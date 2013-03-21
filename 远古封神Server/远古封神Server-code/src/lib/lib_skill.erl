%%%-----------------------------------
%%% @Module  : lib_skill
%%% @Author  : ygzj
%%% @Created : 2010.10.06
%%% @Description: 技能
%%%-----------------------------------
-module(lib_skill).
-include("common.hrl").
-include("record.hrl").
-export(
    [
	 	init_base_skill/0,	 
        get_all_skill/1,
        upgrade_skill/3,
		upgrade_passive_skill/3,
		check_skill/2,
		energy_skill/3,
		updata_light_skill/1,
		get_light_skill/1,
		get_passive_skill/1,
		count_passive_att/3,
		use_couple_skill/1,
		init_couple_skill/1
    ]
).

%% 初始化基础技能
init_base_skill() ->
    F = fun(Skill) ->
		SkillInfo = list_to_tuple([ets_skill | Skill]),
  		ets:insert(?ETS_BASE_SKILL, SkillInfo)
    end,
	L = db_agent:get_base_skill(),
	lists:foreach(F, L),
    ok.

%% 获取所有普通技能（主动）
%% PlayerId 玩家ID
get_all_skill(PlayerId) ->
    case db_agent:get_all_skill(PlayerId, 1) of
   		[] ->
       		[];
   		Data ->
       		[list_to_tuple(D) || D <- Data]
    end.

%% 获取轻功技能
%% PlayerId 玩家ID
get_light_skill(PlayerId) ->
    Data = db_agent:get_all_skill(PlayerId,2),
    case Data of
        [] ->
            [];
        _ ->
            [list_to_tuple(D) || D <- Data]
    end.

%% 获取被动技能
%% PlayerId 玩家ID
get_passive_skill(PlayerId) ->
    Data = db_agent:get_all_skill(PlayerId,3),
    case Data of
        [] ->
            [];
        _ ->
            [list_to_tuple(D) || D <- Data]
    end.

