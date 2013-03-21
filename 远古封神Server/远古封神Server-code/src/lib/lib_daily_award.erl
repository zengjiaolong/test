%% Author: zc
%% Created: 2011-7-14
%% Description: TODO: Add description to lib_daily_award
-module(lib_daily_award).

%%
%% Include files
%%
-include("record.hrl").
-include("common.hrl").

%%
%% Exported Functions
%%
-compile(export_all).


%%
%% API Functions
%%

init_daily_award_data() ->
    F=fun(Dgift) ->
				DgiftInfo = list_to_tuple([ets_base_daily_gift|Dgift]),
                ets:insert(?ETS_BASE_DAILY_GIFT, DgiftInfo)
            end,
        case db_agent:query_daily_award_goods() of
            [] -> skip;
            DgiftList when is_list(DgiftList) ->
                lists:foreach(F,DgiftList);
            _-> skip
        end,
	ok.


%%是否过了新手期奖励
check_daily_award(PlayerStatus) ->
	case lib_online_gift:check_online_gift(PlayerStatus) of
		{error,_,_,_} ->true;
		_Other ->false
	end.

%%今天是否已领完,  Result=1可以领， 0不可以
check_today_times(PlayerStatus) ->
	case db_agent:find_single_award(PlayerStatus#player.id) of
		[] -> 
			case check_daily_award(PlayerStatus) of
					true -> 
						AwardInterval = get_time_interval(0),
						db_agent:add_award_record(PlayerStatus#player.id, 0, 0),
						ets:insert(?ETS_DAILY_ONLINE_AWARD,#ets_daily_online_award{pid=PlayerStatus#player.id,gain_times=0,timestamp=0}),
						{1,AwardInterval};
					false ->{0,0}
			end;
		Info -> 
			    case check_daily_award(PlayerStatus) of
					true ->
						 [ PlayerId, N, Seconds1 ] = Info,
						 ets:insert(?ETS_DAILY_ONLINE_AWARD,#ets_daily_online_award{pid=PlayerId,gain_times=N,timestamp=Seconds1}),
	                     Seconds2 = util:unixtime(),
	                     case util:is_same_date(Seconds1, Seconds2) of
		                     true ->
			                     %case (N < (?DAILY_AWARD_MAX_TIMES-1) andalso N > 0) of
								 case (N < (?DAILY_AWARD_MAX_TIMES) andalso N > 0) of
				                        true ->
								                 AwardInterval = get_time_interval(N),
										         {1,AwardInterval};
				                        false ->
											{0,0}
	                             end;
		                     false ->
			                    Time2 = get_time_interval(0),
					            NewInfo = #ets_daily_online_award{pid = PlayerStatus#player.id, gain_times = 0, timestamp = 0},
					            update_daily_award_info(NewInfo),
			                    {1, Time2}
	                     end;
				    false -> {0,0}
				end           
	end.
	
	  
%% 更新领奖信息表
update_daily_award_info(NewInfo) ->
	ets:insert(?ETS_DAILY_ONLINE_AWARD,NewInfo),
	db_agent:update_daily_award(NewInfo#ets_daily_online_award.pid, NewInfo#ets_daily_online_award.gain_times, NewInfo#ets_daily_online_award.timestamp).

insert_log(NewInfo,GoodsId,Num) ->
	db_agent:log_daily_award(NewInfo#ets_daily_online_award.pid, GoodsId, Num, NewInfo#ets_daily_online_award.gain_times, NewInfo#ets_daily_online_award.timestamp).

get_all_daily_gifts() ->
	ets:tab2list(?ETS_BASE_DAILY_GIFT).

%%领取物品，1：时间未到；2：今天已领完；3：背包空间不足；4:还未领完前十二天的奖励；5:领取物品发生异常；0:领取成功； 
get_single_gift(PlayerStatus) ->
	case check_daily_award(PlayerStatus) of
		true ->
		   case check_bag_enough(PlayerStatus) of
			   true ->
	            case ets:lookup(?ETS_DAILY_ONLINE_AWARD,PlayerStatus#player.id) of
					[Info|_] ->
						N = Info#ets_daily_online_award.gain_times,
						Seconds1 = Info#ets_daily_online_award.timestamp,
						Seconds2 = util:unixtime(),
						% AwardInterval = get_time_interval(N),                                               %玩家领完奖不下线，N有可能为5
						Interval = Seconds2 - Seconds1,
						case util:is_same_date(Seconds1, Seconds2) of
							true ->
								%case N > ?DAILY_AWARD_MAX_TIMES of
								case N >= ?DAILY_AWARD_MAX_TIMES of
									true -> {2,0,0,0};                                     %%今天已领完
									false ->
										AwardInterval = get_time_interval(N),
										case Interval>AwardInterval of
											true ->                                        %%领取成功
												case send_goods(PlayerStatus) of
													error-> {5,0,0,0};
													{GoodsId, Num} ->
														NewInfo = #ets_daily_online_award{pid=PlayerStatus#player.id, gain_times=N+1, timestamp=Seconds2},
														IsEnd = is_end(N),
														case IsEnd =:= 1 of
															true -> 
																NextIntervalTime=0;
															false -> 
																NextIntervalTime = get_time_interval(N+1)
														end,
														update_daily_award_info(NewInfo),
														spawn(fun() -> insert_log(NewInfo,GoodsId,Num) end),
														{0,NextIntervalTime, GoodsId, is_end(N)}
												end;
											false ->{1,AwardInterval-Interval, 0, is_end(N)}  %%时间未到
										end
								end;
							false ->                                                              %%领取成功
								case send_goods(PlayerStatus) of
									error-> {5,0,0,0};
									{GoodsId, Num} ->
										NewInfo = #ets_daily_online_award{pid=PlayerStatus#player.id, gain_times=1, timestamp=Seconds2},
										NextIntervalTime = get_time_interval(1), %%不同的一天，发第二次的间隔时间(无论在线等到第二天还是在不同的一天登录都是这样)
										update_daily_award_info(NewInfo),
										spawn(fun() -> insert_log(NewInfo,GoodsId,Num) end),
										{0, NextIntervalTime, GoodsId, is_end(N)}
								end
						end;
					[] ->
%% 						?DEBUG("LIB_DAILY_AWARD, GAIN EXCEPTION!!!!!",[]),
						{5,0,0,0}
				end;
			   false -> {3,0,0,0}  %%背包空间不足
		   end;
		false ->{4,0,0,0}           %%还未领完前十二天的奖励 
	end. 

%%=========私有函数============%%
%%
%% Local Functions
%%

%%获取时间间隔
get_time_interval(N) ->
     {_Times,{_,Interval}} = lists:keysearch(N,1,?DAILY_AWARD_TIME_INTERVAL),
	 Interval.

%%是否最后一次
is_end(N) ->
     %case N =:= (?DAILY_AWARD_MAX_TIMES-1) of
	 case N >= (?DAILY_AWARD_MAX_TIMES-1) of	 
            true -> 1;
            false -> 0
     end.
               
%%发物品0
send_goods(PlayerStatus) ->
	 Rnd = random:uniform(10000),
	 Gid = goods_rate(Rnd),
	 Pattern = #ets_base_daily_gift{_='_', goods_id = Gid},
	 [GoodsInfo|_] = ets:match_object(?ETS_BASE_DAILY_GIFT, Pattern),
	 Num = GoodsInfo#ets_base_daily_gift.amount,
	 case catch(gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
								{'give_goods',PlayerStatus,Gid,Num,2})) of
		 ok->{Gid, Num};
		_Other->
			error
	end.

%% 小经验丹（23200）(20%)、
%% 小灵力丹（23300）(20%)、
%% 小灵力符（23303）(7.5%)、
%% 小经验符（23203）(7.5%)、
%% 灵兽口粮（24000）(30%)、
%% 低级气血药（23400）(7.5%)、
%% 低级防御药（23403）(7.5%)

%%物品概率
goods_rate(Rnd) ->
	if Rnd =<750 ->
		   23403;%%低级防御药
	   Rnd =< 1500 ->
		   23400;%%低级气血药
	   Rnd =< 2250 ->
		   23203;%%小经验符
	   Rnd =< 3000 ->
		   23303;%%小灵力符
	   Rnd =< 5000 ->
		   23200;%%小经验丹
	   Rnd =< 7000 ->
		   23300;%%小灵力丹
	   Rnd =< 10000 -> 
		   24000 %%灵兽口粮	
	end. 

%%检查背包是否有1个空格子
check_bag_enough(PlayerStatus) ->
    (gen_server:call(PlayerStatus#player.other#player_other.pid_goods,{'cell_num'})) >= 1.


