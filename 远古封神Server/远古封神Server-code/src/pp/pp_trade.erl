%% Author: xiaomai
%% Created: 2010-10-22
%% Description: 交易处理（点对点）
-module(pp_trade).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
%%
%% Exported Functions
%%
-export([handle/3]).

%% =================================================================
%% Description: 交易模块功能函数
%% =================================================================

%% -----------------------------------------------------------------
%% 18000 发起交易请求
%% -----------------------------------------------------------------
handle(18000, Status, [BPlayerId]) ->
	[Result, BPid] = deal_origination(Status, [BPlayerId]),
	case Result of
		1 ->%%发起邀请成功
			{ok, BinDataA} = pt_18:write(18000, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinDataA),
			%%往对方主推消息
			APlayerName = Status#player.nickname,
			APlayerId = Status#player.id,
			APLv = Status#player.lv,
			{ok, BinDataB} = pt_18:write(18001, [APlayerId, tool:to_binary(APlayerName), APLv]),
			gen_server:cast(BPid, {'TRADE_SET_AND_SEND', 0, BinDataB, []}),
			ok;
		_ ->
			{ok, BinDataA} = pt_18:write(18000, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinDataA),
			ok
	end;

%% -----------------------------------------------------------------
%% 18002 确定接受交易
%% -----------------------------------------------------------------
handle(18002, Status, [HandleResult, APlayerId]) ->
	[Result, APlayerStatus] = request_trade(Status, [HandleResult, APlayerId]),
	case HandleResult of
		0 -> %%拒绝
			case Result of
				1 ->%%对方在线
					%%往发起方发送拒绝信息
					#player{id = BPlayerId,
							nickname = BPlayerName} = Status,
					{ok, BinDataA} = pt_18:write(18010, [BPlayerId, tool:to_binary(BPlayerName)]),
					lib_send:send_to_uid(APlayerId, BinDataA),
					%%自己确定拒绝信息
					{ok, BinDataB} = pt_18:write(18002, [0]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinDataB),
					ok;
				2  ->%%对方已经不在线
					%%自己确定拒绝信息
					{ok, BinDataB} = pt_18:write(18002, [0]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinDataB),
					ok;
				_ ->
					{ok, BinDataB} = pt_18:write(18002, [2]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinDataB),
					ok
			end;
		1 ->%%允许
			case Result of
				2 ->%%对方已经不在线
					{ok, BinDataB} = pt_18:write(18002, [Result]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinDataB),
					ok;
				3 ->%%对方正在忙
					{ok, BinDataB} = pt_18:write(18002, [Result]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinDataB),
					ok;
				4 ->%%您已经出在交易状态下
					{ok, BinDataB} = pt_18:write(18002, [Result]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinDataB),
					ok;
				5 ->%%战斗状态不能交易
					{ok, BinDataB} = pt_18:write(18002, [Result]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinDataB),
					ok;
				6 ->%%修炼状态不能交易
					{ok, BinDataB} = pt_18:write(18002, [Result]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinDataB),
					ok;
				7 ->%%账号出现异常了，铜币或者元宝出错
					{ok, BinDataB} = pt_18:write(18002, [Result]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinDataB),
					ok;
				1 ->%%成功
					{ok, BinDataB} = pt_18:write(18002, [Result]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinDataB),
					%%往双方主推交易启动 的协议					
					#player{id = BPlayerId,
							nickname = BPlayerName} = Status,
					#player{id = _APlayerId,
							nickname = APlayerName} = APlayerStatus,
					%%向发起方(A)推消息
					{ok, NewBinDataA} = pt_18:write(18009, [BPlayerId, tool:to_binary(BPlayerName)]),
					%%向发起方(B)推消息
					{ok, NewBinDataB} = pt_18:write(18009, [APlayerId, tool:to_binary(APlayerName)]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, NewBinDataB),
					
					%%修改双方的交易状态
					BPlayerStatusNew = Status#player{other = Status#player.other#player_other{trade_status = {1, APlayerId}}},
					%%通知修改发起方的交易状态
					gen_server:cast(APlayerStatus#player.other#player_other.pid, 
									{'TRADE_SET_AND_SEND', 0, NewBinDataA,
									 [{trade_status, {1, BPlayerId}}]}),
					
					{ok, BPlayerStatusNew};
				_ ->
					{ok, BinDataB} = pt_18:write(18002, [2]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinDataB),
					ok
			end
	end;

