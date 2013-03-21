%% Author: xianrongMai
%% Created: 2012-2-13
%% Description: 市场求购模块处理接口
-module(lib_buy).

%%
%% Include files
%%

-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

-define(BUY_GOODS_BASE_TIME, 3600).		%%拍卖时间基数(60*60 = 3600秒)
%% -define(BUY_GOODS_BASE_TIME, 100).		%%测试用
%%
%% Exported Functions
%%
-export([
		 list_buy_goods/9,							%% 17001 查询市场中存在的物品(求购)
		 get_buygoods_info/3,						%% 17007 获取物品详细信息(仅在市场拍卖模块用)
		 get_buy_goods_attributes/2,				%% 17008 获取物品属性信息
		 get_goods_attributes/1,					%%获取相关的物品的额外属性
		 buy_goods_request/9,						%% 17009 求购物品请求
		 buy_cash_request/5,						%% 17010 开始求购元宝或铜币
		 submit_buy_goods/3,						%% 17011 出卖对应求购物品请求(除了装备)
		 buy_goods_sendmail/6,
		 check_attributes/2,						%% 检查属性是否正确
		 list_buy_goods_self/2,						%% 17012 查看已求购物品
		 cancel_buy_goods/4,						%% 17013 取消求购物品
		 submit_buy_goods_equip/3,					%% 17014 出卖对应求购物品请求(装备类)
		 get_buy_goods_maxoverlap/2,				%% 17015 物品的最大堆叠数
		 buy_goods_equip_sendmail/7,
		 load_all_buy_goods/0,						%%加载所有的求购数据
		 handle_buy_goods_timeout/0,				%%处理所有超时的求购信息
		 labour_cancel_all_goods_buy/0,				%%人工手动下架所有的拍卖物品
		 cancel_all_goods_buy/0,
		 list_hot_goods/6
		 ]).

%%
%% API Functions
%%
%% 加载所有的求购数据
load_all_buy_goods() ->
	AllList = db_agent:load_all_buy_goods(),
	lists:foreach(fun db_into_ets_buy_good/1, AllList).

%%处理所有超时的求购信息
handle_buy_goods_timeout() ->
	NowTime = util:unixtime(),
	AllList = ets_get_buy_goods_all(),
	{SubRecords, _NonSubRecords} = 
		lists:partition(fun(Record) ->
								DiffTime = NowTime - Record#ets_buy_goods.buy_time,
								SaleTime = Record#ets_buy_goods.continue * ?BUY_GOODS_BASE_TIME,
								DiffTime > SaleTime
								 end, AllList),
	lists:foreach(fun(Elem) ->
						  handle_buy_goods_timeout_each(Elem, NowTime)
				  end, SubRecords).
handle_buy_goods_timeout_each(BuyGoods, NowTime) ->
	#ets_buy_goods{id = BuyId,
				   buy_type = BuyType,
				   gid = GoodsTypeId,
				   num = Num,
				   unprice = UnPrice,
				   price_type = PriceType,
				   pid = Pid,
				   pname = PName,
				   continue = Continue} = BuyGoods,
	case BuyType of
		2 ->%%求购元宝或者铜钱，所以没有数量的计算，直接返回扣除的
			{SendType, Param} =
				case PriceType of
					2 ->%%价格是元宝
						Gold = UnPrice,
						Coin = 0,
						{buy_goldprice_timeout, {Gold, Coin}};
					_C ->%%价格是铜钱
						Gold = 0,
						Coin = UnPrice,
						{buy_coinprice_timeout, {Gold, Coin}}
			end,
			%%清除ets
			ets_delete_buy_goods_by_id(BuyId),
			%%删除数据库表
			WhereList = [{id, BuyId}],
			db_agent:delete_buy_goods_record(WhereList),
			%%邮件通知
			erlang:spawn(fun() -> sendmail_for_buy(PName, SendType, Param) end),
			%%写入求购日志
			LogBuyGoods = 
				#log_buy_goods{buyid = BuyId,
							   buy_type = BuyType,
							   bid = Pid,
							   bname = PName,
							   num = Num,
							   ptype = PriceType,
							   unprice = UnPrice,
							   goodsid = GoodsTypeId,
							   f_type = 3,
							   f_time = NowTime,
                               continue = Continue},
			erlang:spawn(fun() -> db_agent:insert_log_buy_goods(LogBuyGoods) end );
		1 ->%%求购的是物品
			if
				Num > 0 ->%%先判断数量是否还是大于0
					{SendType, Param} =
						case PriceType of
							2 ->%%价格是元宝
								Gold = erlang:trunc(UnPrice * Num),
								Coin = 0,
								{buy_goldprice_timeout, {Gold, Coin}};
							_C ->%%价格是铜钱
								Gold = 0,
								Coin = erlang:trunc(UnPrice * Num),
								{buy_coinprice_timeout, {Gold, Coin}}
						end,
					%%清除ets
					ets_delete_buy_goods_by_id(BuyId),
					%%删除数据库表
					WhereList = [{id, BuyId}],
					db_agent:delete_buy_goods_record(WhereList),
					%%邮件通知
					erlang:spawn(fun() -> sendmail_for_buy(PName, SendType, Param) end),
					%%写入求购日志
					LogBuyGoods = 
						#log_buy_goods{buyid = BuyId,
									   buy_type = BuyType,
									   bid = Pid,
									   bname = PName,
									   num = Num,
									   ptype = PriceType,
									   unprice = UnPrice,
									   goodsid = GoodsTypeId,
									   f_type = 3,
									   f_time = NowTime,
									   continue = Continue},
					erlang:spawn(fun() -> db_agent:insert_log_buy_goods(LogBuyGoods) end);
				true ->
					%%清除ets
					ets_delete_buy_goods_by_id(BuyId),
					%%删除数据库表
					WhereList = [{id, BuyId}],
					db_agent:delete_buy_goods_record(WhereList),
					%%写入求购日志
					LogBuyGoods = 
						#log_buy_goods{buyid = BuyId,
									   buy_type = BuyType,
									   bid = Pid,
									   bname = PName,
									   num = Num,
									   ptype = PriceType,
									   unprice = UnPrice,
									   goodsid = GoodsTypeId,
									   f_type = 3,
									   f_time = NowTime,
									   continue = Continue},
					erlang:spawn(fun() -> db_agent:insert_log_buy_goods(LogBuyGoods) end)
			end
	end.
		
%% -----------------------------------------------------------------
%% 17001 查询市场中存在的物品(求购)
%% -----------------------------------------------------------------
list_buy_goods(GoodsLevelId, Color, Career, Type, SubTypeList, SortType, GoodsName, StartNum, EndNum) ->		
	%%求购表过滤
	GoodsRecords = filter_buy_goods(GoodsLevelId, Color, Career, Type, SubTypeList, GoodsName),
	%%按时间倒序一下，越 晚拍的，越靠前
	PartitionGoods = sort_buy_from_time(GoodsRecords),
	%%按照价格类型排序
	LenCheck = length(PartitionGoods),
	case LenCheck > 1 of
		true ->
			case SortType of
				0 ->%%默认的时候是不排序的
					SortPriceBuyGoods = PartitionGoods;
				1 ->%按照价格降序升序
					SortPriceBuyGoods = lists:sort(fun sort_goods_by_price_asc/2, PartitionGoods);
				2 ->%%%按照价格降序
					SortPriceBuyGoods = lists:sort(fun sort_goods_by_price_desc/2, PartitionGoods);
				3 ->%%单价按照升序排序
					SortPriceBuyGoods = lists:sort(fun sort_goods_by_unprice_asc/2, PartitionGoods);
				4 ->%%单价按照降序排序
					SortPriceBuyGoods = lists:sort(fun sort_goods_by_unprice_desc/2, PartitionGoods);
				_ ->%%直接过滤一些非法错误的操作
					SortPriceBuyGoods = PartitionGoods
			end;
		false ->
			SortPriceBuyGoods = PartitionGoods
	end,
	Len = length(SortPriceBuyGoods),
	
%% 	SaleGoodsList = lists:map(fun handle_sale_goods/1, SortPriceSaleGoods),
	if 
		Len == 0 ->
			[Len, 0, []];
		Len < StartNum ->
		  [Len, 0, []];
		true ->
%% 			NewSaleGoodsList = lists:sublist(SaleGoodsList, StartNum, EndNum),
			NewBuyGoodsList = lists:sublist(SortPriceBuyGoods, StartNum, EndNum),
			NewLen = length(NewBuyGoodsList),
			[Len, NewLen, NewBuyGoodsList]
	end.

