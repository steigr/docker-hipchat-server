#!/usr/bin/env bash

[[ "$TRACE" ]] && set -x
set -e

export DEBIAN_FRONTEND=noninteractive

mount -t selinuxfs selinuxfs /sys/fs/selinux
mount -o remount,ro /sys/fs/selinux

dpkg-divert --rename --remove /usr/sbin/grub-probe
rm /usr/sbin/grub-probe
ln -s /bin/true /usr/sbin/grub-probe

printf 'deb [arch=amd64] http://archive.ubuntu.com/ubuntu trusty main universe' | install -D -m 0644 /dev/stdin /etc/apt/sources.list.d/ubuntu.list
apt-get install -f -y
apt update
apt install -y selinux

curl -sL https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 | install -m 0755 /dev/stdin /usr/bin/jq

dpkg -l | grep "ii\s*linux-" | awk '{print $2}' | xargs apt purge -y
apt purge -y acpid irqbalance crda python-xapian wireless-regdb
apt-get autoremove -y
apt install -y linux-libc-dev libc-dev-bin libjpeg-dev

echo "# cleared for docker" > /hipchat-scm/chef-repo/cookbooks/hipchat_server_cleanup/recipes/kernel_tuning.rb

sed -ri 's/^session\s+required\s+pam_loginuid.so$/session optional pam_loginuid.so/' /etc/pam.d/sshd
sed -ri 's/^PermitRootLogin\s+.*/PermitRootLogin yes/' /etc/ssh/sshd_config

echo 'root:docker.io' | chpasswd

/usr/sbin/update-rc.d -f ondemand remove; \
for f in \
	/etc/init/u*.conf \
	/etc/init/mounted-dev.conf \
	/etc/init/mounted-proc.conf \
	/etc/init/mounted-run.conf \
	/etc/init/mounted-tmp.conf \
	/etc/init/mounted-var.conf \
	/etc/init/hostname.conf \
	/etc/init/networking.conf \
	/etc/init/tty*.conf \
	/etc/init/plymouth*.conf \
	/etc/init/hwclock*.conf \
	/etc/init/module*.conf\
; do \
	dpkg-divert --local --rename --add "$f"; \
done; \

echo '# /lib/init/fstab: cleared out for bare-bones Docker' > /lib/init/fstab

echo '# /etc/fstab: cleared out for bare-bones Docker' > /etc/fstab

cat<<'systemd_hostnamed' > /etc/init/systemd-hostnamed.conf
description     "Systemd Hostnamed"

start on dbus

exec /lib/systemd/systemd-hostnamed
systemd_hostnamed

cat<<'fake_init' > /etc/init/fake-init.conf
# fake some events needed for correct startup other services

description     "In-Container Upstart Fake Events"

start on startup

script
	rm -rf /var/run/*.pid
	rm -rf /var/run/network/*
	/sbin/initctl emit stopped JOB=udevtrigger --no-wait
	/sbin/initctl emit started JOB=udev --no-wait
	/sbin/initctl emit runlevel RUNLEVEL=3 --no-wait
end script
fake_init