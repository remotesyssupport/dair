#!/bin/bash

if [ `whoami` != root ]; then
        echo "Please run this as the user, 'root'!";
        exit 1
fi

restart libvirt-bin
restart nova-network
restart nova-compute
restart nova-api
restart nova-objectstore
restart nova-scheduler

