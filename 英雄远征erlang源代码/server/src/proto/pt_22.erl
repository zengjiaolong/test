%%%------------------------------------
%%% @Module     : pt_22
%%% @Author     : huangyongxing
%%% @Email      : huangyongxing@yeah.net
%%% @Created    : 2010.07.22
%%% @Description: 排行榜协议处理
%%%------------------------------------
-module(pt_22).
-export([read/2, write/2]).
-include("record.hrl").

%%
%%客户端 -> 服务端 ----------------------------
%%

%% 查询人物排行榜
read(22001, <<Realm:8, Career:8, Type:8>>) ->
    {ok, [Realm, Career, Type]};

%% %% 查询装备排名
read(22002, <<Type:8>>) ->
    {ok, Type};

%% 查询帮会排名
read(22003, <<Type:8>>) ->
    {ok, Type};

read(_, _) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%% 查询人物排名
write(22001, []) ->
    {ok, pt:pack(22001, <<0:16>>)};     %% 无数据
write(22001, [RoleRank]) ->
    RankList = RoleRank#ets_rank.rank_list,
    F = fun(Info) ->
            [Rank, Id, Nick, Sex, Career, _, GuildName, Value] = Info,
            Len1 = byte_size(Nick),
            Len2 = byte_size(GuildName),
            <<Rank:16, Id:32, Len1:16, Nick/binary, Sex:8, Career:8, Len2:16, GuildName/binary, Value:32>>
    end,
    Size = length(RankList),
    BinList = list_to_binary([F(Info) || Info <- RankList]),
    {ok, pt:pack(22001, <<Size:16, BinList/binary>>)};

%% 查询装备排名
write(22002, []) ->
    {ok, pt:pack(22002, <<0:16>>)};     %% 无数据
write(22002, [EquipRank]) ->
    RankList = EquipRank#ets_rank.rank_list,
    F = fun(Info) ->
            [Rank, GoodsId, GoodsName, PlayerId, PlayerName, Guild, Score] = Info,
            Len1 = byte_size(GoodsName),
            Len2 = byte_size(PlayerName),
            Len3 = byte_size(Guild),
            NewScore = trunc(Score),
            <<Rank:16, GoodsId:32, Len1:16, GoodsName/binary, PlayerId:32, Len2:16, PlayerName/binary, Len3:16, Guild/binary, NewScore:32>>
    end,
    Size = length(RankList),
    BinList = list_to_binary([F(Info) || Info <- RankList]),
    {ok, pt:pack(22002, <<Size:16, BinList/binary>>)};

%% 查询帮会排名
write(22003, []) ->
    {ok, pt:pack(22003, <<0:16>>)};
write(22003, [GuildRank]) ->
    RankList = GuildRank#ets_rank.rank_list,
    F = fun(Info) ->
            [Rank, Id, Name, Realm, Level] = Info,
            Len = byte_size(Name),
            <<Rank:16, Id:32, Len:16, Name/binary, Realm:8, Level:8>>
    end,
    Size = length(RankList),
    BinList = list_to_binary([F(Info) || Info <- RankList]),
    {ok, pt:pack(22003, <<Size:16, BinList/binary>>)};

write(_, _) ->
    {ok, pt:pack(0, <<>>)}.
