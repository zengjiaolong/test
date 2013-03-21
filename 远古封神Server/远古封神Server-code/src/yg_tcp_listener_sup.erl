%%%-----------------------------------
%%% @Module  : yg_tcp_listener_sup
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: tcp listerner 监控树
%%%-----------------------------------

-module(yg_tcp_listener_sup).

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
                    yg_tcp_acceptor_sup,
                    {yg_tcp_acceptor_sup, start_link, []},
                    transient,
                    infinity,
                    supervisor,
                    [yg_tcp_acceptor_sup]
                },
                {
                    lists:concat([yg_tcp_listener_,Port]),
                    {yg_tcp_listener, start_link, [AcceptorCount, Port]},
                    transient,
                    100,
                    worker,
                    [yg_tcp_listener]
                },
				{
                    lists:concat([yg_tcp_listener_,Port-100]),
                    {yg_tcp_listener, start_link, [AcceptorCount, Port-100]},
                    transient,
                    100,
                    worker,
                    [yg_tcp_listener]
                },
				{
                    lists:concat([yg_tcp_listener_,Port-200]),
                    {yg_tcp_listener, start_link, [AcceptorCount, Port-200]},
                    transient,
                    100,
                    worker,
                    [yg_tcp_listener]
                }
            ]
        }
    }.
