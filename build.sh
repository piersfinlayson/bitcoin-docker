#!/bin/bash
set -e
source "build-utils.sh"

BITCOIN_VERSION=$1
CONT_VERSION=$2
PLATFORM=$3
check_args

. ./DEPENDENCIES.sh

echo "Building bitcoin container $CONT_VERSION for platform $PLATFORM"
output_versions

# Get the container already built on amd64 containing arm images
build_container bitcoin-$PLATFORM Dockerfile
tag_container bitcoin-$PLATFORM
echo "Successfully built and tagged registry:80/bitcoin-$PLATFORM:$CONT_VERSION,latest"

# Push container image
docker push registry:80/bitcoin-$PLATFORM:$CONT_VERSION
docker push registry:80/bitcoin-$PLATFORM:latest
echo "Successfully pushed registry:80/bitcoin-$PLATFORM:$CONT_VERSION,latest"

# Tag the git commit
echo "Now tag this git commit:"
echo "git tag -a ${CONT_VERSION} -m \"Container version: ${CONT_VERSION}\nBitcoin version: ${BITCOIN_VERSION}\nlibevent version: ${LIBEVENT_VERSION}\nboost version: ${BOOST_VERSION}\nopenssl version: ${BC_OPENSSL_VERSION}\nARM toolchain version: ${ARM_TOOLCHAIN_VERSION}\" && git push origin ${CONT_VERSION}"
