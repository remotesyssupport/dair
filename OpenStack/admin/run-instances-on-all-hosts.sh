#!/usr/bin/env bash

if [ ! -n "$1" ]; then
    "Please specify an AMI to run on all hosts"
    exit 1
fi

#TODO: check for XXX and exit out if found

HOSTS=`nova-manage service list | grep compute | sort | cut -f1 -d' '`
AMI=$1

for host in $HOSTS; do
    euca-run-instances -k admin-alberta -z nova:$host $AMI
done

echo "Waiting 10 seconds for instances to run"
sleep 10

euca-describe-instances | grep "INSTANCE.*$AMI.*dair," | sort -k9

echo 'To terminate ALL instances execute [euca-describe-instances | grep "INSTANCE.*${AMI}.*dair," | cut -f2 | xargs euca-terminate-instances]'
