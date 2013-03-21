%% Author: xianrongMai
%% Created: 2012-3-28
%% Description: 衣橱功能的处理接口
-module(lib_wardrobe).

%%
%% Include files
%%

-include("common.hrl").
-include("record.hrl").
-include("hot_spring.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

%%
%% Exported Functions
%%
-export([
		 check_need_f5_wardrobe/6,					%% 检查是否需要主推刷新衣橱数据
		 change_warbrode_sex/2,						%% 变性修改衣橱的Id数据
		 check_wardrobe_dress/3,					%% 检查换装是否合法
		 wardrobe_dress/5,							%% 衣橱换装
		 get_player_wardrobe_activated/1,			%% 15142 获取衣橱已激活的图鉴数据
		 player_logout/1,							%% 玩家下线处理
		 unequip_check_wardrobe/2,					%% 卸载时装类衣服,法宝,和 挂饰时去掉对应的装备Ids
		 equip_check_wardrobe/5,					%% 装备时装类衣服,法宝,和 挂饰时激活对应的图鉴
		 get_player_wardrobe/1,						%% 获取衣橱的ets数据
		 init_player_wardrobe/1,					%% 初始化玩家的衣橱数据
		 check_goods_wardrobe/2						%% 检查是否属于时装类的物品
		]).

%%
%% API Functions
%%
%% 初始化玩家的衣橱数据
init_player_wardrobe(Pid) ->
	case db_agent:get_player_wardrobe(Pid) of
		[] ->
			Id = 0,
			TJ = [],
			TJStr = util:term_to_string(TJ),
			Fields = [pid, yfid, yftj, fbid, fbtj, gsid, gstj],
			Values = [Pid, Id, TJStr, Id, TJStr, Id, TJStr],
			db_agent:insert_player_wardrobe(Fields, Values),
			FashionEquip = #ets_fashion_equip{pid = Pid,
											  yfid = Id,
											  yftj = TJ,
											  fbid = Id,
											  fbtj = TJ,
											  gsid = Id,
											  gstj = TJ},
			update_player_wardrobe(FashionEquip);
		[YfId, YfTJStr, FbId, FbTJStr, GsId, GsTJStr] ->
			YfTJ = 
				case util:string_to_term(tool:to_list(YfTJStr)) of
					YfList when is_list(YfList) ->
						YfList;
					_ ->
						[]
				end,
			FbTJ = 
				case util:string_to_term(tool:to_list(FbTJStr)) of
					FbList when is_list(FbList) ->
						FbList;
					_ ->
						[]
				end,
			GsTJ = 
				case util:string_to_term(tool:to_list(GsTJStr)) of
					GsList when is_list(GsList) ->
						GsList;
					_ ->
						[]
				end,
			FashionEquip = #ets_fashion_equip{pid = Pid,
											  yfid = YfId,
											  yftj = YfTJ,
											  fbid = FbId,
											  fbtj = FbTJ,
											  gsid = GsId,
											  gstj = GsTJ},
			update_player_wardrobe(FashionEquip)
	end.

%% 玩家下线处理
player_logout(Pid) ->
%% 	?DEBUG("player logout", []),
	delete_player_wardrobe(Pid).

%% ------------------------------------
%% 15142 获取衣橱已激活的图鉴数据
%% ------------------------------------
get_player_wardrobe_activated(Pid) ->
	FashionEquip = get_player_wardrobe(Pid),
	#ets_fashion_equip{yftj = YfTJ,
					   fbtj = FbTJ,
					   gstj = GsTJ} = FashionEquip,
%% 	?DEBUG("1:~p, 2:~p, 3:~p", [YfTJ, FbTJ, GsTJ]),
	YfTJData = make_wardrobe_data(YfTJ, 1, []),
	FbTJData = make_wardrobe_data(FbTJ, 2, YfTJData),
	GsTJData = make_wardrobe_data(GsTJ, 3, FbTJData),
%% 	?DEBUG("wardrobe:~p", [YfTJData]),
	GsTJData.

%% 装备时装类衣服,法宝,和 挂饰时激活对应的图鉴
equip_check_wardrobe(GoodsInfo, Pid, Sex, UseType, PName) ->
	#goods{type = GoodsType,
		   subtype = GoodsSubType} = GoodsInfo,
	case check_goods_wardrobe(GoodsType, GoodsSubType)of
		false ->
%% 			?DEBUG("Type:~p", [0]),
			{0, GoodsInfo};
		Type ->
