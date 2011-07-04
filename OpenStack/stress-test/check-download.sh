#! /bin/bash

for address in `euca-describe-instances | grep INSTANCE | cut -f 4`; do 
	echo $address 
	ssh -i /root/creds-admin/admin-alberta.private ubuntu@$address 'ls -l /*OpenStack*'
done
