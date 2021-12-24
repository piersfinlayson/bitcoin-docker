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
docker build --build-arg VERSION=$VERSION --target piersfinlayson/bitcoin-armv7l:$VERSION && docker push piersfinlayson/bitcoin-armv7l:$VERSION
docker push piersfinlayson/bitcoin-armv7l:$VERSION
