#! /bin/bash

ABS_PATH=`dirname "$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"`
source $ABS_PATH/cloudpipe.env


if [ `whoami` != root ]; then
        echo "Please run this as the user, 'root'!";
        exit 1
fi

# get the cloud credentials required for bundling
mkdir /bundle
echo "I'm going to copy your cloud credentials '$CLOUD_CREDS_ARCHIVE' from '$CC_HOST', I'll need your password"
scp $DAIR_ADMIN@$CC_HOST:$DAIR_ADMIN_HOME/$CLOUD_CREDS_DIR/$CLOUD_CREDS_ARCHIVE /bundle/

if [ ! -f "/bundle/$CLOUD_CREDS_ARCHIVE" ]; then
	echo "can't find /bundle/$CLOUD_CREDS_ARCHIVE"
	exit 1
fi

apt-get -y install zip curl
unzip -d /bundle /bundle/$CLOUD_CREDS_ARCHIVE 
source /bundle/$NOVARC

if [ -z $EC2_ACCESS_KEY ]; then
	echo "you need to set your cloud credentials."
	echo "try sourcing your $NOVARC file"
	exit 1
fi


echo "getting volume and instance IDs..."
VOLUME_ID=$(euca-create-volume -s 2 -z nova| cut -f 2)
INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)

while [[ `euca-describe-volumes $VOLUME_ID` != *'available'* ]]; do
	echo "waiting for volume $VOLUME_ID..."
	sleep 2
done
echo "attaching volume $VOLUME_ID..."
euca-attach-volume $VOLUME_ID -i $INSTANCE_ID -d $DEVICE

# give the disk a chance to attach
sleep 5

mkfs $DEVICE
mkdir -p $MOUNTPOINT
mount $DEVICE $MOUNTPOINT

apt-get -y update
apt-get -y upgrade
apt-get -y install bridge-utils openvpn openssl euca2ools rsync

echo "writing /etc/openvpn/server.conf.template..."
cat > /etc/openvpn/server.conf.template << EOF
port 1194
proto udp
dev tap0
up "/etc/openvpn/up.sh br0"
down "/etc/openvpn/down.sh br0"

persist-key
persist-tun

ca ca.crt
cert server.crt
key server.key  # This file should be kept secret

dh dh1024.pem
ifconfig-pool-persist ipp.txt

server-bridge VPN_IP DHCP_SUBNET DHCP_LOWER DHCP_UPPER

client-to-client
keepalive 10 120
comp-lzo

max-clients 1

user nobody
group nogroup

persist-key
persist-tun

status openvpn-status.log

verb 3
mute 20

EOF

FILE="/etc/openvpn/up.sh"
echo "writing $FILE..."
cat > $FILE << EOF
#!/bin/sh

BR=\$1
DEV=\$2
MTU=\$3

/sbin/ifconfig \$DEV mtu \$MTU promisc up
/usr/sbin/brctl addif \$BR \$DEV
EOF
chmod +x $FILE

FILE="/etc/openvpn/down.sh"
echo "writing $FILE..."
cat > $FILE << EOF
#!/bin/sh

BR=\$1
DEV=\$2

/usr/sbin/brctl delif \$BR \$DEV
/sbin/ifconfig \$DEV down
EOF
chmod +x $FILE


FILE="/etc/network/interfaces"
echo "writing $FILE..."
cat > $FILE << EOF
# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet manual
  up ifconfig \$IFACE 0.0.0.0 up
  # up ip link set \$IFACE promisc on
  down ifconfig \$IFACE down 
  # down ip link set \$IFACE promisc off

auto br0
iface br0 inet dhcp
  bridge_ports eth0
  # bridge_fd 9      ## from the libvirt docs (forward delay time)
  # bridge_hello 2   ## from the libvirt docs (hello time)
  # bridge_maxage 12 ## from the libvirt docs (maximum message age)
  # bridge_stp off   ## from the libvirt docs (spanning tree protocol)

EOF



FILE="/etc/rc.local"
echo "writing $FILE..."
cat > $FILE << EOF
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#

echo Downloading payload from userdata
wget http://169.254.169.254/latest/user-data -O /tmp/payload.b64
echo Decrypting base64 payload
openssl enc -d -base64 -in /tmp/payload.b64 -out /tmp/payload.zip
mkdir -p /tmp/payload

echo Unzipping payload file
unzip -o /tmp/payload.zip -d /tmp/payload/

# if the autorun.sh script exists, run it
if [ -e /tmp/payload/autorun.sh ]; then
    echo Running autorun.sh
    cd /tmp/payload
    sh /tmp/payload/autorun.sh
else
    echo rc.local : No autorun script to run
fi

exit 0

EOF

chmod +x $FILE


echo "writing hostname..."
echo "cloudpipe" > /etc/hostname

echo "getting information for bundling..."
EKI=$(curl http://169.254.169.254/latest/meta-data/kernel-id)
OLD_AMI=$(euca-describe-images | grep $BUCKET | cut -f 2)

if [ ! -z "$OLD_AMI" ]; then
	euca-deregister $OLD_AMI
	euca-delete-bundle --clear -b $BUCKET
fi

echo "bundling..."
CREDS="-c ${EC2_CERT} -k ${EC2_PRIVATE_KEY} -u ${EC2_USER_ID} --ec2cert ${EUCALYPTUS_CERT}"
EXCLUDE="--exclude /bundle,/root/.ssh,/home/ubuntu/.ssh,$MOUNTPOINT,/tmp"
euca-bundle-vol $CREDS $EXCLUDE --no-inherit --kernel $EKI -d $MOUNTPOINT -r $ARCH -p $NEW_IMAGE_NAME -s $SIZE_IN_MB 

echo "uploading"
euca-upload-bundle -b $BUCKET -m $MOUNTPOINT/$NEW_IMAGE_NAME.manifest.xml

euca-register $BUCKET/$NEW_IMAGE_NAME.manifest.xml
