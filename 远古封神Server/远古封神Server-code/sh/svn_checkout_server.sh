#!/bin/bash

#cd /data/www/ygzj/html/flash
#svn cat svn://113.107.160.8/ygzj/code/www/ygzj/html/flash/main.swf > main.swf

#cd /data/www/ygzj/html/flash/assets
#svn update

#cd /data/www/ygzj/html/admin
#svn update

#cd /data/www/ygzj/php
#svn update

ROOT_DD='/data/erlang/ygzj/'
DATETIME=`date "+%Y%m%d%H%M%S"`
cd ${ROOT_DD}

svn update
chmod 777 *

./sh/make.sh

#将生成的静态数据加入版本控制
cd /data/erlang/ygzj/src/data
svn add * --force
svn ci -m "new base data version"

echo 'UPDATE finish.'

SVN_PATH="/usr/local/svn/bin"

cd /data/erlang/ygzj/logs
mkdir $DATETIME
mv *.log $DATETIME
/bin/tar zcvf $DATETIME.tar.gz $DATETIME >/dev/null 2>&1
rm -rf $DATETIME/*
mv $DATETIME.tar.gz $DATETIME/
echo 'Backup logs finished.'
