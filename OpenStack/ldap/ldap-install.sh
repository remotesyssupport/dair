#!/bin/bash

#Setup the environment
HOSTNAME=`hostname`
ABS_PATH=`dirname "$(cd "${0%/*}" 2>/dev/null; echo "$PWD"/"${0##*/}")"`

if [ ! -f $ABS_PATH/ldap-env ]; then
	cp $ABS_PATH/ldap-env.template $ABS_PATH/ldap-env
	
	vi $ABS_PATH/ldap-env
fi

. $ABS_PATH/ldap-env

apt-get update
apt-get -y install slapd ldap-utils gnutls-bin ssl-cert python-ldap

sed -i "s/dc=example,dc=com/${DOMAIN}/g" $ABS_PATH/backend.ldif $ABS_PATH/frontend.ldif $ABS_PATH/ldap.conf $ABS_PATH/ldap-test-starttls.py $ABS_PATH/nova.ldif $ABS_PATH/slapd.conf
sed -i "s/ldap_pw/${LDAP_PW}/g" $ABS_PATH/backend.ldif $ABS_PATH/frontend.ldif $ABS_PATH/ldap-test-starttls.py $ABS_PATH/slapd.conf
sed -i "s/org_name/${ORG_NAME}/g" $ABS_PATH/frontend.ldif

ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/ldap/schema/cosine.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/ldap/schema/nis.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/ldap/schema/inetorgperson.ldif
ldapadd -Y EXTERNAL -H ldapi:/// -f $ABS_PATH/backend.ldif
ldapadd -x -D cn=admin,${DOMAIN} -w ${LDAP_PW} -f $ABS_PATH/frontend.ldif

certtool --generate-privkey > /etc/ssl/private/${HOSTNAME}_ldap_cakey.pem

cat >/etc/ssl/${HOSTNAME}_ldap_ca.info <<CA_INFO_EOF
cn = ${ORG_NAME}
expiration_days = 3650
ca
cert_signing_key
CA_INFO_EOF

certtool --generate-self-signed --load-privkey /etc/ssl/private/${HOSTNAME}_ldap_cakey.pem --template  /etc/ssl/${HOSTNAME}_ldap_ca.info --outfile /etc/ssl/certs/${HOSTNAME}_ldap_cacert.pem
certtool --generate-privkey > /etc/ssl/private/${HOSTNAME}_slapd_key.pem

cat >/etc/ssl/${HOSTNAME}_ldap_cert.info <<CERT_INFO_EOF
organization = ${ORG_NAME}
cn = ${HOSTNAME}
expiration_days = 3650
tls_www_server
encryption_key
signing_key
CERT_INFO_EOF

certtool --generate-certificate --load-privkey /etc/ssl/private/${HOSTNAME}_slapd_key.pem --load-ca-certificate /etc/ssl/certs/${HOSTNAME}_ldap_cacert.pem --load-ca-privkey /etc/ssl/private/${HOSTNAME}_ldap_cakey.pem --template /etc/ssl/${HOSTNAME}_ldap_cert.info --outfile /etc/ssl/certs/${HOSTNAME}_slapd_cert.pem

cp $ABS_PATH/modify.ldif.template $ABS_PATH/modify.ldif
sed -i "s/hostname/${HOSTNAME}/g" $ABS_PATH/modify.ldif

ldapmodify -Y EXTERNAL -H ldapi:/// -f $ABS_PATH/modify.ldif

sed -i "s#ldapi:///#ldapi:/// ldaps:///#g" /etc/default/slapd

adduser openldap ssl-cert
chgrp ssl-cert /etc/ssl/private/${HOSTNAME}_slapd_key.pem
chmod g+r /etc/ssl/private/${HOSTNAME}_slapd_key.pem

/etc/init.d/slapd restart

# install the nova stuff
$ABS_PATH/ldap-nova-install.sh

# undo the changes so SVN doesn't see them as modifications
sed -i "s/${DOMAIN}/dc=example,dc=com/g"  $ABS_PATH/backend.ldif $ABS_PATH/frontend.ldif $ABS_PATH/ldap.conf $ABS_PATH/nova.ldif $ABS_PATH/slapd.conf
sed -i "s/${LDAP_PW}/ldap_pw/g" $ABS_PATH/backend.ldif $ABS_PATH/frontend.ldif $ABS_PATH/slapd.conf
sed -i "s/${ORG_NAME}/org_name/g" $ABS_PATH/frontend.ldif
