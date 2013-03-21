%% Author: xiaomai
%% Created: 2011-1-11
%% Description: 氏族领地处理方法
-module(lib_guild_manor).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("guild_info.hrl").
%%
%% Exported Functions
%%
-export([]).
-compile([export_all]).

%%
%% API Functions
%%
%%由氏族id和领地场景id产生针对氏族唯一的id
get_unique_manor_id(SceneId, GuildId) ->
	GuildId * ?GUILD_MANOR_PID + SceneId.
%%由唯一的id转为场景id
get_scene_Id_from_scene_unique_id(SceneId, GuildId) ->
	SceneId - GuildId * ?GUILD_MANOR_PID.

get_guild_manor_dict(Type) ->
	get(Type).
update_guild_manor_dict(Type, Param) ->
	put(Type, Param).
erase_guild_manor_dict(Type) ->
	erase(Type).

%%进入领地
enter_manor_scene(Scene, UniqueSceneId, _GuildManorInitId, Status) ->
	%%进入领地场景卸下坐骑
%% 	io:format("enter_manor_scene before :~p\n",[Status#player.scene]),
	{ok, NewStatus} = lib_goods:force_off_mount(Status),
	%%做玩家退出氏族领地时的场景记录
	mark_manor_enter_coord(Status#player.id, Status#player.scene),
	{true, UniqueSceneId, Scene#ets_scene.x, Scene#ets_scene.y, Scene#ets_scene.name, Scene#ets_scene.sid, 0, 0, NewStatus}.

%%检测和进入氏族领地
manor_check_and_enter(SceneId, Scene, Status) ->
%% 	io:format("11111\n"),
	case check_guild_enter(Status) of
		{fail, Reason} ->%%没权限进去
%% 			io:format("22222\n"),
			{false, 0, 0, 0, Reason, 0, []};
		{ok} ->
%% 									 GuildManorInitId = lib_guild_manor:get_scene_Id_from_scene_unique_id(SceneId),%%获取对应的领地id（不唯一）
%% 			io:format("33333\n"),
			#player{id = PlayerId,
					guild_id = GuildId} = Status,
			PlayerPid = Status#player.other#player_other.pid,
			{ok, ManorPid} = mod_guild_manor:get_guild_manor_pid(SceneId, GuildId, PlayerId, PlayerPid),%%获取进程号
			UniqueSceneId = lib_guild_manor:get_unique_manor_id(SceneId, GuildId),
			lib_guild_manor:update_guild_manor_dict(guild_manor_pid, ManorPid),%%更新进程字典
			NewStatus = Status#player{other = Status#player.other#player_other{pid_scene = ManorPid}},
%% 			io:format("status: ~p \n", [NewStatus#player.scene]),
			lib_guild_manor:enter_manor_scene(Scene, UniqueSceneId, SceneId, NewStatus)
%% 			end
	end.

manor_check_and_enter_39sky(SceneId, Scene, Status) ->
	#player{id = PlayerId,
			guild_id = GuildId} = Status,
	PlayerPid = Status#player.other#player_other.pid,
	{ok, ManorPid} = mod_guild_manor:get_guild_manor_pid(SceneId, GuildId, PlayerId, PlayerPid),%%获取进程号
	UniqueSceneId = lib_guild_manor:get_unique_manor_id(SceneId, GuildId),
	lib_guild_manor:update_guild_manor_dict(guild_manor_pid, ManorPid),%%更新进程字典
	NewStatus = Status#player{other = Status#player.other#player_other{pid_scene = ManorPid}},
%% 			io:format("status: ~p \n", [NewStatus#player.scene]),
	lib_guild_manor:enter_manor_scene(Scene, UniqueSceneId, SceneId, NewStatus).


check_guild_sky_enter(Status) ->
	case check_guild_enter_40033(Status) of
		{ok} ->%%可以进入
			{ok};
		{fail, Type} ->
			case Type of
				0 ->
					{fail, <<"你没有加入任何氏族，没权进入该场景！">>};
				3 -> 
					{fail, <<"正在运镖，不能进入该场景！">>};
				4 -> 
					{fail, <<"正在跑商，不能进入该场景！">>};
				5 -> 
					{fail, <<"正在打坐，不能进入该场景！">>};
				6 -> 
					{fail, <<"正在挂机，不能进入该场景！">>};
				7 -> 
					{fail, <<"正在凝神修炼，不能进入该场景！">>};
				8 -> 
					{fail, <<"罪恶值过大，不能进入该场景！">>};
				9 -> 
					{fail, <<"在副本里，不能进入该场景！">>};
				10 -> 
					{fail, <<"已经死亡，不能进入该场景！">>};
				11 ->
					{fail, <<"玩家数据出错了，没权进入该场景！">>};
				12 ->%%在氏族领地里
					{ok};
				17 ->
					{fail, <<"正在战斗，不能进入该场景！">>};
				18 ->
					{fail, <<"蓝名，不能进入该场景！">>};
				19 ->
					{fail, <<"答题状态，不能进入该场景！">>};
				20 ->%%点NPC出去的
					{ok};
				21 ->
					{fail, <<"组队状态，不能进入该场景！">>};
				23 ->
					{fail, <<"镇妖台，不能进入该场景！">>};
				26 ->
					{fail, <<"双修状态，不能进入该场景！">>};
				27 ->
					{fail, <<"婚宴场景，不能直接进入该场景！">>};
				28 ->
					{fail, <<"洞房场景，不能直接进入该场景！">>};
				_ ->
					{fail, <<"操作错误，不能进入该场景！">>}
			end
	end.

%% -----------------------------------------------------------------
%% 氏族领地进入条件判断
%% -----------------------------------------------------------------
check_guild_enter(Status) ->
	case check_guild_enter_40033(Status) of
		{ok} ->%%可以进入
			{ok};
		{fail, Type} ->
			case Type of
				0 ->
					{fail, <<"你没有加入任何氏族，没权进入氏族领地！">>};
				3 -> 
					{fail, <<"正在运镖，不能进入氏族领地！">>};
				4 -> 
					{fail, <<"正在跑商，不能进入氏族领地！">>};
				5 -> 
					{fail, <<"正在打坐，不能进入氏族领地！">>};
				6 -> 
					{fail, <<"正在挂机，不能进入氏族领地！">>};
				7 -> 
					{fail, <<"正在凝神修炼，不能进入氏族领地！">>};
				8 -> 
					{fail, <<"罪恶值过大，不能进入氏族领地！">>};
				9 -> 
					{fail, <<"在副本里，不能进入氏族领地！">>};
				10 -> 
					{fail, <<"已经死亡，不能进入氏族领地！">>};
				11 ->
					{fail, <<"玩家数据出错了，没权进入氏族领地！">>};
				12 ->
					{fail, <<"已经在氏族领地里！">>};
				17 ->
					{fail, <<"正在战斗，不能进入氏族领地！">>};
				18 ->
					{fail, <<"蓝名，不能进入氏族领地！">>};
				19 ->
					{fail, <<"答题状态，不能进入氏族领地！">>};
				20 ->%%点NPC出去的
					{ok};
				21 ->
					{fail, <<"组队状态，不能进入氏族领地！">>};
				23 ->
					{fail, <<"镇妖台，不能进入氏族领地！">>};
				26 ->
					{fail, <<"双修状态，不能进入氏族领地！">>};
				27 ->
					{fail, <<"婚宴场景，不能进入氏族领地！">>};
				28 ->
					{fail, <<"洞房场景，不能进入氏族领地！">>};
				_ ->
					{fail, <<"操作错误，不能进入氏族领地！">>}
			end
	end.
handle_deliver_type(Type) ->
	case Type of
		ok ->
			{ok};
		10 ->%% 10 战斗中
			{fail, 17};
%% 		10 ->%% 10 战斗中
%% 			{ok};
		11 ->%%	11死亡中
			{fail, 10};
		12 ->%%	12蓝名
			{fail, 18};
		13 ->%%	13挂机状态
			{fail, 6};
		14 ->%%	14打坐状态
			{fail, 5};
		15 ->%%	15凝神修炼
			{fail, 7};
		16 ->%%	16挖矿状态
			{fail, 14};
		17 ->%%答题状态
			{fail, 8};
		18 ->%%双修状态
			{fail, 26};
		21 ->%%	21红名（罪恶值>=450）
			{fail, 8};
		22 ->%%	22运镖状态
			{fail, 3};
		31 ->%%	31副本中
			{fail, 9};
		32 ->%%	32氏族领地
			{fail, 12};
		33 ->%%	33竞技场
			{fail, 13};
		34 ->%%	34封神台
			{fail, 15};
		35 ->%%  35秘境
			{fail, 16};
		36 ->%%  36空岛
			{fail, 20};
		37 ->%%37 镇妖台
			{fail, 23};
		38->%%38诛仙台
			{fail,24};
		39 ->%%温泉
			{fail, 25};
		41 ->%%神魔乱斗
			{fail, 9};
		42 ->	%% 九霄攻城战
			{fail, 9};
		43 -> %%婚宴场景
			{fail, 27};
		44 -> %% 洞房场景
			{fail, 28};
		_ ->
			{fail, 22}
	end.
check_guild_enter_40033(Status) ->
	case Status#player.guild_id of
		0 ->
			{fail, 0};
		_GuildId when Status#player.lv >= ?CREATE_GUILD_LV ->
%% 			case is_pid(Status#player.other#player_other.pid_team) =:= true of
%% 				false ->
					Type = lib_deliver:could_deliver(Status),
					handle_deliver_type(Type);
%% 				true ->
%% 					{fail, 21}
%% 			end;
		_ ->%数据有问题了
			{fail, 11}
	end.
										  
			
			
%% 在氏族面板使用回族命令的判断
check_use_guild_token(Status) ->
	case check_guild_enter_40033(Status) of
		{ok} ->
			GuildId = Status#player.guild_id,
			case is_guild_manor_scene(Status#player.scene, GuildId) of
				false ->%%不在氏族领地里面
                  	DefalutScene = 300,
					Now = util:unixtime(),
					case get_guild_manor_dict(guild_token_cd) of
                        undefined ->%%进程字典没有
							PlayerId = Status#player.id,
                            case db_agent:get_guild_manor_cd(PlayerId) of
                                [] ->%%数据库没有
                                    NewTime = Now + ?GUILDTOKENTIME,
                                    db_agent:add_guild_manor_cd(PlayerId, DefalutScene, NewTime, 0),
                                    update_guild_manor_dict(guild_token_cd, NewTime),
                                    update_guild_manor_dict(manor_enter_coord, {1, DefalutScene}),
                                    [1, ?GUILDTOKENTIME];
                                [DBTime] ->
                                    update_guild_manor_time(Now, DBTime, Status, DefalutScene)
                            end;
                        Time ->
                            update_guild_manor_time(Now, Time, Status, DefalutScene)
                    end;
				true ->%%已经在氏族领地里面
					[12, ?GUILDTOKENTIME]
			end;
		{fail, FailType} ->
			[FailType, ?GUILDTOKENTIME]
	end.
			
update_guild_manor_time(Now, Time, Status, DefalutScene) ->
	PlayerId = Status#player.id,
	case (Now - Time) >= 0 of
		true -> %%可以使用
			NewTime = Now + ?GUILDTOKENTIME,
			db_agent:update_guild_manor_cd_and_coord(PlayerId, NewTime, DefalutScene),
			update_guild_manor_dict(manor_enter_coord, {1, DefalutScene}),
			update_guild_manor_dict(guild_token_cd, NewTime),
			[1, ?GUILDTOKENTIME];
		false ->
			RemainTime = Time - Now,
			[2, RemainTime]
	end.
%%
%% Local Functions
%%


%% 是否为氏族领地场景，UniqueId唯一id，会检查是否存在这个场景
is_guild_manor_scene(UniqueSceneId, GuildId) ->
	?GUILD_SCENE_ID =:= get_scene_Id_from_scene_unique_id(UniqueSceneId, GuildId).

%%传出
send_out_guild_manor(PlayerPid, SceneId, Type) ->
	gen_server:cast(PlayerPid,{send_out_manor, SceneId, Type}).


%%做玩家退出氏族领地时的场景记录
mark_manor_enter_coord(PlayerId, SceneId) ->
	case get_guild_manor_dict(manor_enter_coord) of
		undefined ->
			case db_agent:get_guild_manor_enter_coord(PlayerId) of
				[] ->
					db_agent:add_guild_manor_cd(PlayerId, SceneId, 0, 0),
					update_guild_manor_dict(manor_enter_coord, {1, SceneId});
				[_OldSceneId] ->
					db_agent:update_guild_manor_enter_coord(PlayerId, SceneId),
					update_guild_manor_dict(manor_enter_coord, {1, SceneId})
			end;
		{1, _OldSceneId1} ->
			no_action;
		{_OldType, _OldSceneId2} ->
			db_agent:update_guild_manor_enter_coord(PlayerId, SceneId),
			update_guild_manor_dict(manor_enter_coord, {1, SceneId})
	end.

get_manor_sentout_coord(Type, PlayerId) ->
	Result = 
		case get_guild_manor_dict(manor_enter_coord) of
			undefined ->
				case db_agent:get_guild_manor_enter_coord(PlayerId) of
					[] ->
%% 						io:format("111\n"),
						data_guild:get_manor_send_out(300);
					[SceneId] ->
%% 						io:format("2222\n"),
						data_guild:get_manor_send_out(SceneId)
				end;
			{_OldType, SceneIdRecord} ->
%% 				io:format("33333\n"),
				data_guild:get_manor_send_out(SceneIdRecord)
		end,
	{NewSceneId, _X, _Y} = Result,
	case Type of
		0 -> %%氏族已经不存在，直接删除相关的玩家数据
			db_agent:delete_guild_manor_cd(PlayerId);
		1 ->%%玩家登陆
			db_agent:update_guild_manor_enter_coord(PlayerId, NewSceneId),
			update_guild_manor_dict(manor_enter_coord, {1, NewSceneId});
		2 ->%%玩家传出领地
			db_agent:update_guild_manor_enter_coord(PlayerId, 0),
			erase_guild_manor_dict(manor_enter_coord)
	end,
	Result.

enter_manor_scene_40033(Status, SceneId) ->
	Result = 
		case data_scene:get(SceneId) of
			[] ->
				{false, 0, 0, 0, <<"场景不存在!">>, 0, []};
			Scene ->
				case lib_scene:check_requirement(Status, Scene#ets_scene.requirement) of
					{false, Reason} -> 			
						{false, 0, 0, 0, Reason, 0, []};
					{true} when Scene#ets_scene.type =:= 5 ->
						%%开始处理进入氏族领地的逻辑
						lib_guild_manor:manor_check_and_enter(SceneId, Scene, Status);
					_Other ->
						{false, 0, 0, 0, <<"场景不存在!">>, 0, []}
				end
		end,
	case Result of
		 {false, _, _, _, Msg, _, _} ->
			 {ok, BinData} = pt_12:write(12005, [0, 0, 0, Msg, 0, 0, 0, 0]),
			 lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			 ok;
		{true, NewSceneId, X, Y, Name, SceneResId, Dungeon_times, Dungeon_maxtimes, Status1} ->
			%%告诉原场景的玩家你已经离开
			pp_scene:handle(12004, Status, Status#player.scene),
			{ok, BinData} = pt_12:write(12005, 
										[NewSceneId, X, Y, Name, SceneResId, Dungeon_times, Dungeon_maxtimes, 0]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			put(change_scene_xy , [X, Y]),%%做坐标记录
			Status2 = Status1#player{scene = NewSceneId, x = X, y = Y},
			%%更新玩家新坐标
			ValueList = [{scene,NewSceneId},{x,X},{y,Y}, {carry_mark, Status2#player.carry_mark}],
			WhereList = [{id, Status1#player.id}],
			db_agent:mm_update_player_info(ValueList, WhereList),
			{ok, Status2}
	end.

enter_manor_scene_39sky(Status, SceneId) ->
	Result = 
		case data_scene:get(SceneId) of
			[] ->
				{false, 0, 0, 0, <<"场景不存在!">>, 0, []};
			Scene ->
				case lib_scene:check_requirement(Status, Scene#ets_scene.requirement) of
					{false, Reason} -> 			
						{false, 0, 0, 0, Reason, 0, []};
					{true} when Scene#ets_scene.type =:= 5 ->
						%%开始处理进入氏族领地的逻辑
						lib_guild_manor:manor_check_and_enter_39sky(SceneId, Scene, Status);
					_Other ->
						{false, 0, 0, 0, <<"场景不存在!">>, 0, []}
				end
		end,
	case Result of
		 {false, _, _, _, Msg, _, _} ->
			 {ok, BinData} = pt_12:write(12005, [0, 0, 0, Msg, 0, 0, 0, 0]),
			 lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			 {ok, Status};
		{true, NewSceneId, X, Y, Name, SceneResId, Dungeon_times, Dungeon_maxtimes, Status1} ->
			%%告诉原场景的玩家你已经离开
			pp_scene:handle(12004, Status, Status#player.scene),
			{ok, BinData} = pt_12:write(12005, 
										[NewSceneId, X, Y, Name, SceneResId, Dungeon_times, Dungeon_maxtimes, 0]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			put(change_scene_xy , [X, Y]),%%做坐标记录
			Status2 = Status1#player{scene = NewSceneId, x = X, y = Y},
			%%更新玩家新坐标
			ValueList = [{scene,NewSceneId},{x,X},{y,Y}, {carry_mark, Status2#player.carry_mark}],
			WhereList = [{id, Status1#player.id}],
			db_agent:mm_update_player_info(ValueList, WhereList),
			{ok, Status2}
	end.

check_guild_boss(GuildId) ->
	[GuildName, MonId, MonName, X, Y] = get_guild_boss_sv(GuildId),
	case MonId =:= 0 of
		true ->
			skip;
		false ->
			erlang:send_after(4000, self(), {create_mon_boss, GuildId, GuildName, MonId, MonName, X, Y})
	end.
get_guild_boss_sv(GuildId) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
							 {apply_call, lib_guild_manor, lib_check_guild_boss, 
							  [GuildId]})	of
			 error -> 
				 ["", 0, "", 0, 0];
			 Data -> 
				 Data
		end		
	catch
		_:_Reason -> 
			["", 0, "", 0, 0]
	end.

lib_check_guild_boss(GuildId) ->
	case lib_guild_inner:get_guild(GuildId) of
		[] ->
			error;
		Guild ->
			#ets_guild{boss_sv = BossSv,
					   name = GuildName} = Guild,
			case BossSv =:= 0 of
				true ->
					["", 0, "", 0, 0];
				false ->
					Type = data_guild:make_boss_type(BossSv),
					{_Lv, _Funds, MonId, MonName, X, Y} = data_guild:get_guild_call_boss(Type),
					[GuildName, MonId, MonName, X, Y]
			end
	end.
