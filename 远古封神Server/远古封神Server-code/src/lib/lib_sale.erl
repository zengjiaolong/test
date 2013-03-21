%% Author: xiaomai
%% Created: 2010-10-12
%% Description: 交易市场处理 
-module(lib_sale).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
%% -compile([export_all]).
%%
%% Exported Functions
%%
-export([labour_cancel_all_goods_sale/0,	%% 人工手动下架所有的拍卖
		 cancel_all_goods_sale/0,
		 handle_sale_goods_timeout/0,		%% 处理过期拍卖纪录
		 load_all_sale/0,					%%加载所有的交易市场记录
		 list_sale_goods/9,					%% 17001 查询市场中存在的物品
		 sale_goods/7,						%% 17002 开始拍卖物品
		 sale_money/7,						%% 17003 开始拍卖元宝或铜币
		 list_sale_goods_self/1,			%% 17004 查看已上架物品（我的上架物品）
		 cancel_sale_goods/2,				%% 17005 取消拍卖物品
		 buyer_sale_goods/2,				%% 17006 买家拍卖物品
		 get_salegoods_info/3,				%% 17007 获取物品详细信息(仅在市场拍卖模块用)
		 update_goods_attribute/1,
		 ets_delete_goods_info/1,
		 insert_sale_flow_record/3,
		 get_sale_goods_id/1,
		 sale_give_goods/4,%%拍卖物品进背包操作
		 get_deduct_by_goods/1,
		 get_sale_levels_by_id/1,
		 change_player_name/2,
		 list_hot_goods/6
		]).

%%拍卖时间基数(60*60 = 3600秒)
-define(BASE_SLAE_GOODS_TIMEOUT, 3600).

%%
%% API Functions
%%

%% -----------------------------------------------------------------
%% 处理过期拍卖纪录
%% -----------------------------------------------------------------
handle_sale_goods_timeout() ->
	Records = load_sale_goods(),
	NowTime = util:unixtime(),
%% 	io:format("*** NowTime [~p], begin to handle sale goods timeout\n", [NowTime]),
	{SubRecords, _NonSubRecords} = lists:partition(fun(Record) ->
										 DiffTime = NowTime - Record#ets_sale_goods.sale_start_time,
										 SaleTime = Record#ets_sale_goods.sale_time * ?BASE_SLAE_GOODS_TIMEOUT,
										 DiffTime > SaleTime
								 end, Records),
	lists:map(fun(Elem) ->
					  handle_sale_goods_record_timeout(NowTime, Elem)
			  end, SubRecords).

%%处理每条过期的拍卖纪录，拍卖品将以系统信件形式返回给玩家
handle_sale_goods_record_timeout(CancelSaleTime, SaleGoods) ->
	#ets_sale_goods{id = SaleId,
					sale_type = SaleType,
					player_name = PlayerName
					} = SaleGoods,
	%%添加拍卖物品数据流向记录
	spawn(lib_sale, insert_sale_flow_record, [0, CancelSaleTime, SaleGoods]),
	%%处理取消退回拍卖的过程
	case SaleType of
		1 ->%%拍卖的是实物
			GoodsId = SaleGoods#ets_sale_goods.gid,
			Goods = goods_util:get_goods_by_id(GoodsId),
			if %%物品数据缺失
				is_record(Goods, goods) =:= false ->