%%对求购表的数据进行过滤
filter_buy_goods(GoodsLevelId, Color, Career, Type, SubTypeList, GoodsName) ->
%% 	?DEBUG("GoodsLevelId:~p, Color:~p, Career:~p, Type:~p, SubTypeList:~p", [GoodsLevelId, Color, Career, Type, SubTypeList]),
	ColorCareerGoods = 
		if
			Color =/= 99 andalso Career =/= 0 ->%%颜色和职业的限制
				Pattern = #ets_buy_goods{gcolor = Color, career = Career, _ = '_'},
				ets_match_buy_goods(Pattern);
			Color =/= 99 andalso Career =:= 0 ->%%只做职业的限制
				Pattern = #ets_buy_goods{gcolor = Color, _ = '_'},
				
				ets_match_buy_goods(Pattern);
			Color =:= 99 andalso Career =/= 0 ->%%只做颜色的限制
				Pattern = #ets_buy_goods{career = Career, _ = '_'},
				ets_match_buy_goods(Pattern);
			true ->%%都不做限制
				ets_get_buy_goods_all()
		end,
	%%过滤等级范围
	{LevelGoods, _NoLevelGoods} =
		case lib_sale:get_sale_levels_by_id(GoodsLevelId) of
			{do, [GoodsLevelA, GoodsLevelB]} ->%%限制等级范围
				lists:partition(fun(LevelElem) ->
										GoodsLevelA =< LevelElem#ets_buy_goods.glv andalso LevelElem#ets_buy_goods.glv =< GoodsLevelB
								end, ColorCareerGoods);
			{undo, [_GA, _GB]} ->%%不限等级
				{ColorCareerGoods, []}
		end,
	%%类型判断（内嵌子类型）
	if 
		Type =/= 0 orelse (length(SubTypeList) =/= 0) ->
			{SubTypeGoods, _NoSubTypeGoods} = 
				lists:partition(fun(Elem) -> 
										IsSubType = lists:member(Elem#ets_buy_goods.gsubtype, SubTypeList),
										IsSubType andalso (Elem#ets_buy_goods.gtype == Type)
								end, LevelGoods);
		true  ->
			SubTypeGoods = LevelGoods
	end,
	%%名字判断
	LenGoodsName = length(GoodsName),
	case LenGoodsName of
		0 ->
			PartitionGoods = SubTypeGoods;
		_ ->
			{PartitionGoods, _NonPartitionGoods} = 
				lists:partition(fun(X) ->
%% 										X#ets_sale_goods.goods_name == tool:to_binary(GoodsName)
										case re:run(X#ets_buy_goods.gname, tool:to_binary(GoodsName), [caseless]) of
											nomatch ->
												false;
											_ ->
												true
										end
								end, SubTypeGoods)
	end,
	PartitionGoods.

%%按时间排一次序，拍卖越晚的越靠前
sort_buy_from_time(GoodsRecordsAll) ->
	lists:sort(fun(A,B) ->
					   TA = A#ets_buy_goods.buy_time,
					   TB = B#ets_buy_goods.buy_time,
					   TA >= TB
			   end, GoodsRecordsAll).

%%按照价格排序（降序）
sort_goods_by_price_desc(Goods1, Goods2) ->
	case Goods1#ets_buy_goods.price_type > Goods2#ets_buy_goods.price_type of
		true ->
			true;
		false ->
			case Goods1#ets_buy_goods.price_type =:= Goods2#ets_buy_goods.price_type of
				true ->
					Goods1#ets_buy_goods.price >= Goods2#ets_buy_goods.price;
				false ->
					false
		end
	end.
%%按照价格排序（升序）
sort_goods_by_price_asc(Goods1, Goods2) ->
   	case Goods1#ets_buy_goods.price_type < Goods2#ets_buy_goods.price_type of
		true ->
			true;
		false ->
			case Goods1#ets_buy_goods.price_type =:= Goods2#ets_buy_goods.price_type of
				true ->
					Goods1#ets_buy_goods.price =< Goods2#ets_buy_goods.price;
				false ->
					false
		end
	end.
%%单价按照升序排序
sort_goods_by_unprice_asc(Goods1, Goods2) ->
   	case Goods1#ets_buy_goods.price_type < Goods2#ets_buy_goods.price_type of
		true ->
			true;
		false ->
			case Goods1#ets_buy_goods.price_type =:= Goods2#ets_buy_goods.price_type of
				true ->
					Goods1#ets_buy_goods.unprice =< Goods2#ets_buy_goods.unprice;
				false ->
					false
		end
	end.
%%单价按照降序排序			
sort_goods_by_unprice_desc(Goods1, Goods2) ->
	case Goods1#ets_buy_goods.price_type > Goods2#ets_buy_goods.price_type of
		true ->
			true;
		false ->
			case Goods1#ets_buy_goods.price_type =:= Goods2#ets_buy_goods.price_type of
				true ->
					Goods1#ets_buy_goods.unprice >= Goods2#ets_buy_goods.unprice;
				false ->
					false
		end
	end.

%% -----------------------------------------------------------------
%% 17007 获取物品详细信息(仅在市场拍卖模块用)
%% -----------------------------------------------------------------
get_buygoods_info(MarketType, PidSend, GoodsLists) ->
	BuyGoodsList = lists:map(fun handle_get_buygoods_info/1, GoodsLists),
	{ok, BinData} = pt_17:write(17007, [MarketType, BuyGoodsList]),
	lib_send:send_to_sid(PidSend, BinData).

handle_get_buygoods_info(Record) ->
	{BuyId, _GId} = Record,
	case ets_lookup_buy_goods(BuyId) of
		[] ->
			{{}, 0, []};
		[BuyGoods|_] ->
			#ets_buy_goods{gid = Gid,
						   gstren = _GStren,
						   gattr = Nth} = BuyGoods,
			GoodsBaseInfo = goods_util:get_goods_type(Gid),
			case is_record(GoodsBaseInfo, ets_base_goods) of
				true ->
					GoodsInfo = goods_util:get_new_goods(GoodsBaseInfo),
					NGoodsInfo = GoodsInfo#goods{id = BuyId},
					Attrs = data_buy_equipment:get(Gid),
					GAttrs =
						case length(Attrs) < Nth orelse Nth =< 0 of
							true ->
								[];
							false ->
								lists:nth(Nth, Attrs)
						end,
					GoodsAttributes = 
						lists:foldl(fun make_buy_goods_attributes/2, [], GAttrs),
%% 					?DEBUG("GoodsAttributes:~p", [GoodsAttributes]),
					{NGoodsInfo, 0, GoodsAttributes};
				false ->
					{{}, 0, []}
			end
	end.

%%构造求购物品的附加属性
make_buy_goods_attributes(Elem, AccIn) ->
	{Key, Value} = Elem,
	case Key of
		15 -> %%力量
			NAttr = 
				#goods_attribute{attribute_type = 1,
								 status = 1,
								 attribute_id = Key,
								 forza = Value},
			[NAttr|AccIn];
		16 -> %%敏捷
			NAttr = 
				#goods_attribute{attribute_type = 1,
								 status = 1,
								 attribute_id = Key,
								 agile = Value},
			[NAttr|AccIn];
		17 -> %%智力
			NAttr = 
				#goods_attribute{attribute_type = 1,
								 status = 1,
								 attribute_id = Key,
								 wit = Value},
			[NAttr|AccIn];
		9  -> %%体质
			NAttr = 
				#goods_attribute{attribute_type = 1,
								 status = 1,
								 attribute_id = Key,
								 physique = Value},
			[NAttr|AccIn];
		7  -> %%暴击
			NAttr = 
				#goods_attribute{attribute_type = 1,
								 status = 1,
								 attribute_id = Key,
								 crit = Value},
			[NAttr|AccIn];
		6  -> %%闪躲
			NAttr = 
				#goods_attribute{attribute_type = 1,
								 status = 1,
								 attribute_id = Key,
								 dodge = Value},
			[NAttr|AccIn];
		10 -> %%风抗
			NAttr = 
				#goods_attribute{attribute_type = 1,
								 status = 1,
								 attribute_id = Key,
								 anti_wind = Value},
			[NAttr|AccIn];
		13 -> %%雷抗
			NAttr = 
				#goods_attribute{attribute_type = 1,
								 status = 1,
								 attribute_id = Key,
								 anti_thunder = Value},
			[NAttr|AccIn];
		12 -> %%水抗
			NAttr = 
				#goods_attribute{attribute_type = 1,
								 status = 1,
								 attribute_id = Key,
								 anti_water = Value},
			[NAttr|AccIn];
		11 -> %%火抗
			NAttr = 
				#goods_attribute{attribute_type = 1,
								 status = 1,
								 attribute_id = Key,
								 anti_fire = Value},
			[NAttr|AccIn];
		14 -> %%土抗
			NAttr = 
				#goods_attribute{attribute_type = 1,
								 status = 1,
								 attribute_id = Key,
								 anti_soil = Value},
			[NAttr|AccIn];
		1  -> %%气血
			NAttr = 
				#goods_attribute{attribute_type = 1,
								 status = 1,
								 attribute_id = Key,
								 hp = Value},
			[NAttr|AccIn];
		2  -> %%法力
			NAttr = 
				#goods_attribute{attribute_type = 1,
								 status = 1,
								 attribute_id = Key,
								 mp = Value},
			[NAttr|AccIn];
		_ ->
			AccIn
	end.


