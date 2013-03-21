%% Author: zj
%% Created: 2011-11-25
%% Description: TODO: 神器技能
-module(lib_deputy_skill).
-include("battle.hrl").
-include("common.hrl").
-include("record.hrl").
%%
%% Include files
%%

%%
%% Exported Functions
%%
-compile(export_all).

%%
%% API Functions
%%
%%神器技能触发
%% Type 攻击效果触发
%% Aer 攻击方信息
%% Der 防守方信息
%%神器的特殊技能 【神器攻击】
%%神器攻击在攻击开始时候发动，攻击结束计算伤害后额外添加伤害，
cale_deputy_effect_attack(Aer,Der) ->
	Att_max = Aer#battle_state.att_max,
	Att_min = Aer#battle_state.att_min,
	Deputy_prof_lv = Aer#battle_state.deputy_prof_lv,
	LvR = 
		case Deputy_prof_lv of
			1 -> 10;
			2 -> 13;
			3 -> 16;
			4 -> 19;
			5 -> 23;
			6 -> 26;
			7 -> 30;
			_ -> 0
		end,
	case Deputy_prof_lv > 0 andalso util:rand_test(LvR) of
			true ->
				deputy_skill_broadcast(Aer,Der,90001,Deputy_prof_lv),
					Rate = 
						case Deputy_prof_lv of
				 			1 -> 0.05;
							2 -> 0.1;
							3 -> 0.15;
							4 -> 0.20;
							5 -> 0.25;
							6 -> 0.30;
							7 -> 0.35;
							_ -> 0
						end,
				Hurt = round(util:rand(Att_min,Att_max) * Rate),
				put(cale_deputy_effect_attack,Hurt);
			false ->
				put(cale_deputy_effect_attack,0)
	end.
%%%
%%%攻击时，有一定概率额外消耗对方伤害的法力。
%% 返回被击放法力值
cale_deputy_effect_mp_hurt(Aer,Der) ->
	case Aer#battle_state.deputy_skill of
		[] -> Der#battle_state.mp ;
		Skills  ->
			Mp = Der#battle_state.mp,
			SkillInfo = lists:nth(1, Skills),
			case SkillInfo of
				[90002,Lv] when Lv > 0 -> %%夺魄灭魂
					case Der#battle_state.deputy_passive_skill of
						[_,DecPassiveRatio,_,_] ->%%被击方法力屏障概率
							DecPassiveRatio ;
						_ ->
							DecPassiveRatio = 0
					end,
					Ratio = 
						case Lv of
							1 -> 10;
							2 -> 15;
							3 -> 25;
							4 -> 30;
							_ -> 0
						end,
					case get(cale_deputy_effect_attack) > 0 andalso  util:rand_test(Ratio - DecPassiveRatio *100) of%%
						true ->
							Hurt = get(cale_deputy_effect_attack),
							deputy_skill_broadcast(Aer,Der,90002,Lv),
							Rate =
								case Lv of
									1 -> 0.1;
									2 -> 0.2;
									3 -> 0.32;
									4 -> 0.5;
									_ -> 0
								end,
							MpHurt = trunc(Hurt * Rate),
							NewMp = 
							if
								Mp > MpHurt ->
									Mp - MpHurt;
								true ->
									0
							end,
							NewMp;
						false ->
							Der#battle_state.mp 
					end;
				_ ->
					Der#battle_state.mp
			end	
	end.
%%%
%%攻击时，有一定概率减少目标所有抗性
cale_deputy_effect_anti_hurt(Aer,Der) ->
	case Aer#battle_state.deputy_skill of
		[] -> [Aer,Der];
		Skills ->
			Def = Der#battle_state.def,
			SkillInfo = lists:nth(2, Skills),
			case SkillInfo of
				[90003,Lv] when Lv > 0  -> %%碎星辰
					case Der#battle_state.deputy_passive_skill of
						[_,_,DecPassiveRatio,_] -> %%被击方抗性护盾概率
							DecPassiveRatio;
						_ ->
							DecPassiveRatio = 0
					end,
					Ratio = 
						case Lv of
							1 -> 25;
							2 -> 35;
							3 -> 50;
							_ -> 0
						end,
					case get(cale_deputy_effect_attack) > 0 andalso util:rand_test(Ratio - DecPassiveRatio * 100) of %%
						true ->
							deputy_skill_broadcast(Aer,Der,90003,Lv),
							Rate =
								case Lv of
									1 -> 0.08;
									2 -> 0.13;
									3 -> 0.2;
									_ -> 0
								end,
							AntiHurt = trunc(Def * Rate),
							NewDef = 
							if
								Def > AntiHurt ->
									trunc(Def - AntiHurt);
								true ->
									0
							end,
							NewDer = Der#battle_state{def = NewDef},
							[Aer,NewDer];
						false ->
							[Aer,Der]
					end;
				_ ->
					[Aer,Der]
			end					
	end.
