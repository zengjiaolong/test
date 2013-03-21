%%%--------------------------------------
%%% @Module  : yg
%%% @Author  : ygzj
%%% @Created : 2010.10.05 
%%% @Description:  服务器开启  
%%%--------------------------------------
-module(yg).
-include("common.hrl").

-export(
	[
		gateway_start/0, 
		gateway_stop/0, 
		server_start/0, 
		server_stop/0, 
		server_remove/0, 
		info/0, 
		init_db/1,
		server_safe_quit/1,
		server_hot_fix/1
	]
).
-define(GATEWAY_APPS, [sasl, gateway]).
-define(SERVER_APPS, [sasl, server]).

%%启动网关
gateway_start()->
    try
        ok = start_applications(?GATEWAY_APPS)
    after
        timer:sleep(100)
    end.

%%停止网关
gateway_stop() ->
    ok = stop_applications(?GATEWAY_APPS).

%%游戏服务器
server_start()->
    try
        ok = start_applications(?SERVER_APPS)
    after
        timer:sleep(100)
    end.

%%停止游戏服务器
server_stop() ->
	%%首先关闭外部接入，然后停止目前的连接，等全部连接正常退出后，再关闭应用
	catch gen_server:cast(mod_kernel, {set_load, 9999999999}),
    ok = mod_login:stop_all(),
	timer:sleep(30*1000),
    ok = stop_applications(?SERVER_APPS),
    erlang:halt().

%%撤下节点
server_remove() ->
	%%首先关闭外部接入，然后停止目前的连接，等全部连接正常退出后，再关闭应用
	catch gen_server:cast(mod_kernel, {set_load, 9999999999}),
    ok = mod_login:kick_all(),
	timer:sleep(30*1000),
    ok = stop_applications(?SERVER_APPS),
    erlang:halt().

%%脚本执行safe_quit
server_safe_quit([GateWay])->
	catch net_adm:ping(GateWay),
	rpc:eval_everywhere([GateWay], misc_admin, safe_quit, [[]]),
	timer:sleep(30*1000),
	rpc:eval_everywhere([GateWay], erlang, halt, []),
	timer:sleep(10*1000),
	erlang:halt(),
	ok.

%%脚本执行热更新
server_hot_fix([GateWay])->
	catch net_adm:ping(GateWay),
	rpc:eval_everywhere([GateWay], u, c, [20]),
	rpc:eval_everywhere([GateWay], u, u, [20]),
	timer:sleep(5*1000),
	erlang:halt(),
	ok.

info() ->
    SchedId      = erlang:system_info(scheduler_id),
    SchedNum     = erlang:system_info(schedulers),
    ProcCount    = erlang:system_info(process_count),
    ProcLimit    = erlang:system_info(process_limit),
    ProcMemUsed  = erlang:memory(processes_used),
    ProcMemAlloc = erlang:memory(processes),
    MemTot       = erlang:memory(total),
    io:format( "abormal termination:
                       ~n   Scheduler id:                         ~p
                       ~n   Num scheduler:                        ~p
                       ~n   Process count:                        ~p
                       ~n   Process limit:                        ~p
                       ~n   Memory used by erlang processes:      ~p
                       ~n   Memory allocated by erlang processes: ~p
                       ~n   The total amount of memory allocated: ~p
                       ~n",
                            [SchedId, SchedNum, ProcCount, ProcLimit,
                             ProcMemUsed, ProcMemAlloc, MemTot]),
      ok.

%%############辅助调用函数##############
manage_applications(Iterate, Do, Undo, SkipError, ErrorTag, Apps) ->
    Iterate(fun (App, Acc) ->
                    case Do(App) of
                        ok -> [App | Acc];%合拢
                        {error, {SkipError, _}} -> Acc;
                        {error, Reason} ->
                            lists:foreach(Undo, Acc),
                            throw({error, {ErrorTag, App, Reason}})
                    end
            end, [], Apps),
    ok.

start_applications(Apps) ->
    manage_applications(fun lists:foldl/3,
                        fun application:start/1,
                        fun application:stop/1,
                        already_started,
                        cannot_start_application,
                        Apps).

stop_applications(Apps) ->
    manage_applications(fun lists:foldr/3,
                        fun application:stop/1,
                        fun application:start/1,
                        not_started,
                        cannot_stop_application,
                        Apps).
	
%%############数据库初始化##############
%% 数据库连接初始化
init_db(App) ->
%% init_mysql(App),
	case ?DB_MODULE == db_mysql of
		true ->
			init_mysql(App);
		_ ->
			init_mongo(App),%%加载主数据库
			init_log_mongo(App),%%加载日志数据库
			init_slave_mongo(App)  %%加载从数据库	
	end,	
	ok.

%% mysql数据库连接初始化
init_mysql(App) ->
	[Host, Port, User, Password, DB, Encode] = config:get_mysql_config(App),
    mysql:start_link(?DB_POOL, Host, Port, User, Password, DB,  fun(_, _, _, _) -> ok end, Encode),
    mysql:connect(?DB_POOL, Host, Port, User, Password, DB, Encode, true),
	misc:write_system_info({self(), mysql}, mysql, {Host, Port, User, DB, Encode}),
	ok.

%% monogo数据库连接初始化
init_mongo(App) ->
	try 
		[PoolId, Host, Port, DB, EmongoSize] = config:get_mongo_config(App),
		emongo_sup:start_link(),
		emongo_app:initialize_pools([PoolId, Host, Port, DB, EmongoSize]),
		misc:write_system_info({self(),mongo}, mongo, {PoolId, Host, Port, DB, EmongoSize}),
		ok
	catch
		_:_ -> mongo_config_error
	end.

%% monogo数据库连接初始化
init_log_mongo(App) ->
	try 
		[PoolId, Host, Port, DB, EmongoSize] = config:get_log_mongo_config(App),
		emongo_sup:start_link(),
		emongo_app:initialize_pools([PoolId, Host, Port, DB, EmongoSize]),
		misc:write_system_info({self(),mongo}, mongo, {PoolId, Host, Port, DB, EmongoSize}),
		ok
	catch
		_:_ -> mongo_config_error
	end.

%% monogo数据库连接初始化
init_slave_mongo(App) ->
	try 
		[PoolId, Host, Port, DB, EmongoSize] = config:get_slave_mongo_config(App),
		emongo_sup:start_link(),
		emongo_app:initialize_pools([PoolId, Host, Port, DB, EmongoSize]),
		misc:write_system_info({self(),mongo_slave}, mongo_slave, {PoolId, Host, Port, DB, EmongoSize}),
		ok
	catch
		_:_ -> init_mongo(App)%%没有配置从数据库就调用主数据库
	end.
