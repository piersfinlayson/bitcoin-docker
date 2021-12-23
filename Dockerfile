FROM piersfinlayson/build:latest

LABEL maintainer="Piers Finlayson <piers@piersandkatie.com>"
LABEL description="Piers's Bitcoin Node Build Container"

# This stuff is included build:from 0.3.7 onwards
USER root
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
	make

FROM ubuntu:20.04

LABEL maintainer="Piers Finlayson <piers@piersandkatie.com>"
LABEL description="Piers's Bitcoin Node Container"

RUN useradd -ms /bin/bash bitcoin && \
    mkdir /home/bitcoin && \
    chown -R bitcoin:bitcoin /home/bitcoin
USER bitcoin
RUN mkdir /home/bitcoin/bin
COPY --from=0 /home/build/builds/bitcoin/bin/* /home/bitcoin/bin
CMD ["/bin/bash"]