%% -----------------------------------------------------------------
%% 17008 获取物品属性信息
%% -----------------------------------------------------------------
get_buy_goods_attributes(GoodsId, PidSend) ->
	{_Type,Result,_Param, _IsStren, _IsEquip} = get_goods_attributes(GoodsId),
	{ok, BinData17008} = pt_17:write(17008, [Result]),
	lib_send:send_to_sid(PidSend, BinData17008).

get_goods_attributes(GoodsId) ->
	GoodsBaseInfo = goods_util:get_goods_type(GoodsId),
	if
		is_record(GoodsBaseInfo, ets_base_goods) =:= false ->
			{no_goods, [], {}, true, false};
		GoodsBaseInfo#ets_base_goods.type =:= 10 ->
			 Attrs = data_buy_equipment:get(GoodsId),
			 #ets_base_goods{type = GType,
							 subtype = GSubType,
							 career = GCareer,
							 level = Glv,
							 goods_name = GName,
							 color = GColor} = GoodsBaseInfo,
			 CheckStren = check_goods_stren(GoodsBaseInfo),
			 {ok, Attrs,{GName,GType,GSubType,GCareer,Glv,GColor}, CheckStren, true};
		true ->
			#ets_base_goods{type = GType,
							subtype = GSubType,
							career = GCareer,
							level = Glv,
							goods_name = GName,
							color = GColor} = GoodsBaseInfo,
			CheckStren = check_goods_stren(GoodsBaseInfo),
			{ok, [], {GName,GType,GSubType,GCareer,Glv,GColor}, CheckStren, false}
	end.
			 

%%true ->不可强化，false ->可以强化
check_goods_stren(GoodsBaseInfo) ->
	GoodsBaseInfo#ets_base_goods.subtype =:= 20 orelse 
									 GoodsBaseInfo#ets_base_goods.subtype =:= 21 orelse 
																	  GoodsBaseInfo#ets_base_goods.subtype =:= 25.


%% %%遍历整个数组的二元元素
%% perms([], Result) ->
%% 	Result;
%% perms([Elem|Rest], Result) ->
%% 	List = perms_inside(Elem, Rest, []),
%% 	perms(Rest, lists:append([List, Result])).
%% perms_inside(_Elem, [], Result) ->
%% 	Result;
%% perms_inside(Elem, [R|Rest], Result) ->
%% 	perms_inside(Elem, Rest, [[Elem, R]|Result]).
	
%% -----------------------------------------------------------------
%% 17009 求购物品请求
%% -----------------------------------------------------------------
buy_goods_request(Status, GoodsId, Stren, PType, Num, UnPrice, BuyTime, Key, Param) ->
	#player{id = Pid,
			nickname = PName} = Status,
	%%即时获取玩家的铜币数量！
	[Coin, _GBCoin] = db_agent:query_player_coin(Pid),
	[Gold, _Cash] = db_agent:query_player_money(Pid),
	{GName,GType,GSubType,GCareer,Glv,GColor} = Param,
	case PType of%%求购货币类型
		2 ->%%元宝
			%%计算保管费
			[DeductRadix] = lib_sale:get_deduct_by_goods({PType, BuyTime}),
			%%保管费用向上取整
			DeductPriceServ = tool:ceil(UnPrice * Num * DeductRadix),
			NeedPrice = tool:ceil(UnPrice * Num),
			if
				Coin =< 0 orelse Coin < DeductPriceServ ->%%保管费不够
					{2, Status};
				UnPrice =< 0 -> %%价格不能为零
					{9, Status};
				Gold =< 0 orelse Gold < NeedPrice ->%%求购的钱不够
					{6, Status};
				true ->
					GoodsBaseInfo = goods_util:get_goods_type(GoodsId),
					if
						%%信息错误
						is_record(GoodsBaseInfo, ets_base_goods) =:= false ->
%% 							?DEBUG("no goods:~p", [10]),
							{10, Status};
						GoodsBaseInfo#ets_base_goods.bind =:= 2 %%绑定
						  orelse GoodsBaseInfo#ets_base_goods.trade =:= 1 %%不可交易
						  orelse GoodsBaseInfo#ets_base_goods.isdrop =:= 1 -> %%不可丢弃
							{12, Status};
						%%数量出错 了
						GoodsBaseInfo#ets_base_goods.max_overlap =:= 0 andalso Num =/= 1 ->
