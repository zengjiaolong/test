%%%-----------------------------------
%%% @Module  : pt_16
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.04.29
%%% @Description: 16坐骑信息
%%%-----------------------------------
-module(pt_16).
-include("record.hrl").
-export([read/2, write/2]).

%%
%%客户端 -> 服务端 ----------------------------
%%

%% 获取坐骑详细信息
read(16001, <<MountId:32>>) ->
    %io:format("read: ~p~n",[[16001, MountId]]),
    {ok, MountId};

%% 乘上坐骑
read(16002, <<MountId:32>>) ->
    %io:format("read: ~p~n",[[16002, MountId]]),
    {ok, MountId};

%% 离开坐骑
read(16003, <<MountId:32>>) ->
    %io:format("read: ~p~n",[[16003, MountId]]),
    {ok, MountId};

%% 丢弃坐骑
read(16004, <<MountId:32>>) ->
    %io:format("read: ~p~n",[[16004, MountId]]),
    {ok, MountId};

read(_Cmd, _R) ->
    %io:format("read: ~p~n",[[_Cmd, _R]]),
    {error, no_match}.



%% 获取坐骑详细信息
write(16001, [Res, MountId, MountTypeId, BindState, UseState]) ->
    %io:format("write: ~p~n",[[16001, Res, MountId, MountTypeId, BindState, UseState]]),
    {ok, pt:pack(16001, <<Res:16, MountId:32, MountTypeId:32, BindState:16, UseState:16>>)};

%% 乘上坐骑
write(16002, [Res, MountId, OldMountId, OldMountTypeId, OldMountCell, NewSpeed]) ->
    %io:format("write: ~p~n",[[16002, Res, MountId, OldMountId, OldMountTypeId, OldMountCell, NewSpeed]]),
    {ok, pt:pack(16002, <<Res:16, MountId:32, OldMountId:32, OldMountTypeId:32, OldMountCell:16, NewSpeed:16>>)};

%% 离开坐骑
write(16003, [Res, MountId, MountTypeId, MountCell, NewSpeed]) ->
    %io:format("write: ~p~n",[[16003, Res, MountId, MountTypeId, MountCell, NewSpeed]]),
    {ok, pt:pack(16003, <<Res:16, MountId:32, MountTypeId:32, MountCell:16, NewSpeed:16>>)};

%% 丢弃坐骑
write(16004, [Res, MountId]) ->
    %io:format("write: ~p~n",[[16004, Res, MountId]]),
    {ok, pt:pack(16004, <<Res:16, MountId:32>>)};

write(_Cmd, _R) ->
    %io:format("write: ~p~n",[[_Cmd, _R]]),
    {ok, pt:pack(0, <<>>)}.


