%%%-----------------------------------
%%% @Module  : yg_gateway_app
%%% @Author  : ygzj
%%% @Created : 2010.08.18
%%% @Description: 启动网关应用
%%%-----------------------------------
-module(yg_gateway_app).
-behaviour(application).
-export([start/2, stop/1]).   
-include("common.hrl"). 

start(_Type, _Args) ->
	ets:new(?ETS_SYSTEM_INFO, [set, public, named_table,?ETSRC, ?ETSWC]),
	ets:new(?ETS_MONITOR_PID, [set, public, named_table,?ETSRC, ?ETSWC]),
	ets:new(?ETS_STAT_SOCKET, [set, public, named_table,?ETSRC, ?ETSWC]),
	ets:new(?ETS_STAT_DB, [set, public, named_table,?ETSRC, ?ETSWC]),
	
	[Port, Node_id, _Acceptor_num, _Max_connections] = config:get_tcp_listener(gateway),
	[Ip] = config:get_tcp_listener_ip(gateway),

	Log_level = config:get_log_level(gateway), 
	loglevel:set(tool:to_integer(Log_level)),	
	
	yg:init_db(gateway),
	%%gateway启动5秒后将所有玩家的在线标志为0
	timer:apply_after(5000, db_agent, init_player_online_flag, []),
    yg_gateway_sup:start_link([Ip, tool:to_integer(Port), tool:to_integer(Node_id)]),
	yg_timer:start(yg_gateway_sup).



  
stop(_State) ->   
    void.
