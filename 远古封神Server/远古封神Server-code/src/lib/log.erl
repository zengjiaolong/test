%%%-----------------------------------
%%% @Module  : log
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 公共函数
%%%-----------------------------------
-module(log).
-include("record.hrl").
-compile(export_all).

%% 装备强化日志 
log_stren(PlayerStatus, GoodsInfo,Ratio,Ram,Stren_fail, StoneId, RuneId,RuneNum,ProtId,Cost, Status) ->
    Data = [PlayerStatus#player.id, PlayerStatus#player.nickname, GoodsInfo#goods.id, GoodsInfo#goods.goods_id, GoodsInfo#goods.subtype, GoodsInfo#goods.level, GoodsInfo#goods.stren, Ratio,Ram,Stren_fail, StoneId, RuneId,RuneNum,ProtId, Cost, Status ],
    db_agent:log_stren(Data),
    ok.

%% 装备鉴定日志
log_identify(PlayerStatus,GoodsInfo,StoneId,Cost,Status) ->
	Data = [PlayerStatus#player.id,PlayerStatus#player.nickname,GoodsInfo#goods.id,GoodsInfo#goods.goods_id,GoodsInfo#goods.subtype,GoodsInfo#goods.level,StoneId,Cost,Status],
	db_agent:log_identify(Data),
	ok.

%% 装备打孔日志
log_hole(PlayerStatus, GoodsInfo, StoneId, Cost, Status) ->
    Data = [PlayerStatus#player.id, PlayerStatus#player.nickname, GoodsInfo#goods.id, GoodsInfo#goods.goods_id, GoodsInfo#goods.subtype, GoodsInfo#goods.level, GoodsInfo#goods.hole, Cost, Status, StoneId],
    db_agent:log_hole(Data),
    ok.

%% 宝石合成日志
log_compose(PlayerStatus, Rule, Subtype, RuneId, Ratio,Ram,TotalStoneNum, Cost, Status) ->
	%% player_id, nickname, goods_id, subtype,stone_num,new_id,rune_id,cost,status]
    Data = [PlayerStatus#player.id, PlayerStatus#player.nickname, Rule#ets_base_goods_compose.goods_id, Subtype, TotalStoneNum, Rule#ets_base_goods_compose.new_id, RuneId, Ratio,Ram,Cost, Status],
    db_agent:log_compose(Data),
    ok.
  
%% 宝石镶嵌日志
log_inlay(PlayerStatus, GoodsInfo, StoneId,Ratio,Ram,TotalRuneNum,Cost, Status) ->
    Data = [PlayerStatus#player.id, PlayerStatus#player.nickname, GoodsInfo#goods.id, GoodsInfo#goods.goods_id, GoodsInfo#goods.subtype, GoodsInfo#goods.level, StoneId, Ratio,Ram,TotalRuneNum,Cost, Status ],
    db_agent:log_inlay(Data),
    ok.

%% 宝石拆除日志
log_backout(PlayerStatus, GoodsInfo,StoneTypeInfo,Ratio,Ram,TotalRuneNum,Cost,Status) ->
    InlayNum = goods_util:count_inlay_num(GoodsInfo),
    Data = [PlayerStatus#player.id, PlayerStatus#player.nickname, GoodsInfo#goods.id, GoodsInfo#goods.goods_id, GoodsInfo#goods.subtype, GoodsInfo#goods.level,StoneTypeInfo#ets_base_goods.goods_id, InlayNum, Ratio,Ram,TotalRuneNum,Cost,Status],
    db_agent:log_backout(Data),
    ok.

%% 法宝修炼日志
log_practise(PlayerStatus,GoodsInfo)->
	if
		GoodsInfo#goods.step =< 4 andalso GoodsInfo#goods.grade =< 20 ->
			skip;
		true ->
			Data = [PlayerStatus#player.id,PlayerStatus#player.nickname,GoodsInfo#goods.id,GoodsInfo#goods.goods_id,GoodsInfo#goods.step,GoodsInfo#goods.grade,GoodsInfo#goods.spirit],
			db_agent:log_practise(Data)
	end,
	ok.

%% 法宝融合日志
log_merge(PlayerStatus,GoodsInfo1,GoodsInfo2)->
	Data = [PlayerStatus#player.id,PlayerStatus#player.nickname,GoodsInfo1#goods.id,GoodsInfo1#goods.goods_id,GoodsInfo1#goods.step,GoodsInfo1#goods.grade,GoodsInfo1#goods.spirit,GoodsInfo2#goods.id,GoodsInfo2#goods.goods_id,GoodsInfo2#goods.step,GoodsInfo2#goods.grade,GoodsInfo2#goods.spirit],
	db_agent:log_merge(Data),
	ok.

%% 装备洗炼日志
log_wash(PlayerStatus, GoodsInfo, Cost) ->
    Data = [PlayerStatus#player.id, PlayerStatus#player.nickname, GoodsInfo#goods.id, GoodsInfo#goods.goods_id, GoodsInfo#goods.subtype, GoodsInfo#goods.level, GoodsInfo#goods.color, Cost ],
    db_agent:log_wash(Data),
    ok.

%% 紫装融合日志
log_suitmerge(PlayerStatus,GoodsInfo1,GoodsInfo2,GoodsInfo3,Suit_id,Cost) ->
	Data = [PlayerStatus#player.id,PlayerStatus#player.nickname,GoodsInfo1#goods.id,GoodsInfo1#goods.goods_id,GoodsInfo2#goods.id,GoodsInfo2#goods.goods_id,GoodsInfo3#goods.id,GoodsInfo3#goods.goods_id,Suit_id,Cost],
	db_agent:log_suitmerge(Data),
	ok.

%% 消费日志
%% log_consume(Type, GoodsInfo, PlayerStatus, NewPlayerStatus) ->
%%     ConsumeType = goods_util:get_consume_type(Type),
%%     Cost_coin = PlayerStatus#player.coin - NewPlayerStatus#player.coin,
%%     Cost_cash = PlayerStatus#player.cash - NewPlayerStatus#player.cash,
%%     Cost_gold = PlayerStatus#player.gold - NewPlayerStatus#player.gold,
%%     Cost_bcoin = PlayerStatus#player.bcoin - NewPlayerStatus#player.bcoin,
%%     Remain_coin = NewPlayerStatus#player.coin,
%%     Remain_cash = NewPlayerStatus#player.cash,
%%     Remain_gold = NewPlayerStatus#player.gold,
%%     Remain_bcoin = NewPlayerStatus#player.bcoin,
%%     Data = [ConsumeType, PlayerStatus#player.id, PlayerStatus#player.nickname, GoodsInfo#goods.id, GoodsInfo#goods.goods_id, GoodsInfo#goods.subtype, GoodsInfo#goods.level, GoodsInfo#goods.color, Cost_coin, Cost_cash, Cost_gold, Cost_bcoin, Remain_coin, Remain_cash, Remain_gold, Remain_bcoin ],
%%     db_agent:log_consume(Data),
%%     ok.

%% 五彩炼炉合成日志
log_icompose(PlayerStatus,Rule,Ratio,Ram,Cost,Status) ->
	Data = [PlayerStatus#player.id,PlayerStatus#player.nickname,Rule#ets_base_goods_icompose.goods_id,Ratio,Ram,Cost,Status],
	db_agent:log_icompose(Data),
	ok.

%% 五彩练炉分解日志
log_idecompose(PlayerStatus,LogList,Cost,Status)->
	Data = [PlayerStatus#player.id,PlayerStatus#player.nickname,util:term_to_string(LogList),0,Cost,Status],
	db_agent:log_idecompose(Data),
	ok.

%% 精炼日志
log_refine(PlayerStatus,GoodsInfo,New_goods_id,Cost,Status) ->
	Data = [PlayerStatus#player.id,PlayerStatus#player.nickname,GoodsInfo#goods.goods_id,GoodsInfo#goods.id,New_goods_id,Cost,Status],
	db_agent:log_refine(Data),
	ok.

%% 淬炼日志
log_smelt(PlayerStatus,GoodsInfo,Gid_list,Goods_id_list,Repair) ->
	Data = [PlayerStatus#player.id,PlayerStatus#player.nickname,GoodsInfo#goods.id,Gid_list,Goods_id_list,Repair],
	db_agent:log_smelt(Data),
	ok.

%%商城npc购买日志记录 
%%shoptype 商店类型
%%shopsubtype 商店子类型
%%pricetype  '价格类型：1 铜钱, 2 银两，3 金币，4 绑定的铜钱'
log_shop([ShopType,ShopSubtype,PlayerId,NickName,GoodsId,PriceType,Price,Num]) ->
	db_agent:log_shop([ShopType,ShopSubtype,PlayerId,NickName,GoodsId,PriceType,Price,Num]).
	
%%物品使用日志记录
log_use([Player_id,Nickname,Gid,Goods_id,Type,Subtype,Num]) ->
	Skip = lists:member(Goods_id, [23000,23001,23002,23003,23004,23005,23006,23007,23008,23009,23010,
							   		 23011,23012,23013,23014,23100,23101,23102,23103,23104,23105,23106,23107,
								     23108,23109,23200,23201,23202,23203,23204,23205,23300,23301,23400,23401,23403,23404,23406,23407,23501,23502]),
	if
		Skip ->
			skip;
		true ->
			db_agent:log_use([Player_id,Nickname,Gid,Goods_id,Type,Subtype,Num])
	end.

%%获取购买日志
get_shop_log(Player_id,Goods_id,Shop_type,Shop_subtype) ->
	db_agent:get_shop_log(Player_id,Goods_id,Shop_type,Shop_subtype).

%%角色升级日志
log_uplevel(Player,Exp,From) ->
	if
		Player#player.lv >= 20 ->
			db_agent:log_uplevel([Player#player.id,Player#player.lv,Player#player.exp,Player#player.spirit,Player#player.scene,Player#player.x,Player#player.y,Exp,From]);
		true ->
			skip
	end.

%%物品丢弃日志
%%type 1自己丢弃2npc商店卖掉 3物品过期被删除
log_throw([Player_id,Nickname,Gid,Goods_id,Color,Stren,Bind,Type,Num,AttrsStr]) ->
	db_agent:log_throw([Player_id,Nickname,Gid,Goods_id,Color,Stren,Bind,Type,Num,AttrsStr]).

%%矿石产出日志
log_ore([Goods_id,Player_id])->
	db_agent:log_ore([Goods_id,Player_id]).

%%玩家物品记录
log_goods_list([Player_id,Goods_info_list]) ->
	db_agent:log_goods_list([Player_id,Goods_info_list]).
%%获取玩家物品快照
get_log_goods_list(Player_id) ->
	db_agent:get_log_goods_list(Player_id).

%%记录物品差异日志
log_goods_diff([Player_id,T,Goods_id,Gid,Dum,Mnum])->
	db_agent:log_goods_diff([Player_id,T,Goods_id,Gid,Dum,Mnum]).

%%记录时装洗炼日志
log_fashion(Player_Id,GoodsId,StoneId,Old_Goods_attributList,New_Goods_attributList,Cost) ->
	db_agent:log_fashion([Player_Id,GoodsId,StoneId,Old_Goods_attributList,New_Goods_attributList,Cost]).

%%装备附魔和回洗日志
log_magic(Player_Id,GoodsId,GoodsType,StoneId,Old_Goods_attributList,Goods_attributList,Is_Bind,Cost,Is_Oper) ->
	db_agent:log_magic([Player_Id,GoodsId,GoodsType,StoneId,Old_Goods_attributList,Goods_attributList,Is_Bind,Cost,Is_Oper]). 

%%70炼化日志
log_equipsmelt(Player_id,NickName,Gid,Goods_id,JP,MY,Ff) ->
	db_agent:log_equipsmelt([Player_id,NickName,Gid,Goods_id,JP,MY,Ff]).

	
