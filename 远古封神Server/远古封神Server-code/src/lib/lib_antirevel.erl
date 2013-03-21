%% Author: lzz
%% Created: 2010-11-23
%% Description: 防沉迷系统 身份证验证函数
-module(lib_antirevel).

%%
%% Include files
%%

-export([idnum_ver/1, 
		 get_logofftime/2, 
		 get_total_gametime/2, 
		 set_total_gametime/3, 
		 set_logout_time/3, 
		 add_infant/3]).

%%
%% API Functions
%%
%% -----------------------------------------------------------------
%% 29001 身份证验证
%% -----------------------------------------------------------------

idnum_ver(Idnum) ->
	Idnum_len = string:len(Idnum),
	if Idnum_len =:= 18 -> idnum_ver18(Idnum);
		true -> idnum_ver15(Idnum)
	end.

idnum_ver15(Idnum) -> 
	{Bir_day,[]} = string:to_integer(string:sub_string(Idnum, 7, 12)),
	{{Year, Month, Day}, {_Hour, _Min, _Sec}} = calendar:local_time(),
	if ((Year rem 100 + 100) * 10000 + Month * 100 + Day - Bir_day) div 10000 >= 18 -> {true,1};
	   true -> {true,2}
	end.
				
idnum_ver18(Idnum) ->
	Int_v1 = tool:to_integer(string:sub_string(Idnum, 1, 1)) * 7,
	Int_v2 = tool:to_integer(string:sub_string(Idnum, 2, 2)) * 9,
	Int_v3 = tool:to_integer(string:sub_string(Idnum, 3, 3)) * 10,
	Int_v4 = tool:to_integer(string:sub_string(Idnum, 4, 4)) * 5,
	Int_v5 = tool:to_integer(string:sub_string(Idnum, 5, 5)) * 8,
	Int_v6 = tool:to_integer(string:sub_string(Idnum, 6, 6)) * 4,
	Int_v7 = tool:to_integer(string:sub_string(Idnum, 7, 7)) * 2,
	Int_v8 = tool:to_integer(string:sub_string(Idnum, 8, 8)) * 1,
	Int_v9 = tool:to_integer(string:sub_string(Idnum, 9, 9)) * 6,
	Int_v10 = tool:to_integer(string:sub_string(Idnum, 10, 10)) * 3,
	Int_v11 = tool:to_integer(string:sub_string(Idnum, 11, 11)) * 7,
	Int_v12 = tool:to_integer(string:sub_string(Idnum, 12, 12)) * 9,
	Int_v13 = tool:to_integer(string:sub_string(Idnum, 13, 13)) * 10,
	Int_v14 = tool:to_integer(string:sub_string(Idnum, 14, 14)) * 5,
	Int_v15 = tool:to_integer(string:sub_string(Idnum, 15, 15)) * 8,
	Int_v16 = tool:to_integer(string:sub_string(Idnum, 16, 16)) * 4,
	Int_v17 = tool:to_integer(string:sub_string(Idnum, 17, 17)) * 2,

	case (Int_v1+ Int_v2+ Int_v3+ Int_v4+ Int_v5+ Int_v6+ Int_v7+ Int_v8+ Int_v9+ Int_v10+ Int_v11+ Int_v12+ Int_v13+ Int_v14+ Int_v15+ Int_v16+ Int_v17) rem 11 of
		0 -> Str_v18 = "1"; 
		1 -> Str_v18 = "0"; 
		2 -> Str_v18 = "X"; 
		3 -> Str_v18 = "9"; 
		4 -> Str_v18 = "8"; 
		5 -> Str_v18 = "7"; 
		6 -> Str_v18 = "6"; 
		7 -> Str_v18 = "5"; 
		8 -> Str_v18 = "4"; 
		9 -> Str_v18 = "3"; 
		10 -> Str_v18 = "2"
	end,
     
	Str_tmp = string:to_upper(string:sub_string(Idnum, 18, 18)),
	
	if Str_tmp =:= Str_v18  -> 
		   	{{Year, Month, Day}, {_Hour, _Min, _Sec}} = calendar:local_time(),
	   		Bir_day = tool:to_integer(string:sub_string(Idnum, 7, 14)),
	   		if (Year * 10000 + Month * 100 + Day - Bir_day) div 10000 >= 18 -> {true,1};
	   			true -> {true,2}
				end;
	   	true -> {false,3}
	end.

%% 读取账户上次离线时间（防沉迷）
get_logofftime(Sn, Accid) ->
		case db_agent:get_infant_time_byuser(Sn, Accid) of
			null  -> 0;
			[] -> 0;
			V ->V
		end.


%% 获取账户累计游戏时间（防沉迷）
get_total_gametime(Sn, Accid)->
	db_agent:get_gametime_byuser(Sn, Accid).
	
%% 设置账户累计游戏时间（防沉迷）
set_total_gametime(Sn, Accid, T_time)->
	db_agent:set_gametime_byuser(Sn, Accid, T_time).

	
%% 设置账户上次离线时间（防沉迷）
set_logout_time(Sn, Accid, L_time)->
	db_agent:set_last_logout_time_byuser(Sn, Accid, L_time).




%% 将未成年人身份证号码纳入防沉迷
add_infant(Sn, Accid, Last_login_time) ->
	This_game_time = util:unixtime() - Last_login_time,
	Tmp = db_agent:ver_accid(Sn, Accid),
%% 	T_time =
%% 		case db_agent:get_idcard_status(!!sn,Accid) of
%% 			3 -> 
%% 			 	db_agent:get_gametime_byuser(Accid) + This_game_time;
%% 			_ -> 
%% 				This_game_time
%% 		end,
	case Tmp of
		Accid -> 
				TT_time = db_agent:get_gametime_byuser(Sn, Accid) + This_game_time,
				db_agent:set_gametime_byuser(Sn, Accid, TT_time);
		_ -> L_time = util:unixtime(),			
				db_agent:add_idcard_num_acc(Sn, Accid, This_game_time, L_time)
	end.
