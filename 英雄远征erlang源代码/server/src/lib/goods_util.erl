%%%--------------------------------------
%%% @Module  : goods_util
%%% @Author  : xhg
%%% @Email   : xuhuguang@jieyou.com
%%% @Created : 2010.08.03
%%% @Description : 物品实用工具类
%%%--------------------------------------
-module(goods_util).
-include("common.hrl").
-include("record.hrl").
-export(
    [
        init_goods/0,
        init_goods_online/1,
        goods_offline/1,
        get_list/2,
        get_ets_info/2,
        get_ets_list/2,
        make_info/2,
        get_goods_name/1,
        get_task_mon/1,
        get_task_goods_num/2,
        get_new_goods/1,
        get_current_equip/2,
        get_current_equip_by_list/2,
        get_current_equip_by_info/2,
        get_goods/1,
        get_goods_type/1,
        get_add_goods/5,
        get_goods_by_id/1,
        get_goods_by_cell/3,
        get_goods_list/2,
        get_type_goods_list/4,
        get_type_goods_list/3,
        get_mend_list/2,
        get_equip_list/3,
        get_shop_list/2,
        get_shop_info/2,
        get_add_goods_attribute/4,
        get_goods_attribute_info/3,
        get_goods_attribute_list/2,
        get_goods_attribute_list/3,
        get_offline_goods_attribute_list/2,
        count_role_equip_attribute/3,
        get_equip_attribute/3,
        get_goods_attribute/1,
        get_equip_suit/2,
        get_suit_num/2,
        change_equip_suit/3,
        get_add_attribute_by_type/1,
        count_quality_addition/2,
        count_stren_addition/2,
        count_inlay_addition/1,
        count_add_addition/1,
        get_quality_factor/1,
        get_stren_factor/1,
        get_stren_color_factor/1,
        get_goods_attribute_id/1,
        get_inlay_attribute_id/1,
        get_goods_use_num/1,
        get_goods_attrition/2,
        get_mend_cost/2,
        get_equip_cell/1,
        get_null_cell_num/3,
        get_null_cells/2,
        get_goods_exp/1,
        sort/2,
        is_enough_money/3,
        get_cost/3,
        get_price_type/1,
        has_attribute/1,
        can_equip/3,
        get_inlay_num/1,
        get_goods_totalnum/1,
        get_consume_type/1,
        deeploop/3,
        list_handle/3
    ]
).

init_goods() ->
    %% 初始化物品类型列表
    ok = init_goods_type(),
    %% 初始化装备类型附加属性表
    ok = init_goos_add_attribute(),
    %% 初始化物品属性规则列表
    ok = init_goos_attribute_rule(),
    %% 初始化装备套装属性表
    ok = init_suit_attribute(),
    %% 初始化装备品质升级规则表
    ok = init_goos_quality_upgrade(),
    %% 初始化装备品质拆除规则表
    ok = init_goos_quality_backout(),
    %% 初始化装备强化规则表
    ok = init_goos_strengthen(),
    %% 初始化宝石合成规则表
    ok = init_goos_compose(),
    %% 初始化宝石镶嵌规则表
    ok = init_goos_inlay(),
    %% 初始化物品掉落数量规则表
    ok = init_goos_drop_num(),
    %% 初始化物品掉落规则表
    ok = init_goos_drop_rule(),
    %% 初始化商店表
    ok = init_shop(),
    ok.

init_goods_online(PlayerId) ->
    %% 初始化在线玩家背包物品表
    ok = init_goods(PlayerId),
    %% 初始化在线玩家物品属性表
    ok = init_goods_attribute(PlayerId),
    ok.

%%当玩家下线时，删除ets物品表
goods_offline(PlayerId) ->
    ets:match_delete(?ETS_GOODS_ONLINE, #goods{ player_id=PlayerId, _='_' }),
    ets:match_delete(?ETS_GOODS_ATTRIBUTE, #goods_attribute{ player_id=PlayerId, _='_' }),
    %io:format("offline goods clear~n"),
    ok.

%% 初始化物品类型列表
init_goods_type() ->
    F = fun([Mgoods_id,Mgoods_name,Mtype,Msubtype,Mequip_type,Mprice_type,Mprice,Msell_price,Mbind,Mtrade,Msell,Misdrop,Mlevel,Mcareer_id,Msex,Mjob,Mforza_limit,Mwit_limit,Magile_limit,Mvitality,Mspirit,Mhp,Mmp,Mforza,Mwit,Magile,Matt,Mdef,Mhit,Mdodge,Mcrit,Mten,Mspeed,Mattrition,Msuit_id,Mmax_hole,Mmax_stren,Mmax_quality,Mmax_overlap,Mcolor,Mexpire_time]) ->
                MountInfo = #ets_goods_type{
                                goods_id = Mgoods_id,
                                goods_name = Mgoods_name,
                                type = Mtype,
                                subtype = Msubtype,
                                equip_type = Mequip_type,
                                price_type = Mprice_type,
                                price = Mprice,
                                sell_price = Msell_price,
                                bind = Mbind,
                                trade = Mtrade,
                                sell = Msell,
                                isdrop = Misdrop,
                                level = Mlevel,
                                career = Mcareer_id,
                                sex = Msex,
                                job = Mjob,
                                forza_limit = Mforza_limit,
                                wit_limit = Mwit_limit,
                                agile_limit = Magile_limit,
                                vitality = Mvitality,
                                spirit = Mspirit,
                                hp = Mhp,
                                mp = Mmp,
                                forza = Mforza,
                                wit = Mwit,
                                agile = Magile,
                                att = Matt,
                                def = Mdef,
                                hit = Mhit,
                                dodge = Mdodge,
                                crit = Mcrit,
                                ten = Mten,
                                speed = Mspeed,
                                attrition = Mattrition,
                                suit_id = Msuit_id,
                                max_hole = Mmax_hole,
                                max_stren = Mmax_stren,
                                max_quality = Mmax_quality,
                                max_overlap = Mmax_overlap,
                                color = Mcolor,
                                expire_time = Mexpire_time
                            },
                  ets:insert(?ETS_GOODS_TYPE, MountInfo)
           end,
    case db_sql:get_all(<<"select goods_id,goods_name,type,subtype,equip_type,price_type,price,sell_price,bind,trade,sell,isdrop,level,career_id,sex,job,forza_limit,wit_limit,agile_limit,vitality,spirit,hp,mp,forza,wit,agile,att,def,hit,dodge,crit,ten,speed,attrition,suit_id,max_hole,max_stren,max_quality,max_overlap,color,expire_time from `base_goods` ">>) of
        [] -> skip;
        GoodsTypeList when is_list(GoodsTypeList) ->
            lists:foreach(F, GoodsTypeList);
        _ -> skip
    end,
    ok.

%% 初始化装备类型附加属性表
init_goos_add_attribute() ->
     F = fun([Mid,Mgoods_id,Mattribute_id,Mvalue_type,Mmin_value,Mmax_value]) ->
                AttributeInfo = #ets_goods_add_attribute{
                                    id = Mid,
                                    goods_id = Mgoods_id,
                                    attribute_id = Mattribute_id,
                                    value_type = Mvalue_type,
                                    min_value = Mmin_value,
                                    max_value = Mmax_value
                                },
                ets:insert(?ETS_GOODS_ADD_ATTRIBUTE, AttributeInfo)
         end,
    case db_sql:get_all(<<"select id,goods_id,attribute_id,value_type,min_value,max_value from `base_goods_add_attribute` ">>) of
        [] -> skip;
        AttributeList when is_list(AttributeList) ->
            lists:foreach(F, AttributeList);
        _ -> skip
    end,
    ok.

