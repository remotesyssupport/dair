#!/bin/bash

multitail -s 2 \
  -t nova-compute.log -l "tail -f /var/log/nova/nova-compute.log" \
  -t nova-network.log -l "tail -f /var/log/nova/nova-network.log" \
  -t nova-api.log -l "tail -f /var/log/nova/nova-api.log" \
  -t nova-scheduler.log -l "tail -f /var/log/nova/nova-scheduler.log" \
  -t nova-objectstore.log -l "tail -f /var/log/nova/nova-objectstore.log" 
