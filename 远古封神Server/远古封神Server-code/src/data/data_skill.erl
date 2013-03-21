%%%---------------------------------------
%%% @Module  : data_skill
%%% @Author  : ygfs
%%% @Created : 2012-04-26 23:18:31
%%% @Description:  自动生成
%%%---------------------------------------

-module(data_skill).
-export(
	[
		get/2,
		get_skill_id_list/1
	]
).
-include("record.hrl").

get_skill_id_list(1) ->
	[25000,25001,25002,25003,25004,25005,25006,25007,25008,25009,25010,25011];
get_skill_id_list(2) ->
	[25100,25101,25102,25103,25104,25105,25106,25107,25108,25109,25110,25111];
get_skill_id_list(3) ->
	[25200,25201,25202,25203,25204,25205,25206,25207,25208,25209,25210,25211];
get_skill_id_list(4) ->
	[25300,25301,25302,25303,25304,25305,25306,25307,25308,25309,25310,25311];
get_skill_id_list(5) ->
	[25400,25401,25402,25403,25404,25405,25406,25407,25408,25409,25410,25411];
get_skill_id_list(_Career) ->
	[].

get(10000, SkillLv) ->
	#ets_skill{
		id = 10000,
		name = <<"惊雷">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,7},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 1.5}];
				_ ->
					[]
			end
	};

get(10001, SkillLv) ->
	#ets_skill{
		id = 10001,
		name = <<"重锤">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,5},{att_area,2}]}, {shortime, [{hurt_add,50}]}, {lastime, []}, {base_att, 1.3}];
				_ ->
					[]
			end
	};

get(10002, SkillLv) ->
	#ets_skill{
		id = 10002,
		name = <<"雷鸣">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,40},{att_area,0}]}, {shortime, []}, {lastime, [{8,last_crit,0.05}]}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(10003, SkillLv) ->
	#ets_skill{
		id = 10003,
		name = <<"雷暴">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 3,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(10004, SkillLv) ->
	#ets_skill{
		id = 10004,
		name = <<"电闪">>,
		career = 6,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,12},{att_area,0}]}, {shortime, []}, {lastime, [{0,hp,1000}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10005, SkillLv) ->
	#ets_skill{
		id = 10005,
		name = <<"天火">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 1.5}];
				_ ->
					[]
			end
	};

get(10006, SkillLv) ->
	#ets_skill{
		id = 10006,
		name = <<"破炎">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,30},{att_area,2}]}, {shortime, []}, {lastime, [{5,last_crit,0.05}]}, {base_att, 0.8}];
				_ ->
					[]
			end
	};

get(10007, SkillLv) ->
	#ets_skill{
		id = 10007,
		name = <<"焰雨">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 4,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,12},{att_area,2}]}, {shortime, []}, {lastime, [{3,drug,120}]}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(10008, SkillLv) ->
	#ets_skill{
		id = 10008,
		name = <<"炙烤">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 4,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,40},{att_area,2}]}, {shortime, []}, {lastime, [{4,att_der,-0.5}]}, {base_att, 0.4}];
				_ ->
					[]
			end
	};

get(10009, SkillLv) ->
	#ets_skill{
		id = 10009,
		name = <<"血焰">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,30},{att_area,0}]}, {shortime, []}, {lastime, [{5,att,0.08}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10010, SkillLv) ->
	#ets_skill{
		id = 10010,
		name = <<"火花">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 2,
		area_obj = 0,
		assist_type = 0,
		limit_action = 2,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,40},{att_area,2}]}, {shortime, []}, {lastime, [{4,dizzy,0}]}, {base_att, 0.4}];
				_ ->
					[]
			end
	};

get(10011, SkillLv) ->
	#ets_skill{
		id = 10011,
		name = <<"暖阳">>,
		career = 6,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 1,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,18},{att_area,0}]}, {shortime, []}, {lastime, [{0,hp,1500}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10012, SkillLv) ->
	#ets_skill{
		id = 10012,
		name = <<"沅水">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,5},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 1.1}];
				_ ->
					[]
			end
	};

get(10013, SkillLv) ->
	#ets_skill{
		id = 10013,
		name = <<"浣纱">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,7},{att_area,2}]}, {shortime, []}, {lastime, [{5,drug,60}]}, {base_att, 1.15}];
				_ ->
					[]
			end
	};

get(10014, SkillLv) ->
	#ets_skill{
		id = 10014,
		name = <<"落冰">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 2,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,45},{att_area,2}]}, {shortime, []}, {lastime, [{5,dizzy,0}]}, {base_att, 0.4}];
				_ ->
					[]
			end
	};

get(10015, SkillLv) ->
	#ets_skill{
		id = 10015,
		name = <<"水蛇">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 3,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,15},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(10016, SkillLv) ->
	#ets_skill{
		id = 10016,
		name = <<"霜降">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 3,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,20},{att_area,0}]}, {shortime, []}, {lastime, [{8,att_der,-0.05}]}, {base_att, 1.2}];
				_ ->
					[]
			end
	};

get(10017, SkillLv) ->
	#ets_skill{
		id = 10017,
		name = <<"冰壁">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,60},{att_area,0}]}, {shortime, []}, {lastime, [{10,def,0.2}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10018, SkillLv) ->
	#ets_skill{
		id = 10018,
		name = <<"坠石">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,3},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 1.5}];
				_ ->
					[]
			end
	};

get(10019, SkillLv) ->
	#ets_skill{
		id = 10019,
		name = <<"土盾">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,20},{att_area,0}]}, {shortime, []}, {lastime, [{6,def,0.1}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10020, SkillLv) ->
	#ets_skill{
		id = 10020,
		name = <<"飞沙">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 4,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,12},{att_area,2}]}, {shortime, []}, {lastime, [{3,drug,100}]}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(10021, SkillLv) ->
	#ets_skill{
		id = 10021,
		name = <<"封尘">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 4,
		area_obj = 0,
		assist_type = 0,
		limit_action = 3,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,40},{att_area,2}]}, {shortime, []}, {lastime, [{6,silence,0}]}, {base_att, 0.5}];
				_ ->
					[]
			end
	};

get(10022, SkillLv) ->
	#ets_skill{
		id = 10022,
		name = <<"迷沙">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 4,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,24},{att_area,2}]}, {shortime, []}, {lastime, [{4,att_der,-0.08}]}, {base_att, 1.2}];
				_ ->
					[]
			end
	};

get(10023, SkillLv) ->
	#ets_skill{
		id = 10023,
		name = <<"走尘">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 4,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,50},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 1.5}];
				_ ->
					[]
			end
	};

get(10024, SkillLv) ->
	#ets_skill{
		id = 10024,
		name = <<"沅水2">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,4},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 1.5}];
				_ ->
					[]
			end
	};

get(10025, SkillLv) ->
	#ets_skill{
		id = 10025,
		name = <<"浣纱2">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,7},{att_area,2}]}, {shortime, []}, {lastime, [{5,drug,120}]}, {base_att, 1.3}];
				_ ->
					[]
			end
	};

get(10026, SkillLv) ->
	#ets_skill{
		id = 10026,
		name = <<"落冰2">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 2,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,30},{att_area,2}]}, {shortime, []}, {lastime, [{5,dizzy,0}]}, {base_att, 0.4}];
				_ ->
					[]
			end
	};

get(10027, SkillLv) ->
	#ets_skill{
		id = 10027,
		name = <<"落雾">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,32},{att_area,2}]}, {shortime, []}, {lastime, [{3,hit,-0.1}]}, {base_att, 0.2}];
				_ ->
					[]
			end
	};

get(10028, SkillLv) ->
	#ets_skill{
		id = 10028,
		name = <<"水蛇2">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 4,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,12},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 1.2}];
				_ ->
					[]
			end
	};

get(10029, SkillLv) ->
	#ets_skill{
		id = 10029,
		name = <<"霜降2">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 4,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,18},{att_area,2}]}, {shortime, []}, {lastime, [{5,att_der,-0.8}]}, {base_att, 1.2}];
				_ ->
					[]
			end
	};

get(10030, SkillLv) ->
	#ets_skill{
		id = 10030,
		name = <<"冰壁2">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,30},{att_area,0}]}, {shortime, []}, {lastime, [{5,def,0.1}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10031, SkillLv) ->
	#ets_skill{
		id = 10031,
		name = <<"风刃">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,4},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 1.2}];
				_ ->
					[]
			end
	};

get(10032, SkillLv) ->
	#ets_skill{
		id = 10032,
		name = <<"台风">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 2,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,3},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 1.2}];
				_ ->
					[]
			end
	};

get(10033, SkillLv) ->
	#ets_skill{
		id = 10033,
		name = <<"飓风">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 6,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,16},{att_area,5}]}, {shortime, []}, {lastime, []}, {base_att, 1.5}];
				_ ->
					[]
			end
	};

get(10034, SkillLv) ->
	#ets_skill{
		id = 10034,
		name = <<"旋风">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 2,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,35},{att_area,2}]}, {shortime, []}, {lastime, [{5,dizzy,0}]}, {base_att, 0.5}];
				_ ->
					[]
			end
	};

get(10035, SkillLv) ->
	#ets_skill{
		id = 10035,
		name = <<"感知之风">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 6,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,8},{att_area,5}]}, {shortime, []}, {lastime, []}, {base_att, 0.5}];
				_ ->
					[]
			end
	};

get(10036, SkillLv) ->
	#ets_skill{
		id = 10036,
		name = <<"风之迅捷">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,25},{att_area,2}]}, {shortime, []}, {lastime, [{10,dodge,0.25}]}, {base_att, 0.5}];
				_ ->
					[]
			end
	};

get(10037, SkillLv) ->
	#ets_skill{
		id = 10037,
		name = <<"风之狂暴">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,28},{att_area,2}]}, {shortime, []}, {lastime, [{8,last_crit,0.2}]}, {base_att, 0.5}];
				_ ->
					[]
			end
	};

get(10038, SkillLv) ->
	#ets_skill{
		id = 10038,
		name = <<"召唤怪物">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10039, SkillLv) ->
	#ets_skill{
		id = 10039,
		name = <<"顺劈斩">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 2,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,5},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 1.2}];
				_ ->
					[]
			end
	};

get(10040, SkillLv) ->
	#ets_skill{
		id = 10040,
		name = <<"低伤群攻">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 10,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,3},{att_area,10}]}, {shortime, []}, {lastime, []}, {base_att, 0.6}];
				_ ->
					[]
			end
	};

get(10041, SkillLv) ->
	#ets_skill{
		id = 10041,
		name = <<"普通群攻">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 4,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,8},{att_area,10}]}, {shortime, []}, {lastime, []}, {base_att, 1.2}];
				_ ->
					[]
			end
	};

get(10042, SkillLv) ->
	#ets_skill{
		id = 10042,
		name = <<"高伤群攻">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 6,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,15},{att_area,10}]}, {shortime, []}, {lastime, []}, {base_att, 1.5}];
				_ ->
					[]
			end
	};

get(10043, SkillLv) ->
	#ets_skill{
		id = 10043,
		name = <<"昏迷">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 2,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,35},{att_area,10}]}, {shortime, []}, {lastime, [{5,dizzy,0}]}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(10044, SkillLv) ->
	#ets_skill{
		id = 10044,
		name = <<"群体昏迷">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 4,
		area_obj = 0,
		assist_type = 0,
		limit_action = 2,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,40},{att_area,10}]}, {shortime, []}, {lastime, [{5,dizzy,0}]}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(10045, SkillLv) ->
	#ets_skill{
		id = 10045,
		name = <<"沉默">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 3,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,35},{att_area,10}]}, {shortime, []}, {lastime, [{5,silence,0}]}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(10046, SkillLv) ->
	#ets_skill{
		id = 10046,
		name = <<"群体沉默">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 4,
		area_obj = 0,
		assist_type = 0,
		limit_action = 3,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,40},{att_area,10}]}, {shortime, []}, {lastime, [{5,silence,0}]}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(10047, SkillLv) ->
	#ets_skill{
		id = 10047,
		name = <<"狂暴">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,60},{att_area,2}]}, {shortime, []}, {lastime, [{60,att,1.5},{60,lose_add_self,2.5}]}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(10048, SkillLv) ->
	#ets_skill{
		id = 10048,
		name = <<"自焚">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 4,
		area_obj = 1,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10049, SkillLv) ->
	#ets_skill{
		id = 10049,
		name = <<"抽蓝">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 4,
		area_obj = 1,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10050, SkillLv) ->
	#ets_skill{
		id = 10050,
		name = <<"特定范围伤害">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 4,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10051, SkillLv) ->
	#ets_skill{
		id = 10051,
		name = <<"随机攻击">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10052, SkillLv) ->
	#ets_skill{
		id = 10052,
		name = <<"命中降低">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 10,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,25},{att_area,10}]}, {shortime, []}, {lastime, [{15,hit,-0.9}]}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(10053, SkillLv) ->
	#ets_skill{
		id = 10053,
		name = <<"攻击降低">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 10,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,30},{att_area,10}]}, {shortime, []}, {lastime, [{10,att_der,-0.5}]}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(10054, SkillLv) ->
	#ets_skill{
		id = 10054,
		name = <<"烈焰花环">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 4,
		area_obj = 1,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,45},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 1.5}];
				_ ->
					[]
			end
	};