%% 初始化装备附加属性规则表
init_goos_attribute_rule() ->
     F = fun([Mid,Mgoods_id,Mattribute_id,Mvalue,Mfactor,Mratio]) ->
                AttributeRule = #ets_goods_attribute_rule{
                                    id = Mid,
                                    goods_id = Mgoods_id,
                                    attribute_id = Mattribute_id,
                                    value = Mvalue,
                                    factor = Mfactor,
                                    ratio = Mratio
                                },
                ets:insert(?ETS_GOODS_ATTRIBUTE_RULE, AttributeRule)
         end,
    case db_sql:get_all(<<"select id,goods_id,attribute_id,value,factor,ratio from `base_goods_attribute_rule` ">>) of
        [] -> skip;
        AttributeRuleList when is_list(AttributeRuleList) ->
            lists:foreach(F, AttributeRuleList);
        _ -> skip
    end,
    ok.

%% 初始化装备套装属性表
init_suit_attribute() ->
     F = fun([Mid,Msuit_id,Msuit_num,Mattribute_id,Mvalue_type,Mvalue]) ->
                [Hp,Mp,Att,Def,Hit,Dodge,Crit,Ten] = get_suit_attribute_value(Mattribute_id, Mvalue),
                SuitAttribute = #suit_attribute{
                                    id = Mid,
                                    suit_id = Msuit_id,
                                    suit_num = Msuit_num,
                                    attribute_id = Mattribute_id,
                                    value_type = Mvalue_type,
                                    hp = Hp,
                                    mp = Mp,
                                    att = Att,
                                    def = Def,
                                    hit = Hit,
                                    dodge = Dodge,
                                    crit = Crit,
                                    ten = Ten
                                },
                ets:insert(?ETS_SUIT_ATTRIBUTE, SuitAttribute)
         end,
    case db_sql:get_all(<<"select id,suit_id,suit_num,attribute_id,value_type,value from `base_goods_suit_attribute` ">>) of
        [] -> skip;
        SuitAttributeList when is_list(SuitAttributeList) ->
            lists:foreach(F, SuitAttributeList);
        _ -> skip
    end,
    ok.

%% 初始化装备品质升级规则表
init_goos_quality_upgrade() ->
     F = fun([Mid,Mgoods_id,Mquality,Mratio,Mmin_expected_num,Mmax_expected_num,Mcoin]) ->
                QualityUpgrade = #ets_goods_quality_upgrade{
                                    id = Mid,
                                    goods_id = Mgoods_id,
                                    quality = Mquality,
                                    ratio = Mratio,
                                    min_expected = Mmin_expected_num,
                                    max_expected = Mmax_expected_num,
                                    coin = Mcoin
                                 },
                ets:insert(?ETS_GOODS_QUALITY_UPGRADE, QualityUpgrade)
         end,
    case db_sql:get_all(<<"select id,goods_id,quality,ratio,min_expected_num,max_expected_num,coin from `base_goods_quality_upgrade` ">>) of
        [] -> skip;
        QualityUpgradeList when is_list(QualityUpgradeList) ->
            lists:foreach(F, QualityUpgradeList);
        _ -> skip
    end,
    ok.

%% 初始化装备品质拆除规则表
init_goos_quality_backout() ->
     F = fun([Mid,Mquality,Mratio,Mgoods_num,Mgoods_id,Mcoin]) ->
                QualityBackout = #ets_goods_quality_backout{
                                    id = Mid,
                                    quality = Mquality,
                                    ratio = Mratio,
                                    goods_num = Mgoods_num,
                                    goods_id = Mgoods_id,
                                    coin = Mcoin
                                 },
                ets:insert(?ETS_GOODS_QUALITY_BACKOUT, QualityBackout)
         end,
    case db_sql:get_all(<<"select id,quality,ratio,goods_num,goods_id,coin from `base_goods_quality_backout` ">>) of
        [] -> skip;
        QualityBackoutList when is_list(QualityBackoutList) ->
            lists:foreach(F, QualityBackoutList);
        _ -> skip
    end,
    ok.

%% 初始化装备强化规则表
init_goos_strengthen() ->
     F = fun([Mid,Mgoods_id,Mstrengthen,Mratio,Mmin_expected,Mmax_expected,Mcoin]) ->
                StrengthenInfo = #ets_goods_strengthen{
                                    id = Mid,
                                    goods_id = Mgoods_id,
                                    strengthen = Mstrengthen,
                                    ratio = Mratio,
                                    min_expected = Mmin_expected,
                                    max_expected = Mmax_expected,
                                    coin = Mcoin
                                 },
                ets:insert(?ETS_GOODS_STRENGTHEN, StrengthenInfo)
         end,
    case db_sql:get_all(<<"select id,goods_id,strengthen,ratio,min_expected_num,max_expected_num,coin from `base_goods_strengthen` ">>) of
        [] -> skip;
        StrengthenList when is_list(StrengthenList) ->
            lists:foreach(F, StrengthenList);
        _ -> skip
    end,
    ok.

%% 初始化宝石合成规则表
init_goos_compose() ->
     F = fun([Mid,Mgoods_id,Mgoods_num,Mratio,Mnew_id,Mcoin]) ->
                GoodsCompose = #ets_goods_compose{
                                    id = Mid,
                                    goods_id = Mgoods_id,
                                    goods_num = Mgoods_num,
                                    ratio = Mratio,
                                    new_id = Mnew_id,
                                    coin = Mcoin
                                 },
                ets:insert(?ETS_GOODS_COMPOSE, GoodsCompose)
         end,
    case db_sql:get_all(<<"select id,goods_id,goods_num,ratio,new_id,coin from `base_goods_compose` ">>) of
        [] -> skip;
        GoodsComposeList when is_list(GoodsComposeList) ->
            lists:foreach(F, GoodsComposeList);
        _ -> skip
    end,
    ok.

%% 初始化宝石镶嵌规则表
init_goos_inlay() ->
     F = fun([Mid,Mgoods_id,Mratio,Mcoin,Mequip_types]) ->
                Equip_type = util:explode(",", Mequip_types, int),
                GoodsInlay = #ets_goods_inlay{
                                    id = Mid,
                                    goods_id = Mgoods_id,
                                    ratio = Mratio,
                                    coin = Mcoin,
                                    equip_types = Equip_type
                              },
                ets:insert(?ETS_GOODS_INLAY, GoodsInlay)
         end,
    case db_sql:get_all(<<"select id,goods_id,ratio,coin,equip_types from `base_goods_inlay` ">>) of
        [] -> skip;
        GoodsInlayList when is_list(GoodsInlayList) ->
            lists:foreach(F, GoodsInlayList);
        _ -> skip
    end,
    ok.

%% 初始化物品掉落数量规则表
init_goos_drop_num() ->
     F = fun([Mid,Mmon_id,Mdrop_num,Mratio]) ->
                GoodsDropNum = #ets_goods_drop_num{
                                    id = Mid,
                                    mon_id = Mmon_id,
                                    drop_num = Mdrop_num,
                                    ratio = Mratio
                              },
                ets:insert(?ETS_GOODS_DROP_NUM, GoodsDropNum)
         end,
    case db_sql:get_all(<<"select id,mon_id,drop_num,ratio from `base_goods_drop_num` ">>) of
        [] -> skip;
        GoodsDropNumList when is_list(GoodsDropNumList) ->
            lists:foreach(F, GoodsDropNumList);
        _ -> skip
    end,
    ok.

