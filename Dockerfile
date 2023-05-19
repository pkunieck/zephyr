FROM dockerhubcache.caas.intel.com/zephyrprojectrtos/ci-base:v0.26.4 as ci-lite

# proxy args set/override at build stage like this:
# docker build --build-arg HTTPPROXY=$http_proxy --build-arg HTTPSPROXY=$https_proxy --build-arg NOPROXY=$no_proxy ...
ARG HTTPPROXY=
ARG HTTPSPROXY=
ARG NOPROXY=
ARG ARTIFACTORY_API_KEY=
# NOTE: The formatting of the proxy string is important, it must be:
#     'http://<proxy.url>:<proxy.port'
# otherwise the awk-based proxy.xml writer (below) will fail

# Corporate proxy settings- these affect the running container ONLY.
# If you're having issues with the docker build behind a proxy, make sure the docker daemon is configured for proxy access:
# https://docs.docker.com/network/proxy/
ENV no_proxy=$NOPROXY
ENV http_proxy=$HTTPPROXY
ENV https_proxy=$HTTPSPROXY
ENV NO_PROXY=$NOPROXY
ENV HTTP_PROXY=$HTTPPROXY
ENV HTTPS_PROXY=$HTTPSPROXY
ENV XTENSAD_LICENSE_FILE=84300@xtensa01p.elic.intel.com

ENV WGET_ARGS="-q --show-progress --progress=bar:force:noscroll --no-check-certificate"
ARG HOSTTYPE=x86_64

ARG UID=1000
ARG GID=1000

# Set default shell during Docker image build to bash
SHELL ["/bin/bash", "-c"]

# Set non-interactive frontend for apt-get to skip any user confirmations
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get -yq update && \
	apt-get -yq upgrade && \
	apt-get -yq update

# Install github-cli per https://github.com/cli/cli/blob/trunk/docs/install_linux.md
RUN apt-get install -y --no-install-recommends curl && \
		curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
		echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
		apt update && apt install gh

# Add more packages needed for additional tools
# - Support xcc compiler
# - libncurses5:amd64 needed for nsim simulator
RUN	apt install -y --no-install-recommends zlib1g:i386 libc6-i386 \
	lib32ncurses6 lib32ncurses-dev libcrypt1:i386 libncurses5:i386 libcrypt1:amd64 \
	libtinfo5 libncursesw5 libncurses5:amd64 libusb-1.0-0-dev

RUN pip install --upgrade pip

# Install labgrid
RUN git clone https://github.com/labgrid-project/labgrid /tmp/labgrid && \
	pushd /tmp/labgrid && \
	pip install . && \
	popd && \
	rm -rf /tmp/labgrid

# Install SF100 (Dediprog)
RUN git clone https://github.com/DediProgSW/SF100Linux /tmp/SF100Linux && \
	cd /tmp/SF100Linux && \
	git checkout c76e10f03ab758b1dce1c54e586a7a14fbcf298a && \
	make PREFIX=/opt/tools && \
	mkdir -p /etc/udev/rules.d && \
	make install PREFIX=/opt/tools && \
	rm -rf /tmp/SF100Linux

# Install additional pre-built tools:
# - mec172 and mec1501 SPI image builder
COPY ./tools /opt/tools

# Install Linux-tools-generic
RUN sudo apt-get install -y linux-tools-generic

# Install JLink firmware
RUN wget ${WGET_ARGS}  --header="X-JFrog-Art-Api:$ARTIFACTORY_API_KEY" \
	https://ubit-artifactory-or.intel.com/artifactory/zephyr-generic-or-local/tools/JLink_Linux_V786f_x86_64.tgz && \
	mkdir -p /opt/SEGGER && \
	tar xf JLink_Linux_V786f_x86_64.tgz -C /opt/SEGGER && \
	rm JLink_Linux_V786f_x86_64.tgz && \
	cd /opt/SEGGER && \
	ln -s /opt/SEGGER/JLink_Linux_V786f_x86_64 JLink

