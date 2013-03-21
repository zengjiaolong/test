%%%--------------------------------------
%%% @Module  : pp_antirevel
%%% @Author  : lzz
%%% @Created : 2010.11.23
%%% @Description:  防沉迷功能
%%%--------------------------------------
-module(pp_antirevel).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%%处理防沉迷信息验证
handle(29000, Status, [Idcard_status, Idcard_num]) ->
	Accid = Status#player.accid,
	Sn = Status#player.sn,
	Idcard_Res =
		case Idcard_status of
			0 ->
    			{_, New_Id_status} = lib_antirevel:idnum_ver(Idcard_num),
    			case New_Id_status of
    				1 -> 
    					db_agent:set_idcard_status(Sn, Accid, New_Id_status);
    				2 ->
    					lib_antirevel:add_infant(Sn, Accid, Status#player.last_login_time), 
    					db_agent:set_idcard_status(Sn, Accid, New_Id_status);
					_ -> ok
				end,
				New_Id_status;
			1 ->
				db_agent:set_idcard_status(Sn, Accid, Idcard_status),
				Idcard_status;
			_ ->
				db_agent:set_idcard_status(Sn, Accid, Idcard_status),
				lib_antirevel:add_infant(Sn, Accid, Status#player.last_login_time),
				Idcard_status
		end,
    {ok, BinData} = pt_29:write(29000, Idcard_Res),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);


%%累计游戏时间查询
handle(29002, Status, eqtime) ->
	Accid = Status#player.accid,
	Sn = Status#player.sn,
	I_status = db_agent:get_idcard_status(Sn, Accid),
	L_logintime = Status#player.last_login_time,
	L_usetime = lib_antirevel:get_total_gametime(Sn, Accid),
	T_total_time = 3*3600 - (util:unixtime() - L_logintime + L_usetime),
    {ok, BinData} = pt_29:write(29002, [I_status, T_total_time]),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);

%%我未成年
handle(29003, Status, infant) ->
	Accid = Status#player.accid,
	Sn = Status#player.sn,
	case db_agent:get_idcard_status(Sn, Accid) of
		0 -> 
			db_agent:set_idcard_status(Sn, Accid, 3),
			db_agent:add_idcard_num_acc(Sn, Accid, 0, util:unixtime());
		_ ->
			ok
	end;

handle(_Cmd, _Status, _Data) ->
%%     ?DEBUG("pp_antirevel no match", []),
    {error, "pp_antirevel no match"}.
