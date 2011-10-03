#! /usr/bin/env python

#################################################################
# File:     quota-monitor.py
# Purpose:  Aggregate and balance quotas over zones in OpenStack 
# Author:   Andrew Nisbet andrew.nisbet@cybera.ca
# Date:     October 3, 2011
# Version:  0.1 - Dev. Not ready for initial release. 
#################################################################

import sys
import getopt       # Command line processing.
import string

GSTD_QUOTA_FILE = "./baseline_quotas.txt" # Gold standard quotas for baseline.
QUOTA_FILE = "./quotas.tmp" # Saved state on condition of quotas since last run
PROJECT_QUOTAS = {}

# metadata_items: 128
# gigabytes: 100
# floating_ips: 5
# instances: 5
# volumes: 5
# cores: 10

# Open the qotas for each project. This is a gold standard file since once this
# script runs the quotas are dynamically changed as over time.

class ProjectQuota:

			
	def __init__(self, meta=128, Gb=1000, f_ips=10, insts=10, vols=10, cors=10):
		self.quota = {}
		self.quota['metadata_items'] = meta
		self.quota['gigabytes'] = Gb
		self.quota['floating_ips'] = f_ips
		self.quota['instances'] = insts
		self.quota['volumes'] = vols
		self.quota['cores'] = cors
	
	# reads lines from a file and if the values are '=' separated it will assign the named quota the '=' value.
	# WARNING: If the quota name is spelt incorrectly the default value is used.
	def set_values(self, values):
		project_name = ""
		for value in values:
			name = value.split('=')[0].strip()
			vs = value.split('=')[1].strip()
			if name == 'project':
				project_name = vs
			else:
				vs = string.atoi(vs)
				self.quota[name] = vs # possible to set a quota that doesn't exist by misspelling its name
			print "name = " + name + " value = " + str(vs)
		PROJECT_QUOTAS[project_name] = self
		
	def __str__(self):
		return repr("metadata_items: %d, gigabytes: %d, floating_ips: %d, instances: %d, volumes: %d, cores: %d" % \
		(self.quota['metadata_items'],
		self.quota['gigabytes'],
		self.quota['floating_ips'],
		self.quota['instances'],
		self.quota['volumes'],
		self.quota['cores']))
		
# The baseline quota file should look like this:
# project=name,
def read_baseline_quota_file():
	try:
		f = open(GSTD_QUOTA_FILE)
	except:
		raise QuotaException("No initial project quota values defined for projects. There should be a file here called %s." % (GSTD_QUOTA_FILE))
	
	line_no = 0
	for line in f.readlines():
		read_values = line.split(',') # read_values holds name=value pairs.
		line_no = line_no + 1
		pq = ProjectQuota()
		#try:
		pq.set_values(read_values)
		#except:
		#	raise QuotaException("Malformation on line %d" % (line_no))
		print pq
	return True
		
def reset_quotas():
	print "resetting quotas..."
	read_baseline_quota_file()
		
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
        opts, args = getopt.getopt(sys.argv[1:], "hr", ["help","reset"])
    except getopt.GetoptError, err:
        print str(err)
        print usage()
        sys.exit(2)
    verbose = False
    for o, a in opts:
        if o in ("-h", "--help"):
            print usage()
            return 1
        elif o in ("-r", "--reset"):
			return reset_quotas()
        else:
            assert False, "unimplemented option '" + o + "'"


if __name__ == "__main__":
    sys.exit(main())
