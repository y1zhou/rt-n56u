FROM ubuntu:20.04 AS buildstage

MAINTAINER hanwckf <hanwckf@vip.qq.com>

ENV DEBIAN_FRONTEND noninteractive

ARG APT_MIRROR_URL
RUN if test -n "$APT_MIRROR_URL"; then \
	sed -i "s#http://archive.ubuntu.com#$APT_MIRROR_URL#; \
	s#http://security.ubuntu.com#$APT_MIRROR_URL#; \
	s#http://ports.ubuntu.com#$APT_MIRROR_URL#" \
	/etc/apt/sources.list; fi

RUN apt -y -q update && apt -y -q upgrade && \
	apt install -y -q unzip libtool-bin curl cmake gperf gawk flex bison \
	xxd fakeroot cpio git python-docutils gettext automake autopoint \
	texinfo build-essential help2man pkg-config zlib1g-dev libgmp3-dev libmpc-dev \
	libmpfr-dev libncurses5-dev libltdl-dev wget kmod sudo locales && \
	rm -rf /var/cache/apt/

RUN echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && locale-gen
ENV LANG en_US.utf8

# Prepare toolchain
COPY ./toolchain-mipsel /buildrom/toolchain-mipsel
WORKDIR /buildrom
RUN cd toolchain-mipsel && sh dl_toolchain.sh

# Run shell check
COPY ./trunk /buildrom/trunk
RUN sh /buildrom/trunk/tools/shellcheck.sh

# Start build
ARG BUILD_VARIANT=mt7621
ARG PRODUCT_NAME=K2P_nano
# ARG PRODUCT_NAME=K2P_nano-5.0

RUN cd trunk && \
	fakeroot ./build_firmware_modify "${PRODUCT_NAME}" && \
	mv /buildrom/trunk/images /buildrom/ && \
	./clear_tree_simple > /dev/null 2>&1

FROM scratch
COPY --from=buildstage /buildrom/images/K2P_3.4.3.9-099.trx .
