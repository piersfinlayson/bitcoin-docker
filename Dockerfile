FROM piersfinlayson/build:latest

LABEL maintainer="Piers Finlayson <piers@piersandkatie.com>"
LABEL description="Piers's Bitcoin Node Container"

# This stuff is included build:from 0.3.7 onwards
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

USER build
RUN cd /home/build/builds && \
	git clone https://github.com/bitcoin/bitcoin && \
	cd bitcoin && \
	./autogen.sh && \
	./configure && \
	./make
