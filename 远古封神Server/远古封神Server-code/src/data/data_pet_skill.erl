%%%---------------------------------------
%%% @Module  : data_pet_skill
%%% @Author  : ygfs
%%% @Created : 2012-04-26 23:18:31
%%% @Description:  自动生成
%%%---------------------------------------

-module(data_pet_skill).
-export(
	[
		get/1
	]
).
-include("record.hrl").

get(24215) ->
	#ets_pet_skill{
		id = 24215,
		name = <<"初级重击">>,
		type = att,
		lv = 1,
		rate = 0.05,
		hurt_rate = 0.1,
		hurt = 200,
		cd = 10,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24216) ->
	#ets_pet_skill{
		id = 24216,
		name = <<"中级重击">>,
		type = att,
		lv = 2,
		rate = 0.1,
		hurt_rate = 0.15,
		hurt = 400,
		cd = 10,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24217) ->
	#ets_pet_skill{
		id = 24217,
		name = <<"高级重击">>,
		type = att,
		lv = 3,
		rate = 0.15,
		hurt_rate = 0.2,
		hurt = 600,
		cd = 10,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24218) ->
	#ets_pet_skill{
		id = 24218,
		name = <<"顶级重击">>,
		type = att,
		lv = 4,
		rate = 0.2,
		hurt_rate = 0.25,
		hurt = 800,
		cd = 10,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24219) ->
	#ets_pet_skill{
		id = 24219,
		name = <<"初级破甲">>,
		type = break,
		lv = 1,
		rate = 0.05,
		hurt_rate = 0,
		hurt = 0,
		cd = 15,
		effect = 0,
		lastime = 0,
		data = [5000,0.05]
	};

get(24220) ->
	#ets_pet_skill{
		id = 24220,
		name = <<"中级破甲">>,
		type = break,
		lv = 2,
		rate = 0.1,
		hurt_rate = 0,
		hurt = 0,
		cd = 15,
		effect = 0,
		lastime = 0,
		data = [5000,0.08]
	};

get(24221) ->
	#ets_pet_skill{
		id = 24221,
		name = <<"高级破甲">>,
		type = break,
		lv = 3,
		rate = 0.15,
		hurt_rate = 0,
		hurt = 0,
		cd = 15,
		effect = 0,
		lastime = 0,
		data = [5000,0.11]
	};

get(24222) ->
	#ets_pet_skill{
		id = 24222,
		name = <<"顶级破甲">>,
		type = break,
		lv = 4,
		rate = 0.2,
		hurt_rate = 0,
		hurt = 0,
		cd = 15,
		effect = 0,
		lastime = 0,
		data = [5000,0.15]
	};

get(24223) ->
	#ets_pet_skill{
		id = 24223,
		name = <<"初级击退">>,
		type = back,
		lv = 1,
		rate = 0.05,
		hurt_rate = 0.025,
		hurt = 0,
		cd = 20,
		effect = 0,
		lastime = 0,
		data = [2]
	};

get(24224) ->
	#ets_pet_skill{
		id = 24224,
		name = <<"中级击退">>,
		type = back,
		lv = 2,
		rate = 0.1,
		hurt_rate = 0.05,
		hurt = 0,
		cd = 20,
		effect = 0,
		lastime = 0,
		data = [2]
	};

get(24225) ->
	#ets_pet_skill{
		id = 24225,
		name = <<"高级击退">>,
		type = back,
		lv = 3,
		rate = 0.15,
		hurt_rate = 0.075,
		hurt = 0,
		cd = 20,
		effect = 0,
		lastime = 0,
		data = [2]
	};

get(24226) ->
	#ets_pet_skill{
		id = 24226,
		name = <<"顶级击退">>,
		type = back,
		lv = 4,
		rate = 0.2,
		hurt_rate = 0.1,
		hurt = 0,
		cd = 20,
		effect = 0,
		lastime = 0,
		data = [2]
	};