get(10055, SkillLv) ->
	#ets_skill{
		id = 10055,
		name = <<"流血">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, [{5,drug,500}]}, {base_att, 0.2}];
				_ ->
					[]
			end
	};

get(10056, SkillLv) ->
	#ets_skill{
		id = 10056,
		name = <<"单体攻击">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,2},{att_area,10}]}, {shortime, []}, {lastime, []}, {base_att, 1.2}];
				_ ->
					[]
			end
	};

get(10057, SkillLv) ->
	#ets_skill{
		id = 10057,
		name = <<"反伤">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, [{1800,bounce,{100,0.2}}]}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(10058, SkillLv) ->
	#ets_skill{
		id = 10058,
		name = <<"加血">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 1,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, [{0,hp,5000}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10059, SkillLv) ->
	#ets_skill{
		id = 10059,
		name = <<"3000固定伤害">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, [{hurt_add,3000}]}, {lastime, []}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(10060, SkillLv) ->
	#ets_skill{
		id = 10060,
		name = <<"9000固定伤害">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, [{hurt_add,9000}]}, {lastime, []}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(10061, SkillLv) ->
	#ets_skill{
		id = 10061,
		name = <<"300持续伤害">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, [{5,drug,300}]}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(10062, SkillLv) ->
	#ets_skill{
		id = 10062,
		name = <<"加血1">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 1,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, [{0,hp,5000}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10063, SkillLv) ->
	#ets_skill{
		id = 10063,
		name = <<"加血2">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 1,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, [{0,hp,5000}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10064, SkillLv) ->
	#ets_skill{
		id = 10064,
		name = <<"加血3">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 1,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, [{0,hp,5000}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10065, SkillLv) ->
	#ets_skill{
		id = 10065,
		name = <<"怒气技能">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 3,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10066, SkillLv) ->
	#ets_skill{
		id = 10066,
		name = <<"塔怪加血">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 3,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10067, SkillLv) ->
	#ets_skill{
		id = 10067,
		name = <<"能量圈1">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10068, SkillLv) ->
	#ets_skill{
		id = 10068,
		name = <<"能量圈2">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10069, SkillLv) ->
	#ets_skill{
		id = 10069,
		name = <<"魔爆术">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, [{5,energy,0}]}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(10070, SkillLv) ->
	#ets_skill{
		id = 10070,
		name = <<"法师群攻">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 3,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,1200},{att_area,5}]}, {shortime, []}, {lastime, []}, {base_att, 0.2}];
				_ ->
					[]
			end
	};

get(10071, SkillLv) ->
	#ets_skill{
		id = 10071,
		name = <<"甲士群攻">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 3,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,3600},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 0.33}];
				_ ->
					[]
			end
	};

get(10072, SkillLv) ->
	#ets_skill{
		id = 10072,
		name = <<"地震">>,
		career = 6,
		mod = 2,
		type = 1,
		obj = 2,
		area = 4,
		area_obj = 0,
		assist_type = 0,
		limit_action = 2,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,40},{att_area,10}]}, {shortime, []}, {lastime, [{5,dizzy,0}]}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(10073, SkillLv) ->
	#ets_skill{
		id = 10073,
		name = <<"鼓舞">>,
		career = 7,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,1},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10074, SkillLv) ->
	#ets_skill{
		id = 10074,
		name = <<"鼓舞">>,
		career = 7,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,2},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10075, SkillLv) ->
	#ets_skill{
		id = 10075,
		name = <<"鼓舞">>,
		career = 7,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,3},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10076, SkillLv) ->
	#ets_skill{
		id = 10076,
		name = <<"鼓舞">>,
		career = 7,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,4},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10077, SkillLv) ->
	#ets_skill{
		id = 10077,
		name = <<"鼓舞">>,
		career = 7,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,5},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10078, SkillLv) ->
	#ets_skill{
		id = 10078,
		name = <<"鼓舞">>,
		career = 7,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,6},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10079, SkillLv) ->
	#ets_skill{
		id = 10079,
		name = <<"鼓舞">>,
		career = 7,
		mod = 1,
		type = 1,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,7},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10080, SkillLv) ->
	#ets_skill{
		id = 10080,
		name = <<"鼓舞">>,
		career = 7,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,8},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10081, SkillLv) ->
	#ets_skill{
		id = 10081,
		name = <<"鼓舞">>,
		career = 7,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,9},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10082, SkillLv) ->
	#ets_skill{
		id = 10082,
		name = <<"鼓舞">>,
		career = 7,
		mod = 1,
		type = 1,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,10},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10083, SkillLv) ->
	#ets_skill{
		id = 10083,
		name = <<"分身">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10084, SkillLv) ->
	#ets_skill{
		id = 10084,
		name = <<"风">>,
		career = 6,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 1,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, [{30,last_anti,20.0}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10085, SkillLv) ->
	#ets_skill{
		id = 10085,
		name = <<"雷">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 1,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, [{20,drug_prc,0.05}]}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(10086, SkillLv) ->
	#ets_skill{
		id = 10086,
		name = <<"水">>,
		career = 6,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 1,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, [{25,dodge,100}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10087, SkillLv) ->
	#ets_skill{
		id = 10087,
		name = <<"火">>,
		career = 6,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 1,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, [{0,last_add_hp,{25,5,500000}}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10088, SkillLv) ->
	#ets_skill{
		id = 10088,
		name = <<"土">>,
		career = 6,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, [{20,att,5}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10089, SkillLv) ->
	#ets_skill{
		id = 10089,
		name = <<"引燃">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, [{5,ignite,1000}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10090, SkillLv) ->
	#ets_skill{
		id = 10090,
		name = <<"风怒">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, [{wind_anger,1}]}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(10091, SkillLv) ->
	#ets_skill{
		id = 10091,
		name = <<"火神之怒">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, [{fire_anger,2500}]}, {lastime, []}, {base_att, 2}];
				_ ->
					[]
			end
	};

get(10092, SkillLv) ->
	#ets_skill{
		id = 10092,
		name = <<"伤害共享">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25000, SkillLv) ->
	#ets_skill{
		id = 25000,
		name = <<"魔风破">>,
		career = 1,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,5},{coin,900},{culture,11}]}, {cast, [{mp_out,2},{cd,0.5},{att_area,2}]}, {shortime, [{att,14}]}, {lastime, []}, {base_att, 1}];
				2 ->
					[{condition, [{lv,6},{coin,1100},{culture,12}]}, {cast, [{mp_out,2},{cd,0.5},{att_area,2}]}, {shortime, [{att,17}]}, {lastime, []}, {base_att, 1}];
				3 ->
					[{condition, [{lv,7},{coin,1300},{culture,14}]}, {cast, [{mp_out,2},{cd,0.5},{att_area,2}]}, {shortime, [{att,20}]}, {lastime, []}, {base_att, 1}];
				4 ->
					[{condition, [{lv,8},{coin,1500},{culture,15}]}, {cast, [{mp_out,2},{cd,0.5},{att_area,2}]}, {shortime, [{att,23}]}, {lastime, []}, {base_att, 1}];
				5 ->
					[{condition, [{lv,9},{coin,1700},{culture,17}]}, {cast, [{mp_out,2},{cd,0.5},{att_area,2}]}, {shortime, [{att,26}]}, {lastime, []}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(25001, SkillLv) ->
	#ets_skill{
		id = 25001,
		name = <<"砍龙卷">>,
		career = 1,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,12},{coin,2300},{culture,23}]}, {cast, [{mp_out,7},{cd,1.8},{att_area,2}]}, {shortime, [{double,[6,0]},{hurt_add,26}]}, {lastime, []}, {base_att, 1.2}];
				2 ->
					[{condition, [{lv,13},{coin,2500},{culture,26}]}, {cast, [{mp_out,8},{cd,1.8},{att_area,2}]}, {shortime, [{double,[7,0]},{hurt_add,26}]}, {lastime, []}, {base_att, 1.2}];
				3 ->
					[{condition, [{lv,14},{coin,2700},{culture,28}]}, {cast, [{mp_out,9},{cd,1.8},{att_area,2}]}, {shortime, [{double,[8,0]},{hurt_add,26}]}, {lastime, []}, {base_att, 1.2}];
				4 ->
					[{condition, [{lv,15},{coin,3000},{culture,31}]}, {cast, [{mp_out,10},{cd,1.8},{att_area,2}]}, {shortime, [{double,[9,0]},{hurt_add,26}]}, {lastime, []}, {base_att, 1.2}];
				5 ->
					[{condition, [{lv,16},{coin,3100},{culture,35}]}, {cast, [{mp_out,11},{cd,1.8},{att_area,2}]}, {shortime, [{double,[10,0]},{hurt_add,26}]}, {lastime, []}, {base_att, 1.2}];
				_ ->
					[]
			end
	};

get(25002, SkillLv) ->
	#ets_skill{
		id = 25002,
		name = <<"翼风诀">>,
		career = 1,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,19},{coin,3700},{culture,48}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,hp_lim,350}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,21},{coin,4100},{culture,59}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,hp_lim,400}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,23},{coin,4500},{culture,73}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,hp_lim,450}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,25},{coin,5000},{culture,90}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,hp_lim,500}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,27},{coin,5300},{culture,111}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,hp_lim,550}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25003, SkillLv) ->
	#ets_skill{
		id = 25003,
		name = <<"怒风咆哮">>,
		career = 1,
		mod = 2,
		type = 1,
		obj = 2,
		area = 3,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 8,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,25},{coin,5000},{culture,90}]}, {cast, [{mp_out,40},{cd,60},{att_area,2}]}, {shortime, []}, {lastime, [{4,hate,0}]}, {base_att, 0.5}];
				2 ->
					[{condition, [{lv,27},{coin,5300},{culture,111}]}, {cast, [{mp_out,45},{cd,55},{att_area,2}]}, {shortime, []}, {lastime, [{5,hate,0}]}, {base_att, 0.5}];
				3 ->
					[{condition, [{lv,29},{coin,5700},{culture,137}]}, {cast, [{mp_out,50},{cd,50},{att_area,0}]}, {shortime, []}, {lastime, [{6,hate,0}]}, {base_att, 0.5}];
				4 ->
					[{condition, [{lv,31},{coin,15000},{culture,170}]}, {cast, [{mp_out,55},{cd,45},{att_area,0}]}, {shortime, []}, {lastime, [{7,hate,0}]}, {base_att, 0.5}];
				5 ->
					[{condition, [{lv,33},{coin,25000},{culture,311}]}, {cast, [{mp_out,60},{cd,40},{att_area,0}]}, {shortime, []}, {lastime, [{8,hate,0}]}, {base_att, 0.5}];
				_ ->
					[]
			end
	};