%% 							?DEBUG("111 MaxOverLap:~p, Num:~p", [GoodsBaseInfo#ets_base_goods.max_overlap, Num]),
							{11, Status};
						GoodsBaseInfo#ets_base_goods.max_overlap > 0 andalso (GoodsBaseInfo#ets_base_goods.max_overlap < Num orelse Num =< 0) ->
%% 							?DEBUG("222 MaxOverLap:~p, Num:~p", [GoodsBaseInfo#ets_base_goods.max_overlap, Num]),
							{11, Status};
						true ->
							NowTime = util:unixtime(),
							FieldList = [pid, pname, buy_type, gid, gname, gtype, gsubtype, num, career, glv, gcolor, gstren, gattr, unprice, price_type, continue, buy_time],
							ValueList = [Pid, PName, 1, GoodsId, GName, GType, GSubType, Num, GCareer, Glv, GColor, Stren, Key, UnPrice, PType, BuyTime, NowTime],
							%%插入记录
							Ret = db_agent:insert_buy_goods(FieldList, ValueList),
							BuyGoods = 
								#ets_buy_goods{id = Ret,
											   price = NeedPrice,                              %% 求购的物品能给出的价格	
											   pid = Pid,                                %% 玩家ID
											   pname = PName,                             %% 玩家名字	
											   buy_type = 1,                           %% 求购类型(1，实物；2，元宝或铜钱)	
											   gid = GoodsId,                                %% 求购的物品类型Id，当为元宝或者铜钱是，此值为0	
											   gname = GName,                             %% 求购的物品名字	
											   gtype = GType,                              %% 求购的物品类型，当为元宝或者铜钱是，此值为0	
											   gsubtype = GSubType,                           %% 求购的物品子类型，当为元宝或者铜钱是，此值为0	
											   num = Num,                                %% 求购数量	
											   career = GCareer,                             %% 求购 的物品职业类型	
											   glv = Glv,                                %% 求购的物品等级，由base_goods表中的level决定	
											   gcolor = GColor,                            %% 求购的物品颜色，0 白色，1 绿色，2 蓝色，3 金色，4 紫色; 99 为不限	
											   gstren = Stren,                             %% 求购物品要求的最小强化等级	
											   gattr = Key,                             %% 求购的物品要求的对应的额外属性	
											   unprice = UnPrice,                            %% 求购的物品能给出的单价	
											   price_type = PType,                         %% 求购的物品价格类型：2铜钱，1元宝
											   continue = BuyTime,                          %% 求购的持续时间：6小时，12小时，24小时	
											   buy_time = NowTime                            %% 求购信息发布的时间	
											  },
							ets_update_buy_goods(BuyGoods),
							%%扣钱开始
							%%扣报保管费,同时扣除拍卖的元宝
							GoldStatus = lib_goods:cost_money(Status, NeedPrice, gold, 1709),
							CoinPlayer = lib_goods:cost_money(GoldStatus, DeductPriceServ, coinonly, 1709),
							%%此处将要加日志
							%%写入求购日志
							LogBuyGoods = 
								#log_buy_goods{buyid = Ret,
											   buy_type = 1,
											   bid = Pid,
											   bname = PName,
											   goodsid = GoodsId,
											   num = Num,
											   ptype = PType,
											   unprice = UnPrice,
											   f_type = 1,
											   f_time = NowTime,
											   continue = BuyTime},
							erlang:spawn(fun() -> db_agent:insert_log_buy_goods(LogBuyGoods) end),
							{1, CoinPlayer}
					end
			end;
		1 ->%%铜币
			%%计算保管费
			[DeductRadix] = lib_sale:get_deduct_by_goods({PType, BuyTime}),
			%%保管费用向上取整
			DeductPriceServ = tool:ceil(UnPrice * Num * DeductRadix),
			NeedPrice = tool:ceil(UnPrice * Num),
			NeedAll = tool:ceil(NeedPrice + DeductPriceServ),
			if
				Coin =< 0 orelse Coin < DeductPriceServ ->%%保管费不够
					{2, Status};
				Coin =< 0 orelse Coin < NeedAll ->%%求购的钱不够
					{7, Status};
				true ->
					GoodsBaseInfo = goods_util:get_goods_type(GoodsId),
					if
						%%信息错误
						is_record(GoodsBaseInfo, ets_base_goods) =:= false ->
							{10, Status};
						GoodsBaseInfo#ets_base_goods.bind =:= 2 %%绑定
						  orelse GoodsBaseInfo#ets_base_goods.trade =:= 1 %%不可交易
						  orelse GoodsBaseInfo#ets_base_goods.isdrop =:= 1 -> %%不可丢弃
							{12, Status};
						%%数量出错 了
						GoodsBaseInfo#ets_base_goods.max_overlap =:= 0 andalso Num =/= 1 ->
%% 							?DEBUG("3333 MaxOverLap:~p, Num:~p", [GoodsBaseInfo#ets_base_goods.max_overlap, Num]),
							{11, Status};
						GoodsBaseInfo#ets_base_goods.max_overlap > 0 andalso (GoodsBaseInfo#ets_base_goods.max_overlap < Num orelse Num =< 0) ->
%% 							?DEBUG("4444 MaxOverLap:~p, Num:~p", [GoodsBaseInfo#ets_base_goods.max_overlap, Num]),
							{11, Status};
						true ->
							NowTime = util:unixtime(),
							FieldList = [pid, pname, buy_type, gid, gname, gtype, gsubtype, num, career, glv, gcolor, gstren, gattr, unprice, price_type, continue, buy_time],
							ValueList = [Pid, PName, 1, GoodsId, GName, GType, GSubType, Num, GCareer, Glv, GColor, Stren, Key, UnPrice, PType, BuyTime, NowTime],
							%%插入记录
							Ret = db_agent:insert_buy_goods(FieldList, ValueList),
							BuyGoods = 
								#ets_buy_goods{id = Ret,
											   price = NeedPrice,                              %% 求购的物品能给出的价格	
											   pid = Pid,                                %% 玩家ID
											   pname = PName,                             %% 玩家名字	
											   buy_type = 1,                           %% 求购类型(1，实物；2，元宝或铜钱)	
											   gid = GoodsId,                                %% 求购的物品类型Id，当为元宝或者铜钱是，此值为0	
											   gname = GName,                             %% 求购的物品名字	
											   gtype = GType,                              %% 求购的物品类型，当为元宝或者铜钱是，此值为0	
											   gsubtype = GSubType,                           %% 求购的物品子类型，当为元宝或者铜钱是，此值为0	
											   num = Num,                                %% 求购数量	
											   career = GCareer,                             %% 求购 的物品职业类型	
											   glv = Glv,                                %% 求购的物品等级，由base_goods表中的level决定	
											   gcolor = GColor,                            %% 求购的物品颜色，0 白色，1 绿色，2 蓝色，3 金色，4 紫色; 99 为不限	
											   gstren = Stren,                             %% 求购物品要求的最小强化等级	
											   gattr = Key,                             %% 求购的物品要求的对应的额外属性	
											   unprice = UnPrice,                            %% 求购的物品能给出的单价	
											   price_type = PType,                         %% 求购的物品价格类型：2铜钱，1元宝
											   continue = BuyTime,                          %% 求购的持续时间：6小时，12小时，24小时	
											   buy_time = NowTime                            %% 求购信息发布的时间	
											  },
							ets_update_buy_goods(BuyGoods),
							%%扣钱开始
							%%扣报保管费,同时扣除拍卖的元宝
							CoinPlayer = lib_goods:cost_money(Status, NeedAll, coinonly, 1709),
							%%此处将要加日志
							%%写入求购日志
							LogBuyGoods = 
								#log_buy_goods{buyid = Ret,
											   buy_type = 1,
											   bid = Pid,
											   bname = PName,
											   goodsid = GoodsId,
											   num = Num,
											   ptype = PType,
											   unprice = UnPrice,
											   f_type = 1,
											   f_time = NowTime,
											   continue = BuyTime},
							erlang:spawn(fun() -> db_agent:insert_log_buy_goods(LogBuyGoods) end),
							{1, CoinPlayer}
					end
			end;
		_ ->%%乱发数据
			{4, Status}
	end.


check_attributes(GALists, Key) ->
	Len = length(GALists),
	if
		Key =< 0 ->%%没属性？错了
			{fail, []};
		Key > Len ->%%有问题了，那个key
			{fail, []};
		true ->
			List = lists:nth(Key, GALists),
			{ok, List}
	end.

%% -----------------------------------------------------------------
%% 17010 开始求购元宝或铜币
%% -----------------------------------------------------------------
buy_cash_request(Status, Num, PType, UnPrice, BuyTime) ->
	#player{id = Pid,
			nickname = PName} = Status,
	%%即时获取玩家的铜币数量！
	[Coin, _GBCoin] = db_agent:query_player_coin(Pid),
	[Gold, _Cash] = db_agent:query_player_money(Pid),
	case PType of
		2 ->%%价格是元宝，求购的是铜币哇
			%%计算保管费
			[DeductRadix] = lib_sale:get_deduct_by_goods({2, BuyTime}),
			%%保管费用向上取整
			DeductPriceServ = tool:ceil(UnPrice * DeductRadix),
			if
				Coin =< 0 orelse Coin < DeductPriceServ ->%%保管费不够
					{2, Status};
				UnPrice =< 0 ->%%价格不能为零
					{8, Status};
				Gold =< 0 orelse Gold < UnPrice ->%%求购的钱不够
					{6, Status};
				Num =< 0 ->%%求购的数量有问题
					{10, Status};
				true ->
					NowTime = util:unixtime(),
					FieldList = [pid, pname, buy_type, gid, gname, gtype, gsubtype, num, career, glv, gcolor, gstren, gattr, unprice, price_type, continue, buy_time],
					ValueList = [Pid, PName, 2, 1, "铜币", 0, 10, Num, 99, 0, 0, 0, 0, UnPrice, PType, BuyTime, NowTime],
					%%插入记录
					Ret = db_agent:insert_buy_goods(FieldList, ValueList),
					BuyGoods = 
						#ets_buy_goods{id = Ret,
									   price = UnPrice,                              %% 求购的物品能给出的价格	
									   pid = Pid,                                %% 玩家ID
									   pname = PName,                             %% 玩家名字	
									   buy_type = 2,                           %% 求购类型(1，实物；2，元宝或铜钱)	
									   gid = 1,                                %% 求购的物品类型Id，当为元宝或者铜钱是，此值为0	
									   gname = "铜币",                             %% 求购的物品名字	
									   gtype = 0,                              %% 求购的物品类型，当为元宝或者铜钱是，此值为0	
									   gsubtype = 10,                           %% 求购的物品子类型，当为元宝或者铜钱是，此值为0	
									   num = Num,                                %% 求购数量	
									   career = 99,                             %% 求购 的物品职业类型	
									   glv = 0,                                %% 求购的物品等级，由base_goods表中的level决定	
									   gcolor = 0,                            %% 求购的物品颜色，0 白色，1 绿色，2 蓝色，3 金色，4 紫色; 99 为不限	
									   gstren = 0,                             %% 求购物品要求的最小强化等级	
									   gattr = 0,                             %% 求购的物品要求的对应的额外属性	
									   unprice = UnPrice,                            %% 求购的物品能给出的单价	
									   price_type = PType,                         %% 求购的物品价格类型：2铜钱，1元宝	
									   continue = BuyTime,                          %% 求购的持续时间：6小时，12小时，24小时	
									   buy_time = NowTime                            %% 求购信息发布的时间	
									  },
					ets_update_buy_goods(BuyGoods),
					%%扣钱开始
					%%扣报保管费,同时扣除拍卖的元宝
%% 					?DEBUG("NeedCoin:~p, NeedGold:~p", [DeductPriceServ, UnPrice]),
					GoldStatus = lib_goods:cost_money(Status, UnPrice, gold, 1710),
					CoinPlayer = lib_goods:cost_money(GoldStatus, DeductPriceServ, coinonly, 1710),
					%%此处将要加日志
					%%写入求购日志
					LogBuyGoods = 
						#log_buy_goods{buyid = Ret,
									   buy_type = 2,
									   bid = Pid,
									   bname = PName,
									   num = Num,
									   ptype = PType,
									   goodsid = 1,
									   unprice = UnPrice,
									   f_type = 1,
									   f_time = NowTime,
									   continue = BuyTime},
					erlang:spawn(fun() -> db_agent:insert_log_buy_goods(LogBuyGoods) end),
					{1, CoinPlayer}
			end;
		1 ->%%价格是铜币，求购的是元宝
			%%计算保管费
			[DeductRadix] = lib_sale:get_deduct_by_goods({1, BuyTime}),
			%%保管费用向上取整
			DeductPriceServ = tool:ceil(UnPrice * DeductRadix),
			NeedAll = tool:ceil(UnPrice + DeductPriceServ),
			if
				Coin =< 0 orelse Coin < DeductPriceServ ->%%保管费不够
					{2, Status};
				UnPrice =< 0 ->%%价格不能为零
					{8, Status};
				Gold < 0 ->%%元宝数量出错了吧
					{5, Status};
				Coin =< 0 orelse Coin < NeedAll ->%%求购的钱不够
					{6, Status};
				Num =< 0 ->%%求购的数量有问题
					{10, Status};
				true ->
					NowTime = util:unixtime(),
					AListStr = util:term_to_string([]),
					FieldList = [pid, pname, buy_type, gid, gname, gtype, gsubtype, num, career, glv, gcolor, gstren, gattr, unprice, price_type, continue, buy_time],
					ValueList = [Pid, PName, 2, 2, "元宝", 0, 11, Num, 99, 0, 0, 0, AListStr, UnPrice, PType, BuyTime, NowTime],
					%%插入记录
					Ret = db_agent:insert_buy_goods(FieldList, ValueList),
					BuyGoods = 
						#ets_buy_goods{id = Ret,
									   price = UnPrice,                              %% 求购的物品能给出的价格	
									   pid = Pid,                                %% 玩家ID
									   pname = PName,                             %% 玩家名字	
									   buy_type = 2,                           %% 求购类型(1，实物；2，元宝或铜钱)	
									   gid = 2,                                %% 求购的物品类型Id，当为元宝或者铜钱是，此值为0	
									   gname = "元宝",                             %% 求购的物品名字	
									   gtype = 0,                              %% 求购的物品类型，当为元宝或者铜钱是，此值为0	
									   gsubtype = 11,                           %% 求购的物品子类型，当为元宝或者铜钱是，此值为0	
									   num = Num,                                %% 求购数量	
									   career = 99,                             %% 求购 的物品职业类型	
									   glv = 0,                                %% 求购的物品等级，由base_goods表中的level决定	
									   gcolor = 0,                            %% 求购的物品颜色，0 白色，1 绿色，2 蓝色，3 金色，4 紫色; 99 为不限	
									   gstren = 0,                             %% 求购物品要求的最小强化等级	
									   gattr = [],                             %% 求购的物品要求的对应的额外属性	
									   unprice = UnPrice,                            %% 求购的物品能给出的单价	
									   price_type = PType,                         %% 求购的物品价格类型：2铜钱，1元宝
									   continue = BuyTime,                          %% 求购的持续时间：6小时，12小时，24小时	
									   buy_time = NowTime                            %% 求购信息发布的时间	
									  },
					ets_update_buy_goods(BuyGoods),
					%%扣钱开始
					%%扣报保管费,同时扣除拍卖的元宝
