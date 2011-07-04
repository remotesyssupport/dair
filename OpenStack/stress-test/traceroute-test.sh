#! /bin/bash

compute_nodes=(`cat /etc/dsh/group/compute`) 

storage_nodes=(`cat /etc/dsh/group/storage`)

nodes=("${compute_nodes[@]}" "${storage_nodes[@]}")

while [ 1 ]; do
	echo "----------------------------------------------------------------------"
	for node in "${nodes[@]}"; do
		node_hostname=`echo ${node} | cut -c6-8`;
		echo $(traceroute "${node_hostname}")
	done
	sleep 10
done


