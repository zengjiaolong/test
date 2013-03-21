%%%------------------------------------
%%% @Module     : timer_rank
%%% @Author  	: ygzj
%%% @Created 	: 2010.10.05
%%% @Description: 定时生成排行榜 
%%%------------------------------------
-module(timer_rank).
-include("common.hrl").
-include("record.hrl").
-export(
    [
        init/0,         %% 初始化回调
        handle/1,       %% 处理状态变更回调
        terminate/2     %% 中止回调
    ]).
%-compile(export_all).

%% 定时生成排行榜时间间隔，12小时（43200 = 12 * 3600 单位：秒）
-define(RANK_TIME_SPAN, 12*60*60).     

%% 用于mod_timer初始化状态时回调
%% @return {ok, State} | {ignore, Reason} | {stop, Reason}
init() ->
    NowTime = util:unixtime(),
    mod_rank:first_update_rank(),
    {ok, NowTime}.          %% 全局状态为时间戳

%% gen_fsm状态变更回调
handle(State) ->
    {H, M, _} = time(),
    NowTime = util:unixtime(),
    TimeSpan = NowTime - State,
    case (H rem 12 == 0 andalso M < 10) orelse TimeSpan >= ?RANK_TIME_SPAN of
        true ->
            mod_rank:update_rank(),
            {ok, NowTime};
        false ->
            {ok, State}
    end.

%% mod_timer终止回调
terminate(Reason, State) ->
    ?DEBUG("================Terming..., Reason=[~w], Statee = [~w]", [Reason, State]),
    ok.
