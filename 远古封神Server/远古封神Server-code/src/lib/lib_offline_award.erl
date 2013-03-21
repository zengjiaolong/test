%% Author: hxming
%% Created: 2011-3-18
%% Description: TODO: 玩家离线经验累积奖励
-module(lib_offline_award).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
%%
%% Exported Functions
%%
%% -compile(export_all).
-export([init_offline_award/2,
		 offline/1,
		 get_offline_award/1,
		 convert_offline_award/3,
		 update_offline_exc/1,
		 test_change_offline_time/2
		]).
%%
%% API Functions
%%
%%加载玩家离线累积数据
init_offline_award(PlayerId,Level)->
	case db_agent:init_offline_award(PlayerId) of
		[]->
			%插入新玩家数据
			NowTime = util:unixtime(),
			{_,Id}=db_agent:new_offline_award(PlayerId,NowTime),
			Data = [Id,PlayerId,0,NowTime,NowTime],
			EtsOfflineInfo = match_ets_playerinfo(Data),
			update_offline_award(EtsOfflineInfo);
		Result ->
				NewData = update_offline_time(Result,Level),
				EtsOfflineInfo = match_ets_playerinfo(NewData),
				update_offline_award(EtsOfflineInfo)
	end.

%%玩家下线
offline(PlayerId)->
	ets:match_delete(?ETS_OFFLINE_AWARD, #ets_offline_award{pid=PlayerId,_='_'}),
	db_agent:update_offline_time(PlayerId,util:unixtime()).

%% 获取累积时间.经验信息
get_offline_award(Player)->
	case select_offline_award(Player#player.id) of
		[] ->
			skip;
		[OfflineInfo]->
			Seconds = util:floor(OfflineInfo#ets_offline_award.total/3600),
			NowTime = util:unixtime(),
			Mult = lib_find_exp:check_mult(NowTime,1),
			Exp = round(Mult * get_exp_by_time(Player#player.lv, OfflineInfo#ets_offline_award.total)),
			Coin = get_base_coin(Player#player.lv),
			Spt = round(Exp div 2),
			{ok, BinData} = pt_13:write(13020, [Seconds, Exp, Coin, Spt]),
    		lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
	end.


%%兑换累积经验(1成功，2兑换倍数不对，3兑换时间不对，4兑换铜钱不足，5兑换物品不足)
convert_offline_award(PlayerStatus,Hours,Mult)->
	case check_mult(PlayerStatus#player.lv,Mult) of
		{false,_,_}->{2,PlayerStatus};
		{true,TrueMult,Goods}->
			case PlayerStatus#player.lv < 26 of
				true->{6,PlayerStatus};
				false->
					case select_offline_award(PlayerStatus#player.id) of
						[]->{3,PlayerStatus};
						[OfflineInfo]->
							Total = OfflineInfo#ets_offline_award.total,
							case Total >= Hours*3600 andalso Hours> 0 of
								false->{3,PlayerStatus};
								true->
									case Mult of
										1->
%% 											case  goods_util:is_enough_money(PlayerStatus,Goods*Hours,coin) of
%% 												false->{4,PlayerStatus};
%% 												true->
													Exp = round(get_base_exp(PlayerStatus#player.lv)* Hours*TrueMult),
													Spt = Exp div 2,
													NewPlayerStatus = lib_player:add_exp(PlayerStatus, Exp, Spt, 0),
%% 													NewPlayerStatus1 = lib_goods:cost_money(NewPlayerStatus,Goods*Hours,coin,3006),
													{ok,NewTotal,NowTime} = reset_offline_award(PlayerStatus#player.id,Hours,OfflineInfo),
													LogBag = [PlayerStatus#player.id,Hours,Mult,Exp,NowTime],
													spawn(fun()->catch(db_agent:log_offline_award(LogBag))end),
													NewExp = get_exp_by_time(NewPlayerStatus#player.lv,NewTotal),
													NewSpt = round(NewExp div 2),
													{1,NewPlayerStatus,util:floor(NewTotal/3600),NewExp, NewSpt};
%% 											end;
										_->
											case gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'delete_more', Goods, Hours}) of
												1->
													Exp = round(get_base_exp(PlayerStatus#player.lv)* Hours*TrueMult),
													Sprite = Exp div 2,
													NewPlayerStatus = lib_player:add_exp(PlayerStatus, Exp, Sprite, 0),
													{ok,NewTotal,NowTime} = reset_offline_award(PlayerStatus#player.id,Hours,OfflineInfo),
													LogBag = [PlayerStatus#player.id,Hours,Mult,Exp,NowTime],
													spawn(fun()->catch(db_agent:log_offline_award(LogBag))end),		
													NewExp = get_exp_by_time(NewPlayerStatus#player.lv,NewTotal),
													NewSpt = round(NewExp div 2),
													{1,NewPlayerStatus,util:floor(NewTotal/3600),NewExp, NewSpt};
												_->{5,PlayerStatus}
										end
								end
							end
					end
			end
	end.

%%修改离线累积时间测试接口
test_change_offline_time(PlayerId,Hours)->
	case select_offline_award(PlayerId) of
		[]->skip;
		[OfflineInfo]->
			NewTotal = case OfflineInfo#ets_offline_award.total + Hours*3600 > 86400*3 of
						   true ->86400*3;
						   false->OfflineInfo#ets_offline_award.total + Hours*3600
					   end,
			NewOfflineInfo = OfflineInfo#ets_offline_award{total=NewTotal},
			update_offline_award(NewOfflineInfo),
			spawn(fun()->catch(db_agent:update_offline_award(PlayerId,NewTotal,util:unixtime()))end)
			
	end.
%%
%% Local Functions
%%

match_ets_playerinfo(Data)->
	[Id,PlayerId,Total,Exc,Offline]= Data,
	EtsData = #ets_offline_award{
							    id=Id,
      							pid = PlayerId,       
	  							total = Total,
								exc_t = Exc,
								offline_t = Offline
							},
	EtsData.

select_offline_award(PlayerId)->
	ets:match_object(?ETS_OFFLINE_AWARD, #ets_offline_award{pid=PlayerId,_='_'}).
update_offline_award(EtsOffline)->
	ets:insert(?ETS_OFFLINE_AWARD,EtsOffline).

%%玩家上线，更新累积时间
update_offline_time(DataBag,Level)->
	case Level < 26 of
		false ->
			[Id,PlayerId,Total,Exc,Offline] = DataBag,
			NowTime = util:unixtime(),
			OfflineTime = NowTime-Offline,
			NewTotal = case OfflineTime >= 86400 of
						   false-> Total;
						   true->
							    OfflineDay = check_offline_day(Exc,NowTime),
								NewSecond = get_seconds() + 86400*(OfflineDay-1) + Total,
								case NewSecond> 3*86400 of
									false->NewSecond;
									true->3*86400
								end
			   			end,
			spawn(fun()->catch(db_agent:update_offline_award(PlayerId,NewTotal,NowTime))end),
			[Id,PlayerId,NewTotal,NowTime,NowTime];
		true->DataBag
	end.

%%获取每天零点到现在跑过的秒数
get_seconds()->
	{M, S, MS} = now(),
    {_, Time} = calendar:now_to_local_time({M, S, MS}),
    calendar:time_to_seconds(Time).

%%检查第二天
check_offline_day(Timestamp,NowTime)->
	NDay = (NowTime+8*3600) div 86400,
	ODay = (Timestamp+8*3600) div 86400,
	NDay-ODay.

%%记录玩家凝神的时间
update_offline_exc(PlayerId)->
	NowTime = util:unixtime(),
	case select_offline_award(PlayerId) of
		[]->skip;
		[OfflineInfo]->
			NewOfflineInfo = OfflineInfo#ets_offline_award{exc_t = NowTime},
			update_offline_award(NewOfflineInfo),
			db_agent:update_offline_exc(PlayerId,NowTime)
	end.


%%检查倍数
check_mult(_Lv,Mult)->
	NowTime = util:unixtime(),
	case Mult of
%% 		1->{true,1.0,get_base_coin(Lv)};
		1->{true,lib_find_exp:check_mult(NowTime,1.0),0};
		2->{true,lib_find_exp:check_mult(NowTime,2.0),23413};
		3->{true,lib_find_exp:check_mult(NowTime,3.0),23412};
		_->{false,0,0}
	end.

%%获取基础经验值(小时)
get_base_exp(Lv)->
	round(data_exc:get_exc_gain(2, exp, Lv)*60*0.375).

%%获取基础灵力值(小时)
%% get_base_spr(Lv)->
%% 	round(data_exc:get_exc_gain(2, spr, Lv)*60*0.375).

%%根据时间算计累积经验
get_exp_by_time(Lv,Timestamp)->
	round(util:floor(Timestamp/3600)*get_base_exp(Lv)).

%%根据时间算计累积灵力
%% get_spr_by_time(Lv,Timestamp)->
%% 	round(util:floor(Timestamp/3600)*get_base_spr(Lv)).

%%获取兑换铜钱比(小时)
get_base_coin(Lv)->
	case Lv < 26 of
		true->round(data_exc:get_exc_cost(2,26)*6/100);
		false->round(data_exc:get_exc_cost(2,Lv)*6/100)
	end.

reset_offline_award(PlayerId,Hours,OfflineInfo)->
	NewTotal = OfflineInfo#ets_offline_award.total - Hours*3600,
	NowTime = util:unixtime(),
	NewOfflineInfo = OfflineInfo#ets_offline_award{total=NewTotal,offline_t=NowTime,exc_t= NowTime},
	update_offline_award(NewOfflineInfo),
	spawn(fun()->catch(db_agent:update_offline_award(PlayerId,NewTotal,NowTime))end),
	{ok,NewTotal,NowTime}.



			