%% 			?DEBUG("Type:~p", [Type]),
			activate_player_wardrobe(Type, GoodsInfo, Pid, Sex, UseType, PName)
	end.
%%激活需要操作的图鉴
activate_player_wardrobe(Type, GoodsInfo, Pid, Sex, UseType, PName) ->
	#goods{icon = GIcon, 
		   goods_id = GoodsId} =GoodsInfo,
	case Type of
		yifu ->%%时装衣服
			FashionEquip = get_player_wardrobe(Pid),
			YfTJ = FashionEquip#ets_fashion_equip.yftj,
			case UseType of
				goods ->%%物品的使用
					FashionEquip = get_player_wardrobe(Pid),
					YfTJ = FashionEquip#ets_fashion_equip.yftj,
					NYfId = 
						case GIcon > 0 of
							true ->
								GIcon;
							false ->
								GoodsId
						end,
					{IsNeedF5, NGoodsInfo, NFList} = check_whether_activate(GoodsInfo, YfTJ, NYfId, PName),
					case IsNeedF5 of
						1 ->%%有激活图鉴的
							NFashionEquip = FashionEquip#ets_fashion_equip{yfid = GoodsId,
																		   yftj = NFList},
							update_player_wardrobe(NFashionEquip),
							WhereList = [{pid, Pid}],
							NYfTJStr = util:term_to_string(NFList),
							ValueList = [{yfid, NYfId},{yftj, NYfTJStr}],
							db_agent:update_player_wardrobe(WhereList, ValueList),
							%%添加激活时装的日志
							erlang:spawn(fun() -> db_agent:insert_log_fashion_equip(Pid,Sex,1,GoodsId) end),
							{IsNeedF5, NGoodsInfo};
						_ ->%%没有激活图鉴的
							NFashionEquip = FashionEquip#ets_fashion_equip{yfid = GoodsId},
							update_player_wardrobe(NFashionEquip),
							WhereList = [{pid, Pid}],
							ValueList = [{yfid, NYfId}],
							db_agent:update_player_wardrobe(WhereList, ValueList),
							{IsNeedF5, NGoodsInfo}
					end;
				change ->%%变身卡的使用
					NFList = [GoodsId|YfTJ],
					NFashionEquip = FashionEquip#ets_fashion_equip{yfid = GoodsId,
																   yftj = NFList},
					update_player_wardrobe(NFashionEquip),
					WhereList = [{pid, Pid}],
					NYfTJStr = util:term_to_string(NFList),
					ValueList = [{yftj, NYfTJStr}, {yfid, GoodsId}],
					db_agent:update_player_wardrobe(WhereList, ValueList),
					%%添加激活时装的日志
					erlang:spawn(fun() -> db_agent:insert_log_fashion_equip(Pid,Sex,1,GoodsId) end),
					{3, GoodsInfo}
			end;
		fabao ->%%时装法宝
			FashionEquip = get_player_wardrobe(Pid),
			FbTJ = FashionEquip#ets_fashion_equip.fbtj,
			case UseType of
				goods ->%%物品的使用
					FashionEquip = get_player_wardrobe(Pid),
					FbTJ = FashionEquip#ets_fashion_equip.fbtj,
					NFbId = 
						case GIcon > 0 of
							true ->
								GIcon;
							false ->
								GoodsId
						end,
					{IsNeedF5, NGoodsInfo, NFList} = check_whether_activate(GoodsInfo, FbTJ, NFbId, PName),
					case IsNeedF5 of
						1 ->%%有激活图鉴的
							NFashionEquip = FashionEquip#ets_fashion_equip{fbid = GoodsId,
																		   fbtj = NFList},
							update_player_wardrobe(NFashionEquip),
							WhereList = [{pid, Pid}],
							NYfTJStr = util:term_to_string(NFList),
							ValueList = [{fbid, NFbId},{fbtj, NYfTJStr}],
							db_agent:update_player_wardrobe(WhereList, ValueList),
							%%添加激活时装的日志
							erlang:spawn(fun() -> db_agent:insert_log_fashion_equip(Pid,Sex,1,GoodsId) end),
							{IsNeedF5, NGoodsInfo};
						_ ->%%没有激活图鉴的
							NFashionEquip = FashionEquip#ets_fashion_equip{fbid = GoodsId},
							update_player_wardrobe(NFashionEquip),
							WhereList = [{pid, Pid}],
							ValueList = [{fbid, NFbId}],
							db_agent:update_player_wardrobe(WhereList, ValueList),
							{IsNeedF5, NGoodsInfo}
					end;
				change ->%%变身卡的使用
					NFList = [GoodsId|FbTJ],
					NFashionEquip = FashionEquip#ets_fashion_equip{fbid = GoodsId,
																   fbtj = NFList},
					update_player_wardrobe(NFashionEquip),
					WhereList = [{pid, Pid}],
					NFbTJStr = util:term_to_string(NFList),
					ValueList = [{fbtj, NFbTJStr}, {fbid, GoodsId}],
					db_agent:update_player_wardrobe(WhereList, ValueList),
					%%添加激活时装的日志
					erlang:spawn(fun() -> db_agent:insert_log_fashion_equip(Pid,Sex,1,GoodsId) end),
					{3, GoodsInfo}
			end;
		guashi ->%%时装挂饰
			FashionEquip = get_player_wardrobe(Pid),
			GsTJ = FashionEquip#ets_fashion_equip.gstj,
			case UseType of
				goods ->%%物品的使用
					FashionEquip = get_player_wardrobe(Pid),
					GsTJ = FashionEquip#ets_fashion_equip.gstj,
					NGsId = 
						case GIcon > 0 of
							true ->
								GIcon;
							false ->
								GoodsId
						end,
					{IsNeedF5, NGoodsInfo, NFList} = check_whether_activate(GoodsInfo, GsTJ, NGsId, PName),
					case IsNeedF5 of
						1 ->%%有激活图鉴的
							NFashionEquip = FashionEquip#ets_fashion_equip{gsid = GoodsId,
																		   gstj = NFList},
							update_player_wardrobe(NFashionEquip),
							WhereList = [{pid, Pid}],
							NGsTJStr = util:term_to_string(NFList),
							ValueList = [{gsid, NGsId},{gstj, NGsTJStr}],
							db_agent:update_player_wardrobe(WhereList, ValueList),
							%%添加激活时装的日志
							erlang:spawn(fun() -> db_agent:insert_log_fashion_equip(Pid,Sex,1,GoodsId) end),
							{IsNeedF5, NGoodsInfo};
						_ ->%%没有激活图鉴的
							NFashionEquip = FashionEquip#ets_fashion_equip{gsid = GoodsId},
							update_player_wardrobe(NFashionEquip),
							WhereList = [{pid, Pid}],
							ValueList = [{gsid, NGsId}],
							db_agent:update_player_wardrobe(WhereList, ValueList),
							{IsNeedF5, NGoodsInfo}
					end;
				change ->%%变身卡的使用
					NFList = [GoodsId|GsTJ],
					NFashionEquip = FashionEquip#ets_fashion_equip{gsid = GoodsId,
																   gstj = NFList},
					update_player_wardrobe(NFashionEquip),
					WhereList = [{pid, Pid}],
					NGsTJStr = util:term_to_string(NFList),
					ValueList = [{gstj, NGsTJStr}, {gsid, GoodsId}],
					db_agent:update_player_wardrobe(WhereList, ValueList),
					%%添加激活时装的日志
					erlang:spawn(fun() -> db_agent:insert_log_fashion_equip(Pid,Sex,1,GoodsId) end),
					{3, GoodsInfo}
			end;
		_ ->
			{0, GoodsInfo}
	end.

