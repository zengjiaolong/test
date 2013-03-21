%%%--------------------------------------
%%% @Module  : lib_arena
%%% @Author  : ygfs
%%% @Created : 2011.02.15
%%% @Description: 战场处理 
%%%--------------------------------------
-module(lib_arena).

-export(
    [
		enter_arena/3,
		enter_arena_scene/5,
		is_arena_scene/1,
		is_new_arena_scene/1,
		is_arena_time/0,
		replace_ets_arena/1,
		player_login_check/1,
		init_arena_data/0,
		replace_ets_arena_week/1,
		get_pre_week_starttime/0,
		get_pre_week_endtime/0,
		rank_arena/0,
		rank_arena_week/0,
		rank_arena_pre_week/0,
		rank_area_pre_week_firth/0,
		rank_arena_week/2	,
		rank_pre_arena_week/4,
		rank_arena_query/4,
		broadcast_arena_msg/6,
		broadcast_new_arena_msg/6,		
		get_hour_time/0,
		filter_data_bytime/3,
		get_arena_level_name/1,
		get_arena_side_name/1,
		check_arena_status/2,
		leave_arena/1,
		leave_arena/2,
		update_arena_angry/2,
		arena_angry_battle/4,
		init_arena_info/3,
		arena_start/1,
		arena_terminate_quit/1,
		get_arena_position/1,
		get_arena_king/0,
		get_arena_rank_king/0,
		change_player_name/2,
		rank_total_pre_arena/1,
		rank_total_arena_query/1,
		rank_current_arena_week/0,
		get_arena_die_num/0,
		get_arena_join_time/0,
		arena_join/1,
		start_arena_timer/2,
		get_arena_join_end_time/0,
		is_arena_ready_time/1,
		get_arena_start_time/0,
		get_arena_end_time/0,
		get_arena_join_list/0,
		notice_enter_arena/3,
		get_new_arena_position/1,
		check_enter_arena_condition/1,
		arena_die/4,
		arena_award_member/3,
		get_arena_award/1,
		get_arena_start_position/1,
		get_arena_pid/1
    ]
).

-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

-define(ARENA_JOIN_TIME, 68700).										%% 战场报名时间
-define(ARENA_JOIN_END_TIME, 69900).									%% 战场报名结束时间
-define(ARENA_START_TIME, 70200).										%% 战场开始时间
-define(ARENA_END_TIME, 72000).											%% 战场结束时间
-define(ARENA_END_CHECK, 72060).										%% 战场结束一分钟后的检

%% -define(ARENA_JOIN_TIME, 23 * 3600 + 7 * 60).										%% 战场报名时间
%% -define(ARENA_JOIN_END_TIME, ?ARENA_JOIN_TIME + 100).								%% 战场报名结束时间
%% -define(ARENA_START_TIME, ?ARENA_JOIN_END_TIME + 10).								%% 战场开始时间
%% -define(ARENA_END_TIME, ?ARENA_START_TIME + 120).									%% 战场结束时间
%% -define(ARENA_END_CHECK, ?ARENA_END_TIME + 10).										%% 战场结束一分钟后的检

-define(ARENA_DIE_NUM, 15).												%% 战场死亡次数


%% 播放战场信息
broadcast_arena_msg(PlayerId, NickName, Career, Sex, Realm, Kill) ->
	if
		Kill > 9 ->
			case Kill of
				10 ->
					arena_msg_broadcast(PlayerId, NickName, Career, Sex, Realm, NickName, Kill, "正在大杀特杀");
                15 ->
					arena_msg_broadcast(PlayerId, NickName, Career, Sex, Realm, NickName, Kill, "已经主宰比赛了");
				20 ->
					arena_msg_broadcast(PlayerId, NickName, Career, Sex, Realm, NickName, Kill, "已经杀人如麻");
				25 ->
					arena_msg_broadcast(PlayerId, NickName, Career, Sex, Realm, NickName, Kill, "已经无人能挡");
				30 ->
					arena_msg_broadcast(PlayerId, NickName, Career, Sex, Realm, NickName, Kill, "都杀的变态了");
				40 ->
					arena_msg_broadcast(PlayerId, NickName, Career, Sex, Realm, NickName, Kill, "真的跟妖怪一样");
				50 ->
					arena_msg_broadcast(PlayerId, NickName, Career, Sex, Realm, NickName, Kill, "已经成神了");
				60 ->
					arena_msg_broadcast(PlayerId, NickName, Career, Sex, Realm, NickName, Kill, "已经超越神了。。。拜托谁杀了他吧");
				_ ->
					if
						Kill > 60 andalso Kill rem 2 == 0 ->
							arena_msg_broadcast(PlayerId, NickName, Career, Sex, Realm, NickName, Kill, "已经超越神了。。。拜托谁杀了他吧");
						true ->
							[]
					end
			end;
		true ->
			skip
	end.
%% 播放战场信息
broadcast_new_arena_msg(PlayerId, NickName, Career, Sex, Realm, Kill) ->
	if
		Kill > 9 ->
			case Kill of
				10 ->
					arena_msg_broadcast(PlayerId, NickName, Career, Sex, Realm, NickName, Kill, "正在大杀特杀");
                15 ->
					arena_msg_broadcast(PlayerId, NickName, Career, Sex, Realm, NickName, Kill, "已经主宰比赛了");
				20 ->
					arena_msg_broadcast(PlayerId, NickName, Career, Sex, Realm, NickName, Kill, "已经杀人如麻");
				25 ->
					arena_msg_broadcast(PlayerId, NickName, Career, Sex, Realm, NickName, Kill, "已经无人能挡");
				30 ->
					arena_msg_broadcast(PlayerId, NickName, Career, Sex, Realm, NickName, Kill, "都杀的变态了");
				35 ->
					arena_msg_broadcast(PlayerId, NickName, Career, Sex, Realm, NickName, Kill, "真的跟妖怪一样");
				40 ->
					arena_msg_broadcast(PlayerId, NickName, Career, Sex, Realm, NickName, Kill, "已经成神了");
				45 ->
					arena_msg_broadcast(PlayerId, NickName, Career, Sex, Realm, NickName, Kill, "已经超越神了。。。拜托谁杀了他吧");
				_ ->
					if
						Kill > 45 andalso Kill rem 2 == 0 ->
							arena_msg_broadcast(PlayerId, NickName, Career, Sex, Realm, NickName, Kill, "已经超越神了。。。拜托谁杀了他吧");
						true ->
							[]
					end
			end;
		true ->
			skip
	end.
%% 播放战场信息
arena_msg_broadcast(PlayerId, NickName, Career, Sex, Realm, NickName, Kill, Msg) ->
	NameColor = data_agent:get_realm_color(Realm),
	NewMsg = io_lib:format("<a href='event:1, ~p, ~s, ~p, ~p'><font color='~s'>[~s]</font></a> 已经击杀了 <font color='#FEDB4F;'>~p</font> 人， ~s！", [PlayerId, NickName, Career, Sex, NameColor, NickName, Kill, Msg]),
	lib_chat:broadcast_sys_msg(2, NewMsg).	

