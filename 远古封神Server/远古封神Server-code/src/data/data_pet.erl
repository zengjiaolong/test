%%%---------------------------------------
%%% @Module  : data_pet
%%% @Author  : ygzj
%%% @Created : 2010.10.06
%%% @Description:  灵兽配置
%%%---------------------------------------
-module(data_pet).
-compile(export_all).
-include("record.hrl").

%%资质升级概率和消耗
get_upgrade_aptitude(Aptitude) ->
	case Aptitude of
		20 -> [100,1000];
		21 -> [98,1050];
		22 -> [96,1100];
		23 -> [93,1150];
		24 -> [91,1200];
		25 -> [89,1250];
		26 -> [87,1300];
		27 -> [84,1350];
		28 -> [82,1400];
		29 -> [80,1450];
		30 -> [78,1500];
		31 -> [75,1550];
		32 -> [73,1600];
		33 -> [71,1650];
		34 -> [69,1700];
		35 -> [66,1750];
		36 -> [64,1800];
		37 -> [62,1850];
		38 -> [60,1900];
		39 -> [57,1950];
		40 -> [54,2000];
		41 -> [52,2050];
		42 -> [50,2010];
		43 -> [48,2150];
		44 -> [46,2200];
		45 -> [43,2250];
		46 -> [41,2300];
		47 -> [38,2350];
		48 -> [36,2400];
		49 -> [34,2450];
		50 -> [31,2500];
		51 -> [28,2550];
		52 -> [26,2600];
		53 -> [24,2650];
		54 -> [22,2700];
		55 -> [20,2750];
		56 -> [18,2800];
		57 -> [16,2850];
		58 -> [14,2900];
		59 -> [12,2950];
		60 -> [10,3000];
		61 -> [10,3050];
		62 -> [9,3100];
		63 -> [9,3150];
		64 -> [8,3200];
		65 -> [8,3250];
		66 -> [7,3300];
		67 -> [7,3350];
		68 -> [6,3400];
		69 -> [6,3450];
		70 -> [5,3500];
		71 -> [5,3550];
		72 -> [4,3600];
		73 -> [4,3650];
		74 -> [3,3700];
		75 -> [3,3750];
		76 -> [2,3800];
		77 -> [2,3850];
		78 -> [2,3900];
		79 -> [2,3950];
		80 -> [5,4000];
		81 -> [5,4050];
		82 -> [5,4100];
		83 -> [5,4150];
		84 -> [5,4200];
		85 -> [5,4250];
		86 -> [5,4300];
		87 -> [5,4350];
		88 -> [5,4400];
		89 -> [5,4450];
		90 -> [5,4500];
		91 -> [5,4550];
		92 -> [5,4600];
		93 -> [5,4650];
		94 -> [5,4700];
		95 -> [5,4750];
		96 -> [5,4800];
		97 -> [5,4850];
		98 -> [5,4900];
		99 -> [5,4950];	
		_ -> [0,0]
	end.
get_upgrade_exp(Level) ->
	case Level of
	1 ->160;
	2 ->320;
	3 ->480;
	4 ->640;
	5 ->800;
	6 ->960;
	7 ->1120;
	8 ->1280;
	9 ->1780;
	10 ->3225;
	11 ->4600;
	12 ->6350;
	13 ->8475;
	14 ->10975;
	15 ->18467;
	16 ->22800;
	17 ->27633;
	18 ->32967;
	19 ->38800;
	20 ->90267;
	21 ->103933;
	22 ->118600;
	23 ->134267;
	24 ->150933;
	25 ->252900;
	26 ->280900;
	27 ->310400;
	28 ->341400;
	29 ->373900;
	30 ->407900;
	31 ->443400;
	32 ->480400;
	33 ->518900;
	34 ->558900;
	35 ->600400;
	36 ->643400;
	37 ->687900;
	38 ->733900;
	39 ->781400;
	40 ->830400;
	41 ->880900;
	42 ->932900;
	43 ->986400;
	44 ->1041400;
	45 ->1097900;
	46 ->1155900;
	47 ->1215400;
	48 ->1276400;
	49 ->1338900;
	50 ->1589900;
	51 ->1845900;
	52 ->2106900;
	53 ->2372900;
	54 ->2643900;
	55 ->2919900;
	56 ->3200900;
	57 ->3486900;
	58 ->3777900;
	59 ->6728900;
	_ ->100000000
end.

