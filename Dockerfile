#
# Add bitcoin specific packages
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

# Get boost source
USER build
RUN cd /home/build/builds && \
	git clone https://github.com/boostorg/boost --recursive

# Get libevent source
RUN cd /home/build/builds && \
	git clone https://github.com/libevent/libevent
RUN cd /home/build/builds/libevent && \
    ./autogen.sh

# Get bitcoin source
USER build
RUN cd /home/build/builds && \
	git clone https://github.com/bitcoin/bitcoin

# Checkout right version of bitcoin
ARG BITCOIN_VERSION
RUN cd /home/build/builds/bitcoin && \
    git checkout $BITCOIN_VERSION && \
    ./autogen.sh

# Done
USER root

#
# x86 version of the builder - builds the source and packages it up
#
FROM pre-builder as builder-amd64
LABEL description="Piers's Bitcoin Node Build Container (amd64)"

# Build boost and libevent
USER build
RUN cd /home/build/builds/boost && \
	./bootstrap.sh && \
	./b2 --with-filesystem --with-system --with-test
RUN cd /home/build/builds/libevent && \
	LIBS="-ldl" PKG_CONFIG_PATH=/opt/openssl/openssl-x86_64-linux-gnu/lib/pkgconfig/ ./configure \
		--host=x86_64 \
		LDFLAGS="-L/opt/openssl/openssl-x86_64-linux-gnu/lib/" && \
	make -j 2

# Build Berkley DB source and create a .deb
RUN cd /home/build/builds/bitcoin && \
    ./contrib/install_db4.sh `pwd`
ARG LIBDB_VERSION=4.8.30.NC
ARG CONT_VERSION
RUN cd /home/build/builds/bitcoin/db4/db-$LIBDB_VERSION/build_unix && \
    sudo checkinstall \
		--pkgname=libdb \
		--pkgversion=$LIBDB_VERSION \
		--pkgrelease=$CONT_VERSION \
		--pkglicense=MIT \
		--maintainer=piers@piersandkatie.com \
		-y \
		--install=no
RUN cp /home/build/builds/bitcoin/db4/db-$LIBDB_VERSION/build_unix/libdb_$LIBDB_VERSION-${CONT_VERSION}_amd64.deb /home/build/builds/bitcoin

# Build bitcoin
RUN cd /home/build/builds/bitcoin && \
	BOOST_ROOT=/home/build/builds/boost/ \
        PKG_CONFIG_PATH=/home/build/builds/libevent \
        LIBS="-levent" \
		./configure \
		--with-boost=yes \
		--host=x86_64 \
		LDFLAGS="-L/home/build/builds/libevent/.libs/ -L/home/build/builds/boost/stage/lib/ -L/home/build/builds/bitcoin/db4/lib -L/usr/lib/gcc/x86_64-linux-gnu/9" \
		CPPFLAGS="-I/home/build/builds/boost -I/home/build/builds/bitcoin/db4/include -I/home/build/builds/libevent/include" \
		--with-boost-filesystem=boost_filesystem \
		--with-boost-system=boost_system \
        --disable-tests
# Needed to fix https://github.com/bitcoin/bitcoin/pull/23607
RUN cd /home/build/builds/bitcoin && sed -i 's/(char\*\*)\&address/\&address/g' src/httpserver.cpp
RUN	cd /home/build/builds/bitcoin && make -j 2
RUN cd /home/build/builds/bitcoin && \
    make check
ARG BITCOIN_VERSION
RUN cd /home/build/builds/bitcoin && \
	sudo checkinstall \
		--pkgname=bitcoin \
		--pkgversion=$BITCOIN_VERSION \
		--pkgrelease=$CONT_VERSION \
		--pkglicense=MIT \
		--maintainer=piers@piersandkatie.com \
		-y \
		--install=no

# Build boost and libevent packages
RUN cd /home/build/builds/boost && \
	sudo checkinstall \
		--pkgname=libboost \
		--pkgversion=$BITCOIN_VERSION \
		--pkgrelease=$CONT_VERSION \
		--pkglicense=MIT \
		--arch=amd64 \
		--maintainer=piers@piersandkatie.com \
		-y \
		--install=no \
		./b2 install --with-filesystem --with-system --with-test --prefix=/usr
RUN cd /home/build/builds/libevent && \
	sudo checkinstall \
		--pkgname=libevent \
		--pkgversion=$BITCOIN_VERSION \
		--pkgrelease=$CONT_VERSION \
		--pkglicense=MIT \
		--arch=amd64 \
		--maintainer=piers@piersandkatie.com \
		-y \
		--install=no

#
# amd64 version of bitcoin container - installed dpkg from previous stage
#
FROM ubuntu:20.04 as bitcoin-amd64

LABEL description="Piers's Bitcoin Node Container (amd64)"

