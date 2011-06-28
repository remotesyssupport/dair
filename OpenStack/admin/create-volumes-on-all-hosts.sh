#!/usr/bin/env bash

#TODO: check for XXX and exit out if found

if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root"
	exit
fi

HOSTS=`nova-manage service list | grep volume | sort | cut -f1 -d' '`
AMI=$1

for host in $HOSTS; do
    euca-create-volume -s 1 -z nova:$host
done

echo "Waiting 10 seconds for volumes to be created"
sleep 10

euca-describe-volumes | sort -k7

echo 'To terminate ALL instances execute [euca-describe-volumes | grep "dair," | cut -f2 | xargs -n1 euca-delete-volume]'

