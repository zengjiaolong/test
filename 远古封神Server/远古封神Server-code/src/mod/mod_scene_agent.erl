%%%------------------------------------
%%% @Module  : mod_scene_agent
%%% @Author  : ygzj
%%% @Created : 2010.11.06
%%% @Description: 场景管理_代理
%%%------------------------------------
-module(mod_scene_agent). 
-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("common.hrl"). 
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

%% --------------------------------------------------------------------
%% External exports
%% --------------------------------------------------------------------
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-compile(export_all).

-record(state, {
	worker_id = 0,									%% 工作进程ID
	send_num = 1									%% 工作进程发送序号
}).

-define(CLEAR_ONLINE_PLAYER, 10 * 60 * 1000).	  %% 每10分钟 对当前节点的玩家ETS_ONLINE做一次清理

%% ====================================================================
%% External functions
%% ====================================================================
start({SceneAgentProcessName, Worker_id}) ->
    gen_server:start(?MODULE, {SceneAgentProcessName, Worker_id}, []).

start_link({SceneAgentProcessName, Worker_id}) ->
	gen_server:start_link(?MODULE, {SceneAgentProcessName, Worker_id}, []).

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init({SceneAgentProcessName, WorkerId}) ->
    process_flag(trap_exit, true),
	if 
		WorkerId =:= 0 ->
			misc:write_monitor_pid(self(), mod_scene_agent, {?SCENE_WORKER_NUMBER}),
			%% 启动多个场景代理服务进程
			lists:foreach(
				fun(WorkId) ->
					SceneAgentWorkerName = misc:create_process_name(scene_agent_p, [WorkId]),
					mod_scene_agent:start({SceneAgentWorkerName, WorkId}),
					ok
				end,
				lists:seq(1, ?SCENE_WORKER_NUMBER)),
			pg2:create(scene_agent),
			pg2:join(scene_agent, self()),
			erlang:send_after(?CLEAR_ONLINE_PLAYER, self(), {event, clear_online_player});
	   	true -> 
			misc:register(local, tool:to_atom(SceneAgentProcessName), self()),
			misc:write_monitor_pid(self(),mod_scene_agent_worker, {WorkerId})
	end,
	State= #state{
		worker_id = WorkerId,
		send_num = 1
	},	
    {ok, State}.

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
%% 	?DEBUG("mod_scene_agent_apply_call: [~p/~p/~p]", [Module, Method, Args]),	
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_scene_agent_apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
			 error;
		 DataRet -> DataRet
	end,
    {reply, Reply, State};

handle_call(_Request, _From, State) ->
    {reply, State, State}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%%接受请求发送信息到场景,并分发给各代理工[主代理接收 1]
handle_cast({send_to_scene, SceneId, BinData}, State) ->
	%WorkerId = random:uniform(?SCENE_WORKER_NUMBER),
	WorkerId = 
		case State#state.send_num > ?SCENE_WORKER_NUMBER of
			true ->
				1;
			false ->
				State#state.send_num
		end,
	SceneAgentWorkerName = misc:create_process_name(scene_agent_p, [WorkerId]),
	gen_server:cast(tool:to_atom(SceneAgentWorkerName), {send_to_local_scene, SceneId, BinData}),
	NewState = State#state{
		send_num = State#state.send_num + 1
	},
	{noreply, NewState};

%%只发送数据到所有场景
handle_cast({send_to_scene_for_time, BinData}, State) ->
	%WorkerId = random:uniform(?SCENE_WORKER_NUMBER),
	WorkerId = 
		case State#state.send_num > ?SCENE_WORKER_NUMBER of
			true ->
				1;
			false ->
				State#state.send_num
		end,
	SceneAgentWorkerName = misc:create_process_name(scene_agent_p, [WorkerId]),
	gen_server:cast(tool:to_atom(SceneAgentWorkerName), {send_to_local_scene_for_time, BinData}),
	NewState = State#state{
		send_num = State#state.send_num + 1
	},
	{noreply, NewState};

%% 接受请求发送信息到场景区域,并分发给各代理工 [主代理接收 2]
handle_cast({send_to_scene, SceneId, X, Y, BinData}, State) ->
	%WorkerId = random:uniform(?SCENE_WORKER_NUMBER),
	WorkerId = 
		case State#state.send_num > ?SCENE_WORKER_NUMBER of
			true ->
				1;
			false ->
				State#state.send_num
		end,
	SceneAgentWorkerName = misc:create_process_name(scene_agent_p, [WorkerId]),
	gen_server:cast(tool:to_atom(SceneAgentWorkerName), {send_to_local_scene, SceneId, X, Y, BinData}),
	NewState = State#state{
		send_num = State#state.send_num + 1
	},
	{noreply, NewState};
