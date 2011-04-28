#!/bin/bash

nova-manage user create the-rand-corp-admin
nova-manage project create the-rand-corp the-rand-corp-admin

# the-rand-corp-admin gets the projectmanager role by default
nova-manage role add the-rand-corp-admin netadmin the-rand-corp


