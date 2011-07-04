#!/usr/bin/env bash

function prompt {
        set +u
        read -e -i "$3" -p "$1 : " $2
        set -u
}


function usage {
	echo "usage: $0 <key pair> <ami> <instances per host>"
	exit 1
}

if [ $# -eq 3 ]; then
	KEY_PAIR="$1"
	AMI="$2"
	INSTANCES_PER_HOST="$3"
else
	prompt "Key pair" KEY_PAIR "admin-alberta"
	prompt "Machine image" AMI "ami-00000008"
	prompt "Instances per host" INSTANCES_PER_HOST 1
fi

if [ -z "$KEY_PAIR" -o -z "$AMI" -o -z "$INSTANCES_PER_HOST" ]; then
	usage
fi

ABS_PATH=`dirname "$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"`

if [ ! -f $ABS_PATH/payload ]; then
	read -p "User: " USER
        read -p "Password: " PASSWORD
        read -p "Region (ab|qc): " REGION

	cp $ABS_PATH/payload.template $ABS_PATH/payload

	sed -i "s/USER/$USER/g" $ABS_PATH/payload
	sed -i "s/PASSWORD/$PASSWORD/g" $ABS_PATH/payload
	sed -i "s/REGION/$REGION/g" $ABS_PATH/payload
fi

HOSTS=`nova-manage service list | grep compute | grep -v XXX | sort | cut -f1 -d' '`

for host in $HOSTS; do
	euca-run-instances -n $INSTANCES_PER_HOST -k $KEY_PAIR -z nova:$host $AMI -f payload
done

echo "Waiting 10 seconds for instances to run"
sleep 10

euca-describe-instances | grep "INSTANCE.*$AMI.*dair," | sort -k9

echo 'To terminate ALL instances execute [euca-describe-instances | grep "INSTANCE.*$AMI.*dair," | cut -f2 | xargs euca-terminate-instances]'
