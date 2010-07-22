#!/bin/bash
# cleanup everything to repeat testing.

set -e
set -u

# confluence 
/etc/init.d/confluence stop
/usr/local/confluence/confluence/bin/shutdown.sh

rm /etc/init.d/confluence
rm -rf /usr/local/confluence
rm -rf /usr/local/confluence-3.3-std/
rm -rf /usr/local/confluenct-data

# mysql
mysqladmin drop confluence
service stop mysql
yum remove mysql-server
yum remove mysql
