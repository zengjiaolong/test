%% Author: xiaomai
%% Created: 2010-10-12
%% Description: 交易市场信息的解包和组包
-module(pt_17).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
%%
%% Exported Functions
%%
-export([write/2, read/2]).

%%
%% API Functions
%%


%%%=========================================================================
%%% 解包函数
%%%=========================================================================

%% -----------------------------------------------------------------
%% 查询市场中存在的物品
%% -----------------------------------------------------------------
read(17001, <<GoodsLevelId:16, Color:16, Career:16, Type:32, SortType:16, StartNum:16, EndNum:16, Bin/binary>>) ->
	%%获取查询的物品名字
	{GoodsName, SubTypeBin} = pt:read_string(Bin),
	
	F = fun(_, {TB, Result}) ->
				<<SubT:32, NewTB/binary>> = TB,
 				{ok, {NewTB, [SubT|Result]}}
		end,
	%%截取子类型的数组
	<<MarketType:16, SubTLen:16, SubTBin/binary>> = SubTypeBin,
	{ok, {_, SubTypeList}} = util:for_new(1, SubTLen, F, {SubTBin, []}),
	
	{ok, [GoodsLevelId, Color, Career, Type, SubTypeList, SortType, GoodsName, MarketType, StartNum, EndNum]};


%% -----------------------------------------------------------------
%% 开始拍卖物品
%% -----------------------------------------------------------------
read(17002, <<GoodsId:32, PriceType:16, Price:32, DeductPrice:32, SaleTime:32, Cell:32>>) ->
	{ok, [GoodsId, PriceType, Price, DeductPrice, SaleTime, Cell]};


%% -----------------------------------------------------------------
%% 开始拍卖元宝或铜币
%% -----------------------------------------------------------------
read(17003, <<Money:32, PriceType:16, Price:32, DeductPrice:32, SaleTime:32, Bin/binary>>) ->
	{Md5Key, _} = pt:read_string(Bin),
	{ok, [Money, PriceType, Price, DeductPrice, SaleTime, Md5Key]};


%% -----------------------------------------------------------------
%% 查看已上架物品（我的上架物品）
%% -----------------------------------------------------------------
read(17004, _R) ->
	{ok, []};


%% -----------------------------------------------------------------
%% 取消拍卖物品
%% -----------------------------------------------------------------
read(17005, <<SaleId:32>>) ->
	{ok, [SaleId]};


%% -----------------------------------------------------------------
%% 买家拍卖物品
%% -----------------------------------------------------------------
read(17006, <<SaleId:32>>) ->
	{ok, [SaleId]};

%% -----------------------------------------------------------------
%% 获取物品详细信息(仅在市场拍卖模块用)
%% -----------------------------------------------------------------
read(17007, <<MarketType:16, Len:16, Bin/binary>>) ->
	 	F = fun(_, {TB, Result}) ->
 				<<SaleId:32, GoodsId:32, NewTB/binary>> = TB,
 				{ok, {NewTB, [{SaleId, GoodsId}|Result]}}
		end,
	{ok, {_, ApplyList}} = util:for_new(1, Len, F, {Bin, []}),
	{ok, [MarketType, ApplyList]};

%% -----------------------------------------------------------------
%% 17008 获取物品属性信息
%% -----------------------------------------------------------------
read(17008, <<GoodsId:32>>) ->
	{ok, [GoodsId]};

%% -----------------------------------------------------------------
%% 17009 求购物品请求
%% -----------------------------------------------------------------
read(17009, <<GoodsId:32, Stren:8, PType:8, Num:16, UnPrice:32, BuyTime:32, Key:16>>) ->
	{ok, [GoodsId, Stren, PType, Num, UnPrice, BuyTime, Key]};

%% -----------------------------------------------------------------
%% 17010 开始求购元宝或铜币
%% -----------------------------------------------------------------
read(17010, <<Num:32, PType:16, UnPrice:32, BuyTime:32>>) ->
	{ok, [Num, PType, UnPrice, BuyTime]};

