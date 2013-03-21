%%%-----------------------------------
%%% @Module  : pt_11
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.04.29
%%% @Description: 11聊天信息
%%%-----------------------------------
-module(pt_11).
-export([read/2, write/2]).

%%
%%客户端 -> 服务端 ----------------------------
%%

%%世界聊天
read(11001, <<Color:8, Bin/binary>>) ->
    {Msg, _} = pt:read_string(Bin),
    {ok, [Color, Msg]};

%%私聊
read(11002, <<Color:8, Id:32, Bin/binary>>) ->
    {Nick, Bin1} = pt:read_string(Bin),
    {Msg, _} = pt:read_string(Bin1),
    {ok, [Color, Id, Nick, Msg]};

%%场景聊天
read(11003, <<Color:8, Bin/binary>>) ->
    {Msg, _} = pt:read_string(Bin),
    {ok, [Color, Msg]};

%%帮派聊天
read(11005, <<Color:8, Bin/binary>>) ->
    {Msg, _} = pt:read_string(Bin),
    {ok, [Color, Msg]};

%%队伍聊天
read(11006, <<Color:8, Bin/binary>>) ->
    {Msg, _} = pt:read_string(Bin),
    {ok, [Color, Msg]};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%%世界
write(11001, [Id, Nick, Bin, Color]) ->
    Nick1 = list_to_binary(Nick),
    Len = byte_size(Nick1),
    Bin1 = list_to_binary(Bin),
    Len1 = byte_size(Bin1),
    Data = <<Id:32, Len:16, Nick1/binary, Len1:16, Bin1/binary, Color:8>>,
    {ok, pt:pack(11001, Data)};

%%私聊
write(11002, [Id, Nick, Bin, Color]) ->
    Nick1 = list_to_binary(Nick),
    Len = byte_size(Nick1),
    Bin1 = list_to_binary(Bin),
    Len1 = byte_size(Bin1),
    Data = <<Id:32, Len:16, Nick1/binary, Len1:16, Bin1/binary, Color:8>>,
    {ok, pt:pack(11002, Data)};

%%场景聊天
write(11003, [Id, Nick, Bin, Color]) ->
    Nick1 = list_to_binary(Nick),
    Len = byte_size(Nick1),
    Bin1 = list_to_binary(Bin),
    Len1 = byte_size(Bin1),
    Data = <<Id:32, Len:16, Nick1/binary, Len1:16, Bin1/binary, Color:8>>,
    {ok, pt:pack(11003, Data)};

%%聊天系统信息
write(11004, Msg) ->
    Msg1 = list_to_binary(Msg),
    Len1 = byte_size(Msg1),
    Data = <<Len1:16, Msg1/binary>>,
    {ok, pt:pack(11004, Data)};

%%帮派系统信息
write(11005, [GuildId, GuildName, MsgContent, Color]) ->
    GuildNameBin  = list_to_binary(GuildName),
    GuildNameLen  = byte_size(GuildNameBin),
    MsgContentBin = list_to_binary(MsgContent),
    MsgContentLen = byte_size(MsgContentBin),
    Data = <<GuildId:32, GuildNameLen:16, GuildNameBin/binary, MsgContentLen:16, MsgContentBin/binary, Color:8>>,
    {ok, pt:pack(11005, Data)};

%%队伍聊天
write(11006, [Id, Nick, Bin, Color]) ->
    Nick1 = list_to_binary(Nick),
    Len = byte_size(Nick1),
    Bin1 = list_to_binary(Bin),
    Len1 = byte_size(Bin1),
    Data = <<Id:32, Len:16, Nick1/binary, Len1:16, Bin1/binary, Color:8>>,
    {ok, pt:pack(11006, Data)};


%%私聊返回黑名单通知
write(11007, Id) ->
    {ok, pt:pack(11007, <<Id:32>>)};

write(_Cmd, _R) ->
    {ok, pt:pack(0, <<>>)}.
