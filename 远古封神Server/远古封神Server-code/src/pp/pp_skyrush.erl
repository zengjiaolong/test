%% Author: Xianrong.Mai
%% Created: 2011-4-12
%% Description: 神岛空战的场景处理
-module(pp_skyrush).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include("guild_info.hrl").
%%
%% Exported Functions
%%
-export([handle/3]).

%%
%% API Functions
%%
%% -----------------------------------------------------------------
%% 39001 查看已报名氏族
%% -----------------------------------------------------------------
handle(39001, Status, []) ->
	Result = mod_skyrush:get_applied_guilds(),
	{ok, BinData} = pt_39:write(39001, [Result]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;

%% -----------------------------------------------------------------
%% 39002 报名空岛神战
%% -----------------------------------------------------------------
handle(39002, Status, []) ->
	if
		Status#player.guild_position >= 4 ->%%没权限
			Result = 5;
		Status#player.guild_id =:= 0 ->%%没氏族
			Result = 0;
		true ->
			Result = mod_skyrush:apply_skyrush(Status)
	end,
	{ok, BinData} = pt_39:write(39002, [Result]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;

%% -----------------------------------------------------------------
%% 39003 进入空岛神战
%% -----------------------------------------------------------------
handle(39003, Status, []) ->
	{Result, NewStatus} = mod_skyrush:enter_sky_scene(Status),
	{ok, BinData} = pt_39:write(39003, [Result]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	case Result of
		1 ->
			%% 玩家卸下坐骑
%% 			{ok, MountPlayerStatus}=lib_goods:force_off_mount(NewStatus),
%% 			{ok, MountPlayerStatus};
			{ok, change_ets_table, NewStatus};
		_ ->
			ok
	end;

%% -----------------------------------------------------------------
%% 39004 离开空岛神战
%% -----------------------------------------------------------------
handle(39004, Status, [Type]) ->
	Result = lib_skyrush:check_quit_skyscene(Status),
%% 	Result = 1,
	case Result of
		1 ->%%进入氏族领地
			case Status#player.carry_mark >= 8 andalso Status#player.carry_mark =< 17 of
				true ->%%有魔核或者旗,采集中或占据中
					gen_server:cast(Status#player.other#player_other.pid_scene, 
									{'PLAYER_LOGOUT_SKY', Status#player.carry_mark, 
									 Status#player.id}),
					db_agent:mm_update_player_info([{carry_mark, 0}],[{id, Status#player.id}]),
					StatusCarry = Status#player{carry_mark = 0,
												other = Status#player.other#player_other{leader = 0}};
				false ->
					StatusCarry = Status#player{other = Status#player.other#player_other{leader = 0}}
			end,
			{ok, NewStatus} = lib_guild_manor:enter_manor_scene_39sky(StatusCarry, 500),
			%%通知所有玩家
			{ok, BinData2} = pt_12:write(12041, [NewStatus#player.id, NewStatus#player.carry_mark]),
			mod_scene_agent:send_to_area_scene(NewStatus#player.scene, NewStatus#player.x, NewStatus#player.y, BinData2),
			%%专门发给自己
			lib_send:send_to_sid(NewStatus#player.other#player_other.pid_send, BinData2),
			case Type of
				0 ->%%其他时间段的离开
					skip;
				1 ->
					LeaveTime = util:get_today_current_second(),
					%%配置表
					[_WeekDate, _SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = lib_skyrush:get_start_end_time(),
					case LeaveTime >= SKY_RUSH_END_TIME - 10 andalso LeaveTime =< SKY_RUSH_END_TIME + 120000 of
						true ->%%是在结束后才离开的，在这里添加任务完成接口
							lib_task:event(guild_war, null, NewStatus);
						false ->%%乱发数据，屏蔽
							skip
					end;
				_ ->%%%%乱发数据，无视
					skip
			end,
			NewStatus1 = NewStatus#player{other = NewStatus#player.other#player_other{leader = 0}},
			{ok, BinData} = pt_39:write(39004, [Result]),
			lib_send:send_to_sid(NewStatus1#player.other#player_other.pid_send, BinData),
			%%跑速变回去
			ResetPlayer = lib_player:count_player_speed(NewStatus1),
			lib_player:send_player_attribute(ResetPlayer, 1),
%% 			?DEBUG("reset speed:Id:~p, NewSpeed:~p, OldSpeed:~p", [ResetPlayer#player.id, ResetPlayer#player.speed, NewStatus1#player.speed]),
			{ok, ResetPlayer};
		_ ->
			{ok, BinData} = pt_39:write(39004, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok
	end;

%% -----------------------------------------------------------------
%% 39007 战场信息
%% -----------------------------------------------------------------
handle(39007, Status, []) ->
	lib_skyrush:get_sky_info(Status),
	ok;
%% -----------------------------------------------------------------
%% 39008 开旗
%% -----------------------------------------------------------------
handle(39008, Status, [Area]) ->
	%%结束战斗,屏蔽消息
	NowSec = util:get_today_current_second(),
	[_WeekDate, SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = lib_skyrush:get_start_end_time(),
	case NowSec >= SKY_RUSH_START_TIME + 5*60 andalso NowSec =< SKY_RUSH_END_TIME of
		true  ->
	Result = if 
		Status#player.carry_mark >= 8 andalso Status#player.carry_mark =<  11 ->
			2;
		Status#player.carry_mark >= 12 andalso Status#player.carry_mark =<  15 ->
			3;
		Area >= 1 andalso Area =< 3 ->
			[X, Y] = lib_skyrush:get_flags_coord(Area),
			AbX = abs(Status#player.x - X),
			AbY = abs(Status#player.y - Y),
%%			?DEBUG("THE COORD ARE FLAG:{~p,~p},player:{~p,~p}",[X, Y, Status#player.x,Status#player.y]),
			case AbX =< ?COORD_DIST_LIMIT andalso AbY =< ?COORD_DIST_LIMIT of
				true ->
					case Area of
						1 ->
							case catch (gen_server:call(Status#player.other#player_other.pid_scene, 
														{'ONE_GET_AREA_FLAG', Status#player.id})) of
								{ok, GetResult} ->
									GetResult;
								_Error ->
									0
							end;
						2 ->
							case catch (gen_server:call(Status#player.other#player_other.pid_scene, 
														{'TWO_GET_AREA_FLAG', Status#player.id})) of
								{ok, GetResult} ->
									GetResult;
								_Error ->
									0
							end;
						3 ->
							case catch (gen_server:call(Status#player.other#player_other.pid_scene, 
														{'THREE_GET_AREA_FLAG', Status#player.id})) of
								{ok, GetResult} ->
									GetResult;
								_Error ->
									0
							end
					end;
				false ->
					4
			end
			 end,
	case Result of
		1 ->
			{ok, BinData} = pt_39:write(39008, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			NewStatus = Status#player{carry_mark = 16},
			%% 玩家卸下坐骑
			{ok, MountPlayerStatus}= lib_goods:force_off_mount(NewStatus),
			%通知场景附近所有玩家
			{ok,BinData12041} = pt_12:write(12041, [MountPlayerStatus#player.id, MountPlayerStatus#player.carry_mark]),
			mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID,MountPlayerStatus#player.x, MountPlayerStatus#player.y, BinData12041),
			{ok, MountPlayerStatus};
		_ ->
			{ok, BinData} = pt_39:write(39008, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok
	end;
		false ->
			{ok, BinData} = pt_39:write(39008, [0]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok
	end;
	
			
%% -----------------------------------------------------------------
%% 39011 交战旗或魔核
%% -----------------------------------------------------------------
handle(39011, Status, [FeatsType, Color, Point]) ->
%% 	io:format("FeatsType:~p, Color:~p, Point:~p\n", [FeatsType, Color, Point]),
	%%结束战斗,屏蔽消息
	NowSec = util:get_today_current_second(),
	[_WeekDate, SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = lib_skyrush:get_start_end_time(),
	case NowSec >= SKY_RUSH_START_TIME + 5*60 andalso NowSec =< SKY_RUSH_END_TIME of
		true  ->
	{Result, NewStatus} = mod_skyrush:submit_feats(Status, FeatsType, Color, Point),
%% 	io:format("39011--Result:~p\n", [Result]),
	case Result of
		1 ->
			{ok, BinData} = pt_39:write(39011, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			%%通知所有玩家
			db_agent:mm_update_player_info([{carry_mark, NewStatus#player.carry_mark}],[{id, NewStatus#player.id}]),
			{ok,BinData2} = pt_12:write(12041, [NewStatus#player.id,NewStatus#player.carry_mark]),
			mod_scene_agent:send_to_area_scene(NewStatus#player.scene,NewStatus#player.x,NewStatus#player.y, BinData2),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData2),
			%%氏族战运旗成就统计
			case FeatsType of
				0 ->%%战旗是0
					lib_achieve:check_achieve_finish(Status#player.other#player_other.pid_send,Status#player.id, 320, [1]);
				_ ->%%其他的不统计
					skip
			end,	
			%%跑速变回去
			ResetPlayer = lib_player:count_player_speed(NewStatus),
			lib_player:send_player_attribute(ResetPlayer, 1),
%% 			?DEBUG("reset speed:Id:~p, NewSpeed:~p, OldSpeed:~p", [ResetPlayer#player.id, ResetPlayer#player.speed, NewStatus#player.speed]),
			{ok, change_ets_table, ResetPlayer};
		_ ->
			{ok, BinData} = pt_39:write(39011, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			{ok, NewStatus}
	end;
		false ->
			ok
	end;
	
%% -----------------------------------------------------------------
%% 39012 拾取战旗
%% -----------------------------------------------------------------
handle(39012, Status, [X, Y]) ->
	%%结束战斗,屏蔽消息
	NowSec = util:get_today_current_second(),
	[_WeekDate, SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = lib_skyrush:get_start_end_time(),
	case NowSec >= SKY_RUSH_START_TIME + 5*60 andalso NowSec =< SKY_RUSH_END_TIME of
		true  ->
	case Status#player.carry_mark >= 8 andalso Status#player.carry_mark =< 15 of
		false ->
	[Result, Color, NewStatus] = mod_skyrush:pickup_fn(Status, X, Y),
	case Result of
		1 ->
			{ok, BinData} = pt_39:write(39012, [Result, X, Y, Color]),
%% 			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, BinData) end),
			%%通知所有玩家
			{ok,BinData2} = pt_12:write(12041, [NewStatus#player.id, NewStatus#player.carry_mark]),
			mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID, NewStatus#player.x, NewStatus#player.y, BinData2),
			%%tips更新
			Param = [NewStatus#player.other#player_other.pid_send, Color],
			lib_skyrush:send_skyrush_tips(4, Param),
			%%拾取紫旗，播报!
			case Color =:= 4 of
				true ->
					#player{id = PlayerId,
							nickname = PlayerName,
							career = Career,
							sex = Sex} = NewStatus,
					PurpleParam = [PlayerId, PlayerName, Career, Sex],
					lib_skyrush:send_skyrush_notice(8, PurpleParam);
				false ->
					skip
			end,
			%% 玩家卸下坐骑
			{ok, MountPlayerStatus}= lib_goods:force_off_mount(NewStatus),
			%%重新算一次速度
			RMountPlayerStatus = lib_player:count_player_speed(MountPlayerStatus),
			lib_player:send_player_attribute(RMountPlayerStatus, 1),
%% 			?DEBUG("reset speed:Id:~p, NewSpeed:~p, OldSpeed:~p", [RMountPlayerStatus#player.id, RMountPlayerStatus#player.speed, MountPlayerStatus#player.speed]),
			{ok, change_ets_table, RMountPlayerStatus};
		_Other ->
			{ok, BinData} = pt_39:write(39012, [Result, 0, 0, Color]),
			lib_send:send_to_sid(NewStatus#player.other#player_other.pid_send, BinData),
			{ok, NewStatus}
	end;
		true ->
			{ok, BinData} = pt_39:write(39012, [3, 0, 0, 0]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok
	end;
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 39016 占据据点
%% -----------------------------------------------------------------
handle(39016, Status, [Type]) ->
%% 	io:format("39016  :~p\n", [Type]),
	case Type =:= 1 of
		true ->%%此处只有是等于1才放行
	%%结束战斗,屏蔽消息
	NowSec = util:get_today_current_second(),
	[_WeekDate, SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = lib_skyrush:get_start_end_time(),
	case NowSec >= SKY_RUSH_START_TIME + 5*60 andalso NowSec =< SKY_RUSH_END_TIME of
		true  ->
			case Status#player.carry_mark >= 8 andalso Status#player.carry_mark =< 17 of
				false ->
					#player{scene = Scene,
							x = PX,
							y = PY} = Status,
					[X, Y] = lib_skyrush:get_point_coord(Type),
					AbX = abs(PX -X),
					AbY = abs(PY -Y),
%% 					?DEBUG("point:{~p,~p},Player{~p,~p}", [X,Y,PX,PY]),
					if
						AbX > ?COORD_DIST_LIMIT orelse AbY > ?COORD_DIST_LIMIT ->
							Result = 2;
						Scene =/= ?SKY_RUSH_SCENE_ID ->
							Result = 0;
						true ->
							[Result] = mod_skyrush:hold_point(Status, Type)
					end,
					case Result of
						1 ->
							%% 玩家卸下坐骑
							{ok, MountPlayerStatus}=lib_goods:force_off_mount(Status),
							NewStatus = MountPlayerStatus#player{carry_mark = 17},
							%通知场景附近所有玩家
							{ok,BinData12041} = pt_12:write(12041, [NewStatus#player.id, NewStatus#player.carry_mark]),
							mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID,NewStatus#player.x, NewStatus#player.y, BinData12041);
						_ ->
							NewStatus = Status
					end,
					{ok, BinData} = pt_39:write(39016, [Result]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					{ok, NewStatus};
				true ->
					case Status#player.carry_mark =:= 16 orelse Status#player.carry_mark =:= 17 of
						true ->%%已经在操作，直接忽略
							ok;
						false ->%%头上有东西
							{ok, BinData} = pt_39:write(39016, [4]),
							lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
							ok
					end
			end;
		false ->
			ok
	end;
		false ->%%屏蔽掉所有的type不等于1的请求
			skip
	end;

%% -----------------------------------------------------------------
%% 39021 积分排行
%% -----------------------------------------------------------------
handle(39021, Status, []) ->
	mod_skyrush:get_skyrush_rank(Status),
	ok;

%% -----------------------------------------------------------------
%% 39023 氏族战开启时间广播(广播)
%% -----------------------------------------------------------------
handle(39023, Status, []) ->
	%% 配置表
	[WeekDate, SKY_RUSH_START_TIME, _SKY_RUSH_END_TIME] = lib_skyrush:get_start_end_time(),
	%% 判断今天星期几
	Date = util:get_date(),
	%%是否要开氏族战
	case lists:member(Date, WeekDate) of
		true ->
			NowSec = util:get_today_current_second(),
			case NowSec >= SKY_RUSH_START_TIME + 5 andalso NowSec < (SKY_RUSH_START_TIME + 5 * 60) of
				true ->
					RushStartTime = lib_skyrush:get_skyrush_start_infact(),
					RemainTime = RushStartTime - NowSec,
					{ok, BinData39023} = pt_39:write(39023, [RemainTime]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData39023);
				false ->
					skip
			end;
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 39024 查询功勋
%% -----------------------------------------------------------------
handle(39024, Status, []) ->
	case tool:is_operate_ok(pp_39024, 1) of
		true ->
			{ok, BinData39024} = pt_39:write(39024, [Status#player.other#player_other.guild_feats]),
			%%?DEBUG("the guild feats is:~p", [Status#player.other#player_other.guild_feats]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData39024),
			ok;
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 39025 氏族战奖励
%% -----------------------------------------------------------------
handle(39025, Status, []) ->
	case tool:is_operate_ok(pp_39025, 1) of
		true ->
			case Status#player.guild_id =:= 0 of
				true ->
					{ok, BinData39025} = pt_39:write(39025, [0, 0, 0]),
%% 					io:format("guild id = 0\n"),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData39025),
					ok;
				false ->
					[Result, Exp, Spirit] = mod_skyrush:get_sky_award(Status),
					case Result of
						1 ->
							%%加经验灵力
							NewStatus = lib_player:add_exp(Status, Exp, Spirit, 10),

							{ok, BinData39025} = pt_39:write(39025, [Result, Exp, Spirit]),
							lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData39025),
%% 							io:format("Result:~p, Exp:~p, Spirit:~p\n", [Result, Exp, Spirit]),
							{ok, change_ets_table, NewStatus};
						_ ->
							{ok, BinData39025} = pt_39:write(39025, [Result, Exp, Spirit]),
							lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData39025),
%% 							io:format("Result:~p, Exp:~p, Spirit:~p\n", [Result, Exp, Spirit]),
							ok
					end
			end;
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 39026 氏族战奖励	分配上一场空战信息及物品获取物品
%% -----------------------------------------------------------------
handle(39026, Status, [GuildId]) ->
	case Status#player.guild_id =/= 0 andalso GuildId =:= Status#player.guild_id of
		true ->
			Result = mod_skyrush:get_sky_award_and_members(GuildId),
			{ok, BinData39026} = pt_39:write(39026, Result),
%% 			?DEBUG("39026: ~p", [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData39026);
		false ->
			{ok, BinData39026} = pt_39:write(39026, [[],[]]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData39026)
	end,
	ok;
	
%% -----------------------------------------------------------------
%% 39027 氏族战奖励	物品分配物品
%% -----------------------------------------------------------------
handle(39027, Status, [PlayerId, GoodsTypeId, Num]) ->
	case tool:is_operate_ok(pp_39027, 1) of
		true ->%%1秒的频率限制
			case Status#player.guild_position =/= 1 of
				true ->
					{ok, BinData30027} = pt_39:write(39027, [3, GoodsTypeId, 0]),%%不是族长
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData30027);
				false ->
					Result = mod_skyrush:assign_goods_man(Status#player.guild_id, PlayerId, GoodsTypeId, Num),
					{ok, BinData30027} = pt_39:write(39027, Result),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData30027)
			end,
			ok;
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 39028 氏族战奖励	物品自动分配
%% -----------------------------------------------------------------
handle(39028, Status, []) ->
	case tool:is_operate_ok(pp_39028, 2) of
		true ->%%2秒的频率限制
			case Status#player.guild_position =/= 1 of
				true ->
					{ok, BinData30027} = pt_39:write(39028, [3]),%%不是族长
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData30027);
				false ->
					Result = mod_skyrush:assign_goods_auto(Status#player.guild_id),
					{ok, BinData30027} = pt_39:write(39028, [Result]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData30027)
			end,
			ok;
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 39029查询氏族战是否报名
%% -----------------------------------------------------------------
handle(39029,Status,[]) ->
	case Status#player.guild_id > 0 of
		true->
			mod_skyrush:check_sign_up(Status);
		false->
			skip
	end,
	ok;

%% -----------------------------------------------------------------
%% 39102 进入/离开神魔乱斗场景
%% -----------------------------------------------------------------
handle(39102, Status, [Type]) ->
%% 	?DEBUG("PlayerID:~p", [Status#player.id]),
	case Type of
		1 ->%%进入
			NowSec = util:get_today_current_second(),
			%%检查是否需要启动神魔乱斗
			IsTime = lib_warfare:check_warfare_time(NowSec),
	if
		IsTime =/= true ->
			{ok, BinData} = pt_12:write(12005, [0, 0, 0, <<"现在不是神魔乱斗的开放时间，不能进去！">>, 0, 0, 0, 0]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
		Status#player.scene =:= ?WARFARE_SCENE_ID ->%%已经在里面了，忽略
			ok;
		Status#player.lv < 37 ->%%等级不够
			{ok, BinData} = pt_12:write(12005, [0, 0, 0, <<"等级不足37级，不能进入该场景">>, 0, 0, 0, 0]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
		Status#player.scene > 500 andalso Status#player.scene =/= 705 ->
			{ok, BinData} = pt_12:write(12005, [0, 0, 0, <<"现在副本类的场景中，不能进去神魔乱斗！">>, 0, 0, 0, 0]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
		Status#player.status =:= 7 ->%%凝神修炼
			{ok, BinData} = pt_12:write(12005, [0, 0, 0, <<"凝神修炼不能进去神魔乱斗！">>, 0, 0, 0, 0]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
		true ->
			case lib_scene:check_enter(Status, ?WARFARE_SCENE_ID) of
				{false, _, _, _, Msg, _, _} ->
					{ok, BinData} = pt_12:write(12005, [0, 0, 0, Msg, 0, 0, 0, 0]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
				{true, NewSceneId, X, Y, Name, SceneResId, DungeonTimes, DungeonMaxtimes, Status1} ->
					lib_scene:set_hooking_state(Status,NewSceneId),
					Process_id = self(),
					spawn(erlang, garbage_collect, [Process_id]),
					%% 告诉原来场景玩家你已经离开
					pp_scene:handle(12004, Status, Status#player.scene),
					%% 告诉客户端新场景情况
					{ok, BinData} = pt_12:write(12005, [NewSceneId, X, Y, Name, SceneResId, DungeonTimes, DungeonMaxtimes, 0]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					Status2 = 
						Status1#player{scene = NewSceneId, 
									   x = X, 
									   y = Y},
					put(change_scene_xy , [X, Y]),
					%%修改战斗模式为氏族模式
%% 					Status3 = Status2#player{pk_mode = 3},
%% 					%%更新玩家新模式
%% 					ValueList = [{pk_mode, 3}],
%% 					WhereList = [{id, Status3#player.id}],
%% 					db_agent:mm_update_player_info(ValueList, WhereList),
					%%通知客户端
%% 					{ok, PkModeBinData} = pt_13:write(13012, [1, 3]),
%% 					lib_send:send_to_sid(Status2#player.other#player_other.pid_send, PkModeBinData),
					%%获取 冥王之灵的图标显示
					lib_warfare:get_plutos_owns(Status2#player.other#player_other.pid_send),
					erlang:send_after(2000, self(), {'PEACH_SCENE_CHANGE'}),
					%% 进入神魔乱斗场景时向客户端发送当前已经获取的绑定铜数值
					lib_warfare:send_warfare_award_self(Status2#player.id, Status2#player.other#player_other.pid_send),
					{ok, change_ets_table, Status2}
			end
	end;
		_ ->%%离开
			if
				Status#player.scene =/= ?WARFARE_SCENE_ID ->
					ok;
				true ->
					%%通知去掉冥王之灵图标
					{ok,BinData39104} = pt_39:write(39104, []),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData39104),
					%% 告诉原来场景玩家你已经离开
					pp_scene:handle(12004, Status, Status#player.scene),
					case Status#player.carry_mark =:= 27 of %%头上有冥王之灵
						true ->
							{ok,BinData12041} = pt_12:write(12041, [Status#player.id, 0]),
							mod_scene_agent:send_to_area_scene(Status#player.scene,Status#player.x, Status#player.y, BinData12041),
							lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData12041),
							case mod_warfare_mon:get_warfare_mon() of
								{ok, Warfare} ->
									gen_server:cast(Warfare, {'PLUTO_OWN_OFFLINE', Status#player.id});
								_ ->
									?WARNING_MSG("leave WARFARE_SCENE fail,can not find the process", [])
							end,
							Status1 = Status#player{carry_mark = 0};
						false ->
							Status1 = Status#player{carry_mark = 0}
					end,
					%%先保存数据
					List = [{carry_mark, 0}],
					mod_player:save_online_info_fields(Status1, List),
					Process_id = self(),
					spawn(erlang, garbage_collect, [Process_id]),
					%% 告诉客户端新场景情况
					{NewSceneId, X, Y} = ?WARFARE_OUT_SCENE,
					{ok, BinData} = pt_12:write(12005, [NewSceneId, X, Y, <<>>, NewSceneId, 0, 0, 0]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					NStatus = 
						Status1#player{scene = NewSceneId, 
									   x = X, 
									   y = Y},
					put(change_scene_xy , [X, Y]),
					erlang:send_after(2000, self(), {'PEACH_SCENE_CHANGE'}),
					%% 通知玩家
					{ok, BinData39111} = pt_39:write(39111, [2, 0]),
					lib_send:send_to_sid(NStatus#player.other#player_other.pid_send, BinData39111),
					{ok, change_ets_table, NStatus}
			end
	end;
			
%% -----------------------------------------------------------------
%% 39108 吃掉一个铜币图标
%% -----------------------------------------------------------------
handle(39108, Status, [Key]) ->
	case Key > 0  andalso Key =< ?BCOIN_NUM_LIMIT of
		true ->
			NowSec = util:get_today_current_second(),
			%%检查是否需要启动神魔乱斗
			IsTime = lib_warfare:check_warfare_time(NowSec),
			if
				IsTime =/= true ->
					skip;
				true ->
					case mod_warfare_mon:get_warfare_mon() of
						{ok, Warfare} ->
							#player{id = PlayerId,
									x = PX,
									y = PY,
									other = Other} = Status,
							#player_other{pid_send = PidSend,
										  pid = Pid} = Other,
%% 							?DEBUG("Key:~p", [Key]),
							gen_server:cast(Warfare, {'TRANSLATE_BCOIN', PlayerId, Pid, PidSend, Key, PX, PY});
						_ ->
							skip
					end
			end;
		false ->
			{ok, BinData39108} = pt_39:write(39108, [4, 0]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData39108)
	end,
	ok;

handle(Cmd, _Socket, Data) ->
?DEBUG("handle_skyrush no match_/~p/~p/", [Cmd, Data]),
    {error, "handle_skyrush no match"}.


%%
%% Local Functions
%%

