%%%---------------------------------------------
%%% @Module  : mysql_test
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: mysql测试
%%%---------------------------------------------
-module(mysql_test).
-compile(export_all).
-define(DB, mysql_conn_poll).
-define(DB_HOST, "localhost").
-define(DB_PORT, 3386).
-define(DB_USER, "root").
-define(DB_PASS, "root").
-define(DB_NAME, "ygzj").
-define(DB_ENCODE, utf8).


conn()->
    mysql:start_link(?DB, ?DB_HOST, ?DB_PORT, ?DB_USER, ?DB_PASS, ?DB_NAME, fun(_, _, _, _) -> ok end, ?DB_ENCODE),
    mysql:connect(?DB, ?DB_HOST, ?DB_PORT, ?DB_USER, ?DB_PASS, ?DB_NAME, ?DB_ENCODE, true),
%    mysql:fetch(?DB, <<"drop table if exists test">>),
%    mysql:fetch(?DB, <<"create table test (id int not null auto_increment,row varchar(50) not null,r int not null, primary key (id)) engine = myisam">>),
    mysql:fetch(?DB, <<"truncate table test">>),
    ok.

test() ->
    mysql:fetch(?DB, <<"truncate table test">>),
    mysql:fetch(?DB, <<"begin">>),
    F = fun() ->
        db_sql:execute(io_lib:format(<<"insert into  `test` (`row`,`r`) values ('~s',~p)">>,["我是来测试性能的",123])),
        db_sql:execute(io_lib:format(<<"update  `test` set  `row` = '~s' where id = ~p">>,["我是来测试性能的",1]))
%        mysql:fetch(?DB, io_lib:format(<<"insert into  `test` (`row`,`r`) values ('~s',~p)">>,["我是来测试性能的",123]))
    end,
    prof:run(F, 10000),
    mysql:fetch(?DB, <<"commit">>),

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

ok.

%%测试获取时间的性能 （使用系统内置函数)
test_time(N)->
	Now = unixtime(),
	time_count(N,Now).

time_count(0,Bt)->
	Now = unixtime(),
	io:format("--~p~n",[Now - Bt]);

time_count(N,Bt)->
	unixtime(),
	time_count(N-1,Bt).

unixtime()->
	{M, S, _} = erlang:now(),
    M * 1000000 + S.

%%测试获取时间的性能 （使用ets)
test_time2(N) ->
	Now = util:unixtime(),
	time_count2(N,Now).

time_count2(0,Bt)->
	Now = util:unixtime(),
	io:format("--~p~n",[Now - Bt]);

time_count2(N,Bt) ->
	util:unixtime(),
	time_count2(N-1,Bt).