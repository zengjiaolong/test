%%%------------------------------------
%%% @Module  : mod_user
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.05.12
%%% @Description: 用户
%%%------------------------------------
-module(mod_user).
-behaviour(gen_server).
-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-include("common.hrl").
-include("record.hrl").

start_link() ->
    gen_server:start_link(?MODULE, [], []).
    
init([]) ->
    process_flag(trap_exit, true),
    {ok, []}.

handle_cast(_R , Status) ->
    {noreply, Status}.

handle_call({'get'}, _FROM, Status) ->
    {reply, Status, Status};

handle_call({'set', S, Socket, Id, Nick}, _FROM, Status) ->
    Status1 = Status ++ [{S, Socket, Id, Nick}],
    {reply, ok, Status1};

handle_call({'del',Socket}, _FROM, Status) ->
    Status1 = lists:keydelete(Socket,2,Status),
    {reply, ok, Status1};

handle_call(_R , _FROM, Status) ->
    {reply, ok, Status}.

handle_info(_Reason, Status) ->
    {noreply, Status}.

terminate(normal, Status) ->
    {ok, Status}.

code_change(_OldVsn, Status, _Extra)->
	{ok, Status}.
