FROM phusion/baseimage:latest

ENV IREDMAIL_VERSION=0.9.7
ENV DOMAIN=DOMAIN
ENV HOSTNAME=HOSTNAME
ENV TIMEZONE=Europe/London
ENV SOGO_WORKERS=2
ENV IREDAPD_PLUGINS="['reject_null_sender', 'reject_sender_login_mismatch', 'greylisting', 'throttle', 'amavisd_wblist', 'sql_alias_access_policy']"
ENV DEBIAN_FRONTEND noninteractive

RUN echo "APT::Install-Recommends 0;" >> /etc/apt/apt.conf.d/01-no-recommends \
    && echo "APT::Install-Suggests 0;" >> /etc/apt/apt.conf.d/01-no-recommends \
    && echo $TIMEZONE > /etc/timezone \
    && apt-get -q update \
    && apt-get upgrade -y \
    && apt-get install -y -q apt-utils \
    && apt-get install -y -q \
      wget \
      bzip2 \
      iptables \
      openssl \
      mysql-server \
      netcat \
      memcached \
    && apt-get autoremove -y -q \
    && apt-get clean -y -q \
    && mv /bin/uname /bin/uname_ \
    && mv /bin/hostname /bin/hostname_
    
COPY ./uname /bin/uname
COPY ./hostname /bin/hostname

RUN chmod +x /bin/uname
RUN chmod +x /bin/hostname

WORKDIR /opt/iredmail

RUN wget -O - https://bitbucket.org/zhb/iredmail/downloads/iRedMail-"${IREDMAIL_VERSION}".tar.bz2 | \
    tar xvj --strip-components=1

COPY ./config-gen /opt/iredmail/config-gen

# Pre-install
COPY install.sh /install.sh
RUN bash -l /install.sh
RUN rm -rf /install.sh


# Core Services
ADD rc.local /etc/rc.local
ADD services/mysql.sh /etc/service/mysql/run
ADD services/postfix.sh /etc/service/postfix/run
ADD services/amavis.sh /etc/service/amavis/run
ADD services/iredapd.sh /etc/service/iredapd/run
ADD services/dovecot.sh /etc/service/dovecot/run
RUN chmod +x /etc/rc.local
RUN chmod +x /etc/service/mysql/run
RUN chmod +x /etc/service/postfix/run
RUN chmod +x /etc/service/amavis/run
RUN chmod +x /etc/service/iredapd/run
RUN chmod +x /etc/service/dovecot/run

# Frontend
ADD services/memcached.sh /etc/service/memcached/run
ADD services/sogo.sh /etc/service/sogo/run
ADD services/iredadmin.sh /etc/service/iredadmin/run
ADD services/php7-fpm.sh /etc/service/php7-fpm/run
ADD services/nginx.sh /etc/service/httpd/run
RUN chmod +x /etc/service/memcached/run
RUN chmod +x /etc/service/sogo/run
RUN chmod +x /etc/service/iredadmin/run
RUN chmod +x /etc/service/php7-fpm/run
RUN chmod +x /etc/service/httpd/run

# Enhancement
ADD services/fail2ban.sh /etc/service/fail2ban/run
ADD services/clamav-daemon.sh /etc/service/clamav-daemon/run
ADD services/clamav-freshclam.sh /etc/service/clamav-freshclam/run
RUN chmod +x /etc/service/fail2ban/run
RUN chmod +x /etc/service/clamav-daemon/run
RUN chmod +x /etc/service/clamav-freshclam/run

### Purge some packets and save disk space
RUN apt-get purge -y -q dialog apt-utils augeas-tools \
    && apt-get autoremove -y -q \
    && apt-get clean -y -q \
    && rm -rf /var/lib/apt/lists/*


# Apache: 80/tcp, 443/tcp
# Postfix: 25/tcp, 587/tcp
# Dovecot: 110/tcp, 143/tcp, 993/tcp, 995/tcp
EXPOSE 80 443 25 587 110 143 993 995

VOLUME ["/var/lib/mysql", "/var/vmail", "/var/lib/clamav"]

COPY entrypoint.sh /usr/bin/entrypoint
RUN chmod +x /usr/bin/entrypoint

ENTRYPOINT ["/usr/bin/entrypoint"]
CMD ["/sbin/my_init"]
