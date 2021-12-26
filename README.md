# bitcoin-docker

## First on x86
./build.amd64.sh VERSION

## Then on arm
./build.armv7l.sh VERSION

## Then build manifests
./build-manifest.sh

## To run the bitcoin node
docker pull piersfinlayson/bitcoin:latest
docker run -d --restart always --name bitcoin -p 8333:8333 -v /usb/bitcoin-data:/bitcoin-data piersfinlayson/bitcoin:latest
