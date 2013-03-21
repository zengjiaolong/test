%% Author: zj
%% Created: 2011-10-20
%% Description: TODO: Add description to lib_deputy
-module(lib_deputy).
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
%%获取副法宝信息
get_deputy_equip_info(Player,PlayerId) ->
	case Player#player.id == PlayerId of %%查看自己
		true ->
			Pattern = #ets_deputy_equip{pid = PlayerId , _='_'},
			DeputyInfo_0 = goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern),
			if
				is_record(DeputyInfo_0,ets_deputy_equip) ->
					DeputyInfo = do_deputy_lucky_reset(DeputyInfo_0),
					DeputyName = get_deputy_equip_name(DeputyInfo#ets_deputy_equip.prof_lv), 
					Prof_max = 10000,%%数量度最大值
					Step = DeputyInfo#ets_deputy_equip.step,
					Need_lv = (Step + 3)* 10,
					%%发动几率
					[Tick_ratio ,Per_attack]= get_deputy_attack_val(DeputyInfo#ets_deputy_equip.prof_lv),
					%%下一级发动几率
					[Next_tick_ratio,Next_per_attack] = get_deputy_attack_val(DeputyInfo#ets_deputy_equip.prof_lv + 1),
					%%攻击力
					View_attack = round((Player#player.max_attack + Player#player.min_attack) / 2 * (Per_attack / 100)),
					%%下一级攻击力
					Next_view_attack = round((Player#player.max_attack + Player#player.min_attack)  / 2 * (Next_per_attack / 100)),
					%%属性列表
					AttributeList = DeputyInfo#ets_deputy_equip.att,
					TmpAttributeList = DeputyInfo#ets_deputy_equip.tmp_att,	
					[
						DeputyName,
						DeputyInfo#ets_deputy_equip.color,
						DeputyInfo#ets_deputy_equip.step,
						DeputyInfo#ets_deputy_equip.prof,
						Prof_max,
						DeputyInfo#ets_deputy_equip.prof_lv,
						upgrade_deputy_color_ratio_view(DeputyInfo#ets_deputy_equip.color),
						DeputyInfo#ets_deputy_equip.lucky_color,
						get_color_lucky_max(DeputyInfo#ets_deputy_equip.color),
						upgrade_deputy_step_ratio_view(DeputyInfo#ets_deputy_equip.step),
						DeputyInfo#ets_deputy_equip.lucky_step,
						get_step_lucky_max(DeputyInfo#ets_deputy_equip.step),
						break_deputy_prof_ratio_view(DeputyInfo#ets_deputy_equip.prof_lv),
						DeputyInfo#ets_deputy_equip.lucky_prof,
						get_prof_lucky_max(DeputyInfo#ets_deputy_equip.prof_lv),
						Need_lv,
						View_attack,
						Tick_ratio,
						Next_view_attack,
						Next_tick_ratio,
						DeputyInfo#ets_deputy_equip.skills,
						AttributeList,
						TmpAttributeList
					];
				true ->
					[]
			end;
		false -> %%查看别人
			case lib_player:get_online_info_fields(PlayerId,[pid]) of
				[Pid] when is_pid(Pid) -> %%在线
					gen_server:call(Pid, {'get_deputy_equip_info'});
				_ ->
					%%不在线
					[]
			end			
	end.

%%触发重置幸运值
do_deputy_lucky_reset(DeputyInfo) ->
	Now = util:unixtime(),
	LastResetTime = DeputyInfo#ets_deputy_equip.reset ,
	LuckyColor = DeputyInfo#ets_deputy_equip.lucky_color,
	LuckyStep = DeputyInfo#ets_deputy_equip.lucky_step,
	LuckyProf = DeputyInfo#ets_deputy_equip.lucky_prof,
	TodaySecond = util:get_today_current_second(),
	{TodayMidNightSecond  ,_ }= util:get_midnight_seconds(Now),
	case util:is_same_date(Now,LastResetTime) of
		true -> %%时间是同一天
			if 
				LastResetTime < (TodayMidNightSecond + 3600 * 3) andalso Now >= (TodayMidNightSecond + 3600 * 3) ->
					Reset = true;
				true ->
					Reset = false
			end;
		false ->		
			if
				TodaySecond >= 3600 * 3 ->
					Reset = true;					
				true ->
					Reset = false
			end
	end,
	case Reset of
		true ->
			%%根据幸运值是否到达200再判断是否清除具体幸运值
			if
				LuckyColor >= 200 ->
					NewLuckyColor = LuckyColor;
				true ->
					NewLuckyColor = 0
			end,
			if
				LuckyStep >= 200 ->
					NewLuckyStep = LuckyStep;
				true ->
					NewLuckyStep = 0
			end,
			if
				LuckyProf >= 200 ->
					NewLuckyProf = LuckyProf;
				true ->
					NewLuckyProf = 0
			end,
			db_agent:mod_deputy_equip([{lucky_color,NewLuckyColor},{lucky_step,NewLuckyStep},{lucky_prof,NewLuckyProf},{reset,Now}],[{id,DeputyInfo#ets_deputy_equip.id}]),
			NewDeputyInfo = DeputyInfo#ets_deputy_equip{lucky_color = NewLuckyColor,lucky_step = NewLuckyStep,lucky_prof = NewLuckyProf,reset = Now},
			update_ets(NewDeputyInfo),
			NewDeputyInfo;
		false ->
			DeputyInfo
	end.
	
					
%%神器增加属性值
get_deputy_add_attribute(Pid) ->
	Pattern = #ets_deputy_equip{pid = Pid , _='_'},
	DeputyInfo = goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern),
	case is_record(DeputyInfo,ets_deputy_equip) of
		true ->
			[[1,Hp],[3,Attack],[4,Def],[0,Anti]] = DeputyInfo#ets_deputy_equip.att,
			[Hp,Attack,Def,Anti];
		false ->
			[0,0,0,0]
	end.

%%神器增加的技能信息 
%%return [熟练等级，技能列表]
get_deputy_add_skills(Pid) ->
	Pattern = #ets_deputy_equip{pid = Pid , _='_'},
	DeputyInfo = goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern),
	case is_record(DeputyInfo,ets_deputy_equip) of
		true ->
			[DeputyInfo#ets_deputy_equip.prof_lv,DeputyInfo#ets_deputy_equip.skills];
		false ->
			[0,[]]
	end.

%%获取所有副法宝信息
%% get_all_deputy_equip_info(Lv) ->
%% 	InfoList = [[1,0],[2,0],[3,0],[4,0],[5,0]],
%% 	InfoList.

%% 副法宝品级提升 
%% return [Code,Color,Ratio_color,Lucky_color,Lucky_color_max,NewPlayer]
upgrade_deputy_color(Player,Auto_Purch) ->
	Pattern = #ets_deputy_equip{pid = Player#player.id , _='_'},
	DeputyInfo = goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern),
	case is_record(DeputyInfo,ets_deputy_equip) of
		true ->
			Color = DeputyInfo#ets_deputy_equip.color,
			%%RatioColor = DeputyInfo#ets_deputy_equip.ratio_color,
			Cost = 
				case Color of
					0 -> 1000;
					1 -> 7500;
					2 -> 15000;
					3 -> 30000;
					_ -> 100000000
				end,
			LuckyColor = DeputyInfo#ets_deputy_equip.lucky_color,
			LuckyColorMax = get_color_lucky_max(Color),
			Ratio = data_deputy:color_to_ratio(LuckyColor,Color),
			StoneId = 
				if
					DeputyInfo#ets_deputy_equip.color == 3 ->
						32022; %%精炼品质石
					true ->
						32021 %%品质石
				end,
			GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, StoneId),
			StoneList = goods_util:get_type_goods_list(Player#player.id,StoneId,4),
			TotalNum  = goods_util:get_goods_totalnum(StoneList),
			Need = 
				case DeputyInfo#ets_deputy_equip.color  of
					0 -> 4;
					1 -> 6;
					2 -> 8;
					3 -> 5;
					_ -> 1000
				end,
			if
				Auto_Purch ==0 andalso TotalNum < Need -> %%材料不足
					[2,LuckyColor,LuckyColorMax,Player];
				Player#player.coin + Player#player.bcoin < Cost -> %%铜币不足
					[3,LuckyColor,LuckyColorMax,Player];
				Auto_Purch == 1 andalso TotalNum < Need andalso Player#player.gold < GoodsTypeInfo#ets_base_goods.price*(Need-TotalNum) ->
					[6,LuckyColor,LuckyColorMax,Player]; %%元宝不够
				true ->
					Result = 
						if TotalNum == 0 -> %%原来背包里(直接消费元宝)
							   1;
						   TotalNum > 0 andalso TotalNum < Need -> %%只有部分材料
							   case gen_server:call(Player#player.other#player_other.pid_goods,{'delete_more',StoneId,TotalNum}) of 
								   1 ->
									   1;
								   Code ->
									   Code
							   end;
						   true -> %%有全部材料
							   case gen_server:call(Player#player.other#player_other.pid_goods,{'delete_more',StoneId,Need}) of 
								   1 ->
									   1;
								   Code ->
									   Code
							   end
						end,
					if Result == 1 ->
						    Ram = util:rand(1,10000),
							NewPlayer = lib_goods:cost_money(Player,Cost,coin,1567),
							if Auto_Purch == 1 andalso GoodsTypeInfo#ets_base_goods.price*(Need-TotalNum) > 0 ->
								   spawn(fun() ->log:log_shop([1,1,NewPlayer#player.id,NewPlayer#player.nickname,StoneId,gold,GoodsTypeInfo#ets_base_goods.price,Need-TotalNum]) end),
								   NewPlayer1 = lib_goods:cost_money(NewPlayer,GoodsTypeInfo#ets_base_goods.price*(Need-TotalNum),gold,1578);
							   true ->
								   NewPlayer1 = NewPlayer
							end,
						    lib_player:send_player_attribute(NewPlayer1,2),
							if
								Ram < Ratio * 100 ->
									%%成功
									NewColor = Color + 1 ,
									NewLuckyColorMax = get_color_lucky_max(NewColor),
									NewDeputyInfo=DeputyInfo#ets_deputy_equip{color = NewColor,lucky_color = 0},
									update_ets(NewDeputyInfo),
									Batt_val = count_deputy_batt_val(NewDeputyInfo),
									db_agent:mod_deputy_equip([{color,NewColor},{lucky_color,0},{batt_val,Batt_val}],[{id,DeputyInfo#ets_deputy_equip.id}]),
									%%系统广播
									broadcast(1,NewPlayer,NewDeputyInfo),
									db_agent:log_deputy_color([Player#player.id,
															   Player#player.nickname,
															   Color,
															   NewColor,
															   LuckyColor,
															   StoneId,
															   Need,
															   Ratio * 100,
															   Ram,
															   Cost,
															   1
															   ]),
									%%%%%%元宵活动%%%%%%
%% 									{TGStart, TGEnd} = lib_activities:lantern_festival_time(),
%% 									Now = util:unixtime(),
%% 									if
%% 										Now > TGStart andalso Now < TGEnd ->
%% 											db_agent:update_mid_prize([{got,0}],[{pid,Player#player.id},{type,4}]);
%% 										true ->
%% 											skip
%% 									end,
									%%%%%%%%%%%%%%%%%%%%
									%%神器成就判断
									lib_achieve_outline:deputy_ach_check(Player#player.other#player_other.pid, NewDeputyInfo#ets_deputy_equip.prof_lv, NewDeputyInfo#ets_deputy_equip.color),
									[1,0,NewLuckyColorMax,NewPlayer1];
								true ->
									%%失败
									NewLuckyColor = set_color_lucky_val(Color,LuckyColor + 5),
									NewDeputyInfo=DeputyInfo#ets_deputy_equip{lucky_color = NewLuckyColor},
									update_ets(NewDeputyInfo),
									db_agent:mod_deputy_equip([{lucky_color,NewLuckyColor}],[{id,DeputyInfo#ets_deputy_equip.id}]),
									db_agent:log_deputy_color([Player#player.id,
															   Player#player.nickname,
															   Color,
															   Color,
															   LuckyColor,
															   StoneId,
															   Need,
															   Ratio * 100,
															   Ram,
															   Cost,
															   0
															   ]),
									[0,NewLuckyColor,LuckyColorMax,NewPlayer1]								
							end;
					   true ->%%材料删除失败
						   [4,LuckyColor,LuckyColorMax,Player]
					end
			end;
		false -> %%神器不存在
			[5,0,0,Player]
	end.

%%副法宝品级提升 显示成功率
upgrade_deputy_color_ratio_view(Color) ->
	case Color of
		0 -> 10;
		1 -> 5;
		2 -> 2;
		3 -> 1;
		_ -> 0
	end.
%% 副法宝品阶提升
upgrade_deputy_step(Player,Auto_Purch) ->
	Pattern = #ets_deputy_equip{pid = Player#player.id , _='_'},
	DeputyInfo = goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern),
	case is_record(DeputyInfo,ets_deputy_equip) of
		true ->
			Step = DeputyInfo#ets_deputy_equip.step,
			Cost = 
				case Step of
					1 -> 10000;
					2 -> 30000;
					3 -> 90000;
					4 -> 180000;
					5 -> 300000;
					6 -> 400000;
					_ -> 100000000
				end,
			LuckyStep = DeputyInfo#ets_deputy_equip.lucky_step,
			LuckyStepMax = get_step_lucky_max(Step),
			Ratio = data_deputy:step_to_ratio(LuckyStep,Step),
			[StoneId,Need] = 
				case DeputyInfo#ets_deputy_equip.step  of 
					1 -> [21022 , 1];
					2 -> [21022 , 2];
					3 -> [21022 , 4];
					4 -> [21023 , 1];
					5 -> [21023 , 1];
					6 -> [21023 ,2];
					_ -> [21023 ,10000]
				end,
			GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, StoneId),
			StoneList = goods_util:get_type_goods_list(Player#player.id,StoneId,4),
			TotalNum  = goods_util:get_goods_totalnum(StoneList),
			Need_lv = (Step + 3) * 10,
			if
				Player#player.lv < Need_lv ->%%等级不足
					[2,LuckyStep,LuckyStepMax,Player];
				Auto_Purch == 0 andalso TotalNum < Need ->%%材料不足
					[3,LuckyStep,LuckyStepMax,Player];
				Player#player.coin + Player#player.bcoin < Cost ->%%铜币不足
					[4,LuckyStep,LuckyStepMax,Player];
				Auto_Purch == 1 andalso TotalNum < Need andalso Player#player.gold < GoodsTypeInfo#ets_base_goods.price*(Need-TotalNum) ->
					[7,LuckyStep,LuckyStepMax,Player]; %%元宝不够
				true ->
					Result = 
						if TotalNum == 0 -> %%原来背包里(直接消费元宝)
							   1;
						   TotalNum > 0 andalso TotalNum < Need -> %%只有部分材料
							   case gen_server:call(Player#player.other#player_other.pid_goods,{'delete_more',StoneId,TotalNum}) of 
								   1 ->
									   1;
								   Code ->
									   Code
							   end;
						   true -> %%有全部材料
							   case gen_server:call(Player#player.other#player_other.pid_goods,{'delete_more',StoneId,Need}) of 
								   1 ->
									   1;
								   Code ->
									   Code
							   end
						end,
					if Result == 1 ->
						   Ram = util:rand(1,10000),
						   NewPlayer = lib_goods:cost_money(Player,Cost,coin,1568),
						   if Auto_Purch == 1 andalso GoodsTypeInfo#ets_base_goods.price*(Need-TotalNum) > 0 ->
								   spawn(fun() ->log:log_shop([1,1,NewPlayer#player.id,NewPlayer#player.nickname,StoneId,gold,GoodsTypeInfo#ets_base_goods.price,Need-TotalNum]) end),
								   NewPlayer1 = lib_goods:cost_money(NewPlayer,GoodsTypeInfo#ets_base_goods.price*(Need-TotalNum),gold,1577);
							   true ->
								   NewPlayer1 = NewPlayer
							end,
						    lib_player:send_player_attribute(NewPlayer1,2),
							if
								Ram < Ratio * 100 ->
									%%成功
									NewStep = Step + 1 ,
									NewLuckyStepMax = get_step_lucky_max(NewStep),
									NewDeputyInfo=DeputyInfo#ets_deputy_equip{step = NewStep,lucky_step = 0},
									update_ets(NewDeputyInfo),
									Batt_val = count_deputy_batt_val(NewDeputyInfo),
									db_agent:mod_deputy_equip([{step,NewStep},{lucky_step,0},{batt_val,Batt_val}],[{id,DeputyInfo#ets_deputy_equip.id}]),
									db_agent:log_deputy_step([Player#player.id,
															  Player#player.nickname,
															  Step,
															  NewStep,
															  LuckyStep,
															  StoneId,
															  Need,
															  Ratio * 100,
															  Ram,
															  Cost,
															  1
															 ]),
									[1,0,NewLuckyStepMax,NewPlayer1];
								true ->
									%%失败
									NewLuckyStep = set_step_lucky_val(Step,LuckyStep + 5),
									NewDeputyInfo=DeputyInfo#ets_deputy_equip{lucky_step = NewLuckyStep},
									update_ets(NewDeputyInfo),
									db_agent:mod_deputy_equip([{lucky_step,NewLuckyStep}],[{id,DeputyInfo#ets_deputy_equip.id}]),
									db_agent:log_deputy_step([Player#player.id,
															  Player#player.nickname,
															  Step,
															  Step,
															  LuckyStep,
															  StoneId,
															  Need,
															  Ratio * 100,
															  Ram,
															  Cost,
															  0
															 ]),
									[0,NewLuckyStep,LuckyStepMax,NewPlayer1]					
							end;
					   true ->%%删除材料失败
						   [5,LuckyStep,LuckyStepMax,Player]
					end
			end;
		false ->
			[6,0,0,Player]
	end.
%% 副法宝品阶提升 显示成功率
upgrade_deputy_step_ratio_view(Step) ->
	case Step of
		1 -> 35;
		2 -> 30;
		3 -> 20;
		4 -> 20;
		5 -> 10;
		6 -> 10;
		_ -> 0
	end.
%% 副法宝提升熟练度 Type  1 使用 2全部使用
%% 熟练丹32026
upgrade_deputy_prof(Player,Type,Auto_Purch) ->
	Pattern = #ets_deputy_equip{pid = Player#player.id , _='_'},
	DeputyInfo = goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern),
	if is_record(DeputyInfo,ets_deputy_equip) ->
			Prof = DeputyInfo#ets_deputy_equip.prof,
			Prof_lv = DeputyInfo#ets_deputy_equip.prof_lv,
			MaxProfVal = get_lv_prof_maxval(Prof_lv),
			StoneList = goods_util:get_type_goods_list(Player#player.id,32026,4),
			TotalNum  = goods_util:get_goods_totalnum(StoneList),
			GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, 32026),
			if MaxProfVal > Prof ->
					DiffVal = MaxProfVal - Prof ,
					if Auto_Purch == 0 ->%%不自动购买
						   if Type == 1 ->
								  if DiffVal > 50 ->
											NewProf = Prof + 50;
										true ->
											NewProf = MaxProfVal
								  end,
								  CostNum = 1;
							  true ->
								  FullNum = util:ceil(DiffVal / 50),
								  if TotalNum >= FullNum ->
										 NewProf = MaxProfVal,
										 CostNum = FullNum;
									 true ->
										 NewProf = Prof  + TotalNum * 50,
										 CostNum = TotalNum
								  end
						   end;
					   true ->%%材料不足自动购买
						   if Type == 1 ->
								  if DiffVal > 50 ->
											NewProf = Prof + 50;
										true ->
											NewProf = MaxProfVal
								  end,
								  CostNum = 1;
							  true ->
								  FullNum = util:ceil(DiffVal / 50),
								  NewProf = MaxProfVal,
								  CostNum = FullNum
						   end
					end,
					if Auto_Purch == 0 ->%%不自动购买
							case gen_server:call(Player#player.other#player_other.pid_goods,{delete_more,32026,CostNum}) of
								1 ->
									%%扣除成功
									NewDeputyInfo=DeputyInfo#ets_deputy_equip{prof = NewProf},
									update_ets(NewDeputyInfo),
									db_agent:mod_deputy_equip([{prof,NewProf}],[{id,DeputyInfo#ets_deputy_equip.id}]),
									db_agent:log_deputy_prof([Player#player.id,
															  Player#player.nickname,
															  32026,
															  CostNum,
															  Prof,
															  NewProf,
															  Prof_lv
															  ]),
									[1,NewProf,MaxProfVal,Prof_lv,Player];
								_ -> %%背包没有熟练丹
									[2,Prof,MaxProfVal,Prof_lv,Player]
							end;
					   Auto_Purch == 1 andalso TotalNum < CostNum andalso Player#player.gold < GoodsTypeInfo#ets_base_goods.price*(CostNum-TotalNum) ->
						   			[4,Prof,MaxProfVal,Prof_lv,Player];
					   true ->%%材料不足自动购买
							if TotalNum >= CostNum -> %%材料足够
								   case gen_server:call(Player#player.other#player_other.pid_goods,{delete_more,32026,CostNum}) of
										1 ->
											%%扣除成功
											NewDeputyInfo=DeputyInfo#ets_deputy_equip{prof = NewProf},
											update_ets(NewDeputyInfo),
											db_agent:mod_deputy_equip([{prof,NewProf}],[{id,DeputyInfo#ets_deputy_equip.id}]),
											db_agent:log_deputy_prof([Player#player.id,
																	  Player#player.nickname,
																	  32026,
																	  CostNum,
																	  Prof,
																	  NewProf,
																	  Prof_lv
																	  ]),
											[1,NewProf,MaxProfVal,Prof_lv,Player];
										_ -> %%背包没有熟练丹
											[2,Prof,MaxProfVal,Prof_lv,Player]
									end;
							   TotalNum > 0 andalso TotalNum < CostNum ->%%物品不够则先删除物品，再扣元宝
										 case gen_server:call(Player#player.other#player_other.pid_goods,{delete_more,32026,TotalNum}) of
											1 ->
												%%扣除成功
												NewDeputyInfo=DeputyInfo#ets_deputy_equip{prof = NewProf},
												update_ets(NewDeputyInfo),
												db_agent:mod_deputy_equip([{prof,NewProf}],[{id,DeputyInfo#ets_deputy_equip.id}]),
												db_agent:log_deputy_prof([Player#player.id,
																		  Player#player.nickname,
																		  32026,
																		  CostNum,
																		  Prof,
																		  NewProf,
																		  Prof_lv
																		  ]),
												spawn(fun() ->log:log_shop([1,1,Player#player.id,Player#player.nickname,32026,gold,GoodsTypeInfo#ets_base_goods.price,CostNum-TotalNum]) end),
												NewPlayer1 = lib_goods:cost_money(Player,GoodsTypeInfo#ets_base_goods.price*(CostNum-TotalNum),gold,1575),
												lib_player:send_player_attribute(NewPlayer1,2),
												[1,NewProf,MaxProfVal,Prof_lv,NewPlayer1];
											_ -> %%背包没有熟练丹
												[2,Prof,MaxProfVal,Prof_lv,Player]
										end;
							   true -> %%全部扣元宝
									NewDeputyInfo=DeputyInfo#ets_deputy_equip{prof = NewProf},
											update_ets(NewDeputyInfo),
											db_agent:mod_deputy_equip([{prof,NewProf}],[{id,DeputyInfo#ets_deputy_equip.id}]),
											db_agent:log_deputy_prof([Player#player.id,
																	  Player#player.nickname,
																	  32026,
																	  CostNum,
																	  Prof,
																	  NewProf,
																	  Prof_lv
																	  ]),
									spawn(fun() ->log:log_shop([1,1,Player#player.id,Player#player.nickname,32026,gold,GoodsTypeInfo#ets_base_goods.price,CostNum-TotalNum]) end),
									NewPlayer1 = lib_goods:cost_money(Player,GoodsTypeInfo#ets_base_goods.price*(CostNum-TotalNum),gold,1575),
									lib_player:send_player_attribute(NewPlayer1,2),
									[1,NewProf,MaxProfVal,Prof_lv,NewPlayer1]
							end								   
					end;
				true ->%%熟练度已到达上限
					[3,Prof,MaxProfVal,Prof_lv,Player]
			end;
		true ->
			[0,0,0,0,Player]
	end.

%%突破瓶颈
break_deputy_prof(Player,Auto_Purch) ->
	Pattern = #ets_deputy_equip{pid = Player#player.id , _='_'},
	DeputyInfo = goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern),
	case is_record(DeputyInfo,ets_deputy_equip) of
		true ->
			Prof = DeputyInfo#ets_deputy_equip.prof,
			Prof_lv = DeputyInfo#ets_deputy_equip.prof_lv,
			LuckyProf = DeputyInfo#ets_deputy_equip.lucky_prof,
			%%Step = DeputyInfo#ets_deputy_equip.step,
			LuckyProfMax = get_prof_lucky_max(Prof_lv),
			MaxProfVal = get_lv_prof_maxval(Prof_lv),
			Ratio = data_deputy:break_to_ratio(LuckyProf,Prof_lv),
			Cost = 
				case Prof_lv of
					1 -> 2500;
					2 -> 5000;
					3 -> 10000;
					4 -> 20000;
					5 -> 30000;
					6 -> 35000;
					_ -> 100000000
				end,
			[StoneId,Need] = 
			case Prof_lv + 1 of
				2 -> [32027 ,2]; %%太虚石
				3 -> [32027 ,10];
				4 -> [32028 ,5];%%精练太虚石
				5 -> [32028 ,10];
				6 -> [32028 ,20];
				7 -> [32028 ,30];
				_ -> [0 , 0]
			end,
			GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, StoneId),
			StoneList = goods_util:get_type_goods_list(Player#player.id,StoneId,4),
			TotalNum  = goods_util:get_goods_totalnum(StoneList),
			if
				Prof /= MaxProfVal -> %%熟练度未满
					[2,LuckyProf,LuckyProfMax,Prof_lv,Player];
				Auto_Purch == 0 andalso TotalNum < Need -> %%道具不足
					[3,LuckyProf,LuckyProfMax,Prof_lv,Player];
				Player#player.coin + Player#player.bcoin < Cost ->%%铜币不足
					[6,LuckyProf,LuckyProfMax,Prof_lv,Player];
				Auto_Purch == 1 andalso TotalNum < Need andalso Player#player.gold < GoodsTypeInfo#ets_base_goods.price*(Need-TotalNum) ->
					[7,LuckyProf,LuckyProfMax,Prof_lv,Player]; %%元宝不够
				true ->
					Result = 
						if TotalNum == 0 -> %%原来背包里(直接消费元宝)
							   1;
						   TotalNum > 0 andalso TotalNum < Need -> %%只有部分材料
							   case gen_server:call(Player#player.other#player_other.pid_goods,{'delete_more',StoneId,TotalNum}) of 
								   1 ->
									   1;
								   Code ->
									   Code
							   end;
						   true -> %%有全部材料
							   case gen_server:call(Player#player.other#player_other.pid_goods,{'delete_more',StoneId,Need}) of 
								   1 ->
									   1;
								   Code ->
									   Code
							   end
						end,
					if Result == 1 ->
						    Ram = util:rand(1,10000),
							NewPlayer = lib_goods:cost_money(Player,Cost,coin,1569),
						    if Auto_Purch == 1 andalso GoodsTypeInfo#ets_base_goods.price*(Need-TotalNum) > 0 ->
								    spawn(fun() ->log:log_shop([1,1,NewPlayer#player.id,NewPlayer#player.nickname,StoneId,gold,GoodsTypeInfo#ets_base_goods.price,Need-TotalNum]) end),
								   NewPlayer1 = lib_goods:cost_money(NewPlayer,GoodsTypeInfo#ets_base_goods.price*(Need-TotalNum),gold,1576);
							   true ->
								   NewPlayer1 = NewPlayer
							end,
							if
								Ram < Ratio * 100 ->
									%%成功
									NewProf_lv = Prof_lv + 1 ,
									NewProf = 0,
									NewLuckyProf = 0,
									NewLuckyProfMax = get_prof_lucky_max(NewProf_lv),
									NewDeputyInfo=DeputyInfo#ets_deputy_equip{prof_lv = NewProf_lv,prof =  NewProf ,lucky_prof = NewLuckyProf},
									update_ets(NewDeputyInfo),
									Batt_val = count_deputy_batt_val(NewDeputyInfo),
									%%突破影响战斗力值
									NewPlayer2 = lib_player:count_player_attribute(NewPlayer1),
									lib_player:send_player_attribute(NewPlayer2,2),
									db_agent:mod_deputy_equip([{prof_lv,NewProf_lv},{prof,NewProf},{lucky_prof,NewLuckyProf},{batt_val,Batt_val}],[{id,DeputyInfo#ets_deputy_equip.id}]),
									broadcast(2,Player,NewDeputyInfo),
									db_agent:log_deputy_break([Player#player.id,
															   Player#player.nickname,
															   Prof_lv,
															   NewProf_lv,
															   LuckyProf,
															   StoneId,
															   Need,
															   Ratio * 100,
															   Ram,
															   Cost,
															   1]),
									NewPlayer3 = NewPlayer2#player{other = NewPlayer2#player.other#player_other{deputy_prof_lv = NewProf_lv}},
									%%%%%%二月活动%%%%%%
%% 									{TGStart, TGEnd} = lib_activities:february_event_time(),
%% 									Now = util:unixtime(),
%% 									if
%% 										Now > TGStart andalso Now < TGEnd ->
%% 											db_agent:update_mid_prize([{got,0}],[{pid,Player#player.id},{type,5}]);
%% 										true ->
%% 											skip
%% 									end,
									%%%%%%%%%%%%%%%%%%%%
									%%神器成就判断
									lib_achieve_outline:deputy_ach_check(Player#player.other#player_other.pid, NewDeputyInfo#ets_deputy_equip.prof_lv, NewDeputyInfo#ets_deputy_equip.color),
									[1,0,NewLuckyProfMax,NewProf_lv,NewPlayer3];
								true ->
									%%失败
									NewLuckyProf = set_prof_lucky_val(Prof_lv,LuckyProf + 5),
									NewDeputyInfo=DeputyInfo#ets_deputy_equip{lucky_prof = NewLuckyProf},
									update_ets(NewDeputyInfo),
									db_agent:mod_deputy_equip([{lucky_prof,NewLuckyProf}],[{id,DeputyInfo#ets_deputy_equip.id}]),
									db_agent:log_deputy_break([Player#player.id,
															   Player#player.nickname,
															   Prof_lv,
															   Prof_lv,
															   LuckyProf,
															   StoneId,
															   Need,
															   Ratio * 100,
															   Ram,
															   Cost,
															   0]),
									lib_player:send_player_attribute(NewPlayer1,2),
									[0,NewLuckyProf,LuckyProfMax,Prof_lv,NewPlayer1]			
							end;
					   true ->%%道具删除失败
						   [4,LuckyProf,LuckyProfMax,Prof_lv,Player]
					end
					
			end;
		false ->
			[5,0,0,0,Player]
	end.

%%突破瓶颈 显示成功率
break_deputy_prof_ratio_view(Prof_lv) ->
	case Prof_lv of
		1 -> 10;
		2 -> 5;
		3 -> 3 ;
		4 -> 1;
		5 -> 1;
		6 -> 1;
		_ -> 0
	end.
%%属性洗练
wash_deputy(Player,Type,Auto_Purch) ->
	Pattern = #ets_deputy_equip{pid = Player#player.id , _='_'},
	DeputyInfo = goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern),
	case is_record(DeputyInfo,ets_deputy_equip) of
		true ->			
			Step =  DeputyInfo#ets_deputy_equip.step,
			Color =  DeputyInfo#ets_deputy_equip.color,
			%%属性列表
			OldAtt = DeputyInfo#ets_deputy_equip.att,					
			TmpAtt = DeputyInfo#ets_deputy_equip.tmp_att,
			[Cost,NeedSpi] = get_wash_cost(Step),
			if
				Type == 1 -> %%使用玄石
					StoneList = goods_util:get_type_goods_list(Player#player.id,32016,4),
					TotalNum  = goods_util:get_goods_totalnum(StoneList),
					Need = 1;
				true ->
					TotalNum = 0,
					Need = 0
			end,
			GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, 32016),
			if
				Player#player.spirit < NeedSpi ->%%灵力不足
					[2,OldAtt,TmpAtt,[],Player,Step,Color];
				Player#player.coin + Player#player.bcoin < Cost ->%%铜币不足
					[3,OldAtt,TmpAtt,[],Player,Step,Color];
				Auto_Purch == 0 andalso Type == 1 andalso TotalNum  < Need ->%%材料不足
					[4,OldAtt,TmpAtt,[],Player,Step,Color];
				Type == 1 andalso Auto_Purch == 1 andalso TotalNum < Need andalso Player#player.gold < GoodsTypeInfo#ets_base_goods.price*(Need-TotalNum) ->
					[5,OldAtt,TmpAtt,[],Player,Step,Color]; %%元宝不够
				true ->
					Player1 = lib_goods:cost_money(Player,Cost,coin,1569),
					Result = 
						if TotalNum > 0 andalso Type == 0 ->
							   1;
						   TotalNum > 0 andalso Type == 1 ->
							   gen_server:call(Player#player.other#player_other.pid_goods,{delete_more,32016,1}),
							   1;
						   TotalNum == 0 andalso Type == 0 ->
							   1;
						   TotalNum == 0 andalso Type == 1 andalso Auto_Purch == 0 ->
							   1;
						   TotalNum == 0 andalso Type == 1 andalso Auto_Purch == 1 ->
							   2;%%物品不够直接用元宝购买
						   true ->
							   1
						end,		
					  if Result == 2 andalso Auto_Purch == 1 andalso Type == 1 andalso TotalNum < Need andalso GoodsTypeInfo#ets_base_goods.price*(Need-TotalNum) > 0 ->
							 	   spawn(fun() ->log:log_shop([1,1,Player#player.id,Player#player.nickname,32016,gold,GoodsTypeInfo#ets_base_goods.price,Need-TotalNum]) end),
								   NewPlayer1 = lib_goods:cost_money(Player1,GoodsTypeInfo#ets_base_goods.price*(Need-TotalNum),gold,1579);
							   true ->
								   NewPlayer1 = Player1
							end,
					%%初始属性必定成功
					ToSuccess = is_init_att(OldAtt),
					F = fun([Attid,Val],[NewAttList,ChangeAttList]) ->
							[R0,Limit,Inc,Dec] = data_deputy:get_wash_deputy_att(Step,Color,Attid),
							%%如果使用玄石增加概率
							if
								Type == 1 -> R = R0 + 5;
								true -> R = R0
							end,
							Ram = util:rand(1,10000),
							if
								Ram < (R * 100) orelse ToSuccess -> %%成功
									Add = util:rand(1,Inc),
									NewVal = Val + Add;
								true -> %%失败
									if
										Dec > Val ->
											Des = util:rand(1,Val-1);
										true ->
											Des = util:rand(1,Dec-1)
									end,
									NewVal = Val - Des
							end,
							if
								NewVal > Limit ->
									NewVal2 = Limit;
								NewVal < 0 ->
									NewVal2 = 0;
								true ->
									NewVal2 = NewVal
							end,
							if
								NewVal2 > Val ->
									AttChange = [Attid,1];
								NewVal2 == Val ->
									AttChange = [Attid,2];
								true ->
									AttChange = [Attid,0]
							end,
							NewAtt = [Attid,NewVal2],
							[[NewAtt|NewAttList],[AttChange|ChangeAttList]]
						end,

					[NewAtt,ChangeAtt] = lists:foldl(F, [[],[]], lists:reverse(OldAtt)),
					NewDeputyInfo = DeputyInfo#ets_deputy_equip{tmp_att = NewAtt},
					update_ets(NewDeputyInfo),			
					db_agent:mod_deputy_equip([{tmp_att,util:term_to_string(NewAtt)}],[{id,DeputyInfo#ets_deputy_equip.id}]),
					
					NewPlayer = lib_player:sub_spirit(NewPlayer1,NeedSpi),
					%%需除灵力 是否立刻写数据库
					db_agent:log_deputy_wash([Player#player.id,
											  Player#player.nickname,
											  util:term_to_string(OldAtt),
											  util:term_to_string(NewAtt),
											  Player#player.spirit,
											  NewPlayer#player.spirit,
											  32016,
											  Need,
											  Cost
											  ]), 
					lib_player:send_player_attribute(NewPlayer,2),
					[1,OldAtt,NewAtt,ChangeAtt,NewPlayer,Step,Color]
			end;
		false ->
			[0,[],[],[],Player,0,0]
	end.

%%洗练花费铜币和灵力
get_wash_cost(Step) ->
	case Step of
		1 -> [2500,80000];
		2 -> [5000,160000];
		3 -> [10000,500000];
		4 -> [20000,1500000];
		5 -> [40000,5000000];
		6 -> [80000,10000000];
		7 -> [160000,20000000];
		_ ->[100000000,100000000]
	end.
%%洗练属性变更
confirm_wash(Player,Type) ->
	Pattern = #ets_deputy_equip{pid = Player#player.id , _='_'},
	DeputyInfo = goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern),
	case is_record(DeputyInfo,ets_deputy_equip) of
		true ->
			OldAtt = DeputyInfo#ets_deputy_equip.att,					
			TmpAtt = DeputyInfo#ets_deputy_equip.tmp_att,
			Step = DeputyInfo#ets_deputy_equip.step,
			Color = DeputyInfo#ets_deputy_equip.color,
			case Type of
				1 -> %%维持
					NewDeputyInfo = DeputyInfo#ets_deputy_equip{tmp_att = []},
					update_ets(NewDeputyInfo),
					db_agent:mod_deputy_equip([{tmp_att,util:term_to_string([])}],[{id,DeputyInfo#ets_deputy_equip.id}]),
					NewAtt = OldAtt;
				2 -> %%替换
					if
						TmpAtt /= [] ->
							NewDeputyInfo = DeputyInfo#ets_deputy_equip{tmp_att = [] ,att = TmpAtt},
							update_ets(NewDeputyInfo),
							Batt_val = count_deputy_batt_val(NewDeputyInfo),
							db_agent:mod_deputy_equip([{tmp_att,util:term_to_string([])},{att,util:term_to_string(TmpAtt)},{batt_val,Batt_val}],[{id,DeputyInfo#ets_deputy_equip.id}]),
							NewAtt = TmpAtt;
						true ->
							NewAtt = OldAtt
					end
			end,
			NewPlayer = lib_player:count_player_attribute(Player),
			lib_player:send_player_attribute(NewPlayer, 3),
			{Step,Color,NewAtt,NewPlayer};
		false ->
			{0,0,[],Player}
	end.

%%学习技能
learn_skill(Player,Goods_id,Gid) ->
	Pattern = #ets_deputy_equip{pid = Player#player.id , _='_'},
	DeputyInfo = goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern),
	case is_record(DeputyInfo,ets_deputy_equip) of
		true ->
			Skills = DeputyInfo#ets_deputy_equip.skills,
			Prof_lv = DeputyInfo#ets_deputy_equip.prof_lv,
			[S_id,S_lv,Culture,Coin,R_Prof_lv] = get_skill_request(Goods_id),
			Check_pre_skill = fun([Skill_id,Skill_lv]) ->
									  if
										  %%已经学习
										  Skill_id == S_id andalso Skill_lv > S_lv  -> %%当前技能已经大于需求技能
											  2;
										  %%前置技能未学习
										  Skill_id == S_id andalso Skill_lv /= S_lv  -> %%当前技能等级不等于需求技能等级
											  1; 									  
										  true ->
											  0
									  end
							  end,
			Ret = lists:sum(lists:map(Check_pre_skill, Skills)),
			if
				Ret == 1 -> %%前置技能未学习
					[2,Player];
				Ret == 2 -> %%技能已学习
					[3,Player];
				Culture > Player#player.culture -> %%修为不足
					[4,Player];
				R_Prof_lv >  Prof_lv -> %%熟练等级不足
					[5,Player];
				Player#player.coin + Player#player.bcoin  < Coin -> %%铜币不足
					[6,Player];
				true ->
					case gen_server:call(Player#player.other#player_other.pid_goods,{delete_one,Gid,1}) of
						[1,_] ->
							Player1 = lib_goods:cost_money(Player,Coin,coin,1574),%%消费点要改
							
							%%学习技能
							Learn_skill = fun([Skill_id,Skill_lv],NewSkills) ->
												  if
													  Skill_id == S_id  -> %%其他等级升级
														  [[Skill_id,Skill_lv + 1]|NewSkills];
													  true ->
														  [[Skill_id,Skill_lv ]|NewSkills]
												  end
										  end,
							NewSkills = lists:foldl(Learn_skill,[] , lists:reverse(Skills)) ,
							NewDeputyInfo = DeputyInfo#ets_deputy_equip{skills = NewSkills},
							NewPlayer_1 = lib_player:sub_culture(Player1,Culture),
							update_ets(NewDeputyInfo),
							db_agent:mod_deputy_equip([{skills,util:term_to_string(NewSkills)}],[{id,DeputyInfo#ets_deputy_equip.id}]),	
							db_agent:log_deputy_skill([Player#player.id,
													   Player#player.nickname,
													   util:term_to_string(Skills),
													   util:term_to_string(NewSkills),
													   Player#player.culture,
													   NewPlayer_1#player.culture,
													   Coin
													   ]),
							NewPlayer = NewPlayer_1#player{other = NewPlayer_1#player.other#player_other{deputy_skill = NewSkills}},
							[1,NewPlayer];
						_ ->%%物品删除失败
							[7,Player]
					end
			end;
		false ->
			[0,Player]
	end.

%%前置技能，前置技能等级 修为 铜币 熟练等级
%%[S_id,S_lv,Culture,Coin,R_Prof_lv]
get_skill_request(BookId) ->
		case BookId of
			32038 ->[90002,0,2500,20000,4];%%夺魄灭魂1
			32039 ->[90002,1,7500,30000,5];%%夺魄灭魂2
			32040 ->[90002,2,22500,40000,6];%%夺魄灭魂3
			32041 ->[90002,3,67500,50000,7];%%夺魄灭魂4
			32042 ->[90003,0,4500,20000,5];%%碎星辰1
			32043 ->[90003,1,18000,40000,6];%%碎星辰2
			32044 ->[90003,2,72000,60000,7];%%碎星辰3
			32045 ->[90004,0,20000,50000,6];%%千里冰封1
			32046 ->[90004,1,80000,100000,7];%%千里冰封2
			32047 ->[90005,0,100000,200000,7];%%吞日月1
			_ ->[100000000,100000000,100000000,100000000]
		end.
%%新增副法宝
add_deputy_equip(Player) ->
	PlayerId = Player#player.id,
	Pattern = #ets_deputy_equip{pid = PlayerId, _='_'},
	DeputyInfo = goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern),
	case is_record(DeputyInfo,ets_deputy_equip) of
		true ->
			Player;
		false ->
			if
				Player#player.lv >= 40 ->
					Step = 1,
					Color = 0,
					Prof = 0,
					Prof_lv = 1,
					Lucky_color = 0,
					Lucky_step = 0,
					Lucky_prof = 0,
					Skills = [[90002,0],[90003,0],[90004,0],[90005,0]],%%技能ID，等级
					Att = [[1,1],[3,1],[4,1],[0,1]], %%1:气血，3攻击 4 防御 0 全抗
					TmpAtt = [],
					Reset = util:unixtime(),
					Values =
						[PlayerId,Step,Color,Prof,Prof_lv,
				 		Lucky_color,Lucky_step,Lucky_prof,Reset,
				 		util:term_to_string(Skills),
				 		util:term_to_string(Att),
				 		util:term_to_string(TmpAtt)],
					Fields =
						[pid,step,color,prof,prof_lv,lucky_color,lucky_step,lucky_prof,reset,skills,att,tmp_att],
					Id = db_agent:add_deputy_equip(Fields,Values),
					NewDeputyInfo = #ets_deputy_equip{id= Id,pid = PlayerId,step = Step,prof_lv = Prof_lv,reset = Reset ,skills = Skills,att = Att ,tmp_att = TmpAtt},
					update_ets(NewDeputyInfo),
					pp_deputy:handle(46000, Player, [Player#player.id]),
					erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(Player#player.other#player_other.pid, 531, [1]))end),%%神器成就判断
					Player#player{
								  other = Player#player.other#player_other {deputy_skill = Skills,deputy_prof_lv = Prof_lv}
								  };
				true ->
					Player
			end
	end.

%%增加神器的熟练值 用于每次战斗触发增加熟练度
add_deputy_equip_prof_val(PlayerId ,N) ->
	Pattern = #ets_deputy_equip{pid = PlayerId , _='_'},
	DeputyInfo = goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern),
	case is_record(DeputyInfo,ets_deputy_equip) of
		true ->
			Prof = DeputyInfo#ets_deputy_equip.prof,
			Prof_lv =  DeputyInfo#ets_deputy_equip.prof_lv,
			Prof_max = get_lv_prof_maxval(Prof_lv),
			if
				Prof + 1 < Prof_max ->
					NewProf = Prof + N;
				true ->
					NewProf = Prof_max
			end,
			NewDeputyInfo = DeputyInfo#ets_deputy_equip{prof = NewProf},
			%%数据库30点回写
			if
				NewProf rem 50 == 0 ->
					db_agent:mod_deputy_equip([{prof,NewProf}],[{id,DeputyInfo#ets_deputy_equip.id}]);
				true ->
					skip
			end,
			ets:insert(?ETS_DEPUTY_EQUIP, NewDeputyInfo);
		false ->
			skip
	end.

%%玩家退出游戏保存熟练度一直
do_logout(PlayerId) ->
	Pattern = #ets_deputy_equip{pid = PlayerId , _='_'},
	DeputyInfo = goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern),
	case is_record(DeputyInfo,ets_deputy_equip) of
		true ->
			%%删除神器信息
			ets:match_delete(?ETS_DEPUTY_EQUIP,#ets_deputy_equip{pid = PlayerId, _='_'}),
			%%保存数据库
			Prof = DeputyInfo#ets_deputy_equip.prof,
			db_agent:mod_deputy_equip([{prof,Prof}],[{id,DeputyInfo#ets_deputy_equip.id}]),
			ok;
		false ->
			skip
	end.

%%检查是否已经有神器
check_add_deputy_equip(PlayerId) ->
	Pattern = #ets_deputy_equip{pid = PlayerId , _='_'},
	DeputyInfo = goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern),
	case is_record(DeputyInfo,ets_deputy_equip) of
		true -> fail;
		false -> ok
	end.

%%排行榜神器tooltip信息请求
get_deputy_rank_tooltip_info(PlayerId) ->
	 case db_agent:get_online_player_deputy_equip(PlayerId) of
		 [] -> [];
		 [DeputyData] ->
			DeputyInfo = list_to_tuple([ets_deputy_equip]++DeputyData),
			%%把字符串转换成erlang格式
			Skills = util:string_to_term(tool:to_list(DeputyInfo#ets_deputy_equip.skills)),
			Att = util:string_to_term(tool:to_list(DeputyInfo#ets_deputy_equip.att)),
			TmpAtt = util:string_to_term(tool:to_list(DeputyInfo#ets_deputy_equip.tmp_att)),
			NewDeputyInfo = DeputyInfo#ets_deputy_equip{skills = Skills,att= Att ,tmp_att = TmpAtt},
			[
			 PlayerId,
			 get_deputy_equip_name(NewDeputyInfo#ets_deputy_equip.prof_lv), 
			 NewDeputyInfo#ets_deputy_equip.prof_lv,
			 NewDeputyInfo#ets_deputy_equip.color,
			 NewDeputyInfo#ets_deputy_equip.step,
			 NewDeputyInfo#ets_deputy_equip.skills,
			 NewDeputyInfo#ets_deputy_equip.att
			 ]
	 end.

%%检查潜能降级
checkDownDeputyStep(PlayerId) ->
	Pattern = #ets_deputy_equip{pid = PlayerId , _='_'},
	DeputyInfo = goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern),
	case is_record(DeputyInfo,ets_deputy_equip) of
		true ->
			if
				DeputyInfo#ets_deputy_equip.step =< 1->
					{fail,61};
				true ->
					Step = DeputyInfo#ets_deputy_equip.step,
					Color = DeputyInfo#ets_deputy_equip.color,
					[[Aid1,V1],[Aid2,V2],[Aid3,V3],[Aid4,V4]] = DeputyInfo#ets_deputy_equip.att,
					[_,Limit1,_,_] = data_deputy:get_wash_deputy_att(Step -1,Color,Aid1),
					[_,Limit2,_,_] = data_deputy:get_wash_deputy_att(Step -1,Color,Aid2),
					[_,Limit3,_,_] = data_deputy:get_wash_deputy_att(Step -1,Color,Aid3),
					[_,Limit4,_,_] = data_deputy:get_wash_deputy_att(Step -1,Color,Aid4),
					if
						Limit1 < V1 orelse Limit2 < V2 orelse Limit3 < V3 orelse Limit4 < V4 ->
							{fail,62};
						true ->
							{ok,1}
					end
			end;
		false ->
			{fail,63}
	end.
%%潜能降级
downDeputyStep(Player) ->
	PlayerId = Player#player.id,
	Pattern = #ets_deputy_equip{pid = PlayerId , _='_'},
	DeputyInfo = goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern),
	case is_record(DeputyInfo,ets_deputy_equip) of
		true ->	
			Step = DeputyInfo#ets_deputy_equip.step,
			if
				Step > 1 ->
					NewStep = Step -1;
				true ->
					NewStep = Step
			end,
			NewDeputyInfo = DeputyInfo#ets_deputy_equip{step = NewStep},
			update_ets(NewDeputyInfo),
			db_agent:mod_deputy_equip([{step,NewStep}],[{id,DeputyInfo#ets_deputy_equip.id}]),
			pp_deputy:handle(46000, Player, [PlayerId]);
		false ->
			skip
	end.
			
%%
%% Local Functions
%%

update_ets(DeputyInfo) ->
	ets:insert(?ETS_DEPUTY_EQUIP, DeputyInfo).

%% 获取熟练度等级对应最大熟练值
get_lv_prof_maxval(Lv)->
	case Lv of
		_ -> 10000
	end.

get_deputy_equip_name(Prof_lv) ->
	case Prof_lv of
		1 -> "炼妖壶";
		2 -> "昆仑镜";
		3 -> "女娲石";
		4 -> "神农鼎";
		5 -> "崆峒印";
		6 -> "昊天塔";
		7 -> "镇妖剑";
		_ -> "隐藏神器"
	end.

%%根据神器熟练等级返回 [发动概率 ，攻击力百分比]
get_deputy_attack_val(Prof_lv) ->
	case Prof_lv of
		1 -> [10,5];
		2 -> [15,10];
		3 -> [20, 16];
		4 -> [25 ,22];
		5 -> [30, 29];
		6 -> [35 , 36];
		7 -> [40 ,45];
		_ -> [0,0]
	end.
%%广播
broadcast(Type,Player,DeputyInfo) ->
	RealmName = goods_util:get_realm_to_name(Player#player.realm),
	Nickname = Player#player.nickname,
	PreDeputyName = get_deputy_equip_name(DeputyInfo#ets_deputy_equip.prof_lv -1 ),
	DeputyName = get_deputy_equip_name(DeputyInfo#ets_deputy_equip.prof_lv),
	ColorHexVal = goods_util:get_color_hex_value(DeputyInfo#ets_deputy_equip.color),
	NameColor = data_agent:get_realm_color(Player#player.realm),
	case Type of
		1 -> %%品质进阶
			if
				DeputyInfo#ets_deputy_equip.color == 3 ->
					Msg = io_lib:format("恭喜【<font color='~s'>~s</font>】玩家<font color='~s'>~s</font>的神器~s提升品质为<font color='#F8EF38'>金色</font>",["#FF0000",RealmName,NameColor,Nickname,DeputyName]);
				DeputyInfo#ets_deputy_equip.color == 4 ->
					Msg = io_lib:format("恭喜【<font color='~s'>~s</font>】玩家<font color='~s'>~s</font>的神器~s提升品质为<font color='#8800FF'>紫色</font>",["#FF0000",RealmName,NameColor,Nickname,DeputyName]);
				true ->
					Msg = ""
			end;
		2 -> %%等级进阶
			Msg = io_lib:format("恭喜【<font color='~s'>~s</font>】玩家<font color='~s'>~s</font>的神器<font color='~s'>~s</font>成功突破为 <font color='~s'>~s</font>",["#FF0000",RealmName,NameColor,Nickname,ColorHexVal,PreDeputyName,ColorHexVal,DeputyName])
	end,
	if 
		Msg /="" ->
			spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end);
	   	true ->
		   skip
	end.
					
%%获取品级幸运值最大值			
get_color_lucky_max(Color) ->
	case Color of
		0 -> 200;
		1 -> 500;
		2 -> 700;
		3 -> 1000;
		_ ->0
	end.
%%设置品级幸运值,不超过最大值
set_color_lucky_val(Color,Val) ->
	Max = get_color_lucky_max(Color),
	if
		Val > Max -> Max;
		true -> Val
	end.
%%获取品阶幸运值最大值
get_step_lucky_max(Step) ->
	case Step of
		1 -> 100;
		2 -> 100;
		3 -> 200;
		4 -> 200;
		5 -> 500;
		6 -> 500;
		_ -> 0
	end.
%%设置品阶幸运值,不超过最大值
set_step_lucky_val(Step,Val) ->
	Max = get_step_lucky_max(Step),
	if
		Val > Max -> Max;
		true -> Val
	end.
%% 获取突破瓶颈幸运值最大值
get_prof_lucky_max(Lv) ->
	case Lv of
		1 -> 200;
		2 -> 350;
		3 -> 700;
		4 -> 1000;
		5 -> 1000;
		6 -> 1500;
		_ -> 0
	end.
%%设置突破最大幸运值
set_prof_lucky_val(Lv,Val) ->
	Max = get_prof_lucky_max(Lv),
	if
		Val > Max -> Max;
		true -> Val
	end.
%% 是否初始属性值
is_init_att(AttList) ->
	[[_A1,V1] , [_A2,V2] , [_A3,V3] ,[_A4,V4]] = AttList,
	if
		[V1,V2,V3,V4] == [1,1,1,1] ->
			true;
		true ->
			false
	end.

%%统计神器战斗力 用于排行榜
count_deputy_batt_val(DeputyInfo) ->
	[[1,V_hp],[3,V_att],[4,V_def],[0,V_anti]] = DeputyInfo#ets_deputy_equip.att,
	Color = DeputyInfo#ets_deputy_equip.color,
	Step = DeputyInfo#ets_deputy_equip.step,
	Prof_lv = DeputyInfo#ets_deputy_equip.prof_lv,
	ColorR =
		case Color of
			0 -> 1;
			1 -> 2;
			2 -> 3;
			3 -> 4;
			4 -> 5;
			_ -> 0
		end,
	round((V_hp * 0.5 + V_att  + V_def + V_anti) + ((ColorR * 10)*(ColorR * 10) + (Step * 8) * (Step * 8) + (Prof_lv * 15)*(Prof_lv * 15))).


%% 获取神器的战斗力值，用于角色战斗力属性统计 返回整数
get_player_deputy_batt_val(Player) ->
	Pattern = #ets_deputy_equip{pid = Player#player.id , _='_'},
	DeputyInfo = goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern),
	case is_record(DeputyInfo ,ets_deputy_equip) of
		true ->
			get_player_deputy_batt_val(Player,DeputyInfo);
		false ->
			0
	end.

get_player_deputy_batt_val(Player,DeputyInfo)->
	[Tick_ratio ,Per_attack]= get_deputy_attack_val(DeputyInfo#ets_deputy_equip.prof_lv),
	View_attack = round((Player#player.max_attack + Player#player.min_attack) / 2 * (Per_attack / 100)),
	[[1,V_hp],[3,V_att],[4,V_def],[0,V_anti]] = DeputyInfo#ets_deputy_equip.att,
%%	?DEBUG("View_attack:~p        Tick_ratio:~p         V_hp:~p      V_att:~p        V_def:~p       V_anti:~p     total:~p~n",[View_attack,Tick_ratio,V_hp*0.06,V_att*0.8,V_def*0.04,V_anti*0.6,round(View_attack * Tick_ratio * 0.8 + (V_hp * 0.06 + V_att * 0.8 + V_def * 0.04 + V_anti * 0.12 * 5))]),
	round(View_attack * Tick_ratio * 0.8 * 0.01 + (V_hp * 0.06 + V_att * 0.8 + V_def * 0.04 + V_anti * 0.12 * 5)).

%%统计神器战斗力 用于角色战斗力属性统计 返回player
%% count_player_deputy_batt_val(Player,DeputyInfo) ->
%% 	Batt_val = get_player_deputy_batt_val(Player,DeputyInfo),
%% 	Player#player{other = Player#player.other#player_other{deputy_batt_val = Batt_val}}.

	
	