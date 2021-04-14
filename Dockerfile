FROM amr-cache-registry.caas.intel.com/cache/library/ubuntu:20.04

#proxy args set/override at build stage like this:
#   docker build --build-arg HTTPPROXY=$http_proxy --build-arg HTTPSPROXY=$https_proxy --build-arg NOPROXY=$no_proxy ...
ARG HTTPPROXY=
ARG HTTPSPROXY=
ARG NOPROXY=
#NOTE: The formatting of the proxy string is important, it must be:
#     'http://<proxy.url>:<proxy.port'
# otherwise the awk-based proxy.xml writer (below) will fail

#Incorporate proxy settings- these affect the running container ONLY.
#If you're having issues with the docker build behind a proxy, make sure the docker daemon is configured for proxy access:
#https://docs.docker.com/network/proxy/
ENV no_proxy=$NOPROXY
ENV http_proxy=$HTTPPROXY
ENV https_proxy=$HTTPSPROXY
ENV NO_PROXY=$NOPROXY
ENV HTTP_PROXY=$HTTPPROXY
ENV HTTPS_PROXY=$HTTPSPROXY

ARG ZSDK_VERSION=0.12.4
ARG GCC_ARM_NAME=gcc-arm-none-eabi-10-2020-q4-major
ARG CMAKE_VERSION=3.18.3
ARG RENODE_VERSION=1.11.0

ARG UID=1000
ARG GID=1000

ENV DEBIAN_FRONTEND noninteractive

RUN dpkg --add-architecture i386 && \
	apt-get -y update && \
	apt-get -y upgrade && \
	apt-get install --no-install-recommends -y \
	wget

RUN wget -q --show-progress --progress=bar:force:noscroll --no-check-certificate https://github.com/renode/renode/releases/download/v${RENODE_VERSION}/renode_${RENODE_VERSION}_amd64.deb && \
	wget -q --show-progress --progress=bar:force:noscroll --no-check-certificate https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZSDK_VERSION}/zephyr-sdk-${ZSDK_VERSION}-x86_64-linux-setup.run && \
	wget -q --show-progress --progress=bar:force:noscroll --no-check-certificate https://developer.arm.com/-/media/Files/downloads/gnu-rm/10-2020q4/${GCC_ARM_NAME}-x86_64-linux.tar.bz2  && \
	wget -q --show-progress --progress=bar:force:noscroll --no-check-certificate https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-Linux-x86_64.sh

RUN apt-get install --no-install-recommends -y \
	gnupg \
	ca-certificates \
	wget && \
    apt-key adv --keyserver keyserver.ubuntu.com --keyserver-options http-proxy=$HTTPPROXY --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF && \
#PROXY INJECT                                                      PROXY INJECT     ^^^^^^^^^^ \
	echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" | tee /etc/apt/sources.list.d/mono-official-stable.list && \
	apt-get -y update && \
	apt-get install --no-install-recommends -y \
	autoconf \
	automake \
	build-essential \
	ccache \
	device-tree-compiler \
	dfu-util \
	dos2unix \
	doxygen \
	file \
	g++ \
	gcc \
	gcc-multilib \
	g++-multilib \
	gcovr \
	git \
	git-core \
	gitlab-runner \
	gperf \
	gtk-sharp2 \
	iproute2 \
	lcov \
	libglib2.0-dev \
	libgtk2.0-0 \
	libpcap-dev \
	libsdl2-dev:i386 \
	libsdl2-dev \
	libtool \
	locales \
	make \
	mono-complete \
	nano \
	net-tools \
	ninja-build \
	openbox \
	openjdk-8-jdk \
	pkg-config \
	python3-dev \
	python3-pip \
	python3-ply \
	python3-setuptools \
	python3-tk \
	python-xdg \
	qemu \
	rsync \
	socat \
	srecord \
	ssh \
	sudo \
	texinfo \
	unzip \
	valgrind \
	x11vnc \
	xvfb \
	xz-utils && \
	apt install -y ./renode_${RENODE_VERSION}_amd64.deb && \
	rm renode_${RENODE_VERSION}_amd64.deb && \
	rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN pip3 install wheel &&\
	pip3 install -r https://raw.githubusercontent.com/zephyrproject-rtos/zephyr/master/scripts/requirements.txt && \
	pip3 install -r https://raw.githubusercontent.com/zephyrproject-rtos/mcuboot/master/scripts/requirements.txt && \
	pip3 install west &&\
	pip3 install sh

RUN mkdir -p /opt/toolchains

RUN sh "zephyr-sdk-${ZSDK_VERSION}-x86_64-linux-setup.run" --quiet -- -d /opt/toolchains/zephyr-sdk-${ZSDK_VERSION} && \
	rm "zephyr-sdk-${ZSDK_VERSION}-x86_64-linux-setup.run"

RUN tar -xf ${GCC_ARM_NAME}-x86_64-linux.tar.bz2 -C /opt/toolchains/ && \
	rm -f ${GCC_ARM_NAME}-x86_64-linux.tar.bz2

RUN chmod +x cmake-${CMAKE_VERSION}-Linux-x86_64.sh && \
	./cmake-${CMAKE_VERSION}-Linux-x86_64.sh --skip-license --prefix=/usr/local && \
	rm -f ./cmake-${CMAKE_VERSION}-Linux-x86_64.sh

RUN groupadd -g $GID -o jenkins

RUN useradd -u $UID -m -g jenkins -G plugdev jenkins \
	&& echo 'jenkins ALL = NOPASSWD: ALL' > /etc/sudoers.d/jenkins \
	&& chmod 0440 /etc/sudoers.d/jenkins

# Set the locale
ENV ZEPHYR_TOOLCHAIN_VARIANT=zephyr
ENV ZEPHYR_SDK_INSTALL_DIR=/opt/toolchains/zephyr-sdk-${ZSDK_VERSION}
ENV ZEPHYR_BASE=/workdir
ENV GNUARMEMB_TOOLCHAIN_PATH=/opt/toolchains/${GCC_ARM_NAME}
ENV PKG_CONFIG_PATH=/usr/lib/i386-linux-gnu/pkgconfig
ENV DISPLAY=:0

RUN chown -R jenkins:jenkins /home/jenkins

ADD ./entrypoint.sh /home/jenkins/entrypoint.sh
RUN dos2unix /home/jenkins/entrypoint.sh

EXPOSE 5900

ENTRYPOINT ["/home/jenkins/entrypoint.sh"]
CMD ["/bin/bash"]
USER jenkins
WORKDIR /workdir
VOLUME ["/workdir"]

ARG VNCPASSWD=zephyr
RUN mkdir ~/.vnc && x11vnc -storepasswd ${VNCPASSWD} ~/.vnc/passwd

