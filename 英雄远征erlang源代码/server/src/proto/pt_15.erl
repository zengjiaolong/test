%%%-----------------------------------
%%% @Module  : pt_15
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.04.29
%%% @Description: 15物品信息
%%%-----------------------------------
-module(pt_15).
-include("record.hrl").
-export([read/2, write/2, write_goods_info/2]).

%%
%%客户端 -> 服务端 ----------------------------
%%

%%查询物品详细信息
read(15000, <<GoodsId:32, Location:16>>) ->
    %io:format("read: ~p~n",[[15000, GoodsId, Location]]),
    {ok, [GoodsId, Location]};

%%查询别人物品详细信息
read(15001, <<Owner:32, GoodsId:32>>) ->
    %io:format("read: ~p~n",[[15001, Owner, GoodsId]]),
    {ok, [Owner, GoodsId]};

%% 查看地上的掉落包
read(15002, <<DropId:32>>) ->
    %io:format("read: ~p~n",[[15002, DropId]]),
    {ok, DropId};

%%查询物品列表
read(15010, <<Location:16>>) ->
    %io:format("read: ~p~n",[[15010, Location]]),
    {ok, Location};

%%查看别人身上装备列表
read(15011, <<PlayerId:32>>) ->
    %io:format("read: ~p~n",[[15011, PlayerId]]),
    {ok, PlayerId};

%%获取要修理装备列表
read(15012, _R) ->
    %io:format("read: ~p~n",[[15012, _R]]),
    {ok, mend_list};

%% 取商店物品列表
read(15013, <<ShopType:16, ShopSubtype:16>>) ->
    %io:format("read: ~p~n",[[15013, ShopType, ShopSubtype]]),
    {ok, [ShopType, ShopSubtype]};

%% 列出背包打造装备列表
read(15014, _R) ->
    %io:format("read: ~p~n",[15014]),
    {ok, make_list};

%%购买物品
read(15020, <<GoodsTypeId:32, GoodsNum:16, ShopType:16>>) ->
    %io:format("read: ~p~n",[[15020, GoodsTypeId, GoodsNum, ShopType]]),
    {ok, [GoodsTypeId, GoodsNum, ShopType]};

%%出售物品
read(15021, <<GoodsId:32, GoodsNum:16>>) ->
    %io:format("read: ~p~n",[[15021, GoodsId, GoodsNum]]),
    {ok, [GoodsId, GoodsNum]};

%%扩充背包
read(15022, _R) ->
    %io:format("read: ~p~n",[[15022, _R]]),
    {ok, extend_bag};

%%装备物品
read(15030, <<GoodsId:32, Cell:16>>) ->
    %io:format("read: ~p~n",[[15030, GoodsId, Cell]]),
    {ok, [GoodsId, Cell]};

%%卸下装备
read(15031, <<GoodsId:32>>) ->
    %io:format("read: ~p~n",[[15031, GoodsId]]),
    {ok, GoodsId};

%%修理装备
read(15033, <<GoodsId:32>>) ->
    %io:format("read: ~p~n",[[15033, GoodsId]]),
    {ok, GoodsId};

%% 切换装备
read(15034, <<Equip:16>>) ->
    %io:format("read: ~p~n",[[15034, Equip]]),
    {ok, Equip};

%%背包拖动物品
read(15040, <<GoodsId:32, OldCell:16, NewCell:16>>) ->
    %io:format("read: ~p~n",[[15040, GoodsId, OldCell, NewCell]]),
    {ok, [GoodsId, OldCell, NewCell]};

%%物品存入仓库
read(15041, <<GoodsId:32, GoodsNum:16>>) ->
    %io:format("read: ~p~n",[[15041, GoodsId, GoodsNum]]),
    {ok, [GoodsId, GoodsNum]};

%%物品从仓库取出
read(15042, <<GoodsId:32, GoodsNum:16>>) ->
    %io:format("read: ~p~n",[[15042, GoodsId, GoodsNum]]),
    {ok, [GoodsId, GoodsNum]};