%% 初始化物品掉落规则表
init_goos_drop_rule() ->
     F = fun([Mid,Mmon_id,Mgoods_id,Mtype,Mgoods_num,Mratio,Mtime_rule]) ->
                Time_rule = util:explode(",", Mtime_rule, int),
                GoodsDropRule = #ets_goods_drop_rule{
                                    id = Mid,
                                    mon_id = Mmon_id,
                                    goods_id = Mgoods_id,
                                    type = Mtype,
                                    goods_num = Mgoods_num,
                                    ratio = Mratio,
                                    time_rule = Time_rule
                              },
                ets:insert(?ETS_GOODS_DROP_RULE, GoodsDropRule)
         end,
    case db_sql:get_all(<<"select id,mon_id,goods_id,type,goods_num,ratio,time_rule  from `base_goods_drop_rule` ">>) of
        [] -> skip;
        GoodsDropRuleList when is_list(GoodsDropRuleList) ->
            lists:foreach(F, GoodsDropRuleList);
        _ -> skip
    end,
    ok.

%% 初始化商店表
init_shop() ->
     F = fun([Mid,Mshop_type,Mshop_subtype,Mgoods_id]) ->
                Shop = #ets_shop{
                                    id = Mid,
                                    shop_type = Mshop_type,
                                    shop_subtype = Mshop_subtype,
                                    goods_id = Mgoods_id
                              },
                ets:insert(?ETS_SHOP, Shop)
         end,
    case db_sql:get_all(<<"select id,shop_type,shop_subtype,goods_id from `shop` ">>) of
        [] -> skip;
        ShopList when is_list(ShopList) ->
            lists:foreach(F, ShopList);
        _ -> skip
    end,
    ok.

%% 初始化在线玩家背包物品表
init_goods(PlayerId) ->
     F = fun(Info) ->
                GoodsInfo = make_info(goods, Info),
                ets:insert(?ETS_GOODS_ONLINE, GoodsInfo)
         end,
    Sql = io_lib:format(<<"select id, player_id, goods_id, type, subtype, equip_type, price_type, price, sell_price, bind, trade, sell, isdrop, level, vitality, spirit, hp, mp, forza, agile, wit, att, def, hit, dodge, crit, ten, speed, attrition, use_num, suit_id, quality, quality_his, quality_fail, stren, stren_his, stren_fail, hole, hole1_goods, hole2_goods, hole3_goods, location, cell, num, color, expire_time from `goods` where player_id = ~p and location <> 5 ">>, [PlayerId]),
    case db_sql:get_all(Sql) of
        [] -> skip;
        GoodsList when is_list(GoodsList) ->
            lists:foreach(F, GoodsList);
        _ -> skip
    end,
    ok.

%% 初始化在线玩家物品属性表
init_goods_attribute(PlayerId) ->
     F = fun(Info) ->
                AttributeInfo = make_info(goods_attribute, Info),
                ets:insert(?ETS_GOODS_ATTRIBUTE, AttributeInfo)
         end,
    Sql = io_lib:format(<<"select id, player_id, gid, attribute_type, attribute_id, value_type, hp, mp, att, def, hit, dodge, crit, ten from `goods_attribute` where player_id = ~p ">>, [PlayerId]),
    case db_sql:get_all(Sql) of
        [] -> skip;
        AttributeList when is_list(AttributeList) ->
            lists:foreach(F, AttributeList);
        _ -> skip
    end,
    ok.

%% 取多条记录
%% @spec get_list(Field, Data) -> list()
get_list(Table, Sql) ->
    List = (catch db_sql:get_all(Sql)),
    case is_list(List) of
        true ->
            lists:map(fun(GoodsInfo) -> make_info(Table, GoodsInfo) end, List);
        false ->
            %?ERR("lib_goods get_list error:[~p]~n", [List]),
            []
    end.

%% 取物品类型信息
%% @spec get_ets_info(Tab, Id) -> record()
get_ets_info(Tab, Id) ->
    L = case is_integer(Id) of
            true -> ets:lookup(Tab, Id);
            false -> ets:match_object(Tab, Id)
        end,
    case L of
        [Info|_] -> Info;
        _ -> {}
    end.

get_ets_list(Tab, Pattern) ->
    L = ets:match_object(Tab, Pattern),
    case is_list(L) of
        true -> L;
        false -> []
    end.

make_info(Table, Info) ->
    case Info of
        [Id, Player_id, Goods_id, Type, Subtype, Equip_type, Price_type, Price,
            Sell_price, Bind, Trade, Sell, Isdrop, Level, Vitality, Spirit, Hp, Mp, Forza, Agile, Wit, Att,
            Def, Hit, Dodge, Crit, Ten, Speed, Attrition, Use_num, Suit_id, Quality, Quality_his,
            Quality_fail, Stren, Stren_his, Stren_fail, Hole, Hole1_goods, Hole2_goods,
            Hole3_goods, Location, Cell, Num, Color, Expire_time]
            when Table =:= goods ->
                #goods{ id=Id, player_id=Player_id, goods_id=Goods_id, type=Type, subtype=Subtype,
                        equip_type=Equip_type, price_type=Price_type, price=Price, sell_price=Sell_price,
                        bind=Bind, trade=Trade, sell=Sell, isdrop=Isdrop, level=Level, vitality=Vitality, spirit=Spirit,
                        hp=Hp, mp=Mp, forza=Forza, agile=Agile, wit=Wit, att=Att, def=Def, hit=Hit, dodge=Dodge,
                        crit=Crit, ten=Ten, speed=Speed, attrition=Attrition, use_num=Use_num, suit_id=Suit_id, quality=Quality,
                        quality_his=Quality_his, quality_fail=Quality_fail, stren=Stren, stren_his=Stren_his,
                        stren_fail=Stren_fail, hole=Hole, hole1_goods=Hole1_goods, hole2_goods=Hole2_goods,
                        hole3_goods=Hole3_goods, location=Location, cell=Cell, num=Num, color=Color, expire_time=Expire_time };
        [Id, Player_id, Gid, Attribute_type, Attribute_id, Value_type, Hp, Mp, Att, Def, Hit, Dodge, Crit, Ten] when Table =:= goods_attribute ->
                #goods_attribute{ id=Id, player_id=Player_id, gid=Gid, attribute_type=Attribute_type,
                    attribute_id=Attribute_id, value_type=Value_type, hp=Hp, mp=Mp, att=Att, def=Def,
                    hit=Hit, dodge=Dodge, crit=Crit, ten=Ten };
        _ ->
            %io:format("make_info : ~p ~p~n",[Table, Info]),
            Info
    end.

%% 取物品名称
%% @spec get_goods_name(GoodsTypeId) -> string
get_goods_name(GoodsTypeId) ->
    GoodsTypeInfo = get_ets_info(?ETS_GOODS_TYPE, GoodsTypeId),
    case is_record(GoodsTypeInfo, ets_goods_type) of
        true -> GoodsTypeInfo#ets_goods_type.goods_name;
        false -> <<>>
    end.

%% 取任务怪ID
%% @spec get_task_mon(GoodsTypeId) -> mon_id | 0
get_task_mon(GoodsTypeId) ->
    Pattern = #ets_goods_drop_rule{ goods_id=GoodsTypeId, _='_' },
    RuleInfo = get_ets_info(?ETS_GOODS_DROP_RULE, Pattern),
    case is_record(RuleInfo, ets_goods_drop_rule) of
        true -> RuleInfo#ets_goods_drop_rule.mon_id;
        false -> 0
    end.

