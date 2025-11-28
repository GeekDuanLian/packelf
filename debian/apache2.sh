#!/bin/false

# shellcheck disable=SC2034
pkg=(apache2)
bin=(/usr/sbin/apache2)
etc=(/usr/lib/apache2/modules)
ldd=("${etc[0]}"/*.so)

# etc
install_dest /etc/apache2/apache2.conf <<'EOF'
Listen 80
User apache2
Group apache2
DefaultRuntimeDir /var/run/apache2
PidFile /var/run/apache2/apache2.pid
ErrorLog /var/log/apache2/server-error.log
LogLevel warn
LogFormat "%v:%p %h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" vhost_combined

Timeout 300
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 5
HostnameLookups Off

# modules
LoadModule mpm_event_module modules/mod_mpm_event.so
StartServers            2
MinSpareThreads         25
MaxSpareThreads         75
ThreadLimit             64
ThreadsPerChild         25
MaxRequestWorkers       150
MaxConnectionsPerChild  0
LoadModule authz_core_module modules/mod_authz_core.so
LoadModule headers_module modules/mod_headers.so

# privacy
ServerTokens Prod
ServerSignature Off
TraceEnable Off
ServerName localhost
ServerAdmin webmaster@localhost
DocumentRoot /var/empty/apache2

# deny all local files
<Directory />
    Options FollowSymLinks
    AllowOverride None
    Require all denied
</Directory>
EOF

# logrotate
install_dest /etc/logrotate.d/apache2 <<'EOF'
/var/log/apache2/*.log {
    daily
    rotate 180
    compress
    missingok
    nocreate
    sharedscripts
    postrotate
        systemctl reload apache2
    endscript
}
EOF

# service
install_dest /etc/systemd/system/apache2.service <<'EOF'
[Unit]
Description=apache2
After=network.target remote-fs.target nss-lookup.target

[Service]
Environment="LANG=C"
RuntimeDirectory=apache2
RuntimeDirectoryMode=0755
PrivateTmp=true
ExecStartPre=${dest:?}/apache2 -t
ExecStart=${dest:?}/apache2 -D FOREGROUND
ExecReload=${dest:?}/apache2 -t
ExecReload=/bin/kill -SIGUSR1 $MAINPID
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

# setup
install_setup <<'EOF'
# user
groupadd -r -f apache2
useradd -r -g apache2 -Md /var/empty/apache2 -s /usr/sbin/nologin apache2 || :

# dir
mkdir -p /etc/apache2 /var/empty/apache2
mkdir -pm700 /var/log/apache2

# etc
ln -vsf ${dest:?}/usr/lib/apache2/modules /etc/apache2/
ln -vsf {${dest:?},}/etc/logrotate.d/apache2

# service
service='apache2'
systemctl stop    "${service}" || :
systemctl disable "${service}" || :
ln -vsf {${dest:?},}/etc/systemd/system/"${service}".service
systemctl daemon-reload
systemctl enable  "${service}"
systemctl start   "${service}"
systemctl status  "${service}"
EOF
