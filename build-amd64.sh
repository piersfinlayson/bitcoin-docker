#!/bin/bash
set -e
source "build-utils.sh"

BITCOIN_VERSION=$1
CONT_VERSION=$2
EXTRA_ARG=$3
check_args
check_arch x86_64

. ./DEPENDENCIES.sh

echo "Building bitcoin container $CONT_VERSION for amd64 and pre-armv7l"
output_versions

# Forcibly get the latest build container
docker pull piersfinlayson/build:latest

# Build the amd64 version - including latest
build_container bitcoin-amd64 Dockerfile $EXTRA_ARG
tag_container bitcoin_amd64
echo "Successfully built and tagged piersfinlayson/bitcoin-amd64:$CONT_VERSION"

# Build the armv7l image only version - don't bother with latest
build_container bitcoin-image-only-armv7l Dockerfile $EXTRA_ARG
echo "Successfully built piersfinlayson/bitcoin-image-only-armv7l:$CONT_VERSION"

# Push both versions
docker login -u piersfinlayson
docker push piersfinlayson/bitcoin-amd64:$CONT_VERSION
docker push piersfinlayson/bitcoin-amd64:latest
docker push piersfinlayson/bitcoin-image-only-armv7l:$CONT_VERSION
echo Now you need to build the armv7l version on an armv7l machine using the following command:
echo ./build-armv7l.sh $BITCOIN_VERSION $CONT_VERSION
