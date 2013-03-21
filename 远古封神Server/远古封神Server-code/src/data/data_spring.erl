%% Author: xianrongMai
%% Created: 2011-8-3
%% Description: TODO: Add description to data_spring
-module(data_spring).

%%
%% Include files
%%
-include("common.hrl").
-include("hot_spring.hrl").
%%
%% Exported Functions
%%
-export([get_spring_expspi/4]).

%%
%% API Functions
%%
%%计算温泉经验灵力
get_spring_expspi(Lv, Vip, Site, AddType) ->
	BExp = 
		case Lv of
			30 -> 444;
			31 -> 579;
			32 -> 581;
			33 -> 633;
			34 -> 696;
			35 -> 707;
			36 -> 721;
			37 -> 773;
			38 -> 788;
			39 -> 823;
			40 -> 831;
			41 -> 858;
			42 -> 885;
			43 -> 899;
			44 -> 909;
			45 -> 1283;
			46 -> 1316;
			47 -> 1336;
			48 -> 1341;
			49 -> 1346;
			50 -> 2109;
			51 -> 2225;
			52 -> 2326;
			53 -> 2417;
			54 -> 2489;
			55 -> 2825;
			56 -> 2914;
			57 -> 3198;
			58 -> 3339;
			59 -> 3466;
			60 -> 3546;
			61 -> 3589;
			62 -> 3867;
			63 -> 3879;
			64 -> 4025;
			65 -> 4335;
			66 -> 4474;
			67 -> 4621;
			68 -> 4764;
			69 -> 4897;
			70 -> 4916;
			71 -> 5084;
			72 -> 5595;
			73 -> 5948;
			74 -> 5963;
			75 -> 5969;
			76 -> 5970;
			77 -> 5976;
			78 -> 6261;
			79 -> 6364;
			80 -> 6637;
			81 -> 6722;
			82 -> 6764;
			83 -> 6884;
			84 -> 6902;
			85 -> 6990;
			86 -> 7055;
			87 -> 7083;
			88 -> 7162;
			89 -> 7243;
			90 -> 7312;
			91 -> 7370;
			92 -> 7372;
			93 -> 7416;
			94 -> 7506;
			95 -> 7659;
			96 -> 7961;
			97 -> 8245;
			98 -> 8501;
			99 -> 8747;
			_ -> 00
		end,
	Param = 
		case Site of
			4 ->%%普通区域，任何人都是一样的经验
				1;
			3 ->%%一般VIP区域
				case Vip of
					5 ->%%三天体验卡
						1.1;
					1 ->%%月卡
						1.1;
					4 ->%%周卡
						1.1;
					2 ->%%季卡
						1.2;
					3 ->%%半年卡
						1.3;
					_ ->
						0
				end;
			2 ->%%钻石VIP区
				case Vip of
					3 ->%%半年卡
						1.3;
					_ ->
						0
				end;
			_ ->
				0
		end,
	ExpBase = tool:ceil(BExp * Param),
	SpiBase = tool:ceil(ExpBase * 2),
	Result = 
	case AddType of
		0 ->%%发起动作的
			{tool:ceil(ExpBase * 1.5),tool:ceil(SpiBase * 1.5)};
		1 ->
			{ExpBase, SpiBase}
	end,
	%%二月活动
	%%活动六：温泉双倍经验	
	lib_activities:lantern_spring_award(Result).
				
				



%%
%% Local Functions
%%

