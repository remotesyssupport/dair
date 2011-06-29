#! /bin/bash

#~ create swift user in both regions using FQDN
#~ generate swift rc files

LOG="swift-create.log"
ERR="swift-create-error.log"
FQDN_AB="swift-ab.dair-atir.canarie.ca"
FQDN_QC="swift-qc.dair-atir.canarie.ca"
PROXY_LIST=($FQDN_AB $FQDN_QC)
ATTACHMENT_LIST=""

set -o nounset

function usage {
	echo "usage: $0 ..."
}

function prompt {
	read -p "$1 : " $2
}

function log {
	echo $(date): $1 | tee -a $LOG 
}

# we'll clear the error log, but hang on to the regular log"
cat /dev/null > $ERR
log "=============================================="


if [ "$#" -lt 3 ]; then
	usage
	prompt "Account" ACCOUNT
	prompt "Username" USERNAME
	prompt "Email" EMAIL
else
	ACCOUNT="$1"
	USERNAME="$2" 
	EMAIL="$3"
fi

# strip the spaces
ACCOUNT="$(echo $ACCOUNT |sed 's/ //g')"
USERNAME="$(echo $USERNAME |sed 's/ //g')"

log "Account = '$ACCOUNT', Username = '$USERNAME', Email = '$EMAIL'"

PWGEN=$(which pwgen)
if [ -z "$PWGEN" ]; then
	echo "pwgen is not installed"
	apt-get -y install pwgen
fi
PASSWORD=$(pwgen --ambiguous --capitalize 10 1) 1>>$LOG 2>>$ERR 

# Create User
ADMIN_KEY=$(grep super_admin_key /etc/swift/proxy-server.conf | cut -d " " -f 3)

for PROXY in ${PROXY_LIST[@]}; do
	AUTH_URL="https://$PROXY:8080/auth/v1.0"
	REGION=$(echo $PROXY|cut -d"." -f1)
	
	log "Creating account '$ACCOUNT' for user '$USERNAME' in region '$REGION'..."

	swauth-add-user -A https://$PROXY:8080/auth/ -K $ADMIN_KEY -a $ACCOUNT $USERNAME $PASSWORD 1>>$LOG 2>>$ERR 
	
	log "Testing the account for region '$REGION'..."

	# a quick test to make sure the account is good
	# Get an X-Storage-Url and X-Auth-Token:
	result=$(curl -k -v -H "X-Storage-User: $ACCOUNT:$USERNAME" -H "X-Storage-Pass: $PASSWORD" $AUTH_URL 1>/dev/null 2> curl.out)
	if [[ $result == *40[0-9]* ]]; then
		echo "40* found while curling X-Storage-Url"
		exit
	fi
	
	AUTH_TOKEN=$(grep X-Auth-Token curl.out | cut -d " " -f3 | tr -d '\r\n')
	STORAGE_URL=$(grep X-Storage-Url curl.out | cut -d " " -f3 | tr -d '\r\n')

	# Check that you can HEAD the account:
	result=$(curl -k -H "X-Auth-Token: $AUTH_TOKEN" $STORAGE_URL 1>/dev/null 2>/dev/null)
	if [ $? -ne 0 ]; then
		echo "could not curl account heading"
		exit
	fi

	if [[ $result == *40[0-9]* ]]; then
		echo "40* found while curling account heading"
		exit
	fi

	# Check that st works:
	result=$(st -A $AUTH_URL -U $ACCOUNT:$USERNAME -K $PASSWORD stat)
	if [ $? -ne 0 ]; then
		echo "'st stat' test failed"
		exit
	fi

	log "Generating resource file for region '$REGION'..."
	RC_FILE="$USERNAME-$REGION.rc"
	ATTACHMENT_LIST="$ATTACHMENT_LIST $RC_FILE"
	
	cat > $RC_FILE << EOF
# st recognizes ST_AUTH, ST_USER, and ST_KEY environment variables 
unset \$(/usr/bin/env | egrep '^(\w+)=(.*)\$' | egrep 'ST' | /usr/bin/cut -d= -f1);

export ST_USER='$ACCOUNT:$USERNAME'
export ST_KEY='$PASSWORD' 
export ST_AUTH='$AUTH_URL'
EOF

done

log "sending email with attachments to $EMAIL..."
TO="$EMAIL"
CC=""
SUBJECT="Your DAIR/ATIR Storage Account"
BODY="Welcome to DAIR/ATIR Cloud Storage

Account: $ACCOUNT
Username: $USERNAME

Your dair/atir storage credential files are attached to this email.  

If you have any questions, please contact us at dair-support@canarie.ca

Thank you
"
echo "$BODY" | mutt -s "$SUBJECT" -a $ATTACHMENT_LIST -- "$TO"

# clean up
rm -f curl.out
rm -f *.rc

log "Done.  Congratulations!"
log "Please review '$LOG' and '$ERR' for more details"
log "=============================================="
log ""

