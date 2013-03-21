%%%------------------------------------
%%% @Module  : mod_scene
%%% @Author  : ygzj
%%% @Created : 2010.08.24
%%% @Description: 场景管理
%%%------------------------------------
-module(mod_scene). 
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
-compile([export_all]).

-record(state, {
	sceneid = 0, 
	worker_id = 0,
	drop_id = 1									%% 场景掉落物的累加ID
}).

-define(CLEAR_ONLINE_PLAYER, 20 * 60 * 1000).	  %% 每10分钟 对 ets_online 做一次清理

%% ====================================================================
%% External functions
%% ====================================================================
start({SceneId, SceneProcessName, Worker_id}) ->
    gen_server:start(?MODULE, {SceneId, SceneProcessName, Worker_id}, []).

start_link({SceneId, SceneProcessName, Worker_id}) ->
    gen_server:start_link(?MODULE, {SceneId, SceneProcessName, Worker_id}, []).

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init({SceneId, SceneProcessName, WorkerId}) ->
    process_flag(trap_exit, true),
%% 	?DEBUG("SceneId:~p, SceneProcessName:~p, WorkerId:~p", [SceneId, SceneProcessName, WorkerId]),
	case misc:register(unique, SceneProcessName, self()) of
		yes ->
			if 
				WorkerId =:= 0 ->
					net_kernel:monitor_nodes(true),
		   			lib_scene:load_scene(SceneId),
					misc:write_monitor_pid(self(),mod_scene, {SceneId, ?SCENE_WORKER_NUMBER}),
					%% 场景节点死人检测
%% 					erlang:send_after(?CLEAR_ONLINE_PLAYER, self(), {event, clear_online_player}),
					%% 启动多个场景服务进程
					lists:foreach(
						fun(WorkId) ->
							SceneWorkerProcessName = misc:create_process_name(scene_p, [SceneId, WorkId]),
							mod_scene:start_link({SceneId, SceneWorkerProcessName, WorkId})
						end,
					lists:seq(1, ?SCENE_WORKER_NUMBER));
	   			true -> 
		   			misc:write_monitor_pid(self(), mod_scene_worker, {SceneId, WorkerId})
			end,
			State= #state{
				sceneid = SceneId, 
				worker_id = WorkerId
			},	
    		{ok, State};
		_ ->