RUN useradd -ms /bin/false bitcoin 
RUN apt update && \
        DEBIAN_FRONTEND=noninteractive apt-get install -y \
                bsdmainutils && \
    apt-get clean && \
    rm -fr /var/lib/apt/lists/*
ARG LIBDB_VERSION=4.8.30.NC
ARG CONT_VERSION
ARG BITCOIN_VERSION
COPY --from=builder-amd64 /home/build/builds/bitcoin/libdb_$LIBDB_VERSION-${CONT_VERSION}_amd64.deb /home/bitcoin/
COPY --from=builder-amd64 /home/build/builds/bitcoin/bitcoin_$BITCOIN_VERSION-${CONT_VERSION}_amd64.deb /home/bitcoin/
COPY --from=builder-amd64 /home/build/builds/libevent/libevent_$BITCOIN_VERSION-${CONT_VERSION}_amd64.deb /home/bitcoin/
COPY --from=builder-amd64 /home/build/builds/boost/libboost_$BITCOIN_VERSION-${CONT_VERSION}_amd64.deb /home/bitcoin/
RUN dpkg --install /home/bitcoin/libdb_$LIBDB_VERSION-${CONT_VERSION}_amd64.deb
RUN dpkg --install /home/bitcoin/bitcoin_$BITCOIN_VERSION-${CONT_VERSION}_amd64.deb
RUN dpkg --install /home/bitcoin/libevent_$BITCOIN_VERSION-${CONT_VERSION}_amd64.deb
RUN dpkg --install /home/bitcoin/libboost_$BITCOIN_VERSION-${CONT_VERSION}_amd64.deb

USER bitcoin
EXPOSE 8333/tcp
VOLUME ["/bitcoin-data"]
CMD ["/usr/local/bin/bitcoind", "-conf=/bitcoin-data/bitcoin.conf"]

#
# arm32v7l version of the builder container - needs to install armv7l version of g++ and get boost source code, then builds bitcoin and creates dpkg
#
FROM pre-builder as builder-armv7l

LABEL description="Piers's Bitcoin Node Build Container (armv7l)"

USER root
RUN apt update && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y \
		g++-arm-linux-gnueabihf && \
    apt-get clean && \
    rm -fr /var/lib/apt/lists/*

# Build boost and libevent
USER build
RUN cd /home/build/builds/boost && \
	echo "using gcc : arm : arm-linux-gnueabihf-g++ ;" > /home/build/user-config.jam && \
	./bootstrap.sh && \
    ./b2 toolset=gcc-arm --with-filesystem --with-system --with-test
RUN cd /home/build/builds/libevent && \
	LIBS="-ldl" PKG_CONFIG_PATH=/opt/openssl/openssl-armv7-linux-gnueabihf/lib/pkgconfig/ ./configure \
		--host=arm-linux-gnueabihf \
		LDFLAGS="-L/opt/openssl/openssl-armv7-linux-gnueabihf/lib/" && \
	make -j 2

# Build Berkley DB source and create a .deb
RUN cd /home/build/builds/bitcoin && \
    ./contrib/install_db4.sh `pwd` --host=arm-linux-gnueabihf
ARG LIBDB_VERSION=4.8.30.NC
ARG CONT_VERSION
RUN cd /home/build/builds/bitcoin/db4/db-$LIBDB_VERSION/build_unix && \
    sudo checkinstall \
		--pkgname=libdb \
		--pkgversion=$LIBDB_VERSION \
		--pkgrelease=$CONT_VERSION \
		--pkglicense=MIT \
		--maintainer=piers@piersandkatie.com \
        --arch=armhf \
		-y \
		--install=no
RUN cp /home/build/builds/bitcoin/db4/db-$LIBDB_VERSION/build_unix/libdb_$LIBDB_VERSION-${CONT_VERSION}_armhf.deb /home/build/builds/bitcoin

# Now build bitcoin with the armv7l boost (already got source in pre-builder)
RUN cd /home/build/builds/bitcoin && \
	BOOST_ROOT=/home/build/builds/boost/ \
        PKG_CONFIG_PATH=/home/build/builds/libevent \
        LIBS="-levent" \
		./configure \
		--with-boost=yes \
		--host=arm-linux-gnueabihf \
		LDFLAGS="-L/home/build/builds/libevent/.libs/ -L/home/build/builds/boost/stage/lib/ -L/home/build/builds/bitcoin/db4/lib -L/usr/arm-linux-gnueabihf/lib/" \
		CPPFLAGS="-I/home/build/builds/boost -I/home/build/builds/bitcoin/db4/include -I/home/build/builds/libevent/include" \
		--with-boost-filesystem=boost_filesystem \
		--with-boost-system=boost_system \
		--disable-tests \
		--with-seccomp=no
# Needed to fix https://github.com/bitcoin/bitcoin/pull/23607
RUN cd /home/build/builds/bitcoin && sed -i 's/(char\*\*)\&address/\&address/g' src/httpserver.cpp
RUN	cd /home/build/builds/bitcoin && make -j 2
RUN cd /home/build/builds/bitcoin && \
    make check
ARG BITCOIN_VERSION
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
		--pkgversion=$BITCOIN_VERSION \
		--pkgrelease=$CONT_VERSION \
		--pkglicense=MIT \
		--arch=armhf \
		--maintainer=piers@piersandkatie.com \
		-y \
		--install=no \
		./b2 install toolset=gcc-arm --with-filesystem --with-system --with-test --prefix=/usr
RUN cd /home/build/builds/libevent && \
	sudo checkinstall \
		--pkgname=libevent \
		--pkgversion=$BITCOIN_VERSION \
		--pkgrelease=$CONT_VERSION \
		--pkglicense=MIT \
		--arch=armhf \
		--maintainer=piers@piersandkatie.com \
		-y \
		--install=no

FROM scratch as bitcoin-image-only-armv7l
ARG BITCOIN_VERSION
ARG CONT_VERSION
ARG LIBDB_VERSION=4.8.30.NC
COPY --from=builder-armv7l /home/build/builds/bitcoin/bitcoin_$BITCOIN_VERSION-${CONT_VERSION}_armhf.deb /
COPY --from=builder-armv7l /home/build/builds/boost/libboost_$BITCOIN_VERSION-${CONT_VERSION}_armhf.deb /
COPY --from=builder-armv7l /home/build/builds/libevent/libevent_$BITCOIN_VERSION-${CONT_VERSION}_armhf.deb /
COPY --from=builder-armv7l /home/build/builds/bitcoin/libdb_$LIBDB_VERSION-${CONT_VERSION}_armhf.deb /

