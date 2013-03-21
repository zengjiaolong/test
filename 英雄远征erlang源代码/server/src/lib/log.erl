%%%-----------------------------------
%%% @Module  : log
%%% @Author  : xhg
%%% @Email   : xuhuguang@jieyou.com
%%% @Created : 2010.07.23
%%% @Description: 公共函数
%%%-----------------------------------
-module(log).
-include("record.hrl").
-export([
        log_stren/7,
        log_quality_up/6,
        log_quality_out/6,
        log_hole/4,
        log_compose/6,
        log_inlay/5,
        log_backout/3,
        log_wash/3,
        log_consume/4
    ]).

%% 装备强化日志
log_stren(PlayerStatus, GoodsInfo, Stren_fail, StoneId, RuneId, Cost, Status) ->
    Sql = io_lib:format(<<"insert into `log_stren` set time=UNIX_TIMESTAMP(), player_id=~p, nickname='~s', gid=~p, goods_id=~p, subtype=~p, level=~p, stren=~p, stren_his=~p, stren_fail=~p, stone_id=~p, rune_id=~p, cost=~p, status=~p  ">>,
                                [PlayerStatus#player_status.id, PlayerStatus#player_status.nickname, GoodsInfo#goods.id, GoodsInfo#goods.goods_id, GoodsInfo#goods.subtype, GoodsInfo#goods.level, GoodsInfo#goods.stren, GoodsInfo#goods.stren_his, Stren_fail, StoneId, RuneId, Cost, Status ]),
    db_sql:execute(Sql),
    ok.

%% 装备品质升级日志
log_quality_up(PlayerStatus, GoodsInfo, Quality_fail, StoneId, Cost, Status) ->
    Sql = io_lib:format(<<"insert into `log_stren` set time=UNIX_TIMESTAMP(), player_id=~p, nickname='~s', gid=~p, goods_id=~p, subtype=~p, level=~p, quality=~p, quality_his=~p, quality_fail=~p, stone_id=~p, cost=~p, status=~p  ">>,
                                [PlayerStatus#player_status.id, PlayerStatus#player_status.nickname, GoodsInfo#goods.id, GoodsInfo#goods.goods_id, GoodsInfo#goods.subtype, GoodsInfo#goods.level, GoodsInfo#goods.quality, GoodsInfo#goods.quality_his, Quality_fail, StoneId, Cost, Status ]),
    db_sql:execute(Sql),
    ok.

%% 装备品质石拆除日志
log_quality_out(PlayerStatus, GoodsInfo, StoneId, StoneNum, Cost, Status) ->
    Sql = io_lib:format(<<"insert into `log_stren` set time=UNIX_TIMESTAMP(), player_id=~p, nickname='~s', gid=~p, goods_id=~p, subtype=~p, level=~p, quality=~p, stone_id=~p, stone_num=~p, cost=~p, status=~p  ">>,
                                [PlayerStatus#player_status.id, PlayerStatus#player_status.nickname, GoodsInfo#goods.id, GoodsInfo#goods.goods_id, GoodsInfo#goods.subtype, GoodsInfo#goods.level, GoodsInfo#goods.quality, StoneId, StoneNum, Cost, Status ]),
    db_sql:execute(Sql),
    ok.

%% 装备打孔日志
log_hole(PlayerStatus, GoodsInfo, Cost, Status) ->
    Sql = io_lib:format(<<"insert into `log_hole` set time=UNIX_TIMESTAMP(), player_id=~p, nickname='~s', gid=~p, goods_id=~p, subtype=~p, level=~p, hole=~p, cost=~p, status=~p  ">>,
                                [PlayerStatus#player_status.id, PlayerStatus#player_status.nickname, GoodsInfo#goods.id, GoodsInfo#goods.goods_id, GoodsInfo#goods.subtype, GoodsInfo#goods.level, GoodsInfo#goods.hole, Cost, Status ]),
    db_sql:execute(Sql),
    ok.

%% 宝石合成日志
log_compose(PlayerStatus, Rule, Subtype, RuneId, Cost, Status) ->
    Sql = io_lib:format(<<"insert into `log_compose` set time=UNIX_TIMESTAMP(), player_id=~p, nickname='~s', gid=~p, goods_id=~p, subtype=~p, stone_num=~p, new_id=~p, rune_id=~p, cost=~p, status=~p  ">>,
                                [PlayerStatus#player_status.id, PlayerStatus#player_status.nickname, Rule#ets_goods_compose.goods_id, Subtype, Rule#ets_goods_compose.goods_num, Rule#ets_goods_compose.new_id, RuneId, Cost, Status]),
    db_sql:execute(Sql),
    ok.

%% 宝石镶嵌日志
log_inlay(PlayerStatus, GoodsInfo, StoneId, Cost, Status) ->
    Sql = io_lib:format(<<"insert into `log_inlay` set time=UNIX_TIMESTAMP(), player_id=~p, nickname='~s', gid=~p, goods_id=~p, subtype=~p, level=~p, stone_id=~p, cost=~p, status=~p  ">>,
                                [PlayerStatus#player_status.id, PlayerStatus#player_status.nickname, GoodsInfo#goods.id, GoodsInfo#goods.goods_id, GoodsInfo#goods.subtype, GoodsInfo#goods.level, StoneId, Cost, Status ]),
    db_sql:execute(Sql),
    ok.

%% 宝石拆除日志
log_backout(PlayerStatus, GoodsInfo, Cost) ->
    InlayNum = goods_util:get_inlay_num(GoodsInfo),
    Sql = io_lib:format(<<"insert into `log_backout` set time=UNIX_TIMESTAMP(), player_id=~p, nickname='~s', gid=~p, goods_id=~p, subtype=~p, level=~p, inlay=~p, cost=~p ">>,
                                [PlayerStatus#player_status.id, PlayerStatus#player_status.nickname, GoodsInfo#goods.id, GoodsInfo#goods.goods_id, GoodsInfo#goods.subtype, GoodsInfo#goods.level, InlayNum, Cost ]),
    db_sql:execute(Sql),
    ok.

%% 装备洗炼日志
log_wash(PlayerStatus, GoodsInfo, Cost) ->
    Sql = io_lib:format(<<"insert into `log_wash` set time=UNIX_TIMESTAMP(), player_id=~p, nickname='~s', gid=~p, goods_id=~p, subtype=~p, level=~p, color=~p, cost=~p ">>,
                                [PlayerStatus#player_status.id, PlayerStatus#player_status.nickname, GoodsInfo#goods.id, GoodsInfo#goods.goods_id, GoodsInfo#goods.subtype, GoodsInfo#goods.level, GoodsInfo#goods.color, Cost ]),
    db_sql:execute(Sql),
    ok.

%% 消费日志
log_consume(Type, GoodsInfo, PlayerStatus, NewPlayerStatus) ->
    ConsumeType = goods_util:get_consume_type(Type),
    Cost_coin = PlayerStatus#player_status.coin - NewPlayerStatus#player_status.coin,
    Cost_silver = PlayerStatus#player_status.silver - NewPlayerStatus#player_status.silver,
    Cost_gold = PlayerStatus#player_status.gold - NewPlayerStatus#player_status.gold,
    Cost_bcoin = PlayerStatus#player_status.bcoin - NewPlayerStatus#player_status.bcoin,
    Remain_coin = NewPlayerStatus#player_status.coin,
    Remain_silver = NewPlayerStatus#player_status.silver,
    Remain_gold = NewPlayerStatus#player_status.gold,
    Remain_bcoin = NewPlayerStatus#player_status.bcoin,
    Sql = io_lib:format(<<"insert into `log_consume` set time=UNIX_TIMESTAMP(), consume_type=~p, player_id=~p, nickname='~s', gid=~p, goods_id=~p, cost_coin=~p, cost_silver=~p, cost_gold=~p, cost_bcoin=~p, remain_coin=~p, remain_silver=~p, remain_gold=~p, remain_bcoin=~p ">>,
                                [ConsumeType, PlayerStatus#player_status.id, PlayerStatus#player_status.nickname, GoodsInfo#goods.id, GoodsInfo#goods.goods_id, GoodsInfo#goods.subtype, GoodsInfo#goods.level, GoodsInfo#goods.color, Cost_coin, Cost_silver, Cost_gold, Cost_bcoin, Remain_coin, Remain_silver, Remain_gold, Remain_bcoin ]),
    db_sql:execute(Sql),
    ok.
