FROM ubuntu:18.04
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


ARG ZSDK_VERSION=0.11.4
ARG GCC_ARM_NAME=gcc-arm-none-eabi-9-2019-q4-major
ARG CMAKE_VERSION=3.18.0
ARG RENODE_VERSION=1.9.0
ARG DTS_VERSION=1.4.7

ARG UID=1000
ARG GID=1000

ENV DEBIAN_FRONTEND noninteractive

RUN dpkg --add-architecture i386 && \
	apt-get -y update && \
	apt-get -y upgrade && \
	apt-get install --no-install-recommends -y \
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
	wget -O dtc.deb http://security.ubuntu.com/ubuntu/pool/main/d/device-tree-compiler/device-tree-compiler_${DTS_VERSION}-3ubuntu2_amd64.deb && \
	dpkg -i dtc.deb && \
	wget -O renode.deb https://github.com/renode/renode/releases/download/v${RENODE_VERSION}/renode_${RENODE_VERSION}_amd64.deb && \
	apt install -y ./renode.deb && \
	rm dtc.deb renode.deb && \
	rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8


RUN wget -q https://raw.githubusercontent.com/zephyrproject-rtos/zephyr/master/scripts/requirements.txt && \
	wget -q https://raw.githubusercontent.com/zephyrproject-rtos/zephyr/master/scripts/requirements-base.txt && \
	wget -q https://raw.githubusercontent.com/zephyrproject-rtos/zephyr/master/scripts/requirements-build-test.txt && \
	wget -q https://raw.githubusercontent.com/zephyrproject-rtos/zephyr/master/scripts/requirements-doc.txt && \
	wget -q https://raw.githubusercontent.com/zephyrproject-rtos/zephyr/master/scripts/requirements-run-test.txt && \
	wget -q https://raw.githubusercontent.com/zephyrproject-rtos/zephyr/master/scripts/requirements-extras.txt && \
	pip3 install wheel &&\
	pip3 install -r requirements.txt && \
	pip3 install west &&\
	pip3 install sh


RUN wget -q "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZSDK_VERSION}/zephyr-sdk-${ZSDK_VERSION}-setup.run" && \
	sh "zephyr-sdk-${ZSDK_VERSION}-setup.run" --quiet -- -d /opt/toolchains/zephyr-sdk-${ZSDK_VERSION} && \
	rm "zephyr-sdk-${ZSDK_VERSION}-setup.run"

RUN wget -q https://developer.arm.com/-/media/Files/downloads/gnu-rm/9-2019q4/RC2.1/${GCC_ARM_NAME}-x86_64-linux.tar.bz2  && \
	tar xf ${GCC_ARM_NAME}-x86_64-linux.tar.bz2 && \
	rm -f ${GCC_ARM_NAME}-x86_64-linux.tar.bz2 && \
	mv ${GCC_ARM_NAME} /opt/toolchains/${GCC_ARM_NAME}

RUN wget -q https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-Linux-x86_64.sh && \
	chmod +x cmake-${CMAKE_VERSION}-Linux-x86_64.sh && \
	./cmake-${CMAKE_VERSION}-Linux-x86_64.sh --skip-license --prefix=/usr/local && \
	rm -f ./cmake-${CMAKE_VERSION}-Linux-x86_64.sh

RUN groupadd -g $GID -o user

RUN useradd -u $UID -m -g user -G plugdev user \
	&& echo 'user ALL = NOPASSWD: ALL' > /etc/sudoers.d/user \
	&& chmod 0440 /etc/sudoers.d/user

# Set the locale
ENV ZEPHYR_TOOLCHAIN_VARIANT=zephyr
ENV ZEPHYR_SDK_INSTALL_DIR=/opt/toolchains/zephyr-sdk-${ZSDK_VERSION}
ENV ZEPHYR_BASE=/workdir
ENV GNUARMEMB_TOOLCHAIN_PATH=/opt/toolchains/${GCC_ARM_NAME}
ENV PKG_CONFIG_PATH=/usr/lib/i386-linux-gnu/pkgconfig
ENV DISPLAY=:0

RUN chown -R user:user /home/user

ADD ./entrypoint.sh /home/user/entrypoint.sh
RUN dos2unix /home/user/entrypoint.sh

EXPOSE 5900

ENTRYPOINT ["/home/user/entrypoint.sh"]
CMD ["/bin/bash"]

WORKDIR /workdir
VOLUME ["/workdir"]

ARG VNCPASSWD=zephyr
RUN mkdir ~/.vnc && x11vnc -storepasswd ${VNCPASSWD} ~/.vnc/passwd

