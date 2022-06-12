#
# Container performing common (architecture agnostic) operators, such as
# getting the code at the right versions
#
FROM piersfinlayson/build:latest as pre-builder

LABEL maintainer="Piers Finlayson <piers@piersandkatie.com>"
LABEL description="Piers's Bitcoin Node Pre-Build Container"

# Delete stuff we don't want from build container
USER root
# Can remove this once move up to 0.3.7 of build container:
RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        bsdmainutils \
        checkinstall && \
    apt-get clean && \
    rm -fr /var/lib/apt/lists/*
RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt-get remove -y \
        libboost-dev \
        libboost-filesystem-dev \
        libboost-system-dev \
        libboost-test-dev \
        libevent-dev  && \
    rm -fr /usr/include/boost

ARG CONT_VERSION
ARG BITCOIN_VERSION
ARG LIBDB_VERSION
ARG LIBEVENT_VERSION
ARG LIBZMQ_VERSION
ARG BOOST_VERSION

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

LABEL maintainer="Piers Finlayson <piers@piersandkatie.com>"
LABEL description="Piers's Bitcoin Node Build Container (amd64)"

ARG CONT_VERSION
ARG BITCOIN_VERSION
ARG LIBDB_VERSION
ARG LIBEVENT_VERSION
ARG LIBZMQ_VERSION
ARG BOOST_VERSION

# Build boost, libevent and libzmq, install oost and create .debs for both
USER build
RUN cd /home/build/builds/boost && \
    ./bootstrap.sh && \
    ./b2 --with-filesystem --with-system --with-test
RUN cd /home/build/builds/boost && \
    sudo checkinstall \
        --pkgname=libboost \
        --pkgversion=$BOOST_VERSION \
        --pkgrelease=$CONT_VERSION \
        --pkglicense="Boost Software License" \
        --arch=amd64 \
        --maintainer=piers@piersandkatie.com \
        -y \
        --install=yes \
        ./b2 install --with-filesystem --with-system --with-test --prefix=/usr
RUN cd /home/build/builds/libevent && \
    LIBS="-ldl" PKG_CONFIG_PATH=/opt/openssl/openssl-x86_64-linux-gnu/lib/pkgconfig/ ./configure \
        --host=x86_64 \
        LDFLAGS="-L/opt/openssl/openssl-x86_64-linux-gnu/lib/" && \
    make -j 4
RUN cd /home/build/builds/libevent && \
    sudo checkinstall \
        --pkgname=libevent \
        --pkgversion=$LIBEVENT_VERSION \
        --pkgrelease=$CONT_VERSION \
        --pkglicense="3-clause BSD" \
        --arch=amd64 \
        --maintainer=piers@piersandkatie.com \
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
        --maintainer=piers@piersandkatie.com \
        -y \
        --install=yes

# Build Berkley DB source and create a .deb
RUN cd /home/build/builds/bitcoin && \
    ./contrib/install_db4.sh `pwd`
RUN cd /home/build/builds/bitcoin/db4/db-$LIBDB_VERSION/build_unix && \
    sudo checkinstall \
        --pkgname=libdb \
        --pkgversion=$LIBDB_VERSION \
        --pkgrelease=$CONT_VERSION \
        --pkglicense="Berkeley DB v4 License" \
        --maintainer=piers@piersandkatie.com \
        -y \
        --install=no
RUN cp /home/build/builds/bitcoin/db4/db-$LIBDB_VERSION/build_unix/libdb_$LIBDB_VERSION-${CONT_VERSION}_amd64.deb /home/build/builds/bitcoin

# Build bitcoin
# Have tried adding --with-boost-unit-test-framework=boost_unit_test_framework and BOOST_UNIT_TEST_FRAMEWORK_LIB="-lboost_unit_test_framework", but building with tests still doesn't work, so install boost unit_test_framework above
# Need to fix https://github.com/bitcoin/bitcoin/pull/23607 if using boost 1.78.0 
# RUN cd /home/build/builds/bitcoin && sed -i 's/(char\*\*)\&address/\&address/g' src/httpserver.cpp
ENV BDB_PREFIX='/home/build/builds/bitcoin/db4'
ENV EVENT_PREFIX='/home/build/builds/libevent'
RUN cd /home/build/builds/bitcoin && \
        ./configure \
        --host=x86_64 \
        BDB_LIBS="-L${BDB_PREFIX}/lib -ldb_cxx-4.8" BDB_CFLAGS="-I${BDB_PREFIX}/include" \
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
        --maintainer=piers@piersandkatie.com \
        -y \
        --install=no

#
# amd64 version of bitcoin container - installed dpkg from previous stage
#
FROM ubuntu:20.04 as bitcoin-amd64

LABEL maintainer="Piers Finlayson <piers@piersandkatie.com>"
LABEL description="Piers's Bitcoin Node Container (amd64)"

ARG CONT_VERSION
ARG BITCOIN_VERSION
ARG LIBDB_VERSION
ARG LIBEVENT_VERSION
ARG LIBZMQ_VERSION
ARG BOOST_VERSION

RUN useradd -ms /bin/false bitcoin 
RUN apt update && \
        DEBIAN_FRONTEND=noninteractive apt-get install -y \
                bsdmainutils && \
    apt-get clean && \
    rm -fr /var/lib/apt/lists/*
COPY --from=builder-amd64 /home/build/builds/bitcoin/libdb_$LIBDB_VERSION-${CONT_VERSION}_amd64.deb /home/bitcoin/
COPY --from=builder-amd64 /home/build/builds/bitcoin/bitcoin_$BITCOIN_VERSION-${CONT_VERSION}_amd64.deb /home/bitcoin/
COPY --from=builder-amd64 /home/build/builds/libevent/libevent_$LIBEVENT_VERSION-${CONT_VERSION}_amd64.deb /home/bitcoin/
COPY --from=builder-amd64 /home/build/builds/boost/libboost_$BOOST_VERSION-${CONT_VERSION}_amd64.deb /home/bitcoin/
COPY --from=builder-amd64 /home/build/builds/libzmq/libzmq_$LIBZMQ_VERSION-${CONT_VERSION}_amd64.deb /home/bitcoin/
RUN dpkg --install /home/bitcoin/libdb_$LIBDB_VERSION-${CONT_VERSION}_amd64.deb
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

LABEL maintainer="Piers Finlayson <piers@piersandkatie.com>"
LABEL description="Piers's Bitcoin Node Build Container (armv7l)"

ARG CONT_VERSION
ARG BITCOIN_VERSION
ARG LIBDB_VERSION
ARG LIBEVENT_VERSION
ARG LIBZMQ_VERSION
ARG BOOST_VERSION

USER root
RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        g++-arm-linux-gnueabihf && \
    apt-get clean && \
    rm -fr /var/lib/apt/lists/*

# Build boost, libevent and libzmq
USER build
RUN cd /home/build/builds/boost && \
    echo "using gcc : arm : arm-linux-gnueabihf-g++ ;" > /home/build/user-config.jam && \
    ./bootstrap.sh && \
    ./b2 toolset=gcc-arm --with-filesystem --with-system --with-test
RUN cd /home/build/builds/libevent && \
    LIBS="-ldl" PKG_CONFIG_PATH=/opt/openssl/openssl-armv7-linux-gnueabihf/lib/pkgconfig/ ./configure \
        --host=arm-linux-gnueabihf \
        LDFLAGS="-L/opt/openssl/openssl-armv7-linux-gnueabihf/lib/" && \
    make -j 4
RUN cd /home/build/builds/libzmq && \
    ./configure \
        --host=arm-linux-gnueabihf && \
    make -j 4 

# Build Berkley DB source and create a .deb
RUN cd /home/build/builds/bitcoin && \
    ./contrib/install_db4.sh `pwd` --host=arm-linux-gnueabihf
RUN cd /home/build/builds/bitcoin/db4/db-$LIBDB_VERSION/build_unix && \
    sudo checkinstall \
        --pkgname=libdb \
        --pkgversion=$LIBDB_VERSION \
        --pkgrelease=$CONT_VERSION \
        --pkglicense="Berkeley DB v4 License" \
        --maintainer=piers@piersandkatie.com \
        --arch=armhf \
        -y \
        --install=no
RUN cp /home/build/builds/bitcoin/db4/db-$LIBDB_VERSION/build_unix/libdb_$LIBDB_VERSION-${CONT_VERSION}_armhf.deb /home/build/builds/bitcoin

# Now build bitcoin with the armv7l boost (already got source in pre-builder)
ENV BDB_PREFIX='/home/build/builds/bitcoin/db4'
ENV EVENT_PREFIX='/home/build/builds/libevent'
ENV ZMQ_PREFIX='/home/build/builds/libzmq'
RUN cd /home/build/builds/bitcoin && \
    BOOST_ROOT=/home/build/builds/boost/ \
        PKG_CONFIG_PATH="/home/build/builds/libevent:/home/build/builds/libzmq" \
        ./configure \
        --with-boost=yes \
        --host=arm-linux-gnueabihf \
        BDB_LIBS="-L${BDB_PREFIX}/lib -ldb_cxx-4.8" BDB_CFLAGS="-I${BDB_PREFIX}/include" \
        EVENT_LIBS="-L${EVENT_PREFIX}/.libs -levent" EVENT_CFLAGS="-I${EVENT_PREFIX}/include" \
        ZMQ_LIBS="-L${ZMQ_PREFIX}/src/.libs -lzmq" ZMQ_CFLAGS="-I${ZMQ_PREFIX}/include" \
        LDFLAGS="-L/home/build/builds/boost/stage/lib/ -L/home/build/builds/bitcoin/db4/lib -L/usr/arm-linux-gnueabihf/lib/" \
        CPPFLAGS="-I/home/build/builds/boost -I/home/build/builds/bitcoin/db4/include -I${EVENT_PREFIX}/include" \
        --with-boost-filesystem=boost_filesystem \
        --with-boost-system=boost_system \
        --disable-tests \
        --enable-zmq \
        --with-seccomp=no
# Needed to fix https://github.com/bitcoin/bitcoin/pull/23607 
# RUN cd /home/build/builds/bitcoin && sed -i 's/(char\*\*)\&address/\&address/g' src/httpserver.cpp
RUN cd /home/build/builds/bitcoin && make -j 4
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
        --maintainer=piers@piersandkatie.com \
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
        --maintainer=piers@piersandkatie.com \
        -y \
        --install=no \
        ./b2 install toolset=gcc-arm --with-filesystem --with-system --with-test --prefix=/usr
RUN cd /home/build/builds/libevent && \
    sudo checkinstall \
        --pkgname=libevent \
        --pkgversion=$LIBEVENT_VERSION \
        --pkgrelease=$CONT_VERSION \
        --pkglicense="3-clause BSD" \
        --arch=armhf \
        --maintainer=piers@piersandkatie.com \
        -y \
        --install=no
RUN cd /home/build/builds/libzmq && \
    sudo checkinstall \
        --pkgname=libzmq \
        --pkgversion=$LIBZMQ_VERSION \
        --pkgrelease=$CONT_VERSION \
        --pkglicense="GPLv3" \
        --arch=armhf \
        --maintainer=piers@piersandkatie.com \
        -y \
        --install=no

#
# Create a container with just the ARM .debs in, which will then be used on ARM machine to build the real container
#
FROM scratch as bitcoin-image-only-armv7l
ARG BITCOIN_VERSION
ARG CONT_VERSION
ARG LIBDB_VERSION
ARG LIBEVENT_VERSION
ARG LIBZMQ_VERSION
ARG BOOST_VERSION
COPY --from=builder-armv7l /home/build/builds/bitcoin/bitcoin_$BITCOIN_VERSION-${CONT_VERSION}_armhf.deb /
COPY --from=builder-armv7l /home/build/builds/boost/libboost_$BOOST_VERSION-${CONT_VERSION}_armhf.deb /
COPY --from=builder-armv7l /home/build/builds/libevent/libevent_$LIBEVENT_VERSION-${CONT_VERSION}_armhf.deb /
COPY --from=builder-armv7l /home/build/builds/bitcoin/libdb_$LIBDB_VERSION-${CONT_VERSION}_armhf.deb /
COPY --from=builder-armv7l /home/build/builds/libzmq/libzmq_$LIBZMQ_VERSION-${CONT_VERSION}_armhf.deb /

#
# aarch64 version of the builder container - needs to install aarch64 version of g++ and get boost source code, then builds bitcoin and creates dpkg
#
FROM pre-builder as builder-aarch64

LABEL maintainer="Piers Finlayson <piers@piersandkatie.com>"
LABEL description="Piers's Bitcoin Node Build Container (aarch64)"

ARG CONT_VERSION
ARG BITCOIN_VERSION
ARG LIBDB_VERSION
ARG LIBEVENT_VERSION
ARG LIBZMQ_VERSION
ARG BOOST_VERSION

USER root
RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        g++-aarch64-linux-gnu && \
    apt-get clean && \
    rm -fr /var/lib/apt/lists/*

# Build boost, libevent and libzmq
USER build
RUN cd /home/build/builds/boost && \
    echo "using gcc : aarch64 : aarch64-linux-gnu-g++ ;" > /home/build/user-config.jam && \
    ./bootstrap.sh && \
    ./b2 toolset=gcc-aarch64 --with-filesystem --with-system --with-test

# Must build openssl for aarch64 (build container doesn't yet build for aarch64)
ENV PLATFORM=aarch64-linux-gnu
ENV TARGET_CONFIGURE_FLAGS="no-shared no-zlib -fPIC linux-aarch64"
ENV TARGET_DIR=$TMP_OPENSSL_DIR/openssl-$PLATFORM
ENV TMP_OPENSSL_DIR=/tmp/openssl
ENV OPENSSL_VERSION="1.1.1o"
RUN mkdir -p $TMP_OPENSSL_DIR && \
    cd $TMP_OPENSSL_DIR && \
    wget https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz && \
    tar xzf openssl-$OPENSSL_VERSION.tar.gz && \
    rm openssl-$OPENSSL_VERSION.tar.gz && \
    mv openssl-$OPENSSL_VERSION openssl-src
RUN cd ~/ && \
    cp -pr $TMP_OPENSSL_DIR/openssl-src working && \
    cd working && \
    env CC=$PLATFORM-gcc RANLIB=$PLATFORM-ranlib AR=$PLATFORM-ar LD=$PLATFORM-ld ./Configure --openssldir=$TARGET_DIR --prefix=$TARGET_DIR $TARGET_CONFIGURE_FLAGS && \
    env make $PARALLEL_MAKE depend && \
    env make $PARALLEL_MAKE && \
    env make install && \
    cd ~/ && \
    rm -fr working && \
    rm -fr $TMP_OPENSSL_DIR
ENV AARCH64_UNKNOWN_LINUX_GNU_OPENSSL_DIR=$TARGET_DIR
ENV AARCH64_UNKNOWN_LINUX_GNU_OPENSSL_LIB_DIR=$TARGET_DIR/lib
ENV AARCH64_UNKNOWN_LINUX_GNU_OPENSSL_INCLUDE_DIR=$TARGET_DIR/include

# Back to regular schedule ...
RUN cd /home/build/builds/libevent && \
    LIBS="-ldl" PKG_CONFIG_PATH=/opt/openssl/openssl-aarch64-linux-gnu/lib/pkgconfig/ ./configure \
        --host=aarch64-linux-gnu \
        LDFLAGS="-L/opt/openssl/openssl-aarch64-linux-gnu/lib/" && \
    make -j 4
RUN cd /home/build/builds/libzmq && \
    ./configure \
        --host=aarch64-linux-gnu && \
    make -j 4 

# Build Berkley DB source and create a .deb
RUN cd /home/build/builds/bitcoin && \
    ./contrib/install_db4.sh `pwd` --host=aarch64-linux-gnu
RUN cd /home/build/builds/bitcoin/db4/db-$LIBDB_VERSION/build_unix && \
    sudo checkinstall \
        --pkgname=libdb \
        --pkgversion=$LIBDB_VERSION \
        --pkgrelease=$CONT_VERSION \
        --pkglicense="Berkeley DB v4 License" \
        --maintainer=piers@piersandkatie.com \
        --arch=arm64 \
        -y \
        --install=no
RUN cp /home/build/builds/bitcoin/db4/db-$LIBDB_VERSION/build_unix/libdb_$LIBDB_VERSION-${CONT_VERSION}_aarch64.deb /home/build/builds/bitcoin

# Now build bitcoin with the aarch64 boost (already got source in pre-builder)
ENV BDB_PREFIX='/home/build/builds/bitcoin/db4'
ENV EVENT_PREFIX='/home/build/builds/libevent'
ENV ZMQ_PREFIX='/home/build/builds/libzmq'
RUN cd /home/build/builds/bitcoin && \
    BOOST_ROOT=/home/build/builds/boost/ \
        PKG_CONFIG_PATH="/home/build/builds/libevent:/home/build/builds/libzmq" \
        ./configure \
        --with-boost=yes \
        --host=aarch64-linux-gnu \
        BDB_LIBS="-L${BDB_PREFIX}/lib -ldb_cxx-4.8" BDB_CFLAGS="-I${BDB_PREFIX}/include" \
        EVENT_LIBS="-L${EVENT_PREFIX}/.libs -levent" EVENT_CFLAGS="-I${EVENT_PREFIX}/include" \
        ZMQ_LIBS="-L${ZMQ_PREFIX}/src/.libs -lzmq" ZMQ_CFLAGS="-I${ZMQ_PREFIX}/include" \
        LDFLAGS="-L/home/build/builds/boost/stage/lib/ -L/home/build/builds/bitcoin/db4/lib -L/usr/aarch64-linux-gnu/lib/" \
        CPPFLAGS="-I/home/build/builds/boost -I/home/build/builds/bitcoin/db4/include -I${EVENT_PREFIX}/include" \
        --with-boost-filesystem=boost_filesystem \
        --with-boost-system=boost_system \
        --disable-tests \
        --enable-zmq \
        --with-seccomp=no
# Needed to fix https://github.com/bitcoin/bitcoin/pull/23607 
# RUN cd /home/build/builds/bitcoin && sed -i 's/(char\*\*)\&address/\&address/g' src/httpserver.cpp
RUN cd /home/build/builds/bitcoin && make -j 4
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
        --maintainer=piers@piersandkatie.com \
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
        --maintainer=piers@piersandkatie.com \
        -y \
        --install=no \
        ./b2 install toolset=gcc-aarch64 --with-filesystem --with-system --with-test --prefix=/usr
RUN cd /home/build/builds/libevent && \
    sudo checkinstall \
        --pkgname=libevent \
        --pkgversion=$LIBEVENT_VERSION \
        --pkgrelease=$CONT_VERSION \
        --pkglicense="3-clause BSD" \
        --arch=arm64 \
        --maintainer=piers@piersandkatie.com \
        -y \
        --install=no
RUN cd /home/build/builds/libzmq && \
    sudo checkinstall \
        --pkgname=libzmq \
        --pkgversion=$LIBZMQ_VERSION \
        --pkgrelease=$CONT_VERSION \
        --pkglicense="GPLv3" \
        --arch=arm64 \
        --maintainer=piers@piersandkatie.com \
        -y \
        --install=no

#
# Create a container with just the ARM .debs in, which will then be used on ARM machine to build the real container
#
FROM scratch as bitcoin-image-only-aarch64
ARG BITCOIN_VERSION
ARG CONT_VERSION
ARG LIBDB_VERSION
ARG LIBEVENT_VERSION
ARG LIBZMQ_VERSION
ARG BOOST_VERSION
COPY --from=builder-aarch64 /home/build/builds/bitcoin/bitcoin_$BITCOIN_VERSION-${CONT_VERSION}_aarch64.deb /
COPY --from=builder-aarch64 /home/build/builds/boost/libboost_$BOOST_VERSION-${CONT_VERSION}_aarch64.deb /
COPY --from=builder-aarch64 /home/build/builds/libevent/libevent_$LIBEVENT_VERSION-${CONT_VERSION}_aarch64.deb /
COPY --from=builder-aarch64 /home/build/builds/bitcoin/libdb_$LIBDB_VERSION-${CONT_VERSION}_aarch64.deb /
COPY --from=builder-aarch64 /home/build/builds/libzmq/libzmq_$LIBZMQ_VERSION-${CONT_VERSION}_aarch64.deb /
