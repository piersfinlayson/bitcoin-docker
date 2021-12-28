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
EXPECTED_ARCH='armv7l'
if [ "x$ARCH" != "x$EXPECTED_ARCH" ]
then
    echo Must be run on an $EXPECTED_ARCH platform - this is an $ARCH platform
    exit
fi

. ./DEPENDENCIES.sh

docker pull piersfinlayson/bitcoin-image-only-armv7l:$CONT_VERSION
docker build \
    --progress=plain \
    --build-arg LIBEVENT_VERSION=$LIBEVENT_VERSION \
    --build-arg LIBDB_VERSION=$LIBD_VERSION \
    --build-arg LIBZMQ_VERSION=$LIBZMQ_VERSION \
    --build-arg BOOST_VERSION=$BOOST_VERSION \
    --build-arg CONT_VERSION=$CONT_VERSION \
    --build-arg BITCOIN_VERSION=$BITCOIN_VERSION \
    --target bitcoin-armv7l \
    -t piersfinlayson/bitcoin-armv7l:$CONT_VERSION \
    -f Dockerfile.arm \
    .
docker tag piersfinlayson/bitcoin-armv7l:$CONT_VERSION piersfinlayson/bitcoin-armv7l:latest
docker login -u piersfinlayson
docker push piersfinlayson/bitcoin-armv7l:$CONT_VERSION
docker push piersfinlayson/bitcoin-armv7l:latest

echo Now you need to build the manifests using the following command:
echo ./build-manifest.sh $BITCOIN_VERSION $CONT_VERSION
