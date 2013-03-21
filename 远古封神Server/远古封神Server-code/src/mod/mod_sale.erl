%%% -------------------------------------------------------------------
%%% Author  : xiaomai
%%% Description :交易市场
%%%
%%% Created : 2010-10-12
%%% -------------------------------------------------------------------
-module(mod_sale).
-behaviour(gen_server).

%% Include files
-include("common.hrl").
-include("record.hrl").

%% External exports
-compile([export_all]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).


%% 定时器1间隔时间(30*60*1000 = 30分钟)
-define(TIME_STAMP, 1800000).

%% ====================================================================
%% External functions
%% ====================================================================
start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

stop() ->
    gen_server:call(?MODULE, stop).

%%动态加载市场交易处理进程 
get_mod_sale_pid() ->
	ProcessName = mod_sale_process,
	case misc:whereis_name({global, ProcessName}) of
		Pid when is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true -> Pid;
				false -> 
					start_mod_sale(ProcessName)
			end;
		_ ->
			start_mod_sale(ProcessName)
	end.

%%启动市场交易监控模块 (加锁保证全局唯一)
start_mod_sale(ProcessName) ->
	global:set_lock({ProcessName, undefined}),	
	ProcessPid =
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> Pid;
					false -> 
						start_sale()
				end;
			_ ->
				start_sale()
		end,	
	global:del_lock({ProcessName, undefined}),
	ProcessPid.

