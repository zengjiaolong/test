%%%------------------------------------
%%% @Module  : pt_24
%%% @Author  : zzm
%%% @Email   : ming_up@163.com
%%% @Created : 2010.07.06
%%% @Description: 组队协议
%%%------------------------------------

-module(pt_24).
-export([read/2, write/2]).

%%
%%客户端 -> 服务端 ----------------------------
%%

%%创建队伍
read(24000, <<Bin/binary>>) ->
    {TeamName, _} = pt:read_string(Bin),
    {ok, TeamName};

%%加入队伍
read(24002, <<Id:32>>) ->
    {ok, Id};

%%队长处理加入队伍请求
read(24004, <<Res:16, Id:32>>) ->
    {ok, [Res, Id]};

%%离开队伍
read(24005, _R) ->
    {ok, []};

%%邀请人加入队伍
read(24006, <<Id:32>>) ->
    {ok, Id};

%%被邀请人处理邀请进队信息
read(24008, <<Id:32, Res:16>>) ->
    {ok, [Id, Res]};

%%踢出队伍
read(24009, <<Id:32>>) ->
    {ok, Id};

%%委任队长
read(24013, <<Id:32>>) ->
    {ok, Id};

%%更改队名
read(24014, <<Bin/binary>>) ->
    {TeamName, _} = pt:read_string(Bin),
    {ok, TeamName};

%%队伍资料
read(24016, <<Id:32>>) ->
    {ok, Id};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%%创建队伍
write(24000, [Res, TeamName]) ->
    TeamName1 = list_to_binary(TeamName),
    L = byte_size(TeamName1),
    Data = <<Res:16, L:16, TeamName1/binary>>,
    {ok, pt:pack(24000, Data)};

%%加入队伍
write(24002, Res) ->
    Data = <<Res:16>>,
    {ok, pt:pack(24002, Data)};

%%向队长发送加入队伍请求
write(24003, [Id, Lv, Career, Realm, Nick]) ->
    Nick1 = list_to_binary(Nick),
    L = byte_size(Nick1),
    Data = <<Id:32, Lv:16, Career:16, Realm:16, L:16, Nick1/binary>>,
    {ok, pt:pack(24003, Data)};

%%队长处理加入队伍请求
write(24004, Res)->
    Data = <<Res:16>>,
    {ok, pt:pack(24004, Data)};

%%离开队伍
write(24005, Res)->
    Data = <<Res:16>>,
    {ok, pt:pack(24005, Data)};

%%邀请加入队伍
write(24006, Res)->
    Data = <<Res:16>>,
    {ok, pt:pack(24006, Data)};

%%向被邀请人发出邀请
write(24007, [Id, Nick, TeamName]) ->
    Nick1 = list_to_binary(Nick),
    NL = byte_size(Nick1),
    TeamName1 = list_to_binary(TeamName),
    TNL = byte_size(TeamName1),
    Data = <<Id:32, NL:16, Nick1/binary, TNL:16, TeamName1/binary>>,
    {ok, pt:pack(24007, Data)};

%%邀请人邀请进队伍
write(24008, Res) ->
    Data = <<Res:16>>,
    {ok, pt:pack(24008, Data)};

%%踢出队员
write(24009, Res) ->
    Data = <<Res:16>>,
    {ok, pt:pack(24009, Data)};

%%向队员发送队伍信息
write(24010, [TeamId, TeamName, Member]) ->
    TeamName1 = list_to_binary(TeamName),
    TL = byte_size(TeamName1),
    N = length(Member),
    F = fun([Id, Lv, Career, Realm, Nick]) ->
            Nick1 = list_to_binary(Nick),
            L = byte_size(Nick1),
            <<Id:32, Lv:16, Career:16, Realm:8, L:16, Nick1/binary>>
    end,
    LN = list_to_binary([F(X)||X <- Member]),
    Data1 = <<TeamId:32, TL:16, TeamName1/binary, N:16, LN/binary>>,
    {ok, pt:pack(24010, Data1)};

%%向队员发送有人离队的信息
write(24011, Id) ->
    Data = <<Id:32>>,
    {ok, pt:pack(24011, Data)};

%%向队员发送更换队长的信息
write(24012, Id) ->
    Data = <<Id:32>>,
    {ok, pt:pack(24012, Data)};

%%委任队长
write(24013, Res) ->
    Data = <<Res:16>>,
    {ok, pt:pack(24013, Data)};

%%更改队名
write(24014, Res) ->
    Data = <<Res:16>>,
    {ok, pt:pack(24014, Data)};

%%通知队员队名更改了
write(24015, TeamName) ->
    TeamName1 = list_to_binary(TeamName),
    L = byte_size(TeamName1),
    Data = <<L:16, TeamName1/binary>>,
    {ok, pt:pack(24015, Data)};

%%队伍资料
write(24016, [Id, MbNum, Nick, TeamName]) ->
    Nick1 = list_to_binary(Nick),
    NL = byte_size(Nick1),
    TeamName1 = list_to_binary(TeamName),
    TNL = byte_size(TeamName1),
    Data = <<Id:32, MbNum:16, NL:16, Nick1/binary, TNL:16, TeamName1/binary>>,
    {ok, pt:pack(24016, Data)};

%%通知队员队伍解散
write(24017, []) ->
    {ok, pt:pack(24017, <<>>)};

%%给队伍进入副本信息
write(24030, Sid) ->
    {ok, pt:pack(24030, <<Sid:32>>)};

write(_Cmd, _R) ->
    {ok, pt:pack(0, <<>>)}.
