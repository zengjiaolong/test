%% Author: xianrongMai
%% Created: 2011-6-30
%% Description: 专门提供lib_achieve模块调用的方法，其他模块请慎用
-module(lib_achieve_inline).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("achieve.hrl").
%%
%% Exported Functions
%%
-export([check_achieve_init/1,	%%检测是否已经加载过 成就系统的数据
%% 		 put_achtitles_dic/1,
		 init_achieve_log/1,
		 check_achieve_treasure/4,
		 get_achieve_ets/1,
		 update_achieve_ets/1,
		 meri_to_list/1,
		 lists_check_meri/1,
		 fail_noup_to_list/1,
		 box_achieve_check/2,
		 add_achieve_ach/2,
		 check_final_ok/3,
		 put_achieve_update/1,
		 get_achieve_update/1,
		 update_achieve_info_finish/4,
		 update_player_titles/8,
		 check_and_update/4,
%% 		 get_player_titles/1,
		 put_ach_log_num/1,
		 get_ach_log_num/0,
		 insert_achieve_log/3,
		 check_equip_ach/3,
		 get_player_bscb/1,			%%获取玩家的被鄙视和崇拜数据
		 get_player_bscb_dict/1,	%%获取玩家的被鄙视和崇拜数据(进程字典)
		 %%38000
		 get_achieve_task/3,
		 get_achieve_epic/3,
		 get_achieve_trials/3,
		 get_achieve_yg/3,
		 get_achieve_fs/3,
		 get_achieve_interact/3,
		 %% 38006
		 load_unload_pearl/4,
		 check_pearl/4, 
		 get_achieve_log/1, %%38001
		 ach_give_goods/4,%%领取成就奖励物品
		 give_goods/3, %%领取八神珠
		 make_ach_treausre_list/4 %% 38002
		]).

%%
%% API Functions
%%
%%************		奇珍异宝		************
%%	名称				需求成就																物品*1	
%% 1	初级成就礼盒		成就点达到100													初级成就礼盒	
%% 2	中级成绩礼盒		成就点达到500													中级成就礼盒	
%% 3	高级成就礼盒		成就点达到1000													高级成就礼盒	
%% 4	经脉成长符		完成苦心修炼成就													经脉成长符	
%% 5	经脉保护符		完成百里挑一成就													经脉保护符	
%% 6	灵兽资质符		完成平庸灵兽成就													灵兽资质符	
%% 7	灵兽保护符		完成极品灵兽成就													资质保护符	
%% 8	灵兽成长丹		完成成长40成就													灵兽成长丹	
%% 9	成长保护丹		完成成长50成就													成长保护丹	
%% 10	五阶紫水晶		完成封神之峰成就													五阶紫水晶	
%% 11	一级宝石袋		完成“百年诛邪”成就												一级宝石袋	
%% 12	二级宝石袋		完成“千年诛邪”成就												二级宝石袋	
%% 13	六合神珠			完成百炼成钢、栋梁之材、通达副本成就								六合神珠	法力
%% 14	六合神珠·真		完成高深修行、新手镖师、跑商有道成就								六合神珠·真	
%% 15	九地神珠			完成小有成就、资质优秀成就										九地神珠	气血
%% 16	九地神珠·真		完成终得大道、三界奇才成就										九地神珠·真	
%% 17	腾蛇神珠			完成中级灵兽、平庸灵兽、成长40成就								腾蛇神珠	防御
%% 18	腾蛇神珠·真		完成高级灵兽、极品灵兽、成长50成就								腾蛇神珠·真	
%% 19	太阴神珠			完成跑商高手、强盗、潜心修炼成就									太阴神珠	闪躲
%% 20	太阴神珠·真		完成击杀火凤、击杀千年老龟、击杀烈焰麒麟兽成就						太阴神珠·真	
%% 21	朱雀神珠			完成封神之巅、氏族称霸、单人镇妖守将、多人镇妖守将成就				朱雀神珠	命中
%% 22	朱雀神珠·真		完成封神巅峰、独孤求败、氏族称王、单人镇妖首领、多人镇妖首领成就	朱雀神珠·真	
%% 23	九天神珠			完成铸造大师、铸甲大师、顶尖高手成就								九天神珠	暴击
%% 24	九天神珠·真		完成铸造大神、铸甲大神、独孤求败成就								九天神珠·真	
%% 25	勾陈神珠			完成旷世神兵、神兵仙器、千年诛邪成就								勾陈神珠	攻击
%% 26	勾陈神珠·真		完成旷世神器、铸造大神、万年诛邪成就								勾陈神珠·真	
%% 27	直符神珠			成就达到1200														直符神珠	抗性
%% 28	直符神珠·真		成就达到3500														直符神珠·真	
check_achieve_treasure(Achieve, _PlayerId, AddAch, PidSend) ->
	#ets_achieve{ach_task = AchTask,
				 ach_epic = AchEpic,
				 ach_trials = AchTrials,		
				 ach_yg = AchYg,	
				 ach_fs = AchFs,	
				 ach_interact = AchInteract,
				 ach_treasure= AchTreasure} = Achieve,
	[_Ach101,Ach102,_Ach103,_Ach104,Ach105,_Ach106,_Ach107,Ach108,_Ach109,_Ach110,Ach111,Ach112,_Ach113,Ach114,Ach115,_Ach116,_Ach117,_Ach118,_Ach119,_Ach120,_Ach121,_Ach122,_Ach123,_Ach124,_Ach125,_Ach126,_Ach127,_Ach128] = AchTask,
%% 	?DEBUG("one",[]),
	[Ach201,Ach202,_Ach203,_Ach204,Ach205,Ach206,_Ach207,Ach208,_Ach209,Ach210,_Ach211,_Ach212,Ach213,Ach214,_Ach215,_Ach216,_Ach217,Ach218,_Ach219,Ach220,Ach221,_Ach222,_Ach223,_Ach224,_Ach225,_Ach226,_Ach227,_Ach228] = AchEpic,
%% 	?DEBUG("two",[]),
	[_Ach301,_Ach302,Ach303,Ach304,Ach305,_Ach306,_Ach307,_Ach308,Ach309,_Ach310,_Ach311,_Ach312,_Ach313,Ach314,Ach315,Ach316,Ach317,Ach318,Ach319,_Ach320,Ach321,Ach322,_Ach323,Ach324,Ach325,_Ach326,Ach327,Ach328,_Ach329,_Ach330,_Ach331,_Ach332,_Ach333,_Ach334,_Ach335,_Ach336,_Ach337,_Ach338,_Ach339,_Ach340,_Ach341,_Ach342,Ach343,_Ach344,_Ach345,_Ach346,_Ach347,_Ach348,_Ach349,_Ach350,_Ach351,_Ach352,_Ach353,_Ach354,_Ach355,_Ach356,_Ach357,_Ach358,_Ach359,_Ach360,_Ach361,_Ach362,_Ach363,_Ach364] = AchTrials,
%% 	?DEBUG("three",[]),
	[_Ach401,_Ach402,_Ach403,_Ach404,_Ach405,_Ach406,_Ach407,_Ach408,_Ach409,_Ach410,_Ach411,_Ach412,_Ach413,_Ach414,Ach415,Ach416,_Ach417,Ach418,Ach419,Ach420,Ach421,_Ach422,_Ach423,Ach424,_Ach425,_Ach426] = AchYg,
%% 	?DEBUG("four",[]),
	[Ach501,Ach502,Ach503,Ach504,_Ach505,_Ach506,_Ach507,_Ach508,_Ach509,_Ach510,Ach511,_Ach512,Ach513,_Ach514,Ach515,Ach516,Ach517,Ach518,Ach519,Ach520,_Ach521,_Ach522,_Ach523,_Ach524,_Ach525,_Ach526,_Ach527,_Ach528,_Ach529,_Ach530,_Ach531,_Ach532,_Ach533,_Ach534,_Ach535,_Ach536,_Ach537,_Ach538,_Ach539,_Ach540,_Ach541,_Ach542,_Ach543,_Ach544,_Ach545,_Ach546,_Ach547,_Ach548,_Ach549,_Ach550,_Ach551] = AchFs,
%% 	?DEBUG("five",[]),
	[_Ach601,_Ach602,_Ach603,_Ach604,_Ach605,_Ach606,_Ach607,_Ach608,_Ach609,_Ach610,_Ach611,_Ach612,_Ach613,_Ach614,_Ach615,_Ach616,_Ach617,_Ach618,_Ach619,_Ach620,_Ach621,_Ach622,_Ach623,_Ach624,_Ach625,_Ach626,_Ach627,_Ach628,_Ach629,_Ach630,_Ach631,_Ach632,_Ach633] = AchInteract,
%% 	?DEBUG("six",[]),
	[Ach,TS1,TS2,TS3,TS4,TS5,TS6,TS7,TS8,TS9,TS10,TS11,TS12,TS13,TS14,TS15,TS16,TS17,TS18,TS19,TS20,TS21,TS22,TS23,TS24,TS25,TS26,TS27,TS28,TS101,TS102,TS103,TS104,TS105,TS106,TS107,TS108] = AchTreasure,
	NewAch =Ach + AddAch,
