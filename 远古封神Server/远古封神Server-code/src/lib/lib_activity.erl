%% Author: xianrongMai
%% Created: 2011-8-17
%% Description: 处理玩家活跃度的方法
-module(lib_activity).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include("activity.hrl").
-include("guild_info.hrl").

%%
%% Exported Functions
%%
-export([
		 check_player_activity_task/2,		%% 活跃度任务检查
		 check_player_activity/2,			%% 检查玩家的某个活跃度的数据状况(需在玩家进程下用，否则没效)
		 player_logout/1,					%%玩家下线，活跃度数据更新
		 update_activity_data_cast/3,		%%对外提供的更新玩家活跃度数据接口(cast方式)
		 update_activity_data/4,			%%对外提供的更新玩家活跃度数据接口
		 get_active_goods/2,				%% 38013 活跃度领取奖品
		 make_activity_return/1,			%%处理玩家的活跃度物品领取情况
		 check_load_activity/1,				%% 38012 获取活跃度
		 load_player_activity/2				%%初始化玩家的活跃度数据
		]).

%%
%% API Functions
%%
%%对外提供的更新玩家活跃度数据接口
update_activity_data_cast(AtomType, Pid, Param) ->
	case is_pid(Pid) =:= true of
		true ->
			gen_server:cast(Pid, {'UPDATE_ACITVITY_DATA', AtomType, Param});
		false ->
			skip
	end.

update_activity_data(AtomType, Pid, PlayerId, Param) ->
	update_player_activity(AtomType, Pid, PlayerId, Param).

%% -----------------------------------------------------------------
%% 38012 获取活跃度
%% -----------------------------------------------------------------
%%检查是否初始化了活跃度数据，并且返回 	{活跃值，活跃数据，领取的物品情况}
check_load_activity(PlayerId) ->
	NowTime = util:unixtime(),
	case get_player_actions(PlayerId) of
		[] ->
			Activities = load_player_activity(PlayerId, NowTime),
			#player_activity{act = Act,
							 actions = Actions,
							 goods = Goods} = Activities,
			{Act, Actions, Goods};
		[Activity] ->
			#player_activity{act = Act,
							 retime = ReTime,
							 actions = Actions,
							 goods = Goods} = Activity,
			case util:is_same_date(NowTime, ReTime) of
				true ->%%是同一天
					{Act, Actions, Goods};
				false ->
					NewAct = 0,
					%%活跃度数据
					NewActions = ?PLAYER_BASE_ACTIONS,
					NewActionsStr = util:term_to_string(NewActions),
					%%物品领取情况
					NewGoods = ?ACTIVITY_GOODS,
					NewGoodsStr = util:term_to_string(NewGoods),
					Activities = 
						Activity#player_activity{act = NewAct,
												 retime = NowTime,
												 actions = NewActions,
												 goods = NewGoods},
					update_player_actions(Activities),
					WhereList = [{pid, PlayerId}],
					ValueList = [{act, NewAct}, {retime, NowTime}, {actions, NewActionsStr}, {goods, NewGoodsStr}],
					db_agent:update_player_activity(player_activity,ValueList, WhereList),
					{NewAct, NewActions, NewGoods}
			end
	end.
			
		
