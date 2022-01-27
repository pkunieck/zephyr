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

ARG ZSDK_VERSION=0.13.2
ARG GCC_ARM_NAME=gcc-arm-none-eabi-10-2020-q4-major
ARG CMAKE_VERSION=3.20.5
ARG RENODE_VERSION=1.12.0
ARG LLVM_VERSION=12
ARG BSIM_VERSION=v1.0.3
ARG WGET_ARGS="-q --show-progress --progress=bar:force:noscroll --no-check-certificate"

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
	software-properties-common \
	lsb-release \
	autoconf \
	automake \
	bison \
	build-essential \
	ccache \
	chrpath \
	cpio \
	device-tree-compiler \
	dfu-util \
	diffstat \
	dos2unix \
	doxygen \
	file \
	flex \
	g++ \
	gawk \
	gcc \
	gcc-multilib \
	g++-multilib \
	gcovr \
	git \
	git-core \
	gitlab-runner \
	gperf \
	gtk-sharp2 \
	help2man \
	iproute2 \
	lcov \
	libglib2.0-dev \
	libgtk2.0-0 \
	liblocale-gettext-perl \
	libncurses5-dev \
	libpcap-dev \
	libpopt0 \
	libsdl2-dev:i386 \
	libsdl1.2-dev \
	libsdl2-dev \
	libssl-dev \
	libtool \
	libtool-bin \
	locales \
	make \
	net-tools \
	ninja-build \
	openssh-client \
	pkg-config \
	protobuf-compiler \
	python3-dev \
	python3-pip \
	python3-ply \
	python3-setuptools \
	python-is-python3 \
	qemu \
	rsync \
	socat \
	srecord \
	sudo \
	texinfo \
	unzip \
	valgrind \
	wget \
	ovmf \
	xz-utils && \
	wget ${WGET_ARGS} https://github.com/renode/renode/releases/download/v${RENODE_VERSION}/renode_${RENODE_VERSION}_amd64.deb && \
	apt install -y ./renode_${RENODE_VERSION}_amd64.deb && \
	rm renode_${RENODE_VERSION}_amd64.deb && \
	rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN pip3 install wheel pip -U &&\
	pip3 install -r https://raw.githubusercontent.com/zephyrproject-rtos/zephyr/master/scripts/requirements.txt && \
	pip3 install -r https://raw.githubusercontent.com/zephyrproject-rtos/mcuboot/master/scripts/requirements.txt && \
	pip3 install west &&\
	pip3 install sh &&\
	pip3 install awscli PyGithub junitparser pylint \
		     statistics numpy \
		     imgtool \
		     protobuf


RUN mkdir -p /opt/toolchains

# 1RTOS DevOps Note:
# ARM GCC SDK is distributed via NFS so we omit it from container image to reduce size
#
# RUN wget ${WGET_ARGS} https://developer.arm.com/-/media/Files/downloads/gnu-rm/10-2020q4/${GCC_ARM_NAME}-x86_64-linux.tar.bz2  && \
#	tar -xf ${GCC_ARM_NAME}-x86_64-linux.tar.bz2 -C /opt/toolchains/ && \
#	rm -f ${GCC_ARM_NAME}-x86_64-linux.tar.bz2

RUN wget ${WGET_ARGS} https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-Linux-x86_64.sh && \
	chmod +x cmake-${CMAKE_VERSION}-Linux-x86_64.sh && \
	./cmake-${CMAKE_VERSION}-Linux-x86_64.sh --skip-license --prefix=/usr/local && \
	rm -f ./cmake-${CMAKE_VERSION}-Linux-x86_64.sh

RUN wget ${WGET_ARGS} -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - && \
	apt-get update && \
	apt-get install -y clang-$LLVM_VERSION lldb-$LLVM_VERSION lld-$LLVM_VERSION clangd-$LLVM_VERSION llvm-$LLVM_VERSION-dev

RUN mkdir -p /opt/bsim
RUN cd /opt/bsim && \
	rm -f repo && \
	wget ${WGET_ARGS} https://storage.googleapis.com/git-repo-downloads/repo && \
	chmod a+x ./repo && \
	python3 ./repo init -u https://github.com/BabbleSim/manifest.git -m zephyr_docker.xml -b ${BSIM_VERSION} --depth 1 &&\
	python3 ./repo sync && \
	make everything -j 8 && \
	echo ${BSIM_VERSION} > ./version && \
	chmod ag+w . -R

# 1RTOS DevOps Note:
# Zephyr SDKs are distributed via NFS so we can omit it here to save space.
#
#RUN wget ${WGET_ARGS} https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZSDK_VERSION}/zephyr-sdk-${ZSDK_VERSION}-x86_64-linux-setup.run && \
#	sh "zephyr-sdk-${ZSDK_VERSION}-x86_64-linux-setup.run" --quiet -- -d /opt/toolchains/zephyr-sdk-${ZSDK_VERSION} && \
#	rm "zephyr-sdk-${ZSDK_VERSION}-x86_64-linux-setup.run"

# Install github-cli per https://github.com/cli/cli/blob/trunk/docs/install_linux.md
RUN	apt update && apt install -y --no-install-recommends curl && \
		curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
		echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
		apt update && apt install gh

# Support xcc compiler installed on NFS share
RUN	apt update && apt install -y --no-install-recommends zlib1g:i386 libc6-i386 lib32ncurses6 lib32ncurses-dev
ENV	XTENSAD_LICENSE_FILE=84300@xtensa01p.elic.intel.com

RUN apt-get clean && \
	sudo apt-get autoremove --purge

RUN groupadd -g $GID -o 1rtosdev

RUN useradd -u $UID -m -g 1rtosdev -G plugdev 1rtosdev \
	&& echo '1rtosdev ALL = NOPASSWD: ALL' > /etc/sudoers.d/1rtosdev \
	&& chmod 0440 /etc/sudoers.d/1rtosdev

# pre-load ssh-key for gitlab @ Intel, required for automated, SSH-authenticated push/pulls
RUN mkdir /home/1rtosdev/.ssh && \
	ssh-keyscan -t rsa -p 29418 gitlab.devtools.intel.com > /home/1rtosdev/.ssh/known_hosts

ADD ./entrypoint.sh /home/1rtosdev/entrypoint.sh
RUN dos2unix /home/1rtosdev/entrypoint.sh

RUN chown -R 1rtosdev:1rtosdev /home/1rtosdev

RUN wget ${WGET_ARGS} https://static.rust-lang.org/rustup/rustup-init.sh && \
	chmod +x rustup-init.sh && \
	./rustup-init.sh -y && \
	. $HOME/.cargo/env && \
	cargo install uefi-run --root /usr && \
	rm -f ./rustup-init.sh

# create container /opt/1rtos directory from repo 1rtos directory
COPY ./1rtos/* /opt/1rtos/

# Set the locale
ENV ZEPHYR_TOOLCHAIN_VARIANT=zephyr
ENV ZEPHYR_SDK_INSTALL_DIR=/opt/toolchains/zephyr-sdk-${ZSDK_VERSION}
ENV GNUARMEMB_TOOLCHAIN_PATH=/opt/toolchains/${GCC_ARM_NAME}
ENV PKG_CONFIG_PATH=/usr/lib/i386-linux-gnu/pkgconfig
ENV OVMF_FD_PATH=/usr/share/ovmf/OVMF.fd

ENTRYPOINT ["/home/1rtosdev/entrypoint.sh"]
CMD ["/bin/bash"]
USER 1rtosdev
WORKDIR /workdir
VOLUME ["/workdir"]