%% -----------------------------------------------------------------
%% 交易物品操作
%% -----------------------------------------------------------------
handle(18003, Status, [GoodsType, GoodsId, GoodsNum, BaseGoodsId]) ->
	{_ATrade, BPlayerId} = Status#player.other#player_other.trade_status,
	[Result, ATradeList, BPlayerStatus] = goods_trade(Status, [GoodsType, GoodsId, GoodsNum, BPlayerId]),
	case Result of
		1 ->%%成功
			%%向自己发确认
			NewAPlayerStatus = Status#player{other = Status#player.other#player_other{trade_list = ATradeList}},
			{ok, BinDataA} = pt_18:write(18003, [Result]),
			lib_send:send_to_sid(NewAPlayerStatus#player.other#player_other.pid_send, BinDataA),
			%%向对方推物品信息
%% 			io:format("insert result,\n~p,\n~p\n\n", [ATradeList, BPlayerStatus#player.other#player_other.trade_list]),
			{ok, BinDataB} = pt_18:write(18004, [GoodsType, GoodsId, GoodsNum, BaseGoodsId]),
			%%通知对方交易表的更新
			gen_server:cast(BPlayerStatus#player.other#player_other.pid, 
							{'TRADE_SET_AND_SEND', 0, BinDataB, 
							 [{trade_list, BPlayerStatus#player.other#player_other.trade_list}]}),
			{ok, NewAPlayerStatus};
		_ ->
			?DEBUG("return result ~p", [Result]),
			{ok, BinDataA} = pt_18:write(18003, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinDataA),
			ok
	end;

%% -----------------------------------------------------------------
%% 18005 锁定交易
%% -----------------------------------------------------------------
handle(18005, Status, []) ->
	{_ATrade, BPlayerId} = Status#player.other#player_other.trade_status,
	case lib_player:is_online(BPlayerId) of
		flase ->%%对方已经不在线
			ok;
		_ ->%%向对方推送消息
			{ok, BinData} = pt_18:write(18006, []),
			lib_send:send_to_uid(BPlayerId, BinData),
			NewAPlayerStatus = Status#player{other = Status#player.other#player_other{trade_status = {2, BPlayerId}}},
			{ok, NewAPlayerStatus}
	end;

%% -----------------------------------------------------------------
%% 18007 取消交易
%% -----------------------------------------------------------------
handle(18007, Status, [Type]) ->
	{_ATrade, BPlayerId} = Status#player.other#player_other.trade_status,
	[APlayerStatus, BPlayer_Pid] = cancel_trade(Status, BPlayerId), 
	case BPlayer_Pid of
		[] ->%%对方玩家已经不在了
			{ok, APlayerStatus};
		_ ->
			%%向对方推取消交易信息
			{ok, BinData} = pt_18:write(18007, []),
			%%通知对方状态的更新
			gen_server:cast(BPlayer_Pid, 
							{'TRADE_SET_AND_SEND', 0, BinData, 
							 [{trade_status,{0,0}}, {trade_list,[]}]}),
			case Type of
				1 ->%%玩家主动取消交易的
					void;
				2 ->%%玩家被迫进入战斗状态的，要往自己也发取消交易的通告
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
			end,
			{ok, APlayerStatus}
	end;


%% -----------------------------------------------------------------
%% 18008 实施交易
%% -----------------------------------------------------------------
handle(18008, Status, []) ->
	{_ATrade, BPlayerId} = Status#player.other#player_other.trade_status,
	[Result, APlayerStatus, BPlayerStatus] = execute_trade(Status, BPlayerId),
%% 	io:format("Result:~p\n", [Result]),
	case Result of
		0 ->
			{ok, BinData} = pt_18:write(18011, [Result]),
			%%向双方推送消息
			lib_send:send_to_sid(APlayerStatus#player.other#player_other.pid_send, BinData),
			%%通知对方状态的更新
			gen_server:cast(BPlayerStatus#player.other#player_other.pid, 
							{'TRADE_SET_AND_SEND', 0, BinData, 
							 [{trade_status, BPlayerStatus#player.other#player_other.trade_status}, 
							  {trade_list,BPlayerStatus#player.other#player_other.trade_list}]}),
			{ok, APlayerStatus};
		1 ->%%啊哦，成功了
			{ok, BinData} = pt_18:write(18011, [Result]),
			%%向双方推送消息
			lib_send:send_to_sid(APlayerStatus#player.other#player_other.pid_send, BinData),
			%%通知对方状态的更新
			gen_server:cast(BPlayerStatus#player.other#player_other.pid, 
							{'TRADE_SET_AND_SEND', 1, BinData, 
							 [{coin, BPlayerStatus#player.coin},
							  {gold, BPlayerStatus#player.gold},
							  {trade_status, BPlayerStatus#player.other#player_other.trade_status}, 
							  {trade_list,BPlayerStatus#player.other#player_other.trade_list}]}),
			%%添加交易后的时间限制
			NowTime = util:unixtime(),
			put(trade_limit, NowTime),
%% 			%%向物品进程发消息,交易为3
%% 			erlang:send_after(1000 * 10 , APlayerStatus#player.other#player_other.pid_goods ,{'mem_diff',3}),
%% 			erlang:send_after(1000 * 10 , BPlayerStatus#player.other#player_other.pid_goods ,{'mem_diff',3}),
			
			{ok, APlayerStatus};
		2 -> %%对方已经不在线
			{ok, BinData} = pt_18:write(18011, [0]),
			%%向双方推送消息
			lib_send:send_to_sid(APlayerStatus#player.other#player_other.pid_send, BinData),
			{ok, APlayerStatus};
		3 ->%%自己背包不足
			{ok, ABinData} = pt_18:write(18011, [2]),
			{ok, BBinData} = pt_18:write(18011, [3]),
			%%向双方推送消息
			lib_send:send_to_sid(APlayerStatus#player.other#player_other.pid_send, ABinData),
			%%通知对方状态的更新
			gen_server:cast(BPlayerStatus#player.other#player_other.pid, 
							{'TRADE_SET_AND_SEND', 0, BBinData, 
							 [{trade_status, BPlayerStatus#player.other#player_other.trade_status}]}),
			{ok, APlayerStatus};
		4 ->%%对方背包不足
			{ok, ABinData} = pt_18:write(18011, [3]),
			{ok, BBinData} = pt_18:write(18011, [2]),
			%%向双方推送消息
			lib_send:send_to_sid(APlayerStatus#player.other#player_other.pid_send, ABinData),
			%%通知对方状态的更新
			gen_server:cast(BPlayerStatus#player.other#player_other.pid, 
							{'TRADE_SET_AND_SEND', 0, BBinData, 
							 [{trade_status, BPlayerStatus#player.other#player_other.trade_status}]}),
			{ok, APlayerStatus};
		5 ->%%自己点了交易而对方还未点
			{ok, APlayerStatus};
		6 ->%%error或者是catch,(因为没有拿到双方的status，走18007协议)
			handle(18007, Status, [2]);
		7 -> %%双方的账号数据出现异常了，元宝或者铜币出现负数
			{ok, BinData} = pt_18:write(18011, [4]),
			%%向双方推送消息
			lib_send:send_to_sid(APlayerStatus#player.other#player_other.pid_send, BinData),
			%%通知对方状态的更新
			gen_server:cast(BPlayerStatus#player.other#player_other.pid, 
							{'TRADE_SET_AND_SEND', 0, BinData, 
							 [{trade_status, BPlayerStatus#player.other#player_other.trade_status}]}),
			{ok, APlayerStatus};
		8 ->%%物品信息有误了
			{ok, BinData} = pt_18:write(18011, [5]),
			%%向双方推送消息
			lib_send:send_to_sid(APlayerStatus#player.other#player_other.pid_send, BinData),
			%%通知对方状态的更新
			gen_server:cast(BPlayerStatus#player.other#player_other.pid, 
							{'TRADE_SET_AND_SEND', 0, BinData, 
							 [{trade_status, BPlayerStatus#player.other#player_other.trade_status}, 
							  {trade_list,BPlayerStatus#player.other#player_other.trade_list}]}),
			{ok, APlayerStatus};
		_ ->%%异常处理，(因为没有拿到双方的status，走18007协议)
			handle(18007, Status, [2])
	end;
	
%% -----------------------------------------------------------------
%% 18012 拖出物品操作
%% -----------------------------------------------------------------
handle(18012, Status, [GoodsId, GoodsNum, BaseGoodsId]) ->
	{_ATrade, BPlayerId} = Status#player.other#player_other.trade_status,
	[Result, NewATradeList, BPlayerInfo] = goods_undo(Status, [GoodsId, GoodsNum, BPlayerId]),
	case Result of
		0 ->%%失败
			{ok, BinData} = pt_18:write(18012, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
		1 ->%%成功
			{ok, BinDataA} = pt_18:write(18012, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinDataA),
			{ok, BinDataB} = pt_18:write(18013, [GoodsId, GoodsNum, BaseGoodsId]),			
			[BPid, NewBTradeList] = BPlayerInfo,			
			gen_server:cast(BPid, 
							{'TRADE_SET_AND_SEND', 0, BinDataB, 
							 [{trade_list, NewBTradeList}]}),
%% 			io:format("undo result, \n~p,\n~p\n\n",[NewATradeList, NewBTradeList]),
			NewAPlayerStatus = Status#player{other = Status#player.other#player_other{trade_list = NewATradeList}},
			{ok, NewAPlayerStatus};
		_ ->
			ok
	end;
	
handle(_Cmd, _Status, _Data) ->
    ?DEBUG("pp_trade no match", []),
    {error, "pp_trade no match"}.

%%======================================================================
%%=========================  交易（点对点）==============================
%%======================================================================
%% -----------------------------------------------------------------
%% 18000 发起交易请求
%% -----------------------------------------------------------------
deal_origination(Status, [BPlayerId]) ->
	%% 玩家状态
	PlayerStatus = lib_player:player_status(Status), 
	[Gold, _Cash] = db_agent:query_player_money(Status#player.id),
	try 
		case lib_trade: deal_origination(Status#player.id, PlayerStatus, 
										 Status#player.other#player_other.trade_status, 
										 Status#player.coin, Gold,
										 BPlayerId) of
			error ->
				[0, []];
			Result ->
				Result
		end
	catch
		_:_ ->
			[0, []]
	end.
		
%% -----------------------------------------------------------------
%% 18002 确定接受交易
%% -----------------------------------------------------------------
request_trade(Status, [HandleResult, APlayerId]) ->
	%% 玩家状态
	PlayerStatus = lib_player:player_status(Status),
	[Gold, _Cash] = db_agent:query_player_money(Status#player.id),
	try
		case lib_trade:request_trade(PlayerStatus, 
									 Status#player.other#player_other.trade_status, 
									 Status#player.coin, Gold,
									 HandleResult, APlayerId) of
			error -> %%出错
				[0, {}];
			Result ->%%正常
				Result
		end
	catch 
		_:_ ->%%异常了
			[0, {}]
	end.

%% -----------------------------------------------------------------
%% 18003 交易物品操作
%% -----------------------------------------------------------------
goods_trade(Status, [GoodsType, GoodsId, GoodsNum, BPlayerId]) ->
	[Gold, _Cash] = db_agent:query_player_money(Status#player.id),
	try
		case lib_trade:goods_trade(Status#player.id, 
								   Status#player.other#player_other.trade_list, 
								   Status#player.coin,
								   Gold, 
								   GoodsType, GoodsId, 
								   GoodsNum, BPlayerId) of
			error ->
				[0, [], {}];
			Result ->
				Result
		end
	catch 
		_:_ ->
			[0, [], {}]
	end.
			
%% -----------------------------------------------------------------
%% 18007 取消交易
%% -----------------------------------------------------------------
cancel_trade(Status, BPlayerId) ->
	BPlayer_Pid = lib_player:get_player_pid(BPlayerId),
	NewAPlayerStatus = Status#player{other = 
									 Status#player.other#player_other{trade_status = {0,0},
																				  trade_list = []}},
	[NewAPlayerStatus, BPlayer_Pid].

%% -----------------------------------------------------------------
%% 18008 实施交易
%% -----------------------------------------------------------------
execute_trade(Status, BPlayerId) ->
	try 
		case lib_trade:execute_trade(Status, BPlayerId) of
			error ->%%错误处理
				[6, {}, {}];
			Result ->
				Result
		end
	catch
		_:_ ->
			[6, {}, {}]
	end.

%% -----------------------------------------------------------------
%% 18012 拖出物品操作
%% -----------------------------------------------------------------
goods_undo(Status, [GoodsId, GoodsNum, BPlayerId]) ->
	try
		case lib_trade:goods_undo(Status#player.other#player_other.trade_list,
								  GoodsId, GoodsNum, BPlayerId) of
			error ->
				[0, [], {}];
			Result ->
				Result
		end
	catch
		_:_ ->
			[0, [], {}]
	end.

%%======================================================================
%%======================  交易（点对点）结束 ============================
%%======================================================================

