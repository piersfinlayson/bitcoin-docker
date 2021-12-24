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
docker login -u piersfinlayson
docker build -f Dockerfile.arm --build-arg VERSION=$VERSION --target piersfinlayson/bitcoin-armv7l:$VERSION && docker push piersfinlayson/bitcoin-armv7l:$VERSION
docker tag piersfinlayson/bitcoin-armv7l:$VERSION piersfinlayson/bitcoin-armv7l:latest
docker login -u piersfinlayson
docker push piersfinlayson/bitcoin-armv7l:$VERSION
docker push piersfinlayson/bitcoin-armv7l:latest
