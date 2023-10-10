#
# Container performing common (architecture agnostic) operators, such as
# getting the code at the right versions
#
FROM ubuntu:22.04 as pre-builder

LABEL maintainer="Piers Finlayson <piers@piers.rocks>"
LABEL description="Bitcoin Node Pre-Build Container"

USER root
RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        autoconf \
        automake \
        bsdmainutils \
        build-essential \
        checkinstall \
        git \
        libtool \
        m4 \
        pkg-config \
        sudo \
        wget && \
    apt-get clean && \
    rm -fr /var/lib/apt/lists/*

ARG CONT_VERSION
ARG BITCOIN_VERSION
ARG LIBEVENT_VERSION
ARG LIBZMQ_VERSION
ARG BOOST_VERSION
ARG BC_OPENSSL_VERSION

RUN echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/nopasswd
RUN useradd -ms /bin/bash build && \
    usermod -a -G sudo build && \
    mkdir /home/build/builds && \
    chown -R build:build /home/build/builds

# Get boost source
USER build
RUN cd /home/build/builds && \
    git clone https://github.com/boostorg/boost --recursive
RUN cd /home/build/builds/boost && \
    git checkout -f tags/boost-${BOOST_VERSION} && \
    git submodule update --init --recursive

# Get libevent source
RUN cd /home/build/builds && \
    git clone https://github.com/libevent/libevent
RUN cd /home/build/builds/libevent && \
    git checkout -f tags/release-${LIBEVENT_VERSION}-stable
RUN cd /home/build/builds/libevent && \
    ./autogen.sh

# Get libzmq source
RUN cd /home/build/builds && \
    git clone https://github.com/zeromq/libzmq
RUN cd /home/build/builds/libzmq && \
    git checkout -f tags/v${LIBZMQ_VERSION}
RUN cd /home/build/builds/libzmq && \
    ./autogen.sh

# Get OpenSSL source
ENV TMP_OPENSSL_DIR=/home/build/builds/openssl
RUN mkdir -p $TMP_OPENSSL_DIR && \
    cd $TMP_OPENSSL_DIR && \
    wget https://www.openssl.org/source/openssl-${BC_OPENSSL_VERSION}.tar.gz && \
    tar xzf openssl-${BC_OPENSSL_VERSION}.tar.gz && \
    rm openssl-${BC_OPENSSL_VERSION}.tar.gz && \
    mv openssl-${BC_OPENSSL_VERSION} openssl-src

# Get bitcoin source
USER build
RUN cd /home/build/builds && \
    git clone https://github.com/bitcoin/bitcoin

# Checkout right version of bitcoin
RUN cd /home/build/builds/bitcoin && \
    git checkout -f $BITCOIN_VERSION
RUN cd /home/build/builds/bitcoin && \
    ./autogen.sh

# Done
USER root

#
# x86 version of the builder - builds the source and packages it up
#
FROM pre-builder as builder-amd64

LABEL maintainer="Piers Finlayson <piers@piers.rocks>"
LABEL description="Bitcoin Node Build Container (amd64)"

ARG CONT_VERSION
ARG BITCOIN_VERSION
ARG LIBEVENT_VERSION
ARG LIBZMQ_VERSION
ARG BOOST_VERSION
ARG BC_OPENSSL_VERSION

USER build

# Build OpenSSL
ENV PLATFORM=x86_64-linux-gnu
ENV TARGET_CONFIGURE_FLAGS="no-shared no-zlib -fPIC linux-x86_64"
ENV TARGET_DIR=$TMP_OPENSSL_DIR/openssl-$PLATFORM
RUN cd ~/ && \
    cp -pr $TMP_OPENSSL_DIR/openssl-src working && \
    cd working && \
    env CC=$PLATFORM-gcc RANLIB=$PLATFORM-ranlib AR=$PLATFORM-ar LD=$PLATFORM-ld ./Configure --openssldir=$TARGET_DIR --prefix=$TARGET_DIR $TARGET_CONFIGURE_FLAGS && \
    make -j 4 depend && \
    make -j 4 && \
    make install && \
    cd ~/ && \
    rm -fr working

# Build boost, libevent and libzmq, install boost and create .debs for both
RUN cd /home/build/builds/boost && \
    ./bootstrap.sh && \
    ./b2 -j 4 --with-filesystem --with-system --with-test
RUN cd /home/build/builds/boost && \
    sudo checkinstall \
        --pkgname=libboost \
        --pkgversion=$BOOST_VERSION \
        --pkgrelease=$CONT_VERSION \
        --pkglicense="Boost Software License" \
        --arch=amd64 \
        --maintainer=piers@piers.rocks \
        -y \
        --install=yes \
        ./b2 install -j 4 --with-filesystem --with-system --with-test --prefix=/usr
RUN cd /home/build/builds/libevent && \
    LIBS="-ldl" PKG_CONFIG_PATH=${TARGET_DIR}/lib/pkgconfig/ ./configure \
        --host=x86_64 \
        LDFLAGS="-L${TARGET_DIR}/lib/" && \
    make -j 4
RUN cd /home/build/builds/libevent && \
    sudo checkinstall \
        --pkgname=libevent \
        --pkgversion=$LIBEVENT_VERSION \
        --pkgrelease=$CONT_VERSION \
        --pkglicense="3-clause BSD" \
        --arch=amd64 \
        --maintainer=piers@piers.rocks \
        -y \
        --install=no
RUN cd /home/build/builds/libzmq && \
    ./configure && \
    make -j 4
RUN cd /home/build/builds/libzmq && \
    sudo checkinstall \
        --pkgname=libzmq \
        --pkgversion=$LIBZMQ_VERSION \
        --pkgrelease=$CONT_VERSION \
        --pkglicense="GPLv3" \
        --arch=amd64 \
        --maintainer=piers@piers.rocks \
        -y \
        --install=yes

# Build bitcoin
# Have tried adding --with-boost-unit-test-framework=boost_unit_test_framework and BOOST_UNIT_TEST_FRAMEWORK_LIB="-lboost_unit_test_framework", but building with tests still doesn't work, so install boost unit_test_framework above
ENV EVENT_PREFIX='/home/build/builds/libevent'
RUN cd /home/build/builds/bitcoin && \
        ./configure \
        --host=x86_64 \
        EVENT_LIBS="-L${EVENT_PREFIX}/.libs -levent" EVENT_CFLAGS="-I${EVENT_PREFIX}/include"
RUN cd /home/build/builds/bitcoin && \
    make -j 4
#ENV LD_LIBRARY_PATH=/usr/local/lib
#RUN cd /home/build/builds/bitcoin && \
#    make check
RUN cd /home/build/builds/bitcoin && \
    sudo checkinstall \
        --pkgname=bitcoin \
        --pkgversion=$BITCOIN_VERSION \
        --pkgrelease=$CONT_VERSION \
        --pkglicense=MIT \
        --maintainer=piers@piers.rocks \
        -y \
        --install=no

#
# amd64 version of bitcoin container - installed dpkg from previous stage
#
FROM ubuntu:22.04 as bitcoin-amd64

LABEL maintainer="Piers Finlayson <piers@piers.rocks>"
LABEL description="Bitcoin Node Container (amd64)"

ARG CONT_VERSION
ARG BITCOIN_VERSION
ARG LIBEVENT_VERSION
ARG LIBZMQ_VERSION
ARG BOOST_VERSION
ARG BC_OPENSSL_VERSION

RUN useradd -ms /bin/false bitcoin 
RUN apt update && \
        DEBIAN_FRONTEND=noninteractive apt-get install -y \
                bsdmainutils && \
    apt-get clean && \
    rm -fr /var/lib/apt/lists/*
COPY --from=builder-amd64 /home/build/builds/bitcoin/bitcoin_$BITCOIN_VERSION-${CONT_VERSION}_amd64.deb /home/bitcoin/
COPY --from=builder-amd64 /home/build/builds/libevent/libevent_$LIBEVENT_VERSION-${CONT_VERSION}_amd64.deb /home/bitcoin/
COPY --from=builder-amd64 /home/build/builds/boost/libboost_$BOOST_VERSION-${CONT_VERSION}_amd64.deb /home/bitcoin/
COPY --from=builder-amd64 /home/build/builds/libzmq/libzmq_$LIBZMQ_VERSION-${CONT_VERSION}_amd64.deb /home/bitcoin/
RUN dpkg --install /home/bitcoin/bitcoin_$BITCOIN_VERSION-${CONT_VERSION}_amd64.deb
RUN dpkg --install /home/bitcoin/libevent_$LIBEVENT_VERSION-${CONT_VERSION}_amd64.deb
RUN dpkg --install /home/bitcoin/libboost_$BOOST_VERSION-${CONT_VERSION}_amd64.deb
RUN dpkg --install /home/bitcoin/libzmq_$LIBZMQ_VERSION-${CONT_VERSION}_amd64.deb

USER bitcoin
EXPOSE 8333/tcp
VOLUME ["/bitcoin-data"]
CMD ["/usr/local/bin/bitcoind", "-conf=/bitcoin-data/bitcoin.conf"]

#
# arm32v7l version of the builder container - needs to install armv7l version of g++ and get boost source code, then builds bitcoin and creates dpkg
#
FROM pre-builder as builder-armv7l

LABEL maintainer="Piers Finlayson <piers@piers.rocks>"
LABEL description="Bitcoin Node Build Container (armv7l)"

ARG CONT_VERSION
ARG BITCOIN_VERSION
ARG LIBEVENT_VERSION
ARG LIBZMQ_VERSION
ARG BOOST_VERSION
ARG BC_OPENSSL_VERSION
ARG ARM_TOOLCHAIN_VERSION

USER build

# Get ARM toolchain
ENV ARM_TOOLCHAIN_TARGET="arm-none-linux-gnueabihf"
ENV ARM_TOOLCHAIN="arm-gnu-toolchain-${ARM_TOOLCHAIN_VERSION}-x86_64-${ARM_TOOLCHAIN_TARGET}"
ENV ARM_TOOLCHAIN_URL_PREFIX="https://developer.arm.com/-/media/Files/downloads/gnu/${ARM_TOOLCHAIN_VERSION}/binrel"
ENV ARM_TOOLCHAIN_TAR="${ARM_TOOLCHAIN}.tar"
ENV ARM_TOOLCHAIN_URL_TAR_XZ="${ARM_TOOLCHAIN_URL_PREFIX}/${ARM_TOOLCHAIN_TAR}.xz"
ENV ARM_TOOLCHAIN_TAR_XZ="${ARM_TOOLCHAIN_TAR}.xz"
RUN cd /home/build/builds && \
    wget ${ARM_TOOLCHAIN_URL_TAR_XZ} -O ./${ARM_TOOLCHAIN_TAR_XZ} && \
    unxz ./${ARM_TOOLCHAIN_TAR_XZ} && \
    tar xf ./${ARM_TOOLCHAIN_TAR} && \
    rm ./${ARM_TOOLCHAIN_TAR}
ENV ARM_TOOLCHAIN_DIR=/home/build/builds/${ARM_TOOLCHAIN}
ENV ARM_TOOLCHAIN_BIN_PREFIX=${ARM_TOOLCHAIN_DIR}/bin/${ARM_TOOLCHAIN_TARGET}

# Build OpenSSL
ENV TARGET_CONFIGURE_FLAGS="no-shared no-zlib -fPIC linux-armv4 -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard"
ENV TARGET_DIR=$TMP_OPENSSL_DIR/openssl-${ARM_TOOLCHAIN_TARGET}
RUN cd ~/ && \
    cp -pr $TMP_OPENSSL_DIR/openssl-src working && \
    cd working && \
    env CC=${ARM_TOOLCHAIN_BIN_PREFIX}-gcc RANLIB=${ARM_TOOLCHAIN_BIN_PREFIX}-ranlib AR=${ARM_TOOLCHAIN_BIN_PREFIX}-ar LD=${ARM_TOOLCHAIN_BIN_PREFIX}-ld ./Configure --openssldir=$TARGET_DIR --prefix=$TARGET_DIR $TARGET_CONFIGURE_FLAGS && \
    make -j 4 depend && \
    make -j 4 && \
    make install && \
    cd ~/ && \
    rm -fr working

# Build boost, libevent and libzmq
RUN cd /home/build/builds/boost && \
    echo "using gcc : arm : ${ARM_TOOLCHAIN_BIN_PREFIX}-g++ ;" > /home/build/user-config.jam && \
    ./bootstrap.sh && \
    ./b2 -j 4 toolset=gcc-arm --with-filesystem --with-system --with-test
RUN cd /home/build/builds/libevent && \
    LIBS="-ldl" PKG_CONFIG_PATH=${TARGET_DIR}/lib/pkgconfig/ ./configure \
        --host=arm-linux-gnueabihf \
        CC=${ARM_TOOLCHAIN_BIN_PREFIX}-gcc \
        LD=${ARM_TOOLCHAIN_BIN_PREFIX}-ld \
        LDFLAGS="-L${TARGET_DIR}/lib/" && \
    make -j 4
RUN cd /home/build/builds/libzmq && \
    ./configure \
        --host=arm-linux-gnueabihf \
        CC=${ARM_TOOLCHAIN_BIN_PREFIX}-gcc \
        CXX=${ARM_TOOLCHAIN_BIN_PREFIX}-g++ \
        AR=${ARM_TOOLCHAIN_BIN_PREFIX}-ar \
        LD=${ARM_TOOLCHAIN_BIN_PREFIX}-ld && \
    make -j 4 

# Now build bitcoin with the armv7l boost (already got source in pre-builder)
ENV EVENT_PREFIX='/home/build/builds/libevent'
ENV ZMQ_PREFIX='/home/build/builds/libzmq'
RUN cd /home/build/builds/bitcoin && \
    BOOST_ROOT=/home/build/builds/boost/ \
        PKG_CONFIG_PATH="/home/build/builds/libevent:/home/build/builds/libzmq" \
        ./configure \
        --with-boost=yes \
        --host=arm-linux-gnueabihf \
        CC=${ARM_TOOLCHAIN_BIN_PREFIX}-gcc \
        CXX=${ARM_TOOLCHAIN_BIN_PREFIX}-g++ \
        AR=${ARM_TOOLCHAIN_BIN_PREFIX}-ar \
        LD=${ARM_TOOLCHAIN_BIN_PREFIX}-ld \
        EVENT_LIBS="-L${EVENT_PREFIX}/.libs -levent" EVENT_CFLAGS="-I${EVENT_PREFIX}/include" \
        ZMQ_LIBS="-L${ZMQ_PREFIX}/src/.libs -lzmq" ZMQ_CFLAGS="-I${ZMQ_PREFIX}/include" \
        LDFLAGS="-L/home/build/builds/boost/stage/lib/ -L${ARM_TOOLCHAIN_DIR}/lib/" \
        CPPFLAGS="-I/home/build/builds/boost -I${EVENT_PREFIX}/include" \
        --with-boost-filesystem=boost_filesystem \
        --with-boost-system=boost_system \
        --disable-tests \
        --enable-zmq \
        --with-seccomp=no

RUN cd /home/build/builds/bitcoin && \
    make -j 4

# Note that we don't build tests above, and we're cross-compiling, so make check doesn't do anything useful
#RUN cd /home/build/builds/bitcoin && \
#    LD_LIBRARY_PATH=/home/build/builds/boost/stage/lib \
#    make check

RUN cd /home/build/builds/bitcoin && \
    sudo checkinstall \
        --pkgname=bitcoin \
        --pkgversion=$BITCOIN_VERSION \
        --pkgrelease=$CONT_VERSION \
        --pkglicense=MIT \
        --arch=armhf \
        --maintainer=piers@piers.rocks \
        -y \
        --install=no

# For sudo b2 install to work need to put user-config.jam with arm gcc in /root
USER root
RUN cp /home/build/user-config.jam /root
USER build
RUN cd /home/build/builds/boost && \
    sudo checkinstall \
        --pkgname=libboost \
        --pkgversion=$BOOST_VERSION \
        --pkgrelease=$CONT_VERSION \
        --pkglicense="Boost Software License" \
        --arch=armhf \
        --maintainer=piers@piers.rocks \
        -y \
        --install=no \
        ./b2 install -j 4 toolset=gcc-arm --with-filesystem --with-system --with-test --prefix=/usr
RUN cd /home/build/builds/libevent && \
    sudo checkinstall \
        --pkgname=libevent \
        --pkgversion=$LIBEVENT_VERSION \
        --pkgrelease=$CONT_VERSION \
        --pkglicense="3-clause BSD" \
        --arch=armhf \
        --maintainer=piers@piers.rocks \
        -y \
        --install=no
RUN cd /home/build/builds/libzmq && \
    sudo checkinstall \
        --pkgname=libzmq \
        --pkgversion=$LIBZMQ_VERSION \
        --pkgrelease=$CONT_VERSION \
        --pkglicense="GPLv3" \
        --arch=armhf \
        --maintainer=piers@piers.rocks \
        -y \
        --install=no

#
# Create a container with just the ARM .debs in, which will then be used on ARM machine to build the real container
#
FROM scratch as bitcoin-image-only-armv7l
ARG BITCOIN_VERSION
ARG CONT_VERSION
ARG LIBEVENT_VERSION
ARG LIBZMQ_VERSION
ARG BOOST_VERSION
ARG BC_OPENSSL_VERSION

COPY --from=builder-armv7l /home/build/builds/bitcoin/bitcoin_$BITCOIN_VERSION-${CONT_VERSION}_armhf.deb /
COPY --from=builder-armv7l /home/build/builds/boost/libboost_$BOOST_VERSION-${CONT_VERSION}_armhf.deb /
COPY --from=builder-armv7l /home/build/builds/libevent/libevent_$LIBEVENT_VERSION-${CONT_VERSION}_armhf.deb /
COPY --from=builder-armv7l /home/build/builds/libzmq/libzmq_$LIBZMQ_VERSION-${CONT_VERSION}_armhf.deb /

#
# aarch64 version of the builder container - needs to install aarch64 version of g++ and get boost source code, then builds bitcoin and creates dpkg
#
FROM pre-builder as builder-aarch64

LABEL maintainer="Piers Finlayson <piers@piers.rocks>"
LABEL description="Bitcoin Node Build Container (aarch64)"

ARG CONT_VERSION
ARG BITCOIN_VERSION
ARG LIBEVENT_VERSION
ARG LIBZMQ_VERSION
ARG BOOST_VERSION
ARG BC_OPENSSL_VERSION
ARG ARM_TOOLCHAIN_VERSION

USER build

# Get ARM toolchain
ENV ARM_TOOLCHAIN_TARGET="aarch64-none-linux-gnueabihf"
ENV ARM_TOOLCHAIN="arm-gnu-toolchain-${ARM_TOOLCHAIN_VERSION}-x86_64-${ARM_TOOLCHAIN_TARGET}"
ENV ARM_TOOLCHAIN_URL_PREFIX="https://developer.arm.com/-/media/Files/downloads/gnu/${ARM_TOOLCHAIN_VERSION}/binrel"
ENV ARM_TOOLCHAIN_TAR="${ARM_TOOLCHAIN}.tar"
ENV ARM_TOOLCHAIN_URL_TAR_XZ="${ARM_TOOLCHAIN_URL_PREFIX}/${ARM_TOOLCHAIN_TAR}.xz"
ENV ARM_TOOLCHAIN_TAR_XZ="${ARM_TOOLCHAIN_TAR}.xz"
RUN cd /home/build/builds && \
    wget ${ARM_TOOLCHAIN_URL_TAR_XZ} -O ./${ARM_TOOLCHAIN_TAR_XZ} && \
    unxz ./${ARM_TOOLCHAIN_TAR_XZ} && \
    tar xf ./${ARM_TOOLCHAIN_TAR} && \
    rm ./${ARM_TOOLCHAIN_TAR}
ENV ARM_TOOLCHAIN_DIR=/home/build/builds/${ARM_TOOLCHAIN}
ENV ARM_TOOLCHAIN_BIN_PREFIX=${ARM_TOOLCHAIN_DIR}/bin/${ARM_TOOLCHAIN_TARGET}

# Build OpenSSL
ENV TARGET_CONFIGURE_FLAGS="no-shared no-zlib -fPIC linux-armv4 -march=armv8-a -mfpu=vfpv3-d16 -mfloat-abi=hard"
ENV TARGET_DIR=$TMP_OPENSSL_DIR/openssl-${ARM_TOOLCHAIN_TARGET}
RUN cd ~/ && \
    cp -pr $TMP_OPENSSL_DIR/openssl-src working && \
    cd working && \
    env CC=${ARM_TOOLCHAIN_BIN_PREFIX}-gcc RANLIB=${ARM_TOOLCHAIN_BIN_PREFIX}-ranlib AR=${ARM_TOOLCHAIN_BIN_PREFIX}-ar LD=${ARM_TOOLCHAIN_BIN_PREFIX}-ld ./Configure --openssldir=$TARGET_DIR --prefix=$TARGET_DIR $TARGET_CONFIGURE_FLAGS && \
    make -j 4 depend && \
    make -j 4 && \
    make install && \
    cd ~/ && \
    rm -fr working

# Build boost, libevent and libzmq
RUN cd /home/build/builds/boost && \
    echo "using gcc : aarch64 : ${ARM_TOOLCHAIN_BIN_PREFIX}-g++ ;" > /home/build/user-config.jam && \
    ./bootstrap.sh && \
    ./b2 -j 4 toolset=gcc-aarch64 --with-filesystem --with-system --with-test
RUN cd /home/build/builds/libevent && \
    LIBS="-ldl" PKG_CONFIG_PATH=${TARGET_DIR}/lib/pkgconfig/ ./configure \
        --host=aarch64-linux-gnueabihf \
        CC=${ARM_TOOLCHAIN_BIN_PREFIX}-gcc \
        LD=${ARM_TOOLCHAIN_BIN_PREFIX}-ld \
        LDFLAGS="-L${TARGET_DIR}/lib/" && \
    make -j 4
RUN cd /home/build/builds/libzmq && \
    ./configure \
        --host=aarch64-linux-gnueabihf \
        CC=${ARM_TOOLCHAIN_BIN_PREFIX}-gcc \
        CXX=${ARM_TOOLCHAIN_BIN_PREFIX}-g++ \
        AR=${ARM_TOOLCHAIN_BIN_PREFIX}-ar \
        LD=${ARM_TOOLCHAIN_BIN_PREFIX}-ld && \
    make -j 4

# Now build bitcoin with the aarch64 boost (already got source in pre-builder)
ENV EVENT_PREFIX='/home/build/builds/libevent'
ENV ZMQ_PREFIX='/home/build/builds/libzmq'
RUN cd /home/build/builds/bitcoin && \
    BOOST_ROOT=/home/build/builds/boost/ \
        PKG_CONFIG_PATH="/home/build/builds/libevent:/home/build/builds/libzmq" \
        ./configure \
        --with-boost=yes \
        --host=aarch64-linux-gnu \
        EVENT_LIBS="-L${EVENT_PREFIX}/.libs -levent" EVENT_CFLAGS="-I${EVENT_PREFIX}/include" \
        ZMQ_LIBS="-L${ZMQ_PREFIX}/src/.libs -lzmq" ZMQ_CFLAGS="-I${ZMQ_PREFIX}/include" \
        LDFLAGS="-L/home/build/builds/boost/stage/lib/ -L/usr/aarch64-linux-gnu/lib/" \
        CPPFLAGS="-I/home/build/builds/boost -I${EVENT_PREFIX}/include" \
        --with-boost-filesystem=boost_filesystem \
        --with-boost-system=boost_system \
        --disable-tests \
        --enable-zmq \
        --with-seccomp=no

RUN cd /home/build/builds/bitcoin && \
    make -j 4

# Note that we don't build tests above, and we're cross-compiling, so make check doesn't do anything useful
#RUN cd /home/build/builds/bitcoin && \
#    LD_LIBRARY_PATH=/home/build/builds/boost/stage/lib \
#    make check

RUN cd /home/build/builds/bitcoin && \
    sudo checkinstall \
        --pkgname=bitcoin \
        --pkgversion=$BITCOIN_VERSION \
        --pkgrelease=$CONT_VERSION \
        --pkglicense=MIT \
        --arch=arm64 \
        --maintainer=piers@piers.rocks \
        -y \
        --install=no

# For sudo b2 install to work need to put user-config.jam with aarch64 gcc in /root
USER root
RUN cp /home/build/user-config.jam /root
USER build
RUN cd /home/build/builds/boost && \
    sudo checkinstall \
        --pkgname=libboost \
        --pkgversion=$BOOST_VERSION \
        --pkgrelease=$CONT_VERSION \
        --pkglicense="Boost Software License" \
        --arch=arm64 \
        --maintainer=piers@piers.rocks \
        -y \
        --install=no \
        ./b2 -j 4 install toolset=gcc-aarch64 --with-filesystem --with-system --with-test --prefix=/usr
RUN cd /home/build/builds/libevent && \
    sudo checkinstall \
        --pkgname=libevent \
        --pkgversion=$LIBEVENT_VERSION \
        --pkgrelease=$CONT_VERSION \
        --pkglicense="3-clause BSD" \
        --arch=arm64 \
        --maintainer=piers@piers.rocks \
        -y \
        --install=no
RUN cd /home/build/builds/libzmq && \
    sudo checkinstall \
        --pkgname=libzmq \
        --pkgversion=$LIBZMQ_VERSION \
        --pkgrelease=$CONT_VERSION \
        --pkglicense="GPLv3" \
        --arch=arm64 \
        --maintainer=piers@piers.rocks \
        -y \
        --install=no

#
# Create a container with just the ARM .debs in, which will then be used on ARM machine to build the real container
#
FROM scratch as bitcoin-image-only-aarch64
ARG BITCOIN_VERSION
ARG CONT_VERSION
ARG LIBEVENT_VERSION
ARG LIBZMQ_VERSION
ARG BOOST_VERSION
ARG BC_OPENSSL_VERSION

COPY --from=builder-aarch64 /home/build/builds/bitcoin/bitcoin_$BITCOIN_VERSION-${CONT_VERSION}_arm64.deb /
COPY --from=builder-aarch64 /home/build/builds/boost/libboost_$BOOST_VERSION-${CONT_VERSION}_arm64.deb /
COPY --from=builder-aarch64 /home/build/builds/libevent/libevent_$LIBEVENT_VERSION-${CONT_VERSION}_arm64.deb /
COPY --from=builder-aarch64 /home/build/builds/libzmq/libzmq_$LIBZMQ_VERSION-${CONT_VERSION}_arm64.deb /
