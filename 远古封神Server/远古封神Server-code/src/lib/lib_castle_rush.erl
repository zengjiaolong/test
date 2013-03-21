%%%--------------------------------------
%%% @Module  : lib_castle_rush
%%% @Author  : ygfs
%%% @Created : 2011.11.16
%%% @Description : 九霄攻城战
%%%--------------------------------------
-module(lib_castle_rush).
-export(
	[
		is_castle_rush_time/0,
		is_castle_rush_join_time/0,
		is_castle_rush_real_start_time/0,
		apply_castle_rush/2,
		start_castle_rush/1,
		broadcast_castle_rush_time/1,
		get_castle_rush_join_list/1,
		enter_castle_rush_scene/3,
		leave_castle_rush/1,
		get_castle_rush_outside/0,
		get_castle_rush_boss_hp/1,
		get_castle_rush_worker_pid/1,
		castle_rush_boss_score/5,
		castle_rush_angry/2,
		init_castle_rush_info/0,
		get_castle_rush_data/2,
		check_enter/5,
		castle_rush_end/0,
		castle_rush_def_feat/0,
		get_castle_rush_guild_rank/1,
		get_castle_rush_player_rank/1,
		get_castle_rush_king/1,
		get_castle_rush_king_id/0,
		get_castle_rush_king_id_data/0,
		get_castle_rush_tax/1,
		get_castle_rush_tax/2,
		castle_rush_king_login_check/2,
		castle_rush_king_login/2,
		castle_rush_mon_revive/0,
		init_castle_rush_data/0,
		get_castle_rush_def_num/2,
		get_castle_rush_award_data/2,
		allot_castle_rush_award/5,
		auto_allot_castle_rush_award/2,
		del_castle_rush_data/0,
		update_castle_rush_angry/4,
		update_castle_rush_angry_effect/4,
		get_mail_date/1,
		castle_rush_att_def/1,
		castle_rush_start/0,
		get_castle_rush_info/0,
		get_castle_rush_repeat_timer/0,
		castle_rush_angry_val/1,
		castle_rush_die/2,
		castle_rush_position/1,
		get_date_list/0,
		get_castle_rush_join_time_dist/1,
		get_castle_rush_time_dist/1,
		get_castle_rush_check_time_dist/1,
		send_to_castle_rush_guild/3,
		init_castle_rush_guild_info/4,
		update_castle_rush_king_info/1
	]
).
-include("common.hrl").
-include("record.hrl").
-include("guild_info.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

-define(CASTLE_RUSH_JOIN_TIME, 73800).							%% 攻城战报名时间
-define(CASTLE_RUSH_START_TIME, 74100).							%% 攻城战开始时间
-define(CASTLE_RUSH_END_TIME, 75300).							%% 攻城战结束时间
-define(CASTLE_RUSH_END_CHECK, 75330).							%% 攻城战结束一分钟后的检

%% -define(CASTLE_RUSH_JOIN_TIME, 20 * 3600 + 35 * 60).						%% 攻城战报名时间
%% -define(CASTLE_RUSH_START_TIME, ?CASTLE_RUSH_JOIN_TIME + 180).						%% 攻城战开始时间
%% -define(CASTLE_RUSH_END_TIME, ?CASTLE_RUSH_START_TIME + 500).						%% 攻城战结束时间
%% -define(CASTLE_RUSH_END_CHECK, ?CASTLE_RUSH_END_TIME + 30).						%% 攻城战结束一分钟后的检

-define(CASTLE_RUSH_FUND, 100000).									%% 报名攻城战所需的资金
-define(CASTLE_RUSH_INTERVAL, 60000).								%% 龙塔间隔

%% 是否在攻城战间
is_castle_rush_time() ->
	NowSec = util:get_today_current_second(),
	NowSec >= ?CASTLE_RUSH_JOIN_TIME andalso NowSec < ?CASTLE_RUSH_END_TIME + 10.

%% 是否攻城战报名时间
is_castle_rush_join_time() ->
	TodaySec = util:get_today_current_second(),
  	TodaySec < ?CASTLE_RUSH_START_TIME orelse TodaySec > ?CASTLE_RUSH_END_TIME.

%% 攻城战是否正式开始（开打时）
is_castle_rush_real_start_time() ->
	TodaySec = util:get_today_current_second(),
	TodaySec >= ?CASTLE_RUSH_START_TIME andalso TodaySec < ?CASTLE_RUSH_END_TIME.	

%% 报名攻城战
%% GuildId 氏族ID
%% PidSend 发送进程
apply_castle_rush(GuildId, PidSend) ->
	Guild = lib_guild_inner:get_guild(GuildId),
    if
        Guild =:= [] ->
			{ok, BinData} = pt_47:write(47002, 0),
			lib_send:send_to_sid(PidSend, BinData);
		%% 氏族等级不足
		Guild#ets_guild.level < 3 ->
			{ok, BinData} = pt_47:write(47002, 5),
			lib_send:send_to_sid(PidSend, BinData);
		%% 氏族资金不足
		Guild#ets_guild.funds < ?CASTLE_RUSH_FUND ->
			{ok, BinData} = pt_47:write(47002, 6),
			lib_send:send_to_sid(PidSend, BinData);
        true ->
			%% 是否已报名
			case is_join_castle_info(GuildId) of
				false ->
                    NewFunds = Guild#ets_guild.funds - ?CASTLE_RUSH_FUND,
                    NewGuild = Guild#ets_guild{
                        funds = NewFunds
                    },
                    %% 更新氏族缓存
                    lib_guild_inner:update_guild(NewGuild),
					
					spawn(fun()-> db_agent:apply_skyrush(guild, [{funds, NewFunds}], [{id, GuildId}]) end),

                    join_castle_rush(NewGuild, GuildId),

					Date = util:get_date(),
					lib_skyrush:skyrush_send_mail(0, 0, GuildId, apply_castle_rush_succeed, [Date]),
                    {ok, BinData} = pt_47:write(47002, 1),
					lib_send:send_to_sid(PidSend, BinData),
					%% 是否已经开始了
					case is_castle_rush_real_start_time() of
						true ->
							ScenePid = mod_scene:get_scene_pid(?CASTLE_RUSH_SCENE_ID, undefined, undefined), 
							{ok, BinData47001} = pt_47:write(47001, [0, 2]),
							gen_server:cast(ScenePid, {apply_cast, lib_castle_rush, init_castle_rush_guild_info, 
									[GuildId, Guild#ets_guild.name, Guild#ets_guild.level, BinData47001]});
						false ->
							skip
					end;
				true ->
					{ok, BinData} = pt_47:write(47002, 2),
					lib_send:send_to_sid(PidSend, BinData)
			end
    end.
	

%% 添加攻城战报名数据
join_castle_rush(Guild, GuildId) ->
	Now = util:unixtime(),
	#ets_guild{
		level = GuildLevel,
		member_num = GuildMemberNum,
		name = GuildName,
		chief_name = ChiefName
	} = Guild,
    CastleRushGuild = #ets_castle_rush_join{
        guild_id = GuildId,                           
        guild_lv = GuildLevel,                           	
        guild_num = GuildMemberNum,                          	
        guild_name = GuildName,                        	
        guild_chief = ChiefName,                       	
        ctime = Now										
    },
    ets:insert(?ETS_CASTLE_RUSH_JOIN, CastleRushGuild),
    %% 添加攻城战报名数据
    spawn(fun()->
        CastleRushList = [GuildId, GuildLevel, GuildMemberNum, GuildName, ChiefName, Now],
        db_agent:castle_rush_join(CastleRushList, GuildId) 
    end).

%% 是否报名攻城战
is_join_castle_info(GuildId) ->
	Ret = db_agent:get_castle_rush_join_by_guild_id(GuildId),
	is_integer(Ret).
%% 	case ets:lookup(?ETS_CASTLE_RUSH_JOIN, GuildId) of
%% 		[] ->
%% 			false;
%% 		_ ->
%% 			true
%% 	end.

%% 判断是否开启攻城战
start_castle_rush(NowSec) ->
	DateList = get_date_list(),
	%% 判断今天星期几
	Date = util:get_date(),
	case lists:member(Date, DateList) of
		true ->
			if
				NowSec >= ?CASTLE_RUSH_JOIN_TIME - 10 andalso NowSec < ?CASTLE_RUSH_JOIN_TIME ->
					mod_castle_rush:start();
				true ->
					skip
			end;
		false ->
			skip
	end.

%% 广播攻城战报名时间
broadcast_castle_rush_time(NowSec) ->
  	LeftTime = ?CASTLE_RUSH_START_TIME - NowSec,
   	{ok, BinData} = pt_47:write(47001, [LeftTime, 1]),
	%% 只对族长或长老广播
	MS = ets:fun2ms(fun(P) when P#player.guild_id > 0, P#player.guild_position > 0, 
								P#player.guild_position < 4 ->
		[
		 	P#player.other#player_other.pid_send,
			P#player.other#player_other.pid_send2,
			P#player.other#player_other.pid_send3
		]
	end),
  	mod_disperse:broadcast_to_ms(ets:tab2list(?ETS_SERVER), BinData, MS),
 	catch lib_send:send_to_ms(BinData, MS).

%% 查看已报名氏族
get_castle_rush_join_list(PidSend) ->
	CastleRushList = get_castle_rush_join_data(),
	{ok, BinData} = pt_47:write(47003, CastleRushList),
	lib_send:send_to_sid(PidSend, BinData).
get_castle_rush_join_data() ->
	case ets:tab2list(?ETS_CASTLE_RUSH_JOIN) of
		[] ->
			case db_agent:get_castle_rush_join_guild_list() of
				[] ->
					[];
				CastleRushList ->
					Fun = fun(C)->
						Castle = list_to_tuple([?ETS_CASTLE_RUSH_JOIN | C]),
  						ets:insert(?ETS_CASTLE_RUSH_JOIN, Castle)
					end,
					lists:foreach(Fun, CastleRushList),
					ets:tab2list(?ETS_CASTLE_RUSH_JOIN)
			end;
		CastleRushList ->
			CastleRushList
	end.

%% 进入攻城战
enter_castle_rush_scene(PlayerState, WinGuildId, WinGuildName) ->
	Player = PlayerState#player_state.player,
	[X, Y, Leader] = 
		case WinGuildId =/= Player#player.guild_id of
			true ->
				[RX, RY] = castle_rush_position(Player#player.realm),
				[RX, RY, 13];
			false ->
				[5, 15, 14]
		end,
	%% 坐标记录
	put(change_scene_xy, [X, Y]),
	{ok, BinData} = pt_12:write(12005, [?CASTLE_RUSH_SCENE_ID, X, Y, <<>>, ?CASTLE_RUSH_SCENE_ID, 0, 0, Leader]),
   	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),	
  	%% 告诉原来场景玩家你已经离开
	pp_scene:handle(12004, Player, Player#player.scene),
	%%挂机区进入战场
	lib_scene:set_hooking_state(Player,?CASTLE_RUSH_SCENE_ID),
  	%% 修改为氏族模式
	PkMode = 3,
		if
			Player#player.pk_mode =/= PkMode ->
				{ok, PkModeBinData} = pt_13:write(13012, [1, PkMode]),
				lib_send:send_to_sid(Player#player.other#player_other.pid_send, PkModeBinData);
			true ->
				skip
		end,
	%% 攻城剩余时间
	NowSec = util:get_today_current_second(),
	LeftTime = ?CASTLE_RUSH_END_TIME - NowSec,
	{ok, BinData47001} = pt_47:write(47001, [LeftTime, 3]),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData47001),
	%% 
	{ok, BinData47008} = pt_47:write(47008, WinGuildName),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData47008),
	spawn(fun()->
		db_agent:mm_update_player_info([{scene, ?CASTLE_RUSH_SCENE_ID}, {x, X}, {y, Y}, {pk_mode, PkMode}], [{id, Player#player.id}])	  
	end),
	%% 获取氏族怒气
	CastleRushPid = get_castle_rush_worker_pid(Player#player.guild_id),
	case is_pid(CastleRushPid) of
		true ->
			CastleRushPid ! {'GET_CASTLE_RUSH_ANGRY', Player#player.other#player_other.pid_send};
		false ->
			skip
	end,
	
	%% 判断是否在挂机
	HookPlayer = lib_hook:cancel_hoook_status(Player),
	
	NewPlayer = HookPlayer#player{
		scene = ?CASTLE_RUSH_SCENE_ID, 
		x = X, 
		y = Y,
		pk_mode = PkMode,
		other = HookPlayer#player.other#player_other{
   			leader = Leader 
      	}
	},
	List = [
		{scene, NewPlayer#player.scene},
		{x, NewPlayer#player.x},
		{y, NewPlayer#player.y},
		{status, NewPlayer#player.status},
		{pk_mode, PkMode},
		{leader, NewPlayer#player.other#player_other.leader}
	],
	mod_player:save_online_info_fields(NewPlayer, List),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer
	},
	{ok, change_player_state, NewPlayerState}.

%% 离开攻城战
leave_castle_rush(Player) ->
  	RetPlayer = 
        case Player#player.scene =:= ?CASTLE_RUSH_SCENE_ID of
            true ->
                [SceneId, X, Y] = get_castle_rush_outside(),
                NewPlayer = Player#player{
                    scene = SceneId,
                    x = X,
                    y = Y,
                    hp = Player#player.hp_lim,
                    mp = Player#player.mp_lim,
                    status = 0,
                    other = Player#player.other#player_other{
                        pid_dungeon = undefined,
						leader = 0 
                    }
                },
                lib_player:send_player_attribute2(NewPlayer, 2),
                {ok, BinData} = pt_12:write(12005, [SceneId, X, Y, <<>>, SceneId, 0, 0, 0]),
                lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send, BinData),
                %% 告诉原来场景玩家你已经离开
                pp_scene:handle(12004, Player, Player#player.scene),
                NewPlayer;
            false ->
                Player
        end,
	Leader =
		if
			Player#player.other#player_other.leader =:= 13 orelse Player#player.other#player_other.leader =:= 14 ->
				0;
			true ->
				Player#player.other#player_other.leader
		end,
	
	Buff = Player#player.other#player_other.battle_status,
	RetBuff = 
		case lists:keyfind(castle_rush_att, 1, Buff) of
			false ->
				lists:keydelete(castle_rush_anti, 1, Buff);
			_AngrySkillBuff ->
				AttBuff = lists:keydelete(castle_rush_att, 1, Buff),
				lists:keydelete(castle_rush_anti, 1, AttBuff)
		end,
	Now = util:unixtime(),
	NewBuff = [{K, V, T, S, L} || {K, V, T, S, L} <- RetBuff, T > Now],
    {ok, BuffBinData} = pt_13:write(13013, [NewBuff, Now]),
    lib_send:send_to_sid(RetPlayer#player.other#player_other.pid_send, BuffBinData),
	
	NewRetPlayer = RetPlayer#player{
		other = RetPlayer#player.other#player_other{
			leader = Leader,
			battle_status = NewBuff
    	}								
	},
	%% 重新计算人物属性
	CountPlayer = lib_player:count_player_attribute(NewRetPlayer),
	lib_player:send_player_attribute(CountPlayer, 2),
	mod_player:save_online_diff(Player, CountPlayer),
	CountPlayer.

%% 获取龙塔气血值
get_castle_rush_boss_hp(MonHp) ->
	case db_agent:get_castle_rush_info_by_field("boss_hp") of
		0 ->
			MonHp;
		null ->
			db_agent:init_castle_rush_info(MonHp),
			MonHp;
		Hp ->
			case is_integer(Hp) of
				true ->
					Hp;
				false ->
					MonHp
			end
	end.

%% 获取攻城战工作进程
get_castle_rush_worker_pid(GuildId) ->
	WorkerId = GuildId + ?SCENE_WORKER_NUMBER,
	ProcessName = misc:create_process_name(scene_p, [?CASTLE_RUSH_SCENE_ID, WorkerId]),
	Pid = misc:whereis_name({global, ProcessName}),
	case is_pid(Pid) of
		true ->
			Pid;
		false ->
			get_castle_rush_scene_pid(?CASTLE_RUSH_SCENE_ID)
	end.
get_castle_rush_scene_pid(SceneId) ->
	SceneProcessName = misc:create_process_name(scene_p, [SceneId, 0]),
	Pid = misc:whereis_name({global, SceneProcessName}),
	case misc:is_process_alive(Pid) of
		false ->
 			WorkerId = random:uniform(?SCENE_WORKER_NUMBER),
			SceneProcess_Name = misc:create_process_name(scene_p, [SceneId, WorkerId]),
    		misc:whereis_name({global, SceneProcess_Name});
		true ->
			Pid
	end.


%% 攻城战伤害积分
castle_rush_boss_score(PlayerId, SceneId, Harm, MonHpLim, IsAlive) ->
	case lib_mon:get_player(PlayerId, SceneId)  of
		[] ->
			skip;
		Player ->
			GuildId = Player#player.guild_id,
			%% 伤害积分
			case ets:lookup(?ETS_CASTLE_RUSH_HARM_SCORE, GuildId) of
				[] ->
					skip;
				[CastleRushHarmScore | _] ->
					HarmScore = 
						case IsAlive of
							true ->
								CastleRushHarmScore#ets_castle_rush_harm_score.score;
							false ->
								CastleRushHarmScore#ets_castle_rush_harm_score.score + trunc(MonHpLim * 0.05)
						end,
					NewCastleRushHarmScore = CastleRushHarmScore#ets_castle_rush_harm_score{
						score = Harm + HarmScore
       				},
					ets:insert(?ETS_CASTLE_RUSH_HARM_SCORE, NewCastleRushHarmScore)
			end,
			
			%% 氏族战功
			case ets:lookup(?ETS_CASTLE_RUSH_GUILD_SCORE, GuildId) of
				[] ->
					skip;
				[CastleRushGuildScore | _] ->
					GuildHpLimParam = trunc(MonHpLim * 0.01),
					%% 当前击杀BOSS的血量
					GuildHp = Harm + CastleRushGuildScore#ets_castle_rush_guild_score.hp,
					[NewGuildHp, GuildScore] = compare_hp_harm(GuildHp, CastleRushGuildScore#ets_castle_rush_guild_score.score, GuildHpLimParam, 100),
					NewGuildScore = 
						case IsAlive of
							true ->
								GuildScore;
							%% 最后一击加100氏族功勋
							false ->
								100 + GuildScore
						end,
					NewCastleRushGuildScore = CastleRushGuildScore#ets_castle_rush_guild_score{
						score = NewGuildScore,
						hp = NewGuildHp
       				},
					ets:insert(?ETS_CASTLE_RUSH_GUILD_SCORE, NewCastleRushGuildScore)
			end,
			
			%% 个人战功
			CastleRushPlayer = 
				case ets:lookup(?ETS_CASTLE_RUSH_PLAYER_SCORE, PlayerId) of
					[] ->
						#ets_castle_rush_player_score{
      						player_id = PlayerId,                           
       						nickname = Player#player.nickname,
							career = Player#player.career,
							lv = Player#player.lv                      	
       					};
					[CRP | _] ->
						CRP
				end,
			PlayerHpLimParam = trunc(MonHpLim * 0.001),
			%% 当前击杀BOSS的血量
			Spirit = trunc(Harm * 0.5),
			gen_server:cast(Player#player.other#player_other.pid, {'CASTLE_RUSH_SPIRIT', Spirit}),
			PlayerHp = Harm + CastleRushPlayer#ets_castle_rush_player_score.hp,
			[NewPlayerHp, PlayerScore] =
				case IsAlive of
					true ->
						compare_hp_harm(PlayerHp, CastleRushPlayer#ets_castle_rush_player_score.score, PlayerHpLimParam, 2);
					false ->
						[0, 100 + CastleRushPlayer#ets_castle_rush_player_score.score]
				end,
			NewCastleRushPlayer = CastleRushPlayer#ets_castle_rush_player_score{
				score = PlayerScore,
				hp = NewPlayerHp
       		},
			ets:insert(?ETS_CASTLE_RUSH_PLAYER_SCORE, NewCastleRushPlayer),
			
			case IsAlive of
				true ->
					skip;
				false ->
					castle_rush_boss_die_handle(Player)
			end
	end.

compare_hp_harm(GuildHp, HpScore, GuildHpLimParam, Score) ->
	if
		GuildHp < GuildHpLimParam ->
			[GuildHp, HpScore];
		true ->
			compare_hp_harm(GuildHp - GuildHpLimParam, HpScore + Score, GuildHpLimParam, Score)
	end.


%% 龙塔死亡处理
castle_rush_boss_die_handle(Player) ->
	CastleRushInfo = get_castle_rush_info(),
	%% 上一次攻城战守方
	LastWinGuildId = CastleRushInfo#ets_castle_rush_info.win_guild,
	%% 伤害最高的氏族ID
	GuildList = ets:tab2list(?ETS_CASTLE_RUSH_HARM_SCORE),
	[TopHarmGuildId, TopHarmGuildName, _NewGuildList] = handle_harm_guild_list(GuildList, 0, 0, "", []),
	%% 更新攻城战信息
	spawn(fun()-> db_agent:update_castle_rush_info([{win_guild, TopHarmGuildId}]) end),
	NewCastleRushInfo = CastleRushInfo#ets_castle_rush_info{
		win_guild = TopHarmGuildId
	},
	ets:insert(?ETS_CASTLE_RUSH_INFO, NewCastleRushInfo),
	
	%% %% 龙塔攻防间隔定时器更换
	SceneProcessName = misc:create_process_name(scene_p, [?CASTLE_RUSH_SCENE_ID, 0]),
	CastleRushMainPid = misc:whereis_name({global, SceneProcessName}),
	case is_pid(CastleRushMainPid) of
		true ->
			CastleRushMainPid ! 'CASTLE_RUSH_ATT_DEF_REPEAT';
		false ->
			skip
	end,
	
	%% 更新伤害积分列表
	MS = ets:fun2ms(fun(P) when P#player.scene == ?CASTLE_RUSH_SCENE_ID ->
		P 
	end),
	PlayerList = ets:select(?ETS_ONLINE_SCENE, MS),
	{ok, BinData47007} = pt_47:write(47007, 2),
	{ok, BinData47008} = pt_47:write(47008, TopHarmGuildName),
	Msg = io_lib:format("<font color='#FEDB4F'>~s</font> 氏族给予了龙柱最后一击，获得了巨大的伤害积分。", [Player#player.guild_name]),
	{ok, MsgBinData} = pt_11:write(11080, 2, Msg),
	Fun = fun(P)->
		%% 攻城战回合重新开始转移玩家位置
		Buff = P#player.other#player_other.battle_status,
		NewBuff = 
			case lists:keyfind(castle_rush_att, 1, Buff) of
				false ->
					Buff;
				{_SkillKey, _SkillAntiVal, EndTime, SkillId, SkillLv} ->
					[SkillAttVal, SkillAntiVal] = lib_castle_rush:castle_rush_angry_val(SkillId),
					AttBuff = lists:keydelete(castle_rush_att, 1, Buff),
					AntiBuff = lists:keydelete(castle_rush_anti, 1, AttBuff),
					NewAttBuff = [{castle_rush_att, SkillAttVal, EndTime, SkillId, SkillLv} | AntiBuff],
					[{castle_rush_anti, SkillAntiVal, EndTime, SkillId, SkillLv} | NewAttBuff]
			end,
		[X, Y] = castle_rush_position(P#player.realm),
		gen_server:cast(P#player.other#player_other.pid, {'CASTLE_RUSH_ROUND_REPEAT', X, Y, NewBuff, TopHarmGuildId}),
		lib_send:send_to_sid(P#player.other#player_other.pid_send, BinData47007),
		lib_send:send_to_sid(P#player.other#player_other.pid_send, BinData47008),
		lib_send:send_to_sid(P#player.other#player_other.pid_send, MsgBinData),
		if
			P#player.guild_id =/= TopHarmGuildId ->
				if
					P#player.guild_id =:= LastWinGuildId ->
						{ok, BinData47014} = pt_47:write(47014, [P#player.id, 2]),
						lib_send:send_to_online_scene(?CASTLE_RUSH_SCENE_ID, P#player.x, P#player.y, BinData47014);
					true ->
						skip
				end,
				NP = P#player{
					x = X,
					y = Y,
					other = P#player.other#player_other{
						leader = 13,
						battle_status = NewBuff									  
   					}
				},
				ets:insert(?ETS_ONLINE_SCENE, NP);
			true ->
				{ok, BinData47014} = pt_47:write(47014, [P#player.id, 1]),
				lib_send:send_to_online_scene(?CASTLE_RUSH_SCENE_ID, P#player.x, P#player.y, BinData47014),
				NP = P#player{
					other = P#player.other#player_other{
						leader = 14,
						battle_status = NewBuff									  
   					}
				},
				ets:insert(?ETS_ONLINE_SCENE, NP)
		end
	end,
	[Fun(P) || P <- PlayerList].

%% 伤害积分处理
handle_harm_guild_list([], _Score, TopHarmGuildId, TopHarmGuildName, RetGuildList) ->
	[TopHarmGuildId, TopHarmGuildName, RetGuildList];
handle_harm_guild_list([G | GuildList], Score, TopHarmGuildId, TopHarmGuildName, RetGuildList) ->
	NG = G#ets_castle_rush_harm_score{
		score = 0								  
	},
	ets:insert(?ETS_CASTLE_RUSH_HARM_SCORE, NG),
	NewRetGuildList = [NG | RetGuildList],
	if
		G#ets_castle_rush_harm_score.score > Score ->
			handle_harm_guild_list(GuildList, G#ets_castle_rush_harm_score.score, G#ets_castle_rush_harm_score.guild_id, G#ets_castle_rush_harm_score.guild_name, NewRetGuildList);
		true ->
			handle_harm_guild_list(GuildList, Score, TopHarmGuildId, TopHarmGuildName, NewRetGuildList)
	end.

%% 攻城战怒气技能使用
castle_rush_angry(GuildId, AngryParam) ->
	MS = ets:fun2ms(fun(P) when P#player.scene == ?CASTLE_RUSH_SCENE_ID	andalso P#player.guild_id =:= GuildId ->
		[
			P#player.id,
			P#player.hp,
			P#player.mp,
			P#player.guild_position,
		 	P#player.other#player_other.pid
		] 
	end),
	PlayerList = ets:select(?ETS_ONLINE_SCENE, MS),
	Guild = lib_guild_inner:get_guild(GuildId),
	SkillId =
		if
            Guild =:= [] ->
           		10073;
			true ->
				Guild#ets_guild.level + 10072
		end,
	Fun = fun([PlayerId, Hp, Mp, GuildPosition, Pid], [PrePlayerId, PreMp, PreGuildPosition, Ret])->
		gen_server:cast(Pid, {'CASTLE_RUSH_ANGRY', SkillId, AngryParam}),
		if
			PreGuildPosition > GuildPosition ->
				[PlayerId, Mp, GuildPosition ,[[PlayerId, Hp] | Ret]];
			true ->
				[PrePlayerId, PreMp, PreGuildPosition, [[PlayerId, Hp] | Ret]]
		end
	end,
	[AngryId, AngryMp, _GuildPosition, AngryResult] = lists:foldl(Fun, [0, 0, 10000, []], PlayerList),
	{ok, BinData} = pt_20:write(20006, [AngryId, 10073, 1, AngryMp, AngryResult]),
	lib_send:send_to_online_scene(?CASTLE_RUSH_SCENE_ID, BinData).


%% 获取攻城战数据
get_castle_rush_data(Type, PidSend) ->
	{ok, BinData} = pt_47:write(47007, Type),
	lib_send:send_to_sid(PidSend, BinData).

%% 攻城战进入检查
check_enter(PlayerId, NickName, Career, Lv, GuildId) ->
    case is_join_castle_info(GuildId) of
        true ->
			CastleRushInfo = get_castle_rush_info(),
            WinGuild = lib_guild_inner:get_guild(CastleRushInfo#ets_castle_rush_info.win_guild),
			WinGuildName = 
				if
					WinGuild =:= [] ->
						"";
					true ->
						WinGuild#ets_guild.name
				end,
            %% 个人战功
            case ets:lookup(?ETS_CASTLE_RUSH_PLAYER_SCORE, PlayerId) of
                [] ->
                    CastleRushPlayer = #ets_castle_rush_player_score{
                        player_id = PlayerId,
                        nickname = NickName,
                        guild_id = GuildId,
                        career = Career,
                        lv = Lv                      	
                    },
                    ets:insert(?ETS_CASTLE_RUSH_PLAYER_SCORE, CastleRushPlayer);
                _CastleRushPlayer ->
                    skip
            end,
            %% 氏族战功
            case ets:lookup(?ETS_CASTLE_RUSH_GUILD_SCORE, GuildId) of
                [] ->
                    skip;
                [CastleRushGuildScore | _] ->
                    GuildMember = 
                        case lists:member(PlayerId, CastleRushGuildScore#ets_castle_rush_guild_score.member) of
                            false ->
                                [PlayerId | CastleRushGuildScore#ets_castle_rush_guild_score.member];
                            _GuildMember ->
                                CastleRushGuildScore#ets_castle_rush_guild_score.member
                        end,
                    NewCastleRushGuildScore = CastleRushGuildScore#ets_castle_rush_guild_score{
                        member = GuildMember
                    },
                    ets:insert(?ETS_CASTLE_RUSH_GUILD_SCORE, NewCastleRushGuildScore)
            end,
            [1, CastleRushInfo#ets_castle_rush_info.win_guild, WinGuildName];
        false ->
            [2, 0]
    end.


%% 获取攻城战信息
get_castle_rush_info() ->
	case ets:tab2list(?ETS_CASTLE_RUSH_INFO) of
		[] ->
			init_castle_rush_info();
		[CastleRushInfo | _] ->
			CastleRushInfo
	end.

%% 加载攻城战初始数据
init_castle_rush_info() ->
	RetCastleRushInfo = 
		case db_agent:get_castle_rush_info() of
			[] ->
				#ets_castle_rush_info{};
			CastleRushInfo ->
				NewCastleRushInfo = list_to_tuple([?ETS_CASTLE_RUSH_INFO | CastleRushInfo]),
				NewCastleRushInfo#ets_castle_rush_info{
					king = util:string_to_term(tool:to_list(NewCastleRushInfo#ets_castle_rush_info.king))								   
				}
		end,
	ets:insert(?ETS_CASTLE_RUSH_INFO, RetCastleRushInfo),
	RetCastleRushInfo.


%% 攻城战结束
castle_rush_end() ->
	CastleRushInfo = get_castle_rush_info(),
	Guild = lib_guild_inner:get_guild(CastleRushInfo#ets_castle_rush_info.win_guild),
	
	%% 清除龙塔
	MonMS = ets:fun2ms(fun(M) when M#ets_mon.scene == ?CASTLE_RUSH_SCENE_ID ->
		M#ets_mon.pid
	end),
	MonList = ets:select(?ETS_SCENE_MON, MonMS),
	MonFun = fun(MonPid) ->
		case is_pid(MonPid) of
			true ->
				MonPid ! 'CLEAR_MON';
			false ->
				skip
		end
	end,
	[MonFun(M) || M <- MonList],
	
	MS = ets:fun2ms(fun(P) when P#player.scene == ?CASTLE_RUSH_SCENE_ID ->
		P#player.other#player_other.pid_send
	end),
	PlayerList = ets:select(?ETS_ONLINE_SCENE, MS),
	
	%% 更新攻城战排行榜（同时发送结束信号给前端）
	spawn(fun()-> update_castle_rush_rank(PlayerList) end),
	
	%% 更新攻城战报名数据
	spawn(fun()-> db_agent:delete_castle_rush_join_list() end),
	catch ets:delete_all_objects(?ETS_CASTLE_RUSH_JOIN),
	
	if
   		Guild =:= [] ->
      		skip;
		true ->
			%% 更新九霄城霸主
			update_castle_rush_king(CastleRushInfo, Guild#ets_guild.chief_id),
			%% 第一名直接报名下一次攻城战
			join_castle_rush(Guild, CastleRushInfo#ets_castle_rush_info.win_guild),
			%% 第一名广播
			Msg = io_lib:format("恭喜 <font color='#FEDB4F'>~s</font> 氏族成功地守护了九霄龙柱，占领了九霄城！", [Guild#ets_guild.name]),
			lib_chat:broadcast_sys_msg(1, Msg)
	end.


%% 更新城战信息
update_castle_rush_king_info(GuildId) ->
	NewGuildId = tool:to_integer(GuildId),
	case lib_guild_inner:get_guild(NewGuildId) of
		[] ->
			skip;
		Guild ->
			CastleRushInfo = get_castle_rush_info(),
			%% 更新九霄城霸主信息
			update_castle_rush_king(CastleRushInfo, Guild#ets_guild.chief_id, NewGuildId, 0)
	end.

%% 更新九霄城霸主
%% GuildChiefId 氏族族长ID
update_castle_rush_king(CastleRushInfo, GuildChiefId) ->
	%% 氏族霸主标识更换
	if
		CastleRushInfo#ets_castle_rush_info.win_guild =/= CastleRushInfo#ets_castle_rush_info.last_win_guild ->
			change_castle_rush_king(CastleRushInfo#ets_castle_rush_info.win_guild, 1),
			change_castle_rush_king(CastleRushInfo#ets_castle_rush_info.last_win_guild, 0);
		true ->
			skip
	end,
	%% 更新九霄城霸主信息
	update_castle_rush_king(CastleRushInfo, GuildChiefId, CastleRushInfo#ets_castle_rush_info.win_guild, 1).

update_castle_rush_king(CastleRushInfo, GuildChiefId, GuildId, FromType) ->
	[Player, SuitId, Stren, EquipCurrent] =
		case lib_player:get_online_info(GuildChiefId) of
			[] ->
				GuildChiefInfo = lib_account:get_info_by_id(GuildChiefId),
				GuildChiefer = list_to_tuple([player | GuildChiefInfo]),
				EquipSuit = goods_util:get_equip_suit(GuildChiefId),
				ChiefSuitId = goods_util:is_full_suit(EquipSuit),
				ChiefStren = lib_goods:get_player_stren_eff(GuildChiefId),
				%% 获取时装ID
				GoodsStatus = #goods_status{
					player_id = GuildChiefId, 
					equip_current = [0,0,0], 
					equip_suit = EquipSuit
				},
    			NewGoodsStatus = goods_util:get_current_equip(GoodsStatus),
				[GuildChiefer, ChiefSuitId, ChiefStren, NewGoodsStatus#goods_status.equip_current];
			GuildChiefer ->
				[GuildChiefer, GuildChiefer#player.other#player_other.suitid, GuildChiefer#player.other#player_other.stren, GuildChiefer#player.other#player_other.equip_current]
		end,
	Career = 
		case EquipCurrent of
			[_Wq, 0, _Fbyf, _Spyf, _Zq] ->
				Player#player.career;
			[_Wq, Yf, _Fbyf, _Spyf, _Zq] ->
				Yf;
			_ ->
				Player#player.career
		end,
	Light = data_fst:get_suit_light(SuitId, Stren),
	CastleRushKing = [
		Player#player.lv,
		Player#player.realm,
		Career,
		Player#player.sex,
		Light,
		Player#player.nickname,
		Player#player.guild_name			  
	],
	NewCastleRushKing = util:term_to_string(CastleRushKing),
	CastleRushList = [
		{win_guild, GuildId},
		{last_win_guild, GuildId},
		{king, NewCastleRushKing},
		{king_id, Player#player.id}
	],
	spawn(fun()-> db_agent:update_castle_rush_info(CastleRushList) end),
	NewCastleRushInfo = CastleRushInfo#ets_castle_rush_info{
		win_guild = GuildId,
		last_win_guild = GuildId,
		king = CastleRushKing,
		king_id = Player#player.id														
	},
	ets:insert(?ETS_CASTLE_RUSH_INFO, NewCastleRushInfo),
	if
		FromType =:= 1 ->
			spawn(fun()->
				%% 世界播报新霸主
				DataList = [
					Player#player.guild_name,
					Player#player.id,
		      		Player#player.nickname,
		     		Player#player.career,
		    		Player#player.sex, 
		      		Player#player.nickname		
				],
				Msg = io_lib:format("恭喜 <font color='#FEDB4F'>~s</font> 氏族的 <a href='event:1, ~p, ~s, ~p, ~p'><font color='#FEDB4F'>~s</font></a> 成为九霄城城主", DataList),
				lib_chat:broadcast_sys_msg(1, Msg)		  
			end);
		true ->
			skip
	end.
	

%% 更新攻城战排行榜（同时发送结束信号给前端）
update_castle_rush_rank(PlayerList) ->
	%% 更新氏族战功排行
	CastleRushGuildData = ets:tab2list(?ETS_CASTLE_RUSH_GUILD_SCORE),
	if
		length(CastleRushGuildData) > 0 ->
			db_agent:del_castle_rush_guild_rank(),
			CastleRushGuildFun = fun(C, CastleRushGuildList) ->
                Member =
                    case is_list(C#ets_castle_rush_guild_score.member) of
                        true ->
                            length(C#ets_castle_rush_guild_score.member);
                        false ->
                            1
                    end,
                CastleRushData = [
                    C#ets_castle_rush_guild_score.guild_id,
                    C#ets_castle_rush_guild_score.guild_name,
                    C#ets_castle_rush_guild_score.guild_lv,
                    Member,
                    C#ets_castle_rush_guild_score.score			  
                ],
                spawn(fun()-> db_agent:insert_castle_rush_guild_data(CastleRushData) end),
				[CastleRushData | CastleRushGuildList]
            end,
			CastleRushGuildList = lists:foldl(CastleRushGuildFun, [], CastleRushGuildData),
			NewCastleRushGuildList = sort_castle_rush_guild_rank(CastleRushGuildList),
			%% 奖励分配
%% 			spawn(fun()-> castle_rush_award_allot(NewCastleRushGuildList) end),
			castle_rush_award_allot(NewCastleRushGuildList),
			update_castle_rush_guild_rank(NewCastleRushGuildList);
		true ->
			skip
	end,
	
	%% 更新个人战功排行
	CastleRushPlayerData = ets:tab2list(?ETS_CASTLE_RUSH_PLAYER_SCORE),
	if
		length(CastleRushPlayerData) > 0 ->
			db_agent:del_castle_rush_player_rank(),
			CastleRushPlayerFun = fun(C, CastleRushPlayerList) ->
                %% 氏族战功
%%                 GuildScore = C#ets_castle_rush_player_score.guild_score,
				GuildScore = 
					case ets:lookup(?ETS_CASTLE_RUSH_GUILD_SCORE, C#ets_castle_rush_player_score.guild_id) of
						[] ->
							0;
						[CastleRushGuildScore | _] ->
							CastleRushGuildScore#ets_castle_rush_guild_score.score
					end,
                %% 个人战功
                Score = C#ets_castle_rush_player_score.score,
                Feats = trunc(500 * GuildScore / (GuildScore + 8000) + 200 * Score / (Score + 350)),
				%% 添加攻城战功勋
				spawn(fun()-> update_castle_rush_feat(C#ets_castle_rush_player_score.guild_id, C#ets_castle_rush_player_score.player_id, Feats) end),
								  
                CastleRushData = [
                    C#ets_castle_rush_player_score.player_id,
                    C#ets_castle_rush_player_score.nickname,
					C#ets_castle_rush_player_score.guild_id,
                    C#ets_castle_rush_player_score.career,
                    C#ets_castle_rush_player_score.lv,
                    C#ets_castle_rush_player_score.kill,
                    C#ets_castle_rush_player_score.die,
                    GuildScore,
                    Score,
                    Feats
                ],
                spawn(fun()-> db_agent:insert_castle_rush_player_data(CastleRushData) end),
				[CastleRushData | CastleRushPlayerList]
            end,
			CastleRushPlayerList = lists:foldl(CastleRushPlayerFun, [], CastleRushPlayerData),
			update_castle_rush_player_rank(CastleRushPlayerList);
		true ->
			skip
	end,
	%% 发送结束信号给前端
	{ok, BinData} = pt_47:write(47001, [0, 4]),
	Fun = fun(PidSend) ->
		lib_send:send_to_sid(PidSend, BinData)		  
	end,
	lists:foreach(Fun, PlayerList).

%% 添加攻城战功勋
update_castle_rush_feat(GuildId, PlayerId, Feat) ->
	case lib_guild_inner:get_guild_member_by_guildandplayer_id(GuildId, PlayerId) of
		[] ->
			skip;
		GuildMember ->
			GuildFeat = GuildMember#ets_guild_member.feats_all + Feat,
			NewGuildMember = GuildMember#ets_guild_member{
				feats_all = GuildFeat
			},
			db_agent:update_sky_guild(guild_member, [{feats_all, GuildFeat}], [{player_id, PlayerId}]),
			lib_guild_inner:update_guild_member(NewGuildMember),
			%% 同步更新玩家功勋信息
			lib_skyrush:sync_member_feats(PlayerId, GuildFeat)
	end.

%% 分配奖励
castle_rush_award_allot(CastleRushGuildList) ->
	castle_rush_award_allot_loop(?CASTLE_RUSH_AWARD_GOODS, CastleRushGuildList).
castle_rush_award_allot_loop([], _CastleRushGuildList) ->
	ets:delete_all_objects(?ETS_CASTLE_RUSH_AWARD_MEMBER);
castle_rush_award_allot_loop(_CastleRushAwardGoods, []) ->
	ets:delete_all_objects(?ETS_CASTLE_RUSH_AWARD_MEMBER);
castle_rush_award_allot_loop(CastleRushAwardGoods, [CastleRushData | G]) ->
	[GuildId | _] = CastleRushData,
	case lib_guild_inner:get_guild(GuildId) of
		[] ->
			castle_rush_award_allot_loop(CastleRushAwardGoods, G);
		Guild ->
			[Award | A] = CastleRushAwardGoods,
			NewAward = util:term_to_string(Award),
			NewGuild = Guild#ets_guild{
				castle_rush_award = NewAward						   
			},
			spawn(fun()-> db_agent:update_sky_guild(guild, [{castle_rush_award, NewAward}], [{id, GuildId}]) end),
			lib_guild_inner:update_guild(NewGuild),
			castle_rush_award_allot_loop(A, G)
	end.

%% 攻城战防守方增加防御
castle_rush_def_feat() ->
	CastleRushInfo = get_castle_rush_info(),
	GuildId = CastleRushInfo#ets_castle_rush_info.win_guild,
	%% 氏族战功
    case ets:lookup(?ETS_CASTLE_RUSH_GUILD_SCORE, GuildId) of
        [] ->
            skip;
        [CastleRushGuildScore | _] ->
            NewCastleRushGuildScore = CastleRushGuildScore#ets_castle_rush_guild_score{
                score = CastleRushGuildScore#ets_castle_rush_guild_score.score + 500
            },
            ets:insert(?ETS_CASTLE_RUSH_GUILD_SCORE, NewCastleRushGuildScore)
    end.
	
%% 攻城战登陆检查
castle_rush_login_check(Player, NowSec) ->
	%% 是否在报名时间
	Date = util:get_date(),
	DateList = get_date_list(),
	case lists:member(Date, DateList) of
		true ->
            case NowSec >= ?CASTLE_RUSH_JOIN_TIME andalso NowSec < ?CASTLE_RUSH_START_TIME of
                true ->
                    LeftTime = ?CASTLE_RUSH_START_TIME - NowSec,
                    {ok, BinData} = pt_47:write(47001, [LeftTime, 1]),
                    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
                false ->
                    case is_castle_rush_real_start_time() of
                        true ->
                            LeftTime = ?CASTLE_RUSH_END_TIME - NowSec,
                            {ok, BinData} = pt_47:write(47001, [LeftTime, 3]),
                            lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
                        false ->
                            skip
                    end
            end;
		false ->
			skip
	end.

%% 获取攻城战氏族战功排行数据
get_castle_rush_guild_rank(PidSend) ->
%% io:format("get_castle_rush_guild_rank ----- ~p~n", [ets:lookup(?ETS_CASTLE_RUSH_RANK, 1)]),
	CastleRushGuildBinData = 
        case ets:lookup(?ETS_CASTLE_RUSH_RANK, 1) of
            [] ->
                CastleRushGuildList =
                    case db_agent:get_castle_rush_guild_rank() of
                        [] ->
                            [];
                        CRGL ->
                            CRGL
                    end,
				NewCastleRushGuildList = sort_castle_rush_guild_rank(CastleRushGuildList),
                update_castle_rush_guild_rank(NewCastleRushGuildList);
            [CastleRushRank | _] ->
                CastleRushRank#ets_castle_rush_rank.data
        end,
	lib_send:send_to_sid(PidSend, CastleRushGuildBinData).


%% 更新攻城战氏族排行的ETS数据
update_castle_rush_guild_rank(CastleRushGuildData) ->
	{ok, CastleRushGuildBinData} = pt_47:write(47005, CastleRushGuildData),
    CastleRushRank = #ets_castle_rush_rank{
        id = 1,
        data = CastleRushGuildBinData										
    },
    ets:insert(?ETS_CASTLE_RUSH_RANK, CastleRushRank),
	CastleRushGuildBinData.

%% 排序攻城战氏族排行
sort_castle_rush_guild_rank(CastleRushGuildList) ->
	SortGuildFun = fun([_, _, Lv1, Member1, Score1], [_, _, Lv2, Member2, Score2]) -> 
        if 
            Score1 =/= Score2 ->
                Score1 > Score2;
            true ->
                if
                    Lv1 =/= Lv2 ->
                        Lv1 > Lv2;	
                    true ->
                        Member1 > Member2
                end
        end
    end,
    lists:sort(SortGuildFun, CastleRushGuildList).

%% 获取攻城战个人战功排行数据
get_castle_rush_player_rank(PidSend) ->
	CastleRushPlayerBinData = 
        case ets:lookup(?ETS_CASTLE_RUSH_RANK, 2) of
            [] ->
                CastleRushPlayerList = 
                    case db_agent:get_castle_rush_player_rank() of
                        [] ->
                            [];
                        CRPL ->
                            CRPL
                    end,
                update_castle_rush_player_rank(CastleRushPlayerList);
            [CastleRushRank | _] ->
                CastleRushRank#ets_castle_rush_rank.data
        end,
%% io:format("get_castle_rush_player_rank ----- ~p~n", [CastleRushPlayerBinData]),
	lib_send:send_to_sid(PidSend, CastleRushPlayerBinData).


%% 更新攻城战个人排行的ETS数据
update_castle_rush_player_rank(CastleRushPlayerList) ->
	SortPlayerFun = fun([_PlayerId1, _NickName1, _GuildId1, _Career1, Lv1, Kill1, Die1, GuildScore1, Score1, Feats1], [_PlayerId2, _NickName2, _GuildId2, _Career2, Lv2, Kill2, Die2, GuildScore2, Score2, Feats2]) -> 
        if 
            Feats1 =/= Feats2 ->
                Feats1 > Feats2;
            true ->
                if
                    GuildScore1 =/= GuildScore2 ->
                        GuildScore1 > GuildScore2;	
                    true ->
                        if
                            Score1 =/= Score2 ->
                                Score1 > Score2;
                            true ->
                                if
                                    Kill1 =/= Kill2 ->
                                        Kill1 > Kill2;
                                    true ->
                                        if
                                            Die1 =/= Die2 ->
                                                Die1 > Die2;
                                            true ->
                                                Lv1 > Lv2
                                        end
                                end
                        end
                end
        end
    end,
    NewCastleRushPlayerData = lists:sort(SortPlayerFun, CastleRushPlayerList),
	{ok, NewCastleRushPlayerBinData} = pt_47:write(47006, NewCastleRushPlayerData),
    CastleRushRank = #ets_castle_rush_rank{
        id = 2,
        data = NewCastleRushPlayerBinData										
    },
    ets:insert(?ETS_CASTLE_RUSH_RANK, CastleRushRank),
	NewCastleRushPlayerBinData.


%% 攻城战霸主信息
get_castle_rush_king(PidSend) ->
	CastleRushInfo = get_castle_rush_info(),
	case CastleRushInfo#ets_castle_rush_info.king of
		[] ->
			skip;
		_ ->
			{ok, CastleRushBinData} = pt_47:write(47013, CastleRushInfo#ets_castle_rush_info.king),
  			lib_send:send_to_sid(PidSend, CastleRushBinData)
	end.

%% 攻城战霸主ID
get_castle_rush_king_id() ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
					{apply_call, lib_castle_rush, get_castle_rush_king_id_data, []}) of
			error ->
				0;
			Data -> 
				Data
		end			
	catch
		_:_Reason ->
			0
	end.
get_castle_rush_king_id_data() ->
	CastleRushInfo = get_castle_rush_info(),
	CastleRushInfo#ets_castle_rush_info.king_id.
	

%% 获取攻城战税收
get_castle_rush_tax(Player) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid_for_apply(), 
						{apply_call, lib_castle_rush, get_castle_rush_tax, 
						 [Player, Player#player.guild_id]})	of
			error -> 
				[0, Player, 0];
			Data -> 
				Data
		end			
	catch
		_:_Reason -> 
			[0, Player, 0]
	end.
get_castle_rush_tax(Player, GuildId) ->
	CastleRushInfo = get_castle_rush_info(),
	if
		CastleRushInfo#ets_castle_rush_info.last_win_guild =:= GuildId ->
			Guild = lib_guild_inner:get_guild(GuildId),
   			if
   				Guild =:= [] ->
					[0, Player, 0];
				true ->
					TaxTime = db_agent:get_castle_rush_tax_time(Player#player.id),
					case is_integer(TaxTime) of
						true ->
							Now = util:unixtime(),
							case util:is_same_date(TaxTime, Now) of
								true ->
									[2, Player, 0];
								false ->
									spawn(fun()-> db_agent:update_castle_rush_tax_time(Player#player.id, Now) end),
									Coin = castle_rush_tax_coin(Guild#ets_guild.level),
									NewPlayer = lib_goods:add_money(Player, Coin, bcoin, 4701),
									[1, NewPlayer, Coin]
							end;
						false ->
							spawn(fun()-> db_agent:update_castle_rush_tax_time(Player#player.id, 0) end),
							[0, Player, 0]
					end
			end;
		true ->
			[3, Player, 0]
	end.

castle_rush_tax_coin(GuildLv) ->
	case GuildLv of
		10 ->
			90000;
		9 ->
			85000;
		8 ->
			80000;
		7 ->
			75000;
		6 ->
			70000;
		5 ->
			65000;
		4 ->
			60000;
		3 ->
			50000;
		2 ->
			40000;
		_ ->
			20000
	end.

%% 是否九霄城主，1是2否
castle_rush_king_login_check(Player, NowSec) ->
	%% 攻城战登陆检查
	castle_rush_login_check(Player, NowSec),
	if
		Player#player.guild_id =/= 0 ->
			LastWinGuild = db_agent:get_castle_rush_info_by_field("last_win_guild"),
			case is_integer(LastWinGuild) of
				true ->
					if
                  		LastWinGuild =/= Player#player.guild_id ->
                            Player;
                        true ->
                            {ok, BinData} = pt_47:write(47015, 1),
                            lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
							GuildPid = mod_guild:get_mod_guild_pid(),
							case is_pid(GuildPid) of
								true ->
									gen_server:cast(GuildPid, {apply_asyn_cast, lib_castle_rush, castle_rush_king_login, [Player#player.id, Player#player.nickname]});
								false ->
									skip
							end,
                            Player#player{
                                other = Player#player.other#player_other{
                                    castle_king = 1
                                }						
                            }
                    end;
				false ->
					Player
			end;
		true ->
			Player
	end.

%% 城主登陆
castle_rush_king_login(PlayerId, NickName) ->
	CastleRushInfo = get_castle_rush_info(),
	if
		CastleRushInfo#ets_castle_rush_info.king_id =/= PlayerId ->
			skip;	
		true ->
			Now = util:unixtime(),
			case util:is_same_date(CastleRushInfo#ets_castle_rush_info.king_login_time, Now) of
				true ->
					skip;
				false ->
					%% 更新攻城战信息
					spawn(fun()-> db_agent:update_castle_rush_info([{king_login_time, Now}]) end),
					NewCastleRushInfo = CastleRushInfo#ets_castle_rush_info{
						king_login_time = Now								   
					},
					ets:insert(?ETS_CASTLE_RUSH_INFO, NewCastleRushInfo),
					Msg = io_lib:format("九霄城主 <font color='#FEDB4F'>~s</font> 登临远古神州！普天之下，茫茫苍穹，谁与争雄！", [NickName]),
					lib_chat:broadcast_sys_msg(1, Msg)
			end
	end.

%% 龙塔重生
castle_rush_mon_revive() ->
	CastleRushInfo = get_castle_rush_info(),
	Guild = lib_guild_inner:get_guild(CastleRushInfo#ets_castle_rush_info.win_guild),
   	if
   		Guild =:= [] ->
			skip;
		true ->
			Msg = io_lib:format("<font color='#FEDB4F'>~s</font> 氏族对龙柱伤害积分最高，暂时获得了九霄龙塔的占领权！", [Guild#ets_guild.name]),
			lib_chat:broadcast_sys_msg(1, Msg)
	end.

%% 攻城战数据初始
init_castle_rush_data() ->
	CastleRushInfo = get_castle_rush_info(),
	CastleRushList = [
		{last_win_guild, CastleRushInfo#ets_castle_rush_info.win_guild}
	],
	spawn(fun()-> db_agent:update_castle_rush_info(CastleRushList) end),
	NewCastleRushInfo = CastleRushInfo#ets_castle_rush_info{
		last_win_guild = CastleRushInfo#ets_castle_rush_info.win_guild
	},
	ets:insert(?ETS_CASTLE_RUSH_INFO, NewCastleRushInfo).

%% 更改攻城战霸主
change_castle_rush_king(GuildId, CastleRushKing) ->
	case lib_guild_inner:get_guild_member_by_guild_id(GuildId) of
		[] ->
			skip;
		MemberList ->
			{ok, BinData} = pt_47:write(47015, CastleRushKing),
			F = fun(Member) ->
				PlayerProcessName = misc:player_process_name(Member#ets_guild_member.player_id),
				case misc:whereis_name({global, PlayerProcessName}) of
					Pid when is_pid(Pid) ->
						gen_server:cast(Pid, {'CHANGE_CASTLE_RUSH_KING', CastleRushKing, BinData});
					_ ->
						skip
				end
			end,
			[F(Member) || Member <- MemberList]
	end.


%% 获取攻城战在龙塔附近的玩家数量
get_castle_rush_def_num(X, Y) ->
	Arena = 10,
	X1 = X - Arena,
	X2 = X + Arena,
	Y1 = Y - Arena,
	Y2 = Y + Arena,
	MS = ets:fun2ms(fun(P) when P#player.scene == ?CASTLE_RUSH_SCENE_ID andalso P#player.hp > 0 
								andalso P#player.other#player_other.leader == 14 
						 		andalso P#player.x > X1 andalso X2 > P#player.x 
						 		andalso P#player.y > Y1 andalso Y2 > P#player.y ->
		[
			P#player.id,
			P#player.lv,
			P#player.other#player_other.pid
		]
	end),
	PlayerList = ets:select(?ETS_ONLINE_SCENE, MS),
	spawn(fun()-> castle_rush_def_award(PlayerList) end),
	length(PlayerList).

castle_rush_def_award(PlayerList) ->
	Fun = fun([PlayerId, Lv, PlayerPid])->
		case ets:lookup(?ETS_CASTLE_RUSH_PLAYER_SCORE, PlayerId) of
			[] ->
				skip;
			[CastleRushPlayer | _] ->
				Spirit = trunc(math:pow(Lv / 5, 3.5) + Lv * 20),
				gen_server:cast(PlayerPid, {'CASTLE_RUSH_SPIRIT', Spirit}),
				NewCastleRushPlayer = CastleRushPlayer#ets_castle_rush_player_score{
					score = CastleRushPlayer#ets_castle_rush_player_score.score + 5
       			},
				ets:insert(?ETS_CASTLE_RUSH_PLAYER_SCORE, NewCastleRushPlayer)
		end	  
	end,
	[Fun(P) || P <- PlayerList].

%% 获取攻城战奖励数据
get_castle_rush_award_data(PidSend, GuildId) ->
	AwardGoods = 
        case lib_guild_inner:get_guild(GuildId) of
            [] ->
%% io:format("get_castle_rush_award_data1~n"),
                ?SKYRUSH_AWARD_ZERO;
            Guild ->
                AwardList = util:string_to_term(tool:to_list(Guild#ets_guild.castle_rush_award)),
                case AwardList =:= [] orelse AwardList =:= undefined of
                    true ->
%% io:format("get_castle_rush_award_data2~n"),
                        ?SKYRUSH_AWARD_ZERO;
                    false ->
%% io:format("get_castle_rush_award_data3~n"),
                        AwardList
                end
        end,
	AwardMember = get_castle_rush_award_member(GuildId),
	{ok, BinData} = pt_47:write(47016, [AwardGoods, AwardMember]),
	lib_send:send_to_sid(PidSend, BinData).

%% 获取攻城战奖励成员
get_castle_rush_award_member(GuildId) ->
	case ets:lookup(?ETS_CASTLE_RUSH_AWARD_MEMBER, GuildId) of
        [] ->
			CastleRushAwardMemberData = 
				case db_agent:get_castle_rush_award_member(GuildId) of
					[] ->
						[];
					CRAMD ->
						CRAMD
				end,
			NewCastleRushGuildScore = #ets_castle_rush_award_member{
				guild_id = GuildId,
				data = CastleRushAwardMemberData												
			},
			ets:insert(?ETS_CASTLE_RUSH_AWARD_MEMBER, NewCastleRushGuildScore),
			CastleRushAwardMemberData;
        [CastleRushAwardMember | _] ->
			CastleRushAwardMember#ets_castle_rush_award_member.data
    end.

%% 攻城战奖励 - 物品分配物品
allot_castle_rush_award(PidSend, GuildId, PlayerId, GoodsId, Num) ->
	case lib_guild_inner:get_guild(GuildId) of
		%% 没这个氏族
		[] ->
			{ok, BinData} = pt_47:write(47017, [0, GoodsId, 0]),
			lib_send:send_to_sid(PidSend, BinData);
		Guild ->
			case lib_guild_inner:get_guild_member_by_guildandplayer_id(GuildId, PlayerId) of
				%% 没有这个人
				[] ->
					{ok, BinData} = pt_47:write(47017, [0, GoodsId, 0]),
					lib_send:send_to_sid(PidSend, BinData);
				Member ->
                    Award = util:string_to_term(tool:to_list(Guild#ets_guild.castle_rush_award)),
                    case lists:keyfind(GoodsId, 1, Award) of
                        %% 不存在这样的物品
						false ->
							{ok, BinData} = pt_47:write(47017, [4, GoodsId, 0]),
							lib_send:send_to_sid(PidSend, BinData);
                        {_GoodsId, GNum} ->
                            if
								%% 物品数量不足
                                GNum =< 0 orelse GNum < Num ->
									{ok, BinData} = pt_47:write(47017, [5, GoodsId, 0]),
									lib_send:send_to_sid(PidSend, BinData);
                                true ->
                                    spawn(fun() -> castle_rush_award_mail(GoodsId, Member#ets_guild_member.player_name, Num) end),
									NewNum = GNum - Num,
                                    NewAward = util:term_to_string(lists:keyreplace(GoodsId, 1, Award, {GoodsId, NewNum})),
                                    spawn(fun()-> db_agent:update_sky_goods([{castle_rush_award, NewAward}], [{id, GuildId}]) end),
                                    NewGuild = Guild#ets_guild{
										castle_rush_award = NewAward
									},
                                    lib_guild_inner:update_guild(NewGuild),
									{ok, BinData} = pt_47:write(47017, [1, GoodsId, NewNum]),
									lib_send:send_to_sid(PidSend, BinData)
                            end
                    end
			end
	end.


%% 攻城战奖励 - 物品自动分配
auto_allot_castle_rush_award(PidSend, GuildId) ->
	case lib_guild_inner:get_guild(GuildId) of
		[] ->
			{ok, BinData} = pt_47:write(47018, [0]),
			lib_send:send_to_sid(PidSend, BinData);
		Guild ->
			GMems = get_castle_rush_award_member(GuildId),
			if 
				%% 不用分配了
				GMems =:= [] ->
					{ok, BinData} = pt_47:write(47018, [1]),
					lib_send:send_to_sid(PidSend, BinData);
				true ->
					Award = util:string_to_term(tool:to_list(Guild#ets_guild.castle_rush_award)),
					%% 排序
					SortFun = fun([_, _, Feats1], [_, _, Feats2]) ->
						Feats1 >= Feats2
					end,
					SortGMems = lists:sort(SortFun, GMems),
					
					%% 对每一排物品进行自动分配
					assign_goods_auto_loop(SortGMems, Award),
					
					NewAward = util:term_to_string(?SKYRUSH_AWARD_ZERO),
					spawn(fun()-> db_agent:update_sky_goods([{castle_rush_award, NewAward}], [{id, GuildId}]) end),
					NewGuild = Guild#ets_guild{
						castle_rush_award = NewAward
					},
					lib_guild_inner:update_guild(NewGuild),
					
					{ok, BinData} = pt_47:write(47018, [1]),
					lib_send:send_to_sid(PidSend, BinData)
			end
	end.

assign_goods_auto_loop(_GMems, []) ->
	ok;
assign_goods_auto_loop(GMems, [{_GoodsId, 0} | Award]) ->
	assign_goods_auto_loop(GMems, Award);
assign_goods_auto_loop(GMems, [{GoodsId, Num} | Award]) ->
	%% 自动分配
	PlayerList = assign_elem_auto(GMems, GMems, GoodsId, Num, [], 0),
	spawn(fun() ->
		lists:foreach(fun({_ELemPlayerId, ELemPlayerName, ELemGoodsId, ELemNum}) ->
							castle_rush_award_mail(ELemGoodsId, ELemPlayerName, ELemNum)
					end,
		PlayerList) end),
	assign_goods_auto_loop(GMems, Award).

assign_elem_auto(_GMems, _GMemsBase, _GoodsId, 0, PlayerList, _Count) ->
	PlayerList;
assign_elem_auto([], GMemsBase, GoodsId, Num, PlayerList, Count) when length(GMemsBase) =< Count ->
	assign_elem_auto_inner2(GMemsBase, GMemsBase, GoodsId, Num, PlayerList);
assign_elem_auto([], GMemsBase, GoodsId, Num, PlayerList, Count) ->
	assign_elem_auto(GMemsBase, GMemsBase, GoodsId, Num, PlayerList, Count);
assign_elem_auto([[PlayerId, PlayerName, _Feats] | GMems], GMemsBase, GoodsId, Num, PlayerList, Count) ->
	AwardNum = 0,%%手动分配的数量
	GiveNum = util:ceil(Num/10),
	assign_elem_auto_inner1(AwardNum, GiveNum, PlayerId, PlayerName, GMems, GMemsBase, GoodsId, Num, PlayerList, Count).

assign_elem_auto_inner1(AwardNum, GiveNum, PlayerId, PlayerName, GMems, 
					   GMemsBase, GoodsId, Num, PlayerList, Count) ->
	case lists:keyfind(PlayerId, 1, PlayerList) of
		false ->%%之前没手动分配过的
			case GiveNum =< ?AWARDGOODS_NUM_LIMIT of
				true ->
					NewPlayerList = [{PlayerId, PlayerName, GoodsId, GiveNum}|PlayerList],
					NewCount = Count,
					NewNum = Num - GiveNum,
					assign_elem_auto(GMems, GMemsBase, GoodsId, NewNum, NewPlayerList, NewCount);
				false ->%%需要分配的物品太多啦，先分配最大数
					NewPlayerList = [{PlayerId, PlayerName, GoodsId, ?AWARDGOODS_NUM_LIMIT}|PlayerList],
					NewCount = Count + 1,	%%爆满了，+1
					NewNum = Num - GiveNum,
					assign_elem_auto(GMems, GMemsBase, GoodsId, NewNum, NewPlayerList, NewCount)
			end;
		{_PlayerId, _PlayerName, _GoodsId, GiveNumOld} ->%%之前手动分配过的了
			if
				GiveNumOld + AwardNum >= ?AWARDGOODS_NUM_LIMIT ->
					NewCount = Count +1,	%%爆满了，+1
					assign_elem_auto(GMems, GMemsBase, GoodsId, Num, PlayerList, NewCount);
				GiveNum + AwardNum + GiveNumOld >= ?AWARDGOODS_NUM_LIMIT ->
					NewPlayerList = lists:keyreplace(PlayerId, 1, PlayerList, {PlayerId, PlayerName, GoodsId, ?AWARDGOODS_NUM_LIMIT}),
					NewCount = Count +1,	%%爆满了，+1
					NewNum = Num - (?AWARDGOODS_NUM_LIMIT - GiveNumOld - AwardNum),
					assign_elem_auto(GMems, GMemsBase, GoodsId, NewNum, NewPlayerList, NewCount);
				true ->
					NewPlayerList = lists:keyreplace(PlayerId, 1, PlayerList, {PlayerId, PlayerName, GoodsId, GiveNum + GiveNumOld}),
					NewCount = Count,
					NewNum = Num - GiveNum,
					assign_elem_auto(GMems, GMemsBase, GoodsId, NewNum, NewPlayerList, NewCount)
			end
	end.

%%没限制的把物品分配下去
assign_elem_auto_inner2(_GMems, _GMemsBase, _GoodsId, 0, PlayerList) ->
	PlayerList;
assign_elem_auto_inner2([], GMemsBase, GoodsId, Num, PlayerList) when Num =/= 0 ->
	assign_elem_auto_inner2(GMemsBase, GMemsBase, GoodsId, Num, PlayerList);
assign_elem_auto_inner2([[PlayerId, PlayerName, _Feats] | GMems], GMemsBase, GoodsId, Num, PlayerList) ->
	GiveNum = util:ceil(Num / 10),
	case lists:keyfind(PlayerId, 1, PlayerList) of
		false ->%%直接新增
			NewPlayerList = [{PlayerId, PlayerName, GoodsId, GiveNum}|PlayerList],
			NewNum = Num - GiveNum,
			assign_elem_auto_inner2(GMems, GMemsBase, GoodsId, NewNum, NewPlayerList);
		{_PlayerId, _PlayerName, _GoodsId, GiveNumOld} ->
			NewPlayerList = lists:keyreplace(PlayerId, 1, PlayerList, {PlayerId, PlayerName, GoodsId, GiveNum + GiveNumOld}),
			NewNum = Num - GiveNum,
			assign_elem_auto_inner2(GMems, GMemsBase, GoodsId, NewNum, NewPlayerList)
	end.

%% 攻城战奖励邮件
castle_rush_award_mail(GoodsId, PlayerName, Num) ->
	Title = "九霄攻城战奖励",
	Content = io_lib:format("您在九霄攻城战期间表现神勇，杀敌无数，特发此奖。", []),
	mod_mail:send_sys_mail([tool:to_list(PlayerName)], Title, Content, 0, GoodsId, Num, 0, 0).

%% 清除攻城战数据
del_castle_rush_data() ->
	%% 删除氏族战功
	catch ets:delete_all_objects(?ETS_CASTLE_RUSH_GUILD_SCORE),
	%% 删除伤害积分
	catch ets:delete_all_objects(?ETS_CASTLE_RUSH_HARM_SCORE),
	%% 删除个人战功
	catch ets:delete_all_objects(?ETS_CASTLE_RUSH_PLAYER_SCORE).


%% 更新怒气值（同时更新被击方和攻击方的个人功勋）
update_castle_rush_angry(DerId, AerId, GuildId, Leader) ->
	%% 被击者个人战功
    case ets:lookup(?ETS_CASTLE_RUSH_PLAYER_SCORE, DerId) of
        [] ->
            skip;
        [CastleRushDer | _] ->
			if
				%% 攻城战守方
				Leader =:= 14 ->
					CastleRushInfo = get_castle_rush_info(),
					if
						CastleRushInfo#ets_castle_rush_info.win_guild =:= GuildId ->
							case get_castle_rush_boss_pid() of
								[] ->
									skip;
								[MonPid | _] ->
									MonPid ! 'CASTLE_RUSH_MON_DEF';
								_ ->
									skip
							end;
						true ->
							skip
					end;
				true ->
					skip
			end,
			NewCastleRushDer = CastleRushDer#ets_castle_rush_player_score{
				die = CastleRushDer#ets_castle_rush_player_score.die + 1
           	},
			ets:insert(?ETS_CASTLE_RUSH_PLAYER_SCORE, NewCastleRushDer)
    end,
	
	%% 攻击者个人战功
    case ets:lookup(?ETS_CASTLE_RUSH_PLAYER_SCORE, AerId) of
        [] ->
            skip;
        [CastleRushAer | _] ->
			NewCastleRushAer = CastleRushAer#ets_castle_rush_player_score{
				kill = CastleRushAer#ets_castle_rush_player_score.kill + 1,
				score = CastleRushAer#ets_castle_rush_player_score.score + 1
           	},
			ets:insert(?ETS_CASTLE_RUSH_PLAYER_SCORE, NewCastleRushAer),
			%% 添加5点氏族战功
			case ets:lookup(?ETS_CASTLE_RUSH_GUILD_SCORE, CastleRushAer#ets_castle_rush_player_score.guild_id) of
				[] ->
					skip;
				[CastleRushGuildScore | _] ->
					NewCastleRushGuildScore = CastleRushGuildScore#ets_castle_rush_guild_score{
						score = CastleRushGuildScore#ets_castle_rush_guild_score.score + 1
       				},
					ets:insert(?ETS_CASTLE_RUSH_GUILD_SCORE, NewCastleRushGuildScore)
			end
    end,
	
	CastleRushAngry =
		case get(castle_rush_angry) of
			undefined ->
				0;
			CRA ->
				CRA
		end,
	NewCastleRushAngry = CastleRushAngry + 1,
	put(castle_rush_angry, NewCastleRushAngry),
	{ok, BinData} = pt_47:write(47011, NewCastleRushAngry),
	send_to_castle_rush_guild(?CASTLE_RUSH_SCENE_ID, GuildId, BinData).

update_castle_rush_angry_effect(GuildId, AngryNum, AngryParam, WinGuildId) ->
	CastleRushAngry =
		case get(castle_rush_angry) of
			undefined ->
				0;
			CRA ->
				CRA
		end,
	NewCastleRushAngry = CastleRushAngry + AngryNum,
	put(castle_rush_angry, NewCastleRushAngry),
	put(castle_rush_angry_param, [WinGuildId, AngryParam]),
	{ok, BinData} = pt_47:write(47011, NewCastleRushAngry),
	send_to_castle_rush_guild(?CASTLE_RUSH_SCENE_ID, GuildId, BinData).


%% 获取龙塔数据
get_castle_rush_boss_pid() ->
	MS = ets:fun2ms(fun(M) when M#ets_mon.scene == ?CASTLE_RUSH_SCENE_ID, M#ets_mon.hp > 0, M#ets_mon.type == 37 -> 
  		M#ets_mon.pid
	end),
	ets:select(?ETS_SCENE_MON, MS).

%% 给场景玩家发信息
send_to_castle_rush_guild(SceneId, GuildId, BinData) ->
	MS = ets:fun2ms(fun(P) when P#player.scene == SceneId andalso P#player.guild_id == GuildId -> 
		[
			P#player.other#player_other.pid_send, 
			P#player.other#player_other.pid_send2,
			P#player.other#player_other.pid_send3
		]
	end),
   	AllUser = ets:select(?ETS_ONLINE_SCENE, MS),
	F = fun(SendList) ->
		lib_send:send_to_sids(SendList, BinData, 1)
    end,
    spawn(fun()-> [F(SendList) || SendList <- AllUser] end).

get_mail_date(Date) ->
%% 	TodaySec = util:get_today_current_second(),
	DayNum = get_castle_rush_next_date(Date),
	{StartTime, _EndTime} = util:get_this_week_duringtime(),
	DaySec = StartTime + (DayNum - 1) * 24 * 60 * 60 + 3600,
	{{_Year, Month, Day}, _Time} = util:seconds_to_localtime(DaySec),
	[Month, Day].

get_castle_rush_next_date(Date) ->
	DayList = get_date_list(),
	get_castle_rush_next_date_loop(DayList, Date, 0).
get_castle_rush_next_date_loop([], _Date, Ret) ->
	Ret;
get_castle_rush_next_date_loop([Day | D], Date, Ret) ->
	if
		Day - Date < 0 ->
			get_castle_rush_next_date_loop(D, Date, Ret);
		true ->
			Date
	end.


%% 攻城战正式开始时
castle_rush_start() ->
	CastleRushList = db_agent:get_castle_rush_join_guild_list(),
	{ok, BinData} = pt_47:write(47001, [0, 2]),
	Fun = fun(Castle)->
		C = list_to_tuple([?ETS_CASTLE_RUSH_JOIN | Castle]),
		#ets_castle_rush_join{
			guild_id = GuildId,
			guild_name = GuildName,
			guild_lv = GuildLv		  
		} = C,
		
		%% 初始城战氏族信息
		init_castle_rush_guild_info(GuildId, GuildName, GuildLv, BinData)
	end,
	lists:foreach(Fun, CastleRushList),
	%% 开启龙塔防御定时器
	CastleRushInfo = get_castle_rush_info(),
	if
		CastleRushInfo#ets_castle_rush_info.win_guild =/= 0 ->
			erlang:send_after(?CASTLE_RUSH_INTERVAL, self(), {'CASTLE_RUSH_ATT_DEF', 1});
		true ->
			undefined
	end.

%% 初始城战氏族信息
init_castle_rush_guild_info(GuildId, GuildName, GuildLv, BinData) ->
	%% 生成各自氏族的专用进程ID
	WorkerId = GuildId + ?SCENE_WORKER_NUMBER,
	mod_castle_rush:start_link(WorkerId),
	
	%% 氏族战功
	CastleRushGuildScore = #ets_castle_rush_guild_score{
  		guild_id = GuildId,                           
   		guild_name = GuildName,
		guild_lv = GuildLv,
		member = []                        	
   	},
	ets:insert(?ETS_CASTLE_RUSH_GUILD_SCORE, CastleRushGuildScore),
	
	%% 伤害积分
	CastleRushHarmScore = #ets_castle_rush_harm_score{
  		guild_id = GuildId,                           
   		guild_name = GuildName                        	
   	},
	ets:insert(?ETS_CASTLE_RUSH_HARM_SCORE, CastleRushHarmScore),
	%% 通知前端进入城战
	lib_send:send_to_guild(GuildId, BinData).
	

%% 龙塔攻防
castle_rush_att_def(Num) ->
	CastleRushInfo = get_castle_rush_info(),
	WinGuildId = CastleRushInfo#ets_castle_rush_info.win_guild,
	if
		WinGuildId =/= 0 ->
			CastleRushGuildData = ets:tab2list(?ETS_CASTLE_RUSH_GUILD_SCORE),
            if
                length(CastleRushGuildData) > 0 ->
					{AngryNum, AngryParam} = 
						if
							Num > 3 ->
								{15, (Num - 3) * 0.25};
							true ->
								{Num * 5, 0}
						end,
					CastleRushGuildFun = fun(C)->
						if
							WinGuildId =/= C#ets_castle_rush_guild_score.guild_id ->
								CastleRushPid = lib_castle_rush:get_castle_rush_worker_pid(C#ets_castle_rush_guild_score.guild_id),
                                case is_pid(CastleRushPid) of
                                    true ->
                                        CastleRushPid ! {'UPDATE_CASTLE_RUSH_ANGRY_EFFECT', C#ets_castle_rush_guild_score.guild_id, AngryNum, AngryParam, WinGuildId};
                                    false ->
                                        skip
                                end;
							true ->
								skip
						end
                    end,
                    lists:foreach(CastleRushGuildFun , CastleRushGuildData);
                true ->
                    skip
            end,
			erlang:send_after(?CASTLE_RUSH_INTERVAL, self(), {'CASTLE_RUSH_ATT_DEF', Num + 1});
		true ->
			undefined
	end.

get_castle_rush_repeat_timer() ->
	erlang:send_after(?CASTLE_RUSH_INTERVAL, self(), {'CASTLE_RUSH_ATT_DEF',  1}).


%% 鼓舞技能效果值
castle_rush_angry_val(SkillId) ->
	case SkillId of
		10074 ->
			[1200, 550];
		10075 ->
			[1400, 600];
		10076 ->
			[1600, 650];
		10077 ->
			[1800, 700];
		10078 ->
			[2000, 750];
		10079 ->
			[2200, 800];
		10080 ->
			[2400, 850];
		10081 ->
			[2600, 900];
		10082 ->
			[2800, 950];
		_ ->
			[1000, 500]
	end.


%% 城战各部落的出生位置
castle_rush_position(Realm) ->
	case Realm of
        %% 女娲
        1 ->
            [15, 88];
        %% 神农
        2 ->
            [63, 46];
        %% 伏羲
        _ ->
            [62, 96]
    end.


%% 攻城战里死亡 
castle_rush_die(Player, AerId) ->
	if
		Player#player.guild_id > 0 ->
			CastleRushPid = lib_castle_rush:get_castle_rush_worker_pid(Player#player.guild_id),
			case is_pid(CastleRushPid) of
				true ->
					CastleRushPid ! {'UPDATE_CASTLE_RUSH_ANGRY', Player#player.id, AerId, Player#player.guild_id, Player#player.other#player_other.leader};
				false ->
					skip
			end;
		true ->
			skip
	end.












%% 攻城战退出场景信息
get_castle_rush_outside() ->
	[300, 29, 73].

get_date_list() ->
	[3, 6].

%% 攻城战报名时长
get_castle_rush_join_time_dist(TodaySec) ->
	?CASTLE_RUSH_START_TIME - TodaySec.

%% 攻城战战斗时长
get_castle_rush_time_dist(TodaySec) ->
	?CASTLE_RUSH_END_TIME - TodaySec.

%% 攻城战结束时长
get_castle_rush_check_time_dist(TodaySec) ->
	?CASTLE_RUSH_END_CHECK - TodaySec.
