%%%--------------------------------------
%%% @Module  : lib_battle
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description:战斗处理 
%%%--------------------------------------
-module(lib_battle).
-export(
    [
        check_battle_mode/8,              
        player_revive/4,	
        battle_fail/3,
        check_valid_revive/2,
		enter_battle_status/1,
		exit_battle_status/2,
		get_battle_coordinate/5,
		get_scene_user_battle/5,
		get_scene_user_for_battle/6,
		get_mon_for_battle/5,
		check_att_area/5,
		battle_mon/4,
		battle_mon/5,
		battle_player/4,
		battle_player/5,
		check_battle_limit/2,
		hp_bleed/9,
		change_pk_mode/5,
		check_assist_object/2,
		share_mon_hp/8,
		share_mon_hrut/8,
		share_shadow_hrut/8,
		update_battle_limit/8,
		battle_speed/7,
		battle_drug/4
    ]
).

-include("common.hrl").
-include("record.hrl").
-include("battle.hrl").
-include("guild_info.hrl").
-include_lib("stdlib/include/ms_transform.hrl").


%% 根据战斗模式判断是否可以攻击
%% Mode 攻击方的PK模式
%% AttRealm 攻击方所在部落
%% DefRealm 被击方所在部落
%% AttGid 攻击方所在氏族ID
%% DefGid 被击方所在氏族ID
%% AttPid 攻击方的组队进程ID
%% DefPid 被击方的组队进程ID
check_battle_mode(Mode, AerRealm, DerRealm, AerGuildId, DerGuildId, AerTeamPid, DerTeamPid, GuildAlliance) ->
    case Mode of
        %% 部落
        2 ->
            if 
                AerRealm == DerRealm ->
                    0;
                true ->
                    1
            end;
        %% 氏族
        3 ->
            if 
                AerGuildId /= 0 andalso AerGuildId == DerGuildId ->
                    0;
                true ->
                    1
            end;
        %% 组队
        4 ->
            if
                AerTeamPid /= undefined andalso AerTeamPid == DerTeamPid ->
                    0;
                true ->
                    1
            end;
        %% 自由
        5 ->
            1;
		%% 联盟
		6 ->
			if 
                AerGuildId /= 0 andalso AerGuildId == DerGuildId ->
                    0;
                true ->
					case lists:member(DerGuildId, GuildAlliance) of
						true ->
							0;
						false ->
							1
					end
            end;
        _ ->
            0
    end.

