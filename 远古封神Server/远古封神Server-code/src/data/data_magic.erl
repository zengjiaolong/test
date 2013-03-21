%%%---------------------------------------
%%% @Module  : data_mgaic
%%% @Author  : ygfs
%%% @Created : 2011-08-8 17:39:59
%%% @Description:  装备附魔配置
%%%---------------------------------------

-module(data_magic).
-compile(export_all).
-include("common.hrl").
-include("record.hrl").


%%随机装备附魔属性
get_magic_prop(Goods_Level,Goods_Subtype,Goods_Career,MagicId) ->
	Step = 
		if Goods_Level >= 0  andalso Goods_Level  < 30  -> 1;
		   Goods_Level >= 30 andalso Goods_Level < 40  -> 2;
		   Goods_Level >= 40 andalso Goods_Level < 50  -> 3;
		   Goods_Level >= 50 andalso Goods_Level < 60  -> 4;
		   Goods_Level >= 60 andalso Goods_Level < 70  -> 5;
		   Goods_Level >= 70 andalso Goods_Level < 80  -> 6;
		   Goods_Level >= 80 andalso Goods_Level < 90  -> 7;
		   Goods_Level >= 90 andalso Goods_Level < 100  -> 8;
		   true -> 0
		end,
	PropNum = 
		if 
			%%绿色附魔出两种属性
			MagicId == 21020 ->
				[Num] = util:get_random_list_probability([{1,50},{2,50}],1),
				Num;
			%%蓝色附魔石出三种属性
		   MagicId == 21021 ->
			   [Num] = util:get_random_list_probability([{1,35},{2,35},{3,30}],1),
			   Num;
			%%金色附魔石出四种属性
		    MagicId == 21022 ->
			   [Num] = util:get_random_list_probability([{2,35},{3,35},{4,30}],1),
			   Num;
		   %%紫色附魔石出五种属性
		    MagicId == 21023 ->
			   [Num] = util:get_random_list_probability([{2,30},{3,25},{4,25},{5,20}],1),
			   Num;
			%%其它情况出一种属性
			true ->
				0
		end,
		loop_prop(Step,Goods_Subtype,Goods_Career,lists:seq(1,PropNum), []).

%%根据等级，子类型，职业，附魔石的类型洗出指定数量的属性
loop_prop(_Step,_Goods_Subtype,_Goods_Career,[], NewPropList) ->
	NewPropList;