get(24227) ->
	#ets_pet_skill{
		id = 24227,
		name = <<"初级神火怒焰">>,
		type = flame,
		lv = 1,
		rate = 0.05,
		hurt_rate = 0.05,
		hurt = 200,
		cd = 15,
		effect = 0,
		lastime = 0,
		data = [2]
	};

get(24228) ->
	#ets_pet_skill{
		id = 24228,
		name = <<"中级神火怒焰">>,
		type = flame,
		lv = 2,
		rate = 0.1,
		hurt_rate = 0.1,
		hurt = 350,
		cd = 15,
		effect = 0,
		lastime = 0,
		data = [2]
	};

get(24229) ->
	#ets_pet_skill{
		id = 24229,
		name = <<"高级神火怒焰">>,
		type = flame,
		lv = 3,
		rate = 0.15,
		hurt_rate = 0.15,
		hurt = 500,
		cd = 15,
		effect = 0,
		lastime = 0,
		data = [2]
	};

get(24230) ->
	#ets_pet_skill{
		id = 24230,
		name = <<"顶级神火怒焰">>,
		type = flame,
		lv = 4,
		rate = 0.2,
		hurt_rate = 0.2,
		hurt = 650,
		cd = 15,
		effect = 0,
		lastime = 0,
		data = [2]
	};

get(24231) ->
	#ets_pet_skill{
		id = 24231,
		name = <<"初级吸血">>,
		type = bleed,
		lv = 1,
		rate = 0.05,
		hurt_rate = 0.025,
		hurt = 0,
		cd = 30,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24232) ->
	#ets_pet_skill{
		id = 24232,
		name = <<"中级吸血">>,
		type = bleed,
		lv = 2,
		rate = 0.1,
		hurt_rate = 0.05,
		hurt = 0,
		cd = 30,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24233) ->
	#ets_pet_skill{
		id = 24233,
		name = <<"高级吸血">>,
		type = bleed,
		lv = 3,
		rate = 0.15,
		hurt_rate = 0.075,
		hurt = 0,
		cd = 30,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24234) ->
	#ets_pet_skill{
		id = 24234,
		name = <<"顶级吸血">>,
		type = bleed,
		lv = 4,
		rate = 0.15,
		hurt_rate = 0.1,
		hurt = 0,
		cd = 30,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24235) ->
	#ets_pet_skill{
		id = 24235,
		name = <<"高级击晕">>,
		type = dizzy,
		lv = 3,
		rate = 0.05,
		hurt_rate = 0,
		hurt = 0,
		cd = 30,
		effect = 2,
		lastime = 3,
		data = []
	};

get(24236) ->
	#ets_pet_skill{
		id = 24236,
		name = <<"顶级击晕">>,
		type = dizzy,
		lv = 4,
		rate = 0.1,
		hurt_rate = 0,
		hurt = 0,
		cd = 30,
		effect = 2,
		lastime = 3,
		data = []
	};

get(24237) ->
	#ets_pet_skill{
		id = 24237,
		name = <<"高级定身">>,
		type = freeze,
		lv = 3,
		rate = 0.05,
		hurt_rate = 0,
		hurt = 0,
		cd = 30,
		effect = 1,
		lastime = 3,
		data = []
	};

get(24238) ->
	#ets_pet_skill{
		id = 24238,
		name = <<"顶级定身">>,
		type = freeze,
		lv = 4,
		rate = 0.1,
		hurt_rate = 0,
		hurt = 0,
		cd = 30,
		effect = 1,
		lastime = 3,
		data = []
	};

get(24239) ->
	#ets_pet_skill{
		id = 24239,
		name = <<"高级沉默">>,
		type = silence,
		lv = 3,
		rate = 0.05,
		hurt_rate = 0,
		hurt = 0,
		cd = 30,
		effect = 3,
		lastime = 3,
		data = []
	};

