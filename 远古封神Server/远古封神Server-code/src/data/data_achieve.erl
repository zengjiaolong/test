%% Author: xianrongMai
%% Created: 2011-6-29
%% Description: 获取当前对应的成就奖励的成就点
-module(data_achieve).

%%
%% Include files
%%
-include("achieve.hrl").
%%
%% Exported Functions
%%
-export([get/2,
		 get_treasure_id/2,
		 make_update_list/1,
		 get_pearl_add/1,
		 get_love_id/1,
		 get_achtitle_expi/1,
		 get_pearl_equiped_ornot/1]).

%%
%% API Functions
%%
get(AType, SAType) ->
	case AType of
		1 ->
			case SAType of
				1 -> 5;
				2 -> 20;
				3 -> 40;
				4 -> 20;
				5 -> 40;
				6 -> 60;
				7 -> 20;
				8 -> 40;
				9 -> 60;
				10 -> 20;
				11 -> 40;
				12 -> 20;
				13 -> 40;
				14 -> 20;
				15 -> 40;
				16 -> 20;
				17 -> 40;
				18 -> 20;
				19 -> 40;
				20 ->5;
				21 ->5;
				22 ->5;
				23 ->5;
				24 ->5;
				25 ->5;
				26 ->5;
				27 ->5;
				28 -> 100;
				_ -> 0
			end;
		2 ->
			case SAType of
				1 -> 20;
				2 -> 10;
				3 -> 10;
				4 -> 20;
				5 -> 40;
				6 -> 60;
				7 -> 20;
				8 -> 40;
				9 -> 60;
				10 -> 80;
				11 -> 20;
				12 -> 40;
				13 -> 60;
				14 -> 80;
				15 -> 15;
				16 -> 30;
				17 -> 20;
				18 -> 40;
				19 -> 60;
				20 -> 80;
				21 -> 10;
				22 -> 40;
				23 -> 80;
				24 -> 5;
				25 -> 70;
				26 -> 80;
				27 -> 45;
				28 -> 100;
				_ -> 0
			end;
		3 ->
			case SAType of
				1 -> 20;
				2 -> 40;
				3 -> 40;
				4 -> 40;
				5 -> 40;
				6 -> 40;
				7 -> 40;
				8 -> 40;
				9 -> 20;
				10 -> 20;
				11 -> 30;
				12 -> 20;
				13 -> 40;
				14 -> 20;
				15 -> 40;
				16 -> 60;
				17 -> 20;
				18 -> 40;
				19 -> 60;
				20 -> 20;
				21 -> 40;
				22 -> 60;
				23 -> 10;
				24 -> 20;
				25 -> 30;
				26 -> 10;
				27 -> 20;
				28 -> 30;
				29 -> 10;
				30 -> 20;
				31 -> 40;
				32 -> 60;
				33 -> 5;
				34 -> 5;
				35 -> 5;
				36 -> 5;
				37 -> 5;
				38 -> 5;
				39 -> 5;
				40 -> 40;
				41 -> 5;
				42 -> 40;
				43 -> 5;
				44 -> 5;
				45 -> 5;
				46 -> 5;
				47 -> 5;
				48 -> 5;
				49 -> 20;
				50 -> 40;
				51 -> 60;
				52 -> 40;
				53 -> 10;
				54 -> 40;
				55 -> 60;
				56 -> 10;
				57 -> 40;
				58 -> 60;
				59 -> 60;
				60 -> 5;
				61 -> 40;
				62 -> 5;
				63 -> 40;
				64 -> 100;
				_ -> 0
			end;
		4 ->
			case SAType of
				1 -> 10;
				2 -> 20;
				3 -> 40;
				4 -> 60;
				5 -> 20;
				6 -> 40;
				7 -> 20;
				8 -> 40;
				9 -> 60;
				10 -> 20;
				11 -> 40;
				12 -> 60;
				13 -> 20;
				14 -> 40;
				15 -> 20;
				16 -> 40;
				17 -> 60;
				18 -> 80;
				19 -> 20;
				20 -> 40;
				21 -> 60;
				22 -> 80;
				23 -> 5;
				24 -> 5;
				25 -> 5;
				26 -> 100;
				_ -> 0
			end;
		5 ->
			case SAType of
				1 -> 40;
				2 -> 60;
				3 -> 80;
				4 -> 20;
				5 -> 40;
				6 -> 40;
				7 -> 40;
				8 -> 40;
				9 -> 40;
				10 -> 20;
				11 -> 40;
				12 -> 10;
				13 -> 20;
				14 -> 40;
				15 -> 20;
				16 -> 40;
				17 -> 20;
				18 -> 40;
				19 -> 80;
				20 -> 40;
				21 -> 5;
				22 -> 5;
				23 -> 5;
				24 -> 5;
				25 -> 5;
				26 -> 5;
				27 -> 5;
				28 -> 5;
				29 -> 40;
				30 -> 60;
				31 -> 5;
				32 -> 20;
				33 -> 40;
				34 -> 60;
				35 -> 20;
				36 -> 40;
				37 -> 60;
				38 -> 5;
				39 -> 5;
				40 -> 10;
				41 -> 20;
				42 -> 30;
				43 -> 40;
				44 -> 50;
				45 -> 60;
				46 -> 70;
				47 -> 80;
				48 -> 40;
				49 -> 80;
				50 -> 80;
				51 -> 100;
				_ -> 0
			end;
		6 ->
			case SAType of
				1 -> 10;
				2 -> 40;
				3 -> 60;
				4 -> 20;
				5 -> 60;
				6 -> 10;
				7 -> 20;
				8 -> 40;
				9 -> 10;
				10 -> 20;
				11 -> 60;
				12 -> 10;
				13 -> 20;
				14 -> 40;
				15 -> 10;
				16 -> 40;
				17 -> 10;
				18 -> 40;
				19 -> 20;
				20 -> 40;
				21 -> 20;
				22 -> 40;
				23 -> 40;
				24 -> 5;
				25 -> 5;
				26 -> 5;
				27 -> 5;
				28 -> 10;
				29 -> 40;
				30 -> 10;
				31 -> 40;
				32 -> 80;		
				33 -> 100;
				_ -> 0
			end;
		_ ->
			0
	end.
		