get(25004, SkillLv) ->
	#ets_skill{
		id = 25004,
		name = <<"风卷尘">>,
		career = 1,
		mod = 2,
		type = 1,
		obj = 2,
		area = 4,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,30},{coin,10000},{culture,153}]}, {cast, [{mp_out,25},{cd,5},{att_area,2}]}, {shortime, []}, {lastime, [{5,drug,22}]}, {base_att, 0.5}];
				2 ->
					[{condition, [{lv,32},{coin,20000},{culture,207}]}, {cast, [{mp_out,27},{cd,5},{att_area,2}]}, {shortime, []}, {lastime, [{5,drug,34}]}, {base_att, 0.5}];
				3 ->
					[{condition, [{lv,34},{coin,30000},{culture,374}]}, {cast, [{mp_out,29},{cd,5},{att_area,2}]}, {shortime, []}, {lastime, [{5,drug,46}]}, {base_att, 0.5}];
				4 ->
					[{condition, [{lv,36},{coin,44000},{culture,429}]}, {cast, [{mp_out,31},{cd,5},{att_area,2}]}, {shortime, []}, {lastime, [{5,drug,58}]}, {base_att, 0.5}];
				5 ->
					[{condition, [{lv,38},{coin,58000},{culture,496}]}, {cast, [{mp_out,33},{cd,5},{att_area,2}]}, {shortime, []}, {lastime, [{5,drug,70}]}, {base_att, 0.5}];
				_ ->
					[]
			end
	};

get(25005, SkillLv) ->
	#ets_skill{
		id = 25005,
		name = <<"疾风破">>,
		career = 1,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 2,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,35},{coin,37000},{culture,395}]}, {cast, [{mp_out,30},{cd,80},{att_area,6}]}, {shortime, []}, {lastime, [{3,assault,0}]}, {base_att, 0.2}];
				2 ->
					[{condition, [{lv,38},{coin,58000},{culture,496}]}, {cast, [{mp_out,35},{cd,75},{att_area,6}]}, {shortime, []}, {lastime, [{3,assault,0}]}, {base_att, 0.2}];
				3 ->
					[{condition, [{lv,41},{coin,85000},{culture,716}]}, {cast, [{mp_out,40},{cd,70},{att_area,6}]}, {shortime, []}, {lastime, [{3,assault,0}]}, {base_att, 0.2}];
				4 ->
					[{condition, [{lv,44},{coin,115000},{culture,916}]}, {cast, [{mp_out,45},{cd,65},{att_area,6}]}, {shortime, []}, {lastime, [{3,assault,0}]}, {base_att, 0.2}];
				5 ->
					[{condition, [{lv,47},{coin,151000},{culture,1290}]}, {cast, [{mp_out,50},{cd,50},{att_area,6}]}, {shortime, []}, {lastime, [{3,assault,0}]}, {base_att, 0.2}];
				_ ->
					[]
			end
	};

get(25006, SkillLv) ->
	#ets_skill{
		id = 25006,
		name = <<"邪风术">>,
		career = 1,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,40},{coin,75000},{culture,656}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,bounce,{80,0.1}}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,43},{coin,105000},{culture,876}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,bounce,{85,0.1}}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,46},{coin,139000},{culture,1196}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,bounce,{90,0.1}}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,49},{coin,175000},{culture,1610}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,bounce,{95,0.1}}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,52},{coin,220000},{culture,2530}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,bounce,{100,0.1}}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25007, SkillLv) ->
	#ets_skill{
		id = 25007,
		name = <<"君子风">>,
		career = 1,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,45},{coin,127000},{culture,1015}]}, {cast, [{mp_out,50},{cd,80},{att_area,0}]}, {shortime, []}, {lastime, [{6,lose_add,-0.15}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,48},{coin,163000},{culture,1512}]}, {cast, [{mp_out,55},{cd,75},{att_area,0}]}, {shortime, []}, {lastime, [{6,lose_add,-0.15}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,51},{coin,205000},{culture,2053}]}, {cast, [{mp_out,60},{cd,70},{att_area,0}]}, {shortime, []}, {lastime, [{6,lose_add,-0.15}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,54},{coin,250000},{culture,3507}]}, {cast, [{mp_out,65},{cd,65},{att_area,0}]}, {shortime, []}, {lastime, [{6,lose_add,-0.15}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,57},{coin,304000},{culture,5615}]}, {cast, [{mp_out,70},{cd,60},{att_area,0}]}, {shortime, []}, {lastime, [{6,lose_add,-0.15}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25008, SkillLv) ->
	#ets_skill{
		id = 25008,
		name = <<"暴风劫">>,
		career = 1,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,50},{coin,190000},{culture,1754}]}, {cast, [{mp_out,35},{cd,4},{att_area,2}]}, {shortime, [{hit_add,0.05}]}, {lastime, []}, {base_att, 1.37}];
				2 ->
					[{condition, [{lv,54},{coin,250000},{culture,3507}]}, {cast, [{mp_out,37},{cd,4},{att_area,2}]}, {shortime, [{hit_add,0.05}]}, {lastime, []}, {base_att, 1.39}];
				3 ->
					[{condition, [{lv,58},{coin,322000},{culture,6526}]}, {cast, [{mp_out,39},{cd,4},{att_area,2}]}, {shortime, [{hit_add,0.05}]}, {lastime, []}, {base_att, 1.41}];
				4 ->
					[{condition, [{lv,62},{coin,398000},{culture,8475}]}, {cast, [{mp_out,41},{cd,4},{att_area,2}]}, {shortime, [{hit_add,0.05}]}, {lastime, []}, {base_att, 1.43}];
				5 ->
					[{condition, [{lv,66},{coin,488000},{culture,9488}]}, {cast, [{mp_out,43},{cd,4},{att_area,2}]}, {shortime, [{hit_add,0.05}]}, {lastime, []}, {base_att, 1.45}];
				_ ->
					[]
			end
	};

get(25009, SkillLv) ->
	#ets_skill{
		id = 25009,
		name = <<"飓风霾">>,
		career = 1,
		mod = 1,
		type = 1,
		obj = 2,
		area = 3,
		area_obj = 0,
		assist_type = 0,
		limit_action = 3,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,55},{coin,268000},{culture,4243}]}, {cast, [{mp_out,40},{cd,70},{att_area,2}]}, {shortime, []}, {lastime, [{4,silence,0}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,59},{coin,340000},{culture,6900}]}, {cast, [{mp_out,45},{cd,65},{att_area,2}]}, {shortime, []}, {lastime, [{4,silence,0}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,63},{coin,418000},{culture,8673}]}, {cast, [{mp_out,50},{cd,60},{att_area,2}]}, {shortime, []}, {lastime, [{5,silence,0}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,67},{coin,513000},{culture,9804}]}, {cast, [{mp_out,55},{cd,55},{att_area,2}]}, {shortime, []}, {lastime, [{4,silence,0}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,71},{coin,617000},{culture,11258}]}, {cast, [{mp_out,60},{cd,50},{att_area,2}]}, {shortime, []}, {lastime, [{4,silence,0}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25010, SkillLv) ->
	#ets_skill{
		id = 25010,
		name = <<"破风袭">>,
		career = 1,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,60},{coin,358000},{culture,7679}]}, {cast, [{mp_out,45},{cd,30},{att_area,2}]}, {shortime, []}, {lastime, [{6,lose_add,0.13}]}, {base_att, 0.5}];
				2 ->
					[{condition, [{lv,64},{coin,438000},{culture,8963}]}, {cast, [{mp_out,50},{cd,30},{att_area,2}]}, {shortime, []}, {lastime, [{6,lose_add,0.16}]}, {base_att, 0.5}];
				3 ->
					[{condition, [{lv,68},{coin,538000},{culture,10244}]}, {cast, [{mp_out,55},{cd,30},{att_area,2}]}, {shortime, []}, {lastime, [{6,lose_add,0.19}]}, {base_att, 0.5}];
				4 ->
					[{condition, [{lv,72},{coin,644000},{culture,11984}]}, {cast, [{mp_out,0},{cd,30},{att_area,2}]}, {shortime, []}, {lastime, [{6,lose_add,0.22}]}, {base_att, 0.5}];
				5 ->
					[{condition, [{lv,76},{coin,758000},{culture,16170}]}, {cast, [{mp_out,0},{cd,30},{att_area,2}]}, {shortime, []}, {lastime, [{6,lose_add,0.5}]}, {base_att, 0.5}];
				_ ->
					[]
			end
	};

get(25011, SkillLv) ->
	#ets_skill{
		id = 25011,
		name = <<"罡风劲">>,
		career = 1,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,65},{coin,463000},{culture,9236}]}, {cast, [{mp_out,70},{cd,8},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 1.47}];
				2 ->
					[{condition, [{lv,70},{coin,590000},{culture,10844}]}, {cast, [{mp_out,74},{cd,8},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 1.49}];
				3 ->
					[{condition, [{lv,75},{coin,728000},{culture,15253}]}, {cast, [{mp_out,78},{cd,8},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 1.51}];
				4 ->
					[{condition, [{lv,80},{coin,883000},{culture,18832}]}, {cast, [{mp_out,82},{cd,8},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 1.53}];
				5 ->
					[{condition, [{lv,85},{coin,1053000},{culture,24197}]}, {cast, [{mp_out,86},{cd,8},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 1.55}];
				_ ->
					[]
			end
	};

get(25100, SkillLv) ->
	#ets_skill{
		id = 25100,
		name = <<"破冰斩">>,
		career = 2,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,5},{coin,900},{culture,11}]}, {cast, [{mp_out,2},{cd,0.5},{att_area,2}]}, {shortime, [{att,22}]}, {lastime, []}, {base_att, 1}];
				2 ->
					[{condition, [{lv,6},{coin,1100},{culture,12}]}, {cast, [{mp_out,2},{cd,0.5},{att_area,2}]}, {shortime, [{att,25}]}, {lastime, []}, {base_att, 1}];
				3 ->
					[{condition, [{lv,7},{coin,1300},{culture,14}]}, {cast, [{mp_out,2},{cd,0.5},{att_area,2}]}, {shortime, [{att,28}]}, {lastime, []}, {base_att, 1}];
				4 ->
					[{condition, [{lv,8},{coin,1500},{culture,15}]}, {cast, [{mp_out,2},{cd,0.5},{att_area,2}]}, {shortime, [{att,31}]}, {lastime, []}, {base_att, 1}];
				5 ->
					[{condition, [{lv,9},{coin,1700},{culture,17}]}, {cast, [{mp_out,2},{cd,0.5},{att_area,2}]}, {shortime, [{att,34}]}, {lastime, []}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(25101, SkillLv) ->
	#ets_skill{
		id = 25101,
		name = <<"天龙吼">>,
		career = 2,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,12},{coin,2300},{culture,23}]}, {cast, [{mp_out,8},{cd,1.8},{att_area,2}]}, {shortime, [{double,[6,0]},{hurt_add,34}]}, {lastime, []}, {base_att, 1.2}];
				2 ->
					[{condition, [{lv,13},{coin,2500},{culture,26}]}, {cast, [{mp_out,9},{cd,1.8},{att_area,2}]}, {shortime, [{double,[7,0]},{hurt_add,34}]}, {lastime, []}, {base_att, 1.2}];
				3 ->
					[{condition, [{lv,14},{coin,2700},{culture,28}]}, {cast, [{mp_out,10},{cd,1.8},{att_area,2}]}, {shortime, [{double,[8,0]},{hurt_add,34}]}, {lastime, []}, {base_att, 1.2}];
				4 ->
					[{condition, [{lv,15},{coin,3000},{culture,31}]}, {cast, [{mp_out,11},{cd,1.8},{att_area,2}]}, {shortime, [{double,[9,0]},{hurt_add,34}]}, {lastime, []}, {base_att, 1.2}];
				5 ->
					[{condition, [{lv,16},{coin,3100},{culture,35}]}, {cast, [{mp_out,12},{cd,1.8},{att_area,2}]}, {shortime, [{double,[10,0]},{hurt_add,34}]}, {lastime, []}, {base_att, 1.2}];
				_ ->
					[]
			end
	};

