#!/bin/bash

#Usage: nova-CC-install.sh

#Enforcing root user to execute the script
if [ `whoami` != root ]; then
    echo "Please run this as the user, 'root'!";
    exit 1
fi

#This is a Linux check
if [ `uname -a | grep -i linux | wc -l` -lt 1 ]; then
    echo "Not Linux, not compatible."
    exit 1
fi

#Compatible OS Check
DEB_OS=`cat /etc/issue | grep -i 'ubuntu'`
RH_OS=`cat /etc/issue | grep -i 'centos'`

if [[ ${#DEB_OS} -gt 0 ]] ; then
    echo "Valid OS, continuing..."
    CUR_OS="Ubuntu"
elif [[ ${#RH_OS} -gt 0 ]] ; then
    echo "Unsupported OS, sorry!"
    exit 1
else
    echo "Unsupported OS, sorry!"
    exit 1
fi

echo $CUR_OS detected!

#Setup the environment
HOSTNAME=`hostname`
ABS_PATH=`dirname "$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"`

if [ ! -f $ABS_PATH/nova-CC-env ]; then
    read -p "Device for your private network (Default is eth0 -- Enter to accept): " DEVICE
    DEVICE=${DEVICE:-eth0}

    cp $ABS_PATH/nova-CC-env.template $ABS_PATH/nova-CC-env

    DEFAULT_CC_HOST_IP=`ip addr list ${DEVICE} | grep "inet " | cut -d' ' -f6 | cut -d/ -f1`
    sed -i "s/DEFAULT_CC_HOST_IP/$DEFAULT_CC_HOST_IP/g" $ABS_PATH/nova-CC-env
    sed -i "s/DEVICE/$DEVICE/g" $ABS_PATH/nova-CC-env

    CONTINUE="n"

    while [ $CONTINUE != "y" ]; do

        vi $ABS_PATH/nova-CC-env
        . $ABS_PATH/nova-CC-env

        echo
        echo "###################################"
        echo "Nova Cloud Controller Configuration"
        echo "###################################"
        echo
        echo "Cloud Controller Host IP: $CC_HOST_IP"
        echo
        echo "S3 Host IP:               $S3_HOST_IP"
        echo
        echo "Glance Host IP:           $GLANCE_HOST_IP"
        echo
        echo "RabbitMQ Host IP:         $RABBIT_IP"
        echo
        echo "MySQL Host IP:            $MYSQL_HOST_IP"
        echo
        echo "MySQL Password set"
        echo
        echo "Memcached Host IP:        $MEMCACHED_HOST_IP"
        echo
        echo "LDAP Host IP:             $LDAP_HOST_IP"
        echo
        echo "LDAP Password set"
        echo
        echo "VLAN interface:           $VLAN_INTERFACE"
        echo
        echo "Region list:              $REGION_LIST"
        echo
        echo "This region:              $THIS_REGION"

        echo
        echo "##########################"
        echo "Nova Network Configuration"
        echo "##########################"
        echo
        echo "Starting CIDR range of private IPs for VMs: $NETWORK_CIDR"
        echo
        echo "Number of networks for ALL projects: $NETWORK_NUMBER"
        echo
        echo "Number of IPs per network for ALL projects: $IPS_PER_NETWORK"
        echo
        echo "Number of IPs reserved for VPN clients per project: $NUMBER_VPN_CLIENTS"
        echo
        echo "Cloud admin user name set as $CLOUD_ADMIN"
        echo
        echo "Cloud admin project set as $CLOUD_ADMIN_PROJECT"
        echo
        
        read -p "Are these settings correct [y|n]? (Default is y -- Enter to accept): " CONTINUE
        CONTINUE=${CONTINUE:-y}

    done
fi

. $ABS_PATH/nova-CC-env

echo
echo "############################"
echo "Installing required packages"
echo "############################"
echo

cat <<MYSQL_PRESEED | debconf-set-selections
mysql-server-5.1 mysql-server/root_password password $MYSQL_PW
mysql-server-5.1 mysql-server/root_password_again password $MYSQL_PW
mysql-server-5.1 mysql-server/start_on_boot boolean true
MYSQL_PRESEED

apt-get -q -y install python-software-properties

if [ $PACKAGES == "ANSO" ]; then
    apt-key adv --keyserver keyserver.ubuntu.com --recv 460DF9BE
    add-apt-repository 'deb http://packages.ansolabs.com/ maverick main'
elif [ $PACKAGES == "TRUNK" ]; then
    add-apt-repository ppa:nova-core/trunk
else
    add-apt-repository ppa:openstack-release/2011.2
fi

apt-get -q update
apt-get -q -y install ntp monit memcached python-memcache python-mysqldb mysql-server rabbitmq-server python-eventlet euca2ools unzip ntp
apt-get -q -y install nova-api nova-network nova-objectstore nova-scheduler

echo "ENABLED=1" > /etc/default/nova-common

echo
echo "###################################"
echo "Setting up Nova configuration files"
echo "###################################"
echo

#Info to be passed into /etc/nova/nova.conf
cat > /etc/nova/nova.conf << NOVA_CONF_EOF
--dhcpbridge_flagfile=/etc/nova/nova.conf
--dhcpbridge=/usr/bin/nova-dhcpbridge
--lock_path=/var/lock/nova
--logdir=/var/log/nova
--state_path=/var/lib/nova
--verbose
--sql_connection=mysql://root:$MYSQL_PW@$MYSQL_HOST_IP/nova
--rabbit_host=$RABBIT_IP
--s3_host=$S3_HOST_IP
--ec2_host=$CC_HOST_IP
--vlan_interface=$VLAN_INTERFACE
--max_cores=$MAX_CORES
--max_gigabytes=$MAX_GBS
--glance_host=$GLANCE_HOST_IP
--image_service=nova.image.glance.GlanceImageService
--scheduler_driver=nova.scheduler.simple.SimpleScheduler
NOVA_CONF_EOF

if [[ $VPN_USE == "YES" ]]; then

#Info to be passed into /etc/nova/nova.conf
cat >> /etc/nova/nova.conf << VPN_CONF_EOF
--use_project_ca=true
--cnt_vpn_clients=$NUMBER_VPN_CLIENTS
VPN_CONF_EOF

fi

LDAP_PORT=389

if [[ $LDAP_USE == "YES" && $PRIMARY_CC_HOST_IP != $CC_HOST_IP ]]; then
    ssh-keygen -t rsa -N "" -f /root/.ssh/nova_ldap_key
    ssh-copy-id -i /root/.ssh/nova_ldap_key.pub $PRIMARY_CC_HOST_IP
    
    cp $ABS_PATH/nova-ldap-ssh-tunnel /usr/bin/
    sed -i "s/PRIMARY_CC_HOST_IP/${PRIMARY_CC_HOST_IP}/g" /usr/bin/nova-ldap-ssh-tunnel
    /usr/bin/nova-ldap-ssh-tunnel start
    
    sed -i "s/startup=0/startup=1/g" /etc/default/monit
    
    echo "  check process nova_ldap_ssh_tunnel" >> /etc/monit/monitrc
    echo "    with pidfile /var/run/nova/nova_ldap_ssh_tunnel.pid" >> /etc/monit/monitrc
    echo "    start program \"/usr/bin/nova-ldap-ssh-tunnel start\"" >> /etc/monit/monitrc
    echo "    stop program \"/usr/bin/nova-ldap-ssh-tunnel stop\"" >> /etc/monit/monitrc
    
    /etc/init.d/monit restart
    
    LDAP_PORT=1389
    LDAP_HOST_IP=localhost
fi

if [ $LDAP_USE == "YES" ]; then

echo
echo "###############"
echo "Setting up LDAP"
echo "###############"
echo

sed -i "s/127.0.0.1/${MEMCACHED_HOST_IP}/g" /etc/memcached.conf
/etc/init.d/memcached restart

#Info to be passed into /etc/nova/nova.conf
cat >> /etc/nova/nova.conf << LDAP_CONF_EOF
--memcached_servers=$MEMCACHED_HOST_IP:11211
--auth_driver=nova.auth.ldapdriver.LdapDriver
--ldap_url=ldap://$LDAP_HOST_IP:$LDAP_PORT
--ldap_user_dn=cn=admin,$LDAP_DOMAIN
--ldap_user_subtree=ou=Users,$LDAP_DOMAIN
--ldap_project_subtree=ou=Groups,$LDAP_DOMAIN
--role_project_subtree=ou=Groups,$LDAP_DOMAIN
--ldap_cloudadmin=cn=cloudadmins,ou=Groups,$LDAP_DOMAIN
--ldap_itsec=cn=itsec,ou=Groups,$LDAP_DOMAIN
--ldap_sysadmin=cn=sysadmins,ou=Groups,$LDAP_DOMAIN
--ldap_netadmin=cn=netadmins,ou=Groups,$LDAP_DOMAIN
--ldap_developer=cn=developers,ou=Groups,$LDAP_DOMAIN
--ldap_password=$LDAP_PW
--region_list=$REGION_LIST
LDAP_CONF_EOF

echo "Done"
echo

else
    THIS_REGION=nova
fi 

echo "######################"
echo "Finalizing MySQL setup"
echo "######################"
echo

sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf
service mysql restart

mysql -uroot -p$MYSQL_PW -e "CREATE DATABASE nova;"
mysql -uroot -p$MYSQL_PW -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;"
mysql -uroot -p$MYSQL_PW -e "SET PASSWORD FOR 'root'@'%' = PASSWORD('$MYSQL_PW');"

echo
echo "Initializing database"
nova-manage db sync
sleep 1

echo
echo "Starting nova-api to create certificates in DB"
start nova-api
restart nova-api
sleep 3

echo
echo "##################################"
echo "Setting up network and cloud admin"
echo "!! This will take a few minutes !!"
echo "##################################"
echo

if [ $PRIMARY_CC_HOST_IP == $CC_HOST_IP ]; then
    /usr/bin/python /usr/bin/nova-manage user admin $CLOUD_ADMIN
    /usr/bin/python /usr/bin/nova-manage project create $CLOUD_ADMIN_PROJECT $CLOUD_ADMIN
fi

/usr/bin/python /usr/bin/nova-manage network create $NETWORK_CIDR $NETWORK_NUMBER $IPS_PER_NETWORK
/usr/bin/python /usr/bin/nova-manage floating create $HOSTNAME $FLOATING_IPS_CIDR

echo
echo "Done"
echo

echo "##################################"
echo "Generating cloud admin credentials"
echo "##################################"
echo

CLOUD_ADMIN_CREDENTIALS_DIR=/root/creds-admin

mkdir -p ${CLOUD_ADMIN_CREDENTIALS_DIR}
/usr/bin/python /usr/bin/nova-manage project zipfile $CLOUD_ADMIN_PROJECT $CLOUD_ADMIN ${CLOUD_ADMIN_CREDENTIALS_DIR}/novacreds.zip
unzip -d ${CLOUD_ADMIN_CREDENTIALS_DIR} ${CLOUD_ADMIN_CREDENTIALS_DIR}/novacreds.zip
. ${CLOUD_ADMIN_CREDENTIALS_DIR}/${THIS_REGION}rc

if [ `grep -c "${THIS_REGION}rc" ~/.bashrc` -eq 0 ] ; then
  echo ". ${CLOUD_ADMIN_CREDENTIALS_DIR}/${THIS_REGION}rc" >> ~/.bashrc
fi

echo "Setup default ICMP and SSH security groups"
euca-authorize -P icmp -t -1:-1 default
euca-authorize -P tcp -p 22 default

echo "Creating a key for $CLOUD_ADMIN"
euca-add-keypair admin-${THIS_REGION} > ${CLOUD_ADMIN_CREDENTIALS_DIR}/admin-${THIS_REGION}.private
chmod 600 ${CLOUD_ADMIN_CREDENTIALS_DIR}/admin-${THIS_REGION}.private

echo
echo "#################################"
echo "Changing some networking settings"
echo "#################################"
echo

if [ `grep -c "169.254.169.254" /etc/rc.local` -eq 0 ]; then
    #Need this rule for Windows and desktop Linux
    ip addr add 169.254.169.254/32 scope link dev $VLAN_INTERFACE
    sed -i "s/exit 0//g" /etc/rc.local
    echo "ip addr add 169.254.169.254/32 scope link dev $VLAN_INTERFACE" >> /etc/rc.local
    echo "exit 0" >> /etc/rc.local

    #Need this rule for floating IPs
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo "net.ipv4.conf.default.forwarding=1" >> /etc/sysctl.conf
    echo "net.ipv4.conf.all.forwarding=1" >> /etc/sysctl.conf
fi

echo
echo "#########################################"
echo "Ensure all four Nova services are running"
echo "#########################################"
echo
restart nova-api
start nova-network
start nova-objectstore
start nova-scheduler

echo
ps aux | grep -i nova
sleep 5

#Add some convenient aliases
if [ `grep -c "nova-start" ~/.bashrc` -eq 0 ] ; then
    echo "alias nova-images='euca-describe-images | grep machine | cut -f 2,3,4,5'" >> ~/.bashrc
    echo "alias nova-instances='euca-describe-instances | grep INSTANCE | cut -f 2,4,5,7,6'" >> ~/.bashrc
    echo "alias nova-volumes='euca-describe-volumes | grep VOLUME | cut -f 2,3,6'" >> ~/.bashrc
    echo "alias nova-start='rm -f /var/log/nova/*; start nova-api; start nova-network; start nova-scheduler; start nova-objectstore'" >> ~/.bashrc
    echo "alias nova-restart='rm -f /var/log/nova/*; restart nova-api; restart nova-network; restart nova-scheduler; restart nova-objectstore'" >> ~/.bashrc
    echo "alias nova-stop='stop nova-api; stop nova-network; stop nova-scheduler; stop nova-objectstore'" >> ~/.bashrc
    echo "alias nova-tail='multitail -s 2 -t nova-api.log -l \"tail -f /var/log/nova/nova-api.log\" -t nova-scheduler.log -l \"tail -f /var/log/nova/nova-scheduler.log\" -t nova-network.log -l \"tail -f /var/log/nova/nova-network.log\"'" >> ~/.bashrc
    echo "check_mail:0" >> /etc/multitail.conf
fi

echo
echo "Kill all dnsmasq process and restart nova-nework to ensure only the proper dnsmasq is running"
killall dnsmasq
service nova-network restart

echo
echo "###################################################"
echo "Review the output below for errors in the log files"
echo "###################################################"
echo
grep -i ERROR /var/log/nova/*
echo
echo "Done"

echo "Run the command [source ${CLOUD_ADMIN_CREDENTIALS_DIR}/${THIS_REGION}rc] before trying to work with your new cloud."
echo
echo "Complete!"
