#!/bin/bash
echo Building version $1
docker build --target bitcoin-amd64 -t piersfinlayson/bitcoin-amd64:$1 .
docker build --target bitcoin-image-armv7l -t piersfinlayson/bitcoin-image-armv7l:$1 .
docker push piersfinlayson/bitcoin-amd64:$1
docker push piersfinlayson/bitcoin-image-armv7l:$1
echo Now you need to build the armv7l version on an armv7l machine using the dpkg in bitcoin-builder-armv7l:$1
echo Run this command:
echo "docker build --target piersfinlayson/bitcoin-armv7l:$1 && docker push piersfinlayson/bitcoin-armv7l:$1"
