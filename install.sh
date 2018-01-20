#!/usr/bin/env bash

set -e

domain=example.com
hostname=mail

echo ${domain} > /etc/mailname
echo ${hostname} > /opt/hostname

sed s/$(hostname_)/$(cat /opt/hostname | xargs echo -n).$(cat /etc/mailname | xargs echo -n)/ /etc/hosts > /tmp/hosts_ \
    && cat /tmp/hosts_ > /etc/hosts \
    && rm /tmp/hosts_ \
    && echo "$hostname" > /etc/hostname \
    && sleep 5;

mkdir -p /var/lib/mysql
mkdir -p /var/run/mysqld
mkdir -p /var/run/clamav
mkdir -p /var/lib/clamav
mkdir -p /var/vmail
mkdir -p /var/run/vmail

chown -R mysql:mysql /var/lib/mysql
chown -R mysql:mysql /var/run/mysqld

echo "Generating config..."
sh ./config-gen ${hostname} ${domain} > ./config
echo "Config ready."

#echo "Initializing database..."
#mysqld --initialize-insecure
#echo "Database initialized."

mysqld --skip-networking --socket=/var/run/mysqld/mysqld.sock &
pid="$!"

mysql=( mysql --protocol=socket -uroot -hlocalhost --socket=/var/run/mysqld/mysqld.sock )

for i in {30..0}; do
    if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
        break
    fi
    echo 'MySQL init process in progress...'
    sleep 1
done

if [ "$i" = 0 ]; then
    echo >&2 'MySQL init process failed.'
    exit 1
fi

echo
echo "MySQL is ready."
echo "Setting up iredmail..."

IREDMAIL_DEBUG='NO' \
CHECK_NEW_IREDMAIL='NO' \
AUTO_USE_EXISTING_CONFIG_FILE=y \
AUTO_INSTALL_WITHOUT_CONFIRM=y \
AUTO_CLEANUP_REMOVE_SENDMAIL=y \
AUTO_CLEANUP_REMOVE_MOD_PYTHON=y \
AUTO_CLEANUP_REPLACE_FIREWALL_RULES=n \
AUTO_CLEANUP_RESTART_IPTABLES=n \
AUTO_CLEANUP_REPLACE_MYSQL_CONFIG=y \
AUTO_CLEANUP_RESTART_POSTFIX=n \
bash iRedMail.sh

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

   sed -i 's/1.3.0/1.3.3/' /opt/iredmail/pkgs/MD5.misc /opt/iredmail/conf/roundcube \
&& sed -i 's/9f81625029663c7b19402542356abd5e/71b16babe3beb7639ad7a4595b3ac92a/' /opt/iredmail/pkgs/MD5.misc \

echo
echo "Iredmail is ready."

tar jcf /root/mysql.tar.bz2 /var/lib/mysql && rm -rf /var/lib/mysql
tar jcf /root/vmail.tar.bz2 /var/vmail && rm -rf /var/vmail
tar jcf /root/clamav.tar.bz2 /var/lib/clamav && rm -rf /var/lib/clamav

echo "Tarballs are ready."
