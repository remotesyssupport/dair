#!/bin/bash

STORAGE_LOCAL_IP=$(/sbin/ifconfig $INTERFACE_PRIV | egrep '.*inet ' | head -n 1 | perl -pe 's/.*addr:(.+).*Bcast.*/$1/g' | tr -d " " )
ABS_PATH=`dirname "$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"`
source $ABS_PATH/swift.env

ACCOUNT_SERVER_COMMON_CONFIG=" 
user = swift 

[pipeline:main]
pipeline = account-server

[app:account-server]
use = egg:swift#account

[account-replicator]

[account-updater]

[account-auditor]"


CONTAINER_SERVER_COMMON_CONFIG=" 
user = swift

[pipeline:main]
pipeline = container-server

[app:container-server]
use = egg:swift#container

[container-replicator]

[container-updater]

[container-auditor]
"

OBJECT_SERVER_COMMON_CONFIG="
user = swift 

[pipeline:main]
pipeline = object-server

[app:object-server]
use = egg:swift#object

[object-replicator]

[object-updater]

[object-auditor]
"

COMMON_CONFIG=(\
"$OBJECT_SERVER_COMMON_CONFIG" \
"$CONTAINER_SERVER_COMMON_CONFIG" \
"$ACCOUNT_SERVER_COMMON_CONFIG")

# exit if any unset variables
set -o nounset


if [ `whoami` != root ]; then
        echo "Please run this as the user, 'root'!";
        exit 1
fi


# Install common Swift software prerequsites:
apt-get install -y python-software-properties
add-apt-repository ppa:swift-core/ppa
apt-get update
apt-get install -y swift openssh-server

# Create and populate configuration directories:
mkdir -p /etc/swift
chown -R swift:swift /etc/swift/

# Create swift configuration file:
cat > /etc/swift/swift.conf << EOF
[swift-hash]
# random unique string that can never change (DO NOT LOSE)
swift_hash_path_suffix = dair-cloud
EOF

# Install Storage node packages:
apt-get install -y swift-account swift-container swift-object xfsprogs

# -------- Configure the Storage nodes --------------
# the mount points used here must agree with the paths in the
# rsyncd.conf file
echo "mounting attached storage on $MOUNTPOINT"
mkdir -p $MOUNTPOINT

# for the DAIR project, we expect the drives have already
# been mounted and formatted with xfs
#
#for DEV in $(ls /dev/* | grep -E "$DEVICE[0-9]"); do 
#	DEV=$(basename "$DEV")
#	mkfs.xfs -f -i size=1024 /dev/$DEV
#	echo "/dev/$DEV $MOUNTPOINT/$DEV xfs noatime,nodiratime,nobarrier,logbufs=8 0 0" >> /etc/fstab
#	mkdir -p $MOUNTPOINT/$DEV
#	mount /dev/$DEV $MOUNTPOINT/$DEV
#done
chown -R swift $MOUNTPOINT


SERVERTYPES=("object-server container-server account-server")
let PORT=6000
SERVER_NUMBER=0
for SERVER in ${SERVERTYPES}; do
	CONFIG_FILE="/etc/swift/$SERVER.conf"
	echo "writing $CONFIG_FILE"
	echo "[DEFAULT] " > $CONFIG_FILE
	# the following entries are not needed if you use the defaults
	#echo "devices = $MOUNTPOINT" >> $CONFIG_FILE
	#echo "bind_port = 600$SERVER_NUMBER" >> $CONFIG_FILE
	echo "bind_ip = 0.0.0.0" >> $CONFIG_FILE
	echo "workers = 2" >> $CONFIG_FILE
	echo "${COMMON_CONFIG[$SERVER_NUMBER]}" >> $CONFIG_FILE
	let SERVER_NUMBER+=1
done


# ------------- configuration files ------------------------------
# TODO: check rsync for configuration of multiple devices
file="/etc/rsyncd.conf"
echo "writing $file..."
cat > $file << EOF
uid = swift
gid = swift
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
address = $STORAGE_LOCAL_IP

[account]
max connections = 2
path = $MOUNTPOINT/
read only = false
lock file = /var/lock/account.lock

[container]
max connections = 2
path = $MOUNTPOINT/ 
read only = false
lock file = /var/lock/container.lock

[object]
max connections = 2
path = $MOUNTPOINT/
read only = false
lock file = /var/lock/object.lock
EOF

sed -i s/RSYNC_ENABLE=false/RSYNC_ENABLE=true/g /etc/default/rsync
service rsync start


# Make sure all the config files are owned by the swift user:
chown -R swift:swift /etc/swift

# Start the storage services:
# ---------------------------------------------------------
file="/etc/swift/start-all"
echo "writing $file..."
cat > $file << EOF
swift-init object-server start
swift-init object-replicator start
swift-init object-updater start
swift-init object-auditor start
swift-init container-server start
swift-init container-replicator start
swift-init container-updater start
swift-init container-auditor start
swift-init account-server start
swift-init account-replicator start
swift-init account-auditor start
EOF
chmod +x $file
/etc/swift/start-all

file="/etc/swift/stop-all"
echo "writing $file..."
cat > $file << EOF
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
EOF
chmod +x $file