%%初始化玩家的活跃度数据
load_player_activity(PlayerId, NowTime) ->
	case db_agent:get_player_activity(PlayerId) of
		[] ->  
			%%活跃度数据
			Actions = ?PLAYER_BASE_ACTIONS,
			ActionsStr = util:term_to_string(Actions),
			%%物品领取情况
			Goods = ?ACTIVITY_GOODS,
			GoodsStr = util:term_to_string(Goods),
			%%活跃值
			Act = 0,
			db_agent:inset_player_activity(PlayerId, NowTime, Act, ActionsStr, GoodsStr),
			Activities = #player_activity{pid = PlayerId,
										  act = Act,
										  retime = NowTime,
										  actions = Actions,
										  goods = Goods},
			update_player_actions(Activities);
		[Act, ReTime, ActionsStr, GoodsStr] ->
			case util:is_same_date(NowTime, ReTime) of
				true ->%%是同一天
					Actions = util:string_to_term(tool:to_list(ActionsStr)),
					Goods = util:string_to_term(tool:to_list(GoodsStr)),
					Activities = #player_activity{pid = PlayerId,
												  act = Act,
												  retime = NowTime,
												  actions = Actions,
												  goods = Goods},
					%%更新ets
					update_player_actions(Activities),
					%%改数据库时间
					WhereList = [{pid, PlayerId}],
					ValueList = [{retime, NowTime}],
					db_agent:update_player_activity(player_activity,ValueList, WhereList);
				false ->%%已经不是同一天了，算时间
					%%活跃度数据
					Actions = ?PLAYER_BASE_ACTIONS,
					NewActionsStr = util:term_to_string(Actions),
					%%物品领取情况
					Goods = ?ACTIVITY_GOODS,
					NewGoodsStr = util:term_to_string(Goods),
					%%活跃值
					NewAct = 0,
					Activities = #player_activity{pid = PlayerId,
												  act = NewAct,
												  retime = NowTime,
												  actions = Actions,
												  goods = Goods},
					update_player_actions(Activities),
					WhereList = [{pid, PlayerId}],
					ValueList = [{act, NewAct}, {retime, NowTime}, {actions, NewActionsStr}, {goods, NewGoodsStr}],
					db_agent:update_player_activity(player_activity,ValueList, WhereList)
			end
	end,
	Activities.
	
syn_load_player_activity(PlayerId, Pid, NowTime, TypeAtom, Param) ->
	case db_agent:get_player_activity(PlayerId) of
		[] -> 
			%%活跃值
			Act = 0,
			%%活跃度数据
			Actions = ?PLAYER_BASE_ACTIONS,
			{NewAct, NewActions} = get_new_activity(TypeAtom, Act, Actions, Param, NowTime, PlayerId),
			ActionsStr = util:term_to_string(NewActions),
			%%物品领取情况
			Goods = ?ACTIVITY_GOODS,
			GoodsStr = util:term_to_string(Goods),
			db_agent:inset_player_activity(PlayerId, NowTime, NewAct, ActionsStr, GoodsStr),
			Activities = #player_activity{pid = PlayerId,
										  act = NewAct,
										  retime = NowTime,
										  actions = NewActions,
										  goods = Goods},
			update_player_actions(Activities);
		[Act, ReTime, ActionsStr, GoodsStr] ->
			case util:is_same_date(NowTime, ReTime) of
				true ->%%是同一天
					Actions = util:string_to_term(tool:to_list(ActionsStr)),
					{NewAct, NewActions} = get_new_activity(TypeAtom, Act, Actions, Param, NowTime, PlayerId),
					%% --------- %%
					%% 活动：任务达人，赢希望之种			
					lib_act_interf:latern_activity_award(Act, NewAct, PlayerId),
					%% --------- %%
					case NewAct >= ?TASK_12 of
						true ->
							%%氏族祝福任务判断
							GWParam = {12, 100},
							lib_gwish_interface:check_player_gwish(Pid, GWParam);
						false ->
							skip
					end,
					NewActionsStr = util:term_to_string(NewActions),
					Goods = util:string_to_term(tool:to_list(GoodsStr)),
					Activities = #player_activity{pid = PlayerId,
												  act = NewAct,
												  retime = NowTime,
												  actions = NewActions,
												  goods = Goods},
					%%更新ets
					update_player_actions(Activities),
					%%改数据库时间
					WhereList = [{pid, PlayerId}],
					ValueList = [{retime, NowTime}, {act, NewAct}, {actions, NewActionsStr}],
					db_agent:update_player_activity(player_activity,ValueList, WhereList);
				false ->%%已经不是同一天了，算时间
					%%活跃值
					NewAct0 = 0,
					%%活跃度数据
					Actions = ?PLAYER_BASE_ACTIONS,
					{NewAct, NewActions} = get_new_activity(TypeAtom, NewAct0, Actions, Param, NowTime, PlayerId),
					NewActionsStr = util:term_to_string(NewActions),
					%%物品领取情况
					Goods = ?ACTIVITY_GOODS,
					NewGoodsStr = util:term_to_string(Goods),
					Activities = #player_activity{pid = PlayerId,
												  act = NewAct,
												  retime = NowTime,
												  actions = NewActions,
												  goods = Goods},
					update_player_actions(Activities),
					WhereList = [{pid, PlayerId}],
					ValueList = [{act, NewAct}, {retime, NowTime}, {actions, NewActionsStr}, {goods, NewGoodsStr}],
					db_agent:update_player_activity(player_activity,ValueList, WhereList)
			end
	end.
	
	
