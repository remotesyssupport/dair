#!/usr/bin/env python
import sqlalchemy
import json
import web
import re

# Performs database queries across all zones and returns total, used and
# available resources for each compute node plus the cumulative totals
# for each zone

web.config.debug = False
urls = ('/', 'CloudResources')
app = web.application(urls, globals())

class CloudResources:
	def GET(self):
		return self.get_resources()

	def get_db_string(self):
		with open('/etc/nova/nova.conf', 'r') as f:
			for line in f:
				if line.startswith('--sql_connection'):
					return line.strip().split('=', 1)[1]

	def get_resources(self):
		engine = sqlalchemy.create_engine(self.get_db_string())
		conn = engine.connect()
	
		node_usage = conn.execute("SELECT s.host,c.vcpus,c.vcpus_used,c.vcpus-c.vcpus_used AS vcpus_avail, \
		c.memory_mb,c.memory_mb_used,c.memory_mb-c.memory_mb_used AS memory_mb_avail \
		FROM compute_nodes AS c \
		INNER JOIN services AS s ON c.service_id=s.id \
		WHERE s.binary='nova-compute' AND s.deleted=0 AND s.disabled=0")
	
		total_usage = conn.execute("SELECT CAST(SUM(c.vcpus) AS SIGNED) AS vcpus, \
		CAST(SUM(c.vcpus_used) AS SIGNED) AS vcpus_used,CAST(SUM(c.vcpus)-SUM(c.vcpus_used) AS SIGNED) \
		AS vcpus_avail,CAST(SUM(c.memory_mb) AS SIGNED) AS memory_mb,CAST(SUM(c.memory_mb_used) AS SIGNED) \
		AS memory_mb_used,CAST(SUM(c.memory_mb)-SUM(c.memory_mb_used) AS SIGNED) AS memory_mb_avail \
		FROM compute_nodes AS c \
		INNER JOIN services AS s ON c.service_id=s.id \
		WHERE s.binary='nova-compute' AND s.deleted=0 AND s.disabled=0")

		resources = {}
	
		for row in node_usage:
			resources[row['host']] = dict(row.items())
			del resources[row['host']]['host']
	
		resources['total'] = dict(total_usage.first().items())
	
		node_usage.close()
		total_usage.close()
		conn.close()
		
		return json.dumps(resources) 

if __name__ == '__main__':
	app.run()
