%% Author: hxming
%% Created: 2010-10-18
%% Description: 玩家在线奖励  
-module(lib_online_gift).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
%%
%% Exported Functions
%%
%% -compile(export_all).
-export([online/1,
		 offline/1,
		 check_online_gift/1,
		get_online_gift/1,
		 delete_online_gift_info/1]).

%%
%% API Functions
%%

%%玩家登陆，加载在线数据
online(PS)->
	case PS#player.online_gift of
		0->
			PlayerId = PS#player.id,
			Timestamp = util:unixtime(),
			case db_agent:select_online_gift_info(PlayerId) of 
				[]->
					%插入新玩家数据
					db_agent:create_online_gift_info(PlayerId, Timestamp),
					Data = [0,PlayerId,0,Timestamp],
 					EtsData = match_ets_playerinfo(Data),
 					ets:insert(?ETS_ONLINE_GIFT,EtsData);
				Result ->
					[ID,PlayId,Times,_] = Result,
					NewResult = [ID,PlayId,Times,Timestamp],
					Data = match_ets_playerinfo(NewResult),
					ets:insert(?ETS_ONLINE_GIFT,Data),
					db_agent:reset_online_gift_info(PlayerId,Timestamp)
			end;
		_->skip
	end.

%%玩家离线,释放ETS缓存
offline(PlayerId)->
	ets:match_delete(?ETS_ONLINE_GIFT,#ets_online_gift{player_id=PlayerId,_='_'}).
	
%%检查是否有在线奖励[是否可领，领取时间]
check_online_gift(PS)->
	case PS#player.online_gift of
		0->
			Id = PS#player.id,
			case get_player_gift_info(Id) of
				[]->
					{error,PS,[6,0,0],[]};
				Result->
					[{_,_,_,Times,Timestamp}] =  Result,
					GoodsBag = case get_gift_id_and_amount(Times+1) of
								   []->[];
								   [Res]->Res
							   end,
					check_time_and_times(PS,Times,Timestamp,GoodsBag)
			end;
		_->
			{error,PS,[6,0,0],[]}
	end.

%%获取在线奖励物品 1成功，2系统繁忙，稍后领取,3背包空间不足4时间不足，不能领取
get_online_gift(PS)->
	Id = PS#player.id,
	case get_player_gift_info(Id) of
		[]->
			{error,PS,2,[]};
		[{_,_,_,NewTimes,NewTimestamp}]->
			{_error,NewPS,[_,Result,TimeRemain],[]} = check_time_and_times(PS,NewTimes,NewTimestamp,[]),
			if 
				Result =:= 1 andalso TimeRemain =< 0 ->
					case get_gift_id_and_amount(NewTimes+1) of
						[] ->
							{error,NewPS,2,[]};
						[GiftInfo] ->
							case gen_server:call(NewPS#player.other#player_other.pid_goods,{'cell_num'})< length(GiftInfo) of
								true->{error,NewPS,3,[]};
								false->
									NowTime = util:unixtime(),
									case give_goods(NewPS,NewTimes,NowTime,GiftInfo) of
										ok->
											update_online_gift_info(Id,NewTimes+1,NowTime),
											{ok,NewPS,1,GiftInfo};
										_->{error,NewPS,2,[]}
									end
							end
					end;
				true ->
					{error,NewPS,4,[]}
			end
	end.

give_goods(_PlayerStatus,_,_,[])->
	ok;
give_goods(PlayerStatus,Times,NowTime,[GoodsInfo|GoodsBag])->
	[GoodsId,Nums ] = GoodsInfo,
	case ( catch gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'give_goods', PlayerStatus,GoodsId, Nums,2})) of
		ok ->
			spawn(fun()->catch(db_agent:log_online_gift(PlayerStatus#player.id,GoodsId,Nums,Times+1,NowTime))end),
			give_goods(PlayerStatus,Times,NowTime,GoodsBag);
		_ ->error
	end.
%%
%% Local Functions
%%
%%更新玩家在线领取信息
update_online_gift_info(PlayerId,Times,Timestamp)->
	db_agent:update_online_gift_info(PlayerId,Timestamp),
	[PlayerOnlineInfo] = get_player_gift_info(PlayerId),
	NewPlayerOnlineInfo = PlayerOnlineInfo#ets_online_gift{times=Times,timestamp=Timestamp},
	ets:insert(?ETS_ONLINE_GIFT,NewPlayerOnlineInfo).

%%获取玩家奖励信息
get_player_gift_info(PlayerId) ->
	Pattern = #ets_online_gift{player_id=PlayerId,_='_'},
	match_all(?ETS_ONLINE_GIFT, Pattern).

match_all(Table, Pattern) ->
    ets:match_object(Table, Pattern).

match_ets_playerinfo(Data)->
	[Id,PlayerId,Times,Timestamp] = Data,
	EtsData = #ets_online_gift{
	  							id=Id,                          %% ID	
      							player_id = PlayerId,          %% 玩家ID	
	  							times = Times,                  %%当日领取次数           
								timestamp = Timestamp			%%上次领取时间
							},
	EtsData.


%%获取奖励物品信息
get_gift_info(Times)->
	Pattern = #ets_base_online_gift{times=Times,_='_'},
	case match_all(?ETS_BASE_ONLINE_GIFT, Pattern) of 
		[] ->
			case db_agent:get_online_gift(Times) of 
				[]->
					[];
				Result ->
					Data = match_ets_giftinfo(Result),
					ets:insert(?ETS_BASE_ONLINE_GIFT,Data),
					match_all(?ETS_BASE_ONLINE_GIFT, Pattern)
			end;
		Info ->
		 	Info
	end.

%%物品信息转换ETS格式
match_ets_giftinfo(Data)->
	[ID,GoodsBag,Lvl,Times,Timestamp] = Data,
	EtsData = #ets_base_online_gift{
									id=ID,       
									goodsbag = 	util:string_to_term(tool:to_list(GoodsBag)),
      								level = Lvl,                              %% 等级	
      								times = Times,                              %% 第几份	
      								timestamp = Timestamp                           %%  时间间隔
									},
	EtsData.



%%检查每日领取次数和时间
check_time_and_times(PlayerStatus,Times,Timestamp,GoodsBag) ->
	if 
		Times >= 6 ->
			delete_online_gift_info(PlayerStatus#player.id),
			NewPlayerStatus = PlayerStatus#player{online_gift=1},
			ValueList = [{online_gift,1}],
			WhereList = [{id, NewPlayerStatus#player.id}],
    		db_agent:mm_update_player_info(ValueList, WhereList),
			pp_task:handle(30900, NewPlayerStatus, []),
			{error,NewPlayerStatus,[Times,0,0],[]};
		 true->
			 case get_gift_time(Times+1) of
			 	[] ->
					{error,PlayerStatus,[Times+1,0,0],[]};
				 TimeNeed ->
					 NowTime = util:unixtime(),
					 {ok,PlayerStatus,[Times+1,1,Timestamp+TimeNeed-NowTime],GoodsBag}
			 end
	end.

%%获取礼物领取时间
get_gift_time(Times) ->
	case get_gift_info(Times) of
		[]->
			[];
		[Result] ->
			Result#ets_base_online_gift.timestamp
%% 			[{_,_,_,_,_,_,_,Timestamp}] = Result,
%% 			Timestamp
	end.

%%获取礼物id和数量
get_gift_id_and_amount(Times)->
	case get_gift_info(Times) of
		[]->
			[];
		[Result] ->
			[Result#ets_base_online_gift.goodsbag]
	end.

%% %%检查第二天
%% check_new_day(Timestamp)->
%% 	if Timestamp=/=0->
%% 	{M, S, MS} = yg_timer:now(),
%%     {_, Time} = calendar:now_to_local_time({M, S, MS}),
%% 	NowSec = calendar:time_to_seconds(Time),
%%     TodaySec = M * 1000000 + S - NowSec,
%% 	OldDaySec = Timestamp - NowSec,
%%     TodaySec =:= OldDaySec;
%% 		true ->
%% 			true
%% 	end.

%%删除奖励记录
delete_online_gift_info(PlayerId)->
	db_agent:delete_online_gift_info(PlayerId),
	ets:match_delete(?ETS_ONLINE_GIFT,#ets_online_gift{player_id=PlayerId,_='_'}),
	ok.
