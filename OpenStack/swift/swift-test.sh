#!/bin/bash

ABS_PATH=`dirname "$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"`
source $ABS_PATH/swift.env

# exit if any unset variables
set -o nounset

# Create Swift admin account and test
# run these commands from the Auth node.
# For Swauth, replace the https://$AUTH_HOSTNAME:11000/v1.0 with https://<PROXY_HOSTNAME>:8080/auth/v1.0

# clean up from previous tests
rm -rf ./download
rm -f curl.out
rm -f swift-test*.txt

# Create a user with administrative privileges 
# (account = system, username = root, password = testpass). 
# Make sure to replace devauth (or swauthkey) with whatever 
# super_admin key you assigned in the auth-server.conf file 
# (or proxy-server.conf file in the case of Swauth) above. 
# Note: None of the values of account, username, or password are 
# special - they can be anything:
admin_key=$(grep super_admin_key /etc/swift/proxy-server.conf | cut -d " " -f 3)
swauth-prep -A https://127.0.0.1:8080/auth/ -K $admin_key
swauth-add-user -A https://127.0.0.1:8080/auth/ -K $admin_key -a $account $user $passwd

# Get an X-Storage-Url and X-Auth-Token:
curl -k -v -H "X-Storage-User: $account:$user" -H "X-Storage-Pass: $passwd" $AUTH_URL 2> curl.out
AUTH_TOKEN=$(grep X-Auth-Token curl.out | cut -d " " -f3 | tr -d '\r\n')
STORAGE_URL=$(grep X-Storage-Url curl.out | cut -d " " -f3 | tr -d '\r\n')
echo "auth token: $AUTH_TOKEN"
echo "storage url: $STORAGE_URL"

# Check that you can HEAD the account:
curl -k -H "X-Auth-Token: $AUTH_TOKEN" $STORAGE_URL

# Check that st works:
st -A $AUTH_URL -U $account:$user -K $passwd stat

echo "this is my first test file" > swift-test-1.txt
echo "this is my second test file" > swift-test-2.txt

# Use st to upload a few files named ‘bigfile[1-2].tgz’ to a container named ‘myfiles’:
st -A $AUTH_URL -U $account:$user -K $passwd upload myfiles swift-test-1.txt
st -A $AUTH_URL -U $account:$user -K $passwd upload myfiles swift-test-2.txt

# Use st to download all files from the ‘myfiles’ container:
mkdir ./download
cd ./download
st -A $AUTH_URL -U $account:$user -K $passwd download myfiles
cd ..
