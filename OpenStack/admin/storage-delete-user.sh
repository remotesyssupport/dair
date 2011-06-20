#! /bin/bash

LOG="swift-delete.log"
ERR="swift-delete-error.log"
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

if [ "$#" -ne 1]; then
	prompt "Delete account" ACCOUNT
else
	ACCOUNT="$1"
fi

ACCOUNT="$(echo $ACCOUNT | sed 's/ //g')"

log "Account = '$ACCOUNT'"

ADMIN_KEY=$(grep super_admin_key /etc/swift/proxy-server.conf | cut -d " " -f3)

for PROXY in ${PROXY_LIST[@]}; do
	ADMIN_URL="https://$PROXY:8080/auth/"

	USERS=$(swauth-list -p -A $ADMIN_URL -K $ADMIN_KEY $ACCOUNT)

	log "Deleting users..."

	for USER in $USERS; do
		log "Deleting user $USER"
		swauth-delete-user -A $ADMIN_URL -L $ADMIN_KEY $ACCOUNT $USER 1>>$LOG 2>>$ERR
	done

	log "Deleting account '$ACCOUNT'"

	swauth-delete-account -A $ADMIN_URL -K $ADMIN_KEY $ACCOUNT 1>>$LOG 2>>$ERR
done

log "Done."
log "Please review '$LOG' and '$ERR' for more details"
log "=============================================="
log ""
