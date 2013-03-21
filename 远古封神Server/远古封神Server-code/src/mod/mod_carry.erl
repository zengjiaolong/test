%% Author: hxming
%% Created: 2010-10-28
%% Description: TODO: Add description to mod_carry
-module(mod_carry).
%%
%% Include files
%%
-behaviour(gen_server).

%%
%% Exported Functions
%%
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-export(
   	[
		start_link/1, 
		start/0,
		stop/0,
		get_mod_carry_pid/0
	]
).

-include("common.hrl").
-include("record.hrl").

%% 定时器间隔时间
-define(INTERVAL, 10000).

%% 启动国运服务
start_link([ProcessName, Worker_id]) ->
     gen_server:start_link({local, ?MODULE}, ?MODULE, [ProcessName, Worker_id], []).

start() ->
    gen_server:start(?MODULE, [], []).

%% 停止服务
stop() ->
    gen_server:call(?MODULE, stop).

%% 动态加载国运处理进程 
get_mod_carry_pid() ->
	ProcessName = misc:create_process_name(mod_carry_process, [0]),
	case misc:whereis_name({global, ProcessName}) of
		Pid when is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true -> Pid;
				false -> 
					start_mod_carry(ProcessName)
			end;
		_ ->
			start_mod_carry(ProcessName)
	end.

%% 启动国运监控模块 (加锁保证全局唯一)
start_mod_carry(ProcessName) ->
	global:set_lock({ProcessName, undefined}),	
	ProcessPid =
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> Pid;
					false -> 
						start_carry(ProcessName)
				end;
			_ ->
				start_carry(ProcessName)
		end,	
	global:del_lock({ProcessName, undefined}),
	ProcessPid.

%% 开启国运监控模块
start_carry(ProcessName) ->
    case supervisor:start_child(
               yg_server_sup,
               {mod_carry,
                {mod_carry, start_link,[[ProcessName,0]]},
                permanent, 10000, supervisor, [mod_carry]}) of
		{ok, Pid} ->
				timer:sleep(1000),
				Pid;
		_ ->
				undefined
	end.

%%
%% Local Functions
%%
init([ProcessName, Worker_id]) ->
    process_flag(trap_exit, true),	
	case misc:register(unique, ProcessName, self()) of
		yes ->
			if 
				Worker_id =:= 0 ->
					erlang:send_after(?INTERVAL, self(), {sys}),
					misc:write_monitor_pid(self(), mod_carry, {}),
					misc:write_system_info(self(), mod_carry, {});
				true->
			 		misc:write_monitor_pid(self(), mod_carry_child, {Worker_id})
			end,
			io:format("2.Init mod_carry finish!!!~n"),
    		{ok, []};
		_ ->
			{stop,normal,[]}
	end.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

%% 国运系统广播
%% 国运时间与跑商双倍时间不能一样
handle_info({sys}, State) ->
	NowSec = util:get_today_current_second(),
	INTERVAL =
		if 
			NowSec > ?CARRY_BC_START_CHANGE andalso NowSec < ?CARRY_BC_END_CHANGE ->
				broadcast_sys_msg(NowSec),
				?INTERVAL;
			NowSec > ?BUSINESS_DOUBLE_START_CHANGE andalso NowSec < ?BUSINESS_DOUBLE_END_CHANGE ->
				case util:get_date() of
					7 ->
						broadcast_business_msg(NowSec),
						?INTERVAL;
					_ ->
						60000
				end;
	   		true ->
				60000
		end,
	erlang:send_after(INTERVAL, self(), {sys}),
	{noreply,State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% 部落国运时间广播
broadcast_carry_time(Timestamp)->
	{ok, BinData} = pt_30:write(30300, [1,1,Timestamp]),
	mod_disperse:broadcast_to_world(ets:tab2list(?ETS_SERVER), BinData),
	lib_send:send_to_local_all(BinData).

%% 跑商双倍时间广播
broadcast_business_time(Result, Timestamp)->
	{ok, BinData} = pt_30:write(30702, [Result, Timestamp]),
	mod_disperse:broadcast_to_world(ets:tab2list(?ETS_SERVER), BinData),
	lib_send:send_to_local_all(BinData).

%%广播国运系统消息
broadcast_sys_msg(NowSec)->
	if  
		(NowSec >= ?CARRY_BC_START_THREE) andalso (NowSec - ?CARRY_BC_START_THREE) =< 10 ->
			Msg = "<font color='#FEDB4F'>全体部落国运三倍运镖活动将会在3分钟后开启,欢迎诸神共同参与！</font>";
		(NowSec >= ?CARRY_BC_START_ONE) andalso (NowSec - ?CARRY_BC_START_ONE) =< 10 ->
			Msg = "<font color='#FEDB4F'>全体部落国运三倍运镖活动将会在1分钟后开启,欢迎诸神共同参与！</font>";
		(NowSec >= ?CARRY_BC_START) andalso (NowSec - ?CARRY_BC_START) =< 10 ->
			broadcast_carry_time(1200),
			Msg = "<font color='#FEDB4F'>全体部落国运三倍运镖活动开启,欢迎诸神共同参与！</font>";
		(NowSec >= ?CARRY_BC_END_THREE) andalso (NowSec - ?CARRY_BC_END_THREE) =< 10 ->
			Msg = "<font color='#FEDB4F'>全体部落国运三倍运镖活动将会在3分钟后关闭！</font>";
		(NowSec >= ?CARRY_BC_END_ONE) andalso (NowSec - ?CARRY_BC_END_ONE) =< 10 ->
			Msg = "<font color='#FEDB4F'>全体部落国运三倍运镖活动将会在1分钟后关闭！</font>";
		(NowSec >= ?CARRY_BC_END) andalso (NowSec - ?CARRY_BC_END) < 10 ->
			broadcast_carry_time(0),
			Msg = "<font color='#FEDB4F'>全体部落国运三倍运镖活动已经结束,感谢大家的参与！</font>";
		true->Msg=[]
	end,
	case Msg of
		[] -> 
			skip;
		_ ->
			lib_chat:broadcast_sys_msg(2, Msg)
	end.

%%跑商广播系统消息
broadcast_business_msg(NowSec)->
	if 
		(NowSec >= ?BUSINESS_DOUBLE_BROAD_TIME) andalso ((NowSec - ?BUSINESS_DOUBLE_BROAD_TIME) =< 10) ->
			Msg = "<font color='#FEDB4F'>全体部落跑商双倍活动将会在3分钟后开启,欢迎诸神共同参与！</font>";
		(NowSec >= ?BUSINESS_DOUBLE_START_TIME) andalso ((NowSec - ?BUSINESS_DOUBLE_START_TIME) =< 10) ->
			broadcast_business_time(1, ?BUSINESS_DOUBLE_END_TIME - NowSec),
			Msg = "<font color='#FEDB4F'>全体部落跑商双倍活动开启,欢迎诸神共同参与！</font>";
		(NowSec >= ?BUSINESS_DOUBLE_END_TIME) andalso ((NowSec - ?BUSINESS_DOUBLE_END_TIME) =< 10) ->
			broadcast_business_time(0, 0),
			Msg = "<font color='#FEDB4F'>全体部落跑商双倍活动已经结束,感谢大家的参与！</font>";
		true->
			Msg = []
	end,
	case Msg of
		[] ->
			skip;
		_ ->
			lib_chat:broadcast_sys_msg(2, Msg)
	end.
