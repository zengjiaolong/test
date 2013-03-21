%%% -------------------------------------------------------------------
%%% Author  : xiaomai
%%% Description :氏族领地
%%%
%%% Created : 2011-1-11
%%% -------------------------------------------------------------------
-module(mod_guild_manor).

-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("common.hrl").
-include("record.hrl").
-include("guild_info.hrl").
%% --------------------------------------------------------------------
%% External exports
-export([get_manor_id/3,
		 add_manor_role_list/3,
		 quit_manor_role_list/2,
		 get_manor_info/1,
		 get_guild_manor_pid/4,
		 get_guild_manor_pid_by_guild_id/1,
		 quit_guild_manor/2,							%% 传出指定的成员
		 get_outside_scene/1,							%% 判断是否在领地中，返回相关的场景坐标
		 send_out_all_manor/1,							%% 传出指定氏族在领地中的所有成员
%% 		 %%氏族福利接口
		 check_get_member_weal/2,
		 get_guild_level/2,
		 get_guild_skilltoken/2,
		 upgrade_h_skill/4,
		 guild_call_boss/3
		]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {manor_scene_id = 0,		%%氏族领地唯一id
				scene_id = 0,			%%场景原始id
				guild_id = 0,			%%氏族id
				manor_role_list = [],	%%领地内玩家列表
				boss_number = false,	%%领地的boss是否被召唤
				drop_id = 1
}).		
-record(manor_role,  {id, pid, is_online = true}).	%%玩家列表元素
-define(MANOR_PRO_KILLSELF_TIME, 300000).	%%领地进程自动退出的时间限制(5分钟)
%% ====================================================================
%% External functions
%% ====================================================================
get_guild_manor_pid_by_guild_id(GuildId) ->
	UniqueSceneId = lib_guild_manor:get_unique_manor_id(500, GuildId),
	ProcessName = misc:create_process_name(scene_p, [UniqueSceneId, 0]),
	case misc:whereis_name({global, ProcessName}) of
		Pid when is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true -> 
					{ok, Pid};
				false ->
					false
			end;
		_OtherPid ->
			false
	end.

get_guild_manor_pid(SceneId, GuildId, PlayerId, PlayerPid) ->
	UniqueSceneId = lib_guild_manor:get_unique_manor_id(SceneId, GuildId),
	ProcessName = misc:create_process_name(scene_p, [UniqueSceneId, 0]),
	case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
%% 				io:format("the process is built:~p\n", [Pid]),
				add_manor_role_list(Pid, PlayerId, PlayerPid),
				{ok, Pid};
			_OtherPid ->
%% 				io:format("OMG, the process is no built:~p\n", [_OtherPid]),
				start_mod_guild_manor(ProcessName, SceneId, GuildId, PlayerId, PlayerPid, UniqueSceneId)
	end.

%%启动氏族领地进程 (加锁保证全局唯一)
start_mod_guild_manor(ProcessName, SceneId, GuildId, PlayerId, PlayerPid, UniqueSceneId) ->
	global:set_lock({ProcessName, undefined}),	
	ProcessPid =
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> 
						add_manor_role_list(Pid, PlayerId, PlayerPid),
						{ok, Pid};
					false -> 
						start_guild_manor(ProcessName, SceneId, GuildId, PlayerId, PlayerPid, UniqueSceneId)
				end;
			_ ->
				start_guild_manor(ProcessName, SceneId, GuildId, PlayerId, PlayerPid, UniqueSceneId)
		end,	
	global:del_lock({ProcessName, undefined}),
	ProcessPid.

%% start(GuildId, SceneId, RoleList) ->
%% 	{ok, PidManor} = gen_server:start(?MODULE, [GuildId, SceneId, RoleList], []),
%% 	[mod_player:change_manor_pid(PlayerPid) || [_PlayerId, PlayerPid] <- RoleList, PlayerPid =/= From],
%% 	{ok, PidManor}.
start_guild_manor(ProcessName, SceneId, GuildId, PlayerId, PlayerPid, UniqueSceneId) ->
	{ok,PidManor} = gen_server:start(?MODULE, [ProcessName, SceneId, GuildId, PlayerId, PlayerPid, UniqueSceneId], []),
	{ok,PidManor}.

get_manor_id(SceneInitId, GuildId, ManorPid) ->
	gen_server:call(ManorPid, {get_manor_id, SceneInitId, GuildId}).
%% ====================================================================
%% Server functions
%% ====================================================================
%%添加领地玩家列表
%%玩家上线了，列表相应的数据设为online
add_manor_role_list(PidManor, PlayerId, PlayerPid) ->
	gen_server:call(PidManor, {add_manor_role_list, PlayerId, PlayerPid}).