%% -----------------------------------------------------------------
%% 17011 出卖对应求购物品请求(除了装备)
%% -----------------------------------------------------------------
read(17011, <<BuyId:32, SellNum:32>>) ->
	{ok, [BuyId, SellNum]};

%% -----------------------------------------------------------------
%% 17012 查看已求购物品
%% -----------------------------------------------------------------
read(17012, _R) ->
	{ok, []};

%% -----------------------------------------------------------------
%% 17013 取消求购物品
%% -----------------------------------------------------------------
read(17013, <<BuyId:32>>) ->
	{ok, [BuyId]};

%% -----------------------------------------------------------------
%% 17014 出卖对应求购物品请求(装备类)
%% -----------------------------------------------------------------
read(17014, <<BuyId:32, Gid:32>>) ->
	{ok, [BuyId, Gid]};

%% -----------------------------------------------------------------
%% 17015 物品的最大堆叠数
%% -----------------------------------------------------------------
read(17015, <<GoodsId:32>>) ->
	{ok, [GoodsId]};

%% c >> s:
%%   	int:16 排序类型(1:价格升序，2:价格降序，3:单价升序，4:单价降序，0:不排序)
%%   	int:16 开始位置
%%   	int:16 结束位置
%%  	int:16 搜索类型： 1 => 拍卖 ， 2 => 求购
%%     array( 物品类型
%% 		int32: 类型
%% 		int32: 子类型
%% 	)
%% 	array( 物品ID
%% 		int32: 物品ID
%% 	)
%% -----------------------------------------------------------------
%% 17016 热门搜索
%% -----------------------------------------------------------------
read(17016, <<SortType:16,StartNum:16,EndNum:16,SearchType:16,Bin/binary>>) ->
	<<TypeLen:16,Other/binary>> = Bin,
	F_type = fun(_,[TypeBin,L]) ->
					 <<GoodsType:32,GoodsSubType:32,Rest/binary>> = TypeBin,
					 [Rest,[{GoodsType,GoodsSubType}|L]]
			 end,
	F_goods = fun(_,[GoodsBin,L]) ->
					  <<GoodsId:32,Rest/binary>> = GoodsBin,
					  [Rest,[GoodsId|L]]
			  end,
	[GoodsBin,Types] = lists:foldl(F_type, [Other,[]], lists:seq(1, TypeLen)),
	?DEBUG("PT_17  17016  COME!!,Types = ~p",[Types]),
	<<GoodsLen:16,Other2/binary>> = GoodsBin,
	[_,Goods] = lists:foldl(F_goods, [Other2,[]], lists:seq(1, GoodsLen)),
	?DEBUG("PT_17  17016  COME!!, Goods = ~p",[Goods]),
	{ok, [Types,Goods,SortType,StartNum,EndNum,SearchType]};

%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
read(_Cmd, _R) ->
    {error, no_match}.


%%%=========================================================================
%%% 组包函数
%%%=========================================================================

%% -----------------------------------------------------------------
%% 查询市场中存在的物品
%% -----------------------------------------------------------------
write(17001, [MarketType, Len, DataLen, SortPriceGoods]) ->
	case MarketType of
		1 ->
			GoodsList = lists:map(fun handle_sale_goods/1, SortPriceGoods),
			GoodsListBin = tool:to_binary(GoodsList);
		2 ->
			GoodsList = lists:map(fun handle_buy_goods/1, SortPriceGoods),
			GoodsListBin = tool:to_binary(GoodsList)
	end,
	BinData = <<MarketType:16, Len:16, DataLen:16, GoodsListBin/binary>>,
	 {ok, pt:pack(17001, BinData)};


%% -----------------------------------------------------------------
%% 开始拍卖物品
%% -----------------------------------------------------------------
write(17002, [Result, Coin]) ->
	BinData = <<Result:16, Coin:32>>,
	{ok, pt:pack(17002, BinData)};


%% -----------------------------------------------------------------
%% 开始拍卖元宝或铜币
%% -----------------------------------------------------------------
write(17003, [Result, Coin, Gold]) ->
	BinData = <<Result:16, Coin:32, Gold:32>>,
	{ok, pt:pack(17003, BinData)};


