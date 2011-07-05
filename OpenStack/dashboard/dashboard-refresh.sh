#! /bin/bash

# This script should be run as root with the cloud admin user credentials sourced

ABS_PATH=`dirname "$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"`
source $ABS_PATH/dashboard-env

# some sanity checks
if [ `whoami` != root ]; then
    echo "Please run this as the user, 'root'!";
    exit 1
fi

if [ -z "$EC2_URL" ]; then
	echo "Please source the credentials of the cloud admin user."
	exit 1
fi


# you are now entering a zero-tolerance zone
# exit if any variable is not set
set -o nounset 

# dashboard configuration values
NOVA_DEFAULT_ENDPOINT=$EC2_URL
NOVA_DEFAULT_REGION=$DEFAULT_REGION
NOVA_ACCESS_KEY=$EC2_ACCESS_KEY
NOVA_SECRET_KEY=$EC2_SECRET_KEY
NOVA_ADMIN_USER=$NOVA_USERNAME
NOVA_PROJECT=`nova-manage project list | head -1`
                                                                                                                                                                           
#~ In the local_settings.py file, we need to change several important options:
#~ --------------------------------------------------------------------- 
#~ * NOVA_DEFAULT_ENDPOINT : this needs to be set to nova-api instance URL from above. 
#~      Keep the default ('http://localhost:8773/services/Cloud') if you are running 
#~      the dashboard on the same machine as your nova-api.
#~ * NOVA_DEFAULT_REGION : this can remain 'nova'
#~ * NOVA_ACCESS_KEY : this should be the EC2_ACCESS_KEY in your novarc file.
#~ * NOVA_SECRET_KEY : this should be the EC2_SECRET_KEY in your novarc file.
#~ * NOVA_ADMIN_USER: this can be any user with admin privileges in your nova database. 
#~	The CLOUD_SERVERS_USERNAME from your admin credentials file is fine.
#~ * NOVA_PROJECT: this can be any project (defined in your nova database) which the 
#~	NOVA_ADMIN_USER is defined as project_manager. Refer to RunningNova for 
#~	assistance if you haven't defined any nova projects. 
#~ --------------------------------------------------------------------- 
cd "$DASHBOARD/dair/openstack-dashboard/local"

sed -i s/^NOVA_DEFAULT_ENDPOINT.*/"NOVA_DEFAULT_ENDPOINT = '$NOVA_DEFAULT_ENDPOINT'"/g local_settings.py
sed -i s/^NOVA_DEFAULT_REGION.*/"NOVA_DEFAULT_REGION = '$NOVA_DEFAULT_REGION'"/g local_settings.py
sed -i s/^NOVA_ACCESS_KEY.*/"NOVA_ACCESS_KEY = $NOVA_ACCESS_KEY"/g local_settings.py
sed -i s/^NOVA_SECRET_KEY.*/"NOVA_SECRET_KEY = $NOVA_SECRET_KEY"/g local_settings.py
sed -i s/^NOVA_ADMIN_USER.*/"NOVA_ADMIN_USER = $NOVA_ADMIN_USER"/g local_settings.py
sed -i s/^NOVA_PROJECT.*/"NOVA_PROJECT = '$NOVA_PROJECT'"/g local_settings.py
