%% Author: zhangchao
%% Created: 2011-10-13
%% Description: TODO: Add description to data_passive_skill
%%被动技能静态数据表，手工制作
-module(data_passive_skill).

%%
%% Include files
%%
%%
%% Exported Functions
%%
-export([get/2,
		 get_skill_id_list/0,
		 get_book_skill_list/0]).
-include("record.hrl").

%%
%% API Functions
%%

%% 技能数据	
%% base_skill ==> ets_skill 	
%% -record(ets_skill, {	
%%       id,                                     %% 编号	
%%       name = "",                              %% 技能名称	
%%       desc = "",                              %% 技能描述	
%%       career = 0,                             %% 1:战士（玄武），2:刺客（白虎），3:弓手（青龙），4:牧师（朱雀），5:武尊(麒麟)	
%%       mod = 0,                                %% 模式:单体1/全体2	
%%       type = 0,                               %% 主动1/铺助2	
%%       obj = 0,                                %% 释放目标,1,danti	
%%       area = 0,                               %% 攻击范围，格子数	
%%       area_obj = 0,                           %% 攻击范围目标，0以被击方的坐标为中心，1攻击方	
%%       level_effect = "",                      %% 升级效果	
%%       assist_type = 0,                        %% 1特殊（加血、回血、吸收伤害等）、0普通（加命中、躲闪等状态BUFF），不是辅助的技能为0	
%%       limit_action = 0,                       %% 动作限制	
%%       hate = <<"0">>,                         %% 技能仇恨	
%%       data                                    %% 效果	
%%     }).	

get_skill_id_list() ->
	[25500,25501,25502,25503,25504,25505,25506,25507,25508,25509,25510,25511,25512,25513,25514,25515].

get_book_skill_list() ->
	[25512,25513,25514,25515].

get(25500, SkillLv) ->
	{LvLimit, Coin, Culture} = passive_public_data(SkillLv),
	#ets_skill{
		id = 25500,
		name = <<"轩辕剑气">>,
		career = 0,
		mod = 1,
		type = 3,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data =
			case Coin =:= 0 of
				true ->
					[];
				false ->
					[{condition, [{lv,LvLimit},{coin,Coin},{culture,Culture}]},
					 {effect, [{atk,4*SkillLv}]}]
			end
	};

get(25501, SkillLv) ->
	{LvLimit, Coin, Culture} = passive_public_data(SkillLv),
	#ets_skill{
		id = 25501,
		name = <<"霸邪之盾">>,
		career = 0,
		mod = 1,
		type = 3,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data =
			case Coin =:= 0 of
				true ->
					[];
				false ->
					[{condition, [{lv,LvLimit},{coin,Coin},{culture,Culture}]},
					 {effect, [{def,6*SkillLv}]}]
			end
	};

get(25502, SkillLv) ->
	{LvLimit, Coin, Culture} = passive_public_data(SkillLv),
	#ets_skill{
		id = 25502,
		name = <<"远古体质">>,
		career = 0,
		mod = 1,
		type = 3,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data =
			case Coin =:= 0 of
				true ->
					[];
				false ->
					[{condition, [{lv,LvLimit},{coin,Coin},{culture,Culture}]},
					 {effect, [{hp_lim,30*SkillLv}]}]
			end
	};

get(25503, SkillLv) ->
	{LvLimit, Coin, Culture} = passive_public_data(SkillLv),
	#ets_skill{
		id = 25503,
		name = <<"精神之泉">>,
		career = 0,
		mod = 1,
		type = 3,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data =
			case Coin =:= 0 of
				true ->
					[];
				false ->
					[{condition, [{lv,LvLimit},{coin,Coin},{culture,Culture}]},
					 {effect, [{mp_lim,3*SkillLv}]}]
			end
	};

get(25504, SkillLv) ->
	{LvLimit, Coin, Culture} = passive_public_data(SkillLv),
	#ets_skill{
		id = 25504,
		name = <<"迷惑之舞">>,
		career = 0,
		mod = 1,
		type = 3,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data =
			case Coin =:= 0 of
				true ->
					[];
				false ->
					[{condition, [{lv,LvLimit},{coin,Coin},{culture,Culture}]},
					 {effect, [{dodge,1*SkillLv}]}]
			end
	};