%% 				Goods =:= {goods} ->
					%%更新拍卖纪录
					%%在ets_sale_goods删除记录
					ets_delete_sale_goods_record(SaleId),
					
					DeleteSaleGoodsList = [{id, SaleId}],
					spawn(fun()->db_agent:delete_sale_goods_record(DeleteSaleGoodsList)end),
					
					%%删除拍卖表中的物品属性信息(删除ets_sale_goods_online表和ets_sale_goods_attribute表)
					ets_delete_sale_goods_info(GoodsId),
					ets_delete_sale_goods_attribute(GoodsId);
				true ->
					Num = SaleGoods#ets_sale_goods.num,
					GoodsName = goods_util:get_goods_name(Goods#goods.goods_id),
					Param = [GoodsId, GoodsName, Num, Goods#goods.goods_id],
					spawn(fun()->sendmail_for_sale(PlayerName, goods_onsale_timeout, Param)end),
					
					%%更新拍卖纪录
					%%在ets_sale_goods删除记录
					ets_delete_sale_goods_record(SaleId),
					
					DeleteSaleGoodsList = [{id, SaleId}],
					spawn(fun()->db_agent:delete_sale_goods_record(DeleteSaleGoodsList)end),
					
					%%删除拍卖表中的物品属性信息(删除ets_sale_goods_online表和ets_sale_goods_attribute表)
					ets_delete_sale_goods_info(GoodsId),
					ets_delete_sale_goods_attribute(GoodsId)
			end;
		2 ->%%拍卖的是元宝或者铜钱
			PriceType = SaleGoods#ets_sale_goods.price_type,
			Money = SaleGoods#ets_sale_goods.num,
			case PriceType of
				1 ->%拍卖的是元宝
					%%发送系统信件
					Param = [Money],
					spawn(fun()->sendmail_for_sale(PlayerName, gold_onsale_timeout, Param)end),
					%%更新拍卖纪录
					DeleteSaleGoodsList = [{id, SaleId}],
					spawn(fun()->db_agent:delete_sale_goods_record(DeleteSaleGoodsList)end),
					%%在ets_sale_goods删除记录
					ets_delete_sale_goods_record(SaleId),
					[1];
				2 ->%%拍卖的是铜钱
					%%发送系统信件
					Param = [Money],
					spawn(fun()->sendmail_for_sale(PlayerName, coin_onsale_timeout, Param)end),
					%%更新拍卖纪录
					DeleteSaleGoodsList = [{id, SaleId}],
					spawn(fun()->db_agent:delete_sale_goods_record(DeleteSaleGoodsList)end),
					%%在ets_sale_goods删除记录
					ets_delete_sale_goods_record(SaleId)
			end
	end.

	
%% -----------------------------------------------------------------
%%加载所有的交易市场记录
%% -----------------------------------------------------------------
load_all_sale() ->
	SalesList = db_agent:load_all_sale(),
%% 	io:format("load all sale 1.... \n"),
	lists:map(fun load_sales_into_ets/1, SalesList),
	GoodsInfoList = db_agent:load_all_sale_goods(),
%% 	io:format("load all sale 2.... \n"),
	GoodsIds = lists:map(fun load_salegoods_into_ets/1, GoodsInfoList),
%% 	io:format("load all sale 3.... \n"),
	lists:map(fun load_salegoods_attributes_into_ets/1, GoodsIds).
%% 	io:format("load all sale 4.... \n").

load_sales_into_ets(SaleRecord) ->
%% 	SaleRecordEts = list_to_tuple([ets_sale_goods] ++ SaleRecord),
	[Id,SaleType,Gid,GoodsId,GoodsName,GoodsType,GoodsSubtype,
	 PlayerId,PlayerName,Num,Career,GoodsLevel,GoodsColor,
	 PriceType,Price,SaleTime,SalStartTime, Md5Key] = SaleRecord,
	case Num of
		0 ->
			UnPrice = 0;
		_ ->
			UnPrice = Price / Num
	end,
	SaleRecordEts = 
		#ets_sale_goods{id = Id,                                    	 %% 拍卖纪录ID	
						unprice = UnPrice,							 	 %% 商品单价
						sale_type = SaleType,                        	 %% 拍卖类型（1，实物；2，元宝或铜钱）	
						gid = Gid,                                		 %% 物品ID，当ID为0时，表示拍卖的为元宝	
						goods_id = GoodsId,                           	 %% 品物基本类型ID	
						goods_name = GoodsName,                        	 %% 物品名字	
						goods_type = GoodsType,                          %% 物品类型当类型为0时，表示拍卖的为元宝,	
						goods_subtype = GoodsSubtype,                    %% 物品子类型当子类型为0时，表示拍卖的为元宝,	
						player_id = PlayerId,                          	 %% 拍卖的玩家ID	
						player_name = PlayerName,                        %% 拍卖的玩家名字	
						num = Num,                                		 %% 货币（拍卖的物品是元宝或铜钱时，此值存在数值，不是元宝时，此值为该物品的数量）	
						career = Career,                             	 %% 职业,	
						goods_level = GoodsLevel,                        %% 物品等级	
						goods_color = GoodsColor,                        %% 物品颜色，0 白色，1 绿色，2 蓝色，3 金色，4 紫色; 99 为不限 	
						price_type = PriceType,                          %% 拍卖价格类型：1铜钱，2元宝	
						price = Price,                                   %% 拍卖价格	
						sale_time = SaleTime,                            %% 拍卖时间：6小时，12小时，24小时	
						sale_start_time = SalStartTime,                  %% 拍卖开始时间	
						md5_key = Md5Key                                 %% 客户端发送的md5验证串	
    },
	ets_update_sale_goods(SaleRecordEts),
	ok.
load_salegoods_into_ets(GoodsInfo) ->
	GoodsInfoEts = list_to_tuple([goods] ++ GoodsInfo),
	ets_insert_sale_goods_info(GoodsInfoEts),
	GoodsInfoEts#goods.id.

load_salegoods_attributes_into_ets(GId) ->
%% 	io:format("load salegoods attribute into ets:~p \n", [GId]),
	GoodsAttributes = db_agent:load_all_sale_goods_attributes(GId),
	lists:map(fun(GoodsAttribute) ->
					  GoodsAttributeEts = list_to_tuple([goods_attribute] ++ GoodsAttribute),
					  ets_insert_sale_goods_attribute(GoodsAttributeEts)
			  end, GoodsAttributes).
	
%% -----------------------------------------------------------------
%% 17001 查询市场中存在的物品(拍卖)
%% -----------------------------------------------------------------
list_sale_goods(GoodsLevelId, Color, Career, Type, SubTypeList, SortType, GoodsName, StartNum, EndNum) ->
	%%拍卖表过滤
	GoodsRecords = filter_sale_goods(GoodsLevelId, Color, Career, Type, SubTypeList, GoodsName),
	%%按时间倒序一下，越 晚拍的，越靠前
	PartitionGoods = sort_sale_from_time(GoodsRecords),
	%%按照价格类型排序
	LenCheck = length(PartitionGoods),
	case LenCheck > 1 of
		true ->
			case SortType of
				0 ->%%默认的时候是不排序的
					SortPriceSaleGoods = PartitionGoods;
				1 ->%按照价格降序升序
					SortPriceSaleGoods = lists:sort(fun sort_goods_by_price_asc/2, PartitionGoods);
				2 ->%%%按照价格降序
					SortPriceSaleGoods = lists:sort(fun sort_goods_by_price_desc/2, PartitionGoods);
				3 ->%%单价按照升序排序
					SortPriceSaleGoods = lists:sort(fun sort_goods_by_unprice_asc/2, PartitionGoods);
				4 ->%%单价按照降序排序
					SortPriceSaleGoods = lists:sort(fun sort_goods_by_unprice_desc/2, PartitionGoods);
				_ ->%%直接过滤一些非法错误的操作
					SortPriceSaleGoods = PartitionGoods
			end;
		false ->
			SortPriceSaleGoods = PartitionGoods
	end,
	Len = length(SortPriceSaleGoods),
	if 
		Len == 0 ->
			[Len, 0, []];
		Len < StartNum ->
		  [Len, 0, []];
		true ->
			NewSaleGoodsList = lists:sublist(SortPriceSaleGoods, StartNum, EndNum),
			NewLen = length(NewSaleGoodsList),
			[Len, NewLen, NewSaleGoodsList]
	end.

%%从ets表中，查询市场中存在的物品(按等级找)
ets_list_sale_goods([GoodsLevelA, GoodsLevelB]) ->
	Ms = ets:fun2ms(fun(T) when T#ets_sale_goods.goods_level >= GoodsLevelA 
						 andalso T#ets_sale_goods.goods_level =< GoodsLevelB  ->
							T
					end),
	ets:select(?ETS_SALE_GOODS, Ms).


%%按照价格排序（降序）
sort_goods_by_price_desc(Goods1, Goods2) ->
	case Goods1#ets_sale_goods.price_type > Goods2#ets_sale_goods.price_type of
		true ->
			true;
		false ->
			case Goods1#ets_sale_goods.price_type =:= Goods2#ets_sale_goods.price_type of
				true ->
					Goods1#ets_sale_goods.price >= Goods2#ets_sale_goods.price;
				false ->
					false
		end
	end.
%%按照价格排序（升序）
sort_goods_by_price_asc(Goods1, Goods2) ->
   	case Goods1#ets_sale_goods.price_type < Goods2#ets_sale_goods.price_type of
		true ->
			true;
		false ->
			case Goods1#ets_sale_goods.price_type =:= Goods2#ets_sale_goods.price_type of
				true ->
					Goods1#ets_sale_goods.price =< Goods2#ets_sale_goods.price;
				false ->
					false
		end
	end.
%%单价按照升序排序
sort_goods_by_unprice_asc(Goods1, Goods2) ->
   	case Goods1#ets_sale_goods.price_type < Goods2#ets_sale_goods.price_type of
		true ->
			true;
		false ->
			case Goods1#ets_sale_goods.price_type =:= Goods2#ets_sale_goods.price_type of
				true ->
					Goods1#ets_sale_goods.unprice =< Goods2#ets_sale_goods.unprice;
				false ->
					false
		end
	end.
%%单价按照降序排序			
sort_goods_by_unprice_desc(Goods1, Goods2) ->
	case Goods1#ets_sale_goods.price_type > Goods2#ets_sale_goods.price_type of
		true ->
			true;
		false ->
			case Goods1#ets_sale_goods.price_type =:= Goods2#ets_sale_goods.price_type of
				true ->
					Goods1#ets_sale_goods.unprice >= Goods2#ets_sale_goods.unprice;
				false ->
					false
		end
	end.
			
%%拍卖表过滤
filter_sale_goods(GoodsLevelId, Color, Career, Type, SubTypeList, GoodsName) ->
	%%过滤等级范围
	GoodsRecords = 
		case get_sale_levels_by_id(GoodsLevelId) of
			{do, [GoodsLevelA, GoodsLevelB]} ->%%限制等级范围
				ets_list_sale_goods([GoodsLevelA, GoodsLevelB]);
			{undo, [_GA, _GB]} ->%%不限等级
				load_sale_goods()
		end,
	%%颜色和职业限制
	{CareerColorGoods, _NodCareerColorGoods} = 
		if
			Color =/= 99 andalso Career =/= 0 ->
				lists:partition(fun(CareerColorElem) -> CareerColorElem#ets_sale_goods.goods_color == Color 
								andalso CareerColorElem#ets_sale_goods.career == Career end, GoodsRecords);
			Color =:= 99 andalso Career =/= 0 ->
				lists:partition(fun(CareerColorElem) -> CareerColorElem#ets_sale_goods.career == Career end, GoodsRecords);
			Color =/= 99 andalso Career =:= 0 ->
				lists:partition(fun(CareerColorElem) -> CareerColorElem#ets_sale_goods.goods_color == Color end, GoodsRecords);
			true ->
				{GoodsRecords, []}
		end,
	%%类型判断（内嵌子类型）
	if 
		Type =/= 0 orelse (length(SubTypeList) =/= 0) ->
			{SubTypeGoods, _NonSubTypeGoods} = 
				lists:partition(fun(Elem) -> 
										IsSubType = lists:member(Elem#ets_sale_goods.goods_subtype, SubTypeList),
										IsSubType andalso (Elem#ets_sale_goods.goods_type == Type)
								end, CareerColorGoods);
		true  ->
			SubTypeGoods = CareerColorGoods
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
										case re:run(X#ets_sale_goods.goods_name, tool:to_binary(GoodsName), [caseless]) of
											nomatch ->
												false;
											_ ->
												true
										end
								end, SubTypeGoods)
	end,
	PartitionGoods.
%%按时间排一次序，拍卖越晚的越靠前
sort_sale_from_time(GoodsRecordsAll) ->
	lists:sort(fun(A,B) ->
					   TA = A#ets_sale_goods.sale_start_time,
					   TB = B#ets_sale_goods.sale_start_time,
					   TA >= TB
			   end, GoodsRecordsAll).

%% -----------------------------------------------------------------
%% 17002 开始拍卖物品
%% -----------------------------------------------------------------
sale_goods(Status, GoodsId, PriceType, Price, DeductPrice, SaleTime, _Cell) ->
	#player{id =PlayerId, 
			nickname = PalyerName} = Status,
	%%即时获取玩家的铜币数量！
	[Coin, _GBCoin] = db_agent:query_player_coin(PlayerId),
	[Gold, _Cash] = db_agent:query_player_money(Status#player.id),
	GoodsPid = Status#player.other#player_other.pid_goods,
	%%查找在背包中的对应的格子的物品
	%%计算保管费
	[DeductRadix] = get_deduct_by_goods({PriceType, SaleTime}),
	%%保管费用向上取整
	DeductPriceServ = tool:ceil(Price * DeductRadix),
	IsWarServer = lib_war:is_war_server(),
	case Coin >= 0 andalso Gold >= 0 andalso DeductPriceServ > 0 andalso Coin>= DeductPriceServ of
		true ->%%保管费是否够
			if
				DeductPriceServ /= DeductPrice -> error;
%% 				Gold < 0 -> error;
				Price =< 0 -> [6, Coin, 0]; %%价格不能为0
				IsWarServer ->[7,Coin,0];%%跨服不能拍卖
				true ->%%向sale_goods表插入拍卖纪录数据
					case ets_get_goods_info(GoodsId) of
						[] ->%%没拍卖纪录的,可以拍卖
							%% ?DEBUG("~ts~n",["insert the data into sale_goods"]),
							%%删除ets_goods_online更新goods_attribute表(把playerid置0)和删除ets_goods_attribute表数据
							case catch(gen_server:call(GoodsPid, {'delete_sale_goods', GoodsId, 4, PlayerId})) of
								{ok, GoodsName, Goods, AttributeList} ->
									#goods{type = GoodsType,
										   subtype = GoodsSubType,
										   career = Career,
										   level = GoodsLevel,
										   color = GoodsColor} = Goods,
									NowTime = util:unixtime(),
									case Goods#goods.num of
										0 ->
											UnPrice = 0;
										_ ->
											UnPrice = Price / Goods#goods.num
									end,
									SaleGoodsValueList = #ets_sale_goods{unprice = UnPrice,
																		 sale_type = 1,
																		 gid = GoodsId,
																		 goods_id = Goods#goods.goods_id,
																		 goods_name = GoodsName,
																		 goods_type = GoodsType,
																		 goods_subtype = GoodsSubType,
																		 player_id = PlayerId,
																		 player_name = PalyerName,
																		 num = Goods#goods.num,
																		 career = Career,
																		 goods_level = GoodsLevel,
																		 goods_color = GoodsColor,
																		 price_type = PriceType,
																		 price = Price,
																		 sale_time = SaleTime,
																		 sale_start_time = NowTime,
																		 md5_key = tool:to_binary("")},
									case db_agent:sale_goods(SaleGoodsValueList) of
										{mongo, Ret} ->
											SaleGoodsInsertEts = SaleGoodsValueList#ets_sale_goods{id = Ret};
										1 ->
											case db_agent:get_sale_goods_info(GoodsId, PlayerId) of
												null ->
													SaleGoodsInsertEts = [];
												NRet ->
													SaleGoodsInsertEts = SaleGoodsValueList#ets_sale_goods{id = NRet}
											end;
										_Other ->
											SaleGoodsInsertEts = []
									end,
									if 
										SaleGoodsInsertEts == [] -> 
											error;
										true ->
											%%更新ets_sale_goods表
											%% ?DEBUG("~p~n",[SaleGoodsInsertEts]),
											%% ?DEBUG("~ts~n",["insert the data into ets_sale_goods"]),
											ets_update_sale_goods(SaleGoodsInsertEts),
											%%添加拍卖纪录的物品内存数据(ets_sale_goods_online表)
											ets_insert_sale_goods_info(Goods#goods{player_id = 0, cell = 0}),
											%%添加拍卖纪录的物品内存数据(ets_sale_goods_attribute表)
											lists:map(fun(AttirbuteElem) ->
															  NewAttributeElem = AttirbuteElem#goods_attribute{player_id = 0},
															  ets_insert_sale_goods_attribute(NewAttributeElem)
													  end, AttributeList),
											%%扣报保管费
											%% ?DEBUG("~ts~n",["insert the data into deduct price"]),
											NewPlayerStatus = lib_goods:cost_money(Status, DeductPriceServ, coinonly, 1702),
											NewCoin = NewPlayerStatus#player.coin,
											%%添加拍卖物品数据流向记录
											spawn(lib_sale, insert_sale_flow_record, [1, SaleGoodsInsertEts#ets_sale_goods.sale_start_time, SaleGoodsInsertEts]),
											[1, NewCoin, Goods#goods.num]
									end;
								{fail, ResultType} ->
									[ResultType, Coin, 0];
								_DeleteError ->
									error
							end;
						_ ->%%有记录了，出错
							error
					end
			end;
		false ->
			[3, Coin, 0]
	end.

update_goods_attribute(GoodsAttribute) ->
	GoodsAttributeValue = [{player_id, 0}],
	GoodsAttributeWhereList = [{gid, GoodsAttribute#goods_attribute.gid}],
	spawn(fun()->db_agent:update_goods_attribute_owner(GoodsAttributeValue, GoodsAttributeWhereList)end),
	ets_delete_goods_attribute(GoodsAttribute#goods_attribute.id).


ets_get_goods_info(GoodsId) ->
	Pattern = #ets_sale_goods{id = GoodsId, _ ='_'},
	ets:match_object(?ETS_SALE_GOODS_ONLINE, Pattern).
ets_get_goods_info_md5(Md5KeyBin) ->
	Pattern = #ets_sale_goods{md5_key = Md5KeyBin, _ ='_'},
	ets:match_object(?ETS_SALE_GOODS_ONLINE, Pattern).
%%更新ets_goods_online表
ets_delete_goods_info(GoodsId) ->
	ets:delete(?ETS_GOODS_ONLINE, GoodsId).
%%更新goods_attribute表
ets_delete_goods_attribute(Id) ->
	ets:delete(?ETS_GOODS_ATTRIBUTE, Id).

ets_insert_sale_goods_info(GoodsNew) ->
	ets:insert(?ETS_SALE_GOODS_ONLINE, GoodsNew). 
ets_get_sale_goods_info(GoodsId) ->
	ets:lookup(?ETS_SALE_GOODS_ONLINE, GoodsId).
ets_delete_sale_goods_info(GoodsId) ->
	ets:delete(?ETS_SALE_GOODS_ONLINE, GoodsId). 

ets_insert_sale_goods_attribute(NewGoodsAttribute) ->
	ets:insert(?ETS_SALE_GOODS_ATTRIBUTE, NewGoodsAttribute). 
ets_get_sale_goods_attribute(Gid) ->
	Pattern = #goods_attribute{gid = Gid, _ = '_'},
	ets:match_object(?ETS_SALE_GOODS_ATTRIBUTE, Pattern).
ets_delete_sale_goods_attribute(Gid) ->
	Pattern = #goods_attribute{gid = Gid, _='_'},
	ets:match_delete(?ETS_SALE_GOODS_ATTRIBUTE,Pattern).
%% 	ets:delete(?ETS_SALE_GOODS_ATTRIBUTE, Id).

%% -----------------------------------------------------------------
%% 17003 开始拍卖元宝或铜币
%% -----------------------------------------------------------------
sale_money(Status, Money, PriceType, Price, DeductPrice, SaleTime, Md5Key) ->
	#player{id =PlayerId, 
			nickname = PalyerName} = Status,
	%%即时获取玩家的铜币数量！
	[Coin, _GBCoin] = db_agent:query_player_coin(PlayerId),
	[Gold, _Cash] = db_agent:query_player_money(Status#player.id),
	%%计算保管费
	[DeductRadix] = get_deduct_by_money({PriceType, SaleTime}),
	%%保管费用向上取整
	DeductPriceServ = tool:ceil(Price * DeductRadix),
%%	%% ?DEBUG("~ts:serv [~p],client [~p]",["debuctPrice", DeductPriceServ, DeductPrice]),
		
	case string:len(Md5Key) =:= 32 of
		true ->
			Md5KeyBin = tool:to_binary(Md5Key),
	case ets_get_goods_info_md5(Md5KeyBin) of
		[] ->
			case PriceType of
				1 ->%%拍卖的是元宝
					case Money > 0 andalso Price > 0 of
						true ->%%保管费是否足够
							case Coin >= 0 andalso DeductPriceServ > 0 andalso Coin >= DeductPriceServ of
								true -> %%拍卖的本金或者价格不能为0
							case  Gold >= 0 andalso  Money > 0 andalso Gold >= Money of
								true ->%%是否有足够的元宝
									if 
										Money =< 0 orelse Price =< 0 -> [5, 0, 0]; 
%% 						Gold =< 0 orelse Money < 0 orelse abs(Money) > abs(Gold) ->	[2, 0, 0];
										DeductPriceServ /= DeductPrice -> error;
%% 			   Coin =< 0 orelse DeductPrice < 0 orelse abs(DeductPrice) > abs(Coin) -> [3, 0, 0];
										true ->
											%%向sale_goods表插入拍卖纪录数据
											NowTime = util:unixtime(),
											UnPrice = Price / Money,
											SaleGoodsValueList = #ets_sale_goods{unprice = UnPrice,
																				 sale_type = 2,
																				 gid = 0, goods_id = 2,
																				 goods_name = "元宝",
																				 goods_type = 0,
																				 goods_subtype = 10,
																				 player_id = PlayerId,
																				 player_name = PalyerName,
																				 num = Money, career = 0,
																				 goods_level = 0,
																				 goods_color = 99,
																				 price_type = PriceType,
																				 price = Price, sale_time = SaleTime,
																				 sale_start_time = NowTime,
																				 md5_key = Md5KeyBin},
											case db_agent:sale_goods(SaleGoodsValueList) of
												{mongo, Ret} ->
													SaleGoodsEts = SaleGoodsValueList#ets_sale_goods{id = Ret};
												1 ->
													%% ?DEBUG("~p",[SaleGoodsValueList]),
													case db_agent:get_sale_goods_info(0, PlayerId) of
														null ->
															SaleGoodsEts = [];
														NRet ->
															SaleGoodsEts = SaleGoodsValueList#ets_sale_goods{id = NRet}
													end;
												_Other ->
													SaleGoodsEts = []
											end,
											if %%处理_Other时的错误
												SaleGoodsEts == [] -> error;
												true ->
													%%更新ets_sale_goods表
													ets_update_sale_goods(SaleGoodsEts),
													%%扣报保管费,同时扣除拍卖的元宝
													NewPlayerGoldStatus = lib_goods:cost_money(Status, DeductPriceServ, coinonly, 1703),
													NewCoin = NewPlayerGoldStatus#player.coin,
													NewPlayerStatus = lib_goods:cost_money(NewPlayerGoldStatus, Money, gold, 1703),
													NewGold = NewPlayerStatus#player.gold,
													%%添加拍卖物品数据流向记录
													spawn(lib_sale, insert_sale_flow_record, [1, SaleGoodsEts#ets_sale_goods.sale_start_time, SaleGoodsEts]),
													[1, NewCoin, NewGold]
											end
									end;
								false ->
									[2, 0, 0]
							end;
								false ->
									[3, 0, 0]
							end;
						false ->%%保管费不足够
							[5, 0, 0]
					end;
				2 ->%%拍卖的是铜钱
					case Money > 0 andalso Price > 0 of
						true -> %%拍卖的本金或者价格不能为0
							case Gold >= 0 andalso Coin >= 0 andalso DeductPriceServ > 0 andalso Coin >= (Money + DeductPriceServ) 
								andalso Money > 0 andalso Coin > Money of
								true -> %拍卖的铜钱 + 保管费不够扣
									if 	%%数据出错
										DeductPriceServ /= DeductPrice -> error;
										true ->
											%%向sale_goods表插入拍卖纪录数据
											NowTime = util:unixtime(),
											UnPrice = Price / Money,
											SaleGoodsValueList = #ets_sale_goods{unprice = UnPrice,
																				 sale_type = 2,
																				 gid = 0, goods_id = 1,
																				 goods_name = "铜币",
																				 goods_type = 0, goods_subtype = 11,
																				 player_id = PlayerId,
																				 player_name = PalyerName,
																				 num = Money, career = 0,
																				 goods_level = 0,
																				 goods_color = 99,
																				 price_type = PriceType,
																				 price = Price, sale_time = SaleTime,
																				 sale_start_time = NowTime,
																				 md5_key = Md5KeyBin},
											case db_agent:sale_goods(SaleGoodsValueList) of
												{mongo, Ret} ->
													SaleGoodsEts = SaleGoodsValueList#ets_sale_goods{id = Ret};
												1 ->
													case db_agent:get_sale_goods_info(0, PlayerId) of
														null ->
															SaleGoodsEts = [];
														NRet ->
															SaleGoodsEts = SaleGoodsValueList#ets_sale_goods{id = NRet}
													end;
												_Other ->
													SaleGoodsEts = []
											end,
											if 
												SaleGoodsEts == [] ->
													error;
												true ->
													%%更新ets_sale_goods表
													ets_update_sale_goods(SaleGoodsEts),
													%%扣报保管费,同时扣除拍卖的钱
													CoinNeedCut = Money + DeductPriceServ,
													NewPlayerStatus = lib_goods:cost_money(Status, CoinNeedCut, coinonly, 1703),
													NewCoin = NewPlayerStatus#player.coin,
													%%添加拍卖物品数据流向记录
													spawn(lib_sale, insert_sale_flow_record, [1, SaleGoodsEts#ets_sale_goods.sale_start_time, SaleGoodsEts]),
													[1, NewCoin, Gold]
											end
									end;
								false ->
									[3, 0, 0]
							end;
						false ->
						[5, 0, 0]
					end
			end;
		_ ->%%已经由此条记录
			error
	end;
		false ->
			error
	end.


%% -----------------------------------------------------------------
%% 17004 查看已上架物品（我的上架物品）
%% -----------------------------------------------------------------
list_sale_goods_self(PlayerId) ->
	%%获取当前玩家的所有拍卖上架物品列表
	SaleGoods = ets_get_sale_goods_self(PlayerId),
	Len = length(SaleGoods),
	%% ?DEBUG("**********~ts: ~p**********", ["the list_sale_goods_self len is", Len]),
	%%对上架物品根据上架时间进行排序（越新上架越靠前）
	SortSaleGoods = lists:sort(fun sort_sale_goods_by_time/2, SaleGoods),
	%%处理返回的物品列表数据
	Records = lists:map(fun handle_list_sale_goods_self/1, SortSaleGoods),
	[Len, list_to_binary(Records)].

%%对上架物品根据上架时间进行排序（越新上架越靠前）
sort_sale_goods_by_time(SaleGoodsA, SaleGoodsB) ->
	Result = SaleGoodsA#ets_sale_goods.sale_start_time =< SaleGoodsB#ets_sale_goods.sale_start_time,
	case Result of
		true ->
			false;
		false ->
			true
	end.

%%获取当前玩家的所有拍卖上架物品列表
ets_get_sale_goods_self(PlayerId) ->
	Pattern = #ets_sale_goods{player_id = PlayerId, _ = '_'},
	ets:match_object(?ETS_SALE_GOODS, Pattern).

%%处理返回的物品列表数据
handle_list_sale_goods_self(SaleGood) ->
	#ets_sale_goods{id = SaleId,
					gid = GoodsId,
					goods_id = BaseGoodsId,
					goods_name = GoodsName,
					num = Num,
					goods_level = GoodsLevel,
					goods_color = GoodsColor,
					career = Career,
					price_type = PriceType,
					price = Price} = SaleGood,
	GoodsNameBin = tool:to_binary(GoodsName),
	LenGoodsName = byte_size(GoodsNameBin),	
	%% ?DEBUG("****[~ts] ~p  ~p  ~p*****~n",[GoodsName, LenGoodsName, SaleId, GoodsId]),
	<<SaleId:32, GoodsId:32, BaseGoodsId:32, Num:32, LenGoodsName:16, GoodsNameBin/binary, GoodsLevel:32, GoodsColor:16,
	  Career:16, PriceType:16, Price:32, 0:16>>.


%% -----------------------------------------------------------------
%% 17005 取消拍卖物品
%% -----------------------------------------------------------------
cancel_sale_goods(PlayerId, SaleId) ->
	%% ?DEBUG(" lib_sale:cancel_sale_goods and id is [~p] ", [SaleId]),
	SaleGoodsResult = get_sale_goods_record(SaleId),
	case SaleGoodsResult of
		[] ->%%物品不存在
			[2];
		_ ->
			[SaleGoods] = SaleGoodsResult,
			if%%玩家ID与对应的拍卖物品主人ID不同，出错
				SaleGoods#ets_sale_goods.player_id /= PlayerId -> [0];
				true ->
					%%处理取消拍卖的过程
					case SaleGoods#ets_sale_goods.sale_type of
						1 ->%%拍卖的是实物
							%% ?DEBUG("~ts", ["lib_sale:cancel_sale_goods 111"]),
							GoodsId = SaleGoods#ets_sale_goods.gid,
							Goods = goods_util:get_goods_by_id(GoodsId),
							if %%物品数据缺失
								is_record(Goods, goods) =:= false ->
%% 								Goods =:= {goods} ->
								 [3];
							   true ->
								   %% ?DEBUG("~ts", ["lib_sale:cancel_sale_goods 222"]),
								   GoodsName = goods_util:get_goods_name(Goods#goods.goods_id),
								   
								   %%更新拍卖纪录
								   DeleteSaleGoodsList = [{id, SaleId}],
								   spawn(fun()->db_agent:delete_sale_goods_record(DeleteSaleGoodsList)end),
								   %%在ets_sale_goods删除记录
								   ets_delete_sale_goods_record(SaleId),
								   
								   %%删除拍卖表中的物品属性信息(删除ets_sale_goods_online表和ets_sale_goods_attribute表)
								   ets_delete_sale_goods_info(GoodsId),
								   ets_delete_sale_goods_attribute(GoodsId),
								   %%发送系统信件
								   Param = [GoodsId, GoodsName, SaleGoods#ets_sale_goods.num, Goods#goods.goods_id],
								   spawn(fun()->sendmail_for_sale(SaleGoods#ets_sale_goods.player_name, goods_onsale_cancel, Param)end),
								   %%添加拍卖物品数据流向记录
								   CancelSaleTime = util:unixtime(),
								   spawn(lib_sale, insert_sale_flow_record, [0, CancelSaleTime, SaleGoods]),
								   [1]
							end;
						2 ->%%拍卖的是元宝或者铜钱
							%% ?DEBUG("~ts", ["lib_sale:cancel_sale_goods 333"]),
							PriceType = SaleGoods#ets_sale_goods.price_type,
							Money = SaleGoods#ets_sale_goods.num,
							case PriceType of
								1 ->%拍卖的是元宝
									%%更新拍卖纪录
									DeleteSaleGoodsList = [{id, SaleId}],
									spawn(fun()->db_agent:delete_sale_goods_record(DeleteSaleGoodsList)end),					
									%%在ets_sale_goods删除记录
									ets_delete_sale_goods_record(SaleId),									
									%%发送系统信件
									Param = [Money],
									spawn(fun()->sendmail_for_sale(SaleGoods#ets_sale_goods.player_name, gold_onsale_cancel, Param)end),
									%%添加拍卖物品数据流向记录
									CancelSaleTime = util:unixtime(),
									spawn(lib_sale, insert_sale_flow_record, [0, CancelSaleTime, SaleGoods]),
									[1];
								2 ->%%拍卖的是铜钱	
									%%更新拍卖纪录
									DeleteSaleGoodsList = [{id, SaleId}],
									spawn(fun()->db_agent:delete_sale_goods_record(DeleteSaleGoodsList)end),
									%%在ets_sale_goods删除记录
									ets_delete_sale_goods_record(SaleId),
									%%发送系统信件
									Param = [Money],
									spawn(fun()->sendmail_for_sale(SaleGoods#ets_sale_goods.player_name, coin_onsale_cancel, Param)end),
									%%添加拍卖物品数据流向记录
									CancelSaleTime = util:unixtime(),
									spawn(lib_sale, insert_sale_flow_record, [0, CancelSaleTime, SaleGoods]),
									[1]
							end
					end
			end
	end.
%% %%更新物品的属性表
%% update_goods_attribute(PlayerId, GoodsAttribute) ->
%% 	GoodsAttributeValue = [{player_id, PlayerId}],
%% 	GoodsAttributeWhereList = [{gid, GoodsAttribute#goods_attribute.gid}],
%% 	db_agent:update_goods_attribute_owner(GoodsAttributeValue, GoodsAttributeWhereList).

%%查找ets中拍卖纪录
get_sale_goods_record(SaleId) ->
	ets:lookup(?ETS_SALE_GOODS, SaleId).
%%删除ets中拍卖纪录
ets_delete_sale_goods_record(SaleId) ->
	ets:delete(?ETS_SALE_GOODS, SaleId).
	

%% -----------------------------------------------------------------
%% 17006 买家买物品
%% -----------------------------------------------------------------
buyer_sale_goods(Status, SaleId) ->
	%% ?DEBUG(" buyer_sale_goods[~p] ", [SaleId]),
	#player{id = PlayerId,
			nickname = BuyerName} = Status,
	%%即时获取玩家的铜币数量！
	[Coin, _GBCoin] = db_agent:query_player_coin(PlayerId),
	[Gold, _Cash] = db_agent:query_player_money(Status#player.id),
	SaleGoodsResult = get_sale_goods_record(SaleId),
	case SaleGoodsResult =:= [] of
		true ->%%物品不存在
			[2, 0, 0, 0];
		false ->
			[SaleGoods] = SaleGoodsResult,			
			if %%您不能买自己拍卖的东西
				SaleGoods#ets_sale_goods.player_id == PlayerId -> 
					[6, 0, 0, 0];
				true ->
					%% ?DEBUG("Good ^_^,the sale record is exist:[~p]", [SaleGoods]),
					%%处理拍卖的过程
					NeedPrice = SaleGoods#ets_sale_goods.price,
					case SaleGoods#ets_sale_goods.sale_type of
						1 ->%%拍卖的是实物
							Num = SaleGoods#ets_sale_goods.num,
							GoodsId = SaleGoods#ets_sale_goods.gid,
							Goods = goods_util:get_goods_by_id(GoodsId),
							%% ?DEBUG("Good get the goods:[~p]", [Goods]),
							if
%% 								Goods =:= {goods} -> [3, 0, 0];
								is_record(Goods, goods) =:= false ->
									[3, 0, 0, 0];
								Goods#goods.num =/= Num ->%%物品数量出错了
									[0, 0, 0, 0];
								true ->
									GoodsName = goods_util:get_goods_name(Goods#goods.goods_id),
									case SaleGoods#ets_sale_goods.price_type of
										1 ->%%是使用铜钱购买
											case NeedPrice > 0 andalso Gold >= 0 andalso Coin >= 0 andalso Coin >= NeedPrice of
												true ->
													{NewRet, NewCoin} = 
														handle_buyer_sale_for_goods(SaleId, Status,
																					SaleGoods#ets_sale_goods.player_name, 
																					Goods, GoodsName, 
																					coin, goods_onsale_succeed_by_coin, NeedPrice),
													case NewRet of
														8 ->
															%%插拍卖成交的日志纪录
															mark_sale_deal(SaleGoods, PlayerId, BuyerName, Gold, Coin, Gold, NewCoin);
														_OtherRet ->
															skip
													end,
													[NewRet, NewCoin, Gold, Num];
												false ->%%您没有足够的铜币
													[4, 0, 0, 0]
											end;
										2 ->%%是使用元宝购买
											case NeedPrice > 0 andalso Gold >= 0 andalso Coin >= 0 andalso Gold >= NeedPrice of
												true ->
													{NewRet, NewGold} = 
														handle_buyer_sale_for_goods(SaleId, Status,
																					SaleGoods#ets_sale_goods.player_name, 
																					Goods, GoodsName,
																					gold, goods_onsale_succeed_by_gold, 
																					NeedPrice),
													case NewRet of
														8 ->
															%%插拍卖成交的日志纪录
															mark_sale_deal(SaleGoods,PlayerId,BuyerName, Gold, Coin, NewGold, Coin);
														_OtherRet ->
															skip
													end,
													[NewRet, Coin, NewGold, Num];
												false ->%%没有足够的元宝
													[5, 0, 0, 0]
											end
									end
							end;
						2 ->%%拍卖的是元宝或者铜钱 
							Money = SaleGoods#ets_sale_goods.num,
							case SaleGoods#ets_sale_goods.price_type of
								1 ->%%拍卖的是元宝，使用铜钱购买
									case NeedPrice > 0 andalso Gold >= 0 andalso Coin >= 0 andalso Coin >= NeedPrice of
											true ->
											%%扣买家的钱，更新玩家信息	
											[NewCoin, NewGold] = 
												handle_buyer_sale_for_corg(SaleId, BuyerName,
																		   Status,
																		   SaleGoods#ets_sale_goods.player_name,
																		   Gold, Coin, Money, NeedPrice, 
																		   gold, coin, gold_buy_succeed, gold_onsale_succeed),
											%%插拍卖成交的日志纪录
													mark_sale_deal(SaleGoods,PlayerId,BuyerName, Gold, Coin, NewGold, NewCoin),
											[9, NewCoin, NewGold, 1];
										false ->%%您没有足够的铜币
											[4, 0, 0, 0]
									end;
								2 ->%%拍卖的是铜钱，使用元宝购买
									case NeedPrice > 0 andalso Gold >= 0 andalso Coin >= 0 andalso Gold >= NeedPrice of
										true ->
											%%扣买家的钱，更新玩家信息
											[NewCoin, NewGold] = 
												handle_buyer_sale_for_corg(SaleId, BuyerName,
																		   Status,
																		   SaleGoods#ets_sale_goods.player_name,
																		   Coin,Gold,Money, NeedPrice, 
																		   coin, gold, coin_buy_succeed, coin_onsale_succeed),
											%%插拍卖成交的日志纪录
													mark_sale_deal(SaleGoods,PlayerId,BuyerName, Gold, Coin, NewGold, NewCoin),
											[9, NewCoin, NewGold, 1];
										false ->%%您没有足够的元宝
												[5, 0, 0, 0]
									end
							end
					end
			end
	end.

%%处理买家买实物
handle_buyer_sale_for_goods(SaleId, BuyerStatus, SalerName, Goods, GoodsName, PriceType, SendMailType, NeedPrice) ->
	%%取附加属性
	GoodsAttributes = ets_get_sale_goods_attribute(Goods#goods.id),
	
	case catch(gen_server:call(BuyerStatus#player.other#player_other.pid_goods, 
							   {'sale_give_goods', BuyerStatus#player.id, Goods, GoodsAttributes})) of
		{ok, 1} ->
			case PriceType of
				coin ->
					NewBuyerStatus = lib_goods:cost_money(BuyerStatus, NeedPrice, coinonly, 1706),
					NewMoney = NewBuyerStatus#player.coin;
				gold ->
					NewBuyerStatus = lib_goods:cost_money(BuyerStatus, NeedPrice, gold, 1706),
					NewMoney = NewBuyerStatus#player.gold
			end,
%% 	%%给买家发信件
%% 	ParamBuy = [GoodsName, GoodsId, Num, GoodsTypeId],
%% 	spawn(fun()->sendmail_for_sale(BuyerName, goods_buy_succeed, ParamBuy)end),
			%%给卖家发信件
			ParamSale = [GoodsName, NeedPrice],
			spawn(fun()->sendmail_for_sale(SalerName, SendMailType, ParamSale)end),
			%%更新拍卖纪录
			DeleteSaleGoodsList = [{id, SaleId}],
			spawn(fun()->db_agent:delete_sale_goods_record(DeleteSaleGoodsList)end),
			%%在ets_sale_goods删除记录
			ets_delete_sale_goods_record(SaleId),
			%%删除拍卖表中的物品属性信息(删除ets_sale_goods_online表和ets_sale_goods_attribute表)
			ets_delete_sale_goods_info(Goods#goods.id),
			ets_delete_sale_goods_attribute(Goods#goods.id),
			{8, NewMoney};
		{ok, Result} ->
			{Result, 0};
		_Error ->
			{0, 0}
	end.

%%处理买家买铜币或者元宝
handle_buyer_sale_for_corg(SaleId, _BuyerName, BuyerStatus, SalerName, _OldMoney, _OldOwnPrice,
						    Money, NeedPrice, _MoneyType, PriceType, _SendMailBuyerType, SendMaildSaleType) ->
	case PriceType of
		coin ->
			NewBuyerStatus0 = lib_goods:cost_money(BuyerStatus, NeedPrice, coinonly, 1706),
			NewBuyerStatus = lib_goods:add_money(NewBuyerStatus0, Money, gold, 1706),
			NewPrice = NewBuyerStatus#player.coin,
			NewMoney = NewBuyerStatus#player.gold;
		gold ->
			NewBuyerStatus0 = lib_goods:cost_money(BuyerStatus, NeedPrice, gold, 1706),
			NewBuyerStatus = lib_goods:add_money(NewBuyerStatus0, Money, coinonly, 1706),
			NewPrice = NewBuyerStatus#player.gold,
			NewMoney = NewBuyerStatus#player.coin
	end,
	%%通知客户端更新玩家属性
%% 	lib_player:send_player_attribute2(NewBuyerStatus, 2),
	
%% 	%%给买家发信件
%% 	ParamBuy = [Money],
%% 	spawn(fun()->sendmail_for_sale(BuyerName, SendMailBuyerType, ParamBuy)end),
	%%给卖家发信件
	case SendMaildSaleType of
		gold_onsale_succeed ->%%拍卖元宝成功
			ParamSale = [Money, NeedPrice],
			Result = [NewPrice, NewMoney];
		coin_onsale_succeed ->%%拍卖铜币成功
			ParamSale = [NeedPrice, Money],
			Result = [NewMoney, NewPrice]
	end,
	spawn(fun()->sendmail_for_sale(SalerName, SendMaildSaleType, ParamSale)end),
	%%更新拍卖纪录
	DeleteSaleGoodsList = [{id, SaleId}],
	spawn(fun()->db_agent:delete_sale_goods_record(DeleteSaleGoodsList)end),
	%%在ets_sale_goods删除记录
	ets_delete_sale_goods_record(SaleId),
	Result.


%%插拍卖成交的日志纪录
mark_sale_deal(SaleGoods, PlayerId, BuyerName, GoldBef, CoinBef, GoldAft, CoinAft) ->
	%% ?DEBUG(" mark_sale_deal now  ", []),
	#ets_sale_goods{id = SaleId,
				%	sale_type = SaleType,
					gid = GoodsId,
					goods_id = BaseGoodsId,
					goods_name = GoodsName,
					player_id = SalerId,
					player_name = SalerName,
					num = Num,
					price_type = PriceType,
					price = Price} = SaleGoods,
	DealTime = util:unixtime(),
	FieldsList = [sale_id, buyer_id, saler_id, buyer_name, saler_name,
				  deal_time, gid, goods_id, goods_name, num, price_type, price, 
				  buyer_gold_bef,  buyer_gold_aft, buyer_coin_bef, buyer_coin_aft],
	ValuesList = [SaleId, PlayerId, SalerId, BuyerName, SalerName,
				  DealTime, GoodsId, BaseGoodsId, GoodsName, Num, PriceType, Price, GoldBef, GoldAft, CoinBef, CoinAft],
	%% ?DEBUG("~p,, ~p",[FieldsList, ValuesList]),
	db_agent:mark_sale_deal(FieldsList, ValuesList),
	%%添加拍卖物品数据流向记录
	spawn(lib_sale, insert_sale_flow_record, [2, DealTime, SaleGoods]).
	
%%17006 拍卖购买物品进入物品背包
sale_give_goods(PlayerId, Goods, GoodsAttributes, GoodsStatus) ->
	[Cell|RemainCells] = GoodsStatus#goods_status.null_cells,
	SortNullCells = lists:sort(RemainCells),
	NewGoodsStatus = GoodsStatus#goods_status{null_cells = SortNullCells},
	ValueList = [{cell, Cell}, {location, 4}, {player_id, PlayerId}],
	FieldList = [{id, Goods#goods.id}],
	
	db_agent:update_goods_owner(ValueList, FieldList),
	NewGoods = Goods#goods{cell = Cell, 
						   location = 4,
						   player_id = PlayerId},
	ets:insert(?ETS_GOODS_ONLINE, NewGoods),
	
	GoodsAttributeValue = [{player_id, PlayerId}],
	GoodsAttributeWhereList = [{gid, Goods#goods.id}],
	db_agent:update_goods_attribute_owner(GoodsAttributeValue, GoodsAttributeWhereList),
	insert_sgg_attr(GoodsAttributes, PlayerId),

	{1, NewGoodsStatus}.

insert_sgg_attr(GoodsAttributes, PlayerId) ->
	lists:foreach(fun(GoodsAttr) ->
						  NewGoodsAttr = GoodsAttr#goods_attribute{player_id = PlayerId},
						  ets:insert(?ETS_GOODS_ATTRIBUTE, NewGoodsAttr)
				  end, GoodsAttributes).

%% 17007 获取物品详细信息(仅在市场拍卖模块用)
get_salegoods_info(MarketType, PidSend, GoodsLists) ->
	GoodsListsNew = lists:map(fun handle_get_salegoods_info/1, GoodsLists),
	{ok, BinData} = pt_17:write(17007, [MarketType, GoodsListsNew]),
	lib_send:send_to_sid(PidSend, BinData).

handle_get_salegoods_info(GoodsRecord) ->
	{SaleId, GoodsId} = GoodsRecord,
	SaleGoodsResult = get_sale_goods_record(SaleId),
	case SaleGoodsResult of
		[] ->
			{{}, 0, []};
		[SaleGoods] ->
			if
				SaleGoods#ets_sale_goods.gid =/= GoodsId ->
					{{}, 0, []};
				true ->
					GoodsInfo = case ets_get_sale_goods_info(GoodsId) of
									[] -> {};
									[GoodsInfoElem] -> GoodsInfoElem
								end,
					GoodsAttributes = ets_get_sale_goods_attribute(GoodsId),
%% 					SuitNum = length(GoodsAttributes),
					{GoodsInfo, 0, GoodsAttributes}
			end
	end.

%%-----------------------------------------------------------------
%%内部处理函数
%%-----------------------------------------------------------------
%%更新交易市场缓存ets_sale_goods表
ets_update_sale_goods(SaleGoodsEts) ->
	ets:insert(?ETS_SALE_GOODS, SaleGoodsEts). 
%%返回ets_sale_goods表中的所有记录
load_sale_goods() -> 
	ets:tab2list(?ETS_SALE_GOODS).

%%交易发送的系统邮件
sendmail_for_sale(PlayerName, Type, Param) ->
	NameList = [tool:to_list(PlayerName)],
	Title = "系统信件",
	ParamNew = 
		case Type of
			goods_onsale_timeout ->%%实物挂售超时
				[GoodsId, GoodsName, Num, GoodsTypeId] = Param,
				Content = io_lib:format("超过了挂售时间，没人购买，物品【~s】退还给你", [GoodsName]),
				[Content, GoodsId, Num, 0, 0, GoodsTypeId];
			gold_onsale_timeout ->%%元宝挂售超时
				[Gold] = Param,
				Content = io_lib:format("超过了挂售时间，没人购买，物品【~p元宝】退还给你", [Gold]),
				[Content, 0, 0, 0, Gold, 0];
			coin_onsale_timeout ->%%铜币挂售超时
				[Coin] = Param,
				Content = io_lib:format("超过了挂售时间，没人购买，物品【~p铜币】退还给你", [Coin]),
				[Content, 0, 0, Coin, 0, 0];
			goods_onsale_cancel ->%%实物取消拍卖
				[GoodsId, GoodsName, Num, GoodsTypeId] = Param,
				Content = io_lib:format("您取消了拍卖，物品【~s】退还给你", [GoodsName]),
				[Content, GoodsId, Num, 0, 0, GoodsTypeId];
			gold_onsale_cancel ->%%元宝取消拍卖
				[Gold] = Param,
				Content = io_lib:format("您取消了拍卖，物品【~p元宝】退还给你", [Gold]),
				[Content, 0, 0, 0, Gold, 0];
			coin_onsale_cancel ->%%铜币取消拍卖
				[Coin] = Param,
				Content = io_lib:format("您取消了拍卖，物品【~p铜币】退还给你", [Coin]),
				[Content, 0, 0, Coin, 0, 0];
			goods_buy_succeed ->%%实物购买成功(给买家发的)
				[GoodsName, GoodsId, Num, GoodsTypeId] = Param,
				Content = io_lib:format("您成功购买了【~s】", [GoodsName]),
				[Content, GoodsId, Num, 0, 0, GoodsTypeId];
			goods_onsale_succeed_by_coin ->%%实物挂售成功(用铜币购买,给卖家发的)
				[GoodsName, Coin] = Param,
				Content = io_lib:format("您成功挂售了【~s】，获得了~p铜币", [GoodsName, Coin]),
				[Content, 0, 0, Coin, 0, 0];
			goods_onsale_succeed_by_gold ->%%实物挂售成功(用元宝购买,给卖家发的)
				[GoodsName, Gold] = Param,
				Content = io_lib:format("您成功挂售了【~s】，获得了~p元宝", [GoodsName, Gold]),
				[Content, 0, 0, 0, Gold, 0];
			gold_buy_succeed ->%%元宝购买成功(给买家发的)
				[Gold] = Param,
				Content = io_lib:format("您成功购买了【~p元宝】", [Gold]),
				[Content, 0, 0, 0, Gold, 0];
			gold_onsale_succeed -> %%元宝挂售成功(给卖家发的)
				[Gold, Coin] = Param,
				Content = io_lib:format("您成功挂售了【~p元宝】，获得了~p铜币", [Gold, Coin]),
				[Content, 0, 0, Coin, 0, 0];
			coin_buy_succeed ->%%铜币购买成功(给买家发的)
				[Coin] = Param,
				Content = io_lib:format("您成功购买了【~p铜币】", [Coin]),
				[Content, 0, 0, Coin, 0, 0];
			coin_onsale_succeed ->%%铜币挂售成功(给卖家发的)
				[Gold, Coin] = Param,
				Content = io_lib:format("您成功挂售了【~p铜币】，获得了~p元宝", [Coin, Gold]),
				[Content, 0, 0, 0, Gold, 0]
		end,
	[NewContent, NewGoodsId, NewNum, NewCoin, NewGold, NewGoodsTypeId] = ParamNew,
	mod_mail:send_sys_mail(NameList, Title, NewContent, NewGoodsId, NewGoodsTypeId, NewNum, NewCoin, NewGold).

%%获取市场交易中查询的物品等级范围（如按等级， 1-9级）{LevelA, LevelB}
get_sale_levels_by_id(GoodsLevelId) ->
	case lists:member(GoodsLevelId, [1,2,3,4,5,6,7,8]) of
		true ->
			GoodsLevels = 
				[{1, {1, 9}},
				 {2, {10, 19}},
				 {3, {20, 29}},
				 {4, {30, 39}},
				 {5, {40, 49}},
				 {6, {50, 59}},
				 {7, {60, 69}},
				 {8, {70, 79}}],
			{value, {_Level,{GoodsLevelA, GoodsLevelB}}} = lists:keysearch(GoodsLevelId, 1, GoodsLevels),
			{do, [GoodsLevelA, GoodsLevelB]};
		false ->
			{undo, [0, 0]}
	end.

%%拍卖物品时，需要交的保管费{N}
get_deduct_by_goods(Type) ->
	case lists:member(Type, [{1,6},{1,12},{1,24},{2,6},{2,12},{2,24}]) of
		true ->
			GoodsDeducts = [{{1,6}, 0.02},
							{{1,12}, 0.035},
							{{1,24}, 0.06},
							{{2,6}, 15},
							{{2,12}, 20},
							{{2, 24}, 25}],
			{value, {_Type, Radix}} = lists:keysearch(Type, 1, GoodsDeducts),
			[Radix];
		false ->%%乱发数据的，直接扣掉100倍
			[100]
	end.

%%拍卖元宝或铜钱时，需要交的保管费{N}
get_deduct_by_money(Type) ->
	case lists:member(Type, [{1,6},{1,12},{1,24},{2,6},{2,12},{2,24}]) of
		true ->
			GoodsDeducts = [{{1,6}, 0.008},
							{{1,12}, 0.015},
							{{1,24}, 0.03},
							{{2,6}, 15},
							{{2,12}, 20},
							{{2, 24}, 25}],
			{value, {_Type, Radix}} = lists:keysearch(Type, 1, GoodsDeducts),
			[Radix];
		false ->%%乱发数据的，直接扣掉100倍
			[100]
	end.
			
		

insert_sale_flow_record(Type, Time, SaleRecord) ->
%% 	io:format("insert the flow record Type:[~p], ~p,\n", [Type, SaleRecord#ets_sale_goods.id]),
	FlowRecord = 
		#ets_log_sale_dir{sale_id = SaleRecord#ets_sale_goods.id,   	     %% 拍卖记录Id	
						  player_id = SaleRecord#ets_sale_goods.player_id,   %% 卖家Id	
						  flow_time = Time,                          		 %% 变动时间	
						  flow_type = Type,                        			 %% 流向类型：1：上架，0：取消或者系统主动下架	
						  sale_type = SaleRecord#ets_sale_goods.sale_type,   %% 拍卖类型（1，实物；2，元宝或铜钱）	
						  gid = SaleRecord#ets_sale_goods.gid,               %% 物品ID，当ID为0时，表示拍卖的为元宝	
						  goods_id = SaleRecord#ets_sale_goods.goods_id,     %% 品物基本类型ID	
						  num = SaleRecord#ets_sale_goods.num,               %% 货币（拍卖的物品是元宝或铜钱时，此值存在数值，不是元宝时，此值为该物品的数量）	
						  price_type = SaleRecord#ets_sale_goods.price_type, %% 拍卖价格类型：1铜钱，2元宝当gid和goods_id都为0时，1表示拍卖的是元宝，2表示拍卖的是铜钱,	
						  price = SaleRecord#ets_sale_goods.price},          %% 拍卖价格	
	db_agent:insert_sale_flow_record(FlowRecord).

get_sale_goods_id(GoodsId) ->
	db_agent:get_sale_goods_id(GoodsId).
	

%%人工手动下架所有的拍卖物品
labour_cancel_all_goods_sale() ->
	mod_sale:cancel_all_goods_sale().
cancel_all_goods_sale() ->
	Records = load_sale_goods(),
	NowTime = util:unixtime(),
	lists:foreach(fun(Elem) ->
						   handle_sale_goods_record_timeout(NowTime, Elem)
				   end, Records).

%%更新交易角色名
change_player_name(PlayerId,NickName) ->
	Pattern = #ets_sale_goods{player_id=PlayerId,_='_'},
	Ets_sale_goodsList = ets:match_object(?ETS_SALE_GOODS, Pattern),
	case Ets_sale_goodsList of
		[] -> [];
		_ ->
			F = fun(Ets_sale_goods) ->
						NewEts_sale_goods = Ets_sale_goods#ets_sale_goods{player_name = NickName},
						ets:insert(?ETS_SALE_GOODS, NewEts_sale_goods),
						db_agent:change_sale_goods_name(PlayerId,NickName)
				end,
			[F(Ets_sale_goods) || Ets_sale_goods <- Ets_sale_goodsList]
	end.

%%
list_hot_goods(Types,Goods,SortType,StartNum,EndNum,_SearchType)->
	%%拍卖表过滤
	GoodsRecords = lists:flatten(get_hot_goods(Types,Goods)),
%% 	?DEBUG("GoodsRecords = ~p",[GoodsRecords]),
	%%按时间倒序一下，越 晚拍的，越靠前
	PartitionGoods = sort_sale_from_time(GoodsRecords),
	%%按照价格类型排序
	LenCheck = length(PartitionGoods),
	case LenCheck > 1 of
		true ->
			case SortType of
				0 ->%%默认的时候是不排序的
					SortPriceSaleGoods = PartitionGoods;
				1 ->%按照价格降序升序
					SortPriceSaleGoods = lists:sort(fun sort_goods_by_price_asc/2, PartitionGoods);
				2 ->%%%按照价格降序
					SortPriceSaleGoods = lists:sort(fun sort_goods_by_price_desc/2, PartitionGoods);
				3 ->%%单价按照升序排序
					SortPriceSaleGoods = lists:sort(fun sort_goods_by_unprice_asc/2, PartitionGoods);
				4 ->%%单价按照降序排序
					SortPriceSaleGoods = lists:sort(fun sort_goods_by_unprice_desc/2, PartitionGoods);
				_ ->%%直接过滤一些非法错误的操作
					SortPriceSaleGoods = PartitionGoods
			end;
		false ->
			SortPriceSaleGoods = PartitionGoods
	end,
	Len = length(SortPriceSaleGoods),
	if 
		Len == 0 ->
			[Len, 0, []];
		Len < StartNum ->
		  [Len, 0, []];
		true ->
			NewSaleGoodsList = lists:sublist(SortPriceSaleGoods, StartNum, EndNum),
			NewLen = length(NewSaleGoodsList),
			[Len, NewLen, NewSaleGoodsList]
	end.

%%热门搜索(Ets)
get_hot_goods(GoodsTypes,Gids) ->
	F_type = fun({Type,Sub},L) ->
					 Ms = ets:fun2ms(fun(E) when E#ets_sale_goods.goods_type =:= Type andalso E#ets_sale_goods.goods_subtype =:= Sub->E end),
					 case ets:select(?ETS_SALE_GOODS, Ms) of
						 [] ->
							 L;
						 Datas ->
							 [Datas|L]
					 end
			 end,
	Tsales = lists:foldl(F_type, [], GoodsTypes),
	F_goods = fun(Gid,L)->
					  Ms = ets:fun2ms(fun(E) when E#ets_sale_goods.goods_id =:= Gid -> E end),
					  case ets:select(?ETS_SALE_GOODS, Ms) of
						  []->
							  L;
						  Datas ->
							  [Datas|L]
					  end
			  end,
	TGoods = lists:foldl(F_goods, [], Gids),
	[TGoods|Tsales].
					  
					  
							 
