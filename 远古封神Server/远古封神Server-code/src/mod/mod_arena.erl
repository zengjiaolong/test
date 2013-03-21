%%%------------------------------------
%%% @Module  : mod_arena
%%% @Author  : ygfs
%%% @Created : 2011.02.16
%%% @Description: 战场
%%%------------------------------------
-module(mod_arena).

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
-define(END_DELAY_TIME, 1000).										%% 战场完毕的延迟秒数
-define(QUIT_DELAY_TIME, 180).										%% 掉线等待时间

-record(competitor, {
	player_id = 0,					
	nickname = [],							
    realm = 0,							
    career = 0,   				
    lv = 0, 	
    mark = 0,    				
	kill = 0,
	die = 0,
	att = 0,
	sex = 0,
	timer = undefined,
	sta = 0,														%% 1离开				
	last_die_time = 0												%% 上次死亡的时间
}).

-record(state, {
	worker_id = 0,													%% 进程工作ID
	level = 0,
	zone = 0,														%% 战场等级				
	battle_id = 0,													%% 战场ID				
    dragon_realm = 0,												%% 天龙方比分
    dragon_num = 0,													%% 天龙放人数
	tiger_realm = 0,   												%% 地虎方比分
    tiger_num = 0,													%% 地虎方人数
	member = [],													%% 战场成员
	is_end= 0														%%  战场是否结束
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
			%% 清除上一次战场的人物数据
			catch ets:match_delete(?ETS_ONLINE_SCENE, #player{ scene = BattleSceneId, _ = '_' }),
			%% 删除上一次战场的怪物数据
			mod_mon_create:clear_scene_mon(BattleSceneId),
            %% 复制场景数据
            lib_scene:copy_scene(BattleSceneId, ?ARENA_RES_SCENE_ID),
            misc:write_monitor_pid(Self, ?MODULE, {BattleSceneId}),
			ArenaDieNum = lib_arena:get_arena_die_num(),
            %% 初始战场成员数据
            [NewMemberList, DragonNum, TigerNum] = init_arena_member_data(MemberList, ArenaDieNum),
            ArenaScore =
				if
   					DragonNum > TigerNum ->
    					DragonNum * ArenaDieNum;
      				true ->
  						TigerNum * ArenaDieNum
 				end,
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
                dragon_realm = ArenaScore,
                dragon_num = DragonNum,
                tiger_realm = ArenaScore,
                tiger_num = TigerNum,
                member = NewMemberList
            },
			
			%% 通知进入战场
			spawn(fun()-> notice_enter_arena(State, Self) end),
			
            {ok, State};
        true ->
            State = #state{
                worker_id = WorkerId			   
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
						%% 判断是否退出过
						case Competitor#competitor.sta == 0 of
							true ->
								[1, State#state.battle_id, Competitor#competitor.mark, Competitor#competitor.die];
							false ->
								2
						end
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
								case Der#competitor.die > 0 andalso Now - Der#competitor.last_die_time > 4 of
									true ->
                                        [NewDragon, NewTiger] = 
                                            case Der#competitor.mark of
                                                %% 天龙
                                                8 ->
                                                    [State#state.dragon_realm - 1, State#state.tiger_realm];
                                                %% 地虎
                                                _ ->
                                                    [State#state.dragon_realm, State#state.tiger_realm - 1]
                                            end,
                                        {ok, BinData} = pt_23:write(23006, [Aer#competitor.player_id, Aer#competitor.nickname, Der#competitor.player_id, Der#competitor.nickname, NewDragon, NewTiger, 0]),
                                        %% 广播比分
										lib_send:send_to_online_scene(State#state.battle_id, BinData),
                                        NewKill = Aer#competitor.kill + 1,
                                        NewAer = Aer#competitor{
                                            kill = NewKill					
                                        },
                                        lib_arena:broadcast_arena_msg(Aer#competitor.player_id, Aer#competitor.nickname, Aer#competitor.career, Aer#competitor.sex, Aer#competitor.realm, NewKill),
                                        AerMemberList = lists:keyreplace(AerId, 2, MemberList, NewAer),
                                        NDerDie = Der#competitor.die - 1,
										[NewDerDie, NewDragonNum, NewTigerNum] =                                             
                                            case NDerDie < 1 of
                                                true ->
                                                    [NDragonNum, NTigerNum] =
                                                        case Der#competitor.mark of
                                                            %% 天龙
                                                            8 ->
                                                                [State#state.dragon_num - 1, State#state.tiger_num];
                                                            %% 地虎
                                                            _ ->
                                                                [State#state.dragon_num, State#state.tiger_num - 1]
                                                        end,
                                                    [0, NDragonNum, NTigerNum];
                                                false ->
                                                    [NDerDie, State#state.dragon_num, State#state.tiger_num]
                                            end,
                                        NewDer = Der#competitor{
                                            die = NewDerDie,
											last_die_time = Now					
                                        },
                                        DerMemberList = lists:keyreplace(DerId, 2, AerMemberList, NewDer),
                                        case NewDragonNum < 1 orelse NewTigerNum < 1 orelse NewDragon < 1 orelse NewTiger < 1 of
                                            %% 战场结束
                                            true ->
                                                erlang:send_after(?END_DELAY_TIME, self(), 'END_ARENA');
                                            false ->
                                                skip
                                        end,
                                        State#state{
                                            dragon_realm = NewDragon,
                                            dragon_num = NewDragonNum,
                                            tiger_realm = NewTiger,
                                            tiger_num = NewTigerNum,
                                            member = DerMemberList			
                                        };
									false ->
										State
								end
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

%% 没进入战场
handle_cast({'NO_ENTER_ARENA', PlayerId}, State) ->
	NewState = 
		case State#state.is_end /= 1 of
			true ->
				no_enter_arena(State, PlayerId);
			false ->
				State
		end,
	{noreply, NewState};

%% 进入战场场景
handle_cast({'ENTER_ARENA_SCENE', PlayerId}, State) ->
	NewState = 
		case State#state.is_end /= 1 of
			true ->
				Member = State#state.member,
				case lists:keyfind(PlayerId, 2, Member) of
					false ->
						State;
					Competitor ->
						case Competitor#competitor.timer of
        					undefined -> 
								skip;
							_ ->	
            					erlang:cancel_timer(Competitor#competitor.timer)
						end,
						NewCompetitor = Competitor#competitor{
							timer = undefined								  
						},
						NewMember = lists:keyreplace(PlayerId, 2, Member, NewCompetitor),
						State#state{
							member = NewMember		
						}
				end;
			false ->
				State
		end,
	{noreply, NewState};

%% 退出战场
handle_cast({'LEAVE_ARENA', PlayerId}, State) ->
	spawn(fun()-> lib_arena:leave_arena(PlayerId, State#state.battle_id) end),
	NewState = 
		if
			State#state.is_end /= 1 ->
				MemberList = State#state.member,
                case lists:keyfind(PlayerId, 2, MemberList) of
                    false ->
                        State;
                    Competitor ->
                        [DieNum, DeadNum] =
							if
                      			Competitor#competitor.die > 0 ->
                                    [Competitor#competitor.die, 1];				
                                true ->
                                    [0, 0]                                            
                            end,
                        %% 比分
                        [NewDragon, NewTiger, NewDragonNum, NewTigerNum] = 
                            case Competitor#competitor.mark of
                                %% 天龙
                                8 ->
                                    [State#state.dragon_realm - DieNum, State#state.tiger_realm, State#state.dragon_num - DeadNum, State#state.tiger_num];
                                %% 地虎
                                _ ->
                                    [State#state.dragon_realm, State#state.tiger_realm - DieNum, State#state.dragon_num, State#state.tiger_num - DeadNum]
                            end,
                        {ok, BinData} = pt_23:write(23006, [0, [], 0, [], NewDragon, NewTiger, 0]),
                        %% 广播比分
						lib_send:send_to_online_scene(State#state.battle_id, BinData),
                        NewCompetitor = Competitor#competitor{
                            die = 0,
							sta = 1									  
                        },
                        NewMemberList = lists:keyreplace(PlayerId, 2, MemberList, NewCompetitor),
                        case NewDragon < 1 orelse NewTiger < 1 orelse NewDragonNum < 1 orelse NewTigerNum < 1 of
                            true ->
                                erlang:send_after(?END_DELAY_TIME, self(), 'END_ARENA');						
                            false ->
                                skip
                        end,
                        State#state{
                            dragon_realm = NewDragon,
                            dragon_num = NewDragonNum,
                            tiger_realm = NewTiger,
                            tiger_num = NewTigerNum,
                            member = NewMemberList                         
                        }
                end;
			true ->
				State
		end,
	{noreply, NewState};

%% 战场玩家意外退出处理
handle_cast({'PLAYER_TERMINATE_QUIT', PlayerId}, State) ->
	spawn(fun()-> lib_arena:leave_arena(PlayerId, State#state.battle_id) end),
	NewState = 
		if
			State#state.is_end =/= 1 ->
	       		player_terminate_quit(State, PlayerId);
			true ->
				State
		end,
	{noreply, NewState};

%% 战场正式开始
handle_cast('ARENA_START', State) ->
	NewState = 
		if
			State#state.is_end /= 1 ->
				if
					length(State#state.member) > 1 ->
						ArenaPid = self(),
						ArenaZone = State#state.level,
						ArenaSceneId = State#state.battle_id,
						arena_start(State#state.member, ArenaZone, ArenaSceneId, ArenaPid, State);
					true ->
						erlang:send_after(?END_DELAY_TIME, self(), 'END_ARENA'),
						State
				end;
			true ->
				State
		end,
	{noreply, NewState};

%% 获取竞技战斗中的排名列表
handle_cast({'GET_ARENA_MEMBER', PidSend}, State) ->
	spawn(fun()->
		ArenaInfo = get_arena_info(State#state.member, []),
		{ok, BinData} = pt_23:write(23005, [State#state.dragon_realm, State#state.tiger_realm, 0, ArenaInfo, State#state.zone]),
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

handle_info({'TERMINATE_TIMER', PlayerId}, State) ->
	MemberList = State#state.member,
	NewState = 
		case State#state.is_end /= 1 of
			true ->
				Res = 
					case lib_player:get_online_info_fields(PlayerId, [scene]) of
						[] ->
							1;
						[Scene] ->
							case lib_arena:is_arena_scene(Scene) of
								true ->
									0;
								false ->
									1
							end
					end,
				case Res == 1 of
					true ->						
                        case lists:keyfind(PlayerId, 2, MemberList) of
                            false ->
                                State;
                            Competitor ->
                           		[DieNum, DeadNum] =
                                    case Competitor#competitor.die > 0 of
                                        true ->
											[Competitor#competitor.die, 1];				
                                        false ->
											[0, 0]                                            
                                    end,
                                %% 比分
                                [NewDragon, NewTiger, NewDragonNum, NewTigerNum] = 
                                    case Competitor#competitor.mark of
                                        %% 天龙
                                        8 ->
                                            [State#state.dragon_realm - DieNum, State#state.tiger_realm, State#state.dragon_num - DeadNum, State#state.tiger_num];
                                        %% 地虎
                                        _ ->
                                            [State#state.dragon_realm, State#state.tiger_realm - DieNum, State#state.dragon_num, State#state.tiger_num - DeadNum]
                                    end,
								{ok, BinData} = pt_23:write(23006, [0, [], 0, [], NewDragon, NewTiger, 0]),
                                %% 广播比分
								lib_send:send_to_online_scene(State#state.battle_id, BinData),
                                NewCompetitor = Competitor#competitor{
                                    die = 0									  
                                },
                                NewMemberList = lists:keyreplace(PlayerId, 2, MemberList, NewCompetitor),
                                case NewDragon < 1 orelse NewTiger < 1 orelse NewDragonNum < 1 orelse NewTigerNum < 1 of
                                    true ->
                                        erlang:send_after(?END_DELAY_TIME, self(), 'END_ARENA');						
                                    false ->
                                        skip
                                end,
                                State#state{
                                    dragon_realm = NewDragon,
                                    dragon_num = NewDragonNum,
                                    tiger_realm = NewTiger,
                                    tiger_num = NewTigerNum,
                                    member = NewMemberList                         
                                }
                        end;
					false ->
						State
				end;
			false ->
				State
		end,
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
init_arena_member_data(MemberList, ArenaDieNum) ->
	%% 按攻击系数由高到低排
	SortFun = fun({_, _, _, _, _, A1, _}, {_, _, _, _, _, A2, _}) ->
		A1 > A2 
	end,	
	NewMemberList = lists:sort(SortFun, MemberList),
	Half = util:floor(length(MemberList) / 2),
	init_arena_member_data_loop(NewMemberList, Half, ArenaDieNum, 0, 0, [], 0, 0).
init_arena_member_data_loop([], _Half, _ArenaDieNum, _L1, _L2, Group, DragonNum, TigerNum) ->
	[Group, DragonNum, TigerNum];
init_arena_member_data_loop([{PlayerId, NickName, Realm, Career, Lv, Att, Sex} | M], Half, ArenaDieNum, L1, L2, Group, DragonNum, TigerNum) ->
	[NewL1, NewL2, Mark, NewDragonNum, NewTigerNum] =
        if
            DragonNum < Half andalso L1 < L2 ->
                [L1 + Att, L2, 8, DragonNum + 1, TigerNum];
            TigerNum < Half andalso L2 < L1 ->
                [L1, L2 + Att, 9, DragonNum, TigerNum + 1];
            DragonNum >= Half -> 
                [L1, L2 + Att, 9, DragonNum, TigerNum + 1];
            TigerNum >= Half ->
                [L1 + Att, L2, 8, DragonNum + 1, TigerNum];
            L1 < L2 ->
                [L1 + Att, L2, 8, DragonNum + 1, TigerNum];
            L2 < L1 ->
                [L1, L2 + Att, 9, DragonNum, TigerNum + 1];
            true ->
                [L1 + Att, L2, 8, DragonNum + 1, TigerNum]
        end,
	Competitor = #competitor{
		player_id = PlayerId,					
		nickname = NickName,							
    	realm = Realm,							
    	career = Career,   				
    	lv = Lv, 	
    	mark = Mark,    				
		die = ArenaDieNum,
		sex = Sex,
		att = Att			 
	},
	init_arena_member_data_loop(M, Half, ArenaDieNum, NewL1, NewL2, [Competitor | Group], NewDragonNum, NewTigerNum).

get_arena_info([], RetList) ->
	RetList;
get_arena_info([A | M], RetList) ->	
	get_arena_info(M, [{A#competitor.player_id, A#competitor.nickname, A#competitor.career, A#competitor.kill, A#competitor.mark} | RetList]).


%% 战场正式开始
arena_start([], _ArenaZone, _ArenaSceneId, _ArenaPid, RetState) ->
	RetState;
arena_start([A | M], ArenaZone, ArenaSceneId, ArenaPid, State) ->
	NewState = 
		case lib_player:get_player_pid(A#competitor.player_id) of
			[] ->
				no_enter_arena(State, A#competitor.player_id);
			Pid ->
				gen_server:cast(Pid, {'ARENA_START', 1, ArenaZone, ArenaSceneId, ArenaPid}),
				State
		end,
	arena_start(M, ArenaZone, ArenaSceneId, ArenaPid, NewState).

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
		kill = Kill,
		sex = Sex	
	} = A,
	[Win, Score] =
		if
			WinSide == Mark ->
				[1, 35];
			true ->
				[0, 25]
		end,
	NewScore = util:ceil(Score + 0.4 * Kill),
	NewRet = [[NickName, Realm, Career, Lv, Mark - 7, Kill, NewScore] | Ret],
	NewList = [{PlayerId, NickName, Realm, Career, Lv, A#competitor.att, Sex, Win, Kill} | List],
	NewWeek = [{PlayerId, NickName, Realm, Career, Lv, Area, Mark - 7, Win + 1, NewScore, Now, Kill} | Week],
	NewScoreList = [{PlayerId, NickName, Career, Sex, NewScore} | ScoreList],
	arena_rank(M, WinSide, Area, Now, NewRet, NewList, NewWeek, NewScoreList).


%% 8天龙，9地虎
get_win_side(State) ->
	[DragonNum, TigerNum, DragonAlive, TigerAlive, DragonLv, TigerLv] = 
					get_win_side_loop(State#state.member, 0, 0, 0, 0, 0, 0),
	case DragonAlive < 1 of
		true ->
			9;
		false ->
			case TigerAlive < 1 of
				true ->
					8;
				false ->
                    if
                        State#state.dragon_realm > State#state.tiger_realm ->
                            8;
                        State#state.dragon_realm < State#state.tiger_realm ->
                            9;
                        true ->
                            if
                                DragonNum < TigerNum andalso DragonNum > 0 andalso TigerNum > 0 ->
                                    8;
                                DragonNum > TigerNum andalso DragonNum > 0 andalso TigerNum > 0 ->
                                    9;
                                true ->
                                    %% 存活人数
                                    if
                                        DragonAlive > TigerAlive ->
                                            8;
                                        DragonAlive < TigerAlive ->
                                            9;
                                        true ->
                                            %% 总等级
                                            if
                                                DragonLv < TigerLv ->
                                                    8;
                                                DragonLv > TigerLv ->
                                                    9;
                                                true ->
                                                    case random:uniform(100) > 50 of
                                                        true ->
                                                            8;
                                                        false ->
                                                            9
                                                    end
                                            end
                                    end
                            end
                    end
			end
	end.	

get_win_side_loop([], DragonNum, TigerNum, DragonAlive, TigerAlive, DragonLv, TigerLv) ->
	[DragonNum, TigerNum, DragonAlive, TigerAlive, DragonLv, TigerLv];
get_win_side_loop([A | M], DragonNum, TigerNum, DragonAlive, TigerAlive, DragonLv, TigerLv) ->
	Alive = 
		case A#competitor.die > 0 of
			true ->
				1;
			false ->
				0
		end,
	[NewDragonNum, NewTigerNum, NewDragonAlive, NewTigerAlive, NewDragonLv, NewTigerLv] =
		case A#competitor.mark of
			8 ->				
				[DragonNum + 1, TigerNum, DragonAlive + Alive, TigerAlive, DragonLv + A#competitor.lv, TigerLv];
			9 ->
				[DragonNum, TigerNum + 1, DragonAlive, TigerAlive + Alive, DragonLv, TigerLv + A#competitor.lv]
		end,
	get_win_side_loop(M, NewDragonNum, NewTigerNum, NewDragonAlive, NewTigerAlive, NewDragonLv, NewTigerLv).

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

no_enter_arena(State, PlayerId) ->
	Member = State#state.member,
    case lists:keyfind(PlayerId, 2, Member) of
        false ->
            State;
        Competitor ->
            case Competitor#competitor.timer of
                undefined -> 
                    skip;
                _ ->	
                    erlang:cancel_timer(Competitor#competitor.timer)
            end,
            Timer = erlang:send_after(?QUIT_DELAY_TIME * 1000, self(), {'TERMINATE_TIMER', PlayerId}),
            NewCompetitor = Competitor#competitor{
                timer = Timer								  
            },
            NewMember = lists:keyreplace(PlayerId, 2, Member, NewCompetitor),
            State#state{
                member = NewMember		
            }
    end.

%% 玩家意外退出战场
player_terminate_quit(State, PlayerId) ->
	MemberList = State#state.member,
    case lists:keyfind(PlayerId, 2, MemberList) of
        false ->
            State;
        Competitor ->
            case Competitor#competitor.die > 0 of
                true ->
                    DieNum =
                        case Competitor#competitor.die > ?DIE_NUM of
                            true ->
                                ?DIE_NUM;
                            false ->
                                Competitor#competitor.die
                        end,
                    %% 比分
                    [NewDragon, NewTiger] = 
                        case Competitor#competitor.mark of
                            %% 天龙
                            8 ->
                                [State#state.dragon_realm - DieNum, State#state.tiger_realm];
                            %% 地虎
                            _ ->
                                [State#state.dragon_realm, State#state.tiger_realm - DieNum]
                        end,
                    case NewDragon < 1 orelse NewTiger < 1 of
                        true ->
                            erlang:send_after(?END_DELAY_TIME, self(), 'END_ARENA'),
                            NewCompetitor = Competitor#competitor{
                                die = 0									  
                            },
                            NewMemberList = lists:keyreplace(PlayerId, 2, MemberList, NewCompetitor),
                            State#state{
                                dragon_realm = NewDragon,
                                tiger_realm = NewTiger,
                                member = NewMemberList
                            };
                        false ->
                            [NewDie, NewDragonNum, NewTigerNum, IsTimer] = 
                                case Competitor#competitor.die > 0 of
                                    true ->
                                        NDerDie = Competitor#competitor.die - DieNum,
                                        case NDerDie < 1 of
                                            true ->
                                                case Competitor#competitor.mark of
                                                    %% 天龙
                                                    8 ->
                                                        [0, State#state.dragon_num - 1, State#state.tiger_num, 0];
                                                    %% 地虎
                                                    _ ->
                                                        [0, State#state.dragon_num, State#state.tiger_num - 1, 0]
                                                end;
                                            false ->
                                                [NDerDie, State#state.dragon_num, State#state.tiger_num, 1]
                                        end;
                                    false ->					
                                        [0, State#state.dragon_num, State#state.tiger_num, 0]
                                end,                        
                            Timer = 
                                case NewDragonNum < 1 orelse NewTigerNum < 1 of
                                    true ->
                                        erlang:send_after(?END_DELAY_TIME, self(), 'END_ARENA'),
                                        undefined;
                                    false ->	
                                        {ok, BinData} = pt_23:write(23006, [0, [], 0, [], NewDragon, NewTiger, 0]),
                                        %% 广播比分
										lib_send:send_to_online_scene(State#state.battle_id, BinData),
                                        TodaySec = util:get_today_current_second(),
                                        Seconds = TodaySec + ?QUIT_DELAY_TIME,
										ArenaEndTime = lib_arena:get_arena_end_time(),
                                        case IsTimer == 1 andalso ArenaEndTime > Seconds of
                                            true ->
                                                case Competitor#competitor.timer of
                                                    undefined -> 
                                                        skip;
                                                    _ ->	
                                                        erlang:cancel_timer(Competitor#competitor.timer)
                                                end,
                                                erlang:send_after(?QUIT_DELAY_TIME * 1000, self(), {'TERMINATE_TIMER', PlayerId});											
                                            false ->
                                                undefined
                                        end
                                end,
                            NewCompetitor = Competitor#competitor{
                                die = NewDie,
                                timer = Timer									  
                            },
                            NewMemberList = lists:keyreplace(PlayerId, 2, MemberList, NewCompetitor),
                            State#state{
                                dragon_realm = NewDragon,
                                dragon_num = NewDragonNum,
                                tiger_realm = NewTiger,
                                tiger_num = NewTigerNum,
                                member = NewMemberList			
                            }
                    end;
                false ->
                    State
            end
    end.

%% 通知进入战场
notice_enter_arena(State, ArenaPid) ->
	ArenaZone = State#state.level,
	ArenaSceneId = State#state.battle_id,
	Fun = fun(A) ->
		case lib_player:get_player_pid(A#competitor.player_id) of
			[] ->
				no_pid;
			Pid ->
				gen_server:cast(Pid, {'NOTICE_ENTER_ARENA', A#competitor.mark, ArenaZone, ArenaSceneId, ArenaPid})	
		end	  
	end,
	[Fun(M) || M <- State#state.member].
	
	