get(25505, SkillLv) ->
	{LvLimit, Coin, Culture} = passive_public_data(SkillLv),
	#ets_skill{
		id = 25505,
		name = <<"真实之瞳">>,
		career = 0,
		mod = 1,
		type = 3,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data =
			case Coin =:= 0 of
				true ->
					[];
				false ->
					[{condition, [{lv,LvLimit},{coin,Coin},{culture,Culture}]},
					 {effect, [{hit,1*SkillLv}]}]
			end
	};

get(25506, SkillLv) ->
	{LvLimit, Coin, Culture} = passive_public_data(SkillLv),
	#ets_skill{
		id = 25506,
		name = <<"痛击之势">>,
		career = 0,
		mod = 1,
		type = 3,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data =
			case Coin =:= 0 of
				true ->
					[];
				false ->
					[{condition, [{lv,LvLimit},{coin,Coin},{culture,Culture}]},
					 {effect, [{crit,1*SkillLv}]}]
			end
	};

get(25507, SkillLv) ->
	{LvLimit, Coin, Culture} = passive_public_data(SkillLv),
	#ets_skill{
		id = 25507,
		name = <<"玄武守护">>,
		career = 0,
		mod = 1,
		type = 3,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data =
			case Coin =:= 0 of
				true ->
					[];
				false ->
					[{condition, [{lv,LvLimit},{coin,Coin},{culture,Culture}]},
					 {effect, [{anti_wind,3*SkillLv}]}]
			end
	};

get(25508, SkillLv) ->
	{LvLimit, Coin, Culture} = passive_public_data(SkillLv),
	#ets_skill{
		id = 25508,
		name = <<"青龙守护">>,
		career = 0,
		mod = 1,
		type = 3,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data =
			case Coin =:= 0 of
				true ->
					[];
				false ->
					[{condition, [{lv,LvLimit},{coin,Coin},{culture,Culture}]},
					 {effect, [{anti_thunder,3*SkillLv}]}]
			end
	};

get(25509, SkillLv) ->
	{LvLimit, Coin, Culture} = passive_public_data(SkillLv),
	#ets_skill{
		id = 25509,
		name = <<"白虎守护">>,
		career = 0,
		mod = 1,
		type = 3,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data =
			case Coin =:= 0 of
				true ->
					[];
				false ->
					[{condition, [{lv,LvLimit},{coin,Coin},{culture,Culture}]},
					 {effect, [{anti_water,3*SkillLv}]}]
			end
	};

get(25510, SkillLv) ->
	{LvLimit, Coin, Culture} = passive_public_data(SkillLv),
	#ets_skill{
		id = 25510,
		name = <<"朱雀守护">>,
		career = 0,
		mod = 1,
		type = 3,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data =
			case Coin =:= 0 of
				true ->
					[];
				false ->
					[{condition, [{lv,LvLimit},{coin,Coin},{culture,Culture}]},
					 {effect, [{anti_fire,3*SkillLv}]}]
			end
	};

get(25511, SkillLv) ->
	{LvLimit, Coin, Culture} = passive_public_data(SkillLv),
	#ets_skill{
		id = 25511,
		name = <<"麒麟守护">>,
		career = 0,
		mod = 1,
		type = 3,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data =
			case Coin =:= 0 of
				true ->
					[];
				false ->
					[{condition, [{lv,LvLimit},{coin,Coin},{culture,Culture}]},
					 {effect, [{anti_soil,3*SkillLv}]}]
			end
	};

get(25512, SkillLv) ->
	{LvLimit, Coin, Culture} = passive_public_data(SkillLv),
	#ets_skill{
		id = 25512,
		name = <<"血气屏障">>,
		career = 0,
		mod = 1,
		type = 3,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data =
			case Coin =:= 0 of
				true ->
					[];
				false ->
					[{condition, [{lv,LvLimit},{coin,Coin},{culture,Culture}]},
					 {effect, [{lower_hp,0.0025*SkillLv}]}]
			end
	};

get(25513, SkillLv) ->
	{LvLimit, Coin, Culture} = passive_public_data(SkillLv),
	#ets_skill{
		id = 25513,
		name = <<"法力屏障">>,
		career = 0,
		mod = 1,
		type = 3,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data =
			case Coin =:= 0 of
				true ->
					[];
				false ->
					[{condition, [{lv,LvLimit},{coin,Coin},{culture,Culture}]},
					 {effect, [{lower_mp,0.0025*SkillLv}]}]
			end
	};

