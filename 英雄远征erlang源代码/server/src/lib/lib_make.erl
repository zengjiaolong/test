%%%--------------------------------------
%%% @Module  : lib_goods
%%% @Author  : xhg
%%% @Email   : xuhuguang@jieyou.com
%%% @Created : 2010.05.24
%%% @Description : 物品信息
%%%--------------------------------------
-module(lib_make).
-include("common.hrl").
-include("record.hrl").
-export(
    [
        quality_upgrade/5,
        quality_backout/4,
        strengthen/6,
        hole/4,
        compose/5,
        inlay/7,
        backout/4,
        wash/5
    ]
).

%% 装备品质升级
quality_upgrade(PlayerStatus, GoodsStatus, GoodsInfo, StoneInfo, GoodsQualityRule) ->
    %% 根据之前升级失败次数检查当前升级成功率
    Ratio = get_quality_upgrade_ratio(GoodsInfo, GoodsQualityRule),
    %% 花费铜钱
    Cost = GoodsQualityRule#ets_goods_quality_upgrade.coin,
    NewPlayerStatus = lib_goods:cost_money(PlayerStatus, Cost, coin),
    %% 扣掉品质石
    {ok, NewStatus, NewStoneNum} = lib_goods:delete_one(GoodsStatus, StoneInfo, 1),
    %% 更新物品状态
    Ram = util:rand(1, 100),
    %io:format("quality_upgrade: ~p ~p~n",[Ratio, Ram]),
    case Ratio >= Ram of
        %% 升级成功
        true ->
            NewQuality = quality_upgrade_ok(GoodsInfo),
            (catch log:log_quality_up(PlayerStatus, GoodsInfo, GoodsInfo#goods.quality_fail, StoneInfo#goods.goods_id, Cost, 1));
        %% 升级失败
        false ->
            [NewQuality, Quality_fail] = quality_upgrade_fail(GoodsInfo),
            (catch log:log_quality_up(PlayerStatus, GoodsInfo, Quality_fail, StoneInfo#goods.goods_id, Cost, 0))
    end,
    %% 更新装备属性
    AttributeInfo = goods_util:get_goods_attribute_info(GoodsInfo#goods.player_id, GoodsInfo#goods.id, 3),
    case is_record(AttributeInfo, goods_attribute) of
        %% 如果降为0级，则删除
        true when NewQuality =:= 0 ->
            lib_goods:del_goods_attribute(AttributeInfo#goods_attribute.id);
        %% 原来有品质属性，则更改
        true ->
            Effect = goods_util:count_quality_addition(GoodsInfo, NewQuality),
            lib_goods:mod_goods_attribute(AttributeInfo, Effect);
        %% 原来没有品质属性，则新增
        false when NewQuality > 0 ->
            AttributeId = goods_util:get_goods_attribute_id(GoodsInfo#goods.subtype),
            Effect = goods_util:count_quality_addition(GoodsInfo, NewQuality),
            lib_goods:add_goods_attribute(GoodsInfo, 3, AttributeId, Effect);
        false -> skip
    end,
    %% 待完善
    {ok, NewPlayerStatus, NewStatus, [NewQuality, NewStoneNum]}.

get_quality_upgrade_ratio(GoodsInfo, GoodsQualityRule) ->
    case GoodsInfo#goods.quality =:= GoodsInfo#goods.quality_his of
        true when GoodsQualityRule#ets_goods_quality_upgrade.min_expected > 0
                    andalso GoodsInfo#goods.quality_fail < GoodsQualityRule#ets_goods_quality_upgrade.min_expected ->
            0;
        true when GoodsQualityRule#ets_goods_quality_upgrade.max_expected > 0
                    andalso GoodsInfo#goods.quality_fail >= GoodsQualityRule#ets_goods_quality_upgrade.max_expected ->
            100;
        true ->
            GoodsQualityRule#ets_goods_quality_upgrade.ratio;
        false ->
            GoodsQualityRule#ets_goods_quality_upgrade.ratio
    end.

quality_upgrade_ok(GoodsInfo) ->
     NewQuality = GoodsInfo#goods.quality + 1,
    case NewQuality > GoodsInfo#goods.quality_his of
        true ->
            Quality_his = NewQuality,
            Quality_fail = 0;
        false ->
            Quality_his = GoodsInfo#goods.quality_his,
            Quality_fail = GoodsInfo#goods.quality_fail
    end,
    Sql = io_lib:format(<<"update `goods` set quality = ~p, quality_his = ~p, quality_fail = ~p where id = ~p ">>, [NewQuality, Quality_his, Quality_fail, GoodsInfo#goods.id]),
    db_sql:execute(Sql),
    NewGoodsInfo = GoodsInfo#goods{ quality=NewQuality, quality_his=Quality_his, quality_fail=Quality_fail },
    ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
    NewQuality.

quality_upgrade_fail(GoodsInfo) ->
    NewQuality =  case GoodsInfo#goods.quality > 0 of
                        true -> GoodsInfo#goods.quality - 1;
                        false -> 0
                  end,
    case GoodsInfo#goods.quality =:= GoodsInfo#goods.quality_his of
        true ->
            Quality_fail = GoodsInfo#goods.quality_fail + 1;
        false ->
            Quality_fail = GoodsInfo#goods.quality_fail
    end,
    Sql = io_lib:format(<<"update `goods` set quality = ~p, quality_fail = ~p where id = ~p ">>, [NewQuality, Quality_fail, GoodsInfo#goods.id]),
    db_sql:execute(Sql),
    NewGoodsInfo = GoodsInfo#goods{ quality=NewQuality, quality_fail=Quality_fail },
    ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
    [NewQuality, Quality_fail].


%% 装备品质石拆除
quality_backout(PlayerStatus, GoodsStatus, GoodsInfo, GoodsBackoutRuleList) ->
    %% 随机机率，逐个匹配
    Ratio = util:rand(1, 100),
    %io:format("quality_backout: ~p~n",[Ratio]),
    RuleInfo = get_quality_backout_rule(GoodsBackoutRuleList, Ratio),
    %% 成功则生成新物品
    case is_record(RuleInfo, ets_goods_quality_backout) of
        %% 玩家铜钱不足
        true when (PlayerStatus#player_status.coin + PlayerStatus#player_status.bcoin) < RuleInfo#ets_goods_quality_backout.coin ->
            {fail, 9};
        true ->
            %% 花费铜钱
            Cost = RuleInfo#ets_goods_quality_backout.coin,
            NewPlayerStatus = lib_goods:cost_money(PlayerStatus, Cost, coin),
            %% 装备品质归零
            Sql1 = io_lib:format(<<"update `goods` set quality = 0, quality_fail = 0 where id = ~p ">>, [GoodsInfo#goods.id]),
            db_sql:execute(Sql1),
            NewGoodsInfo = GoodsInfo#goods{ quality=0, quality_fail=0 },
            ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
            %% 删除装备属性
            lib_goods:del_goods_attribute(GoodsInfo#goods.player_id, GoodsInfo#goods.id, 3),
            %% 品质石生成
            GoodsNum = RuleInfo#ets_goods_quality_backout.goods_num,
            GoodsTypeInfo = goods_util:get_goods_type(RuleInfo#ets_goods_quality_backout.goods_id),
            case is_record(GoodsTypeInfo, ets_goods_type) of
                true when GoodsNum > 0 ->
                    %% 生成新品质石
                    {ok, NewStatus} = quality_backout_ok(GoodsStatus, GoodsTypeInfo, GoodsNum),
                    (catch log:log_quality_out(PlayerStatus, GoodsInfo, RuleInfo#ets_goods_quality_backout.goods_id, RuleInfo#ets_goods_quality_backout.goods_num, Cost, 1)),
                    {ok, NewPlayerStatus, NewStatus};
                _ ->
                    (catch log:log_quality_out(PlayerStatus, GoodsInfo, RuleInfo#ets_goods_quality_backout.goods_id, RuleInfo#ets_goods_quality_backout.goods_num, Cost, 0)),
                    {fail, 0}
            end;
        %% 失败
        false ->
            {fail, 0}
    end.

get_quality_backout_rule(GoodsBackoutRuleList, Ratio) ->
    F = fun(Rule, [Ra, First, Result]) ->
            End = First + Rule#ets_goods_quality_backout.ratio,
            case Ra > First andalso Ra =< End of
                true -> [Ra, End, Rule];
                false -> [Ra, End, Result]
            end
        end,
    [Ratio, _, RuleInfo] = lists:foldl(F, [Ratio, 0, {}], GoodsBackoutRuleList),
    RuleInfo.

quality_backout_ok(GoodsStatus, GoodsTypeInfo, GoodsNum) ->
    NewInfo = goods_util:get_new_goods(GoodsTypeInfo),
    lib_goods:add_goods_base(GoodsStatus, GoodsTypeInfo, GoodsNum, NewInfo).

%% 装备强化
strengthen(PlayerStatus, GoodsStatus, GoodsInfo, StoneInfo, RuneInfo, GoodsStrengthenRule) ->
    %% 根据之前强化失败次数检查当前强化成功率
    Ratio = get_strengthen_ratio(GoodsInfo, GoodsStrengthenRule),
    %% 花费铜钱
    Cost = GoodsStrengthenRule#ets_goods_strengthen.coin,
    NewPlayerStatus = lib_goods:cost_money(PlayerStatus, Cost, coin),
    %% 扣掉强化石
    {ok, NewStatus1, NewStoneNum} = lib_goods:delete_one(GoodsStatus, StoneInfo, 1),
    %% 扣掉保底符
    {ok, NewStatus2, _} = lib_goods:delete_one(NewStatus1, RuneInfo, 1),
    NewRuneNum = 0,
    %% 更新物品状态
    Ram = util:rand(1, 100),
    %io:format("strengthen: ~p ~p~n",[Ratio, Ram]),
    case Ratio >= Ram of
        %% 强化成功
        true ->
            NewStrengthen = strengthen_ok(GoodsInfo, StoneInfo),
            (catch log:log_stren(PlayerStatus, GoodsInfo, GoodsInfo#goods.stren_fail, StoneInfo#goods.goods_id, RuneInfo#goods.goods_id, Cost, 1));
        %% 强化失败
        false ->
            [NewStrengthen, Stren_fail] = strengthen_fail(GoodsInfo, RuneInfo#goods.id),
            (catch log:log_stren(PlayerStatus, GoodsInfo, Stren_fail, StoneInfo#goods.goods_id, RuneInfo#goods.goods_id, Cost, 0))
    end,
    %% 更新装备属性
    AttributeInfo = goods_util:get_goods_attribute_info(GoodsInfo#goods.player_id, GoodsInfo#goods.id, 2),
    case is_record(AttributeInfo, goods_attribute) of
        %% 如果降为0级，则删除
        true when NewStrengthen =:= 0 ->
            lib_goods:del_goods_attribute(AttributeInfo#goods_attribute.id);
        %% 原来有强化属性，则更改
        true ->
            Effect = goods_util:count_stren_addition(GoodsInfo, NewStrengthen),
            lib_goods:mod_goods_attribute(AttributeInfo, Effect);
        %% 原来没有强化属性，则新增
        false when NewStrengthen > 0 ->
            AttributeId = goods_util:get_goods_attribute_id(GoodsInfo#goods.subtype),
            Effect = goods_util:count_stren_addition(GoodsInfo, NewStrengthen),
            lib_goods:add_goods_attribute(GoodsInfo, 2, AttributeId, Effect);
        false -> skip
    end,
    {ok, NewPlayerStatus, NewStatus2, [NewStrengthen, NewStoneNum, NewRuneNum]}.

get_strengthen_ratio(GoodsInfo, GoodsStrengthenRule) ->
    case GoodsInfo#goods.stren =:= GoodsInfo#goods.stren_his of
        true when GoodsStrengthenRule#ets_goods_strengthen.min_expected > 0
                    andalso GoodsInfo#goods.stren_fail < GoodsStrengthenRule#ets_goods_strengthen.min_expected ->
            0;
        true when GoodsStrengthenRule#ets_goods_strengthen.max_expected > 0
                    andalso GoodsInfo#goods.stren_fail > GoodsStrengthenRule#ets_goods_strengthen.max_expected ->
            100;
        true ->
            GoodsStrengthenRule#ets_goods_strengthen.ratio;
        false ->
            GoodsStrengthenRule#ets_goods_strengthen.ratio
    end.

strengthen_ok(GoodsInfo, StoneInfo) ->
    NewStrengthen = GoodsInfo#goods.stren + 1,
    case NewStrengthen > GoodsInfo#goods.stren_his of
        true ->
            Stren_his = NewStrengthen,
            Stren_fail = 0;
        false ->
            Stren_his = GoodsInfo#goods.stren_his,
            Stren_fail = GoodsInfo#goods.stren_fail
    end,
    case StoneInfo#goods.bind =:= 2 of
        true ->
            Bind = 2,
            Trade = 1;
        false ->
            Bind = GoodsInfo#goods.bind,
            Trade = GoodsInfo#goods.trade
    end,
    Sql = io_lib:format(<<"update `goods` set stren = ~p, stren_his = ~p, stren_fail = ~p, bind = ~p, trade = ~p where id = ~p ">>, [NewStrengthen, Stren_his, Stren_fail, Bind, Trade, GoodsInfo#goods.id]),
    db_sql:execute(Sql),
    NewGoodsInfo = GoodsInfo#goods{ stren=NewStrengthen, stren_his=Stren_his, stren_fail=Stren_fail, bind=Bind, trade=Trade },
    ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
    NewStrengthen.

strengthen_fail(GoodsInfo, RuneId) ->
    NewStrengthen = case GoodsInfo#goods.stren > 1 of
                        %% 有保底符
                        true when RuneId > 0 -> GoodsInfo#goods.stren - 1;
                        true -> 1;
                        _ -> GoodsInfo#goods.stren
                    end,
    case GoodsInfo#goods.stren =:= GoodsInfo#goods.stren_his of
        true ->  Stren_fail = GoodsInfo#goods.stren_fail + 1;
        false -> Stren_fail = GoodsInfo#goods.stren_fail
    end,
    Sql = io_lib:format(<<"update `goods` set stren = ~p, stren_fail = ~p where id = ~p ">>, [NewStrengthen, Stren_fail, GoodsInfo#goods.id]),
    db_sql:execute(Sql),
    NewGoodsInfo = GoodsInfo#goods{ stren=NewStrengthen, stren_fail=Stren_fail },
    ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
    [NewStrengthen, Stren_fail].

%% 装备打孔
hole(PlayerStatus, Status, GoodsInfo, RuneInfo) ->
    %% 花费铜钱
    Cost = 100,
    NewPlayerStatus = lib_goods:cost_money(PlayerStatus, Cost, coin),
    %% 扣掉打孔石
    {ok, NewStatus, NewRuneNum} = lib_goods:delete_one(Status, RuneInfo, 1),
    %% 更新物品状态
    NewHole = GoodsInfo#goods.hole + 1,
    Sql2 = io_lib:format(<<"update `goods` set hole = ~p where id = ~p ">>, [NewHole, GoodsInfo#goods.id]),
    db_sql:execute(Sql2),
    NewGoodsInfo = GoodsInfo#goods{ hole=NewHole },
    ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
    %% 日志
    (catch log:log_hole(PlayerStatus, GoodsInfo, Cost, 1)),
    {ok, NewPlayerStatus, NewStatus, [NewHole, NewRuneNum]}.

%% 宝石合成
compose(PlayerStatus, Status, StoneList, RuneInfo, GoodsComposeRule) ->
    %% 根据宝石数和幸运符计算成功率
    Ratio = case RuneInfo#goods.id > 0 of
                    true -> GoodsComposeRule#ets_goods_compose.ratio + 15;
                    false -> GoodsComposeRule#ets_goods_compose.ratio
            end,
    %% 花费铜钱
    Cost = GoodsComposeRule#ets_goods_compose.coin,
    NewPlayerStatus = lib_goods:cost_money(PlayerStatus, Cost, coin),
    %% 扣掉宝石
    F = fun([StoneInfo, StoneNum], Status1) ->
            {ok, NewStatus, _} = lib_goods:delete_one(Status1, StoneInfo, StoneNum),
            NewStatus
         end,
    NewStatus1 = lists:foldl(F, Status, StoneList),
    %% 扣掉幸运符
    {ok, NewStatus2, _} = lib_goods:delete_one(NewStatus1, RuneInfo, 1),
    %NewRuneNum = 0,
    %% 更新物品状态
    Ram = util:rand(1, 100),
    %io:format("strengthen: ~p ~p~n",[Ratio, Ram]),
    GoodsTypeInfo = goods_util:get_goods_type(GoodsComposeRule#ets_goods_compose.new_id),
    case Ratio >= Ram of
        %% 合成成功
        true when is_record(GoodsTypeInfo, ets_goods_type) ->
            {ok, NewStatus3} = compose_ok(NewStatus2, GoodsTypeInfo, 1),
            (catch log:log_compose(NewPlayerStatus, GoodsComposeRule, GoodsTypeInfo#ets_goods_type.subtype, RuneInfo#goods.goods_id, Cost, 1)),
            {ok, NewPlayerStatus, NewStatus3, GoodsTypeInfo#ets_goods_type.goods_id};
        %% 合成失败
        _ ->
            (catch log:log_compose(NewPlayerStatus, GoodsComposeRule, GoodsTypeInfo#ets_goods_type.subtype, RuneInfo#goods.goods_id, Cost, 0)),
            {ok, NewPlayerStatus, NewStatus2, 0}
    end.

compose_ok(GoodsStatus, GoodsTypeInfo, GoodsNum) ->
    NewInfo = goods_util:get_new_goods(GoodsTypeInfo),
    lib_goods:add_goods_base(GoodsStatus, GoodsTypeInfo, GoodsNum, NewInfo).

%% 宝石镶嵌
inlay(PlayerStatus, Status, GoodsInfo, StoneInfo, TotalRuneNum, NewRuneList, GoodsInlayRule) ->
    %% 根据幸运符计算成功率
    Ratio = case TotalRuneNum > 0 of
                    true -> GoodsInlayRule#ets_goods_inlay.ratio + 25 * TotalRuneNum;
                    false -> GoodsInlayRule#ets_goods_inlay.ratio
            end,
    %% 花费铜钱
    Cost = GoodsInlayRule#ets_goods_inlay.coin,
    NewPlayerStatus = lib_goods:cost_money(PlayerStatus, Cost, coin),
    %% 扣掉宝石
    {ok, NewStatus1, _} = lib_goods:delete_one(Status, StoneInfo, 1),
    %% 扣掉幸运符
    %{ok, NewStatus2, _} = lib_goods:delete_one(NewStatus1, RuneInfo, RuneNum),
    F = fun([RuneInfo, RuneNum], Status1) ->
            {ok, NewStatus, _} = lib_goods:delete_one(Status1, RuneInfo, RuneNum),
            NewStatus
         end,
    NewStatus2 = lists:foldl(F, NewStatus1, NewRuneList),
    %% 更新物品状态
    Ram = util:rand(1, 100),
    %io:format("inlay: ~p ~p~n",[Ratio, Ram]),
    case Ratio >= Ram of
        %% 镶嵌成功
        true ->
            inlay_ok(GoodsInfo, StoneInfo),
            (catch log:log_inlay(NewPlayerStatus, GoodsInfo, StoneInfo#goods.goods_id, Cost, 1)),
            {ok, 1, NewPlayerStatus, NewStatus2};
        %% 镶嵌失败
        false ->
            (catch log:log_inlay(NewPlayerStatus, GoodsInfo, StoneInfo#goods.goods_id, Cost, 0)),
            {ok, 0, NewPlayerStatus, NewStatus2}
    end.

inlay_ok(GoodsInfo, StoneInfo) ->
    case GoodsInfo#goods.hole1_goods > 0 of
        false ->
            Sql = io_lib:format(<<"update `goods` set hole1_goods = ~p where id = ~p ">>, [StoneInfo#goods.goods_id, GoodsInfo#goods.id]),
            NewGoodsInfo = GoodsInfo#goods{ hole1_goods=StoneInfo#goods.goods_id };
        true when GoodsInfo#goods.hole2_goods =:= 0 ->
            Sql = io_lib:format(<<"update `goods` set hole2_goods = ~p where id = ~p ">>, [StoneInfo#goods.goods_id, GoodsInfo#goods.id]),
            NewGoodsInfo = GoodsInfo#goods{ hole1_goods=StoneInfo#goods.goods_id };
        true when GoodsInfo#goods.hole3_goods =:= 0 ->
            Sql = io_lib:format(<<"update `goods` set hole3_goods = ~p where id = ~p ">>, [StoneInfo#goods.goods_id, GoodsInfo#goods.id]),
            NewGoodsInfo = GoodsInfo#goods{ hole1_goods=StoneInfo#goods.goods_id }
    end,
    db_sql:execute(Sql),
    ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
    %% 更新装备属性
    AttributeId = goods_util:get_inlay_attribute_id(StoneInfo),
    Effect = goods_util:count_inlay_addition(StoneInfo),
    lib_goods:add_goods_attribute(GoodsInfo, 4, AttributeId, Effect),
    ok.

%% 宝石拆除
backout(PlayerStatus, Status, GoodsInfo, RuneInfo) ->
   %% 花费铜钱
    Cost = 100,
    NewPlayerStatus = lib_goods:cost_money(PlayerStatus, Cost, coin),
    %% 拆除宝石
    F = fun(StoneId, [Status1, L]) ->
            GoodsTypeInfo = goods_util:get_ets_info(?ETS_GOODS_TYPE, StoneId),
            case is_record(GoodsTypeInfo, ets_goods_type) of
                true ->
                    {ok, NewStatus1} = backout_ok(Status1, GoodsTypeInfo),
                    GoodsList = goods_util:get_type_goods_list(Status1#goods_status.player_id, StoneId, GoodsTypeInfo#ets_goods_type.bind, 4),
                    NewL = L ++ GoodsList,
                    [NewStatus1, NewL];
                false ->
                    [Status1, L]
            end
         end,
    [NewStatus, _] = lists:foldr(F, [Status, []], [GoodsInfo#goods.hole1_goods, GoodsInfo#goods.hole2_goods, GoodsInfo#goods.hole3_goods]),
    %io:format("Res: ~p~n",[Res]),
    %% 扣掉幸运符
    {ok, NewStatus1, _} = lib_goods:delete_one(NewStatus, RuneInfo, 1),
    %% 更新物品状态
    Sql2 = io_lib:format(<<"update `goods` set hole1_goods = 0, hole2_goods = 0, hole3_goods = 0 where id = ~p ">>, [GoodsInfo#goods.id]),
    db_sql:execute(Sql2),
    NewGoodsInfo4 = GoodsInfo#goods{ hole1_goods = 0, hole2_goods = 0, hole3_goods = 0 },
    ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo4),
    %% 删除装备属性
    lib_goods:del_goods_attribute(GoodsInfo#goods.player_id, GoodsInfo#goods.id, 4),
    (catch log:log_backout(NewPlayerStatus, GoodsInfo, Cost)),
    {ok, NewPlayerStatus, NewStatus1}.

backout_ok(GoodsStatus, GoodsTypeInfo) ->
    NewInfo = goods_util:get_new_goods(GoodsTypeInfo),
    lib_goods:add_goods_base(GoodsStatus, GoodsTypeInfo, 1, NewInfo).

%%% 洗附加属性
wash(PlayerStatus, Status, GoodsInfo, RuneInfo, AddAttributeRuleList) ->
    %% 花费铜钱
    Cost = 100,
    NewPlayerStatus = lib_goods:cost_money(PlayerStatus, Cost, coin),
    %% 扣掉洗炼符
    {ok, NewStatus, NewRuneNum} = lib_goods:delete_one(Status, RuneInfo, 1),
    %% 洗附加属性，随机机率，逐个匹配
    [_, _, RuleInfoList] = lists:foldl(fun handle_wash_rule/2, [AddAttributeRuleList, 100, []], lists:seq(1, GoodsInfo#goods.color)),
    if length(RuleInfoList) > 0 ->
            %% 删除原附加属性
            lib_goods:del_goods_attribute(GoodsInfo#goods.player_id, GoodsInfo#goods.id, 1),
            %% 添加新附加属性
            F3 = fun(RuleInfo) ->
                    Effect = goods_util:count_add_addition(RuleInfo),
                    lib_goods:add_goods_attribute(GoodsInfo, 1, RuleInfo#ets_goods_attribute_rule.attribute_id, Effect)
                 end,
            lists:map(F3, RuleInfoList);
        true -> skip
    end,
    (catch log:log_wash(NewPlayerStatus, GoodsInfo, Cost)),
    {ok, NewPlayerStatus, NewStatus, NewRuneNum}.

%% 洗附加属性，随机机率，逐个匹配
handle_wash_rule(_, [RuleList, End, Result]) ->
    Ratio = util:rand(1, End),
    %io:format("wash: ~p ~p~n",[Ratio, End]),
    F2 = fun(Item, [Ra, First, Result2, RuleList2]) ->
                End2 = First + Item#ets_goods_attribute_rule.ratio,
                case Ra > First andalso Ra =< End2 of
                    true -> [Ra, End2, Item, RuleList2];
                    false -> [Ra, End2, Result2, [Item|RuleList2]]
                end
         end,
    [_, _, Result1, RuleList1] = lists:foldl(F2, [Ratio, 0, {}, []], RuleList),
    NewRuleList1 = lists:reverse(RuleList1),
    NewEnd = End - Result1#ets_goods_attribute_rule.ratio,
    [NewRuleList1, NewEnd, [Result1|Result]].