%% 进入战场（进入前判断，放这里同一管理战场常量）
enter_arena(PlayerState, Player, SceneId) ->
	TodaySec = util:get_today_current_second(),
	%% 检查是否是进入时间
	case is_arena_enter_time(SceneId, TodaySec) of
		true ->
			ArenaScenePid = mod_scene:get_scene_real_pid(SceneId),
			case catch gen_server:call(ArenaScenePid, {'CHECK_JOIN_ARENA', Player#player.id}) of
                [1, _Bid, ArenaMark, ReviveNum] ->
                    [RetReviveNum, ArenaSta] =
						if
                      		TodaySec > ?ARENA_START_TIME ->
								if
                              		ReviveNum > 1 ->
                                        [ReviveNum - 1, 1];
                                    true ->
                                        [0, 3]
                                end;
                            true ->
                                [?ARENA_DIE_NUM - 1, 1]
                        end,
					NewPlayerState = PlayerState#player_state{
               			arena_mark = ArenaMark
              		},
                    enter_arena_scene(NewPlayerState, SceneId, RetReviveNum, ArenaSta, 2);
                
                %% 已经退出了战场
				2 ->
                    {ok, BinData} = pt_23:write(23004, 3),
                    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
                _ ->
                    {ok, BinData} = pt_23:write(23004, 0),
                    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
            end;       
        false ->
            {ok, BinData} = pt_23:write(23004, 1),
            lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)	
    end.