%% 	?DEBUG("NewAch is :~p Old:~p", [NewAch, Ach]),
	{U108,V108,NTS108}=
		case TS108 =:= 0 andalso Ach504 =/= 0 of
			true ->
				{[1008],[{ts108,1}], [1]};
			false ->
				{[],[],[TS108]}
		end,
	{U107,V107,NTS107} =
		case TS107 =:= 0 andalso Ach201 =/= 0 of
			true ->
				{[1007|U108],[{ts107,1}|V108],[1|NTS108]};
			false ->
				{U108,V108,[TS107|NTS108]}
		end,
	{U106,V106,NTS106} =
		case TS106 =:= 0 andalso Ach202 =/= 0 of
			true ->
				{[1006|U107],[{ts106,1}|V107],[1|NTS107]};
			false ->
				{U107,V107,[TS106|NTS107]}
		end,
	{U105,V105,NTS105} =
		case TS105 =:= 0 andalso Ach515 =/= 0 of
			true ->
				{[1005|U106],[{ts105,1}|V106],[1|NTS106]};
			false ->
				{U106,V106,[TS105|NTS106]}
		end,
	{U104,V104,NTS104} =
		case TS104 =:= 0 andalso Ach317 =/= 0 of
			true ->
				{[1004|U105],[{ts104,1}|V105],[1|NTS105]};
			false ->
				{U105,V105,[TS104|NTS105]}
		end,
	{U103,V103,NTS103} =
		case TS103 =:= 0 andalso Ach343 =/= 0 of
			true ->
				{[1003|U104],[{ts103,1}|V104],[1|NTS104]};
			false ->
				{U104,V104,[TS103|NTS104]}
		end,
	{U102,V102,NTS102} =
		case TS102 =:= 0 andalso Ach221 =/= 0 of
			true ->
				{[1002|U103],[{ts102,1}|V103],[1|NTS103]};
			false ->
				{U103,V103,[TS102|NTS103]}
		end,
	{U101,V101,NTS101} =
		case TS101 =:= 0 andalso Ach424 =/= 0 of
			true ->
				{[1001|U102],[{ts101,1}|V102],[1|NTS102]};
			false ->
				{U102,V102,[TS101|NTS102]}
		end,
	
	{U28,V28,NTS28}=
		case TS28 =:= 0 andalso NewAch >= 3500 of
			true ->
				{[728|U101],[{ts28,1}|V101], [1|NTS101]};
			false ->
				{U101,V101,[TS28|NTS101]}
		end,
	{U27,V27,NTS27} =
		case TS27 =:= 0 andalso NewAch >= 1200 andalso NewAch < 3500 of
			true ->
				{[727|U28],[{ts27,1}|V28],[1|NTS28]};
			false ->
				{U28,V28,[TS27|NTS28]}
		end,
	{U26,V26,NTS26} =
		case TS26 =:= 0 of
			true ->
				case Ach206 =/= 0 andalso Ach214 =/= 0 andalso Ach503 =/= 0 of
					true ->
						{[726|U27],[{ts26,1}|V27],[1|NTS27]};
					false ->
						{U27,V27,[TS26|NTS27]}
				end;
			false ->
				{U27,V27,[TS26|NTS27]}
		end,
	{U25,V25,NTS25} =
		case TS25 =:= 0 of
			true ->
				case Ach205 =/= 0 andalso Ach213 =/= 0 andalso Ach502 =/= 0 of
					true ->
						{[725|U26],[{ts25,1}|V26], [1|NTS26]};
					false ->
						{U26,V26,[TS25|NTS26]}
				end;
			false ->
				{U26,V26,[TS25|NTS26]}
		end,
	{U24, V24, NTS24} = 
		case TS24 =:= 0 of
			true ->
				case Ach210 =/= 0 andalso Ach220 =/= 0 andalso Ach319 =/= 0 of
					true ->
						{[724|U25],[{ts25,1}|V25], [1|NTS25]};
					false ->
						{U25,V25,[TS24|NTS25]}
				end;
			false ->
				{U25,V25,[TS24|NTS25]}
		end,
	{U23, V23, NTS23} =
		case TS23 =:= 0 of
			true ->
				case Ach208 =/= 0 andalso Ach218 =/= 0 andalso Ach318 =/= 0 of
					true ->
						{[723|U24],[{ts23,1}|V24],[1|NTS24]};
					false ->
						{U24,V24,[TS23|NTS24]}
				end;
			false ->
				{U24,V24,[TS23|NTS24]}
		end,
	{U22,V22,NTS22} =
		case TS22 =:= 0 of
			true ->
				case Ach316 =/= 0 andalso Ach322 =/= 0 andalso Ach325 =/= 0 andalso Ach328 =/= 0 of
					true ->
						{[722|U23],[{ts22,1}|V23],[1|NTS23]};
					false ->
						{U23,V23,[TS22|NTS23]}
				end;
			false ->
				{U23,V23,[TS22|NTS23]}
		end,
	{U21,V21,NTS21} =
		case TS21 =:= 0 of
			true ->
				case Ach315 =/= 0 andalso Ach321 =/= 0 andalso Ach324 =/= 0 andalso Ach327 =/= 0 of
					true ->
						{[721|U22],[{ts21,1}|V22],[1|NTS22]};
					false ->
						{U22,V22,[TS21|NTS22]}
				end;
			false ->
				{U22,V22,[TS21|NTS22]}
		end,
	{U20,V20,NTS20} =
		case TS20 =:= 0 of
			true ->
				case Ach303 =/= 0 andalso Ach304 =/= 0 andalso Ach305 =/= 0 of
					true ->
						{[720|U21],[{ts20,1}|V21],[1|NTS21]};
					false ->
						{U21,V21,[TS20|NTS21]}
				end;
			false ->
				{U21,V21,[TS20|NTS21]}
		end,
	{U19,V19,NTS19} =
		case TS19 =:= 0 of
			true ->
				case Ach115 =/= 0 andalso Ach309 =/= 0 andalso Ach511 =/= 0 of
					true ->
						{[719|U20],[{ts19,1}|V20],[1|NTS20]};
					false ->
						{U20,V20,[TS19|NTS20]}
				end;
			false ->
				{U20,V20,[TS19|NTS20]}
		end,
	{U18,V18,NTS18} =
		case TS18 =:= 0 of
			true ->
				case Ach520 =/= 0 andalso Ach519 =/= 0 of
					true ->
						{[718|U19],[{ts18,1}|V19],[1|NTS19]};
					false ->
						{U19,V19,[TS18|NTS19]}
				end;
			false ->
				{U19,V19,[TS18|NTS19]}
		end,
	{U17,V17,NTS17} =
		case TS17 =:= 0 of
			true ->
				case Ach513 =/= 0 andalso Ach515 =/= 0 andalso Ach517 =/= 0 of
					true ->
						{[717|U18],[{ts17,1}|V18],[1|NTS18]};
					false ->
						{U18,V18,[TS17|NTS18]}
				end;
			false ->
				{U18,V18,[TS17|NTS18]}
		end,
	{U16,V16,NTS16} =
		case TS16 =:= 0 of
			true ->
				case Ach421 =/= 0 andalso Ach418 =/= 0 of
					true ->
						{[716|U17],[{ts16,1}|V17],[1|NTS17]};
					false ->
						{U17,V17,[TS16|NTS17]}
				end;
			false ->
				{U17,V17,[TS16|NTS17]}
		end,
	{U15,V15,NTS15} =
		case TS15 =:= 0 of
			true ->
				case Ach420 =/= 0 andalso Ach415 =/= 0 of
					true ->
						{[715|U16],[{ts15,1}|V16],[1|NTS16]};
					false ->
						{U16,V16,[TS15|NTS16]}
				end;
			false ->
				{U16,V16,[TS15|NTS16]}
		end,
	{U14,V14,NTS14} =
		case TS14 =:= 0 of
			true ->
				case Ach111 =/= 0 andalso Ach112 =/= 0 andalso Ach114 =/= 0 of
					true ->
						{[714|U15],[{ts14,1}|V15],[1|NTS15]};
					false ->
						{U15,V15,[TS14|NTS15]}
				end;
			false ->
				{U15,V15,[TS14|NTS15]}
		end,
	{U13,V13,NTS13} =
		case TS13 =:= 0 of
			true ->
				case Ach102 =/= 0 andalso Ach105 =/= 0 andalso Ach108 =/= 0 of
					true ->
						{[713|U14],[{ts13,1}|V14],[1|NTS14]};
					false ->
						{U14,V14,[TS13|NTS14]}
				end;
			false ->
				{U14,V14,[TS13|NTS14]}
		end,
	{U12,V12,NTS12} =
		case TS12 =:= 0 of
			true ->
				case Ach502 =/= 0 of
					true ->
						{[712|U13],[{ts12,1}|V13],[1|NTS13]};
					false ->
						{U13,V13,[TS12|NTS13]}
				end;
			false ->
				{U13,V13,[TS12|NTS13]}
		end,
	{U11,V11,NTS11} =
		case TS11 =:= 0 of
			true ->
				case Ach501 =/= 0 of
					true ->
						{[711|U12],[{ts11,1}|V12],[1|NTS12]};
					false ->
						{U12,V12,[TS11|NTS12]}
				end;
			false ->
				{U12,V12,[TS11|NTS12]}
		end,
	{U10,V10,NTS10} =
		case TS10 =:= 0 of
			true ->
				case Ach314 =/= 0 of
					true ->
						{[710|U11],[{ts10,1}|V11],[1|NTS11]};
					false ->
						{U11,V11,[TS10|NTS11]}
				end;
			false ->
				{U11,V11,[TS10|NTS11]}
		end,
	{U9,V9,NTS9} =
		case TS9 =:= 0 of
			true ->
				case Ach518 =/= 0 of
					true ->
						{[709|U11],[{ts9,1}|V10],[1|NTS10]};
					false ->
						{U10,V10,[TS9|NTS10]}
				end;
			false ->
				{U10,V10,[TS9|NTS10]}
		end,
	{U8,V8,NTS8} =
		case TS8 =:= 0 of
			true ->
				case Ach517 =/= 0 of
					true ->
						{[708|U9],[{ts8,1}|V9],[1|NTS9]};
					false ->
						{U9,V9,[TS8|NTS9]}
				end;
			false ->
				{U9,V9,[TS8|NTS9]}
		end,
	{U7,V7,NTS7} =
		case TS7 =:= 0 of
			true ->
				case Ach516 =/= 0 of
					true ->
						{[707|U8],[{ts7,1}|V8],[1|NTS8]};
					false ->
						{U8,V8,[TS7|NTS8]}
				end;
			false ->
				{U8,V8,[TS7|NTS8]}
		end,
	{U6,V6,NTS6} =
		case TS6 =:= 0 of
			true ->
				case Ach515 =/= 0 of
					true ->
						{[706|U7],[{ts6,1}|V7],[1|NTS7]};
					false ->
						{U7,V7,[TS6|NTS7]}
				end;
			false ->
				{U7,V7,[TS6|NTS7]}
		end,
	{U5,V5,NTS5} =
		case TS5 =:= 0 of
			true ->
				case Ach416 =/= 0 of
					true ->
						{[705|U6],[{ts5,1}|V6],[1|NTS6]};
					false ->
						{U6,V6,[TS5|NTS6]}
				end;
			false ->
				{U6,V6,[TS5|NTS6]}
		end,
	{U4,V4,NTS4} =
		case TS4 =:= 0 of
			true ->
				case Ach419 =/= 0 of
					true ->
						{[704|U5],[{ts4,1}|V5],[1|NTS5]};
					false ->
						{U5,V5,[TS4|NTS5]}
				end;
			false ->
				{U5,V5,[TS4|NTS5]}
		end,
	{U3,V3,NTS3} =
		case TS3 =:= 0 andalso NewAch >= 1000 andalso NewAch < 1200 of
			true ->
				{[703|U4],[{ts3,1}|V4],[1|NTS4]};
			false ->
				{U4,V4,[TS3|NTS4]}
		end,
	{U2,V2,NTS2} =
		case TS2 =:= 0 andalso NewAch >= 500 andalso NewAch < 1000 of
			true ->
				{[702|U3],[{ts2,1}|V3],[1|NTS3]};
			false ->
				{U3,V3,[TS2|NTS3]}
		end,
	{U1,_V1,NTS1} =
		case TS1 =:= 0 andalso NewAch >= 100 andalso NewAch < 500 of
			true ->
				{[701|U2],[{ts1,1}|V2],[1|NTS2]};
			false ->
				{U2,V2,[TS1|NTS2]}
		end,
	NewTreasure = [NewAch|NTS1],
%% 	ValueList = [{ach,NewAch}|V1],
%% 	WhereList = [{pid, PlayerId}],
%% 	db_agent:update_player_achieve(ach_treasure, ValueList, WhereList),
	NewAchive = Achieve#ets_achieve{ach_treasure = NewTreasure},
	update_achieve_ets(NewAchive),	
	case U1 of
		[] ->
			skip;
		_Have ->
			{ok, BinData38016} = pt_38:write(38016, [U1]),
			lib_send:send_to_sid(PidSend, BinData38016)
	end,
	U1.

