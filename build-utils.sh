#!/bin/bash
check_args() {
    USAGE="Usage build-arch.sh BITCOIN_VERSION CONTAINER_VERSION [optional extra docker build arg]"
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
    echo "  bitcoin:   $BITCOIN_VERSION"
    echo "  libdb:     $LIBDB_VERSION"
    echo "  libevent:  $LIBEVENT_VERSION"
    echo "  libzmq:    $LIBZMQ_VERSION"
    echo "  boost:     $BOOST_VERSION"
    echo "  openssl:   $BC_OPENSSL_VERSION"
}

build_container() {
    docker build \
        --progress=plain \
        --build-arg LIBEVENT_VERSION=$LIBEVENT_VERSION \
        --build-arg LIBDB_VERSION=$LIBDB_VERSION \
        --build-arg LIBZMQ_VERSION=$LIBZMQ_VERSION \
        --build-arg BOOST_VERSION=$BOOST_VERSION \
        --build-arg CONT_VERSION=$CONT_VERSION \
        --build-arg BITCOIN_VERSION=$BITCOIN_VERSION \
        --build-arg BC_OPENSSL_VERSION=$BC_OPENSSL_VERSION \
        --target $1 \
        -t piersfinlayson/$1:$CONT_VERSION \
        -f $2 \
        $EXTRA_ARG \
        .
}

tag_container() {
    docker tag \
        piersfinlayson/$1:$CONT_VERSION \
        piersfinlayson/$1:latest
}
