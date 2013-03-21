%%%------------------------------------
%%% @Module  : mod_goods
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 物品模块
%%%------------------------------------
-module(mod_goods).
-behaviour(gen_server).
-export([start/3]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

start(PlayerId,CellNum,Socket) ->
    gen_server:start_link(?MODULE, [PlayerId,CellNum,Socket], []).

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([PlayerId,CellNum,Pid_send]) ->
 	process_flag(trap_exit, true),
	goods_util:goods_offline(PlayerId),
	ok = goods_util:init_goods_online(PlayerId),
    NullCells = goods_util:get_null_cells(PlayerId, CellNum),
	RestBoxCellsNum = goods_util:get_box_null_cells(PlayerId),
    EquipSuit = goods_util:get_equip_suit(PlayerId),
    GoodsStatus = #goods_status{player_id = PlayerId, 
								null_cells = NullCells,
								pid_send = Pid_send,
								equip_current = [0,0,0,0,0], 
								equip_suit = EquipSuit,
								box_remain_cells = RestBoxCellsNum},
    NewStatus = goods_util:get_current_equip(GoodsStatus),
	misc:write_monitor_pid(self(),?MODULE, {}),
%% %% 	活动四：	全身强化，潜力无限	
%% 	Now = util:unixtime(),
%% 	if
%% 		Now >= ?HOLIDAY_BEG_TIME andalso Now =< ?HOLIDAY_END_TIME ->
%% 			HolidayInfo = goods_util:get_ets_info(?ETS_HOLIDAY_INFO, PlayerId),
%% 			case db_agent:get_mid_prize(PlayerId,40) of
%% 				[_Id2,_Mpid2,_Mtype2,_Mnum2,_got2] ->
%% 					HasFullInfo = 1;
%% 				[] ->
%% 					HasFullInfo = 0
%% 			end,
%% 			ets:insert(?ETS_HOLIDAY_INFO, HolidayInfo#ets_holiday_info{has_full_stren_info = HasFullInfo});
%% 		true ->
%% 			skip
%% 	end,
	%%测试用，禁止打开
	%%erlang:send_after(1000 * 10, self(), 'snapshot'),
	%%erlang:send_after(1000 * 10 , self(),{'mem_diff',1}),
    {ok, NewStatus}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%%设置物品信息
handle_cast({'SET_STATUS', NewStatus}, _GoodsStatus) ->
    {noreply, NewStatus};

%%获取物品详细信息 (15000)
handle_cast({'info_15000', GoodsId, _Location}, GoodsStatus) ->
    GoodsInfo = goods_util:get_goods(GoodsId),
	[GoodsInfo_1, SuitNum_1, AttributeList_1] =
    case is_record(GoodsInfo, goods) of
        true when GoodsInfo#goods.player_id == GoodsStatus#goods_status.player_id ->
            case goods_util:has_attribute(GoodsInfo) of
                true -> AttributeList = goods_util:get_goods_attribute_list(GoodsStatus#goods_status.player_id, GoodsId);
                false -> AttributeList = []
            end,
            SuitNum = goods_util:get_suit_num(GoodsStatus#goods_status.equip_suit, GoodsInfo#goods.suit_id),
            [GoodsInfo, SuitNum, AttributeList];
        _Error ->
            [{}, 0, []]
    end,
    {ok, BinData} = pt_15:write(15000, [GoodsInfo_1, SuitNum_1, AttributeList_1]),
    lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData),	
	{noreply, GoodsStatus};

%%获取物品详细信息 只获取在线物品信息(15001)
handle_cast({'info_15001',PlayerId, OtherPlayerId, GoodsId}, GoodsStatus) ->
	[GoodsInfo_1, SuitNum_1, AttributeList_1] =
	   if OtherPlayerId =/= PlayerId ->
    			case lib_player:get_online_info_fields(OtherPlayerId, [pid_goods]) of
        			[] ->
						[{},0,[]];
        			[Pid_goods] ->
						try 
							gen_server:call(Pid_goods, {'info', GoodsId})
						catch
							_:_ -> [{},0,[]]
						end						
    			end;		
		true ->  %%也可能是自己的情况
			GoodsInfo = goods_util:get_goods(GoodsId),
			case is_record(GoodsInfo,goods) of
				true ->
					case goods_util:has_attribute(GoodsInfo) of
						true -> AttributeList = goods_util:get_goods_attribute_list(GoodsStatus#goods_status.player_id, GoodsId);
                		false -> AttributeList = []
					end,
					SuitNum = goods_util:get_suit_num(GoodsStatus#goods_status.equip_suit, GoodsInfo#goods.suit_id),
            		[GoodsInfo, SuitNum, AttributeList];
				_Error ->
            		[{}, 0, []]
			end
	   end,
    {ok, BinData} = pt_15:write(15001, [GoodsInfo_1, SuitNum_1, AttributeList_1]),
    lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData),	
	{noreply, GoodsStatus};

%%获取物品详细信息 (15003)
handle_cast({'info_15003',PlayerId, OtherPlayerId, GoodsId}, GoodsStatus) ->
	[GoodsInfo_1, SuitNum_1, AttributeList_1] =
	   if OtherPlayerId =/= PlayerId ->
    			case lib_player:get_online_info_fields(OtherPlayerId, [pid_goods]) of
        			[] ->  %%读数据库
						try
							case mod_cache:g_get({mod_goods,info_15003,OtherPlayerId,GoodsId}) of
								[] ->
									InfoList = lib_goods:get_goods_info_from_db(OtherPlayerId,GoodsId),
									mod_cache:g_set({mod_goods,info_15003,OtherPlayerId,GoodsId},InfoList,300);
								CacheList ->
									InfoList = CacheList
							end,
							InfoList
						catch
							_:_ -> [{},0,[]]
						end;
        			[Pid_goods] ->
						try 
							gen_server:call(Pid_goods, {'info', GoodsId})
						catch
							_:_ -> [{},0,[]]
						end						
    			end;		
		true ->  %%也可能是自己的情况
			GoodsInfo = goods_util:get_goods(GoodsId),
			case is_record(GoodsInfo,goods) of
				true ->
					case goods_util:has_attribute(GoodsInfo) of
						true -> AttributeList = goods_util:get_goods_attribute_list(GoodsStatus#goods_status.player_id, GoodsId);
                		false -> AttributeList = []
					end,
					SuitNum = goods_util:get_suit_num(GoodsStatus#goods_status.equip_suit, GoodsInfo#goods.suit_id),
            		[GoodsInfo, SuitNum, AttributeList];
				Error ->
            		?ERROR_MSG("mod_goods info:~p", [[GoodsId,Error]]),
            		[{}, 0, []]
			end
	   end,
    {ok, BinData} = pt_15:write(15003, [GoodsInfo_1, SuitNum_1, AttributeList_1]),
    lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData),	
	{noreply, GoodsStatus};

%% 获取类型物品的高级信息 
handle_cast({'typeinfo_15004',Goods_id},GoodsStatus) ->
	GoodsTypeInfo = goods_util:get_goods_type(Goods_id),
	if
		is_record(GoodsTypeInfo,ets_base_goods) ->
			Ginfo = goods_util:get_new_goods(GoodsTypeInfo),
			Ginfo2 = Ginfo#goods{id = 0, player_id= 0 ,location = 4,cell = 1,num = 1,grade =1},
			if
				Ginfo2#goods.subtype == 21 ->%%饰品显示全抗
					Pattern = #ets_base_goods_add_attribute{ goods_id=Ginfo2#goods.goods_id,color=Ginfo2#goods.color,attribute_type=10, _='_' };
				Ginfo2#goods.subtype == 23 ->%%新戒指
					Pattern = #ets_base_goods_add_attribute{ goods_id=Ginfo2#goods.goods_id,color=Ginfo2#goods.color,attribute_type=13, _='_' };
				true ->%%其他显示双属性
					Attribute_type = 
						if
							Ginfo2#goods.subtype > 13 andalso Ginfo2#goods.color == 4 ->
								11;%%紫装附加属性类型 lib_goods line 123
							Ginfo2#goods.color == 1 ->
								1;
							true ->
								2
						end,
					Pattern = #ets_base_goods_add_attribute{ goods_id=Ginfo2#goods.goods_id,color=Ginfo2#goods.color,attribute_type=Attribute_type, _='_' }
			end,
            BaseAddAttributeList= goods_util:get_ets_list(?ETS_BASE_GOODS_ADD_ATTRIBUTE, Pattern),
			AttLen = length(BaseAddAttributeList),
			F = fun(BaseAddAttribute,Att_list) ->
				if
					is_record(BaseAddAttribute,ets_base_goods_add_attribute) ->
						Attribute= goods_util:get_new_goods_add_attribute(BaseAddAttribute),
						if
							%%紫装显示全鉴定
							AttLen == 4 -> 
								NewAtt = Attribute#goods_attribute{status=1};
							%%新戒指法力，气血需要鉴定
							GoodsTypeInfo#ets_base_goods.subtype == 23 andalso (Attribute#goods_attribute.attribute_id == 1 orelse Attribute#goods_attribute.attribute_id == 2) ->
								NewAtt = Attribute#goods_attribute{status=0};
							%%饰品体质不需要鉴定
							GoodsTypeInfo#ets_base_goods.subtype == 21 andalso Attribute#goods_attribute.attribute_id == 9 ->
								NewAtt = Attribute#goods_attribute{status=1};
							GoodsTypeInfo#ets_base_goods.subtype == 21 ->
								NewAtt = Attribute#goods_attribute{status=0};
							%%体质需要鉴定
							Attribute#goods_attribute.attribute_id == 9 -> 
								NewAtt = Attribute#goods_attribute{status=0};
							true ->
								NewAtt = Attribute
						end,
						[NewAtt|Att_list];
					true ->
						Att_list
				end
			end,		
			AddAttributeList = lists:foldl(F, [], BaseAddAttributeList),
			{ok,BinData} = pt_15:write(15004,[Ginfo2,0,AddAttributeList]),
			lib_send:send_to_sid(GoodsStatus#goods_status.pid_send,BinData);
		true ->
			skip
	end,	
	{noreply,GoodsStatus};

%% 获取玩家物品列表信息(15010)
handle_cast({'list_15010', PlayerStatus, Location}, GoodsStatus) ->
	[NewLocation_1, CellNum_1, GoodsList_1] =
      case Location > 0 of
        %% 装备
        true when Location == 1 ->
			NewLocation = Location,
            CellNum = 12,
            EquipList = goods_util:get_equip_list(PlayerStatus#player.id, 10, NewLocation),
            [NewLocation, CellNum, EquipList];
        true ->
			NewLocation = Location,
			 case Location =:= 5 of
                true -> CellNum = PlayerStatus#player.store_num;  %% 仓库
                false -> CellNum = PlayerStatus#player.cell_num
            end,
            EquipList = goods_util:get_goods_list(PlayerStatus#player.id, NewLocation),
	  		[NewLocation, CellNum, EquipList];
        false ->
	  		[0,0,[]]
      end,
	%%获取玩家的可交易的绑定铜和交易铜
	[BcoinTotalNum,CoinTotalNum] = lib_manor:get_steal_sell_num(PlayerStatus#player.id),
	[BcoinNum,CoinNum] = lib_manor:get_sell_limit(PlayerStatus#player.lv),
    {ok, BinData} = pt_15:write(15010,
				[NewLocation_1, CellNum_1, PlayerStatus#player.coin, 
				 PlayerStatus#player.bcoin, PlayerStatus#player.cash, 
				 PlayerStatus#player.gold, BcoinNum-BcoinTotalNum,CoinNum-CoinTotalNum,GoodsList_1]),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
%% 	?DEBUG("GoodsList_1--> ~p", [GoodsList_1]),
    {noreply, GoodsStatus};

%% 查询别人身上装备列表(15011)
handle_cast({'list_other_15011', OtherPlayerId}, GoodsStatus) ->
	[Res, GoodsList,FasheffectSeting] =
    case lib_player:get_player_pid(OtherPlayerId) of
        %% 玩家不在线
        [] ->
			case mod_cache:g_get({mod_goods,get_offline_goods,OtherPlayerId}) of
				[] ->
					EquipList = goods_util:get_offline_goods(OtherPlayerId, 1),
					mod_cache:g_set({mod_goods,get_offline_goods,OtherPlayerId},EquipList,3600);			
				CacheList ->
					EquipList = CacheList
			end,
			FasheffectSet =
			case mod_cache:g_get({mod_goods,query_player_sys_setting,OtherPlayerId}) of
				[] ->
					[_Player_Id, _ShieldRole, _ShieldSkill, _ShieldRela, _ShieldTeam, _ShieldChat, _Music, _SoundEffect,Fasheffect, _Smelt] = lib_syssetting:query_player_sys_setting(OtherPlayerId),
					mod_cache:g_set({mod_goods,query_player_sys_setting,OtherPlayerId},[_Player_Id, _ShieldRole, _ShieldSkill, _ShieldRela, _ShieldTeam, _ShieldChat, _Music, _SoundEffect,Fasheffect, _Smelt],3600),
					Fasheffect;
				CacheData ->
					[_Player_Id, _ShieldRole, _ShieldSkill, _ShieldRela, _ShieldTeam, _ShieldChat, _Music, _SoundEffect,Fasheffect, _Smelt] = CacheData,
					Fasheffect
			end,
            [3, EquipList,FasheffectSet];
        Pid ->
			[_Player_Id, _ShieldRole, _ShieldSkill, _ShieldRela, _ShieldTeam, _ShieldChat, _Music, _SoundEffect,Fasheffect, _Smelt] = lib_syssetting:query_player_sys_setting(OtherPlayerId),
			case catch gen_server:call(Pid, {'equit_list'}) of
				{'EXIT', _} -> 
					[2, [],Fasheffect];
				EquipList -> 
					[1, EquipList,Fasheffect]
			end
    end,	
    {ok, BinData} = pt_15:write(15011, [Res, OtherPlayerId, GoodsList,FasheffectSeting]),
	lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData),
    {noreply, GoodsStatus};

%%获取要修理装备列表(15012)
handle_cast({'mend_list_15012', Equip}, GoodsStatus) ->
    %% 查找有耐久度的装备
    List = goods_util:get_mend_list(GoodsStatus#goods_status.player_id, Equip),
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
    {ok, BinData} = pt_15:write(15012, MendList),
    lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData),
	{noreply, GoodsStatus};

%% 取商店物品列表(15013)
handle_cast({'shop_15013', ShopType, ShopSubtype}, GoodsStatus) ->
	ShopList = goods_util:get_shop_list(ShopType, ShopSubtype),
	{ok, BinData} = pt_15:write(15013, [GoodsStatus#goods_status.player_id,ShopType, ShopSubtype, ShopList,1]),
	lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData),
    {noreply, GoodsStatus};

%% 取神秘商店物品列表
handle_cast({'fst_shop_15013', ShopType, ShopSubtype, ShopList, Result}, GoodsStatus) ->
	{ok, BinData} = pt_15:write(15013, [GoodsStatus#goods_status.player_id,ShopType, ShopSubtype, ShopList, Result]),
	lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData),
    {noreply, GoodsStatus};

%% 列出背包打造装备列表(15014)
handle_cast({'make_list_15014',Position},GoodsStatus) ->
    EquipList = goods_util:get_equip_list(GoodsStatus#goods_status.player_id, 10, Position),
	{ok, BinData} = pt_15:write(15014, EquipList),
    lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData),
    {noreply, GoodsStatus};

%% 列出装备打造位置约定信息(15015)
handle_cast({'make_position_goods_15015',Position},GoodsStatus)->
	GoodsList = goods_util:get_make_position_goods(GoodsStatus#goods_status.player_id,Position),
	{ok,BinData} = pt_15:write(15015,[Position,GoodsList]),
	lib_send:send_to_sid(GoodsStatus#goods_status.pid_send,BinData),
	{noreply,GoodsStatus};

%% 列出物品cd列表(15016)
handle_cast({'cd_list_15016'},GoodsStatus) ->
	CdList = goods_util:get_goods_cd_list(GoodsStatus#goods_status.player_id),
	[Res,List]=
	if
		length(CdList) > 0 ->
		  	[1,CdList];
		true ->
			[0,[]]
	end,
	{ok,BinData} = pt_15:write(15016,[Res,List]),
	lib_send:send_to_sid(GoodsStatus#goods_status.pid_send,BinData),
	{noreply,GoodsStatus};

%%获取位置物品全部信息(15017)
handle_cast({'all_info_list_15017',PlayerId,Location},GoodsStatus) ->
	[Res,AllGoodsInfoList] =
	if
		Location =:= 1 orelse Location =:= 4 orelse Location == 12 ->
			GoodsList = goods_util:get_goods_list(PlayerId, Location),
			F = fun(GoodsInfo) ->
					%%类似获取单个物品信息的方法
					case is_record(GoodsInfo, goods) of
        				true when GoodsInfo#goods.player_id == GoodsStatus#goods_status.player_id ->
            				case goods_util:has_attribute(GoodsInfo) of
                				true -> AttributeList = goods_util:get_goods_attribute_list(GoodsStatus#goods_status.player_id, GoodsInfo#goods.id);
                				false -> AttributeList = []
            				end,
            				SuitNum = goods_util:get_suit_num(GoodsStatus#goods_status.equip_suit, GoodsInfo#goods.suit_id),
							%%加成计算
							NewGoodsInfo = goods_util:parse_goods_addition(GoodsInfo),
            				[NewGoodsInfo, SuitNum, AttributeList];
						false ->
							[]
					end
				end,
			GetList = lists:map(F, GoodsList),
			[1,GetList];
		true ->
			[0,[]]
	end,
	{ok,BinData} = pt_15:write(15017,[Res,Location,AllGoodsInfoList]),
	lib_send:send_to_sid(GoodsStatus#goods_status.pid_send,BinData),
	{noreply,GoodsStatus};

%%背包拖动物品(15040)
handle_cast({'drag_15040',Cell_num,GoodsId, OldCell, NewCell}, GoodsStatus) ->
	[Res, R_OldCellId, R_OldTypeId, R_NewCellId, R_NewTypeId,R_GoodsStatus] =
    case check_drag(GoodsStatus, GoodsId, OldCell, NewCell, Cell_num) of
        {fail, _Res} ->
            [_Res, 0, 0, 0, 0,GoodsStatus];
        {ok, GoodsInfo} ->
            case (catch lib_goods:drag_goods(GoodsStatus, GoodsInfo, OldCell, NewCell)) of
                {ok, NewStatus, [OldCellId, OldTypeId, NewCellId, NewTypeId]} ->
                    [1, OldCellId, OldTypeId, NewCellId, NewTypeId,NewStatus];
                Error ->
                    ?ERROR_MSG("mod_goods drag:~p", [Error]),
                    [0, 0, 0, 0, 0,GoodsStatus]
            end
    end,
	{ok, BinData} = pt_15:write(15040, [Res, R_OldCellId, R_OldTypeId, OldCell, R_NewCellId, R_NewTypeId, NewCell]),
    lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData),
	{noreply,R_GoodsStatus};

%%物品存入仓库 (15041)
handle_cast({'movein_bag_15041', Store_num,GoodsId, GoodsNum},GoodsStatus) ->
	[Res,R_GoodsStatus] =
    case check_movein_bag(GoodsStatus, GoodsId, GoodsNum) of
        {fail, _Res} ->
            [_Res,GoodsStatus];
        {ok, GoodsInfo, GoodsTypeInfo} ->
            case (catch lib_goods:movein_bag(GoodsStatus, GoodsInfo, GoodsNum, GoodsTypeInfo, Store_num)) of
                {ok, NewStatus} ->
                    [1, NewStatus];
                {fail, full} ->
                    [6, GoodsStatus];				
                Error ->
                    ?ERROR_MSG("mod_goods movein_bag:~p", [Error]),
                    [0, GoodsStatus]
            end
    end,
	{ok, BinData} = pt_15:write(15041, [Res, GoodsId, GoodsNum]),
    lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData),
	{noreply,R_GoodsStatus};

%%从仓库取出物品 (15042)
handle_cast({'moveout_bag_15042',GoodsId, GoodsNum},GoodsStatus) ->
	[Res,R_goodsList,R_GoodsStatus] =
    case check_moveout_bag(GoodsStatus, GoodsId, GoodsNum) of
        {fail, _Res} ->
            [_Res, [],GoodsStatus];
        {ok, GoodsInfo, GoodsTypeInfo} ->
            case lib_goods:moveout_bag(GoodsStatus, GoodsInfo, GoodsNum, GoodsTypeInfo) of
                {ok, NewStatus} ->
                    GoodsList = goods_util:get_type_goods_list(GoodsInfo#goods.player_id, GoodsInfo#goods.goods_id, GoodsInfo#goods.bind, 4),
					lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
                    [1, GoodsList,NewStatus];
                Error ->
                    ?ERROR_MSG("mod_goods moveout_bag:~p", [Error]),
                    [0, [],GoodsStatus]
            end
    end,
	{ok, BinData} = pt_15:write(15042, [Res, GoodsId, R_goodsList]),
    lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData),
	{noreply,R_GoodsStatus};

%%从临时矿包取出物品
handle_cast({'moveout_orebag_15043',GoodsId, GoodsNum}, GoodsStatus) ->
	case check_moveout_orebag(GoodsStatus,GoodsId,GoodsNum) of
		{fail,_Res} ->
			Res = _Res,
			NewStatus = GoodsStatus;
		{ok,GoodsInfo, GoodsTypeInfo} ->
			case (catch lib_goods:moveout_orebag(GoodsStatus,GoodsInfo,GoodsNum,GoodsTypeInfo)) of
				{ok,NewStatus} ->
					lib_player:refresh_client(GoodsStatus#goods_status.pid_send,2),
					Res = 1;
				Error ->
					NewStatus = GoodsStatus,
					?ERROR_MSG("mod_goods moveout_orebag:~p" ,[Error]) ,
					Res = 0
			end
	end,
	{ok,BinData} = pt_15:write(15043,[Res]) ,
	lib_send:send_to_sid(GoodsStatus#goods_status.pid_send,BinData),
	{noreply,NewStatus};

%%从农场背包取出物品
handle_cast({'moveout_plantbag_15044',GoodsInfoList}, GoodsStatus) ->
	case check_moveout_plantbag(GoodsStatus,GoodsInfoList) of
		{fail,_Res} ->
			Res = _Res,
			NewStatus = GoodsStatus;
		{ok} ->
			case (catch lib_goods:moveout_plantbag_list(GoodsStatus,GoodsInfoList)) of
				{ok,NewStatus} ->
					lib_player:refresh_client(GoodsStatus#goods_status.pid_send,2),
					Res = 1;
				_Error ->
					NewStatus = GoodsStatus,
					%%?ERROR_MSG("mod_goods moveout_plantbag:~p" ,[Error]) ,
					Res = 0
			end
	end,
	{ok,BinData} = pt_15:write(15044,[Res]) ,
	lib_send:send_to_sid(GoodsStatus#goods_status.pid_send,BinData),
	{noreply,NewStatus};
	
%%丢弃物品(15051)
handle_cast({'throw_15051', PlayerStatus,GoodsId, GoodsNum}, GoodsStatus) ->
	[Res,R_GoodsStatus] =
		case check_throw(PlayerStatus,GoodsStatus, GoodsId, GoodsNum) of
			{fail, _Res} ->
				[_Res, GoodsStatus];
			{ok, GoodsInfo} ->
				AttributeLists = goods_util:get_goods_attribute_list(PlayerStatus#player.id, GoodsInfo#goods.id, 1),
				case (catch lib_goods:delete_one(GoodsStatus, GoodsInfo, GoodsNum)) of
					{ok, NewStatus, _} ->
						Attrs = lists:foldl(fun goods_util:get_attribute_id_value/2, [], AttributeLists),
						AtrrsStr = util:term_to_string(Attrs),
						spawn(fun()->log:log_throw([PlayerStatus#player.id,PlayerStatus#player.nickname,GoodsInfo#goods.id,GoodsInfo#goods.goods_id,
													GoodsInfo#goods.color,GoodsInfo#goods.stren,GoodsInfo#goods.bind,1,GoodsInfo#goods.num,AtrrsStr])end),
						%%如果是法宝且有灵力，则将灵力返回到人物身上
						if GoodsInfo#goods.type == 10 andalso GoodsInfo#goods.subtype >= 9 andalso GoodsInfo#goods.subtype =< 13 andalso GoodsInfo#goods.spirit > 0 ->
							   PlayerStatus1 = PlayerStatus#player{spirit = PlayerStatus#player.spirit+GoodsInfo#goods.spirit},
							   gen_server:cast(PlayerStatus1#player.other#player_other.pid, {'SET_PLAYER', [{spirit,PlayerStatus1#player.spirit}]}),
							   lib_player:send_player_attribute(PlayerStatus1,2);   
						   true ->
							   skip
						end,
						[1, NewStatus];
					Error ->
						?ERROR_MSG("mod_goods throw:~p", [Error]),
						[0, GoodsStatus]
				end
    end,
	{ok, BinData} = pt_15:write(15051, [Res, GoodsId, GoodsNum]),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	{noreply,R_GoodsStatus};

%% 整理背包(15052)
handle_cast({'clean_15052', Cell_num},GoodsStatus) ->
    %% 查询背包物品列表
    GoodsList = goods_util:get_goods_list(GoodsStatus#goods_status.player_id, 4),
	
    %% 按物品类型ID排序
    GoodsList1 = lists:reverse(goods_util:sort(GoodsList, goods_id)),
	GoodsList2 = [Good || Good <- GoodsList1,Good#goods.cell < 200],
    %% 整理
    %%[Num, _] = lists:foldl(fun lib_goods:clean_bag/2, [1, {}], GoodsList1),
	%%过滤掉坐骑(在200格以后，不纳入整理范围)
	[Num,_] = lib_goods:clean_bag(GoodsList2,[]),
    %% 重新计算
    NewGoodsList = goods_util:get_goods_list(GoodsStatus#goods_status.player_id, 4),
	%%NullCells =lists:seq(Num, Cell_num),
	NullCells =
	case (catch lists:seq(Num, Cell_num)) of
		{'EXIT', Info} ->	
			 ?ERROR_MSG("clean bag error : Module=~p, Method=~p, Reason=~p",[goods, clean_15052,Info]),
			 [];
		_NullCells -> _NullCells	
	end,
    NewGoodsStatus = GoodsStatus#goods_status{  null_cells = NullCells },
	{ok, BinData} = pt_15:write(15052, NewGoodsList),
    lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData),

    {noreply , NewGoodsStatus};

%% 节日道具使用
handle_cast({'usefestivaltool_15054',Player,GoodsId,GoodsNum,SNickname},GoodsStatus) ->
	[_Res,_FestivalType,_NewNum,_NewStatus] =
	case lib_goods_use:check_festivaltool(Player,GoodsStatus,GoodsId,GoodsNum,SNickname) of
		{fail,Res} ->
			[Res,0,0,GoodsStatus];
		{ok,GoodsInfo,[FestivalType,To_id,To_pid,Scene,X,Y,Nickname]} ->
			%%调用普通使用删除道具
			case(catch lib_goods:use_goods(Player,GoodsStatus,GoodsInfo,GoodsNum ,[])) of
				{ok, _,NewPlayer, NewStatus, NewNum,_Buff} ->
					 %%spawn(fun()->lib_team:update_team_player_info(NewPlayer)end),
					 %%spawn(fun()->lib_task:event(use_goods, {GoodsInfo#goods.goods_id}, PlayerStatus)end),
					 spawn(fun()->catch(log:log_use([NewPlayer#player.id,
									   NewPlayer#player.nickname,
									   GoodsId,
									   GoodsInfo#goods.goods_id,
									   GoodsInfo#goods.type,
									   GoodsInfo#goods.subtype,
									   GoodsNum
										]))end),
					 %% 广播效果处理
					 case FestivalType of
						 1 ->%%新年烟花
					 		{ok, BinData1} = pt_12:write(12061, [To_id,GoodsInfo#goods.goods_id]),
     	    		 		mod_scene_agent:send_to_area_scene(Scene, X,Y, BinData1),
					 		if
						 		Player#player.nickname /= SNickname ->
					 				%%传闻广播
									Msg = io_lib:format("【~s】为玩家【~s】点燃了新春焰火，漫天飞舞的烟火照亮了新春的夜空",[Player#player.nickname,SNickname]),
					 				lib_chat:broadcast_sys_msg(6,Msg),
					 				%%发给自己
									MyMsg = io_lib:format("玩家~s看到了您赠送的焰火，同祝你新春快乐！",[SNickname]),
					 				{ok,MyBin} = pt_15:write(15055,[MyMsg]),
					 				lib_send:send_to_sid(Player#player.other#player_other.pid_send,MyBin),
					 				%%发给他人
									ToMsg = io_lib:format("玩家~s 为您点燃了焰火，恭祝你新春快乐！",[Player#player.nickname]),
					 				{ok,ToBin} = pt_15:write(15055,[ToMsg]),
					 				lib_send:send_to_uid(To_id,ToBin);
						 		true ->
							 		skip
					 		end;
						 2 ->%%情人节玫瑰
							 [FlowerNum ,Exp,Spi] =
										 case GoodsInfo#goods.goods_id of
											 28018 -> [9,88,27];
											 28019 -> [99,1380,460];
											 28020 -> [999,8888,2962]
										 end,
							 %%成就系统统计接口
							 erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(Player#player.id, 609, [FlowerNum]))end),
							 %%氏族祝福任务判断
							 GWParam = {1, 1},
							 lib_gwish_interface:check_player_gwish(Player#player.other#player_other.pid, GWParam),
							 %%爱侣赠送玫瑰任务
							 
							 case tool:to_list(Player#player.couple_name) ==SNickname of
								 true->
									lib_task:event(lover_flower,null,Player);
								false->skip
							 end,
							 NowTime = util:unixtime(),
							 if
								 Player#player.nickname /= SNickname ->
									 if
										GoodsInfo#goods.goods_id /= 28018 ->
											%%广播信息
											NameColor = data_agent:get_realm_color(Player#player.realm),
											Msg = io_lib:format("【<font color='~s'>~s</font>】送给【<font color='~s'>~s</font>】~p朵红玫瑰，表达了深深的爱意，他们好幸福啊！",[NameColor,Player#player.nickname,NameColor,SNickname,FlowerNum]),
											if
												GoodsInfo#goods.goods_id == 28019 -> %%聊天框广播
									 				lib_chat:broadcast_sys_msg(6,Msg),
													%%范围广播
													{ok, BinData1} = pt_15:write(15056, [0,To_id,0,"","",Player#player.sex,Player#player.career]),
     	    		 								mod_scene_agent:send_to_area_scene(Scene, X,Y, BinData1);
												GoodsInfo#goods.goods_id == 28020 -> %%大电视广播
													lib_chat:broadcast_sys_msg(2,Msg),
													%%全服广播
													{ok, BinData1} = pt_15:write(15056, [0,To_id,0,"","",Player#player.sex,Player#player.career]),
													mod_disperse:broadcast_to_world(ets:tab2list(?ETS_SERVER), BinData1),
													lib_send:send_to_local_all(BinData1);
												true ->
													skip
											end;
										true ->%%9朵不用广播
											skip
									 end,
									 TaTeamId = 
										 case lib_player:get_online_info_fields(To_id,[other]) of
											 [] ->
												 undefined;
											 [Other] -> Other#player_other.pid_team
										 end,
									 %%增加好友亲密度
							         spawn(fun() -> lib_relationship:close(flower,Player#player.id,To_id,[FlowerNum,Player#player.other#player_other.pid_team,TaTeamId])end),
									 %%都需要弹窗
									 LoveWord = io_lib:format("【~s】被你的魅力所倾倒，送上了~p朵玫瑰，无比幸福的你要怎么感谢他呢？",[Player#player.nickname,FlowerNum]),
									 {ok,LoveWordBin} = pt_15:write(15056,[1,Player#player.id,Player#player.lv,Player#player.nickname,LoveWord,Player#player.sex,Player#player.career]),
									 lib_send:send_to_uid(To_id,LoveWordBin),
									 %%右下角小窗口信息
									 %%发给自己
									 MyMsg = io_lib:format("玩家 ~s 看到了您赠送的玫瑰，幸福无比中！",[SNickname]),
					 				 {ok,MyBin} = pt_15:write(15055,[MyMsg]),
					 				 lib_send:send_to_sid(Player#player.other#player_other.pid_send,MyBin),
					 				 %%发给他人
									 ToMsg = io_lib:format("玩家 ~s 送给您~p朵玫瑰来表达对你的深深爱意！",[Player#player.nickname,FlowerNum]),
					 				 {ok,ToBin} = pt_15:write(15055,[ToMsg]),
					 				 lib_send:send_to_uid(To_id,ToBin),
									 %%增加魅力值
									 gen_server:cast(Player#player.other#player_other.pid,{'add_charm',FlowerNum}),
									 spawn(fun()->db_agent:log_charm([Player#player.id,1,Player#player.id,FlowerNum,FlowerNum,NowTime])end),
									 gen_server:cast(To_pid,{'add_charm',FlowerNum}),
									 spawn(fun()->db_agent:log_charm([To_id,1,Player#player.id,FlowerNum,FlowerNum,NowTime])end),
									 %%增加经验灵力
									 gen_server:cast(To_pid,{'EXP', Exp, Spi}),
									 gen_server:cast(Player#player.other#player_other.pid,{'EXP',Exp,Spi});
								 true ->
									 %%增加魅力值
									 gen_server:cast(Player#player.other#player_other.pid,{'add_charm',FlowerNum}),
									  spawn(fun()->db_agent:log_charm([Player#player.id,1,Player#player.id,FlowerNum,FlowerNum,NowTime])end),
									 LoveWord = io_lib:format("【~s】被你的魅力所倾倒，送上了~p朵玫瑰，无比幸福的你要怎么感谢他呢？",[Player#player.nickname,FlowerNum]),
									 {ok,LoveWordBin} = pt_15:write(15056,[1,Player#player.id,Player#player.lv,Player#player.nickname,LoveWord,Player#player.sex,Player#player.career]),
									 lib_send:send_to_sid(Player#player.other#player_other.pid_send,LoveWordBin),
									 gen_server:cast(Player#player.other#player_other.pid,{'EXP',Exp,Spi})
							 end;
						3 ->%%怪物变身卡
							gen_server:cast(To_pid, {'BE_MON_CHANGE', GoodsInfo}),
							Msg = 
								io_lib:format("[<font color='#FEDB4F'>~s</font>]念动精灵咒语，将[<font color='#FEDB4F'>~s</font>]变成了怪物！大家快来围观啦～",[Player#player.nickname,Nickname]),
							spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg)end);
						 _ ->
							 skip
					 end,
                     [1, FestivalType, NewNum,NewStatus];
                 Error ->
                     ?ERROR_MSG("mod_goods use_error:~p | goodsId: ~p playerId: ~p ~n", [Error,GoodsId,Player#player.id]),
                     [0, 0, 0,GoodsStatus]
            end
	end,
	{ok,BinData} = pt_15:write(15054,[_Res,_FestivalType,GoodsId,_NewNum]),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send,BinData),
	{noreply,_NewStatus};

%% 弹出框的反馈信息
handle_cast({'alert_win_15056',MyName,Type,PlayerId,_Msg},GoodsStatus) ->
	case Type of
		1 ->
			MyMsg = io_lib:format("【~s】看到您的玫瑰，回吻一个表示谢意！",[MyName]),
			{ok,MyBin} = pt_15:write(15055,[MyMsg]),
			lib_send:send_to_uid(PlayerId,MyBin);
		_ ->
			skip
	end,
	{noreply,GoodsStatus};

%% 拣取地上掉落包的物品
handle_cast({'RAND_DROP_CHOOSE', PlayerId, TeamPid, GoodsTypeId, GoodsNum, GoodsColor, MonId, MonType, MaxNum, TeamList, NickName, Realm, Career, Sex}, GoodsStatus) ->
    case catch lib_goods:give_goods({GoodsTypeId, GoodsNum}, GoodsStatus) of
   		{ok, NewGoodsStatus} ->			
			%% 投骰子数据
			{ok, BinData} = pt_24:write(24020, [NickName, MaxNum, GoodsTypeId, TeamList]),
			gen_server:cast(TeamPid, {'SEND_TO_MEMBER', BinData}),
			lib_goods_drop:drop_choose_broadcast(PlayerId, NickName, Career, Sex, Realm, GoodsTypeId, GoodsColor, MonId, MonType, GoodsNum),
			lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
			{noreply, NewGoodsStatus};
		{fail, _Error, GoodsStatus} ->
      		{noreply, GoodsStatus}
	end;

%% 拣取地上掉落包的物品
handle_cast({'drop_choose', PlayerId, TeamPid, SceneId, DropId, GoodsTypeId, PlayerData}, GoodsStatus) ->
  	[Result, RetGoodsStatus] = 
		case lib_goods_drop:check_drop_choose(PlayerId, TeamPid, SceneId, GoodsStatus, DropId, GoodsTypeId) of
        	{fail, Res} ->
           		[Res, GoodsStatus];
        	{ok, DropInfo, GoodsInfo} ->
            	case lib_goods_drop:drop_choose(PlayerId, TeamPid, SceneId, 
												   GoodsStatus, DropInfo, GoodsInfo, PlayerData) of
                	{ok, NewGoodsStatus} ->
						%%转移到拾取函数刷新新物品
						%%lib_player:refresh_client(PlayerId, 2),
               			[1, NewGoodsStatus];
                	_Error ->
             			[0, GoodsStatus]
            	end
    	end,
	{ok, BinData} = pt_15:write(15053, [Result, DropId, GoodsTypeId]),
	lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData),
	{noreply, RetGoodsStatus};

%% 挂机拾取物品
handle_cast({'HOOK_GIVE_GOODS', DropGoods, PlayerData, DropId, MonId, MonX, MonY, SceneType}, GoodsStatus) ->
	NewGoodsStatus = lib_goods_drop:hook_give_goods(DropGoods, DropId, MonId, MonX, MonY, GoodsStatus, [], PlayerData, SceneType),
	{noreply, NewGoodsStatus};
handle_cast({'HOOK_GIVE_GOODS', DropGoods, PlayerData, DropId, MonId, MonX, MonY, SceneType, HookEquipList, HookQualityList}, GoodsStatus) ->
	[GiveGoods, LeftGoods] = lib_goods_drop:hook_select_goods(DropGoods, HookEquipList, HookQualityList, [], []),
	NewGoodsStatus = lib_goods_drop:hook_give_goods(GiveGoods, DropId, MonId, MonX, MonY, GoodsStatus, LeftGoods, PlayerData, SceneType),
	{noreply, NewGoodsStatus};

%% 删除多个同类型物品
handle_cast({'DELETE_MORE', GoodsTypeId, GoodsNum}, GoodsStatus) ->
	GoodsList = goods_util:get_type_goods_list(GoodsStatus#goods_status.player_id, GoodsTypeId, 4),
    TotalNum = goods_util:get_goods_totalnum(GoodsList),
    if
        %% 物品不存在
		length(GoodsList) =:= 0 ->
			{noreply, GoodsStatus};
        %% 物品数量不足
		TotalNum < GoodsNum ->
			{noreply, GoodsStatus};
        true ->
            case (catch lib_goods:delete_more(GoodsStatus, GoodsList, GoodsNum)) of
                {ok, NewGoodsStatus} ->
                     lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
                     {noreply, NewGoodsStatus};
                 _Error ->
					 {noreply, GoodsStatus}
            end
    end;

%% 删除多个同类物品，绑定物品优先
handle_cast({'DELETE_MORE_BIND_PRIOR',GoodsTypeId,GoodsNum},GoodsStatus) ->
	%%绑定的物品列表
	BindGoodsList = goods_util:get_type_goods_list(GoodsStatus#goods_status.player_id, GoodsTypeId,2,4),
    BindTotalNum = goods_util:get_goods_totalnum(BindGoodsList),
	NoBindGoodsList = goods_util:get_type_goods_list(GoodsStatus#goods_status.player_id, GoodsTypeId,0,4),
	%%没绑定的物品列表
    NoBindTotalNum = goods_util:get_goods_totalnum(NoBindGoodsList),
	if
		length(BindGoodsList) == 0 andalso length(NoBindGoodsList) == 0 ->
			{noreply, GoodsStatus};
		BindTotalNum + NoBindTotalNum < GoodsNum ->
			{noreply, GoodsStatus};
		true ->
			if 
				%%绑定物品数量足够
				BindTotalNum > 0 andalso BindTotalNum >= GoodsNum ->
					case (catch lib_goods:delete_more(GoodsStatus,BindGoodsList,GoodsNum)) of
						{ok, NewGoodsStatus} ->
							lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
							{noreply,NewGoodsStatus};
						_Error ->
							{noreply, GoodsStatus}
					end;
				%%绑定物品数量不够
				BindTotalNum > 0 andalso BindTotalNum < GoodsNum ->
					case (catch lib_goods:delete_more(GoodsStatus,BindGoodsList,BindTotalNum)) of
						{ok, GoodsStatus1} ->
							 %%再删除非绑定
							case (catch lib_goods:delete_more(GoodsStatus1, NoBindGoodsList, GoodsNum - BindTotalNum)) of
								{ok,NewGoodsStatus} ->
									lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
									{noreply,NewGoodsStatus};
								_E ->
									lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
									{noreply,GoodsStatus1}
							end;							
						_Error ->
							{noreply, GoodsStatus}
					end;
				%% 没有绑定物品
				BindTotalNum == 0 ->
					case (catch lib_goods:delete_more(GoodsStatus, NoBindGoodsList, GoodsNum)) of
                		{ok, NewGoodsStatus} ->
                    		 lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
                     		{noreply, NewGoodsStatus};
                 		_Error ->
					 		{noreply, GoodsStatus}
            		end;
				true ->
					{noreply, GoodsStatus}
			end
	end;
			
	
%% 紫装融合预览
handle_cast({'suit_merge_preview',PlayerStatus,Gid1,Gid2,Gid3},GoodsStatus) ->
	case check_suit_merge(PlayerStatus,Gid1,Gid2,Gid3,preview) of
		{fail,_Res} ->
			skip;
		{ok,GoodsInfo1,GoodsInfo2,GoodsInfo3,_Cost} ->
			case (catch lib_make:suit_merge_preview(GoodsInfo1,GoodsInfo2,GoodsInfo3))of
				{ok,NewGoodsInfo,AttributeList} ->
					{ok,BinData} = pt_15:write(15060,[NewGoodsInfo,AttributeList]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);
				_Error ->
					skip
			end
	end,
	{noreply,GoodsStatus};



%% 添加采矿物品
handle_cast({'give_ore_goods', GoodsTypeId, GoodsNum ,Nickname, Pidsend}, GoodsStatus) ->
	case lib_goods:give_ore_goods({GoodsTypeId,GoodsNum},GoodsStatus) of
		{ok} ->
			%%成功才广播获得物品
			lib_ore:broadcast_goods_info(Nickname,GoodsTypeId,Pidsend),
			{noreply,GoodsStatus};
		{fail,full} ->
			%%临时矿包已满
			{ok,BinData} = pt_36:write(36002,[4]),
			lib_send:send_to_sid(GoodsStatus#goods_status.pid_send, BinData),
			{noreply,GoodsStatus};
		{fail,_Err} ->
			{noreply,GoodsStatus}
	end;

%% 添加农场物品
%% handle_cast({'give_plant_goods', GoodsTypeId, GoodsNum}, GoodsStatus) ->
%% 	case lib_goods:give_plant_goods({GoodsTypeId,GoodsNum},GoodsStatus) of
%% 		{ok} ->
%% 			{noreply,GoodsStatus};
%% 		{fail,full} ->
%% 			{noreply,GoodsStatus};
%% 		{fail,_Err} ->
%% 			{noreply,GoodsStatus}
%% 	end;

%%定时内存回收
handle_cast('garbage_collect',GoodsStatus)->
	garbage_collect(self()),
	{noreply,GoodsStatus};

%%扩充VIP背包
handle_cast({'extend_vip',Loc,PlayerStatus},GoodsStatus) ->
	case PlayerStatus#player.cell_num =:=  108 of
		false->{noreply, GoodsStatus};
		true->
			{_,_,Award} = lib_vip:get_vip_award(bag,PlayerStatus),
			case Award of
				false->{noreply, GoodsStatus};
				true->
					 case (catch lib_goods:extend(PlayerStatus, 0, Loc)) of
   		             {ok, NewPlayerStatus, NullCells} ->
							NewGoodsStatus = GoodsStatus#goods_status{null_cells = NullCells},
							 {ok, BinData} = pt_15:write(15022, [Loc, 1, NewPlayerStatus#player.gold, NewPlayerStatus#player.cell_num]),
   							 lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
    		                {noreply, NewGoodsStatus};
						{ok, _NewPlayerStatus} ->
							{noreply,GoodsStatus};
    		            Error ->
							?ERROR_MSG("mod_goods extend_bag_vip:~p", [Error]),
      		             	 {noreply, GoodsStatus}
      				   end
			end
	end;

%%重新load玩家物品信息(仅交易模块使用)
handle_cast({'reload_goods', PlayerId, CellNum, DBGoodsRecord}, GoodsStatus) ->
	%%先清数据
	lib_trade:reload_goods_for_trade(true, PlayerId, DBGoodsRecord),
	%%重新初始化
	NullCells = goods_util:get_null_cells(PlayerId, CellNum),
	NewGoodsStatus = GoodsStatus#goods_status{null_cells = NullCells},
	lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
	{noreply,NewGoodsStatus};

%% -----------------------------------------------------------------
%% 38004 38005 八神珠 
%% -----------------------------------------------------------------
handle_cast({'GET_ACH_PEARL_EQUIPED', Type, PlayerId, PidSend}, GoodsStatus) ->
	case Type of
		1 ->
			Result = lib_achieve:get_ach_pearl_equiped(PlayerId),
			{ok, BinData38004} = pt_38:write(38004, [Result]),
			lib_send:send_to_sid(PidSend, BinData38004);
		0 ->
			Result = lib_achieve:get_ach_pearl_equipno(PlayerId),
			{ok, BinData38005} = pt_38:write(38005, [Result]),
			lib_send:send_to_sid(PidSend, BinData38005)
	end,
	{noreply, GoodsStatus};
	
%% 邮件发送物品时对背包状态修改
handle_cast({'handle_mail_goods',Cell},GoodsStatus) ->
	NewNullCells = lists:sort([Cell| GoodsStatus#goods_status.null_cells]),
    NewGoodsStatus = GoodsStatus#goods_status{null_cells = NewNullCells},
	{noreply,NewGoodsStatus};

%% 更新当前时装
handle_cast({'equip_current',Equip_current},GoodsStatus) ->
    NewGoodsStatus = GoodsStatus#goods_status{equip_current = Equip_current},
	{noreply,NewGoodsStatus};

%% ------------------------------------
%% 15142 获取衣橱已激活的图鉴数据
%% ------------------------------------
handle_cast({'GET_PLAYER_WARDROBE', Pid, PidSend}, GoodsStatus) ->
	Wardrobe = lib_wardrobe:get_player_wardrobe_activated(Pid),
	{ok, BinData38005} = pt_15:write(15142, [Wardrobe]),
	lib_send:send_to_sid(PidSend, BinData38005),
	{noreply, GoodsStatus};
	

%%停止进程
handle_cast({stop, _Reason}, GoodsStatus) ->
    {stop, normal, GoodsStatus};

handle_cast(_R , GoodsStatus) ->
    {noreply, GoodsStatus}.


%% --------------------------------------------------------------------
%% Function: handle_call/3
%% Description: Handling call messages
%% Returns: {reply, Reply, State}          |
%%          {reply, Reply, State, Timeout} |
%%          {noreply, State}               |
%%          {noreply, State, Timeout}      |
%%          {stop, Reason, Reply, State}   | (terminate/2 is called)
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_call({'STATUS'} , _From, GoodsStatus) ->
    {reply, GoodsStatus, GoodsStatus};

%%设置物品信息
handle_call({'SET_STATUS', NewGoodsStatus}, _From, _GoodsStatus) ->
    {reply, ok, NewGoodsStatus};

%%获取物品详细信息 只获取在线物品信息
handle_call({'info',GoodsId},_From,GoodsStatus) ->
	GoodsInfo = goods_util:get_goods(GoodsId),
	case is_record(GoodsInfo,goods) of
		true ->
			case goods_util:has_attribute(GoodsInfo) of
				true -> AttributeList = goods_util:get_goods_attribute_list(GoodsStatus#goods_status.player_id, GoodsId);
                false -> AttributeList = []
			end,
			SuitNum = goods_util:get_suit_num(GoodsStatus#goods_status.equip_suit, GoodsInfo#goods.suit_id),
            {reply, [GoodsInfo, SuitNum, AttributeList], GoodsStatus};
		_Error ->
            {reply, [{}, 0, []], GoodsStatus}
	end;

%%获取物品详细信息 
handle_call({'info', GoodsId, _Location}, _From, GoodsStatus) ->
    GoodsInfo = goods_util:get_goods(GoodsId),
    case is_record(GoodsInfo, goods) of
        true when GoodsInfo#goods.player_id == GoodsStatus#goods_status.player_id ->
            case goods_util:has_attribute(GoodsInfo) of
                true -> AttributeList = goods_util:get_goods_attribute_list(GoodsStatus#goods_status.player_id, GoodsId);
                false -> AttributeList = []
            end,
            SuitNum = goods_util:get_suit_num(GoodsStatus#goods_status.equip_suit, GoodsInfo#goods.suit_id),
            {reply, [GoodsInfo, SuitNum, AttributeList], GoodsStatus};
        Error ->
            ?ERROR_MSG("mod_goods info:~p", [[GoodsId,Error]]),
            {reply, [{}, 0, []], GoodsStatus}
    end;

%% 查看玩家背包是否存在指定ID物品
%% PlayerId 玩家ID
%% GoodsTypeId 物品类型ID
handle_call({'goods_find', PlayerId, GoodsTypeId}, _From, GoodsStatus) ->
	Reply = lib_goods:goods_find(PlayerId, GoodsTypeId),
	{reply, Reply, GoodsStatus};


%%删除玩家的ets_goods表的所有数据
handle_call({'delete_goods_ets', PlayerId}, _From, GoodsStatus)->
	Pattern1 = #goods{player_id = PlayerId, _='_'},
	ets:match_delete(?ETS_GOODS_ONLINE, Pattern1),
	Pattern2 = #goods_attribute{ player_id = PlayerId, _='_'},
    ets:match_delete(?ETS_GOODS_ATTRIBUTE, Pattern2),
	Pattern4 = #ets_goods_cd{player_id = PlayerId, _='_'},
	ets:match_delete(?ETS_GOODS_CD, Pattern4),
	{reply, ok, GoodsStatus};

%% 获取玩家物品列表信息
handle_call({'list', PlayerStatus, Location}, _From, GoodsStatus) ->
    case Location > 0 of
        %% 装备
        true when Location == 1 ->
            NewLocation = Location,
            CellNum = 12,
            EquipList = goods_util:get_equip_list(PlayerStatus#player.id, 10, NewLocation),
            List = EquipList;
        true ->
            NewLocation = Location,
            case Location =:= 5 of
                true -> CellNum = PlayerStatus#player.store_num;  %% 仓库
                false -> CellNum = PlayerStatus#player.cell_num
            end,
            List = goods_util:get_goods_list(PlayerStatus#player.id, NewLocation);
        false ->
			NewLocation = 0,
			CellNum = 0,
			List =[]
    end,
    {reply, [NewLocation, CellNum, List], GoodsStatus};

%%购买物品
handle_call({'pay', PlayerStatus, GoodsTypeId, GoodsNum, ShopType ,ShopSubtype}, _From, GoodsStatus) ->
    case check_pay(PlayerStatus, GoodsStatus, GoodsTypeId, GoodsNum, ShopType, ShopSubtype) of
        {fail, Res} ->		
            {reply, [PlayerStatus, Res, []], GoodsStatus};
        {ok, GoodsTypeInfo, GoodsList, Cost, PriceType, _BagNullCells, GoodsStatus1} ->
            case (catch lib_goods:pay_goods(GoodsStatus1, GoodsTypeInfo, GoodsList, GoodsNum)) of
                {ok, NewStatus} ->
					%% 根据商店类型扣除对应属性值
					Is_Fst_Shop = mod_fst:is_fst_shop(ShopType),
					if ShopType =:= 10219 ->
						   NewPlayerStatus = lib_goods:cost_score(PlayerStatus,Cost,arena_score,1219);
					   ShopType =:= 20207 ->
						   {ok,NewPlayerStatus}= lib_skyrush:deduct_player_feat(PlayerStatus, Cost, GoodsTypeId, GoodsNum, 2007);
					   ShopType =:= 21020 ->
						   {ok,NewPlayerStatus}= lib_skyrush:deduct_player_feat(PlayerStatus, Cost, GoodsTypeId, GoodsNum, 2120);
					   ShopType =:= 20800 ->
						   lib_td:cost_hor_td(PlayerStatus#player.id, Cost),
							spawn(fun()->db_agent:log_td_honor_consume([PlayerStatus#player.id,GoodsTypeId, GoodsNum,Cost,util:unixtime()])end),
						   NewPlayerStatus = PlayerStatus;
					   ShopType =:= 20802 ->%%活动面板的购买
						   NewPlayerStatus = lib_goods:cost_money(PlayerStatus, Cost, PriceType,2882);
					   ShopType =:= 1 andalso ShopSubtype =:= 9->
						   NewPlayerStatus = lib_goods:cost_money(PlayerStatus, Cost, PriceType,1561);
					   Is_Fst_Shop =:= true -> %%封神台神秘商店
						   NewPlayerStatus = lib_goods:cost_money(PlayerStatus, Cost, PriceType,2151);
					   true ->
						   NewPlayerStatus = lib_goods:cost_money(PlayerStatus, Cost, PriceType,1561)
					end,
					%% 购买某物品有附加物品
					goods_util:pay_goods_addition(PlayerStatus,GoodsTypeId,GoodsNum, GoodsTypeInfo#ets_base_goods.max_overlap),
                    NewGoodsList = goods_util:get_goods_list(PlayerStatus#player.id, 4),
					case ShopType of 
						1->
							%%氏族祝福任务判断
							GWParam = {3, 1},
							lib_gwish_interface:check_player_gwish(PlayerStatus#player.other#player_other.pid, GWParam),
							spawn(fun()-> lib_task:event(shopping, {GoodsTypeId}, NewPlayerStatus)end);
						_->
							spawn(fun()-> lib_task:event(buy_equip, {GoodsTypeId}, NewPlayerStatus)end)
					end,
					if
						ShopType == 1 andalso ShopSubtype /= 5-> %%礼券商店不记录
							spawn(fun()-> catch(log:log_shop([ShopType,
										ShopSubtype,
										PlayerStatus#player.id,
										PlayerStatus#player.nickname,
										GoodsTypeId,
										PriceType,
										Cost,
										GoodsNum]))end);
						true ->
							skip
					end,
                    {reply, [NewPlayerStatus, 1, NewGoodsList], NewStatus};
                Error ->
                    ?ERROR_MSG("mod_goods pay:~p", [Error]),
                    {reply, [PlayerStatus, 0, []], GoodsStatus1}
            end
    end;

%% ------------------------------------
%% 15071 批量购买商店物品
%% ------------------------------------
handle_call({'buy_multi', PlayerStatus, ShopType, ShopSubType, GoodsList}, _From, GoodsStatus) ->
	LenBuyGoodsList = length(GoodsList),
	case PlayerStatus#player.bcoin >= 0 andalso PlayerStatus#player.coin >= 0 of
		true ->		
	case LenBuyGoodsList > length(GoodsStatus#goods_status.null_cells) of
		false  ->
			PriceType = case ShopSubType of
							1 ->
								coinonly;
							2 ->
								bcoin
						end,
			case multi_check_pay(ok, 1, PlayerStatus, GoodsStatus, GoodsList, ShopType, ShopSubType, []) of
				{fail, Res} ->
					case ShopSubType of 
						1 ->
							Money = PlayerStatus#player.coin;
						2 ->
							Money = PlayerStatus#player.bcoin
					end,
					{reply, [Res, ShopSubType, Money, PlayerStatus], GoodsStatus};
				{ok, GoodsTypeInfos} ->
					BuyResult = multi_pay_goods(PriceType, PlayerStatus, GoodsStatus, GoodsTypeInfos),
					case BuyResult of
						{'EXIT', _} ->%%执行失败了
							case ShopSubType of 
								1 ->
									Money = PlayerStatus#player.coin;
								2 ->
									Money = PlayerStatus#player.bcoin
							end,
							{reply, [0, ShopSubType, Money, PlayerStatus], GoodsStatus};
						_ ->			
							{FinalPlayerStatus, FinalResult, FinalGoodsStatus} = BuyResult,
							case ShopSubType of 
								1 ->
									Money = FinalPlayerStatus#player.coin;
								2 ->
									Money = FinalPlayerStatus#player.bcoin
							end,
							case FinalResult of
								0 ->
									{reply, [FinalResult, ShopSubType, Money, PlayerStatus], GoodsStatus};
								1 ->
									{reply, [FinalResult, ShopSubType, Money, FinalPlayerStatus], FinalGoodsStatus}
							end
					end
			end;
		true ->
			{reply, [4, ShopSubType, 0, PlayerStatus], GoodsStatus}
	end;
		false ->
			{reply, [3, ShopSubType, 0, PlayerStatus], GoodsStatus}
	end;


%%出售物品
handle_call({'sell', PlayerStatus, GoodsId, GoodsNum}, _From, GoodsStatus) ->
    case check_sell(GoodsStatus, GoodsId, GoodsNum) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res], GoodsStatus};
        {ok, GoodsInfo} ->
            case (catch lib_goods:sell_goods(PlayerStatus, GoodsStatus, GoodsInfo, GoodsNum, 0)) of
                {ok, NewPlayerStatus, NewStatus} ->
                    {reply, [NewPlayerStatus, 1], NewStatus};
                Error ->
                    ?ERROR_MSG("mod_goods sell:~p", [Error]),
                    {reply, [PlayerStatus, 0], GoodsStatus}
            end
    end;

%% ------------------------------------
%% 15072 批量出售物品
%% ------------------------------------
handle_call({'sell_multi', PlayerStatus, GoodsList}, _From, GoodsStatus) ->
	case lib_goods:check_goods_diff(GoodsList) of
		false ->%%没有相同的id
			{CheckResult,GoodsInfoList} = multi_check_sell(GoodsList,GoodsStatus),
			case CheckResult of
				0 ->
			{reply, [CheckResult, 1, PlayerStatus#player.coin, PlayerStatus], GoodsStatus};
				1 ->
					SellResult = mutli_sell_goods(PlayerStatus, GoodsStatus, GoodsInfoList),
					case SellResult of
						{'EXIT', _} ->%%执行失败了
							{reply, [0, 1, PlayerStatus#player.coin, PlayerStatus], GoodsStatus};
						_ ->
							{FinalResult, FinalPlayerStatus, FinalGoodsStatus} = SellResult,
							case FinalResult of
								0 ->
									{reply, [FinalResult, 1, PlayerStatus#player.coin, PlayerStatus], GoodsStatus};
								1 ->
									{reply, [FinalResult, 1, FinalPlayerStatus#player.coin, FinalPlayerStatus], FinalGoodsStatus}
							end
					end
			end;
		true ->%%有相同的id
			{reply, [0, 1, PlayerStatus#player.coin, PlayerStatus], GoodsStatus}
	end;

%%装备物品
handle_call({'equip', PlayerStatus, GoodsId, Cell}, _From, GoodsStatus) ->
    case check_equip(PlayerStatus, GoodsId, Cell) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res, {}, {}, [], []], GoodsStatus};
        {ok, GoodsInfo, Location, NewCell} ->
            case (catch lib_goods:equip_goods(PlayerStatus, GoodsStatus, GoodsInfo, Location, NewCell)) of
                {ok, NewPlayerStatus, NewStatus, OldGoodsInfo, Effect2, AchCheck} ->
                    spawn(fun()->lib_task:event(equip, {GoodsInfo#goods.goods_id}, PlayerStatus)end),
                    {reply, [NewPlayerStatus, 1, GoodsInfo, OldGoodsInfo, Effect2, AchCheck], NewStatus};
                 Error ->
                     ?ERROR_MSG("mod_goods equip:~p", [Error]),
                     {reply, [PlayerStatus, 0, {}, {}, [], []], GoodsStatus}
            end
    end;

%%卸下装备
handle_call({'unequip', PlayerStatus, GoodsId}, _From, GoodsStatus) ->
    case check_unequip(GoodsStatus, GoodsId, PlayerStatus#player.equip) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res, {}], GoodsStatus};
        {ok, GoodsInfo} ->
            case (catch lib_goods:unequip_goods(PlayerStatus, GoodsStatus, GoodsInfo)) of
                {ok, NewPlayerStatus, NewStatus, NewGoodsInfo} ->
                     {reply, [NewPlayerStatus, 1, NewGoodsInfo], NewStatus};
                 Error ->
                     ?ERROR_MSG("mod_goods unequip:~p", [Error]),
                     {reply, [PlayerStatus, 0, {}], GoodsStatus}
            end
    end;

%%使用物品
handle_call({'use', PlayerStatus, GoodsId, GoodsNum, GoodsBuffs}, _From, GoodsStatus) ->
    case lib_goods_use:check_use(PlayerStatus,GoodsStatus, GoodsId, GoodsNum) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res, 0, 0, {no_update, GoodsBuffs}], GoodsStatus};
        {ok, GoodsInfo} ->
            case (catch lib_goods:use_goods(PlayerStatus, GoodsStatus, GoodsInfo, GoodsNum, GoodsBuffs)) of
                {ok, Result, NewPlayerStatus, NewStatus, NewNum, NewGoodsBuffs} ->
					case Result of
						1 ->
							spawn(fun()->lib_team:update_team_player_info(NewPlayerStatus)end),
							case lists:member(GoodsInfo#goods.goods_id, [23409,23410,23411]) of
								true->spawn(fun()->lib_task:event(use_peach, {GoodsInfo#goods.goods_id}, PlayerStatus)end);
								false->
									spawn(fun()->lib_task:event(use_goods, {GoodsInfo#goods.goods_id}, PlayerStatus)end)
							end,
					 spawn(fun()->catch(log:log_use([PlayerStatus#player.id,
									   PlayerStatus#player.nickname,
									   GoodsId,
									   GoodsInfo#goods.goods_id,
									   GoodsInfo#goods.type,
									   GoodsInfo#goods.subtype,
									   GoodsNum
										]))end),
					 {reply, [NewPlayerStatus, Result, GoodsInfo#goods.goods_id, NewNum, NewGoodsBuffs], NewStatus};
						_ ->
							{reply, [NewPlayerStatus, Result, 0, 0, NewGoodsBuffs], NewStatus}
					end;
                 Error ->
                     ?ERROR_MSG("mod_goods use_error:~p | goodsId: ~p playerId: ~p ~n", [Error,GoodsId,PlayerStatus#player.id]),
                     {reply, [PlayerStatus, 0, 0, 0, {no_update, GoodsBuffs}], GoodsStatus}
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
                     lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
                     {reply, [1, NewNum], NewStatus};
                 Error ->
                     ?ERROR_MSG("mod_goods delete_one:~p", [Error]),
                     {reply, [0, 0], GoodsStatus}
            end
    end;

%%删除多个同类型物品
handle_call({'delete_more', GoodsTypeId, GoodsNum}, _From, GoodsStatus) ->
    GoodsList = goods_util:get_type_goods_list(GoodsStatus#goods_status.player_id, GoodsTypeId, 4),
    TotalNum = goods_util:get_goods_totalnum(GoodsList),
    if
        length(GoodsList) =:= 0 ->
            {reply, 2, GoodsStatus};	%% 物品不存在        
        TotalNum < GoodsNum ->
            {reply, 3, GoodsStatus};	%% 物品数量不足
        true ->
            case (catch lib_goods:delete_more(GoodsStatus, GoodsList, GoodsNum)) of
                {ok, NewStatus} ->
                     lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
                     {reply, 1, NewStatus};	%% 成功
                 Error ->
                     ?ERROR_MSG("mod_goods delete_more:~p", [Error]),
                     {reply, 0, GoodsStatus}	%% 失败
            end
    end;

%%删除多个同类型非绑定的物品
handle_call({'delete_more_unbind', GoodsTypeId, GoodsNum}, _From, GoodsStatus) ->
    GoodsList = goods_util:get_type_goods_list(GoodsStatus#goods_status.player_id,GoodsTypeId,0, 4),
    TotalNum = goods_util:get_goods_totalnum(GoodsList),
    if
        length(GoodsList) =:= 0 ->
            {reply, 2, GoodsStatus};	%% 物品不存在        
        TotalNum < GoodsNum ->
            {reply, 3, GoodsStatus};	%% 物品数量不足
        true ->
            case (catch lib_goods:delete_more(GoodsStatus, GoodsList, GoodsNum)) of
                {ok, NewStatus} ->
                     lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
                     {reply, 1, NewStatus};	%% 成功
                 Error ->
                     ?ERROR_MSG("mod_goods delete_more:~p", [Error]),
                     {reply, 0, GoodsStatus}	%% 失败
            end
    end;

%%删除多个同类型物品，绑定优先删除 cast 有相同方法
handle_call({'DELETE_MORE_BIND_PRIOR',GoodsTypeId,GoodsNum},_From,GoodsStatus) ->
	%%绑定的物品列表
	BindGoodsList = goods_util:get_type_goods_list(GoodsStatus#goods_status.player_id, GoodsTypeId,2,4),
    BindTotalNum = goods_util:get_goods_totalnum(BindGoodsList),
	NoBindGoodsList = goods_util:get_type_goods_list(GoodsStatus#goods_status.player_id, GoodsTypeId,0,4),
	%%没绑定的物品列表
    NoBindTotalNum = goods_util:get_goods_totalnum(NoBindGoodsList),
	if
		length(BindGoodsList) == 0 andalso length(NoBindGoodsList) == 0 ->
			{reply,2, GoodsStatus};
		BindTotalNum + NoBindTotalNum < GoodsNum ->
			{reply,3, GoodsStatus};
		true ->
			if 
				%%绑定物品数量足够
				BindTotalNum > 0 andalso BindTotalNum >= GoodsNum ->
					case (catch lib_goods:delete_more(GoodsStatus,BindGoodsList,GoodsNum)) of
						{ok, NewGoodsStatus} ->
							lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
							{reply,1,NewGoodsStatus};
						_Error ->
							{reply,0, GoodsStatus}
					end;
				%%绑定物品数量不够
				BindTotalNum > 0 andalso BindTotalNum < GoodsNum ->
					case (catch lib_goods:delete_more(GoodsStatus,BindGoodsList,BindTotalNum)) of
						{ok, GoodsStatus1} ->
							 %%再删除非绑定
							case (catch lib_goods:delete_more(GoodsStatus1, NoBindGoodsList, GoodsNum - BindTotalNum)) of
								{ok,NewGoodsStatus} ->
									lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
									{reply,1,NewGoodsStatus};
								_E ->
									lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
									{reply,0,GoodsStatus1}
							end;							
						_Error ->
							{reply,0, GoodsStatus}
					end;
				%% 没有绑定物品
				BindTotalNum == 0 ->
					case (catch lib_goods:delete_more(GoodsStatus, NoBindGoodsList, GoodsNum)) of
                		{ok, NewGoodsStatus} ->
                    		 lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
                     		{reply,1, NewGoodsStatus};
                 		_Error ->
					 		{reply,0, GoodsStatus}
            		end;
				true ->
					{reply,0, GoodsStatus}
			end
	end;
%%删除任务物品 注意！任务物品不改变物品状态 GoodsStatus
handle_call({'delete_task_goods', GoodsTypeId, GoodsNum}, _From, GoodsStatus) ->
    GoodsList = goods_util:get_type_goods_list(GoodsStatus#goods_status.player_id, GoodsTypeId, 6),
    TotalNum = goods_util:get_goods_totalnum(GoodsList),
    if
        %% 物品不存在
        length(GoodsList) =:= 0 ->
            {reply, 2, GoodsStatus};
        %% 物品数量不足
        TotalNum < GoodsNum ->
            {reply, 3, GoodsStatus};
        true ->
            case (catch lib_goods:delete_task_more(GoodsList, GoodsNum)) of
                {ok} ->
                     {reply, 1, GoodsStatus};
                 Error ->
                     ?ERROR_MSG("mod_goods delete_more:~p", [Error]),
                     {reply, 0, GoodsStatus}
            end
    end;
%%删除农场仓库物品 
handle_call({'delete_plant_goods',GoodsTypeId,GoodsNum},_From,GoodsStatus) -> 
	GoodsList = goods_util:get_type_goods_list(GoodsStatus#goods_status.player_id,GoodsTypeId,10),
	TotalNum = goods_util:get_goods_totalnum(GoodsList),
	if
        %% 物品不存在
        length(GoodsList) =:= 0 ->
            {reply, 2, GoodsStatus};
        %% 物品数量不足
        TotalNum < GoodsNum ->
            {reply, 3, GoodsStatus};
        true ->
            case (catch lib_goods:delete_plant_more(GoodsList, GoodsNum)) of
                {ok} ->
                     {reply, 1, GoodsStatus};
                 Error ->
                     ?ERROR_MSG("mod_goods delete_more:~p", [Error]),
                     {reply, 0, GoodsStatus}
            end
    end;

%%丢弃物品
handle_call({'throw', PlayerStatus,GoodsId, GoodsNum}, _From, GoodsStatus) ->
    case check_throw(PlayerStatus,GoodsStatus, GoodsId, GoodsNum) of
        {fail, Res} ->
            {reply, Res, GoodsStatus};
        {ok, GoodsInfo} ->
            case (catch lib_goods:delete_one(GoodsStatus, GoodsInfo, GoodsNum)) of
                {ok, NewStatus, _} ->
                    {reply, 1, NewStatus};
                Error ->
                    ?ERROR_MSG("mod_goods throw:~p", [Error]),
                    {reply, 0, GoodsStatus}
            end
    end;

%%丢弃同类型物品
%% GoodsTypeList = [GoodsTypeId1, GoodsTypeId2, ...]
handle_call({'throw_more', GoodsTypeList}, _From, GoodsStatus) ->
    case (catch goods_util:list_handle(fun lib_goods:delete_type_goods/2, GoodsStatus, GoodsTypeList)) of
        {ok, NewStatus} ->
            lib_player:refresh_client(NewStatus#goods_status.pid_send, 2),
            {reply, ok, NewStatus};
         {Error, Status} ->
             ?ERROR_MSG("mod_goods throw_more:~p", [Error]),
             {reply, Error, Status}
    end;

%%扩充背包仓库
handle_call({'extend', Loc, PlayerStatus}, _From, GoodsStatus) ->
    case check_extend(PlayerStatus, Loc) of
        {fail, NewPlayerStatus,Res} ->
            {reply, [NewPlayerStatus, Res], GoodsStatus};
        {ok,NewPlayerStatus1, Cost} ->
            case (catch lib_goods:extend(NewPlayerStatus1, Cost, Loc)) of
                {ok, NewPlayerStatus2, NullCells} ->
					NewGoodsStatus = GoodsStatus#goods_status{null_cells = NullCells},
                    {reply, [NewPlayerStatus2, 1], NewGoodsStatus};
				{ok, NewPlayerStatus3} ->
					{reply, [NewPlayerStatus3, 1], GoodsStatus};
                Error ->
                    ?ERROR_MSG("mod_goods extend_bag:~p", [Error]),
                    {reply, [NewPlayerStatus1, 0], GoodsStatus}
            end
    end;


			
%%拆分物品
handle_call({'destruct',PlayerStatus,GoodsId,Num,Pos},_From,GoodsStatus) ->
	case check_destruct(GoodsStatus,GoodsId,Num,Pos) of
		{fail,Res} ->
			{reply,[PlayerStatus,Res],GoodsStatus};
		{ok,GoodsInfo} ->
			case (catch lib_goods:destruct(GoodsStatus,GoodsInfo,Num,Pos)) of
				{ok,NewGoodsStatus} ->
					{reply,[PlayerStatus,1],NewGoodsStatus};
				Error ->
					?ERROR_MSG("mod_goods destruct goods :~p",[Error]),
					{reply,[PlayerStatus,0],GoodsStatus}
			end
	end;
%%装备磨损
handle_call({'attrit', PlayerStatus, UseNum}, _From, GoodsStatus) ->
    %% 穿在身上的装备耐久减1
    EquipList = goods_util:get_equip_list(PlayerStatus#player.id, 10, PlayerStatus#player.equip),
    [_, ZeroEquipList] = lists:foldl(fun lib_goods:attrit_equip/2, [UseNum, []], EquipList),
    %%广播耐久更新
    %%lib_player:refresh_client(PlayerStatus#player.id, 5),
    %% 人物属性更新
    case length(ZeroEquipList) > 0 of
        %% 有耐久为0的装备
        true ->
            %% 人物属性重新计算
            EquipSuit = goods_util:get_equip_suit(PlayerStatus#player.id, PlayerStatus#player.equip),
            Status = GoodsStatus#goods_status{ equip_suit=EquipSuit },
            {ok, NewPlayerStatus, NewStatus} = goods_util:count_role_equip_attribute(PlayerStatus, Status, {}),
            %% 检查武器、衣服
            [NewStatus2, _, _] = goods_util:get_current_equip_by_list(ZeroEquipList, [NewStatus, off]),
            NewPlayerStatus2 = NewPlayerStatus#player{
											other = { NewPlayerStatus#player.other#player_other{equip_attrit=0, equip_current=NewStatus2#goods_status.equip_current }} },
            %% 广播
            {ok, BinData} = pt_12:write(12015, [NewPlayerStatus#player.id, NewPlayerStatus#player.hp, NewPlayerStatus#player.hp_lim, ZeroEquipList]),
            mod_scene:send_to_area_scene(NewPlayerStatus#player.scene, NewPlayerStatus#player.x, NewPlayerStatus#player.y, BinData, NewPlayerStatus),
            %% 通知客户端
            {ok, BinData1} = pt_15:write(15032, ZeroEquipList),
            lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, BinData1),
            %% 返回更新人物属性
            {reply, {ok, NewPlayerStatus2}, NewStatus2};
       false ->
           {reply, {error,no,attrition,equip}, GoodsStatus}
    end;

%%获取要修理装备列表
%% handle_call({'mend_list', PlayerStatus}, _From, GoodsStatus) ->
%%     %% 查找有耐久度的装备
%%     List = goods_util:get_mend_list(GoodsStatus#goods_status.player_id, PlayerStatus#player.equip),
%%     F = fun(GoodsInfo) ->
%%             UseNum = goods_util:get_goods_use_num(GoodsInfo#goods.attrition),
%%             case UseNum =/= GoodsInfo#goods.use_num of
%%                 true ->
%%                     Attrition = goods_util:get_goods_attrition(GoodsInfo#goods.attrition, GoodsInfo#goods.use_num),
%%                     Cost = goods_util:get_mend_cost(GoodsInfo#goods.attrition, GoodsInfo#goods.use_num),
%%                     [[GoodsInfo#goods.id, GoodsInfo#goods.goods_id, Attrition, Cost]];
%%                 false ->
%%                     []
%%             end
%%         end,
%%     MendList = lists:flatmap(F, List),
%%     {reply, MendList, GoodsStatus};

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
                     ?ERROR_MSG("mod_goods mend:~p", [Error]),
                     {reply, [PlayerStatus, 0, {}], GoodsStatus}
            end
    end;

%% 紫装融合
handle_call({'suit_merge',PlayerStatus,Gid1,Gid2,Gid3},_From,GoodsStatus) ->
	case check_suit_merge(PlayerStatus,Gid1,Gid2,Gid3,merge) of
		{fail,Res} ->
			{reply,[PlayerStatus,Res],GoodsStatus};
		{ok,GoodsInfo1,GoodsInfo2,GoodsInfo3,Cost} ->
			case (catch lib_make:suit_merge(PlayerStatus,GoodsStatus,GoodsInfo1,GoodsInfo2,GoodsInfo3,Cost))of
				{ok,Res,NewPlayerStatus,NewStatus} ->
					{reply,[NewPlayerStatus,Res],NewStatus};
				Error ->
					?ERROR_MSG("mod_goods suit_merge:~p",[Error]),
					{reply,[PlayerStatus,0],GoodsStatus}
			end
	end;

%% 装备强化
handle_call({'strengthen', PlayerStatus, GoodsId, StoneId, RuneId1,N1,RuneId2,N2,RuneId3,N3,RuneId4,N4,Protect,StoneTypeId,Auto_purch}, _From, GoodsStatus) ->
    case check_strengthen(PlayerStatus, GoodsId, StoneId, RuneId1,N1,RuneId2,N2,RuneId3,N3,RuneId4,N4,Protect,StoneTypeId,Auto_purch) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res, 0,0,0,0,0,0,0], GoodsStatus};
        {ok, GoodsInfo, StoneInfo, RuneInfo1,RuneInfo2,RuneInfo3,RuneInfo4,Proinfo,GoodsStrengthenRule,GoodsStrengthenAntiRule,GoldCost} ->
            case (catch lib_make:strengthen(PlayerStatus, GoodsStatus, GoodsInfo, StoneInfo, RuneInfo1,N1,RuneInfo2,N2,RuneInfo3,N3,RuneInfo4,N4,Proinfo,GoodsStrengthenRule,GoodsStrengthenAntiRule,Auto_purch,GoldCost)) of
                {ok, NewPlayerStatus, NewStatus, [Result,NewStrengthen,NewStoneNum,StrenFail,NN1,NN2,NN3,NN4]} ->
					if Auto_purch ==1 andalso is_record(StoneInfo,goods) == false andalso GoldCost > 0 ->
						   spawn(fun() ->log:log_shop([1,1,PlayerStatus#player.id,PlayerStatus#player.nickname,StoneTypeId,gold,GoldCost,1]) end);
					   true ->
						   skip
					end,
					Put_on = GoodsInfo#goods.location == 1,
					%% 法宝强化效果广播
					Is_FB = lists:member(GoodsInfo#goods.subtype, [9,10,11,12,13]),
					Is_SP = GoodsInfo#goods.subtype == 27,
					Is_FByf = GoodsInfo#goods.subtype == 26,

					if 
						Is_FB andalso Put_on ->
							{ok,Bin12032} = pt_12:write(12032,[NewPlayerStatus#player.id,4,NewStrengthen]),
							mod_scene_agent:send_to_area_scene(NewPlayerStatus#player.scene, NewPlayerStatus#player.x, NewPlayerStatus#player.y, Bin12032);
						Is_SP andalso Put_on ->
							{ok,Bin12032} = pt_12:write(12032,[NewPlayerStatus#player.id,3,NewStrengthen]),
							mod_scene_agent:send_to_area_scene(NewPlayerStatus#player.scene, NewPlayerStatus#player.x, NewPlayerStatus#player.y, Bin12032);
						Is_FByf andalso Put_on ->
							{ok,Bin12032} = pt_12:write(12032,[NewPlayerStatus#player.id,6,NewStrengthen]),
							mod_scene_agent:send_to_area_scene(NewPlayerStatus#player.scene, NewPlayerStatus#player.x, NewPlayerStatus#player.y, Bin12032);
					   true ->
						  skip
					end,
                    {reply, [NewPlayerStatus,Result, NewStrengthen,NewStoneNum,StrenFail,NN1,NN2,NN3,NN4], NewStatus};
                Error ->
                    ?ERROR_MSG("mod_goods strengthen:~p", [Error]),
                    {reply, [PlayerStatus, 0, 0,0,0,0,0,0,0], GoodsStatus}
            end
    end;

%% 装备打孔
handle_call({'hole', PlayerStatus, GoodsId, StoneId, StoneTypeId, Auto_purch}, _From, GoodsStatus) ->
    case check_hole(PlayerStatus, GoodsId, StoneId, StoneTypeId, Auto_purch) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res, 0, 0], GoodsStatus};
        {ok, GoodsInfo, StoneInfo ,Cost, GoldCost} ->
            case (catch lib_make:hole(PlayerStatus, GoodsStatus, GoodsInfo, StoneInfo ,Cost, GoldCost)) of
                {ok, NewPlayerStatus, NewStatus, [NewHole, NewStoneNum]} ->
					if Auto_purch ==1 andalso is_record(StoneInfo,goods) == false andalso GoldCost > 0 ->
						spawn(fun() ->log:log_shop([1,1,PlayerStatus#player.id,PlayerStatus#player.nickname,StoneTypeId,gold,GoldCost,1]) end);
					   true ->
						skip
					end,
                     {reply, [NewPlayerStatus, 1, NewHole, NewStoneNum], NewStatus};
                 Error ->
                     ?ERROR_MSG("mod_goods hole:~p", [Error]),
                     {reply, [PlayerStatus, 0, 0, 0], GoodsStatus}
            end
    end;

%% 宝石合成
handle_call({'compose', PlayerStatus, RuneId, StoneTypeId, RuneTypeId, Auto_purch, StoneList}, _From, GoodsStatus) ->
    case check_compose(PlayerStatus, GoodsStatus, StoneTypeId, RuneId, RuneTypeId, Auto_purch, StoneList) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res, 0], GoodsStatus};
        {ok, NewStoneList, TotalStoneNum,RuneInfo, GoodsComposeRule,GoldCost} ->
            case (catch lib_make:compose(PlayerStatus, GoodsStatus, NewStoneList,TotalStoneNum, RuneInfo, GoodsComposeRule, RuneTypeId, Auto_purch, GoldCost)) of
                {ok, NewPlayerStatus, NewStatus, NewGoodsTypeId} ->
					if Auto_purch ==1 andalso is_record(RuneInfo,goods) == false andalso GoldCost > 0 ->
						spawn(fun() ->log:log_shop([1,1,PlayerStatus#player.id,PlayerStatus#player.nickname,RuneTypeId,gold,GoldCost,1]) end);
					   true ->
						skip
					end,
                     {reply, [NewPlayerStatus, 1, NewGoodsTypeId], NewStatus};
				{fail, NewPlayerStatus, NewStatus, NewGoodsTypeId} ->
                     {reply, [NewPlayerStatus, 0, NewGoodsTypeId], NewStatus};
                 Error ->
                     ?ERROR_MSG("mod_goods compose:~p", [Error]),
                     {reply, [PlayerStatus, 0, 0], GoodsStatus}
            end
    end;

%% 宝石镶嵌
handle_call({'inlay', PlayerStatus, GoodsId, StoneId, StoneTypeId, Auto_purch, RuneList}, _From, GoodsStatus) ->
    case check_inlay(PlayerStatus, GoodsId, StoneId, StoneTypeId, Auto_purch, RuneList) of
        {fail, Res} -> 
            {reply, [PlayerStatus, Res, []], GoodsStatus};
        {ok, GoodsInfo, StoneInfo, TotalRuneNum,Rbind,NewRuneList, GoodsInlayRule,Cost,GoldCost} ->
            case (catch lib_make:inlay(PlayerStatus, GoodsStatus, GoodsInfo, StoneInfo, TotalRuneNum,Rbind,NewRuneList, GoodsInlayRule,Cost,Auto_purch,GoldCost)) of
                {ok, Res, NewPlayerStatus, NewStatus} ->
					if Auto_purch ==1 andalso GoldCost > 0 ->
						spawn(fun() ->log:log_shop([1,1,PlayerStatus#player.id,PlayerStatus#player.nickname,StoneTypeId,gold,GoldCost,1]) end);
					   true ->
						skip
					end,
					{reply, [NewPlayerStatus, Res, GoodsInfo], NewStatus};
                 Error ->
                     ?ERROR_MSG("mod_goods inlay:~p", [Error]),
                     {reply, [PlayerStatus, 10, GoodsInfo], GoodsStatus}
            end
    end;

%% 装备精炼
handle_call({'refine',Player,Gid,StoneList},_From,GoodsStatus) ->
	case check_refine(Player,Gid,StoneList) of
		{fail,Res} ->
			{reply,[Player,Res],GoodsStatus};
		{ok,GoodsInfo,Cost,RBind,NewStoneList} ->
			case (catch lib_make:refine(Player,GoodsStatus,GoodsInfo,NewStoneList,Cost,RBind)) of
				{ok,Res,NewPlayer,NewStatus} ->
					{reply,[NewPlayer,Res],NewStatus};
				Error ->
					?ERROR_MSG("mod_goods refine:~p",[Error]),
					{reply,[Player,0],GoodsStatus}
			end
	end;

%% 装备分解
handle_call({'idecompose',Player,Type,GoodsList},_From,GoodsStatus) ->

	case check_idecompose_list(Player,GoodsStatus,Type,GoodsList) of
		{fail,Res} ->
			{reply,[Player,Res,0,[]],GoodsStatus};
		{ok,Cost,GoodsInfoList,GoodsTotalList} ->		
			case (catch lib_make:idecompose(Player,GoodsStatus,GoodsInfoList,Type,Cost,GoodsTotalList)) of
				{ok,Res,NewPlayer,NewStatus} ->						
					{reply,[NewPlayer,Res,Cost,GoodsTotalList],NewStatus};
				Error ->
					?ERROR_MSG("mod_Goods idecompose:~p",[Error]),
					{reply,[Player,0,0,[]],GoodsStatus}
			end
	end;

%% 材料合成
handle_call({'icompose',Player,Mid,N},_From,GoodsStatus) ->
	case check_icompose(Player,Mid,N,GoodsStatus) of
		{fail,Res} ->
			{reply,[Player,Res,0,0],GoodsStatus};
		{ok,IcomposeRule} ->
			case (catch lib_make:icompose(Player,GoodsStatus,IcomposeRule,N)) of
				{ok,Res,Snum,Fnum,NewPlayer,NewStatus} ->
					{reply,[NewPlayer,Res,Snum,Fnum],NewStatus};
				Error ->
					?ERROR_MSG("mod_Goods icompose:~p",[Error]),
					{reply,[Player,0,0,0],GoodsStatus}
			end
	end;

%% 宝石拆除
handle_call({'backout', PlayerStatus, GoodsId, StoneId, StoneTypeId, Auto_purch, RuneList}, _From, GoodsStatus) ->
    case check_backout(PlayerStatus, GoodsStatus, GoodsId,StoneId,StoneTypeId,Auto_purch,RuneList) of
        {fail, Res} ->
            {reply, [PlayerStatus, Res,GoodsId], GoodsStatus};
        {ok,GoodsInfo,StoneTypeInfo,TotalRuneNum,NewRuneList,GoodsInlayRune,Rbind,Cost,GoldCost} ->
            case (catch lib_make:backout(PlayerStatus, GoodsStatus, GoodsInfo,StoneTypeInfo, TotalRuneNum,NewRuneList,GoodsInlayRune,Rbind,Cost,Auto_purch,GoldCost)) of
                {ok, Res,NewPlayerStatus, GoodsStatus2,GoodsId2} ->
					if Auto_purch ==1 andalso GoldCost > 0 ->
						spawn(fun() ->log:log_shop([1,1,PlayerStatus#player.id,PlayerStatus#player.nickname,StoneTypeId,gold,GoldCost,1]) end);
					   true ->
						skip
					end,
                     {reply, [NewPlayerStatus,Res,GoodsId2], GoodsStatus2};
                 Error ->
                     ?ERROR_MSG("mod_goods backout:~p", [Error]),
                     {reply, [PlayerStatus, 0,GoodsId], GoodsStatus}
            end
    end;

%%鉴定属性
handle_call({'identify',PlayerStatus,GoodsId,StoneId,StoneTypeId,Auto_purch},_Form,GoodsStatus) ->
	case check_identify(PlayerStatus,GoodsId,StoneId,StoneTypeId,Auto_purch) of
		{fail,Res} ->
			{reply,[PlayerStatus,Res,0,[]],GoodsStatus};
		{ok,StoneInfo,GoodsInfo,AttributeList,GoldCost} ->
			case (catch lib_make:identify(PlayerStatus, GoodsStatus, GoodsInfo, StoneInfo, AttributeList, GoldCost)) of
				{ok,NewPlayerStatus,NewGoodsStatus,StoneNum,NewAttributeList} ->
					spawn(fun()->catch(log:log_identify(PlayerStatus,GoodsInfo,StoneInfo#goods.id,0,1))end),
					if Auto_purch ==1 andalso is_record(StoneInfo,goods) == false andalso GoldCost > 0 ->
						spawn(fun() ->log:log_shop([1,1,PlayerStatus#player.id,PlayerStatus#player.nickname,StoneTypeId,gold,GoldCost,1]) end);
					   true ->
						skip
					end,
					{reply,[NewPlayerStatus,1,StoneNum,NewAttributeList],NewGoodsStatus};
				Error ->
					?ERROR_MSG("mod_goods/identify/error/~p",[Error]),
					{reply,[PlayerStatus,0,[]],GoodsStatus}
			end
	end;

%%法宝修炼
handle_call({'practise',PlayerStatus,GoodsId,Type},_Form,GoodsStatus) ->
	case check_practise(PlayerStatus,GoodsId) of
		{fail,Res} ->
			{reply,[PlayerStatus,Res],GoodsStatus};
		{ok,GoodsInfo,GoodsPractiseRule,AddAttributeList} ->
			if
				Type == 1 ->
					case (catch lib_make:practise(PlayerStatus,GoodsStatus,GoodsInfo,GoodsPractiseRule,AddAttributeList)) of
						{ok,NewPlayerStatus} ->
				  			{reply,[NewPlayerStatus,1],GoodsStatus};
						Error ->
							?ERROR_MSG("mod_goods/practise/error/~P",[Error]),
							{reply,[PlayerStatus,0],GoodsStatus}
					end;
				true ->
					case lib_make:full_practise(PlayerStatus,GoodsStatus,GoodsInfo,AddAttributeList) of
						{ok,NewPlayerStatus} ->
				  			{reply,[NewPlayerStatus,1],GoodsStatus};
						Error ->
							?ERROR_MSG("mod_goods/practise/error/~P",[Error]),
							{reply,[PlayerStatus,0],GoodsStatus}
					end
			end
	end;

%%法宝融合
handle_call({'merge',PlayerStatus,GoodsId1,GoodsId2},_Form,GoodsStatus) ->
	case check_merge(PlayerStatus,GoodsId1,GoodsId2) of
		{fail,Res} ->
			{reply,[PlayerStatus,Res],GoodsStatus};
		{ok,GoodsInfo1,GoodsInfo2} ->
			case (catch lib_make:merge(PlayerStatus,GoodsStatus,GoodsInfo1,GoodsInfo2)) of
				{ok,NewPlayerStatus,NewGoodsStatus,MerType} ->
%% 					lib_task:event(trump, null, NewPlayerStatus),
					{reply,[NewPlayerStatus,MerType],NewGoodsStatus};
				Error ->
					?ERROR_MSG("mod_goods/merge/error/~p",[Error]),
					{reply,[PlayerStatus,0],GoodsStatus}
			end
	end;

%%法宝融合预览
handle_call({'merge_preview',PlayerStatus,GoodsId1,GoodsId2},_Form,GoodsStatus) ->
	case check_merge(PlayerStatus,GoodsId1,GoodsId2) of
		{fail, _Res} ->
			{reply,[{},0,[]],GoodsStatus};
		{ok,GoodsInfo1,GoodsInfo2} ->
			case lib_make:merge_preview(PlayerStatus,GoodsInfo1,GoodsInfo2) of
				{ok,NewGoodsInfo,NewAttributeList} ->
					MagicAttributeList = goods_util:get_goods_attribute_list(PlayerStatus#player.id,NewGoodsInfo#goods.id,7),
					{reply,[NewGoodsInfo,0,NewAttributeList++MagicAttributeList],GoodsStatus};
				Error ->
					?ERROR_MSG("mod_goods/merge_preview/error/~p",[Error]),
					{reply,[{},0,[]],GoodsStatus}
			end
	end;

%%神装炼化
handle_call({'70equipsmelt',Player,GoodsId,Type,Cllist},_Form,GoodsStatus) ->
	case check_equipsmelt(Player,GoodsId,Type,Cllist) of
		{fail,Res} ->
			{reply,[Res,Player,[{},0,[]]],GoodsStatus};
		{ok,GoodsInfo,GoodsInfoList,JPn,MYn,HFn,Cost,Bind}-> %%HF 护符
			case lib_make:equip_smelt_70(Player,GoodsStatus,GoodsInfo,GoodsInfoList,JPn,MYn,HFn,Cost,Bind,Type) of 
				{ok,NewPlayer,NewStatus,[NewGoodsInfo,SuitNum,AttributeList]} ->
					{reply,[1,NewPlayer,[NewGoodsInfo,SuitNum,AttributeList]],NewStatus};
				{fail,_,_,_,_} ->
					{reply,[0,Player,[{},0,[]]],GoodsStatus}
			end
	end;
				

handle_call({'fashion_change', _PlayerStatus,NewTypeId, Info, GidList},_From,GoodsStatus) ->
	F = fun(Gid) -> 
				ets:insert(?ETS_GOODS_ONLINE,Info#goods{goods_id = NewTypeId}),
				spawn(fun() -> db_agent:fashion_change(Gid, NewTypeId) end)
		end,
	[F(Gid) || Gid <- GidList],
	{reply,[],GoodsStatus};

%%60紫套淬炼
handle_call({'smelt',PlayerStatus,GoodsId,GoodsList},_Form,GoodsStatus) ->
	case check_smelt(PlayerStatus,GoodsId,GoodsList) of
		{fail,Ret} ->
			{reply,[Ret,0,PlayerStatus],GoodsStatus};
		{ok,GoodsInfo,GoodsInfoList,Cost} ->
			case lib_make:smelt(PlayerStatus,GoodsStatus,GoodsInfo,GoodsInfoList,Cost) of
				{ok,Repair,NewPlayer,NewGoodsStatus} ->
					{reply,[1,Repair,NewPlayer],NewGoodsStatus};
				Error ->
					?ERROR_MSG("mod_goods/merge_preview/error/~p",[Error]),
					{reply,[0,0,PlayerStatus],GoodsStatus}
			end
	end;

%%时装洗炼
handle_call({'fashion_wash',PlayerStatus,GoodsId,StoneId,Oper,StoneTypeId,Auto_purch},_Form,GoodsStatus) ->
	%%没有未替换的洗炼属性
	case check_fashion_wash(PlayerStatus,GoodsId,StoneId,StoneTypeId,Auto_purch) of
		{fail,Ret} ->
			{reply,[Ret,GoodsId,0,0,PlayerStatus#player.coin,PlayerStatus#player.bcoin,[],PlayerStatus],GoodsStatus};
		{ok,GoodsInfo,StoneInfo,GoldCost} ->
			case lib_make:fashion_wash(PlayerStatus,GoodsStatus,GoodsInfo,StoneInfo,Oper,StoneTypeId,Auto_purch,GoldCost) of
				{ok,GoodsId,Is_wash,Cost,Coin,Bcion,Goods_attributList,NewPlayerStatus,GoodsStatus1} ->
					case Oper == 2 of %%洗炼
						true ->
							if Auto_purch ==1 andalso is_record(StoneInfo,goods) == false andalso GoldCost > 0 ->
								spawn(fun() ->log:log_shop([1,1,PlayerStatus#player.id,PlayerStatus#player.nickname,StoneTypeId,gold,GoldCost,1]) end);
							   true ->
								skip
							end,
							{reply,[1,GoodsId,Is_wash,Cost,Coin,Bcion,Goods_attributList,NewPlayerStatus],GoodsStatus1};
						false ->  %%预览
							{reply,[7,GoodsId,Is_wash,Cost,Coin,Bcion,Goods_attributList,NewPlayerStatus],GoodsStatus1}
					end;
				{fail,GoodsId,Is_wash,Cost,Coin,Bcion,Goods_attributList,NewPlayerStatus,GoodsStatus1} ->
					{reply,[6,GoodsId,Is_wash,Cost,Coin,Bcion,Goods_attributList,NewPlayerStatus],GoodsStatus1};
				Error ->
					?ERROR_MSG("mod_goods/fashion_wash/error/~p",[Error]),
					{reply,[0,GoodsId,0,0,PlayerStatus#player.coin,PlayerStatus#player.bcoin,[],PlayerStatus],GoodsStatus}
			end
	end;


%%Oper替换新的洗炼属性(1)或维持原因属性(0)
handle_call({'fashion_oper',PlayerStatus,GoodsId,Oper},_Form,GoodsStatus) ->
	%%没有未替换的洗炼属性
	case check_fashion_wash(PlayerStatus,GoodsId,0,0,0) of
		{fail,Ret} ->
			{reply,[Ret,GoodsId,[]],GoodsStatus};
		{ok,GoodsInfo,_,_} ->
			[Goods_attributList,NewPlayerStatus,NewGoodsStatus] =  lib_make:fashion_oper(PlayerStatus,GoodsStatus,GoodsInfo,Oper), 
			{reply,[1,GoodsId,Goods_attributList,NewPlayerStatus],NewGoodsStatus}
	end;


%%紫戒指祝福,遗弃
handle_call({'ring_bless',PlayerStatus,GoodsId, Oper, ClassOrMagicIdList},_Form,GoodsStatus) ->
	%%没有未替换的洗炼属性
	case check_ring_bless(PlayerStatus,GoodsId, Oper, ClassOrMagicIdList) of
		 {fail, Res} ->
            {reply, [PlayerStatus, Res], GoodsStatus};
        {ok, GoodsInfo, NewClassOrMagicInfoList, Cost} ->
            case (catch lib_make:ring_bless(PlayerStatus, GoodsStatus, GoodsInfo, NewClassOrMagicInfoList, Cost, Oper)) of
                {ok, Res, NewPlayerStatus, NewStatus} ->
                     {reply, [NewPlayerStatus, Res], NewStatus};
                 Error ->
                     ?ERROR_MSG("mod_goods ring_bless:~p", [Error]),
                     {reply, [PlayerStatus, 12], GoodsStatus}
            end
    end;

%%时装备附魔
handle_call({'equip_magic',PlayerStatus,GoodsId,MagicStoneId,MagicStoneTypeId,Auto_purch,Oper,PropsList},_Form,GoodsStatus) ->
	%%没有未替换的洗炼属性
	case check_equip_magic(PlayerStatus,GoodsId,MagicStoneId,MagicStoneTypeId,Auto_purch,Oper,PropsList) of
		{fail,Ret} ->
			{reply,[Ret,GoodsId,0,0,PlayerStatus#player.coin,PlayerStatus#player.bcoin,[],0,PlayerStatus],GoodsStatus};
		{ok,GoodsInfo,MagicStoneInfo,NewProps,Num,GoldCost,TotalNum,GoldCost1} ->
			case lib_make:make_equip_magic(PlayerStatus,GoodsStatus,GoodsInfo,MagicStoneInfo,MagicStoneTypeId,GoldCost,Oper,NewProps,Num,TotalNum,GoldCost1) of
				{ok,GoodsId,Is_Magic,Cost,Coin,Bcion,Goods_attributList,NewPlayerStatus,GoodsStatus1} ->
					case Oper == 1 of %%附魔
						true ->
							if Auto_purch ==1 andalso is_record(MagicStoneInfo,goods) == false andalso GoldCost > 0 ->
								   spawn(fun() ->log:log_shop([1,1,PlayerStatus#player.id,PlayerStatus#player.nickname,MagicStoneTypeId,gold,GoldCost,1]) end);
							   true ->
								   skip
							end,
							{reply,[1,GoodsId,Is_Magic,Cost,Coin,Bcion,Goods_attributList,GoodsInfo#goods.level,NewPlayerStatus],GoodsStatus1};
						false ->  %%预览
							{reply,[10,GoodsId,Is_Magic,Cost,Coin,Bcion,Goods_attributList,GoodsInfo#goods.level,NewPlayerStatus],GoodsStatus1}
					end;
				{fail1,GoodsId,Is_Magic,Cost,Coin,Bcion,Goods_attributList,NewPlayerStatus,GoodsStatus1} ->
					{reply,[9,GoodsId,Is_Magic,Cost,Coin,Bcion,Goods_attributList,0,NewPlayerStatus],GoodsStatus1};
				{fail2,GoodsId,Is_Magic,Cost,Coin,Bcion,Goods_attributList,NewPlayerStatus,GoodsStatus1} ->
					{reply,[10,GoodsId,Is_Magic,Cost,Coin,Bcion,Goods_attributList,0,NewPlayerStatus],GoodsStatus1};
				Error ->
					?ERROR_MSG("mod_goods/equip_magic/error/~p",[Error]),
					{reply,[0,GoodsId,0,0,PlayerStatus#player.coin,PlayerStatus#player.bcoin,[],0,PlayerStatus],GoodsStatus}
			end
	end;

%%Oper替换新的洗炼属性(1)或维持原因属性(0)
handle_call({'magic_oper',PlayerStatus,GoodsId,Oper},_Form,GoodsStatus) ->
	%%没有未替换的洗炼属性
	case check_equip_magic(PlayerStatus,GoodsId,0,0,0,0,[]) of
		{fail,Ret} ->
			{reply,[Ret,GoodsId],GoodsStatus};
		{ok,GoodsInfo,_,_,_,_,_,_} ->
			[Res,NewPlayerStatus,NewGoodsStatus] =  lib_make:magic_oper(PlayerStatus,GoodsStatus,GoodsInfo,Oper), 
			{reply,[Res,GoodsId,NewPlayerStatus],NewGoodsStatus}
	end;


%%%%%%%
%% 整理背包
%% handle_call({'clean', PlayerStatus}, _From, GoodsStatus) ->
%%     %% 查询背包物品列表
%%     GoodsList = goods_util:get_goods_list(GoodsStatus#goods_status.player_id, 4),
%%     %% 按物品类型ID排序
%%     GoodsList1 = goods_util:sort(GoodsList, goods_id),
%%     %% 整理
%%     [Num, _] = lists:foldl(fun lib_goods:clean_bag/2, [1, {}], GoodsList1),
%%     %% 重新计算
%%     NewGoodsList = goods_util:get_goods_list(GoodsStatus#goods_status.player_id, 4),
%% 	%% ps
%%     NullCells = lists:seq(Num, PlayerStatus#player.cell_num),
%%     NewGoodsStatus = GoodsStatus#goods_status{  null_cells = NullCells },
%%    {reply, NewGoodsList, NewGoodsStatus};


%%17006 拍卖购买物品进入物品背包
handle_call({'sale_give_goods', PlayerId, Goods, GoodsAttributes}, _From, GoodsStatus) ->
	case length(GoodsStatus#goods_status.null_cells) < 1 of
		true ->%%背包空间不足
			Result = 7,
			NewGoodsStatus = GoodsStatus;
		false ->
			{Result, NewGoodsStatus} = lib_sale:sale_give_goods(PlayerId, Goods, GoodsAttributes, GoodsStatus),
			lib_player:refresh_client(NewGoodsStatus#goods_status.pid_send, 2)
	end,
	{reply, {ok, Result}, NewGoodsStatus};


%%添加（可以是批量）诛邪仓库物品
handle_call({'add_box_goods', OpenCount, GoodsList}, _From, GoodsStatus) ->
	case OpenCount > GoodsStatus#goods_status.box_remain_cells of
		true ->
			Reply = [3, {3, 0, []}],
			{reply, Reply, GoodsStatus};
		false ->
			case (catch lib_box:add_box_goods_group(GoodsList, GoodsStatus)) of
				{ok, Result, NewGoodsStatus} ->
					{reply, Result, NewGoodsStatus};
				{fail, Error, NewGoodsStatus} ->
					{reply, Error, NewGoodsStatus}
			end
	end;

%%获取诛邪仓库的物品数据
handle_call({'get_box_goods', PlayerId}, _From, GoodsStatus) ->
	BoxGoodsList = lib_box:get_box_goods(PlayerId),
	{reply, BoxGoodsList, GoodsStatus};
%% 	GoodsTypeInfo = goods_util:get_goods_type(GoodsTypeId),
%%     NewInfo = goods_util:get_new_goods(GoodsTypeInfo),

%%  将诛邪仓库物品放入背包
handle_call({'goods_box_to_bag', PlayerId, GoodsId, GoodsNum}, _From, GoodsStatus) ->
	case 1 > length(GoodsStatus#goods_status.null_cells) of
		true ->
			Result = [2],
			NewGoodsStatus = GoodsStatus;
		false ->
			ApplyList = [{GoodsId, GoodsNum}],
			{Result, NewGoodsStatus} = lib_box:goods_box_to_bag(PlayerId, ApplyList, GoodsStatus)
	end,
	{reply, Result, NewGoodsStatus};

handle_call({'all_goods_box_to_bag',PlayerId}, _From, GoodsStatus) ->
	ApplyList = lib_box:get_all_box_goodstobag_needed(PlayerId),
	ApplyLen = length(ApplyList),
	case ApplyLen of
		0 ->
			Result = [2],
			NewGoodsStatus = GoodsStatus;
		_ ->
			case ApplyLen > length(GoodsStatus#goods_status.null_cells) of
				true ->
					Result = [2],
					NewGoodsStatus = GoodsStatus;
				false ->
					{Result, NewGoodsStatus} = 
						lib_box:goods_box_to_bag(PlayerId, ApplyList, GoodsStatus)
			end
	end,
	{reply, Result, NewGoodsStatus};
		

%%将诛邪仓库的物品丢弃(单个)
handle_call({'delete_box_goods', PlayerId, GoodsId, GoodsNum}, _From, GoodsStatus) ->
	case lib_box:check_delete_boxgoods(PlayerId, GoodsId, GoodsNum) of
		{fail, _Res} ->
			NewGoodsStatus = GoodsStatus,
			Result = [0];
		{ok, GoodsInfo} ->
			case (catch lib_box:delete_box_goods(GoodsInfo, GoodsStatus)) of
				{ok, NewGoodsStatus} ->
					ThrowTime = util:unixtime(),
					spawn(lib_box, delete_box_goods_log, [ThrowTime, PlayerId, GoodsInfo]),
					Result = [1];
				{fail, NewGoodsStatus} ->
					Result = [0]
			end
	end,
	{reply, Result, NewGoodsStatus};

handle_call({'delete_all_box_goods', PlayerId}, _From, GoodsStatus) ->
	case (catch lib_box:delete_all_box_goods(PlayerId, GoodsStatus))of
		{fail, NewGoodsStatus} ->
			Result = [0];
		{ok, NewGoodsStatus} ->
			Result = [1]
	end,
	{reply, Result, NewGoodsStatus};
%%获取当前诛邪仓库的剩余容量
handle_call({'get_box_storage'}, _From, GoodsStatus) ->
	{reply, GoodsStatus#goods_status.box_remain_cells, GoodsStatus};

%% 赠送物品
handle_call({'give_goods', _PlayerStatus, GoodsTypeId, GoodsNum}, _From, GoodsStatus) ->
    case (catch lib_goods:give_goods({GoodsTypeId, GoodsNum}, GoodsStatus)) of
        {ok, NewStatus} ->
            lib_player:refresh_client(NewStatus#goods_status.pid_send, 2),
            {reply, ok, NewStatus};
        {fail, Error, Status} ->
            {reply, Error, Status}
    end;
%% 进程间调用添加物品，可设置绑定状态 0未绑定1暂不用2绑定
handle_call({'give_goods',_PlayerStatus,GoodsTypeId,GoodsNum,Bind},_From,GoodsStatus) ->
	case (catch lib_goods:give_goods({GoodsTypeId, GoodsNum ,Bind}, GoodsStatus)) of
        {ok, NewStatus} ->
            lib_player:refresh_client(NewStatus#goods_status.pid_send, 2),
            {reply, ok, NewStatus};
        {fail, Error, Status} ->
            {reply, Error, Status}
    end;
%% 进程间调用添加物品，可设置物品过期时间
handle_call({'give_goods',_PlayerStatus,GoodsTypeId,GoodsNum,Bind,ExpireTime},_From,GoodsStatus) ->
	case (catch lib_goods:give_goods({GoodsTypeId, GoodsNum ,Bind,ExpireTime, 0}, GoodsStatus)) of
        {ok, NewStatus} ->
            lib_player:refresh_client(NewStatus#goods_status.pid_send, 2),
            {reply, ok, NewStatus};
        {fail, Error, Status} ->
            {reply, Error, Status}
    end;
%% 进程间调用添加物品，可设置绑定状态 0未绑定1暂不用2绑定，可设置交易状态，0：系统默认，1：强制性设成不可交易，2:强制性设成可交易
handle_call({'give_goods_bt', _PlayerStatus, GoodsTypeId, GoodsNum, Bind, Trade}, _From, GoodsStatus) ->
	case (catch lib_goods:give_goods_bt({GoodsTypeId, GoodsNum ,Bind, Trade}, GoodsStatus)) of
        {ok, NewStatus} ->
            lib_player:refresh_client(NewStatus#goods_status.pid_send, 2),
            {reply, ok, NewStatus};
        {fail, Error, Status} ->
            {reply, Error, Status}
    end;

%%仅提供给邮件收取附件使用，若其他模块调用，请先联系xiaomai
handle_call({'give_goods_exsit', GoodsId, PlayerId}, _From, GoodsStatus) ->
	case length(GoodsStatus#goods_status.null_cells) > 0 of
		false ->
			NewGoodsStatus = GoodsStatus,
			Reply = {error, 2};
		true ->
			case db_agent:mail_get_goods_by_id(GoodsId) of
				[] ->
					NewGoodsStatus = GoodsStatus,
					Reply = {error, 4};
				[Goods] ->
					[Cell|NullCells] = GoodsStatus#goods_status.null_cells,
					lib_mail:add_online_goods(Goods, Cell, PlayerId),
					NewNullCells = lists:sort(NullCells),
					%% 更新背包空格列表
					NewGoodsStatus = GoodsStatus#goods_status{null_cells = NewNullCells},
					lib_player:refresh_client(NewGoodsStatus#goods_status.pid_send, 2),   %% 刷新背包
					Reply = {ok, 1}
			end
	end,
	{reply, Reply, NewGoodsStatus};
													
%% 赠送物品
%% GoodsList = [{GoodsTypeId, GoodsNum},...]
%% GoodsList = [{GoodsTypeId, GoodsNum,Bind},...]
%% GoodsList = [{GoodsTypeId, GoodsNum,Bind,Expire,Trade},...]
handle_call({'give_more', _PlayerStatus, GoodsList}, _From, GoodsStatus) ->
    case (catch goods_util:list_handle(fun lib_goods:give_goods/2, GoodsStatus, GoodsList)) of
        {ok, NewStatus} ->
            lib_player:refresh_client(NewStatus#goods_status.pid_send, 2),
            {reply, ok, NewStatus};
        {fail, Error, Status} ->
            {reply, Error, Status}
    end;

%%添加任务物品  注意!任务物品不能修改物品Status
handle_call({'give_task_goods', _PlayerStatus, GoodsTypeId, GoodsNum}, _From, GoodsStatus) ->
	case (catch lib_goods:give_task_goods({GoodsTypeId, GoodsNum},GoodsStatus))of
        {ok} ->
            %%lib_player:refresh_client(GoodsStatus#goods_status.socket, 2),
            {reply, ok, GoodsStatus};
        {fail, Error} ->
            {reply, Error, GoodsStatus}
    end;

%%怪物掉落任务物品
handle_call({'mon_drop_task_goods',PlayerId,GoodsTypeId,GoodsNum,GoodsTypeInfo},_From,GoodsStatus)->
	%% 任务物品不影响Status
    Pattern = #goods{player_id=PlayerId, goods_id=GoodsTypeId, location=6, _='_'},
    GoodsInfo = goods_util:get_ets_info(?ETS_GOODS_ONLINE, Pattern),
    case is_record(GoodsInfo, goods) of
		true ->
			NewNum = GoodsInfo#goods.num + GoodsNum,
			lib_goods:change_goods_num(GoodsInfo, NewNum);
		false ->   
			GoodsInfo1 = goods_util:get_new_goods(GoodsTypeInfo),
            GoodsInfo2 = GoodsInfo1#goods{ player_id=PlayerId, location=6, num=GoodsNum },
			lib_goods:add_goods(GoodsInfo2),
            NewNum = GoodsNum
     end,     	
   {reply, {ok,NewNum}, GoodsStatus};
  
%% 获取空格子数
handle_call({'cell_num'}, _From, GoodsStatus) ->
    {reply, length(GoodsStatus#goods_status.null_cells), GoodsStatus};
%% 获取空格子情况
handle_call({'null_cell'} , _From, GoodsStatus) ->
    {reply, GoodsStatus#goods_status.null_cells, GoodsStatus};

%% 坐骑状态切换
handle_call({'changeMountStatus',PlayerStatus,MountId},_From,GoodsStatus) ->
	case check_change_mount_status(PlayerStatus,MountId) of
		{fail,NewPlayerStatus,Res} ->
			{reply,[Res,0,NewPlayerStatus],GoodsStatus};
		{ok,NewPlayerStatus,MountInfo} ->
			case (catch lib_goods:change_mount_status(NewPlayerStatus,MountInfo)) of
				{ok,NewPlayerStatus1,MountType} ->
					{reply,[1,MountType,NewPlayerStatus1],GoodsStatus};
				Error ->
					?ERROR_MSG("mod_goods changeMountStatusErr:~p",[Error]),
					{reply,[0,0,NewPlayerStatus],GoodsStatus}
			end
	end;

%% 坐骑状态切换
handle_call({'changeGoodsMount',PlayerStatus,MountId},_From,GoodsStatus) ->
	case check_goods_mount(PlayerStatus,MountId) of
		{fail,NewPlayerStatus,Res} ->
			{reply,[Res,0,NewPlayerStatus],GoodsStatus};
		{ok,NewPlayerStatus,MountInfo} ->
			case (catch lib_goods:change_goods_mount(NewPlayerStatus,MountInfo)) of
				{ok,NewPlayerStatus1,MountType} ->
					{reply,[1,MountType,NewPlayerStatus1],GoodsStatus};
				Error ->
					?ERROR_MSG("mod_goods changeMountStatusErr:~p",[Error]),
					{reply,[0,0,NewPlayerStatus],GoodsStatus}
			end
	end;


%%卸下坐骑
handle_call({'force_off_mount',PlayerStatus},_From,GoodsStatus) ->
	case (catch lib_goods:force_off_mount(PlayerStatus)) of
		{ok,NewPlayerStatus} ->
			{reply,[1,NewPlayerStatus],GoodsStatus};
		Error ->
			?ERROR_MSG("mod_goods forceOffMount:~p",[Error]),
			{reply,[0,PlayerStatus],GoodsStatus}
	end;

%%重新load玩家物品信息(仅交易模块使用)
%% handle_call({'reload_goods', PlayerId, CellNum, DBGoodsRecord}, _From, GoodsStatus) ->
%% 	%%先清数据
%% %% 	Result = 
%% 	lib_trade:reload_goods_for_trade(true, PlayerId, DBGoodsRecord),
%% %% 	io:format("  reload goods now: ~p,~p\n  ~p\n",[PlayerId, DBGoodsRecord, Result]),
%% 	%%重新初始化
%% 	NullCells = goods_util:get_null_cells(PlayerId, CellNum),
%% 	NewGoodsStatus = GoodsStatus#goods_status{null_cells = NullCells}, 
%% 	{reply, ok, NewGoodsStatus};

%%拍卖市场模块使用的删除物品记录操作(仅删记录，改id)
handle_call({'delete_sale_goods', GoodsId, Location, PlayerId}, _From, GoodsStatus) ->
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
			case lib_sale:get_sale_goods_id(GoodsId) of
				[] ->
					GPlayerId = 0;
				[GPlayerId, _GTID] ->
					ok
			end,
			if 
				%%绑定物品不可拍卖
				GoodsInfo#goods.bind /= 0 -> 
					Reply = {fail, 2},
					NewGoodsStatus = GoodsStatus;
				GoodsInfo#goods.trade /= 0 -> 
					Reply = {fail, 8},
					NewGoodsStatus = GoodsStatus;
				GoodsInfo#goods.location =/= 4 ->
					Reply = {fail, 4},
					NewGoodsStatus = GoodsStatus;
				GPlayerId =/= PlayerId ->%% 物品不属于本人
					Reply = {fail, 4},
					NewGoodsStatus = GoodsStatus;
				true ->
					case goods_util:get_goods_name(GoodsInfo#goods.goods_id) of
						<<>> ->
							NewGoodsStatus = GoodsStatus,
							Reply = {fail, 0};
						GoodsName ->
							NullCells = lists:sort([GoodsInfo#goods.cell|GoodsStatus#goods_status.null_cells]),
							NewGoodsStatus = GoodsStatus#goods_status{null_cells = NullCells},
							%%更新玩家的物品表(把playerid置0)
							GoodsValueList = [{player_id, 0}, {cell, 0}],
							GoodsWhereList = [{id, GoodsId}],
							db_agent:update_goods_owner(GoodsValueList, GoodsWhereList),
							lib_sale:ets_delete_goods_info(GoodsInfo#goods.id),
							lists:foreach(fun lib_sale:update_goods_attribute/1, AttributeList),
							Reply = {ok, GoodsName, GoodsInfo, AttributeList}
					end
			end;
        _Error ->
			Reply = {fail, 4},
			NewGoodsStatus = GoodsStatus
    end,
	{reply, Reply, NewGoodsStatus};

%% key 0邀请卡（基本不用） 1新手卡 2皇室特权卡 3贵族特权卡 4公民特权卡 5礼包A 6礼包B 7礼包C 8礼包D 9神马大礼包10VIP周卡 
%% 		11强化工具包12气血满满包13通经拓脉14封神体验包15神兵初试包16随心传送包17热浪发骚包18远古风云礼包
%% 使用各种远古封神卡(15090)
handle_call({'use_ygfs_card', PlayerStatus, CardString}, _From, GoodsStatus)->
	Len = length(GoodsStatus#goods_status.null_cells),
	%%4399是生成新手卡号。其他平台按算法生成。
	if
		Len > 0 ->
			[Ret, Key] = lib_goods:active_ygfs_card(PlayerStatus, CardString),
			if
				Ret =:= 1 ->
					case Key of
						1 ->
							%% 28119 新手卡礼包
							case catch lib_goods:give_goods({28119, 1 ,2}, GoodsStatus) of
								{ok, NewGoodsStatus} ->
									NewPlayerStatus=lib_goods:add_money(PlayerStatus, 20000, bcoin, 1503),
									lib_player:refresh_client(NewGoodsStatus#goods_status.pid_send, 2),
									{reply, [Ret, NewPlayerStatus], NewGoodsStatus};
								_ ->
									{reply, [0, PlayerStatus], GoodsStatus}
							end;	
						_ ->
                            GiftList = [
                                {2, 28162}, 			%% 皇室特权礼包
                                {3, 28161}, 			%% 贵族特权礼包
                                {4, 28160}, 			%% 公民特权卡
                                {5, 28173}, 			%% 礼包A
                                {6, 28174}, 			%% 礼包B
                                {7, 28175}, 			%% 礼包C
                                {8, 28176}, 			%% 礼包D
                                {9, 28129}, 			%% 神马大礼包
                                {10, 28603}, 			%% VIP周卡
                                {11, 31007}, 			%% 强化工具包
                                {12, 31008}, 			%% 气血满满包
                                {13, 31009}, 			%% 通经拓脉包
                                {14, 31010}, 			%% 封神体验包
                                {15, 31011}, 			%% 神兵初试包
                                {16, 31012}, 			%% 随心传送包
                                {17, 28188}, 			%% 热浪发骚包
                                {18, 31020}, 			%% 远古风云礼包
                                {19, 28707}, 			%% 好友邀请礼包
                                {20, 31053}, 			%% 360远古封神春节大礼包
                                {21, 31063}, 			%% 团结力量礼包
 								{22, 31070} 			%% 手机绑定礼包
                            ],
							case lists:keyfind(Key, 1, GiftList) of
								false ->
									{reply, [0, PlayerStatus], GoodsStatus};
								{_Key, GoodsTypeId} ->
									case catch lib_goods:give_goods({GoodsTypeId, 1, 2}, GoodsStatus) of
										{ok, NewGoodsStatus} ->
											lib_player:refresh_client(NewGoodsStatus#goods_status.pid_send, 2),
											{reply, [Ret, PlayerStatus], NewGoodsStatus};
										_ ->
											{reply, [0, PlayerStatus], GoodsStatus}
									end
							end
					end;
				true ->
					{reply, [Ret, PlayerStatus], GoodsStatus}	
			end;
		true ->
			{reply, [6, PlayerStatus], GoodsStatus}
	end;
	
%% -----------------------------------------------------------------
%% 40052 取出氏族仓库物品
%% -----------------------------------------------------------------
handle_call({'TACKOUT_FROM_GUILD_WAREHOUSE', GoodsInfo, AttributesList}, _From, GoodsStatus) ->
	PlayerId = GoodsStatus#goods_status.player_id, 
	BagNumRemain = length(GoodsStatus#goods_status.null_cells),
	Reply = 
		case BagNumRemain < 1 of
			true ->
				NewGoodsStatus = GoodsStatus,
				{fail, 5};
			false ->
				[Cell|RemailCells] = GoodsStatus#goods_status.null_cells,
				case lib_guild_warehouse:put_goods_into_bag(GoodsInfo, Cell, 4, AttributesList, PlayerId) of
					ok ->
						NewGoodsStatus = GoodsStatus#goods_status{null_cells = RemailCells},
						lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
						{ok};
					error ->
						NewGoodsStatus = GoodsStatus,
						{fail, 0};
					_Error ->
						NewGoodsStatus = GoodsStatus,
						{fail, 0}
				end
		end,
	{reply, Reply, NewGoodsStatus};
%% -----------------------------------------------------------------
%% 40053 放入氏族仓库物品
%% -----------------------------------------------------------------
handle_call({'PUT_INTO_GUILD_WAREHOUSE', GoodsId, GuildId}, _From, GoodsStatus) ->
	GoodsInfo = goods_util:get_goods(GoodsId),			
	Reply = 
		case is_record(GoodsInfo, goods) of
			true when GoodsInfo#goods.player_id =:= GoodsStatus#goods_status.player_id ->
				case GoodsInfo#goods.location =:= 4 of
					true ->%%是否在背包里
						case GoodsInfo#goods.bind =:= 0 of
							true ->%%是否绑定
								case GoodsInfo#goods.trade =/= 0 of
									true ->%%不可交易的不可放进氏族仓库
										NewGoodsStatus = GoodsStatus,
										{fail, 6};
									false ->
								case goods_util:has_attribute(GoodsInfo) of
									true -> %%是否有附加属性
										AttributeList = 
											goods_util:get_goods_attribute_list(GoodsStatus#goods_status.player_id, GoodsId);
									false ->
										AttributeList = []
								end,
								case lib_guild_warehouse:delete_goods_from_player(GoodsId, GuildId) of
									ok ->%%从背包取出操作
										NewCells = lists:sort([GoodsInfo#goods.cell | GoodsStatus#goods_status.null_cells]),
										NewGoodsStatus = GoodsStatus#goods_status{null_cells = NewCells},
										lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
										{ok, GoodsInfo, AttributeList};
									_OtherError ->
										NewGoodsStatus = GoodsStatus,
										{fail, 0}
								end
									end;
							false ->
								NewGoodsStatus = GoodsStatus,
								{fail, 5}
						end;
					false ->
						NewGoodsStatus = GoodsStatus,
						{fail, 3}
				end;
			_Error ->
				NewGoodsStatus = GoodsStatus,
				{fail, 3}
		end,
	{reply, Reply, NewGoodsStatus};

%%删除牛x的任务法宝
handle_call({'DEL_TASK_WEAPON',Career},_From,GoodsStatus) ->
	GoodsTypeId =
		case Career of
			1 -> 11014;
			2 -> 12014;
			3 -> 13014;
			4 -> 14014;
			5 -> 15014;
			_ -> fail
		end,
	case is_integer(GoodsTypeId) of
		true ->
	 		Pattern = #goods{ player_id=GoodsStatus#goods_status.player_id, goods_id=GoodsTypeId,stren = 10,grade = 50,bind = 2, _='_' },
     		GoodsList = goods_util:get_ets_list(?ETS_GOODS_ONLINE, Pattern),
			case length(GoodsList) > 0 of
				true ->
					{ok,NewStatus} = lib_goods:delete_more(GoodsStatus, GoodsList, 1),
					%%刷新背包
					lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
					{reply,ok,NewStatus};
				false ->
					{reply,fail,GoodsStatus}
			end;
		false ->
			{reply,fail,GoodsStatus}
	end;

%%赠送牛x的任务法宝
handle_call({'GIVE_TASK_WEAPON',Career}, _From, GoodsStatus) ->
	Weapon =
		case Career of
			1 -> goods_util:get_goods_type(11014);%%千锤斧
			2 -> goods_util:get_goods_type(12014);%%墨雨匕
			3 -> goods_util:get_goods_type(13014);%%堰月弓
			4 -> goods_util:get_goods_type(14014);%%天邪琴
			5 -> goods_util:get_goods_type(15014);%%虚豁剑
			_ -> fail
		end,
	NullCell = length(GoodsStatus#goods_status.null_cells),
	if
		NullCell =< 0 ->
			{reply,full,GoodsStatus};
		is_record(Weapon,ets_base_goods) ->
			Goods = goods_util:get_new_goods(Weapon),
			[Cell|NullCells] = GoodsStatus#goods_status.null_cells,
			NewGoods = Goods#goods{player_id = GoodsStatus#goods_status.player_id ,
								   cell = Cell ,
								   location = 4 ,
								   num=1,
								   sell = 1,
								   hole =3,
								   spirit = 1,
								   level = 2,
								   stren = 10,
								   grade = 50,
								   bind = 2,
								   trade = 1
								  },
			Pattern = #ets_base_goods_add_attribute{ goods_id=Weapon#ets_base_goods.goods_id,color=Weapon#ets_base_goods.color,attribute_type= 2 , _='_' },
            AttributeList = goods_util:get_ets_list(?ETS_BASE_GOODS_ADD_ATTRIBUTE, Pattern),
			F = fun(BaseAttribute) ->
						{BaseAttribute#ets_base_goods_add_attribute.attribute_id,0}
				end,
			AttList = lists:map(F, AttributeList),
			%%生成物品
			NewGoodsInfo = lib_goods:add_goods(NewGoods,AttList),
			%%镶嵌攻击宝石
			StoneTypeInfo1 = goods_util:get_goods_type(21324),
			StoneInfo1 = goods_util:get_new_goods(StoneTypeInfo1),
			lib_make:inlay_ok(NewGoodsInfo, StoneInfo1, 2, 1),
			NewGoodsInfo2 = NewGoodsInfo#goods{hole1_goods = 21324},
			%%镶嵌命中宝石
			StoneTypeInfo2 = goods_util:get_goods_type(21344),
			StoneInfo2 = goods_util:get_new_goods(StoneTypeInfo2),
			lib_make:inlay_ok(NewGoodsInfo2, StoneInfo2, 2, 1),
			NewGoodsInfo3 = NewGoodsInfo2#goods{hole2_goods = 21344},
			%%镶嵌暴击宝石
			StoneTypeInfo3 = goods_util:get_goods_type(21364),
			StoneInfo3 = goods_util:get_new_goods(StoneTypeInfo3),
			lib_make:inlay_ok(NewGoodsInfo3, StoneInfo3, 2, 1),
			NewGoodsInfo4 = NewGoodsInfo3#goods{hole3_goods = 21364},
			%%修改修炼属性
			Pattern2 = #ets_base_goods_practise{att_num = 2,subtype = NewGoodsInfo4#goods.subtype,step = NewGoodsInfo4#goods.step,color = NewGoodsInfo4#goods.color, grade =NewGoodsInfo4#goods.grade, _='_' },
            GoodsPractiseRule = goods_util:get_ets_info(?ETS_BASE_GOODS_PRACTISE, Pattern2),
			NewGoodsInfo5 = NewGoodsInfo4#goods{max_attack = GoodsPractiseRule#ets_base_goods_practise.max_attack,
												min_attack = GoodsPractiseRule#ets_base_goods_practise.min_attack,
												hit = GoodsPractiseRule#ets_base_goods_practise.hit,
												other_data  = ''},
			ets:insert(?ETS_GOODS_ONLINE,NewGoodsInfo5),
			spawn(fun()->db_agent:practise(NewGoodsInfo5)end),
			%%强化+10效果
			Att_type = goods_util:get_goods_attribute_id(NewGoodsInfo5#goods.subtype),
			Pattern3 = #ets_base_goods_strengthen{strengthen=NewGoodsInfo5#goods.stren,type=Att_type, _='_' },
            GoodsStrengthenRule = goods_util:get_ets_info(?ETS_BASE_GOODS_STRENGTHEN, Pattern3),
			spawn(fun()->lib_make:mod_strengthen_extra(NewGoodsInfo5,GoodsStrengthenRule)end),
			%%刷新背包
			lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
			NewGoodsStatus = GoodsStatus#goods_status{null_cells = NullCells},
			{reply,ok,NewGoodsStatus};
		true ->
			{reply,fail,GoodsStatus}
	end;
	
%%成就系统赠送 珠子物品
handle_call({'GIVE_ACH_TREASURE', GoodsTypeId, GoodsNum}, _From, GoodsStatus) ->
	case (catch lib_achieve_inline:give_goods(GoodsTypeId, GoodsNum, GoodsStatus#goods_status.player_id)) of
		ok ->
			{reply, ok, GoodsStatus};
		{fail, Error} ->
			{reply, Error, GoodsStatus}
	end;
%% -----------------------------------------------------------------
%% 38006 八神珠  装备和卸载
%% -----------------------------------------------------------------
handle_call({'LOAD_UNLOAD_PEARL', GoodsId, Type, Status}, _From, GoodsStatus) ->
	#player{id = PlayerId,
			other = Other} = Status,
	#player_other{ach_pearl = AchPearl} = Other,
	case lib_achieve:check_pearl(GoodsId, Type, PlayerId, AchPearl) of
		{fail, Error} ->
			{reply,{fail, {Error, GoodsId, 0}}, GoodsStatus};
		{ok, GoodsInfo} ->
			Reply =  lib_achieve:load_unload_pearl(GoodsId, Type, GoodsInfo, Status),
			{reply, Reply, GoodsStatus}
	end;
	
%%初始化获取玩家神珠的装备情况
handle_call({'GET_ACH_PEARLS_INFO'}, _From, GoodsStatus) ->
	Ms = ets:fun2ms(fun(T) when T#goods.player_id =:= GoodsStatus#goods_status.player_id 
						 andalso T#goods.location =:= 2 andalso T#goods.cell =/= 0 ->
							T end),
	Pattern = ets:select(?ETS_GOODS_ONLINE, Ms),
	Reply = lib_achieve_outline:init_ach_pearls(Pattern),
	{reply, Reply, GoodsStatus};

%%极品装备预览
handle_call({'super_view',Gid}, _From, GoodsStatus) ->
	[NewGoodsInfo,NewAttributeList] = lib_make:super_preview(Gid),
	{reply, [NewGoodsInfo,NewAttributeList], GoodsStatus};

%% 17009 求购物品请求
handle_call({'buy_goods_sendmail', GoodsId, UnPrice, PType, SellNum, SellerName}, _From, GoodsStatus) ->
	GoodsBaseInfo = goods_util:get_goods_type(GoodsId),
	{Reply, NGoodsStatus} = 
		case is_record(GoodsBaseInfo,ets_base_goods) of
			false ->
				{no_goods, GoodsStatus};
			true ->
				lib_buy:buy_goods_sendmail(GoodsBaseInfo, UnPrice, PType, SellNum, GoodsStatus, SellerName)
		end,
	{reply, Reply, NGoodsStatus};
handle_call({'buy_goods_equip_sendmail', Gid, Stren, GAttrs, GName, SellerName, NeedGoodsId, UnPrice, PType}, _From, GoodsStatus) ->
	GoodsInfo = goods_util:get_goods(Gid),
	{Reply, NGoodsStatus} = 
		if
			%%信息有误
			is_record(GoodsInfo, goods) =:= false ->
				{no_goods, GoodsStatus};
			%%不是装备
			GoodsInfo#goods.type =/= 10 ->
				{not_equip, GoodsStatus};
			%%强化等级不够
			GoodsInfo#goods.stren < Stren andalso Stren =/= 0 ->
				{no_stren, GoodsStatus};
			%%偷龙转凤？
			GoodsInfo#goods.goods_id =/= NeedGoodsId ->
				{not_equip, GoodsStatus};
			%%不可出售
			GoodsInfo#goods.bind =/= 0 orelse GoodsInfo#goods.trade =/= 0 ->
				{not_sell, GoodsStatus};
			%%不在背包里的
			GoodsInfo#goods.location =/= 4 ->
				{not_location, GoodsStatus};
			GoodsInfo#goods.player_id =/= GoodsStatus#goods_status.player_id ->
				{not_goods, GoodsStatus};
			true ->
				lib_buy:buy_goods_equip_sendmail(GoodsInfo, UnPrice, PType, GAttrs, GName, SellerName, GoodsStatus)
		end,
	{reply, Reply, NGoodsStatus};

handle_call({'WARDROBE_DRESS', Player, Type, FashionId}, _From, GoodsStatus) ->
	Reply = 
		case lib_wardrobe:check_wardrobe_dress(Player, Type, FashionId) of
			{fail, Ret} ->
				NGoodsStatus = GoodsStatus,
				{Ret, Player};
			{ok, GoodsTypeInfo, GoodsInfo} ->
				{NPlayer, NGoodsStatus} = lib_wardrobe:wardrobe_dress(Player, Type, GoodsTypeInfo, GoodsInfo, GoodsStatus),
				{1, NPlayer}
		end,
	{reply, Reply, NGoodsStatus};

handle_call(_R , _From, GoodsStatus) ->
    {reply, ok, GoodsStatus}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------

%%接收删除过期物品的消息
%%{'del_expire_goods',GoodsInfo#goods.id,GoodsInfo#goods.goods_id,GoodsInfo#goods.color,GoodsInfo#goods.expire_time}
handle_info({'del_expire_goods',PlayerId,Gid,Goods_id,Color,Expire,Type},GoodsStatus) ->
	Now = util:unixtime(),
	case goods_util:get_goods(Gid) of
		GoodsInfo  when is_record(GoodsInfo,goods) , GoodsInfo#goods.expire_time /=0  ,GoodsInfo#goods.expire_time =< Now ->
			if Type=:= 0 andalso Goods_id =:=16009 ->notice_remove_mount_uid(PlayerId,Gid,Goods_id); 
			   true->skip
			end,
			AttributeLists = goods_util:get_goods_attribute_list(PlayerId, GoodsInfo#goods.id, 1),										
			Attrs = lists:foldl(fun goods_util:get_attribute_id_value/2, [], AttributeLists),
			AtrrsStr = util:term_to_string(Attrs),
			Param = [PlayerId,"过期物品",Gid,Goods_id,Color,GoodsInfo#goods.stren,GoodsInfo#goods.bind,3,GoodsInfo#goods.num,AtrrsStr],
			spawn(fun()->log:log_throw(Param)end),
			BaseInfo = goods_util:get_goods_type(Goods_id),
			{{Year, Month, Day}, _Time1} =util:seconds_to_localtime(Expire),
			%%飞行坐骑过期不发送邮件
			if Goods_id =/=16009->
				Content = io_lib:format("您好！你的物品【~s】已于~p年~p月~p日过期，系统已自动删除！祝你游戏愉快～",[BaseInfo#ets_base_goods.goods_name,Year, Month, Day]),
				lib_mail:insert_mail(1, util:unixtime(), "系统", PlayerId, "物品到期通知", Content, 0, 0, 0, 0, 0);
			   true->skip
			end,
			%%过期的物品删除
			lib_goods:delete_goods(Gid),
			lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),%%通知刷背包
			lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 1),%%通知刷人物面部
			ok; 
		_ ->
			skip %% 玩家在物品即将过期的时候触发了取消删除的操作
	end,
	{noreply, GoodsStatus};
	
%%物品快照
handle_info('snapshot',GoodsStatus) ->
	spawn(fun()->
			Playerid = GoodsStatus#goods_status.player_id,
			Row = log:get_log_goods_list(Playerid),
			if
				Row /= [] ->
					[_,SnapshotData] = Row,
					Snapshot=util:string_to_term(tool:to_list(SnapshotData));
				true ->
					Snapshot = []
			end,
			NowGoodsList = goods_util:get_goods_list(Playerid,all),
			F = fun(Ginfo,Infolist) ->
						Pre = {Ginfo#goods.id,Ginfo#goods.goods_id,Ginfo#goods.num},
						[Pre|Infolist]
				end,
			CurList = lists:foldl(F, [], NowGoodsList),
			Time = util:unixtime(),
			CurInfo = {Time,CurList},
			%%记录3天历史记录
			case length(Snapshot) >= 3 of
				true ->
					DecSnapshot = lists:reverse(tl(lists:reverse(Snapshot))),
					NewSnapshot = [CurInfo|DecSnapshot];
				false ->
					NewSnapshot = [CurInfo|Snapshot]
			end,
			NewSnapshotData = util:term_to_string(NewSnapshot),
			log:log_goods_list([Playerid,NewSnapshotData])
	end),
	{noreply, GoodsStatus};

%%
%%物品内存数据库对比，用于检测，运营服不开启。
handle_info({'mem_diff',T},GoodsStatus) ->
	misc:cancel_timer(mem_diff_timer),
	spawn(fun()->
				  Playerid = GoodsStatus#goods_status.player_id,
				  NowGoodsList = goods_util:get_goods_list(Playerid,all),
				  NowGoodsListDb = goods_util:get_player_goods_from_db(Playerid),
				  %%检查每个物品的数量是否一致
				  lists:foreach(fun(Dbg)->
										lists:foreach(fun(Mg)->
															  if
																  Mg#goods.id == Dbg#goods.id andalso 
																							   Mg#goods.num /= Dbg#goods.num ->
																	  log:log_goods_diff([Playerid,T,Mg#goods.goods_id,Mg#goods.id,Dbg#goods.num,Mg#goods.num]);
																  true ->
																	  skip
															  end
													  end
															  ,
													   NowGoodsListDb)
								end,
								NowGoodsList),
				  %%获取id列表
				  F_getid = fun(GList) ->
									lists:map(fun(Ginfo) ->Ginfo#goods.id end, GList)
							end,
				  %%根据id获取物品信息
				  F_getinfo = fun(Id,GList) ->
									  lists:foldl(fun(Ginfo,Get)-> 
														if Ginfo#goods.id == Id ->
															   [Ginfo|Get];
														   true ->
															   Get
														end
												end,[], GList)
							  end,
				  %%检查物品个数是否一致
				  Len1 = length(NowGoodsList),
				  Len2 = length(NowGoodsListDb),
				  if
					  Len1 > Len2 ->
						  MoreList = F_getid(NowGoodsList),
						  LessList = F_getid(NowGoodsListDb);
					  Len1 < Len2 ->
						  MoreList = F_getid(NowGoodsListDb),
						  LessList = F_getid(NowGoodsList);
					  true ->
						  MoreList = [],
						  LessList = []				  
				  end,
				  lists:foreach(fun(Id)->
									case lists:member(Id, LessList) of
										true ->
											skip;
										false ->
											ErrGoodList = F_getinfo(Id,NowGoodsList),
											if
												ErrGoodList /= [] ->
													ErrGood = hd(ErrGoodList),
													log:log_goods_diff([Playerid,T,ErrGood#goods.goods_id,ErrGood#goods.id,0,ErrGood#goods.num]);
												true ->
													skip
											end
									end
								end,
							MoreList
					)
				  
		  end),
	erlang:send_after(1000 * 10 , self(),{'mem_diff',1}),
	{noreply,GoodsStatus};

handle_info(_Reason, GoodsStatus) ->
    {noreply, GoodsStatus}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _GoodsStatus) ->
	%%取消timer
	misc:cancel_timer(mem_diff_timer),
	misc:delete_monitor_pid(self()),
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, GoodsStatus, _Extra)->
    {ok, GoodsStatus}.

%%=========================================================================
%% 业务处理函数
%%=========================================================================
check_pay(PlayerStatus, GoodsStatus, GoodsTypeId, GoodsNum, ShopType ,ShopSubtype) ->
    ShopInfo = goods_util:get_shop_info(ShopType, GoodsTypeId),
    _GoodsTypeInfo = goods_util:get_goods_type(GoodsTypeId),
    case is_record(_GoodsTypeInfo, ets_base_goods) andalso is_record(ShopInfo, ets_shop) andalso GoodsNum > 0 of
        %% 物品不存在
        false -> 
			{fail, 2};
        true ->
			%%开服特惠商品
			Is_opening_th_goods = mod_shop:is_opening_th_goods(GoodsTypeId),
			if
				%%特惠区开服物品不绑定
				ShopType == 1 andalso ShopSubtype == 6 andalso Is_opening_th_goods ->
					_GoodsTypeInfo2 = _GoodsTypeInfo;
				%%特惠区和礼券区、积分商店出售的物品绑定
				ShopType =:= 1 andalso (ShopSubtype =:= 5 orelse ShopSubtype =:= 6 orelse ShopSubtype =:= 7) ->
					_GoodsTypeInfo2 = _GoodsTypeInfo#ets_base_goods{bind = 2};
				%%某些商店类型绑定
				ShopType == 10219 orelse ShopType == 10222 orelse ShopType == 20207 orelse ShopType == 20800 orelse ShopType == 21020 orelse ShopType ==20912 ->
					_GoodsTypeInfo2 = _GoodsTypeInfo#ets_base_goods{bind = 2};
				true ->
					_GoodsTypeInfo2 = _GoodsTypeInfo
			end,
			%% 购买有过期时间的物品，暂时只有中秋月兔
			case lists:member(_GoodsTypeInfo2#ets_base_goods.goods_id ,[16008]) of
				true ->
					Now = util:unixtime(),
					Expire = Now + 3600 * 24 * 10,
					GoodsTypeInfo = _GoodsTypeInfo2#ets_base_goods{expire_time = Expire};
				false ->
					GoodsTypeInfo = _GoodsTypeInfo2
			end,
			case lib_goods:is_enough_backpack_cell(GoodsStatus, GoodsTypeInfo, GoodsNum) of
                %%背包格子不足
                no_enough -> 
					{fail, 4};
                {enough, GoodsList, CellNum} ->
					BagNullCells = 
						lists:sublist(GoodsStatus#goods_status.null_cells, CellNum+1, (length(GoodsStatus#goods_status.null_cells)-CellNum)),
					AllowCoinNpc = [10102,10105,10107,10109,10119,10202,10203,10206,10213,10306,
									10307,20110,20117,20120,20121,20223,20226,20245,20251,20308,21001],
					IsCoinNpc = lists:member(ShopType, AllowCoinNpc),
					Is_Fst_Shop = mod_fst:is_fst_shop(ShopType),
					if 
						%%注意优先匹配
						%% 商城特惠区6和礼券商店5	
						ShopType =:= 1 andalso (ShopSubtype =:= 5 orelse ShopSubtype =:= 6 ) ->							
							DataList = goods_util:parse_goods_other_data(GoodsTypeInfo#ets_base_goods.other_data),
							if
								length(DataList) > 0 ->
									[_ps,_goodtypeinfo,_gn,_st,_sut,Cost,PriceType] = lists:foldl(fun goods_util:parse_goods_price_for_shoptype/2, [PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,0,0], DataList),
									case goods_util:is_enough_money(PlayerStatus, Cost, PriceType) of
                        				false when Cost =:= 99 andalso PriceType =:= 99-> {fail, 5};%%当天已购买
										false ->
											{fail,3};%% 金额不足
                        				true -> 
											{ok, GoodsTypeInfo, GoodsList, Cost, PriceType, 0, GoodsStatus}
                    				end;
								true ->
									{fail,2}
							end;
						%% 商城积分 ，暂时注释掉，勿删
%% 						ShopType =:= 1 andalso ShopSubtype =:= 7 ->
%% 							DataList = goods_util:parse_goods_other_data(GoodsTypeInfo#ets_base_goods.other_data),
%% 							if length(DataList) > 0 ->
%% 								   [_ps,_goodtypeinfo,_gn,_st,_sut,Cost,_PriceType] = lists:foldl(fun goods_util:parse_goods_price_for_shoptype/2, [PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,0,0], DataList),
%% 								   case goods_util:is_enough_shop_score(PlayerStatus,Cost) of
%% 									   false ->
%% 										   	{fail,8};%%积分不足
%% 									   true ->
%% 											{ok,GoodsTypeInfo,GoodsList,Cost,shop_score,0, GoodsStatus}
%% 								   end;
%% 							   true ->
%% 								   {fail,2}
%% 							end;
						ShopType =:= 1 andalso ShopSubtype =:= 7 ->
							{fail,2};
						%%时装商店(个性装扮，加入了坐骑) npc (织女 20901)个性热卖
						ShopType == 20901 orelse (ShopType =:= 1 andalso ShopSubtype =:= 9)->
							DataList = goods_util:parse_goods_other_data(GoodsTypeInfo#ets_base_goods.other_data),
							GoodsId = GoodsTypeInfo#ets_base_goods.goods_id,		
							if
								length(DataList) > 0 andalso (GoodsId > 10900 andalso GoodsId < 10921) 
								  andalso GoodsTypeInfo#ets_base_goods.price_type =:= 3 ->
									[_ps,Goodtypeinfo,_gn,_st,_sut,TCSCost,_Type] = 
										lists:foldl(fun goods_util:parse_goods_price_for_shoptype/2, 
													[PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,0,0], DataList),
									Gold = PlayerStatus#player.gold,
									GoodsPrice = Goodtypeinfo#ets_base_goods.price,														
									%%时装用天蚕丝购买
									case goods_util:is_enough_tcsgold_fashion(Gold,TCSCost,GoodsPrice,28404,GoodsStatus,_Type) of%%扣天蚕丝28404
										{1, NewGoodsStatus} ->
											{ok,GoodsTypeInfo,GoodsList,GoodsPrice,gold,0,NewGoodsStatus};
										2 ->%%元宝不足
											{fail, 3};
										3 ->%%天蚕丝不足
											{fail, 11};
										4 ->
											{fail, 0}
									end;
								true ->
									{ok, GoodsTypeInfo, GoodsList, GoodsTypeInfo#ets_base_goods.price, gold, 0, GoodsStatus}
							end;
						%% 商城
						ShopType == 1 ->
							Cost = GoodsTypeInfo#ets_base_goods.price * GoodsNum ,
							PriceType = goods_util:get_price_type(GoodsTypeInfo#ets_base_goods.price_type),
							OnlyOneTime = lists:member(GoodsTypeInfo#ets_base_goods.goods_id, [28118]),
							%% BuyTimes 购买次数限制 0不限
							if
								OnlyOneTime ->
									LogShop = log:get_shop_log(PlayerStatus#player.id,GoodsTypeInfo#ets_base_goods.goods_id,ShopType,ShopSubtype),
									BuyTimes = length(LogShop);
								true ->
									BuyTimes =0
							end,
							case goods_util:is_enough_money(PlayerStatus, Cost, PriceType) of
                        		%% 金额不足
                        		false -> 
									{fail, 3};
								%% 封神礼包只可以买一个
								true when GoodsTypeInfo#ets_base_goods.goods_id == 28118 andalso GoodsNum > 1 ->
									{fail,7};
								true when OnlyOneTime andalso BuyTimes > 0 ->
									{fail, 6};
                        		true -> 
									{ok, GoodsTypeInfo, GoodsList, Cost, PriceType, BagNullCells, GoodsStatus}
                    		end;
						%% 农场商店
						ShopType == 2 ->
							Is_vip = lib_vip:check_vip(PlayerStatus),
							if
								Is_vip == true -> 
									Cost = round(GoodsTypeInfo#ets_base_goods.price * 0.8) * GoodsNum;
								true ->
									Cost = GoodsTypeInfo#ets_base_goods.price * GoodsNum
							end,
							PriceType =
								case goods_util:get_price_type(GoodsTypeInfo#ets_base_goods.price_type) of
									coin ->coinonly;
									PT->PT
								end,
							case goods_util:is_enough_money(PlayerStatus, Cost, PriceType) of
                        		%% 金额不足
                        		false -> 
									{fail, 3};
                        		true -> 
									{ok, GoodsTypeInfo, GoodsList, Cost, PriceType, BagNullCells, GoodsStatus}
                    		end;
							
						%%战场使者
						ShopType == 10219  ->
							DataList = goods_util:parse_goods_other_data(GoodsTypeInfo#ets_base_goods.other_data),
							if
								length(DataList) > 0 ->
									[_ps,_goodtypeinfo,_gn,_st,_sut,Cost,PriceType] = lists:foldl(fun goods_util:parse_goods_price_for_shoptype/2, [PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,0,0], DataList),
									case goods_util:is_enough_score(PlayerStatus,Cost,PriceType) of
										false ->
											{fail,8};%%积分不足
										true ->
											{ok,GoodsTypeInfo,GoodsList,Cost,PriceType,0, GoodsStatus}
									end;
								true ->
									{fail,2}
							end;
						%%封神台荣誉商店(
						ShopType == 10222 ->
							DataList = goods_util:parse_goods_other_data(GoodsTypeInfo#ets_base_goods.other_data),
							if
								length(DataList) > 0 ->
									[_ps,_goodtypeinfo,_gn,_st,_sut,NeedHonor,_Type] = lists:foldl(fun goods_util:parse_goods_price_for_shoptype/2, [PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,0,0], DataList),
									case goods_util:is_enough_honor(PlayerStatus,NeedHonor,_Type) of
										false ->
											{fail,9};%%荣誉不足
										true ->
											Cost = GoodsTypeInfo#ets_base_goods.price * GoodsNum,
											PriceType = goods_util:get_price_type(GoodsTypeInfo#ets_base_goods.price_type),
											case goods_util:is_enough_money(PlayerStatus, Cost, PriceType) of
												true ->
													{ok,GoodsTypeInfo,GoodsList,Cost,PriceType,0, GoodsStatus};
												false ->
													{fail,3}
											end
									end;
								true ->
									{fail,2}
							end;
						%%诛仙台荣誉商店
						ShopType == 20912 ->
							DataList = goods_util:parse_goods_other_data(GoodsTypeInfo#ets_base_goods.other_data),
							if
								length(DataList) > 0 ->
									[_ps,_goodtypeinfo,_gn,_st,_sut,NeedHonor,_Type] = lists:foldl(fun goods_util:parse_goods_price_for_shoptype/2, [PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,0,0], DataList),
									case lib_scene_fst:is_enough_zxt_honor(PlayerStatus,NeedHonor) of
										false ->
											{fail,13};%%荣誉不足
										true ->
											Cost = GoodsTypeInfo#ets_base_goods.price * GoodsNum,
											PriceType = goods_util:get_price_type(GoodsTypeInfo#ets_base_goods.price_type),
											case goods_util:is_enough_money(PlayerStatus, Cost, PriceType) of
												true ->
													{ok,GoodsTypeInfo,GoodsList,Cost,PriceType,0, GoodsStatus};
												false ->
													{fail,3}
											end
									end;
								true ->
									{fail,2}
							end;
						%%功勋商店
						ShopType == 20207 orelse ShopType == 21020 ->
							DataList = goods_util:parse_goods_other_data(GoodsTypeInfo#ets_base_goods.other_data),
							if
								length(DataList) > 0 ->
									[_ps,_goodtypeinfo,_gn,_st,_sut,Cost,_Type] = lists:foldl(fun goods_util:parse_goods_price_for_shoptype/2, [PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,0,0], DataList),
									case goods_util:is_enough_feats(PlayerStatus,Cost,_Type) of
										false ->
											{fail,10};%%功勋不足
										true ->
											{ok,GoodsTypeInfo,GoodsList,Cost,feats,0, GoodsStatus}	
									end;
								true ->
									{fail,2}
							end;
						%%镇妖功勋商店
						ShopType == 20800 andalso ShopSubtype =:= 1 ->
							DataList = goods_util:parse_goods_other_data(GoodsTypeInfo#ets_base_goods.other_data),
							if
								length(DataList) > 0 ->
									[_ps,_goodtypeinfo,_gn,_st,_sut,Cost,_Type] = lists:foldl(fun goods_util:parse_goods_price_for_shoptype/2, [PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,0,0], DataList),
									PHorTd = lib_td:get_hor_td(PlayerStatus#player.id),
									case goods_util:is_enough_hor_td(PHorTd,Cost,_Type) of
										false ->
											{fail,10};%%镇妖功勋不足
										true ->
											{ok,GoodsTypeInfo,GoodsList,Cost,hor_td,0, GoodsStatus}	
									end;
								true ->
									{fail,2}
							end;
						ShopType =:= 20802 ->%%活动面板上的购买，统一走这类型
							case ShopSubtype of
								1 ->
									CheckTime = util:unixtime(),
									%%周年活动的开始和结束时间
									{TGStart, TGEnd} = lib_activities:anniversary_time(),
									case CheckTime > TGStart andalso CheckTime < TGEnd of
										true ->
											DataList = goods_util:parse_goods_other_data(GoodsTypeInfo#ets_base_goods.other_data),
											if
												length(DataList) > 0 ->
													[_ps,_goodtypeinfo,_gn,_st,_sut,Cost,PriceType] =
														lists:foldl(fun goods_util:parse_goods_price_for_shoptype/2, 
																	[PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,0,0], DataList),
													case goods_util:is_enough_money(PlayerStatus, Cost, PriceType) of
														%% 金额不足
														false -> 
															{fail, 3};
														true -> 
															{ok, GoodsTypeInfo, GoodsList, Cost, PriceType, BagNullCells, GoodsStatus}
													end;
												true ->
													{fail,2}
											end;
										false ->
											{fail, 14}
									end;
								_->
									skip
							end;
						%%神秘商店
						Is_Fst_Shop ->
							DataList = goods_util:parse_goods_other_data(GoodsTypeInfo#ets_base_goods.other_data),
									if
										length(DataList) > 0 ->
											[_ps,_goodtypeinfo,_gn,_st,_sut,Cost,_LimitBuy] = lists:foldl(fun goods_util:parse_goods_price_for_shoptype/2,
																										   [PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,0,0], DataList),
											case goods_util:is_enough_money(PlayerStatus,Cost,gold) of
												false ->
													{fail,3};%%金额不足
												true ->
%% 													case GoodsNum > LimitBuy  这里要去封神台进程取剩余个数了，暂时不理
													[IsFstAlive, Pid_fst_next] = 
														case lists:keysearch((PlayerStatus#player.scene)rem 10000, 1, PlayerStatus#player.other#player_other.pid_fst) of
															{value,{_SceneId, Fst_pid}} ->
																[misc:is_process_alive(Fst_pid), Fst_pid];
															_ ->
																{false,16} %%这个错误码需添加,
														end,
													case IsFstAlive of
														false ->
															{fail,16};%%副本已消失
														true ->
															case catch gen_server:call(Pid_fst_next, {buy_from_fst_shop,PlayerStatus,GoodsTypeId,GoodsNum,ShopType,ShopSubtype}) of
																{'EXIT',_Info} ->
																	{fail,16}; %%这个错误码需添加
																{fail,Code} ->
																	{fail,Code};
																{ok,_} ->
																	{ok,GoodsTypeInfo,GoodsList,Cost,gold,0,GoodsStatus}
															end
													end
											end;
										true ->
											{fail,2}
									end;
						%%普通铜币npc购买
						IsCoinNpc ->						
							Cost = GoodsTypeInfo#ets_base_goods.price * GoodsNum ,
							%%普通npc 子 类型1是铜币，2是绑定铜
							PriceType = 
								case ShopSubtype of
										1 ->
											coinonly;
										2 ->
											bcoin;
										_ ->
											goods_util:get_price_type(GoodsTypeInfo#ets_base_goods.price_type)
								end,
                    		case goods_util:is_enough_money(PlayerStatus, Cost, PriceType) of
                        		%% 金额不足
                        		false -> 
									{fail, 3};
                        		true -> 
									{ok, GoodsTypeInfo, GoodsList, Cost, PriceType, BagNullCells, GoodsStatus}
							end;
						%%非指定npc直接过滤
						true ->
							{fail,0}
					end
			end
	end.

multi_check_pay(fail, Type, _PlayerStatus, _GoodsStatus, _GoodsList, _ShopType, _ShopSubType, _GoodsTypeInfoList) ->
	{fail, Type};
multi_check_pay(ok, _Type, _PlayerStatus, _GoodsStatus, [], _ShopType, _ShopSubType, GoodsTypeInfoList) ->
	{ok, GoodsTypeInfoList};
multi_check_pay(ok, _Type, PlayerStatus, GoodsStatus, [{GoodsTypeId, GoodsNum}|GoodsList], ShopType, ShopSubType, GoodsTypeInfoList) ->
	case check_pay(PlayerStatus, GoodsStatus, GoodsTypeId, GoodsNum, ShopType, ShopSubType) of
		{fail, FailType} ->
			multi_check_pay(fail, FailType, PlayerStatus, GoodsStatus, GoodsList, ShopType, ShopSubType, GoodsTypeInfoList);
		{ok, GoodsTypeInfo, _GetGoodsList, Cost, _PriceType, BagNullCells, _OldGoodsStatus} ->
			NewGoodsStatus = GoodsStatus#goods_status{null_cells = BagNullCells},
			case ShopSubType of
				1 ->
					NewGoodsTypeInfo = {GoodsNum, Cost, GoodsTypeInfo},
					NewGoodsTypeInfoList = [NewGoodsTypeInfo|GoodsTypeInfoList],
					NewPlayerStatus = PlayerStatus#player{coin = PlayerStatus#player.coin - Cost},
					multi_check_pay(ok, 1, NewPlayerStatus, NewGoodsStatus, GoodsList, ShopType, ShopSubType, NewGoodsTypeInfoList);
				2 ->
					GoodsTypeInfoBind = GoodsTypeInfo#ets_base_goods{bind = 2},
					NewGoodsTypeInfo = {GoodsNum, Cost, GoodsTypeInfoBind},
					NewGoodsTypeInfoList = [NewGoodsTypeInfo|GoodsTypeInfoList],
					NewPlayerStatus = PlayerStatus#player{bcoin = PlayerStatus#player.bcoin - Cost},
					multi_check_pay(ok, 1, NewPlayerStatus, NewGoodsStatus, GoodsList, ShopType, ShopSubType, NewGoodsTypeInfoList)
			end
	end.

multi_pay_goods(PriceType, PlayerStatus, GoodsStatus, GoodsTypeInfos) ->
	?DB_MODULE:transaction(
	  fun() ->
			  lists:foldl(
				fun(GoodsTypeInfoPay, AccIn) ->
						{GoodsNum, Cost, GoodsTypeInfoPayRest} = GoodsTypeInfoPay,
						{PayPlayerStatus, PayResult, PayGoodsStatus} = AccIn,
						case PayResult of
							0 ->
								{PlayerStatus, 0, GoodsStatus};
							1 ->
								case (catch lib_goods:multi_pay_goods(PayGoodsStatus, 
																	  GoodsTypeInfoPayRest,
																	  GoodsNum)) of
									{ok, NewPayGoodsStatus} ->
										NewPayPlayerStatus = lib_goods:cost_money(PayPlayerStatus, Cost, PriceType, 1571),
										lib_task:event(buy_equip,
													   {GoodsTypeInfoPayRest#ets_base_goods.goods_id},
													   PayPlayerStatus),
										{NewPayPlayerStatus, 1, NewPayGoodsStatus};
									Error ->
										?ERROR_MSG("mod_goods pay:~p", [Error]),
										{PlayerStatus, 0, GoodsStatus}
								end
						end
				end,
				{PlayerStatus, 1, GoodsStatus},
				GoodsTypeInfos)
	  end).

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
		GoodsNum < 0 ->
			{fail, 6};
        %% 物品数量不足
        GoodsInfo#goods.num < GoodsNum ->
            {fail, 6};
		GoodsInfo#goods.spirit > 0 ->%%灵力不为0
			{fail, 7};
        true ->
            {ok, GoodsInfo}
    end.

multi_check_sell(GoodsList,GoodsStatus) ->
	multi_check_sell_each(1, [], GoodsList,GoodsStatus).

multi_check_sell_each(0, _ReturnGoodsList, _GoodsList, _GoodsStatus) ->
	{0, []};
multi_check_sell_each(1, ReturnGoodsList, [], _GoodsStatus) ->
	{1, ReturnGoodsList};
multi_check_sell_each(1, ReturnGoodsList, [{GoodsId, GoodsNum}|GoodsList], GoodsStatus) ->
	case check_sell(GoodsStatus, GoodsId, GoodsNum) of
		{fail, _Res} ->
			multi_check_sell_each(0, ReturnGoodsList, GoodsList, GoodsStatus);
		{ok, GoodsInfo} ->
			multi_check_sell_each(1, [{GoodsNum, GoodsInfo}|ReturnGoodsList],GoodsList, GoodsStatus)
	end.
mutli_sell_goods(PlayerStatus, GoodsStatus, GoodsInfoList) ->
	lists:foldl(
				fun(GoodsInfoParam, AccIn) ->
						{GoodsNum, GoodsInfo} = GoodsInfoParam,
						{ResultElem, SellPlayerStatus, SellGoodsStatus} = AccIn,
						case ResultElem of
							0 ->
								{ResultElem, PlayerStatus, GoodsStatus};
							1 ->
								AttributeLists = goods_util:get_goods_attribute_list(PlayerStatus#player.id, GoodsInfo#goods.id, 1),
								case (catch lib_goods:sell_goods(SellPlayerStatus, SellGoodsStatus, GoodsInfo, GoodsNum, 1)) of
									{ok, SellNewPlayerStatus, SellNewStatus} ->
										%%如果是金紫物品添加日志记录
										
										Attrs = lists:foldl(fun goods_util:get_attribute_id_value/2, [], AttributeLists),
										AtrrsStr = util:term_to_string(Attrs),
										spawn(fun()->log:log_throw([PlayerStatus#player.id,PlayerStatus#player.nickname,GoodsInfo#goods.id,GoodsInfo#goods.goods_id,
																	GoodsInfo#goods.color,GoodsInfo#goods.stren,GoodsInfo#goods.bind,2,GoodsInfo#goods.num,AtrrsStr])end),
										{1, SellNewPlayerStatus, SellNewStatus};
									Error ->
										?ERROR_MSG("mod_goods sell:~p", [Error]),
										{0, PlayerStatus, GoodsStatus}
								end
						end
				end, 
				{1, PlayerStatus, GoodsStatus}, GoodsInfoList).
%% 	  end).

check_equip(PlayerStatus, GoodsId, Cell) ->
    Location = PlayerStatus#player.equip,
    GoodsInfo = goods_util:get_goods(GoodsId),
	Now = util:unixtime(),
    if
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= PlayerStatus#player.id ->
            {fail, 3};
        %% 物品位置不正确
        GoodsInfo#goods.location =/= 4 ->
            {fail, 4};
        %% 物品位置不正确
        Location =/= 1  ->
            {fail, 4};
        %% 物品类型不可装备
        GoodsInfo#goods.type =/= 10 ->
            {fail, 5};
		%% 坐骑不可装备
		GoodsInfo#goods.type =:= 10 andalso GoodsInfo#goods.subtype =:= 22 ->
			{fail,5};
		%% 物品已过期
		GoodsInfo#goods.expire_time /= 0 andalso GoodsInfo#goods.expire_time < Now ->
			{fail,10};
        true ->
			if GoodsInfo#goods.grade == 50 andalso GoodsInfo#goods.spirit == 1  -> SkipCheck = true;
			   true -> SkipCheck = false
			end,
            case goods_util:can_equip(PlayerStatus, GoodsInfo#goods.goods_id, Cell ,SkipCheck) of
                %% 玩家条件不符
                {false,E} ->
                    {fail, E};
                NewCell ->
					%%NewCell 装备的位置
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
        GoodsInfo#goods.location =/= 1 ->
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

check_throw(PlayerStatus,GoodsStatus, GoodsId, GoodsNum) ->
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
		%% 新手期不能丢弃法宝
		PlayerStatus#player.realm =:= 100 ->
			{fail,5};
		%% 物品不可丢弃
		PlayerStatus#player.mount =:= GoodsId ->
			{fail,5};
		%% 物品数量不正确
        GoodsInfo#goods.num < GoodsNum ->
            {fail, 6};
		GoodsNum < 0 ->
			{fail,6};
		%% 这个是任务给出的武器
		GoodsInfo#goods.grade == 50 andalso GoodsInfo#goods.spirit == 1  ->
			{fail,3};
		%% 物品有灵力不能丢弃
		%%GoodsInfo#goods.spirit > 0 ->
			%%{fail,7};
		%%主线任务的物品不能丢弃（化身体验符）
		GoodsInfo#goods.goods_id =:= 28045->
			{fail,5};
		%%婚戒不能丢弃
		GoodsInfo#goods.type == 10 andalso GoodsInfo#goods.subtype == 25 ->
			{fail,5};
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
		GoodsNum =< 0 ->
			{fail,5};
		%% 这个是任务给出的武器
		GoodsInfo#goods.grade == 50 andalso GoodsInfo#goods.spirit == 1 ->
			{fail,3};
        true ->
            GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
            if
                %% 物品类型不存在
                is_record(GoodsTypeInfo, ets_base_goods) =:= false ->
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
		GoodsNum =< 0 ->
			{fail,5};
        true ->
            GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
            if
                %% 物品类型不存在
                is_record(GoodsTypeInfo, ets_base_goods) =:= false ->
                    {fail, 2};
				 %% 背包已满
                length(GoodsStatus#goods_status.null_cells) =< 0 ->
                   {fail, 6};
                true ->
                    {ok, GoodsInfo, GoodsTypeInfo}
            end
    end.



check_moveout_orebag(GoodsStatus,GoodsId,GoodsNum) ->
	GoodsInfo = goods_util:get_goods_by_id(GoodsId),
    if
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= GoodsStatus#goods_status.player_id ->
            {fail, 3};
        %% 物品不在仓库
        GoodsInfo#goods.location =/= 9 ->
            {fail, 4};
        %% 物品数量不正确
        GoodsInfo#goods.num < GoodsNum ->
            {fail, 5};
		GoodsNum =< 0 ->
			{fail,5};
        true ->
            GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
            if
                %% 物品类型不存在
                is_record(GoodsTypeInfo, ets_base_goods) =:= false ->
                    {fail, 2};
                %% 背包已满
                length(GoodsStatus#goods_status.null_cells) =< 0 ->
                    {fail, 6};
                true ->
                    {ok, GoodsInfo, GoodsTypeInfo}
            end
    end.

check_moveout_plantbag(GoodsStatus,GoodsInfoList) ->
	Len = length(GoodsInfoList),
    if
        %% 物品不存在
        length(GoodsStatus#goods_status.null_cells) < Len ->
		  	{fail,6};
		true->
			{ok}
    end.


check_extend(PlayerStatus, Loc) ->
	case Loc of
		1 -> check_extend_bag(PlayerStatus);
		_ -> check_extend_store(PlayerStatus)
	end.
	
check_extend_store(PlayerStatus) ->
	if
		PlayerStatus#player.store_num =:= 36 ->
    		Cost = 80;
		true ->
			Cost = 120
	end,
    MaxCell = 36 * 3,
    if
        %% 仓库已达上限
        PlayerStatus#player.store_num >= MaxCell ->
            {fail,PlayerStatus, 3};
        true ->
            case goods_util:is_enough_money(PlayerStatus, Cost, gold) of
                %% 玩家金额不足
                false -> {fail,PlayerStatus, 2};
                true ->{ok, PlayerStatus,Cost}
            end
    end.

check_extend_bag(PlayerStatus) ->
	if
		PlayerStatus#player.cell_num =:= 36 ->
    		Cost = 100;
		PlayerStatus#player.cell_num =:= 72 ->
			Cost = 200;
		true ->
			Cost = 300
	end,
	{NewPlayerStatus,_,Award} = lib_vip:get_vip_award(bag,PlayerStatus),
	if PlayerStatus#player.cell_num =:= 108 andalso Award =:= false->
		   {fail,PlayerStatus,4};
	   true->
			case Award of
				false->
					MaxCell = 36 * 3,
					if
    				    %% 背包已达上限
   			 		    PlayerStatus#player.cell_num >= MaxCell ->
   			 		        {fail, NewPlayerStatus,3};
		     		   true ->
       				     case goods_util:is_enough_money(PlayerStatus, Cost, gold) of
        				        %% 玩家金额不足
		         		       false -> {fail, NewPlayerStatus,2};
        		   		     true ->{ok,NewPlayerStatus, Cost}
          				  end
		  		   end;
				true->
					VipMaxCell = 36 *4 ,
					if
    		    		%% 背包已达上限
		    		    PlayerStatus#player.cell_num >= VipMaxCell ->
 		   		        {fail,NewPlayerStatus, 3};
  			   		   true ->
   		    		     case goods_util:is_enough_money(PlayerStatus, Cost, gold) of
    		    		        %% 玩家金额不足
    		     		       false -> {fail,NewPlayerStatus, 2};
     		      		     true ->{ok,NewPlayerStatus, Cost}
     		     		  end
  				   end
			end
	end.
			
		

check_destruct(GoodsStatus,GoodsId,_Num,_Pos) ->
	GoodsInfo = goods_util:get_goods(GoodsId),
	Num = abs(_Num),
	if
		is_record(GoodsInfo,goods) =:= false ->
			{fail,2};
		GoodsInfo#goods.player_id =/= GoodsStatus#goods_status.player_id ->
			{fail,3};
		GoodsInfo#goods.location =/= 4 ->
			{fail,4};
		GoodsInfo#goods.num =< 1 ->
			{fail,5};
		GoodsInfo#goods.num =< Num ->
			{fail,6};
		length(GoodsStatus#goods_status.null_cells) < 1 ->
			{fail,7};
		Num < 0 ->
			{fail,0};
		true ->
			{ok,GoodsInfo}
	end.

check_mend(PlayerStatus, GoodsId) ->
    GoodsInfo = goods_util:get_goods(GoodsId),
    if  %% 物品不存在
        is_record(GoodsInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= PlayerStatus#player.id ->
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

check_suit_merge(PlayerStatus,Gid1,Gid2,Gid3,Type) ->
	GoodsInfo1 = goods_util:get_goods(Gid1),
	GoodsInfo2 = goods_util:get_goods(Gid2),
	GoodsInfo3 = goods_util:get_goods(Gid3),
	if
		is_record(GoodsInfo1,goods) == false orelse is_record(GoodsInfo2,goods) == false orelse is_record(GoodsInfo3,goods) == false ->
			{fail,2};
		Gid1 == Gid2 ->
			{fail,2};
		GoodsInfo1#goods.num < 1 orelse GoodsInfo2#goods.num < 1 orelse GoodsInfo3#goods.num < 1 ->
			{fail,2};
		GoodsInfo1#goods.player_id /= PlayerStatus#player.id orelse GoodsInfo2#goods.player_id /= PlayerStatus#player.id orelse GoodsInfo3#goods.player_id /= PlayerStatus#player.id ->
			{fail,3};
		GoodsInfo1#goods.location /= 4 orelse GoodsInfo2#goods.location /= 4 orelse GoodsInfo3#goods.location /= 4 ->
			{fail,4};
		GoodsInfo1#goods.color /= 4 orelse GoodsInfo2#goods.color /= 4 orelse GoodsInfo3#goods.color /= 3 ->
			{fail,5};%%紫+紫+金
		GoodsInfo1#goods.suit_id /= GoodsInfo2#goods.suit_id ->
			{fail,5};%%同套装
		GoodsInfo1#goods.career /= GoodsInfo2#goods.career orelse GoodsInfo1#goods.career /= GoodsInfo3#goods.career orelse GoodsInfo2#goods.career /= GoodsInfo3#goods.career ->
			{fail,5};%%同职业
		true ->
			Step = goods_util:level_to_step(GoodsInfo1#goods.level),
			Step_3 = goods_util:level_to_step(GoodsInfo3#goods.level),
			Cost =
				case Step of
					4 -> 50000;
					5 -> 70000;
					6 -> 90000;
					7 -> 110000;
					8 -> 130000;
					9 -> 150000;
					10 -> 170000;
					_ -> 1000000
				end,		
			Enough = goods_util:is_enough_money(PlayerStatus, Cost, coin),
			if
				Step /= Step_3 ->
					{fail,5};%%同等级
				Enough == false andalso Type /= preview  ->
					{fail,7};
				true ->
					{ok,GoodsInfo1,GoodsInfo2,GoodsInfo3,Cost}
			end
	end.
		
%%强化条件检查
%%GoodsId 物品 StoneId 强化石 RuneId 幸运石
check_strengthen(PlayerStatus, GoodsId, StoneId, RuneId1,_N1,RuneId2,_N2,RuneId3,_N3,RuneId4,_N4,Protect,StoneTypeId,Auto_purch) ->
	N1 = abs(_N1),
	N2 = abs(_N2),
	N3 = abs(_N3),
	N4 = abs(_N4),
	GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, StoneTypeId),
    GoodsInfo = goods_util:get_goods(GoodsId),
    StoneInfo = goods_util:get_goods(StoneId),
    case RuneId1 > 0 of
        true -> RuneInfo1 = goods_util:get_goods(RuneId1);
        false -> RuneInfo1 = #goods{ num = 0, player_id = PlayerStatus#player.id,id=0, goods_id = 0, location = 4, type = 15, subtype = 11 }
    end,
     case RuneId2 > 0 of
        true -> RuneInfo2 = goods_util:get_goods(RuneId2);
        false -> RuneInfo2 = #goods{ num = 0, player_id = PlayerStatus#player.id,id=0, goods_id = 0, location = 4, type = 15, subtype = 11 }
    end,
     case RuneId3 > 0 of
        true -> RuneInfo3 = goods_util:get_goods(RuneId3);
        false -> RuneInfo3 = #goods{ num = 0, player_id = PlayerStatus#player.id,id=0, goods_id = 0, location = 4, type = 15, subtype = 11 }
    end,
     case RuneId4 > 0 of
        true -> RuneInfo4 = goods_util:get_goods(RuneId4);
        false -> RuneInfo4 = #goods{ num = 0, player_id = PlayerStatus#player.id,id=0, goods_id = 0, location = 4, type = 15, subtype = 11 }
    end,
	case Protect > 0 of
		true -> Proinfo = goods_util:get_goods(Protect);
		false -> Proinfo = #goods{ num = 0, player_id = PlayerStatus#player.id,id=0, goods_id = 0, location = 4, type = 15, subtype = 11 }
	end,
	CanStrenNormal = [20300,20303,20304,20305,20306],
	CanStren7 = [20300,20301,20303,20304,20305,20306],
	CanStren8 = [20300,20302,20303,20304,20305,20306],
	CanStren9 = [20300,20303,20304,20305,20306,20315],
	CanStren10 = [20300,20303,20304,20305,20306],
	
    if
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false orelse (Auto_purch == 0 andalso is_record(StoneInfo, goods) =:= false) ->
            {fail, 2};
        %% 物品不存在
        RuneId1 > 0 andalso (is_record(RuneInfo1,goods) == false orelse RuneInfo1#goods.num == 0) ->
            {fail, 2};
        RuneId2 > 0 andalso (is_record(RuneInfo2,goods) == false orelse RuneInfo2#goods.num == 0) ->
            {fail, 2};
        RuneId3 > 0 andalso (is_record(RuneInfo3,goods) == false orelse RuneInfo3#goods.num == 0)->
            {fail, 2};
        RuneId4 > 0 andalso (is_record(RuneInfo4,goods) == false orelse RuneInfo4#goods.num == 0)->
            {fail, 2};
		Protect > 0 andalso (is_record(Proinfo,goods) == false orelse Protect#goods.num == 0)->
			{fail, 2};
		%% 数量错误也算物品不存在
		RuneId1 > 0 andalso RuneInfo1#goods.num < N1 ->
			{fail,2};
		RuneId2 > 0 andalso RuneInfo2#goods.num < N2 ->
			{fail,2};
		RuneId3 > 0 andalso RuneInfo3#goods.num < N3 ->
			{fail,2};
		RuneId4 > 0 andalso RuneInfo4#goods.num < N4 ->
			{fail,2};
		Protect > 0 andalso Proinfo#goods.num =< 0 ->
			{fail,2};
		N1 + N2 + N3 + N4 > 4 ->
			{fail,2};
        GoodsInfo#goods.num < 1 orelse (Auto_purch == 0 andalso StoneInfo#goods.num < 1) ->
            {fail, 2};
		RuneId1 >0 andalso (RuneId1 == RuneId2 orelse RuneId1 == RuneId3 orelse RuneId1 == RuneId4) ->
			{fail,2};
		RuneId2 >0 andalso (RuneId2 == RuneId1 orelse RuneId2 == RuneId3 orelse RuneId2 == RuneId4) ->
			{fail,2};
		RuneId3 >0 andalso (RuneId3 == RuneId1 orelse RuneId3 == RuneId2 orelse RuneId3 == RuneId4) ->
			{fail,2};
		RuneId4 >0 andalso (RuneId4 == RuneId1 orelse RuneId4 == RuneId2 orelse RuneId4 == RuneId3) ->
			{fail,2};
   		%% 物品不属于你所有
        GoodsInfo#goods.player_id =/= PlayerStatus#player.id
                orelse (Auto_purch == 0 andalso StoneInfo#goods.player_id =/= PlayerStatus#player.id) ->
            {fail, 3};
        RuneId1 > 0 andalso RuneInfo1#goods.player_id =/= PlayerStatus#player.id ->
            {fail, 3};
        RuneId2 > 0 andalso RuneInfo2#goods.player_id =/= PlayerStatus#player.id ->
            {fail, 3};
        RuneId3 > 0 andalso RuneInfo3#goods.player_id =/= PlayerStatus#player.id ->
            {fail, 3};
        RuneId4 > 0 andalso RuneInfo4#goods.player_id =/= PlayerStatus#player.id ->
            {fail, 3};
		Protect > 0 andalso Proinfo#goods.player_id =/= PlayerStatus#player.id ->
			{fail,3};
		
        %% 物品位置不正确
%%     GoodsInfo#goods.location =/= 4 ->
%%         {fail, 4};
        %% 物品类型不正确
        GoodsInfo#goods.type =/= 10 ->
            {fail, 5};
		%% 戒指饰品 婚戒不能强化
		GoodsInfo#goods.subtype =:= 20 orelse GoodsInfo#goods.subtype =:= 21 orelse GoodsInfo#goods.subtype =:= 25 ->
			{fail,5};
        %% 物品类型不正确 type=15宝石 subtype=10 武器强化石 ；12 防具强化石
        Auto_purch == 0 andalso (StoneInfo#goods.type =/= 15 andalso StoneInfo#goods.subtype =/= 10 andalso StoneInfo#goods.subtype =/= 12) ->
			{fail, 5};
		%% 强化已达上限
        GoodsInfo#goods.stren >= 10 ->
            {fail, 8};
		%% 乘坐中的坐骑不能强化
		GoodsInfo#goods.id =:= PlayerStatus#player.mount  ->
			{fail, 9};
		%%  强化4级
		GoodsInfo#goods.stren == 3 andalso Protect > 0 andalso Proinfo#goods.goods_id /= 20500 ->
			{fail,5};
		%%  强化5级
		GoodsInfo#goods.stren == 4 andalso Protect > 0 andalso Proinfo#goods.goods_id /= 20501 ->
			{fail,5};
		%%  强化6级
		GoodsInfo#goods.stren == 5 andalso Protect > 0 andalso Proinfo#goods.goods_id /= 20502 ->
			{fail,5};
		%%  强化7级
		GoodsInfo#goods.stren == 6 andalso Protect > 0 andalso Proinfo#goods.goods_id /= 20503 ->
			{fail,5};
		%%  强化8级
		GoodsInfo#goods.stren == 7 andalso Protect > 0 andalso Proinfo#goods.goods_id /= 20504 ->
			{fail,5};
		%% 9彩保护法宝
		(GoodsInfo#goods.subtype < 14 orelse GoodsInfo#goods.subtype == 22 )  andalso GoodsInfo#goods.stren == 8 andalso Protect > 0 andalso (Proinfo#goods.goods_id /= 20308 andalso Proinfo#goods.goods_id /= 20505) ->
			{fail,5};
		%% 10彩保护法宝
		(GoodsInfo#goods.subtype < 14 orelse GoodsInfo#goods.subtype == 22 )  andalso GoodsInfo#goods.stren == 9 andalso Protect > 0 andalso (Proinfo#goods.goods_id /= 20310 andalso Proinfo#goods.goods_id /= 20506) ->
			{fail,5};
		%% 9彩保护防具
		GoodsInfo#goods.subtype >= 14 andalso GoodsInfo#goods.subtype /= 22 andalso GoodsInfo#goods.stren == 8 andalso Protect > 0 andalso (Proinfo#goods.goods_id /= 20312 andalso Proinfo#goods.goods_id /= 20505) ->
			{fail,5};
		%% 10彩保护防具
		GoodsInfo#goods.subtype >= 14 andalso GoodsInfo#goods.subtype /= 22 andalso GoodsInfo#goods.stren == 9 andalso Protect > 0 andalso (Proinfo#goods.goods_id /= 20314 andalso Proinfo#goods.goods_id /= 20506) ->
			{fail,5};
		%%飞行坐骑不能强化
		GoodsInfo#goods.goods_id =:= 16009->
			{fail,10};
        %% 物品类型不正确
		Auto_purch == 1 andalso is_record(StoneInfo, goods) =:= false andalso PlayerStatus#player.gold < GoodsTypeInfo#ets_base_goods.price ->
			{fail,11};
		true ->
			S_0_1 =
				if 
					GoodsInfo#goods.stren < 6 andalso RuneId1 > 0 ->
					   case lists:member(RuneInfo1#goods.goods_id, CanStrenNormal) of
						   true ->
							   0;
						   false ->
							   1
					   end;
					true ->
						0
				end,
			S_0_2 =
				if 
					GoodsInfo#goods.stren < 6 andalso RuneId2 > 0 ->
					   case lists:member(RuneInfo1#goods.goods_id, CanStrenNormal) of
						   true ->
							   0;
						   false ->
							   1
					   end;
					true ->
						0
				end,
			S_0_3 =
				if 
					GoodsInfo#goods.stren < 6 andalso RuneId3 > 0 ->
					   case lists:member(RuneInfo1#goods.goods_id, CanStrenNormal) of
						   true ->
							   0;
						   false ->
							   1
					   end;
					true ->
						0
				end,
			S_0_4 =
				if 
					GoodsInfo#goods.stren < 6 andalso RuneId4 > 0 ->
					   case lists:member(RuneInfo1#goods.goods_id, CanStrenNormal) of
						   true ->
							   0;
						   false ->
							   1
					   end;
					true ->
						0
				end,
			S_6_1 =
				if 
					GoodsInfo#goods.stren == 6 andalso RuneId1 > 0 ->
					   case lists:member(RuneInfo1#goods.goods_id, CanStren7) of
						   true ->
							   0;
						   false ->
							   1
					   end;
					true ->
						0
				end,
			S_6_2 =
				if 
					GoodsInfo#goods.stren == 6 andalso RuneId2 > 0 ->
					   case lists:member(RuneInfo2#goods.goods_id, CanStren7) of
						   true ->
							   0;
						   false ->
							   1
					   end;
					true ->
						0
				end,
			S_6_3 =
				if 
					GoodsInfo#goods.stren == 6 andalso RuneId3 > 0 ->
					   case lists:member(RuneInfo3#goods.goods_id, CanStren7) of
						   true ->
							   0;
						   false ->
							   1
					   end;
					true ->
						0
				end,
			S_6_4 =
				if 
					GoodsInfo#goods.stren == 6 andalso RuneId4 > 0 ->
					   case lists:member(RuneInfo4#goods.goods_id, CanStren7) of
						   true ->
							   0;
						   false ->
							   1
					   end;
					true ->
						0
				end,
			S_7_1 =
				if 
					GoodsInfo#goods.stren == 7 andalso RuneId1 > 0 ->
					   case lists:member(RuneInfo1#goods.goods_id, CanStren8) of
						   true ->
							   0;
						   false ->
							   1
					   end;
					true ->
						0
				end,
			S_7_2 =
				if 
					GoodsInfo#goods.stren == 7 andalso RuneId2 > 0 ->
					   case lists:member(RuneInfo2#goods.goods_id, CanStren8) of
						   true ->
							   0;
						   false ->
							   1
					   end;
					true ->
						0
				end,
			S_7_3 =
				if 
					GoodsInfo#goods.stren == 7 andalso RuneId3 > 0 ->
					   case lists:member(RuneInfo3#goods.goods_id, CanStren8) of
						   true ->
							   0;
						   false ->
							   1
					   end;
					true ->
						0
				end,
			S_7_4 =
				if 
					GoodsInfo#goods.stren == 7 andalso RuneId4 > 0 ->
					   case lists:member(RuneInfo4#goods.goods_id, CanStren8) of
						   true ->
							   0;
						   false ->
							   1
					   end;
					true ->
						0
				end,
			S_8_1 =
				if 
					GoodsInfo#goods.stren == 8 andalso RuneId1 > 0 ->
					   case lists:member(RuneInfo1#goods.goods_id, CanStren9) of
						   true ->
							   0;
						   false ->
							   1
					   end;
					true ->
						0
				end,
			S_8_2 =
				if 
					GoodsInfo#goods.stren == 8 andalso RuneId2 > 0 ->
					   case lists:member(RuneInfo2#goods.goods_id, CanStren9) of
						   true ->
							   0;
						   false ->
							   1
					   end;
					true ->
						0
				end,
			S_8_3 =
				if 
					GoodsInfo#goods.stren == 8 andalso RuneId3 > 0 ->
					   case lists:member(RuneInfo3#goods.goods_id, CanStren9) of
						   true ->
							   0;
						   false ->
							   1
					   end;
					true ->
						0
				end,
			S_8_4 =
				if 
					GoodsInfo#goods.stren == 8 andalso RuneId4 > 0 ->
					   case lists:member(RuneInfo4#goods.goods_id, CanStren9) of
						   true ->
							   0;
						   false ->
							   1
					   end;
					true ->
						0
				end,
			S_9_1 =
				if 
					GoodsInfo#goods.stren == 9 andalso RuneId1 > 0 ->
					   case lists:member(RuneInfo1#goods.goods_id, CanStren10) of
						   true ->
							   0;
						   false ->
							   1
					   end;
					true ->
						0
				end,
			S_9_2 =
				if 
					GoodsInfo#goods.stren == 9 andalso RuneId2 > 0 ->
					   case lists:member(RuneInfo2#goods.goods_id, CanStren10) of
						   true ->
							   0;
						   false ->
							   1
					   end;
					true ->
						0
				end,
			S_9_3 =
				if 
					GoodsInfo#goods.stren == 9 andalso RuneId3 > 0 ->
					   case lists:member(RuneInfo3#goods.goods_id, CanStren10) of
						   true ->
							   0;
						   false ->
							   1
					   end;
					true ->
						0
				end,
			S_9_4 =
				if 
					GoodsInfo#goods.stren == 9 andalso RuneId4 > 0 ->
					   case lists:member(RuneInfo4#goods.goods_id, CanStren10) of
						   true ->
							   0;
						   false ->
							   1
					   end;
					true ->
						0
				end,
			Code = S_0_1+S_0_2+S_0_3+S_0_4+S_6_1 + S_6_2 + S_6_3 +S_6_4+S_7_1+S_7_2+S_7_3 +S_7_4+S_8_1+S_8_2+S_8_3+S_8_4+S_9_1+S_9_2+S_9_3+S_9_4,
			if
				Code == 0 ->
					Att_type=goods_util:get_goods_attribute_id(GoodsInfo#goods.subtype),
            		Pattern = #ets_base_goods_strengthen{ goods_id=StoneTypeId, strengthen=GoodsInfo#goods.stren + 1,type=Att_type, _='_' },
            		GoodsStrengthenRule = goods_util:get_ets_info(?ETS_BASE_GOODS_STRENGTHEN, Pattern),
					Step=goods_util:level_to_step(GoodsInfo#goods.level),
					Pattern2 = #ets_base_goods_strengthen_anti{subtype=GoodsInfo#goods.subtype,step=Step,stren=GoodsInfo#goods.stren + 1, _='_' },
					GoodsStrengthenAntiRule = goods_util:get_ets_info(?ETS_BASE_GOODS_STRENGTHEN_ANTI,Pattern2),
            		if
                		%% 强化规则不存在,不能匹配规则说明物品错误，直接返回物品类型不正确
                		is_record(GoodsStrengthenRule, ets_base_goods_strengthen) =:= false ->
							{fail, 5};
                		%% 玩家铜钱不足
                		(PlayerStatus#player.coin + PlayerStatus#player.bcoin) < GoodsStrengthenRule#ets_base_goods_strengthen.coin ->
                    		{fail, 7};
                		true ->
							if Auto_purch == 1 ->
								   {ok, GoodsInfo, StoneInfo, RuneInfo1,RuneInfo2,RuneInfo3,RuneInfo4,Proinfo, GoodsStrengthenRule,GoodsStrengthenAntiRule,GoodsTypeInfo#ets_base_goods.price};
							   true ->
								   {ok, GoodsInfo, StoneInfo, RuneInfo1,RuneInfo2,RuneInfo3,RuneInfo4,Proinfo, GoodsStrengthenRule,GoodsStrengthenAntiRule,0}
							end
            		end;
				true ->
					{fail,5}
			end
    end.


check_hole(PlayerStatus, GoodsId, StoneId, StoneTypeId, Auto_purch) ->		
    GoodsInfo = goods_util:get_goods(GoodsId),
    StoneInfo = goods_util:get_goods(StoneId),
	GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, StoneTypeId),
    if
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false orelse (Auto_purch == 0 andalso is_record(StoneInfo, goods) =:= false) ->
            {fail, 2};
        %% 物品不存在
        GoodsInfo#goods.num < 1 orelse (Auto_purch == 0 andalso StoneInfo#goods.num < 1) ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= PlayerStatus#player.id
                orelse (Auto_purch ==0 andalso StoneInfo#goods.player_id =/= PlayerStatus#player.id) ->
            {fail, 3};
        %% 物品位置不正确
        %%GoodsInfo#goods.location =/= 4 ->
            %%{fail, 4};
        %% 物品类型不正确
        GoodsInfo#goods.type =/= 10 ->
            {fail, 5};
        %% 物品类型不正确
        StoneInfo#goods.type =/= 15 orelse (Auto_purch ==0 andalso StoneInfo#goods.subtype =/= 14) ->
            {fail, 5};
		GoodsInfo#goods.subtype == 24 orelse  GoodsInfo#goods.subtype == 26  orelse  GoodsInfo#goods.subtype == 27->
            {fail, 5};
		GoodsInfo#goods.color =:= 1 andalso (Auto_purch == 0 andalso StoneInfo#goods.goods_id =/= 21400) ->
			{fail,5};
		GoodsInfo#goods.color =:= 2 andalso (Auto_purch ==0  andalso StoneInfo#goods.goods_id =/= 21400) ->
			{fail,5};
		GoodsInfo#goods.color =:= 3 andalso (Auto_purch == 0 andalso StoneInfo#goods.goods_id =/= 21401) ->
			{fail,5};
		GoodsInfo#goods.color =:= 4 andalso (Auto_purch ==0 andalso StoneInfo#goods.goods_id =/= 21402) ->
			{fail,5};
		Auto_purch == 1 andalso is_record(StoneInfo, goods) =:= false andalso GoodsInfo#goods.color =:= 1 andalso StoneTypeId =/= 21400 ->
			{fail,5};
		Auto_purch == 1 andalso is_record(StoneInfo, goods) =:= false andalso GoodsInfo#goods.color =:= 2 andalso StoneTypeId =/= 21400 ->
			{fail,5};
		Auto_purch == 1 andalso is_record(StoneInfo, goods) =:= false andalso GoodsInfo#goods.color =:= 3 andalso StoneTypeId =/= 21401 ->
			{fail,5};
		Auto_purch == 1 andalso is_record(StoneInfo, goods) =:= false andalso GoodsInfo#goods.color =:= 4 andalso StoneTypeId =/= 21402 ->
			{fail,5};
        %% 孔数已达上限
        GoodsInfo#goods.hole >= 3 ->
            {fail, 6};
       %%  元宝不够
		Auto_purch == 1 andalso is_record(StoneInfo, goods) =:= false andalso PlayerStatus#player.gold < GoodsTypeInfo#ets_base_goods.price ->
		    {fail, 8};
        true ->
			Cost =
				case GoodsInfo#goods.hole of
					0 -> 10000;
					1 -> 30000;
					2 -> 50000
				end,
			if
				 %% 玩家铜钱不足
        		(PlayerStatus#player.coin + PlayerStatus#player.bcoin) < Cost ->
            		{fail, 7};
				true ->
            		{ok, GoodsInfo, StoneInfo , Cost, GoodsTypeInfo#ets_base_goods.price}
			end
    end.

check_compose(PlayerStatus, GoodsStatus, StoneTypeId,RuneId,RuneTypeId,Auto_purch,StoneList) ->
    RuneInfo = goods_util:get_goods(RuneId),
	GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, RuneTypeId),
    if
        %% 物品不存在
        RuneId > 0 andalso (Auto_purch == 0 andalso is_record(RuneInfo, goods) =:= false) ->
            {fail, 2};
        %% 物品不属于你所有
        Auto_purch == 0 andalso RuneInfo#goods.player_id =/= PlayerStatus#player.id ->
            {fail, 3};
        %% 物品位置不正确
        %%RuneInfo#goods.location =/= 4 ->
            %%{fail, 4};
        %% 物品类型不正确 (镶嵌合成符)
       Auto_purch == 0 andalso (RuneInfo#goods.type =/= 20 orelse RuneInfo#goods.subtype =/= 13) ->
            {fail, 5};
        %% 物品数量不正确
        Auto_purch == 0 andalso RuneInfo#goods.num < 1 ->
            {fail, 6};
        %% 物品数量不正确
        length(StoneList) =:= 0 ->
            {fail, 6};
		Auto_purch == 1 andalso is_record(RuneInfo, goods) =:= false andalso PlayerStatus#player.gold < GoodsTypeInfo#ets_base_goods.price ->
			{fail, 10};
        true ->
            case goods_util:list_handle(fun check_compose_stone/2, [RuneInfo, 0, [], RuneTypeId, Auto_purch], StoneList) of
                {fail, Res} ->
                    {fail, Res};
                {ok, [_, TotalStoneNum, NewStoneList,_RuneTypeId, _Auto_purch]} ->
                    Pattern = #ets_base_goods_compose{ goods_id = StoneTypeId, _='_' },
                    GoodsComposeRule = goods_util:get_ets_info(?ETS_BASE_GOODS_COMPOSE, Pattern),
                    if
                        %% 合成规则不存在
                        is_record(GoodsComposeRule, ets_base_goods_compose) =:= false ->
                            {fail, 7};
						TotalStoneNum < 2 ->
							{fail,6};
                        %% 玩家铜钱不足
                        (PlayerStatus#player.coin + PlayerStatus#player.bcoin) < GoodsComposeRule#ets_base_goods_compose.coin ->
                            {fail, 8};
                        %% 背包满
                        length(GoodsStatus#goods_status.null_cells) =:= 0 ->
                            {fail, 9};
                        true ->
							if is_record(GoodsTypeInfo,ets_base_goods) == true ->
								   {ok, NewStoneList,TotalStoneNum, RuneInfo, GoodsComposeRule,GoodsTypeInfo#ets_base_goods.price};
							   true ->
								   {ok, NewStoneList,TotalStoneNum, RuneInfo, GoodsComposeRule,0}
							end
                    end
            end
    end.

%% 处理合成宝石
check_compose_stone([StoneId, _StoneNum], [RuneInfo, Num, L, RuneTypeId, Auto_purch]) ->
    StoneInfo = goods_util:get_goods(StoneId),
	StoneNum = abs(_StoneNum),
	Exists = lists:member(StoneInfo, L),
    if
        %% 物品不存在
        is_record(StoneInfo, goods) =:= false ->
            {fail, 2};
		Exists == true ->
			{fail,2};
        %% 物品不属于你所有
        Auto_purch == 0 andalso StoneInfo#goods.player_id =/= RuneInfo#goods.player_id ->
            {fail, 3};
        %% 物品类型不正确
        StoneInfo#goods.type =/= 15 ->
            {fail, 5};
        %% 物品类型不正确 （合成符 匹配 合成石）
%%         RuneInfo#goods.color < StoneInfo#goods.color ->
%%             {fail, 5};
        %% 物品数量不正确
        StoneInfo#goods.num < StoneNum ->
            {fail, 6};
        true ->
			if
				is_record(RuneInfo,goods) == true ->
					case RuneInfo#goods.goods_id of
						20100 when StoneInfo#goods.level > 3 ->
							{fail,5};
						20101 when StoneInfo#goods.level < 4 orelse StoneInfo#goods.level > 5 ->
							{fail,5};
						20102 when StoneInfo#goods.level < 6  ->
							{fail,5};
						_ ->
							{ok, [RuneInfo, Num+StoneNum, [[StoneInfo, StoneNum]|L], RuneTypeId, Auto_purch]}
					end;
				is_record(RuneInfo,goods) == false ->
					case RuneTypeId of
						20100 when StoneInfo#goods.level > 3 ->
							{fail,5};
						20101 when StoneInfo#goods.level < 4 orelse StoneInfo#goods.level > 5 ->
							{fail,5};
						20102 when StoneInfo#goods.level < 6  ->
							{fail,5};
						_ ->
							{ok, [RuneInfo, Num+StoneNum, [[StoneInfo, StoneNum]|L], RuneTypeId, Auto_purch]}
					end;
				true ->
            		{ok, [RuneInfo, Num+StoneNum, [[StoneInfo, StoneNum]|L], RuneTypeId, Auto_purch]}
			end
    end.

check_inlay(PlayerStatus, GoodsId, StoneId, StoneTypeId, Auto_purch, RuneList) ->	
    GoodsInfo = goods_util:get_goods(GoodsId),
    StoneInfo = goods_util:get_goods(StoneId),
	InlayNum = goods_util:count_inlay_num(GoodsInfo),
	GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, StoneTypeId),
	Cost =
	if
		InlayNum =:= 0 ->
			10000 ;
		InlayNum =:= 1 ->
			30000 ;
		true  ->
			50000
	end,
	if
		is_record(GoodsInfo,goods) =:= true andalso is_record(StoneInfo,goods) =:= true ->
			StonePreFix = trunc(StoneInfo#goods.goods_id / 10),
			Hole1PreFix = trunc(GoodsInfo#goods.hole1_goods /10),
			Hole2PreFix = trunc(GoodsInfo#goods.hole2_goods /10),
			Hole3PreFix = trunc(GoodsInfo#goods.hole3_goods /10);
		true ->
			StonePreFix = 0,
			Hole1PreFix = 0,
			Hole2PreFix = 0,
			Hole3PreFix = 0
	end,
    if
        %% 物品不存在
        is_record(GoodsInfo,goods) =:= false orelse is_record(StoneInfo,goods) =:= false ->
            {fail, 2};
        %% 物品不存在
        GoodsInfo#goods.num < 1 orelse StoneInfo#goods.num < 1 ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= PlayerStatus#player.id
                orelse StoneInfo#goods.player_id =/= PlayerStatus#player.id ->
            {fail, 3};
        %% 物品位置不正确
        %%GoodsInfo#goods.location =/= 4 ->
           %% {fail, 4};
		 %% 物品位置不正确
        GoodsInfo#goods.type =/= 10 ->
            {fail, 4};
		%% 婚戒不能镶嵌
		GoodsInfo#goods.subtype == 25 ->
			{fail, 5};
        %% 物品类型不正确
        StoneInfo#goods.type =/= 15 orelse StoneInfo#goods.subtype =/= 13 ->
            {fail, 5};
        %% 物品类型不正确 有没有镶嵌过同类型物品
        GoodsInfo#goods.hole1_goods > 0 andalso (StonePreFix =:= Hole1PreFix) ->
            {fail, 5};
		GoodsInfo#goods.hole2_goods > 0 andalso (StonePreFix =:= Hole2PreFix) ->
            {fail, 5};
		GoodsInfo#goods.hole3_goods > 0 andalso (StonePreFix =:= Hole3PreFix) ->
            {fail, 5};
        %% 没有孔位
        GoodsInfo#goods.hole =:= 0 ->
            {fail, 6};
        %% 没有孔位
        GoodsInfo#goods.hole1_goods > 0 andalso GoodsInfo#goods.hole2_goods > 0 andalso GoodsInfo#goods.hole3_goods > 0 ->
            {fail, 6};
        true ->
            case goods_util:list_handle(fun check_inlay_rune/2, [PlayerStatus#player.id ,StoneInfo, 0, 0, [], Auto_purch], RuneList) of
                {fail, Res} ->
                    {fail, Res};
                {ok, [_,_, TotalRuneNum,Rbind,NewRuneList,_Auto_purch]} ->
                    Pattern = #ets_base_goods_inlay{ goods_id=StoneInfo#goods.goods_id, _='_' },
                    GoodsInlayRule = goods_util:get_ets_info(?ETS_BASE_GOODS_INLAY, Pattern),
                    if
                        %% 镶嵌规则不存在
                        is_record(GoodsInlayRule, ets_base_goods_inlay) =:= false ->
                            {fail, 7};
						GoodsInlayRule#ets_base_goods_inlay.low_level > GoodsInfo#goods.level ->
							{fail,5}; 
                        %% 玩家铜钱不足
                        (PlayerStatus#player.coin + PlayerStatus#player.bcoin) < Cost ->
                            {fail, 8};
						TotalRuneNum < 3 andalso Auto_purch == 1 andalso StoneInfo#goods.level =< 3 andalso StoneTypeId =/= 20200 ->
			 				{fail, 5};
						TotalRuneNum < 3 andalso Auto_purch == 1 andalso StoneInfo#goods.level > 3 andalso StoneInfo#goods.level =< 5 andalso StoneTypeId =/= 20201 ->
			 				{fail, 5};
						TotalRuneNum < 3 andalso Auto_purch == 1 andalso StoneInfo#goods.level > 5 andalso StoneInfo#goods.level =< 8 andalso StoneTypeId =/= 20202 ->
							{fail, 5};
						%% 元宝不够
						Auto_purch == 1 andalso PlayerStatus#player.gold < GoodsTypeInfo#ets_base_goods.price*(3-TotalRuneNum) ->
							{fail, 11};
                        true ->
                            case length(GoodsInlayRule#ets_base_goods_inlay.equip_types) > 0
                                    andalso lists:member(GoodsInfo#goods.subtype, GoodsInlayRule#ets_base_goods_inlay.equip_types) =:= false of
                                %% 不可镶嵌的类型
                                true -> {fail, 9};
                                false -> 
									if Auto_purch == 1 ->
										   {ok, GoodsInfo, StoneInfo, TotalRuneNum,Rbind,NewRuneList, GoodsInlayRule ,Cost, GoodsTypeInfo#ets_base_goods.price*(3-TotalRuneNum)};
									   true ->
										   {ok, GoodsInfo, StoneInfo, TotalRuneNum,Rbind,NewRuneList, GoodsInlayRule ,Cost, 0}
									end
                            end
                    end
            end
    end.

%% 处理镶嵌符
check_inlay_rune([RuneId, _RuneNum], [PlayerId,StoneInfo, Num,Rbind, L, Auto_purch]) ->
	RuneNum = abs(_RuneNum),
    RuneInfo = goods_util:get_goods(RuneId),
	Exists = lists:member(RuneInfo, L),
    if
        %% 物品不存在
        Auto_purch ==0 andalso is_record(RuneInfo, goods) =:= false ->
            {fail, 2};
		%% 物品重复发送
		Exists == true ->
			{fail,2};
        %% 物品不属于你所有
        Auto_purch ==0 andalso RuneInfo#goods.player_id =/= PlayerId ->
            {fail, 3};
        %% 物品类型不正确
        Auto_purch ==0 andalso (RuneInfo#goods.type =/= 20 orelse RuneInfo#goods.subtype =/= 11) ->
            {fail, 5};
		%% 低级镶嵌符 1-3级宝石 。。
		StoneInfo#goods.level =< 3 andalso (Auto_purch ==0 andalso RuneInfo#goods.goods_id =/= 20200) ->
			{fail,5};
		StoneInfo#goods.level > 3 andalso (Auto_purch ==0 andalso StoneInfo#goods.level =< 5 andalso RuneInfo#goods.goods_id =/= 20201) ->
			{fail,5};
		StoneInfo#goods.level > 5 andalso (Auto_purch ==0 andalso StoneInfo#goods.level =< 8 andalso RuneInfo#goods.goods_id =/= 20202) ->
			{fail,5};
        %% 物品数量不正确
        RuneInfo#goods.num < RuneNum ->
            {fail, 2};
        true ->
            {ok, [PlayerId,StoneInfo, Num+RuneNum, Rbind +RuneInfo#goods.bind,[[RuneInfo, RuneNum]|L],Auto_purch]}
    end.

check_refine(Player,Gid,StoneList) ->
	GoodsInfo = goods_util:get_goods(Gid),
	%%查询附魔属性
	GoodsAttributeList = goods_util:get_goods_attribute_list(Player#player.id, Gid, 7),
	if
		is_record(GoodsInfo,goods) =:= false orelse GoodsInfo#goods.num < 1->
			{fail,2};%%物品不存在
		GoodsInfo#goods.player_id /= Player#player.id ->
			{fail,3};%%物品不属于你
		GoodsInfo#goods.location /= 4 ->
			{fail,4};%%物品位置不正确
		GoodsInfo#goods.type /= 10 ->
			{fail,0};%%物品类型错误
		GoodsInfo#goods.subtype < 14 andalso (GoodsInfo#goods.step < 4 orelse GoodsInfo#goods.step > 10) ->
			{fail,5};%%法宝阶数错误
		GoodsInfo#goods.color  /= 3 andalso (GoodsInfo#goods.subtype == 21 andalso (GoodsInfo#goods.color /= 4 andalso GoodsInfo#goods.color /= 3))->
			{fail,6};%%法宝颜色错误
		GoodsInfo#goods.grade > 1 ->
			{fail,7};%%法宝已经修炼
		GoodsInfo#goods.stren > 0 ->
			{fail,8};%%法宝已经强化
		GoodsInfo#goods.hole > 0 ->
			{fail,9};%%法宝已打孔
		GoodsInfo#goods.subtype == 23 andalso (GoodsInfo#goods.level < 30 orelse GoodsInfo#goods.level > 100) ->
			{fail,15};%%戒指等级错误
		length(GoodsAttributeList) > 0 ->
			{fail,17};%%装备有附魔属性不能精炼
		true ->
			if
				GoodsInfo#goods.subtype < 14 -> %%法宝
					case GoodsInfo#goods.step of
						4 -> Cost = 280000;
						5 -> Cost = 560000;
						6 -> Cost = 1120000;
						7 -> Cost = 2240000;
						8 -> Cost = 4480000;
						9 -> Cost = 8960000;
						10 -> Cost = 17920000
					end;
				GoodsInfo#goods.subtype == 23 -> %%戒指
					case goods_util:level_to_step(GoodsInfo#goods.level) of 
						4 -> Cost = 140000;
						5 -> Cost = 280000;
						6 -> Cost = 560000;
						7 -> Cost = 1120000;
						8 -> Cost = 2240000;
						9 -> Cost = 4480000;
						10 -> Cost = 8960000
					end;
				GoodsInfo#goods.subtype == 21 andalso GoodsInfo#goods.color == 3 -> %%饰品精炼
					case goods_util:level_to_step(GoodsInfo#goods.level) of 
						4 -> Cost = 140000;
						5 -> Cost = 280000;
						6 -> Cost = 560000;
						7 -> Cost = 1120000;
						8 -> Cost = 2240000;
						9 -> Cost = 4480000;
						10 -> Cost = 8960000
					end;
				true -> %%饰品属性激活
					case goods_util:level_to_step(GoodsInfo#goods.level) of 
						4 -> Cost = 15000;
						5 -> Cost = 30000;
						6 -> Cost = 50000;
						7 -> Cost = 100000;
						8 -> Cost = 150000;
						9 -> Cost = 200000;
						10 -> Cost = 250000
					end
			end,
			NoIdentify = goods_util:count_noidentify_num(GoodsInfo),
			if
				(Player#player.coin + Player#player.bcoin) < Cost ->
					{fail,10};%%铜币不足
				GoodsInfo#goods.color == 3 andalso NoIdentify > 0 ->
					{fail,11};%%存在属性没有鉴定
				GoodsInfo#goods.color == 4 andalso NoIdentify == 0 ->
					{fail,0};%% 紫饰品已经精炼完毕
				true ->
					Estep = 
						if
							GoodsInfo#goods.subtype < 14 ->
								GoodsInfo#goods.step;
							true ->
								goods_util:level_to_step(GoodsInfo#goods.level)
						end,
					case goods_util:list_handle(fun check_refine_rule/2, [Player#player.id ,0,GoodsInfo#goods.subtype,Estep,GoodsInfo#goods.bind,[]], StoneList) of
						{fail,Code} ->
							{fail,Code};
						{ok,[_,TotalStoneNum,_,_,Rbind,NewStoneList]} ->
							if
								%%非饰品
								GoodsInfo#goods.subtype /= 21 andalso GoodsInfo#goods.color == 3 ->
									if
										GoodsInfo#goods.subtype < 14 andalso TotalStoneNum < 8 ->
											{fail,14};%%紫水晶数量不足
										GoodsInfo#goods.subtype == 23 andalso TotalStoneNum < 4 ->
											{fail,16};%%紫玉石数量不足
										true ->
											{ok,GoodsInfo,Cost,Rbind,NewStoneList}
									end;
								%%饰品金色精炼
								GoodsInfo#goods.subtype == 21 andalso GoodsInfo#goods.color == 3 ->
									ZSJ = check_refine_stone_type_num(15,NewStoneList),
									ZY = check_refine_stone_type_num(17,NewStoneList),
									if
										ZSJ < 3 ->
											{fail,14};
										ZY < 3 ->
											{fail,16};
										true ->
											{ok,GoodsInfo,Cost,Rbind,NewStoneList}
									end;
								%%饰品紫色属性鉴定
								true ->
									ZSJ = check_refine_stone_type_num(15,NewStoneList),
									ZY = check_refine_stone_type_num(17,NewStoneList),
									if
										ZSJ < 1 ->
											{fail,14};
										ZY < 1 ->
											{fail,16};
										true ->
											{ok,GoodsInfo,Cost,Rbind,NewStoneList}
									end
							end
					end
			end
	end.
%%检查紫玉或紫水晶数量
check_refine_stone_type_num(SubType,NewStoneList) ->
	F_count = fun([StoneInfo,StoneNum],Total) ->
					  if
						  StoneInfo#goods.subtype == SubType ->
							  Total + StoneNum;
						  true ->
							  Total
					  end
			  end,
	lists:foldl(F_count, 0, NewStoneList).

check_refine_rule([StoneId,_StoneNum],[PlayerId,Num,Esubtype,Estep,Rbind,StoneList]) ->
	StoneInfo = goods_util:get_goods(StoneId),
	StoneNum = abs(_StoneNum),
	Exists = lists:member(StoneInfo, StoneList),
    if
        %% 物品不存在 
        is_record(StoneInfo, goods) =:= false ->
            {fail,2};
		Exists == true ->
			{fail,2};
        %% 物品不属于你所有
        StoneInfo#goods.player_id =/= PlayerId ->
            {fail,3};
        %% 物品类型不正确
        Esubtype < 14 andalso (StoneInfo#goods.type /= 15 orelse StoneInfo#goods.subtype /= 15) ->
            {fail,12};
		Esubtype < 14 andalso StoneInfo#goods.step /= Estep ->
			{fail,12};
        %% 物品数量不正确
        StoneInfo#goods.num < StoneNum ->
            {fail,13};
		Esubtype == 23 andalso (StoneInfo#goods.type /= 15 orelse StoneInfo#goods.subtype /= 17) ->
			{fail,16};
		Esubtype == 21 andalso (StoneInfo#goods.type /= 15 orelse (StoneInfo#goods.subtype /= 15 andalso StoneInfo#goods.subtype /= 17)) ->
			{fail,16};
        true ->
            {ok,[PlayerId,Num+StoneNum,Esubtype,Estep,Rbind+StoneInfo#goods.bind,[[StoneInfo,StoneNum]|StoneList]]}
    end.

check_idecompose_list(Player,GoodsStatus,Type,GoodsList) ->
	case goods_util:list_handle(fun check_idecompose/2,[Player,Type,0,[],[]],GoodsList) of
		{ok,[_Np,_t,Cost,GoodsInfoList,GoodsTotalList]} ->
			%%对物品列表整理
			F = fun({_goods_id,_num,_bind},_NewTotalList) ->
						F_filter = fun({_ngid,_nnum,_nbind}) ->
										_goods_id == _ngid andalso _bind == _nbind
								   end,
						SameList = lists:filter(F_filter, _NewTotalList),
						F_Num = fun({_ogid,_onum,_obind},_total) ->
										_onum + _total
								end,
						SameNum = lists:foldl(F_Num,_num,SameList),
						if
							length(SameList) > 0 ->
								{Sgid,_,Sbind} = hd(SameList),
								[{Sgid,SameNum,Sbind}|_NewTotalList -- SameList];	
							true ->
								[{_goods_id,_num,_bind}|_NewTotalList]
						end				
				end,
			NewGoodsTotalList = lists:foldl(F, [], lists:flatten(GoodsTotalList)),
			if
				Type == 1 andalso (length(GoodsStatus#goods_status.null_cells) < (length(NewGoodsTotalList) - length(GoodsList))) ->
					{fail,7};
				true ->
				  {ok,Cost,GoodsInfoList,NewGoodsTotalList}
			end;
		{fail,Code} ->
			{fail,Code}
	end.


check_idecompose(Gid,[Player,Type,Cost0,GoodsInfoList0,Glist0]) ->
	GoodsInfo = goods_util:get_goods(Gid),
	IsExists = lists:member(GoodsInfo,GoodsInfoList0),
	if
		is_record(GoodsInfo,goods) =:= false orelse GoodsInfo#goods.num < 1->
			{fail,2};%%物品不存在
		IsExists == true ->
			{fail,2};%%物品重复了
		GoodsInfo#goods.player_id /= Player#player.id ->
			{fail,3};%%物品不属于你
		GoodsInfo#goods.location /= 4 ->
			{fail,4};%%物品位置不正确
		%% 这个是任务给出的武器
		GoodsInfo#goods.grade == 50 andalso GoodsInfo#goods.spirit == 1  ->
			{fail,3};
		true ->	
			%%优先指定ID分解,再根据类型分解
			Ms_id = ets:fun2ms(fun(T) when T#ets_base_goods_idecompose.goods_id == GoodsInfo#goods.goods_id ->
									   T
							   end),
			IdecomposeRuleIdList = ets:select(?ETS_BASE_GOODS_IDECOMPOSE, Ms_id),
			case length(IdecomposeRuleIdList) > 0 of
				true ->
					IdDecompose = true,
					IdecomposeRuleList = IdecomposeRuleIdList;
				false ->
					IdDecompose = false,
					MS_type = ets:fun2ms(fun(T) when T#ets_base_goods_idecompose.type == GoodsInfo#goods.type andalso
										 T#ets_base_goods_idecompose.color == GoodsInfo#goods.color andalso 
											T#ets_base_goods_idecompose.lv_down =< GoodsInfo#goods.level andalso
											T#ets_base_goods_idecompose.lv_up >= GoodsInfo#goods.level andalso
											T#ets_base_goods_idecompose.goods_id == 0 -> 
							T 
					end),
					IdecomposeRuleList = ets:select(?ETS_BASE_GOODS_IDECOMPOSE, MS_type)
			end,				
			Bind =  GoodsInfo#goods.bind,
			if
				length(IdecomposeRuleList) == 0 ->
					{fail,5};%%分解规则不存在
				true ->
					Rule = hd(IdecomposeRuleList),
					if
						%% 预览不需要考虑角色金钱
						(Player#player.coin + Player#player.bcoin) < Rule#ets_base_goods_idecompose.price andalso Type /= 0 ->
							{fail,6};%%铜币不足
						true ->
							Cost = Rule#ets_base_goods_idecompose.price,
							Step = goods_util:level_to_step(GoodsInfo#goods.level),
							%%Ratio = Rule#ets_base_goods_idecompose.ratio,
							GlistData = tool:list_to_term(tool:to_list(Rule#ets_base_goods_idecompose.target)),
							%%紫色戒指减半
							Flist = fun({_Goods_id,_Num}) ->
											if
												GoodsInfo#goods.subtype == 23  -> %%紫戒指
													{_Goods_id,round(_Num/2),0};
												GoodsInfo#goods.goods_id div 1000 == 18 -> %%塔装
													{_Goods_id,round(_Num/2),0};
												true ->
													if 
														IdDecompose == true ->
															%%具体物品分解根据物品绑定状态返回
															{_Goods_id,_Num,Bind};
														true ->
															{_Goods_id,_Num,0}
													end											
											end
									end,
							%% 基础石头
							%%{物品id，数量，绑定类型}
							Glist = lists:map(Flist, GlistData),
							%% 幸运符
							Glist2 =
								case GoodsInfo#goods.stren of
									7 -> [{20303,1,Bind}|Glist];
									8 -> [{20304,1,Bind}|Glist];
									9 -> [{20305,1,Bind}|Glist];
									10 -> [{20306,1,Bind}|Glist];
									_ ->Glist
								end,
							%% 诛邪礼包
							IsZiJieZhi = GoodsInfo#goods.type == 10 andalso GoodsInfo#goods.subtype == 23 andalso GoodsInfo#goods.color == 4 ,
							IsZiShiPin = GoodsInfo#goods.type == 10 andalso GoodsInfo#goods.subtype == 21 andalso GoodsInfo#goods.color == 4 ,
							Glist3 =
								case GoodsInfo#goods.color == 4 andalso 
														 GoodsInfo#goods.goods_id div 1000 =< 15 andalso 
																			 IsZiJieZhi == false andalso 
																			 IsZiShiPin == false andalso
																			 	IdDecompose == false of %%
									true ->									
										case Step of
											4 ->[{28804,1,Bind}|Glist2];
											5 ->[{28805,1,Bind}|Glist2];
											6 ->[{28806,1,Bind}|Glist2];
											7 ->[{28807,1,Bind}|Glist2];
											8 ->[{28807,1,Bind}|Glist2];
											_ ->Glist2
										end;
									false ->
										Glist2
								end,
							Glist4 =
								if
									IsZiJieZhi andalso GoodsInfo#goods.level > 38 ->
										case Step of
											5 -> [{21701,1,Bind},{21701,1,Bind}|Glist3];
											6 -> [{21702,1,Bind},{21702,1,Bind}|Glist3];
											7 -> [{21703,1,Bind},{21703,1,Bind}|Glist3];
											8 -> [{21704,1,Bind},{21704,1,Bind}|Glist3];
											_ -> Glist3
										end;
									IsZiShiPin ->
										case Step of
											4 -> [{21700,1,Bind},{21500,1,Bind}|Glist3];
											5 -> [{21701,1,Bind},{21501,1,Bind}|Glist3];
											6 -> [{21702,1,Bind},{21502,1,Bind}|Glist3];
											7 -> [{21703,1,Bind},{21503,1,Bind}|Glist3];
											8 -> [{21704,1,Bind},{21504,1,Bind}|Glist3];
											_ -> Glist3
										end;
									true ->
										Glist3
								end,								
									
							%%计算金钱消耗，不扣除 ；预览不计算
							if Type == 0 ->
								   NewPlayer = Player ;
							   true ->
									NewPlayer = goods_util:get_cost(Player,Cost,coin)
							end,
							{ok,[NewPlayer,Type,Cost0+Cost,[GoodsInfo|GoodsInfoList0],[Glist4|Glist0]]}

					end
			end
	end.

check_icompose(Player,Mid,N,GoodsStatus)->
	IcomposeRule = goods_util:get_ets_info(?ETS_BASE_GOODS_ICOMPOSE,Mid),
	NullCells = length(GoodsStatus#goods_status.null_cells),
	if
		N =< 0 ->
			{fail,0};
		NullCells =< 0 ->
			{fail,5};
		is_record(IcomposeRule,ets_base_goods_icompose) ->
			if
				(Player#player.coin + Player#player.bcoin) < IcomposeRule#ets_base_goods_icompose.price * N ->
					{fail,3};%%铜币不足
				true ->
					Require = util:string_to_term(tool:to_list(IcomposeRule#ets_base_goods_icompose.require)),
					F = fun({Goods_id,Num},R) ->
								TypeList = goods_util:get_type_goods_list(Player#player.id,Goods_id,4),
								Total = goods_util:get_goods_totalnum(TypeList),
								if
									Total >= Num * N ->
										R;
									true ->
										R +1
								end
						end,
					Check = lists:foldl(F, 0, Require),
					if
						Check > 0 ->
							{fail,4};%%材料不足
						true ->
							{ok,IcomposeRule}
					end
			end;
		true ->
			{fail,2}%%合成规则不存在
	end.
		
check_backout(PlayerStatus, _GoodsStatus, GoodsId, StoneId, StoneTypeId, Auto_purch, RuneList) ->
    GoodsInfo = goods_util:get_goods_by_id(GoodsId),
	StoneTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, StoneId),
	InlayNum = goods_util:count_inlay_num(GoodsInfo),
	GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, StoneTypeId),
	Cost =
	if
		InlayNum =:= 3 ->
			50000 ;
		InlayNum =:= 2 ->
			30000 ;
		InlayNum =:= 1 ->
			10000 ;
		true  ->
			0
	end,
    if
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false orelse GoodsInfo#goods.num < 1 ->
			lib_goods:delete_goods(GoodsId),
            {fail, 2};
		is_record(StoneTypeInfo,ets_base_goods) =:= false ->
			{fail,2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= PlayerStatus#player.id ->
            {fail, 3};
        %% 物品位置不正确
        %%GoodsInfo#goods.location =/= 4  ->
            %%{fail, 4};
        %% 物品类型不正确
        GoodsInfo#goods.type =/= 10 ->
            {fail, 5};
        %% 没有宝石可拆
        GoodsInfo#goods.hole1_goods =/= StoneId andalso GoodsInfo#goods.hole2_goods =/= StoneId andalso GoodsInfo#goods.hole3_goods =/= StoneId ->
            {fail, 8};
        %% 玩家铜钱不足
        (PlayerStatus#player.coin + PlayerStatus#player.bcoin) < Cost ->
            {fail, 6};
		%% 这个是任务给出的武器
		GoodsInfo#goods.grade == 50 andalso GoodsInfo#goods.spirit == 1  ->
			{fail,3};
        true ->
			StoneLevel = StoneTypeInfo#ets_base_goods.level,
			case goods_util:list_handle(fun check_backout_rune/2, [PlayerStatus#player.id ,StoneLevel, 0,0,[], Auto_purch], RuneList) of
          		{fail,Res} ->
					{fail,Res};
				{ok,[_,_,TotalRuneNum,Rbind,NewRuneList,_Auto_purch]} ->
					%%物品镶嵌的规则
					Pattern = #ets_base_goods_inlay{ goods_id=StoneId, _='_' },
                    GoodsInlayRule = goods_util:get_ets_info(?ETS_BASE_GOODS_INLAY, Pattern),
					if
						is_record(GoodsInlayRule,ets_base_goods_inlay) =:= false ->
							{fail,2};
						TotalRuneNum < 3 andalso Auto_purch == 1 andalso StoneLevel =< 3 andalso StoneTypeId =/= 20000 ->
			 				{fail, 5};
						TotalRuneNum < 3 andalso Auto_purch == 1 andalso StoneLevel > 3 andalso StoneLevel =< 5 andalso StoneTypeId =/= 20001 ->
			 				{fail, 5};
						TotalRuneNum < 3 andalso Auto_purch == 1 andalso StoneLevel > 5 andalso StoneLevel =< 8 andalso StoneTypeId =/= 20002 ->
							{fail, 5};
						%% 元宝不够
						Auto_purch == 1 andalso PlayerStatus#player.gold < GoodsTypeInfo#ets_base_goods.price*(3-TotalRuneNum) ->
							{fail, 10};
						true ->
							if Auto_purch == 1 ->
								   {ok, GoodsInfo,StoneTypeInfo,TotalRuneNum,NewRuneList,GoodsInlayRule,Rbind,Cost,GoodsTypeInfo#ets_base_goods.price*(3-TotalRuneNum)};
							   true ->
								   {ok, GoodsInfo,StoneTypeInfo,TotalRuneNum,NewRuneList,GoodsInlayRule,Rbind,Cost,0}
							end							
					end;
				_ ->
					{fail,5}
			end
    end.

check_backout_rune([RuneId, _RuneNum], [PlayerId,StoneLevel,Num,Rbind, L, Auto_purch]) ->
	RuneInfo = goods_util:get_goods(RuneId),
	RuneNum = abs(_RuneNum),
	Exists = lists:member(RuneInfo, L),
    if
        %% 物品不存在 
        Auto_purch == 0 andalso is_record(RuneInfo, goods) =:= false ->
            {fail,2};
		Exists == true ->
			{fail,2};
        %% 物品不属于你所有
        Auto_purch == 0 andalso RuneInfo#goods.player_id =/= PlayerId ->
            {fail,3};
        %% 物品类型不正确
       Auto_purch == 0 andalso (RuneInfo#goods.type =/= 20 orelse RuneInfo#goods.subtype =/= 12) ->
            {fail,5};
		StoneLevel =< 3 andalso (Auto_purch == 0 andalso RuneInfo#goods.goods_id =/= 20000) ->
			{fail,5};
		StoneLevel >= 4 andalso StoneLevel =< 5 andalso (Auto_purch == 0 andalso RuneInfo#goods.goods_id =/= 20001) ->
			{fail,5};
		StoneLevel >= 6 andalso StoneLevel =< 8 andalso (Auto_purch == 0 andalso RuneInfo#goods.goods_id =/= 20002) ->
			{fail,5};
        %% 物品数量不正确
        RuneInfo#goods.num < RuneNum ->
            {fail,2};		
        true ->
            {ok,[PlayerId,StoneLevel,Num+RuneNum,Rbind+RuneInfo#goods.bind,[[RuneInfo, RuneNum]|L],Auto_purch]}
    end.

check_identify(PlayerStatus,GoodsId,StoneId,StoneTypeId,Auto_purch) ->
	GoodsInfo = goods_util:get_goods(GoodsId),
	StoneInfo = goods_util:get_goods(StoneId),
	IdentifyNum=goods_util:count_noidentify_num(GoodsInfo),
	GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, StoneTypeId),
	if
        %% 物品不存在
        is_record(GoodsInfo, goods) =:= false orelse (Auto_purch == 0 andalso is_record(StoneInfo, goods) =:= false) ->
            {fail, 2};
        %% 物品不存在
        GoodsInfo#goods.num < 1 orelse (Auto_purch == 0 andalso StoneInfo#goods.num < 1) ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= PlayerStatus#player.id orelse (Auto_purch == 0 andalso StoneInfo#goods.player_id =/= PlayerStatus#player.id) ->
            {fail, 3};
        %% 物品位置不正确
        %%GoodsInfo#goods.location =/= 4 orelse StoneInfo#goods.location =/= 4 ->
         %%   {fail, 4};
        %% 物品类型不正确
        GoodsInfo#goods.type =/= 10 orelse StoneInfo#goods.type =/= 15->
            {fail, 5};
		StoneInfo#goods.subtype =/= 11 orelse GoodsInfo#goods.color =:= 0 ->
			{fail, 5};     
        GoodsInfo#goods.color =:= 1 andalso (Auto_purch == 0 andalso StoneInfo#goods.goods_id =/= 21000) ->
			{fail, 5};
		GoodsInfo#goods.color =:= 2 andalso (Auto_purch == 0 andalso StoneInfo#goods.goods_id =/= 21001) ->
			{fail, 5};
		GoodsInfo#goods.color =:= 3 andalso (Auto_purch == 0 andalso StoneInfo#goods.goods_id =/= 21002) ->
			{fail, 5};
		GoodsInfo#goods.color =:= 4 andalso (Auto_purch == 0 andalso StoneInfo#goods.goods_id =/= 21002) ->
			{fail, 5};
		GoodsInfo#goods.subtype == 21 andalso GoodsInfo#goods.color == 4 ->
			{fail,5};
		%%没有需要鉴定的属性
		IdentifyNum =< 0 ->
			{fail,6};
		%%自动购买元宝不够
		Auto_purch == 1 andalso is_record(StoneInfo, goods) =:= false andalso PlayerStatus#player.gold < GoodsTypeInfo#ets_base_goods.price ->
			{fail,7};
        true ->
			%%取附加属性列表
            AttributeList = goods_util:get_goods_attribute_list(PlayerStatus#player.id,GoodsInfo#goods.id,1),
			if
				length(AttributeList) < 1 ->
					{fail,6};
				true ->
            		{ok,StoneInfo,GoodsInfo,AttributeList,GoodsTypeInfo#ets_base_goods.price}
			end
    end.

check_practise(PlayerStatus,GoodsId)->
	GoodsInfo = goods_util:get_goods(GoodsId),
	%% 这里获取法宝现在有的附加属性个数
	AddAttributeList=goods_util:get_goods_attribute_list(PlayerStatus#player.id,GoodsId,1),
	Att_num =length(AddAttributeList),
	if
        %% 物品不存在
        is_record(GoodsInfo,goods) =:= false  ->
            {fail, 2};
        %% 物品不存在
        GoodsInfo#goods.num < 1  ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo#goods.player_id =/= PlayerStatus#player.id ->
            {fail, 3};
        %% 物品位置不正确
        %%GoodsInfo#goods.location =/= 4 ->
        %%    {fail, 4};
        %% 物品类型不正确
        GoodsInfo#goods.type =/= 10 orelse GoodsInfo#goods.subtype > 13 orelse GoodsInfo#goods.subtype < 9->
            {fail, 5};
		%% 达到最大修炼等级
		GoodsInfo#goods.grade + 1 > (GoodsInfo#goods.step * 10) ->
			{fail,7};
		GoodsInfo#goods.grade >= PlayerStatus#player.lv ->
			{fail,7};
        true -> 
			NeedSpirit = data_equip:get_spirit(GoodsInfo#goods.grade),
			Pattern = #ets_base_goods_practise{att_num = Att_num,subtype = GoodsInfo#goods.subtype,step = GoodsInfo#goods.step,color = GoodsInfo#goods.color, grade =GoodsInfo#goods.grade + 1, _='_' },
            GoodsPractiseRule = goods_util:get_ets_info(?ETS_BASE_GOODS_PRACTISE, Pattern),
			if
				%%物品类型错误
				is_record(GoodsPractiseRule,ets_base_goods_practise) =:= false ->
					{fail,5};
				%%灵力不足
				NeedSpirit > PlayerStatus#player.spirit ->
					{fail,6};
				true ->
            		{ok,GoodsInfo, GoodsPractiseRule,AddAttributeList}
			end
    end.

check_merge(PlayerStatus,GoodsId1,GoodsId2) ->
	GoodsInfo1 = goods_util:get_goods(GoodsId1),
	GoodsInfo2 = goods_util:get_goods(GoodsId2),
	if
        %% 物品不存在
        is_record(GoodsInfo1, goods) =:= false orelse is_record(GoodsInfo2,goods) =:= false ->
            {fail, 2};
        %% 物品不存在
        GoodsInfo1#goods.num < 1 orelse GoodsInfo2#goods.num <1  ->
            {fail, 2};
        %% 物品不属于你所有
        GoodsInfo1#goods.player_id =/= PlayerStatus#player.id orelse GoodsInfo2#goods.player_id =/= PlayerStatus#player.id ->
            {fail, 3};
      
        %% 物品类型不正确
        GoodsInfo1#goods.type =/= 10 orelse GoodsInfo1#goods.subtype > 13 orelse GoodsInfo1#goods.subtype < 9 ->
			%%?DEBUG("mod_goods/check_merge/fail_5_1/",[]),
            {fail, 5};
		GoodsInfo2#goods.type =/= 10 orelse GoodsInfo2#goods.subtype > 13 orelse GoodsInfo2#goods.subtype < 9 ->
			%%?DEBUG("mod_goods/check_merge/fail_5_2/",[]),
            {fail, 5};
		GoodsInfo1#goods.step > GoodsInfo2#goods.step orelse 
													 (GoodsInfo1#goods.step ==  GoodsInfo2#goods.step andalso GoodsInfo1#goods.color > GoodsInfo2#goods.color) ->
			%%?DEBUG("mod_goods/check_merge/fail_5_3/g1/~p/g2/~p/step1/~p/step2/~p",[GoodsInfo1#goods.grade,GoodsInfo2#goods.grade,GoodsInfo1#goods.step,GoodsInfo2#goods.step]),
			{fail,5};
		%% 物品错误
		GoodsId1 =:= GoodsId2 ->
			{fail,6};
		%% 这个是任务给出的武器
		GoodsInfo1#goods.grade == 50 andalso GoodsInfo1#goods.spirit == 1 ->
			{fail,3};
		%% 这个是任务给出的武器
		GoodsInfo2#goods.grade == 50 andalso GoodsInfo2#goods.spirit == 1 ->
			{fail,3};
        true -> 

			{ok,GoodsInfo1,GoodsInfo2}
    end.

%%预览
check_equipsmelt(_Player,GoodsId,Type,_Cllist) when Type == 1 ->
	GoodsInfo = goods_util:get_goods(GoodsId),
	{ok,GoodsInfo,[],0,0,0,0,GoodsInfo#goods.bind};

check_equipsmelt(Player,GoodsId,Type,Cllist) when Type == 2 ->
	GoodsInfo = goods_util:get_goods(GoodsId),
	if
		%% 物品不存在
		is_record(GoodsInfo,goods) == false ->
			{fail,2};
		GoodsInfo#goods.num < 1 ->
			{fail,2};
		GoodsInfo#goods.player_id /= Player#player.id ->
			{fail,3};%%物品不属于你
		GoodsInfo#goods.location /= 4 ->
			{fail,4};%%物品位置不正确
		GoodsInfo#goods.color /= 4 ->
			{fail,5};%%物品类型错误
		GoodsInfo#goods.level < 60 orelse GoodsInfo#goods.level > 70 ->
			{fail,5};%%物品类型错误
		GoodsInfo#goods.goods_id div 1000 > 15 ->
			{fail,5};%%物品类型错误
		true ->
			case goods_util:list_handle(fun check_equipsmelt_list/2, [Player#player.id ,GoodsInfo#goods.bind,[]], Cllist) of
				{fail,Ret} ->
					{fail,Ret};
				{ok,[_,Bind,GoodsInfoList]} ->
					Cost = 1500000,
					if
						(Player#player.coin + Player#player.bcoin) < Cost  ->
							{fail,6};%%铜币不足
						true ->
							F = fun({Ginfo,N},[JPN,MYN,HFN]) ->
										if
											Ginfo#goods.goods_id == 21617 -> %%远古精魄
												[JPN + N,MYN,HFN];
											Ginfo#goods.goods_id == 21616 -> %%玄界秘银
												[JPN,MYN + N,HFN];
											Ginfo#goods.goods_id == 20406 -> %%炼化保护符
												[JPN,MYN, HFN+ N];
											true ->
												[JPN,MYN,HFN]
										end
								end,
							[JPn,MYn,HFn] = lists:foldl(F, [0,0,0], GoodsInfoList),
							if
								JPn < 4 orelse MYn < 4 ->
									{fail,7}; %% 物品数量不正确
								true ->
									{ok,GoodsInfo,GoodsInfoList,JPn,MYn,HFn,Cost,Bind}
							end
					end
			end
	end.
	
check_smelt(PlayerStatus,GoodsId,GoodsList) ->
	GoodsInfo = goods_util:get_goods(GoodsId),
	if
		%% 物品不存在
		is_record(GoodsInfo,goods) == false ->
			{fail,2};
		GoodsInfo#goods.num < 1 ->
			{fail,2};
		GoodsInfo#goods.player_id /= PlayerStatus#player.id ->
			{fail,3};%%物品不属于你
		GoodsInfo#goods.location /= 4 ->
			{fail,4};%%物品位置不正确
		GoodsInfo#goods.goods_id /= 21600 andalso GoodsInfo#goods.goods_id /= 21602 -> %% 玄界仙玉碎片
			{fail,5};%%物品不能淬炼
		true ->
			case goods_util:list_handle(fun check_smelt_list/2, [PlayerStatus#player.id ,GoodsInfo#goods.goods_id,[]], GoodsList) of
				{fail,Ret} ->
					{fail,Ret};
				{ok,[_,_,GoodsInfoList]} ->
					GoodsNum = goods_util:get_goods_totalnum(GoodsInfoList),
					Cost = 50 * GoodsNum,
					if
						(PlayerStatus#player.coin + PlayerStatus#player.bcoin) < Cost ->
							{fail,6};%%铜币不足
						true ->
							{ok,GoodsInfo,GoodsInfoList,Cost}
					end
			end
	end.

%%时装洗炼条件检查
check_fashion_wash(PlayerStatus,GoodsId,StoneId,StoneTypeId,Auto_purch) ->
	GoodsInfo = goods_util:get_goods(GoodsId),
	StoneInfo = goods_util:get_goods(StoneId),
	GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, StoneTypeId),
	Goods_attributList = goods_util:get_goods_attribute_list(PlayerStatus#player.id, GoodsId, 6),
	%%替换或维持原型判断
	if StoneId == 0 andalso StoneTypeId == 0 ->
		   if
			   %% 物品不存在
			   is_record(GoodsInfo, goods) =:= false ->
				   {fail, 2};
			   %% 物品数量不正确
			   GoodsInfo#goods.num < 1 ->
				   {fail, 2};
			   %% 物品不属于你所有
			   GoodsInfo#goods.player_id =/= PlayerStatus#player.id ->
				   {fail, 3};
			   %% 物品位置不正确
			   %%GoodsInfo#goods.location =/= 4 ->
				   %%{fail, 4};
			   %% 同种物品错误
			   GoodsId =:= StoneId ->
				   {fail,5};
			   true -> 
				   {ok,GoodsInfo,[],0}
		   end;
	   %%洗炼或预览
	   true ->
		   if
			   %% 物品不存在
			   is_record(GoodsInfo, goods) =:= false orelse (Auto_purch == 0 andalso is_record(StoneInfo,goods) =:= false) ->
				   {fail, 2};
			   %% 物品不存在
			   GoodsInfo#goods.num < 1 orelse (Auto_purch == 0 andalso StoneInfo#goods.num < 1)  ->
				   {fail, 2};
			   %% 物品不属于你所有
			   GoodsInfo#goods.player_id =/= PlayerStatus#player.id orelse (Auto_purch == 0 andalso StoneInfo#goods.player_id =/= PlayerStatus#player.id) ->
				   {fail, 3};
			   %% 物品位置不正确
			   %%GoodsInfo#goods.location =/= 4 orelse StoneInfo#goods.location =/= 4 ->
				%%   {fail, 4};
			   %% 同种物品错误
			   GoodsId =:= StoneId ->
				   {fail,5};
			   %% 元宝不够
			   Auto_purch == 1 andalso is_record(StoneInfo,goods) =:= false andalso PlayerStatus#player.gold < GoodsTypeInfo#ets_base_goods.price ->
				   {fail,8};
			   %%不能用此种类型的洗炼石(三种属性只能用)
			   (length(Goods_attributList) >= 3 andalso is_record(StoneInfo,goods) == false) orelse 
				   								  (length(Goods_attributList) >= 3 andalso is_record(StoneInfo,goods) == true andalso StoneInfo#goods.goods_id =/=  21801)->
			  	   {fail,9};
			   GoodsInfo#goods.type =/= 10 orelse (GoodsInfo#goods.subtype =/= 24 andalso GoodsInfo#goods.subtype =/= 26 andalso GoodsInfo#goods.subtype =/= 27) ->
				   {fail, 10};
			   true -> 
				   if Auto_purch == 1 andalso is_record(StoneInfo,goods) == false ->
						  {ok,GoodsInfo,StoneInfo,GoodsTypeInfo#ets_base_goods.price};
					  true ->
						  {ok,GoodsInfo,StoneInfo,0}
				   end
		   end
    end.	


%%检查紫戒指祝福条件
check_ring_bless(PlayerStatus, GoodsId, Oper, ClassOrMagicList) ->
	GoodsInfo = goods_util:get_goods(GoodsId),
	if
		%% 物品不存在
		is_record(GoodsInfo, goods) =:= false ->
			{fail,2};
		true ->
			MaxBlessLevel = data_ring_bless:get_max_ring_bless_level(GoodsInfo#goods.level),
			if
				%% 物品不存在
				GoodsInfo#goods.num < 1 ->
					{fail, 2};
				%% 物品不属于你所有
				GoodsInfo#goods.player_id =/= PlayerStatus#player.id ->
					{fail, 3};
				%% 物品位置不正确
				GoodsInfo#goods.location =/= 4 ->
					{fail, 4};
				%% 物品类型不正确
				GoodsInfo#goods.type =/= 10 andalso (GoodsInfo#goods.subtype =/= 20 orelse GoodsInfo#goods.subtype =/= 23) ->
					{fail, 5};
				%% 物品颜色类型不正确
				GoodsInfo#goods.color =/= 4 ->
					{fail, 6};
				%%超过最大等级祝福
				Oper ==  1 andalso GoodsInfo#goods.bless_level >=  MaxBlessLevel ->
					{fail, 7};
				true ->
					case goods_util:list_handle(fun check_ring_bless_num/2, [PlayerStatus#player.id , 0, []], ClassOrMagicList) of
						{fail, Res} ->
							{fail, Res};
						{ok, [_, TotalClassOrMagicNum, NewClassOrMagicInfoList]} ->
							NewBless = 
								case Oper of
									1 ->
										GoodsInfo#goods.bless_level+1;
									2 ->
										GoodsInfo#goods.bless_level
								end,
							[Cost, ClassOrMagicNum] = data_ring_bless:get_ring_bless_level_coin_glass(NewBless),
							if
								%% 玩家铜钱不足
								(PlayerStatus#player.coin + PlayerStatus#player.bcoin) < Cost ->
									{fail, 8};
								%% 祝福碎片不足,
								Oper == 1 andalso TotalClassOrMagicNum /= ClassOrMagicNum  ->
									%% 祝福碎片不足
									{fail, 9};
								Oper == 2 andalso TotalClassOrMagicNum < 1->
									%%遗忘符咒不足
									{fail, 10};
								true ->
									{ok, GoodsInfo, NewClassOrMagicInfoList, Cost}
							end
					end
			end
	end.

%% 处理紫戒指祝福
check_ring_bless_num({ClassOrMagicId, _ClassOrMagicIdNum}, [PlayerId, Num, L]) ->
	ClassOrMagicIdNum = abs(_ClassOrMagicIdNum),
    ClassOrMagicInfo = goods_util:get_goods(ClassOrMagicId),
    if
        %% 物品不存在
        is_record(ClassOrMagicInfo, goods) =:= false ->
            {fail, 2};
        %% 物品不属于你所有
        ClassOrMagicInfo#goods.player_id =/= PlayerId ->
            {fail, 3};
        %% 物品数量不正确
        ClassOrMagicInfo#goods.num < ClassOrMagicIdNum ->
            {fail, 11};
        true ->
            {ok, [PlayerId, Num+ClassOrMagicIdNum, [{ClassOrMagicInfo, ClassOrMagicIdNum}|L]]}
    end.

%%Goods_id 五彩仙玉 还是玄界仙玉
check_smelt_list(GoodsId,[PlayerId,Goods_id,L])->
	GoodsInfo = goods_util:get_goods(GoodsId),
	case Goods_id of
		21600  -> %%五彩仙玉碎片
			if
				%% 物品不存在 
				is_record(GoodsInfo,goods) == false ->
					{fail,2};
				GoodsInfo#goods.num < 1 ->
					{fail,2};
				GoodsInfo#goods.player_id /= PlayerId ->
					{fail,3};%%物品不属于你
				GoodsInfo#goods.location /= 4 ->
					{fail,4};%%物品位置不正确
				GoodsInfo#goods.level < 20 orelse GoodsInfo#goods.level >= 60  ->
					{fail,5};%%物品不能淬炼
				GoodsInfo#goods.color == 4 andalso GoodsInfo#goods.level < 30 ->
					{fail,5};%%物品不能淬炼
				GoodsInfo#goods.spirit > 0 ->
					{fail,5};%%物品不能淬炼
				GoodsInfo#goods.hole1_goods > 0 orelse GoodsInfo#goods.hole2_goods > 0 orelse GoodsInfo#goods.hole3_goods > 0 ->
					{fail,5};%%物品不能淬炼
				true ->
					case lists:member(GoodsInfo, L) of
						true ->
							%%重复物品
							{fail,2};
						false ->
							{ok,[PlayerId,Goods_id,[GoodsInfo|L]]}
					end
			end;
		21602 -> %%玄界仙玉碎片
			if
				is_record(GoodsInfo,goods) == false ->
					{fail,2};
				GoodsInfo#goods.num < 1 ->
					{fail,2};
				GoodsInfo#goods.player_id /= PlayerId ->
					{fail,3};%%物品不属于你
				GoodsInfo#goods.location /= 4 ->
					{fail,4};%%物品位置不正确
				GoodsInfo#goods.goods_id /= 21611 ->
					{fail,5};%%只能用补天精石
				true ->
					case lists:member(GoodsInfo, L) of
						true ->
							%%重复物品
							{fail,2};
						false ->
							{ok,[PlayerId,Goods_id,[GoodsInfo|L]]}
					end
			end;						
		_ ->
			{fail,0}
	end.

check_equipsmelt_list({GoodsId,Num},[PlayerId,Bind,L])->
	GoodsInfo = goods_util:get_goods(GoodsId),
	if
		%% 物品不存在
		is_record(GoodsInfo,goods) == false ->
			{fail,2};
		GoodsInfo#goods.num < Num ->
			{fail,2};
		GoodsInfo#goods.player_id /= PlayerId ->
			{fail,3};%%物品不属于你
		GoodsInfo#goods.location /= 4 ->
			{fail,4};%%物品位置不正确
		true ->
			case lists:member(GoodsInfo, L) of
				true ->
					%%重复物品
					{fail,2};
				false ->
					{ok,[PlayerId,GoodsInfo#goods.bind + Bind,[{GoodsInfo,Num}|L]]}
			end
	end.


%%装备附魔条件检查
check_equip_magic(PlayerStatus,GoodsId,MagicStoneId,MagicStoneTypeId,Auto_purch,Oper,PropsList) ->
	GoodsInfo = goods_util:get_goods(GoodsId),
	MagicStoneInfo = goods_util:get_goods(MagicStoneId),
	GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, MagicStoneTypeId),
	GoodsTypeInfo1 = goods_util:get_ets_info(?ETS_BASE_GOODS, 21026),
	%%判断是否有锁定属性
	[NewProps1,Num1] = 
		   if PropsList == [] ->
				  [[],0];
			  true ->
				  F = fun({Prop,Value},[NewProp,Num])->
							  [[{goods_util:get_attribute_name_by_id(Prop),Value} | NewProp],Num+1]
					  end,
				  lists:foldl(F, [[],0], PropsList)
		   end,
	TotalNum = goods_util:get_goods_num(PlayerStatus#player.id, 21026,4),
	%%替换或维持原形检查
	if 
		is_record(GoodsInfo, goods) =:= false ->
			{fail, 2};
			  %% 物品不存在
		GoodsInfo#goods.num < 1  ->
			{fail, 2};
			  %% 物品不属于你所有
		GoodsInfo#goods.player_id =/= PlayerStatus#player.id ->
			{fail, 3};		
		MagicStoneId == 0 andalso Oper == 0 ->
		   %% 物品不存在       
		   if 
			  %% 物品位置不正确
			  %%GoodsInfo#goods.location =/= 4 ->
				 %% {fail, 4};
			  %% 物品类型不正确
			  GoodsInfo#goods.type =/= 10 ->
				  {fail, 5};
			  GoodsInfo#goods.color == 0 ->
				  {fail, 5};
			  %% 物品错误
			  GoodsId =:= MagicStoneId ->
				  {fail,6};
			  true ->
				  {ok,GoodsInfo,MagicStoneInfo,NewProps1,Num1,0,0,0}
		   end;	
	   %%附魔或预览检查
	   true ->
		    Goods_attributList = goods_util:get_goods_attribute_list(GoodsInfo#goods.player_id, GoodsInfo#goods.id, 7),
			GoodsAttributeIdList = [{GoodsAttribute#goods_attribute.attribute_id,goods_util:get_attribute_value(GoodsAttribute)} ||GoodsAttribute <- Goods_attributList],
			F1 = fun({Prop2,Value2},[Total2,NewGoodsAttributeIdList]) ->
						 case lists:member({Prop2,Value2}, NewGoodsAttributeIdList) of
							 true ->
								 [Total2,lists:delete({Prop2,Value2}, NewGoodsAttributeIdList)];
							 false ->
								 [Total2+1,NewGoodsAttributeIdList]
						 end
				 end,
			%%Total2为客户端传过来的不合格的属性条数
			[Total2 ,_] = lists:foldl(F1, [0,GoodsAttributeIdList], PropsList),
		   %% 物品不存在
		   if is_record(GoodsInfo, goods) =:= false orelse (Auto_purch == 0 andalso (Oper == 1 andalso is_record(MagicStoneInfo,goods) =:= false)) ->
				  {fail, 2};
			  %% 物品不存在
			  GoodsInfo#goods.num < 1 orelse (Auto_purch == 0 andalso (Oper == 1 andalso MagicStoneInfo#goods.num < 1))  ->
				  {fail, 2};
			  %% 物品不属于你所有
			  GoodsInfo#goods.player_id =/= PlayerStatus#player.id orelse (Auto_purch == 0 andalso (Oper == 1 andalso MagicStoneInfo#goods.player_id =/= PlayerStatus#player.id)) ->
				  {fail, 3};
			  %% 物品位置不正确
			 %% GoodsInfo#goods.location =/= 4 orelse (Auto_purch == 0 andalso (Oper == 1 andalso MagicStoneInfo#goods.location =/= 4)) ->
				%%  {fail, 4};
			  %% 物品类型不正确
			  GoodsInfo#goods.type =/= 10 orelse  ((GoodsInfo#goods.subtype > 20 orelse GoodsInfo#goods.subtype < 9) andalso GoodsInfo#goods.subtype =/= 23)  ->
				  {fail, 5};
			  %% 物品错误
			  GoodsId =:= MagicStoneId ->
				  {fail,6};
			  %%装备颜色和附魔石颜色不匹配
			  Oper == 1 andalso (GoodsInfo#goods.color =/= MagicStoneInfo#goods.color) ->
				  {fail, 7};
			  GoodsInfo#goods.color == 0 ->
				  {fail, 5};
			  Oper == 1 andalso is_record(MagicStoneInfo, goods) =:= false andalso GoodsInfo#goods.color =< 2 ->
				  {fail, 2};
			  %%附魔锁不够
			  Oper == 1 andalso Auto_purch == 0 andalso TotalNum < Num1 ->
				  {fail, 11};
			  %%元宝不够
			  Oper == 1 andalso Auto_purch == 1 andalso is_record(MagicStoneInfo,goods) =:= false andalso PlayerStatus#player.gold < GoodsTypeInfo#ets_base_goods.price ->
				  {fail, 12};	
			  Oper == 1 andalso Auto_purch == 1 andalso TotalNum < Num1 andalso PlayerStatus#player.gold < GoodsTypeInfo1#ets_base_goods.price*(Num1-TotalNum) ->
				  {fail, 12};	
			  Oper == 1  andalso Auto_purch == 1 andalso is_record(MagicStoneInfo,goods) =:= false andalso TotalNum < Num1 andalso PlayerStatus#player.gold < (GoodsTypeInfo#ets_base_goods.price+GoodsTypeInfo1#ets_base_goods.price*(Num1-TotalNum)) ->
				  {fail, 12};	
			  Oper == 1  andalso Num1 > 0 andalso Total2 > 0 ->
				  {fail, 0};
			  true ->
				  {ok,GoodsInfo,MagicStoneInfo,NewProps1,Num1,GoodsTypeInfo#ets_base_goods.price,TotalNum,GoodsTypeInfo1#ets_base_goods.price}
		   end
	end.


check_change_mount_status(PlayerStatus,MountId) ->
	MountInfo = goods_util:get_goods(MountId),
	MaxMount = lib_mount:get_max_count(), 
	MountList = lib_mount:get_all_mount(PlayerStatus#player.id),
	Now = util:unixtime(),
	if
		is_record(MountInfo,goods) =:= false ->
			{fail,PlayerStatus,2};
		PlayerStatus#player.id =/= MountInfo#goods.player_id ->
			{fail,PlayerStatus,3};
		%%除了正常状态都不能上坐骑
		PlayerStatus#player.status =/= 0->
			{fail,PlayerStatus,4};
		%%押镖不能上坐骑
		PlayerStatus#player.carry_mark>0->
			{fail,PlayerStatus,5};
		length(MountList) >  MaxMount ->
			{fail,PlayerStatus,17};
		%%坐骑过期
		MountInfo#goods.expire_time /= 0 andalso MountInfo#goods.expire_time < Now ->
			NewPlayerStatus = notice_remove_mount(PlayerStatus,MountId,MountInfo),
			{fail,NewPlayerStatus,12};
		true ->
			{ok,PlayerStatus,MountInfo}
	end.

check_goods_mount(PlayerStatus,MountId) ->
	MountInfo = goods_util:get_goods(MountId),
	MaxMount = lib_mount:get_max_count(), 
	MountList = lib_mount:get_all_mount(PlayerStatus#player.id),
	Now = util:unixtime(),
	if
		is_record(MountInfo,goods) =:= false ->
			{fail,PlayerStatus,2};
		PlayerStatus#player.id =/= MountInfo#goods.player_id ->
			{fail,PlayerStatus,3};
		length(MountList) >=  MaxMount ->
			{fail,PlayerStatus,17};
		%%坐骑过期
		MountInfo#goods.expire_time /= 0 andalso MountInfo#goods.expire_time < Now ->
			NewPlayerStatus = notice_remove_mount(PlayerStatus,MountId,MountInfo),
			{fail,NewPlayerStatus,12};
		true ->
			{ok,PlayerStatus,MountInfo}
	end.


%%坐骑过期，通知玩家去掉
notice_remove_mount(PlayerStatus,MountId,GoodsInfo)->
	NewPlayer = 
		if PlayerStatus#player.mount =:= MountId->
			   {ok,MountPlayerStatus}=lib_goods:force_off_mount(PlayerStatus),
			   MountPlayerStatus;
		   true->PlayerStatus
		end,
	{ok, BinData} = pt_16:write(16009, [MountId,GoodsInfo#goods.goods_id]),
	lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send, BinData),
	NewPlayer#player.other#player_other.pid_goods!{'del_expire_goods',NewPlayer#player.id,GoodsInfo#goods.id,GoodsInfo#goods.goods_id,GoodsInfo#goods.color,GoodsInfo#goods.expire_time,1},
	NewPlayer.
	

notice_remove_mount_uid(PlayerId,MountId,GoodsTypeId)->
	case lib_player:get_online_info(PlayerId) of 
		[]->skip;
		PlayerStatus ->
			if PlayerStatus#player.mount >0->
			 	{ok,MountPlayerStatus}=lib_goods:force_off_mount(PlayerStatus),
			 	mod_player:save_online_diff(PlayerStatus,MountPlayerStatus);
			   true->skip
			end
	end,
	{ok, BinData} = pt_16:write(16009, [MountId,GoodsTypeId]),
	lib_send:send_to_uid(PlayerId, BinData).
