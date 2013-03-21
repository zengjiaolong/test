%%%------------------------------------
%%% @Module     : pp_rank
%%% @Author     : huangyongxing
%%% @Email      : huangyongxing@yeah.net
%%% @Created    : 2010.07.22
%%% @Description: 排行榜处理
%%%------------------------------------
-module(pp_rank).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%% 查询人物排名
handle(22001, PlayerStatus, [Realm, Career, Type]) ->
    RankInfo = lib_rank:get_role_rank(Realm, Career, Type),
    {ok, BinData} = pt_22:write(22001, RankInfo),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%% 查询装备排名
handle(22002, PlayerStatus, Type) ->
    RankInfo = lib_rank:get_equip_rank(Type),
    {ok, BinData} = pt_22:write(22002, RankInfo),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%% 查询帮会排名
handle(22003, PlayerStatus, Type) ->
    RankInfo = lib_rank:get_guild_rank(Type),
    {ok, BinData} = pt_22:write(22003, RankInfo),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

handle(_Cmd, _Status, _Data) ->
    ?DEBUG("pp_rank no match", []),
    {error, "pp_rank no match"}.
