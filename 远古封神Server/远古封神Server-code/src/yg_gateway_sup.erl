%%%-----------------------------------
%%% @Module  : yg_gateway_sup
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 网关监控树
%%%-----------------------------------
-module(yg_gateway_sup).
-behaviour(supervisor).
-export([start_link/1]).
-export([init/1]).
-include("common.hrl").

start_link([Ip, Port, Node_id]) ->
	supervisor:start_link({local,?MODULE}, ?MODULE, [Ip, Port, Node_id]).

init([Ip, Port, Node_id]) ->
    {ok,
        {
            {one_for_one, 3, 10},
            [
                {
                    yg_gateway,
                    {yg_gateway, start_link, [Port]},
                    permanent,
                    10000,
                    supervisor,
                    [yg_gateway]
                },
                {
                    mod_disperse,
                    {mod_disperse, start_link,[Ip, Port, Node_id]},
                    permanent,
                    10000,
                    supervisor,
                    [mod_disperse]
                }
            ]
        }
    }.
