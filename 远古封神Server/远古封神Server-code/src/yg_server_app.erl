%%%-----------------------------------
%%% @Module  : yg_server_app
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 游戏服务器应用启动
%%%-----------------------------------
-module(yg_server_app).
-behaviour(application).
-export([start/2, stop/1]).
-include("common.hrl").
-include("record.hrl").

start(normal, []) ->	
	ping_gateway(),
	Tabs = [?ETS_SYSTEM_INFO,?ETS_MONITOR_PID,?ETS_STAT_SOCKET,?ETS_STAT_DB],
	init_ets(Tabs),	
	[Port, Node_id, _Acceptor_num, _Max_connections] = config:get_tcp_listener(server),
	[Ip] = config:get_tcp_listener_ip(server),
	Log_level = config:get_log_level(server),
	loglevel:set(tool:to_integer(Log_level)),	
    {ok, SupPid} = yg_server_sup:start_link(),
	yg_timer:start(yg_server_sup),
    yg_server:start(
	  			[Ip, tool:to_integer(Port), tool:to_integer(Node_id)]
				),
    {ok, SupPid}.
  
stop(_State) ->   
    void. 

ping_gateway()->
	case config:get_gateway_node(server) of
		undefined -> no_action;
		Gateway_node ->	
			catch net_adm:ping(Gateway_node)
	end.

init_ets([])->
	ok;
init_ets([Tab|L]) ->
	ets:new(Tab, [set, public, named_table,?ETSRC, ?ETSWC]),
	init_ets(L).