%%获取数据表更新的valuelist,elem -> {AType,SAType,NewNum}
make_update_list(List) ->
	lists:foldl(fun(Elem,AccIn) ->
						{AType,SAType,NewNum} = Elem,
						Result = get_update(AType,SAType,NewNum),
						[Result|AccIn]
				end,[],List).
%%
%% Local Functions
%%
get_update(AType, SAType, NewNum) ->
	case AType of
		1 ->
			case SAType of
				1 -> {t1, NewNum};
				2 -> {t2, NewNum};
				3 -> {t3, NewNum};
				4 -> {t4, NewNum};
				5 -> {t5, NewNum};
				6 -> {t6, NewNum};
				7 -> {t7, NewNum};
				8 -> {t8, NewNum};
				9 -> {t9, NewNum};
				10 -> {t10, NewNum};
				11 -> {t11, NewNum};
				12 -> {t12, NewNum};
				13 -> {t13, NewNum};
				14 -> {t14, NewNum};
				15 -> {t15, NewNum};
				16 -> {t16, NewNum};
				17 -> {t17, NewNum};
				18 -> {t18, NewNum};
				19 -> {t19, NewNum};
				20 -> {t20, NewNum};
				21 -> {t21, NewNum};
				22 -> {t22, NewNum};
				23 -> {t23, NewNum};
				24 -> {t24, NewNum};
				25 -> {t25, NewNum};
				26 -> {t26, NewNum};
				27 -> {t27, NewNum};
				28 -> {tf, NewNum}
			end;
		2 ->
			case SAType of
				1 -> {e1, NewNum};
				2 -> {e2, NewNum};
				3 -> {e3, NewNum};
				4 -> {e4, NewNum};
				5 -> {e5, NewNum};
				6 -> {e6, NewNum};
				7 -> {e7, NewNum};
				8 -> {e8, NewNum};
				9 -> {e9, NewNum};
				10 -> {e10, NewNum};
				11 -> {e11, NewNum};
				12 -> {e12, NewNum};
				13 -> {e13, NewNum};
				14 -> {e14, NewNum};
				15 -> {e15, NewNum};
				16 -> {e16, NewNum};
				17 -> {e17, NewNum};
				18 -> {e18, NewNum};
				19 -> {e19, NewNum};
				20 -> {e20, NewNum};
				21 -> {e21, NewNum};
				22 -> {e22, NewNum};
				23 -> {e23, NewNum};
				24 -> {e24, NewNum};
				25 -> {e25, NewNum};
				26 -> {e26, NewNum};
				27 -> {e27, NewNum};
				28 -> {ef, NewNum}
			end;
		3 ->
			case SAType of
				1 -> {tr1, NewNum};	
				2 -> {tr2, NewNum};	
				3 -> {tr3, NewNum};	
				4 -> {tr4, NewNum};	
				5 -> {tr5, NewNum};	
				6 -> {tr6, NewNum};	
				7 -> {tr7, NewNum};	
				8 -> {tr8, NewNum};	
				9 -> {tr9, NewNum};	
				10 -> {tr10, NewNum};	
				11 -> {tr11, NewNum};	
				12 -> {tr12, NewNum};	
				13 -> {tr13, NewNum};	
				14 -> {tr14, NewNum};	
				15 -> {tr15, NewNum};	
				16 -> {tr16, NewNum};	
				17 -> {tr17, NewNum};	
				18 -> {tr18, NewNum};	
				19 -> {tr19, NewNum};	
				20 -> {tr20, NewNum};	
				21 -> {tr21, NewNum};	
				22 -> {tr22, NewNum};	
				23 -> {tr23, NewNum};	
				24 -> {tr24, NewNum};	
				25 -> {tr25, NewNum};	
				26 -> {tr26, NewNum};	
				27 -> {tr27, NewNum};	
				28 -> {tr28, NewNum};	
				29 -> {tr29, NewNum};	
				30 -> {tr30, NewNum};	
				31 -> {tr31, NewNum};	
				32 -> {tr32, NewNum};
				33 -> {tr33, NewNum};
				34 -> {tr34, NewNum};
				35 -> {tr35, NewNum};
				36 -> {tr36, NewNum};
				37 -> {tr37, NewNum};
				38 -> {tr38, NewNum};
				39 -> {tr39, NewNum};
				40 -> {tr40, NewNum};
				41 -> {tr41, NewNum};
				42 -> {tr42, NewNum};
				43 -> {tr43, NewNum};
				44 -> {tr44, NewNum};
				45 -> {tr45, NewNum};
				46 -> {tr46, NewNum};
				47 -> {tr47, NewNum};
				48 -> {tr48, NewNum};
				49 -> {tr49, NewNum};
				50 -> {tr50, NewNum};
				51 -> {tr51, NewNum};
				52 -> {tr52, NewNum};
				53 -> {tr53, NewNum};
				54 -> {tr54, NewNum};
				55 -> {tr55, NewNum};
				56 -> {tr56, NewNum};
				57 -> {tr57, NewNum};
				58 -> {tr58, NewNum};
				59 -> {tr59, NewNum};
				60 -> {tr60, NewNum};
				61 -> {tr61, NewNum};
				62 -> {tr62, NewNum};
				63 -> {tr63, NewNum};
				64 -> {trf, NewNum}
			end;
		4 ->
			case SAType of
				1 -> {y1, NewNum};	
				2 -> {y2, NewNum};	
				3 -> {y3, NewNum};	
				4 -> {y4, NewNum};	
				5 -> {y5, NewNum};	
				6 -> {y6, NewNum};	
				7 -> {y7, NewNum};	
				8 -> {y8, NewNum};	
				9 -> {y9, NewNum};	
				10 -> {y10, NewNum};	
				11 -> {y11, NewNum};	
				12 -> {y12, NewNum};	
				13 -> {y13, NewNum};	
				14 -> {y14, NewNum};	
				15 -> {y15, NewNum};	
				16 -> {y16, NewNum};	
				17 -> {y17, NewNum};	
				18 -> {y18, NewNum};	
				19 -> {y19, NewNum};	
				20 -> {y20, NewNum};	
				21 -> {y21, NewNum};	
				22 -> {y22, NewNum};	
				23 -> {y23, NewNum};
				24 -> {y24, NewNum};
				25 -> {y25, NewNum};
				26 -> {yf, NewNum}
			end;
		5 ->
			case SAType of
				1 -> {f1, NewNum};	
				2 -> {f2, NewNum};	
				3 -> {f3, NewNum};	
				4 -> {f4, NewNum};	
				5 -> {f5, NewNum};	
				6 -> {f6, NewNum};	
				7 -> {f7, NewNum};	
				8 -> {f8, NewNum};	
				9 -> {f9, NewNum};	
				10 -> {f10, NewNum};	
				11 -> {f11, NewNum};	
				12 -> {f12, NewNum};	
				13 -> {f13, NewNum};	
				14 -> {f14, NewNum};	
				15 -> {f15, NewNum};	
				16 -> {f16, NewNum};	
				17 -> {f17, NewNum};	
				18 -> {f18, NewNum};	
				19 -> {f19, NewNum};	
				20 -> {f20, NewNum};	
				21 -> {f21, NewNum};
				22 -> {f22, NewNum};
				23 -> {f23, NewNum};
				24 -> {f24, NewNum};
				25 -> {f25, NewNum};
				26 -> {f26, NewNum};
				27 -> {f27, NewNum};
				28 -> {f28, NewNum};
				29 -> {f29, NewNum};
				30 -> {f30, NewNum};
				31 -> {f31, NewNum};
				32 -> {f32, NewNum};
				33 -> {f33, NewNum};
				34 -> {f34, NewNum};
				35 -> {f35, NewNum};
				36 -> {f36, NewNum};
				37 -> {f37, NewNum};
				38 -> {f38, NewNum};
				39 -> {f39, NewNum};
				40 -> {f40, NewNum};
				41 -> {f41, NewNum};
				42 -> {f42, NewNum};
				43 -> {f43, NewNum};
				44 -> {f44, NewNum};
				45 -> {f45, NewNum};
				46 -> {f46, NewNum};
				47 -> {f47, NewNum};
				48 -> {f48, NewNum};
				49 -> {f49, NewNum};
				50 -> {f50, NewNum};
				51 -> {ff, NewNum}
			end;
		6 ->
			case SAType of
				1 -> {in1, NewNum};	
				2 -> {in2, NewNum};	
				3 -> {in3, NewNum};	
				4 -> {in4, NewNum};	
				5 -> {in5, NewNum};	
				6 -> {in6, NewNum};	
				7 -> {in7, NewNum};	
				8 -> {in8, NewNum};	
				9 -> {in9, NewNum};	
				10 -> {in10, NewNum};	
				11 -> {in11, NewNum};	
				12 -> {in12, NewNum};	
				13 -> {in13, NewNum};	
				14 -> {in14, NewNum};	
				15 -> {in15, NewNum};	
				16 -> {in16, NewNum};	
				17 -> {in17, NewNum};	
				18 -> {in18, NewNum};	
				19 -> {in19, NewNum};	
				20 -> {in20, NewNum};	
				21 -> {in21, NewNum};	
				22 -> {in22, NewNum};	
				23 -> {in23, NewNum};	
				24 -> {in24, NewNum};
				25 -> {in25, NewNum};
				26 -> {in26, NewNum};
				27 -> {in27, NewNum};
				28 -> {in28, NewNum};
				29 -> {in29, NewNum};
				30 -> {in30, NewNum};
				31 -> {in31, NewNum};
				32 -> {in32, NewNum};
				33 -> {inf, NewNum} 
			end;
		7 ->
			case SAType of
				1 -> {ts1, NewNum};
				2 -> {ts2, NewNum};
				3 -> {ts3, NewNum};
				4 -> {ts4, NewNum};
				5 -> {ts5, NewNum};
				6 -> {ts6, NewNum};
				7 -> {ts7, NewNum};
				8 -> {ts8, NewNum};
				9 -> {ts9, NewNum};
				10 -> {ts10, NewNum};
				11 -> {ts11, NewNum};
				12 -> {ts12, NewNum};
				13 -> {ts13, NewNum};
				14 -> {ts14, NewNum};
				15 -> {ts15, NewNum};
				16 -> {ts16, NewNum};
				17 -> {ts17, NewNum};
				18 -> {ts18, NewNum};
				19 -> {ts19, NewNum};
				20 -> {ts20, NewNum};
				21 -> {ts21, NewNum};
				22 -> {ts22, NewNum};
				23 -> {ts23, NewNum};
				24 -> {ts24, NewNum};
				25 -> {ts25, NewNum};
				26 -> {ts26, NewNum};
				27 -> {ts27, NewNum};
				28 -> {ts28, NewNum}
			end;
		10 ->
			case SAType of
				1 -> {ts101, NewNum};
				2 -> {ts102, NewNum};
				3 -> {ts103, NewNum};
				4 -> {ts104, NewNum};
				5 -> {ts105, NewNum};
				6 -> {ts106, NewNum};
				7 -> {ts107, NewNum};
				8 -> {ts108, NewNum}
			end
	end.

