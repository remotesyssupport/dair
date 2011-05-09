#!/bin/bash

PROXY_LOCAL_IP=$(/sbin/ifconfig $INTERFACE_PRIV | egrep '.*inet ' | head -n 1 | perl -pe 's/.*addr:(.+).*Bcast.*/$1/g' | tr -d " " )
ABS_PATH=`dirname "$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"`
source $ABS_PATH/swift.env

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


# ------- Configure the Proxy node ----------

# Install swift-proxy service:
apt-get install -y swift-proxy memcached

# Create self-signed cert for SSL:
cd /etc/swift
openssl req -new -x509 -nodes -out cert.crt -keyout cert.key << EOF
CA
AB
Edmonton
Cybera
.
CESWP
ceswp.project@gmail.com
EOF

# Modify memcached to listen on the default interfaces.
# Preferably this should be on a local, non-public network.
sed -i s/127.0.0.1/$PROXY_LOCAL_IP/g /etc/memcached.conf
service memcached restart

# Create /etc/swift/proxy-server.conf:
cat > /etc/swift/proxy-server.conf << EOF
[DEFAULT]
cert_file = /etc/swift/cert.crt
key_file = /etc/swift/cert.key
bind_port = 8080
workers = 8
user = swift

[pipeline:main]
# For DevAuth:
# pipeline = healthcheck cache auth proxy-server
# For Swauth:
pipeline = healthcheck cache swauth proxy-server

[app:proxy-server]
use = egg:swift#proxy
allow_account_management = true

# Only needed for DevAuth
[filter:auth]
use = egg:swift#auth
ssl = true

# Only needed for Swauth
[filter:swauth]
use = egg:swift#swauth
ssl = true
default_swift_cluster = local#https://$PROXY_LOCAL_IP:8080/v1
# Highly recommended to change this key to something else!
super_admin_key = dummypw

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:cache]
use = egg:swift#memcache
memcache_servers = $PROXY_LOCAL_IP:11211
# Note
# If you run multiple memcache servers,
# put the multiple IP:port listings in the [filter:cache] section
# of the proxy-server.conf file like:
# 10.1.2.3:11211, 10.1.2.4:11211
# Only the proxy server uses memcache.
EOF

# Create the account, container and object rings:
cd /etc/swift
rm -f *.builder *.ring.gz
rm -rf backups/

# you can have more zones than replicas, but it doesn't 
# make much sense to have more replicas than zones
if [ "$REPLICAS" -gt "$ZONES" ]; then
	echo "setting replicas = $ZONES"
	REPLICAS=$ZONES
fi

swift-ring-builder account.builder create $PARTITION_EXPONENT $REPLICAS $PARTITION_MOVE_TIME
swift-ring-builder container.builder create $PARTITION_EXPONENT $REPLICAS $PARTITION_MOVE_TIME
swift-ring-builder object.builder create $PARTITION_EXPONENT $REPLICAS $PARTITION_MOVE_TIME

# For every storage device on each node add entries to each ring:
# ZONE should start at 1 and increment by one for each additional node.
#
size=${#STORAGE_NODES[@]}
servers_per_zone=$(($size/$ZONES))
echo "there are $size storage nodes to distribute across $ZONES zones, so let's have $servers_per_zone per zone"
for x in $(seq 1 $size); do
	let ZONE=$((($x+1)/$servers_per_zone))
	let i=$x-1
	NODE=${STORAGE_NODES[$i]}
	echo "server $x ($NODE) ---> zone $ZONE"
	let PORT=6000
	for DEVICE in ${DEVICES[@]}; do
		echo "node $NODE, device $DEVICE"
		echo "----------------------------------"
		echo swift-ring-builder object.builder add z$ZONE-$NODE:$PORT/$DEVICE 100
		swift-ring-builder object.builder add z$ZONE-$NODE:$PORT/$DEVICE 100
		let PORT=PORT+1
		echo swift-ring-builder container.builder add z$ZONE-$NODE:$PORT/$DEVICE 100
		swift-ring-builder container.builder add z$ZONE-$NODE:$PORT/$DEVICE 100
		let PORT=PORT+1
		echo swift-ring-builder account.builder add z$ZONE-$NODE:$PORT/$DEVICE 100
		swift-ring-builder account.builder add z$ZONE-$NODE:$PORT/$DEVICE 100
		let PORT=PORT-2
		echo
	done
done

echo "Verify the ring contents for each ring..."
swift-ring-builder account.builder
swift-ring-builder container.builder
swift-ring-builder object.builder

echo "Rebalance the rings.  This can take some time..."
swift-ring-builder account.builder rebalance
swift-ring-builder container.builder rebalance
swift-ring-builder object.builder rebalance

# Make sure all the config files are owned by the swift user:
chown -R swift:swift /etc/swift

# Start the storage services:
# ---------------------------------------------------------
file="/etc/swift/start-all"
echo "writing $file..."
cat > $file << EOF
swift-init proxy start
EOF
chmod +x $file
/etc/swift/start-all

file="/etc/swift/stop-all"
echo "writing $file..."
cat > $file << EOF
swift-init proxy stop
EOF
chmod +x $file

# Start Proxy services:
swift-init proxy start

# Copy the account.ring.gz, container.ring.gz, and object.ring.gz
# files to each of the Proxy and Storage nodes in /etc/swift.
# TODO: no root password, no swift password.  How to copy files easily?
for NODE in ${STORAGE_NODES[@]}; do
	echo "scp -i /home/ubuntu/creds-admin/admin-alberta.private /etc/swift/*.gz ubuntu@$NODE:~/"
done
echo "copy and past these commands in each storage node"
echo "-------------------------------------------------"
echo "sudo rm /etc/swift/*.gz"
echo "sudo cp /home/ubuntu/*.gz /etc/swift/"
echo "sudo chown swift:swift /etc/swift/*.gz"
echo "-------------------------------------------------"

