%%%-----------------------------------
%%% @Module  : sd_gateway_sup
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.04.15
%%% @Description: 监控树
%%%-----------------------------------
-module(sd_gateway_sup).
-behaviour(supervisor).
-export([start_link/1]).
-export([init/1]).
-include("common.hrl").

start_link([Ip, Port, Sid]) ->
	supervisor:start_link({local,?MODULE}, ?MODULE, [Ip, Port, Sid]).

init([Ip, Port, Sid]) ->
    {ok,
        {
            {one_for_one, 3, 10},
            [
                {
                    sd_gateway,
                    {sd_gateway, start_link, [Port]},
                    permanent,
                    10000,
                    supervisor,
                    [sd_gateway]
                },
                {
                    mod_disperse,
                    {mod_disperse, start_link,[Ip, Port, Sid]},
                    permanent,
                    10000,
                    supervisor,
                    [mod_disperse]
                }
            ]
        }
    }.
