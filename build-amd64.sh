#!/bin/bash
set -e
source "build-utils.sh"

BITCOIN_VERSION=$1
CONT_VERSION=$2
EXTRA_ARG=$3
check_args
check_arch x86_64

. ./DEPENDENCIES.sh

echo "Building bitcoin container $CONT_VERSION for amd64, pre-armv7l and pre-aarch64"
output_versions

# Build the amd64 version - including latest
build_container bitcoin-amd64 Dockerfile $EXTRA_ARG
tag_container bitcoin-amd64
echo "Successfully built and tagged registry:80/bitcoin-amd64:$CONT_VERSION"

# Build the armv7l image only version - don't bother with latest
build_container bitcoin-image-only-armv7l Dockerfile $EXTRA_ARG
echo "Successfully built registry:80/bitcoin-image-only-armv7l:$CONT_VERSION"

# Build the aarch64 image only version - don't bother with latest
build_container bitcoin-image-only-aarch64 Dockerfile $EXTRA_ARG
echo "Successfully built registry:80/bitcoin-image-only-aarch64:$CONT_VERSION"

# Push both versions
docker push registry:80/bitcoin-amd64:$CONT_VERSION
docker push registry:80/bitcoin-amd64:latest
docker push registry:80/bitcoin-image-only-armv7l:$CONT_VERSION
docker push registry:80/bitcoin-image-only-aarch64:$CONT_VERSION
echo Now you need to build the armv7l version on an armv7l machine using the following command:
echo ./build-armv7l.sh $BITCOIN_VERSION $CONT_VERSION
echo Now you need to build the aarch64 version on an aarch64 machine using the following command:
echo ./build-aarch64.sh $BITCOIN_VERSION $CONT_VERSION
