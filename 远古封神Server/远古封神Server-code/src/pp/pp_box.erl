%% Author: xiaomai
%% Created: 2010-11-17
%% Description: 诛邪系统
-module(pp_box).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
%%
%% Exported Functions
%%
-export([handle/3]).

%%
%% API Functions
%%

%%
%%
%% -----------------------------------------------------------------
%% 28001 获取全服开宝箱记录
%% -----------------------------------------------------------------
handle(28001, Status, []) -> 
 	[Len, LogsList] = mod_box_log:list_server_box_logs(),
	
%% 	Len = 0,
%% 	LogsList = [],
	
	{ok, BinData} = pt_28:write(28001, [Len, list_to_binary(LogsList)]),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;

%% -----------------------------------------------------------------
%% 28002 开宝箱
%% -----------------------------------------------------------------
handle(28002, Status, [HoleType, OpenType]) -> 
%%	?DEBUG("HoleType:~p, OpenType:~p\n", [HoleType, OpenType]),
	IsWarServer = lib_war:is_war_server(),
	case tool:is_operate_ok(pp_28002, 1) of
		true ->%%1秒钟的间隔
			if 
				HoleType =:= 4 andalso Status#player.lv < 60 ->%%远古妖洞，60级限制
					{ok, BinData} = pt_28:write(28002, [5, HoleType, []]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					ok;
				HoleType < 1 orelse HoleType > 4 ->
					{ok, BinData} = pt_28:write(28002, [0, HoleType, []]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					ok;
				OpenType < 1 orelse OpenType > 3 ->
					{ok, BinData} = pt_28:write(28002, [0, HoleType, []]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					ok;
				IsWarServer ->
					{ok, BinData} = pt_28:write(28002, [6, HoleType, []]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					ok;
				true ->
%% 					?DEBUG("28002 HoleType[~p], OpenType[~p]~n", [HoleType, OpenType]),
					{PlayerPurpleNum, OpenCounter, PurpleTimeType, GoodsTraceInit} = lib_box:get_open_player_info(Status#player.id),
%% 	io:format("PlayerPurpleNum[~p], OpenCounter[~p], PurpleTimeType[~p]\n",
%% 		   [PlayerPurpleNum, OpenCounter, PurpleTimeType]),
	%%获取一分钟内开出来的紫装Id
					PupleETList = lib_box:get_purple_equip_list(),
%% 	io:format("PupleETList1111-->~p\n",[PupleETList]),
					PurpleEList = {0, PupleETList},
					[Type, Param] = mod_box:open_box(Status, GoodsTraceInit, OpenCounter, PlayerPurpleNum, PurpleTimeType, HoleType, OpenType, PurpleEList, 1),
					case Type of
						ok ->
%% 							?DEBUG("open box ok.......", []),
%% 			{HoleType, OpenType, GoodsNumList, BoxGoodsTrace} = Param,
							{OpenCount, _HoleType, _OpenType, GoodsNumList, NewOpenBoxCount, NewPurpleNum, BoxGoodsTrace, NewPurpleEList} = Param,
							Result = gen_server:call(Status#player.other#player_other.pid_goods, {'add_box_goods', OpenCount, GoodsNumList}),
%% 			case BoxGoodsTrace of
%% 				{init, _BoxGoodsTraceUpdate} ->
%% 					lib_box:handle_box_goods_trace_result_a(NewPurpleNum, PlayerPurpleNum, 
%% 															NewOpenBoxCount, Status#player.id);
%% 				{update, BoxGoodsTraceUpdate} ->
%% 					lib_box:handle_box_goods_trace_result_b(NewPurpleNum, BoxGoodsTraceUpdate, 
%% 															PlayerPurpleNum, NewOpenBoxCount, Status#player.id)
%% 			end,
			#player{id = PlayerId,
					nickname = PlayerName,
					realm = Realm,
					career = Career,
					sex = Sex,
					lv = PlayerLevel} = Status,
			case Result of
				[1, GoodsList] ->%%哇塞，终于要广播了
					lib_box:update_box_goods_trace(BoxGoodsTrace, NewPurpleNum, 
												   PlayerPurpleNum, NewOpenBoxCount, PlayerId),
					%%广播消息
					mod_box_log:boradcast_box_goods(PlayerId, PlayerName, Realm, PlayerLevel, Career, Sex, HoleType, GoodsList),
					%%扣元宝并且更新客户端
					GoldNeeded = lib_box:get_open_box_goldneeded(HoleType, OpenType),
					NewStatus = lib_goods:cost_money(Status, GoldNeeded, gold, 2802),
					lib_player:send_player_attribute2(NewStatus, 2),
					mod_player:save_online(NewStatus),
					%%做紫装记录
					{NewPurpleGoods, _PurpleEListOld} = NewPurpleEList,
					lib_box:make_purple_equip_list_record(NewPurpleGoods, PupleETList),
					lib_activity:update_activity_data(box, Status#player.other#player_other.pid, Status#player.id, 1),%%添加玩家活跃度统计
					%%做诛邪的成就统计
					case HoleType >= 1 andalso HoleType =< 3 andalso OpenType >= 1 andalso OpenType =< 3 of
						true ->
							AchId = 500 + HoleType,
							AchNum = lib_box:set_OpenCount(OpenType),
							lib_achieve:check_achieve_finish(Status#player.other#player_other.pid_send,
															 PlayerId, AchId, [AchNum]);
						false ->
							skip
					end,
					%%氏族祝福任务判断
					GWParam = {4, 1},
					lib_gwish_interface:check_player_gwish(NewStatus#player.other#player_other.pid, GWParam),
					{ok, BinData} = pt_28:write(28002, [1, HoleType, GoodsList]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);	
				[3, GoodsParam] ->%%容量不足
					{ResultReturn, _Len, GoodsList} = GoodsParam,
					NewStatus = Status,
					{ok, BinData} = pt_28:write(28002, [ResultReturn, HoleType, GoodsList]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
				_ ->%%失败了
					NewStatus = Status,
					{ok, BinData} = pt_28:write(28002, [0, HoleType, []]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
			end;
		fail ->
			{ResultReturn, _Len, GoodsList, _HoleType} = Param,
			NewStatus = Status,
			{ok, BinData} = pt_28:write(28002, [ResultReturn, HoleType, GoodsList]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
	end,
	{ok, NewStatus}
			end;
		false ->
			{ok, BinData} = pt_28:write(28002, [4, HoleType, []]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok
	end;

%% -----------------------------------------------------------------
%% 28003 获取诛邪仓库数据
%% -----------------------------------------------------------------
handle(28003, Status, []) -> 
 	[GoodsList] = mod_box:get_warehouse(Status),
	
%% 	Len = 0,
%% 	GoodsList = [],
	
	{ok, BinData} = pt_28:write(28003, [GoodsList]),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;

%% -----------------------------------------------------------------
%% 28004 将物品放入背包
%% -----------------------------------------------------------------
handle(28004, Status, [GoodsId, GoodsNum, GoodsIndex]) -> 
	%% ?DEBUG("28004 ApplyList[~p,~p,~p]", [GoodsId, GoodsNum,GoodsIndex]),
 	[Result] = mod_box:put_goods_into_bag(Status, [GoodsId, GoodsNum]),
	
%% 	Result = 0,
	
	{ok, BinData} = pt_28:write(28004, [Result, GoodsIndex]),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;

%% -----------------------------------------------------------------
%% 28005 将物品丢弃
%% -----------------------------------------------------------------
handle(28005, Status, [GoodsId,GodsNum]) -> 
	%% ?DEBUG("28005 ApplyList[~p, ~p]", [GoodsId, GodsNum]),
 	[Result] = mod_box:discard_box_goods(Status, GoodsId,GodsNum),
	
%% 	Result = 0,
	
	{ok, BinData} = pt_28:write(28005, [Result]),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;

%% -----------------------------------------------------------------
%% 28006 丢弃仓库中的所有物品
%% -----------------------------------------------------------------
handle(28006, Status, []) ->
 	[Result] = mod_box:discard_all_box_goods(Status),
%% 	Result = 0,
	{ok, BinData} = pt_28:write(28006, [Result]),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;

%% -----------------------------------------------------------------
%% 28007 将所有物品放入背包
%% -----------------------------------------------------------------
handle(28007, Status, []) ->
	[Result] = mod_box:put_all_goods_into_bag(Status),
	{ok, BinData} = pt_28:write(28007, [Result]),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;

%% -----------------------------------------------------------------
%% 28008 获取仓库的容量
%% -----------------------------------------------------------------
handle(28008, Status, []) ->
	[RemainCells] = mod_box:get_box_remain_cells(Status),
	{ok, BinData} = pt_28:write(28008, [RemainCells]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;

%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
handle(_Cmd, _Status, _Data) ->
	?DEBUG("pp_guild no match", []),
    {error, "pp_guild no match"}.


%%
%% Local Functions
%%

