#!/bin/bash

if [ -z $EC2_ACCESS_KEY ]; then
	echo "you need to set your cloud credentials."
	echo "try sourcing your novarc file"
	exit 1
fi

sed -i "s#LABEL=/#/dev/vda#g" /etc/fstab

rm -f /root/.userdata-init
rm -f /root/*

history -c && rm -f ~/.bash_history

BUCKETNAME="centos-5-6-server"
euca-bundle-image -i /boot/initrd-$(uname -r).img --ramdisk true
euca-upload-bundle -b $BUCKETNAME -m /tmp/initrd-$(uname -r).img.manifest.xml
ARI=$(euca-register $BUCKETNAME/initrd-$(uname -r).img.manifest.xml | awk '{print $2}')
echo $ARI

euca-bundle-image -i /boot/vmlinuz-$(uname -r) --kernel true
euca-upload-bundle -b $BUCKETNAME -m /tmp/vmlinuz-$(uname -r).manifest.xml
AKI=$(euca-register $BUCKETNAME/vmlinuz-$(uname -r).manifest.xml | awk '{print $2}')
echo $AKI

euca-bundle-vol --kernel $AKI --ramdisk $ARI -d /mnt -p $BUCKETNAME -s 10000 -e /mnt,/tmp,/root/.ssh,/root/dair,/root/creds-admin --no-inherit
euca-upload-bundle -b $BUCKETNAME -m /mnt/$BUCKETNAME.manifest.xml
euca-register $BUCKETNAME/$BUCKETNAME.manifest.xml

sed -i "s#/dev/vda#LABEL=/#g" /etc/fstab

rm -rf /mnt/*