%%更新玩家的活跃度数据
update_player_activity(TypeAtom, Pid, PlayerId, Param) ->
	NowTime = util:unixtime(),
	case get_player_actions(PlayerId) of
		[] ->
			syn_load_player_activity(PlayerId, Pid, NowTime, TypeAtom, Param);
		[Activity] ->
			#player_activity{act = Act,
							 retime = ReTime,
							 actions = Actions,
							 goods = Goods} = Activity,
			{NewAct, NewActions} =
				case util:is_same_date(NowTime, ReTime) of
					true ->
						NewGoods = Goods,
						get_new_activity(TypeAtom, Act, Actions, Param, NowTime, PlayerId);
					false ->
						NewGoods = ?ACTIVITY_GOODS,
						get_new_activity(TypeAtom, 0, ?PLAYER_BASE_ACTIONS, Param, NowTime, PlayerId)
				end,
			%% --------- %%
			%% 活动：任务达人，赢希望之种		
			lib_act_interf:latern_activity_award(Act, NewAct, PlayerId),
			%% --------- %%
			case NewAct >= ?TASK_12 of
				true ->
					%%点名卡任务中活跃度超过100
					gen_server:cast(Pid, {'ACTIVITY_TASK_FINISH', online_100}),
					%%氏族祝福任务判断
					GWParam = {12, 100},
					lib_gwish_interface:check_player_gwish(Pid, GWParam);
				false ->
					skip
			end,
			Online = lists:nth(12, NewActions),
			case Online >= 180 of
				true ->%%点名卡活动任务在线时间超过3小时
					gen_server:cast(Pid, {'ACTIVITY_TASK_FINISH', online});
				false ->
					skip
			end,
			NewActivity = Activity#player_activity{act = NewAct,
												   retime = NowTime,
												   actions = NewActions,
												   goods = NewGoods},
			%%更新ets
			update_player_actions(NewActivity),
			%%改数据库数据
			ActionsStr = util:term_to_string(NewActions),
			NewGoodsStr = util:term_to_string(NewGoods),
			WhereList = [{pid, PlayerId}],
			ValueList = [{act, NewAct}, {retime, NowTime}, {actions, ActionsStr}, {goods, NewGoodsStr}],
			db_agent:update_player_activity(player_activity,ValueList, WhereList)
	end.
					
	
%% -----------------------------------------------------------------
%% 38013 活跃度领取奖品
%% -----------------------------------------------------------------
get_active_goods(Status, Num) ->
	{GoodsId, ActNeed} = get_goods_id_and_actneed(Num),
	NowTime = util:unixtime(),
	PlayerId = Status#player.id,
	case get_player_actions(PlayerId) of
		[] ->
			0;
		[Activity] ->
			#player_activity{act = Act,
							 retime = ReTime,
							 goods = Goods} = Activity,
				case util:is_same_date(NowTime, ReTime) of
					true ->%%可以试试领取
%% 						?DEBUG("true : NowTime, ReTime ~p,~p",[NowTime, ReTime]),
						GotOrNot = lists:nth(Num, Goods),%%查看是否已经领取了
						case GotOrNot of
							1 ->%%OMG,居然领取了TAT
								3;
							0 ->%%可以领取喔，哇咔咔
								if
									ActNeed > Act ->%%哎，还是不能领取
										2;
									true ->
										case catch (gen_server:call(Status#player.other#player_other.pid_goods, 
																	{'give_goods', Status, GoodsId, 1, 2})) of
											ok ->%%领取成功
												NewGoods = tool:replace(Goods, Num, 1),
												NewActivity = 
													Activity#player_activity{goods = NewGoods},
												%%更新ets
												update_player_actions(NewActivity),
												%%改数据库数据
												NewGoodsStr = util:term_to_string(NewGoods),
												WhereList = [{pid, PlayerId}],
												ValueList = [{goods, NewGoodsStr}],
												db_agent:update_player_activity(player_activity,ValueList, WhereList),
												1;
											cell_num ->%%背包空间不足
												5;
											{_GoodsTypeId, not_found} ->
												6;
											_OtherError ->
												0
										end
								end
						end;
					false ->%%过期了，需要客户端重新请求一下活跃度数据
