%% Author: zhj
%% Created: 2011.07.15
%% Description:training
-module(data_training).

%%
%% Include files
%%


%%
%% Exported Functions
%%
-compile(export_all).

%%波数对应怪物刷新坐标
get_mon_xy(Num)->
	case Num of 
		1 ->[12,15];
		2 ->[15,17];
		3 ->[13,21];
		4 ->[11,21];
		5 ->[9,17];
		_ ->[12,18]
	end.
		
		
%%等级对应刷新怪物列表
get_mon_list(Att_num , Lv)->
	if
		Lv >= 30 andalso Lv =< 39 ->
			if
				Att_num >= 1 andalso Att_num =< 15 ->
					[41057,41057,41057,41057,41057];
				Att_num >= 16 andalso Att_num =< 30 ->
					[41058,41058,41058,41058,41058];
				Att_num >= 31 andalso Att_num =< 45 ->
					[41059,41059,41059,41059,41059];
				Att_num >= 46 andalso Att_num =< 60 ->
					[41060,41060,41060,41060,41060];
				Att_num >= 61 andalso Att_num =< 75 ->
					[41061,41061,41061,41061,41061];
				true ->
					[41092]
			end;
		Lv >= 40 andalso Lv =< 49 ->
			if
				Att_num >= 1 andalso Att_num =< 15 ->
					[41062,41062,41062,41062,41062];
				Att_num >= 16 andalso Att_num =< 30 ->
					[41063,41063,41063,41063,41063];
				Att_num >= 31 andalso Att_num =< 45 ->
					[41064,41064,41064,41064,41064];
				Att_num >= 46 andalso Att_num =< 60 ->
					[41065,41065,41065,41065,41065];
				Att_num >= 61 andalso Att_num =< 75 ->
					[41066,41066,41066,41066,41066];
				true ->
					[41093]
			end;
		Lv >= 50 andalso Lv =< 59 ->
			if
				Att_num >= 1 andalso Att_num =< 15 ->
					[41067,41067,41067,41067,41067];
				Att_num >= 16 andalso Att_num =< 30 ->
					[41068,41068,41068,41068,41068];
				Att_num >= 31 andalso Att_num =< 45 ->
					[41069,41069,41069,41069,41069];
				Att_num >= 46 andalso Att_num =< 60 ->
					[41070,41070,41070,41070,41070];
				Att_num >= 61 andalso Att_num =< 75 ->
					[41071,41071,41071,41071,41071];
				true ->
					[41094]
			end;
		Lv >= 60 andalso Lv =< 69 ->
			if
				Att_num >= 1 andalso Att_num =< 15 ->
					[41072,41072,41072,41072,41072];
				Att_num >= 16 andalso Att_num =< 30 ->
					[41073,41073,41073,41073,41073];
				Att_num >= 31 andalso Att_num =< 45 ->
					[41074,41074,41074,41074,41074];
				Att_num >= 46 andalso Att_num =< 60 ->
					[41075,41075,41075,41075,41075];
				Att_num >= 61 andalso Att_num =< 75 ->
					[41076,41076,41076,41076,41076];
				true ->
					[41095]
			end;
		Lv >= 70 andalso Lv =< 79 ->
			if
				Att_num >= 1 andalso Att_num =< 15 ->
					[41077,41077,41077,41077,41077];
				Att_num >= 16 andalso Att_num =< 30 ->
					[41078,41078,41078,41078,41078];
				Att_num >= 31 andalso Att_num =< 45 ->
					[41079,41079,41079,41079,41079];
				Att_num >= 46 andalso Att_num =< 60 ->
					[41080,41080,41080,41080,41080];
				Att_num >= 61 andalso Att_num =< 75 ->
					[41081,41081,41081,41081,41081];
				true ->
					[41096]
			end;
		Lv >= 80 andalso Lv =< 89 ->
			if
				Att_num >= 1 andalso Att_num =< 15 ->
					[41082,41082,41082,41082,41082];
				Att_num >= 16 andalso Att_num =< 30 ->
					[41083,41083,41083,41083,41083];
				Att_num >= 31 andalso Att_num =< 45 ->
					[41084,41084,41084,41084,41084];
				Att_num >= 46 andalso Att_num =< 60 ->
					[41085,41085,41085,41085,41085];
				Att_num >= 61 andalso Att_num =< 75 ->
					[41086,41086,41086,41086,41086];
				true ->
					[41097]
			end;
		true ->
			if
				Att_num >= 1 andalso Att_num =< 15 ->
					[41087,41087,41087,41087,41087];
				Att_num >= 16 andalso Att_num =< 30 ->
					[41088,41088,41088,41088,41088];
				Att_num >= 31 andalso Att_num =< 45 ->
					[41089,41089,41089,41089,41089];
				Att_num >= 46 andalso Att_num =< 60 ->
					[41090,41090,41090,41090,41090];
				Att_num >= 61 andalso Att_num =< 75 ->
					[41091,41091,41091,41091,41091];
				true ->
					[41098]
			end
	end.

%% 试炼副本打怪经验
get_training_mon_exp_spi(Lv,MonTypeId) ->
	Exp =
	case goods_util:level_to_step(Lv) of
		4 -> 
			if 
				MonTypeId == 41092 ->
					12000;
				true ->
					1200
			end;
		5 -> 
			if
				MonTypeId == 41093 ->
					32000;
				true ->
					2500
			end;
		6 -> 
			if
				MonTypeId == 41094 ->
					57600;
				true ->
					6000
			end;
		7 -> 
			if
				MonTypeId == 41095 ->
					85000;
				true ->
					8500
			end;
		8 -> 
			if
				MonTypeId == 41096 ->
					100000;
				true ->
					12000
			end;
		9 -> 
			if
				MonTypeId == 41097 ->
					110000;
				true ->
					12500
			end;
		10 -> 
			if
				MonTypeId == 41098 ->
					220000;
				true ->
					13500
			end;
		_ -> 1
	end,
	Spi = round(Exp / 1.6),
	[Exp,Spi].

		

