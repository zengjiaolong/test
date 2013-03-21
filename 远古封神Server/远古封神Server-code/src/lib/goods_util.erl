%%%--------------------------------------
%%% @Module  : goods_util
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description : 物品实用工具类
%%%--------------------------------------
-module(goods_util).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

-compile(export_all).
%% -export(
%%     [
%%         init_goods/0,							%%基础物品初始化
%% 		reload_goods/0,							%%重载入基础物品
%%         init_goods_online/1,					%%初始化玩家物品
%% 		init_goods_buff/4,						%%初始化玩家buff数据
%%         goods_offline/1,						%%玩家下线删除物品
%%         get_ets_info/2,							%%获取ets信息，返回record
%%         get_ets_list/2,							%%获取ets信息，返回list
%%         get_goods_name/1,						%%获取物品名称
%%         get_task_mon/1,							%%取任务怪ID
%%         get_goods_num/3,						%%获取物品数量
%% 		get_goods_num_unbind/3,					%%获取指定位置的未绑定的物品数量	
%% 		get_goods_num_unbind_trade/5,			%%获取指定位置的的的物品数量(绑定情况和交易情况自定义bind:0,非绑，2,绑定；trade:0,可交易，1,不可交易)
%%         get_new_goods/1,						%%由基础数据转换成goods数据
%% 		get_new_goods_add_attribute/1,			%%有基础附加属性规则生成附加属性(暂用于紫装融合预览)
%%         get_current_equip/1,					%% 取当前装备的武器、衣服,坐骑不能从装备信息取(旧函数)
%%         get_current_equip_by_list/2,			%%获取当前装备列表
%%         get_current_equip_by_info/2,			%%获取当前装备列表(旧函数)
%%         get_goods/1,							%%【获取物品信息】（常用）
%% 		get_goods/2,							%%【获取物品信息】
%% 		get_new_goods_by_type/2,				%% 获取最近添加【类型物品】的的信息
%% 		get_player_goods_from_db/1,				%%从数据库获取玩家物品信息
%%         get_goods_type/1,						%%获取【类型物品】信息（常用）
%%         get_add_goods/5,						%%取新加入的物品
%%         get_goods_by_id/1,						%%根据物品id获取物品信息
%%         get_goods_by_cell/3,					%%根据物品cell获取物品
%%         get_goods_list/2,						%%获取物品列表（常用）
%%         get_type_goods_list/4,					%%获取类型物品列表
%%         get_type_goods_list/3,					%%获取类型物品列表
%% 		get_type_goods_info/3,					%%获取类型物品信息
%%         get_mend_list/2,						%%获取修理装备列表（暂废弃）
%%         get_equip_list/3,						%%获取装备类别
%% 		get_equip_cell/3,						%%获取cell物品
%%         get_shop_list/2,						%%获取商店物品列表
%%         get_shop_info/2,						%%获取商店物品信息，用于检查商店是否有这个物品
%%         get_add_goods_attribute/4,				%%取新加入的装备属性
%% 		get_add_attribute_by_type/1,			%%由基础附加属性规则生成附加属性(暂用于紫装融合预览)
%%         get_goods_attribute_info/3,				%%获取物品属性信息（常用）
%% 		get_goods_attribute_info/4,				%%同上
%%         get_goods_attribute_list/2,				%%获取物品属性列表
%%         get_goods_attribute_list/3,				%%同上
%%         get_offline_goods_attribute_list/2,		%%获取离线物品属性列表
%% 		get_offline_goods_attribute_list/3,		%%同上
%%         count_role_equip_attribute/3,			%%【统计角色装备附加属性】（重要）
%%         get_equip_attribute/3,					%%获取装备属性
%%         get_goods_attribute/1,					%%获取装备属性
%%         get_equip_suit/1,						%%获取套装信息
%%         get_suit_num/2,							%%获取套装数量
%%         change_equip_suit/3,					%%更换套装
%%         count_stren_addition/2,					%%统计强化附加属性
%%         count_inlay_addition/1,					%%统计镶嵌附加属性
%%         get_stren_factor/1,						%%装备强化加成系数
%%         get_stren_color_factor/1,				%%装备强化品质加成系数
%%         get_goods_attribute_id/1,				%%装备加成属性类型ID
%%         get_inlay_attribute_id/1,				%%镶嵌宝石的属性类型ID
%%         get_goods_use_num/1,					%%获取装备的使用次数（用于装备磨损，暂无作用）
%%         get_goods_attrition/2,					%%获取装备耐久度(暂无作用)
%%         get_mend_cost/2,						%%获取修理费用（暂无作用）
%%         get_equip_cell/2,						%%获取默认装备格子位置
%%         get_null_cell_num/3,					%%检查物品还需要多少格子数
%%         get_null_cells/2,						%%获取背包空位
%%         get_goods_exp/1,						%%经验卡对应的经验
%%         sort/2,									%% 按格子位置排序
%% 		is_enough_score/3,						%%是否足够积分
%% 		is_enough_shop_score/2,					%%是否足够商城积分
%%         is_enough_money/3,						%%是否足够金钱
%% 		is_enough_money_chk_db/3,				%%检查数据库并判断金钱是否充足
%% 		is_enough_honor/3,						%%是否足够荣誉
%% 		is_enough_feats/3,						%%是否足够功勋
%% 		is_enough_hor_td/3,						%%判断镇妖功勋是否充足
%% 		is_enough_tcsgold_fashion/6,			%%是否足够天蚕丝28404
%%         get_cost/3,								%%计算消费【注意，只改变内存值】
%% 		add_money/3,							%%添加消费【注意，只改变内存值】
%%         get_price_type/1,						%%获取价格类型
%%         has_attribute/1,						%%是否有附加属性
%%         can_equip/4,							%%是否可穿
%%         get_goods_totalnum/1,					%%获取物品总数量
%%         get_consume_type/1,						%%获取消费类型
%%         deeploop/3,								%%循环
%%         list_handle/3,							%%list处理
%% 		merge_goods_effect/2,					%%合并物品效果
%% 		count_noidentify_num/1,					%%获取没有鉴定属性数
%% 		count_inlay_num/1,						%%获取镶嵌数
%% 		get_make_position_goods/2,				%%获取打造装备位置约定信息
%% 		get_goods_anti_attribute_info/2,		%%取装备强化附加抗性属性信息
%% 		get_add_attribute_type_value/1,			%%获取附加属性的类型和值
%% 		get_practise_attribute_value_by_name/2, %%根据修炼规则和属性名字提取修炼属性数值
%% 		get_attribute_id_by_name/1,				%% 取属性ID
%% 		get_attribute_name_by_id/1,				%%获取属性名字
%% 		get_pracitse_attribute_value/3,			%%取修炼属性值
%% 		get_attribute_value/1,					%%根据属性取属性值
%% 		search_goods/1,							%%%%查找物品
%% 		level_to_step/1,						%%等级到阶转换
%% 		get_total_spirit/1,						%%获取法宝修炼所需的最大灵力值
%% 		parse_goods_other_data/1,				%%解释other接口
%% 		parse_goods_other_data/2,				%%解释other接口
%% 		get_equip_player_attribute/2,			%%装备加成的基础属性 
%% 		get_equip_mult_attribute/2,				%%装备属性的系数加成
%% 		get_goods_cd_list/1,					%%获取物品的cd列表
%% 		get_goods_other_data/1,					%%获取物品otherdata
%% 		get_one_equip/2,						%%获取一件装备
%% 		get_mount_info/1,						%%获取坐骑信息
%% 		get_box_null_cells/1,					%%获取诛邪仓库空格子
%% 		parse_goods_addition/1,					%%分析物品附加属性
%% 		get_color_hex_value/1,					%%获取16进制颜色值
%% 		get_realm_to_name/1,					%%获取部落名称
%% 		parse_goods_price_for_shoptype/2,		%%分析商店购买物品价
%% 		get_equip_fb/1,							%%获取身上一件法宝
%% 		get_cell_equip/2,						%%获取身上对应位置的装备
%% 		is_full_suit/1,							%%是否整套套装
%% 		pay_goods_addition/4,					%%购买有附加物品
%% 		get_equip_attribute/2,				%%查询装备附加属性
%% 		get_fashion_random/3,					%%时装随机洗炼属性
%% 		get_fashion_unreplace/1,				%%时装未替换的属性
%% 		delete_goods_attribute/3,				%%删除goods_attribute中的数据
%% 		get_goods_hp_attribute_info/2,			%%取时装强化附加气血上限属性信息
%% 		get_equip_id_list/3,					%%取装备列表id
%% 		get_ring_color4/1,						%%查询身上装备的紫戒指 
%% 		get_magic_random/4,						%%装备附魔属性
%% 		general_magic_prop/2,               	%%生成附魔物品属性
%% 		get_last_magic_prop/2,                	%%查询上一次的附魔属性
%% 		get_offline_goods/2,                   %%取离线玩家的物品
%% 		get_equip_current/1,                   %%查看离线玩家的武器，衣服，坐骑　
%% 		get_goods_type_db/1,                  %%查询物品类型id
%% 		get_goods_list_type_subtype/4        %%根据类型，子类型查询物品
%% 	    get_equip_unreplace/1,                 %%装备未附魔属性
%%			get_goods_info_fields/2,                %%查询物品相关属性
%%        get_goods_data_stren/2                  %%法宝时装和饰品时装相关属性
%%     ]
%% ).

%% 重新载入基础物品
reload_goods()->
	ok = init_goods_type(),
	ok = init_goos_add_attribute(),
	ok = init_shop(),
	ok.
	
init_goods() ->
    %% 初始化物品类型列表
    ok = init_goods_type(),
    %% 初始化装备类型附加属性表
    ok = init_goos_add_attribute(),
	%% 初始化装备套装基础表
	ok = init_goods_suit(),
    %% 初始化装备套装属性表
    ok = init_goods_suit_attribute(),
    %% 初始化装备强化规则表
    ok = init_goos_strengthen(),
    %% 初始化防具强化抗性规则表
    ok = init_goos_strengthen_anti(),
    %% 初始化装备强化额外信息表
    ok = init_goos_strengthen_extra(),
    %% 初始化法宝修炼规则表
    ok = init_goos_practise(),
    %% 初始化宝石合成规则表
    ok = init_goos_compose(),
    %% 初始化宝石镶嵌规则表
    ok = init_goos_inlay(),
	%% 初始化装备分解规则表
	ok = init_goods_idecompose(),
	%% 初始化材料合成规则表
	ok = init_goods_icompose(),
	%% 天降彩石规则表
	ok = init_goods_ore_rule(),
    %% 初始化物品掉落数量规则表
    ok = init_goos_drop_num(),
    %% 初始化物品掉落规则表
    ok = init_goos_drop_rule(),
    %% 初始化商店表
    ok = init_shop(),
	%% 初始化时装基础数据表
    ok = init_base_goos_fashion(),
	%%加载装备附魔基础属性
	ok = init_base_magic(),
    ok.

init_goods_online(PlayerId) ->
    %% 初始化在线玩家背包物品表
    ok = init_goods(PlayerId),
    %% 初始化在线玩家物品属性表
    ok = init_goods_attribute(PlayerId),
	%% 初始化物品cd表
	ok = init_goods_cd(PlayerId),
	%% 初始化副法宝
	ok = init_deputy_equip(PlayerId),
	%%初始化衣橱数据
	lib_wardrobe:init_player_wardrobe(PlayerId),
    ok.

