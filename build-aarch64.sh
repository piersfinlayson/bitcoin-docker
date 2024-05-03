#!/bin/bash
set -e
source "build-utils.sh"

BITCOIN_VERSION=$1
CONT_VERSION=$2
EXTRA_ARG=$3
check_args
check_arch aarch64

. ./DEPENDENCIES.sh

echo "Building bitcoin container $CONT_VERSION for aarch64"
output_versions

# Get the container already built on amd64 containing arm images
docker pull registry:80/bitcoin-image-only-aarch64:$CONT_VERSION
build_container bitcoin-aarch64 Dockerfile.aarch64 $EXTRA_ARG
tag_container bitcoin-aarch64
echo "Successfully built and tagged registry:80/bitcoin-aarch64:$CONT_VERSION"

# Push container image
docker push registry:80/bitcoin-aarch64:$CONT_VERSION
docker push registry:80/bitcoin-aarch64:latest

echo Now you need to build the manifests using the following command:
echo ./build-manifest.sh $BITCOIN_VERSION $CONT_VERSION

echo Also, tag the registry:80/bitcoin-docker repo as follows:
echo "git tag -a ${CONT_VERSION} -m \"Container version: ${CONT_VERSION}\nBitcoin version: ${BITCOIN_VERSION}\nlibevent version: ${LIBEVENT_VERSION}\nlibzmq version: ${LIBZMQ_VERSION}\nboost version: ${BOOST_VERSION}\nopenssl version: ${BC_OPENSSL_VERSION}\nARM toolchain version: ${ARM_TOOLCHAIN_VERSION}\" && git push origin ${CONT_VERSION}"
