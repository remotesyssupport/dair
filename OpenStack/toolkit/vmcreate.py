#!/usr/bin/env python
"""
A collection of functions to help create Eucalyptus virtual machines 
	and EBS volumes in the CESWP cloud.
	
	These functions will use the Eucalyptus credentials of whoever is 
	calling this script
"""
import os
import os.path
import boto
import boto.ec2
import time
from urlparse import urlparse

EC2_ACCESS_KEY = os.getenv("EC2_ACCESS_KEY")
EC2_SECRET_KEY = os.getenv("EC2_SECRET_KEY")
EC2_URL = os.getenv("EC2_URL")

if not (EC2_ACCESS_KEY and EC2_SECRET_KEY and EC2_URL):
	print "No cloud credentials found.  Recommend you source your novarc file."
	exit(1)

ec2_url_parsed = urlparse(EC2_URL)
# TODO: need to deal with region in entire file
# curl http://169.254.169.254/2009-04-04/meta-data/placement/availability-zone
novaRegion=boto.ec2.regioninfo.RegionInfo(name = "nova", endpoint = ec2_url_parsed.hostname)

conn = boto.connect_ec2(aws_access_key_id=EC2_ACCESS_KEY,
						aws_secret_access_key=EC2_SECRET_KEY,
						is_secure=False,
						region=novaRegion,
						port=ec2_url_parsed.port,
						path=ec2_url_parsed.path) 

class VolumeError(Exception):
	def __init__(self, msg):
		self.msg = msg
	def __str__(self):
		return repr(self.msg)

def image_map():
	map = {}
	images = conn.get_all_images()
	for image in images:
		if image.type == "machine":
			map[image.id] = image.location.split("/")[0]
	return map


def get_private_key(keyname):
	EC2_private_key = os.getenv("EC2_PRIVATE_KEY")
	config = os.path.dirname(EC2_private_key)
	if not config:
		print "no Eucalyptus configuration directory"
		exit(1)
	
	private_key = os.path.join(config, keyname + ".private")
	if not private_key:
		print "can't find the private key", private_key
		exit(1)
	return private_key


def get_EMI(bucket):
	"""Returns the machine filesystem image found at the bucket location"""
	images = conn.get_all_images()
	for image in images:
		if image.location.startswith(bucket) and image.type == "machine":
			return image
	return None


def get_volume(id=None):
	for volume in conn.get_all_volumes():
		if volume.id == id:
			return volume
	return None


def get_instance(id):
	if not isinstance(id, str) and not id:
		return None

	reservations = conn.get_all_instances([id])
	return reservations[0].instances[0]	


def run_instance(bucket, keyname, instance_type, zone='ceswp', user_data=None, addressing_type='public'):
	
	userdata = None
	image = get_EMI(bucket)

	if user_data:
		print "using", user_data, "as initialisation script"
		f = open(user_data)
		userdata = f.read()

	if image and zone and keyname and instance_type:
		reservation = conn.run_instances(image_id = image.id, placement = zone, key_name = keyname, instance_type = instance_type, user_data = userdata, addressing_type = addressing_type)
		instance = reservation.instances[0]
		while instance.private_dns_name == "0.0.0.0":
			time.sleep(2)
			instance.update()
		return instance
	
	return None


def create_volume(size, zone='nova'):
	"""Returns a volume of 'size' GBs"""
	volume = conn.create_volume(int(size), zone)

	while not volume.update().startswith('available'):
		if volume.status.startswith('error'):
			raise VolumeError('Volume creation failed')

	return volume


def attach_volume(volume, instance, device='/dev/vdb'):
	"""Attaches volume to instance, both of which must be available"""
	if not volume or not instance or os.path.exists(device) or not instances.state.startswith('running') or not volume.status.startswith('available'):
		return False

	volume.attach(instance.id, device)

	#print "Volume %s: %s" %  (volume.id, volume.status)

	while not (volume.status.startswith('attached') or volume.status.startswith('in-use')):
		if volume.status.startswith('error'):
			raise VolumeError('Volume in error state')
		time.sleep(1)
		#print "Volume %s: %s" % (volume.id, volume.status)
		volume.update()

	return True


def create_and_attach_volume(size, instance, device='/dev/vdb', zone='nova'):
	"""Creates and attaches volume to instance, must check returned volume's state"""
	volume = create_volume(size, zone)
	attach_volume(volume, instance, device)
	return volume


def detach_and_delete_volume(volume):
	if not volume:
		return None

	if volume.status.startswith('attached') or volume.status.startswith('in-use'):
		volume.detach()

	while not volume.update().startswith('available'):
		time.sleep(1)

	volume.delete()


def get_reservation(id):
	if not id:
		return None
	
	for reservation in conn.get_all_instances():
		if reservation.id == id:
			return reservation


def get_instance(id):
	if not id:
		return None
	
	for reservation in conn.get_all_instances():
		for instance in reservation.instances:
			if instance.id == id :
				return instance
	return None


def get_dns_names(reservation):
	"""Return the list of public DNS names in this reservation."""
	if not reservation:
		return None
	
	dns_name_list = []
	for instance in reservation.instances:
		dns_name_list.append(instance.public_dns_name)
	return dns_name_list


def cleanup(volume=None, instance=None):
	"""A convienience function to terminate a machine and delete a volume."""
	if volume:
		detach_and_delete_volume(volume)
	if instance:
		conn.terminate_instances([instance.id])



def main():
	# here's an example of how to use this package
	instance = run_instance('ubuntu-10-04-gui', 'simulation', 'c1.xlarge', 'nova')
	volume = create_volume(1, 'nova')    
	attach_volume (volume, instance)
	cleanup(volume, instance)

if __name__ == "__main__":
	main()
