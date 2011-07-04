#! /bin/bash

for address in `euca-describe-addresses | grep None | grep dair | cut -f2`; do 
	euca-release-address $address
done