%%主被动技能公用函数
%% 技能书使用的前置检查 
check_skill(Player, SkillId) ->
	case lists:member(SkillId, data_skill:get_skill_id_list(Player#player.career)) of
		true ->
            case lists:keyfind(SkillId, 1, Player#player.other#player_other.skill) of
                false ->
                    SkillData = data_skill:get(SkillId, 1), 
                    case SkillData#ets_skill.data of
                        [] ->
                            %%技能已经学习
                            {fail,2};
                        _ ->
                            [{condition, Condition} | _] = SkillData#ets_skill.data,
                            case check_skill_upgrade_condition(Condition, Player, 1, [0,0,0]) of
                                {true,_, _Coin,_,_} ->
                                    {ok};%%可以使用
                                {false, _Msg} ->
                                    {fail,3}%%学习条件不满足
                            end
                    end;
                {_,_Lv} ->					
                    {fail,2} %%技能已经学习
            end;
		%%检查是否是被动技能
		false ->
			%%?DEBUG("___________skillId = ~p______________",[SkillId]),
			%%只有ID为25512~25515的被动技能需要使用技能书进行学习
			case lists:member(SkillId, data_passive_skill:get_book_skill_list()) of
				true ->
					case lists:keyfind(SkillId, 1, Player#player.other#player_other.passive_skill) of
						false ->
							SkillData = data_passive_skill:get(SkillId, 1), 
							case SkillData#ets_skill.data of
								[] ->
									%%技能已经学习
									{fail,2};
								_ ->
									[{condition, Condition} | _] = SkillData#ets_skill.data,
									case check_skill_upgrade_condition(Condition, Player, 3, [0,0,0]) of
										{true,_, _Coin,_,_} ->
											{ok};%%可以使用
										{false, _Msg} ->
											{fail,3}%%学习条件不满足
									end
							end;
						{_,_Lv} ->	
							{fail,2} %%技能已经学习
					end;
				false ->
					%%技能不存在
					%%?DEBUG("_____FALSE, list = ~p_________",[data_passive_skill:get_skill_id_list()]),
					{fail,4}
			end
	end.
						 
				
%% 升级学习主动技能
%% Player 玩家信息状态
%% SkillId 技能ID
%% IsCost 1已经减了技能书，0没减技能书
upgrade_skill(Player, SkillId, IsCost) ->
    [Sign, Message, NewPlayer, RetSkillId] = 
        case lists:member(SkillId, data_skill:get_skill_id_list(Player#player.career)) of
            true ->
                SkillList = Player#player.other#player_other.skill,
                [NewLv, Type] = 
                    case lists:keyfind(SkillId, 1, SkillList) of
                        %% 学习技能
                        false -> 
                            [1, 0];
                        %% 升级技能
                        {_, Lv} ->                             
                            [Lv + 1, 1]
                    end,
				SkillData = data_skill:get(SkillId, NewLv),
                case SkillData#ets_skill.data of
                    [] ->
                        [0, <<"当前已经是最高等级了">>, Player, 0];
                    _ ->
                        case Type == 0 andalso IsCost == 0 andalso lib_goods:goods_find(Player#player.id, SkillId) == false of
                            true ->
                                [0, <<"技能书不存在">>, Player, 0];
                            false ->
                                [{condition, Condition} | _] = SkillData#ets_skill.data,
                                case check_skill_upgrade_condition(Condition, Player, 1, [0,0,0]) of
                                    {true,NewPlayer_vip, Coin, _CoinSave, Culture} ->
                                        case Type of
                                            %% 学习技能
                                            0 ->
                                                db_agent:study_skill(Player#player.id, SkillId, NewLv, 1),
												%% 扣技能书
												case IsCost of
													0 ->
														gen_server:call(Player#player.other#player_other.pid_goods, {'delete_more', SkillId, 1});
													_ ->
														skip
												end;
												
                                            %% 升级技能
                                            _ ->
                                                db_agent:upgrade_skill(Player#player.id, SkillId, NewLv),
                                                %% 任务升级技能
                                                ok           
                                        end,
										%%主动技能学习或升级都消耗修为
										%%?DEBUG("_____C1 = ~p_____", [NewPlayer_vip#player.culture]),
										Player0 = lib_player:reduce_culture(NewPlayer_vip,Culture),
										%%?DEBUG("_____C2 = ~p_____", [Player0#player.culture]),
										%%?DEBUG("Coin = ~p, Culture = ~p",[Coin, Culture]),
										Player1 = lib_goods:cost_money(Player0, Coin, coin, 2101),
                                        NewSkillList = lists:keydelete(SkillId, 1, SkillList),
                                        RetPlayer = Player1#player{                                           
                                            other = Player1#player.other#player_other{
                                                skill = [{SkillId, NewLv} | NewSkillList]
                                            }
                                        },                     
										case Type of
											0->%% 任务学习技能
                                                lib_task:event(learn_skill, {SkillId}, RetPlayer);
											_->skip
										 end,
										%%成就系统统计接口
										erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(Player#player.id, 423, [1]))end),
                                        [1, <<>>, RetPlayer, SkillId];
                                    
                                    {false, Msg} ->
                                        [0, Msg, Player, 0]
                                end
                        end
                end;
            false ->
                [0, <<"当前技能不存在！">>, Player, 0]
        end,
	if Sign =:= 1 ->
		   NewPlayer2 = lib_player:count_player_attribute(NewPlayer),
		   lib_player:send_player_attribute(NewPlayer2, 2);
	   true ->
		   NewPlayer2 = NewPlayer
	end,
    {ok, BinData} = pt_21:write(21001, [Sign, Message, RetSkillId]),
    lib_send:send_to_sid(NewPlayer2#player.other#player_other.pid_send, BinData),
    {ok, NewPlayer2}.

%%升级被动技能
%% 升级学习技能
%% Player 玩家信息状态
%% SkillId 技能ID
%% IsCost 1已经减了技能书，0没减技能书
upgrade_passive_skill(Player, SkillId, IsCost) ->
    [Sign, Message, NewPlayer, RetSkillId] = 
        case lists:member(SkillId, data_passive_skill:get_skill_id_list()) of
            true ->
                SkillList = Player#player.other#player_other.passive_skill,
                [NewLv, Type] = 
                    case lists:keyfind(SkillId, 1, SkillList) of
                        %% 学习技能
                        false -> 
                            [1, 0];
                        %% 升级技能
                        {_, Lv} ->                             
                            [Lv + 1, 1]
                    end,
				SkillData = data_passive_skill:get(SkillId, NewLv),
                case SkillData#ets_skill.data of
                    [] ->
                        [0, <<"当前已经是最高等级了">>, Player, 0];
                    _ ->
                        case Type == 0 andalso IsCost == 0 andalso lib_goods:goods_find(Player#player.id, SkillId) == false of
                            true ->
                                [0, <<"技能书不存在">>, Player, 0];
                            false ->
                                [{condition, Condition} | _] = SkillData#ets_skill.data,
                                case check_skill_upgrade_condition(Condition, Player, 3, [0,0,0]) of
                                    {true,NewPlayer_vip, Coin, _CoinSave, Culture} ->
                                        case Type of
                                            %% 学习技能
                                            0 ->
												%%更新数据库
												%%被动技能类型为 3
                                                db_agent:study_skill(Player#player.id, SkillId, NewLv, 3),
												%% 扣技能书
												case IsCost of
													0 ->
														%%?DEBUG("_______skip , cost, sid=~p__________",[SkillId]),
														gen_server:call(Player#player.other#player_other.pid_goods, {'delete_more', SkillId, 1});												
													_ ->
														%%ID为25500~25511的被动技能不需要技能书，走这个分支，IsCost已在pp_skill被设置为1
														%%?DEBUG("_______skip ,don't cost, sid=~p__________",[SkillId]),
														skip
												end;
												
                                            %% 升级技能
                                            _ ->
												%%更新数据库
                                                db_agent:upgrade_skill(Player#player.id, SkillId, NewLv),
                                                ok           
                                        end,  
										%%消耗修为
										%%?DEBUG("Coin = ~p, Culture = ~p",[Coin, Culture]),
										Player0 = lib_player:reduce_culture(NewPlayer_vip,Culture),
										Player1 = lib_goods:cost_money(Player0, Coin, coin, 2104),
										%%更新内存
                                        NewSkillList = lists:keydelete(SkillId, 1, SkillList),
                                        RetPlayer = Player1#player{                                           
                                            other = Player1#player.other#player_other{
                                                passive_skill = [{SkillId, NewLv} | NewSkillList]
                                            }
                                        },                     
										case Type of
											0->%% 任务学习被动技能
                                                lib_task:event(passive_skill, null, RetPlayer);
											_->skip
										 end,
										%%成就系统统计接口
										erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(Player#player.id, 423, [1]))end),
                                        [1, <<>>, RetPlayer, SkillId];
                                    
                                    {false, Msg} ->
                                        [0, Msg, Player, 0]
                                end
                        end
                end;
            false ->
                [0, <<"当前技能不存在！">>, Player, 0]
        end,
	if Sign =:= 1 ->
		   NewPlayer2 = lib_player:count_player_attribute(NewPlayer),
		   lib_player:send_player_attribute(NewPlayer2, 2);
	   true ->
		   NewPlayer2 = NewPlayer
	end,
    {ok, BinData} = pt_21:write(21004, [Sign, Message, RetSkillId]),
    lib_send:send_to_sid(NewPlayer2#player.other#player_other.pid_send, BinData),
    {ok, NewPlayer2}.

%%vip省钱提示
%% vip_msg(PlayerStatus,Coin,Save)->
%%  Msg  = io_lib:format("你本次学习/升级技能消费~p铜钱,由于您是VIP会员，本次节省~p铜钱",[Coin,Save]),
%% 	{ok,MyBin} = pt_15:write(15055,[Msg]),
%% 	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin).

%%主被动技能公用函数
%% 检查升级需求
%%Type: 1，主动技能； 2，被动技能
check_skill_upgrade_condition([], Player, _Type, [Coin,CoinSave,Culture]) ->
    {true,Player, Coin, CoinSave, Culture};
check_skill_upgrade_condition([{K, V} | T], Player, Type, [Coin,CoinSave,Culture]) ->
    case K of
        %% 等级需求
        lv -> 
            case Player#player.lv < V of
                true ->
					Msg = io_lib:format("等级不足~p级",[V]),
                    {false, list_to_binary(Msg)};
                    %{true, 1};
                false ->
                    check_skill_upgrade_condition(T, Player, Type, [Coin,CoinSave,Culture])
            end;
		
        %% 铜币需求
        coin -> 
			
			if Type =:= 1 ->
				   {NewPlayer,ok,Award}=lib_vip:get_vip_award(up_skill,Player),
				   CoinNeed = round((1-Award)*V);
			   true ->
				   %%被动技能升级没有VIP优惠
				   NewPlayer = Player,
				   CoinNeed = V
			end,
			case goods_util:is_enough_money(NewPlayer, CoinNeed, coin) of
                false ->
					Msg = io_lib:format("铜币不足~p",[CoinNeed]),
                    {false, list_to_binary(Msg)};
                true ->
                    check_skill_upgrade_condition(T, NewPlayer, Type, [CoinNeed,V-CoinNeed,Culture])
            end;
		
        %% 修为需求
        culture ->
			%%主被动技能都需要消耗修为
			case Player#player.culture < V of
				true ->
					Msg = io_lib:format("修为不足~p",[V]),
					{false, list_to_binary(Msg)};
				false ->
					check_skill_upgrade_condition(T, Player, Type, [Coin,CoinSave,V])
			end;
        _ ->
            check_skill_upgrade_condition(T, Player, Type, [Coin,CoinSave,Culture])
    end.

energy_skill(Player, X, Y) ->
	BattleStatus = Player#player.other#player_other.battle_status,
    EnergyPlayer = 
        if
            %% 攻击圈
            X == 16 andalso Y == 22 ->
                Buff =
                    case lists:keyfind(last_zone_def, 1, BattleStatus) of
                        false ->
                            BattleStatus;
                        _ ->
                            lists:keydelete(last_zone_def, 1, BattleStatus)
                    end,
                NewBuff = 
                    case lists:keyfind(last_zone_att, 1, Buff) of
                        false ->
                            Now = util:unixtime(),
                            Info = {last_zone_att, 2000, Now + 3600, 10067, 1},
                            [Info | Buff];
                        _ ->
                            Buff
                    end,
                Player#player{
                    other = Player#player.other#player_other{
                        battle_status = NewBuff									  
                    }						
                };

            %% 防御圈
            X == 18 andalso Y == 20 ->
                Buff =
                    case lists:keyfind(last_zone_att, 1, BattleStatus) of
                        false ->
                            BattleStatus;
                        _ ->
                            lists:keydelete(last_zone_att, 1, BattleStatus)
                    end,
                NewBuff = 
                    case lists:keyfind(last_zone_def, 1, Buff) of
                        false ->
                            Now = util:unixtime(),
                            Info = {last_zone_def, 5000, Now + 3600, 10068, 1},
                            [Info | Buff];
                        _ ->
                            Buff
                    end,
                Player#player{
                    other = Player#player.other#player_other{
                        battle_status = NewBuff									  
                    } 						
                };

            true ->
                Buff =
                    case lists:keyfind(last_zone_att, 1, BattleStatus) of
                        false ->
                            BattleStatus;
                        _ ->
                            lists:keydelete(last_zone_att, 1, BattleStatus)
                    end,
                NewBuff = 
                    case lists:keyfind(last_zone_def, 1, Buff) of
                        false ->
                            Buff;
                        _ ->
                            lists:keydelete(last_zone_def, 1, Buff)
                    end,
                Player#player{
                    other = Player#player.other#player_other{
                        battle_status = NewBuff									  
                    } 						
                }
        end,
    case EnergyPlayer#player.other#player_other.battle_status /= BattleStatus of
        true ->
			NowTime = util:unixtime(),
			EnergyBuff = lists:ukeysort(4, [{K, V, T, S, L} || {K, V, T, S, L} <- EnergyPlayer#player.other#player_other.battle_status, T > NowTime]),
			{ok, BinData} = pt_13:write(13013, [EnergyBuff, NowTime]),
    		lib_send:send_to_sid(EnergyPlayer#player.other#player_other.pid_send, BinData),
			mod_scene:update_player_info_fields(EnergyPlayer, [{battle_status, EnergyBuff}]);
        false ->
            skip
    end,
    EnergyPlayer.

%%获取玩家所学的被动技能加成数值
count_passive_att([],_PlayerSkills,AttList) ->
	lists:reverse(AttList);
count_passive_att([Sid|SkillIds],PlayerSkills,AttList) ->
	case lists:keyfind(Sid,1,PlayerSkills) of
		false ->
			count_passive_att(SkillIds,PlayerSkills,[0|AttList]);
		{SkillId,Level} ->
			Value = get_pskill_effect_value(SkillId,Level),
			count_passive_att(SkillIds,PlayerSkills,[Value|AttList])
	end.
			
%%获取被动技能加成属性
get_pskill_effect_value(SkillId,Slv) ->
	PSkill = data_passive_skill:get(SkillId, Slv),
	case PSkill of
		[] -> 0;
		Rskill ->
			case lists:keyfind(effect,1,Rskill#ets_skill.data) of
				false -> 0;
				{effect,[{_Effect,Value}]} -> Value 
			end
	end.
			
%%检查玩家轻功技能，如达到条件自动学习
updata_light_skill(Player) ->
	SkillList = Player#player.other#player_other.light_skill,
	Lv =  Player#player.lv,
	[NewSkillLv, _Type] = 
		case lists:keyfind(50000, 1, SkillList) of
			false -> 
				[1, 0];
			%% 升级技能
			{_, Skill_Lv} ->   
				[Skill_Lv + 1, 1]
		end,
	%%轻功技能可升等级
	CanUpdataLv = data_agent:get_light_update_lv(Lv),
	if
		%%可升轻功等级大于0,技能等级小于6
		CanUpdataLv > 0 andalso NewSkillLv =< 5 andalso NewSkillLv =< CanUpdataLv ->
 			NewPlayer = updata_light_skill_loop(lists:seq(NewSkillLv, CanUpdataLv),Player),
			NewPlayer;
		true -> 
			Player
	end.

%%循环检查角色轻功升级条件
updata_light_skill_loop([],Player) ->
	Player;
updata_light_skill_loop([NewSkillLv | RestList],Player) ->
	[_Lv,_Skill_Lv,_Culture,Coin,_Skill_Book,_Cd,_Mp,_Distance] = data_agent:get_light_skill(50000,NewSkillLv),
	if 
		%%修为或铜币不够
		Player#player.coin +  Player#player.bcoin < Coin ->
			Player;
		true ->
			case NewSkillLv of
				1 ->
					%%插入记录
					db_agent:study_skill(Player#player.id, 50000, NewSkillLv,2);
				_ ->
					%%更新记录
					db_agent:upgrade_skill(Player#player.id, 50000, NewSkillLv)
			end,
			SkillList = Player#player.other#player_other.light_skill,
			NewSkillList = lists:keydelete(50000, 1, SkillList),
			Player2 = Player#player{other = Player#player.other#player_other{
                                     light_skill = [{50000, NewSkillLv} | NewSkillList]
                                     }
                        }, 
			%%将轻功等级信息推送到客户端
			pp_skill:handle(21003,Player2,[]),
			lib_player:send_player_attribute(Player2, 4),
			updata_light_skill_loop(RestList,Player2)
	end.

%%初始化夫妻传送技能CD
init_couple_skill(Status)->
	case db_agent:init_couple_skill(Status#player.id) of
		[]->Status;
		[undefined]->Status;
		[CD]->
			Status#player{other = Status#player.other#player_other{couple_skill = CD}}
	end.

%%夫妻传送技能(1传送成功，2您还没有结婚，不能使用该技能，3该技能还在冷却中，不能使用，4您的配偶不在线，不能使用)
use_couple_skill(Status)->
	case Status#player.couple_name of
		[] -> [2,0];
		<<>> -> [2,0];
		_->
			NowTime = util:unixtime(),
			CD = get_couple_skill_cd(Status#player.other#player_other.couple_skill,NowTime),
			if CD > 0 ->[3,CD];
			   true->
				   case lib_player:get_role_id_by_name(Status#player.couple_name) of 
					   null->[4,CD];
					   []->[4,CD];
					   CoupleId->
						   case lib_player:get_online_info(CoupleId) of
							   []->[4,CD];
							   Couple->
								   {SceneId,X,Y} = {Couple#player.scene,Couple#player.x,Couple#player.y},
								   case lib_deliver:could_deliver(Status) of
									   ok->
										   case lib_deliver:check_scene_enter(SceneId) of
											   true->
												   if SceneId =:= 215 orelse SceneId =:= 216 -> [43,CD];
													  true->
														  NewStatus=lib_deliver:deliver(Status,SceneId,X,Y,3),
														  NewCd = NowTime+600,
														  NewStatus1= NewStatus#player{other = Status#player.other#player_other{couple_skill = NewCd}},
														  spawn(fun()->db_agent:update_couple_skill(Status#player.id,NewCd)end),
														  [ok,600,NewStatus1]
												   end;
											   false->[5,CD]
										   end;
									   Err->[Err,CD]
								   end
						   end
				   end
			end
	end.

get_couple_skill_cd(Cd,NowTime)->
	if Cd > NowTime -> Cd-NowTime;
	   true->0
	end.
