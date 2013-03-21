%% Author: xiaomai
%% Created: 2010-10-21
%% Description: 交易处理函数（点对点）
-module(lib_trade).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
%%交易栏格子总数
-define(TRADE_NUM_LIMIT, 15).

%%
%% Exported Functions
%%
-export([deal_origination/6, 	%% 18000 发起交易请求
		 request_trade/6,		%% 18002 确定接受交易
		 goods_trade/8,			%% 18003 交易物品操作
		 execute_trade/2,		%% 18008 实施交易
		 goods_undo/4,			%% 18012 拖出物品操作
		 mark_trade_deal/13,		%%交易日志记录函数
		 reload_goods_for_trade/3,
		 trade_set_and_send/2,
		 get_trade_limit/1
		 ]).

 %%-compile([export_all]).

%%
%% API Functions
%%
%% -----------------------------------------------------------------
%% 18000 发起交易请求
%% -----------------------------------------------------------------
deal_origination(APlayerId, Astatus, ATradestatus, ACoin, AGold, BPlayerId) ->
	{Atrade, _IdB} = ATradestatus,
	IsWarServer = lib_war:is_war_server(),
	if%%不准与自己交易
		APlayerId == BPlayerId -> [0,[]];
		%%发起方是否已经在交易
		Atrade /= 0 -> [3, []];
		%%发起方正在战斗中
		Astatus == 2 -> [4, []];
		Astatus == 4 -> [4, []];
		Astatus == 5 -> [4, []];
		%%自己在凝神修炼
		Astatus == 7 -> [5, []];
		%%本身账号元宝和铜币出现异常了
		ACoin < 0 -> [6, []];
		AGold < 0 -> [6, []];
		IsWarServer ->[6,[]];%%跨服不能交易
		true ->
			case lib_player:get_online_info_fields(BPlayerId, [status, trade_status, pid])of
				%%对方不在线
				[] -> [2, []];
				[Bstatus, {BTrade, _IdA}, Pid] ->
					if 
						%%对方正在战斗中
						Bstatus == 2 -> [0, []];
						Bstatus == 4 -> [0, []];
						Bstatus == 5 -> [0, []];
						%%对方死亡
						Bstatus == 3 -> [0, []];
						%%对方正在交易中
						BTrade /= 0 -> [0, []];
						%%对方在凝神修炼中
						Bstatus == 7 -> [0, []];
						true ->
							[1, Pid]
					end
			end
	end.

%% -----------------------------------------------------------------
%% 18002 确定接受交易
%% -----------------------------------------------------------------
request_trade(Bstatus, BTradestatus, BCoin, BGold, HandleResult, APlayerId) ->
	APlayerStatus = lib_player:get_online_info(APlayerId),
	{BTrade, _IdA} = BTradestatus,
	case HandleResult of
		0 ->%%拒绝			
			case APlayerStatus of
				[] ->%%发起方已经不在线
					[2, {}];
				_ ->
					[1, APlayerStatus]
			end;
		1 ->%%同意交易
			case APlayerStatus of
				[] ->%%发起方已经不在线
					[2,{}];
				_ ->
					%Astatus = APlayerStatus#player.status,
					Astatus = lib_player:player_status(APlayerStatus),
					{ATrade, _IdB} = APlayerStatus#player.other#player_other.trade_status,
					if %%A在战斗中
						Astatus == 2 -> [3, {}];
						Astatus == 4 -> [3, {}];
						Astatus == 5 -> [3, {}];
						%%A在交易中
						ATrade /= 0 -> [3, {}];
						%%A在神修炼中
						Astatus == 7 -> [3, {}];
						%%B在战斗中
						Bstatus == 2 -> [5, {}];
						Bstatus == 4 -> [5, {}];
						Bstatus == 5 -> [5, {}];
						%%B在交易中
						BTrade /= 0 -> [4, {}];
						%%B在神修炼中
						Bstatus == 7 -> [6, {}];
						%%本身账号元宝或铜币异常了
						BCoin < 0 -> [7, APlayerStatus];
						BGold < 0 -> [7, APlayerStatus];
						true ->
							[1, APlayerStatus]
					end
			end;
		_ ->%%错误处理
			error
	end.

