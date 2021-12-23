#
# Add bitcoin specific packages
#
FROM piersfinlayson/build:latest as pre-builder

LABEL maintainer="Piers Finlayson <piers@piersandkatie.com>"
LABEL description="Piers's Bitcoin Node Pre-Build Container"

# This stuff is included build:from 0.3.7 onwards
USER root
RUN apt update && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y \
                bsdmainutils \
		checkinstall \
                libboost-dev \
                libboost-filesystem-dev \
                libboost-system-dev \
                libboost-test-dev \
                libevent-dev && \
    apt-get clean && \
    rm -fr /var/lib/apt/lists/*

# Get bitcoin source
USER build
RUN cd /home/build/builds && \
	git clone https://github.com/bitcoin/bitcoin
USER root

#
# x86 version of the builder - builds the source and packages it up
#
FROM pre-builder as builder-amd64
LABEL description="Piers's Bitcoin Node Build Container (amd64)"
RUN cd /home/build/builds/bitcoin && \
	./autogen.sh && \
	./configure && \
	make -j 4
RUN cd /home/build/builds/bitcoin && \
	sudo checkinstall \
		--pkgname=bitcoin \
		--pkgversion=1 \
		--pkgrelease=1 \
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

RUN useradd -ms /bin/false bitcoin 
RUN apt update && \
        DEBIAN_FRONTEND=noninteractive apt-get install -y \
                bsdmainutils \
                libboost-dev \
                libboost-filesystem-dev \
                libboost-system-dev \
                libboost-test-dev \
                libevent-dev && \
    apt-get clean && \
    rm -fr /var/lib/apt/lists/*
COPY --from=builder-amd64 /home/build/builds/bitcoin/bitcoin_1-1_amd64.deb /home/bitcoin/
RUN dpkg --install /home/bitcoin/bitcoin_1-1_amd64.deb

USER bitcoin
VOLUME ["/bitcoin-data"]
CMD ["/usr/local/bin/bitcoind", "-conf=/bitcoin-data/bitcoin.conf"]

#
# arm32v7l version of the builder container - needs to install armv7l version of g++ and get boost source code, then builds bitcoin and creates dpkg
#
FROM pre-builder as builder-armv7l

LABEL maintainer="Piers Finlayson <piers@piersandkatie.com>"
LABEL description="Piers's Bitcoin Node Build Container (armv7l)"

# This stuff is included build:from 0.3.7 onwards
USER root
RUN apt update && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y \
		g++-arm-linux-gnueabihf && \
    apt-get clean && \
    rm -fr /var/lib/apt/lists/*

USER build
# Build boost and libevent from source for armv7l
RUN cd /home/build/builds && \
	git clone  https://github.com/boostorg/boost --recursive
RUN cd /home/build/builds/boost && \
	echo "using gcc : arm : arm-linux-gnueabihf-g++ ;" > /home/build/user-config.jam && \
	cd /home/build/builds/boost && \
	./bootstrap.sh && \
	./b2 link=static --with-filesystem --with-system --with-test
RUN cd /home/build/builds && \
	git clone https://github.com/libevent/libevent && \
	cd libevent && \
	./autogen.sh && \
	LIBS="-ldl" PKG_CONFIG_PATH=/opt/openssl/openssl-armv7-linux-gnueabihf/lib/pkgconfig/ ./configure \
		--host=arm-linux-gnueabihf \
		LDFLAGS="-L/opt/openssl/openssl-armv7-linux-gnueabihf/lib/" && \
	make -j 4

# TODO remove - temporary
USER root
RUN apt update && \
        DEBIAN_FRONTEND=noninteractive apt-get remove -y \
                libboost-dev \
                libboost-filesystem-dev \
                libboost-system-dev \
                libboost-test-dev && \
    apt-get clean && \
    rm -fr /var/lib/apt/lists/* && \
    rm -fr /usr/include/boost
USER build

# Now build bitcoin with the armv7l boost (already got source in pre-builder)
RUN cd /home/build/builds/bitcoin && \
	./autogen.sh && \
	BOOST_ROOT=/home/build/builds/boost/ \
		./configure \
		--with-boost=yes \
		--host=arm-linux-gnueabihf \
		LDFLAGS="-L/home/build/builds/libevent/.libs/ -L/usr/arm-linux-gnueabihf/lib/ -L/home/build/builds/boost/stage/lib/" \
		CPPFLAGS="-I/home/build/builds/boost" \
		--with-boost-filesystem=boost_filesystem \
		--with-boost-system=boost_system \
		--disable-tests \
		--with-seccomp=no && \
	make -j 4
RUN cd /home/build/builds/bitcoin && \
	sudo checkinstall \
		--pkgname=bitcoin \
		--pkgversion=1 \
		--pkgrelease=1 \
		--pkglicense=MIT \
		--arch=armv7l \
		--maintainer=piers@piersandkatie.com \
		-y \
		--install=no
FROM scratch as bitcoin-image-only-armv7l
COPY --from=builder-armv7l /home/build/builds/bitcoin/bitcoin_1-1_armv7l.deb /

#
# arm32v7l version of bitcoin container
#
FROM piersfinlayson/bitcoin-image-only-armv7l:latest as bitcoin-image-armv7l
FROM arm32v7/ubuntu:20.04 as bitcoin-armv7l

LABEL maintainer="Piers Finlayson <piers@piersandkatie.com>"
LABEL description="Piers's Bitcoin Node Container (armv7l)"

RUN useradd -ms /bin/false bitcoin
RUN apt update && \
        DEBIAN_FRONTEND=noninteractive apt-get install -y \
                bsdmainutils \
                libboost-dev \
                libboost-filesystem-dev \
                libboost-system-dev \
                libboost-test-dev \
                libevent-dev && \
    apt-get clean && \
    rm -fr /var/lib/apt/lists/*
COPY --from=bitcoin-image-armv7l /bitcoin_1-1_armv7l.deb /home/bitcoin/
RUN dpkg --install /home/bitcoin/bitcoin_1-1_armv7l.deb

USER bitcoin
VOLUME ["/bitcoin-data"]
CMD ["/usr/local/bin/bitcoind", "-conf=/bitcoin-data/bitcoin.conf"]