%% 					?DEBUG("NeedCoin:~p", [NeedAll]),
					CoinPlayer = lib_goods:cost_money(Status, NeedAll, coinonly, 1710),
					%%此处将要加日志
					%%写入求购日志
					LogBuyGoods = 
						#log_buy_goods{buyid = Ret,
									   buy_type = 2,
									   bid = Pid,
									   bname = PName,
									   num = Num,
									   ptype = PType,
									   goodsid = 2,
									   unprice = UnPrice,
									   f_type = 1,
									   f_time = NowTime,
									   continue = BuyTime},
					erlang:spawn(fun() -> db_agent:insert_log_buy_goods(LogBuyGoods) end),
					{1, CoinPlayer}
			end
	end.
	

%% -----------------------------------------------------------------
%% 17011 出卖对应求购物品请求(除了装备)
%% -----------------------------------------------------------------
submit_buy_goods(Status, BuyId, SellNum) ->
	#player{id = Pid,
			nickname = BuyName} = Status,
	case ets_lookup_buy_goods(BuyId) of
		[] ->
			{2, Status};
		[BuyGoods|_] ->
			#ets_buy_goods{pid = SellerId,
						   buy_type = BuyType,
						   pname = SellerName,
						   gid = GoodsId,
						   gname = GName,
						   num = Num,
						   unprice = UnPrice,
						   price_type = PType,
						   gtype = GType,
						   continue = Continue
						  } = BuyGoods,
			case SellerId =:= Pid of
				true ->
					{4, Status};
				false ->
					NowTime = util:unixtime(),
					case BuyType of
						1 ->%%求购的是物品
							if
								GoodsId =< 0 ->%%物品有问题
									{3, Status};
								SellNum =< 0 ->%%数量为零？
									{9, Status};
								SellNum > Num ->%%给的也太多了吧
									{9, Status};
								GType =:= 10 ->%%装备类不能用这里卖
									{10, Status};
								true ->
									case catch (gen_server:call(Status#player.other#player_other.pid_goods, 
																{'buy_goods_sendmail', GoodsId, UnPrice, PType, SellNum, SellerName})) of 
										ok ->
											%%计算卖出的数量
											Price = tool:floor(UnPrice * SellNum),
											%%邮件通知(给予买家){SellNum, Price, PType,GName}
											ParamBuy = {SellNum, Price, PType, GName},
											erlang:spawn(fun() -> sendmail_for_buy(BuyName, sell_goods_succeed, ParamBuy) end),
											case Num > SellNum of
												true ->%%还有一些未扣完的
													NewNum = Num - SellNum,
													%%更新ets
													NBuyGoods = BuyGoods#ets_buy_goods{num = NewNum},
													ets_update_buy_goods(NBuyGoods),
													%%修改数据库
													ValueList = [{num, NewNum}],
													WhereList = [{id, BuyId}],
													db_agent:update_buy_goods(WhereList, ValueList),
													%%写入求购日志
													LogBuyGoods = 
														#log_buy_goods{buyid = BuyId,
																	   buy_type = BuyType,
																	   sid = Pid,
																	   sname = BuyName,
																	   bid = SellerId,
																	   bname = SellerName,
																	   num = Num,
																	   snum = SellNum,
																	   goodsid = GoodsId,
																	   ptype = PType,
																	   unprice = UnPrice,
																	   f_type = 2,
																	   f_time = NowTime,
																	   continue = Continue},
													erlang:spawn(fun() -> db_agent:insert_log_buy_goods(LogBuyGoods) end);
												false ->%%直接删掉
													%%更新拍卖纪录
													%%在ets_buy_goods删除记录
													ets_delete_buy_goods_by_id(BuyId),
													WhereList = [{id, BuyId}],
													spawn(fun()->db_agent:delete_buy_goods_record(WhereList) end),
													%%写入求购日志
													LogBuyGoods = 
														#log_buy_goods{buyid = BuyId,
																	   buy_type = BuyType,
																	   sid = Pid,
																	   sname = BuyName,
																	   bid = SellerId,
																	   bname = SellerName,
																	   num = Num,
																	   snum = Num,
																	   goodsid = GoodsId,
																	   ptype = PType,
																	   unprice = UnPrice,
																	   f_type = 2,
																	   f_time = NowTime,
																	   continue = Continue},
													erlang:spawn(fun() -> db_agent:insert_log_buy_goods(LogBuyGoods) end)
											end,	
											{1, Status};
										no_goods ->
											{3, Status};
										no_num ->
											{11, Status};
										_otherError ->
											{0,Status}
									end
							end;
						2 ->%%求购的是元宝或者铜币
							case PType of
								2 ->%%需要给予铜币，将会得到元宝
									%%即时获取玩家的铜币元宝数量！
									[Coin, _GBCoin] = db_agent:query_player_coin(Pid),
									[Gold, _Cash] = db_agent:query_player_money(Pid),
									if
										Coin =< 0 orelse Coin < Num ->
											{6, Status};
										Gold < 0 ->%%元宝居然出现负数
											{8, Status};
										true ->
											%%开始扣钱
											CoinPlayer = lib_goods:cost_money(Status, Num, coinonly, 1711),
											%%邮件通知(给予买家){Coin, Gold, PType}
											ParamBuy = {Num, UnPrice, PType},
											erlang:spawn(fun() -> sendmail_for_buy(BuyName, sell_gc_succeed, ParamBuy) end),
											%%邮件通知(给予求购者){Coin, Gold, PType}
											ParamSell = {Num, UnPrice, PType},
											erlang:spawn(fun() -> sendmail_for_buy(SellerName, buy_gc_succeed, ParamSell) end),
											%%更新拍卖纪录
											%%在ets_buy_goods删除记录
											ets_delete_buy_goods_by_id(BuyId),
											WhereList = [{id, BuyId}],
											spawn(fun()->db_agent:delete_buy_goods_record(WhereList) end),
											%%写入求购日志
											LogBuyGoods = 
												#log_buy_goods{buyid = BuyId,
															   buy_type = BuyType,
															   sid = Pid,
															   sname = BuyName,
															   bid = SellerId,
															   bname = SellerName,
															   num = Num,
															   snum = Num,
															   ptype = PType,
															   unprice = UnPrice,
															   f_type = 2,
															   f_time = NowTime,
															   continue = Continue},
											erlang:spawn(fun() -> db_agent:insert_log_buy_goods(LogBuyGoods) end),
											{1, CoinPlayer}
									end;
								1 ->
									%%即时获取玩家的铜币元宝数量！
									[Coin, _GBCoin] = db_agent:query_player_coin(Pid),
									[Gold, _Cash] = db_agent:query_player_money(Pid),
									if
										Gold =< 0 orelse Gold < Num ->
											{6, Status};
										Coin < 0 ->%%元宝居然出现负数
											{8, Status};
										true ->
											%%开始扣钱
											GoldPlayer = lib_goods:cost_money(Status, Num, gold, 1711),
											%%邮件通知(给予买家){Coin, Gold, PType}
											ParamBuy = {UnPrice, Num, PType},
											erlang:spawn(fun() -> sendmail_for_buy(BuyName, sell_gc_succeed, ParamBuy) end),
											%%邮件通知(给予求购者){Name, Coin, Gold, PType}
											ParamSell = {UnPrice, Num, PType},
											erlang:spawn(fun() -> sendmail_for_buy(SellerName, buy_gc_succeed, ParamSell) end),
											%%更新拍卖纪录
											%%在ets_buy_goods删除记录
											ets_delete_buy_goods_by_id(BuyId),
											WhereList = [{id, BuyId}],
											spawn(fun()->db_agent:delete_buy_goods_record(WhereList) end),
											%%写入求购日志
											LogBuyGoods = 
												#log_buy_goods{buyid = BuyId,
															   buy_type = BuyType,
															   sid = Pid,
															   sname = BuyName,
															   bid = SellerId,
															   bname = SellerName,
															   num = Num,
															   snum = Num,
															   ptype = PType,
															   unprice = UnPrice,
															   f_type = 2,
															   f_time = NowTime,
															   continue = Continue},
											erlang:spawn(fun() -> db_agent:insert_log_buy_goods(LogBuyGoods) end),
											{1, GoldPlayer}
									end
							end
					end
			end
	end.
											
	