%% 更改玩家战斗状态
%% Player 玩家信息
enter_battle_status(Player) ->
	misc:cancel_timer(battle_status_timer),
	BattleStatusTimer = erlang:send_after(?EXIT_BATTLE_INTERVAL, Player#player.other#player_other.pid, 'ESCAPE_BATTLE_STATUS'),
	put(battle_status_timer, BattleStatusTimer),
    case Player#player.status of
		0 ->
            %% 如果在交易的话，立即退出交易状态,通知取消交易
            {ATrade, _BPlayerId} = Player#player.other#player_other.trade_status,
            TradePlayer = 
                if 
                    ATrade /= 0 ->
                        {ok, RetPlayer} = pp_trade:handle(18007, Player, [2]),
                        gen_server:cast(RetPlayer#player.other#player_other.pid, {'SET_PLAYER', [{trade_status, {0, 0}}, {trade_list, []}]}),
                        RetPlayer;
                    true ->
                        Player
                end,
			into_battle_status(TradePlayer);
		%% 从打坐状态恢复正常状态
		6 ->
			{ok, NewPlayer} = lib_player:cancelSitStatus(Player),
			List = [
				{status, 2},
				{peach_revel, NewPlayer#player.other#player_other.peach_revel}		
			],
			mod_player:save_online_info_fields(NewPlayer, List),
			into_battle_status(NewPlayer);
		%% 防御方退出采矿状态
		8 ->
			lib_ore:cancel_ore_status(Player),
			mod_player:save_online_info_fields(Player, [{status, 2}]),
			into_battle_status(Player);
		%% 双修
		10 ->
			{ok, NewPlayer} = lib_double_rest:cancel_double_rest(Player),
			mod_player:save_online_info_fields(NewPlayer, [{status, 2}]),
			into_battle_status(NewPlayer);
  		_ ->
            Player
    end.
%% 进入战斗状态
into_battle_status(Player) ->
	{ok, BinData} = pt_20:write(20007, 1), 
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
    Player#player{
        status = 2
    }.

%% 退出战斗状态
%% Player 玩家信息
%% Sta 状态
exit_battle_status(Player, Sta) ->
	misc:cancel_timer(battle_status_timer),	
	case Player#player.status of
		%% 在战斗中
		2 ->
			{ok, BinData} = pt_20:write(20007, 0), 
            lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		_ ->
            skip
	end,	
	put(battle_status_timer, undefined),
    Player#player{status = Sta}.

%% 玩家复活
%% ReviveType 复活方式
%% FromType 1、使用道具（稻草人）
player_revive(Player, ReviveType, FromType, PlayerState) ->
    [NewPlayer, NewReviveType, NewPlayerState] = 
        case lib_arena:is_arena_scene(Player#player.scene) of
			%% 战场复活
            true ->
				if
					Player#player.hp < 1 andalso Player#player.scene < 650 ->
                        ArenaReviveNum = PlayerState#player_state.arena_revive - 1,
                        [NewArenaReviveNum, BattleLimit, Arena, RetArenaReviveNum] = 
                            case ArenaReviveNum > -1 of
                                true ->
                                    %% 无敌5秒
                                    erlang:send_after(5000, Player#player.other#player_other.pid, {'SET_BATTLE_LIMIT', 0}),
                                    [ArenaReviveNum, 9, Player#player.arena, ArenaReviveNum];
                                false ->
                                    [0, 0, 3, -1]
                            end,
                        {ok, BinData} = pt_23:write(23009, RetArenaReviveNum),
                        lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
						ArenaNow = util:unixtime(),
                        ArenaPlayer = Player#player{
                            arena = Arena,
                            other = Player#player.other#player_other{
                                battle_limit = BattleLimit,
								die_time = ArenaNow								 
                            }			  
                        },
                        ArenaPlayerState = PlayerState#player_state{
                            arena_revive = NewArenaReviveNum										  
                        },
                        [ArenaPlayer, 4, ArenaPlayerState];
					true ->
						ArenaRevireType =
							if
								ReviveType =/= 14 ->
									4;
								true ->
									ReviveType
							end,
						[Player, ArenaRevireType, PlayerState]
				end;
            false ->
				%% 攻城战复活
				case Player#player.scene == ?CASTLE_RUSH_SCENE_ID andalso Player#player.hp < 1 of
					true ->
						%% 无敌5秒
						CastleRushPlayer = Player#player{
							other = Player#player.other#player_other{
								battle_limit = 9	
							}
						},
						erlang:send_after(5000, Player#player.other#player_other.pid, {'SET_BATTLE_LIMIT', 0}),
                       	[CastleRushPlayer, ReviveType, PlayerState];
					false ->
                        case lib_war:is_fight_scene(Player#player.scene) ==true andalso Player#player.hp < 1 of
                            true->
                                WarPlayer = Player#player{other = Player#player.other#player_other{battle_limit = 9	}},
								erlang:send_after(2000, Player#player.other#player_other.pid, {'SET_BATTLE_LIMIT', 0}),
                                [WarPlayer, ReviveType, PlayerState];
                            false->
                                case Player#player.scene =:= ?SKY_RUSH_SCENE_ID andalso Player#player.hp < 1 of
                                    true ->
                                        [Player, 5, PlayerState];
                                    false ->
                                        case lib_scene:is_td_scene(Player#player.scene) of
                                            true ->
                                                [Player, 6, PlayerState];
                                            false ->
                                                NRT = 
                                                    if
                                                        ReviveType =:= 6 ->
                                                            0;
                                                        true ->
                                                            ReviveType
                                                    end,
                                                [Player, NRT, PlayerState]
                                        end
                                end
                        end
				end
        end,
    RetPlayer = lib_scene:revive_to_scene(NewPlayer, NewReviveType, FromType),
	%%死亡进入桃树区域的判断
	case RetPlayer#player.scene =:= 300 andalso RetPlayer#player.x =:= 70 andalso RetPlayer#player.y =:= 118 of 
		true ->%%如果是九霄，判断一下buff桃子的刷新问题
			erlang:send_after(3000, self(), {'PLAYER_INTO_PEACH'});
		false ->
			skip
	end,
	[RetPlayer, NewPlayerState].

%% 战斗发起失败
%% Code 错误码
%% Aer 攻击方
%% AerType 1怪, 2人
battle_fail(Code, Aer, AerType) ->
    case AerType == 2 of
        true ->
            {ok, BinData} = pt_20:write(20005, [Code, 2, Aer#player.id]),
            lib_send:send_to_sid(Aer#player.other#player_other.pid_send, BinData);
   		false ->
            skip
    end.

%% 判断是否有条件复活
%% Player 玩家信息
%% ReviveType 复活方式
check_valid_revive(Player, ReviveType) ->
    case ReviveType of
        %% 高级稻草人
        1 ->
            case lib_player:player_status(Player) of 
           		3 ->
                    case lib_goods:goods_find(Player#player.id, 28401) of
                        false ->					
                            case Player#player.gold >= ?ADVANCED_REVIVE_COST of
                                true ->
                                    1;
                                false ->
                                    0
                            end;
                        _Goods ->
                            1
                    end;
           		_ ->
                    1
            end;
        %% 稻草人
        2 ->
      		case lib_player:player_status(Player) of
           		3 ->
                    case lib_goods:goods_find(Player#player.id, 28400) of
                        false ->
                            case Player#player.gold >= ?REVIVE_COST of
                                true ->
                                    1;
                                false ->
                                    0
                            end;
                        _GoodsInfo ->
                            1
                    end;
                _ ->
                    1
            end;
		%% 攻城战元宝复活
		9 ->
			case lib_player:player_status(Player) of
           		3 ->
              		case Player#player.gold >= 10 of
               			true ->
                    		1;
                  		false ->
                    		0
              		end;
                _ ->
                    1
            end;
		%%跨服战场元宝复活
%% 		8->
%% 			case Player#player.gold >= 100 of
%% 				true ->
%% 					1;
%% 				false ->
%% 					0
%% 			end;
        %% 安全复活/TD复活
		10 -> %%神魔乱斗元宝复活
			case Player#player.gold >= ?WARFARE_REVIVE_COST of
				true ->
					1;
				false ->
					0
			end;
		%% 新战场元宝复活
		14 ->
			case lib_player:player_status(Player) of
           		3 ->
              		case Player#player.gold >= 5 of
               			true ->
                    		1;
                  		false ->
                    		0
              		end;
                _ ->
                    1
            end;
        _ ->
            1     
    end.


%% 返回攻击方的攻击坐标
%% AX 攻击方的x坐标
%% AY 攻击方的y坐标
%% DX 被击方的x坐标
%% DY 被击方的y坐标
get_battle_coordinate(AX, AY, DX, DY, Area) ->
	if
        %% 目标在正下方
        AX == DX andalso AY > DY ->
			[AX, DY + Area];            

        %% 目标在正上方
        AX == DX andalso AY < DY ->
			[AX, DY - Area];            

        %% 目标在正左方
        AX < DX andalso AY == DY ->
			[DX - Area, AY];            

        %% 目标在正右方
        AX > DX andalso AY == DY ->
			[DX + Area, AY];            

        %% 目标在左上方
        AX < DX andalso AY < DY ->
       		[DX - Area, DY - Area];

        %% 目标在左下方
        AX < DX andalso AY > DY ->
            [DX - Area, DY + Area];

        %% 目标在右上方
        AX > DX andalso AY < DY ->
			[DX + Area, DY - Area];
            
        %% 目标在右下方
        AX > DX andalso AY > DY ->
            [DX + Area, DY + Area];

        true ->
			[DX + Area, DY + Area]
	
    end.

get_scene_user_for_battle(SceneId, AerId, X1, X2, Y1, Y2) ->
	MS = ets:fun2ms(fun(P) when P#player.scene == SceneId andalso P#player.arena /= 3 andalso
									P#player.hp > 0 andalso P#player.id /= AerId andalso 
									P#player.x >= X2 andalso P#player.x =< X1 andalso 
									P#player.y >= Y2 andalso P#player.y =< Y1 andalso 
									P#player.other#player_other.battle_limit /= 9 ->
	    [
            P#player.id,
			P#player.x,
			P#player.y,              
            P#player.max_attack,
            P#player.min_attack,
            P#player.def,
            P#player.hit,
            P#player.dodge,
            P#player.crit,
            P#player.hp,
			P#player.hp_lim,
            P#player.mp,
            P#player.lv,
            P#player.other#player_other.pid,
            P#player.other#player_other.battle_status,
            P#player.realm,
            P#player.guild_id,
            P#player.other#player_other.pid_team,
            P#player.status,
            P#player.evil,
			P#player.realm_honor,
			P#player.pk_mode,
			P#player.other#player_other.leader,
			P#player.anti_wind,
			P#player.anti_water,
			P#player.anti_thunder,
			P#player.anti_fire,
			P#player.anti_soil,
			P#player.nickname
	    ]
	end),
	ets:select(?ETS_ONLINE_SCENE, MS).	
	
%% 获取群攻范围内的玩家
get_scene_user_battle(Aer, Der, AttArea, AreaObj, Ret) ->
	[X, Y] =
		case AreaObj of
			0 ->
				[Der#battle_state.x, Der#battle_state.y];
			_ ->
				[Aer#battle_state.x, Aer#battle_state.y]
		end,
    X1 = X + AttArea,
    X2 = X - AttArea,
    Y1 = Y + AttArea,
    Y2 = Y - AttArea,
	SceneId = Aer#battle_state.scene,
	AerId = 
        case Aer#battle_state.sign of
            1 ->
                0;
            _ ->
                Aer#battle_state.id
        end,
	AllUser = get_scene_user_for_battle(SceneId, AerId, X1, X2, Y1, Y2),
	IsArena = lib_arena:is_arena_scene(SceneId),
	IsWarServer = lib_war:is_war_server(),
    get_scene_user_battle_loop(AllUser, Aer, SceneId, IsArena,IsWarServer, Ret, 0).

%% 获取符合条件的玩家
get_scene_user_battle_loop([], _Aer, _Scene, _IsArena,_IsWarServer, Ret, Blue) ->
    [Ret, Blue];
get_scene_user_battle_loop([[Id, X, Y, MaxAtt, MinAtt, Def, Hit, Dodge, Crit, Hp, _HpLim, Mp, Lv, Pid, BS, Realm, GuildId, TeamPid, Sta, Evil, RealmHonor, PkMode, DerLeader, AntiWind, AntiWater, AntiThunder, AntiFire, AntiSoil,Nickname] | U], 
						   Aer, Scene, IsArena,IsWarServer, Ret, Blue) ->
    [NewRet, RetBlue] =  
        case Aer#battle_state.sign /= 1 of
            %% 攻击方是玩家
            true ->
				case IsArena of
					false ->
						case IsWarServer of
							true->
								case DerLeader > 1 andalso Aer#battle_state.leader == DerLeader of
									false ->
										NewDef = 
											case Aer#battle_state.career of
												1 ->
													AntiWind;
												2 ->
													AntiWater;
												3 ->
													AntiThunder;
												4 ->
													AntiFire;
												_ ->
													AntiSoil
											end,
        		                       	[[[Id, MaxAtt, MinAtt, NewDef, Hit, Dodge, Crit, Hp, Mp, Lv, Pid, 2, BS, 0, Evil, RealmHonor, []] | Ret], Blue];
                		            %%跨服战场不可以打同阵营的人
                        		    true ->
										[Ret, Blue]                         
		                        end;
							false->
                        		case Lv > ?BATTLE_LEVEL andalso PkMode /= 1 
		                                andalso check_battle_mode(Aer#battle_state.pk_mode, Aer#battle_state.realm, Realm, Aer#battle_state.guild_id, GuildId, Aer#battle_state.pid_team, TeamPid, Aer#battle_state.g_alliance) == 1 
        		                        andalso lib_scene:ver_location(Scene, [X, Y], safe) /= true of
                		            true ->
                        		        NewBlue = 
                                		    case Blue == 0 andalso Sta /= 4 andalso Evil < 90 of
                                        		%% 错杀无辜，进入蓝名状态
		                                        true ->	1;
        		                                false -> Blue
                		                    end,
										NewDef = 
											case Aer#battle_state.career of
												1 ->
													AntiWind;
												2 ->
													AntiWater;
												3 ->
													AntiThunder;
												4 ->
													AntiFire;
												_ ->
													AntiSoil
											end,
                                		[[[Id, MaxAtt, MinAtt, NewDef, Hit, Dodge, Crit, Hp, Mp, Lv, Pid, 2, BS, 0, Evil, RealmHonor, []] | Ret], NewBlue];
		                            false ->
        		                        [Ret, Blue]
                		        end
						end;
					true ->
						case DerLeader > 1 andalso Aer#battle_state.leader == DerLeader of
                            false ->
								NewDef = 
									case Aer#battle_state.career of
										1 ->
											AntiWind;
										2 ->
											AntiWater;
										3 ->
											AntiThunder;
										4 ->
											AntiFire;
										_ ->
											AntiSoil
									end,
                               	[[[Id, MaxAtt, MinAtt, NewDef, Hit, Dodge, Crit, Hp, Mp, Lv, Pid, 2, BS, 0, Evil, RealmHonor, []] | Ret], Blue];
                            %% 战场不可以打同阵营的人
                            true ->
								[Ret, Blue]                         
                        end
				end;
            false ->
				%% 镇妖护卫不可以打人
				case Aer#battle_state.type /= 100 of
					true ->
						case Aer#battle_state.type /= 41 of
							true->
								NewDef = 
									case Aer#battle_state.type >= 10 of
										true ->
											MonCareer = Aer#battle_state.type rem 10,
											case MonCareer of
												1 ->
													AntiWind;
												2 ->
													AntiWater;
												3 ->
													AntiThunder;
												4 ->
													AntiFire;
												_ ->
													AntiSoil
											end;
										false ->
											Def
									end,
		                		[[[Id, MaxAtt, MinAtt, NewDef, Hit, Dodge, Crit, Hp, Mp, Lv, Pid, 2, BS, 0, Evil, RealmHonor, []] | Ret], Blue];
							false->
								%%分身不能群攻到玩家自己
								if Aer#battle_state.name /= Nickname ->
									   NewDef = 
											case Aer#battle_state.type >= 10 of
												true ->
													MonCareer = Aer#battle_state.type rem 10,
													case MonCareer of
														1 ->
															AntiWind;
														2 ->
															AntiWater;
														3 ->
															AntiThunder;
														4 ->
															AntiFire;
														_ ->
															AntiSoil
													end;
												false ->
													Def
											end,
		                				[[[Id, MaxAtt, MinAtt, NewDef, Hit, Dodge, Crit, Hp, Mp, Lv, Pid, 2, BS, 0, Evil, RealmHonor, []] | Ret], Blue];
								   true->
									   [Ret, Blue]
								end
						end;
					false ->
						[Ret, Blue]	
				end
        end,
	get_scene_user_battle_loop(U, Aer, Scene, IsArena,IsWarServer, NewRet, RetBlue).


%% 获取群攻范围内的怪物
get_mon_for_battle(Aer, Der, AttArea, AreaObj, Ret) ->
    case Aer#battle_state.sign of    
        %% 战斗发起方是：人
		2 ->  
            AllMon = get_scene_mon_battle(Aer, Der, AttArea, AreaObj),          			
            get_mon_for_user_battle_loop(AllMon, Ret, Aer);
        %% 战斗发起方是：怪
		_ ->
			%% 镇妖台怪物、镇妖台护卫
			case lists:member(Aer#battle_state.type, [98, 99, 100]) of
            	true ->
					AllMon = get_scene_mon_battle(Aer, Der, AttArea, AreaObj),
					OtherMonType =
						case Aer#battle_state.type of
							98 ->
								99;
							99 -> 
								98;
							_ ->
								0
						end,
                    get_mon_for_mon_battle_loop(AllMon, Ret, Aer#battle_state.type, OtherMonType);
				false ->
					Ret	
			end
    end.

%% 获得当前场景怪物信息(用于战斗)
get_scene_mon_battle(Aer, Der, AttArea, AreaObj) ->
	[X, Y] =
   		case AreaObj of
       		0 ->
      			[Der#battle_state.x, Der#battle_state.y];
       		_ ->
     			[Aer#battle_state.x, Aer#battle_state.y]
   		end,
  	X1 = X + AttArea,
  	X2 = X - AttArea,
  	Y1 = Y + AttArea,
   	Y2 = Y - AttArea,
	MS = ets:fun2ms(fun(M) when M#ets_mon.scene == Aer#battle_state.scene andalso M#ets_mon.hp > 0 andalso 
								M#ets_mon.x >= X2 andalso M#ets_mon.x =< X1 andalso 
								M#ets_mon.y >= Y2 andalso M#ets_mon.y =< Y1 andalso 
								(M#ets_mon.type < 6 orelse M#ets_mon.type >= 10) ->
	    [
            M#ets_mon.id,
            M#ets_mon.max_attack,
            M#ets_mon.min_attack,
            M#ets_mon.def,
            M#ets_mon.hit,
            M#ets_mon.dodge,
            M#ets_mon.crit,
            M#ets_mon.hp,
            M#ets_mon.mp,
			M#ets_mon.lv,            
            M#ets_mon.pid,
			1,
            M#ets_mon.battle_status,			
			M#ets_mon.type,
			0,
			M#ets_mon.relation,
			M#ets_mon.anti_wind,
			M#ets_mon.anti_water,
			M#ets_mon.anti_thunder,
			M#ets_mon.anti_fire,
			M#ets_mon.anti_soil
	    ]
	end),
	ets:select(?ETS_SCENE_MON, MS).

%% 获取符合条件的怪物（攻击者是怪）
get_mon_for_mon_battle_loop([], Ret, _AerType, _OtherMonType) ->
    Ret;
get_mon_for_mon_battle_loop([[MonId, MaxAtt, MinAtt, Def, Hit, Dodge, Crit, Hp, Mp, Lv, Pid, Sign, BattleStatus, MonType, Evil, Relation, _AntiWind, _AntiWater, _AntiThunder, _AntiFire, _AntiSoil] | M], Ret, AerType, OtherMonType) ->
	NewRet =
		if
			MonType == AerType orelse MonType == OtherMonType orelse (AerType == 100 andalso MonType == 101) ->
				Ret;
			true ->
				[[MonId, MaxAtt, MinAtt, Def, Hit, Dodge, Crit, Hp, Mp, Lv, Pid, Sign, BattleStatus, MonType, Evil, 0, Relation] | Ret]	
		end,
	get_mon_for_mon_battle_loop(M, NewRet, AerType, OtherMonType).

%% 获取符合条件的怪物（攻击者是人）
get_mon_for_user_battle_loop([], Ret, _Aer) ->
    Ret;
get_mon_for_user_battle_loop([[MonId, MaxAtt, MinAtt, Def, Hit, Dodge, Crit, Hp, Mp, Lv, Pid, Sign, BattleStatus, Type, Evil, Relation, AntiWind, AntiWater, AntiThunder, AntiFire, AntiSoil] | M], Ret, Aer) ->
	NewRet =
		%% 不能打镇妖守卫和剑
		case Type /= 100 andalso Type /= 101 of
			true ->
				%% 和平模式下不能攻击野外BOSS
				case Aer#battle_state.pk_mode == 1 andalso Type == 3 of
					false ->
						case Aer#battle_state.leader == 14 andalso Type == 37 of
							true ->
								Ret;
							false ->
                                NewDef =
                                    case Type >= 10 andalso Type =< 25 of
                                        true ->
                                            case Aer#battle_state.career of
                                                1 -> AntiWind;
                                                2 -> AntiWater;
                                                3 -> AntiThunder;
                                                4 -> AntiFire;
                                                _ -> AntiSoil
                                            end;
                                        false ->
                                            Def
                                    end,
                                [[MonId, MaxAtt, MinAtt, NewDef, Hit, Dodge, Crit, Hp, Mp, Lv, Pid, Sign, BattleStatus, Type, Evil, 0, Relation] | Ret]
						end;
					true ->
						Ret
				end;
			false ->
				Ret	
		end,
	get_mon_for_user_battle_loop(M, NewRet, Aer).

%% 判断是否在攻击范围内
%% AX 攻击方X坐标
%% AY 攻击方y坐标
%% DX 被击方X坐标
%% DY 攻击方y坐标
%% AttArea 攻击距离
check_att_area(AX, AY, DX, DY, AttArea) ->
	NewAttArea = AttArea + 2,
    X = abs(AX - DX),
    Y = abs(AY - DY),
    X =< NewAttArea andalso Y =< NewAttArea.

%%跨服战旗攻击检查(11红方，12蓝方，42903/42905蓝旗 42904/42906红旗)
%% can_att_flag_in_war(_Leader,_Type,_MonId)->
%% 			io:format("Leader,Type,MonId>>~p/~p/~p/~n",[Leader,Type,MonId]),
%% 	case Type of
%% 		36->
%% 			case MonId of
%% 				42904->
%% 					Leader=:=11;
%% 				42906->
%% 					Leader=:=11;
%% 				42903->
%% 					Leader=:=12;
%% 				42905->
%% 					Leader=:=12;
%% 				_->false
%% 			end;
%% 		_->true
%% 	end.


%% 发动攻击 - 玩家VS怪 
%% MonId 怪物ID
%% SkillId 技能ID
battle_mon(PlayerId, MonId, SkillId, SceneId) ->
	case lib_mon:get_player(PlayerId, SceneId) of
		[] ->
			skip;
		Player ->
            case lib_mon:get_mon(MonId, SceneId) of
                [] ->
					skip;
                Mon ->
					battle_mon_action(Player, Mon, SkillId)
            end
	end.
battle_mon(PlayerId, MonId, SkillId, SceneId, List) ->
	case lib_mon:get_player(PlayerId, SceneId) of
		[] ->
			skip;
		Player ->
			NewPlayer = lib_player_rw:set_player_info_fields(Player, List),
			ets:insert(?ETS_ONLINE_SCENE, NewPlayer),
            case lib_mon:get_mon(MonId, SceneId) of
                [] ->
					skip;
                Mon ->
					battle_mon_action(NewPlayer, Mon, SkillId)
            end
	end.
battle_mon_action(Player, Mon, SkillId) ->
	case Mon#ets_mon.type of
		%% 野外BOSS
		3 ->
			%% 和平模式下不能攻击野外BOSS
			if
				Player#player.pk_mode =/= 1 ->
					mod_battle:player_battle([Player, 2], [Mon, 1, Mon#ets_mon.x, Mon#ets_mon.y], SkillId, 0);
				true ->
					battle_fail(19, Player, 2)
			end;
		%% 龙塔
		37 ->
			%% 守护方不能攻击龙塔
			if
				Player#player.other#player_other.leader =/= 14 ->
					mod_battle:player_battle([Player, 2], [Mon, 1, Mon#ets_mon.x, Mon#ets_mon.y], SkillId, 1);
				true ->
					battle_fail(22, Player, 2)
			end;
		%% 神魔BOSS
		39 ->
			mod_battle:player_battle([Player, 2], [Mon, 1, Mon#ets_mon.x, Mon#ets_mon.y], SkillId, 1);
		%% 激活怪
		46 ->
			case gen_fsm:sync_send_all_state_event(Mon#ets_mon.pid,isActive) of
				1 -> 
					mod_battle:player_battle([Player, 2], [Mon, 1, Mon#ets_mon.x, Mon#ets_mon.y], SkillId, 0);
				_ ->
					skip
			end;
		%% 镇妖台护卫
		100 ->
			skip;
		%% 镇妖剑
		101 ->
			skip;
		_ ->
			mod_battle:player_battle([Player, 2], [Mon, 1, Mon#ets_mon.x, Mon#ets_mon.y], SkillId, 0)
	end.


%% 人VS人
battle_player(AerId, DerId, SkillId, SceneId, List) ->
	case lib_mon:get_player(AerId, SceneId) of
		[] ->
			skip;
		Aer ->
			NewAer = lib_player_rw:set_player_info_fields(Aer, List),
			ets:insert(?ETS_ONLINE_SCENE, NewAer),
            case lib_mon:get_player(DerId, SceneId) of 
                [] ->
                    skip;
                %% 被击者
                Der ->
					battle_player_action(NewAer, Der, SceneId, SkillId)
            end
	end.
%% 人VS人
battle_player(AerId, DerId, SkillId, SceneId) ->
	case lib_mon:get_player(AerId, SceneId) of
		[] ->
			skip;
		Aer ->
            case lib_mon:get_player(DerId, SceneId) of 
                [] ->
                    skip;
                %% 被击者
                Der ->
					battle_player_action(Aer, Der, SceneId, SkillId)
            end
	end.
battle_player_action(Aer, Der, SceneId, SkillId) ->
	%% 是否在战场
    case lib_arena:is_arena_scene(SceneId) of
        false ->
            case SceneId of
                %% 空战
                ?SKY_RUSH_SCENE_ID ->
                    guild_fight(Aer, Der, SceneId, SkillId);
                %% 野外竞技场
                ?FREE_PK_SCENE_ID ->
                    free_fight(Aer, Der, SceneId, SkillId);
                %% 攻城战
                ?CASTLE_RUSH_SCENE_ID ->
                    castle_rush_fight(Der, Aer, SkillId);
				%% 神魔乱斗
				?WARFARE_SCENE_ID ->
					warfare_fight(Aer, Der, SceneId, SkillId);
                _ ->
					%% 是否在竞技场
					case lib_coliseum:is_coliseum_scene(SceneId) of
						true ->
							coliseum_fight(Aer, Der, SkillId);
						false ->
							case lib_war:is_war_scene(SceneId) of
								true ->
		                            war_fight(Der, Aer, SceneId, SkillId);
		                        false ->
									case lib_era:is_era_scene(SceneId) of
										true ->
											era_fight(Aer, Der, SceneId, SkillId);
										false ->
		                            		%% 普通PK
		                          			normal_fight(Der, Aer, SceneId, SkillId)
									end
		                    end				
					end
            end;
        true ->
            %% 战场
            arena_fight(Der, Aer, SkillId)
    end.


%% 普通Pk
normal_fight(Der, Aer, SceneId, AerSkillId)->
	%% 不在氏族领地里，可以PK
	case lib_guild_manor:is_guild_manor_scene(SceneId, Der#player.guild_id) of
		false ->
			%% 判断攻击方是否在安全区
            case lib_scene:ver_location(SceneId, [Aer#player.x, Aer#player.y], safe) == false of
                true ->
                    %% 判断被击方是否在安全区
                    case lib_scene:ver_location(SceneId, [Der#player.x, Der#player.y], safe) == false of
%%                             andalso lib_scene:ver_location(SceneId, [Der#player.x, Der#player.y], exc) == false) of 
                        true ->
                            case Aer#player.status /= 8 of
                                true ->
									if
                                  		Aer#player.lv > ?BATTLE_LEVEL andalso Der#player.lv > ?BATTLE_LEVEL ->
                                            case Der#player.pk_mode =/= 1 of
                                                true ->
                                                    %%根据战斗模式判断是否可以攻击
                                                    AerPkMode = Aer#player.pk_mode,
                                                    BattleMode = lib_battle:check_battle_mode(AerPkMode, Aer#player.realm, Der#player.realm, Aer#player.guild_id, Der#player.guild_id, Aer#player.other#player_other.pid_team, Der#player.other#player_other.pid_team, Aer#player.other#player_other.g_alliance),
                                                    case (Der#player.status == 4 andalso (AerPkMode == 5 orelse (lists:member(AerPkMode, [2, 3, 4]) == true andalso BattleMode == 1)))
                                                    		orelse 1 == BattleMode of
                                                        true ->
															%%被攻击了，玩家氏族求助
                                                         	lib_guild_call:pk_call_guildhelp(Aer#player.realm, Aer#player.guild_name, Aer#player.guild_id, Aer#player.nickname, Der),
                                                            %%向配偶求助
 															spawn(fun()->lib_marry:cast_Der([Der,Aer#player.nickname,Aer#player.id]) end), 
															mod_battle:player_battle([Aer, 2], [Der, 2, Der#player.x, Der#player.y], AerSkillId, 0);
                                                        false ->
                                                            lib_battle:battle_fail(8, Aer, 2)
                                                    end;
                                                false ->
                                                    lib_battle:battle_fail(13, Aer, 2)
                                            end;	
                                        true ->
                                            lib_battle:battle_fail(10, Aer, 2)
                                    end;
                                false ->
                                    skip
                            end;
                        false ->
                            lib_battle:battle_fail(11, Aer, 2)
                    end;
                false ->
                    lib_battle:battle_fail(11, Aer, 2)
            end;
		true ->%%在氏族领地里，不可以PK
			lib_battle:battle_fail(14, Aer, 2)
	end.


%% 自由PK场
free_fight(Aer, Der, SceneId, AerSkillId) ->
	%% 判断攻击方是否在安全区
	case lib_scene:ver_location(SceneId, [Aer#player.x, Aer#player.y], safe) == false of
    	true ->
        	%% 判断被击方是否在安全区
        	case lib_scene:ver_location(SceneId, [Der#player.x, Der#player.y], safe) == false 
                	andalso lib_scene:ver_location(SceneId, [Der#player.x, Der#player.y], exc) == false of 
            	true ->
					case Aer#player.lv > ?BATTLE_LEVEL andalso Der#player.lv > ?BATTLE_LEVEL of
						true ->
							mod_battle:player_battle([Aer, 2], [Der, 2, Der#player.x, Der#player.y], AerSkillId, 0);
						false ->
							lib_battle:battle_fail(10, Aer, 2)
					end;
				false ->
					lib_battle:battle_fail(11, Aer, 2)
			end;
		false ->
			lib_battle:battle_fail(11, Aer, 2)
	end.


%% 跨服战场Aer
war_fight(Der,Aer,SceneId,AerSkillId)->
	case Der#player.other#player_other.battle_limit /= 9 andalso Aer#player.other#player_other.battle_limit /= 9 of
		true ->
			case Aer#player.other#player_other.leader > 1 andalso Aer#player.other#player_other.leader == Der#player.other#player_other.leader of
				false ->
					case lib_scene:ver_location(SceneId, [Aer#player.x, Aer#player.y], safe) == false 
							 andalso lib_scene:ver_location(SceneId, [Der#player.x, Der#player.y], safe) == false of
						true->
							if Der#player.carry_mark == 29 orelse Aer#player.carry_mark ==29 ->
								   lib_battle:battle_fail(11, Aer, 24);
							   true->
								   mod_battle:player_battle([Aer, 2], [Der, 2, Der#player.x, Der#player.y], AerSkillId, 0)
							end;
						false->
							lib_battle:battle_fail(11, Aer, 2)
					end;
				%% 不可以打同阵营的人
				true ->
							lib_battle:battle_fail(15, Aer, 2)
					end;
		false ->
			%%无敌状态
			lib_battle:battle_fail(16, Aer, 2)
	end.


%% 氏族战
guild_fight(Aer,Der,SceneId,AerSkillId)->
	%% 不能打同一氏族的人
	case Aer#player.guild_id =:= Der#player.guild_id of
		true ->
			lib_battle:battle_fail(15, Aer, 2);
		false ->
			case lib_scene:ver_location(SceneId, [Aer#player.x, Aer#player.y], safe) =:= true 
					orelse lib_scene:ver_location(SceneId, [Der#player.x, Der#player.y], safe) =:= true of
				%% 安全区不能打
				true ->
					lib_battle:battle_fail(11, Aer, 2);
				false ->
					mod_battle:player_battle([Aer, 2], [Der, 2, Der#player.x, Der#player.y], AerSkillId, 0)
%% 					case mod_battle:player_battle([Aer, 2], [Der, 2, Der#player.x, Der#player.y], AerSkillId, 0) of
%% 						undefined ->
%% 							skip
%% 						NewAer ->
%% 							lib_skyrush:discard_flags_battle(1, [AerType, AerInit0], [DerType, DerInit0])
%% 					end
			end
	end.

%% 战场
coliseum_fight(Aer, Der, SkillId) ->
	Now = util:unixtime(),
    if
 		Now > Aer#player.other#player_other.die_time ->
			mod_battle:player_battle([Aer, 2], [Der, 2, Der#player.x, Der#player.y], SkillId, 0);
        true ->
            battle_fail(23, Aer, 2)
    end.

%% 战场
arena_fight(Der, Aer, AerSkillId) ->
	%% 判断新老战场
	case lib_arena:is_new_arena_scene(Aer#player.scene) of
		true ->
			arena_fight_action(Aer, Der, AerSkillId);
		false ->
			if
				Aer#player.arena /= 3 andalso Der#player.arena /= 3 ->
			        %% 对方处于无敌状态
			        if
			            Der#player.other#player_other.battle_limit /= 9 ->
			                arena_fight_action(Aer, Der, AerSkillId);
			            true ->
			                Now = util:unixtime(),
			                if
			             		Now - Der#player.other#player_other.die_time > 5 ->
			                        NewDer = Der#player{
			                            other = Der#player.other#player_other{
			                                battle_limit = 0
			                            }						
			                        },
			                        ets:insert(?ETS_ONLINE_SCENE, NewDer),
			                        arena_fight_action(Aer, NewDer, AerSkillId);
			                    true ->
			                        battle_fail(16, Aer, 2)
			                end
			        end;
				true ->
					skip
			end
	end.
	
arena_fight_action(Aer, Der, AerSkillId) ->
	%% 战场不可以打同阵营的人
	if
		Aer#player.other#player_other.leader > 1 andalso Aer#player.other#player_other.leader == Der#player.other#player_other.leader ->
			battle_fail(15, Aer, 2);
		true ->
			mod_battle:player_battle([Aer, 2], [Der, 2, Der#player.x, Der#player.y], AerSkillId, 0)
	end.

%% 攻城战
castle_rush_fight(Der, Aer, AerSkillId) ->
	%% 对方处于无敌状态
	case Der#player.other#player_other.battle_limit /= 9 of
		true ->
			case Der#player.pk_mode =/= 1 of
                true ->
                    %%根据战斗模式判断是否可以攻击
                    case 1 == lib_battle:check_battle_mode(Aer#player.pk_mode, Aer#player.realm, Der#player.realm, Aer#player.guild_id, Der#player.guild_id, Aer#player.other#player_other.pid_team, Der#player.other#player_other.pid_team, Aer#player.other#player_other.g_alliance) of
                        true ->
							mod_battle:player_battle([Aer, 2], [Der, 2, Der#player.x, Der#player.y], AerSkillId, 2);
                        false ->
                            lib_battle:battle_fail(8, Aer, 2)
                    end;
                false ->
                    lib_battle:battle_fail(13, Aer, 2)
            end;	
		false ->
			lib_battle:battle_fail(16, Aer, 2)
	end.

%% 神魔乱斗
warfare_fight(Aer, Der, SceneId, SkillId) ->
	%% 判断攻击方是否在安全区（神魔乱斗里面，当被攻击方头上有冥王之灵的时候，无视安全区）
    case lib_scene:ver_location(SceneId, [Aer#player.x, Aer#player.y], safe) == false orelse Der#player.carry_mark =:= 27 of
        true ->
            %% 判断被击方是否在安全区
            case lib_scene:ver_location(SceneId, [Der#player.x, Der#player.y], safe) == false orelse Der#player.carry_mark =:= 27 of
                true ->
                    case Der#player.pk_mode =/= 1 of
                        true ->
                            %%根据战斗模式判断是否可以攻击
                            case 1 == lib_battle:check_battle_mode(Aer#player.pk_mode, Aer#player.realm, Der#player.realm, Aer#player.guild_id, Der#player.guild_id, Aer#player.other#player_other.pid_team, Der#player.other#player_other.pid_team, Aer#player.other#player_other.g_alliance) of
                                true ->
									mod_battle:player_battle([Aer, 2], [Der, 2, Der#player.x, Der#player.y], SkillId, 2);																																																																								   
                                false ->
                                    lib_battle:battle_fail(8, Aer, 2)
                            end;
                        false ->
                            lib_battle:battle_fail(13, Aer, 2)
                    end;	
                false ->
                    lib_battle:battle_fail(11, Aer, 2)
            end;
        false ->
            lib_battle:battle_fail(11, Aer, 2)
    end.

%% 封神纪元
era_fight(Aer,Der,_SceneId,SkillId) ->
	mod_battle:player_battle([Aer, 2], [Der, 2, Der#player.x, Der#player.y], SkillId, 2).
	
%% 检查玩家战斗限制状态
%% Aer 攻击方
%% SkillId 技能ID
%% Type 1怪，2人
check_battle_limit(Aer, SkillId) ->
	case Aer#player.other#player_other.battle_limit of
		%% 昏迷状态下不能发起战斗
		2 ->
			{fail, 9};
		%% 沉默（封技）状态下不能使用技能
		3 ->
			if
				SkillId > 0 ->
					battle_fail(12, Aer, 2);
				true ->
					skip
			end,
			{ok, 0};
		_ ->
			{ok, SkillId}
	end.

%% 流血技能
hp_bleed(PlayerId, SceneId, Hurt, ValType, Pid, Id, NickName, Career, Realm) ->
	case lib_mon:get_player(PlayerId, SceneId) of
		[] ->
			skip;
		Player ->
            if
                Player#player.hp > 0 andalso Player#player.status =/= 3 ->
                    if
						ValType == 0 ->
							NewHurt = Hurt;
						true ->
							NewHurt =  round(Player#player.hp_lim * (Hurt / 100))
					end,
					NewHp =
						if
							%% 流血
                       		Hurt > 0 ->
								if
                              		Player#player.hp < NewHurt ->
                                        0;
                                  	true ->
                                        Player#player.hp - NewHurt 
                                end;
                            %% 加血
                           	true ->
                                AddHp = Player#player.hp - NewHurt,
								if
                              		AddHp > Player#player.hp_lim ->
                                        Player#player.hp_lim;
                                  	true ->
                                        AddHp
                                end
                        end,
                    NewPlayer = Player#player{
                        hp = NewHp
                    },
                    %%  广播给附近玩家
                    {ok, BinData} = pt_12:write(12009, [NewPlayer#player.id, NewPlayer#player.hp, NewPlayer#player.hp_lim]),
                    lib_send:send_to_online_scene(SceneId, NewPlayer#player.x, NewPlayer#player.y, BinData),
                    lib_team:update_team_player_info(NewPlayer),
                    NewPlayer#player.other#player_other.pid ! {'BLEED_HP', NewHp, Pid, Id, NickName, Career, Realm}, 
                    ets:insert(?ETS_ONLINE_SCENE, NewPlayer);
                true ->
                    skip
            end
	end.

%% 模式修改
change_pk_mode(Player, Result, RetMode, RetPkTime, Mode) ->
	{ok, BinData} = pt_13:write(13012, [Result, RetMode]),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),   
    case Result of
        1 ->
            NewPlayer = 
                case RetPkTime > 0 of
                    true ->
                        Player#player{
                            pk_mode = Mode,
                            pk_time = RetPkTime
                        };
                    false ->
                        Player#player{
                            pk_mode = Mode
                        }
                end,
            mod_player:save_online_info_fields(NewPlayer, [{pk_mode, Mode}, {pk_time, NewPlayer#player.pk_time}]),
            {ok, change_status, NewPlayer};
        _ ->
            skip
    end.

%% 检测辅助技能对象
check_assist_object(Aer, Der) ->
	case Aer#player.pk_mode of
		%% 和平
		1 ->
			Der;
		%% 部落
		2 ->
			if
				Aer#player.realm =/= Der#player.realm ->
					Aer;
				true ->
					Der
			end;
		%% 氏族
		3 ->
			if
				Aer#player.guild_id =/= Der#player.guild_id ->
					Aer;
				true ->
					Der
			end;
		%% 组队
		4 ->
			if
				Aer#player.other#player_other.pid_team /= undefined 
				  		andalso Aer#player.other#player_other.pid_team == Der#player.other#player_other.pid_team ->
					Der;
				true ->
					Aer
			end;
		%% 全体
		5 ->
			Aer;
		%% 联盟模式
		6 ->
			if 
                Aer#player.guild_id /= 0 andalso Aer#player.guild_id == Der#player.guild_id ->
               		Der;
                true ->
					case lists:member(Der#player.guild_id, Aer#player.other#player_other.g_alliance) of
						true ->
							Der;
						false ->
							Aer
					end
            end;
		_ ->
			Der
	end.
	

%% 生命血量共享
share_mon_hp(Aer, Der, MonId, Hurt, DerHp, DerMp, Sta, Result) ->
	case lib_mon:get_mon(MonId, Der#battle_state.scene) of
        [] ->
          	mod_battle:update_der_hp(Der, Aer, DerHp, DerMp, Hurt),
            [[Der#battle_state.sign, Der#battle_state.id, DerHp, DerMp, Hurt, 0, Sta] | Result];
        ShareMon ->
			#battle_state{
				id = AttId,
				name = AttName,
				pid = AttPid,
				pid_team = AttTeamPid
			} = Aer,
            ShareHurt = util:ceil(Hurt / 2),
            MonHp = 
				if
              		Der#battle_state.hp > ShareMon#ets_mon.hp ->
                        Der#battle_state.hp;
                    true ->
						ShareMon#ets_mon.hp
                end,
            ShareHp = 
				if
              		MonHp > ShareHurt ->
                  		MonHp - ShareHurt;
                    true ->
                        0
                end,
            Hate = mod_battle:add_hate(Aer, Hurt),
            Der#battle_state.pid ! {'MON_BOSS_BATTLE_RESULT', [ShareHp, AttId, AttName, AttPid, Hate, AttTeamPid, 2]},
            ShareMon#ets_mon.pid ! {'MON_BOSS_BATTLE_RESULT', [ShareHp, AttId, AttName, AttPid, 0, AttTeamPid, 2]},
            [[1, MonId, ShareHp, ShareMon#ets_mon.mp, ShareHurt, 0, 0] | [[1, Der#battle_state.id, ShareHp, Der#battle_state.mp, ShareHurt, 0, Sta] | Result]]
    end.


%% 怪物伤害共享
share_mon_hrut(Aer, Der, MonId, Hurt, DerHp, DerMp, Sta, Result) ->
	case lib_mon:get_mon(MonId, Der#battle_state.scene) of
        [] ->
          	mod_battle:update_der_hp(Der, Aer, DerHp, DerMp, Hurt),
            [[Der#battle_state.sign, Der#battle_state.id, DerHp, DerMp, Hurt, 0, Sta] | Result];
        ShareMon ->
			#battle_state{
				id = AttId,
				name = AttName,
				pid = AttPid,
				pid_team = AttTeamPid
			} = Aer,
            ShareHurt = util:ceil(Hurt / 2),
            MonHp = 
				if
              		Der#battle_state.hp > ShareHurt ->
						Der#battle_state.hp - ShareHurt;
                    true ->
						0
                end,
            ShareHp = 
				if
              		ShareMon#ets_mon.hp > ShareHurt ->
                  		ShareMon#ets_mon.hp - ShareHurt;
                    true ->
                        0
                end,
            Hate = mod_battle:add_hate(Aer, Hurt),
            Der#battle_state.pid ! {'MON_BOSS_BATTLE_RESULT', [MonHp, AttId, AttName, AttPid, Hate, AttTeamPid, 2]},
            ShareMon#ets_mon.pid ! {'MON_BOSS_BATTLE_RESULT', [ShareHp, AttId, AttName, AttPid, Hate, AttTeamPid, 2]},
            [[1, MonId, ShareHp, ShareMon#ets_mon.mp, ShareHurt, 0, 0] | [[1, Der#battle_state.id, MonHp, Der#battle_state.mp, ShareHurt, 0, Sta] | Result]]
    end.

%% 分身伤害平分
share_shadow_hrut(Aer,Der,ShadowId,Hurt,DerHp, DerMp, Sta, Result) ->
	case lib_scene:get_scene_user_info(ShadowId) of
		[] ->
			mod_battle:update_der_hp(Der, Aer, DerHp, DerMp, Hurt),
            [[Der#battle_state.sign, Der#battle_state.id, DerHp, DerMp, Hurt, 0, Sta] | Result];
		Shadow ->
			#battle_state{
				id = AttId,
				name = AttName,
				pid = AttPid,
				pid_team = AttTeamPid
			} = Aer,
            ShareHurt = util:ceil(Hurt / 2),
            MonHp = 
				if
              		Der#battle_state.hp > ShareHurt ->
						Der#battle_state.hp - ShareHurt;
                    true ->
						0
                end,
            ShareHp = 
				if
              		Shadow#player.hp > ShareHurt ->
                  		Shadow#player.hp - ShareHurt;
                    true ->
                        0
                end,
            Hate = mod_battle:add_hate(Aer, Hurt),
            Der#battle_state.pid ! {'MON_BOSS_BATTLE_RESULT', [MonHp, AttId, AttName, AttPid, Hate, AttTeamPid, 2]}, 
            Shadow#player.other#player_other.pid ! {'PLAYER_BATTLE_RESULT', [ShareHp, Shadow#player.mp, 0, 0, 0, 0,0, Aer#battle_state.scene]},
			 %% 更新分身血量，广播给附近玩家
			spawn(fun()->
            		{ok, BinData} = pt_12:write(12009, [Shadow#player.id, ShareHp,Shadow#player.hp_lim]),
					lib_send:send_to_online_scene(Shadow#player.scene, Shadow#player.x, Shadow#player.y, BinData)
			end),
            [[1, Der#battle_state.id, MonHp, Der#battle_state.mp, ShareHurt, 0, Sta] | Result]
    end.


%% 更新玩家的战斗限制状态
%% Der 被击方
%% Buff Buff信息
%% LastTime 状态的持续时间
%% BattLimit 限制状态
update_battle_limit(Der, LastTime, BattleLimit, Key, Val, SkillId, Slv, Now) ->
	DerBuff = Der#battle_state.battle_status,
	BuffData = {Key, Val, Now + LastTime, SkillId, Slv},
	Buff = 
		case lists:keyfind(Key, 1, DerBuff) of
			false ->
				[BuffData | DerBuff];									
			_BuffData ->
				lists:keyreplace(Key, 1, DerBuff, BuffData)
		end,   
    case Der#battle_state.sign of
        %% 玩家
		2 ->  
			Der#battle_state.pid ! {'SET_BATTLE_STATUS', {1, [Buff, BattleLimit, LastTime * 1000]}};		
        %% 怪物
		_ ->
			%% BOSS怪无战斗限制
			case lib_mon:is_boss_mon(Der#battle_state.type) of
				false ->
					Der#battle_state.pid ! {'SET_MON_LIMIT', 2, [BattleLimit, LastTime * 1000]};
				true ->
					skip
			end
    end.


%% 减速
battle_speed(Der, DerInit, LastTime, Val, SkillId, Slv, Now) ->
	case Der#battle_state.sign of
        %% 人
		2 ->
            Speed = DerInit#player.speed,
            NewSpeed = round(Speed * (1 + Val)),
            Buff = [{speed, Val, Now + LastTime, SkillId, Slv} | Der#battle_state.battle_status],
			Der#battle_state.pid ! {'SET_BATTLE_STATUS', {2, [Buff, DerInit#player.mount, NewSpeed, Speed, LastTime * 1000]}};
        %% 怪
		_ ->
			case lib_mon:is_boss_mon(Der#battle_state.type) of
				false ->
            		Speed = DerInit#ets_mon.speed,
            		NewSpeed = round(Speed * (1 + Val)),	
					Der#battle_state.pid ! {'SET_MON_LIMIT', 1, [Speed, NewSpeed, LastTime * 1000]};
				true ->
					skip
			end
    end.


%% 持续流血
battle_drug(Aer, Der, LastTime, Val) ->
	AttPid = 
		case Aer#battle_state.sign of
			2 ->
				Aer#battle_state.pid;
			_ ->
				0
		end,										
    case Der#battle_state.sign of
        2 -> 
            Msg = {'START_HP_TIMER', AttPid, Aer#battle_state.id, Aer#battle_state.name, Aer#battle_state.career, Aer#battle_state.realm, Val, 0, LastTime, 1000},
            Der#battle_state.pid ! {'SET_TIME_PLAYER', 1000, Msg};
        _ ->
       		Msg = {'START_HP_TIMER', Aer#battle_state.id, AttPid, Val, 0, LastTime, 1000},
          	Der#battle_state.pid ! {'SET_TIME_MON', 1000, Msg}
    end.

