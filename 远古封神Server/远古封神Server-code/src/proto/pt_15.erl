%%%-----------------------------------
%%% @Module  : pt_15
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 15物品信息
%%%-----------------------------------
-module(pt_15).
-include("common.hrl").
-include("record.hrl").
-export([read/2, write/2, get_goods_info/3]).
 
%%
%%客户端 -> 服务端 ----------------------------
%%

%%查询物品详细信息
read(15000, <<GoodsId:32, Location:16>>) ->
    {ok, [GoodsId, Location]};

%%查询别人物品详细信息
read(15001, <<Owner:32, GoodsId:32>>) ->
    {ok, [Owner, GoodsId]};

%% 查看地上的掉落包
read(15002, <<DropId:32>>) ->
    {ok, DropId};

%%查询别人离线物品详细信息
read(15003, <<Owner:32, GoodsId:32>>) ->
    {ok, [Owner, GoodsId]};

%%查看物品类型高级信息
read(15004,<<Goods_id:32>>) ->
	{ok,[Goods_id]};

%%极品装备预览
read(15006,<<GoodsId:32>>) ->
	{ok,[GoodsId]};

%%查询物品列表
read(15010, <<Location:16>>) ->
    {ok, Location};

%%查看别人身上装备列表
read(15011, <<PlayerId:32>>) ->
    {ok, PlayerId};

%%获取要修理装备列表
read(15012, _R) ->
    {ok, mend_list};

%% 取商店物品列表
read(15013, <<ShopType:16, ShopSubtype:16>>) ->
    {ok, [ShopType, ShopSubtype]};

%% 列出背包打造装备列表
read(15014, <<Position:8>>) ->
    {ok, [Position]};

%% 列出打造装备位置约定信息
read(15015,<<Position:16>>) ->
	{ok,[Position]};

%% 列出物品cd列表
read(15016,_R) ->
	{ok,cd_list};

%% 获取位置全部物品信息
read(15017,<<Location:16>>) ->
	{ok,[Location]};
	
%%购买物品
read(15020, <<GoodsTypeId:32, GoodsNum:16, ShopType:16,ShopSubtype:16>>) ->
    {ok, [GoodsTypeId, GoodsNum, ShopType ,ShopSubtype]};

%%出售物品
read(15021, <<GoodsId:32, GoodsNum:16>>) ->
    {ok, [GoodsId, GoodsNum]};

%%扩充背包或仓库
read(15022, <<Location:8>>) ->
    {ok, [Location]};

%%拆分物品
read(15023,<<GoodsId:32,Num:16,Pos:16>>) ->
	{ok,[GoodsId,Num,Pos]};

%%装备物品
read(15030, <<GoodsId:32, Cell:16>>) ->
    {ok, [GoodsId, Cell]};

%%卸下装备
read(15031, <<GoodsId:32>>) ->
    {ok, GoodsId};

%%修理装备
read(15033, <<GoodsId:32>>) ->
    {ok, GoodsId};

%% 商城搜索
read(15034, <<Bin/binary>>) ->
	{GoodsName,_} = pt:read_string(Bin),	
     {ok, [GoodsName]};

%%背包拖动物品
read(15040, <<GoodsId:32, OldCell:16, NewCell:16>>) ->
    {ok, [GoodsId, OldCell, NewCell]};

%%物品存入仓库
read(15041, <<GoodsId:32, GoodsNum:16>>) ->
    {ok, [GoodsId, GoodsNum]};

%%物品从仓库取出
read(15042, <<GoodsId:32, GoodsNum:16>>) ->
    {ok, [GoodsId, GoodsNum]};

%%物品从临时矿包取出
read(15043,<<GoodsId:32,GoodsNum:16>>) ->
	{ok,[GoodsId,GoodsNum]};

%%物品从农场背包取出
read(15044,<<Num:16,Bin/binary>>)->
	F = fun(_, [Bin1,L]) ->
        <<GoodsId:32, GoodsNum:16, Rest/binary>> = Bin1,
        L1 = [{GoodsId,GoodsNum}|L],
        [Rest, L1]
    end,
    [_, GoodsInfoList] = lists:foldl(F, [Bin,[]], lists:seq(1, Num)),
	{ok,[GoodsInfoList]};

%%使用物品
read(15050, <<GoodsId:32, GoodsNum:16>>) ->
    {ok, [GoodsId, GoodsNum]};

%%丢弃物品
read(15051, <<GoodsId:32, GoodsNum:16>>) ->
    {ok, [GoodsId, GoodsNum]};

%% 整理背包
read(15052, _R) ->
    {ok, clean};

%% 拣取地上掉落包的物品
read(15053, <<DropId:32, GoodsTypeId:32>>) ->
    {ok, [DropId, GoodsTypeId]};

%% 节日道具使用
read(15054,<<GoodsId:32,GoodsNum:16,Bin/binary>>) ->
	{Nickname,_} = pt:read_string(Bin),
	{ok,[GoodsId,GoodsNum,Nickname]};

%% 屏幕弹出框
read(15056,<<Type:8,PlayerId:32,Bin/binary>>) ->
	{Msg,_} = pt:read_string(Bin),
	{ok,[Type,PlayerId,Msg]};

%% 装备精炼
read(15057,<<Gid:32,Num:16,Bin/binary>>) ->
	F = fun(_, [Bin1,L]) ->
        <<GoodsId:32, GoodsNum:16, Rest/binary>> = Bin1,
        L1 = [[GoodsId,GoodsNum]|L],
        [Rest, L1]
    end,
    [_, StoneList] = lists:foldl(F, [Bin,[]], lists:seq(1, Num)),
	{ok,[Gid,StoneList]};

%% 装备分解/预览
read(15058,<<Type:8,Num:16,Bin/binary>>) ->
	F = fun(_, [Bin1,L]) ->
        <<Gid:32,Rest/binary>> = Bin1,
        L1 = [Gid|L],
        [Rest, L1]
    end,
    [_, GoodsList] = lists:foldl(F, [Bin,[]], lists:seq(1, Num)),
	{ok,[Type,GoodsList]};

%% 材料合成
read(15059,<<Mid:8,Num:16>>) ->
	{ok,[Mid,abs(Num)]};
%% 
%% 紫装融合预览
read(15060,<<Gid1:32,Gid2:32,Gid3:32>>)->
	{ok,[Gid1,Gid2,Gid3]};

%% 紫装融合
read(15061,<<Gid1:32,Gid2:32,Gid3:32>>) ->
	{ok,[Gid1,Gid2,Gid3]};

%% 装备强化
read(15062, <<GoodsId:32, StoneId:32, RuneId1:32,Num1:16, RuneId2:32,Num2:16, RuneId3:32,Num3:16, RuneId4:32,Num4:16,Protect:32,StoneTypeId:32,Auto_purch:8>>) ->
    {ok, [GoodsId, StoneId, RuneId1,Num1,RuneId2,Num2,RuneId3,Num3,RuneId4,Num4,Protect,StoneTypeId,Auto_purch]};

