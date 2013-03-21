%%%------------------------------------
%%% @Module     : timer_mail
%%% @Author     : huangyongxing
%%% @Email      : huangyongxing@yeah.net
%%% @Created    : 2010.05.24
%%% @Description: 信件定时清理模块
%%%------------------------------------
-module(timer_mail).
-include("common.hrl").
-include("record.hrl").
-export(
    [
        init/0,         %% 初始化回调
        handle/1,       %% 处理状态变更回调
        terminate/2     %% 中止回调
    ]).
%-compile(export_all).

%% 邮件清理时间间隔，43200 = 12 * 3600，定为12小时清理一次
-define(CLEAN_UP_TIME_SPAN, 43200).

%% 用于mod_timer初始化状态时回调
%% @return {ok, State} | {ignore, Reason} | {stop, Reason}
init() ->
    NowTime = util:unixtime(),
    {ok, NowTime}.

%% mod_timer中gen_fsm状态机状态变更时调用，用以执行所需操作
%% @param   State           : 原状态
%% @return  {ok, NewState}  : 新状态
%%          {ignore, Reason}: 异常
%%          {stop, Reason}  : 异常
handle(State) ->
    NowTime = util:unixtime(),
    TimeSpan = NowTime - State,
    case TimeSpan >= ?CLEAN_UP_TIME_SPAN of
        true ->
            gen_server:cast(mod_mail, 'clean_mail'),    %% 检查信件是否到期
            {ok, NowTime};
        false ->
            {ok, State}
    end.

%% mod_timer终止回调
terminate(Reason, State) ->
    ?DEBUG("================Terming..., Reason=[~w], Statee = [~w]", [Reason, State]),
    ok.
