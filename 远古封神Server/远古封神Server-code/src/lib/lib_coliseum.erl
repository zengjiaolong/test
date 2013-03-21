%%%--------------------------------------
%%% @Module  : lib_coliseum
%%% @Author  : ygfs
%%% @Created : 2012.03.02
%%% @Description: 竞技场处理 
%%%--------------------------------------
-module(lib_coliseum).

-export(
    [
		coliseum_result/2,
		is_coliseum_scene/1,
		send_coliseum_info/2,
		enter_coliseum/4,
		enter_coliseum_action/6,
		coliseum_end/1,
		check_coliseum_state/3,
		init_coliseum_data/1,
		check_coliseum_rank/2,
		get_challenger_list/2,
		create_coliseum_avatar/3,
		get_coliseum_ready_time/0,
		get_challenge_position/0,
		get_challenged_position/0,
		get_coliseum_report/1,
		insert_coliseum_report/7,
		coliseum_report_show/5,
		clear_coliseum_time/2,
		check_coliseum_enter/1,
		get_coliseum_award/1,
		get_coliseum_king/0,
		get_coliseum_rank_data/1,
		get_coliseum_rank_player/1,
		change_coselium_vip_times/3,
		get_player_coliseum_rank/1,
		get_coliseum_skill_list/1
    ]
).

