%%%------------------------------------
%%% @Module  : mod_mon_active
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 怪物活动状态
%%%------------------------------------
-module(mod_mon_active).
-behaviour(gen_fsm).
-export(
   [
        start/1,
        sleep/2,
        trace/2,
        revive/2,
        back/2
	]
).
-export(
    [
        init/1, 
        handle_event/3, 
        handle_sync_event/4, 
        handle_info/3, 
        terminate/3, 
        code_change/4
    ]
).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

-define(SLEEP_TIME, 3600000).							%% 睡眠时间
-define(DUNGEON_SLEEP_TIME, 4000).

-record(state, {    
	battle_limit = 0,									%% 战斗时的一些受限制状态，1 定身，2昏迷，3沉默（封技）
	player_list = [],								
	d_x = 0,											%% 出生点X
	d_y = 0,											%% 出生点Y
	die_time = 0,										%% 死亡次数
	scene_pid = undefined,								%% 场景进程
	speed = 0,											%% 怪物速度	
	action_timer = undefined,							%% 怪物动作定时器
	sleep_time = 0				
}).

%% 开启一个怪物活动进程，每个怪物一个进程
start(Minfo) ->
    gen_fsm:start_link(?MODULE, Minfo, []).

init([M, MonId, SceneId, X, Y, Type, ScenePid]) ->
	process_flag(trap_exit, true),
	AttMin = 
		if
			M#ets_mon.max_attack > M#ets_mon.min_attack ->
				M#ets_mon.min_attack;
			true ->
				M#ets_mon.max_attack - 1
		end,
    Minfo = M#ets_mon{
        id = MonId,
        scene = SceneId,
        x = X,
        y = Y,
        skill = [],        
        pid = self(),
		min_attack = AttMin,
        battle_status = [],
        unique_key = {SceneId, MonId},
		status = 0,
		relation = []
    },
    ets:insert(?ETS_SCENE_MON, Minfo),
	misc:write_monitor_pid(self(), ?MODULE, {}),
	SleepTime = 
		%% 判断是否主动怪
		if
			Minfo#ets_mon.att_type =/= 0 ->
				?DUNGEON_SLEEP_TIME;
			true ->
				?SLEEP_TIME
		end,
	State = #state{
		d_x = X,
		d_y = Y,
		scene_pid = ScenePid,
		speed = M#ets_mon.speed,
		sleep_time = SleepTime			   
	},
	RT = 
		if
			Type == 0 ->
				?SLEEP_TIME;
			%% 怪物动态生成
			true ->
				lib_mon:dynamic_create_mon(Minfo, SceneId, X, Y),
				1000
		end,
	put(delay_revive_timer, undefined),
    {ok, sleep, [[], Minfo, State], RT}.

handle_event(_Event, StateName, Status) ->
    {next_state, StateName, Status}.

handle_sync_event(_Event, _From, StateName, Status) ->
    {reply, ok, StateName, Status}.

