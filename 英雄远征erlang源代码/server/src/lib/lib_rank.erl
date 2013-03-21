%%%------------------------------------
%%% @Module     : lib_rank
%%% @Author     : huangyongxing
%%% @Email      : huangyongxing@yeah.net
%%% @Created    : 2010.07.22
%%% @Description: 排行榜处理函数
%%%------------------------------------
-module(lib_rank).
-include("common.hrl").
-include("record.hrl").
-compile(export_all).

-define(NUM_LIMIT, 100).                        %% 排行榜名次限制

%% 人物属性排行榜相关
-define(ROLE_RANK_TYPE_ID, Realm * 100 + Career * 10 + TypeNum). %% 排行榜类型编号规则
-define(REALM_NUM_LIST,  [0, 1, 2, 3]).         %% 阵营列表（0所有阵营、1天下盟、2无双盟、3傲世盟）
-define(CAREER_NUM_LIST, [0, 1, 2, 3]).         %% 职业列表（0所有职业、1昆仑－战士、2逍遥－法师、3唐门－刺客）
-define(ROLE_RANK_TYPE_LIST, [                  %% 排行类别列表
        {1, prestige},                          %% 声望
        {2, coin},                              %% 财富（铜钱）
        {3, lv},                                %% 等级
        {4, honor}                              %% 荣誉（帮派成员属性）
    ]).

%% 装备评分排行榜相关
-define(EQUIP_RANK_TYPE_ID, 1000 + Type).       %% 装备排行榜类型编号规则
-define(EQUIP_RANK_TYPE_LIST, [1, 2, 3]).       %% 装备类型列表（1武器，2防具，3饰品）

%% 帮派
-define(GUILD_RANK_TYPE_ID, 2000 + TypeNum).    %% 帮派排行榜类型编号规则
-define(GUILD_RANK_TYPE_LIST, [{1, level}]).    %% 帮派排行类别列表

%% @doc  将列表的每个元素（列表）加上次序信息
%% @spec add_order([], List, FirstNum) -> NewList
%% @var  List    : 需为每个元素（列表）添加序号的初始列表
%%       NewList : 添加序号后的新列表
add_order(AccList, [], _) ->
    lists:reverse(AccList);
add_order(AccList, [Info | List], N) ->
    NewInfo = [N | Info],
    add_order([NewInfo | AccList], List, N + 1).

%% @doc  根据物品类型ID查询ETS表获得物品名（二进制数据）
%% @spec get_equip_name(GoodsTypeId) -> GoodsName
get_equip_name(GoodsTypeId) ->
    case ets:lookup(?ETS_GOODS_TYPE, GoodsTypeId) of
        [] ->
            <<"">>;
        [Info] ->
            Info#ets_goods_type.goods_name
    end.

%% @doc  查询ETS表获取请求的排行榜
%% @spec get_equip_rank(Type) -> RankInfo
get_equip_rank(Type) when is_integer(Type) ->
    case Type >= 1 andalso Type =< 3 of
        true -> ets:lookup(?ETS_RANK, ?EQUIP_RANK_TYPE_ID);
        false -> []
    end;
get_equip_rank(_) -> [].

%% @doc  由数据库中取出的数据转换得到排行榜所需信息
%% @spec get_equip_rank_list(RankList, PlayerInfoList) -> NewRankList
get_equip_rank_list(RankList, PlayerInfoList) ->
    update_goods_info(RankList, PlayerInfoList, 1, []).

%% @doc  查询ETS表获取请求的排行榜
%% @spec get_guild_rank(TypeNum | Type) -> RankInfo
get_guild_rank(TypeNum) when is_integer(TypeNum) ->
    ets:lookup(?ETS_RANK, ?GUILD_RANK_TYPE_ID);
get_guild_rank(Type) ->
    case lists:keysearch(Type, 2, ?GUILD_RANK_TYPE_LIST) of
        {value, {TypeNum, _}} ->
            ets:lookup(?ETS_RANK, ?GUILD_RANK_TYPE_ID);
        false ->
            []
    end.