%% 进入战场
enter_arena_scene(PlayerState, SceneId, ReviveNum, ArenaSta, Type) ->
	Player = PlayerState#player_state.player,
	ArenaMark = PlayerState#player_state.arena_mark,
	TodaySec = util:get_today_current_second(),
	{SceneResId, NewArenaSta} = 
        case is_new_arena_scene(SceneId) of
            %% 旧战场场景
            false ->
                [X, Y] =
                    if
                        (TodaySec + 1) >= ?ARENA_START_TIME ->
                            Time = ?ARENA_END_TIME - TodaySec,
							Sta = 4,
							BattleLimit = 0,
							%% 进入战场时开始的坐标
							get_arena_start_position(ArenaMark);
                        true ->
                            Time = ?ARENA_START_TIME - TodaySec,	
							Sta = 2,
							BattleLimit = 9,
							%% 进入战场的坐标
							get_arena_enter_position(ArenaMark)
                    end,
                gen_server:cast(Player#player.other#player_other.pid_dungeon, {'ENTER_ARENA_SCENE', Player#player.id}),
                NewReviveNum =
                    if
                      	ArenaSta =/= 3 ->
                            ReviveNum;
                        true ->	
                            Type - 4
                    end,
                {ok, ReviveNumBinData} = pt_23:write(23009, NewReviveNum),
                lib_send:send_to_sid(Player#player.other#player_other.pid_send, ReviveNumBinData),
                {?ARENA_RES_SCENE_ID, ArenaSta};
            true ->
				Time = ?ARENA_END_TIME - TodaySec,
				Sta = 4,
				BattleLimit = 0,
				{X, Y} = get_new_arena_position(ArenaMark),
                {?NEW_ARENA_RES_SCENE_ID, 1}
        end,
	%% 进入战场卸下坐骑
	{ok, MountPlayer} = lib_goods:force_off_mount(Player),
	
	%% 坐标记录
	put(change_scene_xy, [X, Y]),
	{ok, BinData} = pt_12:write(12005, [SceneId, X, Y, <<>>, SceneResId, 0, 0, ArenaMark]),
   	lib_send:send_to_sid(MountPlayer#player.other#player_other.pid_send, BinData),	
	%% 战场状态信息
	{ok, TimeBinData} = pt_23:write(23001, [Time, Sta]),
	lib_send:send_to_sid(MountPlayer#player.other#player_other.pid_send, TimeBinData),
  	%% 告诉原来场景玩家你已经离开
	pp_scene:handle(12004, MountPlayer, Player#player.scene),	
	%%挂机区进入战场
	lib_scene:set_hooking_state(Player,SceneId),
  	NewPlayer = MountPlayer#player{
		scene = SceneId, 
		x = X, 
		y = Y,
		arena = NewArenaSta,
		other = MountPlayer#player.other#player_other{
			leader = PlayerState#player_state.arena_mark,
    		battle_limit = BattleLimit																				  
      	} 
	},
	%% 战场怒气
	put(arena_angry, 0),
	{ok, AngryBinData} = pt_23:write(23022, 0),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, AngryBinData),
	%% 更新玩家进入战场时间
	spawn(fun()-> db_agent:update_arena_enter_time(Player#player.id) end),
	List = [
		{scene, NewPlayer#player.scene},
		{x, NewPlayer#player.x},
		{y, NewPlayer#player.y},
		{mount, NewPlayer#player.mount},
		{speed, NewPlayer#player.speed},
		{arena, NewPlayer#player.arena},
		{leader, NewPlayer#player.other#player_other.leader},
		{battle_limit, NewPlayer#player.other#player_other.battle_limit},
		{equip_current, NewPlayer#player.other#player_other.equip_current},
		{mount_stren, NewPlayer#player.other#player_other.mount_stren}
	],
	mod_player:save_online_info_fields(NewPlayer, List),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer,
		arena_revive = ReviveNum		   
	},
	{ok, change_player_state, NewPlayerState}.

%% 新战场的出生坐标
get_new_arena_position(ArenaMark) ->
	case ArenaMark of
  		8 ->
     		{12, 52};
     	9 ->
      		{33, 108};
   		_ ->
      		{63, 41}
	end.

%% 是否战场场景
is_arena_scene(SceneId) ->
	SceneId >= 600 andalso SceneId < 700.

%% 是否新战场场景
is_new_arena_scene(SceneId) ->
	SceneId >= 650 andalso SceneId < 700.

%% 是否是竞技时间
is_arena_time() ->
	%% 获取今天凌晨到现在的秒数
 	TodaySec = util:get_today_current_second(),
 	TodaySec >= ?ARENA_JOIN_TIME andalso TodaySec < ?ARENA_END_TIME.

%% 战场退出位置数据获取
get_arena_position(_Realm) ->
	[300, 75, 209].

%% 进入战场的坐标
get_arena_enter_position(ArenaMark) ->
	case ArenaMark of
        8 ->
            [15, 98];
        _ ->
            [63, 16]
    end.

%% 进入战场时开始的坐标
get_arena_start_position(ArenaMark) ->
	case ArenaMark of
        8 ->
            [31, 82];
        _ ->
            [47, 32]
    end.

%% 玩家登陆战场状态判断
player_login_check(Player) ->
    NewPlayer = 
        case is_arena_scene(Player#player.scene) of
            true ->
                [ArenaScene, ArenaX, ArenaY] = get_arena_position(Player#player.realm),
                Player#player{
                    scene = ArenaScene,
                    x = ArenaX,
                    y = ArenaY
                };
            false ->
                Player
        end,
	if
		NewPlayer#player.arena > 0 ->
            case is_arena_time() of
                true ->
              		NewPlayer;
                false ->
					spawn(fun()-> db_agent:update_arena_status(NewPlayer#player.id, 0) end),
                    NewPlayer#player{
                        arena = 0
                    }
            end;
        true ->
			NewPlayer
	end.


%% 战场状态检查
check_arena_status(Player, PlayerState) ->
	Ret =
        case db_agent:get_arena_data_by_id(Player#player.id, "pid, jtime") of
            [] ->
				spawn(fun()-> init_arena_info(Player, util:term_to_string([0, 0]), 0) end),
                0;
            [ArenaInfo, JoinTime] ->
                Now = util:unixtime(),
                case util:is_same_date(JoinTime, Now) of
                    true ->
						{TodayMidNightSecond, _YestodayMidNightSecond} = util:get_midnight_seconds(Now),
                        %% 报名结束时间
						ArenaJoinEndTime = TodayMidNightSecond + ?ARENA_JOIN_END_TIME,
                        ArenaEndTime = TodayMidNightSecond + ?ARENA_END_TIME,
                        if
                            Player#player.arena == 2 andalso Now < ArenaJoinEndTime ->
                                {ok, TimeBinData} = pt_23:write(23001, [ArenaJoinEndTime - Now, 1]),
                                lib_send:send_to_sid(Player#player.other#player_other.pid_send, TimeBinData),
                                [Player, PlayerState];
                            Now >= ArenaJoinEndTime andalso Now < ArenaEndTime ->
                             	case util:string_to_term(tool:to_list(ArenaInfo)) of
                            		[_Zone, ArenaSceneId] ->
                                        ArenaPid = mod_scene:get_scene_real_pid(ArenaSceneId),
                                        case catch gen_server:call(ArenaPid, {'CHECK_JOIN_ARENA', Player#player.id}) of
                                            [1, Bid, ArenaMark, ReviveNum] ->
                                                NewReviveNum =
                                                    if
                                                        ReviveNum > 1 ->
                                                            ReviveNum - 1;
                                                        true ->
                                                            0
                                                    end,
                                                put(arena_battle_id, Bid),
												%% 是否在新战场
												case is_new_arena_scene(ArenaSceneId) of
													true ->
														%% 战场状态信息
														TodaySec = util:get_today_current_second(),
														if
															TodaySec < ?ARENA_START_TIME ->
																{ok, TimeBinData} = pt_23:write(23001, [?ARENA_START_TIME - TodaySec, 2]),
																lib_send:send_to_sid(Player#player.other#player_other.pid_send, TimeBinData);	
															true ->
																{ok, BinData} = pt_23:write(23001, [ArenaEndTime - Now, 3]),
                                                				lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)	
														end;
													false ->
                                                		{ok, BinData} = pt_23:write(23001, [ArenaEndTime - Now, 3]),
                                                		lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
                                                end,
												NewPlayer = Player#player{
                                                    other = Player#player.other#player_other{
                                                        pid_dungeon = ArenaPid
                                                    }                                               						  
                                                },
												NewPlayerState = PlayerState#player_state{
                                                    arena_revive = NewReviveNum,
                                                    arena_mark = ArenaMark										  
                                                },
                                                [NewPlayer, NewPlayerState];
                                            _ ->
                                                0
                                        end;	
                                 	_ ->
                              			0
                              	end;     
                            true ->
                                0
                        end;
                    false ->
                        0
                end
        end,
	if
		Ret == 0 ->
			spawn(fun()-> db_agent:update_arena_status(Player#player.id, 0) end),
			RetPlayer = Player#player{
				arena = 0			   
			},
			[RetPlayer, PlayerState];
		true ->
			Ret
	end.


%% 更新ets_arena
replace_ets_arena({PlayerId, Nickname, Realm, Career, Lv, Att, Sex, Win, Score}) ->
    ArenaRecord =    
		case ets:lookup(?ETS_ARENA, PlayerId) of
            %% 总排行中没有角色的数据
            [] ->
				spawn(fun()->
					db_agent:delete_arena(PlayerId),
					ArenaData = [PlayerId, Nickname, Realm, Career, Lv, Att, Sex, Win, Score, util:term_to_string([0, 0]), 0],                
                	db_agent:insert_arena(ArenaData)
				end),
              	#ets_arena{
                    player_id = PlayerId, 
                    nickname = Nickname,
                    realm = Realm, 
                    career = Career,
                    lv = Lv,
                    wins = Win, 
                    score = Score
           		};
            [Arena | _] ->
                NewWin = Arena#ets_arena.wins + Win,
                NewScore = Arena#ets_arena.score + Score,
				spawn(fun()-> db_agent:update_arena(PlayerId, Lv, NewWin, NewScore) end),
              	Arena#ets_arena{
                    player_id = PlayerId,
					lv = Lv, 
                    wins = NewWin,
                    score = NewScore
                }              
        end,
	ets:insert(?ETS_ARENA, ArenaRecord).

%% 更新ets_ets_arena_week
replace_ets_arena_week({PlayerId, Nickname, Realm, Career, Lv, Area, Camp, Type, Score, Ctime, Killer}) ->
	%% 先删除一周以前的数据
	delete_arena_week(),	
	{mongo, Id} = db_agent:insert_arena_week([PlayerId, Nickname, Realm, Career, Lv, Area, Camp, Type, Score, Ctime ,Killer]),
	ArenaWeekRecord = #ets_arena_week{
      	id = Id,
      	player_id = PlayerId, 
      	nickname = Nickname,
      	realm = Realm, 
      	career = Career,
      	lv = Lv,
      	area = Area,
      	camp = Camp,
      	type = Type,
      	score = Score,
      	ctime = Ctime,
		killer = Killer
   	},
	ets:insert(?ETS_ARENA_WEEK, ArenaWeekRecord).


%% 初始化战场数据
init_arena_data() ->
	ArenaList = db_agent:load_arena_data(),
	ArenaWeekList = db_agent:load_arena_week_data(),
	lists:map(fun load_arena_data_into_ets/1, ArenaList),
	lists:map(fun load_arena_week_data_into_ets/1, ArenaWeekList),
	ok.

%%加载战场总排行
load_arena_data_into_ets([Id, Player_Id, Nickname, Realm, Career, Lv, Wins, Score]) ->
    ArenaRecordEts = #ets_arena{
        id = Id, 
        player_id = Player_Id, 
        nickname = Nickname, 
        realm = Realm, 
        career = Career, 
        lv = Lv, 
        wins = Wins, 
        score = Score
    },
	ets:insert(?ETS_ARENA, ArenaRecordEts).

%%加载战场周排行
load_arena_week_data_into_ets([Id, Player_Id, Nickname, Realm, Career, Lv, Area, Camp, Type, Score, Ctime, Killer]) ->
	ArenaWeekRecordEts = #ets_arena_week{
		id = Id,
        player_id = Player_Id, 
        nickname = Nickname,
        realm = Realm, 
        career = Career,
        lv = Lv,
        area = Area,
        camp = Camp,
        type = Type,
        score = Score,
        ctime = Ctime,
        killer = Killer									
	},
	ets:insert(?ETS_ARENA_WEEK, ArenaWeekRecordEts).


%%删除上周之前的数据,只保留一周数据
delete_arena_week() ->
	DefineTime = get_pre_week_starttime(),
	ArenaWeekData = db_agent:get_arena_week(DefineTime),
	F = fun([Id | _]) ->
		ets:delete(?ETS_ARENA_WEEK, Id)
	end,
	[F(Arena_week)|| Arena_week <- ArenaWeekData],
	db_agent:delete_arena_week(DefineTime),
	ok.
	
%%上周的开始时间和结束时间,返回上周一,0点0分0秒的时间
get_pre_week_starttime() ->
	OrealTime =  calendar:datetime_to_gregorian_seconds({{1970,1,1}, {0,0,0}}),
	{Year,Month,Day} = date(),
	CurrentTime = calendar:datetime_to_gregorian_seconds({{Year,Month,Day}, {0,0,0}})-OrealTime-8*60*60,%%从1970开始时间值
	WeekDay = calendar:day_of_the_week(Year,Month,Day),
	Day1 = 
	case WeekDay of %%上周的时间
		1 -> 7;
		2 -> 7+1;
		3 -> 7+2;
		4 -> 7+3;
		5 -> 7+4;
		6 -> 7+5;
		7 -> 7+6
	end,
	CurrentTime - Day1*24*60*60.

%%上周的开始时间和结束时间,返回本周一,0点0分0秒的时间
get_pre_week_endtime() ->
	OrealTime =  calendar:datetime_to_gregorian_seconds({{1970,1,1}, {0,0,0}}),
	{Year,Month,Day} = date(),
	CurrentTime = calendar:datetime_to_gregorian_seconds({{Year,Month,Day}, {0,0,0}})-OrealTime-8*60*60,%%从1970开始时间值
	WeekDay = calendar:day_of_the_week(Year,Month,Day),
	Day1 = 
	case WeekDay of %%上周的时间
		1 -> 0;
		2 -> 1;
		3 -> 2;
		4 -> 3;
		5 -> 4;
		6 -> 5;
		7 -> 6
	end,
	CurrentTime - Day1*24*60*60.

%% 查询战场总排行
rank_arena() ->
	MS = ets:fun2ms(fun(A) ->
		[
		 	A#ets_arena.player_id,
			A#ets_arena.nickname, 
			A#ets_arena.realm, 
			A#ets_arena.career, 
			A#ets_arena.lv, 
			A#ets_arena.score		 
		]
	end),
	Data = ets:select(?ETS_ARENA, MS),
	SortFun = fun([_, _, _, _, Lv1, Win1], [_, _, _, _, Lv2, Win2]) -> 
		if 
			Win1 =/= Win2 ->
				Win1 > Win2;
			true ->
				Lv1 > Lv2
		end
	end,
	NewData = lists:sort(SortFun, Data),
	add_order([], NewData, 1).	

%%查询战场本周排行
rank_arena_week() ->
	rank_arena_week(get_pre_week_endtime(),util:unixtime()).

%%查询本周一到现在的周排行
rank_current_arena_week() ->
	NowTime = util:unixtime(),
	List = rank_arena_week(NowTime-14*24*3600,NowTime),
	lists:sublist(List, 50).

%%查询战场上周排行
rank_arena_pre_week() ->
	rank_arena_week(get_pre_week_starttime(),get_pre_week_endtime()).

%%查询战场上周战神
rank_area_pre_week_firth() ->
	ArenaWeekList = rank_arena_pre_week(),
	case ArenaWeekList of
		[] -> <<>>;
		_ ->
			[_Order, _Player_Id, Nickname, _Realm, _Career, _Lv, _Wins] = lists:nth(1,ArenaWeekList),
			Nickname
	end.

%%查询时间段内的排名情况
rank_arena_week(Time1,Time2) ->
	AreanWeekData = ets:match(?ETS_ARENA_WEEK, _ = '$1'),
	ArenaWeekData1 = [[Player_Id] || [{ets_arena_week,_Id, Player_Id, _Nickname, _Realm, _Career, _Lv, _Area, _Camp, _Type, _Score, Ctime, _Killer}] <- AreanWeekData,Ctime > Time1,Ctime < Time2],
	AreanWeekList1 = lists:usort(lists:flatten(ArenaWeekData1)),%%[player_id1,player_id2],
	F = fun(Player_Id) ->
				ArenaWeeks = ets:match_object(?ETS_ARENA_WEEK, #ets_arena_week{player_id=Player_Id, _='_'}),
				ArenaWeekData2 = [[Id1, Player_Id1, Nickname1, Realm1, Career1, Lv1, Area1, Camp1, Type1, Score1, Ctime1, Killer1] || {ets_arena_week,Id1, Player_Id1, Nickname1, Realm1, Career1, Lv1, Area1, Camp1, Type1, Score1, Ctime1, Killer1} <- ArenaWeeks,Ctime1 > Time1,Ctime1 < Time2],
				[_Id0, Player_Id0, Nickname0, Realm0, Career0, Lv0, _Area0, _Camp0, _Type0, _Score0, _Ctime0, _Killer0] = lists:nth(1,ArenaWeekData2),
				KillList = [Killer3 || [_Id2, _Player_Id2, _Nickname2, _Realm2, _Career2, _Lv2, _Area2, _Camp2, _Type2, _Score2, _Ctime2, Killer3] <- ArenaWeekData2],
				ScoreList = [Score2 || [_Id2, _Player_Id2, _Nickname2, _Realm2, _Career2, _Lv2, _Area2, _Camp2, _Type2, Score2, _Ctime2, _Killer2] <- ArenaWeekData2],
				[Player_Id0, Nickname0, Realm0, Career0, Lv0, lists:sum(KillList), lists:sum(ScoreList)]
		end,
	ResultList = [F(Player_Id) || Player_Id <- AreanWeekList1],
	ResultList1 = lists:sort(fun([_Player_Id5, _Nickname5, _Realm5, _Career5, Lv5, Wins5, _Score5],[_Player_Id6, _Nickname6, _Realm6, _Career6, Lv6, Wins6, _Score6]) -> 
									if  Wins5 =/= Wins6 -> Wins5 > Wins6;
										true -> Lv5 >= Lv6
									end
							 end, 
							 ResultList),
	ResultList3 = lists:map(fun([Player_Id8, Nickname8, Realm8, Career8, Lv8, Wins8, _Score8]) -> [Player_Id8, Nickname8, Realm8, Career8, Lv8, Wins8] end,ResultList1),
	add_order([],ResultList3,1).

%% 查询上一场战绩 23020
rank_pre_arena_week(LvNum, AreaNum, PlayerId, PidSend) ->
	AreaNum1 = AreaNum + 1,
	[Lv1,Lv2] =  
		case LvNum of
			0 -> [30,39];
			1 -> [40,59];
			2 -> [60,1000]
		end,
	OrealTime = calendar:datetime_to_gregorian_seconds({{1970,1,1}, {0,0,0}}),
	{Year,Month,Day} = date(),
	YesterDayStartTime = calendar:datetime_to_gregorian_seconds({{Year,Month,Day}, {0,0,0}})-OrealTime-8*60*60-24*60*60,%%从1970开始时间值
	CurrentDayStartTime = calendar:datetime_to_gregorian_seconds({{Year,Month,Day}, {0,0,0}})-OrealTime-8*60*60,%%从1970开始时间值
	ArenaWeekData0 = ets:match(?ETS_ARENA_WEEK, _ = '$1'),
	HourList = get_hour_time(),
	HourList1 = HourList++ [{YesterDayStartTime,CurrentDayStartTime}],
	ArenaWeekDataList = filter_data_bytime([],HourList1,ArenaWeekData0),
	AreaNum2 =
		case AreaNum == 100 of
			false  -> AreaNum1;
			true -> %%查询自己所在的战区
				AreaS = [[Area] || [{ets_arena_week, _Id, Player_Id, _Nickname, _Realm, _Career, Lv, Area, _Camp, _Type, _Score, _Ctime, _Killer}] <- ArenaWeekDataList,Lv >= Lv1,Lv =< Lv2,Player_Id == PlayerId],
				case AreaS == [] of
					true -> 100;
					false -> 
						[Area] = lists:nth(1,AreaS),
						Area
				end
		end,
	%% ArenaWeekDataList = [[{ets_arena_week, _Id, Player_Id, _Nickname, _Realm, _Career, Lv, Area, Camp, Type, _Score, Ctime}] || [{ets_arena_week, _Id, Player_Id, _Nickname, _Realm, _Career, Lv, Area, Camp, Type, _Score, Ctime}] <- ArenaWeekData0,Ctime > YesterDayStartTime,Ctime < CurrentDayStartTime],
	%%查询上一场的获胜方
	WinSide = 
	case ArenaWeekDataList of
		[] -> 0;
		_ ->                                  
			ArenaWeekData1 = [[Player_Id] || [{ets_arena_week, _Id, Player_Id, _Nickname, _Realm, _Career, Lv, Area, Camp, Type, _Score, _Ctime, _Killer}] <- ArenaWeekDataList,Lv >= Lv1,Lv =< Lv2,Area == AreaNum2,Camp == 1,Type == 2],
			ArenaWeekData2 = [[Player_Id] || [{ets_arena_week, _Id, Player_Id, _Nickname, _Realm, _Career, Lv, Area, Camp, Type, _Score, _Ctime, _Killer}] <- ArenaWeekDataList,Lv >= Lv1,Lv =< Lv2,Area == AreaNum2,Camp == 2,Type == 2],
			case length(ArenaWeekData1) == length(ArenaWeekData2) of
				true -> 0;
				false -> 
					case length(ArenaWeekData1) > length(ArenaWeekData2) of
						true -> 1;
						false -> 2
					end
			end
		end,
	%%查询战区数
	AreaData = [[Area] || [{ets_arena_week, _Id, _Player_Id, _Nickname, _Realm, _Career, Lv, Area, _Camp, _Type, _Score, _Ctime, _Killer}] <- ArenaWeekDataList,Lv >= Lv1,Lv =< Lv2],
	AreaDataS = length(lists:usort(AreaData)),
	%%排行记录
	
	ArenaWeekData = [[Nickname, Realm, Career, Lv, Camp, Killer, Score] || [{ets_arena_week, _Id, _Player_Id, Nickname, Realm, Career, Lv, Area, Camp, _Type, Score, _Ctime, Killer}] <- ArenaWeekDataList,Lv >= Lv1,Lv =< Lv2,Area == AreaNum2],
	RankList = 
		case ArenaWeekData of
			[] -> [];
			_ ->
				lists:sort(fun([_, _, _, Lv3, _, _, Score3],[_, _, _, Lv4, _, _, Score4]) ->  
													 if  Score3 =/= Score4 -> Score3 > Score4;
														 true -> Lv3 >= Lv4
													 end 
											 end, ArenaWeekData)
		end,
	AreaNum3 = 
		case AreaNum == 100 of
			false -> AreaNum;
			true -> 
				case AreaNum2 ==  100 of
					true -> AreaNum2;
					false -> AreaNum2-1
				end
		end,				
	ArenaData = [LvNum, AreaNum3, AreaDataS, WinSide, 0, lists:sublist(RankList, 100)],
	{ok, BinData} = pt_23:write(23020, ArenaData),
	lib_send:send_to_sid(PidSend, BinData).


%% 战场排行榜上一场战绩 22013
rank_total_pre_arena(PidSend) ->
	RankInfo = get_arena_week_data(101, 0, 100),
	{ok, BinData} = pt_22:write(22013, RankInfo),
	lib_send:send_to_sid(PidSend, BinData).

%% 获取战场奖励等级范围
get_arena_award_lv_range(Lv) ->
	if
		Lv >= 60 ->
			{101, 60};
		true ->
			{60, 40}
	end.

%% 战场奖励的人员列表
arena_award_member(PlayerId, PidSend, Lv) ->
	{MaxLv, MinLv} = get_arena_award_lv_range(Lv),
	RankInfo = get_arena_week_data(MaxLv, MinLv, 10),
	Result = 
		case lists:keyfind(PlayerId, 1, RankInfo) of
			false ->
				0;
			_ ->
				1
		end,
	{ok, BinData} = pt_23:write(23024, [RankInfo, Result]),
	lib_send:send_to_sid(PidSend, BinData).


%% 添加顺序号
add_order1(AccList, [], _) ->
    lists:reverse(AccList);
add_order1(AccList, [Info | List], N) ->
    NewInfo = [N | tuple_to_list(Info)],
    add_order1([list_to_tuple(NewInfo) | AccList], List, N + 1).

%% 领取战场奖励
get_arena_award(Player) ->
	#player{
		id = PlayerId,
		lv = Lv
	} = Player,
	Now = util:unixtime(),
	{TodayMidNightSecond, YestodayMidNightSecond} = util:get_midnight_seconds(Now),
	AwardStartTime = TodayMidNightSecond + ?ARENA_END_TIME + 5,
	%% 是否到领取奖励时间（领取时间是战场结束后）
	if
		Now > AwardStartTime ->
			case db_agent:get_arena_data_by_id(PlayerId, "jtime") of
				[Jtime] ->
					case is_integer(Jtime) andalso Jtime == YestodayMidNightSecond of
						true ->
							6;
						false ->
							{MaxLv, MinLv} = get_arena_award_lv_range(Lv),
							RankInfo = get_arena_week_data(MaxLv, MinLv, 10),
							NewRankInfo = add_order1([], RankInfo, 1),
							case lists:keyfind(PlayerId, 2, NewRankInfo) of
								{Num, _PlayerId, _Nickname, _Realm, _Career, _Lv, _Camp, _Type, _Score} ->
									GoodsNum =
										case Num of
											1 ->
												8;
											2 ->
												6;
											3 ->
												4;
											4 ->
												3;
											5 ->
												3;
											6 ->
												2;
											7 ->
												2;
											_ ->
												1
										end,
									{1, GoodsNum, YestodayMidNightSecond};
								_Other ->
									5
							end
					end;
				_Other ->
					spawn(fun()-> init_arena_info(Player, util:term_to_string([0, 0]), 0) end),
					5
			end;
		true ->
			2
	end.


%% 获取战场周数据 
%% Zone 战区
%% LimitNum 获取个数
get_arena_week_data(MaxLv, MinLv, LimitNum) ->
%% 	OrealTime = calendar:datetime_to_gregorian_seconds({{1970,1,1}, {0,0,0}}),
%% 	{Year,Month,Day} = date(),
%% 	CrealTime = calendar:datetime_to_gregorian_seconds({{Year,Month,Day}, {0,0,0}}),
%% 	%% 从1970开始时间值
%% 	YesterDayStartTime = ,
%% 	%% 从1970开始时间值
%% 	CurrentDayStartTime = CrealTime - OrealTime- 8 * 60 * 60,
	Now = util:unixtime(),
	{TodayMidNightSecond, YestodayMidNightSecond} = util:get_midnight_seconds(Now),
	TodaySec = util:get_today_current_second(),
	{YesterDayStartTime, CurrentDayStartTime} =
		if
			TodaySec > ?ARENA_END_TIME + 3 ->
				{TodayMidNightSecond, YestodayMidNightSecond};
			true ->
				{TodayMidNightSecond - 86400, TodayMidNightSecond}
		end,
	ArenaWeekData0 = ets:match(?ETS_ARENA_WEEK, _ = '$1'),
	HourList = get_hour_time(),
	HourList1 = [{YesterDayStartTime, CurrentDayStartTime} | HourList],
	ArenaWeekDataList = filter_data_bytime([], HourList1, ArenaWeekData0),
	ArenaWeekData = filter_arena_limit_member(ArenaWeekDataList, MaxLv, MinLv, []),
	case ArenaWeekData of
		[] -> 
			[];
		_ ->
			ArenaWeekData1 =
				lists:sort(fun({_,_, _, _, Lv3, _, _, Score3}, {_, _, _, _, Lv4, _, _, Score4}) ->  
					if  
						Score3 =/= Score4 -> 
							Score3 > Score4;
						true -> 
							Lv3 >= Lv4
					end
				end, ArenaWeekData),
			lists:sublist(ArenaWeekData1, LimitNum)
	end.

	
filter_arena_limit_member([], _MaxLv, _MinLv, ArenaMember) ->
	ArenaMember;
filter_arena_limit_member([[ArenaData] | ArenaDataList], MaxLv, MinLv, ArenaMember) ->
	#ets_arena_week{
		player_id = PlayerId,
		nickname = Nickname,
		realm = Realm,
		career = Career,
		lv = Lv,
		camp = Camp,
		score = Score,
		killer = Killer			
	} = ArenaData,
	if
		Lv >= MinLv andalso Lv < MaxLv ->
			filter_arena_limit_member(ArenaDataList, MaxLv, MinLv, [{PlayerId, Nickname, Realm, Career, Lv, Camp, Killer, Score} | ArenaMember]);
		true ->
			filter_arena_limit_member(ArenaDataList, MaxLv, MinLv, ArenaMember)	
	end.		



%% 战场排行榜(总排行,周排行) 23021
rank_arena_query(RankType, PageNum, CurrPage, PidSend) ->
	ArenaData = 
	case RankType == 0 of
		true -> %%总排行
			 rank_arena();			
		false ->%%周排行 
			rank_arena_pre_week()
	end,
	ArenaDataSize = length(ArenaData),
	TotalPage = 
		case ArenaDataSize rem 10 of
			0 -> ArenaDataSize div 10;
			_ -> ArenaDataSize div 10+1
		end,
	RankFirthName = rank_area_pre_week_firth(),
	[Start,Sum] = 
		case PageNum > 1 of
			false -> [1,50*PageNum];
			true -> [50*(PageNum-1)+1,50]
		end,
	ResultData = lists:sublist(ArenaData, Start, Sum),
	Data = [RankType, CurrPage, TotalPage, RankFirthName, ResultData],
	{ok, BinData} = pt_23:write(23021, Data),
	lib_send:send_to_sid(PidSend, BinData).

%% 总排行的战场排行榜(1周战绩排行 2总战绩排行) 22014
rank_total_arena_query(RankType) ->
	ArenaData = 
	case RankType == 2 of
		true -> %%总排行
			 rank_arena();			
		false ->%%周排行 
			rank_arena_pre_week()
	end,
	[RankType,lists:sublist(ArenaData, 100)].



%%根据时间过滤数据
filter_data_bytime(ResultList, [], _) ->
	ResultList;
filter_data_bytime(_, [{StartTime, EndTime} | HourList], DataList) ->
    ArenaWeekDataList = [[{ets_arena_week, _Id, Player_Id, _Nickname, _Realm, _Career, Lv, Area, Camp, Type, _Score, Ctime, Killer}] || [{ets_arena_week, _Id, Player_Id, _Nickname, _Realm, _Career, Lv, Area, Camp, Type, _Score, Ctime, Killer}] <- DataList,Ctime >= StartTime,Ctime =< EndTime],
	if
		length(ArenaWeekDataList) > 0 ->
			ArenaWeekDataList;
		true -> 
			filter_data_bytime([], HourList, DataList) 
	end.

%%返回今天目前时间的整点开始时间和结束时间
get_hour_time() ->
	OrealTime = calendar:datetime_to_gregorian_seconds({{1970,1,1}, {0,0,0}}),
	{Year,Month,Day} = date(),
	{Hour,_,_} = time(),
	CurrentDayStartTime = calendar:datetime_to_gregorian_seconds({{Year,Month,Day}, {0,0,0}})-OrealTime-8*60*60,%%从1970开始时间值
	Result = lists:map(fun(H) -> {CurrentDayStartTime+H*60*60,CurrentDayStartTime+(H+1)*60*60} end,lists:seq(0, Hour)),
	lists:reverse(Result).
	

%%添加顺序号
add_order(AccList, [], _) ->
    lists:reverse(AccList);
add_order(AccList, [Info | List], N) ->
    NewInfo = [N | Info],
    add_order([NewInfo | AccList], List, N + 1).

get_arena_level_name(Lvel) ->
	case Lvel of
		1 ->
			"初";
		2 ->
			"中";
		_ ->
			"高"
	end.

get_arena_side_name(ArenaSide) ->
	case ArenaSide of
		8 ->
			"天龙";
		_ ->
			"地虎"
	end.


%% 离开战场
leave_arena(Player) ->
	TodaySec = util:get_today_current_second(),
	if
 		TodaySec >= ?ARENA_JOIN_END_TIME ->
			ArenaPid = 
				case is_pid(Player#player.other#player_other.pid_dungeon) of
					true ->
						Player#player.other#player_other.pid_dungeon;
					false ->
						mod_scene:get_scene_real_pid(Player#player.scene)
				end,
			gen_server:cast(ArenaPid, {'LEAVE_ARENA', Player#player.id});
		true ->
			skip
	end,
	%% 更新玩家退出战场时间
	spawn(fun()-> db_agent:update_arena_leave_time(Player#player.id) end),
    RetPlayer = 
        case is_arena_scene(Player#player.scene) of
            true ->
                [SceneId, X, Y] = get_arena_position(Player#player.realm),
				{Hp, Mp} =
					case is_new_arena_scene(Player#player.scene) of
						true ->
							{Player#player.hp, Player#player.mp};
						false ->
							{Player#player.hp_lim, Player#player.mp_lim}
					end,
                NewPlayer = Player#player{
                    scene = SceneId,
                    x = X,
                    y = Y,
                    hp = Hp,
                    mp = Mp,
                    status = 0,
                    other = Player#player.other#player_other{
                        pid_dungeon = undefined 
                    }
                },
                lib_player:send_player_attribute2(NewPlayer, 2),
                {ok, BinData} = pt_12:write(12005, [SceneId, X, Y, <<>>, SceneId, 0, 0, 0]),
                lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send, BinData),
                NewPlayer;
            false ->
                Player
        end,
	Leader = 
		if
			RetPlayer#player.other#player_other.leader =/= 1 ->
				0;
			true ->
				1
		end,
	put(arena_angry, 0),	
    NewRetPlayer = RetPlayer#player{
        arena = 0,
		other = RetPlayer#player.other#player_other{
      		leader = Leader
   		}
    },
	List = [
		{scene, NewRetPlayer#player.scene},
       	{x, NewRetPlayer#player.x},
       	{y, NewRetPlayer#player.y},
     	{hp, NewRetPlayer#player.hp_lim},
      	{mp, NewRetPlayer#player.mp_lim},
      	{status, NewRetPlayer#player.status},
		{pid_dungeon, NewRetPlayer#player.other#player_other.pid_dungeon},
		{arena, 0},
		{leader, Leader}
	],
	mod_player:save_online_info_fields(NewRetPlayer, List),
	NewRetPlayer.

%% 离开战场
leave_arena(PlayerId, SceneId) ->
	{ok, BinData} = pt_12:write(12004, PlayerId),
	lib_send:send_to_online_scene(SceneId, BinData),
	catch ets:delete(?ETS_ONLINE_SCENE, PlayerId).

%% 获取战场进程
get_arena_pid(Player) ->
	case lib_arena:is_arena_scene(Player#player.scene) of
		true ->
			ArenaPid = mod_scene:get_scene_real_pid(Player#player.scene),
			case is_pid(ArenaPid) of
				true ->
					ArenaPid;
				false ->
					get_arena_pid1(Player)
			end;
		false ->
			get_arena_pid1(Player)
	end.
get_arena_pid1(Player) ->
	case is_pid(Player#player.other#player_other.pid_dungeon) of
		true ->
			Player#player.other#player_other.pid_dungeon;
		false ->
			Player#player.other#player_other.pid_scene
	end.
	

%% 更新战场怒气
%% Angry 增加的怒气值
update_arena_angry(Player, Angry) ->
	StoreAngry = get(arena_angry),
	CurAngry = 
		case StoreAngry of
			undefined ->
				Angry;
			_ ->
				StoreAngry + Angry
		end,
	NewAngry =
		case CurAngry > 1000 of
			true ->
				1000;
			false ->
				CurAngry
		end,
	{ok, BinData} = pt_23:write(23022, NewAngry),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	put(arena_angry, NewAngry).	

%% 使用怒气技能
arena_angry_battle(PlayerId, SceneId, X, Y) ->
	case lib_mon:get_player(PlayerId, SceneId) of
		[] ->
			skip;
		Player ->
			AttArea = 2,
			X1 = X + AttArea,
    		X2 = X - AttArea,
    		Y1 = Y + AttArea,
    		Y2 = Y - AttArea,
			AllUser = get_scene_user_for_arena(PlayerId, SceneId, X1, X2, Y1, Y2, Player#player.other#player_other.leader),
			BattleResult = arena_angry_battle_loop(AllUser, Player, []),
			{ok, BinData} = pt_20:write(20001, [PlayerId, Player#player.hp, Player#player.mp, 10065, 1, BattleResult]),
    		lib_send:send_to_online_scene(SceneId, X, Y, BinData)
	end.
arena_angry_battle_loop([], _Aer, Ret) ->
	Ret;
arena_angry_battle_loop([[PlayerId, Hp, HpLim, Mp, Pid] | U], Aer, Ret) ->
    Hurt = round(HpLim / 2),
    NewHp = 
		if
       		Hp > Hurt ->
                Hp - Hurt;
            true ->
                0
        end,
    MsgList = [
        NewHp,
        Mp,
        Aer#player.other#player_other.pid,
        Aer#player.id,
        Aer#player.nickname,
        Aer#player.career,
        Aer#player.realm,
		Aer#player.scene
    ],
    Pid ! {'PLAYER_BATTLE_RESULT', MsgList},
	lib_scene:update_player_info_fields_for_battle(PlayerId, NewHp, Mp),
    arena_angry_battle_loop(U, Aer, [[2, PlayerId, NewHp, Mp, Hurt, 0, 0] | Ret]).
get_scene_user_for_arena(AerId, SceneId, X1, X2, Y1, Y2, Leader) ->
	MS = ets:fun2ms(fun(P) when P#player.scene == SceneId, P#player.arena /= 3, P#player.hp > 0, 
									P#player.id /= AerId, P#player.x >= X2, P#player.x =< X1,  
									P#player.y >= Y2, P#player.y =< Y1, 
									P#player.other#player_other.battle_limit /= 9, 
									P#player.other#player_other.leader /= Leader ->
	    [
            P#player.id,
            P#player.hp,
			P#player.hp_lim,
            P#player.mp,
            P#player.other#player_other.pid
	    ]
	end),
	ets:select(?ETS_ONLINE_SCENE, MS).

%% 初始战场信息
init_arena_info(Player, ArenaInfo, Time) ->
	JoinTime = 
		if
			Time == 0 ->
				Now = util:unixtime(),
				Now - (?ARENA_JOIN_END_TIME - ?ARENA_JOIN_TIME);
			true ->
				Time
		end,
	ArenaData = [
		Player#player.id, 
		Player#player.nickname, 
		Player#player.realm, 
		Player#player.career, 
		Player#player.lv,
		Player#player.max_attack,
		Player#player.sex,	 
		0, 
		0,
		ArenaInfo,
		JoinTime
	],
	db_agent:insert_arena(ArenaData).

%% 战场正式开始（跳到战场中）
arena_start(Player) ->
	SceneId = Player#player.scene,
    case is_arena_scene(SceneId) of
        true ->
			%% 发送竞技时间
            TodaySec = util:get_today_current_second(),
            {ok, TimeBinData} = pt_23:write(23001, [?ARENA_END_TIME - TodaySec, 4]),
            lib_send:send_to_sid(Player#player.other#player_other.pid_send, TimeBinData),
            Mark = Player#player.other#player_other.leader,
            [X, Y] =
                case Mark of
                    %% 天龙
                    8 ->
                        [11, 60];
                    %% 地虎
                    9 ->
                        [60, 62];
                    _ ->
                        [30, 90]
                end,
            %% 坐标记录
            put(change_scene_xy, [X, Y]),
            {ok, BinData} = pt_12:write(12005, [SceneId, X, Y, <<>>, 600, 0, 0, Mark]),
            lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
            Msg = io_lib:format("战斗开始，尽情杀戮吧！", []),
            {ok, MsgBinData} = pt_11:write(11080, 2, Msg),
            lib_send:send_to_sid(Player#player.other#player_other.pid_send, MsgBinData),
            NewPlayer = Player#player{
                x = X,
                y = Y,
                other = Player#player.other#player_other{
                    battle_limit = 0																				  
                }						
            },
            mod_player:save_online_info_fields(NewPlayer, [{x, X}, {y, Y}, {battle_limit, 0}]),
            NewPlayer;		
        false ->
            case is_pid(Player#player.other#player_other.pid_dungeon) of
                true ->
                    gen_server:cast(Player#player.other#player_other.pid_dungeon, 
                            {'NO_ENTER_ARENA', Player#player.id});
                false ->
                    skip
            end,
            Player
    end.

%% 战场玩家意外退出处理
arena_terminate_quit(Player) ->
	case is_pid(Player#player.other#player_other.pid_dungeon) of
		true ->
			NowSec = util:get_today_current_second(),
			case NowSec > ?ARENA_START_TIME of
				true ->
					gen_server:cast(Player#player.other#player_other.pid_dungeon, {'PLAYER_TERMINATE_QUIT', Player#player.id});
				false ->
					skip
			end;
		false ->
			skip
	end.

%% 插入战场日志
insert_log_arena(PlayerId, Nickname, Now) ->
	LogArenaData = [PlayerId, Nickname, 0, 0, 0, Now, 0, 0],
	spawn(fun()-> db_agent:insert_log_arena(LogArenaData) end).

%% 获取战场霸主
get_arena_rank_king() ->
	MS = ets:fun2ms(fun(A) ->
		[
			A#ets_arena.player_id, 
			A#ets_arena.lv, 
			A#ets_arena.score		 
		]
	end),
	case ets:select(?ETS_ARENA, MS) of
		[] ->
			0;
		Data ->
			SortFun = fun([_, Lv1, Win1], [_, Lv2, Win2]) -> 
				if 
					Win1 =/= Win2 ->
						Win1 > Win2;
					true ->
						Lv1 > Lv2
				end
			end,
			NewData = lists:sort(SortFun, Data),
			[[PlayerId, _, _] | _] = NewData,
			PlayerId
	end.
get_arena_king() ->
	try 
		Ret = gen_server:call(mod_arena_supervisor:get_mod_arena_supervisor_work_pid(), 
					 {apply_call, lib_arena, get_arena_rank_king, []}),
		if 
			Ret == error -> 
				0;
			true -> 
				Ret 
		end
	catch
		_:_ -> 
			0
	end.

change_player_name(PlayerId,NewNickName) ->
	%%更新周排行角色名
	Ets_ArenaWeeks = ets:match_object(?ETS_ARENA_WEEK, #ets_arena_week{player_id=PlayerId, _='_'}),
	F = fun(Ets_ArenaWeek) ->
		ArenaWeekRecord = Ets_ArenaWeek#ets_arena_week{nickname = NewNickName},
		db_agent:update_arena_week_playername(PlayerId, NewNickName),
		ets:insert(?ETS_ARENA_WEEK, ArenaWeekRecord)
	end,
	[F(Ets_ArenaWeek) || Ets_ArenaWeek <- Ets_ArenaWeeks],	
	%%更新总排行角色名
	case ets:lookup(?ETS_ARENA, PlayerId) of
		[] ->
			skip;
		[Arena | _] ->
				db_agent:update_arena_playername(PlayerId, NewNickName),
              	NewArena = Arena#ets_arena{ nickname = NewNickName } ,
				ets:insert(?ETS_ARENA, NewArena)
        end.

%% 战场报名
arena_join(Player) ->
	NowSec = util:get_today_current_second(),
    if
        %% 非报名时间
        NowSec < ?ARENA_JOIN_TIME orelse NowSec > ?ARENA_END_TIME ->
            3;
        %% 报名时间截止
        NowSec > ?ARENA_JOIN_END_TIME andalso NowSec < ?ARENA_END_TIME ->
            4;
        true ->
            Now = util:unixtime(),
            case db_agent:get_arena_data_by_id(Player#player.id, "jtime") of
                [] ->
                    %% 初始战场信息
                    spawn(fun()-> init_arena_info(Player, util:term_to_string([0, 0]), Now) end),
                    %% 插入战场日志
                    insert_log_arena(Player#player.id, Player#player.nickname, Now),
                    %% 战场参与统计
                    spawn(fun()-> db_agent:update_join_data(Player#player.id, arena) end),
                    1;
                [_Jtime]->
					arena_join_action(Player, Now)
%%                     case util:is_same_date(Jtime, Now) of
%%                         true ->
%% 							{TodayMidNightSecond, _YestodayMidNightSecond} = util:get_midnight_seconds(Now),
%% 							if
%% 								Jtime >= TodayMidNightSecond + ?ARENA_JOIN_TIME andalso Jtime < TodayMidNightSecond + ?ARENA_END_TIME ->
%% 									2;
%% 								true ->
%% 									arena_join_action(Player, Now)
%% 							end;
%%                         false ->
%% 							arena_join_action(Player, Now)
%%                     end 
            end	
    end.
%% 战场报名处理
arena_join_action(Player, Now) ->
    ArenaData = [
        {att, Player#player.max_attack}, 
        {lv, Player#player.lv}, 
        {jtime, Now}
    ],
    spawn(fun()-> db_agent:update_arena_battle_info(Player#player.id, ArenaData) end),
    %% 插入战场日志
    insert_log_arena(Player#player.id, Player#player.nickname, Now),
    1.

%% 获取战场报名人数
get_arena_join_list() ->
	Now = util:unixtime(),
	{TodayMidNightSecond, _YestodayMidNightSecond} = util:get_midnight_seconds(Now),
	JoinStartTime = TodayMidNightSecond + ?ARENA_JOIN_TIME - 10,
	JoinEndTime = TodayMidNightSecond + ?ARENA_START_TIME,
	db_agent:get_join_arene_player(JoinStartTime, JoinEndTime).

start_arena_timer(NowSec, Self) ->
	ARENA_JOIN_END_TIME = ?ARENA_JOIN_END_TIME,
	ARENA_START_TIME = ?ARENA_START_TIME,
	ARENA_END_TIME = ?ARENA_END_TIME,
	ARENA_END_CHECK = ?ARENA_END_CHECK,
	%% 广播战场时间
	spawn(fun()-> broadcast_arena_time(ARENA_JOIN_END_TIME - NowSec) end),
	erlang:send_after((ARENA_JOIN_END_TIME - NowSec + 5) * 1000, Self, 'CREATE_ARENA'),
	erlang:send_after((ARENA_START_TIME - NowSec) * 1000, Self, 'START_ARENA'),
	erlang:send_after((ARENA_END_TIME - NowSec) * 1000, Self, 'ARENA_END'),
	erlang:send_after((ARENA_END_CHECK - NowSec) * 1000, Self, 'KILL_ARENA').

%% 广播战场时间
broadcast_arena_time(Time) ->
	{ok, BinData} = pt_23:write(23001, [Time, 0]),
	mod_disperse:broadcast_to_world(ets:tab2list(?ETS_SERVER), BinData),
	catch lib_send:send_to_local_all(BinData).

%% 获取战场死亡次数
get_arena_die_num() ->
	?ARENA_DIE_NUM.
	
%% 获取战场的报名时间
get_arena_join_time() ->
	?ARENA_JOIN_TIME.

%% 获取战场报名结束时间
get_arena_join_end_time() ->
	?ARENA_JOIN_END_TIME.

%% 获取战场结束时间
get_arena_end_time() ->
	?ARENA_END_TIME.

%% 获取战场开始时间
get_arena_start_time() ->
	?ARENA_START_TIME.

%% 是否战场前准备时间
is_arena_ready_time(SceneId) ->
	NowSec = util:get_today_current_second(),
	is_arena_scene(SceneId) andalso NowSec < ?ARENA_START_TIME.


%% 通知前端进入战场
notice_enter_arena(Player, ArenaZone, ArenaSceneId) ->
	PeachType = lib_peach:get_peach_type_status(Player),
	{ok, BinData} = pt_23:write(23003, [ArenaZone, ArenaSceneId, PeachType]),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData).

%% 检查是否是进入时间
is_arena_enter_time(SceneId, TodaySec) ->
	case is_new_arena_scene(SceneId) of
		true ->
			TodaySec >= ?ARENA_START_TIME - 5 andalso TodaySec < ?ARENA_END_TIME;
		false ->
			TodaySec >= ?ARENA_JOIN_END_TIME andalso TodaySec < ?ARENA_END_TIME
	end.

%% 检查进入战场的条件
check_enter_arena_condition(Player) ->
	%% 氏族领地内不能进入战场
    case lib_guild_manor:is_guild_manor_scene(Player#player.scene, Player#player.guild_id) of
        false ->
            %% 副本里不能进入战场
            case lib_scene:is_dungeon_scene(Player#player.scene) of
                false ->
					if 
						Player#player.status == 7 ->
						   	{ok, BinData} = pt_23:write(23004, 2),
						   	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
					   	Player#player.status == 10 ->
						   	{ok, BinData} = pt_23:write(23004, 7),
						   	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
						Player#player.hp < 1 ->
							skip;
						%% 组队状态不能进战场
						Player#player.other#player_other.pid_team =/= undefined ->
							{ok, BinData} = pt_23:write(23002, 10),
						   	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
						Player#player.carry_mark =/= 0 ->
							CarrySign = 
				            	if 
									Player#player.carry_mark > 0 andalso Player#player.carry_mark < 4 orelse (Player#player.carry_mark >=20 andalso Player#player.carry_mark<26)->
				               			4;
				                	true ->
				               			5
				            	end,
							{ok, BinData} = pt_23:write(23004, CarrySign),
				           	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
					   	true ->
							%% 温泉不能进战场
                       		case lib_spring:is_spring_scene(Player#player.scene) of
                           		false ->
									true;
                                true ->
                                    {ok, BinData} = pt_23:write(23004, 6),
                                    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
                            end
                    end;
                true ->
                    {ok, BinData} = pt_23:write(23002, 9),
                    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
            end;
        true ->
            {ok, BinData} = pt_23:write(23002, 11),
            lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)	
    end.


%% 战场死亡
arena_die(Player, AerPid, AerId, NickName) ->
	if
		Player#player.status =/= 3 ->
			lib_arena:update_arena_angry(Player, 100),
			lib_task:arena_task(AerPid),
			ArenaScenePid = mod_scene:get_scene_real_pid(Player#player.scene),
			NewArenaScenePid = 
				case is_pid(ArenaScenePid) of
					true ->
						ArenaScenePid;
					false ->
						Player#player.other#player_other.pid_dungeon
				end,
			gen_server:cast(NewArenaScenePid, {'ARENA_DIE', AerId, Player#player.id}),
			case lib_arena:is_new_arena_scene(Player#player.scene) of
				true ->
					{ok, BinData23008} = pt_23:write(23008, NickName),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData23008);
				false ->
					skip
			end;
		true ->
			skip
	end.
	
	
