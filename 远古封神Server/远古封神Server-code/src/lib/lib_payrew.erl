%% Author: zj
%% Created: 2012-2-23
%% Description: 充值反馈活动
-module(lib_payrew).
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
%% 是否充值反馈活动时间，是:返回时间区间，否:false
is_payrew_time() ->
	Opening = config:get_opening_time(),
	case Opening > 0 of
		true ->
			Now = util:unixtime(),
			OpEnd = Opening + 86400 * 7,
			if
				Now > Opening andalso Now < OpEnd ->
					[Opening,OpEnd];
				true ->
					PayrewTime = db_agent:get_payrew_time(),
					case PayrewTime of
						[Begtime,Endtime] ->
							if
								Now > Begtime andalso Now < Endtime ->
									[Begtime,Endtime];
								true ->
									false
							end;
						_ ->
							false
					end
			end;
		false ->
			false
	end.
					
%%获取充值反馈信息
get_payrew_info(Player) ->
	PlayerId = Player#player.id,
	case is_payrew_time() of
		[Begtime,Endtime] ->
			PayGold = get_pay_gold(PlayerId, Begtime, Endtime),
			LeftTime = Endtime - util:unixtime(),
			case db_agent:get_payrew_info(PlayerId) of
				[] ->			
					if
						PayGold > 0 ->
							db_agent:insert_payrew_info(PlayerId, Begtime, Endtime),
							[1,PayGold,LeftTime];
						 true ->
							[1,0,LeftTime]
					end;
				[_Pid,Bt,Et,Rgold] ->
					if
						%%同一次活动
						Bt == Begtime andalso Et == Endtime -> 
							[1,PayGold - Rgold,LeftTime];
						true ->
							if
								PayGold > 0 ->
									db_agent:update_payrew_info([{begtime,Begtime},{endtime,Endtime},{rewgold,0}], [{player_id,PlayerId}]),
									[1,PayGold,LeftTime];
								true ->
									[1,0,LeftTime]
							end
					end
			end;					
		false ->
			[3,0,0]
	end.

%%领取兑换
get_payrew(Player,GoodsType) ->
	NeedGold = check_goods_type(GoodsType),
	PlayerId = Player#player.id,
	case is_payrew_time() of
		[Begtime,Endtime] ->
			if
				NeedGold > 0 ->
					PayGold = get_pay_gold(PlayerId, Begtime, Endtime),
					LeftTime = Endtime - util:unixtime(),
					case db_agent:get_payrew_info(PlayerId) of
						[_Pid,_Bt,_Et,Rgold] ->
							if
								PayGold - Rgold - NeedGold >= 0 ->
									NewRgold = (Rgold + NeedGold),
									case get_payrew_goods(Player,GoodsType) of
										1 ->
											db_agent:update_payrew_info([{rewgold,NewRgold}], [{player_id,PlayerId}]),
											[1,PayGold - NewRgold , LeftTime];
										2 ->
											[4,PayGold - Rgold,LeftTime];
										_ ->
											[0,PayGold - Rgold,LeftTime]
									end;
								true ->
									[2,PayGold - Rgold,LeftTime]
							end;
						[] ->
							[0,0,0]
					end;
				true ->
					[0,0,0]
			end;
		_ ->
			[3,0,0]
	end.

%%发送物品
get_payrew_goods(Player,GoodsType) ->
	case length(gen_server:call(Player#player.other#player_other.pid_goods,{'null_cell'})) > 0 of
		true ->
			case gen_server:call(Player#player.other#player_other.pid_goods, {'give_goods', Player,GoodsType,1,0,0}) of
				ok ->
					1;
				_ ->
					0
			end;
		false ->
			2
	end.
					

check_goods_type(GoodsType) ->
	case GoodsType of
		31064 -> 500;
		31065 -> 1000;
		31066 -> 2000;
		31067 -> 5000;
		31068 -> 10000;
		_ -> 0
	end.
		

%%
%% Local Functions
%%
%%获取充值日志
get_pay_log(Pid, BeginTime, EndTime) ->
	db_agent:get_pay_log([{player_id,Pid},{insert_time,">",BeginTime},{insert_time,"<",EndTime},{pay_status,1}]).

%%获取充值总数
get_pay_gold(Pid,BeginTime,EndTime) ->
	PayLog = get_pay_log(Pid, BeginTime, EndTime),
	case length(PayLog) > 0 of
		true ->
			F=fun([_,G]) ->
				G
			end,
			lists:sum(lists:map(F, PayLog));
		false ->
			0
	end.
