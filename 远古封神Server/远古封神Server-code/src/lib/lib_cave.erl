%%%-----------------------------------
%%% @Module  : lib_cave
%%% @Author  : ygfs
%%% @Created : 2011.10.26
%%% @Description: 幻魔穴
%%%-----------------------------------
-module(lib_cave).

-export([
	is_cave_scene/1,
	check_enter_cave/3,
	cave_revive_position/3
]).
-include("common.hrl").
-include("record.hrl").
-include("hot_spring.hrl").

-define(CAVE_MAXTIMES, 3).

%% 是否幻魔穴场景
is_cave_scene(SceneUniqueId) ->
	SceneUniqueId rem 10000 =:= ?CAVE_RES_SCENE_ID.

%% 进入幻魔穴场景条件检查
check_enter_cave(Player, SceneId, Scene) ->
	if 
		Player#player.arena > 0 ->
			{false, 0, 0, 0, <<"战场状态不能进入副本！">>, 0, []};
		Player#player.carry_mark > 0 andalso Player#player.carry_mark < 4 orelse (Player#player.carry_mark >= 20 andalso Player#player.carry_mark < 26) ->
			{false, 0, 0, 0, <<"运镖状态不能进入副本！">>, 0, []};
		Player#player.carry_mark > 3 andalso Player#player.carry_mark < 8 ->
			{false, 0, 0, 0, <<"跑商状态不能进入副本！">>, 0, []};
		Player#player.evil >= 450 ->
			{false, 0, 0, 0, <<"您处于红名状态，不能进入副本!">>, 0, []};
		Player#player.scene =:= ?SPRING_SCENE_VIPTOP_ID ->
			{false, 0, 0, 0, <<"在温泉中，不能进入副本!">>, 0, []};
		Player#player.lv < 70 ->
			{false, 0, 0, 0, <<"70级才能进天回阵副本！">>, 0, []};
		true ->
            %CaveCounter = 1,
			SceneUniqueId = lib_scene:get_scene_id_from_scene_unique_id(Player#player.scene),
			{_NewPlayerStatus, _Auto, AwardTimes} = lib_vip:get_vip_award(cave, Player),
			CaveMaxtimes = ?CAVE_MAXTIMES + AwardTimes,
			{Enter, CaveCounter} = lib_dungeon:check_dungeon_times(Player#player.id, Scene#ets_scene.sid, CaveMaxtimes),
			if
				Enter == fail andalso SceneUniqueId =/= ?CAVE_RES_SCENE_ID ->
					Content = io_lib:format("每天进入天回阵不能超过~p次!",[CaveMaxtimes]),
					{false, 0, 0, 0, tool:to_binary(Content), 0, []};
				true ->
                    case misc:is_process_alive(Player#player.other#player_other.pid_dungeon) andalso SceneId =:= SceneUniqueId of
                        %% 已经有副本服务进程
                        true ->
                            NewCaveCounter = 
                                case SceneUniqueId of
                               		?CAVE_RES_SCENE_ID ->
                                        CaveCounter;
                                    _ ->
                                        CaveCounter + 1
                                end,
                            enter_cave_scene(Scene, Player, NewCaveCounter, CaveMaxtimes, SceneUniqueId);
                        %% 还没有副本服务进程
                        false ->
                            Result = 
                                case misc:is_process_alive(Player#player.other#player_other.pid_team) of
                                    %% 没有队伍，角色进程创建副本服务器
                                    false ->
										gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'del_member',[Player#player.id]}),
                                        mod_cave:start(0, self(), SceneId, [{Player#player.id, 
                                                        Player#player.other#player_other.pid, Player#player.other#player_other.pid_dungeon}]);
                                    %% 有队伍且是队长，由队伍进程创建副本服务器
                                    true ->
                                        mod_team:create_cave(Player#player.other#player_other.pid_team, self(), 
                                                            SceneId, [Player#player.id, 
                                                            Player#player.other#player_other.pid,
                                                            Player#player.other#player_other.pid_dungeon])
                                end,
                            case Result of 
                                {ok, Pid} ->
                                    CavePlayer = Player#player{
                                        other = Player#player.other#player_other{
                                            pid_dungeon = Pid
                                        }
                                    },
                                    NewCaveCounter = 
                                        case SceneUniqueId of
                                           	?CAVE_RES_SCENE_ID ->
                                                CaveCounter;
                                            _ ->
                                                CaveCounter + 1
                                        end,
                                    enter_cave_scene(Scene, CavePlayer, NewCaveCounter, CaveMaxtimes, SceneUniqueId);										
                                {fail, Msg} ->
                                    {false, 0, 0, 0, Msg, 0, []}
                            end
                    end
			end
	end.

%% 进入幻魔穴场景
enter_cave_scene(Scene, Player, CaveCounter, CaveMaxtimes, PlayerSceneUniqueId) ->
    case mod_cave:check_cave_enter(Player#player.id, Scene#ets_scene.sid, Player#player.other#player_other.pid_dungeon, Player#player.x, Player#player.y, PlayerSceneUniqueId, Scene#ets_scene.elem) of
        {false, Msg} ->
            {false, 0, 0, 0, Msg, 0, []};
		{true, SceneUniqueId, X, Y, IsFirstIn} ->
			{ok, NewPlayer} = lib_goods:force_off_mount(Player),
			if
				IsFirstIn =:= 1 ->
					%% 成功进入更新进入副本次数
					lib_dungeon:add_dungeon_times(Player#player.id, Scene#ets_scene.sid),
					%% 更新人物延时保存信息
					mod_delayer:update_delayer_info(NewPlayer#player.id, NewPlayer#player.other#player_other.pid_dungeon, NewPlayer#player.other#player_other.pid_fst, NewPlayer#player.other#player_other.pid_team),
					Msg = io_lib:format("您的队友~s进入了~s",[NewPlayer#player.nickname, Scene#ets_scene.name]),
					{ok,TeamBinData} = pt_15:write(15055, [Msg]),
					gen_server:cast(NewPlayer#player.other#player_other.pid_team, {'SEND_TO_OTHER_MEMBER', NewPlayer#player.id, TeamBinData});
				true ->
					skip
			end,
			{true, SceneUniqueId, X, Y, Scene#ets_scene.name, Scene#ets_scene.sid, CaveCounter, CaveMaxtimes, NewPlayer};
        {true, SceneUniqueId} ->
            DungeonSceneId = lib_scene:get_scene_id_from_scene_unique_id(Player#player.scene),
			case data_scene:get(DungeonSceneId) of
           		[] -> 
               		{false, 0, 0, 0, <<"场景出错_2!">>, 0, []};
                S ->
                   	%% 进入副本场景卸下坐骑
                    {ok, NewPlayer} = lib_goods:force_off_mount(Player),
					%% 成功进入更新进入副本次数
					lib_dungeon:add_dungeon_times(Player#player.id, Scene#ets_scene.sid),
					%% 更新人物延时保存信息
					mod_delayer:update_delayer_info(NewPlayer#player.id, NewPlayer#player.other#player_other.pid_dungeon, NewPlayer#player.other#player_other.pid_fst, NewPlayer#player.other#player_other.pid_team),
					Msg = io_lib:format("您的队友~s进入了~s",[NewPlayer#player.nickname, Scene#ets_scene.name]),
					{ok,TeamBinData} = pt_15:write(15055, [Msg]),
					gen_server:cast(NewPlayer#player.other#player_other.pid_team, {'SEND_TO_OTHER_MEMBER', NewPlayer#player.id, TeamBinData}),
                    [RetX, RetY] = 
						case [{X, Y} || [_Index, Id0, _Name, X, Y] <- Scene#ets_scene.elem, Id0 =:= S#ets_scene.sid] of
                       		[] -> 
                        		[Scene#ets_scene.x, Scene#ets_scene.y];
                         	[{X, Y}] -> 
                          		[X, Y];
							_ ->
								[Scene#ets_scene.x, Scene#ets_scene.y]
						end,
					{true, SceneUniqueId, RetX, RetY, Scene#ets_scene.name, Scene#ets_scene.sid, CaveCounter, CaveMaxtimes, NewPlayer}
            end
    end.

%% 幻魔穴复活
cave_revive_position(ScenePid, SX, SY) ->
	case catch gen:call(ScenePid, '$gen_call', 'GET_CAVE_ZONE', 2000) of
		{'EXIT', _Reason} ->
			[SX, SY];
		{ok, ZoneId} ->
			case ZoneId of
				3 ->
					[70, 45];
				2 ->
					[35, 90];
				1 ->
					[SX, SY]
			end
	end.
	