%% 接受请求发送信息到场景区域,并分发给各代理工 [主代理接收 2](用于战斗)
handle_cast({send_to_scene_for_battle, SceneId, X, Y, BinData}, State) ->
	%WorkerId = random:uniform(?SCENE_WORKER_NUMBER),
	WorkerId = 
		case State#state.send_num > ?SCENE_WORKER_NUMBER of
			true ->
				1;
			false ->
				State#state.send_num
		end,
	SceneAgentWorkerName = misc:create_process_name(scene_agent_p, [WorkerId]),
	gen_server:cast(tool:to_atom(SceneAgentWorkerName), {send_to_local_scene_for_battle, SceneId, X, Y, BinData}),
	NewState = State#state{
		send_num = State#state.send_num + 1
	},
	{noreply, NewState};

%%接受请求发送信息到场景,并分发给各代理工[主代理接收 6](用于处理场景上的事件)
handle_cast({send_to_scene_for_event, SceneId, Event}, State) ->
	%WorkerId = random:uniform(?SCENE_WORKER_NUMBER),
	WorkerId = 
		case State#state.send_num > ?SCENE_WORKER_NUMBER of
			true ->
				1;
			false ->
				State#state.send_num
		end,
	SceneAgentWorkerName = misc:create_process_name(scene_agent_p, [WorkerId]),
	gen_server:cast(tool:to_atom(SceneAgentWorkerName), {send_to_local_scene_for_event, SceneId, Event}),
	NewState = State#state{
		send_num = State#state.send_num + 1
	},
	{noreply, NewState};

  
%%发送信息到本地的场景用户 [代理工接收 1]
handle_cast({send_to_local_scene, SceneId, BinData}, State) ->
	spawn(fun()-> lib_send:send_to_local_scene(SceneId, BinData) end),
	{noreply, State};

%%发送信息到本地的场景用户 [代理工接收 1](定时清理灵兽和坐骑幸运值)
handle_cast({send_to_local_scene_for_time, BinData}, State) ->
	spawn(fun()-> lib_send:send_to_local_scene_for_time(BinData) end),
	{noreply, State};

%%发送信息到本地的场景用户 [代理工接收 2]
handle_cast({send_to_local_scene, SceneId, X, Y, BinData}, State) ->
	spawn(fun()-> lib_send:send_to_local_scene(SceneId, X, Y, BinData) end),
	{noreply, State};

%%发送信息到本地的场景用户 [代理工接收 2]（用于战斗）
handle_cast({send_to_local_scene_for_battle, SceneId, X, Y, BinData}, State) ->
	spawn(fun()-> lib_send:send_to_local_scene(SceneId, X, Y, BinData, 3) end),
	{noreply, State};

%% 当人物移动时候的广播 [主代理接收3]
handle_cast({move_broadcast, SceneId, PidSends, X1, Y1, X2, Y2,PlayerId,Ps, MoveBinData, LeaveBinData, EnterBinData}, State) ->
	%WorkerId = random:uniform(?SCENE_WORKER_NUMBER),
	WorkerId = 
		case State#state.send_num > ?SCENE_WORKER_NUMBER of
			true ->
				1;
			false ->
				State#state.send_num
		end,
	SceneAgentWorkerName = misc:create_process_name(scene_agent_p, [WorkerId]),
	gen_server:cast(tool:to_atom(SceneAgentWorkerName), {move_local_broadcast, SceneId, PidSends, X1, Y1, X2, Y2,PlayerId,Ps, MoveBinData, LeaveBinData, EnterBinData}),
	NewState = State#state{
		send_num = State#state.send_num + 1
	},
	{noreply, NewState};

%% 当人物移动时候的广播 [代理工接收3]
handle_cast({move_local_broadcast, SceneId, PidSends, X1, Y1, X2, Y2,PlayerId,Ps, MoveBinData, LeaveBinData, EnterBinData}, State) ->
	spawn(fun()-> lib_scene:move_broadcast_node(SceneId, PidSends, X1, Y1, X2, Y2,PlayerId,Ps, MoveBinData, LeaveBinData, EnterBinData) end),
	{noreply, State};

%% 复活进入场景 [主代理接收4]
handle_cast({revive_to_scene, PidSends, PlayerId, ReviveType, Scene1, X1, Y1, Scene2, X2, Y2, Bin12003}, State) ->
	%WorkerId = random:uniform(?SCENE_WORKER_NUMBER),
	WorkerId = 
		case State#state.send_num > ?SCENE_WORKER_NUMBER of
			true ->
				1;
			false ->
				State#state.send_num
		end,
	SceneAgentWorkerName = misc:create_process_name(scene_agent_p, [WorkerId]),
	gen_server:cast(tool:to_atom(SceneAgentWorkerName), {revive_to_local_scene, PidSends, PlayerId, ReviveType, Scene1, X1, Y1, Scene2, X2, Y2, Bin12003}),
	NewState = State#state{
		send_num = State#state.send_num + 1
	},
	{noreply, NewState};

