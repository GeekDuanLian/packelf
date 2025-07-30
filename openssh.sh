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
MaxAuthTries 2
LoginGraceTime 30s
AllowTcpForwarding no
AllowAgentForwarding no
PrintMotd no
EOF
install_dest /etc/pam.d/sshd <<'EOF'
# @include common-auth
auth        required        pam_faillock.so preauth  audit silent even_deny_root
auth        [success=1 default=ignore] pam_unix.so nullok
auth        [default=die]   pam_faillock.so authfail audit silent even_deny_root
auth        sufficient      pam_faillock.so authsucc audit silent even_deny_root
auth        requisite   pam_deny.so
auth        required    pam_permit.so
# end
account     required    pam_nologin.so
# @include common-account
account     [success=1 new_authtok_reqd=done default=ignore] pam_unix.so
account     requisite   pam_deny.so
account     required    pam_permit.so
# end
session     [success=ok ignore=ignore module_unknown=ignore default=bad] pam_selinux.so close
session     required    pam_loginuid.so
session     optional    pam_keyinit.so force revoke
# @include common-session
session     [default=1] pam_permit.so
session     requisite   pam_deny.so
session     required    pam_permit.so
session     optional    pam_umask.so
session     required    pam_unix.so
session     optional    pam_systemd.so
# end
session     optional    pam_motd.so motd=/run/motd.dynamic
session     optional    pam_motd.so noupdate
session     optional    pam_mail.so standard noenv
session     required    pam_limits.so
session     required    pam_env.so
session     required    pam_env.so envfile=/etc/default/locale
session     [success=ok ignore=ignore module_unknown=ignore default=bad] pam_selinux.so open
# @include common-password
password    [success=1 default=ignore] pam_unix.so obscure yescrypt
password    requisite   pam_deny.so
password    required    pam_permit.so
# end
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
ln -vsf ${dest}/usr/lib/*-linux-gnu/security /usr/lib/

# etc
rm -vf /etc/init.d/sshd
ln -vsf {${dest},}/etc/ssh/moduli
ln -vsf {${dest},}/etc/pam.d/sshd

# service
ln -vsf {${dest},}/usr/lib/systemd/system/sshd.service
systemctl daemon-reload
systemctl stop sshd || :
systemctl start sshd
systemctl enable sshd
systemctl status sshd
EOF