%% @doc  对装备计算出评分，并返回相应信息
%% @spec get_new_goods_info_list([], GoodsInfoList) -> NewGoodsInfoList
get_new_goods_info_list(AccList, []) ->
    AccList;    
get_new_goods_info_list(AccList, GoodsInfoList) ->
    [[Id, GoodsTypeId, PlayerId, Level, Color, Quality, Stren] | Rest] = GoodsInfoList,
    NewAccList = [{Id, GoodsTypeId, PlayerId, Level * (0.5 * Color + 2) * 5 + Quality * 150 + Stren * 100} | AccList],
    get_new_goods_info_list(NewAccList, Rest).

%% @doc  获得用户信息
%% @spec get_player_info_list([], PlayerIdList) -> PlayerInfoList
get_player_info_list(AccList, []) ->
    AccList;    
get_player_info_list(AccList, PlayerIdList) ->
    [PlayerId | Rest] = PlayerIdList,
    case ets:lookup(?ETS_ONLINE, PlayerId) of
        [] ->           %% 不在线要从数据库中取数据
            Sql = io_lib:format(<<"select id, nickname, guild_name from player where id = ~p">>, [PlayerId]),
            case db_sql:get_all(Sql) of
                [PlayerInfo] ->
                    ok;
                [] ->
                    PlayerInfo = [0, <<"">>, <<"">>]
            end;
        [OnlinePlayer] ->       %% 人物在线则从ETS表中取数据
            PlayerName = list_to_binary(OnlinePlayer#ets_online.nickname),
            GuildId = OnlinePlayer#ets_online.guild_id,
            case GuildId of
                0 ->
                    GuildName = <<>>;
                _ ->
                    [Guild] = ets:lookup(?ETS_GUILD, GuildId),
                    GuildName = Guild#ets_guild.name
            end,
            PlayerInfo = [PlayerId, PlayerName, GuildName]
    end,
    get_player_info_list([PlayerInfo | AccList], Rest).

%% @doc  查询ETS表获取请求的排行榜
%% @spec get_role_rank(Realm, Career, TypeNum) -> RankInfo
%% @var     TypeNum = integer()
get_role_rank(Realm, Career, TypeNum) when is_integer(TypeNum) ->
    RankTypeId = get_role_rank_type(Realm, Career, TypeNum),
    ets:lookup(?ETS_RANK, RankTypeId);
get_role_rank(_, _, _) -> [].

%% @doc  获得人物对应排行榜类型ID
%% @spec get_role_rank_type(Realm, Career, Type | TypeNum) -> RankTypeId | error
get_role_rank_type(Realm, Career, TypeNum) when is_integer(TypeNum) ->
    ?ROLE_RANK_TYPE_ID;
get_role_rank_type(Realm, Career, Type) ->
    case is_atom(Type) of
        true ->
            case lists:keysearch(Type, 2, ?ROLE_RANK_TYPE_LIST) of
                {value, {TypeNum, _}} ->
                    ?ROLE_RANK_TYPE_ID;
                false ->        %% 无此类型
                    error
            end;
        false ->
            error
    end.

%% @doc  创建排行榜ETS表
init_rank() ->
    %RoleRanks = loop_query_roles(?REALM_NUM_LIST, ?CAREER_NUM_LIST, ?ROLE_RANK_TYPE_LIST),   %% 获取人物相关排行
    %EquipRanks = loop_query_equip(?EQUIP_RANK_TYPE_LIST),   %% 获取装备相关排行
    %GuildRanks = loop_query_guild(?GUILD_RANK_TYPE_LIST),   %% 获取帮会相关排行
    %% 创建排行榜ETS表
    ets:new(?ETS_RANK, [named_table, public, set, {keypos,2}]),
    %% 插入排行榜数据
    %insert_rank_info(?ETS_RANK, RoleRanks),
    %insert_rank_info(?ETS_RANK, EquipRanks),
    %insert_rank_info(?ETS_RANK, GuildRanks),
    ok.

%% @doc  插入记录至ETS表
insert_rank_info(Tab, List) ->
    lists:foreach(fun(Record) -> ets:insert(Tab, Record) end, List),
    ok.

%% @doc  在列表列表（元素为列表的列表）中搜索特定元素（第N列搜索值为Key的元素）
%% @spec keysearch(Key, N, ListList) -> {ok, Value} | false
keysearch(_, _, []) ->
    false;
keysearch(Key, N, List) ->
    [List1 | NewList] = List,
    case lists:nth(N, List1) of
        Key ->
            {ok, List1};
        _ ->
            keysearch(Key, N, NewList)
    end.

%% @doc  根据装备类型列表查询相应排行信息
%% @spec loop_query_equip(EquipTypeList) -> AllEquipRanks
loop_query_equip(EquipTypeList) ->
    F = fun(Type) ->
            OldInfoList = query_equip(Type),                            %% 所有玩家物品信息列表
            NewInfoList = get_new_goods_info_list([], OldInfoList),     %% 进行评分得到新列表
            OldRankList = lists:sublist(lists:reverse(lists:keysort(4, NewInfoList)), ?NUM_LIMIT),  %% 排序
            PlayerIdList = lists:usort([PlayerId || {_, _, PlayerId, _} <- OldRankList]),         %% 去除重复Id
            PlayerInfoList = get_player_info_list([], PlayerIdList),    %% 获得玩家信息
            NewRankList = get_equip_rank_list(OldRankList, PlayerInfoList),
            make_rank_info(?EQUIP_RANK_TYPE_ID, NewRankList)
    end,
    lists:map(fun(Type) -> F(Type) end, EquipTypeList).

%% @doc  根据帮派排行类别查询相应排行信息
%% @spec loop_query_guild(GuildTypeList) -> AllGuildRanks
loop_query_guild(GuildTypeList) ->
    F = fun({TypeNum, Type}) ->
            OldRankList = query_guild(Type),
            NewRankList = add_order([], OldRankList, 1),
            make_rank_info(?GUILD_RANK_TYPE_ID, NewRankList)
    end,
    lists:map(fun(TypeInfo) -> F(TypeInfo) end, GuildTypeList).

%% @doc  根据RealmList、CareerList和TypeList循环查询，获得人物属性排行榜
%% @spec loop_query_roles(RealmList, CareerList, TypeList) -> AllRoleRanks
loop_query_roles(RealmList, CareerList, TypeList) ->
    loop_query_roles_1(RealmList, CareerList, TypeList, []).

%% @doc  根据RealmList、CareerList和TypeList循环执行查询，获得排名信息
loop_query_roles_1([], _, _, AccList) ->
    AccList;
loop_query_roles_1(RealmList, CareerList, TypeList, AccList) ->
    [Realm | NewList] = RealmList,
    case loop_query_roles_2(Realm, CareerList, TypeList, AccList) of
        error ->
            error;
        NewAccList ->
            loop_query_roles_1(NewList, CareerList, TypeList, NewAccList)
    end.

%% @doc  在Realm给定时，根据CareerList和TypeList中的元素循环查询
loop_query_roles_2(_, [], _, AccList) ->
    AccList;
loop_query_roles_2(Realm, CareerList, TypeList, AccList) ->
    [Career | NewList] = CareerList,
    case loop_query_roles_3(Realm, Career, TypeList, AccList) of
        error ->
            error;
        NewAccList ->
            loop_query_roles_2(Realm, NewList, TypeList, NewAccList)
    end.

%% @doc  在Realm、Career给定时根据TypeList中的元素循环查询
loop_query_roles_3(_, _, [], AccList) ->
    AccList;
loop_query_roles_3(Realm, Career, TypeList, AccList) ->
    [{TypeNum, Type} | NewList] = TypeList,
    RankList = query_roles(Realm, Career, Type),
    NewRankList = add_order([], RankList, 1),
    RankTypeId = get_role_rank_type(Realm, Career, TypeNum),
    RankRecord = make_rank_info(RankTypeId, NewRankList),
    NewAccList = [RankRecord | AccList],
    loop_query_roles_3(Realm, Career, NewList, NewAccList).

%% @doc  生成某排行榜信息
%% @spec make_rank_info(TypeId, List) -> error | Record
make_rank_info(TypeId, List) ->
    #ets_rank{type_id = TypeId, rank_list = List}.

%% @doc  查询装备相关属性
%% @spec query_equip(Type) -> GoodsInfoList
query_equip(Type) when is_integer(Type) ->
    Sql = io_lib:format(<<"select id, goods_id, player_id, level, color, quality, stren from goods where equip_type = ~p and player_id <> 0">>, [Type]),
    db_sql:get_all(Sql).

%% @doc  查询帮派相关属性，获取帮派属性的排行
%% @spec query_guild(Type) -> RankList
query_guild(Type) ->
    %Sql = io_lib:format(<<"select id, name, realm, ~p from guild order by ~p DESC limit ~p">>, [Type, Type, ?NUM_LIMIT]),
    %db_sql:get_all(Sql).       %% 查询数据库方式
    case get_position(Type) of  %% 查询ETS表方式
        {ok, Pos} ->
            GuildList = [ Guild || [Guild] <- ets:match(?ETS_GUILD, _ = '$1') ],
            NewGuildList = lists:sublist( lists:reverse( lists:keysort(Pos, GuildList) ), ?NUM_LIMIT),
            [ [Guild#ets_guild.id, Guild#ets_guild.name, Guild#ets_guild.realm, lists:nth(Pos, tuple_to_list(Guild))] || Guild <- NewGuildList];
        false ->
            []
    end.

%% @doc  查询某个字段在ets_guild记录中的位置
%% @spec get_position(Field) -> {ok, Position} | false
get_position(Field) when is_atom(Field) ->
    FieldList = record_info(fields, ets_guild),
    case get_first_pos(Field, FieldList) of
        {ok, Pos} ->
            {ok, Pos + 1};
        false ->
            false
    end;
get_position(_) ->
    false.

%%% @doc  查询某元素在列表中的位置列表
%%% @spec get_pos(Elem, List) -> {ok, PositionList} | false
%get_pos_list(Elem, List) when is_list(List) ->
%    F = fun
%        (_X, [], _N, PosList, _G) ->
%            case length(PosList) of
%                0 ->
%                    false;
%                _ ->
%                    {ok, lists:reverse(PosList)}
%            end;
%        (X, L, N, PosList, G) ->
%            [H | NewList] = L,
%            case X == H of
%                true ->
%                    G(X, NewList, N + 1, [N | PosList], G);
%                false ->
%                    G(X, NewList, N + 1, PosList, G)
%            end
%    end,
%    F(Elem, List, 1, [], F).

%% @doc  查询某元素在列表中首次出现的位置
%% @spec get_pos(Elem, List) -> {ok, Position} | false
get_first_pos(Elem, List) when is_list(List) ->
    F = fun
        (_X, [], _N, _G) ->
            false;
        (X, L, N, G) ->
            [H | NewList] = L,
            case X == H of
                true ->
                    {ok, N};
                false ->
                    G(X, NewList, N + 1, G)
            end
    end,
    F(Elem, List, 1, F).

%% @doc  查询人物相关属性
%% @spec query_roles(Realm, Career, Type) -> RankList
query_roles(Realm, Career, Type) ->
    %Str1 = "select player.id, player.nickname, player.sex, player.career, player.realm, guild_member.guild_name, guild_member.honor from guild_member inner join player on player.id = guild_member.player_id ",
    %Str2 = " order by guild_member.honor DESC limit ",
    F1 = fun(GuildMember) ->        %% 全阵营
            [Guild] = ets:lookup(?ETS_GUILD, GuildMember#ets_guild_member.guild_id),
            RoleRealm = Guild#ets_guild.realm,
            PlayerId = GuildMember#ets_guild_member.player_id,
            PlayerName = GuildMember#ets_guild_member.player_name,
            Sex = GuildMember#ets_guild_member.sex,
            RoleCareer = GuildMember#ets_guild_member.career,
            GuildName = GuildMember#ets_guild_member.guild_name,
            Honor = GuildMember#ets_guild_member.honor,
            [PlayerId, PlayerName, Sex, RoleCareer, RoleRealm, GuildName, Honor]
    end,
    F2 = fun(GuildMembers) ->        %% 单阵营
            F = fun
                ([], AccList, _G) ->
                    AccList;
                (Members, AccList, G) ->
                    [GuildMember | Rest] = Members,
                    GuildId = GuildMember#ets_guild_member.guild_id,
                    case ets:match(?ETS_GUILD, #ets_guild{id = GuildId, realm = Realm, _ = '_'}) of
                        [_Guild] ->
                            PlayerId = GuildMember#ets_guild_member.player_id,
                            PlayerName = GuildMember#ets_guild_member.player_name,
                            Sex = GuildMember#ets_guild_member.sex,
                            RoleCareer = GuildMember#ets_guild_member.career,
                            GuildName = GuildMember#ets_guild_member.guild_name,
                            Honor = GuildMember#ets_guild_member.honor,
                            NewAccList = [[PlayerId, PlayerName, Sex, RoleCareer, Realm, GuildName, Honor] | AccList],
                            G(Rest, NewAccList, G);
                        [] ->
                            G(Rest, AccList, G)
                    end
            end,
            F(GuildMembers, [], F)
    end,

    case Realm of
        0 ->            %% 全阵营
            case Career of
                0 ->        %% 全职业
                    case Type /= honor of
                        true ->
                            Sql = io_lib:format(<<"select id, nickname, sex, career, realm, guild_name, ~p from player order by ~p DESC limit ~p">>, [Type, Type, ?NUM_LIMIT]),
                            db_sql:get_all(Sql);
                        false ->
                            %Sql = lists:concat([Str1, Str2, ?NUM_LIMIT]),
                            %db_sql:get_all(Sql)
                            
                            [ F1(GuildMember) || [GuildMember] <- ets:match(?ETS_GUILD_MEMBER, _ = '$1')]
                    end;
                _ ->        %% 单职业
                    case Type /= honor of
                        true ->
                            Sql = io_lib:format(<<"select id, nickname, sex, career, realm, guild_name, ~p from player where career = ~p order by ~p DESC limit ~p">>, [Type, Career, Type, ?NUM_LIMIT]),
                            db_sql:get_all(Sql);
                        false ->
                            %Sql = lists:concat([Str1, " and player.career = ", Career, Str2, ?NUM_LIMIT]),
                            %db_sql:get_all(Sql)
                            [ F1(GuildMember) || GuildMember <- ets:match(?ETS_GUILD_MEMBER, #ets_guild_member{career = Career})]
                    end
            end;
        _ ->            %% 单阵营
            case Career of
                0 ->        %% 全职业
                    case Type /= honor of
                        true ->
                            Sql = io_lib:format(<<"select id, nickname, sex, career, realm, guild_name, ~p from player where realm = ~p order by ~p DESC limit ~p">>, [Type, Realm, Type, ?NUM_LIMIT]),
                            db_sql:get_all(Sql);
                        false ->
                            %Sql = lists:concat([Str1, " and player.realm = ", Realm, Str2, ?NUM_LIMIT]),
                            %db_sql:get_all(Sql)
                            F2( [GuildMember || [GuildMember] <- ets:match(?ETS_GUILD_MEMBER, _ = '$1') ] )
                    end;
                _ ->        %% 单职业
                    case Type /= honor of
                        true ->
                            Sql = io_lib:format(<<"select id, nickname, sex, career, realm, guild_name, ~p from player where career = ~p and realm = ~p order by ~p DESC limit ~p">>, [Type, Career, Realm, Type, ?NUM_LIMIT]),
                            db_sql:get_all(Sql);
                        false ->
                            %Sql = lists:concat([Str1, " and player.realm = ", Realm, " and player.career = ", Career, Str2, ?NUM_LIMIT]),
                            %db_sql:get_all(Sql)
                            F2(ets:match(?ETS_GUILD_MEMBER, #ets_guild_member{career = Career}))
                    end
            end
    end.

%% @doc  从数据库中读取数据，更新排行榜
update_rank() ->
    RoleRanks = loop_query_roles(?REALM_NUM_LIST, ?CAREER_NUM_LIST, ?ROLE_RANK_TYPE_LIST),   %% 获取人物相关排行
    EquipRanks = loop_query_equip(?EQUIP_RANK_TYPE_LIST),   %% 获取装备相关排行
    GuildRanks = loop_query_guild(?GUILD_RANK_TYPE_LIST),   %% 获取帮会相关排行
    %% 更新排行榜ETS表
    insert_rank_info(?ETS_RANK, RoleRanks),
    insert_rank_info(?ETS_RANK, EquipRanks),
    insert_rank_info(?ETS_RANK, GuildRanks),
    ok.

%% @doc  添加排行信息、物品名及玩家信息至物品信息，去掉goods_id（类型ID）
%% @spec update_goods_info(OldInfoList, PlayerInfoList, StartOrder, []) ->NewInfoList
update_goods_info([], _, _, AccList) ->
    lists:reverse(AccList);
update_goods_info(OldGoodsInfoList, PlayerInfoList, Order, AccList) ->
    [GoodsInfo | NewList] = OldGoodsInfoList,
    {Id, GoodsTypeId, PlayerId, Score} = GoodsInfo,
    GoodsName = get_equip_name(GoodsTypeId),
    case keysearch(PlayerId, 1, PlayerInfoList) of
        {ok, PlayerInfo} ->
            [NewPlayerId, PlayerName, Guild] = PlayerInfo;
        false ->
            NewPlayerId = 0,
            PlayerName = <<"">>,
            Guild = <<"">>
    end,
    NewAccList = [[Order, Id, GoodsName, NewPlayerId, PlayerName, Guild, Score] | AccList],
    update_goods_info(NewList, PlayerInfoList, Order + 1, NewAccList).

%% 插入物品（排行榜测试用）
%% TemplateGoodsId : 模板物品的Id，Num : 根据该模板插入Num条物品记录
insert_equip(TemplateGoodsId, Num) ->
    Sql = io_lib:format(<<"select * from goods where id = ~p limit 1">>, [TemplateGoodsId]),
    case db_sql:get_all(Sql) of
        [] ->
            {error, not_exist};
        [GoodsInfo] ->
            Goods = list_to_tuple([goods | GoodsInfo]),
            case Goods#goods.equip_type >= 1 andalso Goods#goods.equip_type =< 3 of
                true ->
                    random:seed(erlang:now()),
                    NewRandSeed = {random:uniform(9999), random:uniform(9999), random:uniform(9999)},
                    random:seed(NewRandSeed),
                    put("random_seed", NewRandSeed),
                    test_insert_goods(Goods, Num);
                false ->
                    {error, not_a_equip}
            end
    end.

%% 插入物品（测试用）
test_insert_goods(_, Num) when Num =< 0 ->
    {ok, complete};
test_insert_goods(Goods, Num) ->
    NewPlayerId = random:uniform(100000),
    Odds = random:uniform() * random:uniform() * random:uniform() + 0.0001, %% 概率
    NewColor   = trunc( (random:uniform( 5) - 1) * Odds ),                %% 0 ~  4
    NewQuality = trunc( (random:uniform(10) - 1) * Odds ) + 1,            %% 1 ~ 10
    NewStren   = trunc( (random:uniform(10) - 1) * Odds ) + 1,            %% 1 ~ 10
    NewGoods   = Goods#goods{player_id = NewPlayerId, color = NewColor, quality = NewQuality, stren = NewStren},
    NewGoodsInfo = lists:nthtail(2, tuple_to_list(NewGoods)),
    [id | FieldList] = record_info(fields, goods),
    Sql = lib_mail:make_insert_sql(goods, FieldList, NewGoodsInfo),
    lib_mail:execute(Sql),
    test_insert_goods(Goods, Num - 1).
