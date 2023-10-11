#!/bin/bash

set -e
set -x

# Change to whatever you want
JANSSON_VERSION="2.14"
CURL_VERSION="8.4.0"

LIB="all"
if [ -n "$1" ]; then
    LIB="$1"
fi

PROJECT_PATH="$PWD"

if [[ "$LIB" == "jansson" || "$LIB" == "all" ]]; then
    # JANSSON
    TMP_DIR="/tmp"
    TMP_DIR_JANSSON="$TMP_DIR/jansson"
    rm -rf $TMP_DIR_JANSSON*
    curl -Lo $TMP_DIR_JANSSON.tar.gz https://github.com/akheron/jansson/releases/download/v$JANSSON_VERSION/jansson-$JANSSON_VERSION.tar.gz
    tar -xvf $TMP_DIR_JANSSON.tar.gz -C $TMP_DIR && mv $TMP_DIR/jansson-$JANSSON_VERSION $TMP_DIR_JANSSON
    cd $TMP_DIR_JANSSON
    mkdir -p build && cd build
    cmake ../ -DCMAKE_POSITION_INDEPENDENT_CODE=ON -Dprotobuf_BUILD_SHARED_LIBS=OFF -DCMAKE_CXX_STANDARD=14 -DCMAKE_INSTALL_PREFIX="$PWD/package"
    make -j 8
    make install
    rm "$PWD/package/include/jansson_config.h"
    cp -R "$PWD/package/include" ../
    cd $PROJECT_PATH
    cp -R "$TMP_DIR_JANSSON"/* ./jansson

    JANSSON_AMBUILDER_SOURCES_PATH="$TMP_DIR_JANSSON/AMBuilder.sources"
    echo "# JANSSON_SRC" > $JANSSON_AMBUILDER_SOURCES_PATH
    cat jansson/src/Makefile.am | grep -o '[a-zA-Z0-9_]*\.c' | awk '!seen[$0]++' | sort | sed "s/.*/'&',/" >> $JANSSON_AMBUILDER_SOURCES_PATH
    echo "" >> $JANSSON_AMBUILDER_SOURCES_PATH

    echo "Sources generated in $JANSSON_AMBUILDER_SOURCES_PATH must be replaced in jansson/src/AMBuilder"
fi

if [[ "$LIB" == "curl" || "$LIB" == "all" ]]; then
    # CURL
    CURL_VERSION_UNDERSCORE="${CURL_VERSION//./_}"

    TMP_DIR="/tmp"
    TMP_DIR_CURL="$TMP_DIR/curl"
    rm -rf $TMP_DIR_CURL*
    curl -Lo $TMP_DIR_CURL.tar.gz https://github.com/curl/curl/releases/download/curl-$CURL_VERSION_UNDERSCORE/curl-$CURL_VERSION.tar.gz
    tar -xvf $TMP_DIR_CURL.tar.gz -C $TMP_DIR && mv $TMP_DIR/curl-$CURL_VERSION $TMP_DIR_CURL
    cd $TMP_DIR_CURL
    mkdir -p build && cd build
    cmake ../ -DCMAKE_POSITION_INDEPENDENT_CODE=ON -Dprotobuf_BUILD_SHARED_LIBS=OFF -DCMAKE_CXX_STANDARD=14 -DCMAKE_INSTALL_PREFIX="$PWD/package"
    make -j 8
    make install
    cp -R "$PWD/package/include" ../
    cd ..
    cd $PROJECT_PATH
    cp -R "$TMP_DIR_CURL"/* ./curl

    CURL_AMBUILDER_SOURCES_PATH="$TMP_DIR_CURL/AMBuilder.sources"
    echo "# LIB_CFILES" > $CURL_AMBUILDER_SOURCES_PATH
    cat curl/lib/Makefile.in | grep -o '  [a-zA-Z0-9_]*\.c' | awk '!seen[$0]++' | sed 's/^[[:space:]]*//' | sort | sed "s/.*/'&',/" >> $CURL_AMBUILDER_SOURCES_PATH
    echo "" >> $CURL_AMBUILDER_SOURCES_PATH

    echo "# LIB_VAUTH_CFILES" >> $CURL_AMBUILDER_SOURCES_PATH
    cat curl/lib/Makefile.in | grep -o 'vauth/[a-zA-Z0-9_]*\.c' | awk '!seen[$0]++' | sort | sed "s/.*/'&',/" >> $CURL_AMBUILDER_SOURCES_PATH
    echo "" >> $CURL_AMBUILDER_SOURCES_PATH

    echo "# LIB_VQUIC_CFILES" >> $CURL_AMBUILDER_SOURCES_PATH
    cat curl/lib/Makefile.in | grep -o 'vquic/[a-zA-Z0-9_]*\.c' | awk '!seen[$0]++' | sort | sed "s/.*/'&',/" >> $CURL_AMBUILDER_SOURCES_PATH
    echo "" >> $CURL_AMBUILDER_SOURCES_PATH

    echo "# LIB_VSSH_CFILES" >> $CURL_AMBUILDER_SOURCES_PATH
    cat curl/lib/Makefile.in | grep -o 'vssh/[a-zA-Z0-9_]*\.c' | awk '!seen[$0]++' | sort | sed "s/.*/'&',/" >> $CURL_AMBUILDER_SOURCES_PATH
    echo "" >> $CURL_AMBUILDER_SOURCES_PATH

    echo "# LIB_VTLS_CFILES" >> $CURL_AMBUILDER_SOURCES_PATH
    cat curl/lib/Makefile.in | grep -o 'vtls/[a-zA-Z0-9_]*\.c' | awk '!seen[$0]++' | sort | sed "s/.*/'&',/" >> $CURL_AMBUILDER_SOURCES_PATH
    echo "" >> $CURL_AMBUILDER_SOURCES_PATH

    echo "Sources generated in $CURL_AMBUILDER_SOURCES_PATH must be replaced in curl/AMBuilder"
fi
