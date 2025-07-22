#!/bin/false

pkg=(openssh-server openssh-client)
bin=(/usr/sbin/sshd /usr/lib/openssh/{sshd-session,sshd-auth} /usr/bin/{ssh,scp,sftp,ssh-keygen})
etc=(/etc/ssh/moduli)
: "${pkg:?}" "${bin:?}" "${etc:?}"

# etc
install_dest /etc/ssh/sshd_config <<'EOF'
SshdAuthPath ${dest}/sshd-auth
SshdSessionPath ${dest}/sshd-session
Subsystem sftp internal-sftp
HostKey /etc/ssh/ssh_host_ed25519_key
AuthorizedKeysFile .ssh/authorized_keys
UsePAM yes
KbdInteractiveAuthentication no
PermitRootLogin no
MaxAuthTries 2
LoginGraceTime 30s
AllowTcpForwarding no
AllowAgentForwarding no
PrintMotd no
EOF

# service
install_dest /usr/lib/systemd/system/sshd.service <<'EOF'
[Unit]
Description=sshd
After=network.target

[Service]
Type=notify
RuntimeDirectory=sshd
RuntimeDirectoryMode=0755
ExecStartPre=${dest}/ssh-keygen -A
ExecStartPre=${dest}/sshd -t
ExecStart=${dest}/sshd -D
ExecReload=${dest}/sshd -t
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
RestartSec=42s
RestartPreventExitStatus=255

[Install]
WantedBy=multi-user.target
EOF

# setup
install_setup <<'EOF'
# dir
ln -vsf /usr/lib64/security /usr/lib/security

# etc
rm -vf /etc/init.d/sshd
ln -vsf {${dest},}/etc/ssh/moduli
ln -vsf {${dest},}/etc/ssh/sshd_config

# service
ln -vsf {${dest},}/usr/lib/systemd/system/sshd.service
systemctl daemon-reload
systemctl stop sshd || :
systemctl start sshd
systemctl enable sshd
systemctl status sshd
EOF
