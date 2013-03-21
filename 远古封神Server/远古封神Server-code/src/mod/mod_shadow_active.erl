%%%------------------------------------
%%% @Module  : mod_shadow_active
%%% @Author  : ygfs
%%% @Created : 2012.02.23
%%% @Description: 玩家分身
%%%------------------------------------
-module(mod_shadow_active).
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

-define(SHADOW_GUARD_AREA, 100).										%% 分身的攻击范围

-record(state, {    
    last_skill_time = [],					%% [{技能ID,上次时间}]
	hate = [],								%% BOSS仇恨列表
	sleep_time = 0,							%% 睡眠时间
	shadow = 0,								%% 玩家分身ID（该玩家ID）
	skill = [],								%% 技能列表
	action_timer = undefined				%% 怪物动作定时器	
}).

%% 开启一个分身进程
start(Sinfo) ->
    gen_fsm:start_link(?MODULE, Sinfo, []).

init([Player, ShadowId, X, Y, SkillList]) ->
	process_flag(trap_exit, true),
	EquipCurrent = 
		case Player#player.other#player_other.equip_current of
			[Wq, Yf, Fbyf, Spyf, _Mount] ->
				[Wq, Yf, Fbyf, Spyf, 0];
			_ ->
				[0, 0, 0,0, 0]
		end,
	NewPlayer = Player#player{
		id = ShadowId,
		x = X,
		y = Y,
		hp = Player#player.hp_lim,
		mp = Player#player.mp_lim,
		status = 0,
		carry_mark = 0,
		mount = 0,
		speed = ?PLAYER_SPEED,
		att_speed = 1000,
		other = Player#player.other#player_other{
			pid = self(),
			battle_limit = 0,
			shadow = Player#player.id,
			pid_send = [],
			pid_send2 = [],
			pid_send3 = [],
			battle_dict = #battle_dict{},
			is_spring = 0,
			mount_stren = 0,
			equip_current = EquipCurrent
		}
	},
	Data12003 = pt_12:trans_to_12003(NewPlayer),
	{ok, Bin12003} = pt_12:write(12003, Data12003),
	lib_send:send_to_online_scene(Player#player.scene, Bin12003),
	ets:insert(?ETS_ONLINE, NewPlayer),
	ets:insert(?ETS_ONLINE_SCENE, NewPlayer),
	State = #state{
		sleep_time = 2000,
		shadow = Player#player.id,
		skill = SkillList
	},
    {ok, sleep, [NewPlayer, State], 1000}.

handle_event(_Event, StateName, State) ->
    {next_state, StateName, State}.

handle_sync_event(_Event, _From, StateName, State) ->
    {reply, ok, StateName, State}.

%% 记录战斗结果
%% Hp 战斗后的Hp
%% Mp 战斗后的Mp
%% NewAttId 当前攻击方的ID
%% NewAttPid 当前攻击方的进程ID
%% AttPid 上次攻击者的ID
%% Minfo BOSS状态信息
%% AttType 1分身、2人物
handle_info({'PLAYER_BATTLE_RESULT', [Hp, Mp, CurAttPid, CurAttId, _NickName, _Career, _Realm, _SceneId]}, StateName, [Player, State]) ->
	if
  		Player#player.hp > 0 andalso Hp > 0 ->
			Hate = Player#player.hp - Hp,
            NewState = add_hate(State, CurAttId, CurAttPid, Hate, 2),
            NewPlayer = Player#player{
                hp = Hp,
				mp = Mp
            },
            ets:insert(?ETS_ONLINE_SCENE, NewPlayer),
            case StateName of
                trace ->
                    {next_state, trace, [NewPlayer, NewState]};
                _ ->
					attack_or_trace(NewPlayer, NewState)
            end;
        true ->
			{stop, normal, [Player, State]}
    end;


