%%%--------------------------------------
%%% @Module  : pp_battle
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 战斗
%%%--------------------------------------
-module(pp_battle).
-export(
	[
		handle/4
	]
).
-include("common.hrl").
-include("record.hrl").
-include("guild_info.hrl").

%% 战斗字典
-record(private_battle_dict, {
  	last_attack_time = 0          						%% 上次出手时间
}).

%% 发动攻击 - 玩家VS怪 
%% MonId 怪物ID
%% SkillId 技能ID
handle(20001, Player, [MonId, SkillId], _PlayerState) ->
	if
  		Player#player.hp > 0 ->
            %% 判断有没有没被昏迷、沉默
            case lib_battle:check_battle_limit(Player, SkillId) of
                {ok, NewSkillId} ->
                    %% 私有战斗字典信息
                    PrivateBattleDict = get_private_battle_dict(),
                    Now = util:longunixtime(),
                    %% 限制出手频率和等级限制
					if
                  		Now - PrivateBattleDict#private_battle_dict.last_attack_time + 200 >= Player#player.att_speed ->
                            NewPrivateBattleDict = PrivateBattleDict#private_battle_dict{
                                last_attack_time = Now				 
                            },
                            put(private_battle_dict, NewPrivateBattleDict),
							%% 是否在雷泽
							case lists:member(Player#player.scene, [100,101, 190, 191,102,200,201,250,251,280,281]) of
								false ->
									battle_mon(Player, MonId, NewSkillId);
								true ->
									case lists:keyfind(NewSkillId, 1, Player#player.other#player_other.skill) of
    									false ->
											mod_battle:battle_mon(Player, MonId, 0, 0);
    									{RetSkillId, Lv} ->
                                            case data_skill:get(RetSkillId, Lv) of
                                                [] ->
                                                    mod_battle:battle_mon(Player, MonId, 0, 0);
                                                SkillData ->
                                                    if
                                                        %% 单攻
                                                        SkillData#ets_skill.mod =:= 1 ->
                                                            mod_battle:battle_mon(Player, MonId, RetSkillId, Lv);
                                                        true ->
                                                            battle_mon(Player, MonId, NewSkillId)
                                                    end
                                            end
									end
									
							end;
                        true ->
                            lib_battle:battle_fail(20, Player, 2)
                    end;
                {fail, Code} ->
                    lib_battle:battle_fail(Code, Player, 2)
            end;
		true ->
			skip
    end;

%% 发动攻击 - 玩家VS玩家
%% DerId 被击方ID
%% AerSkillId 攻击方技能ID
handle(20002, Aer, [DerId, SkillId], _PlayerState) ->
  	case Aer#player.hp > 0 andalso Aer#player.id =/= DerId andalso Aer#player.status =/= 10 of
        true ->
			%% 判断有没有没被昏迷、沉默
    		case lib_battle:check_battle_limit(Aer, SkillId) of
   				{ok, NewSkillId} ->
					%% 私有战斗字典信息
					PrivateBattleDict = get_private_battle_dict(),
    				Time = util:longunixtime(),
    				%% 限制出手频率和等级限制
    				DistTime = Time - PrivateBattleDict#private_battle_dict.last_attack_time + 200,
    				case DistTime >= Aer#player.att_speed of
        				true ->
							NewPrivateBattleDict = PrivateBattleDict#private_battle_dict{
                				last_attack_time = Time				 
            				},
							put(private_battle_dict, NewPrivateBattleDict),
							ScenePid = mod_scene:get_scene_pid(Aer#player.scene, 
								Aer#player.other#player_other.pid_scene, Aer#player.other#player_other.pid),
							if
								Aer#player.mount > 0 ->
									{ok, NewPlayer, ChangeList} = lib_goods:force_off_mount_for_battle(Aer),
									gen_server:cast(ScenePid,
										{apply_asyn_cast, lib_battle, battle_player, [Aer#player.id, DerId, NewSkillId, Aer#player.scene, ChangeList]}),
									{ok, change_status, NewPlayer};
								true ->
									%% 攻击者是否在打坐
									if
										Aer#player.status =/= 6 ->
											gen_server:cast(ScenePid,
												{apply_asyn_cast, lib_battle, battle_player, [Aer#player.id, DerId, NewSkillId, Aer#player.scene]});
										true ->
											{ok, NewPlayer} = lib_player:cancelSitStatus(Aer),
											ChangeList = [
												{status, NewPlayer#player.status},
												{peach_revel, NewPlayer#player.other#player_other.peach_revel}		
											],
											gen_server:cast(ScenePid,
												{apply_asyn_cast, lib_battle, battle_player, [Aer#player.id, DerId, NewSkillId, Aer#player.scene, ChangeList]}),
											{ok, change_status, NewPlayer}
									end
							end;
						false ->
            				lib_battle:battle_fail(20, Aer, 2)
    				end;
				{fail, Code} ->
            		lib_battle:battle_fail(Code, Aer, 2)
    		end;
		false ->
			skip
	end;

%% 复活
%% ReviveType 复活方式
handle(20004, Player, ReviveType, PlayerState) ->
	SceneId = Player#player.scene rem 10000,
	if
		SceneId =:= ?WARFARE_SCENE_ID andalso ReviveType =/= 10 andalso ReviveType =/= 3 ->
			no_revive;
		(SceneId =:= 998 orelse SceneId =:= 999) andalso ReviveType =/= 6 ->
			no_revive;
		true ->
			NewReviveType = 
				case lib_war:is_fight_scene(Player#player.scene) of
					true ->
						DieTime = util:unixtime() - Player#player.other#player_other.die_time,
						case DieTime >= 5 of
							false -> 
								8;
							true ->
								7
						end;
					false ->
						ReviveType
				end,
            case lib_battle:check_valid_revive(Player, NewReviveType) of
                1 ->
                    [NewPlayer, RetPlayerState] = lib_battle:player_revive(Player, NewReviveType, battle, PlayerState),
                    %% 玩家卸下坐骑
                    {ok, MountPlayer} = lib_goods:force_off_mount(NewPlayer),
                    NewPlayerState = RetPlayerState#player_state{
                        player = MountPlayer							 
                    },
                    {ok, change_diff_player_state, NewPlayerState};
                _ ->
                    {ok, BinData} = pt_20:write(20004, 1), 
                    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
            end
	end;

%% 发动辅助技能
%% Id 玩家ID
%% SkillId 玩家技能ID
handle(20006, Aer, [DerId, SkillId], _PlayerState) ->
  	%% 修炼,吃桃，双修不能使用辅助技能
  	case Aer#player.status /= 7 andalso Aer#player.status /= 10 andalso Aer#player.hp > 0 of
		true ->
			case Aer#player.arena == 3 andalso lib_arena:is_arena_scene(Aer#player.scene) of
				false ->
					case lib_spring:is_spring_scene(Aer#player.scene) of
						true ->%%温泉里，技能无效
							skip;
						false ->
							%% 判断有没有没被昏迷、沉默
						    case lib_battle:check_battle_limit(Aer, SkillId) of
						        {ok, NewSkillId} ->
									mod_battle:assist_skill(Aer, DerId, NewSkillId);
						        {fail, Code} ->
						            lib_battle:battle_fail(Code, Aer, 2)
						    end
					end;
				true ->
					skip
			end;
      	false ->
            skip
    end;

%% 采集
handle(20100, Status, [MonId], _PlayerState) ->
	case mod_scene:find_mon(MonId, Status#player.scene) of
        [] ->			
            {ok, BinData} = pt_20:write(20100, [0]),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
        Mon ->
			%%6为采集，7捕捉，32捕捉(特殊)
			case Mon#ets_mon.type =:= 6 orelse Mon#ets_mon.type =:= 7 orelse Mon#ets_mon.type =:= 32 of
				true->
            		case Status#player.hp > 0 of
                		true ->
							%% 从打坐状态恢复正常状态
							if Status#player.status == 6 ->	
									{ok,Status1} = lib_player:cancelSitStatus(Status);
							   %%从双修状态恢复正常状态 
							   Status#player.status == 10 ->	
									{ok,Status1} =  lib_double_rest:cancel_double_rest(Status);
								true ->
									Status1 = Status
							end,
							case Mon#ets_mon.type of
								%%灵兽采集
								32 ->
									Data = mod_pet:collect_pet(Status1, Mon),
									{ok, BinData} = pt_20:write(20100, [Data]),
									lib_send:send_to_sid(Status1#player.other#player_other.pid_send, BinData),
									case Data of
										10 -> %%采集成功删除掉落灵兽宝宝
											Mon#ets_mon.pid ! 'CLEAR_MON';
										_ ->
											skip
									end;
								_ ->
									case mod_collect:collect_call(Status1, Mon) of
										undefined ->
											{ok, BinData} = pt_20:write(20100, [0]),
											lib_send:send_to_sid(Status1#player.other#player_other.pid_send, BinData);
										NewStatus ->
											{ok, NewStatus}
									end
							end;
                		false ->
                   		 	{ok, BinData} = pt_20:write(20100, [0]),
            				lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
					end;
				false->
					{ok, BinData} = pt_20:write(20100, [0]),
            		lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
			end
    end;

%% 取消采集
handle(20102, Player, [MonId], _PlayerState)->
	mod_collect:cancel_collect(),
	{ok, BinData} = pt_20:write(20102, [MonId]),
    mod_scene_agent:send_to_area_scene(Player#player.scene,Player#player.x, Player#player.y, BinData);

handle(_Cmd, _Player, _Data, _PlayerState) ->
    {error, "pp_battle no match"}.

%% 私有战斗字典
get_private_battle_dict() ->
	case get(private_battle_dict) of
		undefined ->
			PrivateBattleDict = #private_battle_dict{},
			put(private_battle_dict, PrivateBattleDict),
			PrivateBattleDict;
		PrivateBattleDict ->
			PrivateBattleDict
	end.

%% 人VS怪
battle_mon(Player, MonId, SkillId) ->
	ScenePid = mod_scene:get_scene_pid(Player#player.scene, 
 				Player#player.other#player_other.pid_scene, Player#player.other#player_other.pid),
    if
        Player#player.mount > 0 ->
            {ok, NewPlayer, ChangeList} = lib_goods:force_off_mount_for_battle(Player),
            gen_server:cast(ScenePid,
                {apply_asyn_cast, lib_battle, battle_mon, [Player#player.id, MonId, SkillId, Player#player.scene, ChangeList]}),
            {ok, change_status, NewPlayer};
        true ->
            gen_server:cast(ScenePid,
                {apply_asyn_cast, lib_battle, battle_mon, [Player#player.id, MonId, SkillId, Player#player.scene]})
    end.
