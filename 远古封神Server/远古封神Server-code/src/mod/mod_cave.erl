%%%-----------------------------------
%%% @Module  : mod_cave
%%% @Author  : dhq
%%% @Created : 2011.10.18
%%% @Description: 幻魔穴
%%%-----------------------------------
-module(mod_cave).
-behaviour(gen_server).

-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

-compile([export_all]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {
	dungeon_scene_id = 0,						%% 副本唯一id
	scene_id = 0,								%% 场景原始id	
    pid_team = 0,								%% 队伍进程Pid
    dungeon_role_list = [],   					%% 副本服务器内玩家列表
	teminate_timer = undefined,					%% 玩家掉线副本结束定时器
	zone = 0,									%% 区域
	mon_id_list1 = [],							%% 区域1怪物ID列表
	mon_id_list2 = [],							%% 区域2怪物ID列表
	zone_2_att_num = 0,							%% 第二个区域怪物攻击波数
	send_id_list = [],
	first_in_list = [],
	is_zone2_start = 0,
	is_zone3_start = 0,
	drop_id = 1
}).

-record(dungeon_role, {
	id = 0, 
	pid = undefined
}).

-define(CHECK_ALIVE_INTERVAL, 10 * 60 * 1000).		%% 定时器1间隔时间(定时检查角色进程, 如果不在线，则送出副本)
-define(CAVE_TERMINATE_INTERVAL, 7200 * 1000).		%% 副本2小时后关闭
-define(REFRESH_MON_INTERVAL, 3000).				%% 第二个区域刷怪间隔				


%% ----------------------- 对外接口 ---------------------------------
%% 进入幻魔穴
check_cave_enter(PlayerId, SceneResId, ScenePid, X, Y, SceneUniqueId, SceneElem) ->
	case catch gen:call(ScenePid, '$gen_call', {'CHECK_CAVE_ENTER', PlayerId, SceneResId, X, Y, SceneUniqueId, SceneElem}, 5000) of
		{'EXIT', _Reason} ->
			{false, <<"系统繁忙，请稍候重试！">>};
		{ok, Result} ->
			Result
	end.

%% 创建副本进程，由lib_scene调用
start(PidTeam, FromPlayerPid, SceneId, RoleList) ->
    {ok, PidDungeon} = gen_server:start(?MODULE, [PidTeam, SceneId, RoleList], []),
    [clear(PlayerPidDungeon) || {_PlayerId, _PlayerPid, PlayerPidDungeon} <- RoleList],
    [mod_player:set_dungeon(PlayerPid, PidDungeon) || {_PlayerId, PlayerPid, _PlayerPidDungeon} <- RoleList, PlayerPid =/= FromPlayerPid],
    {ok, PidDungeon}.

%% 主动加入新的角色
join(PidDungeon, PlayerInfo) ->
    case misc:is_process_alive(PidDungeon) of
   		true ->
			gen_server:call(PidDungeon, {join, PlayerInfo});
		false -> 
			false
    end.

%% 从副本清除角色(Type=0, 则不回调设置)
quit(PidDungeon, Rid, Type) ->
    case is_pid(PidDungeon) of
        false -> 
			false;
        true -> 
			PidDungeon ! {quit, Rid, Type}
    end.

%% 清除副本进程
clear(DungeonPid) ->
    case is_pid(DungeonPid) of
        true ->
			DungeonPid ! role_clear;
		false ->
			skip
    end.	
  
