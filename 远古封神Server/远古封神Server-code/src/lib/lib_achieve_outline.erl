%% Author: xianrongMai
%% Created: 2011-6-30
%% Description: 成就系统专门提供对外调用的接口
-module(lib_achieve_outline).

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
		 mount_stren_check/2,			%%坐骑强化
		 old_mount_ach_check/2,			%%坐骑成就判断
		 mount_ach_check/3,
		 old_deputy_ach_check/2,		%%神器成就判断
		 deputy_ach_check/3,
		 pet_ach_check/2,				%%灵兽成就判断
		 honor_ach_check/2,				%%荣誉成就判断
		 add_exp_check/2,				%%经验成就判断
		 delete_player_ach_info/1,		%%删除指定玩家的成就数据
		 update_player_statistics/1,	%%更新玩家的statistics表的成就数据
		 check_player_old_date/2,		%%触发检测玩家的旧成就数据
		 get_achieve_title/4,			%%获取玩家的称号
		 update_palyer_title/2,			%%更新玩家的称号
		 init_ach_pearls/1,				%%初始化获取玩家神珠的装备情况
		 check_ach_goods_use/3,			%%物品使用的成就情况判断
		 check_equip_ach/3,				%%装备成就判断
		 player_adore/3,				%%鄙视和崇拜的成就判断
		 repair_player_titles/0,
		 claim_ach_title/2,				%% 38011
		 claim_love_title/3,
		 change_tieles_sex/2,			%%修改玩家的称号Id，(仅提供变性功能使用)
		 cancel_ach_title/2,			%% 38010
		 use_ach_title/2, 				%% 38009
		 get_ach_title/2,				%% 38008 
		 inform_ach_finish/3,			%% 38007
		 load_unload_pearl/3,			%% 38006
		 get_ach_pearl_equipno/1,  	 	%% 38005
		 get_ach_pearl_equiped/1,		%% 38004
		 get_ach_treasure/2,			%% 38003
		 get_achieves/1, 				%% 38000
		 get_achieve_log/1, 			%% 38001
		 get_ach_treasure_list/2		%% 38002
		]).

%%
%% API Functions
%%
get_achieve_title(AType, SAType, Achieve, PlayerId) ->
	AchNum = AType*100 + SAType,
	Titles = Achieve#ets_achieve.ach_titles,
	case AType of
		1 ->
			AchTask = Achieve#ets_achieve.ach_task,
			%%查询是否能够领取称号
			lib_achieve_inline:update_player_titles(ach_task, AType, SAType, AchTask, AchNum, Titles, Achieve, PlayerId);
		2 ->
			AchEpic = Achieve#ets_achieve.ach_epic,
			lib_achieve_inline:update_player_titles(ach_epic, AType, SAType, AchEpic, AchNum, Titles, Achieve, PlayerId);
		3 ->
			AchTrials = Achieve#ets_achieve.ach_trials,
			lib_achieve_inline:update_player_titles(ach_trials, AType, SAType, AchTrials, AchNum, Titles, Achieve, PlayerId);
		4 ->
			AchYg = Achieve#ets_achieve.ach_yg,
			lib_achieve_inline:update_player_titles(ach_yg, AType, SAType, AchYg, AchNum, Titles, Achieve, PlayerId);
		5 ->
			AchFs = Achieve#ets_achieve.ach_fs,
			lib_achieve_inline:update_player_titles(ach_fs, AType, SAType, AchFs, AchNum, Titles, Achieve, PlayerId);
		6 ->
			AchInteract = Achieve#ets_achieve.ach_interact,
			lib_achieve_inline:update_player_titles(ach_interact, AType, SAType, AchInteract, AchNum, Titles, Achieve, PlayerId);
		_ ->
			Achieve
	end.

				
					
	
%%初始化获取玩家神珠的装备情况
init_ach_pearls(Pattern) ->
	lists:foldl(fun(Elem, AccIn) ->
					  #goods{id = Gid,
							 goods_id = GoodsTypeId,
							 cell = Cell} = Elem,
					  GoodsTypeInfo = goods_util:get_goods_type(GoodsTypeId),
					  case is_record(GoodsTypeInfo, ets_base_goods) of
						  false ->
							  AccIn;
						  true ->
							  OtherData = GoodsTypeInfo#ets_base_goods.other_data,
							  [_Type, AddType, Effect] = util:string_to_term(tool:to_list(OtherData)),
							  Pearl = #p_ach_pearl{gid = Gid,
												   goods_id = GoodsTypeId,
												   cell = Cell,
												   add_type = AddType,
												   effect = Effect},
							  [Pearl|AccIn]
					  end
			  end, [], Pattern).
%% -----------------------------------------------------------------
%% 38000 总成就获取
%% -----------------------------------------------------------------
get_achieves(Player) ->
	lib_achieve:get_achieves(Player).

%% -----------------------------------------------------------------
%% 38001 获取最近完成成就
%% -----------------------------------------------------------------
get_achieve_log(PlayerId) ->
	lib_achieve:get_achieve_log(PlayerId).
					
	
%% -----------------------------------------------------------------
%% 38002 奇珍异宝 列表
%% -----------------------------------------------------------------
get_ach_treasure_list(PlayerId, Proto) ->
	case lib_achieve_inline:get_achieve_ets(PlayerId) of
		[] ->
			[];
		[Achieve] ->
			Treasure = Achieve#ets_achieve.ach_treasure,
			[_Ach|TreasELem] = Treasure,
			{StartNum, Len, TypeNum} = 
				case Proto of
					38002 ->
						{1, 28, 7};
					38014 ->
						{29, 8, 10}
				end,
			DataTreas = lists:sublist(TreasELem, StartNum, Len),
			lib_achieve_inline:make_ach_treausre_list(1, TypeNum, [], DataTreas)
	end.
		
