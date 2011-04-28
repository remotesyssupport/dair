#!/bin/bash

ABS_PATH=`dirname "$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"`
source $ABS_PATH/bundle.env


# exit if any variable is not set
set -o nounset 

if [[ "$BUCKET" != *"centos"* && "$1" != *"rhel"* && "$1" != *"ubuntu"* ]]; then
	echo "don't recognise '$1'"
	echo "Only know how to handle bucket names containing"
	echo "    'centos', 'rhel', or 'ubuntu'"
	usage
	exit 1
fi

LOOP=$(losetup -f)
losetup $LOOP $IMAGE

kpartx -a $LOOP
PARTITION_MAP=$(ls /dev/mapper/*p1)

mkdir -p $MOUNT
mount -o loop $PARTITION_MAP $MOUNT

case $BUCKET in
	*centos* )
		echo "selected CentOS..."
		KERNEL_NUM=$(sudo sed -n -e "s/default=\([0-9]\)/\1/p" $MOUNT/etc/grub.conf)
		KERNEL_LIST=$(sudo sed -n -e "s;title CentOS (\(.*\));\1;p" $MOUNT/etc/grub.conf)
		KERNEL_ARRAY=($KERNEL_LIST)
		KERNEL=${KERNEL_ARRAY[$DEFAULT_KERNEL]}
		PATH_TO_KERNEL=/mnt/guest/boot
		;;

	*rhel* )
		echo "selected Red Hat..."
		KERNEL_NUM=$(sudo sed -n -e "s/default=\([0-9]\)/\1/p" $MOUNT/boot/grub/grub.conf)
		KERNEL_LIST=$(sudo sed -n -e "s/title Red Hat.*(\(.*\))/\1/p" $MOUNT/boot/grub/grub.conf)
		KERNEL_ARRAY=($KERNEL_LIST)
		KERNEL=${KERNEL_ARRAY[$KERNEL_NUM]}
		PATH_TO_KERNEL=$MOUNT/boot
		rm -f $MOUNT/var/lib/dhclient/*
		rm -f $MOUNT/etc/udev/rules.d/70-persistent-net.rules
		RAMDISK="initramfs"
		;;

	*ubuntu* )
		echo "selected ubuntu..."
		rm -f $MOUNT/lib/udev/rules.d/75-persistent-net-generator.rules
		PATH_TO_KERNEL=/mnt/guest
		;;

	* )
		echo "don't recognise $BUCKET.  Exiting."
		exit 1
		;;
esac

rm -f $IMAGE_DIR/$BUCKET/filesystem.img $IMAGE_DIR/$BUCKET/initrd.img $IMAGE_DIR/$BUCKET/vmlinuz
dd if=$PARTITION_MAP of=$IMAGE_DIR/$BUCKET/filesystem.img bs=1M
cp -u $PATH_TO_KERNEL/$RAMDISK-$KERNEL.img $IMAGE_DIR/$BUCKET/initrd.img
cp -u $PATH_TO_KERNEL/vmlinuz-$KERNEL $IMAGE_DIR/$BUCKET/vmlinuz

umount $MOUNT
kpartx -d $LOOP
losetup -d $LOOP
