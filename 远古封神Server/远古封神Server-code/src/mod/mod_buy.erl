%%% -------------------------------------------------------------------
%%% Author  : xianrongMai
%%% Description :市场求购处理模块
%%%
%%% Created : 2012-2-13
%%% -------------------------------------------------------------------
-module(mod_buy).

-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("common.hrl").
-include("record.hrl").

%% 定时器1间隔时间(30*60*1000 = 30分钟)
-define(TIME_STAMP, 1800000).%程序自带的定时器时间戳

%% -define(TIME_STAMP, 10000).%%测试用

%% --------------------------------------------------------------------
%% External exports
-export([
		 list_buy_goods/1,					%% 17001 查询市场中存在的物品(求购)
		 get_buygoods_info/2,				%% 17007 获取物品详细信息(仅在市场拍卖模块用)
		 get_buy_goods_attributes/2,		%% 17008 获取物品属性信息
		 buy_goods_request/9,				%% 17009 求购物品请求
		 buy_cash_request/5,				%% 17010 开始求购元宝或铜币
		 submit_buy_goods/3,				%% 17011 出卖对应求购物品请求(除了装备)
		 list_buy_goods_self/1,				%% 17012 查看已求购物品
		 cancel_buy_goods/2,				%% 17013 取消求购物品
		 submit_buy_goods_equip/3,			%% 17014 出卖对应求购物品请求(装备类)
		 cancel_all_goods_buy/0,			%% 人工手动下架所有的拍卖物品
		 list_hot_goods/6,					%% 17016  热卖物品
		 
		 start_link/0,
		 stop/0,
		 get_buy_pid/0
		]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {}).

%% ====================================================================
%% External functions
%% ====================================================================


%% ====================================================================
%% Server functions
%% ====================================================================
start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

stop() ->
	gen_server:call(?MODULE, stop).

%%动态加载市场交易处理进程 
get_buy_pid() ->
	ProcessName = mod_buy,
	case misc:whereis_name({global, ProcessName}) of
		Pid when is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true -> Pid;
				false -> 
					start_mod_buy(ProcessName)
			end;
		_ ->
			start_mod_buy(ProcessName)
	end.

%%启动市场交易监控模块 (加锁保证全局唯一)
start_mod_buy(ProcessName) ->
	global:set_lock({ProcessName, undefined}),	
	ProcessPid =
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> Pid;
					false -> 
						start_buy()
				end;
			_ ->
				start_buy()
		end,	
	global:del_lock({ProcessName, undefined}),
	ProcessPid.

%%开启市场交易监控模块
start_buy() ->
	case supervisor:start_child(
		   yg_server_sup,
		   {mod_buy,
			{mod_buy, start_link,[]},
			permanent, 10000, supervisor, [mod_buy]}) of
		{ok, Pid} ->
			timer:sleep(1000),
			Pid;
		_ ->
			undefined
	end.