-include("common.hrl").
-include("record.hrl").
-include("guild_info.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

-define(COLISEUM_READY_TIME, 10).											%% 竞技场准备时间
-define(COLISEUM_CHALLENGE_LEN, 7).											%% 挑战人数长度
-define(COLISEUM_REPORT_LEN, 8).											%% 竞技场战报长度
-define(COLISEUM_COOL_TIME, 300).											%% 竞技场CD冷却时间

%% 竞技场战报返回
coliseum_result(ColiseumResultReport, PidSend) ->
	{ok, BinData} = pt_49:write(49005, ColiseumResultReport),
   	lib_send:send_to_sid(PidSend, BinData).

%% 是否竞技场场景
is_coliseum_scene(SceneUniqueId) ->
	SceneUniqueId rem 10000 =:= ?COLISEUM_RES_SCENE_ID.


%% 打开竞技场面板
send_coliseum_info(PlayerState, Player) ->
	Now = util:unixtime(),
	%% 检测竞技场状态数据
	NewPlayerState = check_coliseum_state(PlayerState, Player, Now),
	ColiseumColdTime = 
		if
			Now > NewPlayerState#player_state.coliseum_cold_time ->
				0;				
			true ->
				NewPlayerState#player_state.coliseum_cold_time - Now
		end,
	ColiseumData = {
		Player#player.id,
		ColiseumColdTime,
		NewPlayerState#player_state.coliseum_surplus_time,
		NewPlayerState#player_state.coliseum_extra_time,
		NewPlayerState#player_state.is_avatar
	},
	ColiseumPid = mod_coliseum_supervisor:get_coliseum_worker_pid(),
	gen_server:cast(ColiseumPid, {'SEND_COLISEUM_INFO', Player#player.id, ColiseumData, Player#player.other#player_other.pid_send, Now}),
	{ok, change_player_state, NewPlayerState}.


%% 进入竞技场
enter_coliseum(PlayerState, Player, ChallengerId, ColiseumPlayerData) ->
	Now = util:unixtime(),
	if
		Now > PlayerState#player_state.coliseum_cold_time ->
			NewPlayerState = PlayerState#player_state{
				coliseum_surplus_time = PlayerState#player_state.coliseum_surplus_time - 1,
				coliseum_cold_time = Now + ?COLISEUM_COOL_TIME										 
			},
			ColiseumSceneId = mod_dungeon:get_unique_dungeon_id(?COLISEUM_RES_SCENE_ID),
			case mod_coliseum:start_link([ColiseumSceneId, Player, ChallengerId, ColiseumPlayerData]) of
				{ok, _ColiseumPid} ->
					{X, Y} = get_challenge_position(),
					enter_coliseum_action(NewPlayerState, Player, ColiseumSceneId, X, Y, Now);
				_Error ->
					skip
			end;		
		true ->
			{ok, BinData} = pt_49:write(49007, [3, 0, []]),
   			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
	end.
	
	

%% 进入竞技场
enter_coliseum_action(PlayerState, Player, ColiseumSceneId, X, Y, Now) ->
	StaPlayer = 
		case Player#player.status of
			%% 挂机
			5 ->
				lib_hook:cancel_hoook_status(Player);
			%% 打坐
			6 ->
				{ok, SitPlayer} = lib_player:cancelSitStatus(Player),
				{ok, BinData13015} = pt_13:write(13015, [SitPlayer#player.id, 0]),
				lib_send:send_to_sid(SitPlayer#player.other#player_other.pid_send, BinData13015),
				SitPlayer;
			_ ->
				Player
		end,
	%% 下坐骑
	{ok, MountPlayer} = lib_goods:force_off_mount(StaPlayer),
	%% 告诉原来场景玩家你已经离开
	pp_scene:handle(12004, Player, Player#player.scene),
	
	ColiseumStartTime = Now + ?COLISEUM_READY_TIME + ?COLISEUM_READY_TIME,
	NewPlayer = MountPlayer#player{
		scene = ColiseumSceneId, 
		x = X, 
		y = Y,
		hp = MountPlayer#player.hp_lim,
		mp = MountPlayer#player.mp_lim,
		status = 0,
		other = MountPlayer#player.other#player_other{
			die_time = ColiseumStartTime,
			battle_limit = 0,
			battle_dict = #battle_dict{}
		}	
	},
	List = [
		{scene, ColiseumSceneId},
		{x, X},
		{y, Y},
		{hp, NewPlayer#player.hp_lim},
		{mp, NewPlayer#player.mp_lim},
		{status, 0},
		{die_time, ColiseumStartTime},
		{battle_limit, 0},
		{peach_revel, NewPlayer#player.other#player_other.peach_revel},
		{mount, NewPlayer#player.mount},
       	{speed, NewPlayer#player.speed},
       	{equip_current, NewPlayer#player.other#player_other.equip_current},
       	{mount_stren, NewPlayer#player.other#player_other.mount_stren},
		{battle_dict, NewPlayer#player.other#player_other.battle_dict}
	],
	mod_player:save_online_info_fields(NewPlayer, List),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer,
		coliseum_d_scene = MountPlayer#player.scene,
		coliseum_d_x = MountPlayer#player.x,
		coliseum_d_y = MountPlayer#player.y
	},
	{ok, BinData} = pt_12:write(12005, [ColiseumSceneId, X, Y, <<>>, ?COLISEUM_RES_SCENE_ID, 0, 0, 0]),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	lib_player:send_player_attribute2(NewPlayer, 2),
	%%竞技场挑战任务
	lib_task:event(arena_pk, null, NewPlayer),
	lib_task:event(arena_fight, null, NewPlayer),
	{ok, change_player_state, NewPlayerState}.

%% 竞技场结束
coliseum_end(PlayerState) ->
 	Player = PlayerState#player_state.player,
	case is_coliseum_scene(Player#player.scene) of
		true ->
			misc:cancel_timer(bleed_timer),
			ColiseumScenePid = mod_scene:get_scene_real_pid(Player#player.scene),
			gen_server:cast(ColiseumScenePid, {'COLISEUM_LEAVE', Player#player.id}),
			{SceneId, X, Y} = {
				PlayerState#player_state.coliseum_d_scene, 
				PlayerState#player_state.coliseum_d_x, 
				PlayerState#player_state.coliseum_d_y
			},
			NewPlayer = Player#player{
		        scene = SceneId,
		        x = X,
		        y = Y,
		        hp = Player#player.hp_lim,
		        mp = Player#player.mp_lim,
		        status = 0,
		        other = Player#player.other#player_other{
		            pid_dungeon = undefined 
		        }
		    },
		    lib_player:send_player_attribute2(NewPlayer, 2),
		    {ok, BinData} = pt_12:write(12005, [SceneId, X, Y, <<>>, SceneId, 0, 0, 0]),
		    lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send, BinData),
			List = [
				{scene, NewPlayer#player.scene},
		       	{x, NewPlayer#player.x},
		       	{y, NewPlayer#player.y},
		     	{hp, NewPlayer#player.hp_lim},
		      	{mp, NewPlayer#player.mp_lim},
		      	{status, NewPlayer#player.status}
			],
			mod_player:save_online_info_fields(NewPlayer, List),
			NewPlayer;
		false ->
			Player
	end.

change_coselium_vip_times(PlayerState, Vip1, Vip2) ->
	ColiseumSurplusTime = 
		case [Vip1, Vip2] of
			[3, 2] ->
				3;
			[3, 1] ->
				5;
			[3, 4] ->
				5;
			[3, 0] ->
				7;
			[2, 1] ->
				2;
			[2, 4] ->
				2;
			[2, 0] ->
				4;
			[1, 0] ->
				2;
			[4, 0] ->
				2;
			_ ->
				0
		end,
	PlayerState#player_state{
		coliseum_surplus_time = PlayerState#player_state.coliseum_surplus_time + ColiseumSurplusTime
	}.


%% 检测竞技场状态数据
check_coliseum_state(PlayerState, Player, Now) ->
	case util:is_same_date(PlayerState#player_state.coliseum_time, Now) of
		true ->
			PlayerState;
		false ->
			ColiseumSurplusTime = 
				case Player#player.vip of
					%% 半年卡
					3 ->
						15;
					%% 季卡
					2 ->
						12;
					%% 月卡
					1 ->
						10;
					%% 周卡
					4 ->
						10;
					_ ->
						8
				end,
			PlayerState#player_state{
				coliseum_time = Now,
				coliseum_surplus_time = ColiseumSurplusTime,
				coliseum_extra_time = 0						 
			}
	end.


%% 初始竞技场数据
init_coliseum_data(Player) ->
	BattVal = lib_player:count_value(Player#player.other#player_other.batt_value),
	ColiseumPid = mod_coliseum_supervisor:get_coliseum_worker_pid(),
	gen_server:cast(ColiseumPid, {'COLISEUM_CHECK', Player#player.id, Player#player.nickname, Player#player.lv, 
			BattVal, Player#player.realm, Player#player.sex, Player#player.career}).

%% 检查排名
check_coliseum_rank(Rank1, Rank2) ->
	if
		Rank1 < 50 ->
			abs(Rank1 - Rank2) =< ?COLISEUM_CHALLENGE_LEN;
		Rank1 < 100 ->
			abs(Rank1 - Rank2) =< 10;
		Rank1 < 300 ->
			abs(Rank1 - Rank2) =< 30;
		Rank1 < 800 ->
			abs(Rank1 - Rank2) =< 50;
		true ->
			abs(Rank1 - Rank2) =< 100
	end.

%% 获取竞技场挑战者列表
get_challenger_list(ColiseumRankData, Rank) ->
	if
		Rank =< ?COLISEUM_CHALLENGE_LEN ->
			RankList = lists:seq(1, ?COLISEUM_CHALLENGE_LEN),
			get_challenger_list_loop(RankList, ColiseumRankData, []);
		Rank < 50 ->
			RankList = [Rank - (R - 1) || R <- lists:seq(1, ?COLISEUM_CHALLENGE_LEN)],
			get_challenger_list_loop(RankList, ColiseumRankData, []);
		Rank < 100 ->
			RankList = rand_rank_num(?COLISEUM_CHALLENGE_LEN - 1, 10, Rank, [Rank]),
			get_challenger_list_loop(RankList, ColiseumRankData, []);
		Rank < 300 ->
			RankList = rand_rank_num(?COLISEUM_CHALLENGE_LEN - 1, 30, Rank, [Rank]),
			get_challenger_list_loop(RankList, ColiseumRankData, []);
		Rank < 800 ->
			RankList = rand_rank_num(?COLISEUM_CHALLENGE_LEN - 1, 50, Rank, [Rank]),
			get_challenger_list_loop(RankList, ColiseumRankData, []);
		true ->
			RankList = rand_rank_num(?COLISEUM_CHALLENGE_LEN - 1, 100, Rank, [Rank]),
			get_challenger_list_loop(RankList, ColiseumRankData, [])
	end.
get_challenger_list_loop([], _ColiseumRankData, ColiseumData) ->
	SortFun = fun(C1, C2) ->
		C1#ets_coliseum_rank.rank < C2#ets_coliseum_rank.rank
	end,
	lists:sort(SortFun, ColiseumData);
get_challenger_list_loop([Rank | R], ColiseumRankData, ColiseumData) ->
	case lists:keyfind(Rank, 12, ColiseumRankData) of
		false ->
			get_challenger_list_loop(R, ColiseumRankData, ColiseumData);
		ColiseumPlayer ->
			get_challenger_list_loop(R, ColiseumRankData, [ColiseumPlayer | ColiseumData])
	end.

%% 获取随机排名
rand_rank_num(0, _Range, _Rank, RankList) ->
	RankList;
rand_rank_num(N, Range, Rank, RankList) ->
	RandRank = Rank - random:uniform(Range),
	case lists:member(RandRank, RankList) of
		true ->
			rand_rank_num(N, Range, Rank, RankList);
		false ->
			rand_rank_num(N - 1, Range, Rank, [RandRank | RankList])
	end.


%% 生成竞技场替身
create_coliseum_avatar(ChallengePlayer, ColiseumSceneId, SkillList) ->
	Now = util:unixtime(),
	ColiseumStartTime = Now + ?COLISEUM_READY_TIME,
	NewChallengerId = round(?MON_LIMIT_NUM / 10) + ChallengePlayer#player.id,
	NewChallengePlayer = ChallengePlayer#player{
		scene = ColiseumSceneId,
		other = ChallengePlayer#player.other#player_other{
			die_time = ColiseumStartTime
		}										 
	},
	{X, Y} = get_challenged_position(),
	NewSkillList = 
		if
			SkillList =/= [] ->
				SkillList;		
			true ->
				{HookConfig, _TimeStart, _TimeLimit, _Timestamp} = lib_hook:get_hook_config(ChallengePlayer#player.id),
				HooConfigSkillList = get_coliseum_skill_list(HookConfig),
				mod_mon_create:shadow_skill(HooConfigSkillList, ChallengePlayer, [])
		end,
	mod_shadow_active:start([NewChallengePlayer, NewChallengerId, X, Y, NewSkillList]).


%% 获取竞技场技能列表
get_coliseum_skill_list(HookConfig) ->
	if
		HookConfig#hook_config.coliseum_skill_list =/= [0, 0, 0, 0, 0] ->
			HookConfig#hook_config.coliseum_skill_list;
		true ->
			HookConfig#hook_config.skill_list
	end.
	
	
%% 获取竞技场准备时间
get_coliseum_ready_time() ->
	?COLISEUM_READY_TIME.

%% 挑战者位置
get_challenge_position() ->
	{8, 25}.

%% 被挑战者的位置
get_challenged_position() ->
	{17, 19}.


%% 获取竞技场战报
get_coliseum_report(PlayerId) ->
	FieldList = "id, c_id, ctime, name, relation, win, rank",
	ReportData = db_agent:select_all(log_coliseum_report, FieldList, [{player_id, PlayerId}], [{ctime, desc}], ?COLISEUM_REPORT_LEN),
	[list_to_tuple(R) || R <- ReportData].

%% 更新竞技场战报
insert_coliseum_report(ColiseumPlayer, ChallengerId, ChallengerName, Relation, Win, Rank, Now) ->
	FieldList = [player_id, c_id, name, relation, win, rank, ctime],
	ValueList = [ColiseumPlayer#ets_coliseum_rank.player_id, ChallengerId, ChallengerName, Relation, Win, Rank, Now],
	ReportId = db_agent:insert(log_coliseum_report, FieldList, ValueList),
	Report = {ReportId, ChallengerId, Now, ChallengerName, Relation, Win, Rank},
	ColiseumRankReport = 
		case is_list(ColiseumPlayer#ets_coliseum_rank.report) of
			true ->
				ColiseumPlayer#ets_coliseum_rank.report;
			false ->
				[]
		end,
	ColiseumReportLen = length(ColiseumRankReport),
	NewColiseumRankReport = 
		if
			ColiseumReportLen >= ?COLISEUM_REPORT_LEN ->
				{LeftList, _RightList} = lists:split(ColiseumReportLen - 1, ColiseumRankReport),
				[Report | LeftList];
			true ->
				[Report | ColiseumRankReport]
		end,
	ValueList1 = [
		{win, ColiseumPlayer#ets_coliseum_rank.win},
		{trend, ColiseumPlayer#ets_coliseum_rank.trend},
		{rank, ColiseumPlayer#ets_coliseum_rank.rank}			 
	],
	spawn(fun()-> 
		case Relation == 2 andalso lib_player:is_online(ColiseumPlayer#ets_coliseum_rank.player_id) of
			true ->
				ColiseumReportMsg = pack_coliseum_report(Win, Rank, Relation, ColiseumPlayer#ets_coliseum_rank.nickname, ChallengerName),
				{ok, ColiseumReportBinData} = pt_11:write(11080, 1, ColiseumReportMsg),
				lib_send:send_to_uid(ColiseumPlayer#ets_coliseum_rank.player_id, ColiseumReportBinData);
			false ->
				skip
		end,
		db_agent:update(coliseum_rank, ValueList1, [{player_id, ColiseumPlayer#ets_coliseum_rank.player_id}]) 
	end),
	
	ColiseumPlayer#ets_coliseum_rank{
		report = NewColiseumRankReport							 
	}.


%% 竞技场战报展示
coliseum_report_show(ColiseumPlayer, ReportId, Nickname, Vip, State) ->
	case lists:keyfind(ReportId, 1, ColiseumPlayer#ets_coliseum_rank.report) of
		{_ResultId, _ChallengerId, _ResultTime, Name, Relation, Result, Rank} ->
			ColiseumReportMsg = pack_coliseum_report(Result, Rank, Relation, Nickname, Name),
			ColiseumReportData = [
				ColiseumPlayer#ets_coliseum_rank.player_id, 
				ColiseumPlayer#ets_coliseum_rank.nickname, 
				ColiseumPlayer#ets_coliseum_rank.career, 
				ColiseumPlayer#ets_coliseum_rank.realm, 
				ColiseumPlayer#ets_coliseum_rank.sex, 
				Vip,
				State, 
				ColiseumReportMsg
			],
			{ok, ColiseumReportBinData} = pt_11:write(11010, ColiseumReportData),
			lib_send:send_to_all(ColiseumReportBinData, 3);
		_ ->
			skip
	end.

%% 组装战报内容
pack_coliseum_report(Result, Rank, Relation, Nickname, Name) ->
	if
		Result =:= 1 orelse Result =:= 3 ->
			ResultText = "获胜",
			if
				Rank =/= 0 ->
					RankText = io_lib:format("升到第~p位", [Rank]);
				true ->
					RankText = "排名不变"
			end;
		true ->
			ResultText = "战败",
			if
				Rank =/= 0 ->
					RankText = io_lib:format("降到第~p位", [Rank]);
				true ->
					RankText = "排名不变"
			end
	end,
	{MsgNickname, MsgName} =
		if
			Relation == 1 ->
				{Nickname, Name};
			true ->
				{Name, Nickname}
		end,
	io_lib:format("<font color='#FFCF00'>[~s]</font> 挑战了 <font color='#FFCF00'>[~s]</font>，~s~s了，~s。", [MsgNickname, MsgName, Nickname, ResultText, RankText]).

%% 清零冷却时间
clear_coliseum_time(PlayerState, Player) ->
	Now = util:unixtime(),
	DistTime = PlayerState#player_state.coliseum_cold_time - Now,
	%% 每次挑战CD时间为10分钟
	if
		DistTime > 0 ->
			Cost = util:ceil(DistTime / 60),
			if
				%% 元宝不足
				Player#player.gold < Cost ->
					{ok, BinData} = pt_49:write(49004, [1, 2, 0, 0]),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
				true ->
					NewPlayer = lib_goods:cost_money(Player, Cost, gold, 4904),
					lib_player:send_player_attribute2(NewPlayer, 2),
					{ok, BinData} = pt_49:write(49004, [1, 1, 0, 0]),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
					NewPlayerState = PlayerState#player_state{
						player = NewPlayer,
						coliseum_cold_time = 0							   
					},
					{ok, change_player_state, NewPlayerState}
			end;
		true ->
			skip
	end.

%% 检查竞技场进入
check_coliseum_enter(Player) ->
	if
		Player#player.hp =< 0 ->
			{ok, BinData} = pt_49:write(49007, [12, 0, []]),
   			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
%% 		%% 战场状态不能参加竞技场
%% 		Player#player.arena > 0 ->
%% 			{ok, BinData} = pt_49:write(49007, [9, 0, []]),
%%    			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		%% 5运镖跑商状态不能打竞技场
		Player#player.carry_mark > 0 ->
			{ok, BinData} = pt_49:write(49007, [5, 0, []]),
   			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		%% 13蓝名不能参加竞技场
		Player#player.status == 4 ->
			{ok, BinData} = pt_49:write(49007, [13, 0, []]),
   			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
%% 		%% 15打坐不能进入竞技场
%% 		Player#player.status == 6 ->
%% 			{ok, BinData} = pt_49:write(49007, [15, 0, []]),
%%    			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		%% 7凝神状态不能打竞技场
		Player#player.status == 7 ->
			{ok, BinData} = pt_49:write(49007, [7, 0, []]),
   			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		%% 14双修不能进入竞技场
		Player#player.status == 10 ->
			{ok, BinData} = pt_49:write(49007, [14, 0, []]),
   			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		true ->
			%% 8温泉里不能打竞技场
			case lib_spring:is_spring_scene(Player#player.scene) of
				false ->
					%% 4副本内不打竞技场
					case data_scene:get(Player#player.scene) of
						[] ->
							{ok, BinData} = pt_49:write(49007, [4, 0, []]),
   							lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
						SceneInfo ->
							case lists:member(SceneInfo#ets_scene.type, [0, 1]) of
								true ->
									true;
								false ->
									{ok, BinData} = pt_49:write(49007, [4, 0, []]),
   									lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
							end
					end;
				true ->
					{ok, BinData} = pt_49:write(49007, [8, 0, []]),
   					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
			end
	end.

%% 领取竞技场奖励
get_coliseum_award(PlayerState) ->
	Player = PlayerState#player_state.player,
	ColiseumRank = PlayerState#player_state.coliseum_rank,
	ColiseumPid = mod_coliseum_supervisor:get_coliseum_worker_pid(),
	case catch gen_server:call(ColiseumPid, 'AWARD_TIME') of
		{1, AwardTime} ->
			GoodsTypeId = 
				if
					ColiseumRank == 1 ->
						28835;
					ColiseumRank < 11 ->
						28834;
					ColiseumRank < 26 ->
						28833;
					ColiseumRank < 101 ->
						28832;
					true ->
						0
				end,
			IsOk = 
				if
					GoodsTypeId > 0 ->
						case catch gen_server:call(Player#player.other#player_other.pid_goods, 
															{'give_goods', Player, GoodsTypeId, 1, 2}) of
		 					ok ->
								1;
							_Other->
								0
						end;
					true ->
						1
				end,
			if
				IsOk == 1 ->
					{Culture, Coin} = coliseum_culture_coin_award(ColiseumRank),
					Spirit = coliseum_spirit_award(ColiseumRank, Player#player.lv),
					NewCulture = Player#player.culture + trunc(Culture),
					NewSpirit = Player#player.spirit + trunc(Spirit),
					NewCoin = trunc(Coin),
					CoinPlayer = lib_goods:add_money(Player, NewCoin, bcoin, 4914),
					NewPlayer = CoinPlayer#player{
						culture = NewCulture,
						spirit = NewSpirit							  
					},
					Now = util:unixtime(),
					NewAwardTime = AwardTime - Now,
					{ok, BinData} = pt_49:write(49014, [1, Culture, NewCoin, Spirit, NewAwardTime, GoodsTypeId]),
				   	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
					spawn(fun()-> db_agent:update(player_other, [{coliseum_rank, 0}], [{pid, Player#player.id}]) end),
					
					NewPlayerState = PlayerState#player_state{
						player = NewPlayer,
						coliseum_rank = 0
					},
					{ok, change_player_state, NewPlayerState};	
				true ->
					%% 背包满
					{ok, BinData} = pt_49:write(49014, [3, 0, 0, 0, 0, 0]),
		   			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
			end;
		_ ->
			{ok, BinData} = pt_49:write(49014, [4, 0, 0, 0, 0, 0]),
		   	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
	end.

coliseum_culture_coin_award(ColiseumRank) ->
	if
		ColiseumRank < 51 ->
			{40000 - 500 * (ColiseumRank - 1), 300000 - 5000 * (ColiseumRank - 1)};
		ColiseumRank < 301 ->
			{15500 - 30 * (ColiseumRank - 1), 55000 - 150 * (ColiseumRank - 1)};
		true ->
			{6500, 10000}
	end.

coliseum_spirit_award(ColiseumRank, Lv) ->
	if
		ColiseumRank == 1 ->
			Lv * 20000;
		ColiseumRank < 6 ->
			Lv * 13332 - (ColiseumRank - 2) * Lv * 532;
		ColiseumRank < 21 ->
			Lv * 10666 - (ColiseumRank - 6) * Lv * 166;
		ColiseumRank < 51 ->
			Lv * 8000 - (ColiseumRank - 21) * Lv * 128;
		ColiseumRank < 101 ->
			Lv * 4000 - (ColiseumRank - 51) * Lv * 26;
		ColiseumRank < 201 ->
			Lv * 2666 - (ColiseumRank - 101) * Lv * 12;
		ColiseumRank < 501 ->
			Lv * 1332 - (ColiseumRank - 201) * Lv * 4;
		true ->
			Lv * 1332 - (500 - 201) * Lv * 4
	end.

%% 获取竞技场第一名玩家
get_coliseum_king() ->
	ColiseumPid = mod_coliseum_supervisor:get_coliseum_worker_pid(),
	case catch gen_server:call(ColiseumPid, 'COLISEUM_KING') of
		{1, KingId} ->
			if
				KingId > 0 ->
					[KingId];
				true ->
					[]
			end;
		_ ->
			[]
	end.


%% 获取竞技场排名
get_player_coliseum_rank(PlayerId) ->
	ColiseumPid = mod_coliseum_supervisor:get_coliseum_worker_pid(),
	case catch gen_server:call(ColiseumPid, {'PLAYER_COLISEUM_RANK', PlayerId}) of
		{1, Rank} ->
			Rank;
		_ ->
			0
	end.
	

%% 获取竞技场前N名玩家
get_coliseum_rank_data(Num) ->
	try
		ColiseumPid = mod_coliseum_supervisor:get_coliseum_worker_pid(),
		case gen_server:call(ColiseumPid, {apply_call, lib_coliseum, get_coliseum_rank_player, [Num]}) of
			error ->
				[];
			Data ->
				Data
		end
	catch
		_:_ ->
			[]
	end.

%% 获取竞技场前N名玩家
get_coliseum_rank_player(Num) ->
	ColiseumRankData = ets:tab2list(?ETS_COLISEUM_RANK),
	LenColiseumRank = length(ColiseumRankData),
	SortFun = fun(C1, C2) ->
		C1#ets_coliseum_rank.rank < C2#ets_coliseum_rank.rank
	end,
	ColiseumRankData1 = lists:sort(SortFun, ColiseumRankData),
	if
		LenColiseumRank > Num ->
			{LeftList, _RightList} = lists:split(Num, ColiseumRankData1),
			LeftList;
		true ->
			ColiseumRankData1
	end.
