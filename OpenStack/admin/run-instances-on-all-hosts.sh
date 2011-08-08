#!/usr/bin/env bash

function usage {
	echo "usage: $0 <key pair> <ami>"
	exit 1
}

if [ ! -n "$1" ]; then
    echo "Please specify a key pair"
    usage
fi

if [ ! -n "$2" ]; then
    echo "Please specify an AMI to run on all hosts"
    usage
fi

# Ignore XXX and disabled hosts
HOSTS=`nova-manage service list | grep compute | grep -v XXX | grep -v disabled | sort | cut -f1 -d' '`
KEY_PAIR=$1
AMI=$2

for host in $HOSTS; do
    euca-run-instances -k $KEY_PAIR -z nova:$host $AMI
done

echo "Waiting 10 seconds for instances to run"
sleep 10

euca-describe-instances | grep "INSTANCE.*$AMI.*dair," | sort -k9

echo 'To terminate ALL instances execute [euca-describe-instances | grep "INSTANCE.*${AMI}.*dair," | cut -f2 | xargs euca-terminate-instances]'