get(25102, SkillLv) ->
	#ets_skill{
		id = 25102,
		name = <<"风霜雪">>,
		career = 2,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,19},{coin,3700},{culture,48}]}, {cast, [{mp_out,15},{cd,3},{att_area,2}]}, {shortime, [{hit_add,0.05}]}, {lastime, []}, {base_att, 1.3}];
				2 ->
					[{condition, [{lv,21},{coin,4100},{culture,59}]}, {cast, [{mp_out,16},{cd,3},{att_area,2}]}, {shortime, [{hurt_add,25},{hit_add,0.05}]}, {lastime, []}, {base_att, 1.3}];
				3 ->
					[{condition, [{lv,23},{coin,4500},{culture,73}]}, {cast, [{mp_out,17},{cd,3},{att_area,2}]}, {shortime, [{hurt_add,50},{hit_add,0.05}]}, {lastime, []}, {base_att, 1.3}];
				4 ->
					[{condition, [{lv,25},{coin,5000},{culture,90}]}, {cast, [{mp_out,18},{cd,3},{att_area,2}]}, {shortime, [{hurt_add,75},{hit_add,0.05}]}, {lastime, []}, {base_att, 1.3}];
				5 ->
					[{condition, [{lv,27},{coin,5300},{culture,111}]}, {cast, [{mp_out,19},{cd,3},{att_area,2}]}, {shortime, [{hurt_add,100},{hit_add,0.05}]}, {lastime, []}, {base_att, 1.3}];
				_ ->
					[]
			end
	};

get(25103, SkillLv) ->
	#ets_skill{
		id = 25103,
		name = <<"玄冰战气">>,
		career = 2,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,25},{coin,5000},{culture,90}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,agile,28}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,27},{coin,5300},{culture,111}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,agile,36}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,29},{coin,5700},{culture,137}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,agile,44}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,31},{coin,15000},{culture,170}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,agile,52}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,33},{coin,25000},{culture,311}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,agile,60}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25104, SkillLv) ->
	#ets_skill{
		id = 25104,
		name = <<"双龙诀">>,
		career = 2,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,30},{coin,10000},{culture,153}]}, {cast, [{mp_out,21},{cd,14},{att_area,2}]}, {shortime, [{hurt_add,1}]}, {lastime, []}, {base_att, 0.75}];
				2 ->
					[{condition, [{lv,32},{coin,20000},{culture,207}]}, {cast, [{mp_out,22},{cd,12},{att_area,2}]}, {shortime, [{hurt_add,1}]}, {lastime, []}, {base_att, 0.75}];
				3 ->
					[{condition, [{lv,34},{coin,30000},{culture,374}]}, {cast, [{mp_out,23},{cd,10},{att_area,2}]}, {shortime, [{hurt_add,1}]}, {lastime, []}, {base_att, 0.75}];
				4 ->
					[{condition, [{lv,36},{coin,44000},{culture,429}]}, {cast, [{mp_out,24},{cd,8},{att_area,2}]}, {shortime, [{hurt_add,1}]}, {lastime, []}, {base_att, 0.75}];
				5 ->
					[{condition, [{lv,38},{coin,58000},{culture,496}]}, {cast, [{mp_out,25},{cd,6},{att_area,2}]}, {shortime, [{hurt_add,1}]}, {lastime, []}, {base_att, 0.75}];
				_ ->
					[]
			end
	};

get(25105, SkillLv) ->
	#ets_skill{
		id = 25105,
		name = <<"坎水诀">>,
		career = 2,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,35},{coin,37000},{culture,395}]}, {cast, [{mp_out,30},{cd,60},{att_area,0}]}, {shortime, []}, {lastime, [{5,last_anti,1.6}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,38},{coin,58000},{culture,496}]}, {cast, [{mp_out,32},{cd,60},{att_area,0}]}, {shortime, []}, {lastime, [{5,last_anti,1.7}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,41},{coin,85000},{culture,716}]}, {cast, [{mp_out,34},{cd,60},{att_area,0}]}, {shortime, []}, {lastime, [{5,last_anti,1.8}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,44},{coin,115000},{culture,916}]}, {cast, [{mp_out,36},{cd,60},{att_area,0}]}, {shortime, []}, {lastime, [{5,last_anti,1.9}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,47},{coin,151000},{culture,1290}]}, {cast, [{mp_out,38},{cd,60},{att_area,0}]}, {shortime, []}, {lastime, [{5,last_anti,2.0}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25106, SkillLv) ->
	#ets_skill{
		id = 25106,
		name = <<"潜流杀">>,
		career = 2,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,40},{coin,75000},{culture,656}]}, {cast, [{mp_out,48},{cd,40},{att_area,6}]}, {shortime, []}, {lastime, [{1,flash,0}]}, {base_att, 1.1}];
				2 ->
					[{condition, [{lv,43},{coin,105000},{culture,876}]}, {cast, [{mp_out,51},{cd,35},{att_area,6}]}, {shortime, []}, {lastime, [{1,flash,0}]}, {base_att, 1.1}];
				3 ->
					[{condition, [{lv,46},{coin,139000},{culture,1196}]}, {cast, [{mp_out,54},{cd,30},{att_area,6}]}, {shortime, []}, {lastime, [{1,flash,0}]}, {base_att, 1.1}];
				4 ->
					[{condition, [{lv,49},{coin,175000},{culture,1610}]}, {cast, [{mp_out,57},{cd,25},{att_area,6}]}, {shortime, []}, {lastime, [{1,flash,0}]}, {base_att, 1.1}];
				5 ->
					[{condition, [{lv,52},{coin,220000},{culture,2530}]}, {cast, [{mp_out,60},{cd,20},{att_area,6}]}, {shortime, []}, {lastime, [{1,flash,0}]}, {base_att, 1.1}];
				_ ->
					[]
			end
	};

get(25107, SkillLv) ->
	#ets_skill{
		id = 25107,
		name = <<"断水流">>,
		career = 2,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,45},{coin,127000},{culture,1015}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,hit_add,0.06}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,48},{coin,163000},{culture,1512}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,hit_add,0.07}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,51},{coin,205000},{culture,2053}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,hit_add,0.08}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,54},{coin,250000},{culture,3507}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,hit_add,0.09}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,57},{coin,304000},{culture,5615}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,hit_add,0.1}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25108, SkillLv) ->
	#ets_skill{
		id = 25108,
		name = <<"惊涛拍岸">>,
		career = 2,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,50},{coin,190000},{culture,1754}]}, {cast, [{mp_out,30},{cd,75},{att_area,0}]}, {shortime, []}, {lastime, [{6,last_crit,0.10}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,54},{coin,250000},{culture,3507}]}, {cast, [{mp_out,33},{cd,75},{att_area,0}]}, {shortime, []}, {lastime, [{9,last_crit,0.10}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,58},{coin,322000},{culture,6526}]}, {cast, [{mp_out,36},{cd,75},{att_area,0}]}, {shortime, []}, {lastime, [{11,last_crit,0.10}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,62},{coin,398000},{culture,8475}]}, {cast, [{mp_out,39},{cd,75},{att_area,0}]}, {shortime, []}, {lastime, [{13,last_crit,0.10}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,66},{coin,488000},{culture,9488}]}, {cast, [{mp_out,42},{cd,75},{att_area,0}]}, {shortime, []}, {lastime, [{15,last_crit,0.10}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25109, SkillLv) ->
	#ets_skill{
		id = 25109,
		name = <<"奔流击">>,
		career = 2,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,55},{coin,268000},{culture,4243}]}, {cast, [{mp_out,45},{cd,120},{att_area,0}]}, {shortime, []}, {lastime, [{5,dodge,1.2}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,59},{coin,340000},{culture,6900}]}, {cast, [{mp_out,48},{cd,120},{att_area,0}]}, {shortime, []}, {lastime, [{5,dodge,1.4}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,63},{coin,418000},{culture,8673}]}, {cast, [{mp_out,51},{cd,120},{att_area,0}]}, {shortime, []}, {lastime, [{5,dodge,1.6}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,67},{coin,513000},{culture,9804}]}, {cast, [{mp_out,54},{cd,120},{att_area,0}]}, {shortime, []}, {lastime, [{5,dodge,1.8}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,71},{coin,617000},{culture,11258}]}, {cast, [{mp_out,57},{cd,120},{att_area,0}]}, {shortime, []}, {lastime, [{5,dodge,2}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25110, SkillLv) ->
	#ets_skill{
		id = 25110,
		name = <<"百川汇宗">>,
		career = 2,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,60},{coin,358000},{culture,7679}]}, {cast, [{mp_out,65},{cd,10},{att_area,2}]}, {shortime, [{double,[20,7]}]}, {lastime, []}, {base_att, 1.4}];
				2 ->
					[{condition, [{lv,64},{coin,438000},{culture,8963}]}, {cast, [{mp_out,68},{cd,10},{att_area,2}]}, {shortime, [{double,[20,9]}]}, {lastime, []}, {base_att, 1.4}];
				3 ->
					[{condition, [{lv,68},{coin,538000},{culture,10244}]}, {cast, [{mp_out,71},{cd,10},{att_area,2}]}, {shortime, [{double,[20,11]}]}, {lastime, []}, {base_att, 1.4}];
				4 ->
					[{condition, [{lv,72},{coin,644000},{culture,11984}]}, {cast, [{mp_out,74},{cd,10},{att_area,2}]}, {shortime, [{double,[20,13]}]}, {lastime, []}, {base_att, 1.4}];
				5 ->
					[{condition, [{lv,76},{coin,758000},{culture,16170}]}, {cast, [{mp_out,77},{cd,10},{att_area,2}]}, {shortime, [{double,[20,15]}]}, {lastime, []}, {base_att, 1.4}];
				_ ->
					[]
			end
	};

get(25111, SkillLv) ->
	#ets_skill{
		id = 25111,
		name = <<"天绝刺">>,
		career = 2,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,65},{coin,463000},{culture,9236}]}, {cast, [{mp_out,80},{cd,10},{att_area,2}]}, {shortime, [{crit,0.12}]}, {lastime, []}, {base_att, 1.6}];
				2 ->
					[{condition, [{lv,70},{coin,590000},{culture,10844}]}, {cast, [{mp_out,83},{cd,10},{att_area,2}]}, {shortime, [{crit,0.14}]}, {lastime, []}, {base_att, 1.6}];
				3 ->
					[{condition, [{lv,75},{coin,728000},{culture,15253}]}, {cast, [{mp_out,86},{cd,10},{att_area,2}]}, {shortime, [{crit,0.16}]}, {lastime, []}, {base_att, 1.6}];
				4 ->
					[{condition, [{lv,80},{coin,883000},{culture,18832}]}, {cast, [{mp_out,89},{cd,10},{att_area,2}]}, {shortime, [{crit,0.18}]}, {lastime, []}, {base_att, 1.6}];
				5 ->
					[{condition, [{lv,85},{coin,1053000},{culture,24197}]}, {cast, [{mp_out,92},{cd,10},{att_area,2}]}, {shortime, [{crit,0.2}]}, {lastime, []}, {base_att, 1.6}];
				_ ->
					[]
			end
	};

get(25200, SkillLv) ->
	#ets_skill{
		id = 25200,
		name = <<"怒雷击">>,
		career = 3,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,5},{coin,900},{culture,11}]}, {cast, [{mp_out,3},{cd,0.5},{att_area,5}]}, {shortime, [{att,12}]}, {lastime, []}, {base_att, 1}];
				2 ->
					[{condition, [{lv,6},{coin,1100},{culture,12}]}, {cast, [{mp_out,3},{cd,0.5},{att_area,5}]}, {shortime, [{att,15}]}, {lastime, []}, {base_att, 1}];
				3 ->
					[{condition, [{lv,7},{coin,1300},{culture,14}]}, {cast, [{mp_out,3},{cd,0.5},{att_area,5}]}, {shortime, [{att,18}]}, {lastime, []}, {base_att, 1}];
				4 ->
					[{condition, [{lv,8},{coin,1500},{culture,15}]}, {cast, [{mp_out,3},{cd,0.5},{att_area,5}]}, {shortime, [{att,21}]}, {lastime, []}, {base_att, 1}];
				5 ->
					[{condition, [{lv,9},{coin,1700},{culture,17}]}, {cast, [{mp_out,3},{cd,0.5},{att_area,5}]}, {shortime, [{att,24}]}, {lastime, []}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(25201, SkillLv) ->
	#ets_skill{
		id = 25201,
		name = <<"惊雷破">>,
		career = 3,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,12},{coin,2300},{culture,23}]}, {cast, [{mp_out,9},{cd,1.8},{att_area,5}]}, {shortime, [{double,[6,0]},{hurt_add,24}]}, {lastime, []}, {base_att, 1.2}];
				2 ->
					[{condition, [{lv,13},{coin,2500},{culture,26}]}, {cast, [{mp_out,10},{cd,1.8},{att_area,5}]}, {shortime, [{double,[7,0]},{hurt_add,24}]}, {lastime, []}, {base_att, 1.2}];
				3 ->
					[{condition, [{lv,14},{coin,2700},{culture,28}]}, {cast, [{mp_out,11},{cd,1.8},{att_area,5}]}, {shortime, [{double,[8,0]},{hurt_add,24}]}, {lastime, []}, {base_att, 1.2}];
				4 ->
					[{condition, [{lv,15},{coin,3000},{culture,31}]}, {cast, [{mp_out,12},{cd,1.8},{att_area,5}]}, {shortime, [{double,[9,0]},{hurt_add,24}]}, {lastime, []}, {base_att, 1.2}];
				5 ->
					[{condition, [{lv,16},{coin,3100},{culture,35}]}, {cast, [{mp_out,13},{cd,1.8},{att_area,5}]}, {shortime, [{double,[10,0]},{hurt_add,24}]}, {lastime, []}, {base_att, 1.2}];
				_ ->
					[]
			end
	};

