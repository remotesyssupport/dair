#!/bin/bash

ABS_PATH=`dirname "$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"`

cp $ABS_PATH/openssh-lpk_openldap.schema /etc/ldap/schema/openssh-lpk_openldap.schema
cp $ABS_PATH/nova_openldap.schema /etc/ldap/schema/nova.schema

cp $ABS_PATH/slapd.conf /etc/ldap/
cp $ABS_PATH/ldap.conf /etc/ldap/

/etc/init.d/slapd stop
slaptest -f /etc/ldap/slapd.conf -F /etc/ldap/slapd.d
chown -R openldap:openldap /etc/ldap/slapd.d
chown -R openldap:openldap /var/lib/ldap
slapadd -v -l $ABS_PATH/nova.ldif
/etc/init.d/slapd start

