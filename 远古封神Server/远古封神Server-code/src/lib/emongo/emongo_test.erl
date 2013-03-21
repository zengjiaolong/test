%%%---------------------------------------------
%%% @Module  : emongo_test
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: mysql测试
%%%---------------------------------------------
-module(emongo_test).
-compile(export_all).
-define(DB, mysql_conn_poll).
-define(DB_HOST, "localhost").
-define(DB_PORT, 3386).
-define(DB_USER, "root").
-define(DB_PASS, "root").
-define(DB_NAME, "ygzj").
-define(DB_ENCODE, utf8).



%conn()->
%%     mysql:start_link(?DB, ?DB_HOST, ?DB_PORT, ?DB_USER, ?DB_PASS, ?DB_NAME, fun(_, _, _, _) -> ok end, ?DB_ENCODE),
%%     mysql:connect(?DB, ?DB_HOST, ?DB_PORT, ?DB_USER, ?DB_PASS, ?DB_NAME, ?DB_ENCODE, true),
%    mysql:fetch(?DB, <<"drop table if exists test">>),
%    mysql:fetch(?DB, <<"create table test (id int not null auto_increment,row varchar(50) not null,r int not null, primary key (id)) engine = myisam">>),
%%     mysql:fetch(?DB, <<"truncate table test">>),
%%     ok.

%% test() ->
%%     mysql:fetch(?DB, <<"truncate table test">>),
%%     mysql:fetch(?DB, <<"begin">>),
%%     F = fun() ->
%%         db_sql:execute(io_lib:format(<<"insert into  `test` (`row`,`r`) values ('~s',~p)">>,["我是来测试性能的",123])),
%%         db_sql:execute(io_lib:format(<<"update  `test` set  `row` = '~s' where id = ~p">>,["我是来测试性能的",1]))
%% %        mysql:fetch(?DB, io_lib:format(<<"insert into  `test` (`row`,`r`) values ('~s',~p)">>,["我是来测试性能的",123]))
%%     end,
%%     prof:run(F, 10000),
%%     mysql:fetch(?DB, <<"commit">>),

%    mysql:fetch(?DB, <<"begin">>),
%
%    F1 = fun() ->
%        mysql:fetch(?DB, io_lib:format(<<"update  `test` set  `row` = '~s' where id = ~p">>,["我是来测试性能的",123]))
%    end,
%    prof:run(F1, 10000),
%    mysql:fetch(?DB, <<"commit">>),
%
%    F2 = fun() ->
%        mysql:fetch(?DB, <<"select * from  `test` where id = 1">>)
%    end,
%    prof:run(F2, 10000),

%% ok.

