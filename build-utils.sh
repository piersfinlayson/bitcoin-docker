#!/bin/bash
check_args() {
    USAGE="Usage build-arch.sh BITCOIN_VERSION CONTAINER_VERSION PLATFORM"
    if [ -z $BITCOIN_VERSION ]
    then
        echo $USAGE
        exit
    fi
    if [ -z $CONT_VERSION ]
    then
        echo $USAGE
        exit
    fi
    if [ -z $PLATFORM ]
    then
        # Default to linux/amd64
        PLATFORM=linux/amd64
        echo "No platform specified, defaulting to $PLATFORM"
    fi

    valid_platforms=("linux/amd64" "linux/arm64" "linux/arm64/v8" "linux/arm/v7" "linux/arm/v6")
    if [[ ! " ${valid_platforms[@]} " =~ " ${PLATFORM} " ]]; then
        echo "Invalid platform specified"
        exit 1
    fi
}

check_arch() {
    ARCH=`arch`
    if [ "x$ARCH" != "x$1" ]
    then
        echo Must be run on an $1 platform - this is an $ARCH platform
        exit
    fi
}

output_versions() {
    echo "Dependency versions:"
    echo "  bitcoin:       $BITCOIN_VERSION"
    echo "  libevent:      $LIBEVENT_VERSION"
    echo "  boost:         $BOOST_VERSION"
    echo "  openssl:       $BC_OPENSSL_VERSION"
    echo "  ARM toolchain: $ARM_TOOLCHAIN_VERSION"
}

build_container() {
    # Output the docker command to be run
    echo "docker build --provenance=false --build-arg LIBEVENT_VERSION=$LIBEVENT_VERSION --build-arg --build-arg BOOST_VERSION=$BOOST_VERSION --build-arg CONT_VERSION=$CONT_VERSION --build-arg BITCOIN_VERSION=$BITCOIN_VERSION --build-arg BC_OPENSSL_VERSION=$BC_OPENSSL_VERSION -t registry:80/$1:$CONT_VERSION -f $2 --platform $PLATFORM --progress=plain ."
    docker build \
	--provenance=false \
        --build-arg LIBEVENT_VERSION=$LIBEVENT_VERSION \
        --build-arg BOOST_VERSION=$BOOST_VERSION \
        --build-arg CONT_VERSION=$CONT_VERSION \
        --build-arg BITCOIN_VERSION=$BITCOIN_VERSION \
        --build-arg BC_OPENSSL_VERSION=$BC_OPENSSL_VERSION \
        -t registry:80/$1:$CONT_VERSION \
        -f $2 \
        --platform $PLATFORM \
        --progress=plain \
        .
}

tag_container() {
    docker tag \
        registry:80/$1:$CONT_VERSION \
        registry:80/$1:latest
}