%%玩家退出氏族领地，从列表中去掉
quit_manor_role_list(PidManor, PlayerId) ->
	case misc:is_process_alive(PidManor) of
		false ->
			false;
		true ->
			PidManor ! {quit, PlayerId, 0}
	end.

get_manor_info(UniqueManorId) ->
	SceneProcessName = misc:create_process_name(scene_p, [UniqueManorId, 0]),
	case misc:whereis_name({global, SceneProcessName}) of
		Pid when is_pid(Pid) ->
			gen_server:call(Pid, {info});
		_ -> {error, undefined}
	end.

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([ProcessName, SceneId, GuildId, PlayerId, PlayerPid, UniqueSceneId]) ->
%% 	erlang:send_after(10000, self(), {create_mon_boss, UniqueSceneId}),
	process_flag(trap_exit, true),
	misc:register(global, ProcessName, self()), %% 多节点的情况下， 仅启用一个对应的氏族进程
	case PlayerId of
		0 ->
			ManorRoleList = [];
		_ ->
			ManorRoleList = [#manor_role{id = PlayerId, pid = PlayerPid, is_online = true}]
	end,
		
	lib_scene:copy_scene(UniqueSceneId, SceneId),  %% 复制场景
	lib_guild_manor:check_guild_boss(GuildId),
	State = #state{scene_id = SceneId,				%%场景原始id
				guild_id = GuildId,					%%氏族id
				manor_role_list = ManorRoleList,	%%领地内玩家列表
				boss_number = false},		%%默认设置
	misc:write_monitor_pid(self(), ?MODULE, {State}),
%% 	io:format("init the guild manor ok\n"),
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
%% 	%% ?DEBUG("mod_scene_apply_call: [~p/~p/~p]", [Module, Method, Args]),	
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_scene_apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
			 error;
		 DataRet -> DataRet
	end,
    {reply, Reply, State};

%%检查进入领地
handle_call({get_manor_id, SceneInitId, GuildId}, _From, State) ->
	UniqueId = lib_guild_manor:get_unique_manor_id(SceneInitId, GuildId),
	SceneProcessName = misc:create_process_name(scene_p, [UniqueId, 0]),
	misc:register(global, SceneProcessName, self()),
	lib_scene:copy_scene(UniqueId, SceneInitId),%%复制领地场景数据
	NewStatus = State#state{manor_scene_id = UniqueId},
	{reply, UniqueId, NewStatus};

handle_call({add_manor_role_list, PlayerId, PlayerPid}, _From, State) ->
	NewRoleElem = #manor_role{id = PlayerId, pid = PlayerPid, is_online = true},
	NewState = State#state{manor_role_list = [NewRoleElem|State#state.manor_role_list]},
