#!/bin/false

# shellcheck disable=SC2034
pkg=(openssh-server openssh-client)
bin=(/usr/sbin/{sshd,faillock} /usr/lib/openssh/{sshd-session,sshd-auth} /usr/bin/{ssh,scp,sftp,ssh-keygen})
etc=(/usr/lib/*-linux-gnu/security /etc/ssh/moduli)
ldd=("${etc[0]}"/*.so)

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
AllowTcpForwarding no
AllowAgentForwarding no
PrintMotd no
EOF

# pam.d
install_dest /etc/pam.d/sshd <<'EOF'
@include debian-common-auth
account     required    pam_nologin.so
@include debian-common-account
session     [success=ok ignore=ignore module_unknown=ignore default=bad] pam_selinux.so close
session     required    pam_loginuid.so
session     optional    pam_keyinit.so force revoke
@include debian-common-session
session     optional    pam_motd.so motd=/run/motd.dynamic
session     optional    pam_motd.so noupdate
session     optional    pam_mail.so standard noenv
session     required    pam_limits.so
session     required    pam_env.so
session     required    pam_env.so envfile=/etc/default/locale
session     [success=ok ignore=ignore module_unknown=ignore default=bad] pam_selinux.so open
@include debian-common-password
EOF
# other
perl -pe 's/other/dbian/' /usr/lib/*-linux-gnu/libpam.so.0 | install_dest /lib/libpam.so.0-dbian
install_dest /etc/pam.d/dbian <<'EOF'
@include debian-common-auth
@include debian-common-account
@include debian-common-password
@include debian-common-session
EOF
install_dest /etc/pam.d/debian-common-auth <<'EOF'
auth        required        pam_faillock.so preauth  audit silent even_deny_root
auth        [success=1 default=ignore] pam_unix.so nullok
auth        [default=die]   pam_faillock.so authfail audit silent even_deny_root
auth        sufficient      pam_faillock.so authsucc audit silent even_deny_root
auth        requisite   pam_deny.so
auth        required    pam_permit.so
EOF
install_dest /etc/pam.d/debian-common-account <<'EOF'
account     [success=1 new_authtok_reqd=done default=ignore] pam_unix.so
account     requisite   pam_deny.so
account     required    pam_permit.so
EOF
install_dest /etc/pam.d/debian-common-password <<'EOF'
password    [success=1 default=ignore] pam_unix.so obscure yescrypt
password    requisite   pam_deny.so
password    required    pam_permit.so
EOF
install_dest /etc/pam.d/debian-common-session <<'EOF'
session     [default=1] pam_permit.so
session     requisite   pam_deny.so
session     required    pam_permit.so
session     optional    pam_umask.so
session     required    pam_unix.so
session     optional    pam_systemd.so
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
if [[ ! -f /etc/deepin-version ]]; then
    ln -vsf /usr/lib64/security /usr/lib/
    rm ${dest}/lib/libpam.so.0-dbian
else
    ln -vsf ${dest}/usr/lib/*-linux-gnu/security /usr/lib/
    ln -vsf ${dest}/etc/pam.d/* /etc/pam.d/
    mv -v ${dest}/lib/libpam.so.0{-dbian,}
fi

# etc
ln -vsf {${dest},}/etc/ssh/moduli

# service
service='sshd'
systemctl stop    "${service}"
systemctl disable "${service}"
ln -vsf {${dest},}/usr/lib/systemd/system/"${service}".service; rm -vf /etc/init.d/sshd
systemctl daemon-reload
systemctl enable  "${service}"
systemctl start   "${service}"
systemctl status  "${service}"
EOF