%%更新ETS_ACHIEVE表的ets记录
update_achieve_ets(AchieveEts) ->
	ets:insert(?ETS_ACHIEVE, AchieveEts).
%%获取ETS_ACHIEVE表的ets记录
get_achieve_ets(PlayerId) ->
	 ets:lookup(?ETS_ACHIEVE, PlayerId).

%%经脉由ets转成list
meri_to_list(Meri) ->
	[{Meri#ets_meridian.mer_yang, Meri#ets_meridian.mer_yang_linggen},
	 {Meri#ets_meridian.mer_yin, Meri#ets_meridian.mer_yin_linggen},
	 {Meri#ets_meridian.mer_wei, Meri#ets_meridian.mer_wei_linggen},
	 {Meri#ets_meridian.mer_ren, Meri#ets_meridian.mer_ren_linggen},
	 {Meri#ets_meridian.mer_du, Meri#ets_meridian.mer_du_linggen},
	 {Meri#ets_meridian.mer_chong, Meri#ets_meridian.mer_chong_linggen},
	 {Meri#ets_meridian.mer_qi, Meri#ets_meridian.mer_qi_linggen},
	 {Meri#ets_meridian.mer_dai, Meri#ets_meridian.mer_dai_linggen}].
lists_check_meri(MeriList) ->
	lists:foldl(
	  fun(Elem, AccIn) ->
			  {EMLv,EMLg} = Elem,
			  {EMerLg1, EMerLg2, EMerLg3,
			   EMerLv1, EMerLv2, EMerLv3, EMerLv4, EMerLv5} = AccIn,
			  if
				  EMLg >= 100 ->
					  NEMerLg1 = EMerLg1 + 1,
					  NEMerLg2 = EMerLg2 + 1,
					  NEMerLg3 = 1;
				  EMLg >= 70 ->
					  NEMerLg1 = EMerLg1 + 1,
					  NEMerLg2 = EMerLg2,
					  NEMerLg3 = 1;
				  EMLg > 0 ->
					  NEMerLg1 = EMerLg1,
					  NEMerLg2 = EMerLg2,
					  NEMerLg3 = 1;
				  true ->
					  NEMerLg1 = EMerLg1,
					  NEMerLg2 = EMerLg2,
					  NEMerLg3 = EMerLg3
			  end,
			  if
				  EMLv >= 15 ->
					  NEMerLv1 = EMerLv1 +1,
					  NEMerLv2 = EMerLv2 +1,
					  NEMerLv3 = EMerLv3 +1,
					  NEMerLv4 = EMerLv4 +1,
					  NEMerLv5 = 1;
				  EMLv >= 10 ->
					  NEMerLv1 = EMerLv1 +1,
					  NEMerLv2 = EMerLv2 +1,
					  NEMerLv3 = EMerLv3 +1,
					  NEMerLv4 = EMerLv4,
					  NEMerLv5 = 1;
				  EMLv >= 7 ->
					  NEMerLv1 = EMerLv1 +1,
					  NEMerLv2 = EMerLv2 +1,
					  NEMerLv3 = EMerLv3,
					  NEMerLv4 = EMerLv4,
					  NEMerLv5 = 1;
				  EMLv >= 5 ->
					  NEMerLv1 = EMerLv1 +1,
					  NEMerLv2 = EMerLv2,
					  NEMerLv3 = EMerLv3,
					  NEMerLv4 = EMerLv4,
					  NEMerLv5 = 1;
				  EMLv > 0 ->
					  NEMerLv1 = EMerLv1,
					  NEMerLv2 = EMerLv2,
					  NEMerLv3 = EMerLv3,
					  NEMerLv4 = EMerLv4,
					  NEMerLv5 = 1;
				  true ->
					  NEMerLv1 = EMerLv1,
					  NEMerLv2 = EMerLv2,
					  NEMerLv3 = EMerLv3,
					  NEMerLv4 = EMerLv4,
					  NEMerLv5 = EMerLv5
			  end,
			  {NEMerLg1, NEMerLg2,NEMerLg3,
			   NEMerLv1, NEMerLv2, NEMerLv3, NEMerLv4, NEMerLv5}
	  end, {0,0,0,0,0,0,0,0},	MeriList).
fail_noup_to_list(Result) ->
	if
		is_list(Result) =:= true ->
			Result;
		Result =:= fail ->
			[];
		Result =:= no_update ->
			[];
		Result =:= ok ->
			[];
		true ->
			[]
	end.
			
box_achieve_check(PidSend, PlayerId) ->
	 [One, Two, Three] = 
		 lists:map(fun(Elem) ->
						   case db_agent:get_box_open_nums(PlayerId, Elem) of
							   [] ->
								   0;
							   Counts ->
								   Count = lists:flatten(Counts),
								   lists:sum(Count)
						   end
				   end,[1,2,3]),
	 lib_achieve:check_achieve_finish(PidSend, PlayerId, 501, [One]),	%%百年
	 lib_achieve:check_achieve_finish(PidSend, PlayerId, 502, [Two]),	%%千年
	 lib_achieve:check_achieve_finish(PidSend, PlayerId, 503, [Three]).	%%万年
					
put_achieve_update(Type) ->
	put(Type, 1).
get_achieve_update(Type) ->
	get(Type).

%%计算成就点
add_achieve_ach(Type, List) ->
	lists:foldl(fun(Elem, AccIn) ->
						Ach = data_achieve:get(Type, Elem),
						AccIn + Ach
				end, 0, List).

	
check_final_ok(0,_List,Result) ->
	Result;
check_final_ok(Num, [Elem|List],Result) ->
	case Elem =:= 0 of
		true ->
			check_final_ok(Num -1,List, false);
		false ->
			check_final_ok(Num -1,List, Result)
	end.


update_achieve_info_finish(AType, UpList, Achieve, PlayerId) ->
	lists:foldl(fun(Elem, AccIn) ->
						lib_achieve_outline:get_achieve_title(AType, Elem, AccIn, PlayerId)
				end, Achieve, UpList).
	

%%获取玩家的新称号和判断是否能够获取
update_player_titles(AchAtom, AType, SAType, Ach, AchNum, Titles, Achieve, PlayerId) ->
	case lib_achieve_inline:check_and_update(SAType, Ach, AchNum, Titles) of
		{fail, _Result} ->
			Achieve;
		{ok, NewAch, NewTitles} ->
			NewAchieve = get_newachieve(AchAtom, NewAch, NewTitles, Achieve),
			%%更新数据表
			%%更新ach表
			ValueList = data_achieve:make_update_list([{AType,SAType,1}]),
			WhereList = [{pid,PlayerId}],
	%%		?DEBUG("ValueList: ~p", [ValueList]),
			db_agent:update_player_achieve(AchAtom, ValueList, WhereList),
			%%更新player_other表
%% 			db_agent:update_player_other_titles(NewTitles, PlayerId),
			%%更新ets表
			update_achieve_ets(NewAchieve),
			NewAchieve
	end.
get_newachieve(AchAtom, NewAch, NewTitles,Achieve) ->
	case AchAtom of
		ach_task ->
			Achieve#ets_achieve{ach_task = NewAch,
								ach_titles = NewTitles};
		ach_epic ->
			Achieve#ets_achieve{ach_epic = NewAch,
								ach_titles = NewTitles};
		ach_trials ->
			Achieve#ets_achieve{ach_trials = NewAch,
								ach_titles = NewTitles};
		ach_yg ->
			Achieve#ets_achieve{ach_yg = NewAch,
								ach_titles = NewTitles};
		ach_fs ->
			Achieve#ets_achieve{ach_fs = NewAch,
								ach_titles = NewTitles};
		ach_interact ->
			Achieve#ets_achieve{ach_interact = NewAch,
								ach_titles = NewTitles}
	end.

%%检查称号是否已经领取或者是否能够领取
check_and_update(SAType, Ach, AchNum, Titles) ->
	Check = lists:nth(SAType, Ach),
	case Check of
		0 ->%%还不能领取
			{fail, 2};
		2 ->%%已经领取过了
			{fail, 3};
		1 ->%%可以领取哦
			NewAch = tool:replace(Ach, SAType, 1),
			NewTitle = #p_title_elem{tid = AchNum,
									 expi = 1},
			NewTitles = 
				case lists:keyfind(AchNum, #p_title_elem.tid, Titles) of
					false ->
						[NewTitle|Titles];
					_ ->
						lists:keyreplace(AchNum, #p_title_elem.tid, Titles, NewTitle)
				end,
			{ok, NewAch, NewTitles}
	end.

%% %%过滤过期的玩家称号
%% get_player_titles(PTitles) ->
%% 	lists:foldl(fun(Elem, AccIn) ->
%% 						#p_title_elem{expi = Expire} = Elem,
%% 						{Type, List} = AccIn,
%% 						case Expire of
%% 							 0 ->
%% 								{Type,[Elem|List]};
%% 							1 ->
%% 								{Type, [Elem|List]};
%% 							_ ->
%% 								Now = util:unixtime(),
%% 								if
%% 									Expire < Now ->
%% 										{update_titles, List};
%% 									true ->
%% 										{Type, [Elem|List]}
%% 								end
%% 						end
%% 				end, {no_update,[]},PTitles).

%%初始化玩家的成就日志
init_achieve_log(PlayerId) ->
	case db_agent:get_ach_log(PlayerId) of
		[] ->%%没有日志，直接从50倒数开始
			skip;
		Logs ->
			load_log_into_ets(Logs,PlayerId)
	end.
			
load_log_into_ets(Logs,PlayerId) ->
	lists:foreach(fun(Elem) ->
						  [Id, AchNum, Time] = Elem,
						  NewLog = #ets_log_ach_f{id = Id,
												  pid = PlayerId,
												  ach_num = AchNum,
												  time = Time},
						  ets:insert(?ACHIEVE_LOG,NewLog)
				  end, Logs).
						
insert_achieve_log(AType, UpList, PlayerId) ->
	Now = util:unixtime(),
	lists:foreach(fun(Elem) ->
						  AchNum = AType * 100 + Elem,
						  Log = #ets_log_ach_f{pid = PlayerId,
											   ach_num = AchNum,
											   time = Now},
						  {_, Id} = db_agent:insert_ach_log(Log),
						  NewLog = Log#ets_log_ach_f{id = Id},
						  ets:insert(?ACHIEVE_LOG, NewLog)
				  end,UpList).

%% -----------------------------------------------------------------
%% 38000 总成就获取
%% -----------------------------------------------------------------
get_achieve_task(AchTask,AChStatistics,_Player) ->
	[Ach101,Ach102,Ach103,Ach104,Ach105,Ach106,Ach107,Ach108,Ach109,Ach110,
	 Ach111,Ach112,Ach113,Ach114,Ach115,Ach116,Ach117,Ach118,Ach119,Ach120,
	  Ach121,Ach122,Ach123,Ach124,Ach125,Ach126,Ach127,Ach128]= AchTask,
	#ets_ach_stats{trc = TRC,                 %% 完成日常任务次数	
				   tg = TG,                   %% 完成氏族任务次数	
				   tfb = TFB,                 %% 完成副本任务次数
				   tcul = TCUL,               %% 完成修为任务次数	
				   tca = TCA,                 %% 完成运镖任务次数	
				   tbus = TBUS,               %% 完成跑商任务次数	
				   tfst = TFST,               %% 完成封神贴任务	
				   tcyc = TCYC                %% 完成循环任务次数
				  } = 	AChStatistics,
	Task1 = [{101, Ach101, ?ACH_FINISH_RATE, Ach101}],
	Task2 = [{102, TRC, ?TASK_RC_ONE, Ach102}|Task1],
	Task3 = [{103, TRC, ?TASK_RC_TWO, Ach103}|Task2],
	Task4 = [{104, TG, ?TASK_GUILD_ONE, Ach104}|Task3],
	Task5 = [{105, TG, ?TASK_GUILD_TWO, Ach105}|Task4],
	Task6 = [{106, TG, ?TASK_GUILD_THREE, Ach106}|Task5],
	Task7 = [{107, TFB, ?TASK_FB_ONE, Ach107}|Task6],
	Task8 = [{108, TFB, ?TASK_FB_TWO, Ach108}|Task7],
	Task9 = [{109, TFB, ?TASK_FB_THREE, Ach109}|Task8],
	Task10 = [{110, TCUL, ?TASK_CULTURE_ONE, Ach110}|Task9],
	Task11 = [{111, TCUL, ?TASK_CULTURE_TWO, Ach111}|Task10],
	Task12 = [{112, TCA, ?TASK_CARRY_ONE, Ach112}|Task11],
	Task13 = [{113, TCA, ?TASK_CARRY_TWO, Ach113}|Task12],
	Task14 = [{114, TBUS, ?TASK_BUS_ONE, Ach114}|Task13],
	Task15 = [{115, TBUS, ?TASK_BUS_TWO, Ach115}|Task14],
	Task16 = [{116, TFST, ?TASK_FST_ONE, Ach116}|Task15],
	Task17 = [{117, TFST, ?TASK_FST_TWO, Ach117}|Task16],
	Task18 = [{118, TCYC, ?TASK_CYCLE_ONE, Ach118}|Task17],
	Task19 = [{119, TCYC, ?TASK_CYCLE_TWO, Ach119}|Task18],
	Task20 = [{120, Ach120, ?ACH_FINISH_RATE, Ach120}|Task19],
	Task21 = [{121, Ach121, ?ACH_FINISH_RATE, Ach121}|Task20],
	Task22 = [{122, Ach122, ?ACH_FINISH_RATE, Ach122}|Task21],
	Task23 = [{123, Ach123, ?ACH_FINISH_RATE, Ach123}|Task22],
	Task24 = [{124, Ach124, ?ACH_FINISH_RATE, Ach124}|Task23],
	Task25 = [{125, Ach125, ?ACH_FINISH_RATE, Ach125}|Task24],
	Task26 = [{126, Ach126, ?ACH_FINISH_RATE, Ach126}|Task25],
	Task27 = [{127, Ach127, ?ACH_FINISH_RATE, Ach127}|Task26],
	[{128, Ach128,?ACH_FINISH_RATE, Ach128}|Task27].

get_achieve_epic(AchEpic, _AchStatistics, _Player) ->
	[Ach201,Ach202,Ach203,Ach204,Ach205,Ach206,Ach207,Ach208,Ach209,Ach210,
	 Ach211,Ach212,Ach213,Ach214,Ach215,Ach216,Ach217,Ach218,Ach219,Ach220,
	 Ach221,Ach222,Ach223,Ach224,Ach225,Ach226,Ach227,Ach228] = AchEpic,
	Epic1 = [{201, Ach201, ?ACH_FINISH_RATE, Ach201}],
	Epic2 = [{202, Ach202, ?ACH_FINISH_RATE, Ach202}|Epic1],
	Epic3 = [{203, Ach203, ?ACH_FINISH_RATE, Ach203}|Epic2],
	Epic4 = [{204, Ach204, ?ACH_FINISH_RATE, Ach204}|Epic3],
	Epic5 = [{205, Ach205, ?ACH_FINISH_RATE, Ach205}|Epic4],
	Epic6 = [{206, Ach206, ?ACH_FINISH_RATE, Ach206}|Epic5],
	Epic7 = [{207, Ach207, ?ACH_FINISH_RATE, Ach207}|Epic6],
	Epic8 = [{208, Ach208, ?ACH_FINISH_RATE, Ach208}|Epic7],
	Epic9 = [{209, Ach209, ?ACH_FINISH_RATE, Ach209}|Epic8],
	Epic10 = [{210, Ach210, ?ACH_FINISH_RATE, Ach210}|Epic9],
	Epic11 = [{211, Ach211, ?ACH_FINISH_RATE, Ach211}|Epic10],
	Epic12 = [{212, Ach212, ?ACH_FINISH_RATE, Ach212}|Epic11],
	Epic13 = [{213, Ach213, ?ACH_FINISH_RATE, Ach213}|Epic12],
	Epic14 = [{214, Ach214, ?ACH_FINISH_RATE, Ach214}|Epic13],
	Epic15 = [{215, Ach215, ?ACH_FINISH_RATE, Ach215}|Epic14],
	Epic16 = [{216, Ach216, ?ACH_FINISH_RATE, Ach216}|Epic15],
	Epic17 = [{217, Ach217, ?ACH_FINISH_RATE, Ach217}|Epic16],
	Epic18 = [{218, Ach218, ?ACH_FINISH_RATE, Ach218}|Epic17],
	Epic19 = [{219, Ach219, ?ACH_FINISH_RATE, Ach219}|Epic18],
	Epic20 = [{220, Ach220, ?ACH_FINISH_RATE, Ach220}|Epic19],
	Epic21 = [{221, Ach221, ?ACH_FINISH_RATE, Ach221}|Epic20],
	Epic22 = [{222, Ach222, ?ACH_FINISH_RATE, Ach222}|Epic21],
	Epic23 = [{223, Ach223, ?ACH_FINISH_RATE, Ach223}|Epic22],
	Epic24 = [{224, Ach224, ?ACH_FINISH_RATE, Ach224}|Epic23],
	Epic25 = [{225, Ach225, ?ACH_FINISH_RATE, Ach225}|Epic24],
	Epic26 = [{226, Ach226, ?ACH_FINISH_RATE, Ach226}|Epic25],
	Epic27 = [{227, Ach227, ?ACH_FINISH_RATE, Ach227}|Epic26],
	[{228, Ach228, ?ACH_FINISH_RATE, Ach228}|Epic27].
	
get_achieve_trials(AchTrials, AchStatistics, _Player) ->
	[Ach301,Ach302,Ach303,Ach304,Ach305,Ach306,Ach307,Ach308,Ach309,Ach310,
	 Ach311,Ach312,Ach313,Ach314,Ach315,Ach316,Ach317,Ach318,Ach319,Ach320,
	 Ach321,Ach322,Ach323,Ach324,Ach325,Ach326,Ach327,Ach328,Ach329,Ach330,
	 Ach331,Ach332,Ach333,Ach334,Ach335,Ach336,Ach337,Ach338,Ach339,Ach340,
	 Ach341,Ach342,Ach343,Ach344,Ach345,Ach346,Ach347,Ach348,Ach349,Ach350,
	 Ach351,Ach352,Ach353,Ach354,Ach355,Ach356,Ach357,Ach358,Ach359,Ach360,
	 Ach361,Ach362,Ach363,Ach364] = AchTrials,
	#ets_ach_stats{trm = TRM,                                %% 杀击怪物次数	
				   trb = [TRBOne, TRBTwo,TRBThree, TRBFour,TRBFive,TRBSix],%% <<"[0,0,0,0,0,0]">>,杀击boss次数[火凤，千年老龟，烈焰麒麟兽，灵狐，裂地斧魔，千年猴妖]	
				   trbc = [TRBCOne,TRBCTwo,TRBCThree],         %% <<"[0,0,0]">>,成功劫镖和劫商次数记录	
				   trbus = TRBUS,                              %% 成功跑商次数	
				   trfst = [TRFSTOne,TRFSTTwo,TRFSTThree],     %% <<"[0,0,0]">>,封神台通关次数[12，21，45]层	
				   trar = TRAR,                                %% 场战杀敌次数	
				   trf = TRF,                                  %% 氏族战运旗次数	
				   trstd = [TRSTDOne,TRSTDTwo,TRSTDThree],     %% <<"[0,0,0]">>,单人镇妖台杀怪物次数[千年毒尸，龙骨甲兽，食腐树妖]	
				   trmtd = [TRMTDOne,TRMTDTwo,TRMTDThree],     %% <<"[0,0,0]">>,多人镇妖台杀怪物次数[千年毒尸，龙骨甲兽，食腐树妖]	
				   trfbb = [TRFBBOne,TRFBBTwo,TRFBBThree,TRFBBFour],     %% <<"[0,0,0,0]">>,杀击副本boss次数[雷公，狐小小，河伯，蚩尤]	
				   trsixfb = [TRSIXFBOne,TRSIXFBTwo,TRSIXFBThree],		%% 击杀怪物次数[穷奇巨兽，赤尾狐，瑶池圣母]
				   trzxt = [TRZXTOne,TRZXTTwo,TRZXTThree],				%% 诛仙台通关次数[12，21，30]层
				   trsm = TRSM,                               %% 神魔乱斗参与击败哈迪斯的次数	
				   trtrain = TRTRAIN,                            %% 击败试炼之祖的次数	
				   trjl = TRJL,                               %% 击败蛮荒巨龙的次数	
				   trds = TRDS,                               %% 击败千年毒尸的次数	
				   trgg = TRGG                               %% 击杀共工次数
				  } = AchStatistics,
	Trials1 = [{301, TRM, ?TRIALS_TRM_ONE, Ach301}],
	Trials2 = [{302, TRM, ?TRIALS_TRM_TWO, Ach302}|Trials1],
	Trials3 = [{303, TRBOne, ?TRIALS_BOSS_ONE, Ach303}|Trials2],
	Trials4 = [{304, TRBTwo, ?TRIALS_BOSS_TWO, Ach304}|Trials3],
	Trials5 = [{305, TRBThree, ?TRIALS_BOSS_THREE, Ach305}|Trials4],
	Trials6 = [{306, TRBFour, ?TRIALS_BOSS_FOUR, Ach306}|Trials5],
	Trials7 = [{307, TRBFive, ?TRIALS_BOSS_FIVE, Ach307}|Trials6],
	Trials8 = [{308, TRBSix, ?TRIALS_BOSS_SIX, Ach308}|Trials7],
	Trials9 = [{309, TRBCOne, ?TRIALS_TRBC_ONE, Ach309}|Trials8],
	Trials10 = [{310, TRBCTwo, ?TRIALS_TRBC_TWO, Ach310}|Trials9],
	Trials11 = [{311, TRBCThree, ?TRIALS_TRBC_THREE, Ach311}|Trials10],
	Trials12 = [{312, TRBUS, ?TRIALS_TRBUS_ONE, Ach312}|Trials11],
	Trials13 = [{313, TRBUS, ?TRIALS_TRBUS_TWO, Ach313}|Trials12],
	Trials14 = [{314, TRFSTOne, ?TRIALS_TRFST_ONE, Ach314}|Trials13],
	Trials15 = [{315, TRFSTTwo, ?TRIALS_TRFST_TWO, Ach315}|Trials14],
	Trials16 = [{316, TRFSTThree, ?TRIALS_TRFST_THREE, Ach316}|Trials15],
	Trials17 = [{317, TRAR, ?TRIALS_TRAR_ONE, Ach317}|Trials16],
	Trials18 = [{318, TRAR, ?TRIALS_TRAR_TWO, Ach318}|Trials17],
	Trials19 = [{319, TRAR, ?TRIALS_TRAR_THREE, Ach319}|Trials18],
	Trials20 = [{320, TRF, ?TRIALS_TRF_ONE, Ach320}|Trials19],
	Trials21 = [{321, TRF, ?TRIALS_TRF_TWO, Ach321}|Trials20],
	Trials22 = [{322, TRF, ?TRIALS_TRF_THREE, Ach322}|Trials21],
	Trials23 = [{323, TRSTDOne, ?TRIALS_TRSTD_ONE, Ach323}|Trials22],
	Trials24 = [{324, TRSTDTwo, ?TRIALS_TRSTD_TWO, Ach324}|Trials23],
	Trials25 = [{325, TRSTDThree, ?TRIALS_TRSTD_THREE, Ach325}|Trials24],
	Trials26 = [{326, TRMTDOne, ?TRIALS_TRMTD_ONE, Ach326}|Trials25],
	Trials27 = [{327, TRMTDTwo, ?TRIALS_TRMTD_TWO, Ach327}|Trials26],
	Trials28 = [{328, TRMTDThree, ?TRIALS_TRMTD_THREE, Ach328}|Trials27],
	Trials29 = [{329, TRFBBOne, ?TRIALS_TRFBB_ONE, Ach329}|Trials28],
	Trials30 = [{330, TRFBBTwo, ?TRIALS_TRFBB_TWO, Ach330}|Trials29],
	Trials31 = [{331, TRFBBThree, ?TRIALS_TRFBB_THREE, Ach331}|Trials30],
	Trials32 = [{332, TRFBBFour, ?TRIALS_TRFBB_FOUR, Ach332}|Trials31],
	Trials33 = [{333, Ach333, ?ACH_FINISH_RATE, Ach333}|Trials32],
	Trials34 = [{334, Ach334, ?ACH_FINISH_RATE, Ach334}|Trials33],
	Trials35 = [{335, Ach335, ?ACH_FINISH_RATE, Ach335}|Trials34],
	Trials36 = [{336, Ach336, ?ACH_FINISH_RATE, Ach336}|Trials35],
	Trials37 = [{337, Ach337, ?ACH_FINISH_RATE, Ach337}|Trials36],
	Trials38 = [{338, Ach338, ?ACH_FINISH_RATE, Ach338}|Trials37],
	Trials39 = [{339, Ach339, ?ACH_FINISH_RATE, Ach339}|Trials38],
	Trials40 = [{340, TRSIXFBOne, ?TRIALS_TRSIXFB_ONE, Ach340}|Trials39],
	Trials41 = [{341, Ach341, ?ACH_FINISH_RATE, Ach341}|Trials40],
	Trials42 = [{342, TRSIXFBTwo, ?TRIALS_TRSIXFB_TWO, Ach342}|Trials41],
	Trials43 = [{343, Ach343, ?ACH_FINISH_RATE, Ach343}|Trials42],
	Trials44 = [{344, Ach344, ?ACH_FINISH_RATE, Ach344}|Trials43],
	Trials45 = [{345, Ach345, ?ACH_FINISH_RATE, Ach345}|Trials44],
	Trials46 = [{346, Ach346, ?ACH_FINISH_RATE, Ach346}|Trials45],
	Trials47 = [{347, Ach347, ?ACH_FINISH_RATE, Ach347}|Trials46],
	Trials48 = [{348, Ach348, ?ACH_FINISH_RATE, Ach348}|Trials47],
	Trials49 = [{349, TRZXTOne, ?TRIALS_TRZXT_ONE, Ach349}|Trials48],
	Trials50 = [{350, TRZXTTwo, ?TRIALS_TRZXT_TWO, Ach350}|Trials49],
	Trials51 = [{351, TRZXTThree, ?TRIALS_TRZXT_THREE, Ach351}|Trials50],
	Trials52 = [{352, TRSIXFBThree, ?TRIALS_TRSIXFB_THREE, Ach352}|Trials51],
	Trials53 = [{353, TRSM, ?ACH_FINISH_RATE, Ach353}|Trials52],
	Trials54 = [{354, TRSM, ?TRIALS_TRSM_ONE, Ach354}|Trials53],
	Trials55 = [{355, TRSM, ?TRIALS_TRSM_TWO, Ach355}|Trials54],
	Trials56 = [{356, TRTRAIN, ?ACH_FINISH_RATE, Ach356}|Trials55],
	Trials57 = [{357, TRTRAIN, ?TRIALS_TRTRAIN_ONE, Ach357}|Trials56],
	Trials58 = [{358, TRTRAIN, ?TRIALS_TRTRAIN_TWO, Ach358}|Trials57],
	Trials59 = [{359, TRGG, ?TRIALS_TRGG_NUM, Ach359}|Trials58],
	Trials60 = [{360, TRDS, ?ACH_FINISH_RATE, Ach360}|Trials59],
	Trials61 = [{361, TRDS, ?TRIALS_TRDS_NUM, Ach361}|Trials60],
	Trials62 = [{362, TRJL, ?ACH_FINISH_RATE, Ach362}|Trials61],
	Trials63 = [{363, TRJL, ?TRIALS_TRJL_NUM, Ach363}|Trials62],
	[{364, Ach364, ?ACH_FINISH_RATE, Ach364}|Trials63].

