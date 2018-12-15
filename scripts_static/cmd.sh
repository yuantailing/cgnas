#!/bin/bash
set -ex

if [ ! -d /mnt/persistent/cron/crontabs ]; then mkdir -p /mnt/persistent/cron/crontabs; fi
rm -r /var/spool/cron && ln -s /mnt/persistent/cron /var/spool/cron
chgrp crontab /var/spool/cron/crontabs && chgrp -f crontab /var/spool/cron/crontabs/* && chmod 1730 /var/spool/cron/crontabs
touch /etc/cron.allow

service ssh start
service smbd start
service vsftpd start || true
service apache2 start
service cron start
service openvpn start

updatedb &

python3 $(dirname $(realpath "$0"))/idle.py
