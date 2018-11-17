#!/bin/bash
set -ex

service ssh start
service smbd start
service vsftpd start || true
service rpcbind start
service nfs-kernel-server start
service apache2 start
service cron start
service openvpn start

updatedb &

python3 $(dirname $(realpath "$0"))/idle.py
