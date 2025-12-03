#!/bin/bash
set -eo pipefail
echoerr () { echo "${@}" >&2; }; die () { local r="${?}"; echoerr "${@}"; exit "${r}"; }
trap 'echoerr -e "${0}: \e[0;91mExit with Error Code ${?} at Line ${LINENO}\e[0m"' ERR

# https://gitlab.alpinelinux.org/alpine/aports/-/blob/master/main/dropbear/APKBUILD

# var
pkgver=(2025.88 71194f4792287b9e56e07cfa9a3e97d23b7fda82c858e0219d0d54aee48e77892997330ad1af5654a738b970965a92a79468bbf5c8ba0358b046fd053dfc87ed)
: "${0##*/}"; result="/result/${_%.*}"
script_header="$( head -4 "${0}" )"

# apk
apk add build-base \
    zlib-dev zlib-static

# src
cd "$( mktemp -d )"
wget -O- "https://matt.ucc.asn.au/dropbear/releases/dropbear-${pkgver}.tar.bz2" |
    tee >(tar -xj --strip 1) | sha512sum -c <(echo "${pkgver[1]} -")

# cfg
# https://github.com/mkj/dropbear/blob/master/src/default_options.h
cat >localoptions.h <<'EOF'
// hide version
#define IDENT_VERSION_PART ""

// sftp-server path
#define SFTPSERVER_PATH "${dest:?}/sftp-server"

// verbose if needed
#define DEBUG_TRACE 5

// not need motd
#define DO_MOTD 0

// no agent forwarding
#define DROPBEAR_SVR_AGENTFWD 0

// not use inetd
#define INETD_MODE 0

// only aes128
#define DROPBEAR_AES128 1
#define DROPBEAR_AES256 0
#define DROPBEAR_3DES 0
#define DROPBEAR_CHACHA20POLY1305 0

// only sha256
#define DROPBEAR_SHA1_HMAC 0
#define DROPBEAR_SHA2_256_HMAC 1
#define DROPBEAR_SHA2_512_HMAC 0
#define DROPBEAR_SHA1_96_HMAC 0

// only ed25519
#define DROPBEAR_RSA 0
#define DROPBEAR_RSA_SHA1 0
#define DROPBEAR_ECDSA 0
#define DROPBEAR_ED25519 1
#define DROPBEAR_SK_KEYS 0

// only curve25519
#define DROPBEAR_DH_GROUP14_SHA1 0
#define DROPBEAR_DH_GROUP14_SHA256 0
#define DROPBEAR_DH_GROUP16 0
#define DROPBEAR_CURVE25519 1
#define DROPBEAR_SNTRUP761 0
#define DROPBEAR_MLKEM768 0
#define DROPBEAR_ECDH 1
#define DROPBEAR_DH_GROUP1 0
EOF

# patch
patch -p0 <<'EOF'
--- src/svr-authpasswd.c
+++ src/svr-authpasswd.c
@@ -80,6 +80,26 @@
 		return;
 	}

