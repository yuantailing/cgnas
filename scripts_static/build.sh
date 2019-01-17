#!/bin/bash

set -ex

# add `user' group
groupadd -g501 user

# set timezone
ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && dpkg-reconfigure -f noninteractive tzdata

# setup locale
locale-gen en_US en_US.utf8 zh_CN zh_CN.utf8
update-locale LANG=en_US.utf8

# setup openssh-server
sed "s@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g" -i /etc/pam.d/sshd
sed "/^HostKey/d" -i /etc/ssh/sshd_config
echo "HostKey /etc/cgnas/ssh_host_keys/ssh_host_rsa_key" >>/etc/ssh/sshd_config
echo "HostKey /etc/cgnas/ssh_host_keys/ssh_host_ecdsa_key" >>/etc/ssh/sshd_config
echo "X11UseLocalhost yes" >>/etc/ssh/sshd_config

# setup samba
# see https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html
sed "s/passdb backend = tdbsam/passdb backend = smbpasswd/g" -i /etc/samba/smb.conf
sed "/\[global\]/a\  unix extensions = no" -i /etc/samba/smb.conf
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
use_localtime=NO
pasv_min_port=${VSFTPD_PASV_MIN_PORT}
pasv_max_port=${VSFTPD_PASV_MAX_PORT}" >>/etc/vsftpd.conf

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
