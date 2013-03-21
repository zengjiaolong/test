%% Author: xianrongMai
%% Created: 2011-11-14
%% Description: 后台邮件发物品特殊处理
-module(lib_mail_goods).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
%%
%% Exported Functions
%%
-export([
		 test/6,
%% 		 sent_mail_goods/7,%%仅此方法对外调用
		 stren_mail_goods/9
		]).

%%
%% API Functions
%%
test(GoodsTypeId, Coin, Cash, Bind, Stren, Trade) ->
	NameList = [tool:to_list("宇文千佑")],
	Title = "test",
	Content = "test",
	stren_mail_goods(NameList, Title, Content, GoodsTypeId, Coin, Cash, Bind, Stren, Trade).
	
%% @spec lib_mail_goods:sent_mail_goods(RoleIdList, GoodsList, Title, Content, Coin, Cash, Bind) -> ok
%% RoleIdList:玩家Id [Id1,Id2]
%% GoodsList：物品列表[{GoodsTypeId, Stren}],其中stren:1~~10
%% Title：信件标题
%% Content：信件内容
%% Coin：铜币
%% Cash：元宝
%% Bind：是否绑定:0不绑定，2绑定
%% sent_mail_goods(RoleIdList, GoodsList, Title, Content, Coin, Cash, Bind) ->
%% 	lists:foreach(fun(Elem) ->
%% 						  Name =  lib_player:get_role_name_by_id(Elem),
%% 						  ENameList = [tool:to_list(Name)],
%% 						  lists:foreach(fun(GElem) ->
%% 												{GoodsTypeId, Stren, AttId} = GElem,
%% 												stren_mail_goods(ENameList, Title, Content, GoodsTypeId, Coin, Cash, Bind, Stren)
%% 										end, GoodsList)
%% 				  end, RoleIdList),
%% 	ok.
	
%% Param:	NameList: [玩家名字]
%% 			Title: 信件标题
%% 			Content: 信件内容
%% 			GoodsTypeId: 物品类型Id
%% 			Coin: 铜币
%% 			Cash: 元宝
%% 			Bind: 物品是否绑定0：不绑定，1：绑定
%% 			Stren: 强化等级1~~10
%% 			AttId: 双属，2；单属，1
%%			SendTrade:	0为可交易，1为不可交易
stren_mail_goods(NameList, Title, Content, GoodsTypeId, Coin, Cash, Bind, Stren, SendTrade) ->
%%	?DEBUG("NameList:~p, Title:~p, Content:~p, GoodsTypeId:~p, Coin:~p, Cash:~p, Bind:~p, Stren:~p", [NameList, Title, Content, GoodsTypeId, Coin, Cash, Bind, Stren]),
	{Type, NewId} = 
		if
			GoodsTypeId =:= 0 ->
				{goods_id, GoodsTypeId};
		Stren =< 0 orelse Stren > 10 ->%%出错的
			{goods_id, GoodsTypeId};
		GoodsTypeId =:= 16009 ->%%特殊的飞行画卷
			{goods_id, GoodsTypeId};
		true ->
			 GoodsTypeInfo0 = goods_util:get_goods_type(GoodsTypeId),
			  case is_record(GoodsTypeInfo0, ets_base_goods) of
				  %% 物品不存在
				  false ->
					  {fail,GoodsTypeId};
				  true ->
					  %%设定绑定情况
					  GBind = 
						  case Bind of
							  0 ->
								  0;
							  _ ->
								  2
						  end,
					  Trade = 
						  case SendTrade of
							  0 ->
								  0;
							  _ ->
								  1
						  end,
					  GoodsTypeInfo = GoodsTypeInfo0#ets_base_goods{bind = GBind},
					  GoodsInfo0 = goods_util:get_new_goods(GoodsTypeInfo),
					  GoodsInfo1 = GoodsInfo0#goods{player_id = 0, location = 4, cell = 0, num = 1, stren = Stren, trade = Trade},