%% -----------------------------------------------------------------
%% 18003 交易物品操作
%% -----------------------------------------------------------------
goods_trade(APlayerId, ATradeList, ACoin, AGold, GoodsType, GoodsId, GoodsNum, BPlayerId) ->
	BPlayerStatus = lib_player:get_online_info(BPlayerId),
	if 
		GoodsNum < 0 -> %%数据有误了
			[0, [], {}];
		true ->
			case BPlayerStatus of
				[] -> %%对方已经下线了
					[0, [], {}];
				_ ->
					Len = get_trade_goods_num(2, ATradeList),
					case GoodsType of
						1 ->
							if GoodsId == 1  ->
								   money_trade(GoodsType, GoodsId, GoodsNum, ATradeList, AGold, BPlayerStatus);
							   GoodsId == 2 ->
								   money_trade(GoodsType, GoodsId, GoodsNum, ATradeList, ACoin, BPlayerStatus);
							   true ->
								   error
							end;
						2 ->
							if GoodsId > 0 ->
								   GoodsInfo = goods_util:get_goods(GoodsId),
								   IsSame2 = lists:keymember({GoodsId, 2, GoodsType}, 1, ATradeList), 
								   IsSame1 = lists:keymember({GoodsId, 1, GoodsType}, 1, BPlayerStatus#player.other#player_other.trade_list), 
								   if %%交易栏格子已满
									   Len >= ?TRADE_NUM_LIMIT -> [2, [], {}];
									   %%背包中没有该物品
									   GoodsInfo =:= {} -> [3,[],{}];
									   true -> %%oh yeah,交易栏格子还未满哦
										   if GoodsInfo#goods.bind == 2  ->
												  [5, [], {}];%%物品是绑定的
											  GoodsInfo#goods.trade == 1 ->
												  [6, [], {}];%%不可交易
											  GoodsInfo#goods.num =/= GoodsNum ->
												  [0, [], {}];%%物品数量出错
											  GoodsInfo#goods.player_id =/= APlayerId ->
												  [0, [], {}];%%物品出错，不是本人的
											  GoodsInfo#goods.location =/= 4 ->
												  [0, [], {}];%%物品不在背包里
											  IsSame2 =:= true orelse IsSame1 =:= true ->
												   [0, [], {}];%%物品出错，同一件物品重复提交
											  true ->
												  BaseGoodsTypeId = GoodsInfo#goods.goods_id,
												  NewATradeList = [{{GoodsId, 2, GoodsType}, GoodsNum, 2, BaseGoodsTypeId}|ATradeList],
												  BTradeList = BPlayerStatus#player.other#player_other.trade_list,
												  NewBTradeList = [{{GoodsId, 1, GoodsType}, GoodsNum, 1, BaseGoodsTypeId}|BTradeList],
												  NewBPlayerStatus = BPlayerStatus#player{other = BPlayerStatus#player.other#player_other{trade_list = NewBTradeList}},
												  [1, NewATradeList, NewBPlayerStatus]
										   end
								   end;
							   true ->
								   [3,[],{}]
							end;
						_ -> 
							error
					end
			end
	end.

%%物品操作中的元宝或者铜钱操作
money_trade(GoodsType, GoodsId, GoodsNum, ATradeList, Money, BPlayerStatus) ->
	if%%元宝或者铜钱不够
		GoodsNum < 0  orelse Money < 0 orelse abs(GoodsNum) > abs(Money)  ->
			[4, [], {}];
		true ->
			if GoodsNum =:= 0 ->
				   %%删除原来的元宝或者铜钱记录(如果有),直接清零
				   BTradeList = BPlayerStatus#player.other#player_other.trade_list,
				   ATradeListRest = lists:keydelete({GoodsId, 2, GoodsType}, 1, ATradeList),
				   BTradeListRest = lists:keydelete({GoodsId, 1, GoodsType}, 1, BTradeList),
				   NewBPlayerStatus = BPlayerStatus#player{other = BPlayerStatus#player.other#player_other{trade_list = BTradeListRest}},
				   [1, ATradeListRest, NewBPlayerStatus];
			   true ->
				   %%元宝或者铜币
				   %%先删除原来的元宝或者铜钱记录(如果有)
				   BTradeList = BPlayerStatus#player.other#player_other.trade_list,
				   ATradeListRest = lists:keydelete({GoodsId, 2, GoodsType}, 1, ATradeList),
				   BTradeListRest = lists:keydelete({GoodsId, 1, GoodsType}, 1, BTradeList),
				   %%添加新的元宝或者铜钱记录
				   NewATradeList = [{{GoodsId, 2, GoodsType}, GoodsNum, 2, 0}|ATradeListRest],	
				   NewBTradeList = [{{GoodsId, 1, GoodsType}, GoodsNum, 1, 0}|BTradeListRest],
				   NewBPlayerStatus = BPlayerStatus#player{other = BPlayerStatus#player.other#player_other{trade_list = NewBTradeList}},
				   [1, NewATradeList, NewBPlayerStatus]
			end
	end.

%% -----------------------------------------------------------------
%% 18008 实施交易
%% -----------------------------------------------------------------
execute_trade(APlayerStatus, BPlayerId) ->
	BPlayerStatus = lib_player:get_online_info(BPlayerId),
	case BPlayerStatus of
		[] ->%%玩家已经不在线了,立即取消交易
			NewAPlayerStatus = change_trade_status(APlayerStatus),
			[2, NewAPlayerStatus, {}];
		_ ->
			{BTrade, APlayerIds} = BPlayerStatus#player.other#player_other.trade_status,
			if
				BTrade == 3 ->%%可以开始交易
					ATradeList = APlayerStatus#player.other#player_other.trade_list,
					BTradeList = BPlayerStatus#player.other#player_other.trade_list,
					if length(ATradeList) /= length(BTradeList) ->%%交易失败
						   NewAPlayerStatus = change_trade_status(APlayerStatus),
						   NewBPlayerStatus = change_trade_status(BPlayerStatus),
%% 						   io:format("222222\n"),
						   [0, NewAPlayerStatus, NewBPlayerStatus];
					   true ->%%交易开始
						   APlayerPidGoods = APlayerStatus#player.other#player_other.pid_goods,
						   BPlayerPidGoods = BPlayerStatus#player.other#player_other.pid_goods,
						   %%即时获取玩家的铜币数量！
						   [ACoin, _ABCoin] = db_agent:query_player_coin(APlayerStatus#player.id),
						   [BCoin, _BBCoin] = db_agent:query_player_coin(BPlayerStatus#player.id),
						   [AGold,_ACash] = db_agent:query_player_money(APlayerStatus#player.id),
						   [BGold,_BCash] = db_agent:query_player_money(BPlayerStatus#player.id),
						   ANullCells = gen_server:call(APlayerPidGoods, {'null_cell'}), 
						   BNullCells = gen_server:call(BPlayerPidGoods, {'null_cell'}), 
						   ACellNum = length(ANullCells),
						   BCellNum = length(BNullCells),
						   AInsertNum = get_trade_goods_num(1, ATradeList),
						   BInsertNum = get_trade_goods_num(2, ATradeList),
						   APlayerId = APlayerStatus#player.id,
						   case (ACoin >= 0 andalso AGold >= 0 andalso BCoin >= 0 andalso BGold >= 0) of
							   true ->
								   if 
									   ACellNum < AInsertNum ->%%自己背包格子不够
										   NewAPlayerStatus = APlayerStatus#player{other = APlayerStatus#player.other#player_other{trade_status = {2, BPlayerId}}},
										   NewBPlayerStatus = BPlayerStatus#player{other = BPlayerStatus#player.other#player_other{trade_status = {2, APlayerId}}},
										   [3, NewAPlayerStatus, NewBPlayerStatus];
									   BCellNum < BInsertNum ->%%对方背包格子不够
										   NewAPlayerStatus = APlayerStatus#player{other = APlayerStatus#player.other#player_other{trade_status = {2, BPlayerId}}},
										   NewBPlayerStatus = BPlayerStatus#player{other = BPlayerStatus#player.other#player_other{trade_status = {2, APlayerId}}},
										   [4, NewAPlayerStatus, NewBPlayerStatus];
									   APlayerId /= APlayerIds ->%%出错了
										   NewAPlayerStatus = change_trade_status(APlayerStatus),
										   NewBPlayerStatus = change_trade_status(BPlayerStatus),
%% 										   io:format("333333\n"),
										   [0, NewAPlayerStatus, NewBPlayerStatus];
									   true ->
										   %%修改数据库开始
%% 										   ResultDB = commint_trade(ATradeList, APlayerId, BPlayerId, ANullCells, BNullCells),
										   case commint_trade({ok, {0, 0, 0, 0, []}, {ANullCells, BNullCells}}, ATradeList, APlayerId, BPlayerId, {AGold, ACoin, BGold, BCoin}) of
											   {fail, 1} ->%%物品数据出现更改了，交易终止
												   NewAPlayerStatusChErr = change_trade_status(APlayerStatus),
												   NewBPlayerStatusChErr = change_trade_status(BPlayerStatus),
%% 												   io:format("error~~8\n"),
												   [8, NewAPlayerStatusChErr, NewBPlayerStatusChErr];
											   {fail, 0} ->%%铜币元宝数据出错
												   NewAPlayerStatusChErr = change_trade_status(APlayerStatus),
												   NewBPlayerStatusChErr = change_trade_status(BPlayerStatus),
												   [7, NewAPlayerStatusChErr, NewBPlayerStatusChErr];
											   {ok, ResultDB}->
												   {DBAGold, DBACoin, DBBGold, DBBCoin, DBGoodsRecord} = ResultDB,
												   CheckDBAGold = AGold + DBAGold,
												   CheckDBACoin = ACoin + DBACoin,
												   CheckDBBGold = BGold + DBBGold,
												   CheckDBBCoin = BCoin + DBBCoin,
%% 												   io:format("AG~p,AC~p,BG~p,BC~p\n",[CheckDBAGold,CheckDBACoin,CheckDBBGold,CheckDBBCoin]),
												   case CheckDBAGold >= 0 andalso CheckDBACoin >= 0 andalso CheckDBBGold >= 0 andalso CheckDBBCoin >= 0 of
													   true ->%%在交易中，如果做一些消费操作，则此处重新判断铜币元宝
														   ABCoinGold = {AGold,ACoin,BGold,BCoin},%%玩家交易前的元宝铜币
														   try 
															   db_agent:commint_trade(ResultDB, APlayerId, BPlayerId, ABCoinGold),
															   spawn(fun()->
																	util:sleep(1000),
															   		gen_server:cast(BPlayerPidGoods, 
																			   {'reload_goods', BPlayerId, BPlayerStatus#player.cell_num, DBGoodsRecord}),
															   		gen_server:cast(APlayerPidGoods, 
																			   {'reload_goods', APlayerId, APlayerStatus#player.cell_num, DBGoodsRecord})
															   end),
															   %%修改新的玩家状态
															   ACoinAft = ACoin + DBACoin,
															   AGoldAft = AGold + DBAGold,
															   NewAPlayerStatus = 
																   APlayerStatus#player{coin = ACoinAft,
																						gold = AGoldAft,
																						other = APlayerStatus#player.other#player_other{trade_status = {0, 0}, 
																																		trade_list = []}},
															   BCoinAft = BCoin + DBBCoin,
															   BGoldAft = BGold + DBBGold,
															   NewBPlayerStatus = 
																   BPlayerStatus#player{coin = BCoinAft,
																						gold = BGoldAft,
																						other = BPlayerStatus#player.other#player_other{trade_status = {0, 0},
																																		trade_list = []}},
															   %%添加交易的日志记录
															   spawn(lib_trade, mark_trade_deal, 
																	  [ACoin, AGold, BCoin, BGold, ATradeList, APlayerId, BPlayerId, 
																	    APlayerStatus#player.nickname, BPlayerStatus#player.nickname,
																	    ACoinAft, AGoldAft, BCoinAft, BGoldAft]),
															   [1, NewAPlayerStatus, NewBPlayerStatus]
														   catch 
															   _:_ ->
																   NewAPlayerStatusEr = change_trade_status(APlayerStatus),
																   NewBPlayerStatusEr = change_trade_status(BPlayerStatus),
																   
																   [0, NewAPlayerStatusEr, NewBPlayerStatusEr]
														   end;
													   false ->%%在交易过程中，做了一些其他的消费操作，铜币元宝重新判断
														   NewAPlayerStatusChErr = change_trade_status(APlayerStatus),
														   NewBPlayerStatusChErr = change_trade_status(BPlayerStatus),
														   [7, NewAPlayerStatusChErr, NewBPlayerStatusChErr]
												   end
										   end
								   end; 
							   false ->
								   NewAPlayerStatus = change_trade_status(APlayerStatus),
								   NewBPlayerStatus = change_trade_status(BPlayerStatus),
								   [7, NewAPlayerStatus, NewBPlayerStatus]
						   end
					end;
				BTrade == 1 ->%%对方还未锁定,出错
					NewAPlayerStatus = change_trade_status(APlayerStatus),
					NewBPlayerStatus = change_trade_status(BPlayerStatus),
%% 					io:format("4555555\n"),
					[0, NewAPlayerStatus, NewBPlayerStatus];
				true ->%%对方已经锁定
					NewAPlayerStatus = APlayerStatus#player{other = APlayerStatus#player.other#player_other{trade_status = {3, BPlayerId}}},
					[5, NewAPlayerStatus, {}]
			end
	end.

%%获取一方交易的物品个数
get_trade_goods_num(Type, TradeList) ->
	F = fun(Elem, AccIn) -> 
				{{_GoodsId, _TypesCopy, GoodsType}, _Num, Types, _BaseGoodsTypeId} = Elem,
				if 
%% 					GoodsId == 1 orelse GoodsId == 2 ->
					GoodsType =:= 1 ->%%元宝或者铜钱
						AccIn;
					GoodsType =:= 2 ->%%物品
						case Types =:= Type of
							true ->
								AccIn +1;
							false ->%%处理异常
								AccIn
						end;
					true ->%%哎，出错了，不知道什么原因
						AccIn
				end
		end,
	lists:foldr(F, 0, TradeList).

mark_trade_deal(ACoinBef, AGoldBef, BCoinBef, BGoldBef, 
				TradeList, APlayerId, BPlayerId, APlayerName, BPlayerName,
				ACoinAft, AGoldAft, BCoinAft, BGoldAft) ->
	%%io:format("wqerwerqwer\n"),
	FieldsList = [donor_id, gainer_id, donor_name, gainer_name,
				  deal_time, gid, goods_id, type, num,
				  donor_coin_bef, donor_gold_bef, gainer_coin_bef, gainer_gold_bef,
				  donor_coin_aft, donor_gold_aft, gainer_coin_aft, gainer_gold_aft],
	DealTime = util:unixtime(),
	lists:foreach(fun(Trade) ->
						  {{GoodsId, _Type, GoodsType}, GoodsNum, Type, BaseGoodsId} = Trade,
						  %%做插入数据操作
						  case GoodsType of						  
							  1 ->%%元宝或者铜币
								  case Type of
									  1 -> %%别人给自己的，自己相加，别人要减
										  ValuesList = [BPlayerId, APlayerId, BPlayerName, APlayerName,
														DealTime, 0, BaseGoodsId, GoodsId, GoodsNum,
														BCoinBef, BGoldBef, ACoinBef, AGoldBef,
														BCoinAft, BGoldAft, ACoinAft, AGoldAft],
										  db_agent:mark_trade_deal(log_trade, FieldsList, ValuesList);
									  2 ->%%给别人的，别人那里相加，自己这边要减
										  ValuesList = [APlayerId, BPlayerId, APlayerName, BPlayerName,
														DealTime, 0, BaseGoodsId, GoodsId, GoodsNum,
														ACoinBef, AGoldBef, BCoinBef, BGoldBef,
														ACoinAft, AGoldAft, BCoinAft, BGoldAft],
										  db_agent:mark_trade_deal(log_trade, FieldsList, ValuesList)
								  end;
							  2 ->%%实物
								  case Type of%%别人给自己的，自己相加，别人要减
									  1 ->
										  ValuesList = [BPlayerId, APlayerId, BPlayerName, APlayerName,
														DealTime, GoodsId, BaseGoodsId, 3, GoodsNum,
														BCoinBef, BGoldBef, ACoinBef, AGoldBef,
														BCoinAft, BGoldAft, ACoinAft, AGoldAft],
										  db_agent:mark_trade_deal(log_trade, FieldsList, ValuesList);
									  2 ->%%给别人的，别人那里相加，自己这边要减
										  ValuesList = [APlayerId, BPlayerId, APlayerName, BPlayerName,
														DealTime, GoodsId, BaseGoodsId, 3, GoodsNum,
														ACoinBef, AGoldBef, BCoinBef, BGoldBef,
														ACoinAft, AGoldAft, BCoinAft, BGoldAft],
										  db_agent:mark_trade_deal(log_trade, FieldsList, ValuesList)
								  end;
							  _ ->%%出错，不作处理
								  error
						  end
				  end, TradeList).

%% -----------------------------------------------------------------
%% 18012 拖出物品操作
%% -----------------------------------------------------------------
goods_undo(ATradeList, GoodsId, _GoodsNum, BPlayerId) ->
	case lib_player:get_online_info_fields(BPlayerId, [pid, trade_list]) of
		[] ->%%玩家已经不在线了,出错
			error;
		[BPid, BTradeList]->
			Result1 = lists:keymember({GoodsId, 2, 2}, 1, ATradeList),
			Result2 = lists:keymember({GoodsId, 1, 2}, 1, BTradeList),
%% 			io:format("before undo,\n~p,\n~p\n\n",[ATradeList, BTradeList]),
			if %%出错
				(Result1 =/= Result2) ->
%% 							io:format("~p,~p\n",[Result1,Result2]),
					error;
				true ->
%% 							io:format("222\n"),
					NewATradeList = lists:keydelete({GoodsId, 2, 2}, 1, ATradeList),
					NewBTradeList = lists:keydelete({GoodsId, 1, 2}, 1, BTradeList),
					[1, NewATradeList, [BPid, NewBTradeList]]
			end
	end.


%%玩家用于更新本身的物品列表数据
reload_goods_for_trade(true, _PlayerId, []) ->
	true;
reload_goods_for_trade(false, _PlayerId, _DBGoodsRecord) ->
	false;
reload_goods_for_trade(true, PlayerId, [DBElem | DBGoodsRecord]) ->
	{[{player_id, DBPlayerId}, {cell, DBCell}], [{id, DBGoodsId}]} = DBElem,
	case DBPlayerId  =:= PlayerId of
		false ->
%% 			io:format("11,~p\n", [PlayerId]),
			Pattern1 = #goods{id = DBGoodsId, player_id = PlayerId, _='_'},
			ets:match_delete(?ETS_GOODS_ONLINE, Pattern1),
			Pattern2 = #goods_attribute{gid = DBGoodsId, player_id = PlayerId, _='_'},
			ets:match_delete(?ETS_GOODS_ATTRIBUTE, Pattern2),
			reload_goods_for_trade(true, PlayerId, DBGoodsRecord);
		true ->
%% 			io:format("22,~p\n", [PlayerId]),
			GoodsInfoRecord = goods_util:get_goods_by_id(DBGoodsId),
			if 
				is_record(GoodsInfoRecord, goods) =:= false ->
				   reload_goods_for_trade(false, PlayerId, DBGoodsRecord);
				true  ->
%% 				   GoodsInfoRecord = list_to_tuple([goods] ++ GoodsList),
				   NewGoodsInfo = GoodsInfoRecord#goods{player_id = PlayerId, cell = DBCell},
				   ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
				   GoodsAttributesList = db_agent:get_goods_attribute_list_by_gid(DBGoodsId),
				   lists:foreach(fun(Elem) ->
										 NewGoodsAttribute = Elem#goods_attribute{player_id = PlayerId},
										 ets:insert(?ETS_GOODS_ATTRIBUTE, NewGoodsAttribute)
								 end, GoodsAttributesList),
				   reload_goods_for_trade(true, PlayerId, DBGoodsRecord)
		   end
	end.

%%
%% Local Functions
%%
%%统计交易的详细数据
commint_trade({fail, {_AGold, _ACoin, _BGold, _BCoin, _GoodsRecord}, {_ANullCell, _BNullCell}}, 
			  _ATradeList, _APlayerId, _BPlayerId, {_QAGold, _QACoin, _QBGold, _QBCoin}) ->
	{fail, 0};
commint_trade({ok, {AGold, ACoin, BGold, BCoin, GoodsRecord}, {_ANullCell, _BNullCell}}, 
			  [], _APlayerId, _BPlayerId, {_QAGold, _QACoin, _QBGold, _QBCoin}) ->
	case check_goods_trade(GoodsRecord) of
		{fail} ->
			{fail, 1};
		{ok, RetGoodsRecord} ->
			{ok, {AGold, ACoin, BGold, BCoin, RetGoodsRecord}};
		_ ->
			{fail, 1}
	end;
	
commint_trade({ok, {AGold, ACoin, BGold, BCoin, GoodsRecord}, {ANullCell,BNullCell}}, 
			  [TradeRecord|ATradeList], APlayerId, BPlayerId, {QAGold, QACoin, QBGold, QBCoin}) ->
	{{GoodsId, _TypeCopy, GoodsType}, Num, Type, _BaseGoodsTypeId} = TradeRecord,
	ResultComint =
	case Type of
		1 -> %%别人给自己的，自己相加，别人要减
			case GoodsType of
				1 ->
					case GoodsId of
						1 ->%%是元宝
							case Num < 0 orelse Num > QBGold of
								true ->
%% 									io:format("QBGold;~p,~p\n",[Num, QBGold]),
									{fail, {AGold, ACoin, BGold, BCoin, GoodsRecord}, {ANullCell,BNullCell}};
								false ->
									NewAGold = AGold + Num,
									NewBGold = BGold - Num,
									{ok, {NewAGold, ACoin, NewBGold, BCoin, GoodsRecord}, {ANullCell,BNullCell}}
							end;
						2 ->%%是铜钱
							case Num < 0 orelse Num > QBCoin of
								true ->
%% 									io:format("QBCoin;~p,~p\n",[Num, QBCoin]),
									{fail, {AGold, ACoin, BGold, BCoin, GoodsRecord}, {ANullCell,BNullCell}};
								false ->
									NewACoin = ACoin + Num,
									NewBCoin = BCoin - Num,
									{ok, {AGold, NewACoin, BGold, NewBCoin, GoodsRecord}, {ANullCell,BNullCell}}
							end
					end;
				2 -> %%是物品
					[Cell|NewANullCell] = ANullCell,
					NewGoodsRecord = [{[{player_id, APlayerId}, {cell, Cell}], [{id, GoodsId}], Num, BPlayerId} | GoodsRecord],
					{ok, {AGold, ACoin, BGold, BCoin, NewGoodsRecord}, {NewANullCell,BNullCell}}
			end;
		2 ->
			%%给别人的，别人那里相加，自己这边要减
			case GoodsType of
				1 ->
					case GoodsId of
						1 ->%%是元宝
							case Num < 0 orelse Num > QAGold of
								true ->
%% 									io:format("QAGold;~p,~p\n",[Num, QAGold]),
									{fail, {AGold, ACoin, BGold, BCoin, GoodsRecord}, {ANullCell,BNullCell}};
								false ->
									NewAGold = AGold - Num,
									NewBGold = BGold + Num,
									{ok, {NewAGold, ACoin, NewBGold, BCoin, GoodsRecord}, {ANullCell,BNullCell}}
							end;
						2 ->%%是铜钱
							case Num < 0 orelse Num > QACoin of
								true ->
%% 									io:format("QACoin;~p,~p\n",[Num, QACoin]),
									{fail, {AGold, ACoin, BGold, BCoin, GoodsRecord}, {ANullCell,BNullCell}};
								false ->
									NewACoin = ACoin - Num,
									NewBCoin = BCoin + Num,
									{ok, {AGold, NewACoin, BGold, NewBCoin, GoodsRecord}, {ANullCell,BNullCell}}
							end
					end;
				2 -> %%是物品
					[Cell|NewBNullCell] = BNullCell,
					NewGoodsRecord = [{[{player_id, BPlayerId}, {cell, Cell}], [{id, GoodsId}], Num, APlayerId} | GoodsRecord],
					{ok, {AGold, ACoin, BGold, BCoin, NewGoodsRecord}, {ANullCell, NewBNullCell}}
			end
	end,
	commint_trade(ResultComint, ATradeList, APlayerId, BPlayerId, {QAGold, QACoin, QBGold, QBCoin}).
%%物品判断
check_goods_trade(MinNewGoodsRecords) ->
	GoodsIdList = lists:map(fun(GoodsRecord) ->
					  {[{player_id, _BPlayerId}, {cell, _Cell}], [{id, GoodsId}], _Num, _OwnPlayerId} = GoodsRecord,
					  GoodsId
			  end, MinNewGoodsRecords),
	case check_goods_diff(GoodsIdList) of
		false ->
			GoodsInfos = (catch db_agent:get_goods_by_ids(GoodsIdList)),
			case length(GoodsInfos) =:= length(MinNewGoodsRecords) of
				false ->
%% 					io:format("aaaaaaaa\n"),
					{fail};
				true ->
					GoodsInfoRecords = make_goods_records(GoodsInfos),
%% 					io:format("aa11111\n"),
					SortGoodsInfoRecords = lists:sort(fun sort_goods_info_records/2, GoodsInfoRecords),
%% 					io:format("aa22222\n"),
					SortMinNewGoodsRecords = lists:sort(fun sort_goods_records/2, MinNewGoodsRecords),
%% 					io:format("aa33333\n"),
					check_goods_trade_inner(ok, SortGoodsInfoRecords, SortMinNewGoodsRecords, [])
			end;
		true ->
			{fail}
	end.
%%生成物品records
make_goods_records(GoodsInfos) ->
	Result = lists:map(fun(Goods) -> 
					  list_to_tuple([goods] ++ Goods)
			  end, GoodsInfos),
%% 	io:format("Result:~p\n",[Result]),
	Result.

sort_goods_info_records(ElemA, ElemB) ->
%% 	io:format("BB:~p;;~p\n",[ElemA#goods.id,ElemB#goods.id]),
	ElemA#goods.id =< ElemB#goods.id.
sort_goods_records(ElemOne, ElemTwo) ->
%% 	io:format("X\n"),
	{[{player_id, _BPlayerIdOne}, {cell, _CellOne}], [{id, GoodsIdOne}], _NumOne, _APlayerIdOne} = ElemOne,
%% 	io:format("Y\n"),
	{[{player_id, _BPlayerIdTwo}, {cell, _CellTwo}], [{id, GoodsIdTwo}], _NumTwo, _APlayerIdTwo} = ElemTwo,
%% 	io:format("Z\n"),
	GoodsIdOne =< GoodsIdTwo.

check_goods_trade_inner(fail, _GoodsInfoRecords, _MinNewGoodsRecords, _RetGoodsRecords) ->
	{fail};
check_goods_trade_inner(ok, [], [], RetGoodsRecords) ->
	{ok, RetGoodsRecords};
check_goods_trade_inner(ok, [GoodsInfo|GoodsInfoRecords], [GoodsRecord|MinNewGoodsRecords], RetGoodsRecords) ->
	{InfoA, [{id, GoodsId}], Num, OwnPlayerId} = GoodsRecord,
%% 	io:format("abcde\n"),
	if 
		is_record(GoodsInfo, goods) =:= false ->
%% 			io:format("is_record error\n"),
			{fail};
		true ->
			if 
				Num =< 0 orelse GoodsInfo#goods.num =/= Num ->
%% 					io:format("bbbbbb\n"),
					check_goods_trade_inner(fail, GoodsInfoRecords, MinNewGoodsRecords, RetGoodsRecords);
				GoodsInfo#goods.bind =:= 2 orelse GoodsInfo#goods.trade =:= 1 ->%%物品是绑定的或者不可交易
%% 					io:format("ccccc\n"),
					check_goods_trade_inner(fail, GoodsInfoRecords, MinNewGoodsRecords, RetGoodsRecords);
				GoodsInfo#goods.player_id =/= OwnPlayerId ->
%% 					io:format("ddddddd\n"),
					check_goods_trade_inner(fail, GoodsInfoRecords, MinNewGoodsRecords, RetGoodsRecords);
				GoodsInfo#goods.id =/= GoodsId ->
%% 					io:format("eeeee\n"),
					check_goods_trade_inner(fail, GoodsInfoRecords, MinNewGoodsRecords, RetGoodsRecords);
				GoodsInfo#goods.location =/= 4 ->
					check_goods_trade_inner(fail, GoodsInfoRecords, MinNewGoodsRecords, RetGoodsRecords);
				true ->
%% 					io:format("ok\n"),
					check_goods_trade_inner(ok, GoodsInfoRecords, MinNewGoodsRecords,[{InfoA, [{id, GoodsId}]}|RetGoodsRecords])
			end
	end.
						
	
	
	

trade_set_and_send(UpdateList, Status) ->
	case UpdateList =:= [] of
		true ->
			Status;
		false ->
			NewStatus = lib_player_rw:set_player_info_fields(Status, UpdateList),
			mod_player:save_online_diff(Status,NewStatus),
			NewStatus
	end.

%%交易状态复位
change_trade_status(PlayerStatus) ->
	PlayerStatus#player{other =PlayerStatus#player.other#player_other{trade_status = {0, 0}, trade_list = []}}.

check_goods_diff(GoodsIdLists) ->
	check_diff_good(false, GoodsIdLists,GoodsIdLists).

check_diff_good(true, _RemainGoodsIdLists, _GoodsIdLists) ->
	true;
check_diff_good(false, [], _GoodsIdLists) ->
	false;
check_diff_good(false, [GoodsId|RemainGoodsIdLists], GoodsIdLists) ->
	NewGoodsIdLists = lists:delete(GoodsId, GoodsIdLists),
	Result = lists:any(fun(GoodsIdInner) ->
							   GoodsId =:= GoodsIdInner 
					   end, NewGoodsIdLists),
	check_diff_good(Result, RemainGoodsIdLists, GoodsIdLists).

%%获取交易的时限
get_trade_limit(Type) ->
	case get(Type) of
		undefined ->
			true;
		Time ->
			Now = util:unixtime(),
			case (Now - Time) > 3 of
				true ->
					put(Type, undefined),
					true;
				false ->
					false
			end
	end.
