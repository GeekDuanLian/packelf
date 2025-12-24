#!/bin/false

# shellcheck disable=SC2034
pkg=(nginx)
bin=(/usr/sbin/nginx)
etc=(/etc/nginx/mime.types)

# etc
install_dest /etc/nginx/nginx.conf <<'EOF'
user nginx;
worker_processes auto;
worker_cpu_affinity auto;
pid /run/nginx/nginx.pid;
error_log /var/log/nginx/error.log warn;

events {
    worker_connections 1024;
}

http {
    server_tokens off;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;

    include      mime.types;
    default_type application/octet-stream;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_min_length 1024;
    gzip_types  text/css
                text/javascript
                text/xml
                text/plain
                application/javascript
                application/x-javascript
                application/json
                application/xml
                application/rss+xml
                application/vnd.ms-fontobject
                font/ttf
                font/opentype
                image/svg+xml;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;
}
EOF

# logrotate
install_dest /etc/logrotate.d/nginx <<'EOF'
/var/log/nginx/*.log {
    daily
    rotate 180
    compress
    missingok
    nocreate
    sharedscripts
    postrotate
        systemctl reload nginx
    endscript
}
EOF

# service
install_dest /etc/systemd/system/nginx.service <<'EOF'
[Unit]
Description=nginx
After=network.target remote-fs.target nss-lookup.target

[Service]
Environment="LANG=C"
LimitNOFILE=infinity
RuntimeDirectory=nginx
RuntimeDirectoryMode=0755

NoNewPrivileges=true
ProtectSystem=full
PrivateDevices=true
PrivateTmp=true
ProtectHome=true

ExecStartPre=${dest:?}/nginx -tq
ExecStart=${dest:?}/nginx -g 'daemon off;'
ExecReload=${dest:?}/nginx -tq
ExecReload=${dest:?}/nginx -s reload
KillMode=mixed
KillSignal=SIGQUIT
TimeoutStopSec=5

Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# setup
install_setup <<'EOF'
# user
u='nginx'
groupadd -r -f "${u}"
id -u "${u}" &>/dev/null || useradd -r -g "${u}" -Md /var/empty/"${u}" -s /usr/sbin/nologin "${u}"

# dir
mkdir -p /etc/nginx
mkdir -pm700 /var/log/nginx /var/empty/nginx

# etc
ln -vsf ${dest:?}/etc/nginx/mime.types /etc/nginx/
[[ "${1}" ]] && install -m644 "${1}" /etc/nginx/nginx.conf

# logrotate
ln -vsf {${dest:?},}/etc/logrotate.d/nginx

# service
service='nginx'
systemctl stop    "${service}" || :
systemctl disable "${service}" || :
ln -vsf {${dest:?},}/etc/systemd/system/"${service}".service
systemctl daemon-reload
systemctl enable  "${service}" || { ln -vsf /etc/systemd/system{,/multi-user.target.wants}/"${service}".service; systemctl daemon-reload; }
systemctl start   "${service}"
systemctl status  "${service}"
EOF
