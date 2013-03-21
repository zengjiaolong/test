%% Author: Administrator
%% Created: 2012-2-20
%% Description: TODO: 跨服单人竞技记录
-module(lib_war2).

-compile(export_all).

-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

%%
%% API Functions
%%
is_war2_server()->
	config:get_war_server_mark() > 0.

is_war2_scene(SceneId) ->
	Scene = SceneId rem 1000,
	Scene =:= 730 orelse Scene =:= 740.
is_wait_scene(SceneId) ->
	Scene = SceneId rem 1000,
	Scene =:= 730.
is_fight_scene(SceneId)->
	Scene = SceneId rem 1000,
	Scene =:= 740.

%%初始化竞技记录
init_war2_record()->
	F = fun(Record) ->
			EtsData = list_to_tuple([ets_war2_record] ++ Record),
            ets:insert(?ETS_WAR2_RECORD, EtsData)
           end,
	RecordBag = db_agent:select_war2_record(),
	lists:foreach(F, RecordBag),
	ok.
clear_war2_record()->
	db_agent:delete_war2_record(),
	ets_clear_war2_record(),
	ok.

%%初始化淘汰赛记录
init_war2_elimination()->
	F = fun(Record) ->
			EtsData = list_to_tuple([ets_war2_elimination] ++ Record),
            ets:insert(?ETS_WAR2_ELIMINATION, EtsData)
           end,
	RecordBag = db_agent:select_war2_elimination(),
	lists:foreach(F, RecordBag),
	ok.

%%删除淘汰赛记录
clear_war2_elimination()->
	db_agent:delete_war2_elimination(),
	ets_clear_war2_elimination(),
	ok.
	
%%重载淘汰赛记录
reload_war2_elimination()->
	ets_clear_war2_elimination(),
	init_war2_elimination(),
	ok.

%%初始化淘汰赛战报记录
init_war2_pape()->
	F = fun(Record) ->
				EtsData = list_to_tuple([ets_war2_pape] ++ Record),
				ets:insert(?ETS_WAR2_PAPE, EtsData)
		end,
	RecordBag = db_agent:select_war2_pape(),
	lists:foreach(F, RecordBag),
	ok.

%%清除淘汰赛战报记录
clear_war2_pape()->
	ets_clear_war2_pape(),
	db_agent:delete_war2_pape(),
	ok.

%%初始化竞技个人历史记录
init_war2_history(PlayerId,NickName)->
	F = fun(History) ->
				%%id,enemy,result,state,timestamp
			[Id,Enemy,Result,State,Timestamp] = History,
			EtsDat = #ets_war2_history{id=Id,pid=PlayerId,enemy=Enemy,result=Result,state=State,timestamp=Timestamp},
            ets:insert(?ETS_WAR2_HISTORY, EtsDat)
           end,
	RecordBag = db_agent:select_war2_history(NickName),
	lists:foreach(F, RecordBag),
	ok.

%%玩家下线，清除历史记录
offline_clear_history(PlayerId)->
	ets_delete_war2_history(PlayerId),
	ok.

init_war2_state()->
	case db_agent:select_war2_state() of
		[]->
			db_agent:insert_war2_state(),
			{1,2};
		[Times,State]->
			{Times,State}
	end.

init_war2_champion(Grade)->
	case db_agent:select_war2_champion(Grade) of
		[]->[];
		[Champion|_]->Champion
	end.

get_elimination_info(Grade)->
	ets_select_war2_elimination_by_grade(Grade).

%%初始化投注
init_war2_bet()->
	F = fun(Record) ->
				EtsData = list_to_tuple([ets_war2_bet] ++ Record),
				ets:insert(?ETS_WAR2_BET, EtsData)
		end,
	RecordBag = db_agent:select_war2_bet(),
	lists:foreach(F, RecordBag),
	ok.

%%清除投注
clear_war2_bet()->
	ets_delete_war2_bet(),
	db_agent:delete_war2_bet(),
	ok.
%%
%% Local Functions
%%

%%单人竞技记录
ets_update_war2_record(NewRecord)->
	ets:insert(?ETS_WAR2_RECORD, NewRecord).
%%根据玩家id获取记录
ets_select_war2_record(PlayerId)->
	ets:lookup(?ETS_WAR2_RECORD, PlayerId).
