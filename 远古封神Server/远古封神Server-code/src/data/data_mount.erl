%%%---------------------------------------
%%% @Module  : data_mount
%%% @Author  : ygzj
%%% @Created : 2011.12.23
%%% @Description:  坐骑配置
%%%---------------------------------------
-module(data_mount).
-compile(export_all).
-include("record.hrl").  

get_upgrade_exp(Level) ->
	[Exp,Feeds] = 
	case Level of 
		1 ->[50,5];
		2 ->[60,6];
		3 ->[70,7];
		4 ->[80,8];
		5 ->[100,10];
		6 ->[120,	12];
		7 ->[140,14];
		8 ->[170,17];
		9 ->[200,20];
		10 ->[230,23];
		11 ->[270,	27];
		12 ->[310,	31];
		13 ->[350,	35];
		14 ->[400,	40];
		15 ->[450,	45];
		16 ->[500,	50];
		17 ->[560,	56];
		18 ->[620,62];
		19 ->[680,	68];
		20 ->[750,	75];
		21 ->[820,	82];
		22 ->[890,	89];
		23 ->[970,	97];
		24 ->[1050,105];
		25 ->[1130,113];
		26 ->[1220,122];
		27 ->[1310,131];
		28 ->[1400,140];
		29 ->[1500,150];
		30 ->[1600,160];
		31 ->[1700,170];
		32 ->[1810,181];
		33 ->[1920,192];
		34 ->[2030,203];
		35 ->[2150,215];
		36 ->[2270,227];
		37 ->[2390,239];
		38 ->[2520,252];
		39 ->[2650,265];
		40 ->[2780,278];
		41 ->[2920,292];
		42 ->[3060,306];
		43 ->[3200,320];
		44 ->[3350,335];
		45 ->[3500,350];
		46 ->[3650,365];
		47 ->[3810,381];
		48 ->[3970,397];
		49 ->[4130,413];
		50 ->[4300,430];
		51 ->[4470,447];
		52 ->[4640,464];
		53 ->[4820,482];
		54 ->[5000,500];
		55 ->[5180,518];
		56 ->[5370,537];
		57 ->[5560,556];
		58 ->[5750,575];
		59 ->[5950,595];
		60 ->[6150,615];
		61 ->[6350,635];
		62 ->[6560,656];
		63 ->[6770,677];
		64 ->[6980,698];
		65 ->[7200,720];
		66 ->[7420,742];
		67 ->[7640,764];
		68 ->[7870,787];
		69 ->[8100,810];
		70 ->[8330,833];
		71 ->[8570,857];
		72 ->[8810,881];
		73 ->[9050,905];
		74 ->[9300,930];
		75 ->[9550,955];
		76 ->[9800,980];
		77 ->[10060,1006];
		78 ->[10320,1032];
		79 ->[10580,1058];
		80 ->[10850,1085];
		81 ->[11120,1112];
		82 ->[11390,1139];
		83 ->[11670,1167];
		84 ->[11950,1195];
		85 ->[12230,1223];
		86 ->[12520,1252];
		87 ->[12810,1281];
		88 ->[13100,1310];
		89 ->[13400,1340];
		90 ->[13700,1370];
		91 ->[14000,1400];
		92 ->[14310,1431];
		93 ->[14620,1462];
		94 ->[14930,1493];
		95 ->[15250,1525];
		96 ->[15570,1557];
		97 ->[15890,1589];
		98 ->[16220,1622];
		99 ->[16550,1655];
		_ ->[1000000,100000]
	end,
	[Exp,Feeds].

%%下一级所需经验(改成根据人物经验的计算升级经验)
get_level_need_exp(Level) ->
%% 	[Exp,_Foods] = get_upgrade_exp(Level),
%% 	Exp.
	round(lib_player:next_lv_exp(Level)*0.02).

%%下一级所需口粮个数
get_next_level_need_food(Level) ->
	[_Exp,Foods] = get_upgrade_exp(Level),
	Foods.

%%进阶所需等级要求
get_need_level(Step) ->
	if Step =< 1 ->
		   1;
	   true ->
		   (Step-1)*5
	end.
	
%%原坐骑转换获取默认的除数
get_transfer_step(GoodsTypeId) ->
	if 
	   GoodsTypeId == 16000 -> 1;
	   GoodsTypeId == 16001 -> 2;
	   GoodsTypeId == 16002 -> 2;
	   GoodsTypeId == 16003 -> 2;
	   GoodsTypeId == 16006 -> 2;
	   GoodsTypeId == 16007 -> 2;
	   GoodsTypeId == 16008 -> 2;
	   GoodsTypeId == 16004 -> 2;
	   GoodsTypeId == 16005 -> 2;
	   GoodsTypeId == 16009 -> 2;
	   GoodsTypeId == 16010 -> 2;
	   true -> 2
	end.
	   


%%通过技能id取名字
get_skill_name_color(Step) ->
	case Step of
		1 ->%%白
			"#ffffff";
		2 ->%%绿			
			"#00ff33";
		3 ->%%蓝
			"#313bdd";
		4 ->%%金
			"#f8ef38";
		5 ->%%紫
			"#8800ff";
		_ ->%%白
			"#ffffff"
	end.

%%取兽魄值
get_4sp_val(Step) ->
	[_TotalValue,_Average,_MaxVlaue] = 
	case Step of
		1 -> [600,150,225];
		2 -> [800,200,300];
		3 -> [1000,250,375];
		4 -> [1400,350,525];
		5 -> [2000,500,750];
		6 -> [2800,700,1050];
		7 -> [3800,950,1425];
		8 -> [5000,1250,1875];
		9 -> [6400,1600,2400];
		10 -> [8000,2000,3000];
		_  -> [8000,2000,3000]
	end.

%%取兽魄最大值
get_max_4sp_val(Step)	 ->
	[TotalValue,_Average,_MaxVlaue] = get_4sp_val(Step),
	TotalValue.

%%取幸运值
get_max_luck_val(Step) ->
	case Step of
		1 -> 150;
		2 -> 150;
		3 -> 300;
		4 -> 400;
		5 -> 500;
		6 -> 600;
		7 -> 700;
		8 -> 800;
		9 -> 800;
		_ -> 800
	end.
			
	
%%进阶阶数对应的速度
get_step_speed(Step) ->
	case Step of
		0 -> 0;
		1 -> 30;
		2 -> 45;
		3 -> 55;
		_ -> 65
	end.

%%进阶所需材料和数量(1-3阶进阶需要飞灵丹，4阶及以上进阶需要飞灵仙丹)
%%进阶所需条件(物品类型,数量,铜币)
get_need_cond_step(Step) ->
	[_Goods_id,_Num,_Coin] = 
	case Step of
		2 -> [24822,3,2000];
		3 -> [24822,5,4000];
		4 -> [24823,3,6000];
		5 -> [24823,4,10000];
		6 -> [24823,5,15000];
		7 -> [24823,8,30000];
		8 -> [24823,10,50000];
		9 -> [24823,15,80000];
		_ -> [24823,20,120000]
	end.
		
