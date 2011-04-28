#!/bin/bash

if [ `whoami` != root ]; then
        echo "Please run this as the user, 'root'!";
        exit 1
fi

apt-get -y update
apt-get -y upgrade
apt-get -y install kvm-pxe curl vlan gcc multitail vim
svn co --username public --password public --no-auth-cache --non-interactive --trust-server-cert https://ceswp.ca/svn/ceswp/toolkit/system/ toolkit-system/
toolkit-system/install-command-logging.sh
source /etc/bash.bashrc
