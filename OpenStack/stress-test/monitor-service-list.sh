#!/bin/bash

while true; do 
    nova-manage service list | sort >> monitor-service-list.log 
    sleep 5
done

