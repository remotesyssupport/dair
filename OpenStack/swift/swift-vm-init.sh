#!/bin/bash

#
# this scripts provisions a virtual machine for a Swift proxy installation
# on an ubuntu 10.10 os
#

ABS_PATH=`dirname "$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"`
source $ABS_PATH/swift.env

# exit if any unset variables
set -o nounset



test() {
	echo "NOVA_KEY_DIR = $NOVA_KEY_DIR"
	echo "EC2_ACCESS_KEY = $EC2_ACCESS_KEY"
	echo "EC2_SECRET_KEY = $EC2_SECRET_KEY"
	echo "EC2_URL = $EC2_URL"
	echo "EC2_CERT = $EC2_CERT"
	echo "EC2_PRIVATE_KEY = $EC2_PRIVATE_KEY"
	echo "S3_URL = $S3_URL"
	echo "EUCALYPTUS_CERT = $EUCALYPTUS_CERT"
	echo "INSTANCE_ID = $INSTANCE_ID"
	echo "PUBLIC_IP = $PUBLIC_IP"
	echo "PRIVATE_IP = $PRIVATE_IP"
	echo "VOLUME_ID = $VOLUME_ID"

}


cleanup() {
	for DEVICE in $(ls /dev | grep -E "vdc[0-9]"); do
		umount /dev/$DEVICE
	done
	rm -rf $MOUNTPOINT
}


setEnvironment() {
	source $NOVARC
	
	INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)
	PUBLIC_IP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)
	PRIVATE_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
}


setupVolume() {
	VOLUME_ID=$(euca-create-volume --size 2 -z nova | cut -f 2)
	echo $VOLUME_ID
	while [ $(euca-describe-volumes $VOLUME_ID | grep -c available) -eq 0 ]; do
		echo "not ready yet..."
	done
	echo "ready to attach"
	DEVICE=$(basename $(ls -t "/dev/$DRIVE_TYPE"* | grep -E "$DRIVE_TYPE[a-z]$" | head -1))
	echo "most recent device is $DEVICE"

	echo "euca-attach-volume -i $INSTANCE_ID -d /dev/vdc $VOLUME_ID"
	euca-attach-volume -i $INSTANCE_ID -d /dev/vdc $VOLUME_ID 
	while [ $(euca-describe-volumes $VOLUME_ID | grep -c in-use) -eq 0 ]; do
		echo "not attached yet..."
	done
	echo "okay, attached"
	DEVICE=$(basename $(ls -t "/dev/$DRIVE_TYPE"* | grep -E "$DRIVE_TYPE[a-z]$" | head -1))
	echo "most recent device is $DEVICE"
	
}


partitionDisk() {
	echo "partitioning $DEVICE"
	START=""
	ID=""
	BOOTABLE=""
	DATA_FILE="partition.data"
	CYLINDERS=$(sfdisk -l /dev/$DEVICE | grep cylinders | head -1 | cut -d " " -f 3)

	let PARTITIONS=${#DEVICES[@]}

	if [[ "$PARTITIONS" > 0 ]]; then
		let CYLINDERS=$CYLINDERS/$PARTITIONS
	fi

	echo "creating $PARTITIONS $CYLINDERS cylinder partitions"
	rm -f $DATA_FILE

	for i in $(seq 1 1 $PARTITIONS); do
		echo $START, $CYLINDERS, $ID, $BOOTABLE >> $DATA_FILE
	done

	# the remaing partitions are empty
	let PARTITIONS=$i+1
	CYLINDERS="0"

	for j in $(seq $PARTITIONS 1 4); do
		echo $START, $CYLINDERS, $ID, $BOOTABLE >> $DATA_FILE
	done

	/sbin/sfdisk "/dev/$DEVICE" < $DATA_FILE
}


mountDisk() {
	echo "mounting attached storage on $MOUNTPOINT"
	mkdir -p $MOUNTPOINT
	
	apt-get install -y xfsprogs

	for DEVICE in $(ls /dev/* | grep -E "$DEVICE[0-9]"); do
		mkfs.xfs -f -i size=1024 /dev/$DEVICE
		echo "/dev/$DEVICE $MOUNTPOINT/$DEVICE xfs noatime,nodiratime,nobarrier,logbufs=8 0 0" >> /etc/fstab
		mkdir -p $MOUNTPOINT/$DEVICE
		mount /dev/$DEVICE $MOUNTPOINT/$DEVICE
	done
	echo "chown -R swift $MOUNTPOINT"
}

# cleanup 
setEnvironment
setupVolume
partitionDisk
# the node install script mounts the disks
# mountDisk
