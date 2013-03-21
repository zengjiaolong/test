%%% -------------------------------------------------------------------
%%% Author  : xianrongMai
%%% Description :
%%%
%%% Created : 2012-1-4
%%% -------------------------------------------------------------------
-module(mod_anniversary).

-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------

-include("common.hrl").
-include("record.hrl").
-include("activities.hrl").

%% --------------------------------------------------------------------
%% External exports
-export([
		 start_link/1,
		 start/1,
		 stop/0,
		 
		 start_anniversary/1,
		 get_anniversary_pid/0,
		 
		 get_wish_tree/1,		%% 30016 周年庆活动祈愿信息
		 make_wish/4			%% 30017 周年庆活动发送祈愿
		]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {worker_id = 0}).

-define(ANNIVERSARY_WORKER_NUMBER, 100).

%% ====================================================================
%% External functions
%% ====================================================================


%% ====================================================================
%% Server functions
%% ====================================================================

start_link([ProcessName, Worker_id]) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [ProcessName, Worker_id], []).

start([ProcessName, Worker_id]) ->
    gen_server:start(?MODULE, [ProcessName, Worker_id], []).

stop() ->
    gen_server:call(?MODULE, stop).

%% 动态加载祈福处理进程 
get_anniversary_pid() ->
	ProcessName = misc:create_process_name(anniversary_p, [0]),
	case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true ->
						WorkerId = random:uniform(?ANNIVERSARY_WORKER_NUMBER),
						ProcessName_1 = misc:create_process_name(anniversary_p, [WorkerId]),
 						misc:whereis_name({global, ProcessName_1});						
					false -> 
						start_anniversary(ProcessName)
				end;
			_ ->
				start_anniversary(ProcessName)
	end.

%%启动氏族监控模块 (加锁保证全局唯一)
start_anniversary(ProcessName) ->
	global:set_lock({ProcessName, undefined}),	
	ProcessPid =
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> 
						WorkerId = random:uniform(?ANNIVERSARY_WORKER_NUMBER),
						ProcessName_1 = misc:create_process_name(anniversary_p, [WorkerId]),
 						misc:whereis_name({global, ProcessName_1});						
					false -> 
						start_anniversary_tree(ProcessName)
				end;
			_ ->
				start_anniversary_tree(ProcessName)
		end,	
	global:del_lock({ProcessName, undefined}),
	ProcessPid.