%% 装备打孔
read(15063, <<GoodsId:32, RuneId:32, StoneTypeId:32, Auto_purch:8>>) ->
    {ok, [GoodsId, RuneId, StoneTypeId, Auto_purch]};

%% 宝石合成
read(15064, <<RuneId:32, StoneTypeId:32, RuneTypeId:32, Auto_purch:8, Num:16, Bin/binary>>) ->
    F = fun(_, [Bin1,L]) ->
        <<GoodsId:32, GoodsNum:16, Rest/binary>> = Bin1,
        L1 = [[GoodsId,GoodsNum]|L],
        [Rest, L1]
    end,
    [_, StoneList] = lists:foldl(F, [Bin,[]], lists:seq(1, Num)),
    {ok, [RuneId, StoneTypeId, RuneTypeId, Auto_purch,StoneList]};

%% 宝石镶嵌
read(15065, <<GoodsId:32, StoneId:32, StoneTypeId:32, Auto_purch:8, Num:16, Bin/binary>>) ->
    F = fun(_, [Bin1,L]) ->
        <<RuneId:32, RuneNum:16, Rest/binary>> = Bin1,
        L1 = [[RuneId,RuneNum]|L],
        [Rest, L1]
    end,
    [_, RuneList] = lists:foldl(F, [Bin,[]], lists:seq(1, Num)),
    {ok, [GoodsId, StoneId, StoneTypeId, Auto_purch, RuneList]};

%% 宝石摘除
read(15066, <<GoodsId:32,StoneId:32,StoneTypeId:32,Auto_purch:8,Num:16,Bin/binary>>) ->
    F = fun(_,[Bin1,L]) ->
				<<RuneId:32,RuneNum:16,Rest/binary>> = Bin1,
				L1=[[RuneId,RuneNum]|L],
				[Rest,L1]
		end,
	[_,RuneList] = lists:foldl(F,[Bin,[]],lists:seq(1,Num)),
    {ok, [GoodsId,StoneId,StoneTypeId,Auto_purch,RuneList]};

%% 洗附加属性
read(15067, <<GoodsId:32, RuneId:32>>) ->
    {ok, [GoodsId, RuneId]};

%%鉴定属性
read(15068, <<GoodsId:32,StoneId:32,StoneTypeId:32,Auto_purch:8>>) ->
	{ok,[GoodsId,StoneId,StoneTypeId,Auto_purch]};

%%法宝修炼
read(15069,<<GoodsId:32,Type:8>>)->
	{ok,[GoodsId,Type]};
%%法宝融合
read(15070,<<GoodsId1:32,GoodsId2:32>>) ->
	{ok,[GoodsId1,GoodsId2]};

%% ------------------------------------
%% 15071 批量购买商店物品
%% ------------------------------------
read(15071, <<ShopType:16, ShopSubType:16, Len:16, Bin/binary>>) ->
	F = fun(_Elem, {TB, Result}) ->
				<<BaseGoodsId:32, Num:16, RestTB/binary>> = TB,
				{ok, {RestTB, [{BaseGoodsId, Num}|Result]}}
		end,
	{ok, {_, GoodsList}} = util:for_new(1, Len, F, {Bin, []}),
	{ok, [ShopType, ShopSubType, GoodsList]};

%% ------------------------------------
%% 15072 批量出售物品
%% ------------------------------------
read(15072, <<Len:16, Bin/binary>>) ->
	Fun = fun(_Elem, {TB, Result}) ->
				<<GoodsId:32, Num:16, RestTB/binary>> = TB,
				{ok, {RestTB, [{GoodsId, Num}|Result]}}
		  end,
	{ok, {_, GoodsList}} = util:for_new(1, Len, Fun, {Bin, []}),
	{ok, [GoodsList]};

%% %% -------------------------------------------------------------
%% %% 15073 查询物品详细信息(拍卖或者交易的时候用到的查看物品信息)
%% %% -------------------------------------------------------------
%% read(15073, <<GoodsId:32>>) ->
%%     {ok, [GoodsId]};

%%法宝融合预览
read(15074,<<GoodsId1:32,GoodsId2:32>>) ->
	{ok,[GoodsId1,GoodsId2]};

%% 神装炼化
read(15075,<<GoodsId:32,Type:8,Num:16,Bin/binary>>) ->
	F = fun(_, [Bin1,L]) ->
        <<GId:32,N:16,Rest/binary>> = Bin1,
        L1 = [{GId,N}|L],
        [Rest, L1]
    end,
    [_, GoodsList] = lists:foldl(F, [Bin,[]], lists:seq(1, Num)),
	{ok,[GoodsId,Type,GoodsList]};

%%装备评价
read(15080,<<GoodsId:32>>)->
	{ok,[GoodsId]};

%%60套紫装淬炼
read(15081,<<GoodsId:32,Num:16,Bin/binary>>)->
	F = fun(_, [Bin1,L]) ->
        <<GId:32,Rest/binary>> = Bin1,
        L1 = [GId|L],
        [Rest, L1]
    end,
    [_, GoodsList] = lists:foldl(F, [Bin,[]], lists:seq(1, Num)),
	{ok,[GoodsId,GoodsList]};

%%各种卡号使用
read(15090,<<Bin/binary>>) ->
	{CardString,_} = pt:read_string(Bin),
	{ok,[CardString]};

%%各种卡号查询
read(15091,_R) ->
	{ok,[]};

%% 中秋活动物品领取状况
read(15092 ,<<Type:8>>) ->
	{ok,[Type]};

%% 中秋活动领取物品
read(15093,<<Type:8>>) ->
	{ok,[Type]};

%% 兑换物品
read(15094,<<Type:16>>) ->
	{ok,[Type]};

%% 临时活动
read(15095,<<Type:8,Num:16,Bin/binary>>) ->
	F = fun(_,[Bin1,L]) ->
				<<Gid:32,Rest/binary>> = Bin1,
				L1 = [Gid|L],
				[Rest,L1]
		end,
	[_,GoodsList] = lists:foldl(F, [Bin,[]], lists:seq(1, Num)),
	{ok,[Type,GoodsList]};

%%%%领取5级强化护腕
read(15096,_R) ->
	{ok,[_R]};

%% 领取5级强化护腕 预览
read(15097,_R) ->
	{ok,[_R]};

%% 充值祈福
read(15098,<<Type:8>>) ->
	{ok,[Type]};

%%查询vip背包使用权限
read(15100,[])->
	{ok,[]};

%%兑换魅力称号
read(15120,<<TitleId:32>>)->
	{ok,[TitleId]};

%%时装洗炼Oper为预览(1),洗炼(2)
read(15130,<<GoodsId:32,StoneId:32,Oper:8,StoneTypeId:32,Auto_purch:8>>) ->
	{ok,[GoodsId,StoneId,Oper,StoneTypeId,Auto_purch]};

%%Oper替换新的洗炼属性(1)或维持原因属性(0)
read(15131,<<GoodsId:32,Oper:8>>) ->
	{ok,[GoodsId,Oper]};

