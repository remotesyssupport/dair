#! /bin/bash

# This script should be run as root with the cloud admin user credentials sourced

# This script cribbed from installation guide at 
# http://wiki.openstack.org/OpenStackDashboard

#Enforcing root user to execute the script
if [ `whoami` != root ]; then
    echo "Please run this as the user, 'root'!";
    exit 1
fi

if [ -z "$EC2_URL" ]; then
	echo "Please source the credentials of the cloud admin user."
	exit 1
fi

ABS_PATH=`dirname "$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"`

if [ ! -f $ABS_PATH/dashboard-env ]; then
    cp $ABS_PATH/dashboard-env.template $ABS_PATH/dashboard-env

    CONTINUE="n"

    while [ $CONTINUE != "y" ]; do

        vi $ABS_PATH/dashboard-env
        . $ABS_PATH/dashboard-env

        echo
        echo "#######################"
        echo "Dashboard Configuration"
        echo "#######################"
        echo
        echo "Email Port: $EMAIL_PORT"
        echo
        echo "Email Host: $EMAIL_HOST"
        echo
        echo "Email Host User: $EMAIL_HOST_USER"
        echo
        echo "Email Host Password: $EMAIL_HOST_PASSWORD"
        echo
        echo "Email Use TLS: $EMAIL_USE_TLS"
        echo
        
        read -p "Are these settings correct [y|n]? (Default is y -- Enter to accept): " CONTINUE
        CONTINUE=${CONTINUE:-y}
    done
fi

. $ABS_PATH/dashboard-env


# you are now entering a zero-tolerance zone
# exit if any variable is not set
set -o nounset 

echo "Installing the OpenStack Dashboard to $DASHBOARD"
# Get openstack-dashboard
# openstack-dashboard provides all the look and feel for the dashboard.
mkdir -p $DASHBOARD
cd $DASHBOARD
git clone git://github.com/canarie/openstack-dashboard.git dair

cd "$DASHBOARD/dair/openstack-dashboard/local"
cat >> local_settings.py << EOF
import os

DEBUG = True
TEMPLATE_DEBUG = DEBUG
PROD = False
USE_SSL = False


DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': 'dashboard' ,
        'USER': 'root',
        'PASSWORD': '$MYSQL_PW',
        'HOST': 'localhost',
    },
}

CACHE_BACKEND = 'dummy://'

NOVA_DEFAULT_ENDPOINT = ''
NOVA_DEFAULT_REGION = ''
NOVA_ACCESS_KEY = ''
NOVA_SECRET_KEY = ''
NOVA_ADMIN_USER = ''
NOVA_PROJECT = ''

EMAIL_PORT = $EMAIL_PORT
EMAIL_HOST = '$EMAIL_HOST'
EMAIL_HOST_USER = '$EMAIL_HOST_USER'
EMAIL_HOST_PASSWORD = '$EMAIL_HOST_PASSWORD'
EMAIL_USE_TLS = None
EOF

# we assume the MySQL database is already installed for Nova
mysql -uroot -p$MYSQL_PW -e "CREATE DATABASE dashboard;"

# additional packages for Django to use mySQL DB
apt-get -y install python-setuptools python-dev libmysqlclient-dev

cd "$DASHBOARD/dair/openstack-dashboard"
easy_install virtualenv
python tools/install_venv.py
tools/with_venv.sh pip install MySQL-python
tools/with_venv.sh dashboard/manage.py syncdb 

#~ # add the VNC console
#chmod +x $ABS_PATH/dashboard-vncproxy-install.sh
#$ABS_PATH/dashboard-vncproxy-install.sh
#cp local_settings.py.example local_settings.py

# call script to extract dashboard configuration values
# from the nova installation
chmod +x $ABS_PATH/dashboard-refresh.sh
$ABS_PATH/dashboard-refresh.sh

cd $DASHBOARD/dair/openstack-dashboard/media
ln -s $DASHBOARD/dair/openstack-dashboard/.dashboard-venv/lib/python2.6/site-packages/django/contrib/admin/media/ admin

cat > $DASHBOARD_START_STOP << EOF
#! /bin/bash

usage()
{
    echo
    echo "start or stop the OpenStack dashboard"
    echo
    echo "    \$0 start|stop|restart"
    echo
    exit 0
}

case \$1 in
    start )
        echo "starting dashboard..."
        cd $DASHBOARD/dair/openstack-dashboard/
        nohup tools/with_venv.sh dashboard/manage.py runserver --noreload '$DASHBOARD_SERVER_IP:8080' > /var/log/nova/dashboard.log &
        ;;

    stop )
        echo "stopping dashboard..."
        PID=\$(ps -efl | grep runserver | grep -v "grep" |cut -c14-18 | sort -r | head -1)
        kill \$PID
        ;;

    restart )
        echo "re-starting dashboard..."
        dashboard stop
        dashboard start
        ;;

    *)
        usage
        ;;
esac
EOF

chmod +x $DASHBOARD_START_STOP

