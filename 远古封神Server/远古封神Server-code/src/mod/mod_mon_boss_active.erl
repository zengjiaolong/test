%%%------------------------------------
%%% @Module  : mod_mon_boss_active
%%% @Author  : ygfs
%%% @Created : 2010.10.05
%%% @Description: 场景BOSS
%%%------------------------------------
-module(mod_mon_boss_active).
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
-export([init/1, handle_event/3, handle_sync_event/4, handle_info/3, terminate/3, code_change/4]).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

-record(state, {    
    last_skill_time = [],					%% [{技能ID,上次时间}]
	battle_limit = 0,						%% 战斗时的一些受限制状态，1定身，2昏迷，3沉默（封技）
	d_x = 0,								%% 怪物初始的X坐标
	d_y = 0,								%% 怪物初始的Y坐标
	first_attack = 0,						%% 第一个攻击BOSS的玩家	
	conjure_list = [],						%% 召唤列表
	dps = [],								%% BOSS的DPS列表
	hate = [],								%% BOSS仇恨列表
	skill_hate = [],						%% 技能仇恨
	is_die_conjure = 0,						%% 死后是否召唤过
	player_list = [],						%% 参加玩家列表
	is_revive = 0,							%% 上一次复活的时间
	sleep_time = 0,							%% 睡眠时间	
	war_boss_damage= [0, 0],				%% 跨服战场boss所以伤害[红方，蓝方]
	mon_def = 0,							%% 怪物防御	   
	speed = 0,								%% 怪物速度
	active = 1,								%% 默认怪物是否激活
	action_timer = undefined				%% 怪物动作定时器
}).

%% 开启一个场景BOSS进程
start(Minfo) ->
    gen_fsm:start_link(?MODULE, Minfo, []).

