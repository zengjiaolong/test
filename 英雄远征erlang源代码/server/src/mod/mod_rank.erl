%%%------------------------------------
%%% @Module     : mod_rank
%%% @Author     : huangyongxing
%%% @Email      : huangyongxing@yeah.net
%%% @Created    : 2010.08.19
%%% @Description: 排行榜
%%%------------------------------------
-module(mod_rank).
-behaviour(gen_fsm).
-export([init/1, handle_event/3, handle_sync_event/4, handle_info/3, code_change/4, terminate/3]).
-export(
    [
        start_link/0,
        first_update_rank/0,
        update_rank/0,
        handle/2
    ]).

-include("common.hrl").
-include("record.hrl").

-define(INIT_RANK_DELAY, 10000).    %% 初始化排行榜延时，10秒（10 * 1000 单位：毫秒）

%%%------------------------------------
%%%             接口函数
%%%------------------------------------

start_link() ->      %% 启动服务
    gen_fsm:start_link({local, ?MODULE}, ?MODULE, [], []).

first_update_rank() ->
    gen_fsm:send_event(?MODULE, 'init_data').

update_rank() ->
    gen_fsm:send_event(?MODULE, 'update_data').

%%%------------------------------------
%%%             回调函数
%%%------------------------------------

init(_) ->
    process_flag(trap_exit, true),
    lib_rank:init_rank(),           %% 创建空排行榜
    {ok, handle, []}.

handle('init_data', StateData) ->
    {next_state, handle, StateData, ?INIT_RANK_DELAY};

handle(_, StateData) ->
    lib_rank:update_rank(),
    {next_state, handle, StateData}.

handle_event(_Event, _StateName, StateData) ->
    {next_state, handle, StateData}.

handle_sync_event(_Event, _From, _StateName, StateData) ->
    {next_state, handle, StateData}.

code_change(_OldVsn, _StateName, State, _Extra) ->
    {ok, handle, State}.

handle_info(_Any, _StateName, State) ->
    {next_state, handle, State}.

terminate(_Any, _StateName, _Opts) ->
    ok.