loop_prop(Step,Goods_Subtype,Goods_Career,[Num | Rest], NewPropList) ->
	Pattern = #ets_base_magic{step=Step,pack=Num,_='_'},
	PropList = ets:match_object(?ETS_BASE_MAGIC, Pattern),
 	PropList1 = [[util:string_to_term(tool:to_list(Ets_base_magic#ets_base_magic.prop)),Ets_base_magic#ets_base_magic.ratio,Ets_base_magic#ets_base_magic.max_value,Ets_base_magic#ets_base_magic.min_value] || Ets_base_magic <- PropList,Ets_base_magic#ets_base_magic.ratio > 0],
    {PropRandom,PropValue} = get_random_prop(PropList1),
	{PropRandom2,PropValue2} = 
	 		if
			%%玄武
			Goods_Career == 1  ->
				if 
					PropRandom == wit orelse PropRandom == agile ->
						{forza,get_lists_max(PropList1,forza)};
					true ->
						{PropRandom,PropValue}
				end;
			%%白虎
			Goods_Career == 2  ->
				if 
					PropRandom == wit orelse PropRandom == forza ->
						{agile,get_lists_max(PropList1,agile)};
					true ->
						{PropRandom,PropValue}
				end;
			%%青龙
			Goods_Career == 3  ->
				if 
					PropRandom == wit orelse PropRandom == forza ->
						{agile,get_lists_max(PropList1,agile)};
					true ->
						{PropRandom,PropValue}
				end;
			%%朱雀
			Goods_Career == 4  ->
				if 
					PropRandom == agile orelse PropRandom == forza ->
						{wit,get_lists_max(PropList1,wit)};
					true ->
						{PropRandom,PropValue}
				end;
			%%麒麟
			Goods_Career == 5  ->
				if 
					PropRandom == wit orelse PropRandom == agile ->
						{forza,get_lists_max(PropList1,forza)};
					true ->
						{PropRandom,PropValue}
				end;
			true ->
				{PropRandom,PropValue}
		end,
	{PropRandom3,PropValue3} = 
		if 
			(Goods_Subtype >= 9 andalso Goods_Subtype =< 13) orelse Goods_Subtype == 20 orelse Goods_Subtype == 23 ->
				if
					PropRandom2 == hp ->
						{mp,get_lists_max(PropList1,mp)};
					true ->
						{PropRandom2,PropValue2}
				end;
			(Goods_Subtype >= 14 andalso Goods_Subtype =< 19) ->
				if
					PropRandom2 == max_attack ->
						{mp,get_lists_max(PropList1,mp)};
					true ->
						{PropRandom2,PropValue2}
				end;
			true ->
				{PropRandom2,PropValue2}
		end,	
	loop_prop(Step,Goods_Subtype,Goods_Career,Rest, [{PropRandom3,PropValue3}|NewPropList]). 

%%取物品对就的最大攻击值
get_max_value_magic(Goods_Level,Key) ->
	Step = 
		if Goods_Level >= 0  andalso Goods_Level  < 30  -> 1;
		   Goods_Level >= 30 andalso Goods_Level < 40  -> 2;
		   Goods_Level >= 40 andalso Goods_Level < 50  -> 3;
		   Goods_Level >= 50 andalso Goods_Level < 60  -> 4;
		   Goods_Level >= 60 andalso Goods_Level < 70  -> 5;
		   Goods_Level >= 70 andalso Goods_Level < 80  -> 6;
		   Goods_Level >= 80 andalso Goods_Level < 90  -> 7;
		   Goods_Level >= 90 andalso Goods_Level < 100  -> 8;
		   true -> 0
		end,
	Pattern = #ets_base_magic{step=Step,pack=5,_='_'},
	PropList = ets:match_object(?ETS_BASE_MAGIC, Pattern),

 	PropList1 = [[util:string_to_term(tool:to_list(Ets_base_magic#ets_base_magic.prop)),Ets_base_magic#ets_base_magic.ratio,Ets_base_magic#ets_base_magic.max_value,Ets_base_magic#ets_base_magic.min_value] || Ets_base_magic <- PropList,Ets_base_magic#ets_base_magic.ratio =/= 0],
	[Value] = [MaxValue || [PropKey,_Ratio,MaxValue,_MinValue]<- PropList1,PropKey==Key],
	Value.

get_lists_max(PropList,NewProp) ->
	PropValueList = [[util:rand(MinValue, MaxValue)]|| [Prop,_Ratio,MaxValue,MinValue] <- PropList,NewProp == Prop],
	lists:nth(1, lists:max(PropValueList)).

get_random_prop(PropList) ->
	PropList1 = [[lists:duplicate(trunc(Ratio*1000),Prop)] || [Prop,Ratio,_Max_value,_Min_value] <- PropList],
	[Properties] = util:get_random_list(lists:flatten(PropList1),1),
	PropList2 = [{Prop1,[Max_value1,Min_value1]} ||[Prop1,_Ratio1,Max_value1,Min_value1] <- PropList],
	{NewProp,[MaxValue,MinValue]} = lists:keyfind(Properties, 1, PropList2),
	PropValue =
		if
			MinValue == 0 -> 0;
			MaxValue == 0 -> 0;
			MinValue > MaxValue -> 0;
			true ->util:rand(MinValue, MaxValue)
		end,
	{NewProp,PropValue}.

%%计算附魔计算基础值
get_magic_total_score(Goods_Level) ->
	Step = 
		if Goods_Level >= 0  andalso Goods_Level  < 30  -> 1;
		   Goods_Level >= 30 andalso Goods_Level < 40  -> 2;
		   Goods_Level >= 40 andalso Goods_Level < 50  -> 3;
		   Goods_Level >= 50 andalso Goods_Level < 60  -> 4;
		   Goods_Level >= 60 andalso Goods_Level < 70  -> 5;
		   Goods_Level >= 70 andalso Goods_Level < 80  -> 6;
		   Goods_Level >= 80 andalso Goods_Level < 90  -> 7;
		   Goods_Level >= 90 andalso Goods_Level < 100  -> 8;
		   true -> 0
		end,
	Pattern = #ets_base_magic{step=Step,pack=1,_='_'},
	PropList = ets:match_object(?ETS_BASE_MAGIC, Pattern),
	PropList1 = [{Ets_base_magic#ets_base_magic.prop,Ets_base_magic#ets_base_magic.max_value} || Ets_base_magic <- PropList],
	F = fun(NewProp,Max_Vlaue) ->
				if
					NewProp == hp -> 
						30*Max_Vlaue;
					NewProp == mp -> 
						10*Max_Vlaue;
					NewProp == max_attack -> 
						30*Max_Vlaue;
					NewProp == forza -> 
						10*Max_Vlaue;
					NewProp == agile -> 
						10*Max_Vlaue;
					NewProp == wit -> 
						10*Max_Vlaue;
					NewProp == physique -> 
						20*Max_Vlaue;
					NewProp == hit -> 
						20*Max_Vlaue;
					NewProp == crit -> 
						20*Max_Vlaue;
					NewProp == dodge -> 
						20*Max_Vlaue;
					NewProp == def -> 
						20*Max_Vlaue;
					NewProp == anti_wind -> 
						30*Max_Vlaue;
					NewProp == anti_thunder -> 
						30*Max_Vlaue;
					NewProp == anti_water -> 
						30*Max_Vlaue;
					NewProp == anti_fire -> 
						30*Max_Vlaue;
					NewProp == anti_soil -> 
						30*Max_Vlaue;
					NewProp == anti_all -> 
						30*Max_Vlaue;
					true ->
						0
				end		
	end,
	List = [F(util:string_to_term(tool:to_list(Prop)),Max_Vlaue) || {Prop,Max_Vlaue} <- PropList1],
	SumMaxValue = lists:sum(List),
	trunc(SumMaxValue / 10).
	

%%计算附魔装备的星级(总评价)
get_magic_star(Goods_Level,GoodsAttributeList) ->
	Step = 
		if Goods_Level >= 0  andalso Goods_Level  < 30  -> 1;
		   Goods_Level >= 30 andalso Goods_Level < 40  -> 2;
		   Goods_Level >= 40 andalso Goods_Level < 50  -> 3;
		   Goods_Level >= 50 andalso Goods_Level < 60  -> 4;
		   Goods_Level >= 60 andalso Goods_Level < 70  -> 5;
		   Goods_Level >= 70 andalso Goods_Level < 80  -> 6;
		   Goods_Level >= 80 andalso Goods_Level < 90  -> 7;
		   Goods_Level >= 90 andalso Goods_Level < 100  -> 8;
		   true -> 0
		end,
	Pattern = #ets_base_magic{step=Step,pack=1,_='_'},
	PropList = ets:match_object(?ETS_BASE_MAGIC, Pattern),
	PropList1 = [{util:string_to_term(tool:to_list(Ets_base_magic#ets_base_magic.prop)),Ets_base_magic#ets_base_magic.max_value} || Ets_base_magic <- PropList],
	case GoodsAttributeList of
		[] -> 0;
		_ -> 
			F = fun(AttributeInfo) ->
						 case AttributeInfo#goods_attribute.attribute_id of
							 1 -> 
								 {_Key,MaxValue} = lists:keyfind(hp,1,PropList1),
								 {30*AttributeInfo#goods_attribute.hp,30*MaxValue};
							 2 -> 
								 {_Key,MaxValue} = lists:keyfind(mp,1,PropList1),
								 {1*AttributeInfo#goods_attribute.mp,10*MaxValue};
							 3 -> 
								 {_Key,MaxValue} = lists:keyfind(max_attack,1,PropList1),
								 {30*AttributeInfo#goods_attribute.max_attack,30*MaxValue};
							 4 -> 
								 {_Key,MaxValue} = lists:keyfind(def,1,PropList1),
								 {10*AttributeInfo#goods_attribute.def,20*MaxValue};
							 5 -> 
								 {_Key,MaxValue} = lists:keyfind(hit,1,PropList1),
								 {5*AttributeInfo#goods_attribute.hit,20*MaxValue};
							 6 -> 
								 {_Key,MaxValue} = lists:keyfind(dodge,1,PropList1),
								 {10*AttributeInfo#goods_attribute.dodge,20*MaxValue};
							 7 ->
								 {_Key,MaxValue} = lists:keyfind(crit,1,PropList1),
								 {10*AttributeInfo#goods_attribute.crit,20*MaxValue};
							 8 -> 
								 {_Key,MaxValue} = lists:keyfind(min_attack,1,PropList1),
								 {30*AttributeInfo#goods_attribute.min_attack,30*MaxValue};
							 9 -> 
								 {_Key,MaxValue} = lists:keyfind(physique,1,PropList1),
								 {20*AttributeInfo#goods_attribute.physique,20*MaxValue};
							 10 -> 
								 {_Key,MaxValue} = lists:keyfind(anti_wind,1,PropList1),
								 {30*AttributeInfo#goods_attribute.anti_wind,30*MaxValue};
							 11 -> 
								 {_Key,MaxValue} = lists:keyfind(anti_fire,1,PropList1),
								 {30*AttributeInfo#goods_attribute.anti_fire,30*MaxValue};
							 12 -> 
								 {_Key,MaxValue} = lists:keyfind(anti_water,1,PropList1),
								 {30*AttributeInfo#goods_attribute.anti_water,30*MaxValue};
							 13 -> 
								 {_Key,MaxValue} = lists:keyfind(anti_thunder,1,PropList1),
								 {30*AttributeInfo#goods_attribute.anti_thunder,30*MaxValue};
							 14 -> 
								 {_Key,MaxValue} = lists:keyfind(anti_soil,1,PropList1),
								 {30*AttributeInfo#goods_attribute.anti_soil,30*MaxValue};
							 15 -> 
								 {_Key,MaxValue} = lists:keyfind(forza,1,PropList1),
								 {5*AttributeInfo#goods_attribute.forza,10*MaxValue};
							 16 -> 
								 {_Key,MaxValue} = lists:keyfind(agile,1,PropList1),
								 {5*AttributeInfo#goods_attribute.agile,10*MaxValue};
							 17 -> 
								 {_Key,MaxValue} = lists:keyfind(wit,1,PropList1),
								 {5*AttributeInfo#goods_attribute.wit,10*MaxValue};
							 0 ->  
								 {_Key,MaxValue} = lists:keyfind(anti_wind,1,PropList1),
								 {30*AttributeInfo#goods_attribute.anti_wind,30*MaxValue};
							 _ -> 
								 {0,0}
						end
				end,
			List = ([F(AttributeInfo) || AttributeInfo <- GoodsAttributeList]),
			F2 = fun({Score1,Score2},[Sum1,Sum2]) ->
						 [Sum1+Score1,Sum2+Score2]
				 end,
			[Total,TotalScore] = lists:foldl(F2, [0,0], List),
			Star = (length(GoodsAttributeList)+0.5)*Total*10/(TotalScore*5),
			Star1 = util:ceil(Star),
			if
				Star1 >= 10 -> 
					10;
				true -> 
					if Star1 == 0 ->
						   1;
					   true ->
						   Star1
					end
			end
	end.

%%计算附魔装备的星级(单个属性评价)
get_single_magic_star(Goods_Level,Attribute_id,Attribute_value) ->
	Step = 
		if Goods_Level >= 0  andalso Goods_Level  < 30  -> 1;
		   Goods_Level >= 30 andalso Goods_Level < 40  -> 2;
		   Goods_Level >= 40 andalso Goods_Level < 50  -> 3;
		   Goods_Level >= 50 andalso Goods_Level < 60  -> 4;
		   Goods_Level >= 60 andalso Goods_Level < 70  -> 5;
		   Goods_Level >= 70 andalso Goods_Level < 80  -> 6;
		   Goods_Level >= 80 andalso Goods_Level < 90  -> 7;
		   Goods_Level >= 90 andalso Goods_Level < 100  -> 8;
		   true -> 0
		end,
	Pattern = #ets_base_magic{step=Step,pack=1,_='_'},
	PropList = ets:match_object(?ETS_BASE_MAGIC, Pattern),
	PropList1 = [{util:string_to_term(tool:to_list(Ets_base_magic#ets_base_magic.prop)),Ets_base_magic#ets_base_magic.max_value} || Ets_base_magic <- PropList],
	%%原始对应的最大值
	case Attribute_id of
			1 ->
				Key = hp;
			2 ->
				Key = mp;
			3 ->
				Key = max_attack;
			4 ->
				Key = def;
			5 ->
				Key = hit;
			6 ->
				Key = dodge;
			7 ->
				Key = crit;
			8 ->
				Key = max_attack;
			9 ->
				Key = physique;
			10 ->
				Key = anti_wind;
			11 ->
				Key = anti_fire;
			12 ->
				Key = anti_water;
			13 ->
				Key = anti_thunder;
			14 ->
				Key = anti_soil;
			15 ->
				Key = forza;
			16 ->
				Key = agile;
			17 ->
				Key = wit;
			0 ->
				Key = anti_wind;
			_ ->
				Key = undefined
		end	,	
	case lists:keyfind(Key,1,PropList1) of
		false -> OgraiValue = 1;
		{_Key,MaxValue} -> OgraiValue = MaxValue
	end,
	%%70级以上的且为三个主属性之一，当值大于23则为10星，其它情况按公式计算
	if Step >= 6 andalso Attribute_id >= 15 andalso Attribute_id =< 17 andalso Attribute_value >= 23 ->
		   10;
	   true ->
		   Star = (Attribute_value) / (OgraiValue / 10),
		   if
			   Star >= 10 ->
				   10;
			   true ->
				   if Star == 0 ->
						  1;
					  Star > 0 andalso Star =< 1 ->
						  2;
					  true ->
						  trunc(Star)
				   end
		   end
	end.
