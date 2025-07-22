#!/bin/false

pkg=(apache2)
bin=(/usr/sbin/apache2)
etc=(/usr/lib/apache2/modules)

# etc
install_dest /etc/apache2/apache2.conf <<'EOF'
Listen 80
User apache2
Group apache2
DefaultRuntimeDir /var/run/apache2
PidFile /var/run/apache2/apache2.pid
ErrorLog /dev/stderr
LogLevel warn

Timeout 300
KeepAlive On
MaxKeepAliveRequests 100
KeepAliveTimeout 5
HostnameLookups Off

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

# service
install_dest /usr/lib/systemd/system/apache2.service <<'EOF'
[Unit]
Description=apache2
After=network.target remote-fs.target nss-lookup.target

[Service]
Environment="LANG=C"
RuntimeDirectory=apache2
RuntimeDirectoryMode=0755
ExecStartPre=${dest}/apache2 -t
ExecStart=${dest}/apache2 -D FOREGROUND
ExecReload=${dest}/apache2 -t
ExecReload=/bin/kill -SIGUSR1 $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

# setup
install_setup <<'EOF'
# user
groupadd -f apache2
useradd -g apache2 -d /var/empty/apache2 -s /usr/sbin/nologin apache2 || :

# dir
mkdir -p /etc/apache2
install -vd -o apache2 -g apache2 /var/empty/apache2

# etc
ln -vsf {${dest},}/etc/apache2/apache2.conf
ln -vsf ${dest}/usr/lib/apache2/modules /etc/apache2/

# service
ln -vsf {${dest},}/usr/lib/systemd/system/apache2.service
systemctl daemon-reload
systemctl stop apache2 || :
systemctl start apache2
EOF
