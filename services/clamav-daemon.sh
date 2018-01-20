#!/bin/sh
# Wait until SOGo is started
while ! nc -z localhost 20000; do   
  sleep 1
done
sleep 3

chown -R clamav:clamav /var/lib/clamav

if [ ! -e /var/lib/clamav/main.cvd ]; then
   echo "*** Preparing ClamAV files.." 
   cd / && tar jxf /root/clamav.tar.bz2
   rm /root/clamav.tar.bz2
fi;

exec /usr/sbin/clamd
