#!/usr/bin/env bash

echo "Domain: $DOMAIN"
echo "Hostname: $HOSTNAME"

echo ${DOMAIN} > /etc/mailname
echo ${HOSTNAME} > /opt/hostname

sed s/$(hostname_)/$(cat /opt/hostname | xargs echo -n).$(cat /etc/mailname | xargs echo -n)/ /etc/hosts > /tmp/hosts_ \
    && cat /tmp/hosts_ > /etc/hosts \
    && rm /tmp/hosts_ \
    && echo $HOSTNAME > /etc/hostname \
    && sleep 5;

mkdir -p /var/lib/mysql
mkdir -p /var/run/mysqld
mkdir -p /var/run/clamav
mkdir -p /var/lib/clamav
mkdir -p /var/vmail
mkdir -p /var/run/vmail

chown -R mysql:mysql /var/lib/mysql
chown -R mysql:mysql /var/run/mysqld
chown clamav:clamav /var/run/clamav
chown clamav:clamav /var/lib/clamav
chown vmail:vmail /var/vmail
chown vmail:vmail /var/run/vmail

. /opt/iredmail/config \
    && sed -i 's/PREFORK=.*$'/PREFORK=$SOGO_WORKERS/ /etc/default/sogo \
    && sed -i 's/WOWorkersCount.*$'/WOWorkersCount=$SOGO_WORKERS\;/ /etc/sogo/sogo.conf \
    && sed -i '/^Foreground /c Foreground true' /etc/clamav/clamd.conf \
    && sed -i '/init.d/c pkill -sighup clamd' /etc/logrotate.d/clamav-daemon \
    && sed -i '/^Foreground /c Foreground true' /etc/clamav/freshclam.conf \
    && sed -i 's/^bind-address/#bind-address/' /etc/mysql/mysql.conf.d/mysqld.cnf

exec "$@"
