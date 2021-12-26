#!/bin/bash
set -e 
BITCOIN_VERSION=$1
if [ -z $BITCOIN_VERSION ]
then
	echo "Usage build.manifest.sh BITCOIN_VERSION CONTAINER_VERSION"
	exit
else
	echo Building bitcoin version $BITCOIN_VERSION
fi
CONT_VERSION=$2
if [ -z $CONT_VERSION ]
then
	echo "Usage build.manifest.sh BITCOIN_VERSION CONTAINER_VERSION"
	exit
else
	echo Building container version $CONT_VERSION
fi

VERSION=`cat VERSION`
echo "Create piersfinlayson/bitcoin manifests"
echo "       version: ${VERSION}"

docker login

# Create VERSION manifest
docker manifest create -a piersfinlayson/bitcoin:${VERSION} piersfinlayson/bitcoin-amd64:${VERSION} piersfinlayson/bitcoin-armv7l:${VERSION}
docker manifest annotate --arch amd64 --os linux piersfinlayson/bitcoin:${VERSION} piersfinlayson/bitcoin-amd64:${VERSION}
docker manifest annotate --arch arm --os linux --variant armv7l piersfinlayson/bitcoin:${VERSION} piersfinlayson/bitcoin-armv7l:${VERSION}
docker manifest inspect piersfinlayson/bitcoin:${VERSION}
docker manifest push --purge piersfinlayson/bitcoin:${VERSION}

# Create latest manifest
docker manifest create -a piersfinlayson/bitcoin:latest piersfinlayson/bitcoin-amd64:${VERSION} piersfinlayson/bitcoin-armv7l:${VERSION}
docker manifest annotate --arch amd64 --os linux piersfinlayson/bitcoin:latest piersfinlayson/bitcoin-amd64:${VERSION}
docker manifest annotate --arch arm --os linux --variant armv7l piersfinlayson/bitcoin:latest piersfinlayson/bitcoin-armv7l:${VERSION}
docker manifest inspect piersfinlayson/bitcoin:latest
docker manifest push --purge piersfinlayson/bitcoin:latest

docker pull piersfinlayson/bitcoin:latest
