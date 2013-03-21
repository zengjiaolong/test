%%%--------------------------------------
%%% @Module  : lib_td
%%% @Author  : ygzj
%%% @Created : 2011.05.05
%%% @Description:塔防相关处理
%%%--------------------------------------
-module(lib_td).
-compile(export_all).
-include("common.hrl").
-include("record.hrl"). 

%% 查询玩家镇妖功勋
get_hor_td(PlayerId) ->
	case db_agent:get_hor_td(PlayerId) of
		[] ->
			0;
		null ->
			0;
		undefined ->
			0;
		Hor when is_integer(Hor)->
			Hor;
		_ ->
			0
	end.

%% 镇妖功勋消耗
cost_hor_td(Uid, Cost) ->
	case db_agent:get_hor_td(Uid) of
		[] ->
			false;
		Hor when Hor < abs(Cost) ->
			false;
		Hor ->
			db_agent:update_hor_td(Uid, abs(Cost), sub),
			Hor - abs(Cost)
	end.	

%%增加或更新镇妖台单人记录（包括总功勋）
set_td_single(Att_num, G_name, Nick, Career, Realm, Uid, Hor_td, Mgc_td, Hor_add) ->
	case db_agent:get_td_single(Uid) of
		[] ->
			db_agent:add_td_single(Att_num, G_name, Nick, Career, Realm, Uid, Hor_td, Mgc_td, Hor_add);
		[Att_num_rec, Hor_td_rec, Mgc_td_rec, Hor_ttl] ->
			if
				Hor_td > Hor_td_rec orelse 
					(Hor_td =:= Hor_td_rec andalso Att_num > Att_num_rec) orelse
					(Hor_td =:= Hor_td_rec andalso Att_num =:= Att_num_rec andalso Mgc_td > Mgc_td_rec) ->
						db_agent:update_td_single(Att_num, G_name, Hor_td, Mgc_td, Hor_ttl + Hor_add, Uid);
				true ->
					if
						Hor_add =/= 0 ->
							db_agent:update_hor_td(Uid, Hor_add, add);
						true ->
							skip
					end
			end;
		_ ->
			skip
	end.

%%增加或更新镇妖台多人记录
set_td_multi(Att_num, Uids, Hor_td, Mgc_td, UidList) ->
	case db_agent:get_td_multi(Uids) of
		[] ->
			NickList = lists:foldl(fun({Uid}, NickSum) ->
										   case db_agent:get_player_nick(Uid) of
											   null ->
												   NickSum;
											   undefined ->
												   NickSum;
											   Nick ->
%% ?DEBUG("TD____~p___/",[Nick]),
%% ?DEBUG("TD____~p___/",[binary_to_list(Nick)]),
												   NickSum ++ io_lib:format(" ~s ",[binary_to_list(Nick)])
										   end
								   end,
								   [], UidList),
%% 			Nicks = util:term_to_string(NickList),
			db_agent:add_td_multi(Att_num, NickList, Uids, Hor_td, Mgc_td);
		[Att_num_rec, Hor_td_rec, Mgc_td_rec] ->
			if
				Hor_td > Hor_td_rec orelse 
					(Hor_td =:= Hor_td_rec andalso Att_num > Att_num_rec) orelse
					(Hor_td =:= Hor_td_rec andalso Att_num =:= Att_num_rec andalso Mgc_td > Mgc_td_rec) ->
						db_agent:update_td_multi(Att_num, Uids, Hor_td, Mgc_td); 
				true ->
					skip
			end
	end.

get_exp(Hor, MapType) ->
	case MapType of
		998 ->
			0;
		999 ->
			round(500 * math:pow(Hor * 5000, 0.45))
	end.

%% get_spr(Hor) ->
%% 	Hor * 500.

%%魔力开销 get_cost Cmd为 43005召唤/修复，43006升级
get_cost(Cmd, Def, Map_type) ->
	case Cmd of
		43005 -> data_td:opt_mon_cost(Def, Map_type);
		_ -> data_td:up_mon_cost(Def, Map_type)
	end.

%%是否防御怪
is_def(MonId) ->
	MonId >= 46901 andalso MonId =< 46932.

get_mon_list(Att_num, Scene_id) ->
	[X, Y] = 
		case random:uniform(3) of
			1 ->
				[24, 14];
			2 ->
				[7, 34];
			_ ->
				[41, 34]
		end,
	case data_td:get_mon_list(Att_num, Scene_id) of
		error ->
			error;
		[{MonId1,MonNum1}, {MonId2,MonNum2}] ->
			[{MonId1, X, Y, MonNum1},{MonId2, X, Y, MonNum2}];
		[{MonId1,MonNum1}] ->
			[{MonId1, X, Y, MonNum1}];
		_ ->
			error
	end.

