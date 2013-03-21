%%%-----------------------------------
%%% @Module  : 60
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.06.30
%%% @Description: 60 网关
%%%-----------------------------------
-module(pt_60).
-export([read/2, write/2]).

%%
%%客户端 -> 服务端 ----------------------------
%%

%% 请求服务器列表
read(60000, _) ->
    {ok, list};

%% 是否有角色
read(60001, <<Bin/binary>>) ->
    {Accname, _} = pt:read_string(Bin),
    {ok, Accname};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%% 服务器列表
write(60000, []) ->
    {ok, pt:pack(0, <<>>)};
write(60000, List) ->
    Rlen = length(List),
    F = fun([Id, Ip, Port, State, Num]) ->
        Ip1 = list_to_binary(Ip),
        Len = byte_size(Ip1),
        <<Id:8, Len:16, Ip1/binary, Port:16, State:8, Num:16>>
    end,
    RB = list_to_binary([F(D) || D <- List]),
    {ok, pt:pack(60000, <<Rlen:16, RB/binary>>)};

%% 是否有角色
write(60001, Is) ->
    {ok, pt:pack(60001, <<Is:8>>)};

write(_Cmd, _R) ->
    {ok, pt:pack(0, <<>>)}.
