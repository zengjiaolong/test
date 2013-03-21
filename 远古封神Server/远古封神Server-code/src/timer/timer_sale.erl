%%%------------------------------------
%%% @Module  : timer_sale
%%% @Author  : xiaomai
%%% @Created : 2010-10-15
%%% @Description: 氏族后台定时服务 
%%%------------------------------------
-module(timer_sale).
-compile(export_all).
-include("common.hrl").
-include("record.hrl").

%%=========================================================================
%% 一些定义
%% TODO: 定义模块状态。
%%=========================================================================

%% 自定义状态
-record(state, {last_handle_sale_goods_time = 0}).

%% 处理过期的拍卖纪录的处理间隔 30分钟 （1*1 = 1秒）
-define(TIME_INTERVAL_HANDLE_SALE_GOODS, 30*60).

%%=========================================================================
%% 回调接口
%% TODO: 实现回调接口。
%%=========================================================================

%% -----------------------------------------------------------------
%% @desc     启动回调函数，用来初始化资源。
%% @param    
%% @return  {ok, State}     : 启动正常
%%           {ignore, Reason}: 启动异常，本模块将被忽略不执行
%%           {stop, Reason}  : 启动异常，需要停止所有后台定时模块
%% -----------------------------------------------------------------
init() ->
    NowTime = util:unixtime(),
    State = #state{last_handle_sale_goods_time = NowTime},
    {ok, State}.

%% -----------------------------------------------------------------
%% @desc     服务回调函数，用来执行业务操作。
%% @param    State          : 初始化或者上一次服务返回的状态
%% @return  {ok, NewState}  : 服务正常，返回新状态
%%           {ignore, Reason}: 服务异常，本模块以后将被忽略不执行，模块的terminate函数将被回调
%%           {stop, Reason}  : 服务异常，需要停止所有后台定时模块，所有模块的terminate函数将被回调
%% -----------------------------------------------------------------
handle(State) ->
	NewState = handle_sale_goods_timeout(State),
    {ok, NewState}.

%% -----------------------------------------------------------------
%% @desc     停止回调函数，用来销毁资源。
%% @param    Reason        : 停止原因
%% @param    State         : 初始化或者上一次服务返回的状态
%% @return   ok
%% -----------------------------------------------------------------
terminate(Reason, State) ->
    ?DEBUG("================Terming..., Reason=[~w], Statee = [~w]", [Reason, State]),
    ok.

%%=========================================================================
%% 业务处理
%% TODO: 实现业务处理。
%%=========================================================================

%% -----------------------------------------------------------------
%% 处理过期拍卖纪录
%% -----------------------------------------------------------------
handle_sale_goods_timeout(State) ->
	LastHandleTime = State#state.last_handle_sale_goods_time,
	NowTime = util:unixtime(),
	DiffTime = NowTime - LastHandleTime,
	?DEBUG("~ts~n",["*********try to handle_sale_goods_timeout**********"]),
	%% 处理过期的拍卖纪录的处理间隔 30分钟
	if DiffTime >= ?TIME_INTERVAL_HANDLE_SALE_GOODS ->
		   ?DEBUG("handle_sale_goods_timeout: State=[~w]", [State]),
		   mod_sale:handle_sale_goods_timeout(),
		   State#state{last_handle_sale_goods_time = NowTime};
	   true ->
		   State
	end.
	