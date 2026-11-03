#!/usr/bin/env bash
#
# Replace the vendored jansson and/or curl sources with an upstream release.
#
# Usage: ./update_dep.sh [jansson|curl|all]
#
# To use another release, change the version and its SHA-256 below. Upstream
# signs every tarball (curl: Daniel Stenberg, jansson: Petri Lehtinen), so check
# the .asc signature once before pinning a new hash.
#
# The files this repository maintains itself are kept:
#   jansson/include/jansson_config*.h, jansson/private_include/, jansson/src/AMBuilder
#   curl/lib/curl_config*.h, curl/lib/AMBuilder
# The source lists to paste into the AMBuilder files are printed at the end.

set -euo pipefail

JANSSON_VERSION="2.15.1"
JANSSON_SHA256="0c7114dc0b2d22a670724a1f95922029d7077c19dbf79a584cb8084d2f267f2f"
CURL_VERSION="8.23.0"
CURL_SHA256="e3de77cfa6367083c776a26647fc9f633b538c06c3baa73d931a252ac8f72b49"

LIB="${1:-all}"
case "$LIB" in
    jansson|curl|all) ;;
    *) echo "Usage: $0 [jansson|curl|all]" >&2; exit 1 ;;
esac

PROJECT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

sha256_check() {
    if command -v sha256sum >/dev/null; then
        echo "$1  $2" | sha256sum -c -
    else
        echo "$1  $2" | shasum -a 256 -c -
    fi
}

# fetch <url> <sha256> <name>: download and check the tarball, extract it to $WORK_DIR/<name>
fetch() {
    local archive="$WORK_DIR/$3.tar.gz"
    curl -fsSL -o "$archive" "$1"
    sha256_check "$2" "$archive"
    mkdir "$WORK_DIR/$3"
    tar -xzf "$archive" -C "$WORK_DIR/$3" --strip-components=1
}

# replace <dir> <keep...>: swap ./<dir> for the extracted release, keeping the listed paths (globs allowed)
replace() {
    local dir="$1" keep_dir="$WORK_DIR/keep-$1" pattern path
    shift
    mkdir "$keep_dir"
    (cd "$PROJECT_PATH/$dir" && for pattern in "$@"; do
        for path in $pattern; do
            [ -e "$path" ] || continue
            mkdir -p "$keep_dir/$(dirname "$path")"
            cp -R "$path" "$keep_dir/$path"
        done
    done)
    rm -rf "${PROJECT_PATH:?}/$dir"
    cp -R "$WORK_DIR/$dir" "$PROJECT_PATH/$dir"
    cp -R "$keep_dir/." "$PROJECT_PATH/$dir/"
}

# cfiles <makefile> <variable>: the .c files of a multi-line make variable, as AMBuilder entries
cfiles() {
    awk -v var="$2" '
        $1 == var && $2 == "=" { on = 1 }
        on {
            for (i = 1; i <= NF; i++) if ($i ~ /\.c$/) print "    \x27" $i "\x27,"
            if ($NF != "\\") on = 0
        }
    ' "$1" | sort -u
}

SOURCES=""

if [[ "$LIB" == "jansson" || "$LIB" == "all" ]]; then
    fetch "https://github.com/akheron/jansson/releases/download/v$JANSSON_VERSION/jansson-$JANSSON_VERSION.tar.gz" \
        "$JANSSON_SHA256" jansson
    replace jansson 'include/jansson_config*.h' private_include src/AMBuilder
    cp "$PROJECT_PATH/jansson/src/jansson.h" "$PROJECT_PATH/jansson/include/jansson.h"

    # dtoa.c is left out: it is only built when DTOA_ENABLED (see jansson/src/Makefile.am)
    SOURCES+="# jansson/src/AMBuilder (libjansson_la_SOURCES in jansson/src/Makefile.am)"$'\n'
    SOURCES+="$(cfiles "$WORK_DIR/jansson/src/Makefile.am" libjansson_la_SOURCES)"$'\n\n'
fi

if [[ "$LIB" == "curl" || "$LIB" == "all" ]]; then
    fetch "https://github.com/curl/curl/releases/download/curl-${CURL_VERSION//./_}/curl-$CURL_VERSION.tar.gz" \
        "$CURL_SHA256" curl
    replace curl 'lib/curl_config*.h' lib/AMBuilder

    SOURCES+="# curl/lib/AMBuilder (curl/lib/Makefile.inc)"$'\n'
    for var in $(grep -oE '^LIB_([A-Z]+_)?CFILES' "$WORK_DIR/curl/lib/Makefile.inc" | sort -u); do
        SOURCES+="    # $var"$'\n'"$(cfiles "$WORK_DIR/curl/lib/Makefile.inc" "$var")"$'\n'
    done
    SOURCES+=$'\n'
fi

echo
echo "Done. Paste these lists into the AMBuilder files, then review the *_config*.h headers kept above:"
echo
printf '%s' "$SOURCES"