%%当玩家下线时，删除ets物品表
goods_offline(PlayerId) ->
    ets:match_delete(?ETS_GOODS_ONLINE, #goods{ player_id=PlayerId, _='_' }),
    ets:match_delete(?ETS_GOODS_ATTRIBUTE, #goods_attribute{ player_id=PlayerId, _='_' }),
	ets:match_delete(?ETS_GOODS_CD,#ets_goods_cd{player_id = PlayerId, _='_'}), 
	ets:match_delete(?ETS_DEPUTY_EQUIP,#ets_deputy_equip{pid = PlayerId, _='_'}), 
	%%删除衣橱数据
	lib_wardrobe:player_logout(PlayerId),
    ok.

%%删除goods_attribute中的数据
delete_goods_attribute(Player_Id,Gid,AttributeType) ->
	ets:match_delete(?ETS_GOODS_ATTRIBUTE, #goods_attribute{ gid=Gid,attribute_type=AttributeType, _='_' }),
	db_agent:del_goods_attribute(Player_Id,Gid,AttributeType).


%% 初始化基础数据 --------------------------------------------------------------
%% 初始化物品类型列表
init_goods_type() ->
	ets:delete_all_objects(ets_base_goods),
    F = fun(GoodsType) ->
				  GoodsInfo = list_to_tuple([ets_base_goods] ++ GoodsType),
                  ets:insert(?ETS_BASE_GOODS, GoodsInfo)
           end,
    case db_agent:get_base_goods_info() of
        [] -> skip;
        GoodsTypeList when is_list(GoodsTypeList) ->
            lists:foreach(F, GoodsTypeList);
        _ -> skip
    end,
    ok.

%% 重新载入某物品基础数据
init_goods_type(GoodsId) ->
	F = fun(GoodsType) ->
				GoodsInfo = list_to_tuple([ets_base_goods] ++ GoodsType),
				if
					GoodsInfo#ets_base_goods.goods_id == GoodsId ->
                		ets:insert(?ETS_BASE_GOODS, GoodsInfo);
					true ->
						skip
				end
           end,
    case db_agent:get_base_goods_info() of
        [] -> skip;
        GoodsTypeList when is_list(GoodsTypeList) ->
            lists:foreach(F, GoodsTypeList);
        _ -> skip
    end,
    ok.

%% 初始化装备类型附加属性表
init_goos_add_attribute() ->
	ets:delete_all_objects(ets_base_goods_add_attribute),
     F = fun(Attribute) ->
                AttributeInfo = list_to_tuple([ets_base_goods_add_attribute] ++ Attribute),
                ets:insert(?ETS_BASE_GOODS_ADD_ATTRIBUTE, AttributeInfo)
         end,
    case db_agent:get_base_goods_add_attribute() of
        [] -> skip;
        AttributeList when is_list(AttributeList) ->
            lists:foreach(F, AttributeList);
        _ -> skip
    end,
    ok.

%% 初始化装备套装基础表
init_goods_suit() ->
	ets:delete_all_objects(ets_base_goods_suit),
	F = fun(BaseSuit) ->
				BaseSuitInfo = list_to_tuple([ets_base_goods_suit] ++ BaseSuit),
				ets:insert(?ETS_BASE_GOODS_SUIT,BaseSuitInfo)
		end,
	case db_agent:get_base_goods_suit() of
		[] ->skip;
		SuitList when is_list(SuitList) ->
			lists:foreach(F, SuitList);
		_ ->skip
	end,
	ok.

%% 初始化装备套装属性表
init_goods_suit_attribute() ->
	ets:delete_all_objects(ets_base_goods_suit_attribute),
	F = fun(SuitAttribute) ->
				SuitAttributeInfo = list_to_tuple([ets_base_goods_suit_attribute] ++ SuitAttribute),
				ets:insert(?ETS_BASE_GOODS_SUIT_ATTRIBUTE,SuitAttributeInfo)
		end,
	case db_agent:get_base_goods_suit_attribute() of
		[] ->skip;
		SuitAttributeList when is_list(SuitAttributeList) ->
			lists:foreach(F, SuitAttributeList);
		_ ->skip
	end,
	ok.

%% 初始化装备强化规则表
init_goos_strengthen() ->
	ets:delete_all_objects(ets_base_goods_strengthen),
     F = fun(Strengthen) ->
				StrengthenInfo = list_to_tuple([ets_base_goods_strengthen] ++Strengthen),
                ets:insert(?ETS_BASE_GOODS_STRENGTHEN, StrengthenInfo)
         end,
    case db_agent:get_base_goods_strengthen() of
        [] -> skip;
        StrengthenList when is_list(StrengthenList) ->
            lists:foreach(F, StrengthenList);
        _ -> skip
    end,
    ok.

%%初始化防具强化抗性规则表
init_goos_strengthen_anti()->
	ets:delete_all_objects(ets_base_goods_strengthen_anti),
    F=fun(StrengthenAnti) ->
			StrengthenAntiInfo = list_to_tuple([ets_base_goods_strengthen_anti] ++StrengthenAnti),
            ets:insert(?ETS_BASE_GOODS_STRENGTHEN_ANTI, StrengthenAntiInfo)
        end,
    case db_agent:get_base_goods_strengthen_anti() of
        [] -> skip;
        StrengthenAntiList when is_list(StrengthenAntiList) ->
            lists:foreach(F, StrengthenAntiList);
        _ -> skip
    end,
    ok.

%%初始化装备强化额外信息表
init_goos_strengthen_extra()->
	ets:delete_all_objects(ets_base_goods_strengthen_extra),
    F=fun(StrengthenExtra) ->
			StrengthenExtraInfo = list_to_tuple([ets_base_goods_strengthen_extra] ++StrengthenExtra),
            ets:insert(?ETS_BASE_GOODS_STRENGTHEN_EXTRA ,StrengthenExtraInfo)
        end,
        case db_agent:get_base_goods_strengthen_extra() of
            [] ->skip;
            StrengthenExtraList when is_list(StrengthenExtraList) ->
                lists:foreach(F,StrengthenExtraList);
            _->skip
        end,
        ok.

%%初始化法宝修炼规则表
init_goos_practise()->
%%	ets:delete_all_objects(ets_base_goods_practise),
    F=fun(Practise) ->
				PractiseInfo = list_to_tuple([ets_base_goods_practise] ++Practise),
                ets:insert(?ETS_BASE_GOODS_PRACTISE, PractiseInfo)
            end,
        case db_agent:get_base_goods_practise() of
            [] -> skip;
            PractiseList when is_list(PractiseList) ->
                lists:foreach(F,PractiseList);
            _-> skip
        end,
        ok.

%% 初始化宝石合成规则表
init_goos_compose() ->
	ets:delete_all_objects(ets_base_goods_compose),
     F = fun(GoodsCompose) ->
				GoodsComposeInfo = list_to_tuple([ets_base_goods_compose] ++GoodsCompose),
                ets:insert(?ETS_BASE_GOODS_COMPOSE, GoodsComposeInfo)
         end,
    case db_agent:get_base_goods_compose() of
        [] -> skip;
        GoodsComposeList when is_list(GoodsComposeList) ->
            lists:foreach(F, GoodsComposeList);
        _ -> skip
    end,
    ok.

%% 初始化宝石镶嵌规则表
init_goos_inlay() ->
	ets:delete_all_objects(ets_base_goods_inlay),
     F = fun(GoodsInlay) ->
				GoodsInlayInfo = list_to_tuple([ets_base_goods_inlay] ++GoodsInlay),
				Equip_type = util:explode(",", GoodsInlayInfo#ets_base_goods_inlay.equip_types, int),
                GoodsInlayInfo_1 = GoodsInlayInfo#ets_base_goods_inlay{
                                      equip_types = Equip_type
                              	},
                ets:insert(?ETS_BASE_GOODS_INLAY, GoodsInlayInfo_1)
         end,
    case db_agent:get_base_goods_inlay() of
        [] -> skip;
        GoodsInlayList when is_list(GoodsInlayList) ->
            lists:foreach(F, GoodsInlayList);
        _ -> skip
    end,
    ok.

%% 初始化装备分解规则表
init_goods_idecompose()->
	ets:delete_all_objects(ets_base_goods_idecompose),
	F = fun(GoodsDe) ->
				GoodsDeInfo = list_to_tuple([ets_base_goods_idecompose] ++ GoodsDe),
				ets:insert(?ETS_BASE_GOODS_IDECOMPOSE,GoodsDeInfo)
		end,
	case db_agent:get_base_goods_idecompose() of
		[] ->skip;
		GoodsDecomposeList when is_list(GoodsDecomposeList) ->
			lists:foreach(F, GoodsDecomposeList);
		_->skip
	end,
	ok.

%% 初始化材料合成规则表
init_goods_icompose() ->
	ets:delete_all_objects(ets_base_goods_icompose),
	F = fun(GoodsIc) ->
				GoodsIcInfo = list_to_tuple([ets_base_goods_icompose] ++ GoodsIc),
				ets:insert(?ETS_BASE_GOODS_ICOMPOSE,GoodsIcInfo)
		end,
	case db_agent:get_base_goods_icompose() of
		[] ->skip;
		GoodsIcomposeList when is_list(GoodsIcomposeList) ->
			lists:foreach(F, GoodsIcomposeList);
		_ ->skip
	end,
	ok.
				
%% %% 初始化天降彩石规则表
init_goods_ore_rule()->
	ets:delete_all_objects(ets_base_goods_ore),
	F = fun(GoR) ->
				GoRInfo = list_to_tuple([ets_base_goods_ore]++GoR),
				ets:insert(?ETS_BASE_GOODS_ORE,GoRInfo)
		end,
	case db_agent:get_base_goods_ore() of
		[] ->skip;
		GoodsOreInfo when is_list(GoodsOreInfo) ->
			lists:foreach(F,GoodsOreInfo);
		_ ->skip
	end,
	ok.

%% 初始化物品掉落数量规则表
init_goos_drop_num() ->
	ets:delete_all_objects(ets_base_goods_drop_num),
     F = fun(GoodsDropNum) ->
				GoodsDropNumInfo = list_to_tuple([ets_base_goods_drop_num] ++ GoodsDropNum),
                ets:insert(?ETS_BASE_GOODS_DROP_NUM, GoodsDropNumInfo)
         end,
    case db_agent:get_base_goods_drop_num() of
        [] -> skip;
        GoodsDropNumList when is_list(GoodsDropNumList) ->
            lists:foreach(F, GoodsDropNumList);
        _ -> skip
    end,
    ok.

%% 初始化物品掉落规则表
init_goos_drop_rule() ->
	ets:delete_all_objects(ets_base_goods_drop_rule),
 	F = fun(GoodsDropRule) ->
		GoodsDropRuleInfo = list_to_tuple([ets_base_goods_drop_rule] ++ GoodsDropRule),
   		ets:insert(?ETS_BASE_GOODS_DROP_RULE, GoodsDropRuleInfo)
  	end,
    case db_agent:get_base_goods_drop_rule() of
        [] -> skip;
        GoodsDropRuleList when is_list(GoodsDropRuleList) ->
            lists:foreach(F, GoodsDropRuleList);
        _ -> skip
    end,
    ok.

%% 初始化商店表
init_shop() ->
	ets:delete_all_objects(ets_shop),
     F = fun(Shop) ->
				ShopInfo = list_to_tuple([ets_shop] ++ Shop),
                ets:insert(?ETS_BASE_SHOP, ShopInfo)
         end,
    case db_agent:get_shop_info() of
        [] -> skip;
        ShopList when is_list(ShopList) ->
            lists:foreach(F, ShopList);
        _ -> skip
    end,
    ok.

%% 初始化时装基础数据表
init_base_goos_fashion() ->
	ets:delete_all_objects(ets_base_goods_fashion),
	F = fun(BaseGoodFashion) ->
				BaseGoodFashionInfo = list_to_tuple([ets_base_goods_fashion] ++ BaseGoodFashion),
				ets:insert(?ETS_BASE_GOODS_FASHION,BaseGoodFashionInfo)
		end,
	case db_agent:get_base_goods_fashion() of
		[] ->skip;
		BaseGoodFashionList when is_list(BaseGoodFashionList) ->
			lists:foreach(F, BaseGoodFashionList);
		_ ->skip
	end,
	ok.

%% 初始化装备附魔基础数据表
init_base_magic() ->
	ets:delete_all_objects(ets_base_magic),
	F = fun(BaseMagic) ->
				BaseMagicInfo = list_to_tuple([ets_base_magic] ++ BaseMagic),
				ets:insert(?ETS_BASE_MAGIC,BaseMagicInfo)
		end,
	case db_agent:get_base_magic() of
		[] ->skip;
		BaseMagicList when is_list(BaseMagicList) ->
			lists:foreach(F, BaseMagicList);
		_ ->skip
	end,
	ok.

%% ---------------------------------------------------------------------------------

%% 初始化在线玩家背包物品表
init_goods(PlayerId) ->
	 Now = util:unixtime(),
     F = fun(Goods) ->
				GoodsInfo = list_to_tuple([goods] ++ Goods),
				%%过滤有效期的物品
				if
					GoodsInfo#goods.expire_time /= 0 andalso GoodsInfo#goods.expire_time > Now andalso GoodsInfo#goods.expire_time - Now < 86400 ->
						ets:insert(?ETS_GOODS_ONLINE, GoodsInfo),
						erlang:send_after((GoodsInfo#goods.expire_time - Now) * 1000, self(), {'del_expire_goods',PlayerId,GoodsInfo#goods.id,GoodsInfo#goods.goods_id,GoodsInfo#goods.color,GoodsInfo#goods.expire_time,0}); 
					GoodsInfo#goods.expire_time /= 0 andalso GoodsInfo#goods.expire_time < Now ->
						DBAttrs = db_agent:get_goods_attrlist_by_gidtype(GoodsInfo#goods.id,1),
						Attrs = lists:foldl(fun get_attribute_id_value/2, [], DBAttrs),
						AtrrsStr = util:term_to_string(Attrs),
						Param = [PlayerId,"过期物品",GoodsInfo#goods.id,GoodsInfo#goods.goods_id,GoodsInfo#goods.color,GoodsInfo#goods.stren,GoodsInfo#goods.bind,3,GoodsInfo#goods.num,AtrrsStr],
						spawn(fun()->log:log_throw(Param)end),
						BaseInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
						{{Year, Month, Day}, _Time1} =util:seconds_to_localtime(GoodsInfo#goods.expire_time),
						%%飞行坐骑过期不发送邮件
						if GoodsInfo#goods.goods_id =/=16009->
							   Content = io_lib:format("您好！你的物品【~s】已于~p年~p月~p日过期，系统已自动删除！祝你游戏愉快～",[BaseInfo#ets_base_goods.goods_name,Year, Month, Day]),
							   lib_mail:insert_mail(1, Now, "系统", PlayerId, "物品到期通知", Content, 0, 0, 0, 0, 0);
						   true->skip
						end,
						%%过期的物品删除
						lib_goods:delete_goods(GoodsInfo#goods.id);
					true ->
                		ets:insert(?ETS_GOODS_ONLINE, GoodsInfo)
				end
         end,
    case db_agent:get_online_player_goods_by_id(PlayerId) of
        [] -> skip;
        GoodsList when is_list(GoodsList) ->
            lists:foreach(F, GoodsList);
        _ -> skip
    end,
    ok.

%% 初始化在线玩家物品属性表
init_goods_attribute(PlayerId) ->
    F = fun(Attribute) ->
				AttributeInfo = list_to_tuple([goods_attribute] ++ Attribute),
                ets:insert(?ETS_GOODS_ATTRIBUTE, AttributeInfo)
         end,
    case db_agent:get_online_player_goods_attribute_by_id(PlayerId) of
        [] -> skip;
        AttributeList when is_list(AttributeList) ->
            lists:foreach(F, AttributeList);
        _ -> skip
    end,
    ok.

%% 初始化在线玩家物品buff表
init_goods_buff(Player,LLoginTime, NowTime, LTime) ->
	PlayerId = Player#player.id,
	case db_agent:get_online_player_goods_buff_by_id(PlayerId) of
		[] -> {[],[]};
		BuffList when is_list(BuffList) ->
			GoodsBuffs = 
				lists:foldl(fun(Elem, AccIn) ->
									{TurnedValue,Buffs} = AccIn,
									[Eid,Egoods_id,Eexpire_time,Edata] = Elem,
									%%物品buff过期时间包括未在线时间
									IsIncludeOffTime = lists:member(Egoods_id, [31216,31217,31218,28047]),
									case LTime =/= 0 andalso LTime >= LLoginTime of
										true -> 
											if  
												%%LTime:上次离线时间
												%%buff未过期
												Eexpire_time > LTime-10 ->
													if IsIncludeOffTime == true ->
														   NewExpirT = Eexpire_time;
													   true ->
														   NewExpirT = Eexpire_time - LTime - 5 + NowTime  %%因为有延时，所以-5s
													end,
													%%改数据库时间
													db_agent:update_gbuff_time(NewExpirT, Eid),
													{BuffGId, Data} = get_buff_compatibility(Egoods_id, Edata),
													%%变身buff特殊处理，有属性加成
													Turneds =
													if Egoods_id =:= 28043 orelse  Egoods_id =:= 28047 orelse  Egoods_id =:= 31216->
														   {Mon_id,_B} = Data,
														   if Egoods_id =:= 31216 ->
																 {_MonId,{Fields,Value,_BuffId}} = data_agent:get_chr_turned_buff_id(Mon_id,Player#player.career,Player#player.sex);
															  Egoods_id =:= 28047 ->
																 {_MonId,{Fields,Value,_BuffId}} = data_agent:get_chr_snow_buff_id(Mon_id);
															  true ->
																 {_MonId,{Fields,Value,_BuffId}} = data_agent:get_turned_buff_id(Mon_id)
														   end,
														   lib_goods_use:get_turned_values(Player,Fields,Value);														  
													   true ->
														   []
													end,
													change_buffid_compatibility(PlayerId, Egoods_id, BuffGId),%%对旧数据的兼容
													Buff = {BuffGId, Data, NewExpirT},
													{[Turneds|TurnedValue],[Buff|Buffs]};
												%%buff已过期
												true ->
													Turneds = [],
													{BuffGId, Data} = get_buff_compatibility(Egoods_id, Edata),
													change_buffid_compatibility(PlayerId, Egoods_id, BuffGId),%%对旧数据的兼容
													Buff = {BuffGId, Data, Eexpire_time},
													{[Turneds|TurnedValue],[Buff|Buffs]}
											end;
										false ->
									        Turneds = [],
											NewExpirT = Eexpire_time - LLoginTime + NowTime,
											%%改数据库时间
											db_agent:update_gbuff_time(NewExpirT, Eid),
											{BuffGId, Data} = get_buff_compatibility(Egoods_id, Edata),%%对旧数据的兼容
											change_buffid_compatibility(PlayerId, Egoods_id, BuffGId),
											Buff = {BuffGId, Data, NewExpirT},
											{[Turneds|TurnedValue],[Buff|Buffs]}
									end
							end, {[],[]}, BuffList),
			GoodsBuffs;
		_ ->
			{[],[]}
	end.

%% 初始化在线玩家物品cd表
init_goods_cd(PlayerId) ->
	F = fun(GoodsCd) ->
				GCD = list_to_tuple([ets_goods_cd]++ GoodsCd),
				ets:insert(?ETS_GOODS_CD,GCD)
		end,
	case db_agent:get_online_player_goods_cd_by_id(PlayerId) of
		[] ->skip;
		CDlist when is_list(CDlist) ->
			lists:foreach(F,CDlist);
		_ ->skip
	end,
	ok.

%% 初始化副法宝
init_deputy_equip(PlayerId) ->
	F = fun(DeputyData) ->
				DeputyInfo = list_to_tuple([ets_deputy_equip]++DeputyData),
				%%把字符串转换成erlang格式
				Skills = util:string_to_term(tool:to_list(DeputyInfo#ets_deputy_equip.skills)),
				Att = util:string_to_term(tool:to_list(DeputyInfo#ets_deputy_equip.att)),
				TmpAtt = util:string_to_term(tool:to_list(DeputyInfo#ets_deputy_equip.tmp_att)),
				NewDeputyInfo = DeputyInfo#ets_deputy_equip{skills = Skills,att= Att ,tmp_att = TmpAtt},
				ets:insert(?ETS_DEPUTY_EQUIP,NewDeputyInfo)
		end,
	case db_agent:get_online_player_deputy_equip(PlayerId) of
		[] -> skip;
		Dlist when is_list(Dlist) ->
			lists:foreach(F,Dlist);
		_ ->skip
	end,
	ok.
%% 取物品类型信息
%% @spec get_ets_info(Tab, Id) -> record()
get_ets_info(Tab, Id) ->
    L = case is_integer(Id) of
            true -> ets:lookup(Tab, Id);
            false -> ets:match_object(Tab, Id)
        end,
    case L of
        [Info|_] -> Info;
        _ -> {}
    end.

get_ets_list(Tab, Pattern) ->
    L = ets:match_object(Tab, Pattern),
    case is_list(L) of
        true ->L;
        false -> []
    end.

%% 取物品名称
%% @spec get_goods_name(GoodsTypeId) -> string
get_goods_name(GoodsTypeId) ->
    GoodsTypeInfo = get_ets_info(?ETS_BASE_GOODS, GoodsTypeId),
    case is_record(GoodsTypeInfo, ets_base_goods) of
        true -> GoodsTypeInfo#ets_base_goods.goods_name;
        false -> <<>>
    end.

%% 取任务怪ID
%% @spec get_task_mon(GoodsTypeId) -> mon_id | 0
get_task_mon(GoodsTypeId) ->
    Pattern = #ets_base_goods_drop_rule{ goods_id=GoodsTypeId, _='_' },
    RuleInfo = get_ets_info(?ETS_BASE_GOODS_DROP_RULE, Pattern),
    case is_record(RuleInfo, ets_base_goods_drop_rule) of
        true -> RuleInfo#ets_base_goods_drop_rule.mon_id;
        false -> 0
    end.

%% 获取指定位置的物品数量
%% @spec get_goods_num(PlayerId, GoodsTypeId,Location) -> num | 0
get_goods_num(PlayerId, GoodsTypeId,Location) ->
    Pattern = #goods{ player_id=PlayerId, goods_id=GoodsTypeId, location=Location, _='_' },
    GoodsList = get_ets_list(?ETS_GOODS_ONLINE, Pattern),
    get_goods_totalnum(GoodsList).

%%获取指定位置的未绑定的物品数量
get_goods_num_unbind(PlayerId, GoodsTypeId,Location)->
	Pattern = #goods{ player_id=PlayerId, goods_id=GoodsTypeId, location=Location,bind=0, _='_' },
    GoodsList = get_ets_list(?ETS_GOODS_ONLINE, Pattern),
    get_goods_totalnum(GoodsList).

%%获取指定位置的的的物品数量(绑定情况和交易情况自定义bind:0,非绑，2,绑定；trade:0,可交易，1,不可交易)
get_goods_num_unbind_trade(PlayerId, GoodsTypeId, Location, Bind, Trade) ->
	Pattern = #goods{ player_id=PlayerId, goods_id=GoodsTypeId, location=Location,bind = Bind, trade = Trade, _='_' },
    GoodsList = get_ets_list(?ETS_GOODS_ONLINE, Pattern),
    get_goods_totalnum(GoodsList).

%%由基础数据转换成goods数据
get_new_goods(GoodsTypeInfo) ->
    #goods{
        goods_id = GoodsTypeInfo#ets_base_goods.goods_id,
        type = GoodsTypeInfo#ets_base_goods.type,
        subtype = GoodsTypeInfo#ets_base_goods.subtype,
        equip_type = GoodsTypeInfo#ets_base_goods.equip_type,
        price_type = GoodsTypeInfo#ets_base_goods.price_type,
        price = GoodsTypeInfo#ets_base_goods.price,
        sell_price = GoodsTypeInfo#ets_base_goods.sell_price,
        bind = GoodsTypeInfo#ets_base_goods.bind,
		career = GoodsTypeInfo#ets_base_goods.career,
        trade = GoodsTypeInfo#ets_base_goods.trade,
        sell = GoodsTypeInfo#ets_base_goods.sell,
        isdrop = GoodsTypeInfo#ets_base_goods.isdrop,
        level = GoodsTypeInfo#ets_base_goods.level,
		grade = GoodsTypeInfo#ets_base_goods.grade,
        spirit = GoodsTypeInfo#ets_base_goods.spirit,
        hp = GoodsTypeInfo#ets_base_goods.hp,
        mp = GoodsTypeInfo#ets_base_goods.mp,
        forza = GoodsTypeInfo#ets_base_goods.forza,
		physique = GoodsTypeInfo#ets_base_goods.physique,
        agile = GoodsTypeInfo#ets_base_goods.agile,
        wit = GoodsTypeInfo#ets_base_goods.wit,
        max_attack = GoodsTypeInfo#ets_base_goods.max_attack,
		min_attack = GoodsTypeInfo#ets_base_goods.min_attack,
        def = GoodsTypeInfo#ets_base_goods.def,
        hit = GoodsTypeInfo#ets_base_goods.hit,
        dodge = GoodsTypeInfo#ets_base_goods.dodge,
        crit = GoodsTypeInfo#ets_base_goods.crit,
        %%ten = GoodsTypeInfo#ets_base_goods.ten,
		anti_wind = GoodsTypeInfo#ets_base_goods.anti_wind,
		anti_fire = GoodsTypeInfo#ets_base_goods.anti_fire,
		anti_water = GoodsTypeInfo#ets_base_goods.anti_water,
		anti_thunder = GoodsTypeInfo#ets_base_goods.anti_thunder,
		anti_soil = GoodsTypeInfo#ets_base_goods.anti_soil,
		step = GoodsTypeInfo#ets_base_goods.step,
        speed = GoodsTypeInfo#ets_base_goods.speed,
        attrition = GoodsTypeInfo#ets_base_goods.attrition,
        use_num = get_goods_use_num(GoodsTypeInfo#ets_base_goods.attrition),
        suit_id = GoodsTypeInfo#ets_base_goods.suit_id,
        color = GoodsTypeInfo#ets_base_goods.color,
        expire_time = GoodsTypeInfo#ets_base_goods.expire_time,
		bless_level = 0,
		bless_skill = 0
    }.

%%由基础附加属性规则生成附加属性(暂用于紫装融合预览)
get_new_goods_add_attribute(Base_goods_add_attribute) ->
	[Hp,Mp,Forza,Agile,Wit,Physique,Crit,Dodge,Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil,Attack,Anti_rift] =
	get_add_attribute_by_type(Base_goods_add_attribute),
	#goods_attribute{
		attribute_type = 1,
		value_type = 0,
		attribute_id = Base_goods_add_attribute#ets_base_goods_add_attribute.attribute_id,
		hp = Hp,
		mp = Mp,
		max_attack = Attack,
		min_attack = Attack,
		forza = Forza,
		agile = Agile,
		wit = Wit,
		physique = Physique,
		crit = Crit,
		dodge = Dodge,
		anti_wind = Anti_wind,
		anti_fire = Anti_fire,
		anti_water = Anti_water,
		anti_thunder = Anti_thunder,
		anti_soil  = Anti_soil,
		anti_rift = Anti_rift			 
	}.

%%查询身上装备的紫戒指 
get_ring_color4(PlayerId) ->
	Pattern = #goods{player_id=PlayerId, type=10, location=1, subtype=23, _='_' },
    List = get_ets_list(?ETS_GOODS_ONLINE, Pattern),
	[{GoodsInfo#goods.bless_level,GoodsInfo#goods.bless_skill} || GoodsInfo <- List].

%% 取当前装备的武器、衣服,坐骑不能从装备信息取
get_current_equip(GoodsStatus) ->
    EquipList = goods_util:get_equip_list(GoodsStatus#goods_status.player_id, 10, 1),
    [NewStatus, _, _] = get_current_equip_by_list(EquipList, [GoodsStatus, on]),
    NewStatus.

%%获取当前装备列表
get_current_equip_by_list(GoodsList, [GoodsStatus, Type]) ->
	%%添加 时装判断，只有时装再传goods_id,其它都传0，否则会显示人物模形有问题
	[_Player_Id, _ShieldRole, _ShieldSkill, _ShieldRela, _ShieldTeam, _ShieldChat, _Music, _SoundEffect,Fasheffect, _Smelt] = lib_syssetting:query_player_sys_setting(GoodsStatus#goods_status.player_id),
    lists:foldl(fun get_current_equip_by_info/2, [GoodsStatus, Type, Fasheffect], GoodsList).

%%
get_current_equip_by_info(GoodsInfo, [GoodsStatus, Type, Fasheffect]) ->
    [Wq, Yf, Fbyf, Spyf, Zq] = GoodsStatus#goods_status.equip_current,

    case is_record(GoodsInfo, goods) of
        true when GoodsInfo#goods.type =:= 10 andalso GoodsInfo#goods.subtype < 14 ->%%法宝
            CurrentEquip = case Type of
                                on -> [GoodsInfo#goods.goods_id, Yf, Fbyf, Spyf, Zq];
                                off -> [0, Yf, Fbyf, Spyf, Zq]
                           end;
        true when GoodsInfo#goods.type =:= 10 andalso GoodsInfo#goods.subtype =:= 24 ->%%衣服时装
			CurrentEquip = case Type of
                                on when GoodsInfo#goods.goods_id >= 10901 andalso GoodsInfo#goods.goods_id =< 10940  -> %%只有时装才占用这个字段
									case Fasheffect of
										1 ->
											[Wq, 0, Fbyf, Spyf, Zq];
										_ ->
											if 
												%% 如果时装有变化效果
												GoodsInfo#goods.icon > 0 ->
										   			[Wq, GoodsInfo#goods.icon, Fbyf, Spyf, Zq];
												true ->
													FashionEquip = lib_wardrobe:get_player_wardrobe(GoodsStatus#goods_status.player_id),
													if 
														FashionEquip#ets_fashion_equip.yfid > 0 ->%%衣橱里是否已经换过装
															[Wq, FashionEquip#ets_fashion_equip.yfid, Fbyf, Spyf, Zq];
														true ->
															[Wq, GoodsInfo#goods.goods_id, Fbyf, Spyf, Zq]
													end
											end
									end;
                                off ->
									[Wq, 0, Fbyf, Spyf, Zq]
                           end;
		 true when GoodsInfo#goods.type =:= 10 andalso GoodsInfo#goods.subtype == 26 ->%%法宝时装
			 CurrentEquip = case Type of
								on -> 
									if 
										%% 如果法宝有图鉴效果
										GoodsInfo#goods.icon > 0 ->
											[Wq, Yf, GoodsInfo#goods.icon, Spyf, Zq];
										true ->
											[Wq, Yf, GoodsInfo#goods.goods_id, Spyf, Zq]
									end;
                                off -> [0, Yf, 0, Spyf, Zq]
                           end;
		true when GoodsInfo#goods.type =:= 10 andalso GoodsInfo#goods.subtype == 27 ->%%饰品时装
			CurrentEquip = case Type of
                                on -> 
									if 
										%% 如果挂饰有图鉴效果
										GoodsInfo#goods.icon > 0 ->
											[Wq, Yf, Fbyf, GoodsInfo#goods.icon, Zq];
										true ->
											[Wq, Yf, Fbyf, GoodsInfo#goods.goods_id, Zq]
									end;
                                off -> [0, Yf, Fbyf, 0, Zq]
                           end;
        _ ->
			CurrentEquip = [Wq, Yf, Fbyf, Spyf, Zq]
    end,
    NewGoodsStatus = GoodsStatus#goods_status{ equip_current=CurrentEquip },
    [NewGoodsStatus, Type, Fasheffect].

%%从ets取goods信息 
%%返回单个物品record

get_goods(GoodsId) ->
    GoodsInfo = goods_util:get_ets_info(?ETS_GOODS_ONLINE, GoodsId),
	parse_goods_addition(GoodsInfo).
			
%%返回类型列表
get_goods(Goods_Id, PlayerId) ->
	Pattern = #goods{goods_id = Goods_Id, player_id = PlayerId, _='_'},
	GoodsInfoList = get_ets_list(?ETS_GOODS_ONLINE, Pattern),
	lists:map(fun parse_goods_addition/1, GoodsInfoList).

%%根据物品类型ID获取最新生成都物品信息
get_new_goods_by_type(Goods_Id,PlayerId) ->
	GoodsList = get_goods(Goods_Id, PlayerId),
		if							
			length(GoodsList) > 1 ->
				lists:max(GoodsList);
			length(GoodsList) == 1 ->
				lists:nth(1, GoodsList);
			true ->
				#goods{}
		end.

%%获取玩家数据库物品信息
%% 初始化在线玩家背包物品表
get_player_goods_from_db(PlayerId) ->
     F = fun(Goods) ->
				list_to_tuple([goods] ++ Goods)
         end,
    case db_agent:get_online_player_goods_by_id(PlayerId) of
        [] -> [];
        GoodsList when is_list(GoodsList) ->
            lists:map(F, GoodsList);
        _ -> []
    end.

%%这里需要处理物品的强化加成属性
%%注意！！goodsInfo#goods.other_data 保存部分初始化属性,为goods记录。当清空时,重新保存当前值为初始属性。
parse_goods_addition(OldGoodsInfo) ->
	F=fun(Stren,GoodsInfo) ->
		if 
			%%装备有强化加成属性处理
			is_record(GoodsInfo,goods)  andalso GoodsInfo#goods.type =:= 10 andalso Stren > 0 ->
				Att_type=goods_util:get_goods_attribute_id(GoodsInfo#goods.subtype),
    			Pattern = #ets_base_goods_strengthen{ strengthen=Stren ,type=Att_type, _='_' },
    			GoodsStrengthenRule = goods_util:get_ets_info(?ETS_BASE_GOODS_STRENGTHEN, Pattern),
				case Att_type of
					1 ->
						%%处理时装基本属性气血加成
						Max_attack = GoodsInfo#goods.max_attack,
						Min_attack = GoodsInfo#goods.min_attack,
						Speed = GoodsInfo#goods.speed,
						case GoodsInfo#goods.subtype == 24 of
							false -> 
								Def = GoodsInfo#goods.def,
								Hp = GoodsInfo#goods.hp;
							true ->
								Def = tool:floor(GoodsInfo#goods.def *(1 + GoodsStrengthenRule#ets_base_goods_strengthen.value / 100)),
								Hp = tool:floor(GoodsInfo#goods.hp *(1 + GoodsStrengthenRule#ets_base_goods_strengthen.value / 100))
						end,
						Anti_wind = GoodsInfo#goods.anti_wind,
						Anti_thunder = GoodsInfo#goods.anti_thunder,
						Anti_water = GoodsInfo#goods.anti_water,
						Anti_fire = GoodsInfo#goods.anti_fire,
						Anti_soil = GoodsInfo#goods.anti_soil;	
					3 ->
						%%法宝
						Max_attack = tool:floor(GoodsInfo#goods.max_attack * (1 + GoodsStrengthenRule#ets_base_goods_strengthen.value / 100)),
						Min_attack = tool:floor(GoodsInfo#goods.min_attack * (1 + GoodsStrengthenRule#ets_base_goods_strengthen.value / 100)),
						Def = GoodsInfo#goods.def,
						Speed = GoodsInfo#goods.speed,
						Hp = GoodsInfo#goods.hp,
						Anti_wind = GoodsInfo#goods.anti_wind,
						Anti_thunder = GoodsInfo#goods.anti_thunder,
						Anti_water = GoodsInfo#goods.anti_water,
						Anti_fire = GoodsInfo#goods.anti_fire,
						Anti_soil = GoodsInfo#goods.anti_soil;
					4 ->
						%%防具
						Max_attack = GoodsInfo#goods.max_attack,
						Min_attack = GoodsInfo#goods.min_attack,
						Def = tool:floor(GoodsInfo#goods.def *(1 + GoodsStrengthenRule#ets_base_goods_strengthen.value / 100)),
						Speed = GoodsInfo#goods.speed,
						Hp = GoodsInfo#goods.hp,
						Anti_wind = GoodsInfo#goods.anti_wind,
						Anti_thunder = GoodsInfo#goods.anti_thunder,
						Anti_water = GoodsInfo#goods.anti_water,
						Anti_fire = GoodsInfo#goods.anti_fire,
						Anti_soil = GoodsInfo#goods.anti_soil;
					26 ->
						%%法宝时装
						[Max_attack1,Def1] = get_goods_data_stren(GoodsInfo#goods.goods_id,Stren),
						Max_attack = Max_attack1,
						Min_attack = Max_attack1,
						Def = Def1,
						Speed = GoodsInfo#goods.speed,
						Hp = GoodsInfo#goods.hp,
						Anti_wind = GoodsInfo#goods.anti_wind,
						Anti_thunder = GoodsInfo#goods.anti_thunder,
						Anti_water = GoodsInfo#goods.anti_water,
						Anti_fire = GoodsInfo#goods.anti_fire,
						Anti_soil = GoodsInfo#goods.anti_soil;
					27 ->
						%%饰品时装
						[Hp1,Anti_all] = get_goods_data_stren(GoodsInfo#goods.goods_id,Stren),
						Max_attack = GoodsInfo#goods.max_attack,
						Min_attack = GoodsInfo#goods.min_attack,
						Def = GoodsInfo#goods.def,
						Speed = GoodsInfo#goods.speed,
						Hp = Hp1,
						Anti_wind = Anti_all,
						Anti_thunder = Anti_all,
						Anti_water = Anti_all,
						Anti_fire = Anti_all,
						Anti_soil = Anti_all;
					_ ->
						%%坐骑速度
						Speed = lib_mount:get_mount_speed_by_id(GoodsInfo#goods.id,GoodsInfo#goods.other_data) + tool:floor(100 *(GoodsStrengthenRule#ets_base_goods_strengthen.value / 100)),
						Max_attack = GoodsInfo#goods.max_attack,
						Min_attack = GoodsInfo#goods.min_attack,
						Def = GoodsInfo#goods.def,
						Hp = GoodsInfo#goods.hp,
						Anti_wind = GoodsInfo#goods.anti_wind,
						Anti_thunder = GoodsInfo#goods.anti_thunder,
						Anti_water = GoodsInfo#goods.anti_water,
						Anti_fire = GoodsInfo#goods.anti_fire,
						Anti_soil = GoodsInfo#goods.anti_soil
				end,
				NewGoodsInfo = GoodsInfo#goods{max_attack = Max_attack,min_attack = Min_attack ,def = Def,speed = Speed,hp = Hp,anti_wind = Anti_wind, anti_thunder = Anti_thunder,
											   anti_water = Anti_water, anti_fire = Anti_fire, anti_soil = Anti_soil},
				NewGoodsInfo;
			true ->
				GoodsInfo
		end
	end,
	if
		is_record(OldGoodsInfo,goods) andalso OldGoodsInfo#goods.type =:= 10->
			%%需要备份的原始数据，等于数据库里面的数据
			GoodsInfo1 =
			case is_record(OldGoodsInfo#goods.other_data,goods) of
				true->
					OldGoodsInfo;
				false ->
					if
						OldGoodsInfo#goods.type == 10 andalso OldGoodsInfo#goods.subtype == 22 ->
							Speed = lib_mount:get_mount_speed_by_id(OldGoodsInfo#goods.id,OldGoodsInfo);
						true ->
							Speed = OldGoodsInfo#goods.speed
					end,
					Copy = #goods{max_attack = OldGoodsInfo#goods.max_attack,
								  min_attack = OldGoodsInfo#goods.min_attack,
								  def = OldGoodsInfo#goods.def,
								  speed = Speed,
								  hp = OldGoodsInfo#goods.hp
								  },
					GoodsInfo0=OldGoodsInfo#goods{other_data = Copy},
					
					%%同步备份数据
					ets:insert(?ETS_GOODS_ONLINE,GoodsInfo0),
					GoodsInfo0
			end,

			%%处理强化加成 把攻击防御回复到初始值
			GodosInfo_for_Stren = GoodsInfo1#goods{max_attack = GoodsInfo1#goods.other_data#goods.max_attack,
												   min_attack = GoodsInfo1#goods.other_data#goods.min_attack,
												   def = GoodsInfo1#goods.other_data#goods.def,
												   speed = GoodsInfo1#goods.other_data#goods.speed,
												   hp = GoodsInfo1#goods.other_data#goods.hp},
			apply(F, [GoodsInfo1#goods.stren, GodosInfo_for_Stren]);
		true ->
			OldGoodsInfo
	end.

%%对法宝时装和饰品时间的强化基本属性加成
get_goods_data_stren(GoodsType,Stren) ->
	GoodsTypeInfo = goods_util:get_goods_type(GoodsType),
	if GoodsTypeInfo#ets_base_goods.subtype == 26 ->%%法宝时装返回[攻击，防御]
		   if Stren == 1 -> [104,130];
			  Stren == 2 -> [120,150];
			  Stren == 3 -> [136,170];
			  Stren == 4 -> [160,200];
			  Stren == 5 -> [192,240];
			  Stren == 6 -> [232,290];
			  Stren == 7 -> [280,350];
			  Stren == 8 -> [336,420];
			  Stren == 9 -> [400,500];
			  Stren == 10 -> [480,600];
			  true -> [GoodsTypeInfo#ets_base_goods.max_attack,GoodsTypeInfo#ets_base_goods.def]
		   end;
	   GoodsTypeInfo#ets_base_goods.subtype == 27 ->%%饰品时装返回[气血，全抗]
		   if Stren == 1 -> [520,65];
			  Stren == 2 -> [600,75];
			  Stren == 3 -> [680,85];
			  Stren == 4 -> [800,100];
			  Stren == 5 -> [960,120];
			  Stren == 6 -> [1160,145];
			  Stren == 7 -> [1400,175];
			  Stren == 8 -> [1680,210];
			  Stren == 9 -> [2000,250];
			  Stren == 10 -> [2400,300];
			  true -> [GoodsTypeInfo#ets_base_goods.hp,GoodsTypeInfo#ets_base_goods.anti_fire]
		   end;
	   true ->
		   [0,0]
	end.
			
%%取goods base信息
get_goods_type(GoodsTypeId) ->
    get_ets_info(?ETS_BASE_GOODS, GoodsTypeId).

%% 取新加入的物品	
get_add_goods(PlayerId, GoodsTypeId, Location, Cell, Num) ->
    Goods = (catch db_agent:get_add_goods(PlayerId, GoodsTypeId, Location, Cell, Num)),
	GoodsInfo = list_to_tuple([goods] ++ Goods),
	GoodsInfo.

%% @spec get_goods_by_id(GoodsId) -> record()
get_goods_by_id(GoodsId) ->
    Goods = (catch db_agent:get_goods_by_id(GoodsId)),
	GoodsInfo = list_to_tuple([goods] ++ Goods),
	parse_goods_addition(GoodsInfo).

get_goods_by_cell(PlayerId, Location, Cell) ->
    Pattern = #goods{ player_id=PlayerId, location=Location, cell=Cell, _='_' },
    get_ets_info(?ETS_GOODS_ONLINE, Pattern).

%% 取物品列表
get_goods_list(PlayerId,all) ->
	Pattern = #goods{ player_id=PlayerId, _='_' },
    get_ets_list(?ETS_GOODS_ONLINE, Pattern);
get_goods_list(PlayerId, Location) ->
   	Pattern = #goods{ player_id=PlayerId, location=Location, _='_' },
    get_ets_list(?ETS_GOODS_ONLINE, Pattern).

%%根据类型，子类型查询物品
get_goods_list_type_subtype(PlayerId,Location,Type,Subtype) ->
	Pattern = #goods{ player_id=PlayerId, location=Location, type=Type, subtype=Subtype,_='_' },
    get_ets_list(?ETS_GOODS_ONLINE, Pattern).

%% 获取同类物品列表
get_type_goods_list(PlayerId, GoodsTypeId, Bind, Location) ->
   	Pattern = #goods{ player_id=PlayerId, goods_id=GoodsTypeId, bind=Bind, location=Location, _='_' },
    get_ets_list(?ETS_GOODS_ONLINE, Pattern).

get_type_goods_list(PlayerId, GoodsTypeId, Location) ->
    Pattern = #goods{ player_id=PlayerId, goods_id=GoodsTypeId, location=Location, _='_' },
    get_ets_list(?ETS_GOODS_ONLINE, Pattern).

get_mount_cell(PlayerId,Location) ->
	MS = ets:fun2ms(fun(T) when T#goods.player_id == PlayerId andalso T#goods.location == Location andalso T#goods.cell >= 200  -> 
			T 
		end),
	ets:select(?ETS_GOODS_ONLINE, MS).

%% 获取同类物品的一个
get_type_goods_info(PlayerId,GoodsTypeId,Location)->
	TypInfoList = get_type_goods_list(PlayerId, GoodsTypeId, Location),
	case length(TypInfoList) > 0 of
		true ->
			hd(TypInfoList);
		false ->
			TypInfoList
	end.

%% 查找有耐久度的装备
get_mend_list(PlayerId, Equip) ->
    L1 = get_equip_list(PlayerId, 10, Equip),
    L2 = get_equip_list(PlayerId, 10, 4),
    L1 ++ L2.

%% 取装备列表
get_equip_list(PlayerId, Type, Location) ->
    Pattern = #goods{player_id=PlayerId, type=Type, location=Location, _='_' },
    List = get_ets_list(?ETS_GOODS_ONLINE, Pattern),
	lists:map(fun parse_goods_addition/1, List).

%% 取cell装备 %%注意有同名函数！
get_equip_cell(PlayerId,Location,Cell) ->
    Pattern = #goods{player_id=PlayerId, location=Location,cell = Cell, _='_' },
    List = get_ets_list(?ETS_GOODS_ONLINE, Pattern),
	ParseList = lists:map(fun parse_goods_addition/1, List),
	case ParseList of
		[] -> [];
		_ -> hd(ParseList)
	end.

%% 取离线玩家装备列表
get_offline_goods(PlayerId, Location) ->
	 F = fun(Goods) ->
				list_to_tuple([goods] ++ Goods)
         end,
	 GoodsList = db_agent:get_offline_goods(PlayerId,Location),
	 List = lists:map(F, GoodsList),
	 List.

%% 取离线玩家武器衣服坐骑
get_equip_current(Player_Id) ->
	db_agent:get_equip_current(Player_Id).

%%查询物品类型id
get_goods_type_db(Gid) ->
	db_agent:get_goods_type(Gid).

%% 取装备列表id
get_equip_id_list(PlayerId, Type, Location) ->
	Pattern = #goods{player_id=PlayerId, type=Type, location=Location, _='_' },
    List = get_ets_list(?ETS_GOODS_ONLINE, Pattern),
	[Goods#goods.goods_id || Goods <- List].

%% 取商店物品列表
get_shop_list(ShopType, ShopSubtype) ->
    case ShopSubtype > 0 of
        true ->  Pattern = #ets_shop{ shop_type=ShopType, shop_subtype=ShopSubtype, _='_' };
        false -> Pattern = #ets_shop{ shop_type=ShopType, _='_' }
    end,
    get_ets_list(?ETS_BASE_SHOP, Pattern).

%% 取商店物品信息
get_shop_info(ShopType, GoodsTypeId) ->
    Pattern = #ets_shop{ shop_type=ShopType, goods_id=GoodsTypeId, _='_' },
    get_ets_info(?ETS_BASE_SHOP, Pattern).

%% 取新加入的装备属性
get_add_goods_attribute(PlayerId, GoodsId, AttributeType, AttributeId) ->
    Attribute = (catch db_agent:get_add_goods_attribute(PlayerId, GoodsId, AttributeType, AttributeId)),
	AttributeInfo = list_to_tuple([goods_attribute] ++ Attribute),
	AttributeInfo.

%% 取装备属性信息
get_goods_attribute_info(PlayerId, GoodsId, AttributeType) ->
    Pattern = #goods_attribute{ player_id=PlayerId, gid=GoodsId, attribute_type=AttributeType, _='_'},
    get_ets_info(?ETS_GOODS_ATTRIBUTE, Pattern).

get_goods_attribute_info(PlayerId,GoodsId,AttributeType,AttributeId) ->
	Pattern = #goods_attribute{player_id = PlayerId,gid = GoodsId,attribute_id = AttributeId,attribute_type=AttributeType,_='_'},
	get_ets_info(?ETS_GOODS_ATTRIBUTE,Pattern).

%%取装备属性列表
get_goods_attribute_list(PlayerId, GoodsId, AttributeType) ->
    Pattern = #goods_attribute{ player_id=PlayerId, gid=GoodsId, attribute_type=AttributeType, _='_'},
    get_ets_list(?ETS_GOODS_ATTRIBUTE, Pattern).

get_goods_attribute_list(PlayerId, GoodsId) ->
    Pattern = #goods_attribute{ player_id=PlayerId, gid=GoodsId, _='_'},
    get_ets_list(?ETS_GOODS_ATTRIBUTE, Pattern).

get_offline_goods_attribute_list(PlayerId,GoodsId,AttributeType)->
	db_agent:gu_get_offline_goods_attribute_list(goods_attribute,PlayerId,GoodsId,AttributeType).
																								
get_offline_goods_attribute_list(PlayerId, GoodsId) ->
    db_agent:gu_get_offline_goods_attribute_list(goods_attribute, PlayerId, GoodsId).


%%关键函数！！%%人物装备属性重新计算
count_role_equip_attribute(PlayerStatus, GoodsStatus, _GoodsInfo) ->
    %% 装备属性
    [FullStren,Effect] = get_equip_attribute(PlayerStatus#player.id, PlayerStatus#player.equip, GoodsStatus#goods_status.equip_suit),
	%% 装备加成的基础属性 
	Effect_base = get_equip_player_attribute(PlayerStatus#player.id,GoodsStatus#goods_status.equip_suit),
	%% 装备属性的系数加成
	Effect_mult = get_equip_mult_attribute(PlayerStatus#player.id,GoodsStatus#goods_status.equip_suit),
	%% 灵兽属性加成
	Pet_attribute = lib_pet:get_out_pet_attribute(PlayerStatus),
	%% 灵兽技能系数加成
	Pet_skill_mult_attribute = lib_pet:get_out_pet_skill_effect(PlayerStatus),
    %% 检查武器、衣服
    %%[NewGoodsStatus, _] = get_current_equip_by_info(GoodsInfo, [GoodsStatus, on]),
    %% 更新人物属性
    PlayerStatus1 = PlayerStatus#player{
						  other = PlayerStatus#player.other#player_other{
                           		equip_current = GoodsStatus#goods_status.equip_current,
                           		equip_attribute = Effect,
								equip_player_attribute = Effect_base,
								equip_mult_attribute = Effect_mult ,
								pet_attribute = Pet_attribute,
								pet_skill_mult_attribute = Pet_skill_mult_attribute,
								fullstren = FullStren
								}
                    		},
    %% 人物属性重新计算
    PlayerStatus2 = lib_player:count_player_attribute(PlayerStatus1),
    {ok, PlayerStatus2, GoodsStatus}.

%% 取装备的属性加成
%% 获取所有装备的属性加成
get_equip_attribute(PlayerId, Equip, EquipSuit) ->
    EquipList = get_equip_list(PlayerId, 10, Equip),
    %% 装备属性加成
    [Hp, Mp, MaxAtt, MinAtt, Def, Hit, Dodge, Crit, Anti_wind, Anti_fire, Anti_water ,Anti_thunder,Anti_soil,Anti_rift] = lists:foldl(fun count_goods_effect/2, [0,0,0,0,0,0,0,0,0,0,0,0,0,0], EquipList),
    %% 装备套装属性加成
    [Hp_lim2, Mp_lim2,Max_attack2,Min_attack2,Def2, Hit2,Dodge2, Crit2, _Forza2,_Physique2,_Agile2,_Wit2,Anti_wind2,Anti_fire2,Anti_water2,Anti_thunder2,Anti_soil2] = get_suit_attribute(EquipSuit),
	%% 全身装备强化加成
	[FullStren,[Max_attack3,Min_attack3,Hp_lim3,Def3,Anti_wind3,Anti_fire3,Anti_water3,Anti_thunder3,Anti_soil3]] = get_full_stren_attribute(PlayerId,EquipList),
	[FullStren,
	[
	 	Hp + Hp_lim2 + Hp_lim3, 
	 	Mp + Mp_lim2,
	 	MaxAtt + Max_attack2 + Max_attack3,
	 	MinAtt + Min_attack2 + Min_attack3,
	 	Def + Def2 + Def3,
	 	Hit + Hit2, 
	 	Dodge + Dodge2, 
	 	Crit + Crit2, 
	 	Anti_wind + Anti_wind2 + Anti_wind3,
	 	Anti_fire + Anti_fire2 + Anti_fire3, 
	 	Anti_water + Anti_water2 + Anti_water3 ,
	 	Anti_thunder + Anti_thunder2 +Anti_thunder3,
	 	Anti_soil + Anti_soil2 +Anti_soil3,
		Anti_rift
	]
	].

%% 获取所有装备对角色的基础属性加成 [forza,physique,wit,agile,speed]
get_equip_player_attribute(PlayerId,EquipSuit) ->
	EquipList = get_equip_list(PlayerId,10,1),
	[Forza,Physique,Wit,Agile,Speed] = lists:foldl(fun count_goods_player_effect/2 ,[0,0,0,0,0],EquipList),
	%%套装属性加成
	[_Hp_lim2, _Mp_lim2,_Max_attack2,_Min_attack2,_Def2, _Hit2,_Dodge2,_Crit2, Forza2,Physique2,Agile2,Wit2,_Anti_wind2,_Anti_fire2,_Anti_water2,_Anti_thunder2,_Anti_soil2] = get_suit_attribute(EquipSuit),
	[Forza+Forza2,Physique+Physique2,Wit+Wit2,Agile+Agile2,Speed].



%% 获取装备对气血暴击的系数加成[hp,crit]
get_equip_mult_attribute(PlayerId,_EquipSuit) ->
	EquipList = get_equip_list(PlayerId,10,1),
	[Mult_hp,Mult_crit,Max_att]= lists:foldl(fun count_goods_mult_effect/2,[0,0,0],EquipList),
	%%套装占位
	[Mult_hp,Mult_crit,Max_att].

%% 取单件装备的属性加成
%% 加成所有附加属性的单件装备属性加成
get_goods_attribute(GoodsInfo) ->
    [Hp1, Mp1, MaxAtt1, MinAtt1, Def1, Hit1, Dodge1, Crit1, Anti_wind1,Anti_fire1,Anti_water1,Anti_thunder1,Anti_soil1,Anti_rift1] = 
		[GoodsInfo#goods.hp, GoodsInfo#goods.mp, GoodsInfo#goods.max_attack, GoodsInfo#goods.min_attack,GoodsInfo#goods.def, GoodsInfo#goods.hit, 
		 GoodsInfo#goods.dodge, GoodsInfo#goods.crit, GoodsInfo#goods.anti_wind,GoodsInfo#goods.anti_fire,GoodsInfo#goods.anti_water,GoodsInfo#goods.anti_thunder,
		 GoodsInfo#goods.anti_soil,GoodsInfo#goods.anti_rift],
    %% 装备额外属性加成
    AttributeList = get_goods_attribute_list(GoodsInfo#goods.player_id, GoodsInfo#goods.id),
    [Hp2, Mp2, MaxAtt2, MinAtt2, Def2, Hit2, Dodge2, Crit2, Anti_wind2,Anti_fire2,Anti_water2,Anti_thunder2,Anti_soil2,Anti_rift2] = lists:foldl(fun count_goods_attribute_effect/2, [0,0,0,0,0,0,0,0,0,0,0,0,0,0], AttributeList),
    [Hp1+Hp2, Mp1+Mp2, MaxAtt1+MaxAtt2, MinAtt1+MinAtt2, Def1+Def2, Hit1+Hit2, Dodge1+Dodge2, Crit1+Crit2, Anti_wind1+Anti_wind2, Anti_fire1+Anti_fire2,Anti_water1+Anti_water2,Anti_thunder1+Anti_thunder2,Anti_soil1+Anti_soil2,Anti_rift1+Anti_rift2].

%% 取单件装备的基础属性加成
get_goods_player_attribute(GoodsInfo) ->
	%%附加属性不加成speed。
	Speed = GoodsInfo#goods.speed,
	[Forza1 ,Physique1,Wit1,Agile1] = [GoodsInfo#goods.forza,GoodsInfo#goods.physique,GoodsInfo#goods.wit,GoodsInfo#goods.agile],
	AttributeList = get_goods_attribute_list(GoodsInfo#goods.player_id, GoodsInfo#goods.id),
	[Forza,Physique,Wit,Agile] = lists:foldl(fun count_goods_player_attribute_effect/2, [0,0,0,0], AttributeList),
	[Forza1 + Forza,Physique1 + Physique,Wit1 + Wit,Agile1 + Agile,Speed].

%%取单件装备的属性系数加成
get_goods_mult_attribute(GoodsInfo) ->
	AttributeList = get_goods_attribute_list(GoodsInfo#goods.player_id, GoodsInfo#goods.id),
	[Mult_hp,Mult_crit,Max_att] = lists:foldl(fun count_goods_mult_attribute_effect/2, [0,0,0], AttributeList),
	[Mult_hp,Mult_crit,Max_att].

%%获取套装信息[{suit_id,suit_num}]
get_equip_suit(PlayerId) ->
    EquipList = goods_util:get_equip_list(PlayerId, 10, 1),
    F = fun(GoodsInfo, EquipSuit) ->
            change_equip_suit(EquipSuit, 0, GoodsInfo#goods.suit_id)
        end,
    EquipSuit = lists:foldl(F, [], EquipList),
    EquipSuit.

%%套装属性
%%[Hp_lim, Mp_lim, Max_attack,Min_attack,Def, Hit,Dodge, Crit, Forza,Physique,Agile,Wit,Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil]
get_suit_attribute(EquipSuit) ->
	F = fun({SuitId,SuitNum},List) ->
			if
				SuitNum >= 2 ->
					Pattern = #ets_base_goods_suit_attribute{ suit_id=SuitId, _='_'},
    				SuitAttributeInfo = get_ets_info(?ETS_BASE_GOODS_SUIT_ATTRIBUTE, Pattern),
					SuitNumAttributeInfo = get_suit_num_attribute({SuitId,SuitNum},SuitAttributeInfo),
					if
						is_record(SuitNumAttributeInfo,ets_base_goods_suit_attribute) ->
							[SuitNumAttributeInfo|List];
						true ->
							List
					end;
				true ->
					List
			end         
        end,
    SuitAttributeList = lists:foldl(F, [], EquipSuit),
    F2 = fun(SuitAttribute,Effect) ->
            count_suit_attribute_effect(SuitAttribute,Effect)
        end,
    SuitAttribute = lists:foldl(F2, [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], SuitAttributeList),
	SuitAttribute.

%%根据套装数量获取属性
get_suit_num_attribute({SuitId,SuitNum},SuitAttributeInfo) ->
	Pattern = #ets_base_goods_suit{suit_id = SuitId ,_='_'},
	BaseGoodsSuit = get_ets_info(?ETS_BASE_GOODS_SUIT,Pattern),
	if
		is_record(BaseGoodsSuit ,ets_base_goods_suit) ->
			SuitEffect = util:string_to_term(tool:to_list(BaseGoodsSuit#ets_base_goods_suit.suit_effect)),
			AttributeIdList = 
				case lists:member(SuitId, [51,52,53,54,55]) of
					true ->%%新手套
						case SuitNum of
							3 ->
								SuitEffect;
							_ ->
								[]
						end;
					false ->%%普通套装
						case SuitNum of
							2 ->
								Spt = lists:member(SuitId, [36,37,38,39,40]),%%饰品套
								if
									Spt ->
										SuitEffect;
									true ->
										lists:sublist(SuitEffect, 1)
								end;
							3 -> lists:sublist(SuitEffect, 1);
							4 -> lists:sublist(SuitEffect, 2);
							5 -> lists:sublist(SuitEffect, 2);
							6 -> SuitEffect
						end
				end,
			F = fun(AttributeId,_SuitAttributeInfo) ->
					AttributeName = get_attribute_name_by_id(AttributeId),
					case AttributeName of
							hp ->_SuitAttributeInfo;
							mp ->_SuitAttributeInfo;
							max_attack ->
								_SuitAttributeInfo#ets_base_goods_suit_attribute{max_attack = SuitAttributeInfo#ets_base_goods_suit_attribute.max_attack,
																				 min_attack = SuitAttributeInfo#ets_base_goods_suit_attribute.min_attack };
							def ->
								_SuitAttributeInfo#ets_base_goods_suit_attribute{def =SuitAttributeInfo#ets_base_goods_suit_attribute.def };
							hit ->
								_SuitAttributeInfo#ets_base_goods_suit_attribute{hit =SuitAttributeInfo#ets_base_goods_suit_attribute.hit };
							dodge ->
								_SuitAttributeInfo#ets_base_goods_suit_attribute{dodge =SuitAttributeInfo#ets_base_goods_suit_attribute.dodge };
							crit ->
								_SuitAttributeInfo#ets_base_goods_suit_attribute{crit =SuitAttributeInfo#ets_base_goods_suit_attribute.crit };
							min_attack ->
								_SuitAttributeInfo#ets_base_goods_suit_attribute{min_attack =SuitAttributeInfo#ets_base_goods_suit_attribute.min_attack,
																				 max_attack = SuitAttributeInfo#ets_base_goods_suit_attribute.max_attack};
							physique ->
								_SuitAttributeInfo#ets_base_goods_suit_attribute{physique =SuitAttributeInfo#ets_base_goods_suit_attribute.physique};
							anti_wind ->
								_SuitAttributeInfo#ets_base_goods_suit_attribute{anti_wind =SuitAttributeInfo#ets_base_goods_suit_attribute.anti_wind};
							anti_fire ->
								_SuitAttributeInfo#ets_base_goods_suit_attribute{anti_fire =SuitAttributeInfo#ets_base_goods_suit_attribute.anti_fire};
							anti_water ->
								_SuitAttributeInfo#ets_base_goods_suit_attribute{anti_water =SuitAttributeInfo#ets_base_goods_suit_attribute.anti_water};
							anti_thunder ->
								_SuitAttributeInfo#ets_base_goods_suit_attribute{anti_thunder =SuitAttributeInfo#ets_base_goods_suit_attribute.anti_thunder};
							anti_soil ->
								_SuitAttributeInfo#ets_base_goods_suit_attribute{anti_soil =SuitAttributeInfo#ets_base_goods_suit_attribute.anti_soil};
							forza ->
								_SuitAttributeInfo#ets_base_goods_suit_attribute{forza =SuitAttributeInfo#ets_base_goods_suit_attribute.forza};
							agile ->
								_SuitAttributeInfo#ets_base_goods_suit_attribute{agile =SuitAttributeInfo#ets_base_goods_suit_attribute.agile};
							wit -> 
								_SuitAttributeInfo#ets_base_goods_suit_attribute{wit =SuitAttributeInfo#ets_base_goods_suit_attribute.wit};
							speed -> _SuitAttributeInfo;
							hp_lim ->
								_SuitAttributeInfo#ets_base_goods_suit_attribute{hp_lim =SuitAttributeInfo#ets_base_goods_suit_attribute.hp_lim};
							mp_lim ->
								_SuitAttributeInfo#ets_base_goods_suit_attribute{mp_lim =SuitAttributeInfo#ets_base_goods_suit_attribute.mp_lim};
							_ ->_SuitAttributeInfo
					end
				end,
			NewSuitAttributeInfo = #ets_base_goods_suit_attribute{id=SuitAttributeInfo#ets_base_goods_suit_attribute.id,
																  career_id =SuitAttributeInfo#ets_base_goods_suit_attribute.career_id,
																  suit_id = SuitAttributeInfo#ets_base_goods_suit_attribute.suit_id,
																  suit_num = SuitAttributeInfo#ets_base_goods_suit_attribute.suit_num,
																  level = SuitAttributeInfo#ets_base_goods_suit_attribute.level
																 },
			lists:foldl(F, NewSuitAttributeInfo, AttributeIdList);
		true ->
			skip
	end.

%%辅助
count_goods_effect(GoodsInfo, [Hp1, Mp1, MaxAtt1, MinAtt1, Def1, Hit1, Dodge1, Crit1, Anti_wind1,Anti_fire1,Anti_water1,Anti_thunder1,Anti_soil1,Anti_rift1]) ->
    [Hp2, Mp2, MaxAtt2, MinAtt2, Def2, Hit2, Dodge2, Crit2, Anti_wind2,Anti_fire2,Anti_water2,Anti_thunder2,Anti_soil2,Anti_rift2] = get_goods_attribute(GoodsInfo),
    [Hp1+Hp2, Mp1+Mp2, MaxAtt1+MaxAtt2, MinAtt1+MinAtt2, Def1+Def2, Hit1+Hit2, Dodge1+Dodge2, Crit1+Crit2, Anti_wind1+Anti_wind2,Anti_fire1+Anti_fire2,Anti_water1+Anti_water2,Anti_thunder1+Anti_thunder2,Anti_soil1+ Anti_soil2,Anti_rift1+Anti_rift2].

%%辅助
count_goods_player_effect(GoodsInfo,[Forza1,Physique1,Wit1,Agile1,Speed1]) ->
	[Forza2,Physique2,Wit2,Agile2,Speed2] = get_goods_player_attribute(GoodsInfo),
	[Forza1+Forza2,Physique1+Physique2,Wit1+Wit2,Agile1+Agile2,Speed1+Speed2].

%%辅助(统计气血百分比，暴击百分比，攻击百分比)
count_goods_mult_effect(GoodsInfo,[Mult_hp1,Mult_crit1,Max_att1]) ->
	[Mult_hp2,Mult_crit2,Max_att2] = get_goods_mult_attribute(GoodsInfo),
	[Mult_hp1+Mult_hp2 , Mult_crit1+ Mult_crit2, Max_att1+Max_att2].

%%辅助
count_goods_attribute_effect(AttributeInfo, [Hp, Mp, MaxAtt, MinAtt, Def, Hit, Dodge, Crit, Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil,Anti_rift]) ->
	if
		AttributeInfo#goods_attribute.status =:= 1 andalso AttributeInfo#goods_attribute.value_type =:= 0 ->
    		[ Hp + AttributeInfo#goods_attribute.hp,
      		Mp + AttributeInfo#goods_attribute.mp,
			MaxAtt + AttributeInfo#goods_attribute.max_attack,
	  		MinAtt + AttributeInfo#goods_attribute.min_attack,
      		Def + AttributeInfo#goods_attribute.def,
      		Hit + AttributeInfo#goods_attribute.hit,
      		Dodge + AttributeInfo#goods_attribute.dodge,
      		Crit + AttributeInfo#goods_attribute.crit,
      		Anti_wind + AttributeInfo#goods_attribute.anti_wind,
	  		Anti_fire + AttributeInfo#goods_attribute.anti_fire,
	  		Anti_water + AttributeInfo#goods_attribute.anti_water,
	  		Anti_thunder + AttributeInfo#goods_attribute.anti_thunder,
	  		Anti_soil + AttributeInfo#goods_attribute.anti_soil,
			Anti_rift + AttributeInfo#goods_attribute.anti_rift 
			];
		true ->
			[Hp, Mp, MaxAtt, MinAtt, Def, Hit, Dodge, Crit, Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil,Anti_rift]
	end.
%%辅助
count_goods_player_attribute_effect(AttributeInfo,[Forza,Physique,Wit,Agile]) ->
	if
		%%已鉴定的属性才可用
		AttributeInfo#goods_attribute.status =:= 1 andalso AttributeInfo#goods_attribute.value_type =:= 0->
			[Forza + AttributeInfo#goods_attribute.forza,
	 		Physique + AttributeInfo#goods_attribute.physique,
	 		Wit + AttributeInfo#goods_attribute.wit,
	 		Agile + AttributeInfo#goods_attribute.agile
	 		];
		true ->
			[Forza,Physique,Wit,Agile]
	end.
%%辅助
count_goods_mult_attribute_effect(AttributeInfo,[Mult_hp,Mult_crit,Max_att]) ->
	if
		AttributeInfo#goods_attribute.status =:= 1 andalso AttributeInfo#goods_attribute.value_type =:= 1 ->
			[Mult_hp + AttributeInfo#goods_attribute.hp,
			 Mult_crit + AttributeInfo#goods_attribute.crit,
			 Max_att + AttributeInfo#goods_attribute.max_attack
			 ];
		true ->
			[Mult_hp,Mult_crit,Max_att]
	end.
%%辅助
count_suit_attribute_effect(SuitAttribute, [Hp_lim, Mp_lim, Max_attack,Min_attack,Def, Hit,Dodge, Crit, Forza,Physique,Agile,Wit,Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil]) ->
    [ Hp_lim + SuitAttribute#ets_base_goods_suit_attribute.hp_lim,
      Mp_lim + SuitAttribute#ets_base_goods_suit_attribute.mp_lim,
	  Max_attack + SuitAttribute#ets_base_goods_suit_attribute.max_attack,
	  Min_attack + SuitAttribute#ets_base_goods_suit_attribute.min_attack,
	  Def + SuitAttribute#ets_base_goods_suit_attribute.def,
      Hit + SuitAttribute#ets_base_goods_suit_attribute.hit,
      Dodge + SuitAttribute#ets_base_goods_suit_attribute.dodge,
      Crit + SuitAttribute#ets_base_goods_suit_attribute.crit,
      Forza + SuitAttribute#ets_base_goods_suit_attribute.forza,
      Physique + SuitAttribute#ets_base_goods_suit_attribute.physique,
      Agile + SuitAttribute#ets_base_goods_suit_attribute.agile,
      Wit + SuitAttribute#ets_base_goods_suit_attribute.wit, 
      Anti_wind + SuitAttribute#ets_base_goods_suit_attribute.anti_wind,
      Anti_fire + SuitAttribute#ets_base_goods_suit_attribute.anti_fire,
      Anti_water + SuitAttribute#ets_base_goods_suit_attribute.anti_water,
      Anti_thunder + SuitAttribute#ets_base_goods_suit_attribute.anti_thunder,
      Anti_soil + SuitAttribute#ets_base_goods_suit_attribute.anti_soil
	   ].

%%合并属性
merge_goods_effect(Effect1,Effect2) ->
	[Hp1, Mp1, MaxAtt1, MinAtt1, Def1, Hit1, Dodge1, Crit1, Anti_wind1,Anti_fire1,Anti_water1,Anti_thunder1,Anti_soil1] = Effect1,
	[Hp2, Mp2, MaxAtt2, MinAtt2, Def2, Hit2, Dodge2, Crit2, Anti_wind2,Anti_fire2,Anti_water2,Anti_thunder2,Anti_soil2] = Effect2,
	[Hp1+Hp2, Mp1+Mp2, MaxAtt1+MaxAtt2, MinAtt1+MinAtt2, Def1+Def2, Hit1+Hit2, Dodge1+Dodge2, Crit1+Crit2, Anti_wind1+Anti_wind2,Anti_fire1+Anti_fire2,Anti_water1+Anti_water2,Anti_thunder1+Anti_thunder2,Anti_soil1+Anti_soil2].

%%查找suitid的当前数量
get_suit_num(EquipSuit, SuitId) ->
    case SuitId > 0 of
        true ->
            case lists:keyfind(SuitId, 1, EquipSuit) of
                false -> 0;
                {SuitId, SuitNum} -> SuitNum
            end;
        false -> 0
    end.
	
%%动态增删
change_equip_suit(EquipSuit, OldSuitId, NewSuitId) ->
    %% 删除
    EquipSuit1 = if OldSuitId > 0 ->
                        case lists:keyfind(OldSuitId, 1, EquipSuit) of
                            false ->
                                EquipSuit;
                            {OldSuitId, SuitNum} when SuitNum > 1 ->
                                lists:keyreplace(OldSuitId, 1, EquipSuit, {OldSuitId, SuitNum-1});
                            {OldSuitId, _} ->
                                lists:keydelete(OldSuitId, 1, EquipSuit)
                        end;
                    true -> EquipSuit
                end,
    %% 添加
    EquipSuit2 = if NewSuitId > 0 ->
                        case lists:keyfind(NewSuitId, 1, EquipSuit1) of
                            false ->
                                [{NewSuitId, 1} | EquipSuit1];
                            {NewSuitId, SuitNum2} ->
                                lists:keyreplace(NewSuitId, 1, EquipSuit1, {NewSuitId, SuitNum2+1})
                        end;
                    true -> EquipSuit1
                end,
    EquipSuit2.

%%检查是否已经穿完整一套 return 0/suitId
is_full_suit(EquipSuit)->
	F = fun(ES,{CurSuitId,CurSuitNum}) ->
				case ES of
					{SuitId,SuitNum} ->
						if
							SuitNum > CurSuitNum ->
								{SuitId,SuitNum};
							true ->
								{CurSuitId,CurSuitNum}
						end;
					_ ->
						{CurSuitId,CurSuitNum}
				end
		end,
	GetSuit = lists:foldl(F, {0,0}, EquipSuit),
	case GetSuit of
		{GetSuitId,6} ->
			GetSuitId;
		_ ->
			0
	end.

%% 获取全套强化加成属性
get_full_stren_attribute(_PlayerId,EquipList) ->
%% 	HolidayInfo = goods_util:get_ets_info(?ETS_HOLIDAY_INFO, _PlayerId),
	case length(EquipList) >=9 of
		true ->
			Pos = [1,2,3,4,5,6,7,10,11],
			F = fun(Goods,[Cell,Stren]) ->
						case lists:member(Goods#goods.cell, Pos) of
							true ->
								[[Goods#goods.cell|Cell],[Goods#goods.stren|Stren]];
							false ->
								[Cell,Stren]
						end
				end,
			[Cells,Strens] = lists:foldl(F, [[],[]], EquipList),		
			case lists:sort(Cells) == Pos of
				true ->
					MinStren = lists:min(Strens),
					%%%%%%%%%%%%%%%元旦全身强化活动%%%%%%
%% 					Now = util:unixtime(),
%% 					%%元旦活动时间
%% 					{ST, ET} = lib_activities:newyear_time(),
%% 					if 
%% 						Now > ST andalso Now < ET andalso MinStren >= 5 ->
%% 							
%% 							case HolidayInfo#ets_holiday_info.has_full_stren_info == 1 of
%% 								true ->
%% 									NewHolidayInfo = HolidayInfo#ets_holiday_info{full_stren = MinStren};
%% 								false ->
%% %% 									db_agent:insert_mid_prize([pid,type,num,got],[_PlayerId,5,0,0]),
%% 									NewHolidayInfo = HolidayInfo#ets_holiday_info{full_stren = MinStren ,has_full_stren_info = 1}
%% 							end,
%% 							ets:insert(?ETS_HOLIDAY_INFO, NewHolidayInfo);
%% 						true ->
%% 							skip
%% 					end,
					%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
					if						
						MinStren == 5 orelse MinStren == 6 -> 
							[5,[50,50,150,75,50,50,50,50,50]];
						MinStren == 7 -> 
							[7,[100,100,400,200,100,100,100,100,100]];
						MinStren == 8 ->
							[8,[200,200,650,350,200,200,200,200,200]];
						MinStren == 9 ->
							[9,[350,350,1000,550,350,350,350,350,350]];
						MinStren == 10 ->
							[10,[500,500,1500,800,500,500,500,500,500]];
						true ->
							[0,[0,0,0,0,0,0,0,0,0]]
					end;
				false ->
					%%元旦活动 不是全套则为0
%% 					ets:insert(?ETS_HOLIDAY_INFO, HolidayInfo#ets_holiday_info{full_stren = 0}),
					[0,[0,0,0,0,0,0,0,0,0]]
			end;
		false ->
			%%元旦活动 不是全套则为0
%% 			ets:insert(?ETS_HOLIDAY_INFO, HolidayInfo#ets_holiday_info{full_stren = 0}),
			[0,[0,0,0,0,0,0,0,0,0]]
	end.
	
%% 取装备类型附加属性值 [气血,法力,力量，敏捷，智力，体质，暴击，躲避,风抗,火抗,水抗,雷抗,土抗,攻击,抗性穿透] N = 15
%%@spec get_add_attribute_by_type(BaseAddAttributeInfo) -> [forza, agile, wit,physique, crit, dodge]
get_add_attribute_by_type(BaseAddAttributeInfo) ->
    Value = BaseAddAttributeInfo#ets_base_goods_add_attribute.value,
    case BaseAddAttributeInfo#ets_base_goods_add_attribute.attribute_id of
		1  -> [Value, 0,0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ,0 ,0];%%气血
		19 -> [Value,0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ,0 ,0];%%气血上限
		22 -> [Value,0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ,0 ,0];%%气血百分比
		2  -> [0, Value,0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ,0 ,0];
		3  -> [0,0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ,Value, 0];%%攻击
		21 -> [0,0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ,Value, 0];%%攻击百分比
        15 -> [0,0,Value, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ,0 ,0];
        16 -> [0,0,0, Value, 0, 0, 0, 0, 0, 0, 0, 0, 0 ,0 ,0];
        17 -> [0,0,0, 0, Value, 0, 0, 0, 0, 0, 0, 0, 0 ,0 ,0];
        9 ->  [0,0,0, 0, 0, Value, 0, 0, 0, 0, 0, 0, 0 ,0 ,0];
        7 ->  [0,0,0, 0, 0, 0, Value, 0, 0, 0, 0, 0, 0 ,0 ,0];
        6 ->  [0,0,0, 0, 0, 0, 0, Value, 0, 0, 0, 0, 0 ,0 ,0];
		10 -> [0,0,0, 0, 0, 0, 0, 0, Value, 0, 0, 0, 0 ,0 ,0];
		11 -> [0,0,0, 0, 0, 0, 0, 0, 0, Value, 0, 0, 0 ,0 ,0];
		12 -> [0,0,0, 0, 0, 0, 0, 0, 0, 0, Value, 0, 0 ,0 ,0];
		13 -> [0,0,0, 0, 0, 0, 0, 0, 0, 0, 0, Value, 0 ,0 ,0];
		14 -> [0,0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, Value ,0 ,0];
		23 -> [0,0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ,0 ,Value];
        _ ->  [0,0,0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ,0, 0]
    end.


%% 计算装备强化加成
%% @spec count_stren_addition(GoodsInfo, Stren) -> [Hp, Mp, MaxAtt,MinAtt, Def, Hit, Dodge, Crit, Ten]
count_stren_addition(GoodsInfo, Stren) ->
	%%去掉品质
    %%QFactor = get_quality_factor(GoodsInfo#goods.quality),
    CFactor = get_stren_color_factor(GoodsInfo#goods.color),
    SFactor = get_stren_factor(Stren),
    Hp = round(GoodsInfo#goods.hp * CFactor * SFactor),
    Mp = round(GoodsInfo#goods.mp * CFactor * SFactor),
    MaxAtt = round(GoodsInfo#goods.max_attack * CFactor * SFactor),
	MinAtt = round(GoodsInfo#goods.min_attack * CFactor * SFactor),
    Def = round(GoodsInfo#goods.def  * CFactor * SFactor),
    Hit = round(GoodsInfo#goods.hit  * CFactor * SFactor),
    Dodge = round(GoodsInfo#goods.dodge  * CFactor * SFactor),
    Crit = round(GoodsInfo#goods.crit * CFactor * SFactor),
	%%抗性是否需要加成
	Anti_wind = GoodsInfo#goods.anti_wind,
	Anti_fire = GoodsInfo#goods.anti_fire,
	Anti_water = GoodsInfo#goods.anti_water,
	Anti_thunder = GoodsInfo#goods.anti_thunder,
	Anti_soil = GoodsInfo#goods.anti_soil,
    [Hp, Mp, MaxAtt,MinAtt,Def, Hit, Dodge, Crit, Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil].

%% 计算宝石镶嵌加成
%% 全属性 顺序与id属性是不一致的。
count_inlay_addition(StoneInfo) ->
    Hp = StoneInfo#goods.hp,
    Mp = StoneInfo#goods.mp,
    MaxAtt = StoneInfo#goods.max_attack,
	MinAtt = StoneInfo#goods.min_attack,
    Def = StoneInfo#goods.def,
    Hit = StoneInfo#goods.hit,
    Dodge = StoneInfo#goods.dodge,
    Crit = StoneInfo#goods.crit,
	Physique = StoneInfo#goods.physique,
    Anti_wind = StoneInfo#goods.anti_wind,
	Anti_fire = StoneInfo#goods.anti_fire,
	Anti_water = StoneInfo#goods.anti_water,
	Anti_thunder = StoneInfo#goods.anti_thunder,
	Anti_soil = StoneInfo#goods.anti_soil,
	Forza =StoneInfo#goods.forza,
	Agile =StoneInfo#goods.agile,
	Wit =StoneInfo#goods.wit,
    [Hp, Mp, MaxAtt,MinAtt,Def, Hit, Dodge, Crit, Physique,Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil,Forza,Agile,Wit].

%% 装备强化加成系数
get_stren_factor(Stren) ->
    case Stren of
        0  -> 0;
        1  -> 0.06;
        2  -> 0.15;
        3  -> 0.26;
        4  -> 0.38;
        5  -> 0.48;
        6  -> 0.6;
        7  -> 0.74;
        8  -> 0.82;
        9  -> 0.9;
        10 -> 1;
        _  -> 0
    end.

%% 装备强化颜色系数
get_stren_color_factor(Color) ->
    case Color of
        0  -> 0.9;
        1  -> 0.95;
        2  -> 1;
        3  -> 1.1;
        4  -> 1.25;
        _  -> 0.9
    end.

% 装备加成属性类型ID 这里决定加攻或是加防或是加移动速度
get_goods_attribute_id(Subtype) ->
    if
        Subtype >= 9 andalso  Subtype =< 13 ->
            3;
		Subtype =:= 22 ->
			18;
		Subtype =:= 24 ->
			1;
		Subtype =:= 26 ->
			26;
		Subtype =:= 27 ->
			27;
        true ->
            4
    end.


% 镶嵌宝石的属性类型ID
get_inlay_attribute_id(StoneInfo) ->
    case is_record(StoneInfo, goods) of
        true when StoneInfo#goods.hp > 0    -> 1;
        true when StoneInfo#goods.mp > 0    -> 2;
        true when StoneInfo#goods.max_attack > 0   -> 3;
        true when StoneInfo#goods.def > 0   -> 4;
        true when StoneInfo#goods.hit > 0   -> 5;
        true when StoneInfo#goods.dodge > 0 -> 6;
        true when StoneInfo#goods.crit > 0  -> 7;
        true when StoneInfo#goods.min_attack  -> 8;
		true when StoneInfo#goods.physique >0 -> 9;
		true when StoneInfo#goods.anti_wind >0 ->10;
		true when StoneInfo#goods.anti_fire >0 ->11;
		true when StoneInfo#goods.anti_water >0 ->12;
		true when StoneInfo#goods.anti_thunder >0 ->13;
		true when StoneInfo#goods.anti_soil > 0 ->14;
		true when StoneInfo#goods.forza > 0 -> 15;
		true when StoneInfo#goods.agile > 0 -> 16;
		true when StoneInfo#goods.wit >0 -> 17;
        _ -> 
			?DEBUG("goods_util/get_inlay_attribute_id/err_no_record",[]),
			0
    end.

%%获取附加属性的类型和值
get_add_attribute_type_value(Attribute) ->
	case  is_record(Attribute,goods_attribute) of
		true when Attribute#goods_attribute.dodge > 0 -> [dodge,Attribute#goods_attribute.dodge];
		true when Attribute#goods_attribute.crit > 0 -> [crit,Attribute#goods_attribute.crit];
		true when Attribute#goods_attribute.physique >0 -> [physique,Attribute#goods_attribute.physique];
		true when Attribute#goods_attribute.forza > 0 -> [forza,Attribute#goods_attribute.forza];
		true when Attribute#goods_attribute.agile > 0 -> [agile,Attribute#goods_attribute.agile];
		true when Attribute#goods_attribute.wit > 0 -> [wit,Attribute#goods_attribute.wit];
		_-> [wit,0]
	end.
%%根据修炼规则和属性名字提取修炼属性数值
get_practise_attribute_value_by_name(AttName,GoodsPractiseRule) ->
	case is_record(GoodsPractiseRule,ets_base_goods_practise) of
		true ->
			case AttName of
%% 				dodge ->
%% 					GoodsPractiseRule#ets_base_goods_practise.dodge;
%% 				crit ->
%% 					GoodsPractiseRule#ets_base_goods_practise.crit;
				physique ->
					GoodsPractiseRule#ets_base_goods_practise.physique;
				forza ->
					GoodsPractiseRule#ets_base_goods_practise.forza;
				agile ->
					GoodsPractiseRule#ets_base_goods_practise.agile;
				wit ->
					GoodsPractiseRule#ets_base_goods_practise.wit;
				_ -> 0
			end;
		_ ->
			0
	end.
%% 取得装备的使用次数
%% @spec get_goods_use_num(Attrition) -> UseNum
get_goods_use_num(Attrition) ->
    Attrition * 10.

%% 取得装备的耐久度
%% @spec get_goods_attrition(UseNum) -> Attrition
get_goods_attrition(OldAttrition, UseNum) ->
    Attrition = case OldAttrition > 0 of
                    false -> 0;
                    true -> round( UseNum / 10 + 0.5 )
                end,
    case Attrition > OldAttrition of
        true -> OldAttrition;
        false -> Attrition
    end.

%% 取修理装备价格
get_mend_cost(Attrition, UseNum) ->
    TotalUseNum = get_goods_use_num(Attrition),
    Cost = trunc( (TotalUseNum - UseNum) * 1 ),
    Cost.

%%注意有同名函数！
%%默认装备格子位置, 0 默认位置，1 武器，2 衣服，3 腰带，4 护腕， 5 护手， 6 裤子，7 鞋子，8 饰品一，9 饰品二，10 戒指一，11 戒指二，12 灵兽 ,13 时装,14婚戒 15 法宝时装 16饰品时装
get_equip_cell(PlayerStatus,Subtype) ->
    case Subtype of
		9 ->1;       % 弓
        10 -> 1;    % 斧
		11 -> 1;	% 剑
		12 -> 1;	% 印
		13 -> 1;	% 琴
        19 -> 2;    % 衣服
        18 -> 3;    % 腰带
        14 -> 4;    % 护腕
        15 -> 5;    % 护手
        16 -> 6;    % 裤子
        17 -> 7;    % 鞋子
		24 -> 13;  %时装 
		25 -> 14;	%婚戒
		26 -> 15;	%法宝时装
		27 -> 16;	%饰品时装
        21 ->
			Cell8=get_goods_by_cell(PlayerStatus#player.id,1,8),
			if
				% 饰品一 
				 is_record(Cell8,goods) =/= true ->
					8;
				true ->
					9
			end;
        20 -> % 戒指
			Cell10 = get_goods_by_cell(PlayerStatus#player.id,1,10),
			if
				
				is_record(Cell10,goods) =/= true ->
					10;
				true ->
					11
			end;
		23 -> % 新戒指
			Cell10 = get_goods_by_cell(PlayerStatus#player.id,1,10),
			if
				
				is_record(Cell10,goods) =/= true ->
					10;
				true ->
					11
			end;
        _  -> 12    % 灵兽
    end.
%% 取属性ID
get_attribute_id_by_name(Name) ->
	case Name of
		hp ->1;
		mp ->2;
		max_attack ->3;
		def ->4;
		hit ->5;
		dodge ->6;
		crit ->7;
		min_attack -> 8;
		physique -> 9;
		anti_wind ->10;
		anti_fire ->11;
		anti_water ->12;
		anti_thunder ->13;
		anti_soil ->14;
		anti_rift ->23;
		forza ->15;
		agile ->16;
		wit -> 17;
		speed ->18;
		hp_lim ->19;
		mp_lim ->20;
		_ -> 0
	end.
%%取属性名称
get_attribute_name_by_id(Id) ->
	case Id of
		1 -> hp ;
		2 -> mp ;
		3 -> max_attack ;
		4 -> def ;
		5 -> hit ;
		6 -> dodge ;
		7 -> crit ;
		8 -> min_attack ;
		9 -> physique ;
		10 -> anti_wind ;
		11 -> anti_fire ;
		12 -> anti_water ;
		13 -> anti_thunder ;
		14 -> anti_soil ;
		15 -> forza ;
		16 -> agile ;
		17 -> wit;
		18 ->speed;
		19 -> hp_lim;
		20 -> mp_lim;
		23 ->anti_rift;
		0 -> anti_all;
		_ -> undefined
	end.
%%根据属性取属性值
get_attribute_value(AttributeInfo) ->
    case AttributeInfo#goods_attribute.attribute_id of
        1 -> AttributeInfo#goods_attribute.hp;
        2 -> AttributeInfo#goods_attribute.mp;
        3 -> AttributeInfo#goods_attribute.max_attack;
        4 -> AttributeInfo#goods_attribute.def;
        5 -> AttributeInfo#goods_attribute.hit;
        6 -> AttributeInfo#goods_attribute.dodge;
        7 -> AttributeInfo#goods_attribute.crit;
		8 -> AttributeInfo#goods_attribute.min_attack;
		9 -> AttributeInfo#goods_attribute.physique;
		10 -> AttributeInfo#goods_attribute.anti_wind;
		11 -> AttributeInfo#goods_attribute.anti_fire;
		12 -> AttributeInfo#goods_attribute.anti_water;
		13 -> AttributeInfo#goods_attribute.anti_thunder;
		14 -> AttributeInfo#goods_attribute.anti_soil;
		15 -> AttributeInfo#goods_attribute.forza;
		16 -> AttributeInfo#goods_attribute.agile;
		17 -> AttributeInfo#goods_attribute.wit;
		19 -> AttributeInfo#goods_attribute.hp;
		20 -> AttributeInfo#goods_attribute.mp;
		21 -> AttributeInfo#goods_attribute.max_attack;
		22 -> AttributeInfo#goods_attribute.hp;
		23 -> AttributeInfo#goods_attribute.anti_rift;
		%% 0 防具强化中5抗属性
		0 -> AttributeInfo#goods_attribute.anti_wind;
        _ -> 0
    end.

%% 经验卡对应的经验
get_goods_exp(Color) ->
    case Color of
        0 -> 1000;    % 初级经验卡
        1 -> 5000;    % 中级经验卡
        2 -> 10000;   % 高级经验卡
        _  -> 0
    end.

%% 检查物品还需要多少格子数
get_null_cell_num(GoodsList, MaxNum, GoodsNum) ->
    case MaxNum > 1 of
        true ->
            TotalNum = lists:foldl(fun(X, Sum) -> X#goods.num + Sum end, 0, GoodsList),
            CellNum = util:ceil( (TotalNum+GoodsNum)/ MaxNum ),
%%             ( CellNum - length(GoodsList) );
			%%返回数值经过修改--xiaomai
			case CellNum =< length(GoodsList) of
				true ->%%能够全部合并进去了，所以直接返回0
					0;
				false ->%%需要多出来的格子
					CellNum -length(GoodsList)
			end;
        false ->
            GoodsNum
    end.

%% 获取背包空位
get_null_cells(PlayerId, CellNum) ->
    Pattern = #goods{ player_id=PlayerId, location=4, _='_' },
    List = get_ets_list(?ETS_GOODS_ONLINE, Pattern),
	List1 = [Good || Good <- List,Good#goods.cell < 200],
    Cells = lists:map(fun(GoodsInfo) -> [GoodsInfo#goods.cell] end, List1),
    AllCells = lists:seq(1, CellNum),
    NullCells = lists:filter(fun(X) -> not(lists:member([X], Cells)) end, AllCells),
    NullCells.

get_box_null_cells(PlayerId) ->
	Pattern = #goods{player_id = PlayerId, location=7, _='_'},
	MatchObject = ets:match_object(?ETS_GOODS_ONLINE, Pattern),
	?BOX_GOODS_STORAGE - length(MatchObject).
%% 按格子位置排序
sort(GoodsList, Type) ->
    case Type of
        cell -> F = fun(G1, G2) -> G1#goods.cell < G2#goods.cell end;
        goods_id -> F = fun(G1, G2) -> G1#goods.goods_id < G2#goods.goods_id end;
        _ -> F = fun(G1, G2) -> G1#goods.cell < G2#goods.cell end
    end,
    lists:sort(F, GoodsList).

%% 判断荣誉是否足够
is_enough_honor(PlayerStatus,Cost,_Type) ->
	[Honor] = db_agent:query_player_honor(PlayerStatus#player.id),
	Honor >= Cost.

%% 判断是功勋足够
is_enough_feats(PlayerStatus,Cost,_Type) ->
%% 	PlayerStatus#player.other#player_other.guild_feats >= Cost andalso PlayerStatus#player.guild_id =/= 0.
	case db_agent:get_player_feats(PlayerStatus#player.id) of
		null ->
			false;
		Num ->
			PlayerStatus#player.other#player_other.guild_feats >= Cost 
	andalso PlayerStatus#player.guild_id =/= 0
	andalso Num >= Cost
	end.
		

%% 判断积分是否充足
is_enough_score(PlayerStatus,Cost,_Type) ->
	[Score] = db_agent:query_player_score(PlayerStatus#player.id),
	Score >= Cost.

%% 判断商城积分是否充足
is_enough_shop_score(PlayerStatus,Cost) ->
	Score = lib_player:get_gold_for_score(PlayerStatus#player.id),
	Score >= Cost.

%%判断镇妖功勋是否充足
is_enough_hor_td(PHorTd,Cost,_Type) ->
	PHorTd >= Cost.
%%扣天蚕丝28404
is_enough_tcsgold_fashion(Gold,TCSCost,GoodsPrice,GoodsTypeId,GoodsStatus,_Type) ->
	case Gold >= GoodsPrice of
		false ->
			2;%%元宝不足
		true ->
			 GoodsList = goods_util:get_type_goods_list(GoodsStatus#goods_status.player_id, GoodsTypeId, 4),
			 TotalNum = goods_util:get_goods_totalnum(GoodsList),
			 if
				 length(GoodsList) =:= 0 ->
					 3;	%% 物品不存在        
				 TotalNum < TCSCost ->
					 3;	%% 物品数量不足
				 true ->
					 case (catch lib_goods:delete_more(GoodsStatus, GoodsList, TCSCost)) of
						 {ok, NewStatus} ->%%扣物品成功
							 lib_player:refresh_client(GoodsStatus#goods_status.pid_send, 2),
							 {1, NewStatus};
						 Error ->
							 ?ERROR_MSG("mod_goods delete_more:~p", [Error]),
							 4	%% 失败
					 end
			 end
	end.
	

%% 判断金钱是否充足，true为充足，false为不足
is_enough_money(PlayerStatus, NewCost, Type) ->
	if NewCost < 0 ->false;
	   true->
%% 		   NewCost = Cost,
		   case Type of
			   coin ->
				   if
					   NewCost >= 50000 ->
						   [Coin, Bcoin] = db_agent:query_player_coin(PlayerStatus#player.id),
						   Coin + Bcoin >= NewCost;
					   true ->
						   (PlayerStatus#player.bcoin + PlayerStatus#player.coin) >= NewCost
				   end;
			   coinonly ->
				   if
					   NewCost >= 50000 ->
						   [Coin, _Bcoin] = db_agent:query_player_coin(PlayerStatus#player.id),
						   Coin >= NewCost;
					   true ->
						   PlayerStatus#player.coin >= NewCost
				   end;
			   cash ->
				   [_Gold,Cash] = db_agent:query_player_money(PlayerStatus#player.id),
					Cash >= NewCost;
			   gold ->
				   [Gold,_Cash] = db_agent:query_player_money(PlayerStatus#player.id),
				   Gold >= NewCost;
			   bcoin ->
				   if
					   NewCost >= 50000 ->
						   [_Coin, Bcoin] = db_agent:query_player_coin(PlayerStatus#player.id),
						   Bcoin >= NewCost;
					   true ->
						   PlayerStatus#player.bcoin >= NewCost
				   end;
			   shop_score ->
					   is_enough_shop_score(PlayerStatus,NewCost);
			   _ -> false
			end
    end.

%% 检查数据库并判断金钱是否充足，true为充足，false为不足
is_enough_money_chk_db(PlayerStatus, NewCost, Type) ->
	if NewCost < 0 ->false;
	   true->
		   case Type of
			   coin ->
				   [Coin, Bcoin] = db_agent:query_player_coin(PlayerStatus#player.id),
				   Coin + Bcoin >= NewCost;
			   coinonly ->
				   [Coin, _Bcoin] = db_agent:query_player_coin(PlayerStatus#player.id),
				   Coin >= NewCost;
			   cash ->
				   [_Gold,Cash] = db_agent:query_player_money(PlayerStatus#player.id),
					Cash >= NewCost;
			   gold ->
				   [Gold,_Cash] = db_agent:query_player_money(PlayerStatus#player.id),
				   Gold >= NewCost;
			   bcoin ->
				   [_Coin, Bcoin] = db_agent:query_player_coin(PlayerStatus#player.id),
				   Bcoin >= NewCost;			   
			   _ -> false
			end
    end.

%% 计算消费
get_cost(PlayerStatus, Cost, Type) ->
	NewCost = abs(Cost),
    case Type of
        coin -> 
			case PlayerStatus#player.bcoin < Cost of
                    false -> NewPlayerStatus = PlayerStatus#player{ bcoin = (PlayerStatus#player.bcoin - NewCost) };
                    true -> NewPlayerStatus = PlayerStatus#player{ bcoin = 0, coin = (PlayerStatus#player.bcoin + PlayerStatus#player.coin - NewCost) }
            end;
		coinonly ->
			NewPlayerStatus = PlayerStatus#player{coin = (PlayerStatus#player.coin - NewCost)};
        cash ->
			[_Gold,Cash] = db_agent:query_player_money(PlayerStatus#player.id),
			NewPlayerStatus = PlayerStatus#player{ cash = (Cash - NewCost) };
        gold ->
			[Gold,_Cash] = db_agent:query_player_money(PlayerStatus#player.id),
			NewPlayerStatus = PlayerStatus#player{ gold = (Gold - NewCost) };
        bcoin ->
			NewPlayerStatus = PlayerStatus#player{ bcoin = (PlayerStatus#player.bcoin - NewCost) };
		shop_score ->
			if PlayerStatus#player.other#player_other.shop_score > NewCost ->
				   ShopScore = PlayerStatus#player.other#player_other.shop_score - NewCost;
			   true ->
				   ShopScore = PlayerStatus#player.other#player_other.shop_score
			end,
			NewPlayerStatus = PlayerStatus#player{other = PlayerStatus#player.other#player_other{shop_score = ShopScore}}
    end,
    NewPlayerStatus.

%% 添加金钱
add_money(PlayerStatus,Sum,Type) ->
	NewSum = abs(Sum),
	case Type of
		coin -> 
			NewPlayerStatus = PlayerStatus#player{coin = (PlayerStatus#player.coin + NewSum)};
		coinonly -> 
			NewPlayerStatus = PlayerStatus#player{coin = (PlayerStatus#player.coin + NewSum)};
		cash -> 
			NewPlayerStatus = PlayerStatus#player{cash = (PlayerStatus#player.cash + NewSum)};
		gold ->
			NewPlayerStatus = PlayerStatus#player{gold = (PlayerStatus#player.gold + NewSum)};
		bcoin ->
			NewPlayerStatus = PlayerStatus#player{bcoin = (PlayerStatus#player.bcoin + NewSum)}
	end,
	%% 需添加日志
	NewPlayerStatus.
	
%% 取价格类型
get_price_type(Type) ->
    case Type of
        1 -> coin;      % 铜钱
        2 -> cash;    	% 礼金
        3 -> gold;      % 元宝
        4 -> bcoin;     % 绑定的铜钱
        _ -> coin       % 铜钱
    end.
%%等级换算成阶
level_to_step(Level) ->
	case Level > 0 of
		true when Level < 10 -> 1;
		true when Level < 20 -> 2;
		true when Level < 30 -> 3;
		true when Level < 40 -> 4;
		true when Level < 50 -> 5;
		true when Level < 60 -> 6;
		true when Level < 70 -> 7;
		true when Level < 80 -> 8;
		true when Level < 90 -> 9;
		true when Level =< 100 -> 10;
		false -> 1
	end.

%% 检查装备是否有属性加成
has_attribute(GoodsInfo) ->
    case is_record(GoodsInfo,goods) andalso GoodsInfo#goods.type =:= 10 of
        true when GoodsInfo#goods.stren > 0 -> true;
        true when GoodsInfo#goods.hole1_goods > 0 -> true;
		true when GoodsInfo#goods.hole2_goods > 0 -> true;
		true when GoodsInfo#goods.hole3_goods > 0 -> true;
        true when GoodsInfo#goods.color > 0 -> true;
        true when GoodsInfo#goods.suit_id > 0 -> true;
        _ -> false
    end.

%% 检查装备是否可穿
can_equip(PlayerStatus, GoodsTypeId, Cell ,SkipCheck) ->
    GoodsTypeInfo = get_goods_type(GoodsTypeId),
	if
		is_record(GoodsTypeInfo,ets_base_goods) ->
			%%装备对应cell
		    DefCell = get_equip_cell(PlayerStatus,GoodsTypeInfo#ets_base_goods.subtype),
		    NewCell = case (Cell =< 0 orelse Cell > 12) of
		                    true -> DefCell;
		                    false -> Cell
		              end,
		    case is_record(GoodsTypeInfo, ets_base_goods) of
		        false -> {false,0};
				%%戒指
		        true when (GoodsTypeInfo#ets_base_goods.subtype =:= 20 orelse GoodsTypeInfo#ets_base_goods.subtype =:= 23) %%戒指/新戒指
				  		andalso NewCell =/= 10 andalso NewCell =/= 11 ->
		            {false,6};%%6装备位置错误
		        true when GoodsTypeInfo#ets_base_goods.subtype =/= 20 andalso NewCell =/= DefCell ->
		            {false,6};
				%%饰品
				true when GoodsTypeInfo#ets_base_goods.subtype =:= 21 andalso NewCell =/= 8 andalso NewCell =/= 9 ->
		            {false,6};
		        true when GoodsTypeInfo#ets_base_goods.subtype =/= 21 andalso NewCell =/= DefCell ->
		            {false,6};
		        true when GoodsTypeInfo#ets_base_goods.level > PlayerStatus#player.lv ,SkipCheck ==false ->
		            {false,7};%%等级不符合
		        true when GoodsTypeInfo#ets_base_goods.career > 0 andalso GoodsTypeInfo#ets_base_goods.career =/= PlayerStatus#player.career ->
		            {false,8};%%职业不符合
				true when GoodsTypeInfo#ets_base_goods.sex > 0 andalso GoodsTypeInfo#ets_base_goods.sex =/= PlayerStatus#player.sex ->
		            {false,9};%%性别不符合
		        true ->
		            NewCell
		    end;
		true ->
			{false,0}
	end.

%% 取物品总数
get_goods_totalnum(GoodsList) ->
	F = fun(X,Sum) ->
				if
					is_record(X,goods) ->
						X#goods.num + Sum;
					true ->
						Sum
				end
		end,					
    lists:foldl(F, 0, GoodsList).

%% 取消费类型
get_consume_type(Type) ->
    case Type of
        pay -> 1;
        mend -> 2;
        %%quality_upgrade -> 3;
        %%quality_backout -> 4;
        strengthen -> 5;
        hole -> 6;
        compose -> 7;
        inlay -> 8;
        backout -> 9;
        wash -> 10;
        _ -> 0
    end.

deeploop(F, N, Data) ->
    case N > 0 of
        true ->
            [N1, Data1] = F(N, Data),
            deeploop(F, N1, Data1);
        false ->
            Data
    end.

%% @spec list_handle(F, Data, List) -> {ok, NewData} | Error
list_handle(F, Data, List) ->
    if length(List) > 0 ->
            [Item|L] = List,
            case catch(F(Item, Data)) of
                {ok, Data1} -> list_handle(F, Data1, L);
                Error -> Error
            end;
        true ->
            {ok, Data}
    end.

%%取装备没有鉴定属性的个数
count_noidentify_num(GoodsInfo) ->
	if
		is_record(GoodsInfo,goods) ->
			%%attribute_type = 1 装备的职业附加属性 
			AttributeList=get_goods_attribute_list(GoodsInfo#goods.player_id, GoodsInfo#goods.id, 1),
			F=fun(AttributeInfo,Sum)->
			  		if
				  		AttributeInfo#goods_attribute.status =:= 0 ->
					  		Sum+1;
				  		true ->
					  		Sum
			  		end
	  		end,
			lists:foldl(F,0,AttributeList);
		true ->
			0
	end.

%%取装备已镶嵌宝石的个数
count_inlay_num(GoodsInfo) ->
	if
		is_record(GoodsInfo,goods) ->
			H1 =
			if
				GoodsInfo#goods.hole1_goods > 0 -> 1;
				true -> 0
			end,
			H2 =
			if
				GoodsInfo#goods.hole2_goods > 0 -> 1;
				true -> 0
			end,
			H3 =
			if
				GoodsInfo#goods.hole3_goods > 0 -> 1;
				true -> 0
			end,
			H1+H2+H3;
		true ->
			0
	end.
%%获取打造装备位置约定信息
get_make_position_goods(PlayerId,Position) ->
	case Position of
		%% 1装备强化  约定信息 返回宝石 type=15
		1 when PlayerId > 0 ->
				Pattern = #goods{ player_id=PlayerId, type=15, _='_' },
            	get_ets_list(?ETS_GOODS_ONLINE, Pattern);
		_ ->
			[]
	end.

%%取装备强化附加抗性属性信息
get_goods_anti_attribute_info(PlayerId,GoodsId) ->
	Pattern = #goods_attribute{ player_id=PlayerId, gid=GoodsId, attribute_type=4,attribute_id =0, _='_'},
	get_ets_info(?ETS_GOODS_ATTRIBUTE, Pattern).


%%取时装强化附加气血上限属性信息
get_goods_hp_attribute_info(PlayerId,GoodsId) ->
	Pattern = #goods_attribute{ player_id=PlayerId, gid=GoodsId, attribute_type=2,attribute_id =1, _='_'},
	get_ets_info(?ETS_GOODS_ATTRIBUTE, Pattern).

%%取修炼属性值（下一等级值，最大值）
get_pracitse_attribute_value(GoodsInfo,AttributeId,Type) ->
	if
		GoodsInfo#goods.type =:= 10 andalso GoodsInfo#goods.subtype =< 13 ->
			GAL =  get_goods_attribute_list(GoodsInfo#goods.player_id,GoodsInfo#goods.id,1),
			if
				GAL =:= [] ->
					case mod_cache:get({goods_util,get_offline_goods_attribute_list,GoodsInfo#goods.id}) of
						[] ->
							GoodsAddAttributeList = get_offline_goods_attribute_list(GoodsInfo#goods.player_id,GoodsInfo#goods.id,1),
							mod_cache:set({goods_util,get_offline_goods_attribute_list,GoodsInfo#goods.id},GoodsAddAttributeList,3600),
							GoodsAddAttributeList;
						CacheData ->
							GoodsAddAttributeList = CacheData
					end;					
				true ->
					GoodsAddAttributeList =GAL
			end,
			if
				%%不存在的物品,用于显示双属性
				GoodsInfo#goods.id == 0 andalso GoodsInfo#goods.color == 1->
					Att_num = 1;
				GoodsInfo#goods.id == 0 ->
					Att_num = 2 ;
				true ->
					Att_num = length(GoodsAddAttributeList)
			end,
			MaxGrade = GoodsInfo#goods.step * 10 ,
			AttributeName = get_attribute_name_by_id(AttributeId),
			case Type of
				next ->
					Pattern = #ets_base_goods_practise{att_num = Att_num,subtype = GoodsInfo#goods.subtype,step = GoodsInfo#goods.step,color = GoodsInfo#goods.color, grade =GoodsInfo#goods.grade + 1, _='_' };
				max ->
					Pattern = #ets_base_goods_practise{att_num = Att_num,subtype = GoodsInfo#goods.subtype,step = GoodsInfo#goods.step,color = GoodsInfo#goods.color, grade =MaxGrade , _='_' }
			end,
    		GoodsPractiseRule = goods_util:get_ets_info(?ETS_BASE_GOODS_PRACTISE, Pattern),
			if
				is_record(GoodsPractiseRule,ets_base_goods_practise) ->
					Value =
					case AttributeName of 
						max_attack ->
							GoodsPractiseRule#ets_base_goods_practise.max_attack;
						min_attack ->
							GoodsPractiseRule#ets_base_goods_practise.min_attack;
						hit ->
							GoodsPractiseRule#ets_base_goods_practise.hit;
						wit ->
							GoodsPractiseRule#ets_base_goods_practise.wit;
						agile ->
							GoodsPractiseRule#ets_base_goods_practise.agile;
						forza ->
							GoodsPractiseRule#ets_base_goods_practise.forza;
						physique ->
							GoodsPractiseRule#ets_base_goods_practise.physique;
						_->
							0
					end,
					%%有攻击强化加成
					case lists:member(AttributeName, [max_attack,min_attack]) of
						true when GoodsInfo#goods.stren > 0 ->
							Att_type=goods_util:get_goods_attribute_id(GoodsInfo#goods.subtype),
    						Pattern2 = #ets_base_goods_strengthen{ strengthen=GoodsInfo#goods.stren ,type=Att_type, _='_' },
    						GoodsStrengthenRule = goods_util:get_ets_info(?ETS_BASE_GOODS_STRENGTHEN, Pattern2),
							tool:floor(Value * (1 + GoodsStrengthenRule#ets_base_goods_strengthen.value / 100));
						true ->
							Value;
						false ->
							Value
					end;
				true ->
					0
			end;
		true ->
			0
	end.

%%获取法宝修炼所需的最大灵力值
get_total_spirit(GoodsInfo) ->
	if
		%%只有法宝有最大灵力
		GoodsInfo#goods.type =:= 10 andalso GoodsInfo#goods.subtype =< 13 ->
			ToGrade =
			case (GoodsInfo#goods.step * 10 -1) >0 of
				true ->GoodsInfo#goods.step * 10 -1;
				false -> 1
			end,
			lists:sum(lists:map(fun data_equip:get_spirit/1,lists:seq(1, ToGrade)));%%ps 注意get_spirit是升下一级所需的灵力
		true ->
			0
	end.

%%查找物品
search_goods(Name)->
	BaseGoodsList = ets:tab2list(?ETS_BASE_GOODS),
	ShopGoodsList = ets:tab2list(?ETS_BASE_SHOP),
	F =fun(BaseGoodsInfo,GetList)  ->
		GoodsName = tool:to_list(BaseGoodsInfo#ets_base_goods.goods_name),
		F = string:str(GoodsName,Name),
		case F of
			0 ->
				GetList;				
			_-> 
				[BaseGoodsInfo#ets_base_goods.goods_id|GetList]
		end		
	end,
	SearchInBase = lists:foldl(F, [], BaseGoodsList),
	F2 = fun(ShopGoodsInfo,TargetList) ->
			T =lists:member(ShopGoodsInfo#ets_shop.goods_id, SearchInBase),
			if
				T =:= true andalso ShopGoodsInfo#ets_shop.shop_type =:= 1 ->
					[[ShopGoodsInfo#ets_shop.goods_id,ShopGoodsInfo#ets_shop.shop_subtype]|TargetList];
				true ->
					TargetList
			end
		 end,
	lists:foldl(F2,[],ShopGoodsList).


%%解析other_data 数据 "[a,b,c];[d,e,f]" => [[a,b,c],[d,e,f]]
%%other_data的格式有:
%%数值			value
%%礼包			[{24400,1,2},{23204,1,2}]
%%随机礼包		[{24000,1,2,80}] %%礼包格式+ 80 概率
%%价格			[shop,lq,5];[shop,th,6];[shop,jf,7]
%%buff			[buff,mp_lim,1.45,0.5]
%% type 类型 shop,buff,gift,value
parse_goods_other_data(Other_data) ->
	String = tool:to_list(Other_data),
	List = string:tokens(String, ";"),
	F = fun(S) ->
				util:string_to_term(S)
		end,
	lists:map(F, List).
parse_goods_other_data(Other_data,Type) ->
	if Other_data =:= <<>> ->
		   [];
	   true ->
		   Trans = parse_goods_other_data(Other_data),
		   get_type_other_data(Trans,Type)
	end.

get_type_other_data([],_Type) ->
	error;
get_type_other_data([One|Trans],Type)->
	case One of
		[shop|_] when Type == shop -> One;
		[buff|_] when Type == buff -> One;
		[farm|_] when Type == farm -> One;
		[acti|_] when Type == activity -> One;
		[busi|_] when Type == busi -> One;
		[{_chenge,Id}|_] when Type ==chenge ->Id;
		[{_expiretime,Id}|_] when Type ==expiretime ->Id;
		[{_Id,_N,_B}|_] when Type == gift ->One;
		[{_Id,_N,_B,_R}|_] when Type ==rgift -> One;
		V  when is_integer(V),Type == value -> One;
		_ -> get_type_other_data(Trans,Type)
	end.
		

%% 获取物品基础数据的other_data数据
get_goods_other_data(TypeId) ->
	TypeInfo = get_goods_type(TypeId),
	if
		is_record(TypeInfo,ets_base_goods) ->
			TypeInfo#ets_base_goods.other_data;
		true ->
			<<>>
	end.
%% 获取物品cd列表
get_goods_cd_list(PlayerId) ->
	Now =util:unixtime(),
	MS_cd = ets:fun2ms(fun(T) when T#ets_goods_cd.player_id == PlayerId andalso T#ets_goods_cd.expire_time > Now  -> 
			T 
		end),
	ets:select(?ETS_GOODS_CD, MS_cd).


%% 获取一件新手法宝
get_one_equip(PlayerId,Color) ->
	MS = ets:fun2ms(fun(T) when T#goods.player_id == PlayerId andalso T#goods.type == 10 andalso T#goods.subtype >= 9 andalso T#goods.subtype =< 13 andalso T#goods.color == Color ->
							T
					end),
	GoodsList = ets:select(?ETS_GOODS_ONLINE,MS),
	F = fun(GoodsInfo) ->
				if
					GoodsInfo#goods.goods_id div 1000 =:= 17 ->
						true;
					true ->
						false
				end
		end,
	FilterList = lists:filter(F, GoodsList),
	if
		is_list(FilterList) andalso length(FilterList) > 0 ->
			lists:nth(1, FilterList);
		true ->
			{}
	end.

%%获取身上的一件法宝
get_equip_fb(PlayerId) ->
	MS = ets:fun2ms(fun(T) when T#goods.player_id == PlayerId andalso T#goods.type == 10 andalso T#goods.subtype >= 9 andalso T#goods.subtype =< 13 andalso T#goods.location =:= 1 ->
							T
					end),
	GoodsList = ets:select(?ETS_GOODS_ONLINE,MS),
	case length(GoodsList) > 0 of
		true ->
			GoodsInfo = lists:nth(1, GoodsList),
			if
				is_record(GoodsInfo,goods)->
					GoodsInfo;
				true ->
					#goods{}
			end;
		false ->
			#goods{}
	end.

%% 获取身上对应位置的装备
get_cell_equip(PlayerId,Cell) ->
	MS = ets:fun2ms(fun(T) when T#goods.player_id == PlayerId andalso T#goods.location == 1 andalso T#goods.cell == Cell ->
							T
					end),
	GoodsList = ets:select(?ETS_GOODS_ONLINE, MS),
	case length(GoodsList) > 0 of
		true ->
			GoodsInfo = hd(GoodsList),
			if
				is_record(GoodsInfo,goods) ->
					GoodsInfo;
				true ->
					{}
			end;
		false ->
			{}
	end.

%% 获取坐骑加成速度
get_mount_info(Player) ->
	case Player#player.mount of
		0 ->
			[0,0,0];
		MountId ->
			MountInfo = lib_mount:get_mount(MountId),
			Speed = lib_mount:get_mount_speed(Player#player.id),
			if
				is_record(MountInfo,ets_mount) ->
					if %% 如果坐骑变身效果
						MountInfo#ets_mount.icon > 0 ->
							[MountInfo#ets_mount.icon,Speed,MountInfo#ets_mount.stren];
						true ->
							[MountInfo#ets_mount.goods_id,Speed,MountInfo#ets_mount.stren]
					end;
				true ->
					[0,0,0]
			end
	end.
%% 获取color对应的16进制值
get_color_hex_value(Color) ->
	case Color of
		0 ->"#FFFFFF";
		1 ->"#00FF33";
		2 ->"#313bdd";
		3 ->"#F8EF38";
		4 ->"#8800FF";
		_ ->"#FFFFFF"
	end.
%% 获取realm对应部落名称
get_realm_to_name(Id) ->
	case Id of
		1 ->"女娲";
		2 ->"神农";
		3 ->"伏羲";
		100 ->"新手";
		_ ->"未知"
	end.

%% 分析商店购买物品价格(这里可动态添加 同一物品不同商店价格保存在goods.other_data 格式[shop,lq,5];[shop,th,6];[shop,jf,7])	
parse_goods_price_for_shoptype(OtherData,[PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,Price0,PriceType0]) ->
	%%OtherData =util:string_to_term(PerData),
%% 	Is_Fst_Shop = mod_fst:is_fst_shop(ShopType),
	case OtherData of
		%%特惠区
		[shop,th,Price] when ShopType == 1 ,ShopSubtype == 6 ->
			%%%特惠区每天只可购买一次
			Goods_id = GoodsTypeInfo#ets_base_goods.goods_id,
			LogShop = log:get_shop_log(PlayerStatus#player.id,Goods_id,ShopType,ShopSubtype),
			LenLog = length(LogShop),
			if
				LenLog > 0 ->
					OneLog = lists:nth(1, LogShop),
					Time = lists:last(OneLog);
				true ->
					Time = 0
			end,
			Now = util:unixtime(),
			SameDay = util:is_same_date(Time,Now),
			if
				%%标记不 能购买99
				SameDay =:= true andalso 
						Goods_id /= 28602 andalso 
						Goods_id /=	24303 andalso 
						Goods_id /= 28186 andalso 
						Goods_id /= 28600 andalso 
						Goods_id /= 28603 andalso 
						Goods_id /= 31034 andalso
						Goods_id /= 28822
						->
					[PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,99,99];
				true ->
					C = Price * GoodsNum,
					PT = goods_util:get_price_type(GoodsTypeInfo#ets_base_goods.price_type),
					[PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,C,PT]
			end;
		%%礼券区
		[shop,lq,Price] when ShopType == 1,ShopSubtype == 5 ->
			C = Price * GoodsNum,
			PT = goods_util:get_price_type(2),
			[PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,C,PT];
		%%积分
		[shop,jf,Price] when ShopType == 10219 ->
			C = Price * GoodsNum,
			PT = score,
			[PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,C,PT];
		
		%%积分
		[shop,jf,Price] when ShopType == 1 andalso ShopSubtype == 7 ->
			C = Price * GoodsNum,
			PT = shop_score,
			[PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,C,PT];
		
		%%荣誉需求
		[shop,ry,Price] when ShopType == 10222 orelse ShopType == 20912->
			C = Price * GoodsNum,
			PT = honor,
			[PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,C,PT];
		%%功勋
		[shop,gx,Price] when ShopType == 20207 orelse ShopType == 21020 ->
			C = Price *  GoodsNum,
			PT = feats,
			[PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,C,PT];
		%%镇妖功勋
		[shop,tfgx,Price] when ShopType == 20800 ->
			C = Price * GoodsNum,
			PT = hor_td,
			[PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,C,PT];
		%%时装商店
		[shop,tcs,Price] when (ShopType =:= 1 andalso ShopSubtype =:= 9) ->
			C = Price * GoodsNum,
			PT = f_shop,
			[PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,C,PT];
		%%时装织女npc兑换
		[shop,tcs,Price] when (ShopType =:= 20901 andalso ShopSubtype =:= 1) ->
			C = Price * GoodsNum,
			PT = f_tcs,
			[PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,C,PT];
		%%活动面板上的购买
		[acti,PT,Price] when ShopType =:= 20802 ->
			C = Price * GoodsNum,
			[PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,C,PT];
		%%神秘商店
		[busi,Price,LimitBuy] when (ShopType=:=21048 orelse ShopType=:=21049 orelse ShopType=:=21050 orelse ShopType=:=21051) andalso ShopSubtype =:= 1 ->
			C = Price * GoodsNum,
			[PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,C,LimitBuy];
		_R ->
			[PlayerStatus, GoodsTypeInfo, GoodsNum, ShopType ,ShopSubtype,Price0,PriceType0]									
	end.

%%购买有附加物品
pay_goods_addition(Player,GoodsType,GoodsNum, MaxOverlap) ->
	Is_type1 = lists:member(GoodsType, [28025,28026,28027]),%%奇异果
	if
		Is_type1 ->
				if
					GoodsType == 28025 ->
						GiveGoods = 28028,
						handle_pay_goods_addition(Player#player.nickname,GiveGoods,2,GoodsNum,"赠送奖励","你购买初级奇异果，邮件增送初级秘境令", MaxOverlap);
					GoodsType == 28026 ->
						GiveGoods = 28029,
						handle_pay_goods_addition(Player#player.nickname,GiveGoods,2,GoodsNum,"赠送奖励","你购买中级奇异果，邮件增送中级秘境令", MaxOverlap);
					GoodsType == 28027 ->
						GiveGoods = 28030,
						handle_pay_goods_addition(Player#player.nickname,GiveGoods,2,GoodsNum,"赠送奖励","你购买高级奇异果，邮件增送高级秘境令", MaxOverlap);
					true ->
						0
				end;
		true ->
			skip
	end.
handle_pay_goods_addition(PlayerName, GiveGoods, 2, GoodsNum, Title, Cont, MaxOverlap) ->
	case GoodsNum =< 0 of
		false ->
			{NewNum, ResNum} =
				if
					MaxOverlap > 1 andalso MaxOverlap > GoodsNum ->
						{GoodsNum, 0};
					MaxOverlap > 1 andalso MaxOverlap =< GoodsNum ->
						{MaxOverlap, GoodsNum - MaxOverlap};
					true ->
						{1, 0}
				end,
			Content = io_lib:format("~s~p~s", [Cont,NewNum, "个"]),
			lib_goods:add_new_goods_by_mail(PlayerName, GiveGoods, 2, NewNum, Title, Content),
			handle_pay_goods_addition(PlayerName, GiveGoods, 2, ResNum, Title, Cont, MaxOverlap);
		true ->
			skip
	end.

%%查询时装附加属性
get_equip_attribute(GoodsInfo,Type) ->
	case Type == 6 of
		true ->
			AttributeList = get_goods_attribute_list(GoodsInfo#goods.player_id, GoodsInfo#goods.id, 6);
		false ->
			AttributeList = get_goods_attribute_list(GoodsInfo#goods.player_id, GoodsInfo#goods.id, 7)
	end,
	F = fun(AttributeInfo) ->
				if AttributeInfo#goods_attribute.crit > 0 ->%%暴击
					   {crit,AttributeInfo#goods_attribute.crit};
				   AttributeInfo#goods_attribute.dodge > 0 ->%%躲避
					   {dodge,AttributeInfo#goods_attribute.dodge};
				   AttributeInfo#goods_attribute.hit > 0 ->%%命中
					   {hit,AttributeInfo#goods_attribute.hit};
				   AttributeInfo#goods_attribute.mp > 0 ->%%法力
					   {mp,AttributeInfo#goods_attribute.mp};
				   AttributeInfo#goods_attribute.max_attack > 0 ->%%最大攻击
					   {max_attack,AttributeInfo#goods_attribute.max_attack};
				   AttributeInfo#goods_attribute.min_attack > 0 ->%%最小攻击
					   {min_attack,AttributeInfo#goods_attribute.min_attack};
				   AttributeInfo#goods_attribute.forza > 0 ->%%力量
					   {forza,AttributeInfo#goods_attribute.forza};
				   AttributeInfo#goods_attribute.agile > 0 ->%%敏捷
					   {agile,AttributeInfo#goods_attribute.agile};
				   AttributeInfo#goods_attribute.wit > 0 ->%%智力
					   {wit,AttributeInfo#goods_attribute.wit};
				   AttributeInfo#goods_attribute.physique > 0 ->%%体质
					   {physique,AttributeInfo#goods_attribute.physique};
				   AttributeInfo#goods_attribute.att > 0 ->%%攻击
					   {att,AttributeInfo#goods_attribute.att};
				   AttributeInfo#goods_attribute.anti_wind > 0 ->%%风抗
					   {anti_wind,AttributeInfo#goods_attribute.anti_wind};
				   AttributeInfo#goods_attribute.anti_thunder > 0 ->%%雷抗
					   {anti_thunder,AttributeInfo#goods_attribute.anti_thunder};
				   AttributeInfo#goods_attribute.anti_water > 0 ->%%水抗
					   {anti_water,AttributeInfo#goods_attribute.anti_water};
				   AttributeInfo#goods_attribute.anti_fire > 0 ->%%火抗
					   {anti_fire,AttributeInfo#goods_attribute.anti_fire};
				   AttributeInfo#goods_attribute.anti_soil > 0 ->%%土抗
					   {anti_soil,AttributeInfo#goods_attribute.anti_soil};
				   AttributeInfo#goods_attribute.hp > 0 ->%%气血
					   {hp,AttributeInfo#goods_attribute.hp};
				   true ->
					  {}
				end
		end,
	RestList1 = [F(AttributeInfo)||AttributeInfo <- AttributeList],
	RestList2 = lists:filter(fun(T)-> T =/= {} end, RestList1),
	lists:flatten(RestList2).

%%时装未替换的属性
get_fashion_unreplace(GoodsInfo) ->
	db_agent:get_goods_fashion_log(GoodsInfo#goods.player_id, GoodsInfo#goods.id). 

%%装备附魔未替换的属性
get_equip_unreplace(GoodsInfo) ->
	db_agent:get_equip_unreplace(GoodsInfo#goods.player_id, GoodsInfo#goods.id). 
	
%%时装随机洗炼属性
get_fashion_random(Career,GoodsTypeId, StoneGoodsTypeId) ->
	[_Id,_Goods_id,Max_crit,Min_crit,Max_dodge,Min_dodge,Max_hit,Min_hit,Max_mp,Min_mp,Max_physique,Min_physique,Max_attack,Min_attack,
	Max_anti_all,Min_anti_all,Max_forza,Min_forza,Max_wit,Min_wit,Max_agile,Min_agile,Max_anti_wind,Min_anti_wind,Max_anti_thunder,Min_anti_thunder,
	Max_anti_water,Min_anti_water,Max_anti_fire,Min_anti_fire,Max_anti_soil,Min_anti_soil,Max_att_per,Min_att_per,Max_mp_per,Min_mp_per] = db_agent:get_fashion_random(GoodsTypeId),
	RandomProList1 = [{crit,[Min_crit,Max_crit]},{dodge,[Min_dodge,Max_dodge]},{hit,[Min_hit,Max_hit]},{mp,[Min_mp,Max_mp]},{physique,[Min_physique,Max_physique]},{max_attack,[Min_attack,Max_attack]},
					     {anti_all,[Min_anti_all,Max_anti_all]},{forza,[Min_forza,Max_forza]},{wit,[Min_wit,Max_wit]},{agile,[Min_agile,Max_agile]},{anti_wind,[Min_anti_wind,Max_anti_wind]},{anti_thunder,[Min_anti_thunder,Max_anti_thunder]},
					    {anti_water,[Min_anti_water,Max_anti_water]},{anti_fire,[Min_anti_fire,Max_anti_fire]},{anti_soil,[Min_anti_soil,Max_anti_soil]},{att_per,[Min_att_per,Max_att_per]},{hp_per,[Min_mp_per,Max_mp_per]}],
	PropertiesRatioList1 =
		case Career of
			1 -> %%玄武
				[{crit,8},{dodge,8},{hit,9},{mp,9},{physique,6},{max_attack,4},{anti_all,6},{forza,8},{anti_wind,8},{anti_thunder,8},
					    {anti_water,8},{anti_fire,8},{anti_soil,8},{att_per,1},{hp_per,1}];
			2 ->%%白虎-
				[{crit,8},{dodge,8},{hit,9},{mp,9},{physique,6},{max_attack,4},{anti_all,6},{agile,8},{anti_wind,8},{anti_thunder,8},
					    {anti_water,8},{anti_fire,8},{anti_soil,8},{att_per,1},{hp_per,1}];
			3 ->%%青龙
				[{crit,8},{dodge,8},{hit,9},{mp,9},{physique,6},{max_attack,4},{anti_all,6},{agile,8},{anti_wind,8},{anti_thunder,8},
					    {anti_water,8},{anti_fire,8},{anti_soil,8},{att_per,1},{hp_per,1}];
			4 ->%%朱雀
				[{crit,8},{dodge,8},{hit,9},{mp,9},{physique,6},{max_attack,4},{anti_all,6},{wit,8},{anti_wind,8},{anti_thunder,8},
					    {anti_water,8},{anti_fire,8},{anti_soil,8},{att_per,1},{hp_per,1}];
			_ ->%%5麒麟
				[{crit,8},{dodge,8},{hit,9},{mp,9},{physique,6},{max_attack,4},{anti_all,6},{forza,8},{anti_wind,8},{anti_thunder,8},
					    {anti_water,8},{anti_fire,8},{anti_soil,8},{att_per,1},{hp_per,1}]
		end,
		
	
%%除去属性为0的属性
%%RandomProList3 = [{PropName,[Min_Value,Max_Value]} || {PropName,[Min_Value,Max_Value]} <- RandomProList2,Min_Value > 0,Max_Value > 0],
    RandomSize = 
	case StoneGoodsTypeId == 21801 of
		%%金色洗炼石出三种属性
		true -> 
			3;
		%%蓝色洗炼石出二种属性
		false ->
			2
	end,
	PropertiesList = util:get_random_list_probability(PropertiesRatioList1,RandomSize),
	F = fun(Properties) ->
				{Prop,[MinValue,MaxValue]} = lists:keyfind(Properties, 1, RandomProList1),
				PropValue1 =
					if
						MinValue == 0 -> 0;
						MaxValue == 0 -> 0;
						MinValue > MaxValue -> 0;
						true ->util:rand(MinValue, MaxValue)
					end,
				{Prop,PropValue1}
		end,
	PropertiesList1 = [F(Properties) || Properties <- PropertiesList],
	PropertiesList1.


%%装备附魔或回光
get_magic_random(GoodsLevel,GoodsSubtype,GoodsCareer,MagicTypeId) ->
	data_magic:get_magic_prop(GoodsLevel,GoodsSubtype,GoodsCareer,MagicTypeId).

%%查询上一次的附魔属性
get_last_magic_prop(Player_Id, Gid) ->
	db_agent:get_last_magic_prop(Player_Id, Gid).

%%生成物品随机属性(附魔)
general_magic_prop(GoodsInfo,PropList) ->
	F = fun(Prop,Value) ->
							   %%属性显示的是数字还是百分比(0数字,1百分比)
							   ValueType =
								   if Prop == att_per orelse Prop == hp_per -> 1;
									  true -> 0
								   end,
							   Prop1 =
								   if Prop == att_per  -> max_attack;
									  Prop == hp_per  -> hp;
									  true -> Prop
								   end,
							   Attribute_id = 
								   if Prop1 =/= anti_all ->	goods_util:get_attribute_id_by_name(Prop1);
									  true -> 	0 %%表示全抗
								   end,
							   Goods_attribute1 = 
								   case Prop1 of
									   crit ->   #goods_attribute{crit = Value};
									   dodge -> #goods_attribute{dodge = Value};
									   hit -> #goods_attribute{hit = Value};
									   mp -> #goods_attribute{mp = Value};
									   def -> #goods_attribute{def = Value};
									   max_attack -> #goods_attribute{max_attack = Value};
									   min_attack -> #goods_attribute{min_attack =  Value};
									   forza -> #goods_attribute{forza = Value};
									   agile -> #goods_attribute{agile =  Value};
									   wit -> #goods_attribute{wit = Value};
									   physique -> #goods_attribute{physique = Value};
									   anti_wind -> #goods_attribute{anti_wind = Value};
									   anti_thunder -> #goods_attribute{anti_thunder = Value};
									   anti_water -> #goods_attribute{anti_water =  Value};
									   anti_fire -> #goods_attribute{anti_fire =  Value};
									   anti_soil -> #goods_attribute{anti_soil =  Value};
									   hp -> #goods_attribute{hp = Value};
									   _ ->  #goods_attribute{}
								   end,
							   Goods_id = GoodsInfo#goods.goods_id,
							   Effect = 
								   case Attribute_id =/= 0 of
									   true ->
										   [Goods_id,Goods_attribute1#goods_attribute.hp, Goods_attribute1#goods_attribute.mp, Goods_attribute1#goods_attribute.max_attack,Goods_attribute1#goods_attribute.min_attack, Goods_attribute1#goods_attribute.def,
											Goods_attribute1#goods_attribute.hit, Goods_attribute1#goods_attribute.dodge, Goods_attribute1#goods_attribute.crit,Goods_attribute1#goods_attribute.physique, Goods_attribute1#goods_attribute.anti_wind,Goods_attribute1#goods_attribute.anti_fire,
											Goods_attribute1#goods_attribute.anti_water,Goods_attribute1#goods_attribute.anti_thunder,Goods_attribute1#goods_attribute.anti_soil,Goods_attribute1#goods_attribute.forza,Goods_attribute1#goods_attribute.agile,Goods_attribute1#goods_attribute.wit];
									   false -> %%全抗 
										   [Goods_id,Goods_attribute1#goods_attribute.hp, Goods_attribute1#goods_attribute.mp, Goods_attribute1#goods_attribute.max_attack,Goods_attribute1#goods_attribute.min_attack, Goods_attribute1#goods_attribute.def,
											Goods_attribute1#goods_attribute.hit, Goods_attribute1#goods_attribute.dodge, Goods_attribute1#goods_attribute.crit,Goods_attribute1#goods_attribute.physique, Value,Value,
											Value,Value,Value,Goods_attribute1#goods_attribute.forza,Goods_attribute1#goods_attribute.agile,Goods_attribute1#goods_attribute.wit]
								   end,
							   lib_goods:add_goods_attribute(GoodsInfo,7,Attribute_id,Effect,ValueType)
					   end,
				   [F(Prop,Value)|| {Prop,Value} <- PropList].
				   
get_buff_compatibility(Egoods_id, Edata) ->
	Data = util:string_to_term(tool:to_list(Edata)),
	case Data of
		[buff,hp_lim,Value]->
			LastTime = get_goods_buff_time(Egoods_id),
			{23400, {Value, LastTime}};
		[buff,mp_lim,Value] ->
			LastTime = get_goods_buff_time(Egoods_id),
			{23406, {Value, LastTime}};
		[buff,def_mult,Value] ->
			LastTime = get_goods_buff_time(Egoods_id),
			{23403, {Value, LastTime}};					
		[buff,exp_mult,Value] ->
			LastTime = get_goods_buff_time(Egoods_id),
			{23203, {Value, LastTime}};
		[buff,spi_mult,Value] ->
			LastTime = get_goods_buff_time(Egoods_id),
			{23303, {Value, LastTime}};
		[buff,pet_mult,Value] ->
			LastTime = get_goods_buff_time(Egoods_id),
			{24102, {Value, LastTime}};
		[buff,peach_mult,Value] ->
			LastTime = get_goods_buff_time(Egoods_id),
			{23409, {Value, LastTime}};
		_ ->
%%			?DEBUG("___________load login load buff goods_id = ~p, Data = ~p_________________",[Egoods_id,Data]),
			{Egoods_id, Data}
	end.

%%修改兼容的数据
change_buffid_compatibility(PlayerId, GoodsTypeId, BuffGid) ->
	case GoodsTypeId =:= BuffGid of
		false ->
			db_agent:change_buffid_compatibility(PlayerId, GoodsTypeId, BuffGid);
		true ->
			skip
	end.

get_goods_buff_time(GoodsId) ->
	case GoodsId of
		23400 ->
			0.5;
		23401 ->
			0.5;
		23402 ->
			0.5;
		23406 ->
			0.5;
		23407 ->
			0.5;
		23408 ->
			0.5;
		23203 ->
			1;
		23204 ->
			24;
		23205 ->
			1;
		23303 ->
			1;
		23304 ->
			24;
		23305 ->
			1;
		23403 ->
			0.5;
		23404 ->
			0.5;
		23405 ->
			0.5;
		24102 ->
			12;
		24103 ->
			24;
		23409 ->
			5;
		23410 ->
			5;
		23411 ->
			5;
		_ ->
			0
	end.

%%Type为add(+)或sub(-)
%% 将[{key,value},{key1,value1}]变成 [{key,value,add},{key1,value1,add}]或 [{key,value,sub},{key1,value1,sub}]
prop_value_add(PropValueList,Type) ->
	[{Key,Value,Type} || {Key,Value} <- PropValueList].

is_enough_money_to_pay_goods(PlayerStatus,GoodsId,Num)->
	GoodsTypeInfo = goods_util:get_goods_type(GoodsId),
	Cost = GoodsTypeInfo#ets_base_goods.price * Num ,
	PriceType = goods_util:get_price_type(GoodsTypeInfo#ets_base_goods.price_type),
	{goods_util:is_enough_money(PlayerStatus, Cost, PriceType),Cost}.

%%转化物品的附加属性值，[{attribute_id,value,status}]
get_attribute_id_value(One,AccIn) ->
	Elem = 
	if
		is_record(One, goods_attribute) =:= true ->
			One;
		true ->
			list_to_tuple([goods_attribute] ++ One)
	end,
	AttType = Elem#goods_attribute.attribute_id,
	case AttType of
		15 -> %%力量
			#goods_attribute{status = Status,forza = Value}= Elem,
			[{AttType, Value, Status}|AccIn];
		16 -> %%敏捷
			#goods_attribute{status = Status,agile = Value}= Elem,
			[{AttType, Value, Status}|AccIn];
		17 -> %%智力
			#goods_attribute{status = Status,wit = Value}= Elem,
			[{AttType, Value, Status}|AccIn];
		9  -> %%体质
			#goods_attribute{status = Status,physique = Value}= Elem,
			[{AttType, Value, Status}|AccIn];
		7  -> %%暴击
			#goods_attribute{status = Status,crit = Value}= Elem,
			[{AttType, Value, Status}|AccIn];
		6  -> %%闪躲
			#goods_attribute{status = Status,dodge = Value}= Elem,
			[{AttType, Value, Status}|AccIn];
		10 -> %%风抗
			#goods_attribute{status = Status,anti_wind = Value}= Elem,
			[{AttType, Value, Status}|AccIn];
		13 -> %%雷抗
			#goods_attribute{status = Status,anti_thunder = Value}= Elem,
			[{AttType, Value, Status}|AccIn];
		12 -> %%水抗
			#goods_attribute{status = Status,anti_water = Value}= Elem,
			[{AttType, Value, Status}|AccIn];
		11 -> %%火抗
			#goods_attribute{status = Status,anti_fire = Value}= Elem,
			[{AttType, Value, Status}|AccIn];
		14 -> %%土抗
			#goods_attribute{status = Status,anti_soil = Value}= Elem,
			[{AttType, Value, Status}|AccIn];
		1  -> %%气血
			#goods_attribute{status = Status,hp = Value}= Elem,
			[{AttType, Value, Status}|AccIn];
		2  -> %%法力
			#goods_attribute{status = Status,mp = Value}= Elem,
			[{AttType, Value, Status}|AccIn];
		_ ->
			AccIn
	end.

get_goods_info_fields(Gid,FieldsList) ->
	GoodsInfo = goods_util:get_goods(Gid),
	if is_record(GoodsInfo,goods) == false ->
		   [];
	   true ->
		   lists:map(fun(T) ->	
			case T of
				id -> GoodsInfo#goods.id;
				player_id -> GoodsInfo#goods.player_id;
				goods_id -> GoodsInfo#goods.goods_id; 
				type -> GoodsInfo#goods.type;
				subtype -> GoodsInfo#goods.subtype;
				equip_type -> GoodsInfo#goods.equip_type;
				price_type -> GoodsInfo#goods.price_type;
      			price -> GoodsInfo#goods.price;
		      	sell_price -> GoodsInfo#goods.sell_price;
		        bind -> GoodsInfo#goods.bind;	
		        career -> GoodsInfo#goods.career;
		        trade -> GoodsInfo#goods.trade;
		        sell -> GoodsInfo#goods.sell;
		        isdrop -> GoodsInfo#goods.isdrop;
		        level -> GoodsInfo#goods.level;
		        spirit -> GoodsInfo#goods.spirit;
		        hp -> GoodsInfo#goods.hp;
		        mp -> GoodsInfo#goods.mp;
		        forza -> GoodsInfo#goods.forza;
		        physique -> GoodsInfo#goods.physique;	
		        agile -> GoodsInfo#goods.agile;
		        wit -> GoodsInfo#goods.wit;
		        max_attack -> GoodsInfo#goods.max_attack;
		        min_attack -> GoodsInfo#goods.min_attack;
		        def -> GoodsInfo#goods.def;
		        hit -> GoodsInfo#goods.hit;
		        dodge -> GoodsInfo#goods.dodge;
		        crit -> GoodsInfo#goods.crit;
		        ten -> GoodsInfo#goods.ten;
		        anti_wind -> GoodsInfo#goods.anti_wind;
		        anti_fire -> GoodsInfo#goods.anti_fire;
		        anti_water -> GoodsInfo#goods.anti_water;
		        anti_thunder -> GoodsInfo#goods.anti_thunder;	
		        anti_soil -> GoodsInfo#goods.anti_soil;
		        anti_rift -> GoodsInfo#goods.anti_rift;	
		        speed -> GoodsInfo#goods.speed;
		        attrition -> GoodsInfo#goods.attrition;
		        use_num -> GoodsInfo#goods.use_num;	
		        suit_id -> GoodsInfo#goods.suit_id;
		        stren -> GoodsInfo#goods.stren;
		        stren_fail -> GoodsInfo#goods.stren_fail;
		        hole -> GoodsInfo#goods.hole;
		        hole1_goods -> GoodsInfo#goods.hole1_goods;
		        hole2_goods -> GoodsInfo#goods.hole2_goods;
		        hole3_goods -> GoodsInfo#goods.hole3_goods;
		        location -> GoodsInfo#goods.location;	
		        cell -> GoodsInfo#goods.cell;
		        num -> GoodsInfo#goods.num;
		        grade -> GoodsInfo#goods.grade;	
		        step -> GoodsInfo#goods.step;
		        color -> GoodsInfo#goods.color;
		        other_data -> GoodsInfo#goods.other_data;
		        expire_time -> GoodsInfo#goods.expire_time;
		        score -> GoodsInfo#goods.score;  	
		        bless_level -> GoodsInfo#goods.bless_level;
		        bless_skill -> GoodsInfo#goods.bless_skill;
		        icon -> GoodsInfo#goods.icon;
		        ct -> GoodsInfo#goods.ct;    
				_ -> undefined	
			end	
		end, FieldsList)	
	end.
	
	
	
