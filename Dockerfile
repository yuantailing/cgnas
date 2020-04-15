FROM ubuntu:18.04

RUN sed -i s/archive.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g /etc/apt/sources.list && \
	sed -i s/security.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g /etc/apt/sources.list

RUN sed "s/read -p.*/REPLY=y/" -i $(which unminimize) && \
	sed "s/apt-get upgrade/apt-get upgrade -y/g" -i $(which unminimize) && \
	unminimize && \
	rm -rf /var/lib/apt/lists/*

RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y ubuntu-server ubuntu-desktop && \
	rm -rf /var/lib/apt/lists/*

RUN apt-get update && \
	apt-get install --no-install-recommends -y apache2 curl nfs-kernel-server openssh-server openvpn python3 python3-pip samba vsftpd && \
	rm -rf /var/lib/apt/lists/*

RUN pip3 install --user requests && \
	rm -rf ~/.cache/pip

RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y \
		acl apport apt-rdepends apt-transport-https apt-utils aria2 attr automake \
		bc blender build-essential \
		chromium-browser chromium-chromedriver clang cmake codelite cron \
		dc default-jdk default-jre dos2unix \
		expect \
		ffmpeg fish \
		gdb gfortran git gnulib gnupg-agent gnupg1 gnupg2 golang-go \
		htop \
		iftop imagemagick iotop iputils-ping \
		landscape-client less libboost-dev libfreetype6-dev libglu-dev liblapack-dev liblapacke-dev libmysqlclient-dev libopenblas-dev libpcre++-dev libopencv-dev libsnappy-dev libssl-dev links lm-sensors locales locate lsb-release \
		man mysql-client \
		nano net-tools nmap nodejs ntpdate \
		p7zip-full php pkg-config procinfo proxychains psmisc python-dev python-pip python-setuptools python-tk python3-dev python3-setuptools python3-tk \
		rar ruby-bundler ruby-dev \
		screen shadowsocks-libev smbclient software-properties-common sshfs supervisor \
		telnet tmux traceroute \
		unrar unzip \
		vim virtualenv \
		w3m wget whois \
		x11-apps xdg-utils xorg xorg-dev \
		zip zsh && \
	rm -rf /var/lib/apt/lists/*

RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y \
		g++-5 g++-6 g++-8 python3.7 python3.7-dev && \
	rm -rf /var/lib/apt/lists/*

RUN rm /etc/apt/apt.conf.d/docker-clean && \
	apt-get update

COPY ssh_host_keys /etc/cgnas/ssh_host_keys
COPY conf/openvpn_account /root/private/openvpn_account
COPY scripts_static /root/scripts_static

ARG VSFTPD_PASV_MIN_PORT
ARG VSFTPD_PASV_MAX_PORT
RUN /root/scripts_static/build.sh

CMD ["/root/scripts_static/cmd.sh"]
