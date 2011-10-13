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
import subprocess	# for __execute_call__()
import logging		# for logging

APP_DIR = os.getcwd() + '/'
GSTD_QUOTA_FILE = APP_DIR + "baseline_quotas.txt" # Gold standard quotas for baseline.
RUNG_QUOTA_FILE = "/tmp/quotas.tmp" # Saved state on condition of quotas since last run
NOVA_CONF = "/home/cybera/dev/nova.conf" # nova.conf -- change for production.


class QuotaLogger:
	""" Logs events of interest """
	LOG_FILE = "/var/log/dair/quota-monitor.log" # log file
	def __init__(self):
		self.logger = logging.getLogger('quota-monitor')
		hdlr = logging.FileHandler(QuotaLogger.LOG_FILE)
		formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
		hdlr.setFormatter(formatter)
		logger.addHandler(hdlr) 
		logger.setLevel(logging.WARNING)

class ZoneInstance:
	def __init__(self):
		self.instances = {}
		
	def set_instance_count_per_project(self, which_quota, project_count):
		""" Used to populate all the projects' specific quota."""
		for project in project_count:
			project_instance = Quota()
			try:
				project_instance = self.instances[project]
			except KeyError: # no instances for this project logged yet.
				pass
			project_instance.set_quota(which_quota, project_count[project])
			self.instances[project] = project_instance
			print project_instance
			
	# this method accumulates all the zone_instance values.
	def __sum__(self, other_zone):
		"""Given another zone_instance add its values to this zone's values."""
		# zone_instance = {'project': Quota}, so for all the projects running...
		for project in self.instances.keys():
			other_resource = None
			try:
				other_resource = other_zone[project]
			except KeyError: # this project isn't using resources in other_zone.
				continue
			my_quota = self.instances[project]
			my_quota.__add__(other_resource)
			
			
		
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
		self.Q_PROJECT_INSTANCES = """ "select project_id, count(state) from instances where state=1 group by project_id;" """
		self.Q_PROJECT_GIGABYTES = """ "select project_id, sum(size) from volumes where attach_status=\\"attached\\" group by project_id;" """ # returns empty set not expected '0'
		self.Q_PROJECT_VOLUMES   = """ "select project_id, count(size) from volumes where attach_status=\\"attached\\" group by project_id;" """
		self.Q_PROJECT_FLOAT_IPS = """ "select project_id, count(deleted) from floating_ips where deleted=0 group by project_id;" """
		self.Q_PROJECT_CPUS      = """ "select project_id, sum(vcpus) from instances where state=1 group by project_id;" """
		self.regions = {} # {'full_name' = ip}
		self.instances = {} # {'full_name' = ZoneInstance}
		self.password = None
		# this requires two greps of the nova.conf file but could be done in one.
		# get the regions like: --region_list=alberta=208.75.74.10,quebec=208.75.75.10
		results = self.__execute_call__("grep region_list " + NOVA_CONF)
		results = results.split('region_list=')[1]
		# now split on the regions separated by a ','
		results = results.split(',')
		for result in results:
			name_value = result.split('=')
			self.regions[name_value[0].strip()] = name_value[1].strip() # gets rid of nagging newline
		# now the password --sql_connection=mysql://root:xxxxxxxxxxxxx@192.168.2.10/nova
		results = self.__execute_call__("grep sql_connection " + NOVA_CONF)
		self.password = results.split('root:')[1].split('@')[0] # yuck.
		#print self.password, self.regions
		
	def __execute_call__(self, command_and_args):
		""" returns the stdout of a Unix command """
		cmd = command_and_args.split()
		if len(cmd) < 1:
			return "<no cmd to execute>"
		process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
		return process.communicate()[0]
		
	def get_zone_resource_snapshots(self):
		for zone in self.regions.keys():
			# populate the zone's project instances
			zone_instance_data = ZoneInstance()
			self.__query_project_statuses__(zone, zone_instance_data)
			self.instances[zone] = zone_instance_data
		#print self.instances

	def __query_project_statuses__(self, zone, zone_project_instances):
		print "querying " + zone + " for instances..."
		ssh_cmd = "ssh root@" + self.regions[zone]
		sql_cmd_prefix = " 'mysql -uroot -p" + self.password + " nova -e "
		sql_cmd_suffix = "'"
		# for each quota run a query for the values currently in this zone.
		#print ssh_cmd + sql_cmd_prefix + self.Q_PROJECT_GIGABYTES + sql_cmd_suffix
		#cmd_result = __execute_call__(ssh_cmd + sql_cmd_prefix + self.Q_PROJECT_GIGABYTES + sql_cmd_suffix)
		# test data
		cmd_result = """"""
		if zone == 'quebec':
			cmd_result = """
			project_id	sum(size)
			1003unbc	10
			1007Benbria	20
			1009HeadwallSoftware	100
			1037Innovative	80
			1041STC	10
			1047VRStorm	10
			1143TransitHub	60
			AgoraMobile	176
			Mindr	110
			spawn	10
			"""
		else:
			# returns 'ab':
			cmd_result = """project_id	sum(size)
			1002Gnowit	240
			1012BiOS	300
			1016LiveReach3	35
			1037Innovative	20
			1041STC	10
			1042IgnitePlayBeta	10
			1045KiribatuRMS	200
			1047VRStorm	10
			1051BGPmon	170
			1052idQuanta	16
			1057TRLabs1	100
			1058iRok2	25
			1059InsideMapp	10
			1079ProjectWhiteCard	8
			1150Dyno	20
			Metafor	8
			moodle	30
			"""
		result_dict = self.__parse_query_result__(cmd_result)
		zone_project_instances.set_instance_count_per_project(Quota.G, result_dict)
		#print ssh_cmd + sql_cmd_prefix + self.Q_PROJECT_FLOAT_IPS + sql_cmd_suffix
		zone_project_instances.set_instance_count_per_project(Quota.F, result_dict)
		#print ssh_cmd + sql_cmd_prefix + self.Q_PROJECT_INSTANCES + sql_cmd_suffix
		zone_project_instances.set_instance_count_per_project(Quota.I, result_dict)
		#print ssh_cmd + sql_cmd_prefix + self.Q_PROJECT_VOLUMES + sql_cmd_suffix
		zone_project_instances.set_instance_count_per_project(Quota.V, result_dict)
		#print ssh_cmd + sql_cmd_prefix + self.Q_PROJECT_CPUS + sql_cmd_suffix
		zone_project_instances.set_instance_count_per_project(Quota.C, result_dict)
	
		
	def connection_is_open(self):
		return True
		
	def set_quotas(self, zone, quotas):
		pass
		
	def get_zones(self):
		""" Returns the names of the regions collected from nova.conf. """
		return self.regions.keys()
		
	def get_other_zones_current_resources(self, zone):
		"""
		Returns a ZoneInstance object of all projects in zones other
		than the named zone, and including project resource usage.
		"""
		#other_zones_resources = zoneManager.get_other_zones_current_resources(zone)
		other_zones_resources = ZoneInstance()
		for z in self.regions.keys():
			if z == zone:
				continue
			else:
				other_zones_resources.__sum__(self.instances[zone]) # add the project quotas from the other snapshot(s)
		return other_zones_resources
		
	def compute_zone_quotas(self, quotas, other_zones_resources):
		pass
		#new_quotas = zoneManager.compute_zone_quotas(quotas, other_zones_resources)
		
	def __parse_query_result__(self, table):
		""" 
		Takes a table output on stdout and returns it as a dictionary of 
		results project=value. 
		"""
		results = {}
		if len(table) < 1: # empty set test -- naive test fix me
			return results
		clean_table = table.strip()
		rows = clean_table.splitlines()
		# remove the first row which is the column titles from the query
		# or possibly an empty set message.
		rows.__delitem__(0)
		for row in rows:
			data = row.split()
			if len(data) == 2:
				results[data[0]] = string.atoi(data[1]) # project_id = [0], value = [1]
		return results
		
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
	This class represents a project's quotas and instances of current resource
	values within a zone. It also includes a flag to determine if the project 
	stackholders have been alerted to overquotas.
	"""
	fl = 'flags'
	M = ''
	G = 'gigabytes'
	F = 'floating_ips'
	I = 'instances'
	V = 'volumes'
	C = 'cores'
	
	def __init__(self, flags=0, meta=0, Gb=0, f_ips=0, insts=0, vols=0, cors=0, name=""):
		self.quota = {}
		self.project_name = name
		self.quota[Quota.fl] = flags # flags is currently if we have issued an email yet
		self.quota[Quota.M] = meta
		self.quota[Quota.G] = Gb
		self.quota[Quota.F] = f_ips
		self.quota[Quota.I] = insts
		self.quota[Quota.V] = vols
		self.quota[Quota.C] = cors
		
	# This function adds the values from another quota to this one.
	def __add__(self, quota):
		"""
		This method adds the values of quota to this quota object. It is used
		for calculating all the instances of resources within other zones.
		"""
		for quota_name in self.quota.keys():
			try:
				self.quota[quota_name] = self.quota[quota_name] + quota[quota_name]
			except KeyError:
				pass # mismatched quotas don't get added to this object that is
					 # a quota must exist in both quota objects for it to be added
	
	# reads lines from a file and if the values are '=' separated it will assign the named quota the '=' value.
	# WARNING: If the quota name is spelt incorrectly the default value is used.
	def set_values(self, values):
		""" 
		This method is used for reading in the original quota values for
		projects. This is the values that the project admins signed up for.
		parsing a string of 'name=value,' quotas. 
		"""
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
			log = QuotaLogger()
			msg = "quotas found for a project with no name."
			log.error(msg)
			raise QuotaException(msg)
		else:
			return project_name
			
	def set_quota(self, name, value):
		""" Stores a quota value. """
		self.quota[name] = value
		
	def get_quota(self, name):
		""" Returns a quota value or 0 if not found. """
		try:
			return self.quota[name]
		except KeyError:
			return 0
		
	def __str__(self):
		return repr("flags: %d, metadata_items: %d, gigabytes: %d, floating_ips: %d, instances: %d, volumes: %d, cores: %d" % \
		(self.quota[Quota.fl],
		self.quota[Quota.M],
		self.quota[Quota.G],
		self.quota[Quota.F],
		self.quota[Quota.I],
		self.quota[Quota.V],
		self.quota[Quota.C]))
		
	def is_over_quota(self):
		values = self.quotas.values()
		for value in values:
			if value < 0:
				return True
		return False
		
	def get_exceeded(self):
		"""Returns a list of quotas that have been exceeded. """
		return_str = ""
		for q in self.quota.keys():
			if self.quota[key] < 0:
				return_str = return_str + "%s " % (key)
		return return_str
		
	def get_project_name(self):
		"""Returns the name of the project that this quota belongs to."""
		return self.project_name
		
		
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
def read_baseline_quota_file():
	quotas = {}
	try:
		f = open(GSTD_QUOTA_FILE)
	except:
		log = QuotaLogger()
		msg = "No initial project quota values defined for projects. There should be a file here called %s." % (GSTD_QUOTA_FILE)
		log.error(msg)
		raise QuotaException(msg)
	
	line_no = 0
	for line in f.readlines():
		if line.strip() != "" and line[0] != "#":
			read_values = line.split(',') # read_values holds name=value pairs.
			line_no = line_no + 1
			# preset the quota values to defaults flags=0, meta=128, Gb=100, f_ips=10, insts=10, vols=10, cors=20.
			project_quota = Quota(0, 128, 100, 10, 10, 10, 20)
			name = None
			try:
				name = project_quota.set_values(read_values)
			except:
				log = QuotaLogger()
				msg = "Malformed quota file on line %d" % (line_no)
				log.error(msg)
				raise QuotaException(msg)
			# save the project's quotas from file
			quotas[name] = project_quota
		print quotas
		
# There has to be a way to reset the quotas to the baseline for all groups 
# in the case that there is a problem and the quotas get out of synch.
# This method does that.
# param: quotas = {'project': Quota}
def reset_quotas():
	""" 
	Reads the gold standard project quotas for projects and sets those
	values in each zone. This function does not balance zone quotas.
	"""
	print "resetting quotas..."
	quotas = read_baseline_quota_file()
	zoneManager = ZoneQueryManager()
	for zone in zoneManager.get_zones():
		zoneManager.set_quotas(zone, quotas) # everyone gets the same.
	return 0
	
def balance_quotas():
	"""
	Balances quotas. Run from cron this function runs once per preset time period.
	The formula is: 
		Qnow = Qbaseline - Iother_zones
	where
	Qnow: the quota for a specific but arbitrary zone at this cycle
	Qbaseline: the quota for the project assigned when the project was created
	Iother: the number of instances of a resource being consumed in all other zones.
	"""
	zoneManager = ZoneQueryManager() # this will now contain the regions and sql password
	if zoneManager.connection_is_open() == False: # TODO finish this method
		log = QuotaLogger()
		msg = "no connection to other zones"
		log.error(msg)
		return -2
		
	quotas = read_baseline_quota_file()	
	zoneManager.get_zone_resource_snapshots()
	for zone in zoneManager.get_zones():
		other_zones_resources = zoneManager.get_other_zones_current_resources(zone) ####### continue here #####
		#new_quotas = zoneManager.compute_zone_quotas(quotas, other_zones_resources)
		#zoneManager.set_quotas(zone, new_quotas)
		#if new_quotas.is_over_quota():
		#	log = QuotaLogger()
		#	msg = "project %s is over quota: %s in zone %s." % (new_quota.get_project_name(), new_quota.get_exceeded(), zone)
		#	log.warn(msg)
		#	email_stakeholders(msg)
	return 0
	

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
			return reset_quotas()
		elif o in ("-b", "--balance"):
			return balance_quotas()
		else:
			assert False, "unimplemented option '" + o + "'"


if __name__ == "__main__":
    sys.exit(main())
