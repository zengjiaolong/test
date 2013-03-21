%%% -------------------------------------------------------------------
%%% Author  : xiaomai
%%% Description : 诛邪系统日志处理进程
%%%
%%% Created : 2010-12-8
%%% -------------------------------------------------------------------
-module(mod_box_log).

-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("common.hrl").
-include("record.hrl").

%% --------------------------------------------------------------------
%% External exports
-export([start_link/0,
		 start/0,
		 stop/0,
		 boradcast_box_goods/8,
		 broadcast_box_to_local_all/2,
		 list_server_box_logs/0			%% 28001  获取全服开宝箱记录
		 ]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).


%% ====================================================================
%% External functions
%% ====================================================================
start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

start() ->
	gen_server:start(?MODULE, [], []).

stop() ->
    gen_server:call(?MODULE, stop).

%% ====================================================================
%% Server functions
%% ====================================================================

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
	ets:new(?ETS_LOG_BOX_OPEN, [{keypos, #ets_log_box_open.id}, named_table, public, set,?ETSRC, ?ETSWC]),
	lib_box:load_all_box_log(),
	misc:write_monitor_pid(self(),?MODULE, {}),
	erlang:send_after(?TIMESTAMPLOG, self(), {event, mod_box_log_update_action}),
	%% ?DEBUG("init the mod_box process children now....please wait", []),
	{ok, []}.

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
	%% ?DEBUG("****************mod_box_apply_call:[~p,~p]*********", [Module, Method]),
	Reply = 
		case (catch apply(Module, Method, Args)) of
			{'EXIT', Info} ->
				?WARNING_MSG("mod_box_apply_call: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
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
handle_cast({'broadcast_box_goods', PlayerId, PlayerName, Realm, PlayerLevel, Career, Sex,
			 HoleType, GoodsList}, State) ->
	%% ?DEBUG("******  the GoodsList length is [~p]  ******", [length(GoodsList)]),
	EtsBoxGoodsType = mod_box:get_ets_boxgoods_type(),
	{BroadCastGoodsList, CastListStr} = 
		lists:foldl(fun(GoodsInfo, AccIn) ->
							lib_box:handle_each_box_goods(EtsBoxGoodsType, 
														  PlayerId, PlayerName, HoleType, 
														  GoodsInfo, AccIn)
					end, {[], ""}, GoodsList),
	case length(CastListStr) == 0 of
		false ->
			erlang:spawn(lib_box, handle_box_system_msg, 
						 [Realm, HoleType, PlayerId, PlayerName, PlayerLevel, Career, Sex, CastListStr, BroadCastGoodsList]);
		true ->
			no_action
	end,
	{noreply, State};

handle_cast({'send_to_local_all', Data, BroadCastGoodsList}, State) ->
	lists:foreach(fun lib_box:lib_box_goods_log_local/1, BroadCastGoodsList),
	lib_send:send_to_local_all(Data),
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
handle_info({event, mod_box_log_update_action}, _State) ->
	NewState = lib_box:mod_box_log_handle_update_action(),
	erlang:send_after(?TIMESTAMPLOG, self(), {event, mod_box_log_update_action}),
	{noreply, NewState};
handle_info(_Info, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()),
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% --------------------------------------------------------------------
%%% API functions
%% --------------------------------------------------------------------
%% -----------------------------------------------------------------
%% 28001 获取全服开宝箱记录
%% -----------------------------------------------------------------
list_server_box_logs() ->
	%% ?DEBUG("****************list_server_box_logs 28001*********************",[]),
	try
		case gen_server:call(?MODULE,
							 {apply_call, lib_box, list_server_box_logs, 
							  []}) of
			error -> 
				%% ?DEBUG("28001 list_server_box_logs error", []),
				[0, []];
			Data ->
%% 				%% ?DEBUG("28001 list_server_box_logs result:[~p]", [Data]),
				Data
		end
	catch
		_:_Reason -> 
			?WARNING_MSG("28001 list_server_box_logs fail for the reason:[~p]", [_Reason]),
			[0, []]
	end.


%%广播
boradcast_box_goods(PlayerId, PlayerName, Realm, PlayerLevel, Career, Sex, HoleType, GoodsList) ->
	gen_server:cast(?MODULE, {'broadcast_box_goods',PlayerId, PlayerName, 
							  Realm, PlayerLevel, Career, Sex, HoleType, GoodsList}).
%%往本地发送广播
broadcast_box_to_local_all(Data, BroadCastGoodsList) ->
	gen_server:cast(?MODULE, {'send_to_local_all', Data, BroadCastGoodsList}).

%% --------------------------------------------------------------------
%%% Internal functions
%% --------------------------------------------------------------------

