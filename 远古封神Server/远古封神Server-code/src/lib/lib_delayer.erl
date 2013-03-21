%%%--------------------------------------
%%% @Module  : lib_delayer
%%% @Author  : ygzj
%%% @Created : 2011.02.39
%%% @Description:角色延时信息处理
%%%--------------------------------------
-module(lib_delayer).
-export([ 
	delayer_login/2
]).

-include("record.hrl").
-include("common.hrl").

delayer_login(Player, PlayerPid) ->
    case [mod_delayer:check_delayer_info(Player#player.id), mod_dungeon:get_outside_scene(Player#player.scene)] of
        [DelayInfo, false] ->
			NewPidTeam =
                case DelayInfo of
                    [_Dungeon_pid, _Fst_pid, undefined] ->
                    	undefined;
                    [_Dungeon_pid, _Fst_pid, PidTeam] ->
                        lib_team:join_team(PidTeam, Player, PlayerPid);
                    _ -> 
						undefined
                end,
			%% 是否在氏族领地里
            case mod_guild_manor:get_outside_scene(Player) of
                false ->
					%% 是否在诛邪领地里
                    case mod_box_scene:is_box_scene(Player) of
                        false ->
                            case lib_skyrush:is_skyrush_scene(Player) of
                                false ->
                                    [[Player#player.scene, Player#player.x, Player#player.y], NewPidTeam, [undefined, []]];
                                SkyRushScene ->
                                    [SkyRushScene, NewPidTeam, [undefined, []]]
                            end;	
                        BoxScene ->
                            [BoxScene, NewPidTeam, [undefined, []]]
                    end;
                GuildManorOut ->
                    [GuildManorOut, NewPidTeam, [undefined, []]]
            end;
        [[undefined, [], PidTeam], [DungeonId, DungeonOut]] ->
       		NewPidTeam =
                case PidTeam of
                    undefined ->
                        undefined;
                    _ ->
                        lib_team:join_team(PidTeam, Player, PlayerPid)
                end,
            if
                %% 单人副本 909
				DungeonId == 909  -> 
                    [[Player#player.scene, Player#player.x, Player#player.y], NewPidTeam, [undefined, []]];
                true ->
                    [DungeonOut, NewPidTeam, [undefined, []]]
            end;
        [[DungeonPid, FstPid, PidTeam], [DungeonId, DungeonOut]] ->
            NewPidTeam =
                case PidTeam of
                    undefined ->
                        undefined;
                    _ ->
                        lib_team:join_team(PidTeam, Player, PlayerPid)
                end,
            if
                %%试炼副本
                DungeonId == 901 ->
                    case misc:is_process_alive(DungeonPid) of 
                        true ->							
                            [[Player#player.scene, Player#player.x, Player#player.y], NewPidTeam, [DungeonPid, FstPid]];
                        _ ->
                            [DungeonOut, undefined, [undefined, []]]
                    end;
                NewPidTeam =:= undefined andalso PidTeam =/= undefined andalso DungeonId =/= 999 andalso DungeonId =< 1000->
                    [DungeonOut, undefined, [undefined, []]];
                DungeonId =:= 999  andalso NewPidTeam =:= undefined ->
                    case catch gen_server:call(DungeonPid, {info_num, Player#player.id}) of
                        {'EXIT', _} ->
                            [DungeonOut, undefined, [undefined, []]];
                        ok ->
                            case catch gen:call(DungeonPid, '$gen_call', {join_init, [Player#player.id, PlayerPid]}, 2000) of
                                {ok, true} ->
                                    [[Player#player.scene, Player#player.x, Player#player.y], NewPidTeam, [DungeonPid, FstPid]];
                                {'EXIT', _Reason} ->
                                    [DungeonOut, NewPidTeam, [undefined, []]]
                            end;
                        out ->
                            gen_server:cast(DungeonPid, {'RM_PLAYER', Player#player.id}),
                            [DungeonOut, undefined, [undefined, []]]
                    end;
				DungeonId >= 1101 andalso DungeonId =< 1115 ->
					 case misc:is_process_alive(DungeonPid) of 
                        true ->	
							case catch gen:call(DungeonPid, '$gen_call', {join_init, [Player#player.id, PlayerPid]}, 2000) of
                                 {ok, true} ->
                            		[[Player#player.scene, Player#player.x, Player#player.y], NewPidTeam, [DungeonPid, FstPid]];
								{'EXIT', _Reason} ->
									 [DungeonOut, undefined, [undefined, []]]
							end;
                        _ ->
                            [DungeonOut, undefined, [undefined, []]]
                    end;
                true ->
                    SceneResId = Player#player.scene rem 10000,
                    if
                        SceneResId < 1000 ->
                            %%副本，TD
                            case misc:is_process_alive(DungeonPid) of
                                true ->
                                    case catch gen:call(DungeonPid, '$gen_call', {join_init, [Player#player.id, PlayerPid]}, 2000) of
                                        {ok, true} ->
                                            [[Player#player.scene, Player#player.x, Player#player.y], NewPidTeam, [DungeonPid, FstPid]];
                                        {'EXIT', _Reason} ->
                                            [DungeonOut, NewPidTeam, [undefined, []]]
                                    end;
                                false ->
                                    [DungeonOut, NewPidTeam, [undefined, []]]
                            end;
                        true ->
                            [Fst_alive, Pid_fst_delayer] = 
                                case lists:keysearch(SceneResId, 1, FstPid) of
                                    {value,{_SceneId, Now_Fst_pid}} ->
                                        [misc:is_process_alive(Now_Fst_pid), Now_Fst_pid];
                                    _ ->
                                        [false, 0]
                                end,
                            case Fst_alive of
                                true ->
                                    case catch gen:call(Pid_fst_delayer, '$gen_call', {join, [Player#player.id, PlayerPid]}, 2000) of
                                        {ok, true} ->
                                            [[Player#player.scene, Player#player.x, Player#player.y], NewPidTeam, [DungeonPid, FstPid]];
                                        {'EXIT', _Reason} ->
                                            [DungeonOut, NewPidTeam, [undefined, []]]
                                    end;
                                false ->
                                    [DungeonOut, NewPidTeam, [undefined, []]]
                            end
                    end
                end;
        [_DelayInfo, [_Dungeon_id, DungeonOut]] ->
            [DungeonOut, undefined, [undefined, []]]
    end.