%% 开始一个分身持续流血的计时器	
handle_info({'START_HP_TIMER', Pid, Id, NickName, Career, Realm, Hurt, Time, Interval}, StateName, [Player, State]) ->
	misc:cancel_timer(bleed_timer),
	case StateName /= revive andalso StateName /= back of
		true ->
			if
           		Player#player.hp > 0 ->
                    Hp = 
						if
                      		Player#player.hp > Hurt ->
                                Player#player.hp - Hurt;
                            true ->
                                1
                        end,
                    NewPlayer = Player#player{
                        hp = Hp
                    },
                    ets:insert(?ETS_ONLINE_SCENE, NewPlayer),
                    %% 更新分身血量，广播给附近玩家
                    {ok, BinData} = pt_12:write(12009, [NewPlayer#player.id, Hp,NewPlayer#player.hp_lim]),
					lib_send:send_to_online_scene(NewPlayer#player.scene, NewPlayer#player.x, NewPlayer#player.y, BinData),
                    NewTime = Time - 1,
                    BleedTimer = 
						if
                      		NewTime > 0 ->
                                erlang:send_after(Interval, self(), {'START_HP_TIMER', Pid, Id, NickName, Career, Realm, Hurt, Time, Interval});
                            true ->
                                undefined
                        end,
                    put(bleed_timer, BleedTimer),
                    {next_state, StateName, [NewPlayer, State]};
                true ->
					{stop, normal, [Player, State]}
            end;
		false ->
			{next_state, StateName, [Player, State]}
	end;


%% 定时处理分身信息
%% Interval 倒计时间
%% Message 要处理的消息
handle_info({'SET_TIME_PLAYER', Interval, Message}, StateName, State) ->	
	erlang:send_after(Interval, self(), Message),
	{next_state, StateName, State};


%% 设置分身信息(按字段+数值)
handle_info({'SET_PLAYER_INFO', List}, StateName, [Player, State]) ->
	NewPlayer = lib_player_rw:set_player_info_fields(Player, List),
	ets:insert(?ETS_ONLINE, NewPlayer),
	ets:insert(?ETS_ONLINE_SCENE, NewPlayer),
	{next_state, StateName, [NewPlayer, State]};

%% 更改分身BUFF
handle_info({'SET_MON_BUFF', Buff}, StateName, [Player, State]) ->	
	NewPlayer = Player#player{
		other = Player#player.other#player_other{
			battle_status = Buff
		}
    },
    ets:insert(?ETS_ONLINE_SCENE, NewPlayer),
	{next_state, StateName, [NewPlayer, State]};

%% 设置战斗中产生的修改
handle_info({'SET_BATTLE_STATUS', {Type, Data}}, StateName, [Player, State]) ->
	NewPlayer = 
        case Type of
			%% 限制状态
            1 -> 
                [Buff, BattleLimit, Interval] = Data,
                erlang:send_after(Interval, self(), {'SET_PLAYER_INFO', [{battle_limit, 0}]}),
				Player#player{
             		other = Player#player.other#player_other{
             			battle_status = Buff,
						battle_limit = BattleLimit								  
              		}						
               	};
            %% 减速
            2 ->
				[_Buff, Mount, NewSpeed, _Speed, Interval] = Data,
				%% 速度的重新计算方式改变
				%% mount ,speed 似乎已经没有作用
				case get(change_speed_timer) of
					undefined ->
						skip;
					[undefined, _, _] ->
						skip;
					[OldChangeSpeedTimer, _Sp, _Mnt] ->
						erlang:cancel_timer(OldChangeSpeedTimer)
				end,
                {ok, BinData} =  pt_20:write(20009, [Player#player.id, NewSpeed]),
				lib_send:send_to_online_scene(Player#player.scene, BinData),
                ChangeSpeedTimer = erlang:send_after(Interval, self(), {'CHANGE_SPEED', Player#player.speed, Mount}),
				put(change_speed_timer, [ChangeSpeedTimer, Player#player.speed, Mount]),
                Player#player{
					speed = NewSpeed
				};
            _ -> 
           		Player
        end,
	ets:insert(?ETS_ONLINE, NewPlayer),
	ets:insert(?ETS_ONLINE_SCENE, NewPlayer),
	{next_state, StateName, [NewPlayer, State]};

%% 改变玩家移动速度
handle_info({'CHANGE_SPEED', Speed, _Mount}, StateName, [Player, State]) ->
	case get(change_speed_timer) of
		[undefined, _, _] ->
			skip;
		[ChangeSpeedTimer, _, _] ->
			erlang:cancel_timer(ChangeSpeedTimer);
		_ ->
			skip
	end,
	put(change_speed_timer, [undefined, ?PLAYER_SPEED, 0]),
	{ok, BinData} =  pt_20:write(20009, [Player#player.id, Speed]),
	lib_send:send_to_online_scene(Player#player.scene, BinData),
	NewPlayer = Player#player{
		speed = Speed						 
	},
	ets:insert(?ETS_ONLINE, NewPlayer),
	ets:insert(?ETS_ONLINE_SCENE, NewPlayer),
	{next_state, StateName, [NewPlayer, State]};

%% 清除进程
handle_info(clear, _StateName, State) ->
    {stop, normal, State};

handle_info(_Info, StateName, State) ->
    {next_state, StateName, State}.

terminate(_Reason, _StateName, [Player, State]) ->
	cancel_action_timer(State),
	catch ets:delete(?ETS_ONLINE, Player#player.id),
	catch ets:delete(?ETS_ONLINE_SCENE, Player#player.id), 
	ScenePid = mod_scene:get_scene_real_pid(Player#player.scene),
	case lib_war2:is_fight_scene(Player#player.scene) of
		false->
			gen_server:cast(ScenePid, {'SHADOW_DIE', Player#player.other#player_other.shadow});
		true->
			%%跨服单人竞技分身死亡
			gen_server:cast(ScenePid, {'SHADOW_DIE',[Player#player.other#player_other.shadow,Player#player.nickname]})
	end,
	%%需要清理分身尸体的场景
	Is_era_scene = lib_era:is_era_scene(Player#player.scene),
	if
		Is_era_scene ->
			{ok,BinData} = pt_12:write(12004,Player#player.id),
			lib_send:send_to_online_scene(Player#player.scene, Player#player.x, Player#player.y, BinData);
		true ->
			skip
	end,
	ok.

code_change(_OldVsn, StateName, Status, _Extra) ->
    {ok, StateName, Status}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 处理分身所有状态
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 静止状态并回血
sleep(timeout, [Player, State]) ->
	CancelState = cancel_action_timer(State),
    sleep_action(Player, CancelState);
sleep(repeat, Status) ->    
    sleep(timeout, Status);
sleep(_R, Status) ->
    sleep(timeout, Status).

%% 跟踪目标
trace(timeout, [Player, State]) ->
	CancelState = cancel_action_timer(State),
	attack_or_trace(Player, CancelState);
trace(repeat, Status) ->    
    trace(timeout, Status);
trace(_R, Status) ->    
    trace(timeout, Status).

%% 返回默认出生点
back(timeout, [Player, State]) ->
	CancelState = cancel_action_timer(State),
	sleep(timeout, [Player, CancelState]);
back(repeat, Status) ->    
	back(timeout, Status);
back(_R, Status) ->
    sleep(timeout, Status).

%% 复活
revive(timeout, Status) ->
	{stop, normal, Status};
revive(repeat, Status) ->
	revive(timeout, Status);
revive(_R, Status) ->
	revive(timeout, Status).

%% 分身攻击移动
attack_move(X, Y, [Player, State]) ->
	case lists:member(Player#player.other#player_other.battle_limit, [0, 3]) of
		true ->
			{ok, BinData} = pt_12:write(12001, [X, Y, Player#player.id]),
			lib_send:send_to_online_scene(Player#player.scene, BinData),
			NewPlayer = Player#player{
		        x = X,
		        y = Y
		    },
			ets:insert(?ETS_ONLINE, NewPlayer),
			ets:insert(?ETS_ONLINE_SCENE, NewPlayer),
			TraceState = send_event_after(State, 600),
		   	{next_state, trace, [NewPlayer, TraceState]};	
		false ->
			BackState = send_event_after(State, 1000),
		  	{next_state, back, [Player, BackState]}
	end.
	       


%% 获取BOSS技能
get_skill(State) ->
	Now = util:longunixtime(),
	%% 获取可施放的技能ID
	SkillIdList = get_skill_loop(State#state.skill, State#state.last_skill_time, Now, []),
	Len = length(SkillIdList),
	if
		Len > 0 ->
			%% 随机获取一个技能
			Rand = random:uniform(Len),
			SkillId = lists:nth(Rand, SkillIdList),			
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
			[SkillId, NewState];
		true ->
			[0, State]		
	end.
get_skill_loop([], _LastSkillTime, _Now, SkillIdList) ->
	SkillIdList;
get_skill_loop([{SkillId, CD, _HpStart, _HpEnd, _Other} | S], LastSkillTime, Now, SkillIdList) ->
	%% 判断CD
    case lists:keyfind(SkillId, 1, LastSkillTime) of
        false ->
            get_skill_loop(S, LastSkillTime, Now, [SkillId | SkillIdList]);
        {_, LastTime} ->
			if
          		LastTime + CD > Now ->
                    get_skill_loop(S, LastSkillTime, Now, SkillIdList);       
                true ->
                    get_skill_loop(S, LastSkillTime, Now, [SkillId | SkillIdList])
            end
    end.

attack_or_trace(Shadow, State) ->
	Now = util:unixtime(),
	if
		Now > Shadow#player.other#player_other.die_time andalso Shadow#player.other#player_other.battle_limit /= 2 ->
			case get_att_object(Shadow, State) of
		        %% 可以进行攻击
				{attack, [NewState, Player, AttPid, AttType, SkillId]} ->
					mon_attack(Shadow, Player, AttPid, AttType, NewState, SkillId);
		        %% 还不能进行攻击就追踪
				{trace, [NewState, X, Y]} ->
					attack_move(X, Y, [Shadow, NewState]);
		        %% 停止追踪
				{none, NewState} ->
					case get_area_mon_for_battle(Shadow#player.scene, Shadow#player.x, Shadow#player.y, ?SHADOW_GUARD_AREA, 41, NewState#state.shadow) of
		          		[] ->
							BackState = send_event_after(NewState, 1000),
							{next_state, back, [Shadow, BackState]};
		             	[AttId, AttPid, AttType] ->
		               		HateState = NewState#state{        
		               			hate = [{AttId, AttPid, AttType, 1} | NewState#state.hate]
		                  	},
							TraceState = send_event_after(HateState, Shadow#player.att_speed),
							{next_state, trace, [Shadow, TraceState]}
		           	end;
				_ -> 	
					BackState = send_event_after(State, 1000),
		            {next_state, back, [Shadow, BackState]}        
		    end;		
		true ->
			BackState = send_event_after(State, 1000),
		  	{next_state, back, [Shadow, BackState]}
	end.
    

%% 分身攻击
%% AttType 攻击对象类型，1分身、2人物
mon_attack(Shadow, Player, _AttPid, AttType, State, SkillId) ->
	Now = util:unixtime(),
	BattleDict = Shadow#player.other#player_other.battle_dict,
	{NewSkillId, Slv, NewSkillData, BattleMod, ShadowMp} =
		case data_skill:get(SkillId, 1) of
        	[] ->
				{0, 0, [], 1, Shadow#player.mp};
			SkillData ->
				{_, [{_, MpOut1}, {_, _CD}, {_, _Att_Area}]} = lists:keyfind(cast, 1, SkillData#ets_skill.data),
				MpOut = 
	                case is_float(MpOut1) of
	                    true ->
	                        round(MpOut1 * Shadow#player.mp_lim);
	                    _ ->
	                        MpOut1
	                end,
				LeftMp = Shadow#player.mp - MpOut,
				if
					LeftMp > 0 ->
						{SkillId, 1, SkillData, SkillData#ets_skill.mod, LeftMp};
					true ->
						{0, 0, [], 1, Shadow#player.mp}
				end
		end,
	MpShadow = Shadow#player{
		mp = ShadowMp					 
	},
	NewShadow = mod_battle:attack([MpShadow, 2], [Player, AttType], NewSkillData, BattleDict, NewSkillId, Slv, BattleMod, 2, Now),
	ets:insert(?ETS_ONLINE_SCENE, NewShadow),
	TraceState = send_event_after(State, NewShadow#player.att_speed),
	{next_state, trace, [NewShadow, TraceState]}.

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

%% 增加仇恨值
%% Minfo BOSS状态信息
%% AttId 当前攻击方的ID
%% AttPid 当前攻击方的进程ID
%% Hp 战斗后的Hp
%% AttType 1分身、2人物
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
	State#state{
		hate = NewHateList		
	}.


get_att_object(Player, State) ->
	%% 排序仇恨列表
	SortFun = fun({_, _, _, H1}, {_, _, _, H2}) ->
		H1 > H2 
	end,	
	HateList = lists:sort(SortFun, State#state.hate),
	get_att_obj_loop(HateList, Player, State).
	
get_att_obj_loop([], _Player, State) ->	
	{none, State};
get_att_obj_loop([{AttId, AttPid, AttType, _Hate} | LeftHateList], Player, State) ->
	case lib_mon:get_mon_att_object(Player#player.nickname, 41, AttType, AttId, Player#player.scene) of
   		[] ->
          	NewState = State#state{
          		hate = LeftHateList
           	},
			get_att_obj_loop(LeftHateList, Player, NewState);
		[Object, _Hp, X, Y] ->	
            case trace_action(Player, X, Y) of
                attack ->
					[SkillId, NewState] = get_skill(State),
                    {attack, [NewState, Object, AttPid, AttType, SkillId]};
                trace ->
					case lib_mon:trace_line(Player#player.x, Player#player.y, X, Y, Player#player.att_area) of
        				{MX, MY} ->
							{trace, [State, MX, MY]};                    				
        				_ ->
							NewState = State#state{
  								hate = LeftHateList
   							},
							get_att_obj_loop(LeftHateList, Player, NewState)
    				end                            
            end
	end.


%% Player 分身信息
%% X 被击方的X坐标
%% Y 被击方的Y坐标 
trace_action(Player, X, Y) ->    
    DX = abs(Player#player.x - X),
	if
  		Player#player.att_area >= DX ->
            DY = abs(Player#player.y - Y),
			if
          		Player#player.att_area >= DY ->
                    attack;
                true ->
					trace
            end;
        true ->
			trace
    end.

%% 静止动作
sleep_action(Player, State) ->
	%% 判断是否死亡
	if
  		Player#player.hp > 0 ->
			case get_area_mon_for_battle(Player#player.scene, Player#player.x, Player#player.y, ?SHADOW_GUARD_AREA, 41, State#state.shadow) of
          		[] ->
					{next_state, sleep, [Player, State], State#state.sleep_time};
             	[AttId, AttPid, AttType] ->
					case lists:keyfind(AttId, 1, State#state.hate) of
						false ->
							HateState = State#state{        
           						hate = [{AttId, AttPid, AttType, 1} | State#state.hate]
              				},
							attack_or_trace(Player, HateState);
						_ ->
							attack_or_trace(Player, State)
					end
           	end;
        true ->
			{stop, normal, [Player, State]}
    end.

%% 获取范围内的分身(分身使用)
get_area_mon_for_battle(SceneId, X, Y, GuardArea, MonType, Shadow) ->	
    X1 = X + GuardArea,
    X2 = X - GuardArea,
    Y1 = Y + GuardArea,
    Y2 = Y - GuardArea,
	MS = ets:fun2ms(fun(P) when P#player.scene == SceneId, P#player.hp > 0, P#player.x >= X2, 
								P#player.x =< X1, P#player.y >= Y2, P#player.y =< Y1, 
								P#player.other#player_other.shadow /= Shadow, P#player.id /= Shadow, 
								P#player.carry_mark /= 29 ->
		[
			P#player.id, 
			P#player.other#player_other.pid, 
			P#player.x, 
			P#player.y,
			0,
			2			
		]
	end),
	All = ets:select(?ETS_ONLINE_SCENE, MS),
    lib_scene:get_area_mon_for_battlle_loop(All, X, Y, 1000000, MonType, []).


