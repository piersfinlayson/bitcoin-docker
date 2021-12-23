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
docker build --target bitcoin-amd64 -t piersfinlayson/bitcoin-amd64:$VERSION .
docker build --target bitcoin-image-armv7l -t piersfinlayson/bitcoin-image-armv7l:$VERSION .
docker push piersfinlayson/bitcoin-amd64:$VERSION
docker push piersfinlayson/bitcoin-image-armv7l:$VERSION
echo Now you need to build the armv7l version on an armv7l machine using the dpkg in bitcoin-builder-armv7l:$VERSION
echo Run this command:
echo "docker build --target piersfinlayson/bitcoin-armv7l:$VERSION && docker push piersfinlayson/bitcoin-armv7l:$VERSION"
