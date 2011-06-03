#!/usr/bin/env bash

if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root"
	exit 1
fi

if [ -z $EC2_ACCESS_KEY ]; then
	echo "You need to set your cloud credentials"
	echo "Try sourcing your novarc file"
	exit 1
fi

if [ ! -n "$1" ]; then
	echo -n "Specify project to delete: "
	read PROJECT
else
	PROJECT=$1
fi

# Use project admin's credentials
USER="$PROJECT-admin"
EXPORTS=$(nova-manage user exports $USER)

if [ ! $(echo "$EXPORTS" | wc -l) -eq 2 ]; then
	echo "Bad project name or admin is not $USER"
	exit 1
fi

echo -n "About to delete project $PROJECT, continue? (y/N) "
read ANSWER

if [[ $ANSWER != 'y' && $ANSWER != 'Y' ]]; then
	echo "Aborting..."
	exit 0
fi

$EXPORTS
EC2_ACCESS_KEY=$EC2_ACCESS_KEY:$PROJECT

echo "Deleting images..."
IMAGES=$(euca-describe-images | grep "	private	" | cut -f2)

if [[ ! $IMAGES = '' ]]; then
	echo $IMAGES | xargs -n1 euca-deregister
fi

echo "Releasing addresses..."
ADDRESSES=$(euca-describe-addresses | cut -f2)

if [[ ! $ADDRESSES = '' ]]; then
	echo $ADDRESSES | xargs -n1 euca-disassociate-address
	sleep 2
	echo $ADDRESSES | xargs -n1 euca-release-address
fi

echo "Deleting volumes..."
VOLUMES=$(euca-describe-volumes | cut -f2)

if [[ ! $VOLUMES = '' ]]; then
	echo $VOLUMES | xargs -n1 euca-detach-volume
	sleep 2
	echo $VOLUMES | xargs -n1 euca-delete-volume
fi

echo "Terminating instances..."
INSTANCES=$(euca-describe-instances | grep "INSTANCE" | cut -f2)

if [[ ! $INSTANCES = '' ]]; then
	echo $INSTANCES | xargs -n1 euca-terminate-instances
fi

echo "Deleting keypairs..."
KEYPAIRS=$(euca-describe-keypairs | cut -f2)

if [[ ! $KEYPAIRS = '' ]]; then
	echo $KEYPAIRS | xargs -n1 euca-delete-keypair
fi

# Currently unsupported in OpenStack
#echo "Deleting snapshots..."
#SNAPSHOTS=$(euca-describe-snapshots | cut -f2)

#if [[ ! $SNAPSHOTS = '' ]]; then
#	echo $SNAPSHOTS | xargs -n1 euca-delete-snapshot
#fi

echo "Deleting project..."
nova-manage project delete $PROJECT
nova-manage project scrub $PROJECT

echo "Deleting project admin..."
nova-manage user delete $USER

echo "Project $PROJECT deleted.  Please note that user accounts must be deleted manually."
