#! /usr/bin/env python

#################################################################
# File:     quota-monitor.py
# Purpose:  Aggregate and balance quotas over zones in OpenStack 
# Author:   Andrew Nisbet andrew.nisbet@cybera.ca
# Date:     October 3, 2011
# Version:  0.1 - Dev. Not ready for initial release. 
#################################################################

import os			# for getcwd()
import sys
import getopt       # Command line processing.
import string		# for atoi()
import subprocess	# for execute_call()

APP_DIR = os.getcwd() + '/'
GSTD_QUOTA_FILE = APP_DIR + "baseline_quotas.txt" # Gold standard quotas for baseline.
RUNG_QUOTA_FILE = "/tmp/quotas.tmp" # Saved state on condition of quotas since last run
NOVA_CONF = "/home/cybera/dev/nova.conf" # nova.conf -- change for production.


# sql queries:
# basic passing:
#		ssh root@openstack1.cybera.ca 'mysql -uroot -pxxxxxxxxxx nova -e "show tables;"'
# total instances by project:
# 		select project_id, count(state) from instances where state=1 group by project_id;
# total size of all volumes by project gigbytes:
# 		select project_id, sum(size) from volumes where attach_status='attached' group by project_id;
# total volumes by project:
#		select project_id, count(size) from volumes where attach_status='attached' group by project_id;
# Total number of floating_ips in use by a project (make sure you get rid of the NULL project value):
# 		select project_id, count(deleted) from floating_ips where deleted=0 group by project_id;
# CPUs in use by a project:
# 		select project_id, sum(vcpus) from instances where state_description='running' group by project_id;
#		select project_id, sum(vcpus) from instances where state=1 group by project_id;
class ZoneQueryManager:
	def __init__(self):
		self.Q_PROJECT_INSTANCES = "\"select project_id, count(state) from instances where state=1 group by project_id;\""
		self.Q_PROJECT_GIGABYTES = """ "select project_id, sum(size) from volumes where attach_status=\\'attached\\' group by project_id;" """ # returns empty set not expected '0'
		self.Q_PROJECT_VOLUMES   = "\"select project_id, count(size) from volumes where attach_status=\'attached\' group by project_id;\""
		self.Q_PROJECT_FLOAT_IPS = "\"select project_id, count(deleted) from floating_ips where deleted=0 group by project_id;\""
		self.Q_PROJECT_CPUS      = "\"select project_id, sum(vcpus) from instances where state=1 group by project_id;\""
		self.regions = {} # {'full_name' = ip}
		self.instances = {} # {'full_name' = Quota_obj}
		self.password = None
		# this requires two greps of the nova.conf file but could be done in one.
		# get the regions like: --region_list=alberta=208.75.74.10,quebec=208.75.75.10
		results = self.execute_call("grep region_list " + NOVA_CONF)
		results = results.split('region_list=')[1]
		# now split on the regions separated by a ','
		results = results.split(',')
		for result in results:
			name_value = result.split('=')
			self.regions[name_value[0].strip()] = name_value[1].strip() # gets rid of nagging newline
		# now the password --sql_connection=mysql://root:xxxxxxxxxxxxx@192.168.2.10/nova
		results = self.execute_call("grep sql_connection " + NOVA_CONF)
		self.password = results.split('root:')[1].split('@')[0] # yuck.
		#print self.password, self.regions
		
	def execute_call(self, command_and_args):
		""" returns the stdout of a Unix command """
		cmd = command_and_args.split()
		if len(cmd) < 1:
			return "<no cmd to execute>"
		process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		return process.communicate()[0]
		
	def get_zone_snapshots(self):
		for zone in self.regions.keys():
			zone_query_results = Quota()
			self._query_(zone, zone_query_results)
			self.instances[zone] = zone_query_results
		print self.instances

	def _query_(self, zone, results):
		print "querying " + zone + " for instances..."
		ssh_cmd = "ssh root@" + self.regions[zone]
		sql_cmd_prefix = " 'mysql -uroot -p" + self.password + " nova -e "
		sql_cmd_suffix = "'"
		
		print ssh_cmd + sql_cmd_prefix + self.Q_PROJECT_GIGABYTES + sql_cmd_suffix
		results.set_quota('floating_ips', 77)
		
# metadata_items: 128
# gigabytes: 100
# floating_ips: 5
# instances: 5
# volumes: 5
# cores: 10

# Open the qotas for each project. This is a gold standard file since once this
# script runs the quotas are dynamically changed as over time.

