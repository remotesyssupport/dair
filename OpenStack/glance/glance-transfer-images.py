#!/usr/bin/env python

"""
This script transfers images from one Glance repository to another.  It will
also automatically point filesystem images to the new IDs of their kernels
and/or ramdisks as long as the kernel and ramdisk come before the filesystem
in the arguments used to call this script.
"""

from glance.client import Client
from os import remove
import argparse

TEMP_IMAGE_PATH = '/tmp/glance-transfer-images'

parser = argparse.ArgumentParser(description="Transfer images between Glance repositories.")
parser.add_argument('images', metavar='image', type=int, nargs='+', help="an image to transfer")
parser.add_argument('--source', dest='source', help="source Glance repository")
parser.add_argument('--dest', dest='destination', help="destination Glance repository")

args = parser.parse_args()
source = args.source.split(':')
dest = args.destination.split(':')
try:
	source_client = Client(source[0], source[1])
except IndexError:
	source_client = Client(source[0], 9292)
try:
	dest_client = Client(dest[0], dest[1])
except IndexError:
	dest_client = Client(dest[0], 9292)

new_image_ids = {}

for image in args.images:
	meta, image_file = source_client.get_image(image)	
	f = open(TEMP_IMAGE_PATH, 'wb')
	for chunk in image_file:
		f.write(chunk)
	f.close()

	f = open(TEMP_IMAGE_PATH, 'rb')
	old_id = str(meta['id'])
	del meta['id']
	del meta['location']
	try:
		meta['properties']['kernel_id'] = new_image_ids[meta['properties']['kernel_id']]
	except KeyError:
		None
	try:
		meta['properties']['ramdisk_id'] = new_image_ids[meta['properties']['ramdisk_id']]
	except KeyError:
		None

	new_meta = dest_client.add_image(meta, f)
	new_image_ids[old_id] = str(new_meta['id'])
	print("Image transferred.  Got id: %s" % new_meta['id'])
	f.close()
	remove(TEMP_IMAGE_PATH)