%%进阶操作成功率(根据幸运值计算) 
get_ratio_by_luck_step(Step,Luck_val) ->
	Platform = config:get_platform_name(), 
	Ratio = 
	if Platform == "cmwebgame" ->
		   case Step of
			   1 ->
				   if Luck_val >= 0 andalso Luck_val =< 55 ->
						  0;
					  Luck_val > 55 andalso Luck_val =< 75 ->
						  7;
					  Luck_val > 75 andalso Luck_val =< 100 ->
						  11;
					  Luck_val > 100 andalso Luck_val =< 125 ->
						  16;
					  Luck_val > 125 andalso Luck_val < 150 ->
						  25;
					  Luck_val >= 150  ->
						  100;
					  true ->
						  0
				   end;
			   2 ->
				   if Luck_val >= 0 andalso Luck_val =< 80 ->
						  0;
					  Luck_val > 80 andalso Luck_val =< 100 ->
						  5;
					  Luck_val > 100 andalso Luck_val =< 130 ->
						  15;
					  Luck_val > 130 andalso Luck_val < 150 ->
						  20;
					  Luck_val >= 150  ->
						  100;
					  true ->
						  0
				   end;
			   3 ->
				   if Luck_val >= 0 andalso Luck_val =< 100 ->
						  0;
					  Luck_val > 100 andalso Luck_val =< 125 ->
						  2;
					  Luck_val > 125 andalso Luck_val =< 150 ->
						  5;
					  Luck_val > 150  andalso Luck_val =< 175 ->
						  5;
					  Luck_val > 175  andalso Luck_val =< 200 ->
						  8;
					  Luck_val > 200  andalso Luck_val =< 225 ->
						  12;
					  Luck_val > 225  andalso Luck_val =< 250 ->
						  12;
					  Luck_val > 250  andalso Luck_val =< 275 ->
						  15;
					  Luck_val > 275  andalso Luck_val < 300 ->
						  15;
					  Luck_val >= 300   ->
						  100;
					  true ->
						  0
				   end;
			   4 ->
				   if Luck_val >= 0 andalso Luck_val =< 150 ->
						  0;
					  Luck_val > 150  andalso Luck_val =< 175 ->
						  1;
					  Luck_val > 175  andalso Luck_val =< 200 ->
						  1;
					  Luck_val > 200  andalso Luck_val =< 225 ->
						  3;
					  Luck_val > 225  andalso Luck_val =< 250 ->
						  3;
					  Luck_val > 250  andalso Luck_val =< 275 ->
						  3;
					  Luck_val > 275  andalso Luck_val =< 300 ->
						  7;
					  Luck_val > 300   andalso Luck_val =< 325 ->
						  10;
					  Luck_val > 325   andalso Luck_val =< 350 ->
						  10;
					  Luck_val > 350   andalso Luck_val =< 375 ->
						  15;
					  Luck_val > 375   andalso Luck_val < 400 ->
						  15;
					  Luck_val >= 400 ->
						  100;
					  true ->
						  0
				   end;
			   5 ->
				   if Luck_val >= 0 andalso Luck_val =< 375 ->
						  0;
					  Luck_val > 375   andalso Luck_val =< 400 ->
						  3;
					  Luck_val > 400 andalso Luck_val =< 425 ->
						  5;
					  Luck_val > 425 andalso Luck_val =< 450 ->
						  5;
					  Luck_val > 450 andalso Luck_val =< 475 ->
						  7;
					  Luck_val > 475 andalso Luck_val < 500 ->
						  7;
					  Luck_val >= 500 ->
						  100;
					  true ->
						  0
				   end;
			   6 ->
				   if Luck_val >= 0 andalso Luck_val =< 375 ->
						  0;
					  Luck_val > 375   andalso Luck_val =< 400 ->
						  2;
					  Luck_val > 400 andalso Luck_val =< 425 ->
						  3;
					  Luck_val > 425 andalso Luck_val =< 450 ->
						  3;
					  Luck_val > 450 andalso Luck_val =< 475 ->
						  6;
					  Luck_val > 475 andalso Luck_val =< 500 ->
						  6;
					  Luck_val > 500 andalso Luck_val =< 525 ->
						  8;
					  Luck_val > 525 andalso Luck_val =< 550 ->
						  8;
					  Luck_val > 550 andalso Luck_val =< 575 ->
						  15;
					  Luck_val > 575 andalso Luck_val < 600 ->
						  15;
					  Luck_val >= 600 ->
						  100;
					  true ->
						  0
				   end;
			   7 ->
				   if Luck_val >= 0 andalso Luck_val =< 450 ->
						  0;
					  Luck_val > 450 andalso Luck_val =< 475 ->
						  2;
					  Luck_val > 475 andalso Luck_val =< 500 ->
						  2;
					  Luck_val > 500 andalso Luck_val =< 525 ->
						  5;
					  Luck_val > 525 andalso Luck_val =< 550 ->
						  5;
					  Luck_val > 550 andalso Luck_val =< 575 ->
						  8;
					  Luck_val > 575 andalso Luck_val =< 600 ->
						  8;
					  Luck_val > 600 andalso Luck_val =< 625 ->
						  10;
					  Luck_val > 625 andalso Luck_val =< 650 ->
						  10;
					  Luck_val > 650 andalso Luck_val =< 675 ->
						  15;
					  Luck_val > 675 andalso Luck_val < 700 ->
						  15;
					  Luck_val >= 700 ->
						  100;
					  true ->
						  0
				   end;
			   8 ->
				   if Luck_val >= 0 andalso Luck_val =< 450 ->
						  0;
					  Luck_val > 450 andalso Luck_val =< 475 ->
						  0.5;
					  Luck_val > 475 andalso Luck_val =< 500 ->
						  0.5;
					  Luck_val > 500 andalso Luck_val =< 525 ->
						  1;
					  Luck_val > 525 andalso Luck_val =< 550 ->
						  1;
					  Luck_val > 550 andalso Luck_val =< 575 ->	
						  2.5;
					  Luck_val > 575 andalso Luck_val =< 600 ->
						  2.5;
					  Luck_val > 600 andalso Luck_val =< 625 ->
						  5;
					  Luck_val > 625 andalso Luck_val =< 650 ->
						  5;
					  Luck_val > 650 andalso Luck_val =< 675 ->
						  8;
					  Luck_val > 675 andalso Luck_val =< 700 ->
						 8;
					  Luck_val > 700 andalso Luck_val =< 725 ->
						  10;
					  Luck_val > 725 andalso Luck_val =< 750 ->
						  10;
					  Luck_val > 750 andalso Luck_val =< 775 ->
						  15;
					  Luck_val > 775 andalso Luck_val < 800 ->
						  15;
					  Luck_val >= 800 ->
						  100;
					  true ->
						  0
				   end; 
			   9 ->
				   if Luck_val >= 0 andalso Luck_val =< 650 ->
						  0;
					  Luck_val > 650 andalso Luck_val =< 675 ->
						  1;
					  Luck_val > 675 andalso Luck_val =< 700 ->
						  1;
					  Luck_val > 700 andalso Luck_val =< 725 ->
						  5;
					  Luck_val > 725 andalso Luck_val =< 750 ->
						  5;
					  Luck_val > 750 andalso Luck_val =< 775 ->
						  10;
					  Luck_val > 775 andalso Luck_val < 800 ->
						  10;
					  Luck_val >= 800 ->
						  100;
					  true ->
						  0
				   end;
			   _ ->
				   0
		   end;
	   true ->
		   case Step of
			   1 ->
				   if Luck_val >= 0 andalso Luck_val =< 25 ->
						  0;
					 Luck_val > 25 andalso Luck_val =< 50 ->
						 0;
					  Luck_val > 50 andalso Luck_val =< 75 ->
						  7;
					 Luck_val > 75 andalso Luck_val =< 100 ->
						 15;
					  Luck_val > 100 andalso Luck_val =< 125 ->
						  20;
					 Luck_val > 125 andalso Luck_val < 150 ->
						 25;
					  Luck_val >= 150  ->
						  100;
					 true ->
						 0
				   end;
			   2 -> 
				   if Luck_val >= 0 andalso Luck_val =< 25 ->
				 	  	0;
			  		 Luck_val > 25 andalso Luck_val =< 50 ->
				   		0;
			   		Luck_val > 50 andalso Luck_val =< 75 ->
				   		3;
			   		Luck_val > 75 andalso Luck_val =< 100 ->
				   		9;
			   		Luck_val > 100 andalso Luck_val =< 130 ->
				   		15;
			    	Luck_val > 130 andalso Luck_val < 150 ->
				   		20;
			    	Luck_val >= 150  ->
				   		100;
					true ->
				   		0
				end;
			   3 -> 
				   if Luck_val >= 0 andalso Luck_val =< 25 ->
				   		0;
			   		Luck_val > 25 andalso Luck_val =< 50 ->
				   		0;
			   		Luck_val > 50 andalso Luck_val =< 75 ->
				   		0;
			   		Luck_val > 75 andalso Luck_val =< 100 ->
				   		0;
			   		Luck_val > 100 andalso Luck_val =< 125 ->
				   		4;
			    	Luck_val > 125 andalso Luck_val =< 150 ->
				   		4;
			    	Luck_val > 150  andalso Luck_val =< 175 ->
				   		8;
					Luck_val > 175  andalso Luck_val =< 200 ->
				   		8;
					Luck_val > 200  andalso Luck_val =< 225 ->
				   		12;
					Luck_val > 225  andalso Luck_val =< 250 ->
				   		12;
					Luck_val > 250  andalso Luck_val =< 275 ->
				   		15;
					Luck_val > 275  andalso Luck_val < 300 ->
				   		15;
					Luck_val >= 300   ->
				   		100;
					true ->
						0
				   end;
			   4 -> 
				   if Luck_val >= 0 andalso Luck_val =< 25 ->
				   		0;
			   		Luck_val > 25 andalso Luck_val =< 50 ->
				   		0;
			   		Luck_val > 50 andalso Luck_val =< 75 ->
				   		0;
					Luck_val > 75 andalso Luck_val =< 100 ->
						0;
			   		Luck_val > 100 andalso Luck_val =< 125 ->
				   		0;
			    	Luck_val > 125 andalso Luck_val =< 150 ->
				   		0;
			    	Luck_val > 150  andalso Luck_val =< 175 ->
				   		1;
					Luck_val > 175  andalso Luck_val =< 200 ->
				   		1;
					Luck_val > 200  andalso Luck_val =< 225 ->
				   		4;
					Luck_val > 225  andalso Luck_val =< 250 ->
				   		4;
					Luck_val > 250  andalso Luck_val =< 275 ->
				   		10;
					Luck_val > 275  andalso Luck_val =< 300 ->
				   		10;
					Luck_val > 300   andalso Luck_val =< 325 ->
				   		13;
					Luck_val > 325   andalso Luck_val =< 350 ->
				   		15;
					Luck_val > 350   andalso Luck_val =< 375 ->
				   		15;
					Luck_val > 375   andalso Luck_val < 400 ->
				   		20;
					Luck_val >= 400 ->
						100;
					true ->
						0
				   end;
			   5 -> 
				   if Luck_val >= 0 andalso Luck_val =< 25 ->
				   		0;
			   		Luck_val > 25 andalso Luck_val =< 50 ->
				   		0;
			   		Luck_val > 50 andalso Luck_val =< 75 ->
				   		0;
			   		Luck_val > 75 andalso Luck_val =< 100 ->
				   		0;
			   		Luck_val > 100 andalso Luck_val =< 125 ->
				   		0;
			    	Luck_val > 125 andalso Luck_val =< 150 ->
				   		0;
			    	Luck_val > 150  andalso Luck_val =< 175 ->
				   		0;
					Luck_val > 175  andalso Luck_val =< 200 ->
				   		0;
					Luck_val > 200  andalso Luck_val =< 225 ->
				   		0;
					Luck_val > 225  andalso Luck_val =< 250 ->
				   		0;
					Luck_val > 250  andalso Luck_val =< 275 ->
				   		0.5;
					Luck_val > 275  andalso Luck_val =< 300 ->
				   		0.5;
					Luck_val > 300   andalso Luck_val =< 325 ->
				   		1;
					Luck_val > 325   andalso Luck_val =< 350 ->
				   		1;
					Luck_val > 350   andalso Luck_val =< 375 ->
				   		3;
					Luck_val > 375   andalso Luck_val =< 400 ->
				   		3;
					Luck_val > 400 andalso Luck_val =< 425 ->
				   		6;
					Luck_val > 425 andalso Luck_val =< 450 ->
				   		6;
					Luck_val > 450 andalso Luck_val =< 475 ->
				   		6;
					Luck_val > 475 andalso Luck_val < 500 ->
				   		10;
					Luck_val >= 500 ->
				   		100;
					true ->
						0
				   end;
			   6 -> 
				   if Luck_val >= 0 andalso Luck_val =< 25 ->
						0;
					Luck_val > 25 andalso Luck_val =< 50 ->
				   		0;
			   		Luck_val > 50 andalso Luck_val =< 75 ->
				   		0;
			   		Luck_val > 75 andalso Luck_val =< 100 ->
				   		0;
			   		Luck_val > 100 andalso Luck_val =< 125 ->
				   		0;
			    	Luck_val > 125 andalso Luck_val =< 150 ->
				   		0;
			    	Luck_val > 150  andalso Luck_val =< 175 ->
				   		0;
					Luck_val > 175  andalso Luck_val =< 200 ->
				   		0;
					Luck_val > 200  andalso Luck_val =< 225 ->
				   		0;
					Luck_val > 225  andalso Luck_val =< 250 ->
				   		0;
					Luck_val > 250  andalso Luck_val =< 275 ->
				   		0.5;
					Luck_val > 275  andalso Luck_val =< 300 ->
				   		0.5;
					Luck_val > 300   andalso Luck_val =< 325 ->
				   		1;
					Luck_val > 325   andalso Luck_val =< 350 ->
				   		1;
					Luck_val > 350   andalso Luck_val =< 375 ->
				   		2;
					Luck_val > 375   andalso Luck_val =< 400 ->
				   		2;
					Luck_val > 400 andalso Luck_val =< 425 ->
				   		4;
					Luck_val > 425 andalso Luck_val =< 450 ->
				   		5;
					Luck_val > 450 andalso Luck_val =< 475 ->
				   		5;
					Luck_val > 475 andalso Luck_val =< 500 ->
				   		8;
					Luck_val > 500 andalso Luck_val =< 525 ->
				   		8;
					Luck_val > 525 andalso Luck_val =< 550 ->
				   		10;
					Luck_val > 550 andalso Luck_val =< 575 ->
				   		10;
					Luck_val > 575 andalso Luck_val < 600 ->
				   		20;
					Luck_val >= 600 ->
				   		100;
					true ->
						0
				   end;
			   7 ->
				   if Luck_val >= 0 andalso Luck_val =< 25 ->
						0;
					Luck_val > 25 andalso Luck_val =< 50 ->
						0;
			   		Luck_val > 50 andalso Luck_val =< 75 ->
				   		0;
			   		Luck_val > 75 andalso Luck_val =< 100 ->
				   		0;
			   		Luck_val > 100 andalso Luck_val =< 125 ->
				   		0;
			    	Luck_val > 125 andalso Luck_val =< 150 ->
				   		0;
			    	Luck_val > 150  andalso Luck_val =< 175 ->
				   		0;
					Luck_val > 175  andalso Luck_val =< 200 ->
				   		0;
					Luck_val > 200  andalso Luck_val =< 225 ->
				   		0;
					Luck_val > 225  andalso Luck_val =< 250 ->
				   		0;
					Luck_val > 250  andalso Luck_val =< 275 ->
				   		0;
					Luck_val > 275  andalso Luck_val =< 300 ->
				   		0;
					Luck_val > 300   andalso Luck_val =< 325 ->
				   		0.1;
					Luck_val > 325   andalso Luck_val =< 350 ->
				   		0.3;
					Luck_val > 350   andalso Luck_val =< 375 ->
				   		0.3;
					Luck_val > 375   andalso Luck_val =< 400 ->
				   		0.5;
					Luck_val > 400 andalso Luck_val =< 425 ->
				   		0.5;
					Luck_val > 425 andalso Luck_val =< 450 ->
				   		1;
					Luck_val > 450 andalso Luck_val =< 475 ->
				   		1;
					Luck_val > 475 andalso Luck_val =< 500 ->
				   		5;
					Luck_val > 500 andalso Luck_val =< 525 ->
				   		5;
					Luck_val > 525 andalso Luck_val =< 550 ->
				   		8;
					Luck_val > 550 andalso Luck_val =< 575 ->
				   		8;
					Luck_val > 575 andalso Luck_val =< 600 ->
				   		10;
					Luck_val > 600 andalso Luck_val =< 625 ->
				   		10;
					Luck_val > 625 andalso Luck_val =< 650 ->
				   		13;
					Luck_val > 650 andalso Luck_val =< 675 ->
				   		13;
					Luck_val > 675 andalso Luck_val < 700 ->
				   		16;
					Luck_val >= 700 ->
				   		100;
					true ->
						0
				   end;
			   8 -> 
				   if Luck_val >= 0 andalso Luck_val =< 25 ->
						0;
			   		Luck_val > 25 andalso Luck_val =< 50 ->
				   		0;
			   		Luck_val > 50 andalso Luck_val =< 75 ->
				  		0;
			   		Luck_val > 75 andalso Luck_val =< 100 ->
				   		0;
			   		Luck_val > 100 andalso Luck_val =< 125 ->
				   		0;
			    	Luck_val > 125 andalso Luck_val =< 150 ->
				   		0;
			    	Luck_val > 150  andalso Luck_val =< 175 ->
				   		0;
					Luck_val > 175  andalso Luck_val =< 200 ->
				   		0;
					Luck_val > 200  andalso Luck_val =< 225 ->
				   		0;
					Luck_val > 225  andalso Luck_val =< 250 ->
				   		0;
					Luck_val > 250  andalso Luck_val =< 275 ->
				   		0;
					Luck_val > 275  andalso Luck_val =< 300 ->
				   		0;
					Luck_val > 300   andalso Luck_val =< 325 ->
				   		0;
					Luck_val > 325   andalso Luck_val =< 350 ->
				   		0.1;
					Luck_val > 350   andalso Luck_val =< 375 ->
				   		0.1;
					Luck_val > 375   andalso Luck_val =< 400 ->
				   		0.1;
					Luck_val > 400 andalso Luck_val =< 425 ->
				   		0.5;
					Luck_val > 425 andalso Luck_val =< 450 ->
				   		0.5;
					Luck_val > 450 andalso Luck_val =< 475 ->
				   		1;
					Luck_val > 475 andalso Luck_val =< 500 ->
				   		1;
					Luck_val > 500 andalso Luck_val =< 525 ->
				   		2;
					Luck_val > 525 andalso Luck_val =< 550 ->
				   		2;
					Luck_val > 550 andalso Luck_val =< 575 ->
				   		5;
					Luck_val > 575 andalso Luck_val =< 600 ->
				   		5;
					Luck_val > 600 andalso Luck_val =< 625 ->
				   		8;
					Luck_val > 625 andalso Luck_val =< 650 ->
				   		8;
					Luck_val > 650 andalso Luck_val =< 675 ->
				   		11;
					Luck_val > 675 andalso Luck_val =< 700 ->
				   		11;
					Luck_val > 700 andalso Luck_val =< 725 ->
				   		16;
					Luck_val > 725 andalso Luck_val =< 750 ->
				   		16;
					Luck_val > 750 andalso Luck_val =< 775 ->
				   		20;
					Luck_val > 775 andalso Luck_val < 800 ->
				   		20;
					Luck_val >= 800 ->
				   		100;
					true ->
						0
				   end;
			   9 ->
				   if Luck_val >= 0 andalso Luck_val =< 25 ->
						0;
			   		Luck_val > 25 andalso Luck_val =< 50 ->
				   		0;
			   		Luck_val > 50 andalso Luck_val =< 75 ->
				   		0;
			   		Luck_val > 75 andalso Luck_val =< 100 ->
				   		0;
			   		Luck_val > 100 andalso Luck_val =< 125 ->
				   		0;
			    	Luck_val > 125 andalso Luck_val =< 150 ->
				   		0;
			    	Luck_val > 150  andalso Luck_val =< 175 ->
				   		0;
					Luck_val > 175  andalso Luck_val =< 200 ->
				   		0;
					Luck_val > 200  andalso Luck_val =< 225 ->
				   		0;
					Luck_val > 225  andalso Luck_val =< 250 ->
				   		0;
					Luck_val > 250  andalso Luck_val =< 275 ->
				   		0;
					Luck_val > 275  andalso Luck_val =< 300 ->
				   		0;
					Luck_val > 300   andalso Luck_val =< 325 ->
				   		0;
					Luck_val > 325   andalso Luck_val =< 350 ->
				   		0;
					Luck_val > 350   andalso Luck_val =< 375 ->
				   		0;
					Luck_val > 375   andalso Luck_val =< 400 ->
				   		0;
					Luck_val > 400 andalso Luck_val =< 425 ->
				   		0;
					Luck_val > 425 andalso Luck_val =< 450 ->
				   		0;
					Luck_val > 450 andalso Luck_val =< 475 ->
				   		0;
					Luck_val > 475 andalso Luck_val =< 500 ->
				   		0;
					Luck_val > 500 andalso Luck_val =< 525 ->
				   		0.1;
					Luck_val > 525 andalso Luck_val =< 550 ->
				   		0.1;
					Luck_val > 550 andalso Luck_val =< 575 ->
				   		0.5;
					Luck_val > 575 andalso Luck_val =< 600 ->
				   		1;
					Luck_val > 600 andalso Luck_val =< 625 ->
				  	 	1;
					Luck_val > 625 andalso Luck_val =< 650 ->
				   		1;
					Luck_val > 650 andalso Luck_val =< 675 ->
				   		5;
					Luck_val > 675 andalso Luck_val =< 700 ->
				   		5;
					Luck_val > 700 andalso Luck_val =< 725 ->
				   		9;
					Luck_val > 725 andalso Luck_val =< 750 ->
				   		9;
					Luck_val > 750 andalso Luck_val =< 775 ->
				   		15;
					Luck_val > 775 andalso Luck_val < 800 ->
				   		15;
					Luck_val >= 800 ->
				   		100;
					true ->
						0
				   end;
			   _ ->
				   0
		   end
	end,
	Ratio*100.
			   