get(25202, SkillLv) ->
	#ets_skill{
		id = 25202,
		name = <<"仙雷诀">>,
		career = 3,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,19},{coin,3700},{culture,48}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,hit_add,0.03}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,21},{coin,4100},{culture,59}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,hit_add,0.04}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,23},{coin,4500},{culture,73}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,hit_add,0.05}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,25},{coin,5000},{culture,90}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,hit_add,0.06}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,27},{coin,5300},{culture,111}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,hit_add,0.07}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25203, SkillLv) ->
	#ets_skill{
		id = 25203,
		name = <<"青雷吼">>,
		career = 3,
		mod = 2,
		type = 1,
		obj = 2,
		area = 3,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,25},{coin,5000},{culture,73}]}, {cast, [{mp_out,50},{cd,4},{att_area,5}]}, {shortime, []}, {lastime, [{4,drug,60}]}, {base_att, 0.6}];
				2 ->
					[{condition, [{lv,27},{coin,5300},{culture,111}]}, {cast, [{mp_out,60},{cd,4},{att_area,5}]}, {shortime, []}, {lastime, [{4,drug,60}]}, {base_att, 0.65}];
				3 ->
					[{condition, [{lv,29},{coin,5700},{culture,137}]}, {cast, [{mp_out,70},{cd,4},{att_area,5}]}, {shortime, []}, {lastime, [{4,drug,60}]}, {base_att, 0.7}];
				4 ->
					[{condition, [{lv,31},{coin,15000},{culture,170}]}, {cast, [{mp_out,80},{cd,4},{att_area,5}]}, {shortime, []}, {lastime, [{4,drug,60}]}, {base_att, 0.75}];
				5 ->
					[{condition, [{lv,33},{coin,25000},{culture,311}]}, {cast, [{mp_out,90},{cd,4},{att_area,5}]}, {shortime, []}, {lastime, [{4,drug,60}]}, {base_att, 0.8}];
				_ ->
					[]
			end
	};

get(25204, SkillLv) ->
	#ets_skill{
		id = 25204,
		name = <<"紫雷劲">>,
		career = 3,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,30},{coin,10000},{culture,153}]}, {cast, [{mp_out,30},{cd,60},{att_area,5}]}, {shortime, []}, {lastime, [{4,lose_add,0.12}]}, {base_att, 1}];
				2 ->
					[{condition, [{lv,32},{coin,20000},{culture,207}]}, {cast, [{mp_out,35},{cd,60},{att_area,5}]}, {shortime, []}, {lastime, [{4,lose_add,0.14}]}, {base_att, 1}];
				3 ->
					[{condition, [{lv,34},{coin,30000},{culture,374}]}, {cast, [{mp_out,40},{cd,60},{att_area,5}]}, {shortime, []}, {lastime, [{4,lose_add,0.16}]}, {base_att, 1}];
				4 ->
					[{condition, [{lv,36},{coin,44000},{culture,429}]}, {cast, [{mp_out,45},{cd,60},{att_area,5}]}, {shortime, []}, {lastime, [{4,lose_add,0.18}]}, {base_att, 1}];
				5 ->
					[{condition, [{lv,38},{coin,58000},{culture,496}]}, {cast, [{mp_out,50},{cd,60},{att_area,5}]}, {shortime, []}, {lastime, [{4,lose_add,0.2}]}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(25205, SkillLv) ->
	#ets_skill{
		id = 25205,
		name = <<"玄雷落">>,
		career = 3,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 1,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,35},{coin,37000},{culture,395}]}, {cast, [{mp_out,52},{cd,60},{att_area,6}]}, {shortime, []}, {lastime, [{3,dizzy,0}]}, {base_att, 0.5}];
				2 ->
					[{condition, [{lv,38},{coin,58000},{culture,496}]}, {cast, [{mp_out,54},{cd,55},{att_area,6}]}, {shortime, []}, {lastime, [{3,dizzy,0}]}, {base_att, 0.5}];
				3 ->
					[{condition, [{lv,41},{coin,85000},{culture,716}]}, {cast, [{mp_out,56},{cd,50},{att_area,6}]}, {shortime, []}, {lastime, [{3,dizzy,0}]}, {base_att, 0.5}];
				4 ->
					[{condition, [{lv,44},{coin,115000},{culture,916}]}, {cast, [{mp_out,58},{cd,45},{att_area,6}]}, {shortime, []}, {lastime, [{3,dizzy,0}]}, {base_att, 0.5}];
				5 ->
					[{condition, [{lv,47},{coin,151000},{culture,1290}]}, {cast, [{mp_out,60},{cd,40},{att_area,6}]}, {shortime, []}, {lastime, [{3,dizzy,0}]}, {base_att, 0.5}];
				_ ->
					[]
			end
	};

get(25206, SkillLv) ->
	#ets_skill{
		id = 25206,
		name = <<"狂雷术">>,
		career = 3,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,40},{coin,75000},{culture,656}]}, {cast, [{mp_out,80},{cd,80},{att_area,0}]}, {shortime, []}, {lastime, [{10,att,0.06},{10,last_crit,0.05}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,43},{coin,105000},{culture,876}]}, {cast, [{mp_out,85},{cd,80},{att_area,0}]}, {shortime, []}, {lastime, [{10,att,0.07},{10,last_crit,0.05}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,46},{coin,139000},{culture,1196}]}, {cast, [{mp_out,90},{cd,80},{att_area,0}]}, {shortime, []}, {lastime, [{10,att,0.08},{10,last_crit,0.05}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,49},{coin,175000},{culture,1610}]}, {cast, [{mp_out,95},{cd,80},{att_area,0}]}, {shortime, []}, {lastime, [{10,att,0.09},{10,last_crit,0.05}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,52},{coin,220000},{culture,2530}]}, {cast, [{mp_out,100},{cd,80},{att_area,0}]}, {shortime, []}, {lastime, [{10,att,0.10},{10,last_crit,0.05}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25207, SkillLv) ->
	#ets_skill{
		id = 25207,
		name = <<"雷霆万钧">>,
		career = 3,
		mod = 2,
		type = 1,
		obj = 2,
		area = 3,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,45},{coin,127000},{culture,1015}]}, {cast, [{mp_out,70},{cd,6},{att_area,5}]}, {shortime, [{hurt_add,200}]}, {lastime, []}, {base_att, 0.8}];
				2 ->
					[{condition, [{lv,48},{coin,163000},{culture,1512}]}, {cast, [{mp_out,75},{cd,6},{att_area,5}]}, {shortime, [{hurt_add,225}]}, {lastime, []}, {base_att, 0.8}];
				3 ->
					[{condition, [{lv,51},{coin,205000},{culture,2053}]}, {cast, [{mp_out,80},{cd,6},{att_area,5}]}, {shortime, [{hurt_add,250}]}, {lastime, []}, {base_att, 0.8}];
				4 ->
					[{condition, [{lv,54},{coin,250000},{culture,3507}]}, {cast, [{mp_out,85},{cd,6},{att_area,5}]}, {shortime, [{hurt_add,275}]}, {lastime, []}, {base_att, 0.8}];
				5 ->
					[{condition, [{lv,57},{coin,304000},{culture,5615}]}, {cast, [{mp_out,90},{cd,6},{att_area,5}]}, {shortime, [{hurt_add,300}]}, {lastime, []}, {base_att, 0.8}];
				_ ->
					[]
			end
	};

get(25208, SkillLv) ->
	#ets_skill{
		id = 25208,
		name = <<"天雷劫">>,
		career = 3,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,50},{coin,190000},{culture,1754}]}, {cast, [{mp_out,48},{cd,7},{att_area,5}]}, {shortime, []}, {lastime, [{4,drug,300}]}, {base_att, 1.35}];
				2 ->
					[{condition, [{lv,54},{coin,250000},{culture,3507}]}, {cast, [{mp_out,51},{cd,7},{att_area,5}]}, {shortime, []}, {lastime, [{4,drug,400}]}, {base_att, 1.35}];
				3 ->
					[{condition, [{lv,58},{coin,322000},{culture,6526}]}, {cast, [{mp_out,54},{cd,7},{att_area,5}]}, {shortime, []}, {lastime, [{4,drug,500}]}, {base_att, 1.35}];
				4 ->
					[{condition, [{lv,62},{coin,398000},{culture,8475}]}, {cast, [{mp_out,57},{cd,7},{att_area,5}]}, {shortime, []}, {lastime, [{4,drug,600}]}, {base_att, 1.35}];
				5 ->
					[{condition, [{lv,66},{coin,488000},{culture,9488}]}, {cast, [{mp_out,60},{cd,7},{att_area,5}]}, {shortime, []}, {lastime, [{4,drug,700}]}, {base_att, 1.35}];
				_ ->
					[]
			end
	};

get(25209, SkillLv) ->
	#ets_skill{
		id = 25209,
		name = <<"幻雷闪">>,
		career = 3,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,55},{coin,268000},{culture,4243}]}, {cast, [{mp_out,80},{cd,70},{att_area,0}]}, {shortime, []}, {lastime, [{5,lose_add,0.05},{5,hurt_add,0.1}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,59},{coin,340000},{culture,6900}]}, {cast, [{mp_out,90},{cd,70},{att_area,0}]}, {shortime, []}, {lastime, [{6,lose_add,0.05},{6,hurt_add,0.1}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,63},{coin,418000},{culture,8673}]}, {cast, [{mp_out,100},{cd,70},{att_area,0}]}, {shortime, []}, {lastime, [{7,lose_add,0.05},{7,hurt_add,0.1}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,67},{coin,513000},{culture,9804}]}, {cast, [{mp_out,110},{cd,70},{att_area,0}]}, {shortime, []}, {lastime, [{8,lose_add,0.05},{8,hurt_add,0.1}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,71},{coin,617000},{culture,11258}]}, {cast, [{mp_out,120},{cd,70},{att_area,0}]}, {shortime, []}, {lastime, [{9,lose_add,0.05},{9,hurt_add,0.1}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25210, SkillLv) ->
	#ets_skill{
		id = 25210,
		name = <<"暴雷令">>,
		career = 3,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,60},{coin,358000},{culture,7679}]}, {cast, [{mp_out,72},{cd,8},{att_area,5}]}, {shortime, [{crit,0.09}]}, {lastime, []}, {base_att, 1.57}];
				2 ->
					[{condition, [{lv,64},{coin,438000},{culture,8963}]}, {cast, [{mp_out,74},{cd,8},{att_area,5}]}, {shortime, [{crit,0.13}]}, {lastime, []}, {base_att, 1.59}];
				3 ->
					[{condition, [{lv,68},{coin,538000},{culture,10244}]}, {cast, [{mp_out,76},{cd,8},{att_area,5}]}, {shortime, [{crit,0.17}]}, {lastime, []}, {base_att, 1.61}];
				4 ->
					[{condition, [{lv,72},{coin,644000},{culture,11984}]}, {cast, [{mp_out,78},{cd,8},{att_area,5}]}, {shortime, [{crit,0.21}]}, {lastime, []}, {base_att, 1.63}];
				5 ->
					[{condition, [{lv,76},{coin,758000},{culture,16170}]}, {cast, [{mp_out,80},{cd,8},{att_area,5}]}, {shortime, [{crit,0.25}]}, {lastime, []}, {base_att, 1.65}];
				_ ->
					[]
			end
	};

