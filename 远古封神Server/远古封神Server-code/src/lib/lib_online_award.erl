%% Author: hxming
%% Created: 2011-3-21
%% Description: TODO:玩家在线奖励
-module(lib_online_award).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
%%
%% Exported Functions
%%
%% -compile(export_all).
-export([continuous_online_info/1,
		 get_continuous_online_award/2,
		 continuous_online_cash_info/1,
		 get_continuous_online_cash/2,
		 init_online_award/1,
		 init_online_award_holiday/1,
		 offline/1,
		 test_change_time/3
		 ]).
%%
%% API Functions
%%
%%获取连续登陆统计信息
%%[连续登陆天数，第四天物品id，物品数量，是否领取，
%%第八天物品id，物品数量，是否领取，
%%第十二天物品id，物品数量，是否领取]
continuous_online_info(PlayerStatus)->
	Data =
		case select_online_award(PlayerStatus#player.id) of
			[] ->
				[0,0,0,0,0,0,0,0,0,0];
			[Online]-> 
				EtsOnline = check_day_online(PlayerStatus#player.id,util:unixtime(),Online),
				[GoodsId1,G1_N,G1_M,CDay,GoodsId2,G2_N,G2_M]=get_holiday_award(PlayerStatus#player.id),
				[
					EtsOnline#ets_online_award.day,
			 		EtsOnline#ets_online_award.g4,
			 		get_goods_num_by_id(4,EtsOnline#ets_online_award.lv,EtsOnline#ets_online_award.g4),
			 		EtsOnline#ets_online_award.g4_m,
			 		EtsOnline#ets_online_award.g8,
			 		get_goods_num_by_id(8,EtsOnline#ets_online_award.lv,EtsOnline#ets_online_award.g8),
			 		EtsOnline#ets_online_award.g8_m,
			 		EtsOnline#ets_online_award.g12,
			 		get_goods_num_by_id(12,EtsOnline#ets_online_award.lv,EtsOnline#ets_online_award.g12),
			 		EtsOnline#ets_online_award.g12_m,
			 		GoodsId1,G1_N,G1_M,CDay,GoodsId2,G2_N,G2_M
			 	]
		end,
	{ok, BinData} = pt_13:write(13022, Data),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData).
			
%%领取连续上线奖励(1领取成功，2数据异常，3连续上线还不够4天，4连续上线还不够8天，5连续上线还不够12天,6该物品已经领取,7领取失败,8背包不足)
get_continuous_online_award(PlayerStatus,Day)->
	case Day=:=51 orelse Day=:=52 of
		false->
			case select_online_award(PlayerStatus#player.id) of
				[]->{error,2};
				[EtsOnline]->
					case Day of
						4->get_goods(fourth,PlayerStatus,EtsOnline);
						8->get_goods(eighth,PlayerStatus,EtsOnline);
						12->get_goods(twelfth,PlayerStatus,EtsOnline);
						_->{error,2}
					end
			end;
		true->
			case select_online_award_holiday(PlayerStatus#player.id) of
				[]->{error,2};
				[EtsOnlineHoliday]->
					case Day of
						51->get_goods(every_day,PlayerStatus,EtsOnlineHoliday);
						52->get_goods(continuous,PlayerStatus,EtsOnlineHoliday);
						_->{error,2}
					end
			end
	end.

%%
get_goods(fourth,PlayerStatus,EtsOnline)->
	case EtsOnline#ets_online_award.day >=4 of
		true->
			case EtsOnline#ets_online_award.g4_m of
				0->
					case give_goods(PlayerStatus,EtsOnline#ets_online_award.lv,4,EtsOnline#ets_online_award.g4) of
						{ok,_}->
							spawn(fun()->catch(db_agent:update_online_award_goods(PlayerStatus#player.id,g4_m))end),
							NewEtsOnline = EtsOnline#ets_online_award{g4_m=1},
							update_online_award(NewEtsOnline),
							{ok,1};
						{error,Res}->{error,Res}
					end;
				_->{error,6}
			end;
		false->{error,3}
	end;
get_goods(eighth,PlayerStatus,EtsOnline)->
	case EtsOnline#ets_online_award.day >=8 of
		true->
			case EtsOnline#ets_online_award.g8_m of
				0->
					case give_goods(PlayerStatus,EtsOnline#ets_online_award.lv,8,EtsOnline#ets_online_award.g8) of
						{ok,_}->
							spawn(fun()->catch(db_agent:update_online_award_goods(PlayerStatus#player.id,g8_m))end),
							NewEtsOnline = EtsOnline#ets_online_award{g8_m=1},
							update_online_award(NewEtsOnline),
							{ok,1};
						{error,Res}->{error,Res}
					end;
				_->{error,6}
			end;
		false->{error,4}
	end;
get_goods(twelfth,PlayerStatus,EtsOnline)->
	case EtsOnline#ets_online_award.day >=12 of
		true->
			case EtsOnline#ets_online_award.g12_m of
				0->
					case give_goods(PlayerStatus,EtsOnline#ets_online_award.lv,12,EtsOnline#ets_online_award.g12) of
						{ok,_}->
							{ok,[G4,G8,G12]} = get_online_award_goods(PlayerStatus#player.lv),
							NowTime = util:unixtime(),
							spawn(fun()->catch(db_agent:reset_online_award_goods(PlayerStatus#player.id,PlayerStatus#player.lv,NowTime,[G4,G8,G12]))end),
							NewEtsOnline = EtsOnline#ets_online_award{day=0,d_t=NowTime,g4=G4,g4_m=0,
																	  g8=G8,g8_m=0,g12=G12,g12_m=0},
							update_online_award(NewEtsOnline),
							{ok,1};
						{_,Res}->{error,Res}
					end;
				_->{error,6}
			end;
		false->{error,5}
	end;
get_goods(every_day,PlayerStatus,EtsOnlineHoliday)->
	NowTime = util:unixtime(),
	case ?HOLIDAY_START =<NowTime andalso NowTime=<?HOLIDAY_END of
		true->
			case EtsOnlineHoliday#ets_online_award_holiday.every_day_mark of
				0->
					case give_goods(PlayerStatus,PlayerStatus#player.lv,51,?HOLIDAY_GOODS_ID_EVERY_DAY) of
						{ok,_}->
							NewEtsOnlineHoliday = EtsOnlineHoliday#ets_online_award_holiday{every_day_mark=1},
							spawn(fun()->
										  catch(db_agent:update_online_award_holiday(PlayerStatus#player.id,
																					 NewEtsOnlineHoliday#ets_online_award_holiday.every_day_time,
																					 NewEtsOnlineHoliday#ets_online_award_holiday.every_day_mark,
																					 NewEtsOnlineHoliday#ets_online_award_holiday.continuous_day,
																					 NewEtsOnlineHoliday#ets_online_award_holiday.continuous_mark))
								  end),
							update_online_award_holiday(NewEtsOnlineHoliday),
							{ok,1};
						{error,Res}->{error,Res}
					end;
				_->{error,6}
			end;
		false->{error,9}
	end;
get_goods(continuous,PlayerStatus,EtsOnlineHoliday)->
	case EtsOnlineHoliday#ets_online_award_holiday.continuous_day >= 3 of
		true->
			case EtsOnlineHoliday#ets_online_award_holiday.continuous_mark of
				0->
					case give_goods(PlayerStatus,PlayerStatus#player.lv,52,?HOLIDAY_GOODS_ID_CON_DAY) of
						{ok,_}->
							NewEtsOnlineHoliday = EtsOnlineHoliday#ets_online_award_holiday{continuous_mark=1,continuous_day=0},
							spawn(fun()->
										  catch(db_agent:update_online_award_holiday(PlayerStatus#player.id,
																					 NewEtsOnlineHoliday#ets_online_award_holiday.every_day_time,
																					 NewEtsOnlineHoliday#ets_online_award_holiday.every_day_mark,
																					 NewEtsOnlineHoliday#ets_online_award_holiday.continuous_day,
																					 NewEtsOnlineHoliday#ets_online_award_holiday.continuous_mark))
								  end),
							update_online_award_holiday(NewEtsOnlineHoliday),
							{ok,1};
						{error,Res}->{error,Res}
					end;
				_->{error,6}
			end;
		false->{error,10}
	end.


give_goods(PlayerStatus,Lv,Day,GoodsId)->
	case gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
						 {'cell_num'})< 1 of
		false->
			Amount = get_goods_num_by_id(Day,Lv,GoodsId),
			case ( catch gen_server:call(PlayerStatus#player.other#player_other.pid_goods, 
								 {'give_goods', PlayerStatus,GoodsId, Amount,2})) of
				ok ->
					LogBag = [PlayerStatus#player.id,GoodsId,Amount,Day,util:unixtime()],
					spawn(fun()->catch(db_agent:log_online_goods(LogBag))end),
					{ok,1};
				_->{error,7}
			end;
		true->{error,8}
	end.

%% 连续在线礼券奖励信息
%% [当天在线时间，当天可领取的礼券，
%% 七天在线时间，七天在线可领取的礼券，七天在线是否领取，七天到期时间，
%% 三十天在线时间，三十天在线可领取的礼券，三十天到期时间]
continuous_online_cash_info(Player)->
	Data =
		case select_online_award(Player#player.id) of
			[] -> 
				[0,0,0,0,0,0,0,0,0,0];
			[Online]->
				NowTime = util:unixtime(),
				EtsOnline = check_time_online(Player#player.id,NowTime,Online),
				Cash = util:floor(EtsOnline#ets_online_award.hour/3600*get_base_cash()),
				WeekEnd = NowTime- EtsOnline#ets_online_award.w_t,
				MonEnd = NowTime- EtsOnline#ets_online_award.m_t,
				[
					EtsOnline#ets_online_award.hour,
			 		Cash,
			 		EtsOnline#ets_online_award.week,
			 		50,
			 		EtsOnline#ets_online_award.w_m,
			 		WeekEnd,
			 		EtsOnline#ets_online_award.mon,
			 		300,
			 		EtsOnline#ets_online_award.m_m,
			 		MonEnd
				]
		end,
	{ok, BinData} = pt_13:write(13024, Data),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData).

%%领取礼券{1领取成功，2参数异常，3不能超过领取上限，4七天内上线没有达到40小时，
%%5七天内上线奖励已经领取,6三十天内上线没有达到200小时，7三十天内上线奖励已经领取}
get_continuous_online_cash(PlayerStatus,Type)->
	case select_online_award(PlayerStatus#player.id) of
		[]->{error,2};
		[EtsOnline]-> 
			NowTime=util:unixtime(),
			case Type of
				1->get_cash(day,PlayerStatus,EtsOnline,NowTime);
				2->get_cash(week,PlayerStatus,EtsOnline,NowTime);
				3->get_cash(mon,PlayerStatus,EtsOnline,NowTime);
				_->{error,2}
			end
	end.

%%
get_cash(day,PlayerStatus,EtsOnline,NowTime)->
	OnlineSeconds=EtsOnline#ets_online_award.hour+(NowTime- EtsOnline#ets_online_award.h_t),
	Cash = util:floor(OnlineSeconds/3600*get_base_cash()),
	case Cash >= 1 of
		true->
			NewPlayerStatus = lib_target_gift:add_cash(PlayerStatus,Cash),
			NewOnlineSeconds = OnlineSeconds-Cash*3600*get_base_cash(),
			spawn(fun()->catch(db_agent:update_online_award_hour(PlayerStatus#player.id,NewOnlineSeconds,NowTime))end),
			NewEtsOnline = EtsOnline#ets_online_award{hour = NewOnlineSeconds,h_t=NowTime},
			update_online_award(NewEtsOnline),
			LogBag = [PlayerStatus#player.id,Cash,Cash,1,NowTime],
			spawn(fun()->catch(db_agent:log_online_cash(LogBag))end),
			{ok,NewPlayerStatus};
		false->{error,3}
	end;
get_cash(week,PlayerStatus,EtsOnline,NowTime)->
	case EtsOnline#ets_online_award.w_m of
		0->
			OnlineSeconds = EtsOnline#ets_online_award.week+(NowTime- EtsOnline#ets_online_award.h_t),
			case OnlineSeconds >= 40*3600 of
				true->
					NewPlayerStatus = lib_target_gift:add_cash(PlayerStatus,50),
					spawn(fun()->catch(db_agent:update_online_award_cash(PlayerStatus#player.id,w_m,1))end),
					NewEtsOnline = EtsOnline#ets_online_award{w_m = 1},
					update_online_award(NewEtsOnline),
					LogBag = [PlayerStatus#player.id,40,50,2,NowTime],
					spawn(fun()->catch(db_agent:log_online_cash(LogBag))end),
					{ok,NewPlayerStatus};
				false->{error,4}
			end;
		_->{error,5}
	end;
get_cash(mon,PlayerStatus,EtsOnline,NowTime)->
	case EtsOnline#ets_online_award.m_m of
		0->
			OnlineSeconds = EtsOnline#ets_online_award.mon+(NowTime- EtsOnline#ets_online_award.h_t),
			case OnlineSeconds >= 200*3600 of
				true->
					NewPlayerStatus = lib_target_gift:add_cash(PlayerStatus,300),
					spawn(fun()->catch(db_agent:update_online_award_cash(PlayerStatus#player.id,m_m,1))end),
					NewEtsOnline = EtsOnline#ets_online_award{m_m = 1},
					update_online_award(NewEtsOnline),
					LogBag = [PlayerStatus#player.id,200,300,3,NowTime],
					spawn(fun()->catch(db_agent:log_online_cash(LogBag))end),
					{ok,NewPlayerStatus};
				false->{error,6}
			end;
		_->{error,7}
	end.
%%
%% Local Functions
%%

%%加载玩家在线累积数据
init_online_award(PlayerStatus)->
	PlayerId = PlayerStatus#player.id,
	case db_agent:init_online_award(PlayerId) of
		[]->
			%插入新玩家数据
			NowTime = util:unixtime(),
			{ok,[G4,G8,G12]} = get_online_award_goods(PlayerStatus#player.lv),
			{_,Id}=db_agent:new_online_award(PlayerId,PlayerStatus#player.lv,NowTime,[G4,G8,G12]),
			Data = [Id,PlayerId,PlayerStatus#player.lv,1,NowTime,G4,0,G8,0,G12,0,
					0,NowTime,0,0,NowTime,0,0,NowTime,0],
			EtsOnline = match_ets_playerinfo(Data),
			update_online_award(EtsOnline);
		Result ->
			NewData = update_online_time(PlayerStatus#player.lv,Result),
			EtsOnline = match_ets_playerinfo(NewData),
			update_online_award(EtsOnline)
	end.



match_ets_playerinfo(Data)->
	[Id,PlayerId,Lv,Day,DTime,G4,G4Mark,G8,G8Mark,G12,G12Mark,
	Hour,HTime,HMark,Week,WTime,WMark,Mon,MTime,MMark]= Data,
	EtsData = #ets_online_award{
	  id = Id,   
      pid = PlayerId,                                %% 玩家id	
	  lv=Lv,
      day = Day,                                %% 连续上线天数	
      d_t = DTime,                                %% 连续上线时间戳	
      g4 = G4,                                 %% 第四天物品	
      g4_m = G4Mark,                               %% 第四天物品领取标记	
      g8 = G8,                                 %% 第八天物品	
      g8_m = G8Mark,                               %% 第八天物品领取标记	
      g12 = G12,                                %% 第十二天物品	
      g12_m = G12Mark,                              %% 第十二天物品领取标记	
      hour = Hour,                               %% 当天在线时间(S)	
      h_t = HTime,                                %% 天时间戳	
      h_m = HMark,                                %% 天奖励领取时间戳	
      week = Week,                               %% 每周在线时间(S)	
      w_t = WTime,                                %% 周时间戳	
      w_m = WMark,                                %% 周奖励领取标记	
      mon = Mon,                                %% 当月在线时间(S)	
      m_t = MTime,                                %% 月时间戳	
      m_m = MMark                                 %% 月奖励领取标记	
							},
	EtsData.

select_online_award(PlayerId)->
	ets:match_object(?ETS_ONLINE_AWARD, #ets_online_award{pid=PlayerId,_='_'}).
update_online_award(EtsOnline)->
	ets:insert(?ETS_ONLINE_AWARD,EtsOnline).

update_online_time(PLv,OnlineBag)->
	[Id,PlayerId,Lv,Day,DTime,G4,G4Mark,G8,G8Mark,G12,G12Mark,
	Hour,_HTime,HMark,Week,WTime,WMark,Mon,MTime,MMark]= OnlineBag,
	NowTime = util:unixtime(),
	{NewDay,NewDTime,NewG4,NewG4Mark,NewG8,NewG8Mark,NewG12,NewG12Mark,NewHour,NewHTime,NewHMark,NewLv} = 
		case check_online_day(DTime,NowTime) of
			0->{Day,NowTime,G4,G4Mark,G8,G8Mark,G12,G12Mark,Hour,NowTime,HMark,Lv};
			1->{Day+1,NowTime,G4,G4Mark,G8,G8Mark,G12,G12Mark,0,NowTime,0,Lv};
			_->{ok,[G4_1,G8_1,G12_1]} = get_online_award_goods(PLv),
			   {1,NowTime,G4_1,0,G8_1,0,G12_1,0,0,NowTime,0,PLv}
		end,
	{NewWeek,NewWTime,NewWMark} =  check_online_week(NowTime,[Week,WTime,WMark]),
	{NewMon,NewMTime,NewMMark}  = check_online_mon(NowTime,[Mon,MTime,MMark]),
	NewOnlineBag = [Id,PlayerId,NewLv,NewDay,NewDTime,NewG4,NewG4Mark,NewG8,NewG8Mark,NewG12,NewG12Mark,
	NewHour,NewHTime,NewHMark,NewWeek,NewWTime,NewWMark,NewMon,NewMTime,NewMMark],
	spawn(fun()->catch(db_agent:update_online_award(NewOnlineBag))end),
	NewOnlineBag.

check_day_online(PlayerId,NowTime,EtsOnline)->
	{NewDay,NewDTime,NewG4,NewG4Mark,NewG8,NewG8Mark,NewG12,NewG12Mark} = 
		case check_online_day(EtsOnline#ets_online_award.d_t,NowTime) of
			0->{EtsOnline#ets_online_award.day,
				EtsOnline#ets_online_award.d_t,
				EtsOnline#ets_online_award.g4,
			 	EtsOnline#ets_online_award.g4_m,
			 	EtsOnline#ets_online_award.g8,
			 	EtsOnline#ets_online_award.g8_m,
			 	EtsOnline#ets_online_award.g12,
			 	EtsOnline#ets_online_award.g12_m};
			Day->{EtsOnline#ets_online_award.day+Day,
				NowTime,
				EtsOnline#ets_online_award.g4,
			 	EtsOnline#ets_online_award.g4_m,
			 	EtsOnline#ets_online_award.g8,
			 	EtsOnline#ets_online_award.g8_m,
			 	EtsOnline#ets_online_award.g12,
			 	EtsOnline#ets_online_award.g12_m}
		end,
	NewEtsOnline = EtsOnline#ets_online_award{day = NewDay,d_t = NewDTime,g4 = NewG4,g4_m = NewG4Mark,
											  g8 = NewG8,g8_m = NewG8Mark,g12 = NewG12,g12_m = NewG12Mark},
	case NewEtsOnline =/= EtsOnline of
		true->
			update_online_award(NewEtsOnline),
			spawn(fun()->catch(db_agent:reset_online_award_day(PlayerId,[NewDay,NewDTime,NewG4,NewG4Mark,NewG8,NewG8Mark,NewG12,NewG12Mark]))end);
		false->skip
	end,
	NewEtsOnline.

check_time_online(PlayerId,NowTime,EtsOnline)->
	OnlineSce = (NowTime- EtsOnline#ets_online_award.h_t),
	{Hour,HTime} = case check_online_day(EtsOnline#ets_online_award.h_t,NowTime) of
		0-> {EtsOnline#ets_online_award.hour+OnlineSce,NowTime};
		_->{zero_to_now_time(),NowTime}
	end,
	{Week,WTime,WMark} =  update_online_week(NowTime,OnlineSce,[EtsOnline#ets_online_award.week,EtsOnline#ets_online_award.w_t,EtsOnline#ets_online_award.w_m]),
	{Mon,MTime,MMark}  = update_online_mon(NowTime,OnlineSce,[EtsOnline#ets_online_award.mon,EtsOnline#ets_online_award.m_t,EtsOnline#ets_online_award.m_m]),
	NewEtsOnline = EtsOnline#ets_online_award{hour=Hour,h_t=HTime,week=Week,w_t=WTime,w_m=WMark,mon=Mon,m_t=MTime,m_m=MMark},
	spawn(fun()->catch(db_agent:reset_online_award_time(PlayerId,[Hour,HTime,Week,WTime,WMark,Mon,MTime,MMark]))end),
	update_online_award(NewEtsOnline),
	NewEtsOnline.

%%玩家下线
offline(PlayerId)->
	case select_online_award(PlayerId) of
		[]->skip;
		[EtsOnline]->
			NowTime = util:unixtime(),
			OnlineSeconds= NowTime- EtsOnline#ets_online_award.h_t,
			Hour = EtsOnline#ets_online_award.hour+OnlineSeconds,
			Week = EtsOnline#ets_online_award.week+OnlineSeconds,
			Mon = EtsOnline#ets_online_award.mon+OnlineSeconds,
			spawn(fun()->catch(db_agent:update_online_award_time(PlayerId,Hour,Week,Mon))end)
	end,
	ets:match_delete(?ETS_ONLINE_AWARD, #ets_online_award{pid=PlayerId,_='_'}),
	ets:match_delete(?ETS_ONLINE_AWARD_HOLIDAY, #ets_online_award_holiday{pid=PlayerId,_='_'}),
	ok.

%%当天秒数
zero_to_now_time()->
	{M, S, MS} = now(),
    {_, Time} = calendar:now_to_local_time({M, S, MS}),
    calendar:time_to_seconds(Time).

%%检查天数差
check_online_day(Timestamp,NowTime)->
	NDay = (NowTime+8*3600) div 86400,
	TDay = (Timestamp+8*3600) div 86400,
	NDay-TDay.

%%检查周在线时间
check_online_week(NowTime,WeekBag)->
	[Week,WTime,WMark]=WeekBag,
	case check_online_day(WTime,NowTime)>7 of
		false->{Week,WTime,WMark};
		true->{0,NowTime,0}
	end.

%%检查月在线时间
check_online_mon(NowTime,MonBag)->
	[Mon,MTime,MMark] = MonBag,
	case check_online_day(MTime,NowTime)>30 of
		false->{Mon,MTime,MMark};
		true->{0,NowTime,0}
	end.

%%更新周在线时间
update_online_week(NowTime,OnlineSce,WeekBag)->
	[Week,WTime,WMark]=WeekBag,
	case check_online_day(WTime,NowTime)>7 of
		false->{Week+OnlineSce,WTime,WMark};
		true->{0,NowTime,0}
	end.

%%更新月在线时间
update_online_mon(NowTime,OnlineSce,MonBag)->
	[Mon,MTime,MMark] = MonBag,
	case check_online_day(MTime,NowTime)>30 of
		false->{Mon+OnlineSce,MTime,MMark};
		true->{0,NowTime,0}
	end.
%%随机获取在线物品
get_online_award_goods(Lv)->
	GoodsList_4 = get_goods_by_day(4,Lv),
	{Goods_4,_} = tool:list_random(GoodsList_4),	
	GoodsList_8 = get_goods_by_day(8,Lv),
	{Goods_8,_} = tool:list_random(GoodsList_8),
	GoodsList_12 = get_goods_by_day(12,Lv),
	{Goods_12,_} = tool:list_random(GoodsList_12),
	{ok,[Goods_4,Goods_8,Goods_12]}.

%% get_online_award_goods_num(Lv,GoodsIdBag)->
%% 	[G4,G8,G12] = GoodsIdBag,
%% 	{ok,[get_goods_num_by_id(4,Lv,G4),
%% 		 get_goods_num_by_id(8,Lv,G8),
%% 		 get_goods_num_by_id(12,Lv,G12)
%% 		]
%% 	}.

%%根据天数获取物品id列表
get_goods_by_day(Day,Lv)->
	case Lv>=45 of
		true->
			case Day of
				4->[23009,23203,23303,22006];%%极乐丹*5,低级经验符*3,低级灵力符*3高级经脉灵丹*1
				8->[28013,20300,23006,21201];%%传音符*10,幸运符*1,气血包*1,中阶坚韧灵石*2
				_->[24000,23106,20301,22000]%%仙宠口粮*10,法力包*1,七彩幸运符*1,经脉成长符*1
			end;
		false->
			case Day of
				4->[28013,28201,23002];%%筋斗云*5,传音符*3,高级聚魂丹*20,
				8->[28201,24000,21201];%%筋斗云*5,仙宠口粮*4,中阶坚韧灵石*2
				_->[23006,24000,20301]%%气血包*1,仙宠口粮*8,七彩幸运符*1
			end
	end.


%%根据物品id获取奖励物品数量
get_goods_num_by_id(Day,Lv,Id)->
	case Lv>=45 of
		false->
			case Day of
				51->?HOLIDAY_GOODS_NUM_EVERY_DAY;
				52->?HOLIDAY_GOODS_NUM_CON_DAY;
				4->
					case Id of
						28013->5;
						28201->3;
						23002->20;
						_->0
					end;
				8->
					case Id of
						28201->5;
						24000->4;
						21201->2;
						_->0
					end;
				_->
					case Id of
						23006->1;
						24000->8;
						20301->1;
						_->0
					end
			end;
		true->
			case Day of
				51->?HOLIDAY_GOODS_NUM_EVERY_DAY;
				52->?HOLIDAY_GOODS_NUM_CON_DAY;
				4->
					case Id of
						23009->5;
						23203->3;
						23303->3;
						22006->1;
						_->0
					end;
				8->
					case Id of
						28013->10;
						20300->1;
						23006->1;
						21201->2;
						_->0
					end;
				_->
					case Id of
						24000->10;
						23106->1;
						20301->1;
						22000->1;
						_->0
					end
			end
	end.


%%获取礼券基础值
get_base_cash()->
	1.

%%%%%%%%%%%%%%%%%%%%%%%%%节日登陆奖励处理
%%获取节日奖励
get_holiday_award(_PlayerId)->
	[0,0,0,0,0,0,0].
%% 	case select_online_award_holiday(PlayerId) of
%% 		[]->[0,0,0,0,0,0,0];
%% 		[EtsInfo]->
%% 			NewEtsInfo = check_holiday_online_day(EtsInfo),
%% 			[?HOLIDAY_GOODS_ID_EVERY_DAY,?HOLIDAY_GOODS_NUM_EVERY_DAY,NewEtsInfo#ets_online_award_holiday.every_day_mark,
%% 			 NewEtsInfo#ets_online_award_holiday.continuous_day,?HOLIDAY_GOODS_ID_CON_DAY,?HOLIDAY_GOODS_NUM_CON_DAY,NewEtsInfo#ets_online_award_holiday.continuous_mark]
%% 	end.

%%加载玩家节日登陆数据
init_online_award_holiday(PlayerStatus)->
	PlayerId = PlayerStatus#player.id,
	case db_agent:select_online_award_holiday(PlayerId) of
		[]->
			NowTime = util:unixtime(),
			case ?HOLIDAY_START =<NowTime andalso NowTime=<?HOLIDAY_END of
				true->CDay=1;
				false->CDay=0
			end,
			{_,Id}=db_agent:new_online_award_holiday(PlayerId,CDay,NowTime),
			Data=[Id,PlayerId,NowTime,0,CDay,0],
			EtsOnlineHoliday = match_ets_playerinfo_holiday(Data),
			update_online_award_holiday(EtsOnlineHoliday);
		Result->
			NewData = update_online_time_holiday(Result),
			EtsOnlineHoliday = match_ets_playerinfo_holiday(NewData),
			update_online_award_holiday(EtsOnlineHoliday)
	end.

match_ets_playerinfo_holiday(Data)->
	[Id,PlayerId,EveryDayTime,EveryDayMark,ContinuousDay,ContinuousMark]=Data,
	#ets_online_award_holiday{
					  id=Id,
					  pid=PlayerId,
					  every_day_time=EveryDayTime,
					  every_day_mark=EveryDayMark,
					  continuous_day = ContinuousDay,
					  continuous_mark =ContinuousMark
					 }.

select_online_award_holiday(PlayerId)->
	ets:match_object(?ETS_ONLINE_AWARD_HOLIDAY, #ets_online_award_holiday{pid=PlayerId,_='_'}).
update_online_award_holiday(EtsOnlineHoliday)->
	ets:insert(?ETS_ONLINE_AWARD_HOLIDAY,EtsOnlineHoliday).

update_online_time_holiday(Data)->
	[Id,PlayerId,EveryDayTime,EveryDayMark,ContinuousDay,ContinuousMark]=Data,
	NowTime = util:unixtime(),
	NewData= case ?HOLIDAY_START =<NowTime andalso NowTime=<?HOLIDAY_END of
				 true->
					 case check_online_day(EveryDayTime,NowTime) of
				 		0->[Id,PlayerId,EveryDayTime,EveryDayMark,ContinuousDay,ContinuousMark];
						1->[Id,PlayerId,NowTime,0,ContinuousDay+1,ContinuousMark];
						_->[Id,PlayerId,NowTime,EveryDayMark,1,ContinuousMark]
					 end;
				 false->
					 case check_online_day(EveryDayTime,NowTime) of
						 0->[Id,PlayerId,EveryDayTime,EveryDayMark,ContinuousDay,ContinuousMark];
						 _->
					 		[Id,PlayerId,NowTime,EveryDayMark,ContinuousDay,ContinuousMark]
					 end
			 end,
	if NewData =/= Data->
		   [_,_,NewEveryDayTime,NewEveryDayMark,NewContinuousDay,NewContinuousMark]=NewData,
		   db_agent:update_online_award_holiday(PlayerId,NewEveryDayTime,NewEveryDayMark,NewContinuousDay,NewContinuousMark);
	   true->skip
	end,
	NewData.

%% check_holiday_online_day(OnlineInfo)->
%% 	NowTime = util:unixtime(),
%% 	case ?HOLIDAY_START =<NowTime andalso NowTime=<?HOLIDAY_END of
%% 		true->
%% 			case check_online_day(OnlineInfo#ets_online_award_holiday.every_day_time,NowTime) of
%% 				0->OnlineInfo;
%% 				Day->
%% 					NewDay = OnlineInfo#ets_online_award_holiday.continuous_day+Day,
%% 					NewOnlineInfo = OnlineInfo#ets_online_award_holiday{every_day_time=NowTime,every_day_mark=0,continuous_day=NewDay},
%% 					spawn(fun()->
%% 								  catch(db_agent:update_online_award_holiday(NewOnlineInfo#ets_online_award_holiday.pid,
%% 																					 NewOnlineInfo#ets_online_award_holiday.every_day_time,
%% 																					 NewOnlineInfo#ets_online_award_holiday.every_day_mark,
%% 																					 NewOnlineInfo#ets_online_award_holiday.continuous_day,
%% 																					 NewOnlineInfo#ets_online_award_holiday.continuous_mark))
%% 								  end),
%% 					update_online_award_holiday(NewOnlineInfo),
%% 					NewOnlineInfo
%% 			end;
%% 		false->OnlineInfo#ets_online_award_holiday{every_day_mark=1,continuous_mark=1}
%% 	end.

%%测试接口
test_change_time(holiday,PlayerId,Day)->
	case select_online_award_holiday(PlayerId) of
		[]->skip;
		[EtsOnline]->
			NewOnlineInfo = EtsOnline#ets_online_award_holiday{continuous_day=Day},
			update_online_award_holiday(NewOnlineInfo),
			spawn(fun()->
						  catch(db_agent:update_online_award_holiday(NewOnlineInfo#ets_online_award_holiday.pid,
																	NewOnlineInfo#ets_online_award_holiday.every_day_time,
																	NewOnlineInfo#ets_online_award_holiday.every_day_mark,
																	NewOnlineInfo#ets_online_award_holiday.continuous_day,
																	NewOnlineInfo#ets_online_award_holiday.continuous_mark))
								  end)
	end;
test_change_time(holiday_del,PlayerId,_)->
	case select_online_award_holiday(PlayerId) of
		[]->skip;
		[EtsOnline]->
			NewOnlineInfo = EtsOnline#ets_online_award_holiday{every_day_time=util:unixtime(),every_day_mark=0,continuous_day=0,continuous_mark=0},
			update_online_award_holiday(NewOnlineInfo),
			spawn(fun()->
						  catch(db_agent:update_online_award_holiday(NewOnlineInfo#ets_online_award_holiday.pid,
																	NewOnlineInfo#ets_online_award_holiday.every_day_time,
																	NewOnlineInfo#ets_online_award_holiday.every_day_mark,
																	NewOnlineInfo#ets_online_award_holiday.continuous_day,
																	NewOnlineInfo#ets_online_award_holiday.continuous_mark))
								  end)
	end;
%%修改天在线时长
test_change_time(date,PlayerId,Day)->
	case select_online_award(PlayerId) of
		[]->skip;
		[EtsOnline]->
			NewEtsOnline = EtsOnline#ets_online_award{day=Day},
			update_online_award(NewEtsOnline),
			db_agent:update_online_award_date(PlayerId,Day)
	end;
test_change_time(day,PlayerId,Hours)->
	case select_online_award(PlayerId) of
		[]->skip;
		[EtsOnline]->
			NowTime = util:unixtime(),
			Seconds= NowTime- EtsOnline#ets_online_award.h_t,
			OnlineSeconds=  case EtsOnline#ets_online_award.hour+Seconds + Hours*3600 > 24*3600 of
								false->  EtsOnline#ets_online_award.hour+Seconds + Hours*3600 ;
								true->24*3600
							end,
			NewEtsOnline = EtsOnline#ets_online_award{hour=OnlineSeconds},
			update_online_award(NewEtsOnline),
			db_agent:update_online_award_time(PlayerId,OnlineSeconds,EtsOnline#ets_online_award.week,EtsOnline#ets_online_award.mon)
	end;
test_change_time(week,PlayerId,Hours)->
	case select_online_award(PlayerId) of
		[]->skip;
		[EtsOnline]->
			NowTime = util:unixtime(),
			Seconds= NowTime- EtsOnline#ets_online_award.h_t,
			OnlineSeconds=  case EtsOnline#ets_online_award.week +Seconds+ Hours*3600 > 7*24*3600 of
								false-> EtsOnline#ets_online_award.week +Seconds+ Hours*3600 ;
								true->7*24*3600
							end,
			NewEtsOnline = EtsOnline#ets_online_award{week=OnlineSeconds},
			update_online_award(NewEtsOnline),
			db_agent:update_online_award_time(PlayerId,EtsOnline#ets_online_award.hour,OnlineSeconds,EtsOnline#ets_online_award.mon)
	end;
test_change_time(mon,PlayerId,Hours)->
	case select_online_award(PlayerId) of
		[]->skip;
		[EtsOnline]->
			NowTime = util:unixtime(),
			Seconds= NowTime- EtsOnline#ets_online_award.h_t,
			OnlineSeconds=  case EtsOnline#ets_online_award.mon + Seconds+Hours*3600 > 30*24*3600 of
								false-> EtsOnline#ets_online_award.mon + Seconds+Hours*3600 ;
								true->30*24*3600
							end,
			NewEtsOnline = EtsOnline#ets_online_award{mon=OnlineSeconds},
			update_online_award(NewEtsOnline),
			db_agent:update_online_award_time(PlayerId,EtsOnline#ets_online_award.hour,EtsOnline#ets_online_award.week,OnlineSeconds)
	end.