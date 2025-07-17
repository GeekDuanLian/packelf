#!/bin/false

# utils

pkg+=(bash curl less grep diffutils htop broot btop micro traceroute rsync netcat-openbsd)
bin+=(/usr/bin/{bash,curl,less,grep,diff,htop,broot,btop,micro,traceroute,rsync,nc})
etc+=(/etc/ssl/certs/ca-certificates.crt)

install_dest /dev/stdin setup/utils.sh <<'EOF'
# etc
ln -vsf {${dest},}/etc/ssl/certs/ca-certificates.crt
EOF
