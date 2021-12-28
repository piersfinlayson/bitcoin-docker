#!/bin/bash
set -e
source "build-utils.sh"

BITCOIN_VERSION=$1
CONT_VERSION=$2
EXTRA_ARG=$3
check_args
check_arch armv7l

. ./DEPENDENCIES.sh

echo "Building bitcoin container $CONT_VERSION for armv7l"
output_versions

# Get the container already built on amd64 containing arm images
docker pull piersfinlayson/bitcoin-image-only-armv7l:$CONT_VERSION
build_container bitcoin-armv7l Dockerfile.arm $EXTRA_ARG
tag_container bitcoin-armv7l
echo "Successfully built and tagged piersfinlayson/bitcoin-armv7l:$CONT_VERSION"

# Push container image
docker login -u piersfinlayson
docker push piersfinlayson/bitcoin-armv7l:$CONT_VERSION
docker push piersfinlayson/bitcoin-armv7l:latest

echo Now you need to build the manifests using the following command:
echo ./build-manifest.sh $BITCOIN_VERSION $CONT_VERSION

echo Also, tag the piersfinlayson/bitcoin-docker repo as follows:
echo "git tag -a ${CONT_VERSION} -m \"Container version: ${CONT_VERSION}\nBitcoin version: ${BITCOIN_VERSION}\nlibevent version: ${LIBEVENT_VERSION}\nlibdb version: ${LIBDB_VERSION}\nlibzmq version: ${LIBZMQ_VERSION}\nboost version: ${BOOST_VERSION}\" && git push origin ${CONT_VERSION}"
