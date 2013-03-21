%%%--------------------------------------
%%% @Module  : pp_meridian
%%% @Author  : hc
%%% @Email   : hc@jieyou.com
%%% @Created : 2010.08.09
%%% @Description:  ����ϵͳ����
%%%--------------------------------------

-module(pp_meridian).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%经脉开脉
handle(25010, PlayerStatus, MeridianId) ->
    Value = lib_meridian:id_to_type(MeridianId),
   {_, _,MerdianValue,Err} =  mod_meridian:meridian_active(PlayerStatus,Value),
   {ok, Bin} = pt_25:write(25010, [MeridianId,MerdianValue,Err]),
   gen_tcp:send(PlayerStatus#player_status.socket, Bin);

%经脉信息
handle(25020, PlayerStatus, PlayerId) ->
%    io:format("PlayerId=~p~n",[PlayerId]),
    {ok,Data} = lib_meridian:check_meridian_info(PlayerId),
    {ok,Bin} = pt_25:write(25020,Data),
    gen_tcp:send(PlayerStatus#player_status.socket, Bin);

%经脉属性
handle(25030, PlayerStatus, [PlayerId,MeridianId]) ->
    Value = lib_meridian:id_to_type(MeridianId),
    {_,Mer_Lvl} = lib_meridian:check_meridian_lvl_byId(PlayerId,MeridianId),
    Lvl = Mer_Lvl div 10,
    [{1,V1},{2,V2},{3,V3},{4,V4},{5,V5},{6,V6},{7,V7},{8,V8}] = lib_meridian:get_value_between_two_lvl(Value),
    Data = [{1,V1*Lvl},{2,V2*Lvl},{3,V3*Lvl},{4,V4*Lvl},{5,V5*Lvl},{6,V6*Lvl},{7,V7*Lvl},{8,V8*Lvl}],
    {ok,Bin} = pt_25:write(25030,[PlayerId,MeridianId]++Data),
    gen_tcp:send(PlayerStatus#player_status.socket, Bin);

handle(_Cmd, _Status, _Data) ->
    ?DEBUG("pp_meridian no match", []),
    {error, "pp_meridian no match"}.