%% -----------------------------------------------------------------
%% 38003 奇珍异宝  领取奖励
%% -----------------------------------------------------------------
get_ach_treasure(AchNum, Player) ->
	PlayerId = Player#player.id,
	case lib_achieve_inline:get_achieve_ets(PlayerId) of
		[] ->
			0;
		[Achieve] ->
			Treasure = Achieve#ets_achieve.ach_treasure,
			AType = AchNum div 100,
			SAType = AchNum rem 100,
			Nth = 
				case AType of
				7 ->
					SAType+1;
				10 ->
					SAType+29
				end,
			Check = lists:nth(Nth, Treasure),
			case Check =:= 1 of
				true ->%%可以领取
					{Type, GoodsId} = data_achieve:get_treasure_id(AType, SAType),
					case lib_achieve_inline:ach_give_goods(Type, GoodsId, 1, Player) of
						ok ->
							NewTreasure = tool:replace(Treasure, Nth, 2),
							ValueList = data_achieve:make_update_list([{AType,SAType,2}]),
							WhereList = [{pid,PlayerId}],
							db_agent:update_player_achieve(ach_treasure, ValueList,WhereList),
							NewAchieve = Achieve#ets_achieve{ach_treasure = NewTreasure},
							lib_achieve_inline:update_achieve_ets(NewAchieve),
							1;
						cell_num ->
							4;%%背包空间不足
						{_GoodsTypeId, not_found} ->
							5;%%物品不存在
						{_GoodsTypeId, goods_exist} ->
							2;%%已经领取过了
						_OtherError ->%%其他错误
							0
					end;
				false when Check =:= 2 ->
					2;%%已经领取过了
				false when Check =:= 0 ->
					3;%%还未能领取
				false ->
					0
			end
	end.