# Install NSIM
RUN wget ${WGET_ARGS}  --header="X-JFrog-Art-Api:$ARTIFACTORY_API_KEY" \
	https://ubit-artifactory-or.intel.com/artifactory/zephyr-generic-or-local/simulators/nsim/nsim_free.tgz && \
	mkdir -p /tmp/nsim && \
	tar xf nsim_free.tgz -C /tmp/nsim && \
	cp -a /tmp/nsim/nSIM_64/* /opt/tools/ && \
	rm -rf /tmp/nsim && \
	rm nsim_free.tgz

# Clean up stale packages
RUN apt-get clean -y && \
	apt-get autoremove --purge -y && \
	rm -rf /var/lib/apt/lists/*

ADD ./entrypoint.sh /entrypoint.sh
RUN dos2unix /entrypoint.sh
RUN usermod -a -G dialout user

ENTRYPOINT ["/entrypoint.sh"]


# Set back to 'user' as the Zephyr container has the default user set to root
# w/o this files will be created as root and cause issues
USER user

###########XCC Docker##########
FROM ci-lite as ci-xcc

ENV XTENSAD_LICENSE_FILE=84300@xtensa01p.elic.intel.com
ARG ARTIFACTORY_API_KEY=
ENV WGET_ARGS="-q --show-progress --progress=bar:force:noscroll --no-check-certificate"
USER root
ENV ACE10_CORE=ace10_LX7HiFi4_2022_10_linux.tgz

RUN mkdir xcc && cd xcc && \
    wget ${WGET_ARGS} --header="X-JFrog-Art-Api:$ARTIFACTORY_API_KEY" https://ubit-artifactory-or.intel.com/artifactory/zephyr-generic-or-local/toolchain/xcc/install.sh && \
    chmod a+x install.sh && \
    wget ${WGET_ARGS} -nd -P RG-2017.8 -r -l 1 --header="X-JFrog-Art-Api:$ARTIFACTORY_API_KEY" https://ubit-artifactory-or.intel.com/artifactory/zephyr-generic-or-local/toolchain/xcc/RG-2017.8/ && \
    wget ${WGET_ARGS} -nd -P RI-2021.7 -r -l 1 --header="X-JFrog-Art-Api:$ARTIFACTORY_API_KEY" https://ubit-artifactory-or.intel.com/artifactory/zephyr-generic-or-local/toolchain/xcc/RI-2021.7/ && \
    wget ${WGET_ARGS} -nd -P RI-2022.10 -r -l 1 --header="X-JFrog-Art-Api:$ARTIFACTORY_API_KEY" https://ubit-artifactory-or.intel.com/artifactory/zephyr-generic-or-local/toolchain/xcc/RI-2022.10/ && \
    ./install.sh /opt/toolchains/xtensa/XtDevTools/install  && \
    cd .. && rm -fr xcc && \
    find /opt/toolchains/xtensa/ -name html | xargs rm -rf

RUN usermod -a -G dialout user
USER user

#################### For build the simulator######
FROM ci-xcc as acesim-sdk
USER root
RUN dpkg --add-architecture i386 && \
        apt-get -y update && \
        apt-get install --no-install-recommends -y \
	libboost-all-dev \
        patchelf


RUN usermod -a -G dialout user
USER user
RUN pip3 install meson -U

ENV PATH="$HOME/.local/bin:$PATH"

##########CI-SDK Docker#########
FROM dockerhubcache.caas.intel.com/zephyrprojectrtos/ci:v0.26.4 as ci-sdk
ARG HTTPPROXY=
ARG HTTPSPROXY=
ARG NOPROXY=
ARG ARTIFACTORY_API_KEY=
ENV no_proxy=$NOPROXY
ENV http_proxy=$HTTPPROXY
ENV https_proxy=$HTTPSPROXY
ENV NO_PROXY=$NOPROXY
ENV HTTP_PROXY=$HTTPPROXY
ENV HTTPS_PROXY=$HTTPSPROXY

ARG ZSDK_VERSION
ENV ZSDK_VERSION=0.16.1
ENV XTENSAD_LICENSE_FILE=84300@xtensa01p.elic.intel.com

RUN apt-get -yq update && \
	apt-get -yq upgrade && \
	apt-get -yq update
# Add more packages needed for additional tools
# - Support xcc compiler
# - libncurses5:amd64 needed for nsim simulator
RUN	apt install -y --no-install-recommends zlib1g:i386 libc6-i386 \
	lib32ncurses6 lib32ncurses-dev libcrypt1:i386 libncurses5:i386 libcrypt1:amd64 \
	libtinfo5 libncursesw5 libncurses5:amd64 libusb-1.0-0-dev \
	netcat telnet

COPY --from=ci-xcc /opt/toolchains/xtensa /opt/toolchains/xtensa
COPY --from=ci-lite /opt/tools /opt/tools

RUN pip install --upgrade pip

# Install labgrid
RUN git clone https://github.com/labgrid-project/labgrid /tmp/labgrid && \
	pushd /tmp/labgrid && \
	pip install . && \
	popd && \
	rm -rf /tmp/labgrid

# Used by at least the docker CI
ENV ZEPHYR_SDK_INSTALL_DIR=/opt/toolchains/zephyr-sdk-$ZSDK_VERSION

RUN usermod -a -G dialout user
USER user
RUN pip3 install elasticsearch -U
ENV PATH="$HOME/.local/bin:/opt/tools/bin:$PATH"

##########CI COVERITY DOCKER#########
FROM ci-sdk AS ci-coverity
USER root
ARG ARTIFACTORY_API_KEY=
ENV WGET_ARGS="-q --show-progress --progress=bar:force:noscroll --no-check-certificate"
ENV PATH="/opt/coverity/analysis/bin:$PATH"
ENV ZSDK_VERSION=0.16.0

# Download coverity install dependencies
RUN wget ${WGET_ARGS} https://ubit-artifactory-or.intel.com/artifactory/coverity-or-local/Enterprise/cov-analysis-linux64-2022.3.1.sh -P /tmp/ && \
	wget ${WGET_ARGS} https://ubit-artifactory-or.intel.com/artifactory/coverity-or-local/Enterprise/license.dat -P /tmp/ && \
	sh /tmp/cov-analysis-linux64-2022.3.1.sh -q \
        --installation.dir=/opt/coverity/analysis/ \
        --license.agreement=agree --license.region=0 --license.type.choice=0 --license.cov.path=/tmp/license.dat \
        --component.sdk=false --component.skip.documentation=true && \
	rm /tmp/cov-analysis-linux64-2022.3.1.sh /tmp/license.dat && \
	chown -R user:user /opt/coverity
ENV ZEPHYR_SDK_INSTALL_DIR=/opt/toolchains/zephyr-sdk-$ZSDK_VERSION
ENV XTENSAD_LICENSE_FILE=84300@xtensa01p.elic.intel.com
USER user

######## oneapi DOCKER #############
FROM ci-lite as ci-oneapi

ARG ARTIFACTORY_API_KEY=
ENV WGET_ARGS="-q --show-progress --progress=bar:force:noscroll --no-check-certificate"
USER root

RUN mkdir oneapi && cd oneapi && mkdir -p /opt/toolchains/oneapi && \
   wget ${WGET_ARGS} --header="X-JFrog-Art-Api:$ARTIFACTORY_API_KEY" https://ubit-artifactory-or.intel.com/artifactory/zephyr-generic-or-local/toolchain/openapi/l_dpcpp-cpp-compiler_p_2023.0.0.25393_offline.sh && \
   chmod a+x l_dpcpp-cpp-compiler_p_2023.0.0.25393_offline.sh && \
   ./l_dpcpp-cpp-compiler_p_2023.0.0.25393_offline.sh -a -s --eula accept --install-dir=/opt/toolchains/oneapi && \
   cd .. && rm -fr oneapi

USER user

#####2.7 sdk docker######
FROM dockerhubcache.caas.intel.com/zephyrprojectrtos/ci:v0.18.4 as ci-sdk-2.7lts
ARG HTTPPROXY=
ARG HTTPSPROXY=
ARG NOPROXY=
ARG ARTIFACTORY_API_KEY=
ENV no_proxy=$NOPROXY
ENV http_proxy=$HTTPPROXY
ENV https_proxy=$HTTPSPROXY
ENV NO_PROXY=$NOPROXY
ENV HTTP_PROXY=$HTTPPROXY
ENV HTTPS_PROXY=$HTTPSPROXY

ARG ZSDK_VERSION
ENV ZSDK_VERSION=0.13.1
ENV XTENSAD_LICENSE_FILE=84300@xtensa01p.elic.intel.com

RUN apt-get -yq update && \
	apt-get -yq upgrade && \
	apt-get -yq update
# Add more packages needed for additional tools
# - libncurses5:amd64 needed for nsim simulator
RUN	apt install -y --no-install-recommends zlib1g:i386 libc6-i386 \
	lib32ncurses6 lib32ncurses-dev libcrypt1:i386 libncurses5:i386 libcrypt1:amd64 \
	libtinfo5 libncursesw5 libncurses5:amd64 libusb-1.0-0-dev \
	netcat telnet

COPY --from=ci-lite /opt/tools /opt/tools

# Used by at least the docker CI
ENV ZEPHYR_SDK_INSTALL_DIR=/opt/toolchains/zephyr-sdk-$ZSDK_VERSION

RUN usermod -a -G dialout user
USER user
RUN pip3 install elasticsearch -U
ENV PATH="$HOME/.local/bin:/opt/tools/bin:$PATH"