%% -----------------------------------------------------------------
%% 查看已上架物品
%% -----------------------------------------------------------------
write(17004, [Len, Bin]) ->
	BinData = <<Len:16, Bin/binary>>,
	{ok, pt:pack(17004, BinData)};


%% -----------------------------------------------------------------
%% 取消拍卖物品
%% -----------------------------------------------------------------
write(17005, [Result]) ->
	BinData = <<Result:16>>,
	{ok, pt:pack(17005, BinData)};


%% -----------------------------------------------------------------
%% 拍卖物品
%% -----------------------------------------------------------------
write(17006, [Result, Coin, Gold]) ->
	BinData = <<Result:16, Coin:32, Gold:32>>,
	{ok, pt:pack(17006, BinData)};

%% -----------------------------------------------------------------
%% 获取物品详细信息(仅在市场拍卖模块用)
%% -----------------------------------------------------------------
write(17007, [MarketType,GoodsLists]) ->
	Len = length(GoodsLists),
	NewGoodsList = 
		lists:map(fun(GoodsList) -> 
						  {GoodsInfo, SuitNumInit, AttributeList} = GoodsList,
						  pt_15:get_goods_info(GoodsInfo, SuitNumInit, AttributeList) 
				  end,
						  GoodsLists),
	Data = tool:to_binary(NewGoodsList),
	BinData = <<MarketType:16, Len:16, Data/binary>>,
	{ok, pt:pack(17007, BinData)};

%% -----------------------------------------------------------------
%% 17008 获取物品属性信息
%% -----------------------------------------------------------------
write(17008, [Result]) ->
%% 	?DEBUG("17008 result:~p", [Result]),
	{Len, RBin} = handle_17008(Result, [], 1),
	{ok, pt:pack(17008, <<Len:16, RBin/binary>>)};

%% -----------------------------------------------------------------
%% 17009 求购物品请求
%% -----------------------------------------------------------------
write(17009, [Result, Coin, Gold]) ->
%% 	?DEBUG("17009 result:~p, Coin:~p, Gold:~p", [Result, Coin, Gold]),
	BinData = <<Result:16, Coin:32, Gold:32>>,
	{ok, pt:pack(17009, BinData)};

%% -----------------------------------------------------------------
%% 17010 开始求购元宝或铜币
%% -----------------------------------------------------------------
write(17010, [Result, NCoin, NGold]) ->
%% 	?DEBUG("17010:Result:~p, NCoin:~p, NGold:~p", [Result, NCoin, NGold]),
	BinData = <<Result:16, NCoin:32, NGold:32>>,
	{ok, pt:pack(17010, BinData)};

%% -----------------------------------------------------------------
%% 17011 出卖对应求购物品请求(除了装备)
%% -----------------------------------------------------------------
write(17011, [Result, NCoin, NGold]) ->
%% 	?DEBUG("Result:~p, NCoin:~p, NGold:~p", [Result, NCoin, NGold]),
	BinData = <<Result:16, NCoin:32, NGold:32>>,
	{ok, pt:pack(17011, BinData)};

%% -----------------------------------------------------------------
%% 17012 查看已求购物品
%% -----------------------------------------------------------------
write(17012, [SortBuyGoods]) ->
%% 	?DEBUG("SortBuyGoods:~p", [SortBuyGoods]),
	{Len, Bin} = handle_17012(SortBuyGoods, 0, []),
	{ok, pt:pack(17012, <<Len:16, Bin/binary>>)};

%% -----------------------------------------------------------------
%% 17013 取消求购物品
%% -----------------------------------------------------------------
write(17013, [Result]) ->
	BinData = <<Result:16>>,
	{ok, pt:pack(17013, BinData)};

%% -----------------------------------------------------------------
%% 17014 出卖对应求购物品请求(装备类)
%% -----------------------------------------------------------------
write(17014, [Result]) ->
%% 	?DEBUG("17014:~p ", [Result]),
	BinData = <<Result:16>>,
	{ok, pt:pack(17014, BinData)};

