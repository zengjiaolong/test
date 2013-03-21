%% Author: Xianrong.Mai
%% Created: 2011-4-7
%% Description: TODO: 新的秘境副本接口
-module(lib_boxs_piece).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
%%
%% Exported Functions
%%
-export([get_boxs_piece_xy/0,
		 start_boxs_piece/2,
		 boxs_kill_mon/2,
		 boxs_kill_mon_goods/3]).

%%
%% API Functions
%%
%%初始化新秘境的场景信息
start_boxs_piece(UniqueSceneId, SceneId) ->
	case data_scene:get(SceneId) of
		[] ->
			fail;
		S ->
			lib_scene:copy_scene(UniqueSceneId, SceneId),
			{S#ets_scene.name}
	end.
			
boxs_kill_mon(PlayerPid, MonId) ->
	[HoleType, OpenType] = get_boxs_mon_type(MonId),
	gen_server:cast(PlayerPid, {'BOX_KILL_MON', HoleType, OpenType}).

boxs_kill_mon_goods(Status, HoleType, OpenType) ->
	{PlayerPurpleNum, OpenCounter, PurpleTimeType, GoodsTraceInit} = 
		lib_box:get_open_player_info(Status#player.id),
	PupleETList = lib_box:get_purple_equip_list(),
	PurpleEList = {0, PupleETList},
	
	[Type, Param] = mod_box:open_box(Status, GoodsTraceInit, OpenCounter, PlayerPurpleNum, 
									 PurpleTimeType, HoleType, OpenType, PurpleEList, 1),
	case Type of
		ok ->
%% 			?DEBUG("open box ok.......", []),
			{OpenCount, _HoleType, _OpenType, GoodsNumList, NewOpenBoxCount, 
			 NewPurpleNum, BoxGoodsTrace, NewPurpleEList} = Param,
			Result = gen_server:call(Status#player.other#player_other.pid_goods, {'add_box_goods', OpenCount, GoodsNumList}),
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
					mod_box_log:boradcast_box_goods(PlayerId, PlayerName, Realm, PlayerLevel, 
													Career, Sex, HoleType, GoodsList),
					%%扣元宝并且更新客户端
					GoldNeeded = lib_box:get_open_box_goldneeded(HoleType, OpenType),
					NewStatus = lib_goods:cost_money(Status, GoldNeeded, gold, 2802),
					lib_player:send_player_attribute2(NewStatus, 2),
					mod_player:save_online_diff(Status,NewStatus),
					%%做紫装记录
					{NewPurpleGoods, _PurpleEListOld} = NewPurpleEList,
					lib_box:make_purple_equip_list_record(NewPurpleGoods, PupleETList),
					
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
	{ok, NewStatus}.

%%返回新秘境的场景xy坐标
get_boxs_piece_xy() ->
	[15, 41].

%%
%% Local Functions
%%
%%根据怪物的类型id，获取开诛邪的类型
get_boxs_mon_type(MonId) ->
	case MonId of
		40108 ->
			[1,1];
		40109 ->
			[1,2];
		40110 ->
			[1,3];
		40111 ->
			[2,1];
		40112 ->
			[2,2];
		40113 ->
			[2,3];
		40114 ->
			[3,1];
		40115 ->
			[3,2];
		40116 ->
			[3,3]
	end.
