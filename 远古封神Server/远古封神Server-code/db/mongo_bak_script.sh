#!/bin/bash

DATETIME=`date "+%Y%m%d%H%M%S"`
chmod 777 /data/*

echo 'Backup start...'
/usr/local/mongodb/bin/mongodump -d ygfs -o /data/mongodb_bak/${DATETIME}

echo 'Backup finish...'
