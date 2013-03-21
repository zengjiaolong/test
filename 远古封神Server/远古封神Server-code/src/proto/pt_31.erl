%%%-----------------------------------
%%% @Module  : pt_31
%%% @Author  : lzz
%%% @Created : 2010.12.15
%%% @Description: 31传送
%%%-----------------------------------
-module(pt_31).
-export([read/2, write/2]).
-include("common.hrl").
-include("record.hrl").

%%
%%客户端 -> 服务端 ----------------------------
%%

%% 传送信息
read(31000, <<Scid:16>>) ->
    {ok, [Scid]};

%% 绑定回城石信息
read(31001, <<Scid:16>>) ->
    {ok, [Scid]};

%% 使用回城石信息
read(31002, <<GoodsId:32>>) ->
    {ok, [GoodsId]};

%% 幻魔穴区域信息
read(31010, <<>>) ->
    {ok, <<>>};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%


%%传送信息
write(31000, [Res, Coin, Bcoin]) ->
    {ok, pt:pack(31000, <<Res:8, Coin:32, Bcoin:32>>)};


%%绑定回城石信息
write(31001, [Res]) ->
    {ok, pt:pack(31001, <<Res:8>>)};

%% 使用回城石信息
write(31002, [Res]) ->
    {ok, pt:pack(31002, <<Res:8>>)};

%% 幻魔穴区域信息
write(31010, [ZoneId]) ->
    {ok, pt:pack(31010, <<ZoneId:8>>)};

%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.

