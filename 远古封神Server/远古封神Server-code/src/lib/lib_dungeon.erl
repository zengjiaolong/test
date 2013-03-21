%%%-----------------------------------
%%% @Module  : lib_scene
%%% @Author  : ygfs
%%% @Created : 2011.07.14
%%% @Description: 副本信息
%%%-----------------------------------
-module(lib_dungeon).

-export([
	check_dungeon_times/3,
	get_dungeon_times_list/5,
	get_dungeon_times/3,
	add_dungeon_times/2,
	offline/1,
	check_enter_dungeon_requirement/1,
	set_team_pid/2
]).

-include("common.hrl").
-include("record.hrl").
-include("hot_spring.hrl").

%%ETS
update_dungeon(DungeonInfo)->
	ets:insert(?ETS_DUNGEON, DungeonInfo).

select_dungeon(PlayerId,SceneId)->
	ets:match_object(?ETS_DUNGEON, #ets_dungeon{player_id={PlayerId,SceneId},_='_'}).

delete_dungeon(PlayerId,SceneId)->
	ets:match_delete(?ETS_DUNGEON, #ets_dungeon{player_id={PlayerId,SceneId},_='_'}).

%% 检查进入副本场景次数限制 不自动递增次数,成功进入再增加
check_dungeon_times(PlayerId, SceneId, MaxTimes) ->
	[S, M, Counter] = 
		case select_dungeon(PlayerId,SceneId) of
			[]->
				case db_agent:get_log_dungeon(PlayerId,SceneId) of
					[]->
						[0,0,0];
					LogInfo ->
						LogDungeon = list_to_tuple([ets_dungeon | LogInfo]),
						NewLogDungeon = LogDungeon#ets_dungeon{player_id={PlayerId,SceneId}},
						update_dungeon(NewLogDungeon),
						[
							LogDungeon#ets_dungeon.first_dungeon_time rem 1000000,
							util:floor(LogDungeon#ets_dungeon.first_dungeon_time / 1000000),
							LogDungeon#ets_dungeon.dungeon_counter
						]
				end;
			[Dungeon]->
				[
				 Dungeon#ets_dungeon.first_dungeon_time rem 1000000,
				 util:floor(Dungeon#ets_dungeon.first_dungeon_time / 1000000),
				 Dungeon#ets_dungeon.dungeon_counter
				 ]
		end,
						
	Type =
		case SceneId of
			998 ->
				tds;
			999 ->
				tdm;
			Val when Val > 1000 andalso  Val =< 1045->
				fst;
			Val when Val > 1045->
				zxt;
			_ ->
				tool:to_atom("fb_" ++ tool:to_list(SceneId))
		end,
	
	T1 = misc:date_format({M, S, 0}),
	T2 = misc:date_format(now()),
	NowTime = util:unixtime(),
	if 
		T1 =/= T2 -> %%不同一天 ，数据重置
			if 
				%%上面设置00表示没有数据，需插入一条新纪录
				S =:= 0, M =:= 0 ->
					NewDungeon = #ets_dungeon{player_id={PlayerId,SceneId},dungeon_id=SceneId,first_dungeon_time=NowTime,dungeon_counter=0},
					update_dungeon(NewDungeon),
				   	spawn(fun()-> db_agent:insert_log_dungeon(PlayerId, SceneId,NowTime, 0) end);
			   	true ->
					NewDungeon = #ets_dungeon{player_id={PlayerId,SceneId},dungeon_id=SceneId,dungeon_counter=0},
					update_dungeon(NewDungeon)
			end,
			spawn(fun()->db_agent:update_join_data(PlayerId, Type)end),
			{pass, 0};
		true ->  %%同一天
			if 
				Counter < MaxTimes ->
				 	{pass, Counter};
				
			   	true ->
				 	{fail,Counter}
			end
	end.

%%增加进入副本次数 返回增加后的次数
add_dungeon_times(PlayerId, SceneId) ->
	NowTime = util:unixtime(),
	case select_dungeon(PlayerId,SceneId) of
		[] -> %%如果先check 的情况下，不会为空
			case db_agent:get_log_dungeon(PlayerId,SceneId) of
					[]->
						spawn(fun()-> db_agent:insert_log_dungeon(PlayerId, SceneId,NowTime, 1) end),
						spawn(fun()->db_agent:log_dungeon_times(PlayerId,SceneId,NowTime)end),
						1;
					LogInfo ->
						LogDungeon = list_to_tuple([ets_dungeon | LogInfo]),
						NewCounter = LogDungeon#ets_dungeon.dungeon_counter + 1 ,
						NewLogDungeon = LogDungeon#ets_dungeon{player_id={PlayerId,SceneId},first_dungeon_time=NowTime,dungeon_counter=NewCounter},
						update_dungeon(NewLogDungeon),
						spawn(fun()-> db_agent:update_log_dungeon(PlayerId, SceneId, NowTime, NewCounter) end),
						if NewCounter =< 3->
							   spawn(fun()->db_agent:log_dungeon_times(PlayerId,SceneId,NowTime)end);
						   true->skip
						end,
						NewCounter
			end;
		[Dungeon] ->
			NewCounter = Dungeon#ets_dungeon.dungeon_counter + 1 ,
			NewDungeon = Dungeon#ets_dungeon{player_id={PlayerId,SceneId},first_dungeon_time=NowTime,dungeon_counter=NewCounter},
			update_dungeon(NewDungeon),
			spawn(fun()-> db_agent:update_log_dungeon(PlayerId, SceneId, NowTime, NewCounter) end),
			if NewCounter =< 3->
				   spawn(fun()->db_agent:log_dungeon_times(PlayerId,SceneId,NowTime)end);
			   true->skip
			end,
			NewCounter
	end.

%%获取进入副本次数
get_dungeon_times(PlayerId,Lv, Dungeon_id) ->
	case Lv >= get_lv(Dungeon_id) of
		false->0;
		true->
			case select_dungeon(PlayerId,Dungeon_id) of
				[]->
					case db_agent:get_log_dungeon(PlayerId, Dungeon_id) of
						[] -> 
							0;
						LogInfo -> 
							Log_dungeon = list_to_tuple([ets_dungeon] ++ LogInfo),
							S = Log_dungeon#ets_dungeon.first_dungeon_time rem 1000000,
							M = util:floor(Log_dungeon#ets_dungeon.first_dungeon_time / 1000000),
							T1 = misc:date_format({M, S, 0}),
							T2 = misc:date_format(now()),
							if T1 =/= T2 ->
								   NewDungeon = Log_dungeon#ets_dungeon{player_id={PlayerId,Dungeon_id},dungeon_counter=0},
								   update_dungeon(NewDungeon),
								   0;
								true->
									NewLogDungeon = Log_dungeon#ets_dungeon{player_id={PlayerId,Dungeon_id}},
									update_dungeon(NewLogDungeon),
									Log_dungeon#ets_dungeon.dungeon_counter
						end	
					end;
				[Dungeon]->
					Dungeon#ets_dungeon.dungeon_counter
			end
	end.

get_dungeon_times_list(_PlayerId,_Lv,[],_VIPTimes,DungeonInfo)-> 
	{ok,DungeonInfo};
get_dungeon_times_list(PlayerId,Lv,[DungeonId|DungeonList],VIPTimes,DungeonInfo)->
	Times = get_dungeon_times(PlayerId,Lv,DungeonId),
	Info = {DungeonId,Times,VIPTimes+lib_scene:get_dungeon_base_times(DungeonId)},
	get_dungeon_times_list(PlayerId,Lv,DungeonList,VIPTimes,[Info|DungeonInfo]).


offline(PlayerId)->
	DungeonList = data_scene:common_dungeon_get_id_list(),
	SceneList = [998,999,1001,1046 | DungeonList],
	[delete_dungeon(PlayerId,SceneId) || SceneId<-SceneList].

get_lv(SceneId)->
	case SceneId of
		911 -> 25;
		920 -> 35;
		930 -> 45;
		940 -> 55;
		950 -> 65;
		961 -> 70;
		998 -> 33;
		999 -> 40;
		1001 -> 35;
		1046 -> 55;
		901 -> 33;
		_->1
	end.

%% 检查进入副本的条件
check_enter_dungeon_requirement(Player) ->
	if 
		Player#player.arena > 0 ->
			{false, 0, 0, 0, <<"战场状态不能进入副本！">>, 0, []};
		Player#player.carry_mark > 0 andalso Player#player.carry_mark < 4 orelse (Player#player.carry_mark >= 20 andalso Player#player.carry_mark < 26 )->
			{false, 0, 0, 0, <<"运镖状态不能进入副本！">>, 0, []};
		Player#player.carry_mark >3 andalso Player#player.carry_mark<8->
			{false, 0, 0, 0, <<"跑商状态不能进入副本！">>, 0, []};
		Player#player.evil >= 450 ->
			{false, 0, 0, 0, <<"您处于红名状态，不能进入副本!">>, 0, []};
		Player#player.scene =:= ?SPRING_SCENE_VIPTOP_ID ->
			{false, 0, 0, 0, <<"在温泉中，不能进入副本">>, 0, []};
		true ->
			true	
	end.

%% 设置副本的TeamPid
set_team_pid(DungeonPid, TeamPid) ->
    case is_pid(DungeonPid) of
   		false -> 
			false;
   		true -> 
			DungeonPid ! {set_team, TeamPid}
    end.