%%坐骑进阶的顺序(类型id和名称)	
get_next_step_type_name(Step) ->
	case Step of
		1 ->
			[16001,"霸天虎"];
		2 ->
			[16013,"三尾仙狐"];
		3 ->
			[16016,"黑狮兽"];
		4 ->
			[16017,"双头狼"];
		5 ->
			[16012,"战鼓犀牛"];
		6 ->
			[16014,"仙羚"];			
		7 ->
			[16015,"玄天战象"];
		8 ->
			[16018,"青龙皇"];
		9 ->
			[16020,"万毒巨蝎"];
		10 ->
			[16019,"白玉麒麟"];
		_ ->
			[11111,""]
	end.

%%坐骑进阶的顺序(类型id和名称)	
get_name_by_goodsid(GoodsTypeId) ->
	case GoodsTypeId of 
		16000 -> "霸天虎";
		16001 -> "冰川虎";
		16002 -> "吉祥兔";
		16003 -> "独角兽";
		16004 -> "冰魂";
		16005 -> "炎魄";
		16006 -> "甜甜";
		16007 -> "蜜蜜";
		16008 -> "月兔";
		16012 -> "战鼓犀牛";
		16013 -> "三尾仙狐";
		16014 -> "仙羚";
		16015 -> "玄天战象";
		16016 -> "黑狮兽";
		16017 -> "双头狼";
		16018 -> "青龙皇";
		16019 -> "白玉麒麟";
		16020 -> "万毒巨蝎";
		16009 -> "飞行画卷";
		16010 -> "飞行画卷";
		_ -> "霸天虎"
	end.
	
