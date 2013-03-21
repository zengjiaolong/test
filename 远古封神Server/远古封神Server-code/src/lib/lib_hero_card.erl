%% Author: hxming
%% Created: 2011-5-6
%% Description: TODO: 英雄帖
-module(lib_hero_card).

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
%%加载数据
init_hero_card(PlayerId)->
	case db_agent:select_hero_card(PlayerId) of
		[]->
			%插入新玩家数据
			NowTime = util:unixtime(),
			{_,Id}=db_agent:new_hero_card(PlayerId,NowTime),
			Data = [Id,PlayerId,0,0,0,NowTime],
			HeroCard = match_ets(Data),
			update_hero_card(HeroCard);
		Result ->
				NewData = update_use_times(Result),
				HeroCard = match_ets(NewData),
				update_hero_card(HeroCard)
	end.

match_ets(Data)->
	[Id,PlayerId,Times,Lv,Color,Timestamp]= Data,
	EtsData = #ets_hero_card{
							    id=Id,
      							pid = PlayerId,       
	  							times = Times,
								lv = Lv,
								color=Color,
								timestamp=Timestamp
							},
	EtsData.

get_hero_card_award(PlayerId)->
	[Lv,Color] = case select_hero_card(PlayerId) of
					 []->[0,0];
					 [HeroCard]->
						 [HeroCard#ets_hero_card.lv,
						  HeroCard#ets_hero_card.color]
				 end,
	{Exp,Spt} = get_award(Lv,Color),
	{Exp,Spt}.

%%检查封神贴是否可以使用
check_hero_card_use(PlayerStatus,GoodsId)->
	PlayerId = PlayerStatus#player.id,
	{Goodslv,_,_} = get_lv_and_color(GoodsId),
	if PlayerStatus#player.lv < Goodslv orelse PlayerStatus#player.lv >= Goodslv+10->
		   {fail,42};
	   true->
			case select_hero_card(PlayerId) of
				[]->{fail,41};
				[HeroCard]->
					case check_new_day(HeroCard#ets_hero_card.timestamp,util:unixtime()) of
						true->
							if HeroCard#ets_hero_card.times<?HEROCARD_NUM_LIMIT->
								   check_task(PlayerId,get_hero_task_list());
							   true->{fail,41}
							end;
						false->
							check_task(PlayerId,get_hero_task_list())
					end
			end
	end.


%%检查是否接了封神贴任务
%% check_task(PlayerId)->
%% 	case db_agent:check_task_accept(PlayerId,get_hero_task_list()) of
%% 		[]->ok;
%% 		null->ok;
%% 		_->{fail,40}
%% 	end.
check_task(_PlayerId,[])->ok;
check_task(PlayerId,[TaskId|TaskList])->
	case lib_task:get_one_trigger(TaskId, PlayerId) of
		false->check_task(PlayerId,TaskList);
		_->{fail,40}
	end.

use_hero_card(PlayerId,Lv,Color)->
	NowTime = util:unixtime(),
	[HeroCard]=select_hero_card(PlayerId),
	case check_new_day(HeroCard#ets_hero_card.timestamp,NowTime) of
		true-> 
			Times = HeroCard#ets_hero_card.times+1,
			NewHeroCard = HeroCard#ets_hero_card{times=Times,lv=Lv,color=Color};
		false->
			NewHeroCard = HeroCard#ets_hero_card{times=1,lv=Lv,color=Color,timestamp=NowTime}
	end,
	update_hero_card(NewHeroCard),
	db_agent:update_hero_card(PlayerId,Lv,Color,NewHeroCard#ets_hero_card.times,NewHeroCard#ets_hero_card.timestamp).

reset_hero_card(PlayerStatus,Exp,Spt)->
	mail_and_msg(PlayerStatus,Exp,Spt),
	[HeroCard] = select_hero_card(PlayerStatus#player.id),
	NewHeroCard = HeroCard#ets_hero_card{lv=0,color=0},
	update_hero_card(NewHeroCard),
	db_agent:reset_hero_card(PlayerStatus#player.id).

%%放弃任务
abnegate_task(PlayerStatus)->
	NowTime = util:unixtime(),
	[HeroCard]=select_hero_card(PlayerStatus#player.id),
	case check_new_day(HeroCard#ets_hero_card.timestamp,NowTime) of
		true-> 
			NewTimes = case HeroCard#ets_hero_card.times-1 <0 of
				   		true->0;
				   		false->HeroCard#ets_hero_card.times-1
			   		end,
			NewHeroCard = HeroCard#ets_hero_card{lv=0,color=0,times=NewTimes},
			update_hero_card(NewHeroCard),
			db_agent:update_hero_card(PlayerStatus#player.id,0,0,NewTimes,NewHeroCard#ets_hero_card.timestamp);
		false->
			NewHeroCard = HeroCard#ets_hero_card{lv=0,color=0,times=0,timestamp=NowTime},
			update_hero_card(NewHeroCard),
			db_agent:update_hero_card(PlayerStatus#player.id,0,0,0,NowTime)
	end.

mail_and_msg(PlayerStatus,Exp,Spt)->
	if Exp > 0 orelse Spt > 0 ->
		   NameList = [tool:to_list(PlayerStatus#player.nickname)],
		   Content =io_lib:format( "亲爱的玩家，您完成了封神帖任务，获得了~p经验，~p灵力，祝您游戏愉快！",[Exp,Spt]),
		   mod_mail:send_sys_mail(NameList, "封神帖", Content, 0,0, 0, 0, 0);
	   true->skip
	end.

%%
%% Local Functions
%%
select_hero_card(PlayerId)->
	ets:lookup(?ETS_HERO_CARD, PlayerId).
update_hero_card(HeroCard)->
	ets:insert(?ETS_HERO_CARD,HeroCard).
delete_hero_card(PlayerId)->
	ets:delete(?ETS_HERO_CARD, PlayerId).

%%更新使用次数
update_use_times(Data)->
	[Id,PlayerId,_Times,Lv,Color,Timestamp]= Data,
	NowTime = util:unixtime(),
	case check_new_day(Timestamp,NowTime) of
		true->
			Data;
		false->
			case db_agent:check_task_accept(PlayerId,get_hero_task_list()) of
				[]->
					db_agent:update_hero_times(PlayerId,0,NowTime),
					[Id,PlayerId,0,Lv,Color,NowTime];
				null->
					db_agent:update_hero_times(PlayerId,0,NowTime),
					[Id,PlayerId,0,Lv,Color,NowTime];
				_->
					db_agent:update_hero_times(PlayerId,1,NowTime),
					[Id,PlayerId,1,Lv,Color,NowTime]
			end
	end.

%%检查第二天
check_new_day(Timestamp,NowTime)->
	NDay = (NowTime+8*3600) div 86400,
	ODay = (Timestamp+8*3600) div 86400,
	NDay=:=ODay.

%%玩家下线
offline(PlayerId)->
	delete_hero_card(PlayerId),
	ok.

%%加载奖励
init_base_award() ->
    F = fun(HeroCard) ->
			HeroCardAward = list_to_tuple([ets_base_hero_card|HeroCard]),
            ets:insert(?ETS_BASE_HERO_CARD, HeroCardAward)
           end,
	L = db_agent:get_base_hero_card(),
	lists:foreach(F, L),
    ok.

get_lv_and_color(GoodsId)->
	Pattern = #ets_base_hero_card{goods_id=GoodsId,_='_'},
	case ets:match_object(?ETS_BASE_HERO_CARD, Pattern) of
		[]->{0,0,0};
		[Award]->
			{Award#ets_base_hero_card.lv,Award#ets_base_hero_card.color,Award#ets_base_hero_card.task_id}
	end.

%%获取奖励
get_award(Lv,Color)->
	NewLv = get_lv(Lv),
	Pattern = #ets_base_hero_card{lv=NewLv,color = Color,_='_'},
	case ets:match_object(?ETS_BASE_HERO_CARD, Pattern) of
		[]->{0,0};
		[Award]->
			{Award#ets_base_hero_card.exp,Award#ets_base_hero_card.spt}
	end.

get_lv(Lv)->
	if Lv <30->0;
	   Lv <40->30;
	   Lv < 50 ->40;
	   Lv < 60 ->50;
	   Lv < 70 ->60;
	   Lv < 80 ->70;
	   Lv < 90 ->80;
	   true->90
	end.

%%获取任务列表
get_hero_task_list()->
	data_task:task_get_hero_card_id_list().