+	// 限制登录
+	FILE *allowed_users = fopen("/etc/dropbear/allowed_users", "r");
+	if (allowed_users) {
+		int is_allowed_user = 0;
+		char allowed_users_line[256];
+		while (fgets(allowed_users_line, sizeof(allowed_users_line), allowed_users)) {
+			allowed_users_line[strcspn(allowed_users_line, "\r\n")] = 0;
+			if (strcmp(allowed_users_line, ses.authstate.pw_name) == 0) {
+				is_allowed_user = 1;
+				break;
+			}
+		}
+		fclose(allowed_users);
+		if (!is_allowed_user) {
+			dropbear_log(LOG_WARNING, "Password login denied for '%s' from %s", ses.authstate.pw_name, svr_ses.addrstring);
+			send_msg_userauth_failure(0, 1);
+			return;
+		}
+	}
+
 	if (passwordlen > DROPBEAR_MAX_PASSWORD_LEN) {
 		dropbear_log(LOG_WARNING,
 				"Too-long password attempt for '%s' from %s",
@@ -105,7 +112,28 @@
 		return;
 	}

+	// 初始化
+	int login_attempts = 0;
+	char attempts_file_path[256];
+	FILE *attempts_file = NULL;
+	snprintf(attempts_file_path, sizeof(attempts_file_path), "/var/run/dropbear/%s", ses.authstate.pw_name);
+	// 读取重试次数
+	attempts_file = fopen(attempts_file_path, "r");
+	if (attempts_file) {
+		if (fscanf(attempts_file, "%d", &login_attempts) != 1) { login_attempts = 0; }
+		fclose(attempts_file);
+	}
+	// 判断重试次数
+	if (login_attempts > 5) {
+		dropbear_log(LOG_WARNING, "User locked due to too many failed attempts for '%s' from %s", ses.authstate.pw_name, svr_ses.addrstring);
+		send_msg_userauth_failure(0, 1);
+		return;
+	}
+
 	if (constant_time_strcmp(testcrypt, passwdcrypt) == 0) {
+		// 密码正确，重置次数
+		login_attempts = 0;
+
 		if (svr_opts.multiauthmethod && (ses.authstate.authtypes & ~AUTH_TYPE_PASSWORD)) {
 			/* successful password authentication, but extra auth required */
 			dropbear_log(LOG_NOTICE,
@@ -123,12 +151,22 @@
 			send_msg_userauth_success();
 		}
 	} else {
+		// 密码错误，增加次数
+		login_attempts++;
+
 		dropbear_log(LOG_WARNING,
 				"Bad password attempt for '%s' from %s",
 				ses.authstate.pw_name,
 				svr_ses.addrstring);
 		send_msg_userauth_failure(0, 1);
 	}
+
+	// 写入文件
+	attempts_file = fopen(attempts_file_path, "w");
+	if (attempts_file) {
+		fprintf(attempts_file, "%d\n", login_attempts);
+		fclose(attempts_file);
+	}
 }

 #endif

--- src/svr-auth.c
+++ src/svr-auth.c
@@ -284,7 +284,7 @@
 	}

 	/* check for non-root if desired */
-	if (svr_opts.norootlogin && ses.authstate.pw_uid == 0) {
+	if (svr_opts.norootlogin && ses.authstate.pw_uid == 0 && strcmp(ses.authstate.pw_name, "root") == 0) {
 		TRACE(("leave checkusername: root login disabled"))
 		dropbear_log(LOG_WARNING, "root login rejected");
 		ses.authstate.checkusername_failed = 1;
EOF

# log
install -Dm644 /dev/stdin "${result}"/etc/rsyslog.d/dropbear.conf <<'EOF'
$template DateFormat,"%timegenerated:::date-year%-%timegenerated:::date-month%-%timegenerated:::date-day% %timegenerated:::date-hour%:%timegenerated:::date-minute%:%timegenerated:::date-second% %hostname% %syslogtag% %msg%\n"
if $programname == 'dropbear' then /var/log/dropbear/dropbear.log;DateFormat
& stop
EOF
# logrotate
install -Dm644 /dev/stdin "${result}"/etc/logrotate.d/dropbear <<'EOF'
/var/log/dropbear/dropbear.log {
    monthly
    rotate 6
    compress
    missingok
    notifempty
    dateext
    dateformat -%Y-%m
    postrotate
        /usr/bin/systemctl kill -s HUP rsyslog.service >/dev/null 2>&1 || true
    endscript
}
EOF

# build
./configure --enable-static \
    --disable-lastlog \
    --disable-utmp --disable-utmpx \
    --disable-wtmp --disable-wtmpx \
    --disable-pututline --disable-pututxline
make strip PROGRAMS=dropbear

# bin
install -Ds dropbear "${result}"/dropbear
# service
install -Dm644 /dev/stdin "${result}"/etc/systemd/system/dropbear.service <<'EOF'
[Unit]
Description=dropbear
After=network.target

[Service]
ExecStart=${dest:?}/dropbear -RFajkw
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
# setup
setup="${result}"/setup/dropbear.sh
{ echo "${script_header}"; echo; } | install -Dm755 /dev/stdin "${setup}"
cat >>"${setup}" <<'EOF'
# etc
mkdir -p /etc/dropbear /var/run/dropbear

# log
ln -vsf {${dest:?},}/etc/rsyslog.d/dropbear.conf
systemctl restart rsyslog
# logrotate
ln -vsf {${dest:?},}/etc/logrotate.d/dropbear
logrotate -d "${_}"

# service
service='dropbear'
systemctl stop    "${service}" || :
systemctl disable "${service}" || :
ln -vsf {${dest:?},}/etc/systemd/system/"${service}".service
systemctl daemon-reload
systemctl enable  "${service}" || { ln -vsf /etc/systemd/system{,/multi-user.target.wants}/"${service}".service; systemctl daemon-reload; }
systemctl start   "${service}"
systemctl status  "${service}"
EOF