%%启动氏族监控树模块
start_anniversary_tree(ProcessName) ->
	case supervisor:start_child(
       		yg_server_sup, {mod_anniversary,
            		{mod_anniversary, start_link,[[ProcessName, 0]]},
               		permanent, 10000, supervisor, [mod_anniversary]}) of
		{ok, Pid} ->
				Pid;
		_e ->
			?WARNING_MSG("anniversary start error:~p~n",[_e]),
				undefined
	end.

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([ProcessName, Worker_id]) ->
	process_flag(trap_exit, true),
 	case misc:register(unique, ProcessName, self()) of%% 多节点的情况下， 仅在一个节点祈福的处理进程
		yes ->
			if 
				Worker_id =:= 0 ->
					ets:new(?ANNIVERSARY, [{keypos, #ets_anniversary_bless.pid}, named_table, public, set,?ETSRC, ?ETSWC]),	%%祈福数据表
					misc:write_monitor_pid(self(),?MODULE, {?ANNIVERSARY_WORKER_NUMBER}),
					misc:write_system_info(self(), mod_anniversary, {}),	
					%% 启动多个场景服务进程
					io:format("13.Init mod_anniversary finish!!!~n"),
					erlang:send_after(5000, self(), {'LOAD_WISH_TREE'}),
					%%做周期性的数据更新操作
					TimeRef = erlang:send_after(?ANNIVERSARY_TIME_STAMP, self(), {'UPDATE_WISH_DATA', 0}),
					put(time_stamp, TimeRef),%%放进程字典
					lists:foreach(
					  fun(WorkerId) ->
							  ProcessName_1 = misc:create_process_name(anniversary_p, [WorkerId]),
							  mod_anniversary:start([ProcessName_1, WorkerId])
					  end,
					  lists:seq(1, ?ANNIVERSARY_WORKER_NUMBER));		
				true -> 
					misc:write_monitor_pid(self(), mod_anniversary_worker, {Worker_id})
			end,
			State= #state{worker_id = Worker_id},
			{ok, State};
		_ ->
			{stop,normal,#state{}}
	end.
		

%% --------------------------------------------------------------------
%% Function: handle_call/3
%% Description: Handling call messages
%% Returns: {reply, Reply, State}          |
%%          {reply, Reply, State, Timeout} |
%%          {noreply, State}               |
%%          {noreply, State, Timeout}      |
%%          {stop, Reason, Reply, State}   | (terminate/2 is called)
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%% 统一模块+过程调用(call)
handle_call({apply_call, Module, Method, Args}, _From, State) ->
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("anniversary apply call error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
			 error;
		 DataRet -> DataRet
	end,
    {reply, Reply, State};

handle_call(_Request, _From, State) ->
	?WARNING_MSG("unknow call in module mod_anniversary: ~p",[_Request]),
    Reply = ok,
    {reply, Reply, State}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%% 统一模块+过程调用(cast)
handle_cast({apply_cast, Module, Method, Args}, State) ->
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("anniversary apply cast error: Module=~p, Method=~p, Reason=~p",[Module, Method, Info]),
			 error;
		 _ -> ok
	end,
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

handle_cast(_Msg, State) ->
	?WARNING_MSG("unknow cast in module mod_anniversary: ~p",[_Msg]),
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%%初始化数据
handle_info({'LOAD_WISH_TREE'}, State) ->
	%%初始化祈祷活动的数据
	?DEBUG("LOAD_WISH_TREE", []),
	lib_anniversary:load_anniversary(),
	{noreply, State};

handle_info({'UPDATE_WISH_DATA',Type}, State) ->
	NowTime = util:unixtime(),
	NowSec = util:get_today_current_second(),
	NewType = lib_anniversary:check_wishtree_data(Type, NowTime, NowSec),
	%%先去掉定时器.
	misc:cancel_timer(time_stamp),
	TimeRef = erlang:send_after(?ANNIVERSARY_TIME_STAMP, self(), {'UPDATE_WISH_DATA', NewType}),
	put(time_stamp, TimeRef),%%放进程字典
	
	{noreply, State};

handle_info({'END_WISHTREE_BROADCAST'}, State) ->
	%%世界广播
	Content = "本轮祝福已经结束，请期待下轮开启，本次的幸运玩家将于<font color='#FFFFFF'>2</font></a>分钟后产生.",
	lib_chat:broadcast_sys_msg(1, Content),
	%%2分钟后，开始计算得奖的玩家
	?DEBUG("END_WISHTREE_BROADCAST", []),
	erlang:send_after(120000, self(), {'LOTTERY_WISHTREE'}),
	
	{noreply, State};
	
handle_info({'LOTTERY_WISHTREE'}, State) ->
	?DEBUG("LOTTERY_WISHTREE", []),
	%%开始抽奖活动
	lib_anniversary:lottery_wishtree(),
	{noreply, State};
handle_info(_Info, State) ->
	?WARNING_MSG("unknow info in module mod_anniversary: ~p",[_Info]),
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% --------------------------------------------------------------------
%%% Internal functions
%% --------------------------------------------------------------------

%% -----------------------------------------------------------------
%% 30016 周年庆活动祈愿信息
%% -----------------------------------------------------------------
get_wish_tree(PlayerStatus) ->
	gen_server:cast(mod_anniversary:get_anniversary_pid(),
					{apply_cast, lib_anniversary, get_wish_tree, [PlayerStatus#player.other#player_other.pid_send]}).
%% -----------------------------------------------------------------
%% 30017 周年庆活动发送祈愿
%% -----------------------------------------------------------------
make_wish(Player, Gid, Content, NowTime) ->
	try 
		case gen_server:call(mod_anniversary:get_anniversary_pid(), 
							 {apply_call, lib_anniversary, make_wish,
							  [Player#player.id, Player#player.nickname, Gid, Content, NowTime]}) of
			error ->
				0;
			Data ->
				Data
		end
	catch
		_:_Reason -> 
			?ERROR_MSG("make wish fail for the reason:[~p]", [_Reason]),
			0
	end.