get(25211, SkillLv) ->
	#ets_skill{
		id = 25211,
		name = <<"雷神印">>,
		career = 3,
		mod = 2,
		type = 1,
		obj = 2,
		area = 4,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,65},{coin,463000},{culture,9236}]}, {cast, [{mp_out,120},{cd,12},{att_area,5}]}, {shortime, []}, {lastime, []}, {base_att, 1.13}];
				2 ->
					[{condition, [{lv,70},{coin,590000},{culture,10844}]}, {cast, [{mp_out,125},{cd,12},{att_area,5}]}, {shortime, []}, {lastime, []}, {base_att, 1.16}];
				3 ->
					[{condition, [{lv,75},{coin,728000},{culture,15253}]}, {cast, [{mp_out,130},{cd,12},{att_area,5}]}, {shortime, []}, {lastime, []}, {base_att, 1.19}];
				4 ->
					[{condition, [{lv,80},{coin,883000},{culture,18832}]}, {cast, [{mp_out,135},{cd,12},{att_area,5}]}, {shortime, []}, {lastime, []}, {base_att, 1.22}];
				5 ->
					[{condition, [{lv,85},{coin,1053000},{culture,24197}]}, {cast, [{mp_out,140},{cd,12},{att_area,5}]}, {shortime, []}, {lastime, []}, {base_att, 1.25}];
				_ ->
					[]
			end
	};

get(25300, SkillLv) ->
	#ets_skill{
		id = 25300,
		name = <<"无名火">>,
		career = 4,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,5},{coin,900},{culture,11}]}, {cast, [{mp_out,3},{cd,0.5},{att_area,5}]}, {shortime, [{att,18}]}, {lastime, []}, {base_att, 1}];
				2 ->
					[{condition, [{lv,6},{coin,1100},{culture,12}]}, {cast, [{mp_out,3},{cd,0.5},{att_area,5}]}, {shortime, [{att,21}]}, {lastime, []}, {base_att, 1}];
				3 ->
					[{condition, [{lv,7},{coin,1300},{culture,14}]}, {cast, [{mp_out,3},{cd,0.5},{att_area,5}]}, {shortime, [{att,24}]}, {lastime, []}, {base_att, 1}];
				4 ->
					[{condition, [{lv,8},{coin,1500},{culture,15}]}, {cast, [{mp_out,3},{cd,0.5},{att_area,5}]}, {shortime, [{att,27}]}, {lastime, []}, {base_att, 1}];
				5 ->
					[{condition, [{lv,9},{coin,1700},{culture,17}]}, {cast, [{mp_out,3},{cd,0.5},{att_area,5}]}, {shortime, [{att,30}]}, {lastime, []}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(25301, SkillLv) ->
	#ets_skill{
		id = 25301,
		name = <<"焦阳乐">>,
		career = 4,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,12},{coin,2300},{culture,23}]}, {cast, [{mp_out,12},{cd,1.8},{att_area,5}]}, {shortime, [{double,[6,0]},{hurt_add,20}]}, {lastime, []}, {base_att, 1.2}];
				2 ->
					[{condition, [{lv,13},{coin,2500},{culture,26}]}, {cast, [{mp_out,13},{cd,1.8},{att_area,5}]}, {shortime, [{double,[7,0]},{hurt_add,20}]}, {lastime, []}, {base_att, 1.2}];
				3 ->
					[{condition, [{lv,14},{coin,2700},{culture,28}]}, {cast, [{mp_out,14},{cd,1.8},{att_area,5}]}, {shortime, [{double,[8,0]},{hurt_add,20}]}, {lastime, []}, {base_att, 1.2}];
				4 ->
					[{condition, [{lv,15},{coin,3000},{culture,31}]}, {cast, [{mp_out,15},{cd,1.8},{att_area,5}]}, {shortime, [{double,[9,0]},{hurt_add,20}]}, {lastime, []}, {base_att, 1.2}];
				5 ->
					[{condition, [{lv,16},{coin,3100},{culture,35}]}, {cast, [{mp_out,16},{cd,1.8},{att_area,5}]}, {shortime, [{double,[10,0]},{hurt_add,20}]}, {lastime, []}, {base_att, 1.2}];
				_ ->
					[]
			end
	};

get(25302, SkillLv) ->
	#ets_skill{
		id = 25302,
		name = <<"暖慈光">>,
		career = 4,
		mod = 1,
		type = 2,
		obj = 3,
		area = 0,
		area_obj = 0,
		assist_type = 1,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,19},{coin,3700},{culture,48}]}, {cast, [{mp_out,55},{cd,2},{att_area,5}]}, {shortime, []}, {lastime, [{0,hp,0.8}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,21},{coin,4100},{culture,59}]}, {cast, [{mp_out,60},{cd,2},{att_area,5}]}, {shortime, []}, {lastime, [{0,hp,0.85}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,23},{coin,4500},{culture,73}]}, {cast, [{mp_out,65},{cd,2},{att_area,5}]}, {shortime, []}, {lastime, [{0,hp,0.9}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,25},{coin,5000},{culture,90}]}, {cast, [{mp_out,70},{cd,2},{att_area,5}]}, {shortime, []}, {lastime, [{0,hp,0.95}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,27},{coin,5300},{culture,111}]}, {cast, [{mp_out,75},{cd,2},{att_area,5}]}, {shortime, []}, {lastime, [{0,hp,1}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25303, SkillLv) ->
	#ets_skill{
		id = 25303,
		name = <<"星火燎原">>,
		career = 4,
		mod = 2,
		type = 1,
		obj = 2,
		area = 3,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,25},{coin,5000},{culture,90}]}, {cast, [{mp_out,30},{cd,4},{att_area,5}]}, {shortime, []}, {lastime, []}, {base_att, 0.8}];
				2 ->
					[{condition, [{lv,27},{coin,5300},{culture,111}]}, {cast, [{mp_out,35},{cd,4},{att_area,5}]}, {shortime, []}, {lastime, []}, {base_att, 0.85}];
				3 ->
					[{condition, [{lv,29},{coin,5700},{culture,137}]}, {cast, [{mp_out,40},{cd,4},{att_area,5}]}, {shortime, []}, {lastime, []}, {base_att, 0.9}];
				4 ->
					[{condition, [{lv,31},{coin,15000},{culture,170}]}, {cast, [{mp_out,45},{cd,4},{att_area,5}]}, {shortime, []}, {lastime, []}, {base_att, 0.95}];
				5 ->
					[{condition, [{lv,33},{coin,25000},{culture,311}]}, {cast, [{mp_out,50},{cd,4},{att_area,5}]}, {shortime, []}, {lastime, []}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(25304, SkillLv) ->
	#ets_skill{
		id = 25304,
		name = <<"魔心魇">>,
		career = 4,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,30},{coin,10000},{culture,153}]}, {cast, [{mp_out,70},{cd,5},{att_area,5}]}, {shortime, [{hurt_add,150}]}, {lastime, [{4,att_der,-30}]}, {base_att, 1}];
				2 ->
					[{condition, [{lv,32},{coin,20000},{culture,207}]}, {cast, [{mp_out,75},{cd,5},{att_area,5}]}, {shortime, [{hurt_add,150}]}, {lastime, [{4,att_der,-30}]}, {base_att, 1.05}];
				3 ->
					[{condition, [{lv,34},{coin,30000},{culture,374}]}, {cast, [{mp_out,80},{cd,5},{att_area,5}]}, {shortime, [{hurt_add,150}]}, {lastime, [{4,att_der,-30}]}, {base_att, 1.1}];
				4 ->
					[{condition, [{lv,36},{coin,44000},{culture,429}]}, {cast, [{mp_out,85},{cd,5},{att_area,5}]}, {shortime, [{hurt_add,150}]}, {lastime, [{4,att_der,-30}]}, {base_att, 1.15}];
				5 ->
					[{condition, [{lv,38},{coin,58000},{culture,496}]}, {cast, [{mp_out,90},{cd,5},{att_area,5}]}, {shortime, [{hurt_add,150}]}, {lastime, [{4,att_der,-30}]}, {base_att, 1.2}];
				_ ->
					[]
			end
	};

get(25305, SkillLv) ->
	#ets_skill{
		id = 25305,
		name = <<"离火仙诀">>,
		career = 4,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,35},{coin,37000},{culture,395}]}, {cast, [{mp_out,60},{cd,25},{att_area,7}]}, {shortime, []}, {lastime, [{20,shield,{7,7}}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,38},{coin,58000},{culture,496}]}, {cast, [{mp_out,70},{cd,25},{att_area,0}]}, {shortime, []}, {lastime, [{20,shield,{7,7}}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,41},{coin,85000},{culture,716}]}, {cast, [{mp_out,70},{cd,25},{att_area,7}]}, {shortime, []}, {lastime, [{20,shield,{7,7}}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,44},{coin,115000},{culture,916}]}, {cast, [{mp_out,75},{cd,25},{att_area,7}]}, {shortime, []}, {lastime, [{20,shield,{7,7}}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,47},{coin,151000},{culture,1290}]}, {cast, [{mp_out,80},{cd,25},{att_area,7}]}, {shortime, []}, {lastime, [{20,shield,{7,7}}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25306, SkillLv) ->
	#ets_skill{
		id = 25306,
		name = <<"坠残阳">>,
		career = 4,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,40},{coin,75000},{culture,656}]}, {cast, [{mp_out,45},{cd,20},{att_area,5}]}, {shortime, []}, {lastime, [{6,att_der,-0.06}]}, {base_att, 0.5}];
				2 ->
					[{condition, [{lv,43},{coin,105000},{culture,876}]}, {cast, [{mp_out,50},{cd,20},{att_area,5}]}, {shortime, []}, {lastime, [{6,att_der,-0.07}]}, {base_att, 0.5}];
				3 ->
					[{condition, [{lv,46},{coin,139000},{culture,1196}]}, {cast, [{mp_out,55},{cd,20},{att_area,5}]}, {shortime, []}, {lastime, [{6,att_der,-0.08}]}, {base_att, 0.5}];
				4 ->
					[{condition, [{lv,49},{coin,175000},{culture,1610}]}, {cast, [{mp_out,60},{cd,20},{att_area,5}]}, {shortime, []}, {lastime, [{6,att_der,-0.09}]}, {base_att, 0.5}];
				5 ->
					[{condition, [{lv,52},{coin,220000},{culture,2530}]}, {cast, [{mp_out,65},{cd,20},{att_area,5}]}, {shortime, []}, {lastime, [{6,att_der,-0.1}]}, {base_att, 0.5}];
				_ ->
					[]
			end
	};

