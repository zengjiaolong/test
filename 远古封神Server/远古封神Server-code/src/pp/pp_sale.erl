%% Author: xiaomai
%% Created: 2010-10-12
%% Description: 拍卖市场
-module(pp_sale).

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

%% -----------------------------------------------------------------
%% 查询市场中存在的物品
%% -----------------------------------------------------------------
handle(17001, Status, [GoodsLevelId, Color, Career, Type, SubTypeList, SortType, GoodsName, MarketType, StartNum, EndNum]) -> 
	%% 	?DEBUG("Type:~p, SubTypeList:~w", [Type, SubTypeList]),
	case MarketType of
		1 ->%%市场拍卖的
			[Len, DataLen, Data] =
				mod_sale:list_sale_goods([GoodsLevelId, Color, Career, Type, SubTypeList, 
										  SortType, GoodsName, StartNum, EndNum]),
			{ok, BinData} = pt_17:write(17001, [MarketType, Len, DataLen, Data]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok;
		2 ->%%市场求购的
			[Len, DataLen, Data] =
				mod_buy:list_buy_goods([GoodsLevelId, Color, Career, Type, SubTypeList, 
										SortType, GoodsName, StartNum, EndNum]),
			{ok, BinData} = pt_17:write(17001, [MarketType, Len, DataLen, Data]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok;
		_ ->%%不知道是什么东西
			ok
	end;


%% -----------------------------------------------------------------
%% 开始拍卖物品
%% -----------------------------------------------------------------
handle(17002, Status, [GoodsId, PriceType, Price, DeductPrice, SaleTime, Cell]) ->
	IsPriceType = lists:member(PriceType, [1, 2]),
	IsSaleTIme = lists:member(SaleTime, [6,12,24]),
	case tool:is_operate_ok(pp_17002, 1) 
			 andalso IsPriceType =:= true 
			 andalso IsSaleTIme =:= true of
		true ->
			[Result, Coin, Num] = mod_sale:sale_goods(Status, [GoodsId, PriceType, Price, DeductPrice, SaleTime, Cell]),
			
			%% 	?DEBUG("handle 17002 result:~p  Coin: ~p~n", [Result, Coin]),
			case Result of
				1 ->%%成功
					NewStatus = Status#player{coin = Coin},
					{ok, BinData} = pt_17:write(17002, [Result, Coin]),
					
					%%市场挂售成就统计
					lib_achieve:check_achieve_finish(Status#player.other#player_other.pid_send,Status#player.id, 507, [Num]),
					
					%% 			%%向物品进程发消息,拍卖为2
					%% 			erlang:send_after(1000 * 10 , NewStatus#player.other#player_other.pid_goods ,{'mem_diff',2}),
					lib_send:send_to_sid(NewStatus#player.other#player_other.pid_send, BinData),			
					{ok, NewStatus};
				_ ->
					{ok, BinData} = pt_17:write(17002, [Result, Coin]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),			
					ok
			end;
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 开始拍卖元宝或铜币
%% -----------------------------------------------------------------
handle(17003, Status, [Money, PriceType, Price, DeductPrice, SaleTime, Md5Key]) ->
	IsPriceType = lists:member(PriceType, [1, 2]),
	IsSaleTIme = lists:member(SaleTime, [6,12,24]),
	case tool:is_operate_ok(pp_17003, 1) 
			 andalso IsPriceType =:= true 
			 andalso IsSaleTIme =:= true of
		true ->
			[Result, Coin, Gold] = mod_sale:sale_money(Status, [Money, PriceType, Price, DeductPrice, SaleTime, Md5Key]),
			{ok, BinData} = pt_17:write(17003, [Result, Coin, Gold]),
			case Result of
				1 ->
					NewStatus = Status#player{coin = Coin,
											  gold = Gold},
					%%市场挂售成就统计
					lib_achieve:check_achieve_finish(Status#player.other#player_other.pid_send,Status#player.id, 507, [1]),
					
					lib_send:send_to_sid(NewStatus#player.other#player_other.pid_send, BinData),	
					{ok, NewStatus};
				_ ->
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					ok
			end;
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 查看已上架物品（我的上架物品）
%% -----------------------------------------------------------------
handle(17004, Status, []) ->
	[Len, Data] = mod_sale:list_sale_goods_self(Status),
	{ok, BinData} = pt_17:write(17004, [Len, Data]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),			
	ok;

%% -----------------------------------------------------------------
%% 取消拍卖物品
%% -----------------------------------------------------------------
handle(17005, Status, [SaleId]) ->
	case tool:is_operate_ok(pp_17005, 1) of
		true ->
			[Result] = mod_sale:cancel_sale_goods(Status, [SaleId]),
			{ok, BinData} = pt_17:write(17005, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
		false ->
			skip
	end,
	ok;

%% -----------------------------------------------------------------
%% 买家买物品
%% -----------------------------------------------------------------
handle(17006, Status, [SaleId]) ->
	case tool:is_operate_ok(pp_17006, 1) of
		true ->
			[Result, Coin, Gold, Num] = mod_sale:buyer_sale_goods(Status, [SaleId]),
			{ok, BinData} = pt_17:write(17006, [Result, Coin, Gold]),
			case Result of
				Val when Val =:= 1 orelse Val =:= 8 orelse Val =:= 9->
					NewStatus = Status#player{coin = Coin,
											  gold = Gold},
					%%市场挂售成就统计
					lib_achieve:check_achieve_finish(Status#player.other#player_other.pid_send,Status#player.id, 508, [Num]),
					%% 			%%向物品进程发消息,拍卖为2
					%% 			erlang:send_after(1000 * 10 , NewStatus#player.other#player_other.pid_goods ,{'mem_diff',2}),
					
					lib_send:send_to_sid(NewStatus#player.other#player_other.pid_send, BinData),
					{ok, NewStatus};
				_ ->
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					ok
			end;
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 获取物品详细信息(仅在市场拍卖模块用)
%% -----------------------------------------------------------------
handle(17007, Status, [MarketType, GoodsLists]) ->
	case MarketType of
		1 ->%%拍卖的
			mod_sale:get_salegoods_info(Status, [MarketType, GoodsLists]),
			ok;
		2 ->%%求购的
			mod_buy:get_buygoods_info(Status, [MarketType, GoodsLists]),
			ok;
		_ ->
			ok
	end;

%% -----------------------------------------------------------------
%% 17008 获取物品属性信息
%% -----------------------------------------------------------------
handle(17008, Status, [GoodsId]) ->
	if
		GoodsId =< 0 ->
			skip;
		true ->
%% 			?DEBUG("the goods id is :~p", [GoodsId]),
			mod_buy:get_buy_goods_attributes(Status, GoodsId)
	end,
	ok;

%% -----------------------------------------------------------------
%% 17009 求购物品请求
%% -----------------------------------------------------------------
handle(17009, Status, [GoodsId, Stren, PType, Num, UnPrice, BuyTime, Key]) ->
%% 	?DEBUG("GoodsId:~p, Stren:~p, PType:~p, Num:~p, UnPrice:~p, BuyTime:~p, Key:~p", [GoodsId, Stren, PType, Num, UnPrice, BuyTime, Key]),
	case tool:is_operate_ok(pp_17009, 1) of
		true ->
			if 
				BuyTime =/= 6 andalso BuyTime =/= 12 andalso BuyTime =/= 24 ->
					{ok, BinData} = pt_17:write(17009, [5, Status#player.coin, Status#player.gold]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					ok;
				GoodsId =< 0 orelse Stren < 0 orelse Stren > 10 %%物品数据有问题
					orelse PType =< 0 orelse PType >= 3 orelse Num =< 0 %%类型和数量有问题
					orelse UnPrice =< 0 -> %%价格有问题
					{ok, BinData} = pt_17:write(17009, [5, Status#player.coin, Status#player.gold]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					ok;
				(BuyTime =:= 6 orelse BuyTime =:= 12 orelse BuyTime =:= 24) =:= false ->%%求购的时间有问题
					{ok, BinData} = pt_17:write(17009, [5, Status#player.coin, Status#player.gold]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					ok;
				true ->
					case lib_buy:get_goods_attributes(GoodsId) of %%获得额外的属性判断
						{ok, [], Param, IsStren, IsEquip} ->
							if 
								IsStren =:= true andalso Stren =/= 0 ->
									%%不可强化的，但是却发强化的数据
									{ok, BinData} = pt_17:write(17009, [8, Status#player.coin, Status#player.gold]),
									lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
									ok;
								IsEquip =:= true andalso Num =/= 1 ->
									{ok, BinData} = pt_17:write(17009, [5, Status#player.coin, Status#player.gold]),
									lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
									ok;
								true ->
									case Key  =:= 0 of
										false ->%%属性都对不上，有问题
											{ok, BinData} = pt_17:write(17009, [3, Status#player.coin, Status#player.gold]),
											lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
											ok;
										true ->
											{Result, NewStatus} = 
												mod_buy:buy_goods_request(Status, GoodsId, Stren, PType, Num, UnPrice, BuyTime, Key, Param),
											{ok, BinData} = pt_17:write(17009, [Result, NewStatus#player.coin, NewStatus#player.gold]),
											lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
											{ok, NewStatus}
									end
							end;
						{ok, GALists, Param, IsStren, IsEquip} ->
							if 
								IsStren =:= true andalso Stren =/= 0 ->
									%%不可强化的，但是却发强化的数据
									{ok, BinData} = pt_17:write(17009, [8, Status#player.coin, Status#player.gold]),
									lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
									ok;
								IsEquip =:= true andalso Num =/= 1 ->
									{ok, BinData} = pt_17:write(17009, [5, Status#player.coin, Status#player.gold]),
									lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
									ok;
								true ->
									case lib_buy:check_attributes(GALists, Key) of
										{ok, _NeedAttr} ->%%冇问题
											{Result, NewStatus} = 
												mod_buy:buy_goods_request(Status, GoodsId, Stren, PType, Num, UnPrice, BuyTime, Key, Param),
											{ok, BinData} = pt_17:write(17009, [Result, NewStatus#player.coin, NewStatus#player.gold]),
											lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
											{ok, NewStatus};
										{fail, _Fail}->%%有问题
											{ok, BinData} = pt_17:write(17009, [3, Status#player.coin, Status#player.gold]),
											lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
											ok
									end
							end;
						_Other ->
							{ok, BinData} = pt_17:write(17009, [3, Status#player.coin, Status#player.gold]),
							lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
							ok
					end
			end;
		false ->%%太快了，亲
			{ok, BinData} = pt_17:write(17009, [4, Status#player.coin, Status#player.gold]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok
	end;


%% -----------------------------------------------------------------
%% 17010 开始求购元宝或铜币
%% -----------------------------------------------------------------
handle(17010, Status, [Num, PType, UnPrice, BuyTime]) ->
%% 	?DEBUG("Num:~p, PType:~p, UnPrice:~p, BuyTime:~p", [Num, PType, UnPrice, BuyTime]),
	case tool:is_operate_ok(pp_17010, 1) of
		true ->%%数据校验
			case Num > 0 andalso PType >= 1 andalso PType =< 2 andalso UnPrice > 0 
					 andalso (BuyTime  =:= 6 orelse BuyTime =:= 12 orelse BuyTime =:= 24) of
				true ->
					{Result, NewStatus} = mod_buy:buy_cash_request(Status, Num, PType, UnPrice, BuyTime),
					#player{coin = NCoin, 
							gold = NGold} = NewStatus,
					{ok, BinData17010} = pt_17:write(17010, [Result, NCoin, NGold]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData17010),
					{ok, NewStatus};
				false ->%%数据有问题
					#player{coin = NCoin,
							gold = NGold} = Status,
					{ok, BinData17010} = pt_17:write(17010, [5, NCoin, NGold]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData17010),
					ok
			end;
		false ->
			#player{coin = NCoin, 
					gold = NGold} = Status,
			{ok, BinData17010} = pt_17:write(17010, [9, NCoin, NGold]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData17010),
			ok
	end;

%% -----------------------------------------------------------------
%% 17011 出卖对应求购物品请求(除了装备)
%% -----------------------------------------------------------------
handle(17011, Status, [BuyId, SellNum]) ->
%% 	?DEBUG("BuyId:~p, SellNum:~p", [BuyId, SellNum]),
	case tool:is_operate_ok(pp_17011, 1) of
		true ->
			if SellNum =< 0 ->%%数量有问题
				   {ok, BinData17011} = pt_17:write(17011, [11, Status#player.coin, Status#player.gold]),
				   lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData17011),
				   ok;
			   true ->
				   {Result, NewStatus} = mod_buy:submit_buy_goods(Status, BuyId, SellNum),
				   {ok, BinData17011} = pt_17:write(17011, [Result, NewStatus#player.coin, NewStatus#player.gold]),
				   lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData17011),
				   {ok, NewStatus}
			end;
		false ->
			{ok, BinData17011} = pt_17:write(17011, [7, Status#player.coin, Status#player.gold]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData17011),
			ok
	end;
%% -----------------------------------------------------------------
%% 17012 查看已求购物品
%% -----------------------------------------------------------------
handle(17012, Status, []) ->
	case tool:is_operate_ok(pp_17012, 1) of
		true ->
			mod_buy:list_buy_goods_self(Status),
			ok;
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 17013 取消求购物品
%% -----------------------------------------------------------------
handle(17013, Status, [BuyId]) ->
	case BuyId =< 0 of%%值有问题的，直接忽略
		false ->
			case tool:is_operate_ok(pp_17013, 1) of
				true ->
					mod_buy:cancel_buy_goods(Status, BuyId),
					ok;
				false ->
					ok
			end;
		true ->
			ok
	end;

%% -----------------------------------------------------------------
%% 17014 出卖对应求购物品请求(装备类)
%% -----------------------------------------------------------------
handle(17014, Status, [BuyId, Gid]) ->
%% 	?DEBUG("17014 BuyId:~p, Gid:~p", [BuyId, Gid]),
	case tool:is_operate_ok(pp_17014, 1) of
		true ->
			if BuyId =< 0 orelse Gid =< 0 ->
				   {ok, BinData17014} = pt_17:write(17014, [11]),
				   lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData17014),
				   ok;
			   true ->
				   Result = mod_buy:submit_buy_goods_equip(Status, BuyId, Gid),
				   {ok, BinData17014} = pt_17:write(17014, [Result]),
				   lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData17014),
				   ok
			end;
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 17015 物品的最大堆叠数
%% -----------------------------------------------------------------
handle(17015, Status, [GoodsId]) ->
	lib_buy:get_buy_goods_maxoverlap(Status#player.other#player_other.pid_send, GoodsId),
	ok;

%% -----------------------------------------------------------------
%% 17016 热门搜索
%% -----------------------------------------------------------------
handle(17016, Status, [Types,Goods,SortType,StartNum,EndNum,SearchType]) ->
	case SearchType of
		1 ->%%市场拍卖的
			[Len, DataLen, Data] =
				mod_sale:list_hot_goods(Types,Goods,SortType,StartNum,EndNum,SearchType),
			{ok, BinData} = pt_17:write(17001, [SearchType, Len, DataLen, Data]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok;
		2 ->%%市场求购的
			[Len, DataLen, Data] =
				mod_buy:list_hot_goods(Types,Goods,SortType,StartNum,EndNum,SearchType),
			{ok, BinData} = pt_17:write(17001, [SearchType, Len, DataLen, Data]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok;
		_ ->%%不知道是什么东西
			ok
	end;	

%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
handle(_Cmd, _Status, _Data) ->
	?DEBUG("pp_sale no match:~p", [_Cmd]),
	{error, "pp_sale no match"}.
%%
%% Local Functions
%%

