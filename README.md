# bitcoin-docker

## First on x86
./build.amd64.sh VERSION

## Then on arm
./build.armv7l.sh VERSION
## To run the bitcoin node (on arm)
docker run -d --restart always --name bitcoin -p 8333:8333 -v /usb/bitcoin-data:/bitcoin-data piersfinlayson/bitcoin-armv7l:VERSION