get_achieve_yg(AchYg, AchStatistics, _Player) ->
	 [Ach401,Ach402,Ach403,Ach404,Ach405,Ach406,Ach407,Ach408,Ach409,Ach410,
	  Ach411,Ach412,Ach413,Ach414,Ach415,Ach416,Ach417,Ach418,Ach419,Ach420,
	  Ach421,Ach422,Ach423,Ach424,Ach425,Ach426] = AchYg,
	 #ets_ach_stats{ygcul = YgCul} = AchStatistics,
	 Yg1 = [{401, Ach401, ?ACH_FINISH_RATE, Ach401}],
	 Yg2 = [{402, Ach402, ?ACH_FINISH_RATE, Ach402}|Yg1],
	 Yg3 = [{403, Ach403, ?ACH_FINISH_RATE, Ach403}|Yg2],
	 Yg4 = [{404, Ach404, ?ACH_FINISH_RATE, Ach404}|Yg3],
	 Yg5 = [{405, Ach405, ?ACH_FINISH_RATE, Ach405}|Yg4],
	 Yg6 = [{406, Ach406, ?ACH_FINISH_RATE, Ach406}|Yg5],
	 Yg7 = [{407, YgCul, ?YG_CULTURE_ONE, Ach407}|Yg6],
	 Yg8 = [{408, YgCul, ?YG_CULTURE_TWO, Ach408}|Yg7],
	 Yg9 = [{409, YgCul, ?YG_CULTURE_THREE, Ach409}|Yg8],
	 Yg10 = [{410, Ach410, ?ACH_FINISH_RATE, Ach410}|Yg9],
	 Yg11 = [{411, Ach411, ?ACH_FINISH_RATE, Ach411}|Yg10],
	 Yg12 = [{412, Ach412, ?ACH_FINISH_RATE, Ach412}|Yg11],
	 Yg13 = [{413, Ach413, ?ACH_FINISH_RATE, Ach413}|Yg12],
	 Yg14 = [{414, Ach414, ?ACH_FINISH_RATE, Ach414}|Yg13],
	 Yg15 = [{415, Ach415, ?ACH_FINISH_RATE, Ach415}|Yg14],
	 Yg16 = [{416, Ach416, ?ACH_FINISH_RATE, Ach416}|Yg15],
	 Yg17 = [{417, Ach417, ?ACH_FINISH_RATE, Ach417}|Yg16],
	 Yg18 = [{418, Ach418, ?ACH_FINISH_RATE, Ach418}|Yg17],
	 Yg19 = [{419, Ach419, ?ACH_FINISH_RATE, Ach419}|Yg18],
	 Yg20 = [{420, Ach420, ?ACH_FINISH_RATE, Ach420}|Yg19],
	 Yg21 = [{421, Ach421, ?ACH_FINISH_RATE, Ach421}|Yg20],
	 Yg22 = [{422, Ach422, ?ACH_FINISH_RATE, Ach422}|Yg21],
	 Yg23 = [{423, Ach423, ?ACH_FINISH_RATE, Ach423}|Yg22],
	 Yg24 = [{424, Ach424, ?ACH_FINISH_RATE, Ach424}|Yg23],
	 Yg25 = [{425, Ach425, ?ACH_FINISH_RATE, Ach425}|Yg24],
	 [{426, Ach426, ?ACH_FINISH_RATE, Ach426}|Yg25].

