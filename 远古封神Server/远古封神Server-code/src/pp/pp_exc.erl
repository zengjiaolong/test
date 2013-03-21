%%%--------------------------------------
%%% @Module  : pp_exc
%%% @Author  : lzz
%%% @Created : 2010.11.30
%%% @Description:  凝神修炼功能
%%%--------------------------------------
-module(pp_exc).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%%打开凝神修炼
handle(33000, Status, _) ->
	Plv = Status#player.lv,
	Pid = Status#player.id,
	if 
		Plv < 26 ->
			{ok, BinData} = pt_33:write(33000, [4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
    		lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
		true -> 
			Loc_exc = lib_scene:ver_location(Status#player.scene, [Status#player.x, Status#player.y], exc),
			case db_agent:get_exc_rec(Pid) of
	    		[] ->
					if 
			  			Loc_exc =:= false -> %%判断角色位置
							[Sta, Tleft, Ttol, Exp, Spr, Tok] = [0, 0, 0, 0, 0, 0],
							OpenWindow = 0;
						true ->
							Sta = 3,
							Tleft = 0,
							Ttol = 0,
							Tok = 24 * 60,
%% %% ?DEBUG("handle_33000_1_~p/~p ~n",[Ttol, db_agent:get_exc_rec(Pid)]),
							Exp = data_exc:get_exc_gain(coin, exp, Plv),
	    					Spr = data_exc:get_exc_gain(coin, spr, Plv),
							OpenWindow = 1
					end;
				Exc_rec ->
					%%有修炼记录
					[Sta, This_beg_time, This_end_time, This_exc_time, Total_exc_time, _Pre_pay_coin, _Pre_pay_gold, _Llout_time]= Exc_rec,
					if
						Sta =:= 3 andalso Loc_exc =:= false ->
							[Tleft, Ttol, Exp, Spr, Tok] = [0, 0, 0, 0, 0],
							OpenWindow = 0;
						true ->
							Nowtime = util:unixtime(),
	    					Tleft1 = This_end_time - Nowtime,
							if 
								Tleft1 < 0 ->
									Tleft = 0;
								true ->
									Tleft = Tleft1
							end,
							Ttol = This_exc_time,
							T_used =
							case Sta of
								3 -> lib_exc:refresh_tttime(Pid, Nowtime, This_end_time, Total_exc_time);
								_ ->
									Exc_time = 
										if
											(This_beg_time + 8*3600) rem 86400 =:= 1 ->
%% ?DEBUG("handle_33000_1_xxxx_~p/~p ~n",[Pid, This_beg_time]),
												Total_exc_time * 60;
											true ->
												This_exc_time * 60 - (This_end_time - Nowtime)
										end,							
%% ?DEBUG("handle_33000_2_sssss_~p/~p ~n",[Nowtime, Exc_time]),
									lib_exc:refresh_tttime_open(Pid, Nowtime, This_beg_time, Exc_time, Total_exc_time)
							end,
%% ?DEBUG("handle_33000_3_~p/~p ~n",[T_used, Total_exc_time]),
							Tok = 24 * 60 - T_used,
	    					case Sta of
	    						1 ->
									Exp = data_exc:get_exc_gain(gold, exp, Plv),
	    							Spr = data_exc:get_exc_gain(gold, spr, Plv);
	    						_ ->
									Exp = data_exc:get_exc_gain(coin, exp, Plv),
	    							Spr = data_exc:get_exc_gain(coin, spr, Plv)				
	    					end,
							OpenWindow = 1
					end
				end,
				case OpenWindow of
					1 ->
    					Costc = data_exc:get_exc_cost(coin, Plv)div 100,
    					Costg = data_exc:get_exc_cost(gold, Plv),
	    				Costcn = data_exc:get_exc_cost(coin, Plv+1)div 100,
	    				Costgn = data_exc:get_exc_cost(gold, Plv+1),   		
    					Spd10 = data_exc:get_exc_cost(speedup, Plv),
    					Spd60 = data_exc:get_exc_cost(speedup_hour, Plv),
%% 						io:format("____Costc,Costcn Costg,Costgn,~p/~p/~p/~p~n",[Costc,Costcn,Costg,Costgn]),
						{ok, BinData1} = pt_33:write(33000, [Sta, Tleft, Ttol, Exp, Spr, Tok, Costc, Costg, Costcn, Costgn, Spd10, Spd60, Status#player.gold, Plv]),
    					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData1);
					_ ->
						{ok, BinData} = pt_33:write(33000, [5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
    					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
				end
	end;


%%开始修炼
handle(33001, Status, [Ty, Tm]) ->
	case Status#player.arena > 0 of
		false ->
            Pid = Status#player.id,
            case db_agent:ver_exc_record(Pid) of
                Pid ->
                    [Sta, _This_beg_time, This_end_time, _This_exc_time, Total_exc_time, _Pre_pay_coin, _Pre_pay_gold, _Llout_time] = db_agent:get_exc_rec(Pid),
                    case Sta of
                        3 ->
                            Nowtime = util:unixtime(),
                            lib_exc:refresh_tttime(Pid, Nowtime, This_end_time, Total_exc_time);
                        _ -> Total_exc_time
                    end,
                    Tttime = db_agent:get_exc_toltime(Pid);
                _ -> Tttime = 0
            end,
        %% io:format("start_exc_~p/~p ~n",[Status#player.x, Status#player.y]),	
            if 
                24 * 60 - Tttime < (Tm * 60 - 59) ->
                    {ok, BinData} = pt_33:write(33001, [4, Status#player.gold, Status#player.coin, Status#player.bcoin, 0]),
                    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
                true ->
        %% io:format("start_exc_1_~p/~p ~n",[Status#player.x, Status#player.y]),
                    Loc_exc = lib_scene:ver_location(Status#player.scene, [Status#player.x, Status#player.y], exc),
                    if 
                        Loc_exc =:= false -> %%判断角色位置
                        {ok, BinData} = pt_33:write(33001, [6, Status#player.gold, Status#player.coin, Status#player.bcoin, 0]),
                        lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
                    true ->
                        case Status#player.status of
                            7 ->
                                {ok, BinData} = pt_33:write(33001, [7, Status#player.gold, Status#player.coin, Status#player.bcoin, 0]),
                                lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
                                Status_s = Status,
                                Continue = 0;
                            6	->
                                %%取消打坐
                                {ok,Status_s} = lib_player:cancelSitStatus(Status),
                                Continue = 1;
                            0 ->
                                Status_s = Status,
                                Continue = 1;
                            _->
                                {ok, BinData} = pt_33:write(33001, [5, Status#player.gold, Status#player.coin, Status#player.bcoin, 0]),
                                lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
                                Status_s = Status,
                                Continue = 0
                        end,
                        %%************************************ by xiaomai 
                        %%如果在交易的话，立即退出交易状态,通知取消交易
                        {ATrade, _BPlayerId} = Status_s#player.other#player_other.trade_status,
        %% %% ?DEBUG("*******  the status is [~p] *******", [ATrade]),
                        Status_trade = 
                            if 
                                ATrade /= 0 ->
                                    {ok, Status_new} = pp_trade:handle(18007, Status_s, [2]),
                                    Status_new;
                                true ->
                                    Status_s
                            end,
                        %%************************************	
                        {ok, Status_t} = lib_goods:force_off_mount(Status_trade),
                        
                        case Continue of
                            0 -> ok;
                            1 -> 
                                case Ty of
                                    1 ->
                                        Type = gold;
                                    2 ->
                                        Type = coin
                                end,
                                Plv = Status_t#player.lv,
                                Exp_now = Status_t#player.exp,
                                Exp_up = data_exp:get(Plv + 1),
                                Exc_time =
                                        if 
                                            24 * 60 - Tttime < Tm * 60 ->	
                                                24 * 60 - Tttime;
                                            true ->
                                                Tm * 60
                                        end,
                                Exp_min = data_exc:get_exc_gain(Type, exp, Plv),	
								case Type of 
									gold->
                                		if
                                    		Exp_min * Exc_time > Exp_up ->
                                      		  Up_time = (Exp_up - Exp_now) div Exp_min + 1,
                                       		 Cost = tool:ceil(((Up_time div 10 ) * data_exc:get_exc_cost(Type, Plv) + ((Exc_time - Up_time) div 10 ) * data_exc:get_exc_cost(Type, Plv + 1))/100);
                                  		  true ->
                                       		 Cost = tool:ceil((Exc_time div 10 )* data_exc:get_exc_cost(Type, Plv)/100)
                               		 end;
									coin->
										if
                                    		Exp_min * Exc_time > Exp_up ->
                                      		  Up_time = (Exp_up - Exp_now) div Exp_min + 1,
                                       		 Cost = round(((Up_time div 10) * data_exc:get_exc_cost(Type, Plv) + ((Exc_time - Up_time) div 10) * data_exc:get_exc_cost(Type, Plv + 1)) div 100);
                                  		  true ->
                                       		 Cost = round((Exc_time div 10 )* data_exc:get_exc_cost(Type, Plv) div 100)
                               		 end
								end,
%% 								io:format("_______Cost  Exc_time ~p/~p~n",[Cost,Exc_time]),
                                case goods_util:is_enough_money(Status_t, Cost, Type) of
                                    false ->
                                        {ok, BinData1} = pt_33:write(33001, [Ty + 1, Status_t#player.gold, Status_t#player.coin, Status_t#player.bcoin, 0]),
                                        lib_send:send_to_sid(Status_t#player.other#player_other.pid_send, BinData1);							
                                    true ->
                                        db_agent:set_exc_loc(Pid, Status#player.scene, Status#player.x, Status#player.y),
										spawn(fun()->db_agent:update_join_data(Status_t#player.id, exc)end),
                                        lib_exc:start_exc(Status_t, Ty, Exc_time, Cost, start_exc)
                                end
                        end
                 end
            end;
		true ->
			{ok, BinData} = pt_23:write(23002, 12),
    		lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
	end;

%%取消修炼
handle(33002, Status, cancel) ->
	Pid = Status#player.id,
	case Status#player.status of
		7 ->
			case db_agent:get_exc_rec(Pid) of
				[Exc_sta, Begtime, This_end_time, Exc_time_m, Total_exc_time, _Pre_pay_coin, _Pre_pay_gold, Llout_time] ->
					Pid = Status#player.id,
					Nowtime = util:unixtime(),
  					Exc_time = 
						case (Begtime + 8*3600) rem 86400 of
							1 ->
								Total_exc_time * 60;
							_ ->
								Exc_time_m * 60 - (This_end_time - Nowtime)
						end,
					case Exc_sta of
						1 -> Paytype = gold;
						2 -> Paytype = bcoin
					end,
					Left_time = This_end_time - Nowtime,
					Payb = erlang:trunc((data_exc:get_exc_cost(Paytype, Status#player.lv)/100) * (Left_time div 600)),
					if 
						Payb > 0 ->
								Status1 = lib_goods:add_money(Status, Payb, Paytype, 3312);
						true -> 
							Status1 = Status
					end,
%% %% ?DEBUG("handle_33002_1_~p/~p ~n",[left_time, Left_time]),
%% %% ?DEBUG("handle_33002_2_~p/~p ~n",[Payb, Status#player.bcoin]),
%% 			lib_exc:set_exc_prepay(Pid, Exc_sta, 0),
					Tttime = lib_exc:refresh_tttime(Pid, Nowtime, Begtime, Exc_time, Total_exc_time),
					db_agent:add_exc_log(Pid, Exc_time_m, Begtime, Llout_time, This_end_time, Tttime, Exc_time, 2),
					db_agent:clear_exc_info(Pid, Nowtime),				
					Status2 = lib_exc:set_exc_status(Status1, 0),
  					{ok, BinData} = pt_33:write(33002, [Status2#player.gold, Status2#player.bcoin]),
 					lib_send:send_to_sid(Status2#player.other#player_other.pid_send, BinData),			
					{ok, BinDataBC} = pt_12:write(12090, [Pid, 0]),
					mod_scene_agent:send_to_area_scene(Status2#player.scene, Status2#player.x, Status2#player.y, BinDataBC),			
 					{ok, Status2};
				_ ->
					error
			end;
  		_ -> error
  	end;


%%加速修炼
handle(33004, Status, [Ty]) ->
		Pid = Status#player.id,
		case Status#player.status of
			7 ->
%% io:format("pp_exc_1_~p/~p ~n",[Pid, Ty]),
				[Exc_sta, Begtime, This_end_time, _Exc_time_m, Total_exc_time, _Pre_pay_coin, _Pre_pay_gold, _Llout_time]= db_agent:get_exc_rec(Pid),
				case Exc_sta of
					Val when Val =:= 0 orelse Val =:= 3 ->
		  			{ok, BinData} = pt_33:write(33004, [3, Status#player.gold, Ty]),
		 				lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
		 			_ ->
		 				Costg = data_exc:get_exc_cost(Ty + 2, Status#player.lv),
%% io:format("pp_exc_2_~p/~p ~n",[Costg, Ty]),	
						case goods_util:is_enough_money(Status, Costg, gold) of
							false ->
		  						{ok, BinData} = pt_33:write(33004, [2, Status#player.gold, Ty]),
		 						lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData); 						
		 					true ->
%% io:format("pp_exc_3_~p/~p ~n",[Costg, Ty]),
								Time_sp =
		 							case Ty of
		 								1 -> 10;
		 								2 -> 60
		 							end,
								lib_achieve:check_achieve_finish(Status#player.other#player_other.pid_send,
																 Status#player.id, 510, [Time_sp]),
								Costg_abs = abs(Costg),
		 						Status1 = lib_goods:cost_money(Status, Costg_abs, gold, 3314),
								Nowtime = util:unixtime(),
								Tmx = Nowtime + Time_sp * 60,
								if
									(Nowtime + 8*3600) div 86400 > (Begtime + 8*3600) div 86400 ->
										Reset_begtime = ((Nowtime + 8*3600) div 86400) * 86400 - 8*3600 +1,
%% 										Tttime_min = ((Nowtime + 8*3600) rem 86400 + Exc_time) div 60,
										db_agent:reset_exc_begtime(Pid, Reset_begtime, Time_sp);
%% 										db_agent:set_exc_begtime(Pid, Reset_begtime);
									true -> 
										case (Begtime + 8*3600) rem 86400 of
											1 ->
												db_agent:reset_exc_begtime(Pid, Begtime, Time_sp + Total_exc_time);
											_ -> ok
										end
								end,
		 						if 
		 							Tmx >= This_end_time ->
		 								Exc_time = This_end_time - util:unixtime(),
										db_agent:reduce_exc_endtime(Pid, Exc_time),
		 								Statustmp = lib_exc:finish_exc(Status1);
		 							true ->
		 								Exc_time = Time_sp * 60,
%% 		 								Newendtime = This_end_time - Exc_time,
		 								db_agent:reduce_exc_endtime(Pid, Exc_time),
										Statustmp = Status1
		 						 end,
		 						 Exp_inc = data_exc:get_exc_gain(Exc_sta, exp, Statustmp#player.lv) * (Exc_time div 60),
		 						 Spr_inc = data_exc:get_exc_gain(Exc_sta, spr, Statustmp#player.lv)* (Exc_time div 60),
		 						 Status2 = lib_player:add_exp(Statustmp, Exp_inc, Spr_inc, 4),
		  					 	{ok, BinData} = pt_33:write(33004, [1, Status2#player.gold, Ty]),
		 						 lib_send:send_to_sid(Status2#player.other#player_other.pid_send, BinData),
		 						 {ok, Status2}	 						 						
		 				end
		 		end;
		 	_ ->
		  		{ok, BinData} = pt_33:write(33004, [3, Status#player.gold, Ty]),
		 		lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
		 		ok		 		
 		end;

%% 凝神传送
handle(33005, PlayerStatus, [Type])->
	[Res, Status] =
		case Type of
			1 ->%%凝神修炼
				Check = 
					case PlayerStatus#player.vip =:= 3 of
						false->%%不是半年卡
							pp_task:check_vip_send_times(PlayerStatus);
						true->
							1
					 end,
				case Check of
					1 ->
						lib_exc:exc_devliver(PlayerStatus, Type);
					_NoVip ->
						[3, PlayerStatus]
				end;
			Value when Value =:= 2 orelse Value =:= 3 ->%%桃子，灵兽圣园
				case goods_util:is_enough_money(PlayerStatus, 5, gold) of
					false ->
						[2, PlayerStatus];
					true ->
						lib_exc:exc_devliver(PlayerStatus, Type)
				end;
			_Other ->
				[0,PlayerStatus]
		end,
	{ok, BinData} = pt_33:write(33005, [Res, Status#player.gold]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	{ok, Status};
		   
handle(33006,Status,[])->
	Data = lib_find_exp:check_find_exp(Status#player.id),
	{ok,BinData} = pt_33:write(33006,Data),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;

handle(33007,Status,[Id,ConvertType,Color])->
	case lib_find_exp:convert_find_exp(Status,ConvertType,Id,Color) of
		{NewStatus,1,Color}-> 
			{ok,BinData} = pt_33:write(33007,[1,Color]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			lib_player:send_player_attribute(NewStatus,2),
			handle(33006,NewStatus,[]),
			{ok,NewStatus};
		{_,Res,Color}->
			{ok,BinData} = pt_33:write(33007,[Res,Color]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok
	end;

%%一键领取
handle(33008,Status,[Type])->
	case lib_find_exp:convert_exp_all(Status,Type) of
		{NewStatus,1}-> 
			{ok,BinData} = pt_33:write(33008,[1]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			lib_player:send_player_attribute(NewStatus,2),
			handle(33006,NewStatus,[]),
			{ok,NewStatus};
		{_,Res}->
			{ok,BinData} = pt_33:write(33008,[Res]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok
	end;

handle(_Cmd, _Status, _Data) ->
	%%     ?DEBUG("pp_fst no match", []),
    {error, "pp_exc no match"}.