%% Type 2死后召唤;3共享血量;4自杀;5?;6几率召唤;7血姬;8空幻;9伤害共享;10分身伤害平分
init([M, MonId, SceneId, X, Y, Type, Other]) ->
	process_flag(trap_exit, true),
	[MX, MY] =
		case Type of
			0 ->
				get_scene_boss_coordinate(M#ets_mon.x, M#ets_mon.y, X, Y, M#ets_mon.type);
			_ ->
				[X, Y]
		end,
	%% 睡眠时间
	SleepTime = 
		%% 判断是否主动怪
		case M#ets_mon.att_type =/= 0 of
			true ->
				3000;
			false ->
				3600000
		end,
	%%是否默认激活
	Active =
		case lists:member(M#ets_mon.type, [46]) of
			true ->
				0;
			false ->
				1
		end,
	State = #state{
		d_x = MX,
		d_y = MY,
		sleep_time = SleepTime,
		mon_def = M#ets_mon.def,
		speed = M#ets_mon.speed,
		active = Active		   
	},
	Relation = 
		case Type of
			%% 血量共享
			3 ->
				[3, Other, undefined];
			%% 血姬血柱
			4 ->
				[EraBleedMonPid,EraBleedMid,Interval] = Other,
				R = util:rand(1, 10),
				erlang:send_after((Interval * 1000 + R * 1000), self(), {'ERA_BLEED_HP', EraBleedMonPid,EraBleedMid,Interval}),
				[4, Other, undefined];
			%% 阴阳怪
			5 ->
				[EraBleedMonPid, OtherMonTypeId, EraSkyType] = Other,
				erlang:send_after(5000, self(), {'ERA_SKY_ATTR', EraSkyType, EraBleedMonPid}),
				[5, EraBleedMonPid, OtherMonTypeId, EraSkyType];
			_ ->
				case is_list(M#ets_mon.relation) of
					true ->
						case M#ets_mon.relation of
							%% 自杀怪
							[4, Expire, _Area, _Dam, _DamType] ->
								SuicideTimer = erlang:send_after(Expire * 1000, self(), 'MON_SUICIDE'),
								put(mon_suicide_timer, SuicideTimer),
								M#ets_mon.relation;
							%% 血姬
							[7, RelationList] ->
								lib_mon:era_blood_relation(RelationList, SceneId, X, Y, self() ,MonId);
							%% 空幻
							[8, RelationList] ->
								lib_mon:era_sky_relation(RelationList, SceneId, X, Y, self());
							_ ->
								M#ets_mon.relation
						end;
					false ->
						[]
				end
		end,
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
        x = MX,
        y = MY,
        pid = self(),
		min_attack = AttMin,
        battle_status = [],
        unique_key = {SceneId, MonId},
		status = 0,
		relation = Relation
    },	
    ets:insert(?ETS_SCENE_MON, Minfo),
	misc:write_monitor_pid(self(), ?MODULE, {}),
	RT = 
		case Type of
			0 ->
				State#state.sleep_time;
			%% 动态生成的怪
			_ ->
				lib_mon:dynamic_create_mon(Minfo, SceneId, MX, MY),
				1000
		end,
    case Minfo#ets_mon.type of
        %% 特殊捕捉怪物
        32 ->
            VanishTimer = erlang:send_after(60000, self(), 'CLEAR_MON'),
            put(mon_vanish_timer, VanishTimer);
        %% 龙塔
        37 ->
            Now = util:unixtime(),
            CastleRushTimer = erlang:send_after(10000, self(), 'CASTLE_RUSH_MON'),
            put(castle_rush_mon_boss, [CastleRushTimer, Now, Now]);
        _ ->
            skip
    end,
    {ok, sleep, [Minfo, State], RT}.

handle_event(_Event, StateName, Status) ->
    {next_state, StateName, Status}.

handle_sync_event(isActive, _From, StateName, [Minfo, State]) ->
    {reply, State#state.active, StateName, [Minfo, State]};

handle_sync_event(stateName, _From, StateName, [Minfo, State]) ->
    {reply, StateName, StateName, [Minfo, State]};

handle_sync_event(_Event, _From, StateName, Status) ->
    {reply, ok, StateName, Status}.

%% 记录战斗结果
%% Hp 战斗后的Hp
%% Mp 战斗后的Mp
%% NewAttId 当前攻击方的ID
%% NewAttPid 当前攻击方的进程ID
%% AttPid 上次攻击者的ID
%% Minfo BOSS状态信息
%% AttType 1怪物、2人物
handle_info({'MON_BOSS_BATTLE_RESULT', [Hp, CurAttId, CurAttName, CurAttPid, Hate, TeamPid, AttType]}, StateName, [Minfo, State]) ->
	case StateName /= revive andalso StateName /= back of
		true ->
            case Minfo#ets_mon.hp > 0 of
                true ->
					IsAlive = Hp > 0,
                    NewState =
						case Minfo#ets_mon.type of
							%% 野外BOSS
							3 ->
								HateState = add_hate(State, CurAttId, CurAttPid, Hate, AttType),
								DpsState =
									if
										Minfo#ets_mon.hp > Hp ->
											Hurt = Minfo#ets_mon.hp - Hp,
                                			add_dps(HateState, CurAttId, TeamPid, Hurt);
										true ->
											HateState
									end,
								%% 记录第一个打BOSS的玩家
								case DpsState#state.first_attack =/= 0 of
                              		true ->
                       					DpsState;
                                 	false ->
                                   		DpsState#state{
                                    		first_attack = CurAttId
                                     	}						
                             	end;
							%% 龙塔
							37 ->
								if
									Minfo#ets_mon.hp > Hp ->
										Hurt = Minfo#ets_mon.hp - Hp,
										spawn(fun()-> lib_castle_rush:castle_rush_boss_score(CurAttId, Minfo#ets_mon.scene, Hurt, Minfo#ets_mon.hp_lim, IsAlive) end);
									true ->
										skip
								end,
								State;
							39 ->%%神魔乱斗boss
								%%计算在神魔乱战的时候砍怪获得的经验和灵力
								case AttType =:= 2 of
									true ->
										Hurt = Minfo#ets_mon.hp - Hp,
										lib_warfare:count_player_gain(Minfo#ets_mon.scene, Minfo#ets_mon.type,
																	  CurAttPid, CurAttId, CurAttName, Hurt);
									false ->
										skip
								end,
								add_hate(State, CurAttId, CurAttPid, Hate, AttType);
							%% 镇妖剑
							101 ->
								{ok, TdBinData} = pt_12:write(12081, [Minfo#ets_mon.id, Hp]),
								lib_send:send_to_online_scene(Minfo#ets_mon.scene, TdBinData),
								State;
							_ ->
								add_hate(State, CurAttId, CurAttPid, Hate, AttType)
						end,
                    NewMinfo = Minfo#ets_mon{
                        hp = Hp
                    },
                    ets:insert(?ETS_SCENE_MON, NewMinfo),
                    case IsAlive of
                        true ->
                            case StateName of
                                trace ->
                                    {next_state, trace, [NewMinfo, NewState]};
                                _ ->
                              		trace_doing(NewMinfo, NewState)
                            end;
                        false ->
							NewCurAttId =
								%% 怪物打死怪物的情况，取玩家列表里去
								case AttType /= 1 of
									true ->
										CurAttId;
									false ->
										case length(NewState#state.player_list) > 0 of
											true ->
												lists:nth(1, NewState#state.player_list);
											false ->
												CurAttId
										end
								end,
                            mon_boss_revive(NewMinfo, NewState, StateName, NewCurAttId)
                    end;
                false ->
                    mon_boss_revive(Minfo, State, StateName, CurAttId)
            end;
		false ->
			{next_state, StateName, [Minfo, State]}
	end;

%% 开始一个怪物持续流血的计时器	
handle_info({'START_HP_TIMER', CurAttId, CurAttPid, Hurt,ValType, Time, Interval}, StateName, [Minfo, State]) ->	
	misc:cancel_timer(bleed_timer),
	case StateName /= revive andalso StateName /= back of
		true ->
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
                                1
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
                            {next_state, StateName, [NewMinfo, State]};
                        false ->
                            mon_boss_revive(Minfo, State, StateName, CurAttId)
                    end;			
                false ->
                    mon_boss_revive(Minfo, State, StateName, CurAttId)
            end;
		false ->
			{next_state, StateName, [Minfo, State]}
	end;

%% 定时处理怪物信息
%% Interval 倒计时间
%% Message 要处理的消息
handle_info({'SET_TIME_MON', Interval, Message}, StateName, [Minfo, State]) ->	
	erlang:send_after(Interval, self(), Message),
	{next_state, StateName, [Minfo, State]};

handle_info({'SET_MON_LIMIT', Type, Data}, StateName, [Minfo, State]) ->
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
            {next_state, StateName, [NewMinfo, State]};
        %% 改变状态
        2 ->
            [BattleLimit, Interval] = Data,
            Message = {'CHANGE_BATTLE_LIMIT', 0, BattleLimit},
            erlang:send_after(Interval, self(), Message),
            handle_info({'CHANGE_BATTLE_LIMIT', BattleLimit, 0}, StateName, [Minfo, State]);
        _ ->
            {next_state, StateName, [ Minfo, State]}
    end;

%% 更改战斗限制状态
%% ChangeStatus 要更改的状态
%% CurStatus 当前的状态
handle_info({'CHANGE_BATTLE_LIMIT', ChangeStatus, CurStatus}, StateName, [Minfo, State]) ->	
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
            case StateName == trace  of
                true ->
                    {next_state, trace, [Minfo, NewState]};
                false ->
					TraceState = send_event_after(NewState, 1000),
                    {next_state, trace, [Minfo, TraceState]}
            end;
        _ ->
            {next_state, StateName, [Minfo, NewState]}
    end;

%% 增加仇恨值
handle_info({'ADD_SKILL_HATE', AttId, AttPid, LastTime}, StateName, [Minfo, State]) ->
	Now = util:unixtime(),
	Expire = Now + LastTime,
	HateState = State#state{
		skill_hate = [AttId, AttPid, 2, Expire]			
	},
	{next_state, StateName, [Minfo, HateState]};

%% 攻城战怪物
handle_info('CASTLE_RUSH_MON', StateName, [Minfo, State]) ->
	[CRT, ReviveTime] =
		case get(castle_rush_mon_boss) of
			undefined ->
				[0, 0];
			[_CastleRushTimer, IntervalTime, RT] ->
				[IntervalTime, RT];
			_ ->
				[0, 0]
		end,
	%% 攻城战防守方在龙塔附近人数
	DefNum = lib_castle_rush:get_castle_rush_def_num(Minfo#ets_mon.x, Minfo#ets_mon.y),
	MonDef = trunc(Minfo#ets_mon.def + (DefNum / (DefNum + 5)) * 1000),
	NewMinfo = Minfo#ets_mon{
		def = MonDef						 
	},
	{Symbol, DictDef} =
		case MonDef > Minfo#ets_mon.def of
			true ->
				{2, MonDef - Minfo#ets_mon.def};
			false ->
				{1, Minfo#ets_mon.def - MonDef}
		end,
	%% 怪物属性广播
	if
		DictDef =/= 0 ->
			{ok, BinData} = pt_12:write(12084, [Minfo#ets_mon.id, [{1, DictDef, Symbol}]]),
			lib_send:send_to_online_scene(Minfo#ets_mon.scene, Minfo#ets_mon.x, Minfo#ets_mon.y, BinData);
		true ->
			skip
	end,
	ets:insert(?ETS_SCENE_MON, NewMinfo),
	Now = util:unixtime(),
	CT = 
		if
			%% 龙塔占领方每分钟有100氏族功勋
			Now - CRT > 59 ->
				CastleRushPid = mod_scene:get_scene_pid(?CASTLE_RUSH_SCENE_ID, undefined, undefined),
				case is_pid(CastleRushPid) of
					true ->
						gen_server:cast(CastleRushPid, 'CASTLE_RUSH_DEF_FEAT');	
					false ->
						skip
				end,
				Now;
			true ->
				CRT
		end,
	CastleRushTimer = erlang:send_after(10000, self(), 'CASTLE_RUSH_MON'),
	put(castle_rush_mon_boss, [CastleRushTimer, CT, ReviveTime]),
	{next_state, StateName, [NewMinfo, State]};

%% 攻城战怪物防御
handle_info('CASTLE_RUSH_MON_DEF', StateName, [Minfo, State]) ->
	Def = 50,
	MonDef = 
		case Minfo#ets_mon.def > Def of
			true ->
				Minfo#ets_mon.def - Def;
			false ->
				0
		end,
	{Symbol, DictDef} =
		case MonDef > Minfo#ets_mon.def of
			true ->
				{2, MonDef - Minfo#ets_mon.def};
			false ->
				{1, Minfo#ets_mon.def - MonDef}
		end,
	%% 怪物属性广播
	if
		DictDef =/= 0 ->
			{ok, BinData} = pt_12:write(12084, [Minfo#ets_mon.id, [{1, DictDef, Symbol}]]),
			lib_send:send_to_online_scene(Minfo#ets_mon.scene, Minfo#ets_mon.x, Minfo#ets_mon.y, BinData);
		true ->
			skip
	end,
	NewMinfo = Minfo#ets_mon{
		def = MonDef						 
	},
	ets:insert(?ETS_SCENE_MON, NewMinfo),
	{next_state, StateName, [NewMinfo, State]};

%% 主动控制怪物坐标点移动
handle_info({'MON_MOVIE', X, Y},StateName,[Minfo, State]) ->
	NewMinfo = Minfo#ets_mon{
		x = X,
		y = Y
	},
	lib_scene:mon_move(X, Y, Minfo#ets_mon.id, Minfo#ets_mon.scene, Minfo#ets_mon.speed),
	ets:insert(?ETS_SCENE_MON, NewMinfo),
	{next_state, StateName, [NewMinfo, State]};

%% 改变怪物坐标
handle_info({'MON_POSITION', X, Y}, StateName, [Minfo, State]) ->
	NewMinfo = Minfo#ets_mon{
		x = X,
		y = Y
	},
	ets:insert(?ETS_SCENE_MON, NewMinfo),
	{next_state, StateName, [NewMinfo, State]};

%% 更改怪物BUFF
handle_info({'SET_MON_BUFF', Buff}, StateName, [Minfo, State]) ->	
	NewMinfo = Minfo#ets_mon{
        battle_status = Buff        
    },
    ets:insert(?ETS_SCENE_MON, NewMinfo),
	{next_state, StateName, [NewMinfo, State]};

%% 更改怪物属性
handle_info({'CHANGE_MON_ATTR_UP', Hp, HpLim, Name, Def}, StateName, [Minfo, State]) ->
	NewMinfo = Minfo#ets_mon{
   		name = Name,
		hp = Hp + Minfo#ets_mon.hp,
		hp_lim = HpLim + Minfo#ets_mon.hp_lim,
		def = Def  + Minfo#ets_mon.def       
    },
    ets:insert(?ETS_SCENE_MON, NewMinfo),
	{ok, BinData} = pt_12:write(12083, [NewMinfo#ets_mon.id, Hp + Minfo#ets_mon.hp, HpLim + Minfo#ets_mon.hp_lim, Name]),
	lib_send:send_to_online_scene(NewMinfo#ets_mon.scene, BinData),
	{next_state, StateName, [NewMinfo, State]};

%% 更改怪物属性
handle_info({'CHANGE_MON_ATTR_TD'}, StateName, [Minfo, State]) ->
	Hp = trunc(Minfo#ets_mon.hp * 1.1), 
	HpNew =
		if
			Hp >= Minfo#ets_mon.hp_lim ->
				Minfo#ets_mon.hp_lim;
			true ->
				Hp
		end,
	NewMinfo = Minfo#ets_mon{hp = HpNew },
    ets:insert(?ETS_SCENE_MON, NewMinfo),
	{ok, BinData} = pt_12:write(12083, [NewMinfo#ets_mon.id, HpNew, Minfo#ets_mon.hp_lim, Minfo#ets_mon.name]),
	lib_send:send_to_online_scene(NewMinfo#ets_mon.scene, BinData),
	{next_state, StateName, [NewMinfo, State]};

%% 更改怪物类型
handle_info({'CHANGE_MON_ATT_TYPE',Type},StateName,[Minfo, State]) ->
	NewMinfo = Minfo#ets_mon{type = Type},
	ets:insert(?ETS_SCENE_MON, NewMinfo),			
	{next_state, StateName, [NewMinfo, State]};

%% 更改激活状态
handle_info({'CHANGE_MON_ACTIVE',Active},StateName,[Minfo, State]) ->
	if
		Active == 0 orelse Active == 1 ->
			NewState = State#state{active = Active};
		true ->
			NewState = State
	end,
	{next_state, StateName, [Minfo, NewState]};

%% 更改怪物关系
handle_info({'CHANGE_MON_RELATION',Relation},StateName,[Minfo,State]) ->
	NewMinfo = Minfo#ets_mon{relation = Relation},
	ets:insert(?ETS_SCENE_MON, NewMinfo),
	{next_state,StateName,[NewMinfo,State]};

%% 怪物自杀
handle_info('MON_SUICIDE', StateName, [Minfo, State]) ->
	case get(mon_suicide_timer) of
		undefined ->
			skip;
		SuicideTimer ->
			erlang:cancel_timer(SuicideTimer)
	end,
	put(mon_suicide_timer, undefined),
	case Minfo#ets_mon.relation of
		[4, _Expire, Area, Dam, DamType] ->
			case DamType of
				%% 爆炸
				1 ->
					Hurt =
						case is_float(Dam) of
							true ->
								Dam * Minfo#ets_mon.hp_lim;
							false ->
								Dam
						end,
					lib_mon:battle(Minfo#ets_mon.id, Minfo#ets_mon.hp, Minfo#ets_mon.mp, Minfo#ets_mon.scene, Minfo#ets_mon.x, Minfo#ets_mon.y, Area, round(Hurt), 0, 10054);
				%% 眩晕
				2 ->
					case get_att_obj(Minfo, State) of
						{attack, [_NewState, Player, _AttPid, _SkillInfo]} ->
							mod_battle:mon_battle([[Minfo, 1], [Player, 2], Dam]);
						_ ->
							skip
					end;
				_ ->
					skip
			end,
			{ok, BinData} = pt_12:write(12082, [Minfo#ets_mon.id, 0]),
			case lib_scene:is_copy_scene(Minfo#ets_mon.scene) of
				true ->
					lib_send:send_to_online_scene(Minfo#ets_mon.scene, BinData);
				false ->
					lib_send:send_to_online_scene(Minfo#ets_mon.scene, Minfo#ets_mon.x, Minfo#ets_mon.y, BinData)
			end,
			handle_info(clear, null, [Minfo, State]);
		_ ->
			{next_state, StateName, [Minfo, State]}
	end;

%% 怪物蓄能爆炸
handle_info({'MON_ENERGY_EXPLODE', Hurt, AttArea}, StateName, [Minfo, State]) ->
	case get(mon_energy_timer) of
		undefined ->
			skip;
		EnergyTimer ->
			erlang:cancel_timer(EnergyTimer)
	end,
	put(mon_energy_timer, undefined),
	X = Minfo#ets_mon.x,
	Y = Minfo#ets_mon.y,
	X1 = X + AttArea,
    X2 = X - AttArea,
    Y1 = Y + AttArea,
    Y2 = Y - AttArea,
	SceneId = Minfo#ets_mon.scene,
	MS = ets:fun2ms(fun(P) when P#player.scene == SceneId andalso P#player.hp > 0 andalso  
								P#player.x >= X2 andalso P#player.x =< X1 andalso 
								P#player.y >= Y2 andalso P#player.y =< Y1 -> 
	    [
            P#player.id,
            P#player.hp,
            P#player.mp,
            P#player.other#player_other.pid,
			P#player.other#player_other.battle_status
	    ]
	end),
	AllUser = ets:select(?ETS_ONLINE_SCENE, MS),
	User = lib_mon:energy_explode_user(AllUser, []),
	lib_mon:battle_result(User, Minfo#ets_mon.id, Minfo#ets_mon.hp, Minfo#ets_mon.mp, SceneId, X, Y, Hurt, 0, 10069),
	{next_state, StateName, [Minfo, State]};

%% 血姬柱子加血 Mid 柱子id Mpid  柱子进程
handle_info({'ERA_BLEED_HP',Mid,_Mpid}, StateName, [Minfo, State]) ->
	OtherMinfo = lib_mon:get_mon(Mid,Minfo#ets_mon.scene),
	case is_record(OtherMinfo, ets_mon) of
		true ->
			Alive = OtherMinfo#ets_mon.hp > 0;
		false ->
			Alive = false
	end,
	%% 断开连线
	{ok,BinData20201} = pt_20:write(20201, [Minfo#ets_mon.id,Mid,0]),
	lib_send:send_to_online_scene(Minfo#ets_mon.scene, BinData20201),

	if
		Alive ->
			if
				Minfo#ets_mon.hp < Minfo#ets_mon.hp_lim ->
					Hp = 
						if
							Minfo#ets_mon.hp + 50000 > Minfo#ets_mon.hp_lim ->
								Minfo#ets_mon.hp_lim;
							true ->
								Minfo#ets_mon.hp + 50000
						end,
					NewMinfo = Minfo#ets_mon{
						hp = Hp
					},
					{ok, BinData} = pt_12:write(12082, [NewMinfo#ets_mon.id, NewMinfo#ets_mon.hp]),
					lib_send:send_to_online_scene(NewMinfo#ets_mon.scene, BinData),
					ets:insert(?ETS_SCENE_MON, NewMinfo),
					{next_state, StateName, [NewMinfo, State]};
				true ->
					{next_state, StateName, [Minfo, State]}
			end;
		true ->
			{next_state, StateName, [Minfo, State]}
	end;

handle_info({'ERA_BLEED_HP', EraBleedMonPid,EraBleedMid,Interval}, StateName, [Minfo, State]) ->
	case is_pid(EraBleedMonPid) andalso StateName /= revive of
		true ->
			spawn(fun()->
				%% 连线
				{ok,BinData} = pt_20:write(20201, [EraBleedMid,Minfo#ets_mon.id,1]),
				lib_send:send_to_online_scene(Minfo#ets_mon.scene, BinData)
			end),
			erlang:send_after(5000, EraBleedMonPid, {'ERA_BLEED_HP',Minfo#ets_mon.id,Minfo#ets_mon.pid});
		false ->
			skip
	end,
	misc:cancel_timer(era_blood_timer),
	R = util:rand(1, 10),
	Era_blood_timer = erlang:send_after((Interval * 1000 + R * 1000), self(), {'ERA_BLEED_HP', EraBleedMonPid,EraBleedMid,Interval}),
	put(era_blood_timer,Era_blood_timer),
	{next_state, StateName, [Minfo, State]};

%% 阴阳怪给空幻加属性（1阴2阳）
handle_info({'ERA_SKY_ATTR', EraSkyType, EraBleedMonPid}, StateName, [Minfo, State]) ->
	case is_pid(EraBleedMonPid) andalso StateName == trace of
		true ->
			EraBleedMonPid ! {'ERA_SKY_ATTR', EraSkyType} ;
		false ->
			skip
	end,
	misc:cancel_timer(era_sky_timer),
	Era_sky_timer = erlang:send_after(2000, self(), {'ERA_SKY_ATTR', EraSkyType, EraBleedMonPid}),
	put(era_sky_timer,Era_sky_timer),
	{next_state, StateName, [Minfo, State]};

handle_info({'ERA_SKY_ATTR', EraSkyType}, StateName, [Minfo, State]) ->
	RetMinfo =
		if
			EraSkyType == 1  ->
				[Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil] = 
					case get(mod_default_anti) of
						undefined ->
							put(mod_default_anti,[Minfo#ets_mon.anti_wind,Minfo#ets_mon.anti_fire,Minfo#ets_mon.anti_water,Minfo#ets_mon.anti_thunder,Minfo#ets_mon.anti_soil]),
							[Minfo#ets_mon.anti_wind,Minfo#ets_mon.anti_fire,Minfo#ets_mon.anti_water,Minfo#ets_mon.anti_thunder,Minfo#ets_mon.anti_soil];
						DefVal ->
							DefVal
					end,
				AddValue = 20000,
				Minfo#ets_mon{
					anti_wind = Anti_wind + AddValue,
					anti_fire = Anti_fire + AddValue,
					anti_water = Anti_water + AddValue,
					anti_thunder = Anti_thunder + AddValue,
					anti_soil = Anti_soil + AddValue				
				};
			EraSkyType == 2 ->
				Hp = 
					if
						Minfo#ets_mon.hp + 500000 > Minfo#ets_mon.hp_lim ->
							Minfo#ets_mon.hp_lim;
						true ->
							Minfo#ets_mon.hp + 500000
					end,
				NewMinfo = Minfo#ets_mon{
					hp = Hp
				},
				{ok, BinData} = pt_12:write(12082, [NewMinfo#ets_mon.id, NewMinfo#ets_mon.hp]),
				lib_send:send_to_online_scene(NewMinfo#ets_mon.scene, BinData),
				NewMinfo;
			true ->
				Minfo
		end,
	ets:insert(?ETS_SCENE_MON, RetMinfo),
	{next_state, StateName, [RetMinfo, State]};

%% 阴阳怪给空幻加属性（1阴2阳）
handle_info({'ERA_SKY_MON_DIE', Type}, StateName, [Minfo, State]) ->
	Skill =
		if
			Type == 1 ->
				%% 去掉法力技能
				lists:keydelete(10049, 1, Minfo#ets_mon.skill);
			true ->
				lists:keydelete(10060, 1, Minfo#ets_mon.skill)
		end,
	Minfo1 = 
		if
			Type == 1 ->
				%% 阴怪死后恢复空幻基础防御
				case get(mod_default_anti) of
					undefined ->
						Minfo;
					[Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil] ->
						Minfo#ets_mon{
							anti_wind = Anti_wind ,
							anti_fire = Anti_fire ,
							anti_water = Anti_water ,
							anti_thunder = Anti_thunder ,
							anti_soil = Anti_soil		
						}
				end;
			true ->
				Minfo
		end,
	NewMinfo = Minfo1#ets_mon{
		skill = Skill
	},
	ets:insert(?ETS_SCENE_MON, NewMinfo),
	{next_state, StateName, [NewMinfo, State]};

%% 空幻阴阳怪愤怒
handle_info('ERA_MON_ANGRY', StateName, [Minfo, State]) ->
	NewMinfo = Minfo#ets_mon{
		max_attack = Minfo#ets_mon.max_attack + 3000,
		min_attack = Minfo#ets_mon.min_attack + 3000
	},
	ets:insert(?ETS_SCENE_MON, NewMinfo),
	{next_state, StateName, [NewMinfo, State]};

%% 怪物技能失效
handle_info({'MON_SKILL_LOSE',SkillId},StateName,[Minfo,State]) ->
	NewSkill = lists:keydelete(SkillId, 1, Minfo#ets_mon.skill),
	NewMinfo =  Minfo#ets_mon{skill = NewSkill},
	ets:insert(?ETS_SCENE_MON, NewMinfo),
	{next_state,StateName,[NewMinfo,State]};

%% 清除进程（外部调用）
handle_info('CLEAR_MON', _StateName, [Minfo, State]) ->
	case get(mon_vanish_timer) of
		undefined ->
			skip;
		VanishTimer ->
			catch erlang:cancel_timer(VanishTimer)
	end,
	put(mon_vanish_timer, undefined),
	{ok, BinData} = pt_12:write(12082, [Minfo#ets_mon.id, 0]),
	SceneId = Minfo#ets_mon.scene,
	case lib_scene:is_copy_scene(SceneId) of
		true ->
			lib_send:send_to_online_scene(SceneId, BinData);
		false ->
			lib_send:send_to_online_scene(SceneId, Minfo#ets_mon.x, Minfo#ets_mon.y, BinData)
	end,
    {stop, normal, [Minfo, State]};

%% 清除进程
handle_info(clear, _StateName, [Minfo, State]) ->
    {stop, normal, [Minfo, State]};

handle_info(_Info, StateName, [Minfo, State]) ->
%?WARNING_MSG("MON_BOSS_NO_MSG: /~p/~n", [[Info, StateName, [Minfo, State]]]),
    {next_state, StateName, [Minfo, State]}.

terminate(_Reason, _StateName, [Minfo, _State]) ->
%% 	cancel_action_timer(State),
	lib_mon:del_mon_data(self(), Minfo#ets_mon.unique_key).

code_change(_OldVsn, StateName, Status, _Extra) ->
    {ok, StateName, Status}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 处理怪物所有状态
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 静止状态并回血
sleep(timeout, [Minfo, CancelState]) ->
%% 	CancelState = cancel_action_timer(State),
    %% 判断是否死亡
    case Minfo#ets_mon.hp > 0 of
        true ->
			NewMinfo = 
				case Minfo#ets_mon.status == 0 of
					true ->
						Minfo;
					false ->						
						NMinfo = Minfo#ets_mon{
                    		status = 0
                   		},
						ets:insert(?ETS_SCENE_MON, NMinfo),
						NMinfo
				end,
			case NewMinfo#ets_mon.att_type of
				%% 主动怪
				1 when CancelState#state.active == 0 ->
					sleep_action(NewMinfo, CancelState);                
                1 ->  
					MonType = NewMinfo#ets_mon.type,
					Type = 
						case MonType of
							%% TD守卫
							100 ->
								1;
							%% TDBOSS
							98 ->
								0;
							%% TD怪物
							99 ->
								0;
							%% 幻魔怪
							33 ->
								0;
							_ ->
								2
						end,
					case lib_scene:get_area_mon_for_battle(NewMinfo#ets_mon.scene, NewMinfo#ets_mon.x, NewMinfo#ets_mon.y, NewMinfo#ets_mon.guard_area, MonType, Type) of
                  		[] ->
                      		sleep_action(NewMinfo, CancelState);
                     	[AttId, AttPid, AttType] ->
                       		HateState = CancelState#state{        
                       			hate = [{AttId, AttPid, AttType, 1} | CancelState#state.hate]
                          	},
                       		trace_doing(NewMinfo, HateState)
                   	end;
                %% 被动怪
                _ -> 
               		sleep_action(NewMinfo, CancelState)
            end;
        false ->
            {next_state, revive, [Minfo, CancelState], Minfo#ets_mon.retime}
    end;
sleep(repeat, Status) ->
	sleep(timeout, Status);
sleep(_R, Status) ->
    sleep(timeout, Status).

%% 跟踪目标
trace(timeout, [Minfo, CancelState]) ->
%% 	CancelState = cancel_action_timer(State),
	trace_doing(Minfo, CancelState);
trace(repeat, Status) ->    
    trace(timeout, Status);
trace(_R, Status) ->    
    trace(timeout, Status).

%% 返回默认出生点
back(timeout, [Minfo, CancelState]) ->
	lib_mon:destory_conjure_mon(CancelState#state.conjure_list, Minfo#ets_mon.scene),
	{StateName, NewMinfo, Interval} = lib_mon:back(Minfo, CancelState#state.battle_limit, CancelState#state.d_x, CancelState#state.d_y),
%%     CancelState = cancel_action_timer(State),
	NewState = init_state(CancelState),
	case StateName of
		back ->
			BackState = send_event_after(NewState, Interval),
			{next_state, StateName, [NewMinfo, BackState]};
		_ ->
			{next_state, StateName, [NewMinfo, NewState], Interval}
	end;
back(repeat, Status) ->    
	back(timeout, Status);
back(_R, Status) ->
    sleep(timeout, Status).

%% 复活
revive(timeout, [Minfo, State]) ->
	CancelState = check_conjure(State, Minfo),
%% 	CancelState = cancel_action_timer(ConjureState),
	%% 重生时间大于0且不是副本怪
	SceneId = lib_scene:get_scene_id_from_scene_unique_id(Minfo#ets_mon.scene),
    case Minfo#ets_mon.retime > 0 andalso (lib_scene:is_copy_scene(Minfo#ets_mon.scene) == false 
											orelse Minfo#ets_mon.type =:= 37 
										  	orelse Minfo#ets_mon.type =:= 44
											orelse SceneId == 1102 
  											orelse SceneId == 1108
										  	orelse SceneId == 1110
  											) of 
		true ->
			NewState = init_state(CancelState),
			ReviveMinfo = lib_mon:revive(Minfo, CancelState#state.d_x, CancelState#state.d_y, CancelState#state.speed),
			NewMinfo = ReviveMinfo#ets_mon{
				def = CancelState#state.mon_def							
			},
			ets:insert(?ETS_SCENE_MON, NewMinfo),
            {next_state, sleep, [NewMinfo, NewState], NewState#state.sleep_time};
        false ->
			%% 不重生关闭怪物进程
            handle_info(clear, null, [Minfo, CancelState])
    end;
revive(repeat, [Minfo, State]) ->
	ConjureState = check_conjure(State, Minfo),
	[Retime, RetState] =
		case ConjureState#state.is_revive =:= 0 of
			true ->
				NewState = ConjureState#state{
					is_revive = 1									   
				},
				[Minfo#ets_mon.retime, NewState];
			false ->
				[1000, ConjureState]
		end,
	if
		Minfo#ets_mon.type == 44 ->
			gen_fsm:send_event_after(Retime, timeout),
			{next_state, revive, [Minfo, RetState]};
		Minfo#ets_mon.type =/= 37 ->
    		{next_state, revive, [Minfo, RetState], Retime};
		true ->
			revive(timeout, [Minfo, RetState])
	end;
revive(_R, [Minfo, State]) ->
	ConjureState = check_conjure(State, Minfo),
    {next_state, revive, [Minfo, ConjureState], 1000}.

%% 怪物攻击移动
attack_move(X, Y, [Minfo, State]) ->
	[NewMinfo, Interval] = lib_mon:attack_move(Minfo, State#state.battle_limit, X, Y),                
	TraceState = send_event_after(State, Interval),
   	{next_state, trace, [NewMinfo, TraceState]}.        

%% 随机移动
sleep_action(Minfo, State) ->  
    %% 是否镇妖守卫
    case Minfo#ets_mon.type /= 100 of
		true ->
			{next_state, sleep, [Minfo, State], State#state.sleep_time};
        false ->
            %% 是否有加血技能
            case lists:keyfind(10066, 1, Minfo#ets_mon.skill) of
                {_SkillId, CD, _HpStart, _HpEnd, [AddHp, Area]} ->
                    case lib_scene:get_user_mon_for_mon_hp(Minfo#ets_mon.scene, Minfo#ets_mon.x, Minfo#ets_mon.y, Minfo#ets_mon.type, Area) of
                        [] ->
                            {next_state, sleep, [Minfo, State], State#state.sleep_time};
                        [Id, Pid, Sign] ->
                            case Sign of
                                %% 怪
                                1 ->
                                    Pid ! {'START_HP_TIMER', 0, 0, -AddHp, 0, 1000};
                                %% 人
                               	_ ->
									lib_battle:hp_bleed(Id, Minfo#ets_mon.scene, -AddHp,0, 0, 0, Minfo#ets_mon.name, 0, 0)
%%                                     Pid ! {'START_HP_TIMER', 0, 0, Minfo#ets_mon.name, 0, 0, -AddHp, 0, 1000}
                            end,
							SleepState = send_event_after(State, CD * 2),
                            {next_state, sleep, [Minfo, SleepState]}
                    end;
                _ ->
                    {next_state, sleep, [Minfo, State], State#state.sleep_time}	
            end
    end.

%% 获取BOSS技能
get_skill(Minfo, State) ->
	Skill = Minfo#ets_mon.skill,
	MonHpRate = Minfo#ets_mon.hp / Minfo#ets_mon.hp_lim,
	Now = util:longunixtime(),
	%% 获取可施放的技能ID
	SkillIdList = get_skill_loop(Skill, State, MonHpRate, Now, []),
	Len = length(SkillIdList),
	case Len > 0 of
		true ->
			%% 随机获取一个技能
			Rand = random:uniform(Len),
			{SkillId, Other} = lists:nth(Rand, SkillIdList),			
			NewLastSkill = 
				case lists:keyfind(SkillId, 1, State#state.last_skill_time) of
					false ->
						State#state.last_skill_time;
					_ ->
						lists:keydelete(SkillId, 1, State#state.last_skill_time)
				end,
			NewState = State#state{
           		last_skill_time = [{SkillId, Now} | NewLastSkill]
           	},
			[{SkillId, Other}, NewState];
		false ->
			[{0, 0}, State]		
	end.

get_skill_loop([], _State, _MonHpRate, _Now, SkillIdList) ->
	SkillIdList;
get_skill_loop([{SkillId, CD, HpStart, HpEnd, Other} | S], State, MonHpRate, Now, SkillIdList) ->
	%% 判断怪物血量是否达到施放条件
	case MonHpRate =< HpStart andalso MonHpRate > HpEnd of
		true ->
			%% 判断CD
            case lists:keyfind(SkillId, 1, State#state.last_skill_time) of
                false ->
                    NewSkillIdList = [{SkillId, Other} | SkillIdList],
                    get_skill_loop(S, State, MonHpRate, Now, NewSkillIdList);
                {_, LastSkillTime} ->
                    case LastSkillTime + CD > Now  of
                        true ->
                            get_skill_loop(S, State, MonHpRate, Now, SkillIdList);       
                        false ->
                            NewSkillIdList = [{SkillId, Other} | SkillIdList],
                            get_skill_loop(S, State, MonHpRate, Now, NewSkillIdList)
                    end
            end;
		false ->
			get_skill_loop(S, State, MonHpRate, Now, SkillIdList)
	end.

attack_or_trace(Minfo, State) ->
    case get_att_obj(Minfo, State) of
        %% 可以进行攻击
		{attack, [NewState, Player, AttPid, AttType, SkillInfo]} ->
			if 
				State#state.battle_limit /= 2 ->
					mon_attack(Minfo, Player, AttPid, AttType, NewState, SkillInfo);
			   	true ->
				   {next_state, back, [Minfo, NewState]}
			end;
        %% 还不能进行攻击就追踪
		{trace, [NewState, X, Y]} ->
			attack_move(X, Y, [Minfo, NewState]);
        %% 停止追踪
		{none, NewState} ->
			MonType = Minfo#ets_mon.type,
			case lists:member(MonType, [98, 99, 100]) of
				true ->
					Type = 
						if
							%% TD怪物
							MonType =/= 100 ->
								0;
							%% TD守卫
							true ->
								1
						end,
					case lib_scene:get_area_mon_for_battle(Minfo#ets_mon.scene, Minfo#ets_mon.x, Minfo#ets_mon.y, Minfo#ets_mon.guard_area, MonType, Type) of
                  		[] ->
							BackState = send_event_after(NewState, 1000),
							{next_state, back, [Minfo, BackState]};
                     	[AttId, AttPid, AttType] ->
                       		HateState = NewState#state{        
                       			hate = [{AttId, AttPid, AttType, 1} | NewState#state.hate]
                          	},
							TraceState = send_event_after(HateState, Minfo#ets_mon.att_speed),
							{next_state, trace, [Minfo, TraceState]}
                   	end;
				false ->
					BackState = send_event_after(NewState, 1000),
					{next_state, back, [Minfo, BackState]}
			end;
		_ -> 	
			BackState = send_event_after(State, 1000),
            {next_state, back, [Minfo, BackState]}        
    end.

%% 怪物攻击
%% AttType 攻击对象类型，1怪物、2人物
mon_attack(Minfo, Player, AttPid, AttType, State, SkillInfo) ->
	{SkillId, Other} = SkillInfo,
    case SkillId of
		%% 加血
		10058 ->
			case Other of
				[Val] ->
					AddHp = 
						case is_float(Val) of
							true ->
								Minfo#ets_mon.hp_lim * Val;
							false ->
								Val
						end,
					NewMinfo = add_hp(Minfo, round(AddHp)),
					TraceState = send_event_after(State, NewMinfo#ets_mon.att_speed),
            		{next_state, trace, [NewMinfo, TraceState]};
				_ ->
					start_battle(Minfo, Player, State, 0, AttType)
			end;
        %% 召唤怪物
        10038 ->
            case Other of
                [ConjureMonId, ConjureNum] ->
                    ConjureList = lib_mon:conjure_mon(ConjureNum, ConjureMonId, Minfo#ets_mon.scene, Minfo#ets_mon.x, Minfo#ets_mon.y, State#state.conjure_list),
                    NewState = State#state{
                        conjure_list = ConjureList						   
                    },
					TraceState = send_event_after(NewState, Minfo#ets_mon.att_speed),
                    {next_state, trace, [Minfo, TraceState]};
                _ ->
                    start_battle(Minfo, Player, State, 0, AttType)
            end;
        %% 自焚
        10048 ->
            case Other of
                [Hurt, AttArea] ->
                    HpHurt =
                        case is_float(Hurt) of
                            true ->
                                util:ceil(Minfo#ets_mon.hp * Hurt);
                            false ->
                                Hurt
                        end,
                    NewMinfo = add_hp(Minfo, -HpHurt),
                    lib_mon:battle(NewMinfo#ets_mon.id, NewMinfo#ets_mon.hp, NewMinfo#ets_mon.mp, NewMinfo#ets_mon.scene, NewMinfo#ets_mon.x, NewMinfo#ets_mon.y, AttArea, HpHurt, 0, 10048),   
					TraceState = send_event_after(State, NewMinfo#ets_mon.att_speed),
                    {next_state, trace, [NewMinfo, TraceState]};
                _ ->
                    start_battle(Minfo, Player, State, 0, AttType)
            end;                
        %% 抽蓝
        10049 ->
            case Other of
                [Hurt, AttArea] ->
                    MpHurt =
                        case is_float(Hurt) of
                            true ->
                                util:ceil(Minfo#ets_mon.mp * Hurt);
                            false ->
                                Hurt
                        end,
                    lib_mon:battle(Minfo#ets_mon.id, Minfo#ets_mon.hp, Minfo#ets_mon.mp, Minfo#ets_mon.scene, Minfo#ets_mon.x, Minfo#ets_mon.y, AttArea, 0, MpHurt, 10048),   
					TraceState = send_event_after(State, Minfo#ets_mon.att_speed),
                    {next_state, trace, [Minfo, TraceState]};
                _ ->
                    start_battle(Minfo, Player, State, 0, AttType)
            end;                
        %% 特定范围伤害
        10050 ->	
            case Other of
                [Hurt, Last, Area] ->
                    case rand_att_obj(State#state.hate, Minfo, State) of
                        {attack, [NewState, RandPlayer, _AttPid, _AttType, _SkillInfo]} ->
                            ScenePid = mod_scene:get_scene_real_pid(Minfo#ets_mon.scene),
							case is_pid(ScenePid) of
								true ->
									gen_server:cast(ScenePid, 
                                		{'LAST_AREA_DAM', Hurt, Last, Area, Minfo#ets_mon.scene, RandPlayer#player.x, RandPlayer#player.y, SkillId});
                            	false ->
									skip
							end,
							TraceState = send_event_after(NewState, Minfo#ets_mon.att_speed),
                            {next_state, trace, [Minfo, TraceState]};
                        _ ->
                            start_battle(Minfo, Player, State, 0, AttType)	
                    end;
                _ ->
                    start_battle(Minfo, Player, State, 0, AttType)						 	
            end;
		
		%% 塔怪加血
		10066 ->
			case Other of
                [AddHp, Area] ->
                    case lib_scene:get_user_mon_for_mon_hp(Minfo#ets_mon.scene, Minfo#ets_mon.x, Minfo#ets_mon.y, Minfo#ets_mon.type, Area) of
                        [] ->
							start_battle(Minfo, Player, State, 0, AttType);
                        [Id, Pid, Sign] ->
                            case Sign of
                                %% 怪
                                1 ->
                                    Pid ! {'START_HP_TIMER', 0, 0, -AddHp, 0, 1000};
                                %% 人
                                2 ->
									lib_battle:hp_bleed(Id, Minfo#ets_mon.scene, -AddHp,0, 0, 0, Minfo#ets_mon.name, 0, 0)
%% 									Pid ! {'START_HP_TIMER', 0, 0, Minfo#ets_mon.name, 0, 0, -AddHp, 0, 1000}
                            end,
							TraceState = send_event_after(State, Minfo#ets_mon.att_speed),
                    		{next_state, trace, [Minfo, TraceState]}
                    end;
				_ ->
					start_battle(Minfo, Player, State, 0, AttType)	
			end;
		
		%% 魔爆术
		10069 ->
			case Other of
				[Expire, Hurt, AttArea] ->
					EnergyTimer = erlang:send_after(Expire * 1000, self(), {'MON_ENERGY_EXPLODE', Hurt, AttArea}),
					put(mon_energy_timer, EnergyTimer),
					start_battle(Minfo, Player, State, SkillId, AttType);
				_ ->
					start_battle(Minfo, Player, State, 0, AttType)	
			end;
			
		%% 随机攻击
		10051 ->
			case is_list(Other) of
				true ->
					Len = length(Other),
					case Len > 0 of
						true ->
							Rand = random:uniform(Len),
							RandSkill = lists:nth(Rand, Other),
							case RandSkill /= SkillId of
								true ->
									%% 随机攻击目标
									case rand_att_obj(State#state.hate, Minfo, State) of
                						{attack, [NState, RandPlayer, _AttPid, _AttType, _RandSkillInfo]} ->
											RandSkillInfo = 
												case lists:keyfind(RandSkill, 1, Minfo#ets_mon.skill) of
													false ->
														{0,[]};
													{_RandSkill, _CD, _HpStart, _HpEnd, RandOther} ->
														{RandSkill, RandOther}
												end,
											mon_attack(Minfo, RandPlayer, AttPid, AttType, NState, RandSkillInfo);
                						_ ->
											start_battle(Minfo, Player, State, 0, AttType)
            						end;									
								false ->
									start_battle(Minfo, Player, State, 0, AttType)
							end;
						false ->
							start_battle(Minfo, Player, State, 0, AttType)
					end;					
				false ->
					start_battle(Minfo, Player, State, 0, AttType)	
			end;	
		
		%% 分身
		10083 ->
			%% 继承玩家属性百分比
			case Other of
				[] -> 
					Pct = 1;
				[PctN] ->
					Pct = PctN
			end,
			[{AttId, _AttPid, _AttType, _} | _] = State#state.hate,
			case lib_mon:get_player(AttId, Minfo#ets_mon.scene) of
				[] ->
					skip;					
				Shadow ->
					NewChallengerId = round(?MON_LIMIT_NUM / 10) * 2 + AttId,
					NewChallengePlayer = Shadow#player{
						id = Minfo#ets_mon.id,
						scene = Minfo#ets_mon.scene,
						max_attack = round(Shadow#player.max_attack * Pct),
						min_attack = round(Shadow#player.min_attack * Pct),
						def = round(Shadow#player.def * Pct),
						dodge = round(Shadow#player.dodge * Pct),
						hit = round(Shadow#player.hit * Pct),
						crit = round(Shadow#player.crit * Pct),
						forza = round(Shadow#player.forza * Pct),
						agile = round(Shadow#player.agile * Pct),
						wit = round(Shadow#player.wit * Pct),
						physique = round(Shadow#player.physique * Pct),
						anti_wind = round(Shadow#player.anti_wind * Pct),
						anti_fire = round(Shadow#player.anti_fire * Pct),
						anti_water = round(Shadow#player.anti_water * Pct),
						anti_thunder = round(Shadow#player.anti_thunder * Pct),
						anti_soil = round(Shadow#player.anti_soil * Pct)
					},
					{HookConfig, _TimeStart, _TimeLimit, _Timestamp} = lib_hook:get_hook_config(AttId),
					SkillList = mod_mon_create:shadow_skill(HookConfig#hook_config.skill_list, Shadow, []),
					mod_shadow_active:start([NewChallengePlayer, NewChallengerId, Minfo#ets_mon.x, Minfo#ets_mon.y, SkillList])
			end,
			start_battle(Minfo, Player, State, SkillId, AttType);
		
		%% 伤害共享
		10092 ->
			case Other of
				[ShareMonId] ->
					case data_agent:mon_get(ShareMonId) of
                        [] ->
							start_battle(Minfo, Player, State, 0, AttType);
                        ShareMinfo ->
							ShareMonAutoId = mod_mon_create:get_mon_auto_id(2),
							NewShareMinfo = ShareMinfo#ets_mon{
								relation = [9, Minfo#ets_mon.id]								
							},
                            case mod_mon_boss_active:start([NewShareMinfo, ShareMonAutoId, Minfo#ets_mon.scene, Minfo#ets_mon.x + 1, Minfo#ets_mon.y + 1, 9, Minfo#ets_mon.id]) of
								{ok, _ShareMonPid} ->
									NewMinfo = Minfo#ets_mon{
										relation = [9, ShareMonAutoId]						 
									},
									start_battle(NewMinfo, Player, State, 0, AttType);
								_ ->
									start_battle(Minfo, Player, State, 0, AttType)	
							end
                    end;
				_ ->
					start_battle(Minfo, Player, State, 0, AttType)	
			end;
        _ ->
            start_battle(Minfo, Player, State, SkillId, AttType)
    end.

start_battle(Minfo, Player, State, SkillId, AttType) ->
	NewMinfo = mod_battle:mon_battle([[Minfo, 1], [Player, AttType], SkillId]),
	ets:insert(?ETS_SCENE_MON, NewMinfo),
	TraceState = send_event_after(State, NewMinfo#ets_mon.att_speed),
	{next_state, trace, [NewMinfo, TraceState]}.

add_hp(Minfo, Hp) ->
	NewHp = Minfo#ets_mon.hp + Hp,
    NewMinfo = Minfo#ets_mon{
   		hp = NewHp
    },
    ets:insert(?ETS_SCENE_MON, NewMinfo),
    %% 更新怪物血量，广播给附近玩家
    {ok, BinData} = pt_12:write(12082, [NewMinfo#ets_mon.id, NewHp]),
	lib_send:send_to_online_scene(NewMinfo#ets_mon.scene, NewMinfo#ets_mon.x, NewMinfo#ets_mon.y, BinData),
	NewMinfo.

%% 增加仇恨值
%% Minfo BOSS状态信息
%% AttId 当前攻击方的ID
%% AttPid 当前攻击方的进程ID
%% Hp 战斗后的Hp
%% AttType 1怪物、2人物
add_hate(State, AttId, AttPid, Hate, AttType) ->	
	HateList = State#state.hate,
	NewHateList = 
		case lists:keyfind(AttId, 1, HateList) of
			false ->
				[{AttId, AttPid, AttType, Hate} | HateList];
			{_AttId, _AttPid, _AttType, PreHateVal} ->
				CurHateVal = PreHateVal + Hate,
				lists:keyreplace(AttId, 1, HateList, {AttId, AttPid, AttType, CurHateVal})
		end,
	HateState = State#state{
		hate = NewHateList		
	},
	case lists:member(AttId, HateState#state.player_list) orelse AttType == 1 of
    	false ->
        	HateState#state{
				player_list = [AttId | HateState#state.player_list]
			};
    	true ->
        	HateState
	end.

%% 增加DPS
add_dps(State, AttId, TeamPid, DPS) ->
	DPSList = State#state.dps,
	NewDPSList = 
		case lists:keyfind(AttId, 1, DPSList) of
			false ->
				[{AttId, TeamPid, DPS} | DPSList];
			{_AttId, _PreTeamPid, PreDPSVal} ->
				CurDPSVal = PreDPSVal + DPS,
				lists:keyreplace(AttId, 1, DPSList, {AttId, TeamPid, CurDPSVal})
		end,
	State#state{
		dps = NewDPSList		
	}.

%% 获取攻击目标
get_att_obj(Minfo, State) ->
    %% 是否有技能仇恨
    case State#state.skill_hate of
        [AttId, AttPid, AttType, Expire] ->
            Now = util:unixtime(),
            case Now > Expire of
                true ->
                    NewState = State#state{
                        skill_hate = []					   
                    },
                    get_att_object(Minfo, NewState);
                false ->
					case lib_mon:get_mon_att_object(Minfo#ets_mon.name,Minfo#ets_mon.type,AttType, AttId, Minfo#ets_mon.scene) of
						[] ->
							NewState = State#state{
                                skill_hate = []					   
                            },
                            get_att_object(Minfo, NewState);
						[Object, _Hp, X, Y] ->
                            case lib_mon:trace_action(Minfo, X, Y, State#state.d_x, State#state.d_y) of
                                back ->
                                    NewState = State#state{
                                        skill_hate = []				   
                                    },
                                    get_att_object(Minfo, NewState);
                                attack ->
                                    [SkillInfo, NewState] = get_skill(Minfo, State),
                                    {attack, [NewState, Object, AttPid, AttType, SkillInfo]};
                                trace ->
                                    case lib_mon:trace_line(Minfo#ets_mon.x, Minfo#ets_mon.y, X, Y, Minfo#ets_mon.att_area) of
                                        {MX, MY} ->
                                            {trace, [State, MX, MY]};                    				
                                        _ ->
                                            NewState = State#state{
                                                skill_hate = []				   
                                            },
                                            get_att_object(Minfo, NewState)
                                    end                            
                            end
					end
            end;					
        _ ->
            get_att_object(Minfo, State)
    end.

get_att_object(Minfo, State) ->
	%% 排序仇恨列表
	SortFun = fun({_, _, _, H1}, {_, _, _, H2}) ->
		H1 > H2 
	end,	
	HateList = lists:sort(SortFun, State#state.hate),
	get_att_obj_loop(HateList, Minfo, State).
	
get_att_obj_loop([], _Minfo, State) ->	
	{none, State};
get_att_obj_loop([{AttId, AttPid, AttType, _Hate} | LeftHateList], Minfo, State) ->
	case lib_mon:get_mon_att_object(Minfo#ets_mon.name,Minfo#ets_mon.type,AttType, AttId, Minfo#ets_mon.scene) of
   		[] ->			
          	NewState = State#state{
          		hate = LeftHateList
           	},
			get_att_obj_loop(LeftHateList, Minfo, NewState);
		[Object, _Hp, X, Y] ->			
            case lib_mon:trace_action(Minfo, X, Y, State#state.d_x, State#state.d_y) of
                back ->
					NewState = State#state{
  						hate = LeftHateList
   					},
					get_att_obj_loop(LeftHateList, Minfo, NewState);                            
                attack ->
					[SkillInfo, NewState] = get_skill(Minfo, State),
                    {attack, [NewState, Object, AttPid, AttType, SkillInfo]};
                trace ->
					case lib_mon:trace_line(Minfo#ets_mon.x, Minfo#ets_mon.y, X, Y, Minfo#ets_mon.att_area) of
        				{MX, MY} ->
							{trace, [State, MX, MY]};                    				
        				_ ->
							NewState = State#state{
  								hate = LeftHateList
   							},
							get_att_obj_loop(LeftHateList, Minfo, NewState)
    				end                            
            end
	end.

%% 随机攻击目标
rand_att_obj([], _Minfo, State) ->
	{none, State};
rand_att_obj(HateList, Minfo, State) ->
	Len = length(HateList),
	Rand = random:uniform(Len),
	{AttId, AttPid, AttType, _Hate} = lists:nth(Rand, HateList),
	case lib_mon:get_mon_att_object(Minfo#ets_mon.name,Minfo#ets_mon.type,AttType, AttId, Minfo#ets_mon.scene) of
   		[] ->
			LeftHateList = lists:keydelete(AttId, 1, HateList),
			rand_att_obj(LeftHateList, Minfo, State);
		[Object, _Hp, X, Y] ->
            case lib_mon:trace_action(Minfo, X, Y, State#state.d_x, State#state.d_y) of
                back ->
					LeftHateList = lists:keydelete(AttId, 1, HateList),
					rand_att_obj(LeftHateList, Minfo, State);
                attack ->
					[SkillInfo, NewState] = get_skill(Minfo, State),
                    {attack, [NewState, Object, AttPid, AttType, SkillInfo]};
                trace ->
					case lib_mon:trace_line(Minfo#ets_mon.x, Minfo#ets_mon.y, X, Y, Minfo#ets_mon.att_area) of
        				{MX, MY} ->
							{trace, [State, MX, MY]};                    				
        				_ ->
							LeftHateList = lists:keydelete(AttId, 1, HateList),
							rand_att_obj(LeftHateList, Minfo, State)
    				end                            
            end
	end.

%% 随机获取野外BOSS的刷新点坐标
get_scene_boss_coordinate(RX, RY, SX, SY, MonType) ->
	%% 野外BOSS
	case MonType == 3 andalso is_list(RX) andalso is_list(RY) of
        true ->
            XL = length(RX),
            YL = length(RY),
            case XL > 0 andalso XL == YL of
                true ->
                    Rand = random:uniform(XL),
                    RetX = lists:nth(Rand, RX),
                    RetY = lists:nth(Rand, RY),
                    [RetX, RetY];
                false ->
                    [SX, SY]
            end;
        false ->
            [SX, SY]
	end.

get_top_dps_id(DpsList) ->
	Len = length(DpsList),
	case Len == 1 of
		true ->
			[{PlayerId, _TeamPid, _DPS}] = DpsList,
			[PlayerId, PlayerId];
		false ->
            RetDpsList1 = group_by_dps_loop(DpsList, []),
            %% 排序DPS列表
            SortFun = fun({_, _, DPS1}, {_, _, DPS2}) ->
                DPS1 > DPS2 
            end,	
            NewDpsList1 = lists:sort(SortFun, RetDpsList1),
            {TopDpsId, _TeamPid, _DPS} = lists:nth(1, NewDpsList1),
			RetDpsList2 = lists:keydelete(TopDpsId, 1, DpsList),
			NewDpsList2 = lists:sort(SortFun, RetDpsList2),
			Rand = 
				case Len > 10 of
					true ->
						random:uniform(10);
					false ->
						random:uniform(Len - 1)
				end,
			{RandDpsId, _RandTeamPid, _RandDps} = lists:nth(Rand, NewDpsList2),
            [TopDpsId, RandDpsId]
	end.
group_by_dps_loop([], RetDPSList) ->
	RetDPSList;
group_by_dps_loop([{Id, TeamPid, DPS} | DPSList], RetDPSList) ->
    NewTeamPid = 
        case is_pid(TeamPid) of
            true ->
                TeamPid;
            _ ->
                Id
        end,
    NewRetDPSList = 
        case lists:keyfind(NewTeamPid, 2, RetDPSList) of
            false ->
                [{Id, NewTeamPid, DPS} | RetDPSList];
            {_Id, _TeamPid, PreDPSVal} ->
                CurDPSVal = PreDPSVal + DPS,
                lists:keyreplace(NewTeamPid, 2, RetDPSList, {Id, NewTeamPid, CurDPSVal})
        end,
    group_by_dps_loop(DPSList, NewRetDPSList).

%% 初始回原始数据
init_state(State) ->
	State#state{
		last_skill_time = [],
		battle_limit = 0,
		first_attack = 0,
		conjure_list = [],
		dps = [],
		hate = [],
		skill_hate = [],
		player_list =[],
		is_revive = 0,
		is_die_conjure = 0									   
	}.

%% 判断是否会召唤怪
check_conjure(State, Minfo) ->
	%% 取消持续流血定时器
	misc:cancel_timer(bleed_timer),
	lib_mon:destory_conjure_mon(State#state.conjure_list, Minfo#ets_mon.scene),
	NewState = State#state{
		conjure_list = []					   
	},
    case NewState#state.is_die_conjure == 0 of
        true ->
            case Minfo#ets_mon.relation of
                %% 死后召唤
				[2, MonList] ->
                    case is_list(MonList) of
                        true ->
							mod_scene:conjure_after_die(MonList, Minfo#ets_mon.scene, Minfo#ets_mon.x, Minfo#ets_mon.y),
                            NewState#state{
                                is_die_conjure = 1			
                            };
                        false ->
							NewState
                    end;
				%% 自杀怪
				[4, _Expire, _Area, _Dam, _DamType] ->
					SuicideTimer = get(mon_suicide_timer),
					case SuicideTimer of
						undefined ->
							skip;
						_ ->
							erlang:cancel_timer(SuicideTimer)
					end,
					put(mon_suicide_timer, undefined),
					NewState;
				%% 死后几率召唤
				[6, ConjureMonId, ConjureRate] ->
					case tool:odds(ConjureRate, 100) of
						true ->
							mod_scene:conjure_after_die([ConjureMonId], Minfo#ets_mon.scene, Minfo#ets_mon.x, Minfo#ets_mon.y),
                            NewState#state{
                                is_die_conjure = 1			
                            };
						false ->
							NewState
					end;
                _ ->
					NewState
            end;
        false ->
			NewState
    end.

%% 怪物复活
mon_boss_revive(Minfo, State, StateName, CurAttId) ->
	case StateName of
        revive ->
            {next_state, revive, [Minfo, State]};
        _ ->
            RetAttId = 
                case Minfo#ets_mon.type of
					%% 野外BOSS
                    3 ->
                        %% 第一个攻击怪奖励
                        lib_goods_drop:extra_mon_drop(Minfo, State#state.first_attack),
                        %% 最后一个攻击怪奖励
                        lib_goods_drop:extra_mon_drop(Minfo, CurAttId),
                        [TopDpsId, RandDpsId] = get_top_dps_id(State#state.dps),
                        %% 参与奖励
						if
                      		TopDpsId /= RandDpsId ->
                                lib_goods_drop:extra_mon_drop(Minfo, RandDpsId);
                            true ->
                                skip
                        end,
                        TopDpsId;
					%% 龙塔
					37 ->
						case get(castle_rush_mon) of
							undefined ->
								skip;
							[CastleRushTimer, _T] ->
								catch erlang:cancel_timer(CastleRushTimer)
						end,
						CurAttId;
                    _ ->
                        CurAttId
                end,
            spawn(fun()-> lib_mon:mon_die(Minfo, RetAttId, State#state.player_list, State#state.d_x, State#state.d_y) end),
			ConjureState = check_conjure(State, Minfo),
			ReviveState = send_event_after(ConjureState, Minfo#ets_mon.retime),
    		{next_state, revive, [Minfo, ReviveState]}
    end.

trace_doing(Minfo, State) ->
	%% 采集、捕捉、龙塔、镇妖剑不可攻击
	case lists:member(Minfo#ets_mon.type, [6, 7, 37, 101, 40]) of
		true->
			{next_state, sleep, [Minfo, State]};
		false when State#state.active == 0 ->
			{next_state, sleep, [Minfo, State]};
		false->
            case Minfo#ets_mon.hp > 0 of
                true ->
                    case Minfo#ets_mon.status /= 1 of
                        true ->
							attack_or_trace(Minfo, State);
                        false ->
							BackState = send_event_after(State, 1000),
                            {next_state, back, [Minfo, BackState]}
                    end;
                false ->
                    {next_state, revive, [Minfo, State], Minfo#ets_mon.retime}
            end
	end.

%% 怪物的定时事件
send_event_after(State, Interval) ->
%% 	CancelState = cancel_action_timer(State),
	ActionTimer = gen_fsm:send_event_after(Interval, repeat),
	State#state{
		action_timer = ActionTimer
	}.

%% %% %% 取消怪物动作定时器
%% cancel_action_timer(State) ->
%% 	if
%% 		State#state.action_timer =/= undefined ->
%% 			erlang:cancel_timer(State#state.action_timer);
%% 		true ->
%% 			skip
%% 	end,
%% 	State#state{
%% 		action_timer = undefined
%% 	}.