buy_goods_sendmail(GoodsBaseInfo, UnPrice, PType, SellNum, GoodsStatus, SellerName) ->
	#ets_base_goods{goods_id = GoodsId,
					type = GType,
					goods_name = GName} = GoodsBaseInfo,
	#goods_status{player_id = Pid} = GoodsStatus,
	case GType of
		10 ->%%装备类的物品
			{no_goods, GoodsStatus};	
		_OtherType ->%%其他类的物品，直接删除和发物品
			NeedGoods = goods_util:get_type_goods_list(Pid, GoodsId, 0, 4),
			TotalNum = goods_util:get_goods_totalnum(NeedGoods),
			if
				length(NeedGoods) =:= 0 ->
					{no_goods, GoodsStatus};
				TotalNum < SellNum ->
					{no_num, GoodsStatus};
				true ->
					 case (catch lib_goods:delete_more(GoodsStatus, NeedGoods, SellNum)) of
						 {ok, NewStatus} ->
							 lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
							 %%邮件通知(给予求购者){GName, SellNum, UnPrice, PType, GoodsId}
							 ParamSell = {GName, SellNum, UnPrice, PType, GoodsId},
							 erlang:spawn(fun() -> sendmail_for_buy(SellerName, buy_goods_succeed, ParamSell) end),
							 {ok, NewStatus};	%% 成功
						 Error ->
							 ?ERROR_MSG("mod_goods delete_more:~p", [Error]),
							 {fail, GoodsStatus}	%% 失败
					 end
			end
	end.										
						
%% -----------------------------------------------------------------
%% 17012 查看已求购物品
%% -----------------------------------------------------------------
list_buy_goods_self(Pid, PidSend) ->
	%%获取当前玩家的所有上架求购的列表
	Pattern = #ets_buy_goods{pid = Pid, _='_'},
	BuyGoods = ets_match_buy_goods(Pattern),
	%%对上架物品根据上架时间进行排序（越新上架越靠前）
	SortBuyGoods = sort_buy_from_time(BuyGoods),
	{ok, BinData17012} = pt_17:write(17012, [SortBuyGoods]),
	lib_send:send_to_sid(PidSend, BinData17012).

%% -----------------------------------------------------------------
%% 17013 取消求购物品
%% -----------------------------------------------------------------
cancel_buy_goods(BuyId, Pid, PName,PidSend) ->
	Result =
		case ets_lookup_buy_goods(BuyId) of
			[] ->%%记录已经没有了
				2;
			[BuyGoods|_] ->
				#ets_buy_goods{pid = SellerId} = BuyGoods,
				if
					SellerId =/= Pid ->%%压根不是本人的
						4;
					true ->
						#ets_buy_goods{price_type = PType,
									   unprice = UnPrice,
									   buy_type = BuyType,
									   num = Num,
									   pname = SellerName,
									   gid = GoodsId,
									   continue = Continue} = BuyGoods,
						case BuyType of
							1 ->%%求购的是物品，有数量的计算
								%%更新拍卖纪录
								%%在ets_buy_goods删除记录
								ets_delete_buy_goods_by_id(BuyId),
								WhereList = [{id, BuyId}],
								spawn(fun()->db_agent:delete_buy_goods_record(WhereList) end),		
								Price = tool:floor(Num * UnPrice),
								%%邮件通知(给予求购者){Price, PType}
								ParamSell = {Price, PType},
								erlang:spawn(fun() -> sendmail_for_buy(PName, cancel_buy_goods, ParamSell) end);
							2 ->%%求购的是元宝或者铜币，没有数量的计算
								%%在ets_buy_goods删除记录
								ets_delete_buy_goods_by_id(BuyId),
								WhereList = [{id, BuyId}],
								spawn(fun()->db_agent:delete_buy_goods_record(WhereList) end),	
								Price = UnPrice,
								%%邮件通知(给予求购者){Price, PType}
								ParamSell = {Price, PType},
								erlang:spawn(fun() -> sendmail_for_buy(PName, cancel_buy_goods, ParamSell) end)
						end,
						%%写入求购日志
						NowTime = util:unixtime(),
						LogBuyGoods = 
							#log_buy_goods{buyid = BuyId,
										   buy_type = BuyType,
										   sid = 0,
										   sname = "",
										   bid = Pid,
										   bname = SellerName,
										   num = Num,
										   snum = Num,
										   goodsid = GoodsId,
										   ptype = PType,
										   unprice = UnPrice,
										   f_type = 4,
										   f_time = NowTime,
										   continue = Continue},
						erlang:spawn(fun() -> db_agent:insert_log_buy_goods(LogBuyGoods) end),
						1
				end
		end,
	{ok, BinData17013} = pt_17:write(17013, [Result]),
	lib_send:send_to_sid(PidSend, BinData17013).
	
