%%%------------------------------------
%%% @Module  : mod_arena_new
%%% @Author  : ygfs
%%% @Created : 2012.02.15
%%% @Description: 战场
%%%------------------------------------
-module(mod_arena_new).

-behaviour(gen_server).
-include("common.hrl").
-include("record.hrl").

-export(
	[
	 	init/1, 
		handle_call/3, 
		handle_cast/2, 
		handle_info/2, 
		terminate/2, 
		code_change/3
	]
).
-export(
    [
   		start/4,
		start/5
    ]
).

-define(DIE_NUM, 1).												%% 意外退出战场的死亡次数
-define(DIE_INTERVAL, 120).											%% 死亡间隔
-define(QUIT_DELAY_TIME, 180).										%% 掉线等待时间

-record(competitor, {
	player_id = 0,					
	nickname = [],							
    realm = 0,							
    career = 0,   				
    lv = 0, 	
    mark = 0,    				
	kill = 0,
	realm_kill = 0,
	die = 0,
	att = 0,
	sex = 0,
	timer = undefined,
	sta = 0,														%% 1离开				
	last_die_time = []												%% 上次死亡的时间
}).

-record(state, {
	worker_id = 0,													%% 进程工作ID
	level = 0,
	zone = 0,														%% 战场等级				
	battle_id = 0,													%% 战场ID				
    dragon_realm = 0,												%% 天龙方比分
    dragon_num = 15,													%% 天龙放人数
	tiger_realm = 0,   												%% 地虎方比分
    tiger_num = 15,													%% 地虎方人数
	human_realm = 0,												%% 人王分数
	human_num = 15,													%% 人王方人数
	member = [],													%% 战场成员
	is_end = 0														%%  战场是否结束
}).
											
%% 启动角色主进程
start(Level, Zone, BattleId, MemberList) ->
    gen_server:start(?MODULE, [Level, Zone, BattleId, MemberList, 0], []).

start(Level, Zone, BattleSceneId, MemberList, WorkerId) ->
	gen_server:start_link(?MODULE, [Level, Zone, BattleSceneId, MemberList, WorkerId], []).

init([Level, Zone, BattleSceneId, MemberList, WorkerId]) ->
	process_flag(trap_exit, true),
	Self = self(),
	SceneProcessName = misc:create_process_name(scene_p, [BattleSceneId, WorkerId]),
	misc:register(global, SceneProcessName, Self),
    if
        WorkerId =:= 0 ->
			%% 清除上一次攻城战的人物数据
			catch ets:match_delete(?ETS_ONLINE_SCENE, #player{ scene = BattleSceneId, _ = '_' }),
			%% 删除上一次战场的怪物数据
			mod_mon_create:clear_scene_mon(BattleSceneId),
            %% 复制场景数据
            lib_scene:copy_scene(BattleSceneId, ?NEW_ARENA_RES_SCENE_ID),
            misc:write_monitor_pid(Self, ?MODULE, {BattleSceneId}),
            %% 初始战场成员数据
            [NewMemberList, DragonNum, TigerNum, HumanNum] = init_arena_member_data(MemberList),
			%% 通知战场已经初始好
			spawn(fun()-> notice_arena_start(NewMemberList, Level, BattleSceneId, Self) end),
            %% 启动战场服务进程
            lists:foreach(
                fun(WorkId) ->
                    mod_arena:start(Level, Zone, BattleSceneId, MemberList, WorkId)
                end,
            lists:seq(1, ?SCENE_WORKER_NUMBER)),
            State = #state{
                worker_id = WorkerId,
                level = Level,
                zone = Zone,
                battle_id = BattleSceneId,
                dragon_num = DragonNum,
                tiger_num = TigerNum,
				human_num = HumanNum,
                member = NewMemberList
            },
            {ok, State};
        true ->
            State = #state{
                worker_id = WorkerId,
				battle_id = BattleSceneId
            },
            {ok, State}
    end.

