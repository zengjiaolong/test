%%%-----------------------------------
%%% @Module  : yg_tcp_listener
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: tcp listerner监听
%%%-----------------------------------
-module(yg_tcp_listener).
-behaviour(gen_server).
-export([start_link/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,terminate/2, code_change/3]).
-include("common.hrl").

start_link(AcceptorCount, Port) ->
    gen_server:start_link(?MODULE, {AcceptorCount, Port}, []).

init({AcceptorCount, Port}) ->
    process_flag(trap_exit, true),
	misc:write_monitor_pid(self(),?MODULE, {}),
    case gen_tcp:listen(Port, ?TCP_OPTIONS) of
        {ok, LSock} ->
            lists:foreach(fun (_) ->
                          	{ok, _APid} = supervisor:start_child(
                                            yg_tcp_acceptor_sup, [LSock])
                          end,
                          lists:duplicate(AcceptorCount, dummy)),
            %{ok, {LIPAddress, LPort}} = inet:sockname(LSock),
            {ok, LSock};
        {error, Reason} ->
            {stop, {cannot_listen, Reason}}
    end.

handle_call(_Request, _From, State) ->
    {reply, State, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, State) ->
    %{ok, {IPAddress, Port}} = inet:sockname(State),
    gen_tcp:close(State),
	misc:delete_monitor_pid(self()),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