%% 						?DEBUG("old the day: NowTime, ReTime ~p,~p",[NowTime, ReTime]),
						NewGoods = ?ACTIVITY_GOODS,
						NewActions = ?PLAYER_BASE_ACTIONS,
						NewAct = 0,
						NewActivity = 
							Activity#player_activity{act = NewAct,
													 retime = NowTime,
													 actions = NewActions,
													 goods = NewGoods},
						%%更新ets
						update_player_actions(NewActivity),
						%%改数据库数据
						ActionsStr = util:term_to_string(NewActions),
						NewGoodsStr = util:term_to_string(NewGoods),
						WhereList = [{pid, PlayerId}],
						ValueList = [{act, NewAct}, {retime, NowTime}, {actions, ActionsStr}, {goods, NewGoodsStr}],
						db_agent:update_player_activity(player_activity,ValueList, WhereList),
						4
			end
	end.

%%玩家下线，活跃度数据更新
player_logout(PlayerId) ->
%% 	?DEBUG("delete the player acitvity: ~p", [PlayerId]),
	delete_player_actions(PlayerId).
%%
%% Local Functions
%%
%%玩家活跃度的ets相关操作
update_player_actions(Activities) ->
	ets:insert(?ETS_PLAYER_ACTIVITY, Activities).
delete_player_actions(PlayerId) ->
	ets:delete(?ETS_PLAYER_ACTIVITY, PlayerId).
get_player_actions(PlayerId) ->
	ets:lookup(?ETS_PLAYER_ACTIVITY, PlayerId).

%%由活跃度转化成对应的活跃度数据位置
get_new_activity(TypeAtom, Act, Actions, Param, NowTime, PlayerId) ->
%% 	?DEBUG("the atom type is :<< ~p , ~p>>", [TypeAtom, Param]),
	Nth = get_nth(TypeAtom),%%获取位置
	Standard = get_finfish_num(Nth),%%获取完成时需要的条件
	change_act_and_actions(Nth, Standard, Act, Actions, Param, NowTime, PlayerId).

change_act_and_actions(Count, Standard, Act, Actions, Param, NowTime, PlayerId) ->
	Num = lists:nth(Count, Actions),
	case Num >= Standard of
		true ->%%已经超过 最大值了，不必判断了
			{Act, Actions};
		false ->
			change_act_and_actions_inline(Param, Act, Actions, Count, Num, Standard, NowTime, PlayerId)
	end.

change_act_and_actions_inline(0, Act, Actions, _Count, _Num, _Standard, _NowTime, _PlayerId) ->
	{Act, Actions};
change_act_and_actions_inline(Param, Act, Actions, Count, Num, Standard, NowTime, PlayerId) ->
	NewNum = Num +1,
	case NewNum =:= Standard of
		true ->
			ActNum = get_act_num(Count),
			NewAct = Act+ActNum,
			NewActions = tool:replace(Actions, Count, NewNum),
			%%添加玩家完成活跃度的日志记录
			erlang:spawn(fun() ->db_agent:insert_activity_log(PlayerId, Count, NowTime) end),
			%%达到活跃度要求了，直接跳出循环
			change_act_and_actions_inline(0, NewAct, NewActions, Count, NewNum, Standard, NowTime, PlayerId);
		false when (NewNum > Standard) ->%%超过了，直接就可以跳出循环，退出了
			change_act_and_actions_inline(0, Act, Actions, Count, Num, Standard, NowTime, PlayerId);
		false ->
			NewActions = tool:replace(Actions, Count, NewNum),
			change_act_and_actions_inline(Param-1, Act, NewActions, Count, NewNum, Standard, NowTime, PlayerId)
	end.

