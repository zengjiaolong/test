%% Author: Administrator
%% Created: 2011-6-18
%% Description: TODO: Add description to lib_lucky_draw
-module(lib_lucky_draw).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
%%
%% Exported Functions
%%
-compile(export_all).
%%
%% API Functions
%%

%%获取领取物品信息
get_luckydraw_info(PlayerId)->
	case select_luckydraw(PlayerId) of
		[]->[0,0,0,[0,0,0,0,0,0,0,0,0,0,0,0]];
		[LD]->
			NowTime = util:unixtime(),
			case check_online_day(LD#ets_luckydraw.timestamp,NowTime) of
				0->[LD#ets_luckydraw.goods_id,LD#ets_luckydraw.days,LD#ets_luckydraw.times,LD#ets_luckydraw.goodslist];
				_->
					NewDays = LD#ets_luckydraw.days+1,
					Times = days_to_times(NewDays, NowTime),
					NewLD = LD#ets_luckydraw{days=NewDays,times=Times,timestamp=NowTime},
					update_luckydraw(NewLD),
					db_agent:update_lucky_draw_days(PlayerId,NewDays,Times,NowTime),
					[LD#ets_luckydraw.goods_id,NewDays,Times,LD#ets_luckydraw.goodslist]
			end
	end.

%%抽奖（1成功，2今日登录奖励领取完毕，请明天再来！3您当前有可领取物品,4你不是VIP玩家，不能领取）
lucky_draw(PlayerStatus)->
	case PlayerStatus#player.vip > 0 of
		false->{error,4};
		true->
			case select_luckydraw(PlayerStatus#player.id) of
				[]->{error,2};
				[LuckyDraw]->
					if LuckyDraw#ets_luckydraw.goods_id>0 ->{error,3};
					   true->
						   if LuckyDraw#ets_luckydraw.times >0 ->
								  {ok,GoodsId} = get_goods_id(LuckyDraw#ets_luckydraw.goodslist),
								  NewTimes = LuckyDraw#ets_luckydraw.times-1,
								  NewLuckyDraw = LuckyDraw#ets_luckydraw{times=NewTimes,goods_id=GoodsId},
								  update_luckydraw(NewLuckyDraw),
								  db_agent:update_lucky_draw_goods(PlayerStatus#player.id,GoodsId,NewTimes,util:term_to_string(LuckyDraw#ets_luckydraw.goodslist)),
								  {ok,GoodsId};
							  true->{error,2}
						   end
					end
			end
	end.

%%获取物品（1成功，2当前没有物品可以领取，3您的背包空间不足，请清理背包再领取4系统繁忙，请稍后领取）
get_goods(PlayerStatus)->
	case select_luckydraw(PlayerStatus#player.id) of
		[]->{error,2};
		[LuckyDraw]->
			if LuckyDraw#ets_luckydraw.goods_id>0 ->
			 	case give_goods(PlayerStatus,LuckyDraw#ets_luckydraw.goods_id) of
				 	{ok,_}->
						log_lucky_draw(PlayerStatus#player.id,LuckyDraw#ets_luckydraw.days,LuckyDraw#ets_luckydraw.times,LuckyDraw#ets_luckydraw.goods_id,util:unixtime()),
						{ok,GoodsList} = get_goodslist(),
						NewLuckyDraw = LuckyDraw#ets_luckydraw{goodslist=GoodsList,goods_id=0},
						update_luckydraw(NewLuckyDraw),
						db_agent:update_lucky_draw_goods(PlayerStatus#player.id,0,LuckyDraw#ets_luckydraw.times,util:term_to_string(GoodsList)),
						spawn(fun()->catch(msg(PlayerStatus,LuckyDraw#ets_luckydraw.goods_id))end),
						{ok,LuckyDraw#ets_luckydraw.goods_id,NewLuckyDraw};
				 	{error,Error}->{error,Error}
			 	end;
			   true->{error,2}
			end
	end.

give_goods(PlayerStatus,GoodsId)->
	case gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
						 {'cell_num'})< 1 of
		false->
			case ( catch gen_server:call(PlayerStatus#player.other#player_other.pid_goods, 
								 {'give_goods', PlayerStatus,GoodsId, 1,2})) of
				ok ->
					{ok,1};
				_->{error,4}
			end;
		true->{error,3}
	end.

%%领取日志
log_lucky_draw(PlayerId,Days,Times,GoodsId,Timestamp)->
	spawn(fun()->catch(db_agent:log_lucky_draw(PlayerId,Days,Times,GoodsId,Timestamp))end).

%%好一点的物品广播下
msg(PlayerStatus,GoodsId)->
	NameColor = data_agent:get_realm_color(PlayerStatus#player.realm),
	case lists:member(GoodsId,[21001,21002,21500,21700,21401,21201,21101,20100,20000,20200,21400,22000,24400,24104,28800]) of
		false->skip;
		true->
			%%恭喜【玩家名】在登录奖励中获得【物品名】！
			Msg = io_lib:format("恭喜【<a href='event:1,~p, ~s, ~p,~p'><font color='~s'><u>~s</u></font></a>】在VIP福利中获得【~s】！",
								[PlayerStatus#player.id,PlayerStatus#player.nickname,PlayerStatus#player.career,PlayerStatus#player.sex, NameColor,PlayerStatus#player.nickname,
								 goods_msg(GoodsId,PlayerStatus#player.id)]),
			lib_chat:broadcast_sys_msg(2,Msg)
	end.

%物品信息
goods_msg(GoodsId,PlayerId)->
	GiveGoodsInfo = goods_util:get_new_goods_by_type(GoodsId,PlayerId),
	io_lib:format("<a href='event:2,~p,~p,1'><font color='~s'> <u> ~s </u> </font></a>",
												[GiveGoodsInfo#goods.id, PlayerId, goods_util:get_color_hex_value(GiveGoodsInfo#goods.color), goods_util:get_goods_name(GoodsId)]).
%%
%% Local Functions
%%

%%初始化数据
init_lucky_draw(PlayerId)->
	NowTime = util:unixtime(),
	case db_agent:select_lucky_draw(PlayerId) of
		[]->
			{ok,GoodsList} = get_goodslist(),
			Id = db_agent:insert_lucky_draw(PlayerId,NowTime,util:term_to_string(GoodsList)),
			Data=[Id,PlayerId,0,1,1,NowTime,util:term_to_string(GoodsList)],
			LuckyDraw = pack_ets(Data),
			update_luckydraw(LuckyDraw);
		Result->
			NewResult = check_new_day(Result,NowTime),
			LuckyDraw = pack_ets(NewResult),
			update_luckydraw(LuckyDraw)
	end.

%%玩家下线，清除数据
offline(PlayerId)->
	delete_luckydraw(PlayerId).

pack_ets(Data)->
	[Id,PlayerId,GoodsId,Days,Times,Timestamp,GoodsList]=Data,
	#ets_luckydraw{
				   id=Id,
				   pid=PlayerId,
				   goods_id=GoodsId,
				   days=Days,
				   times=Times,
				   timestamp=Timestamp,
				   goodslist= util:string_to_term(tool:to_list(GoodsList))
				}.


%%检查第二天
check_new_day(Data,NowTime)->
	[Id,PlayerId,GoodsId,Days,_Times,Timestamp,GoodsList]=Data,
	case check_online_day(Timestamp,NowTime) of
		0->Data;
		1->
			Times = days_to_times(Days+1, NowTime),
			db_agent:update_lucky_draw_days(PlayerId,Days+1,Times,NowTime),
			[Id,PlayerId,GoodsId,Days+1,Times,NowTime,GoodsList];
		_->
			Times = days_to_times(1, NowTime),
			db_agent:update_lucky_draw_days(PlayerId,1,Times,NowTime),
			[Id,PlayerId,GoodsId,1,Times,NowTime,GoodsList]
	end.

%%检查天数差
check_online_day(Timestamp,NowTime)->
	NDay = (NowTime+8*3600) div 86400,
	TDay = (Timestamp+8*3600) div 86400,
	NDay-TDay.

%%ets操作
update_luckydraw(LuckyDraw)->
	ets:insert(?ETS_LUCKYDRAW, LuckyDraw).
select_luckydraw(PlayerId)->
	ets:lookup(?ETS_LUCKYDRAW, PlayerId).
delete_luckydraw(PlayerId)->
	ets:delete(?ETS_LUCKYDRAW, PlayerId).


%%获取物品列表前6种固定，后6种随机
get_goodslist()->
	TotalList=[[28400,28401],
			   [28024,28023],
			   [24000],
			   [23409,23410],
			   [21001,21002],
			   [21500,21700],
			   [23007,23107],
			   [23303,23203],
			   [21401,21201,21101],
			   [23400,23403,23406,21200,21100],
			   [20100,20000,20200,21400],
			   [22000,24400,24104,28800]
			   ],
	RandomList = get_random([],TotalList),
	{ok,RandomList}.

get_random(GoodsIdList,[])->
	lists:reverse(GoodsIdList);
get_random(GoodsIdList,[IdList|T])->
	[GoodsId] = util:get_random_list(IdList,1),
	get_random([GoodsId|GoodsIdList],T).

%%天数转换次数
days_to_times(Days, _NowTime)->
	%%圣诞节的开始和结束时间
%% 	{TGStart, TGEnd} = lib_activities:christmas_time(),
	Times = 
		case Days of
			0->0;
			1->1;
			2->2;
			_->3
		end,
	Times.
%% 	case NowTime > TGStart andalso NowTime < TGEnd  of
%% 		true ->
%% 			trunc(Times*2);
%% 		false ->
%% 			Times
%% 	end.
		

%%随即获取物品信息
get_goods_id(GoodsList)->
	Rp = tool:random(1,10000),
	Index = if Rp =< 3000 -> 1;
			   Rp =< 4600 -> 2;
			   Rp =< 6200 -> 3;
			   Rp =< 7800 -> 4;
			   Rp =< 7850 -> 5;
			   Rp =< 7900 -> 6;
			   Rp =< 8400 -> 7;
			   Rp =< 9400 -> 8;
			   Rp =< 9450 -> 9;
			   Rp =< 9750 -> 10;
			   Rp =< 9950 -> 11;
			   true->12
			end,
	{_,NewGoodsList} = case GoodsList of
					   []->get_goodslist();
					   _->{ok,GoodsList}
				   end,
	case length(NewGoodsList) >= Index of
		true->
			GoodsId = lists:nth(Index,NewGoodsList),
			{ok,GoodsId};
		false->get_goods_id(NewGoodsList)
	end.

%%测试
test_times(PlayerId,Times)->
	[LD] = select_luckydraw(PlayerId),
	NewLD = LD#ets_luckydraw{times=Times},
	update_luckydraw(NewLD),
	db_agent:update_lucky_draw_goods(PlayerId,NewLD#ets_luckydraw.goods_id,NewLD#ets_luckydraw.times,util:term_to_string(NewLD#ets_luckydraw.goodslist)).