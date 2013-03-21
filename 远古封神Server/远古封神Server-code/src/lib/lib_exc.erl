%%%--------------------------------------
%%% @Module  : lib_exc
%%% @Author  : ygzj
%%% @Created : 2010.12.01
%%% @Description:凝神修炼相关处理
%%%--------------------------------------
-module(lib_exc).
-export([ 
		 start_exc/5,
		 finish_exc/1, 
		 set_exc_status/2, 
		 set_exc_prepay/3, 
		 reduce_exc_prepay/5,
		 get_exc_prepay/4,
		 refresh_tttime/4,
		 refresh_tttime_open/5,
		 refresh_tttime/5,
		 get_tttime/4,
		 exc_login/2,
		 exc_devliver/2
		]).
-include("common.hrl").
-include("record.hrl"). 

%%开始凝神修炼
start_exc(PlayerStatus, Ty, Time_m, End_time, continue_exc) ->
	Status1 = set_exc_status(PlayerStatus, 7),
	{ok, BinDataBC} = pt_12:write(12090, [Status1#player.id, 7]),
	%%采用广播通知，附近玩家都能看到
	mod_scene_agent:send_to_area_scene(Status1#player.scene, Status1#player.x, Status1#player.y, BinDataBC),
	Diftime = End_time - util:unixtime(),
	if 
		Diftime rem 60 < 2 -> 
			erlang:send_after(60 * 1000, self(), {'EXC_ING', Ty, Time_m, End_time});
		true ->
			erlang:send_after((Diftime rem 60) * 1000, self(), {'EXC_ING_EX', Ty, Time_m, End_time})
	end,
	%%玩家凝神同步离线累积经验时间
	lib_offline_award:update_offline_exc(PlayerStatus#player.id),
	{ok, Status1};
	
start_exc(PlayerStatus, Ty, Time_m, Cost, start_exc) ->
	Nowtime = util:unixtime(),
	%%每天前三(第0,1,2)秒作为一个标识位，不能作为开始时间
	This_end_time =
		if 
			(Nowtime + 8*3600) rem 86400 < 3 ->
				Nowtime + 3 + Time_m * 60;
			true ->
				Nowtime + Time_m * 60
		end,
	case Ty of
		1 ->
			Pre_pay_coin = 0,
			Pre_pay_gold = Cost,
			Costtype = gold;
		2 -> 
			Pre_pay_coin = Cost,
			Pre_pay_gold = 0,
			Costtype = coin;			
		_ ->	
			Pre_pay_coin = 0,
			Pre_pay_gold = 0,
			Costtype = coin		
	end,
	Pid = PlayerStatus#player.id,
	Cost_abs = abs(Cost),
	Status1 = lib_goods:cost_money(PlayerStatus, Cost_abs, Costtype, 3313),
    {ok, BinData1} = pt_33:write(33001, [1, Status1#player.gold, Status1#player.coin, Status1#player.bcoin, Time_m]),
    lib_send:send_to_sid(Status1#player.other#player_other.pid_send, BinData1),
	case db_agent:ver_exc_record(Pid) of
		Pid ->
			db_agent:set_exc_info(Pid, Ty, This_end_time, Time_m, Pre_pay_coin, Pre_pay_gold);
		_ ->
			db_agent:add_exc_info(Pid, Ty, This_end_time, Time_m, Pre_pay_coin, Pre_pay_gold)
	end,
	start_exc(Status1, Ty, Time_m, This_end_time, continue_exc).


%%完成凝神修炼状态
finish_exc(Status) ->
	Pid = Status#player.id,
	Nowtime = util:unixtime(),
	[_Exc_status, Begtime, This_end_time, Exc_time, Total_exc_time, _Pre_pay_coin, _Pre_pay_gold, Llout_time]= db_agent:get_exc_rec(Pid),
	Exc_time_s =
		case (Begtime + 8*3600) rem 86400 of
			1 ->
				Total_exc_time * 60;
			_ ->
				Exc_time * 60
		end,
	Tttime = refresh_tttime(Pid, Nowtime, Begtime, Exc_time_s, Total_exc_time),
	spawn(fun()-> db_agent:add_exc_log(Pid, Exc_time, Begtime, Llout_time, This_end_time, Tttime, Exc_time_s, 0) end),
	spawn(fun()-> db_agent:clear_exc_info(Pid, This_end_time) end),
	{ok, BinData} = pt_33:write(33003, <<>>),
  	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	{ok, BinDataBC} = pt_12:write(12090, [Pid, 0]),
	%%采用广播通知，附近玩家都能看到
	mod_scene_agent:send_to_area_scene(Status#player.scene, Status#player.x, Status#player.y, BinDataBC),
	set_exc_status(Status, 0).
	

%%设置凝神修炼状态
set_exc_status(PlayerStatus, Exc_status) ->
	case Exc_status of
		0 ->%% 由凝神变成正常
			case PlayerStatus#player.other#player_other.goods_buff#goods_cur_buff.peach_mult of
				1 ->
					PlayerStatus#player{status = Exc_status, other = PlayerStatus#player.other#player_other{exc_status = Exc_status}};
				_ ->
					PlayerStatus#player{status = 6, other = PlayerStatus#player.other#player_other{exc_status = Exc_status}}
			end;
		7 ->
			case PlayerStatus#player.other#player_other.goods_buff#goods_cur_buff.peach_mult of
				1 ->
					PlayerStatus#player{status = Exc_status, other = PlayerStatus#player.other#player_other{exc_status = Exc_status}};
				_IsPeach when PlayerStatus#player.scene =:= 300 ->
					NewPlayerStatus = PlayerStatus#player{status = Exc_status, other = PlayerStatus#player.other#player_other{exc_status = Exc_status}},
					lib_peach:handle_peach_exp_spir(NewPlayerStatus);
				_ ->
					PlayerStatus#player{status = Exc_status, other = PlayerStatus#player.other#player_other{exc_status = Exc_status}}
			end
	end.

%%设置凝神修炼预付款
set_exc_prepay(Playerid, Type, Prepay) ->
	case Type of 
		1 -> Type1 = gold;
		2 -> Type1 = coin;
		_ -> Type1 = Type
	end,
	case Type1 of
		gold -> db_agent:set_exc_prepay_gold(Playerid, Prepay);
		coin -> db_agent:set_exc_prepay_coin(Playerid, Prepay);
		_ -> ok
	end.

%%扣除凝神修炼预付款
reduce_exc_prepay(Playerid, Type, Reduce, Pgold, Pcoin) ->
	case Type of 
		1 -> Type1 = gold;
		2 -> Type1 = coin;
		_ -> Type1 = Type
	end,	
	case Type1 of
		gold -> 
			Reduce_amount = Pgold - Reduce,
			db_agent:set_exc_prepay_gold(Playerid, Reduce_amount);
		coin -> 
			Reduce_amount = Pcoin - Reduce,
			db_agent:set_exc_prepay_coin(Playerid, Reduce_amount);
		_ -> ok
	end.

%%获取凝神修炼预付款
get_exc_prepay(_Playerid, Type, Pgold, Pcoin) ->
	case Type of 
		1 -> Type1 = gold;
		2 -> Type1 = coin;		
		bcoin -> Type1 = coin;
		_ -> Type1 = Type
	end,	
	case Type1 of
		gold -> Pgold;
		coin -> Pcoin;
		_ -> ok
	end.

%%计算并刷新累计游戏时间（打开面板且当时【不】在修炼中）
refresh_tttime(PlayerId, Nowtime, Cp_time, TTtime) ->
	if 
		(Nowtime + 8*3600) div 86400 > (Cp_time + 8*3600) div 86400 ->
			db_agent:set_exc_toltime(PlayerId, 0),
			0;
		true ->
			TTtime
	end.

%%计算并刷新累计游戏时间（打开面板且当时【正】在修炼中）
refresh_tttime_open(PlayerId, Nowtime, Lc_time, Exc_time, TTtime) ->
	case (Lc_time + 8*3600) rem 86400 of
		1 ->
			((Nowtime + 8*3600) rem 86400 + Exc_time) div 60;
		_ ->
			if 
				(Nowtime + 8*3600) div 86400 > (Lc_time + 8*3600) div 86400 ->
					[Exc_status, _This_beg_time, This_end_time, _This_exc_time, _Total_exc_time, _Pre_pay_coin, _Pre_pay_gold, _Last_logout_time] = db_agent:get_exc_rec(PlayerId),
					NewTTtime = (Nowtime + 8*3600) rem 86400 div 60,
					New_exc_m = (This_end_time - Nowtime) div 60,
					db_agent:reset_exc(PlayerId, Nowtime, New_exc_m, NewTTtime),
					Diftime = (This_end_time - Nowtime) rem 60,
					if 
						Diftime < 2 -> 
							erlang:send_after(60 * 1000, self(), {'EXC_ING', Exc_status, New_exc_m, This_end_time});
						true ->
							erlang:send_after(Diftime * 1000, self(), {'EXC_ING_EX', Exc_status, New_exc_m, This_end_time})
					end,
					NewTTtime;
				true ->
					TTtime + Exc_time div 60
			end
	end.

%%计算并刷新累计游戏时间
refresh_tttime(PlayerId, Nowtime, Lc_time, Exc_time, TTtime) ->
	Exc_time_used = get_tttime(Nowtime, Lc_time, Exc_time, TTtime),
	db_agent:set_exc_toltime(PlayerId, Exc_time_used),
	Exc_time_used.

%%计算累计游戏时间
get_tttime(Nowtime, Lc_time, Exc_time, TTtime) ->
	case (Lc_time + 8*3600) rem 86400 of
		1 ->
			((Nowtime + 8*3600) rem 86400 + Exc_time) div 60;
		_ ->
			if 
				(Nowtime + 8*3600) div 86400 > (Lc_time + 8*3600) div 86400 ->
					(Nowtime + 8*3600) rem 86400 div 60;
				true ->
					TTtime + Exc_time div 60
			end
	end.

%%上线登陆计算
exc_login(Status, Nowtime) ->
	PlayerId = Status#player.id,
	case db_agent:get_exc_rec(PlayerId) of
		[] -> Status1 = Status;
		Exc_rec ->
		%%有修炼记录
			[Exc_status, This_beg_time, This_end_time, This_exc_time, Total_exc_time, _Pre_pay_coin, _Pre_pay_gold, Llout_time]= Exc_rec,
			Plv = Status#player.lv,
			if 
				Exc_status < 3 ->
				%%上次离线前正在修炼				
					if 
						This_end_time =< Nowtime  ->
						%% 离线期间完成修炼
							Exc_time_cl = This_end_time - Llout_time,
							Exc_time = 
								if
									(This_beg_time + 8*3600) rem 86400 =:= 1 ->
										Total_exc_time * 60;
									true ->
										if 
											Exc_time_cl div 60 > This_exc_time ->
												This_exc_time * 60;
											true ->
												Exc_time_cl
										end
								end,
							Exc_time_used =
								if
									(This_beg_time + 8*3600) rem 86400 =:= 1 ->
										(Exc_time + (This_end_time  + 8*3600) rem 86400) div 60;
									(Nowtime + 8*3600) div 86400 > (This_beg_time + 8*3600) div 86400 ->
										Reset_begtime = ((Nowtime + 8*3600) div 86400) * 86400 - 8*3600 +1,
										spawn(fun()->db_agent:set_exc_begtime(PlayerId, Reset_begtime)end),
										if 
											(Nowtime + 8*3600) div 86400 > (This_end_time  + 8*3600) div 86400 ->
												0;
											true ->
												(This_end_time + 8*3600) rem 86400 div 60
										end;
									true ->
										Total_exc_time + Exc_time div 60
								end,						
							spawn(fun()->db_agent:set_exc_toltime(PlayerId, Exc_time_used)end),
							spawn(fun()->db_agent:add_exc_log(PlayerId, This_exc_time, This_beg_time, Llout_time, This_end_time, Total_exc_time, Exc_time_used*60, 1)end),
							spawn(fun()->db_agent:clear_exc_info(PlayerId, This_end_time)end),
							{ok, BinData1} = pt_33:write(33003, <<>>),
  							lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData1),
							Status1 = set_exc_status(Status, 0);
						true ->
						%% 修炼尚未完成
%% 							Exc_time_cl = Nowtime - Llout_time,
%% 							Exc_time =
%% 								if 
%% 									Exc_time_cl div 60 > This_exc_time ->
%% 										This_exc_time * 60;
%% 									true ->
%% 										Exc_time_cl
%% 								end,
							Exc_time_con = This_end_time - Nowtime,
							Exc_time = 
								if
									Llout_time > This_beg_time ->
										Nowtime - Llout_time;
									true ->
										if
											(This_beg_time + 8*3600) rem 86400 =:= 1 ->
												Total_exc_time * 60;
											true ->
												Nowtime - Llout_time
										end
								end,
%% 							Exc_time_used = refresh_tttime(PlayerId, Nowtime, Llout_time, Exc_time, Total_exc_time),
%% 							db_agent:set_exc_logout_tm(PlayerId),
							Exc_time_used = get_tttime(Nowtime, This_beg_time, Exc_time, Total_exc_time),
							{ok, Status1} = start_exc(Status, Exc_status, This_exc_time, This_end_time, continue_exc),
							%% 继续修炼
							Ttol = This_exc_time,
	   						Tok = 24 * 60 - Exc_time_used,	
	   						Exp = data_exc:get_exc_gain(Exc_status, exp, Plv),
	   						Spr = data_exc:get_exc_gain(Exc_status, spr, Plv),
   							Costc = data_exc:get_exc_cost(coin, Plv) div 100,
   							Costg = data_exc:get_exc_cost(gold, Plv),
	   						Costcn = data_exc:get_exc_cost(coin, Plv+1) div 100,
	   						Costgn = data_exc:get_exc_cost(gold, Plv+1),   		
   							Spd10 = data_exc:get_exc_cost(speedup, Plv),
   							Spd60 = data_exc:get_exc_cost(speedup_hour, Plv),	    				
							{ok, BinData} = pt_33:write(33000, [Exc_status, Exc_time_con, Ttol, Exp, Spr, Tok, Costc, Costg, Costcn, Costgn, Spd10, Spd60, Status1#player.gold, Plv]),
   							lib_send:send_to_sid(Status1#player.other#player_other.pid_send, BinData)
					end,
					Lvn = Status1#player.lv,
					Exp_now = Status1#player.exp,
					Exp_up = data_exp:get(Plv),
					case Exc_status of
						1 ->
							Type = gold;
						2 ->
							Type = coin
					end,
					Exc_time_min =
						if
							Exc_time div 60 > This_exc_time ->
								This_exc_time;
							true ->
								Exc_time div 60
						end,
					%% 延迟15秒统计凝神时间
					erlang:send_after(15 * 1000, self(), {'EXC_CHECK_ACHIEVE', Exc_time_min}),
					Exp_min = data_exc:get_exc_gain(Type, exp, Lvn),
					Spr_min = data_exc:get_exc_gain(Type, spr, Lvn),				
					if
						Exp_min * Exc_time_min > Exp_up ->
							Exp_min_up = data_exc:get_exc_gain(Type, exp, Lvn + 1),
							Spr_min_up = data_exc:get_exc_gain(Type, spr, Lvn + 1),
							Up_time = (Exp_up - Exp_now) div Exp_min + 1,
							Exp_inc = Up_time * Exp_min + (Exc_time_min -Up_time) * Exp_min_up,
							Spr_inc = Up_time * Spr_min + (Exc_time_min -Up_time) * Spr_min_up;
						true ->
							Exp_inc = Exc_time_min * Exp_min,
							Spr_inc = Exc_time_min * Spr_min
					end,
					if
						Exp_inc > 10000 ->
							spawn(fun()->db_agent:add_exc_exp_log(PlayerId, This_beg_time, This_end_time, This_exc_time, Exc_time_min, Exp_inc)end);
						true ->
							ok
					end,
					%% 延迟2秒加经验和灵力
					erlang:send_after(2 * 1000, self(), {'EXC_ING_LOGIN', Exp_inc, Spr_inc});

%% 					case Status1#player.status of
%% 						0 ->
%% 							db_agent:add_exc_log(PlayerId, This_exc_time, This_beg_time, Llout_time, This_end_time, Total_exc_time, Exc_time),
%% 							db_agent:clear_exc_info(PlayerId),
%% 							{ok, BinData1} = pt_33:write(33003, <<>>),
%%   							lib_send:send_to_sid(Status1#player.other#player_other.pid_send, BinData1);
%% 						_ ->
%% 							ok
%% 					end;
				true -> Status1 = Status
			end
	end,
	Status1.
	
exc_devliver(PlayerStatus, Type) ->
	case lib_deliver:could_deliver(PlayerStatus) of
		ok ->
%% 			Scid = 
%% 				case PlayerStatus#player.realm of
%% 					3 -> 250;
%% 					2 -> 280;
%% 					_ -> 200
%% 				end,
%% 			RandomCount = random:uniform(5),
%% %% io:format("pp_exc_Scid_~p/~p ~n",[Scid, Scid]),
%% 			[X1,Y1] = 
%% 				case RandomCount of
%% 					5 -> [139,133];
%% 					4 -> [155,138];
%% 					3 -> [134,108];
%% 					2 -> [120,105];
%% 					_ -> [118,114]
%% 				end,
%% 			[X2,Y2] = 
%% 				case Scid of
%% 					200 -> [X1,Y1];
%% 					250 -> [X1-3,Y1-3];
%% 					280 -> [X1+1,Y1-1]
%% 				end,
%% 			X = X2 + random:uniform(5) - 3,
%% 			Y = Y2 + random:uniform(5) - 3,
			[Scid, X, Y] = get_devliver_coord(PlayerStatus, Type),
			{ok, BinData} = pt_12:write(12005, [Scid, X, Y, <<>>, lib_scene:get_res_id(Scid), 0, 0, 0]),
	  		lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
			%%告诉原场景的玩家你已经离开
			pp_scene:handle(12004, PlayerStatus, PlayerStatus#player.scene),
			put(change_scene_xy , [X, Y]),%%做坐标记录
			%%扣除元宝
			case Type of
				Value when Value =:= 2 orelse Value =:= 3 ->%%桃子，灵兽圣园要元宝
					PlayerStatus1 = lib_goods:cost_money(PlayerStatus, 5, gold, 3311);
				_ ->
					PlayerStatus1 = PlayerStatus
			end,
			%%更新玩家新坐标
	    	NewStatus = PlayerStatus1#player{scene = Scid, x = X, y = Y},	
			ValueList = [{scene,Scid},{x,X},{y,Y}],
			WhereList = [{id, NewStatus#player.id}],
	    	db_agent:mm_update_player_info(ValueList, WhereList),
			erlang:send_after(2000, self(), {'PEACH_SCENE_CHANGE'}),
	    	[1, NewStatus];
		Res ->
			[Res, PlayerStatus]
	end.

%%获取传送的场景id, x, y
get_devliver_coord(_PlayerStatus, Type) ->
	lib_peach:get_devliver_coord(Type).
%%以下方法不再用，直接传送到九霄(与蟠桃的一样了)
%% 	case Type of
%% 		1 ->
%% 			Scid = 
%% 				case PlayerStatus#player.realm of
%% 					3 -> 250;
%% 					2 -> 280;
%% 					_ -> 200
%% 				end,
%% %% 			RandomCount = random:uniform(5),
%% 			[X1,Y1] = [123,111],
%% %% 				case RandomCount of
%% %% 					5 -> [139,133];
%% %% 					4 -> [155,138];
%% %% 					3 -> [134,108];
%% %% 					2 -> [120,105];
%% %% 					_ -> [118,114]
%% %% 				end,
%% 			[X2,Y2] = 
%% 				case Scid of
%% 					200 -> [X1,Y1];
%% 					250 -> [X1-3,Y1-3];
%% 					280 -> [X1+1,Y1-1]
%% 				end,
%% 			X = X2 + random:uniform(5) - 3,
%% 			Y = Y2 + random:uniform(5) - 3,
%% 			[Scid, X, Y];
%% 		2 ->
%% 			lib_peach:get_devliver_coord(Type)
%% 	end.

			
