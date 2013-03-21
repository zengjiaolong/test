#!/bin/bash

cd /data/www/ygzj/html/flash
svn cat svn://113.107.160.8/ygzj/code/www/ygzj/html/flash/main.swf > main.swf
svn cat svn://113.107.160.8/ygzj/code/www/ygzj/html/flash/GameLoader.swf > GameLoader.swf

cd /data/www/ygzj/html/flash/assets
svn update

cd /data/www/ygzj/html/admin
svn update

cd /data/www/ygzj/php
svn update

echo 'UPDATE ygzj_www finish.'
