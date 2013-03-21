%% Author: xianrongMai
%% Created: 2011-6-20
%% Description: 成就系统模块处理
-module(lib_achieve).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("achieve.hrl").

%%
%% Exported Functions
%%
-export([
		 check_ach_foryg_target/2,		%% 远古目标获取成就数据判断(人物进程里调用)
		 init_achieve/2,				%% 初始化玩家成就系统数据
		 offline/1,						%%玩家下线清楚数据
		 check_achieve_finish/4,		%%检查各个成就是否成功完成
		 check_achieve_finish_cast/3,	%%检查各个成就是否成功完成(cast方式)
		 load_unload_pearl/4,			%% 38006
		 check_pearl/4,					%% 38006
		 get_ach_pearl_equipno/1, 	 	%% 38005
		 get_ach_pearl_equiped/1, 		%% 38004
		 get_achieves/1, 				%% 38000
		 get_achieve_log/1,				%% 38001
		 compare_ach_fslg/0,			%%离线挂机数据兼容性处理
		 kill_mon_achieve/5				%% 杀怪成就
		 ]).
%%
%% API Functions
%%
%% -----------------------------------------------------------------
%% 初始化玩家成就系统数据
%% -----------------------------------------------------------------
init_achieve(PlayerId, AchTitles) ->
	%%获取任务成就
	AchTask = db_agent:get_player_achieve(ach_task, PlayerId),
	%%获取神装成就
	AchEpic = db_agent:get_player_achieve(ach_epic, PlayerId),
	%%获取试炼成就
	AchTrials = db_agent:get_player_achieve(ach_trials, PlayerId),
	%%获取远古成就
	AchYg = db_agent:get_player_achieve(ach_yg, PlayerId),
	%%获取封神成就
	AchFs = db_agent:get_player_achieve(ach_fs, PlayerId),
	%%获取互动成就
	AchInteract = db_agent:get_player_achieve(ach_interact, PlayerId),
	%%获取奇珍异宝
	AchTreasure = db_agent:get_player_achieve(ach_treasure, PlayerId),
	AchIeveUpdate = init_achieve_ets(PlayerId, AchTask, AchEpic, AchTrials, AchYg, AchFs, AchInteract, AchTreasure, AchTitles),%%初始化ets
%%	?DEBUG("PlayerId:~p,~n AchTask:~p,~n AchEpic:~p,~n AchTrials:~p,~n AchYg:~p,~n AchFs:~p,~n AchInteract:~p,~n AchTreasure:~p,~n AchTitles:~p",
%%		   [PlayerId, AchTask, AchEpic, AchTrials, AchYg, AchFs, AchInteract, AchTreasure, AchTitles]),
	lib_achieve_inline:init_achieve_log(PlayerId),%%初始化玩家的成就日志
	AchIeveUpdate.

%%玩家下线清楚数据
offline(PlayerId) ->
%% 	?DEBUG("player offline, ~p", [PlayerId]),
	lib_achieve_outline:update_player_statistics(PlayerId),%%保存数据库
	Pattern = #ets_log_ach_f{pid = PlayerId, _ ='_'},
	ets:match_delete(?ACHIEVE_LOG,Pattern),
	ets:delete(?ACHIEVE_STATISTICS, PlayerId),
	ets:delete(?ETS_ACHIEVE, PlayerId).
%% 	?DEBUG("delete succeed!", []).

					
	
%%
%% Local Functions
%%
init_achieve_ets(PlayerId, AchTask, AchEpic, AchTrials, AchYg, AchFs, AchInteract, AchTreasure, AchTitles) ->
	%%初始化?ETS_ACHIEVE
	Achieve = #ets_achieve{pid = PlayerId},
	EtsAT = %%任务成就
		case AchTask =:= [] of
			true ->
				db_agent:insert_player_achieve(ach_task, ?ACH_TASK_FIELDS, [PlayerId|?ACH_TASK_INIT]),
				AchIeveUpdate = 0,
				Achieve;
			false ->
				%%做成就更新的标志
				AchIeveUpdate = 1,
				[_TId,_TPid|EtsAchTask] = AchTask,
				Achieve#ets_achieve{ach_task = EtsAchTask}
		end,
	EtsAE = %%神装成就
		case AchEpic =:= [] of
			true ->
				db_agent:insert_player_achieve(ach_epic, ?ACH_EPIC_FIELDS, [PlayerId|?ACH_EPIC_INIT]),
				EtsAT;
			false ->
				[_EId,_EPid|EtsAchEpic] = AchEpic,
				EtsAT#ets_achieve{ach_epic = EtsAchEpic}
		end,
	EtsATr = %%试炼成就
		case AchTrials =:= [] of
			true ->
				db_agent:insert_player_achieve(ach_trials, ?ACH_TRIALS_FIELDS, [PlayerId|?ACH_TRIALS_INIT]),
				EtsAE;
			false ->
				[_TRId,_TRPid|EtsAchTrials] = AchTrials,
				EtsAE#ets_achieve{ach_trials = EtsAchTrials}
		end,
	EtsAYg = %%远古成就
		case AchYg =:= [] of
			true ->
				db_agent:insert_player_achieve(ach_yg, ?ACH_YG_FIELDS, [PlayerId|?ACH_YG_INIT]),
				EtsATr;
			false ->
				[_YGId,_YGPid|EtsAchYg] = AchYg,
				EtsATr#ets_achieve{ach_yg = EtsAchYg}
		end,
	EtsAFs = %%封神成就
		case AchFs =:= [] of
			true ->
				db_agent:insert_player_achieve(ach_fs, ?ACH_FS_FIELDS, [PlayerId|?ACH_FS_INIT]),
				EtsAYg;
			false ->
				[_FSId,_FSPid|EtsAchFs] = AchFs,
				EtsAYg#ets_achieve{ach_fs = EtsAchFs}
		end,
	EtsAIn = %%互动成就
		case AchInteract =:= [] of
			true ->
				db_agent:insert_player_achieve(ach_interact, ?ACH_INTERACT_FIELDS, [PlayerId|?ACH_INTERACT_INIT]),
				EtsAFs;
			false ->
				[_INId,_INPid|EtsAchInteract] = AchInteract,
				EtsAFs#ets_achieve{ach_interact = EtsAchInteract}
		end,
	EtsATs = %%奇珍异宝
		case AchTreasure =:= [] of
			true ->
				db_agent:insert_player_achieve(ach_treasure, ?ACH_TREASURE_FIELDS, [PlayerId|?ACH_TREASURE_INIT]),
				EtsAIn;
			false ->
				[_TREASId,_TREASPid|EtsAchTreasure] = AchTreasure,
				EtsAIn#ets_achieve{ach_treasure = EtsAchTreasure}
		end,
	NewEts = EtsATs#ets_achieve{ach_titles = AchTitles},
	ets:insert(?ETS_ACHIEVE, NewEts),
	%%初始化?ACHIEVE_STATISTICS
	case db_agent:get_player_achieve(achieve_statistics, PlayerId) of
		[] ->
			{_, Id} = db_agent:insert_ach_stats(PlayerId),
			NewAchState = #ets_ach_stats{id = Id,
										 pid = PlayerId,
										 trb = [0,0,0,0,0,0],
										 trbc = [0,0,0],
										 trfst = [0,0,0],
										 trstd = [0,0,0],
										 trmtd = [0,0,0],
										 trfbb = [0,0,0,0],
										 fsb = [0,0,0],
										 fsc = [0,0],
										 fssa = [0,0],
										 trsixfb = [0,0,0],
										 trzxt = [0,0,0]
										 },
			ets:insert(?ACHIEVE_STATISTICS, NewAchState);
		[Id,Pid,Trc,Tg,Tfb,Tcul,Tca,Tbus,Tfst,Tcyc,TRm,TRb,TRbc,
		 TRbus,TRfst,TRar,TRf,TRstd,TRmtd,TRfbb,TRsixfb,TRzxt, TRsm,TRtrain,TRjl,TRds,TRgg,YgCul,
		 FSb,FSsh,FSc,FSsa,FSlg,INfl, INlv,INlved,INfai,INfao] ->
			NewAchState = #ets_ach_stats{id=Id,pid=Pid,trc=Trc,tg=Tg,tfb=Tfb,tcul=Tcul,tca=Tca,
										 tbus=Tbus,tfst=Tfst,tcyc=Tcyc,trm=TRm,
										 trb=util:string_to_term(tool:to_list(TRb)),
										 trbc=util:string_to_term(tool:to_list(TRbc)),
										 trbus=TRbus,
										 trfst=util:string_to_term(tool:to_list(TRfst)),
										 trar=TRar,trf=TRf,
										 trstd=util:string_to_term(tool:to_list(TRstd)),
										 trmtd=util:string_to_term(tool:to_list(TRmtd)),
										 trfbb=util:string_to_term(tool:to_list(TRfbb)),
										 trsixfb = util:string_to_term(tool:to_list(TRsixfb)),
										 trzxt = util:string_to_term(tool:to_list(TRzxt)),
										 trsm = TRsm,
										 trtrain = TRtrain,
										 trjl = TRjl,
										 trds = TRds,
										 trgg = TRgg,
										 ygcul = YgCul,
										 fsb=util:string_to_term(tool:to_list(FSb)),
										 fssh=FSsh,
										 fsc=util:string_to_term(tool:to_list(FSc)),
										 fssa=util:string_to_term(tool:to_list(FSsa)),
										 fslg=FSlg,
										 infl = INfl,inlv=INlv,inlved=INlved,
										 infai=INfai,infao=INfao},
			ets:insert(?ACHIEVE_STATISTICS, NewAchState)
	end,
	%%初始化鄙视和崇拜数据
	case catch(lib_achieve_inline:get_player_bscb(PlayerId)) of
		[BS,CB] ->
			put(player_bs, BS),
			put(player_cb, CB);
		[] ->
			put(player_bs, 0),
			put(player_cb, 0)
	end,
	AchIeveUpdate.

	
%%检查各个成就是否成功完成
%% Param:[Num],其中Num标志完成的任务数
%% 						%%任务成就
%% 101：完成新手任务
%% 102：完成日常打怪任务
%% 104：完成氏族任务
%% 107：完成副本任务
%% 10：完成修为任务
%% 112：完成运镖任务
%% 114：完成跑商任务
%% 116：完成封神贴任务
%% 118：完成循环任务
%%						%%神装成就
%% 201	装备一件时装
%% 202	装备一把【中阶锋芒灵石】任务的法宝
%% 203	装备一把四阶紫法宝					
%% 204	装备一把五阶紫法宝					
%% 205	装备一把六阶紫法宝					
%% 206	装备一把七阶紫法宝					
%% 207	装备任意一把+7的金色或紫色法宝		
%% 208	装备任意一把+8的金色或紫色法宝		
%% 209	装备任意一把+9的金色或紫色法宝		
%% 210	装备任意一把+10的金色或紫色法宝		
%% 211	装备一套30级诛邪套装				
%% 212	装备一套40级诛邪套装				
%% 213	装备一套50级诛邪套装				
%% 214	装备一套60级诛邪套装				
%% 215	装备一套40级的封神台紫装			
%% 216	装备一套50级的封神台紫装			
%% 217	装备全部六件+7的套装				
%% 218	装备全部六件+8的套装				
%% 219	装备全部六件+9的套装				
%% 220	装备全部六件+10的套装				
%% 221	镶嵌任意一颗3级宝石					
%% 222	镶嵌任意一颗5级宝石					
%% 223	镶嵌任意一颗7级宝石		
%% 						%%试炼成就
%% 301：击杀普通怪
%% 303：击杀火凤
%% 304：击杀千年老龟
%% 305：击杀烈焰麒麟兽
%% 306：击杀灵狐
%% 307：击杀裂地斧魔
%% 308：击杀千年猴妖
%% 309：成功劫镖
%% 310：成功劫商
%% 312：成功跑紫色商
%% 314：封神台12层通关
%% 315：封神台21层通关
%% 316：封神台45层通关
%% 317：远古战场杀人
%% 320：氏族战成功运旗
%% 323：单人镇妖台防守击败千年毒尸
%% 324：单人镇妖台防守击败龙骨甲兽
%% 325：单人镇妖台防守击败食腐树妖
%% 326：多人镇妖台防守击败千年毒尸
%% 327：多人镇妖台防守击败龙骨甲兽
%% 328：多人镇妖台防守击败食腐树妖
%% 329：击败雷公
%% 330：击败狐小小
%% 331：击败河伯
%% 332：击败蚩尤
%% 						%%远古成就
%% 401：等级达到40级		
%% 402：等级达到50级		
%% 403：等级达到60级		
%% 404：等级达到70级		
%% 405：拥有1000000铜币		
%% 406：拥有100000000铜币	
%% 407：修为达到10000		
%% 408：修为达到150000		
%% 409：修为达到500000		
%% 410：封神台荣誉达到10000	
%% 411：封神台荣誉达到100000
%% 412：封神台荣誉达到200000
%% 413：学会12个技能		
%% 414：12个技能全部学满级	
%% 415：3条经脉达到半人半神	
%% 416：1条经脉达到仙风道骨	
%% 417：3条经脉达到仙风道骨	
%% 418：8条经脉达到仙风道骨	
%% 419：8个经脉达到5级		
%% 420：8个经脉修炼到7级	
%% 421：8个经脉达到10级		
%% 422：8个经脉修炼到15级	
%% 						%%封神成就
%% 501：开百年诛邪
%% 502：开千年诛邪
%% 503：开万年诛邪
%% 504：成为vip
%% 505：商城购买道具
%% 506：合成宝石
%% 507：市场挂售物品
%% 508：市场购买物品
%% 509：炼炉分解物品
%% 510：离线挂机
%% 512：灵兽等级达到5级
%% 513：灵兽等级达到10级
%% 514：灵兽资质达到25级
%% 515：灵兽资质达到30	
%% 516：灵兽资质达到55	
%% 517：灵兽成长达到40
%% 518：灵兽成长达到50	
%% 519：灵兽成长达到60
%% 520：神兽相伴	获得一只化形后的灵兽
%% 						%%互动成就
%% 601	有1个徒弟出师
%% 602	有2个徒弟出师
%% 603	有3个徒弟出师
%% 604：加入氏族
%% 605：氏族贡献
%% 606	拥有5个好友
%% 607	拥有20个好友
%% 608	拥有30个好友
%% 609：赠送好友鲜花
%% 612：魅力值增加
%% 615：完成仙侣情缘
%% 617：仙侣情缘被邀请
%% 619：庄园收获
%% 621：庄园偷取
%% 623：庄园拥有9块地了
check_achieve_finish_cast(PlayerPid, AchId, Param) ->
%% 	?DEBUG("cast PlayerPid:~p, AchId:~p, Param:~p", [PlayerPid, AchId, Param]),
	case is_pid(PlayerPid) =:= true of
		true ->
			gen_server:cast(PlayerPid, {'UDATE_ACHIEVE', AchId, Param});
		false when is_integer(PlayerPid) =:= true ->
			case lib_player:get_player_pid(PlayerPid) of
				[] ->
					skip;
				Pid ->
					gen_server:cast(Pid, {'UDATE_ACHIEVE', AchId, Param})
			end;
		false ->
			skip
	end.
			

check_achieve_finish(PidSend, PlayerId, AchId, Param) ->
%% 	?DEBUG("PlayerId:~p, AchId:~p, Param:~p", [PlayerId, AchId, Param]),
	%%检测是否已经加载过 成就系统的数据
	lib_achieve_inline:check_achieve_init(PlayerId),
	case lib_achieve_inline:get_achieve_ets(PlayerId) of
		[] ->
			fail;
		[Achieve] ->
			AType = AchId div 100,
			ASType = AchId rem 100,
			Result =
				case AType of
					1 ->%%任务成就
						update_achieve_inline(PlayerId, Achieve, ach_task,ASType, Param);
					2 ->%%神装成就
						check_achieve_inline(ach_epic, Achieve, ASType, Param);
					3 ->%%试炼成就
						update_achieve_inline(PlayerId, Achieve, ach_trials, ASType, Param);
					4 ->%%远古成就
						update_achieve_inline(PlayerId, Achieve, ach_yg, ASType, Param);
					5 ->%%封神成就
						update_achieve_inline(PlayerId, Achieve, ach_fs, ASType, Param);
					6 ->%%互动成就
						update_achieve_inline(PlayerId, Achieve, ach_interact, ASType, Param);
%% 					7 ->%%奇珍异宝
%% 						check_achieve_inline(ach_treasure, Achieve, ASType, Param);
					_ ->
						fail
				end,
%% 			?DEBUG("Result:~p,AType:~p,ASType:~p", [Result,AType,ASType]),
			case Result of
				fail ->
					[];
				no_update ->
					[];
				ok ->
					[];
				{UpList, NewAchieve} ->
					case UpList of
						[] ->%%仅作奖励的判断
							_TRUpList = lib_achieve_inline:check_achieve_treasure(NewAchieve, PlayerId, 0, PidSend);
						_ExistUp ->
							AddAch = lib_achieve_inline:add_achieve_ach(AType,UpList),
%% 					?DEBUG("AType:~p, GET Ach NUM:~p", [AType, UpList]),
							%%做成就日志记录
							lib_achieve_inline:insert_achieve_log(AType, UpList, PlayerId),
							NAchieve = lib_achieve_inline:update_achieve_info_finish(AType, UpList, NewAchieve, PlayerId),
							_TRUpList = lib_achieve_inline:check_achieve_treasure(NAchieve, PlayerId, AddAch, PidSend),
							lib_achieve_outline:inform_ach_finish(PidSend, AType, UpList),%%通知更新
							UpList	
					end
			end
	end.
		