get(25307, SkillLv) ->
	#ets_skill{
		id = 25307,
		name = <<"日光咏">>,
		career = 4,
		mod = 1,
		type = 2,
		obj = 3,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,45},{coin,127000},{culture,1015}]}, {cast, [{mp_out,0.2},{cd,2},{att_area,3}]}, {shortime, []}, {lastime, [{1800,hp_lim,300}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,48},{coin,163000},{culture,1512}]}, {cast, [{mp_out,0.2},{cd,2},{att_area,3}]}, {shortime, []}, {lastime, [{1800,hp_lim,350}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,51},{coin,205000},{culture,2053}]}, {cast, [{mp_out,0.2},{cd,2},{att_area,3}]}, {shortime, []}, {lastime, [{1800,hp_lim,400}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,54},{coin,250000},{culture,3507}]}, {cast, [{mp_out,0.2},{cd,2},{att_area,3}]}, {shortime, []}, {lastime, [{1800,hp_lim,450}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,57},{coin,304000},{culture,5615}]}, {cast, [{mp_out,0.2},{cd,2},{att_area,3}]}, {shortime, []}, {lastime, [{1800,hp_lim,500}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25308, SkillLv) ->
	#ets_skill{
		id = 25308,
		name = <<"润心诀">>,
		career = 4,
		mod = 1,
		type = 2,
		obj = 3,
		area = 0,
		area_obj = 0,
		assist_type = 1,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,50},{coin,190000},{culture,1754}]}, {cast, [{mp_out,70},{cd,8},{att_area,5}]}, {shortime, []}, {lastime, [{0,last_add_hp,{5,1,0.2}}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,54},{coin,250000},{culture,3507}]}, {cast, [{mp_out,75},{cd,8},{att_area,5}]}, {shortime, []}, {lastime, [{0,last_add_hp,{5,1,0.21}}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,58},{coin,322000},{culture,6526}]}, {cast, [{mp_out,80},{cd,8},{att_area,5}]}, {shortime, []}, {lastime, [{0,last_add_hp,{5,1,0.22}}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,62},{coin,398000},{culture,8475}]}, {cast, [{mp_out,85},{cd,8},{att_area,5}]}, {shortime, []}, {lastime, [{0,last_add_hp,{5,1,0.23}}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,66},{coin,488000},{culture,9488}]}, {cast, [{mp_out,90},{cd,8},{att_area,5}]}, {shortime, []}, {lastime, [{0,last_add_hp,{5,1,0.24}}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25309, SkillLv) ->
	#ets_skill{
		id = 25309,
		name = <<"炙阳燧">>,
		career = 4,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,55},{coin,268000},{culture,4243}]}, {cast, [{mp_out,60},{cd,5},{att_area,5}]}, {shortime, []}, {lastime, [{2,last_def,-0.05},{2,last_anti,-0.05}]}, {base_att, 1.3}];
				2 ->
					[{condition, [{lv,59},{coin,340000},{culture,6900}]}, {cast, [{mp_out,65},{cd,5},{att_area,5}]}, {shortime, []}, {lastime, [{3,last_def,-0.05},{3,last_anti,-0.05}]}, {base_att, 1.3}];
				3 ->
					[{condition, [{lv,63},{coin,418000},{culture,8673}]}, {cast, [{mp_out,70},{cd,5},{att_area,5}]}, {shortime, []}, {lastime, [{4,last_def,-0.05},{4,last_anti,-0.05}]}, {base_att, 1.3}];
				4 ->
					[{condition, [{lv,67},{coin,513000},{culture,9804}]}, {cast, [{mp_out,75},{cd,5},{att_area,5}]}, {shortime, []}, {lastime, [{5,last_def,-0.05},{5,last_anti,-0.05}]}, {base_att, 1.3}];
				5 ->
					[{condition, [{lv,71},{coin,617000},{culture,11258}]}, {cast, [{mp_out,80},{cd,5},{att_area,5}]}, {shortime, []}, {lastime, [{6,last_def,-0.05},{6,last_anti,-0.05}]}, {base_att, 1.3}];
				_ ->
					[]
			end
	};

get(25310, SkillLv) ->
	#ets_skill{
		id = 25310,
		name = <<"迷火歌">>,
		career = 4,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 2,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,60},{coin,358000},{culture,7679}]}, {cast, [{mp_out,70},{cd,70},{att_area,5}]}, {shortime, []}, {lastime, [{3,dizzy,0}]}, {base_att, 0.2}];
				2 ->
					[{condition, [{lv,64},{coin,438000},{culture,8963}]}, {cast, [{mp_out,75},{cd,65},{att_area,5}]}, {shortime, []}, {lastime, [{3,dizzy,0}]}, {base_att, 0.2}];
				3 ->
					[{condition, [{lv,68},{coin,538000},{culture,10244}]}, {cast, [{mp_out,80},{cd,60},{att_area,5}]}, {shortime, []}, {lastime, [{3,dizzy,0}]}, {base_att, 0.2}];
				4 ->
					[{condition, [{lv,72},{coin,644000},{culture,11984}]}, {cast, [{mp_out,85},{cd,55},{att_area,5}]}, {shortime, []}, {lastime, [{3,dizzy,0}]}, {base_att, 0.2}];
				5 ->
					[{condition, [{lv,76},{coin,758000},{culture,16170}]}, {cast, [{mp_out,90},{cd,50},{att_area,5}]}, {shortime, []}, {lastime, [{3,dizzy,0}]}, {base_att, 0.2}];
				_ ->
					[]
			end
	};

get(25311, SkillLv) ->
	#ets_skill{
		id = 25311,
		name = <<"焚天诀">>,
		career = 4,
		mod = 2,
		type = 1,
		obj = 2,
		area = 4,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,65},{coin,463000},{culture,9236}]}, {cast, [{mp_out,300},{cd,9},{att_area,5}]}, {shortime, [{hurt_add,300}]}, {lastime, []}, {base_att, 1.1}];
				2 ->
					[{condition, [{lv,70},{coin,590000},{culture,10844}]}, {cast, [{mp_out,309},{cd,9},{att_area,5}]}, {shortime, [{hurt_add,325}]}, {lastime, []}, {base_att, 1.1}];
				3 ->
					[{condition, [{lv,75},{coin,728000},{culture,15253}]}, {cast, [{mp_out,318},{cd,9},{att_area,5}]}, {shortime, [{hurt_add,350}]}, {lastime, []}, {base_att, 1.1}];
				4 ->
					[{condition, [{lv,80},{coin,883000},{culture,18832}]}, {cast, [{mp_out,327},{cd,9},{att_area,5}]}, {shortime, [{hurt_add,375}]}, {lastime, []}, {base_att, 1.1}];
				5 ->
					[{condition, [{lv,85},{coin,1053000},{culture,24197}]}, {cast, [{mp_out,336},{cd,9},{att_area,5}]}, {shortime, [{hurt_add,400}]}, {lastime, []}, {base_att, 1.1}];
				_ ->
					[]
			end
	};

get(25400, SkillLv) ->
	#ets_skill{
		id = 25400,
		name = <<"地刺术">>,
		career = 5,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,5},{coin,900},{culture,11}]}, {cast, [{mp_out,2},{cd,0.5},{att_area,2}]}, {shortime, [{att,16}]}, {lastime, []}, {base_att, 1}];
				2 ->
					[{condition, [{lv,6},{coin,1100},{culture,12}]}, {cast, [{mp_out,2},{cd,0.5},{att_area,2}]}, {shortime, [{att,19}]}, {lastime, []}, {base_att, 1}];
				3 ->
					[{condition, [{lv,7},{coin,1300},{culture,14}]}, {cast, [{mp_out,2},{cd,0.5},{att_area,2}]}, {shortime, [{att,22}]}, {lastime, []}, {base_att, 1}];
				4 ->
					[{condition, [{lv,8},{coin,1500},{culture,15}]}, {cast, [{mp_out,2},{cd,0.5},{att_area,2}]}, {shortime, [{att,25}]}, {lastime, []}, {base_att, 1}];
				5 ->
					[{condition, [{lv,9},{coin,1700},{culture,17}]}, {cast, [{mp_out,2},{cd,0.5},{att_area,2}]}, {shortime, [{att,28}]}, {lastime, []}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(25401, SkillLv) ->
	#ets_skill{
		id = 25401,
		name = <<"裂地岩">>,
		career = 5,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,12},{coin,2300},{culture,23}]}, {cast, [{mp_out,7},{cd,1.8},{att_area,2}]}, {shortime, [{double,[6,0]},{hurt_add,25}]}, {lastime, []}, {base_att, 1.2}];
				2 ->
					[{condition, [{lv,13},{coin,2500},{culture,26}]}, {cast, [{mp_out,8},{cd,1.8},{att_area,2}]}, {shortime, [{double,[7,0]},{hurt_add,25}]}, {lastime, []}, {base_att, 1.2}];
				3 ->
					[{condition, [{lv,14},{coin,2700},{culture,28}]}, {cast, [{mp_out,9},{cd,1.8},{att_area,2}]}, {shortime, [{double,[8,0]},{hurt_add,25}]}, {lastime, []}, {base_att, 1.2}];
				4 ->
					[{condition, [{lv,15},{coin,3000},{culture,31}]}, {cast, [{mp_out,10},{cd,1.8},{att_area,2}]}, {shortime, [{double,[9,0]},{hurt_add,25}]}, {lastime, []}, {base_att, 1.2}];
				5 ->
					[{condition, [{lv,16},{coin,3100},{culture,35}]}, {cast, [{mp_out,11},{cd,1.8},{att_area,2}]}, {shortime, [{double,[10,0]},{hurt_add,25}]}, {lastime, []}, {base_att, 1.2}];
				_ ->
					[]
			end
	};

get(25402, SkillLv) ->
	#ets_skill{
		id = 25402,
		name = <<"含沙射影">>,
		career = 5,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,19},{coin,3700},{culture,48}]}, {cast, [{mp_out,11},{cd,5},{att_area,2}]}, {shortime, []}, {lastime, [{3,att_der,-0.08}]}, {base_att, 1.25}];
				2 ->
					[{condition, [{lv,21},{coin,4100},{culture,59}]}, {cast, [{mp_out,12},{cd,5},{att_area,2}]}, {shortime, []}, {lastime, [{3,att_der,-0.11}]}, {base_att, 1.25}];
				3 ->
					[{condition, [{lv,23},{coin,4500},{culture,73}]}, {cast, [{mp_out,13},{cd,5},{att_area,2}]}, {shortime, []}, {lastime, [{3,att_der,-0.14}]}, {base_att, 1.25}];
				4 ->
					[{condition, [{lv,25},{coin,5000},{culture,90}]}, {cast, [{mp_out,14},{cd,5},{att_area,2}]}, {shortime, []}, {lastime, [{3,att_der,-0.17}]}, {base_att, 1.25}];
				5 ->
					[{condition, [{lv,27},{coin,5300},{culture,111}]}, {cast, [{mp_out,15},{cd,5},{att_area,2}]}, {shortime, []}, {lastime, [{3,att_der,-0.2}]}, {base_att, 1.25}];
				_ ->
					[]
			end
	};

get(25403, SkillLv) ->
	#ets_skill{
		id = 25403,
		name = <<"星沉地动">>,
		career = 5,
		mod = 2,
		type = 1,
		obj = 2,
		area = 3,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,25},{coin,5000},{culture,90}]}, {cast, [{mp_out,40},{cd,5},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 0.6}];
				2 ->
					[{condition, [{lv,27},{coin,5300},{culture,111}]}, {cast, [{mp_out,50},{cd,5},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 0.65}];
				3 ->
					[{condition, [{lv,29},{coin,5700},{culture,137}]}, {cast, [{mp_out,60},{cd,5},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 0.7}];
				4 ->
					[{condition, [{lv,31},{coin,15000},{culture,170}]}, {cast, [{mp_out,70},{cd,5},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 0.75}];
				5 ->
					[{condition, [{lv,33},{coin,25000},{culture,311}]}, {cast, [{mp_out,80},{cd,5},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 0.8}];
				_ ->
					[]
			end
	};

get(25404, SkillLv) ->
	#ets_skill{
		id = 25404,
		name = <<"厚土沉积">>,
		career = 5,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,30},{coin,10000},{culture,153}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,hit_add,0.06}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,32},{coin,20000},{culture,207}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,hit_add,0.07}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,34},{coin,30000},{culture,374}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,hit_add,0.08}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,36},{coin,44000},{culture,429}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,hit_add,0.09}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,38},{coin,58000},{culture,496}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,0}]}, {shortime, []}, {lastime, [{1800,hit_add,0.1}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25405, SkillLv) ->
	#ets_skill{
		id = 25405,
		name = <<"流沙袭">>,
		career = 5,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,35},{coin,37000},{culture,395}]}, {cast, [{mp_out,40},{cd,30},{att_area,2}]}, {shortime, []}, {lastime, [{10,speed,-0.4}]}, {base_att, 0.5}];
				2 ->
					[{condition, [{lv,38},{coin,58000},{culture,496}]}, {cast, [{mp_out,50},{cd,30},{att_area,2}]}, {shortime, []}, {lastime, [{5,speed,-0.45}]}, {base_att, 0.5}];
				3 ->
					[{condition, [{lv,41},{coin,85000},{culture,716}]}, {cast, [{mp_out,60},{cd,30},{att_area,2}]}, {shortime, []}, {lastime, [{5,speed,-0.5}]}, {base_att, 0.5}];
				4 ->
					[{condition, [{lv,44},{coin,115000},{culture,916}]}, {cast, [{mp_out,70},{cd,30},{att_area,2}]}, {shortime, []}, {lastime, [{5,speed,-0.55}]}, {base_att, 0.5}];
				5 ->
					[{condition, [{lv,47},{coin,151000},{culture,1290}]}, {cast, [{mp_out,80},{cd,30},{att_area,2}]}, {shortime, []}, {lastime, [{5,speed,-0.6}]}, {base_att, 0.5}];
				_ ->
					[]
			end
	};

