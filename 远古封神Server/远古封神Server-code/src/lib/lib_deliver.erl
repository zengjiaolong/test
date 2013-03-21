%%%--------------------------------------
%%% @Module  : lib_deliver
%%% @Author  : lzz
%%% @Created : 2010.12.19
%%% @Description:传送相关处理
%%%--------------------------------------
-module(lib_deliver).
-export([
		 deliver/2, 
		 deliver/5,
		 fix_home/2,
		 back_home/2,
		 could_deliver/1,
		 check_scene_enter/1,
		 light_deliver/3,
		 get_px/2
		]).
-include("common.hrl").
-include("record.hrl"). 
-include("guild_info.hrl").
-include("hot_spring.hrl").

%%传送
deliver(Status, Scid) ->
	Tar_scid =
		if 
			Scid =:= 1 ->
				case Status#player.realm of
					3 -> 250;
					2 -> 280;
					1 -> 200;
					_ -> 0
				end;
			true ->
				Scid
		end,
	case data_deliver:get_delivers(Tar_scid) of
		{error,_,_} ->
			[[9, 0, 0],Status];
		{Lvl, Cost, [X, Y]} ->
			if 
				Status#player.lv < Lvl ->
					[[2, 0, 0],Status];
				true ->
					case goods_util:is_enough_money(Status, Cost, coin) of
						false ->
							[[3, 0, 0],Status];
						_ ->
							case could_deliver(Status) of
								ok ->
									NewStatus = change_scene(Status, Tar_scid,Tar_scid, X, Y),
									NewStatus1 = lib_goods:cost_money(NewStatus, Cost, coin, 3111),
									[[1, NewStatus1#player.coin, NewStatus1#player.bcoin],NewStatus1];
								Res ->
									[[Res, 0, 0],Status]
							end
					end
			end
	end.

%%绑定回城石
fix_home(Status, Scid) ->
	if 
		Scid =:= Status#player.scene ->
			GoodTypeId = 28200,
			Res_goods = lib_goods:goods_find(Status#player.id,GoodTypeId),
			case Res_goods of
				false ->
					2;
				Stone ->
%%					[_, StoneId|_Tail] = tuple_to_list(Stone),
%% ?DEBUG("handle_31001_~p/~p ~n",[Scid, StoneId]),
					lib_goods:mod_goods_otherdata(Stone, util:term_to_string([Status#player.id, Scid, Status#player.x, Status#player.y])),
					1
			end;
		true ->
			2
	end.
	
%%使用回城石
back_home(Status, Goodsinfo) ->
	case util:bitstring_to_term(Goodsinfo#goods.other_data) of
		undefined -> [3, ok];
		[_Pid, Scid, X, Y] ->
 			case could_deliver(Status) of
				ok ->
					case lib_goods:cd_add(Status,Goodsinfo) of
						skip ->
							[2, ok];
						_ ->
							[X1,Y1] = case Scid of
										  300->[102,162];
										  _->[X,Y]
									  end,
							NewStatus = change_scene(Status, Scid,Scid, X1,Y1),
							[1, {ok, NewStatus}]
					end;
				Res ->
					[Res, ok]
 			end;
		_ ->
			[3, ok]
	end.

	
change_scene(Player, SceneId,ResId, X, Y) ->
	%% 是否在打坐
	{ok, SitPlayer} = 
		if
			Player#player.status =/= 6 ->
				%% 判断是否在挂机
				HookPlayer = lib_hook:cancel_hoook_status(Player),
				{ok, HookPlayer};	
			true ->
				{ok, SitBinData} = pt_13:write(13015, [Player#player.id, 0]),
				lib_send:send_to_sid(Player#player.other#player_other.pid_send, SitBinData),
				lib_player:cancelSitStatus(Player)			
		end,
	%% 告诉原场景的玩家你已经离开
  	pp_scene:handle(12004, Player, Player#player.scene),
	SceneResId = lib_scene:get_res_id(SceneId),
	SceneName =
		case data_scene:get(SceneResId) of
			[] ->
				<<>>;
			Scene ->
				Scene#ets_scene.name
		end,
	{ok, BinData} = pt_12:write(12005, [SceneId, X, Y, SceneName, ResId, 0, 0, 0]),
  	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	%% 做坐标记录
	put(change_scene_xy , [X, Y]),
	%% 更新玩家新坐标
  	ValueList = [{scene, SceneId}, {x, X}, {y, Y}],
  	WhereList = [{id, Player#player.id}],
  	spawn(fun()-> db_agent:mm_update_player_info(ValueList, WhereList) end),
	case SceneId =:= 300 orelse Player#player.scene =:= 300 of
		true ->
			erlang:send_after(2000, self(), {'PEACH_SCENE_CHANGE'});
		false ->
			skip
	end,
	SitPlayer#player{
		scene = SceneId, 
		x = X, 
		y = Y
	}.


%%通用的传送判断（竞技场传送不适用）
%%返回值：Res（ok或者数字）10~30状态， 31~43位置
%%	10 战斗中
%%	11死亡中
%%	12蓝名
%%	13挂机状态
%%	14打坐状态
%%	15凝神修炼
%%	16挖矿状态
%%	17答题状态 
%% 18双修不能使用筋斗云
%%	21红名（罪恶值>=450）
%%	22运镖状态
%%
%%	31副本中
%%	32氏族领地
%%	33竞技场
%%	34封神台
%%  35秘境
%%  36空岛
%%  37镇妖台
%%  38诛仙台
%%  39温泉
%%  40封神大会不能使用筋斗云
%%	41神魔乱斗中，不能传送
%%	42攻城战
%%  43婚宴
%%  44洞房
%%  45竞技场
%%  46新手

could_deliver(Status) ->
	Sta = lib_player:player_status(Status),
	%%和平模式不影响战斗状态
	PkMode = 
		if 
			Sta =:= 2 ->
				if 
					Status#player.pk_mode =:= 1 -> 
						1;
					true -> 
						10
				end;
			true ->
				1
		end,
	case PkMode of
		10->10;
		_->
	if
		Sta > 2 andalso Sta =< 10 andalso Sta =/= 5 andalso Sta =/= 6 ->
			Sta + 8;
		%% 和平模式下的挂机状态可以传送
		Sta =:= 5 andalso Status#player.pk_mode =/= 1 ->
			Sta + 8;
		Status#player.evil >= 450 ->
			21;
		Status#player.carry_mark > 0 andalso Status#player.carry_mark =< 7 orelse (Status#player.carry_mark >=20 andalso Status#player.carry_mark<26)->
			22;
		Status#player.carry_mark =:= 27 ->
			41;
		Status#player.realm == 100-> 
			46;%%新手不能传送
		true ->
			case lib_scene:is_dungeon_scene(Status#player.scene) of
				true ->
					31;
				_ ->
					case lib_guild_manor:is_guild_manor_scene(Status#player.scene, Status#player.guild_id) of
						true ->
							32;
						_ ->
							case lib_arena:is_arena_scene(Status#player.scene) of
								true ->
									33;
								_ ->
									case lib_scene:is_fst_scene(Status#player.scene) of
										true ->
											34;
										_ ->
											case lib_box_scene:is_box_scene_idsp_for_team(Status#player.scene, Status#player.id) of
												true ->
													35;
												_ ->
													case lib_scene:is_td_scene(Status#player.scene) of
														true ->
															37;
														_ ->
															case lib_scene:is_zxt_scene(Status#player.scene) of
																true->38;
																_->
																	case lib_spring:is_spring_scene(Status#player.scene) of
																		true ->%%在温泉里
																			39;
																		false ->
																			case lib_war:is_war_scene(Status#player.scene) of
																				true -> 
																					40;
																				false ->
																					%% 70副本（幻魔穴）
																					case lib_cave:is_cave_scene(Status#player.scene) of
																						true ->
																							31;
																						false ->
																							%% 竞技场
																							case lib_coliseum:is_coliseum_scene(Status#player.scene) of
																								true ->
																									45;
																								false ->
																									case Status#player.scene of
																										%% 九霄攻城战
																										?CASTLE_RUSH_SCENE_ID ->
																											42;
																										?WARFARE_SCENE_ID ->
																											41;
																										?WEDDING_SCENE_ID ->
																											43;
																										?WEDDING_LOVE_SCENE_ID ->
																											44;
																										%% 空岛
																										?SKY_RUSH_SCENE_ID ->
																											36;
																										Scene ->
																											case is_train_scene(Scene) of
																												true ->
																													31;
																												false ->
																													%% 封神纪元
																													case lib_era:is_era_scene(Scene) of
																														true ->
																															31;
																														false ->
																															ok
																													end
																											end
																									end
																							end
																					end
																			end
																	end
															end
													end
											end
									end
							end
					end
			end
	end
	end.

%%是否试炼副本
is_train_scene(Scene)->
	Scene rem 1000 == 901 .


%% 传送(筋斗云)
deliver(Player, SceneId, X, Y, MoneyType)->
	if 
		MoneyType =:= 1 orelse MoneyType =:= 2 ->
			spawn(fun()-> db_agent:log_deliver(Player#player.id, MoneyType, util:unixtime()) end);
	   	true -> 
			skip
	end,
	%% 处理挂机区
	lib_scene:set_hooking_state(Player, SceneId),
	%% 传送到雷泽时固定到101地图
	{NewSceneId,SceneResId} = 
		case lists:member(SceneId, [101, 191, 190]) of
			true ->
				OnlineNum =(catch mod_online_count:get_online_num()),
				if
					OnlineNum >= 3000 ->
						{191,101};
					OnlineNum >= 1800 ->
						{190,101};
					true ->
						{101,101}
				end;
			false ->
				case lists:member(SceneId, data_scene:get_hook_scene_list()) of
					true ->
						{SceneId,120};
					false ->
						{SceneId,SceneId}
				end
		end,
	Rand = util:rand(-2, 2),
	change_scene(Player, NewSceneId,SceneResId, X + Rand, Y + Rand).
	

%%副本，战场场景进入检测
check_scene_enter(SceneId)->
	
	if 	SceneId =:= 705->
			true;
		SceneId >= 500 ->
			false;
	   true->
		   true
	end.

%% 轻功传送
light_deliver(Status, X, Y) ->
	if 
		Status#player.status == 10 ->
           [16,Status];%%双修，不能使用轻功
		Status#player.lv < 30 ->
			[2,Status];%%等级不足30级,不能使用轻功
		(Status#player.carry_mark >= 1  andalso Status#player.carry_mark =< 3)  orelse (Status#player.carry_mark >= 20  andalso Status#player.carry_mark =< 25)->
           [7,Status];%%运镖状态，不能使用轻功
        Status#player.carry_mark >= 4  andalso Status#player.carry_mark =< 7 ->
           [8,Status];%%跑商状态，不能使用轻功
        Status#player.carry_mark >= 8  andalso Status#player.carry_mark =< 11 ->
           [9,Status];%%神岛空战运旗中，不能使用轻功
        Status#player.carry_mark >= 12  andalso Status#player.carry_mark =< 15 ->
           [10,Status];%%神岛空战运魔核中，不能使用轻功
        Status#player.scene =:= ?SPRING_SCENE_VIPTOP_ID ->
           [11,Status];%%温泉内，不能使用轻功		
        Status#player.other#player_other.battle_limit >= 1 andalso Status#player.other#player_other.battle_limit  =< 3 -> 
           [12,Status];%%被晕，被沉默，被定神，不能使用轻功
        Status#player.status == 8 -> 
           [13,Status];%%采矿状态，不能使用轻功	
        Status#player.status == 6 orelse Status#player.status == 7 ->
           [15,Status];%%打坐，凝神，吃桃，双修，不能使用轻功
		Status#player.carry_mark =:= 26->
		   [17,Status];%%封神大会运旗状态不能使用轻功
		Status#player.scene =:= ?WEDDING_SCENE_ID ->
		   [18,Status];%%婚宴场景不能使用轻功
		Status#player.scene =:= ?WEDDING_LOVE_SCENE_ID ->
		   [19,Status];%%洞房场景不能使用轻功
		true ->
			case lists:keyfind(50000, 1, Status#player.other#player_other.light_skill) of
				false ->
					[3, Status];			%%没有学轻功技能,不能使用轻功
				%% 升级技能
				{_, Light_Lv} ->
					case data_agent:get_light_skill(50000, Light_Lv) of
						[] ->
							[4,Status];%%学轻功技能信息异常,不能使用轻功
						Skill_Data ->
                            [_Player_NeedLv,_Skill_Lv,_Culture,_Coin,_Skill_Book,Cd,Mp,Distance] = Skill_Data,
                            CurrentTime = util:unixtime(),
                            LastTime = 
                                case get(light_skill) of
                                    undefined ->
                                        0;
                                    LastUseTime ->
                                        LastUseTime
                                end,
							if
								CurrentTime - LastTime < Cd ->
									[5,Status];%%技能冷却中,不能使用轻功
								true ->
									Distance1 = math:pow((get_px(x,Status#player.x)-get_px(x,X)), 2)+math:pow((get_px(y,Status#player.y)-get_px(y,Y)), 2),
                            		Distance2 = math:pow(Distance*60,2),
                                    if
										Distance1 > Distance2 ->
                                            [6,Status];%%距离太远,不能使用轻功
										true ->
											case lib_arena:is_arena_ready_time(Status#player.scene) of
												true ->
                                                    [14, Status];%%战场开始之前，不能使用轻功
                                                false ->
                                                    put(light_skill,CurrentTime),
                                                    NewStatus = Status#player{
                                                        mp = Status#player.mp - Mp,
                                                        x = X,
                                                        y = Y
                                                    },
                                                    lib_player:send_player_attribute2(NewStatus, 4),
													case NewStatus#player.scene =:= 300 of
														true ->
															erlang:send_after(2000, self(), {'PEACH_SCENE_CHANGE'});
														false ->
															skip
													end,
                                                    [1, NewStatus]%%成功使用轻功
                                            end	
									end
							end
					end
			end
	end.


%%计算x,y相素
get_px(Type,Vlaue) ->
	if 
		Type == x ->
			Vlaue*60+30;
		Type == y ->
			Vlaue*30+15
	end.