%%检查是否能够激活图鉴
check_whether_activate(GoodsInfo, TJList, GNIcon, PName) ->
	#goods{id = Gid,
		   goods_id = GoodsId,
		   used = Used} = GoodsInfo,
	case Used of
		0 ->%%没使用过
			{IsNeedF5, NTJList, ActNum} = 
				case lists:member(GNIcon, TJList) of
					true ->
						Mid = TJList,
						case lists:member(GoodsId, Mid) of
							true ->
								{2, Mid, 0};
							false ->
								{1, [GoodsId|Mid], 1}
						end;
					false ->
						Mid = [GNIcon|TJList],
						case lists:member(GoodsId, Mid) of
							true ->
								{1, Mid, 1};
							false ->
								{1, [GoodsId|Mid], 2}
						end
				end,
			NGoodsInfo = GoodsInfo#goods{used = 1},
			WhereList = [{id, Gid}],
			ValueList = [{used, 1}],
			db_agent:update_goods_used(ValueList, WhereList),
			ets:insert(?ETS_GOODS_ONLINE, NGoodsInfo),
			%% 活动	激活图鉴	
			lib_act_interf:wardrobe_activited_award(PName, ActNum),
			{IsNeedF5, NGoodsInfo, NTJList};
		_ ->%%使用过了
			{0, GoodsInfo, TJList}
	end.