get(24240) ->
	#ets_pet_skill{
		id = 24240,
		name = <<"顶级沉默">>,
		type = silence,
		lv = 4,
		rate = 0.1,
		hurt_rate = 0,
		hurt = 0,
		cd = 30,
		effect = 3,
		lastime = 3,
		data = []
	};

get(24241) ->
	#ets_pet_skill{
		id = 24241,
		name = <<"高级迟缓">>,
		type = slow,
		lv = 3,
		rate = 0.05,
		hurt_rate = 0,
		hurt = 0,
		cd = 30,
		effect = 4,
		lastime = 4,
		data = [0.15]
	};

get(24242) ->
	#ets_pet_skill{
		id = 24242,
		name = <<"顶级迟缓">>,
		type = slow,
		lv = 4,
		rate = 0.1,
		hurt_rate = 0,
		hurt = 0,
		cd = 30,
		effect = 4,
		lastime = 4,
		data = [0.15]
	};

get(24243) ->
	#ets_pet_skill{
		id = 24243,
		name = <<"初级虚弱">>,
		type = weak,
		lv = 1,
		rate = 0.05,
		hurt_rate = 0,
		hurt = 0,
		cd = 15,
		effect = 0,
		lastime = 0,
		data = [5000,0.05]
	};

get(24244) ->
	#ets_pet_skill{
		id = 24244,
		name = <<"中级虚弱">>,
		type = weak,
		lv = 2,
		rate = 0.1,
		hurt_rate = 0,
		hurt = 0,
		cd = 15,
		effect = 0,
		lastime = 0,
		data = [5000,0.08]
	};

get(24245) ->
	#ets_pet_skill{
		id = 24245,
		name = <<"高级虚弱">>,
		type = weak,
		lv = 3,
		rate = 0.15,
		hurt_rate = 0,
		hurt = 0,
		cd = 15,
		effect = 0,
		lastime = 0,
		data = [5000,0.11]
	};

get(24246) ->
	#ets_pet_skill{
		id = 24246,
		name = <<"顶级虚弱">>,
		type = weak,
		lv = 4,
		rate = 0.2,
		hurt_rate = 0,
		hurt = 0,
		cd = 15,
		effect = 0,
		lastime = 0,
		data = [5000,0.15]
	};

get(24247) ->
	#ets_pet_skill{
		id = 24247,
		name = <<"初级割伤">>,
		type = cut,
		lv = 1,
		rate = 0.05,
		hurt_rate = 0.02,
		hurt = 100,
		cd = 12,
		effect = 0,
		lastime = 0,
		data = [5000]
	};

get(24248) ->
	#ets_pet_skill{
		id = 24248,
		name = <<"中级割伤">>,
		type = cut,
		lv = 2,
		rate = 0.1,
		hurt_rate = 0.03,
		hurt = 200,
		cd = 12,
		effect = 0,
		lastime = 0,
		data = [5000]
	};

get(24249) ->
	#ets_pet_skill{
		id = 24249,
		name = <<"高级割伤">>,
		type = cut,
		lv = 3,
		rate = 0.15,
		hurt_rate = 0.04,
		hurt = 300,
		cd = 12,
		effect = 0,
		lastime = 0,
		data = [5000]
	};

get(24250) ->
	#ets_pet_skill{
		id = 24250,
		name = <<"顶级割伤">>,
		type = cut,
		lv = 4,
		rate = 0.2,
		hurt_rate = 0.05,
		hurt = 400,
		cd = 12,
		effect = 0,
		lastime = 0,
		data = [5000]
	};