%% -----------------------------------------------------------------
%% 38004 八神珠 已装备
%% -----------------------------------------------------------------
get_ach_pearl_equiped(Status) ->
	gen_server:cast(Status#player.other#player_other.pid_goods, 
					{'GET_ACH_PEARL_EQUIPED',
					 1, Status#player.id, 
					 Status#player.other#player_other.pid_send}).

%% -----------------------------------------------------------------
%% 38005 八神珠 未装备
%% -----------------------------------------------------------------
get_ach_pearl_equipno(Status) ->
	gen_server:cast(Status#player.other#player_other.pid_goods, 
					{'GET_ACH_PEARL_EQUIPED',
					 0, Status#player.id, 
					 Status#player.other#player_other.pid_send}).

%% -----------------------------------------------------------------
%% 38006 八神珠  装备和卸载
%% -----------------------------------------------------------------
load_unload_pearl(GoodsId, Type, Status) ->
	#player{other = Other} = Status,
	#player_other{pid_goods = PidGoods} = Other,
	case Type =:= 0 orelse Type =:= 1 of
		true ->
			case catch(gen_server:call(PidGoods, {'LOAD_UNLOAD_PEARL', GoodsId, Type, Status})) of
				{ok, Result} ->
					Result;
				{fail, Error} ->
					{Status, Error}
			end;
		false ->
			{Status, {0, 0, 0}}
	end.
				
	
%% -----------------------------------------------------------------
%% 38007 通知某个成就完成
%% -----------------------------------------------------------------
inform_ach_finish(PidSend, AType, SATypeList) ->
	lists:foreach(fun(Elem) ->
						  AchNum = AType * 100 + Elem,
						  {ok, BinData38007} = pt_38:write(38007, [AchNum]),
						  lib_send:send_to_sid(PidSend, BinData38007)
				  end, SATypeList).

%% -----------------------------------------------------------------
%% 38008 人物属性面板称号列表获取
%% -----------------------------------------------------------------
get_ach_title(PlayerId, Titles) ->
	case show_got_achieve_titles(PlayerId) of
		[] ->
			{[],?COMMON_TITLES, ?SPECIAL_TITLES};
		PTitles ->
%% 			?DEBUG("PTitles:~p, Titles:~p", [PTitles, Titles]),
			Now = util:unixtime(),
			lists:foldl(fun(Elem, AccIn) ->
%% 								?DEBUG("Elem:~p", [Elem]),
								#p_title_elem{tid = Tid,
											  expi = Expi} = Elem,
								{AchTs, ComTs, SpecTs} = AccIn,
								if
									Tid > 100 andalso Tid < 700 ->%%成就称号
										{[{Tid, 0, Expi, 0}|AchTs], ComTs, SpecTs};
									Tid > 800 andalso Tid < 900 ->%%普通称号
										if
											Expi =:= 1 ->
												IsUse =
													case lists:member(Tid, Titles) of
														true ->
															1;
														false ->
															0
													end,
												NewComTs = lists:keyreplace(Tid, 1, SpecTs, {Tid, 0, 1, IsUse}),
												{AchTs, NewComTs, SpecTs};
											Expi =:= 0 ->
												case lists:keyfind(Tid, 1, ComTs) of
													false ->
														AccIn;
													{_FTid, FA, _FB, _IsFinish} ->
														IsUse =
															case lists:member(Tid, Titles) of
																true ->
																	1;
																false ->
																	0
															end,
														NewComTs = lists:keyreplace(Tid, 1, ComTs, {Tid, FA, 1, IsUse}),
														{AchTs, NewComTs, SpecTs}
												end;
											true ->%%应该是要跑这里代码的
												IsUse =
													case lists:member(Tid, Titles) of
														true ->
															1;
														false ->
															0
													end,
												RestTime = %%判断时间是否为0了
													case (Expi - Now) < 0 of
														true -> 
															0;
														false ->
															Expi - Now
													end,
												NewComTs = lists:keyreplace(Tid, 1, ComTs, {Tid, RestTime, 1, IsUse}),
												{AchTs, NewComTs, SpecTs}
										end;
									Tid > 900 andalso Tid < 1000 ->%%特殊称号
										if
											Expi =:= 1 ->
												IsUse =
													case lists:member(Tid, Titles) of
														true ->
															1;
														false ->
															0
													end,
												NewSpecTs = lists:keyreplace(Tid, 1, SpecTs, {Tid, 0, 2, IsUse}),
												{AchTs, ComTs, NewSpecTs};
											Expi =:= 0 ->
												case lists:keyfind(Tid, 1, SpecTs) of
													false ->
														AccIn;
													{_FTid,FA,_FB, _IsFinish} ->
														NewSpecTs = lists:keyreplace(Tid, 1, SpecTs, {Tid, FA, 2, 0}),
														{AchTs, ComTs, NewSpecTs}
												end;
											true ->
												IsUse =
													case lists:member(Tid, Titles) of
														true ->
															1;
														false ->
															0
													end,
												NewSpecTs = lists:keyreplace(Tid, 1, SpecTs, {Tid, 0, 2, IsUse}),
												{AchTs, ComTs, NewSpecTs}
										end;
									true ->
										AccIn
								end
						end, {[],?COMMON_TITLES, ?SPECIAL_TITLES}, PTitles)
	end.

%%获取玩家的称号		
show_got_achieve_titles(PlayerId) ->
	case lib_achieve_inline:get_achieve_ets(PlayerId) of
		[] ->
			[];
		[Achieve] ->
			Achieve#ets_achieve.ach_titles
%% 			case lib_achieve_inline:get_player_titles(PTitles) of
%% 				{no_update, NewTitles} ->
%% 					NewTitles;
%% 				{update_titles, NewTitles} ->
%% 					NewAchieve = Achieve#ets_achieve{ach_titles = NewTitles},
%% 					db_agent:update_player_other_titles(NewTitles, PlayerId),
%% 					lib_achieve_inline:update_achieve_ets(NewAchieve),
%% 					NewTitles
%% 			end
	end.

%%修改玩家的称号Id，(仅提供变性功能使用,玩家进程)
change_tieles_sex(PlayerId, NeedIds) ->
	%%检测是否已经加载过 成就系统的数据
	lib_achieve_inline:check_achieve_init(PlayerId),
	case lib_achieve_inline:get_achieve_ets(PlayerId) of
		[] ->
			[];
		[Achieve] ->
			PTitles = Achieve#ets_achieve.ach_titles,
%% 			case lib_achieve_inline:get_player_titles(PTitles) of
%% 				{no_update, NewTitles} ->
%% 					NewTitles;
%% 				{update_titles, NewTitles} ->
%% 					UpTitles = 
%% 			?DEBUG("~p, ~p", [NeedIds, PTitles]),
			{Result, NPTitles} = 
				lists:foldl(fun(Elem, AccIn) ->
									{CheckElem, ChangeElem} = Elem,	
									{_Type, GTitles} = AccIn,
%% 									?DEBUG("~p, ~p", [Elem, GTitles]),
									case lists:keyfind(CheckElem, #p_title_elem.tid, GTitles) of
										false ->
%% 											?DEBUG("2222222", []),
											AccIn;
										Tuple ->
%% 											?DEBUG("11111111", []),
											NewTuple = Tuple#p_title_elem{tid = ChangeElem},
											NGTitles = lists:keyreplace(CheckElem, #p_title_elem.tid, GTitles, NewTuple),
											{1, NGTitles}	
									end
							end, {0, PTitles}, NeedIds),
			case Result of
				0 ->
					skip;
				_ ->
					NewAchieve = Achieve#ets_achieve{ach_titles = NPTitles},
					db_agent:update_player_other_titles(NPTitles, PlayerId),
					lib_achieve_inline:update_achieve_ets(NewAchieve)
			end
	end.
			

%%领取魅力称号，return：NewPlayer
claim_love_title(TitleId, Player, ExpireTime) ->
	AchNum = data_achieve:get_love_id(TitleId),
	{_Result, NewPlayer} = lib_title:player_claim_ach_title(1, AchNum, ExpireTime, Player),
	NewPlayer.
	

%% -----------------------------------------------------------------
%% 38009 使用称号
%% -----------------------------------------------------------------
use_ach_title(Status, AchNum) ->
	#player{id = PlayerId} = Status,
	case lib_achieve_inline:get_achieve_ets(PlayerId) of
		[] ->
			{0, Status};
		[Achieve] ->
			AchTitles = Achieve#ets_achieve.ach_titles,
			case lists:keyfind(AchNum, #p_title_elem.tid, AchTitles) of
				false ->
					{2, Status};%%称号不存在
				TitleInfo ->
					Now = util:unixtime(),
					Time = TitleInfo#p_title_elem.expi,
					OTitles = Status#player.other#player_other.titles,
					case lists:member(AchNum, OTitles) of
						true ->
							{5, Status};
						false ->
							Titles =
								if 
									AchNum >= 101 andalso AchNum =< 700 ->
										[];
									true ->
										case lib_title:check_normal_t_use(OTitles) of
											{true, HUseTid} ->
												lists:delete(HUseTid, OTitles);
											false ->
												OTitles
										end
								end,
							case Time =:= 1 of
								true ->
									NTitles = [AchNum|Titles],
									NewStatus = Status#player{other = Status#player.other#player_other{titles = NTitles}},
									lib_love:bc_title_in_scene(NewStatus,NTitles),
									%%改数据库
									NTitlesStr = util:term_to_string(NTitles),
									ValueLists = [{ptitle, NTitlesStr}],
									WhereLists = [{pid, PlayerId}],
									db_agent:update_player_other(player_other, ValueLists, WhereLists),
									%%更新
									mod_player:save_online_diff(Status, NewStatus),
									{1, NewStatus};
								false when Time > Now ->
									NTitles = [AchNum|Titles],
									NewStatus = Status#player{other = Status#player.other#player_other{titles = NTitles}},
									lib_love:bc_title_in_scene(NewStatus,NTitles),
									%%改数据库
									NTitlesStr = util:term_to_string(NTitles),
									ValueLists = [{ptitle, NTitlesStr}],
									WhereLists = [{pid, PlayerId}],
									db_agent:update_player_other(player_other, ValueLists, WhereLists),
									%%更新
									mod_player:save_online_diff(Status, NewStatus),
									{1, NewStatus};
								false ->%%称号已过期
									update_palyer_title(AchNum, PlayerId),%%删除过期的称号
									{4, Status}
							end
					end
			end
	end.
							
	
%% -----------------------------------------------------------------
%% 38010 取消称号
%% -----------------------------------------------------------------
cancel_ach_title(Status, AchNum) ->
	#player{id = PlayerId,
			other = Other} = Status,
	#player_other{titles = Titles} = Other,
	case Titles =:= [] of
		true ->
			{3, Status};
		false ->
			NTitles = lists:delete(AchNum, Titles),
			NewStatus = Status#player{other = Status#player.other#player_other{titles = NTitles}},
			lib_love:bc_title_in_scene(NewStatus,NTitles),
			%%改数据库
			NIdsStr = util:term_to_string(NTitles),
			ValueLists = [{ptitle, NIdsStr}],
			WhereLists = [{pid, PlayerId}],
			db_agent:update_player_other(player_other, ValueLists, WhereLists),
			%%更新
			mod_player:save_online_diff(Status, NewStatus),
			{1, NewStatus}
	end.
%% -----------------------------------------------------------------
%% 38011 获取称号
%% -----------------------------------------------------------------
claim_ach_title(Status, AchNum) ->
	ExpireTime = data_achieve:get_achtitle_expi(AchNum),
	case AchNum > 800 andalso AchNum < 1000 of
		true ->
			case lib_title:player_claim_ach_title(0, AchNum, ExpireTime, Status) of
				{ok, NewStatus} ->
					{1, NewStatus};
				{Rest, _Status} ->
					{Rest, Status}
			end;
		false ->
			{3, Status}
	end.
		
%%玩家称号过期了,需要更新
update_palyer_title(Title, PlayerId) ->
	case lib_achieve_inline:get_achieve_ets(PlayerId) of
		[] ->
			skip;
		[Achieve] ->
			AchTitles = Achieve#ets_achieve.ach_titles,
			NewAchTitles = lists:keydelete(Title, #p_title_elem.tid, AchTitles),
			ValueLists = [{ptitles, util:term_to_string(NewAchTitles)}],
			WhereLists = [{pid, PlayerId}],
			db_agent:update_player_other(player_other, ValueLists, WhereLists),
			NewAchieve = Achieve#ets_achieve{ach_titles = NewAchTitles},
			lib_achieve_inline:update_achieve_ets(NewAchieve)
	end.


%%成就系统的物品装备判断,1:法宝判断，2:时装判断，3:套装判断
check_equip_ach(GoodsInfo, PlayerStatus, Type) ->
	lib_achieve_inline:check_equip_ach(GoodsInfo, PlayerStatus, Type).


%%对玩家的过去数据进行统计
check_player_old_date(Player, AchIeveUpdate) ->
	#player{id =PlayerId,
			lv = PLv,
			coin = Coin,
			bcoin = BCoin,
			honor = Honor,
			guild_id = GuildId,
			vip = VIP,
			other = PlayerOther} = Player,
	#player_other{pid = PlayerPid,
				  skill = Skill,
				  pid_send = PidSend} = PlayerOther,
	PCoin = BCoin + Coin,
	%%铜币判断
	if
		PCoin >= ?YG_COIN_TWO ->%%拥有100000000铜币	
			lib_achieve:check_achieve_finish_cast(PlayerPid, 406, [PCoin]);
		PCoin >= ?YG_COIN_ONE -> %%拥有1000000铜币
			lib_achieve:check_achieve_finish_cast(PlayerPid, 405, [PCoin]);
		true ->
			ok
	end,
	SkillLen = length(Skill),
	F = fun(Elem) ->
				{_SkillId, SLv} = Elem,
				SLv =/= 5
		end,
	SkillMax = lists:any(F, Skill),
	case SkillLen =:= 12 of
		true when SkillMax =:= false ->%%学了12个技能，并且全部满级
			lib_achieve:check_achieve_finish_cast(PlayerPid, 414, [1]);
		true ->%%仅学会了12个技能
			lib_achieve:check_achieve_finish_cast(PlayerPid, 413, [1]);
		false ->
			ok
	end,
	if
		SkillLen =/= 0 ->
			%%有学了技能的
			lib_achieve:check_achieve_finish_cast(PlayerPid, 423, [1]);
		true ->
			skip
	end,
	%%宠物判断
	pet_ach_check(PlayerId, PlayerPid),
	%%经脉判断
	case lib_meridian:get_player_meridian_info(PlayerId) of
		[] ->
			[];
		[Meri|_] ->
			MeriList = lib_achieve_inline:meri_to_list(Meri),
			%%{灵根达到70数量，灵根达到100数量，提升过灵根，8个经脉达到5级，8个经脉达到7级，8个经脉达到10级，8个经脉达到15级，修过灵根}
			{MerLg1, MerLg2, MerLg3, MerLv1, MerLv2, MerLv3, MerLv4, MerLv5} =
				lib_achieve_inline:lists_check_meri(MeriList),
			case MerLg1 >= 3 of%%三条灵根达到70
				true ->
					lib_achieve:check_achieve_finish_cast(PlayerPid, 415, [MerLg1]);
				false ->
					skip
			end,
			if
				MerLg2 >= 8 ->%%八条灵根达到100
					lib_achieve:check_achieve_finish_cast(PlayerPid, 418, [MerLg2]);
				MerLg2 >= 3 ->%%三条灵根达到100
					lib_achieve:check_achieve_finish_cast(PlayerPid, 417, [MerLg2]);
				MerLg2 >= 1 ->%%一条灵根达到100
					lib_achieve:check_achieve_finish_cast(PlayerPid, 416, [MerLg2]);
				true ->
					skip
			end,
			if%%提升过灵根
				MerLg3 =:= 1 ->
					lib_achieve:check_achieve_finish_cast(PlayerPid, 424, [1]);
				true ->
					[]
			end,
			if
				MerLv4 >= 8 ->
					lib_achieve:check_achieve_finish_cast(PlayerPid, 422, [15]);
				MerLv3 >= 8 ->
					lib_achieve:check_achieve_finish_cast(PlayerPid, 421, [10]);
				MerLv2 >= 8 ->
					lib_achieve:check_achieve_finish_cast(PlayerPid, 420, [7]);
				MerLv1 >= 8 ->
					lib_achieve:check_achieve_finish_cast(PlayerPid, 419, [5]);
				true ->
					[]
			end,
			if%%修过灵根
				MerLv5 =:= 1 ->
					lib_achieve:check_achieve_finish_cast(PlayerPid, 425, [1]);
				true ->
					[]
			end
		end,
		%%出师徒弟数量
	AppsNum = mod_master_apprentice:get_finish_apprenticeship_count(Player#player.id),
	if
		AppsNum >= 3 ->
			lib_achieve:check_achieve_finish_cast(PlayerPid, 603, [3]);
		AppsNum >= 2 ->
			lib_achieve:check_achieve_finish_cast(PlayerPid, 602, [2]);
		AppsNum >= 1 ->
			lib_achieve:check_achieve_finish_cast(PlayerPid, 601, [1]);
		true ->
			[]
	end,
	%%开垦农田块数判断
	FarmNum = lib_manor:get_reclaim_farm_num(PlayerId),
	case FarmNum >= 9 of
		true ->
			lib_achieve:check_achieve_finish_cast(PlayerPid, 623, [1]);
		false ->
			skip
	end,
	%%等级判断
	add_exp_check(PLv, PlayerPid),
	%%荣誉判断
	honor_ach_check(Honor, PlayerPid),
	%%鄙视崇拜判断
	bscb_ach_check(PlayerPid),
	%%VIP会员
	case VIP of
		0 ->
			[];
		6 ->%%体验卡
			[];
		_ ->
			lib_achieve:check_achieve_finish_cast(PlayerPid, 504, [1])
	end,
	%%神兵利器的任务检查
	SBLQCheck = [40103],
	[SBLQ] = db_agent:get_ach_olddata_count(task_log, [{task_id, "in", SBLQCheck}, {player_id, PlayerId}]),
	case SBLQ of
		0 ->
			skip;
		_ ->
			lib_achieve:check_achieve_finish_cast(PlayerPid, 202, [SBLQ])
	end,
	%%神器成就判断
	old_deputy_ach_check(PlayerPid, PlayerId),
	%%坐骑成就判断
	old_mount_ach_check(PlayerPid, PlayerId),
	%%婚宴成就判断
	case Player#player.couple_name =/= "" of
		true ->
			lib_achieve:check_achieve_finish_cast(PlayerPid, 632, [1]);
		false ->
			skip
	end,
	%%此处进行仅仅一次的操作
	case AchIeveUpdate of
		1 ->
			skip;
		0 ->
			%%新手任务
			case PLv >= 10 of
				true ->
					lib_achieve:check_achieve_finish(PidSend, PlayerId, 101, [1]);
				false ->
					[]
			end,
			%%任务成就判断
			check_task_old_data(PidSend, PlayerId),
			%%诛邪判断
			lib_achieve_inline:box_achieve_check(PidSend, PlayerId),
			%%加入氏族
			case GuildId =/= 0 of
				true ->
					lib_achieve:check_achieve_finish(PidSend, PlayerId, 604, [1]);
				false ->
					[]
			end,
			%%氏族成就
			GDonate = lib_guild:get_member_donate(Player#player.guild_id, Player#player.id),
			if
				GDonate >= ?INTERACT_GUILD_DONATE ->
					lib_achieve:check_achieve_finish(PidSend, PlayerId, 605, [GDonate]);
				true ->
					[]
			end,
			%%好友判断
			Friend = lib_relationship:get_idA_list(PlayerId, 1),
			FLen = length(Friend),
			if
				FLen >= 30 ->
					lib_achieve:check_achieve_finish(PidSend, PlayerId, 608, [30]);
				FLen >= 20 ->
					lib_achieve:check_achieve_finish(PidSend, PlayerId, 607, [20]);
				FLen >= 5 ->
					lib_achieve:check_achieve_finish(PidSend, PlayerId, 606, [5]);
				true ->
					[]
			end
	end.
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%	成就测试专用(稳定后删除)	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 	if
%% 		PlayerId =:= 31177 ->%%大灰狼的专号
%% 			io:format("FLen:~p,  TaskOne: ~p,  PLvUpList: ~p,  CoinUpList: ~p,  CultUpList: ~p,  HonorUpList: ~p,  SkillUpList: ~p,  FrenUpList: ~p,  GuildUpList: ~p,  VIPCheck: ~p,  Apps: ~p,  Ten: ~p,  GDCheck: ~p,  UpdateList:~p \n", 
%% 					  [FLen, NewComer, One, Two, Three, Four, Five, Six, Seven, Eight, Nine, Ten, MUpList,UpdateList]);
%% 		true ->
%% 			skip
%% 	end,
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%	成就测试专用(稳定后删除)	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%
%% Local Functions
%%
%%做任务数据的历史统计
check_task_old_data(PidSend, PlayerId) ->
	RCKillMon = [61006, 61021, 61023, 61025, 61031, 61032, 61033, 61034, 61035],	%%日常打怪												
	GuildTask = [60100, 61011, 61017, 61018],												%%氏族任务	
	FBTask = [61002, 61010, 61015, 61016],												%%副本任务
	CultureTask = [61004, 61019, 61020],													%%修为任务
	YBTask = [61008, 61012, 61013, 61014],							%%运镖任务						
	CarryTask = [81000, 81001, 81002, 81003],								%%跑商任务			
	FSTTask = [83100, 83101, 83102, 83103, 83110, 83111, 83112, 83113, 83120, 83121, 83122, 83123],%%封神贴任务												
	CycleTask = [70100, 70103, 70106, 83124, 83125, 83126, 83127, 83128],	%%循环任务
	SBLQCheck = [40103],%%神兵利器的任务检查
	RC = db_agent:get_ach_olddata_count(task_log, [{task_id, "in", RCKillMon}, {player_id, PlayerId}]),
	GT = db_agent:get_ach_olddata_count(task_log, [{task_id, "in", GuildTask}, {player_id, PlayerId}]),
	FB = db_agent:get_ach_olddata_count(task_log, [{task_id, "in", FBTask}, {player_id, PlayerId}]),
	Cul = db_agent:get_ach_olddata_count(task_log, [{task_id, "in", CultureTask}, {player_id, PlayerId}]),
	YB = db_agent:get_ach_olddata_count(task_log, [{task_id, "in", YBTask}, {player_id, PlayerId}]),
	Carry = db_agent:get_ach_olddata_count(task_log, [{task_id, "in", CarryTask}, {player_id, PlayerId}]),
	FST = db_agent:get_ach_olddata_count(task_log, [{task_id, "in", FSTTask}, {player_id, PlayerId}]),
	Cycle = db_agent:get_ach_olddata_count(task_log, [{task_id, "in", CycleTask}, {player_id, PlayerId}]),
	[SBLQ] = db_agent:get_ach_olddata_count(task_log, [{task_id, "in", SBLQCheck}, {player_id, PlayerId}]),
	
	lib_achieve:check_achieve_finish(PidSend, PlayerId, 102, RC),
	lib_achieve:check_achieve_finish(PidSend, PlayerId, 104, GT),
	lib_achieve:check_achieve_finish(PidSend, PlayerId, 107, FB),
	lib_achieve:check_achieve_finish(PidSend, PlayerId, 110, Cul),
	lib_achieve:check_achieve_finish(PidSend, PlayerId, 112, YB),
	lib_achieve:check_achieve_finish(PidSend, PlayerId, 114, Carry),
	lib_achieve:check_achieve_finish(PidSend, PlayerId, 116, FST),
	lib_achieve:check_achieve_finish(PidSend, PlayerId, 118, Cycle),
	%%神兵利器的任务检查
	case SBLQ of
		0 ->
			skip;
		_ ->
			lib_achieve:check_achieve_finish(PidSend, PlayerId, 202, [SBLQ])
	end.

%%做物品使用的成就统计
check_ach_goods_use(Player, Res, GoodsTypeId) ->
	case Res of
		1 ->
			#player{id = PlayerId,
					other = Other} = Player,
			#player_other{pid_send = PidSend} = Other,
			VIP = lists:member(GoodsTypeId, [28600, 28601, 28602, 28603,28604]),%%VIP卡
%% 			?DEBUG("VIP:~p,~p", [GoodsTypeId, VIP]),
			if
				VIP =:= true ->
					lib_achieve:check_achieve_finish(PidSend, PlayerId, 504, [1]);
				true ->
					skip
			end;
		_ ->
			skip
	end.
	

update_player_statistics(PlayerId) ->
%% 	?DEBUG("update_player_statistics", []),
	case ets:lookup(?ACHIEVE_STATISTICS, PlayerId) of
		[] ->
			skip;
		[Achieve] ->
			#ets_ach_stats{trc=Trc,tg=Tg,tfb=Tfb,tcul=Tcul,tca=Tca,
						   tbus=Tbus,tfst=Tfst,tcyc=Tcyc,trm=TRm,
						   trb=TRb,
						   trbc=TRbc,
						   trbus=TRbus,
						   trfst=TRfst,
						   trar=TRar,trf=TRf,
						   trstd=TRstd,
						   trmtd=TRmtd,
						   trfbb=TRfbb,
						   trsixfb = TRsixfb,
						   trzxt = TRzxt,
						   trsm = TRsm, 
						   trtrain = TRtrain,    
						   trjl = Trjl,      
						   trds = Trds,   
						   trgg = Trgg, 
						   fsb=FSb,
						   fssh=FSsh,
						   fsc=FSc,
						   fssa=FSsa,
						   fslg=FSlg,
						   infl = INfl,inlv=INlv,inlved=INlved,
						   ygcul = YgCul,
						   infai=INfai,infao=INfao} = Achieve,
			TRbStr = util:term_to_string(TRb),
			TRbcStr = util:term_to_string(TRbc),
			TRfstStr = util:term_to_string(TRfst),
			TRstdStr = util:term_to_string(TRstd),
			TRmtdStr = util:term_to_string(TRmtd),
			TRfbbStr = util:term_to_string(TRfbb),
			TRxixfbStr = util:term_to_string(TRsixfb),
			TRzxtStr = util:term_to_string(TRzxt),
			FSbStr = util:term_to_string(FSb),
			FScStr = util:term_to_string(FSc),
			FSsaStr = util:term_to_string(FSsa),
			FieldsList = 
				[{trc, Trc}, {tg, Tg}, {tfb, Tfb}, {tcul, Tcul}, {tca, Tca}, {tbus, Tbus},
				 {tfst, Tfst}, {tcyc, Tcyc}, {trm, TRm}, {trb, TRbStr}, {trbc, TRbcStr}, {trbus, TRbus}, 
				 {trfst, TRfstStr}, {trar, TRar}, {trf, TRf}, {trstd, TRstdStr}, {trmtd, TRmtdStr}, 
				 {trfbb, TRfbbStr}, {trsixfb, TRxixfbStr}, {trzxt, TRzxtStr}, {trsm, TRsm},
				 {trtrain, TRtrain},{trjl, Trjl},{trds, Trds},{trgg, Trgg},{fsb, FSbStr}, {fssh, FSsh}, 
				 {fsc, FScStr}, {fssa, FSsaStr}, {fslg, FSlg}, {infl, INfl}, {inlv, INlv}, 
				 {inlved, INlved}, {infai, INfai}, {infao, INfao}, {ygcul, YgCul}],
			WhereList = [{pid, PlayerId}],
			db_agent:update_ach_stats(achieve_statistics, FieldsList, WhereList)
	end,
	case lib_achieve_inline:get_achieve_ets(PlayerId) of
		[] ->
%% 			?DEBUG("OMG can not find the ets:~p", [PlayerId]),
			skip;
		[AchieveEts] ->%%更新奇珍异宝的数据
			ETreasure = AchieveEts#ets_achieve.ach_treasure,
			#ets_achieve{ach_treasure = ETreasure,
						 ach_titles = ETitles} = AchieveEts,
			%%更新player_other表
			db_agent:update_player_other_titles(ETitles, PlayerId),
%% 			?DEBUG("ETreasure:~p,ETitles:~p", [ETreasure, length(ETitles)]),
			[_EPid|EFeilds] = ?ACH_TREASURE_FIELDS,
			Len1 = length(ETreasure),
			Len2 = length(EFeilds),
			case Len1 =:= Len2 of
				true ->
					ValueListEts = make_treasure_uplist(ETreasure, EFeilds, []),
					WhereListEts = [{pid, PlayerId}],
					db_agent:update_player_achieve(ach_treasure, ValueListEts, WhereListEts);
				false ->
					skip
			end
	end.
make_treasure_uplist([], [], Result) ->
	Result;
make_treasure_uplist([Trea|Treasure], [Elem|Feilds], Result) ->
	List = [{Elem, Trea}|Result],
	make_treasure_uplist(Treasure, Feilds, List).
			
	
%%升级的成就判断
add_exp_check(Level, PlayerPid) ->
	if
		Level >= 70 ->%%等级达到70级
			lib_achieve:check_achieve_finish_cast(PlayerPid, 404, [70]);
		Level >= 60 ->%%等级达到60级
			lib_achieve:check_achieve_finish_cast(PlayerPid, 403, [60]);
		Level >= 50 ->%%等级达到50级
			lib_achieve:check_achieve_finish_cast(PlayerPid, 402, [50]);
		Level >= 40 ->%%等级达到40级
			lib_achieve:check_achieve_finish_cast(PlayerPid, 401, [40]);
		true ->
			skip
	end.
pet_ach_check(PlayerId, PlayerPid) ->
	%%宠物判断
	Pets = lib_pet:get_all_pet(PlayerId),
	case Pets of
		[] ->
			skip;
		_ ->%%有灵兽了
			lib_achieve:check_achieve_finish_cast(PlayerPid, 528, [1])
	end,
	lists:foldl(fun(Elem, AccIn) ->
						[EA,EB,EC,ED,EE,EF,EG,EH,EI,ES1,ES2] = AccIn,
						#ets_pet{level = Lv,
								 aptitude = ApTi,
								 grow = Grow,
								 chenge = Chenge} = Elem,
						{NA,NB,NC} = 
							if
								Lv >= 25 andalso EC =:= 0 ->
									lib_achieve:check_achieve_finish_cast(PlayerPid, 514, [25]),
									{1,1,1};
								Lv >= 10 andalso EB =:= 0 ->
									lib_achieve:check_achieve_finish_cast(PlayerPid, 513, [10]),
									{1,1,EC};
								Lv >= 5 andalso EA =:= 0 ->
									lib_achieve:check_achieve_finish_cast(PlayerPid, 512, [5]),
									{1,EB,EC};
								true ->
									{EA,EB,EC}
							end,
						{ND,NE} =
							if
								ApTi >= 55 andalso EE =:= 0 ->
									lib_achieve:check_achieve_finish_cast(PlayerPid, 516, [55]),
									{1,1};
								ApTi >= 30 andalso ED =:= 0 ->
									lib_achieve:check_achieve_finish_cast(PlayerPid, 515, [30]),
									{1,EE};
								true ->
									{ED,EE}
							end,
						{NF,NG,NH} = 
							if
								Grow >= 60 andalso EH =:= 0 ->
									lib_achieve:check_achieve_finish_cast(PlayerPid, 519, [60]),
									{1,1,1};
								Grow >= 50 andalso EG =:= 0 ->
									lib_achieve:check_achieve_finish_cast(PlayerPid, 518, [50]),
									{1,1,EH};
								Grow >= 40 andalso EF =:= 0 ->
									lib_achieve:check_achieve_finish_cast(PlayerPid, 517, [40]),
									{1,EG,EH};
								true ->
									{EF,EG,EH}
							end,
						NI =
							if
								Chenge =/= 0 andalso EI =:= 0 ->
									lib_achieve:check_achieve_finish_cast(PlayerPid, 520, [1]),
									1;
								true ->
									EI
							end,
						ENum = lib_pet:get_count_step_skill(Elem,5),
						if
							ENum >= 5 ->
								lib_achieve:check_achieve_finish_cast(PlayerPid, 530, [ENum]),
								NS1 = 1,
								NS2 = 2;
							ENum >= 1 ->
								lib_achieve:check_achieve_finish_cast(PlayerPid, 529, [ENum]),
								NS1 = 1,
								NS2 = ES2;
							true ->
								NS1 = ES1,
								NS2 = ES2
						end,
						[NA,NB,NC,ND,NE,NF,NG,NH,NI,NS1,NS2]
				end, [0,0,0,0,0,0,0,0,0,0,0], Pets).

%%荣誉判断
honor_ach_check(Honor, PlayerPid) ->
	if
		Honor >= ?YG_HONOR_THREE -> %%封神台荣誉达到200000
			lib_achieve:check_achieve_finish_cast(PlayerPid, 412, [Honor]);
		Honor >= ?YG_HONOR_TWO -> %%封神台荣誉达到100000
			lib_achieve:check_achieve_finish_cast(PlayerPid, 411, [Honor]);
		Honor >= ?YG_HONOR_ONE -> %%封神台荣誉达到10000
			lib_achieve:check_achieve_finish_cast(PlayerPid, 410, [Honor]);
		true ->
			ok
	end.

%%清除指定玩家Id的成就数据
delete_player_ach_info(PlayerId) ->
	db_agent:delete_player_ach_info(PlayerId).


repair_add_title(Append, _Num, []) ->
	Append;
repair_add_title(Append, Num, [Elem|Rest]) ->
	case Elem =/= 0 of
		true ->
			NewTitle = #p_title_elem{tid = Num,
									 expi = 1},
			NewAppend = [NewTitle|Append];
		false ->
			NewAppend = Append
	end,
	repair_add_title(NewAppend, Num+1, Rest).

repair_player_titles() ->
	Now = util:unixtime(),
	LastTime = Now - 604800,
	Pids = db_agent:repair_get_achs_need(LastTime),
%% 	?DEBUG("PIDS :~p,,,,~p", [LastTime, Pids]),
	lists:foreach(fun([PlayerId]) ->
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
						  EtsAT = %%任务
							  case AchTask =:= [] of
								  true ->
									  [];
								  false ->
									  [_TId,_TPid|EtsAchTask] = AchTask,
									  repair_add_title([], 101, EtsAchTask)
							  end,
						  EtsAE = %%神装成就
							  case AchEpic =:= [] of
								  true ->
									  EtsAT;
								  false ->
									  [_EId,_EPid|EtsAchEpic] = AchEpic,
									  repair_add_title(EtsAT, 201, EtsAchEpic)
							  end,
						  EtsATr = %%试炼成就
							  case AchTrials =:= [] of
								  true ->
									  EtsAE;
								  false ->
									  [_TRId,_TRPid|EtsAchTrials] = AchTrials,
									 repair_add_title(EtsAE, 301, EtsAchTrials)
							  end,
						  EtsAYg = %%远古成就
							  case AchYg =:= [] of
								  true ->
									  EtsATr;
								  false ->
									  [_YGId,_YGPid|EtsAchYg] = AchYg,
									   repair_add_title(EtsATr, 401, EtsAchYg)
							  end,
						  EtsAFs = %%封神成就
							  case AchFs =:= [] of
								  true ->
									  EtsAYg;
								  false ->
									  [_FSId,_FSPid|EtsAchFs] = AchFs,
									  repair_add_title(EtsAYg, 501, EtsAchFs)
							  end,
						  EtsAIn = %%互动成就
							  case AchInteract =:= [] of
								  true ->
									  EtsAFs;
								  false ->
									  [_INId,_INPid|EtsAchInteract] = AchInteract,
									  repair_add_title(EtsAFs, 601, EtsAchInteract)
							  end,
						  TitlesStr = util:term_to_string(EtsAIn),
						  Values = [{ptitles, TitlesStr}, {ptitle, 0}],
						  Where = [{pid, PlayerId}],
						  db_agent:update_player_other(player_other, Values, Where)
				  end, Pids).

%%鄙视和崇拜的成就判断(系统本身自己去做)
bscb_ach_check(PlayerPid) ->
	%%获取鄙视和崇拜数据
	BS = lib_achieve_inline:get_player_bscb_dict(player_bs),
	CB = lib_achieve_inline:get_player_bscb_dict(player_cb),
%%	?DEBUG("BS:~p,CB:~p", [BS,CB]),
	lib_achieve:check_achieve_finish_cast(PlayerPid, 630, [CB]),
	lib_achieve:check_achieve_finish_cast(PlayerPid, 628, [BS]).
	
%%鄙视和崇拜的成就判断(触发判断)
player_adore(BSCB, PlayerId, Type) ->
	[BS,CB] = BSCB,
	case Type of
		2 ->%%被崇拜
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerId, 630, [CB]))end);
		_ ->
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerId, 628, [BS]))end)
	end.
