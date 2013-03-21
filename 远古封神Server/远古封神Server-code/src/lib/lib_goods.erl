%%%--------------------------------------
%%% @Module  : lib_goods
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description : 物品信息
%%%--------------------------------------
-module(lib_goods).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("guild_info.hrl").
-export(
    [
        add_goods/1,								%%添加物品，根据类型信息添加一个新物品（一般内部调用）
		add_goods/2,								%%添加物品，包含附加属性
		add_attribule_by_type/1,					%%添加物品的默认附加属性（一般内部调用）
        add_goods_attribute/4,						%%根据属性列表添加物品附加属性（一般内部调用）
		add_goods_attribute/5,						%%根据属性列表添加物品附加属性（一般内部调用）
        mod_goods_attribute/2,						%%修改物品属性
        del_goods_attribute/1,						%%删除物品属性
        del_goods_attribute/3,						%%删除物品属性
		del_goods_attribute/4,						%%删除物品属性
        pay_goods/4,								%%购买物品调用的接口
		multi_pay_goods/3,							%%批量购买
        sell_goods/5,								%%出售物品
        equip_goods/5,								%%穿上装备
        unequip_goods/3,							%%卸下装备
        drag_goods/4,								%%拖动物品
		refresh_new_goods/3,						%%刷新新物品
        use_goods/5,								%%使用物品
        delete_more/3,								%%删除同类型物品的其中一个
        delete_one/3,								%%删除指定物品
        delete_type_goods/2,						%%删除一类物品
        movein_bag/5,								%%放入背包
        moveout_bag/4,								%%移出背包
		moveout_orebag/4,							%%移出彩石背包
		moveout_plantbag_list/2,					%%移出农场背包
        extend/3,									%%扩展背包
        mend_goods/3,								%%修理装备（暂时废弃）
        clean_bag/2,								%%整理背包
		give_goods_bt/2,							%%可设置绑定和交易状态
        give_goods/2,								%%发送物品
		give_task_goods/2,							%%发送任务物品
		give_ore_goods/2,							%%发送矿石物品
		give_pet_batt_skill_goods/2,				%%发送灵兽技能书物品
		give_plant_goods/2,							%%发送农场物品
        add_goods_base/3,							%%添加一个基础物品（主要）
        add_goods_base/4,							%%添加一个基础物品
        add_goods_base/5,							%%添加一个基础物品
		add_equip_base/4,							%%添加一件基础装备（区分于物品，只是装备）
		add_task_goods_base/5,						%%添加任务基础物品
        update_overlap_goods/2,						%%跟新叠加物品
        add_overlap_goods/2,						%%添加可叠加物品
        add_nonlap_goods/2,							%%添加不可叠加物品
        attrit_equip/2,								%%装备磨损 （暂废弃）
        cost_money/4,								%%【扣除游戏内的货币（游戏内必须调用此接口）】
		cost_score/4,								%%积分消耗
		add_money/4,								%%【添加游戏内的货币（游戏内必须调用此接口）】
        delete_role/1,								%%删除角色，（一般情况下不使用）
		mod_goods_attribute_by_name/2,				%%由[name,value]的形式修改装备属性
		update_goods_buff_action/2,					%% 更新物品buff信息
		update_goods_buff/2,						%%更新物品buff信息
		update_goods_buff/3,						%%更新物品buff信息
		do_logout/1,								%%玩家退出处理
		destruct/4,									%%装备拆分
		cd_check/2,									%%物品cd检查
		change_mount_status/2,						%%改变坐骑状态
		get_on_mount/2,								%%上坐骑
		force_off_mount/1,							%%下坐骑
		force_off_mount_for_battle/1,				%% 下坐骑（战斗用）
		delete_goods/1,								%%删除物品
		change_goods_num/2,							%%改变物品数量
        goods_find/2,								%%查看玩家背包是否存在指定ID物品
		delete_all_box_goods/1,						%%删除诛邪仓库物品
		delete_all_box_goods_attribute/1,			%%删除诛邪仓库物品属性
		ets_delete_box_goods_attribute/1,			%%删除诛邪仓库物品属性
		add_new_goods_by_mail/6,					%%邮件发送新物品
		is_enough_backpack_cell/3,					%%判断是否有足够的背包格子
		delete_task_more/2,							%%删除多个任务物品
		delete_plant_more/2,						%%删除多个农场物品
		delete_task_one/2,							%%删除一个任务物品
		mod_goods_otherdata/2,						%%修改物品的other_data属性
		cd_add/2,									%%添加物品cd
		cd_add_ets/2,								%%添加物品内存cd
		get_goods_info_from_db/2,					%%从数据库获取物品信息
		active_ygfs_card/2,							%%卡类激活
		give_score/2,								%%装备评分
		bind_goods/1,								%%物品绑定
		check_goods_diff/1,							%%物品对比				
		goods_buff_trans_to_proto/1,				%%物品buff协议转换
	    get_all_use_card/1,							%%获取一个玩家所有已用过的卡类型
		get_player_goodsbuffs/0,					%%获取玩家的buff内容
		update_player_goodsbuffs/2,					%%更新玩家的buff内容
		get_buff_goodstypeid/2,						%%有物品Id转化成buffID
		get_buff_goods_ids/1,						%%由buffID获取需要删除的物品Id
		get_hero_card_list/0,						%%封神贴id列表
		get_dungeon_card_list/0,					%%副本令id列表
		get_player_stren_eff/1,						%%获取玩家强化效果值
		get_player_fbyf_stren/1,					%%获取法宝时装强化等级
		get_player_spyf_stren/1,					%% 获取挂饰强化等级
		change_goods_mount/2                    %%将物品转换为坐骑
	]).


%% 保存物品信息
%% @spec set_goods_info(GoodsId, Field, Data) -> ok
%set_goods_info(GoodsId, Field, Data) ->
%    db_agent:set_goods_info(GoodsId, Field, Data),
%    ok.


%%注意！！不能外部调用，添加新类型物品应用 add_goods_base
%% 添加新物品信息 
%% @spec add_goods(PlayerId, Cell, Num, Location, GoodsTypeInfo) -> GoodsInfo
add_goods(GoodsInfo) ->
    add_goods(GoodsInfo,[]).
%%AttributeList = {attribute_id,identify}
add_goods(GoodsInfo,AttributeList) ->
	case db_agent:add_goods(GoodsInfo) of
		{mongo,Ret} ->
			NewGoodsInfo = GoodsInfo#goods{id = Ret};
		_Ret ->
    		NewGoodsInfo = goods_util:get_add_goods(GoodsInfo#goods.player_id,
											GoodsInfo#goods.goods_id,
											GoodsInfo#goods.location,
											GoodsInfo#goods.cell,
											GoodsInfo#goods.num)
	end,
    case is_record(NewGoodsInfo, goods) of
        true ->
            ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
			case length(AttributeList) > 0 of
				true ->
					%%添加固定附加属性
					add_attribute_by_attribute_id(NewGoodsInfo,AttributeList);
				false ->
					%%添加随机附加属性
            		add_attribule_by_type(NewGoodsInfo)
			end;
        false -> skip
    end,
    NewGoodsInfo.

%% 添加附加属性 %%1单属性，2双属性-1,3双属性-2，4双属性-3,5饰品属性1，6饰品属性2,7饰品属性3，8饰品属性4，9饰品属性5，10饰品属性全,11紫装属性,12新戒指属性1,13新戒指属性2, 14饰品护符属性  24新时装  ,26法宝时装，27饰品时装   
add_attribule_by_type(GoodsInfo) ->
     if is_record(GoodsInfo,goods) andalso GoodsInfo#goods.color > 0 andalso GoodsInfo#goods.color =< 4 andalso GoodsInfo#goods.type =:= 10->
			%%属性附加类型
			Attribute_type=
			if
				%%如果是法宝 
				GoodsInfo#goods.subtype >= 9 andalso GoodsInfo#goods.subtype =< 13 ->
					if
						%%如果是绿装
						GoodsInfo#goods.color =:= 1 ->
							1;
						%%非绿装
						true ->
							R1=util:rand(1,100),
							%%固定双属性的法宝
							IsDouble = lists:member(GoodsInfo#goods.goods_id, [11005,12005,13005,14005,15005,19036,19037,19038,19039,19040]),
							if	
								IsDouble =:= true ->
									2;
								R1 > 70 ->
									2;
								true ->
									1
							end
					end;
				%%饰品
				GoodsInfo#goods.subtype =:= 21 ->
					Is_spt = lists:member(GoodsInfo#goods.goods_id, lists:seq(10053, 10062)),
					if
						Is_spt ->
							10;
						GoodsInfo#goods.color =:= 1 ->
							util:rand(5,9);
						true ->
							util:rand(5,10)
					end;
				%%戒指 20 新戒指 23
				GoodsInfo#goods.subtype =:= 20 ->
					if GoodsInfo#goods.color =:= 1 ->
						   1;
					   true ->
							util:rand(2,3)
					end;
				%%新戒指
				GoodsInfo#goods.subtype =:= 23 ->
					if GoodsInfo#goods.color =:= 1 ->
						    12;
					   true ->
							util:rand(12,13)
					end;
				%%新时装
				GoodsInfo#goods.subtype =:= 24 ->
					24;
				%%法宝时装
				GoodsInfo#goods.subtype =:= 26 ->
					26;
				%%饰品时装
				GoodsInfo#goods.subtype =:= 27 ->
					27;
				%%其他防具
				true ->
					if
						GoodsInfo#goods.color =:= 1 ->
							R2 = util:rand(1,100),
							if
								%%新手礼包物品给双属性
								GoodsInfo#goods.goods_id div 1000 =:= 17 ->
									2;
								R2 > 66 ->
									2;
								true ->
									1
							end;
						%%紫装
						GoodsInfo#goods.color =:= 4 ->
							11;
						true ->
							util:rand(2,4)
					end	
			end,
            Pattern = #ets_base_goods_add_attribute{ goods_id=GoodsInfo#goods.goods_id,color=GoodsInfo#goods.color,attribute_type=Attribute_type, _='_' },
            %%获取某goods_id 物品添加的所有属性 类型值
            AttributeList = goods_util:get_ets_list(?ETS_BASE_GOODS_ADD_ATTRIBUTE, Pattern),
			if
				length(AttributeList) > 0 ->
					Length = length(AttributeList),
					case Attribute_type of
						1 ->
							%%单属性有两种
							R=util:rand(1,100),							
							if 
								R > 50 andalso Length =:= 2 ->
									Add_attributelist = lists:sublist(AttributeList,1,1);
								R =< 50 andalso Length =:= 2 ->
									Add_attributelist =lists:sublist(AttributeList,2,1);
								true ->
									Add_attributelist=AttributeList								
							end;			
						 B when B =<4  ->
							 %%双属性
							 	Add_attributelist=lists:sublist(AttributeList,1,2);							
						_  ->
							%%饰品属性 && 全属性
							Add_attributelist = AttributeList

					end,
					%%紫色饰品特殊护符属性
					if
						GoodsInfo#goods.subtype =:= 21 andalso GoodsInfo#goods.color == 4 ->
							Sp_attributeList = [parse_sp_base_goods_attribute_info(GoodsInfo,22),
									 			parse_sp_base_goods_attribute_info(GoodsInfo,21),
									 			parse_sp_base_goods_attribute_info(GoodsInfo,23)];
						true ->
							Sp_attributeList = []
					end,
            		[add_base_attribute(GoodsInfo, AttributeInfo) || AttributeInfo <- (Add_attributelist ++ Sp_attributeList)];
				true ->skip
			end;
 			%%添加职业附加属性
         true -> skip
     end,
     ok.

%%添加固定附加属性 AttidList = [id,id]
add_attribute_by_attribute_id(GoodsInfo,AttidList) ->
	F = fun({Attid,Identify}) ->
			if
				%%特殊百分比属性ID 
				Attid == 21  ->
					AttributeInfo = parse_sp_base_goods_attribute_info(GoodsInfo,21);
				Attid == 22  ->
					AttributeInfo = parse_sp_base_goods_attribute_info(GoodsInfo,22);
				Attid == 23  ->
					AttributeInfo = parse_sp_base_goods_attribute_info(GoodsInfo,23);
				true ->
					if
						%%金色饰品精炼到紫色饰品，根据color 和 attribute_id 会匹配到多条记录，要根据属性的个数判断是单抗还是全抗去取值
						GoodsInfo#goods.subtype == 21 ->
							case length(AttidList) of
								5 -> %%单抗
									MS = ets:fun2ms(fun(T) when T#ets_base_goods_add_attribute.goods_id == GoodsInfo#goods.goods_id andalso 
																	T#ets_base_goods_add_attribute.color == GoodsInfo#goods.color andalso
																		T#ets_base_goods_add_attribute.attribute_id == Attid andalso 
																			T#ets_base_goods_add_attribute.attribute_type /= 10  -> 
												T 
										end);
								9 ->%%全抗
									MS = ets:fun2ms(fun(T) when T#ets_base_goods_add_attribute.goods_id == GoodsInfo#goods.goods_id andalso 
																	T#ets_base_goods_add_attribute.color == GoodsInfo#goods.color andalso
																		T#ets_base_goods_add_attribute.attribute_id == Attid andalso 
																			T#ets_base_goods_add_attribute.attribute_type == 10  -> 
												T 
										end);
								_ ->
									MS = ets:fun2ms(fun(T) when T#ets_base_goods_add_attribute.goods_id == GoodsInfo#goods.goods_id andalso 
																	T#ets_base_goods_add_attribute.color == GoodsInfo#goods.color andalso
																		T#ets_base_goods_add_attribute.attribute_id == Attid  -> 
												T 
										end)
							end,
							AttributeInfoList = ets:select(?ETS_BASE_GOODS_ADD_ATTRIBUTE, MS),
							case length(AttributeInfoList) > 0 of
								true ->
									AttributeInfo = hd(AttributeInfoList);
								false ->
									AttributeInfo = []
							end;
						true ->
							Pattern = #ets_base_goods_add_attribute{ goods_id=GoodsInfo#goods.goods_id,color=GoodsInfo#goods.color,attribute_id = Attid, _='_' },
    						AttributeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS_ADD_ATTRIBUTE, Pattern)
					end
			end,
			if
				is_record(AttributeInfo,ets_base_goods_add_attribute) ->
					NewAttributeInfo = AttributeInfo#ets_base_goods_add_attribute{identify = Identify},
					add_base_attribute(GoodsInfo,NewAttributeInfo);
				true ->
					skip
			end
		end,
	lists:foreach(F, AttidList).
			
%% 添加附加属性
add_base_attribute(GoodsInfo, BaseAttributeInfo) ->
     %%类型值的效果值
     Effect = goods_util:get_add_attribute_by_type(BaseAttributeInfo),
	 Status =
		 case BaseAttributeInfo#ets_base_goods_add_attribute.identify of
			 0 -> 1; %% 0 不需要鉴定 = 1已鉴定
			 1 -> 0; %% 1 要鉴定 = 0 没鉴定
			 _ -> 0
		 end,
	 Effect2 = [Status|Effect],
     %%将效果添加到物品
	 AttributeType = 
		 if GoodsInfo#goods.subtype =:= 24 -> 6;%%时装
			GoodsInfo#goods.subtype =:= 26 -> 6;%%法宝时装
			GoodsInfo#goods.subtype =:= 27 -> 6;%%饰品时装
			true -> 1
		 end,		 
     add_goods_attribute(GoodsInfo, AttributeType, BaseAttributeInfo#ets_base_goods_add_attribute.attribute_id, Effect2 ,BaseAttributeInfo#ets_base_goods_add_attribute.value_type).

%%关键函数！！
%% 把属性添加到goods_attribute 表 。添加的属性类型 1附加 2强化+7加成 3镶嵌4防具强化抗性加成5强化+8攻击加成 6时装洗炼属性7附魔属性
%% 添加装备属性valueType 0 值 1 百分比
%%Effect情况	1：Effect长度为13 2：Effect长度为15用于附加属性 3：effect长度18镶嵌
%%Effect效果可额外增加，判断长度即可。
add_goods_attribute(GoodsInfo, AttributeType, AttributeId, Effect) ->
	add_goods_attribute(GoodsInfo,AttributeType,AttributeId,Effect,0),
	ok.
add_goods_attribute(GoodsInfo,AttributeType,AttributeId,Effect,ValueType) ->
	case length(Effect) of
		13 ->
			%%常用添加属性
			[Hp, Mp, MaxAtt,MinAtt, Def, Hit, Dodge, Crit, Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil] = Effect,
    		case db_agent:add_goods_attribute(GoodsInfo, AttributeType,ValueType,AttributeId, Hp, Mp, MaxAtt,MinAtt, Def, Hit, Dodge, Crit, Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil) of
				{mongo,GoodsAttribute,Ret} ->
					AttributeInfo = GoodsAttribute#goods_attribute{id=Ret};
				_Ret ->
    				AttributeInfo = goods_util:get_add_goods_attribute(GoodsInfo#goods.player_id, GoodsInfo#goods.id, AttributeType, AttributeId)
			end;
		16 ->
			%%附加属性
			%%[forza, agile, wit,physique, crit, dodge,Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil,mult_att,hp_limit,Anti_rift]
			[Status,Hp,Mp,Forza,Agile,Wit,Physique,Crit,Dodge,Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil,Attack,Anti_rift] = Effect,
			case db_agent:add_goods_attribute(GoodsInfo,AttributeType,ValueType,AttributeId,Status,Hp,Mp,Forza,Agile,Wit,Physique,Crit,Dodge,Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil,Attack,Anti_rift) of
				{mongo,GoodsAttribute,Ret} ->
					AttributeInfo = GoodsAttribute#goods_attribute{id=Ret};
				_Ret ->
    				AttributeInfo = goods_util:get_add_goods_attribute(GoodsInfo#goods.player_id, GoodsInfo#goods.id, AttributeType, AttributeId)
			end;
		18 ->
			%%镶嵌属性
			[Goods_id,Hp, Mp, MaxAtt,MinAtt, Def, Hit, Dodge, Crit,Physique, Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil,Forza,Agile,Wit] = Effect,
			case db_agent:add_goods_attribute(GoodsInfo,AttributeType,ValueType,AttributeId,Goods_id,Hp, Mp, MaxAtt,MinAtt, Def, Hit, Dodge, Crit,Physique, Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil,Forza,Agile,Wit) of
				{mongo,GoodsAttribute,Ret} ->
					AttributeInfo = GoodsAttribute#goods_attribute{id=Ret};
				_Ret ->
    				AttributeInfo = goods_util:get_add_goods_attribute(GoodsInfo#goods.player_id, GoodsInfo#goods.id, AttributeType, AttributeId)
			end			
	end,  
   
%%	?DEBUG("lib_goods/add_goods_attribute/attributeinfo/~p",[AttributeInfo]),
    if is_record(AttributeInfo, goods_attribute) ->		   
            %%回写到ets，同步装备属性
            ets:insert(?ETS_GOODS_ATTRIBUTE, AttributeInfo);
        true -> skip
    end,
	ok.

%% 修改装备属性
mod_goods_attribute(AttributeInfo, Effect) ->
    [Hp, Mp, MaxAtt, MinAtt, Def, Hit, Dodge, Crit, Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil] = Effect,
    db_agent:mod_goods_attribute(AttributeInfo, Hp, Mp, MaxAtt, MinAtt, Def, Hit, Dodge, Crit, Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil),
    NewAttributeInfo = AttributeInfo#goods_attribute{ hp=Hp, mp=Mp, max_attack=MaxAtt, min_attack = MinAtt, def=Def, hit=Hit, dodge=Dodge, crit=Crit, anti_wind=Anti_wind,anti_fire=Anti_fire,anti_water=Anti_water,anti_thunder=Anti_thunder ,anti_soil=Anti_soil},
    ets:insert(?ETS_GOODS_ATTRIBUTE, NewAttributeInfo),
    ok.

%% 由[name,value]的形式修改装备属性
mod_goods_attribute_by_name(AttributeInfo,[Attribute_name,Value]) ->	
	NewAttributeInfo =
	case Attribute_name of
		dodge -> AttributeInfo#goods_attribute{dodge= Value};
		crit -> AttributeInfo#goods_attribute{crit = Value};
		physique -> AttributeInfo#goods_attribute{physique = Value};
		forza -> AttributeInfo#goods_attribute{forza = Value};
		agile -> AttributeInfo#goods_attribute{agile = Value};
		wit -> AttributeInfo#goods_attribute{wit = Value};
		_ ->AttributeInfo
	end,
	db_agent:mod_goods_attribute(NewAttributeInfo),
	ets:insert(?ETS_GOODS_ATTRIBUTE, NewAttributeInfo),
    ok.

%% 删除装备属性
del_goods_attribute(PlayerId, GoodsId, AttributeType) ->
    db_agent:del_goods_attribute(PlayerId, GoodsId, AttributeType),
    Pattern = #goods_attribute{ player_id=PlayerId, gid=GoodsId, attribute_type=AttributeType, _='_'},
    ets:match_delete(?ETS_GOODS_ATTRIBUTE, Pattern),
    ok.
del_goods_attribute(PlayerId,GoodsId,AttributeType,AttributeId) ->
	db_agent:del_goods_attribute(PlayerId, GoodsId, AttributeType,AttributeId),
    Pattern = #goods_attribute{ player_id=PlayerId, gid=GoodsId, attribute_type=AttributeType,attribute_id= AttributeId, _='_'},
    ets:match_delete(?ETS_GOODS_ATTRIBUTE, Pattern),
    ok.
del_goods_attribute(Id) ->
    db_agent:del_goods_attribute(Id),
    ets:delete(?ETS_GOODS_ATTRIBUTE, Id),
    ok.

%%紫色饰品的特殊附加属性 21 攻击百分比 ;22 气血百分比 ;23 抗性穿透
parse_sp_base_goods_attribute_info(GoodsInfo,AttributeId) ->
	Step = goods_util:level_to_step(GoodsInfo#goods.level),
	case Step of
		4 -> 
			case AttributeId of
				21  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 1,value_type = 1,identify = 1};
				22  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 1,value_type = 1,identify = 1};
				23  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 1,value_type = 0,identify = 1}
			end;
		5 ->
			case AttributeId of
				21  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 1,value_type = 1,identify = 1};
				22  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 1,value_type = 1,identify = 1};
				23  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 2,value_type = 0,identify = 1}
			end;
		6 ->
			case AttributeId of
				21  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 1,value_type = 1,identify = 1};
				22  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 2,value_type = 1,identify = 1};
				23  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 2,value_type = 0,identify = 1}
			end;
		7 ->
			case AttributeId of
				21  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 1,value_type = 1,identify = 1};
				22  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 2,value_type = 1,identify = 1};
				23  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 3,value_type = 0,identify = 1}
			end;
		8 ->
			case AttributeId of
				21  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 2,value_type = 1,identify = 1};
				22  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 2,value_type = 1,identify = 1};
				23  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 4,value_type = 0,identify = 1}
			end;
		9 ->
			case AttributeId of
				21  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 2,value_type = 1,identify = 1};
				22  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 2,value_type = 1,identify = 1};
				23  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 5,value_type = 0,identify = 1}
			end;
		10 ->
			case AttributeId of
				21  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 2,value_type = 1,identify = 1};
				22  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 2,value_type = 1,identify = 1};
				23  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 6,value_type = 0,identify = 1}
			end;
		_ ->
			case AttributeId of
				21  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 0,value_type = 1,identify = 1};
				22  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 0,value_type = 1,identify = 1};
				23  ->
					#ets_base_goods_add_attribute{attribute_id = AttributeId,value = 0,value_type = 0,identify = 1}
			end		
	end.
			