%%坐骑兽魄驯化所需材料和数量(1-3阶进阶需要飞灵丹，4阶及以上进阶需要飞灵仙丹)
%%进阶所需条件(物品类型,数量,铜币)
get_need_cond_4sp(Step) ->
	[_Goods_id,_Num,_Coin] = 
	case Step of
		1 -> [24820,1,20000];
		2 -> [24820,1,20000];
		3 -> [24820,1,20000];
		4 -> [24821,1,20000];
		5 -> [24821,1,20000];
		6 -> [24821,1,20000];
		7 -> [24821,1,20000];
		8 -> [24821,1,20000];
		9 -> [24821,1,20000];
		_ -> [24821,1,20000]
	end.

%%取坐骑品质
get_random_color(Step) ->
	Platform = config:get_platform_name(), 
	%%台湾平台 
	if Platform == "cmwebgame" ->
		   Random = util:rand(1, 10000),
		   if Step >= 0 andalso Step =< 3 ->
				  if Random >= 0 andalso Random =< 6200 -> 1;
					 Random >= 6201 andalso Random =< 8900 -> 2;
					 Random >= 8901 andalso Random =< 9720 -> 3;
					 Random >= 9721 andalso Random =< 9920 -> 4;
					 Random >= 9921 andalso Random =< 10000 -> 5;
					 true ->
						 1
				  end;
			  Step >= 4 andalso Step =< 10 ->
				  if Random >= 0 andalso Random =< 4650 -> 1;
					 Random >= 4651 andalso Random =< 7350 -> 2;
					 Random >= 7351 andalso Random =< 9150 -> 3;
					 Random >= 9151 andalso Random =< 9850 -> 4;
					 Random >= 9851 andalso Random =< 10000 -> 5;
					 true ->
						 1
				  end;
			  true ->
				  1
		   end;
	   true ->
		   Random = util:rand(1, 10000),
		   if Step >= 0 andalso Step =< 3 ->
				  if Random >= 0 andalso Random =< 6000 -> 1;
					 Random >= 6001 andalso Random =< 9000 -> 2;
					 Random >= 9001 andalso Random =< 9600 -> 3;
					 Random >= 9601 andalso Random =< 9900 -> 4;
					 Random >= 9901 andalso Random =< 10000 -> 5;
					 true ->
						 1
				  end;
			  Step >= 4 andalso Step =< 10 ->
				  if Random >= 0 andalso Random =< 4000 -> 1;
					 Random >= 4001 andalso Random =< 7000 -> 2;
					 Random >= 7001 andalso Random =< 9000 -> 3;
					 Random >= 9001 andalso Random =< 9800 -> 4;
					 Random >= 9801 andalso Random =< 10000 -> 5;
					 true ->
						 1
				  end;
			  true ->
				  1
		   end
	end.
	   
