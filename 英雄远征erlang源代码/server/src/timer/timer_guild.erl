%%%------------------------------------
%%% @Module  : timer_guild
%%% @Author  : shebiao
%%% @Email   : shebiao@jieyou.com
%%% @Created : 2010.06.24
%%% @Description: 帮派后台定时服务
%%%------------------------------------
-module(timer_guild).
-compile(export_all).
-include("common.hrl").
-include("record.hrl").

%%=========================================================================
%% 一些定义
%% TODO: 定义模块状态。
%%=========================================================================

%% 自定义状态
-record(state, {last_handle_expired_disband_time = 0, last_handle_auto_disband_time = 0, last_handle_daily_construction_time = 0}).

%% 过期解散申请处理间隔
-define(TIME_INTERVAL_HANDLE_EXPIRED_DISBAND,     30*60).
%  掉级自动解散处理间隔
-define(TIME_INTERVAL_HANDLE_AUTO_DISBAND,        30*60).
%% 每日建设处理间隔
-define(TIME_INTERVAL_HANDLE_DAILY_CONSTRUCTION,  30*60).

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
    State = #state{last_handle_expired_disband_time    = NowTime,
                   last_handle_auto_disband_time       = NowTime,
                   last_handle_daily_construction_time = NowTime},
    {ok, State}.

%% -----------------------------------------------------------------
%% @desc     服务回调函数，用来执行业务操作。
%% @param    State          : 初始化或者上一次服务返回的状态
%% @return  {ok, NewState}  : 服务正常，返回新状态
%%           {ignore, Reason}: 服务异常，本模块以后将被忽略不执行，模块的terminate函数将被回调
%%           {stop, Reason}  : 服务异常，需要停止所有后台定时模块，所有模块的terminate函数将被回调
%% -----------------------------------------------------------------
handle(State) ->
    NewState1 = handle_expired_disband(State),
    NewState2 = handle_auto_disband(NewState1),
    NewState3 = handle_daily_construction(NewState2),
    {ok, NewState3}.

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
%% 处理过期解散申请
%% -----------------------------------------------------------------
handle_expired_disband(State) ->
    LastHandleTime = State#state.last_handle_expired_disband_time,
    NowTime        = util:unixtime(),
    DiffTime       = NowTime - LastHandleTime,
    {{_Year, _Month, _Day}, {Hour, _Min, _Sec}} = calendar:local_time(),
    % 每天凌晨4点到6点，且隔30分钟收取一次
    if  ((DiffTime >= ?TIME_INTERVAL_HANDLE_EXPIRED_DISBAND) and (Hour >= 4) and (Hour =< 6)) ->
    %if  (DiffTime >= ?TIME_INTERVAL_HANDLE_EXPIRED_DISBAND) ->
            ?DEBUG("handle_expired_disband: State=[~w]", [State]),
            mod_guild:handle_expired_disband(),
            State#state{last_handle_expired_disband_time = NowTime};
        true ->
            State
    end.

%% -----------------------------------------------------------------
%% 处理掉级自动解散
%% -----------------------------------------------------------------
handle_auto_disband(State) ->
    LastHandleTime = State#state.last_handle_auto_disband_time,
    NowTime        = util:unixtime(),
    DiffTime       = NowTime - LastHandleTime,
    {{_Year, _Month, _Day}, {Hour, _Min, _Sec}} = calendar:local_time(),
    % 每天凌晨4点到6点，且隔30分钟收取一次
    if  ((DiffTime >= ?TIME_INTERVAL_HANDLE_AUTO_DISBAND) and (Hour >= 4) and (Hour =< 6)) ->
    %if  (DiffTime >= ?TIME_INTERVAL_HANDLE_AUTO_DISBAND) ->
            ?DEBUG("handle_auto_disband: State=[~w]", [State]),
            mod_guild:handle_auto_disband(),
            State#state{last_handle_auto_disband_time = NowTime};
        true ->
            State
    end.

%% -----------------------------------------------------------------
%% 处理每日建设收取
%% -----------------------------------------------------------------
handle_daily_construction(State) ->    
    LastHandleTime = State#state.last_handle_daily_construction_time,
    NowTime        = util:unixtime(),
    DiffTime       = NowTime - LastHandleTime,
    {{_Year, _Month, _Day}, {Hour, _Min, _Sec}} = calendar:local_time(),
    % 每天凌晨4点到6点，且隔30分钟收取一次
    if  ((DiffTime >= ?TIME_INTERVAL_HANDLE_DAILY_CONSTRUCTION) and (Hour >= 4) and (Hour =< 6)) ->
    %if  (DiffTime >= ?TIME_INTERVAL_HANDLE_DAILY_CONSTRUCTION) ->
            ?DEBUG("handle_daily_construction: State=[~w]", [State]),
            mod_guild:handle_daily_construction(),
            State#state{last_handle_daily_construction_time = NowTime};
        true ->
            State
    end.