%% 取任务物品数量
%% @spec get_task_goods_num(PlayerId, GoodsTypeId) -> num | 0
get_task_goods_num(PlayerId, GoodsTypeId) ->
    Pattern = #goods{ player_id=PlayerId, goods_id=GoodsTypeId, location=4, _='_' },
    GoodsList = get_ets_list(?ETS_GOODS_ONLINE, Pattern),
    get_goods_totalnum(GoodsList).

get_new_goods(GoodsTypeInfo) ->
    #goods{
        goods_id = GoodsTypeInfo#ets_goods_type.goods_id,
        type = GoodsTypeInfo#ets_goods_type.type,
        subtype = GoodsTypeInfo#ets_goods_type.subtype,
        equip_type = GoodsTypeInfo#ets_goods_type.equip_type,
        price_type = GoodsTypeInfo#ets_goods_type.price_type,
        price = GoodsTypeInfo#ets_goods_type.price,
        sell_price = GoodsTypeInfo#ets_goods_type.sell_price,
        bind = GoodsTypeInfo#ets_goods_type.bind,
        trade = GoodsTypeInfo#ets_goods_type.trade,
        sell = GoodsTypeInfo#ets_goods_type.sell,
        isdrop = GoodsTypeInfo#ets_goods_type.isdrop,
        level = GoodsTypeInfo#ets_goods_type.level,
        vitality = GoodsTypeInfo#ets_goods_type.vitality,
        spirit = GoodsTypeInfo#ets_goods_type.spirit,
        hp = GoodsTypeInfo#ets_goods_type.hp,
        mp = GoodsTypeInfo#ets_goods_type.mp,
        forza = GoodsTypeInfo#ets_goods_type.forza,
        agile = GoodsTypeInfo#ets_goods_type.agile,
        wit = GoodsTypeInfo#ets_goods_type.wit,
        att = GoodsTypeInfo#ets_goods_type.att,
        def = GoodsTypeInfo#ets_goods_type.def,
        hit = GoodsTypeInfo#ets_goods_type.hit,
        dodge = GoodsTypeInfo#ets_goods_type.dodge,
        crit = GoodsTypeInfo#ets_goods_type.crit,
        ten = GoodsTypeInfo#ets_goods_type.ten,
        speed = GoodsTypeInfo#ets_goods_type.speed,
        attrition = GoodsTypeInfo#ets_goods_type.attrition,
        use_num = get_goods_use_num(GoodsTypeInfo#ets_goods_type.attrition),
        suit_id = GoodsTypeInfo#ets_goods_type.suit_id,
        color = GoodsTypeInfo#ets_goods_type.color,
        expire_time = GoodsTypeInfo#ets_goods_type.expire_time
    }.

