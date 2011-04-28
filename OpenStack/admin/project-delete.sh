#!/usr/bin/env bash

if [ ! -n "$1" ]; then
    "Please specify a project to delete"
    exit 1
fi

if [ -z $EC2_ACCESS_KEY ]; then
	echo "you need to set your cloud credentials."
	echo "try sourcing your novarc file"
	exit 1
fi
PROJECT=$1
SAFE_PROJECT="	$PROJECT	"

# Images
# NOTE(vish): leave public images because others may be using them
euca-describe-images | grep "	private	" | -cut -f2 | xargs -n1 euca-deregister

# TODO: need to delete the buckets of the images

# Addresses
euca-describe-addresses | grep "$PROJECT" | cut -f2 | xargs -n1 euca-disassociate-address
sleep 2
euca-describe-addresses | grep "$PROJECT" | cut -f2 | xargs -n1 euca-release-address

# Volumes
euca-describe-volumes | grep "$SAFE_PROJECT" | cut -f2 | xargs -n1 euca-detach-volume
sleep 2
euca-describe-volumes | grep "$SAFE_PROJECT" | cut -f2 | xargs -n1 euca-delete-volume
sleep 2

# Instances
euca-describe-instances | grep "$SAFE_PROJECT" | cut -f2 | xargs euca-terminate-instances
sleep 2

# Project
nova-manage project delete $PROJECT

# Security groups and network
nova-manage project scrub $PROJECT