%% -----------------------------------------------------------------
%% 17015 物品的最大堆叠数
%% -----------------------------------------------------------------
write(17015, [GoodsId, MaxOverLap]) ->
	BinData = <<GoodsId:32, MaxOverLap:32>>,
	{ok, pt:pack(17015, BinData)};

%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.


%%
%% Local Functions
%%

handle_17012([], Num, Result) ->
	{Num, tool:to_binary(Result)};
handle_17012([Elem|SortBuyGoods], Num, Result) ->
	#ets_buy_goods{id = Id,
				   gid = Gid,
				   num = SellNum,
				   gname = GName,
				   glv = Glv,
				   gcolor = GColor,
				   career = Career,
				   price_type = PType,
				   gstren = GStren,
				   unprice = UnPrice} = Elem,
	GNBin = tool:to_binary(GName),
	GNLen = byte_size(GNBin),
	EBin = <<Id:32, 0:32, Gid:32, SellNum:32, GNLen:16, GNBin/binary, 
			 Glv:32, GColor:16, Career:16, PType:16, UnPrice:32, GStren:16>>,
	handle_17012(SortBuyGoods, Num+1, [EBin|Result]).
	
%%处理返回的每条拍卖纪录
handle_sale_goods(SaleGoods) ->
	#ets_sale_goods{id = Id,
					gid = GoodsId,
					goods_id = BaseGoodsId,
					num = Num,
					goods_name = GoodsName,
					goods_level = GoodsLevel,
					goods_color = GoodsColor,
					career = Career,
					price_type = PriceType,
					price = Price} = SaleGoods,
	GoodsNameBin = tool:to_binary(GoodsName),
	GoodsNameLen = byte_size(GoodsNameBin),
%% 	?DEBUG("SaleId[~p],GoodsId[~p], BaseGoodsId[~p], num[~p], GoodsName[~ts], GoodsLevel[~p], GooodsColor[~p],Career[~p],PriceType[~p], Price[~p]",
%% 		   [Id, GoodsId, BaseGoodsId, Num, GoodsName, GoodsLevel, GoodsColor, Career, PriceType, Price]),
	<<Id:32, GoodsId:32, BaseGoodsId:32, Num:32, GoodsNameLen:16, GoodsNameBin/binary, 
	  GoodsLevel:32, GoodsColor:16, Career:16, PriceType:16, Price:32, 0:16>>.

handle_buy_goods(BuyGoods) ->
	#ets_buy_goods{id = Id,
				   gid = GoodsId,
				   num = Num,
				   gname = GName,
				   glv = Glv,
				   gcolor = GColor,
				   career = Career,
				   gstren = Stren,
				   price_type = PType,
				   unprice = UnPrice} = BuyGoods,
	GNameBin = tool:to_binary(GName),
	GNameLen = byte_size(GNameBin),
%% 	?DEBUG("SaleId[~p],GoodsId[~p], BaseGoodsId[~p], num[~p], GoodsName[~ts], GoodsLevel[~p], GooodsColor[~p],Career[~p],PriceType[~p], Price[~p]",
%% 		   [Id, GoodsId, BaseGoodsId, Num, GoodsName, GoodsLevel, GoodsColor, Career, PriceType, Price]),
	<<Id:32, 0:32, GoodsId:32, Num:32, GNameLen:16, GNameBin/binary, 
	  Glv:32, GColor:16, Career:16, PType:16, UnPrice:32, Stren:16>>.

%%17008协议数据处理
handle_17008([], Result, _Num) ->
	{length(Result), tool:to_binary(Result)};
handle_17008([Elem|Rest], Result, Num) ->
	{ELen, ERBin} = handle_17008_inside(Elem, []),
	handle_17008(Rest, [<<Num:16, ELen:16, ERBin/binary>>|Result], Num+1).
handle_17008_inside([], Result) ->
	{length(Result), tool:to_binary(Result)};
handle_17008_inside([Elem|Rest], Result) ->
	{AId, Value} = Elem,
	handle_17008_inside(Rest, [<<AId:16, Value:32>>|Result]).
