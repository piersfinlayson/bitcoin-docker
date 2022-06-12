#!/bin/bash
set -e 
BITCOIN_VERSION=$1
if [ -z $BITCOIN_VERSION ]
then
	echo "Usage build-manifest.sh BITCOIN_VERSION CONTAINER_VERSION"
	exit
else
	echo Building bitcoin version $BITCOIN_VERSION
fi
CONT_VERSION=$2
if [ -z $CONT_VERSION ]
then
	echo "Usage build-manifest.sh BITCOIN_VERSION CONTAINER_VERSION"
	exit
else
	echo Building container version $CONT_VERSION
fi

docker login -u piersfinlayson

# Create VERSION manifest
docker manifest create -a piersfinlayson/bitcoin:${CONT_VERSION} piersfinlayson/bitcoin-amd64:${CONT_VERSION} piersfinlayson/bitcoin-armv7l:${CONT_VERSION} piersfinlayson/bitcoin-aarch64:${CONT_VERSION}
docker manifest annotate --arch amd64 --os linux piersfinlayson/bitcoin:${CONT_VERSION} piersfinlayson/bitcoin-amd64:${CONT_VERSION}
docker manifest annotate --arch arm --os linux --variant armv7l piersfinlayson/bitcoin:${CONT_VERSION} piersfinlayson/bitcoin-armv7l:${CONT_VERSION}
docker manifest annotate --arch arm --os linux --variant aarch64 piersfinlayson/bitcoin:${CONT_VERSION} piersfinlayson/bitcoin-aarch64:${CONT_VERSION}
docker manifest inspect piersfinlayson/bitcoin:${CONT_VERSION}
docker manifest push --purge piersfinlayson/bitcoin:${CONT_VERSION}

# Create latest manifest
docker manifest create -a piersfinlayson/bitcoin:latest piersfinlayson/bitcoin-amd64:${CONT_VERSION} piersfinlayson/bitcoin-armv7l:${CONT_VERSION} piersfinlayson/bitcoin-aarch64:${CONT_VERSION}
docker manifest annotate --arch amd64 --os linux piersfinlayson/bitcoin:latest piersfinlayson/bitcoin-amd64:${CONT_VERSION}
docker manifest annotate --arch arm --os linux --variant armv7l piersfinlayson/bitcoin:latest piersfinlayson/bitcoin-armv7l:${CONT_VERSION}
docker manifest annotate --arch arm --os linux --variant aarch64 piersfinlayson/bitcoin:latest piersfinlayson/bitcoin-aarch64:${CONT_VERSION}
docker manifest inspect piersfinlayson/bitcoin:latest
docker manifest push --purge piersfinlayson/bitcoin:latest

docker pull piersfinlayson/bitcoin:latest
