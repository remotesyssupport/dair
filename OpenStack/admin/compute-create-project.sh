#! /bin/bash

LOG="compute-create.log"
ERR="compute-create-error.log"
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

# we'll clear the error log, but hang on to the regular log"
cat /dev/null > $ERR
log "=============================================="


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

MYSQL_USER=$(grep sql_connection /etc/nova/nova.conf | cut -d '/' -f3 | cut -d ':' -f1)
MYSQL_PW=$(grep sql_connection /etc/nova/nova.conf | cut -d ':' -f3 | cut -d '@' -f1)
RESULT=$(mysql -u$MYSQL_USER -p$MYSQL_PW dashboard -e "select * from auth_user where email='$EMAIL'")

if [[ "$RESULT" != '' ]]; then
	log "A user with email $EMAIL already exists"
	exit
fi

# Create User
log "Creating user '$USERNAME'..."
$VENV $MANAGE  createuser --username="$USERNAME" --email="$EMAIL" \
	--firstname="$FIRSTNAME" --lastname="$LASTNAME" --noinput 1>>$LOG 2>>$ERR 
if [ $? -ne 0 ]; then
	log "error while creating user $USERNAME"
	exit
fi

# Password reset
log "Resetting password..."
log "Sending notification to '$EMAIL'..."
$VENV $MANAGE passwordreset --admin --email="$EMAIL" 1>>$LOG 2>>$ERR 

if [ "$(project_exists)" == "true" ]; then
	log "project $PROJECT already exists and has an administrator"
	exit
fi

# Create Project + assign user as project administrator
log "Creating new project '$PROJECT'..."
nova-manage project create "$PROJECT" "$USERNAME" "$PROJECT_DESCRIPTION" 1>>$LOG 2>>$ERR 

# Assign roles
log "Assigning netadmin role..."
nova-manage role add $USERNAME netadmin 1>>$LOG 2>>$ERR 
nova-manage role add $USERNAME netadmin $PROJECT 1>>$LOG 2>>$ERR 

log "Assigning sysadmin role..."
nova-manage role add $USERNAME sysadmin 1>>$LOG 2>>$ERR 
nova-manage role add $USERNAME sysadmin $PROJECT 1>>$LOG 2>>$ERR 

CREDENTIALS=$(nova-manage user exports $USERNAME)
SECRET_KEY=$(echo "$CREDENTIALS" | grep EC2_SECRET_KEY | cut -d"=" -f2)
ACCESS_KEY=$(echo "$CREDENTIALS" | grep EC2_ACCESS_KEY | cut -d"=" -f2)
ACCESS_KEY=$ACCESS_KEY:$PROJECT

log "Creating security group..."
euca-authorize -S $SECRET_KEY -A $ACCESS_KEY -P tcp -p 22 -s 0.0.0.0/0 default 1>>$LOG 2>>$ERR 
euca-authorize -S $SECRET_KEY -A $ACCESS_KEY -P tcp -p 80 -s 0.0.0.0/0 default 1>>$LOG 2>>$ERR 
euca-authorize -S $SECRET_KEY -A $ACCESS_KEY -P icmp -t -1:-1 default 1>>$LOG 2>>$ERR 

log "Setting project quotas..."
nova-manage project quota $PROJECT gigabytes $QUOTA_GIGABYTES 1>>$LOG 2>>$ERR 
nova-manage project quota $PROJECT floating_ips $QUOTA_FLOATING_IPS 1>>$LOG 2>>$ERR 
nova-manage project quota $PROJECT instances $QUOTA_INSTANCES 1>>$LOG 2>>$ERR 
nova-manage project quota $PROJECT volumes $QUOTA_VOLUMES 1>>$LOG 2>>$ERR 
nova-manage project quota $PROJECT cores $QUOTA_CORES 1>>$LOG 2>>$ERR 

log "Done.  Congratulations!"
log "Please review '$LOG' and '$ERR' for more details"
log "=============================================="
log ""
