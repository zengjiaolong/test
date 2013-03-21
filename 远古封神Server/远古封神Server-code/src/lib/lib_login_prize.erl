%%%--------------------------------------
%%% @Module  : lib_login_prize
%%% @Author  : ygzj
%%% @Created : 2010.12.01
%%% @Description:登录奖励包括登录奖励，登录补偿等
%%%--------------------------------------
-module(lib_login_prize).
-compile(export_all).
-include("common.hrl").
-include("record.hrl"). 

%% 活动辅助表初始化
init_holiday_info(PlayerId) ->
	ets:insert(?ETS_HOLIDAY_INFO, #ets_holiday_info{pid = PlayerId}),
	ok.

%% 万人迷活动奖励接口
hot_fans_award_timer() ->
	NowSec = util:get_today_current_second(),
	Now = util:unixtime(),
	if
		Now >= ?HOLIDAY_BEG_TIME andalso Now < ?HOLIDAY_END_TIME andalso NowSec =< ?HOLIDAY_HOT_FANS_TIME andalso  NowSec + 600 >= ?HOLIDAY_HOT_FANS_TIME ->
			timer:apply_after((?HOLIDAY_HOT_FANS_TIME - NowSec)*1000, lib_login_prize, hot_fans_award, [2]),
			timer:apply_after((?HOLIDAY_HOT_FANS_TIME - NowSec)*1000, lib_login_prize, hot_fans_award, [3]);
		true ->
			skip
	end.

%% 万人迷奖励
hot_fans_award(Type) ->
	case mod_appraise:get_max_appraise(Type, 0) of
		[] ->
			skip;
		Mlist when is_list(Mlist)->
			Pid = hd(Mlist),
			case db_agent:get_mid_prize(Pid,3) of
				[] ->
					%%没有 则添加可领取记录
					db_agent:insert_mid_prize([pid,type,num,got],[Pid,3,1,0]);
				_ ->
					skip
			end;
		_ ->
			skip
	end.
				
			
%% 当天第一次登录奖励/补偿
%% Llast_login_time 记录的上一次登录时间，Player里面的是已经更新的时间
do_login_prize(Player,Llast_login_time)->
	Now = util:unixtime(),
	SameDay = util:is_same_date(Llast_login_time,Now),
	%%?DEBUG("lib_login________do_login_prize____sameday________~p",[SameDay]),
	%%?DEBUG("_________last_login_time:_________~p",[Llast_login_time]),
	if
		Llast_login_time == 0 ->
			RegDay = true;
		true ->
			RegDay = false
	end,
	if
		RegDay orelse SameDay == false ->
			GivePrice = true;
		true ->
			GivePrice = false
	end,
	%% 1317398400 - 1318003200 %%国庆
	%% 国庆登陆活动%%%
	%%	get_mid_prize type 1 充值 2登陆 3万人迷 4强化 5充值返利
	%% 初始节日活动辅助表
	%% 活动type 2
%% 	if
%% 		Now >= ?HOLIDAY_BEG_TIME andalso Now =< ?HOLIDAY_END_TIME andalso GivePrice ->
%% 			case db_agent:get_mid_prize(Player#player.id,2) of
%% 				[_Id,Mpid,Mtype,Mnum,_got] ->
%% 					db_agent:update_mid_prize([{num,Mnum + 1}],[{pid ,Mpid},{type,Mtype}]);
%% 				[] ->
%% 					db_agent:insert_mid_prize([pid,type,num,got],[Player#player.id,2,1,0])
%% 			end;				
%% 		true ->
%% 			skip
%% 	end,
	%% 全身强化活动 4
%% 	if
%% 		Now >= ?HOLIDAY_BEG_TIME andalso Now =< ?HOLIDAY_END_TIME ->
%% 			HolidayInfo = goods_util:get_ets_info(?ETS_HOLIDAY_INFO, Player#player.id),
%% 			case db_agent:get_mid_prize(Player#player.id,4) of
%% 				[_Id2,_Mpid2,_Mtype2,_Mnum2,_got2] ->
%% 					HasFullInfo = 1;
%% 				[] ->
%% 					HasFullInfo = 0
%% 			end,
%% 			ets:insert(?ETS_HOLIDAY_INFO, HolidayInfo#ets_holiday_info{has_full_stren_info = HasFullInfo});
%% 		true ->
%% 			skip
%% 	end,
	%% 充值返利5
%% 	if
%% 		Now < ?HOLIDAY_END_TIME andalso (Now + 86400) >?HOLIDAY_END_TIME ->
%% 			erlang:send_after((?HOLIDAY_END_TIME - Now)*1000, self(), {'HOLIDAY_RETURN_AWARD'});
%% 		Now >= ?HOLIDAY_END_TIME ->
%% 			lib_activities:holiday_return_award(Player);
%% 		true ->
%% 			skip
%% 	end,			
	%%%%%%%%%%%%%%%%%%%
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 	1324310400, 1324742400
%% 	三月活动
%% 整个个活动持续时间
	{EventStart, EventEnd} = lib_activities:march_event_time(),
	case EventStart =< Now andalso Now =<  EventEnd of
		true ->
			case GivePrice of
				true ->
%% 					%% 活动二	登录送好礼
%% 					ActType1 = 2,	%%活动类型
%% 					case db_agent:get_mid_prize(Player#player.id,ActType1) of
%% 						[_Id1,Mpid1,Mtype1,Mnum1,_got1] ->
%% 							db_agent:update_mid_prize([{num, Mnum1 + 1}],[{pid ,Mpid1},{type,Mtype1}]);
%% 						[] ->
%% 							db_agent:insert_mid_prize([pid,type,num,got],[Player#player.id,ActType1,1,0])
%% 					end;
%% 					%% 	活动五：	全身强化，潜力无限 
%% 					ActType2 = 3,
%% 					HolidayInfo = goods_util:get_ets_info(?ETS_HOLIDAY_INFO, Player#player.id),
%% 					case db_agent:get_mid_prize(Player#player.id, ActType2) of
%% 						[_Id2,_Mpid2,_Mtype2,_Mnum2,_got2] ->
%% 							HasFullInfo = 1;
%% 						[] ->
%% 							HasFullInfo = 0
%% 					end,
%% 					ets:insert(?ETS_HOLIDAY_INFO, HolidayInfo#ets_holiday_info{has_full_stren_info = HasFullInfo});
					%%	活动四	勇者回归
					ActType1 = 7,
					case Player#player.lv >= 40 of
						true ->
							case db_agent:get_mid_prize(Player#player.id,ActType1) of
								[_Id1,Mpid1,Mtype1,Mnum1,_got1] ->
									case Mnum1 of
										1 ->%%第一天登陆了,给第二天的
											TimeGap = util:get_diff_days(Now, Llast_login_time),
											%%?DEBUG("1TimeGap:~p", [TimeGap]),
											case TimeGap > 2 of
												true ->
													skip;
												false ->
													
													db_agent:update_mid_prize([{num, Mnum1 + 2}],[{pid ,Mpid1},{type,Mtype1}])
											end;
										3 ->%%第二天也连续登陆了，给第三天的
											TimeGap = util:get_diff_days(Now, Llast_login_time),
											%%?DEBUG("3TimeGap:~p", [TimeGap]),
											case TimeGap > 2 of
												true ->
													skip;
												false ->
													
													db_agent:update_mid_prize([{num, Mnum1 + 3}],[{pid ,Mpid1},{type,Mtype1}])
											end;
										_ ->
											skip
									end;	
								[] ->
									TimeGap = util:get_diff_days(Now, Llast_login_time),
									case TimeGap >= 8 of
										true ->%%七天没登陆，给第一天的
											db_agent:insert_mid_prize([pid,type,num,got],[Player#player.id,ActType1,1,0]);
										false ->%%没超过7天，没得给了
											db_agent:insert_mid_prize([pid,type,num,got],[Player#player.id,ActType1,0,0])
									end
							end;
						false ->%%等级没有超过40级，没机会了
							db_agent:insert_mid_prize([pid,type,num,got],[Player#player.id,ActType1,0,0])
					end;
					%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				false ->
					skip
			end;
		false ->
			skip
	end,

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%新年活动
%% 	{TGStart2, TGEnd2} = lib_activities:spring_festival_time_1(),
%% 	 if
%%  		Now >= TGStart2 andalso Now =< TGEnd2 andalso GivePrice ->
%% 	   %%新年活动登陆奖励类型 15
%%  			case db_agent:get_mid_prize(Player#player.id,15) of
%% 				[_Id2,Mpid2,Mtype2,Mnum2,_got2] ->
%% 					db_agent:update_mid_prize([{num, Mnum2 + 1}],[{pid ,Mpid2},{type,Mtype2}]);
%% 				[] ->
%% 					db_agent:insert_mid_prize([pid,type,num,got],[Player#player.id,15,1,0])
%% 			end;
%% 		true ->
%% 			skip
%% 	end,
%% 	CheckT = lib_activities:is_lovedays_time(Now),
%% 	case CheckT of
%% 		true ->
%% 			case GivePrice of
%% 				true ->
%% 					case db_agent:get_mid_prize(Player#player.id,2) of  %%类型2 登录送好礼
%% 						[_Id2,Mpid2,Mtype2,Mnum2,_got2,_D] ->
%% 							db_agent:update_mid_prize([{num, Mnum2 + 1}],[{pid ,Mpid2},{type,Mtype2}]);
%% 						[] ->
%% 							db_agent:insert_mid_prize([pid,type,num,got],[Player#player.id,2,1,0])
%% 					end;
%% 				false ->
%% 					skip
%% 			end;
%% 		false ->
%% 			skip
%% 	end,
	NewPlayer =
	case GivePrice of
		true ->
%% 			Player_1 = lib_vip:get_vip_award_load(Player),
			Player_1 = Player,
			LoginPrize = db_agent:get_login_prize(),
			case length(LoginPrize) > 0 of
				true ->
					LP = lists:nth(1, LoginPrize),
					[Begtime,Endtime,Lv_lim,Beg_regtime,End_regtime,Gold,Cash,Coin,Bcoin,Goods_id,Num,Title,Content] = LP,
					if
						Begtime < Now andalso
						Now < Endtime andalso
						Player#player.lv >= Lv_lim andalso
						Beg_regtime < Player#player.reg_time andalso 
						Player#player.reg_time < End_regtime ->
							P1 =
							if
								Bcoin > 0  ->
									lib_goods:add_money(Player_1,Bcoin,bcoin,1001);
								true ->
									Player_1
							end,
							P2 =
							if
								Cash > 0 ->
									lib_goods:add_money(P1,Cash,cash,1001);
								true ->
									P1
							end,
							P3 =
							if
								Gold > 0 orelse Coin > 0 orelse Goods_id > 0 ->
									lib_mail:insert_mail(0, Now, "系统", P2#player.id, Title, Content, 0, Goods_id, Num, Coin, Gold),
									P2;
								true ->
									P2
							end,
							P3;
						true ->
							Player
					end;
				false ->
					Player
			end;
		false ->
			Player
	end,
	NewPlayer.
