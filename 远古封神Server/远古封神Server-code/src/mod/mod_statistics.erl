%%%------------------------------------
%%% @Module     : mod_statistics
%%% @Author     : lzz
%%% @Created    : 2010.12.24
%%% @Description: 统计
%%%------------------------------------
-module(mod_statistics).
-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-compile(export_all).

%% 每1分钟 统计一次在线人数
-define(STATISTCS_INTERVAL, 60*1000).

-record(state, {}).
%%%------------------------------------
%%%             接口函数
%%%------------------------------------

start() ->      %% 启动服务
	gen_server:start(?MODULE, [], []).

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([]) ->
	%%初始化统计进程
	{M, S, _} = erlang:now(),
    Nowtime = M * 1000000 + S,
	Bufftime = 60 - ((Nowtime+30) rem 60),
	erlang:send_after(Bufftime*1000, self(), {event, statistics}),
	State = #state{},
	{ok, State}.	

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
handle_cast(_Rec, Status) ->
    {noreply, Status}.

handle_call(_Rec, _FROM, Status) ->
    {reply, ok, Status}.

%%在线统计
handle_info({event, statistics}, State) ->
	erlang:spawn(lib_statistics, statistics_min, []),
	erlang:send_after(?STATISTCS_INTERVAL, self(), {event, statistics}),
	{noreply, State};

handle_info(_Info, Status) ->
    {noreply, Status}.


%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
	misc:delete_system_info(self()),
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
