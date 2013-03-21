#!/bin/bash

ROOT_DD='/data/erlang/ygzj/'
cd ${ROOT_DD}

rm -f ./ebin/*.beam
erl -make

cd ebin
erl -s mysql_to_emongo start_base
cd ..

echo -e "\t$(svn info | grep "Revision")" >$ROOT_DD/ebin/ygzj_version
echo -e "\t$(svn info | grep "Last Changed Dat")" >>$ROOT_DD/ebin/ygzj_version
