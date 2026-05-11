#!/bin/bash
set -eo pipefail
echoerr () { echo "${@}" >&2; }; die () { local r="${?}"; echoerr "${@}"; exit "${r}"; }
trap 'echoerr -e "${0}: \e[0;91mExit with Error Code ${?} at Line ${LINENO}\e[0m"' ERR

# https://gitlab.alpinelinux.org/alpine/aports/-/blob/master/main/openssh/APKBUILD

# var
pkgver=(10.3_p1 cb2bd67086491c25e305879b924c3dfa8236502a60c7f250b2fd17d2d9a79ebfc2e40b2f43e42dcf598cc510996e00cc03df9b8e38f34bc2dc71a3d4ff3788fa)
: "${0##*/}"; result="/result/${_%.*}"

# apk
apk add build-base \
    zlib-dev zlib-static

# src
cd "$( mktemp -d )"
wget -O- "https://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-${pkgver/_/}.tar.gz" |
    tee >(tar -xz --strip 1) | sha512sum -c <(echo "${pkgver[1]} -")

# build
./configure CFLAGS=-static LDFLAGS=-static \
    --without-openssl
make sftp-server

# bin
for bin in sftp-server; do
    install -Ds "${bin}" "${result}/${bin}"
done