get_treasure_id(Type, SAType) ->
	case Type of
		7 ->
			case SAType of
				1 -> {0, 28182};
				2 -> {0, 28183};
				3 -> {0, 28184};
				4 -> {0, 22000};
				5 -> {0, 22007};
				6 -> {0, 24400};
				7 -> {0, 24401};
				8 -> {0, 24104};
				9 -> {0, 24105};
				10 -> {0, 21501};
				11 -> {0, 28800};
				12 -> {0, 28801};
				13 -> {1, 30025};
				14 -> {1, 30026};
				15 -> {1, 30000};
				16 -> {1, 30001};
				17 -> {1, 30015};
				18 -> {1, 30016};
				19 -> {1, 30020};
				20 -> {1, 30021};
				21 -> {1, 30035};
				22 -> {1, 30036};
				23 -> {1, 30005};
				24 -> {1, 30006};
				25 -> {1, 30030};
				26 -> {1, 30031};
				27 -> {1, 30010};
				28 -> {1, 30011};
				_ -> {0,0}  
			end;
		10 ->
			case SAType of
				1 -> {1, 30027};
				2 -> {1, 30002};
				3 -> {1, 30017};
				4 -> {1, 30022};
				5 -> {1, 30037};
				6 -> {1, 30007};
				7 -> {1, 30032};
				8 -> {1, 30012}
			end
	end.
					
