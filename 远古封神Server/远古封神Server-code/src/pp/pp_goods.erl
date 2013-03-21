%%%--------------------------------------
%%% @Module  : pp_goods
%%% @Author  : ygzj
%%% @Created : 2010.09.23
%%% @Description:  物品操作
%%%--------------------------------------

-module(pp_goods).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").
-include("guild_info.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

%%查询物品详细信息
handle(15000, PlayerStatus, [GoodsId, Location]) ->
    gen_server:cast(PlayerStatus#player.other#player_other.pid_goods, 
							{'info_15000', GoodsId, Location}),
    ok;

%%查询别人物品详细信息 此接口只查询在线物品信息 玩家离线不返回物品信息
handle(15001, PlayerStatus, [OtherPlayerId, GoodsId]) ->
    gen_server:cast(PlayerStatus#player.other#player_other.pid_goods, 
							{'info_15001', PlayerStatus#player.id, OtherPlayerId, GoodsId}),
    ok;	

%% 查看地上的掉落包
handle(15002, Player, DropId) ->
	ScenePid = mod_scene:get_scene_pid(Player#player.scene, undefined, undefined),
	PlayerList = [
		Player#player.id,
		DropId,
		Player#player.other#player_other.pid_team,
		Player#player.other#player_other.pid_send,
		Player#player.x,
		Player#player.y
	],
	gen_server:cast(ScenePid, {apply_asyn_cast, lib_goods_drop, get_drop_list, PlayerList});

%%查询别人物品详细信息  玩家离线返回物品信息
%%处理暂时只读数据表,优化可做缓存
handle(15003, PlayerStatus, [OtherPlayerId, GoodsId]) ->
    gen_server:cast(PlayerStatus#player.other#player_other.pid_goods, 
							{'info_15003', PlayerStatus#player.id, OtherPlayerId, GoodsId}),
    ok;	

%%查询类型物品的高级信息
handle(15004,PlayerStatus,[Goods_id]) ->
	gen_server:cast(PlayerStatus#player.other#player_other.pid_goods,
							{'typeinfo_15004',Goods_id}),
	ok;

%%极品装备预览
handle(15006,PlayerStatus,[GoodsId]) ->
	[NewGoodsInfo,AttributeList] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
													{'super_view',GoodsId}),
	{ok,BinData} = pt_15:write(15006,[NewGoodsInfo,AttributeList]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);

%%查询玩家某个位置的物品列表
handle(15010, PlayerStatus, Location) ->
	gen_server:cast(PlayerStatus#player.other#player_other.pid_goods, 
					{'list_15010', PlayerStatus, Location}),
	ok;

%%查询别人身上装备列表
handle(15011, PlayerStatus, OtherPlayerId) ->
   gen_server:cast(PlayerStatus#player.other#player_other.pid_goods, 
				   {'list_other_15011', OtherPlayerId}),
   ok;

%%获取要修理装备列表
handle(15012, PlayerStatus, mend_list) ->
   gen_server:cast(PlayerStatus#player.other#player_other.pid_goods, 
				   {'mend_list_15012', PlayerStatus#player.equip}),
   ok;

%% 取商店物品列表
handle(15013, PlayerStatus, [ShopType, ShopSubtype]) ->
%%	?DEBUG("ShopType:~p, ShopSubtype:~p", [ShopType, ShopSubtype]),
	IsFst_shop = mod_fst:is_fst_shop(ShopType),
	if  
		%%特惠区
		ShopType =:= 1 andalso ShopSubtype =:= 6 ->
			case misc:whereis_name({global, mod_shop_process}) of
				Pid when is_pid(Pid) ->				
					gen_server:cast(Pid,{'get_th_goods',PlayerStatus#player.id,PlayerStatus#player.career,PlayerStatus#player.sex,PlayerStatus#player.other#player_other.pid_send});
				_ ->
					skip
			end;
		IsFst_shop ->
			[IsFstAlive, Pid_fst_next] = 
				case lists:keysearch((PlayerStatus#player.scene)rem 10000, 1, PlayerStatus#player.other#player_other.pid_fst) of
					{value,{_SceneId, Fst_pid}} ->
						[misc:is_process_alive(Fst_pid), Fst_pid];
					_ ->
						{false,2} %%这个错误码需添加,  副本已消失
				end,
			{_Res,Ret,ShopList} = 
			case IsFstAlive of
				false ->
					{false,2,[]};%%副本已消失
				true ->
					case catch gen_server:call(Pid_fst_next, {open_fst_shop,PlayerStatus#player.id}) of
						{'EXIT',_Info} ->
							{fail,2,[]}; %%这个错误码需添加  副本已消失
						{fail,Code} ->
							{fail,Code,[]};
						{ok,SL} ->
							{ok,1,SL}
					end
			end,
			gen_server:cast(PlayerStatus#player.other#player_other.pid_goods,
							{'fst_shop_15013', ShopType, ShopSubtype, ShopList, Ret});
		true ->
    		gen_server:cast(PlayerStatus#player.other#player_other.pid_goods, 
					{'shop_15013', ShopType, ShopSubtype})
	end,
	ok;

%%Todo 以下call需要处理
%% 列出背包打造装备列表
handle(15014, PlayerStatus, [Position]) ->
   	gen_server:cast(PlayerStatus#player.other#player_other.pid_goods,
					 {'make_list_15014',Position}),
	ok;

%% 列出装备打造位置约定信息
handle(15015,PlayerStatus,[Position]) ->
	gen_server:cast(PlayerStatus#player.other#player_other.pid_goods,
					{'make_position_goods_15015',Position}),
	ok;


%% 列出物品cd列表
handle(15016, PlayerStatus, cd_list) ->
	gen_server:cast(PlayerStatus#player.other#player_other.pid_goods,
					{'cd_list_15016'}),
	ok;
	

%% 获取物品位置全部物品信息
handle(15017,PlayerStatus,[Location]) ->
	gen_server:cast(PlayerStatus#player.other#player_other.pid_goods,
					{'all_info_list_15017',
					 PlayerStatus#player.id,
					 Location}),
	ok;


%%购买物品
handle(15020, PlayerStatus, [GoodsTypeId, GoodsNum, ShopType ,ShopSubtype]) ->
	Is_operate_ok = tool:is_operate_ok(pp_15020,1),
	case Is_operate_ok of
    	true ->
			[NewPlayerStatus, Res, GoodsList] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'pay', PlayerStatus, GoodsTypeId, GoodsNum, ShopType ,ShopSubtype}),
			if
				%%增加特惠区购买记录
				ShopType =:= 1 andalso ShopSubtype =:= 6 andalso Res =:=1 ->
					case misc:whereis_name({global, mod_shop_process}) of
						Pid when is_pid(Pid) ->	
							gen_server:cast(Pid,{'th_sell_add',GoodsTypeId});
						_ ->
							skip
					end;
				true ->
					skip
			end;
		 _ ->
			[NewPlayerStatus, Res, GoodsList] = [PlayerStatus,0,[]]
	end,
	case Res of
		1 ->
			%商城购买的成就统计
			IsCount = lists:member({ShopType,ShopSubtype}, [{1,1}, {1,2}, {1,3}, {1,4}, {1,6}, {9,1}]),%%商城用元宝的地方，和购买时装
			case IsCount of
				true ->
					lib_achieve:check_achieve_finish(NewPlayerStatus#player.other#player_other.pid_send,
													 NewPlayerStatus#player.id, 505, [GoodsNum]);
				false ->
					skip
			end,
			%%活跃度判断
			case (IsCount =:= true andalso ShopSubtype =/= 6) %%去掉特惠区
				orelse (ShopType =:= 1 andalso ShopSubtype =:= 5) %%补上礼券区
				orelse (ShopType =:= 1 andalso ShopSubtype =:= 0) of%%不上快速购买
				true ->
					lib_task:event(buy_anything, null, PlayerStatus),
					lib_activity:update_activity_data(shop, PlayerStatus#player.other#player_other.pid, PlayerStatus#player.id, 1);%%添加玩家活跃度统计
				false ->
					skip
			end;
		_Other ->
			skip
	end,
	%%更新玩家的商城积分(独立协议)
%% 	if ShopType =:= 1 andalso ShopSubtype =:= 7 ->
%% 		   %%通知客户端(独立协议)
%% 		   ShopScore = lib_player:get_11_17_pay_gold(PlayerStatus#player.id),
%% 		   {ok,BinData13054} = pt_13:write(13054,ShopScore),
%% 		   lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData13054);
%% 	   true ->
%% 		   skip
%% 	end,
	{ok, BinData} = pt_15:write(15020, [Res, GoodsTypeId, GoodsNum, ShopType, NewPlayerStatus#player.coin, NewPlayerStatus#player.bcoin,NewPlayerStatus#player.cash, NewPlayerStatus#player.gold,NewPlayerStatus#player.arena_score, GoodsList]),
    lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, BinData),	
    {ok, NewPlayerStatus};

%%出售物品
handle(15021, PlayerStatus, [GoodsId, GoodsNum]) ->
    [NewPlayerStatus, Res] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'sell', PlayerStatus, GoodsId, GoodsNum}),
    {ok, BinData} = pt_15:write(15021, [Res, GoodsId, GoodsNum, NewPlayerStatus#player.coin,NewPlayerStatus#player.bcoin]),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
    {ok, NewPlayerStatus};

%%扩充背包
handle(15022, PlayerStatus, [Loc]) ->
    [NewPlayerStatus, Res] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'extend', Loc, PlayerStatus}),
	case Loc of
		1 -> New_num = NewPlayerStatus#player.cell_num;
		_ -> New_num = NewPlayerStatus#player.store_num
	end,
    {ok, BinData} = pt_15:write(15022, [Loc, Res, NewPlayerStatus#player.gold, New_num]),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
    {ok, NewPlayerStatus};

%%拆分物品
handle(15023,PlayerStatus,[GoodsId,Num,Pos]) ->
	[NewPlayerStatus,Res] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'destruct',PlayerStatus,GoodsId,Num,Pos}),
	{ok,BinData} = pt_15:write(15023,[Res]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	{ok,NewPlayerStatus};

%%装备物品
handle(15030, PlayerStatus, [GoodsId, Cell]) ->
	TempInfo = goods_util:get_goods(GoodsId),
	if
		is_record(TempInfo,goods) ->
			%%防止短时间发包
			DefCell = goods_util:get_equip_cell(PlayerStatus,TempInfo#goods.subtype),
			Is_operate_ok = tool:is_operate_ok(lists:concat([pp_15030_,DefCell]),1),
			if
				Is_operate_ok == true ->
					[NewPlayerStatus, Res, GoodsInfo, OldGoodsInfo, Effect, AchResult] = 
						gen_server:call(PlayerStatus#player.other#player_other.pid_goods, 
								{'equip', PlayerStatus, GoodsId, Cell}),
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
    				spawn(fun()->lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)end),
    				spawn(fun()->lib_player:send_player_attribute(NewPlayerStatus, 3)end),
					case is_record(GoodsInfo,goods) andalso Res =:= 1 of
						true ->
							%% 气血 改变广播
							Is_Equip = lists:member(GoodsInfo#goods.subtype, [9,10,11,12,13,19]) ,
							if
								NewPlayerStatus#player.hp_lim =/= PlayerStatus#player.hp_lim orelse Is_Equip ->
									{ok, BinData1} = pt_12:write(12012, [NewPlayerStatus#player.id, GoodsInfo#goods.goods_id, GoodsInfo#goods.subtype, NewPlayerStatus#player.hp, NewPlayerStatus#player.hp_lim]);
								true ->
									BinData1 = <<>>
							end,
							%% 强化效果广播
							Is_FB = lists:member(GoodsInfo#goods.subtype, [9,10,11,12,13]),
							Is_SP = GoodsInfo#goods.subtype == 27,
							Is_FByf = GoodsInfo#goods.subtype == 26,
							if
								Is_FB  ->
									{ok,BinData2} = pt_12:write(12032,[NewPlayerStatus#player.id,4,GoodsInfo#goods.stren]);
								Is_SP ->
									{ok,BinData2} = pt_12:write(12032,[NewPlayerStatus#player.id,3,GoodsInfo#goods.stren]);
								Is_FByf ->
									{ok,BinData2} = pt_12:write(12032,[NewPlayerStatus#player.id,6,GoodsInfo#goods.stren]);
								true ->
									BinData2 = <<>>
							end,
						
							%% 套装效果广播
							{ok,BinData3} = pt_12:write(12032,[NewPlayerStatus#player.id,2,NewPlayerStatus#player.other#player_other.suitid]),
						
							%% 全身强化效果
							{ok,BinData4} = pt_12:write(12032, [NewPlayerStatus#player.id,5,NewPlayerStatus#player.other#player_other.fullstren]),
							
							%%时装穿卸人物模形改变通知客户端
							if 
								GoodsInfo#goods.subtype =:= 24 ->
									[_Player_Id, _ShieldRole, _ShieldSkill, _ShieldRela, _ShieldTeam, _ShieldChat, _Music, _SoundEffect,Fasheffect, _Smelt] = lib_syssetting:query_player_sys_setting(PlayerStatus#player.id),
									case Fasheffect == 1 of
										true ->
											{ok, Bin12042} = pt_12:write(12042, [NewPlayerStatus#player.id, [{2, 0}]]);
										false ->
											if
												GoodsInfo#goods.icon > 0 -> 
													ShowFace = GoodsInfo#goods.icon;
												true ->
													ShowFace = GoodsInfo#goods.goods_id
											end,
											{ok, Bin12042} = pt_12:write(12042, [NewPlayerStatus#player.id, [{2,ShowFace}]])
									end;
								GoodsInfo#goods.subtype =:= 26 ->
											{ok, Bin12042} = pt_12:write(12042, [NewPlayerStatus#player.id, [{9,GoodsInfo#goods.goods_id}]]);
								GoodsInfo#goods.subtype =:= 27 ->
											{ok, Bin12042} = pt_12:write(12042, [NewPlayerStatus#player.id, [{10,GoodsInfo#goods.goods_id}]]);
								true ->
									Bin12042 = <<>>
							end,
							TotalBin = <<BinData1/binary,BinData2/binary,BinData3/binary,BinData4/binary,Bin12042/binary>> ,
							mod_scene_agent:send_to_area_scene(NewPlayerStatus#player.scene, NewPlayerStatus#player.x, NewPlayerStatus#player.y, TotalBin),
							%%做物品装备的成就反馈
							case AchResult of
								[] ->
									skip;
								_ ->
									lists:foreach(fun(Elem) ->
														  {AchNum, Num} = Elem,
														  lib_achieve:check_achieve_finish(NewPlayerStatus#player.other#player_other.pid_send,
																						   NewPlayerStatus#player.id, AchNum, [Num])
												  end, AchResult)
							end;
						_ ->
							skip
					end,
    				{ok, NewPlayerStatus};
				true ->
					{ok,PlayerStatus}
			end;
		true ->
			{ok,PlayerStatus}
	end;			
    

%%卸下装备
handle(15031, PlayerStatus, GoodsId) ->
    [NewPlayerStatus, Res, GoodsInfo] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'unequip', PlayerStatus, GoodsId}),
    case is_record(GoodsInfo, goods) of
         true ->
             TypeId = GoodsInfo#goods.goods_id,
             Cell = GoodsInfo#goods.cell;
         false ->
             TypeId = 0,
             Cell = 0
    end,
    {ok, BinData} = pt_15:write(15031, [Res, GoodsId, TypeId, Cell]),
    spawn(fun()->lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)end),
    spawn(fun()->lib_player:send_player_attribute(NewPlayerStatus, 3)end),
    case is_record(GoodsInfo,goods) andalso Res =:= 1 of
		true ->
			%% 气血 改变广播
			Is_Equip = lists:member(GoodsInfo#goods.subtype, [9,10,11,12,13,19]) ,
			if
				NewPlayerStatus#player.hp_lim =/= PlayerStatus#player.hp_lim orelse Is_Equip ->
					{ok, BinData1} = pt_12:write(12013, [NewPlayerStatus#player.id, GoodsInfo#goods.goods_id, GoodsInfo#goods.subtype, NewPlayerStatus#player.hp, NewPlayerStatus#player.hp_lim]);
				true ->
					BinData1 = <<>>
			end,
			%% 法宝强化效果广播
			Is_FB = lists:member(GoodsInfo#goods.subtype, [9,10,11,12,13]),
			Is_SP = GoodsInfo#goods.subtype == 27,
			Is_FByf = GoodsInfo#goods.subtype == 26,
			if
				Is_FB  ->
					{ok,BinData2} = pt_12:write(12032,[NewPlayerStatus#player.id,4,0]);
				Is_SP ->
					{ok,BinData2} = pt_12:write(12032,[NewPlayerStatus#player.id,3,0]);
				Is_FByf ->
					{ok,BinData2} = pt_12:write(12032,[NewPlayerStatus#player.id,6,0]);
				true ->
					BinData2 = <<>>
			end,
			%% 套装效果广播

		  	{ok,BinData3} = pt_12:write(12032,[NewPlayerStatus#player.id,2,NewPlayerStatus#player.other#player_other.suitid]),
	
			%% 全身强化效果
			{ok,BinData4} = pt_12:write(12032, [NewPlayerStatus#player.id,5,NewPlayerStatus#player.other#player_other.fullstren]),
			%%时装穿卸人物模形改变通知客户端
			if
				GoodsInfo#goods.subtype =:= 24 ->
					{ok, Bin12042} = pt_12:write(12042, [NewPlayerStatus#player.id, [{2, 0}]]);
				GoodsInfo#goods.subtype =:= 26 ->
					{ok, Bin12042} = pt_12:write(12042, [NewPlayerStatus#player.id, [{9, 0}]]);
				GoodsInfo#goods.subtype =:= 27 ->
					{ok, Bin12042} = pt_12:write(12042, [NewPlayerStatus#player.id, [{10, 0}]]);
				true ->
					Bin12042 = <<>>
			end,
			TotalBin = <<BinData1/binary,BinData2/binary,BinData3/binary,BinData4/binary,Bin12042/binary>> ,
			mod_scene_agent:send_to_area_scene(NewPlayerStatus#player.scene, NewPlayerStatus#player.x, NewPlayerStatus#player.y, TotalBin);
		_ ->
			skip
	end,
    {ok, NewPlayerStatus};

%%修理装备
handle(15033, PlayerStatus, GoodsId) ->
    [NewPlayerStatus, Res, GoodsInfo] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'mend', PlayerStatus, GoodsId}),
    {ok, BinData} = pt_15:write(15033, [Res, GoodsId, NewPlayerStatus#player.coin,NewPlayerStatus#player.bcoin]),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
    %% 气血有改变则广播
    case is_record(GoodsInfo, goods) of
        true when NewPlayerStatus#player.hp_lim =/= PlayerStatus#player.hp_lim
                    orelse GoodsInfo#goods.subtype =:= 19 ->

            {ok, BinData1} = pt_12:write(12012, [NewPlayerStatus#player.id, GoodsInfo#goods.goods_id, NewPlayerStatus#player.hp, NewPlayerStatus#player.hp_lim]),
            mod_scene_agent:send_to_area_scene(NewPlayerStatus#player.scene, NewPlayerStatus#player.x, NewPlayerStatus#player.y, BinData1);
        _ ->
            skip
    end,
    {ok, NewPlayerStatus};

%% 商城搜索
handle(15034, PlayerStatus, [Name]) ->
	GoodsList = goods_util:search_goods(Name),
	Code =
		case length(GoodsList) of
			0 -> 0;
			_ -> 1
		end,
	{ok,BinData} = pt_15:write(15034,[Code,GoodsList]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
	

%%拖动背包物品
handle(15040, PlayerStatus, [GoodsId, OldCell, NewCell]) ->
	gen_server:cast(PlayerStatus#player.other#player_other.pid_goods, 
					{'drag_15040',
					PlayerStatus#player.cell_num,
					GoodsId, OldCell, NewCell}),
	ok;
   
%%物品存入仓库
handle(15041, PlayerStatus, [GoodsId, GoodsNum]) ->
    gen_server:cast(PlayerStatus#player.other#player_other.pid_goods, 
					{'movein_bag_15041',
					PlayerStatus#player.store_num,
					GoodsId, GoodsNum}),
	ok;


%%从仓库取出物品
handle(15042, PlayerStatus, [GoodsId, GoodsNum]) ->
    gen_server:cast(PlayerStatus#player.other#player_other.pid_goods, 
					{'moveout_bag_15042',
					 GoodsId, GoodsNum}),
	ok;

%%物品从临时矿包取出
handle(15043, PlayerStatus,[GoodsId,GoodsNum]) ->
	gen_server:cast(PlayerStatus#player.other#player_other.pid_goods,
					{'moveout_orebag_15043',
					 GoodsId, GoodsNum}),
	ok;

%%从农场背包取出物品
handle(15044,PlayerStatus,[GoodsInfoList]) ->
	gen_server:cast(PlayerStatus#player.other#player_other.pid_goods,
					{'moveout_plantbag_15044',
					GoodsInfoList}),
	ok;
 
%% 使用物品
handle(15050, PlayerStatus, [GoodsId, GoodsNum]) ->
    %% 战斗昏迷状态下不能使用物品
    case PlayerStatus#player.other#player_other.battle_limit /= 2 of
        true ->
			%%获取玩家的goods_buff,
			GoodsBuffs = lib_goods:get_player_goodsbuffs(),
            case gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'use', PlayerStatus, GoodsId, GoodsNum, GoodsBuffs},8000) of
                %% 竞技场血药不提示
				[_NewPlayerStatus, 73, _GoodsTypeId, _NewNum, _NewGoodsBuffs] ->
					skip;
				[NewPlayerStatus, Res, GoodsTypeId, NewNum, NewGoodsBuffs] ->
					%%更新玩家的新goods_buff
					NewStatus1 = lib_goods:update_player_goodsbuffs(NewPlayerStatus, NewGoodsBuffs),
                    NewStatus2 = lib_peach:use_goods_peach(Res, NewStatus1, GoodsTypeId),%%%使用蟠桃的判断					
					%%做物品使用的成就统计
					lib_achieve_outline:check_ach_goods_use(NewStatus2, Res, GoodsTypeId),
					%% 使用远古大转盘的判断(记录删除)
					lib_anniversary:check_bigwheel_use(Res, NewStatus2, GoodsTypeId),
                    {ok, BinData} = pt_15:write(15050, [Res, GoodsId, GoodsTypeId, NewNum, NewStatus2#player.hp, NewStatus2#player.mp]),
                    lib_send:send_to_sid(NewStatus2#player.other#player_other.pid_send, BinData),
                    {ok, NewStatus2};
                _Err ->
                    skip
            end;
        false ->
            skip
    end;

%%丢弃物品
handle(15051, PlayerStatus, [GoodsId, GoodsNum]) ->
    gen_server:cast(PlayerStatus#player.other#player_other.pid_goods, 
					{'throw_15051', PlayerStatus, GoodsId, GoodsNum}),
	ok;

%% 整理背包
handle(15052, PlayerStatus, clean) ->
	%% 按物品类型ID排序 
	case lib_trade:get_trade_limit(trade_limit) of
		true ->%%在交易之后3秒内不能整理
			gen_server:cast(PlayerStatus#player.other#player_other.pid_goods, 
							{'clean_15052', 
							 PlayerStatus#player.cell_num});
		false ->
			skip
	end,
	ok;
    
%% 拣取地上掉落包的物品
handle(15053, Player, [DropId, GoodsTypeId]) ->
	Msg = {
		'drop_choose', 
		Player#player.id, 
		Player#player.other#player_other.pid_team, 
		Player#player.scene, 
		DropId, GoodsTypeId, 
		[Player#player.nickname, Player#player.realm, Player#player.career, Player#player.sex]
	},
	gen_server:cast(Player#player.other#player_other.pid_goods, Msg);

%%节日道具使用
handle(15054,Player,[GoodsId,GoodsNum,Nickname]) ->
	gen_server:cast(Player#player.other#player_other.pid_goods,
					{'usefestivaltool_15054',Player,GoodsId,GoodsNum,Nickname}),
	
	ok;

%% 屏幕弹出框
handle(15056,Player,[Type,PlayerId,Msg]) ->
	gen_server:cast(Player#player.other#player_other.pid_goods,
					{'alert_win_15056',Player#player.nickname,Type,PlayerId,Msg}),
	ok;

%% 装备精炼
handle(15057,Player,[Gid,StoneList]) ->
	[NewPlayer,Res] = gen_server:call(Player#player.other#player_other.pid_goods,
					{'refine',Player,Gid,StoneList}),
	{ok,BinData} = pt_15:write(15057,[Res,NewPlayer#player.coin,NewPlayer#player.bcoin]),
	lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send,BinData),
	{ok,NewPlayer};

%% 装备分解/预览
handle(15058,Player,[Type,GoodsList]) ->
	[NewPlayer,Res,Cost,Glist]=gen_server:call(Player#player.other#player_other.pid_goods,
					{'idecompose',Player,Type,GoodsList}),
	{ok,BinData} = pt_15:write(15058,[Res,Type,Cost,Glist]),
	lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send,BinData),
	
	case Type =:= 1 andalso Res =:= 1 of
		true ->%%成就系统做装备分解的统计
			Num = length(GoodsList),
			lib_achieve:check_achieve_finish(Player#player.other#player_other.pid_send,Player#player.id, 509, [Num]);
		false ->
			skip
	end,
			
	{ok,NewPlayer};

%% 材料合成
handle(15059,Player,[Mid,N]) ->
	[NewPlayer,Res,Snum,Fnum] = gen_server:call(Player#player.other#player_other.pid_goods,{'icompose',Player,Mid,N}),
	case Res of
		1 ->%%做材料合成的成就统计
			IsStone = lists:member(Mid, [26,27,28,29,30,31,32,33]),%%判断是否 石头配方
			case IsStone of
				true ->
					lib_achieve:check_achieve_finish(Player#player.other#player_other.pid_send,
													 Player#player.id, 506, [1]);
				false ->
					skip
			end;
		_ ->
			skip
	end,
	{ok,BinData} = pt_15:write(15059,[Res,Snum,Fnum]),
	lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send,BinData),		
	{ok,NewPlayer};

%%紫装融合预览
handle(15060,PlayerStatus,[Gid1,Gid2,Gid3]) ->
	gen_server:cast(PlayerStatus#player.other#player_other.pid_goods,{'suit_merge_preview',PlayerStatus,Gid1,Gid2,Gid3}),
	ok;

%% 紫装融合
handle(15061,PlayerStatus,[Gid1,Gid2,Gid3]) ->
	[NewPlayerStatus,Res] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods,{'suit_merge',PlayerStatus,Gid1,Gid2,Gid3}),
	{ok,BinData} = pt_15:write(15061,[Res]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	{ok,NewPlayerStatus};

%% 装备强化
handle(15062, PlayerStatus, [GoodsId, StoneId, RuneId1,N1,RuneId2,N2,RuneId3,N3,RuneId4,N4,Protect,StoneTypeId,Auto_purch]) ->
    [NewPlayerStatus, Res, NewStrengthen,NewStoneNum,StrenFail,NewN1,NewN2,NewN3,NewN4] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'strengthen', PlayerStatus, GoodsId, StoneId, RuneId1,N1,RuneId2,N2,RuneId3,N3,RuneId4,N4,Protect,StoneTypeId,Auto_purch}),
    {ok, BinData} = pt_15:write(15062, [Res, GoodsId, NewStrengthen, NewPlayerStatus#player.coin,NewPlayerStatus#player.bcoin,NewStoneNum,StrenFail,RuneId1,NewN1,RuneId2,NewN2,RuneId3,NewN3,RuneId4,NewN4]),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
    {ok, NewPlayerStatus};

%% 装备打孔
handle(15063, PlayerStatus, [GoodsId, StoneId, StoneTypeId, Auto_purch]) ->
    [NewPlayerStatus, Res, NewHole, NewStoneNum] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'hole', PlayerStatus, GoodsId, StoneId, StoneTypeId, Auto_purch}),
    {ok, BinData} = pt_15:write(15063, [Res, GoodsId, NewHole, NewStoneNum, NewPlayerStatus#player.coin,NewPlayerStatus#player.bcoin]),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
    {ok, NewPlayerStatus};

%% 宝石合成
handle(15064, PlayerStatus, [RuneId, StoneTypeId, RuneTypeId, Auto_purch, StoneList]) ->
    [NewPlayerStatus, Res, NewGoodsTypeId] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'compose', PlayerStatus, RuneId, StoneTypeId, RuneTypeId, Auto_purch, StoneList}),
    case Res of
		1 ->%%做材料合成的成就统计
			lib_achieve:check_achieve_finish(NewPlayerStatus#player.other#player_other.pid_send,
											 NewPlayerStatus#player.id, 506, [1]),
			case lists:member(NewGoodsTypeId, ?TASK_11) of
				true ->
					%%氏族祝福任务判断
					GWParam = {11, 1},
					lib_gwish_interface:check_player_gwish(PlayerStatus#player.other#player_other.pid, GWParam);
				false ->
					skip
			end;
		_ ->
			skip
	end,
	{ok, BinData} = pt_15:write(15064, [Res, NewGoodsTypeId]),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
    {ok, NewPlayerStatus};

%% 宝石镶嵌
handle(15065, PlayerStatus, [GoodsId, StoneId, StoneTypeId, Auto_purch, RuneList]) ->
    [NewPlayerStatus, Res, GoodsInfo] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'inlay', PlayerStatus, GoodsId, StoneId, StoneTypeId, Auto_purch, RuneList}),
    {ok, BinData} = pt_15:write(15065, [Res, GoodsId, NewPlayerStatus#player.coin,NewPlayerStatus#player.bcoin]),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	if GoodsInfo#goods.location == 1 ->
			  lib_player:send_player_attribute(NewPlayerStatus,2);
		  true ->
			  skip
	   end,
    {ok, NewPlayerStatus};

%% 宝石拆除
handle(15066, PlayerStatus, [GoodsId,StoneId,StoneTypeId,Auto_purch,RuneList]) ->
    [NewPlayerStatus, Res,NewStoneId] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'backout', PlayerStatus, GoodsId,StoneId,StoneTypeId,Auto_purch,RuneList}),
    {ok, BinData} = pt_15:write(15066, [Res, GoodsId, NewPlayerStatus#player.coin,NewPlayerStatus#player.bcoin,NewStoneId]),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
    {ok, NewPlayerStatus};

%% 洗附加属性
handle(15067, PlayerStatus, [GoodsId, RuneId]) ->
    [NewPlayerStatus, Res, NewRuneNum] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'wash', PlayerStatus, GoodsId, RuneId}),
    {ok, BinData} = pt_15:write(15067, [Res, GoodsId, NewRuneNum, NewPlayerStatus#player.coin,NewPlayerStatus#player.bcoin]),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
    {ok, NewPlayerStatus};

%% 鉴定属性
handle(15068, PlayerStatus,[GoodsId,StoneId,StoneTypeId,Auto_purch]) ->
	[NewPlayerStatus,Res,StoneNum,AttributeList] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods,{'identify',PlayerStatus,GoodsId,StoneId,StoneTypeId,Auto_purch}),
	{ok,BinData} = pt_15:write(15068,[Res,GoodsId,StoneNum,AttributeList]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	{ok,NewPlayerStatus};

%%法宝修炼
handle(15069,PlayerStatus,[GoodsId,Type]) ->
	[NewPlayerStatus,Res] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods,{'practise',PlayerStatus,GoodsId,Type}),
	{ok,BinData} = pt_15:write(15069,[Res,NewPlayerStatus#player.spirit]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	{ok,NewPlayerStatus};

%%法宝融合
handle(15070,PlayerStatus,[GoodsId1,GoodsId2]) ->
	[NewPlayerStatus,Res] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods,{'merge',PlayerStatus,GoodsId1,GoodsId2}),
	{ok,BinData} = pt_15:write(15070,[Res]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	{ok,NewPlayerStatus};

%% ------------------------------------
%% 15071 批量购买商店物品
%% ------------------------------------
handle(15071, PlayerStatus, [ShopType, ShopSubType, GoodsList]) ->
	%%添加商店子类型的强制性判断
	case ShopSubType =:= 1 orelse ShopSubType =:= 2 of
		false ->
			Result = 0,
			MoneyType = 0,
			Money = 0,
			NewPlayerStatus = PlayerStatus;
		true ->
			case length(GoodsList) =:= 0 of 
				true ->%%长度为零，不用操作，直接返回
					[Result, MoneyType, Money, NewPlayerStatus] = [0, 0, 0, PlayerStatus];
				false ->
					[Result, MoneyType, Money, NewPlayerStatus] = 
						gen_server:call(PlayerStatus#player.other#player_other.pid_goods, 
										{'buy_multi', PlayerStatus, ShopType, ShopSubType, GoodsList})
			end
	end,
	{ok, BinData} = pt_15:write(15071, [Result, MoneyType, Money]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	lib_player:send_player_attribute(NewPlayerStatus, 2),
	{ok,NewPlayerStatus};
	
%% ------------------------------------
%% 15072 批量出售物品
%% ------------------------------------
handle(15072, PlayerStatus, [GoodsList]) ->
	case length(GoodsList) =:= 0 of
		true ->%%长度为零，不用操作，直接返回
			[Result, MoneyType, Money, NewPlayerStatus] = [0, 1, PlayerStatus#player.coin, PlayerStatus];
		false ->
			[Result, MoneyType, Money, NewPlayerStatus] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
																		  {'sell_multi', PlayerStatus, GoodsList})
	end,
	{ok, BinData} = pt_15:write(15072, [Result, MoneyType, Money]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	lib_player:send_player_attribute(NewPlayerStatus, 2),
	{ok,NewPlayerStatus};

%% %% -------------------------------------------------------------
%% %% 15073 查询物品详细信息(拍卖或者交易的时候用到的查看物品信息)
%% %% -------------------------------------------------------------
%% handle(15073, PlayerStatus, [GoodsId]) ->
%% 	?DEBUG("pp_goods 15073 get goods information:[~p]", [GoodsId]),
%% 	[GoodsInfo, SuitNum, AttributeList] = mod_player:get_goods_info_by_gid(PlayerStatus, {'info', GoodsId}),
%%     {ok, BinData} = pt_15:write(15073, [GoodsInfo, SuitNum, AttributeList]),
%% 	%%?DEBUG("pt_15/15000/attributelist/~p",[AttributeList]),
%%     lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%%物品融合预览
handle(15074,PlayerStatus,[GoodsId1,GoodsId2]) ->
	[GoodsInfo,SuitNum,AttributeList] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
														{'merge_preview',PlayerStatus,GoodsId1,GoodsId2}),
	{ok,BinData} = pt_15:write(15074,[GoodsInfo,SuitNum,AttributeList]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);	

%%神装炼化
handle(15075,Player,[GoodsId,Type,Cllist]) ->
	[Res,NewPlayer,[GoodsInfo,SuitNum,AttributeList]] = gen_server:call(Player#player.other#player_other.pid_goods,{'70equipsmelt',Player,GoodsId,Type,Cllist}),
	{ok,BinData} = pt_15:write(15075,[Res,NewPlayer#player.coin,NewPlayer#player.bcoin,Type,[GoodsInfo,SuitNum,AttributeList]]),
	lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send,BinData),
	{ok,NewPlayer};


%%装备评价
handle(15080,PlayerStatus,[GoodsId]) ->
	[Res, Score, Status] = lib_goods:give_score(PlayerStatus, GoodsId),
	{ok,BinData} = pt_15:write(15080,[Res, GoodsId, Score, Status#player.coin, Status#player.bcoin]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	{ok,Status};	

%%60 70 套紫装淬炼
handle(15081,PlayerStatus,[GoodsId,GoodsList]) ->
	[Ret,Repair,NewPlayer] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
													{'smelt',PlayerStatus,GoodsId,GoodsList}),
	{ok,BinData} = pt_15:write(15081,[Ret,Repair,NewPlayer#player.coin,NewPlayer#player.bcoin]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	{ok,NewPlayer};

%%各种卡号使用
handle(15090,PlayerStatus,[CardString]) ->
	[Res,NewStatus]=gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
							{'use_ygfs_card',PlayerStatus,CardString}),
	{ok,BinData} = pt_15:write(15090,[Res]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	{ok,NewStatus};

%%各种卡及首冲礼包、VIP礼包的领取情况
handle(15091,PlayerStatus,[]) ->
	Result = lib_goods:get_all_use_card(PlayerStatus#player.id),
	{ok,BinData} = pt_15:write(15091,Result),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);

%% 活动礼包领取情况
handle(15092,PlayerStatus,[Type]) ->
	[Data, GState] = lib_activities:get_may_day_info(PlayerStatus, Type),
%% 	?DEBUG("PlayerId:~p, Data:~p, GState:~p, Type:~p", [PlayerStatus#player.id, Data, GState,Type]),
	{ok,BinData} = pt_15:write(15092,[Type, Data, GState]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	ok;

%% 领取活动礼包
handle(15093,PlayerStatus,[Type]) ->
	{_Rest,Code} = lib_activities:get_may_day(PlayerStatus, Type),
%% 	?DEBUG("PlayerId:~p, Code:~p, Type:~p", [PlayerStatus#player.id, Code,Type]),
	{ok,BinData} = pt_15:write(15093,[Type,Code]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	ok;

%% 兑换物品
handle(15094 ,PlayerStatus,[Type]) ->
	{_,Code} = lib_activities:exchange_goods(PlayerStatus,Type),
	{ok,BinData} = pt_15:write(15094,[Code]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);

%% 临时活动
handle(15095,PlayerStatus,[Type,GoodsList]) ->
	[Code,Score] = lib_activities:tmp_activity(PlayerStatus,Type,GoodsList),
	{ok,BinData} = pt_15:write(15095,[Code,Type,Score]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);

%%领取5级强化护腕
handle(15096,PlayerStatus,[_R]) ->
	[Code] = lib_activities:give_stren5_hw(PlayerStatus),
	{ok,BinData} = pt_15:write(15096,[Code]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	ok;
%%领取5级强化护腕 预览
handle(15097,PlayerStatus,[_R]) ->
	[GoodsInfo ,SuitId,AttributeList] = lib_activities:give_stren5_hw_preview(PlayerStatus) ,
	{ok,BinData} = pt_15:write(15097,[GoodsInfo ,SuitId,AttributeList]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	ok;

%% 充值祈福 
handle(15098,PlayerStatus,[Type]) ->
	case Type of
		1 -> 
			[Code,Mult,CostGold] = lib_pay_pray:get_pay_pray_info(PlayerStatus),
			NewPlayer = PlayerStatus;
		_ -> 
			[Code,Mult,CostGold,NewPlayer] = lib_pay_pray:get_pay_pray(PlayerStatus)
	end,
	NewMult = round(Mult * 10),
	{ok,BinData} = pt_15:write(15098, [Type,Code,NewMult,CostGold]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	{ok,NewPlayer};

%%查询vip背包使用权限
handle(15100,PlayerStatus,[])->
	{NewPlayerStatus,_,Result} = lib_vip:get_vip_award(remote,PlayerStatus),
	case Result of
		false->
			{ok,BinData} = pt_15:write(15100,[0]);
		true->
			{ok,BinData} = pt_15:write(15100,[1])
	end,
	lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send,BinData),
	{ok,NewPlayerStatus};

%%兑换魅力称号
handle(15120,PlayerStatus,[TitleId])->
	case lib_love:convert_charm(PlayerStatus,TitleId) of
		{error,Res}->
			{ok,BinData} = pt_15:write(15120,[Res, TitleId]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);
		{_,NewPlayerStatus}->
			{ok,BinData} = pt_15:write(15120,[1, TitleId]),
			lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send,BinData),
			spawn(fun()->lib_player:send_player_attribute(NewPlayerStatus,1)end),
			{ok,NewPlayerStatus}
	end; 

%%时装洗炼
handle(15130,PlayerStatus,[GoodsId,StoneId,Oper,StoneTypeId,Auto_purch]) ->
	[Result,GoodsId,Is_wash,Cost,Coin,Bcion,Goods_attributList,NewPlayerStatus] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
													{'fashion_wash',PlayerStatus,GoodsId,StoneId,Oper,StoneTypeId,Auto_purch}),
	{ok,BinData} = pt_15:write(15130,[Result,GoodsId,Is_wash,Cost,Coin,Bcion,Goods_attributList]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	{ok,NewPlayerStatus};

%%Oper替换新的洗炼属性(1)或维持原因属性(0)
handle(15131,PlayerStatus,[GoodsId,Oper]) ->
	[Result,GoodsId,Goods_attributList,NewPlayerStatus] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
													{'fashion_oper',PlayerStatus,GoodsId,Oper}),
	{ok,BinData} = pt_15:write(15131,[Result, GoodsId, Goods_attributList]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	{ok,NewPlayerStatus};


%%紫戒指祝福,GoodsId(紫戒指) ClassOrMagicId(是祝福碎片或是遗忘符咒),Oper(1为祝福,2为遗弃)
handle(15132,PlayerStatus,[GoodsId, Oper, ClassOrMagicList]) ->
	[NewPlayerStatus, Result] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
													{'ring_bless',PlayerStatus,GoodsId, Oper, ClassOrMagicList}),
	{ok,BinData} = pt_15:write(15132,[Result,GoodsId,NewPlayerStatus#player.coin,NewPlayerStatus#player.bcoin,Oper]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	{ok,NewPlayerStatus};

%%装备附魔 Oper 1为附魔,2为预览
handle(15133,PlayerStatus,[GoodsId,MagicStoneId,MagicStoneTypeId,Auto_purch,Oper,PropsList]) ->
	[Result,GoodsId,Is_magic,Cost,Coin,Bcion,Goods_attributList,GoodsLevel,NewPlayerStatus] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
													{'equip_magic',PlayerStatus,GoodsId,MagicStoneId,MagicStoneTypeId,Auto_purch,Oper,PropsList}),
	{ok,BinData} = pt_15:write(15133,[Result,GoodsId,Is_magic,Cost,Coin,Bcion,Goods_attributList,GoodsLevel]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	{ok,NewPlayerStatus};

%%Oper替换新的洗炼属性(1)或维持原因属性(0)
handle(15134,PlayerStatus,[GoodsId,Oper]) ->
	[Result,GoodsId, NewPlayerStatus] = gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
													{'magic_oper',PlayerStatus,GoodsId,Oper}),
	{ok,BinData} = pt_15:write(15134,[Result, GoodsId]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
	{ok,NewPlayerStatus};

%% ------------------------------------
%% 15142 获取衣橱已激活的图鉴数据
%% ------------------------------------
handle(15142, PlayerStatus, []) ->
	gen_server:cast(PlayerStatus#player.other#player_other.pid_goods,
					{'GET_PLAYER_WARDROBE',PlayerStatus#player.id,PlayerStatus#player.other#player_other.pid_send}),
	ok;
	
%% ------------------------------------
%% 15143 时装换装请求
%% ------------------------------------
handle(15143, PlayerStatus, [Type, FashionId]) ->
	case tool:is_operate_ok(pp_15143, 1) of
		true ->
			{Res, NPlayerStatus} = gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'WARDROBE_DRESS', PlayerStatus, Type, FashionId}),
			case Res of
				1 ->
					{ok,BinData} = pt_15:write(15143,[Res]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
					[_Player_Id, _ShieldRole, _ShieldSkill, _ShieldRela, _ShieldTeam, _ShieldChat, _Music, _SoundEffect,Fasheffect, _Smelt] = 
						lib_syssetting:query_player_sys_setting(PlayerStatus#player.id),
					%%判断时装是否有外显
					case Fasheffect == 1 of
						true ->
							{ok, Bin12042} = pt_12:write(12042, [NPlayerStatus#player.id, [{Type+7, 0}]]),
							%%采用广播通知，附近玩家都不能看到
							mod_scene_agent:send_to_area_scene(NPlayerStatus#player.scene, NPlayerStatus#player.x, NPlayerStatus#player.y, Bin12042);
						false ->
							{ok, Bin12042} = pt_12:write(12042, [NPlayerStatus#player.id, [{Type+7, FashionId}]]),
							%%采用广播通知，附近玩家都能看到
							mod_scene_agent:send_to_area_scene(NPlayerStatus#player.scene, NPlayerStatus#player.x, NPlayerStatus#player.y, Bin12042)
					end,
					{ok, change_ets_table, NPlayerStatus};
				_Other ->
					{ok,BinData} = pt_15:write(15143,[Res]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
					ok
			end;
		false ->%%亲，点太快了，歇一会吧
			{ok,BinData} = pt_15:write(15143,[8]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData),
			ok
	end;


	

%%开服充值反馈
handle(15200,PlayerStatus,[Type,GoodsType]) ->
	[Code,Gold,Time] = 
	if
		Type == 1 ->
			lib_payrew:get_payrew_info(PlayerStatus);
		true ->
			lib_payrew:get_payrew(PlayerStatus, GoodsType)
	end,
	{ok,BinData} = pt_15:write(15200,[Code,Type,Gold,Time]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData);

handle(_Cmd, _Status, _Data) ->
    ?DEBUG("pp_goods no match", []),
    {error, "pp_goods no match"}.