%%神器成就判断
old_deputy_ach_check(PlayerPid, PlayerId) ->
	Pattern = #ets_deputy_equip{pid = PlayerId, _='_'},
	DeputyInfo = goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern),
	case is_record(DeputyInfo,ets_deputy_equip) of
		true ->
			deputy_ach_check(PlayerPid, DeputyInfo#ets_deputy_equip.prof_lv, DeputyInfo#ets_deputy_equip.color);
		false ->
			skip
	end.
deputy_ach_check(PlayerPid, Step, Color) ->
	%%神器阶数判断
	if
		Step >= 7 ->%%神器达到7阶
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerPid, 534, [Step]))end);
		Step >= 5 ->%%神器达到5阶
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerPid, 533, [Step]))end);
		Step >= 3 ->%%神器达到3阶
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerPid, 532, [Step]))end);
		true ->
			skip
	end,
	if
		Color =:= 4 ->%%神器品质进阶为紫色
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerPid, 537, [Color]))end);
		Color =:= 3 ->%%神器品质进阶为金色
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerPid, 536, [Color]))end);
		Color =:= 2 ->%%神器品质进阶为蓝色
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerPid, 535, [Color]))end);
		true ->
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerPid, 531, [1]))end)
	end.

%%坐骑成就判断
old_mount_ach_check(PlayerPid, PlayerId) ->
	Mounts = lib_mount:get_all_mount(PlayerId),
	lists:foreach(fun(Elem) ->
						  mount_ach_check(PlayerPid, Elem, 0)
				  end, Mounts),
	ActMount = lib_mount:get_all_type(PlayerId),
	Len = length(ActMount),
	case Len >= 17 of
		true ->
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerPid, 550, [Len]))end);
		false ->
			skip
	end.


