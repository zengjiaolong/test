%%%--------------------------------------
%%% @Module  : pp_coliseum
%%% @Author  : ygfs
%%% @Created : 2012.02.27
%%% @Description : 竞技场
%%%--------------------------------------
-module(pp_coliseum).

-export(
	[
	 	handle/3
	]
).
-include("common.hrl").
-include("record.hrl").
-include("guild_info.hrl").

%% 打开竞技场面板
handle(49001, PlayerState, _) ->
	Player = PlayerState#player_state.player,
	if
		Player#player.lv > 29 ->
			lib_coliseum:send_coliseum_info(PlayerState, Player);
		true ->
			{ok, BinData} = pt_49:write(49006, 2),
   			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
	end;

%% 修改是否自动使用替身设置 
%% IsAvatar 1是，0否
handle(49002, PlayerState, IsAvatar) ->
	NewPlayerState = PlayerState#player_state{
		is_avatar = IsAvatar							   
	},
	{ok, change_player_state, NewPlayerState};

%% 请求竞技场排行榜信息
handle(49003, PlayerState, _) ->
	Player = PlayerState#player_state.player,
	ColiseumPid = mod_coliseum_supervisor:get_coliseum_worker_pid(),
	gen_server:cast(ColiseumPid, {'COLISEUM_RANK', Player#player.other#player_other.pid_send});
	
%% 清零冷却时间或增加每日挑战次数
%% Type 请求类型，1清零冷却时间，2增加每日挑战次数
handle(49004, PlayerState, Type) ->
	Player = PlayerState#player_state.player,
	if
		Type =:= 1 ->
			lib_coliseum:clear_coliseum_time(PlayerState, Player);
		true ->
			Cost = (PlayerState#player_state.coliseum_extra_time + 1) * 2,
			if
				%% 元宝不足
				Player#player.gold < Cost ->
					{ok, BinData} = pt_49:write(49004, [Type, 2, 0, 0]),
   					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
				true ->
					NewPlayer = lib_goods:cost_money(Player, Cost, gold, 4905),
					lib_player:send_player_attribute2(NewPlayer, 2),
					%% 竞技场剩余挑战次数
					ColiseumSurplusTime = PlayerState#player_state.coliseum_surplus_time + 1,
					%% 额外挑战次数
					ColiseumExtraTime = PlayerState#player_state.coliseum_extra_time + 1,
					{ok, BinData} = pt_49:write(49004, [Type, 1, ColiseumSurplusTime, ColiseumExtraTime]),
   					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
					NewPlayerState = PlayerState#player_state{
						player = NewPlayer,
						coliseum_surplus_time = ColiseumSurplusTime,
						coliseum_extra_time = ColiseumExtraTime					   
					},
					{ok, change_player_state, NewPlayerState}
			end
	end;

%% 竞技场战报展示
handle(49006, PlayerState, ReportId) ->
	Player = PlayerState#player_state.player,
	ColiseumReportTime = 
		case get(coliseum_report_time) of
			undefined -> 
				0;
			CRT ->
				CRT
		end,
	Now = util:unixtime(),
	if
		%% 10秒只可以展示一次
		Now - ColiseumReportTime > 10 ->
			put(coliseum_report_time, Now),
			ColiseumPid = mod_coliseum_supervisor:get_coliseum_worker_pid(),
			gen_server:cast(ColiseumPid, 
				{'COLISEUM_REPORT_SHOW', Player#player.id, Player#player.nickname, Player#player.vip, Player#player.state, ReportId});
		true ->
			{ok, BinData} = pt_49:write(49006, 1),
   			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
	end;
	
%% 竞技场挑战
%% ChallengerId 挑战者ID
handle(49007, PlayerState, ChallengerId) ->
	Player = PlayerState#player_state.player,
	if
		Player#player.id =:= ChallengerId ->
			{ok, BinData} = pt_49:write(49007, [11, 0, []]),
   			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		%% 判断是否有剩余次数
		PlayerState#player_state.coliseum_surplus_time =< 0 ->
			{ok, BinData} = pt_49:write(49007, [2, 0, []]),
   			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		true ->
			%% 检查进入竞技场的条件
			case lib_coliseum:check_coliseum_enter(Player) of
				true ->
					ColiseumPid = mod_coliseum_supervisor:get_coliseum_worker_pid(),
					case catch gen_server:call(ColiseumPid, {'CHECK_COLISEUM_ENTER', Player#player.id, ChallengerId}) of
						{1, ColiseumPlayerData} ->
							lib_coliseum:enter_coliseum(PlayerState, Player, ChallengerId, ColiseumPlayerData);
						_Other ->
							skip
					end;	
				_ ->
					skip
			end
	end;

%% 被挑战者回应
%% Type 1亲自上阵，2使用替身
handle(49008, PlayerState, [Type, ColiseumSceneId]) ->
	case lib_coliseum:is_coliseum_scene(ColiseumSceneId) of
		true ->
			Player = PlayerState#player_state.player,
			ColiseumScenePid = mod_scene:get_scene_real_pid(ColiseumSceneId),
			case catch gen_server:call(ColiseumScenePid, {'COLISEUM_ENER_CHECK', Player#player.id, Player#player.hp_lim, 
							Player#player.mp_lim, Type, Player#player.other#player_other.pid_send}) of
				1 ->
					if
						Type =:= 1 ->
							%% 检查进入竞技场的条件
							case lib_coliseum:check_coliseum_enter(Player) of
								true ->
									{X, Y} = lib_coliseum:get_challenged_position(),
									Now = util:unixtime(),
									lib_coliseum:enter_coliseum_action(PlayerState, Player, ColiseumSceneId, X, Y, Now);
								_ ->
									%% 使用替身
									ColiseumScenePid ! {'COLISEUM_READY_CHECK', Player}
							end;
						true ->
							ColiseumScenePid ! {'COLISEUM_READY_CHECK', Player}
					end;
				_ ->
					skip
			end;
		false ->
			skip
	end;

%% 离开竞技场
handle(49012, PlayerState, _) ->
	NewPlayer = lib_coliseum:coliseum_end(PlayerState),
	{ok, change_status, NewPlayer};

%% 领取竞技场奖励
handle(49014, PlayerState, _) ->
	if
		PlayerState#player_state.coliseum_rank > 0 ->
			lib_coliseum:get_coliseum_award(PlayerState);
		true ->
			Player = PlayerState#player_state.player,
			{ok, BinData} = pt_49:write(49014, [2, 0, 0, 0, 0, 0]),
		   	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
	end;

handle(_Cmd, _PlayerState, _Data) ->
    {error, "handle_pp_coliseum no match"}.