%%使用物品
read(15050, <<GoodsId:32, GoodsNum:16>>) ->
    %io:format("read: ~p~n",[[15050, GoodsId, GoodsNum]]),
    {ok, [GoodsId, GoodsNum]};

%%丢弃物品
read(15051, <<GoodsId:32, GoodsNum:16>>) ->
    %io:format("read: ~p~n",[[15051, GoodsId, GoodsNum]]),
    {ok, [GoodsId, GoodsNum]};

%% 整理背包
read(15052, _R) ->
    %io:format("read: ~p~n",[[15052]]),
    {ok, clean};

%% 拣取地上掉落包的物品
read(15053, <<DropId:32, GoodsTypeId:32>>) ->
    %io:format("read: ~p~n",[[15053, DropId, GoodsTypeId]]),
    {ok, [DropId, GoodsTypeId]};

%% 装备品质升级
read(15060, <<GoodsId:32, StoneId:32>>) ->
    %io:format("read: ~p~n",[[15060, GoodsId, StoneId]]),
    {ok, [GoodsId, StoneId]};

%% 装备品质石拆除
read(15061, <<GoodsId:32, RuneId:32>>) ->
    %io:format("read: ~p~n",[[15061, GoodsId, RuneId]]),
    {ok, [GoodsId, RuneId]};

%% 装备强化
read(15062, <<GoodsId:32, StoneId:32, RuneId:32>>) ->
    %io:format("read: ~p~n",[[15062, GoodsId, StoneId, RuneId]]),
    {ok, [GoodsId, StoneId, RuneId]};

%% 装备打孔
read(15063, <<GoodsId:32, RuneId:32>>) ->
    %io:format("read: ~p~n",[[15063, GoodsId, RuneId]]),
    {ok, [GoodsId, RuneId]};

%% 宝石合成
read(15064, <<RuneId:32, StoneTypeId:32, Num:16, Bin/binary>>) ->
    %io:format("read: ~p~n",[[15064, RuneId, Num, Bin]]),
    F = fun(_, [Bin1,L]) ->
        <<GoodsId:32, GoodsNum:16, Rest/binary>> = Bin1,
        L1 = [[GoodsId,GoodsNum]|L],
        [Rest, L1]
    end,
    [_, StoneList] = lists:foldl(F, [Bin,[]], lists:seq(1, Num)),
    %io:format("read: ~p~n",[[15064, RuneId, StoneTypeId, Num, StoneList]]),
    {ok, [RuneId, StoneTypeId, StoneList]};

%% 宝石镶嵌
read(15065, <<GoodsId:32, StoneId:32, Num:16, Bin/binary>>) ->
    F = fun(_, [Bin1,L]) ->
        <<RuneId:32, RuneNum:16, Rest/binary>> = Bin1,
        L1 = [[RuneId,RuneNum]|L],
        [Rest, L1]
    end,
    [_, RuneList] = lists:foldl(F, [Bin,[]], lists:seq(1, Num)),
    %io:format("read: ~p~n",[[15065, GoodsId, StoneId, Num, RuneList]]),
    {ok, [GoodsId, StoneId, RuneList]};

%% 宝石拆除
read(15066, <<GoodsId:32>>) ->
    %io:format("read: ~p~n",[[15066, GoodsId]]),
    {ok, GoodsId};

%% 洗附加属性
read(15067, <<GoodsId:32, RuneId:32>>) ->
    %io:format("read: ~p~n",[[15067, GoodsId, RuneId]]),
    {ok, [GoodsId, RuneId]};

