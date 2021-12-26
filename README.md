# bitcoin-docker

A container with bitcoin, libboost and libevent built from source, available for both x86_86/amd64 and armv7l (Raspberry Pi, except for Raspberry Pi Zero v1.x) architectures.

## Building

### Inputs
BITCOIN_VERSION, must be a valid branch of git@github.com:bitcoin/bitcoin.git - e.g. 22.x

CONT_VERSION, container version - uses convention BITCOIN_VERSION.xx, where xx is container build number for that version of bitcoin (so e.g. 22.x.01)

### Step 1 - on x86
./build-amd64.sh BITCOIN_VERSION CONT_VERSION

### Step 2 - on arm
./build-armv7l.sh BITCOIN_VERSION CONT_VERSION

### Step 3 - on any architecture
./build-manifest.sh BITCOIN_VERSION CONT_VERSION

### Final result
piersfinlayson/bitcoin-amd64:CONT_VERSION
piersfinlayson/bitcoin-amd64:latest
piersfinlayson/bitcoin-armv7l:CONT_VERSION
piersfinlayson/bitcoin-armv7l:latest
piersfinlayson/bitcoin:CONT_VERSION
piersfinlayson/bitcoin:latest

## Running

Put a bitcoin.conf in your local bitcoin data directory - in the example below /usr/bitcoin-data.  For a sample bitcoin.conf see: https://github.com/bitcoin/bitcoin/blob/master/share/examples/bitcoin.conf

Then to run:
```
docker pull piersfinlayson/bitcoin:latest # Always worth running to ensure you have the latest
docker run -d --restart always --name bitcoin -p 8333:8333 -v /usb/bitcoin-data:/bitcoin-data piersfinlayson/bitcoin:latest
```

The ```-p 8333:8333``` is optional - only required if you want to be able to be contactable from the internet (and will require appropriate network firewall rules to be in place).

If stopping and restarting (e.g. to upgrade), give some time for the node to shutdown gracefully, e.g.:
```
docker stop -t 60 my_bitcoin_container_name
```
or
```
docker restart -t 60 my_bitcoin_container_name
```
If you don't use the -t flag docker will give the container 10s by default before performing an immediate kill.