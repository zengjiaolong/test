%% Author: hxming
%% Created: 2011-2-18
%% Description: TODO: 玩家委托任务处理模块
-module(mod_consign).

-behaviour(gen_server).
-include("common.hrl").
-include("record.hrl").
%%
%% Exported Functions
%%
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-export([start_link/1, 
		 start/0,
		 stop/0,
		 get_mod_consign_pid/0
		 ]).
-export([check_consign_task/2,
		 publish_consign_task/1,
		 accept_consign_task/1,
		 finish_consign_task/1,
		 get_consign_task/1,
		 get_consign_task_by_accept/2,
		 reset_consign_task/1
		 ]).

-define(TIMER_1, 60000).
%%
%% API Functions
%%
%% 启动委托任务服务
start_link([ProcessName, Worker_id]) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [ProcessName, Worker_id], []).

start() ->
    gen_server:start(?MODULE, [], []).

%%停止服务
stop() ->
    gen_server:call(?MODULE, stop).

%%查询委托任务
check_consign_task(PlayerStatus,ConsignInfo)->
	gen_server:cast(mod_consign:get_mod_consign_pid(), {'consign_task', [PlayerStatus,ConsignInfo]}).

%%发布委托任务
publish_consign_task(TaskBag)->
	gen_server:cast(mod_consign:get_mod_consign_pid(), {'publish_task', [TaskBag]}).

%%接受委托任务
accept_consign_task(TaskBag)->
	gen_server:cast(mod_consign:get_mod_consign_pid(), {'accept_task', [TaskBag]}).

%%完成委托任务
finish_consign_task(TaskBag)->
	gen_server:cast(mod_consign:get_mod_consign_pid(),{'finish_task',[TaskBag]}).

%%重置委托任务状态
reset_consign_task(Id)->
	gen_server:cast(mod_consign:get_mod_consign_pid(),{'reset_task',[Id]}).

%%获取任务信息
get_consign_task(Id)->
	gen_server:call(mod_consign:get_mod_consign_pid(),{'consign_task_by_id',[Id]}).

%%根据接受玩家获取委托任务
get_consign_task_by_accept(PlayerId,TaskId)->
	gen_server:call(mod_consign:get_mod_consign_pid(),{'get_consign_task_by_accept',[PlayerId,TaskId]}).

%%动态加载委托任务处理进程 
get_mod_consign_pid() ->
	ProcessName = misc:create_process_name(mod_consign_process, [0]),
	case misc:whereis_name({global, ProcessName}) of
		Pid when is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true -> Pid;
				false -> 
					start_mod_consign(ProcessName)
			end;
		_ ->
			start_mod_consign(ProcessName)
	end.


%%启动委托任务监控模块 (加锁保证全局唯一)
start_mod_consign(ProcessName) ->
	global:set_lock({ProcessName, undefined}),	
	ProcessPid =
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> Pid;
					false -> 
						start_consign(ProcessName)
				end;
			_ ->
				start_consign(ProcessName)
		end,	
	global:del_lock({ProcessName, undefined}),
	ProcessPid.

%%开启委托任务监控模块
start_consign(ProcessName) ->
    case supervisor:start_child(
               yg_server_sup,
               {mod_consign,
                {mod_consign, start_link,[[ProcessName,0]]},
                permanent, 10000, supervisor, [mod_consign]}) of
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
					misc:write_monitor_pid(self(), mod_consign, {}),
					misc:write_system_info(self(), mod_consign, {}),
					erlang:send_after(?TIMER_1, self(), {'clear'});
				true->
			 		misc:write_monitor_pid(self(), mod_consign_child, {Worker_id})
			end,
			%%加载委托任务数据
			lib_consign:init_consign_task(),
			io:format("8.Init mod_consign finish!!!~n"),
    		{ok, []};
		_ ->
			{stop,normal,[]}
	end.

handle_call({'consign_task_by_id',[Id]},_From,State)->
	ConsignTask = case lib_consign:get_consign_task_by_id(Id) of
					  []->[];
					  [Data]->Data
				  end,
	{reply,{ok,ConsignTask},State};

handle_call({'get_consign_task_by_accept',[PlayerId,TaskId]},_From,State)->
	 ConsignTask = case lib_consign:get_consign_task_by_accept(PlayerId,TaskId) of
					   []->[];
					   [Data]->Data
				   end,
	 {reply,{ok,ConsignTask},State};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast( {'consign_task', [PlayerStatus,ConsignInfo]},State)->
	Consign_task = lib_consign:get_all_consign_task(),
%% 	NewConsignInfo = 	case gen_server:call(PlayerStatus#player.other#player_other.pid_task,{'consign_times',PlayerStatus}) of
%% 							{ok,ConsignInfo} -> ConsignInfo;
%% 							{'EXIT', _} -> {0,3,0,3}
%% 						end,
	{ok,BinData} = pt_30:write(30400,[Consign_task,ConsignInfo]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	{noreply,State};
	
handle_cast({'publish_task', [TaskBag]},State)->
	lib_consign:publish_consign_task(TaskBag),
	{noreply,State};

handle_cast({'accept_task', [TaskBag]},State)->
	lib_consign:accept_consign_task(TaskBag),
	{noreply,State};

handle_cast({'finish_task', [TaskBag]},State)->
	lib_consign:finish_consign_task(TaskBag),
	{noreply,State};

handle_cast({'reset_task', [Id]},State)->
	lib_consign:reset_consign_task(Id),
	{noreply,State};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({'clear'},State)->
	NowSec = util:get_today_current_second(),
	if NowSec =< 60 ->
		   lib_consign:clear_consign_task(),
		   ok;
	  true->skip
	end,
	erlang:send_after(?TIMER_1, self(), {'clear'}),
	{noreply,State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()).

code_change(_OldVsn, State, _Extra)->
    {ok, State}.


%%
%% Local Functions
%%