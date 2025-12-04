#!/bin/bash
set -eo pipefail
echoerr () { echo "${@}" >&2; }; die () { local r="${?}"; echoerr "${@}"; exit "${r}"; }
trap 'echoerr -e "${0}: \e[0;91mExit with Error Code ${?} at Line ${LINENO}\e[0m"' ERR

# https://gitlab.alpinelinux.org/alpine/aports/-/blob/master/community/pure-ftpd/APKBUILD

# var
pkgver=(1.0.52 d3aa87e0e9beca464f5dc23ea86835ba42a8bb57120e8c0a4cd975925aed850a442766c1ef605e563d6c61a37967b4f283ababb991493327ce6f0a1749aae01a)
: "${0##*/}"; result="/result/${_%.*}"
script_header="$( head -4 "${0}" )"

# apk
apk add build-base \
    openssl-dev openssl-libs-static

# src
cd "$( mktemp -d )"
wget -O- "https://download.pureftpd.org/pub/pure-ftpd/releases/pure-ftpd-$pkgver.tar.gz" |
    tee >(tar -xz --strip 1) | sha512sum -c <(echo "${pkgver[1]} -")

# patch
patch -p0 <<'EOF'
--- src/ftpd.c
+++ src/ftpd.c
@@ -1080,8 +1080,6 @@ void dobanner(const int type)

 #endif

-#ifndef MINIMAL
-
 int modernformat(const char *file, char *target, size_t target_size,
                  const char * const prefix)
 {
@@ -1228,8 +1226,6 @@ void doallo(const off_t size)
     }
 }

-#endif
-
 void dositetime(void)
 {
     char tmp[64];


EOF

# build
./configure CFLAGS=-static LDFLAGS=-static \
    --without-inetd \
    --without-pam \
    --without-shadow \
    --with-minimal \
    --with-puredb \
    --with-implicittls \
    --with-certfile=/etc/pure-ftpd/tls.crt \
     --with-keyfile=/etc/pure-ftpd/tls.key
make

# bin
for bin in pure-ftpd pure-pw; do
    install -Ds src/"${bin}" "${result}/${bin}"
done
# service
install -Dm644 /dev/stdin "${result}"/etc/systemd/system/pure-ftpd.service <<'EOF'
[Unit]
Description=pure-ftpd
After=network.target

[Service]
ExecStart=${dest:?}/pure-ftpd -EAR4HS 990 -l puredb:/etc/pure-ftpd/passwd.pdb -Y3

[Install]
WantedBy=multi-user.target
EOF
# setup
setup="${result}"/setup/pure-ftpd.sh
{ echo "${script_header}"; echo; } | install -Dm755 /dev/stdin "${setup}"
cat >>"${setup}" <<'EOF'
# etc
mkdir -p /etc/pure-ftpd

# service
service='pure-ftpd'
systemctl stop    "${service}" || :
systemctl disable "${service}" || :
ln -vsf {${dest:?},}/etc/systemd/system/"${service}".service
systemctl daemon-reload
systemctl enable  "${service}" || { ln -vsf /etc/systemd/system{,/multi-user.target.wants}/"${service}".service; systemctl daemon-reload; }
systemctl start   "${service}"
systemctl status  "${service}"
EOF