get_pearl_add(AchPearls) ->
	lists:foldl(fun(Elem, AccIn) ->
						#p_ach_pearl{add_type = AddType,
									 effect = Effect} = Elem,
						get_pearl_info(AddType, Effect, AccIn)
				end, [0,0,0,0,0,0,0,0], AchPearls).

get_pearl_info(AddType, Effect, Effects) ->
	[AchHp, AchMp, AchAtt, AchDef, AchDod, AchHit, AchCrit, AchAnti] = Effects,
	case AddType of
		hp_add ->
			[Effect, AchMp, AchAtt, AchDef, AchDod, AchHit, AchCrit, AchAnti]; %%气血
		mp_add ->
			[AchHp, Effect, AchAtt, AchDef, AchDod, AchHit, AchCrit, AchAnti]; %%法力
		att_add ->
			[AchHp, AchMp, Effect, AchDef, AchDod, AchHit, AchCrit, AchAnti]; %%攻击
		def_add ->
			[AchHp, AchMp, AchAtt, Effect, AchDod, AchHit, AchCrit, AchAnti]; %%防御
		dod_add ->
			[AchHp, AchMp, AchAtt, AchDef, Effect, AchHit, AchCrit, AchAnti]; %%闪躲
		hit_add ->
			[AchHp, AchMp, AchAtt, AchDef, AchDod, Effect, AchCrit, AchAnti]; %%命中
		crit_add ->
			[AchHp, AchMp, AchAtt, AchDef, AchDod, AchHit, Effect, AchAnti]; %%暴击
		anti_add ->
			[AchHp, AchMp, AchAtt, AchDef, AchDod, AchHit, AchCrit, Effect]; %%暴击
		_ ->
			Effects
	end.
