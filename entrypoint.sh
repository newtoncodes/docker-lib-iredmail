#!/usr/bin/env bash

CPU_COUNT=`grep processor /proc/cpuinfo | wc -l`;
RAM_COUNT=$(($(printf "%.0f" `awk 'match($0,/MemTotal:/) {print $2}' /proc/meminfo`) / 1024))
HOST_IP=`/sbin/ip route|awk '/default/ { print $3 }'`;

sed -i "s/innodb_thread_concurrency.*/innodb_thread_concurrency       = $(($CPU_COUNT*2))/" /etc/mysql/mysql.conf.d/mysqld.cnf
sed -i "s/innodb_buffer_pool_size.*/innodb_buffer_pool_size         = $(printf "%.0f" $((($RAM_COUNT-512)*8/10)))M/" /etc/mysql/mysql.conf.d/mysqld.cnf


if [ "$1" = "bash" ] && [ ! -f /var/lib/mysql/ibdata1 ]; then
    echo "Initializing..."
    mkdir -p /var/lib/mysql
    mkdir -p /var/run/mysqld
	chown -R mysql:mysql /var/lib/mysql
	chown -R mysql:mysql /var/run/mysqld
    mysqld --initialize-insecure
    echo "Database initialized."

    mkdir -p /var/run/clamav
    chown clamav:clamav /var/run/clamav

    mkdir -p /var/lib/clamav
    chown clamav:clamav /var/lib/clamav

    mkdir -p /var/vmail
    chown vmail:vmail /var/vmail

    mkdir -p /var/run/vmail
    chown vmail:vmail /var/run/vmail

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

    mkdir -p /var/run/mysqld
    mkdir -p /var/run/mysql
    mkdir -p /var/lib/mysql
    chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/run/mysql

    mkdir -p /var/vmail
    chown -R mysql:mysql /var/vmail

    mkdir -p /var/lib/clamav
    chown -R clamav:clamav /var/lib/clamav

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

    . /opt/iredmail/config \
        && sed -i 's/PREFORK=.*$'/PREFORK=$SOGO_WORKERS/ /etc/default/sogo \
        && sed -i 's/WOWorkersCount.*$'/WOWorkersCount=$SOGO_WORKERS\;/ /etc/sogo/sogo.conf \
        && sed -i '/^Foreground /c Foreground true' /etc/clamav/clamd.conf \
        && sed -i '/init.d/c pkill -sighup clamd' /etc/logrotate.d/clamav-daemon \
        && sed -i '/^Foreground /c Foreground true' /etc/clamav/freshclam.conf \
        && sed -i 's/^bind-address/#bind-address/' /etc/mysql/mysql.conf.d/mysqld.cnf

    echo
    echo "Iredmail is ready."
fi

exec "$@"
