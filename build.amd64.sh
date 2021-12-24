#!/bin/bash
set -e
VERSION=$1
if [ -z $VERSION ]
then
	echo "Specify version"
	exit
else
	echo Building version $VERSION
fi
# Build the amd64 version - including latest
docker build --progress=plain --target bitcoin-amd64 -t piersfinlayson/bitcoin-amd64:$VERSION .
docker tag piersfinlayson/bitcoin-amd64:$VERSION piersfinlayson/bitcoin-amd64:latest

# Build the armv7l image only version - don't bother with latest
docker build --progress=plain --build-arg VERSION=$VERSION --target bitcoin-image-only-armv7l -t piersfinlayson/bitcoin-image-only-armv7l:$VERSION .

# Push both versions
docker login -u piersfinlayson
docker push piersfinlayson/bitcoin-amd64:$VERSION
docker push piersfinlayson/bitcoin-amd64:latest
docker push piersfinlayson/bitcoin-image-only-armv7l:$VERSION
echo Now you need to build the armv7l version on an armv7l machine using the following command:
echo ./build.armv7l.sh $VERSION