get_achieve_fs(AchFs, AchStatistics, _Player) ->
	[Ach501,Ach502,Ach503,Ach504,Ach505,Ach506,Ach507,Ach508,Ach509,Ach510,
	 Ach511,Ach512,Ach513,Ach514,Ach515,Ach516,Ach517,Ach518,Ach519,Ach520,
	 Ach521,Ach522,Ach523,Ach524,Ach525,Ach526,Ach527,Ach528,Ach529,Ach530,
	 Ach531,Ach532,Ach533,Ach534,Ach535,Ach536,Ach537,Ach538,Ach539,Ach540,
	 Ach541,Ach542,Ach543,Ach544,Ach545,Ach546,Ach547,Ach548,Ach549,Ach550,
	 Ach551] = AchFs,
	#ets_ach_stats{fsb = [FSBOne,FSBTwo,FSBThree], %% <<"[0,0,0]">>,诛邪次数统计[百年，千年，万年]	
				   fssh = FSSH,                    %% 商城购买道具次数	
				   fsc = [FSCOne,FSCTwo],          %% <<"[0,0]">>,物品合成和分解次数统计[石头合成，装备分解]	
				   fssa = [FSSAOne,FSSATwo],       %% <<"[0,0]">>,市场挂售和购买次数统计[市场挂售，市场购买]	
				   fslg = FSLG                     %% 离线挂机时间统计	
				  } = AchStatistics,
	Fs1 = [{501, FSBOne, ?FS_FSB_ONE, Ach501}],
	Fs2 = [{502, FSBTwo, ?FS_FSB_TWO, Ach502}|Fs1],
	Fs3 = [{503, FSBThree, ?FS_FSB_THREE, Ach503}|Fs2],
	Fs4 = [{504, Ach504, ?ACH_FINISH_RATE, Ach504}|Fs3],
	Fs5 = [{505, FSSH, ?FS_FSSH, Ach505}|Fs4],
	Fs6 = [{506, FSCOne, ?FS_FSC_ONE, Ach506}|Fs5],
	Fs7 = [{507, FSSAOne, ?FS_FSSA_ONE, Ach507}|Fs6],
	Fs8 = [{508, FSSATwo, ?FS_FSSA_TWO, Ach508}|Fs7],
	Fs9 = [{509, FSCTwo, ?FS_FSC_TWO, Ach509}|Fs8],
	Fs10 = [{510, erlang:trunc(FSLG/60), erlang:trunc(?FS_FSLG_ONE/60), Ach510}|Fs9],
	Fs11 = [{511, erlang:trunc(FSLG/60), erlang:trunc(?FS_FSLG_TWO/60), Ach511}|Fs10],
	Fs12 = [{512, Ach512, ?ACH_FINISH_RATE, Ach512}|Fs11],
	Fs13 = [{513, Ach513, ?ACH_FINISH_RATE, Ach513}|Fs12],
	Fs14 = [{514, Ach514, ?ACH_FINISH_RATE, Ach514}|Fs13],
	Fs15 = [{515, Ach515, ?ACH_FINISH_RATE, Ach515}|Fs14],
	Fs16 = [{516, Ach516, ?ACH_FINISH_RATE, Ach516}|Fs15],
	Fs17 = [{517, Ach517, ?ACH_FINISH_RATE, Ach517}|Fs16],
	Fs18 = [{518, Ach518, ?ACH_FINISH_RATE, Ach518}|Fs17],
	Fs19 = [{519, Ach519, ?ACH_FINISH_RATE, Ach519}|Fs18],
	Fs20 = [{520, Ach520, ?ACH_FINISH_RATE, Ach520}|Fs19],
	Fs21 = [{521, Ach521, ?ACH_FINISH_RATE, Ach521}|Fs20],
	Fs22 = [{522, Ach522, ?ACH_FINISH_RATE, Ach522}|Fs21],
	Fs23 = [{523, Ach523, ?ACH_FINISH_RATE, Ach523}|Fs22],
	Fs24 = [{524, Ach524, ?ACH_FINISH_RATE, Ach524}|Fs23],
	Fs25 = [{525, Ach525, ?ACH_FINISH_RATE, Ach525}|Fs24],
	Fs26 = [{526, Ach526, ?ACH_FINISH_RATE, Ach526}|Fs25],
	Fs27 = [{527, Ach527, ?ACH_FINISH_RATE, Ach527}|Fs26],
	Fs28 = [{528, Ach528, ?ACH_FINISH_RATE, Ach528}|Fs27],
	Fs29 = [{529, Ach529, ?ACH_FINISH_RATE, Ach529}|Fs28],
	Fs30 = [{530, Ach530, ?ACH_FINISH_RATE, Ach530}|Fs29],
	Fs31 = [{531, Ach531, ?ACH_FINISH_RATE, Ach531}|Fs30],
	Fs32 = [{532, Ach532, ?ACH_FINISH_RATE, Ach532}|Fs31],
	Fs33 = [{533, Ach533, ?ACH_FINISH_RATE, Ach533}|Fs32],
	Fs34 = [{534, Ach534, ?ACH_FINISH_RATE, Ach534}|Fs33],
	Fs35 = [{535, Ach535, ?ACH_FINISH_RATE, Ach535}|Fs34],
	Fs36 = [{536, Ach536, ?ACH_FINISH_RATE, Ach536}|Fs35],
	Fs37 = [{537, Ach537, ?ACH_FINISH_RATE, Ach537}|Fs36],
	Fs38 = [{538, Ach538, ?ACH_FINISH_RATE, Ach538}|Fs37],
	Fs39 = [{539, Ach539, ?ACH_FINISH_RATE, Ach539}|Fs38],
	Fs40 = [{540, Ach540, ?ACH_FINISH_RATE, Ach540}|Fs39],
	Fs41 = [{541, Ach541, ?ACH_FINISH_RATE, Ach541}|Fs40],
	Fs42 = [{542, Ach542, ?ACH_FINISH_RATE, Ach542}|Fs41],
	Fs43 = [{543, Ach543, ?ACH_FINISH_RATE, Ach543}|Fs42],
	Fs44 = [{544, Ach544, ?ACH_FINISH_RATE, Ach544}|Fs43],
	Fs45 = [{545, Ach545, ?ACH_FINISH_RATE, Ach545}|Fs44],
	Fs46 = [{546, Ach546, ?ACH_FINISH_RATE, Ach546}|Fs45],
	Fs47 = [{547, Ach547, ?ACH_FINISH_RATE, Ach547}|Fs46],
	Fs48 = [{548, Ach548, ?ACH_FINISH_RATE, Ach548}|Fs47],
	Fs49 = [{549, Ach549, ?ACH_FINISH_RATE, Ach549}|Fs48],
	Fs50 = [{550, Ach550, ?ACH_FINISH_RATE, Ach550}|Fs49],
	[{551, Ach551, ?ACH_FINISH_RATE, Ach551}|Fs50].

