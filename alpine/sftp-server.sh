#!/bin/bash
set -eo pipefail
echoerr () { echo "${@}" >&2; }; die () { local r="${?}"; echoerr "${@}"; exit "${r}"; }
trap 'echoerr -e "${0}: \e[0;91mExit with Error Code ${?} at Line ${LINENO}\e[0m"' ERR

# https://gitlab.alpinelinux.org/alpine/aports/-/blob/master/main/openssh/APKBUILD

# var
pkgver=(10.2_p1 66f3dd646179e71aaf41c33b6f14a207dc873d71d24f11c130a89dee317ee45398b818e5b94887b5913240964a38630d7bca3e481e0f1eff2e41d9e1cfdbdfc5)
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
install -Ds sftp-server "${result}"/sftp-server
