echo off

cd ..

mkdir temp

cd temp

mkdir include 

erlc -I ../include/ ../src/lib/mysql/mysql_auth.erl  ../src/lib/mysql/mysql_conn.erl ../src/lib/mysql/mysql_recv.erl  ../src/lib/mysql/mysql.erl  ../src/lib/erlydb/erlsql.erl ../src/lib/erlydb/erlydb.erl ../src/lib/erlydb/erlydb_base.erl ../src/lib/erlydb/erlydb_field.erl ../src/lib/erlydb/erlydb_mysql.erl ../src/lib/erlydb/smerl.erl ../src/lib/db_sql.erl ../src/misc/tool.erl ../src/test/table_to_record.erl 
werl +P 1024000 -smp disabled -name ygzj_tool@127.0.0.1 -s table_to_record start
echo 开始生成【../src/lib/lib_player_rw.erl】
erlc -I ../include/ ../src/test/record_to_code.erl
werl +P 1024000 -smp disable -name ygzj_tool@127.0.0.1 -s record_to_code start


