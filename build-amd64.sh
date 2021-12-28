#!/bin/bash
set -e
BITCOIN_VERSION=$1
if [ -z $BITCOIN_VERSION ]
then
	echo "Usage build-arch.sh BITCOIN_VERSION CONTAINER_VERSION"
	exit
else
	echo Building bitcoin version $BITCOIN_VERSION
fi
CONT_VERSION=$2
if [ -z $CONT_VERSION ]
then
	echo "Usage build-arch.sh BITCOIN_VERSION CONTAINER_VERSION"
	exit
else
	echo Building container version $CONT_VERSION
fi
ARCH=`arch`
EXPECTED_ARCH='x86_64'
if [ "x$ARCH" != "x$EXPECTED_ARCH" ]
then
    echo Must be run on an $EXPECTED_ARCH platform - this is an $ARCH platform
    exit
fi

. ./DEPENDENCIES.sh

# Forcibly get the latest build container
docker pull piersfinlayson/build:latest

# Build the amd64 version - including latest
docker build \
    --progress=plain \
    --build-arg LIBEVENT_VERSION=$LIBEVENT_VERSION \
    --build-arg LIBDB_VERSION=$LIBDBVERSION \
    --build-arg LIBZMQ_VERSION=$LIBZMQ_VERSION \
    --build-arg BOOST_VERSION=$BOOST_VERSION \
    --build-arg CONT_VERSION=$CONT_VERSION \
    --build-arg BITCOIN_VERSION=$BITCOIN_VERSION \
    --target bitcoin-amd64 \
    -t piersfinlayson/bitcoin-amd64:$CONT_VERSION \
    .
docker tag piersfinlayson/bitcoin-amd64:$CONT_VERSION piersfinlayson/bitcoin-amd64:latest
echo "Successfully built piersfinlayson/bitcoin-amd64:$CONT_VERSION"

# Build the armv7l image only version - don't bother with latest
docker build \
    --progress=plain \
    --build-arg LIBEVENT_VERSION=$LIBEVENT_VERSION \
    --build-arg LIBDB_VERSION=$LIBDBVERSION \
    --build-arg LIBZMQ_VERSION=$LIBZMQ_VERSION \
    --build-arg BOOST_VERSION=$BOOST_VERSION \
    --build-arg CONT_VERSION=$CONT_VERSION \
    --build-arg BITCOIN_VERSION=$BITCOIN_VERSION \
    --target bitcoin-image-only-armv7l  \
    -t piersfinlayson/bitcoin-image-only-armv7l:$CONT_VERSION \
    .
echo "Successfully built piersfinlayson/bitcoin-image-only-armv7l:$CONT_VERSION"

# Push both versions
docker login -u piersfinlayson
docker push piersfinlayson/bitcoin-amd64:$CONT_VERSION
docker push piersfinlayson/bitcoin-amd64:latest
docker push piersfinlayson/bitcoin-image-only-armv7l:$CONT_VERSION
echo Now you need to build the armv7l version on an armv7l machine using the following command:
echo ./build-armv7l.sh $BITCOIN_VERSION $CONT_VERSION