%% 					  %%判断单双属性并生成属性
%% 					  Pattern = #ets_base_goods_add_attribute{ goods_id=GoodsTypeInfo#ets_base_goods.goods_id,color=GoodsTypeInfo#ets_base_goods.color,
%% 															   attribute_type= AttId , _='_' },
%% 					  AttributeList = goods_util:get_ets_list(?ETS_BASE_GOODS_ADD_ATTRIBUTE, Pattern),
%% 					  F = fun(BaseAttribute) ->
%% 								  {BaseAttribute#ets_base_goods_add_attribute.attribute_id,0}
%% 						  end,
%% 					  AttList = lists:map(F, AttributeList),
%% 					  %%添加物品
%% 					  GoodsInfo = lib_goods:add_goods(GoodsInfo1,AttList),
					  %%添加物品
					  GoodsInfo = lib_goods:add_goods(GoodsInfo1),
					  %%强化+Stren
					  
					  AttType = goods_util:get_goods_attribute_id(GoodsInfo#goods.subtype),
					  Pattern2 = #ets_base_goods_strengthen{strengthen=GoodsInfo#goods.stren,type=AttType, _='_' },
					  GoodsStrengthenRule = goods_util:get_ets_info(?ETS_BASE_GOODS_STRENGTHEN, Pattern2),
					  %%防具抗性附加属性
					  Step=goods_util:level_to_step(GoodsInfo#goods.level),
					  Pattern3 = #ets_base_goods_strengthen_anti{subtype=GoodsInfo#goods.subtype, 
																 step=Step, stren=GoodsInfo#goods.stren, _='_' },
					  GoodsStrengthenAntiRule = goods_util:get_ets_info(?ETS_BASE_GOODS_STRENGTHEN_ANTI,Pattern3),
					  if
						  %% 强化规则不存在,不能匹配规则说明物品错误
						  is_record(GoodsStrengthenRule, ets_base_goods_strengthen) =:= false ->
							  skip;
						  true ->
							  strengthen_ok(GoodsInfo,GoodsStrengthenRule,GoodsStrengthenAntiRule)
					  end,
					  
					  
					  
%% 					  stren_mail_goods(1, Stren, GoodsInfo),
					  {gid, GoodsInfo#goods.id}
					  %%	  
			 end
	end,
	case Type of
		goods_id ->%%纯发没有生成的物品
			MailGoodsId = 0,
			MailGoodsTypeId = NewId,
			GoodsBind = 
				case Bind of
					0 ->%%不绑定
						1;
					_ ->
						0
				end,
			mod_mail:send_sys_mail(NameList, Title, Content, MailGoodsId, MailGoodsTypeId, 1, Coin, Cash, GoodsBind);
%% 			mod_mail:send_sys_mail(NameList, Title, Content, MailGoodsId, MailGoodsTypeId, 1, Coin, Cash);
		gid ->
			MailGoodsId = NewId,
%% 			MailGoodsTypeId = 0,
			mod_mail:send_sys_mail(NameList, Title, Content, MailGoodsId, GoodsTypeId, 1, Coin, Cash),
			ets:delete(?ETS_GOODS_ATTRIBUTE, MailGoodsId),
			ets:delete(?ETS_GOODS_ONLINE, MailGoodsId);
		_ ->
			skip
	end.
	


%%
%% Local Functions
%%
%%强化成功处理
%%强化成功处理
strengthen_ok(GoodsInfo, GoodsStrengthenRule, GoodsStrengthenAntiRule) ->
    NewStrengthen = GoodsInfo#goods.stren,
    NewGoodsInfo = GoodsInfo#goods{stren=NewStrengthen},
	ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
	%%先处理额外属性
	%% 强化+7 加成 
	if
		NewStrengthen >= 7 andalso NewGoodsInfo#goods.subtype =/= 22 andalso NewGoodsInfo#goods.subtype =/= 24 ->
			spawn(fun()-> lib_make:mod_strengthen_extra(NewGoodsInfo,GoodsStrengthenRule)end);
		true ->
			skip
	end,
	%% 强化+8 攻击加成
	if
		NewStrengthen >= 8 andalso NewGoodsInfo#goods.subtype < 14 andalso NewGoodsInfo#goods.subtype =/= 24->
			spawn(fun()-> lib_make:mod_strengthen_attack_extra(NewGoodsInfo)end);
		true ->
			skip
	end,
	%%如果是防具则增加抗性
	if
		NewGoodsInfo#goods.subtype > 13 andalso NewGoodsInfo#goods.subtype /= 23  andalso NewGoodsInfo#goods.subtype =/= 24->
			spawn(fun()-> lib_make:mod_strengthen_anti(NewGoodsInfo,GoodsStrengthenAntiRule)end);
		true ->
			skip
	end,
    spawn(fun()->db_agent:mod_strengthen(NewStrengthen, GoodsInfo#goods.stren_fail, GoodsInfo#goods.bind, 
										 GoodsInfo#goods.trade, GoodsInfo#goods.expire_time, GoodsInfo#goods.id)end),
	%%如果是新戒指
	if
		NewGoodsInfo#goods.subtype == 23 ->
			spawn(fun()-> lib_make:mod_strengthen_ring_attribute(NewGoodsInfo)end);
		true ->
			skip
	end,
	%%新时装处理强化抗性和气血上限百分比
	if
		NewGoodsInfo#goods.subtype == 24 ->
			spawn(fun()-> lib_make:mod_strengthen_fashion_anti_hp(NewGoodsInfo)end);
		true ->
			skip
	end.
%% 	?DEBUG("11111stren:~p", [GoodsInfo#goods.stren]),
%%     NewGoodsInfo.

%% stren_mail_goods(Num, Stren, _GoodsInfo) when Num > Stren ->
%% 	skip;
%% stren_mail_goods(Num, Stren, GoodsInfo) ->
%% 	AttType = goods_util:get_goods_attribute_id(GoodsInfo#goods.subtype),
%% 	Pattern2 = #ets_base_goods_strengthen{strengthen=GoodsInfo#goods.stren  + 1,type=AttType, _='_' },
%% 	GoodsStrengthenRule = goods_util:get_ets_info(?ETS_BASE_GOODS_STRENGTHEN, Pattern2),
%% 	%%防具抗性附加属性
%% 	Step=goods_util:level_to_step(GoodsInfo#goods.level),
%% 	Pattern3 = #ets_base_goods_strengthen_anti{subtype=GoodsInfo#goods.subtype, step=Step, stren=GoodsInfo#goods.stren + 1, _='_' },
%% 	GoodsStrengthenAntiRule = goods_util:get_ets_info(?ETS_BASE_GOODS_STRENGTHEN_ANTI,Pattern3),
%% 	NewGoodsInfo = 
%% 		if
%% 			%% 强化规则不存在,不能匹配规则说明物品错误
%% 			is_record(GoodsStrengthenRule, ets_base_goods_strengthen) =:= false ->
%% 				GoodsInfo;
%% 			true ->
%% 				strengthen_ok(GoodsInfo,GoodsStrengthenRule,GoodsStrengthenAntiRule)
%% 		end,
%% 	stren_mail_goods(Num+1, Stren, NewGoodsInfo).