%% 	io:format("the roleList is: ~p\n", [NewState#state.manor_role_list]),
	{reply, true, NewState};

handle_call({info}, _From, State) ->
	{reply, {ok, State}, State};

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
%% 	%% ?DEBUG("mod_scene_apply_cast: [~p/~p/~p]", [Module, Method, Args]),	
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

handle_cast({'guild_call_boss', Status, Type}, State) ->
	Result = lib_guild_manor:guild_call_boss(Status, Type),
	{ok, BinData} = pt_40:write(40024, [Result]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	{noreply, State};

%%召唤boss
handle_cast({create_mon_boss, GuildId, MonId, X, Y, MonName, GuildName}, State) ->
	UniqueSceneId = lib_guild_manor:get_unique_manor_id(500, GuildId),
	%mod_mon_create:create_mon([MonId, UniqueSceneId, X, Y, 1, []]),
	MonAutoId = mod_mon_create:get_mon_auto_id(1),
	mod_mon_create:create_mon_action(MonId, UniqueSceneId, X, Y, 1, [], MonAutoId),
	%%广播
	ConTent = io_lib:format("<font color='#FEDB4F;'>[~s]</font>穿过了时空的裂缝出现在<font color='#FEDB4F;'>[~s]</font>的氏族领地上，氏族成员们请速去支援族长。",
							[MonName, GuildName]),
	spawn(lib_chat, broadcast_sys_msg, [1, ConTent]),
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
handle_info({quit, PlayerId, Type}, State) ->
%% 	io:format("40034_1_/~p\n", [PlayerId]),
	case lists:keyfind(PlayerId, #manor_role.id, State#state.manor_role_list) of
		false ->
%% 			io:format("error no person\n"),
			{noreply, State};
		Role ->
			case misc:is_process_alive(Role#manor_role.pid) of
				true ->
%% 					io:format("40034_2_/~p\n", [Role#manor_role.pid]),
					lib_guild_manor:send_out_guild_manor(Role#manor_role.pid, State#state.scene_id, Type);
				false ->
%% 					io:format("offline \n"),
					offline
			end,
			NewRoleList = lists:keydelete(PlayerId, #manor_role.id, State#state.manor_role_list),
			NewState = State#state{manor_role_list = NewRoleList},
%% 			io:format("the roleList is: ~p\n", [NewRoleList]),
			%%此处场景进程不再关闭，因为有可能有个boss在领地中
%% 			case NewRoleList of
%% 				[] ->
%% 					erlang:send_after(?MANOR_PRO_KILLSELF_TIME, self(), {'KELL_SELF'});
%% 				_Other ->
%% 					no_action
%% 			end,
			{noreply, NewState}
	end;
handle_info({quit_all}, State) ->
	lists:map(fun(Elem) -> 
					  #manor_role{pid = PlayerPid} = Elem,
					  case misc:is_process_alive(PlayerPid) of
						  true ->
							  lib_guild_manor:send_out_guild_manor(PlayerPid, State#state.scene_id, 1);
						  false ->
							  offline
					  end
			  end, State#state.manor_role_list),
	terminate(kill_self, State),
	{noreply, State};
	
handle_info({logout, PlayerId}, State) ->
	NewRoleList = lists:keydelete(PlayerId, #manor_role.id, State#state.manor_role_list),
	NewState = State#state{manor_role_list = NewRoleList},
%% 	io:format("the roleList is: ~p\n", [NewRoleList]),
	%%此处场景进程不再关闭，因为有可能有个boss在领地中
%% 	case NewRoleList of
%% 		[] ->
%% 			erlang:send_after(?MANOR_PRO_KILLSELF_TIME, self(), {'KELL_SELF'});
%% 		_Other ->
%% 			no_action
%% 	end,
	{noreply, NewState};
%%进程自动退出
handle_info({'KELL_SELF'}, State) ->
	RoleList = State#state.manor_role_list,
	case RoleList of
		[] ->
			terminate(kill_self, State);
		_Other ->
			noaction
	end,
	{noreply, State};
			
handle_info({create_mon_boss, GuildId, GuildName, MonId, MonName, X, Y}, State) ->
	UniqueSceneId = lib_guild_manor:get_unique_manor_id(500, GuildId),
	%mod_mon_create:create_mon([MonId, UniqueSceneId, X, Y, 1, []]),
	MonAutoId = mod_mon_create:get_mon_auto_id(1),
	mod_mon_create:create_mon_action(MonId, UniqueSceneId, X, Y, 1, [], MonAutoId),
	%%广播
	ConTent = io_lib:format("<font color='#FEDB4F;'>~s</font>穿过了时空的裂缝出现在<font color='#FEDB4F;'>~s</font>的氏族领地上，氏族成员们请速去支援族长。",
							[MonName, GuildName]),
	spawn(lib_chat, broadcast_sys_msg, [1, ConTent]),
	{noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
%% 	io:format("terminate the guild manor! OK \n"),
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
%%传出指定的成员
quit_guild_manor(Type, Param) ->
%% 	io:format("quit_guild_manor\n"),
	case Type of
		1 ->%%传自己
			{PidScene, SceneId, PlayerId, PlayerGuildId, SOType} = Param,
			case lib_guild_manor:is_guild_manor_scene(SceneId, PlayerGuildId) of
						true ->
%% 							io:format("ok\n"),
							PidScene ! {quit, PlayerId, SOType};
						false ->%%不在领地里
							not_inside
					end;
		0 ->%传别人
			{PlayerId, GuildId, SOType} = Param,
%% 			io:format("send the member!\n"),
			case lib_player:get_online_info_fields(PlayerId, [scene, pid_scene]) of
				[] ->%%已经下线
%% 					io:format("quit_guild_manor,off_line\n"),
					not_inside;
				[SceneId, PidScene] ->
					case lib_guild_manor:is_guild_manor_scene(SceneId, GuildId) of
						true ->
%% 							io:format("ok\n"),
							PidScene ! {quit, PlayerId, SOType};
						false ->%%不在领地里
%% 							io:format("ont_inside\n"),
							not_inside
					end
			end
	end.

%%传出指定氏族在领地中的所有成员
send_out_all_manor(GuildId) ->
	case get_guild_manor_pid_by_guild_id(GuildId) of
		{ok, PidScene} ->
			PidScene ! {quit_all};
		false ->
			no_action
	end.

%%判断是否在领地中，返回相关的场景坐标
get_outside_scene(Player) ->
	#player{scene = SceneId,
%% 			x = X,
%% 			y = Y,
			guild_id = GuildId} = Player,
	
	case lib_guild_manor:get_scene_Id_from_scene_unique_id(SceneId, GuildId) of
		500 ->
			%%产生种子
			{MegaSecs, Secs, MicroSecs} = now(),
			random:seed({MegaSecs, Secs, MicroSecs}),
			Num = random:uniform(4),
			{X, Y} = lists:nth(Num, ?GUILD_MANOR_COORD), %%随机产生一对坐标
			[500, X, Y];
		_NewSceneId when SceneId rem 10000 =/= ?BOX_SCENE_ID andalso SceneId rem 10000 =/= ?BOXS_PIECE_ID andalso  SceneId > ?GUILD_MANOR_PID ->
			{ReSceneId, ReX, ReY} = lib_guild_manor:get_manor_sentout_coord(1, Player#player.id),
			[ReSceneId, ReX, ReY];
		_ ->
			false
	end.

%% %% ====================================================================
%% %% External functions(氏族福利接口)
%% %% ====================================================================
%% %% -----------------------------------------------------------------
%% %% 40024 查询今日是否领取过福利
%% %% -----------------------------------------------------------------
%% check_member_weal(LTGetWeal) ->
%% 	lib_guild_weal:check_member_weal(LTGetWeal).

%% -----------------------------------------------------------------
%% 40025 领取福利
%% -----------------------------------------------------------------
check_get_member_weal(Status, LTGetWeal) ->
	lib_guild_weal:check_get_member_weal(Status, LTGetWeal).

get_guild_level(GuildId, PlayerId) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
							 {apply_call, lib_guild_weal, get_guild_level, 
							  [GuildId, PlayerId]})	of
			 error -> 
				 %% ?DEBUG("40001 create_guild error",[]),
				 fail;
			Data -> 
				 %% ?DEBUG("40001 create_guild succeed:[~p]",[Data]),
				 Data
		end			
	catch
		_:_Reason -> 
			%% ?DEBUG("40001 create_guild for the reason:[~p]",[_Reason]),
			fail
	end.
		
%% -----------------------------------------------------------------
%% 40026  获取氏族高级技能信息
%% -----------------------------------------------------------------
get_guild_skilltoken(Status, GuildId) ->
	gen_server:cast(mod_guild:get_mod_guild_pid(),
					{apply_cast, lib_guild_weal, get_guild_skilltoken, 
					 [Status#player.other#player_other.pid_send,
					  GuildId]}).

%% -----------------------------------------------------------------
%% 40027  高级技能升级 
%% -----------------------------------------------------------------
upgrade_h_skill(Status, GuildId, HSkillId, HKLevel) ->
	%%因为涉及到并发问题，此操作专门使用Id号为24的进程执行
	ProcessName = misc:create_process_name(guild_p, [24]),
	GuildPid = 
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true ->
						Pid;
					false ->
						mod_guild:start_mod_guild(ProcessName)
				end;
			_ ->
				mod_guild:start_mod_guild(ProcessName)
		end,
	try 
		case gen_server:call(GuildPid, 
						{apply_call, lib_guild_weal, upgrade_h_skill, 
						 [Status#player.guild_id,
						  Status#player.guild_position,
						  GuildId, HSkillId, HKLevel]})	of
			 error -> 
				 %% ?DEBUG("40032 guild_skills_upgrade error",[]),
				 [0, HKLevel, 0];
			 Data -> 
				 %% ?DEBUG("40032 guild_skills_upgrade succeed:[~p]",[Data]),
				 Data
		end			
	catch
		_:_Reason -> 
			%% ?DEBUG("40032 guild_skills_upgrade fail for the reason:[~p]", [_Reason]),
			[0, HKLevel, 0]
	end.

%% -----------------------------------------------------------------
%% 40017 召唤氏族boss
%% -----------------------------------------------------------------
guild_call_boss(Status, Type, IsOk) ->
	GuildId = Status#player.guild_id,
	if 
		GuildId =:= 0 ->
		   [0];
		IsOk =:= false ->%%还未接任务
			[7];
		true  ->
				%%因为涉及到并发问题，此操作专门使用Id号为24的进程执行
			ProcessName = misc:create_process_name(guild_p, [42]),
			GuildPid = 
				case misc:whereis_name({global, ProcessName}) of
					Pid when is_pid(Pid) ->
						case misc:is_process_alive(Pid) of
							true ->
								Pid;
							false ->
								mod_guild:start_mod_guild(ProcessName)
						end;
					_ ->
						mod_guild:start_mod_guild(ProcessName)
				end,
			try 
				case gen_server:call(GuildPid, {apply_call, lib_guild_weal, lib_guild_call_boss, 
									  [Status#player.other#player_other.pid_scene, 
									   Status#player.guild_position, GuildId, Type]})	of
					error -> 
						%% ?DEBUG("40001 create_guild error",[]),
						[0];
					Data -> 
						%% ?DEBUG("40001 create_guild succeed:[~p]",[Data]),
						Data
				end			
			catch
				_:_Reason -> 
					%% ?DEBUG("40001 create_guild for the reason:[~p]",[_Reason]),
					[0]
			end
	end.
				
			