%%开启市场交易监控模块
start_sale() ->
    case supervisor:start_child(
               yg_server_sup,
               {mod_sale,
                {mod_sale, start_link,[]},
                permanent, 10000, supervisor, [mod_sale]}) of
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
%% 	io:format("init the sale module..\n"),
	process_flag(trap_exit, true),	
	ProcessName = mod_sale_process,		%% 多节点的情况下， 仅启用一个市场交易进程
 	case misc:register(unique, ProcessName, self()) of
		yes ->
			ets:new(?ETS_SALE_GOODS, [{keypos, #ets_sale_goods.id}, named_table, public, set,?ETSRC, ?ETSWC]), %%交易市场表
			ets:new(?ETS_SALE_GOODS_ONLINE, [{keypos, #goods.id}, named_table, public, set ,?ETSRC, ?ETSWC]),	%%保存物品今本信息
			ets:new(?ETS_SALE_GOODS_ATTRIBUTE, [{keypos, #goods_attribute.id}, named_table, public, set,?ETSRC, ?ETSWC]),	%%保存物品的额外属性信息
			erlang:send_after(7000, self(), {'LOAD_ALL_SALE_GOODS'}),%%七秒之后开始数据的加载
			misc:write_monitor_pid(self(),?MODULE, {}),
			misc:write_system_info(self(), mod_sale, {}),	
			io:format("2.Init mod_sale finish!!!~n"),
    		{ok, []};
		_ ->
			{stop,normal,[]}
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
	%% ?DEBUG("****************mod_sale_apply_call:[~p,~p]*********", [Module, Method]),
	Reply = 
		case (catch apply(Module, Method, Args)) of
			{'EXIT', Info} ->
				?WARNING_MSG("mod_sale_apply_call: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
				error;
			DataRet -> DataRet
		end,
	{reply, Reply, State};

handle_call(_Request, _From, State) ->
	%% ?DEBUG("****************mod_sale_apply_call:ERROR*********", []),
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
	%% ?DEBUG("mod_sale__apply_cast: [~p/~p/~p]", [Module, Method, Args]),	
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_sale__apply_cast error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
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
handle_info({'LOAD_ALL_SALE_GOODS'}, State) ->
%% 	?DEBUG("load all sale goods:~p", [util:unixtime()]),
	%%加载用于拍卖展示的物品表
	spawn(fun()-> lib_sale:load_all_sale() end),
	erlang:send_after(?TIME_STAMP, self(), {event, timer_action}),
	{noreply, State};

handle_info({event, timer_action}, State) ->
%% 	?DEBUG("timer_action:~p", [util:unixtime()]),
	lib_sale:handle_sale_goods_timeout(),  %% 处理过期拍卖纪录
	erlang:send_after(?TIME_STAMP, self(), {event, timer_action}),
	{noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
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

%% =========================================================================
%%% 业务逻辑处理函数
%% =========================================================================


%% -----------------------------------------------------------------
%% 17001 查询市场中存在的物品(拍卖)
%% -----------------------------------------------------------------
list_sale_goods([GoodsLevelId, Color, Career, Type, SubTypeList, SortType, GoodsName, StartNum, EndNum]) ->
	%% ?DEBUG("****************list_sale_goods 17001*********************",[]),
	try
		case gen_server:call(mod_sale:get_mod_sale_pid(),
							 {apply_call, lib_sale, list_sale_goods, 
							  [GoodsLevelId, Color, Career, Type, SubTypeList, SortType, GoodsName, StartNum, EndNum]}) of
			error -> 
				%% ?DEBUG("17001 list_sale_goods error", []),
				[0, 0, []];
			Data ->
%% 				%% ?DEBUG("17001 list_sale_goods result:[~p]", [Data]),
				Data
		end
	catch
		_:_Reason -> 
			?WARNING_MSG("17001 list_sale_goods fail for the reason:[~p]", [_Reason]),
			[0, 0, []]
	end.


%% -----------------------------------------------------------------
%% 17002 开始拍卖物品
%% -----------------------------------------------------------------
sale_goods(Status, [GoodsId, PriceType, Price, DeductPrice, SaleTime, Cell]) ->
	%% ?DEBUG("~ts~n",["****************sale_goods 17002*********************"]),
	try
		case gen_server:call(mod_sale:get_mod_sale_pid(),
							 {apply_call, lib_sale, sale_goods,
							  [Status, GoodsId, PriceType, Price, DeductPrice, SaleTime, Cell]}) of
			error -> 
				%% ?DEBUG("17002 sale_goods error", []),
				[0, 0, 0];
			Result -> 
				%% ?DEBUG("17002 sale_goods result:[~p]", [Result]),
				Result
		end
	catch
		_:_Reason ->
			?WARNING_MSG("17002 sale_goods fail for the reason:[~p]", [_Reason]),
			[0, 0, 0]
	end.


%% -----------------------------------------------------------------
%% 17003 开始拍卖元宝或铜币
%% -----------------------------------------------------------------
sale_money(Status, [Money, PriceType, Price, DeductPrice, SaleTime, Md5KeyBin]) ->
	%% ?DEBUG("~ts~n",["****************sale_money 17003*********************"]),
	try 
		case gen_server:call(mod_sale:get_mod_sale_pid(),
							 {apply_call, lib_sale, sale_money,
							  [Status, Money, PriceType, Price, DeductPrice, SaleTime, Md5KeyBin]}) of
			error ->
				%% ?DEBUG("17003 sale_money error", []),
				[0, 0, 0];
			Result ->
				%% ?DEBUG("17003 sale_money result:[~p]", [Result]),
				Result
		end
	catch
		_:_Reason -> 
			?WARNING_MSG("17003 sale_money fail for the reason:[~p]", [_Reason]),
			[0, 0, 0]
	end.


%% -----------------------------------------------------------------
%% 17004 查看已上架物品（我的上架物品）
%% -----------------------------------------------------------------
list_sale_goods_self(Status) ->
	%% ?DEBUG("~ts~n",["****************list_sale_goods_self 17004*********************"]),
	try
		case gen_server:call(mod_sale:get_mod_sale_pid(), 
							 {apply_call, lib_sale, list_sale_goods_self,
							  [Status#player.id]}) of
			error ->
				%% ?DEBUG("17004 list_sale_goods_self error", []),
				[0, <<>>];
			Result ->
				%% ?DEBUG("17004 list_sale_goods_self result:[~p]", [Result]),
				Result
		end
	catch
		_:_Reason -> 
			?WARNING_MSG("17004 list_sale_goods_self fail for the reason:[~p]", [_Reason]),
			[0, <<>>]
	end.
			
%% -----------------------------------------------------------------
%% 17005 取消拍卖物品
%% -----------------------------------------------------------------
cancel_sale_goods(Status, [SaleId]) ->
	%% ?DEBUG("~ts~n",["****************cancel_sale_goods 17005*********************"]),
	try 
		case gen_server:call(mod_sale:get_mod_sale_pid(),
							  {apply_call, lib_sale, cancel_sale_goods,
							  [Status#player.id, 
							   SaleId]}) of
			error ->
				%% ?DEBUG("17005 cancel_sale_goods error", []),
				[0];
			Result ->
				%% ?DEBUG("17005 cancel_sale_goods result:[~p]", [Result]),
				Result
		end
	catch 
		_:_Reason -> 
			?WARNING_MSG("17005 cancel_sale_goods fail for the reason:[~p]", [_Reason]),
			[0]
	end.


%% -----------------------------------------------------------------
%% 17006 买家拍卖物品
%% -----------------------------------------------------------------
buyer_sale_goods(Status, [SaleId]) ->
	try
		case gen_server:call(mod_sale:get_mod_sale_pid(),
							 {apply_call, lib_sale, buyer_sale_goods,
							  [Status, SaleId]}) of
			error ->
				[0, 0, 0, 0];
			Result -> 
				Result
		end
	catch
		_:_Reason -> 
			?WARNING_MSG("17006 buyer buy the goods fail for the reason:[~p]", [_Reason]),
			[0, 0, 0, 0]
	end.
	
%% -----------------------------------------------------------------
%% 17007 获取物品详细信息(仅在市场拍卖模块用)
%% -----------------------------------------------------------------
get_salegoods_info(Status, [MarketType, GoodsLists]) ->
	%% ?DEBUG("~ts~n",["****************get_salegoods_info 17007*********************"]),
	gen_server:cast(mod_sale:get_mod_sale_pid(),
					{apply_cast, lib_sale, get_salegoods_info,
					 [MarketType, Status#player.other#player_other.pid_send, GoodsLists]}).
	
	
%%%手动把所有的物品
cancel_all_goods_sale() ->
	gen_server:cast(mod_sale:get_mod_sale_pid(),
					{apply_cast, lib_sale, cancel_all_goods_sale,
					[]}).

%%更新交易角色名
change_player_name(PlayerId,NewNickName) ->
	gen_server:cast(mod_sale:get_mod_sale_pid(),
					{apply_cast, lib_sale, change_player_name,
					[PlayerId,NewNickName]}).
	
%% -----------------------------------------------------------------
%% 17016 查询市场中存在的物品(拍卖)
%% -----------------------------------------------------------------
list_hot_goods(Types,Goods,SortType,StartNum,EndNum,SearchType) ->
 ?DEBUG("****************list_sale_goods 17016*********************",[]),
	try
		case gen_server:call(mod_sale:get_mod_sale_pid(),
							 {apply_call, lib_sale, list_hot_goods, 
							  [Types,Goods,SortType,StartNum,EndNum,SearchType]}) of
			error -> 
 ?DEBUG("17001 list_sale_goods error", []),
				[0, 0, []];
			Data ->
%%  ?DEBUG("17001 list_sale_goods result:[~p]", [Data]),
				Data
		end
	catch
		_:_Reason -> 
			?WARNING_MSG("17016 list_hot_goods fail for the reason:[~p]", [_Reason]),
			[0, 0, []]
	end.