get_pearl_equiped_ornot(AchPearls) ->
	lists:foldl(fun(Elem, AccIn) ->
						#p_ach_pearl{goods_id = GoodsTypeId,
									 add_type = AddType} = Elem,
						get_equip_ornot(GoodsTypeId, AddType, AccIn)
				end, [0,0,0,0,0,0,0,0], AchPearls).
get_equip_ornot(GoodsTypeId, AddType, Effects) ->
	[AchHp, AchMp, AchAtt, AchDef, AchDod, AchHit, AchCrit, AchAnti] = Effects,
	case AddType of
		hp_add ->
			if 
				GoodsTypeId =:= 30002 ->
					[1, AchMp, AchAtt, AchDef, AchDod, AchHit, AchCrit, AchAnti]; %%气血
				GoodsTypeId =:= 30000 ->
					[2, AchMp, AchAtt, AchDef, AchDod, AchHit, AchCrit, AchAnti]; %%气血
				GoodsTypeId =:= 30001 ->
					[3, AchMp, AchAtt, AchDef, AchDod, AchHit, AchCrit, AchAnti]; %%气血
				true ->
					Effects 
			end;
		mp_add ->
			if
				GoodsTypeId =:= 30027 ->
					[AchHp, 1, AchAtt, AchDef, AchDod, AchHit, AchCrit, AchAnti]; %%法力
				GoodsTypeId =:= 30025 ->
					[AchHp, 2, AchAtt, AchDef, AchDod, AchHit, AchCrit, AchAnti]; %%法力
				GoodsTypeId =:= 30026 ->
					[AchHp, 3, AchAtt, AchDef, AchDod, AchHit, AchCrit, AchAnti]; %%法力
				true ->
					Effects 
			end;				
		att_add ->
			if
				GoodsTypeId =:= 30032 ->
					[AchHp, AchMp, 1, AchDef, AchDod, AchHit, AchCrit, AchAnti]; %%攻击
				GoodsTypeId =:= 30030 ->
					[AchHp, AchMp, 2, AchDef, AchDod, AchHit, AchCrit, AchAnti]; %%攻击
				GoodsTypeId =:= 30031 ->
					[AchHp, AchMp, 3, AchDef, AchDod, AchHit, AchCrit, AchAnti]; %%攻击
				true ->
					Effects
			end;
		def_add ->
			if
				GoodsTypeId =:= 30017 ->
					[AchHp, AchMp, AchAtt, 1, AchDod, AchHit, AchCrit, AchAnti]; %%防御
				GoodsTypeId =:= 30015 ->
					[AchHp, AchMp, AchAtt, 2, AchDod, AchHit, AchCrit, AchAnti]; %%防御
				GoodsTypeId =:= 30016 ->
					[AchHp, AchMp, AchAtt, 3, AchDod, AchHit, AchCrit, AchAnti]; %%防御
				true ->
					Effects
			end;
		dod_add ->
			if
				GoodsTypeId =:= 30022 ->
					[AchHp, AchMp, AchAtt, AchDef, 1, AchHit, AchCrit, AchAnti]; %%闪躲
				GoodsTypeId =:= 30020 ->
					[AchHp, AchMp, AchAtt, AchDef, 2, AchHit, AchCrit, AchAnti]; %%闪躲
				GoodsTypeId =:= 30021 ->
					[AchHp, AchMp, AchAtt, AchDef, 3, AchHit, AchCrit, AchAnti]; %%闪躲
				true ->
					Effects
			end;
		hit_add ->
			if
				GoodsTypeId =:= 30037 ->
					[AchHp, AchMp, AchAtt, AchDef, AchDod, 1, AchCrit, AchAnti]; %%命中
				GoodsTypeId =:= 30035 ->
					[AchHp, AchMp, AchAtt, AchDef, AchDod, 2, AchCrit, AchAnti]; %%命中
				GoodsTypeId =:= 30036 ->
					[AchHp, AchMp, AchAtt, AchDef, AchDod, 3, AchCrit, AchAnti]; %%命中
				true ->
					Effects
			end;
		crit_add ->
			if 
				GoodsTypeId =:= 30007 ->
					[AchHp, AchMp, AchAtt, AchDef, AchDod, AchHit, 1, AchAnti]; %%暴击
				GoodsTypeId =:= 30005 ->
					[AchHp, AchMp, AchAtt, AchDef, AchDod, AchHit, 2, AchAnti]; %%暴击
				GoodsTypeId =:= 30006 ->
					[AchHp, AchMp, AchAtt, AchDef, AchDod, AchHit, 3, AchAnti]; %%暴击
				true ->
					Effects
			end;
		anti_add ->
			if
				GoodsTypeId =:= 30012 ->
					[AchHp, AchMp, AchAtt, AchDef, AchDod, AchHit, AchCrit, 1]; %%抗性
				GoodsTypeId =:= 30010 ->
					[AchHp, AchMp, AchAtt, AchDef, AchDod, AchHit, AchCrit, 2]; %%抗性
				GoodsTypeId =:= 30011 ->
					[AchHp, AchMp, AchAtt, AchDef, AchDod, AchHit, AchCrit, 3]; %%抗性
				true ->
					Effects
			end;
		_ ->
			Effects
	end.