%% -----------------------------------------------------------------
%% 17014 出卖对应求购物品请求(装备类)
%% -----------------------------------------------------------------
submit_buy_goods_equip(Status, BuyId, Gid) ->
	#player{id = Pid,
			nickname = BuyName} = Status,
	case ets_lookup_buy_goods(BuyId) of
		[] ->
			2;
		[BuyGoods|_] ->
			#ets_buy_goods{pid = SellerId,
						   buy_type = BuyType,
						   pname = SellerName,
						   gid = GoodsId,
						   gname = GName,
						   num = SellNum,
						   unprice = UnPrice,
						   price_type = PType,
						   gtype = GType,
						   gattr = GAttrs,
						   gstren = Stren,
						   continue = Continue
						  } = BuyGoods,
			
			if%%是不是自己的呢
				SellerId =:= Pid ->
					4;
				%%不是装备的喔
				GType =/= 10 ->
					10;
				%%数据出错了
				SellNum =/= 1 ->
					0;
				BuyType =/= 
				true ->
					case catch (gen_server:call(Status#player.other#player_other.pid_goods, 
												{'buy_goods_equip_sendmail', Gid, Stren, GAttrs, GName, SellerName, 
												 GoodsId, UnPrice, PType})) of
						{ok, DGid} ->
							%%计算卖出的数量
							Price = tool:floor(UnPrice * SellNum),
							%%邮件通知(给予买家){SellNum, Price, PType,GName}
							ParamBuy = {SellNum, Price, PType, GName},
							erlang:spawn(fun() -> sendmail_for_buy(BuyName, sell_goods_succeed, ParamBuy) end),
							%%直接删掉,更新拍卖纪录
							%%在ets_buy_goods删除记录
							ets_delete_buy_goods_by_id(BuyId),
							WhereList = [{id, BuyId}],
							spawn(fun()->db_agent:delete_buy_goods_record(WhereList) end),
							NowTime = util:unixtime(),
							%%写入求购日志
							LogBuyGoods = 
								#log_buy_goods{buyid = BuyId,
											   buy_type = BuyType,
											   sid = Pid,
											   sname = BuyName,
											   bid = SellerId,
											   bname = SellerName,
											   num = SellNum,
											   snum = SellNum,
											   goodsid = GoodsId,
											   gid = DGid,
											   ptype = PType,
											   unprice = UnPrice,
											   f_type = 2,
											   f_time = NowTime,
											   continue = Continue},
							erlang:spawn(fun() -> db_agent:insert_log_buy_goods(LogBuyGoods) end),
							1;
						no_goods ->%%没有所需要的物品
							3;
						not_equip ->%%都不是装备
							11;
						no_stren ->%%强化等级不够
							12;
						not_location ->%%不在背包
							13;
						not_sell ->%%不可出售
							14;
						_ ->
							3
					end
			end
	end.

%% -----------------------------------------------------------------
%% 17006 热门搜索
%% -----------------------------------------------------------------
list_hot_goods(Types,Goods,SortType,StartNum,EndNum,_SearchType) ->		
	%%求购表过滤
	GoodsRecords = lists:flatten(get_hot_goods(Types,Goods)),
	%%按时间倒序一下，越 晚拍的，越靠前
	PartitionGoods = sort_buy_from_time(GoodsRecords),
	%%按照价格类型排序
	LenCheck = length(PartitionGoods),
	case LenCheck > 1 of
		true ->
			case SortType of
				0 ->%%默认的时候是不排序的
					SortPriceBuyGoods = PartitionGoods;
				1 ->%按照价格降序升序
					SortPriceBuyGoods = lists:sort(fun sort_goods_by_price_asc/2, PartitionGoods);
				2 ->%%%按照价格降序
					SortPriceBuyGoods = lists:sort(fun sort_goods_by_price_desc/2, PartitionGoods);
				3 ->%%单价按照升序排序
					SortPriceBuyGoods = lists:sort(fun sort_goods_by_unprice_asc/2, PartitionGoods);
				4 ->%%单价按照降序排序
					SortPriceBuyGoods = lists:sort(fun sort_goods_by_unprice_desc/2, PartitionGoods);
				_ ->%%直接过滤一些非法错误的操作
					SortPriceBuyGoods = PartitionGoods
			end;
		false ->
			SortPriceBuyGoods = PartitionGoods
	end,
	Len = length(SortPriceBuyGoods),
	if 
		Len == 0 ->
			[Len, 0, []];
		Len < StartNum ->
		  [Len, 0, []];
		true ->
			NewBuyGoodsList = lists:sublist(SortPriceBuyGoods, StartNum, EndNum),
			NewLen = length(NewBuyGoodsList),
			[Len, NewLen, NewBuyGoodsList]
	end.

