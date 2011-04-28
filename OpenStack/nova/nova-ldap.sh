#! /bin/sh
# Restart the ssh tunnel so LDAP traffic to Nova is always encrypted

set -e

if [ "$IFACE" = eth0 ]; then
	ssh -i /root/.ssh/nova_ldap_key -g -f -N -L 1389:localhost:389 PRIMARY_CC_HOST_IP
	exit 0
fi

exit 0
