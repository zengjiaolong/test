%%%------------------------------------
%%% @Module  : mod_battle
%%% @Author  : ygfs
%%% @Created : 2010.10.05
%%% @Description: 战斗
%%%------------------------------------

-module(mod_battle).
-export(
    [
        mon_battle/1,
		player_battle/4,
		battle_mon/4,
		attack/9,
		assist_skill/3,
		update_der_hp/5,
		add_hate/2
    ]
).
-include("common.hrl").
-include("record.hrl").
-include("battle.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("guild_info.hrl").

%% 怪物发起战斗(AerType、DerType: 1表示怪, 2表示人)
mon_battle([[Minfo, AerType], [DerInit, DerType], SkillId]) ->
	BattleDict = get_battle_dict(),
	[RetSkillData, RetSkillId, RetSlv, SkillMod] =
		case data_skill:get(SkillId, 1) of
			[] ->
				[[], 0, 1, 1];
			SkillData ->
				[SkillData, SkillId, 1, SkillData#ets_skill.mod]
		end,
	Now = util:unixtime(),
	Aer1 = init_data([Minfo, AerType], [DerInit, DerType], Now, 1),
    Der1 = init_data([DerInit, DerType], [Minfo, AerType], Now, 0), 
	%% 神岛空战里面的取旗判断
	{AerInit1, DerInit1} = 
		if
			Aer1#battle_state.scene =/= ?SKY_RUSH_SCENE_ID ->
				{Minfo, DerInit};
			true ->
				lib_skyrush:discard_flags_battle(1, [AerType, Minfo], [DerType, DerInit])
		end,
	%% 检查攻击方持续BUFF
    [Aer2, AerInit2] = check_aer_last_buff(Aer1#battle_state.battle_status, Aer1, AerInit1, [], Now),
	%% 计算技能效果
    {Aer3, Der2, BaseSkillHurt, AerInit3, LastimeSkillEffect} =
		check_skill_data(RetSkillData, AerInit2, DerInit1, Aer2, Der1, RetSkillId, RetSlv, Now),
	%% 先放这里处理
	put(cale_deputy_effect_attack,0),
	{Aer5, RetBattleDict, DerBattleResult, AerInit5} = 
        case SkillMod of    
            %% 单攻
            1 ->
				%% 检查被击方持续BUFF
			    Der3 = check_der_last_buff(Der2#battle_state.battle_status, Der2, [], Now),
			    %% 随机攻击值
			    AttMin = Aer3#battle_state.att_min,
			    AttMax = Aer3#battle_state.att_max,
				if
					AttMax > AttMin ->
						RandAtt = random:uniform(AttMax - AttMin) + AttMin;
					true ->
						RandAtt = 1 + AttMin
				end,
			    [Aer4, AerInit4, DerHp, DerMp, Hurt, Sta, BattleDict1] = 
					cale_hurt(Aer3, AerInit3, Der3, BaseSkillHurt, RandAtt, BattleDict, Now, RetSkillId, RetSlv, LastimeSkillEffect),
				update_der_hp(Der3, Aer4, DerHp, DerMp, Hurt),
				Result = [[Der3#battle_state.sign, Der3#battle_state.id, DerHp, DerMp, Hurt, 0, Sta]],
				{Aer4, BattleDict1, Result, AerInit4};
            %% 群攻
            _ ->
                {DoubleRetBattleDict, DoubleDerBattleResult, DoubleAerInit, _Blue} = 
					double_active_skill(Aer3, Der2, BattleDict, AerInit3, BaseSkillHurt, RetSkillData#ets_skill.area, RetSkillData#ets_skill.area_obj, Now, RetSkillId, RetSlv, 0, LastimeSkillEffect),
				{Aer3, DoubleRetBattleDict, DoubleDerBattleResult, DoubleAerInit}
        end,
	send_battle_msg(Aer5, RetSkillId, RetSlv, DerBattleResult, 20003),
	put(battle_dict, RetBattleDict),
    AerInit5#ets_mon{
        hp = Aer5#battle_state.hp,
        mp = Aer5#battle_state.mp
    }.	

get_battle_dict() ->
	case get(battle_dict) of
		undefined ->
			BattleDict = #battle_dict{},
			put(battle_dict, BattleDict),
			BattleDict;
		BattleDict ->
			BattleDict
	end.

%% 玩家战斗开始(AerType、DerType: 1表示怪, 2人)
player_battle([AerInit, AerType], [DerInit, DerType, DX, DY], SkillId, ObjType) ->
	Now = util:unixtime(),
	BattleDict = AerInit#player.other#player_other.battle_dict,
	{NewSkillId, Slv} =
        case lists:keyfind(SkillId, 1, AerInit#player.other#player_other.skill) of
            false ->
         		{0, 0};
          	RetSkillInfo ->
				RetSkillInfo
        end,
	case data_skill:get(NewSkillId, Slv) of
        [] ->
			case lib_battle:check_att_area(AerInit#player.x, AerInit#player.y, DX, DY, AerInit#player.att_area) of
				true ->
					attack([AerInit, AerType], [DerInit, DerType], [], BattleDict, 0, Slv, 1, 0, Now);
				_ ->
					if
						DerType == 2 andalso DerInit#player.status == 0 ->
							{ok, BinData} = pt_20:write(20010, [DerInit#player.id, DerType, DX, DY]),
							lib_send:send_to_sid(AerInit#player.other#player_other.pid_send, BinData),
							lib_battle:battle_fail(4, AerInit, 2);
						true ->
							skip
					end,
					undefined
			end;
        SkillData ->
            %% 判断施法条件
            case check_skill_cast_condition(SkillData, AerInit#player.mp_lim, AerInit#player.mp, AerInit#player.x, AerInit#player.y, DX, DY, AerInit#player.att_area, BattleDict, Now) of
                {mp_error, NewBattleDict} ->
					attack([AerInit, AerType], [DerInit, DerType], [], NewBattleDict, 0, Slv, 1, 0, Now);
				
                {att_area_error, _NewBattleDict} ->
					if
						DerType == 2 andalso DerInit#player.status == 0 ->
							{ok, BinData} = pt_20:write(20010, [DerInit#player.id, DerType, DX, DY]),
							lib_send:send_to_sid(AerInit#player.other#player_other.pid_send, BinData),
							lib_battle:battle_fail(4, AerInit, 2);
						true ->
							skip
					end,
					undefined;
                                    
                {cd_error, NewBattleDict} ->
					NewAerInit = AerInit#player{
                		other = AerInit#player.other#player_other{
                    		battle_dict = NewBattleDict  
                		}
            		},
					ets:insert(?ETS_ONLINE_SCENE, NewAerInit),
					undefined;

                {ok, NewBattleDict, LeftMpOut} ->
             		NewAerInit = AerInit#player{
               			mp = LeftMpOut
                	},
            		attack([NewAerInit, AerType], [DerInit, DerType], SkillData, NewBattleDict, NewSkillId, Slv, SkillData#ets_skill.mod, ObjType, Now)
        	end
    end.


%% 人VS怪
battle_mon(Player, MonId, SkillId, Slv) ->
	case mod_scene:find_mon(MonId, Player#player.scene) of
		[] ->
			skip;
		Mon ->
			if
				Mon#ets_mon.type =:= 3 andalso Player#player.pk_mode =:= 1 ->
					lib_battle:battle_fail(19, Player, 2);	
				true ->
		            MX = Mon#ets_mon.x, 
		            MY = Mon#ets_mon.y,
		            Now = util:unixtime(),
		            BattleDict = Player#player.other#player_other.battle_dict,
		            case data_skill:get(SkillId, Slv) of
		                [] ->
		                    case lib_battle:check_att_area(Player#player.x, Player#player.y, MX, MY, Player#player.att_area) of
		                        true ->
		                            attack_mon(Player, Mon, [], BattleDict, 0, Slv, Now);
		                        _ ->
		                            skip
		                    end;
		                SkillData ->
		                    %% 判断施法条件
		                    case check_skill_cast_condition(SkillData, Player#player.mp_lim, Player#player.mp, Player#player.x, Player#player.y, MX, MY, Player#player.att_area, BattleDict, Now) of
		                        {mp_error, NewBattleDict} ->
		                            attack_mon(Player, Mon, [], NewBattleDict, 0, Slv, Now);
		                        
		                        {att_area_error, _NewBattleDict} ->
		                            skip;
		                                            
		                        {cd_error, NewBattleDict} ->
		                            NewPlayer = Player#player{
		                                other = Player#player.other#player_other{
		                                    battle_dict = NewBattleDict  
		                                }
		                            },
		                            {ok, change_status, NewPlayer};
		
		                        {ok, NewBattleDict, LeftMpOut} ->
		                            NewPlayer = Player#player{
		                                mp = LeftMpOut
		                            },
		                            attack_mon(NewPlayer, Mon, SkillData, NewBattleDict, SkillId, Slv, Now)
		                    end
		            end
			end
	end.


%% 攻击
%% Aer 攻击方
%% Der 被击方
%% SkillData 技能数据
%% SkillId 技能ID
%% Slv 技能等级
%% AerInit 攻击方初始数据
%% DerInit 被击方初始数据
%% SkillMod 技能攻击模式
attack_mon(Player, DerInit, SkillData, BattleDict, SkillId, Slv, Now) ->
   	{ok, AerInit} = lib_goods:force_off_mount(Player),
	Aer = init_data([AerInit, 2], [DerInit, 1], Now, 1),
    Der = init_data([DerInit, 1], [AerInit, 2], Now, 0), 
	%% 检查攻击方持续BUFF
    [NewAer, NewAerInit] = check_aer_last_buff(Aer#battle_state.battle_status, Aer, AerInit, [], Now),
	%% 计算技能效果
    {Aer2, Der2, BaseSkillHurt, NewRetAerInit, LastimeSkillEffect} =
		check_skill_data(SkillData, NewAerInit, DerInit, NewAer, Der, SkillId, Slv, Now),
	%%先放这里处理
	put(cale_deputy_effect_attack, 0),
	{RetAer, RetBattleDict, DerBattleResult, RetAerInit} = 
		single_active_skill(Aer2, Der2, BattleDict, NewRetAerInit, DerInit, BaseSkillHurt, Now, SkillId, Slv, LastimeSkillEffect),
	
	%% 宠物战斗
	RetPetBattleDict = lib_pet_battle:pet_fight(RetAerInit, DerInit, RetAer, Der2, DerBattleResult, RetBattleDict, Now, 2),
	
    {ok, BinData} = pt_20:write(20001, [Aer#battle_state.id, Aer#battle_state.hp, Aer#battle_state.mp, SkillId, Slv, DerBattleResult]),
	mod_scene_agent:send_to_area_scene(Aer#battle_state.scene, Aer#battle_state.x, Aer#battle_state.y, BinData),
	
	NewPlayer = RetAerInit#player{
  		hp = RetAer#battle_state.hp,
    	mp = RetAer#battle_state.mp,
    	other = RetAerInit#player.other#player_other{
   			battle_dict = RetPetBattleDict  
   		}
	},
    BattleList = [
        {hp, NewPlayer#player.hp},
        {mp, NewPlayer#player.mp},
        {battle_status, NewPlayer#player.other#player_other.battle_status}
    ],
	mod_player:save_online_info_fields(NewPlayer, BattleList),
	{ok, change_status, NewPlayer}.

	
%% 攻击（人攻击）
%% Aer 攻击方
%% Der 被击方
%% SkillData 技能数据
%% SkillId 技能ID
%% Slv 技能等级
%% AerInit 攻击方初始数据
%% DerInit 被击方初始数据
%% SkillMod 技能攻击模式
attack([AerInit0, AerType], [DerInit0, DerType], SkillData, BattleDict, SkillId, Slv, SkillMod, ObjType, Now) ->
    Aer = init_data([AerInit0, AerType], [DerInit0, DerType], Now, 1),
    Der = init_data([DerInit0, DerType], [AerInit0, AerType], Now, 0), 
	%% 神岛空战里面的取旗判断
	{AerInit, DerInit} = 
		if
			Aer#battle_state.scene =/= ?SKY_RUSH_SCENE_ID ->
				{AerInit0, DerInit0};
			true ->
				lib_skyrush:discard_flags_battle(1, [AerType, AerInit0], [DerType, DerInit0])
		end,
	%% 检查攻击方持续BUFF
    [NewAer, NewAerInit] = check_aer_last_buff(Aer#battle_state.battle_status, Aer, AerInit, [], Now),
	%% 计算技能效果
    {Aer2, Der2, BaseSkillHurt, NewRetAerInit, LastimeSkillEffect} =
		check_skill_data(SkillData, NewAerInit, DerInit, NewAer, Der, SkillId, Slv, Now),
	%%先放这里处理
	put(cale_deputy_effect_attack,0),
	{RetAer, RetBattleDict, DerBattleResult, RetAerInit} = 
        case SkillMod of    
            %% 单攻
            1 ->
                single_active_skill(Aer2, Der2, BattleDict, NewRetAerInit, DerInit, BaseSkillHurt, Now, SkillId, Slv, LastimeSkillEffect);
            %% 群攻
            _ ->
                {DoubleRetBattleDict, DoubleDerBattleResult, DoubleAerInit, Blue} = 
					double_active_skill(Aer2, Der2, BattleDict, NewRetAerInit, BaseSkillHurt, SkillData#ets_skill.area, SkillData#ets_skill.area_obj, Now, SkillId, Slv, ObjType, LastimeSkillEffect),
				%% 有误伤人则进入蓝名状态
				if
					Blue =/= 1 ->
						skip;
					true ->
						enter_blue_status(DoubleAerInit)
				end,
				{Aer2, DoubleRetBattleDict, DoubleDerBattleResult, DoubleAerInit}
        end,
	%% 宠物战斗
	RetPetBattleDict = lib_pet_battle:pet_fight(RetAerInit, DerInit, RetAer, Der2, DerBattleResult, RetBattleDict, Now, 1),
	save(RetAer, RetAerInit, RetPetBattleDict, SkillId, Slv, DerBattleResult).


%% 群攻
%% Aer 攻击方
%% Der 被击方
%% SkillData 技能信息
%% State 战斗状态信息
%% SkillId 技能ID
%% Slv 技能等级
%% ObjType 0全部，1怪，2人
double_active_skill(Aer, Der, State, AerInit, BaseSkillHurt, AttArea, AreaObj, Now, SkillId, Slv, ObjType, LastimeSkillEffect) ->    
	AllObj = 
		case ObjType of
			%% 只取怪
			1 ->
				Blue = 0,
				lib_battle:get_mon_for_battle(Aer, Der, AttArea, AreaObj, []);
			%% 只取人
			2 ->
				[AllUser, Blue] = lib_battle:get_scene_user_battle(Aer, Der, AttArea, AreaObj, []),
				AllUser;
			_ ->
				[AllUser, Blue] = lib_battle:get_scene_user_battle(Aer, Der, AttArea, AreaObj, []),
				lib_battle:get_mon_for_battle(Aer, Der, AttArea, AreaObj, AllUser)
		end,
	AttDist = Aer#battle_state.att_max - Aer#battle_state.att_min,
    RandAttList = rand_att(length(AllObj), AttDist, Aer#battle_state.att_min, []),
    {NewAerInit, NewState, Result} = att_result(AllObj, RandAttList, Aer, AerInit, State, BaseSkillHurt, Now, SkillId, Slv, LastimeSkillEffect, []),
    {NewState, Result, NewAerInit, Blue}.

%% 获取群攻战斗结果
att_result([], _RandAttList, _Aer, AerInit, State, _BaseSkillHurt, _Now, _SkillId, _Slv, _LastimeSkillEffect, Result) ->
    {AerInit, State, Result};
att_result([Der | D], [RandAtt | R], Aer, AerInit, State, BaseSkillHurt, Now, SkillId, Slv, LastimeSkillEffect, Result) ->
    DerInit = init_data([Der, 0], [0, 0], Now, 1),
    %% 计算技能效果
    DerInit1 = check_der_last_buff(DerInit#battle_state.battle_status, DerInit, [], Now),
    [NewAer, NewAerInit, DerHp, DerMp, Hurt, Sta, NewState] = 
		cale_hurt(Aer, AerInit, DerInit1, BaseSkillHurt, RandAtt, State, Now, SkillId, Slv, LastimeSkillEffect),
	
	%% 战斗关系判断
	NewResult = battle_relation(NewAer, DerInit1, Hurt, DerHp, DerMp, Sta, Result),
	
	att_result(D, R, NewAer, NewAerInit, NewState, BaseSkillHurt, Now, SkillId, Slv, LastimeSkillEffect, NewResult).	

%% 获取群攻随机攻击值
rand_att(0, _AttDist, _AttMin, RandAttList) ->
    RandAttList;
rand_att(L, AttDist, AttMin, RandAttList) ->
	if
		AttDist > 0 ->
    		RandAtt = random:uniform(AttDist) + AttMin;
		true ->
			RandAtt = 1 + AttMin
	end,
    rand_att(L - 1, AttDist, AttMin, [RandAtt | RandAttList]).

%% 单体攻击
%% Aer 攻击方信息
%% Der 被击方信息
%% SkillData 技能信息
%% State 战斗信息
single_active_skill(Aer, Der, BattleDict, AerInit, DerInit, BaseSkillHurt, Now, SkillId, Slv, LastimeSkillEffect) ->    
    %% 检查被击方持续BUFF
    Der2 = check_der_last_buff(Der#battle_state.battle_status, Der, [], Now),
    %% 随机攻击值
    AttMin = Aer#battle_state.att_min,
    AttMax = Aer#battle_state.att_max,
	if
		AttMax > AttMin ->
    		RandAtt = random:uniform(AttMax - AttMin) + AttMin;
		true ->
			RandAtt = 1 + AttMin
	end,
	%%神器技能触发
	lib_deputy_skill:cale_deputy_effect_attack(Aer, Der2),
	%%神器技能抗性消减
	[NewAer,NewDer]= lib_deputy_skill:cale_deputy_effect_anti_hurt(Aer, Der2),
	%%神器技能减速
	lib_deputy_skill:cale_deputy_effect_speed(NewAer, NewDer, DerInit),
    [CaleHurtAer, NewAerInit, DerHp, DerMp, Hurt, Sta, NewBattleDict] = 
		cale_hurt(NewAer, AerInit, NewDer, BaseSkillHurt, RandAtt, BattleDict, Now, SkillId, Slv, LastimeSkillEffect),
	
	%% 战斗关系判断
	Result = battle_relation(CaleHurtAer, NewDer, Hurt, DerHp, DerMp, Sta, []),
	%% 是否进入蓝名
	check_blue_status(NewAerInit, DerInit, NewDer),
	%%神器技能吸血效果
	NewAer2 = lib_deputy_skill:cale_deputy_effect_hp_hurt(CaleHurtAer, NewDer),
	{NewAer2, NewBattleDict, Result, NewAerInit}.

%% 战斗关系
battle_relation(Aer, Der, Hurt, DerHp, DerMp, Sta, Result) ->
	case Der#battle_state.sign == 1 andalso Der#battle_state.relation /= [] of
        true ->
            case Der#battle_state.relation of
                %% 生命血量共享
				[3, ShareMonId, _] ->
					lib_battle:share_mon_hp(Aer, Der, ShareMonId, Hurt, DerHp, DerMp, Sta, Result);
				%% 伤害共享
				[9, ShareMonId] ->
					lib_battle:share_mon_hrut(Aer, Der, ShareMonId, Hurt, DerHp, DerMp, Sta, Result);
				%% 分身伤害平分
				[10, ShadowId] ->
					lib_battle:share_shadow_hrut(Aer, Der, ShadowId, Hurt, DerHp, DerMp, Sta, Result);
				_ ->
                    update_der_hp(Der, Aer, DerHp, DerMp, Hurt),
                    [[Der#battle_state.sign, Der#battle_state.id, DerHp, DerMp, Hurt, 0, Sta] | Result]
            end;
        false ->
            update_der_hp(Der, Aer, DerHp, DerMp, Hurt),
            [[Der#battle_state.sign, Der#battle_state.id, DerHp, DerMp, Hurt, 0, Sta] | Result]
    end.


%% 伤害计算
%% Aer 攻击方信息
%% Der 被击方信息
%% BaseSkillHurt 技能基础伤害值
cale_hurt(Aer, AerInit, Der, BaseSkillHurt, RandAtt, BattleDict, Now, SkillId, Slv, LastimeSkillEffect) ->
    %% 计算等级压制命中和暴击的加成值 
    [LvHit, LvCrit] = get_lv_advantage(Aer#battle_state.sign, Der#battle_state.sign, Aer#battle_state.lv, Der#battle_state.lv),        
    %% 实际命中率
	Hit = (Aer#battle_state.hit - Der#battle_state.dodge + LvHit) * 1000,
	case is_dodge(Der, BattleDict, Hit, Now) of
        %% 命中
        false ->                             
			%% 被击方的防御值或抗性值 人 打 人有抗性穿透
			%% DC - 免伤率
			{DCData, DerDef} = 
				if
					Aer#battle_state.sign == 2 andalso Der#battle_state.sign == 2 ->
						{60, Der#battle_state.def * (abs(100 - AerInit#player.anti_rift)/100)};
					true ->
						{100, Der#battle_state.def}
				end,
			DCParam = DerDef * (1 + Der#battle_state.lv / DCData),
			DC = DCParam / (DCParam + Aer#battle_state.lv * DCData + 100),				
			Dam = RandAtt * BaseSkillHurt * (1 - DC),
			%% 加上附加伤害
			HurtAdd = 
				case Aer#battle_state.hurt_add of
					1 ->
						1.0;
					_ ->
						Aer#battle_state.hurt_add
				end,
			TotalDam = value_cate(HurtAdd, Dam),
			
			%% 持续技能伤害
			last_skill_effect(Aer, Der, LastimeSkillEffect, SkillId, Slv, Now),
			
            %% 暴击率				
			Crit = Aer#battle_state.crit + LvCrit,
			{Hurt, Sta} =
				case random:uniform(1000) > Crit * 1000 of
                	%% 没暴击
                    true ->
                    	{util:ceil(TotalDam), 0};
                   	false ->
                    	{util:ceil(TotalDam * 1.5), 3}
                end,
			%% 计算攻击方对伤害有影响的BUFF
			Hurt1 = cale_after_aer_buff(Aer#battle_state.battle_status, Hurt, Aer, Der),
			%% 计算被击方对伤害有影响的BUFF
			{Hurt2, NewAer} = cale_after_der_buff(Der#battle_state.battle_status, Hurt1, Aer, Der, Now),
			%% 神器发动的额外伤害值，无视防御
			Hurt3 = Hurt2 + get(cale_deputy_effect_attack),
			%% 神器技能法力伤害
			RetDerMp = lib_deputy_skill:cale_deputy_effect_mp_hurt(Aer,Der),
		    [NewAerInit, RetDerHp, RetHurt] =
				if
		      		Hurt3 > 0 ->
						if
		              		Der#battle_state.hp > Hurt3 ->
		                        [AerInit, Der#battle_state.hp - Hurt3, Hurt3];
		                    %% 死亡
		                    true ->
		                        RetAerInit = cal_evil_honor(AerInit, Der, Aer#battle_state.sign, Now),
		                        [RetAerInit, 0, Hurt3]
		                end;
		            true ->
		                [AerInit, Der#battle_state.hp, 0]
		        end,
		    [NewAer, NewAerInit, RetDerHp, RetDerMp, RetHurt, Sta, BattleDict];
		%% 躲闪
        true ->
            DodgeBattleDict = BattleDict#battle_dict{
        		last_dodge_time = Now
            },
			[Aer, AerInit, Der#battle_state.hp, Der#battle_state.mp, 0, 1, DodgeBattleDict]
    end.

%% 增加罪恶荣誉值
cal_evil_honor(AerInit, Der, AerSign, Now) ->
	case Der#battle_state.sign == 2 andalso AerSign == 2 of
		true ->
			%%在自由竞技场,战场，跨服战场不增加罪恶值
			case 
					lists:member(AerInit#player.scene, [?FREE_PK_SCENE_ID, ?SKY_RUSH_SCENE_ID, ?CASTLE_RUSH_SCENE_ID]) 
					orelse lib_arena:is_arena_scene(AerInit#player.scene) 
					orelse lib_war:is_war_scene(AerInit#player.scene)
					orelse lib_coliseum:is_coliseum_scene(AerInit#player.scene)
			of 
				true ->
					AerInit;
				false ->
					Evil0 = 
						if
							%% 罪恶值大于90或不为蓝名状态，不加罪恶值
							Der#battle_state.evil < 90 andalso Der#battle_state.status /= 4 ->
								10;
							true ->
								0
						end,
					RealmHonorPlayerList = AerInit#player.other#player_other.realm_honor_player_list,
					[RealmHonor, RetRealmHonorPlayerList, Evil] =
						%% 神魔乱斗场景内击杀玩家罪恶值只增加在普通场景内的一半
						if
							AerInit#player.scene =:= ?WARFARE_SCENE_ID ->
								 [AerInit#player.realm_honor, RealmHonorPlayerList, trunc(Evil0 / 2)];
							true ->
								%% 同部落
								if
                            		AerInit#player.realm == Der#battle_state.realm ->
                                        RH = util:ceil(AerInit#player.realm_honor * 0.9),
                                        {ok, RealmHonorBinData} = pt_13:write(13018, [{2, RH}]),
                                        lib_send:send_to_sid(AerInit#player.other#player_other.pid_send, RealmHonorBinData),
                                        [RH, RealmHonorPlayerList, Evil0];
                                    true ->
                                        if
                                            %% 大于10级无荣誉
                                            AerInit#player.lv  - Der#battle_state.lv > 10 ->
                                                [AerInit#player.realm_honor, RealmHonorPlayerList, Evil0];
                                            true ->
                                                case lists:keyfind(Der#battle_state.id, 1, RealmHonorPlayerList) of
                                                    false ->
                                                        NewRealmHonorPlayerList = [{Der#battle_state.id, Now} | RealmHonorPlayerList],
                                                        [cal_realm_honor(AerInit, Der), NewRealmHonorPlayerList, Evil0];
                                                    {DerId, LastKillTime} ->
                                                        if
                                                            Now - LastKillTime > 1800 ->
                                                                NewRealmHonorPlayerList = lists:keyreplace(DerId, 1, RealmHonorPlayerList, {DerId, Now}),
                                                                [cal_realm_honor(AerInit, Der), NewRealmHonorPlayerList, Evil0];
                                                            true ->
                                                                [AerInit#player.realm_honor, RealmHonorPlayerList, Evil0]
                                                        end
                                                end
                                        end
                                end
						end,
					AerInit#player{
						evil = AerInit#player.evil + Evil,
						realm_honor = RealmHonor,
						other = AerInit#player.other#player_other{
       						realm_honor_player_list = RetRealmHonorPlayerList  
      					}
					}
			end;
		false ->
			AerInit
	end.

%% 部落荣誉计算
cal_realm_honor(AerInit, Der) ->
    if
        Der#battle_state.realm_honor > 0 ->
            Honor = util:ceil(Der#battle_state.realm_honor * 0.1),
            DerHonor = Der#battle_state.realm_honor - Honor,
            gen_server:cast(Der#battle_state.pid, {'UPDATE_REALM_HONOR', DerHonor}),
            AerRealmHonor = AerInit#player.realm_honor + Honor,
            {ok, RealmHonorBinData} = pt_13:write(13018, [{2, AerRealmHonor}]),
            lib_send:send_to_sid(AerInit#player.other#player_other.pid_send, RealmHonorBinData),
            AerRealmHonor;
        true ->
            AerInit#player.realm_honor	
    end.
	

%% 计算攻击方对伤害有影响的持续BUFF效果
%% K 效果类型
%% V 效果值
%% T 技能效果结束时间
%% S 技能ID
%% L 技能等级
%% Hurt 收到的伤害
%% Aer 攻击方信息
%% Der 被击方信息
cale_after_aer_buff([], Hurt, _Aer, _Der) ->
    Hurt;
cale_after_aer_buff([{K, V, _T, _S, _L} | H], Hurt, Aer, Der) ->
    case K of
        %% 自身伤害增加
        hurt_add ->
            NewHurt = value_cate(V, Hurt),
            cale_after_aer_buff(H, NewHurt, Aer, Der);
        _ ->
            cale_after_aer_buff(H, Hurt, Aer, Der)
    end.

%% 计算被击方对伤害有影响的持续BUFF效果
%% K 效果类型
%% V 效果值
%% T 技能效果结束时间
%% S 技能ID
%% L 技能等级
%% Hurt 收到的伤害
%% Aer 攻击方信息
%% Der 被击方信息
cale_after_der_buff([], Hurt, Aer, _Der, _Now) ->
  	{Hurt, Aer};
cale_after_der_buff([{K, V, T, S, L} | H], Hurt, Aer, Der, Now) ->
    {RetHurt, RetAer} = 
        case K of
            %% 施放目标所受伤害增加（负数则为减）
            lose_add ->
				LoseAddHurt = value_cate(V, Hurt),
                {LoseAddHurt, Aer};

            %% 反弹伤害
            bounce ->
				{Rate, Val} = V,
				NewAer =
	                case tool:odds(Rate, 100) of
	                    true ->
							%% 反弹伤害技能
							bounce_skill(Aer, Der, Hurt, Val);
	                    _ ->
							Aer
	                end,
                {Hurt, NewAer};
			
			%% 反弹伤害
            goods_skill_bounce ->
				{Rate, Val} = V,
				NewAer =
	                case tool:odds(Rate, 100) of
	                    true ->
							%% 反弹伤害技能
							bounce_skill(Aer, Der, Hurt, Val);
	                    _ ->
							Aer
	                end,
                {Hurt, NewAer};
			
            %% 吸收伤害
            shield ->
				ShieldHurt = 
	                case V > 0 of
	                    true ->
	                        DerPid = Der#battle_state.pid,
							%% 怪物攻击，伤害加大
							NewHurt = 
								case Aer#battle_state.sign of
									2 ->
										Hurt;
									_ ->
										Hurt * 2
								end,
	                        case NewHurt >= V of
	                            true ->
	                                Hurt1 = NewHurt - V,
									Hurt2 = 
										case Hurt1 > Hurt of
											true ->
												Hurt;
											false ->
												Hurt1
										end,
	                                LeftBuff = lists:keydelete(K, 1, Der#battle_state.battle_status),
	                                case Der#battle_state.sign of
	                                    %% 人
										2 ->
	                                 		DerPid ! {'SET_BATTLE_STATUS', {3, [LeftBuff]}};
	                                    %% 怪
										_ ->
	                                        DerPid ! {'SET_MON_BUFF', LeftBuff}
	                                end,
	                                Hurt2;
	                            false ->
	                                V1 = V - NewHurt,
	                                ReplaceBuff = lists:keyreplace(K, 1, Der#battle_state.battle_status, {K, V1, T, S, L}),
									case Der#battle_state.sign of
	                                    %% 人
										2 ->
											gen_server:cast(DerPid, {'SET_PLAYER', [{battle_status, ReplaceBuff}]});
	                                    %% 怪
										_ ->
	                                        DerPid ! {'SET_MON_BUFF', ReplaceBuff}
	                                end,
	                                0
	                        end; 
	                    false ->
	                        Hurt
	                end,
				{ShieldHurt, Aer};
			
			%% 物品技能 加攻击
            goods_last_att_add ->
                %% 根据概率算出此buff出现与否
                [_Val, _Ratio, CD, _Interval] = V,
				Der#battle_state.pid ! {'SET_BATTLE_STATUS',{5, [K, V, T, S, L, CD, Now]}},
                {Hurt, Aer};
			
            %% 物品技能  恢复法力
            goods_last_add_mp ->
                %% 根据概率算出此buff出现与否
                [Val, _Ratio, CD, Interval] = V,
                Time = trunc((T - Now) / Interval),
              	Der#battle_state.pid ! {'SET_BATTLE_STATUS',{6, [K, V, T, S, L, CD, Now, 0, Val, Time, Interval]}},
                {Hurt, Aer};
        
            %% 物品技能  恢复气血
            goods_last_add_hp ->
                %% 根据概率算出此buff出现与否
                [Val, _Ratio, CD, Interval] = V,
                Time = trunc((T - Now) / Interval),
              	Der#battle_state.pid ! {'SET_BATTLE_STATUS',{6, [K, V, T, S, L, CD, Now, 1, Val, Time, Interval]}},
                {Hurt, Aer};
			
			%% 物品技能 减免伤害
            goods_bounce_reduce ->
				%% 根据概率算出此buff出现与否
              	[Val, _Ratio, CD, _Interval] = V,
				Der#battle_state.pid ! {'SET_BATTLE_STATUS',{5, [lose_add, -Val, T, S, L, CD, Now]}},
                {value_cate(-Val, Hurt), Aer};
			
			 %% 物品技能 反弹伤害
            goods_bounce ->
				[Val, _Ratio, CD, _Interval] = V,
				Der#battle_state.pid ! {'SET_BATTLE_STATUS', {5, [goods_skill_bounce, {100, Val}, T, S, L, CD, Now]}},
				%% 反弹伤害技能
				NewAer = bounce_skill(Aer, Der, Hurt, Val),
                {Hurt, NewAer};
			
            _ ->
                {Hurt, Aer}
        end,
    cale_after_der_buff(H, RetHurt, RetAer, Der, Now).

%% 瞬间技能效果
%% Aer 攻击方信息
%% Der 防守方信息
cale_active_effect(SkillData, Aer, Der) ->
	case lists:keyfind(shortime, 1, SkillData) of
        false ->
            [Aer, Der];
        {shortime, Shortime} ->
			cale_active_effect_loop(Shortime, Aer, Der)					
    end.
cale_active_effect_loop([], Aer, Der) ->
    [Aer, Der];
cale_active_effect_loop([{K, V} | T], Aer, Der) ->
    case K of
        %% 加攻击
        att ->
			V1 = 
				case V of
					%% 1代表攻击加倍
					1 ->
						1.0;
					_ ->
						V
				end,
            AttMin = value_cate(V1, Aer#battle_state.att_min),
            AttMax = value_cate(V1, Aer#battle_state.att_max),
            NewAer = Aer#battle_state{
                att_min = AttMin,
                att_max = AttMax
            },
            cale_active_effect_loop(T, NewAer, Der);

        %% 双倍攻击
        double ->
            Rate =
                case V of
                    [D1, D2] ->
                        R = random:uniform(100),
                        case D1 > 0 andalso R =< D1 of
                            true ->
                                1.0;
                            false ->
                                case D2 > 0 andalso R > D1 andalso R =< D2 of
                                    true ->
                                        2.0;
                                    false ->
                                        0
                                end 
                        end;
                    _ ->
                        0
                end,
            NewAer =
                case Rate > 0 of
                    true ->
                        AttMin = value_cate(Rate, Aer#battle_state.att_min),
                        AttMax = value_cate(Rate, Aer#battle_state.att_max),
                        Aer#battle_state{
                            att_min = AttMin,
                            att_max = AttMax
                        };
                    _ ->
                        Aer
                end,
            cale_active_effect_loop(T, NewAer, Der);

        %% 加命中
        hit_add ->                    
            NewAer = Aer#battle_state{
                hit = V + Aer#battle_state.hit
            },
            cale_active_effect_loop(T, NewAer, Der);

        %% 加暴击
        crit ->                   
            NewAer = Aer#battle_state{
                crit = Aer#battle_state.crit + V 
            },
            cale_active_effect_loop(T, NewAer, Der);

        %% 加大攻击伤害
        hurt_add ->
            HurtAdd = value_cate(V, Aer#battle_state.hurt_add),
            NewAer = Aer#battle_state{
                hurt_add = HurtAdd
            },
            cale_active_effect_loop(T, NewAer, Der);

        %% 对对方防御
        def_del ->
            Def = value_cate(-V, Der#battle_state.def),
            NewDer = Der#battle_state{
                def = Def
            },
            cale_active_effect_loop(T, Aer, NewDer);

        %% 斩杀
        slash ->
            NewAer = 
                case V of
                    [HpRate, Hurt] ->
                        DHpRate = Der#battle_state.hp / Der#battle_state.hp_lim,
                        case DHpRate > HpRate of
                            true ->
                                Aer;
                            false ->
                                Aer#battle_state{
                                    hurt_add = Hurt
                                }
                        end;
                    _ ->
                        Aer
                end,
            cale_active_effect_loop(T, NewAer, Der);
		%% 风怒wind_anger
		wind_anger ->
			Der#battle_state.pid ! {'CHANGE_SCENE_WIND'},
			cale_active_effect_loop(T, Aer, Der);
		%% 火神之怒
		fire_anger ->
			%%结晶 47931
			CryList = lib_scene:get_scene_mon_td_by_mid(Aer#battle_state.scene, 47931),
			CryNum = length(CryList),
			NewAer = 
				case CryNum > 0 of
					true ->
						F_kill = fun([_Mid,Mpid]) ->
										 Mpid ! 'CLEAR_MON'
								 end,
						lists:foreach(F_kill, CryList),
						Att_min = Aer#battle_state.att_min,
						Att_max = Aer#battle_state.att_max,
						Aer#battle_state{
							att_min = round(CryNum * V) + Att_min,
							att_max = round(CryNum * V) + Att_max
						};
					false ->
						Aer
				end,
			 cale_active_effect_loop(T, NewAer, Der);					
        _ ->
            cale_active_effect_loop(T, Aer, Der)
    end.

%% 添加战斗短持续Buff
add_last_active_buff(AerInit, DerInit, SkillData, Aer, Der, SkillId, Slv, Now) ->
    case lists:keyfind(lastime, 1, SkillData) of
        false ->
			[AerInit, Aer, Der, []];
        {lastime, SkillEffect} ->
			add_last_active_buff_loop(SkillEffect, AerInit, DerInit, Aer, Der, SkillId, Slv, Now, SkillEffect)
    end.
add_last_active_buff_loop([], AerInit, _DerInit, Aer, Der, _Sid, _Slv, _Now, LastimeSkillEffect) ->
	[AerInit, Aer, Der, LastimeSkillEffect];
add_last_active_buff_loop([{LastTime, Key, Val} | SkillEffect], AerInit, DerInit, Aer, Der, SkillId, Slv, Now, LastimeSkillEffect) ->
    [RetAerInit, RetAer, RetDer] = 
        case LastTime > 0 of
            true ->
                case Key of
					%% 反击
					bounce ->
						Info = {Key, Val, Now + LastTime, SkillId, Slv},
						Buff = 
							case lists:keyfind(Key, 1, Aer#battle_state.battle_status) of
								false ->
									[Info | Aer#battle_state.battle_status];
								_ABuff -> 
									lists:keyreplace(Key, 1, Aer#battle_state.battle_status, Info)
							end,
						NewAerInit = 
                            case Aer#battle_state.sign of
                                %% 人
								2 ->
                                    lib_player:refresh_player_buff(AerInit#player.other#player_other.pid_send, Buff, Now),
									AerInit#player{
                                        other = AerInit#player.other#player_other{
                                            battle_status = Buff									  
                                        }						
                                    };
                                _ ->
                                    AerInit#ets_mon{
                                        battle_status = Buff				
                                    }
                            end,      
                        [NewAerInit, Aer, Der];
		
                    %% 加攻击
                    att ->
                        AttMin = value_cate(Val, Aer#battle_state.att_min),
                        AttMax = value_cate(Val, Aer#battle_state.att_max),
                        Buff = [{Key, Val, Now + LastTime, SkillId, Slv} | Aer#battle_state.battle_status],
                        NewAer = Aer#battle_state{
                            att_min = AttMin,
                            att_max = AttMax,
                            battle_status = Buff
                        },
                        NewAerInit = 
                            case Aer#battle_state.sign of
                                %% 人
								2 ->								
									lib_player:refresh_player_buff(AerInit#player.other#player_other.pid_send, Buff, Now),
                                    AerInit#player{
                                        other = AerInit#player.other#player_other{
                                            battle_status = Buff									  
                                        }						
                                    };
                                _ ->
                                    AerInit#ets_mon{
                                        battle_status = Buff				
                                    }
                            end,      
                        [NewAerInit, NewAer, Der];

                    %% 被击时伤害增加
                    lose_add ->
                        Buff = [{Key, Val, Now + LastTime, SkillId, Slv} | Der#battle_state.battle_status],
                        NewDer = Der#battle_state{
                            battle_status = Buff
                        },
                        DerPid = Der#battle_state.pid, 
                        case Der#battle_state.sign of
                            2 ->
								DerPid ! {'SET_BATTLE_STATUS', {4, [Buff]}};
                            _ ->
                                DerPid ! {'SET_MON_BUFF', Buff} 
                        end,
                        [AerInit, Aer, NewDer];

                    %% 自身伤害增加
                    lose_add_self ->
                        Buff = [{lose_add, Val, Now + LastTime, SkillId, Slv} | Aer#battle_state.battle_status],
                        NewAer = Aer#battle_state{
                            battle_status = Buff
                        },					
                        NewAerInit = 
                            case Aer#battle_state.sign of
                                2 ->
									lib_player:refresh_player_buff(AerInit#player.other#player_other.pid_send, Buff, Now),
                                    AerInit#player{
                                        other = AerInit#player.other#player_other{
                                            battle_status = Buff									  
                                        }						
                                    };
                                _ ->
									AerInit#ets_mon{
        								battle_status = Buff        
    								}
                            end,
                        [NewAerInit, NewAer, Der];

                    %% 暴击
                    last_crit ->                    
                        Buff = [{crit, Val, Now + LastTime, SkillId, Slv} | Aer#battle_state.battle_status],
                        NewAer = Aer#battle_state{
                            crit = Val + Aer#battle_state.crit,
                            battle_status = Buff
                        },
                        NewAerInit = 
                            case Aer#battle_state.sign of
                                2 ->	
									lib_player:refresh_player_buff(AerInit#player.other#player_other.pid_send, Buff, Now),
                                    AerInit#player{
                                        other = AerInit#player.other#player_other{
                                            battle_status = Buff									  
                                        }						
                                    };
                                _ ->
                                    AerInit#ets_mon{
                                        battle_status = Buff				
                                    }
                            end,                    
                        [NewAerInit, NewAer, Der];
                        
                    %% 持续减防
                    last_def ->
                        Def = value_cate(Val, Der#battle_state.def),		
                        Buff = [{Key, Val, Now + LastTime, SkillId, Slv} | Der#battle_state.battle_status],
                        NewDer = Der#battle_state{
                            def = Def,
                            battle_status = Buff
                        },
						if
							Der#battle_state.sign == 2 ->
								Der#battle_state.pid ! {'SET_BATTLE_STATUS', {4, [Buff]}};
                            true ->
                           		Der#battle_state.pid ! {'SET_MON_BUFF', Buff} 
                        end,						
                        [AerInit, Aer, NewDer];

                    %% 防御
                    def ->
                        Def = value_cate(Val, Aer#battle_state.def),		
                        Buff = [{Key, Val, Now + LastTime, SkillId, Slv} | Aer#battle_state.battle_status],
                        NewAer = Aer#battle_state{
                            def = Def,
                            battle_status = Buff
                        },
                        NewAerInit = 
                            case Aer#battle_state.sign of
                                2 ->
	                                lib_player:refresh_player_buff(AerInit#player.other#player_other.pid_send, Buff, Now),
                                    AerInit#player{
                                        other = AerInit#player.other#player_other{
                                            battle_status = Buff								  
                                        }						
                                    };
                                _ ->
                                    AerInit#ets_mon{
                                        battle_status = Buff				
                                    }
                            end,						
                        [NewAerInit, NewAer, Der];
                    
                    %% 冲锋
                    assault ->
                  		[X, Y] = lib_battle:get_battle_coordinate(Aer#battle_state.x, Aer#battle_state.y, Der#battle_state.x, Der#battle_state.y, 1),							
						case lib_scene:is_blocked(Aer#battle_state.scene, [X, Y]) of
							true ->
								lib_battle:update_battle_limit(Der, LastTime, 2, dizzy, Val, SkillId, Slv, Now),
								{ok, MoveBinData} =  pt_12:write(12110, [2, AerInit#player.id, X, Y, 1]),
								mod_scene_agent:send_to_area_scene(AerInit#player.scene, X, Y, MoveBinData),
                   				NewAerInit = AerInit#player{
                   					x = X,
                    				y = Y						
                 				},
								NewAer = Aer#battle_state{
									x = X,
									y = Y					  
								},
								ets:insert(?ETS_ONLINE_SCENE, NewAerInit),
                       			[NewAerInit, NewAer, Der]; 
							false ->
								[AerInit, Aer, Der]
						end;
                    
                    %% 偷袭
                    flash ->
                        [X, Y] = lib_battle:get_battle_coordinate(Aer#battle_state.x, Aer#battle_state.y, Der#battle_state.x, Der#battle_state.y, 1),					
						case lib_scene:is_blocked(Aer#battle_state.scene, [X, Y]) of
							true ->
                        		{ok, MoveBinData} =  pt_12:write(12110, [2, AerInit#player.id, X, Y, 1]),
								mod_scene_agent:send_to_area_scene(AerInit#player.scene, X, Y, MoveBinData),
								NewAerInit = AerInit#player{
                            		x = X,
                            		y = Y						
                        		},
								NewAer = Aer#battle_state{
									x = X,
									y = Y					  
								},
								ets:insert(?ETS_ONLINE_SCENE, NewAerInit),
                        		[NewAerInit, NewAer, Der];
							false ->
								[AerInit, Aer, Der]
						end;
                    
                    %% 减速
                    speed ->
						lib_battle:battle_speed(Der, DerInit, LastTime, Val, SkillId, Slv, Now),
                        [AerInit, Aer, Der];					
                    _ ->
                        [AerInit, Aer, Der]
                end;
            _ ->
                [AerInit, Aer, Der]
        end,
    add_last_active_buff_loop(SkillEffect, RetAerInit, DerInit, RetAer, RetDer, SkillId, Slv, Now, LastimeSkillEffect).

%% 检查更新攻击方持续效果，有则加成，过期则去掉
%% K 效果类型
%% V 效果值
%% T 技能效果结束时间
%% S 技能ID
%% L 技能等级
%% Aer 攻击方信息
%% Buff 持续效果BUFF信息
%% Time 现在时间
check_aer_last_buff([], Aer, AerInit, Buff, _Now) ->
    NewAerInit = 
		case Aer#battle_state.sign of
			2 ->				
				AerInit#player{
					other = AerInit#player.other#player_other{
						battle_status = Buff									  
					}						
				};
			_ ->
				AerInit#ets_mon{
					battle_status = Buff				
				}
		end,
	NewAer = Aer#battle_state{
        battle_status = Buff
    },
	[NewAer, NewAerInit];
check_aer_last_buff([{K, V, T, S, L} | H], Aer, AerInit, Buff, Now) ->
    %% 判断效果有没过期
    case T > Now of
        true ->            
            NewAer = 
                case K of
                    %% 加攻击(负数为减攻击)
                    att ->
                        AttMin = value_cate(V, Aer#battle_state.att_min),
                        AttMax = value_cate(V, Aer#battle_state.att_max),
                        Aer#battle_state{
                            att_min = AttMin,
                            att_max = AttMax
                        };
					
					%% 攻城战攻击BUFF
					castle_rush_att ->
						Aer#battle_state{
                   			att_min = V + Aer#battle_state.att_min,
                        	att_max = V + Aer#battle_state.att_max
                  		};
						
					%% 物品Buff
					goods_last_att_add ->
						case V of
							[Val, _Ratio, _ColdTime] ->
								AttMin = value_cate(Val, Aer#battle_state.att_min),
                                AttMax = value_cate(Val, Aer#battle_state.att_max),
                                Aer#battle_state{
                                    att_min = AttMin,
                                    att_max = AttMax
                                };
							_ ->
								Aer
						end;
					
					%% 区域增加攻击
					last_zone_att ->
                       	AttMin = value_cate(V, Aer#battle_state.att_min),
                     	AttMax = value_cate(V, Aer#battle_state.att_max),
                     	Aer#battle_state{
                  			att_min = AttMin,
                           	att_max = AttMax
                      	};
                        
                    %% 加大攻击伤害
                    hurt_add ->
                       	Aer#battle_state{
                            hurt_add = V
                        };
                        
                    %% 加命中
                    hit_add ->                    
                       	Aer#battle_state{
							hit = value_cate(V, Aer#battle_state.hit)
                        };

                    hit ->                    
                       	Aer#battle_state{
                            hit = value_cate(V, Aer#battle_state.hit)
                        };
                        
                    %% 加暴击
                    crit ->                   
                       	Aer#battle_state{
							crit = value_cate(V, Aer#battle_state.crit)
                        };
                        
                    %% 加躲闪
                    dodge ->                    
                        Aer#battle_state{
							dodge = value_cate(V, Aer#battle_state.dodge)
                        };                   

                    %% 防御
                    def ->
                        Aer#battle_state{
                            def = value_cate(V, Aer#battle_state.def)
                        };				
						
                    _ ->
                        Aer
                end,
            check_aer_last_buff(H, NewAer, AerInit, [{K, V, T, S, L} | Buff], Now);
        false ->
			case K =/= last_anti of
				true ->
            		check_aer_last_buff(H, Aer, AerInit, Buff, Now);
				false ->
					check_aer_last_buff(H, Aer, AerInit, [{K, V, T, S, L} | Buff], Now)
			end
    end.

%% 检查更新被击方持续效果，有则加成，过期则去掉
%% K 效果类型
%% V 效果值
%% T 技能效果结束时间
%% S 技能ID
%% L 技能等级
%% Der 被击方信息
%% BattleStatus 持续效果BUFF信息
%% Now 现在时间
check_der_last_buff([], Der, Buff, _Now) ->
	Der#battle_state{
  		battle_status = Buff
	};
check_der_last_buff([{K, V, T, S, L} | H], Der, Buff, Now) ->
    %% 判断效果有没过期
    case T > Now of
        true ->
            case K of                
                %% 加躲闪
                dodge ->                    
                    NewDer = Der#battle_state{
                        dodge = V + Der#battle_state.dodge
                    },
                    check_der_last_buff(H, NewDer, [{K, V, T, S, L} | Buff], Now);
				
				%% 持续减防
                last_def ->              
                	NewDer = Der#battle_state{
						def = value_cate(V, Der#battle_state.def)
					},
                    check_der_last_buff(H, NewDer, [{K, V, T, S, L} | Buff], Now);

                %% 吸收伤害，吸收伤害值为0时则去掉效果
                shield ->
                    case V > 0 of
                        true ->
                            check_der_last_buff(H, Der, [{K, V, T, S, L} | Buff], Now);
                        false ->
                            check_der_last_buff(H, Der, Buff, Now)
                    end;
				
				%% 区域增加攻击
				last_zone_def ->
					NewDer = Der#battle_state{
                  		def = value_cate(V, Der#battle_state.def)
                  	},
					check_der_last_buff(H, NewDer, [{K, V, T, S, L} | Buff], Now);
				
				%% 攻城战抗性BUFF
				castle_rush_anti ->
					NewDer = Der#battle_state{
                  		def = V + Der#battle_state.def
                  	},
					check_der_last_buff(H, NewDer, [{K, V, T, S, L} | Buff], Now);

                _ ->
                    check_der_last_buff(H, Der, [{K, V, T, S, L} | Buff], Now)
            end;
        false ->			
            check_der_last_buff(H, Der, Buff, Now)
    end.

%% 技能数据检测
check_skill_data(SkillData, AerInit, DerInit, Aer, Der, SkillId, Slv, Now) ->
	case SkillData of
        [] ->
      		{Aer, Der, 1, AerInit, []};
        _SkillData ->
            %% 计算攻击方的瞬间技能效果
            [Aer1, Der1] = cale_active_effect(SkillData#ets_skill.data, Aer, Der),
            [NewAerInit, Aer2, Der2, LastimeSkillEffect] = add_last_active_buff(AerInit, DerInit, SkillData#ets_skill.data, Aer1, Der1, SkillId, Slv, Now),
            NewBaseSkillHurt =
                case lists:keyfind(base_att, 1, SkillData#ets_skill.data) of
                    {base_att, BaseSkillHurt} ->
                 		BaseSkillHurt;
                    _ ->
                        1
                end,		
            {Aer2, Der2, NewBaseSkillHurt, NewAerInit, LastimeSkillEffect}
    end.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 辅助技能函数
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% 发动辅助技能
assist_skill(Aer, DerId, SkillId) ->
   	case lists:keyfind(SkillId, 1, Aer#player.other#player_other.skill) of
   		false ->
			skip;
     	{_SkillId, Slv} ->
            %% 判断技能是否存在
            case data_skill:get(SkillId, Slv) of
                [] ->
					skip;
                SkillData ->
					%% 是否辅助技能
					case SkillData#ets_skill.type == 2 of
						true ->
							case lists:keyfind(lastime, 1, SkillData#ets_skill.data) of
        						false ->
            						skip;
        						{_, SkillEffect} ->
									if
										Aer#player.id == DerId ->
											use_assist_skill(Aer, Aer, SkillData, SkillEffect, SkillId, Slv);
										true ->
											case lib_player:get_online_info(DerId) of
												[] ->
													skip;
												Der ->
													NewDer = lib_battle:check_assist_object(Aer, Der),
													use_assist_skill(Aer, NewDer, SkillData, SkillEffect, SkillId, Slv)
											end
									end
							end;
						false ->
							skip
					end
            end
  	end.

%% 使用辅助技能
%% DX 被击者的X坐标
%% DY 被击者的Y坐标
use_assist_skill(Aer, Der, SkillData, SkillEffect, SkillId, Slv) ->
	BattleDict = get_battle_dict(),
	Now = util:unixtime(),
	DX = Der#player.x, 
	DY = Der#player.y,
	%% 判断施法条件
    case check_skill_cast_condition(SkillData, Aer#player.mp_lim, Aer#player.mp, Aer#player.x, Aer#player.y, DX, DY, Aer#player.att_area, BattleDict, Now) of
        {mp_error, NewBattleDict} ->
            lib_battle:battle_fail(5, Aer, 2),
			put(battle_dict, NewBattleDict);
        {att_area_error, NewBattleDict} ->
            lib_battle:battle_fail(4, Aer, 2),
			put(battle_dict, NewBattleDict);
        {cd_error, NewBattleDict} ->
			put(battle_dict, NewBattleDict);
        {ok, NewBattleDict, LeftMp} ->
            NewAer = Aer#player{
                mp = LeftMp
            },
			%% 加血、回血技能另外处理
		    case SkillData#ets_skill.assist_type of
		        %% 持续性技能
		        0 ->
					Der#player.other#player_other.pid ! {'ADD_LAST_SKILL_BUFF', SkillEffect, SkillId, Slv},
  					%% 发送辅助技能信息
  					send_assist_msg(NewAer#player.id, SkillId, DX, DY, Slv, LeftMp, Der#player.scene, [[Der#player.id, Der#player.hp]]);
		        %% 一次性使用技能
		        _ ->
		            add_short_skill_buff(NewAer, Der, SkillEffect, SkillId, Slv)
		    end,
			put(battle_dict, NewBattleDict),
			{ok, change_status, NewAer}
    end.
    
%% 一次性辅助技能能效果
%% Aer 技能发起方信息
%% User 技能受用方信息
%% SkillData 技能数据
%% SkillId 技能ID
%% Slv 技能等级
add_short_skill_buff(Aer, User, [{_LastTime, Key, Val}], SkillId, Slv) ->    
	case Key of
        %% 加Hp
        hp ->              
			AddHp = round(treatment_formula(Aer) * Val) + User#player.hp,
            NewHp = 
                case AddHp > User#player.hp_lim of
                    true ->
                        User#player.hp_lim;
                    false ->
                        AddHp
                end,
			NewMp = 
				if
					Aer#player.id /= User#player.id ->
						User#player.mp;
					true ->
						Aer#player.mp
				end,
            User#player.other#player_other.pid ! {'PLAYER_BATTLE_RESULT', [NewHp, NewMp, 0, 0, 0, 0, 0, Aer#player.scene]},
            send_assist_msg(Aer#player.id, SkillId, User#player.x, User#player.y, Slv, Aer#player.mp, User#player.scene, [[User#player.id, NewHp]]);
        
		%% 持续回血
        last_add_hp ->
            {LT, Interval, HpParam} = Val,
            LastTime = round(LT / Interval),
            NewInterval = Interval * 1000,
			NewAddHp = 
				case is_float(HpParam) of
					true ->
						round(treatment_formula(Aer) * HpParam);	
					false ->
						HpParam
				end,	
            ObjPid = User#player.other#player_other.pid,
			Message = {
				'START_HP_TIMER', 
				ObjPid,
				User#player.id,
				User#player.nickname,
				User#player.career,
				User#player.realm, 
				-NewAddHp,
				0, 
				LastTime, 
				NewInterval
			},
            ObjPid ! Message,          
            send_assist_msg(Aer#player.id, SkillId, User#player.x, User#player.y, Slv, Aer#player.mp, User#player.scene, [[User#player.id, User#player.hp]]);

        _ ->
            skip
    end.

%% 治疗公式
treatment_formula(Player) ->
	(Player#player.mp_lim * 0.05 + Player#player.wit * 4) * 0.4.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 一些私有工具函数
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%           

%% 保存数据
save(Aer, AerInit, BattleDict, SkillId, Slv, DerBattleResult) ->
	send_battle_msg(Aer, SkillId, Slv, DerBattleResult, 20001),
    Player = AerInit#player{
        hp = Aer#battle_state.hp,
        mp = Aer#battle_state.mp,
        other = AerInit#player.other#player_other{
            battle_dict = BattleDict  
        }
    },
	BattleList = [
		{hp, Player#player.hp},
		{mp, Player#player.mp},
		{evil, Player#player.evil},
		{realm_honor, Player#player.realm_honor},
		{carry_mark, Player#player.carry_mark},
		{battle_status, Player#player.other#player_other.battle_status}
	],
	gen_server:cast(Player#player.other#player_other.pid, {'SET_PLAYER_FOR_BATTLE', BattleList}),
	ets:insert(?ETS_ONLINE_SCENE, Player),
	Player.


%% 发送战斗结果消息
send_battle_msg(Aer, SkillId, Slv, DerBattleResult, Protocol) ->
%%	?DEBUG("X:~p                y:~p           ~n",[Aer#battle_state.x, Aer#battle_state.y]),
    {ok, BinData} = pt_20:write(Protocol, [Aer#battle_state.id, Aer#battle_state.hp, Aer#battle_state.mp, SkillId, Slv, DerBattleResult]),
	lib_send:send_to_online_scene(Aer#battle_state.scene, Aer#battle_state.x, Aer#battle_state.y, BinData).


%% 发送辅助技能信息
%% PlayerId 玩家ID
%% SkillId 技能ID
%% Slv 技能等级
%% MP 玩家的魔
%% SceneId 玩家所在场景的ID
%% AssistList 被辅助者的信息列表
send_assist_msg(PlayerId, SkillId, X, Y, Slv, MP, SceneId, AssistList) ->
    {ok, BinData} = pt_20:write(20006, [PlayerId, SkillId, Slv, MP, AssistList]),
    mod_scene_agent:send_to_area_scene(SceneId, X, Y, BinData).

%% 技能触发频率
%% SkillId 技能ID
%% CD 该技能的CD时间
%% State 战斗状态信息
skill_use_frequency(SkillId, CD, BattleDict, Now) ->	
    case lists:keyfind(SkillId, 1, BattleDict#battle_dict.last_skill_time) of
        false ->
            NewBattleDict = BattleDict#battle_dict{
                last_skill_time = [{SkillId, Now} | BattleDict#battle_dict.last_skill_time]
            },
            [true, NewBattleDict];
        {_, Time} ->
			if
          		Time + CD < Now + 1 ->
					LastSkillTime = lists:keyreplace(SkillId, 1, BattleDict#battle_dict.last_skill_time, {SkillId, Now}),
                    NewBattleDict = BattleDict#battle_dict{
                        last_skill_time = LastSkillTime
                    },
                    [true, NewBattleDict];
                true ->
                    [false, BattleDict]
            end
    end.

%% 初始化战斗双方属性
%% Self 自己
%% Other 别人
%% SelfType、OtherType 1自己是怪、2自己是人
%% AttType 1攻击方、2被击方
init_data([Self, SelfType], [Other, OtherType], Now, AttType) ->
	%% 命中系数
	HitParam = 1000,
	%% 躲闪系数
	DodgeParam = 1200,
	%% 暴击系数
	CritParam = 2000,
  	case SelfType of 
		1 ->
			MonDef = 
				case (Self#ets_mon.type >= 10 andalso lists:member(Self#ets_mon.type, [37, 38, 39]) =:= false) andalso OtherType == 2 of
					%% 人VS塔怪
					true ->
						get_career_anti_mon(Self, Other#player.career);
					false ->
						Self#ets_mon.def
				end,
            #battle_state{
                id = Self#ets_mon.id,
				name = Self#ets_mon.name,
                scene = Self#ets_mon.scene,
                lv = Self#ets_mon.lv,
                hp = Self#ets_mon.hp,
                hp_lim = Self#ets_mon.hp_lim,
                mp = Self#ets_mon.mp,
                mp_lim = Self#ets_mon.mp_lim,
                att_max = Self#ets_mon.max_attack,
                att_min = Self#ets_mon.min_attack,
                def = MonDef,
                x = Self#ets_mon.x,
                y = Self#ets_mon.y,
                att_area = Self#ets_mon.att_area,
                pid = Self#ets_mon.pid,
                hit = (Self#ets_mon.hit - Self#ets_mon.init_hit) / HitParam + 0.85,
                dodge = (Self#ets_mon.dodge - Self#ets_mon.init_dodge) / DodgeParam,
                crit = (Self#ets_mon.crit - Self#ets_mon.init_crit) / CritParam,
                battle_status = Self#ets_mon.battle_status,
                sign = 1,
				type = Self#ets_mon.type,
                status = Self#ets_mon.status,
                relation = Self#ets_mon.relation
			};
      	2 ->
			%% 添加物品短持续时间BUFF
			Buff = data_agent:get_goods_skill_all(Self, Now, AttType),
			GoodsBuffCD = Self#player.other#player_other.goods_buf_cd,
			Def = 
				case OtherType of
					%% 被击方是人，自己也是人
					2 ->
						%%被攻击者的神器被动技能发动几率减免 
						OtherDeputyPassiveSkill = Other#player.other#player_other.deputy_passive_att ,
						get_career_anti(Self, Other#player.career);
					_ ->
						OtherDeputyPassiveSkill = [],
						case Other#ets_mon.type >= 10 andalso lists:member(Other#ets_mon.type, [37, 38, 39]) =:= false of
							false ->
								Self#player.def;
							true ->
								MonCareer = Other#ets_mon.type rem 10,
								get_career_anti(Self, MonCareer)
						end
				end,
            CareerInfo = lib_player:get_attribute_parameter(Self#player.career),
			HitInit = CareerInfo#ets_base_career.hit_init,
			DodgeInit = CareerInfo#ets_base_career.dodge_init,
			CritInit = CareerInfo#ets_base_career.crit_init,		
            #battle_state{
                id = Self#player.id,
                name = Self#player.nickname,
                scene = Self#player.scene,
                lv = Self#player.lv,
                career = Self#player.career,
                hp = Self#player.hp,
                hp_lim = Self#player.hp_lim,
                mp = Self#player.mp,
                mp_lim = Self#player.mp_lim,
                att_max = Self#player.max_attack,
                att_min = Self#player.min_attack,
                def = Def,
                x = Self#player.x,
                y = Self#player.y,
                att_area = Self#player.att_area,
                pid = Self#player.other#player_other.pid,
                hit = (Self#player.hit - HitInit) / HitParam + 0.85,
                dodge = (Self#player.dodge - DodgeInit) / DodgeParam,
                crit = (Self#player.crit - CritInit) / CritParam,
                battle_status = Buff,
                pk_mode = Self#player.pk_mode,
                realm = Self#player.realm,
                guild_id = Self#player.guild_id,
                pid_team = Self#player.other#player_other.pid_team,
                sign = 2,
                status = Self#player.status,
                evil = Self#player.evil,
				realm_honor = Self#player.realm_honor,
				leader = Self#player.other#player_other.leader,
				goods_buf_cd = GoodsBuffCD,
				deputy_skill = Self#player.other#player_other.deputy_skill,
				deputy_passive_skill = OtherDeputyPassiveSkill,
				deputy_prof_lv = Self#player.other#player_other.deputy_prof_lv,
				g_alliance = Self#player.other#player_other.g_alliance
            };
      	_ ->
            [Id, MaxAtt, MinAtt, Def, Hit, Dodge, Crit, Hp, Mp, Lv, Pid, Sign, BattleStatus, Type, Evil, RealmHonor, Relation] = Self,
            #battle_state{
                id = Id,
                hp = Hp,
                mp = Mp,
                lv = Lv,
                att_max = MaxAtt,
                att_min = MinAtt,
                def = Def,
                pid = Pid,
                hit = (Hit - 800) / HitParam + 0.85,
                dodge = (Dodge - 50) / DodgeParam,
                crit = (Crit - 50) / CritParam,
                battle_status = BattleStatus,
                sign = Sign,
				type = Type,
                evil = Evil,
				realm_honor = RealmHonor,
                relation = Relation
            }
  	end.

%% 获取相应职业的抗性值
%% Der 被击方信息
%% Career 攻击方的职业
get_career_anti(Der, Career) ->
	case Career of
		%% 战士
		1 ->
			Der#player.anti_wind;
		%% 刺客
		2 ->
			Der#player.anti_water;
		%% 弓手
		3 ->
			Der#player.anti_thunder;
		%% 牧师
		4 ->
			Der#player.anti_fire;
		%% 武尊
		_ ->
			Der#player.anti_soil
	end.

%% 获取相应怪物职业的抗性值
%% Der 被击方信息
%% Career 攻击方的职业
get_career_anti_mon(Der, Career) ->
	case Career of
		%% 战士
		1 ->
			Der#ets_mon.anti_wind;
		%% 刺客
		2 ->
			Der#ets_mon.anti_water;
		%% 弓手
		3 ->
			Der#ets_mon.anti_thunder;
		%% 牧师
		4 ->
			Der#ets_mon.anti_fire;
		%% 武尊
		_ ->
			Der#ets_mon.anti_soil
	end.

%% 更新被击方的气血
%% Der 被击方战斗信息
%% Aer 攻击方战斗信息
%% Hp 被击方血量
%% Mp 被击方魔量
update_der_hp(Der, Aer, Hp, Mp, Hurt) ->
    AerPid = Aer#battle_state.pid,
	DerPid = Der#battle_state.pid,
	AerId = Aer#battle_state.id,
    case Der#battle_state.sign of
        %% 怪物
        1 ->
            %% 判断怪物是否返回状态
            case Der#battle_state.status of
                0 ->
					case lib_mon:is_boss_mon(Der#battle_state.type) of
                   		false ->
							DerPid ! {'MON_BATTLE_RESULT', [Hp, AerId, AerPid, Aer#battle_state.career]};
                    	%% BOSS怪
                   		true ->
							%% 不能攻击镇妖剑
							if
								Der#battle_state.type == 100 andalso Aer#battle_state.sign == 2 ->
									skip;
								true ->
									Hate = add_hate(Aer, Hurt),
									DerPid ! {'MON_BOSS_BATTLE_RESULT', [Hp, AerId, Aer#battle_state.name, AerPid, Hate, Aer#battle_state.pid_team, Aer#battle_state.sign]}
							end
                   	end;
                _ ->
                    skip
            end;                
        _ ->
            Message = 
                case Aer#battle_state.sign of
                    1 ->     
						case Aer#battle_state.scene =:= ?WARFARE_SCENE_ID of
							true ->
								MonName =
									case ets:match_object(?ETS_SCENE_MON, #ets_mon{scene = Aer#battle_state.scene, id = AerId, _ = '_'}) of
										[] ->
											"神魔怪";
										[Mon|_R] ->
											Mon#ets_mon.name
									end;
							false ->
								MonName = ""
						end,
                        [Hp, Mp, 0, 0, MonName, 0, 0, Aer#battle_state.scene];
                    _ ->                        
                        [Hp, Mp, AerPid, AerId, Aer#battle_state.name, Aer#battle_state.career, Aer#battle_state.realm, Aer#battle_state.scene]
                end,
			lib_scene:update_player_info_fields_for_battle(Der#battle_state.id,	Hp, Mp),
            DerPid ! {'PLAYER_BATTLE_RESULT', Message}
    end.

%% 判断技能施放是否符合条件
%% Aer 攻击方
%% Der 被击方
%% SkillData 技能信息
%% SkillId 技能ID
%% State 战斗状态信息
check_skill_cast_condition(SkillData, AerMpLim, AerMp, AX, AY, DX, DY, AerAttArea, BattleDict, Now) ->
    {_, [{_, MpOut1}, {_, CD}, {_, Att_Area}]} = lists:keyfind(cast, 1, SkillData#ets_skill.data),
    %% 判断上次放技能时间	
    case skill_use_frequency(SkillData#ets_skill.id, CD, BattleDict, Now) of
        [true, NewBattleDict] ->
            %% 判断MP是否足够
            MpOut = 
                case is_float(MpOut1) of
                    true ->
                        round(MpOut1 * AerMpLim);
                    _ ->
                        MpOut1
                end,			
            LeftMp = AerMp - MpOut,
			if
           		LeftMp > 0 ->
                    %% 施法目标是自身不用判断施法距离
					if
                  		SkillData#ets_skill.obj /= 1 ->
                            %% 判断攻击距离
                            AttArea =
								if
                               		Att_Area > 0 ->
                                        Att_Area;
                                    true ->
                                        AerAttArea
                                end,                                    
                            case lib_battle:check_att_area(AX, AY, DX, DY, AttArea) of
                                true ->                                    
                                    {ok, NewBattleDict, LeftMp};
                                _ ->
                                    {att_area_error, NewBattleDict}
                            end;
                        true ->
                            {ok, NewBattleDict, LeftMp}
                    end;                            
         		true ->
                    {mp_error, NewBattleDict}
            end;
        [false, NewBattleDict] ->
            {cd_error, NewBattleDict}
    end.

%% 获取等级压制命中和暴击的加成值
%% Aer 攻击方
%% Der 被击方
get_lv_advantage(AerSign, DerSign, AerLv, DerLv) ->
	case AerSign of
        %% 玩家
        2 ->
            %% 攻击方与被击方的等级差距
            LvDist = AerLv - DerLv,
            case DerSign of
                %% 怪物
                1 ->
                    if
                        LvDist >= 10 ->
                            [0.1, 0.05];
                        LvDist >= 8 ->
                            [0.08, 0.04];
                        LvDist >= 5 ->
                            [0.05, 0.03];
                        LvDist >= 3 ->
                            [0.03, 0.02];
						LvDist =< -10 ->
                            [-0.08, -0.05];
						LvDist =< -8 ->
                            [-0.06, -0.04];
						LvDist =< -5 ->
                            [-0.04, -0.03];
                        LvDist =< -3 ->
                            [-0.02, -0.02];
						true ->
							[0, 0]
                    end;
                _ ->
                    if
                        LvDist >= 10 ->
                            [0.06, 0];							
                        LvDist >= 5 ->
                            [0.03, 0];
						LvDist =< -10 ->
                            [-0.06, 0];
                        LvDist =< -5 ->
                            [-0.03, 0];
						true ->
							[0, 0]
                    end
            end;
        _ ->
            [0, 0]
    end.


%% 检查攻击方是否进入蓝名状态
%% Aer 攻击方的战斗信息
%% Der 被击方的战斗信息
%% AerInit 攻击方的原始信息
%% DerInit 被击方的原始 信息
check_blue_status(AerInit, DerInit, Der) ->
	if
		Der#battle_state.sign == 2 andalso AerInit#player.status /= 4 
						andalso DerInit#player.status /= 4 andalso DerInit#player.evil < 90 ->
			enter_blue_status(AerInit);
      	true ->
			skip
    end.

%% 蓝名状态
%% Player 玩家信息
enter_blue_status(Player) ->
	%% 竞技场,自由竞技场,神岛空战不进入蓝名状态
	case 
			lib_arena:is_arena_scene(Player#player.scene) 
			orelse lib_war:is_war_server() 
			orelse lists:member(Player#player.scene, [?FREE_PK_SCENE_ID, ?SKY_RUSH_SCENE_ID, ?CASTLE_RUSH_SCENE_ID]) 
			orelse lib_coliseum:is_coliseum_scene(Player#player.scene)
			orelse lib_era:is_era_scene(Player#player.scene)
	of
		false ->
      		Player#player.other#player_other.pid ! 'ENTER_BLUE_STATUS';
		true ->
			skip
	end.

%% 是否躲闪
is_dodge(Der, BattleDict, Hit, Now) ->
	%% 判断是否在返回状态
	case Der#battle_state.status == 1 andalso lists:member(Der#battle_state.type, [3, 20, 21, 22, 23, 24, 25]) of
		true ->
			true;	
		false ->
			Rand = util:rand(1, 1000),
			case lists:keyfind(dodge, 1, Der#battle_state.battle_status) of
				false ->
					Rand > Hit andalso Now - 1 > BattleDict#battle_dict.last_dodge_time;
				_ ->
					Rand > Hit	
			end
	end.

%% 添加仇恨
add_hate(Aer, Hurt) ->
	%% 镇妖台甲士
	case Aer#battle_state.sign == 1 andalso Aer#battle_state.type == 100 andalso Aer#battle_state.att_area == 2 of
		true ->
			round(Hurt * 3);
		false ->
            case Aer#battle_state.career of
                1 ->
                    Hurt * 2;
                2 ->
                    round(Hurt * 1.5);
                3 ->
                    round(Hurt * 1.5);
                5 ->
                    round(Hurt * 1.6);
                _ ->
                    Hurt
            end
	end.

%% 反弹伤害技能
bounce_skill(Aer, Der, Hurt, Val) ->
	%% 反弹的伤害
    BounceHurt = util:ceil(Hurt * Val), 
    %% 反弹后攻击方剩余的气血
    AerHp =
		if
       		Aer#battle_state.hp > BounceHurt ->
                Aer#battle_state.hp - BounceHurt;
            true ->
                0
        end,
    %% 更新被击方气血
    update_der_hp(Aer, Der, AerHp, Aer#battle_state.mp, BounceHurt),
    %% 广播给附近玩家
    {ok, BinData} = 
        case Aer#battle_state.sign of
            1 ->
                pt_12:write(12082, [Aer#battle_state.id, AerHp]);
            _ ->
                pt_12:write(12009, [Aer#battle_state.id, AerHp, Aer#battle_state.hp_lim])
        end,
	lib_send:send_to_online_scene(Aer#battle_state.scene, Aer#battle_state.x, Aer#battle_state.y, BinData),
	Aer#battle_state{
		hp = AerHp				 
	}.

%% 整数相加，小数相乘
value_cate(V1, V2) when is_float(V1) ->
	case is_float(V2) of
    	false ->			
			round(V2 * (1 + V1));
		true ->
			V2 * (1 + V1)
	end;
value_cate(V1, V2) ->
    round(V2 + V1).

%% 持续技能伤害
last_skill_effect(Aer, Der, LastimeSkillEffect, SkillId, Slv, Now) ->
	%% 判断有没有持续掉血技能
	case LastimeSkillEffect of
		[{LastTime, Key, Val}] ->
			case Key of
				%% 持续流血
				drug ->
					lib_battle:battle_drug(Aer, Der, LastTime, Val);						    
				%%持续百分比掉血
				drug_prc ->
					AttPid = 
						case Aer#battle_state.sign of
							2 ->
								Aer#battle_state.pid;
							_ ->
								0
						end,										
                    case Der#battle_state.sign of
                        2 -> 
                            Msg = {'START_HP_TIMER', AttPid, Aer#battle_state.id, Aer#battle_state.name, Aer#battle_state.career, Aer#battle_state.realm, Val,1, LastTime, 1000},
                            Der#battle_state.pid ! {'SET_TIME_PLAYER', 1000, Msg};
                        _ ->
                       		Msg = {'START_HP_TIMER', Aer#battle_state.id, AttPid, Val,1, LastTime, 1000},
                          	Der#battle_state.pid ! {'SET_TIME_MON', 1000, Msg}
                    end;				
				%% 定身
                stand ->
					lib_battle:update_battle_limit(Der, LastTime, 1, Key, Val, SkillId, Slv, Now);

                %% 昏迷
                dizzy ->
					lib_battle:update_battle_limit(Der, LastTime, 2, Key, Val, SkillId, Slv, Now);

                %% 沉默（封技）
                silence ->
					lib_battle:update_battle_limit(Der, LastTime, 3, Key, Val, SkillId, Slv, Now);
				
				%% 命中
                hit ->
					DerBuff = Der#battle_state.battle_status,
					BuffData = {Key, Val, Now + LastTime, SkillId, Slv},
                    Buff =
                        case lists:keyfind(Key, 1, DerBuff) of
                            false ->
                                [BuffData | DerBuff];									
                            _BuffData ->
                                lists:keyreplace(Key, 1, DerBuff, BuffData)
                        end,
                    Pid = Der#battle_state.pid,
                    case Der#battle_state.sign of
                        2 ->
                      		Pid ! {'SET_BATTLE_STATUS', {4, [Buff]}};
                        _ ->
                            Pid ! {'SET_MON_BUFF', Buff} 
                    end;
				
				%% 对被击方的攻击影响
				att_der ->
					DerBuff = Der#battle_state.battle_status,
					BuffData = {att, Val, Now + LastTime, SkillId, Slv},
					Buff = 
						case lists:keyfind(att, 1, DerBuff) of 
							false ->
								[BuffData | DerBuff];
							_BuffData ->
								lists:keyreplace(att, 1, DerBuff, BuffData)
						end,
                    Pid = Der#battle_state.pid,
                    case Der#battle_state.sign of
                        2 ->
                       		Pid ! {'SET_BATTLE_STATUS', {4, [Buff]}};
                        _ ->
                            Pid ! {'SET_MON_BUFF', Buff}
                    end;
				
				%% 仇恨
				hate ->
					case lib_mon:is_boss_mon(Der#battle_state.type) of
    					true ->
        					Der#battle_state.pid ! {'ADD_SKILL_HATE', Aer#battle_state.id, Aer#battle_state.pid, LastTime};
    					_ ->
        					skip
					end; 
				%% 引燃
				ignite ->
					case lists:keyfind(burn, 1, Der#battle_state.battle_status) of
						false ->
							skip;
						_ ->
							AttPid = 
								case Aer#battle_state.sign of
									2 ->
										Aer#battle_state.pid;
									_ ->
										0
								end,										
		                    case Der#battle_state.sign of
		                        2 -> 
		                            Msg = {'START_HP_TIMER', AttPid, Aer#battle_state.id, Aer#battle_state.name, Aer#battle_state.career, Aer#battle_state.realm, Val,0, LastTime, 1000},
		                            Der#battle_state.pid ! {'SET_TIME_PLAYER', 1000, Msg},
									BuffData = {Key, Val, Now + LastTime, SkillId, Slv},
									Der#battle_state.pid ! {'SET_BATTLE_STATUS', {7, [BuffData]}};
		                        _ ->
		                       		Msg = {'START_HP_TIMER', Aer#battle_state.id, AttPid, Val,0, LastTime, 1000},
		                          	Der#battle_state.pid ! {'SET_TIME_MON', 1000, Msg}
		                    end
					end;							
				_ ->
					skip
			end;
		_ ->
			skip
	end.
		