%% 卸载时装类衣服,法宝,和 挂饰时去掉对应的装备Ids
unequip_check_wardrobe(GoodsInfo, Pid) ->
	#goods{type = GoodsType,
		   subtype = GoodsSubType} = GoodsInfo,
	case check_goods_wardrobe(GoodsType, GoodsSubType)of
		false ->
			skip;
		Type ->
			reset_player_wardrobe(Type, 0, Pid)
	end.
%%时装icon复位
reset_player_wardrobe(Type, GoodsTypeId, Pid) ->
	case Type of
		yifu ->%%时装衣服
			FashionEquip = get_player_wardrobe(Pid),
			NFashionEquip = FashionEquip#ets_fashion_equip{yfid = GoodsTypeId},
			update_player_wardrobe(NFashionEquip),
			WhereList = [{pid, Pid}],
			ValueList = [{yfid, GoodsTypeId}],
			db_agent:update_player_wardrobe(WhereList, ValueList);
		fabao ->%%时装法宝
			FashionEquip = get_player_wardrobe(Pid),
			NFashionEquip = FashionEquip#ets_fashion_equip{fbid = GoodsTypeId},
			update_player_wardrobe(NFashionEquip),
			WhereList = [{pid, Pid}],
			ValueList = [{fbid, GoodsTypeId}],
			db_agent:update_player_wardrobe(WhereList, ValueList);
		guashi ->%%时装挂饰
			FashionEquip = get_player_wardrobe(Pid),
			NFashionEquip = FashionEquip#ets_fashion_equip{gsid = GoodsTypeId},
			update_player_wardrobe(NFashionEquip),
			WhereList = [{pid, Pid}],
			ValueList = [{gsid, GoodsTypeId}],
			db_agent:update_player_wardrobe(WhereList, ValueList);
		_ ->
			skip
	end.

%% 检查是否属于时装类的物品
check_goods_wardrobe(GoodsType, GoodsSubType) ->
%% 	?DEBUG("Type:~p, SubType:~p", [GoodsType, GoodsSubType]),
	if 
		GoodsType =:= 10 andalso GoodsSubType =:= 24 ->%% 衣服时装类{10,24}
			yifu;
		GoodsType =:= 10 andalso GoodsSubType =:= 26 ->%% 法宝时装类{10,26}
			fabao;
		GoodsType =:= 10 andalso GoodsSubType =:= 27 ->%% 挂饰时装类{10,27}
			guashi;
		true ->
			false
	end.

