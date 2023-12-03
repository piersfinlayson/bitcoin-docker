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

# Create VERSION manifest
docker manifest create --insecure -a registry:80/bitcoin:${CONT_VERSION} registry:80/bitcoin-amd64:${CONT_VERSION} registry:80/bitcoin-armv7l:${CONT_VERSION} registry:80/bitcoin-aarch64:${CONT_VERSION}
docker manifest annotate --arch amd64 --os linux registry:80/bitcoin:${CONT_VERSION} registry:80/bitcoin-amd64:${CONT_VERSION}
docker manifest annotate --arch arm --os linux --variant armv7l registry:80/bitcoin:${CONT_VERSION} registry:80/bitcoin-armv7l:${CONT_VERSION}
docker manifest annotate --arch arm --os linux --variant arm64 registry:80/bitcoin:${CONT_VERSION} registry:80/bitcoin-aarch64:${CONT_VERSION}
docker manifest inspect --insecure registry:80/bitcoin:${CONT_VERSION}
docker manifest push --insecure --purge registry:80/bitcoin:${CONT_VERSION}

# Create latest manifest
docker manifest create --insecure -a registry:80/bitcoin:latest registry:80/bitcoin-amd64:${CONT_VERSION} registry:80/bitcoin-armv7l:${CONT_VERSION} registry:80/bitcoin-aarch64:${CONT_VERSION}
docker manifest annotate --arch amd64 --os linux registry:80/bitcoin:latest registry:80/bitcoin-amd64:${CONT_VERSION}
docker manifest annotate --arch arm --os linux --variant armv7l registry:80/bitcoin:latest registry:80/bitcoin-armv7l:${CONT_VERSION}
docker manifest annotate --arch arm --os linux --variant arm64 registry:80/bitcoin:latest registry:80/bitcoin-aarch64:${CONT_VERSION}
docker manifest inspect --insecure registry:80/bitcoin:latest
docker manifest push --insecure --purge registry:80/bitcoin:latest

docker pull registry:80/bitcoin:latest
