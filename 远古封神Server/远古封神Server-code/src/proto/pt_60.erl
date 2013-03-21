%%%-----------------------------------
%%% @Module  : pt_60
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 60 网关
%%%-----------------------------------
-module(pt_60).
-export([read/2, write/2]).
-include("common.hrl").

%%
%%客户端 -> 服务端 ----------------------------
%%

%% 请求服务器列表
read(60000, _) ->
    {ok, list};

%% 是否有角色
read(60001, <<Sn:16, Bin/binary>>) ->
    {Accname, _} = pt:read_string(Bin),
    {ok, [Sn, Accname]};

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
    F = fun([Id, Ip, Port, State, Num, _System_status]) ->
        Ip1 = tool:to_binary(Ip),
        Len = byte_size(Ip1),
        <<Id:8, Len:16, Ip1/binary, Port:16, State:8, Num:16>>
    end,
    RB = tool:to_binary([F(D) || D <- List]),
    {ok, pt:pack(60000, <<Rlen:16, RB/binary>>)};

%% 是否有角色
write(60001, Is) ->
    {ok, pt:pack(60001, <<Is:8>>)};

%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.