mount_ach_check(PlayerPid, Mount, Type) ->
	#ets_mount{step = Step,
			   stren = Stren} = Mount,
	if%%坐骑阶数
		Step >= 10 ->
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerPid, 547, [Step]))end);
		Step >= 9 ->
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerPid, 546, [Step]))end);
		Step >= 8 ->
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerPid, 545, [Step]))end);
		Step >= 7 ->
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerPid, 544, [Step]))end);
		Step >= 6 ->
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerPid, 543, [Step]))end);
		Step >= 5 ->
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerPid, 542, [Step]))end);
		Step >= 4 ->
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerPid, 541, [Step]))end);
		Step >= 3 ->
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerPid, 540, [Step]))end);
		Type =:= 1 ->
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerPid, 539, [Step]))end);
		true ->
			skip
	end,
	if%%坐骑强化
		Stren >= 10 ->
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerPid, 549, [Step]))end);
		Stren >= 7 ->
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerPid, 548, [Step]))end);
		true ->
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerPid, 538, [Step]))end)
	end.
		
%%坐骑强化
mount_stren_check(NewStrengthen, PlayerPid) ->
	if
		NewStrengthen >= 10 ->
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerPid, 549, [NewStrengthen]))end);
		NewStrengthen >= 7 ->
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerPid, 548, [NewStrengthen]))end);
		true ->
			skip
	end.
			