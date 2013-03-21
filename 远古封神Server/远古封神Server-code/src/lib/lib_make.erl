%%%--------------------------------------
%%% @Module  : lib_goods
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description : 物品信息
%%%--------------------------------------
-module(lib_make).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-export( 
    [
        %%quality_upgrade/5,
        %%quality_backout/4,
        strengthen/17,
        hole/6,
        compose/9,
        inlay/11,
		idecompose/6,
		icompose/4,
        backout/11,
		identify/6,
		full_practise/4,
		practise/5,
		auto_practise/1,
		merge/4,
		merge_preview/3,
		suit_merge/6,
		suit_merge_preview/3,
		refine/6,
		inlay_ok/4,
		mod_strengthen_extra/2,
		smelt/5,
		fashion_wash/8,
		fashion_oper/4,
		ring_bless/6,
		make_equip_magic/11,
		equip_smelt_70/10,
		mod_strengthen_anti/2,
		mod_strengthen_attack_extra/1,
		mod_strengthen_ring_attribute/1,
		mod_strengthen_fashion_anti_hp/1,
		magic_oper/4,
		super_preview/1
		
    ]
).

%% 装备强化
strengthen(PlayerStatus, GoodsStatus, GoodsInfo, StoneInfo, RuneInfo1,N1,RuneInfo2,N2,RuneInfo3,N3,RuneInfo4,N4,Proinfo,GoodsStrengthenRule,GoodsStrengthenAntiRule,Auto_purch,GoldCost) ->
    %% 根据之前强化失败次数检查当前强化成功率
    Ratio = get_strengthen_ratio(GoodsInfo, GoodsStrengthenRule,RuneInfo1,N1,RuneInfo2,N2,RuneInfo3,N3,RuneInfo3,N4),
    %% 花费铜钱
    Cost = GoodsStrengthenRule#ets_base_goods_strengthen.coin,
    if PlayerStatus#player.bcoin > Cost ->
		   PlayerStatus2 = lib_goods:cost_money(PlayerStatus,Cost,bcoin,1552);
		true ->
			PlayerStatus2 = lib_goods:cost_money(PlayerStatus, Cost, coin,1552)
	end,
	if
		is_record(StoneInfo,goods) == true  ->
			if
				StoneInfo#goods.bind > 0 ->
					Bind = 2;
				true ->
					Bind = GoodsInfo#goods.bind
			end;
		true ->
			Bind = GoodsInfo#goods.bind
	end,
    %% 扣掉强化石
	if Auto_purch == 0 ->
		   {ok, NewStatus1, NewStoneNum} = lib_goods:delete_one(GoodsStatus, StoneInfo, 1),
		   PlayerStatus3 = PlayerStatus2,
		   Bind1 = Bind,
		   StoneInfoTypeId = StoneInfo#goods.goods_id;
	   true ->%%有强化石直接用强化石
		   if is_record(StoneInfo,goods) == true ->
				  {ok, NewStatus1, NewStoneNum} = lib_goods:delete_one(GoodsStatus, StoneInfo, 1),
				  PlayerStatus3 = PlayerStatus2,
				  Bind1 = Bind,
				  StoneInfoTypeId = StoneInfo#goods.goods_id;
			  true ->%%没有强化石直接用元宝
				  NewStatus1 = GoodsStatus,
				  NewStoneNum = 0,
				  PlayerStatus3 = lib_goods:cost_money(PlayerStatus2,GoldCost,gold,1580),
				  Bind1 = Bind,
				  %%类型为0表示是直接用元宝购买强化石
				  StoneInfoTypeId = 0
		   end
	end,
    %% 扣掉幸运符
    {ok, NewStatus2, NN1} = lib_goods:delete_one(NewStatus1, RuneInfo1,N1),
    {ok, NewStatus3, NN2} = lib_goods:delete_one(NewStatus2, RuneInfo2,N2),
    {ok, NewStatus4, NN3} = lib_goods:delete_one(NewStatus3,RuneInfo3,N3),
    {ok, NewStatus5, NN4} = lib_goods:delete_one(NewStatus4,RuneInfo4,N4),
	{ok,NewStatus6,_} = lib_goods:delete_one(NewStatus5,Proinfo,1),
	RuneNum = N1 + N2 + N3 + N4,
	
    %% 更新物品状态
    Ram = util:rand(1, 10000),
	%%去掉 vip强化成功率加成 
	%%{PlayerStatusVip,_,Award} = lib_vip:get_vip_award(intensify,PlayerStatus2),
	%%NewRatio = round(Ratio+Award*100),
	%%计算强化效果法宝，法宝时装，挂饰时间
    case Ratio * 100 >= Ram of
        %% 强化成功
        true ->
			Result=1,
			Stren_fail = GoodsInfo#goods.stren_fail,
            NewStrengthen = strengthen_ok(PlayerStatus3,GoodsInfo,Bind1,GoodsStrengthenRule,GoodsStrengthenAntiRule),		
			NewPlayerStatus = PlayerStatus3,
            spawn(fun() -> (catch log:log_stren(PlayerStatus3, GoodsInfo,Ratio,Ram div 100,Stren_fail, StoneInfoTypeId, RuneInfo1#goods.goods_id,RuneNum,Proinfo#goods.id,Cost,1))end);
        %% 强化失败
        false ->
			Result=0,
            [NewStrengthen, Stren_fail] = strengthen_fail(PlayerStatus3,GoodsInfo,Bind1,GoodsStrengthenRule,Proinfo),
			NewPlayerStatus = strengthen_recoup(PlayerStatus3,GoodsInfo#goods.stren+1),
            spawn(fun()-> (catch log:log_stren(PlayerStatus3, GoodsInfo,Ratio,Ram div 100, Stren_fail, StoneInfoTypeId, RuneInfo1#goods.goods_id, RuneNum,Proinfo#goods.id,Cost,0))end)
    end,
	%% 人物属性重新计算
	if GoodsInfo#goods.location == 1 ->
		   {ok, NewPlayerStatus1, NewStatus7} = goods_util:count_role_equip_attribute(NewPlayerStatus, NewStatus6, GoodsInfo);
	   true ->
		   NewPlayerStatus1 = NewPlayerStatus,
		   NewStatus7 = NewStatus6
	end,
	StrenEff = lib_goods:get_player_stren_eff(PlayerStatus#player.id),
	FbyfStren = lib_goods:get_player_fbyf_stren(PlayerStatus#player.id),
	SpyfStren = lib_goods:get_player_spyf_stren(PlayerStatus#player.id),
	NewPlayerStatus2 = NewPlayerStatus1#player{other = NewPlayerStatus1#player.other#player_other{fbyfstren = FbyfStren,spyfstren = SpyfStren,stren = StrenEff}},
	lib_player:send_player_attribute(NewPlayerStatus2,2),
	%%强化任务接口
	lib_task:event(open_strength,null,NewPlayerStatus2),
    {ok, NewPlayerStatus2, NewStatus7, [Result,NewStrengthen,NewStoneNum,Stren_fail,NN1,NN2,NN3,NN4]}.

%%强化成功率
get_strengthen_ratio(GoodsInfo, GoodsStrengthenRule,RuneInfo1,N1,RuneInfo2,N2,RuneInfo3,N3,RuneInfo4,N4) ->
	RatioB=GoodsStrengthenRule#ets_base_goods_strengthen.ratio,
	RatioA=GoodsInfo#goods.stren_fail * 2,
	F=fun({RuneInfo,N},Sum) ->
		case RuneInfo#goods.goods_id of
			20300 -> 
				5 * N + Sum; %%普通幸运
			20301 ->
				10 * N + Sum; %%七彩幸运
			20302 -> 
				10 * N + Sum; %% 八彩幸运
			20315 ->
				10 * N + Sum; %% 9彩幸运
			20303 ->
				8 * N + Sum; %%优秀
			20304 ->
				12 * N + Sum;%%精良
			20305 ->
				15 * N + Sum;%%完美
			20306 ->
				18 * N +Sum;%%极品
			_ -> 
				Sum
		end
	end,
	RatioX=lists:foldl(F, 0, [{RuneInfo1,N1},{RuneInfo2,N2},{RuneInfo3,N3},{RuneInfo4,N4}]),
	case RatioB + RatioA + RatioX > 100 of
		true ->100;
		false -> 
			if 
				GoodsInfo#goods.stren == 4  ->%%+5+6 *0.75
					round(RatioB * 0.8) + RatioA +RatioX ;					
				true ->
					RatioB+ RatioA +RatioX
			end
	end.

%%强化失败补偿 return PlayerStatus
strengthen_recoup(PlayerStatus,ToStren)->
	if
		ToStren =:= 7 orelse ToStren =:= 8 ->
			Goods_id = 28111;
		ToStren =:= 9 orelse ToStren =:= 10 ->
			Goods_id = 28112;
		true ->
			Goods_id = 0
	end,
	Price =
	case ToStren of
		8 -> 10000;
		9 -> 20000;
		10 -> 40000;
		_-> 0
	end,
	%%通过邮件返回礼包
	if
		Goods_id > 0 ->
			Msg0 = io_lib:format("强化+~s失败，返回补偿礼包", [tool:to_list(ToStren)]),
			spawn(fun()->lib_goods:add_new_goods_by_mail(PlayerStatus#player.nickname,Goods_id,2,1,"系统消息",Msg0)end);
		true ->
			skip
	end,
	if
		Price > 0 ->
			MyMsg= io_lib:format("强化+~s失败，返还绑定铜~s",[tool:to_list(ToStren),tool:to_list(Price)]),
			{ok,MyBin} = pt_15:write(15055,[MyMsg]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin),
			lib_goods:add_money(PlayerStatus,Price,bcoin,1502);
		true ->
			PlayerStatus
	end.
		
%%强化成功处理
strengthen_ok(PlayerStatus,GoodsInfo,Bind,GoodsStrengthenRule,GoodsStrengthenAntiRule) ->
	OldStrengthen = GoodsInfo#goods.stren,
    NewStrengthen = GoodsInfo#goods.stren + 1,
	%% 绑定处理
	Trade = Bind div 2,
	%% 强化+7 清除失败次数
	if
		NewStrengthen =:= 7 ->
			Expire = 0,
			Stren_fail =0;
		true->
			Expire = GoodsInfo#goods.expire_time,
			Stren_fail = GoodsInfo#goods.stren_fail
	end,
    NewGoodsInfo = GoodsInfo#goods{ stren=NewStrengthen, stren_fail=Stren_fail, bind = Bind, trade = Trade ,expire_time = Expire},
	ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
	%%先处理额外属性
	%% 强化+7 加成 
	if
		NewStrengthen >= 7 andalso NewGoodsInfo#goods.subtype =/= 22 andalso NewGoodsInfo#goods.subtype =/= 24 ->
			spawn(fun()-> mod_strengthen_extra(NewGoodsInfo,GoodsStrengthenRule)end);
		true ->
			skip
	end,
	%% 强化+8 攻击加成
	if
		NewStrengthen >= 8 andalso NewGoodsInfo#goods.subtype < 14 andalso NewGoodsInfo#goods.subtype =/= 24->
			spawn(fun()-> mod_strengthen_attack_extra(NewGoodsInfo)end);
		true ->
			skip
	end,
	%%如果是防具则增加抗性
	if
		NewGoodsInfo#goods.subtype > 13 andalso NewGoodsInfo#goods.subtype /= 23  andalso NewGoodsInfo#goods.subtype =/= 24  andalso NewGoodsInfo#goods.subtype =/= 26 andalso NewGoodsInfo#goods.subtype =/= 27->
			spawn(fun()->mod_strengthen_anti(NewGoodsInfo,GoodsStrengthenAntiRule)end);
		true ->
			skip
	end,
    spawn(fun()->db_agent:mod_strengthen(NewStrengthen, Stren_fail, Bind, Trade, Expire, GoodsInfo#goods.id)end),
	%%如果是新戒指
	if
		NewGoodsInfo#goods.subtype == 23 ->
			spawn(fun()->mod_strengthen_ring_attribute(NewGoodsInfo)end);
		true ->
			skip
	end,
	%%新时装处理强化抗性和气血上限百分比
	if
		NewGoodsInfo#goods.subtype == 24 ->
			spawn(fun()->mod_strengthen_fashion_anti_hp(NewGoodsInfo)end);
		true ->
			skip
	end,
	if
		OldStrengthen >= 5 ->
			spawn(fun()->sys_strengthen_msg(1,PlayerStatus,NewGoodsInfo,OldStrengthen)end);
		true ->
			skip
	end,
	%%坐骑强化修改强化等级
	if 
		GoodsInfo#goods.type == 10 andalso GoodsInfo#goods.subtype == 22 ->
			lib_mount:update_goods_mount_stren(GoodsInfo#goods.id,NewStrengthen),
			lib_achieve_outline:mount_stren_check(NewStrengthen, PlayerStatus#player.other#player_other.pid);%%坐骑强化成就判断
		true ->
			skip
	end,
    NewStrengthen.

%%新时装处理强化抗性和气血上限百分比
mod_strengthen_fashion_anti_hp(GoodsInfo) ->
	AttributeInfo = goods_util:get_goods_anti_attribute_info(GoodsInfo#goods.player_id,GoodsInfo#goods.id),
	AntiValue = 
		case GoodsInfo#goods.stren of
			1 -> 45;
			2 -> 51;
			3 -> 56;
			4 -> 63;
			5 -> 69;
			6 -> 74;
			7 -> 80;
			8 -> 87;
			9 -> 92;
			10 -> 98;
			_ -> 0
		end,
	Effect=[0,0,0,0,0,0,0,0,AntiValue,AntiValue,AntiValue,AntiValue,AntiValue],
	%%强化的加抗属性attribute_type = 4, attribute_id = 0
	case is_record(AttributeInfo, goods_attribute) of
		true ->	
			lib_goods:mod_goods_attribute(AttributeInfo,Effect);
		false ->
			%%attributeid  0 全抗。
			lib_goods:add_goods_attribute(GoodsInfo,4,0,Effect)
	end,
	
	%%强化的加气血 属性attribute_type = 2, attribute_id = 1
	if  GoodsInfo#goods.stren =< 6 ->
			skip;
		true ->
			AttributeInfo1 = goods_util:get_goods_hp_attribute_info(GoodsInfo#goods.player_id,GoodsInfo#goods.id),
			HpValue = 
				case GoodsInfo#goods.stren of
					7 -> 5;
					8 -> 7;
					9 -> 9;
					10 -> 11;
					_ -> 0
				end,
			ValueType = 1,
			Effect1 = [HpValue,0,0,0,0,0,0,0,0,0,0,0,0],
			case is_record(AttributeInfo1, goods_attribute) of
				true ->
					lib_goods:mod_goods_attribute(AttributeInfo1,Effect1);
				false ->
					lib_goods:add_goods_attribute(GoodsInfo,2,1,Effect1,ValueType)
			end
	end.

%%新戒指属性加成
mod_strengthen_ring_attribute(GoodsInfo) ->
	Attribute = goods_util:get_goods_attribute_info(GoodsInfo#goods.player_id,GoodsInfo#goods.id,1,1),
	Attribute2 = goods_util:get_goods_attribute_info(GoodsInfo#goods.player_id,GoodsInfo#goods.id,1,2),
	if
		is_record(Attribute,goods_attribute) andalso is_record(Attribute2,goods_attribute)  ->
			%%基础数值 气血
			Pattern = #ets_base_goods_add_attribute{ goods_id=GoodsInfo#goods.goods_id,color=GoodsInfo#goods.color,attribute_id = 1, _='_' },
            BaseAttributeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS_ADD_ATTRIBUTE, Pattern),
			BaseValue = BaseAttributeInfo#ets_base_goods_add_attribute.value,			
			%%基础数值 法力
			Pattern2 = #ets_base_goods_add_attribute{ goods_id=GoodsInfo#goods.goods_id,color=GoodsInfo#goods.color,attribute_id = 2, _='_' },
            BaseAttributeInfo2 = goods_util:get_ets_info(?ETS_BASE_GOODS_ADD_ATTRIBUTE, Pattern2),
			BaseValue2 = BaseAttributeInfo2#ets_base_goods_add_attribute.value,
			
			%%取防具的强化加成效果
			Pattern3 = #ets_base_goods_strengthen{ strengthen=GoodsInfo#goods.stren ,type=4, _='_' },
    		GoodsStrengthenRule = goods_util:get_ets_info(?ETS_BASE_GOODS_STRENGTHEN, Pattern3),
			
			Value = trunc(BaseValue * (1 + GoodsStrengthenRule#ets_base_goods_strengthen.value / 100)),
			Effect=[Value, 0, 0,0,0,0,0,0,0,0,0,0,0],
			lib_goods:mod_goods_attribute(Attribute,Effect),
			
			Value2 = trunc(BaseValue2 * (1 + GoodsStrengthenRule#ets_base_goods_strengthen.value / 100)),
			Effect2=[0,Value2, 0,0,0,0,0,0,0,0,0,0,0],
			lib_goods:mod_goods_attribute(Attribute2,Effect2),
			ok;
		true ->
			skip
	end.
	

%%抗性加成属性
mod_strengthen_anti(GoodsInfo,GoodsStrengthenAntiRule) ->
	case is_record(GoodsStrengthenAntiRule ,ets_base_goods_strengthen_anti) of
		true ->
			[?ETS_BASE_GOODS_STRENGTHEN_ANTI,_,_,_,_,Value] = tuple_to_list(GoodsStrengthenAntiRule),
			AntiAttributeInfo=goods_util:get_goods_anti_attribute_info(GoodsInfo#goods.player_id,GoodsInfo#goods.id),
			Effect=[0, 0, 0,0,0,0,0,0,Value,Value,Value,Value,Value],
			case is_record(AntiAttributeInfo ,goods_attribute) of
				true ->					
					lib_goods:mod_goods_attribute(AntiAttributeInfo,Effect);
				false ->
					%%attributeid  0 5抗。
					lib_goods:add_goods_attribute(GoodsInfo,4,0,Effect)
			end;
		false ->
			skip
	end.

%% +8+9+10 攻击加成
mod_strengthen_attack_extra(GoodsInfo) ->
	Step  = goods_util:level_to_step(GoodsInfo#goods.level),
	[Stren8,Stren9,Stren10] =
	case Step of
		1 ->[5,8,10];
		2 ->[10,15,20];
		3 ->[15,23,30];
		4 ->[30,38,50];
		5 ->[35,50,70];
		6 ->[50,65,90];
		7 ->[60,80,110];
		8 ->[70,100,135];
		9 ->[85,120,165];
		10 ->[105,145,200]
	end,
	Value =
	case GoodsInfo#goods.stren of
		8 -> Stren8;
		9 -> Stren9;
		10 -> Stren10
	end,
	AntiAttributeInfo = goods_util:get_goods_attribute_info(GoodsInfo#goods.player_id,GoodsInfo#goods.id,5),
	Effect=[0, 0, Value,Value,0,0,0,0,0,0,0,0,0],
	case is_record(AntiAttributeInfo ,goods_attribute) of
		true ->					
			lib_goods:mod_goods_attribute(AntiAttributeInfo,Effect);
		false ->
			%%3最大攻击
			lib_goods:add_goods_attribute(GoodsInfo,5,3,Effect)
	end,
	ok.
	
%%+7属性
%% GoodsInfo 当前物品最新信息
mod_strengthen_extra(GoodsInfo,GoodsStrengthenRule)  ->
	Strengthen = GoodsInfo#goods.stren,
	Pattern=#ets_base_goods_strengthen_extra{level = GoodsInfo#goods.level , _='_'},
	Goods_stren_extra=goods_util:get_ets_info(?ETS_BASE_GOODS_STRENGTHEN_EXTRA,Pattern),
	if 
		GoodsInfo#goods.subtype == 26 orelse GoodsInfo#goods.subtype == 27 -> %%法宝时装和饰品时装不添加暴击和气血
		   Hp=0,
		   Crit =0;
	   true ->
		   [?ETS_BASE_GOODS_STRENGTHEN_EXTRA,_level,Crit7,Crit8,Crit9,Crit10,Hp7,Hp8,Hp9,Hp10]=tuple_to_list(Goods_stren_extra),
		   case GoodsStrengthenRule#ets_base_goods_strengthen.type of
			   3 -> %%法宝+暴击
					Crit=
						case Strengthen of
							7 -> Crit7;
							8 -> Crit8;
							9 -> Crit9;
							10 -> Crit10;
							_-> Crit7
						end,
					Hp = 0;
			 4 -> %%防具 + 气血
				    Hp=
						case Strengthen of
							7 -> Hp7;
							8 -> Hp8;
							9 -> Hp9;
							10 -> Hp10;
							_ -> Hp7
						end,
					Crit = 0;
			   _ ->
				   Hp=0,
				   Crit =0
		   end
	end,
	Effect=[Hp, 0, 0,0,0,0,0, Crit,0,0,0,0,0],
	AttributeInfo=goods_util:get_goods_attribute_info(GoodsInfo#goods.player_id,GoodsInfo#goods.id,2),
	case is_record(AttributeInfo ,goods_attribute) of
		true ->	
			lib_goods:mod_goods_attribute(AttributeInfo,Effect);
		false ->
			AttributeId =
				case GoodsStrengthenRule#ets_base_goods_strengthen.type of
					3 -> 7 ; %%暴击
					4 -> 1 ; %% 气血
					_ -> 0
				end,
			if 
				AttributeId > 0 ->
					lib_goods:add_goods_attribute(GoodsInfo,2,AttributeId,Effect,1);
				true ->
					skip
			end
	end.
	

%%强化失败处理，绑定和可交易的属性不变
strengthen_fail(PlayerStatus,GoodsInfo,Bind,GoodsStrengthenRule,Proinfo) ->
	OldStrengthen = GoodsInfo#goods.stren,
	if
		Proinfo#goods.num > 0 ->
			NewStrengthen = GoodsInfo#goods.stren;
		true ->
    		NewStrengthen = GoodsStrengthenRule#ets_base_goods_strengthen.fail
	end,
	Step=goods_util:level_to_step(GoodsInfo#goods.level),
	Pattern = #ets_base_goods_strengthen_anti{subtype=GoodsInfo#goods.subtype,step=Step,stren=NewStrengthen, _='_' },
	GoodsStrengthenAntiRule = goods_util:get_ets_info(?ETS_BASE_GOODS_STRENGTHEN_ANTI,Pattern),
	%% 绑定处理
	Trade = Bind div 2,
	Stren_fail =
		%%强化失败额外增加失败次数,有保护符不增加
		if Proinfo#goods.num > 0 ->
			   GoodsInfo#goods.stren_fail;
		   true ->
			case GoodsInfo#goods.stren of
				7 ->  GoodsInfo#goods.stren_fail + 5;
				8 ->  GoodsInfo#goods.stren_fail + 10;
				9 ->  GoodsInfo#goods.stren_fail;
		 		_ ->  GoodsInfo#goods.stren_fail +1 
			end
		end,
	NewGoodsInfo = GoodsInfo#goods{ stren=NewStrengthen, stren_fail=Stren_fail, bind = Bind, trade = Trade},
    ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
	%%强化+7 处理
	if
		GoodsInfo#goods.stren == NewStrengthen ->
			skip;
		GoodsInfo#goods.stren >= 7 andalso NewStrengthen < 7 andalso GoodsInfo#goods.subtype =/= 22 andalso GoodsInfo#goods.subtype =/= 24 ->
			spawn(fun()->lib_goods:del_goods_attribute(NewGoodsInfo#goods.player_id, NewGoodsInfo#goods.id, 2)end);
		GoodsInfo#goods.stren >=7 andalso NewStrengthen >= 7 andalso GoodsInfo#goods.subtype =/= 22 andalso GoodsInfo#goods.subtype =/= 24 ->
			spawn(fun()->mod_strengthen_extra(NewGoodsInfo,GoodsStrengthenRule)end);
		true ->
			skip
	end,
	%% 强化+8 攻击加成
	if
		GoodsInfo#goods.stren == NewStrengthen ->
			skip;
		NewStrengthen >= 8 andalso NewGoodsInfo#goods.subtype < 14 ->
			spawn(fun()-> mod_strengthen_attack_extra(NewGoodsInfo)end);
		GoodsInfo#goods.stren >=8 andalso NewStrengthen < 8 andalso NewGoodsInfo#goods.subtype < 14 ->
			spawn(fun()->lib_goods:del_goods_attribute(NewGoodsInfo#goods.player_id, NewGoodsInfo#goods.id, 5)end);
		true ->
			skip
	end,
	%%抗性属性处理
	if
		GoodsInfo#goods.stren == NewStrengthen ->
			skip;
		NewGoodsInfo#goods.subtype > 13 andalso NewGoodsInfo#goods.subtype /= 23 andalso GoodsInfo#goods.subtype =/= 24 ->
			spawn(fun()->mod_strengthen_anti(NewGoodsInfo,GoodsStrengthenAntiRule)end);
		true ->
			skip
	end,
    spawn(fun()->db_agent:mod_strengthen(NewStrengthen, Stren_fail, Bind, Trade,GoodsInfo#goods.expire_time,GoodsInfo#goods.id)end),
	%%如果是新戒指
	if
		GoodsInfo#goods.stren == NewStrengthen ->
			skip;
		NewGoodsInfo#goods.subtype == 23 ->
			spawn(fun()->mod_strengthen_ring_attribute(NewGoodsInfo)end);
		true ->
			skip
	end,
	%%如果是新时装,则要调整全抗和气血
	if
		GoodsInfo#goods.stren == NewStrengthen ->
			skip;
		NewGoodsInfo#goods.subtype == 24 ->
			if GoodsInfo#goods.stren >= 7 andalso NewStrengthen < 7 ->
				   spawn(fun()->lib_goods:del_goods_attribute(NewGoodsInfo#goods.player_id, NewGoodsInfo#goods.id, 2,1)end),
				   spawn(fun()->mod_strengthen_fashion_anti_hp(NewGoodsInfo)end);
			   true ->
				   spawn(fun()->mod_strengthen_fashion_anti_hp(NewGoodsInfo)end)
			end;
		true ->
			skip
	end,
	if
		OldStrengthen >= 6 ->
			spawn(fun()->sys_strengthen_msg(2,PlayerStatus,NewGoodsInfo,OldStrengthen)end);
		true ->
			skip
	end,
	%%坐骑强化修改强化等级
	if 
		GoodsInfo#goods.type == 10 andalso GoodsInfo#goods.subtype == 22 ->
			lib_mount:update_goods_mount_stren(GoodsInfo#goods.id,NewStrengthen);
		true ->
			skip
	end,
    [NewStrengthen, Stren_fail].

%% 装备打孔
hole(PlayerStatus, Status, GoodsInfo, StoneInfo ,Cost, GoldCost) ->
	%% 绑定处理
	if is_record(StoneInfo,goods) == true andalso StoneInfo#goods.bind == 0->Bind = GoodsInfo#goods.bind;
	   is_record(StoneInfo,goods) == true andalso StoneInfo#goods.bind == 1->Bind = 2;
	   is_record(StoneInfo,goods) == true andalso StoneInfo#goods.bind == 2->Bind = 2;
	   is_record(StoneInfo,goods) == false andalso StoneInfo#goods.bind == 2->Bind = GoodsInfo#goods.bind;
	   true ->Bind = GoodsInfo#goods.bind
	end,
	Trade = Bind div 2,
	 %% 更新物品状态
    NewHole = GoodsInfo#goods.hole + 1,
    spawn(fun()->db_agent:quality_hole(NewHole, Bind, Trade, GoodsInfo#goods.id)end),
    NewGoodsInfo = GoodsInfo#goods{ hole=NewHole, bind = Bind, trade = Trade },
    ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
	NewPlayerStatus = lib_goods:cost_money(PlayerStatus, Cost, coin,1553),
	if is_record(StoneInfo,goods) == true ->
	    %% 扣掉打孔石
	    {ok, NewStatus, NewStoneNum} = lib_goods:delete_one(Status, StoneInfo, 1),
		NewPlayerStatus1 = NewPlayerStatus,
		spawn(fun()-> log:log_hole(NewPlayerStatus1, GoodsInfo, StoneInfo#goods.goods_id, Cost, 1) end);
	  true ->
		NewStatus = Status,
		NewStoneNum = 0,
		NewPlayerStatus1 = lib_goods:cost_money(NewPlayerStatus,GoldCost,gold,1586),
		spawn(fun()-> log:log_hole(NewPlayerStatus1, GoodsInfo, 0, Cost, 1) end)
	end,
	gen_server:cast(NewPlayerStatus1#player.other#player_other.pid, {'SET_PLAYER', NewPlayerStatus1}),
	lib_player:send_player_attribute(NewPlayerStatus1,2),
    {ok, NewPlayerStatus1, NewStatus, [NewHole, NewStoneNum]}.

%% 宝石合成
compose(PlayerStatus, Status, StoneList,TotalStoneNum, RuneInfo, GoodsComposeRule, RuneTypeId, Auto_purch, GoldCost) ->
    %% 根据宝石数和幸运符计算成功率
    Ratio = 
		case is_record(RuneInfo,goods) of
			true ->%%有合成符
				RuneId = RuneInfo#goods.goods_id,
				Rbind = RuneInfo#goods.bind,
				(TotalStoneNum-1)  * 25 + 25;
			false when Auto_purch == 1 ->%%没有合成符且选择自动购买
				RuneId = RuneTypeId,
				Rbind = 0,
				(TotalStoneNum-1)  * 25 + 25;
			false ->%%没有合成符且没有选择自动购买
				RuneId = 0,
				Rbind = 0,
				(TotalStoneNum-1)  * 25
		end,
	Bind = 
		case lists:foldl(fun([StoneInfo, _num], Sum) -> StoneInfo#goods.bind + Sum end, 0, StoneList) of
			0 ->Rbind;
			_ -> 2
		end,
	Trade = Bind div 2,
    %% 花费铜钱
    Cost = GoodsComposeRule#ets_base_goods_compose.coin,
    NewPlayerStatus = lib_goods:cost_money(PlayerStatus, Cost, coin,1554),
    %% 扣掉宝石
    F = fun([StoneInfo, StoneNum], Status1) ->
            {ok, NewStatus, _} = lib_goods:delete_one(Status1, StoneInfo, StoneNum),
            NewStatus
         end,
    NewStatus1 = lists:foldl(F, Status, StoneList),
    %% 扣掉幸运符
    {ok, NewStatus2, _} = 
		case is_record(RuneInfo,goods) of
			true ->
				NewPlayerStatus1 = NewPlayerStatus,
				lib_goods:delete_one(NewStatus1, RuneInfo, 1);
			false when Auto_purch == 1 ->%%没有合成符且选择自动购买
				NewPlayerStatus1 = lib_goods:cost_money(NewPlayerStatus,GoldCost,gold,1585),
				{ok,NewStatus1,1};
			false ->
				NewPlayerStatus1 = NewPlayerStatus,
				{ok,NewStatus1,1}
		end,
    %NewRuneNum = 0,
    %% 更新物品状态
    Ram0 = util:rand(1, 10000),
	%% 手动调整概率
	if
		Ratio < 100 ->
			Ram = Ram0 + 1000;%%扩大随机数
		true ->
			Ram = Ram0
	end,
    GoodsTypeInfo = goods_util:get_goods_type(GoodsComposeRule#ets_base_goods_compose.new_id),
	FailGoodsTypeInfo = goods_util:get_goods_type(GoodsComposeRule#ets_base_goods_compose.fail_id),
	gen_server:cast(NewPlayerStatus1#player.other#player_other.pid, {'SET_PLAYER', NewPlayerStatus1}),
	lib_player:send_player_attribute(NewPlayerStatus1,2),
    case Ratio * 100 >= Ram  of
        %% 合成成功
        true when is_record(GoodsTypeInfo, ets_base_goods) ->
            {ok, NewStatus3} = compose_ok(NewStatus2, GoodsTypeInfo, 1, Bind, Trade),
            spawn(fun()->catch(log:log_compose(NewPlayerStatus, GoodsComposeRule, GoodsTypeInfo#ets_base_goods.subtype, RuneId,Ratio,Ram div 100,TotalStoneNum, Cost, 1))end),
            {ok, NewPlayerStatus1, NewStatus3, GoodsTypeInfo#ets_base_goods.goods_id};
        %% 合成失败 有返回物品
        false when is_record(FailGoodsTypeInfo,ets_base_goods) ->
			F2 = fun(FailStoneTypeInfo,Status_1) ->
						 {ok,NewStatus_1} = compose_ok(Status_1,FailStoneTypeInfo,1,Bind,Trade),
						 NewStatus_1
				 end,
            NewStatus3 = lists:foldl(F2, NewStatus2,lists:duplicate(TotalStoneNum,FailGoodsTypeInfo)),
            spawn(fun()->catch(log:log_compose(NewPlayerStatus1, GoodsComposeRule, GoodsTypeInfo#ets_base_goods.subtype, RuneId, Ratio,Ram div 100,TotalStoneNum,Cost, 0))end),
            {fail, NewPlayerStatus, NewStatus3, 0};
		%%合成失败没有返回物品
		_ ->
			spawn(fun()->catch(log:log_compose(NewPlayerStatus1,GoodsComposeRule, GoodsTypeInfo#ets_base_goods.subtype, RuneId ,Ratio,Ram div 100, TotalStoneNum,Cost, 0))end),
            {fail, NewPlayerStatus, NewStatus2, 0}
    end.

compose_ok(GoodsStatus, GoodsTypeInfo, GoodsNum, Bind, Trade) ->
    NewInfo = goods_util:get_new_goods(GoodsTypeInfo),
	NewGoodsInfo = NewInfo#goods{ bind = Bind, trade = Trade },
    lib_goods:add_goods_base(GoodsStatus, GoodsTypeInfo, GoodsNum, NewGoodsInfo).

%% 宝石镶嵌
inlay(PlayerStatus, Status, GoodsInfo, StoneInfo, TotalRuneNum,Rbind,NewRuneList, GoodsInlayRule,Cost,Auto_purch,GoldCost) ->
    %% 根据幸运符计算成功率
    if  
		TotalRuneNum < 3 andalso Auto_purch == 1 ->
			Ratio = 25 + 25 * 3;
		TotalRuneNum == 3 ->
			Ratio = 25 + 25 * 3;
		TotalRuneNum > 0 ->
		   Ratio = 25 + 25 * TotalRuneNum;
	   true ->
		   Ratio = 25
	end,
		%% 绑定处理
	Bind=
		case StoneInfo#goods.bind of
			0 ->
				if
					Rbind > 0 ->
						2;
					true ->
						GoodsInfo#goods.bind
				end;
			1 ->2;
			2 ->2;
		_ ->GoodsInfo#goods.bind
		end,
	Trade = Bind div 2,
    NewPlayerStatus = lib_goods:cost_money(PlayerStatus, Cost, coin,1555),
    %% 扣掉宝石
    {ok, Status1, _} = lib_goods:delete_one(Status, StoneInfo, 1),
    %% 扣掉幸运符
    F = fun([RuneInfo, RuneNum], _Status) ->
            {ok, _NewStatus, _} = lib_goods:delete_one(_Status, RuneInfo, RuneNum),
            _NewStatus
         end,
    Status2 = lists:foldl(F, Status1, NewRuneList),
	if TotalRuneNum < 3 andalso Auto_purch == 1 andalso GoldCost > 0 ->
		NewPlayerStatus1 = lib_goods:cost_money(NewPlayerStatus,GoldCost,gold,1587);
	   true ->
		NewPlayerStatus1 = NewPlayerStatus
	end,
    %% 更新物品状态
    Ram = util:rand(1, 10000),
    case Ratio * 100 >= Ram of
        %% 镶嵌成功
        true ->
            inlay_ok(GoodsInfo, StoneInfo, Bind, Trade),
            spawn(fun()->(catch log:log_inlay(NewPlayerStatus1, GoodsInfo, StoneInfo#goods.goods_id,Ratio,Ram div 100,TotalRuneNum,Cost, 1))end),
			%% 人物属性重新计算
			if GoodsInfo#goods.location == 1 ->
				   {ok, NewPlayerStatus2, Status3} = goods_util:count_role_equip_attribute(NewPlayerStatus1, Status2, GoodsInfo);
			   true ->
				   NewPlayerStatus2 = NewPlayerStatus1,
				   Status3 = Status2
			end,
			
			{ok, 1, NewPlayerStatus2, Status3};
        %% 镶嵌失败 
        false ->
			NewGoodsInfo = 
				case Bind of
					2 -> lib_goods:bind_goods(GoodsInfo);
					_-> GoodsInfo
				end,
			Status3=
			case GoodsInlayRule#ets_base_goods_inlay.fail_goods_id of
				0 -> Status2;
				GoodsTypeId ->
					%%失败返回物品
					case lib_goods:give_goods({GoodsTypeId,1,Bind},Status2) of
						{fail,_,_}->Status2;
						{ok,_Status3}->_Status3
					end
			end,
            spawn(fun()-> catch(log:log_inlay(NewPlayerStatus1, NewGoodsInfo, StoneInfo#goods.goods_id,Ratio,Ram div 100,TotalRuneNum,Cost, 0))end),
            {ok, 0, NewPlayerStatus1, Status3}
    end.

inlay_ok(GoodsInfo, StoneInfo, Bind, Trade) ->
    case GoodsInfo#goods.hole1_goods > 0 of
        false ->
            StoneCol = "hole1_goods",
            NewGoodsInfo = GoodsInfo#goods{ hole1_goods=StoneInfo#goods.goods_id, bind = Bind, trade = Trade };
        true when GoodsInfo#goods.hole2_goods =:= 0 ->
            StoneCol = "hole2_goods",
            NewGoodsInfo = GoodsInfo#goods{ hole2_goods=StoneInfo#goods.goods_id, bind = Bind, trade = Trade };
        true when GoodsInfo#goods.hole3_goods =:= 0 ->
            StoneCol = "hole3_goods",
            NewGoodsInfo = GoodsInfo#goods{ hole3_goods=StoneInfo#goods.goods_id, bind = Bind, trade = Trade }
    end,
    spawn(fun()->db_agent:quality_inlay_ok(StoneCol, StoneInfo#goods.goods_id, Bind, Trade, GoodsInfo#goods.id)end),
    ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
    %% 更新装备属性
    AttributeId = goods_util:get_inlay_attribute_id(StoneInfo),
    Effect = goods_util:count_inlay_addition(StoneInfo),
	Effect2 = [StoneInfo#goods.goods_id|Effect],
    lib_goods:add_goods_attribute(GoodsInfo,3,AttributeId, Effect2,0),
    ok.

%%装备精炼
refine(Player,GoodsStatus,GoodsInfo,StoneList,Cost,RBind)->
	if
		%%精炼
		GoodsInfo#goods.color == 3 ->
			Type = GoodsInfo#goods.type,
			Subtype = GoodsInfo#goods.subtype,
			Step = GoodsInfo#goods.step,
			Level = GoodsInfo#goods.level,
			%%获取对应的紫装备信息
			if
				GoodsInfo#goods.subtype < 14 ->
					Pattern = #ets_base_goods{type=Type,subtype = Subtype,step = Step,color = 4,_='_'};
				true ->
					Pattern = #ets_base_goods{type=Type,subtype = Subtype,level = Level,color = 4,_='_'}
			end,
			GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS,Pattern),
			OldAttributeList = goods_util:get_goods_attribute_list(Player#player.id,GoodsInfo#goods.id,1),
			F_1 = fun(AttributeInfo) ->
				  case AttributeInfo#goods_attribute.status of
					  1 -> Identify = 0;
					  _ -> Identify = 1
				  end,
				{AttributeInfo#goods_attribute.attribute_id,Identify}
			end,
			AttList = lists:map(F_1, OldAttributeList),
			%%如果是饰品,
			if
				GoodsInfo#goods.color == 3 andalso GoodsInfo#goods.subtype == 21 ->
					AttList1 = AttList ++ [{21,1},{22,1},{23,1}];
				true ->
					AttList1 = AttList
			end,
			case RBind > 0 of
				true -> Bind =2;
				false -> Bind = 0
			end,	
			%% 扣掉紫水晶
			F = fun([StoneInfo, StoneNum], Status0) ->
				{ok, _NewStatus,_} = lib_goods:delete_one(Status0, StoneInfo, StoneNum),
				_NewStatus
			end,
			GoodsStatus1 = lists:foldl(F, GoodsStatus, StoneList),
			{ok,GoodsStatus2,_}= lib_goods:delete_one(GoodsStatus1,GoodsInfo,1),
			{ok,NewStatus} = lib_goods:add_equip_base(GoodsStatus2,GoodsTypeInfo,AttList1,Bind),
			NewPlayer = lib_goods:cost_money(Player,Cost,coin,1560),
			%%日志
			spawn(fun()->log:log_refine(Player,GoodsInfo,GoodsTypeInfo#ets_base_goods.goods_id,Cost,1)end),
			{ok,1,NewPlayer,NewStatus};
		%%紫饰品的属性鉴定
		GoodsInfo#goods.color == 4 ->
			AttributeList = goods_util:get_goods_attribute_list(Player#player.id,GoodsInfo#goods.id,1),
			%%过滤未鉴定属性
			F_filter=fun(_Attribute)->
				if
					%% 0不可用，1可用
					_Attribute#goods_attribute.status == 0 ->
							true;
					true ->
							false
				end
			end,
			AttributeList2=lists:filter(F_filter,AttributeList),
			%%优先鉴定顺序  气血百分比1[22] 攻击百分比3[21] 抗性穿透23
			case length(AttributeList2) of
				3 -> OrderAttid = 22;
				2 -> OrderAttid = 21;
				1 -> OrderAttid = 23;
				_ -> OrderAttid = 0
			end,
			F_order = fun(_Attribute2) ->
				if
					_Attribute2#goods_attribute.attribute_id == OrderAttid ->
						true;
					true ->
						false
				end
			end,
			OrderAttributeList = lists:filter(F_order, AttributeList2),	
			case length(OrderAttributeList) == 1 of
				true ->
					Attribute = hd(OrderAttributeList),
					spawn(fun()->db_agent:identify(Attribute#goods_attribute.id)end),
					AttributeNew=Attribute#goods_attribute{status = 1},
					ets:insert(?ETS_GOODS_ATTRIBUTE,AttributeNew),
					if
						RBind > 0 ->
							lib_goods:bind_goods(GoodsInfo);
						true ->
							skip
					end,
					%% 扣掉紫水晶
					F = fun([StoneInfo, StoneNum], Status0) ->
						{ok, _NewStatus,_} = lib_goods:delete_one(Status0, StoneInfo, StoneNum),
						_NewStatus
					end,
					GoodsStatus1 = lists:foldl(F, GoodsStatus, StoneList),
					NewPlayer = lib_goods:cost_money(Player,Cost,coin,1560),
					gen_server:cast(self(),	{'info_15000', GoodsInfo#goods.id, 1}),
					{ok,1,NewPlayer,GoodsStatus1};
				false ->
					{ok,1,Player,GoodsStatus}
			end;
		true ->
			{ok,1,Player,GoodsStatus}
	end.

	
	
%% 装备分解
idecompose(Player,GoodsStatus,GoodsInfoList,Type,Cost,GoodsTotalList) ->
	if
		%% type == 0为预览
		Type == 0 ->
			{ok,1,Player,GoodsStatus};
		Type == 1 ->
			F_del = fun(_GoodsInfo,_goodsStatus0) ->
							{ok,_goodsStatus1,_} = lib_goods:delete_one(_goodsStatus0,_GoodsInfo,1),
							_goodsStatus1
					end,
			Status1 = lists:foldl(F_del,GoodsStatus , GoodsInfoList),
			F_give = fun({_goods_id,_num,_bind},_goodsStatus2) ->
						{ok,_GoodsStatus3} = lib_goods:give_goods({_goods_id,_num,_bind},_goodsStatus2),
						_GoodsStatus3
				end,
			Status2 = lists:foldl(F_give, Status1,GoodsTotalList),
			NewPlayer = lib_goods:cost_money(Player,Cost,coin,1558),
			F_log = fun(_G) ->
							_G#goods.goods_id
					end,
			LogList = lists:map(F_log, GoodsInfoList),
			spawn(fun()->log:log_idecompose(Player,LogList,Cost,1)end),
			{ok,1,NewPlayer,Status2};
		true ->
			{ok,1,Player,GoodsStatus}
	end.

%% 材料合成
icompose(Player,GoodsStatus,IcomposeRule,N) ->
	Cost = IcomposeRule#ets_base_goods_icompose.price * N,
	Ratio = IcomposeRule#ets_base_goods_icompose.ratio,
	Goods_id = IcomposeRule#ets_base_goods_icompose.goods_id,
	%%require = [{goods_id,num},{goods_id,num}|..]
	Require = util:string_to_term(tool:to_list(IcomposeRule#ets_base_goods_icompose.require)),
	F = fun({_goods_id,_num},[_status,BindNum ,TotalNum]) ->
				%%已有未绑定
				NoBindList = goods_util:get_type_goods_list(Player#player.id,_goods_id,0,4),
				%%已有绑定列表
				BindList = goods_util:get_type_goods_list(Player#player.id,_goods_id,2,4),
				%%绑定总数量
				BindTotal = goods_util:get_goods_totalnum(BindList),
				if
					BindTotal >= _num * N ->
						%%绑定数量已经足够
						{ok,_newStatus} = lib_goods:delete_more(_status,BindList,_num * N),
						NewBindNum = BindNum + _num * N;
					true ->
						{ok,_newStatus1} = lib_goods:delete_more(_status,BindList,BindTotal),
						{ok,_newStatus} = lib_goods:delete_more(_newStatus1,NoBindList,_num * N - BindTotal),
						NewBindNum = BindNum + BindTotal
				end,
				NewTotalNum = TotalNum + _num * N,
				[_newStatus,NewBindNum,NewTotalNum]
		end,	
	[Status1 ,DelBindNum, NeedNum] = lists:foldl(F, [GoodsStatus ,0,0 ], Require),
	NewPlayer = lib_goods:cost_money(Player,Cost,coin,1559),
	%%成功合成的个数
	F_suc = fun(_,SucN) ->
					Ram = util:rand(1,10000),
					if
						Ratio * 100 >= Ram ->
							SucN + 1;
						true ->
							SucN
					end
			end,
	%%成功个数
	Suc_num = lists:foldl(F_suc, 0, lists:seq(1, N)),
	%%生成绑定物品的个数
	MakeBind = util:ceil(Suc_num * (DelBindNum / NeedNum)),
	%%失败个数
	Fail_num = N - Suc_num,
	%% 绑定物品优先落入失败数里面
	if
		Suc_num > 0 andalso Fail_num > 0 andalso MakeBind >0->
			if
				MakeBind > Fail_num ->
					%%需要绑定 > 失败数
					NeedBind = MakeBind - Fail_num;
				true ->
					NeedBind = 0
			end;
		Suc_num >0 andalso Fail_num == 0 andalso MakeBind >0 ->
			NeedBind = MakeBind;
		true ->
			NeedBind = 0
	end,
	if
		Suc_num > 0 andalso NeedBind >0 -> %%成功但有绑定的情况
			{ok,Status2} = lib_goods:give_goods({Goods_id,NeedBind,2},Status1),
			{ok,NewGoodsStatus} = lib_goods:give_goods({Goods_id,Suc_num - NeedBind,0},Status2),
			spawn(fun()-> log:log_icompose(Player,IcomposeRule,Ratio,Suc_num,Cost,1) end),
			{ok,1,Suc_num,Fail_num,NewPlayer,NewGoodsStatus};
		Suc_num > 0 andalso NeedBind == 0 -> %%成功但没有绑定
			{ok,NewGoodsStatus} = lib_goods:give_goods({Goods_id,Suc_num,0},Status1),
			spawn(fun()-> log:log_icompose(Player,IcomposeRule,Ratio,Suc_num,Cost,1) end),
			{ok,1,Suc_num,Fail_num,NewPlayer,NewGoodsStatus};
		true ->
			spawn(fun()-> log:log_icompose(Player,IcomposeRule,Ratio,Suc_num,Cost,0) end),
			{ok,0,0,0,NewPlayer,GoodsStatus}
	end.

%% 宝石拆除
backout(PlayerStatus,Status,GoodsInfo,StoneTypeInfo,TotalRuneNum,NewRuneList,GoodsInlayRune,Rbind,Cost,Auto_purch,GoldCost) ->
    NewPlayerStatus = lib_goods:cost_money(PlayerStatus, Cost, coin,1556),
	F=fun([RuneInfo,Num],Status1) ->
			  {ok,NewStatus,_}=lib_goods:delete_one(Status1,RuneInfo,Num),
			  NewStatus
	  end,
	NewStatus2=lists:foldl(F, Status, NewRuneList),
	%% 绑定处理
	Bind = 
		if
			Rbind > 0 ->
				2;
			true ->
				GoodsInfo#goods.bind
		end,
	Trade = Bind div 2,
	Ram = util:rand(1,10000),
	if TotalRuneNum < 3 andalso Auto_purch ==1 ->
		   Ratio = 3 * 25 + 25;
	   true ->
		   Ratio = TotalRuneNum * 25 + 25
	end,
	%%成功失败都需要腾出孔位
	NewGoodsInfo =
		if
			StoneTypeInfo#ets_base_goods.goods_id =:= GoodsInfo#goods.hole1_goods ->
				GoodsInfo#goods{hole1_goods =0, bind = Bind, trade = Trade };
			StoneTypeInfo#ets_base_goods.goods_id =:= GoodsInfo#goods.hole2_goods ->
				GoodsInfo#goods{hole2_goods =0, bind = Bind, trade = Trade };
			StoneTypeInfo#ets_base_goods.goods_id =:= GoodsInfo#goods.hole3_goods ->
				GoodsInfo#goods{hole3_goods =0, bind = Bind, trade = Trade };
			true ->
				GoodsInfo#goods{hole1_goods =0, bind = Bind, trade = Trade }
		end,
    		%% 更新物品状态
    spawn(fun()->db_agent:quality_backout(NewGoodsInfo)end),	
    ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
	%%成功失败都要 删除装备属性
	NewStoneInfo = goods_util:get_new_goods(StoneTypeInfo),
	AttributeId = goods_util:get_inlay_attribute_id(NewStoneInfo),
	spawn(fun()->lib_goods:del_goods_attribute(NewGoodsInfo#goods.player_id, GoodsInfo#goods.id, 3,AttributeId)end),
	if TotalRuneNum < 3 andalso Auto_purch == 1 andalso GoldCost > 0 ->
		NewPlayerStatus1 = lib_goods:cost_money(NewPlayerStatus,GoldCost,gold,1588);
	   true ->
		NewPlayerStatus1 = NewPlayerStatus
	end,
	[Res,Rstatus,RStone_id] =
	if
		%%成功
		Ratio * 100> Ram ->
			case length(NewStatus2#goods_status.null_cells) >= 1 of
				true ->
					%%返还到背包
    				NewStatus3=
						case lib_goods:give_goods({NewStoneInfo#goods.goods_id,1,Bind},NewStatus2) of
							{fail,_,_}->NewStatus2;
							{ok,Status_0}->Status_0
						end;
				false ->
					%%通过邮件返回
					spawn(fun()->lib_goods:add_new_goods_by_mail(PlayerStatus#player.nickname,NewStoneInfo#goods.goods_id,Bind,1,"系统消息","您的背包已满,成功摘除的宝石通过邮件附件返还。")end),
					NewStatus3 = NewStatus2
			end,
			spawn(fun()->(catch log:log_backout(NewPlayerStatus, GoodsInfo,StoneTypeInfo,Ratio,Ram div 100,TotalRuneNum,Cost,1))end),
			%% 人物属性重新计算
			if GoodsInfo#goods.location == 1 ->
				   {ok, NewPlayerStatus2, NewStatus4} = goods_util:count_role_equip_attribute(NewPlayerStatus1, NewStatus3, GoodsInfo);				   
			   true ->
				   NewPlayerStatus2 = NewPlayerStatus1,
				   NewStatus4 = NewStatus3
			end,
			lib_player:send_player_attribute(NewPlayerStatus2,2),
			[1,NewStatus4,NewStoneInfo#goods.goods_id];
		true ->
			%%失败
			Fail_StoneId=GoodsInlayRune#ets_base_goods_inlay.fail_goods_id,
			if
				Fail_StoneId > 0 ->					
				  	Fail_StoneTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS,Fail_StoneId),
					Fail_StoneInfo = goods_util:get_new_goods(Fail_StoneTypeInfo),
					%%镶嵌低一级的物品
					spawn(fun()->inlay_ok(NewGoodsInfo,Fail_StoneInfo, Bind, Trade)end);				
				true ->skip
			end,
			spawn(fun()->(catch log:log_backout(NewPlayerStatus, GoodsInfo,StoneTypeInfo,Ratio,Ram div 100,TotalRuneNum,Cost,0))end),
			%% 人物属性重新计算
			if GoodsInfo#goods.location == 1 ->
				   {ok, NewPlayerStatus2, NewStatus4} = goods_util:count_role_equip_attribute(NewPlayerStatus1, NewStatus2, GoodsInfo);
			   true ->
				   NewPlayerStatus2 = NewPlayerStatus1,
				   NewStatus4 = NewStatus2
			end,
			lib_player:send_player_attribute(NewPlayerStatus2,2),
			[0,NewStatus4,Fail_StoneId]
	end,
    {ok, Res,NewPlayerStatus2,Rstatus,RStone_id}.

%%属性鉴定
identify(PlayerStatus,GoodsStatus,GoodsInfo,StoneInfo,AttributeList,GoldCost) ->	
	%%有物品先扣物品
	if is_record(StoneInfo, goods) ->
		    %% 扣掉洗炼符
		    {ok, NewGoodsStatus, NewStoneNum} = lib_goods:delete_one(GoodsStatus, StoneInfo, 1),
			NewPlayerStatus = PlayerStatus;
	   %%没有物品直接扣元宝
	   true ->
		   NewGoodsStatus = GoodsStatus,
		   NewStoneNum = 0,
		   NewPlayerStatus = lib_goods:cost_money(PlayerStatus,GoldCost,gold,1582)
	end,
	%% 绑定处理
	if 
		is_record(StoneInfo, goods) == true ->
			if StoneInfo#goods.bind == 0 -> Bind = GoodsInfo#goods.bind;
			   StoneInfo#goods.bind == 1 -> Bind = 2;
			   true ->  Bind = 2
			end;
		true ->Bind = GoodsInfo#goods.bind
	end,
	Trade = Bind div 2,
	NewGoodsInfo =
		case Bind of
			0 -> GoodsInfo;
			_ -> db_agent:bind_goods(GoodsInfo),
				 GoodsInfo#goods{bind = Bind, trade = Trade }
		end,
	ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
	%%过滤未鉴定属性
	F=fun(_Attribute)->
		if
			%% 0不可用，1可用
			_Attribute#goods_attribute.status == 0 ->
					true;
			true ->
					false
		end
	end,
	%%排序具体属性
	F2 = fun(Attribute1,_Attribute2)->
				 if
					 %%优先未鉴定的法力属性
					 Attribute1#goods_attribute.attribute_id == 2 andalso Attribute1#goods_attribute.status == 0 ->
						 true;
					 true ->
						 false
				 end
		 end,
	AttributeList2=lists:sort(F2,lists:filter(F,AttributeList)),
	[Attribute1|Attribute2]=AttributeList2,
	spawn(fun()->db_agent:identify(Attribute1#goods_attribute.id)end),
	Attribute1_new=Attribute1#goods_attribute{status = 1},
	ets:insert(?ETS_GOODS_ATTRIBUTE,Attribute1_new),
	%% 人物属性重新计算
	if GoodsInfo#goods.location == 1 ->
		   {ok, NewPlayerStatus1, NewGoodsStatus1} = goods_util:count_role_equip_attribute(NewPlayerStatus, NewGoodsStatus, GoodsInfo);
	   true ->
		   NewPlayerStatus1 = NewPlayerStatus,
		   NewGoodsStatus1 = NewGoodsStatus
	end,
	lib_player:send_player_attribute(NewPlayerStatus1,2),
	%%鉴定不对玩家属性处理。
	NewAttributeList = [Attribute1_new|Attribute2],
	{ok,NewPlayerStatus1,NewGoodsStatus1,NewStoneNum,NewAttributeList}.

%%法宝一次完成修炼
full_practise(PlayerStatus,GoodsStatus,GoodsInfo,AddAttributeList) ->
	CurGrade = GoodsInfo#goods.grade,
	CurSpirit = PlayerStatus#player.spirit,
	MaxGrade1 = GoodsInfo#goods.step * 10,
	MaxGrade2 = PlayerStatus#player.lv,
	F = fun(Grade,[ToGrade,Tspirit]) ->
				if
					Grade =< MaxGrade1  ->
						NeedSpirit = data_equip:get_spirit(Grade-1),
						if
							NeedSpirit + Tspirit =< CurSpirit ->
								[Grade,NeedSpirit + Tspirit];
							true ->
								[ToGrade ,Tspirit]
						end;
					true ->
						[ToGrade,Tspirit]
				end
		end,
	[MaxGrade,TotalNeedSpirit] = lists:foldl(F, [CurGrade,0], lists:seq(CurGrade + 1, MaxGrade2)), 
	Att_num =length(AddAttributeList),
	Pattern = #ets_base_goods_practise{att_num = Att_num,subtype = GoodsInfo#goods.subtype,step = GoodsInfo#goods.step,color = GoodsInfo#goods.color, grade = MaxGrade, _='_' },
    GoodsPractiseRule = goods_util:get_ets_info(?ETS_BASE_GOODS_PRACTISE, Pattern),
	if
		is_record(GoodsPractiseRule,ets_base_goods_practise) andalso MaxGrade > CurGrade ->
			NewGoodsInfo = GoodsInfo#goods{spirit = GoodsInfo#goods.spirit + TotalNeedSpirit,
									   grade = MaxGrade,
									   max_attack = GoodsPractiseRule#ets_base_goods_practise.max_attack,
									   min_attack = GoodsPractiseRule#ets_base_goods_practise.min_attack,
									   hit = GoodsPractiseRule#ets_base_goods_practise.hit,									  
								   	   bind =2,
								   	   other_data =''%%other_data必须重设，否则修炼后属性不改变。
									  },
			NewPlayer = PlayerStatus#player{spirit = CurSpirit - TotalNeedSpirit},
			practise_action(NewPlayer,GoodsStatus,NewGoodsInfo,GoodsPractiseRule,AddAttributeList);
		true ->
			{ok,PlayerStatus}
	end.

%%法宝单级修炼
practise(PlayerStatus,GoodsStatus,GoodsInfo,GoodsPractiseRule,AddAttributeList) ->
	%%Spirit = GoodsPractiseRule#ets_base_goods_practise.spirit,
	Spirit = data_equip:get_spirit(GoodsInfo#goods.grade),
	NewPlayer = PlayerStatus#player{spirit = PlayerStatus#player.spirit - Spirit},
	%%提升基本属性
	NewGoodsInfo = GoodsInfo#goods{spirit = GoodsInfo#goods.spirit + Spirit,
									   grade = GoodsInfo#goods.grade + 1,
									   max_attack = GoodsPractiseRule#ets_base_goods_practise.max_attack,
									   min_attack = GoodsPractiseRule#ets_base_goods_practise.min_attack,
									   hit = GoodsPractiseRule#ets_base_goods_practise.hit,									  
								   	   bind =2,
								   	   other_data =''%%other_data必须重设，否则修炼后属性不改变。
									  },
	practise_action(NewPlayer,GoodsStatus,NewGoodsInfo,GoodsPractiseRule ,AddAttributeList).

%%法宝修炼处理
practise_action(NewPlayer,GoodsStatus,NewGoodsInfo,GoodsPractiseRule ,AddAttributeList) ->
	ets:insert(?ETS_GOODS_ONLINE,NewGoodsInfo),
	spawn(fun()->db_agent:practise(NewGoodsInfo)end),
	%%提升附加属性
	F =fun(Attribute)->
			%%拿出附加的key-val
			[AttName,_Value] = goods_util:get_add_attribute_type_value(Attribute),
			%%匹配出新val
			NewValue = goods_util:get_practise_attribute_value_by_name(AttName,GoodsPractiseRule),				
			%%?DEBUG("lib_make/practise/get_name_value/~p/~p/",[AttName,NewValue]),
			spawn(fun()->lib_goods:mod_goods_attribute_by_name(Attribute,[AttName,NewValue])end)
	   end,
	lists:map(F,AddAttributeList),
	if
		GoodsStatus /= [] ->
			{ok,NewPlayerStatus,_} = goods_util:count_role_equip_attribute(NewPlayer, GoodsStatus,[]),
			lib_player:send_player_attribute(NewPlayerStatus,2);
		true ->
			NewPlayerStatus = NewPlayer
	end,
	catch(log:log_practise(NewPlayerStatus,NewGoodsInfo)),
	{ok,NewPlayerStatus}.	

%%前10级自动修炼法宝
auto_practise(PlayerStatus) ->
	F = fun(Lv,{PlayerStatus0,_}) ->
			GoodsInfo = goods_util:get_equip_fb(PlayerStatus0#player.id),
			if
				GoodsInfo#goods.id > 0 andalso GoodsInfo#goods.grade < Lv  ->
					Spirit = data_equip:get_spirit(GoodsInfo#goods.grade),
					AddAttributeList=goods_util:get_goods_attribute_list(PlayerStatus0#player.id,GoodsInfo#goods.id,1),
					Att_num =length(AddAttributeList),
					Pattern = #ets_base_goods_practise{att_num = Att_num,subtype = GoodsInfo#goods.subtype,step = GoodsInfo#goods.step,color = GoodsInfo#goods.color, grade =GoodsInfo#goods.grade + 1, _='_' },
            		GoodsPractiseRule = goods_util:get_ets_info(?ETS_BASE_GOODS_PRACTISE, Pattern),
					if
						is_record(GoodsPractiseRule,ets_base_goods_practise) andalso PlayerStatus0#player.spirit >= Spirit ->
							{ok,PlayerStatus1}=practise(PlayerStatus0,[],GoodsInfo,GoodsPractiseRule,AddAttributeList),
							{PlayerStatus1,GoodsInfo};
						true ->
							{PlayerStatus0,GoodsInfo}
					end;
				true ->
					{PlayerStatus0,[]}
			end
	end,
	%%修炼到角色等级
	{NewPlayerStatus , NewGoodsInfo} = lists:foldl(F, {PlayerStatus,[]},lists:seq(1, PlayerStatus#player.lv)),
	if
		is_record(NewGoodsInfo,goods) ->
			spawn(fun() -> pp_goods:handle(15000, NewPlayerStatus, [NewGoodsInfo#goods.id, NewGoodsInfo#goods.location]) end);
		true ->
			skip
	end,
	NewPlayerStatus.

%%法宝融合
merge(PlayerStatus,GoodsStatus,GoodsInfo1,GoodsInfo2) ->
	Spirit1 = GoodsInfo1#goods.spirit,
	Spirit2 = GoodsInfo2#goods.spirit,
	MaxSpirit = goods_util:get_total_spirit(GoodsInfo2),
	if
		Spirit1 + Spirit2 > MaxSpirit ->
			TotalSpirit = MaxSpirit,
			LeftSpirit =Spirit1 + Spirit2 - TotalSpirit;
		true ->
			TotalSpirit = Spirit1 + Spirit2,
			LeftSpirit = 0
	end,
	Grade = GoodsInfo1#goods.grade + GoodsInfo2#goods.grade,
	F = fun(G,[Grade0,Spirit_last]) ->
				S = data_equip:get_spirit(G),
				case Spirit_last >= S of
					true ->[Grade0+1,Spirit_last - S];
					false ->[Grade0,Spirit_last]
				end
		end,
	[NewGrade,_]=lists:foldl(F,[1,TotalSpirit],lists:seq(1,Grade)),
	if
		GoodsInfo1#goods.stren > GoodsInfo2#goods.stren ->
			MaxStren = GoodsInfo1#goods.stren;
		true ->
			MaxStren = GoodsInfo2#goods.stren
	end,
	if
		MaxStren >= 4 ->
			Stren = MaxStren - util:rand(1,3);
		true ->
			Stren = MaxStren
	end,
	if
		Stren >= 7 ->
			NewStrenFail = 0;
		true ->
			NewStrenFail = GoodsInfo2#goods.stren_fail
	end,
	NewGoodsInfo2=GoodsInfo2#goods{grade= NewGrade,spirit = TotalSpirit ,bind = 2,stren = Stren ,stren_fail = NewStrenFail},
	ets:insert(?ETS_GOODS_ONLINE,NewGoodsInfo2),
	%%增加修炼对应grade等级属性值
	add_practise_attribute(PlayerStatus,NewGoodsInfo2),
	%%增加强化对应等级的属性值
	add_strengthen_attribute(NewGoodsInfo2,GoodsInfo2),		
	{ok,NewGoodsStatus,_} = lib_goods:delete_one(GoodsStatus,GoodsInfo1,1),
	%%如果有剩余灵力 返回到角色
	if
		LeftSpirit > 0 ->
			NewPlayer = lib_player:add_spirit(PlayerStatus,LeftSpirit),
			db_agent:mm_update_player_info([{spirit,NewPlayer#player.spirit}], [{id,NewPlayer#player.id}]);
		true ->
			NewPlayer = PlayerStatus
	end,	
	%%hzj多删除一次内存，针对无法删除内存bug
	ets:delete(?ETS_GOODS_ONLINE,GoodsInfo1#goods.id),
	spawn(fun() -> lib_player:send_player_attribute(NewPlayer, 3) end),
	spawn(fun()->db_agent:merge(NewGoodsInfo2)end),
	spawn(fun()->catch(log:log_merge(PlayerStatus,GoodsInfo1,GoodsInfo2))end),
	if
		GoodsInfo1#goods.location == 1 ->
			MerType = 100;%%法宝在身上的融合情况
			%%{ok,NewPlayerStatus,_} = goods_util:count_role_equip_attribute(NewPlayer, NewGoodsStatus,[]),
			%%lib_player:send_player_attribute(NewPlayerStatus,2);
		true ->
			MerType = 1
	end,
	{ok,NewPlayer,NewGoodsStatus,MerType}.

%%神装练化 return NewPlayer,NewStatus,[GoodsInfo,SuitNum,AttributeList];
equip_smelt_70(Player,GoodsStatus,GoodsInfo,GoodsInfoList,JPn,MYn,HFn,Cost,Bind,Type) ->
	MS = ets:fun2ms(fun(T) when T#ets_base_goods.type == 10 andalso 
													 T#ets_base_goods.type == GoodsInfo#goods.type andalso
													 T#ets_base_goods.subtype == GoodsInfo#goods.subtype andalso										  
													 T#ets_base_goods.color == 4 andalso 
													 T#ets_base_goods.career == GoodsInfo#goods.career andalso 
													 T#ets_base_goods.level >= 70 andalso 
													 T#ets_base_goods.level < 80  ->	
			T 
		end),
	BaseGoodsList0 = ets:select(ets_base_goods,MS),
	F_filter = fun(Base) ->
					   Base#ets_base_goods.goods_id div 1000 =< 15
			   end,
	BaseGoodsList = lists:filter(F_filter, BaseGoodsList0),
	case length(BaseGoodsList)>0 of
		true ->
			TypeInfo = hd(BaseGoodsList),
			Stren = GoodsInfo#goods.stren,

			if
				HFn >0 ->
					NewStren = Stren;
				Stren > 3 ->
					Ram = util:rand(1,100),
					if
						Ram >= 90 ->
							L = 1;
						Ram >= 50 ->
							L = 2;
						true ->
							L = 3
					end,
					NewStren = Stren - L;
				true ->
					NewStren = Stren
			end,
			if
				Bind > 0 ->
					NewBind = 2;
				true ->
					NewBind = 0
			end,
			case Type of
				1 ->%%预览
					
					NewGoods = goods_util:get_new_goods(TypeInfo), 
					NewGoods2 = NewGoods#goods{id =0,player_id =0,location=4 ,cell=1 ,num = 1,stren = 100 ,bind = NewBind},
					Pattern = #ets_base_goods_add_attribute{ goods_id=NewGoods2#goods.goods_id,color=GoodsInfo#goods.color,attribute_type=11, _='_' },
            		BaseAddAttributeList = goods_util:get_ets_list(?ETS_BASE_GOODS_ADD_ATTRIBUTE, Pattern),
					F = fun(BaseAddAttribute,L) ->							
							case is_record(BaseAddAttribute,ets_base_goods_add_attribute) of
								true ->
									Attribute= goods_util:get_new_goods_add_attribute(BaseAddAttribute),
									[Attribute|L];
								false ->
									L
							end
						end,
					AttributeList = lists:foldl(F, [], BaseAddAttributeList),
					{ok,Player,GoodsStatus,[NewGoods2,0,AttributeList]};
				_ ->
					%%删除物品
					F_del = fun({Ginfo,N},Status0) ->
								{ok, _NewStatus,_} = lib_goods:delete_one(Status0, Ginfo, N),
								_NewStatus
							end,
					NewStatus0 = lists:foldl(F_del, GoodsStatus, [{GoodsInfo,1}|GoodsInfoList]),				
					{ok,NewGoodsStatus} = lib_goods:give_goods({TypeInfo#ets_base_goods.goods_id, 1 ,NewBind}, NewStatus0),
					GiveGoodsInfo = goods_util:get_new_goods_by_type(TypeInfo#ets_base_goods.goods_id,Player#player.id),
					%%处理强化效果
					NewGiveGoodsInfo = GiveGoodsInfo#goods{stren = NewStren},
					spawn(fun()->db_agent:mod_strengthen(NewStren, 0,GiveGoodsInfo#goods.id)end),
					ets:insert(?ETS_GOODS_ONLINE, NewGiveGoodsInfo),
					%%处理强化附加属性
					Att_type=goods_util:get_goods_attribute_id(NewGiveGoodsInfo#goods.subtype),
            		Pattern = #ets_base_goods_strengthen{strengthen = NewGiveGoodsInfo#goods.stren,type=Att_type, _='_' },
            		GoodsStrengthenRule = goods_util:get_ets_info(?ETS_BASE_GOODS_STRENGTHEN, Pattern),
					%%
					Step=goods_util:level_to_step(NewGiveGoodsInfo#goods.level),
					Pattern2 = #ets_base_goods_strengthen_anti{subtype=NewGiveGoodsInfo#goods.subtype,step=Step,stren=NewGiveGoodsInfo#goods.stren, _='_' },
					GoodsStrengthenAntiRule = goods_util:get_ets_info(?ETS_BASE_GOODS_STRENGTHEN_ANTI,Pattern2),
					%%先处理额外属性 提取强化属性处理
					%% 强化+7 加成 
					if
						NewStren >= 7 andalso NewGiveGoodsInfo#goods.subtype =/= 22 andalso NewGiveGoodsInfo#goods.subtype =/= 24 ->
							mod_strengthen_extra(NewGiveGoodsInfo,GoodsStrengthenRule);
						true ->
							skip
					end,
					%%如果是防具则增加抗性
					if
						NewStren > 0 andalso NewGiveGoodsInfo#goods.subtype > 13 andalso NewGiveGoodsInfo#goods.subtype /= 23  andalso NewGiveGoodsInfo#goods.subtype =/= 24->
							mod_strengthen_anti(NewGiveGoodsInfo,GoodsStrengthenAntiRule);
						true ->
							skip
					end,
					NameColor = data_agent:get_realm_color(Player#player.realm),
					AttributeList = goods_util:get_goods_attribute_list(Player#player.id, GiveGoodsInfo#goods.id),
					SuitNum = goods_util:get_suit_num(GoodsStatus#goods_status.equip_suit, GiveGoodsInfo#goods.suit_id),
					NewPlayer = lib_goods:cost_money(Player,Cost,coin,1573),
					Msg =io_lib:format("恭喜[~s]的[<a href='event:1,~p,~s,~p,~p'><font color='~s'>~s</font></a>]在炼器中成功炼化极品装备<a href ='event:2,~p,~p,1'><font color='~s'><u>~s</u></font></a>。",
											[goods_util:get_realm_to_name(Player#player.realm),Player#player.id,Player#player.nickname,Player#player.career,Player#player.sex,NameColor,Player#player.nickname,
											NewGiveGoodsInfo#goods.id,Player#player.id,goods_util:get_color_hex_value(NewGiveGoodsInfo#goods.color),TypeInfo#ets_base_goods.goods_name]),
					lib_chat:broadcast_sys_msg(2,Msg),
					spawn(fun()->log:log_equipsmelt(NewPlayer#player.id,NewPlayer#player.nickname,GoodsInfo#goods.id,GoodsInfo#goods.goods_id,JPn,MYn,HFn)end),
					{ok,NewPlayer,NewGoodsStatus,[NewGiveGoodsInfo,SuitNum,AttributeList]}
			end;
		false ->
			{fail,Player,GoodsStatus,[{},0,[]]}
	end.
	



%%法宝预览
merge_preview(PlayerStatus,GoodsInfo1,GoodsInfo2) ->
	Spirit1 = GoodsInfo1#goods.spirit,
	Spirit2 = GoodsInfo2#goods.spirit,
	MaxSpirit = goods_util:get_total_spirit(GoodsInfo2),
	if
		Spirit1 + Spirit2 > MaxSpirit ->
			TotalSpirit = MaxSpirit;
			
		true ->
			TotalSpirit = Spirit1 + Spirit2
	end,
	Grade = GoodsInfo1#goods.grade + GoodsInfo2#goods.grade,
	F = fun(G,[Grade0,Spirit_last]) ->
				S = data_equip:get_spirit(G),
				case Spirit_last >= S of
					true ->[Grade0+1,Spirit_last - S];
					false ->[Grade0,Spirit_last]
				end
		end,
	[NewGrade,_]=lists:foldl(F,[1,TotalSpirit],lists:seq(1,Grade)),
	if
		GoodsInfo1#goods.stren >= 4 ->
			Stren = GoodsInfo1#goods.stren - util:rand(1,3);
		true ->
			Stren = GoodsInfo2#goods.stren
	end,

	NewGoodsInfo2=GoodsInfo2#goods{grade= NewGrade,spirit = TotalSpirit ,bind = 2,stren = Stren},
	AddAttributeList=goods_util:get_goods_attribute_list(PlayerStatus#player.id,NewGoodsInfo2#goods.id,1),
	Att_num =length(AddAttributeList), 
	Pattern = #ets_base_goods_practise{att_num = Att_num,subtype = NewGoodsInfo2#goods.subtype,step = NewGoodsInfo2#goods.step,color = NewGoodsInfo2#goods.color, grade =NewGoodsInfo2#goods.grade , _='_' },
    GoodsPractiseRule = goods_util:get_ets_info(?ETS_BASE_GOODS_PRACTISE, Pattern),
	if
		is_record(GoodsPractiseRule,ets_base_goods_practise) ->
			%%提升基本属性
			NewGoodsInfo3 = NewGoodsInfo2#goods{
									   max_attack = GoodsPractiseRule#ets_base_goods_practise.max_attack,
									   min_attack = GoodsPractiseRule#ets_base_goods_practise.min_attack,
									   hit = GoodsPractiseRule#ets_base_goods_practise.hit,									  
								   	   other_data =''%%other_data必须重设，否则修炼后属性不改变。
									  },
			%%提升附加属性
			F2 =fun(AttributeInfo)->
					%%拿出附加的key-val
					[AttName,_Value] = goods_util:get_add_attribute_type_value(AttributeInfo),
					%%匹配出新val
					NewValue = goods_util:get_practise_attribute_value_by_name(AttName,GoodsPractiseRule),				
					case AttName of
						dodge -> AttributeInfo#goods_attribute{dodge= NewValue};
						crit -> AttributeInfo#goods_attribute{crit = NewValue};
						physique -> AttributeInfo#goods_attribute{physique = NewValue};
						forza -> AttributeInfo#goods_attribute{forza = NewValue};
						agile -> AttributeInfo#goods_attribute{agile = NewValue};
						wit -> AttributeInfo#goods_attribute{wit = NewValue};
						_ ->AttributeInfo
					end
	   		end,
			NewAttributeList = lists:map(F2,AddAttributeList),
			{ok,NewGoodsInfo3,NewAttributeList};
		true ->
			{ok,NewGoodsInfo2,AddAttributeList}
	end.

%%极品预览
super_preview(Gid) ->	
	GoodsInfo = goods_util:get_goods(Gid),
	if is_record(GoodsInfo,goods) ->
		NewGoodsInfo = GoodsInfo#goods{stren=10,stren_fail=0},
		GoodsTypeInfo = goods_util:get_goods_type(GoodsInfo#goods.goods_id),
		Type = GoodsTypeInfo#ets_base_goods.type,
		Subtype = GoodsTypeInfo#ets_base_goods.subtype,
		Step = goods_util:level_to_step(GoodsTypeInfo#ets_base_goods.level),
		Att_type = goods_util:get_goods_attribute_id(Subtype),
		Pattern = #ets_base_goods_strengthen{strengthen=10 ,type=Att_type, _='_' },
		GoodsStrengthenRule = goods_util:get_ets_info(?ETS_BASE_GOODS_STRENGTHEN, Pattern),
		%%附加属性 
 		AttributeList01 = goods_util:get_goods_attribute_list(GoodsInfo#goods.player_id, GoodsInfo#goods.id, 1),
		AttList01 = [E#goods_attribute.attribute_id || E <- AttributeList01],
		Pattern0 = #ets_base_goods_add_attribute{goods_id=GoodsInfo#goods.goods_id,color=GoodsInfo#goods.color, _='_' },
		%%获取某goods_id 物品添加的所有属性 类型值
	    AttList = goods_util:get_ets_list(?ETS_BASE_GOODS_ADD_ATTRIBUTE, Pattern0),
		ResultList = [{goods_util:get_attribute_name_by_id(Attribute#goods_attribute.attribute_id),goods_util:get_attribute_value(Attribute)}||Attribute <- AttributeList01],
		HitValue=GoodsInfo#goods.hit,
		case lists:keyfind(wit, 1, ResultList) of
				false -> WitValue = 0;
				{_, V2} ->WitValue = V2
			end,
		case lists:keyfind(agile, 1, ResultList) of
				false -> AgileValue = 0;
				{_, V3} ->AgileValue = V3
			end,
		case lists:keyfind(physique, 1, ResultList) of
				false -> PhysiqueValue = 0;
				{_, V4} ->PhysiqueValue = V4
			end,
		case lists:keyfind(forza, 1, ResultList) of
				false -> ForzaValue = 0;
				{_, V5} ->ForzaValue = V5
			end,
		F = fun(E) ->
				 Eattribute_id = E#ets_base_goods_add_attribute.attribute_id,
				 %%气血和法力有强化效果，其它属性与强化无关
				 if Eattribute_id == 1 orelse Eattribute_id == 2  ->
						{goods_util:get_attribute_name_by_id(Eattribute_id),tool:floor(E#ets_base_goods_add_attribute.value*(1 + GoodsStrengthenRule#ets_base_goods_strengthen.value / 100)),1,E#ets_base_goods_add_attribute.value_type};
					true ->
						{goods_util:get_attribute_name_by_id(Eattribute_id),tool:floor(E#ets_base_goods_add_attribute.value),1,E#ets_base_goods_add_attribute.value_type}
				 end
		 end,
		AttList0 = [F(E) || E <- AttList,lists:member(E#ets_base_goods_add_attribute.attribute_id, AttList01)],
		AttList00 = AttList0 ++ [{hit,HitValue,1,0},{wit,WitValue,1,0},{agile,AgileValue,1,0},{physique,PhysiqueValue,1,0},{forza,ForzaValue,1,0}],
		AttList1 = [{Key1,KeyValue1,PropType1,VlaueType1}||{Key1,KeyValue1,PropType1,VlaueType1} <- AttList00,KeyValue1 >0,Key1 =/= hit],
		Pattern00 = #ets_base_goods_practise{subtype = GoodsInfo#goods.subtype,step = GoodsInfo#goods.step,color = GoodsInfo#goods.color, grade = GoodsInfo#goods.grade , _='_' },
		GoodsPractiseRule = goods_util:get_ets_info(?ETS_BASE_GOODS_PRACTISE, Pattern00),
		%%原始属性[{属性key，属性值，属性类型，值类型}]
		if	Type == 10 andalso Subtype >= 9 andalso Subtype =< 13 ->%%法宝
			PrevMaxAtt = GoodsPractiseRule#ets_base_goods_practise.max_attack,
			PrevMinAtt = GoodsPractiseRule#ets_base_goods_practise.min_attack,
			Max_attack = tool:floor(PrevMaxAtt * (1 + GoodsStrengthenRule#ets_base_goods_strengthen.value / 100)),
			Min_attack = tool:floor(PrevMinAtt * (1 + GoodsStrengthenRule#ets_base_goods_strengthen.value / 100)),
			NewGoodsInfo1 = NewGoodsInfo#goods{min_attack=Min_attack,max_attack=Max_attack};
		Type == 10 andalso Subtype >= 14 andalso Subtype =< 19 ->%%防具
			Def = tool:floor(GoodsTypeInfo#ets_base_goods.def *(1 + GoodsStrengthenRule#ets_base_goods_strengthen.value / 100)),
			NewGoodsInfo1 = NewGoodsInfo#goods{def=Def};
		Type == 10 andalso Subtype == 24 ->%%时装
			Def = tool:floor(GoodsTypeInfo#ets_base_goods.def *(1 + GoodsStrengthenRule#ets_base_goods_strengthen.value / 100)),
			Hp = tool:floor(GoodsTypeInfo#ets_base_goods.hp *(1 + GoodsStrengthenRule#ets_base_goods_strengthen.value / 100)),
			NewGoodsInfo1 = NewGoodsInfo#goods{def=Def,hp=Hp};
		Type == 10 andalso Subtype == 22 ->%%坐骑
			Speed = lib_mount:get_mount_speed_by_id(GoodsInfo#goods.id,GoodsInfo#goods.other_data) + tool:floor(100 *(GoodsStrengthenRule#ets_base_goods_strengthen.value / 100)),
			NewGoodsInfo1 = NewGoodsInfo#goods{speed = Speed};
		Type == 10 andalso Subtype == 26 ->%%法宝时装
			[Max_attack,Def] = goods_util:get_goods_data_stren(GoodsInfo#goods.goods_id,10),
			NewGoodsInfo1 = NewGoodsInfo#goods{min_attack = Max_attack,max_attack = Max_attack,def = Def};
		Type == 10 andalso Subtype == 27 ->%%饰品时装
			[Hp,Anti_all] = goods_util:get_goods_data_stren(GoodsInfo#goods.goods_id,10),
			NewGoodsInfo1 = NewGoodsInfo#goods{hp = Hp,anti_wind = Anti_all, anti_thunder = Anti_all,anti_water = Anti_all, anti_fire = Anti_all, anti_soil = Anti_all};
		true ->
			NewGoodsInfo1 = NewGoodsInfo
		end,
		Pattern2 = #ets_base_goods_strengthen_anti{subtype=Subtype,step=Step,stren=10, _='_' },
		GoodsStrengthenAntiRule = goods_util:get_ets_info(?ETS_BASE_GOODS_STRENGTHEN_ANTI,Pattern2),
		Pattern3 = #ets_base_goods_strengthen_extra{level=GoodsInfo#goods.level, _='_'},
		Goods_stren_extra = goods_util:get_ets_info(?ETS_BASE_GOODS_STRENGTHEN_EXTRA,Pattern3),
		%%强化属性2,奖励属性4(气血和暴击,攻击(法宝),全抗)
	AttList2 = 	
			if Type == 10 andalso Subtype >= 9 andalso Subtype =< 13 ->%%法宝
				[?ETS_BASE_GOODS_STRENGTHEN_EXTRA,_level,_Crit7,_Crit8,_Crit9,Crit10,_Hp7,_Hp8,_Hp9,_Hp10] = tuple_to_list(Goods_stren_extra),
				[_Stren8,_Stren9,Stren10] =
				case Step of
					1 ->[5,8,10];
					2 ->[10,15,20];
					3 ->[15,23,30];
					4 ->[30,38,50];
					5 ->[35,50,70];
					6 ->[50,65,90];
					7 ->[60,80,110];
					8 ->[70,100,135];
					9 ->[85,120,165];
					10 ->[105,145,200]
				end,
				[{crit,Crit10,2,1},{max_attack,Stren10,5,0}];
			   Type == 10 andalso Subtype >= 14 andalso Subtype =< 19 ->%%防具
					[?ETS_BASE_GOODS_STRENGTHEN_EXTRA,_level,_Crit7,_Crit8,_Crit9,_Crit10,_Hp7,_Hp8,_Hp9,Hp10] = tuple_to_list(Goods_stren_extra),
					[?ETS_BASE_GOODS_STRENGTHEN_ANTI,_,_,_,_,Value] = tuple_to_list(GoodsStrengthenAntiRule),
					[{hp,Hp10,2,1},{anti_all,Value,4,0}];
			   Type == 10 andalso Subtype == 23 ->%%戒指
					[?ETS_BASE_GOODS_STRENGTHEN_EXTRA,_level,_Crit7,_Crit8,_Crit9,_Crit10,_Hp7,_Hp8,_Hp9,Hp10] = tuple_to_list(Goods_stren_extra),
					[{hp,Hp10,2,1}];
			   Type == 10 andalso Subtype == 24 ->%%时装
					[{hp,11,2,1},{anti_all,98,4,0}];
			   true ->
				   []
			end,
		%%附魔属性(防具气血和法宝攻击)
		Color = GoodsInfo#goods.color,
		if Color =< 1 -> Num = 2;
		   Color == 2 -> Num = 3;
		   Color == 3 -> Num = 4;
		   true ->	 Num = 5
		end,
		AttList3 =
			if Type == 10 andalso Subtype >= 9 andalso Subtype =< 13->%%法宝
					Max_attack1 = data_magic:get_max_value_magic(GoodsInfo#goods.level,max_attack),
					[{max_attack,Max_attack1,7,0}||_Num <- lists:seq(1, Num)];
			   Type == 10 andalso Subtype >= 14 andalso Subtype =< 19 ->%%防具
					Hp1 = data_magic:get_max_value_magic(GoodsInfo#goods.level,hp),
					[{hp,Hp1,7,0}||_Num <- lists:seq(1, Num)];
			   Type == 10 andalso Subtype == 23->%%戒指
					Max_attack1 = data_magic:get_max_value_magic(GoodsInfo#goods.level,max_attack),
					[{max_attack,Max_attack1,7,0}||_Num <- lists:seq(1, Num)];
			   Type == 10 andalso Subtype == 24 ->%%时装
					[];
			   true ->
				   []
			end,
		%%洗炼属性(气血百分比和攻击百分比，攻击最大值)
		AttList4 =
			if Type == 10 andalso Subtype == 24 ->%%时装
					Max_Att = db_agent:get_fashion_max_att(GoodsInfo#goods.goods_id),
					[{hp,5,6,1},{max_attack,5,6,1},{max_attack,Max_Att,6,0}];
			   Type == 10 andalso (Subtype == 26 orelse Subtype == 27) ->%%法宝时装
					[{hp,2,6,1},{max_attack,2,6,1},{max_attack,50,6,2}];
			   true ->
				   []
			end,
		F1 =fun({Propkey,Value,PropType,VlaueType})->
					if Propkey == anti_all ->
						   Attribute_id = 0;
					   true->
						   Attribute_id = goods_util:get_attribute_id_by_name(Propkey)
					end,
					AttributeInfo =
					case Propkey of
						def -> #goods_attribute{def=Value,attribute_type=PropType,attribute_id=Attribute_id,value_type=VlaueType,goods_id=GoodsInfo#goods.goods_id,player_id=GoodsInfo#goods.player_id};
						hp -> #goods_attribute{hp=Value,attribute_type=PropType,attribute_id=Attribute_id,value_type=VlaueType,goods_id=GoodsInfo#goods.goods_id,player_id=GoodsInfo#goods.player_id};
						max_attack -> #goods_attribute{max_attack=Value,attribute_type=PropType,attribute_id=Attribute_id,value_type=VlaueType,goods_id=GoodsInfo#goods.goods_id,player_id=GoodsInfo#goods.player_id};
						min_attack -> #goods_attribute{min_attack=Value,attribute_type=PropType,attribute_id=Attribute_id,value_type=VlaueType,goods_id=GoodsInfo#goods.goods_id,player_id=GoodsInfo#goods.player_id};
						hit -> #goods_attribute{hit=Value,attribute_type=PropType,attribute_id=Attribute_id,value_type=VlaueType,goods_id=GoodsInfo#goods.goods_id,player_id=GoodsInfo#goods.player_id};
						physique -> #goods_attribute{physique=Value,attribute_type=PropType,attribute_id=Attribute_id,value_type=VlaueType,goods_id=GoodsInfo#goods.goods_id,player_id=GoodsInfo#goods.player_id};
						forza -> #goods_attribute{forza=Value,attribute_type=PropType,attribute_id=Attribute_id,value_type=VlaueType,goods_id=GoodsInfo#goods.goods_id,player_id=GoodsInfo#goods.player_id};
						mp -> #goods_attribute{mp=Value,attribute_type=PropType,attribute_id=Attribute_id,value_type=VlaueType,goods_id=GoodsInfo#goods.goods_id,player_id=GoodsInfo#goods.player_id};
						dodge -> #goods_attribute{dodge=Value,attribute_type=PropType,attribute_id=Attribute_id,value_type=VlaueType,goods_id=GoodsInfo#goods.goods_id,player_id=GoodsInfo#goods.player_id};
						agile -> #goods_attribute{agile=Value,attribute_type=PropType,attribute_id=Attribute_id,value_type=VlaueType,goods_id=GoodsInfo#goods.goods_id,player_id=GoodsInfo#goods.player_id};
						wit -> #goods_attribute{wit=Value,attribute_type=PropType,attribute_id=Attribute_id,value_type=VlaueType,goods_id=GoodsInfo#goods.goods_id,player_id=GoodsInfo#goods.player_id};
						crit -> #goods_attribute{crit=Value,attribute_type=PropType,attribute_id=Attribute_id,value_type=VlaueType,goods_id=GoodsInfo#goods.goods_id,player_id=GoodsInfo#goods.player_id};
						anti_wind -> #goods_attribute{anti_wind=Value,attribute_type=PropType,attribute_id=Attribute_id,value_type=VlaueType,goods_id=GoodsInfo#goods.goods_id,player_id=GoodsInfo#goods.player_id};
						anti_fire -> #goods_attribute{anti_fire=Value,attribute_type=PropType,attribute_id=Attribute_id,value_type=VlaueType,goods_id=GoodsInfo#goods.goods_id,player_id=GoodsInfo#goods.player_id};
						anti_water -> #goods_attribute{anti_water=Value,attribute_type=PropType,attribute_id=Attribute_id,value_type=VlaueType,goods_id=GoodsInfo#goods.goods_id,player_id=GoodsInfo#goods.player_id};
						anti_thunder -> #goods_attribute{anti_thunder=Value,attribute_type=PropType,attribute_id=Attribute_id,value_type=VlaueType,goods_id=GoodsInfo#goods.goods_id,player_id=GoodsInfo#goods.player_id};
						anti_soil -> #goods_attribute{anti_soil=Value,attribute_type=PropType,attribute_id=Attribute_id,value_type=VlaueType,goods_id=GoodsInfo#goods.goods_id,player_id=GoodsInfo#goods.player_id};
						anti_all -> #goods_attribute{anti_wind=Value,anti_fire=Value,anti_water=Value,anti_thunder=Value,anti_soil=Value,attribute_type=PropType,attribute_id=Attribute_id,value_type=VlaueType,goods_id=GoodsInfo#goods.goods_id,player_id=GoodsInfo#goods.player_id};
						_ ->#goods_attribute{}
					end,
					AttributeInfo
			end,
		NewAttributeList = lists:map(F1,AttList1++AttList2++AttList3++AttList4),
		[NewGoodsInfo1,NewAttributeList];
	   true ->
		   [[],[]]
	end.


%%添加强化属性,用于装备融合
add_strengthen_attribute(GoodsInfo,OldGoodsInfo) ->
	if
		GoodsInfo#goods.stren >= 7 ->
			Att_type=goods_util:get_goods_attribute_id(GoodsInfo#goods.subtype),
			Pattern = #ets_base_goods_strengthen{strengthen=GoodsInfo#goods.stren + 1,type=Att_type, _='_' },
    		GoodsStrengthenRule = goods_util:get_ets_info(?ETS_BASE_GOODS_STRENGTHEN, Pattern),
			spawn(fun()->mod_strengthen_extra(GoodsInfo,GoodsStrengthenRule)end);
		true ->
			skip
	end,
	if
		GoodsInfo#goods.stren >= 8 ->
			spawn(fun()->mod_strengthen_attack_extra(GoodsInfo)end);
		true ->
			skip
	end,
	if
		OldGoodsInfo#goods.stren >=7 andalso GoodsInfo#goods.stren < 7 ->
			spawn(fun()->lib_goods:del_goods_attribute(GoodsInfo#goods.player_id,GoodsInfo#goods.id,2)end);
		true ->
			skip
	end,
	if
		OldGoodsInfo#goods.stren >=8 andalso GoodsInfo#goods.stren < 8 ->
			spawn(fun()->lib_goods:del_goods_attribute(GoodsInfo#goods.player_id,GoodsInfo#goods.id,5)end);
		true ->
			skip
	end.
		
%%添加修炼属性，用于装备融合
add_practise_attribute(PlayerStatus,GoodsInfo) ->
	AddAttributeList=goods_util:get_goods_attribute_list(PlayerStatus#player.id,GoodsInfo#goods.id,1),
	Att_num =length(AddAttributeList), 
	Pattern = #ets_base_goods_practise{att_num = Att_num,subtype = GoodsInfo#goods.subtype,step = GoodsInfo#goods.step,color = GoodsInfo#goods.color, grade =GoodsInfo#goods.grade , _='_' },
    GoodsPractiseRule = goods_util:get_ets_info(?ETS_BASE_GOODS_PRACTISE, Pattern),
	if
		is_record(GoodsPractiseRule,ets_base_goods_practise) ->
			%%提升基本属性
			NewGoodsInfo = GoodsInfo#goods{
									   max_attack = GoodsPractiseRule#ets_base_goods_practise.max_attack,
									   min_attack = GoodsPractiseRule#ets_base_goods_practise.min_attack,
									   hit = GoodsPractiseRule#ets_base_goods_practise.hit,									  
								   	   other_data =''%%other_data必须重设，否则修炼后属性不改变。
									  },
			ets:insert(?ETS_GOODS_ONLINE,NewGoodsInfo),
			spawn(fun()->db_agent:practise(NewGoodsInfo)end),
			%%提升附加属性
			AddAttributeList= goods_util:get_goods_attribute_list(PlayerStatus#player.id,GoodsInfo#goods.id,1),
			F =fun(Attribute)->
					%%拿出附加的key-val
					[AttName,_Value] = goods_util:get_add_attribute_type_value(Attribute),
					%%匹配出新val
					NewValue = goods_util:get_practise_attribute_value_by_name(AttName,GoodsPractiseRule),				
					%%?DEBUG("lib_make/practise/get_name_value/~p/~p/",[AttName,NewValue]),
					spawn(fun()->lib_goods:mod_goods_attribute_by_name(Attribute,[AttName,NewValue])end)
	   		end,
			lists:map(F,AddAttributeList),
			NewGoodsInfo;
		true ->
			GoodsInfo
	end.
%%强化信息广播
sys_strengthen_msg(Type,PlayerStatus,NewGoodsInfo,OldStrengthen) ->
	Uid = tool:to_list(PlayerStatus#player.id),
	NameColor = data_agent:get_realm_color(PlayerStatus#player.realm),
	NickName = tool:to_list(PlayerStatus#player.nickname),
	%%UserLevel = tool:to_list( PlayerStatus#player.lv),
	RealmName = goods_util:get_realm_to_name(PlayerStatus#player.realm),
	Career = tool:to_list(PlayerStatus#player.career),
	Sex = tool:to_list(PlayerStatus#player.sex),
	NewGid = tool:to_list(NewGoodsInfo#goods.id),
	NewGoodsTypeInfo = goods_util:get_goods_type(NewGoodsInfo#goods.goods_id),
	OldStrengthenName = tool:to_list(OldStrengthen + 1),
	if
		is_record(NewGoodsTypeInfo,ets_base_goods) ->
			NewGoodsName = tool:to_list(NewGoodsTypeInfo#ets_base_goods.goods_name);
		true ->
			NewGoodsName =""
	end,
	if 
		NewGoodsInfo#goods.type == 10 andalso NewGoodsInfo#goods.subtype == 22 -> %%坐骑取品质对应的颜色
			Mount =  lib_mount:get_mount(NewGoodsInfo#goods.id),
			if is_record(Mount,ets_mount) ->
				   Color = data_mount:get_skill_name_color(Mount#ets_mount.color);
			   true ->
				   Color = goods_util:get_color_hex_value(NewGoodsInfo#goods.color)
			end;
		true ->
			Color = goods_util:get_color_hex_value(NewGoodsInfo#goods.color)
	end,
	NewStrengthenName = tool:to_list(NewGoodsInfo#goods.stren),
	case Type of
		1	->
			if
				NewGoodsInfo#goods.stren =:= 10 ->
					
					%%
%%
					Msg = io_lib:format("我了个去！[<font color='#FF0000'>~s</font>]玩家[<a href='event:1,~s,~s,~s,~s'><font color='~s'>~s</font></a>]人品大爆发，竟然成功将<a href ='event:2,~s,~s,1'><font color='~s'><u>~s</u></font></a> 强化至+10！！！！！！", 
										[RealmName,Uid,NickName,Career,Sex,NameColor,NickName,NewGid,Uid,Color,NewGoodsName]);
				true ->
					Msg = io_lib:format("恭喜[<font color='#FF0000'>~s</font>]玩家[<a href='event:1,~s,~s,~s,~s'><font color='~s'>~s</font></a>]在炼器处成功将<a href ='event:2,~s,~s,1'><font color='~s'><u>~s</u></font></a>强化至+~s", 
										[RealmName,Uid,NickName,Career,Sex,NameColor,NickName,NewGid,Uid,Color,NewGoodsName,NewStrengthenName])
			end;
		2 	->
			if
				OldStrengthen == NewGoodsInfo#goods.stren andalso (OldStrengthen == 6  orelse OldStrengthen == 7 orelse OldStrengthen == 8)->
					Msg = io_lib:format("[<font color='#FF0000'>~s</font>]玩家[<a href='event:1,~s,~s,~s,~s'><font color='#FEDB4F'>~s</font></a>]强化<a href ='event:2,~s,~s,1'><font color='~s'><u>~s</u></font></a> +~p时失败，幸好用了保护符，装备不降级。", 
										[RealmName,Uid,NickName,Career,Sex,NickName,NewGid,Uid,	Color,NewGoodsName,OldStrengthen+1]);
				OldStrengthen == NewGoodsInfo#goods.stren andalso OldStrengthen == 9 ->
					Msg = io_lib:format("杯具啊！[<font color='#FF0000'>~s</font>]玩家[<a href='event:1,~s,~s,~s,~s'><font color='~s'>~s</font></a>]强化<a href ='event:2,~s,~s,1'><font color='~s'><u>~s</u></font></a> +10时失败，不幸中的万幸用了保护符，装备不降级。", 
										[RealmName,Uid,NickName,Career,Sex,NameColor,NickName,NewGid,Uid,Color,NewGoodsName]);
				OldStrengthen =:= 9 ->
					Msg = io_lib:format("杯具啊！[<font color='#FF0000'>~s</font>]玩家[<a href='event:1,~s,~s,~s,~s'><font color='~s'>~s</font></a>]强化<a href ='event:2,~s,~s,1'><font color='~s'><u>~s</u></font></a> +10时失败，降为 +~s！",
										[RealmName,Uid,NickName,Career,Sex,NameColor,NickName,NewGid,Uid,Color,NewGoodsName,NewStrengthenName]);
				true ->
					Msg = io_lib:format("真是太遗憾了，[<font color='#FF0000'>~s</font>]玩家[<a href='event:1,~s,~s,~s,~s'><font color='~s'>~s</font></a>]强化 <a href ='event:2,~s,~s,1'><font color='~s'><u>~s</u></font></a> +~s时失败，降为 +~s！", 
										[RealmName,Uid,NickName,Career,Sex,NameColor,NickName,NewGid,Uid,Color,NewGoodsName,OldStrengthenName,NewStrengthenName])
			end;
		_	->
			Msg =""
	end,
	lib_chat:broadcast_sys_msg(2,Msg).

%% 紫装融合
suit_merge(PlayerStatus,GoodsStatus,GoodsInfo1,GoodsInfo2,GoodsInfo3,Cost) ->
	Suit_id = GoodsInfo1#goods.suit_id,
	Pattern = #ets_base_goods{suit_id = Suit_id,subtype= GoodsInfo3#goods.subtype,_='_'},
	GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS,Pattern),
	if
		is_record(GoodsTypeInfo,ets_base_goods) ->
			{ok,GoodsStatus1,_} = lib_goods:delete_one(GoodsStatus,GoodsInfo1,1),
			{ok,GoodsStatus2,_} = lib_goods:delete_one(GoodsStatus1,GoodsInfo2,1),
			{ok,GoodsStatus3,_} = lib_goods:delete_one(GoodsStatus2,GoodsInfo3,1),
			GoodsInfo = goods_util:get_new_goods(GoodsTypeInfo),
			if
				GoodsInfo1#goods.bind > 0 orelse GoodsInfo2#goods.bind > 0 orelse GoodsInfo3#goods.bind > 0 ->
					Bind = 2;
				true ->
					Bind = 0
			end,
			NewGoodsInfo = GoodsInfo#goods{bind = Bind},
			{ok,GoodsStatus4}=lib_goods:add_goods_base(GoodsStatus3, GoodsTypeInfo, 1, NewGoodsInfo),
			NewPlayerStatus = lib_goods:cost_money(PlayerStatus, Cost, coin,1557),
			%%日志
			spawn(fun()-> log:log_suitmerge(PlayerStatus,GoodsInfo1,GoodsInfo2,GoodsInfo3,Suit_id,Cost)end),
			{ok,1,NewPlayerStatus,GoodsStatus4};
		true ->
			{ok,6,PlayerStatus,GoodsStatus}
	end.

%% 紫装融合预览
suit_merge_preview(GoodsInfo1,GoodsInfo2,GoodsInfo3) ->
	Suit_id = GoodsInfo1#goods.suit_id,
	Pattern = #ets_base_goods{suit_id = Suit_id,subtype= GoodsInfo3#goods.subtype,_='_'},
	GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS,Pattern),
	if
		is_record(GoodsTypeInfo,ets_base_goods) ->
			GoodsInfo = goods_util:get_new_goods(GoodsTypeInfo),
			if
				GoodsInfo1#goods.bind > 0 orelse GoodsInfo2#goods.bind > 0 orelse GoodsInfo3#goods.bind > 0 ->
					Bind = 2;
				true ->
					Bind = 0
			end,
			NewGoodsInfo = GoodsInfo#goods{id = 0 ,player_id = 0,location = 4,cell = 1,num = 1,bind = Bind},
			Pattern2 = #ets_base_goods_add_attribute{ goods_id=NewGoodsInfo#goods.goods_id,color=NewGoodsInfo#goods.color,attribute_type=11, _='_' },
            %%获取某goods_id 物品添加的所有属性 类型值
            BaseAddAttributeList= goods_util:get_ets_list(?ETS_BASE_GOODS_ADD_ATTRIBUTE, Pattern2),
			F = fun(BaseAddAttribute,Att_list) ->
				if
					is_record(BaseAddAttribute,ets_base_goods_add_attribute) ->
						AttributeList = goods_util:get_new_goods_add_attribute(BaseAddAttribute),
						[AttributeList|Att_list];
					true ->
						Att_list
				end
			end,
			AddAttributeList = lists:foldl(F, [], BaseAddAttributeList),
			{ok,NewGoodsInfo,AddAttributeList};
		true ->
			{fail}
	end.

%% 60,70套紫装淬炼
smelt(PlayerStatus,GoodsStatus,GoodsInfo,GoodsInfoList,Cost) ->
	if
		%%五彩仙玉碎片
		GoodsInfo#goods.goods_id == 21600 ->
			F = fun(Ginfo,R) ->
						Step  = goods_util:level_to_step(Ginfo#goods.level),
						[Lv,Lan,Jin,Zi] =
						case Step of
							3 -> [1,2,10,0];
							4 -> [1,2,10,84];
							5 -> [1,3,15,167];
							6 -> [1,4,25,333];
							_ -> [0,0,0,0]
						end,
						Value =
						case Ginfo#goods.color of
							1 -> Lv ;
							2 -> Lan ;
							3 -> 
								trunc(Jin * (util:rand(90,110)/100)) ;
							4 -> 
								trunc(Zi * (util:rand(90,100)/100)) ;
							_ -> 0 
						end,
						%%紫色戒指数值减半
						if
							Ginfo#goods.subtype == 23 ->
								tool:floor(Value /2) +  R;
							true ->
								Value + R
						end
				end,
			AddRepair = lists:foldl(F, 0, GoodsInfoList);
		%%玄界仙玉碎片
		GoodsInfo#goods.goods_id == 21602 ->
			RepairN = goods_util:get_goods_totalnum(GoodsInfoList),
			AddRepair = RepairN * 100;
		true ->
			AddRepair = 0
	end,
	%%获取物品id goods_id列表，用于写log
	F_get = fun(Ginfo,[_Gid_list,_Goods_id_list]) ->
					[[Ginfo#goods.id|_Gid_list],[Ginfo#goods.goods_id|_Goods_id_list]]
			end,
	[Gid_list,Goods_id_list] = lists:foldl(F_get, [[],[]], GoodsInfoList),
	%%删除物品列表
	F_del = fun(GinfoDel, Status0) ->
		{ok, _NewStatus,_} = lib_goods:delete_one(Status0, GinfoDel, 1),
		_NewStatus
	end,
	GoodsStatus2 = lists:foldl(F_del, GoodsStatus,GoodsInfoList),
	NewPlayerStatus = lib_goods:cost_money(PlayerStatus, Cost, coin,1563),
	NewRepair = GoodsInfo#goods.spirit + AddRepair,
	%%如果精石有绑定，碎片需要绑定
	Bind =
	if 
		GoodsInfo#goods.goods_id == 21602 ->
			F_Bind = fun(Ginfo_bind,B) ->
					B + Ginfo_bind#goods.bind
				end,
			HadBind = lists:foldl(F_Bind, 0, GoodsInfoList),
			if
				HadBind > 0 ->
					2;
				true ->
					0
			end;
		true ->
			GoodsInfo#goods.bind
	end,
	if
		GoodsInfo#goods.goods_id == 21600 andalso NewRepair >= 1000 -> %%五彩仙玉碎片
			{ok,GoodsStatus3,_} = lib_goods:delete_one(GoodsStatus2,GoodsInfo,1),
			{ok,NewGoodsStatus} = lib_goods:give_goods({21601, 1 ,Bind}, GoodsStatus3);
		GoodsInfo#goods.goods_id == 21602 andalso NewRepair >= 300 -> %%玄界仙玉碎片
			{ok,GoodsStatus3,_} = lib_goods:delete_one(GoodsStatus2,GoodsInfo,1),
			{ok,NewGoodsStatus} = lib_goods:give_goods({21603, 1 ,Bind}, GoodsStatus3);
		true ->		
			NewGoodsInfo = GoodsInfo#goods{spirit = NewRepair ,bind = Bind},
			ets:insert(?ETS_GOODS_ONLINE,NewGoodsInfo),
			db_agent:update_goods([{spirit,NewRepair},{bind,Bind}],[{id,NewGoodsInfo#goods.id}]),
			NewGoodsStatus = GoodsStatus2
	end, 
	spawn(fun()->log:log_smelt(NewPlayerStatus,GoodsInfo,util:term_to_string(list_to_tuple(Gid_list)),util:term_to_string(list_to_tuple(Goods_id_list)),NewRepair)end),
	{ok,NewRepair,NewPlayerStatus,NewGoodsStatus}.

%% 时装洗炼Oper为预览(1),洗炼(2)
fashion_wash(PlayerStatus,GoodsStatus,GoodsInfo,StoneInfo,Oper,StoneTypeId,Auto_purch,GoldCost) ->
	%%查询该时装已经洗炼且未替换的属性
	ProsList = goods_util:get_fashion_unreplace(GoodsInfo),
	%%查询该时装原有属性
	Goods_attributList = goods_util:get_equip_attribute(GoodsInfo,6),
	Cost = 
		if is_record(StoneInfo,goods) == true andalso StoneInfo#goods.goods_id == 21800 ->
			   1500;
		   is_record(StoneInfo,goods) == true andalso StoneInfo#goods.goods_id == 21801 ->
			   3000;
		   true ->
			   if StoneTypeId == 21800 ->
					1500;
				 StoneTypeId == 21801 ->
					3000;
				  true ->
					3000
			   end
		end,
	case ProsList == [] of 
		%%如果没有未替换的属性
		true ->
			%%没有洗炼石
			if Auto_purch == 0 andalso is_record(StoneInfo,goods) == false ->
					{ok,GoodsInfo#goods.id,0,0,PlayerStatus#player.coin,PlayerStatus#player.bcoin,Goods_attributList,PlayerStatus,GoodsStatus} ;
				%%有洗炼石
				true -> 
				       if (PlayerStatus#player.coin + PlayerStatus#player.bcoin) < Cost ->
							  {fail,GoodsInfo#goods.id,0,Cost,PlayerStatus#player.coin,PlayerStatus#player.bcoin,Goods_attributList,PlayerStatus,GoodsStatus};%%铜币不足
						  true ->
							  %%洗炼动作
							  case Oper == 2 of
								  true ->
									 %%扣除洗炼费
									 NewPlayerStatus = lib_goods:cost_money(PlayerStatus, Cost, coin,1563),
									 if is_record(StoneInfo,goods) == true ->
											%%删除洗炼石
									 		 {ok,GoodsStatus1,_} = lib_goods:delete_one(GoodsStatus,StoneInfo,1),
											 NewPlayerStatus1 = NewPlayerStatus,
											 %%计算洗炼后属性随机值
											 Key = lists:concat([GoodsInfo#goods.id, StoneInfo#goods.id]);
										true ->
											%%扣购买洗炼石所用元宝
									 		 GoodsStatus1 = GoodsStatus,
											 NewPlayerStatus1 = lib_goods:cost_money(NewPlayerStatus,GoldCost,gold,1584),
											 %%计算洗炼后属性随机值
											 Key = lists:concat([GoodsInfo#goods.id, StoneTypeId])
										end,
									  
									  Goods_attributList1 = 
										  %%从字典中取预览属性
										  case get(Key) of
											  undefined ->
												if is_record(StoneInfo,goods) == true ->
														goods_util:get_fashion_random(PlayerStatus#player.career,GoodsInfo#goods.goods_id, StoneInfo#goods.goods_id);
													true ->
														goods_util:get_fashion_random(PlayerStatus#player.career,GoodsInfo#goods.goods_id, StoneTypeId)
													end;
											  Goods_attributList2 ->
												  erlang:erase(Key),
												  Goods_attributList2
										  end,
										lib_player:send_player_attribute(NewPlayerStatus1,2),
									  %%记录洗炼日志
									  if is_record(StoneInfo,goods) == true ->
											spawn(fun()-> log:log_fashion(PlayerStatus#player.id,GoodsInfo#goods.id,StoneInfo#goods.id,util:term_to_string(Goods_attributList),util:term_to_string(Goods_attributList1),Cost)end);
										true ->
											spawn(fun()-> log:log_fashion(PlayerStatus#player.id,GoodsInfo#goods.id,StoneTypeId,util:term_to_string(Goods_attributList),util:term_to_string(Goods_attributList1),Cost)end)
										end,
									  {ok,GoodsInfo#goods.id,1,0,NewPlayerStatus1#player.coin,NewPlayerStatus1#player.bcoin,Goods_attributList1,NewPlayerStatus1,GoodsStatus1};
								  %%预览动作
								  false ->
									  if is_record(StoneInfo,goods) == true ->
											Goods_attributList1 = goods_util:get_fashion_random(PlayerStatus#player.career,GoodsInfo#goods.goods_id, StoneInfo#goods.goods_id),
											%%计算洗炼后属性随机值
											Key = lists:concat([GoodsInfo#goods.id, StoneInfo#goods.id]);
										true ->
											Goods_attributList1 = goods_util:get_fashion_random(PlayerStatus#player.career,GoodsInfo#goods.goods_id, StoneTypeId),
											%%计算洗炼后属性随机值
											Key = lists:concat([GoodsInfo#goods.id, StoneTypeId])
										end,
									  %%将预览属性存放到字典中
									  put(Key ,Goods_attributList1),
									  {ok,GoodsInfo#goods.id,0,Cost,PlayerStatus#player.coin,PlayerStatus#player.bcoin,Goods_attributList1,PlayerStatus,GoodsStatus}
							  end
					   end
			end;
		%%如果有未替换的属性 
		false ->
			[_LogId,_Old_pro,New_pro] = ProsList,
			New_pro1 = util:string_to_term(tool:to_list(New_pro)),
			{ok,GoodsInfo#goods.id,1,0,PlayerStatus#player.coin,PlayerStatus#player.bcoin,New_pro1,PlayerStatus,GoodsStatus} 
	end.

%%Oper替换新的洗炼属性(1)或维持原有属性(0)
fashion_oper(PlayerStatus,GoodsStatus,GoodsInfo,Oper) ->
	%%查询该时装已经洗炼且未替换的属性
	ProsList = goods_util:get_fashion_unreplace(GoodsInfo),
	%%查询该时装原有已经洗炼出的属性
	Goods_attributList = goods_util:get_equip_attribute(GoodsInfo,6),
	case ProsList == [] of
		true ->
			[Goods_attributList,PlayerStatus,GoodsStatus];
		false ->
			[LogId, _OldPro,NewPro] = ProsList,
			if Oper == 0 ->
				   %%维持原有属性
				   db_agent:update_log_fashion(0,LogId),
				   [Goods_attributList,PlayerStatus,GoodsStatus];
			   Oper == 1 ->
				   %%替换新的洗炼属性 util:string_to_term(A)
				   db_agent:update_log_fashion(2,LogId),
				   NewProList = util:string_to_term(tool:to_list(NewPro)),
				   %%删除goods_attribut中的对应数据，并产生新的数据
				   %%防止删除生成的新属性，重新查询并根据id删除属性
				   %%goods_util:delete_goods_attribute(GoodsInfo#goods.player_id, GoodsInfo#goods.id, 6),
				   OldPropList = goods_util:get_goods_attribute_list(GoodsInfo#goods.player_id, GoodsInfo#goods.id, 6),
				   if OldPropList =/= [] ->
						  [lib_goods:del_goods_attribute(OldGoodsAttribute#goods_attribute.id) ||OldGoodsAttribute <- OldPropList];
					  true ->
						  skip
				   end,
				   F = fun(Prop,Value) ->
							   %%属性显示的是数字还是百分比(0数字,1百分比)anti_all
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
								   if Prop =/= anti_all ->	goods_util:get_attribute_id_by_name(Prop1);
									  true -> 	0 %%表示全抗
								   end,
							   Goods_attribute1 = 
								   case Prop1 of
									   crit ->   #goods_attribute{crit = Value};
									   dodge -> #goods_attribute{dodge = Value};
									   hit -> #goods_attribute{hit = Value};
									   mp -> #goods_attribute{mp = Value};
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
									   anti_all -> #goods_attribute{anti_wind = Value,anti_water =  Value,anti_thunder = Value,anti_fire =  Value,anti_soil =  Value};
									   _Key ->?WARNING_MSG("_Key wash fashion : ~p/~n",[_Key]),#goods_attribute{}
								   end,
							   Goods_id = GoodsInfo#goods.goods_id,
							   Def = 0,
							   Effect = 
								   case Attribute_id =/= 0 of
									   true ->
										   [Goods_id,Goods_attribute1#goods_attribute.hp, Goods_attribute1#goods_attribute.mp, Goods_attribute1#goods_attribute.max_attack,Goods_attribute1#goods_attribute.min_attack, Def,
											Goods_attribute1#goods_attribute.hit, Goods_attribute1#goods_attribute.dodge, Goods_attribute1#goods_attribute.crit,Goods_attribute1#goods_attribute.physique, Goods_attribute1#goods_attribute.anti_wind,Goods_attribute1#goods_attribute.anti_fire,
											Goods_attribute1#goods_attribute.anti_water,Goods_attribute1#goods_attribute.anti_thunder,Goods_attribute1#goods_attribute.anti_soil,Goods_attribute1#goods_attribute.forza,Goods_attribute1#goods_attribute.agile,Goods_attribute1#goods_attribute.wit];
									   false -> %%全抗 
										   [Goods_id,Goods_attribute1#goods_attribute.hp, Goods_attribute1#goods_attribute.mp, Goods_attribute1#goods_attribute.max_attack,Goods_attribute1#goods_attribute.min_attack, Def,
											Goods_attribute1#goods_attribute.hit, Goods_attribute1#goods_attribute.dodge, Goods_attribute1#goods_attribute.crit,Goods_attribute1#goods_attribute.physique, Value,Value,
											Value,Value,Value,Goods_attribute1#goods_attribute.forza,Goods_attribute1#goods_attribute.agile,Goods_attribute1#goods_attribute.wit]
								   end,
							   lib_goods:add_goods_attribute(GoodsInfo,6,Attribute_id,Effect,ValueType)
					   end,
				   [F(Prop,Value)|| {Prop,Value} <- NewProList],	
				   %% 人物属性重新计算
				   if GoodsInfo#goods.location == 1 ->
						  {ok, NewPlayerStatus, NewGoodsStatus} = goods_util:count_role_equip_attribute(PlayerStatus, GoodsStatus, GoodsInfo);
					  true ->
						  NewPlayerStatus = PlayerStatus,
						  NewGoodsStatus = GoodsStatus
				   end,
				   lib_player:send_player_attribute(NewPlayerStatus,2),
				   [NewProList,NewPlayerStatus,NewGoodsStatus];
			   true ->
				   [Goods_attributList,PlayerStatus,GoodsStatus]
			end
	end	.
	
%%紫戒指祝福Oper为1是祝福,2是遗弃
ring_bless(PlayerStatus, GoodsStatus, GoodsInfo, NewClassOrMagicInfoList, Cost, Oper) ->
    NewPlayerStatus = lib_goods:cost_money(PlayerStatus, Cost, coin,1565),
    F = fun({ClassOrMagicInfo, ClassOrMagicIdNum}, _Status) ->
            {ok, _NewStatus, _} = lib_goods:delete_one(_Status, ClassOrMagicInfo, ClassOrMagicIdNum),
            _NewStatus
         end,
    Status2 = lists:foldl(F, GoodsStatus, NewClassOrMagicInfoList),
	if Oper ==  1 ->
		   %%祝福
		   Bless_level = GoodsInfo#goods.bless_level+1,
		   Bless_skill = 
			   case (GoodsInfo#goods.bless_level == 0 orelse GoodsInfo#goods.bless_level == undefined) of
				   %%还没有过祝福等级,随机产生一个技能
				   true ->
					   [BlessType] = util:get_random_list(data_ring_bless:get_ring_bless_type(),1),
					   Bless_skill1 = data_ring_bless:get_ring_bless_type_skill(BlessType),
					   Bless_skill1;
				   %%有祝福等级 
				   false ->
					   Bless_skill1 = GoodsInfo#goods.bless_skill,
					   Bless_skill1
			   end,
		    spawn(fun()->db_agent:ring_bless(Bless_level, Bless_skill, GoodsInfo#goods.id)end),
    		NewGoodsInfo = GoodsInfo#goods{bless_level = Bless_level, bless_skill = Bless_skill},
   			ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo);
	   true -> 
		   %%遗弃
		   Bless_level = 0,
		   Bless_skill = 0,
		   spawn(fun()->db_agent:ring_bless(Bless_level, Bless_skill, GoodsInfo#goods.id)end),
    	   NewGoodsInfo = GoodsInfo#goods{bless_level = Bless_level, bless_skill = Bless_skill},
   		   ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo)
	end,
    {ok, 1, NewPlayerStatus, Status2}.

%%装备附魔或回光 Oper 1为附魔,2为预览
make_equip_magic(PlayerStatus,GoodsStatus,GoodsInfo,MagicStoneInfo,MagicStoneTypeId,GoldCost,Oper,NewProps,Num,TotalNum,GoldCost1) ->
	%%查询该时装已经洗炼且未替换的属性
	ProsList = goods_util:get_equip_unreplace(GoodsInfo),
	%%查询该装备原有已经洗炼出的属性
	Goods_attributList = goods_util:get_equip_attribute(GoodsInfo,7),
	Cost = 
		if 
			%%绿色附魔石费用
			is_record(MagicStoneInfo,goods) == true  andalso MagicStoneInfo#goods.goods_id == 21020->
			   50;
			%%蓝色附魔石费用		    
			is_record(MagicStoneInfo,goods) == true  andalso MagicStoneInfo#goods.goods_id == 21021->
			   100;
			%%金色附魔石费用
			is_record(MagicStoneInfo,goods) == true  andalso MagicStoneInfo#goods.goods_id == 21022->
			   200;
			%%紫色附魔石费用
		    is_record(MagicStoneInfo,goods) == true  andalso MagicStoneInfo#goods.goods_id == 21023->
			   500;
			%%回光石不需要费用
		    is_record(MagicStoneInfo,goods) == true  andalso MagicStoneInfo#goods.goods_id == 21025->
			   0;
		true ->
			if MagicStoneTypeId == 21020->
			     50;
			%%蓝色附魔石费用		    
			MagicStoneTypeId == 21021->
			   100;
			%%金色附魔石费用
			MagicStoneTypeId == 21022->
			   200;
			%%紫色附魔石费用
		    MagicStoneTypeId == 21023->
			   500;
			%%回光石不需要费用
		   MagicStoneTypeId == 21025 ->
			   0;
			true ->
				50000000
			end
	end,
	case Oper == 1 of 
		%%如果没有未替换的属性
		true ->
			if (PlayerStatus#player.coin + PlayerStatus#player.bcoin) < Cost ->
				   {fail1,GoodsInfo#goods.id,0,Cost,PlayerStatus#player.coin,PlayerStatus#player.bcoin,Goods_attributList,PlayerStatus,GoodsStatus};%%铜币不足
			   true ->
				   %%扣除附魔费用
				   NewPlayerStatus = lib_goods:cost_money(PlayerStatus, Cost, coin, 1566),
				   if is_record(MagicStoneInfo,goods) andalso MagicStoneInfo#goods.bind == 2 ->
						  Is_Bind = 2;
					  true ->
						  Is_Bind = 0
				   end,
					%%删除附魔锁
				   if  Num > 0 ->
							if TotalNum >= Num ->
									gen_server:cast(PlayerStatus#player.other#player_other.pid_goods, {'DELETE_MORE_BIND_PRIOR', 21026, Num}),
									NewPlayerStatus0 = NewPlayerStatus;
					   			true ->
									gen_server:cast(PlayerStatus#player.other#player_other.pid_goods, {'DELETE_MORE_BIND_PRIOR', 21026, TotalNum}),
									NewPlayerStatus0 = lib_goods:cost_money(NewPlayerStatus,GoldCost1*(Num-TotalNum),gold,1581)
								end;
					  true ->
							NewPlayerStatus0 = NewPlayerStatus
					end,
				   %%有附魔石直接扣附魔石
				   if is_record(MagicStoneInfo, goods) ->
						  {ok,GoodsStatus1,_} = lib_goods:delete_one(GoodsStatus,MagicStoneInfo,1),
						  NewPlayerStatus1 = NewPlayerStatus0,
						  NewMagicStoneInfoId = MagicStoneInfo#goods.goods_id,
						  Goods_attributList1 = goods_util:get_magic_random(GoodsInfo#goods.level,GoodsInfo#goods.subtype,GoodsInfo#goods.career,MagicStoneInfo#goods.goods_id);
					  %%无附魔石扣元宝
					  true ->
						  GoodsStatus1 = GoodsStatus,
						  NewPlayerStatus1 = lib_goods:cost_money(NewPlayerStatus0,GoldCost,gold,1581),
						  NewMagicStoneInfoId = MagicStoneTypeId,
						  Goods_attributList1 = goods_util:get_magic_random(GoodsInfo#goods.level,GoodsInfo#goods.subtype,GoodsInfo#goods.career,MagicStoneTypeId)
				   end,
				   PropListLen1 = length(Goods_attributList1),
				   if PropListLen1 =< Num -> 
						  Goods_attributList2 = NewProps; 
					  true ->	 
						  Goods_attributList2 = NewProps ++ lists:sublist(Goods_attributList1, (PropListLen1-Num))   
				   end,
				   %%最多属性条数
				   if GoodsInfo#goods.color =< 3 ->
						Maxprops = 4;
					  true ->
						Maxprops = 5
					end,
				   Goods_attributList3 = lists:sublist(Goods_attributList2, Maxprops),
				   lib_player:send_player_attribute(NewPlayerStatus1,2),
				   %%记录洗炼日志
				   spawn(fun()-> log:log_magic(PlayerStatus#player.id,GoodsInfo#goods.id,GoodsInfo#goods.goods_id,NewMagicStoneInfoId,util:term_to_string(Goods_attributList),util:term_to_string(Goods_attributList3),Is_Bind,Cost,1)end),
				   {ok,GoodsInfo#goods.id,0,0,NewPlayerStatus1#player.coin,NewPlayerStatus1#player.bcoin,Goods_attributList2,NewPlayerStatus1,GoodsStatus1}
			end;
		%%预览
		false ->
			if ProsList == [] ->
				   {ok,GoodsInfo#goods.id,0,Cost,PlayerStatus#player.coin,PlayerStatus#player.bcoin,[],PlayerStatus,GoodsStatus};
			   true ->
				   [_LogId,New_pro,_Is_bind] = ProsList,
				   New_pro1 = util:string_to_term(tool:to_list(New_pro)),
				   {ok,GoodsInfo#goods.id,1,0,PlayerStatus#player.coin,PlayerStatus#player.bcoin,New_pro1,PlayerStatus,GoodsStatus}
			end
	end.
	

%%Oper替换新的附魔属性(1)或维持原有属性(0)
magic_oper(PlayerStatus,GoodsStatus,GoodsInfo,Oper) ->
	%%查询该时装已经洗炼且未替换的属性
	ProsList = goods_util:get_equip_unreplace(GoodsInfo),
	case ProsList == [] of
		true ->
			[1,PlayerStatus,GoodsStatus];
		false ->
			[LogId, NewPro, Is_bind] = ProsList,
			if Oper == 0 ->
				   %%维持原有属性
				   db_agent:update_log_magic(0,LogId),
				   [1,PlayerStatus,GoodsStatus];
			   true ->
				   %%替换新的洗炼属性 util:string_to_term(A)
				   db_agent:update_log_magic(2,LogId),
				   NewProList = util:string_to_term(tool:to_list(NewPro)),
				   %%删除goods_attribut中的对应数据，并产生新的数据
				   %%防止删除生成的新属性，重新查询并根据id删除属性
				   OldPropList = goods_util:get_goods_attribute_list(GoodsInfo#goods.player_id, GoodsInfo#goods.id, 7),
				   if OldPropList =/= [] ->
						  [lib_goods:del_goods_attribute(OldGoodsAttribute#goods_attribute.id) ||OldGoodsAttribute <- OldPropList];
					  true ->
						  skip
				   end,
				   %%生成新的属性
				   goods_util:general_magic_prop(GoodsInfo,NewProList),
				   %%附魔后是否绑定
				   if 
					  GoodsInfo#goods.bind  =/= 2 andalso Is_bind == 2 -> 
						   lib_goods:bind_goods(GoodsInfo);
					   true -> 
						   skip
				   end,   
				   %%附魔任务接口
				   lib_task:event(magic,null,PlayerStatus),
				   %% 人物属性重新计算
				   if GoodsInfo#goods.location == 1 ->
						{ok, NewPlayerStatus, GoodsStatus1} = goods_util:count_role_equip_attribute(PlayerStatus, GoodsStatus, GoodsInfo);						
					true ->
						NewPlayerStatus = PlayerStatus,
						GoodsStatus1 = GoodsStatus
					end,
				   lib_player:send_player_attribute(NewPlayerStatus,2),
				   [1,NewPlayerStatus,GoodsStatus1]
			end
	end	.
	
	
	





