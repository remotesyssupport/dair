#!/usr/bin/env bash

# Deletes given project and releases all associated resources
# Currently deletes all associated users regardless of whether they are part of another project
# Must be run from the management node

NOVA_CONF='/etc/nova/nova.conf'

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

if [[ $IMAGES != '' ]]; then
	echo $IMAGES | xargs -n1 euca-deregister
fi

echo "Releasing addresses..."
ADDRESSES=$(euca-describe-addresses | cut -f2)

if [[ $ADDRESSES != '' ]]; then
	echo $ADDRESSES | xargs -n1 euca-disassociate-address
	sleep 2
	echo $ADDRESSES | xargs -n1 euca-release-address
fi

echo "Deleting volumes..."
VOLUMES=$(euca-describe-volumes | cut -f2)

if [[ $VOLUMES != '' ]]; then
	echo $VOLUMES | xargs -n1 euca-detach-volume
	sleep 2
	echo $VOLUMES | xargs -n1 euca-delete-volume
fi

echo "Terminating instances..."
INSTANCES=$(euca-describe-instances | grep "INSTANCE" | cut -f2)

if [[ $INSTANCES != '' ]]; then
	echo $INSTANCES | xargs -n1 euca-terminate-instances
fi

echo "Deleting keypairs..."
KEYPAIRS=$(euca-describe-keypairs | cut -f2)

if [[ $KEYPAIRS != '' ]]; then
	echo $KEYPAIRS | xargs -n1 euca-delete-keypair
fi

# Currently unsupported in OpenStack
#echo "Deleting snapshots..."
#SNAPSHOTS=$(euca-describe-snapshots | cut -f2)

#if [[ ! $SNAPSHOTS = '' ]]; then
#	echo $SNAPSHOTS | xargs -n1 euca-delete-snapshot
#fi

echo "Deleting users..."
LDAP_ADDR=$(sed -n 's/--ldap_url=ldap:\/\/\(.\+\)/\1/p' $NOVA_CONF)
LDAP_USER=$(sed -n 's/--ldap_user_dn=\(.\+\)/\1/p' $NOVA_CONF)
LDAP_PW=$(sed -n 's/--ldap_password=\(.\+\)/\1/p' $NOVA_CONF)
LDAP_SEARCHBASE="ou=Groups,$(echo $LDAP_USER | grep -o 'dc=.\+')"
USERS=$(ldapsearch -b "cn=$PROJECT,$LDAP_SEARCHBASE" -D $LDAP_USER -h $LDAP_ADDR -xw $LDAP_PW | sed -n 's/member: uid=\([^,]\+\).\+/\1/p' | grep -xv $USER | sort | uniq)

if [[ $USERS != '' ]]; then
	echo $USERS | xargs -n1 nova-manage user delete
fi

echo "Deleting project..."
nova-manage project delete $PROJECT
nova-manage project scrub $PROJECT

echo "Deleting project admin..."
nova-manage user delete $USER

echo "Project $PROJECT deleted."