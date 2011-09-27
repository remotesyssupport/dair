#!/bin/bash

#Usage:  nova-NODE-install.sh

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
ABS_PATH=`dirname "$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"`

if [ ! -f $ABS_PATH/nova-NODE-env ]; then
    read -p "Device for your private network (Default is eth0 -- Enter to accept): " DEVICE
    DEVICE=${DEVICE:-eth0}

    cp $ABS_PATH/nova-NODE-env.template $ABS_PATH/nova-NODE-env

    DEFAULT_CC_HOST_IP=`ip addr list ${DEVICE} | grep "inet " | cut -d' ' -f6 | cut -d/ -f1`
    if [ ! "$DEFAULT_CC_HOST_IP" ]; then
        DEFAULT_CC_HOST_IP=`ip addr list eth0 | grep "inet " | cut -d' ' -f6 | cut -d/ -f1`
    fi

    sed -i "s/DEFAULT_CC_HOST_IP/$DEFAULT_CC_HOST_IP/g" $ABS_PATH/nova-NODE-env
    sed -i "s/DEVICE/$DEVICE/g" $ABS_PATH/nova-NODE-env

    CONTINUE="n"

    while [ $CONTINUE != "y" ]; do

        vi $ABS_PATH/nova-NODE-env
        . $ABS_PATH/nova-NODE-env

		echo
		echo "##################################"
		echo "Compute/Volume Node Configuration "
		echo "##################################"
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
        
        read -p "Are these settings correct [y|n]? (Default is y -- Enter to accept): " CONTINUE
        CONTINUE=${CONTINUE:-y}

    done
fi

. $ABS_PATH/nova-NODE-env

echo
echo "############################"
echo "Installing required packages"
echo "############################"
echo

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
apt-get -q -y install ntp python-memcache python-mysqldb
apt-get -q -y -t maverick install nova-common nova-compute nova-volume

echo "ENABLED=1" > /etc/default/nova-common

if [ `vgs nova-volumes | grep -c "not found"` -eq 0 ]; then
    echo "Setting up volume group for nova-volumes"
    truncate -s ${MAX_GBS}G /var/lib/nova/volumes
    DEV=`losetup -f --show /var/lib/nova/volumes`
    vgcreate nova-volumes $DEV
fi

echo
echo "Restarting iscsitarget"
echo "ISCSITARGET_ENABLE=true" > /etc/default/iscsitarget
/etc/init.d/iscsitarget restart

ISCSI_PREFIX_IP=`echo $DEFAULT_CC_HOST_IP | cut -d. -f1-3`

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
--glance_host=$GLANCE_HOST_IP
--image_service=nova.image.glance.GlanceImageService
--iscsi_ip_prefix=$ISCSI_PREFIX_IP
NOVA_CONF_EOF

echo
echo "###############"
echo "Setting up LDAP"
echo "###############"
echo

LDAP_PORT=389

if [[ $LDAP_USE == "YES" && $PRIMARY_CC_HOST_IP != $CC_HOST_IP ]]; then
    LDAP_PORT=1389
fi

if [ $LDAP_USE == "YES" ]; then

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
LDAP_CONF_EOF

fi 

echo "Done"
echo

echo "#################"
echo "Bouncing services"
echo "#################"
restart libvirt-bin
start nova-compute
start nova-volume
sleep 5

#Needed for KVM to initialize, VMs run in qemu mode otherwise and is very slow
chgrp kvm /dev/kvm
chmod g+rwx /dev/kvm

#Any server that does NOT have nova-api running on it will need this rule for UEC images to get metadata info
if [ `grep -c "169.254.169.254" /etc/rc.local` -eq 0 ]; then
    iptables -t nat -A PREROUTING -d 169.254.169.254/32 -i $VLAN_INTERFACE -p tcp -m tcp --dport 80 -j DNAT --to-destination $CC_HOST_IP:8773

    sed -i "s/exit 0//g" /etc/rc.local
    echo "iptables -t nat -A PREROUTING -d 169.254.169.254/32 -i $VLAN_INTERFACE -p tcp -m tcp --dport 80 -j DNAT --to-destination $CC_HOST_IP:8773" >> /etc/rc.local
    echo "exit 0" >> /etc/rc.local
fi

#Add some convenient aliases
if [ `grep -c "nova-start" ~/.bashrc` -eq 0 ] ; then
    echo "alias nova-start='rm -f /var/log/nova/*; start nova-compute; start nova-volume'" >> ~/.bashrc
    echo "alias nova-restart='rm -f /var/log/nova/*; restart nova-compute; restart nova-volume'" >> ~/.bashrc
    echo "alias nova-stop='stop nova-compute; stop nova-volume'" >> ~/.bashrc
    echo "alias nova-tail='multitail -s 2 -t nova-compute.log -l \"tail -f /var/log/nova/nova-compute.log\" -t nova-volume.log -l \"tail -f /var/log/nova/nova-volume.log\"'" >> ~/.bashrc
    echo "check_mail:0" >> /etc/multitail.conf
fi


echo
echo "###################################################"
echo "Review the output below for errors in the log files"
echo "###################################################"
echo
grep -i ERROR /var/log/nova/*
echo
echo "Done"
echo

echo
echo "On the Nova Controller at $CC_HOST_IP run the command [nova-manage service list] and check for the hostname of this machine for compute and volume in the host column."
echo "Complete!"
