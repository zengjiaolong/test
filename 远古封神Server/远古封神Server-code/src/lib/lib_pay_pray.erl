%% Author: zj
%% Created: 2012-3-27
%% Description: 充值祈福
-module(lib_pay_pray).
-include("record.hrl").
%%
%% Include files
%%

%%
%% Exported Functions
%%
-compile(export_all).

%%
%% API Functions
%%
%% 是否充值祈福活动开启时间，是:返回时间区间，否:false
is_pay_pray_time(Now) ->
	PayPrayTime = db_agent:get_pay_pray_time(Now),
	case PayPrayTime of
		[Begtime,Endtime] ->
			if
				Now > Begtime andalso Now < Endtime ->
					[Begtime,Endtime];
				true ->
					false
			end;
		_ ->
			false
	end.

%% 获取祈福时间
get_pay_pray_time() ->
	Now = util:unixtime() ,
	PayPrayTime = db_agent:get_pay_pray_time(Now),
	case PayPrayTime of
		[Begtime,Endtime] ->
			{Begtime,Endtime};
		[] ->
			{0,0}
	end.

%% 获取转盘数据
get_pay_pray_info(Player) ->
	Now = util:unixtime(),
	case is_pay_pray_time(Now) of
		[Begtime,Endtime] ->
			if
				Now > Begtime andalso Now < Endtime ->
					case db_agent:get_pay_pray_info(Player#player.id) of
						[] ->
							[1,0,0];
						%% 同一次活动
						[Octime,Omult,Free,Charge,ST,ET] when Begtime == ST andalso Endtime == ET ->
							[Code,Mult] =
								if
									%% 已经转过
									Omult > 0 andalso Octime > Begtime andalso Octime < Endtime ->
										[1,Omult];
									Omult == -1 ->
										[5,0];
									Free == 0 orelse Charge < 2 ->
										[1,0];
									true ->
										[4,0]
								end,
							CostGold = 
								case Charge of
									0 when Free == 0 ->
										0;
									0 when Free == 1 ->
										50;
									1 -> 100;
									_ -> 111
								end,
							[Code,Mult,CostGold];
						%% 不同一次活动
						_ ->
							[1,0,0]
					end;
				true ->
					[3,0,0]
			end;
		false ->
			[3,0,0]
	end.
		
%% 祈福转盘触发
get_pay_pray(Player) ->
	Now = util:unixtime(),
	case is_pay_pray_time(Now) of
		[Begtime,Endtime] ->
			if
				Now > Begtime andalso Now < Endtime ->
					Mult = rand_mult(),
					case db_agent:get_pay_pray_info(Player#player.id) of
						[] ->
							db_agent:insert_pay_pray_info(Player#player.id,Now, Mult, 1, 0 ,Begtime,Endtime),
							CostGold = 50,
							[1,Mult,CostGold,Player];
						%% 本次活动
						[_Octime,Omult,Free,Charge,ST,ET] when ST == Begtime andalso ET == Endtime ->
							 if
								 Omult == -1 ->
									 [5,0,111,Player];
								 Free == 0 ->
									db_agent:update_pay_pray_info(Player#player.id, Now, Mult, 1, Charge,Begtime,Endtime),
									CostGold = 50,
									[1,Mult,CostGold,Player];
								 Free == 1 andalso Charge < 2 ->
									 Cost = 
										 case Charge of
											 0 -> 50;
											 1 -> 100;
											 _ -> 100000
										 end,
									 NextCost = 
										 case Charge of
											 0 -> 100;
											 _ -> 111
										 end,
									 case goods_util:is_enough_money(Player, Cost, gold) of
										 true ->
											 NewPlayer = lib_goods:cost_money(Player, Cost, gold, 3921),
											 lib_player:send_player_attribute2(NewPlayer, 2),
											 db_agent:update_pay_pray_info(Player#player.id, Now, Mult, 1, Charge + 1,Begtime,Endtime),
											 [1,Mult,NextCost,NewPlayer];
										 false ->
											 [2,0,NextCost,Player]
									 end;
								 true ->
									 [4,0,111,Player]
							 end;

						%%有数据，但活动时间不一致则是上一次活动
						_ ->
							db_agent:update_pay_pray_info(Player#player.id, Now, Mult, 1, 0,Begtime,Endtime),
							CostGold = 50,
							[1,Mult,CostGold,Player]
					end;
				true ->
					[3,0,0,Player]
			end;
		false ->
			[3,0,0,Player]
	end.


rand_mult() ->
	R = util:rand(1, 10000),
	if
		R > 1 andalso R =< 400 -> 
			2;
		R > 400 andalso R =< 1200 ->
			1.8;
		R > 1200 andalso R =< 2300 ->
			1.6;
		R > 2300 andalso R =< 4000 ->
			1.4;
		R > 4000 andalso R =< 6500 ->
			1.2;
		R > 6500 andalso R =< 10000 ->
			1.1
	end.
			
	