?WARNING_MSG("mod_scene duplicate scenes error: SceneId=~p, WorkerId =~p, Args =~p~n",[SceneId, SceneProcessName, WorkerId]),
			{stop, normal, #state{}}
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
%% 	?DEBUG("mod_scene_apply_call: [~p/~p/~p]", [Module, Method, Args]),	
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_scene_apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
			 error;
		 DataRet -> DataRet
	end,
    {reply, Reply, State};

%% 获取掉落物自增ID
handle_call({'GET_DROP_ID', DropNum}, _From, State) ->
	DropId = State#state.drop_id + DropNum + 1,
	NewDropId = 
		if
   			DropId > ?MON_LIMIT_NUM ->
				1;
	   		true ->
				DropId
        end,
	NewState = State#state{
		drop_id = NewDropId
	},
    {reply, State#state.drop_id, NewState};

handle_call(_Request, _From, State) ->
    {reply, State, State}.

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
?WARNING_MSG("mod_scene_apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
			 error;
		_ -> ok
	end,
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

%% 怪物特定范围伤害
handle_cast({'LAST_AREA_DAM', Hurt, Last, AttArea, SceneId, X, Y, SkillId}, State) ->
	erlang:send_after(1000, self(), {'LAST_AREA_DAM', Hurt, Last, AttArea, SceneId, X, Y}),
	{ok, BinData} = pt_20:write(20103, [X, Y, (Last + 1) * 1000, SkillId]),
	lib_send:send_to_online_scene(SceneId, X, Y, BinData),
	{noreply, State};

handle_cast({'INIT_WARFARE_MON'}, State) ->
	mod_warfare_mon:init_warfare_mon(),
	{noreply, State};

handle_cast({'SHADOW',[Status,SkillList,SceneId,X,Y]},State)->
	_Res = mod_mon_create:create_shadow_action(Status,SkillList,SceneId,X,Y),
	{noreply,State};

handle_cast({'CREATE_SHADOW', PlayerId, SkillList}, State) ->
	case lib_mon:get_player(PlayerId, State#state.sceneid) of
		[] ->
			skip;
		Player ->
			NewPlayerId = round(?MON_LIMIT_NUM / 10) + Player#player.id,
			X = Player#player.x + 1,
			Y = Player#player.y + 1,
			mod_shadow_active:start([Player, NewPlayerId, X, Y, SkillList])
	end,
	{noreply, State};

%% 野外BOSS重新刷新 
handle_cast({'REFRESH_WILD_BOSS', MonId, SceneId, X, Y}, State) ->
	MS = ets:fun2ms(fun(M) when M#ets_mon.mid == MonId ,  M#ets_mon.scene == SceneId -> 
		[
			M#ets_mon.pid,
			M#ets_mon.unique_key
		]
	end),
	MonList = ets:select(?ETS_SCENE_MON, MS),
	Now = util:unixtime(),
	RandPid = mod_rank:get_mod_rank_pid(),
	catch gen_server:cast(RandPid, {boss_killed_time, MonId, Now , 0}),
	if
		length(MonList) > 0 ->
			Fun = fun([MonPid, MonUniqueKey]) -> 
				case misc:is_process_alive(MonPid) of 
					false ->
						lib_mon:del_mon_data(MonPid, MonUniqueKey);
					true ->
						MonPid ! 'CLEAR_MON'	
				end
			end,
			[Fun(M) || M <- MonList];
		true ->
			skip
	end,
	AutoId = mod_mon_create:get_mon_auto_id(1),
	mod_mon_create:create_mon_action(MonId, SceneId, X, Y, 1, [], AutoId), 
	{noreply, State};

%% 场景重新生成所有怪物 普通 精英 采集 捕捉
handle_cast({'REFRESH_SCENE_MON',SceneId},State) ->
	MS = ets:fun2ms(fun(M) when M#ets_mon.scene == SceneId , 
								(M#ets_mon.type == 1 orelse M#ets_mon.type == 2 orelse M#ets_mon.type == 6 orelse M#ets_mon.type == 7) ->
							[
							 M#ets_mon.id,
							 M#ets_mon.pid, 
							 M#ets_mon.unique_key
							]
					end),
	MonList = ets:select(?ETS_SCENE_MON, MS),
	if
		length(MonList) > 0 ->
			Fun = fun([_Id,MonPid,MonUniqueKey]) ->
						 MonPid ! clear,
						 lib_mon:del_mon_data(MonPid, MonUniqueKey)
				  end,
			lists:foreach(Fun, MonList),
			Fpack = fun([Id,_Mpid,_Muk]) ->
							{ok, BinData} = pt_12:write(12082, [Id, 0]),
							<<BinData/binary>>
					end,
			PackBinData = tool:to_binary(lists:map(Fpack, MonList)),
			mod_scene_agent:send_to_scene(SceneId,PackBinData);
		true ->
			skip
	end,
	case data_scene:get(SceneId) of
		[] -> 
			skip;
		SceneInfo ->
			Mon = SceneInfo#ets_scene.mon,
			Filter = fun([Mid,_X,_Y,_Type],NewMon) ->
							 case data_agent:mon_get(Mid) of
								 [] -> 
									NewMon;
								 MonInfo ->
									Type = MonInfo#ets_mon.type,
									if
							 			Type == 1 orelse Type == 2 orelse Type == 6 orelse Type == 7 ->
											[[Mid,_X,_Y,_Type]|NewMon];
										true ->
											NewMon
									end
							 end
					 end,
			NewMonList = lists:foldl(Filter, [], Mon),
			lib_scene:load_mon(NewMonList, SceneId)
	end,
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
%% 处理节点关闭事件
handle_info({nodedown, Node}, State) ->
	try
		if 
			State#state.worker_id =:= 0 ->
				Scene = State#state.sceneid,
				lists:foreach(fun(T) ->
					if T#player.other#player_other.node == Node, T#player.scene == Scene  ->
			  				ets:delete(?ETS_ONLINE_SCENE, T#player.id),
				  			{ok, BinData} = pt_12:write(12004, T#player.id),					
							lib_send:send_to_local_scene(Scene, BinData);
					   true -> no_action
					end
				  end, 
				  ets:tab2list(?ETS_ONLINE_SCENE));
	   		true -> no_action
		end
	catch
		_:_ -> error
	end,
    {noreply, State};

%% 定时清理场景死人
handle_info({event, clear_online_player}, State) ->
	spawn(fun()-> clear_online_player(State#state.sceneid) end),
	erlang:send_after(?CLEAR_ONLINE_PLAYER, self(), {event, clear_online_player}),
	{noreply, State};

%% 清理场景玩家
handle_info({'CLEAR_ETS_ONLINE_SCENE', PlayerId}, State) ->
	spawn(fun()->
		db_agent:update_online_flag(PlayerId, 0),
		ets:delete(?ETS_ONLINE_SCENE, PlayerId)			  
	end),
	{noreply, State};

%%创建场景指定怪物
handle_info({'CREATE_MON',[MonId,Type,Other]},State)->
	MonInfo = lib_mon:get_scene_by_mon_id(MonId),
	Position = [{X,Y}||[_,X,Y]<-MonInfo],
	mod_mon_create:create_some_mon_loop(Position,State#state.sceneid,MonId,Type,Other),
	{noreply,State};

%%清除场景指定怪物  
handle_info({'CLEAR_MON',[MonId]},State)->
	mod_mon_create:clear_scene_mon_by_monid(State#state.sceneid,MonId),
	{noreply,State};

%% 怪物特定范围伤害
handle_info({'LAST_AREA_DAM', Hurt, Last, AttArea, SceneId, X, Y}, State) ->
	lib_mon:battle(0, 0, 0, SceneId, X, Y, AttArea, Hurt, 0, 10048),
	case Last > 0 of
		true ->
			erlang:send_after(1000, self(), {'LAST_AREA_DAM', Hurt, Last - 1, AttArea, SceneId, X, Y});
		false ->
			skip
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
%%% 业务逻辑处理函数
%% =========================================================================
get_scene_real_pid(SceneUniqueId) ->
	SceneProcessName = misc:create_process_name(scene_p, [SceneUniqueId, 0]),
	misc:whereis_name({global, SceneProcessName}).

%% 动态加载某个场景
get_scene_pid(SceneId, OldScenePid, PlayerPid) ->
	SceneProcessName = misc:create_process_name(scene_p, [SceneId, 0]),
	{ScenePid, Worker_Pid} =
		case misc:whereis_name({global, SceneProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true ->
						case lib_skyrush:is_get_skyrush_scene(SceneId) orelse lib_scene:is_copy_scene(SceneId) 
								orelse lib_spring:is_spring_scene(SceneId) of
							true ->
								{Pid, Pid};
                            false ->
                                WorkerId = random:uniform(?SCENE_WORKER_NUMBER),
                                SceneProcess_Name = misc:create_process_name(scene_p, [SceneId, WorkerId]),
                                {Pid, misc:whereis_name({global, SceneProcess_Name})}
						end;
					false -> 
						global:unregister_name(SceneProcessName),
						exit(Pid, kill),
						start_mod_scene(SceneId, SceneProcessName)
				end;					
			_ ->
				start_mod_scene(SceneId, SceneProcessName)
		end,
	if 
		ScenePid =/= OldScenePid, PlayerPid =/= undefined ->
			gen_server:cast(PlayerPid, {change_pid_scene, ScenePid, SceneId});
		true ->
			no_cast
	end,
	Worker_Pid.


%% 获取掉落物自增ID
get_drop_id(SceneId, DropNum) ->
	ScenePid = mod_scene:get_scene_real_pid(SceneId),
	case is_pid(ScenePid) of
		true ->
			case catch gen_server:call(ScenePid, {'GET_DROP_ID', DropNum}) of
				{'EXIT', _Reason} ->
					round(?MON_LIMIT_NUM / random:uniform(100));
				Ret ->
					Ret
			end;		
		false ->
			round(?MON_LIMIT_NUM / random:uniform(100))
	end.
	

%%启动场景模块 (加锁保证全局唯一)
start_mod_scene(SceneId, SceneProcessName) ->
	global:set_lock({SceneProcessName, undefined}),
	%timer:sleep(1000),
	ScenePid = start_scene(SceneId, SceneProcessName, 2),
	Worker_Pid = ScenePid,
	global:del_lock({SceneProcessName, undefined}),
	{ScenePid, Worker_Pid}.

%% 启动场景模块
start_scene(SceneId, SceneProcessName, _Source) ->
	Pid =
		case mod_scene:start({SceneId, SceneProcessName, 0}) of
			{ok, NewScenePid} ->
				NewScenePid;
			_ ->
				undefined
		end,
	%timer:sleep(1000),
	Pid.

%% 获取场景所有队长
get_scene_team_info(SceneId, X, Y, PidSend) ->
	ScenePid = mod_scene:get_scene_pid(SceneId, undefined, undefined),
	case is_pid(ScenePid) of
		true ->
			gen_server:cast(ScenePid, 
					{apply_asyn_cast, lib_scene, get_scene_team_info, [SceneId, X, Y, PidSend]});
		false ->
			skip
	end.

%% 流血
bleed_hp(PlayerId, SceneId, Hurt,ValType,Pid, Id, NickName, Career, Realm) ->
	ScenePid = mod_scene:get_scene_pid(SceneId, undefined, undefined),
	case is_pid(ScenePid) of
		true ->
			gen_server:cast(ScenePid, 
				{apply_asyn_cast, lib_battle, hp_bleed, [PlayerId, SceneId, Hurt, ValType ,Pid, Id, NickName, Career, Realm]});		
		false ->
			skip
	end.

%% 寻找一个唯一编码为UniqueId的Mon
find_mon(MonId, SceneId) ->
	try  
		gen_server:call(mod_scene:get_scene_pid(SceneId, undefined, undefined), 
				 {apply_call, lib_mon, get_mon, [MonId, SceneId]})			
	catch
		_:_ -> []
	end.

%% 获取某一场景的所有Npc
get_scene_npc(SceneId) ->
	try  
		gen_server:call(mod_scene:get_scene_pid(SceneId, undefined, undefined), 
				 {apply_call, lib_scene, get_scene_npc, [SceneId]})			
	catch
		_:_ -> []
	end.

%% 寻找一个唯一编码为UniqueId的npc
find_npc(UniqueId, SceneId) ->
	try  
		gen_server:call(mod_scene:get_scene_pid(SceneId, undefined, undefined), 
				 {apply_call, lib_npc, get_npc, [UniqueId, SceneId]})			
	catch
		_:_ -> []
	end.

%% 获得NPC唯一id
get_npc_unique_id(NpcId, SceneId) ->
	try  
		gen_server:call(mod_scene:get_scene_pid(SceneId, undefined, undefined), 
				 {apply_call, lib_npc, get_unique_id, [NpcId, SceneId]})			
	catch
		_:_ -> 0
	end.

%% 在场景中， 放置一个掉落物
put_mon_drop_in_scene(PidScene, DropInfo) ->
	try 
		gen_server:cast(PidScene, {apply_asyn_cast, ets, insert, [?ETS_GOODS_DROP, DropInfo]})	
	catch
		_:_ -> {fail, no_drop}
	end.

%% 在场景中， 获取一个掉落物
get_mon_drop_in_scene(SceneId, DropId) ->
	try
		ScenePid = get_scene_pid(SceneId, undefined, undefined),
		UniqueKey = {SceneId, DropId},
		GoodsDropList = gen_server:call(ScenePid, {apply_call, ets, lookup, [?ETS_GOODS_DROP, UniqueKey]}, 2000),
		case GoodsDropList of
        	[GoodsDrop | _] -> 
				GoodsDrop;
        	_ -> 
				{}
    	end
	catch
		_:_ -> 
			{}
	end.

%% 在场景中，删除一个掉落物
del_mon_drop_in_scene(SceneId, DropId) ->
	try 
		ScenePid = get_scene_pid(SceneId, undefined, undefined),
		UniqueKey = {SceneId, DropId},
		gen_server:cast(ScenePid, {apply_asyn_cast, ets, delete, [?ETS_GOODS_DROP, UniqueKey]})	
	catch
		_:_ -> {fail, no_drop}
	end.	

%%同步场景用户状态
update_player(Status) ->
	try  
		ScenePid = mod_scene:get_scene_pid(Status#player.scene, Status#player.other#player_other.pid_scene, Status#player.other#player_other.pid),
		if
			node(Status#player.other#player_other.pid) == node(ScenePid) ->
				ets:insert(?ETS_ONLINE_SCENE, Status);
			true ->
				gen_server:cast(ScenePid,{apply_cast, ets, insert, [?ETS_ONLINE_SCENE, Status]})
		end	 	
	catch
		_:_ -> fail
	end.

%%同步场景用户状态- key-value 形式
update_player_info_fields(Status, ValueList) ->
	try 
		ScenePid = mod_scene:get_scene_pid(Status#player.scene,Status#player.other#player_other.pid_scene, Status#player.other#player_other.pid),
		if
			node(Status#player.other#player_other.pid) == node(ScenePid) ->
				lib_scene:update_player_info_fields(Status#player.id, ValueList); 
			true ->
				gen_server:cast(ScenePid ,{apply_cast, lib_scene, update_player_info_fields, [Status#player.id, ValueList]})
		end
	catch
		_:_ -> fail
	end.

%% 更新玩家的坐标信息
update_player_position(Player) ->
	try  
		ScenePid = mod_scene:get_scene_pid(Player#player.scene, Player#player.other#player_other.pid_scene, Player#player.other#player_other.pid),
		if
			node(Player#player.other#player_other.pid) == node(ScenePid) ->
				lib_scene:update_player_position(Player#player.id, Player#player.x, Player#player.y, Player#player.status);
			true ->
				gen_server:cast(ScenePid,
					{apply_cast, lib_scene, update_player_position, [Player#player.id, Player#player.x, Player#player.y, Player#player.status]})
		end
	catch
		_:_ -> fail
	end.

%% 获取场景基本信息
get_scene_info(SceneId, X, Y, PidSend) ->
	try  
		ModScenePid = get_scene_pid(SceneId, undefined, undefined),
		ok = gen_server:call(ModScenePid, {apply_call, lib_scene, get_scene_info, [SceneId, X, Y, PidSend]}),
		{ok, ModScenePid}
	catch
		_:_ -> 
			[]
	end.

%% 获取场景用户ID
get_scene_player_id(SceneId) ->
	try  
		ScenePid = mod_scene:get_scene_pid(SceneId, undefined, undefined), 
		gen_server:call(ScenePid, {apply_call, lib_scene, get_scene_player_id, [SceneId]})
	catch
		_:_ -> []
	end.

%% 用户进入场景
enter_scene(Pid_scene, Status) ->
	try  
		gen_server:cast(Pid_scene, {apply_cast, lib_scene, enter_scene, [Status]})
	catch
		_:_ -> fail
	end.	

%% 用户退出场景
leave_scene(PlayerId, SceneId, PidScene, X, Y) ->
	try  
		gen_server:cast(PidScene, 
				 {apply_cast, lib_scene, leave_scene, [PlayerId, SceneId, X, Y]})
	catch
		_:_ -> 
			fail
	end.

%% 用户退出场景
leave_scene1(PlayerId, SceneId, PidScene, X, Y) ->
	try  
		gen_server:cast(PidScene, 
				 {apply_cast, lib_scene, leave_scene1, [PlayerId, SceneId, X, Y]})
	catch
		_:_ -> 
			fail
	end.

%% 死亡召唤
conjure_after_die(Minfo, SceneId, X, Y) ->
	try 
		ScenePid = mod_scene:get_scene_pid(SceneId, undefined, undefined),
		gen_server:cast(ScenePid, 
			{apply_cast, lib_mon, conjure_after_die, [Minfo, SceneId, X, Y]})
	catch
		_:_ -> 
			fail
	end.	

%%进入场景条件检查
check_enter(Status, SceneId) ->
	try  
		gen_server:call(mod_scene:get_scene_pid(Status#player.scene, 
															   Status#player.other#player_other.pid_scene, 
															   Status#player.other#player_other.pid), 
				 {apply_call, lib_scene, check_enter, [Status, SceneId]})			
	catch
		_:_ -> fail
	end.


%% 查找同屏所有玩家
get_all_scene_user(Status) ->
	try  
		gen_server:call(mod_scene:get_scene_pid(Status#player.scene, 
															   Status#player.other#player_other.pid_scene, 
															   Status#player.other#player_other.pid), 
				 {apply_call, lib_scene, get_double_rest_user, [Status#player.id,Status#player.scene,Status#player.x,Status#player.y]})			
	catch
		_:_ -> []
	end.

%% 场景玩家检测(%%清除场景中的异常玩家)
clear_online_player(SceneId) ->
	Now = util:unixtime(),
	MS = ets:fun2ms(fun(P) when P#player.scene =:= SceneId, P#player.other#player_other.shadow =:= 0 -> 
		[
			P#player.id,
			P#player.other#player_other.pid,
			P#player.other#player_other.node,
			P#player.other#player_other.heartbeat,
			P#player.nickname,
			P#player.x,
			P#player.y
		]
	end),
	User = ets:select(?ETS_ONLINE_SCENE, MS),
	F = fun([PlayerId, Pid, Node, HeartBeat, NickName, X, Y]) ->
		case misc:is_process_alive(Pid) of
			false ->
				db_agent:update_online_flag(PlayerId, 0),
?WARNING_MSG("clear_online_player_/scene:~p/player_id:~p/pid:~p/node:~p/~n", [SceneId, PlayerId, Pid, Node]),						
				ets:delete(?ETS_ONLINE_SCENE, PlayerId);
			_ -> 
				case Now - HeartBeat > 120 of
					true->
?WARNING_MSG("clean_online_player:~p |~p | ~p |~p |~p~n",[PlayerId, SceneId, Now, HeartBeat, Now - HeartBeat]),
						db_agent:insert_kick_off_log(PlayerId, NickName, 10, Now, SceneId, X, Y),
						mod_player:stop(Pid, 2);
					false->
						is_alive
				end
		end
	end,
	lists:foreach(F, User).

%% 重新生成场景怪物
refresh_scene_mon(SceneId) ->
	ScenePid = mod_scene:get_scene_pid(SceneId, undefined, undefined),
	gen_server:cast(ScenePid, {'REFRESH_SCENE_MON',SceneId}).

test() ->
	NowTime = util:unixtime(),
	MS = ets:fun2ms(fun(P) when P#player.scene =:= 524 -> 
		[
			P#player.id,
			P#player.other#player_other.heartbeat
		]
	end),
	User = ets:select(?ETS_ONLINE_SCENE, MS),
	io:format("-----now:~p-------------info:~p~n",[NowTime,User]).
