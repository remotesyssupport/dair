#! /bin/bash

LOG="compute-create.log"
VENV="/usr/local/openstack-dashboard/trunk/openstack-dashboard/tools/with_venv.sh"
MANAGE="/usr/local/openstack-dashboard/trunk/openstack-dashboard/dashboard/manage.py"
PROJECT_LIST=$(nova-manage project list)

set -o nounset

function usage {
	echo "usage: $0 <project name> <admin first-name> <admin last-name> <admin email>"
}

function prompt {
	set +u
	read -e -i "$3" -p "$1 : " $2
	set -u
}

function log {
	echo $(date): $1 2>&1 |tee -a $LOG 
}

function project_exists {
	for P in $PROJECT_LIST; do
		if [ "$P" = "$PROJECT" ]; then
			echo "true"
			return
		fi
	done
}


if [ "$#" -lt 10 ]; then
	usage
	prompt "Project name" PROJECT
	prompt "Project description" PROJECT_DESCRIPTION
	prompt "Project administrator's first name" FIRSTNAME
	prompt "Project administrator's last name" LASTNAME
	prompt "Project administrator's email" EMAIL
	prompt "Gigabyte quota" QUOTA_GIGABYTES 100
	prompt "Floating IP quota" QUOTA_FLOATING_IPS 10
	prompt "Instance quota" QUOTA_INSTANCES 10
	prompt "Volume quota" QUOTA_VOLUMES 10
	prompt "Cores quota" QUOTA_CORES 20
else
	PROJECT="$1"
	PROJECT_DESCRIPTION="$2"
	FIRSTNAME="$3"
	LASTNAME="$4"
	EMAIL="$5"
	QUOTA_GIGABYTES="$6"
	QUOTA_FLOATING_IPS="$7"
	QUOTA_INSTANCES="$8"
	QUOTA_VOLUMES="$9"
	QUOTA_CORES="$10"
fi

# project administrators usernames follow DAIR convention
USERNAME="$PROJECT-admin"

log "project = '$PROJECT', first name = '$FIRSTNAME', last name = '$LASTNAME', username = '$USERNAME', email = '$EMAIL'"

# Create User
$VENV $MANAGE  createuser --username="$USERNAME" --email="$EMAIL" --firstname="$FIRSTNAME" --lastname="$LASTNAME" --noinput
if [ $? -ne 0 ]; then
	log "error while creating user $USERNAME"
	exit
fi

# Password reset
$VENV $MANAGE passwordreset --email="$EMAIL"

if [ "$(project_exists)" == "true" ]; then
	log "project $PROJECT already exists and has an administrator"
	exit
fi

# Create Project + assign user as project administrator
log "creating new project $PROJECT"
nova-manage project create "$PROJECT" "$USERNAME" "$PROJECT_DESCRIPTION"

# Assign roles
nova-manage role add $USERNAME netadmin
nova-manage role add $USERNAME netadmin $PROJECT
nova-manage role add $USERNAME sysadmin
nova-manage role add $USERNAME sysadmin $PROJECT

CREDENTIALS=$(nova-manage user exports $USERNAME)
SECRET_KEY=$(echo "$CREDENTIALS" | grep EC2_SECRET_KEY | cut -d"=" -f2)
ACCESS_KEY=$(echo "$CREDENTIALS" | grep EC2_ACCESS_KEY | cut -d"=" -f2)
ACCESS_KEY=$ACCESS_KEY:$PROJECT

euca-authorize -S $SECRET_KEY -A $ACCESS_KEY -P tcp -p 22 -s 0.0.0.0/0 default # ssh
euca-authorize -S $SECRET_KEY -A $ACCESS_KEY -P tcp -p 80 -s 0.0.0.0/0 default # http
euca-authorize -S $SECRET_KEY -A $ACCESS_KEY -P icmp -t -1:-1 default # ping

nova-manage project quota $PROJECT gigabytes $QUOTA_GIGABYTES
nova-manage project quota $PROJECT floating_ips $QUOTA_FLOATING_IPS
nova-manage project quota $PROJECT instances $QUOTA_INSTANCES
nova-manage project quota $PROJECT volumes $QUOTA_VOLUMES
nova-manage project quota $PROJECT cores $QUOTA_CORES