%% 记录战斗结果
handle_info({'MON_BATTLE_RESULT', [Hp, CurAttId, CurAttPid, _AttCareer]}, StateName, [AttObj, Minfo, State]) ->
	case Minfo#ets_mon.hp > 0 of
		true ->
			NewState = 
				case lists:member(CurAttId, State#state.player_list) of
					false ->
						PlayerList = [CurAttId | State#state.player_list],
						State#state{ player_list=PlayerList };
					true -> 
						State
				end,
			NewMinfo = Minfo#ets_mon{
          		hp = Hp
            },
            ets:insert(?ETS_SCENE_MON, NewMinfo),
            case Hp > 0 of
                true ->
                    case StateName of
                        trace ->
                            {next_state, trace, [AttObj, NewMinfo, NewState]};
                        _ ->
							TraceState = send_event_after(NewState, Minfo#ets_mon.att_speed),
                            {next_state, trace, [[CurAttId, CurAttPid], NewMinfo, TraceState]}	
                    end;
                false ->
                    mon_revive(NewMinfo, NewState, StateName, AttObj, CurAttId)
            end;
		false ->
			mon_revive(Minfo, State, StateName, AttObj, CurAttId)
	end;

%% 开始一个怪物持续流血的计时器	
handle_info({'START_HP_TIMER', CurAttId, CurAttPid, Hurt,ValType, Time, Interval}, StateName, [AttObj, Minfo, State]) ->	
	misc:cancel_timer(bleed_timer),
	case Minfo#ets_mon.hp > 0 of
		true ->	
			if
				ValType == 0 ->
					NewHurt = Hurt;
				true ->
					NewHurt = round(Minfo#ets_mon.hp_lim * (Hurt / 100))
			end,
			MHp = 
				case Minfo#ets_mon.hp > NewHurt of
					true ->
						Minfo#ets_mon.hp - NewHurt;
					false ->
						AttId = 
							case AttObj of
								[PreAttId, _PreAttPid] ->
									PreAttId;
								_ ->
									CurAttId
							end,
						spawn(fun()-> lib_mon:mon_die(Minfo, AttId, State#state.player_list, State#state.d_x, State#state.d_y) end),
						0
				end,
			NewMinfo = Minfo#ets_mon{
				hp = MHp
			},
			ets:insert(?ETS_SCENE_MON, NewMinfo),
          	%% 更新怪物血量，广播给附近玩家
            {ok, BinData} = pt_12:write(12082, [NewMinfo#ets_mon.id, MHp]),
			lib_send:send_to_online_scene(NewMinfo#ets_mon.scene, NewMinfo#ets_mon.x, NewMinfo#ets_mon.y, BinData),
			case MHp > 0 of
				true ->
					NewTime = Time - 1,
					BleedTimer = 
    					case NewTime > 0 of
        					true ->
            					erlang:send_after(Interval, self(), {'START_HP_TIMER', CurAttId, CurAttPid, Hurt,ValType, NewTime, Interval});
        					false ->
            					undefined
    					end,
					put(bleed_timer, BleedTimer),
					{next_state, StateName, [AttObj, NewMinfo, State]};
				false ->
					mon_revive(NewMinfo, State, StateName, AttObj, CurAttId)
			end;			
		false ->
			mon_revive(Minfo, State, StateName, AttObj, CurAttId)
	end;

%% 更改怪物Buff
handle_info({'SET_MON_BUFF', Buff}, StateName, [AttObj, Minfo, State]) ->	
	NewMinfo = Minfo#ets_mon{
        battle_status = Buff        
    },
    ets:insert(?ETS_SCENE_MON, NewMinfo),
	{next_state, StateName, [AttObj, NewMinfo, State]};

handle_info('DELAY_REVIVE', StateName, [_AttObj, Minfo, State]) ->
	case get(delay_revive_timer) of
		undefined ->
			skip;	
		DelayReviveTimer ->
			erlang:cancel_timer(DelayReviveTimer)
	end,
	put(delay_revive_timer, undefined),
	NewMinfo = lib_mon:revive(Minfo, State#state.d_x, State#state.d_y, State#state.speed),
	NewState = State#state{
		battle_limit = 0,									%% 战斗时的一些受限制状态，1 定身，2昏迷，3沉默（封技）
		player_list = [],
		die_time = State#state.die_time + 1					   
	},
	ets:insert(?ETS_SCENE_MON, NewMinfo),
	{next_state, StateName, [[], NewMinfo, NewState]};

%% 更改战斗限制状态
%% ChangeStatus 要更改的状态
%% CurStatus 当前的状态
handle_info({'CHANGE_BATTLE_LIMIT', ChangeStatus, CurStatus}, StateName, [AttObj, Minfo, State]) ->	
	BattleLimit = 
		case ChangeStatus of
			%% 取消限制状态
			0 ->
				%% 判断当前状态是否一样
				case State#state.battle_limit of
					CurStatus ->
						ChangeStatus;						
					_ ->
						State#state.battle_limit						
				end;
			_ ->
				ChangeStatus				
		end,
	NewState = State#state{
		battle_limit = BattleLimit					   
	},
    case BattleLimit of
        0 ->
            case StateName == trace andalso length(AttObj) >= 2 of
                true ->
                    {next_state, trace, [AttObj, Minfo, NewState]};
                false ->
					TraceState = send_event_after(NewState, 1000),
                    {next_state, trace, [AttObj, Minfo, TraceState]}
            end;
        _ ->
            {next_state, StateName, [AttObj, Minfo, NewState]}
    end;

%% 改变怪物速度
%% Speed 速度
handle_info({'CHANGE_SPEED', Speed}, StateName, [AttObj, Minfo, State]) ->	
	NewMinfo = Minfo#ets_mon{
        speed = Speed        
    },
	ets:insert(?ETS_SCENE_MON, NewMinfo),
	{next_state, StateName, [AttObj, NewMinfo, State]};

%% 定时处理怪物信息
%% Interval 倒计时间
%% Message 要处理的消息
handle_info({'SET_TIME_MON', Interval, Message}, StateName, [AttObj, Minfo, State]) ->	
	erlang:send_after(Interval, self(), Message),
	{next_state, StateName, [AttObj, Minfo, State]};

%% 改变怪物坐标
handle_info({'MON_POSITION', X, Y}, StateName, [AttObj, Minfo, State]) ->
	NewMinfo = Minfo#ets_mon{
		x = X,
		y = Y
	},
	ets:insert(?ETS_SCENE_MON, NewMinfo),
	{next_state, StateName, [AttObj, NewMinfo, State]};

handle_info({'SET_MON_LIMIT', Type, Data}, StateName, [AttObj, Minfo, State]) ->
    case Type of
        %% 减速度
        1 ->
            [PreSpeed, CurSpeed, Interval] = Data,
            Message = {'CHANGE_SPEED', PreSpeed},
            erlang:send_after(Interval, self(), Message),
            NewMinfo = Minfo#ets_mon{
                speed = CurSpeed        
            },
            ets:insert(?ETS_SCENE_MON, NewMinfo),
            {next_state, StateName, [AttObj, NewMinfo, State]};
        %% 改变状态
        2 ->
            [BattleLimit, Interval] = Data,
            Message = {'CHANGE_BATTLE_LIMIT', 0, BattleLimit},
            erlang:send_after(Interval, self(), Message),
            handle_info({'CHANGE_BATTLE_LIMIT', BattleLimit, 0}, StateName, [AttObj, Minfo, State]);
        _ ->
            {next_state, StateName, [AttObj, Minfo, State]}
    end;	

%% 清除进程
handle_info(clear, _StateName, [AttObj, Minfo, State]) ->
    {stop, normal, [AttObj, Minfo, State]};

handle_info(clear_outside, _StateName, [AttObj, Minfo, State]) ->
	{ok, BinData} = pt_12:write(12082, [Minfo#ets_mon.id, 0]),
	SceneId = Minfo#ets_mon.scene,
	case lib_scene:is_copy_scene(SceneId) of
		true ->
			lib_send:send_to_online_scene(SceneId, BinData);
		false ->
			lib_send:send_to_online_scene(SceneId, Minfo#ets_mon.x, Minfo#ets_mon.y, BinData)
	end,
	{stop, normal, [AttObj, Minfo, State]};

handle_info(Info, StateName, [AttObj, Minfo, State]) ->
?WARNING_MSG("MON_NO_MSG: /~p/~n", [[Info, StateName, [AttObj, Minfo, State]]]),	
    {next_state, StateName, [AttObj, Minfo, State]}.

terminate(_Reason, _StateName, [_AttObj, Minfo, State]) ->
	cancel_action_timer(State),
	lib_mon:del_mon_data(self(), Minfo#ets_mon.unique_key).

code_change(_OldVsn, StateName, Status, _Extra) ->
    {ok, StateName, Status}.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 处理怪物所有状态
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 静止状态并回血
sleep(timeout, [[], Minfo, State]) ->
	case get(delay_revive_timer) of
		undefined ->
            %% 判断是否死亡
			if
          		Minfo#ets_mon.hp > 0 ->
                    NewMinfo = 
						if
                     		Minfo#ets_mon.status == 0 ->
                                Minfo;
                            true ->
                                NMinfo = Minfo#ets_mon{
                               		status = 0
                                },
                                ets:insert(?ETS_SCENE_MON, NMinfo),
                                NMinfo                		
                        end,
					if
                  		%% 主动怪
						NewMinfo#ets_mon.att_type == 1 ->
                            MonScene = NewMinfo#ets_mon.scene,
                            MonX = NewMinfo#ets_mon.x,
                            MonY = NewMinfo#ets_mon.y,
                            GuardArea = NewMinfo#ets_mon.guard_area,
                            case lib_scene:get_area_user_for_battle(MonScene, MonX, MonY, GuardArea) of
                                [] ->
                             		sleep_action(NewMinfo, State);                           
                                [AttId, AttPid] ->
									TraceState = send_event_after(State, NewMinfo#ets_mon.att_speed),
                                    {next_state, trace, [[AttId, AttPid], NewMinfo, TraceState]}
                            end;
                        %% 被动怪
                       	true -> 
                      		sleep_action(NewMinfo, State)
                    end;
                true ->
					ReviveState = send_event_after(State, round(Minfo#ets_mon.retime / 2)),
                    {next_state, revive, [[], Minfo, ReviveState]}
            end;
		_ ->
			{next_state, sleep, [[], Minfo, State], ?SLEEP_TIME}
	end;    
sleep(_R, Status) ->
    sleep(timeout, Status).

%% 跟踪目标
trace(timeout, [AttObj, Minfo, State])->
	%% 不能为采集、捕捉、镇妖剑
	case lists:member(Minfo#ets_mon.type, [6, 7, 101,36]) of
		false ->
			if
          		Minfo#ets_mon.status /= 1 andalso length(AttObj) >= 2 ->
					[AttId, _AttPid] = AttObj,
					case lib_mon:get_player(AttId, Minfo#ets_mon.scene) of 
                        [] ->
                            {next_state, back, [[], Minfo, State], 1000};
						Player ->
							if
                         		Player#player.hp > 0 ->
                               		attack_or_trace(Minfo, State, Player#player.x, Player#player.y, AttObj, Player);
                                true ->
									ReviveState = send_event_after(State, round(Minfo#ets_mon.retime / 2)),
          							{next_state, revive, [[], Minfo, ReviveState]}
                            end
                    end;
                true ->
                    {next_state, back, [[], Minfo, State], 1000}
            end;
		true ->
			{next_state, sleep, [[], Minfo, State], ?SLEEP_TIME}
    end;
trace(repeat, Status) ->
    trace(timeout, Status);
trace(_R, Status) ->
    trace(timeout, Status).

%% 返回默认出生点
back(timeout, [[], Minfo, State]) ->
    {StateName, NewMinfo, Interval} = lib_mon:back(Minfo, State#state.battle_limit, State#state.d_x, State#state.d_y),
    {next_state, StateName, [[], NewMinfo, State], Interval};
back(_R, Status) ->
    sleep(timeout, Status).

%% 复活
revive(timeout, [_PidList, Minfo, State]) ->
	%% 取消持续流血定时器
	misc:cancel_timer(bleed_timer),
	%% 重生时间大于0且不是副本怪
    case (Minfo#ets_mon.retime > 0 andalso lib_scene:is_copy_scene(Minfo#ets_mon.scene) == false 
			andalso Minfo#ets_mon.type /= 4) orelse Minfo#ets_mon.scene rem 10000 =:= ?BOXS_PIECE_ID of
        true ->
			if
				State#state.die_time > 1000 ->
					AutoId = mod_mon_create:get_mon_auto_id(1),
					gen_server:cast(State#state.scene_pid,
                  			{apply_cast, mod_mon_create, create_mon_action, [Minfo#ets_mon.mid, Minfo#ets_mon.scene, State#state.d_x, State#state.d_y, 1, [], AutoId]}),
					{stop, normal, [[], Minfo, State]};
				true ->
					case get(delay_revive_timer) of
						undefined ->
							DelayReviveTimer = erlang:send_after(round(Minfo#ets_mon.retime / 2), self(), 'DELAY_REVIVE'),
							put(delay_revive_timer, DelayReviveTimer);
						_ ->
							skip
					end,
					{next_state, sleep, [[], Minfo, State], ?SLEEP_TIME}
			end;
        %% 不重生关闭怪物进程
		false ->
			{stop, normal, [[], Minfo, State]}
    end;
revive(repeat, Status) ->
	revive(timeout, Status);
revive(_R, Status) ->
	revive(timeout, Status).

%% 怪物攻击移动
attack_move(Minfo, State, AttObj, X, Y) ->
	[NewMinfo, Interval] = lib_mon:attack_move(Minfo, State#state.battle_limit, X, Y),
	TraceState = send_event_after(State, Interval),
   	{next_state, trace, [AttObj, NewMinfo, TraceState]}.

%% 睡眠
sleep_action(Minfo, State) ->
	{next_state, sleep, [[], Minfo, State], State#state.sleep_time}.

%% 攻击巡逻
attack_or_trace(Minfo, State, X, Y, AttObj, Player) ->
    case lib_mon:trace_action(Minfo, X, Y, State#state.d_x, State#state.d_y) of
        %% 可以进行攻击
		attack ->
            %% 昏迷状态下不能攻击
           	RetMinfo =
				if
					State#state.battle_limit /= 2 ->
						NewMinfo = mod_battle:mon_battle([[Minfo, 1], [Player, 2], 0]),
						ets:insert(?ETS_SCENE_MON, NewMinfo),
						NewMinfo;
                	true ->
						Minfo
            	end,
			TraceState = send_event_after(State, RetMinfo#ets_mon.att_speed),
            {next_state, trace, [AttObj, RetMinfo, TraceState]};
		
        %% 还不能进行攻击就追踪
		trace ->
            case lib_mon:trace_line(Minfo#ets_mon.x, Minfo#ets_mon.y, X, Y, Minfo#ets_mon.att_area) of
                {MX, MY} ->                    
					attack_move(Minfo, State, AttObj, MX, MY);
                true ->
                    {next_state, back, [[], Minfo, State], 1000}
            end;
		
        %% 停止追踪
		_ ->
            {next_state, back, [[], Minfo, State], 1000}
    end.

%% 怪物死亡复活
mon_revive(Minfo, State, StateName, AttObj, CurAttId) ->
	case StateName of
		revive ->
			{next_state, revive, [[], Minfo, State]};
		_ ->
            AttId = 
                case AttObj of
                    [PreAttId, _PreAttPid] ->
                        PreAttId;
                    _ ->
                        CurAttId
                end,
			case Minfo#ets_mon.mid of
				44101 ->
					case tool:odds(20, 100) of
						true ->
							mod_scene:conjure_after_die([44001], Minfo#ets_mon.scene, Minfo#ets_mon.x, Minfo#ets_mon.y);
						false ->
							skip
					end;
				44102 ->
					case tool:odds(20, 100) of
						true ->
							mod_scene:conjure_after_die([44002], Minfo#ets_mon.scene, Minfo#ets_mon.x, Minfo#ets_mon.y);
						false ->
							skip
					end;
				44103 ->
					case tool:odds(20, 100) of
						true ->
							mod_scene:conjure_after_die([44003], Minfo#ets_mon.scene, Minfo#ets_mon.x, Minfo#ets_mon.y);
						false ->
							skip
					end;
                _ ->
					skip
			end,
            spawn(fun()-> lib_mon:mon_die(Minfo, AttId, State#state.player_list, State#state.d_x, State#state.d_y) end),
			ReviveState = send_event_after(State, round(Minfo#ets_mon.retime / 2)),
            {next_state, revive, [[], Minfo, ReviveState]}
	end.


%% 怪物的定时事件
send_event_after(State, Interval) ->
	CancelState = cancel_action_timer(State),
	ActionTimer = gen_fsm:send_event_after(Interval, repeat),
	CancelState#state{
		action_timer = ActionTimer
	}.

%% 取消怪物动作定时器
cancel_action_timer(State) ->
	if
		State#state.action_timer =/= undefined ->
			erlang:cancel_timer(State#state.action_timer);
		true ->
			skip
	end,
	State#state{
		action_timer = undefined
	}.

