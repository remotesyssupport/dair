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
DEFAULT_IMAGE_NAME = "new-image"
DEFAULT_BUCKET_NAME = "my-bucket"

if not vminit.isRoot():
    print "You need to run this script as root to bundle a VM."
    exit(1)

custom_image_name = raw_input("Image name (%(DEFAULT_IMAGE_NAME)s): " % locals())
custom_bucket_name = raw_input("\nBucket name (%(DEFAULT_BUCKET_NAME)s): " % locals())

image_name = custom_image_name if custom_image_name else DEFAULT_IMAGE_NAME
bucket_name = custom_bucket_name if custom_bucket_name else DEFAULT_BUCKET_NAME

fs = os.statvfs('/')
disk_size_in_GBs = int(round((fs.f_blocks * fs.f_frsize) / GBs))
disk_size_in_MBs = int(round((fs.f_blocks * fs.f_frsize) / MBs))

print("\n***** Getting metadata *****")
metadata = boto.utils.get_instance_metadata()
instance_id = metadata['instance-id']
instance = vmcreate.get_instance(instance_id)
kernel_id = metadata['kernel-id']
ramdisk_id = metadata['ramdisk-id']

mount_point_suffix = 'a'
mount_point = MOUNT_POINT_PREFIX + mount_point_suffix

while os.path.exists(mount_point):
    mount_point_suffix = chr(ord(mount_point_suffix) + 1)
    mount_point = MOUNT_POINT_PREFIX + mount_point_suffix

print("\n***** Creating directory %(mount_point)s *****" % locals())
utils.execute("mkdir -p %(mount_point)s" % locals())

volume = None

if fs.f_bfree < fs.f_blocks / 2:
    # Calculate open device
    result = utils.execute("ls " + DEVICE_PREFIX + "*")
    devices = result[0].strip().split(" ")
    last_device = devices[-1]
    last_device_letter = last_device[-1]

    if last_device_letter == 'z':
        print("No devices left")
        cleanup()
        exit(1)

    next_device_letter = chr(ord(last_device_letter) + 1)
    device = DEVICE_PREFIX + next_device_letter

    print("\n***** Create and attach volume to %(device)s *****" % locals())
    volume = vmcreate.create_and_attach_volume(disk_size_in_GBs, instance, device)

    if not volume:
        print("Error creating volume")
        cleanup()
	exit(1)

    print("\n***** Making filesystem on volume *****")
    utils.execute("mke2fs -q -t ext3 %(device)s" % locals())

    print("\n***** Mounting volume to %(mount_point)s *****" % locals())
    utils.execute("mount %(device)s %(mount_point)s *****" % locals())

dirs_to_exclude = "%(mount_point)s,/root/.ssh,/ubuntu/.ssh" % locals()

print("\n***** Excluding directories %(dirs_to_exclude)s *****" % locals())

if ramdisk_id == '':
    ramdisk_opt = ''
else:
    ramdisk_opt = "--ramdisk " + ramdisk_id

print("\n***** Bundling volume *****")
utils.execute("euca-bundle-vol --no-inherit --kernel %(kernel_id)s %(ramdisk_opt)s -d %(mount_point)s -r x86_64 -p %(image_name)s -s %(disk_size_in_MBs)s -e %(dirs_to_exclude)s" % locals())

print("\n***** Uploading bundle *****")
utils.execute("euca-upload-bundle -b %(bucket_name)s -m %(mount_point)s/%(image_name)s.manifest.xml" % locals())
#print shell.stdout

print("\n***** Registering bundle *****")
utils.execute("euca-register %(bucket_name)s/%(image_name)s.manifest.xml" % locals())
#print shell.stdout

cleanup()


def cleanup():
    if volume:
	utils.execute("umount " + mount_point)
        vmcreate.detach_and_delete_volume(volume)

    utils.execute("rm -rf " + mount_point)

