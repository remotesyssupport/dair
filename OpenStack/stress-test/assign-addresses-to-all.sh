#! /bin/bash

INSTANCES=$(euca-describe-instances | grep INSTANCE | grep -v 208.75  | cut -f 2)

for INSTANCE in $INSTANCES; do
	echo $INSTANCE
	ADDRESS=$(euca-allocate-address | cut -f 2)
	euca-associate-address $ADDRESS -i $INSTANCE
done
