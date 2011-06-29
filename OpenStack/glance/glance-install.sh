apt-get -q -y install python-software-properties
apt-key adv --keyserver keyserver.ubuntu.com --recv 460DF9BE
add-apt-repository 'deb http://packages.ansolabs.com/ maverick main'
add-apt-repository ppa:swift-core/ppa
apt-get update
apt-get -y install python-mysqldb
apt-get -y -t maverick install nova-common glance swift
MYSQL_CONN=`grep sql_conn /etc/nova/nova.conf | sed 's/--//' | sed 's/nova/glance/'`
MYSQL_USER=`echo $MYSQL_CONN | cut -d '/' -f3 | cut -d ':' -f1`
MYSQL_PW=`echo $MYSQL_CONN | cut -d ':' -f3 | cut -d '@' -f1`
mysql -u$MYSQL_USER -p$MYSQL_PW -e "CREATE DATABASE glance;"
sed -i "s;sql_conn.\+;$MYSQL_CONN;" /etc/glance/glance.conf
restart glance-api
restart glance-registry
grep -i ERROR /var/log/glance/*
