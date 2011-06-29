#!/bin/bash

if [ `whoami` != root ]; then
	echo "Please run this as the user, 'root'!";
	exit 1
fi

ABS_PATH=`dirname "$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"`

. $ABS_PATH/nova-CC-env

apt-get -y purge nova-common nova-doc python-nova nova-api nova-network nova-objectstore nova-scheduler nova-compute python-novaclient

mysql -uroot -p$MYSQL_PW -e 'DROP DATABASE nova;'

rm -rf /root/creds-admin
rm -rf /etc/nova
rm -rf /var/log/nova
rm -rf /var/lib/nova

vconfig rem vlan100
ifconfig br100 down
brctl delbr br100

killall dnsmasq

echo "Restart netowrking? /etc/init.d/networking restart"

echo "#######################################"
echo "DELETE ANY EXTRANEOUS VLANS AND BRIDGES"
echo "#######################################"

