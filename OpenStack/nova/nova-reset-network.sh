#!/bin/bash

if [ `whoami` != root ]; then
	echo "Please run this as the user, 'root'!";
	exit 1
fi

ABS_PATH=`dirname "$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"`

. $ABS_PATH/nova-CC-env

rm -f /var/log/nova/*
killall dnsmasq

mysql -uroot -p$MYSQL_PW -e "DROP DATABASE nova;"
mysql -uroot -p$MYSQL_PW -e "CREATE DATABASE nova;"
mysql -uroot -p$MYSQL_PW -e "GRANT ALL PRIVILEGES ON openssl.cnf TO 'root'@'%' WITH GRANT OPTION;"
mysql -uroot -p$MYSQL_PW -e "SET PASSWORD FOR 'root'@'%' = PASSWORD('$MYSQL_PW');"

nova-manage db sync

restart nova-api
sleep 5

nova-manage user admin $CLOUD_ADMIN
nova-manage project create $CLOUD_ADMIN_PROJECT $CLOUD_ADMIN
nova-manage network create $NETWORK_CIDR $NETWORK_NUMBER $IPS_PER_NETWORK

rm -rf creds-admin/
mkdir creds-admin
cd creds-admin

nova-manage project zipfile $CLOUD_ADMIN_PROJECT $CLOUD_ADMIN novacreds.zip
unzip novacreds.zip
. sandboxrc

restart nova-network
restart nova-api
restart nova-objectstore
restart nova-scheduler

euca-authorize -P icmp -t -1:-1 default
euca-authorize -P tcp -p 22 default
euca-add-keypair admin > admin.private
chmod 600 admin.private

