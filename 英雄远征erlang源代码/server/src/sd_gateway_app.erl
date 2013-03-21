%%%-----------------------------------
%%% @Module  : sd_gateway_app
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.04.15
%%% @Description: 打包程序
%%%-----------------------------------
-module(sd_gateway_app).
-behaviour(application).
-export([start/2, stop/1]).  
-include("common.hrl").

start(_Type, _Args) ->
    init_mysql(),
    [Ip, Port, Sid] = init:get_plain_arguments(),
    sd_gateway_sup:start_link([Ip, list_to_integer(Port), list_to_integer(Sid)]).
  
stop(_State) ->   
    void.

%% mysql数据库连接初始化
init_mysql() ->
    mysql:start_link(?DB, ?DB_HOST, ?DB_PORT, ?DB_USER, ?DB_PASS, ?DB_NAME, fun(_, _, _, _) -> ok end, ?DB_ENCODE),
    mysql:connect(?DB, ?DB_HOST, ?DB_PORT, ?DB_USER, ?DB_PASS, ?DB_NAME, ?DB_ENCODE, true),
    ok.
