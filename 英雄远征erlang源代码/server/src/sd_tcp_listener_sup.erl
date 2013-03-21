%%%-----------------------------------
%%% @Module  : sd_tcp_listener_sup
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.06.01
%%% @Description: tcp listerner 监控树
%%%-----------------------------------

-module(sd_tcp_listener_sup).

-behaviour(supervisor).

-export([start_link/1]).

-export([init/1]).

start_link(Port) ->
    supervisor:start_link(?MODULE, {10, Port}).

init({AcceptorCount, Port}) ->
    {ok,
        {{one_for_all, 10, 10},
            [
                {
                    sd_tcp_acceptor_sup,
                    {sd_tcp_acceptor_sup, start_link, []},
                    transient,
                    infinity,
                    supervisor,
                    [sd_tcp_acceptor_sup]
                },
                {
                    sd_tcp_listener,
                    {sd_tcp_listener, start_link, [AcceptorCount, Port]},
                    transient,
                    100,
                    worker,
                    [sd_tcp_listener]
                }
            ]
        }
    }.
