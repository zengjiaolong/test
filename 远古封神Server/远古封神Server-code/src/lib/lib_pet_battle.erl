%% Author: ygfs
%% Created: 2012-4-21
%% Description: 宠物战斗
-module(lib_pet_battle).

-include("common.hrl").
-include("record.hrl").
-include("battle.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

%%
%% Exported Functions
%%
-export(
	[
		pet_fight/8,
		pet_skill_flame_action/7
	]
).


pet_fight(Player, DerInit, Aer, Der, DerBattleResult, BattleDict, Now, FromType) ->
	case lib_arena:is_arena_scene(Player#player.scene) of
		false ->
			case Player#player.other#player_other.pet_batt_skill of
				[] ->
					BattleDict;
				undefined ->
					BattleDict;
				PetBattSkill ->
					PetSkillTime = BattleDict#battle_dict.pet_skill_time,
					PetSkillId = get_pet_skill_id(PetBattSkill, PetSkillTime, Now),
					if
						PetSkillId =/= 0 ->
							case data_pet_skill:get(PetSkillId) of
								[] ->
									BattleDict;
								PetSkillData ->
									spawn(fun()-> pet_fight_action(Player, DerInit, Aer, Der, DerBattleResult, PetSkillData, Now, FromType) end),
									LastPetSkillTime = Now + PetSkillData#ets_pet_skill.cd,
									NewPetSkillTime = 
										case lists:keyfind(PetSkillId, 1, PetSkillTime) of
											false ->
												[{PetSkillId, LastPetSkillTime} | PetSkillTime];
											_ ->
												lists:keyreplace(PetSkillId, 1, PetSkillTime, {PetSkillId, LastPetSkillTime})
										end,
									BattleDict#battle_dict{
										pet_skill_time = NewPetSkillTime									   
									}
							end;
						true ->
							BattleDict
					end
			end;
		true ->
			BattleDict	
	end.


%% 宠物战斗逻辑运算
pet_fight_action(Player, DerInit, Aer, Der, DerBattleResult, PetSkillData, Now, FromType) ->
	{DerHurt, DerHp} = get_der_hurt(DerBattleResult, Der),
	if
		DerHp > 0 andalso DerHurt > 0 ->
			case PetSkillData#ets_pet_skill.type of
				%% 重击
				att ->
					pet_skill_att(Aer, Der, PetSkillData, DerHurt, DerHp, FromType);
				%% 破甲
				break ->
					pet_skill_break(Aer, Der, PetSkillData, DerHp, Now);
				%% 击退
				back ->
					pet_skill_back(Aer, Der, PetSkillData, DerHurt, DerHp, FromType);
				%% 神火怒焰
				flame ->
					pet_skill_flame(Player, Der, PetSkillData, DerHurt, FromType);
				%% 吸血
				bleed ->
					pet_skill_bleed(Aer, Der, PetSkillData, DerHurt, DerHp);
				%% 定身
				freeze ->
					case check_anti_pet_skill(DerInit, Aer, Der, anti_freeze, Now) of
						false ->
							pet_skill_freeze(Aer, Der, PetSkillData, DerHp, Now);
						_ ->
							skip
					end;
				%% 击晕
				dizzy ->
					case check_anti_pet_skill(DerInit, Aer, Der, anti_dizzy, Now) of
						false ->
							pet_skill_dizzy(Aer, Der, PetSkillData, DerHp, Now);
						_ ->
							skip
					end;
				%% 沉默
				silence ->
					case check_anti_pet_skill(DerInit, Aer, Der, anti_silence, Now) of
						false ->
							pet_skill_silence(Aer, Der, PetSkillData, DerHp, Now);
						_ ->
							skip
					end;
				%% 减速
				slow ->
					case check_anti_pet_skill(DerInit, Aer, Der, anti_slow, Now) of
						false ->
							pet_skill_slow(DerInit, Aer, Der, PetSkillData, DerHp, Now);
						_ ->
							skip
					end;
				%% 虚弱
				weak ->
					pet_skill_weak(Aer, Der, PetSkillData, DerHp, Now);
				%% 割伤
				cut ->
					pet_skill_cut(Aer, Der, PetSkillData, DerHurt, DerHp);
				_ ->
					skip
			end;
		true ->
			skip
	end.


%% 宠物重击技能
pet_skill_att(Aer, Der, PetSkill, DerHurt, DerHp, FromType) ->
	Hurt = round(DerHurt * PetSkill#ets_pet_skill.hurt_rate + PetSkill#ets_pet_skill.hurt),
	pet_hurt(Aer, Der, PetSkill, DerHp, Hurt, FromType).

%% 破甲
pet_skill_break(Aer, Der, PetSkill, DerHp, Now) ->
	case PetSkill#ets_pet_skill.data of
		[LastTime, Val] ->
			Buff = Der#battle_state.battle_status,
			BuffInfo = {last_def, Val, Now + trunc(LastTime / 1000), PetSkill#ets_pet_skill.id, PetSkill#ets_pet_skill.lv},
			NewBuff = 	
				case lists:keyfind(last_def, 1, Buff) of
					false ->
						[BuffInfo | Buff];
					_ ->
						lists:keyreplace(last_def, 1, Buff, BuffInfo)
				end,
			if
				Der#battle_state.sign == 2 ->
					Der#battle_state.pid ! {'SET_BATTLE_STATUS', {4, [NewBuff]}};
                true ->
               		Der#battle_state.pid ! {'SET_MON_BUFF', NewBuff} 
            end,
			send_pet_battle_msg(Aer, Der, PetSkill, DerHp, 0);
		_ ->
			skip
	end.

%% 击退
pet_skill_back(Aer, Der, PetSkill, DerHurt, DerHp, FromType) ->
	case PetSkill#ets_pet_skill.data of
		[Area] ->
			[BX, BY] = lib_battle:get_battle_coordinate(Aer#battle_state.x, Aer#battle_state.y, Der#battle_state.x, Der#battle_state.y, -Area),
			case lib_scene:is_blocked(Aer#battle_state.scene, [BX, BY]) of
				true ->
					#battle_state{
						id = DerId,
						scene = DerScene,
						sign = DerSign,
						pid = DerPid	  
					} = Der,
					if
						DerSign == 1 ->
							DerPid ! {'MON_POSITION', BX, BY};
						true ->
							DerPid ! {'SET_PLAYER', [{x, BX}, {y, BY}]}
					end,
					{ok, BinData} =  pt_12:write(12110, [DerSign, DerId, BX, BY, 2]),
					mod_scene_agent:send_to_area_scene(DerScene, BX, BY, BinData);
				false ->
					skip
			end;
		_ ->
			skip
	end,
	Hurt = round(DerHurt * PetSkill#ets_pet_skill.hurt_rate),
	pet_hurt(Aer, Der, PetSkill, DerHp, Hurt, FromType).

%% 神火怒焰
pet_skill_flame(Player, Der, PetSkill, DerHurt, FromType) ->
	case PetSkill#ets_pet_skill.data of
		[AttArea] ->
			Hurt = round(DerHurt * PetSkill#ets_pet_skill.hurt_rate + PetSkill#ets_pet_skill.hurt),
			if 
				FromType == 1 ->
					pet_skill_flame_action(Player, PetSkill, Der#battle_state.scene, Der#battle_state.x, Der#battle_state.y, Hurt, AttArea);
				true ->
					ScenePid = mod_scene:get_scene_pid(Der#battle_state.scene, undefined, undefined),
					gen_server:cast(ScenePid,
		                {apply_asyn_cast, lib_pet_battle, pet_skill_flame_action, [Player, PetSkill, Der#battle_state.scene, Der#battle_state.x, Der#battle_state.y, Hurt, AttArea]})
			end;
		_ ->
			skip
	end.

%% 吸血
pet_skill_bleed(Aer, Der, PetSkill, DerHurt, DerHp) ->
	AddHp = round(DerHurt * PetSkill#ets_pet_skill.hurt_rate),
	#battle_state{
		id = AerId,
		hp = AerHp,
		hp_lim = AerHpLim,
		mp = AerMp,
		x = X,
		y = Y,
		scene = Scene,
		pid = AerPid	  
	} = Aer,
	NewAerHp = AerHp + AddHp,
	NewAerHp1 = 
		if
			NewAerHp > AerHpLim ->
				AerHpLim;
			true ->
				NewAerHp
		end,
	AerPid ! {'PLAYER_BATTLE_RESULT', [NewAerHp1, AerMp, 0, 0, 0, 0, 0, Scene]},
	%% 广播给附近玩家
	{ok, BinData12009} = pt_12:write(12009, [AerId, NewAerHp1, AerHpLim]),
	mod_scene_agent:send_to_area_scene(Scene, X, Y, BinData12009),
	%% 发送宠物战斗信息
	send_pet_battle_msg(Aer, Der, PetSkill, DerHp, 0).

%% 定身
pet_skill_freeze(Aer, Der, PetSkill, DerHp, Now) ->
	lib_battle:update_battle_limit(Der, PetSkill#ets_pet_skill.lastime, 1, stand, 0, 10043, PetSkill#ets_pet_skill.lv, Now),
	send_pet_battle_msg(Aer, Der, PetSkill, DerHp, 0).

%% 击晕 
pet_skill_dizzy(Aer, Der, PetSkill, DerHp, Now) ->
	lib_battle:update_battle_limit(Der, PetSkill#ets_pet_skill.lastime, 2, dizzy, 0, 10043, PetSkill#ets_pet_skill.lv, Now),
	send_pet_battle_msg(Aer, Der, PetSkill, DerHp, 0).

%% 沉默
pet_skill_silence(Aer, Der, PetSkill, DerHp, Now) ->
	lib_battle:update_battle_limit(Der, PetSkill#ets_pet_skill.lastime, 3, silence, 0, 10045, PetSkill#ets_pet_skill.lv, Now),
	send_pet_battle_msg(Aer, Der, PetSkill, DerHp, 0).

%% 减速
pet_skill_slow(DerInit, Aer, Der, PetSkill, DerHp, Now) ->
	case PetSkill#ets_pet_skill.data of
		[Val] ->
			lib_battle:battle_speed(Der, DerInit, PetSkill#ets_pet_skill.lastime, -Val, 25405, PetSkill#ets_pet_skill.lv, Now),
			send_pet_battle_msg(Aer, Der, PetSkill, DerHp, 0);
		_ ->
			skip
	end.

%% 虚弱
pet_skill_weak(Aer, Der, PetSkill, DerHp, Now) ->
	case PetSkill#ets_pet_skill.data of
		[LastTime, Val] ->
			#battle_state{
				sign = DerSign,
				battle_status = Buff,
				pid = DerPid	  
			} = Der,
			BuffInfo = {att_der, -Val, Now + trunc(LastTime / 1000), 10029, PetSkill#ets_pet_skill.lv},
			NewBuff = 	
				case lists:keyfind(att_der, 1, Buff) of
					false ->
						[BuffInfo | Buff];
					_ ->
						lists:keyreplace(att_der, 1, Buff, BuffInfo)
				end,
			if
				DerSign == 2 ->
					DerPid ! {'SET_BATTLE_STATUS', {4, [NewBuff]}};
                true ->
               		DerPid ! {'SET_MON_BUFF', NewBuff} 
            end,
			send_pet_battle_msg(Aer, Der, PetSkill, DerHp, 0);
		_ ->
			skip
	end.

%% 割伤
pet_skill_cut(Aer, Der, PetSkill, DerHurt, DerHp) ->
	case PetSkill#ets_pet_skill.data of
		[LastTime] ->
			Hurt = round(DerHurt * PetSkill#ets_pet_skill.hurt_rate + PetSkill#ets_pet_skill.hurt),
			lib_battle:battle_drug(Aer, Der, trunc(LastTime / 1000), Hurt),
			send_pet_battle_msg(Aer, Der, PetSkill, DerHp, 0);
		_ ->
			skip
	end.

%% 宠物伤害
pet_hurt(Aer, Der, PetSkill, DerHp, Hurt, FromType) ->
	NewDerHp = 
		if
			DerHp > Hurt ->
				DerHp - Hurt;
			true ->
				0
		end,
	if 
		FromType == 1 ->
			mod_battle:update_der_hp(Der, Aer, NewDerHp, Der#battle_state.mp, Hurt);
		true ->
			ScenePid = mod_scene:get_scene_pid(Aer#battle_state.scene, undefined, undefined),
			gen_server:cast(ScenePid,
                {apply_asyn_cast, mod_battle, update_der_hp, [Der, Aer, NewDerHp, Der#battle_state.mp, Hurt]})
	end,
	send_pet_battle_msg(Aer, Der, PetSkill, NewDerHp, Hurt).

%% 获取被击方的伤害
get_der_hurt([], _Der) ->
	{0, 0};
get_der_hurt([[DerSign, DerId, DerHp, _DerMp, Hurt, _MpHurt, _Sta] | R], Der) ->
	if
		Der#battle_state.sign == DerSign andalso Der#battle_state.id == DerId ->
			{Hurt, DerHp};
		true ->
			get_der_hurt(R, Der)
	end.

%% 神火怒焰
pet_skill_flame_action(Player, PetSkill, SceneId, X, Y, Hurt, AttArea) ->
	X1 = X + AttArea,
	X2 = X - AttArea,
	Y1 = Y + AttArea,
	Y2 = Y - AttArea,
	%% 神火怒焰人物
	AllUser = get_scene_user_for_pet_skill_flame(Player#player.id, SceneId, X1, X2, Y1, Y2),
	NewAllUser = get_valid_user_for_pet_skill_flame(AllUser, Player#player.other#player_other.pid_team, Player#player.other#player_other.leader, []),
	BattleResult = pet_skill_flame_player_loop(NewAllUser, Player, Hurt, []),
	%% 神火怒焰怪物
	AllMon = get_scene_mon_for_pet_skill_flame(SceneId, X1, X2, Y1, Y2),
	NewBattleResult = pet_skill_flame_mon_loop(AllMon, Player, Hurt, BattleResult),
	{ok, BinData} = pt_20:write(20013, [Player#player.id, PetSkill#ets_pet_skill.id, NewBattleResult]),
	lib_send:send_to_online_scene(SceneId, X, Y, BinData).
%% 神火怒焰人物计算
pet_skill_flame_player_loop([], _Aer, _Hurt, Ret) ->
	Ret;
pet_skill_flame_player_loop([{PlayerId, Hp, Mp, Pid, _PidTeam, _Leader} | U], Aer, Hurt, Ret) ->
    NewHp = 
		if
       		Hp > Hurt ->
                Hp - Hurt;
            true ->
                0
        end,
    MsgList = [
        NewHp,
        Mp,
        Aer#player.other#player_other.pid,
        Aer#player.id,
        Aer#player.nickname,
        Aer#player.career,
        Aer#player.realm,
		Aer#player.scene
    ],
    Pid ! {'PLAYER_BATTLE_RESULT', MsgList},
	lib_scene:update_player_info_fields_for_battle(PlayerId, NewHp, Mp),
    pet_skill_flame_player_loop(U, Aer, Hurt, [{2, PlayerId, NewHp, Hurt} | Ret]).
get_scene_user_for_pet_skill_flame(AerId, SceneId, X1, X2, Y1, Y2) ->
	MS = ets:fun2ms(fun(P) when P#player.scene == SceneId, P#player.hp > 0, 
									P#player.id /= AerId, P#player.x >= X2, P#player.x =< X1,  
									P#player.y >= Y2, P#player.y =< Y1, 
									P#player.other#player_other.battle_limit /= 9 ->
	    {
            P#player.id,
            P#player.hp,
            P#player.mp,
            P#player.other#player_other.pid,
			P#player.other#player_other.pid_team,
			P#player.other#player_other.leader
	    }
	end),
	ets:select(?ETS_ONLINE_SCENE, MS).
get_valid_user_for_pet_skill_flame([], _AerPidTeam, _AerLeader, User) ->
	User;
get_valid_user_for_pet_skill_flame([{PlayerId, Hp, Mp, Pid, PidTeam, Leader} | U], AerPidTeam, AerLeader, User) ->
	if
		PidTeam /= undefined andalso PidTeam == AerPidTeam ->
			get_valid_user_for_pet_skill_flame(U, AerPidTeam, AerLeader, User);
		true ->
			if
				Leader /= 0 andalso Leader /= 1 andalso Leader == AerLeader ->
					get_valid_user_for_pet_skill_flame(U, AerPidTeam, AerLeader, User);
				true ->
					get_valid_user_for_pet_skill_flame(U, AerPidTeam, AerLeader, [{PlayerId, Hp, Mp, Pid, PidTeam, Leader} | User])
			end
	end.


%% 神火怒焰怪物计算
pet_skill_flame_mon_loop([], _Aer, _Hurt, Ret) ->
	Ret;
pet_skill_flame_mon_loop([[MonId, MonHp, MonType, MonPid] | P], Aer, Hurt, Ret) ->
    NewMonHp = 
		if
       		MonHp > Hurt ->
                MonHp - Hurt;
            true ->
                0
        end,
	case lib_mon:is_boss_mon(MonType) of
   		false ->
			MonPid ! {'MON_BATTLE_RESULT', [NewMonHp, Aer#player.id, Aer#player.other#player_other.pid, Aer#player.career]};
    	%% BOSS怪
   		true ->
			MsgList = [
		        NewMonHp,
		        Aer#player.id,
				Aer#player.nickname,
		        Aer#player.other#player_other.pid,
				0,
				Aer#player.other#player_other.pid_team,
				2
		    ],
			MonPid ! {'MON_BOSS_BATTLE_RESULT', MsgList}
   	end,
    pet_skill_flame_mon_loop(P, Aer, Hurt, [{1, MonId, NewMonHp, Hurt} | Ret]).
get_scene_mon_for_pet_skill_flame(SceneId, X1, X2, Y1, Y2) ->
	MS = ets:fun2ms(fun(M) when M#ets_mon.scene == SceneId, M#ets_mon.hp > 0, 
									M#ets_mon.x >= X2, M#ets_mon.x =< X1,  
									M#ets_mon.y >= Y2, M#ets_mon.y =< Y1,
									M#ets_mon.type /= 100, M#ets_mon.type /= 101 ->
	    [
            M#ets_mon.id,
            M#ets_mon.hp,
            M#ets_mon.type,
            M#ets_mon.pid
	    ]
	end),
	ets:select(?ETS_SCENE_MON, MS).


%% 发送宠物战斗信息
send_pet_battle_msg(Aer, Der, PetSkill, DerHp, Hurt) ->
	#battle_state{
		id = DerId,
		sign = DerSign
	} = Der,
	DerList = [{DerSign, DerId, DerHp, Hurt}],
	#battle_state{
		id = AerId,
		scene = Scene,
		x = X,
		y = Y		  
	} = Aer,
	{ok, BinData} = pt_20:write(20013, [AerId, PetSkill#ets_pet_skill.id, DerList]),
	mod_scene_agent:send_to_area_scene(Scene, X, Y, BinData).
	

%% 获取灵兽技能ID
get_pet_skill_id(PetBattSkill, PetSkillTime, Now) ->
	{Rate, PetSkillList} = get_pet_skill_list(PetBattSkill, PetSkillTime, Now, 0, []),
	if
		Rate > 0 ->
			Rank = 
				if
					Rate > 100 ->
						random:uniform(Rate);
					true ->
						random:uniform(100)
				end,
			get_pet_skill_id_loop(PetSkillList, Rank, 0);
		true ->
			0
	end.
get_pet_skill_id_loop([], _Rank, _RateStart) ->
	0;
get_pet_skill_id_loop([{PetSkillId, Rate} | S], Rank, RateStart) ->
	RateEnd = RateStart + Rate,
%% 	RateEnd = RateStart + 80,
	if
		Rank > RateStart andalso Rank =< RateEnd ->
			PetSkillId;
		true ->
			get_pet_skill_id_loop(S, Rank, RateEnd)
	end.
	
get_pet_skill_list([], _PetSkillTime, _Now, Rate, PetSkillList) ->
	{Rate, PetSkillList};
get_pet_skill_list([{_PetSkillKey, PetSkillId, Rate} | S], PetSkillTime, Now, R, PetSkillList) ->
	case check_pet_skill_cd(PetSkillTime, PetSkillId, Now) of
		true ->
			get_pet_skill_list(S, PetSkillTime, Now, R + Rate, [{PetSkillId, Rate} | PetSkillList]);
		false ->
			get_pet_skill_list(S, PetSkillTime, Now, R, PetSkillList)
	end.


%% 判断宠物技能CD
check_pet_skill_cd(PetSkillTime, PetSkillId, Now) ->
	case lists:keyfind(PetSkillId, 1, PetSkillTime) of
		{_PetSkillId, LastTime} ->
			if
				Now >= LastTime ->
					true;
				true ->
					false
			end;
		_ ->
			true
	end.

%% 判断反抗技能是否有效
check_anti_pet_skill(DerInit, Aer, Der, PetSkillKey, Now) ->
	if
		Der#battle_state.sign =/= 2 ->
			false;
		true ->
			case DerInit#player.other#player_other.pet_batt_skill of
				[] ->
					false;
				PetBattSkill ->
					case lists:keyfind(PetSkillKey, 1, PetBattSkill) of
						{_PetSkillKey, PetSkillId, PetSkillRate} ->
							%% 产生随机种子
							random:seed(now()),
							Rand = random:uniform(100),
							if
								Rand > PetSkillRate ->
									false;
								true ->
									case data_pet_skill:get(PetSkillId) of
										[] ->
											false;
										PetSkillData ->
											send_pet_battle_msg(Der, Aer, PetSkillData, Aer#battle_state.hp, 0),
											BattleDict = DerInit#player.other#player_other.battle_dict,
											PetSkillTime = BattleDict#battle_dict.pet_skill_time,
											NewPetSkillTime = 
												case lists:keyfind(PetSkillId, 1, PetSkillTime) of
													false ->
														[{PetSkillId, Now} | PetSkillTime];
													_ ->
														lists:keyreplace(PetSkillId, 1, PetSkillTime, {PetSkillId, Now})
												end,
											NewBattleDict = BattleDict#battle_dict{
												pet_skill_time = NewPetSkillTime									   
											},
											gen_server:cast(Der#battle_state.pid, {'SET_PLAYER', [{battle_dict, NewBattleDict}]})
									end
							end;
						_ ->
							false
					end
			end	
	end.

