%%%------------------------------------
%%% @Module  : mod_goods
%%% @Author  : xhg
%%% @Email   : xuhuguang@jieyou.com
%%% @Created : 2010.05.25
%%% @Description: 物品模块
%%%------------------------------------
-module(mod_goods).
-behaviour(gen_server).
-export([start/3]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-include("common.hrl").
-include("record.hrl").

start(PlayerId,CellNum, Equip) ->
    gen_server:start_link(?MODULE, [PlayerId,CellNum, Equip], []).

init([PlayerId,CellNum, Equip]) ->
    ok = goods_util:init_goods_online(PlayerId),
    NullCells = goods_util:get_null_cells(PlayerId, CellNum),
    EquipSuit = goods_util:get_equip_suit(PlayerId, Equip),
    GoodsStatus = #goods_status{ player_id = PlayerId, null_cells = NullCells, equip_current = [0,0,0], equip_suit=EquipSuit },
    NewStatus = goods_util:get_current_equip(GoodsStatus, Equip),
    %io:format("equip_current: ~p~n",[NewStatus#goods_status.equip_current]),
    {ok, NewStatus}.

%%设置物品信息
handle_cast({'SET_STATUS', NewStatus}, _GoodsStatus) ->
    {noreply, NewStatus};

handle_cast(_R , GoodsStatus) ->
    {noreply, GoodsStatus}.


handle_call({'STATUS'} , _From, GoodsStatus) ->
    {reply, GoodsStatus, GoodsStatus};

%%设置物品信息
handle_call({'SET_STATUS', NewGoodsStatus}, _From, _GoodsStatus) ->
    {reply, ok, NewGoodsStatus};

%%获取物品详细信息
handle_call({'info', GoodsId, Location}, _From, GoodsStatus) ->
    case Location =:= 5 of
        true -> GoodsInfo = goods_util:get_goods_by_id(GoodsId);
        false -> GoodsInfo = goods_util:get_goods(GoodsId)
    end,
    case is_record(GoodsInfo, goods) of
        true when GoodsInfo#goods.player_id == GoodsStatus#goods_status.player_id ->
            case goods_util:has_attribute(GoodsInfo) of
                true -> AttributeList = goods_util:get_goods_attribute_list(GoodsStatus#goods_status.player_id, GoodsId);
                false -> AttributeList = []
            end,
            SuitNum = goods_util:get_suit_num(GoodsStatus#goods_status.equip_suit, GoodsInfo#goods.suit_id),
            {reply, [GoodsInfo, SuitNum, AttributeList], GoodsStatus};
        Error ->
            ?DEBUG("mod_goods info:~p", [[GoodsId,Error]]),
            {reply, [{}, 0, []], GoodsStatus}
    end;

%%查询别人物品详细信息
handle_call({'info_other', Owner, GoodsId}, _From, GoodsStatus) ->
    Info = goods_util:get_goods(GoodsId),
    case is_record(Info, goods) of
        true -> GoodsInfo = Info;
        false -> GoodsInfo = goods_util:get_goods_by_id(GoodsId)
    end,
    case is_record(GoodsInfo, goods) of
        true ->
            IsOnline = lib_player:is_online(Owner),
            case goods_util:has_attribute(GoodsInfo) of
                true when IsOnline =:= true -> AttributeList = goods_util:get_goods_attribute_list(Owner, GoodsId);
                true -> AttributeList = goods_util:get_offline_goods_attribute_list(Owner, GoodsId);
                false -> AttributeList = []
            end,
            SuitNum = goods_util:get_suit_num(GoodsStatus#goods_status.equip_suit, GoodsInfo#goods.suit_id),
            {reply, [GoodsInfo, SuitNum, AttributeList], GoodsStatus};
        Error ->
            ?DEBUG("mod_goods info_other:~p", [[Owner, GoodsId, Error]]),
            {reply, [{}, 0, []], GoodsStatus}
    end;

%% 获取玩家物品列表信息
handle_call({'list', PlayerStatus, Location}, _From, GoodsStatus) ->
    case Location > 0 of
        %% 装备
        true when Location =< 3 ->
            NewLocation = Location,
            CellNum = 12,
            EquipList = goods_util:get_equip_list(PlayerStatus#player_status.id, 10, NewLocation),
            MountList = goods_util:get_equip_list(PlayerStatus#player_status.id, 31, 1),
            List = EquipList ++ MountList;
        true ->
            NewLocation = Location,
            case Location =:= 5 of
                true -> CellNum = 245;  %% 仓库
                false -> CellNum = PlayerStatus#player_status.cell_num
            end,
            List = goods_util:get_goods_list(PlayerStatus#player_status.id, NewLocation);
        %% 当前装备
        false ->
            NewLocation = PlayerStatus#player_status.equip,
            CellNum = 12,
            EquipList = goods_util:get_equip_list(PlayerStatus#player_status.id, 10, NewLocation),
            MountList = goods_util:get_equip_list(PlayerStatus#player_status.id, 31, 1),
            List = EquipList ++ MountList
    end,
    {reply, [NewLocation, CellNum, List], GoodsStatus};

%% 获取玩家物品列表信息
handle_call({'list_other', PlayerId}, _From, GoodsStatus) ->
    %io:format("list_other: ~p~n",[[PlayerId, lib_player:is_online(PlayerId), ets:info(?ETS_ONLINE,size)]]),
    case lib_player:is_online(PlayerId) of
        %% 玩家不在线
        false ->
            {reply, [2, []], GoodsStatus};
        true ->
            Player = lib_player:get_online_info(PlayerId),
            EquipList = goods_util:get_equip_list(PlayerId, 10, Player#ets_online.equip),
            MountList = goods_util:get_equip_list(PlayerId, 31, 1),
            List = EquipList ++ MountList,
            {reply, [1, List], GoodsStatus}
    end;

%% 列出背包打造装备列表
handle_call({'make_list'}, _From, GoodsStatus) ->
    EquipList = goods_util:get_equip_list(GoodsStatus#goods_status.player_id, 10, 4),
    {reply, EquipList, GoodsStatus};

%% 取商店物品列表
handle_call({'shop', ShopType, ShopSubtype}, _From, GoodsStatus) ->
    ShopList = goods_util:get_shop_list(ShopType, ShopSubtype),
    {reply, ShopList, GoodsStatus};

%%购买物品
handle_call({'pay', PlayerStatus, GoodsTypeId, GoodsNum, ShopType}, _From, GoodsStatus) ->
    case check_pay(PlayerStatus, GoodsStatus, GoodsTypeId, GoodsNum, ShopType) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res, []], GoodsStatus};
        {ok, GoodsTypeInfo, GoodsList, Cost, PriceType} ->
            case (catch lib_goods:pay_goods(GoodsStatus, GoodsTypeInfo, GoodsList, GoodsNum)) of
                {ok, NewStatus} ->
                    NewPlayerStatus = lib_goods:cost_money(PlayerStatus, Cost, PriceType),
                    NewGoodsList = goods_util:get_type_goods_list(PlayerStatus#player_status.id, GoodsTypeId, GoodsTypeInfo#ets_goods_type.bind, 4),
                    lib_task:event(buy_equip, {GoodsTypeId}, PlayerStatus#player_status.id),
                    {reply, [NewPlayerStatus, 1, NewGoodsList], NewStatus};
                Error ->
                    ?DEBUG("mod_goods pay:~p", [Error]),
                    {reply, [PlayerStatus, 0, []], GoodsStatus}
            end
    end;

%%出售物品
handle_call({'sell', PlayerStatus, GoodsId, GoodsNum}, _From, GoodsStatus) ->
    case check_sell(GoodsStatus, GoodsId, GoodsNum) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res], GoodsStatus};
        {ok, GoodsInfo} ->
            case (catch lib_goods:sell_goods(PlayerStatus, GoodsStatus, GoodsInfo, GoodsNum)) of
                {ok, NewPlayerStatus, NewStatus} ->
                    {reply, [NewPlayerStatus, 1], NewStatus};
                Error ->
                    ?DEBUG("mod_goods sell:~p", [Error]),
                    {reply, [PlayerStatus, 0], GoodsStatus}
            end
    end;

%%装备物品
handle_call({'equip', PlayerStatus, GoodsId, Cell}, _From, GoodsStatus) ->
    case check_equip(PlayerStatus, GoodsId, Cell) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res, {}, {}, []], GoodsStatus};
        {ok, GoodsInfo, Location, NewCell} ->
            case (catch lib_goods:equip_goods(PlayerStatus, GoodsStatus, GoodsInfo, Location, NewCell)) of
                {ok, NewPlayerStatus, NewStatus, OldGoodsInfo, Effect2} ->
                    lib_task:event(equip, {GoodsInfo#goods.goods_id}, GoodsInfo#goods.player_id),
                    {reply, [NewPlayerStatus, 1, GoodsInfo, OldGoodsInfo, Effect2], NewStatus};
                 Error ->
                     ?DEBUG("mod_goods equip:~p", [Error]),
                     {reply, [PlayerStatus, 0, {}, []], GoodsStatus}
            end
    end;

%%卸下装备
handle_call({'unequip', PlayerStatus, GoodsId}, _From, GoodsStatus) ->
    case check_unequip(GoodsStatus, GoodsId, PlayerStatus#player_status.equip) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res, {}], GoodsStatus};
        {ok, GoodsInfo} ->
            case (catch lib_goods:unequip_goods(PlayerStatus, GoodsStatus, GoodsInfo)) of
                {ok, NewPlayerStatus, NewStatus, NewGoodsInfo} ->
                     {reply, [NewPlayerStatus, 1, NewGoodsInfo], NewStatus};
                 Error ->
                     ?DEBUG("mod_goods unequip:~p", [Error]),
                     {reply, [PlayerStatus, 0, {}], GoodsStatus}
            end
    end;

%%背包拖动物品
handle_call({'drag', PlayerStatus, GoodsId, OldCell, NewCell}, _From, GoodsStatus) ->
    case check_drag(GoodsStatus, GoodsId, OldCell, NewCell, PlayerStatus#player_status.cell_num) of
        {fail, Res} ->
            {reply, [Res, 0, 0, 0, 0], GoodsStatus};
        {ok, GoodsInfo} ->
            case (catch lib_goods:drag_goods(GoodsStatus, GoodsInfo, OldCell, NewCell)) of
                {ok, NewStatus, [OldCellId, OldTypeId, NewCellId, NewTypeId]} ->
                    {reply, [1, OldCellId, OldTypeId, NewCellId, NewTypeId], NewStatus};
                Error ->
                    ?DEBUG("mod_goods drag:~p", [Error]),
                    {reply, [0, 0, 0, 0, 0], GoodsStatus}
            end
    end;

%%使用物品
handle_call({'use', PlayerStatus, GoodsId, GoodsNum}, _From, GoodsStatus) ->
    case check_use(GoodsStatus, GoodsId, GoodsNum, PlayerStatus#player_status.lv) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res, 0, 0], GoodsStatus};
        {ok, GoodsInfo} ->
            case (catch lib_goods:use_goods(PlayerStatus, GoodsStatus, GoodsInfo, GoodsNum)) of
                {ok, NewPlayerStatus, NewStatus, NewNum} ->
                     {reply, [NewPlayerStatus, 1, GoodsInfo#goods.goods_id, NewNum], NewStatus};
                 Error ->
                     ?DEBUG("mod_goods use:~p", [Error]),
                     {reply, [PlayerStatus, 0, 0, 0], GoodsStatus}
            end
    end;

%%删除多个物品
handle_call({'delete_one', GoodsId, GoodsNum}, _From, GoodsStatus) ->
    GoodsInfo = goods_util:get_goods(GoodsId),
    if
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false ->
            {reply, [2, 0], GoodsStatus};
        %% 物品数量不正确
        GoodsInfo#goods.num < GoodsNum ->
            {reply, [3, 0], GoodsStatus};
        true ->
            case (catch lib_goods:delete_one(GoodsStatus, GoodsInfo, GoodsNum)) of
                {ok, NewStatus, NewNum} ->
                     lib_player:refresh_client(GoodsStatus#goods_status.player_id, 2),
                     {reply, [1, NewNum], NewStatus};
                 Error ->
                     ?DEBUG("mod_goods delete_one:~p", [Error]),
                     {reply, [0, 0], GoodsStatus}
            end
    end;

%%删除多个同类型物品
handle_call({'delete_more', GoodsTypeId, GoodsNum}, _From, GoodsStatus) ->
    GoodsList = goods_util:get_type_goods_list(GoodsStatus#goods_status.player_id, GoodsTypeId, 4),
    TotalNum = goods_util:get_goods_totalnum(GoodsList),
    if 
        %% 物品不存在
        length(GoodsList) =:= 0 ->
            {reply, 2, GoodsStatus};
        %% 物品数量不足
        TotalNum < GoodsNum ->
            {reply, 3, GoodsStatus};
        true ->
            case (catch lib_goods:delete_more(GoodsStatus, GoodsList, GoodsNum)) of
                {ok, NewStatus} ->
                     lib_player:refresh_client(GoodsStatus#goods_status.player_id, 2),
                     {reply, 1, NewStatus};
                 Error ->
                     ?DEBUG("mod_goods delete_more:~p", [Error]),
                     {reply, 0, GoodsStatus}
            end
    end;

%%丢弃物品
handle_call({'throw', GoodsId, GoodsNum}, _From, GoodsStatus) ->
    case check_throw(GoodsStatus, GoodsId, GoodsNum) of
        {fail, Res} ->
            {reply, Res, GoodsStatus};
        {ok, GoodsInfo} ->
            case (catch lib_goods:delete_one(GoodsStatus, GoodsInfo, GoodsNum)) of
                {ok, NewStatus, _} ->
                    {reply, 1, NewStatus};
                Error ->
                    ?DEBUG("mod_goods throw:~p", [Error]),
                    {reply, 0, GoodsStatus}
            end
    end;

%%丢弃同类型物品
%% GoodsTypeList = [GoodsTypeId1, GoodsTypeId2, ...]
handle_call({'throw_more', GoodsTypeList}, _From, GoodsStatus) ->
    case (catch goods_util:list_handle(fun lib_goods:delete_type_goods/2, GoodsStatus, GoodsTypeList)) of
        {ok, NewStatus} ->
            lib_player:refresh_client(NewStatus#goods_status.player_id, 2),
            {reply, ok, NewStatus};
         {Error, Status} ->
             ?DEBUG("mod_goods throw_more:~p", [Error]),
             {reply, Error, Status}
    end;

%%物品存入仓库
handle_call({'movein_bag', GoodsId, GoodsNum}, _From, GoodsStatus) ->
    case check_movein_bag(GoodsStatus, GoodsId, GoodsNum) of
        {fail, Res} ->
            {reply, Res, GoodsStatus};
        {ok, GoodsInfo, GoodsTypeInfo} ->
            case (catch lib_goods:movein_bag(GoodsStatus, GoodsInfo, GoodsNum, GoodsTypeInfo)) of
                {ok, NewStatus} ->
                    {reply, 1, NewStatus};
                Error ->
                    ?DEBUG("mod_goods movein_bag:~p", [Error]),
                    {reply, 0, GoodsStatus}
            end
    end;

%%从仓库取出物品
handle_call({'moveout_bag', GoodsId, GoodsNum}, _From, GoodsStatus) ->
    case check_moveout_bag(GoodsStatus, GoodsId, GoodsNum) of
        {fail, Res} ->
            {reply, [Res, []], GoodsStatus};
        {ok, GoodsInfo, GoodsTypeInfo} ->
            case (catch lib_goods:moveout_bag(GoodsStatus, GoodsInfo, GoodsNum, GoodsTypeInfo)) of
                {ok, NewStatus} ->
                    GoodsList = goods_util:get_type_goods_list(GoodsInfo#goods.player_id, GoodsInfo#goods.goods_id, GoodsInfo#goods.bind, 4),
                    {reply, [1, GoodsList], NewStatus};
                Error ->
                    ?DEBUG("mod_goods moveout_bag:~p", [Error]),
                    {reply, [0, []], GoodsStatus}
            end
    end;

%%扩充背包
handle_call({'extend_bag', PlayerStatus}, _From, GoodsStatus) ->
    case check_extend_bag(PlayerStatus) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res], GoodsStatus};
        {ok, Cost} ->
            case (catch lib_goods:extend_bag(PlayerStatus, Cost)) of
                {ok, NewPlayerStatus} ->
                    {reply, [NewPlayerStatus, 1], GoodsStatus};
                Error ->
                    ?DEBUG("mod_goods extend_bag:~p", [Error]),
                    {reply, [PlayerStatus, 0], GoodsStatus}
            end
    end;

%%装备磨损
handle_call({'attrit', PlayerStatus, UseNum}, _From, GoodsStatus) ->
    %% 查找身上耐久为1的装备
    %Sql = io_lib:format(<<"select id,subtype from `goods` where player_id = ~p and location = ~p and type = 10 and use_num <= ~p and use_num > 0 and attrition > 0 ">>, [PlayerStatus#player_status.id, PlayerStatus#player_status.equip, UseNum]),
    %List = goods_util:get_list(goods, Sql),
    %% 穿在身上的装备耐久减1
    Sql2 = io_lib:format(<<"update `goods` set use_num = use_num - (~p) where player_id = ~p and location = ~p and type = 10 and use_num > ~p and attrition > 0 ">>, [UseNum, PlayerStatus#player_status.id, PlayerStatus#player_status.equip, UseNum]),
    db_sql:execute(Sql2),
    Sql3 = io_lib:format(<<"update `goods` set use_num = 0 where player_id = ~p and location = ~p and type = 10 and use_num <= ~p and use_num > 0 and attrition > 0 ">>, [PlayerStatus#player_status.id, PlayerStatus#player_status.equip, UseNum]),
    db_sql:execute(Sql3),
    EquipList = goods_util:get_equip_list(PlayerStatus#player_status.id, 10, PlayerStatus#player_status.equip),
    [_, ZeroEquipList] = lists:foldl(fun lib_goods:attrit_equip/2, [UseNum, []], EquipList),
    %%广播耐久更新
    lib_player:refresh_client(PlayerStatus#player_status.id, 5),
    %% 人物属性更新
    case length(ZeroEquipList) > 0 of
        %% 有耐久为0的装备
        true ->
            %% 人物属性重新计算
            EquipSuit = goods_util:get_equip_suit(PlayerStatus#player_status.id, PlayerStatus#player_status.equip),
            Status = GoodsStatus#goods_status{ equip_suit=EquipSuit },
            {ok, NewPlayerStatus, NewStatus} = goods_util:count_role_equip_attribute(PlayerStatus, Status, {}),
            %% 检查武器、衣服
            [NewStatus2, _] = goods_util:get_current_equip_by_list(ZeroEquipList, [NewStatus, off]),
            NewPlayerStatus2 = NewPlayerStatus#player_status{ equip_attrit=0, equip_current=NewStatus2#goods_status.equip_current },
            %% 广播
            {ok, BinData} = pt_12:write(12015, [NewPlayerStatus#player_status.id, NewPlayerStatus#player_status.hp, NewPlayerStatus#player_status.hp_lim, ZeroEquipList]),
            lib_send:send_to_area_scene(NewPlayerStatus#player_status.scene, NewPlayerStatus#player_status.x, NewPlayerStatus#player_status.y, BinData),
            %% 通知客户端
            {ok, BinData1} = pt_15:write(15032, ZeroEquipList),
            lib_send:send_one(NewPlayerStatus#player_status.socket, BinData1),
            %% 返回更新人物属性
            {reply, {ok, NewPlayerStatus2}, NewStatus2};
       false ->
           {reply, {error,no,attrition,equip}, GoodsStatus}
    end;

%%获取要修理装备列表
handle_call({'mend_list', PlayerStatus}, _From, GoodsStatus) ->
    %% 查找有耐久度的装备
    List = goods_util:get_mend_list(GoodsStatus#goods_status.player_id, PlayerStatus#player_status.equip),
    F = fun(GoodsInfo) ->
            UseNum = goods_util:get_goods_use_num(GoodsInfo#goods.attrition),
            case UseNum =/= GoodsInfo#goods.use_num of
                true ->
                    Attrition = goods_util:get_goods_attrition(GoodsInfo#goods.attrition, GoodsInfo#goods.use_num),
                    Cost = goods_util:get_mend_cost(GoodsInfo#goods.attrition, GoodsInfo#goods.use_num),
                    [[GoodsInfo#goods.id, GoodsInfo#goods.goods_id, Attrition, Cost]];
                false ->
                    []
            end
        end,
    MendList = lists:flatmap(F, List),
    {reply, MendList, GoodsStatus};

%%修理装备
handle_call({'mend', PlayerStatus, GoodsId}, _From, GoodsStatus) ->
    case check_mend(PlayerStatus, GoodsId) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res, {}], GoodsStatus};
        {ok, GoodsInfo} ->
            case (catch lib_goods:mend_goods(PlayerStatus, GoodsStatus, GoodsInfo)) of
                {ok, NewPlayerStatus, NewStatus} ->
                    {reply, [NewPlayerStatus, 1, GoodsInfo], NewStatus};
                 Error ->
                     ?DEBUG("mod_goods mend:~p", [Error]),
                     {reply, [PlayerStatus, 0, {}], GoodsStatus}
            end
    end;

%% 装备品质升级
handle_call({'quality_upgrade', PlayerStatus, GoodsId, StoneId}, _From, GoodsStatus) ->
    case check_quality_upgrade(PlayerStatus, GoodsId, StoneId) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res, 0, 0], GoodsStatus};
        {ok, GoodsInfo, StoneInfo, GoodsQualityRule} ->
            case (catch lib_make:quality_upgrade(PlayerStatus, GoodsStatus, GoodsInfo, StoneInfo, GoodsQualityRule)) of
                {ok, NewPlayerStatus, NewStatus, [NewQuality, NewStoneNum]} ->
                     {reply, [NewPlayerStatus, 1, NewQuality, NewStoneNum], NewStatus};
                 Error ->
                     ?DEBUG("mod_goods quality_upgrade:~p", [Error]),
                     {reply, [PlayerStatus, 0, 0, 0], GoodsStatus}
            end
    end;

%% 装备品质石拆除
handle_call({'quality_backout', PlayerStatus, GoodsId}, _From, GoodsStatus) ->
    case check_quality_backout(GoodsStatus, GoodsId) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res], GoodsStatus};
        {ok, GoodsInfo, GoodsBackoutRuleList} ->
            case (catch lib_make:quality_backout(PlayerStatus, GoodsStatus, GoodsInfo, GoodsBackoutRuleList)) of
                {ok, NewPlayerStatus, NewStatus} ->
                    {reply, [NewPlayerStatus, 1], NewStatus};
                {fail, Res} ->
                    {reply, [PlayerStatus, Res], GoodsStatus};
                Error ->
                    ?DEBUG("mod_goods quality_backout:~p", [Error]),
                    {reply, [PlayerStatus, 0], GoodsStatus}
            end
    end;

%% 装备强化
handle_call({'strengthen', PlayerStatus, GoodsId, StoneId, RuneId}, _From, GoodsStatus) ->
    case check_strengthen(PlayerStatus, GoodsId, StoneId, RuneId) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res, 0, 0, 0], GoodsStatus};
        {ok, GoodsInfo, StoneInfo, RuneInfo, GoodsStrengthenRule} ->
            case (catch lib_make:strengthen(PlayerStatus, GoodsStatus, GoodsInfo, StoneInfo, RuneInfo, GoodsStrengthenRule)) of
                {ok, NewPlayerStatus, NewStatus, [NewStrengthen, NewStoneNum, NewRuneNum]} ->
                     {reply, [NewPlayerStatus, 1, NewStrengthen, NewStoneNum, NewRuneNum], NewStatus};
                 Error ->
                     ?DEBUG("mod_goods strengthen:~p", [Error]),
                     {reply, [PlayerStatus, 0, 0, 0, 0], GoodsStatus}
            end
    end;

%% 装备打孔
handle_call({'hole', PlayerStatus, GoodsId, RuneId}, _From, GoodsStatus) ->
    case check_hole(PlayerStatus, GoodsId, RuneId) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res, 0, 0], GoodsStatus};
        {ok, GoodsInfo, RuneInfo} ->
            case (catch lib_make:hole(PlayerStatus, GoodsStatus, GoodsInfo, RuneInfo)) of
                {ok, NewPlayerStatus, NewStatus, [NewHole, NewRuneNum]} ->
                     {reply, [NewPlayerStatus, 1, NewHole, NewRuneNum], NewStatus};
                 Error ->
                     ?DEBUG("mod_goods hole:~p", [Error]),
                     {reply, [PlayerStatus, 0, 0, 0], GoodsStatus}
            end
    end;

%% 宝石合成
handle_call({'compose', PlayerStatus, RuneId, StoneTypeId, StoneList}, _From, GoodsStatus) ->
    case check_compose(PlayerStatus, GoodsStatus, RuneId, StoneTypeId, StoneList) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res, 0], GoodsStatus};
        {ok, NewStoneList, RuneInfo, GoodsComposeRule} ->
            case (catch lib_make:compose(PlayerStatus, GoodsStatus, NewStoneList, RuneInfo, GoodsComposeRule)) of
                {ok, NewPlayerStatus, NewStatus, NewGoodsTypeId} ->
                     {reply, [NewPlayerStatus, 1, NewGoodsTypeId], NewStatus};
                 Error ->
                     ?DEBUG("mod_goods compose:~p", [Error]),
                     {reply, [PlayerStatus, 0, 0], GoodsStatus}
            end
    end;

%% 宝石镶嵌
handle_call({'inlay', PlayerStatus, GoodsId, StoneId, RuneList}, _From, GoodsStatus) ->
    case check_inlay(PlayerStatus, GoodsId, StoneId, RuneList) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res], GoodsStatus};
        {ok, GoodsInfo, StoneInfo, TotalRuneNum, NewRuneList, GoodsInlayRule} ->
            case (catch lib_make:inlay(PlayerStatus, GoodsStatus, GoodsInfo, StoneInfo, TotalRuneNum, NewRuneList, GoodsInlayRule)) of
                {ok, Res, NewPlayerStatus, NewStatus} ->
                     {reply, [NewPlayerStatus, Res], NewStatus};
                 Error ->
                     ?DEBUG("mod_goods inlay:~p", [Error]),
                     {reply, [PlayerStatus, 10], GoodsStatus}
            end
    end;

%% 宝石拆除
handle_call({'backout', PlayerStatus, GoodsId, RuneId}, _From, GoodsStatus) ->
    case check_backout(PlayerStatus, GoodsStatus, GoodsId, RuneId) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res], GoodsStatus};
        {ok, GoodsInfo, RuneInfo} ->
            case (catch lib_make:backout(PlayerStatus, GoodsStatus, GoodsInfo, RuneInfo)) of
                {ok, NewPlayerStatus, NewStatus} ->
                     {reply, [NewPlayerStatus, 1], NewStatus};
                 Error ->
                     ?DEBUG("mod_goods backout:~p", [Error]),
                     {reply, [PlayerStatus, 0], GoodsStatus}
            end
    end;

%% 洗附加属性
handle_call({'wash', PlayerStatus, GoodsId, RuneId}, _From, GoodsStatus) ->
    case check_wash(PlayerStatus, GoodsId, RuneId) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res, 0], GoodsStatus};
        {ok, GoodsInfo, RuneInfo, AddAttributeRuleList} ->
            case (catch lib_make:wash(PlayerStatus, GoodsStatus, GoodsInfo, RuneInfo, AddAttributeRuleList)) of
                {ok, NewPlayerStatus, NewStatus, NewRuneNum} ->
                     {reply, [NewPlayerStatus, 1, NewRuneNum], NewStatus};
                 Error ->
                     ?DEBUG("mod_goods wash:~p", [Error]),
                     {reply, [PlayerStatus, 0, 0], GoodsStatus}
            end
    end;

%% 切换装备
handle_call({'change_equip', PlayerStatus, Equip}, _From, GoodsStatus) ->
    case check_change_equip(PlayerStatus, Equip) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res, []], GoodsStatus};
        ok ->
            case (catch lib_goods:change_equip(PlayerStatus, GoodsStatus, Equip)) of
                {ok, NewPlayerStatus, NewStatus, EquipList} ->
                    {reply, [NewPlayerStatus, 1, EquipList], NewStatus};
                Error ->
                    ?DEBUG("mod_goods change_equip:~p", [Error]),
                    {reply, [PlayerStatus, 0, []], GoodsStatus}
            end
    end;

%% 整理背包
handle_call({'clean', PlayerStatus}, _From, GoodsStatus) ->
    %% 查询背包物品列表
    GoodsList = goods_util:get_goods_list(GoodsStatus#goods_status.player_id, 4),
    %% 按物品类型ID排序
    GoodsList1 = goods_util:sort(GoodsList, goods_id),
    %% 整理
    [Num, _] = lists:foldl(fun lib_goods:clean_bag/2, [1, {}], GoodsList1),
    %% 重新计算
    NewGoodsList = goods_util:get_goods_list(GoodsStatus#goods_status.player_id, 4),
    NullCells = lists:seq(Num, PlayerStatus#player_status.cell_num),
    NewGoodsStatus = GoodsStatus#goods_status{  null_cells = NullCells },
   {reply, NewGoodsList, NewGoodsStatus};

%% 查看地上的掉落包
handle_call({'drop_list', PlayerStatus, DropId}, _From, GoodsStatus) ->
    case check_drop_list(PlayerStatus, DropId) of
        {fail, Res} ->
            {reply, [Res, []], GoodsStatus};
        {ok, DropInfo} ->
            {reply, [1, DropInfo#ets_goods_drop.drop_goods], GoodsStatus}
    end;

%% 拣取地上掉落包的物品
handle_call({'drop_choose', PlayerStatus, DropId, GoodsTypeId}, _From, GoodsStatus) ->
    case check_drop_choose(PlayerStatus, GoodsStatus, DropId, GoodsTypeId) of
        {fail, Res} ->
            {reply, Res, GoodsStatus};
        {ok, DropInfo, GoodsInfo} ->
            case (catch lib_goods:drop_choose(PlayerStatus, GoodsStatus, DropInfo, GoodsInfo)) of
                {ok, NewStatus} ->
                    {reply, 1, NewStatus};
                Error ->
                    ?DEBUG("mod_goods drop_choose:~p", [Error]),
                    {reply, 0, GoodsStatus}
            end
    end;

%% 赠送物品
handle_call({'give_goods', _PlayerStatus, GoodsTypeId, GoodsNum}, _From, GoodsStatus) ->
    case (catch lib_goods:give_goods({GoodsTypeId, GoodsNum}, GoodsStatus)) of
        {ok, NewStatus} ->
            lib_player:refresh_client(NewStatus#goods_status.player_id, 2),
            {reply, ok, NewStatus};
        {fail, Error, Status} ->
            ?DEBUG("mod_goods give_goods:~p", [Error]),
            {reply, Error, Status}
    end;

%% 赠送物品
%% GoodsList = [{GoodsTypeId, GoodsNum},...]
handle_call({'give_more', _PlayerStatus, GoodsList}, _From, GoodsStatus) ->
    case (catch goods_util:list_handle(fun lib_goods:give_goods/2, GoodsStatus, GoodsList)) of
        {ok, NewStatus} ->
            lib_player:refresh_client(NewStatus#goods_status.player_id, 2),
            {reply, ok, NewStatus};
        {fail, Error, Status} ->
            ?DEBUG("mod_goods give_more:~p", [Error]),
            {reply, Error, Status}
    end;

%% 怪物掉落
%% {'mon_drop', PlayerStatus, MonStatus} -> {ok, TaskResult} | {fail, no_drop}
handle_call({'mon_drop', PlayerStatus, MonStatus}, _From, GoodsStatus) ->
    PlayerId = PlayerStatus#player_status.id,
    TeamId = PlayerStatus#player_status.pid_team,
    MonId = MonStatus#ets_mon.mid,
    RealMonId = MonStatus#ets_mon.id,
    NumRule = lib_goods:get_drop_num_rule(MonId),
    case is_record(NumRule, ets_goods_drop_num) of
        true when NumRule#ets_goods_drop_num.drop_num > 0 ->
            [TotalRatio, RuleList] = lib_goods:get_drop_rule_list(PlayerId, MonId),
            case length(RuleList) > 0 of
                true ->
                    DropNum = NumRule#ets_goods_drop_num.drop_num,
                    [NewGoodsStatus, _, _, RuleResult, TaskResult] = lists:foldl(fun lib_goods:mon_drop/2, [GoodsStatus, RuleList, TotalRatio, [], []], lists:seq(1, DropNum)),
                    %io:format("mon_drop RuleResult: ~p~n",[RuleResult]),
                    case length(TaskResult) > 0 of
                        true ->
                            %io:format("mon_drop TaskResult: ~p~n",[TaskResult]),
                            lib_task:event(item, TaskResult, PlayerId),
                            lib_player:refresh_client(PlayerId, 2);
                        false -> skip
                    end,
                    case length(RuleResult) > 0 of
                        %% 如果有掉落，则插入ETS
                        true ->
                            ExpireTime = util:unixtime() + 60,
                            DropInfo = #ets_goods_drop{ id=RealMonId, player_id=PlayerId, team_id=TeamId, drop_goods=RuleResult, expire_time=ExpireTime },
                            ets:insert(?ETS_GOODS_DROP, DropInfo),
                            %% 广播
                            {ok, BinData} = pt_12:write(12017, [RealMonId, 60, MonStatus#ets_mon.x, MonStatus#ets_mon.y]),
                            lib_send:send_to_team(PlayerStatus#player_status.sid, PlayerStatus#player_status.pid_team, BinData),
                            {reply, ok, NewGoodsStatus};
                        %% 无掉落
                        false ->
                            {reply, {fail, no_drop}, NewGoodsStatus}
                    end;
                %% 无掉落
                false ->
                    {reply, {fail, no_drop}, GoodsStatus}
            end;
        %% 无掉落
        _ ->
            {reply, {fail, no_drop}, GoodsStatus}
    end;

%% 获取空格子数
handle_call({'cell_num'} , _From, GoodsStatus) ->
    {reply, length(GoodsStatus#goods_status.null_cells), GoodsStatus};

handle_call(_R , _From, GoodsStatus) ->
    {reply, ok, GoodsStatus}.

handle_info(_Reason, GoodsStatus) ->
    {noreply, GoodsStatus}.

terminate(_Reason, _GoodsStatus) ->
    ok.

code_change(_OldVsn, GoodsStatus, _Extra)->
    {ok, GoodsStatus}.

%% Local Function
check_pay(PlayerStatus, GoodsStatus, GoodsTypeId, GoodsNum, ShopType) ->
    ShopInfo = goods_util:get_shop_info(ShopType, GoodsTypeId),
    GoodsTypeInfo = goods_util:get_goods_type(GoodsTypeId),
    case is_record(GoodsTypeInfo, ets_goods_type) andalso is_record(ShopInfo, ets_shop) of
        %% 物品不存在
        false -> {fail, 2};
        true ->
            GoodsList = goods_util:get_type_goods_list(GoodsStatus#goods_status.player_id, GoodsTypeId, GoodsTypeInfo#ets_goods_type.bind, 4),
            CellNum = goods_util:get_null_cell_num(GoodsList, GoodsTypeInfo#ets_goods_type.max_overlap, GoodsNum),
            case length(GoodsStatus#goods_status.null_cells) < CellNum of
                %%背包格子不足
                true -> {fail, 4};
                false ->
                    Cost = GoodsTypeInfo#ets_goods_type.price * GoodsNum,
                    PriceType = goods_util:get_price_type(GoodsTypeInfo#ets_goods_type.price_type),
                    case goods_util:is_enough_money(PlayerStatus, Cost, PriceType) of
                        %% 金额不足
                        false -> {fail, 3};
                        true -> {ok, GoodsTypeInfo, GoodsList, Cost, PriceType}
                    end
            end
    end.

check_sell(GoodsStatus, GoodsId, GoodsNum) ->
    GoodsInfo = goods_util:get_goods(GoodsId),
    if
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= GoodsStatus#goods_status.player_id ->
            {fail, 3};
        %% 物品不在背包
        GoodsInfo#goods.location =/= 4 ->
            {fail, 4};
        %% 物品不可出售
        GoodsInfo#goods.sell =:= 1 ->
            {fail, 5};
        %% 物品数量不足
        GoodsInfo#goods.num < GoodsNum ->
            {fail, 6};
        true ->
            {ok, GoodsInfo}
    end.

check_equip(PlayerStatus, GoodsId, Cell) ->
    Location = PlayerStatus#player_status.equip,
    GoodsInfo = goods_util:get_goods(GoodsId),
    if
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= PlayerStatus#player_status.id ->
            {fail, 3};
        %% 物品位置不正确
        GoodsInfo#goods.location =/= 4 ->
            {fail, 4};
        %% 物品位置不正确
        Location =/= 1 andalso Location =/= 2 andalso Location =/= 3 ->
            {fail, 4};
        %% 物品类型不可装备
        GoodsInfo#goods.type =/= 10 ->
            {fail, 5};
        true ->
            case goods_util:can_equip(PlayerStatus, GoodsInfo#goods.goods_id, Cell) of
                %% 玩家条件不符
                false ->
                    {fail, 6};
                NewCell ->
                    {ok, GoodsInfo, Location, NewCell}
            end
    end.

check_unequip(GoodsStatus, GoodsId, Equip) ->
    GoodsInfo = goods_util:get_goods(GoodsId),
    if
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= GoodsStatus#goods_status.player_id ->
            {fail, 3};
        %% 物品不在身上
        GoodsInfo#goods.location > 3 orelse GoodsInfo#goods.location < 1 ->
            {fail, 4};
        %% 物品不在身上
        GoodsInfo#goods.location =/= Equip ->
            {fail, 4};
        %% 物品类型不可装备
        GoodsInfo#goods.type =/= 10 ->
            {fail, 5};
        %% 背包已满
        length(GoodsStatus#goods_status.null_cells) =:= 0 ->
            {fail, 6};
        true ->
            {ok, GoodsInfo}
    end.

check_drag(GoodsStatus, GoodsId, OldCell, NewCell, MaxCellNum) ->
    GoodsInfo = goods_util:get_goods(GoodsId),
    if
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= GoodsStatus#goods_status.player_id ->
            {fail, 3};
        %% 物品不在背包
        GoodsInfo#goods.location =/= 4 ->
            {fail, 4};
        %% 物品格子位置不正确
        GoodsInfo#goods.cell =/= OldCell ->
            {fail, 5};
        %% 物品格子位置不正确
        NewCell < 1 orelse NewCell > MaxCellNum ->
            {fail, 5};
        true ->
            {ok, GoodsInfo}
    end.

check_use(GoodsStatus, GoodsId, GoodsNum, Level) ->
    NowTime = util:unixtime(),
    GoodsInfo = goods_util:get_goods(GoodsId),
    if
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= GoodsStatus#goods_status.player_id ->
            {fail, 3};
        %% 物品不在背包
        GoodsInfo#goods.location =/= 4 ->
            {fail, 4};
        %% 物品类型不符
        GoodsInfo#goods.type =/= 20 andalso GoodsInfo#goods.type =/= 22 ->
            {fail, 5};
        %% 物品数量不正确
        GoodsInfo#goods.num < GoodsNum ->
            {fail, 6};
        %% 冷却时间
        GoodsInfo#goods.type =:= 20 andalso GoodsStatus#goods_status.ct_time > NowTime ->
            {fail, 7};
        %% 人物等级不足
        GoodsInfo#goods.level > Level ->
            {fail, 8};
        true ->
            {ok, GoodsInfo}
    end.

check_throw(GoodsStatus, GoodsId, GoodsNum) ->
    GoodsInfo = goods_util:get_goods(GoodsId),
    if
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= GoodsStatus#goods_status.player_id ->
            {fail, 3};
        %% 物品不在背包
        GoodsInfo#goods.location =/= 4 ->
            {fail, 4};
        %% 物品不可丢弃
        GoodsInfo#goods.isdrop =:= 1 ->
            {fail, 5};
        %% 物品数量不正确
        GoodsInfo#goods.num < GoodsNum ->
            {fail, 6};
        true ->
            {ok, GoodsInfo}
    end.

check_movein_bag(GoodsStatus, GoodsId, GoodsNum) ->
    GoodsInfo = goods_util:get_goods(GoodsId),
    if
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= GoodsStatus#goods_status.player_id ->
            {fail, 3};
        %% 物品不在背包
        GoodsInfo#goods.location =/= 4 ->
            {fail, 4};
        %% 物品数量不正确
        GoodsInfo#goods.num < GoodsNum ->
            {fail, 5};
        true ->
            GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
            if
                %% 物品类型不存在
                is_record(GoodsTypeInfo, ets_goods_type) =:= false ->
                    {fail, 2};
                true ->
                    {ok, GoodsInfo, GoodsTypeInfo}
            end
    end.

check_moveout_bag(GoodsStatus, GoodsId, GoodsNum) ->
    GoodsInfo = goods_util:get_goods_by_id(GoodsId),
    if
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= GoodsStatus#goods_status.player_id ->
            {fail, 3};
        %% 物品不在仓库
        GoodsInfo#goods.location =/= 5 ->
            {fail, 4};
        %% 物品数量不正确
        GoodsInfo#goods.num < GoodsNum ->
            {fail, 5};
        true ->
            GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
            if
                %% 物品类型不存在
                is_record(GoodsTypeInfo, ets_goods_type) =:= false ->
                    {fail, 2};
                %% 背包已满
                length(GoodsStatus#goods_status.null_cells) =< 0 ->
                    {fail, 6};
                true ->
                    {ok, GoodsInfo, GoodsTypeInfo}
            end
    end.

check_extend_bag(PlayerStatus) ->
    Cost = 1000,
    MaxCell = 147,
    if
        %% 背包已达上限
        PlayerStatus#player_status.cell_num >= MaxCell ->
            {fail, 3};
        true ->
            case goods_util:is_enough_money(PlayerStatus, Cost, coin) of
                %% 玩家金额不足
                false -> {fail, 2};
                true ->{ok, Cost}
            end
    end.

check_mend(PlayerStatus, GoodsId) ->
    GoodsInfo = goods_util:get_goods(GoodsId),
    if  %% 物品不存在
        is_record(GoodsInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= PlayerStatus#player_status.id ->
            {fail, 3};
        %% 物品类型不正确
        GoodsInfo#goods.type =/= 10 orelse GoodsInfo#goods.attrition =:= 0 ->
            {fail, 4};
        true ->
            UseNum = goods_util:get_goods_use_num(GoodsInfo#goods.attrition),
            if  %% 无磨损
                UseNum > 0 andalso UseNum =:= GoodsInfo#goods.use_num ->
                    {fail, 5};
                true ->
                    Cost = goods_util:get_mend_cost(GoodsInfo#goods.attrition, GoodsInfo#goods.use_num),
                    case goods_util:is_enough_money(PlayerStatus, Cost, coin) of
                        %% 余额不足
                        false -> {fail, 6};
                        true -> {ok, GoodsInfo}
                    end
            end
    end.

check_quality_upgrade(PlayerStatus, GoodsId, StoneId) ->
    GoodsInfo = goods_util:get_goods(GoodsId),
    StoneInfo = goods_util:get_goods(StoneId),
    if
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false orelse is_record(StoneInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不存在
        GoodsInfo#goods.num < 1 orelse StoneInfo#goods.num < 1 ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= PlayerStatus#player_status.id
                orelse StoneInfo#goods.player_id =/= PlayerStatus#player_status.id ->
            {fail, 3};
        %% 物品位置不正确
        GoodsInfo#goods.location =/= 4 ->
            {fail, 4};
        %% 物品类型不正确
        GoodsInfo#goods.type =/= 10 ->
            {fail, 5};
        %% 物品类型不正确
        StoneInfo#goods.type =/= 11 orelse StoneInfo#goods.subtype =/= 11 ->
            {fail, 5};
        true ->
            Pattern = #ets_goods_quality_upgrade{ goods_id=StoneInfo#goods.goods_id, quality=GoodsInfo#goods.quality, _='_' },
            GoodsQualityRule = goods_util:get_ets_info(?ETS_GOODS_QUALITY_UPGRADE, Pattern),
            if
                %% 品质升级规则不存在
                is_record(GoodsQualityRule, ets_goods_quality_upgrade) =:= false ->
                    {fail, 6};
                %% 玩家铜钱不足
                (PlayerStatus#player_status.coin + PlayerStatus#player_status.bcoin) < GoodsQualityRule#ets_goods_quality_upgrade.coin ->
                    {fail, 7};
                true ->
                    {ok, GoodsInfo, StoneInfo, GoodsQualityRule}
            end
    end.

check_quality_backout(GoodsStatus, GoodsId) ->
    GoodsInfo = goods_util:get_goods(GoodsId),
    if
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false orelse GoodsInfo#goods.num < 1 ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= GoodsStatus#goods_status.player_id ->
            {fail, 3};
        %% 物品类型不正确
        GoodsInfo#goods.type =/= 10 ->
            {fail, 5};
        %% 物品品质不正确
        GoodsInfo#goods.quality < 1 ->
            {fail, 6};
        %% 背包满
        length(GoodsStatus#goods_status.null_cells) =:= 0 ->
            {fail, 8};
        true ->
            Pattern = #ets_goods_quality_backout{ quality=GoodsInfo#goods.quality, _='_' },
            GoodsBackoutRuleList = goods_util:get_ets_list(?ETS_GOODS_QUALITY_BACKOUT, Pattern),
            if
                %% 装备品质石拆除规则不存在
                length(GoodsBackoutRuleList) =:= 0 ->
                    {fail, 7};
                true ->
                    {ok, GoodsInfo, GoodsBackoutRuleList}
            end
    end.

check_strengthen(PlayerStatus, GoodsId, StoneId, RuneId) ->
    GoodsInfo = goods_util:get_goods(GoodsId),
    StoneInfo = goods_util:get_goods(StoneId),
    case RuneId > 0 of
        true -> RuneInfo = goods_util:get_goods(RuneId);
        false -> RuneInfo = #goods{ num = 1, player_id = PlayerStatus#player_status.id, location = 4, type = 11, subtype = 10 }
    end,
    if
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false
                orelse is_record(StoneInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不存在
        RuneId > 0 andalso is_record(RuneInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不存在
        GoodsInfo#goods.num < 1 orelse StoneInfo#goods.num < 1 ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= PlayerStatus#player_status.id
                orelse StoneInfo#goods.player_id =/= PlayerStatus#player_status.id ->
            {fail, 3};
        %% 物品不属于你所有
        RuneId > 0 andalso RuneInfo#goods.player_id =/= PlayerStatus#player_status.id ->
            {fail, 3};
        %% 物品位置不正确
        GoodsInfo#goods.location =/= 4 ->
            {fail, 4};
        %% 物品类型不正确
        GoodsInfo#goods.type =/= 10 ->
            {fail, 5};
        %% 物品类型不正确
        StoneInfo#goods.type =/= 11 orelse StoneInfo#goods.subtype =/= 10 ->
            {fail, 5};
        %% 物品类型不正确
        RuneId > 0 andalso RuneInfo#goods.type =/= 12 ->
            {fail, 5};
        %% 物品类型不正确
        RuneId > 0 andalso RuneInfo#goods.subtype =/= 10 andalso RuneInfo#goods.subtype =/= 18 ->
            {fail, 5};
        %% 强化已达上限
        GoodsInfo#goods.stren >= 10 ->
            {fail, 8};
        true ->
            Pattern = #ets_goods_strengthen{ goods_id=StoneInfo#goods.goods_id, strengthen=GoodsInfo#goods.stren, _='_' },
            GoodsStrengthenRule = goods_util:get_ets_info(?ETS_GOODS_STRENGTHEN, Pattern),
            if
                %% 强化规则不存在
                is_record(GoodsStrengthenRule, ets_goods_strengthen) =:= false ->
                    {fail, 6};
                %% 玩家铜钱不足
                (PlayerStatus#player_status.coin + PlayerStatus#player_status.bcoin) < GoodsStrengthenRule#ets_goods_strengthen.coin ->
                    {fail, 7};
                true ->
                    {ok, GoodsInfo, StoneInfo, RuneInfo, GoodsStrengthenRule}
            end
    end.

check_hole(PlayerStatus, GoodsId, RuneId) ->
    Cost = 100,
    GoodsInfo = goods_util:get_goods(GoodsId),
    RuneInfo = goods_util:get_goods(RuneId),
    if
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false orelse is_record(RuneInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不存在
        GoodsInfo#goods.num < 1 orelse RuneInfo#goods.num < 1 ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= PlayerStatus#player_status.id
                orelse RuneInfo#goods.player_id =/= PlayerStatus#player_status.id ->
            {fail, 3};
        %% 物品位置不正确
        GoodsInfo#goods.location =/= 4 ->
            {fail, 4};
        %% 物品类型不正确
        GoodsInfo#goods.type =/= 10 ->
            {fail, 5};
        %% 物品类型不正确
        RuneInfo#goods.type =/= 12 orelse RuneInfo#goods.subtype =/= 12 ->
            {fail, 5};
        %% 孔数已达上限
        GoodsInfo#goods.hole >= 3 ->
            {fail, 6};
        %% 玩家铜钱不足
        (PlayerStatus#player_status.coin + PlayerStatus#player_status.bcoin) < Cost ->
            {fail, 7};
        true ->
            {ok, GoodsInfo, RuneInfo}
    end.

check_compose(PlayerStatus, GoodsStatus, RuneId, StoneTypeId, StoneList) ->
    case RuneId > 0 of
        true -> RuneInfo = goods_util:get_goods(RuneId);
        false -> RuneInfo = #goods{ num = 1, player_id = PlayerStatus#player_status.id, location = 4, type = 12, subtype = 13, color=3 }
    end,
    if
        %% 物品不存在
        is_record(RuneInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不属于你所有
        RuneInfo#goods.player_id =/= PlayerStatus#player_status.id ->
            {fail, 3};
        %% 物品位置不正确
        RuneInfo#goods.location =/= 4 ->
            {fail, 4};
        %% 物品类型不正确
        RuneInfo#goods.type =/= 12 orelse RuneInfo#goods.subtype =/= 13 ->
            {fail, 5};
        %% 物品数量不正确
        RuneInfo#goods.num < 1 ->
            {fail, 6};
        %% 物品数量不正确
        length(StoneList) =:= 0 ->
            {fail, 6};
        true ->
            case goods_util:list_handle(fun check_compose_stone/2, [RuneInfo, StoneTypeId, 0, []], StoneList) of
                {fail, Res} ->
                    {fail, Res};
                {ok, [_, _, TotalStoneNum, NewStoneList]} ->
                    Pattern = #ets_goods_compose{ goods_id=StoneTypeId, goods_num=TotalStoneNum, _='_' },
                    GoodsComposeRule = goods_util:get_ets_info(?ETS_GOODS_COMPOSE, Pattern),
                    if
                        %% 合成规则不存在
                        is_record(GoodsComposeRule, ets_goods_compose) =:= false ->
                            {fail, 7};
                        %% 玩家铜钱不足
                        (PlayerStatus#player_status.coin + PlayerStatus#player_status.bcoin) < GoodsComposeRule#ets_goods_compose.coin ->
                            {fail, 8};
                        %% 背包满
                        length(GoodsStatus#goods_status.null_cells) =:= 0 ->
                            {fail, 9};
                        true ->
                            {ok, NewStoneList, RuneInfo, GoodsComposeRule}
                    end
            end
    end.
%% 处理合成宝石
check_compose_stone([StoneId, StoneNum], [RuneInfo, StoneTypeId, Num, L]) ->
    StoneInfo = goods_util:get_goods(StoneId),
    if
        %% 物品不存在
        is_record(StoneInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不属于你所有
        StoneInfo#goods.player_id =/= RuneInfo#goods.player_id ->
            {fail, 3};
        %% 物品类型不正确
        StoneInfo#goods.goods_id =/= StoneTypeId ->
            {fail, 5};
        %% 物品类型不正确
        RuneInfo#goods.color < StoneInfo#goods.color ->
            {fail, 5};
        %% 物品数量不正确
        StoneInfo#goods.num < StoneNum ->
            {fail, 6};
        true ->
            {ok, [RuneInfo, StoneTypeId, Num+StoneNum, [[StoneInfo, StoneNum]|L]]}
    end.

check_inlay(PlayerStatus, GoodsId, StoneId, RuneList) ->
    GoodsInfo = goods_util:get_goods(GoodsId),
    StoneInfo = goods_util:get_goods(StoneId),
    if
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false orelse is_record(StoneInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不存在
        GoodsInfo#goods.num < 1 orelse StoneInfo#goods.num < 1 ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= PlayerStatus#player_status.id
                orelse StoneInfo#goods.player_id =/= PlayerStatus#player_status.id ->
            {fail, 3};
        %% 物品位置不正确
        GoodsInfo#goods.location =/= 4 ->
            {fail, 4};
        %% 物品类型不正确
        GoodsInfo#goods.type =/= 10 ->
            {fail, 5};
        %% 物品类型不正确
        StoneInfo#goods.type =/= 11 orelse StoneInfo#goods.subtype =/= 14 ->
            {fail, 5};
        %% 物品类型不正确
        StoneInfo#goods.goods_id =:= GoodsInfo#goods.hole1_goods
                orelse StoneInfo#goods.goods_id =:= GoodsInfo#goods.hole2_goods
                orelse StoneInfo#goods.goods_id =:= GoodsInfo#goods.hole3_goods ->
            {fail, 5};
        %% 没有孔位
        GoodsInfo#goods.hole =:= 0 ->
            {fail, 6};
        %% 没有孔位
        GoodsInfo#goods.hole =:= 1 andalso GoodsInfo#goods.hole1_goods > 0 ->
            {fail, 6};
        %% 没有孔位
        GoodsInfo#goods.hole =:= 2 andalso GoodsInfo#goods.hole2_goods > 0 ->
            {fail, 6};
        %% 没有孔位
        GoodsInfo#goods.hole =:= 3 andalso GoodsInfo#goods.hole3_goods > 0 ->
            {fail, 6};
        true ->
            case goods_util:list_handle(fun check_inlay_rune/2, [PlayerStatus#player_status.id, 0, []], RuneList) of
                {fail, Res} ->
                    {fail, Res};
                {ok, [_, TotalRuneNum, NewRuneList]} ->
                    Pattern = #ets_goods_inlay{ goods_id=StoneInfo#goods.goods_id, _='_' },
                    GoodsInlayRule = goods_util:get_ets_info(?ETS_GOODS_INLAY, Pattern),
                    if
                        %% 镶嵌规则不存在
                        is_record(GoodsInlayRule, ets_goods_inlay) =:= false ->
                            {fail, 7};
                        %% 玩家铜钱不足
                        (PlayerStatus#player_status.coin + PlayerStatus#player_status.bcoin) < GoodsInlayRule#ets_goods_inlay.coin ->
                            {fail, 8};
                        true ->
                            case length(GoodsInlayRule#ets_goods_inlay.equip_types) > 0
                                    andalso lists:member(GoodsInfo#goods.subtype, GoodsInlayRule#ets_goods_inlay.equip_types) =:= false of
                                %% 不可镶嵌的类型
                                true -> {fail, 9};
                                false -> {ok, GoodsInfo, StoneInfo, TotalRuneNum, NewRuneList, GoodsInlayRule}
                            end
                    end
            end
    end.
%% 处理镶嵌符
check_inlay_rune([RuneId, RuneNum], [PlayerId, Num, L]) ->
    RuneInfo = goods_util:get_goods(RuneId),
    if
        %% 物品不存在
        is_record(RuneInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不属于你所有
        RuneInfo#goods.player_id =/= PlayerId ->
            {fail, 3};
        %% 物品类型不正确
        RuneInfo#goods.type =/= 12 orelse RuneInfo#goods.subtype =/= 14 ->
            {fail, 5};
        %% 物品数量不正确
        RuneInfo#goods.num < RuneNum ->
            {fail, 6};
        true ->
            {ok, [PlayerId, Num+RuneNum, [[RuneInfo, RuneNum]|L]]}
    end.

check_backout(PlayerStatus, GoodsStatus, GoodsId, RuneId) ->
    Cost = 100,
    GoodsInfo = goods_util:get_goods(GoodsId),
    RuneInfo = goods_util:get_goods(RuneId),
    if
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false orelse GoodsInfo#goods.num < 1 ->
            {fail, 2};
        %% 物品不存在
        is_record(RuneInfo, goods) =:= false orelse RuneInfo#goods.num < 1 ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= PlayerStatus#player_status.id
                orelse RuneInfo#goods.player_id =/= PlayerStatus#player_status.id ->
            {fail, 3};
        %% 物品位置不正确
        GoodsInfo#goods.location =/= 4 orelse RuneInfo#goods.location =/= 4 ->
            {fail, 4};
        %% 物品类型不正确
        GoodsInfo#goods.type =/= 10 ->
            {fail, 5};
        %% 物品类型不正确
        RuneInfo#goods.type =/= 12 andalso RuneInfo#goods.subtype =/= 17 ->
            {fail, 5};
        %% 没有宝石可拆
        GoodsInfo#goods.hole1_goods =:= 0 ->
            {fail, 8};
        %% 玩家铜钱不足
        (PlayerStatus#player_status.coin + PlayerStatus#player_status.bcoin) < Cost ->
            {fail, 6};
        true ->
            InlayNum = goods_util:get_inlay_num(GoodsInfo),
            if
                %% 背包格子不足
                length(GoodsStatus#goods_status.null_cells) < InlayNum ->
                    {fail, 7};
                true ->
                    {ok, GoodsInfo, RuneInfo}
            end
    end.

check_wash(PlayerStatus, GoodsId, RuneId) ->
    Cost = 100,
    GoodsInfo = goods_util:get_goods(GoodsId),
    RuneInfo = goods_util:get_goods(RuneId),
    if
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false orelse is_record(RuneInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不存在
        GoodsInfo#goods.num < 1 orelse RuneInfo#goods.num < 1 ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= PlayerStatus#player_status.id
                orelse RuneInfo#goods.player_id =/= PlayerStatus#player_status.id ->
            {fail, 3};
        %% 物品位置不正确
        GoodsInfo#goods.location =/= 4
                orelse RuneInfo#goods.location =/= 4 ->
            {fail, 4};
        %% 物品类型不正确
        GoodsInfo#goods.type =/= 10 ->
            {fail, 5};
        %% 物品类型不正确
        RuneInfo#goods.type =/= 12
                orelse RuneInfo#goods.subtype =/= 15 ->
            {fail, 5};
        %% 物品类型不正确
        GoodsInfo#goods.color =:= 0 ->
            {fail, 5};
        %% 玩家铜钱不足
        (PlayerStatus#player_status.coin + PlayerStatus#player_status.bcoin) < Cost ->
            {fail, 6};
        true ->
            Pattern = #ets_goods_attribute_rule{ goods_id=GoodsInfo#goods.goods_id, _='_'},
            AddAttributeRuleList = goods_util:get_ets_list(?ETS_GOODS_ATTRIBUTE_RULE, Pattern),
            if
                %% 装备附加属性规则不存在
                length(AddAttributeRuleList) =:= 0  ->
                    {fail, 7};
                true ->
                    {ok, GoodsInfo, RuneInfo, AddAttributeRuleList}
            end
    end.

check_change_equip(PlayerStatus, Equip) ->
    if
        %% 装备类型错误
        Equip > 3 orelse Equip < 1 ->
            {fail, 2};
        %% 装备类型错误
        Equip =:= PlayerStatus#player_status.equip ->
            {fail, 2};
        true -> ok
    end.

check_drop_list(PlayerStatus, DropId) ->
    DropInfo = goods_util:get_ets_info(?ETS_GOODS_DROP, DropId),
    NowTime = util:unixtime(),
    if
        %% 掉落包已经消失
        is_record(DropInfo, ets_goods_drop) =:= false ->
            {fail, 2};
        %% 掉落包已经消失
        DropInfo#ets_goods_drop.expire_time =< NowTime ->
            {fail, 2};
        %% 无权拣取
        DropInfo#ets_goods_drop.team_id =:= 0
                andalso DropInfo#ets_goods_drop.player_id =/= PlayerStatus#player_status.id ->
            {fail, 3};
        %% 无权拣取
        DropInfo#ets_goods_drop.team_id > 0
                andalso DropInfo#ets_goods_drop.team_id =/= PlayerStatus#player_status.pid_team
                andalso DropInfo#ets_goods_drop.player_id =/= PlayerStatus#player_status.id ->
            {fail, 3};
        true ->
            {ok, DropInfo}
    end.

check_drop_choose(PlayerStatus, GoodsStatus, DropId, GoodsTypeId) ->
    case check_drop_list(PlayerStatus, DropId) of
        {fail, Res} ->
            {fail, Res};
        {ok, DropInfo} ->
            case lists:keyfind(GoodsTypeId, 1, DropInfo#ets_goods_drop.drop_goods) of
                %% 物品已经不存在
                false ->
                    {fail, 4};
                GoodsInfo ->
                    {GoodsTypeId, _Type, GoodsNum, _GoodsQuality} = GoodsInfo,
                    GoodsTypeInfo = goods_util:get_goods_type(GoodsTypeId),
                    if is_record(GoodsTypeInfo, ets_goods_type) =:= false ->
                            {fail, 4};
                        true ->
                            GoodsList = goods_util:get_type_goods_list(GoodsStatus#goods_status.player_id, GoodsTypeId, GoodsTypeInfo#ets_goods_type.bind, 4),
                            CellNum = goods_util:get_null_cell_num(GoodsList, GoodsTypeInfo#ets_goods_type.max_overlap, GoodsNum),
                            if
                                %% 背包格子不足
                                length(GoodsStatus#goods_status.null_cells) < CellNum ->
                                    {fail, 5};
                                true ->
                                    {ok, DropInfo, GoodsInfo}
                            end
                    end
            end
    end.