%% 检查换装是否合法
check_wardrobe_dress(Player, Type, FashionId) ->
	#player{id = Pid} = Player,
	%%判断是否已经激活图鉴
	FashionEquip = get_player_wardrobe(Pid),
	{Cell, IsActivated} = 
		case Type of
			1 ->%%衣服
				YfTJ = FashionEquip#ets_fashion_equip.yftj,
				{13, lists:member(FashionId, YfTJ)};
			2 ->%%法宝
				FbTJ = FashionEquip#ets_fashion_equip.fbtj,
				{15, lists:member(FashionId, FbTJ)};
			3 ->%%挂饰
				GsTJ = FashionEquip#ets_fashion_equip.gstj,
				{16, lists:member(FashionId, GsTJ)};
			_ ->%%此处可以添加法宝，挂饰判断
				{0, false}
		end,
	case IsActivated of
		true ->
			%%查看该时装是否合法
			GoodsTypeInfo = goods_util:get_goods_type(FashionId),
			if
				is_record(GoodsTypeInfo, ets_base_goods) =:= false ->
					{fail, 4};%%物品不存在
				GoodsTypeInfo#ets_base_goods.sex =/= 0 andalso GoodsTypeInfo#ets_base_goods.sex =/= Player#player.sex ->
					{fail, 5};%%性别不符合
				GoodsTypeInfo#ets_base_goods.career =/= 0 andalso GoodsTypeInfo#ets_base_goods.career =/= Player#player.career ->
					{fail, 6};%%职业不符合
				GoodsTypeInfo#ets_base_goods.type =/= 10 ->
					{fail, 7};%% 物品类型不可装备
				GoodsTypeInfo#ets_base_goods.type =:= 10 andalso GoodsTypeInfo#ets_base_goods.subtype =:= 22 ->
					{fail, 7};%% 坐骑不可装备
				Player#player.equip =/= 1 ->
					{fail, 7};
				true ->
					%%装备对应cell
					DefCell = goods_util:get_equip_cell(Player,GoodsTypeInfo#ets_base_goods.subtype),
					case Cell =:= DefCell of
						true ->
							%%身上是否有穿时装
							Location = Player#player.equip,
							GoodsInfo = goods_util:get_goods_by_cell(Pid, Location, Cell),
							case is_record(GoodsInfo, goods) of
								true ->
									{ok, GoodsTypeInfo, GoodsInfo};
								false ->
									{fail, 3}
							end;
						false ->
							{fail, 7}
					end
			end;
		false ->
			{fail, 2}
	end.
			
%% 衣橱换装
wardrobe_dress(Player, Type, GoodsTypeInfo, GoodsInfo, GoodsStatus) ->
	[Wq, Yf, Fbyf, Spyf, Zq] = GoodsStatus#goods_status.equip_current,
	CurrentEquip = 
		case Type of
			1 ->%%时装衣服
				%%修改时装iconId
				Pid = Player#player.id,
				YfId = GoodsTypeInfo#ets_base_goods.goods_id,
				FashionEquip = get_player_wardrobe(Pid),
				NFashionEquip = FashionEquip#ets_fashion_equip{yfid = YfId},
				update_player_wardrobe(NFashionEquip),
				WhereList = [{pid, Pid}],
				ValueList = [{yfid, YfId}],
				db_agent:update_player_wardrobe(WhereList, ValueList),
				update_goods_icon(GoodsInfo, YfId),
				[Wq, YfId, Fbyf, Spyf, Zq];
			2 ->%%时装法宝
				%%修改时装iconId
				Pid = Player#player.id,
				FbId = GoodsTypeInfo#ets_base_goods.goods_id,
				FashionEquip = get_player_wardrobe(Pid),
				NFashionEquip = FashionEquip#ets_fashion_equip{fbid = FbId},
				update_player_wardrobe(NFashionEquip),
				WhereList = [{pid, Pid}],
				ValueList = [{fbid, FbId}],
				db_agent:update_player_wardrobe(WhereList, ValueList),
				update_goods_icon(GoodsInfo, FbId),
				[Wq, Yf, FbId, Spyf, Zq];
			3 ->%%时装挂饰
				%%修改时装iconId
				Pid = Player#player.id,
				GsId = GoodsTypeInfo#ets_base_goods.goods_id,
				FashionEquip = get_player_wardrobe(Pid),
				NFashionEquip = FashionEquip#ets_fashion_equip{gsid = GsId},
				update_player_wardrobe(NFashionEquip),
				WhereList = [{pid, Pid}],
				ValueList = [{gsid, GsId}],
				db_agent:update_player_wardrobe(WhereList, ValueList),
				update_goods_icon(GoodsInfo, GsId),
				[Wq, Yf, Fbyf, GsId, Zq];
			_ ->
				[Wq, Yf, Fbyf, Spyf, Zq]
		end,
	
	NGoodsStatus = GoodsStatus#goods_status{equip_current = CurrentEquip},
	NPlayer = Player#player{other = Player#player.other#player_other{equip_current = CurrentEquip}},
	%%使用后角色面板要刷新
	gen_server:cast(self(), {'list_15010', NPlayer, 1}),
	{NPlayer, NGoodsStatus}.

%% 变性修改衣橱的Id数据
change_warbrode_sex(Pid, EquipCurrent) ->
	[_Wq, Yf, Fbyf, _Spyf, _Zq] = EquipCurrent,
	FashionEquip = get_player_wardrobe(Pid),
	#ets_fashion_equip{yftj = YfTJ,
					   fbtj = FbTJ} = FashionEquip,
	NYfTJ = wardrobe_idchange_sex(yifu, YfTJ, []),
	NFbTJ = wardrobe_idchange_sex(fabao, FbTJ, []),
	NFashionEquip = FashionEquip#ets_fashion_equip{yfid = Yf,
												   yftj = NYfTJ,
												   fbid = Fbyf,
												   fbtj = NFbTJ},
	update_player_wardrobe(NFashionEquip),
	NYfTJStr = util:term_to_string(NYfTJ),
	NFbTJStr = util:term_to_string(NFbTJ),
	WhereList = [{pid, Pid}],
	ValueList = [{yfid, Yf}, {yftj, NYfTJStr}, {fbid, Fbyf}, {fbtj, NFbTJStr}],
	db_agent:update_player_wardrobe(WhereList, ValueList).

