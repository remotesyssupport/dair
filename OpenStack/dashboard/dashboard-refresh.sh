#! /bin/bash

ABS_PATH=`dirname "$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"`
source $ABS_PATH/dashboard.env

# some sanity checks
if [ `whoami` != root ]; then
        echo "Please run this as the user, 'root'!";
        exit 1
fi

if [ ! -f "$NOVARC" ]; then
	echo "can't find novarc file '$NOVARC'"
	exit 1
fi


# you are now entering a zero-tolerance zone
# exit if any variable is not set
set -o nounset 

# dashboard configuration values
NOVA_DEFAULT_ENDPOINT=$(grep EC2_URL= $NOVARC | cut -d'=' -f2  | sed s/'\/'/'\\\/'/g)
NOVA_DEFAULT_REGION="nova"
NOVA_ACCESS_KEY=$(grep EC2_ACCESS_KEY= $NOVARC | cut -d'=' -f2)
NOVA_SECRET_KEY=$(grep EC2_SECRET_KEY= $NOVARC | cut -d'=' -f2)
NOVA_ADMIN_USER=$(grep NOVA_USERNAME= $NOVARC | cut -d'=' -f2)
NOVA_PROJECT_LIST=$(nova-manage project list)


for PROJECT in $NOVA_PROJECT_LIST; do
        if [[ $PROJECT = *'admin'* ]]; then
		NOVA_PROJECT=$PROJECT
        fi
done
                                                                                                                                                                           
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
cd "$DASHBOARD/trunk/openstack-dashboard/local"

sed -i s/^NOVA_DEFAULT_REGION.*/"NOVA_DEFAULT_REGION = '$NOVA_DEFAULT_REGION'"/g local_settings.py
sed -i s/^NOVA_ACCESS_KEY.*/"NOVA_ACCESS_KEY = $NOVA_ACCESS_KEY"/g local_settings.py
sed -i s/^NOVA_SECRET_KEY.*/"NOVA_SECRET_KEY = $NOVA_SECRET_KEY"/g local_settings.py
sed -i s/^NOVA_ADMIN_USER.*/"NOVA_ADMIN_USER = $NOVA_ADMIN_USER"/g local_settings.py
sed -i s/^NOVA_PROJECT.*/"NOVA_PROJECT = '$NOVA_PROJECT'"/g local_settings.py