%% 获取玩家所在副本的外场景
get_outside_scene(SceneId) ->
	SceneResId = lib_scene:get_res_id(SceneId),
    case get_dungeon_id(SceneResId) of
        0 -> 
			false;
        DungeonId ->
			Dungeon = data_dungeon:get(DungeonId),
            [DungeonId, Dungeon#dungeon.out]
    end.

%% 检查是否存活
check_alive(DungeonPid, Num) ->
	case is_pid(DungeonPid) of
		true -> 
			DungeonPid ! {check_alive, Num};
		false ->
			skip
    end.

%% 幻魔穴杀怪
kill_cave_mon(DungeonPid, MonId) ->
    case is_pid(DungeonPid) of
       	true -> 
			DungeonPid ! {'KILL_CAVE_MON', MonId};
		false ->
			skip
    end.

%% 创建70副本场景
%% SceneUniqueId 场景资源ID
create_dungeon_scene(SceneResId, State) ->
	%% 获取唯一副本场景id
    SceneUniqueId = mod_dungeon:get_unique_dungeon_id(SceneResId),
	SceneProcessName = misc:create_process_name(scene_p, [SceneUniqueId, 0]),
	misc:register(global, SceneProcessName, self()),
    %% 复制场景
	lib_scene:copy_scene(SceneUniqueId, SceneResId),
	%% 场景怪物列表
	MS = ets:fun2ms(fun(M) when M#ets_mon.scene == SceneUniqueId, M#ets_mon.hp > 0, M#ets_mon.type /= 101, M#ets_mon.mid /= 41109 -> M#ets_mon.id end),
	MonIdList = ets:select(?ETS_SCENE_MON, MS),
	%% 更新副本场景的唯一ID
    NewState = State#state{
		dungeon_scene_id = SceneUniqueId,
		mon_id_list1 = MonIdList,
		zone = 1
	},    
	misc:write_monitor_pid(self(), ?MODULE, {SceneResId}),
    {SceneUniqueId, NewState}.

%% ------------------------- 服务器内部实现 ---------------------------------
%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([PidTeam, SceneId, RoleList]) ->
    CaveRoleList = [#dungeon_role{id = PlayerId, pid = PlayerPid} || {PlayerId, PlayerPid, _PlayerPidDungeon} <- RoleList],
	Scene = data_scene:get(SceneId),
	SendIdList = get_scene_elem_info([{1, 2}, {2, 1}], Scene#ets_scene.elem, []),
	State = #state{
		scene_id = SceneId,
        pid_team = PidTeam,
        dungeon_role_list = CaveRoleList,
		send_id_list = SendIdList
    },
	Self = self(),
	CheckAliveInterval = erlang:send_after(?CHECK_ALIVE_INTERVAL, Self, check_role_pid),
	put(cave_alive_interval, CheckAliveInterval),
	CaveTerminateTimer = erlang:send_after(?CAVE_TERMINATE_INTERVAL, Self, terminate),
	put(cave_terminate_interval, CaveTerminateTimer),
	misc:write_monitor_pid(Self, ?MODULE, {State}),
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
%% 检查进入幻魔穴
handle_call({'CHECK_CAVE_ENTER', PlayerId, SceneResId, X, Y, PlayerSceneUniqueId, SceneElem}, _From, State) ->
	if 
		SceneResId =:= State#state.scene_id ->
			case State#state.dungeon_scene_id =/= 0 of
           		true ->
					case State#state.zone of
						2 ->
							case PlayerSceneUniqueId =:= ?CAVE_RES_SCENE_ID of
								true ->
                                    ElemId = get_scene_elem_id(SceneElem, X, Y, 10000000, 0),
                                    if
                                        ElemId =:= 2 orelse State#state.zone_2_att_num > 10 ->
                                            NewState =
                                                if
                                                    State#state.is_zone2_start =:= 0 ->
                                                        erlang:send_after(500, self(), {'START_ZONE_2'}),
                                                        State#state{
                                                            is_zone2_start = 1
                                                        };
                                                    true ->
                                                        State
                                                end,
											IsFirstIn =
												case lists:keyfind(PlayerId, 1, State#state.first_in_list) of
        											false ->
														1;
													_ ->
														0
												end,
                                            {reply, {true, State#state.dungeon_scene_id, 35, 90, IsFirstIn}, NewState};
                                        true ->
                                            {reply, {false, <<"第二区域怪还没打完">>}, State}
                                    end;
								false ->
									IsFirstIn =
										case lists:keyfind(PlayerId, 1, State#state.first_in_list) of
        									false ->
												1;
											_ ->
												0
										end,
									{reply, {true, State#state.dungeon_scene_id, 35, 90, IsFirstIn}, State}
							end;
						3 ->
							NewState =
								if
									State#state.is_zone3_start =:= 0 ->
										erlang:send_after(500, self(), {'START_ZONE_3_MON'}),
										State#state{
											is_zone3_start = 1
										};
									true ->
										State
								end,
							IsFirstIn =
								case lists:keyfind(PlayerId, 1, State#state.first_in_list) of
        							false ->
										1;
									_ ->
										0
								end,
							{reply, {true, State#state.dungeon_scene_id, 70, 45, IsFirstIn}, NewState};
						_ ->
							case PlayerSceneUniqueId =:= ?CAVE_RES_SCENE_ID of
								true ->
									if
										State#state.mon_id_list1 =:= [] ->
											{reply, {true, State#state.dungeon_scene_id}, State};
										true ->
											{reply, {false, <<"第一区域怪还没打完">>}, State}
									end;
								false ->
									{reply, {true, State#state.dungeon_scene_id}, State}
							end
					end;
              	false ->
					{SceneUniqueId, NewState} = create_dungeon_scene(SceneResId, State),
					misc:write_monitor_pid(self(), ?MODULE, {NewState}),
					{reply, {true, SceneUniqueId}, NewState}
           	end;
		true ->
			{reply, {false, <<"没有这个副本场景">>}, State}
	end;

%% 加入副本服务
handle_call({join, [PlayerId, Player_Pid, Player_Pid_dungeon]}, _From, State) ->
    %% 清除上个副本服务进程
	clear(Player_Pid_dungeon), 
    case lists:keyfind(PlayerId, 2, State#state.dungeon_role_list) of
        false -> 
			NewState = State#state{
				dungeon_role_list = [#dungeon_role{id = PlayerId, pid = Player_Pid} | State#state.dungeon_role_list]
			},
            {reply, true, NewState};
		_DungeonRole ->
			{reply, true, State}
    end;

%% 初始化时，如在副本，则加入副本服务
handle_call({join_init, [PlayerId, PlayerPid]}, _From, State) ->
	case State#state.teminate_timer of
		undefined ->
			skip;
		_ ->
			erlang:cancel_timer(State#state.teminate_timer)
	end,
	RoleList =
    	case lists:keyfind(PlayerId, 2, State#state.dungeon_role_list) of
        	false -> 
    			State#state.dungeon_role_list;
			_ -> 
				lists:keydelete(PlayerId, 2, State#state.dungeon_role_list)
    	end,
    NewRoleList = [#dungeon_role{id = PlayerId, pid = PlayerPid} | RoleList],
	NewState = State#state{
		dungeon_role_list = NewRoleList,
		teminate_timer = undefined
	},
	misc:write_monitor_pid(self(), ?MODULE, {NewState}),
	{reply, true, NewState};

%% 获取区域ID
handle_call('GET_CAVE_ZONE', _From, State) ->
	{reply, State#state.zone, State};

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

%% 统一模块+过程调用(call)
handle_call({apply_call, Module, Method, Args}, _From, State) ->
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_dungeon_apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
			 error;
		 DataRet -> DataRet
	end,
    {reply, Reply, State};

handle_call(_Request, _From, State) ->
    {noreply, State}.

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
?WARNING_MSG("mod_dungeon_apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
			error;
		_ -> ok
	end,
  	{noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

%% 幻魔穴区域信息
handle_cast({'GET_ZONE_INFO', PlayerId, PidSend}, State) ->
	[Zone, NewState] = 
		case lists:keyfind(PlayerId, 1, State#state.first_in_list) of
        	false ->
				FirstInList = [{PlayerId, 1, 0, 0} | State#state.first_in_list],
				RetState = State#state{
					first_in_list = FirstInList
				},
				[1, RetState];
			{_PlayerId, Zone1, Zone2, Zone3} ->
				[RetZone, RetState] =
					case State#state.zone of
						1 ->
							if
								Zone1 =/= 0 ->
									[0, State];
								true ->
									NewFirstIn = {PlayerId, 1, Zone2, Zone3},
									FirstInList = lists:keyreplace(PlayerId, 1, State#state.first_in_list, NewFirstIn),
									RState = State#state{
										first_in_list = FirstInList
									},
									[State#state.zone, RState]
							end;
						2 ->
							if
								Zone2 =/= 0 ->
									[0, State];
								true ->
									NewFirstIn = {PlayerId, Zone1, 1, Zone3},
									FirstInList = lists:keyreplace(PlayerId, 1, State#state.first_in_list, NewFirstIn),
									RState = State#state{
										first_in_list = FirstInList
									},
									[State#state.zone, RState]
							end;
						_ ->
							if
								Zone3 =/= 0 ->
									[0, State];
								true ->
									NewFirstIn = {PlayerId, Zone1, Zone2, 1},
									FirstInList = lists:keyreplace(PlayerId, 1, State#state.first_in_list, NewFirstIn),
									RState = State#state{
										first_in_list = FirstInList
									},
									[State#state.zone, RState]
							end
					end,
				[RetZone, RetState]
    	end,
	{ok, BinData} = pt_31:write(31010, [Zone]),
	lib_send:send_to_sid(PidSend, BinData),
	%% 幻魔穴传送点信息
	SendIdList = send_id_list(State#state.send_id_list, State#state.zone, []),
	{ok, SendIdListBinData} = pt_12:write(12071, SendIdList),
	lib_send:send_to_sid(PidSend, SendIdListBinData),
	{noreply, NewState};

%% 怪物特定范围伤害
handle_cast({'LAST_AREA_DAM', Hurt, Last, AttArea, SceneId, X, Y, SkillId}, State) ->
	erlang:send_after(1000, self(), {'LAST_AREA_DAM', Hurt, Last, AttArea, SceneId, X, Y}),
	{ok, BinData} = pt_20:write(20103, [X, Y, (Last + 1) * 1000, SkillId]),
	lib_send:send_to_online_scene(SceneId, X, Y, BinData),
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
%% 在副本里创建队伍，需要设置到副本进程
handle_info({set_team, Pid_team}, State) ->
	NewState = State#state{pid_team = Pid_team},
  	{noreply, NewState};

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

%% 幻魔穴杀怪
handle_info({'KILL_CAVE_MON', MonId}, State) ->
	NewState = 
		case State#state.zone of
			1 ->
				MonIdList = lists:delete(MonId, State#state.mon_id_list1),
				case MonIdList =:= [] of
					%% 第一区域怪物打完
					true ->
						%% 幻魔穴传送点信息
						SendIdList = send_id_list(State#state.send_id_list, 2, []),
						{ok, SendIdListBinData} = pt_12:write(12071, SendIdList),
						send_cave_player(State#state.dungeon_role_list, SendIdListBinData),
						State#state{
							zone = 2,
							zone_2_att_num = 1,
							mon_id_list1 = MonIdList		
						};
					false ->
						State#state{
							mon_id_list1 = MonIdList		
						}
				end;
			2 ->
				MonIdList = lists:delete(MonId, State#state.mon_id_list2),
				case MonIdList =:= [] of
					true ->
						erlang:send_after(?REFRESH_MON_INTERVAL, self(), {'START_ZONE_2_MON'}),
						State#state{
							zone_2_att_num = State#state.zone_2_att_num + 1,
							mon_id_list2 = MonIdList		
						};
					false ->
						State#state{
							mon_id_list2 = MonIdList		
						}
				end;
			_ ->
				State
		end,
	{noreply, NewState};

%% 第二区域怪物开启
handle_info({'START_ZONE_2'}, State) ->
	%% 生成镇妖剑
	Len = 1 + 20,
	AutoId = mod_mon_create:get_mon_auto_id(Len),
	mod_mon_create:create_mon_action(41111, State#state.dungeon_scene_id, 28, 61, 1, [], AutoId),
	%% 第二区域怪物开始
	erlang:send_after(?REFRESH_MON_INTERVAL, self(), {'START_ZONE_2_MON'}),
	{noreply, State};

%% 第二区域怪物生成
handle_info({'START_ZONE_2_MON'}, State) ->
	NewState =
        case get_zone_2_mon_list(State#state.zone_2_att_num) of
            [] ->
				%% 幻魔穴传送点信息
				SendIdList = send_id_list(State#state.send_id_list, 3, []),
				{ok, SendIdListBinData} = pt_12:write(12071, SendIdList),
				send_cave_player(State#state.dungeon_role_list, SendIdListBinData),
				State#state{
					zone = 3,
					mon_id_list2 = []
				};
            AttMon ->
				[X, Y] = 
					case random:uniform(4) of
						1 ->
							[39, 63];
						2 ->
							[28, 49];
						3 ->
							[17, 63];
						_ ->
							[30, 77]
					end,
                create_zone_2_mon(AttMon, X, Y, State#state.dungeon_scene_id),
                MS = ets:fun2ms(fun(M) when M#ets_mon.scene == State#state.dungeon_scene_id, M#ets_mon.hp > 0, M#ets_mon.type /= 101, M#ets_mon.mid /= 41109 -> M#ets_mon.id end),
                MonIdList = ets:select(?ETS_SCENE_MON, MS),
                %% 更新副本场景的唯一ID
                State#state{
                    mon_id_list2 = MonIdList
                }
        end,
	{noreply, NewState};

%% 第三区域怪物生成
handle_info({'START_ZONE_3_MON'}, State) ->
	%% 生成第三区域的怪
	Len = 1 + 10,
	AutoId = mod_mon_create:get_mon_auto_id(Len),
	mod_mon_create:create_mon_action(41109, State#state.dungeon_scene_id, 83, 32, 1, [], AutoId),
	{noreply, State};

%% 将指定玩家传出副本
handle_info({quit, Rid, Type}, State) ->
    case lists:keyfind(Rid, 2, State#state.dungeon_role_list) of
        false ->
			{noreply, State};
        Role ->
			if 
				Type > 0 ->
					case misc:is_process_alive(Role#dungeon_role.pid) of
                		true ->
                    		send_out(Role#dungeon_role.pid, State#state.scene_id);
						_-> 
							offline
            		end;
			   	true -> 
					no_action
			end,
			NewState = State#state{
				dungeon_role_list = lists:keydelete(Rid, 2, State#state.dungeon_role_list)
			},
			misc:write_monitor_pid(self(), ?MODULE, {NewState}),
            {noreply, NewState}			
    end;

%% 清除角色, 关闭副本服务进程
handle_info(role_clear, State) ->
	case misc:is_process_alive(State#state.pid_team) of
        true -> %% 有组队
            case length(State#state.dungeon_role_list) >= 1 of  %% 判断副本是否没有人了
                true ->
					erlang:send_after(1000, self(), {check_alive, 0}),
                    {noreply, State};
                false ->
					gen_server:cast(State#state.pid_team, {clear_dungeon}),
                    {stop, normal, State}
            end;
        false ->
            {stop, normal, State}
    end;

%% 定时检查角色进程, 如果不在线，则送出副本
handle_info(check_role_pid, State) ->
	NewRoleList = get_role_alive_list(State),
	case length(NewRoleList) >= 1 of
		 true -> 
			erlang:send_after(?CHECK_ALIVE_INTERVAL, self(), check_role_pid),
			NewState = State#state{dungeon_role_list = NewRoleList},
			misc:write_monitor_pid(self(), ?MODULE, {NewState}),
			{noreply, NewState};			 
		 _ -> %% 没有角色啦，则 清除副本
			case misc:is_process_alive(State#state.pid_team) of
        		true -> %% 有组队, 通知队伍进程	
					gen_server:cast(State#state.pid_team, {clear_dungeon});
				_ -> no_action
			end,
			{stop, normal, State}
	end;

%% 检查存活数
handle_info({check_alive, Num}, State) ->
	NewRoleList = get_role_alive_list(State),
	case length(NewRoleList) > Num of
		true -> 
			{noreply, State};			 
		_ ->
			case State#state.teminate_timer of
				undefined ->
					TeminateTimer = erlang:send_after(300 * 1000, self(), 'INTERVAL_CHECK_ALIVE'),
					NewState = State#state{
						teminate_timer = TeminateTimer   
					},
					{noreply, NewState};
				_ ->
					{noreply, State}
			end
	end;

%% 间断检测是否还有活人
handle_info('INTERVAL_CHECK_ALIVE', State) ->
	case State#state.teminate_timer of
		undefined ->
			skip;
		_ ->
			erlang:cancel_timer(State#state.teminate_timer)
	end,
	NewState = State#state{
		teminate_timer = undefined   
	},
	NewRoleList = get_role_alive_list(NewState),
	case length(NewRoleList) > 0 of
		true ->
			{noreply, NewState};
		false ->
			case misc:is_process_alive(State#state.pid_team) of
        		true -> %% 有组队, 通知队伍进程	
					gen_server:cast(State#state.pid_team, {clear_dungeon});
				_ -> 
					no_action
			end,
			{stop, normal, NewState}
	end;

%% 副本关闭
handle_info(terminate, State) ->
	NewRoleList = get_role_alive_list(State),
	case length(NewRoleList) >= 1 of
		true ->
			F = fun(Role) ->
				send_out(Role#dungeon_role.pid, State#state.scene_id)
			end,
			lists:foreach(F, NewRoleList);
		false ->
			skip
	end,
	{stop,normal,State};

handle_info(_Info, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, State) ->
	misc:cancel_timer(cave_alive_interval),
	misc:cancel_timer(cave_terminate_interval),
	%% 副本关闭清理资源
 	spawn(fun()-> lib_scene:clear_scene(State#state.dungeon_scene_id) end),
	misc:delete_monitor_pid(self()),	
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% -----------------------------私有方法--------------------------------
%% 传送出副本
send_out(Pid, SceneId) ->
	DungeonData = data_dungeon:get(SceneId),
	[NewSenceId, X, Y] = DungeonData#dungeon.out,
	gen_server:cast(Pid, {send_out_dungeon, [NewSenceId, X, Y]}).

%% 用场景资源获取副本id
get_dungeon_id(SceneResId) ->
    F = fun(DungeonId, P) ->
		Dungeon = data_dungeon:get(DungeonId),
		case lists:keyfind(SceneResId, 1, Dungeon#dungeon.scene) of
       		false -> 
				P;
           	_ -> 
				DungeonId
        end
    end,
    lists:foldl(F, 0, data_scene:dungeon_get_id_list()).

%% 获取存活的角色列表
get_role_alive_list(State) ->
	lists:filter(fun(Role)-> 
		misc:is_process_alive(Role#dungeon_role.pid) end, 
	State#state.dungeon_role_list).

%% 第二个区域的怪物刷新
get_zone_2_mon_list(Num) ->
	case Num of
		1 ->
			[{41103, 5}];
		2 ->
			[{41103, 5}];
		3 ->
			[{41103, 5}];
		4 ->
			[{41103, 5}];
		5 ->
			[{41108, 1}];
		6 ->
			[{41104, 5}];
		7 ->
			[{41104, 5}];
		8 ->
			[{41104, 5}];
		9 ->
			[{41104, 5}];
		10 ->
			[{41107, 1}];
		_ ->
			[]
	end.


%% 对幻魔穴的玩家发送信息
send_cave_player(RoleList, BinData) ->
	[lib_send:send_to_uid(Role#dungeon_role.id, BinData) || Role <- RoleList].


create_zone_2_mon([], _X, _Y, _SceneId) ->
	skip;
create_zone_2_mon([{MonId, Num} | M], X, Y, SceneId) ->
	lib_scene:load_mon_td({MonId, X, Y, Num}, SceneId),
	create_zone_2_mon(M, X, Y, SceneId).

%% 传送点列表
send_id_list([], _ZoneId, SendIdList) ->
	SendIdList;
send_id_list([{Z, SceneIndex, SceneId, SceneName, SceneX, SceneY} | S], ZoneId, SendIdList) ->
	if
		ZoneId > Z ->
			send_id_list(S, ZoneId, [{SceneIndex, SceneId, SceneName, SceneX, SceneY} | SendIdList]);
		true ->
			send_id_list(S, ZoneId, SendIdList)
	end.

get_scene_elem_info([], _SceneElem, SendIdList) ->
	SendIdList;
get_scene_elem_info([{ZoneId, SceneIndex} | E], SceneElem, SendIdList) ->
	case get_scene_elem_info_loop(SceneElem, SceneIndex, []) of
		[] ->
			get_scene_elem_info(E, SceneElem, SendIdList);
		[_SceneIndex, SceneId, SceneName, SceneX, SceneY] ->
			get_scene_elem_info(E, SceneElem, [{ZoneId, SceneIndex, SceneId, SceneName, SceneX, SceneY} | SendIdList])
	end.
get_scene_elem_info_loop([], _SI, ElemInfo) ->
	ElemInfo;
get_scene_elem_info_loop([[SceneIndex, SceneId, SceneName, SceneX, SceneY] | E], SI, ElemInfo) ->
	if
		SceneIndex =:= SI ->
			[SceneIndex, SceneId, SceneName, SceneX, SceneY];
		true ->
			get_scene_elem_info_loop(E, SI, ElemInfo)	
	end.

get_scene_elem_id([], _PX, _PY, _Dist, ElemId) ->
	ElemId;
get_scene_elem_id([[Index, _SceneId, _Name, X, Y] | E], PX, PY, Dist, ElemId) ->
	Len = abs(X - PX) + abs(Y - PY),    
    {NewDist, NewElemId} =
        case Dist > Len of
            true -> 
				{Len, Index};
            false -> 
				{Dist, ElemId}
        end,
	get_scene_elem_id(E, PX, PY, NewDist, NewElemId).
	
