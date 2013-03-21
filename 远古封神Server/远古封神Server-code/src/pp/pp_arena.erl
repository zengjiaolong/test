%%%--------------------------------------
%%% @Module  : pp_arena
%%% @Author  : ygfs
%%% @Created : 2011.02.15
%%% @Description : 战场
%%%--------------------------------------
-module(pp_arena).

-export(
	[
	 	handle/3
	]
).
-include("common.hrl").
-include("record.hrl").

%% 登录检测战场状态 
handle(23001, PlayerState, _R) ->
	Player = PlayerState#player_state.player,
	%% 检查进入战场的条件
	case lib_arena:check_enter_arena_condition(Player) of
		true ->
			case get(arena_battle_id) of
                undefined ->
					SupArenaPid = mod_arena_supervisor:get_mod_arena_supervisor_pid(),
					case catch gen_server:call(SupArenaPid, {'CHECK_JOIN_ARENA', Player#player.id}) of
						{ArenaSceneId, ArenaPid} ->
							case catch gen_server:call(ArenaPid, {'CHECK_JOIN_ARENA', Player#player.id}) of
                          		[1, _ArenaSceneId, ArenaMark, ReviveNum] ->
									NewPlayer = Player#player{
                                 		other = Player#player.other#player_other{
                                 			pid_dungeon = ArenaPid
                                    	}                                               						  
                                   	},
                             		NewPlayerState = PlayerState#player_state{
                              			arena_revive = ReviveNum,
                               			arena_mark = ArenaMark,
										player = NewPlayer										  
                              		},
									lib_arena:enter_arena_scene(NewPlayerState, ArenaSceneId, ReviveNum, 1, 1);
								_ ->
									skip
							end;
						_ ->
							skip
					end;
                SceneId ->
                    ReviveNum = PlayerState#player_state.arena_revive,
                    ArenaSta = 
                        %% 是否新战场场景
                        case lib_arena:is_new_arena_scene(SceneId) of
                            true ->
                                1;
                            false ->
                                if
                                    ReviveNum > 0 ->
                                        1;
                                    true ->
                                        3
                                end
                        end,
                    lib_arena:enter_arena_scene(PlayerState, SceneId, ReviveNum, ArenaSta, 1)
  			end;
		_ ->
			skip
	end;

%% 战场报名
handle(23002, PlayerState, _R) ->
	Player = PlayerState#player_state.player,
	Coin = 1000,
	Result =
		if
			%% 等级不足
			Player#player.lv < 33 ->
				6;
			%% 铜币不足
			Player#player.coin < Coin ->
				8;
			%% 红名
			Player#player.evil > 300 ->
				7;
			%% 凝神状态不能进入战场
			Player#player.status =:= 7 ->
				14;
			true ->
                %% 副本里不可以报名
                case lib_scene:is_dungeon_scene(Player#player.scene) of                            
                    false ->
                        %% 氏族领地内不能进入战场
                        case lib_guild_manor:is_guild_manor_scene(Player#player.scene, Player#player.guild_id) of
                            false ->
                                %% 封神塔内不可以报名
                                case lib_scene:is_fst_scene(Player#player.scene) of
                                    false ->
                                        case lib_scene:is_zxt_scene(Player#player.scene) of
                                            false->
                                                case lib_spring:is_spring_scene(Player#player.scene) of
                                                    false ->
                                                        %% 镇妖台不可以报名
                                                        case lib_scene:is_td_scene(Player#player.scene) of
                                                            false ->
                                                                %% 70副本不可以报名
                                                                case lib_cave:is_cave_scene(Player#player.scene) of
                                                                    false ->
																		lib_arena:arena_join(Player);
                                                                    true ->
                                                                        9
                                                                end;
                                                            true ->
                                                                17
                                                        end;
                                                    true ->
                                                        16
                                                end;
                                            true ->
                                                15
                                        end;
                                    true ->
                                        13	
                                end;
                            true ->
                                11
                        end;
                    true ->
                        9
                end
		end,
    {ok, BinData} = pt_23:write(23002, Result),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	if
		Result == 1 ->			
			CostPlayer = lib_goods:cost_money(Player, Coin, coin, 2301),
			NewPlayer = CostPlayer#player{
				arena = 2						  
			},
			lib_player:send_player_attribute2(NewPlayer, 2),
			%% 战场怒气
			put(arena_angry, 0),
			ArenaList = [
				{coin, NewPlayer#player.coin},
				{bcoin, NewPlayer#player.bcoin},
				{arena, NewPlayer#player.arena}
			],
			mod_player:save_online_info_fields(NewPlayer, ArenaList),
			{ok, change_status, NewPlayer};
		true ->
			skip
	end;

%% 玩家登录检查竞技状态
handle(23003, PlayerState, _) ->
	Player = PlayerState#player_state.player,
		%%初始化氏族祝福
	case Player#player.lv < 35 of
		true ->
			skip;
		false ->
			lib_guild_wish:init_guild_wish(Player#player.id, Player#player.nickname, Player#player.sex, Player#player.career, Player#player.guild_id)
	end,
	
	%% 获取灵兽列表
	pp_pet:handle(41008, Player, [Player#player.id]),
	
	%% 获取技能列表
	pp_skill:handle(21002, Player, []),
	
	%% 请求快捷栏
	pp_player:handle(13007, PlayerState, []),
	
	case lib_war:is_war_server() of
		true->skip;%%跨服不加载一些不需要的功能
		false->
			%%把人物的成就系统数据初始化
			lib_achieve_inline:check_achieve_init(Player#player.id),
			%% 获取本人庄园是否有东西成熟
			pp_manor:handle(42017, Player, [null]),
	
			%% 查询登陆奖励（新）
			pp_task:handle(30081, Player, []),
	
			%% 查询登陆抽奖信息
			pp_task:handle(30075, Player, []),
	
			%% 获取玩家离线时间经验累积
			lib_offline_award:get_offline_award(Player),
	
			%% 获取挖矿倒计时
			pp_ore:handle(36000, Player, []),
	
			%% 获取挂机面板信息
			pp_hook:handle(26002, Player, []),

			%%新手礼包
			pp_task:handle(30084,Player,[]),
			%% 检查是否有在线奖励
			{_, _GiftPlayer, Data, GoodsBag} = lib_online_gift:check_online_gift(Player),
			{ok, OnlineBinData} = pt_30:write(30070, [Data, GoodsBag]),
  			lib_send:send_to_sid(Player#player.other#player_other.pid_send, OnlineBinData),
			
			%%检查是否需要初始化猜灯谜活动的数据
			%%lib_activities:check_init_lantern_riddles(Player),
			%%?DEBUG("ok: ~p", [get(lantern)]),
			%% 查询是否可以领取每日在线奖励
			pp_task:handle(30900, Player, []),
	
			%%查询是否跑商双倍时间
			pp_task:handle(30702, Player, []),
	
			%% 查询目标引导
			pp_task:handle(30078, Player, []),
	
			%% 询问队伍信息
			pp_team:handle(24010, Player, []),
	
			%%查询挂机去是否开放
			pp_scene:handle(12401,Player,[]),
			
			%%推送商城积分
			pp_player:handle(13054,PlayerState,[]),
			
			%%祝福瓶经验
			pp_relationship:handle(14054, Player, [], PlayerState),
			
			%%推送婚宴图标
			lib_marry:is_wedding_on(Player),
			%% 获取目标奖励信息
			pp_task:handle(30072, Player, []),
			%%查询封神大会状态
			lib_war:notice_war_state(Player),
			%%开服活动
			pp_task:handle(30087,Player,[]),
			
			%%单人镇妖竞技
			pp_rank:handle(22018,Player,[0]),
			
			
			%% 是否在双倍经验活动
			lib_player:exp_activity_login_check(Player#player.other#player_other.pid_send),
			
			%% 是否可以领取竞技场奖励
			if
				PlayerState#player_state.coliseum_rank > 0 ->
					{ok, BinData49013} = pt_49:write(49013, PlayerState#player_state.coliseum_rank),
   					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData49013);
				true ->
					skip
			end,
			
			ok
	end,
	%%登陆成功后推送出战坐骑信息
	MountInfo = lib_mount:get_out_mount(Player#player.id),
	if is_record(MountInfo,ets_mount) ->
		   pp_mount:handle(16012, Player, MountInfo#ets_mount.id);
	   true ->
		   skip
	end,	
	%% 获取今天凌晨到现在的秒数
 	TodaySec = util:get_today_current_second(),
	
	[RetPlayer, RetPlayerState] = 
		%% 是否在战场时间
		case lib_arena:is_arena_time() of
			true ->
				if
              		Player#player.arena > 0 ->
                   		lib_arena:check_arena_status(Player, PlayerState);
                    true ->
						ArenaJoinEndTime = lib_arena:get_arena_join_end_time(),
                        if
                 			TodaySec < ArenaJoinEndTime ->
                                {ok, ArenaBinData} = pt_23:write(23001, [ArenaJoinEndTime - TodaySec, 0]),
                                lib_send:send_to_sid(Player#player.other#player_other.pid_send, ArenaBinData);
                            true ->
                                skip
                        end,
						[Player, PlayerState]
                end;
           	false ->
				ANSWER_HOUR_TIME = mod_answer:get_mod_answer_data_by_type(answer_hour_time),
				ANSWER_END = mod_answer:get_mod_answer_data_by_type(answer_end),
				if
					%% 是否在答题时间[70618,70020,71220]
					TodaySec >= ANSWER_HOUR_TIME andalso TodaySec < ANSWER_END ->
						mod_answer:check_answer_time_info(Player);
					%% 是否在国运时间
					TodaySec >= ?CARRY_BC_START andalso TodaySec =< ?CARRY_BC_END ->
						{ok, CarryBinData} = pt_30:write(30300, [1, 1, ?CARRY_BC_END - TodaySec]),
						lib_send:send_to_sid(Player#player.other#player_other.pid_send, CarryBinData);
					true ->
						skip
				end,
				[Player, PlayerState]
        end,
	
	%% 获取技能BUFF信息
	Buff = RetPlayer#player.other#player_other.battle_status,
	Now = util:unixtime(),
	if
		Buff =/= [] ->
			lib_player:refresh_player_buff(RetPlayer#player.other#player_other.pid_send, Buff, Now);
		true ->
			skip
	end,
	
	%% 获取物品BUFF信息
 	{BuffPlayer, BuffInfo} = lib_goods:update_goods_buff_action(RetPlayer, force),
	lib_peach:player_load_into_scene(BuffPlayer, BuffInfo),
	
	%% 攻城战霸主登陆检查
	CastleRushPlayer = lib_castle_rush:castle_rush_king_login_check(BuffPlayer, TodaySec),
	
	%%判断是否有可能给帮玩家启动一个 定时器的判断
	NewPlayer = lib_peach:check_handle_peach_exp_spir(CastleRushPlayer),
	
	%% 氏族战开启时间广播(广播)
	pp_skyrush:handle(39023, NewPlayer, []),
	
	%% 查询氏族战是否报名
	pp_skyrush:handle(39029, NewPlayer, []),

	%% 查询温泉是否开始
	pp_scene:handle(12053, NewPlayer, []),
	
	%%检查是否需要向客户端推神魔乱斗的倒计时图标
	lib_warfare:check_send_warfare_icon(NewPlayer#player.lv, NewPlayer#player.other#player_other.pid_send),
	%%获取 冥王之灵的图标显示
%% 	lib_warfare:get_plutos_owns(NewPlayer#player.other#player_other.pid_send),
	
	%%推送封神争霸信息
	mod_war2_supervisor:notice_enter_war2(NewPlayer),
	%% 检查新邮件
	lib_mail:check_unread(NewPlayer#player.id),
	%% 检查邮件是否已满
	case lib_mail:check_mail_full(NewPlayer#player.id) of
		true ->
			{ok, BinData} = pt_19:write(19007, <<>>),
  			lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send, BinData);
		_ ->
			ok
	end,
	%% 判断是否需要通知客户端领取竞猜奖励
	lib_quizzes:check_player_quizzes_receive(NewPlayer#player.id, NewPlayer#player.other#player_other.pid_send, Now),
	NewPlayerState = RetPlayerState#player_state{
		player = NewPlayer							 
	},
	%% 将轻功等级信息推送到客户端
	pp_skill:handle(21003,NewPlayer,[]),
	%%经验找回查询
	pp_exc:handle(33006,NewPlayer,[]),
	{ok, change_diff_player_state, NewPlayerState};


%% 开始进入战场
handle(23004, PlayerState, [_ZoneId, SceneId]) ->
	Player = PlayerState#player_state.player,
	%% 检查进入战场的条件
	case lib_arena:check_enter_arena_condition(Player) of
		true ->
			lib_arena:enter_arena(PlayerState, Player, SceneId);
		_ ->
			skip
	end;

%% 获取竞技战斗中的排名列表
handle(23005, PlayerState, _) ->
	Player = PlayerState#player_state.player,
	ArenaPid = lib_arena:get_arena_pid(Player),
	gen_server:cast(ArenaPid, {'GET_ARENA_MEMBER', Player#player.other#player_other.pid_send});

%% 离开战场
handle(23010, PlayerState, _) ->
	NewPlayer = lib_arena:leave_arena(PlayerState#player_state.player),
	{ok, change_status, NewPlayer};

%% 战场英雄榜
handle(23020, PlayerState, [LvNum, AreaNum]) ->
	Player = PlayerState#player_state.player,
	gen_server:cast(mod_arena_supervisor:get_mod_arena_supervisor_work_pid(), 
			{apply_asyn_cast, lib_arena, rank_pre_arena_week, [LvNum, AreaNum, Player#player.id, Player#player.other#player_other.pid_send]});
	
%% 战场排行榜(总排行,周排行)
handle(23021, PlayerState, [RankType, PageNum, CurrPage]) ->
	Player = PlayerState#player_state.player,
	gen_server:cast(mod_arena_supervisor:get_mod_arena_supervisor_work_pid(), 
			{apply_asyn_cast, lib_arena, rank_arena_query, [RankType, PageNum, CurrPage, Player#player.other#player_other.pid_send]});

%% 使用怒气技能
handle(23023, PlayerState, DerId) ->
	Player = PlayerState#player_state.player,
	case lib_arena:is_arena_scene(Player#player.scene) andalso Player#player.arena /= 3 of
		true ->
			Angry = 
				case get(arena_angry) of
					undefined ->
						0;
					StoreAngry ->
						StoreAngry
				end,
			if
				Angry >= 1000 ->
					case lib_player:get_online_info_fields(DerId, [x, y, leader]) of
                    	[] ->
							skip;
                    	[DerX, DerY, DerLeader] ->
							if
								Player#player.other#player_other.leader /= DerLeader ->
                                    case lib_battle:check_att_area(Player#player.x, Player#player.y, DerX, DerY, 2) of
                                        true ->
											ScenePid = mod_scene:get_scene_pid(Player#player.scene, undefined, undefined),
											gen_server:cast(ScenePid,
                                                {apply_asyn_cast, lib_arena, arena_angry_battle, [Player#player.id, Player#player.scene, DerX, DerY]}),
                                            {ok, BinData} = pt_23:write(23022, 0),
                                            lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
                                            put(arena_angry, 0);	
                                        %% 距离有误
                                        false ->
                                            lib_battle:battle_fail(4, Player, 2)
                                    end;
								%% 施放对象有误
								true ->
									lib_battle:battle_fail(7, Player, 2)
							end
                	end;
				%% 怒气不足
				true ->
					{ok, BinData} = pt_23:write(23023, 1),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)	
			end;
		false ->
			skip
	end;

%% 打开战场奖励面板
handle(23024, PlayerState, _) ->
	Player = PlayerState#player_state.player,
	gen_server:cast(mod_arena_supervisor:get_mod_arena_supervisor_work_pid(),
			{apply_asyn_cast, lib_arena, arena_award_member, 
				[Player#player.id, Player#player.other#player_other.pid_send, Player#player.lv]});

%% 领取竞技场奖励
handle(23026, PlayerState, _) ->
	Player = PlayerState#player_state.player,
	ArenaPid = mod_arena_supervisor:get_mod_arena_supervisor_work_pid(),
	case catch gen_server:call(ArenaPid, {apply_call, lib_arena, get_arena_award, [Player]}) of
		{1, GoodsNum, YestodayMidNightSecond} ->
			GoodsTypeId = 28842,
			case catch gen_server:call(Player#player.other#player_other.pid_goods, 
												{'give_goods', Player, GoodsTypeId, GoodsNum, 2}) of
				ok ->
					spawn(fun()-> db_agent:update(arena, [{jtime, YestodayMidNightSecond}], [{player_id, Player#player.id}]) end),
					spawn(fun()-> db_agent:add_money(Player, 0, bcoin, 2326) end),
					{ok, BinData} = pt_23:write(23026, [1, GoodsTypeId]),
	   				lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
				_Other->
					%% 背包满
					{ok, BinData} = pt_23:write(23026, [3, 0]),
	   				lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
			end;
		%% 领取时间没到
		2 ->
			{ok, BinData} = pt_23:write(23026, [2, 0]),
	   		lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		%% 没有奖励
		5 ->
			{ok, BinData} = pt_23:write(23026, [5, 0]),
	   		lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		%% 已经领取过
		6 ->
			{ok, BinData} = pt_23:write(23026, [6, 0]),
	   		lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		_ ->
			{ok, BinData} = pt_23:write(23026, [4, 0]),
	   		lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
	end;

handle(_Cmd, _PlayerState, _Data) ->
    {error, "handle_arena no match"}.
