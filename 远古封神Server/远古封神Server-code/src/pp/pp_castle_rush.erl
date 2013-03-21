%%%--------------------------------------
%%% @Module  : pp_castle_rush
%%% @Author  : ygfs
%%% @Created : 2011.11.16
%%% @Description : 九霄攻城战
%%%--------------------------------------
-module(pp_castle_rush).

-export(
	[
	 	handle/3
	]
).

-include("common.hrl").
-include("record.hrl").

%% 攻城战报名
handle(47002, PlayerState, _) ->
	Player = PlayerState#player_state.player,
	if
		%% 必须是氏族内的族长或者长老才可以进行报名操作
		Player#player.guild_position > 3 ->
			{ok, BinData} = pt_47:write(47002, 8),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		true ->
%% 			%% 是否在报名时间
%%             case lib_castle_rush:is_castle_rush_join_time() of
%%                 true ->
                    gen_server:cast(mod_guild:get_mod_guild_pid_for_apply(), 
                        {apply_asyn_cast, lib_castle_rush, apply_castle_rush,
                            [Player#player.guild_id, Player#player.other#player_other.pid_send]})
%%                 false ->
%%                     {ok, BinData} = pt_47:write(47002, 3),
%%                     lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
%%             end
	end;

%% 查看已报名氏族
handle(47003, PlayerState, _) ->
	Player = PlayerState#player_state.player,
	GuildPid = mod_guild:get_mod_guild_pid(),
	case is_pid(GuildPid) of
		true ->
			gen_server:cast(GuildPid, {apply_asyn_cast, lib_castle_rush, get_castle_rush_join_list, [Player#player.other#player_other.pid_send]});
		false ->
			skip
	end;

%% 进入攻城战
handle(47004, PlayerState, _) ->
	Player = PlayerState#player_state.player,
    if
        %% 红名不能参加攻城战
        Player#player.evil > 300 ->
            {ok, BinData} = pt_47:write(47004, 7),
            lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
        %% 死亡状态不能进入攻城战
        Player#player.hp < 1 ->
            {ok, BinData} = pt_47:write(47004, 9),
            lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
        %% 双修状态不能进入攻城战
        Player#player.status =:= 10 ->
            {ok, BinData} = pt_47:write(47004, 6),
            lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		%% 凝神状态不能进入攻城战
        Player#player.status =:= 7 ->
            {ok, BinData} = pt_47:write(47004, 2),
            lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
        %% 运镖跑商状态不能进入攻城战
        Player#player.carry_mark > 0 ->
            {ok, BinData} = pt_47:write(47004, 4),
            lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		%% 没氏族不能进入攻城战
		Player#player.guild_id =:= 0 ->
			{ok, BinData} = pt_47:write(47004, 10),
            lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		%% 35级以上才能进入城战地图
		Player#player.lv < 35 ->
			{ok, BinData} = pt_47:write(47004, 12),
            lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
        true ->
            %% 组队不能进入攻城战
            case is_pid(Player#player.other#player_other.pid_team) of
                true ->
                    {ok, BinData} = pt_47:write(47004, 8),
                    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
                false ->
                    %% 温泉里不能直接进入攻城战
                    case lib_spring:is_spring_scene(Player#player.scene) of
                        true ->
                            {ok, BinData} = pt_47:write(47004, 5),
                            lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
                        false ->
%% 							lib_castle_rush:enter_castle_rush_scene(PlayerState, 1)
							case lib_castle_rush:is_castle_rush_real_start_time() of
								true ->
									ScenePid = mod_scene:get_scene_pid(?CASTLE_RUSH_SCENE_ID, undefined, undefined), 
									case catch gen_server:call(ScenePid, {apply_call, lib_castle_rush, check_enter, [Player#player.id, Player#player.nickname, Player#player.career, Player#player.lv, Player#player.guild_id]}) of
                                        [1, WinGuildId, WinGuildName] ->
                                            lib_castle_rush:enter_castle_rush_scene(PlayerState, WinGuildId, WinGuildName);
                                        %% 没报名
                                        [2, _Sta] ->
                                            {ok, BinData} = pt_47:write(47004, 11),
                                            lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
                                        _Other ->
%% 		io:format("castle_rush bbbbbbbbbbbbbbbbbbbbbbbbbb ~p~n", [Other]),
                                            {ok, BinData} = pt_47:write(47004, 0),
                                            lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
									end;
								false ->
									{ok, BinData} = pt_47:write(47004, 1),
                            		lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
							end
                    end
            end
    end;

%% 战功排行氏族战功 
handle(47005, PlayerState, _) ->
	Player = PlayerState#player_state.player,
	GuildPid = mod_guild:get_mod_guild_pid(),
	case is_pid(GuildPid) of
		true ->
			gen_server:cast(GuildPid, {apply_asyn_cast, lib_castle_rush, get_castle_rush_guild_rank, [Player#player.other#player_other.pid_send]});
		false ->
			skip
	end;

%% 战功排行个人战功
handle(47006, PlayerState, _) ->
	Player = PlayerState#player_state.player,
	GuildPid = mod_guild:get_mod_guild_pid(),
	case is_pid(GuildPid) of
		true ->
			gen_server:cast(GuildPid, {apply_asyn_cast, lib_castle_rush, get_castle_rush_player_rank, [Player#player.other#player_other.pid_send]});
		false ->
			skip
	end;

%% 攻城战数据
%% Type 1氏族战功、2伤害积分、3个人战功
handle(47007, PlayerState, Type) ->
	Player = PlayerState#player_state.player,
	case lib_castle_rush:is_castle_rush_time() of
		true ->
            CastleRushPid = lib_castle_rush:get_castle_rush_worker_pid(Player#player.guild_id),
            case is_pid(CastleRushPid) of
                true ->
                    gen_server:cast(CastleRushPid, {apply_asyn_cast, lib_castle_rush, get_castle_rush_data, 
                            [Type, Player#player.other#player_other.pid_send]});
                false ->
                    skip
            end;
		false ->
			skip
	end;

%% 领取税收
handle(47009, PlayerState, _) ->
	Player = PlayerState#player_state.player,
	[Result, NewPlayer, Num] = lib_castle_rush:get_castle_rush_tax(Player),
	{ok, BinData} = pt_47:write(47009, [Result, Num]),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	if
		Result == 1 ->
			{ok, BinData13018} = pt_13:write(13018, [{3, NewPlayer#player.bcoin}]),
			lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send, BinData13018),
			{ok, change_status, NewPlayer};
		true ->
			skip
	end;

%% 离开攻城战
handle(47010, PlayerState, _) ->
	NewPlayer = lib_castle_rush:leave_castle_rush(PlayerState#player_state.player),
	{ok, change_status, NewPlayer};

%% 使用鼓舞技能
handle(47012, PlayerState, _) ->
	Player = PlayerState#player_state.player,
	if
		Player#player.guild_id =/= 0 ->
			%% 是否族长或长老
			if
				Player#player.guild_position > 3 ->
					{ok, BinData} = pt_47:write(47012, 2),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
				true ->
					CastleRushPid = lib_castle_rush:get_castle_rush_worker_pid(Player#player.guild_id),
					CastleRushPid ! {'CASTLE_RUSH_ANGRY', Player#player.guild_id, Player#player.other#player_other.pid_send}
			end;
		true ->
			skip
	end;

%% 攻城战奖励 - 获取物品
handle(47016, PlayerState, _) ->
	Player = PlayerState#player_state.player,
	if
		Player#player.guild_id =/= 0 ->
			GuildPid = mod_guild:get_mod_guild_pid(),
			case is_pid(GuildPid) of
				true ->
					gen_server:cast(GuildPid, {apply_asyn_cast, lib_castle_rush, 
							get_castle_rush_award_data, [Player#player.other#player_other.pid_send, Player#player.guild_id]});
				false ->
					skip
			end;
		true ->
			skip
	end;

%% 攻城战奖励 - 物品分配物品
handle(47017, PlayerState, [PlayerId, GoodsTypeId, Num]) ->
	Player = PlayerState#player_state.player,
	%% 是否族长
	if
		Player#player.guild_position =/= 1 ->
			{ok, BinData} = pt_47:write(47017, [3, GoodsTypeId, 0]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		true ->
			GuildPid = mod_guild:get_mod_guild_pid(),
			case is_pid(GuildPid) of
				true ->
					gen_server:cast(GuildPid, {apply_asyn_cast, lib_castle_rush, 
							allot_castle_rush_award, [Player#player.other#player_other.pid_send, Player#player.guild_id, PlayerId, GoodsTypeId, Num]});
				false ->
					skip
			end
	end;

%% 攻城战奖励 - 物品自动分配
handle(47018, PlayerState, []) ->
	Player = PlayerState#player_state.player,
	%% 是否族长
	if
		Player#player.guild_position =/= 1 ->
			{ok, BinData} = pt_47:write(47018, [3]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		true ->
			GuildPid = mod_guild:get_mod_guild_pid(),
			case is_pid(GuildPid) of
				true ->
					gen_server:cast(GuildPid, {apply_asyn_cast, lib_castle_rush, 
							auto_allot_castle_rush_award, [Player#player.other#player_other.pid_send, Player#player.guild_id]});
				false ->
					skip
			end
	end;

handle(_Cmd, _PlayerState, _Data) ->
    {error, "handle_castle_rush no match"}.
