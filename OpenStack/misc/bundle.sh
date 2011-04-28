#!/bin/bash

ABS_PATH=`dirname "$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"`
source $ABS_PATH/bundle.env

function usage {
	echo "$0 <bucket>"
}

if [ -z $EC2_ACCESS_KEY ]; then
	echo "you need to set your cloud credentials."
	echo "try sourcing your novarc file"
	exit 1
fi

if [ -z "$1" ]; then
	usage
else
	BUCKET=$1
	echo "The bucket is $BUCKET"
fi


# exit if any variable is not set
set -o nounset 

IMAGE_LIST=$(euca-describe-images | grep "$BUCKET" | cut -f 2 | sort)

echo "********** Deregistering images **********"
for image in $IMAGE_LIST; do
	echo "de-registered '$image'"
	euca-deregister $image
done

if [ -n "$IMAGE_LIST" ]; then
	echo "deleting bundle '$BUCKET'"
	euca-delete-bundle -b $BUCKET
fi

echo ""
echo "********** Bundle/Upload/Register RamDisk **********"
euca-bundle-image --ramdisk true -d /tmp/$BUCKET/ -i $IMAGE_DIR/$BUCKET/initrd.img
euca-upload-bundle -b $BUCKET -m /tmp/$BUCKET/initrd.img.manifest.xml
ARI=$(euca-register $BUCKET/initrd.img.manifest.xml | awk '{print $2}')

echo ""
echo "********** Bundle/Upload/Register Kernel **********"
euca-bundle-image --kernel true -d /tmp/$BUCKET/ -i $IMAGE_DIR/$BUCKET/vmlinuz
euca-upload-bundle -b $BUCKET -m /tmp/$BUCKET/vmlinuz.manifest.xml
AKI=$(euca-register $BUCKET/vmlinuz.manifest.xml | awk '{print $2}')

echo ""
echo "********** Bundle/Upload/Register Image **********"
euca-bundle-image --kernel $AKI --ramdisk $ARI -d /tmp/$BUCKET/ -i $IMAGE_DIR/$BUCKET/filesystem.img
euca-upload-bundle -b $BUCKET -m /tmp/$BUCKET/filesystem.img.manifest.xml
export AMI=$(euca-register $BUCKET/filesystem.img.manifest.xml | awk '{print $2}')
echo "********** done *************"
echo "AMI=$AMI"
echo "ARI=$ARI"
echo "AKI=$AKI"
