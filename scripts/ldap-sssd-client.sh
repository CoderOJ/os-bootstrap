set -eou pipefail

apt install sssd dialog

cat >> /etc/ssh/sshd_config << EOF
AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys
AuthorizedKeysCommandUser nobody
EOF
systemctl restart sshd

cat > /etc/sssd/sssd.conf << EOF
[sssd]
services = nss, pam, ssh
domains = LDAP
config_file_version = 2

[domain/LDAP]
id_provider = ldap
auth_provider = ldap
chpass_provider = ldap

ldap_uri = ldap://192.168.3.102
ldap_id_use_start_tls = false
ldap_tls_reqcert = never
ldap_search_base = dc=cscg,dc=com

ldap_default_bind_dn = uid=ldapreader,ou=People,dc=cscg,dc=com
ldap_default_authtok_type = password
ldap_default_authtok = ldapreader

# 用户 / 组搜索
ldap_user_search_base = ou=People,dc=cscg,dc=com
ldap_group_search_base = ou=Groups,dc=cscg,dc=com

# SSH 公钥
ldap_user_ssh_public_key = sshPublicKey

# disable cache
cache_credentials = false
memcache_timeout = 0

enumerate = false
use_fully_qualified_names = false
fallback_homedir = /home/%u
EOF
chmod 640 /etc/sssd/sssd.conf
systemctl restart sssd

cat > /usr/share/pam-configs/custom-ldap-init << EOF
Name: LDAP User Home Initialization
Default: yes
Priority: 900
Session-Type: Additional
Session:
    optional    pam_exec.so seteuid /home/cscg/init-user.sh
EOF
pam-auth-update

cat > /home/cscg/init-user.sh << 'EOF'
#!/bin/bash

USERNAME="${PAM_USER}"

# 获取用户信息
USER_INFO=$(getent passwd "$USERNAME")

# 解析字段
USER_UID=$(echo "$USER_INFO" | cut -d: -f3)
USER_GID=$(echo "$USER_INFO" | cut -d: -f4)  # ⭐ 主组 GID
USER_HOME=$(echo "$USER_INFO" | cut -d: -f6)

if [ ! -d "$USER_HOME" ] ; then
	# create home dir
	btrfs subvolume create "$USER_HOME"
	btrfs qgroup limit 500G "$USER_HOME"
	cp -r /etc/skel/. "$USER_HOME"
	chown -R $USER_UID:$USER_GID "$USER_HOME"
	chmod 755 "$USER_HOME"
fi
EOF
chown cscg:cscg /home/cscg/init-user.sh
chmod +x /home/cscg/init-user.sh