%%取坐骑称号
get_mount_title_4sp(Mount) ->
	Lp = Mount#ets_mount.lp,
	Xp = Mount#ets_mount.xp,
	Tp = Mount#ets_mount.tp,
	Qp = Mount#ets_mount.qp,
	SP4TotalValue = round((Lp+Xp+Tp+Qp)/5),
	BaseValue = round(SP4TotalValue*0.1),
	ReamValue = SP4TotalValue -4*BaseValue,
	[_TotalValue,_Average,MaxVlaue1] = data_mount:get_4sp_val(Mount#ets_mount.step),
	MaxVlaue = round(MaxVlaue1/5),
	if ReamValue > MaxVlaue ->
		    NewValue1  =  util:rand(1,MaxVlaue);
	   true ->
		   NewValue1  =  util:rand(1,ReamValue)
	end,
	if BaseValue+NewValue1 > MaxVlaue ->
		   RandomLp = MaxVlaue;
	   true ->
		   RandomLp = BaseValue+NewValue1
	end,
	
	if ReamValue - RandomLp  > MaxVlaue ->
		    NewValue2  =  util:rand(1,MaxVlaue);
	   true ->
		   NewValue2  =  util:rand(1,ReamValue - RandomLp)
	end,
	if BaseValue+NewValue2 > MaxVlaue ->
		   RandomXp = MaxVlaue;
	   true ->
		   RandomXp = BaseValue+NewValue2
	end,
	
	if ReamValue - RandomLp -  RandomXp > MaxVlaue ->
		    NewValue3  =  util:rand(1,MaxVlaue);
	   true ->
		   NewValue3  =  util:rand(1,ReamValue - RandomLp -  RandomXp)
	end,
	if BaseValue+NewValue3 > MaxVlaue ->
		   RandomTp = MaxVlaue;
	   true ->
		   RandomTp = BaseValue+NewValue3 
	end,
	RandomQp = SP4TotalValue -RandomLp-RandomXp-RandomTp,
	NewList = [RandomLp,RandomXp,RandomTp,RandomQp],
	   
	NewList1 = filter_result(lists:reverse(lists:sort(NewList)),MaxVlaue,[],0),
	NewSpValue1 = lists:nth(1, NewList1),
	NewSpValue2 = lists:nth(2, NewList1),
	NewSpValue3 = lists:nth(3, NewList1),
	NewSpValue4 = lists:nth(4, NewList1),
	if NewSpValue3 == NewSpValue4 ->
		   NewList2 = [{NewSpValue1+11,1}, {NewSpValue2,2}, {NewSpValue3,3}, {NewSpValue4-11,4}];
	   true ->
		   NewList2 = [{NewSpValue1,1}, {NewSpValue2,2}, {NewSpValue3,3}, {NewSpValue4,4}]
	end,
	TotalOrder = util:rand(1,6),
	ResultList2 = lists:sort(fun({Value3, _Order3},{Value4, _Order4}) -> Value3 =< Value4  end, NewList2),
	{MinValue,_MinOrder} = lists:nth(1, ResultList2),
	{MinValue2,_MinOrder2} = lists:nth(2, ResultList2),
	{MinValue3,_MinOrder3} = lists:nth(3, ResultList2),
	{MinValue4,_MinOrder4} = lists:nth(4, ResultList2),
	[NewLp,NewXp,NewTp,NewQp] = 
	if TotalOrder == 1 ->
		   [MinValue,MinValue2,MinValue3,MinValue4];
	   TotalOrder == 2 ->
		   [MinValue2,MinValue,MinValue4,MinValue3];
	   TotalOrder == 3 ->
		   [MinValue3,MinValue4,MinValue,MinValue2];
	   TotalOrder == 4 ->
		   [MinValue4,MinValue,MinValue3,MinValue2];
	   TotalOrder == 5 ->
		   [MinValue,MinValue3,MinValue4,MinValue2];
	   TotalOrder == 6 ->
		   [MinValue,MinValue4,MinValue3,MinValue2];
	   true ->
		  [MinValue2,MinValue,MinValue4,MinValue3]
	end,
	[NewLp*5,NewXp*5,NewTp*5,NewQp*5].

filter_result([],_MaxVlaue,NewSp4List,_Diff) ->
	NewSp4List;
filter_result([H|T],MaxVlaue,NewSp4List,Diff) ->
	if H+Diff =< MaxVlaue ->
		    filter_result(T,MaxVlaue,[H+Diff | NewSp4List],0);   
	   true ->
		   DiffValue = H-MaxVlaue,
		   filter_result(T,MaxVlaue,[MaxVlaue|NewSp4List],Diff+DiffValue)
	end.
	


%%猎魂按钮对应的消费礼券数
get_need_cond_cash_btn(Order) ->
	_Cash = 
	case Order of
		1 -> 4;
		2 -> 5;
		3 -> 10;
		4 -> 20;
		5 -> 30;
		_ -> 30
	end.

%%激活下一按钮(BtnOrder为当前按钮顺序号1-5 ,返回0表示失败，1表示成功)
get_next_btn_ratio(BtnOrder) ->
	Random = util:rand(1, 100),
	case BtnOrder of
		1 ->
			if Random >= 0 andalso Random =< 50 ->
				   1;
			   true ->
				   0
			end;
		2 ->
			if Random >= 0 andalso Random =< 40 ->
				   1;
			   true ->
				   0
			end;
		3 ->
			if Random >= 0 andalso Random =< 20 ->
				   1;
			   true ->
				   0
			end;
		4 ->
			if Random >= 0 andalso Random =< 30 ->
				   1;
			   true ->
				   0
			end;
		5 ->
			if Random >= 0 andalso Random =< 50 ->
				   1;
			   true ->
				   0
			end;
		_ ->
			0
	end.


%%随机出现技能 (根据按钮位置 1雍和,2乘黄,3睚眦,4穷奇,5饕餮)
%%ActiveType(0为礼券激活，1为元宝激活)
get_random_color_btn(BtnOrder,ActiveType) ->
	Random = util:rand(1, 100),
	SkillList = 
	case BtnOrder of
		1 ->
			if Random >= 0 andalso Random =< 60 ->
				   [6001,6002,6003,6004];
			   Random >= 61 andalso Random =< 100 ->
				   [1001,1002,1003,1004,1005,1006,1007,1008,1009,1010,1011,1012];
			   true ->
				   [6001,6002,6003,6004]
			end;
		2 ->
			if Random >= 0 andalso Random =< 40 ->
				   [6001,6002,6003,6004];
			    Random >= 41 andalso Random =< 80 ->
				   [1001,1002,1003,1004,1005,1006,1007,1008,1009,1010,1011,1012];
			   Random >= 81 andalso Random =< 100 ->
				   [2001,2002,2003,2004,2005,2006,2007,2008,2009,2010,2011,2012,2013];
			   true ->
				   [6001,6002,6003,6004]
			end;
		3 ->
			if Random >= 0 andalso Random =< 30 ->
				   [6001,6002,6003,6004];
			    Random >= 31 andalso Random =< 70 ->
				   [1001,1002,1003,1004,1005,1006,1007,1008,1009,1010,1011,1012];
			   Random >= 71 andalso Random =< 100 ->
				   [2001,2002,2003,2004,2005,2006,2007,2008,2009,2010,2011,2012,2013];
			   true ->
				   [6001,6002,6003,6004]
			end;
		4 ->
			if ActiveType == 0 ->%%礼券
				   if Random >= 0 andalso Random =< 40 ->
						  [1001,1002,1003,1004,1005,1006,1007,1008,1009,1010,1011,1012];
					  Random >= 41 andalso Random =< 80 ->
						  [2001,2002,2003,2004,2005,2006,2007,2008,2009,2010,2011,2012,2013];
					  Random >= 81 andalso Random =< 100 ->
						  [3001,3002,3003,3004,3005,3006,3007,3008,3009,3010,3011,3012,3013];
					  true ->
						  [1001,1002,1003,1004,1005,1006,1007,1008,1009,1010,1011,1012]
				   end;
			   true -> %%元宝
				    if Random >= 0 andalso Random =< 25 ->
						  [3001,3002,3003,3004,3005,3006,3007,3008,3009,3010,3011,3012,3013];
					   Random >= 26 andalso Random =< 30 ->
						  [4001,4002,4003,4004,4005,4006,4007,4008,4009,4010,4011,4012,4013];
					   Random >= 31 andalso Random =< 100 ->
						  [7001];
					  true ->
						  [7001]
				   end
			end;
		5 ->
			if ActiveType == 0 ->%%礼券
				   if Random >= 0 andalso Random =< 20 ->
						  [1001,1002,1003,1004,1005,1006,1007,1008,1009,1010,1011,1012];
					  Random >= 21 andalso Random =< 65 ->
						  [2001,2002,2003,2004,2005,2006,2007,2008,2009,2010,2011,2012,2013];
					  Random >= 66 andalso Random =< 95 ->
						  [3001,3002,3003,3004,3005,3006,3007,3008,3009,3010,3011,3012,3013];
					  Random >= 96 andalso Random =< 100 ->
						  [4001,4002,4003,4004,4005,4006,4007,4008,4009,4010,4011,4012,4013];
					  true ->
						  [1001,1002,1003,1004,1005,1006,1007,1008,1009,1010,1011,1012]
				   end;
			   true -> %%元宝
				   if Random >= 0 andalso Random =< 43 ->
						  [3001,3002,3003,3004,3005,3006,3007,3008,3009,3010,3011,3012,3013];
					  Random >= 44 andalso Random =< 48 ->
						  [4001,4002,4003,4004,4005,4006,4007,4008,4009,4010,4011,4012,4013];
					  Random >= 49 andalso Random =< 50 ->
						  [5001];
					  Random >= 51 andalso Random =< 100 ->
						  [7001];
					  true ->
						  [3001,3002,3003,3004,3005,3006,3007,3008,3009,3010,3011,3012,3013]
				   end 
			end;
		_ -> 
			[6001,6002,6003,6004]
	end,
	[SkillId] = util:get_random_list(SkillList,1),
	SkillId.

	   
%%气血1,法力2,攻击3,防御4,命中5,闪避6,暴击7,风抗8,火抗9,水抗10,雷抗11,土抗12,全抗13,无用精魂14,经验精魂15
%%返回技能类型(例如攻击,气血),颜色灰0,绿1,蓝2,金3,紫4,红5
get_skill_type_color(SkillId) ->
	if 
	   SkillId == 1001 -> [1,1];
	   SkillId == 1002 -> [2,1];
	   SkillId == 1003 -> [4,1];
	   SkillId == 1004 -> [5,1];
	   SkillId == 1005 -> [6,1];
	   SkillId == 1006 -> [7,1];
	   SkillId == 1007 -> [8,1];
	   SkillId == 1008 -> [9,1];
	   SkillId == 1009 -> [10,1];
	   SkillId == 1010 -> [11,1];
	   SkillId == 1011 -> [12,1];
	   SkillId == 1012 -> [13,1];
	   
	   SkillId == 2001 -> [3,1];
	   SkillId == 2002 -> [1,2];
	   SkillId == 2003 -> [2,2];
	   SkillId == 2004 -> [4,2];
	   SkillId == 2005 -> [5,2];
	   SkillId == 2006 -> [6,2];
	   SkillId == 2007 -> [7,2];
	   SkillId == 2008 -> [8,2];
	   SkillId == 2009 -> [9,2];
	   SkillId == 2010 -> [10,2];
	   SkillId == 2011 -> [11,2];
	   SkillId == 2012 -> [12,2];	   
	   SkillId == 2013 -> [13,2];
	   
	   SkillId == 3001 -> [3,2];
	   SkillId == 3002 -> [1,3];
	   SkillId == 3003 -> [2,3];
	   SkillId == 3004 -> [4,3];
	   SkillId == 3005 -> [5,3];
	   SkillId == 3006 -> [6,3];
	   SkillId == 3007 -> [7,3];
	   SkillId == 3008 -> [8,3];
	   SkillId == 3009 -> [9,3];
	   SkillId == 3010 -> [10,3];
	   SkillId == 3011 -> [11,3];
	   SkillId == 3012 -> [12,3];
	   SkillId == 3013 -> [13,3];
	   
	   SkillId == 4001 -> [3,3];
	   SkillId == 4002 -> [1,4];
	   SkillId == 4003 -> [2,4];
	   SkillId == 4004 -> [4,4];
	   SkillId == 4005 -> [5,4];
	   SkillId == 4006 -> [6,4];
	   SkillId == 4007 -> [7,4];
	   SkillId == 4008 -> [8,4];
	   SkillId == 4009 -> [9,4];
	   SkillId == 4010 -> [10,4];
	   SkillId == 4011 -> [11,4];
	   SkillId == 4012 -> [12,4];
	   SkillId == 4013 -> [13,4];
	   
	   SkillId == 5001 -> [3,4];
	   
	   SkillId == 6001 -> [14,0];
	   SkillId == 6002 -> [14,0];
	   SkillId == 6003 -> [14,0];
	   SkillId == 6004 -> [14,0];
	   
	   SkillId == 7001 -> [15,5];
	   true -> [14,0]
	end.
		   
%%气血1,法力2,攻击3,防御4,命中5,闪避6,暴击7,风抗8,火抗9,水抗10,雷抗11,土抗12,全抗13,无用精魂14,经验精魂15
get_skill_name(SkillId) ->
	if 
	   SkillId == 1001 -> "不屈";
	   SkillId == 1002 -> "煌光";
	   SkillId == 1003 -> "鹿筋";
	   SkillId == 1004 -> "心眼";
	   SkillId == 1005 -> "敏锐";
	   SkillId == 1006 -> "蓄力";
	   SkillId == 1007 -> "风妖";
	   SkillId == 1008 -> "火妖";
	   SkillId == 1009 -> "水妖";
	   SkillId == 1010 -> "雷妖";
	   SkillId == 1011 -> "土妖";
	   SkillId == 1012 -> "昊天灵守";
	   
	   SkillId == 2001 -> "猛攻";
	   SkillId == 2002 -> "铁血";
	   SkillId == 2003 -> "旭日";
	   SkillId == 2004 -> "虎骨";
	   SkillId == 2005 -> "先机";
	   SkillId == 2006 -> "迷踪";
	   SkillId == 2007 -> "会心";
	   SkillId == 2008 -> "风魔";
	   SkillId == 2009 -> "火魔";
	   SkillId == 2010 -> "水魔";
	   SkillId == 2011 -> "雷魔";
	   SkillId == 2012 -> "土魔";	   
	   SkillId == 2013 -> "东皇仙气";
	   
	   SkillId == 3001 -> "虎狼";
	   SkillId == 3002 -> "不死身";
	   SkillId == 3003 -> "炼狱火";
	   SkillId == 3004 -> "麒麟角";
	   SkillId == 3005 -> "聚神气";
	   SkillId == 3006 -> "影分身";
	   SkillId == 3007 -> "背水击";
	   SkillId == 3008 -> "风灵神";
	   SkillId == 3009 -> "火灵神";
	   SkillId == 3010 -> "水灵神";
	   SkillId == 3011 -> "雷灵神";
	   SkillId == 3012 -> "土灵神";
	   SkillId == 3013 -> "盘古神舍";
	   
	   SkillId == 4001 -> "恶鬼神";
	   SkillId == 4002 -> "永生之躯";
	   SkillId == 4003 -> "浮罗万解";
	   SkillId == 4004 -> "龙鳞凤羽";
	   SkillId == 4005 -> "通天下地";
	   SkillId == 4006 -> "魔影潜行";
	   SkillId == 4007 -> "反骨逆鳞";
	   SkillId == 4008 -> "风仙下凡";
	   SkillId == 4009 -> "火仙下凡";
	   SkillId == 4010 -> "水仙下凡";
	   SkillId == 4011 -> "雷仙下凡";
	   SkillId == 4012 -> "土仙下凡";
	   SkillId == 4013 -> "轩辕护体";
	   
	   SkillId == 5001 -> "混世魔王";
	   
	   SkillId == 6001 -> "恶病缠身";
	   SkillId == 6002 -> "魂躯互噬";
	   SkillId == 6003 -> "狂乱逆天";
	   SkillId == 6004 -> "犯忠弑主";
	   
	   SkillId == 7001 -> "天地精气";
	   true -> ""
	end.

get_skill_id_name(Name) ->
	if 
	   Name == "不屈" -> SkillId = 1001;
	   Name == "煌光" -> SkillId = 1002;
	   Name == "鹿筋" -> SkillId = 1003;
	   Name == "心眼" -> SkillId = 1004;
	   Name == "敏锐" -> SkillId = 1005;
	   Name == "蓄力" -> SkillId = 1006;
	   Name == "风妖" -> SkillId = 1007;
	   Name == "火妖" -> SkillId = 1008;
	   Name == "水妖" -> SkillId = 1009;
	   Name == "雷妖" -> SkillId = 1010;
	   Name == "土妖" -> SkillId = 1011;
	   Name == "昊天灵守" -> SkillId = 1012;
	   
	   Name == "猛攻" -> SkillId = 2001;
	   Name == "铁血" -> SkillId = 2002;
	   Name == "旭日" -> SkillId = 2003;
	   Name == "虎骨" -> SkillId = 2004;
	   Name == "先机" -> SkillId = 2005;
	   Name == "迷踪" -> SkillId = 2006;
	   Name == "会心" -> SkillId = 2007;
	   Name == "风魔" -> SkillId = 2008;
	   Name == "火魔" -> SkillId = 2009;
	   Name == "水魔" -> SkillId = 2010;
	   Name == "雷魔" -> SkillId = 2011;
	   Name == "土魔" -> SkillId = 2012;	   
	   Name == "东皇仙气" -> SkillId = 2013;
	   
	   Name == "虎狼" -> SkillId = 3001;
	   Name == "不死身" -> SkillId = 3002;
	   Name == "炼狱火" -> SkillId = 3003;
	   Name == "麒麟角" -> SkillId = 3004;
	   Name == "聚神气" -> SkillId = 3005;
	   Name == "影分身" -> SkillId = 3006;
	   Name == "背水击" -> SkillId = 3007;
	   Name == "风灵神" -> SkillId = 3008;
	   Name == "火灵神" -> SkillId = 3009;
	   Name == "水灵神" -> SkillId = 3010;
	   Name == "雷灵神" -> SkillId = 3011;
	   Name == "土灵神" -> SkillId = 3012;
	   Name == "盘古神舍" -> SkillId = 3013;
	   
	   Name == "恶鬼神" -> SkillId = 4001;
	   Name == "永生之躯" -> SkillId = 4002;
	   Name == "浮罗万解" -> SkillId = 4003;
	   Name == "龙鳞凤羽" -> SkillId = 4004;
	   Name == "通天下地" -> SkillId = 4005;
	   Name == "魔影潜行" -> SkillId = 4006;
	   Name == "反骨逆鳞" -> SkillId = 4007;
	   Name == "风仙下凡" -> SkillId = 4008;
	   Name == "火仙下凡" -> SkillId = 4009;
	   Name == "水仙下凡" -> SkillId = 4010;
	   Name == "雷仙下凡" -> SkillId = 4011;
	   Name == "土仙下凡" -> SkillId = 4012;
	   Name == "轩辕护体" -> SkillId = 4013;
	   
	   Name == "混世魔王" -> SkillId = 5001;
	   
	   Name == "恶病缠身" -> SkillId = 6001;
	   Name == "魂躯互噬" -> SkillId = 6002;
	   Name == "狂乱逆天" -> SkillId = 6003;
	   Name == "犯忠弑主" -> SkillId = 6004;
	   
	   Name == "天地精气" -> SkillId = 7001;
	   true -> SkillId = 0
	end,
	SkillId.


%%技能的属性加成
get_skill_prop(SkillId,Level) ->
	PropValueList = 
	if 
	   SkillId == 1001 -> [110,140,170,200,230,270,300,330,360,390];
	   SkillId == 1002 -> [15,23,31,39,47,55,63,71,79,88];
	   SkillId == 1003 -> [50,67,84,101,118,135,152,169,186,200];
	   SkillId == 1004 -> [7,9,11,13,15,17,19,21,23,25];
	   SkillId == 1005 -> [7,9,11,13,15,17,19,21,23,25];
	   SkillId == 1006 -> [7,9,11,13,15,17,19,21,23,25];
	   SkillId == 1007 -> [14,18,22,26,30,34,38,42,46,50];
	   SkillId == 1008 -> [14,18,22,26,30,34,38,42,46,50];
	   SkillId == 1009 -> [14,18,22,26,30,34,38,42,46,50];
	   SkillId == 1010 -> [14,18,22,26,30,34,38,42,46,50];
	   SkillId == 1011 -> [14,18,22,26,30,34,38,42,46,50];
	   SkillId == 1012 -> [11,15,19,23,27,31,35,39,44,50];
	   
	   SkillId == 2001 -> [25,33,41,49,57,65,73,81,89,100];
	   SkillId == 2002 -> [210,270,330,390,450,510,570,630,690,750];
	   SkillId == 2003 -> [30,46,62,78,94,110,126,142,158,175];
	   SkillId == 2004 -> [100,131,162,193,224,255,286,317,348,375];
	   SkillId == 2005 -> [14,18,22,26,30,34,38,42,46,50];
	   SkillId == 2006 -> [14,18,22,26,30,34,38,42,46,50];
	   SkillId == 2007 -> [14,18,22,26,30,34,38,42,46,50];
	   SkillId == 2008 -> [28,36,44,52,60,68,76,84,92,100];
	   SkillId == 2009 -> [28,36,44,52,60,68,76,84,92,100];
	   SkillId == 2010 -> [28,36,44,52,60,68,76,84,92,100];
	   SkillId == 2011 -> [28,36,44,52,60,68,76,84,92,100];
	   SkillId == 2012 -> [28,36,44,52,60,68,76,84,92,100];
	   SkillId == 2013 -> [25,33,41,49,57,65,73,81,89,100];
	   
	   SkillId == 3001 -> [50,67,84,101,118,135,152,169,186,200];
	   SkillId == 3002 -> [420,540,660,780,900,1020,1140,1260,1380,1500];
	   SkillId == 3003 -> [60,92,124,156,188,220,252,284,316,350];
	   SkillId == 3004 -> [200,261,322,383,444,505,566,627,688,750];
	   SkillId == 3005 -> [28,36,44,52,60,68,76,84,92,100];
	   SkillId == 3006 -> [28,36,44,52,60,68,76,84,92,100];
	   SkillId == 3007 -> [28,36,44,52,60,68,76,84,92,100];
	   SkillId == 3008 -> [65,80,95,110,125,140,155,170,185,200];
	   SkillId == 3009 -> [65,80,95,110,125,140,155,170,185,200];
	   SkillId == 3010 -> [65,80,95,110,125,140,155,170,185,200];
	   SkillId == 3011 -> [65,80,95,110,125,140,155,170,185,200];
	   SkillId == 3012 -> [65,80,95,110,125,140,155,170,185,200];
	   SkillId == 3013 -> [50,67,84,101,118,135,152,169,186,200];
	   
	   SkillId == 4001 -> [100,133,166,199,232,265,298,331,364,400];
	   SkillId == 4002 -> [840,1080,1320,1560,1800,2040,2280,2520,2760,3000];
	   SkillId == 4003 -> [120,184,248,312,376,440,504,568,632,700];
	   SkillId == 4004 -> [400,522,644,766,888,1010,1132,1254,1376,1500];
	   SkillId == 4005 -> [65,80,95,110,125,140,155,170,185,200];
	   SkillId == 4006 -> [65,80,95,110,125,140,155,170,185,200];
	   SkillId == 4007 -> [65,80,95,110,125,140,155,170,185,200];
	   SkillId == 4008 -> [130,160,190,220,250,280,310,340,370,400];
	   SkillId == 4009 -> [130,160,190,220,250,280,310,340,370,400];
	   SkillId == 4010 -> [130,160,190,220,250,280,310,340,370,400];
	   SkillId == 4011 -> [130,160,190,220,250,280,310,340,370,400];
	   SkillId == 4012 -> [130,160,190,220,250,280,310,340,370,400];
	   SkillId == 4013 -> [120,184,248,312,376,440,504,568,632,700];
	   
	   SkillId == 5001 -> [200,267,334,401,468,535,602,669,736,800];
	   
	   SkillId == 6001 -> [0,0,0,0,0,0,0,0,0,0];
	   SkillId == 6002 -> [0,0,0,0,0,0,0,0,0,0];
	   SkillId == 6003 -> [0,0,0,0,0,0,0,0,0,0];
	   SkillId == 6004 -> [0,0,0,0,0,0,0,0,0,0];
	   
	   SkillId == 7001 -> [0,0,0,0,0,0,0,0,0,0];
	   true -> [0,0,0,0,0,0,0,0,0,0]
	end,
	if Level >= 1 andalso Level =< 10 ->
		   lists:nth(Level,PropValueList);
	   true ->
		   0
	end.

%%技能本身对应的经验值(灰0,绿1,蓝2,金3,紫4,红5)
get_self_skill_exp(Color) ->
	case Color of
		1 -> 30;
		2 -> 60;
		3 -> 120;
		4 -> 240;
		5 -> 1200;
		_ -> 0
	end.

%%技能升级对应经验(绿1,	蓝2,金3,紫4,红5)
get_skill_upgrade_exp(Level,Color) ->
	ExpList = 
	case Level of
		1 -> [120,240,480,960];
		2 -> [240,480,960,1920];
		3 -> [480,960,1920,3840];
		4 -> [960,1920,3840,7680];
		5 -> [1920,3840,7680,15360];
		6 -> [3840	,7680,15360,30720];
		7 -> [7680,15360,30720,61440];
		8 -> [15360,30720,61440,122880];
		9 -> [30720,61440,122880,245760];
		_ -> [30720,61440,122880,245760]
	end,
	case Color of
		1 -> lists:nth(1, ExpList);
		2 -> lists:nth(2, ExpList);
		3 -> lists:nth(3, ExpList);
		4 -> lists:nth(4, ExpList);
		_ -> lists:nth(4, ExpList)
	end.

%%坐骑属性计算 力魄：(攻击&命中)    心魄：(暴击&闪避) 体魄：(气血&法力) 气魄：(防御&全抗）							
%气血1,法力2,攻击3,防御4,命中5,闪避6,暴击7,风抗8,火抗9,水抗10,雷抗11,土抗12,全抗13
%%根据兽魄决定加成属性类型 比率
get_sp4_type_per(Mount) ->
	Lp = Mount#ets_mount.lp,                                 
    Xp = Mount#ets_mount.xp,                                  
    Tp = Mount#ets_mount.tp,                              
    Qp = Mount#ets_mount.qp,           
	[Xp /250 +1,Xp /250 +1,Lp /250 +1,Tp /250 +1,Lp /250 +1,Qp /250 +1, Qp /250 +1,Tp /250 +1,Tp /250 +1,Tp /250 +1,Tp /250 +1,Tp /250 +1,0].


%气血1,法力2,攻击3,防御4,命中5,闪避6,暴击7,风抗8,火抗9,水抗10,雷抗11,土抗12,全抗13
%%根据精魂技能决定加成属性类型 值
get_prop_mount(MountInfo) ->
	if MountInfo == [] ->
		   [0,0,0,0,0,0,0,0,0,0,0,0];
	   true ->
		   SkillList = [MountInfo#ets_mount.skill_1,MountInfo#ets_mount.skill_2,MountInfo#ets_mount.skill_3,MountInfo#ets_mount.skill_4,
										MountInfo#ets_mount.skill_5,MountInfo#ets_mount.skill_6,MountInfo#ets_mount.skill_7,MountInfo#ets_mount.skill_8],
		   F = fun(MountSkill) ->
					   [_Pos, SkillId, SkillType, SkillLevel, _SkillStep, _SkillExp]  = util:string_to_term(tool:to_list(MountSkill)),
					   SkillEffect = data_mount:get_skill_prop(SkillId,SkillLevel),
					   if SkillType >= 1 andalso SkillType < 14 ->
							  {SkillType,SkillEffect};
						  true ->
							  {14,0}
					   end
			   end,
		   ResultList = [F(MountSkill) ||  MountSkill <- SkillList],
		   %%技能效果值
		   F1 = fun(Num1) ->
						case lists:keyfind(Num1, 1, ResultList) of
							false ->
								0;
							{_,Value1} ->
								Value1
						end
				end,		
		   ResultList1 = [F1(Num1)||Num1 <- lists:seq(1, 13)],
		   %%等级加成效果值[Hp,Mp,Att,Def,Hit,Dodge,Crit,Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil,Anti_all]
		   LevelEffectList = get_prop_level_add(MountInfo#ets_mount.level),
		   %%兽魄效果加成系数[Hp_Sp,Mp_Sp,Att_Sp,Def_Sp,Hit_Sp,Dodge_Sp,Crit_Sp,Anti_wind_Sp,Anti_fire_Sp,Anti_water_Sp,Anti_thunder_Sp,Anti_soil_Sp,Anti_all_Sp]
		   Sp4EffectList = get_sp4_type_per(MountInfo),
		   %%品质效果加成系数
		   Color_ratio = get_prop_colr_per(MountInfo#ets_mount.color),
		   %%亲密度加成系数
		   Close_ratio = get_prop_closr_per(MountInfo#ets_mount.close),
		   F2 = fun(Num2) ->
						PropValue = lists:nth(Num2, LevelEffectList),
						Sp4Ratio = lists:nth(Num2, Sp4EffectList),
						PropValue*Sp4Ratio*Color_ratio
				end,
		   ResultList2 = [F2(Num2)||Num2 <- lists:seq(1, 13)],
		   F3 = fun(Num3) ->
						
						%%技能加成值
						PropValue1 = lists:nth(Num3, ResultList1),
						%%等级，兽魄，品质加成
						PropValue2 = lists:nth(Num3, ResultList2),
						round((PropValue1+PropValue2)*Close_ratio)
				end,
		   ResultList3 = [F3(Num3)||Num3 <- lists:seq(1, 13)],
		   %%将全抗转换到单抗
		   [Hp,Mp,Att,Def,Hit,Dodge,Crit,Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil,Anti_all] = ResultList3,
		   [Hp,Mp,Att,Def,Hit,Dodge,Crit,(Anti_wind+Anti_all),(Anti_fire+Anti_all),(Anti_water+Anti_all),(Anti_thunder+Anti_all),(Anti_soil+Anti_all)]
	end.

%%直接从数据库中查询坐骑的属性
get_prop_mount_db(PlayerId) ->
	Mount = db_agent:select_out_mount_db(PlayerId),
	MountInfo = list_to_tuple([ets_mount]++Mount),
	if is_record(MountInfo,ets_mount) == true ->
		   get_prop_mount(MountInfo);
	   true ->
		   []
	end.

%%战斗力根据key的对应比率求值
count_mount_batt(ResultList) ->
	if ResultList == [] -> 0;
	   length(ResultList) =/= 12 -> 0;
	   true ->
		   [Hp,Mp,Att,Def,Hit,Dodge,Crit,Anti_wind,Anti_fire,Anti_water,Anti_thunder,Anti_soil] = ResultList,
		   ResultList1 = [Hp*0.06+Mp*0.1+Att*0.4+Def*0.4+Hit*0.4+Dodge*0.6+Crit*0.7+Anti_wind*0.12+Anti_fire*0.12+Anti_water*0.12+Anti_thunder*0.12+Anti_soil*0.12],
		   round(lists:sum(ResultList1))
	end.

loop_count([],Result1) ->
	Result1;
loop_count([H | Rest],Result1) ->
	{Key,Value} = H,
	case lists:keyfind(Key, 1, Result1) of
		false ->
			loop_count(Rest,[{Key,Value} | Result1]);
		{Key,OldValue} ->
			loop_count(Rest, lists:keyreplace(Key, 1, Result1, {Key,OldValue+Value}))
	end.

%气血1,法力2,攻击3,防御4,命中5,闪避6,暴击7,风抗8,火抗9,水抗10,雷抗11,土抗12,全抗13
%%根据品质决定加成属性类型比率
get_prop_colr_per(Color) ->
	case Color of
		2 -> 1.10;
		3 -> 1.25;
		4 -> 1.4;
		5 -> 1.6;
		_ -> 1
	end.

%气血1,法力2,攻击3,防御4,命中5,闪避6,暴击7,风抗8,火抗9,水抗10,雷抗11,土抗12,全抗13
%%根据品质决定加成属性类型比率
get_prop_closr_per(_Close) ->
	1.
%% 	if Close > 0 andalso Close =< 500 -> 1.01;
%% 	   Close > 500 andalso Close =< 1500 -> 1.02;
%% 	   Close > 1500 andalso Close =< 3000 -> 1.03;
%% 	   Close > 3000 andalso Close =< 6000 -> 1.04;
%% 	   Close > 6000 andalso Close =< 10000 -> 1.05;
%% 	   true -> 1
%% 	end.
		

%%坐骑属性计算
%气血1,法力2,攻击3,防御4,命中5,闪避6,暴击7,风抗8,火抗9,水抗10,雷抗11,土抗12,全抗13
%%返回各属性的初始值 和每级的加成数据
get_prop_Level_value(Level,Type) ->
	case Type of
		1 -> round(100+6*(Level-1));
		2 -> round(20+0.6*(Level-1));
		3 -> round(10+2*(Level-1));
		4 -> round(20+1*(Level-1));
		5 -> round(3+0.2*(Level-1));
		6 -> round(3+0.15*(Level-1));
		7 -> round(3+0.15*(Level-1));
		8 -> round(10+0.2*(Level-1));
		9 -> round(10+0.2*(Level-1));
		10 -> round(10+0.2*(Level-1));
		11 -> round(10+0.2*(Level-1));
		12 -> round(10+0.2*(Level-1));
		13 -> round(10+0.2*(Level-1));
		_ -> 0
	end.
		
%%等级属性加成
get_prop_level_add(Level) ->
	if Level >= 100 ->
		   Level1 = 100;
	   true ->
		   Level1 =Level
	end,
	F = fun(Type) ->
			  get_prop_Level_value(Level1,Type)
	  end,
	[F(Type) ||Type <- lists:seq(1, 13)].

	
%%坐骑参装备的技能格子数
get_skill_num(Step) ->
	NewCell = 
	if Step >= 1 andalso Step =< 10 ->
		   Step -1;
	   true ->
		   0
	end,
	if NewCell >= 8 ->
		   NewCell1 = 8;
	   true ->
		 NewCell1 = NewCell
	end,
	NewCell1.
	   
%%坐骑变身卡对应相应的坐骑
get_mount_type_id(GoodsTypeId) ->
	case GoodsTypeId of
		24850 -> 16008;%%月兔变身卡
		24851 -> 16020;%%万毒巨蝎变身卡
		24852 -> 16018;%%青龙皇变身卡
		24853 -> 16015;%%玄天战象变身卡	
		24854 -> 16006;%%甜甜变身卡
		24855 -> 16007;%%蜜蜜变身卡
		24856 -> 16005;%%炎魄变身卡
		24857 -> 16001;%%冰川虎变身卡
		24858 -> 16002;%%吉祥兔变身卡
		24859 -> 16014;%%仙羚变身卡
		24860 -> 16012;%%战鼓犀牛变身卡
		24861 -> 16017;%%双头狼变身卡
		24862 -> 16004;%%冰魂变身卡
		24863 -> 16003;%%独角兽变身卡
		24864 -> 16010;%%飞行卷轴变身卡	
		24865 -> 16016;%%黑狮兽变身卡
		_ -> 0
	end.
		
		
	
			
	
	
	