%%紫戒指祝福,ClassOrMagicId(是祝福碎片或是遗忘符咒),Oper(1为祝福,2为遗弃)
read(15132,<<GoodsId:32, Oper:8, Num:16, Bin/binary>>) ->
	 F = fun(_, [Bin1,L]) ->
        <<ClassOrMagicId:32, ClassOrMagicNum:8, Rest/binary>> = Bin1,
        L1 = [{ClassOrMagicId,ClassOrMagicNum}|L],
        [Rest, L1]
    end,
    [_, ClassOrMagicList] = lists:foldl(F, [Bin,[]], lists:seq(1, Num)),
    {ok, [GoodsId, Oper, ClassOrMagicList]};

%%装备附魔或回光(Oper 1为附魔,2为预览)
read(15133,<<GoodsId:32,MagicStoneId:32,MagicStoneTypeId:32,Auto_purch:8,Oper:8,Num:16,Bin/binary>>) ->
	F = fun(_, [Bin1,L]) ->
        <<PropId:16,Value:16,Rest/binary>> = Bin1,
        L1 = [{PropId,Value}|L],
        [Rest, L1]
    end,
    [_, PropsList] = lists:foldl(F, [Bin,[]], lists:seq(1, Num)),
	{ok,[GoodsId,MagicStoneId,MagicStoneTypeId,Auto_purch,Oper,PropsList]};

%%Oper替换新的洗炼属性(1)或维持原因属性(0)
read(15134,<<GoodsId:32,Oper:8>>) ->
	{ok,[GoodsId,Oper]};


%% ------------------------------------
%% 15142 获取衣橱已激活的图鉴数据
%% ------------------------------------
read(15142, _R) ->
	{ok, []};

%% ------------------------------------
%% 15143 时装换装请求
%% ------------------------------------
read(15143, <<Type:8, FashionId:32>>) ->
	{ok, [Type, FashionId]};

%%开服充值反馈%%
read(15200,<<Type:8,GoodsType:32>>) ->
	{ok,[Type,GoodsType]};

