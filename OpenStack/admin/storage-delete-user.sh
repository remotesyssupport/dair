#! /bin/bash

LOG_DIR="/var/log/dair"
LOG="$LOG_DIR/storage-delete-user.log"
ERR="$LOG_DIR/storage-delete-user-error.log"
FQDN_AB="swift-ab.dair-atir.canarie.ca"
FQDN_QC="swift-qc.dair-atir.canarie.ca"
PROXY_LIST=($FQDN_AB $FQDN_QC)

set -o nounset

function usage {
	echo "Usage: $0 <account>"
}

function prompt {
	read -p "$1 : " $2
}

function log {
	echo $(date): $1 | tee -a $LOG
}

if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root"
	exit
fi

mkdir -p $LOG_DIR > /dev/null 2>&1
cat /dev/null > $ERR
log "============================================="

if [ "$#" -ne 1 ]; then
	usage
	prompt "Delete account" ACCOUNT
else
	ACCOUNT="$1"
fi

ACCOUNT="$(echo $ACCOUNT | sed 's/ //g')"

log "Account = '$ACCOUNT'"

ADMIN_KEY=$(grep super_admin_key /etc/swift/proxy-server.conf | cut -d " " -f3)

for PROXY in ${PROXY_LIST[@]}; do
	ADMIN_URL="https://$PROXY:8080/auth/"
	REGION=$(echo $PROXY | cut -d "." -f1)

	USERS=$(swauth-list -p -A $ADMIN_URL -K $ADMIN_KEY $ACCOUNT 2>/dev/null)
	
	if [[ $USERS == "List failed: 404 Not Found" ]]; then
		log "Account $ACCOUNT does not exist in region $REGION"
		continue
	fi

	log "Deleting users in region '$REGION'..."

	for USER in $USERS; do
		log "Deleting user $USER"
		swauth-delete-user -A $ADMIN_URL -K $ADMIN_KEY $ACCOUNT $USER 1>>$LOG 2>>$ERR
	done

	log "Deleting account '$ACCOUNT' in region '$REGION'"

	swauth-delete-account -A $ADMIN_URL -K $ADMIN_KEY $ACCOUNT 1>>$LOG 2>>$ERR
done

log "Done."
log "Please review '$LOG' and '$ERR' for more details"
log "=============================================="
log ""
