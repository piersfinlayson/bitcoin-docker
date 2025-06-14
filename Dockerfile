# syntax=docker/dockerfile:1

ARG XX_VERSION=1.6.1
ARG RUST_VERSION=1.89
ARG ALPINE_VERSION=3.22

FROM --platform=$BUILDPLATFORM tonistiigi/xx:${XX_VERSION} AS xx
FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS prebuild

# Do platform agnostic stuff

ARG CONT_VERSION
ARG BITCOIN_VERSION
ARG LIBEVENT_VERSION
ARG BOOST_VERSION
ARG BC_OPENSSL_VERSION

RUN apk add --no-cache autoconf automake bash clang git libtool lld m4 make perl pkgconfig wget
COPY --from=xx / /

RUN mkdir /build

# Get boost source
RUN cd /build && \
    git clone https://github.com/boostorg/boost --recursive
RUN cd /build/boost && \
    git checkout -f tags/boost-${BOOST_VERSION} && \
    git submodule update --init --recursive

# Get libevent source
RUN cd /build && \
    git clone https://github.com/libevent/libevent
RUN cd /build/libevent && \
    git checkout -f tags/release-${LIBEVENT_VERSION}-stable

# Get OpenSSL source
ENV TMP_OPENSSL_DIR=/build/openssl
RUN mkdir -p $TMP_OPENSSL_DIR && \
    cd $TMP_OPENSSL_DIR && \
    wget https://www.openssl.org/source/openssl-${BC_OPENSSL_VERSION}.tar.gz && \
    tar xzf openssl-${BC_OPENSSL_VERSION}.tar.gz && \
    rm openssl-${BC_OPENSSL_VERSION}.tar.gz && \
    mv openssl-${BC_OPENSSL_VERSION} openssl-src

# Get bitcoin source
RUN cd /build && \
    git clone https://github.com/bitcoin/bitcoin
RUN cd /build/bitcoin && \
    git checkout -f $BITCOIN_VERSION

# Start platform specific phase
FROM --platform=$BUILDPLATFORM prebuild AS build

ARG TARGETPLATFORM
ARG TARGETARCH
RUN xx-apk add --no-cache g++ gcc linux-headers musl-dev

RUN cd /build/openssl/openssl-src && \
    export CONFIGURE_FLAGS="no-shared no-zlib -fPIC no-ssl3" && \
    echo "Compiling openssl for architecture: $TARGETARCH" && \
    if [ $TARGETARCH = "amd64" ] || [ $TARGETARCH = "x86_64" ] ; \
    then \
        export CONFIGURE_FLAGS="$CONFIGURE_FLAGS linux-x86_64" ; \
    elif [ $TARGETARCH = "aarch64" ] || [ $TARGETARCH = "arm64" ] ; \
    then \
        export CONFIGURE_FLAGS="$CONFIGURE_FLAGS linux-aarch64 -march=armv8-a+crc+simd+fp" ; \
    elif [ $TARGETARCH = "arm" ] ; \
    then \
        VARIANT=$(xx-info variant) ; \
        echo "ARM variant: $VARIANT" ; \
        if [ $VARIANT == "v7" ] ; \
        then \
            export CONFIGURE_FLAGS="$CONFIGURE_FLAGS linux-armv4 -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard" ; \
        elif [ $VARIANT == "v6" ] ; \
        then \
            export CONFIGURE_FLAGS="$CONFIGURE_FLAGS linux-armv4 -march=armv6 -marm -mfpu=vfp" ; \
        else \
            echo "Unsupported variant" ; \
        fi \
    else \
        echo "Unsupported architecture" ; \
        exit 1 ; \
    fi && \
    ./config $CONFIGURE_FLAGS \
    --prefix=/usr/local/ssl --openssldir=/usr/local/ssl \
    CC=xx-clang CXX=xx-clang++ && \
    make -j8 depend && \
    make -j8 && \
    make install_sw

# Build and install boost
RUN cd /build/boost && \
    ./bootstrap.sh --with-toolset=clang --with-libraries=filesystem,system,test
