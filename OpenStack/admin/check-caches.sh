#!/usr/bin/env bash

MIN_AVAIL=50000000000
IMAGE_DIR=/var/lib/nova/instances/_base
NODES=`nova-manage service list | grep compute | grep -v "disabled\|XXX" | cut -d' ' -f1`
 
for node in $NODES; do
	avail=`ssh -q -o StrictHostKeyChecking=no $node "df -B1 | grep /var/lib/nova | sed \"s/\s\+/ /g\" | cut -d' ' -f4"`

	if [ $avail -lt $MIN_AVAIL ]; then
		images=`ssh -q -o StrictHostKeyChecking=no $node "ls -l $IMAGE_DIR | grep -v \"total\|local\" | sed \"s/\s\+/ /g\""`
		sizes=(`echo "$images" | cut -d' ' -f5`)
		ids=(`echo "$images" | cut -d' ' -f8`)
		images_to_delete=""

		while [ $avail -lt $MIN_AVAIL ] && [ ${#ids[*]} -gt 0 ]; do
			i=$((RANDOM%${#ids[*]}))
			avail=$(($avail+${sizes[$i]}))
			images_to_delete="$images_to_delete ${ids[$i]}"
			unset sizes[$i]
			sizes=(${sizes[@]})
			unset ids[$i]
			ids=(${ids[@]})
		done

		if [ -n "$images_to_delete" ]; then
			echo "$(date): ssh -q -o StrictHostKeyChecking=no $node \"cd $IMAGE_DIR; rm -f $images_to_delete\"" >> /var/log/check-caches.log
		fi
	fi
done
