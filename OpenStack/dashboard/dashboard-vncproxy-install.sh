#! /bin/bash

# this script cribbed from installation guide at 
# http://wiki.openstack.org/OpenStackDashboard

ABS_PATH=`dirname "$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"`
source $ABS_PATH/dashboard.env

# some sanity checks
if [ `whoami` != root ]; then
        echo "Please run this as the user, 'root'!";
        exit 1
fi

# you are now entering a zero-tolerance zone
# exit if any variable is not set
set -o nounset 


# add the VNC console
cd "$DASHBOARD/trunk/"
bzr merge lp:~sleepsonthefloor/openstack-dashboard/vnc_console

cd /var/lib/nova
git clone https://github.com/openstack/noVNC
cat $ABS_PATH/vnc.patch | patch -p0

# we use dsh to add the VNC proxy to the configuration of each compute node...
DSH=$(which dsh)
if [ -z "$DSH" ]; then
	echo "dsh is not installed"
	echo "I'm gonna try to install it and create a group listing"
	echo "for the compute nodess..."
	apt-get -y install dsh
	mkdir -p /etc/dsh/group
	COMPUTE_GROUP=$(grep -E "dair.*c[0-9][0-9]$" /etc/hosts | awk '{print "root@"$3}')
	cat /dev/null > /etc/dsh/group/compute
	for HOST in $COMPUTE_GROUP; do
		echo $HOST >> /etc/dsh/group/compute
	done
fi

dsh -g compute "--vncproxy_url=http://$DASHBOARD_SERVER_IP:6080 >> /etc/nova/nova.log"

# start 'er up!
nova-vncproxy --flagfile=/etc/nova/nova.conf