get_act_num(Count) ->
	lists:nth(Count, ?ACTIVITY_FINISH_GET).
%%获取数据的位置
get_nth(TypeAtom) ->
	case TypeAtom of
		fb ->%%完成1次最高等级副本任务
			1;
		gt ->%%完成1次最高等级氏族任务
			2;
		box ->%%完成1次诛邪
			3;
		shop ->%%购买1次商城物品
			4;
		hook ->%%完成30分钟高级挂机
			5;
		train ->%%完成1次远古试炼
			6;
		farm ->%%出售10个庄园果实
			7;
		yb ->%%完成1次运镖任务
			8;
		love ->%%完成仙侣情缘任务
			9;
		bc ->%%完成1次跑商任务
			10;
		evil ->%%完成温柔一刀任务
			11;
		online ->%%累计在线3小时
			12;
		fst ->%%使用2张封神帖
			13;
		rea_hor ->%%完成部落荣誉任务
			14;
		fst12 ->%%通关封神台12层
			15;
		cult ->%%完成1次修为任务
			16;
		rc ->%%完成1次日常守护任务
			17;
		answer ->%%参加1次智力答题
			18;
		hspri ->%%进入1次温泉
			19;
		peach ->%%使用3个仙桃
			20;
		td ->%%进入1次镇妖台
			21;
		_ ->
			0
	end.
%%获取完成时需要的条件
get_finfish_num(Nth) ->
	case Nth >= 1 andalso Nth =< 21 of
		true ->
			lists:nth(Nth, ?ACTIVITY_FINISH_NUM);
		false ->
			10000
	end.
%%获取对应的物品领取时所需要的活跃度
get_goods_id_and_actneed(Num) ->
	lists:nth(Num, ?ACTIVITY_GOODS_NEED).

%%处理玩家的活跃度物品领取情况
make_activity_return(ActivityData) ->
	{Act, Actions, Goods} = ActivityData,
	NOL = get_return_result(12, Actions, 60),
	NewActons = tool:replace(Actions, 12, NOL),
	NewGoods = check_goods_gotornot(Act, [], ?ACTIVITY_GOODS_NEED, Goods),
	{Act, NewActons, NewGoods}.

%%对返回的goods处理
check_goods_gotornot(_Act, NewGoods, [], []) ->
	lists:reverse(NewGoods);%%顺便反转
check_goods_gotornot(Act, NewGoods, [ActNeeds|ResAct], [G|ResGoods]) ->
	{_GId, ActNeed} = ActNeeds,
	NewG = 
		case G =:= 0 of
			true when Act >= ActNeed ->
				2;
			true ->
				G;
			false ->
				G
		end,
	check_goods_gotornot(Act, [NewG|NewGoods], ResAct, ResGoods).
%对返回的Actions处理
get_return_result(Nth, Actions, Base) ->
	Num = lists:nth(Nth, Actions),
	Condition = get_finfish_num(Nth),
%% 	?DEBUG("Num: ~p, Condition:~p", [Num,Condition]),
	case Num > Condition of
		true ->
			Condition div Base;
		false ->
			Num div Base
	end.

%% 检查玩家的某个活跃度的数据状况(需在玩家进程下用，否则没效)
%% Param  ActType ->return :[act -> Num || shop,online,_ -> true or false || peach -> Num]
check_player_activity(PlayerId, ActType) ->
	{Act, Actions, _Goods} = lib_activity:check_load_activity(PlayerId),
	case ActType of
		act ->
			Act;
		shop ->
			Num = lists:nth(4, Actions),
			Num >= 1;
		on_line ->
			Num = lists:nth(12, Actions),
			Num >= 180;
		peach ->
			lists:nth(20, Actions);
		_ ->
			false
	end.

%% 活跃度任务检查
check_player_activity_task(Type, Player) ->
	case Type of
		online_100 ->
			lib_task:event(online_100,null,Player);
		online ->
			lib_task:event(online_time,null,Player);
		_ ->
			skip
	end.