get_achieve_interact(AchInteract,AchStatistics,Player) ->
	[Ach601,Ach602,Ach603,Ach604,Ach605,Ach606,Ach607,Ach608,Ach609,Ach610,
	 Ach611,Ach612,Ach613,Ach614,Ach615,Ach616,Ach617,Ach618,Ach619,Ach620,
	 Ach621,Ach622,Ach623,Ach624,Ach625,Ach626,Ach627,Ach628,Ach629,Ach630,
	 Ach631,Ach632,Ach633] = AchInteract,
	#ets_ach_stats{infl = INFL,                               %% 记录玩家送法的朵数	
				   inlv = INLV,                               %% 完成仙侣情缘次数	
				   inlved = INLVED,                             %% 仙侣情缘中被邀请过次数	
				   infai = INFAI,                              %% 庄园收获次数	
				   infao = INFAO                               %% 庄园偷取次数	
				  } = AchStatistics,
	%%好友判断
	Friend = lib_relationship:get_idA_list(Player#player.id, 1),
	FLen = length(Friend),
	GDonate = lib_guild:get_member_donate(Player#player.guild_id, Player#player.id),
	%%获取魅力值
	PLove = Player#player.other#player_other.charm,
	%%出师徒弟数量
	AppsNum = mod_master_apprentice:get_finish_apprenticeship_count(Player#player.id),
	%%开垦农田数
	FarmNum = lib_manor:get_reclaim_farm_num(Player#player.id),
	%%获取鄙视和崇拜数据
	BS = get_player_bscb_dict(player_bs),
	CB = get_player_bscb_dict(player_cb),
%% 	?DEBUG("BS:~p,CB:~p", [BS,CB]),
	IN1 = [{601, AppsNum, ?INTERACT_APPRENTICE_ONE, Ach601}],
	IN2 = [{602, AppsNum, ?INTERACT_APPRENTICE_TOW, Ach602}|IN1],
	IN3 = [{603, AppsNum, ?INTERACT_APPRENTICE_THREE, Ach603}|IN2],
	IN4 = [{604, Ach604, ?ACH_FINISH_RATE, Ach604}|IN3],
	IN5 = [{605, GDonate, ?INTERACT_GUILD_DONATE, Ach605}|IN4],
	case Ach606 =/= 0 of
		true ->
			IN6 = [{606, ?INTERACT_FRIENDS_ONE, ?INTERACT_FRIENDS_ONE, Ach606}|IN5];
		false ->
			IN6 = [{606, FLen, ?INTERACT_FRIENDS_ONE, Ach606}|IN5]
	end,
	case Ach607 =/= 0 of
		true ->
			IN7 = [{607, ?INTERACT_FRIENDS_TWO, ?INTERACT_FRIENDS_TWO, Ach607}|IN6];
		false ->
			IN7 = [{607, FLen, ?INTERACT_FRIENDS_TWO, Ach607}|IN6]
	end,
	case Ach608 =/= 0 of
		true ->
			IN8 = [{608, ?INTERACT_FRIENDS_THREE, ?INTERACT_FRIENDS_THREE, Ach608}|IN7];
		false ->
			IN8 = [{608, FLen, ?INTERACT_FRIENDS_THREE, Ach608}|IN7]
	end,
	IN9 = [{609, INFL, ?INTERACT_INFL_ONE, Ach609}|IN8],
	IN10 = [{610, INFL, ?INTERACT_INFL_TWO, Ach610}|IN9],
	IN11 = [{611, INFL, ?INTERACT_INFO_THREE, Ach611}|IN10],
	case Ach612 =/= 0 of
		true ->
			IN12 = [{612, ?INTERACT_LOVE_ONE, ?INTERACT_LOVE_ONE, Ach612}|IN11];
		false ->
			IN12 = [{612, PLove, ?INTERACT_LOVE_ONE, Ach612}|IN11]
	end,
	case Ach613 =/= 0 of
		true ->
			IN13 = [{613, ?INTERACT_LOVE_TWO, ?INTERACT_LOVE_TWO, Ach613}|IN12];
		false ->
			IN13 = [{613, PLove, ?INTERACT_LOVE_TWO, Ach613}|IN12]
	end,
	case Ach614 =/= 0 of
		true ->
			IN14 = [{614, ?INTERACT_LOVE_THREE, ?INTERACT_LOVE_THREE, Ach614}|IN13];
		false ->
			IN14 = [{614, PLove, ?INTERACT_LOVE_THREE, Ach614}|IN13]
	end,
	IN15 = [{615, INLV, ?INTERACT_INLV_ONE, Ach615}|IN14],
	IN16 = [{616, INLV, ?INTERACT_INLV_TWO, Ach616}|IN15],
	IN17 = [{617, INLVED, ?INTERACT_INLVED_ONE, Ach617}|IN16],
	IN18 = [{618, INLVED, ?INTERACT_INLVED_TWO, Ach618}|IN17],
	IN19 = [{619, INFAI, ?INTERACT_INFAI_ONE, Ach619}|IN18],
	IN20 = [{620, INFAI, ?INTERACT_INFAI_TWO, Ach620}|IN19],
	IN21 = [{621, INFAO, ?INITERACT_INFAO_ONE, Ach621}|IN20],
	IN22 = [{622, INFAO, ?INTERACT_INFAO_TWO, Ach622}|IN21],
	IN23 = [{623, FarmNum, ?INTERACT_FARM_NUM, Ach623}|IN22],
	IN24 = [{624, Ach624, ?ACH_FINISH_RATE, Ach624}|IN23],
	IN25 = [{625, Ach625, ?ACH_FINISH_RATE, Ach625}|IN24],
	IN26 = [{626, Ach626, ?ACH_FINISH_RATE, Ach626}|IN25],
	IN27 = [{627, Ach627, ?ACH_FINISH_RATE, Ach627}|IN26],
	IN28 = [{628, BS, ?INTERACT_BS_ONE, Ach628}|IN27],
	IN29 = [{629, BS, ?INTERACT_BS_TWO, Ach629}|IN28],
	IN30 = [{630, CB, ?INTERACT_CB_ONE, Ach630}|IN29],
	IN31 = [{631, CB, ?INTERACT_CB_TWO, Ach631}|IN30],
	IN32 = [{632, Ach632, ?ACH_FINISH_RATE, Ach632}|IN31],
	[{633, Ach633, ?ACH_FINISH_RATE, Ach633}|IN32].
	
	
	
%% -----------------------------------------------------------------
%% 38001 获取最近完成成就
%% -----------------------------------------------------------------
get_achieve_log(Logs) ->
	SortLogs = lists:sort(fun(A,B) ->
								  A#ets_log_ach_f.time > B#ets_log_ach_f.time
						  end,Logs),
	Len = length(SortLogs),
	case Len > 50 of
		true ->
			lists:nthtail(Len - 50, SortLogs);
		false ->
			SortLogs
	end.
%% -----------------------------------------------------------------
%% 38002 奇珍异宝 列表
%% -----------------------------------------------------------------
make_ach_treausre_list(_Num, _TypeNum, List, []) ->
	List;
make_ach_treausre_list(Num, TypeNum, List, [Elem|Treasure]) ->
	Result =
		case Elem =:= 1 of
			true ->
				[{TypeNum*100+Num, Elem, 0}|List];
			false when Elem =:= 2->
				[{TypeNum*100+Num, 1, 1}|List];
			false ->
				[{TypeNum*100+Num, Elem, Elem}|List]
		end,
	make_ach_treausre_list(Num+1, TypeNum, Result, Treasure).

%% -----------------------------------------------------------------
%% 38006 八神珠  装备和卸载
%% -----------------------------------------------------------------
%%检查操作的八神珠是否合法
check_pearl(GoodsId, Type, PlayerId, AchPearl) ->			
	GoodsInfo = goods_util:get_goods(GoodsId),
	if
		%%物品不存在
		is_record(GoodsInfo, goods) =:= false ->
			{fail, 3};
		%%物品不属于你
		GoodsInfo#goods.player_id =/= PlayerId ->
			{fail, 4};
		%%物品的位置不正确
		GoodsInfo#goods.location =/= 2 ->
%% 			?DEBUG("omg:~p~~~~", [GoodsId]),
			{fail, 5};
		%%物品的类型有问题了
		GoodsInfo#goods.type =/= 82 ->
			{fail, 6};
		true ->
			Exist = lists:any(fun(G) ->
								 G#p_ach_pearl.gid =:= GoodsId
						 end, AchPearl),
			if
				Exist =:= true andalso Type =:= 0 
				  andalso GoodsInfo#goods.cell =:= GoodsInfo#goods.subtype ->%%能够卸载
					{ok, GoodsInfo};
				Exist =:= false andalso Type =:= 1 
				  andalso GoodsInfo#goods.cell =:= 0 ->%%能够装载
					check_pearl_level(GoodsInfo, AchPearl);
				true ->%%位置出问题了
%% 					?DEBUG("Exist:~p, p_ach_pearl:~p,Gid:~p", [Exist, AchPearl, GoodsId]),
					{fail, 5}
			end
	end.
check_pearl_level(GoodsInfo, AchPearl) ->
	case lists:keyfind(GoodsInfo#goods.subtype, #p_ach_pearl.cell, AchPearl) of
		false ->
			{ok, GoodsInfo};
		Target ->
			case lists:keyfind(Target#p_ach_pearl.goods_id, 1, ?PEARL_LEVEL_LIMIT) of
				false ->
					{fail, 5};
				{_G,Members} ->
					case lists:member(GoodsInfo#goods.goods_id, Members) of
						true ->%%目标的比当前的高级,可以替换
							{ok, GoodsInfo};
						false ->
							{fail, 7}
					end
			end
	end.
update_ach_pearl_info(LoadGid, LoadGooodsInfo, LoadCell, UnloadGid, UnloadGoodInfo) ->
	if
		LoadGid =/= 0 ->
			LValueList = [{cell, LoadCell}],
			LWhereList = [{id, LoadGid}],
			db_agent:update_ach_pearl(goods, LValueList, LWhereList),
			LNewGoodsInfo = LoadGooodsInfo#goods{cell = LoadCell},
			ets:insert(?ETS_GOODS_ONLINE, LNewGoodsInfo);
		true ->
			skip
	end,
	if
		UnloadGid =/= 0 ->
			ULValueList = [{cell, 0}],
			ULWhereList = [{id, UnloadGid}],
			db_agent:update_ach_pearl(goods, ULValueList, ULWhereList),
			ULNewGoodsInfo = UnloadGoodInfo#goods{cell = 0},
			ets:insert(?ETS_GOODS_ONLINE, ULNewGoodsInfo);
		true ->
			skip
	end.
			
load_unload_pearl(GoodsId, Type, GoodsInfo, Status) ->
	#player{other = Other} = Status,
	#player_other{ach_pearl = AchPearl} = Other,
	Cell = GoodsInfo#goods.subtype,
	case Type of
		1 ->%%load+
			case lists:keyfind(Cell, #p_ach_pearl.cell, AchPearl) of
				false ->%%没有装备，所以直接装备新的
					update_ach_pearl_info(GoodsId, GoodsInfo, Cell, 0, {}),
					case pearl_change_status(Type, Status, GoodsInfo) of
						fail ->
							{fail, 0};
						{ok, NewStatus} ->
							{NewStatus, GoodsId, GoodsInfo#goods.goods_id, Cell}
					end;
				PAchPearl ->
					OGid = PAchPearl#p_ach_pearl.gid,
					case ets:lookup(?ETS_GOODS_ONLINE, OGid) of
						[] ->%%以前的数据出问题了
							{fail, 7};
						[OGoodsInfo] ->
							update_ach_pearl_info(GoodsId, GoodsInfo, Cell, OGid, OGoodsInfo),
							case pearl_change_status(Type, Status, GoodsInfo) of
								fail ->
									{fail, 0};
								{ok, NewStatus} ->
									{NewStatus, GoodsId, GoodsInfo#goods.goods_id, Cell}
							end
					end
			end;
		0 ->%%unload-
			update_ach_pearl_info(0,{},0, GoodsId, GoodsInfo),
			case pearl_change_status(Type, Status, GoodsInfo) of
				fail ->
					{fail, 0};
				{ok, NewStatus} ->
					{NewStatus, GoodsId, GoodsInfo#goods.goods_id, Cell}
			end
	end.

pearl_change_status(Type, Status, GoodsInfo) ->
	#goods{id = Gid,
		   goods_id = GoodsTypeId,
		   subtype = Cell} = GoodsInfo,
	AchPearls = Status#player.other#player_other.ach_pearl,
	GoodsTypeInfo = goods_util:get_goods_type(GoodsTypeId),
	case is_record(GoodsTypeInfo, ets_base_goods) of
		true ->
			case Type of
				1 ->%%load
					OtherData = GoodsTypeInfo#ets_base_goods.other_data, 
					[_AchType, AddType, Effect] = util:string_to_term(tool:to_list(OtherData)),
					PAchPearl = #p_ach_pearl{gid = Gid,
											 goods_id = GoodsTypeId,
											 cell = Cell,
											 add_type = AddType,
											 effect = Effect},
					case lists:keyfind(Cell, #p_ach_pearl.cell, AchPearls) of
						false ->
							NewAchPearls = [PAchPearl|AchPearls];
%% 							?DEBUG("1111:~p", [NewAchPearls]);
						_ ->
							NewAchPearls = lists:keyreplace(Cell, #p_ach_pearl.cell, AchPearls, PAchPearl)
%% 							?DEBUG("2222:~p", [NewAchPearls])
					end,
					UpdateStatus = Status#player{other = Status#player.other#player_other{ach_pearl = NewAchPearls}},
					NewStatus = lib_player:count_player_attribute(UpdateStatus),
					{ok, NewStatus};
				0 ->%%unload
					NewAchPearls = lists:keydelete(Cell, #p_ach_pearl.cell, AchPearls),
%% 					?DEBUG("3333:~p", [NewAchPearls]),
					UpdateStatus = Status#player{other = Status#player.other#player_other{ach_pearl = NewAchPearls}},
					NewStatus = lib_player:count_player_attribute(UpdateStatus),
					{ok, NewStatus}
			end;
		false ->
			fail
	end.


%%成就系统的物品装备判断,1:法宝判断，2:时装判断，3:套装判断
check_equip_ach(GoodsInfo, PlayerStatus, Type) ->
	#goods{goods_id = GoodsTypeId,
		   spirit = Spirit,%%灵力
		   step = Step,%%阶数
		   stren = Stren, %%强化等级
		   hole1_goods = HGTId1, %%孔1所镶物品ID
		   hole2_goods = HGTId2, %%孔2所镶物品ID
		   hole3_goods = HGTId3, %%孔3所镶物品ID
		   color = Color %%颜色
		  } = GoodsInfo,
%% 	IsSBLQ = lists:member(GoodsTypeId, [11005, 12005, 13005, 14005, 15005]),%%装备神兵利器的法宝
%% 	?DEBUG("Type:~p, Spirit:~p, Step:~p, Stren:~p, Color:~p, HGTId1:~p, HGTId2:~p, HGTId3:~p", [Type, Spirit, Step, Stren, Color, HGTId1, HGTId2, HGTId3]),
	Result =
		case Type of
			1 ->%%法宝
				Epic224 = [{224,1}],
				case Step =:= 5 andalso Spirit =:= 1 of
					true -> %%神装的判断
						Epic224;
					false  ->
%% 						Epic202 =
%% 							if	%%装备神兵利器的法宝
%% 								IsSBLQ =:= true ->
%% 									[{202,1}|Epic224];
%% 								true ->
%% 									Epic224
%% 							end,
						Epic203 = 
							if
								Step =:= 4 andalso Color =:= 4 ->
									[{203, 4}|Epic224];
								true ->
									Epic224
							end,
						Epic204 = 
							if
								Step =:= 5 andalso Color =:= 4 ->
									[{204, 5}|Epic203];
								true ->
									Epic203
							end,
						Epic205 =
							if
								Step =:= 6 andalso Color =:= 4 ->
									[{205, 6}|Epic204];
								true ->
									Epic204
							end,
						Epic206 =
							if
								Step =:= 7 andalso Color =:= 4 ->
									[{206, 7}|Epic205];
								true ->
									Epic205
							end,
						Epic225 = 
							if
								Step =:= 8 andalso Color =:= 4 ->
									[{225, 8}|Epic206];
								true ->
									Epic206
							end,
						Epic207 =
							if
								Stren =:= 7 andalso (Color =:= 3 orelse Color =:= 4) ->
									[{207, 7}|Epic225];
								true ->
									Epic225
							end,
						Epic208 =
							if
								Stren =:= 8 andalso (Color =:= 3 orelse Color =:= 4) ->
									[{208, 8}|Epic207];
								true ->
									Epic207
							end,
						Epic209 =
							if
								Stren =:= 9 andalso (Color =:= 3 orelse Color =:= 4) ->
									[{209, 9}|Epic208];
								true ->
									Epic208
							end,
						if
							Stren =:= 10 andalso (Color =:= 3 orelse Color =:= 4) ->
								[{210, 10}|Epic209];
							true ->
								Epic209
						end
				end;
			2 ->%%时装[10901, 10903, 10905, 10907, 10902, 10904, 10906, 10908,...10940]
				Fashion = lists:member(GoodsTypeId, [10901, 10903, 10905, 10907, 10902, 10904, 10906, 10908, 10909, 10910, 
													 10911, 10912, 10913, 10914, 10915, 10916, 10917, 10918, 10919, 10920,
													 10921, 10922, 10923, 10924, 10925, 10926, 10927, 10928, 10929, 10930,
													 10931, 10932, 10933, 10934, 10935, 10936, 10937, 10938, 10939, 10940]),
				case Fashion of
					true ->
						[{201, 1}];
					false ->
						[]
				end;
			3 ->%%其他的判断
				#player{id = PlayerId,
						career = Career,
						other = Other} = PlayerStatus,
				#player_other{suitid = SuitId} = Other,
				{Box30, Box40, Box50, Box60, FST40, FST50, Gold30, Box70, FST60} = get_ach_suit_id(Career),
				{SuitCheck, Find} = if
								Career =:= 100 orelse SuitId =:= 0 ->
									{[], false};
								SuitId =:= Box30 ->
									{[{211, 30}], true};
								SuitId =:= Box40 ->
									{[{212, 40}], true};
								SuitId =:= Box50 ->
									{[{213, 50}], true};
								SuitId =:= Box60 ->
									{[{214, 60}], true};
								SuitId =:= FST40 ->
									{[{215, 40}], true};
								SuitId =:= FST50 ->
									{[{216, 50}], true};
								SuitId =:= Gold30 ->%%30级金装
									{[], true};
								SuitId =:= Box70 ->
									{[{226, 70}],true};%%诛邪70套
								SuitId =:= FST60 ->
									{[{227, 60}],true};%%封神60套
								true ->
									{[], false}
							end,
				case Find of
					false ->
						SuitCheck;
					true ->
						case get_stren_suit(PlayerId, SuitId) of
							 7 ->%%加7
								[{217, 7}|SuitCheck];
							 8 ->%%加8
								 [{218, 8}|SuitCheck];
							 9 ->%%加9
								 [{219, 9}|SuitCheck];
							 10 ->%%加10
								[{220, 10}|SuitCheck];
							 _ ->
								 SuitCheck
						 end
				end
		end,
	case Step =:= 5 andalso Spirit =:= 1 of
		true ->%%神兵利器 直接跳过宝石的鉴定
			Result;
		false ->
			%%三级宝石[21362, 21352, 21342, 21332, 21322, 21312, 21302]
			R31 = lists:member(HGTId1, [21362, 21352, 21342, 21332, 21322, 21312, 21302]),
			R32 = lists:member(HGTId2, [21362, 21352, 21342, 21332, 21322, 21312, 21302]),
			R33 = lists:member(HGTId3, [21362, 21352, 21342, 21332, 21322, 21312, 21302]),
			RAch3 = 
				if
					R31 =:= true ->
						[{221, 3}|Result];
					R32 =:= true ->
						[{221, 3}|Result];
					R33 =:= true ->
						[{221, 3}|Result];
					true ->
						Result
				end,
			%%五级宝石[21364, 21354, 21344, 21334, 21324, 21314, 21304]
			R51 = lists:member(HGTId1, [21364, 21354, 21344, 21334, 21324, 21314, 21304]),
			R52 = lists:member(HGTId2, [21364, 21354, 21344, 21334, 21324, 21314, 21304]),
			R53 = lists:member(HGTId3, [21364, 21354, 21344, 21334, 21324, 21314, 21304]),
			RAch5 =
				if
					R51 =:= true ->
						[{222, 5}|RAch3];
					R52 =:= true ->
						[{222, 5}|RAch3];
					R53 =:= true ->
						[{222, 5}|RAch3];
					true ->
						RAch3
				end,
			%%七级宝石[21366, 21356, 21346, 21336, 21326, 21316, 21306]
			R71 = lists:member(HGTId1, [21366, 21356, 21346, 21336, 21326, 21316, 21306]),
			R72 = lists:member(HGTId2, [21366, 21356, 21346, 21336, 21326, 21316, 21306]),
			R73 = lists:member(HGTId3, [21366, 21356, 21346, 21336, 21326, 21316, 21306]),
			if
				R71 =:= true ->
					[{223, 7}|RAch5];
				R72 =:= true ->
					[{223, 7}|RAch5];
				R73 =:= true ->
					[{223, 7}|RAch5];
				true ->
					RAch5
			end
	end.
					
			
			
			
			
%%
%% Local Functions
%%
put_ach_log_num(Final) ->
	put(ach_log_num, Final).
get_ach_log_num() ->
	case get(ach_log_num) of
		undefined ->
			50;
		Num ->
			Num
	end.
	
%%领取成就奖励物品
ach_give_goods(Type, GoodsTypeId, GoodsNum, PlayerStatus) ->
	case Type of
		0 ->
			catch (gen_server:call(PlayerStatus#player.other#player_other.pid_goods, 
								  {'give_goods', PlayerStatus, GoodsTypeId, GoodsNum, 2}));
		1 ->
			catch (gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
								   {'GIVE_ACH_TREASURE', GoodsTypeId, GoodsNum}))
	end.
%%领取八神珠
give_goods(GoodsTypeId, GoodsNum, PlayerId) ->
	GoodsTypeInfo0 = goods_util:get_goods_type(GoodsTypeId),
	case is_record(GoodsTypeInfo0, ets_base_goods) of
		false ->%物品不存在，出错了
			{fail, {GoodsTypeId, not_found}};
		true ->
			GoodsTypeInfo = GoodsTypeInfo0#ets_base_goods{sell = 1,%%不可出售
														  isdrop = 1,%%不可丢弃
														  trade = 1},%%不可交易
			GoodsList = goods_util:get_type_goods_list(PlayerId, GoodsTypeInfo#ets_base_goods.goods_id, 2),
			case length(GoodsList) of
				0 ->
					GoodsInfo = goods_util:get_new_goods(GoodsTypeInfo),
					
					AddGoodsInfo = GoodsInfo#goods{player_id = PlayerId,
												   location = 2,%%成就背包
												   num = GoodsNum,
												   cell = 0},
					lib_goods:add_goods(AddGoodsInfo),
					ok;
				_ ->
					{fail, {GoodsTypeId, goods_exist}}
			end
	end.
				

%% {Box30, Box40, Box50, Box60, FST40, FST50, Gold30, Box70, FST60}
get_ach_suit_id(Career) ->
	case Career of
		3 -> {7, 8, 9, 28, 20, 21, 43, 48, 33}; 	%%青龙
		2 -> {4, 5, 6, 27, 18, 19, 42, 47, 32};		%%白虎
		4 -> {10, 11, 12, 29, 22, 23, 44, 49, 34};	%%朱雀
		1 -> {1, 2, 3, 26, 16, 17, 41, 46, 31};		%%玄武
		5 -> {13, 14, 15, 30, 24, 25, 45, 50, 35};	%%麒麟
		_ -> {0, 0, 0, 0, 0, 0, 0, 0, 0}
	end.
	
get_stren_suit(PlayerId, SuitId) ->
	Ms = ets:fun2ms(fun(T) when T#goods.suit_id =:= SuitId andalso T#goods.player_id =:= PlayerId
						 andalso T#goods.location =:= 1 ->
							T
					end),
	Pattern = ets:select(?ETS_GOODS_ONLINE, Ms),
	Len = length(Pattern),
	case Len =:= 6 of
		true ->
			[Equip1,Equip2,Equip3,Equip4,Equip5,Equip6] = Pattern,
			if
				Equip1#goods.stren >= 10 andalso Equip2#goods.stren >= 10 andalso Equip3#goods.stren >= 10
				  andalso Equip4#goods.stren >= 10andalso Equip5#goods.stren >= 10andalso Equip6#goods.stren >= 10 ->
					10;
				Equip1#goods.stren >= 9 andalso Equip2#goods.stren >= 9 andalso Equip3#goods.stren >= 9
				  andalso Equip4#goods.stren >= 9 andalso Equip5#goods.stren >= 9 andalso Equip6#goods.stren >= 9 ->
					9;
				Equip1#goods.stren >= 8 andalso Equip2#goods.stren >= 8 andalso Equip3#goods.stren >= 8
				  andalso Equip4#goods.stren >= 8 andalso Equip5#goods.stren >= 8 andalso Equip6#goods.stren >= 8 ->
					8;
				Equip1#goods.stren >= 7 andalso Equip2#goods.stren >= 7 andalso Equip3#goods.stren >= 7
				  andalso Equip4#goods.stren >= 7 andalso Equip5#goods.stren >= 7 andalso Equip6#goods.stren >= 7 ->
					7;
				true ->
					0
			end;
		false ->
			0
	end.
	
%%检测是否已经加载过 成就系统的数据
check_achieve_init(PlayerId) ->
	case get_achinit_dic() of
		true ->
			ok;
		false ->
			[NPTitlesStr] = db_agent:get_player_titles_delay(PlayerId),
			DBPTitles = 
				case util:string_to_term(tool:to_list(NPTitlesStr)) of
					List when is_list(List) ->
						List;
					_Other ->
						[]
				end,
%% 			NPTitles = get_achtitles_dic(),
%% 			A = (DBPTitles =:= NPTitles),
%% 			?DEBUG("DBPTitles:~p, NPTitles:~p, A:~p", [DBPTitles,NPTitles, A]),
			AchIeveUpdate = lib_achieve:init_achieve(PlayerId, DBPTitles),
			erlang:send_after(5000, self(), {'CHECK_ACH_OLD_DATA', AchIeveUpdate}),
			put_achinit_dic(1)
	end.

%%获取当前加载成就系统的信息判断
get_achinit_dic() ->
	case get(achinit) of
		undefined ->
			false;
		1 ->
			true;
		_ ->
			false
	end.
%%更新成就系统加载情况的标志位
put_achinit_dic(Num) ->
	put(achinit, Num).
%%获取成就系统 的称号集
%% get_achtitles_dic() ->
%% 	case get(achtitles) of
%% 		undefined ->
%% 			[];
%% 		List ->
%% 			List
%% 	end.
%%添加成就系统的称号集数据
%% put_achtitles_dic(Titles) ->
%% 	put(achtitles, Titles).
	
%%获取玩家的被鄙视和崇拜数据
get_player_bscb(PlayerId) ->
	try 
		gen_server:call(mod_appraise:get_mod_appraise_pid(), 
						{apply_call, lib_appraise, achieve_get_adore, [PlayerId]})
	catch
		_:_ -> io:format("got fail"), []
	end.
	
get_player_bscb_dict(Type) ->
	case get(Type) of
		undefined ->
			0;
		Num when is_integer(Num) ->
			Num;
		_ ->
			0
	end.