%%%--------------------------------------
%%% @Module  : lib_mount
%%% @Author  : xhg
%%% @Email   : xuhuguang@jieyou.com
%%% @Created : 2010.06.02
%%% @Description : 坐骑信息
%%%--------------------------------------
-module(lib_mount).
-include("common.hrl").
-include("record.hrl").
-compile(export_all).

%% 计算消耗灵力
%% @spec get_spirit(MountId, CellNum) -> int()
get_spirit(MountTypeId) ->
     MountTypeInfo = goods_util:get_ets_info(?ETS_GOODS_TYPE, MountTypeId),
    case is_record(MountTypeInfo, ets_goods_type) of
        false -> [0, 0];
        true ->
            case MountTypeInfo#ets_goods_type.level of
                %% 15级坐骑，每行进6格消耗量一点灵力
                15 -> [6, 1];
                30 -> [5, 1];
                45 -> [4, 1];
                60 -> [3, 1];
                75 -> [5, 2];
                90 -> [4, 2];
                100 -> [3, 2];
                _ -> [0, 0]
            end
    end.

%% 取一条记录信息
%% @spec get_info(MountId) -> record()
get_info(MountId) ->
    %Sql = io_lib:format(<<"select * from `goods` where id = ~p limit 1">>, [MountId]),
    %GoodsInfo = (catch db_sql:get_row(Sql)),
    %lib_goods:make_info(goods, GoodsInfo).
    goods_util:get_ets_info(?ETS_GOODS_ONLINE, MountId).

%% 乘上坐骑
%% @spec get_on(MountInfo) -> ok | Error
get_on(PlayerStatus, GoodsStatus, MountInfo) ->
    OldMountInfo = case PlayerStatus#player_status.mount > 0 of
                            true -> get_info(PlayerStatus#player_status.mount);
                            false -> {}
                   end,
    case is_record(OldMountInfo, goods) of
        %% 原来乘有坐骑
        true ->
            NullCells = lists:sort([MountInfo#goods.cell|GoodsStatus#goods_status.null_cells]),
            NewGoodsStatus = GoodsStatus#goods_status{ null_cells=NullCells },
            {ok, NewPlayerStatus1, NewGoodsStatus1, OldMountCell} = get_off(PlayerStatus, NewGoodsStatus, OldMountInfo),
            OldMountId = OldMountInfo#goods.id,
            OldMountTypeId = OldMountInfo#goods.goods_id;
        false ->
            NewPlayerStatus1 = PlayerStatus,
            NewGoodsStatus1 = GoodsStatus,
            OldMountId = 0,
            OldMountTypeId = 0,
            OldMountCell = 0
    end,
    %% 修改玩家坐骑状态
    Sql = io_lib:format(<<"update `goods` set cell = 16, location = 1 where id = ~p ">>, [MountInfo#goods.id]),
    db_sql:execute(Sql),
    NewMountInfo = MountInfo#goods{ cell=16, location=1 },
    ets:insert(?ETS_GOODS_ONLINE, NewMountInfo),
    %% 修改角色状态
    MountSpirit = get_spirit(MountInfo#goods.goods_id),
    NewSpeed = NewPlayerStatus1#player_status.speed + MountInfo#goods.speed,
    [Wq, Yf, _Zq] = NewPlayerStatus1#player_status.equip_current,
    NewPlayerStatus2 = NewPlayerStatus1#player_status{
                           mount = MountInfo#goods.id,
                           mount_spirit = MountSpirit,
                           equip_current = [Wq, Yf, MountInfo#goods.goods_id],
                           speed = NewSpeed
                },
    Sql1 = io_lib:format(<<"update player set mount=~p, speed=~p where id=~p">>, [MountInfo#goods.id, NewSpeed, NewPlayerStatus2#player_status.id]),
    db_sql:execute(Sql1),
    {ok, NewPlayerStatus2, NewGoodsStatus1, [OldMountId, OldMountTypeId, OldMountCell, MountInfo#goods.goods_id]}.

%% 离开坐骑
%% @spec get_off(MountInfo) -> ok | Error
get_off(PlayerStatus, GoodsStatus, MountInfo) ->
    %% 修改玩家坐骑状态
    [Cell|NullCells] = GoodsStatus#goods_status.null_cells,
    Sql = io_lib:format(<<"update `goods` set cell = ~p, location = 4 where id = ~p ">>, [Cell, MountInfo#goods.id]),
    db_sql:execute(Sql),
    NewMountInfo = MountInfo#goods{ cell=Cell, location=4 },
    ets:insert(?ETS_GOODS_ONLINE, NewMountInfo),
    NewGoodsStatus = GoodsStatus#goods_status{ null_cells=NullCells },
    %% 修改角色状态
    MountSpirit = [0,0],
    %ok = gen_server:cast(PlayerStatus#player_status.pid, {'MOUNT', 0, 0, (-MountInfo#goods.speed), MountSpirit}),
    NewSpeed = case PlayerStatus#player_status.speed - MountInfo#goods.speed < 0 of
                    true -> 0;
                    false -> PlayerStatus#player_status.speed - MountInfo#goods.speed
               end,
    [Wq, Yf, _Zq] = PlayerStatus#player_status.equip_current,
    NewPlayerStatus = PlayerStatus#player_status{
                           mount = 0,
                           mount_spirit = MountSpirit,
                           equip_current = [Wq, Yf, 0],
                           speed = NewSpeed
                },
    Sql1 = io_lib:format(<<"update player set mount=0, speed=~p where id=~p">>, [NewSpeed, NewPlayerStatus#player_status.id]),
    db_sql:execute(Sql1),
    {ok, NewPlayerStatus, NewGoodsStatus, Cell}.

%% 丢弃坐骑
%% @spec throw_away(MountId) -> ok | Error
throw_away(GoodsStatus, MountInfo) ->
    Sql = io_lib:format(<<"delete from `goods` where id = ~p ">>, [MountInfo#goods.id]),
    db_sql:execute(Sql),
    ets:delete(?ETS_GOODS_ONLINE, MountInfo#goods.id),
    NullCells = lists:sort([MountInfo#goods.cell|GoodsStatus#goods_status.null_cells]),
    NewGoodsStatus = GoodsStatus#goods_status{ null_cells=NullCells },
    {ok, NewGoodsStatus}.