get(25514, SkillLv) ->
	{LvLimit, Coin, Culture} = passive_public_data(SkillLv),
	#ets_skill{
		id = 25514,
		name = <<"抗性护盾">>,
		career = 0,
		mod = 1,
		type = 3,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data =
			case Coin =:= 0 of
				true ->
					[];
				false ->
					[{condition, [{lv,LvLimit},{coin,Coin},{culture,Culture}]},
					 {effect, [{lower_anti,0.0025*SkillLv}]}]
			end
	};

get(25515, SkillLv) ->
	{LvLimit, Coin, Culture} = passive_public_data(SkillLv),
	#ets_skill{
		id = 25515,
		name = <<"风神祝福">>,
		career = 0,
		mod = 1,
		type = 3,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data =
			case Coin =:= 0 of
				true ->
					[];
				false ->
					[{condition, [{lv,LvLimit},{coin,Coin},{culture,Culture}]},
					 {effect, [{lower_speed,0.0025*SkillLv}]}]
			end
	};

get(_SkillId, _SkillLv) ->
	[].

%%
%% Local Functions
%%






passive_public_data(SkillLevel) ->
	{Coin, Culture} = 
		case SkillLevel of
			1 ->    {35,80 };
			2 ->    {39,89 };
			3 ->    {43,99 };
			4 ->    {48,110 };
			5 ->	{53,122};
			6 ->	{59,135};
			7 ->	{65,150};
			8 ->	{72,167};
			9 ->    {80,186};
			10->	{89,207};
			11->	{99,275};
			12->	{110,305};
			13->	{122,339};
			14->	{135,377};
			15->	{150,419};
			16->	{167,466};
			17->	{185,518};
			18->	{206	,575 };
			19->	{229	,639 };
			20->	{254	,710 };
			21->	{282	,789 };
			22->	{313	,877 };
			23->	{348	,974 };
			24->	{387	,1082 };
			25->	{430	,1202 };
			26->	{478	,1335};
			27->	{531	,1483};
			28->	{590	,1648};
			29->	{656	,1831};
			30->	{729	,2034};
			31->	{810	,2260};
			32->	{900	,2759};
			33->	{1000,4984   };
			34->	{1200,5713   };
			35->	{1480,4147   };
			36->	{1760,4761   };
			37->	{2040,5978   };
			38->	{2320,7528   };
			39->	{2600,9552   };
			40->	{3000,6612   };
			41->	{3400,8748   };
			42->	{3800,10185   };
			43->	{4200,11679   };
			44->	{4600,14668  };
			45->	{5080,18942  };
			46->	{5560,22331  };
			47->	{6040,24097  };
			48->	{6520,28246  };
			49->	{7000,30065  };
			50->	{7600,42110  };
			51->	{8200,49299  };
			52->	{8800,60713  };
			53->	{9400,68440  };
			54->	{10000,84171 };
			55->	{10720,101855 };
			56->	{11440,114429 };
			57->	{12160,134761};
			58->	{12880,156628};
			59->	{13600,174793};
			60->	{14320,259526};
			61->	{15120,240388};
			62->	{15920,194540};
			63->	{16720,211437};
			64->	{17520,227083};
			65->	{18520,214702};
			66->	{19520,219720};
			67->	{20520,233998};
			68->	{21520,248384};
			69->	{22520,265683};
			70->	{23600,296420};
			71->	{24680,337755};
			72->	{25760,359546};
			73->	{26840,399008};
			74->	{27920,424084};
			75->	{29120,468933};
			76->	{30320,497125};
			77->	{31520,527564};
			78->	{32720,551582};
			79->	{33920,578719};
			80->	{35320,569562};
			81->	{36720,597864};
			82->	{38120,627856};
			83->	{39520,661870};
			84->	{40920,696776};
			85->	{42120,813701};
			86->	{43320,849993};
			87->	{44520,889093};
			88->	{45720,929275};
			89->	{46920,965589};
			90->	{48520,978967};
			91->	{50120,1022409};
			92->	{51720,1064188};
			93->	{53320,1114147};
			94->	{54920,1182272};
			95->	{56920,1367208};
			96->	{58920,1416136};
			97->	{60920,1483729};
			98->	{62920,1540279};
			99->	{64920,1578266};
			100->	{65920,1200000};
			_->  {0,0}
		end,
	{SkillLevel, Coin, Culture}.
		
			
			
	
	
	
	
	
	
	
	
	
	
	
	
	