get_def_list(Def, Map_type) ->
	[X, Y] = [25, 45],
	[data_td:get_def_mid(Def, Map_type), X, Y, 1].



%% 跳波后经验灵力返回计算
count_skip_exp_spi(Vip,Exp_mult,Spi_mult,Rexp,Rspi) ->
	if
		%%有vip 有经验符 有灵力符
		Vip > 0 andalso Exp_mult > 1 andalso Spi_mult > 1 ->
			if
				Vip == 1 orelse Vip == 4 ->
					case Exp_mult of
						2 -> Addexp = Rexp * 2;
						1.5 -> Addexp = Rexp * 1.8
					end,
					case Spi_mult  of
						2 -> Addspi = Rspi * 1.7;
						1.5 -> Addspi = Rspi * 1.5
					end;
				Vip == 2 ->
					case Exp_mult of
						2 -> Addexp = Rexp * 2.1;
						1.5 -> Addexp = Rexp * 1.9
					end,
					case Spi_mult of
						2 -> Addspi = Rspi * 1.8;
						1.5 -> Addspi = Rspi * 1.6
					end;
				true -> %%Vip == 3
					case Exp_mult of
						2 -> Addexp = Rexp * 2.2;
						1.5 -> Addexp = Rexp * 2
					end,
					case Spi_mult of
						2 -> Addspi = Rspi * 2;
						1.5 -> Addspi = Rspi * 1.7
					end
			end;
		%% 有vip 有经验符
		Vip > 0 andalso Exp_mult > 1 ->
			if
		  		Vip == 1 orelse Vip == 4 ->
					case Exp_mult of
						2 -> Addexp = Rexp * 2;
						1.5 -> Addexp = Rexp * 1.8
					end,
					Addspi = Rspi;
				Vip == 2 ->
					case Exp_mult of
						2 -> Addexp = Rexp * 2.1;
						1.5 -> Addexp = Rexp * 1.9
					end,
					Addspi = Rspi;
				true -> %%Vip == 3
					case Exp_mult of
						2 -> Addexp = Rexp * 2.2;
						1.5 -> Addexp = Rexp * 2
					end,
					Addspi = Rspi
			end;
		%% 有vip 有灵力符
		Vip > 0 andalso Spi_mult > 1 ->
			if
				Vip == 1 orelse Vip == 4 ->
					Addexp = Rexp,
					case Spi_mult  of
						2 -> Addspi = Rspi * 1.7;
						1.5 -> Addspi = Rspi * 1.5
					end;
				Vip == 2 ->
					Addexp = Rexp,
					case Spi_mult of
						2 -> Addspi = Rspi * 1.8;
						1.5 -> Addspi = Rspi * 1.6
					end;
				true -> %%Vip == 3
					Addexp = Rexp,
					case Spi_mult of
						2 -> Addspi = Rspi * 2;
						1.5 -> Addspi = Rspi * 1.7
					end
			end; 
		%% 有经验符 有灵力符
		Exp_mult > 1 andalso Spi_mult > 1 ->
			case Exp_mult of
				2 -> Addexp = Rexp * 2;
				1.5 -> Addexp = Rexp * 1.5
			end,
			case Spi_mult of
				2 -> Addspi = Rspi * 2;
				1.5 -> Addspi = Rspi * 1.5
			end;
		Exp_mult > 1 ->
			case Exp_mult of
				2 -> Addexp = Rexp * 2;
				1.5 -> Addexp = Rexp * 1.5
			end,
			Addspi = Rspi;
		Spi_mult > 1 ->
			Addexp = Rexp,
			case Spi_mult of
				2 -> Addspi = Rspi * 2;
				1.5 -> Addspi = Rspi * 1.5
			end;
		Vip > 0 -> %%只有vip
			if
				Vip == 1 orelse Vip == 4 ->
					Addexp = Rexp * 1.5,
					Addspi = Rspi * 1.2;
				Vip == 2 ->
					Addexp = Rexp * 1.5,
					Addspi = Rspi * 1.3;
				true -> %%vip 半年
					Addexp = Rexp * 1.5,
					Addspi = Rspi * 1.5
			end;
		true ->
			Addexp = Rexp,
			Addspi = Rspi
	end,
	[trunc(Addexp),trunc(Addspi)].

