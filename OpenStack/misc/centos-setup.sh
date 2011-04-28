#!/bin/bash

if [ -z $EC2_ACCESS_KEY ]; then
	echo "you need to set your cloud credentials."
	echo "try sourcing your novarc file"
	exit 1
fi

rm -f /root/*

sed -i "/MAC/d" /etc/sysconfig/network-scripts/ifcfg-eth0
/etc/init.d/network restart

cp /root/OpenStack/misc/euca2ools.repo /etc/yum.repos.d/
yum -y install euca2ools curl java-1.6.0-openjdk* gcc 

cp -f /root/OpenStack/misc/rc.local /etc/rc.local
echo modprobe acpiphp >> /etc/rc.modules
chmod +x /etc/rc.modules

yum -y upgrade
mkinitrd --with virtio_pci --with virtio_ring --with virtio_blk --with virtio_net --with virtio_balloon --with virtio -f /boot/initrd-$(uname -r).img $(uname -r)

echo "New kernel"
echo "Time to reboot"
