#!/usr/bin/env python

import os
import sys
import ldap
import ConfigParser

class FakeSection(object):
    def __init__(self, fp):
        self.fp = fp
        self.section = '[section]\n'
    def readline(self):
        if self.section:
            try: return self.section
            finally: self.section = None
        else: return self.fp.readline()

config = ConfigParser.SafeConfigParser()
config.readfp(FakeSection(open(os.path.dirname(__file__) + '/ldap-env')))

admin = 'cn=admin,' + config.get('section', 'domain')
password = config.get('section', 'ldap_pw')

ldap.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_NEVER) # set because hostname does not match CN in peer certificate 

l = ldap.initialize("ldap://localhost:389")
l.set_option(ldap.OPT_PROTOCOL_VERSION, 3)
l.set_option(ldap.OPT_X_TLS,ldap.OPT_X_TLS_DEMAND)

try:
    l.start_tls_s()
    l.simple_bind_s(admin, password)
except ldap.INVALID_CREDENTIALS:
    print "Your username or password is incorrect."
    sys.exit()
except ldap.LDAPError, e:
    print(e)
    sys.exit()

print(l.whoami_s())
print("StartTLS succeeded!")

