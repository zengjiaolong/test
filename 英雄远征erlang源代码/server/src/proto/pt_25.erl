%%%------------------------------------
%%% @Module  : pt_25
%%% @Author  : hc
%%% @Email   : hc@jieyou.com
%%% @Created : 2010.08.09
%%% @Description: 经脉协议
%%%------------------------------------

-module(pt_25).
-export([read/2, write/2]).

%%
%%客户端 -> 服务端 ----------------------------
%%

%%开经脉
read(25010, <<MeridianId:16>>) ->
    {ok, MeridianId};

%%查看经脉信息
read(25020, <<PlayerId:32>>) ->
%    io:format("PlayerId=~p~n",[PlayerId]),
    {ok, PlayerId};

%%查看经脉属性
read(25030, <<PlayerId:32,MeridianId:16>>) ->
    {ok, [PlayerId,MeridianId]};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%
write(25010, [MeridianId,MeridianValue,Err]) ->
    {ok, pt:pack(25010, <<MeridianId:16,MeridianValue:16,Err:16>>)};

write(25020, [PlyId,M_ren,M_du,M_chong,M_dai,M_yinwei,M_yangwei,M_yinqiao,M_yangqiao]) ->
    {ok, pt:pack(25020, <<PlyId:32,M_ren:16,M_du:16,M_chong:16,M_dai:16,M_yinwei:16,M_yangwei:16,M_yinqiao:16,M_yangqiao:16>>)};

write(25030, [PlyId,MerId,{_,Crit},{_,Ten},{_,Hit},{_,Shun},{_,Att},{_,Def},{_,HP},{_,Mp}]) ->
    {ok, pt:pack(25030, <<PlyId:32,MerId:16,Crit:16,Ten:16,Hit:16,Shun:16,Att:16,Def:16,HP:16,Mp:16>>)};

write(_Cmd, _R) ->
    {ok, pt:pack(0, <<>>)}.