get(25406, SkillLv) ->
	#ets_skill{
		id = 25406,
		name = <<"风尘绝">>,
		career = 5,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,40},{coin,75000},{culture,656}]}, {cast, [{mp_out,48},{cd,60},{att_area,2}]}, {shortime, [{crit,0.2}]}, {lastime, [{8,lose_add_self,0.2},{8,last_crit,0.2}]}, {base_att, 1}];
				2 ->
					[{condition, [{lv,43},{coin,105000},{culture,876}]}, {cast, [{mp_out,48},{cd,55},{att_area,2}]}, {shortime, []}, {lastime, [{8,lose_add_self,0.2},{8,last_crit,0.2}]}, {base_att, 1}];
				3 ->
					[{condition, [{lv,46},{coin,139000},{culture,1196}]}, {cast, [{mp_out,48},{cd,50},{att_area,2}]}, {shortime, [{crit,0.2}]}, {lastime, [{8,lose_add_self,0.2},{8,last_crit,0.2}]}, {base_att, 1}];
				4 ->
					[{condition, [{lv,49},{coin,175000},{culture,1610}]}, {cast, [{mp_out,48},{cd,45},{att_area,2}]}, {shortime, []}, {lastime, [{8,lose_add_self,0.2},{8,last_crit,0.2}]}, {base_att, 1}];
				5 ->
					[{condition, [{lv,52},{coin,220000},{culture,2530}]}, {cast, [{mp_out,48},{cd,40},{att_area,2}]}, {shortime, []}, {lastime, [{8,lose_add_self,0.2},{8,last_crit,0.2}]}, {base_att, 1}];
				_ ->
					[]
			end
	};

get(25407, SkillLv) ->
	#ets_skill{
		id = 25407,
		name = <<"润土术">>,
		career = 5,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,45},{coin,127000},{culture,1015}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,2}]}, {shortime, []}, {lastime, [{1800,physique,20},{1800,def,0.07}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,48},{coin,163000},{culture,1512}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,2}]}, {shortime, []}, {lastime, [{1800,physique,25},{1800,def,0.09}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,51},{coin,205000},{culture,2053}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,2}]}, {shortime, []}, {lastime, [{1800,physique,30},{1800,def,0.11}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,54},{coin,250000},{culture,3507}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,2}]}, {shortime, []}, {lastime, [{1800,physique,35},{1800,def,0.13}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,57},{coin,304000},{culture,5615}]}, {cast, [{mp_out,0.2},{cd,15},{att_area,2}]}, {shortime, []}, {lastime, [{1800,physique,40},{1800,def,0.15}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25408, SkillLv) ->
	#ets_skill{
		id = 25408,
		name = <<"泰山压顶">>,
		career = 5,
		mod = 1,
		type = 1,
		obj = 2,
		area = 3,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,50},{coin,190000},{culture,1754}]}, {cast, [{mp_out,50},{cd,9},{att_area,2}]}, {shortime, [{slash,[0.12,250]}]}, {lastime, []}, {base_att, 1.35}];
				2 ->
					[{condition, [{lv,54},{coin,250000},{culture,3507}]}, {cast, [{mp_out,55},{cd,9},{att_area,2}]}, {shortime, [{slash,[0.14,300]}]}, {lastime, []}, {base_att, 1.35}];
				3 ->
					[{condition, [{lv,58},{coin,322000},{culture,6526}]}, {cast, [{mp_out,60},{cd,9},{att_area,2}]}, {shortime, [{slash,[0.16,350]}]}, {lastime, []}, {base_att, 1.35}];
				4 ->
					[{condition, [{lv,62},{coin,398000},{culture,8475}]}, {cast, [{mp_out,65},{cd,9},{att_area,2}]}, {shortime, [{slash,[0.18,400]}]}, {lastime, []}, {base_att, 1.35}];
				5 ->
					[{condition, [{lv,66},{coin,488000},{culture,9488}]}, {cast, [{mp_out,70},{cd,9},{att_area,2}]}, {shortime, [{slash,[0.2,450]}]}, {lastime, []}, {base_att, 1.35}];
				_ ->
					[]
			end
	};

get(25409, SkillLv) ->
	#ets_skill{
		id = 25409,
		name = <<"飞沙走石">>,
		career = 5,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 2,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,55},{coin,268000},{culture,4243}]}, {cast, [{mp_out,30},{cd,60},{att_area,2}]}, {shortime, []}, {lastime, [{3,dizzy,0}]}, {base_att, 0.1}];
				2 ->
					[{condition, [{lv,59},{coin,340000},{culture,6900}]}, {cast, [{mp_out,35},{cd,55},{att_area,2}]}, {shortime, []}, {lastime, [{3,dizzy,0}]}, {base_att, 0.1}];
				3 ->
					[{condition, [{lv,63},{coin,418000},{culture,8673}]}, {cast, [{mp_out,40},{cd,50},{att_area,2}]}, {shortime, []}, {lastime, [{3,dizzy,0}]}, {base_att, 0.1}];
				4 ->
					[{condition, [{lv,67},{coin,513000},{culture,9804}]}, {cast, [{mp_out,45},{cd,45},{att_area,2}]}, {shortime, []}, {lastime, [{3,dizzy,0}]}, {base_att, 0.1}];
				5 ->
					[{condition, [{lv,71},{coin,617000},{culture,11258}]}, {cast, [{mp_out,50},{cd,40},{att_area,2}]}, {shortime, []}, {lastime, [{3,dizzy,0}]}, {base_att, 0.1}];
				_ ->
					[]
			end
	};

get(25410, SkillLv) ->
	#ets_skill{
		id = 25410,
		name = <<"地动山摇">>,
		career = 5,
		mod = 2,
		type = 1,
		obj = 2,
		area = 3,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,60},{coin,358000},{culture,7679}]}, {cast, [{mp_out,80},{cd,6},{att_area,2}]}, {shortime, []}, {lastime, [{5,last_def,0.08}]}, {base_att, 0.82}];
				2 ->
					[{condition, [{lv,64},{coin,438000},{culture,8963}]}, {cast, [{mp_out,85},{cd,6},{att_area,2}]}, {shortime, []}, {lastime, [{5,last_def,0.11}]}, {base_att, 0.84}];
				3 ->
					[{condition, [{lv,68},{coin,538000},{culture,10244}]}, {cast, [{mp_out,90},{cd,6},{att_area,2}]}, {shortime, []}, {lastime, [{5,last_def,0.14}]}, {base_att, 0.86}];
				4 ->
					[{condition, [{lv,72},{coin,644000},{culture,11984}]}, {cast, [{mp_out,95},{cd,6},{att_area,2}]}, {shortime, []}, {lastime, [{5,last_def,0.17}]}, {base_att, 0.88}];
				5 ->
					[{condition, [{lv,76},{coin,758000},{culture,16170}]}, {cast, [{mp_out,100},{cd,6},{att_area,2}]}, {shortime, []}, {lastime, [{5,last_def,0.20}]}, {base_att, 0.9}];
				_ ->
					[]
			end
	};

get(25411, SkillLv) ->
	#ets_skill{
		id = 25411,
		name = <<"山崩地裂">>,
		career = 5,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,65},{coin,463000},{culture,9236}]}, {cast, [{mp_out,60},{cd,9},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 1.41}];
				2 ->
					[{condition, [{lv,70},{coin,590000},{culture,10844}]}, {cast, [{mp_out,63},{cd,9},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 1.42}];
				3 ->
					[{condition, [{lv,75},{coin,728000},{culture,15253}]}, {cast, [{mp_out,69},{cd,9},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 1.43}];
				4 ->
					[{condition, [{lv,80},{coin,883000},{culture,18832}]}, {cast, [{mp_out,72},{cd,9},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 1.44}];
				5 ->
					[{condition, [{lv,85},{coin,1053000},{culture,24197}]}, {cast, [{mp_out,75},{cd,9},{att_area,2}]}, {shortime, []}, {lastime, []}, {base_att, 1.45}];
				_ ->
					[]
			end
	};

get(25601, SkillLv) ->
	#ets_skill{
		id = 25601,
		name = <<"火神祝福">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{5,goods_last_att_add,[50,10,15,0]}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{5,goods_last_att_add,[100,10,15,0]}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{5,goods_last_att_add,[150,10,15,0]}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{5,goods_last_att_add,[200,10,15,0]}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{5,goods_last_att_add,[250,10,15,0]}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25602, SkillLv) ->
	#ets_skill{
		id = 25602,
		name = <<"水神祝福">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{6,goods_last_add_mp,[40,10,15,2]}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{6,goods_last_add_mp,[80,10,15,2]}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{6,goods_last_add_mp,[120,10,15,2]}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{6,goods_last_add_mp,[160,10,15,2]}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{6,goods_last_add_mp,[200,10,15,2]}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25603, SkillLv) ->
	#ets_skill{
		id = 25603,
		name = <<"木神祝福">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{6,goods_last_add_hp,[50,10,15,2]}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{6,goods_last_add_hp,[150,10,15,2]}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{6,goods_last_add_hp,[250,10,15,2]}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{6,goods_last_add_hp,[350,10,15,2]}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{6,goods_last_add_hp,[450,10,15,2]}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25604, SkillLv) ->
	#ets_skill{
		id = 25604,
		name = <<"土神祝福">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{5,goods_bounce_reduce,[25,10,15,0]}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{5,goods_bounce_reduce,[50,10,15,0]}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{5,goods_bounce_reduce,[75,10,15,0]}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{5,goods_bounce_reduce,[100,10,15,0]}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{5,goods_bounce_reduce,[125,10,15,0]}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(25605, SkillLv) ->
	#ets_skill{
		id = 25605,
		name = <<"金神祝福">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{5,goods_bounce,[0.01,10,15,0]}]}, {base_att, 0}];
				2 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{5,goods_bounce,[0.02,10,15,0]}]}, {base_att, 0}];
				3 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{5,goods_bounce,[0.03,10,15,0]}]}, {base_att, 0}];
				4 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{5,goods_bounce,[0.04,10,15,0]}]}, {base_att, 0}];
				5 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,6},{att_area,0}]}, {shortime, []}, {lastime, [{5,goods_bounce,[0.05,10,15,0]}]}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(90004, SkillLv) ->
	#ets_skill{
		id = 90004,
		name = <<"千里冰封">>,
		career = 7,
		mod = 1,
		type = 1,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 1,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,1},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(90005, SkillLv) ->
	#ets_skill{
		id = 90005,
		name = <<"燃烧">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(90006, SkillLv) ->
	#ets_skill{
		id = 90006,
		name = <<"火神之刃">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 2,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(90007, SkillLv) ->
	#ets_skill{
		id = 90007,
		name = <<"火神之盾">>,
		career = 6,
		mod = 1,
		type = 1,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(90008, SkillLv) ->
	#ets_skill{
		id = 90008,
		name = <<"连斩">>,
		career = 7,
		mod = 1,
		type = 2,
		obj = 1,
		area = 0,
		area_obj = 0,
		assist_type = 0,
		limit_action = 0,
		hate = 0,
		data = 
			case SkillLv of
				1 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				2 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				3 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				4 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				5 ->
					[{condition, [{lv,0},{coin,0},{culture,0}]}, {cast, [{mp_out,0},{cd,0},{att_area,0}]}, {shortime, []}, {lastime, []}, {base_att, 0}];
				_ ->
					[]
			end
	};

get(_SkillId, _SkillLv) ->
	[].