%%%
%%攻击时，有一定概率减少目标移动速度
cale_deputy_effect_speed(Aer,Der,DerInit) ->
	case Aer#battle_state.deputy_skill of
		[] -> skip;
		Skills ->
			SkillInfo = lists:nth(3, Skills),
			case SkillInfo of
				[90004,Lv] when Lv > 0 -> %%千里冰封
					case Der#battle_state.deputy_passive_skill of
						[_,_,_,DecPassiveRatio] ->%%被击方风神祝福概率					
							DecPassiveRatio ;
						_ ->
							DecPassiveRatio = 0
					end,
					Ratio =
						case Lv of
							1 -> 25;
							2 -> 40;
							_ -> 0
						end,
					case get(cale_deputy_effect_attack) > 0 andalso util:rand_test(Ratio - DecPassiveRatio * 100) of %%Lv * 15 + 10
						true ->
							deputy_skill_broadcast(Aer,Der,90004,Lv),         
							Rate =
								case Lv of
									1 -> 0.15;
									2 -> 0.3;
									_ -> 0
								end,
							Val = - Rate ,
							case Der#battle_state.sign of
								2 ->%%人
									%%deputy_skill_broadcast(Aer,Der,90004,Lv),          				
									Speed = DerInit#player.speed,
									NewSpeed = round(Speed * (1 + Val)),
									gen_server:cast(Der#battle_state.pid, {'DEPUTY_SKILL_EFFECT', {speed,DerInit#player.mount, NewSpeed, Speed, 3 * 1000}});
								_ ->%%怪
									case lib_mon:is_boss_mon(Der#battle_state.type) of
										false ->
                                			Speed = DerInit#ets_mon.speed,
                                			NewSpeed = round(Speed * (1 + Val)),									
											Der#battle_state.pid ! {'SET_MON_LIMIT', 1, [Speed, NewSpeed, 3 * 1000]};
										true ->
											skip
									end
							end;
						false ->
							skip
					end;
				_ ->
					skip
			end
	end.
%%%
%%攻击时，有一定概率吸取5%伤害为自身生命，最大吸取值为2000
%%返回攻击者气血值
cale_deputy_effect_hp_hurt(Aer,Der) ->
	case Aer#battle_state.deputy_skill of
		[] -> Aer;
		Skills ->
			Hp = Aer#battle_state.hp,
			Hp_lim = Aer#battle_state.hp_lim,
			SkillInfo = lists:nth(4, Skills),
			case SkillInfo of
				[90005,Lv] when Lv > 0 -> %%吞日月
					case Der#battle_state.deputy_passive_skill of
						[DecPassiveRatio,_,_,_] ->%%被击方气血屏障概率
							DecPassiveRatio ;
						_ ->
							DecPassiveRatio = 0
					end,
					case get(cale_deputy_effect_attack) > 0 andalso util:rand_test(40 - DecPassiveRatio * 100) of %% 40
						true ->
							Hurt = get(cale_deputy_effect_attack),
							deputy_skill_broadcast(Aer,Der,90005,1),
							HpHurt = round(Hurt * 0.15),
							NewHpHurt = 
								if
									HpHurt >= 2000 ->
										2000;
									true ->
										HpHurt
								end,
							NewHp = 
								if
									Hp + NewHpHurt >= Hp_lim ->
										Hp_lim ;
									true ->
										Hp + NewHpHurt
								end,
							%%广播吸血效果
							{ok,Bindata} = pt_12:write(12009,[Aer#battle_state.id,NewHp,Hp_lim]),
							mod_scene_agent:send_to_area_scene(Aer#battle_state.scene, Aer#battle_state.x, Aer#battle_state.y, Bindata),
							Aer#battle_state{hp =NewHp};
						false ->
							Aer
					end;
				_ ->
					Aer
			end					
	end.	


%%技能效果广播
deputy_skill_broadcast(Aer,Der,Skill_id,Lv) ->
%%	io:format("----SKILL:~p~n",[Skill_id]),
	%% 触发技能 增加熟练值
	gen_server:cast(Aer#battle_state.pid, {'DEPUTY_SKILL_EFFECT', {add_prof,1}}),
	DerType = 
		case Der#battle_state.sign of
			1 -> 2; %%怪
			2 -> 1  %%人
		end,
	{ok,Bin} = pt_46:write(46009,[Skill_id,Lv,Aer#battle_state.id,DerType,Der#battle_state.id]),
	mod_scene_agent:send_to_area_scene(Aer#battle_state.scene, Aer#battle_state.x, Aer#battle_state.y, Bin).

%%
%% Local Functions
%%

