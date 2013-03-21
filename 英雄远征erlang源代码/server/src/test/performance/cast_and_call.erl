%%%---------------------------------------------
%%% @module  : cast_and_call
%%% @author  : xyao
%%% @email   : jiexiaowen@gmail.com
%%% @created : 2010.05.03
%%% @description: gen_server cast and call 测试
%%% @result：cast 要比call 快0.006毫秒
%%%---------------------------------------------
-module(cast_and_call).
-behaviour(gen_server).

%%Interface functions. 
-export([start/0, test/0]).

%%gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

start() ->
    gen_server:start(?MODULE, [], []).

init([]) ->
    {ok, 1}.

handle_cast('TEST', Status) ->
    %%io:format("This is cast. ~n"),
    {noreply, Status}.

handle_call('TEST', _FROM, Status) ->
    %%io:format("This is call. ~n"),
    {reply, ok, Status}.

handle_info(_Info, Status) ->
    {noreply, Status}.

terminate(normal, Status) ->
    {ok, Status}.

code_change(_OldVsn, Status, _Extra)->
	{ok, Status}.

test() ->
    {ok, Pid} = start(),
    fprof:apply(gen_server, call, [Pid, 'TEST']),
    fprof:profile(),
    fprof:analyse({dest, "call.analysis"}),
    fprof:apply(gen_server, cast, [Pid, 'TEST']),
    fprof:profile(),
    fprof:analyse({dest, "cast.analysis"}),
    F1 = fun() -> gen_server:call(Pid, 'TEST') end,
    F2 = fun() -> gen_server:cast(Pid, 'TEST') end,
    prof:run(F1, 100000),
    prof:run(F2, 100000).
    


