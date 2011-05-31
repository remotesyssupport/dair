#!/usr/bin/env bash

if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root"
	exit 1
fi

if [ ! -n "$1" ]; then
    "Please specify a project to delete"
    exit 1
fi

if [ -z $EC2_ACCESS_KEY ]; then
	echo "You need to set your cloud credentials"
	echo "Try sourcing your novarc file"
	exit 1
fi

PROJECT=$1
#SAFE_PROJECT="	$PROJECT	"

# Use project admin's credentials
EXPORTS=$(nova-manage user exports $PROJECT-admin)

if [ ! $(echo "$EXPORTS" | wc -l) -eq 2 ]; then
	echo "Bad project name or project admin is not $PROJECT-admin"
	exit 1
fi

$EXPORTS

# Images
# NOTE(vish): leave public images because others may be using them
euca-describe-images | grep "	private	" | cut -f2 | xargs -n1 euca-deregister
sleep 2

# Addresses
#euca-describe-addresses | grep "$PROJECT" | cut -f2 | xargs -n1 euca-disassociate-address
euca-describe-addresses | cut -f2 | xargs -n1 euca-disassociate-address
sleep 2
#euca-describe-addresses | grep "$PROJECT" | cut -f2 | xargs -n1 euca-release-address
euca-describe-addresses | cut -f2 | xargs -n1 euca-release-address

# Volumes
#euca-describe-volumes | grep "$SAFE_PROJECT" | cut -f2 | xargs -n1 euca-detach-volume
euca-describe-volumes | cut -f2 | xargs -n1 euca-detach-volume
sleep 2
#euca-describe-volumes | grep "$SAFE_PROJECT" | cut -f2 | xargs -n1 euca-delete-volume
euca-describe-volumes | cut -f2 | xargs -n1 euca-delete-volume

# Instances
#euca-describe-instances | grep "$SAFE_PROJECT" | cut -f2 | xargs euca-terminate-instances
euca-describe-instances | cut -f2 | xargs euca-terminate-instances
sleep 2

# Project
nova-manage project delete $PROJECT

# Security groups and network
nova-manage project scrub $PROJECT