%% 是否参加了战场
handle_call({'CHECK_JOIN_ARENA', PlayerId}, _From, State) ->
	Reply = 
		case State#state.is_end /= 1 of
			true ->
				case lists:keyfind(PlayerId, 2, State#state.member) of
					false ->
						0;
					Competitor ->
						[1, State#state.battle_id, Competitor#competitor.mark, Competitor#competitor.die]
				end;
			false ->
				0
		end,
	{reply, Reply, State};

%% 统一模块+过程调用(call)
handle_call({apply_call, Module, Method, Args}, _From, State) ->	
	Reply  = 
		case (catch apply(Module, Method, Args)) of
			{'EXIT', Info} ->	
?WARNING_MSG("mod_arena_apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
			 	error;
		 	DataRet -> 
				DataRet
		end,
    {reply, Reply, State};

handle_call(_Request, _From, State) ->
    {reply, State, State}.

%% 战场死亡
handle_cast({'ARENA_DIE', AerId, DerId}, State) ->
	NewState =
		case State#state.is_end /= 1 andalso AerId /= DerId of
			true ->
				MemberList = State#state.member,
                case lists:keyfind(AerId, 2, MemberList) of
                    false ->
                        State;
					Aer ->
                        case lists:keyfind(DerId, 2, MemberList) of
                            false ->
                                State;
							Der ->
								Now = util:unixtime(),
								{RetAer, RetDer} = 
									case check_valid_die(Der, AerId, Now) of
										{true, NewDer} ->
	                                        RA = Aer#competitor{
												realm_kill = Aer#competitor.realm_kill + 1
	                                 		},
											{RA, NewDer};
										_ ->
											{Aer, Der}
									end,
								[NewDragon, NewTiger, NewHuman] = 
                                    case Aer#competitor.mark of
                                        %% 天龙
                                        8 ->
                                            [State#state.dragon_realm + 1, State#state.tiger_realm, State#state.human_realm];
                                        %% 地虎
                                        9 ->
                                            [State#state.dragon_realm, State#state.tiger_realm + 1, State#state.human_realm];
										%% 人王
										_ ->
											[State#state.dragon_realm, State#state.tiger_realm, State#state.human_realm + 1]
                                    end,
                                {ok, BinData} = pt_23:write(23006, [RetAer#competitor.player_id, RetAer#competitor.nickname, RetDer#competitor.player_id, Der#competitor.nickname, NewDragon, NewTiger, NewHuman]),
                                %% 广播比分
								lib_send:send_to_online_scene(State#state.battle_id, BinData),
                                NewKill = RetAer#competitor.kill + 1,
                                NewAer = RetAer#competitor{
                                    kill = NewKill					
                                },
                                lib_arena:broadcast_new_arena_msg(Aer#competitor.player_id, Aer#competitor.nickname, Aer#competitor.career, Aer#competitor.sex, Aer#competitor.realm, NewKill),
                                AerMemberList = lists:keyreplace(AerId, 2, MemberList, NewAer),
                                DerMemberList = lists:keyreplace(DerId, 2, AerMemberList, RetDer),
								State#state{
                                    dragon_realm = NewDragon,
                                    tiger_realm = NewTiger,
									human_realm = NewHuman,
                                    member = DerMemberList			
                         		}
						end
                end;
			false ->
				State
		end,
    {noreply, NewState};

%% 结束战场进程
handle_cast('KILL_ARENA', State) ->
	%% 判断还有没有人在战场
	Fun = fun(A)->
		case lib_player:get_player_pid(A#competitor.player_id) of
			[] ->
				no_pid;
			Pid ->
				gen_server:cast(Pid, 'ARENA_FINAL_CHECK')	
		end		  
	end,
	[Fun(A) || A <- State#state.member],
	{stop, normal, State};

%% 战场正式开始
handle_cast('ARENA_START', State) ->
	if
		State#state.is_end =/= 1 ->
			ArenaPid = self(),
			ArenaZone = State#state.level,
			ArenaSceneId = State#state.battle_id,
			Fun = fun(A)->
				case lib_player:get_player_pid(A#competitor.player_id) of
					[] ->
						skip;
					Pid ->
						gen_server:cast(Pid, {'ARENA_START', 2, ArenaZone, ArenaSceneId, ArenaPid})
				end		  
			end,
			[Fun(A) || A <- State#state.member];
		true ->
			skip
	end,
	{noreply, State};

%% 退出战场
handle_cast({'LEAVE_ARENA', PlayerId}, State) ->
	spawn(fun()-> lib_arena:leave_arena(PlayerId, State#state.battle_id) end),
	{noreply, State};

%% 战场玩家意外退出处理
handle_cast({'PLAYER_TERMINATE_QUIT', PlayerId}, State) ->
	spawn(fun()-> lib_arena:leave_arena(PlayerId, State#state.battle_id) end),
	{noreply, State};

%% 获取竞技战斗中的排名列表
handle_cast({'GET_ARENA_MEMBER', PidSend}, State) ->
	spawn(fun()->
		ArenaInfo = get_arena_info(State#state.member, []),
		{ok, BinData} = pt_23:write(23005, [State#state.dragon_realm, State#state.tiger_realm, State#state.human_realm, ArenaInfo, State#state.zone]),
	    lib_send:send_to_sid(PidSend, BinData)	  
	end),
	{noreply, State};

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%% 统一模块+过程调用(cast)
handle_cast({apply_cast, Module, Method, Args}, State) ->	
%% 	case (catch apply(Module, Method, Args)) of
%% 		 {'EXIT', Info} ->	
%% ?WARNING_MSG("mod_dungeon_apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
%% 			 error;
%% 		 _ -> ok
%% 	end,
	spawn(fun()-> apply(Module, Method, Args) end),
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

%% 战场结束
handle_info('END_ARENA', State) ->
	if
		State#state.is_end /= 1 ->
			WinSide = get_win_side(State),
			end_arena(State, WinSide);
		true ->
			skip
	end,
	NewState = State#state{
		is_end = 1
	},
	{noreply, NewState};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, State) ->
	misc:delete_monitor_pid(self()),
	if
		State#state.worker_id =:= 0 ->
%%?WARNING_MSG("ARENA_SUB_PROC_TERMINATE: Reason ~p~n State ~p~n", [Reason, State]),
			spawn(fun()-> lib_scene:clear_scene(State#state.battle_id) end);
		true ->
			skip
	end,
	%misc:delete_system_info(self()),	
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%% 初始战场成员数据
init_arena_member_data(MemberList) ->
	Half = util:floor(length(MemberList) / 3),
	init_arena_member_data_loop(MemberList, Half, 0, 0, 0, [], 0, 0, 0).
init_arena_member_data_loop([], _Half, _A1, _A2, _A3, MemberList, DragonNum, TigerNum, HumanNum) ->
	[MemberList, DragonNum, TigerNum, HumanNum];
init_arena_member_data_loop([{PlayerId, NickName, Realm, Career, Lv, Att, Sex} | M], Half, A1, A2, A3, MemberList, DragonNum, TigerNum, HumanNum) ->
	[NA1, NA2, NA3, Mark, NewDragonNum, NewTigerNum, NewHumanNum] =
        if
			A1 =< A2 andalso A1 =< A3 ->
                [A1 + Att, A2, A3, 8, DragonNum + 1, TigerNum, HumanNum];
            A2 =< A1 andalso A2 =< A3 ->
                [A1, A2 + Att, A3, 9, DragonNum, TigerNum + 1, HumanNum];
			A3 =< A1 andalso A3 =< A2 ->
				[A1, A2, A3 + Att, 10, DragonNum, TigerNum, HumanNum + 1];
            DragonNum < Half andalso A1 < A2 andalso A1 < A3 ->
                [A1 + Att, A2, A3, 8, DragonNum + 1, TigerNum, HumanNum];
            TigerNum < Half andalso A2 < A1 andalso A2 < A3 ->
                [A1, A2 + Att, 9, A3, DragonNum, TigerNum + 1, HumanNum];
			HumanNum < Half andalso A3 < A1 andalso A3 < A2 ->
				[A1, A2, A3 + Att, 10, DragonNum, TigerNum, HumanNum + 1];
            DragonNum >= Half andalso HumanNum >= Half andalso Half /= 0 -> 
                [A1, A2 + Att, A3, 9, DragonNum, TigerNum + 1, HumanNum];
            TigerNum >= Half andalso HumanNum >= Half andalso Half /= 0 ->
                [A1 + Att, A2, A3, 8, DragonNum + 1, TigerNum, HumanNum];
			DragonNum >= Half andalso TigerNum >= Half andalso Half /= 0 ->
				[A1, A2, A3 + Att, 10, DragonNum, TigerNum, HumanNum + 1];
            true ->
                [A1 + Att, A2, A3, 8, DragonNum + 1, TigerNum, HumanNum]
        end,
	Competitor = #competitor{
		player_id = PlayerId,					
		nickname = NickName,							
    	realm = Realm,							
    	career = Career,   				
    	lv = Lv, 	
    	mark = Mark,    				
		sex = Sex,
		att = Att			 
	},
	init_arena_member_data_loop(M, Half, NA1, NA2, NA3, [Competitor | MemberList], NewDragonNum, NewTigerNum, NewHumanNum).

get_arena_info([], RetList) ->
	RetList;
get_arena_info([A | M], RetList) ->	
	get_arena_info(M, [{A#competitor.player_id, A#competitor.nickname, A#competitor.career, A#competitor.kill, A#competitor.mark} | RetList]).

%% 竞技结束
end_arena(State, WinSide) ->	
	Member = State#state.member,		
	Now = util:unixtime(),
	[RankList, ArenaList, ArenaWeekList, ScoreList] = arena_rank(Member, WinSide, State#state.zone, Now, [], [], [], []),
	
	%% 战场结果
	SortFun1 = fun([_, _, _, L1, _, K1, S1], [_, _, _, L2, _, K2, S2]) ->
		case S1 /= S2 of
			true ->
				S1 > S2;
			false ->
				case K1 /= K2 of
					true ->
						K1 > K2;
					false ->
						L1 < L2
				end
				
		end
	end,
	NewRankList = lists:sort(SortFun1, RankList),
	
	SortFun2 = fun({_, _, _, _, S1}, {_, _, _, _, S2}) ->
		S1 > S2 
	end,
	NewScoreList = lists:sort(SortFun2, ScoreList),
	[{WinPlayerId, WinNickName, WinCareer, WinSex, _Score} | _] = NewScoreList,	
	LevelName = lib_arena:get_arena_level_name(State#state.level),
	WinSideName = lib_arena:get_arena_side_name(WinSide),
	DataList = [
		LevelName,
		State#state.zone,
		WinSideName,
		WinPlayerId,
		WinNickName,
		WinCareer,
		WinSex,
		WinNickName		
	],
	Msg = io_lib:format("~s级战场第 <font color='#FEDB4F'>~p</font> 战区 <font color='#FEDB4F'>~s</font> 方获得本次战场胜利！<a href='event:1, ~p, ~s, ~p, ~p'><font color='#FEDB4F'>[~s]</font></a> 获得本次战区第一！", DataList),
	lib_chat:broadcast_sys_msg(2, Msg),
	Data = [State#state.level - 1, State#state.zone - 1, 1, WinSide - 7, 1, NewRankList],
	{ok, BinData} = pt_23:write(23020, Data),
	end_arena_loop(ArenaWeekList, BinData),
	update_arena_database(ArenaList),
	update_arena_week_database(ArenaWeekList).
end_arena_loop([], _BinData) ->
	ok;
end_arena_loop([{PlayerId, _NickName, _Realm, _Career, _Lv, _Area, _Mark, _Win, Score, _Now, Kill} | M], BinData) ->
	case lib_player:get_player_pid(PlayerId) of
		[] ->
			spawn(fun()-> db_agent:update_arena_score_add(PlayerId, Score, 0) end);
		Pid ->
			gen_server:cast(Pid, {'END_ARENA', BinData, Score, Kill})	
	end,	
	end_arena_loop(M, BinData).

arena_rank([], _WinSide, _Area, _Now, Ret, List, Week, ScoreList) ->
	[Ret, List, Week, ScoreList];
arena_rank([A | M], WinSide, Area, Now, Ret, List, Week, ScoreList) ->
	#competitor{
		player_id = PlayerId,
		nickname = NickName,
		realm = Realm,
		career = Career,
		lv = Lv,
		mark = Mark,
		realm_kill = RealmKill,
		kill = Kill,
		sex = Sex	
	} = A,
	{Win, Score, KillParam} =
		if
			WinSide == Mark ->
				{1, 35, 1};
			true ->
				{0, 20, 0.75}
		end,
	NewScore = util:ceil(Score + KillParam * RealmKill),
	NewRet = [[NickName, Realm, Career, Lv, Mark - 7, Kill, NewScore] | Ret],
	NewList = [{PlayerId, NickName, Realm, Career, Lv, A#competitor.att, Sex, Win, Kill} | List],
	NewWeek = [{PlayerId, NickName, Realm, Career, Lv, Area, Mark - 7, Win + 1, NewScore, Now, Kill} | Week],
	NewScoreList = [{PlayerId, NickName, Career, Sex, NewScore} | ScoreList],
	arena_rank(M, WinSide, Area, Now, NewRet, NewList, NewWeek, NewScoreList).


%% 8天龙，9地虎
get_win_side(State) ->
	if
		State#state.dragon_realm > State#state.tiger_realm andalso State#state.dragon_realm > State#state.human_realm ->
			8;
		State#state.tiger_realm > State#state.dragon_realm andalso State#state.tiger_realm > State#state.human_realm ->
			9;
		State#state.human_realm > State#state.dragon_realm andalso State#state.human_realm > State#state.tiger_realm ->
			10;
		State#state.dragon_num < State#state.tiger_num andalso State#state.dragon_num < State#state.human_num ->
			8;
		State#state.tiger_num < State#state.dragon_num andalso State#state.tiger_num < State#state.human_num ->
			9;
		State#state.human_num < State#state.dragon_num andalso State#state.human_num > State#state.tiger_num ->
			10;
		true ->
			random:uniform(3) + 7
	end.

update_arena_database([]) ->
	ok;
update_arena_database([A | D]) ->
	spawn(fun()-> lib_arena:replace_ets_arena(A) end),
	update_arena_database(D).

update_arena_week_database([]) ->
	ok;
update_arena_week_database([A | D]) ->
	spawn(fun()-> lib_arena:replace_ets_arena_week(A) end),
	update_arena_week_database(D).

%% 判断被击杀者是否合法击杀
check_valid_die(Der, AerId, Now) ->
	case lists:keyfind(AerId, 1, Der#competitor.last_die_time) of
		false ->
			NewDer = Der#competitor{
				last_die_time = [{AerId, Now} | Der#competitor.last_die_time]						
			},
			{true, NewDer};
		{_AerId, DieTime} ->
			if
				Now - DieTime > ?DIE_INTERVAL ->
					LastDieTime = lists:keyreplace(AerId, 1, Der#competitor.last_die_time, {AerId, Now}),
					NewDer = Der#competitor{
						last_die_time = LastDieTime					
					},
					{true, NewDer};
				true ->
					false
			end
	end.

%% 通知战场已经初始好
notice_arena_start(ArenaMember, ArenaZone, ArenaSceneId, ArenaPid) ->
	Fun = fun(A) ->
		case lib_player:get_player_pid(A#competitor.player_id) of
			[] ->
				no_pid;
			Pid ->
				gen_server:cast(Pid, {'NOTICE_ENTER_ARENA', A#competitor.mark, ArenaZone, ArenaSceneId, ArenaPid})	
		end	  
	end,
	[Fun(M) || M <- ArenaMember].

