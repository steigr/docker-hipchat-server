#!/usr/bin/env bash

[[ "$TRACE" ]] && set -x
set -e

HIPCHAT_SERVER_DEFAULT_INIT_SERVICES="systemd-hostnamed nginx sudo snmpd ssh redisserver redisstats mysql memcached postfix elasticsearch hipchat fake-init"

_sync() {
	chown "$3" "$2"
	rsync --update --archive --recursive "$1"/ "$2"/
}

_sync /bootstrap/chat_history /chat_history  root:root
_sync /bootstrap/file_store   /file_store    root:root
_sync /bootstrap/mysql        /var/lib/mysql mysql:mysql
_sync /bootstrap/hipchat      /hipchat       root:root
_sync /bootstrap/hipchat-scm  /hipchat-scm   root:root

ip=$(ip r g 1.0.0.0 | xargs | cut -f7 -d" ")
hostname_f=$(hostname -f)
hostname_s=$(hostname -s)

printf "nameserver 8.8.8.8" > /etc/resolv.conf

cat<<hosts > /etc/hosts
127.0.0.1       $hostname_f $hostname_s localhost localhost.localdom


# Network nodes


# Services
$ip      graphite.hipchat.com           # $hostname_f
$ip      mysql.hipchat.com              # $hostname_f
$ip      redis-master.hipchat.com       # $hostname_f
$ip      redis-slave.hipchat.com        # $hostname_f


# IPv6
::1             ip6-localhost ip6-loopback
fe00::0         ip6-localnet
ff00::0         ip6-mcastprefix
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
ff02::3         ip6-allhosts
hosts

unset HIPCHAT_SERVER_HOSTNAME
unset HIPCHAT_SERVER_NAME
unset HIPCHAT_SERVER_IMAGE
unset HIPCHAT_SERVER_DATA
unset HIPCHAT_SERVER_NETWORK

echo '# /lib/init/fstab: cleared out for bare-bones Docker' > /lib/init/fstab

echo '# /etc/fstab: cleared out for bare-bones Docker' > /etc/fstab

echo | install -D -o www-data /dev/stdin /var/log/nginx/error.log
install -D -d -o ntp /var/log/ntpstats
install -D -d -o redis -g redis /var/lib/redis
chown -R redis:redis /var/lib/redis /usr/local/var/lib/redis

chown -R postfix /var/lib/postfix /var/spool/postfix
chmod -R 755 /var/spool/postfix
chmod 1733 /var/spool/postfix/maildrop

touch /var/log/redis-server.log
chown -R redis /var/log/redis*

chown -R mysql:mysql /var/log/mysql /var/lib/mysql

chmod 1777 /tmp /var/tmp

chmod 4755 /usr/bin/sudo

chown -R elasticsearch /chat_history/elasticsearch /var/log/hipchat/elasticsearch.log

mount -t selinuxfs selinuxfs /sys/fs/selinux

_jq() {
	f="$1"; shift
	d="$(dirname "$f")"
	[[ -d "$d" ]] || mkdir -p "$d"
	[[ -f "$f" ]] || echo '{}' > "$f"
	t=$(mktemp)
	jq "$@" > "$t" < "$f"
	cat "$t" > "$f"
	rm "$t"
}

[[ "$HIPCHAT_SERVER_ID" ]]      && _jq /hipchat/config/btf_license.json --arg ID  "$HIPCHAT_SERVER_ID"      '. * {license_parameters: {ServerID: $ID}}'
[[ "$HIPCHAT_SERVER_LICENSE" ]] && _jq /hipchat/config/btf_license.json --arg LIC "$HIPCHAT_SERVER_LICENSE" '. * {license: $LIC}'

cat /hipchat/config/btf_license.json  | jq '.'

(sleep 2; for i in $HIPCHAT_SERVER_INIT_SERVICES $HIPCHAT_SERVER_DEFAULT_INIT_SERVICES; do service $i start; done; ) </dev/null >/dev/null 2>/dev/null &

exec /sbin/init
