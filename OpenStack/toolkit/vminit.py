#!/usr/bin/env python
"""
A package of functions to initialise CESWP virtual machines.
	This isn't really ready for use, it's only been tested on Ubuntu, and 
	much of it won't even run on CentOS
"""

import os
import errno

def isRoot():
	return os.getuid() == 0

def installPackages(packages):
	print "updating apt-get sources..."
	os.system("apt-get update")

	for package in packages:
		print "installing",package
		#os.system("apt-get install -y", package)
	

def setHostname(new_hostname):
	f = open("/etc/hostname")
	old_hostname = f.readline().rstrip()
	f.close()

	print "changing hostname from '%s' to '%s'..." % (old_hostname, new_hostname)
	os.system("hostname %s" % new_hostname)

	files = ["/etc/hosts", "/etc/hostname"]
	for file in files:
		os.system("sed -i s/%s/%s/g %s" % (old_hostname, new_hostname, file))
	

def makedir(dir):
	try:
		os.makedirs(dir)
	except OSError as e:
		if e.errno != errno.EEXIST:
			raise
	

def addAccount(username, password, homedir="/home", sudo=True):
	print "creating user account '%s'" % username
	
	makedir(homedir)
	os.system("/usr/sbin/useradd " + \
			"--create-home " +  \
			"--home " + os.path.join(homedir, username) + " " + \
			"--shell /bin/bash " + username)	

	os.system("echo '" + password + "\n" + password + "' | passwd " + username)	
	os.system("chage --lastday 0 " + username)
	
	if sudo:
		os.system("usermod --groups admin " + username)
	

def deleteAccount(username):
	os.system("grep " + username + " /etc/passwd")
	os.system("/usr/sbin/userdel --remove " + username)
	os.system("grep " + username + " /etc/passwd")
	
def showConfig():
	print getPackageInstallCmd()

def main():
	showConfig()

if __name__ == "__main__":
	main()

