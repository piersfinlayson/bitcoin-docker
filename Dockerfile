FROM piersfinlayson/build:latest

LABEL maintainer="Piers Finlayson <piers@piersandkatie.com>"
LABEL description="Piers's Bitcoin Node Build Container"

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

USER build
RUN cd /home/build/builds && \
	git clone https://github.com/bitcoin/bitcoin
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
#RUN cd /home/build/builds && \
#	tar zcvf bitcoin-sw.tgz bitcoin/

FROM ubuntu:20.04

LABEL maintainer="Piers Finlayson <piers@piersandkatie.com>"
LABEL description="Piers's Bitcoin Node Container"

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
COPY --from=0 /home/build/builds/bitcoin/bitcoin_1-1_amd64.deb /home/bitcoin/
RUN dpkg --install /home/bitcoin/bitcoin_1-1_amd64.deb
#COPY --from=0 /home/build/builds/bitcoin-sw.tgz /home/bitcoin/
#RUN cd /home/bitcoin && \
#	tar zxvf bitcoin-sw.tgz
USER bitcoin
VOLUME ["/bitcoin-data"]
CMD ["/usr/local/bin/bitcoind", "-conf=/bitcoin-data/bitcoin.conf"]
