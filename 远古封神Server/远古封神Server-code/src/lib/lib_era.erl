%% Author: zj
%% Created: 2012-2-28
%% Description: 封神纪元
-module(lib_era).
 
%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-define(TIMELIMIT,1800).
%%
%% Exported Functions
%%
-compile(export_all).

%%
%% API Functions
%%
%% 35010 封神纪元tooltip显示
get_player_era_tooltip(Player,TargetPlayerId) ->
	PlayerId = Player#player.id,
	if
		PlayerId == TargetPlayerId ->
			case get_player_era_info(PlayerId) of
				[] ->
					[PlayerId,0,0,0,0,0,0,0];
				EraInfo ->
					[Attack,Hp,Mp,Def,AntiAll] = get_player_era_attribute(PlayerId),
					Stage = find_max_over_stage(EraInfo#ets_fs_era.prize),
					[Lv,_T] = find_max_levelTime(EraInfo#ets_fs_era.lv_info,Stage),
					[PlayerId,Stage,Lv,Attack,Hp,Mp,Def,AntiAll]
			end;
		true ->
			case lib_player:get_online_info_fields(TargetPlayerId, [pid]) of
				Pid when is_pid(Pid) ->
					gen_server:call(Pid, '{GET_PLAYER_ERA_TOOLTIP}');
				_ ->
					[TargetPlayerId,0,0,0,0,0,0,0]
			end
	end.

%% 35011 封神纪元通关信息
%% 通关信息lv_info = [{stage,level,time}]
%% 通关奖励信息prize = [{stage,Cp,Bp,Ap,Sp,SSp,SSSp}]
%% [PlayerId,Stage,MaxStage,BV,PetBV,MountBV,TimeLimit,RBV,RpetBV,RmountBV,MaxLv,PassTime,Toper,TopTime,
%%			 PrizeInfo,
%%			 StagePrizeInfo,AttributeInfo]
get_player_era_stage_info(Player,TargetPlayerId,Stage) ->
	PlayerId = Player#player.id,
	if
		TargetPlayerId == PlayerId ->
			EraInfo = 
				case get_player_era_info(PlayerId) of
					[] ->
						if
							Player#player.lv >= 25 ->
								add_player_era_info(PlayerId);
							true ->
								[]
						end;
					EraEts ->
						EraEts
				end,
			case EraInfo of
				[] ->
					[];
				_ ->
					MaxStage = find_max_stage(EraInfo#ets_fs_era.lv_info),
					BattleValueList = Player#player.other#player_other.batt_value,
					BattleValue = lib_player:count_value(BattleValueList),
					PetBV = get_battle_val(BattleValueList,pet),
					MountBV = get_battle_val(BattleValueList,mount),
					TimeLimit = ?TIMELIMIT,
					[RBattleValue,RPetBV,RMountBV] = data_era:recommend_battle_val(Stage),
					[Level,PassTime]= find_max_levelTime(EraInfo#ets_fs_era.lv_info,Stage),
					[Toper,TopPassTime] = get_era_top(Stage),
					[Cp,Bp,Ap,Sp,SSp,SSSp] = find_stage_prize(EraInfo#ets_fs_era.prize,Stage),
					FP = fun(L) ->
								 P = data_era:get_level_prize(Stage, L),
								 [L|P]
						 end,
					FPlist = lists:map(FP, [1,2,3,4,5,6]),
					AddAttribute = data_era:stage_add_attribute(Stage),
					[PlayerId,Stage,MaxStage,BattleValue,PetBV,MountBV,TimeLimit,RBattleValue,RPetBV,RMountBV,Level,PassTime,Toper,TopPassTime,
					 [Cp,Bp,Ap,Sp,SSp,SSSp],
					 FPlist,AddAttribute]
			end;
		true ->
			[]
	end.

%%获取战斗力
get_battle_val(Battle_val_list,Type) ->
	case Type of
		player ->
			Target = 1;
		pet ->
			Target = 7;
		mount ->
			Target = 9;
		_ ->
			Target = 1
	end,	
	F_filter = fun([T,V],Val) ->
					if
						T == Target ->
							V;
						true ->
							Val
					end
			   end,
	lists:foldl(F_filter, 0, Battle_val_list).

%%根据玩家ID 查询通关信息里面的最高关数(这里指可以进的关卡数)
find_max_stage_by_playerid(PlayerId) ->
	case get_player_era_info(PlayerId) of
		[] ->
			30;
		EraInfo ->
			find_max_stage(EraInfo#ets_fs_era.lv_info)
	end.

%%查询通关信息里面的最高关数(这里指可以进的关卡数)
find_max_stage(LvInfo) ->
	case LvInfo of
		[] -> 
			30;
		_ ->
			F = fun({Stage,_Level,_Time},Val) ->
						if
							Stage > Val ->
								Stage ;
							true ->
								Val
						end
				end,
			lists:foldl(F, 30, LvInfo)
	end.

%% 查询已经通关的最高关卡数
find_max_over_stage(Prize) ->
	case Prize of
		[] ->
			0;
		_ ->
			F = fun({Stage,_Cp,_Bp,_Ap,_Sp,_SSp,_SSSp},Val) ->
						if
							Stage > Val ->
								Stage;
							true ->
								Val
						end
				end,
			lists:foldl(F, 0, Prize)
	end.

%%查询关数的最高评价和通过时间 [Level,Time]
find_max_levelTime(LvInfo,Stage) ->
	case LvInfo of
		[] -> 
			[0,0];
		_ ->
			case lists:keyfind(Stage, 1, LvInfo) of
				{_Stage,Level,Time} ->
					[Level,Time];
				_ ->
					[0,0]
			end
	end.
%%获取关卡通过奖励信息
find_stage_prize(PrizeInfo,Stage) ->
	case PrizeInfo of
		[] ->
			[0,0,0,0,0,0];
		_ ->
			case lists:keyfind(Stage, 1, PrizeInfo) of
				{_Stage,Cp,Bp,Ap,Sp,SSp,SSSp} ->
					[Cp,Bp,Ap,Sp,SSp,SSSp];
				_ ->
					[0,0,0,0,0,0]
			end
	end.

%% 35014 领取奖励
get_player_era_prize(Player,Stage,Level) ->
	PlayerId = Player#player.id,
	case get_player_era_info(PlayerId) of
		[] ->
			[Player,[Stage,Level,0]];
		EraInfo ->
			case find_stage_prize(EraInfo#ets_fs_era.prize, Stage) of
				[0,0,0,0,0,0] -> %%没有通关
					[Player,[Stage,Level,2]];
				[Cp,Bp,Ap,Sp,SSp,SSSp] ->
					case Level of
						1 ->
							if
								Cp == 0 ->
									Code = -1;
								Cp == 2 ->
									Code = -2;
								true ->
									Code = 1
							end;
						2 ->
							if
								Bp == 0 ->
									Code = -1;
								Bp == 2 ->
									Code = -2;
								true ->
									Code = 1
							end;
						3 ->
							if
								Ap == 0 ->
									Code = -1;
								Ap == 2 ->
									Code = -2;
								true ->
									Code = 1
							end;
						4 ->
							if
								Sp == 0 ->
									Code = -1;
								Sp == 2 ->
									Code = -2;
								true ->
									Code = 1
							end;
						5 ->
							if
								SSp == 0 ->
									Code = -1;
								SSp == 2 ->
									Code = -2;
								true ->
									Code = 1
							end;
						6 ->
							if
								SSSp == 0 ->
									Code = -1;
								SSSp == 2->
									Code = -2;
								true ->
									Code = 1
							end;
						_ ->
							Code = -1
					end,
					if
%% 						Stage == 30 andalso Level > 2 andalso Player#player.lv < 30 ->
%% 							[Player,[Stage,Level,6]];%% 新手不能领取
						Code == -1 ->
							[Player,[Stage,Level,3]];%% 级别还没达到
						Code == -2->
							[Player,[Stage,Level,4]];%%奖励已经领取
						true ->
							NewEraInfo = update_player_era_prize_info(PlayerId,Stage,Level,2),
							[Exp,Spi,Cul,Bcoin,GoodsType,GoodsNum] = data_era:get_level_prize(Stage, Level),
							if
								Exp > 0 orelse Spi > 0 ->
									Player2 = lib_player:add_exp(Player, Exp, Spi, 24);
								true ->
									Player2 = Player
							end,
							if
								Cul > 0 ->
									Player3 = lib_player:add_culture(Player2, Cul);
								true ->
									Player3 = Player2
							end,
							if
								Bcoin > 0 ->
									Player4 = lib_goods:add_money(Player3, Bcoin, bcoin, 3920);
								true ->
									Player4 = Player3
							end,
							if
								GoodsType > 0 ->
									case length(gen_server:call(Player4#player.other#player_other.pid_goods,{'null_cell'})) > 0 of
										true ->
											gen_server:call(Player#player.other#player_other.pid_goods, {'give_goods', Player4,GoodsType, GoodsNum, 2});
										_ ->
											Msg0 = "您的背包已满，返回领取奖励物品。",
											spawn(fun()->lib_goods:add_new_goods_by_mail(Player#player.nickname,GoodsType,2,GoodsNum,"系统消息",Msg0)end)
									end;
								true ->
									skip
							end,
							lib_player:send_player_attribute(Player4, 2),
							if
								Level == 1 ->
									Player5 = get_stage_attribute(Player4,Stage,NewEraInfo);
								Level == 2 ->
									open_next_stage(PlayerId,NewEraInfo),
									Player5 = Player4;
								true ->
									Player5 = Player4
							end,
							[Player5,[Stage,Level,1]]
					end
			end
	end.

%%添加玩家封神纪元信息
add_player_era_info(PlayerId) ->
	case get_player_era_info(PlayerId) of
		[] ->
			Keys = [player_id,attack,hp,mp,def,anti_all,lv_info,prize],
			LvInfo = util:term_to_string([]),
			PrizeInfo = util:term_to_string([]),
			Values = [PlayerId,0,0,0,0,0,LvInfo,PrizeInfo],
			db_agent:add_player_era_info(Keys, Values),
			Fs_era = #ets_fs_era{player_id = PlayerId,
								 attack = 0,
								 hp = 0,
								 mp = 0,
								 def = 0,
								 anti_all = 0,
								 lv_info = [],
								 prize = []
								 },
			update_player_era_ets(Fs_era),
			Fs_era;
		Fs_eraInfo ->
			Fs_eraInfo
	end.

update_player_era_ets(FsEraInfo) ->
	ets:insert(?ETS_FS_ERA, FsEraInfo).
	
%%初始化玩家封神纪元信息
init_player_era_info(PlayerId) ->
	F = fun(Era) ->
				EraInfo = list_to_tuple([ets_fs_era] ++ Era),
				LvInfo = util:string_to_term(tool:to_list(EraInfo#ets_fs_era.lv_info)),
				Prize = util:string_to_term(tool:to_list(EraInfo#ets_fs_era.prize)),
				NewEraData = EraInfo#ets_fs_era{lv_info = LvInfo,prize = Prize},
                ets:insert(?ETS_FS_ERA, NewEraData) 
         end,
    case db_agent:load_player_era_info(PlayerId) of
        [] -> 
			skip;
        EraData when is_list(EraData) ->
            F(EraData);
        _ -> skip
    end.

%% 更新玩家闯关记录信息
%% PlayerId 玩家ID
%% Stage 关卡数
%% Level 通关评价等级 1-6
%% Time 通关时间 秒
%% State 通关奖励状态 为0时不做更新，用于开启下一关卡
update_player_era_info(PlayerId,Nickname,Stage,Level,Time,State) ->
	case get_player_era_info(PlayerId) of
		[] ->
			[];
		EraInfo ->
			%%更新通关信息
			LvInfo = EraInfo#ets_fs_era.lv_info,
			case LvInfo of
				[] ->
					NewInfo = [{Stage,Level,Time}];
				 _  ->
					case lists:keyfind(Stage, 1, LvInfo) of
						{_stage,Olevel,Otime} ->
							if
								Olevel < Level andalso Otime > Time ->
									NewInfo = lists:keyreplace(Stage, 1, LvInfo, {Stage,Level,Time});
								Olevel < Level ->
									NewInfo = lists:keyreplace(Stage, 1, LvInfo, {Stage,Level,Otime});
								Otime > Time  ->
									NewInfo = lists:keyreplace(Stage, 1, LvInfo, {Stage,Olevel,Time});
								true ->
									NewInfo = LvInfo
							end;
						_ ->
							NewInfo = [{Stage,Level,Time}|LvInfo]
					end
			end,
			Prize = EraInfo#ets_fs_era.prize,
			if
				State /=  0 ->
					%%更新通关奖励信息
					F_mod = fun(N,CurPrize) ->
								{_Stage,C,B,A,S,SS,SSS} = CurPrize ,
									case N of
										1 when C == 0 -> {_Stage,State,B,A,S,SS,SSS};
										2 when B == 0 -> {_Stage,C,State,A,S,SS,SSS};
										3 when A == 0 -> {_Stage,C,B,State,S,SS,SSS};
										4 when S == 0 -> {_Stage,C,B,A,State,SS,SSS};
										5 when SS == 0-> {_Stage,C,B,A,S,State,SSS};
										6 when SSS == 0 -> {_Stage,C,B,A,S,SS,State};
										_ -> {_Stage,C,B,A,S,SS,SSS}
									end
						end,
					case Prize of
						[] ->
							NewPrize = [lists:foldl(F_mod, {Stage,0,0,0,0,0,0}, lists:seq(1, Level))];
						_ ->
							case lists:keyfind(Stage, 1, Prize) of
								{_Stage,Cp,Bp,Ap,Sp,SSp,SSSp} ->
									StagePrize = lists:foldl(F_mod, {_Stage,Cp,Bp,Ap,Sp,SSp,SSSp}, lists:seq(1, Level)),
									NewPrize = lists:keyreplace(Stage, 1, Prize, StagePrize);
								_ ->
									StagePrize = lists:foldl(F_mod, {Stage,0,0,0,0,0,0}, lists:seq(1, Level)),
									NewPrize = [StagePrize|Prize]
							end
					end;
				true ->
					NewPrize = Prize
			end,
			%%更新记录
			if
				State /= 0 ->
					update_era_top(PlayerId,Nickname,Stage,Time);
				true ->
					skip
			end,				
			%%更新erainfo
			NewEraInfo = EraInfo#ets_fs_era{lv_info = NewInfo,prize = NewPrize},
			update_player_era_ets(NewEraInfo),
			db_agent:update_player_era_info(PlayerId,util:term_to_string(NewInfo), util:term_to_string(NewPrize)),
			NewEraInfo
	end.

%% 获取玩家最高通关记录
get_era_top(Stage) ->
	Key = {lib_era,era_top,Stage},
	case mod_cache:g_get(Key) of
		[_PlayerId,Nickname,Time] ->
			[Nickname,Time];
		_ ->
			case db_agent:get_era_top_player(Stage) of
				[] ->
					["无",0];
				[OplayerId,Onickname,Otime] ->
					mod_cache:g_set(Key, [OplayerId,Onickname,Otime], 6 * 3600),
					[Onickname,Otime]
			end
	end.
		
%%更新玩家记录
update_era_top(PlayerId,Nickname,Stage,Time) ->
	Key = {lib_era,era_top,Stage},
	case mod_cache:g_get(Key) of
		[] ->
			case db_agent:get_era_top_player(Stage) of
				[] ->
					mod_cache:g_set(Key, [PlayerId,Nickname,Time], 6 * 3600),
					db_agent:insert_era_top_player(PlayerId, Nickname, Stage, Time);
				[OplayerId,_Onickname,Otime] ->
					update_era_top_info(OplayerId,Otime,PlayerId,Nickname,Stage,Time)
			end;
		[CplayerId,_Cnickname,Ctime] ->
			update_era_top_info(CplayerId,Ctime,PlayerId,Nickname,Stage,Time);
		_ ->
			skip
	end.
%%OplayerId 记录玩家id
%%Otime 记录时间
%%PlayerId 当前玩家id
%%Nickname 当前玩家昵称
%%Stage 关卡
%%NewTime 当前时间 
update_era_top_info(OplayerId,Otime,PlayerId,Nickname,Stage,NewTime) ->
	Key = {lib_era,era_top,Stage},
	if
		PlayerId == OplayerId ->
			if
				NewTime < Otime ->
					mod_cache:g_set(Key, [PlayerId,Nickname,NewTime], 6 * 3600),
					db_agent:update_era_top_player(PlayerId, Stage, NewTime);
				true ->
					skip
			end;
		true ->
			if
				NewTime < Otime ->
					mod_cache:g_set(Key, [PlayerId,Nickname,NewTime], 6 * 3600),
					db_agent:update_era_top_player(PlayerId, Nickname, Stage, NewTime);
				true ->
					skip
			end
	end.
	
%%更新玩家奖励信息
%%PlayerId 玩家ID
%%Stage 关卡数
%%Plv 通关评价等级
%%state 0不可领取 1 可领取 2已领取
update_player_era_prize_info(PlayerId,Stage,Plv,State) ->
	case get_player_era_info(PlayerId) of
		[] ->
			[];
		EraInfo ->
			Prize = EraInfo#ets_fs_era.prize,
			case Prize of
				[] ->
					NewPrize = [init_order_prize(Stage,Plv,State)];
				_ ->
					case lists:keyfind(Stage, 1, Prize) of
						{_Stage,Cp,Bp,Ap,Sp,SSp,SSSp} ->
							StagePrize = update_order_prize(Plv,State,{Stage,Cp,Bp,Ap,Sp,SSp,SSSp}),
							NewPrize = lists:keyreplace(Stage, 1, Prize, StagePrize);
						_ ->
							StagePrize = init_order_prize(Stage,Plv,State),
							NewPrize = [StagePrize|Prize]
					end						
			end,
			NewEraInfo = EraInfo#ets_fs_era{prize = NewPrize},
			update_player_era_ets(NewEraInfo),
			if
				Prize /= NewPrize ->								
					db_agent:update_player_era_prize(PlayerId,util:term_to_string(NewPrize));
				true ->
					skip
			end,
			NewEraInfo
	end.
update_order_prize(Plv,State,PrizeTuple) ->
	{Stage,Cp,Bp,Ap,Sp,SSp,SSSp} = PrizeTuple,
	case Plv of
		1 ->
			{Stage,state_choose(Cp,State),Bp,Ap,Sp,SSp,SSSp};
		2 ->
			{Stage,Cp,state_choose(Bp,State),Ap,Sp,SSp,SSSp};
		3 ->
			{Stage,Cp,Bp,state_choose(Ap,State),Sp,SSp,SSSp};
		4 ->
			{Stage,Cp,Bp,Ap,state_choose(Sp,State),SSp,SSSp};
		5 ->
			{Stage,Cp,Bp,Ap,Sp,state_choose(SSp,State),SSSp};
		6 ->
			{Stage,Cp,Bp,Ap,Sp,SSp,state_choose(SSSp,State)};
		_ ->
			{Stage,Cp,Bp,Ap,Sp,SSp,SSSp}
	end.

state_choose(OldState,NewState) ->
	if
		OldState == 2 ->
			OldState;
		OldState == 0 andalso NewState == 1 ->
			NewState;
		OldState == 1 andalso NewState == 2 ->
			NewState;
		true ->
			OldState
	end.
			
init_order_prize(Stage,Plv,State) ->
	case Plv of
		1 -> 
			{Stage,State,0,0,0,0,0};
		2 ->
			{Stage,0,State,0,0,0,0};
		3 ->
			{Stage,0,0,State,0,0,0};
		4 ->
			{Stage,0,0,0,State,0,0};
		5 ->
			{Stage,0,0,0,0,0,State};
		_ ->
			{Stage,0,0,0,0,0,0}
	end.

%%开启下一关卡
open_next_stage(PlayerId,EraInfo) ->
	LvInfo = EraInfo#ets_fs_era.lv_info,
	Stage = find_max_stage(LvInfo),
	update_player_era_info(PlayerId,system,Stage + 5,0,3600,0).

%%获取关卡属性奖励
get_stage_attribute(Player,Stage,EraInfo) ->
	PlayerId = Player#player.id,
	case data_era:stage_add_attribute(Stage) of
		[0,0,0,0,0] ->
			Player;
		[Attack,Hp,Mp,Def,AntiAll] ->
			OldAttack = EraInfo#ets_fs_era.attack,
			if
				OldAttack < Attack ->
					NewEraInfo = EraInfo#ets_fs_era{attack = Attack,hp = Hp,mp = Mp,def = Def,anti_all = AntiAll},
					update_player_era_ets(NewEraInfo),
					spawn(fun()->db_agent:update_player_era_attribute(PlayerId, Attack, Hp, Mp, Def, AntiAll)end),
					NewPlayer = lib_player:count_player_attribute(Player),
					lib_player:send_player_attribute(NewPlayer, 2),
					NewPlayer;
				true ->
					Player
			end
	end.
	
	
%%是否已经通关 
is_passed_stage(PlayerId,Stage) ->
	case get_player_era_info(PlayerId) of
		[] ->
			false;
		EraInfo ->
			LvInfo = EraInfo#ets_fs_era.lv_info,
			case lists:keyfind(Stage, 1, LvInfo) of
				false ->
					false;
				{_Stage,Lv,_Time} ->
					if
						Lv > 0 ->
							true;
						true ->
							false
					end
			end
	end.

%%删除玩家封神纪元信息
unload_player_era_info(PlayerId) ->
	ets:delete(?ETS_FS_ERA, PlayerId).

%%获取玩家封神纪元信息
get_player_era_info(PlayerId) ->
	case ets:lookup(?ETS_FS_ERA, PlayerId) of
		[] -> 
			[];
		[EraInfo|_] ->
			EraInfo
	end.
		  
%%获取玩家封神纪元属性加成[attack,hp,mp,def,anti_all]
get_player_era_attribute(PlayerId) ->
	EraInfo = get_player_era_info(PlayerId),
	case is_record(EraInfo,ets_fs_era) of
		true ->
			[
			 EraInfo#ets_fs_era.attack,
			 EraInfo#ets_fs_era.hp,
			 EraInfo#ets_fs_era.mp,
			 EraInfo#ets_fs_era.def,
			 EraInfo#ets_fs_era.anti_all
			];
		false ->
			[0,0,0,0,0]
	end.

%%气血损耗计算
calc_era_scene_hurt(NewPlayer,Hurt) ->
	case is_era_scene(NewPlayer#player.scene) of
		true ->
			if
				Hurt > 0 ->
					if
						is_pid(NewPlayer#player.other#player_other.pid_dungeon) ->
							NewPlayer#player.other#player_other.pid_dungeon  ! {hurt,Hurt};
						true ->
							skip
					end;
				true ->
					skip
			end;
		_ ->
			skip
	end.
	
%%是否封神纪元场景
is_era_scene(SceneUniqueId) ->
	SceneResId = lib_scene:get_scene_id_from_scene_unique_id(SceneUniqueId),
	SceneResId >= 1101 andalso SceneResId =< 1115.

%%场景对应关卡转换
scene_to_stage(SceneId) ->
	case SceneId of
		1101 -> 30;
		1102 -> 35;
		1103 -> 40;
		1104 -> 45;
		1105 -> 50;
		1106 -> 55;
		1107 -> 60;
		1108 -> 65;
		1109 -> 70;
		1110 -> 75;
		1111 -> 80;
		1112 -> 85;
		1113 -> 90;
		1114 -> 95;
		1115 -> 100;
		_ -> 30
	end.

%% 连斩数对应评价
ckills_score_level(Ckills) ->
	if
		Ckills =< 50 ->
			1;
		Ckills =< 100 ->
			2;
		Ckills =< 150 ->
			3;
		Ckills =< 200 ->
			4;
		Ckills =< 250 ->
			5;
		Ckills =< 300 ->
			6;
		true ->
			6
	end.
	
%%
%% Local Functions
%%

