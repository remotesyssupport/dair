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
	read -p "$1 : " $2
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


if [ "$#" -lt 4 ]; then
	usage
	prompt "Project name: " PROJECT
	prompt "Project administrator's first name: " FIRSTNAME
	prompt "Project administrator's last name: " LASTNAME
	prompt "Project administrator's email: " EMAIL
else
	PROJECT="$1"
	FIRSTNAME="$2"
	LASTNAME="$3"
	EMAIL="$4"
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

if [ "$(project_exists)" != "true" ]; then
	# Create Project + assign user as project administrator
	log "creating new project"
	nova-manage project create $PROJECT $USERNAME  # [description]
else
	log "project $PROJECT already exists and has an administrator"
	exit
fi

# Assign role netadmin
nova-manage role add $USERNAME netadmin $PROJECT

euca-authorize -P tcp -p 22 -s 0.0.0.0/0 default # ssh
euca-authorize -P tcp -p 80 -s 0.0.0.0/0 default # http
euca-authorize -P icmp -t -1:-1 default # ping

nova-manage project quota $PROJECT gigabytes 1000
nova-manage project quota $PROJECT floating_ips 10
nova-manage project quota $PROJECT instances 10
nova-manage project quota $PROJECT volumes 10
nova-manage project quota $PROJECT cores 20
