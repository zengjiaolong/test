%%%---------------------------------------
%%% @Module  : data_ring_bless
%%% @Author  : ygzj
%%% @Created : 2011.07.01
%%% @Description:  灵兽配置
%%%---------------------------------------
-module(data_ring_bless).
-compile(export_all).
-include("record.hrl").

%%紫戒指的最大祝福等级
get_max_ring_bless_level(GoodsLevel) ->
	case GoodsLevel of
		36 -> 1;
		46 -> 2;
		56 -> 3;
		66 -> 4;
		76 -> 5;
		_ ->  0
	end.

%%戒指祝福等级消耗的铜币和祝福碎片
get_ring_bless_level_coin_glass(RingLevel) ->
	case RingLevel of
		1 -> [10000,2];
		2 -> [15000,5];
		3 -> [20000,11];
		4 -> [25000,15];
		5 -> [30000,22];
		_ -> [10000000,10000000]
	end.
	
%%戒指祝福技能效果类型
get_ring_bless_type() ->
	[fire_bless,water_bless,wood_bless,soil_bless,gold_bless].

%%戒指等级和祝福等级的技能效果
get_ring_bless_type_skill(BlessType) ->
	case BlessType of
		fire_bless  ->
			 25601;%%增加攻击,持续20秒,概率为10%;
		water_bless ->
			25602;%%增加法力,持续20秒,概率为10%;
		wood_bless ->
			25603;%%增加气血,持续20秒,概率为10%;
		soil_bless ->
			25604;%%减免伤害,持续20秒,概率为10%;
		gold_bless ->
			25605;%%反弹所受伤害,持续20秒,概率为10%;
		_ ->
			0
	end.

