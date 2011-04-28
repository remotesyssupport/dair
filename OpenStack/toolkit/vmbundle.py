#!/usr/bin/env python

from __future__ import division

import os
import os.path

import boto

import utils
import vmcreate
import vminit

GBs = 1024 * 1024 * 1024
MBs = 1024 * 1024
DEVICE_PREFIX = "/dev/vd"
MOUNT_POINT_PREFIX = "/mnt/bundle-"
NEW_IMAGE_NAME = "new-image"
BUCKET_NAME = "my-bucket"

if not vminit.isRoot():
    print "You need to run this script as root to bundle a VM."
    exit(1)

fs = os.statvfs('/')
disk_size_in_GBs = int(round((fs.f_blocks * fs.f_frsize) / GBs))
disk_size_in_MBs = int(round((fs.f_blocks * fs.f_frsize) / MBs))

print("***** Getting metadata *****")
#instance_id = boto.utils.get_instance_metadata()['instance-id']
#instance = vmcreate.get_instance(instance_id)

# Calculate open device
result = utils.execute("ls " + DEVICE_PREFIX + "*")
devices = result[0].strip().split(" ")
last_device = devices[-1]
last_device_letter = last_device[-1]

if last_device_letter == 'z':
    print("No devices left")
    exit(1)

next_device_letter = chr(ord(last_device_letter) + 1)
device = DEVICE_PREFIX + next_device_letter

print("\n***** Create and attach volume to %(device)s *****" % locals())
#vmcreate.create_and_attach_volume(disk_size_in_GBs, instance, device)

print("\n***** Making filesystem on volume *****")
#utils.execute("mke2fs -q -t ext3 %(DEVICE)s" % locals())

mount_point_suffix = 'a'
mount_point = MOUNT_POINT_PREFIX + mount_point_suffix

while os.path.exists(mount_point):
    mount_point_suffix = chr(ord(mount_point_suffix) + 1)
    mount_point = MOUNT_POINT_PREFIX + mount_point_suffix

print("\n***** Mounting filesystem to %(mount_point)s *****" % locals())
utils.execute("mkdir -p %(mount_point)s" % locals())

dirs_to_exclude = "%(mount_point)s,/root/.ssh,/ubuntu/.ssh" % locals()

print("\n***** Excluding directories %(dirs_to_exclude)s *****" % locals())

#utils.execute("euca-bundle-vol --no-inherit --kernel %(kernel)s --ramdisk %(ramdisk)s -d %(mount_point)s -r x86_64 -p %(image_name)s -s %(disk_size_in_MBs)s -e %(dirs_to_exclude)s" % (instance.kernel, instance.ramdisk, mount_point, image_name, disk_size_in_MBs, dirs_to_exclude))

#shell.euca-upload-bundle("-b",BUCKET_NAME,"-m",MOUNT_POINT + "/" + NEW_IMAGE_NAME + ".manifest.xml")
#print shell.stdout

#shell.euca-register(BUCKET_NAME + "/" + NEW_IMAGE_NAME + ".manifest.xml")
#print shell.stdout
