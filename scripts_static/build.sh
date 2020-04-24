#!/bin/bash
set -ex

SSH_PORTS=$1

# add `user' group
groupadd -g501 user

# set timezone
ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && dpkg-reconfigure -f noninteractive tzdata

# setup locale
locale-gen en_US en_US.utf8 zh_CN zh_CN.utf8
localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
update-locale LANG=en_US.utf8

# setup openssh-server
sed "s@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g" -i /etc/pam.d/sshd
sed "/^HostKey/d" -i /etc/ssh/sshd_config
for SSH_PORT in ${SSH_PORTS}; do echo "Port ${SSH_PORT}" >>/etc/ssh/sshd_config; done
echo "HostKey /etc/cgnas/ssh_host_keys/ssh_host_rsa_key" >>/etc/ssh/sshd_config
echo "HostKey /etc/cgnas/ssh_host_keys/ssh_host_ecdsa_key" >>/etc/ssh/sshd_config
echo "X11UseLocalhost yes" >>/etc/ssh/sshd_config
echo "GatewayPorts clientspecified" >>/etc/ssh/sshd_config

# setup samba
# see https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html
sed "/\[global\]/a\  unix extensions = no\n  passdb backend = smbpasswd" -i /etc/samba/smb.conf
sed "/passdb backend = tdbsam/d" -i /etc/samba/smb.conf
echo "[share]
  path = /
  browseable = yes
  writable = yes
  comment = nas-docker
  hide dot files = no
  create mode = 0644
  directory mode = 0755
  follow symlinks = yes
  wide links = yes" >>/etc/samba/smb.conf

# setup vsftpd
sed "s/listen_ipv6=YES/listen_ipv6=NO/g" -i /etc/vsftpd.conf
sed "s/listen=NO/listen=YES/g" -i /etc/vsftpd.conf
echo "write_enable=YES
chroot_local_user=YES
local_root=/
local_umask=022
utf8_filesystem=YES
use_localtime=NO" >>/etc/vsftpd.conf

# setup nfs
mkdir -p /run/sendsigs.omit.d
echo "/nas *(rw,sync,no_subtree_check,all_squash)" >>/etc/exports
echo "mountd 31001/tcp
mountd 31001/udp
lockd 31002/tcp
lockd 31002/udp" >>/etc/services

# setup openvpn
curl -sSL https://cg.cs.tsinghua.edu.cn/serverlist/static/serverlist/cscg.ovpn -o /etc/openvpn/cscg.conf
sed -i "s/auth-user-pass/auth-user-pass \/root\/private\/openvpn_account/g" /etc/openvpn/cscg.conf

# disable updatedb
chmod -x /etc/cron.daily/locate
if [ -f /etc/cron.daily/mlocate ]; then chmod -x /etc/cron.daily/mlocate; fi
