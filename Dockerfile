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

ARG ZSDK_VERSION=0.15.0
ARG GCC_ARM_NAME=gcc-arm-none-eabi-10-2020-q4-major
ARG DOXYGEN_VERSION=1.9.4
ARG CMAKE_VERSION=3.20.5
ARG RENODE_VERSION=1.13.0
ARG LLVM_VERSION=12
ARG BSIM_VERSION=v1.0.3
ARG SPARSE_VERSION=9212270048c3bd23f56c20a83d4f89b870b2b26e
ARG WGET_ARGS="-q --show-progress --progress=bar:force:noscroll --no-check-certificate"

ARG UID=1000
ARG GID=1000

# Set non-interactive frontend for apt-get to skip any user confirmations
ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386 && \
	apt-get -yq update && \
	apt-get -yq upgrade && \
	apt-get install --no-install-recommends -yq \
	gnupg \
	ca-certificates \
	wget && \
    apt-key adv --keyserver keyserver.ubuntu.com --keyserver-options http-proxy=$HTTPPROXY --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF && \
#PROXY INJECT                                                      PROXY INJECT     ^^^^^^^^^^ \
	echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" | tee /etc/apt/sources.list.d/mono-official-stable.list && \
	apt-get -yq update && \
	apt-get install --no-install-recommends -yq \
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
	gnupg \
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
	apt install -yq ./renode_${RENODE_VERSION}_amd64.deb && \
	rm renode_${RENODE_VERSION}_amd64.deb && \
	rm -rf /var/lib/apt/lists/*

# Initialise system locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Install Doxygen (x86 only)
# NOTE: Pre-built Doxygen binaries are only available for x86_64 host.
RUN if [ "${HOSTTYPE}" = "x86_64" ]; then \
	wget ${WGET_ARGS} https://downloads.sourceforge.net/project/doxygen/rel-${DOXYGEN_VERSION}/doxygen-${DOXYGEN_VERSION}.linux.bin.tar.gz && \
	tar xf doxygen-${DOXYGEN_VERSION}.linux.bin.tar.gz -C /opt && \
	ln -s /opt/doxygen-${DOXYGEN_VERSION}/bin/doxygen /usr/local/bin && \
	rm doxygen-${DOXYGEN_VERSION}.linux.bin.tar.gz \
	; fi
	
# Install Python dependencies
# Awscli requires docutils<0.17 (0.16) which breaks all kinds of things, so remove that
# protobuf pinned to unbreak samples/modules/nanopb .proto stuff
# Default six package is not high enough version for pyocd and others, so bump
# These version issues are still present with latest upstream docker image. 
RUN pip3 install wheel pip -U &&\
	pip3 install -r https://raw.githubusercontent.com/zephyrproject-rtos/zephyr/master/scripts/requirements.txt && \
	pip3 install -r https://raw.githubusercontent.com/zephyrproject-rtos/mcuboot/master/scripts/requirements.txt && \
	pip3 install west &&\
	pip3 install sh &&\
	pip3 install PyGithub junitparser pylint \
		     statistics numpy \
		     imgtool \
		     protobuf \
                     GitPython && \
        pip3 install --upgrade "protobuf<=3.19.0" "docutils==0.17" "six>=1.5.0" "jinja2>=3.0"

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

# Install BSIM
RUN mkdir -p /opt/bsim && \
	cd /opt/bsim && \
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
RUN	apt update && apt install -y --no-install-recommends zlib1g:i386 libc6-i386 lib32ncurses6 lib32ncurses-dev libcrypt1:i386 libncurses5:i386 libcrypt1:amd64 libtinfo5 libncursesw5
ENV	XTENSAD_LICENSE_FILE=84300@xtensa01p.elic.intel.com

ADD ./entrypoint.sh /entrypoint.sh
RUN dos2unix /entrypoint.sh

# Install uefi-run utility
RUN wget ${WGET_ARGS} https://static.rust-lang.org/rustup/rustup-init.sh && \
	chmod +x rustup-init.sh && \
	./rustup-init.sh -y && \
	. $HOME/.cargo/env && \
	cargo install uefi-run --root /usr && \
	rm -f ./rustup-init.sh

# Install LLVM and Clang
RUN wget ${WGET_ARGS} -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - && \
	apt-get update && \
	apt-get install -y clang-$LLVM_VERSION lldb-$LLVM_VERSION lld-$LLVM_VERSION clangd-$LLVM_VERSION llvm-$LLVM_VERSION-dev

# Install sparse package for static analysis
RUN mkdir -p /opt/sparse && \
	cd /opt/sparse && \
	git clone https://git.kernel.org/pub/scm/devel/sparse/sparse.git && \
	cd sparse && git checkout ${SPARSE_VERSION} && \
	make -j8 && \
	PREFIX=/opt/sparse make install && \
	rm -rf /opt/sparse/sparse
	
# Clean up stale packages
RUN apt-get clean -y && \
	apt-get autoremove --purge -y && \
	rm -rf /var/lib/apt/lists/*

# create container /opt/1rtos directory from repo 1rtos directory
COPY ./1rtos/* /opt/1rtos/

ENV ZEPHYR_TOOLCHAIN_VARIANT=zephyr
ENV PKG_CONFIG_PATH=/usr/lib/i386-linux-gnu/pkgconfig
ENV OVMF_FD_PATH=/usr/share/ovmf/OVMF.fd
ENV ZEPHYR_SDK_INSTALL_DIR=/opt/toolchains/zephyr-sdk-${ZSDK_VERSION}
ENV GNUARMEMB_TOOLCHAIN_PATH=/opt/toolchains/${GCC_ARM_NAME}

ENTRYPOINT ["/entrypoint.sh"]
