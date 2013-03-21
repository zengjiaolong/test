%%%----------------------------------------------------------------------
%%% File    : yg_timer.erl
%%% Author  : ygzj
%%% Created : 2010-10-17
%%% Description: 时间生成器
%%%----------------------------------------------------------------------
-module(yg_timer).

-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("common.hrl").

%% --------------------------------------------------------------------
%% External exports
-export([now/0, now_seconds/0, cpu_time/0, start_link/0, start/1, info/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%% ====================================================================
%% External functions
%% ====================================================================
now() -> 
	[{timer, {Now, _}}] = ets:lookup(ets_timer, timer),
	Now.

now_seconds()->
	[{timer, {Now, _}}] = ets:lookup(ets_timer, timer),
	{MegaSecs, Secs, _MicroSecs} = Now,
	lists:concat([MegaSecs, Secs]).

cpu_time() -> 
	[{timer, {_, Wallclock_Time_Since_Last_Call}}] = ets:lookup(ets_timer, timer),
	Wallclock_Time_Since_Last_Call.

info() ->
	[
	 ets:info(ets_timer), 
     ets:tab2list(ets_timer)
    ].

-define(CLOCK, 1000).

start(Sup) ->
	supervisor:start_child(Sup, 
						   {yg_timer,
							{yg_timer, start_link, []},
							permanent, brutal_kill, worker, [yg_timer]}).

%% ====================================================================
%% Server functions
%% ====================================================================

start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([]) ->
	ets:new(ets_timer, [set, protected, named_table ,?ETSRC, ?ETSWC]),
	ets:insert(ets_timer, {timer, {erlang:now(), 0}}),
	erlang:send_after(?CLOCK, self(), {event, clock}),
	misc:write_monitor_pid(self(),?MODULE, {}),	
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
handle_call(_Request, _From, State) ->
    {reply, State, State}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_cast(_Msg, State) ->
	{noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_info({event, clock}, State) ->
%% 	{_Total_Wallclock_Time, Wallclock_Time_Since_Last_Call}= statistics(wall_clock),
 	{_Total_Run_Time, Time_Since_Last_Call} = statistics(runtime),
	ets:insert(ets_timer, {timer, {erlang:now(), Time_Since_Last_Call}}),
	erlang:send_after(?CLOCK, self(), {event, clock}),
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