%% 修改物品other_data数据 
mod_goods_otherdata(GoodsInfo,String) ->	
	case is_record(GoodsInfo,goods) of
		true ->
			NewString = 
				if
					is_list(String) ->
						String;
					true ->
						util:to_list(String)
				end,
			NewGoodsInfo=GoodsInfo#goods{other_data = list_to_binary(NewString)},
			ets:insert(?ETS_GOODS_ONLINE,NewGoodsInfo),
			spawn(fun()->db_agent:mod_goods_otherdata(NewGoodsInfo#goods.id,NewString)end),
			NewGoodsInfo;				
		false ->
			GoodsInfo
	end.

%% 购买物品
%% @spec pay_goods(GoodsStatus, GoodsTypeInfo, GoodsNum) -> ok | Error
pay_goods(GoodsStatus, GoodsTypeInfo, GoodsList, GoodsNum) ->
    GoodsInfo = goods_util:get_new_goods(GoodsTypeInfo),
	add_goods_base(GoodsStatus, GoodsTypeInfo, GoodsNum, GoodsInfo, GoodsList).

%% 购买多个物品
%% @spec multi_pay_goods(GoodsStatus, GoodsTypeInfo, GoodsNum) -> ok | Error
multi_pay_goods(GoodsStatus, GoodsTypeInfo, GoodsNum) ->
	GoodsInfo = goods_util:get_new_goods(GoodsTypeInfo),
	add_goods_base(GoodsStatus, GoodsTypeInfo, GoodsNum, GoodsInfo).
%% 出售物品
%% @spec sell_goods(GoodsInfo, GoodsNum) -> ok | Error
sell_goods(PlayerStatus, Status, GoodsInfo, GoodsNum, SellType) ->
	if 

		%%在NPC商城里出售绑定的物品
		SellType == 1 andalso GoodsInfo#goods.bind == 2 ->
			PriceType = coin,
			Amount = 1 * GoodsNum;
		true ->%%其他情况
			PriceType = coin,
			Amount = GoodsInfo#goods.sell_price * GoodsNum
	end,
	NewPlayerStatus = lib_goods:add_money(PlayerStatus,Amount,PriceType,1504),
    %% 删除物品
    {ok, NewStatus, _} = delete_one(Status, GoodsInfo, GoodsNum),
    {ok, NewPlayerStatus, NewStatus}.


%%装备物品
%% @spec equip_goods(PlayerId, GoodsInfo) -> {ok, 1, Effect} | Error
equip_goods(PlayerStatus, Status, GoodsInfo, Location, Cell) ->
    OldGoodsInfo = goods_util:get_goods_by_cell(PlayerStatus#player.id, Location, Cell),
	[Wq, Yf, Fbyf, Spyf, Zq] = Status#goods_status.equip_current,
	case is_record(GoodsInfo,goods) of
		true ->
    		if  GoodsInfo#goods.subtype >= 9 andalso GoodsInfo#goods.subtype < 14 ->%%武器法宝
            		CurrentEquip = [GoodsInfo#goods.goods_id, Yf, Fbyf, Spyf, Zq];
        		GoodsInfo#goods.subtype =:= 24 ->%%时装
					%%如果时装有使用过变化效果的，拿icon字段显示
					if
						GoodsInfo#goods.icon > 0 ->
							CurrentEquip = [Wq, GoodsInfo#goods.icon, Fbyf, Spyf, Zq];
						true ->
            				CurrentEquip = [Wq, GoodsInfo#goods.goods_id, Fbyf, Spyf, Zq]
					end;
				GoodsInfo#goods.subtype =:= 26 ->%%法宝时装
						CurrentEquip = [Wq,Yf, GoodsInfo#goods.goods_id, Spyf, Zq];
				GoodsInfo#goods.subtype =:= 27 ->%%饰品时装
						CurrentEquip = [Wq,Yf, Fbyf, GoodsInfo#goods.goods_id, Zq];
        		true ->
            		CurrentEquip = [Wq, Yf, Fbyf, Spyf, Zq]
    		end;
		false ->
			CurrentEquip = [Wq, Yf, Fbyf, Spyf, Zq]
	end,
    case is_record(OldGoodsInfo, goods) of
       %% 存在已装备的物品，则替换
        true ->
			%%空格
			NullCells = lists:sort([GoodsInfo#goods.cell | Status#goods_status.null_cells]),
			[OldGoodsCell|NullCells2] = NullCells,
			%%卸下物品 原来已经装备的物品 OldGoodsInfo ,OldGoodsCell为原来已经装备的物品卸下的位置
			NewOldGoodsInfo = change_goods_cell(OldGoodsInfo, 4, OldGoodsCell),
            %%装上需要的物品
            NewGoodsInfo = change_goods_cell(GoodsInfo, Location, Cell),
            %%如果是套装的要处理
            EquipSuit = goods_util:change_equip_suit(Status#goods_status.equip_suit, OldGoodsInfo#goods.suit_id, GoodsInfo#goods.suit_id),
            %%空格子为NullCells2
            NewStatus = Status#goods_status{ null_cells=NullCells2, equip_suit=EquipSuit ,equip_current = CurrentEquip};
        %% 不存在
        false ->
            NewOldGoodsInfo = OldGoodsInfo,
            %%直接装上吧
            NewGoodsInfo = change_goods_cell(GoodsInfo, Location, Cell),
            %%装上就多了一个空间了
            NullCells = lists:sort([GoodsInfo#goods.cell | Status#goods_status.null_cells]),
            EquipSuit = goods_util:change_equip_suit(Status#goods_status.equip_suit, 0, GoodsInfo#goods.suit_id),
            NewStatus = Status#goods_status{ null_cells=NullCells, equip_suit=EquipSuit ,equip_current = CurrentEquip}
    end,
    %%如果穿上后绑定
	BindGoodsInfo =
		case GoodsInfo#goods.bind =:= 1 of
			true -> bind_goods(NewGoodsInfo);
			false -> NewGoodsInfo
		end,
	%%玩家重新穿上装备，更新衣橱的数据
	{IsNeedF5, NewGoodsInfo2} = lib_wardrobe:equip_check_wardrobe(BindGoodsInfo, PlayerStatus#player.id, PlayerStatus#player.sex, goods, PlayerStatus#player.nickname),
	%%检查是否需要主推刷新衣橱数据
	lib_wardrobe:check_need_f5_wardrobe(self(), PlayerStatus#player.id, PlayerStatus#player.other#player_other.pid_send, IsNeedF5, NewGoodsInfo2, NewStatus),
    %% 人物属性重新计算
    {ok, NewPlayerStatus, NewStatus2} = goods_util:count_role_equip_attribute(PlayerStatus, NewStatus, NewGoodsInfo2),	
	
	SuitID = goods_util:is_full_suit(EquipSuit),

	StrenEff = get_player_stren_eff(NewPlayerStatus#player.id),
	FbyfStren = get_player_fbyf_stren(NewPlayerStatus#player.id),
	SpyfStren = get_player_spyf_stren(NewPlayerStatus#player.id),
	NewPlayerStatus2 = NewPlayerStatus#player{other=NewPlayerStatus#player.other#player_other{stren =StrenEff,suitid=SuitID,fbyfstren = FbyfStren,spyfstren = SpyfStren}},
    %% 单件装备加成
    Effect2 = goods_util:get_goods_attribute(NewGoodsInfo2),
	%%穿装备时加入紫戒指的技能和等级信息
	Goods_ring4 = goods_util:get_ring_color4(NewPlayerStatus#player.id),
	NewPlayerStatus3 = NewPlayerStatus2#player{other=NewPlayerStatus2#player.other#player_other{goods_ring4=Goods_ring4}},
	if  
		GoodsInfo#goods.subtype >= 9 andalso GoodsInfo#goods.subtype < 14 ->%%武器法宝
			%%成就系统的法宝判断
			AchCheck = lib_achieve_outline:check_equip_ach(GoodsInfo, NewPlayerStatus3, 1);
		GoodsInfo#goods.subtype =:= 24 ->%%时装
			%%成就系统的时装判断
			AchCheck = lib_achieve_outline:check_equip_ach(GoodsInfo, NewPlayerStatus3, 2);
		true ->
			%%成就系统的套装判断
			AchCheck = lib_achieve_outline:check_equip_ach(GoodsInfo, NewPlayerStatus3, 3)
	end,
	{ok, NewPlayerStatus3, NewStatus2, NewOldGoodsInfo, Effect2, AchCheck}.

%%卸下装备
%% @spec unequip_goods(PlayerId, Cell, GoodsInfo, GoodsTab) -> {ok, 1, [HP, MP, Attack, Defense, Strengh, Physique, Agility]}
unequip_goods(PlayerStatus, Status, GoodsInfo) ->
	%%取一个空格
	[Cell|NullCells] = Status#goods_status.null_cells,
	NewGoodsInfo = change_goods_cell(GoodsInfo, 4, Cell),
    %% 检查是否是武器、衣服
    [Wq, Yf, Fbyf, Spyf, Zq] = Status#goods_status.equip_current,
    if  NewGoodsInfo#goods.subtype =:= 10 ->
            CurrentEquip = [0, Yf, Fbyf, Spyf, Zq];
        NewGoodsInfo#goods.subtype =:= 24 ->
            CurrentEquip = [Wq, 0, Fbyf, Spyf, Zq];
		NewGoodsInfo#goods.subtype =:= 26 ->
            CurrentEquip = [Wq, Yf, 0, Spyf, Zq];
		NewGoodsInfo#goods.subtype =:= 27 ->
            CurrentEquip = [Wq, Yf, Fbyf, 0, Zq];
        true ->
            CurrentEquip = [Wq, Yf, Fbyf, Spyf, Zq]
    end,
    EquipSuit = goods_util:change_equip_suit(Status#goods_status.equip_suit, GoodsInfo#goods.suit_id, 0),
    NewStatus = Status#goods_status{ null_cells=NullCells, equip_current=CurrentEquip, equip_suit=EquipSuit },
	
	%%玩家卸下装备，更新衣橱的数据
	lib_wardrobe:unequip_check_wardrobe(NewGoodsInfo, PlayerStatus#player.id),
    %% 人物属性重新计算
    {ok, NewPlayerStatus, NewStatus2} = goods_util:count_role_equip_attribute(PlayerStatus, NewStatus, NewGoodsInfo),
	SuitID = goods_util:is_full_suit(EquipSuit),
	
	StrenEff = get_player_stren_eff(NewPlayerStatus#player.id),
	FbyfStren = get_player_fbyf_stren(NewPlayerStatus#player.id),
	SpyfStren = get_player_spyf_stren(NewPlayerStatus#player.id),
	
	NewPlayerStatus2 = NewPlayerStatus#player{other=NewPlayerStatus#player.other#player_other{stren =StrenEff,suitid=SuitID,fbyfstren = FbyfStren,spyfstren = SpyfStren}},
	%%穿装备时加入紫戒指的技能和等级信息
	Goods_ring4 = goods_util:get_ring_color4(NewPlayerStatus#player.id),
	NewPlayerStatus3 = NewPlayerStatus2#player{other=NewPlayerStatus2#player.other#player_other{goods_ring4=Goods_ring4}},
    {ok, NewPlayerStatus3, NewStatus2, NewGoodsInfo}.

%% 背包拖动物品
%% @spec drag_goods(GoodsInfo, OldCell, NewCell) -> {ok, NewStatus, [OldCellId, OldTypeId, NewCellId, NewTypeId]}
drag_goods(Status, GoodsInfo, OldCell, NewCell) ->
    OldGoodsInfo = goods_util:get_goods_by_cell(Status#goods_status.player_id, 4, NewCell),
    case is_record(OldGoodsInfo, goods) of
        false ->
            %% 新位置没有物品
            change_goods_cell(GoodsInfo, 4, NewCell),
            NullCells = lists:delete(NewCell, Status#goods_status.null_cells),
            NullCells1 = lists:sort([OldCell|NullCells]),
            NewStatus = Status#goods_status{ null_cells=NullCells1 },
            OldCellId = 0,
            OldTypeId = 0,
            NewCellId = GoodsInfo#goods.id,
            NewTypeId = GoodsInfo#goods.goods_id;
        true ->
            %% 新位置有物品
            change_goods_cell(GoodsInfo, 4, NewCell),
            change_goods_cell(OldGoodsInfo, 4, OldCell),
            NewStatus = Status,
            OldCellId = OldGoodsInfo#goods.id,
            OldTypeId = OldGoodsInfo#goods.goods_id,
            NewCellId = GoodsInfo#goods.id,
            NewTypeId = GoodsInfo#goods.goods_id
    end,
    {ok, NewStatus, [OldCellId, OldTypeId, NewCellId, NewTypeId]}.

%% 刷新背包掉落添加物品
refresh_new_goods(PidSend,PlayerId,GoodsTypeId)->
	GoodsLists = goods_util:get_type_goods_list(PlayerId,GoodsTypeId,4),
	case length(GoodsLists) > 0  of
		true ->			
			{ok,Bin} = pt_15:write(15005,[GoodsLists]),
			lib_send:send_to_sid(PidSend,Bin);
		false ->
			skip
	end.

%% 使用物品
%% @spec use_goods(PlayerStatus, Status, GoodsInfo, GoodsNum) -> {ok, NewPlayerStatus, NewStatus1, NewNum}
use_goods(PlayerStatus, Status, GoodsInfo, GoodsNum, GoodsBuffs) ->
	lib_goods_use:use_goods(PlayerStatus, Status, GoodsInfo, GoodsNum, GoodsBuffs).


%%添加长CD记录到ets
cd_add_ets(PlayerStatus,GoodsInfo) ->
	case cd_check(PlayerStatus,GoodsInfo) of
		{ok,Now} ->
			Minute1 = lists:member(GoodsInfo#goods.goods_id, [23000,23001,23002,23100,23101,23102,23009,23109,23013,23014]),
			ExpireTime = 
				if
					Minute1 -> Now + 60;
					true -> 
						Now + 10
				end,
			NewCd = #ets_goods_cd{id= Now,player_id = PlayerStatus#player.id,goods_id = GoodsInfo#goods.goods_id,expire_time = ExpireTime},
			ets:insert(?ETS_GOODS_CD, NewCd);
		{fail} ->
			skip
	end.

%%添加长CD记录到数据库		
cd_add(PlayerStatus,GoodsInfo) ->
	case cd_check(PlayerStatus,GoodsInfo) of
		{ok,Now} ->
			Halfhour = lists:member(GoodsInfo#goods.goods_id, [28200]),%% 28200回城石
			Onehour = lists:member(GoodsInfo#goods.goods_id, [28007,28008]),%% 28007 28008 功德丸
%% 			MinutePeach = lists:member(GoodsInfo#goods.goods_id, [23409, 23410,23411]),%% 蟠桃
			ExpireTime = 
				if
					Halfhour -> Now +1800; %% 半小时
					Onehour -> Now + 3600; %% 一小时
%% 					MinutePeach -> Now + 5; %%5秒
					true ->
						Now + 60
				end,
			case db_agent:add_new_goods_cd(PlayerStatus#player.id,GoodsInfo#goods.goods_id,ExpireTime) of
				{mongo,Ret} ->
					NewCd = #ets_goods_cd{id= Ret,player_id = PlayerStatus#player.id,goods_id = GoodsInfo#goods.goods_id,expire_time = ExpireTime};
				_Ret ->
					CdData = db_agent:get_new_goods_cd(PlayerStatus#player.id,GoodsInfo#goods.goods_id),
					NewCd = list_to_tuple([ets_goods_cd]++CdData)
			end,
			if
				is_record(NewCd,ets_goods_cd) ->
					ets:insert(?ETS_GOODS_CD, NewCd),
					{ok};
				true ->
					skip
			end;
		{fail} ->
			skip
	end.

%%长cd检验
cd_check(PlayerStatus,GoodsInfo) ->
	%%先删除过期的
	del_goods_cd(PlayerStatus#player.id),
	Now =util:unixtime(),
	MS_cd = ets:fun2ms(fun(T) when T#ets_goods_cd.player_id == PlayerStatus#player.id andalso T#ets_goods_cd.expire_time > Now  -> 
			T 
		end),
	CdList = ets:select(?ETS_GOODS_CD, MS_cd),
	F = fun(GCD,Flag) ->
			CdType = GCD#ets_goods_cd.goods_id div 100 ,
			GoodsType = GoodsInfo#goods.goods_id div 100 ,
			if
				%%功德丸特例
				GCD#ets_goods_cd.goods_id == 28007 andalso GoodsInfo#goods.goods_id == 28008 ->
					Flag;
				GCD#ets_goods_cd.goods_id == 28008 andalso GoodsInfo#goods.goods_id == 28007 ->
					Flag;
 				%%蟠桃特例(三种判断)
 				GCD#ets_goods_cd.goods_id == 23409 
 				  andalso GoodsInfo#goods.goods_id == 23410
 				  andalso GoodsInfo#goods.goods_id == 23411->
 					Flag;
				CdType == GoodsType ->
					Flag +1;
				true ->
					Flag
			end
	end,
	Ret = lists:foldl(F, 0, CdList),
	if
		Ret > 0 ->
			{fail};
		true ->
			{ok,Now}
	end.

%% 删除多个物品
%% @spec delete_more(Status, GoodsList, GoodsNum) -> {ok, NewStatus}
delete_more(Status, GoodsList, GoodsNum) ->
    GoodsList1 = goods_util:sort(GoodsList, cell),
    F1 = fun(GoodsInfo, [Num, Status1]) ->
            case Num > 0 of
                true ->
                    {ok, NewStatus1, Num1} = delete_one(Status1, GoodsInfo, Num),
                    case Num1 > 0 of
                        true -> NewNum = 0;
                        false -> NewNum = Num - GoodsInfo#goods.num
                    end,
                    [NewNum, NewStatus1];
                false ->
                    [Num, Status1]
            end
         end,
    [_, NewStatus] = lists:foldl(F1, [GoodsNum, Status], GoodsList1),
    {ok, NewStatus}.

%% 删除多个任务物品
delete_task_more(GoodsList,GoodsNum) ->
	  F1 = fun(GoodsInfo, Num) ->
            case Num > 0 of
                true ->
                    {ok,Num1} = delete_task_one(GoodsInfo, Num),
                    case Num1 > 0 of
                        true -> NewNum = 0;
                        false -> NewNum = Num - GoodsInfo#goods.num
                    end,
                    NewNum;
                false ->
                    Num
            end
         end,
    lists:foldl(F1,GoodsNum, GoodsList),
    {ok}.
%% 删除多个农场仓库物品
delete_plant_more(GoodsList,GoodsNum) ->
	  F1 = fun(GoodsInfo, Num) ->
            case Num > 0 of
                true ->
                    {ok,Num1} = delete_plant_one(GoodsInfo, Num),
                    case Num1 > 0 of
                        true -> NewNum = 0;
                        false -> NewNum = Num - GoodsInfo#goods.num
                    end,
                    NewNum;
                false ->
                    Num
            end
         end,
    lists:foldl(F1,GoodsNum, GoodsList),
    {ok}.
%% 删除一个物品
%% @spec use_goods(PlayerStatus, GoodsStatus, GoodsInfo, GoodsNum) -> {ok, [HP, MP]}
delete_one(Status, GoodsInfo, GoodsNum) ->
    case GoodsInfo#goods.num > GoodsNum of
        true when GoodsInfo#goods.id >0 ->
            %% 部分使用
            NewNum = GoodsInfo#goods.num - GoodsNum,
            change_goods_num(GoodsInfo, NewNum),
            NewStatus = Status;
        false when GoodsInfo#goods.id >0 ->
            %% 全部使用
            NewNum = 0,
            delete_goods(GoodsInfo#goods.id),
            if  GoodsInfo#goods.location == 4 ->
                    NullCells = lists:sort([GoodsInfo#goods.cell|Status#goods_status.null_cells]),
                    NewStatus = Status#goods_status{ null_cells=NullCells };
                true ->
                    NewStatus = Status
            end;
        _ ->
            NewNum = GoodsNum,
            NewStatus = Status
    end,
    {ok, NewStatus, NewNum}.

%% 删除一个任务物品
delete_task_one(GoodsInfo,GoodsNum) ->
	case GoodsInfo#goods.num > GoodsNum of
        true when GoodsInfo#goods.id >0 ->
            %% 部分使用
            NewNum = GoodsInfo#goods.num - GoodsNum,
            change_goods_num(GoodsInfo, NewNum);
        false when GoodsInfo#goods.id >0 ->
            %% 全部使用
            NewNum = 0,
            delete_goods(GoodsInfo#goods.id)
    end,
    {ok, NewNum}.

%% 删除一个任务物品
delete_plant_one(GoodsInfo,GoodsNum) ->
	case GoodsInfo#goods.num > GoodsNum of
        true when GoodsInfo#goods.id >0 ->
            %% 部分使用
            NewNum = GoodsInfo#goods.num - GoodsNum,
            change_goods_num(GoodsInfo, NewNum);
        false when GoodsInfo#goods.id >0 ->
            %% 全部使用
            NewNum = 0,
            delete_goods(GoodsInfo#goods.id)
    end,
    {ok, NewNum}.

%% 删除一类物品
%% @spec delete_type_goods(GoodsTypeId, GoodsStatus) -> {ok, NewStatus} | Error
delete_type_goods(GoodsTypeId, GoodsStatus) ->
    GoodsList = goods_util:get_type_goods_list(GoodsStatus#goods_status.player_id, GoodsTypeId, 4),
    if length(GoodsList) > 0 ->
            TotalNum = goods_util:get_goods_totalnum(GoodsList),
            case (catch delete_more(GoodsStatus, GoodsList, TotalNum)) of
                {ok, NewStatus} -> {ok, NewStatus};
                 Error -> {fail, Error, GoodsStatus}
            end;
        true ->
            {ok, GoodsStatus}
    end.

%%物品存入仓库
movein_bag(Status, GoodsInfo, GoodsNum, GoodsTypeInfo, Store_num) ->
	GoodsList = goods_util:get_type_goods_list(GoodsInfo#goods.player_id,GoodsInfo#goods.goods_id , GoodsInfo#goods.bind, 5), 
	Store_count = length(goods_util:get_goods_list(GoodsInfo#goods.player_id,5)),
	if 
		Store_count >= Store_num ->
			{fail, full};
		true ->
    		%%查找是不是已经有同类物品？
    		GoodsList1 = goods_util:sort(GoodsList, id),
   		 	case GoodsNum =:= GoodsInfo#goods.num of
        		%% 全部
        		true ->
            		case length(GoodsList1) > 0 of
                		%% 存在且可叠加
                		true when GoodsTypeInfo#ets_base_goods.max_overlap > 1 ->
                    		%% 更新原有的可叠加物品
                    		[GoodsNum2,_] = lists:foldl(fun update_overlap_goods/2, [GoodsNum, GoodsTypeInfo#ets_base_goods.max_overlap], GoodsList1),
		                    case GoodsNum2 > 0 of
        		                true ->
                		            change_goods_cell_and_num(GoodsInfo, 5, 0, GoodsNum2);
                        		false ->
                            		delete_goods(GoodsInfo#goods.id)
                    		end;
                		%% 不存在或者不可叠加，且直接移入仓库
                		_ -> 
							change_goods_cell(GoodsInfo, 5, 0)
            		end,
            		NullCells = lists:sort([GoodsInfo#goods.cell|Status#goods_status.null_cells]),
            		NewStatus = Status#goods_status{ null_cells=NullCells };
        		%% 部份
        		false ->
					%%仓库没有部分存入
            		NewStatus = Status
    		end,
    		{ok, NewStatus}
	end.


%%从临时矿包取出物品
moveout_orebag(Status, GoodsInfo, GoodsNum, GoodsTypeInfo) ->
    GoodsList = goods_util:get_type_goods_list(GoodsInfo#goods.player_id, GoodsInfo#goods.goods_id, GoodsInfo#goods.bind, 4),
    GoodsList1 = goods_util:sort(GoodsList, cell),
    case GoodsNum =:= GoodsInfo#goods.num of
        %% 全部
        true ->
            case length(GoodsList1) > 0 of
                %% 存在且可叠加
                true when GoodsTypeInfo#ets_base_goods.max_overlap > 1 ->
                    %% 更新原有的可叠加物品
                    [GoodsNum2,_] = lists:foldl(fun update_overlap_goods/2, [GoodsNum, GoodsTypeInfo#ets_base_goods.max_overlap], GoodsList1),
                    case GoodsNum2 > 0 of
                        true ->
                            [NewCell|NullCells] =Status#goods_status.null_cells,
                            change_goods_cell_and_num(GoodsInfo, 4, NewCell, GoodsNum2),
                            NewStatus = Status#goods_status{ null_cells=NullCells };
                        false ->
                            delete_goods(GoodsInfo#goods.id),
                            NewStatus = Status
                    end;
                %% 不存在或者不可叠加，且直接移入背包
                _ ->
                    [NewCell|NullCells] =Status#goods_status.null_cells,
                    change_goods_cell(GoodsInfo, 4, NewCell),
                    NewStatus = Status#goods_status{ null_cells=NullCells }
            end,
			{ok,NewStatus};
        false ->
			{ok,Status}
	end.

%%从农场仓库取出物品 1个物品
moveout_plantbag(Status, GoodsInfo, GoodsNum, GoodsTypeInfo) ->
    GoodsList = goods_util:get_type_goods_list(GoodsInfo#goods.player_id, GoodsInfo#goods.goods_id, GoodsInfo#goods.bind, 4),
    GoodsList1 = goods_util:sort(GoodsList, cell),
    case GoodsNum =:= GoodsInfo#goods.num of
        %% 全部
        true ->
            case length(GoodsList1) > 0 of
                %% 存在且可叠加
                true when GoodsTypeInfo#ets_base_goods.max_overlap > 1 ->
                    %% 更新原有的可叠加物品
                    [GoodsNum2,_] = lists:foldl(fun update_overlap_goods/2, [GoodsNum, GoodsTypeInfo#ets_base_goods.max_overlap], GoodsList1),
                    case GoodsNum2 > 0 of
                        true ->
                            [NewCell|NullCells] =Status#goods_status.null_cells,
                            change_goods_cell_and_num(GoodsInfo, 4, NewCell, GoodsNum2),
                            NewStatus = Status#goods_status{ null_cells=NullCells};
                        false ->
                            delete_goods(GoodsInfo#goods.id),
                            NewStatus = Status
                    end;
                %% 不存在或者不可叠加，且直接移入背包
                _ ->
                    [NewCell|NullCells] =Status#goods_status.null_cells,
                    change_goods_cell(GoodsInfo, 4, NewCell),
                    NewStatus = Status#goods_status{ null_cells=NullCells }
            end,
			{ok,NewStatus};
        false ->
			case length(GoodsList1) > 0 of
		                %% 存在
        		        true ->
                		    %% 更新原有的可叠加物品
		                    [GoodsNum2,_] = lists:foldl(fun update_overlap_goods/2, [GoodsNum, GoodsTypeInfo#ets_base_goods.max_overlap], GoodsList1);
        		        false ->
                		    GoodsNum2 = GoodsNum
		     end,
        	%% 添加新的记录
		    case GoodsNum2 > 0 of
                	true ->
						[NewCell|NullCells] =Status#goods_status.null_cells,
						NewStatus = Status#goods_status{ null_cells=NullCells },
                    	NewGoodsInfo1 = GoodsInfo#goods{ location=4, cell = NewCell, num=GoodsNum2 },
		                add_goods(NewGoodsInfo1),
						NewStatus;
        		    false ->
						NewStatus = Status
            end,
           	%% 更改原数量
            NewNum = GoodsInfo#goods.num - GoodsNum,
            change_goods_num(GoodsInfo, NewNum),
			{ok,NewStatus}
	end.

%%从农场仓库取出物品  列表
moveout_plantbag_list(Status,GoodsList) ->
	F = fun({Gid,Num},_Status) ->
				GoodsInfo = goods_util:get_type_goods_info(Status#goods_status.player_id,Gid,10),
				case is_record(GoodsInfo,goods) of	
					true when GoodsInfo#goods.num >= Num ->
						GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
						moveout_plantbag(_Status, GoodsInfo, Num, GoodsTypeInfo);
					_ ->
						_Status
				end
		end,
	case goods_util:list_handle(F, Status, GoodsList) of
		{ok, NewStatus} ->
			{ok, NewStatus};
		_ ->
			{fail,Status}
	end.
				
%%从仓库取出物品
moveout_bag(Status, GoodsInfo, GoodsNum, GoodsTypeInfo) ->
    GoodsList = goods_util:get_type_goods_list(GoodsInfo#goods.player_id, GoodsInfo#goods.goods_id, GoodsInfo#goods.bind, 4),
    GoodsList1 = goods_util:sort(GoodsList, cell),
    case GoodsNum =:= GoodsInfo#goods.num of
        %% 全部
        true ->
			%%MODIFY ZJ 不对物品进行叠加  ">" to "<"
            case length(GoodsList1) < 0 of
                %% 存在且可叠加
                true when GoodsTypeInfo#ets_base_goods.max_overlap > 1 ->
                    %% 更新原有的可叠加物品
                    [GoodsNum2,_] = lists:foldl(fun update_overlap_goods/2, [GoodsNum, GoodsTypeInfo#ets_base_goods.max_overlap], GoodsList1),
                    case GoodsNum2 > 0 of
                        true ->
                            [NewCell|NullCells] =Status#goods_status.null_cells,
                            change_goods_cell_and_num(GoodsInfo, 4, NewCell, GoodsNum2),
                            NewStatus = Status#goods_status{ null_cells=NullCells };
                        false ->
                            delete_goods(GoodsInfo#goods.id),
                            NewStatus = Status
                    end;
                %% 不存在或者不可叠加，且直接移入背包
                _ ->
                    [NewCell|NullCells] =Status#goods_status.null_cells,
                    change_goods_cell(GoodsInfo, 4, NewCell),
                    NewStatus = Status#goods_status{ null_cells=NullCells }
            end;
        %% 部份
        false ->
			%%仓库没有部分取出
			NewStatus = Status
    end,
    {ok, NewStatus}.

%% 扩展背包
extend(PlayerStatus, Cost, Loc) ->
	PlayerStatus1 = lib_goods:cost_money(PlayerStatus, Cost, gold, 1562),
    CellNum = 6 * 6,
	case Loc of
		1 ->
    		NewNum = PlayerStatus1#player.cell_num + CellNum,
    		NewPlayerStatus = PlayerStatus1#player{cell_num = NewNum },
			NellCells = goods_util:get_null_cells(PlayerStatus#player.id, NewNum),
			db_agent:extend_bag(NewNum,NewPlayerStatus#player.id),
			{ok, NewPlayerStatus, NellCells};
		_ ->
			NewNum = PlayerStatus1#player.store_num + CellNum,
			NewPlayerStatus = PlayerStatus1#player{store_num = NewNum },
			db_agent:extend_store(NewNum,NewPlayerStatus#player.id),
			{ok, NewPlayerStatus}
	end.

%% 装备拆分
destruct(GoodsStatus,GoodsInfo,Num,_Pos) ->
	NewNum = GoodsInfo#goods.num - Num,
	change_goods_num(GoodsInfo,NewNum),
	GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
	NewGoodsInfo = goods_util:get_new_goods(GoodsTypeInfo),
	NewGoodsInfo2 = NewGoodsInfo#goods{bind = GoodsInfo#goods.bind},
	add_goods_base(GoodsStatus,GoodsTypeInfo,Num,NewGoodsInfo2,[]).

	
%%修理装备
%% @spec mend_goods(PlayerId, GoodsInfo) -> {ok, NewCoin, Cost, [HP, MP, Attack, Defense]} | {error, Res}
mend_goods(PlayerStatus, GoodsStatus, GoodsInfo) ->
    UseNum = goods_util:get_goods_use_num(GoodsInfo#goods.attrition),
    change_goods_use(GoodsInfo, UseNum),
    %% 扣费
    Cost = goods_util:get_mend_cost(GoodsInfo#goods.attrition, GoodsInfo#goods.use_num),
    NewPlayerStatus = cost_money(PlayerStatus, Cost, coin,1551),
    case GoodsInfo#goods.use_num =< 0 of
        %% 之前磨损为0
        true ->
            %% 人物属性重新计算
            EquipSuit = goods_util:change_equip_suit(GoodsStatus#goods_status.equip_suit, 0, GoodsInfo#goods.suit_id),
            Status = GoodsStatus#goods_status{ equip_suit=EquipSuit },
            {ok, NewPlayerStatus2, NewStatus} = goods_util:count_role_equip_attribute(NewPlayerStatus, Status, GoodsInfo);
        false ->
            NewPlayerStatus2 = NewPlayerStatus,
            NewStatus = GoodsStatus
     end,
     {ok, NewPlayerStatus2, NewStatus}.


%%整理背包 
clean_bag([],[])->
	[0,{}];
clean_bag([],GroupList)->
	F = fun(Group,Cell) ->
			case length(Group) > 0 of
				true ->
					One = hd(Group),
					GoodsTypeInfo = goods_util:get_goods_type(One#goods.goods_id),
					case is_record(GoodsTypeInfo,ets_base_goods) andalso GoodsTypeInfo#ets_base_goods.max_overlap > 1 of
						true ->
							%%可以叠加
							TotalNum = goods_util:get_goods_totalnum(Group),
							F_cell = fun(Good,[Left,NowCell]) ->
											 case Left > 0 of
												 true ->
											 		if
												 		Left > GoodsTypeInfo#ets_base_goods.max_overlap ->
															if
																Good#goods.cell == NowCell andalso Good#goods.num == GoodsTypeInfo#ets_base_goods.max_overlap ->
																	skip;
																true ->
													 				change_goods_cell_and_num(Good, 4, NowCell, GoodsTypeInfo#ets_base_goods.max_overlap)
															end,
															NewLeft = Left - GoodsTypeInfo#ets_base_goods.max_overlap,
															[NewLeft, NowCell + 1];
														true ->
															if
																Good#goods.cell == NowCell andalso Good#goods.num == Left ->
																	skip;
																true ->
																	change_goods_cell_and_num(Good, 4, NowCell, Left)
															end,
															[0,NowCell + 1]
													end;
												 false ->
													 delete_goods(Good#goods.id),
													 [0,NowCell]
											 end
									 end,
							[_,NewCell] = lists:foldl(F_cell, [TotalNum,Cell], Group),
							NewCell;					
						false ->
							%%不能叠加，每一个物品分配cell
							F_cell = fun(Good,NowCell) ->
											 if
												 Good#goods.cell == NowCell ->
													 skip;
												 true ->
													change_goods_cell(Good, 4, NowCell)
											 end,
									NowCell + 1
							end,
							lists:foldl(F_cell,Cell, Group)
					end;
				false ->
					Cell
			end
		end,
	TotalCell = lists:foldl(F, 1, GroupList),
	[TotalCell,{}];
%%整理背包
clean_bag(GoodsList,GroupList) ->
	OneGood = hd(GoodsList),
		F_filter = fun(Good) ->
					   Good#goods.goods_id == OneGood#goods.goods_id 
				   andalso Good#goods.bind == OneGood#goods.bind
				   andalso Good#goods.trade == OneGood#goods.trade
				   end,
	Filter_list = lists:filter(F_filter, GoodsList),
	Tail_list =lists:foldl(
				 fun(Good,Left) ->
								   lists:delete(Good, Left)
						   end
								   ,GoodsList, Filter_list),
	clean_bag(Tail_list,[Filter_list|GroupList]).
	

%%添加采矿物品
give_ore_goods({GoodsTypeId, GoodsNum}, GoodsStatus)->
	GoodsTypeInfo = goods_util:get_goods_type(GoodsTypeId),
    case is_record(GoodsTypeInfo, ets_base_goods) of
        %% 物品不存在
        false ->
            {fail, {GoodsTypeId, not_found}};
        true ->
			GoodsList = goods_util:get_type_goods_list(GoodsStatus#goods_status.player_id, GoodsTypeId, GoodsTypeInfo#ets_base_goods.bind, 9),
            GoodsInfo = goods_util:get_new_goods(GoodsTypeInfo),
            case add_ore_goods_base(GoodsStatus, GoodsTypeInfo, GoodsNum, GoodsInfo, GoodsList) of
                 {ok} ->
					 spawn(fun()->log:log_ore([GoodsTypeId,GoodsStatus#goods_status.player_id])end),
                     {ok};
                  Error ->
                      {fail, Error}
            end
    end.

%%添加灵兽战斗技能书物品
give_pet_batt_skill_goods({GoodsTypeId, GoodsNum}, PlayerId)->
	GoodsTypeInfo = goods_util:get_goods_type(GoodsTypeId),
    case is_record(GoodsTypeInfo, ets_base_goods) of
        %% 物品不存在
        false ->
            {fail, {GoodsTypeId, not_found}};
        true ->
			GoodsList = goods_util:get_type_goods_list(PlayerId, GoodsTypeId, GoodsTypeInfo#ets_base_goods.bind, 12),
            GoodsInfo = goods_util:get_new_goods(GoodsTypeInfo),
			NewGoodsInfo = lib_goods:bind_goods(GoodsInfo),
            case add_pet_batt_skill_books_goods(PlayerId, GoodsTypeInfo, GoodsNum, NewGoodsInfo, GoodsList) of
                 {ok} ->
                     {ok};
                  Error ->
                      {fail, Error}
            end
    end.

%%添加农场物品   lib执行，不走mod_goods 进程
give_plant_goods({GoodsTypeId, GoodsNum}, PlayerId)->
	GoodsTypeInfo = goods_util:get_goods_type(GoodsTypeId),
    case is_record(GoodsTypeInfo, ets_base_goods) of
        %% 物品不存在
        false ->
            {fail, {GoodsTypeId, not_found}};
        true ->
			GoodsList = goods_util:get_type_goods_list(PlayerId, GoodsTypeId, GoodsTypeInfo#ets_base_goods.bind, 10),
            GoodsInfo = goods_util:get_new_goods(GoodsTypeInfo),
            case add_plant_goods_base(PlayerId,GoodsTypeInfo, GoodsNum, GoodsInfo, GoodsList) of
                 {ok} ->
                     {ok};
                  Error ->
                      {fail, Error}
            end
    end.

%%任务物品
give_task_goods({GoodsTypeId, GoodsNum}, GoodsStatus)->
	GoodsTypeInfo = goods_util:get_goods_type(GoodsTypeId),
    case is_record(GoodsTypeInfo, ets_base_goods) of
        %% 物品不存在
        false ->
            {fail, {GoodsTypeId, not_found}};
        true ->
            GoodsList = goods_util:get_type_goods_list(GoodsStatus#goods_status.player_id, GoodsTypeId, GoodsTypeInfo#ets_base_goods.bind, 6),
            GoodsInfo = goods_util:get_new_goods(GoodsTypeInfo),
            case (catch add_task_goods_base(GoodsStatus, GoodsTypeInfo, GoodsNum, GoodsInfo, GoodsList)) of
                 {ok} ->
                     {ok};
                  Error ->
                  %?DEBUG("mod_goods give_goods:~p", [Error]),
                      {fail, Error}
            end
    end.

%% 赠送物品

%%可设置绑定和交易状态
give_goods_bt({GoodsTypeId, GoodsNum ,Bind, Trade}, GoodsStatus) ->
	give_goods({GoodsTypeId, GoodsNum ,Bind ,0, Trade}, GoodsStatus).

%% @spec give_goods(GoodsStatus, GoodsTypeId, GoodsNum) -> {ok, NewGoodsStatus} | {fail, Error, GoodsStatus}
give_goods({GoodsTypeId, GoodsNum}, GoodsStatus) ->
	GoodsTypeInfo = goods_util:get_goods_type(GoodsTypeId),
  	give_goods({GoodsTypeId, GoodsNum ,GoodsTypeInfo#ets_base_goods.bind}, GoodsStatus);
%%可设物品绑定状态
give_goods({GoodsTypeId, GoodsNum ,Bind}, GoodsStatus) ->
	give_goods({GoodsTypeId, GoodsNum, Bind ,0, 0}, GoodsStatus);
	
give_goods({GoodsTypeId, GoodsNum ,Bind ,ExpireTime, Trade}, GoodsStatus) ->
%% 	?DEBUG("lib_goods gid = ~p~n",[GoodsTypeId]),
    GoodsTypeInfo0 = goods_util:get_goods_type(GoodsTypeId),
	case Bind of
		0 ->
			GoodsTypeInfo1 = GoodsTypeInfo0#ets_base_goods{bind = Bind ,expire_time = ExpireTime};
		2 ->
			GoodsTypeInfo1 = GoodsTypeInfo0#ets_base_goods{bind = Bind ,expire_time = ExpireTime};
		_ ->
			GoodsTypeInfo1 = GoodsTypeInfo0
	end,
	case Trade of
		1 ->%%强制性设成不可交易的
			GoodsTypeInfo = GoodsTypeInfo1#ets_base_goods{trade = 1};
		2 ->%%强制性设成可交易的
			GoodsTypeInfo = GoodsTypeInfo1#ets_base_goods{trade = 0};
		_ ->%%系统默认的，如0
			GoodsTypeInfo = GoodsTypeInfo1
	end,
    case is_record(GoodsTypeInfo, ets_base_goods) of
        %% 物品不存在
        false ->
            {fail, {GoodsTypeId, not_found}, GoodsStatus};
        true ->
            GoodsList = goods_util:get_type_goods_list(GoodsStatus#goods_status.player_id, GoodsTypeId, GoodsTypeInfo#ets_base_goods.bind, 4),
            %%空格子的个数
            CellNum = goods_util:get_null_cell_num(GoodsList, GoodsTypeInfo#ets_base_goods.max_overlap, GoodsNum),
            case length(GoodsStatus#goods_status.null_cells) < CellNum of
                %% 背包格子不足
                true ->
                    {fail, cell_num, GoodsStatus};
                false ->
                    GoodsInfo = goods_util:get_new_goods(GoodsTypeInfo),
                    case (catch add_goods_base(GoodsStatus, GoodsTypeInfo, GoodsNum, GoodsInfo, GoodsList)) of
                        {ok, NewStatus} ->
                            {ok, NewStatus};
                        Error ->
                            {fail, Error, GoodsStatus}
                    end
            end
    end.


%% 更新原有的可叠加物品
update_overlap_goods(GoodsInfo, [Num, MaxOverlap]) ->
    case Num > 0 of
        true when GoodsInfo#goods.num =/= MaxOverlap andalso MaxOverlap > 0 ->
            case Num + GoodsInfo#goods.num > MaxOverlap of
                %% 总数超出可叠加数
                true ->
                    OldNum = MaxOverlap,
                    NewNum = Num + GoodsInfo#goods.num - MaxOverlap;
                false ->
                    OldNum = Num + GoodsInfo#goods.num,
                    NewNum = 0
            end,
            change_goods_num(GoodsInfo, OldNum);
        true ->
            NewNum = Num;
        false ->
            NewNum = 0
    end,
    [NewNum, MaxOverlap].

%% 添加装备 到背包
%% @spec add_equip_base(GoodsStatus, GoodsTypeInfo, AttributeList,BindType) -> {ok, NewGoodsStatus}
add_equip_base(GoodsStatus,GoodsTypeInfo,AttributeList,BindType) ->
	if
		is_record(GoodsTypeInfo,ets_base_goods) ->
			[Cell|NullCells] = GoodsStatus#goods_status.null_cells,
			Goods = goods_util:get_new_goods(GoodsTypeInfo),
			NewGoods = Goods#goods{player_id = GoodsStatus#goods_status.player_id,location = 4,cell = Cell,num=1,bind = BindType},
    		NewGoodsStatus = GoodsStatus#goods_status{ null_cells=NullCells },
    		add_goods(NewGoods,AttributeList),
			{ok,NewGoodsStatus};
		true ->
			{ok,GoodsStatus}
	end.

%% 添加物品
%% @spec add_goods_base(GoodsStatus, GoodsTypeInfo, GoodsInfo, GoodsNum) -> {ok, NewGoodsStatus}
add_goods_base(GoodsStatus, GoodsTypeInfo, GoodsNum) ->
    GoodsInfo = goods_util:get_new_goods(GoodsTypeInfo),
    add_goods_base(GoodsStatus, GoodsTypeInfo, GoodsNum, GoodsInfo).

add_goods_base(GoodsStatus, GoodsTypeInfo, GoodsNum, GoodsInfo) ->
	%%如果可以叠加，添加叠加物品
    case GoodsTypeInfo#ets_base_goods.max_overlap > 1 of
        true ->
            List = goods_util:get_type_goods_list(GoodsStatus#goods_status.player_id, GoodsTypeInfo#ets_base_goods.goods_id, GoodsInfo#goods.bind, 4),
            GoodsList = goods_util:sort(List, cell);
        false ->
            GoodsList = []
    end,
    add_goods_base(GoodsStatus, GoodsTypeInfo, GoodsNum, GoodsInfo, GoodsList).

add_goods_base(GoodsStatus, GoodsTypeInfo, GoodsNum, GoodsInfo, GoodsList) ->
    %% 插入物品记录
    case GoodsTypeInfo#ets_base_goods.max_overlap > 1 of
        true ->
            %% 更新原有的可叠加物品
            [GoodsNum2,_] = lists:foldl(fun update_overlap_goods/2, [GoodsNum, GoodsTypeInfo#ets_base_goods.max_overlap], GoodsList),
            %% 添加新的可叠加物品
            [NewGoodsStatus,_,_,_] = goods_util:deeploop(fun add_overlap_goods/2, GoodsNum2, [GoodsStatus, GoodsInfo, 4, GoodsTypeInfo#ets_base_goods.max_overlap]);
        false ->
            %% 添加新的不可叠加物品
            AllNums = lists:seq(1, GoodsNum),
            [NewGoodsStatus,_,_] = lists:foldl(fun add_nonlap_goods/2, [GoodsStatus, GoodsInfo, 4], AllNums)
    end,
    {ok, NewGoodsStatus}.

%%添加灵兽战斗技能书物品
add_pet_batt_skill_books_goods(PlayerId, GoodsTypeInfo, GoodsNum, GoodsInfo, GoodsList) ->
    %% 插入物品记录
    case GoodsTypeInfo#ets_base_goods.max_overlap > 1 of
        true ->
            %% 更新原有的可叠加物品
            [GoodsNum2,_] = lists:foldl(fun update_overlap_goods/2, [GoodsNum, GoodsTypeInfo#ets_base_goods.max_overlap], GoodsList),
            %% 添加新的可叠加物品
            [_,_,_,_] = goods_util:deeploop(fun add_overlap_goods/2, GoodsNum2, [PlayerId,GoodsInfo, 12, GoodsTypeInfo#ets_base_goods.max_overlap]);
        false ->
            %% 添加新的不可叠加物品
            AllNums = lists:seq(1, GoodsNum),
            [_,_,_] = lists:foldl(fun add_nonlap_goods/2, [PlayerId,GoodsInfo, 12], AllNums)
    end,
	{ok}.
	

%%添加采矿物品
add_ore_goods_base(GoodsStatus, GoodsTypeInfo, GoodsNum, GoodsInfo, GoodsList) ->
    %% 插入物品记录
    case GoodsTypeInfo#ets_base_goods.max_overlap > 1 of
        true ->
            %% 更新原有的可叠加物品
            [GoodsNum2,_] = lists:foldl(fun update_overlap_goods/2, [GoodsNum, GoodsTypeInfo#ets_base_goods.max_overlap], GoodsList),
            %% 添加新的可叠加物品
            [_NewGoodsStatus,_,_,_] = goods_util:deeploop(fun add_overlap_goods/2, GoodsNum2, [GoodsStatus#goods_status.player_id, GoodsInfo, 9, GoodsTypeInfo#ets_base_goods.max_overlap]);
        false ->
            %% 添加新的不可叠加物品
            AllNums = lists:seq(1, GoodsNum),
            [_NewGoodsStatus,_,_] = lists:foldl(fun add_nonlap_goods/2, [GoodsStatus#goods_status.player_id, GoodsInfo, 9], AllNums)
    end,
	{ok}.

%%添加农场物品
add_plant_goods_base(PlayerId,GoodsTypeInfo, GoodsNum, GoodsInfo, GoodsList) ->
    %% 插入物品记录
    case GoodsTypeInfo#ets_base_goods.max_overlap > 1 of
        true ->
            %% 更新原有的可叠加物品
            [GoodsNum2,_] = lists:foldl(fun update_overlap_goods/2, [GoodsNum, GoodsTypeInfo#ets_base_goods.max_overlap], GoodsList),
            %% 添加新的可叠加物品
            [_,_,_,_] = goods_util:deeploop(fun add_overlap_goods/2, GoodsNum2, [PlayerId,GoodsInfo, 10, GoodsTypeInfo#ets_base_goods.max_overlap]);
        false ->
            %% 添加新的不可叠加物品
            AllNums = lists:seq(1, GoodsNum),
            [_,_,_] = lists:foldl(fun add_nonlap_goods/2, [PlayerId,GoodsInfo, 10], AllNums)
    end,
	{ok}.
%%添加任务物品
add_task_goods_base(GoodsStatus, GoodsTypeInfo, GoodsNum, GoodsInfo, GoodsList) ->
    %% 插入物品记录
    case GoodsTypeInfo#ets_base_goods.max_overlap > 1 of
        true ->
            %% 更新原有的可叠加物品
            [GoodsNum2,_] = lists:foldl(fun update_overlap_goods/2, [GoodsNum, GoodsTypeInfo#ets_base_goods.max_overlap], GoodsList),
            %% 添加新的可叠加物品
            [_NewGoodsStatus,_,_,_] = goods_util:deeploop(fun add_overlap_goods/2, GoodsNum2, [GoodsStatus, GoodsInfo, 6, GoodsTypeInfo#ets_base_goods.max_overlap]);
        false ->
            %% 添加新的不可叠加物品
            AllNums = lists:seq(1, GoodsNum),
            [_NewGoodsStatus,_,_] = lists:foldl(fun add_nonlap_goods/2, [GoodsStatus, GoodsInfo, 6], AllNums)
    end,
    {ok}.

%% 添加新的可叠加物品 不检查空间
add_overlap_goods(Num, [PlayerId,GoodsInfo, Location, MaxOverlap]) when is_integer(PlayerId) ->
    case Num > MaxOverlap of
        true ->
            NewNum = Num - MaxOverlap,
            OldNum = MaxOverlap;
        false ->
            NewNum = 0,
            OldNum = Num
    end,
    case OldNum > 0 of
        true  ->
            NewGoodsInfo = GoodsInfo#goods{ player_id=PlayerId, location=Location, num=OldNum },
            add_goods(NewGoodsInfo);
         _ ->
			skip
    end,
    [NewNum, [PlayerId,GoodsInfo, Location, MaxOverlap]];

%% 添加新的可叠加物品  检查空间
add_overlap_goods(Num, [GoodsStatus, GoodsInfo, Location, MaxOverlap]) ->
    case Num > MaxOverlap of
        true ->
            NewNum = Num - MaxOverlap,
            OldNum = MaxOverlap;
        false ->
            NewNum = 0,
            OldNum = Num
    end,
    case OldNum > 0 of
        true when length(GoodsStatus#goods_status.null_cells) > 0 ->
            [Cell|NullCells] = GoodsStatus#goods_status.null_cells,
            NewGoodsStatus = GoodsStatus#goods_status{null_cells=NullCells },
            NewGoodsInfo = GoodsInfo#goods{ player_id=GoodsStatus#goods_status.player_id, location=Location, cell=Cell, num=OldNum },
            add_goods(NewGoodsInfo);
         _ ->
             NewGoodsStatus = GoodsStatus
    end,
    [NewNum, [NewGoodsStatus, GoodsInfo, Location, MaxOverlap]].


%% 添加新的不可叠加物品   不检查空间
add_nonlap_goods(_, [PlayerId,GoodsInfo, Location]) when is_integer(PlayerId)->
   	NewGoodsInfo3 = GoodsInfo#goods{ player_id=PlayerId, location=Location, num=1 },
    add_goods(NewGoodsInfo3),
    [PlayerId,GoodsInfo, Location];

%% 添加新的不可叠加物品   检查空间
add_nonlap_goods(_, [GoodsStatus, GoodsInfo, Location]) ->
    case length(GoodsStatus#goods_status.null_cells) > 0 of
        true ->
            [Cell|NullCells] = GoodsStatus#goods_status.null_cells,
            NewGoodsStatus = GoodsStatus#goods_status{ null_cells=NullCells },
            NewGoodsInfo3 = GoodsInfo#goods{ player_id=GoodsStatus#goods_status.player_id, location=Location, cell=Cell, num=1 },
            add_goods(NewGoodsInfo3);
        false ->
            NewGoodsStatus = GoodsStatus
    end,
    [NewGoodsStatus, GoodsInfo, Location].


%% 装备磨损
attrit_equip(GoodsInfo, [UseNum, ZeroEquipList]) ->
    case GoodsInfo#goods.attrition > 0 andalso GoodsInfo#goods.use_num > 0 of
        %% 耐久度降为0
        true when GoodsInfo#goods.use_num =< UseNum ->
            NewGoodsInfo = GoodsInfo#goods{ use_num=0 },
            ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
            [UseNum, [NewGoodsInfo|ZeroEquipList]];
        true ->
            NewUseNum = GoodsInfo#goods.use_num - UseNum,
            NewGoodsInfo = GoodsInfo#goods{ use_num=NewUseNum },
            ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
            [UseNum, ZeroEquipList];
        false ->
            [UseNum, ZeroEquipList]
    end.

%% 更改物品格子位置
change_goods_cell(GoodsInfo, Location, Cell) ->
    db_agent:change_goods_cell(Location, Cell, GoodsInfo#goods.id),
    NewGoodsInfo = GoodsInfo#goods{ location=Location, cell=Cell },
    ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
    NewGoodsInfo.

%% 更改物品数量
change_goods_num(GoodsInfo, Num) ->
    db_agent:change_goods_num(GoodsInfo#goods.id, Num),
    NewGoodsInfo = GoodsInfo#goods{ num=Num },
    ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
    NewGoodsInfo.

%% 更改物品格子位置和数量
change_goods_cell_and_num(GoodsInfo, Location, Cell, Num) ->
    db_agent:change_goods_cell_and_num(GoodsInfo, Location, Cell, Num),
    NewGoodsInfo = GoodsInfo#goods{ location=Location, cell=Cell, num=Num },
    ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
    NewGoodsInfo.

%% 更改物品耐久度
change_goods_use(GoodsInfo, UseNum) ->
    db_agent:change_goods_use(GoodsInfo, UseNum),
    NewGoodsInfo = GoodsInfo#goods{ use_num=UseNum },
    ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
    NewGoodsInfo.

%% 邮件发送新物品 return record goods 先生成物品，再发送邮件。Bind是否绑定状态。
add_new_goods_by_mail(ToNickname,TypeId,Bind,Num,Title,Content) ->
	GoodsTypeInfo = goods_util:get_goods_type(TypeId),
	if
		is_record(GoodsTypeInfo,ets_base_goods) ->
			NewNum =
			if
				GoodsTypeInfo#ets_base_goods.max_overlap > 1 andalso GoodsTypeInfo#ets_base_goods.max_overlap > Num ->
					Num;
				GoodsTypeInfo#ets_base_goods.max_overlap > 1 andalso GoodsTypeInfo#ets_base_goods.max_overlap =< Num ->
					GoodsTypeInfo#ets_base_goods.max_overlap;
				true ->
					1
			end,
			case Bind of 
				0 -> BindType = 0;
				2 -> BindType = 2;
				_ -> BindType = 2
			end,			
			NewGoods = goods_util:get_new_goods(GoodsTypeInfo),
			NewGoods2 = NewGoods#goods{player_id = 0,location = 4 ,cell = 0,num = NewNum ,bind= BindType},
			NewGoodsInfo=add_goods(NewGoods2),
			%%清理ets
			Pattern1=#goods{id=NewGoodsInfo#goods.id},
			Pattern2=#goods_attribute{player_id = 0,gid=NewGoodsInfo#goods.id},
			ets:match_delete(?ETS_GOODS_ONLINE, Pattern1),
			ets:match_delete(?ETS_GOODS_ATTRIBUTE, Pattern2),
			%%
			Name = tool:to_list(ToNickname),			
			lib_mail:send_sys_mail([Name], Title, Content, NewGoodsInfo#goods.id,NewGoodsInfo#goods.goods_id,NewGoodsInfo#goods.num, 0,0),
			NewGoodsInfo;
		true ->
			{}
	end.
				
%%保存物品buff信息
save_goods_buff(PlayerStatus, GoodsBuffs) ->
	Now = util:unixtime(),
	%%更新玩家buff的时间
	db_agent:update_pbuff_time(Now, PlayerStatus#player.id),
	%%保存数值有变化的 现在只有气血包和法力包
	%%删除过期的和数值小于0的
	F = fun(Elem, AccIn) ->
				 {GoodsId, Data, ExpireTime} = Elem,
				 if
					 GoodsId =:= 23006 orelse GoodsId =:= 23106 ->
						 if
							 Data =< 0 ->
								 db_agent:del_goods_buff(PlayerStatus#player.id,GoodsId),
								 AccIn;
							 true ->
								 db_agent:update_goods_buff(PlayerStatus#player.id,GoodsId,
															ExpireTime,Data),
								[Elem|AccIn] 
						 end;
					 
					 ExpireTime < Now ->
				 		db_agent:del_goods_buff(PlayerStatus#player.id,GoodsId),
						AccIn;
					 true ->
						 [Elem|AccIn]
				 end
		 end,
	lists:foldl(F,[],GoodsBuffs).

%% 更新玩家物品buff效果
update_goods_buff_action(Status, Type) ->
	GoodsBuffs = get_player_goodsbuffs(),
	{Change, NGoodsBuffs, NewStatus} = update_goods_buff(Status, GoodsBuffs, Type),
	put(goods_buffs, NGoodsBuffs),
	misc:cancel_timer(update_goods_buff_timer),
 	Update_goods_buff_timer = erlang:send_after(?BUFF_AND_SITADDEXP_TIMESTAMP, self(), {'UPDATE_GOODS_BUFF', auto}),
	put(update_goods_buff_timer, Update_goods_buff_timer),
	if 
		Change =:= yes ->
			mod_player:save_online_diff(Status, NewStatus);
	   	true -> 
			skip
	end,
	%% 物品buffTimer 检查发包数量，异常包数量断开连接
	R2 = lib_hack:check_socket_count(Status),
	if 
		R2 == stop ->
		   	spawn(fun()->
				Time = util:unixtime(),
				db_agent:insert_kick_off_log(Status#player.id, Status#player.nickname, 2, Time, Status#player.scene, Status#player.x, Status#player.y)
			end),
			mod_player:stop(NewStatus#player.other#player_other.pid, 7);
	   	true ->
			skip
	end,
	{NewStatus, NGoodsBuffs}.
	
%%更新玩家物品buff效果 return {yes/no,newPlayer}
update_goods_buff(PlayerStatus, GoodsBuffs) ->
	update_goods_buff(PlayerStatus,GoodsBuffs, auto).


update_goods_buff(PlayerStatus, GoodsBuffs, Type)  ->
	Now = util:unixtime(),
	%%更新玩家buff的时间
	case Type of
		auto ->
			skip;
		_OtherType ->
			db_agent:update_pbuff_time(Now, PlayerStatus#player.id)
	end,
	{NewGoodsBuffs,NewPlayer} = get_most_newgbuffs(GoodsBuffs, PlayerStatus, Now),
	if NewPlayer#player.hp > 0 ->
			F = fun(GoodsBuff,{PS, EBuffs}) ->
						{EBuffGid, EData, EExpireTime} = GoodsBuff,
					if  
						%%气血包
						EBuffGid == 23006 ->
							if
								Type =:= auto ->
							DiffHP = PS#player.hp_lim - PS#player.hp,
							DataValue = tool:to_integer(tool:to_list(EData)),
							case 
									DiffHP > 0 andalso DataValue > 0 andalso PS#player.hp > 0 
									andalso lib_arena:is_arena_scene(PS#player.scene) =:= false 			%% 战场不可以使用气血包
									andalso lib_scene:is_fst_scene(PS#player.scene) =:= false  				%% 封神台不可以使用气血包
									andalso lib_scene:is_zxt_scene(PS#player.scene) =:= false  				%% 诛仙台不可以使用气血包
									andalso lib_war:is_war_server() =:= false								%% 跨服专服不能使用气血包
									andalso lib_scene:is_td_scene(PS#player.scene) =:= false  				%% 塔防不能使用气血包
									andalso PS#player.scene =/= ?SKY_RUSH_SCENE_ID 							%% 空岛不能使用气血包
									andalso PS#player.scene =/= ?CASTLE_RUSH_SCENE_ID						%% 九霄攻城战不能使用气血包
									andalso lib_coliseum:is_coliseum_scene(PS#player.scene)	 =:= false		%% 竞技场不可以使用气血包
									andalso lib_era:is_era_scene(PS#player.scene) =:= false					%% 封神纪元不可以使用气血包
							of
								true ->
									MinusHP = 
										case DiffHP > 20000 of
											true ->
												20000;
											false ->
												DiffHP
										end,
									if 
										DataValue > MinusHP ->
%% 											NewGoodsBuff = GoodsBuff#goods_buff{data = DataValue - DiffHP},
											NewGoodsBuff = {EBuffGid, (DataValue - MinusHP), EExpireTime},
											HP = PS#player.hp+MinusHP;
										true ->
											HpExpireTime = 
												case Type =:= auto of
													true ->
														case lib_hook:is_auto_use_goods(PS, 1) of
															true ->
																EExpireTime;
															false ->
																Now + 1
														end;
													false ->
														Now + 1
												end,
%% 											NewGoodsBuff = GoodsBuff#goods_buff{data =0, expire_time = HpExpireTime},
											NewGoodsBuff = {EBuffGid, 0, HpExpireTime},
											HP = PS#player.hp + DataValue
									end,			
									NewPS = PS#player{hp = HP},
									
									spawn(fun()->
										%% 发送人物改变信息
										{ok, HpBinData} = pt_13:write(13016, [NewPS#player.id, NewPS#player.hp, NewPS#player.mp]),
										mod_scene_agent:send_to_area_scene(NewPS#player.scene, NewPS#player.x, NewPS#player.y, HpBinData),
										%% 更新队伍成员气血
										lib_team:update_team_player_info(NewPS),
										%% 发送气血包改变值
										TransGoodsBuff = goods_buff_trans_to_proto([NewGoodsBuff]),
										{ok, BinData} = pt_13:write(13014, TransGoodsBuff),
										lib_send:send_to_sid(NewPS#player.other#player_other.pid_send, BinData)
									end),
									{NewPS, [NewGoodsBuff|EBuffs]};
								false ->
									{PS, [GoodsBuff|EBuffs]}
							end;
								true ->
									{PS, [GoodsBuff|EBuffs]}
							end;
						%%法力包
						EBuffGid == 23106 ->
							if
								Type =:= auto ->
							DiffMP = PS#player.mp_lim - PS#player.mp,
							DataValue = tool:to_integer(tool:to_list(EData)),
							case 
									DiffMP > 0 andalso DataValue > 0 andalso 
									lib_arena:is_arena_scene(PS#player.scene) =:= false 
									andalso lib_war:is_war_server() =:= false 	%%跨服专服不能是篮包
%% 									andalso	lib_scene:is_fst_scene(PlayerStatus#player.scene) =:= false
%% 									andalso	lib_scene:is_zxt_scene(PlayerStatus#player.scene) =:= false
%% 									andalso lib_scene:is_td_scene(PlayerStatus#player.scene) =:= false  	%% 塔防不能使用法力包
									andalso PS#player.scene =/= ?SKY_RUSH_SCENE_ID 							%% 空岛不能使用法力包
									andalso lib_coliseum:is_coliseum_scene(PS#player.scene)	 =:= false		%% 竞技场不可以使用法力包
							of
								true ->
									if
										DataValue > DiffMP ->
%% 											NewGoodsBuff = GoodsBuff#goods_buff{data = DataValue - DiffMP},
											NewGoodsBuff = {EBuffGid, (DataValue - DiffMP), EExpireTime},
											MP = PS#player.mp_lim;
										true ->
											MpExpireTime = 
												case Type =:= auto of
													true ->
														case lib_hook:is_auto_use_goods(PS, 2) of
															true ->
																EExpireTime;
															false ->
																Now + 1
														end;
													false ->
														Now + 1
												end,
%% 											NewGoodsBuff = GoodsBuff#goods_buff{data = 0, expire_time = MpExpireTime},
											NewGoodsBuff = {EBuffGid, 0, MpExpireTime},
											MP = PS#player.mp + DataValue
									end,
									NewPS=PS#player{mp = MP},
									spawn(fun() -> 
										lib_player:send_player_attribute2(NewPS, 3),
										TransGoodsBuff = goods_buff_trans_to_proto([NewGoodsBuff]),
										{ok, BinData} = pt_13:write(13014, TransGoodsBuff),
										lib_send:send_to_sid(NewPS#player.other#player_other.pid_send, BinData)
									end),
									{NewPS, [NewGoodsBuff|EBuffs]};
								false ->
									{PS, [GoodsBuff|EBuffs]}
							end;
								true ->
									{PS, [GoodsBuff|EBuffs]}
							end;
						%%其他buff效果	
						true ->
							%%检查更新的buff数据
							PBuffs = PS#player.other#player_other.goods_buff,%%去原来的buff数据
							CheckPBuffs = check_player_buff_update(PBuffs, GoodsBuff, PS, Now),%%计算更新的buff数据
							{PS#player{other = PS#player.other#player_other{goods_buff = CheckPBuffs}},[GoodsBuff|EBuffs]}
						end
				end,
			NewPlayer0 = NewPlayer#player{other = NewPlayer#player.other#player_other{goods_buff = #goods_cur_buff{}}},
			{NewPlayer1, NGoodsBuffsRest} = lists:foldl(F, {NewPlayer0, []}, NewGoodsBuffs),
			%%获取新的buff数据
			[NHp,NMp,NHpL,NMpL,NExpM,NSpiM,NDefM,NPetM,NPeachM,NTurnedM] = get_check_buffdata(NewPlayer1),
			%%获取过去的buff数据
			[PreHp,PreMp,PreHpL,PreMpL,PreExpM,PreSpiM,PreDefM,PrePetM,PrePeachM,PreTurnedM] = get_check_buffdata(NewPlayer),
			if
				%%加成系数值有改变则重新统计人物属性
				PreHpL =/= NHpL orelse PreMpL =/= NMpL orelse PreDefM =/= NDefM orelse PreTurnedM =/= NTurnedM ->
					Turned28043 = lists:keyfind(28043,1,NGoodsBuffsRest),
					Turned28047 = lists:keyfind(28047,1,NGoodsBuffsRest),
					Turned31216 = lists:keyfind(31216,1,NGoodsBuffsRest),
					if Turned28043 =/= false orelse Turned28047 =/= false orelse Turned31216 =/= false ->
						   if Turned28043 =/= false orelse Turned28047 =/= false->
								  if Turned28043 =/= false ->
										 {_EGoodsId, EValue, _ETime} = Turned28043;
									 true ->
										 {_EGoodsId, EValue, _ETime} = Turned28047
								  end;
							  true ->
								   {_EGoodsId, EValue, _ETime} = Turned31216
						   end,
						   {MonId,_BuffId} = EValue,
						   if _EGoodsId =:= 31216 ->
								  {_MonId,{Fields,_Value,_BuffId}} = data_agent:get_chr_turned_buff_id(MonId,NewPlayer#player.career,NewPlayer#player.sex);
							  _EGoodsId =:= 28047 ->
								  {_MonId,{Fields,_Value,_BuffId}} = data_agent:get_chr_snow_buff_id(28047);
							  true ->
								   {_MonId,{Fields,_Value,_BuffId}} = data_agent:get_turned_buff_id(MonId)
						   end,
						  	TempNewPlayer = lib_player:count_player_attribute(NewPlayer1),						   
							NewPlayer2 = TempNewPlayer#player{other = TempNewPlayer#player.other#player_other{turned = Fields}},
							{ok,Data12066} = pt_12:write(12066,[NewPlayer2#player.id,NewPlayer2#player.other#player_other.turned]),						   
							mod_scene_agent:send_to_area_scene(NewPlayer2#player.scene,NewPlayer2#player.x, NewPlayer2#player.y, Data12066),
							lib_player:send_player_attribute(NewPlayer2, 2),
							mod_player:save_online_diff(TempNewPlayer, NewPlayer2),
							NewPlayer2;
						true ->
							case lists:keyfind(28045,1,NGoodsBuffsRest) of
								{_EGoodsId, EValue, _ETime} ->
									{MonId,_BuffId} = EValue,
									{_M,{Fields,_V,_B}} = data_agent:get_turned_buff_id(MonId),
									TempNewPlayer = lib_player:count_player_attribute(NewPlayer1),
									NewPlayer2 = TempNewPlayer#player{other = TempNewPlayer#player.other#player_other{turned = Fields}},
									{ok,Data12066} = pt_12:write(12066,[NewPlayer2#player.id,NewPlayer2#player.other#player_other.turned]),
									mod_scene_agent:send_to_area_scene(NewPlayer2#player.scene,NewPlayer2#player.x, NewPlayer2#player.y, Data12066),
									lib_player:send_player_attribute(NewPlayer2, 2),
									mod_player:save_online_diff(TempNewPlayer, NewPlayer2),
									NewPlayer2;
								
								false ->
									case lists:keyfind(28056, 1, NGoodsBuffsRest) of
										false ->
											NewPlayer2 = lib_player:count_player_attribute(NewPlayer1),
											lib_player:send_player_attribute(NewPlayer2, 1),
											NewPlayer2;
										{_EGoodsId, {MonId,_BuffId}, _ETime} ->
											TempNewPlayer = lib_player:count_player_attribute(NewPlayer1),						   
											NewPlayer2 = TempNewPlayer#player{other = TempNewPlayer#player.other#player_other{turned = MonId}},
											{ok,Data12066} = pt_12:write(12066,[NewPlayer2#player.id,NewPlayer2#player.other#player_other.turned]),						   
											mod_scene_agent:send_to_area_scene(NewPlayer2#player.scene,NewPlayer2#player.x, NewPlayer2#player.y, Data12066),
											lib_player:send_player_attribute(NewPlayer2, 2),
											mod_player:save_online_diff(TempNewPlayer, NewPlayer2),
											NewPlayer2
									end
							end
					end;
				true ->
					NewPlayer2 = NewPlayer1
			end,
			%%获取最新数值
			if
				%%auto 且有变化更新
				(Type =:= auto) 
				  andalso (PreHpL =/= NHpL orelse PreMpL =/= NMpL 
						  orelse PreExpM =/= NExpM orelse PreSpiM =/= NSpiM 
						  orelse PreDefM =/= NDefM orelse PrePetM =/= NPetM 
						  orelse PrePeachM =/= NPeachM orelse PreTurnedM =/= NTurnedM) ->
					NewBuffList = goods_buff_trans_to_proto(NGoodsBuffsRest),
					{ok, BinData} = pt_13:write(13014, NewBuffList),
					lib_send:send_to_sid(NewPlayer2#player.other#player_other.pid_send, BinData),
					Change = yes;
				%%auto 
				Type =:= auto ->
					if
						PreHp =/= NHp orelse PreMp =/= NMp ->
							Change = yes;
						true ->
							Change = no
					end;
				%%force 强制更新
				true ->
					NewBuffList = goods_buff_trans_to_proto(NGoodsBuffsRest),
					{ok, BinData} = pt_13:write(13014, NewBuffList),
    				lib_send:send_to_sid(NewPlayer2#player.other#player_other.pid_send, BinData),
					Change = yes
			end,
			%% 定时保存数据
			WalkTime = Now rem (600+ 20), 
			case (WalkTime - 600) >= 0 of
				true ->
					%%借助定时器清理垃圾内存
					gen_server:cast(NewPlayer2#player.other#player_other.pid_goods,'garbage_collect'),
					NewGoodsBuffsEnd = save_goods_buff(NewPlayer2, NGoodsBuffsRest);
				false ->
					NewGoodsBuffsEnd = NGoodsBuffsRest
			end,
			{Change, NewGoodsBuffsEnd, NewPlayer2};
		true ->
			{no, GoodsBuffs, NewPlayer}
	end.

check_player_buff_update(PBuffs, GoodsBuff, PS, Now) ->
	{BuffGid, {Value, _LastTime}, ExpireTime} = GoodsBuff,
	case BuffGid of
		23400 -> %%气血
			PBuffs#goods_cur_buff{hp_lim = Value};
		23406 -> %%魔法
			PBuffs#goods_cur_buff{mp_lim = Value};
		23203 -> %%经验
			if
				ExpireTime - Now < 30 ->
					lib_hook:is_auto_use_goods(PS, 3);
				true ->
					skip
			end,
			PBuffs#goods_cur_buff{exp_mult = Value};
		23303 -> %%灵力
			PBuffs#goods_cur_buff{spi_mult = Value};
		23403 -> %%防御
			PBuffs#goods_cur_buff{def_mult = Value};
		24102 -> %%灵兽经验
			PBuffs#goods_cur_buff{pet_mult = Value};
		23409 -> %%蟠桃
			PBuffs#goods_cur_buff{peach_mult = Value};
		28043 -> %%变身(幻化符)
			{_id,{Fields,Value2,_BuffId}} = data_agent:get_turned_buff_id(Value),
			Values = lib_goods_use:get_turned_add_value(PS,Fields,Value2),
			PBuffs#goods_cur_buff{turned_mult = Values};
		31216 -> %%变身(圣诞变身符)
			{_id,{Fields,Value2,_BuffId}} = data_agent:get_chr_turned_buff_id(PS#player.career,PS#player.sex,Value),
			Values = lib_goods_use:get_turned_add_value(PS,Fields,Value2),
			PBuffs#goods_cur_buff{turned_mult = Values};
		28045 -> %%变身(幻化体验卡，新手任务专用)
			{_id,{Fields,Value2,_BuffId}} = data_agent:get_turned_buff_id(Value),
			Values = lib_goods_use:get_turned_add_value(PS,Fields,Value2),
			PBuffs#goods_cur_buff{turned_mult = Values};
		28047 -> %%变身(幻化符)
			{_id,{Fields,Value2,_BuffId}} = data_agent:get_turned_buff_id(Value),
			Values = lib_goods_use:get_turned_add_value(PS,Fields,Value2),
			PBuffs#goods_cur_buff{turned_mult = Values};
		24108 -> %%灵兽经验
			PBuffs#goods_cur_buff{pet_mult_exp = Value};
		23500 -> %%灵兽经验
			PBuffs#goods_cur_buff{culture = Value};
		31217 -> %%圣诞坐骑
			PBuffs#goods_cur_buff{chr_mount = Value};
		31218 -> %%圣诞灵兽
			PBuffs#goods_cur_buff{chr_pet = Value};
		_ ->
			PBuffs
	end.

get_check_buffdata(PlayerStatus) ->
	#player{hp = Hp,
			mp = Mp,
			other = PlayerOther} = PlayerStatus,
	PBuffs = PlayerOther#player_other.goods_buff,
	#goods_cur_buff{hp_lim = HpL,
					mp_lim = MpL,	
					exp_mult = ExpM, 	
					spi_mult = SpiM,
					def_mult = DefM,	
					pet_mult = PetM,
					peach_mult = PeachM,
					turned_mult = TurnedM} = PBuffs,
	[Hp,Mp,HpL,MpL,ExpM,SpiM,DefM,PetM,PeachM,TurnedM].

get_most_newgbuffs(GoodsBuffs, Player, Now) ->
	%%更新玩家buff的时间
    PlayerId = Player#player.id,
%% 	db_agent:update_pbuff_time(Now, PlayerId),
%% ?DEBUG("PlayerId:~p, GoodsBuffs:~p",[PlayerId, GoodsBuffs]),
	lists:foldl(fun(Elem, AccIn) ->
						{NewBuffs,EPlayer} = AccIn,
						{BuffGid, Value, ExpireTime} = Elem,
						if  
							BuffGid =:= 23006 orelse BuffGid =:= 23106 ->
								if
									Value =< 0 ->
										db_agent:del_goods_buff(PlayerId,BuffGid),
										{NewBuffs, EPlayer};
									true ->%%暂时不更新气血包，法力包的数值
										{[Elem|NewBuffs],EPlayer}
								end;
							ExpireTime < Now  ->
								%%直接删除多余的buff数据
								if 	
									%%变身BUFF
 									BuffGid =:= 28043 orelse BuffGid =:= 28045 orelse BuffGid =:= 28047 orelse BuffGid =:= 31216 orelse BuffGid =:= 28056 ->	
										if EPlayer#player.other#player_other.turned == 0 ->
											   NewPlayer2 = EPlayer;
										   true ->
											   {OldMid,_B} = Value,
											   if BuffGid =:= 31216 ->
													   {_MonId,{Fields,Value2,_BuffId}} = data_agent:get_chr_turned_buff_id(OldMid,EPlayer#player.career,EPlayer#player.sex);
												  BuffGid =:= 28056 ->
													  Fields = 0,
													  Value2 = 0;
												   true ->
													   {_MonId,{Fields,Value2,_BuffId}} = data_agent:get_turned_buff_id(OldMid)
											   end,
%% 											   ?DEBUG("BuffGid:~p", [BuffGid]),
											   ValueList = lib_goods_use:get_turned_values(EPlayer,Fields,-Value2),
											   NewPlayer = lib_player_rw:set_player_info_fields(EPlayer, ValueList),
											   NewPlayer2 = NewPlayer#player{other = NewPlayer#player.other#player_other{turned = 0,
																						  goods_buff = NewPlayer#player.other#player_other.goods_buff#goods_cur_buff{turned_mult = []}}},
											   %%发送玩家属性变更通知到客户端,这就是 13001！！！！！！！！！！！！！
											   lib_player:send_player_attribute(NewPlayer2,2),
											   %%通知场景，模型改变
											   {ok,Data12066} = pt_12:write(12066,[NewPlayer2#player.id,NewPlayer2#player.other#player_other.turned]),
											   mod_scene_agent:send_to_area_scene(NewPlayer2#player.scene,NewPlayer2#player.x, NewPlayer2#player.y, Data12066),
											   NewPlayer2
										end;
									%%取消圣诞坐骑
									BuffGid =:= 31217 ->
										EPlayer1 = lib_goods_use:cancel_chr_mount(EPlayer,Value),
										NewPlayer2 = EPlayer1;
									%%取消圣诞灵兽
									BuffGid =:= 31218 ->
										EPlayer1 = lib_goods_use:cancel_chr_pet(EPlayer,Value),
										NewPlayer2 = EPlayer1;
									true -> 
										NewPlayer2 = EPlayer
								end,
								db_agent:del_goods_buff(PlayerId,BuffGid),
								{NewBuffs,NewPlayer2};
							true ->
								%%人物模型变身
								if BuffGid =:= 28043 orelse BuffGid =:= 28045 orelse BuffGid =:= 28047 orelse BuffGid =:= 31216 orelse BuffGid =:= 28056 ->
									   {OldMid,_B} = Value,
									   if BuffGid =:= 31216  ->
											  {_MonId,{Fields,Value2,_BuffId}} = data_agent:get_chr_turned_buff_id(OldMid,Player#player.career,Player#player.sex);
										  BuffGid =:= 28047  ->
											  {_MonId,{Fields,Value2,_BuffId}} = data_agent:get_chr_snow_buff_id(28047);
										   BuffGid =:= 28056 ->
											   Fields = OldMid,
											   Value2 = 0;
										  true ->
											  {_MonId,{Fields,Value2,_BuffId}} = data_agent:get_turned_buff_id(OldMid)
									   end,
									   if BuffGid =:= 31216 orelse BuffGid =:= 28056 ->
											  BuffValues = lib_goods_use:get_chr_turned_add_value(EPlayer,Fields,Value2),
											  NewPlayer1 = EPlayer#player{other = EPlayer#player.other#player_other{turned = Fields,
																			goods_buff = EPlayer#player.other#player_other.goods_buff#goods_cur_buff{turned_mult = [BuffValues]}}},
											  NewPlayer2 = lib_player:count_player_attribute(NewPlayer1),
											  {[Elem|NewBuffs],NewPlayer2};
										  true ->
											  {[Elem|NewBuffs],EPlayer}
									   end;								
								   true ->
									   {[Elem|NewBuffs],EPlayer}
								end
%% 								if BuffGid =:= 31216 andalso EPlayer#player.other#player_other.goods_buff#goods_cur_buff.chr_fash == [] -> 
%% 									   PropValueList = data_agent:get_chr_fash_eft(EPlayer#player.career),
%% 									   PropValueAddList = goods_util:prop_value_add(PropValueList,add),
%% 									   EPlayer1 = lib_player_rw:set_player_info_fields(EPlayer, PropValueAddList),
%% 									   EPlayer2 = EPlayer1#player{other = EPlayer1#player.other#player_other{
%% 													goods_buff = EPlayer1#player.other#player_other.goods_buff#goods_cur_buff{chr_fash = [PropValueList]}}},
%% 												%%发送玩家属性变更通知到客户端,这就是 13001！！！！！！！！！！！！！
%% 										lib_player:send_player_attribute(EPlayer2,2),
%% 										{[Elem|NewBuffs],EPlayer2};
%% 								   true ->
%% 									   {[Elem|NewBuffs],EPlayer}
%% 								end
						end
				end, {[],Player}, GoodsBuffs).

%%转换到协议格式
goods_buff_trans_to_proto(GoodsBuffList) ->
	Now = util:unixtime(),
	F = fun(Elem) ->
				{GoodsTypeId, Value, ExpireTime} = Elem,
				if
					GoodsTypeId == 23006 orelse GoodsTypeId == 23106 ->
						LeftTime =
							if
								ExpireTime > Now + 10 ->
									0;
								true ->
									trunc(ExpireTime) - Now
							end,
						[GoodsTypeId,Value,LeftTime];
					GoodsTypeId =:= 28043 ->
						{MonId,BuffId} = Value,
						{_Mid,{_Tid,FieldValue,_B}} = data_agent:get_turned_buff_id(MonId),
						LeftTime = trunc(ExpireTime) - Now,
						[BuffId,FieldValue,LeftTime];
					GoodsTypeId =:= 28045 ->
						{MonId,BuffId} = Value,
						NewBuffId = BuffId + 100,
						{_Mid,{_Tid,FieldValue,_B}} = data_agent:get_turned_buff_id(MonId),
						LeftTime = trunc(ExpireTime) - Now,
						[NewBuffId,FieldValue,LeftTime];
					true ->					
						BUffGid = get_buff_goodstypeid(GoodsTypeId, Value),
						LeftTime = trunc(ExpireTime) - Now,
						[BUffGid,0,LeftTime]
				end
		end,
	lists:map(F, GoodsBuffList).

%% 删除物品
delete_goods(GoodsId) ->
    db_agent:delete_goods(GoodsId),
    Pattern = #goods_attribute{ gid=GoodsId, _='_'},
    ets:match_delete(?ETS_GOODS_ATTRIBUTE, Pattern),
	ets:delete(?ETS_GOODS_ONLINE,GoodsId),
    ok.

%% ---------------------------------------
%%删除诛邪仓库的全部物品的相关属性
delete_all_box_goods(PlayerId) ->
	db_agent:delete_all_box_goods(PlayerId).
delete_all_box_goods_attribute(GoodsList) ->
	lists:foreach(fun(Goods) -> spawn(fun()->db_agent:delete_all_box_goods_attribute(Goods#goods.id)end) end, GoodsList).

ets_delete_box_goods_attribute(GoodsId) ->
	Pattern = #goods_attribute{ gid=GoodsId, _='_'},
    ets:match_delete(?ETS_GOODS_ATTRIBUTE, Pattern).
%% -------------------------------------- 


%%-------------------------------------
%%角色金钱修改的统一接口 返回PlayerStatus
%%-------------------------------------
%% 扣除角色金钱
%%PointId消费点
cost_money(PlayerStatus, Cost, Type, PointId) ->
	if
		Cost > 0 ->
			[H1, H2, _H3, _H4] = integer_to_list(PointId),
			Is_Enough_Money =
				case [H1, H2] of
					"17" ->
						goods_util:is_enough_money_chk_db(PlayerStatus,Cost,Type);
					"18" ->
						goods_util:is_enough_money_chk_db(PlayerStatus,Cost,Type);
					_ ->
						goods_util:is_enough_money(PlayerStatus,Cost,Type)
				end,
			case Is_Enough_Money of
				true ->
					NewCost = abs(Cost),
    				NewPlayerStatus = goods_util:get_cost(PlayerStatus, NewCost, Type),
					db_agent:cost_money(PlayerStatus, NewCost, Type, PointId);
				false ->
					NewPlayerStatus = PlayerStatus
			end,  
    		NewPlayerStatus;
		true ->
			PlayerStatus
	end.

%% 加角色金钱
%%PointId消费点
add_money(PlayerStatus, Sum, Type, PointId) ->
	NewSum = abs(Sum),
	NewPlayerStatus = goods_util:add_money(PlayerStatus, NewSum, Type),
	spawn(fun()-> db_agent:add_money(PlayerStatus,NewSum,Type, PointId) end),
	NewPlayerStatus.

%%end.

%%积分消耗
cost_score(PlayerStatus, Cost, Type, PointId) ->
	NewCost = abs(Cost),
	[Score] = db_agent:query_player_score(PlayerStatus#player.id),
	if
		Score >= NewCost ->
			db_agent:cost_score(PlayerStatus,NewCost,Type,PointId),
			PlayerStatus#player{arena_score = Score - NewCost};
		true ->
			PlayerStatus
	end.
			
	
%% 物品绑定
bind_goods(GoodsInfo) ->
	%%坐骑绑定
	if GoodsInfo#goods.type == 10 andalso GoodsInfo#goods.subtype == 22 ->
		   MountCount = length(goods_util:get_mount_cell(GoodsInfo#goods.player_id,4)),
		   %%将坐骑放入到cell 200之后，间接在背包里隐藏坐骑
		   if MountCount == 0 ->
				  NewCell = 200;
			  true ->
				  NewCell = 200 + MountCount
		   end,
		   NewGoodsInfo = GoodsInfo#goods{ bind=2, trade=1, cell = NewCell };
	   true ->
		   NewGoodsInfo = GoodsInfo#goods{ bind=2, trade=1 }
	end,
	db_agent:bind_goods(NewGoodsInfo),
    ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
    NewGoodsInfo.

%%-----------
%%坐骑相关
%%-----------
%%坐骑状态切换开关
change_goods_mount(PlayerStatus,MountInfo) ->
	if
		is_record(MountInfo,goods) ->
			NewMountInfo = bind_goods(MountInfo),
			%%刷新用户背包,让使用后的坐骑从背包里
			lib_player:refresh_client(PlayerStatus#player.other#player_other.pid_send, 2),
			%%第一次使用绑定并生成坐骑信息
			lib_mount:change_mount(PlayerStatus,MountInfo),
			{ok, BIN} = pt_15:write(15000, [NewMountInfo, 0, []]),
    		lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BIN),
			{ok,PlayerStatus,MountInfo#goods.goods_id};
		true ->
			{fail,PlayerStatus,MountInfo#goods.goods_id}
	end.

		
%%坐骑状态切换开关
change_mount_status(PlayerStatus,MountInfo) ->
	case PlayerStatus#player.mount of
		%%原来没有坐骑
		0 ->
			NewPlayerStatus = get_on_mount(PlayerStatus,MountInfo),
			if MountInfo#goods.icon > 0 ->
				   {ok,NewPlayerStatus,MountInfo#goods.icon};
			   true ->
				   {ok,NewPlayerStatus,MountInfo#goods.goods_id}
			end;
		%%有坐骑
		OldMountId ->				
			%%新旧相同则卸下
			case OldMountId =:= MountInfo#goods.id of
				true ->
					NewPlayerStatus = lib_mount:get_off_mount(PlayerStatus,MountInfo),
					{ok,NewPlayerStatus,0};
				%%不同则先卸旧装备新
				false ->
					OldMountInfo = goods_util:get_goods(OldMountId),
					if
						is_record(OldMountInfo,goods) ->
							PlayerStatus2 = lib_mount:get_off_mount(PlayerStatus,OldMountInfo);
						true ->
							PlayerStatus2 = PlayerStatus
					end,
					NewPlayerStatus = get_on_mount(PlayerStatus2,MountInfo),
					if MountInfo#goods.icon > 0 ->
						   {ok,NewPlayerStatus,MountInfo#goods.icon};
					   true ->
						   {ok,NewPlayerStatus,MountInfo#goods.goods_id}
					end					
			end
	end.
%%装备坐骑			
get_on_mount(PlayerStatus,MountInfo) ->
	if
		is_record(MountInfo,goods) ->
			NewMountInfo = bind_goods(MountInfo),
			%%刷新用户背包,让使用后的坐骑从背包里
			lib_player:refresh_client(PlayerStatus#player.other#player_other.pid_send, 2),
			%%第一次使用绑定并生成坐骑信息
			lib_mount:change_mount(PlayerStatus,MountInfo),
			{ok, BIN} = pt_15:write(15000, [NewMountInfo, 0, []]),
    		lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BIN),
			[Wq, Yf, _Fbyf,_Spyf,_Zq] = PlayerStatus#player.other#player_other.equip_current,
			Speed = PlayerStatus#player.speed + MountInfo#goods.speed,
			if MountInfo#goods.icon > 0 ->
				   NewMountTypeId = MountInfo#goods.icon;
			   true ->
				   NewMountTypeId = MountInfo#goods.goods_id				   
			end,
			Equip_current = [Wq, Yf, _Fbyf,_Spyf,NewMountTypeId],
			NewPlayerStatus = PlayerStatus#player{
                           mount = MountInfo#goods.id,
						   speed = Speed,
						   other = PlayerStatus#player.other#player_other{
                           		equip_current = Equip_current,
								mount_stren = MountInfo#goods.stren
								}
            	},
			spawn(fun()->db_agent:change_mount_status(MountInfo#goods.id,NewPlayerStatus#player.id)end),
			{ok, BinData} = pt_12:write(12010, [NewPlayerStatus#player.id, Speed, NewMountTypeId,MountInfo#goods.id,MountInfo#goods.stren]),
    		spawn(fun()->mod_scene_agent:send_to_area_scene(NewPlayerStatus#player.scene, NewPlayerStatus#player.x, NewPlayerStatus#player.y, BinData)end),
			NewPlayerStatus;
		true ->
			PlayerStatus
	end.

%% 卸下坐骑
force_off_mount(PlayerStatus) ->
	if
		PlayerStatus#player.mount > 0 ->
			MountInfo = lib_mount:get_mount(PlayerStatus#player.mount),
			NewPlayerStatus = lib_mount:get_off_mount(PlayerStatus,MountInfo),
			lib_player:send_player_attribute(NewPlayerStatus, 3),
			{ok, NewPlayerStatus};		
		true ->
			{ok, PlayerStatus}
	end.
%% 卸下坐骑（战斗用）			
force_off_mount_for_battle(Player) ->
	MountInfo = lib_mount:get_mount(Player#player.mount),
	NewPlayer = lib_mount:get_off_mount(Player, MountInfo),
	lib_player:send_player_attribute(NewPlayer, 3),
	ChangeList = [
   		{mount, NewPlayer#player.mount},
       	{speed, NewPlayer#player.speed},
       	{equip_current, NewPlayer#player.other#player_other.equip_current},
       	{mount_stren, NewPlayer#player.other#player_other.mount_stren}
	],
	{ok, NewPlayer, ChangeList}.		
					
%%-----------
%%清除处理操作
%%-----------
%%当玩家删除角色时，删除有关于这角色的数据
delete_role(PlayerId) ->
    db_agent:lg_delete_role(PlayerId),
    ok.
%%删除玩家物品的过期cd。
del_goods_cd(PlayerId) ->
	Now = util:unixtime(),
	MS_cd = ets:fun2ms(fun(T) when T#ets_goods_cd.player_id == PlayerId  -> 
			T 
		end),
	CdList = ets:select(?ETS_GOODS_CD, MS_cd),
	F = fun(GoodsCd) ->
				if
					GoodsCd#ets_goods_cd.expire_time =< Now andalso GoodsCd#ets_goods_cd.id > 0 ->
						ets:delete_object(?ETS_GOODS_CD, GoodsCd),
						db_agent:del_goods_cd(GoodsCd#ets_goods_cd.id);
					GoodsCd#ets_goods_cd.expire_time =< Now ->
						ets:delete_object(?ETS_GOODS_CD, GoodsCd);
					true ->
						skip
				end
		end,
	lists:map(F, CdList).

%%处理玩家下线物品相关操作
do_logout(PlayerStatus) ->
	GoodsBuffs = get_player_goodsbuffs(),
	save_goods_buff(PlayerStatus, GoodsBuffs),
	del_goods_cd(PlayerStatus#player.id).
	
%% 查看玩家背包是否存在指定ID物品
%% PlayerId 玩家ID
%% GoodsTypeId 物品类型ID
goods_find(PlayerId, GoodsTypeId) ->
	G = goods_util:get_type_goods_list(PlayerId, GoodsTypeId, 4),
	case is_list(G) of
		true ->
			lists:keyfind(GoodsTypeId, 4, G);
		false ->
			false
	end.

%% 判断是否有足够的背包格子
%% GoodsStatus 玩家物品信息
%% GoodsTypeInfo 物品类型信息
%% GoodsNum 物品数量
is_enough_backpack_cell(GoodsStatus, GoodsTypeInfo, GoodsNum) ->
	GoodsList = goods_util:get_type_goods_list(GoodsStatus#goods_status.player_id, 
				  GoodsTypeInfo#ets_base_goods.goods_id, GoodsTypeInfo#ets_base_goods.bind, 4),
	GoodsList1 = [Good || Good <- GoodsList,Good#goods.cell < 200],
    CellNum = goods_util:get_null_cell_num(GoodsList1, GoodsTypeInfo#ets_base_goods.max_overlap, GoodsNum),
    case length(GoodsStatus#goods_status.null_cells) >= CellNum of
		true ->
			{enough, GoodsList, CellNum};
		false ->
			no_enough
	end.

 
%% 从数据表获取物品信息
get_goods_info_from_db(Player_id,Gid)->
	GoodsInfo = goods_util:get_goods_by_id(Gid),
	case is_record(GoodsInfo,goods) of
		true ->
			case goods_util:has_attribute(GoodsInfo) of
				true ->
					AttributeList = goods_util:get_offline_goods_attribute_list(Player_id,Gid),
					%%SuitNum = goods_util:get_suit_num(GoodsStatus#goods_status.equip_suit, GoodsInfo#goods.suit_id);
					SuitNum = 0;
				false ->
					AttributeList =[],
					SuitNum = 0
			end,
			[GoodsInfo, SuitNum, AttributeList];
		Error ->
			?DEBUG("mod_goods info_other:~p", [[Player_id, Gid, Error]]),
            [{}, 0, []]
	end.

%% 装备评价
give_score(PlayerStatus, GoodsId) ->
	case goods_util:is_enough_money(PlayerStatus, 1000, coin) of
		true ->
			case gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'info', GoodsId}) of
				[GoodsInfo, _SuitNum, _AttributeList] ->
					case GoodsInfo#goods.type of
						10 when not(GoodsInfo#goods.grade == 50 andalso GoodsInfo#goods.spirit ==1) ->%%过滤任务神器
							Glv =
								if 
									GoodsInfo#goods.grade > 0 ->
										GoodsInfo#goods.grade;
									true ->
										GoodsInfo#goods.level
								end,
							Gstep =
								if
									GoodsInfo#goods.type =:= 10 andalso GoodsInfo#goods.subtype < 14 andalso GoodsInfo#goods.step > 0 ->
										GoodsInfo#goods.step;
									true ->
										0
								end,
							StoneList = [goods_util:get_goods_type(GoodsInfo#goods.hole1_goods), goods_util:get_goods_type(GoodsInfo#goods.hole2_goods), goods_util:get_goods_type(GoodsInfo#goods.hole3_goods)],
							F = fun(StoneInfo, Sum) ->
										case StoneInfo of 
											{} -> Sum; 
											_-> StoneInfo#ets_base_goods.level + Sum
										end
								end,
							Stone_Lv = lists:foldl(F, 0, StoneList),
							AttributeCount = 
								if 
									GoodsInfo#goods.subtype > 8 andalso GoodsInfo#goods.subtype < 14 ->
										AtbList = goods_util:get_goods_attribute_list(PlayerStatus#player.id, GoodsId, 1),
										erlang:length(AtbList);
									true ->
										0
								end,
							%%附魔属性列表
							MagicAttList = goods_util:get_goods_attribute_list(GoodsInfo#goods.player_id,GoodsId,7),
							MagicStarFun = fun(MagAtt,S) ->
												AttVal = goods_util:get_attribute_value(MagAtt),
												Star = data_magic:get_single_magic_star(GoodsInfo#goods.level,MagAtt#goods_attribute.attribute_id,AttVal),
												Star + S
										end,
							MagicStar = lists:foldl(MagicStarFun, 0, MagicAttList),
							Score = erlang:round(Glv*((GoodsInfo#goods.color+1)/2+1)*5 + Gstep *150 + GoodsInfo#goods.stren*100 + Stone_Lv*60 + AttributeCount*50 + MagicStar * 1.5),
%%单件装备评价公式：（装备等级*装备成色系数）*5+品阶等级*150+强化等级*100+（宝石1等级+宝石2等级+宝石3等级）*100 +法宝属性条数*50 +附魔星级总和*1.5
%% 装备成色系数		白色1.5	绿色2	蓝色2.5	黄色3	紫色3.5
							spawn(fun()->db_agent:mod_goods_score(GoodsId, Score)end),
							NewStatus = cost_money(PlayerStatus, 1000, coin, 1599),
							[1, Score, NewStatus];
						_ ->
							[0, 0, PlayerStatus]
					end;
				_ ->
					[0, 0, PlayerStatus]
			end;
		false ->
			[2, 0, PlayerStatus]
	end.

check_key(List) ->
	A = [],
    case lists:member(1, List) of
		true -> B = lists:append(A, [1]);
	    false -> B = lists:append(A, [0])
	end,	
	case lists:member(2, List) of
		true -> C = lists:append(B, [1]);
	    false -> C = lists:append(B, [0])
	end,
	case lists:member(3, List) of
		true -> D = lists:append(C, [1]);
	    false -> D = lists:append(C, [0])
	end,
	case lists:member(4, List) of
		true -> E = lists:append(D, [1]);
	    false -> E = lists:append(D, [0])
	end,
    E.

%%获取所有已使用的卡key
get_all_use_card(PlayerId)->
	Reds = db_agent:get_all_given(PlayerId),
	Keys = lists:map(fun(E)->[_,_,_,_,_,_,Key] = E, Key end, Reds),
    Result = check_key(Keys),
	%%检查玩家是否拿过首冲礼包、VIP礼包
	case db_agent:get_firstpay_gift_record(PlayerId) of
		[] -> Result2 = lists:append(Result, [0]);
	    _ -> Result2 = lists:append(Result, [1])
	end,
	case db_agent:get_vip_gift_record(PlayerId) of
		[] -> Result3 = lists:append(Result2, [0]);
	    _ -> Result3 = lists:append(Result2, [1])
	end,
    Result3.

%%远古封神卡类激活
active_ygfs_card(Player,Cardstring) ->
	CardInfo = db_agent:check_ygfs_card(Cardstring),
	Player_id = Player#player.id,
	Accname = Player#player.accname,
	Time = util:unixtime(),
	if
		%%在数据库生成的卡号
		CardInfo /= [] ->
			[CardId,_cardstring,Begtime,Endtime,Active,_Pid,Key]= CardInfo,
			%%是否已经使用过同类卡型
			CheckUsed = db_agent:check_ygfs_card_used(Key,Player_id),
			if
				Active =/= 0 ->
					[2,<<>>];
				CheckUsed =/= [] andalso Key =/= 19 ->			%% 19好友邀请礼包
					[5,<<>>];
				Begtime =/= 0 andalso Time < Begtime ->
					[3,<<>>];
				Endtime =/= 0 andalso Time > Endtime ->
					[4,<<>>];
				true ->
					spawn(fun()->db_agent:active_ygfs_card(CardId,Player_id)end),
					[1,Key]
			end;
		%%算法生成的卡号
		CardInfo == [] andalso Cardstring /= [] ->
			PlatFormName = config:get_platform_name(),
			ServerNum = Player#player.sn,
			CardKey = config:get_card_key(),
			case PlatFormName of
				"4399" ->
					MakePhoneActive = util:md5(lists:concat(["vXDKCbm*dwZb+D+*JhMXU%+o","ygfs","S",ServerNum,util:url_encode(tool:to_list(Player#player.accname)),"sj"])),
					case MakePhoneActive == Cardstring of
						true ->
							Key = 22,
							db_agent:active_use_ygfs_card(Cardstring,Player_id,Key),
							[1,Key];
						false ->
							[0,<<>>]
					end;
				undefined ->
					[0,<<>>];
				_ ->
					if
						ServerNum /= undefined andalso CardKey /= undefined ->
							MakeCardString = util:md5(lists:concat([Accname,tool:to_list(ServerNum),CardKey])),
							case string:to_upper(MakeCardString) == string:to_upper(Cardstring) of
								true ->
									Key=1,
									db_agent:active_use_ygfs_card(Cardstring,Player_id,Key),
									[1,Key];
								false ->
									[0,<<>>]
							end;
						true ->
							[0,<<>>]
					end
			end;
		true ->
			[0,<<>>]

	end.

%%检查物品变化
check_goods_diff(GoodsList) ->
	check_diff_good(false, GoodsList, GoodsList).

check_diff_good(true, _GoodsList, _RemainGoodsList) ->
	true;
check_diff_good(false, _GoodsList, []) ->
	false;
check_diff_good(false, GoodsList, [{GoodsId, Num}|ReaminGoodsList]) ->
	NewGoodsList = lists:delete({GoodsId, Num}, GoodsList),
	Result = lists:any(fun(Elem) ->
							   {GoodsIdInner, _NumInner} = Elem,
							   GoodsIdInner =:= GoodsId
					   end, NewGoodsList),
	check_diff_good(Result, GoodsList, ReaminGoodsList).

get_player_goodsbuffs() ->
	case get(goods_buffs) of
		Result when is_list(Result) ->
			Result;
		_ ->
			[]
	end.
update_player_goodsbuffs(Player, GoodsBuffsRst) ->
	case GoodsBuffsRst of
		{update, GoodsBuffs} ->
			put(goods_buffs, GoodsBuffs),
			{_, NGoodsBuffs, PlayerStatus2}=lib_goods:update_goods_buff(Player, GoodsBuffs, force1),
			put(goods_buffs, NGoodsBuffs),
			PlayerStatus2;
		{update, false, GoodsBuffs} ->
			put(goods_buffs, GoodsBuffs),
			{_, NGoodsBuffs, PlayerStatus2}=lib_goods:update_goods_buff(Player, GoodsBuffs, force1),
			put(goods_buffs, NGoodsBuffs),
			PlayerStatus2;%%人物属性不更新
		{update, true, GoodsBuffs} ->
			put(goods_buffs, GoodsBuffs),
			{_, NGoodsBuffs, PlayerStatus2}=lib_goods:update_goods_buff(Player, GoodsBuffs, force2),
			put(goods_buffs, NGoodsBuffs),
			PlayerStatus2;%%需要更新人物属性
		{no_update, GoodsBuffs} ->
			put(goods_buffs, GoodsBuffs),
			Player
	end.
	
%% 	[23400,23401,23402]   气血
%% 	[23406,23407,23408]   魔法
%% 	[23203,23204,23205]   经验
%% 	[23303,23304,23305]   灵力
%% 	[23403,23404,23405]   防御
%% 	[24102,24103]  		     灵兽经验
%% 	[23409,23410,23411]   蟠桃
get_buff_goodstypeid(GoodsTypeId, BuffData) ->
	{Value,LastTime} = BuffData,
	case GoodsTypeId of
		23400 ->
			case Value of
				1.1 ->
					23400;
				1.15 ->
					23401;
				1.2 ->
					23402
			end;
		23406 ->
			case Value of
				1.15 ->
					23406;
				1.3 ->
					23407;
				1.45 ->
					23408
			end;
		23203 ->
			case BuffData of
				 {1.5, 1} ->
					23203;
				{1.5, 24} ->
					23204;
				{2, 1} ->
					23205
			end;
		23303 ->
			case BuffData of
				{1.5, 1} ->
					23303;
				{1.5, 24} ->
					23304;
				{2, 1} ->
					23305
			end;
		23403 ->
			case Value of
				1.1 ->
					23403;
				1.15 ->
					23404;
				1.2 ->
					23405
			end;
		24102 ->
			case LastTime of
				12 ->
					24102;
				24 ->
					24103
			end;
		24108 ->
			24108;
		23409 ->
			case Value of
				2 ->
					23409;
				3 ->
					23410;
				4 ->
					23411
			end;
		28043 ->
			LastTime;
		28045 ->
			LastTime;
		28047 ->
			28047;
		23500 ->
			23500;
		31216 ->
			31216;
		31217 ->
			31217;
		31218 ->
			31218;
		28056 ->
			28056
	end.
		
%%由buffID获取需要删除的物品Id
get_buff_goods_ids(GoodsTypeId) ->
	case GoodsTypeId of
		23400 ->
			[23400,23401,23402];%%气血
		23406 ->
			[23406,23407,23408];%%魔法
		23203 ->
			[23203,23204,23205];%%经验
		23303 ->
			[23303,23304,23305];%%灵力
		23403 ->
			[23403,23404,23405];%%防御
		24102 ->
			[24102,24103];%%灵兽经验
		23409 ->
			[23409,23410,23411];%%蟠桃
		_ ->
			[GoodsTypeId]
	end.

%%获取封神贴id列表
get_hero_card_list()->
	[28350,28351,28352,28353,28354,28355,28356,28357,28358,28359,28360,28361,28362,28363,28364,28365,28366,28367].
%% 	MS = ets:fun2ms(fun(T) when T#ets_base_goods.type=:=80,T#ets_base_goods.subtype=:=20 -> T#ets_base_goods.goods_id end),
%%    	ets:select(?ETS_BASE_GOODS, MS).

%%获取副本令id
get_dungeon_card_list()->
	[28621,28622,28623,28624,28625,28626,28627,28628,28629,28630,28631,28632].

%%返回玩家法宝强化等级
get_player_stren_eff(PlayerId) ->
	Equip_fb = goods_util:get_equip_fb(PlayerId),
	Equip_fb#goods.stren.

%%返回法宝时装强化等级
get_player_fbyf_stren(PlayerId) ->
	Fbyf = goods_util:get_cell_equip(PlayerId,15),
	if
		is_record(Fbyf,goods) ->
			Fbyf#goods.stren;
		true ->
			0
	end.

%% 返回挂是强化等级
get_player_spyf_stren(PlayerId) ->
	Spyf = goods_util:get_cell_equip(PlayerId,16),
	if
		is_record(Spyf,goods) ->
			Spyf#goods.stren;
		true ->
			0
	end.
			