%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([]) ->
	process_flag(trap_exit, true),	
	ProcessName = mod_buy,		%% 多节点的情况下， 仅启用一个市场交易进程
	case misc:register(unique, ProcessName, self()) of
		yes ->
			ets:new(?ETS_BUY_GOODS, [{keypos, #ets_buy_goods.id}, named_table, public, set,?ETSRC, ?ETSWC]), %%交易市场表
			erlang:send_after(7000, self(), {'LOAD_ALL_BUY_GOODS'}),%%七秒之后开始数据的加载
			misc:write_monitor_pid(self(),?MODULE, {}),
			misc:write_system_info(self(), mod_buy, {}),	
			io:format("10.Init mod_buy finish!!!~n"),
			{ok, #state{}};
		_ ->
			{stop,normal,#state{}}
	end.

%% --------------------------------------------------------------------
%% Function: handle_call/3
%% Description: Handling call messages
%% Returns: {reply, Reply, State}          |
%%          {reply, Reply, State, Timeout} |
%%          {noreply, State}               |
%%          {noreply, State, Timeout}      |
%%          {stop, Reason, Reply, State}   | (terminate/2 is called)
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%% 统一模块+过程调用(call)
handle_call({apply_call, Module, Method, Args}, _From, State) ->
	%% 	?DEBUG("mod_buy apply_call:[~p, ~p, ~p]", [Module, Method, Args]),
	Reply = 
		case (catch apply(Module, Method, Args)) of
			{'EXIT', Info} ->
				?WARNING_MSG("mod_buy apply_call fail: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
				error;
			DataRet -> DataRet
		end,
	{reply, Reply, State};

handle_call(_Request, _From, State) ->
	Reply = ok,
	{reply, Reply, State}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%% 统一模块+过程调用(cast)
handle_cast({apply_cast, Module, Method, Args}, State) ->
	%% 	?DEBUG("mod_buy apply_cast: [~p, ~p, ~p]", [Module, Method, Args]),	
	case (catch apply(Module, Method, Args)) of
		{'EXIT', Info} ->	
			?WARNING_MSG("mod_buy apply_cast fail: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
			error;
		_ -> ok
	end,
	{noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

handle_cast(_Msg, State) ->
	{noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_info({'LOAD_ALL_BUY_GOODS'}, State) ->
	%% 加载所有的求购数据
	lib_buy:load_all_buy_goods(),
	erlang:send_after(?TIME_STAMP, self(), {event, timeout_action}),
	{noreply, State};

%%处理过期的数据
handle_info({event, timeout_action}, State) ->
	%%处理所有超时的求购信息
	lib_buy:handle_buy_goods_timeout(),
	erlang:send_after(?TIME_STAMP, self(), {event, timeout_action}),
	{noreply, State};

handle_info(_Info, State) ->
	{noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(Reason, _State) ->
	?WARNING_MSG("mod_buy process terminate because of -> ~p",[Reason]),
	misc:delete_monitor_pid(self()),
	misc:delete_system_info(self()),	
	ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

%% --------------------------------------------------------------------
%%% Internal functions
%% --------------------------------------------------------------------
%% -----------------------------------------------------------------
%% 17001 查询市场中存在的物品(求购)
%% -----------------------------------------------------------------
list_buy_goods([GoodsLevelId, Color, Career, Type, SubTypeList, SortType, GoodsName, StartNum, EndNum]) ->
	try
		case gen_server:call(mod_buy:get_buy_pid(),
							 {apply_call, lib_buy, list_buy_goods, 
							  [GoodsLevelId, Color, Career, Type, SubTypeList, SortType, GoodsName, StartNum, EndNum]}) of
			error -> 
				%% ?DEBUG("17001 list_buy_goods error", []),
				[0, 0, []];
			Data ->
				%% 				%% ?DEBUG("17001 list_buy_goods result:[~p]", [Data]),
				Data
		end
	catch
		_:_Reason -> 
			?WARNING_MSG("17001 list_buy_goods fail for the reason:[~p]", [_Reason]),
			[0, 0, []]
	end.

%% -----------------------------------------------------------------
%% 17007 获取物品详细信息(仅在市场拍卖模块用)
%% -----------------------------------------------------------------
get_buygoods_info(Status, [MarketType, GoodsLists]) ->
	gen_server:cast(mod_buy:get_buy_pid(),
					{apply_cast, lib_buy, get_buygoods_info,
					 [MarketType, Status#player.other#player_other.pid_send, GoodsLists]}).

%% -----------------------------------------------------------------
%% 17008 获取物品属性信息
%% -----------------------------------------------------------------
get_buy_goods_attributes(Status, GoodsId) ->
	lib_buy:get_buy_goods_attributes(GoodsId, Status#player.other#player_other.pid_send).

%% -----------------------------------------------------------------
%% 17009 求购物品请求
%% -----------------------------------------------------------------
buy_goods_request(Status, GoodsId, Stren, PType, Num, UnPrice, BuyTime, AList, Param) ->
	try
		case gen_server:call(mod_buy:get_buy_pid(),
							 {apply_call, lib_buy, buy_goods_request, 
							  [Status, GoodsId, Stren, PType, Num, UnPrice, BuyTime, AList, Param]}) of
			error -> 
				%% ?DEBUG("17009 buy_goods_request error", []),
				{0, Status};
			Data ->
				%% 				%% ?DEBUG("17009 buy_goods_request result:[~p]", [Data]),
				Data
		end
	catch
		_:_Reason -> 
			?WARNING_MSG("17009 buy_goods_request fail for the reason:[~p]", [_Reason]),
			{0, Status}
	end.


%% -----------------------------------------------------------------
%% 17010 开始求购元宝或铜币
%% -----------------------------------------------------------------
buy_cash_request(Status, Num, PType, UnPrice, BuyTime) ->
	try
		case gen_server:call(mod_buy:get_buy_pid(),
							 {apply_call, lib_buy, buy_cash_request, 
							  [Status, Num, PType, UnPrice, BuyTime]}) of
			error -> 
%% 				?DEBUG("17010 buy_cash_request error", []),
				{0, Status};
			Data ->
				%% 				?DEBUG("17010 buy_cash_request result:[~p]", [Data]),
				Data
		end
	catch
		_:_Reason -> 
			?WARNING_MSG("17010 buy_cash_request fail for the reason:[~p]", [_Reason]),
			{0, Status}
	end.

%% -----------------------------------------------------------------
%% 17011 出卖对应求购物品请求(除了装备)
%% -----------------------------------------------------------------
submit_buy_goods(Status, BuyId, SellNum) ->
	try
		case gen_server:call(mod_buy:get_buy_pid(),
							 {apply_call, lib_buy, submit_buy_goods, 
							  [Status, BuyId, SellNum]}) of
			error -> 
				%% ?DEBUG("17011 submit_buy_goods error", []),
				{0, Status};
			Data ->
				%% 				%% ?DEBUG("17011 submit_buy_goods result:[~p]", [Data]),
				Data
		end
	catch
		_:_Reason -> 
			?WARNING_MSG("17010 buy_cash_request fail for the reason:[~p]", [_Reason]),
			{0, Status}
	end.


%% -----------------------------------------------------------------
%% 17012 查看已求购物品
%% -----------------------------------------------------------------
list_buy_goods_self(Status) ->
	gen_server:cast(mod_buy:get_buy_pid(),
					{apply_cast, lib_buy, list_buy_goods_self, 
					 [Status#player.id, 
					  Status#player.other#player_other.pid_send]}).


%% -----------------------------------------------------------------
%% 17013 取消求购物品
%% -----------------------------------------------------------------
cancel_buy_goods(Status, BuyId) ->
	gen_server:cast(mod_buy:get_buy_pid(),
					{apply_cast, lib_buy, cancel_buy_goods, 
					 [BuyId,
					  Status#player.id, Status#player.nickname,
					  Status#player.other#player_other.pid_send]}).

%% -----------------------------------------------------------------
%% 17014 出卖对应求购物品请求(装备类)
%% -----------------------------------------------------------------
submit_buy_goods_equip(Status, BuyId, Gid) ->
	try
		case gen_server:call(mod_buy:get_buy_pid(),
							 {apply_call, lib_buy, submit_buy_goods_equip, 
							  [Status, BuyId, Gid]}) of
			error -> 
				%% ?DEBUG("17014 submit_buy_goods_equip error", []),
				0;
			Data ->
				%% 				%% ?DEBUG("17014 submit_buy_goods_equip result:[~p]", [Data]),
				Data
		end
	catch
		_:_Reason -> 
			?WARNING_MSG("17014 submit_buy_goods_equip fail for the reason:[~p]", [_Reason]),
			0
	end.

%% -----------------------------------------------------------------
%% 17016 热卖搜索
%% -----------------------------------------------------------------

list_hot_goods(Types,Goods,SortType,StartNum,EndNum,SearchType) ->
	try
		case gen_server:call(mod_buy:get_buy_pid(),
							 {apply_call, lib_buy, list_hot_goods, 
							  [Types,Goods,SortType,StartNum,EndNum,SearchType]}) of
			error -> 
				[0, 0, []];
			Data ->
				Data
		end
	catch
		_:_Reason -> 
			?WARNING_MSG("17001 list_buy_goods fail for the reason:[~p]", [_Reason]),
			[0, 0, []]
	end.

%%人工手动下架所有的拍卖物品
cancel_all_goods_buy() ->
	gen_server:cast(mod_buy:get_buy_pid(),
					{apply_cast, lib_buy, cancel_all_goods_buy,
					 []}).