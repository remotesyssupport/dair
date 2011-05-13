#! /bin/bash

LOG="compute-create.log"
VENV="/usr/local/openstack-dashboard/trunk/openstack-dashboard/tools/with_venv.sh"
MANAGE="/usr/local/openstack-dashboard/trunk/openstack-dashboard/dashboard/manage.py"
PROJECT_LIST=$(nova-manage project list)

set -o nounset

function usage {
	echo "usage: $0 <project> <first-name> <last-name> <username> <email>"
}

function prompt {
	set +u
	read -e -i "$3" -p "$1 : " $2
	set -u
}

function log {
	echo $(date): $1 | tee -a $LOG 
}

function project_exists {
	for P in $PROJECT_LIST; do
		if [ "$P" = "$PROJECT" ]; then
			echo "true"
			return
		fi
	done
}


if [ "$#" -lt 5 ]; then
	usage
	prompt "project name" PROJECT
	prompt "User's first name" FIRSTNAME
	prompt "User's last name" LASTNAME
	prompt "User's username" USERNAME $(echo $FIRSTNAME.$LASTNAME  | tr '[A-Z]' '[a-z]')
	prompt "User's email" EMAIL
else
	PROJECT="$1"
	FIRSTNAME="$2"
	LASTNAME="$3"
	USERNAME="$4" 
	EMAIL="$5"
fi

log "project = '$PROJECT', first name = '$FIRSTNAME', last name = '$LASTNAME', username = '$USERNAME', email = '$EMAIL'"

# Create User
$VENV $MANAGE  createuser --username="$USERNAME" --email="$EMAIL" --firstname="$FIRSTNAME" --lastname="$LASTNAME" --noinput
if [ $? -ne 0 ]; then
	log "error while creating user $USERNAME"
	exit
fi

# Password reset
$VENV $MANAGE passwordreset --email="$EMAIL"

log "adding $USERNAME to $PROJECT"
nova-manage project add $PROJECT $USERNAME

# Assign role netadmin
nova-manage role add $USERNAME netadmin $PROJECT

