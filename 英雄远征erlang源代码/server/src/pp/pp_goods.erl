%%%--------------------------------------
%%% @Module  : pp_goods
%%% @Author  : xhg
%%% @Email   : xuhuguang@jieyou.com
%%% @Created : 2010.05.25
%%% @Description:  物品操作
%%%--------------------------------------

-module(pp_goods).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").


%%查询物品详细信息
handle(15000, PlayerStatus, [GoodsId, Location]) ->
    [GoodsInfo, SuitNum, AttributeList] = gen_server:call(PlayerStatus#player_status.goods_pid, {'info', GoodsId, Location}),
    {ok, BinData} = pt_15:write_goods_info(15000, [GoodsInfo, SuitNum, AttributeList]),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%%查询别人物品详细信息
handle(15001, PlayerStatus, [Owner, GoodsId]) ->
    [GoodsInfo, SuitNum, AttributeList] = gen_server:call(PlayerStatus#player_status.goods_pid, {'info_other', Owner, GoodsId}),
    {ok, BinData} = pt_15:write_goods_info(15001, [GoodsInfo, SuitNum, AttributeList]),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%% 查看地上的掉落包
handle(15002, PlayerStatus, DropId) ->
    [Res, DropList] = gen_server:call(PlayerStatus#player_status.goods_pid, {'drop_list', PlayerStatus, DropId}),
    {ok, BinData} = pt_15:write(15002, [Res, DropId, DropList]),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%%查询玩家某个位置的物品列表
handle(15010, PlayerStatus, Location) ->
    [NewLocation, CellNum, GoodsList] = gen_server:call(PlayerStatus#player_status.goods_pid, {'list', PlayerStatus, Location}),
    {ok, BinData} = pt_15:write(15010, [NewLocation, CellNum, PlayerStatus#player_status.coin, PlayerStatus#player_status.silver, PlayerStatus#player_status.gold, GoodsList]),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%%查询别人身上装备列表
handle(15011, PlayerStatus, PlayerId) ->
    [Res, GoodsList] = gen_server:call(PlayerStatus#player_status.goods_pid, {'list_other', PlayerId}),
    {ok, BinData} = pt_15:write(15011, [Res, PlayerId, GoodsList]),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%%获取要修理装备列表
handle(15012, PlayerStatus, mend_list) ->
    MendList = gen_server:call(PlayerStatus#player_status.goods_pid, {'mend_list', PlayerStatus}),
    {ok, BinData} = pt_15:write(15012, MendList),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%% 取商店物品列表
handle(15013, PlayerStatus, [ShopType, ShopSubtype]) ->
    ShopList = gen_server:call(PlayerStatus#player_status.goods_pid, {'shop', ShopType, ShopSubtype}),
    {ok, BinData} = pt_15:write(15013, [ShopType, ShopSubtype, ShopList]),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%% 列出背包打造装备列表
handle(15014, PlayerStatus, make_list) ->
    EquipList = gen_server:call(PlayerStatus#player_status.goods_pid, {'make_list'}),
    {ok, BinData} = pt_15:write(15014, EquipList),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%%购买物品
handle(15020, PlayerStatus, [GoodsTypeId, GoodsNum, ShopType]) ->
    [NewPlayerStatus, Res, GoodsList] = gen_server:call(PlayerStatus#player_status.goods_pid, {'pay', PlayerStatus, GoodsTypeId, GoodsNum, ShopType}),
    {ok, BinData} = pt_15:write(15020, [Res, GoodsTypeId, GoodsNum, ShopType, NewPlayerStatus#player_status.coin, NewPlayerStatus#player_status.silver, NewPlayerStatus#player_status.gold, GoodsList]),
    lib_send:send_one(NewPlayerStatus#player_status.socket, BinData),
    {ok, NewPlayerStatus};

%%出售物品
handle(15021, PlayerStatus, [GoodsId, GoodsNum]) ->
    [NewPlayerStatus, Res] = gen_server:call(PlayerStatus#player_status.goods_pid, {'sell', PlayerStatus, GoodsId, GoodsNum}),
    {ok, BinData} = pt_15:write(15021, [Res, GoodsId, GoodsNum, NewPlayerStatus#player_status.coin]),
    lib_send:send_one(NewPlayerStatus#player_status.socket, BinData),
    {ok, NewPlayerStatus};

%%扩充背包
handle(15022, PlayerStatus, extend_bag) ->
    [NewPlayerStatus, Res] = gen_server:call(PlayerStatus#player_status.goods_pid, {'extend_bag', PlayerStatus}),
    {ok, BinData} = pt_15:write(15022, [Res, NewPlayerStatus#player_status.coin, NewPlayerStatus#player_status.cell_num]),
    lib_send:send_one(NewPlayerStatus#player_status.socket, BinData),
    {ok, NewPlayerStatus};

%%装备物品
handle(15030, PlayerStatus, [GoodsId, Cell]) ->
    [NewPlayerStatus, Res, GoodsInfo, OldGoodsInfo, Effect] = gen_server:call(PlayerStatus#player_status.goods_pid, {'equip', PlayerStatus, GoodsId, Cell}),
    case is_record(OldGoodsInfo, goods) of
         true ->
             OldGoodsId = OldGoodsInfo#goods.id,
             OldGoodsTypeId = OldGoodsInfo#goods.goods_id,
             OldGoodsCell = OldGoodsInfo#goods.cell;
         false ->
             OldGoodsId = 0,
             OldGoodsTypeId = 0,
             OldGoodsCell = 0
    end,
    {ok, BinData} = pt_15:write(15030, [Res, GoodsId, OldGoodsId, OldGoodsTypeId, OldGoodsCell, Effect]),
    lib_send:send_one(NewPlayerStatus#player_status.socket, BinData),
    lib_player:send_attribute_change_notify(NewPlayerStatus, 2),
    %% 气血有改变则广播
    case is_record(GoodsInfo, goods) of
        true when NewPlayerStatus#player_status.hp_lim =/= PlayerStatus#player_status.hp_lim
                    orelse GoodsInfo#goods.subtype =:= 10 
                    orelse GoodsInfo#goods.subtype =:= 21 ->
            {ok, BinData1} = pt_12:write(12012, [NewPlayerStatus#player_status.id, GoodsInfo#goods.goods_id, GoodsInfo#goods.subtype, NewPlayerStatus#player_status.hp, NewPlayerStatus#player_status.hp_lim]),
            lib_send:send_to_area_scene(NewPlayerStatus#player_status.scene, NewPlayerStatus#player_status.x, NewPlayerStatus#player_status.y, BinData1);
        _ ->
            void
    end,
    {ok, NewPlayerStatus};

%%卸下装备
handle(15031, PlayerStatus, GoodsId) ->
    [NewPlayerStatus, Res, GoodsInfo] = gen_server:call(PlayerStatus#player_status.goods_pid, {'unequip', PlayerStatus, GoodsId}),
    case is_record(GoodsInfo, goods) of
         true ->
             TypeId = GoodsInfo#goods.goods_id,
             Cell = GoodsInfo#goods.cell;
         false ->
             TypeId = 0,
             Cell = 0
    end,
    {ok, BinData} = pt_15:write(15031, [Res, GoodsId, TypeId, Cell]),
    lib_send:send_one(NewPlayerStatus#player_status.socket, BinData),
    lib_player:send_attribute_change_notify(NewPlayerStatus, 2),
    %% 气血有改变则广播
    case is_record(GoodsInfo, goods) of
        true when NewPlayerStatus#player_status.hp_lim =/= PlayerStatus#player_status.hp_lim
                    orelse GoodsInfo#goods.subtype =:= 10
                    orelse GoodsInfo#goods.subtype =:= 21 ->
            {ok, BinData1} = pt_12:write(12013, [PlayerStatus#player_status.id, GoodsInfo#goods.goods_id, GoodsInfo#goods.subtype, NewPlayerStatus#player_status.hp, NewPlayerStatus#player_status.hp_lim]),
            lib_send:send_to_area_scene(PlayerStatus#player_status.scene, PlayerStatus#player_status.x, PlayerStatus#player_status.y, BinData1);
        _ ->
            skip
    end,
    {ok, NewPlayerStatus};

%%修理装备
handle(15033, PlayerStatus, GoodsId) ->
    [NewPlayerStatus, Res, GoodsInfo] = gen_server:call(PlayerStatus#player_status.goods_pid, {'mend', PlayerStatus, GoodsId}),
    {ok, BinData} = pt_15:write(15033, [Res, GoodsId, NewPlayerStatus#player_status.coin]),
    lib_send:send_one(NewPlayerStatus#player_status.socket, BinData),
    %% 气血有改变则广播
    case is_record(GoodsInfo, goods) of
        true when NewPlayerStatus#player_status.hp_lim =/= PlayerStatus#player_status.hp_lim
                    orelse GoodsInfo#goods.subtype =:= 10
                    orelse GoodsInfo#goods.subtype =:= 21 ->
            {ok, BinData1} = pt_12:write(12012, [NewPlayerStatus#player_status.id, GoodsInfo#goods.goods_id, NewPlayerStatus#player_status.hp, NewPlayerStatus#player_status.hp_lim]),
            lib_send:send_to_area_scene(NewPlayerStatus#player_status.scene, NewPlayerStatus#player_status.x, NewPlayerStatus#player_status.y, BinData1);
        _ ->
            skip
    end,
    {ok, NewPlayerStatus};

%% 切换装备
handle(15034, PlayerStatus, Equip) ->
    [NewPlayerStatus, Res, EquipList] = gen_server:call(PlayerStatus#player_status.goods_pid, {'change_equip', PlayerStatus, Equip}),
    {ok, BinData} = pt_15:write(15034, [Res, Equip, EquipList]),
    lib_send:send_one(NewPlayerStatus#player_status.socket, BinData),
    lib_player:send_attribute_change_notify(NewPlayerStatus, 2),
    %% 广播
    {ok, BinData1} = pt_12:write(12016, [NewPlayerStatus#player_status.id, NewPlayerStatus#player_status.hp, NewPlayerStatus#player_status.hp_lim, EquipList]),
    lib_send:send_to_area_scene(NewPlayerStatus#player_status.scene, NewPlayerStatus#player_status.x, NewPlayerStatus#player_status.y, BinData1),
    {ok, NewPlayerStatus};

%%拖动背包物品
handle(15040, PlayerStatus, [GoodsId, OldCell, NewCell]) ->
    [Res, OldCellId, OldTypeId, NewCellId, NewTypeId] = gen_server:call(PlayerStatus#player_status.goods_pid, {'drag', PlayerStatus, GoodsId, OldCell, NewCell}),
    {ok, BinData} = pt_15:write(15040, [Res, OldCellId, OldTypeId, OldCell, NewCellId, NewTypeId, NewCell]),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%%物品存入仓库
handle(15041, PlayerStatus, [GoodsId, GoodsNum]) ->
    Res = gen_server:call(PlayerStatus#player_status.goods_pid, {'movein_bag', GoodsId, GoodsNum}),
    {ok, BinData} = pt_15:write(15041, [Res, GoodsId, GoodsNum]),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%%从仓库取出物品
handle(15042, PlayerStatus, [GoodsId, GoodsNum]) ->
    [Res, GoodsList] = gen_server:call(PlayerStatus#player_status.goods_pid, {'moveout_bag', GoodsId, GoodsNum}),
    {ok, BinData} = pt_15:write(15042, [Res, GoodsId, GoodsList]),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%%使用物品
handle(15050, PlayerStatus, [GoodsId, GoodsNum]) ->
    [NewPlayerStatus, Res, GoodsTypeId, NewNum] = gen_server:call(PlayerStatus#player_status.goods_pid, {'use', PlayerStatus, GoodsId, GoodsNum}),
    {ok, BinData} = pt_15:write(15050, [Res, GoodsId, GoodsTypeId, NewNum, [NewPlayerStatus#player_status.hp, NewPlayerStatus#player_status.mp]]),
    lib_send:send_one(NewPlayerStatus#player_status.socket, BinData),
    {ok, NewPlayerStatus};

%%丢弃物品
handle(15051, PlayerStatus, [GoodsId, GoodsNum]) ->
    Res = gen_server:call(PlayerStatus#player_status.goods_pid, {'throw', GoodsId, GoodsNum}),
    {ok, BinData} = pt_15:write(15051, [Res, GoodsId, GoodsNum]),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%% 整理背包
handle(15052, PlayerStatus, clean) ->
    GoodsList = gen_server:call(PlayerStatus#player_status.goods_pid, {'clean', PlayerStatus}),
    {ok, BinData} = pt_15:write(15052, GoodsList),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%% 拣取地上掉落包的物品
handle(15053, PlayerStatus, [DropId, GoodsTypeId]) ->
    Res = gen_server:call(PlayerStatus#player_status.goods_pid, {'drop_choose', PlayerStatus, DropId, GoodsTypeId}),
    {ok, BinData} = pt_15:write(15053, [Res, DropId, GoodsTypeId]),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData),
    %% 广播
    case Res =:= 1 of
        true -> lib_player:refresh_client(PlayerStatus#player_status.id, 2);
        false -> void
    end;

%% 装备品质升级
handle(15060, PlayerStatus, [GoodsId, StoneId]) ->
    [NewPlayerStatus, Res, NewQuality, NewStoneNum] = gen_server:call(PlayerStatus#player_status.goods_pid, {'quality_upgrade', PlayerStatus, GoodsId, StoneId}),
    {ok, BinData} = pt_15:write(15060, [Res, GoodsId, NewQuality, NewStoneNum, NewPlayerStatus#player_status.coin]),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData),
    {ok, NewPlayerStatus};

%% 装备品质石拆除
handle(15061, PlayerStatus, GoodsId) ->
    [NewPlayerStatus, Res] = gen_server:call(PlayerStatus#player_status.goods_pid, {'quality_backout', PlayerStatus, GoodsId}),
    {ok, BinData} = pt_15:write(15061, [Res, GoodsId, NewPlayerStatus#player_status.coin]),
    lib_send:send_one(NewPlayerStatus#player_status.socket, BinData),
    {ok, NewPlayerStatus};

%% 装备强化
handle(15062, PlayerStatus, [GoodsId, StoneId, RuneId]) ->
    [NewPlayerStatus, Res, NewStrengthen, NewStoneNum, NewRuneNum] = gen_server:call(PlayerStatus#player_status.goods_pid, {'strengthen', PlayerStatus, GoodsId, StoneId, RuneId}),
    {ok, BinData} = pt_15:write(15062, [Res, GoodsId, NewStrengthen, NewStoneNum, NewRuneNum, NewPlayerStatus#player_status.coin]),
    lib_send:send_one(NewPlayerStatus#player_status.socket, BinData),
    {ok, NewPlayerStatus};

%% 装备打孔
handle(15063, PlayerStatus, [GoodsId, RuneId]) ->
    [NewPlayerStatus, Res, NewHole, NewRuneNum] = gen_server:call(PlayerStatus#player_status.goods_pid, {'hole', PlayerStatus, GoodsId, RuneId}),
    {ok, BinData} = pt_15:write(15063, [Res, GoodsId, NewHole, NewRuneNum, NewPlayerStatus#player_status.coin]),
    lib_send:send_one(NewPlayerStatus#player_status.socket, BinData),
    {ok, NewPlayerStatus};

%% 宝石合成
handle(15064, PlayerStatus, [RuneId, StoneTypeId, StoneList]) ->
    [NewPlayerStatus, Res, NewGoodsTypeId] = gen_server:call(PlayerStatus#player_status.goods_pid, {'compose', PlayerStatus, RuneId, StoneTypeId, StoneList}),
    {ok, BinData} = pt_15:write(15064, [Res, NewGoodsTypeId]),
    lib_send:send_one(NewPlayerStatus#player_status.socket, BinData),
    {ok, NewPlayerStatus};

%% 宝石镶嵌
handle(15065, PlayerStatus, [GoodsId, StoneId, RuneList]) ->
    [NewPlayerStatus, Res] = gen_server:call(PlayerStatus#player_status.goods_pid, {'inlay', PlayerStatus, GoodsId, StoneId, RuneList}),
    {ok, BinData} = pt_15:write(15065, [Res, GoodsId, NewPlayerStatus#player_status.coin]),
    lib_send:send_one(NewPlayerStatus#player_status.socket, BinData),
    {ok, NewPlayerStatus};

%% 宝石拆除
handle(15066, PlayerStatus, [GoodsId, RuneId]) ->
    [NewPlayerStatus, Res] = gen_server:call(PlayerStatus#player_status.goods_pid, {'backout', PlayerStatus, GoodsId, RuneId}),
    {ok, BinData} = pt_15:write(15066, [Res, GoodsId, NewPlayerStatus#player_status.coin]),
    lib_send:send_one(NewPlayerStatus#player_status.socket, BinData),
    {ok, NewPlayerStatus};

%% 洗附加属性
handle(15067, PlayerStatus, [GoodsId, RuneId]) ->
    [NewPlayerStatus, Res, NewRuneNum] = gen_server:call(PlayerStatus#player_status.goods_pid, {'wash', PlayerStatus, GoodsId, RuneId}),
    {ok, BinData} = pt_15:write(15067, [Res, GoodsId, NewRuneNum, NewPlayerStatus#player_status.coin]),
    lib_send:send_one(NewPlayerStatus#player_status.socket, BinData),
    {ok, NewPlayerStatus};

handle(_Cmd, _Status, _Data) ->
    ?DEBUG("pp_goods no match", []),
    {error, "pp_goods no match"}.