RUN cd /build/boost && \
    CXX_VERSION=$(ls -d /usr/include/c++/* | awk -F'/' '{print $NF}') && \
    TARGET_TRIPLE=$(xx-info triple) && \
    echo "Using C++ $CXX_VERSION for target $TARGET_TRIPLE" && \
    ./b2 toolset=clang --host=$(xx-info alpine-arch) --target=$(xx-info triple) \
    link=static runtime-link=static -j8 \
    --with-filesystem --with-system --with-test --prefix=/$(xx-info triple)/usr/local/boost \
    cxxflags="-std=c++11 -stdlib=libc++ -I/usr/include/c++/$CXX_VERSION -I/usr/include/c++/$CXX_VERSION/x86_64-alpine-linux-musl -I/$TARGET_TRIPLE/usr/include" \
    linkflags="-stdlib=libc++"
RUN cd /build/boost && \
    ./b2 install toolset=clang --host=$(xx-info alpine-arch) --target=$(xx-info triple) \
    link=static runtime-link=static -j8 \
    --with-filesystem --with-system --with-test --prefix=/$(xx-info triple)/usr/local/boost \
    cxxflags="-std=c++11 -stdlib=libc++ -I/usr/include/c++/$CXX_VERSION -I/usr/include/c++/$CXX_VERSION/x86_64-alpine-linux-musl -I/$TARGET_TRIPLE/usr/include" \
    linkflags="-stdlib=libc++"

RUN apk add --no-cache cmake

# Build and install libevent using CMAKE (like Bitcoin's depends system)
RUN cd /build/libevent && \
    TARGET_TRIPLE=$(xx-info triple) && \
    cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/$TARGET_TRIPLE/usr/local/libevent \
    -DCMAKE_C_COMPILER=xx-clang \
    -DCMAKE_CXX_COMPILER=xx-clang++ \
    -DEVENT__DISABLE_BENCHMARK=ON \
    -DEVENT__DISABLE_OPENSSL=ON \
    -DEVENT__DISABLE_SAMPLES=ON \
    -DEVENT__DISABLE_REGRESS=ON \
    -DEVENT__DISABLE_TESTS=ON \
    -DEVENT__LIBRARY_TYPE=STATIC && \
    cmake --build build -j8 && \
    cmake --install build

# Build bitcoin
#
# There was lots of fiddling required to figure out how to get this to cross
# compile properly.  If something looks odd below, it was probably because 
# of this.
#
#RUN xx-apk add --no-cache pkgconfig
RUN cd /build/bitcoin && \
    xx-clang --setup-target-triple && \
    TARGET_TRIPLE=$(xx-info triple) && \
    if [ $TARGETARCH = "aarch64" ] || [ $TARGETARCH = "arm64" ] ; \
    then \
        export CXXFLAGS_EXTRA="-mno-outline-atomics" ; \
    elif [ $TARGETARCH = "arm" ] ; \
    then \
        export CXXFLAGS_EXTRA="-mno-outline-atomics" ; \
    else \
        export CXXFLAGS_EXTRA="" ; \
    fi && \
    cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/$TARGET_TRIPLE/usr/local/bitcoin \
    -DCMAKE_PREFIX_PATH="/$TARGET_TRIPLE/usr/local/boost;/$TARGET_TRIPLE/usr/local/libevent" \
    -DCMAKE_C_COMPILER="$TARGET_TRIPLE-clang" \
    -DCMAKE_CXX_COMPILER="$TARGET_TRIPLE-clang++" \
    -DBUILD_SHARED_LIBS=OFF \
    -DENABLE_WALLET=OFF \
    -DWITH_ZMQ=OFF \
    -DWITH_BDB=OFF \
    -DWITH_SQLITE=OFF \
    -DAPPEND_CXXFLAGS="$CXXFLAGS_EXTRA"
RUN cd /build/bitcoin && \
    cmake --build build -j8

# Can't run tests as likely cross-compiling

# Pull together required files
RUN cd /build/bitcoin && \
    cmake --install build
RUN mkdir /output/
RUN TARGET_TRIPLE=$(xx-info triple) && \
    cp /$TARGET_TRIPLE/usr/local/bitcoin/bin/bitcoind /output/ && \
    cp /$TARGET_TRIPLE/usr/local/bitcoin/bin/bitcoin-cli /output/ && \
    cp /$TARGET_TRIPLE/usr/local/bitcoin/bin/bitcoin-tx /output/ && \
    cp /$TARGET_TRIPLE/usr/local/bitcoin/bin/bitcoin-util /output/
RUN echo "Bitcoin Container Version: ${CONT_VERSION}\n"\
    "Platform: $BUILDPLATFORM\n"\
    "Built with software versions: \n"\
    "  bitcoin:  ${BITCOIN_VERSION}\n"\
    "  libevent: ${LIBEVENT_VERSION}\n"\
    "  boost:    ${BOOST_VERSION}\n"\
    "  openssl:  ${BC_OPENSSL_VERSION}"\
    > /output/versions.txt

FROM scratch

LABEL maintainer="Piers Finlayson <piers@piers.rocks>"
LABEL description="Bitcoin Node Container"

COPY --from=build /output/ /

EXPOSE 8333/tcp
VOLUME ["/bitcoin-data"]
CMD ["/bitcoind -conf=/bitcoin-data/bitcoin.conf"]
