FROM ubuntu:18.04

RUN echo "deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic main restricted universe multiverse\n\
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-security main restricted universe multiverse\n\
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-updates main restricted universe multiverse\n" >/etc/apt/sources.list

RUN sed "s/read -p.*/REPLY=y/" -i $(which unminimize) && \
	sed "s/apt-get upgrade/apt-get upgrade -y/g" -i $(which unminimize) && \
	unminimize && \
	rm -rf /var/lib/apt/lists/*

RUN apt-get update && \
	apt-get install --no-install-recommends -y apache2 curl nfs-kernel-server openssh-server openvpn python3 python3-pip samba vsftpd && \
	rm -rf /var/lib/apt/lists/*

RUN pip3 install requests && \
	rm -rf ~/.cache/pip

RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y acl attr automake bc blender build-essential cmake cron dc default-jdk default-jre expect fish gfortran git gnupg2 golang-go htop iotop iputils-ping less libboost-dev libglu-dev liblapack-dev libopenblas-dev libopencv-dev locate lsb-release man nano net-tools nodejs p7zip-full php pkg-config psmisc python python-pip python-tk python3-tk rar screen smbclient sshfs telnet tmux unrar unzip vim wget whois x11-apps zip zsh && \
	rm -rf /var/lib/apt/lists/*

RUN pip install requests virtualenv && \
	pip3 install virtualenv && \
	rm -rf ~/.cache/pip

COPY ssh_host_keys /etc/cgnas/ssh_host_keys
COPY conf/openvpn_account /root/private/openvpn_account
COPY scripts_static /root/scripts_static

ARG VSFTPD_PASV_MIN_PORT
ARG VSFTPD_PASV_MAX_PORT
RUN /root/scripts_static/build.sh

CMD ["/root/scripts_static/cmd.sh"]
