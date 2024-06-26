# bitcoin-docker

A container with bitcoin, libboost and libevent built from source, available for both x86_86/amd64 and armv7l (Raspberry Pi, except for Raspberry Pi Zero v1.x) architectures.

## Building

### Inputs
BITCOIN_VERSION, must be a valid branch of https://github.com/bitcoin/bitcoin - e.g. 22.x

CONT_VERSION, container version - uses convention BITCOIN_VERSION.xx, where xx is container build number for that version of bitcoin (so e.g. 22.x.01)

### Step 0 - on x86

Check DEPENDENCIES for any updates, and update as approach.  Remember to check in before steps beyond step 1.

### Step 1 - on x86
./build-amd64.sh BITCOIN_VERSION CONT_VERSION

### Step 1b - on x86
Commit DEPENDENCIES if changed.

### Step 2a - on armv7 (32-bit raspberry pi, not a zero)
./build-armv7l.sh BITCOIN_VERSION CONT_VERSION

### Step 2b - on arm64 (64-bit raspberry pi, aarch64, armv8)
./build-aarch64.sh BITCOIN_VERSION CONT_VERSION

### Step 3 - on any architecture
./build-manifest.sh BITCOIN_VERSION CONT_VERSION

### Final result
registry:80/bitcoin-amd64:CONT_VERSION
registry:80/bitcoin-amd64:latest
registry:80/bitcoin-armv7l:CONT_VERSION
registry:80/bitcoin-armv7l:latest
registry:80/bitcoin-aarch64:CONT_VERSION
registry:80/bitcoin-aarch64:latest
registry:80/bitcoin:CONT_VERSION
registry:80/bitcoin:latest

## Running

Put a bitcoin.conf in your local bitcoin data directory - in the example below /usr/bitcoin-data.  For a sample bitcoin.conf see: https://github.com/bitcoin/bitcoin/blob/master/share/examples/bitcoin.conf

Then to run:
```
docker pull registry:80/bitcoin:latest # Always worth running to ensure you have the latest
docker run -d --restart always --name bitcoin -p 8333:8333 -v /usb/bitcoin-data:/bitcoin-data registry:80/bitcoin:latest
```

The ```-p 8333:8333``` is optional - only required if you want to be able to be contactable from the internet (and will require appropriate network firewall rules to be in place).

If stopping and restarting (e.g. to upgrade), give some time for the node to shutdown gracefully, e.g.:
```
docker stop -t 3600 my_bitcoin_container_name
```
or
```
docker restart -t 3600 my_bitcoin_container_name
```
If you don't use the -t flag docker will give the container 10s by default before performing an immediate kill.
