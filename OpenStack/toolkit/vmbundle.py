#!/usr/bin/env python

from __future__ import division
from random import sample
import os
import os.path
import boto
import utils
import vmcreate
import vminit
import atexit
import string

GBs = 1024 * 1024 * 1024
MBs = 1024 * 1024
DEVICE_PREFIX = "/dev/vmbundle-"
MOUNT_POINT_PREFIX = "/mnt/vmbundle-"
DEFAULT_IMAGE_NAME = "new-image"
DEFAULT_BUCKET_NAME = "my-bucket"

mount_point_created = False
volume_created = False
volume_mounted = False

@atexit.register
def cleanup():
    print("\n***** Cleaning up *****")
    if volume_mounted:
        utils.execute("umount " + mount_point)
    if volume_created:
        vmcreate.detach_and_delete(volume)
    if mount_point_created:
        utils.execute("rm -rf " + mount_point)

def rand_suffix():
	return ''.join(random.sample(string.letters, 4))


if not vminit.isRoot():
    print("You need to run this script as root to bundle a VM.")
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

mount_point = MOUNT_POINT_PREFIX + rand_suffix()

while os.path.exists(mount_point):
    mount_point = MOUNT_POINT_PREFIX + rand_suffix()

print("\n***** Creating mount point %(mount_point)s *****" % locals())
utils.execute("mkdir -p %(mount_point)s" % locals())
mount_point_created = True

if fs.f_bfree < fs.f_blocks / 2:
    device = DEVICE_PREFIX + rand_suffix()

    while os.path.exists(device):
        device = DEVICE_PREFIX + rand_suffix()

    print("\n***** Create and attach volume to %(device)s *****" % locals())
    volume = vmcreate.create_and_attach_volume(disk_size_in_GBs, instance, device)
    print(volume.attachment_state())
 
    if not volume:
        print("Error creating volume")
        exit(1)
   
    volume_created = True

    if not os.path.exists(device):
        print("Error attaching volume")
        exit(1) 

    print("\n***** Making filesystem on volume *****")
    utils.execute("mke2fs -q -t ext3 %(device)s" % locals())

    print("\n***** Mounting volume to %(mount_point)s *****" % locals())
    utils.execute("mount %(device)s %(mount_point)s" % locals())

    volume_mounted = True

dirs_to_exclude = "%(mount_point)s,/root/.ssh,/ubuntu/.ssh" % locals()

print("\n***** Excluding directories %(dirs_to_exclude)s *****" % locals())

print("\n***** Bundling volume *****")
kernel_opt = '' if kernel_id == '' else '--kernel ' + kernel_id
ramdisk_opt = '' if ramdisk_id == '' else '--ramdisk ' + ramdisk_id
#utils.execute("euca-bundle-vol --no-inherit %(kernel_opt)s %(ramdisk_opt)s -d %(mount_point)s -r x86_64 -p %(image_name)s -s %(disk_size_in_MBs)s -e %(dirs_to_exclude)s" % locals())

print("\n***** Uploading bundle *****")
#utils.execute("euca-upload-bundle -b %(bucket_name)s -m %(mount_point)s/%(image_name)s.manifest.xml" % locals())

print("\n***** Registering bundle *****")
#utils.execute("euca-register %(bucket_name)s/%(image_name)s.manifest.xml" % locals())
