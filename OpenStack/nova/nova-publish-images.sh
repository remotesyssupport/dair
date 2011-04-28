#!/bin/bash

if [ `whoami` != root ]; then
        echo "Please run this as the user, 'root'!";
        exit 1
fi

IMAGE="ubuntu-10.04-server-uec-amd64.tar.gz"
IMAGE_URL="http://uec-images.ubuntu.com/server/releases/lucid/release/$IMAGE"

. /root/creds-admin/novarc

mkdir images
cd images
wget $IMAGE_URL
uec-publish-tarball $IMAGE ubuntu-10-04-server x86_64

echo "********** euca-describe-images **********"
euca-describe-images

echo
echo "Set up your env variables with: source /root/creds/novarc"
echo "To run an instance of your image: euca-run-instances <ami> -k admin -t m1.tiny"
echo "To check and see if your instance is running: euca-describe-instances"
echo "To ssh to your instance: ssh -i /root/creds/admin.private ubuntu@<instance_ip>"