get_love_id(TitleId) ->
	case TitleId of
		28035 -> 801;	%%"人气王子"
		28036 -> 802;	%%"人气宝贝"
		28037 -> 803;	%%"多情公子"
		28038 -> 804	%%"魅力宝宝"
	end.
get_achtitle_expi(AchNum) ->
	IsExist = lists:member(AchNum, ?PLYAER_TITLES_MEMBERS),
	if 
		IsExist =:= false ->
			1;
		true ->
			case AchNum of
				%%普通称号
				801 -> 432000;%%人气王子
				802 -> 432000;%%人气宝贝
				803 -> 604800;%%多情公子
				804 -> 604800;%%魅力宝宝
				%%特殊称号
				901 -> 259200;	%%封神霸主
				902 -> 259200;	%%天下无敌
				903 -> 259200;	%%女娲英雄
				904 -> 259200; 	%%神农英雄
				905 -> 259200; 	%%伏羲英雄
				906 -> 259200; 	%%不差钱
				907 -> 259200; 	%%八神之主
				908 -> 259200; 	%%绝世神兵
				909 -> 259200; 	%%诛仙霸主
				910 -> 259200;	%%全民偶像
				911 -> 259200;	%%全民公敌
				912 -> 259200;	%%远古战神
				913 -> 259200;	%%九霄城主
				914 -> 259200;	%%天下第一
				915 -> 604800;	%%远古无双
				916 -> 259200	%%一骑绝尘
			end
	end.