%% 检查是否需要主推刷新衣橱数据
check_need_f5_wardrobe(PidGoods, Pid, PidSend, IsNeedF5, NewGoodsInfo, GoodsStatus) ->
	case IsNeedF5 of
		1 ->%%衣橱+物品信息
			%%重新推一次物品信息，更新使用状态信息
			case goods_util:has_attribute(NewGoodsInfo) of
				true -> AttributeList = goods_util:get_goods_attribute_list(GoodsStatus#goods_status.player_id, NewGoodsInfo#goods.id);
				false -> AttributeList = []
			end,
			SuitNum = goods_util:get_suit_num(GoodsStatus#goods_status.equip_suit, NewGoodsInfo#goods.suit_id),
			{ok, BinData15000} = pt_15:write(15000, [NewGoodsInfo, SuitNum, AttributeList]),
			lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData15000),	
			gen_server:cast(PidGoods,
							{'GET_PLAYER_WARDROBE', Pid, PidSend});
		2 ->%%只推物品信息
			%%重新推一次物品信息，更新使用状态信息
			case goods_util:has_attribute(NewGoodsInfo) of
				true -> AttributeList = goods_util:get_goods_attribute_list(GoodsStatus#goods_status.player_id, NewGoodsInfo#goods.id);
				false -> AttributeList = []
			end,
			SuitNum = goods_util:get_suit_num(GoodsStatus#goods_status.equip_suit, NewGoodsInfo#goods.suit_id),
			{ok, BinData15000} = pt_15:write(15000, [NewGoodsInfo, SuitNum, AttributeList]),
			lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData15000);
		3 ->%%只是更新衣橱的数据
			gen_server:cast(PidGoods,
							{'GET_PLAYER_WARDROBE', Pid, PidSend});
		_ ->
			skip
	end.
%%
%% Local Functions
%%
update_goods_icon(GoodsInfo, NIcon) ->
	NGoodsInfo = GoodsInfo#goods{icon = NIcon},
	ets:insert(?ETS_GOODS_ONLINE,NGoodsInfo),
	db_agent:update_goods_icon(GoodsInfo#goods.id, NIcon).

%% 衣橱的ets数据操作
update_player_wardrobe(FashionEquip) ->
%% 	?DEBUG("FashionEquip is :~p", [FashionEquip]),
	ets:insert(?ETS_FASHION_EQUIP, FashionEquip).
get_player_wardrobe(Pid) ->
	case ets:lookup(?ETS_FASHION_EQUIP, Pid) of
		[]->
			#ets_fashion_equip{pid  = Pid};
		[FashionEquip|_] ->
			FashionEquip
	end.

delete_player_wardrobe(Pid) ->
	ets:delete(?ETS_FASHION_EQUIP, Pid).

%%打包处理衣橱里已激活的时装数据
make_wardrobe_data([], _Type, Result) ->
	Result;
make_wardrobe_data([Elem|TJ], Type, Result) ->
	make_wardrobe_data(TJ, Type, [{Type, Elem}|Result]).


wardrobe_idchange_sex(guashi, [], Result) ->
	Result;
wardrobe_idchange_sex(guashi, [Elem|Rest], Result) ->
	%%此处要添加法宝的转换接口
	wardrobe_idchange_sex(fabao, Rest, [Elem|Result]);
wardrobe_idchange_sex(fabao, [], Result) ->
	Result;
wardrobe_idchange_sex(fabao, [Elem|Rest], Result) ->
	case lib_player:get_fashion_fb_sp_change(Elem) of
		0 ->
			wardrobe_idchange_sex(fabao, Rest, Result);
		NElem ->
			wardrobe_idchange_sex(fabao, Rest, [NElem|Result])
	end;
wardrobe_idchange_sex(yifu, [], Result) ->
	Result;
wardrobe_idchange_sex(yifu, [Elem|Rest], Result) ->
	case lib_player:get_fashion_equip_change(Elem) of
		0 ->
			wardrobe_idchange_sex(yifu, Rest, Result);
		NElem ->
			wardrobe_idchange_sex(yifu, Rest, [NElem|Result])
	end;
wardrobe_idchange_sex(_Other, _Rest, _Result) ->
	[].


