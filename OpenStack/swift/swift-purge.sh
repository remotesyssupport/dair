#!/bin/bash

if [ `whoami` != root ]; then
	echo "Please run this as the user, 'root'!";
	exit 1
fi

swift-init proxy stop
swift-init auth stop

swift-init object-server stop
swift-init object-replicator stop
swift-init object-updater stop
swift-init object-auditor stop
swift-init container-server stop
swift-init container-replicator stop
swift-init container-updater stop
swift-init container-auditor stop
swift-init account-server stop
swift-init account-replicator stop
swift-init account-auditor stop

apt-get -y purge python-software-properties swift openssh-server swift-account swift-container swift-object xfsprogs swift-proxy memcached swift-auth

rm -rf /etc/swift
rm -rf /var/log/swift
rm -f /var/log/rsyncd.log

sed -i '/^\/dev\/sdb1.*$/d' /etc/fstab
umount /dev/sdb1