update_achieve_inline(PlayerId, Achieve, AchType, ASType, Param) ->
	case AchType of
		ach_task ->%%任务成就
			case update_achieve_task(PlayerId, Achieve#ets_achieve.ach_task, ASType, Param) of
				fail ->%%查询数据失败
					fail;
				no_update ->%%没成就完成的更新
					ok;
				{UpList, NewAchTask} ->
					NewAchieve = Achieve#ets_achieve{ach_task = NewAchTask},
%% 					update_achieve_ets(NewAchieve),
					{UpList,NewAchieve}
			end;
		ach_trials ->%%试炼成就
			case update_achieve_trials(PlayerId, Achieve#ets_achieve.ach_trials, ASType, Param) of
				fail ->%%查询数据失败
					fail;
				no_update ->%%仅是更新，但没有成就完成
					ok;
				{UpList, NewAchTrials} ->
					NewAchieve = Achieve#ets_achieve{ach_trials = NewAchTrials},
%% 					update_achieve_ets(NewAchieve),
					{UpList, NewAchieve}
			end;
		ach_yg ->%%远古成就
			case update_achieve_yg(PlayerId, Achieve#ets_achieve.ach_yg, ASType, Param) of
				fail ->%%查询数据失败
					fail;
				no_update ->%%仅是更新，但没有成就完成
					ok;
				{UpList, NewAchieveYG} ->
					NewAchieve = Achieve#ets_achieve{ach_yg = NewAchieveYG},
%% 					update_achieve_ets(NewAchieve),
					{UpList, NewAchieve}
			end;
		ach_fs ->%%封神成就
			case update_achieve_fs(PlayerId, Achieve#ets_achieve.ach_fs, ASType, Param) of
				fail ->%%查询数据失败
					fail;
				no_update ->%%仅是更新，但没有成就完成
					ok;
				{UpList, NewAchieveFS} ->
					NewAchieve = Achieve#ets_achieve{ach_fs = NewAchieveFS},
%% 					update_achieve_ets(NewAchieve),
					{UpList, NewAchieve}
			end;
		ach_interact ->%%互动成就
			case update_achieve_interact(PlayerId, Achieve#ets_achieve.ach_interact, ASType, Param) of
				fail ->%%查询数据失败
					fail;
				no_update ->%%仅是更新，但没有成就完成
					ok;
				{UpList, NewAchieveInteract} ->
					NewAchieve = Achieve#ets_achieve{ach_interact = NewAchieveInteract},
%% 					update_achieve_ets(NewAchieve),
					{UpList, NewAchieve}
			end;
		_ ->
			fail
	end.
check_achieve_inline(AchType, Achieve, ASType, Param) ->
	case AchType of
		ach_epic -> %%神装成就
			case check_achieve_epic(Achieve#ets_achieve.ach_epic, ASType, Param) of
				fail ->
					fail;
				no_update ->
					ok;
				ok ->
					ok;
				{UpList, NewAchEpic} ->
					NewAchieve = Achieve#ets_achieve{ach_epic = NewAchEpic},
			{UpList, NewAchieve}
			end;
%% 		ach_treasure -> %%奇珍异宝
%% 			check_achieve_treasure(ASType, Param);
		_ ->
			fail
	end.

%% =========================================================================
%% 各种类型的成就处理方法
%% =========================================================================
%%************		任务成就		************
%% 1 	初涉远古		完成所有新手引导任务			5	初涉远古
%% 2 	百炼成钢		完成10次日常守护打怪任务		20	百炼成钢
%% 3 	千锤百炼		完成100次日常守护打怪任务		40	千锤百炼
%% 4 	新丁磨练		完成30次氏族任务				20	新丁磨练
%% 5 	栋梁之材		完成200次氏族任务			40	栋梁之材
%% 6 	元老功臣		完成900次氏族任务			60	元老功臣
%% 7 	挑战副本		完成30次副本任务				20	挑战副本
%% 8 	通达副本		完成200副本任务				40	通达副本
%% 9 	征服副本		完成900次副本任务			60	征服副本
%% 10 	修炼伊始		完成30修为任务				20	修炼伊始
%% 11 	高深修行		完成120次修为任务			40	高深修行
%% 12 	新手镖师		完成30次运镖任务				20	新手镖师
%% 13 	生财有道		完成120次运镖任务			40	生财有道
%% 14 	跑商有道		完成30次跑商任务				20	跑商有道
%% 15 	跑商高手		完成120次跑商任务			40	跑商高手
%% 16 	封神灭妖		完成封神帖30次				20	封神灭妖
%% 17 	封神大会		完成封神帖任务120次			40	封神大会
%% 18 	远古畅游		完成循环任务450次			20	远古畅游
%% 19 	远古导游		完成循环任务4500次			40	远古导游
%% tf 	剑胆琴心		完成所有任务成就				100	剑胆琴心
update_achieve_task(PlayerId, AchTask, ASType, Param) ->
	[T1,T2,T3,T4,T5,T6,T7,T8,T9,T10,
	 T11,T12,T13,T14,T15,T16,T17,T18,T19,T20,
	 T21,T22,T23,T24,T25,T26,T27,T28] = AchTask,
%% 	?DEBUG("PlayerId:~p, ASType:~p, Param:~p", [PlayerId, ASType, Param]),
	case ets:lookup(?ACHIEVE_STATISTICS, PlayerId) of
		[] ->
			fail;
		[Achieve] ->
			Result = 
				if
					ASType =:= 1 andalso T1 =:= 0 ->%%新手
						NewAchTask = 
							[1,T2,T3,T4,T5,T6,T7,T8,T9,T10,
							 T11,T12,T13,T14,T15,T16,T17,T18,T19,T20,
							 T21,T22,T23,T24,T25,T26,T27,T28],
						{[1], NewAchTask};
					ASType =:= 2 orelse ASType =:= 3 orelse ASType =:= 20 ->%%日常任务
						[Num] = Param,
						TRC = Achieve#ets_ach_stats.trc,
						NewTRC = TRC + Num,
						if 
							NewTRC >= ?TASK_RC_TWO andalso (T2 =:= 0 orelse T3 =:= 0) ->
								%% 检查和更新 对应的字段
								{UpList, [NT2,NT3,NT20], _Rest} = check_and_update_list_update([20,3,2], [T2,T3,T20]),
								NewAchTask = [T1,NT2,NT3,T4,T5,T6,T7,T8,T9,T10,
											  T11,T12,T13,T14,T15,T16,T17,T18,T19,NT20,
											  T21,T22,T23,T24,T25,T26,T27,T28],
								NewAchieve = Achieve#ets_ach_stats{trc = NewTRC},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTask};
							NewTRC >= ?TASK_RC_ONE andalso T2 =:= 0 ->
								%% 检查和更新 对应的字段
								{UpList, [NT2,NT20], _Rest} = check_and_update_list_update([20,2], [T2,T20]),
								NewAchTask = [T1,NT2,T3,T4,T5,T6,T7,T8,T9,T10,
											  T11,T12,T13,T14,T15,T16,T17,T18,T19,NT20,
											  T21,T22,T23,T24,T25,T26,T27,T28],
								NewAchieve = Achieve#ets_ach_stats{trc = NewTRC},
								
%% 								NewAchTask = [T1,1,T3,T4,T5,T6,T7,T8,T9,T10,
%% 											  T11,T12,T13,T14,T15,T16,T17,T18,T19,T20],
%% 								NewAchieve = Achieve#ets_ach_stats{trc = NewTRC},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTask};
							true ->
%% 								io:format("true task : ~p\n", [AchTask]),
								if 
									T20 =:= 0 andalso NewTRC > 0 ->
										NewAchTask = [T1,T2,T3,T4,T5,T6,T7,T8,T9,T10,
													  T11,T12,T13,T14,T15,T16,T17,T18,T19,1,
													  T21,T22,T23,T24,T25,T26,T27,T28],
										UpList = [20];
									true ->
										NewAchTask = AchTask,
										UpList = []
								end,
								case T2 =:= 0 orelse T3 =:= 0 of
									true ->
										NewAchieve = Achieve#ets_ach_stats{trc = NewTRC},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve);
									false ->
										skip
								end,
								{UpList, NewAchTask}
						end;
					ASType =:= 4 orelse ASType =:= 5 orelse ASType =:= 6 orelse ASType =:= 21->%%氏族任务
						[Num] = Param,
						TG = Achieve#ets_ach_stats.tg,
						NewTG = TG + Num,
						if 
							NewTG >= ?TASK_GUILD_THREE andalso (T4 =:= 0 orelse T5 =:= 0 orelse T6 =:= 0) ->
								%% 检查和更新 对应的字段
								{UpList, [NT4,NT5,NT6,NT21], _Rest} = check_and_update_list_update([21, 6,5,4], [T4,T5,T6,T21]),
								NewAchTask = [T1,T2,T2,NT4,NT5,NT6,T7,T8,T9,T10,
											  T11,T12,T13,T14,T15,T16,T17,T18,T19,T20,
											  NT21,T22,T23,T24,T25,T26,T27,T28],
								NewAchieve = Achieve#ets_ach_stats{tg = NewTG},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTask};
							NewTG >= ?TASK_GUILD_TWO andalso (T4 =:= 0 orelse T5 =:= 0 ) ->
								%% 检查和更新 对应的字段
								{UpList, [NT4,NT5,NT21], _Rest} = check_and_update_list_update([21,5,4], [T4,T5,T21]),
								NewAchTask = [T1,T2,T2,NT4,NT5,T6,T7,T8,T9,T10,
											  T11,T12,T13,T14,T15,T16,T17,T18,T19,T20,
											  NT21,T22,T23,T24,T25,T26,T27,T28],
								NewAchieve = Achieve#ets_ach_stats{tg = NewTG},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTask};
							NewTG >= ?TASK_GUILD_ONE andalso  T4 =:= 0 ->
								%% 检查和更新 对应的字段
								{UpList, [NT4,NT21], _Rest} = check_and_update_list_update([21,4], [T4,T21]),
								NewAchTask = [T1,T2,T2,NT4,T5,T6,T7,T8,T9,T10,
											  T11,T12,T13,T14,T15,T16,T17,T18,T19,T20,
											  NT21,T22,T23,T24,T25,T26,T27,T28],
								NewAchieve = Achieve#ets_ach_stats{tg = NewTG},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTask};
							true ->
								if 
									T21 =:= 0 andalso NewTG > 0 ->
										NewAchTask = [T1,T2,T3,T4,T5,T6,T7,T8,T9,T10,
													  T11,T12,T13,T14,T15,T16,T17,T18,T19,T20,
													  1,T22,T23,T24,T25,T26,T27,T28],
										UpList = [21];
									true ->
										NewAchTask = AchTask,
										UpList = []
								end,
								case T4 =:= 0 orelse T5 =:= 0 orelse T6 =:= 0 of
									true ->
										NewAchieve = Achieve#ets_ach_stats{tg = NewTG},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve);
									false ->
										skip
								end,
								{UpList, NewAchTask}
						end;
					ASType =:= 7 orelse ASType =:= 8 orelse ASType =:= 9 orelse ASType =:= 22 ->%%副本任务
						[Num] = Param,
						TFB = Achieve#ets_ach_stats.tfb,
						NewTFB = TFB + Num,
						if 
							NewTFB >= ?TASK_FB_THREE andalso (T7 =:= 0 orelse T8 =:= 0 orelse T9 =:= 0) ->
								%% 检查和更新 对应的字段
								{UpList, [NT7,NT8,NT9,NT22], _Rest} = check_and_update_list_update([22,9,8,7], [T7,T8,T9,T22]),
								NewAchTask = [T1,T2,T2,T4,T5,T6,NT7,NT8,NT9,T10,
											  T11,T12,T13,T14,T15,T16,T17,T18,T19,T20,
											  T21,NT22,T23,T24,T25,T26,T27,T28],
								NewAchieve = Achieve#ets_ach_stats{tfb = NewTFB},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTask};
							NewTFB >= ?TASK_FB_TWO andalso (T7 =:= 0 orelse T8 =:= 0)->
								%% 检查和更新 对应的字段
								{UpList, [NT7,NT8,NT22], _Rest} = check_and_update_list_update([22,8,7], [T7,T8,T22]),
								NewAchTask = [T1,T2,T2,T4,T5,T6,NT7,NT8,T9,T10,
											  T11,T12,T13,T14,T15,T16,T17,T18,T19,T20,
											  T21,NT22,T23,T24,T25,T26,T27,T28],
								NewAchieve = Achieve#ets_ach_stats{tfb = NewTFB},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTask};
							NewTFB >= ?TASK_FB_ONE andalso T7 =:= 0 ->
								%% 检查和更新 对应的字段
								{UpList, [NT7,NT22], _Rest} = check_and_update_list_update([22,7], [T7,T22]),
								NewAchTask = [T1,T2,T2,T4,T5,T6,NT7,T8,T9,T10,
											  T11,T12,T13,T14,T15,T16,T17,T18,T19,T20,
											  T21,NT22,T23,T24,T25,T26,T27,T28],
								NewAchieve = Achieve#ets_ach_stats{tfb = NewTFB},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTask};
							true ->
								if 
									T22 =:= 0 andalso NewTFB > 0 ->
										NewAchTask = [T1,T2,T3,T4,T5,T6,T7,T8,T9,T10,
													  T11,T12,T13,T14,T15,T16,T17,T18,T19,T20,
													  T21,1,T23,T24,T25,T26,T27,T28],
										UpList = [22];
									true ->
										NewAchTask = AchTask,
										UpList = []
								end,
								case T7 =:= 0 orelse T8 =:= 0 orelse T9 =:= 0 of
									true ->
										NewAchieve = Achieve#ets_ach_stats{tfb = NewTFB},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve);
									false ->
										skip
								end,
								{UpList, NewAchTask}
						end;
					ASType =:= 10 orelse ASType =:= 11 orelse ASType =:= 23 ->%%修为任务
						[Num] = Param,
						TCUL = Achieve#ets_ach_stats.tcul,
						NewTCUL = TCUL + Num,
						if 	
							NewTCUL >= ?TASK_CULTURE_TWO andalso (T10 =:= 0 orelse T11 =:= 0) ->
								%% 检查和更新 对应的字段
								{UpList, [NT10,NT11,NT23], _Rest} = check_and_update_list_update([23,11,10], [T10,T11,T23]),
								NewAchTask = [T1,T2,T3,T4,T5,T6,T7,T8,T9,NT10,
											  NT11,T12,T13,T14,T15,T16,T17,T18,T19,T20,
											  T21,T22,NT23,T24,T25,T26,T27,T28],
								NewAchieve = Achieve#ets_ach_stats{tcul = NewTCUL},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTask};
							NewTCUL >= ?TASK_CULTURE_ONE andalso T10 =:= 0 ->
								{UpList, [NT10,NT23], _Rest} = check_and_update_list_update([23,10], [T10,T23]),
								NewAchTask = [T1,T2,T3,T4,T5,T6,T7,T8,T9,NT10,
											  T11,T12,T13,T14,T15,T16,T17,T18,T19,T20,
											  T21,T22,NT23,T24,T25,T26,T27,T28],
								NewAchieve = Achieve#ets_ach_stats{tcul = NewTCUL},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTask};
							true ->
								if 
									T23 =:= 0 andalso NewTCUL > 0 ->
										NewAchTask = [T1,T2,T3,T4,T5,T6,T7,T8,T9,T10,
													  T11,T12,T13,T14,T15,T16,T17,T18,T19,T20,
													  T21,T22,1,T24,T25,T26,T27,T28],
										UpList = [23];
									true ->
										NewAchTask = AchTask,
										UpList = []
								end,
								case T10 =:= 0 orelse T11 =:= 0 of
									true ->
										NewAchieve = Achieve#ets_ach_stats{tcul = NewTCUL},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve);
									false ->
										skip
								end,
								{UpList, NewAchTask}
						end;
					ASType =:= 12 orelse ASType =:= 13 orelse ASType =:= 24 -> %%运镖任务
						[Num] = Param,
						TCA = Achieve#ets_ach_stats.tca,
						NewTCA = TCA + Num,
						if 	
							NewTCA >= ?TASK_CARRY_TWO andalso (T12 =:= 0 orelse T13 =:= 0) ->
								%% 检查和更新 对应的字段
								{UpList, [NT12,NT13,NT24], _Rest} = check_and_update_list_update([24,13,12], [T12,T13,T24]),
								NewAchTask = [T1,T2,T3,T4,T5,T6,T7,T8,T9,T10,
											  T11,NT12,NT13,T14,T15,T16,T17,T18,T19,T20,
											  T21,T22,T23,NT24,T25,T26,T27,T28],
								NewAchieve = Achieve#ets_ach_stats{tca = NewTCA},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTask};
							NewTCA >= ?TASK_CARRY_ONE  andalso T12 =:= 0 ->
								%% 检查和更新 对应的字段
								{UpList, [NT12,NT24], _Rest} = check_and_update_list_update([24,12], [T12,T24]),
								NewAchTask = [T1,T2,T3,T4,T5,T6,T7,T8,T9,T10,
											  T11,NT12,T13,T14,T15,T16,T17,T18,T19,T20,
											  T21,T22,T23,NT24,T25,T26,T27,T28],
								NewAchieve = Achieve#ets_ach_stats{tca = NewTCA},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTask};
							true ->
								if 
									T24 =:= 0 andalso NewTCA > 0 ->
										NewAchTask = [T1,T2,T3,T4,T5,T6,T7,T8,T9,T10,
													  T11,T12,T13,T14,T15,T16,T17,T18,T19,T20,
													  T21,T22,T23,1,T25,T26,T27,T28],
										UpList = [24];
									true ->
										NewAchTask = AchTask,
										UpList = []
								end,
								case T12 =:= 0 orelse T13 =:= 0 of
									true ->
										NewAchieve = Achieve#ets_ach_stats{tca = NewTCA},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve);
									false ->
										skip
								end,
								{UpList, NewAchTask}
						end;
					ASType =:= 14 orelse ASType =:= 15 orelse ASType =:= 25 -> %%跑商任务
						[Num] = Param,
						TBUS = Achieve#ets_ach_stats.tbus,
						NewTBUS = TBUS + Num,
						if 
							NewTBUS >= ?TASK_BUS_TWO andalso (T14 =:= 0 orelse T15 =:= 0) ->
								%% 检查和更新 对应的字段
								{UpList, [NT14,NT15,NT25], _Rest} = check_and_update_list_update([25,15,14], [T14,T15,T25]),
								NewAchTask = [T1,T2,T3,T4,T5,T6,T7,T8,T9,T10,
											  T11,T12,T13,NT14,NT15,T16,T17,T18,T19,T20,
											  T21,T22,T23,T24,NT25,T26,T27,T28],
								NewAchieve = Achieve#ets_ach_stats{tbus = NewTBUS},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTask};
							NewTBUS >= ?TASK_BUS_ONE andalso T14 =:= 0 ->
								%% 检查和更新 对应的字段
								{UpList, [NT14,NT25], _Rest} = check_and_update_list_update([25,14], [T14,T25]),
								NewAchTask = [T1,T2,T3,T4,T5,T6,T7,T8,T9,T10,
											  T11,T12,T13,NT14,T15,T16,T17,T18,T19,T20,
											  T21,T22,T23,T24,NT25,T26,T27,T28],
								NewAchieve = Achieve#ets_ach_stats{tbus = NewTBUS},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTask};
							true ->
								if 
									T25 =:= 0 andalso NewTBUS > 0 ->
										NewAchTask = [T1,T2,T3,T4,T5,T6,T7,T8,T9,T10,
													  T11,T12,T13,T14,T15,T16,T17,T18,T19,T20,
													  T21,T22,T23,T24,1,T26,T27,T28],
										UpList = [25];
									true ->
										NewAchTask = AchTask,
										UpList = []
								end,
								case T14 =:= 0 orelse T15 =:= 0 of
									true ->
										NewAchieve = Achieve#ets_ach_stats{tbus = NewTBUS},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve);
									false ->
										skip
								end,
								{UpList, NewAchTask}
						end;
					ASType =:= 16 orelse ASType =:= 17 orelse ASType =:= 26 ->%%封神贴任务
						[Num] = Param,
						TFST = Achieve#ets_ach_stats.tfst,
						NewTFST = TFST + Num,
						if 
							NewTFST >= ?TASK_FST_TWO andalso (T16 =:= 0 orelse T17 =:= 0) ->
								%% 检查和更新 对应的字段
								{UpList, [NT16,NT17,NT26], _Rest} = check_and_update_list_update([26,17,16], [T16,T17,T26]),
								NewAchTask = [T1,T2,T3,T4,T5,T6,T7,T8,T9,T10,
											  T11,T12,T13,T14,T15,NT16,NT17,T18,T19,T20,
											  T21,T22,T23,T24,T25,NT26,T27,T28],
								NewAchieve = Achieve#ets_ach_stats{tfst = NewTFST},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTask};
							NewTFST >= ?TASK_FST_ONE andalso T16 =:= 0 ->
								%% 检查和更新 对应的字段
								{UpList, [NT16,NT26], _Rest} = check_and_update_list_update([26,16], [T16,T26]),
								NewAchTask = [T1,T2,T3,T4,T5,T6,T7,T8,T9,T10,
											  T11,T12,T13,T14,T15,NT16,T17,T18,T19,T20,
											  T21,T22,T23,T24,T25,NT26,T27,T28],
								NewAchieve = Achieve#ets_ach_stats{tfst = NewTFST},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTask};
							true ->
								if 
									T26 =:= 0 andalso NewTFST > 0 ->
										NewAchTask = [T1,T2,T3,T4,T5,T6,T7,T8,T9,T10,
													  T11,T12,T13,T14,T15,T16,T17,T18,T19,T20,
													  T21,T22,T23,T24,T25,1,T27,T28],
										UpList = [26];
									true ->
										NewAchTask = AchTask,
										UpList = []
								end,
								case T16 =:= 0 orelse T17 =:= 0 of
									true ->
										NewAchieve = Achieve#ets_ach_stats{tfst = NewTFST},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve);
									false ->
										skip
								end,
								{UpList, NewAchTask}
						end;
					ASType =:= 18 orelse ASType =:= 19 orelse ASType =:= 27 ->%%循环任务
						[Num] = Param,
						TCYC = Achieve#ets_ach_stats.tcyc,
						NewTCYC = TCYC + Num,
						if 
							NewTCYC >= ?TASK_CYCLE_TWO andalso (T18 =:= 0 orelse T19 =:= 0) ->
								%% 检查和更新 对应的字段
								{UpList, [NT18,NT19,NT27], _Rest} = check_and_update_list_update([27,19,18], [T18,T19,T27]),
								NewAchTask = [T1,T2,T3,T4,T5,T6,T7,T8,T9,T10,
											  T11,T12,T13,T14,T15,T16,T17,NT18,NT19,T20,
											  T21,T22,T23,T24,T25,T26,NT27,T28],
								NewAchieve = Achieve#ets_ach_stats{tcyc = NewTCYC},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTask};
							NewTCYC >= ?TASK_CYCLE_ONE andalso T18 =:= 0 ->
								%% 检查和更新 对应的字段
								{UpList, [NT18,NT27], _Rest} = check_and_update_list_update([27,18], [T18,T27]),
								NewAchTask = [T1,T2,T3,T4,T5,T6,T7,T8,T9,T10,
											  T11,T12,T13,T14,T15,T16,T17,NT18,T19,T20,
											  T21,T22,T23,T24,T25,T26,NT27,T28],
								NewAchieve = Achieve#ets_ach_stats{tcyc = NewTCYC},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTask};
							true ->
								if 
									T27 =:= 0 andalso NewTCYC > 0 ->
										NewAchTask = [T1,T2,T3,T4,T5,T6,T7,T8,T9,T10,
													  T11,T12,T13,T14,T15,T16,T17,T18,T19,T20,
													  T21,T22,T23,T24,T25,T26,1,T28],
										UpList = [27];
									true ->
										NewAchTask = AchTask,
										UpList = []
								end,
								case T18 =:= 0 orelse T19 =:= 0 of
									true ->
										NewAchieve = Achieve#ets_ach_stats{tcyc = NewTCYC},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve);
									false ->
										skip
								end,
								{UpList, NewAchTask}
						end;
					ASType =:= 28 ->%%最后一个任务成就
						{[], AchTask};
					true ->
						{[], AchTask}
				end,
			{RUpList, RNewAchTask} = Result,
			[RT1,RT2,RT3,RT4,RT5,RT6,RT7,RT8,RT9,RT10,
			 RT11,RT12,RT13,RT14,RT15,RT16,RT17,RT18,RT19,RT20,
			 RT21,RT22,RT23,RT24,RT25,RT26,RT27,RT28] = AchTask,
			case lib_achieve_inline:check_final_ok(length(RNewAchTask)-1, RNewAchTask, true) andalso RT28 =:= 0 of
				true ->
					{[28|RUpList],[RT1,RT2,RT3,RT4,RT5,RT6,RT7,RT8,RT9,RT10,
								   RT11,RT12,RT13,RT14,RT15,RT16,RT17,RT18,RT19,RT20,
								   RT21,RT22,RT23,RT24,RT25,RT26,RT27,1]};
				false ->
					Result
			end
	end.
	
%%************		神装成就		************
%% 1	时髦神装		装备一件时装							20	时髦神装
%% 2	神兵			装备一把【神兵利器】任务的法宝		10	神兵
%% 3	旷世神刃		装备一把四阶紫法宝					10	旷世神刃
%% 4	旷世神武		装备一把五阶紫法宝					20	旷世神武
%% 5	旷世神兵		装备一把六阶紫法宝					40	旷世神兵
%% 6	旷世神器		装备一把七阶紫法宝					60	旷世神器
%% 7	铸造大王		装备任意一把+7的金色或紫色法宝		20	铸造大王
%% 8	铸造大师		装备任意一把+8的金色或紫色法宝		40	铸造大师
%% 9	铸造大仙		装备任意一把+9的金色或紫色法宝		60	铸造大仙
%% 10	铸造大神		装备任意一把+10的金色或紫色法宝		80	铸造大神
%% 11	神兵利器		装备一套30级诛邪套装					20	神兵利器
%% 12	神兵王器		装备一套40级诛邪套装					40	神兵王器
%% 13	神兵仙器		装备一套50级诛邪套装					60	神兵仙器
%% 14	神兵神器		装备一套60级诛邪套装					80	神兵神器
%% 15	封神神装		装备一套40级的封神台紫装				15	封神神装
%% 16	封神神装		装备一套50级的封神台紫装				30	封神神装
%% 17	铸甲大王		装备全部六件+7的套装					20	铸甲大王
%% 18	铸甲大师		装备全部六件+8的套装					40	铸甲大师
%% 19	铸甲大仙		装备全部六件+9的套装					60	铸甲大仙
%% 20	铸甲大神		装备全部六件+10的套装					80	铸甲大神
%% 21	宝石3		镶嵌任意一颗3级宝石					10	
%% 22	宝石5		镶嵌任意一颗5级宝石					40	
%% 23	宝石7		镶嵌任意一颗7级宝石					80	
%% 24	天下无双		达成所有神装成就						100	天下无双

check_achieve_epic(AchEpic, ASType, _Param) ->
	[E1,E2,E3,E4,E5,E6,E7,E8,E9,E10,
	 E11,E12,E13,E14,E15,E16,E17,E18,E19,E20,
	 E21,E22,E23,E24,E25,E26,E27,Ef] = AchEpic,
	Result = 
	if
		ASType =:= 1 andalso E1 =:= 0->%%时装
			NewAchEpic = [1,E2,E3,E4,E5,E6,E7,E8,E9,E10,
						  E11,E12,E13,E14,E15,E16,E17,E18,E19,E20,
						  E21,E22,E23,E24,E25,E26,E27,Ef],
			{[1], NewAchEpic};
		ASType =:= 2 andalso E2 =:= 0 ->%%装备一把【神兵利器】任务的法宝
			NewAchEpic = [E1,1,E3,E4,E5,E6,E7,E8,E9,E10,
						  E11,E12,E13,E14,E15,E16,E17,E18,E19,E20,
						  E21,E22,E23,E24,E25,E26,E27,Ef],
			{[2], NewAchEpic};
		ASType =:= 3 andalso E3 =:= 0 ->%%装备一把四阶紫法宝
			NewAchEpic = [E1,E2,1,E4,E5,E6,E7,E8,E9,E10,
						  E11,E12,E13,E14,E15,E16,E17,E18,E19,E20,
						  E21,E22,E23,E24,E25,E26,E27,Ef],
			{[3], NewAchEpic};
		ASType =:= 4 andalso E4 =:= 0 ->%%装备一把五阶紫法宝
			NewAchEpic = [E1,E2,E3,1,E5,E6,E7,E8,E9,E10,
						  E11,E12,E13,E14,E15,E16,E17,E18,E19,E20,
						  E21,E22,E23,E24,E25,E26,E27,Ef],
			{[4], NewAchEpic};
		ASType =:= 5 andalso E5 =:= 0 ->%%装备一把六阶紫法宝
			NewAchEpic = [E1,E2,E3,E4,1,E6,E7,E8,E9,E10,
						  E11,E12,E13,E14,E15,E16,E17,E18,E19,E20,
						  E21,E22,E23,E24,E25,E26,E27,Ef],
			{[5], NewAchEpic};
		ASType =:= 6 andalso E6 =:= 0 ->%%装备一把七阶紫法宝
			NewAchEpic = [E1,E2,E3,E4,E5,1,E7,E8,E9,E10,
						  E11,E12,E13,E14,E15,E16,E17,E18,E19,E20,
						  E21,E22,E23,E24,E25,E26,E27,Ef],
			{[6], NewAchEpic};
		ASType =:= 7 andalso E7 =:= 0 ->%%装备任意一把+7的金色或紫色法宝
			NewAchEpic = [E1,E2,E3,E4,E5,E6,1,E8,E9,E10,
						  E11,E12,E13,E14,E15,E16,E17,E18,E19,E20,
						  E21,E22,E23,E24,E25,E26,E27,Ef],
			{[7], NewAchEpic};
		ASType =:= 8  andalso (E8 =:= 0 orelse E7 =:= 0) ->%%装备任意一把+8的金色或紫色法宝
			%% 检查和更新 对应的字段
			{UpList, [NE7,NE8], _Rest} = check_and_update_list_update([8,7], [E7,E8]),
			NewAchEpic = 
				[E1,E2,E3,E4,E5,E6,NE7,NE8,E9,E10,
				 E11,E12,E13,E14,E15,E16,E17,E18,E19,E20,
				 E21,E22,E23,E24,E25,E26,E27,Ef],
			{UpList, NewAchEpic};
		ASType =:= 9  andalso (E9 =:= 0 orelse E8 =:= 0 orelse E7 =:= 0) ->%%装备任意一把+9的金色或紫色法宝
			%% 检查和更新 对应的字段
			{UpList, [NE7,NE8,NE9], _Rest} = check_and_update_list_update([9,8,7], [E7,E8,E9]),
			NewAchEpic = 
				[E1,E2,E3,E4,E5,E6,NE7,NE8,NE9,E10,
				 E11,E12,E13,E14,E15,E16,E17,E18,E19,E20,
				 E21,E22,E23,E24,E25,E26,E27,Ef],
			{UpList, NewAchEpic};
		ASType =:= 10 andalso (E10 =:= 0 orelse E9 =:= 0 orelse E8 =:= 0 orelse E7 =:= 0) ->%%装备任意一把+10的金色或紫色法宝
			%% 检查和更新 对应的字段
			{UpList, [NE7,NE8,NE9,NE10], _Rest} = check_and_update_list_update([10,9,8,7], [E7,E8,E9,E10]),
			NewAchEpic = 
				[E1,E2,E3,E4,E5,E6,NE7,NE8,NE9,NE10,
				 E11,E12,E13,E14,E15,E16,E17,E18,E19,E20,
				 E21,E22,E23,E24,E25,E26,E27,Ef],
			{UpList, NewAchEpic};
		ASType =:= 11 andalso E11 =:= 0 ->%%装备一套30级诛邪套装
			NewAchEpic = [E1,E2,E3,E4,E5,E6,E7,E8,E9,E10,
						  1,E12,E13,E14,E15,E16,E17,E18,E19,E20,
						  E21,E22,E23,E24,E25,E26,E27,Ef],
			{[11], NewAchEpic};
		ASType =:= 12 andalso E12 =:= 0 ->%%装备一套40级诛邪套装
			NewAchEpic = [E1,E2,E3,E4,E5,E6,E7,E8,E9,E10,
						  E11,1,E13,E14,E15,E16,E17,E18,E19,E20,
						  E21,E22,E23,E24,E25,E26,E27,Ef],
			{[12], NewAchEpic};
		ASType =:= 13 andalso E13 =:= 0 ->%%装备一套50级诛邪套装
			NewAchEpic = [E1,E2,E3,E4,E5,E6,E7,E8,E9,E10,
						  E11,E12,1,E14,E15,E16,E17,E18,E19,E20,
						  E21,E22,E23,E24,E25,E26,E27,Ef],
			{[13], NewAchEpic};
		ASType =:= 14 andalso E14 =:= 0->%%装备一套60级诛邪套装
			NewAchEpic = [E1,E2,E3,E4,E5,E6,E7,E8,E9,E10,
						  E11,E12,E13,1,E15,E16,E17,E18,E19,E20,
						  E21,E22,E23,E24,E25,E26,E27,Ef],
			{[14], NewAchEpic};
		ASType =:= 15 andalso E15 =:= 0 ->%%装备一套40级的封神台紫装
			NewAchEpic = [E1,E2,E3,E4,E5,E6,E7,E8,E9,E10,
						  E11,E12,E13,E14,1,E16,E17,E18,E19,E20,
						  E21,E22,E23,E24,E25,E26,E27,Ef],
			{[15], NewAchEpic};
		ASType =:= 16 andalso E16 =:= 0 -> %%装备一套50级的封神台紫装
			NewAchEpic = [E1,E2,E3,E4,E5,E6,E7,E8,E9,E10,
						  E11,E12,E13,E14,E15,1,E17,E18,E19,E20,
						  E21,E22,E23,E24,E25,E26,E27,Ef],
			{[16], NewAchEpic};
		ASType =:= 17 andalso E17 =:= 0 ->%%装备全部六件+7的套装	
			NewAchEpic = [E1,E2,E3,E4,E5,E6,E7,E8,E9,E10,
						  E11,E12,E13,E14,E15,E16,1,E18,E19,E20,
						  E21,E22,E23,E24,E25,E26,E27,Ef],
			{[17], NewAchEpic};
		ASType =:= 18 andalso (E18 =:= 0 orelse E17 =:= 0)->%%装备全部六件+8的套装
			%% 检查和更新 对应的字段
			{UpList, [NE17,NE18], _Rest} = check_and_update_list_update([18,17], [E17,E18]),
			NewAchEpic = 
				[E1,E2,E3,E4,E5,E6,E7,E8,E9,E10,
				 E11,E12,E13,E14,E15,E16,NE17,NE18,E19,E20,
				 E21,E22,E23,E24,E25,E26,E27,Ef],
			{UpList, NewAchEpic};
		ASType =:=19 andalso (E19 =:= 0 orelse E18 =:= 0 orelse E17 =:= 0) ->%%装备全部六件+9的套装
			%% 检查和更新 对应的字段
			{UpList, [NE17,NE18,NE19], _Rest} = check_and_update_list_update([19,18,17], [E17,E18,E19]),
			NewAchEpic = 
				[E1,E2,E3,E4,E5,E6,E7,E8,E9,E10,
				 E11,E12,E13,E14,E15,E16,NE17,NE18,NE19,E20,
				 E21,E22,E23,E24,E25,E26,E27,Ef],
			{UpList, NewAchEpic};
		ASType =:=20 andalso (E20 =:= 0 orelse E19 =:= 0 orelse E18 =:= 0 orelse E17 =:= 0) -> %%装备全部六件+10的套装
			%% 检查和更新 对应的字段
			{UpList, [NE17,NE18,NE19,NE20], _Rest} = check_and_update_list_update([20,19,18,17], [E17,E18,E19,E20]),
			NewAchEpic = 
				[E1,E2,E3,E4,E5,E6,E7,E8,E9,E10,
				 E11,E12,E13,E14,E15,E16,NE17,NE18,NE19,NE20,
				 E21,E22,E23,E24,E25,E26,E27,Ef],
			{UpList, NewAchEpic};
		ASType =:= 21 andalso E21 =:= 0 ->%%镶嵌任意一颗3级宝石
			NewAchEpic = [E1,E2,E3,E4,E5,E6,E7,E8,E9,E10,
						  E11,E12,E13,E14,E15,E16,E17,E18,E19,E20,
						  1,E22,E23,E24,E25,E26,E27,Ef],
			{[21], NewAchEpic};
		ASType =:= 22 andalso E22 =:= 0 ->%%镶嵌任意一颗5级宝石
			NewAchEpic = [E1,E2,E3,E4,E5,E6,E7,E8,E9,E10,
						  E11,E12,E13,E14,E15,E16,E17,E18,E19,E20,
						  E21,1,E23,E24,E25,E26,E27,Ef],
			{[22], NewAchEpic};
		ASType =:= 23 andalso E23 =:= 0 ->%%镶嵌任意一颗3级宝石
			NewAchEpic = [E1,E2,E3,E4,E5,E6,E7,E8,E9,E10,
						  E11,E12,E13,E14,E15,E16,E17,E18,E19,E20,
						  E21,E22,1,E24,E25,E26,E27,Ef],
			{[23], NewAchEpic};
		ASType =:= 24 andalso E24 =:= 0 ->%%装备1个法宝
			NewAchEpic = [E1,E2,E3,E4,E5,E6,E7,E8,E9,E10,
						  E11,E12,E13,E14,E15,E16,E17,E18,E19,E20,
						  E21,E22,E23,1,E25,E26,E27,Ef],
			{[24], NewAchEpic};
		ASType =:= 25 andalso E25 =:= 0 ->%%装备一个八阶紫法宝
			NewAchEpic = [E1,E2,E3,E4,E5,E6,E7,E8,E9,E10,
						  E11,E12,E13,E14,E15,E16,E17,E18,E19,E20,
						  E21,E22,E23,E24,1,E26,E27,Ef],
			{[25], NewAchEpic};
		ASType =:= 26 andalso E26 =:= 0 ->%%装备一套70级诛邪套装
			NewAchEpic = [E1,E2,E3,E4,E5,E6,E7,E8,E9,E10,
						  E11,E12,E13,E14,E15,E16,E17,E18,E19,E20,
						  E21,E22,E23,E24,E25,1,E27,Ef],
			{[26], NewAchEpic};
		ASType =:= 27 andalso E27 =:= 0 ->%%装备一套60级封神套装
			NewAchEpic = [E1,E2,E3,E4,E5,E6,E7,E8,E9,E10,
						  E11,E12,E13,E14,E15,E16,E17,E18,E19,E20,
						  E21,E22,E23,E24,E25,E26,1,Ef],
			{[27], NewAchEpic};
		ASType =:= 28 -> %%最后一个神装成就
			{[], AchEpic};
		true  ->
			{[], AchEpic}
	end,
	{RUpList, RNewAchEpic} = Result,
	[RE1,RE2,RE3,RE4,RE5,RE6,RE7,RE8,RE9,RE10,
	 RE11,RE12,RE13,RE14,RE15,RE16,RE17,RE18,RE19,RE20,
	 RE21,RE22,RE23,RE24,RE25,RE26,RE27,REf] = RNewAchEpic,
	case lib_achieve_inline:check_final_ok(length(RNewAchEpic)-1, RNewAchEpic, true) andalso REf =:= 0 of
		true ->
			{[28|RUpList],[RE1,RE2,RE3,RE4,RE5,RE6,RE7,RE8,RE9,RE10,
						   RE11,RE12,RE13,RE14,RE15,RE16,RE17,RE18,RE19,RE20,
						   RE21,RE22,RE23,RE24,RE25,RE26,RE27,1]};
		false ->
			Result
	end.
	
%%************		试炼成就		************
%% 1	万妖杀			击败怪物10000只					20	万妖杀
%% 2	灭妖师			击败怪物5000000只				40	灭妖师
%% 3	击杀火凤			击败火凤50次						40	
%% 4	击杀千年老龟		击败千年老龟50次					40	
%% 5	击杀烈焰麒麟兽	击败烈焰麒麟兽50次				40	
%% 6	击杀灵狐			击败灵狐100次					40	
%% 7	击杀裂地斧魔		击败裂地斧魔100次				40	
%% 8	击杀千年猴妖		击败千年猴妖100次				40	
%% 9	强盗				成功劫镖5次						20	强盗
%% 10	土匪				成功劫商3次						20	土匪
%% 11	山大王			成功打劫紫色商车3次				30	山大王
%% 12	跑商高手			成功运送2次紫色商车				20	跑商高手
%% 13	跑商大师			成功运送紫色商车20次				40	跑商大师
%% 14	封神之峰			封神台12层通关50次				20	封神之峰
%% 15	封神之巅			封神台21层通关50次				40	封神之巅
%% 16	封神巅峰			封神台45层通关50次				60	封神巅峰
%% 17	小有身手			远古战场击败100名玩家				20	小有身手
%% 18	顶尖高手			远古战场击败500名玩家				40	顶尖高手
%% 19	独孤求败			远古战场击败5000名玩家			60	独孤求败
%% 20	氏族称雄			成功运送10次旗					20	氏族称雄
%% 21	氏族称霸			成功运送100次旗					40	氏族称霸
%% 22	氏族称王			成功运送300次旗					60	氏族称王
%% 23	单人镇妖护卫		单人镇妖台防守击败千年毒尸30次	10	
%% 24	单人镇妖守将		单人镇妖台防守击败龙骨甲兽15次	20	
%% 25	单人镇妖首领		单人镇妖台防守击败食腐树妖10次	30	
%% 26	多人镇妖护卫		多人镇妖台防守击败千年毒尸30次	10	
%% 27	多人镇妖守将		多人镇妖台防守击败龙骨甲兽15次	20	
%% 28	多人镇妖首领		多人镇妖台防守击败食腐树妖10次	30	
%% 29	击杀雷公			击败雷公100次					10	
%% 30	击杀狐小小		击败狐小小150次					20	
%% 31	击杀河伯			击败河伯200次					40	
%% 32	击杀蚩尤			击败蚩尤250次					60	
%% 33	威名远播			完成所有试炼成就					100	威名远播

update_achieve_trials(PlayerId, AchTrials, ASType, Param) ->
	[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
	 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
	 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
	 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
	 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
	 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf] = AchTrials,
	case ets:lookup(?ACHIEVE_STATISTICS, PlayerId) of
		[] ->
			fail;
		[Achieve] ->
			Result =
				if 
					ASType =:= 1 orelse ASType =:= 2 ->%%杀普通怪
						[Num] = Param,
						TRM = Achieve#ets_ach_stats.trm,
						NewTRM = TRM + Num,
						if 
							NewTRM >= ?TRIALS_TRM_TWO andalso (Tr1 =:= 0 orelse Tr2 =:= 0) ->
								%% 检查和更新 对应的字段
								{UpList, [NTr1,NTr2], _Rest} = check_and_update_list_update([2,1], [Tr1,Tr2]),
								NewAchTrials = [NTr1,NTr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
												Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
												Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
												Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
												Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
												Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewAchieve = Achieve#ets_ach_stats{trm = NewTRM},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTrials};
							NewTRM >= ?TRIALS_TRM_ONE andalso Tr1 =:= 0 ->
								NewAchTrials = [1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
												Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
												Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
												Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
												Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
												Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewAchieve = Achieve#ets_ach_stats{trm = NewTRM},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[1], NewAchTrials};
							true ->
								case Tr1 =:= 0 orelse Tr2 =:= 0 of
									true ->
										NewAchieve = Achieve#ets_ach_stats{trm = NewTRM},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
										{[],AchTrials};
									false ->
										{[],AchTrials}
								end
						end;
					ASType =:= 3 orelse ASType =:= 4 orelse ASType =:= 5 
					  orelse ASType =:= 6 orelse ASType =:= 7 orelse ASType =:= 8 ->%%杀世界boss
						[Num] = Param,
						TRB = Achieve#ets_ach_stats.trb,
						[BNum1,BNum2,BNum3,BNum4,BNum5,BNum6] = TRB,
						if 
							ASType =:= 3 ->%%火凤
								NewBNum = BNum1 + Num,
								case NewBNum >= ?TRIALS_BOSS_ONE andalso Tr3 =:= 0 of
									true ->
										{UpList, [NTr3,NTr33], _Rest} = check_and_update_list_update([33,3], [Tr3,Tr33]),
										NewAchTrials = [Tr1,Tr2,NTr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
														Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
														Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
														Tr31,Tr32,NTr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
														Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
														Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
										NewTRB = [NewBNum,BNum2,BNum3,BNum4,BNum5,BNum6],
										NewAchieve = Achieve#ets_ach_stats{trb = NewTRB},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
										{UpList, NewAchTrials};
									false ->
										if
											Tr33 =:= 0 ->
												NewAchTrials = 
													[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
													 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
													 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
													 Tr31,Tr32,1,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
													 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
													 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
												UpList = [33];
											true ->
												NewAchTrials = AchTrials,
												UpList = []
										end,
										NewTRB = [NewBNum,BNum2,BNum3,BNum4,BNum5,BNum6],
										NewAchieve = Achieve#ets_ach_stats{trb = NewTRB},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
										{UpList, NewAchTrials}
								end;
							ASType =:= 4 ->%%千年老龟
								NewBNum = BNum2 + Num,
								case NewBNum >= ?TRIALS_BOSS_TWO andalso Tr4 =:= 0 of
									true ->
										{UpList, [NTr4,NTr34], _Rest} = check_and_update_list_update([34,4], [Tr4,Tr34]),
										NewAchTrials = [Tr1,Tr2,Tr3,NTr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
														Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
														Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
														Tr31,Tr32,Tr33,NTr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
														Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
														Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
										NewTRB = [BNum1,NewBNum,BNum3,BNum4,BNum5,BNum6],
										NewAchieve = Achieve#ets_ach_stats{trb = NewTRB},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
										%%做数据的更新记录
										make_log_update_ach(PlayerId, 304, NewBNum),
										{UpList, NewAchTrials};
								false ->
									if
										Tr34 =:= 0 ->
											NewAchTrials = 
													[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
													 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
													 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
													 Tr31,Tr32,Tr33,1,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
													 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
													 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
												UpList = [34];
											true ->
												NewAchTrials = AchTrials,
												UpList = []
										end,
										NewTRB = [BNum1,NewBNum,BNum3,BNum4,BNum5,BNum6],
										NewAchieve = Achieve#ets_ach_stats{trb = NewTRB},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
										%%做数据的更新记录
										make_log_update_ach(PlayerId, 304, NewBNum),
										{UpList, NewAchTrials}
								end;
							ASType =:= 5 ->%%烈焰麒麟兽
								NewBNum = BNum3 + Num,
								case NewBNum >= ?TRIALS_BOSS_THREE andalso Tr5 =:= 0 of
									true ->
										{UpList, [NTr5,NTr35], _Rest} = check_and_update_list_update([35,5], [Tr5,Tr35]),
										NewAchTrials = [Tr1,Tr2,Tr3,Tr4,NTr5,Tr6,Tr7,Tr8,Tr9,Tr10,
														Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
														Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
														Tr31,Tr32,Tr33,Tr34,NTr35,Tr36,Tr37,Tr38,Tr39,Tr40,
														Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
														Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
										NewTRB = [BNum1,BNum2,NewBNum,BNum4,BNum5,BNum6],
										NewAchieve = Achieve#ets_ach_stats{trb = NewTRB},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
										%%做数据的更新记录
										make_log_update_ach(PlayerId, 305, NewBNum),
										{UpList, NewAchTrials};
									false ->
										if
											Tr35 =:= 0 ->
												NewAchTrials = 
													[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
													 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
													 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
													 Tr31,Tr32,Tr33,Tr34,1,Tr36,Tr37,Tr38,Tr39,Tr40,
													 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
													 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
												UpList = [35];
											true ->
												NewAchTrials = AchTrials,
												UpList = []
										end,
										NewTRB = [BNum1,BNum2,NewBNum,BNum4,BNum5,BNum6],
										NewAchieve = Achieve#ets_ach_stats{trb = NewTRB},
										%%做数据的更新记录
										make_log_update_ach(PlayerId, 305, NewBNum),
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
										{UpList, NewAchTrials}
								end;
							ASType =:= 6 ->%%灵狐
								NewBNum = BNum4 + Num,
								case NewBNum >= ?TRIALS_BOSS_FOUR andalso Tr6 =:= 0 of
									true ->
										{UpList, [NTr6,NTr36], _Rest} = check_and_update_list_update([36,6], [Tr6,Tr36]),
										NewAchTrials = [Tr1,Tr2,Tr3,Tr4,Tr5,NTr6,Tr7,Tr8,Tr9,Tr10,
														Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
														Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
														Tr31,Tr32,Tr33,Tr34,Tr35,NTr36,Tr37,Tr38,Tr39,Tr40,
														Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
														Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
											NewTRB = [BNum1,BNum2,BNum3,NewBNum,BNum5,BNum6],
										NewAchieve = Achieve#ets_ach_stats{trb = NewTRB},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
										{UpList, NewAchTrials};
								false ->
									if
										Tr36 =:= 0 ->
												NewAchTrials = 
													[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
													 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
													 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
													 Tr31,Tr32,Tr33,Tr34,Tr35,1,Tr37,Tr38,Tr39,Tr40,
													 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
													 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
												UpList = [36];
											true ->
												NewAchTrials = AchTrials,
												UpList = []
										end,
										NewTRB = [BNum1,BNum2,BNum3,NewBNum,BNum5,BNum6],
										NewAchieve = Achieve#ets_ach_stats{trb = NewTRB},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
										{UpList, NewAchTrials}
								end;
							ASType =:= 7 ->%%裂地斧魔
								NewBNum = BNum5 + Num,
								case NewBNum >= ?TRIALS_BOSS_FIVE andalso Tr7 =:= 0 of
									true ->
										{UpList, [NTr7,NTr37], _Rest} = check_and_update_list_update([37,7], [Tr7,Tr37]),
										NewAchTrials = [Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,NTr7,Tr8,Tr9,Tr10,
														Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
														Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
														Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,NTr37,Tr38,Tr39,Tr40,
														Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
														Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
										NewTRB = [BNum1,BNum2,BNum3,BNum4,NewBNum,BNum6],
										NewAchieve = Achieve#ets_ach_stats{trb = NewTRB},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
										{UpList, NewAchTrials};
									false ->
										if
											Tr37 =:= 0 ->
												NewAchTrials = 
													[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
													 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
													 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
													 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,1,Tr38,Tr39,Tr40,
													 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
													 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
												UpList = [37];
											true ->
												NewAchTrials = AchTrials,
												UpList = []
										end,
										NewTRB = [BNum1,BNum2,BNum3,BNum4,NewBNum,BNum6],
										NewAchieve = Achieve#ets_ach_stats{trb = NewTRB},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
										{UpList, NewAchTrials}
								end;
							ASType =:= 8 ->%%千年猴妖
								NewBNum = BNum6 + Num,
								case NewBNum >= ?TRIALS_BOSS_SIX andalso Tr8 =:= 0 of
									true ->
										{UpList, [NTr8,NTr38], _Rest} = check_and_update_list_update([38,8], [Tr8,Tr38]),
										NewAchTrials = [Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,NTr8,Tr9,Tr10,
														Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
														Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
														Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,NTr38,Tr39,Tr40,
														Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
														Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
										NewTRB = [BNum1,BNum2,BNum3,BNum4,BNum5,NewBNum],
										NewAchieve = Achieve#ets_ach_stats{trb = NewTRB},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
										{UpList, NewAchTrials};
									false ->
										if
											Tr38 =:= 0 ->
												NewAchTrials = 
													[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
													 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
													 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
													 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,1,Tr39,Tr40,
													 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
													 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
												UpList = [38];
											true ->
												NewAchTrials = AchTrials,
												UpList = []
										end,
										NewTRB = [BNum1,BNum2,BNum3,BNum4,BNum5,NewBNum],
										NewAchieve = Achieve#ets_ach_stats{trb = NewTRB},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
										{UpList, NewAchTrials}
								end;
							true ->
								{[],AchTrials}
						end;
					ASType =:= 9 orelse ASType =:= 10 orelse ASType =:= 11 ->%%劫商，劫镖
						TRBC = Achieve#ets_ach_stats.trbc,
						[BCNum1,BCNum2,BCNum3] = TRBC,
							if
								ASType =:= 9 ->
									[Num] = Param,
									NewBCNum = BCNum1 + Num,
									case NewBCNum >= ?TRIALS_TRBC_ONE andalso Tr9 =:= 0 of
										true ->
											NewAchTrials = 
												[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,1,Tr10,
												 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
												 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
												 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
												 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
												 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
											NewTRBC = [NewBCNum,BCNum2,BCNum3],
											NewAchieve = Achieve#ets_ach_stats{trbc = NewTRBC},
											ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
											{[9], NewAchTrials};
										false ->
											NewTRBC = [NewBCNum,BCNum2,BCNum3],
											NewAchieve = Achieve#ets_ach_stats{trbc = NewTRBC},
											ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
											{[],AchTrials}
									end;
								ASType =:= 10 orelse ASType =:= 11 ->
									[Color, Num] = Param,
									case Color of%%商车颜色    白:4绿:5蓝:6紫:7
										7 ->
											NewBCNum = BCNum2 + Num,
											NewPBCNum = BCNum3 + Num,
											A = (NewBCNum >= ?TRIALS_TRBC_TWO andalso Tr10 =:= 0),
											B = (NewPBCNum >= ?TRIALS_TRBC_THREE andalso Tr11 =:= 0),
											if
												A =:= true andalso B =:= true ->
													NewAchTrials = 
														[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,1,
														 1,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
														 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
														 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
														 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
														 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
													NewTRBC = [BCNum1,NewBCNum,NewPBCNum],
													NewAchieve = Achieve#ets_ach_stats{trbc = NewTRBC},
													ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
													{[10,11],NewAchTrials};
												A =:= true andalso B =:= false ->
													NewAchTrials = 
														[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,1,
														 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
														 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
														 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
														 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
														 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
													NewTRBC = [BCNum1,NewBCNum,NewPBCNum],
													NewAchieve = Achieve#ets_ach_stats{trbc = NewTRBC},
													ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
													{[10],NewAchTrials};
												A =:= false andalso B =:= true ->
													NewAchTrials = 
														[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
														 1,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
														 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
														 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
														 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
														 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
													NewTRBC = [BCNum1,NewBCNum,NewPBCNum],
													NewAchieve = Achieve#ets_ach_stats{trbc = NewTRBC},
													ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
													{[11],NewAchTrials};
												true ->
													NewTRBC = [BCNum1,NewBCNum,NewPBCNum],
													NewAchieve = Achieve#ets_ach_stats{trbc = NewTRBC},
													ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
													{[],AchTrials}
											end;
										_Other ->
											NewBCNum = BCNum2 + Num,
											case NewBCNum >= ?TRIALS_TRBC_TWO andalso Tr10 =:= 0 of
												true ->
													NewAchTrials = 
														[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,1,
														 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
														 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
														 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
														 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
														 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
													NewTRBC = [BCNum1,NewBCNum,BCNum3],
													NewAchieve = Achieve#ets_ach_stats{trbc = NewTRBC},
													ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
													{[10],NewAchTrials};
												false ->
													NewTRBC = [BCNum1,NewBCNum,BCNum3],
													NewAchieve = Achieve#ets_ach_stats{trbc = NewTRBC},
													ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
													{[],AchTrials}
											end
									end
						end;
					ASType =:= 12 orelse ASType =:= 13 ->%%成功跑商
						[Num] = Param,
						TRBus = Achieve#ets_ach_stats.trbus,
						NewTRBus = TRBus + Num,    
						if 
							NewTRBus >= ?TRIALS_TRBUS_TWO andalso (Tr12 =:= 0 orelse Tr13 =:= 0) ->
								%% 检查和更新 对应的字段
								{UpList, [NTr12,NTr13], _Rest} = check_and_update_list_update([13,12], [Tr12,Tr13]),
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,NTr12,NTr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewAchieve = Achieve#ets_ach_stats{trbus = NewTRBus},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTrials};
							NewTRBus >= ?TRIALS_TRBUS_ONE  andalso Tr12 =:= 0 ->
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,1,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewAchieve = Achieve#ets_ach_stats{trbus = NewTRBus},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[12], NewAchTrials};
							true ->
								case Tr12 =:= 0 orelse Tr13 =:= 0 of
									true ->
										NewAchieve = Achieve#ets_ach_stats{trbus = NewTRBus},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve);
									false ->
										skip
								end,
								{[],AchTrials}
						end;
					ASType =:= 14 ->%%12封神台任务
						[Num] = Param,
%% 						?DEBUG("14, Num:~p", [Num]),
						TRFst = Achieve#ets_ach_stats.trfst,
						[One,Two,Three] = TRFst,
						NewNum = One + Num,
						case NewNum >= ?TRIALS_TRFST_ONE of
							true when Tr14 =:= 0 ->
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,1,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
									 Tr61,Tr62,Tr63,Trf],
								NewTRFst = [NewNum,Two,Three],
								NewAchieve = Achieve#ets_ach_stats{trfst = NewTRFst},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								%%做数据的更新记录
								make_log_update_ach(PlayerId, 314, NewNum),
								{[14], NewAchTrials};
							true ->
								{[],AchTrials};
							false ->
								NewTRFst = [NewNum,Two,Three],
								NewAchieve = Achieve#ets_ach_stats{trfst = NewTRFst},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								%%做数据的更新记录
								make_log_update_ach(PlayerId, 314, NewNum),
								{[],AchTrials}
						end;
					ASType =:= 15 ->%%21封神台任务
						[Num] = Param,
%% 						?DEBUG("15, Num:~p", [Num]),
						TRFst = Achieve#ets_ach_stats.trfst,
						[One,Two,Three] = TRFst,
						NewNum = Two + Num,
						case NewNum >= ?TRIALS_TRFST_TWO of
							true when Tr15 =:= 0 ->
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,1,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewTRFst = [One,NewNum,Three],
								NewAchieve = Achieve#ets_ach_stats{trfst = NewTRFst},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								%%做数据的更新记录
								make_log_update_ach(PlayerId, 315, NewNum),
								{[15], NewAchTrials};
							true ->
								{[],AchTrials};
							false ->
								NewTRFst = [One,NewNum,Three],
								NewAchieve = Achieve#ets_ach_stats{trfst = NewTRFst},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								%%做数据的更新记录
								make_log_update_ach(PlayerId, 315, NewNum),
								{[],AchTrials}
						end;
					ASType =:= 16 ->%%45封神台任务
						[Num] = Param,
%% 						?DEBUG("16, Num:~p", [Num]),
						TRFst = Achieve#ets_ach_stats.trfst,
						[One,Two,Three] = TRFst,
						NewNum = Three + Num,
						case NewNum >= ?TRIALS_TRFST_THREE of
							true when Tr16 =:= 0 ->
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,1,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewTRFst = [One,Two,NewNum],
								NewAchieve = Achieve#ets_ach_stats{trfst = NewTRFst},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								%%做数据的更新记录
								make_log_update_ach(PlayerId, 316, NewNum),
								{[16], NewAchTrials};
							true ->
								{[],AchTrials};
							false ->
								NewTRFst = [One,Two,NewNum],
								NewAchieve = Achieve#ets_ach_stats{trfst = NewTRFst},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								%%做数据的更新记录
								make_log_update_ach(PlayerId, 316, NewNum),
								{[],AchTrials}
						end;
					ASType =:= 17 orelse ASType =:= 18 orelse ASType =:= 19 ->%%战场杀人
						[Num] = Param,
						TRAR = Achieve#ets_ach_stats.trar,
						NewTRAR = TRAR + Num,
						if 
							NewTRAR >= ?TRIALS_TRAR_THREE andalso (Tr17 =:= 0 orelse Tr18 =:= 0 orelse Tr19 =:= 0) ->
								%% 检查和更新 对应的字段
								{UpList, [NTr17,NTr18,NTr19,NTr44], _Rest} = check_and_update_list_update([44,19,18,17], [Tr17,Tr18,Tr19,Tr44]),
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,NTr17,NTr18,NTr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,NTr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewAchieve = Achieve#ets_ach_stats{trar = NewTRAR},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTrials};
							NewTRAR >= ?TRIALS_TRAR_TWO andalso (Tr17 =:= 0 orelse Tr18 =:= 0) ->
								%% 检查和更新 对应的字段
								{UpList, [NTr17,NTr18,NTr44], _Rest} = check_and_update_list_update([44,18,17], [Tr17,Tr18,Tr44]),
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,NTr17,NTr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,NTr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewAchieve = Achieve#ets_ach_stats{trar = NewTRAR},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTrials};
							NewTRAR >= ?TRIALS_TRAR_ONE andalso Tr17 =:= 0 ->
								%% 检查和更新 对应的字段
								{UpList, [NTr17,NTr44], _Rest} = check_and_update_list_update([44,17], [Tr17,Tr44]),
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,NTr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,NTr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewAchieve = Achieve#ets_ach_stats{trar = NewTRAR},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTrials};
							true ->
								if
									Tr44 =:= 0 ->
										NewAchTrials = 
											[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
											 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
											 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
											 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
											 Tr41,Tr42,Tr43,1,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
											 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
												UpList = [44];
									true ->
										NewAchTrials = AchTrials,
										UpList = []
								end,
								case Tr17 =:= 0 orelse Tr18 =:= 0 orelse Tr19 =:= 0 of
									true ->
										NewAchieve = Achieve#ets_ach_stats{trar = NewTRAR},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve);
									false ->
										skip
								end,
								{UpList, NewAchTrials}
						end;
					ASType =:= 20 orelse ASType =:= 21 orelse ASType =:= 22 ->%%氏族战运旗
						[Num] = Param,
						TRF = Achieve#ets_ach_stats.trf,
						NewTRF = TRF + Num,
						if 
							NewTRF >= ?TRIALS_TRF_THREE andalso (Tr20 =:= 0 orelse Tr21 =:= 0 orelse Tr22 =:= 0) ->
								%% 检查和更新 对应的字段
								{UpList, [NTr20,NTr21,NTr22,NTr45], _Rest} = check_and_update_list_update([45,22,21,20], [Tr20,Tr21,Tr22,Tr45]),
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,NTr20,
									 NTr21,NTr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,NTr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewAchieve = Achieve#ets_ach_stats{trf = NewTRF},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTrials};
							NewTRF >= ?TRIALS_TRF_TWO andalso (Tr20 =:= 0 orelse Tr21 =:= 0) ->
								%% 检查和更新 对应的字段
								{UpList, [NTr20,NTr21,NTr45], _Rest} = check_and_update_list_update([45,21,20], [Tr20,Tr21,Tr45]),
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,NTr20,
									 NTr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,NTr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewAchieve = Achieve#ets_ach_stats{trf = NewTRF},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTrials};
							NewTRF >= ?TRIALS_TRF_ONE andalso Tr20 =:= 0 ->
								%% 检查和更新 对应的字段
								{UpList, [NTr20,NTr45], _Rest} = check_and_update_list_update([45,20], [Tr20,Tr45]),
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,NTr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,NTr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewAchieve = Achieve#ets_ach_stats{trf = NewTRF},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTrials};
							true ->
								if
									Tr45 =:= 0 ->
										NewAchTrials = 
											[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
											 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
											 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
											 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
											 Tr41,Tr42,Tr43,Tr44,1,Tr46,Tr47,Tr48,Tr49,Tr50,
											 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
												UpList = [45];
									true ->
										NewAchTrials = AchTrials,
										UpList = []
								end,
								case Tr20 =:= 0 orelse Tr21 =:= 0 orelse Tr22 =:= 0 of
									true ->
										NewAchieve = Achieve#ets_ach_stats{trf = NewTRF},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve);
									false ->
										skip
								end,
								{UpList, NewAchTrials}
						end;
					ASType =:= 23 ->%%千年毒尸妖 单人镇妖台
						[Num] = Param,
%% 						?DEBUG("ZYT 23 :~p", [Num]),
						TRSTD = Achieve#ets_ach_stats.trstd,
						[One,Two,Three] = TRSTD,
						NewNum = One + Num,
						case NewNum >= ?TRIALS_TRSTD_ONE of
							true when Tr23 =:= 0 ->
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,1,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewTRSTD = [NewNum,Two,Three],
								NewAchieve = Achieve#ets_ach_stats{trstd = NewTRSTD},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[23], NewAchTrials};
							true ->
								{[],AchTrials};
							false ->
								NewTRSTD = [NewNum,Two,Three],
								NewAchieve = Achieve#ets_ach_stats{trstd = NewTRSTD},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[],AchTrials}
						end;
					ASType =:= 24 ->%%龙骨甲兽 单人镇妖台
						[Num] = Param,
%% 						?DEBUG("ZYT 24 :~p", [Num]),
						TRSTD = Achieve#ets_ach_stats.trstd,
						[One,Two,Three] = TRSTD,
						NewNum = Two + Num,
						case NewNum >= ?TRIALS_TRSTD_TWO of
							true when Tr24 =:= 0 ->
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,1,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewTRSTD = [One,NewNum,Three],
								NewAchieve = Achieve#ets_ach_stats{trstd = NewTRSTD},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[24], NewAchTrials};
							true ->
								{[],AchTrials};
							false ->
								NewTRSTD = [One,NewNum,Three],
								NewAchieve = Achieve#ets_ach_stats{trstd = NewTRSTD},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[],AchTrials}
						end;
					ASType =:= 25 ->%%食腐树 单人镇妖台
						[Num] = Param,
%% 						?DEBUG("ZYT 25 :~p", [Num]),
						TRSTD = Achieve#ets_ach_stats.trstd,
						[One,Two,Three] = TRSTD,
						NewNum = Three + Num,
						case NewNum >= ?TRIALS_TRSTD_THREE of
							true when Tr25 =:= 0 ->
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,1,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewTRSTD = [One,Two,NewNum],
								NewAchieve = Achieve#ets_ach_stats{trstd = NewTRSTD},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[25], NewAchTrials};
							true ->
								{[],AchTrials};
							false ->
								NewTRSTD = [One,Two,NewNum],
								NewAchieve = Achieve#ets_ach_stats{trstd = NewTRSTD},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[],AchTrials}
						end;
					ASType =:= 26 ->%%千年毒尸妖 多人镇妖台
						[Num] = Param,
%% 						?DEBUG("ZYT 26 :~p", [Num]),
						TRMTD = Achieve#ets_ach_stats.trmtd,
						[One,Two,Three] = TRMTD,
						NewNum = One + Num,
						case NewNum >= ?TRIALS_TRMTD_ONE of
							true when Tr26 =:= 0 ->
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,1,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewTRMTD = [NewNum,Two,Three],
								NewAchieve = Achieve#ets_ach_stats{trmtd = NewTRMTD},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[26], NewAchTrials};
							true ->
								{[],AchTrials};
							false ->
								NewTRMTD = [NewNum,Two,Three],
								NewAchieve = Achieve#ets_ach_stats{trmtd = NewTRMTD},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[],AchTrials}
						end;
					ASType =:= 27 ->%%龙骨甲兽 多人镇妖台
						[Num] = Param,
%% 						?DEBUG("ZYT 27 :~p", [Num]),
						TRMTD = Achieve#ets_ach_stats.trmtd,
						[One,Two,Three] = TRMTD,
						NewNum = Two + Num,
						case NewNum >= ?TRIALS_TRMTD_TWO of
							true when Tr27 =:= 0 ->
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,1,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewTRMTD = [One,NewNum,Three],
								NewAchieve = Achieve#ets_ach_stats{trmtd = NewTRMTD},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[27], NewAchTrials};
							true ->
								{[],AchTrials};
							false ->
								NewTRMTD = [One,NewNum,Three],
								NewAchieve = Achieve#ets_ach_stats{trmtd = NewTRMTD},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[],AchTrials}
						end;
					ASType =:= 28 ->%%食腐树 多人镇妖台
						[Num] = Param,
%% 						?DEBUG("ZYT 28 :~p", [Num]),
						TRMTD = Achieve#ets_ach_stats.trmtd,
						[One,Two,Three] = TRMTD,
						NewNum = Three + Num,
						case NewNum >= ?TRIALS_TRMTD_THREE of
							true when Tr28 =:= 0 ->
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,1,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewTRMTD = [One,Two,NewNum],
								NewAchieve = Achieve#ets_ach_stats{trmtd = NewTRMTD},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[28], NewAchTrials};
							true ->
								{[],AchTrials};
							false ->
								NewTRMTD = [One,Two,NewNum],
								NewAchieve = Achieve#ets_ach_stats{trmtd = NewTRMTD},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[],AchTrials}
						end;
					ASType =:= 29 ->%%雷公 杀副本boss
						[Num] = Param,
						TRFBB = Achieve#ets_ach_stats.trfbb,
						[One,Two,Three,Four] = TRFBB,
						NewNum = One + Num,
						case NewNum >= ?TRIALS_TRFBB_ONE of
							true when Tr29 =:= 0 ->
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,1,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewTRFBB = [NewNum,Two,Three,Four],
								NewAchieve = Achieve#ets_ach_stats{trfbb = NewTRFBB},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[29], NewAchTrials};
							true ->
								{[],AchTrials};
							false ->
								NewTRFBB = [NewNum,Two,Three,Four],
								NewAchieve = Achieve#ets_ach_stats{trfbb = NewTRFBB},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[],AchTrials}
						end;
					ASType =:= 30 ->%%狐小小 杀副本boss
						[Num] = Param,
						TRFBB = Achieve#ets_ach_stats.trfbb,
						[One,Two,Three,Four] = TRFBB,
						NewNum = Two + Num,
						case NewNum >= ?TRIALS_TRFBB_TWO of
							true when Tr30 =:= 0 ->
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,1,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewTRFBB = [One,NewNum,Three,Four],
								NewAchieve = Achieve#ets_ach_stats{trfbb = NewTRFBB},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[30], NewAchTrials};
							true ->
								{[],AchTrials};
							false ->
								NewTRFBB = [One,NewNum,Three,Four],
								NewAchieve = Achieve#ets_ach_stats{trfbb = NewTRFBB},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[],AchTrials}
						end;
					ASType =:= 31 ->%%河伯 杀副本boss
						[Num] = Param,
						TRFBB = Achieve#ets_ach_stats.trfbb,
						[One,Two,Three,Four] = TRFBB,
						NewNum = Three + Num,
						case NewNum >= ?TRIALS_TRFBB_THREE of
							true when Tr31 =:= 0 ->
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 1,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewTRFBB = [One,Two,NewNum,Four],
								NewAchieve = Achieve#ets_ach_stats{trfbb = NewTRFBB},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[31], NewAchTrials};
							true ->
								{[],AchTrials};
							false ->
								NewTRFBB = [One,Two,NewNum,Four],
								NewAchieve = Achieve#ets_ach_stats{trfbb = NewTRFBB},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[],AchTrials}
						end;
					ASType =:= 32 ->%%蚩尤 杀副本boss
						[Num] = Param,
						TRFBB = Achieve#ets_ach_stats.trfbb,
						[One,Two,Three,Four] = TRFBB,
						NewNum = Four + Num,
						case NewNum >= ?TRIALS_TRFBB_FOUR of
							true when Tr32 =:= 0 ->
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,1,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewTRFBB = [One,Two,Three,NewNum],
								NewAchieve = Achieve#ets_ach_stats{trfbb = NewTRFBB},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[32], NewAchTrials};
							true ->
								{[],AchTrials};
							false ->
								NewTRFBB = [One,Two,Three,NewNum],
								NewAchieve = Achieve#ets_ach_stats{trfbb = NewTRFBB},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[],AchTrials}
						end;
					ASType =:= 39 orelse ASType =:= 40 orelse ASType =:= 41 orelse ASType =:=  42
					  orelse ASType =:=  52 ->
						if
							ASType =:= 40 orelse ASType =:= 39 ->%%杀穷奇
								[Num] = Param,
								TRSIXFB = Achieve#ets_ach_stats.trsixfb,
								[One,Two,Three] = TRSIXFB,
								NewNum = One + Num,
								case NewNum >= ?TRIALS_TRSIXFB_ONE andalso Tr40 =:= 0 of
									true ->
										{UpList, [NTr39,NTr40], _Rest} = check_and_update_list_update([40,39], [Tr39,Tr40]),
										NewAchTrials = 
											[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
											 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
											 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
											 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,NTr39,NTr40,
											 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
											 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
										NewTRSIXFB = [NewNum,Two,Three],
										NewAchieve = Achieve#ets_ach_stats{trsixfb = NewTRSIXFB},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
										{UpList, NewAchTrials};
									false ->
										if
											Tr39 =:= 0 ->
												NewAchTrials = 
													[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
													 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
													 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
													 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,1,Tr40,
													 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
													 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
												UpList = [39];
											true ->
												NewAchTrials = AchTrials,
												UpList = []
										end,
										NewTRSIXFB = [NewNum,Two,Three],
										NewAchieve = Achieve#ets_ach_stats{trsixfb = NewTRSIXFB},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
										{UpList, NewAchTrials}
								end;
							ASType =:= 42 orelse ASType =:= 41 ->%%赤尾狐
								[Num] = Param,
								TRSIXFB = Achieve#ets_ach_stats.trsixfb,
								[One,Two,Three] = TRSIXFB,
								NewNum = Two + Num,
								case NewNum >= ?TRIALS_TRSIXFB_TWO andalso Tr42 =:= 0 of
									true ->
										{UpList, [NTr41,NTr42], _Rest} = check_and_update_list_update([42,41], [Tr41,Tr42]),
										NewAchTrials = 
											[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
											 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
											 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
											 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
											 NTr41,NTr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
											 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
										NewTRSIXFB = [One,NewNum,Three],
										NewAchieve = Achieve#ets_ach_stats{trsixfb = NewTRSIXFB},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
										{UpList, NewAchTrials};
									false ->
										if
											Tr41 =:= 0 ->
												NewAchTrials = 
													[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
													 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
													 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
													 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
													 1,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
													 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
												UpList = [41];
											true ->
												NewAchTrials = AchTrials,
												UpList = []
										end,
										NewTRSIXFB = [One,NewNum,Three],
										NewAchieve = Achieve#ets_ach_stats{trsixfb = NewTRSIXFB},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
										{UpList, NewAchTrials}
								end;
							ASType =:= 52 ->%%击杀 瑶池圣母
								[Num] = Param,
								TRSIXFB = Achieve#ets_ach_stats.trsixfb,
								[One,Two,Three] = TRSIXFB,
								NewNum = Three + Num,
								case NewNum >= ?TRIALS_TRSIXFB_THREE of
									true when Tr52 =:= 0 ->
										NewAchTrials = 
											[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
											  Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
											 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
											 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
											 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
											 Tr51,1,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
										UpList = [52],
										NewTRSIXFB = [One,Two,NewNum],
										NewAchieve = Achieve#ets_ach_stats{trsixfb = NewTRSIXFB},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
										{UpList, NewAchTrials};
									true ->
										{[], AchTrials};
									false ->
										NewTRSIXFB = [One,Two,NewNum],
										NewAchieve = Achieve#ets_ach_stats{trsixfb = NewTRSIXFB},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
										{[], AchTrials}
								end;
							true ->
								{[], AchTrials}
						end;	
					ASType =:= 43 andalso Tr43 =:= 0 ->%%通关封神台9层一次
						NewAchTrials = 
							[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
							 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
							 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
							 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
							 Tr41,Tr42,1,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
							 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
						{[43], NewAchTrials};
					ASType =:= 46 andalso Tr46 =:= 0 ->%%单人镇妖防守魔界蜂后1次
						NewAchTrials = 
							[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
							 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
							 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
							 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
							 Tr41,Tr42,Tr43,Tr44,Tr45,1,Tr47,Tr48,Tr49,Tr50,
							 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
						{[46], NewAchTrials};
					ASType =:= 47 andalso Tr47 =:= 0 ->%%多人镇妖防守魔界蜂后1次
						NewAchTrials = 
							[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
							 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
							 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
							 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
							 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,1,Tr48,Tr49,Tr50,
							 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
						{[47], NewAchTrials};
					ASType =:= 48 andalso Tr48 =:= 0 ->%%通关诛仙台9层一次
						NewAchTrials = 
							[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
							 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
							 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
							 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
							 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,1,Tr49,Tr50,
							 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
						{[48], NewAchTrials};
					ASType =:= 49 ->%%12诛仙台
						[Num] = Param,
%% 						?DEBUG("49, Num:~p", [Num]),
						TRZXT = Achieve#ets_ach_stats.trzxt,
						[One,Two,Three] = TRZXT,
						NewNum = One + Num,
						case NewNum >= ?TRIALS_TRZXT_ONE of
							true when Tr49 =:= 0 ->
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,1,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewTRZXT = [NewNum,Two,Three],
								NewAchieve = Achieve#ets_ach_stats{trzxt = NewTRZXT},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[49], NewAchTrials};
							true ->
								{[],AchTrials};
							false ->
								NewTRZXT = [NewNum,Two,Three],
								NewAchieve = Achieve#ets_ach_stats{trzxt = NewTRZXT},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[],AchTrials}
						end;
					ASType =:= 50 ->%%21诛仙台
						[Num] = Param,
%% 						?DEBUG("50, Num:~p", [Num]),
						TRZXT = Achieve#ets_ach_stats.trzxt,
						[One,Two,Three] = TRZXT,
						NewNum = Two + Num,
						case NewNum >= ?TRIALS_TRZXT_TWO of
							true when Tr50 =:= 0 ->
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,1,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewTRZXT = [One,NewNum,Three],
								NewAchieve = Achieve#ets_ach_stats{trzxt = NewTRZXT},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[50], NewAchTrials};
							true ->
								{[],AchTrials};
							false ->
								NewTRZXT = [One,NewNum,Three],
								NewAchieve = Achieve#ets_ach_stats{trzxt = NewTRZXT},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[],AchTrials}
						end;
					ASType =:= 51 ->%%30诛仙台
						[Num] = Param,
%% 						?DEBUG("51, Num:~p", [Num]),
						TRZXT = Achieve#ets_ach_stats.trzxt,
						[One,Two,Three] = TRZXT,
						NewNum = Three + Num,
						case NewNum >= ?TRIALS_TRZXT_THREE of
							true when Tr51 =:= 0 ->
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 1,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
							Tr61,Tr62,Tr63,Trf],
								NewTRZXT = [One,Two,NewNum],
								NewAchieve = Achieve#ets_ach_stats{trzxt = NewTRZXT},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[51], NewAchTrials};
							true ->
								{[],AchTrials};
							false ->
								NewTRZXT = [One,Two,NewNum],
								NewAchieve = Achieve#ets_ach_stats{trzxt = NewTRZXT},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[],AchTrials}
						end;
					ASType =:= 53 orelse ASType =:= 54 orelse ASType =:= 55 ->%%神魔乱斗参与击败哈迪斯
						[Num] = Param,
						TRSM = Achieve#ets_ach_stats.trsm,
						NewTRSM = TRSM + Num,
						if 
							NewTRSM >= ?TRIALS_TRSM_TWO andalso (Tr55 =:= 0 orelse Tr54 =:= 0 orelse Tr53 =:= 0) ->
								%% 检查和更新 对应的字段
								{UpList, [NTr53,NTr54,NTr55], _Rest} = check_and_update_list_update([55,54,53], [Tr53,Tr54,Tr55]),
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,NTr53,NTr54,NTr55,Tr56,Tr57,Tr58,Tr59,Tr60,
									 Tr61,Tr62,Tr63,Trf],
								NewAchieve = Achieve#ets_ach_stats{trsm = NewTRSM},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTrials};
							NewTRSM >= ?TRIALS_TRSM_ONE andalso (Tr54 =:= 0 orelse Tr53 =:= 0) ->
								%% 检查和更新 对应的字段
								{UpList, [NTr53,NTr54], _Rest} = check_and_update_list_update([54,53], [Tr53,Tr54]),
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,NTr53,NTr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
									 Tr61,Tr62,Tr63,Trf],
								NewAchieve = Achieve#ets_ach_stats{trsm = NewTRSM},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTrials};
							true ->
								if
									Tr53 =:= 0 ->
										NewAchTrials = 
											[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
											 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
											 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
											 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
											 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
											 Tr51,Tr52,1,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
											 Tr61,Tr62,Tr63,Trf],
										UpList = [53];
									true ->
										NewAchTrials = AchTrials,
										UpList = []
								end,
								case Tr53 =:= 0 orelse Tr54 =:= 0 orelse Tr55 =:= 0 of
									true ->
										NewAchieve = Achieve#ets_ach_stats{trsm = NewTRSM},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve);
									false ->
										skip
								end,
								{UpList, NewAchTrials}
						end;
					ASType =:= 56 orelse ASType =:= 57 orelse ASType =:= 58 ->%%击败试炼之祖
						[Num] = Param,
						TRTRAIN = Achieve#ets_ach_stats.trtrain,
						NewTRTRAIN = TRTRAIN + Num,
						if 
							NewTRTRAIN >= ?TRIALS_TRTRAIN_TWO andalso (Tr58 =:= 0 orelse Tr57 =:= 0 orelse Tr56 =:= 0) ->
								%% 检查和更新 对应的字段
								{UpList, [NTr56,NTr57,NTr58], _Rest} = check_and_update_list_update([58,57,56], [Tr56,Tr57,Tr58]),
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,NTr56,NTr57,NTr58,Tr59,Tr60,
									 Tr61,Tr62,Tr63,Trf],
								NewAchieve = Achieve#ets_ach_stats{trtrain = NewTRTRAIN},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTrials};
							NewTRTRAIN >= ?TRIALS_TRTRAIN_ONE andalso (Tr57 =:= 0 orelse Tr56 =:= 0) ->
								%% 检查和更新 对应的字段
								{UpList, [NTr56,NTr57], _Rest} = check_and_update_list_update([57,56], [Tr56,Tr57]),
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,NTr56,NTr57,Tr58,Tr59,Tr60,
									 Tr61,Tr62,Tr63,Trf],
								NewAchieve = Achieve#ets_ach_stats{trtrain = NewTRTRAIN},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTrials};
							true ->
								if
									Tr56 =:= 0 ->
										NewAchTrials = 
											[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
											 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
											 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
											 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
											 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
											 Tr51,Tr52,Tr53,Tr54,Tr55,1,Tr57,Tr58,Tr59,Tr60,
											 Tr61,Tr62,Tr63,Trf],
										UpList = [56];
									true ->
										NewAchTrials = AchTrials,
										UpList = []
								end,
								case Tr58 =:= 0 orelse Tr57 =:= 0 orelse Tr56 =:= 0 of
									true ->
										NewAchieve = Achieve#ets_ach_stats{trtrain = NewTRTRAIN},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve);
									false ->
										skip
								end,
								{UpList, NewAchTrials}
						end;
					ASType =:= 59 ->%%击杀共工200次
						[Num] = Param,
						TRGG = Achieve#ets_ach_stats.trgg,
						NewTRGG = TRGG + Num,
						if 
							TRGG >= ?TRIALS_TRGG_NUM andalso Tr59 =:= 0 ->
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,1,Tr60,
									 Tr61,Tr62,Tr63,Trf],
								NewAchieve = Achieve#ets_ach_stats{trgg = NewTRGG},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{[59], NewAchTrials};
							true ->
								case Tr59 =:= 0 of
									true ->
										NewAchieve = Achieve#ets_ach_stats{trgg = NewTRGG},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve);
									false ->
										skip
								end,
								{[], AchTrials}
						end;
					ASType =:= 60 orelse ASType =:= 61 ->%%击杀千年毒尸
						[Num] = Param,
						TRDS = Achieve#ets_ach_stats.trds,
						NewTRTRDS = TRDS + Num,
						if 
							NewTRTRDS >= ?TRIALS_TRDS_NUM andalso (Tr61 =:= 0 orelse Tr60 =:= 0) ->
								%% 检查和更新 对应的字段
								{UpList, [NTr60,NTr61], _Rest} = check_and_update_list_update([61,60], [Tr60,Tr61]),
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,NTr60,
									 NTr61,Tr62,Tr63,Trf],
								NewAchieve = Achieve#ets_ach_stats{trds = NewTRTRDS},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTrials};
							true ->
								if
									Tr60 =:= 0 ->
										NewAchTrials = 
											[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
											 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
											 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
											 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
											 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
											 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,1,
											 Tr61,Tr62,Tr63,Trf],
										UpList = [60];
									true ->
										NewAchTrials = AchTrials,
										UpList = []
								end,
								case Tr61 =:= 0 orelse Tr60 =:= 0 of
									true ->
										NewAchieve = Achieve#ets_ach_stats{trds = NewTRTRDS},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve);
									false ->
										skip
								end,
								{UpList, NewAchTrials}
						end;
					ASType =:= 62 orelse ASType =:= 63 ->%%击败蛮荒巨龙
						[Num] = Param,
						TRJL = Achieve#ets_ach_stats.trjl,
						NewTRTRJL = TRJL + Num,
						if 
							NewTRTRJL >= ?TRIALS_TRJL_NUM andalso (Tr63 =:= 0 orelse Tr62 =:= 0) ->
								%% 检查和更新 对应的字段
								{UpList, [NTr62,NTr63], _Rest} = check_and_update_list_update([63,62], [Tr62,Tr63]),
								NewAchTrials = 
									[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
									 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
									 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
									 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
									 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
									 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
									 Tr61,NTr62,NTr63,Trf],
								NewAchieve = Achieve#ets_ach_stats{trjl = NewTRTRJL},
								ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
								{UpList, NewAchTrials};
							true ->
								if
									Tr62 =:= 0 ->
										NewAchTrials = 
											[Tr1,Tr2,Tr3,Tr4,Tr5,Tr6,Tr7,Tr8,Tr9,Tr10,
											 Tr11,Tr12,Tr13,Tr14,Tr15,Tr16,Tr17,Tr18,Tr19,Tr20,
											 Tr21,Tr22,Tr23,Tr24,Tr25,Tr26,Tr27,Tr28,Tr29,Tr30,
											 Tr31,Tr32,Tr33,Tr34,Tr35,Tr36,Tr37,Tr38,Tr39,Tr40,
											 Tr41,Tr42,Tr43,Tr44,Tr45,Tr46,Tr47,Tr48,Tr49,Tr50,
											 Tr51,Tr52,Tr53,Tr54,Tr55,Tr56,Tr57,Tr58,Tr59,Tr60,
											 Tr61,1,Tr63,Trf],
										UpList = [62];
									true ->
										NewAchTrials = AchTrials,
										UpList = []
								end,
								case Tr63 =:= 0 orelse Tr62 =:= 0 of
									true ->
										NewAchieve = Achieve#ets_ach_stats{trjl = NewTRTRJL},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve);
									false ->
										skip
								end,
								{UpList, NewAchTrials}
						end;
					ASType =:= 64 ->%%最后一个成就
						{[],AchTrials};
					true ->
						{[],AchTrials}
				end,
			{RUpList, RNewAchTrials} = Result,
			[RTr1,RTr2,RTr3,RTr4,RTr5,RTr6,RTr7,RTr8,RTr9,RTr10,
			 RTr11,RTr12,RTr13,RTr14,RTr15,RTr16,RTr17,RTr18,RTr19,RTr20,
			 RTr21,RTr22,RTr23,RTr24,RTr25,RTr26,RTr27,RTr28,RTr29,RTr30,
			 RTr31,RTr32,RTr33,RTr34,RTr35,RTr36,RTr37,RTr38,RTr39,RTr40,
			 RTr41,RTr42,RTr43,RTr44,RTr45,RTr46,RTr47,RTr48,RTr49,RTr50,
			 RTr51,RTr52,RTr53,RTr54,RTr55,RTr56,RTr57,RTr58,RTr59,RTr60,
							RTr61,RTr62,RTr63,RTrf] = RNewAchTrials,
			case lib_achieve_inline:check_final_ok(length(RNewAchTrials)-1, RNewAchTrials, true) andalso RTrf =:= 0 of
				true ->
					{[64|RUpList],[RTr1,RTr2,RTr3,RTr4,RTr5,RTr6,RTr7,RTr8,RTr9,RTr10,
								   RTr11,RTr12,RTr13,RTr14,RTr15,RTr16,RTr17,RTr18,RTr19,RTr20,
								   RTr21,RTr22,RTr23,RTr24,RTr25,RTr26,RTr27,RTr28,RTr29,RTr30,
								   RTr31,RTr32,RTr33,RTr34,RTr35,RTr36,RTr37,RTr38,RTr39,RTr40,
								   RTr41,RTr42,RTr43,RTr44,RTr45,RTr46,RTr47,RTr48,RTr49,RTr50,
								    RTr51,RTr52,RTr53,RTr54,RTr55,RTr56,RTr57,RTr58,RTr59,RTr60,
							RTr61,RTr62,RTr63,1]};
				false ->
					Result
			end
	end.
%%************		远古成就		************
%% 1	等级40		等级达到40级			10	
%% 2	等级50		等级达到50级			20	
%% 3	等级60		等级达到60级			40	
%% 4	等级70		等级达到70级			60	
%% 5	远古大款		拥有1000000铜币		20	远古大款
%% 6	远古富翁		拥有100000000铜币	40	远古富翁
%% 7	修为高深		修为达到10000		20	修为高深
%% 8	神通广大		修为达到150000		40	神通广大
%% 9	修为通天		修为达到500000		60	修为通天
%% 10	封神之荣		封神台荣誉达到10000	20	封神之荣
%% 11	封神之誉		封神台荣誉达到100000	40	封神之誉
%% 12	封神荣誉		封神台荣誉达到200000	60	封神荣誉
%% 13	武学大师		学会12个技能			20	武学大师
%% 14	武学始祖		12个技能全部学满级	40	武学始祖
%% 15	资质优秀		3条经脉达到半人半神	20	资质优秀
%% 16	百里挑一		1条经脉达到仙风道骨	40	百里挑一
%% 17	三界奇才		3条经脉达到仙风道骨	60	三界奇才
%% 18	千年难遇		8条经脉达到仙风道骨	80	千年难遇
%% 19	苦心修炼		8个经脉达到5级		20	苦心修炼
%% 20	小有成就		8个经脉修炼到7级		40	小有成就
%% 21	终得大道		8个经脉达到10级		60	终得大道
%% 22	走火入魔		8个经脉修炼到15级	80	走火入魔
%% 23	远古主宰		完成所有远古任务		100	

update_achieve_yg(PlayerId, AchYg, ASType, Param) ->
	[Y1,Y2,Y3,Y4,Y5,Y6,Y7,Y8,Y9,Y10,
	 Y11,Y12,Y13,Y14,Y15,Y16,Y17,Y18,Y19,Y20,
	 Y21,Y22,Y23,Y24,Y25,Yf] = AchYg,
	Result = 
	if
		ASType =:= 4 andalso (Y1 =:= 0 orelse Y2 =:= 0 orelse Y3 =:= 0 orelse Y4 =:= 0) ->%%70级
			%% 检查和更新 对应的字段
			{UpList, [NY1,NY2,NY3,NY4], _Rest} = check_and_update_list_update([4,3,2,1], [Y1,Y2,Y3,Y4]),
			NewAchYg = 
				[NY1,NY2,NY3,NY4,Y5,Y6,Y7,Y8,Y9,Y10,
				 Y11,Y12,Y13,Y14,Y15,Y16,Y17,Y18,Y19,Y20,
				 Y21,Y22,Y23,Y24,Y25,Yf],
			{UpList, NewAchYg};
		ASType =:= 3 andalso (Y1 =:= 0 orelse Y2 =:= 0 orelse Y3 =:= 0) -> %%60级
			%% 检查和更新 对应的字段
			{UpList, [NY1,NY2,NY3], _Rest} = check_and_update_list_update([3,2,1], [Y1,Y2,Y3]),
			NewAchYg = 
				[NY1,NY2,NY3,Y4,Y5,Y6,Y7,Y8,Y9,Y10,
				 Y11,Y12,Y13,Y14,Y15,Y16,Y17,Y18,Y19,Y20,
				 Y21,Y22,Y23,Y24,Y25,Yf],
			{UpList, NewAchYg};
		ASType =:= 2 andalso (Y1 =:= 0 orelse Y2 =:= 0)->%%50级
			%% 检查和更新 对应的字段
			{UpList, [NY1,NY2], _Rest} = check_and_update_list_update([2,1], [Y1,Y2]),
			NewAchYg = 
				[NY1,NY2,Y3,Y4,Y5,Y6,Y7,Y8,Y9,Y10,
				 Y11,Y12,Y13,Y14,Y15,Y16,Y17,Y18,Y19,Y20,
				 Y21,Y22,Y23,Y24,Y25,Yf],
			{UpList, NewAchYg};
		ASType =:= 1 andalso Y1 =:= 0 ->%%40级
			NewAchYg = [1,Y2,Y3,Y4,Y5,Y6,Y7,Y8,Y9,Y10,
						Y11,Y12,Y13,Y14,Y15,Y16,Y17,Y18,Y19,Y20,
						Y21,Y22,Y23,Y24,Y25,Yf],
			{[1], NewAchYg};
		ASType =:= 5 andalso Y5 =:= 0 ->%%拥有1000000铜币
			NewAchYg = [Y1,Y2,Y3,Y4,1,Y6,Y7,Y8,Y9,Y10,
						Y11,Y12,Y13,Y14,Y15,Y16,Y17,Y18,Y19,Y20,
						Y21,Y22,Y23,Y24,Y25,Yf],
			{[5], NewAchYg};
		ASType =:= 6 andalso (Y5 =:= 0 orelse Y6 =:= 0)-> %%拥有100000000铜币
			%% 检查和更新 对应的字段
			{UpList, [NY5,NY6], _Rest} = check_and_update_list_update([6,5], [Y5,Y6]),
			NewAchYg = 
				[Y1,Y2,Y3,Y4,NY5,NY6,Y7,Y8,Y9,Y10,
				 Y11,Y12,Y13,Y14,Y15,Y16,Y17,Y18,Y19,Y20,
				 Y21,Y22,Y23,Y24,Y25,Yf],
			{UpList, NewAchYg};
		ASType =:= 7 ->%%修为消耗的
				case ets:lookup(?ACHIEVE_STATISTICS, PlayerId) of
					[] ->
						{[], AchYg};
					[Achieve] ->
						[Num] = Param,
						YgCul = Achieve#ets_ach_stats.ygcul,
						NewYgCul = YgCul + Num,
						if
							NewYgCul >= ?YG_CULTURE_THREE andalso (Y7 =:= 0 orelse Y8 =:= 0 orelse Y9 =:= 0) ->%%修为消耗达到500000
									%% 检查和更新 对应的字段
									{UpList, [NY7,NY8,NY9], _Rest} = check_and_update_list_update([9,8,7], [Y7,Y8,Y9]),
									NewAchYg = 
										[Y1,Y2,Y3,Y4,Y5,Y6,NY7,NY8,NY9,Y10,
										 Y11,Y12,Y13,Y14,Y15,Y16,Y17,Y18,Y19,Y20,
										 Y21,Y22,Y23,Y24,Y25,Yf],
									NewAchieve = Achieve#ets_ach_stats{ygcul = NewYgCul},
									ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
									{UpList, NewAchYg};
							NewYgCul >= ?YG_CULTURE_TWO andalso (Y7 =:= 0 orelse Y8 =:= 0) ->%%修为消耗达到150000
								%% 检查和更新 对应的字段
									{UpList, [NY7,NY8], _Rest} = check_and_update_list_update([8,7], [Y7,Y8]),
									NewAchYg = 
										[Y1,Y2,Y3,Y4,Y5,Y6,NY7,NY8,Y9,Y10,
										 Y11,Y12,Y13,Y14,Y15,Y16,Y17,Y18,Y19,Y20,
										 Y21,Y22,Y23,Y24,Y25,Yf],
									NewAchieve = Achieve#ets_ach_stats{ygcul = NewYgCul},
									ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
									{UpList, NewAchYg};
							NewYgCul >= ?YG_CULTURE_ONE andalso Y7 =:= 0 ->%%修为消耗达到10000
								NewAchYg = 
										[Y1,Y2,Y3,Y4,Y5,Y6,1,Y8,Y9,Y10,
										 Y11,Y12,Y13,Y14,Y15,Y16,Y17,Y18,Y19,Y20,
										 Y21,Y22,Y23,Y24,Y25,Yf],
									NewAchieve = Achieve#ets_ach_stats{ygcul = NewYgCul},
									ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
									{[7], NewAchYg};
							true ->
								case Y7 =:= 0 orelse Y8 =:= 0 orelse Y9 =:= 0 of
									true ->%%要持续添加
										NewAchieve = Achieve#ets_ach_stats{ygcul = NewYgCul},
										ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
										{[], AchYg};
									false ->%%成功就都可以了，不再累加
										{[], AchYg}
								end
						end
				end;
		ASType =:= 10 andalso Y10 =:= 0 ->%%封神台荣誉达到10000
			NewAchYg = [Y1,Y2,Y3,Y4,Y5,Y6,Y7,Y8,Y9,1,
						Y11,Y12,Y13,Y14,Y15,Y16,Y17,Y18,Y19,Y20,
						Y21,Y22,Y23,Y24,Y25,Yf],
			{[10], NewAchYg};
		ASType =:= 11 andalso (Y10 =:= 0 orelse Y11 =:= 0) ->%%封神台荣誉达到100000
			%% 检查和更新 对应的字段
			{UpList, [NY10,NY11], _Rest} = check_and_update_list_update([11,10], [Y10,Y11]),
			NewAchYg = 
				[Y1,Y2,Y3,Y4,Y5,Y6,Y7,Y8,Y9,NY10,
				 NY11,Y12,Y13,Y14,Y15,Y16,Y17,Y18,Y19,Y20,
				 Y21,Y22,Y23,Y24,Y25,Yf],
			{UpList, NewAchYg};
		ASType =:= 12 andalso (Y10 =:= 0 orelse Y11 =:= 0 orelse Y12 =:= 0) ->%%封神台荣誉达到200000
			%% 检查和更新 对应的字段
			{UpList, [NY10,NY11,NY12], _Rest} = check_and_update_list_update([12,11,10], [Y10,Y11,Y12]),
			NewAchYg = 
				[Y1,Y2,Y3,Y4,Y5,Y6,Y7,Y8,Y9,NY10,
				 NY11,NY12,Y13,Y14,Y15,Y16,Y17,Y18,Y19,Y20,
				 Y21,Y22,Y23,Y24,Y25,Yf],
			{UpList, NewAchYg};
		ASType =:= 13 andalso Y13 =:= 0 ->%%学会12个技能
			NewAchYg = [Y1,Y2,Y3,Y4,Y5,Y6,Y7,Y8,Y9,Y10,
						Y11,Y12,1,Y14,Y15,Y16,Y17,Y18,Y19,Y20,
						Y21,Y22,Y23,Y24,Y25,Yf],
			{[13], NewAchYg};
		ASType =:= 14 ->%%学会12个技能且全满级
			case Y14 =:= 0 of
				true when Y13 =:= 0 ->
					NewAchYg = 
						[Y1,Y2,Y3,Y4,Y5,Y6,Y7,Y8,Y9,Y10,
						 Y11,Y12,1,1,Y15,Y16,Y17,Y18,Y19,Y20,
						 Y21,Y22,Y23,Y24,Y25,Yf],
					{[13, 14], NewAchYg};
				true ->
					NewAchYg = 
						[Y1,Y2,Y3,Y4,Y5,Y6,Y7,Y8,Y9,Y10,
						 Y11,Y12,Y13,1,Y15,Y16,Y17,Y18,Y19,Y20,
						 Y21,Y22,Y23,Y24,Y25,Yf],
					{[14], NewAchYg};
				false when Y13 =:= 0 ->
					NewAchYg = 
						[Y1,Y2,Y3,Y4,Y5,Y6,Y7,Y8,Y9,Y10,
						 Y11,Y12,1,Y14,Y15,Y16,Y17,Y18,Y19,Y20,
						 Y21,Y22,Y23,Y24,Y25,Yf],
					{[13], NewAchYg};
				false ->
					{[], AchYg}
			end;
		ASType =:= 15 andalso Y15 =:= 0 ->%%3条经脉达到半人半神
			NewAchYg = [Y1,Y2,Y3,Y4,Y5,Y6,Y7,Y8,Y9,Y10,
						Y11,Y12,Y13,Y14,1,Y16,Y17,Y18,Y19,Y20,
						Y21,Y22,Y23,Y24,Y25,Yf],
			{[15], NewAchYg};
		ASType =:= 16 andalso Y16 =:= 0 ->%%1条经脉达到仙风道骨
			NewAchYg = [Y1,Y2,Y3,Y4,Y5,Y6,Y7,Y8,Y9,Y10,
						Y11,Y12,Y13,Y14,Y15,1,Y17,Y18,Y19,Y20,
						Y21,Y22,Y23,Y24,Y25,Yf],
			{[16], NewAchYg};
		ASType =:= 17 andalso (Y16 =:= 0 orelse Y17 =:= 0) ->%%3条经脉达到仙风道骨
			%% 检查和更新 对应的字段
			{UpList, [NY16,NY17], _Rest} = check_and_update_list_update([17,16], [Y16,Y17]),
			NewAchYg = 
				[Y1,Y2,Y3,Y4,Y5,Y6,Y7,Y8,Y9,Y10,
				 Y11,Y12,Y13,Y14,Y15,NY16,NY17,Y18,Y19,Y20,
				 Y21,Y22,Y23,Y24,Y25,Yf],
			{UpList, NewAchYg};
		ASType =:= 18 andalso (Y16 =:= 0 orelse Y17 =:= 0 orelse Y18 =:= 0) ->%%8条经脉达到仙风道骨
			%% 检查和更新 对应的字段
			{UpList, [NY16,NY17,NY18], _Rest} = check_and_update_list_update([18,17,16], [Y16,Y17,Y18]),
			NewAchYg = 
				[Y1,Y2,Y3,Y4,Y5,Y6,Y7,Y8,Y9,Y10,
				 Y11,Y12,Y13,Y14,Y15,NY16,NY17,NY18,Y19,Y20,
				 Y21,Y22,Y23,Y24,Y25,Yf],
			{UpList, NewAchYg};
		ASType =:= 22 andalso (Y19 =:= 0 orelse Y20 =:= 0 orelse Y21 =:= 0 orelse Y22 =:= 0) ->%%8个经脉修炼到15级
			%% 检查和更新 对应的字段
			{UpList, [NY19,NY20,NY21,NY22], _Rest} = check_and_update_list_update([22,21,20,19], [Y19,Y20,Y21,Y22]),
			NewAchYg = [Y1,Y2,Y3,Y4,Y5,Y6,Y7,Y8,Y9,Y10,
						Y11,Y12,Y13,Y14,Y15,Y16,Y17,Y18,NY19,NY20,
						NY21,NY22,Y23,Y24,Y25,Yf],
			{UpList, NewAchYg};
		ASType =:= 21 andalso (Y19 =:= 0 orelse Y20 =:= 0 orelse Y21 =:= 0) ->%%8个经脉达到10级
			%% 检查和更新 对应的字段
			{UpList, [NY19,NY20,NY21], _Rest} = check_and_update_list_update([21,20,19], [Y19,Y20,Y21]),
			NewAchYg = 
				[Y1,Y2,Y3,Y4,Y5,Y6,Y7,Y8,Y9,Y10,
				 Y11,Y12,Y13,Y14,Y15,Y16,Y17,Y18,NY19,NY20,
				 NY21,Y22,Y23,Y24,Y25,Yf],
			{UpList, NewAchYg};
		ASType =:= 20 andalso (Y19 =:= 0 orelse Y20 =:= 0) ->%%8个经脉修炼到7级
			%% 检查和更新 对应的字段
			{UpList, [NY19,NY20], _Rest} = check_and_update_list_update([20,19], [Y19,Y20]),
			NewAchYg = 
				[Y1,Y2,Y3,Y4,Y5,Y6,Y7,Y8,Y9,Y10,
				 Y11,Y12,Y13,Y14,Y15,Y16,Y17,Y18,NY19,NY20,
				 Y21,Y22,Y23,Y24,Y25,Yf],
			{UpList, NewAchYg};
		ASType =:= 19 andalso Y19 =:= 0 ->%%8个经脉达到5级
			NewAchYg = [Y1,Y2,Y3,Y4,Y5,Y6,Y7,Y8,Y9,Y10,
						Y11,Y12,Y13,Y14,Y15,Y16,Y17,Y18,1,Y20,
						Y21,Y22,Y23,Y24,Y25,Yf],
			{[19], NewAchYg};
		ASType =:= 23 andalso Y23 =:= 0 -> %%学习第一个技能
			NewAchYg = [Y1,Y2,Y3,Y4,Y5,Y6,Y7,Y8,Y9,Y10,
						Y11,Y12,Y13,Y14,Y15,Y16,Y17,Y18,Y19,Y20,
						Y21,Y22,1,Y24,Y25,Yf],
			{[23], NewAchYg};
		ASType =:= 24 andalso Y24 =:= 0 -> %%第一次提升灵根
			NewAchYg = [Y1,Y2,Y3,Y4,Y5,Y6,Y7,Y8,Y9,Y10,
						Y11,Y12,Y13,Y14,Y15,Y16,Y17,Y18,Y19,Y20,
						Y21,Y22,Y23,1,Y25,Yf],
			{[24], NewAchYg};
		ASType =:= 25 andalso Y25 =:= 0 -> %%第一次修炼经脉
			NewAchYg = [Y1,Y2,Y3,Y4,Y5,Y6,Y7,Y8,Y9,Y10,
						Y11,Y12,Y13,Y14,Y15,Y16,Y17,Y18,Y19,Y20,
						Y21,Y22,Y23,Y24,1,Yf],
			{[25], NewAchYg};
		ASType =:= 26 ->%%完成最后的一个了
			{[], AchYg};
		true ->
			{[], AchYg}
	end,
	{RUpList, RNewAchYg} = Result,
	[RY1,RY2,RY3,RY4,RY5,RY6,RY7,RY8,RY9,RY10,
	 RY11,RY12,RY13,RY14,RY15,RY16,RY17,RY18,RY19,RY20,
	 RY21,RY22,RY23,RY24,RY25,RYf] = RNewAchYg,
	case lib_achieve_inline:check_final_ok(length(RNewAchYg)-1, RNewAchYg, true) andalso RYf =:= 0 of
		true ->
			{[26|RUpList],[RY1,RY2,RY3,RY4,RY5,RY6,RY7,RY8,RY9,RY10,
						   RY11,RY12,RY13,RY14,RY15,RY16,RY17,RY18,RY19,RY20,
						   RY21,RY22,RY23,RY24,RY25,1]};
		false ->
			Result
	end.
	
%%************		封神成就		************
%% 1	百年诛邪		开启百年诛邪1200次		40	百年诛邪
%% 2	千年诛邪		开启千年诛邪1200次		60	千年诛邪
%% 3	万年诛邪		开启万年诛邪1200次		80	万年诛邪
%% 4	VIP会员		成为VIP会员				20	VIP会员
%% 5	大富翁		在商城中购买100件道具		40	大富翁
%% 6	宝石之星		50次成功利用材料合成宝石	40	宝石之星
%% 7	商人			在市场中成功挂售100件物品	40	商人
%% 8	购物狂		在市场中购买100件物品		40	购物狂
%% 9	分解狂		在炼炉中分解1000件装备	40	分解狂
%% 10	静心打坐		离线挂机累计200小时		20	静心打坐
%% 11	潜心修炼		离线挂机累计500小时		40	潜心修炼
%% 12	初级灵兽		灵兽等级达到5级			10	
%% 13	中级灵兽		灵兽等级达到10级			20	
%% 14	高级灵兽		灵兽等级达到25级			40	
%% 15	平庸灵兽		灵兽资质达到30			20	
%% 16	极品灵兽		灵兽资质达到55			40	
%% 17	成长40		灵兽成长达到40			20	
%% 18	成长50		灵兽成长达到50			40	
%% 19	成长60		灵兽成长达到60			80	
%% 20	神兽相伴		获得一只化形后的灵兽		40	神兽相伴
%% 21	隐世强者		达成所有封神成就			100	隐世强者

update_achieve_fs(PlayerId, AchFS, ASType, Param) ->
	[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
	 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
	 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
	 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
	 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
	 Ff] = AchFS,
%% 	?DEBUG("update_achieve_fs, PlayerId:~p, AchFS:~p, ASType:~p, Param:~p", [PlayerId, AchFS, ASType, Param]),
	case ets:lookup(?ACHIEVE_STATISTICS, PlayerId) of
		[] ->
			fail;
		[Achieve] ->
			Result = 
			if
				ASType =:= 1 ->%%百年 诛邪次数统计
					[Num] = Param,
					FSB = Achieve#ets_ach_stats.fsb,
					[One,Two,Three] = FSB,
					NewNum = One + Num,
					case NewNum >= ?FS_FSB_ONE of
						true when F1 =:= 0 andalso F21 =:= 0->
							NewAchFS = 
								[1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 1,F22,F23,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewFSB = [NewNum,Two,Three],
							NewAchieve = Achieve#ets_ach_stats{fsb = NewFSB},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[1,21], NewAchFS};
						true when F1 =:= 0 andalso F21 =/= 0 ->
							NewAchFS = 
								[1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewFSB = [NewNum,Two,Three],
							NewAchieve = Achieve#ets_ach_stats{fsb = NewFSB},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[1], NewAchFS};
						true when F1 =/= 0 andalso F21 =:= 0 ->
							NewAchFS = 
								[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 1,F22,F23,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							{[21], NewAchFS};
						true ->
							{[], AchFS};
						false when F21 =:= 0 andalso NewNum > 0 ->
							NewAchFS = 
								[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 1,F22,F23,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewFSB = [NewNum,Two,Three],
							NewAchieve = Achieve#ets_ach_stats{fsb = NewFSB},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[21], NewAchFS};
						false ->
							NewFSB = [NewNum,Two,Three],
							NewAchieve = Achieve#ets_ach_stats{fsb = NewFSB},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[], AchFS}
					end;
				ASType =:= 2 ->%%千年 诛邪次数统计
					[Num] = Param,
					FSB = Achieve#ets_ach_stats.fsb,
					[One,Two,Three] = FSB,
					NewNum = Two + Num,
					case NewNum >= ?FS_FSB_TWO of
						true when F2 =:= 0 andalso F21 =:= 0 ->
							NewAchFS = 
								[F1,1,F3,F4,F5,F6,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 1,F22,F23,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewFSB = [One,NewNum,Three],
							NewAchieve = Achieve#ets_ach_stats{fsb = NewFSB},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[2,21], NewAchFS};
						true when F2 =:= 0 andalso F21 =/= 0 ->
							NewAchFS = 
								[F1,1,F3,F4,F5,F6,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 1,F22,F23,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewFSB = [One,NewNum,Three],
							NewAchieve = Achieve#ets_ach_stats{fsb = NewFSB},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[2], NewAchFS};
						true when F2 =/= 0 andalso F21 =:= 0 ->
							NewAchFS = 
								[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 1,F22,F23,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							{[21], NewAchFS};
						true ->
							{[], AchFS};
						false when F21 =:= 0 andalso NewNum > 0 ->
							NewAchFS = 
								[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 1,F22,F23,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewFSB = [One,NewNum,Three],
							NewAchieve = Achieve#ets_ach_stats{fsb = NewFSB},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[21], NewAchFS};
						false ->
							NewFSB = [One,NewNum,Three],
							NewAchieve = Achieve#ets_ach_stats{fsb = NewFSB},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[], AchFS}
					end;
				ASType =:= 3 ->%%万年 诛邪次数统计
					[Num] = Param,
					TRFSB = Achieve#ets_ach_stats.fsb,
					[One,Two,Three] = TRFSB,
					NewNum = Three + Num,
					case NewNum >= ?FS_FSB_THREE of
						true when F3 =:= 0 andalso F21 =:= 0 ->
							NewAchFS = 
								[F1,F2,1,F4,F5,F6,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 1,F22,F23,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewFSB = [One,Two,NewNum],
							NewAchieve = Achieve#ets_ach_stats{fsb = NewFSB},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[3, 21], NewAchFS};
						true when F3 =:= 0 andalso F21 =/= 0->
							NewAchFS = 
								[F1,F2,1,F4,F5,F6,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewFSB = [One,Two,NewNum],
							NewAchieve = Achieve#ets_ach_stats{fsb = NewFSB},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[3], NewAchFS};
						true when F3 =/= 0 andalso F21 =:= 0 ->
							NewAchFS = 
								[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 1,F22,F23,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							{[21], NewAchFS};
						true ->
							{[], AchFS};
						false when F21 =:= 0 andalso NewNum > 0 ->
							NewAchFS = 
								[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 1,F22,F23,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewFSB = [One,Two,NewNum],
							NewAchieve = Achieve#ets_ach_stats{fsb = NewFSB},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[21], NewAchFS};
						false ->
							NewFSB = [One,Two,NewNum],
%% 							NewFSBStr = util:term_to_string(NewFSB),
%% 							db_agent:update_ach_stats(achieve_statistics, [{fsb, NewFSBStr}], [{pid, PlayerId}]),
							NewAchieve = Achieve#ets_ach_stats{fsb = NewFSB},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[], AchFS}
					end;
				ASType =:= 4 andalso F4 =:= 0 ->%%会员
					NewAchFS = 
						[F1,F2,F3,1,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
						 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
						 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
						 Ff],
					{[4], NewAchFS};
				ASType =:= 5 ->%%购买
					[Num] = Param,
					FSSH =  Achieve#ets_ach_stats.fssh,
					NewFSSH = FSSH + Num,
					case NewFSSH >= ?FS_FSSH of
						true when F5 =:= 0 andalso F22 =:= 0 ->
							NewAchFS = 
								[F1,F2,F3,F4,1,F6,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 F21,1,F23,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewAchieve = Achieve#ets_ach_stats{fssh = NewFSSH},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[5, 22], NewAchFS};
						true when F5 =:= 0 andalso F22 =/= 0 ->
							NewAchFS = 
								[F1,F2,F3,F4,1,F6,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewAchieve = Achieve#ets_ach_stats{fssh = NewFSSH},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[5], NewAchFS};
						true when F5 =/= 0 andalso F22 =:= 0 ->
							NewAchFS = 
								[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 F21,1,F23,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							{[22], NewAchFS};
						true ->
							{[], AchFS};
						false when F22 =:= 0 ->
							NewAchFS = 
								[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 F21,1,F23,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewAchieve = Achieve#ets_ach_stats{fssh = NewFSSH},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[22], NewAchFS};
						false ->
							NewAchieve = Achieve#ets_ach_stats{fssh = NewFSSH},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[], AchFS}
					end;
				ASType =:= 6 ->%%宝石合成
					[Num] = Param,
					FSC = Achieve#ets_ach_stats.fsc,
					[One,Two] = FSC,
					NewNum = One + Num,
					case NewNum >= ?FS_FSC_ONE of
						true when F6 =:= 0 andalso F23 =:= 0 ->
							NewAchFS = 
								[F1,F2,F3,F4,F5,1,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 F21,F22,1,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewFSC = [NewNum,Two],
							NewAchieve = Achieve#ets_ach_stats{fsc = NewFSC},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[6,23], NewAchFS};
						true when F6 =:= 0 andalso F23 =/=0 ->
							NewAchFS = 
								[F1,F2,F3,F4,F5,1,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewFSC = [NewNum,Two],
							NewAchieve = Achieve#ets_ach_stats{fsc = NewFSC},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[6], NewAchFS};
						true when F6 =/= 0 andalso F23 =:= 0 ->
							NewAchFS = 
								[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 F21,F22,1,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							{[23], NewAchFS};
						true ->
							{[], AchFS};
						false when F23 =:= 0 ->
							NewAchFS = 
								[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 F21,F22,1,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewFSC = [NewNum,Two],
							NewAchieve = Achieve#ets_ach_stats{fsc = NewFSC},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[23], NewAchFS};
						false ->
							NewFSC = [NewNum,Two],
							NewAchieve = Achieve#ets_ach_stats{fsc = NewFSC},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[], AchFS}
					end;
				ASType =:= 7 ->%%市场挂售
					[Num] = Param,
					FSSA = Achieve#ets_ach_stats.fssa,
					[One,Two] = FSSA,
					NewNum = One + Num,
					case NewNum >= ?FS_FSSA_ONE of
						true when F7 =:= 0 andalso F24 =:= 0 ->
							NewAchFS = 
								[F1,F2,F3,F4,F5,F6,1,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 F21,F22,F23,1,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewFSSA = [NewNum,Two],
							NewAchieve = Achieve#ets_ach_stats{fssa = NewFSSA},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[7, 24], NewAchFS};
						true when F7 =:= 0 andalso F24 =/= 0->
							NewAchFS = 
								[F1,F2,F3,F4,F5,F6,1,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewFSSA = [NewNum,Two],
							NewAchieve = Achieve#ets_ach_stats{fssa = NewFSSA},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[7], NewAchFS};
						true when F7 =/= 0 andalso F24 =:= 0 ->
							NewAchFS = 
								[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 F21,F22,F23,1,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							{[24], NewAchFS};
						true ->
							{[], AchFS};
						false when F24 =:= 0 ->
							NewAchFS = 
								[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 F21,F22,F23,1,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewFSSA = [NewNum,Two],
							NewAchieve = Achieve#ets_ach_stats{fssa = NewFSSA},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[24], NewAchFS};
						false ->
							NewFSSA = [NewNum,Two],
							NewAchieve = Achieve#ets_ach_stats{fssa = NewFSSA},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[], AchFS}
					end;
				ASType =:= 8 ->%%市场购买
					[Num] = Param,
					FSSA = Achieve#ets_ach_stats.fssa,
					[One,Two] = FSSA,
					NewNum = Two + Num,
					case NewNum >= ?FS_FSSA_TWO of
						true when F8 =:= 0  andalso F25 =:= 0 ->
							NewAchFS = 
								[F1,F2,F3,F4,F5,F6,F7,1,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 F21,F22,F23,F24,1,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewFSSA = [One,NewNum],
							NewAchieve = Achieve#ets_ach_stats{fssa = NewFSSA},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[8, 25], NewAchFS};
						true when F8 =:= 0 andalso F25 =/= 0 ->
							NewAchFS = 
								[F1,F2,F3,F4,F5,F6,F7,1,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewFSSA = [One,NewNum],
							NewAchieve = Achieve#ets_ach_stats{fssa = NewFSSA},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[8], NewAchFS};
						true when F8 =/= 0 andalso F25 =:= 0 ->
							NewAchFS = 
								[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 F21,F22,F23,F24,1,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							{[25], NewAchFS};
						true ->
							{[], AchFS};
						false when F25 =:= 0 ->
							NewAchFS = 
								[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 F21,F22,F23,F24,1,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewFSSA = [One,NewNum],
							NewAchieve = Achieve#ets_ach_stats{fssa = NewFSSA},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[25], NewAchFS};
						false ->
							NewFSSA = [One,NewNum],
							NewAchieve = Achieve#ets_ach_stats{fssa = NewFSSA},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[], AchFS}
					end;
				ASType =:= 9 ->%%物品分解
					[Num] = Param,
					FSC = Achieve#ets_ach_stats.fsc,
					[One,Two] = FSC,
					NewNum = Two + Num,
					case NewNum >= ?FS_FSC_TWO of
						true when F9 =:= 0 andalso F26 =:= 0 ->
							NewAchFS = 
								[F1,F2,F3,F4,F5,F6,F7,F8,1,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 F21,F22,F23,F24,F25,1,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewFSC = [One,NewNum],
							NewAchieve = Achieve#ets_ach_stats{fsc = NewFSC},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[9, 26], NewAchFS};
						true when F9 =:= 0 andalso F26 =/= 0 ->
							NewAchFS = 
								[F1,F2,F3,F4,F5,F6,F7,F8,1,F10,
								 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
								 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
								 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
								 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
								 Ff],
							NewFSC = [One,NewNum],
							NewAchieve = Achieve#ets_ach_stats{fsc = NewFSC},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[9], NewAchFS};
						true when F9 =/= 0 andalso F26 =:= 0 ->
							NewAchFS = [F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
							F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
							F21,F22,F23,F24,F25,1,F27,F28,F29,F30,
	 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
	 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
	 Ff],
							{[26], NewAchFS};
						true ->
							{[], AchFS};
						false when F26 =:= 0 ->
							NewAchFS = [F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
							F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
							F21,F22,F23,F24,F25,1,F27,F28,F29,F30,
	 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
	 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
	 Ff],
							NewFSC = [One,NewNum],
							NewAchieve = Achieve#ets_ach_stats{fsc = NewFSC},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[26], NewAchFS};
						false ->
							NewFSC = [One,NewNum],
							NewAchieve = Achieve#ets_ach_stats{fsc = NewFSC},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[], AchFS}
					end;
				ASType =:= 10 orelse ASType =:= 11 ->%%离线挂机
					[NumMin] = Param,%%分钟
%% 					Num = NumMin div 60,
					case NumMin =< 0 of
						true ->%%等于0的数值，直接扔了，返回
							{[], AchFS};
						false ->
							FSLG = Achieve#ets_ach_stats.fslg,
							NewFSLG = FSLG + NumMin,
							if 
								NewFSLG >= ?FS_FSLG_TWO andalso (F10 =:= 0 orelse F11 =:= 0) ->
									%% 检查和更新 对应的字段
									{UpList, [NF10,NF11,NF27], _Rest} = check_and_update_list_update([27,11,10], [F10,F11,F27]),
									NewAchFS = 
										[F1,F2,F3,F4,F5,F6,F7,F8,F9,NF10,
										 NF11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
										 F21,F22,F23,F24,F25,F26,NF27,F28,F29,F30,
	 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
	 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
	 Ff],
									NewAchieve = Achieve#ets_ach_stats{fslg = NewFSLG},
									ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
									{UpList, NewAchFS};
								NewFSLG >= ?FS_FSLG_ONE andalso F10 =:= 0 ->
									%% 检查和更新 对应的字段
									{UpList, [NF10,NF27], _Rest} = check_and_update_list_update([27,10], [F10,F27]),
									NewAchFS = 
										[F1,F2,F3,F4,F5,F6,F7,F8,F9,NF10,
										 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
										 F21,F22,F23,F24,F25,F26,NF27,F28,F29,F30,
	 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
	 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
	 Ff],
									NewAchieve = Achieve#ets_ach_stats{fslg = NewFSLG},
									ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
									{UpList, NewAchFS};
								true ->
									if
										F27 =:= 0 ->
											NewAchFS = 
												[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
												 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
												 F21,F22,F23,F24,F25,F26,1,F28,F29,F30,
	 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
	 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
	 Ff],
											UpList = [27];
										true ->
											NewAchFS = AchFS,
											UpList = []
									end,
									case F10 =:= 0 orelse F11 =:= 0 of
										true ->
											NewAchieve = Achieve#ets_ach_stats{fslg = NewFSLG},
											ets:insert(?ACHIEVE_STATISTICS, NewAchieve);
										false ->
											skip
									end,
									{UpList, NewAchFS}
							end
					end;
				ASType =:= 12 andalso F12 =:= 0 ->%%灵兽等级达到5级
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,1,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
	 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
	 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
	 Ff],
					{[12], NewAchFS};
				ASType =:= 13 andalso (F12 =:= 0 orelse F13 =:= 0) ->%%灵兽等级达到10级
					%% 检查和更新 对应的字段
					{UpList, [NF12,NF13], _Rest} = check_and_update_list_update([13,12], [F12,F13]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,NF12,NF13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
	 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
	 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
	 Ff],
					{UpList, NewAchFS};
				ASType =:= 14 andalso (F12 =:= 0 orelse F13 =:= 0 orelse F14 =:= 0) ->%%灵兽等级达到20级
					%% 检查和更新 对应的字段
					{UpList, [NF12,NF13,NF14], _Rest} = check_and_update_list_update([14,13,12], [F12,F13,F14]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,NF12,NF13,NF14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
	 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
	 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
	 Ff],
					{UpList, NewAchFS};
				ASType =:= 15 andalso F15 =:= 0 ->%%灵兽资质达到30
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,1,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
	 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
	 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
	 Ff],
					{[15], NewAchFS};
				ASType =:= 16 andalso (F15 =:= 0 orelse F16 =:= 0) ->%%灵兽资质达到55
					%% 检查和更新 对应的字段
					{UpList, [NF15,NF16], _Rest} = check_and_update_list_update([16,15], [F15,F16]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,NF15,NF16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
	 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
	 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
	 Ff],
					{UpList, NewAchFS};
				ASType =:= 17 andalso F17 =:= 0 ->%%灵兽成长达到40
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,1,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
	 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
	 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
	 Ff],
					{[17], NewAchFS};
				ASType =:= 18 andalso (F17 =:= 0 orelse F18 =:= 0) ->%%灵兽成长达到50
					%% 检查和更新 对应的字段
					{UpList, [NF17,NF18], _Rest} = check_and_update_list_update([18,17], [F17,F18]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,NF17,NF18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
	 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
	 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
	 Ff],
					{UpList, NewAchFS};
				ASType =:= 19 andalso (F17 =:= 0 orelse F18 =:= 0 orelse F19 =:= 0) ->%%灵兽成长60
					%% 检查和更新 对应的字段 
					{UpList, [NF17,NF18,NF19], _Rest} = check_and_update_list_update([19,18,17], [F17,F18,F19]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,NF17,NF18,NF19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
	 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
	 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
	 Ff],
					{UpList, NewAchFS};
				ASType =:= 20 andalso F20 =:= 0 ->%%灵兽化形
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,1,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
	 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
	 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
	 Ff],
					{[20], NewAchFS};
				ASType =:= 28 andalso F28 =:=0 ->%%获得一只灵兽
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,1,F29,F30,
	 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
	 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
	 Ff],
					{[28], NewAchFS};
				ASType =:= 51 ->%%完成所有的
					{[], AchFS};
				ASType =:= 29 andalso F29 =:= 0 ->%%获得第一个五阶灵兽技能
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,1,F30,
						 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
						 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
						 Ff],
					{[29], NewAchFS};
				ASType =:= 30 andalso (F29 =:= 0 orelse F30 =:= 0) ->%%获得五个五阶灵兽技能
					%% 检查和更新 对应的字段 
					{UpList, [NF29,NF30], _Rest} = check_and_update_list_update([30,29], [F29,F30]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,NF29,NF30,
						 F31,F32,F33,F34,F35,F36,F37,F38,F39,F40,
						 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
						 Ff],
					{UpList, NewAchFS};
				ASType =:= 31 andalso F31 =:= 0 ->%%获得第一件神器
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
						 1,F32,F33,F34,F35,F36,F37,F38,F39,F40,
						 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
						 Ff],
					{[31], NewAchFS};
				ASType =:= 32 andalso (F31 =:= 0 orelse F32 =:= 0 )->%%神器达到3阶
					%% 检查和更新 对应的字段 
					{UpList, [NF31,NF32], _Rest} = check_and_update_list_update([32,31], [F31,F32]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
						 NF31,NF32,F33,F34,F35,F36,F37,F38,F39,F40,
						 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
						 Ff],
					{UpList, NewAchFS};
				ASType =:= 33 andalso (F32 =:= 0 orelse F33 =:= 0 orelse F31 =:= 0) ->%%神器达到5阶
					%% 检查和更新 对应的字段 
					{UpList, [NF31,NF32,NF33], _Rest} = check_and_update_list_update([33,32,31], [F31,F32,F33]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
						 NF31,NF32,NF33,F34,F35,F36,F37,F38,F39,F40,
						 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
						 Ff],
					{UpList, NewAchFS};
				ASType =:= 34 andalso (F32 =:= 0 orelse F33 =:= 0 orelse F34 =:= 0 orelse F31 =:= 0) ->%%神器达到7阶
					%% 检查和更新 对应的字段 
					{UpList, [NF31,NF32,NF33,NF34], _Rest} = check_and_update_list_update([34,33,32,31], [F31,F32,F33,F34]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
						 NF31,NF32,NF33,NF34,F35,F36,F37,F38,F39,F40,
						 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
						 Ff],
					{UpList, NewAchFS};
				
				ASType =:= 35 andalso (F31 =:= 0 orelse F35 =:= 0)->%%神器品质进阶为蓝色
					%% 检查和更新 对应的字段 
					{UpList, [NF31,NF35], _Rest} = check_and_update_list_update([35,31], [F31,F35]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
						 NF31,F32,F33,F34,NF35,F36,F37,F38,F39,F40,
						 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
						 Ff],
					{UpList, NewAchFS};
				ASType =:= 36 andalso (F31 =:= 0 orelse F35 =:= 0 orelse F36 =:= 0) ->%%神器品质进阶为金色
					%% 检查和更新 对应的字段 
					{UpList, [NF31,NF35,NF36], _Rest} = check_and_update_list_update([36,35,31], [F31,F35,F36]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
						 NF31,F32,F33,F34,NF35,NF36,F37,F38,F39,F40,
						 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
						 Ff],
					{UpList, NewAchFS};
				ASType =:= 37 andalso (F31 =:= 0 orelse F35 =:= 0 orelse F36 =:= 0 orelse F37 =:= 0) ->%%神器品质进阶为紫色
					%% 检查和更新 对应的字段 
					{UpList, [NF31,NF35,NF36,NF37], _Rest} = check_and_update_list_update([37,36,35,31], [F31,F35,F36,F37]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
						 NF31,F32,F33,F34,NF35,NF36,NF37,F38,F39,F40,
						 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
						 Ff],
					{UpList, NewAchFS};
				ASType =:= 38 andalso F38 =:= 0 ->%%拥有第一只坐骑
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
						 F30,F32,F33,F34,F35,F36,F37,1,F39,F40,
						 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
						 Ff],
					{[38], NewAchFS};
				ASType =:= 39 andalso (F38 =:= 0 orelse F39 =:= 0) ->%%第一次提升坐骑品阶
					%% 检查和更新 对应的字段 
					{UpList, [NF38,NF39], _Rest} = check_and_update_list_update([39,38], [F38,F39]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
						 F31,F32,F33,F34,F35,F36,F37,NF38,NF39,F40,
						 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
						 Ff],
					{UpList, NewAchFS};
				ASType =:= 40 andalso (F38 =:= 0 orelse F39 =:= 0 orelse F40 =:= 0)->%%1只坐骑达到3阶
					%% 检查和更新 对应的字段 
					{UpList, [NF38,NF39,NF40], _Rest} = check_and_update_list_update([40,39,38], [F38,F39,F40]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
						 F31,F32,F33,F34,F35,F36,F37,NF38,NF39,NF40,
						 F41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
						 Ff],
					{UpList, NewAchFS};
				ASType =:= 41 andalso (F38 =:= 0 orelse F39 =:= 0 orelse F40 =:= 0 orelse F41 =:= 0)->%%1只坐骑达到3阶
					%% 检查和更新 对应的字段 
					{UpList, [NF38,NF39,NF40,NF41], _Rest} = check_and_update_list_update([41,40,39,38], [F38,F39,F40,F41]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
						 F31,F32,F33,F34,F35,F36,F37,NF38,NF39,NF40,
						 NF41,F42,F43,F44,F45,F46,F47,F48,F49,F50,
						 Ff],
					{UpList, NewAchFS};
				ASType =:= 42 andalso (F38 =:= 0 orelse F39 =:= 0 orelse F40 =:= 0 orelse F41 =:= 0
									  orelse F42 =:= 0)->%%1只坐骑达到5阶
					%% 检查和更新 对应的字段 
					{UpList, [NF38,NF39,NF40,NF41,NF42], _Rest} = check_and_update_list_update([42,41,40,39,38], [F38,F39,F40,F41,F42]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
						 F31,F32,F33,F34,F35,F36,F37,NF38,NF39,NF40,
						 NF41,NF42,F43,F44,F45,F46,F47,F48,F49,F50,
						 Ff],
					{UpList, NewAchFS};
				ASType =:= 43 andalso (F38 =:= 0 orelse F39 =:= 0 orelse F40 =:= 0 orelse F41 =:= 0
									  orelse F42 =:= 0 orelse F43 =:= 0)->%%1只坐骑达到6阶
					%% 检查和更新 对应的字段 
					{UpList, [NF38,NF39,NF40,NF41,NF42,NF43], _Rest} = check_and_update_list_update([43,42,41,40,39,38], [F38,F39,F40,F41,F42,F43]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
						 F31,F32,F33,F34,F35,F36,F37,NF38,NF39,NF40,
						 NF41,NF42,NF43,F44,F45,F46,F47,F48,F49,F50,
						 Ff],
					{UpList, NewAchFS};
				ASType =:= 44 andalso (F38 =:= 0 orelse F39 =:= 0 orelse F40 =:= 0 orelse F41 =:= 0
									  orelse F42 =:= 0 orelse F43 =:= 0 orelse F44 =:= 0)->%%1只坐骑达到7阶
					%% 检查和更新 对应的字段 
					{UpList, [NF38,NF39,NF40,NF41,NF42,NF43,NF44], _Rest} = check_and_update_list_update([44,43,42,41,40,39,38], [F38,F39,F40,F41,F42,F43,F44]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
						 F31,F32,F33,F34,F35,F36,F37,NF38,NF39,NF40,
						 NF41,NF42,NF43,NF44,F45,F46,F47,F48,F49,F50,
						 Ff],
					{UpList, NewAchFS};
				ASType =:= 45 andalso (F38 =:= 0 orelse F39 =:= 0 orelse F40 =:= 0 orelse F41 =:= 0
									  orelse F42 =:= 0 orelse F43 =:= 0 orelse F44 =:= 0 orelse F45 =:= 0)->%%1只坐骑达到8阶
					%% 检查和更新 对应的字段 
					{UpList, [NF38,NF39,NF40,NF41,NF42,NF43,NF44,NF45], _Rest} = check_and_update_list_update([45,44,43,42,41,40,39,38], [F38,F39,F40,F41,F42,F43,F44,F45]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
						 F31,F32,F33,F34,F35,F36,F37,NF38,NF39,NF40,
						 NF41,NF42,NF43,NF44,NF45,F46,F47,F48,F49,F50,
						 Ff],
					{UpList, NewAchFS};
				ASType =:= 46 andalso (F38 =:= 0 orelse F39 =:= 0 orelse F40 =:= 0 orelse F41 =:= 0
									  orelse F42 =:= 0 orelse F43 =:= 0 orelse F44 =:= 0 orelse F45 =:= 0
									  orelse F46 =:= 0)->%%1只坐骑达到9阶
					%% 检查和更新 对应的字段 
					{UpList, [NF38,NF39,NF40,NF41,NF42,NF43,NF44,NF45,NF46], _Rest} = check_and_update_list_update([46,45,44,43,42,41,40,39,38], [F38,F39,F40,F41,F42,F43,F44,F45,F46]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
						 F31,F32,F33,F34,F35,F36,F37,NF38,NF39,NF40,
						 NF41,NF42,NF43,NF44,NF45,NF46,F47,F48,F49,F50,
						 Ff],
					{UpList, NewAchFS};
				ASType =:= 47 andalso (F38 =:= 0 orelse F39 =:= 0 orelse F40 =:= 0 orelse F41 =:= 0
									  orelse F42 =:= 0 orelse F43 =:= 0 orelse F44 =:= 0 orelse F45 =:= 0
									  orelse F46 =:= 0 orelse F47 =:= 0)->%%1只坐骑达到10阶
					%% 检查和更新 对应的字段 
					{UpList, [NF38,NF39,NF40,NF41,NF42,NF43,NF44,NF45,NF46,NF47], _Rest} = check_and_update_list_update([47,46,45,44,43,42,41,40,39,38], [F38,F39,F40,F41,F42,F43,F44,F45,F46,F47]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
						 F31,F32,F33,F34,F35,F36,F37,NF38,NF39,NF40,
						 NF41,NF42,NF43,NF44,NF45,NF46,NF47,F48,F49,F50,
						 Ff],
					{UpList, NewAchFS};
				ASType =:= 48 andalso (F38 =:= 0 orelse F48 =:= 0) ->%%1只坐骑强化等级达到7
					%% 检查和更新 对应的字段 
					{UpList, [NF38,NF48], _Rest} = check_and_update_list_update([48,38], [F38,F48]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
						 F31,F32,F33,F34,F35,F36,F37,NF38,F39,F40,
						 F41,F42,F43,F44,F45,F46,F47,NF48,F49,F50,
						 Ff],
					{UpList, NewAchFS};
				ASType =:= 49 andalso (F38 =:= 0 orelse F48 =:= 0 orelse F49 =:= 0) ->%%1只坐骑强化等级达到10
					%% 检查和更新 对应的字段 
					{UpList, [NF38,NF48,NF49], _Rest} = check_and_update_list_update([49,48,38], [F38,F48,F49]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
						 F31,F32,F33,F34,F35,F36,F37,NF38,F39,F40,
						 F41,F42,F43,F44,F45,F46,F47,NF48,NF49,F50,
						 Ff],
					{UpList, NewAchFS};
				ASType =:= 50 andalso (F50 =:= 0 orelse F38 =:= 0) ->%%激活17个坐骑图鉴
					%% 检查和更新 对应的字段 
					{UpList, [NF38,NF50], _Rest} = check_and_update_list_update([50,38], [F38,F50]),
					NewAchFS = 
						[F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,
						 F11,F12,F13,F14,F15,F16,F17,F18,F19,F20,
						 F21,F22,F23,F24,F25,F26,F27,F28,F29,F30,
						 F31,F32,F33,F34,F35,F36,F37,NF38,F39,F40,
						 F41,F42,F43,F44,F45,F46,F47,F48,F49,NF50,
						 Ff],
					{UpList, NewAchFS};
				true ->
					{[], AchFS}
			end,
			{RUpList, RNewAchFS} = Result,
			[RF1,RF2,RF3,RF4,RF5,RF6,RF7,RF8,RF9,RF10,
			 RF11,RF12,RF13,RF14,RF15,RF16,RF17,RF18,RF19,RF20,
			 RF21,RF22,RF23,RF24,RF25,RF26,RF27,RF28,RF29,RF30,
			 RF31,RF32,RF33,RF34,RF35,RF36,RF37,RF38,RF39,RF40,
			 RF41,RF42,RF43,RF44,RF45,RF46,RF47,RF48,RF49,RF50,
			 RFf] = RNewAchFS,
			case lib_achieve_inline:check_final_ok(length(RNewAchFS)-1, RNewAchFS, true) andalso RFf =:= 0 of
				true ->
					{[51|RUpList],[RF1,RF2,RF3,RF4,RF5,RF6,RF7,RF8,RF9,RF10,
								   RF11,RF12,RF13,RF14,RF15,RF16,RF17,RF18,RF19,RF20,
								   RF21,RF22,RF23,RF24,RF25,RF26,RF27,RF28,RF29,RF30,
								   RF31,RF32,RF33,RF34,RF35,RF36,RF37,RF38,RF39,RF40,
								   RF41,RF42,RF43,RF44,RF45,RF46,RF47,RF48,RF49,RF50,
	 1]};
				false ->
					Result
			end
	end.
%%************		互动成就		************
%% 1	为人师表		有1个徒弟出师				10	为人师表
%% 2	循循善诱		有2个徒弟出师				40	循循善诱
%% 3	桃李天下		有3个徒弟出师				60	桃李天下
%% 4	融入氏族		加入一个氏族					20	融入氏族
%% 5	氏族功臣		氏族贡献达到10000			60	氏族功臣
%% 6	广交好友		拥有5个好友					10	广交好友
%% 7	高朋满座		拥有20个好友					20	高朋满座
%% 8	宾客盈门		拥有30个好友					40	宾客盈门
%% 9	以花传情		赠送任意好友鲜花				10	以花传情
%% 10	花漫漫天		赠送任意好友99朵以上鲜花		20	花漫漫天
%% 11	多情公子		赠送任意好友3000朵以上鲜花	60	多情公子
%% 12	气质非凡		魅力值达到20点				10	气质非凡
%% 13	魅力四射		魅力值达到1314点				20	魅力四射
%% 14	万人迷		魅力值达到3344点				40	万人迷
%% 15	情窦初开		完成仙侣情缘1次				10	情窦初开
%% 16	情圣			完成仙侣情缘20次				40	情圣
%% 17	初次应约		仙侣情缘中被邀请过1次			10	初次应约
%% 18	人见人爱		仙侣情缘中被邀请过40次		40	人见人爱
%% 19				神之庄园中收获100次			20	
%% 20				神之庄园中收获10000次		40	
%% 21	小偷			神之庄园中偷取100次			20	小偷
%% 22	岁月神偷		神之庄园中偷取10000次		40	岁月神偷
%% 23	大地主		神之庄园中拥有9块土地			40	大地主
%% 24	魅力无限		完成所有的互动成就			100	魅力无限

update_achieve_interact(PlayerId, AchInteract, ASType, Param) ->
	[IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
	 IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
	 IN21,IN22,IN23,IN24,IN25,IN26,IN27,IN28,IN29,IN30,IN31,IN32,INF] = AchInteract,
	case ets:lookup(?ACHIEVE_STATISTICS, PlayerId) of
		[] ->
			fail;
		[Achieve] ->
			Result = 
			if
				ASType =:= 1 andalso IN1 =:= 0 -> %%有1个徒弟出师
					NewAchInteract = 
						[1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
						 IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
						 IN21,IN22,IN23,IN24,IN25,IN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
					{[1], NewAchInteract};
				ASType =:= 2 andalso (IN1 =:= 0 orelse IN2 =:= 0) ->%%有2个徒弟出师
					%% 检查和更新 对应的字段
					{UpList, [NIN1,NIN2], _Rest} = check_and_update_list_update([2,1], [IN1,IN2]),
					NewAchInteract = 
						[NIN1,NIN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
						 IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
						 IN21,IN22,IN23,IN24,IN25,IN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
					{UpList, NewAchInteract};
				ASType =:= 3 andalso (IN1 =:= 0 orelse IN2 =:= 0 orelse IN3 =:= 0) ->%%有3个徒弟出师
					%% 检查和更新 对应的字段
					{UpList, [NIN1,NIN2,NIN3], _Rest} = check_and_update_list_update([3,2,1], [IN1,IN2,IN3]),
					NewAchInteract = 
						[NIN1,NIN2,NIN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
						 IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
						 IN21,IN22,IN23,IN24,IN25,IN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
					{UpList, NewAchInteract};
				ASType =:= 4 andalso IN4 =:= 0 ->%%加入氏族
					NewAchInteract = 
						[IN1,IN2,IN3,1,IN5,IN6,IN7,IN8,IN9,IN10,
						 IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
						 IN21,IN22,IN23,IN24,IN25,IN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
					{[4], NewAchInteract};
				ASType =:= 5 andalso IN5 =:= 0 ->%%氏族贡献
					[Num] = Param,
					case Num >= ?INTERACT_GUILD_DONATE of
						true ->
							NewAchInteract = 
								[IN1,IN2,IN3,IN4,1,IN6,IN7,IN8,IN9,IN10,
								 IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
								 IN21,IN22,IN23,IN24,IN25,IN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
							{[5], NewAchInteract};
						false ->
							{[], AchInteract}
					end;
				ASType =:= 6 andalso IN6 =:= 0 ->%%拥有5个好友
					NewAchInteract = 
						[IN1,IN2,IN3,IN4,IN5,1,IN7,IN8,IN9,IN10,
						 IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
						 IN21,IN22,IN23,IN24,IN25,IN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
%% 					io:format("~~608~~~p\n", [6]),
					{[6], NewAchInteract};
				ASType =:= 7 andalso (IN6 =:= 0 orelse IN7 =:= 0) ->%%拥有20个好友
					%% 检查和更新 对应的字段
					{UpList, [NIN6,NIN7], _Rest} = check_and_update_list_update([7,6], [IN6,IN7]),
					NewAchInteract = 
						[IN1,IN2,IN3,IN4,IN5,NIN6,NIN7,IN8,IN9,IN10,
						 IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
						 IN21,IN22,IN23,IN24,IN25,IN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
%% 					io:format("~~607~~~p\n", [UpList]),
					{UpList, NewAchInteract};
				ASType =:= 8 andalso (IN6 =:= 0 orelse IN7 =:= 0 orelse IN8 =:= 0) ->%%拥有30个好友
					%% 检查和更新 对应的字段
					{UpList, [NIN6,NIN7,NIN8], _Rest} = check_and_update_list_update([8,7,6], [IN6,IN7,IN8]),
					NewAchInteract = 
						[IN1,IN2,IN3,IN4,IN5,NIN6,NIN7,NIN8,IN9,IN10,
						 IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
						 IN21,IN22,IN23,IN24,IN25,IN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
%% 					io:format("~~608~~~p\n", [UpList]),
					{UpList, NewAchInteract}; 
				ASType =:= 9 orelse ASType =:= 10 orelse ASType =:= 11 ->%%送花
					[Num] = Param,
					INFL = Achieve#ets_ach_stats.infl,
					NewINFL = INFL + Num,
					if
						NewINFL >= ?INTERACT_INFO_THREE andalso (IN9 =:= 0 orelse IN10 =:= 0 orelse IN11 =:= 0) ->%%赠送任意好友3000朵以上鲜花
							%% 检查和更新 对应的字段
							{UpList, [NIN9,NIN10,NIN11], _Rest} = check_and_update_list_update([11,10,9], [IN9,IN10,IN11]),
							NewAchInteract = 
								[IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,NIN9,NIN10,
								 NIN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
								 IN21,IN22,IN23,IN24,IN25,IN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
							NewAchieve = Achieve#ets_ach_stats{infl = NewINFL},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{UpList, NewAchInteract};
						NewINFL >= ?INTERACT_INFL_TWO andalso (IN9 =:= 0 orelse IN10 =:= 0) ->%%赠送任意好友99朵以上鲜花
							%% 检查和更新 对应的字段
							{UpList, [NIN9,NIN10], _Rest} = check_and_update_list_update([10,9], [IN9,IN10]),
							NewAchInteract = 
								[IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,NIN9,NIN10,
								 IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
								 IN21,IN22,IN23,IN24,IN25,IN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
							NewAchieve = Achieve#ets_ach_stats{infl = NewINFL},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{UpList, NewAchInteract};
						NewINFL >= ?INTERACT_INFL_ONE andalso IN9 =:= 0 ->%%赠送任意好友鲜花
							NewAchInteract = [IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,1,IN10,
											  IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
											  IN21,IN22,IN23,IN24,IN25,IN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
							NewAchieve = Achieve#ets_ach_stats{infl = NewINFL},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[9], NewAchInteract};
						true ->
							case IN9 =:= 0 orelse IN10 =:= 0 orelse IN11 =:= 0 of
								true ->
									NewAchieve = Achieve#ets_ach_stats{infl = NewINFL},
									ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
									{[], AchInteract};
								false ->
									{[], AchInteract}
							end
					end;
				ASType =:= 12 andalso IN12 =:= 0 ->%%魅力值达到20点
					NewAchInteract = 
						[IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
						 IN11,1,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
						 IN21,IN22,IN23,IN24,IN25,IN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
					{[12], NewAchInteract};
				ASType =:= 13 andalso (IN12 =:= 0 orelse IN13 =:= 0) ->%%魅力值达到1314点
					%% 检查和更新 对应的字段
					{UpList, [NIN12,NIN13], _Rest} = check_and_update_list_update([13,12], [IN12,IN13]),
					NewAchInteract = 
						[IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
						 IN11,NIN12,NIN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
						 IN21,IN22,IN23,IN24,IN25,IN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
					{UpList, NewAchInteract};
				ASType =:= 14 andalso (IN12 =:= 0 orelse IN13 =:= 0 orelse IN14 =:= 0) -> %%魅力值达到3344点
					%% 检查和更新 对应的字段
					{UpList, [NIN12,NIN13,NIN14], _Rest} = check_and_update_list_update([14,13,12], [IN12,IN13,IN14]),
					NewAchInteract = 
						[IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
						 IN11,NIN12,NIN13,NIN14,IN15,IN16,IN17,IN18,IN19,IN20,
						 IN21,IN22,IN23,IN24,IN25,IN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
					{UpList, NewAchInteract};
				ASType =:= 15 orelse ASType =:= 16 ->%%完成仙侣情缘
					[Num] = Param,
					INLV = Achieve#ets_ach_stats.inlv,
					NewINLV = INLV + Num,
					if 
						NewINLV >= ?INTERACT_INLV_TWO andalso (IN15 =:= 0 orelse IN16 =:= 0) ->%%完成仙侣情缘20次
							%% 检查和更新 对应的字段
							{UpList, [NIN15,NIN16], _Rest} = check_and_update_list_update([16,15], [IN15,IN16]),
							NewAchInteract = [IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
											  IN11,IN12,IN13,IN14,NIN15,NIN16,IN17,IN18,IN19,IN20,
											  IN21,IN22,IN23,IN24,IN25,IN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
							NewAchieve = Achieve#ets_ach_stats{inlv = NewINLV},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{UpList, NewAchInteract};
						NewINLV >= ?INTERACT_INLV_ONE andalso IN15 =:= 0 ->%%完成仙侣情缘1次
							NewAchInteract = [IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
											  IN11,IN12,IN13,IN14,1,IN16,IN17,IN18,IN19,IN20,
											  IN21,IN22,IN23,IN24,IN25,IN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
							NewAchieve = Achieve#ets_ach_stats{inlv = NewINLV},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[15], NewAchInteract};
						true ->
							case IN15 =:= 0 orelse IN16 =:= 0 of
								true ->
									NewAchieve = Achieve#ets_ach_stats{inlv = NewINLV},
									ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
									{[], AchInteract};
								false ->
									{[], AchInteract}
							end
					end;		
				ASType =:= 17 orelse ASType =:= 18 ->%%仙侣情缘邀请
					[Num] = Param,
					INLVED = Achieve#ets_ach_stats.inlved,
					NewINLVED = INLVED + Num,
					if 
						NewINLVED >= ?INTERACT_INLVED_TWO andalso (IN17 =:= 0 orelse IN18 =:= 0) ->%%仙侣情缘中被邀请过40次
							%% 检查和更新 对应的字段
							{UpList, [NIN17,NIN18], _Rest} = check_and_update_list_update([18,17], [IN17,IN18]),
							NewAchInteract = [IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
											  IN11,IN12,IN13,IN14,IN15,IN16,NIN17,NIN18,IN19,IN20,
											  IN21,IN22,IN23,IN24,IN25,IN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
							NewAchieve = Achieve#ets_ach_stats{inlved = NewINLVED},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{UpList, NewAchInteract};
						NewINLVED >= ?INTERACT_INLVED_ONE andalso IN17 =:= 0 ->%%仙侣情缘中被邀请过1次
							NewAchInteract = [IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
											  IN11,IN12,IN13,IN14,IN15,IN16,1,IN18,IN19,IN20,
											  IN21,IN22,IN23,IN24,IN25,IN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
							NewAchieve = Achieve#ets_ach_stats{inlved = NewINLVED},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{[17], NewAchInteract};
						true ->
							case IN17 =:= 0 orelse IN18 =:= 0 of
								true ->
									NewAchieve = Achieve#ets_ach_stats{inlved = NewINLVED},
									ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
									{[], AchInteract};
								false ->
									{[], AchInteract}
							end
					end;		
				ASType =:= 19 orelse ASType =:= 20 ->%%庄园收获东西
					[Num] = Param,
%%					?DEBUG("19,20, :~p", [Num]),
					INFAI = Achieve#ets_ach_stats.infai,
					NewINFAI = INFAI + Num,
					if 
						NewINFAI >= ?INTERACT_INFAI_TWO andalso (IN19 =:= 0 orelse IN20 =:= 0) ->%%神之庄园中收获1000次  
							%% 检查和更新 对应的字段
							{UpList, [NIN19,NIN20,NIN26], _Rest} = check_and_update_list_update([26,20,19], [IN19,IN20,IN26]),
							NewAchInteract = [IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
											  IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,NIN19,NIN20,
											  IN21,IN22,IN23,IN24,IN25,NIN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
							NewAchieve = Achieve#ets_ach_stats{infai = NewINFAI},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{UpList, NewAchInteract};
						NewINFAI >= ?INTERACT_INFAI_ONE andalso IN19 =:= 0 ->%%神之庄园中收获100次
							%% 检查和更新 对应的字段
							{UpList, [NIN19,NIN26], _Rest} = check_and_update_list_update([26,19], [IN19,IN26]),
							NewAchInteract = [IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
											  IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,NIN19,IN20,
											  IN21,IN22,IN23,IN24,IN25,NIN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
							NewAchieve = Achieve#ets_ach_stats{infai = NewINFAI},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{UpList, NewAchInteract};
						true ->
							if
								IN26 =:= 0 ->
									NewAchInteract = [IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
											  IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
											  IN21,IN22,IN23,IN24,IN25,1,IN27,IN28,IN29,IN30,IN31,IN32,INF],
									UpList = [26];
								true ->
									NewAchInteract = AchInteract,
									UpList = []
							end,
							case IN19 =:= 0 orelse IN20 =:= 0 of
								true ->
									NewAchieve = Achieve#ets_ach_stats{infai = NewINFAI},
									ets:insert(?ACHIEVE_STATISTICS, NewAchieve);
								false ->
									skip
							end,
							{UpList, NewAchInteract}
					end;		
				ASType =:= 21 orelse ASType =:= 22 ->%%庄园偷东西
					[Num] = Param,
					INFAO = Achieve#ets_ach_stats.infao,
					NewINFAO = INFAO + Num,
					if 
						NewINFAO >= ?INTERACT_INFAO_TWO andalso (IN21 =:= 0 orelse IN22 =:= 0) ->
							%% 检查和更新 对应的字段
							{UpList, [NIN21,NIN22,NIN27], _Rest} = check_and_update_list_update([27,22,21], [IN21,IN22,IN27]),
							NewAchInteract = [IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
											  IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
											  NIN21,NIN22,IN23,IN24,IN25,IN26,NIN27,IN28,IN29,IN30,IN31,IN32,INF],
							NewAchieve = Achieve#ets_ach_stats{infao = NewINFAO},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{UpList, NewAchInteract};
						NewINFAO >= ?INITERACT_INFAO_ONE andalso IN21 =:= 0 ->%%神之庄园中偷取100次
							%% 检查和更新 对应的字段
							{UpList, [NIN21,NIN27], _Rest} = check_and_update_list_update([27,21], [IN21,IN27]),
							NewAchInteract = [IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
											  IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
											  NIN21,IN22,IN23,IN24,IN25,IN26,NIN27,IN28,IN29,IN30,IN31,IN32,INF],
							NewAchieve = Achieve#ets_ach_stats{infao = NewINFAO},
							ets:insert(?ACHIEVE_STATISTICS, NewAchieve),
							{UpList, NewAchInteract};
						true ->
							if
								IN27 =:= 0 ->
									NewAchInteract = 
										[IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
										 IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
										 IN21,IN22,IN23,IN24,IN25,IN26,1,IN28,IN29,IN30,IN31,IN32,INF],
									UpList = [27];
								true ->
									NewAchInteract = AchInteract,
									UpList = []
							end,
							case IN21 =:= 0 orelse IN22 =:= 0 of
								true ->
									NewAchieve = Achieve#ets_ach_stats{infao = NewINFAO},
									ets:insert(?ACHIEVE_STATISTICS, NewAchieve);
								false ->
									skip
							end,
							{UpList, NewAchInteract}
					end;		
				ASType =:= 23 andalso IN23 =:= 0 ->%%庄园拥有土地
					NewAchInteract = 
						[IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
						 IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
						 IN21,IN22,1,IN24,IN25,IN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
					{[23], NewAchInteract};
				ASType =:= 24 andalso IN24 =:= 0 ->%%获得第一个徒弟
					NewAchInteract = 
						[IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
						 IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
						 IN21,IN22,IN23,1,IN25,IN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
					{[24], NewAchInteract};
				ASType =:= 25 andalso IN25 =:= 0 ->%%拥有一个好友
					NewAchInteract = 
						[IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
						 IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
						 IN21,IN22,IN23,IN24,1,IN26,IN27,IN28,IN29,IN30,IN31,IN32,INF],
					{[25], NewAchInteract};
				ASType =:= 28 orelse ASType =:= 29 ->%%被鄙视
					[BS] = Param,
%%					?DEBUG("omg, BS:~p", [BS]),
					if 
						BS >= ?INTERACT_BS_TWO andalso (IN28 =:= 0 orelse IN29 =:= 0) ->%%被鄙视次数2000
							%% 检查和更新 对应的字段
							{UpList, [NIN28,NIN29], _Rest} = check_and_update_list_update([29,28], [IN28,IN29]),
							NewAchInteract = [IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
											  IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
											  IN21,IN22,IN23,IN24,IN25,IN26,IN27,NIN28,NIN29,IN30,IN31,IN32,INF],
							put(player_bs,BS),
							{UpList, NewAchInteract};
						BS >= ?INTERACT_BS_ONE andalso IN28 =:= 0 ->%%被鄙视次数100
							NewAchInteract = [IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
											  IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
											  IN21,IN22,IN23,IN24,IN25,IN26,IN27,1,IN29,IN30,IN31,IN32,INF],
							put(player_bs,BS),
							{[28], NewAchInteract};
						true ->
							put(player_bs,BS),
							{[], AchInteract}
					end;		
				ASType =:= 30 orelse ASType =:= 31 ->%%被崇拜
					[CB] = Param,
%%					?DEBUG("wow, CB:~p", [CB]),
					if 
						CB >= ?INTERACT_CB_TWO andalso (IN30 =:= 0 orelse IN31 =:= 0) ->%%被崇拜次数2000
							%% 检查和更新 对应的字段
							{UpList, [NIN30,NIN31], _Rest} = check_and_update_list_update([31,30], [IN30,IN31]),
							NewAchInteract = [IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
											  IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
											  IN21,IN22,IN23,IN24,IN25,IN26,IN27,IN28,IN29,NIN30,NIN31,IN32,INF],
							put(player_cb, CB),
							{UpList, NewAchInteract};
						CB >= ?INTERACT_CB_ONE andalso IN30 =:= 0 ->%%被崇拜次数100
							NewAchInteract = [IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
											  IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
											  IN21,IN22,IN23,IN24,IN25,IN26,IN27,IN28,IN29,1,IN31,IN32,INF],
							put(player_cb, CB),
							{[30], NewAchInteract};
						true ->
							put(player_cb, CB),
							{[], AchInteract}
					end;
				ASType =:= 32 andalso IN32 =:= 0 ->%%与自己最心爱之人喜结良缘
					NewAchInteract = 
						[IN1,IN2,IN3,IN4,IN5,IN6,IN7,IN8,IN9,IN10,
						 IN11,IN12,IN13,IN14,IN15,IN16,IN17,IN18,IN19,IN20,
						 IN21,IN22,IN23,IN24,IN25,IN26,IN27,IN28,IN29,IN30,IN31,1,INF],
%% 					io:format("~~608~~~p\n", [6]),
					{[32], NewAchInteract};
				ASType =:= 33 ->%%完成所有
					{[], AchInteract};
				true ->
					{[], AchInteract}
			end,
			{RUpList, RNewAchInteract} = Result,
			[RIN1,RIN2,RIN3,RIN4,RIN5,RIN6,RIN7,RIN8,RIN9,RIN10,
			 RIN11,RIN12,RIN13,RIN14,RIN15,RIN16,RIN17,RIN18,RIN19,RIN20,
			 RIN21,RIN22,RIN23,RIN24,RIN25,RIN26,RIN27,RIN28,RIN29,RIN30,RIN31,RIN32,RINF] = RNewAchInteract,
			case lib_achieve_inline:check_final_ok(length(RNewAchInteract)-1, RNewAchInteract, true) andalso RINF =:= 0 of
				true ->
					{[33|RUpList],[RIN1,RIN2,RIN3,RIN4,RIN5,RIN6,RIN7,RIN8,RIN9,RIN10,
								   RIN11,RIN12,RIN13,RIN14,RIN15,RIN16,RIN17,RIN18,RIN19,RIN20,
								   RIN21,RIN22,RIN23,RIN24,RIN25,RIN26,RIN27,RIN28,RIN29,RIN30,RIN31,RIN32,1]};
				false ->
					Result
			end
	end.

%% -----------------------------------------------------------------
%% 38000 总成就获取
%% -----------------------------------------------------------------
get_achieves(Player) ->
	case lib_achieve_inline:get_achieve_ets(Player#player.id) of
		[] ->
			{[],[],[],[],[],[]};
		[Achieve] ->
			case ets:lookup(?ACHIEVE_STATISTICS, Player#player.id) of
				[] ->
					{[],[],[],[],[],[]};
				[AchStatistics] ->
					get_achieves(Achieve, AchStatistics, Player)
			end
	end.
%% 份别总成就获取		
get_achieves(Achieve, AchStatistics, Player) ->
	#ets_achieve{ach_task = AchTask,
				 ach_epic = AchEpic,
				 ach_trials = AchTrials,
				 ach_yg = AchYg,
				 ach_fs = AchFs,
				 ach_interact = AchInteract} = Achieve,
	Task = lib_achieve_inline:get_achieve_task(AchTask,AchStatistics,Player),
	Epic = lib_achieve_inline:get_achieve_epic(AchEpic,AchStatistics,Player),
	Trials = lib_achieve_inline:get_achieve_trials(AchTrials,AchStatistics,Player),
	Yg = lib_achieve_inline:get_achieve_yg(AchYg,AchStatistics,Player),
	Fs = lib_achieve_inline:get_achieve_fs(AchFs,AchStatistics,Player),
	Interact = lib_achieve_inline:get_achieve_interact(AchInteract,AchStatistics,Player),
	{Task, Epic, Trials, Yg, Fs, Interact}.

%% -----------------------------------------------------------------
%% 38001 获取最近完成成就
%% -----------------------------------------------------------------
get_achieve_log(PlayerId) ->
	Pattern = #ets_log_ach_f{pid = PlayerId, _ = '_'},
	Result = ets:match_object(?ACHIEVE_LOG, Pattern),
	lib_achieve_inline:get_achieve_log(Result).

%% -----------------------------------------------------------------
%% 38004 八神珠 已装备
%% -----------------------------------------------------------------
get_ach_pearl_equiped(PlayerId) ->
	Ms = ets:fun2ms(fun(T) when T#goods.player_id == PlayerId 
						 andalso T#goods.location == 2
						 andalso T#goods.cell =/= 0 ->
							T
					end),
	Objects = ets:select(?ETS_GOODS_ONLINE, Ms),
	lists:map(fun(Elem) ->
					  {Elem#goods.id,Elem#goods.goods_id, Elem#goods.cell}
			  end, Objects).
	
%% -----------------------------------------------------------------
%% 38005 八神珠 未装备
%% -----------------------------------------------------------------
get_ach_pearl_equipno(PlayerId) ->
	Ms = ets:fun2ms(fun(T) when T#goods.player_id =:= PlayerId 
						 andalso T#goods.location =:= 2 
						 andalso T#goods.cell =:= 0->
							T
					end),
	Objects = ets:select(?ETS_GOODS_ONLINE, Ms),
	lists:map(fun(Elem) ->
					  {Elem#goods.id,Elem#goods.goods_id}
			  end, Objects).
	
%% -----------------------------------------------------------------
%% 38006 八神珠  装备和卸载
%% -----------------------------------------------------------------
%%检查操作的八神珠是否合法
check_pearl(GoodsId, Type, PlayerId, AchPearl) ->
	lib_achieve_inline:check_pearl(GoodsId, Type, PlayerId, AchPearl).
		
load_unload_pearl(GoodsId, Type, GoodsInfo, Status) ->
	case lib_achieve_inline:load_unload_pearl(GoodsId, Type, GoodsInfo, Status) of
		{fail, Error} ->
			{fail, {Error, GoodsId, 0}};
		{NewStatus, GoodsId, GoodsTypeId, Cell} ->
			{ok, {NewStatus, {1, GoodsTypeId, Cell}}}
	end.

%% 杀怪成就
%% Player 人物RECORD
%% MonType 怪物类型
%% MonTypeId 怪物类型ID
kill_mon_achieve(PlayerId, Pid, PidSend, MonType, MonTypeId) ->
	case MonType of
		%% 普通怪成就
		1 ->
			check_achieve_finish(PidSend, PlayerId, 301, [1]);
		%% 精英怪
		2 ->
			check_achieve_finish(PidSend, PlayerId, 301, [1]);
		_ ->
			case MonTypeId of
				%% 火凤
				Value when Value =:= 42001 orelse Value =:= 42023 orelse Value =:= 42025 ->
					%%氏族祝福任务判断
					GWParam = {28, 1},
					lib_gwish_interface:check_player_gwish(Pid, GWParam),
					check_achieve_finish(PidSend, PlayerId, 303, [1]);
				%% 千年老龟
				Value when Value =:= 42003 orelse Value =:= 42027 orelse Value =:= 42029 ->
					%%氏族祝福任务判断
					GWParam = {28, 1},
					lib_gwish_interface:check_player_gwish(Pid, GWParam),
					check_achieve_finish(PidSend, PlayerId, 304, [1]);
				%% 麒麟兽
				Value when Value =:= 42005 orelse Value =:= 42031 orelse Value =:= 42033 ->
					%%氏族祝福任务判断
					GWParam = {28, 1},
					lib_gwish_interface:check_player_gwish(Pid, GWParam),
					check_achieve_finish(PidSend, PlayerId, 305, [1]);
				%% 灵狐
				42007 ->
					%%氏族祝福任务判断
					GWParam = {29, 1},
					lib_gwish_interface:check_player_gwish(Pid, GWParam),
					check_achieve_finish(PidSend, PlayerId, 306, [1]);
				%% 裂地斧魔
				42009 ->
					%%氏族祝福任务判断
					GWParam = {29, 1},
					lib_gwish_interface:check_player_gwish(Pid, GWParam),
					check_achieve_finish(PidSend, PlayerId, 307, [1]);
				%% 千年猴妖
				42011 ->
					%%氏族祝福任务判断
					GWParam = {29, 1},
					lib_gwish_interface:check_player_gwish(Pid, GWParam),
					check_achieve_finish(PidSend, PlayerId, 308, [1]);
				%%精英boss 千年毒尸
				42017 ->
					%%氏族祝福任务判断
					GWParam = {29, 1},
					lib_gwish_interface:check_player_gwish(Pid, GWParam),
					lib_achieve:check_achieve_finish(PidSend,PlayerId, 360, [1]);
				%% 雷公
				41010 ->
					check_achieve_finish(PidSend, PlayerId, 329, [1]);
				%% 狐小小
				41020 ->
					check_achieve_finish(PidSend, PlayerId, 330, [1]);
				%% 河伯
				41030 ->
					check_achieve_finish(PidSend, PlayerId, 331, [1]);
				%% 蚩尤
				41040 ->
					check_achieve_finish(PidSend, PlayerId, 332, [1]);
				%%蛮荒巨龙
				Value when Value =:= 42021 orelse Value =:= 42039 orelse Value =:= 42041 ->
					%%氏族祝福任务判断
					GWParam = {28, 1},
					lib_gwish_interface:check_player_gwish(Pid, GWParam),
					lib_achieve:check_achieve_finish(PidSend,PlayerId, 362, [1]);
				%% 千年毒尸（单）
				46020 ->
					%%氏族祝福任务判断
					GWParam = {7, 1},
					lib_gwish_interface:check_player_gwish(Pid, GWParam),
					check_achieve_finish(PidSend, PlayerId, 323, [1]);
				%%30层单人  狂暴尸鸟
				46030 ->
					%%氏族祝福任务判断
					GWParam = {7, 1},
					lib_gwish_interface:check_player_gwish(Pid, GWParam);
				%%40层单人  龙门火蜥
				46040 ->
					%%氏族祝福任务判断
					GWParam = {7, 1},
					lib_gwish_interface:check_player_gwish(Pid, GWParam);
				%% 千年毒尸（多）
				46090 ->
					%%氏族祝福任务判断
					GWParam = {8, 1},
					lib_gwish_interface:check_player_gwish(Pid, GWParam),
					check_achieve_finish(PidSend, PlayerId, 326, [1]);
				%% 龙骨甲兽（单）
				46050 ->
					check_achieve_finish(PidSend, PlayerId, 324, [1]);
				%% 龙骨甲兽（多）
				46120 ->
					check_achieve_finish(PidSend, PlayerId, 327, [1]);
				%% 食腐树妖（单）
				46070 ->
					check_achieve_finish(PidSend, PlayerId, 325, [1]);
				%% 食腐树妖（多）
				46140 ->
					check_achieve_finish(PidSend, PlayerId, 328, [1]);
				 %%赤尾狐
				42013 ->
					%%氏族祝福任务判断
					GWParam = {29, 1},
					lib_gwish_interface:check_player_gwish(Pid, GWParam),
					check_achieve_finish(PidSend, PlayerId, 342, [1]);
				%%穷奇巨兽
				Value when Value =:= 42015 orelse Value =:= 42035 orelse Value =:= 42037 ->
					%%氏族祝福任务判断
					GWParam = {28, 1},
					lib_gwish_interface:check_player_gwish(Pid, GWParam),
					check_achieve_finish(PidSend, PlayerId, 340, [1]);
				%%瑶池圣母
				41056 ->
					check_achieve_finish(PidSend, PlayerId, 352, [1]);
%% 				 魔界蜂后 单人的
				46010 ->
					check_achieve_finish(PidSend, PlayerId, 346, [1]);
%% 				魔界蜂后 多人的
				46080 ->
					check_achieve_finish(PidSend, PlayerId, 347, [1]);
				47009 ->%%封神台9层
%% 					?DEBUG("MonTypeId:~p", [MonTypeId]),
					%%氏族祝福任务判断
					GWParam = {6, 1},
					lib_gwish_interface:check_player_gwish(Pid, GWParam),
					lib_achieve:check_achieve_finish(PidSend,PlayerId, 343, [1]);
				47012 ->%%封神台12层
%% 					?DEBUG("fst 12MonTypeId:~p", [MonTypeId]),
					lib_activity:update_activity_data(fst12, Pid, PlayerId, 1),%%添加玩家活跃度统计
					lib_achieve:check_achieve_finish(PidSend,PlayerId, 314, [1]);
				47024 -> %%封神台21层
%% 					?DEBUG("fst 21MonTypeId:~p", [MonTypeId]),
					lib_achieve:check_achieve_finish(PidSend,PlayerId, 315, [1]);
				47056 -> %%封神台45层
%% 					?DEBUG("fst 45MonTypeId:~p", [MonTypeId]),
					lib_achieve:check_achieve_finish(PidSend,PlayerId, 316, [1]);
				47066 ->%%9层诛仙台
%% 					?DEBUG("zxt 9MonTypeId:~p", [MonTypeId]),
					%%氏族祝福任务判断
					GWParam = {10, 1},
					lib_gwish_interface:check_player_gwish(Pid, GWParam),
					lib_achieve:check_achieve_finish(PidSend,PlayerId, 348, [1]);
				47069 -> %%12层诛仙台
%% 					?DEBUG("zxt 12MonTypeId:~p", [MonTypeId]),
					lib_achieve:check_achieve_finish(PidSend,PlayerId, 349, [1]);
				47078 -> %%21层诛仙台
%% 					?DEBUG("zxt 21MonTypeId:~p", [MonTypeId]),
					lib_achieve:check_achieve_finish(PidSend,PlayerId, 350, [1]);
				47087 -> %%30层诛仙台
%% 					?DEBUG("zxt 30MonTypeId:~p", [MonTypeId]),
					lib_achieve:check_achieve_finish(PidSend,PlayerId, 351, [1]);
				41109 ->%%共工
					lib_achieve:check_achieve_finish(PidSend,PlayerId, 359, [1]);
				Value when Value =:= 41092 orelse Value =:= 41093 orelse Value =:= 41094 orelse Value =:= 41095
				  orelse Value =:= 41096 orelse Value =:= 41097 orelse Value =:= 41098 ->%%试炼之祖
					lib_achieve:check_achieve_finish(PidSend,PlayerId, 356, [1]);
				_ ->
					skip
			end
	end.
		
%% @spec -> check_and_update_list_update(Achs, List)
%% 检查和更新 对应的字段
%% param  形如  Achs:[5,4,3,2,1], List:[T1,T2,T3,T4,T5]
%% return 形如 result:{Uplist, [NT1,NT2,NT3,NT4,NT5], []}
check_and_update_list_update(Achs, List) ->
	lists:foldr(fun(Elem, AccIn) ->
						{EUp, EAch, EList} = AccIn,
						[ENum|ERest] = EList,
						case Elem =:= 0 of
							true ->
								{[ENum|EUp], [1|EAch], ERest};
							false ->
								{EUp, [Elem|EAch], ERest}
						end
				end, {[], [], Achs}, List).	
	
%%离线挂机数据兼容性处理
compare_ach_fslg() ->
	Result = db_agent:find_allcompare_ach_fslg(),
	lists:foreach(fun(Elem) ->
						  [Pid, Fslg] = Elem,
						  NFslg = erlang:trunc(Fslg*60),
						  ValueList = [{fslg, NFslg}],
						  WhereList = [{pid, Pid}],
						  db_agent:update_compare_ach_fslg(ValueList, WhereList)
				  end, Result),
	io:format("Oh, good, it is ok!").

						  
				
%%做一些特殊的成就数据记录
make_log_update_ach(PlayerId, Ach, Data) ->
	erlang:spawn(fun() ->
						 NowTime = util:unixtime(),
%% 						 ?DEBUG("PlayerId:~p, Ach:~p, Data:~p, NowTime:~p", [PlayerId, Ach, Data, NowTime]),
						 db_agent:make_log_update_ach(PlayerId, Ach, Data, NowTime)
				 end).
	
%% 远古目标获取成就数据判断(人物进程里调用)
%% return:true or false
check_ach_foryg_target(PlayerId, Type) ->
	%%检测是否已经加载过 成就系统的数据
	lib_achieve_inline:check_achieve_init(PlayerId),
	case ets:lookup(?ACHIEVE_STATISTICS, PlayerId) of
		[] ->
			false;
		[AchieveStats] ->
			case lib_achieve_inline:get_achieve_ets(PlayerId) of
				[] ->
					false;
				[Achieve] ->
					Result = 
						case Type of
							dungeon_25 ->%% 通关雷公殿dungeon_25
								[One,_Two,_Three,_Four] = AchieveStats#ets_ach_stats.trfbb,
								One;
							dungeon_35 ->%% 通关狐狸洞dungeon_35
								[_One,Two,_Three,_Four] = AchieveStats#ets_ach_stats.trfbb,
								Two;
							fst_6 ->%% 通关封神台6层fst_6
								Trials = Achieve#ets_achieve.ach_trials,
								lists:nth(43, Trials);
							td_20 ->%% 击退镇妖台20波怪物td_20
								[One,_Two,_Three] = AchieveStats#ets_ach_stats.trstd,
								One;
							dungeon_45 ->%% 通关河神殿dungeon_45
								[_One,_Two,Three,_Four] = AchieveStats#ets_ach_stats.trfbb,
								Three;
							fst_14 ->%% 通关封神台14层fst_14
								[_One,Two,_Three] = AchieveStats#ets_ach_stats.trfst,
								Two;
							dungeon_55 ->%% 通关蚩尤墓dungeon_55
								[_One,_Two,_Three,Four] = AchieveStats#ets_ach_stats.trfbb,
								Four;
							zxt_14 ->%% 通关诛仙台14层zxt_14
								[_One,Two,_Three] = AchieveStats#ets_ach_stats.trzxt,
								Two;
							td_70 ->%% 击退单人镇妖第70波怪物td_70
								[_One,_Two,Three] = AchieveStats#ets_ach_stats.trstd,
								Three;
							zxt_20 ->%% 通关诛仙台zxt_20
								[_One,_Two,Three] = AchieveStats#ets_ach_stats.trzxt,
								Three;
							_ ->
								0
						end,
					Result > 0
			end
	end.