get(24251) ->
	#ets_pet_skill{
		id = 24251,
		name = <<"初级抵抗眩晕">>,
		type = anti_dizzy,
		lv = 1,
		rate = 0.1,
		hurt_rate = 0,
		hurt = 0,
		cd = 20,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24252) ->
	#ets_pet_skill{
		id = 24252,
		name = <<"中级抵抗眩晕">>,
		type = anti_dizzy,
		lv = 2,
		rate = 0.2,
		hurt_rate = 0,
		hurt = 0,
		cd = 20,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24253) ->
	#ets_pet_skill{
		id = 24253,
		name = <<"高级抵抗眩晕">>,
		type = anti_dizzy,
		lv = 3,
		rate = 0.3,
		hurt_rate = 0,
		hurt = 0,
		cd = 20,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24254) ->
	#ets_pet_skill{
		id = 24254,
		name = <<"顶级抵抗眩晕">>,
		type = anti_dizzy,
		lv = 4,
		rate = 0.4,
		hurt_rate = 0,
		hurt = 0,
		cd = 20,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24255) ->
	#ets_pet_skill{
		id = 24255,
		name = <<"初级抵抗沉默">>,
		type = anti_silence,
		lv = 1,
		rate = 0.1,
		hurt_rate = 0,
		hurt = 0,
		cd = 20,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24256) ->
	#ets_pet_skill{
		id = 24256,
		name = <<"中级抵抗沉默">>,
		type = anti_silence,
		lv = 2,
		rate = 0.2,
		hurt_rate = 0,
		hurt = 0,
		cd = 20,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24257) ->
	#ets_pet_skill{
		id = 24257,
		name = <<"高级抵抗沉默">>,
		type = anti_silence,
		lv = 3,
		rate = 0.3,
		hurt_rate = 0,
		hurt = 0,
		cd = 20,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24258) ->
	#ets_pet_skill{
		id = 24258,
		name = <<"顶级抵抗沉默">>,
		type = anti_silence,
		lv = 4,
		rate = 0.4,
		hurt_rate = 0,
		hurt = 0,
		cd = 20,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24259) ->
	#ets_pet_skill{
		id = 24259,
		name = <<"初级抵抗定身">>,
		type = anti_freeze,
		lv = 1,
		rate = 0.1,
		hurt_rate = 0,
		hurt = 0,
		cd = 20,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24260) ->
	#ets_pet_skill{
		id = 24260,
		name = <<"中级抵抗定身">>,
		type = anti_freeze,
		lv = 2,
		rate = 0.2,
		hurt_rate = 0,
		hurt = 0,
		cd = 20,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24261) ->
	#ets_pet_skill{
		id = 24261,
		name = <<"高级抵抗定身">>,
		type = anti_freeze,
		lv = 3,
		rate = 0.3,
		hurt_rate = 0,
		hurt = 0,
		cd = 20,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24262) ->
	#ets_pet_skill{
		id = 24262,
		name = <<"顶级抵抗定身">>,
		type = anti_freeze,
		lv = 4,
		rate = 0.4,
		hurt_rate = 0,
		hurt = 0,
		cd = 20,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24263) ->
	#ets_pet_skill{
		id = 24263,
		name = <<"初级抵抗迟缓">>,
		type = anti_slow,
		lv = 1,
		rate = 0.1,
		hurt_rate = 0,
		hurt = 0,
		cd = 20,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24264) ->
	#ets_pet_skill{
		id = 24264,
		name = <<"中级抵抗迟缓">>,
		type = anti_slow,
		lv = 2,
		rate = 0.2,
		hurt_rate = 0,
		hurt = 0,
		cd = 20,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24265) ->
	#ets_pet_skill{
		id = 24265,
		name = <<"高级抵抗迟缓">>,
		type = anti_slow,
		lv = 3,
		rate = 0.3,
		hurt_rate = 0,
		hurt = 0,
		cd = 20,
		effect = 0,
		lastime = 0,
		data = []
	};

get(24266) ->
	#ets_pet_skill{
		id = 24266,
		name = <<"顶级抵抗迟缓">>,
		type = anti_slow,
		lv = 4,
		rate = 0.4,
		hurt_rate = 0,
		hurt = 0,
		cd = 20,
		effect = 0,
		lastime = 0,
		data = []
	};

get(_SkillId) ->
	[].

