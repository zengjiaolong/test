%%%-----------------------------------
%%% @Module  : sd_sup
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.04.15
%%% @Description: 监控树
%%%-----------------------------------
-module(sd_sup).
-behaviour(supervisor).
-export([start_link/0, start_child/1, start_child/2, init/1]).

start_link() ->
	supervisor:start_link({local,?MODULE}, ?MODULE, []).

start_child(Mod) ->
    start_child(Mod, []).

start_child(Mod, Args) ->
    {ok, _} = supervisor:start_child(?MODULE,
                                     {Mod, {Mod, start_link, Args},
                                      transient, 100, worker, [Mod]}),
    ok.

init([]) -> 
	%gen_event:swap_handler(alarm_handler, {alarm_handler, swap}, {sd_alarm_handler, sd_server}),
	{ok, {   
            {one_for_one, 3, 10},   
            []         
	}}. 