%%通过技能id取名字
get_skill_name(SkillId) ->
	case SkillId of
		24200 ->			
			"气血增加";
		24201 ->
			"法力增加";
		24202 ->
			"攻击增加";
		24203 ->
			"防御增加";
		24204 ->
			"躲闪增加";
		24205 ->
			"命中增加";
		24206 ->
			"打坐回血";
		24207 ->
			"打坐回蓝";
		24208 ->
			"全抗增加";
		_ ->
			"技能"
	end.

%%通过技能id取名字
get_skill_name_color(Step) ->
	case Step of
		1 ->			
			"#ffffff";
		2 ->
			"#00ff00";
		3 ->
			"#0000ff";
		4 ->
			"#ffff00";
		5 ->
			"#ff00ff";
		_ ->
			"#ffffff"
	end.

%%捕兽索对应的随机灵兽的阶数PetGrabId 捕兽索物品类型id
get_grab_pet_step(PetGrabId) ->
	case PetGrabId of
		24700 -> 
			[Step] = util:get_random_list_probability([{0,20},{1,80}],1);
		24701 -> 
			[Step] = util:get_random_list_probability([{1,55},{2,45}],1);
		24702 -> 
			[Step] = util:get_random_list_probability([{2,70},{3,30}],1);
		24703 -> 
			[Step] =util:get_random_list_probability([{3,85},{4,15}],1);
		_ -> 
			[Step] = [0]
	end,
	Step.

