#!/bin/bash
set -eo pipefail
echoerr () { echo "${@}" >&2; }; die () { local r="${?}"; echoerr "${@}"; exit "${r}"; }
trap 'echoerr -e "${0}: \e[0;91mExit with Error Code ${?} at Line ${LINENO}\e[0m"' ERR

# https://gitlab.alpinelinux.org/alpine/aports/-/blob/master/main/tinyproxy/APKBUILD

# var
pkgver=('1.11.2' 'd7cdc3aa273881ca1bd3027ff83d1fa3d3f40424a3f665ea906a3de059df2795455b65aeebde0f75ae5cacf9bba57219bc0c468808a9a75278e93f8d7913bac5')
: "${0##*/}"; result="/result/${_%.*}"
script_header="$( head -4 "${0}" )"

# apk
apk add build-base

# src
cd "$( mktemp -d )"
wget -O- "https://github.com/tinyproxy/tinyproxy/releases/download/$pkgver/tinyproxy-$pkgver.tar.gz" |
    tee >(tar -xz --strip 1) | sha512sum -c <(echo "${pkgver[1]} -")

# build
./configure LDFLAGS=-static --sysconfdir='/etc' \
    --enable-upstream \
    --disable-debug \
    --disable-xtinyproxy \
    --disable-filter \
    --disable-reverse \
    --disable-transparent \
    --disable-manpage_support
make

# bin
install -Ds src/tinyproxy "${result}"/tinyproxy
# service
install -Dm644 /dev/stdin "${result}"/etc/systemd/system/tinyproxy.service <<'EOF'
[Unit]
Description=tinyproxy
After=network.target

[Service]
User=nobody
Group=nobody
ExecStart=${dest:?}/tinyproxy -d
ExecReload=/bin/kill -USR1 $MAINPID
KillMode=process
PrivateDevices=yes

[Install]
WantedBy=multi-user.target
EOF
# setup
: "${result}"/setup/tinyproxy.sh
{ echo "${script_header}"; echo; } | install -Dm755 /dev/stdin "${_}"
cat >>"${_}" <<'EOF'
# etc
install -Dm644 /dev/null /etc/tinyproxy/tinyproxy.conf

# service
service='tinyproxy'
systemctl stop    "${service}" || :
systemctl disable "${service}" || :
ln -vsf {${dest:?},}/etc/systemd/system/"${service}".service
systemctl daemon-reload
systemctl enable  "${service}"
systemctl start   "${service}"
systemctl status  "${service}"
EOF