class Quota:
	""" 
	This class represents a project's quotas. It also includes a flag to 
	determine if the project stackholders have been alerted to overquotas.
	"""
			
	def __init__(self, flags=0, meta=128, Gb=100, f_ips=10, insts=10, vols=10, cors=20):
		self.quota = {}
		self.quota['flags'] = flags # flags is currently if we have issued an email yet
		self.quota['metadata_items'] = meta
		self.quota['gigabytes'] = Gb
		self.quota['floating_ips'] = f_ips
		self.quota['instances'] = insts
		self.quota['volumes'] = vols
		self.quota['cores'] = cors
	
	# reads lines from a file and if the values are '=' separated it will assign the named quota the '=' value.
	# WARNING: If the quota name is spelt incorrectly the default value is used.
	def set_values(self, values):
		""" This method is used for parsing a string of 'name=value,' quotas. """
		project_name = None
		for value in values:
			name = value.split('=')[0].strip()
			vs = value.split('=')[1].strip()
			if name == 'project':
				project_name = vs
			else:
				vs = string.atoi(vs)
				self.quota[name] = vs # possible to set a quota that doesn't exist by misspelling its name
			print "name = " + name + " value = " + str(vs)
		if project_name == None or project_name == "":
			# project name not specified in file throw exception
			raise QuotaException("quotas found for a project with no name.")
		else:
			return project_name
			
	def set_quota(self, name, value):
		""" Stores a quota value. """
		self.quota[name] = value
		
	def get_quota(self, name):
		""" Returns a quota value or None if not found. """
		return self.quota[name]
		
	def __str__(self):
		return repr("flags: %d, metadata_items: %d, gigabytes: %d, floating_ips: %d, instances: %d, volumes: %d, cores: %d" % \
		(self.quota['flags'],
		self.quota['metadata_items'],
		self.quota['gigabytes'],
		self.quota['floating_ips'],
		self.quota['instances'],
		self.quota['volumes'],
		self.quota['cores']))
		
# The baseline quota file is made up of lines of quotas where the minimum entry
# is the project name. There is no maximum entry so future quotas can be added
# with no impact to reading the file, unrecognized quotas are ignored, those
# that are not mentioned are set to the OpenStack defaults set by compute--
# project-create.sh. The format of the file is a single line per project with
# name value pairs separated by ','. Trailing ',' are not permitted. Examples:
# name_0=value_0, name_1=value_1
# Blank lines are allowed and the comment character is '#'. 
#
# Valid entries tested include:
# project=a,flags=1,metadata_items=120,gigabytes=99, floating_ips=9,   instances=4,	volumes =  2, cores    =   20
# flags=0,metadata_items=121,gigabytes=10, floating_ips=10,   instances=5,	volumes =4, cores=7,project=z
# cores=999, project=p
def read_baseline_quota_file(quotas):
	try:
		f = open(GSTD_QUOTA_FILE)
	except:
		raise QuotaException("No initial project quota values defined for projects. There should be a file here called %s." % (GSTD_QUOTA_FILE))
	
	line_no = 0
	for line in f.readlines():
		if line.strip() != "" and line[0] != "#":
			read_values = line.split(',') # read_values holds name=value pairs.
			line_no = line_no + 1
			project_quota = Quota()
			name = None
			try:
				name = project_quota.set_values(read_values)
			except:
				raise QuotaException("Malformed quota file on line %d" % (line_no))
			# save the project's quotas from file
			quotas[name] = project_quota
		print quotas
		
# There has to be a way to reset the quotas to the baseline for all groups 
# in the case that there is a problem and the quotas get out of synch.
# This method does that.
def reset_quotas(quotas):
	""" 
	Reads the gold standard project quotas for projects and sets those
	values in each zone. This function does not balance zone quotas.
	"""
	print "resetting quotas..."
	read_baseline_quota_file(quotas)
	return set_quotas(quotas)
	
# Sets the quotas for a zone based on the supplied quotas.
def set_quotas(zone, quotas):
	pass
	
def balance_quotas(quotas):
	"""
	Balances quotas. Run from cron this function runs once per preset time period.
	The formula is: Qnow = Qbaseline - Iother_zones where
	Qnow: the quota for a specific but arbitrary zone at this cycle
	Qbaseline: the quota for the project assigned when the project was created
	Iother: the number of instances of a resource being consumed in all other zones.
	"""
	zoneManager = ZoneQueryManager() # this will now contain the regions and sql password
	zoneManager.get_zone_snapshots()

def usage():
	return """
Usage: quota-monitor.py [-hr, --help, --reset]

    This script is meant to be run routinely by cron to check and 
    balance quotas over zones in OpenStack.
    
    In the DAIR environment quotas are assigned at project creation
    but were not being propagated to other zones correctly. Worse 
    zones were getting the same values as the values set in the 
    management node's zone. This seems reasonable at first because
    a customer in any zone should have access to the full quota of
    VMs that they paid for. The problem is that as you instantiate
    a VM in one zone, people in other zones think they can start
    their full quota, not n -1 instances. To remedy that this 
    script makes note of what each project should have as resources
    then periodically queries how many instances are actually being
    used in different zones, then reduces the quota total for the 
    other zones and reports if the reduced quota falls below zero.
    
    -h, --help prints this message and exits with status 1.
    -r, --reset resets the quotas to the original values set in the
		./baseline_quotas.txt file.
"""
	
class QuotaException:
	def __init__(self, msg):
		self.msg = msg
	def __str__(self):
		return repr(self.msg)


def main():
	
	quotas = {}
    # parse command line options
	try:
		opts, args = getopt.getopt(sys.argv[1:], "hrb", ["help","reset","balance"])
	except getopt.GetoptError, err:
		print str(err)
		print usage()
		sys.exit(2)

	
	for o, a in opts:
		if o in ("-h", "--help"):
			print usage()
			return 1
		elif o in ("-r", "--reset"):
			return reset_quotas(quotas)
		elif o in ("-b", "--balance"):
			return balance_quotas(quotas)
		else:
			assert False, "unimplemented option '" + o + "'"


if __name__ == "__main__":
    sys.exit(main())