read(_Cmd, _R) ->
    %%io:format("read: ~p~n",[[_Cmd, _R]]),
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%%查询物品详细信息
write_goods_info(Cmd, [GoodsInfo, SuitNum, AttributeList]) ->
    %io:format("write: ~p~n",[[Cmd, GoodsInfo, AttributeList]]),
    case is_record(GoodsInfo, goods) of
        true ->
            GoodsId = GoodsInfo#goods.id,
            TypeId = GoodsInfo#goods.goods_id,
            Cell = GoodsInfo#goods.cell,
            Num = GoodsInfo#goods.num,
            Bind = GoodsInfo#goods.bind,
            Trade = GoodsInfo#goods.trade,
            Sell = GoodsInfo#goods.sell,
            Isdrop = GoodsInfo#goods.isdrop,
            Attrition = goods_util:get_goods_attrition(GoodsInfo#goods.attrition, GoodsInfo#goods.use_num),
            Color = GoodsInfo#goods.color,
            Quality = GoodsInfo#goods.quality,
            Stren = GoodsInfo#goods.stren,
            Hole = GoodsInfo#goods.hole,
            Hole1_goods = GoodsInfo#goods.hole1_goods,
            Hole2_goods = GoodsInfo#goods.hole2_goods,
            Hole3_goods = GoodsInfo#goods.hole3_goods,
            SuitId = GoodsInfo#goods.suit_id,
            SuitNum = SuitNum,
            Forza = GoodsInfo#goods.forza,
            Agile = GoodsInfo#goods.agile,
            Wit = GoodsInfo#goods.wit,
            Vitality = GoodsInfo#goods.vitality,
            Spirit = GoodsInfo#goods.spirit,
            Hp = GoodsInfo#goods.hp,
            Mp = GoodsInfo#goods.mp,
            Att = GoodsInfo#goods.att,
            Def = GoodsInfo#goods.def,
            Hit = GoodsInfo#goods.hit,
            Dodge = GoodsInfo#goods.dodge,
            Crit = GoodsInfo#goods.crit,
            Ten = GoodsInfo#goods.ten,
            ListNum = length(AttributeList),
            F = fun(AttributeInfo) ->
                    AttributeType = AttributeInfo#goods_attribute.attribute_type,
                    AttributeId = AttributeInfo#goods_attribute.attribute_id,
                    AttributeVal = get_attribute_value(AttributeInfo),
                    <<AttributeType:16, AttributeId:16, AttributeVal:32>>
                end,
            ListBin = list_to_binary(lists:map(F, AttributeList));
        false ->
            GoodsId = 0,
            TypeId = 0,
            Cell = 0,
            Num = 0,
            Bind = 0,
            Trade = 0,
            Sell = 0,
            Isdrop = 0,
            Attrition = 0,
            Color = 0,
            Quality = 0,
            Stren = 0,
            Hole = 0,
            Hole1_goods = 0,
            Hole2_goods = 0,
            Hole3_goods = 0,
            SuitId = 0,
            SuitNum = 0,
            Forza = 0,
            Agile = 0,
            Wit = 0,
            Vitality = 0,
            Spirit = 0,
            Hp = 0,
            Mp = 0,
            Att = 0,
            Def = 0,
            Hit = 0,
            Dodge = 0,
            Crit = 0,
            Ten = 0,
            ListNum = 0,
            ListBin = <<>>
    end,
    %io:format("write: ~p~n",[[Cmd, GoodsId, TypeId, Cell, Num, Bind, Trade,
    %                        Sell, Isdrop, Attrition, Color, Quality, Stren,
    %                        Hole, Hole1_goods, Hole2_goods, Hole3_goods, SuitId, SuitNum,
    %                        Forza, Agile, Wit, Vitality, Spirit, Hp, Mp,
    %                        Att, Def, Hit, Dodge, Crit, Ten, ListNum]]),
    %io:format("write: ~p~n", [binary_to_list(ListBin)]),
    {ok, pt:pack(Cmd, <<GoodsId:32, TypeId:32, Cell:16, Num:16, Bind:16, Trade:16,
                            Sell:16, Isdrop:16, Attrition:16, Color:16, Quality:16, Stren:16,
                            Hole:16, Hole1_goods:32, Hole2_goods:32, Hole3_goods:32, SuitId:16,
                            SuitNum:16, Forza:16, Agile:16, Wit:16, Vitality:16, Spirit:32, Hp:32, Mp:32,
                            Att:16, Def:16, Hit:16, Dodge:16, Crit:16, Ten:16, ListNum:16, ListBin/binary>>)}.

%% 查看地上的掉落包
write(15002, [Res, DropId, DropList]) ->
    %io:format("write: ~p~n",[[15002, Res, DropId, DropList]]),
    ListNum = length(DropList),
    F = fun({GoodsTypeId, _GoodsType, GoodsNum, Quality}) ->
            <<GoodsTypeId:32, GoodsNum:16, Quality:16>>
        end,
    ListBin = list_to_binary(lists:map(F, DropList)),
    {ok, pt:pack(15002, <<Res:16, DropId:32, ListNum:16, ListBin/binary>>)};

%%查询玩家物品列表
write(15010, [Location, CellNum, Coin, Silver, Gold, GoodsList]) ->
    %io:format("write: ~p~n",[[15010, Location, CellNum, Coin, Silver, Gold]]),
    ListNum = length(GoodsList),
    F = fun(GoodsInfo) ->
            GoodsId = GoodsInfo#goods.id,
            TypeId = GoodsInfo#goods.goods_id,
            Cell = GoodsInfo#goods.cell,
            GoodsNum = GoodsInfo#goods.num,
            %io:format("list: ~p~n",[[GoodsId, TypeId, Cell, GoodsNum]]),
            <<GoodsId:32, TypeId:32, Cell:16, GoodsNum:16>>
        end,
    %ListBin = list_to_binary([util:get_list(X, F) || X <- GoodList]),
    ListBin = list_to_binary(lists:map(F, GoodsList)),
    {ok, pt:pack(15010, <<Location:16, CellNum:16, Coin:32, Silver:32, Gold:32, ListNum:16, ListBin/binary>>)};

%%查看别人身上装备列表
write(15011, [Res, PlayerId, GoodsList]) ->
    %io:format("write: ~p~n",[[15011, Res, PlayerId]]),
    ListNum = length(GoodsList),
    F = fun(GoodsInfo) ->
            GoodsId = GoodsInfo#goods.id,
            TypeId = GoodsInfo#goods.goods_id,
            Cell = GoodsInfo#goods.cell,
            GoodsNum = GoodsInfo#goods.num,
            %io:format("list: ~p~n",[[GoodsId, TypeId, Cell, GoodsNum]]),
            <<GoodsId:32, TypeId:32, Cell:16, GoodsNum:16>>
        end,
    ListBin = list_to_binary(lists:map(F, GoodsList)),
    {ok, pt:pack(15011, <<Res:16, PlayerId:32, ListNum:16, ListBin/binary>>)};

%%获取要修理装备列表
write(15012, MendList) ->
    %io:format("write: ~p~n",[[15012, MendList]]),
    ListNum = length(MendList),
    F = fun([GoodsId, TypeId, Attrition, Cost]) ->
            <<GoodsId:32, TypeId:32, Attrition:16, Cost:32>>
        end,
    ListBin = list_to_binary(lists:map(F, MendList)),
    {ok, pt:pack(15012, <<ListNum:16, ListBin/binary>>)};

%%取商店物品列表
write(15013, [ShopType, ShopSubtype, ShopList]) ->
    %io:format("write: ~p~n",[[15013, ShopType, ShopSubtype, ShopList]]),
    ListNum = length(ShopList),
    F = fun(ShopInfo) ->
            GoodsId = ShopInfo#ets_shop.goods_id,
            <<GoodsId:32>>
        end,
     ListBin = list_to_binary(lists:map(F, ShopList)),
    {ok, pt:pack(15013, <<ShopType:16, ShopSubtype:16, ListNum:16, ListBin/binary>>)};

%%列出背包打造装备列表
write(15014, EquipList) ->
    %io:format("write: ~p~n",[[15014]]),
    ListNum = length(EquipList),
    F = fun(GoodsInfo) ->
            GoodsId = GoodsInfo#goods.id,
            Hole = GoodsInfo#goods.hole,
            Stren = GoodsInfo#goods.stren,
            Quality = GoodsInfo#goods.quality,
            %io:format("list: ~p~n",[[GoodsId, Hole, Stren, Quality]]),
            <<GoodsId:32, Hole:16, Stren:16, Quality:16>>
        end,
    ListBin = list_to_binary(lists:map(F, EquipList)),
    {ok, pt:pack(15014, <<ListNum:16, ListBin/binary>>)};

%%购买物品
write(15020, [Res, GoodsTypeId, GoodsNum, ShopType, NewCoin, NewSilver, NewGold, GoodsList]) ->
    %io:format("write: ~p~n",[[15020, Res, GoodsTypeId, GoodsNum, ShopType, NewCoin, NewSilver, NewGold]]),
    ListNum = length(GoodsList),
    F = fun(GoodsInfo) ->
            GoodsId = GoodsInfo#goods.id,
            TypeId = GoodsInfo#goods.goods_id,
            Cell = GoodsInfo#goods.cell,
            Num = GoodsInfo#goods.num,
            %io:format("list: ~p~n",[[GoodsId, TypeId, Cell, Num]]),
            <<GoodsId:32, TypeId:32, Cell:16, Num:16>>
        end,
    ListBin = list_to_binary(lists:map(F, GoodsList)),
    {ok, pt:pack(15020, <<Res:16, GoodsTypeId:32, GoodsNum:16, ShopType:16, NewCoin:32, NewSilver:32, NewGold:32, ListNum:16, ListBin/binary>>)};

%%出售物品
write(15021, [Res, GoodsId, GoodsNum, Coin]) ->
    %io:format("write: ~p~n",[[15021, Res, GoodsId, GoodsNum, Coin]]),
    {ok, pt:pack(15021, <<Res:16, GoodsId:32, GoodsNum:16, Coin:32>>)};

%%扩充背包
write(15022, [Res, NewCoin, NewCellNum]) ->
    %io:format("write: ~p~n",[[15022, Res, NewCoin, NewCellNum]]),
    {ok, pt:pack(15022, <<Res:16, NewCoin:32, NewCellNum:16>>)};

%%装备物品
write(15030, [Res, GoodsId, OldGoodsId, OldGoodsTypeId, OldGoodsCell, Effect]) ->
    %io:format("write: ~p~n",[[15030, Res, GoodsId, OldGoodsId, OldGoodsTypeId, OldGoodsCell, Effect]]),
    [Hp, Mp, Att, Def, Hit, Dodge, Crit, Ten] = case length(Effect) =:= 8 of
                                                        true -> Effect;
                                                        false -> [0, 0, 0, 0, 0, 0, 0, 0]
                                                end,
    {ok, pt:pack(15030, <<Res:16, GoodsId:32, OldGoodsId:32, OldGoodsTypeId:32, OldGoodsCell:16, Hp:32, Mp:32, Att:16, Def:16, Hit:16, Dodge:16, Crit:16, Ten:16>>)};

%%卸下装备
write(15031, [Res, GoodsId, TypeId, Cell]) ->
    %io:format("write: ~p~n",[[15031, Res, GoodsId, TypeId, Cell]]),
    {ok, pt:pack(15031, <<Res:16, GoodsId:32, TypeId:32, Cell:16>>)};

%%装备磨损
write(15032, GoodsList) ->
    %io:format("write: ~p~n",[[15032, GoodsList]]),
    ListNum = length(GoodsList),
    F = fun(GoodsInfo) ->
            GoodsId = GoodsInfo#goods.id,
            <<GoodsId:32>>
        end,
    ListBin = list_to_binary(lists:map(F, GoodsList)),
    {ok, pt:pack(15032, <<ListNum:16, ListBin/binary>>)};

%%修理装备
write(15033, [Res, GoodsId, NewCoin]) ->
    %io:format("write: ~p~n",[[15033, Res, GoodsId, NewCoin]]),
    {ok, pt:pack(15033, <<Res:16, GoodsId:32, NewCoin:32>>)};

%%切换装备
write(15034, [Res, Equip, EquipList]) ->
    %io:format("write: ~p~n",[[15034, Res, Equip]]),
    ListNum = length(EquipList),
    F = fun(GoodsInfo) ->
            GoodsId = GoodsInfo#goods.id,
            TypeId = GoodsInfo#goods.goods_id,
            Cell = GoodsInfo#goods.cell,
            Num = GoodsInfo#goods.num,
            %io:format("list: ~p~n",[[GoodsId, TypeId, Cell, Num]]),
            <<GoodsId:32, TypeId:32, Cell:16, Num:16>>
        end,
     ListBin = list_to_binary(lists:map(F, EquipList)),
    {ok, pt:pack(15034, <<Res:16, Equip:16, ListNum:16, ListBin/binary>>)};

%%背包拖动物品
write(15040, [Res, GoodsId1, GoodsTypeId1, OldCell, GoodsId2, GoodsTypeId2, NewCell]) ->
    %io:format("write: ~p~n",[[15040, Res, GoodsId1, GoodsTypeId1, OldCell, GoodsId2, GoodsTypeId2, NewCell]]),
    {ok, pt:pack(15040, <<Res:16, GoodsId1:32, GoodsTypeId1:32, OldCell:16, GoodsId2:32, GoodsTypeId2:32, NewCell:16>>)};

%%物品存入仓库
write(15041, [Res, GoodsId, GoodsNum]) ->
    %io:format("write: ~p~n",[[15041, Res, GoodsId, GoodsNum]]),
    {ok, pt:pack(15041, <<Res:16, GoodsId:32, GoodsNum:16>>)};

%%物品从仓库取出
write(15042, [Res, GoodsId, GoodsList]) ->
    %io:format("write: ~p~n",[[15042, Res, GoodsId]]),
    ListNum = length(GoodsList),
    F = fun(GoodsInfo) ->
            Id = GoodsInfo#goods.id,
            TypeId = GoodsInfo#goods.goods_id,
            Cell = GoodsInfo#goods.cell,
            Num = GoodsInfo#goods.num,
            %io:format("list: ~p~n",[[Id, TypeId, Cell, Num]]),
            <<Id:32, TypeId:32, Cell:16, Num:16>>
        end,
    ListBin = list_to_binary(lists:map(F, GoodsList)),
    {ok, pt:pack(15042, <<Res:16, GoodsId:32, ListNum:16, ListBin/binary>>)};

%%使用物品
write(15050, [Res, GoodsId, GoodsTypeId, GoodsNum, Effect]) ->
    %io:format("write: ~p~n",[[15050, Res, GoodsId, GoodsTypeId, GoodsNum, Effect]]),
    [Hp, Mp] = case length(Effect) =:= 2 of
                    true -> Effect;
                    false -> [0, 0]
               end,
    {ok, pt:pack(15050, <<Res:16, GoodsId:32, GoodsTypeId:32, GoodsNum:16, Hp:32, Mp:32>>)};

%%丢弃物品
write(15051, [Res, GoodsId, GoodsNum]) ->
    %io:format("write: ~p~n",[[15051, Res, GoodsId, GoodsNum]]),
    {ok, pt:pack(15051, <<Res:16, GoodsId:32, GoodsNum:16>>)};

%%整理背包
write(15052, GoodsList) ->
    ListNum = length(GoodsList),
    %io:format("write: ~p~n",[[15052, ListNum]]),
    F = fun(GoodsInfo) ->
            GoodsId = GoodsInfo#goods.id,
            TypeId = GoodsInfo#goods.goods_id,
            Cell = GoodsInfo#goods.cell,
            Num = GoodsInfo#goods.num,
            %io:format("list: ~p~n",[[GoodsId, TypeId, Cell, Num]]),
            <<GoodsId:32, TypeId:32, Cell:16, Num:16>>
        end,
    ListBin = list_to_binary(lists:map(F, GoodsList)),
    {ok, pt:pack(15052, <<ListNum:16, ListBin/binary>>)};

%% 拣取地上掉落包的物品
write(15053, [Res, DropId, GoodsTypeId]) ->
    %io:format("write: ~p~n",[[15053, Res, DropId, GoodsTypeId]]),
    {ok, pt:pack(15053, <<Res:16, DropId:32, GoodsTypeId:32>>)};

%%品质石升级
write(15060, [Res, GoodsId, NewQuality, NewStoneNum, NewCoin]) ->
    %io:format("write: ~p~n",[[15060, Res, GoodsId, NewQuality, NewStoneNum, NewCoin]]),
    {ok, pt:pack(15060, <<Res:16, GoodsId:32, NewQuality:16, NewStoneNum:16, NewCoin:32>>)};

%%装备品质石拆除
write(15061, [Res, GoodsId, NewCoin]) ->
    %io:format("write: ~p~n",[[15061, Res, GoodsId, NewCoin]]),
    {ok, pt:pack(15061, <<Res:16, GoodsId:32, NewCoin:32>>)};

%%装备强化
write(15062, [Res, GoodsId, NewStrengthen, NewStoneNum, NewRuneNum, NewCoin]) ->
    %io:format("write: ~p~n",[[15062, Res, GoodsId, NewStrengthen, NewStoneNum, NewRuneNum, NewCoin]]),
    {ok, pt:pack(15062, <<Res:16, GoodsId:32, NewStrengthen:16, NewStoneNum:16, NewRuneNum:16, NewCoin:32>>)};

%%装备打孔
write(15063, [Res, GoodsId, NewHole, NewRuneNum, NewCoin]) ->
    %io:format("write: ~p~n",[[15063, Res, GoodsId, NewHole, NewRuneNum, NewCoin]]),
    {ok, pt:pack(15063, <<Res:16, GoodsId:32, NewHole:16, NewRuneNum:16, NewCoin:32>>)};

%%宝石合成
write(15064, [Res, NewGoodsTypeId]) ->
    %io:format("write: ~p~n",[[15064, Res, NewGoodsTypeId]]),
    {ok, pt:pack(15064, <<Res:16, NewGoodsTypeId:32>>)};

%%宝石镶嵌
write(15065, [Res, GoodsId, NewCoin]) ->
    %io:format("write: ~p~n",[[15065, Res, GoodsId, NewCoin]]),
    {ok, pt:pack(15065, <<Res:16, GoodsId:32, NewCoin:32>>)};

%%宝石拆除
write(15066, [Res, GoodsId, NewCoin]) ->
    %io:format("write: ~p~n",[[15066, Res, GoodsId, NewCoin]]),
    {ok, pt:pack(15066, <<Res:16, GoodsId:32, NewCoin:32>>)};

%%洗附加属性
write(15067, [Res, GoodsId, NewRuneNum, NewCoin]) ->
    %io:format("write: ~p~n",[[15067, Res, GoodsId, NewRuneNum, NewCoin]]),
    {ok, pt:pack(15067, <<Res:16, GoodsId:32, NewRuneNum:16, NewCoin:32>>)};


write(_Cmd, _R) ->
    %io:format("write: ~p~n",[[_Cmd, _R]]),
    {ok, pt:pack(0, <<>>)}.

get_attribute_value(AttributeInfo) ->
    case AttributeInfo#goods_attribute.attribute_id of
        1 -> AttributeInfo#goods_attribute.hp;
        2 -> AttributeInfo#goods_attribute.mp;
        3 -> AttributeInfo#goods_attribute.att;
        4 -> AttributeInfo#goods_attribute.def;
        5 -> AttributeInfo#goods_attribute.hit;
        6 -> AttributeInfo#goods_attribute.dodge;
        7 -> AttributeInfo#goods_attribute.crit;
        8 -> AttributeInfo#goods_attribute.ten;
        _ -> 0
    end.
