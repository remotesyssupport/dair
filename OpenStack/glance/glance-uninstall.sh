apt-get -y purge glance
MYSQL_USER=`grep sql_connection /etc/nova/nova.conf | cut -d '/' -f3 | cut -d ':' -f1`
MYSQL_PW=`grep sql_connection /etc/nova/nova.conf | cut -d ':' -f3 | cut -d '@' -f1`
mysql -u$MYSQL_USER -p$MYSQL_PW -e "DROP DATABASE glance;"