%% 复活进入场景 [代理工接收4]
handle_cast({revive_to_local_scene, PidSends, PlayerId, ReviveType, Scene1, X1, Y1, Scene2, X2, Y2, Bin12003}, State) ->
	spawn(fun()-> lib_scene:revive_to_scene_node(PidSends, PlayerId, ReviveType, Scene1, X1, Y1, Scene2, X2, Y2, Bin12003) end),
	{noreply, State};

%% 取得同屏25级及以上的玩家并向其发送好友祝福 [主代理接收5]
handle_cast({get_player_in_screen_bless, PlayerList, FriendsList}, State) ->
	spawn(fun()-> lib_scene:get_player_in_screen_bless(PlayerList, FriendsList) end),
%% 	WorkerId = 
%% 		case State#state.send_num > ?SCENE_WORKER_NUMBER of
%% 			true ->
%% 				1;
%% 			false ->
%% 				State#state.send_num
%% 		end,
%% 	SceneAgentWorkerName = misc:create_process_name(scene_agent_p, [WorkerId]),
%% 	gen_server:cast(tool:to_atom(SceneAgentWorkerName), {get_player_in_local_screen_bless, PlayerList, FriendsList}),
%% 	NewState = State#state{
%% 		send_num = State#state.send_num + 1
%% 	},
	{noreply, State};

%% %% 取得同屏25级及以上的玩家并向其发送好友祝福 [代理工接收5]
%% handle_cast({get_player_in_local_screen_bless, PlayerList, FriendsList}, State) ->
%% 	spawn(fun()-> lib_scene:get_player_in_screen_bless(PlayerList, FriendsList) end),
%% 	{noreply, State};

%%发送信息到本地的场景用户 [代理工接收 6](用于处理场景上的事件)
handle_cast({send_to_local_scene_for_event, SceneId, Event}, State) ->
	spawn(fun()-> lib_send:send_to_local_scene_for_event(SceneId, Event) end),
	{noreply, State};

%% 双倍经验活动数据
%% StartTime 活动开始时间
%% EndTime 活动结束时间
handle_cast({'UPDATE_EXP_ACTIVITY_DATA', StartTime, EndTime}, State) ->
	catch ets:delete_all_objects(?ETS_EXP_ACTIVITY),
	St = util:string_to_term(StartTime),
	Et = util:string_to_term(EndTime),
	ExpActivity = #ets_exp_activity{
		st = St,
		et = Et
	},
	ets:insert(?ETS_EXP_ACTIVITY, ExpActivity),
	
	case get(exp_activity_timer) of
		undefined ->
			skip;
		ExpActivityTimer ->
			catch erlang:cancel_timer(ExpActivityTimer)
	end,
	Now = util:unixtime(),
	DistTime = 
		if
			St > Now ->
				(St - Now) * 1000;
			true ->
				1000
		end,
	NewExpActivityTimer = erlang:send_after(DistTime, self(), 'SEND_EXP_ACTIVITY'),
	put(exp_activity_timer, NewExpActivityTimer),
	{noreply, State};

%% 统一模块+过程调用(cast)
handle_cast({apply_cast, Module, Method, Args}, State) ->
%% 	?DEBUG("mod_scene_agent_apply_cast: [~p/~p/~p]", [Module, Method, Args]),	
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_scene_agent_apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
			 error;
		 _ -> ok
	end,
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%% 清除节点中的异常玩家
handle_info({event, clear_online_player}, State) ->
	spawn(fun()-> clear_online_player() end),		  
	erlang:send_after(?CLEAR_ONLINE_PLAYER, self(), {event, clear_online_player}),
	{noreply, State};