%%获取种子选手
ets_select_war2_record_by_seed(Grade)->
	ets:match_object(?ETS_WAR2_RECORD, #ets_war2_record{grade=Grade,seed=1,_='_'}).
%%更加级别，分区获取玩家记录
ets_select_war2_record_by_subarea(Grade,Subarea)->
	ets:match_object(?ETS_WAR2_RECORD, #ets_war2_record{grade=Grade,subarea=Subarea,_='_'}).
%%根据平台，服，名字获取记录
ets_select_war2_record_by_name(Platform,Sn,NickName)->
	ets:match_object(?ETS_WAR2_RECORD, #ets_war2_record{platform=Platform,sn=Sn,nickname=NickName,_='_'}).
%%获取所有玩家记录
ets_select_war2_record_all()->
	ets:tab2list(?ETS_WAR2_RECORD).
%%根据玩家id删除记录
ets_delete_war2_record(PlayerId)->
	ets:delete(?ETS_WAR2_RECORD, PlayerId).
%%清除所有记录
ets_clear_war2_record()->
	ets:delete_all_objects(?ETS_WAR2_RECORD).

%%淘汰赛记录

%%获取所有淘汰赛纪录
ets_select_war2_elimination_all()->
	ets:tab2list(?ETS_WAR2_ELIMINATION).

ets_update_war2_elimination(NewRecord)->
	ets:insert(?ETS_WAR2_ELIMINATION, NewRecord).
%%根据玩家id获取记录
ets_select_war2_elimination(PlayerId)->
	ets:lookup(?ETS_WAR2_ELIMINATION, PlayerId).
%%根据级别获取记录
ets_select_war2_elimination_by_grade(Grade)->
	ets:match_object(?ETS_WAR2_ELIMINATION, #ets_war2_elimination{grade=Grade,_='_'}).
%%根据级别，分区获取记录
ets_select_war2_elimination_by_subarea(Grade,Subarea)->
	ets:match_object(?ETS_WAR2_ELIMINATION, #ets_war2_elimination{grade = Grade,subarea=Subarea,_='_'}).
%%获取四强玩家
ets_select_war2_elimination_by_champion(Platform,Sn)->
	MS = ets:fun2ms(
		   fun(T) when 
				T#ets_war2_elimination.platform =:=Platform,
				T#ets_war2_elimination.sn =:= Sn,
				T#ets_war2_elimination.champion =/= 0
				-> T	
		   end),
   ets:select(?ETS_WAR2_ELIMINATION, MS) .
%%根据平台，服，名字获取记录
ets_select_war2_elimination_by_sn(Platform,Sn,Nickname)->
	ets:match_object(?ETS_WAR2_ELIMINATION, #ets_war2_elimination{platform=Platform,sn=Sn,nickname=Nickname,_='_'}).
%%根据晋级获取记录
ets_select_war2_elimination_by_win()->
	ets:match_object(?ETS_WAR2_ELIMINATION, #ets_war2_elimination{elimination=1,_='_'}).
ets_select_war2_elimination_by_win(Grade)->
	ets:match_object(?ETS_WAR2_ELIMINATION, #ets_war2_elimination{grade=Grade,elimination=1,_='_'}).

%%获取冠军
ets_select_war2_elimination_champion(Grade)->
	ets:match_object(?ETS_WAR2_ELIMINATION, #ets_war2_elimination{grade=Grade,champion=1,_='_'}).
%%根据玩家id删除数据
ets_delete_war2_elimination(PlayerId)->
	ets:delete(?ETS_WAR2_ELIMINATION, PlayerId).
%%清除所有数据
ets_clear_war2_elimination()->
	ets:delete_all_objects(?ETS_WAR2_ELIMINATION).

%%参赛历史记录
ets_update_war2_history(History)->
	ets:insert(?ETS_WAR2_HISTORY, History).
ets_select_war2_history(PlayerId)->
	ets:match_object(?ETS_WAR2_HISTORY, #ets_war2_history{pid=PlayerId,_='_'}).
ets_delete_war2_history(PlayerId)->
	ets:match_delete(?ETS_WAR2_HISTORY, #ets_war2_history{pid=PlayerId,_='_'}).

%%下注
ets_update_war2_bet(Bet)->
	ets:insert(?ETS_WAR2_BET, Bet).
ets_select_war2_bet(PlayerId)->
	ets:lookup(?ETS_WAR2_BET, PlayerId).
ets_select_war2_bet_all()->
	ets:tab2list(?ETS_WAR2_BET).
ets_delete_war2_bet()->
	ets:delete_all_objects(?ETS_WAR2_BET).

%%清除战报
ets_clear_war2_pape()->
	ets:delete_all_objects(?ETS_WAR2_PAPE).
%%查询战报
ets_select_war2_pape(Grade,State,Pid)->
	MS = ets:fun2ms(
		   fun(T) when 
				T#ets_war2_pape.grade =:=Grade,
				T#ets_war2_pape.state =:= State,
				T#ets_war2_pape.pid_a ==Pid orelse T#ets_war2_pape.pid_b ==Pid 
				-> T	
		   end),
   ets:select(?ETS_WAR2_PAPE, MS) .

%%是否已报名
is_apply(PlayerId)->
	case check_apply_time() of
		true->
			case ets_select_war2_record(PlayerId) of
				[]->1;
				_->2
			end;
		false->0
	end.

%%报名
%%errorcode 1报名成功；2现在不是报名开放时间，3等级不足，4已经报名,5天罡级别邀请战斗力18000以上，6地煞要战斗力8000以上
apply(Status)->
	case config:get_war_server_info() of
		[_,_,_,_,1]->
			case check_apply_time() of
				true->
					if Status#player.lv< 55->[3];
					   true->
						   case ets_select_war2_record(Status#player.id) of
							   []->
								   BattValue = lib_player:count_value(Status#player.other#player_other.batt_value),
								   Grade = get_grade(Status#player.lv),
								   case check_battvalue(Status#player.id,Grade,BattValue) of
									   [1]->
										   Platform = config:get_platform_name(),
										   Sn = config:get_server_num(),
										   NowTime = util:unixtime(),
										   Data = [Status#player.id,Status#player.nickname,Status#player.career,Status#player.sex,Status#player.lv,BattValue,Platform,Sn,Grade,1,NowTime,0],
										   {_,Id} = db_agent:insert_war2_record(Data),
										   Record = #ets_war2_record{
																	 id = Id,
																	 pid = Status#player.id,
																	 nickname = tool:to_binary(Status#player.nickname),
																	 career = Status#player.career,
																	 sex = Status#player.sex, 
																	 lv=Status#player.lv,
																	 batt_value = BattValue,
																	 platform = Platform,
																	 sn = Sn,
																	 grade = Grade,
																	 state = 1,
																	 timestamp = NowTime,
																	 seed=0
																	},
										   ets_update_war2_record(Record),
										   mod_leap_client:war2_sync_player(Status#player.id,Status#player.nickname),
										   [1];
									   [Error]->[Error]
								   end;
							   _->[4]
						   end
					end;
				false->[2]
			end;
		_->[7]
	end.

%%系统自动报名
auto_apply()->
	 Platform = tool:to_binary(config:get_platform_name()),
	 Sn = config:get_server_num(),
	 case ets_select_war2_elimination_by_champion(Platform,Sn) of
		 []->skip;
		 EliInfo->
			 apply_auto(EliInfo,Platform,Sn,util:unixtime())
	 end.

apply_auto([],_Platform,_Sn,_NowTime)->finish;
apply_auto([Eli|EliInfo],Platform,Sn,NowTime)->
	case lib_player:get_role_id_by_name(Eli#ets_war2_elimination.nickname) of
		null->skip;
		PlayerId->
			Data = db_agent:get_player_mult_properties([lv,sex],[PlayerId]),
			case lists:keyfind(PlayerId,1,Data) of
				false->skip;
			   {_1,[Lv,Sex]}->
				   if Eli#ets_war2_elimination.grade == 2  andalso Lv >=70 ->
						  Seed = 0,
						  NewGrade = 1;
					  true->
						  Seed=1,
						  NewGrade = Eli#ets_war2_elimination.grade
				   end,
				   DataApply = [PlayerId,
						   Eli#ets_war2_elimination.nickname,
						   Eli#ets_war2_elimination.career,
						   Sex,Lv,Eli#ets_war2_elimination.batt_value,
						   Platform,Sn,NewGrade,1,NowTime,Seed],
				   {_,Id} = db_agent:insert_war2_record(DataApply),
				   Record = #ets_war2_record{
														  id = Id,
														  pid = PlayerId,
														  nickname = Eli#ets_war2_elimination.nickname,
														  career = Eli#ets_war2_elimination.career,
														  sex = Sex, 
														  lv = Lv,
														  batt_value = Eli#ets_war2_elimination.batt_value,
														  platform = Platform,
														  sn = Sn,
														  grade = NewGrade,
														  state = 1,
														  timestamp = NowTime,
														  seed=Seed
														},
				   ets_update_war2_record(Record),
				   mod_leap_client:war2_sync_player(PlayerId,Eli#ets_war2_elimination.nickname)
			end
	end,
	apply_auto(EliInfo,Platform,Sn,NowTime).
				   

%%检查报名时间
check_apply_time()->
	Week = util:get_date(),
	case lists:member(Week, [7,1]) of
		true->
			NowSec = util:get_today_current_second(),
			if Week ==7->
				   StartSec = 9*3600,
				   StartSec =< NowSec;
			   true->
				   EndSec = 15*3600+0*60,
				  NowSec =< EndSec
			end;
		false->
			false
	end.
%% 	Week = util:get_date(),
%% 	case lists:member(Week, [1,2,3,4,5,6]) of
%% 		true->
%% 			NowSec = util:get_today_current_second(),
%% 			StartSec = 15*3600+0*60,
%% 			EndSec = 15*3600+30*60,
%% %% 			StartSec = 19*3600+35*60,
%% %% 			EndSec = 19*3600+45*60,
%% 			if NowSec >= StartSec andalso NowSec =< EndSec ->true;
%% 			   true->false
%% 			end;
%% 		false->
%% 			false
%% 	end.

check_battvalue(PlayerId,Grade,Batt)->
%% 	[1].
	case Grade of
		1->
			if Batt>= 15000->[1];
			   true->
				   case check_coliseum_rank(PlayerId,5) of
					   true->[1];
					   false->
						   [5]
				   end
			end;
		_->
			if Batt>= 8000->[1];
			   true->
				   case check_coliseum_rank(PlayerId,10) of
					   true->[1];
					   false->
						   [6]
				   end
			end
	end.

%%检查竞技场排名
check_coliseum_rank(PlayerId,Rank)->
	CBag = lib_coliseum:get_coliseum_rank_data(Rank),
	PidBag = [C#ets_coliseum_rank.player_id||C<-CBag],
	lists:member(PlayerId, PidBag).

%%获取分组等级（1天罡，2地煞）
get_grade(Lv)->
	if Lv < 65 -> 2;
	   true->1
	end.

%% 生成玩家替身
create_shadow(PlayerId,SceneId,X, Y) ->
	ChallengePlayer = lib_player:get_player_info(PlayerId),
	{HookConfig, _TimeStart, _TimeLimit, _Timestamp} = lib_hook:get_hook_config(PlayerId),
	SkillList = mod_mon_create:shadow_skill(HookConfig#hook_config.skill_list, ChallengePlayer, []),
	NewChallengerId = round(?MON_LIMIT_NUM / 10) + ChallengePlayer#player.id,
	NewChallengePlayer = ChallengePlayer#player{
												scene = SceneId,
												other = ChallengePlayer#player.other#player_other{
			die_time = util:unixtime()+5
		}										 
	},
	mod_shadow_active:start([NewChallengePlayer, NewChallengerId, X, Y, SkillList]),
	NewChallengerId.

%%更换竞技区场景
change_scene(Player,ScenePid,ResId,SceneId,X,Y)->
	%%告诉原场景的玩家你已经离开
	pp_scene:handle(12004, Player, Player#player.scene),
	NewPlayer = Player#player{
							  scene = SceneId,
							  x=X,
							  y=Y,
							  hp = Player#player.hp_lim,
							  mp = Player#player.mp_lim,
							  other = Player#player.other#player_other{
																	   battle_dict = #battle_dict{},
																	   pid_dungeon = ScenePid
																	  }					
							 },
	put(battle_dict, #battle_dict{}),
	if Player#player.hp < 1->
		   %%复活
		   NewStuats =  lib_scene:revive_to_scene(NewPlayer, 15, battle);
	   true->
		   NewStuats = NewPlayer
	end,
	%% 坐标记录
	put(change_scene_xy, [X, Y]),
	{ok, BinData} = pt_12:write(12005, [SceneId, X, Y, <<>>, ResId, 0, 0, 0]),
	lib_send:send_to_sid(NewStuats#player.other#player_other.pid_send, BinData),
	mod_player:save_online_info_fields(NewStuats, [{scene,SceneId},{x,X},{y,Y},
												   {hp,Player#player.hp_lim},
												   {mp,Player#player.mp_lim},
												   {pid_dungeon, ScenePid},
												   {battle_dict,#battle_dict{}}]),
	lib_player:send_player_attribute(NewStuats, 2),
	%%进入信息区的话，更新个人信息
	case is_wait_scene(SceneId) of
		true->
			ScenePid ! {'FIGHT_INFO',[NewStuats#player.other#player_other.pid,Player#player.id]};
		false->skip
	end,
	%%无敌状态
	NewStatus1 = NewStuats#player{other = NewStuats#player.other#player_other{battle_limit = 9	}},
	erlang:send_after(5000, NewStatus1#player.other#player_other.pid, {'SET_BATTLE_LIMIT', 0}),
	
	NewStatus1.

%%更换竞技区场景(Mark为28则为观战模式)
war2_view_scene(Player,ScenePid,ResId,SceneId,X,Y,Mark)->
	%%告诉原场景的玩家你已经离开
	pp_scene:handle(12004, Player, Player#player.scene),
	NewPlayer = Player#player{
							  scene = SceneId,
							  x=X,
							  y=Y,
							  carry_mark =Mark,
							  hp = Player#player.hp_lim,
							  mp = Player#player.mp_lim,
							  other = Player#player.other#player_other{
																	   war2_scene = [{Player#player.scene,Player#player.other#player_other.pid_dungeon}],
																	   pid_dungeon = ScenePid
																	  }					
							 },
	if Player#player.hp < 1->
		   %%复活
		   NewStuats =  lib_scene:revive_to_scene(NewPlayer, 15, battle);
	   true->
		   NewStuats = NewPlayer
	end,
	%%{'GAME_TIME_VIEW',[PlayerId]}
	%%进入信息区的话，更新个人信息
	case is_wait_scene(SceneId) of
		true->
			ScenePid ! {'FIGHT_INFO',[NewStuats#player.other#player_other.pid,Player#player.id]};
		false->skip
	end,
	%% 坐标记录
	put(change_scene_xy, [X, Y]),
	{ok, BinData} = pt_12:write(12005, [SceneId, X, Y, <<>>, ResId, 0, 0, 0]),
	lib_send:send_to_sid(NewStuats#player.other#player_other.pid_send, BinData),
	mod_player:save_online_info_fields(NewStuats, [{scene,SceneId},{x,X},{y,Y},
												   {hp,Player#player.hp_lim},
												   {mp,Player#player.mp_lim},
												   {carry_mark,Mark},
												   {pid_dungeon, ScenePid},
												   {war2_scene,[{Player#player.scene,Player#player.other#player_other.pid_dungeon}]}]),
	lib_player:send_player_attribute(NewStuats, 2),
	NewStuats.



%%添加玩家出线
tryout(Record,Subarea,Num,Grade,State,Win)->
	Data = [
			Record#ets_war2_record.pid,
			Record#ets_war2_record.nickname,
			Record#ets_war2_record.lv,
			Record#ets_war2_record.career,
			Record#ets_war2_record.sex,
			Record#ets_war2_record.batt_value,
			Record#ets_war2_record.platform,
			Record#ets_war2_record.sn,
			Grade,Subarea,Num,State,Win	],

	{_,Id} = db_agent:insert_war2_elimination(Data),
	NewEli = #ets_war2_elimination{
							   id = Id,
							   pid = Record#ets_war2_record.pid,
							   nickname = Record#ets_war2_record.nickname,
							   lv = Record#ets_war2_record.lv,
							   career = Record#ets_war2_record.career,
							   sex = Record#ets_war2_record.sex,
							   batt_value = Record#ets_war2_record.batt_value,
							   platform = Record#ets_war2_record.platform,
							   sn = Record#ets_war2_record.sn,
							   grade = Grade,
							   subarea = Subarea,
							   num = Num,
							   state = State,
							   elimination = Win
							   },
	ets_update_war2_elimination(NewEli),
	ok.

%%测试代码，添加淘汰赛数据
test_data()->
	clear_war2_elimination(),
	test_data_grade([1,2]),
	init_war2_elimination().

test_data_grade([])->
	ok;
test_data_grade([Grade|GradeBag])->
	test_data_sub([1,2,3,4],Grade),
	test_data_grade(GradeBag).

test_data_sub([],_Grade)->ok;
test_data_sub([Sub|SubBag],Grade)->
	test_data_num([1,2,3,4,5,6,7,8],Grade,Sub),
	test_data_sub(SubBag,Grade).

test_data_num([],_Grade,_Subarea)->ok;
test_data_num([Num|NumBag],Grade,Subarea)->
	PlayerId = tool:random(1, 100000),
	test_elimination_data(PlayerId,50,Grade,Subarea,Num),
	test_data_num(NumBag,Grade,Subarea).

test_elimination_data(PlayerId,Lv,Grade,Subarea,Num)->
	Data = [
			PlayerId,
			"路人甲",
			Lv,
			tool:random(1, 5),
			tool:random(1, 2),
			tool:random(10000, 30000),
			"4399",
			tool:random(1, 34),
			Grade,Subarea,Num,2,1],

	{_,_Id} = db_agent:insert_war2_elimination(Data),
	ok.

%%查询玩家进度状态
player_war2_state(PlayerId,Nickname)->
	Platform = tool:to_binary(config:get_platform_name()),
	 Sn = config:get_server_num(),
	case lib_war2:ets_select_war2_elimination_by_sn(Platform, Sn, tool:to_binary(Nickname)) of
		[]->
			case lib_war2:ets_select_war2_record(PlayerId) of
				[]-> 11;
				[_R]->1
			end;
		[Eli]->
			if Eli#ets_war2_elimination.elimination == 0 andalso Eli#ets_war2_elimination.champion ==0-> 0; 
			   true->
				   if Eli#ets_war2_elimination.champion == 1->
						  7;
					  Eli#ets_war2_elimination.champion == 2->
						  8;
					  Eli#ets_war2_elimination.champion == 3->
						  9;
					  Eli#ets_war2_elimination.champion == 4->
						  10;
					  true->
						  Eli#ets_war2_elimination.state-1
				   end
			end
	end.

%%%同步淘汰赛记录
sync_elimination_data_remote()->
	EliminationBag = db_agent:select_war2_elimination(),
	mod_leap_server:war2_elimination(EliminationBag),
	ok.
%%同步淘汰赛记录到本地
sync_elimination_data_local(EliminationBag)->
	clear_war2_elimination(),
	elimination_record_loop(EliminationBag),
	ok.

%%添加淘汰赛玩家记录到本地
elimination_record_loop([])->
	%%加载新数据
	init_war2_elimination();
elimination_record_loop([Record|RecordBag])->
	War = list_to_tuple([ets_war2_elimination | Record]),
	ValueList = lists:nthtail(2, tuple_to_list(War)),
	[id | FieldList] = record_info(fields, ets_war2_elimination),
	?DB_MODULE:insert(war2_elimination, FieldList, ValueList),
	elimination_record_loop(RecordBag).

elimination_history(Platform,Sn,Name,Info)->
	mod_leap_server:elimination_history(Platform,Sn,Name,Info).


%%个人淘汰赛记录
sync_history_local([_NickName,Data])->
	db_agent:insert_war2_history(Data).

%%同步冠军数据
sync_champion(Data)->
	db_agent:insert_war2_champion(Data),
	mod_leap_server:elimination_champion(Data).

%%同步冠军数据到本地
champion_local(Data)->
	db_agent:insert_war2_champion(Data).

%%发放奖励
war2_award()->
	RecordBag = ets_select_war2_record_all(),
	Platform = tool:to_binary(config:get_platform_name()), 
	Sn = config:get_server_num(),
	award_loop(RecordBag,Platform,Sn),
	ok.

award_loop([],_Platform,_Sn)->
	ok;
award_loop([R|RecordBag],Platform,Sn)->
	{Grade,Rank}= get_grade_and_rank(R,Platform,Sn),
	[Goods,Point] = goods_info(Grade,Rank),
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'war2_award',[R#ets_war2_record.pid,Grade,Rank,Point,Goods]}),
%% 	award(R#ets_war2_record.pid,Grade,Rank,Point,Goods),
	award_loop(RecordBag,Platform,Sn).

award(PlayerId,Grade,Rank,Point,Goods)->
	case lib_war:check_war_award(PlayerId) of
		[]->
			NowTime = util:unixtime(),
			NewGoods = util:term_to_string(Goods),
			{_,Id} = db_agent:new_war_award1(PlayerId,Grade,Rank,Point,NewGoods,NowTime),
			Award = #ets_war_award{id=Id,pid=PlayerId,grade=Grade,rank=Rank,newp=Point,goods=NewGoods,timestamp=NowTime},
			lib_war:update_war_award(Award),
			ok;
		[Award]->
			NewGoods = util:term_to_string(Goods),
			NewAward = Award#ets_war_award{grade=Grade,rank=Rank,newp=Point,goods=NewGoods},
			lib_war:update_war_award(NewAward),
			db_agent:update_war_award([{grade,Grade},{rank,Rank},{newp,Point},{goods,NewGoods}], [{pid,PlayerId}])
	end.

get_grade_and_rank(Record,Platform,Sn)->
	case ets_select_war2_elimination_by_sn(Platform,Sn,tool:to_binary(Record#ets_war2_record.nickname)) of
		[]->{Record#ets_war2_record.grade,8};
		[Eli|_]-> 
			if Eli#ets_war2_elimination.champion == 1 ->
				   {Record#ets_war2_record.grade,1};
			   Eli#ets_war2_elimination.champion == 2 ->
				   {Record#ets_war2_record.grade,2};
			   Eli#ets_war2_elimination.champion == 3 ->
				   {Record#ets_war2_record.grade,3}; 
			   Eli#ets_war2_elimination.champion == 4 ->
				   {Record#ets_war2_record.grade,4};
			   Eli#ets_war2_elimination.state == 5 ->
				   {Record#ets_war2_record.grade,5 };
			   Eli#ets_war2_elimination.state == 4 ->
				   {Record#ets_war2_record.grade, 6};
			   true ->
				   {Record#ets_war2_record.grade,7 }
			end
	end.
		
		
goods_info(Grade,Rank)->
%% 	case Grade of
%% 		1->
%% 			case Rank of
%% 				1->[[{28054,6}],500];
%% 				2->[[{28054,5}],400];
%% 				3->[[{28054,4}],300];
%% 				4->[[{28054,4}],300];
%% 				5->[[{28054,3}],200];
%% 				6->[[{28054,2}],150];
%% 				7->[[{28054,2}],100];
%% 				_8->[[{28054,0}],50]
%% 			end;
%% 		_->
%% 			case Rank of
%% 				1->[[{28054,4}],250];
%% 				2->[[{28054,3}],200];
%% 				3->[[{28054,2}],150];
%% 				4->[[{28054,2}],150];
%% 				5->[[{28054,1}],100];
%% 				6->[[{28054,1}],70];
%% 				7->[[{28054,1}],50];
%% 				_8->[[{28054,0}],20]
%% 			end
%% 	end.
	case Grade of
		1->
			case Rank of
				1->[[{28054,15}],800];
				2->[[{28054,10}],700];
				3->[[{28054,8}],600];
				4->[[{28054,8}],600];
				5->[[{28054,7}],500];
				6->[[{28054,6}],400];
				7->[[{28054,5}],300];
				_8->[[{28054,2}],100]
			end;
		_->
			case Rank of
				1->[[{28054,4}],400];
				2->[[{28054,3}],300];
				3->[[{28054,2}],250];
				4->[[{28054,2}],250];
				5->[[{28054,1}],200];
				6->[[{28054,1}],175];
				7->[[{28054,1}],150];
				_8->[[{28054,0}],50]
			end
	end.

%%查询是否有奖励
check_godos_award(PlayerId)->
	case lib_war:check_war_award(PlayerId) of
		[]->
			case db_agent:select_war_award(PlayerId) of
				[]->0;
				[G]->
					case util:string_to_term(tool:to_list(G)) of
						[]-> 0;
						undefined->0;
						0->0;
						_Goods->1
					end
			end;
		[Award]->
			case util:string_to_term(tool:to_list(Award#ets_war_award.goods)) of
				[]-> 0;
				undefined->0;
				0->0;
				_Goods->1
			end
	end.

%%查询物品奖励信息
check_award_info(Status)->
	Data = 
		case lib_war:check_war_award(Status#player.id) of
			[]->[0,0,0,[]];
			[Award]->
				Goods = 
					case util:string_to_term(tool:to_list(Award#ets_war_award.goods)) of
						[]->[];
						undefined->[];
						0->[];
						G->G
					end,
				[
				 Award#ets_war_award.grade,
				 Award#ets_war_award.rank,
				 Award#ets_war_award.newp,
				 Goods
				]
		end,
	{ok,BinData} = pt_45:write(45114,Data),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).

%%领取奖励
get_goods_award(Status)->
	Res = case lib_war:check_war_award(Status#player.id) of
			  []->[2];
			  [Award]->
				  case Award#ets_war_award.goods of
					  []-> [2];
					  undefined->[2];
					  Goods->
						  NewGoods = util:string_to_term(tool:to_list(Goods)),
						  case gen_server:call(Status#player.other#player_other.pid_goods,
											   {'cell_num'})<length(NewGoods) of
							  true->[4];
							  false->
								  case give_goods(Status,NewGoods) of
									  {ok,_}->
										  Point=Award#ets_war_award.point+Award#ets_war_award.newp,
										  NewAward = Award#ets_war_award{rank=0,grade=0,newp=0,goods=[],point=Point},
										  lib_war:update_war_award(NewAward),
										  spawn(fun()->db_agent:log_war_award(Status#player.id,0,0,1,Award#ets_war_award.newp,util:unixtime())end),
										  db_agent:update_war_award([{rank,0},{grade,0},{newp,0},{goods,util:term_to_string([])},{point,Point}], [{pid,Status#player.id}]),
										  [1];
									  _->[3]
								  end
						  end
				  end
		  end,
	{ok,BinData} = pt_45:write(45108,Res),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).

%%添加奖励物品
give_goods(PlayerStatus,[])->
	{ok,PlayerStatus};
give_goods(PlayerStatus,[Goods|T])->
	{GoodsId,GoodsNum} = Goods,
	if GoodsNum  > 0 ->
		   case catch( gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'give_goods', PlayerStatus, GoodsId, GoodsNum,2}))of
			   ok->
				   spawn(fun()->db_agent:log_war_award(PlayerStatus#player.id,GoodsId,GoodsNum,2,0,util:unixtime())end),
				   give_goods(PlayerStatus,T);
			   _->{error,PlayerStatus}
		   end;
	   true->
		   give_goods(PlayerStatus,T)
	end.

%%查询我的下注
my_bet(Status)->
	Res = case ets_select_war2_bet(Status#player.id) of
			  []->0;
			  _->1
		  end,
	{ok,BinData} = pt_45:write(45109, <<Res:16>>),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).

get_my_bet(PlayerId,IsBet)->
	case IsBet of
		1->
			case ets_select_war2_bet(PlayerId) of
				[]->{1,0,0,0,0};
				[Bet]->
					{0,Bet#ets_war2_bet.bet_id,Bet#ets_war2_bet.grade,Bet#ets_war2_bet.type,Bet#ets_war2_bet.total}
			end;
		_->{0,0,0,0,0}
	end.

%%下注
%%errcode 1下注成功，2不能对该玩家下注，3当前时间不能下注，4您今天已经下注,5绑定铜币不足，6礼券不足,7等级不足30级不能下注
betting(Status,Type,Money,PlayerId,IsBet)->
	Res = 
		if Status#player.lv < 30-> [7,0];
		   true->
			   case check_bet_time(IsBet) of
				   false-> [3,0];
				   true->
					   case is_war2_server() of
						   true-> [2,0];
						   false->
							   case lib_war2:ets_select_war2_elimination(PlayerId) of
								   []->[2,0];
								   [R]->
									   if R#ets_war2_elimination.elimination == 0->[2,0];
										  true->
											  case lib_war2:ets_select_war2_bet(Status#player.id) of
												  []->
													  case check_money(Status,Type,Money) of
														  {error,Error}->Error;
														  {ok,Total,Popular}->
															  Data = [Status#player.id,Status#player.nickname,Type,Total,
																	  R#ets_war2_elimination.state,
																	  R#ets_war2_elimination.nickname,
																	  R#ets_war2_elimination.pid,
																	  R#ets_war2_elimination.platform,
																	  R#ets_war2_elimination.sn,
																	  R#ets_war2_elimination.grade],
															  {_,Id} = db_agent:new_war2_bet(Data),
															  spawn(fun()->db_agent:log_war2_bet([Status#player.id,Type,Total,R#ets_war2_elimination.nickname,R#ets_war2_elimination.state,util:unixtime()])end),
															  Bet = #ets_war2_bet{id=Id,
																				  pid = Status#player.id,
																				  name = Status#player.nickname,
																				  type=Type,
																				  total=Total,
																				  state=R#ets_war2_elimination.state,
																				  nickname=R#ets_war2_elimination.nickname,
																				  bet_id=R#ets_war2_elimination.pid,
																				  platform=R#ets_war2_elimination.platform,
																				  sn=R#ets_war2_elimination.sn,
																				  grade=R#ets_war2_elimination.grade},
															  lib_war2:ets_update_war2_bet(Bet),
															  gen_server:cast(Status#player.other#player_other.pid,{'WAR2_BET',[Type,Total]}),
															  mod_leap_client:bet_popular([PlayerId,Popular]),
															  [1,R#ets_war2_elimination.grade]
													  end;
												  _->[4,0]
											  end
									   end
							   end
					   end
			   end
		end,
	{ok,BinData} = pt_45:write(45110, Res),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).

%%Type:1铜币2礼券
check_money(Status,Type,Money)->
	case Type of
		1->
			{BCoin,Popular} = get_coin(Money),
			case goods_util:is_enough_money(Status, BCoin, bcoin) of
				false->
					{error,[5,0]};
				true->{ok,BCoin,Popular}
			end;
		_->
			{Cash,Popular} = get_cash(Money),
			case goods_util:is_enough_money(Status, Cash, cash) of
				false->
					{error,[6,0]};
				true->{ok,Cash,Popular}
			end
	end.

get_coin(Type)->
	case Type of
		1->{5000,10};
		2->{20000,20};
		_->{50000,30}
	end.
get_cash(Type)->
	case Type of
		1->{10,10};
		2->{30,20};
		_->{50,30}
	end.

check_bet_time(_IsBet)->
%% 	IsBet==1.
	Week = util:get_date(),
	case lists:member(Week,[2,3,4,5,6]) of
		false->false;
		true->
			NowSec = util:get_today_current_second(),
			NowSec =< 15*3600
	end.

%%参赛玩家增加人气
popular_up([PlayerId,Popular])->
	case lib_war2:ets_select_war2_elimination(PlayerId) of
		[]->skip;
		[R]->
			NewPopular = R#ets_war2_elimination.popular+Popular,
			NR = R#ets_war2_elimination{popular=NewPopular},
			lib_war2:ets_update_war2_elimination(NR),
			db_agent:update_war2_elimination([{popular,NewPopular}],[{pid,R#ets_war2_elimination.pid}])
	end.

%%发放下注奖励
bet_provide()->
	BetBag = lib_war2:ets_select_war2_bet_all(),
	provice_loop(BetBag),
	clear_war2_bet().

provice_loop([])->
	ok;
provice_loop([R|BetBag])->
	case lib_war2:ets_select_war2_elimination_by_sn(R#ets_war2_bet.platform, R#ets_war2_bet.sn, R#ets_war2_bet.nickname) of 
		[]->skip;
		[Eli]->
			if Eli#ets_war2_elimination.elimination ==1->
				   bet_win(R);
			   true->
				   bet_failed(R)
			end
	end,
	provice_loop(BetBag).


%% %% 发系统邮件	GoodsBind为0时，发绑定的物品，其他值如1时不绑定
%% send_sys_mail(NameList, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Cash, GoodsBind) ->
%%28023   10000绑铜卡
%%28024 10礼券
bet_win(R)->
	Content = io_lib:format("恭喜，你在封神争霸投注的选手~s获得胜利，获得投注金额翻倍的奖励！",[R#ets_war2_bet.nickname]),
	NameList = [tool:to_list(R#ets_war2_bet.name)],
	case R#ets_war2_bet.type of
		1->
			Num = get_goods_num(R#ets_war2_bet.type,R#ets_war2_bet.total),
			mod_mail:send_sys_mail(NameList, "封神争霸", Content, 0,28023, Num, 0, 0,0);
		_->
			Num = get_goods_num(R#ets_war2_bet.type,R#ets_war2_bet.total),
			mod_mail:send_sys_mail(NameList, "封神争霸", Content, 0,28024, Num, 0, 0,0)
	end,
	ok.

get_goods_num(Type,Total)->
	case Type of
		1-> round(Total*2 div 10000);
		_-> round(Total*2 div 10)
	end.

bet_failed(R)->
	Content = io_lib:format("很遗憾，你在封神争霸投注的选手~s败北，失去所有的投注金额！",[R#ets_war2_bet.nickname]),
	NameList = [tool:to_list(R#ets_war2_bet.name)],
	mod_mail:send_sys_mail(NameList, "封神争霸", Content, 0,0, 0, 0, 0),
	ok.

enter_war2_scene(Status)->
	case catch gen_server:call(mod_war2_supervisor:get_mod_war2_supervisor_pid(), {'SUBAREA_SERVICE',[Status#player.other#player_other.pid,Status#player.id,Status#player.lv]}) of
		{ok,[undefined,undefined]}->
			Status;
		{ok,[Pid,SceneId]}->
			gen_server:cast(Pid, {'GET_FIGHT_INFO',[Status#player.other#player_other.pid,Status#player.id]}),
			Status#player{scene = SceneId,
								x = 22,
								y = 53,
								mount = 0,
								carry_mark = 0,
								hp = Status#player.hp_lim,
								mp = Status#player.mp_lim,
								other = Status#player.other#player_other{pid_dungeon = Pid}};
		_->Status
	end.
%%1进入，2当前时间不能进入，3您没有资格进入,4跑商/运镖状态不能进入，5正在副本类地图中，不能进入
enter_war2(Status)->
	Week = util:get_date(),
	EnterTime = 15*3600+45*60,
	EliTime = 16*3600+30*60,

	NowSec = util:get_today_current_second(),
	Data =
		if Status#player.carry_mark > 0->
			   [4,<<>>,0];
		   true->
			   if Status#player.scene > 500->
					  [5,<<>>,0];
				  true->
					  if Week == 7->[2,<<>>,0];
						 true ->
							 if NowSec < EnterTime orelse NowSec > EliTime -> [2,<<>>,0]; 
								true->
									case lib_war2:ets_select_war2_record(Status#player.id) of
										[]->[3,<<>>,0];
										_->
											case config:get_war_server_info() of
												[]-> [3,<<>>,0];
												[Ip,_,_,Port,_]->
													mod_leap_client:war2_update_player(Status#player.id,Status#player.nickname),
													timer:sleep(5000),
													[1,Ip,Port];
												_->[3,<<>>,0]
											end 
									end
							 end
					  
					  end
			   end
		end,
	{ok,BinData} = pt_45:write(45111,Data),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).

%%查询是否可进入封神争霸
notice_enter_war2(Player)->
%%测试
%% 	NowSec = util:get_today_current_second(),
%% 	%%报名时间
%% 	StartSec = 15*3600,
%% 	EndSec = 15*3600+30*60,
%% %% 	%%进入时间
%% 	Second = 15*3600+45*60,
%% 	Second1 = 16*3600+15*60,
%% %% 	%%报名时间
%% %% 	StartSec = 19*3600+35*60,
%% %% 	EndSec = 19*3600+44*60,
%% %% 	%%进入时间
%% %% 	Second = 19*3600+45*60,
%% %% 	Second1 = 19*3600+55*60,
%% 	
%% 	if 
%% 		NowSec < EndSec andalso NowSec > StartSec -> 
%% 			if Player#player.lv < 50 ->skip;
%% 			   true->
%% 				   BattValue = lib_player:count_value(Player#player.other#player_other.batt_value),
%% 				   Grade = get_grade(Player#player.lv),
%% 				   case check_battvalue(Player#player.id,Grade,BattValue) of
%% 					   [1]->
%% 						   case lib_war2:ets_select_war2_record(Player#player.id) of
%% 							   []->
%% 								   {ok,BinData} = pt_45:write(45116, [2]),
%% 								   lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
%% 							   _->skip
%% 						   end;
%% 					   _->skip
%% 				   end
%% 			end;
%% 		NowSec >Second andalso NowSec < Second1 -> 
%% 			case lib_war2:ets_select_war2_record(Player#player.id) of
%% 				[]->skip;
%% 				_->
%% 					{ok,BinData} = pt_45:write(45116, [1]),
%% 					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
%% 			end;
%% 		true->
%% 			skip
	%% 	end.

	%%正式版
	Week = util:get_date(),
	Second = 15*3600+45*60,
	Second1 = 16*3600,
	NowSec = util:get_today_current_second(),
	if Week == 7 -> 
		   StartSec = 9*3600,
		   if 
			   NowSec > StartSec  -> 
				   if Player#player.lv < 55 ->skip;
					  true->
						  BattValue = lib_player:count_value(Player#player.other#player_other.batt_value),
						  Grade = get_grade(Player#player.lv),
						  case check_battvalue(Player#player.id,Grade,BattValue) of
							  [1]->
								  case lib_war2:ets_select_war2_record(Player#player.id) of
									  []->
										  {ok,BinData} = pt_45:write(45116, [2]),
										  lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
									  _->skip
								  end;
							  _->skip
						  end
				   end;
			   true->skip
		   end;
	   Week == 1 ->
		   EndSec = 15*3600+0*60,
		   if 
			   NowSec < EndSec  -> 
				   if Player#player.lv < 55 ->skip;
					  true->
						  BattValue = lib_player:count_value(Player#player.other#player_other.batt_value),
						  Grade = get_grade(Player#player.lv),
						  case check_battvalue(Player#player.id,Grade,BattValue) of
							  [1]->
								  case lib_war2:ets_select_war2_record(Player#player.id) of
									  []->
										  {ok,BinData} = pt_45:write(45116, [2]),
										  lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
									  _->skip
								  end;
							  _->skip
						  end
				   end;
			   NowSec > Second andalso NowSec < Second1->
				   case lib_war2:ets_select_war2_record(Player#player.id) of
					   []->skip;
					  _->
						  {ok,BinData} = pt_45:write(45116, [1]),
						  lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
				  end;
			   true->skip
		   end;
	   true->
		   if NowSec < Second orelse NowSec > Second1 -> skip;
			  true->
				  Platform = tool:to_binary(config:get_platform_name()),
				  Sn = config:get_server_num(),
				  case lib_war2:ets_select_war2_elimination_by_sn(Platform, Sn, tool:to_binary(Player#player.nickname)) of
					  []->skip;
					  [E]->
						  if E#ets_war2_elimination.elimination /= 1->skip;
							 true->
								 {ok,BinData} = pt_45:write(45116, [1]),
								 lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
						  end
				  end
		   end
	end.

%%
notice_enter_war2_all()->
%%测试
%% 	Second = 15*3600+45*60,
%% 	Second1 = 16*3600,
%% %% 	Second = 19*3600+49*60,
%% %% 	Second1 = 19*3600+55*60,
%% 	NowSec = util:get_today_current_second(),
%% 	if NowSec < Second orelse NowSec > Second1 -> skip;
%% 	   true->
%% 		   {ok,BinData} = pt_45:write(45116, [1]),
%% 		   RecordBag = lib_war2:ets_select_war2_record_all(),
%% 		   [lib_send:send_to_uid(R#ets_war2_record.pid, BinData)||R<-RecordBag]
%% 	end.
		    
%%正式版
	Week = util:get_date(),
	Second = 15*3600+45*60,
	Second1 = 16*3600,
	NowSec = util:get_today_current_second(),
	if Week == 7 -> skip;
	   Week == 1 ->
		    if NowSec < Second orelse NowSec > Second1 -> skip;
			  true->
				  {ok,BinData} = pt_45:write(45116, [1]),
				  RecordBag = lib_war2:ets_select_war2_record_all(),
				  [lib_send:send_to_uid(R#ets_war2_record.pid, BinData)||R<-RecordBag]
			end;
	   true->
		    if NowSec < Second orelse NowSec > Second1 -> skip;
			  true->
				  Platform = tool:to_binary(config:get_platform_name()),
				  Sn = config:get_server_num(),
				  {ok,BinData} = pt_45:write(45116, [1]),
				  RecordBag = lib_war2:ets_select_war2_record_all(),
				  [notice_enter_elimination(Platform,Sn,Record,BinData)||Record<-RecordBag]
			end
	end.

notice_enter_elimination(Platform,Sn,Record,BinData)->
	case lib_war2:ets_select_war2_elimination_by_sn(Platform, Sn, tool:to_binary(Record#ets_war2_record.nickname)) of
		[]->skip;
		[E]->
			if E#ets_war2_elimination.elimination /= 1->skip;
			   true->
				   {ok,BinData} = pt_45:write(45116, [1]),
				   lib_send:send_to_uid(Record#ets_war2_record.pid, BinData)
			end
	end.

%%查看个人历史记录
get_history(Status,State)->
	%% 	State = lib_war2:player_war2_state(Status#player.id,Status#player.nickname),
	History = lib_war2:ets_select_war2_history(Status#player.id),
	{ok,BinData} = pt_45:write(45107, [State,History]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).


%%加载封神争霸功勋值
init_war_honor(Status)->
	case db_agent:select_war_honor(Status#player.id) of
		[]-> Status;
		[undefined]->
			Status;
		[Honor] ->
			NewHonor = util:string_to_term(tool:to_list(Honor)),
			Attribute = count_war_honor_attribute(NewHonor),
			Status#player{other = Status#player.other#player_other{war_honor = NewHonor,war_honor_value=Attribute}}
	end.

%%增加封神争霸功勋值
add_war_honor(Status,Honor)->
	HonorBag = Status#player.other#player_other.war_honor,
	[HonorUse,HonorRift,HonorCul,HonorSpt,HonorPet] = HonorBag,
	NewHonorBag = [HonorUse+Honor,HonorRift,HonorCul,HonorSpt,HonorPet],
	NewStatus = Status#player{other = Status#player.other#player_other{war_honor = NewHonorBag}},
	db_agent:update_war_honor(Status#player.id, util:term_to_string(NewHonorBag)),
	NewStatus1 = lib_player:count_player_attribute(NewStatus),
	mod_player:save_online_info_fields(NewStatus1, [{war_honor,NewHonorBag}]),
	lib_player:send_player_attribute(NewStatus1, 2),
	NewStatus1.

%%使用封神争霸功勋值（加点）(1升级成功，2加点的属性不存在，3当前霸主经验不足升级，4已经满级)
use_war_honor(Status,Type)->
	case lists:member(Type, [1,2,3,4]) of
		false->{error,2};
		true->
			HonorBag = Status#player.other#player_other.war_honor,
			[HonorUse,HonorRift,HonorCul,HonorSpt,HonorPet] = HonorBag,
			case calc_honor_nextlv(HonorBag,Type) of
				{error,Error}->{error,Error};
				{ok,Honor}->
				   NewHonorBag = 
					   case Type of
						   1->[HonorUse-Honor,HonorRift+Honor,HonorCul,HonorSpt,HonorPet];
						   2->[HonorUse-Honor,HonorRift,HonorCul+Honor,HonorSpt,HonorPet];
						   3->[HonorUse-Honor,HonorRift,HonorCul,HonorSpt+Honor,HonorPet];
						   _4->[HonorUse-Honor,HonorRift,HonorCul,HonorSpt,HonorPet+Honor]
					   end,
				   Attribute = count_war_honor_attribute(NewHonorBag),
				   NewStatus = Status#player{other = Status#player.other#player_other{war_honor = NewHonorBag,war_honor_value=Attribute}},
				   db_agent:update_war_honor(Status#player.id, util:term_to_string(NewHonorBag)),
				   NewStatus1 = lib_player:count_player_attribute(NewStatus),
				   lib_player:send_player_attribute(NewStatus1, 2),
				   {NewStatus1,1}
			end
	end.

%%计算点数是否可升级
calc_honor_nextlv([HonorUse,HonorRift,HonorCul,HonorSpt,HonorPet],Type)->
	case Type of
		1->
			%%抗性穿透
			case next_lv(rift,HonorRift) of
				max->{error,4};
				H->
					case HonorUse >= H of
						false->{error,3};
						true->{ok,H}
					end
			end;
		2->
			%%修为加成
			case next_lv(cul,HonorCul) of
				max->{error,4};
				H->
					case HonorUse >= H of
						false->{error,3};
						true->{ok,H}
					end
			end;
		3->
			%%灵力加成
			case next_lv(spt,HonorSpt) of
				max->{error,4};
				H->
					case HonorUse >= H of
						false->{error,3};
						true->{ok,H}
					end
			end;
		_4->
			%%灵兽经验加成
			case next_lv(pet,HonorPet) of
				max->{error,4};
				H->
					case HonorUse >= H of
						false->{error,3};
						true->{ok,H}
					end
			end
	end.

%%获取下一级点数
next_lv(rift,HonorRift)->
	if HonorRift < 10 -> 10-HonorRift;
	   HonorRift < 30 -> 30-HonorRift;
	   HonorRift < 70 -> 70-HonorRift;
	   HonorRift < 130 -> 130-HonorRift;
	   HonorRift < 230 -> 230-HonorRift;
	   true->max
	end;
next_lv(cul,HonorCul)->
	if HonorCul < 8-> 8-HonorCul;
	   HonorCul < 24 -> 24-HonorCul;
	   HonorCul < 54 -> 54-HonorCul;
	   HonorCul < 104 -> 104-HonorCul;
	   HonorCul < 184 -> 184-HonorCul;
	   true->max
	end;
next_lv(spt,HonorSpt)->
	if HonorSpt < 8-> 8-HonorSpt;
	   HonorSpt < 24 -> 24-HonorSpt;
	   HonorSpt < 54 -> 54-HonorSpt;
	   HonorSpt < 104 -> 104-HonorSpt;
	   HonorSpt < 184 -> 184-HonorSpt;
	   true->max
	end;
next_lv(pet,HonorPet)->
	if HonorPet < 8-> 8-HonorPet;
	   HonorPet < 24 -> 24-HonorPet;
	   HonorPet < 54 -> 54-HonorPet;
	   HonorPet < 104 -> 104-HonorPet;
	   HonorPet < 184 -> 184-HonorPet;
	   true->max
	end.

%%计算封神争霸功勋属性[抗性穿透（百分比）,修为加成，灵力加成，灵兽经验加成]
count_war_honor_attribute([_HonorUse,HonorRift,HonorCul,HonorSpt,HonorPet])->
	Rift =
		if HonorRift < 10 ->0;
		   HonorRift < 30 -> 1;
		   HonorRift < 70 -> 2;
		   HonorRift < 130 -> 3;
		   HonorRift < 230 -> 4;
		   true->5
		end,
	Cul = 
		if HonorCul < 8-> 0;
		   HonorCul < 24 -> 0.02;
		   HonorCul < 54 -> 0.04;
		   HonorCul < 104 -> 0.06;
		   HonorCul < 184 -> 0.08;
		   true->0.1
		end,
	Spt = 
		if HonorSpt < 8-> 0;
		   HonorSpt < 24 -> 0.02;
		   HonorSpt < 54 -> 0.04;
		   HonorSpt < 104 -> 0.06;
		   HonorSpt < 184 -> 0.08;
		   true->0.1
		end,
	Pet = 
		if HonorPet < 8-> 0;
		   HonorPet < 24 -> 0.02;
		   HonorPet < 54 -> 0.04;
		   HonorPet < 104 -> 0.06;
		   HonorPet < 184 -> 0.08;
		   true->0.1
		end,
	[Rift,Cul,Spt,Pet].

war2_pape_to_remote([Grade,State,PidA,PidB,Round,Winner])->
	war2_pape_to_local([Grade,State,PidA,PidB,Round,Winner]),
	mod_leap_server:sync_war2_pape([Grade,State,PidA,PidB,Round,Winner]).

%%添加新战报到本地
war2_pape_to_local([Grade,State,PidA,PidB,Round,Winner])->
	Data  = #ets_war2_pape{
						   grade=Grade,
						   state=State,
						   pid_a=PidA,
						   pid_b=PidB,
						   round=Round,
						   winner=Winner
						  },
	{_,Id} = db_agent:new_war2_pape(Data),
	NewData = Data#ets_war2_pape{id=Id},
	ets:insert(?ETS_WAR2_PAPE, NewData),
	ok.

%%查询战报
check_war2_pape(Status,Grade,State,PidA,PidB)->
	InfoA = get_war2_pape_info(PidA),
	InfoB = get_war2_pape_info(PidB),
	InfoPage = 
		case lib_war2:ets_select_war2_pape(Grade, State, PidA) of
		[]->
			[];
		Pape->
			[{P#ets_war2_pape.round,P#ets_war2_pape.winner}||P<-Pape]
	end,
	{ok,BinData} = pt_45:write(45119, [InfoA,InfoB,InfoPage]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok.

%%获取玩家信息
get_war2_pape_info(Pid)->
	case lib_war2:ets_select_war2_elimination(Pid) of
		[]->{<<>>,<<>>,0,0,0};
		[Eli]->
			{Eli#ets_war2_elimination.nickname,
			 Eli#ets_war2_elimination.platform,
			 Eli#ets_war2_elimination.sn,
			 Eli#ets_war2_elimination.career,
			 Eli#ets_war2_elimination.sex
			 }
	end.

%%玩家选择观战(1选择观战成功，请等待比赛开始，2您已经选择了观战的场次，3该玩家已经被淘汰，不能选择，4该玩家没有比赛安排，不能选择；5该场次比赛未开放观战选择)
				%%6非封神争霸专服不能选择观战,7只能选择观战淘汰赛比赛,8您有比赛任务，不能观战
choice_view(Status,State,MemberView,FightId)->
	Res = 
		case lists:keyfind(Status#player.id, 1, MemberView) of
			false->
				case lib_war2:ets_select_war2_elimination(FightId) of
					[]->[4];
					[Eli]->
						if Eli#ets_war2_elimination.elimination /= 1->[3];
						   true->
							   if Eli#ets_war2_elimination.state /= State->
									  [5];
								  true->
									  case is_fighter(Status#player.id) of
										  false->
											  [1];
										  true->
											  [8]
									  end
							   end
						end
				end;
			_->[2]
		end,
	{ok,BinData} = pt_45:write(45120, Res),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	case Res of
		[1]->true;
		_->false
	end.

is_fighter(PlayerId)->
	case lib_war2:ets_select_war2_elimination(PlayerId) of
		[]->false;
		[Eli]->
			Eli#ets_war2_elimination.elimination == 1
	end.

cmd_get_fighter()->
	fighter_loop([1,2]).

fighter_loop([])->ok;
fighter_loop([Grade|GradeBag])->
	loop_fighter(Grade),
	fighter_loop(GradeBag).

loop_fighter(Grade)->
	[loop_eli(Subarea,Grade)||Subarea<-[1,2,3,4]],
	ok.

loop_eli(Subarea,Grade)->
%% 	tryout(Record,Subarea,Num,Grade,State,Win)
	FightBag=?DB_MODULE:select_all(war2_record,"*",[{grade,Grade},{subarea,Subarea}],[{batt_value,desc}],[8]),
	insert_eli(FightBag,Subarea,Grade,1),
	ok.

insert_eli([],_Subarea,_Grade,_Num)->skip;
insert_eli([Data|DataBag],Subarea,Grade,Num)->
	EtsData = list_to_tuple([ets_war2_record] ++ Data),
	tryout(EtsData,Subarea,Num,Grade,3,1),
	insert_eli(DataBag,Subarea,Grade,Num+1).

delwith_merge_data([],_Platform,_Sn)->skip;
delwith_merge_data([S|SnList],Platform,Sn)->
	if S == Sn ->skip;
	   true->
		   RecordBag = ets:match_object(?ETS_WAR2_RECORD, #ets_war2_record{platform=Platform,sn=S,_='_'}),
		   merge_data_record(RecordBag,Sn),
		   EliBag = ets:match_object(?ETS_WAR2_ELIMINATION,#ets_war2_elimination{platform=Platform,sn=S,_='_'}),
		   merge_data_eli(EliBag,Sn),
		   ok
	   end,
	delwith_merge_data(SnList,Platform,Sn).

merge_data_record([],_Sn)->skip;
merge_data_record([Record|RecordBag],Sn)->
	NewRecord = Record#ets_war2_record{sn=Sn},
	lib_war2:ets_update_war2_record(NewRecord),
	db_agent:update_war2_record([{sn,Sn}], [{pid,NewRecord#ets_war2_record.pid}]),
	merge_data_record(RecordBag,Sn).


merge_data_eli([],_Sn)->skip;
merge_data_eli([Eli|EliBag],Sn)->
	NewEli = Eli#ets_war2_elimination{sn=Sn},
	lib_war2:ets_update_war2_elimination(NewEli),
	db_agent:update_war2_elimination([{sn,Sn}], [{pid,NewEli#ets_war2_elimination.pid}]),
	merge_data_eli(EliBag,Sn).

fix_player_id()->
	EliBag = lib_war2:ets_select_war2_elimination_all(),
	fix_loop(EliBag),
	ok.

fix_loop([])->skip;
fix_loop([Eli|EliBag])->
	case ets_select_war2_record_by_name(Eli#ets_war2_elimination.platform,Eli#ets_war2_elimination.sn,Eli#ets_war2_elimination.nickname) of
		[]->skip;
		[R]->
			NewEli = Eli#ets_war2_elimination{pid=R#ets_war2_record.pid},
			lib_war2:ets_update_war2_elimination(NewEli),
			db_agent:update_war2_elimination([{pid,R#ets_war2_record.pid}], [{id,Eli#ets_war2_elimination.id}])
	end,
	fix_loop(EliBag).