%% 取当前装备的武器、衣服、坐骑列表
get_current_equip(GoodsStatus, Equip) ->
    EquipList = goods_util:get_equip_list(GoodsStatus#goods_status.player_id, 10, Equip),
    MountList = goods_util:get_equip_list(GoodsStatus#goods_status.player_id, 31, 1),
    GoodsList = EquipList ++ MountList,
    [NewStatus, _] = get_current_equip_by_list(GoodsList, [GoodsStatus, on]),
    NewStatus.

get_current_equip_by_list(GoodsList, [GoodsStatus, Type]) ->
    lists:foldl(fun get_current_equip_by_info/2, [GoodsStatus, Type], GoodsList).

get_current_equip_by_info(GoodsInfo, [GoodsStatus, Type]) ->
    [Wq, Yf, Zq] = GoodsStatus#goods_status.equip_current,
    case is_record(GoodsInfo, goods) of
        true when GoodsInfo#goods.type =:= 10 andalso GoodsInfo#goods.subtype =:= 10 ->
            CurrentEquip = case Type of
                                on -> [GoodsInfo#goods.goods_id, Yf, Zq];
                                off -> [0, Yf, Zq]
                           end;
        true when GoodsInfo#goods.type =:= 10 andalso GoodsInfo#goods.subtype =:= 21 ->
            CurrentEquip = case Type of
                                on -> [Wq, GoodsInfo#goods.goods_id, Zq];
                                off -> [Wq, 0, Zq]
                           end;
        true when GoodsInfo#goods.type =:= 31 ->
            CurrentEquip = case Type of
                                on -> [Wq, Yf, GoodsInfo#goods.goods_id];
                                off -> [Wq, Yf, 0]
                           end;
        _ ->
            CurrentEquip = [Wq, Yf, Zq]
    end,
    NewGoodsStatus = GoodsStatus#goods_status{ equip_current=CurrentEquip },
    [NewGoodsStatus, Type].

get_goods(GoodsId) ->
    goods_util:get_ets_info(?ETS_GOODS_ONLINE, GoodsId).

get_goods_type(GoodsTypeId) ->
    get_ets_info(?ETS_GOODS_TYPE, GoodsTypeId).

get_add_goods(PlayerId, GoodsTypeId, Location, Cell, Num) ->
    Sql = io_lib:format(<<"select id, player_id, goods_id, type, subtype, equip_type, price_type, price, sell_price, bind, trade, sell, isdrop, level, vitality, spirit, hp, mp, forza, agile, wit, att, def, hit, dodge, crit, ten, speed, attrition, use_num, suit_id, quality, quality_his, quality_fail, stren, stren_his, stren_fail, hole, hole1_goods, hole2_goods, hole3_goods, location, cell, num, color, expire_time from `goods` where player_id = ~p and goods_id = ~p and location = ~p and cell = ~p and num = ~p order by id DESC limit 1 ">>,
                            [PlayerId, GoodsTypeId, Location, Cell, Num]),
    GoodsInfo = (catch db_sql:get_row(Sql)),
    make_info(goods, GoodsInfo).

%% @spec get_goods_by_id(GoodsId) -> record()
get_goods_by_id(GoodsId) ->
    Sql = io_lib:format(<<"select id, player_id, goods_id, type, subtype, equip_type, price_type, price, sell_price, bind, trade, sell, isdrop, level, vitality, spirit, hp, mp, forza, agile, wit, att, def, hit, dodge, crit, ten, speed, attrition, use_num, suit_id, quality, quality_his, quality_fail, stren, stren_his, stren_fail, hole, hole1_goods, hole2_goods, hole3_goods, location, cell, num, color, expire_time from `goods` where id = ~p limit 1">>, [GoodsId]),
    GoodsInfo = (catch db_sql:get_row(Sql)),
    make_info(goods, GoodsInfo).

get_goods_by_cell(PlayerId, Location, Cell) ->
    Pattern = #goods{ player_id=PlayerId, location=Location, cell=Cell, _='_' },
    get_ets_info(?ETS_GOODS_ONLINE, Pattern).

%% 取物品列表
get_goods_list(PlayerId, Location) ->
    case Location =/= 5 of
        true ->
            Pattern = #goods{ player_id=PlayerId, location=Location, _='_' },
            get_ets_list(?ETS_GOODS_ONLINE, Pattern);
        false -> %% 仓库
            Sql = io_lib:format(<<"select id, player_id, goods_id, type, subtype, equip_type, price_type, price, sell_price, bind, trade, sell, isdrop, level, vitality, spirit, hp, mp, forza, agile, wit, att, def, hit, dodge, crit, ten, speed, attrition, use_num, suit_id, quality, quality_his, quality_fail, stren, stren_his, stren_fail, hole, hole1_goods, hole2_goods, hole3_goods, location, cell, num, color, expire_time from `goods` where player_id = ~p and location = 5 ">>, [PlayerId]),
            get_list(goods, Sql)
    end.

%% 获取同类物品列表
get_type_goods_list(PlayerId, GoodsTypeId, Bind, Location) ->
    case Location =/= 5 of
        true ->
            Pattern = #goods{ player_id=PlayerId, goods_id=GoodsTypeId, bind=Bind, location=Location, _='_' },
            get_ets_list(?ETS_GOODS_ONLINE, Pattern);
        false -> %% 仓库
            Sql = io_lib:format(<<"select id, player_id, goods_id, type, subtype, equip_type, price_type, price, sell_price, bind, trade, sell, isdrop, level, vitality, spirit, hp, mp, forza, agile, wit, att, def, hit, dodge, crit, ten, speed, attrition, use_num, suit_id, quality, quality_his, quality_fail, stren, stren_his, stren_fail, hole, hole1_goods, hole2_goods, hole3_goods, location, cell, num, color, expire_time from `goods` where player_id = ~p and goods_id = ~p and bind = ~p and location = 5 ">>,
                                    [PlayerId, GoodsTypeId, Bind]),
            get_list(goods, Sql)
    end.
get_type_goods_list(PlayerId, GoodsTypeId, Location) ->
    case Location =/= 5 of
        true ->
            Pattern = #goods{ player_id=PlayerId, goods_id=GoodsTypeId, location=Location, _='_' },
            get_ets_list(?ETS_GOODS_ONLINE, Pattern);
        false -> %% 仓库
            Sql = io_lib:format(<<"select id, player_id, goods_id, type, subtype, equip_type, price_type, price, sell_price, bind, trade, sell, isdrop, level, vitality, spirit, hp, mp, forza, agile, wit, att, def, hit, dodge, crit, ten, speed, attrition, use_num, suit_id, quality, quality_his, quality_fail, stren, stren_his, stren_fail, hole, hole1_goods, hole2_goods, hole3_goods, location, cell, num, color, expire_time from `goods` where player_id = ~p and goods_id = ~p and location = 5 ">>,
                                    [PlayerId, GoodsTypeId]),
            get_list(goods, Sql)
    end.

%% 查找有耐久度的装备
get_mend_list(PlayerId, Equip) ->
    L1 = get_equip_list(PlayerId, 10, Equip),
    L2 = get_equip_list(PlayerId, 10, 4),
    L1 ++ L2.

%% 取装备列表
get_equip_list(PlayerId, Type, Location) ->
    Pattern = #goods{ player_id=PlayerId, type=Type, location=Location, _='_' },
    get_ets_list(?ETS_GOODS_ONLINE, Pattern).

%% 取商店物品列表
get_shop_list(ShopType, ShopSubtype) ->
    case ShopSubtype > 0 of
        true ->  Pattern = #ets_shop{ shop_type=ShopType, shop_subtype=ShopSubtype, _='_' };
        false -> Pattern = #ets_shop{ shop_type=ShopType, _='_' }
    end,
    get_ets_list(?ETS_SHOP, Pattern).

%% 取商店物品信息
get_shop_info(ShopType, GoodsTypeId) ->
    Pattern = #ets_shop{ shop_type=ShopType, goods_id=GoodsTypeId, _='_' },
    get_ets_info(?ETS_SHOP, Pattern).

%% 取新加入的装备属性
get_add_goods_attribute(PlayerId, GoodsId, AttributeType, AttributeId) ->
    Sql = io_lib:format(<<"select id, player_id, gid, attribute_type, attribute_id, value_type, hp, mp, att, def, hit, dodge, crit, ten from `goods_attribute` where player_id = ~p and gid = ~p and attribute_type = ~p and attribute_id = ~p limit 1 ">>,
                            [PlayerId, GoodsId, AttributeType, AttributeId]),
    AttributeInfo = (catch db_sql:get_row(Sql)),
    make_info(goods_attribute, AttributeInfo).

%% 取装备属性信息
get_goods_attribute_info(PlayerId, GoodsId, AttributeType) ->
    Pattern = #goods_attribute{ player_id=PlayerId, gid=GoodsId, attribute_type=AttributeType, _='_'},
    get_ets_info(?ETS_GOODS_ATTRIBUTE, Pattern).

%%取装备属性列表
get_goods_attribute_list(PlayerId, GoodsId, AttributeType) ->
    Pattern = #goods_attribute{ player_id=PlayerId, gid=GoodsId, attribute_type=AttributeType, _='_'},
    get_ets_list(?ETS_GOODS_ATTRIBUTE, Pattern).

get_goods_attribute_list(PlayerId, GoodsId) ->
    Pattern = #goods_attribute{ player_id=PlayerId, gid=GoodsId, _='_'},
    get_ets_list(?ETS_GOODS_ATTRIBUTE, Pattern).

get_offline_goods_attribute_list(PlayerId, GoodsId) ->
    Sql = io_lib:format(<<"select id, player_id, gid, attribute_type, attribute_id, value_type, hp, mp, att, def, hit, dodge, crit, ten from `goods_attribute` where player_id = ~p and gid = ~p  ">>,
                            [PlayerId, GoodsId]),
    get_list(goods_attribute, Sql).

get_suit_attribute_list(SuitId, SuitNum) ->
    Pattern = #suit_attribute{ suit_id=SuitId, _='_'},
    SuitAttributeList = get_ets_list(?ETS_SUIT_ATTRIBUTE, Pattern),
    F = fun(SuitAttribute, [SuitNum1, List]) ->
            case SuitAttribute#suit_attribute.suit_num =< SuitNum1 of
                true -> [SuitNum1, [SuitAttribute|List]];
                false -> [SuitNum1, List]
            end
        end,
    [_, NewSuitAttributeList] = lists:foldl(F, [SuitNum, []], SuitAttributeList),
    NewSuitAttributeList.

%% 人物装备属性重新计算
count_role_equip_attribute(PlayerStatus, GoodsStatus, GoodsInfo) ->
    %% 装备属性
    Effect = get_equip_attribute(PlayerStatus#player_status.id, PlayerStatus#player_status.equip, GoodsStatus#goods_status.equip_suit),
    %% 检查武器、衣服
    [NewGoodsStatus, _] = get_current_equip_by_info(GoodsInfo, [GoodsStatus, on]),
    %% 更新人物属性
    PlayerStatus1 = PlayerStatus#player_status{
                           equip_current = NewGoodsStatus#goods_status.equip_current,
                           equip_attribute = Effect
                    },
    %% 人物属性重新计算
    NewPlayerStatus = lib_player:count_player_attribute(PlayerStatus1),
    {ok, NewPlayerStatus, NewGoodsStatus}.

%% 取装备的属性加成
get_equip_attribute(PlayerId, Equip, EquipSuit) ->
    EquipList = get_equip_list(PlayerId, 10, Equip),
    %% 装备属性加成
    [Hp, Mp, Att, Def, Hit, Dodge, Crit, Ten] = lists:foldl(fun count_goods_effect/2, [0,0,0,0,0,0,0,0], EquipList),
    %% 装备套装属性加成
    %io:format("EquipSuit: ~p~n",[EquipSuit]),
    [Hp1, Mp1, Att1, Def1, Hit1, Dodge1, Crit1, Ten1] = get_suit_attribute(EquipSuit),
    %io:format("get_suit_attribute: ~p~n",[[Hp1, Mp1, Att1, Def1, Hit1, Dodge1, Crit1, Ten1]]),
    [Hp+Hp1, Mp+Mp1, Att+Att1, Def+Def1, Hit+Hit1, Dodge+Dodge1, Crit+Crit1, Ten+Ten1].

%% 取单件装备的属性加成
get_goods_attribute(GoodsInfo) ->
    [Hp1, Mp1, Att1, Def1, Hit1, Dodge1, Crit1, Ten1] = [GoodsInfo#goods.hp, GoodsInfo#goods.mp, GoodsInfo#goods.att, GoodsInfo#goods.def, GoodsInfo#goods.hit, GoodsInfo#goods.dodge, GoodsInfo#goods.crit, GoodsInfo#goods.ten],
    %% 装备额外属性加成
    AttributeList = get_goods_attribute_list(GoodsInfo#goods.player_id, GoodsInfo#goods.id),
    [Hp2, Mp2, Att2, Def2, Hit2, Dodge2, Crit2, Ten2] = lists:foldl(fun count_goods_attribute_effect/2, [0,0,0,0,0,0,0,0], AttributeList),
    [Hp1+Hp2, Mp1+Mp2, Att1+Att2, Def1+Def2, Hit1+Hit2, Dodge1+Dodge2, Crit1+Crit2, Ten1+Ten2].

get_equip_suit(PlayerId, Equip) ->
    EquipList = goods_util:get_equip_list(PlayerId, 10, Equip),
    F = fun(GoodsInfo, EquipSuit) ->
            change_equip_suit(EquipSuit, 0, GoodsInfo#goods.suit_id)
        end,
    EquipSuit = lists:foldl(F, [], EquipList),
    %io:format("EquipSuit:~p~n",[EquipSuit]),
    EquipSuit.

get_suit_attribute(EquipSuit) ->
    F = fun({SuitId, SuitNum}, Effect) ->
            case SuitNum > 1 of
                true ->
                    SuitAttributeList = get_suit_attribute_list(SuitId, SuitNum),
                    lists:foldl(fun count_suit_attribute_effect/2, Effect, SuitAttributeList);
                false ->
                    Effect
            end
        end,
    lists:foldl(F, [0,0,0,0,0,0,0,0], EquipSuit).

count_goods_effect(GoodsInfo, [Hp1, Mp1, Att1, Def1, Hit1, Dodge1, Crit1, Ten1]) ->
    [Hp2, Mp2, Att2, Def2, Hit2, Dodge2, Crit2, Ten2] = get_goods_attribute(GoodsInfo),
    [Hp1+Hp2, Mp1+Mp2, Att1+Att2, Def1+Def2, Hit1+Hit2, Dodge1+Dodge2, Crit1+Crit2, Ten1+Ten2].

count_goods_attribute_effect(AttributeInfo, [Hp, Mp, Att, Def, Hit, Dodge, Crit, Ten]) ->
    [ Hp + AttributeInfo#goods_attribute.hp,
      Mp + AttributeInfo#goods_attribute.mp,
      Att + AttributeInfo#goods_attribute.att,
      Def + AttributeInfo#goods_attribute.def,
      Hit + AttributeInfo#goods_attribute.hit,
      Dodge + AttributeInfo#goods_attribute.dodge,
      Crit + AttributeInfo#goods_attribute.crit,
      Ten + AttributeInfo#goods_attribute.ten ].

count_suit_attribute_effect(SuitAttribute, [Hp, Mp, Att, Def, Hit, Dodge, Crit, Ten]) ->
    [ Hp + SuitAttribute#suit_attribute.hp,
      Mp + SuitAttribute#suit_attribute.mp,
      Att + SuitAttribute#suit_attribute.att,
      Def + SuitAttribute#suit_attribute.def,
      Hit + SuitAttribute#suit_attribute.hit,
      Dodge + SuitAttribute#suit_attribute.dodge,
      Crit + SuitAttribute#suit_attribute.crit,
      Ten + SuitAttribute#suit_attribute.ten ].

get_suit_num(EquipSuit, SuitId) ->
    case SuitId > 0 of
        true ->
            case lists:keyfind(SuitId, 1, EquipSuit) of
                false -> 0;
                {SuitId, SuitNum} -> SuitNum
            end;
        false -> 0
    end.

change_equip_suit(EquipSuit, OldSuitId, NewSuitId) ->
    %% 删除
    EquipSuit1 = if OldSuitId > 0 ->
                        case lists:keyfind(OldSuitId, 1, EquipSuit) of
                            false ->
                                EquipSuit;
                            {OldSuitId, SuitNum} when SuitNum > 1 ->
                                lists:keyreplace(OldSuitId, 1, EquipSuit, {OldSuitId, SuitNum-1});
                            {OldSuitId, _} ->
                                lists:keydelete(OldSuitId, 1, EquipSuit)
                        end;
                    true -> EquipSuit
                end,
    %% 添加
    EquipSuit2 = if NewSuitId > 0 ->
                        case lists:keyfind(NewSuitId, 1, EquipSuit1) of
                            false ->
                                [{NewSuitId, 1} | EquipSuit1];
                            {NewSuitId, SuitNum2} ->
                                lists:keyreplace(NewSuitId, 1, EquipSuit1, {NewSuitId, SuitNum2+1})
                        end;
                    true -> EquipSuit1
                end,
    %io:format("EquipSuit:~p~n",[EquipSuit2]),
    EquipSuit2.

%% 取装备类型附加属性值
%% @spec get_add_attribute_by_type(BaseAttributeInfo) -> [Hp, Mp, Att, Def, Hit, Dodge, Crit, Ten]
get_add_attribute_by_type(BaseAttributeInfo) ->
    Value = util:rand(BaseAttributeInfo#ets_goods_add_attribute.min_value, BaseAttributeInfo#ets_goods_add_attribute.max_value),
    case BaseAttributeInfo#ets_goods_add_attribute.attribute_id of
        1 -> [Value, 0, 0, 0, 0, 0, 0, 0];
        2 -> [0, Value, 0, 0, 0, 0, 0, 0];
        3 -> [0, 0, Value, 0, 0, 0, 0, 0];
        4 -> [0, 0, 0, Value, 0, 0, 0, 0];
        5 -> [0, 0, 0, 0, Value, 0, 0, 0];
        6 -> [0, 0, 0, 0, 0, Value, 0, 0];
        7 -> [0, 0, 0, 0, 0, 0, Value, 0];
        8 -> [0, 0, 0, 0, 0, 0, 0, Value];
        _ -> [0, 0, 0, 0, 0, 0, 0, 0]
    end.

%% 计算装备品质加成
%% @spec count_quality_addition(GoodsInfo, Quality) -> [Hp, Mp, Att, Def, Hit, Dodge, Crit, Ten]
count_quality_addition(GoodsInfo, Quality) ->
    Factor = get_quality_factor(Quality),
    Hp = round(GoodsInfo#goods.hp * Factor),
    Mp = round(GoodsInfo#goods.mp * Factor),
    Att = round(GoodsInfo#goods.att * Factor),
    Def = round(GoodsInfo#goods.def * Factor),
    Hit = round(GoodsInfo#goods.hit * Factor),
    Dodge = round(GoodsInfo#goods.dodge * Factor),
    Crit = round(GoodsInfo#goods.crit * Factor),
    Ten = round(GoodsInfo#goods.ten * Factor),
    [Hp, Mp, Att, Def, Hit, Dodge, Crit, Ten].

%% 计算装备强化加成
%% @spec count_stren_addition(GoodsInfo, Stren) -> [Hp, Mp, Att, Def, Hit, Dodge, Crit, Ten]
count_stren_addition(GoodsInfo, Stren) ->
    QFactor = get_quality_factor(GoodsInfo#goods.quality),
    CFactor = get_stren_color_factor(GoodsInfo#goods.color),
    SFactor = get_stren_factor(Stren),
    Hp = round(GoodsInfo#goods.hp * (1 + QFactor) * CFactor * SFactor),
    Mp = round(GoodsInfo#goods.mp * (1 + QFactor) * CFactor * SFactor),
    Att = round(GoodsInfo#goods.att * (1 + QFactor) * CFactor * SFactor),
    Def = round(GoodsInfo#goods.def * (1 + QFactor) * CFactor * SFactor),
    Hit = round(GoodsInfo#goods.hit * (1 + QFactor) * CFactor * SFactor),
    Dodge = round(GoodsInfo#goods.dodge * (1 + QFactor) * CFactor * SFactor),
    Crit = round(GoodsInfo#goods.crit * (1 + QFactor) * CFactor * SFactor),
    Ten = round(GoodsInfo#goods.ten * (1 + QFactor) * CFactor * SFactor),
    [Hp, Mp, Att, Def, Hit, Dodge, Crit, Ten].

%% 计算宝石镶嵌加成
%% @spec count_inlay_addition(StoneInfo) -> [Hp, Mp, Att, Def, Hit, Dodge, Crit, Ten]
count_inlay_addition(StoneInfo) ->
    Hp = StoneInfo#goods.hp,
    Mp = StoneInfo#goods.mp,
    Att = StoneInfo#goods.att,
    Def = StoneInfo#goods.def,
    Hit = StoneInfo#goods.hit,
    Dodge = StoneInfo#goods.dodge,
    Crit = StoneInfo#goods.crit,
    Ten = StoneInfo#goods.ten,
    [Hp, Mp, Att, Def, Hit, Dodge, Crit, Ten].

%% 计算附加属性加成
%% @spec count_add_addition(RuleInfo) -> [Hp, Mp, Att, Def, Hit, Dodge, Crit, Ten]
count_add_addition(RuleInfo) ->
    BaseValue = RuleInfo#ets_goods_attribute_rule.value,
    Factor = RuleInfo#ets_goods_attribute_rule.factor,
    Rand = util:rand(1, 100),
    %% 分布概率 不变20% 降40% 升40%
    Value = case Rand =< 60 of
                %% 不变
                true when Rand =< 20 -> BaseValue;
                %% 降
                true -> round( util:rand(BaseValue-Factor, BaseValue) );
                %% 升
                false -> round( util:rand(BaseValue, BaseValue+Factor) )
            end,
    case RuleInfo#ets_goods_attribute_rule.attribute_id of
        1 -> [Value, 0, 0, 0, 0, 0, 0, 0];
        2 -> [0, Value, 0, 0, 0, 0, 0, 0];
        3 -> [0, 0, Value, 0, 0, 0, 0, 0];
        4 -> [0, 0, 0, Value, 0, 0, 0, 0];
        5 -> [0, 0, 0, 0, Value, 0, 0, 0];
        6 -> [0, 0, 0, 0, 0, Value, 0, 0];
        7 -> [0, 0, 0, 0, 0, 0, Value, 0];
        8 -> [0, 0, 0, 0, 0, 0, 0, Value];
        _ -> [0, 0, 0, 0, 0, 0, 0, 0]
    end.

get_suit_attribute_value(Attribute_id, Value) ->
    case Attribute_id of
        1 -> [Value, 0, 0, 0, 0, 0, 0, 0];
        2 -> [0, Value, 0, 0, 0, 0, 0, 0];
        3 -> [0, 0, Value, 0, 0, 0, 0, 0];
        4 -> [0, 0, 0, Value, 0, 0, 0, 0];
        5 -> [0, 0, 0, 0, Value, 0, 0, 0];
        6 -> [0, 0, 0, 0, 0, Value, 0, 0];
        7 -> [0, 0, 0, 0, 0, 0, Value, 0];
        8 -> [0, 0, 0, 0, 0, 0, 0, Value];
        _ -> [0, 0, 0, 0, 0, 0, 0, 0]
    end.

%% 装备品质加成系数
get_quality_factor(Quality) ->
    case Quality of
        0  -> 0;
        1  -> 0.05;
        2  -> 0.1;
        3  -> 0.16;
        4  -> 0.22;
        5  -> 0.29;
        6  -> 0.36;
        7  -> 0.44;
        8  -> 0.52;
        9  -> 0.6;
        10 -> 0.7;
        11 -> 0.83;
        12 -> 1;
        _  -> 0
    end.

%% 装备强化加成系数
get_stren_factor(Stren) ->
    case Stren of
        0  -> 0;
        1  -> 0.06;
        2  -> 0.15;
        3  -> 0.26;
        4  -> 0.38;
        5  -> 0.48;
        6  -> 0.6;
        7  -> 0.74;
        8  -> 0.82;
        9  -> 0.9;
        10 -> 1;
        _  -> 0
    end.

%% 装备强化颜色系数
get_stren_color_factor(Color) ->
    case Color of
        0  -> 0.9;
        1  -> 0.95;
        2  -> 1;
        3  -> 1.1;
        4  -> 1.25;
        _  -> 0.9
    end.

% 装备加成属性类型ID
% 属性类型Id， 1气血，2内力，3攻击，4防御，5命中，6躲避，7暴击，8坚韧
get_goods_attribute_id(Subtype) ->
    case Subtype of
        10  -> 3;    % 武器
        20  -> 4;    % 头盔
        21  -> 4;    % 衣服
        22  -> 4;    % 裤子
        23  -> 4;    % 鞋子
        24  -> 6;    % 腰带
        25  -> 5;    % 手套
        30  -> 4;    % 披风
        31  -> 4;    % 腰饰
        32  -> 3;    % 戒指
        33  -> 3;    % 项链
        _  -> 0
    end.

% 镶嵌宝石的属性类型ID
get_inlay_attribute_id(StoneInfo) ->
    case is_record(StoneInfo, goods) of
        true when StoneInfo#goods.hp > 0    -> 1;
        true when StoneInfo#goods.mp > 0    -> 2;
        true when StoneInfo#goods.att > 0   -> 3;
        true when StoneInfo#goods.def > 0   -> 4;
        true when StoneInfo#goods.hit > 0   -> 5;
        true when StoneInfo#goods.dodge > 0 -> 6;
        true when StoneInfo#goods.crit > 0  -> 7;
        true when StoneInfo#goods.ten > 0   -> 8;
        _ -> 0
    end.
%% 取得装备的使用次数
%% @spec get_goods_use_num(Attrition) -> UseNum
get_goods_use_num(Attrition) ->
    Attrition * 10.

%% 取得装备的耐久度
%% @spec get_goods_attrition(UseNum) -> Attrition
get_goods_attrition(OldAttrition, UseNum) ->
    Attrition = case OldAttrition > 0 of
                    false -> 0;
                    true -> round( UseNum / 10 + 0.5 )
                end,
    case Attrition > OldAttrition of
        true -> OldAttrition;
        false -> Attrition
    end.

%% 取修理装备价格
get_mend_cost(Attrition, UseNum) ->
    TotalUseNum = get_goods_use_num(Attrition),
    Cost = trunc( (TotalUseNum - UseNum) * 1 ),
    Cost.

%%默认装备格子位置, 0 默认位置，1 武器，2 头盔，3 衣服，4 裤子， 5 鞋子， 6 腰带，7 手套，8 披风，9 腰饰，10 项链，11 戒指一，12 戒指二
get_equip_cell(Subtype) ->
    case Subtype of
        10 -> 1;    % 武器
        20 -> 2;    % 头盔
        21 -> 3;    % 衣服
        22 -> 4;    % 裤子
        23 -> 5;    % 鞋子
        24 -> 6;    % 腰带
        25 -> 7;    % 手套
        30 -> 8;    % 披风
        31 -> 9;    % 腰饰
        33 -> 10;   % 项链
        32 -> 11;   % 戒指一
        _  -> 0
    end.

%% 经验卡对应的经验
get_goods_exp(Color) ->
    case Color of
        0 -> 1000;    % 初级经验卡
        1 -> 5000;    % 中级经验卡
        2 -> 10000;   % 高级经验卡
        _  -> 0
    end.

%% 检查物品还需要多少格子数
get_null_cell_num(GoodsList, MaxNum, GoodsNum) ->
    case MaxNum > 1 of
        true ->
            TotalNum = lists:foldl(fun(X, Sum) -> X#goods.num + Sum end, 0, GoodsList),
            CellNum = util:ceil( (TotalNum+GoodsNum)/ MaxNum ),
            ( CellNum - length(GoodsList) );
        false ->
            GoodsNum
    end.

%% 获取背包空位
get_null_cells(PlayerId, CellNum) ->
    %Sql = io_lib:format(<<"select cell from `goods` where player_id = ~p and location = 4 ">>, [PlayerId]),
    %List = db_sql:get_all(Sql),
    Pattern = #goods{ player_id=PlayerId, location=4, _='_' },
    List = get_ets_list(?ETS_GOODS_ONLINE, Pattern),
    Cells = lists:map(fun(GoodsInfo) -> [GoodsInfo#goods.cell] end, List),
    AllCells = lists:seq(1, CellNum),
    NullCells = lists:filter(fun(X) -> not(lists:member([X], Cells)) end, AllCells),
    NullCells.

%% 按格子位置排序
sort(GoodsList, Type) ->
    case Type of
        cell -> F = fun(G1, G2) -> G1#goods.cell < G2#goods.cell end;
        goods_id -> F = fun(G1, G2) -> G1#goods.goods_id < G2#goods.goods_id end;
        _ -> F = fun(G1, G2) -> G1#goods.cell < G2#goods.cell end
    end,
    lists:sort(F, GoodsList).

%% 判断金钱是否充足，true为充足，false为不足
is_enough_money(PlayerStatus, Cost, Type) ->
    case Type of
        coin ->     (PlayerStatus#player_status.bcoin + PlayerStatus#player_status.coin) > Cost;
        silver ->   PlayerStatus#player_status.silver > Cost;
        gold ->     PlayerStatus#player_status.gold > Cost;
        bcoin ->    PlayerStatus#player_status.bcoin > Cost
    end.

%% 计算消费
get_cost(PlayerStatus, Cost, Type) ->
    case Type of
        coin -> case PlayerStatus#player_status.bcoin < Cost of
                    false -> NewPlayerStatus = PlayerStatus#player_status{ bcoin = (PlayerStatus#player_status.bcoin - Cost) };
                    true -> NewPlayerStatus = PlayerStatus#player_status{ bcoin = 0, coin= (PlayerStatus#player_status.bcoin + PlayerStatus#player_status.coin - Cost) }
                end;
        silver -> NewPlayerStatus = PlayerStatus#player_status{ silver = (PlayerStatus#player_status.silver - Cost) };
        gold ->   NewPlayerStatus = PlayerStatus#player_status{ gold = (PlayerStatus#player_status.gold - Cost) };
        bcoin ->  NewPlayerStatus = PlayerStatus#player_status{ bcoin = (PlayerStatus#player_status.bcoin - Cost) }
    end,
    NewPlayerStatus.

%% 取价格类型
get_price_type(Type) ->
    case Type of
        1 -> coin;      % 铜钱
        2 -> silver;    % 银两
        3 -> gold;      % 金币
        4 -> bcoin;     % 绑定的铜钱
        _ -> coin       % 铜钱
    end.

%% 检查装备是否有属性加成
has_attribute(GoodsInfo) ->
    case GoodsInfo#goods.type =:= 10 of
        true when GoodsInfo#goods.quality > 0 -> true;
        true when GoodsInfo#goods.stren > 0 -> true;
        true when GoodsInfo#goods.hole1_goods > 0 -> true;
        true when GoodsInfo#goods.color > 0 -> true;
        true when GoodsInfo#goods.suit_id > 0 -> true;
        _ -> false
    end.

%% 检查装备是否可穿
can_equip(PlayerStatus, GoodsTypeId, Cell) ->
    GoodsTypeInfo = get_goods_type(GoodsTypeId),
    DefCell = get_equip_cell(GoodsTypeInfo#ets_goods_type.subtype),
    NewCell = case (Cell =< 0 orelse Cell > 12) of
                    true -> DefCell;
                    false -> Cell
              end,
    case is_record(GoodsTypeInfo, ets_goods_type) of
        false -> false;
        true when GoodsTypeInfo#ets_goods_type.subtype =:= 32 andalso NewCell =/= 11 andalso NewCell =/= 12 ->
            false;
        true when GoodsTypeInfo#ets_goods_type.subtype =/= 32 andalso NewCell =/= DefCell ->
            false;
        true when GoodsTypeInfo#ets_goods_type.level > PlayerStatus#player_status.lv ->
            false;
        true when GoodsTypeInfo#ets_goods_type.career > 0 andalso GoodsTypeInfo#ets_goods_type.career =/= PlayerStatus#player_status.career ->
            false;
        true when GoodsTypeInfo#ets_goods_type.sex > 0 andalso GoodsTypeInfo#ets_goods_type.sex =/= PlayerStatus#player_status.sex ->
            false;
        true when GoodsTypeInfo#ets_goods_type.job > PlayerStatus#player_status.jobs ->
            false;
        true when GoodsTypeInfo#ets_goods_type.forza_limit > PlayerStatus#player_status.forza ->
            false;
        true when GoodsTypeInfo#ets_goods_type.agile_limit > PlayerStatus#player_status.agile ->
            false;
        true when GoodsTypeInfo#ets_goods_type.wit_limit > PlayerStatus#player_status.wit ->
            false;
        true ->
            NewCell
    end.

%% 取物品镶嵌数
get_inlay_num(GoodsInfo) ->
    if
        GoodsInfo#goods.hole3_goods > 0 -> 3;
        GoodsInfo#goods.hole2_goods > 0 -> 2;
        GoodsInfo#goods.hole1_goods > 0 -> 1;
        true -> 0
    end.

%% 取物品总数
get_goods_totalnum(GoodsList) ->
    lists:foldl(fun(X, Sum) -> X#goods.num + Sum end, 0, GoodsList).

%% 取消费类型
get_consume_type(Type) ->
    case Type of
        pay -> 1;
        mend -> 2;
        quality_upgrade -> 3;
        quality_backout -> 4;
        strengthen -> 5;
        hole -> 6;
        compose -> 7;
        inlay -> 8;
        backout -> 9;
        wash -> 10;
        _ -> 0
    end.

deeploop(F, N, Data) ->
    case N > 0 of
        true ->
            [N1, Data1] = F(N, Data),
            deeploop(F, N1, Data1);
        false ->
            Data
    end.

%% @spec list_handle(F, Data, List) -> {ok, NewData} | Error
list_handle(F, Data, List) ->
    if length(List) > 0 ->
            [Item|L] = List,
            case F(Item, Data) of
                {ok, Data1} -> list_handle(F, Data1, L);
                Error -> Error
            end;
        true ->
            {ok, Data}
    end.