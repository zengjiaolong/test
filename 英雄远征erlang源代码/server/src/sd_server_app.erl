%%%-----------------------------------
%%% @Module  : sd_server_app
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.04.15
%%% @Description: 打包程序
%%%-----------------------------------
-module(sd_server_app).
-behaviour(application).
-export([start/2, stop/1]).
-include("common.hrl").
-include("record.hrl").

start(normal, []) ->
    %%从启动参数-extra换取参数（节点，端口，游戏线路）
    [Ip, Port, Sid] = init:get_plain_arguments(),
    {ok, SupPid} =sd_sup:start_link(),
    sd_networking:start([Ip, list_to_integer(Port), list_to_integer(Sid)]),
    {ok, SupPid}.
  
stop(_State) ->   
    void. 
