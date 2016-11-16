#!/usr/bin/env bash

[[ "$TRACE" ]] && set -x
set -e

HIPCHAT_SERVER_OVA_URL=${HIPCHAT_SERVER_OVA_URL}
HIPCHAT_SERVER_IMAGE=${HIPCHAT_SERVER_IMAGE:-hipchat-server}


DST="${DST:-$PWD}"
SRC="${SRC:-$DST/system}"

# Conversion of OVA -> CHROOT
if [[ ! -d "$SRC" ]]; then

	if [[ ! -f hipchat.tar ]]; then
		if [[ ! -f system.vmdk ]]; then
			# Download HipChat Server OVA
			wget -c ${HIPCHAT_SERVER_OVA_URL}
			# Extract disk images
			tar xf HipChat.ova
			rm HipChat.ova
		fi
		# Compress complete system
		cat<<'guestfish_script' | BOOT=/usr/boot ./guestfish --ro --add=system.vmdk --add=file_store.vmdk --add=chat_history.vmdk
run
vg-activate-all true
mount /dev/sda6 /
mount /dev/sda1 /boot
mount /dev/sda7 /var/log
mount /dev/file_store_vg/file_store /file_store
mount /dev/chat_history_vg/chat_history /chat_history
tar-out / hipchat.tar
shutdown
guestfish_script
		rm system.vmdk -a file_store.vmdk -a chat_history.vmdk
	fi
	# uncompress image
	docker run --volume=$PWD/hipchat.tar:/hipchat.tar --volume=$SRC:/system --rm alpine sh -c 'apk add --update tar; exec tar -xPf /hipchat.tar -C /system'
	# remove temporary archive
	rm -f hipchat.tar
fi

# End Conversion of OVA -> CHROOT
docker run -e TRACE --rm $(cd "$SRC"; ls | grep -v -e dev -e proc -e sys -e run -e initrd.img -e initrd.img.old -e vmlinuz -e vmlinuz.old -e lost+found | xargs -n1 -I{} printf -- ' --volume=%s:%s' $SRC/{} /{}) --volume=$PWD/prepare.sh:/prepare.sh --entrypoint=/prepare.sh --env=container=docker --privileged busybox

# create entrypoint-script
docker run --rm -i -v $SRC:$SRC -w $SRC alpine install -m 0755 /dev/stdin docker-entrypoint.sh < docker-entrypoint.sh

# ignore certain files
docker run --rm -i -v $SRC:$SRC -w $SRC alpine install -m 0644 /dev/stdin .dockerignore < .dockerignore

# go to system archive
pushd "$SRC"

# build docker file

cat <<Dockerfile | docker run -i -v $PWD:$PWD -w $PWD alpine install -m 0755 /dev/stdin Dockerfile
from scratch

add bin /bin
add sbin /sbin
add mnt /mnt
add etc /etc
add home /home
add srv /srv
add lib64 /lib64
add lib /lib
add opt /opt
add usr /usr

# add all except /var/lib
$(cd "$SRC"; ls var | grep -v -e lib -e lock -e run | xargs -n1 -I{} printf 'add var/{} /var/{}\n')

# add all except /var/lib/mysql
$(cd "$SRC"; ls var/lib | grep -v mysql | xargs -n1 -I{} printf 'add var/lib/{} /var/lib/{}\n')

run ln -s /run /var/run && ln -s /run/lock /var/lock

volume /file_store /chat_history /run /tmp /root /var/lib/mysql /hipchat /hipchat-scm /opt/atlassian/crowd/apache-tomcat/logs /var/log /var/tmp

add var/lib/mysql /bootstrap/mysql
add file_store /bootstrap/file_store
add chat_history /bootstrap/chat_history
add hipchat /bootstrap/hipchat
add hipchat-scm /bootstrap/hipchat-scm

env container docker

entrypoint ["hipchat"]

expose 22 80 443 5222 5223

add docker-entrypoint.sh /bin/hipchat
Dockerfile


# build it
docker run -v $PWD:$PWD -w $PWD -v /var/run/docker.sock:/var/run/docker.sock docker docker build -t ${HIPCHAT_SERVER_IMAGE} .

popd

# remove temporary image
docker run --volume=$SRC/..:/workdir --workdir=/workdir --rm alpine sh -c "exec rm -rf '$SRC'"