%%ets数据
get_hot_goods(GoodsTypes,Gids) ->
	F_type = fun({Type,Sub},L) ->
					 Ms = ets:fun2ms(fun(E) when E#ets_buy_goods.gtype =:= Type andalso E#ets_buy_goods.gsubtype =:= Sub->E end),
					 case ets:select(?ETS_BUY_GOODS, Ms) of
						 [] ->
							 L;
						 Datas ->
							 [Datas|L]
					 end
			 end,
	Tsales = lists:foldl(F_type, [], GoodsTypes),
	F_goods = fun(Gid,L)->
					  Ms = ets:fun2ms(fun(E) when E#ets_buy_goods.gid =:= Gid -> E end),
					  case ets:select(?ETS_BUY_GOODS, Ms) of
						  []->
							  L;
						  Datas ->
							  [Datas|L]
					  end
			  end,
	TGoods = lists:foldl(F_goods, [], Gids),
	[TGoods|Tsales].

buy_goods_equip_sendmail(GoodsInfo, UnPrice, PType, GAttrs, GName, SellerName, GoodsStatus) ->
	NGAttris = data_buy_equipment:get(GoodsInfo#goods.goods_id),
	Len = length(NGAttris),
	if
		GAttrs > Len orelse GAttrs =< 0 ->
			{no_goods, GoodsStatus};
		true ->
			NAttributes = lists:nth(GAttrs, NGAttris),
			%%获取附加的属性
			AttributeList = goods_util:get_goods_attribute_list(GoodsStatus#goods_status.player_id, GoodsInfo#goods.id, 1),
			case check_goods_attris_need(AttributeList, NAttributes, ok) of
				ok ->
					NullCells = lists:sort([GoodsInfo#goods.cell|GoodsStatus#goods_status.null_cells]),
					NewStatus = GoodsStatus#goods_status{null_cells = NullCells},
					%%删除ets_goods_online的数据
					ets:delete(?ETS_GOODS_ONLINE, GoodsInfo#goods.id),
					ets:match_delete(?ETS_GOODS_ATTRIBUTE, #goods_attribute{gid=GoodsInfo#goods.id, _='_'}),
					%%更新玩家的物品表(把playerid置0)
					db_agent:buy_update_goods(GoodsInfo#goods.id),
					lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
					%%邮件通知(给予求购者){GName, SellNum, UnPrice, PType, GoodsId}
					ParamSell = {GName, 1, UnPrice, PType, GoodsInfo#goods.id, GoodsInfo#goods.goods_id},
					erlang:spawn(fun() -> sendmail_for_buy(SellerName, buy_goods_equip_succeed, ParamSell) end),
					{{ok,GoodsInfo#goods.id}, NewStatus};	%% 成功
				fail ->
					{no_goods, GoodsStatus}
			end
	end.

check_goods_attris_need(_AttributeList, [], Type) ->
	Type;
check_goods_attris_need(AttributeList, [Elem|Rest], Type) ->
	{AttId, _Value} = Elem,
	Check = 
		lists:any(fun(E) ->
						  E#goods_attribute.attribute_id =:= AttId
				  end, AttributeList),
	case Check of
		true ->%%居然有，那就判断下一个了
			check_goods_attris_need(AttributeList, Rest, Type);
		false ->%%只要有一个没有的，就是不合符要求的啦
			check_goods_attris_need(AttributeList, [], fail)
	end.
	
%% -----------------------------------------------------------------
%% 17015 物品的最大堆叠数
%% -----------------------------------------------------------------
get_buy_goods_maxoverlap(PidSend, GoodsId) ->
	GoodsBaseInfo = goods_util:get_goods_type(GoodsId),
	MaxOverLap = 
		case is_record(GoodsBaseInfo, ets_base_goods)of
			true ->
				GoodsBaseInfo#ets_base_goods.max_overlap;
			false ->
				0
		end,
	{ok, BinData17015} = pt_17:write(17015, [GoodsId, MaxOverLap]),
	lib_send:send_to_sid(PidSend, BinData17015).

%%
%% Local Functions
%%
%% 求购的db数据更新到ets中
db_into_ets_buy_good(BuyGoods) ->
	[Id,Pid,PName,BuyType,Gid,GName,GType,GSubtype,Num,Career,
	 GLv,GColor,GStren,GAttr,UnPrice,PriceType,Continue,BuyTime] = BuyGoods,
	Price = tool:ceil(UnPrice * Num),
	Ets = #ets_buy_goods{	
						 id = Id,                                     %% 求购Id(自增Id)	
						 pid = Pid,                                %% 玩家ID	
						 pname = PName,                             %% 玩家名字	
						 buy_type = BuyType,                           %% 求购类型(1，实物；2，元宝或铜钱)	
						 gid = Gid,                                %% 求购的物品类型Id，当为元宝或者铜钱是，此值为0	
						 gname = GName,                             %% 求购的物品名字	
						 gtype = GType,                              %% 求购的物品类型，当为元宝或者铜钱是，此值为0	
						 gsubtype = GSubtype,                           %% 求购的物品子类型，当为元宝或者铜钱是，此值为0	
						 num = Num,                                %% 求购数量	
						 career = Career,                             %% 求购 的物品职业类型	
						 glv = GLv,                                %% 求购的物品等级，由base_goods表中的level决定	
						 gcolor = GColor,                            %% 求购的物品颜色，0 白色，1 绿色，2 蓝色，3 金色，4 紫色; 99 为不限	
						 gstren = GStren,                             %% 求购物品要求的最小强化等级	
						 gattr = GAttr,                             %% 求购的物品要求的对应的额外属性	
						 price = Price,                              %% 求购的物品能给出的价格
						 unprice = UnPrice,							  %% 求购的物品单价
						 price_type = PriceType,                         %% 求购的物品价格类型：2铜钱，1元宝
						 continue = Continue,                          %% 求购的持续时间：6小时，12小时，24小时	
						 buy_time = BuyTime                            %% 求购信息发布的时间	
						},
	ets_update_buy_goods(Ets).

%% ============	ets操作	============
ets_update_buy_goods(BuyGoods) ->
	ets:insert(?ETS_BUY_GOODS, BuyGoods).
ets_delete_buy_goods_by_id(Id) ->
	ets:delete(?ETS_BUY_GOODS, Id).
ets_get_buy_goods_all() ->
	ets:tab2list(?ETS_BUY_GOODS).
ets_match_buy_goods(Pattern) ->
	ets:match_object(?ETS_BUY_GOODS, Pattern).
ets_lookup_buy_goods(BuyId) ->
	ets:lookup(?ETS_BUY_GOODS, BuyId).

%%求购模块的邮件
sendmail_for_buy(PName, SendType, Param) ->
	NameList = [tool:to_list(PName)],
	Title = "系统信件",
	{GoodsId, GoodsTypeId, GoodsNum, Coin, Cash, GoodsBind} = 
		case SendType of
			buy_goldprice_timeout ->%%%%求购单价为元宝的过期了
				{EGold, ECoin} = Param,
				Content = io_lib:format("您的求购信息已过期,扣除手续费后,现返还您~p元宝", [EGold]),
				{0,0,0,ECoin,EGold, 1};
			buy_coinprice_timeout ->%%求购单价为铜钱的过期了
				{EGold, ECoin} = Param,
				Content = io_lib:format("您的求购信息已过期,扣除手续费后,现返还您~p铜币", [ECoin]),
				{0,0,0,ECoin,EGold, 1};
			sell_gc_succeed ->%%成功出售元宝或者铜币
				{ECoin, EGold, EPType} = Param,
%% 				?DEBUG("sell_gc_succeed:~p", [EPType]),
				case EPType of
					1 ->%%价格是铜钱，求购元宝，给予元宝，得到铜钱
						Content = io_lib:format("您已成功出售元宝×~p,共获得~p铜钱.", [EGold,ECoin]),
						{0,0,0,ECoin,0,1};
					2 ->%%价格是元宝，求购铜钱，给予铜钱，得到元宝
						Content = io_lib:format("您已成功出售铜钱×~p,共获得~p元宝.", [ECoin, EGold]),
						{0,0,0,0,EGold,1}
				end;
			buy_gc_succeed ->%%成功求购元宝或者铜币
				{ECoin, EGold, EPType} = Param,
%% 				?DEBUG("buy_gc_succeed:~p", [EPType]),
				case EPType of
					2 ->%%求购的是铜币，出售元宝，得到铜币				
						Content = io_lib:format("您已成功购买铜币×~p,共花费~p元宝.", [ECoin, EGold]),
						{0,0,0,ECoin,0,1};
					1 ->%%求购的是元宝，出售博内关闭，得到元宝
						Content = io_lib:format("您已成功购买元宝×~p,共花费~p铜币.", [EGold, ECoin]),
						{0,0,0,0,EGold,1}
				end;
			sell_goods_succeed ->%%兜售物品，得到对应的价格
				{ESellNum, EPrice, EPType, EGName} = Param,
%% 				?DEBUG("sell_goods_succeed:~p", [EPType]),
				case EPType of
					2 ->%%价格是元宝，直接得到元宝	
						Content = io_lib:format("您已成功出售~s×~p,共获得~p元宝.", [EGName, ESellNum, EPrice]),
						{0,0,0,0,EPrice,1};
					1 ->%%价格是铜币，直接得到铜币
						Content = io_lib:format("您已成功出售~s×~p,共获得~p铜币.", [EGName, ESellNum, EPrice]),
						{0,0,0,EPrice,0,1}
				end;
			buy_goods_succeed ->%%成功求购物品
				{EGName, ESellNum, EUnPrice, EPType, EGoodsId} = Param,
				EPrice = tool:ceil(EUnPrice * ESellNum),
%% 				?DEBUG("buy_goods_succeed:~p", [EPType]),
				case EPType of
					2 ->%%价格是元宝	
						Content = io_lib:format("您已成功购买~s×~p,共花费~p元宝.", [EGName, ESellNum, EPrice]),
						{0,EGoodsId,ESellNum,0,0,1};
					1 ->%%价格是铜币
						Content = io_lib:format("您已成功购买~s×~p,共花费~p铜币.", [EGName, ESellNum, EPrice]),
						{0,EGoodsId,ESellNum,0,0,1}
				end;
		buy_goods_equip_succeed ->
				{EGName, ESellNum, EUnPrice, EPType, EGid, EGoodsId} = Param,
				EPrice = tool:ceil(EUnPrice * ESellNum),
%% 				?DEBUG("buy_goods_equip_succeed:~p", [EPType]),
				case EPType of
					2 ->%%价格是元宝	
						Content = io_lib:format("您已成功购买~s×~p,共花费~p元宝.", [EGName, ESellNum, EPrice]),
						{EGid,EGoodsId,1,0,0,1};
					1 ->%%价格是铜币
						Content = io_lib:format("您已成功购买~s×~p,共花费~p铜币.", [EGName, ESellNum, EPrice]),
						{EGid,EGoodsId,1,0,0,1}
				end;
			cancel_buy_goods ->%%取消求购记录，直接返回价格
				{EPrice, EPType} = Param,
%% 				?DEBUG("cancel_buy_goods:~p", [EPType]),
				case EPType of
					2 ->%%价格是元宝	
						Content = io_lib:format("您已取消求购,扣除手续费后,现返还您~p元宝.", [EPrice]),
						{0,0,0,0,EPrice,1};
					1 ->%%价格是铜币
						Content = io_lib:format("您已取消求购,扣除手续费后,现返还您~p铜币.", [EPrice]),
						{0,0,0,EPrice,0,1}
				end;
			_ ->
				Content = "感谢对远古封神的支持！",
				{0,0,0,0,0,1}
		end,
	mod_mail:send_sys_mail(NameList, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Cash, GoodsBind).

%%人工手动下架所有的拍卖物品
labour_cancel_all_goods_buy() ->
	mod_buy:cancel_all_goods_buy().

cancel_all_goods_buy() ->
	Records = ets_get_buy_goods_all(),
	NowTime = util:unixtime(),
	lists:foreach(fun(Elem) ->
						  handle_buy_goods_timeout_each(Elem, NowTime)
				  end, Records).