read(_Cmd, _R) ->
	%%io:format("read: ~p~n",[[_Cmd, _R]]),
	{error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%%查询自己物品详细信息
write(15000, [GoodsInfo, SuitNum, AttributeList]) ->
	Data = get_goods_info(GoodsInfo, SuitNum, AttributeList),
	{ok, pt:pack(15000, Data)};

%%查询别人物品详细信息
write(15001, [GoodsInfo, SuitNum, AttributeList]) ->
	Data = get_goods_info(GoodsInfo, SuitNum, AttributeList),
	{ok, pt:pack(15001, Data)};
	
%% 查看地上的掉落包
write(15002, [Res, DropId, DropInfo]) ->
    ListNum = length(DropInfo),
    F = fun({GoodsTypeId, _GoodsType, GoodsNum, _GoodsColor, _MonType}) ->
            <<GoodsTypeId:32, GoodsNum:16>>		
        end,
    ListBin = tool:to_binary(lists:map(F, DropInfo)),
    {ok, pt:pack(15002, <<Res:16, DropId:32, ListNum:16, ListBin/binary>>)};

%%查询别人离线物品详细信息
write(15003, [GoodsInfo, SuitNum, AttributeList]) ->
	Data = get_goods_info(GoodsInfo, SuitNum, AttributeList),
	{ok, pt:pack(15003, Data)};

%% 获取物品类型高级信息
write(15004,[GoodsInfo,SuitNum,AttributeList]) ->
	Data = get_goods_info(GoodsInfo,SuitNum,AttributeList),
	{ok,pt:pack(15004,Data)};

%% 更新背包物品信息
write(15005,[GoodsList]) ->
	ListNum = length(GoodsList),
	F = fun(GoodsInfo) ->
            GoodsId = GoodsInfo#goods.id,
            TypeId = GoodsInfo#goods.goods_id,
            Cell = GoodsInfo#goods.cell,
            GoodsNum = GoodsInfo#goods.num,
			Bind = GoodsInfo#goods.bind,
			Stren = GoodsInfo#goods.stren,
			Icon = GoodsInfo#goods.icon,
            <<GoodsId:32, TypeId:32, Cell:16, GoodsNum:16,Bind:8,Stren:8,Icon:32>>
        end,
   	ListBin = tool:to_binary(lists:map(F, GoodsList)),
	{ok,pt:pack(15005,<<ListNum:16,ListBin/binary>>)};

%%极品装备预览
write(15006,[GoodsInfo,AttributeList]) ->
	Data = get_goods_info(GoodsInfo, 0, AttributeList),
	{ok, pt:pack(15006, Data)};

%%查询玩家物品列表
write(15010, [Location, CellNum, Coin,Bcoin,Cash, Gold,CanSellBcoinNum,CanSellCoinNum,GoodsList]) ->
    ListNum = length(GoodsList),
	F = fun(GoodsInfo) ->
            GoodsId = GoodsInfo#goods.id,
            TypeId = GoodsInfo#goods.goods_id,
            Cell = GoodsInfo#goods.cell,
            GoodsNum = GoodsInfo#goods.num,
			Bind = GoodsInfo#goods.bind,
			Stren = GoodsInfo#goods.stren,
			Icon = GoodsInfo#goods.icon,
            <<GoodsId:32, TypeId:32, Cell:16, GoodsNum:16,Bind:8,Stren:8,Icon:32>>
        end,
   	ListBin = tool:to_binary(lists:map(F, GoodsList)),
    {ok, pt:pack(15010, <<Location:16, CellNum:16, Coin:32,Bcoin:32, Cash:32, Gold:32,CanSellBcoinNum:16,CanSellCoinNum:16,ListNum:16, ListBin/binary>>)};

%%查看别人身上装备列表
write(15011, [Res, PlayerId, GoodsList,Fasheffect])  ->
    ListNum = length(GoodsList),
    F = fun(GoodsInfo) ->
            GoodsId = GoodsInfo#goods.id,
            TypeId = GoodsInfo#goods.goods_id,
            Cell = GoodsInfo#goods.cell,
            GoodsNum = GoodsInfo#goods.num,
			Bind = GoodsInfo#goods.bind,
			Stren = GoodsInfo#goods.stren,
			Icon = GoodsInfo#goods.icon,
            <<GoodsId:32, TypeId:32, Cell:16, GoodsNum:16,Bind:8,Stren:8,Icon:32>>
        end,
    ListBin = tool:to_binary(lists:map(F, GoodsList)),
    {ok, pt:pack(15011, <<Res:16, PlayerId:32, Fasheffect:8, ListNum:16, ListBin/binary>>)};

%%获取要修理装备列表
write(15012, MendList) ->
    ListNum = length(MendList),
    F = fun([GoodsId, TypeId, Attrition, Cost]) ->
            <<GoodsId:32, TypeId:32, Attrition:16, Cost:32>>
        end,
    ListBin = tool:to_binary(lists:map(F, MendList)),
    {ok, pt:pack(15012, <<ListNum:16, ListBin/binary>>)};

%%取商店物品列表
write(15013, [PlayerId, ShopType, ShopSubtype, ShopList, Result]) ->
    ListNum = length(ShopList),
%% 	?DEBUG("PT_15, ShopList = ~p~n",[ShopList]),
	Is_Fst_Shop = mod_fst:is_fst_shop(ShopType),
	if
		%%特惠区特殊处理
		ShopType =:=1 andalso ShopSubtype =:= 6 ->
			F_th=fun({Goods_id,Num,Lt}) ->
				<<Goods_id:32,Num:16,Lt:32>>
				 end,
			ListBin = tool:to_binary(lists:map(F_th, ShopList));
		%%神秘商店
		Is_Fst_Shop ->
			F_th=fun({Goods_id,Num}) ->%%神秘商店没有剩余时间
				<<Goods_id:32,Num:16,0:32>> 
				 end,
			ListBin = tool:to_binary(lists:map(F_th, ShopList));
		true ->
    		F = fun(ShopInfo) ->
			%%对特惠区返回物品剩余数量
					if
						%%ShopInfo#ets_shop.shop_type =:= 1 andalso ShopInfo#ets_shop.shop_subtype =:= 6 ->
						%%	Goods_id = ShopInfo#ets_shop.goods_id,
						%%	<<Goods_id:32,9999:16>>;
						%%封神礼包购买过不显示
						ShopInfo#ets_shop.goods_id =:= 28118 ->
							BuyLog = log:get_shop_log(PlayerId,ShopInfo#ets_shop.goods_id,ShopType,ShopSubtype),
							case length(BuyLog) > 0 of
								true->
									<<0:32,0:16,0:32>>;
								false ->
									<<28118:32,0:16,0:32>>
							end;
						true ->
%% 							?DEBUG("ShopInfo = ~p~n",[ShopInfo]),
							Goods_id = ShopInfo#ets_shop.goods_id,
							<<Goods_id:32,0:16,0:32>>
					end					
        		end,
    		ListBin = tool:to_binary(lists:map(F, ShopList))
	end,
    {ok, pt:pack(15013, <<ShopType:16, ShopSubtype:16, ListNum:16, ListBin/binary, Result:8>>)};

%%列出背包打造装备列表
write(15014, EquipList) ->
    ListNum = length(EquipList),
    F = fun(GoodsInfo) ->
            GoodsId = GoodsInfo#goods.id,
            Hole = GoodsInfo#goods.hole,
            Stren = GoodsInfo#goods.stren,
			FailNum = GoodsInfo#goods.stren_fail ,
			NoIdentify = goods_util:count_noidentify_num(GoodsInfo),
			InlayNum = goods_util:count_inlay_num(GoodsInfo),
            <<GoodsId:32, Hole:16, Stren:16,FailNum:16,NoIdentify:16,InlayNum:16>>
        end,
    ListBin = tool:to_binary(lists:map(F, EquipList)),
    {ok, pt:pack(15014, <<ListNum:16, ListBin/binary>>)};

%%列出装备打造位置约定信息
write(15015,[Position,GoodsList]) ->
	ListNum = length(GoodsList),
	F = fun(GoodsInfo) ->
				GoodsId = GoodsInfo#goods.id,
				Bind = GoodsInfo#goods.bind,
				<<GoodsId:32,Bind:16>>
		end,
	ListBin = tool:to_binary(lists:map(F,GoodsList)),
	{ok,pt:pack(15015,<<Position:16,ListNum:16,ListBin/binary>>)};

%%列出cd列表
write(15016,[Res,CdList]) ->
	ListNum = length(CdList),
	Time = util:unixtime(),
	F = fun(GoodsCd) ->
				Goods_Id = GoodsCd#ets_goods_cd.goods_id,
				ExpireTime = GoodsCd#ets_goods_cd.expire_time - Time,
				<<Goods_Id:32,ExpireTime:32>>
		end,
	ListBin = tool:to_binary(lists:map(F, CdList)),
	{ok,pt:pack(15016,<<Res:16,ListNum:16,ListBin/binary>>)};

%%获取位置全部物品全部信息
write(15017,[Res,Location,AllGoodsInfoList]) ->
	ListNum = length(AllGoodsInfoList),
	F = fun(AllGoodsInfo) ->
				case AllGoodsInfo of
					[GoodsInfo, SuitNum, AttributeList] ->
						get_goods_info(GoodsInfo,SuitNum,AttributeList);
					_ ->
						<<>>
				end
		end,
	ListBin = tool:to_binary(lists:map(F, AllGoodsInfoList)),
	{ok,pt:pack(15017,<<Res:16,Location:16,ListNum:16,ListBin/binary>>)};

%% 弹出获得物品列表 
write(15018,[GoodsList]) ->
	ListNum = length(GoodsList),
	F = fun(GoodsInfo) ->
				[Goods_id,Num] = GoodsInfo,
				<<Goods_id:32,Num:16>>
		end,
	ListBin = tool:to_binary(lists:map(F, GoodsList)),
	{ok,pt:pack(15018,<<ListNum:16,ListBin/binary>>)};

%%购买物品
write(15020, [Res, GoodsTypeId, GoodsNum, ShopType, NewCoin,NewBcoin,NewCash, NewGold,Score,GoodsList]) ->
    ListNum = length(GoodsList),
    F = fun(GoodsInfo) ->
            GoodsId = GoodsInfo#goods.id,
            TypeId = GoodsInfo#goods.goods_id,
            Cell = GoodsInfo#goods.cell,
            Num = GoodsInfo#goods.num,
			Bind = GoodsInfo#goods.bind,
            %io:format("list: ~p~n",[[GoodsId, TypeId, Cell, Num]]),
            <<GoodsId:32, TypeId:32, Cell:16, Num:16,Bind:8>>
        end,
    ListBin = tool:to_binary(lists:map(F, GoodsList)),
    {ok, pt:pack(15020, <<Res:16, GoodsTypeId:32, GoodsNum:16, ShopType:16, NewCoin:32,NewBcoin:32, NewCash:32, NewGold:32,Score:32, ListNum:16, ListBin/binary>>)};

%%出售物品
write(15021, [Res, GoodsId, GoodsNum, Coin ,Bcoin]) ->
    {ok, pt:pack(15021, <<Res:16, GoodsId:32, GoodsNum:16, Coin:32,Bcoin:32>>)};

%%扩充背包或仓库
write(15022, [Loc, Res, Gold, NewCellNum]) ->
    {ok, pt:pack(15022, <<Loc:8, Res:8, Gold:32,NewCellNum:16>>)};

%%拆分物品
write(15023,[Res]) ->
	{ok,pt:pack(15023,<<Res:16>>)};

%%装备物品
write(15030, [Res, GoodsId, OldGoodsId, OldGoodsTypeId, OldGoodsCell, Effect]) ->
    [Hp, Mp, MaxAtt,MinAtt,Def, Hit, Dodge, Crit, Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil,_Anti_rift] = case length(Effect) =:= 14 of
                                                        true -> Effect;
                                                        false -> [0, 0, 0, 0, 0, 0, 0, 0,0,0,0,0,0,0]
                                                end,
    {ok, pt:pack(15030, <<Res:16, GoodsId:32, OldGoodsId:32, OldGoodsTypeId:32, OldGoodsCell:16, 
						  Hp:32, Mp:32, MaxAtt:16,MinAtt:16, Def:16, Hit:16, Dodge:16, Crit:16,Anti_wind:16,Anti_fire:16,Anti_water:16,Anti_thunder:16,Anti_soil:16>>)};

%%卸下装备
write(15031, [Res, GoodsId, TypeId, Cell]) ->
    {ok, pt:pack(15031, <<Res:16, GoodsId:32, TypeId:32, Cell:16>>)};

%%装备磨损
write(15032, GoodsList) ->
    ListNum = length(GoodsList),
    F = fun(GoodsInfo) ->
            GoodsId = GoodsInfo#goods.id,
            <<GoodsId:32>>
        end,
    ListBin = tool:to_binary(lists:map(F, GoodsList)),
    {ok, pt:pack(15032, <<ListNum:16, ListBin/binary>>)};

%%修理装备
write(15033, [Res, GoodsId, NewCoin,NewBcoin]) ->
    {ok, pt:pack(15033, <<Res:16, GoodsId:32, NewCoin:32,NewBcoin:32>>)};

%%商城搜索
write(15034,[Res,GoodsList]) ->
	ListNum = length(GoodsList),
	F = fun([Goods_Id,Subtype]) ->
				<<Goods_Id:32,Subtype:16>>
		end,
	ListBin = tool:to_binary(lists:map(F, GoodsList)),
	{ok,pt:pack(15034,<<Res:16,ListNum:16,ListBin/binary>>)};

%%背包拖动物品
write(15040, [Res, GoodsId1, GoodsTypeId1, OldCell, GoodsId2, GoodsTypeId2, NewCell]) ->
    {ok, pt:pack(15040, <<Res:16, GoodsId1:32, GoodsTypeId1:32, OldCell:16, GoodsId2:32, GoodsTypeId2:32, NewCell:16>>)};

%%物品存入仓库
write(15041, [Res, GoodsId, GoodsNum]) ->
    {ok, pt:pack(15041, <<Res:16, GoodsId:32, GoodsNum:16>>)};

%%物品从仓库取出
write(15042, [Res, GoodsId, GoodsList]) ->
    ListNum = length(GoodsList),
    F = fun(GoodsInfo) ->
            Id = GoodsInfo#goods.id,
            TypeId = GoodsInfo#goods.goods_id,
            Cell = GoodsInfo#goods.cell,
            Num = GoodsInfo#goods.num,
			Bind = GoodsInfo#goods.bind,
			Stren = GoodsInfo#goods.stren,
			Icon =  GoodsInfo#goods.icon,
            %io:format("list: ~p~n",[[Id, TypeId, Cell, Num]]),
            <<Id:32, TypeId:32, Cell:16, Num:16,Bind:8 ,Stren:8 ,Icon:32>>
        end,
    ListBin = tool:to_binary(lists:map(F, GoodsList)),
    {ok, pt:pack(15042, <<Res:16, GoodsId:32, ListNum:16, ListBin/binary>>)};

%%物品从临时矿包取出
write(15043,[Res]) ->
	{ok,pt:pack(15043,<<Res:8>>)};

%%农场仓库收取
write(15044,[Res]) ->
	{ok,pt:pack(15044,<<Res:8>>)};

%%使用物品
write(15050, [Res, GoodsId, GoodsTypeId, GoodsNum, Hp,Mp]) ->
    {ok, pt:pack(15050, <<Res:16, GoodsId:32, GoodsTypeId:32, GoodsNum:16, Hp:32, Mp:32>>)};

%%丢弃物品
write(15051, [Res, GoodsId, GoodsNum]) ->
    {ok, pt:pack(15051, <<Res:16, GoodsId:32, GoodsNum:16>>)};

%%整理背包
write(15052, GoodsList) ->
    ListNum = length(GoodsList),
    F = fun(GoodsInfo) ->
            GoodsId = GoodsInfo#goods.id,
            TypeId = GoodsInfo#goods.goods_id,
            Cell = GoodsInfo#goods.cell,
            Num = GoodsInfo#goods.num,
			Bind = GoodsInfo#goods.bind,
			Stren = GoodsInfo#goods.stren,
			Icon = GoodsInfo#goods.icon,
            %io:format("list: ~p~n",[[GoodsId, TypeId, Cell, Num]]),
            <<GoodsId:32, TypeId:32, Cell:16, Num:16,Bind:8,Stren:8,Icon:32>>
        end,
    ListBin = tool:to_binary(lists:map(F, GoodsList)),
    {ok, pt:pack(15052, <<ListNum:16, ListBin/binary>>)};

%% 拣取地上掉落包的物品
write(15053, [Res, DropId, GoodsTypeId]) ->
    {ok, pt:pack(15053, <<Res:16, DropId:32, GoodsTypeId:32>>)};

%% 使用节日道具
write(15054,[Res,FestivalType,GoodsId,NewNum]) ->
	{ok,pt:pack(15054,<<Res:8,FestivalType:8,GoodsId:32,NewNum:16>>)};

%% 物品使用右下角提示信息 
write(15055,[Msg])->
	Bin = tool:to_binary(Msg),
	BinLen = byte_size(Bin),
	{ok,pt:pack(15055,<<BinLen:16,Bin/binary>>)};

%% 屏幕弹出框
write(15056,[Type,ToID,FromLv,FromName,Msg,Sex,Career]) ->
	Bin = tool:to_binary(Msg),
	BinLen = byte_size(Bin),
	BinName = tool:to_binary(FromName),
	NameLen = byte_size(BinName),
	{ok,pt:pack(15056,<<Type:8,ToID:32,FromLv:8,NameLen:16,BinName/binary,BinLen:16,Bin/binary,Sex:8,Career:8>>)};

%%装备精炼
write(15057,[Res,Coin,Bcoin]) ->
	{ok,pt:pack(15057,<<Res:8,Coin:32,Bcoin:32>>)};

%%装备分解/预览
write(15058,[Res,Type,Cost,Glist]) ->
	F = fun({Goods_id,Num,Bind}) ->
				<<Goods_id:32,Num:16,Bind:8>>
		end,
	Glen = length(Glist),
	if
		Glen > 0 ->
			Gbin = tool:to_binary(lists:map(F, Glist));
		true ->
			Gbin = <<>>
	end,
	{ok,pt:pack(15058,<<Res:8,Type:8,Cost:32,100:8,Glen:16,Gbin/binary>>)};

%% 材料合成
write(15059,[Res,Snum,Fnum]) ->
	{ok,pt:pack(15059,<<Res:8,Snum:16,Fnum:16>>)};

%% 紫装融合预览
write(15060, [GoodsInfo,AttributeList]) ->
	Data = get_goods_info(GoodsInfo, 0, AttributeList),
	{ok, pt:pack(15060, Data)};

%% 紫装融合
write(15061,[Res]) ->
	{ok,pt:pack(15061,<<Res:8>>)};

%%装备强化
write(15062, [Res, GoodsId, NewStrengthen, NewCoin,NewBcoin,NewStoneNum,FailNum,RuneId1,Num1,RuneId2,Num2,RuneId3,Num3,RuneId4,Num4]) ->
    {ok, pt:pack(15062, <<Res:16, GoodsId:32, NewStrengthen:16,NewCoin:32,NewBcoin:32,NewStoneNum:16,FailNum:16,RuneId1:32,Num1:16,RuneId2:32,Num2:16,RuneId3:32,Num3:16,RuneId4:32,Num4:16>>)};

%%装备打孔
write(15063, [Res, GoodsId, NewHole, NewRuneNum, NewCoin,NewBcoin]) ->
    {ok, pt:pack(15063, <<Res:16, GoodsId:32, NewHole:16, NewRuneNum:16, NewCoin:32,NewBcoin:32>>)};

%%宝石合成
write(15064, [Res, NewGoodsTypeId]) ->
    {ok, pt:pack(15064, <<Res:16, NewGoodsTypeId:32>>)};

%%宝石镶嵌
write(15065, [Res, GoodsId, NewCoin,NewBcoin]) ->
    {ok, pt:pack(15065, <<Res:16, GoodsId:32, NewCoin:32,NewBcoin:32>>)};

%%宝石拆除
write(15066, [Res, GoodsId, NewCoin,NewBcoin,StoneId]) ->
    {ok, pt:pack(15066, <<Res:16, GoodsId:32, NewCoin:32,NewBcoin:32,StoneId:32>>)};

%%洗附加属性
write(15067, [Res, GoodsId, NewRuneNum, NewCoin,NewBcoin]) ->
    {ok, pt:pack(15067, <<Res:16, GoodsId:32, NewRuneNum:16, NewCoin:32,NewBcoin:32>>)};

%%鉴定属性
write(15068,[Res,GoodsId,StoneNum,AttributeList]) ->
	ListNum = length(AttributeList),
	F = fun(AttributeInfo) ->
           	AttributeId = AttributeInfo#goods_attribute.attribute_id,
			AttributeStatus = AttributeInfo#goods_attribute.status,
            <<AttributeId:16, AttributeStatus:16>>
         end,
    ListBin = tool:to_binary(lists:map(F, AttributeList)),
	
	{ok,pt:pack(15068,<<Res:16,GoodsId:32,StoneNum:16,ListNum:16,ListBin/binary>>)};

%%法宝修炼
write(15069,[Res,Spi]) ->
	Spi_bin = tool:to_binary(Spi),
	Spi_len = byte_size(Spi_bin),
	{ok,pt:pack(15069,<<Res:16,Spi_len:16,Spi_bin/binary>>)};

%%法宝融合
write(15070,[Res]) ->
	{ok,pt:pack(15070,<<Res:16>>)};

%% ------------------------------------
%% 15071 批量购买商店物品
%% ------------------------------------
write(15071, [Result, MoneyType, Money]) ->
	{ok, pt:pack(15071, <<Result:16, MoneyType:16, Money:32>>)};

%% ------------------------------------
%% 15072 批量出售物品
%% ------------------------------------
write(15072, [Result, MoneyType, Money]) ->
	{ok, pt:pack(15072, <<Result:16, MoneyType:16, Money:32>>)};

%% 融合预览
write(15074, [GoodsInfo, SuitNum, AttributeList]) ->
	Data = get_goods_info(GoodsInfo, SuitNum, AttributeList),
	{ok, pt:pack(15074, Data)};

%% 神装炼化
write(15075,[Res,Coin,Bcoin,Type,[GoodsInfo,SuitNum,AttributeList]]) ->
	Data =  get_goods_info(GoodsInfo, SuitNum, AttributeList),
	{ok,pt:pack(15075,<<Res:8 ,Coin:32,Bcoin:32,Type:8,1:16,Data/binary>>)};


%% 装备评价
write(15080, [Res, GoodsId, Score, Coin, Bcoin]) ->
    {ok, pt:pack(15080, <<Res:8, GoodsId:32, Score:32, Coin:32, Bcoin:32>>)};

%% 60套紫装淬炼
write(15081,[Res,Repair,Coin,Bcoin]) ->
	{ok,pt:pack(15081,<<Res:16,Repair:32,Coin:32,Bcoin:32>>)};


%% 各种卡号使用
write(15090,[Res]) ->
	{ok,pt:pack(15090,<<Res:8>>)};

%%查询玩家所有已使用过的卡key
write(15091,[XinShou,HuangShi,GuiZu,GongMin,ShouChong,VipLiBao]) ->
	{ok,pt:pack(15091,<<XinShou:8,ShouChong:8,VipLiBao:8,GongMin:8,GuiZu:8,HuangShi:8>>)};

%% 中秋活动物品领取状况
write(15092,[Type, Data, GState]) ->
	{ok,pt:pack(15092,<<Type:8, Data:32, GState:32>>)};

%% 领取中秋活动礼包
write(15093,[Type,Code]) ->
	{ok,pt:pack(15093,<<Type:8,Code:8>>)};

%% 兑换物品
write(15094,[Code]) ->
	{ok,pt:pack(15094,<<Code:8>>)};

%%临时活动
write(15095,[Code,Type,Score]) ->
	{ok,pt:pack(15095,<<Code:8,Type:8,Score:32>>)};

%%领取5级强化护腕
write(15096,[Code]) ->
	{ok,pt:pack(15096,<<Code:8>>)};

%%领取5级强化护腕 预览
write(15097,[GoodsInfo,SuitNum,AttributeList]) ->
	Data =  get_goods_info(GoodsInfo, SuitNum, AttributeList),
	{ok,pt:pack(15097,<<Data/binary>>)};

%% 充值祈福
write(15098,[Type,Code,Mult,Gold]) -> 
	{ok,pt:pack(15098,<<Type:8,Code:8,Mult:8,Gold:8>>)};

%% %% -------------------------------------------------------------
%% %% 15073 查询物品详细信息(拍卖或者交易的时候用到的查看物品信息)
%% %% -------------------------------------------------------------
%% write(15073, [GoodsInfo, SuitNum, AttributeList]) ->
%% 	Data = get_goods_info(GoodsInfo, SuitNum, AttributeList),
%% 	{ok, pt:pack(15073, Data)};

%%vip背包使用权限
write(15100,[Res])->
	{ok,pt:pack(15100,<<Res:16>>)};

%% 物品获取
write(15110, [GoodsTypeId, Nickname])->
	NewNickname = tool:to_binary(Nickname),
  	LenNickname = byte_size(NewNickname),
	{ok, pt:pack(15110, <<GoodsTypeId:32, LenNickname:16, NewNickname/binary>>)};

%%兑换魅力称号
write(15120,[Res,TitleId])->
	{ok,pt:pack(15120,<<Res:16, TitleId:32>>)};

%% 时装洗炼
write(15130,[Result,GoodsId,Is_wash,Cost,Coin,Bcoin,Goods_attributList]) ->
	Goods_attributListSize = length(Goods_attributList),
	if Goods_attributListSize == 0 ->
		   {ok, pt:pack(15130, <<Result:8,GoodsId:32,Is_wash:8,Cost:32,Coin:32,Bcoin:32,0:16,<<>>/binary>>)};
	   true ->
		   F = fun(D) ->
					   {Prop,Value} = D,
					   Prop1 = 
					   case Prop of
						    crit -> 7;
						    dodge -> 6;
						    def -> 4;
						    hit -> 5;
						    mp -> 2;
						    physique -> 9;
						    max_attack -> 8;
						    forza -> 15;
						    wit -> 17;
						    agile -> 16;
						    anti_wind -> 10;
						    anti_thunder -> 13;
						    anti_water -> 12;
						    anti_fire -> 11;
						    anti_soil -> 14;
						    hp -> 1;
						    anti_all -> 0;
						    att_per -> 21;
						    hp_per -> 22								  
					   end,
					   <<Prop1:16,Value:16>>
				end,
			Data = tool:to_binary([F(D) || D <- Goods_attributList]),	
		   {ok,pt:pack(15130,<<Result:8,GoodsId:32,Is_wash:8,Cost:32,Coin:32,Bcoin:32,Goods_attributListSize:16, Data/binary>>)}
	end;	


%% 时装洗炼
write(15131,[Result, GoodsId, _Goods_attributList]) ->
%% 	Goods_attributListSize = length(Goods_attributList),
%% 	if Goods_attributListSize == 0 ->
%% 		   {ok, pt:pack(15131, <<Result:8,0:16,<<>>/binary>>)};
%% 	   true ->
%% 		   F = fun(D) ->
%% 					   {Prop,Value} = D,
%% 					   Prop1 = 
%% 					   case Prop of
%% 						    crit -> 7;
%% 						    dodge -> 6;
%% 						    hit -> 5;
%% 						    mp -> 2;
%% 						    physique -> 9;
%% 						    max_attack -> 8;
%% 						    forza -> 15;
%% 						    wit -> 17;
%% 						    agile -> 16;
%% 						    anti_wind -> 10;
%% 						    anti_thunder -> 13;
%% 						    anti_water -> 12;
%% 						    anti_fire -> 11;
%% 						    anti_soil -> 14;
%% 						    hp -> 1
%% 					   end,
%% 					   <<Prop1:16,Value:16>>
%% 				end,
%% 			Data = tool:to_binary([F(D) || D <- Goods_attributList]),		   
%% 		   {ok,pt:pack(15131,<<Result:8,Goods_attributListSize:16, Data/binary>>)}
%% 	end;	
	 {ok, pt:pack(15131, <<Result:8,GoodsId:32>>)};

%%紫戒指祝福或遗弃
write(15132,[Result, GoodsId, Coin, Bcoin, Oper]) ->
	 {ok, pt:pack(15132, <<Result:8,GoodsId:32,Coin:32,Bcoin:32,Oper:8>>)};

%%装备附魔或预览
write(15133,[Result,GoodsId,Is_magic,Cost,Coin,Bcoin,Goods_attributList,GoodsLevel]) ->
	Goods_attributListSize = length(Goods_attributList),
	if Goods_attributListSize == 0 ->
		   {ok, pt:pack(15133, <<Result:8,GoodsId:32,Is_magic:8,Cost:32,Coin:32,Bcoin:32,0:16,<<>>/binary>>)};
	   true ->
		   F = fun(D) ->
					   {Prop,Value} = D,
					   Prop1 = 
					   case Prop of
						    crit -> 7;
						    dodge -> 6;
						    def -> 4;
						    hit -> 5;
						    mp -> 2;
						    physique -> 9;
						    max_attack -> 3;
						    min_attack -> 8;
						    forza -> 15;
						    wit -> 17;
						    agile -> 16;
						    anti_wind -> 10;
						    anti_thunder -> 13;
						    anti_water -> 12;
						    anti_fire -> 11;
						    anti_soil -> 14;
						    hp -> 1;
						    anti_all -> 0;
						    _key -> ?WARNING_MSG("pt_15 _Key is ~p~n",[_key]), 1
					   end,
					   %%单个属性值的星级
					   Single_Magic_star = data_magic:get_single_magic_star(GoodsLevel,Prop1,Value),
					   <<Prop1:16,Value:16,Single_Magic_star:8>>
				end,
			Data = tool:to_binary([F(D) || D <- Goods_attributList]),	
		   {ok,pt:pack(15133,<<Result:8,GoodsId:32,Is_magic:8,Cost:32,Coin:32,Bcoin:32,Goods_attributListSize:16, Data/binary>>)}
	end;	


%% 装备附魔保持或替换
write(15134,[Result, GoodsId]) ->
	 {ok, pt:pack(15134, <<Result:8,GoodsId:32>>)};

%%通知购买VIP卡
write(15140,[Res])->
	{ok,pt:pack(15140,<<Res:8>>)};

%%神秘商店购买物品后返回剩余个数
write(15141,[Goods_id,Num]) ->
	{ok,pt:pack(15141,<<Goods_id:32,Num:16>>)};

%% ------------------------------------
%% 15142 获取衣橱已激活的图鉴数据
%% ------------------------------------
write(15142, [Wardrobe]) ->
	F = fun({Type, ElemId}) -> 
				<<Type:8, ElemId:32>> 
		end,
	Data = tool:to_binary([F(Elem) || Elem <- Wardrobe]),
	Len = length(Wardrobe),
	{ok,pt:pack(15142,<<Len:16, Data/binary>>)};
	
%% ------------------------------------
%% 15143 时装换装请求
%% ------------------------------------
write(15143, [Res]) ->
	{ok,pt:pack(15143,<<Res:8>>)};

%%开服充值反馈
write(15200,[Code,Type,Gold,Time]) ->
	{ok,pt:pack(15200, <<Code:8,Type:8,Gold:32,Time:32>>)};

write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.


%%物品详细信息
get_goods_info(GoodsInfo, SuitNum, AttributeList) ->
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
            Stren = GoodsInfo#goods.stren,
			Stren_fail = GoodsInfo#goods.stren_fail,
            Hole = GoodsInfo#goods.hole,
            Hole1_goods = GoodsInfo#goods.hole1_goods,
            Hole2_goods = GoodsInfo#goods.hole2_goods,
            Hole3_goods = GoodsInfo#goods.hole3_goods,
            SuitId = GoodsInfo#goods.suit_id, 
            SuitNum = SuitNum,
            Forza = GoodsInfo#goods.forza,
			Physique = GoodsInfo#goods.physique,
            Agile = GoodsInfo#goods.agile,
            Wit = GoodsInfo#goods.wit,
            Spirit = GoodsInfo#goods.spirit,
			NextSpirit = data_equip:get_spirit(GoodsInfo#goods.grade),%%修炼下一级需要灵力
			Max_Spirit = goods_util:get_total_spirit(GoodsInfo),%%法宝修炼满所需灵力
            Hp = GoodsInfo#goods.hp,
            Mp = GoodsInfo#goods.mp,
			MaxAtt = GoodsInfo#goods.max_attack,
			MinAtt = GoodsInfo#goods.min_attack,
			Next_MaxAtt = goods_util:get_pracitse_attribute_value(GoodsInfo,3,next),%%修炼下一等级最大攻击
			Next_MinAtt = goods_util:get_pracitse_attribute_value(GoodsInfo,8,next),%%修炼下一等级最小攻击
			Max_MaxAtt = goods_util:get_pracitse_attribute_value(GoodsInfo,3,max),%%最大攻击
			Max_MinAtt = goods_util:get_pracitse_attribute_value(GoodsInfo,8,max),%%最小攻击
            Def = GoodsInfo#goods.def,
            Hit = GoodsInfo#goods.hit,
			Next_Hit = goods_util:get_pracitse_attribute_value(GoodsInfo,5,next),%%修炼下一等级命中
			Max_Hit = goods_util:get_pracitse_attribute_value(GoodsInfo,5,max),%%最大命中
            Dodge = GoodsInfo#goods.dodge,
            Crit = GoodsInfo#goods.crit,
			Grade = GoodsInfo#goods.grade,
			Step = GoodsInfo#goods.step,
			Anti_wind = GoodsInfo#goods.anti_wind,
			Anti_fire = GoodsInfo#goods.anti_fire,
			Anti_water = GoodsInfo#goods.anti_water,
			Anti_thunder = GoodsInfo#goods.anti_thunder,
			Anti_soil = GoodsInfo#goods.anti_soil,
			Speed = GoodsInfo#goods.speed,
			Bless_level = GoodsInfo#goods.bless_level,
			Bless_skill = GoodsInfo#goods.bless_skill,
			Icon = GoodsInfo#goods.icon,
			Expire_time = GoodsInfo#goods.expire_time,
			Used = get_goods_used(GoodsInfo),
			%%过滤出附魔属性
			GoodsAttributeList = [GoodsAttribute || GoodsAttribute <- AttributeList,GoodsAttribute#goods_attribute.attribute_type == 7,GoodsInfo#goods.player_id == GoodsAttribute#goods_attribute.player_id],
			Magic_star = data_magic:get_magic_star(GoodsInfo#goods.level,GoodsAttributeList),
            ListNum = length(AttributeList),
            F = fun(AttributeInfo) ->
                    AttributeType = AttributeInfo#goods_attribute.attribute_type,
                    AttributeId = AttributeInfo#goods_attribute.attribute_id,
					AttributeStatus = AttributeInfo#goods_attribute.status,
                    AttributeVal = goods_util:get_attribute_value(AttributeInfo),
					NextAttributeVal = goods_util:get_pracitse_attribute_value(GoodsInfo,AttributeId,next),%%下一等级数值
					MaxAttributeVal = goods_util:get_pracitse_attribute_value(GoodsInfo,AttributeId,max),%%最大数值
					Goods_id = AttributeInfo#goods_attribute.goods_id,
					%%0显示数值，1显示百分比
					ValueType = AttributeInfo#goods_attribute.value_type,
					%%单个属性值的星级
					Single_Magic_star = data_magic:get_single_magic_star(GoodsInfo#goods.level,AttributeId,AttributeVal),
                    <<AttributeType:16,AttributeId:16,AttributeStatus:16,AttributeVal:16,NextAttributeVal:16,MaxAttributeVal:16,Goods_id:32,ValueType:8,Single_Magic_star:8>>
                end,
            ListBin = tool:to_binary(lists:map(F, AttributeList));
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
            Stren = 0,
			Stren_fail=0,
            Hole = 0,
            Hole1_goods = 0,
            Hole2_goods = 0,
            Hole3_goods = 0,
            SuitId = 0,
            SuitNum = 0,
            Forza = 0,
			Physique =0,
            Agile = 0,
            Wit = 0,
            Spirit = 0,
			NextSpirit =0,
			Max_Spirit =0,
            Hp = 0,
            Mp = 0,
            MaxAtt =0,
			MinAtt =0,
			Next_MaxAtt =0,
			Next_MinAtt =0,
			Max_MaxAtt =0,
			Max_MinAtt =0,
            Def = 0,
            Hit = 0,
			Next_Hit =0,
			Max_Hit =0,
            Dodge = 0,
            Crit = 0,
			Grade = 0,
			Step = 0,
			Anti_wind = 0,
			Anti_fire = 0,
			Anti_water = 0,
			Anti_thunder = 0,
			Anti_soil =0,
			Speed = 0,
			Bless_level = 0,
			Bless_skill = 0,
			Magic_star = 0,
			Icon = 0,
			Expire_time = 0,
			Used = 0,
            ListNum = 0,
            ListBin = <<>>
    end,
	%%灵力值超出前端显示范围，需转换成字符串
	Spirit_bin = tool:to_binary(Spirit),
	Spirit_len = byte_size(Spirit_bin),
	NextSpirit_bin = tool:to_binary(NextSpirit),
	NextSpirit_len = byte_size(NextSpirit_bin),
	Max_Spirit_bin = tool:to_binary(Max_Spirit),
	Max_Spirit_len = byte_size(Max_Spirit_bin),
    <<GoodsId:32, TypeId:32, Cell:16, Num:16, Bind:16, Trade:16,
           Sell:16, Isdrop:16, Attrition:16, Color:16, Stren:16,Stren_fail:16,
           Hole:16, Hole1_goods:32, Hole2_goods:32, Hole3_goods:32, SuitId:16,
           SuitNum:16, Forza:16, Physique:16, Agile:16, Wit:16, Spirit_len:16,Spirit_bin/binary,NextSpirit_len:16,NextSpirit_bin/binary,Max_Spirit_len:16,Max_Spirit_bin/binary, Hp:32, Mp:32,
           MaxAtt:16,MinAtt:16,Next_MaxAtt:16,Next_MinAtt:16,Max_MaxAtt:16,Max_MinAtt:16,Def:16, Hit:16,Next_Hit:16,Max_Hit:16, Dodge:16, Crit:16, Grade:16,Step:16,Anti_wind:16,
	  	   Anti_fire:16,Anti_water:16,Anti_thunder:16,Anti_soil:16,Speed:16,Bless_level:8,Bless_skill:32,Magic_star:8,Icon:32,Expire_time:32,Used:16,ListNum:16, ListBin/binary>>.

get_goods_used(GoodsInfo) ->
	#goods{type = Type,
		   subtype = SubType,
		   used = Used} = GoodsInfo,
	case lib_wardrobe:check_goods_wardrobe(Type, SubType) of
		GType when GType =:= yifu orelse GType =:= fabao orelse GType =:= guashi ->%%时装类
			Ret = 1 - Used,
			case Ret >= 0  of
				true ->
					Ret;
				false ->
					0
			end;
		_ ->
			0
	end.

				