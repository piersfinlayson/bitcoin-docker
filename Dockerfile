FROM piersfinlayson/build:latest

LABEL maintainer="Piers Finlayson <piers@piersandkatie.com>"
LABEL description="Piers's Bitcoin Node Container"

USER build
RUN cd /home/build/builds && \
	git clone https://github.com/bitcoin/bitcoin && \
	cd bitcoin && \
	./autogen.sh && \
	./configure && \
	./make