%% 发送双倍经验活动数据
handle_info('SEND_EXP_ACTIVITY', State) ->
	case get(exp_activity_timer) of
		undefined ->
			skip;
		ExpActivityTimer ->
			catch erlang:cancel_timer(ExpActivityTimer)
	end,
	case ets:tab2list(?ETS_EXP_ACTIVITY) of
		[] ->
			false;
		[ExpActivity | _] ->
			Now = util:unixtime(),
			if
				ExpActivity#ets_exp_activity.et > Now ->
					DistTime = (ExpActivity#ets_exp_activity.et - Now) * 1000,
					{ok, BinData} = pt_13:write(13061, [ExpActivity#ets_exp_activity.st, ExpActivity#ets_exp_activity.et, DistTime]),
					spawn(fun()-> lib_send:send_to_node(BinData) end);
				true ->
					skip
			end
	end,
	{noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()),
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% =========================================================================
%%% 外部调用API
%% =========================================================================
%% 发送数据到所有节点场景 
send_to_scene_for_time(BinData)->
	[gen_server:cast(SceneAgentPid, {send_to_scene_for_time, BinData}) || SceneAgentPid <- misc:pg2_get_members(scene_agent)].

send_to_scene(SceneId, BinData)->
	[gen_server:cast(SceneAgentPid, {send_to_scene, SceneId, BinData}) || SceneAgentPid <- misc:pg2_get_members(scene_agent)].

%% 发送数据到某一场景区域
send_to_area_scene(SceneId, X, Y, BinData) ->
	[gen_server:cast(SceneAgentPid, {send_to_scene, SceneId, X, Y, BinData}) || SceneAgentPid <- misc:pg2_get_members(scene_agent)].
%% 发送数据到某一场景区域（用于战斗）
send_to_area_scene_for_battle(SceneId, X, Y, BinData) ->
	[gen_server:cast(SceneAgentPid, {send_to_scene_for_battle, SceneId, X, Y, BinData}) || SceneAgentPid <- misc:pg2_get_members(scene_agent)].
%%发功数据到某一场景，让该场景上的所有玩家处理对应的事件
send_to_scene_for_event(SceneId, Event) ->
	[gen_server:cast(SceneAgentPid, {send_to_scene_for_event, SceneId, Event}) || SceneAgentPid <- misc:pg2_get_members(scene_agent)].

%%当人物或者怪物移动时候的广播
move_broadcast(SceneId, PidSends, X1, Y1, X2, Y2, PlayerId, Sta, MoveBinData, LeaveBinData, EnterBinData) ->
	[gen_server:cast(SceneAgentPid, {move_broadcast, SceneId, PidSends, X1, Y1, X2, Y2, PlayerId, Sta, MoveBinData, LeaveBinData, EnterBinData}) || SceneAgentPid <- misc:pg2_get_members(scene_agent)].

%% 复活进入场景
revive_to_scene(PidSends, PlayerId, ReviveType, SceneId, X1, Y1, Scene2, X2, Y2, Bin12003) ->
	[gen_server:cast(SceneAgentPid, {revive_to_scene, PidSends, PlayerId, ReviveType, SceneId, X1, Y1, Scene2, X2, Y2, Bin12003}) || SceneAgentPid <- misc:pg2_get_members(scene_agent)].

%% 取得同屏25级及以上的玩家并向其发送好友祝福
get_player_in_screen_bless(Player, FriendsList) ->
	PlayerData = [
		Player#player.id, 
		Player#player.nickname, 
		Player#player.lv,
		Player#player.scene, 
		Player#player.x, 
		Player#player.y
	],
	[gen_server:cast(SceneAgentPid, {get_player_in_screen_bless, PlayerData, FriendsList}) || SceneAgentPid <- misc:pg2_get_members(scene_agent)].


%% 清除节点中的异常玩家
clear_online_player() ->
	Now = util:unixtime(),
	MS = ets:fun2ms(fun(P) when P#player.other#player_other.shadow =:= 0 -> 
		[
			P#player.id,
			P#player.other#player_other.pid,
			P#player.other#player_other.socket,
			P#player.other#player_other.socket2,
			P#player.other#player_other.socket3,
			P#player.other#player_other.heartbeat,
			P#player.nickname,
			P#player.scene,
			P#player.x,
			P#player.y
		]
	end),
	User = ets:select(?ETS_ONLINE, MS),
	F = fun([PlayerId, Pid, Socket,Socket2,Socket3, HeartBeat, NickName, SceneId, X, Y]) ->
		case erlang:is_process_alive(Pid) andalso Now - HeartBeat < 120 of
			true ->
				%% 定时保存成就数据和活跃度在线时间统计
				Pid ! {'UPDATE_ACH_STATISTICS'};
			false ->
				gen_tcp:close(Socket),
				catch gen_tcp:close(Socket2),
				catch gen_tcp:close(Socket3),
				mod_player:delete_player_ets(PlayerId),
				ets:delete(?ETS_ONLINE, PlayerId),
				spawn(fun()->
					ScenePid = mod_scene:get_scene_pid(SceneId, undefined, undefined),
					ScenePid ! {'CLEAR_ETS_ONLINE_SCENE', PlayerId},
					db_agent:insert_kick_off_log(PlayerId, NickName, 11, Now, SceneId, X, Y) 
				end),
				mod_player:stop(Pid, 2)
		end
	end,
	lists:foreach(F, User).