%%神兽蛋概率产生物品或灵兽或技能
%%返回格式[Type,Num]type为1表示灵兽,阶数，2表示物品,typeid
get_data_by_egg(PlayerId,_GoodsTypeId) ->
	Ets_Pet_Extra = lib_pet:get_pet_extra(PlayerId),
	get_data_by_lucky_value(Ets_Pet_Extra#ets_pet_extra.lucky_value).

%%返回格式[Type,Num]type为1表示灵兽,阶数，2表示物品,typeid
get_data_by_lucky_value(Lucky_value) ->
	Random = util:rand(1, 10000),
	TwoStep = (0.692-(Lucky_value/1000)*0.275)*10000,
	ThreeStep =(0.23+(Lucky_value/1000)*0.265)*10000,
	FourthStep =(0.018)*10000,
	FivthStep = ((Lucky_value/1000)*0.01)*10000,
	 if
		 Random >= 0 andalso Random < TwoStep ->
			 [1,2];%%1为类型,2为阶数
		 Random >= TwoStep andalso Random < (TwoStep + ThreeStep) ->
			 [1,3];%%1为类型,2为阶数
		 Random >= (TwoStep + ThreeStep) andalso Random < (TwoStep + ThreeStep +FourthStep) ->
			 [1,4];%%1为类型,2为阶数
		 Random >= (TwoStep + ThreeStep +FourthStep) andalso Random < (TwoStep + ThreeStep +FourthStep + FivthStep) ->
			 [1,5];%%1为类型,2为阶数
		 Random >= (TwoStep + ThreeStep +FourthStep + FivthStep) andalso Random =< 10000 ->
			 [2,24107];%%1为类型,2为物品typeid
		 true ->
			 [0,0]
	end.

%%元宝刷新　返回格式[Type,Num]type为1表示灵兽,阶数，2表示物品,typeid
get_data_by_lucky_value_flush(Lucky_value) ->
	Random = util:rand(1, 10000),
	TwoStep = (0.80-(Lucky_value/1000)*0.275)*10000,
	ThreeStep =(0.17+(Lucky_value/1000)*0.273)*10000,
	FourthStep =(0.005)*10000,
	FivthStep = ((Lucky_value/1000)*0.002)*10000,
	 if
		 Random >= 0 andalso Random < TwoStep ->
			 [1,2];%%1为类型,2为阶数
		 Random >= TwoStep andalso Random < (TwoStep + ThreeStep) ->
			 [1,3];%%1为类型,2为阶数
		 Random >= (TwoStep + ThreeStep) andalso Random < (TwoStep + ThreeStep +FourthStep) ->
			 [1,4];%%1为类型,2为阶数
		 Random >= (TwoStep + ThreeStep +FourthStep) andalso Random < (TwoStep + ThreeStep +FourthStep + FivthStep) ->
			 [1,5];%%1为类型,2为阶数
		 Random >= (TwoStep + ThreeStep +FourthStep + FivthStep) andalso Random =< 10000 ->
			 [2,24107];%%1为类型,2为物品typeid
		 true ->
			 [0,0]
	end.

get_data_by_free() ->
	Random = util:rand(1, 100),
	 if
		 Random >= 0 andalso Random < 92 ->
			 [1,2];%%1为类型,2为阶数
		 Random >= 92 andalso Random < 100 ->
			 [1,3];%%1为类型,2为阶数
		 true ->
			 [1,2]%%1为类型,2为阶数
	end.
	
%% 	if Lucky_value >= 0 andalso Lucky_value =< 499 ->
%% 		   if
%% 				Random >= 1 andalso Random =< 6250 ->
%% 					[1,2];%%1为类型,2为阶数
%% 				Random > 6251 andalso Random =< 8250 ->
%% 					[1,3];%%1为类型,2为阶数
%% 				Random >= 8251 andalso Random =< 8450 ->
%% 					[1,4];%%1为类型,2为阶数
%% 				Random >= 8451 andalso Random =< 8500 ->
%% 					[1,5];%%1为类型,2为阶数
%% 				Random >= 8501 andalso Random =< 10000 ->
%% 					[2,24107];%%1为类型,2为物品typeid
%% 				true ->
%% 					[0,0]
%% 			end;
%% 	   Lucky_value >= 500 andalso Lucky_value =< 999 ->
%% 		    if
%% 				Random >= 1 andalso Random =< 5650 ->
%% 					[1,2];%%1为类型,2为阶数
%% 				Random > 5651 andalso Random =< 8150 ->
%% 					[1,3];%%1为类型,2为阶数
%% 				Random >= 8151 andalso Random =< 8450 ->
%% 					[1,4];%%1为类型,2为阶数
%% 				Random >= 8451 andalso Random =< 8500 ->
%% 					[1,5];%%1为类型,2为阶数
%% 				Random >= 8501 andalso Random =< 10000 ->
%% 					[2,24107];%%1为类型,2为物品typeid
%% 				true ->
%% 					[0,0]
%% 			end;
%% 	   Lucky_value > 999 ->
%% 		    if
%% 				Random >= 1 andalso Random =< 5000 ->
%% 					[1,2];%%1为类型,2为阶数
%% 				Random > 5001 andalso Random =< 8000 ->
%% 					[1,3];%%1为类型,2为阶数
%% 				Random >= 8001 andalso Random =< 8400 ->
%% 					[1,4];%%1为类型,2为阶数
%% 				Random >= 8401 andalso Random =< 8500 ->
%% 					[1,5];%%1为类型,2为阶数
%% 				Random >= 8501 andalso Random =< 10000 ->
%% 					[2,24107];%%1为类型,2为物品typeid
%% 				true ->
%% 					[0,0]
%% 			end
%% 	end.
	

%%捕兽索对应的随机灵兽随机产生9种技能中的一种
get_grab_pet_skill_id() ->
	SkillIdList = [{24200,9},{24201,12},{24202,7},{24203,13},{24204,13},{24205,13},{24206,12},{24207,12},{24208,9}],
	[Skill_Id] = util:get_random_list_probability(SkillIdList,1),
	Skill_Id.

%%随机产生灵兽6种类型中的一种
get_random_type_id() ->
	PetRandomTypeIdList = [24600,24601,24602,24603,24604,24605,24606],
	[PetTypeId] = util:get_random_list(PetRandomTypeIdList,1),
	PetTypeId.

%%根据抓捕兽的怪物类型id决定产生哪种类型的灵兽
get_pet_type_by_montypeid(MonTypeId) ->
	if
		MonTypeId == 44001 -> 24605;
		MonTypeId == 44002 -> 24603;
		MonTypeId == 44003 -> 24602;
		true -> 24605
	end.
		
	

%%随机产生哪种类型的灵兽
get_random_pet_type() ->
	PetTypeList = [24600,24601,24602,24603,24604,24605,24606],
	[PetType] = util:get_random_list(PetTypeList,1),
	PetType.

%%消耗快乐值
get_decrease_happy(Level) ->
	if 
		Level >= 1 andalso Level =< 10 -> 2;
		Level >= 11 andalso Level =< 30 -> 3;
		Level >= 31 andalso Level =< 40 -> 4;
		Level >= 41 andalso Level =< 60 -> 6;
		true -> 6
	end.

%%宠物颜色
get_pet_color(Aptitude) ->
	if 
		Aptitude >= 20 andalso Aptitude =< 30 -> 1;
		Aptitude >= 30 andalso Aptitude =< 40 -> 2;
		Aptitude >= 40 andalso Aptitude =< 50 -> 3;
		Aptitude >= 51 andalso Aptitude =< 60 -> 4;
		Aptitude >= 61 andalso Aptitude =< 100 -> 5; 
		true ->0
	end.

%%获取灵兽技能加成
get_pet_skill_value(Pet) ->
	[get_skill_value(Pet#ets_pet.skill_1),
	 get_skill_value(Pet#ets_pet.skill_2),
	 get_skill_value(Pet#ets_pet.skill_3),
	 get_skill_value(Pet#ets_pet.skill_4),
	 get_skill_value(Pet#ets_pet.skill_5)]. 


%%获取灵兽技能效果值
get_skill_value(Skill) ->
	[SkillId, SkillLevel, SkillStep, _SkillExp] = util:string_to_term(tool:to_list(Skill)),
	case SkillId of
		24200 ->			
			[[Hp,HpFix],_,_,_,_,_,_,_,_] = get_pet_skill_effect(SkillId,SkillLevel,SkillStep),
			 [round(Hp*10000),HpFix];
		24201 ->
			[_,[Mp,MpFix],_,_,_,_,_,_,_] = get_pet_skill_effect(SkillId,SkillLevel,SkillStep),
			[round(Mp*10000),MpFix];
		24202 ->
			[_,_,_,[Att,AttFix],_,_,_,_,_] = get_pet_skill_effect(SkillId,SkillLevel,SkillStep),
			[round(Att*10000),AttFix];
		24203 ->
			[_,_,[Def,DefFix],_,_,_,_,_,_] = get_pet_skill_effect(SkillId,SkillLevel,SkillStep),
			[round(Def*10000),DefFix];
		24204 ->
			[_,_,_,_,_,_,[Dodge,DodgeFix],_,_] = get_pet_skill_effect(SkillId,SkillLevel,SkillStep),
			[round(Dodge*10000),DodgeFix];
		24205 ->
			[_,_,_,_,_,[Hit,HitFix],_,_,_] = get_pet_skill_effect(SkillId,SkillLevel,SkillStep),
			[round(Hit*10000),HitFix];
		24206 ->
			[_,_,_,_,_,_,_,[R_hp,R_hpFix],_] = get_pet_skill_effect(SkillId,SkillLevel,SkillStep),
			[round(R_hp*10000),R_hpFix];
		24207 ->
			[_,_,_,_,_,_,_,_,[R_mp,R_mpFix]] = get_pet_skill_effect(SkillId,SkillLevel,SkillStep),
			[round(R_mp*10000),R_mpFix];
		24208 ->
			[_,_,_,_,[Anti,AntiFix],_,_,_,_] = get_pet_skill_effect(SkillId,SkillLevel,SkillStep),
			[round(Anti*10000),AntiFix];
		_ ->
			[0,0]
	end.

%%灵兽技能效果
%%获取灵兽的技能属性加成系数  [气血(24200)，法力(24201)，防御(24202)，攻击(24203)，抗性(24204)，命中(24205)，闪躲(24206)，打坐回血(24207)，打坐回蓝(24208),千锤百炼(24209),飞升(24210)] 
get_pet_skill_effect(SkillId,SkillLevel,SkillStep) ->
	Ets_base_pet_skill_effectList = lib_pet:get_base_pet_skill_effect(SkillId,SkillLevel,SkillStep),
	case Ets_base_pet_skill_effectList of
		[] -> 
			EffectValue = [[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0]];
		_ ->
			[Ets_base_pet_skill_effect] = Ets_base_pet_skill_effectList,
			EffectValue = [(Ets_base_pet_skill_effect#ets_base_pet_skill_effect.per),(Ets_base_pet_skill_effect#ets_base_pet_skill_effect.fix)]
			end,
			case SkillId of
				24200 ->	
					[EffectValue,[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0]];
				24201 ->
					[[0,0],EffectValue,[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0]];
				24202 ->
					[[0,0],[0,0],[0,0],EffectValue,[0,0],[0,0],[0,0],[0,0],[0,0]];
				24203 ->
					[[0,0],[0,0],EffectValue,[0,0],[0,0],[0,0],[0,0],[0,0],[0,0]];
				24204 ->
					[[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],EffectValue,[0,0],[0,0]];
				24205 ->
					[[0,0],[0,0],[0,0],[0,0],[0,0],EffectValue,[0,0],[0,0],[0,0]];
				24206 ->
					[[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],EffectValue,[0,0]];
				24207 ->
					[[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],EffectValue];
				24208 ->
					[[0,0],[0,0],[0,0],[0,0],EffectValue,[0,0],[0,0],[0,0],[0,0]];
				24209 ->
					[[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0]];
				24210 ->
					[[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0]];
				_ ->
					[[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0],[0,0]]
			end.

%%灵兽技能等级和阶数对应的经验值
get_pet_skill_exp_step(SkillLevel) ->
	case SkillLevel of
		1 -> 0;%%对应一、二、三、四、五阶的所需技能经验值
		2 -> 100;
		3 -> 300;
		4 -> 600;
		5 -> 1000;
		6 -> 1500;
		7 -> 2500;
		8 -> 3900;
		9 -> 5700;
		10 -> 7900;
		11 -> 10400;
		12 -> 13200;
		13 -> 16300;
		14 -> 19800;
		15 -> 23700;
		16 -> 27900;
		17 -> 32400;
		18 -> 37200;
		19 -> 42400;
		20 -> 48000;
		21 -> 53900;
		22 -> 60100;
		23 -> 66600;
		24 -> 73500;
		25 -> 80800;
		26 -> 88400;
		27 -> 96300;
		28 -> 104500;
		29 -> 113100;
		30 -> 122100;
		31 -> 131400;
		32 -> 141000;
		33 -> 150900;
		34 -> 161200;
		35 -> 171900;
		36 -> 182900;
		37 -> 194200;
		38 -> 205800;
		39 -> 217800;
		40 -> 230200;
		41 -> 242900;
		42 -> 255900;
		43 -> 269200;
		44 -> 282900;
		45 -> 297000;
		46 -> 311400;
		47 -> 326100;
		48 -> 341100;
		49 -> 356500;
		50 -> 372300;
		51 -> 388400;
		52 -> 404800;
		53 -> 421500;
		54 -> 438600;
		55 -> 456100;
		56 -> 505100;
		57 -> 578600;
		58 -> 659000;
		59 -> 746400;
		60 -> 841300;
		_ -> 200000000
	end.

%%取技能的对应的经验值
get_pet_skill_exp(SkillLevel,Step) ->
	if 
		SkillLevel > 60 -> 200000000;
		true ->
			Step1Exp = get_pet_skill_exp_step(SkillLevel),
			case Step of
				1 -> Step1Exp;
				2 -> 2*Step1Exp;
				3 -> 4*Step1Exp;
				4 -> 8*Step1Exp;
				5 -> 12*Step1Exp;
				_ -> 100000000
			end
	end.

%%取阶数自身的经验
get_step_exp(Step) ->
	case Step of
		1 -> 600;
		2 -> 1800;
		3 -> 5400;
		4 -> 16200;
		5 -> 48600;
		_ -> 0
	end.


%% 初始成长值概率范围
base_grow(RP)->
	if RP =< 7000 -> %%75%
		   [20,25];
	   RP =< 9500 -> %%90%
		   [26,29];
	   true-> 
		   [30,30] %%5%
	end.

%%成长值-点数
grow_to_point(Grow) ->
	if Grow < 30-> 2;
	   Grow < 40-> 3;
	   Grow < 50-> 4;
	   Grow < 60-> 5;
	   Grow < 70-> 6;
	   Grow < 80-> 7;
	   true-> 8
	end.
	
%%提示成功率，保底
grow_up(Grow)->
	if Grow < 30 -> [100,20];
	   Grow < 40 -> [round(75*0.9),30];
	   Grow < 41 -> [round(60*0.9),40];
	   Grow < 42 -> [round(55*0.9),40];
	   Grow < 43 -> [round(50*0.9),40];
	   Grow < 44 -> [round(45*0.9),40];
	   Grow < 45 -> [round(40*0.9),40];
	   Grow < 50 -> [round(35*0.9),40];
	   Grow < 51 -> [round(30*0.9),50];
	   Grow < 52 -> [round(25*0.9),50];
	   Grow < 53 -> [round(20*0.9),50];
	   Grow < 54 -> [round(15*0.9),50];
	   Grow < 60 -> [round(10*0.9),50];
	   Grow < 70 -> [round(8*0.9),60];
	   Grow < 80 -> [round(5*0.9),70];
	   true-> [0,0]
	end.

%%每次提升加成值
base_grow_up() -> 1.

%%训练时间
get_train_time(PetLvl,GoodsNum) ->
	%%【训练时间s】＝【口粮数量】*200*60/【当前快乐值下降速度】
	HappyDel = get_decrease_happy(PetLvl),
	round(GoodsNum*200*60/HappyDel).

%%训练时间转换口粮
time_to_food(TrianTime,PetLv)->
	HappyDel = get_decrease_happy(PetLv),
	tool:floor(TrianTime*HappyDel/(200*60)).

%%训练所需金钱
get_train_money(MoneyType,TrainTime)->
	case MoneyType of
		1->
			tool:ceil(TrainTime/600);
		2->
			tool:ceil(TrainTime/0.4);
		_-> 0
	end.

%%资质到达80后提升成功加点随机(1-3点)
get_add_random_aptitude(Aptitude) ->
	if Aptitude < 80 ->
		   4;
	   true ->
		   RandomList = [{1,50},{2,35},{3,15}],
		   [AddAptitude] = util:get_random_list_probability(RandomList,1),
		   AddAptitude
	end.
	
%%资质到达80后提升失败减点随机(1-3点)
get_sub_random_aptitude(_Aptitude) ->
%% 	RandomList = [{1,15},{2,35},{3,50}],
%% 	[AddAptitude] = util:get_random_list_probability(RandomList,1),
%% 	AddAptitude.
	5.

%%资质对应的额外属性[攻击，气血，防御]
get_extra_attribute(Aptitude) ->
	if  Aptitude >= 35 andalso  Aptitude =< 44 -> [50,250,200];
		Aptitude >= 45 andalso  Aptitude =< 54 -> [100,500,300];
		Aptitude >= 55 andalso  Aptitude =< 64 -> [180,900,400];
		Aptitude >= 65 andalso  Aptitude =< 79 -> [260,1300,500];
		Aptitude >= 80 andalso  Aptitude =< 99 -> [330,1650,600];
		Aptitude >= 100 -> [400,2000,700];
		true -> [0,0,0]
	end.

%%成长对应的额外属性加点Type
get_extra_point(Grow) ->
	if  Grow >= 30 andalso  Grow =< 39 -> 10;
		Grow >= 40 andalso  Grow =< 49 -> 10+10;
		Grow >= 50 andalso  Grow =< 59 -> 10+10+15;
		Grow >= 60 andalso  Grow =< 69 -> 10+10+15+15;
		Grow >= 70 andalso  Grow =< 79 -> 10+10+15+15+20;
		Grow >= 80 -> 10+10+15+15+20+20;
		true -> 0
	end.

%%计算现在应该加的属性点(扣除原来已经加的),返回应增加的 [属性点,等加点范围]
get_add_extra_point(Grow,PrevGrow) ->
	if Grow < 30 -> [0,PrevGrow];
	   Grow =< PrevGrow*10 -> [0,PrevGrow];
	   true ->
		   [get_extra_point(Grow)-get_extra_point(PrevGrow*10),Grow div 10]
	end.


%%幸运星获取战斗技能概率
get_batt_skill_star(BattLuckValue) ->
	[Lv1,Lv2,Lv3,Lv4] = 
	if BattLuckValue >= 0 andalso BattLuckValue =< 49 -> [100,0,0,0];
	   BattLuckValue >= 50 andalso BattLuckValue =< 99 -> [91,9,0,0];
	   BattLuckValue >= 100 andalso BattLuckValue =< 149 -> [85,15,0,0];
	   BattLuckValue >= 150 andalso BattLuckValue =< 199 -> [80,20,0,0];
	   BattLuckValue >= 200 andalso BattLuckValue =< 249 -> [75,25,0,0];
	   BattLuckValue >= 250 andalso BattLuckValue =< 299 -> [69.7,30,0.3,0];
	   BattLuckValue >= 300 andalso BattLuckValue =< 349 -> [64.4,35,0.6,0];
	   BattLuckValue >= 350 andalso BattLuckValue =< 399 -> [59.1,40,0.9,0];
	   BattLuckValue >= 400 andalso BattLuckValue =< 449 -> [53.8,45,1.2,0];
	   BattLuckValue >= 450 andalso BattLuckValue =< 499 -> [53,45,2,0];
	   BattLuckValue >= 500 andalso BattLuckValue =< 549 -> [53,42,5,0];
	   BattLuckValue >= 550 andalso BattLuckValue =< 599 -> [50.95,39,10,0.05];
	   BattLuckValue >= 600 andalso BattLuckValue =< 649 -> [49.9,35,15,0.1];
	   BattLuckValue >= 650 andalso BattLuckValue =< 699 -> [44.8,35,20,0.2];
	   BattLuckValue >= 700 andalso BattLuckValue =< 749 -> [34.5,40,25,0.5];
	   BattLuckValue >= 750 andalso BattLuckValue =< 799 -> [29,40,30,1];
	   BattLuckValue >= 800 andalso BattLuckValue =< 849 -> [23,40,35,2];
	   BattLuckValue >= 850 andalso BattLuckValue =< 899 -> [20,40,35,5];
	   BattLuckValue >= 900 andalso BattLuckValue =< 949 -> [15,40,35,10];
	   BattLuckValue >= 950 andalso BattLuckValue =< 999 -> [5,40,35,20];
	   BattLuckValue >= 1000 -> [0,0,0,100];
	   true -> [0,0,0,0]
	end,
	SkillLvList = [{1,trunc(Lv1*100)},{2,trunc(Lv2*100)},{3,trunc(Lv3*100)},{4,trunc(Lv4*100)}],
	[SkillLv] = util:get_random_list_probability(SkillLvList,1),
	SkillLv.

%%随机战斗技能
get_random_batt_skill(BattLuckValue) ->
	Lv = get_batt_skill_star(BattLuckValue),
	SkillIdList = 
	if	Lv == 1 -> [{24215,12},{24219,5},{24223,12},{24227,5},{24231,5},{24243,8},{24247,5},{24251,12},{24255,12},{24259,12},{24263,12}];
		Lv == 2 -> [{24216,12},{24220,5},{24224,12},{24228,5},{24232,5},{24244,8},{24248,5},{24252,12},{24256,12},{24260,12},{24264,12}];
		Lv == 3 -> [{24217,8},{24221,8},{24225,7},{24229,4},{24233,3},{24235,3},{24237,3},{24239,3},{24241,7},{24245,7},{24249,7},{24253,10},{24257,10},{24261,10},{24265,10}];
		Lv == 4 -> [{24218,7},{24222,7},{24226,7},{24230,6},{24234,3},{24236,3},{24238,3},{24240,3},{24242,7},{24246,7},{24250,7},{24254,10},{24258,10},{24262,10},{24266,10}];
	   true -> [{0,0}]
	end,
	util:get_random_list_probability(SkillIdList,1).
	   
%%学习技能的前置----学习技能的个数
get_batt_skill_num(Aptitude) ->
	if Aptitude >= 20 andalso Aptitude =< 34 -> 1;
	   Aptitude >= 35 andalso Aptitude =< 44 -> 2;
	   Aptitude >= 45 andalso Aptitude =< 54 -> 3;
	   Aptitude >= 55 andalso Aptitude =< 64 -> 4;
	   Aptitude >= 65 andalso Aptitude =< 74 -> 5;
	   Aptitude >= 75 -> 6;
	   true -> 0
	end.

%%所有灵兽战斗技能
get_all_batt_skill_list() ->
	AllPetBattSkillList = [
	 {zj,[{24215,1},{24216,2},{24217,3},{24218,4}]},
	 {pj,[{24219,1},{24220,2},{24221,3},{24222,4}]},
	 {jt,[{24223,1},{24224,2},{24225,3},{24226,4}]},
	 {shny,[{24227,1},{24228,2},{24229,3},{24230,4}]},
	 {xx,[{24231,1},{24232,2},{24233,3},{24234,4}]},
	 {jy,[{24235,3},{24236,4}]},
	 {ds,[{24237,3},{24238,4}]},
	 {cm,[{24239,3},{24240,4}]},
	 {ch,[{24241,3},{24242,4}]},
	 {xr,[{24243,1},{24244,2},{24245,3},{24246,4}]},
	 {gs,[{24247,1},{24248,2},{24249,3},{24250,4}]},
	 {dkxy,[{24251,1},{24252,2},{24253,3},{24254,4}]},
	 {dkcm,[{24255,1},{24256,2},{24257,3},{24258,4}]},
	 {dkds,[{24259,1},{24260,2},{24261,3},{24262,4}]},
	 {dkch,[{24263,1},{24264,2},{24265,3},{24266,4}]}	 
	 ],
	AllPetBattSkillList.

%%查询技能对应的等级
get_get_all_batt_skill_lv(SkillId) ->
	AllPetBattSkillList = get_all_batt_skill_list(),
	F1 = fun(SkillIdLvList) ->
				case lists:keyfind(SkillId, 1, SkillIdLvList) of
					false -> 0;
					{_SkillId,Lv} -> Lv
				end
		 end,
	lists:sum([F1(SkillIdLvList) ||{_Key,SkillIdLvList} <- AllPetBattSkillList]).

%%根据技能id列表查询灵兽战斗技能类型
get_pet_batt_skill_type(SkillIdList) ->
	if SkillIdList == [] ->[];
	   true ->
		   AllPetBattSkillList = get_all_batt_skill_list(),
		   F = fun(SkillId) ->
					   F1 = fun(Key,SkillIdLvList) ->
										case lists:keyfind(SkillId, 1, SkillIdLvList) of
											false -> [];
											{SkillId,_Lv} -> Key
										end
								end,
					   AllPetBattSkillList1 = [F1(Key,SkillIdLvList) ||{Key,SkillIdLvList} <- AllPetBattSkillList],
					   AllPetBattSkillList2 = [Key1 ||Key1 <- AllPetBattSkillList1,Key1 /= []],
					   if AllPetBattSkillList2 == [] -> [];
						  true ->
							  [H|_] = AllPetBattSkillList2,
							  H
					   end
			   end,
		  ResultList = [F(SkillId) ||SkillId <- SkillIdList],
		  if ResultList == [[]] -> ResultList1 = [];
			 true -> ResultList1 = [Key2 ||Key2 <- ResultList,Key2 /= []]
		  end,
		  ResultList1
end.

%%根据技能id列表查询此类型的技能id列表
get_pet_batt_skill_type_skillIds(SkillId) ->
	AllPetBattSkillList = get_all_batt_skill_list(),
	KeyList = get_pet_batt_skill_type([SkillId]),
	if KeyList == [] -> [];
	   true ->
		   [Key | _] = KeyList,
		   case lists:keyfind(Key, 1, AllPetBattSkillList) of
			   false -> [];
			   {Key,SkillIdLvList} -> 
				   lists:flatten([SkillId1 || {SkillId1,_Lv1} <-SkillIdLvList])
		   end
	end.
	
%%根据战斗技能id查询下一级的战斗技能id
get_next_pet_batt_skill(SkillId)  ->
	SkillIdList = get_pet_batt_skill_type_skillIds(SkillId), 
	Size = length(SkillIdList),
	if SkillIdList == [] orelse SkillId == 0 -> 0;
	   true ->
		   F = fun(Num) ->
					   SkillId1 = lists:nth(Num, SkillIdList),
					   if SkillId1 == SkillId ->Num;
						  true -> 0
					   end
			   end,
		   Order = lists:sum([F(Num)||Num <- lists:seq(1, Size)]),
		   
		   if Order == 0 orelse Order == Size -> 0;
			  true -> lists:nth(Order+1, SkillIdList)
		   end		   
	end.

%%查询元素在列表中的位置
get_pos_list(Elelm,List) ->
	Size = length(List),
	F = fun(Num) ->
				Elelm1 = lists:nth(Num,List),
				if Elelm1 == Elelm ->Num;
				   true -> 0
				end
		end,
	Order = lists:sum([F(Num)||Num <- lists:seq(1, Size)]),
	Order.
		   

%%根据战斗技能类型查询灵兽身上的技能id
get_pet_batt_skill_id(Batt_skill_type,Batt_skill)  ->
	if Batt_skill == [] -> 
		   0;
	   true ->
		   loop_batt_skill_type(Batt_skill,Batt_skill_type,0) 
	end.
	
	
loop_batt_skill_type([],_Batt_skill_type,SkillId) ->
	SkillId;
loop_batt_skill_type([H|Rest],Batt_skill_type,NewSkillId) ->
	[Type] = get_pet_batt_skill_type([H]),
	if Type == Batt_skill_type ->
		   loop_batt_skill_type([],Batt_skill_type,H);
	   true ->
		   loop_batt_skill_type(Rest,Batt_skill_type,NewSkillId)
	end.
	