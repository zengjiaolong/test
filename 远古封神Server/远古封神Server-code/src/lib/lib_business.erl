%% Author: hxming
%% Created: 2011-4-19
%% Description: TODO: 跑商类
-module(lib_business).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

%%
%% Exported Functions
%%
%% -export([]).
-compile(export_all).
%%
%% API Functions
%%

%%查询商车信息
check_car_info(PlayerStatus)->
	case get_business(PlayerStatus#player.id) of
		[]->
			[0,18];
		[Business]->
			NowTime = util:unixtime(),
			case check_new_day(Business#ets_business.timestamp,NowTime) of
				false->%%当天第一次跑商。｛每日跑商次数，商车颜色：4，白车；5，绿车；6，蓝车；7，紫车；｝
					case PlayerStatus#player.carry_mark > 3 andalso PlayerStatus#player.carry_mark < 8 of
						true ->
							[Business#ets_business.times,PlayerStatus#player.carry_mark];           
					    false ->
							[Business#ets_business.times,18]
					end;		
				true->%%上次跑商与当天是同一天
					[Business#ets_business.times, PlayerStatus#player.carry_mark]
			end
    end.

%%检查第二天
check_new_day(Timestamp,NowTime)->
	NDay = (NowTime+8*3600) div 86400,
	TDay = (Timestamp+8*3600) div 86400,
	NDay=/=TDay.

%% 跑商奖励
get_business_award(PlayerId,Lv)->
	case get_business(PlayerId) of
		[]->{0,0};
		[Business]->
			case Business#ets_business.current of
				0->base_award(Business#ets_business.color,Lv,PlayerId);
				1->
					{Exp,Spt}=base_award(Business#ets_business.color,Lv,PlayerId),
					{round(Exp/2),round(Spt/2)};
				_->
					{Exp,Spt}=base_award(Business#ets_business.color,Lv,PlayerId),
					{round(Exp/4),round(Spt/4)}
			end
	end.

%%计算是否跑商双倍奖励时间
get_double_time()->
	{WeekStime,_WeekEtime} = util:get_this_week_duringtime(),
	Dist = (?BUSINESS_DOUBLE_DAY - 1) * 24 * 3600,
	DStartTime = WeekStime + Dist + ?BUSINESS_DOUBLE_START_TIME,
	DEndTime = WeekStime + Dist + ?BUSINESS_DOUBLE_END_TIME,
	BroadTime = WeekStime + Dist + ?BUSINESS_DOUBLE_BROAD_TIME,
	{DStartTime, DEndTime, BroadTime}.

get_level_tid(Lv) ->
	if  
		Lv>= 90->
			81006;
		Lv>=80 ->
			81005;
		Lv>=70 ->
			81004;
		Lv>=60 ->
			81003;
		Lv>=50 ->
			81002;
		Lv>=40 ->
			81001;
		Lv>=30 ->
			81000;
		true ->
			0
	end.
		
	  

%%检查玩家是否有相应的商牌 {结果:1,成功;2，没有相应的商牌；3，数据异常；  ，    商车颜色：4，白车；5，绿车；6，蓝车；7，紫车；0，什么车都不是}
check_business_goods(PS, Type) ->
	PlayerId = PS#player.id,
	case Type =:= 18 of %%自动匹配 
		true -> [_R,_Color,_G] = case lib_goods:goods_find(PlayerId, 28409) of
					 false-> case lib_goods:goods_find(PlayerId, 28408) of
								 false-> case lib_goods:goods_find(PlayerId, 28407) of
											 false-> case lib_goods:goods_find(PlayerId, 28406) of
														 false->[2,0,0];
														 _->[1,4,28406]   %%有白色商牌
													 end;
											 _->[1,5,28407]                %%有绿色商牌
										 end;
								 _->[1,6,28408]                            %%有蓝色商牌
							 end;
					 _->[1,7,28409]                                        %%有紫色商牌
				 end;
											 
		false ->       %%已经选择商车，不是自动匹配
			case Type =:= 10000 of
				true -> [1,0,0];%%用于获取可接任务列表
				false ->case lists:keyfind(Type,1,?GOODSTYPE) of
							false ->[2,0,0];
							{Type,GoodsId} -> case lib_goods:goods_find(PlayerId, GoodsId) of
												  false-> case Type =:= 6 orelse Type =:= 7 of
															  true -> [2,Type,1] ;
															  false -> [2,0,0]
														  end;
												  _->[1,Type,GoodsId]
											  end
						end
			end	
			
	end.

%%检查跑商
check_business(PlayerStatus,Color)->
	case get_business(PlayerStatus#player.id) of
		[]->
			{false,208};
		[Business]-> 
			NowTime = util:unixtime(),
			case check_new_day(Business#ets_business.timestamp,NowTime) of
				false->
					case Business#ets_business.times >= 3 of
						true->
							{false,208};
						false->
							case check_business_goods(PlayerStatus, Color) of
								[2,0,0] ->
									{false,211};
								[2,Color,1] ->
									if Color=:=6 ->
										   {false,212};
									   true ->
										   {false,213}
									end;
								[1,CarColor,_GoodsId] ->
									{true,CarColor}
							end		
					end;
				true->
					reset_business_info(PlayerStatus,Business,NowTime),
					{true,1}
			end
	end.

%%开始跑商
update_business_info(PlayerStatus,Color) ->
	%% 玩家卸下坐骑
	{ok,MountPlayerStatus}=lib_goods:force_off_mount(PlayerStatus),
	[BInfo] = get_business(PlayerStatus#player.id),
	BusinessInfo=BInfo#ets_business{color = Color},
	NewPlayerStatus = MountPlayerStatus#player{pk_mode=5},
	{ok, PkModeBinData} = pt_13:write(13012, [1, 5]),
    lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, PkModeBinData),
	(catch db_agent:mm_update_player_info([ {carry_mark, BusinessInfo#ets_business.color}],
											[{id,NewPlayerStatus#player.id}])),
	NewPlayerStatus1=NewPlayerStatus#player{carry_mark = BusinessInfo#ets_business.color},
	NewBusinessInfo = BusinessInfo#ets_business{times =BusinessInfo#ets_business.times+1, lv=PlayerStatus#player.lv,current=0,color=BusinessInfo#ets_business.color},
	{_Key,GoodsId} = lists:keyfind(Color, 1, ?GOODSTYPE),
	gen_server:call(PlayerStatus#player.other#player_other.pid_goods,{'delete_more', GoodsId, 1}),
	
	update_business(NewBusinessInfo),
	db_agent:start_business(PlayerStatus#player.id,PlayerStatus#player.lv, Color),
	%%通知所有玩家
    {ok,BinData2} = pt_12:write(12041,[NewPlayerStatus1#player.id,NewPlayerStatus1#player.carry_mark]),
	mod_scene_agent:send_to_area_scene(NewPlayerStatus1#player.scene,NewPlayerStatus1#player.x,NewPlayerStatus1#player.y, BinData2),
	business_broadcast(NewPlayerStatus1,null,1),
	db_agent:update_join_data(NewPlayerStatus1#player.id, business),
	%%NewPlayerStatus#player.other#player_other.pid ! {'SET_PLAYER_INFO', [{carry_mark,BusinessInfo#ets_business.color}]},
	%%io:format("lib_business 185 line carry_mark = ~p~n",[NewPlayerStatus1#player.carry_mark])
	{ok,NewPlayerStatus1}.

%%变换商车
change_car(PlayerStatus,Color)->
	(catch db_agent:mm_update_player_info([ {carry_mark, Color}],
											[{id,PlayerStatus#player.id}])),
	NewPlayerStatus1=PlayerStatus#player{carry_mark = Color},
	%%通知所有玩家
    {ok,BinData2} = pt_12:write(12041,[NewPlayerStatus1#player.id,NewPlayerStatus1#player.carry_mark]),
	mod_scene_agent:send_to_area_scene(NewPlayerStatus1#player.scene,NewPlayerStatus1#player.x,NewPlayerStatus1#player.y, BinData2),
	business_broadcast(NewPlayerStatus1,null,1),
	gen_server:cast(NewPlayerStatus1#player.other#player_other.pid,{'SET_PLAYER',NewPlayerStatus1}),
	{ok,NewPlayerStatus1}.

%%交商
finish_business(PlayerStatus)->
	spawn(fun()->db_agent:mm_update_player_info([{carry_mark,0}],[{id,PlayerStatus#player.id}])end),
	PlayerStatus1 = PlayerStatus#player{carry_mark = 0},
	[BusinessInfo]=get_business(PlayerStatus#player.id),
	NewBusinessInfo = BusinessInfo#ets_business{color=4,current=0},
	update_business(NewBusinessInfo),
	db_agent:reset_business(PlayerStatus#player.id),
	%%通知所有玩家
    {ok,BinData2} = pt_12:write(12041,[PlayerStatus1#player.id,PlayerStatus1#player.carry_mark]),
	mod_scene_agent:send_to_area_scene(PlayerStatus1#player.scene,PlayerStatus1#player.x, PlayerStatus1#player.y, BinData2),
	del_business_info(PlayerStatus#player.id),
	{ok,PlayerStatus1}.

%%跑商信息重置
reset_business_info(PlayerStatus,Business,NowTime) ->
	[TotalTimes,NewColor] = case PlayerStatus#player.carry_mark>3 andalso PlayerStatus#player.carry_mark<8 of
								   true ->[1,PlayerStatus#player.carry_mark];
								   false->[0,4]
							   end,
	NewBusiness = Business#ets_business{times=TotalTimes,timestamp=NowTime,color=NewColor},
	update_business(NewBusiness),
	db_agent:reset_business_times(PlayerStatus#player.id,TotalTimes,NewColor,NowTime).

%%劫商
robbed_business(PlayerStatus,Pid)->
	case is_pid(Pid) of
		false->skip;
		true->
			case catch gen:call(Pid, '$gen_call', 'PLAYER', 2000) of
             	{'EXIT',_Reason} ->
              			skip;
             	{ok, Player} ->
					%%检查劫商次数
					case check_robbed_times(Player) of
						true->
							business_fail_mail(PlayerStatus,Player,1),
							skip;
						false->
							%%检查等级差
							case check_lv(PlayerStatus,Player) of
								false->
									business_fail_mail(PlayerStatus,Player,2),
									skip;
								true->
									[Business] = get_business(PlayerStatus#player.id),
									%%检查商车被劫次数
									case Business#ets_business.current >=1 of
										true->
											business_fail_mail(PlayerStatus,Player,3),
											skip;
										false->
											%%检查是否劫同一商车
											case get_business_count(PlayerStatus#player.id,Player#player.id) of
												true->
													business_fail_mail(PlayerStatus,Player,4),
													skip;
												false->
													%%计算劫商经验灵力
													{Exp,Spt}=base_award(Business#ets_business.color, PlayerStatus#player.lv, PlayerStatus#player.id),
													{NewExp,NewSpt} = case Business#ets_business.current of
																		  0->{round(Exp/2),round(Spt/2)};
																		  1->{round(Exp/4),round(Spt/4)};
																		  _->{0,0}
																	  end,
													if NewExp=:=0 orelse NewSpt=:= 0->
														   business_fail_mail(PlayerStatus,Player,3),
														   skip;
													   true->
														   %%获取劫商奖励
%% 														   get_robbed_award(Player,NewExp,NewSpt),
														   gen_server:cast(Player#player.other#player_other.pid_task,
																		   {'get_robbed_award',Player,NewExp,NewSpt}),
														   %%商车被劫
														   robbed_car(PlayerStatus,Business),
														   %%商车被劫通知邮件
														   business_mail(PlayerStatus,Player#player.nickname,2,NewExp,NewSpt),
														   %%劫商系统广播
														   business_broadcast(PlayerStatus,Player,3),
														   %%刷新已接任务列表
														   gen_server:cast(PlayerStatus#player.other#player_other.pid_task,
																		   {'trigger_task',PlayerStatus}),
														   add_business_info(PlayerStatus#player.id,Player#player.id),
														   %%添加劫商信息
														   gen_server:cast(Player#player.other#player_other.pid_task,
																		   {'robbed_info',Player#player.id,PlayerStatus#player.id,PlayerStatus#player.carry_mark}),
														   ok
													end
											end
									end
							end
					end
			end
	end.

%%判定等级差
check_lv(PlayerDie,PlayerLive)->
	case abs(PlayerLive#player.lv-PlayerDie#player.lv) > 10 of
		false->true;
		true->false
	end.

%%劫商奖励
get_robbed_award(PlayerStatus,Exp,Spt)->
%% 	NewPlayerStatus1 = lib_player:add_exp(PlayerStatus,Exp, 0, 0),
%% 	NewPlayerStatus2 = lib_player:add_spirit(NewPlayerStatus1,Spt),
%% 	ValueList = [{spirit,Spt,add}],
%% 	WhereList = [{id, PlayerStatus#player.id}],
%%     db_agent:mm_update_player_info(ValueList, WhereList),
%% 	gen_server:cast(NewPlayerStatus2#player.other#player_other.pid,{'SET_PLAYER',NewPlayerStatus2}),
%% 	lib_player:send_player_attribute(NewPlayerStatus2,1),
	gen_server:cast(PlayerStatus#player.other#player_other.pid,{'business',Exp,Spt}),
	business_mail(PlayerStatus,null,1,Exp,Spt),
	ok.

%%跑商获得奖励
add_business_award(PlayerStatus)->
	{Exp,_} = lib_business:get_business_award(PlayerStatus#player.id,PlayerStatus#player.lv),
	{ok,PlayerStatus_1} = lib_business:finish_business(PlayerStatus),
	PlayerStatus_2=lib_player:count_player_speed(PlayerStatus_1),
	lib_player:add_exp(PlayerStatus_2, Exp, 0,0).

%%商车被劫
robbed_car(PlayerStatus,Business)->
	 NewBusiness = Business#ets_business{current=Business#ets_business.current+1},
	 update_business(NewBusiness),
	 db_agent:robbed_car(PlayerStatus#player.id),
	 {ok, PkModeBinData} = pt_13:write(13012, [1, 1]),
	 lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, PkModeBinData),
	 NewPlayerStatus=PlayerStatus#player{pk_mode=1},
	 gen_server:cast(NewPlayerStatus#player.other#player_other.pid,{'SET_PLAYER',NewPlayerStatus}).

business_mail(PlayerStatus,Name,Type,Exp,Spt)->
	case Type of
		1->
			%%恭喜您劫商成功！获得XXX经验，XXX灵力。
			Content =io_lib:format( "恭喜您劫商成功！获得~p经验，~p灵力",[Exp,Spt]),
			mod_mail:send_sys_mail([tool:to_list(PlayerStatus#player.nickname)], "跑商信件", Content, 0, 0, 0, 0,0);
		_->
			%%您的商车被XXX（劫商人的名字）所劫，损失XXX经验，XXX灵力。您可以通过强化、经脉、诛邪等来快速提升您的实力。
			Content =io_lib:format( "您的商车被~s所劫，损失~p经验，~p灵力。您可以通过强化、经脉、诛邪、神器、坐骑等来快速提升您的实力。",[Name,Exp,Spt]),
			mod_mail:send_sys_mail([tool:to_list(PlayerStatus#player.nickname)], "跑商信件", Content, 0, 0, 0, 0,0)
	end.

business_fail_mail(PlayerStatus,Player,Type)->
	case Type of
		1->
			Content = "由于对方今天劫商次数已满，本次劫商不属于有效劫商，不损失任何经验与灵力!",
			Content1 = "由于您今天劫商次数已满，本次劫商不属于有效劫商，不获得任何经验与灵力!";
		2->
			Content = "由于双方的等级差大于10级，本次劫商不属于有效劫商，不损失任何经验与灵力!",
			Content1 = "由于双方的等级差大于10级，本次劫商不属于有效劫商，不获得任何经验与灵力!";
		3->
			Content = "由于您的商车已经被劫过，本次劫商不属于有效劫商，不损失任何经验与灵力!",
			Content1 = "由于对方的商车已经被劫过，本次劫商不属于有效劫商，不获得任何经验与灵力!";
		4->
			Content = "由于对方劫的是同一辆商车，本次劫商不属于有效劫商，不损失任何经验与灵力!",
			Content1 = "由于您劫的是同一辆商车，本次劫商不属于有效劫商，不获得任何经验与灵力!";
		_->
			Content = "由于劫商条件不满足，本次劫商不属于有效劫商，不损失任何经验与灵力!",
			Content1 = "由于劫商条件不满足，本次劫商不属于有效劫商，不获得任何经验与灵力!"
	end,
	mod_mail:send_sys_mail([tool:to_list(PlayerStatus#player.nickname)], "跑商信件", Content, 0, 0, 0, 0,0),
	mod_mail:send_sys_mail([tool:to_list(Player#player.nickname)], "跑商信件", Content1, 0, 0, 0, 0,0).

business_broadcast(PlayerBusiness,PlayerRobbed,Type)->
	case Type of
		1->
			if PlayerBusiness#player.carry_mark>5 andalso PlayerBusiness#player.carry_mark<8->
				   if PlayerBusiness#player.carry_mark =:= 7->
					erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerBusiness#player.other#player_other.pid, 312, [1]))end);
					true->skip
				 end,
				%%【XXX】帅气地拉着满是宝物的X色商车，正在前往XXX（对应部落的主城）的路上。
				 Msg = io_lib:format("【<a href='event:1,~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>】帅气地拉着满是宝物的<font color='~s'>~s</font>，正在前往雷泽商人的路上！！！",
									 [PlayerBusiness#player.id,PlayerBusiness#player.nickname,PlayerBusiness#player.career,PlayerBusiness#player.sex,PlayerBusiness#player.nickname,
									  get_color_by_id(PlayerBusiness#player.carry_mark),get_name_by_color(PlayerBusiness#player.carry_mark)]),
		   		lib_chat:broadcast_sys_msg(6,Msg);
			   true->skip
			end;
		2->
			%%经过一场激烈的厮杀，【XXX】成功保护了X色商车，并击退了【XXX】
			Msg = io_lib:format("经过一场激烈的厮杀，【<a href='event:1,~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>】成功保护了<font color='~s'>~s</font>，并击退了【<a href='event:1, ~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>】！！",
								[PlayerBusiness#player.id,PlayerBusiness#player.nickname,PlayerBusiness#player.career,PlayerBusiness#player.sex,PlayerBusiness#player.nickname,
								 get_color_by_id(PlayerBusiness#player.carry_mark),get_name_by_color(PlayerBusiness#player.carry_mark),
								 PlayerRobbed#player.id,PlayerRobbed#player.nickname,PlayerRobbed#player.career,PlayerRobbed#player.sex,PlayerRobbed#player.nickname]),
		   	lib_chat:broadcast_sys_msg(6,Msg);
		3->
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerRobbed#player.other#player_other.pid, 310, [PlayerBusiness#player.carry_mark,1]))end),
			%%经过一场激烈的厮杀，【XXX】成功劫取了X色商车，并击败了【XXX】
			Msg = io_lib:format("经过一场激烈的厮杀，【<a href='event:1,~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>】成功劫取了<font color='~s'>~s</font>，并击败了【<a href='event:1, ~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>】！！",
								[PlayerRobbed#player.id,PlayerRobbed#player.nickname,PlayerRobbed#player.career,PlayerRobbed#player.sex,PlayerRobbed#player.nickname,
								 get_color_by_id(PlayerBusiness#player.carry_mark),get_name_by_color(PlayerBusiness#player.carry_mark),
								 PlayerBusiness#player.id,PlayerBusiness#player.nickname,PlayerBusiness#player.career,PlayerBusiness#player.sex,PlayerBusiness#player.nickname]),
		   	lib_chat:broadcast_sys_msg(6,Msg);
		_->skip
	end.

get_color_by_id(Id)->
	case Id of 
		4->goods_util:get_color_hex_value(0);
		5->goods_util:get_color_hex_value(1);
		6->goods_util:get_color_hex_value(2);
		_->goods_util:get_color_hex_value(4)
	end.

get_name_by_color(Id)->
	case Id of
		4->"白色商车";
		5->"绿色商车";
		6->"蓝色商车";
		_->"紫色商车"
	end.

%%根据id获取部落主城名称
get_city_name_by_id(Id)->
	case Id of
		1->"女娲-娲皇城";
		2->"神农-华阳城";
		_->"伏羲-太昊城"
	end.
%%
%% Local Functions
%%

%%初始化跑商数据
init_business(PlayerId,Lv)->
	case db_agent:select_business(PlayerId) of
		[]->
			%插入新玩家数据
			NowTime = util:unixtime(),
			{_,Id}=db_agent:create_new_business(PlayerId,NowTime),
			Data = [Id,PlayerId,0,NowTime,4,Lv,0],
			EtsData = match_ets_playerinfo(Data),
 			update_business(EtsData);
		Result ->
				Data = match_ets_playerinfo(Result),
				update_business(Data)
	end.

match_ets_playerinfo(Data)->
	[Id,PlayerId,Times,Timestamp1,Color,LV,Current]= Data,
	#ets_business{
				  id=Id,
				  player_id=PlayerId,
				  times=Times,
				  timestamp = Timestamp1,
				  color=Color,
				  lv=LV,
				  current=Current
				 }.

%%加载跑商奖励
init_base_business() ->
    F = fun(Business) ->
			BusinessAward = list_to_tuple([ets_base_business|Business]),
            ets:insert(?ETS_BASE_BUSINESS, BusinessAward)
           end,
	L = db_agent:get_base_business(),
	lists:foreach(F, L),
    ok.

%%获取奖励信息
base_award(Color,Lv)->
	if Lv < 40 -> NewLv=30;
	   Lv < 50 -> NewLv=40;
	   Lv < 60 -> NewLv=50;
	   Lv < 70 -> NewLv=60;
	   Lv < 80 -> NewLv=70;
	   Lv < 90 -> NewLv=80;
	   true -> NewLv=90
	end,
	Pattern = #ets_base_business{color=Color,lv=NewLv,_='_'},
	case ets:match_object(?ETS_BASE_BUSINESS, Pattern) of
		[]->{0,0};
		[Award]->
			Aexp = Award#ets_base_business.exp,
			Aspt = Award#ets_base_business.spt,
			{Aexp,Aspt}
	end.

base_award(Color,Lv,PlayerId)->
	if Lv < 40 -> NewLv=30;
	   Lv < 50 -> NewLv=40;
	   Lv < 60 -> NewLv=50;
	   Lv < 70 -> NewLv=60;
	   Lv < 80 -> NewLv=70;
	   Lv < 90 -> NewLv=80;
	   true -> NewLv=90
	end,
	Pattern = #ets_base_business{color=Color,lv=NewLv,_='_'},
	case ets:match_object(?ETS_BASE_BUSINESS, Pattern) of
		[]->{0,0};
		[Award]->
			Now = util:unixtime(),
			{ST,ET,_BT} = get_double_time(),
			Aexp = Award#ets_base_business.exp,
			Aspt = Award#ets_base_business.spt,
			Ms = ets:fun2ms(fun(T) when T#role_task_log.player_id =:= PlayerId andalso
															 T#role_task_log.task_id >= 81001 andalso 
																				 T#role_task_log.task_id =< 81006
								  -> T#role_task_log.trigger_time end),
		    case ets:select(?ETS_ROLE_TASK_LOG,Ms) of
				[] -> 
					Ms2 = ets:fun2ms(fun(T) when T#role_task.player_id =:= PlayerId andalso 
																  T#role_task.task_id >= 81001 andalso 
																				 T#role_task.task_id =< 81006
										  -> T#role_task.trigger_time end),
					case ets:select(?ETS_ROLE_TASK,Ms2) of
						[] ->
							{Aexp,Aspt};
						[TriggerTime|_L] -> 
							case Now >= ST andalso Now<ET andalso TriggerTime >=ST andalso TriggerTime < ET of
								true ->
									{Aexp*2,Aspt*2};
								false ->
									{Aexp,Aspt}
							end
					end;
				List ->
					Latest = lists:max(List),
					case Now >= ST andalso Now<ET andalso Latest >=ST andalso Latest < ET of
						true ->
							{Aexp*2,Aspt*2};
						false ->
							{Aexp,Aspt}
					end
			end	
	end.

%%加载劫商数据
init_log_business(PlayerId)->
	RobbedList = db_agent:select_robbed_log(PlayerId),
	[
	 ets:insert(?ETS_LOG_ROBBED,#ets_log_robbed{id={Id1,PId1},player_id=PId1,robbed_id=RobbedId1,timestamp=Timestamp1})
	||[Id1,PId1,RobbedId1,Timestamp1] <-RobbedList
	].

%%获取跑商信息
get_business(PlayerId)->
	ets:lookup(?ETS_BUSINESS, PlayerId).

%%更新跑商信息
update_business(Business)->
	ets:insert(?ETS_BUSINESS,Business).

%%查询是否被该玩家劫过
get_business_count(PlayerId,RobbedId)->
	case select_business(PlayerId) of
		[]->false;
		[{_,Cache}]->
			lists:member(RobbedId, Cache)
	end.

select_business(PlayerId) ->
    ets:lookup(?ETS_SAME_CAR,PlayerId).

%%添加被劫商信息
add_business_info(PlayerId,RobbedId)->
	case select_business(PlayerId) of
		[]->ets:insert(?ETS_SAME_CAR, {PlayerId,[RobbedId]});
		[{_,Cache}]->ets:insert(?ETS_SAME_CAR, {PlayerId,[RobbedId|Cache]})
	end.

%%删除被劫商信息
del_business_info(PlayerId)->
	ets:match_delete(?ETS_SAME_CAR,{PlayerId,_='_'}).


%%添加劫商信息
add_robbed_info(PlayerId,RobbedId,Color)->
	NowTime = util:unixtime(),
	Id=db_agent:log_business_robbed(PlayerId,RobbedId,Color,NowTime),
	ets:insert(?ETS_LOG_ROBBED,#ets_log_robbed{id={Id,PlayerId},player_id=PlayerId,robbed_id=RobbedId,timestamp=NowTime}),
	ok.
%%统计劫商信息
get_robbed_count(PlayerId)->
	{TodaySec,TomorrowSec}=get_time(),
    length([0 || Business <- select_robbed(PlayerId), Business#ets_log_robbed.timestamp >= TodaySec, Business#ets_log_robbed.timestamp < TomorrowSec]).

select_robbed(PlayerId) ->
    ets:match_object(?ETS_LOG_ROBBED, #ets_log_robbed{player_id=PlayerId, _='_'}).

%%获取时间戳
get_time()->
	{M, S, MS} = now(),
    {_, Time} = calendar:now_to_local_time({M, S, MS}),
    TodaySec = M * 1000000 + S - calendar:time_to_seconds(Time),
    TomorrowSec = TodaySec + 86400,
	{TodaySec,TomorrowSec}.

%%检查劫商次数
check_robbed_times(PlayerStatus)->
	Times = case catch(gen_server:call(PlayerStatus#player.other#player_other.pid_task,{'business_robbed_times',PlayerStatus#player.id})) of
				{ok,Num}->Num;
				{'EXIT', _} -> 0
			end,
	Times >=3 .

%%玩家上线
online(PlayerStatus)->
	init_business(PlayerStatus#player.id,PlayerStatus#player.lv),
	init_log_business(PlayerStatus#player.id),
	ok.

%%玩家下线
offline(PlayerId)->
	del_business_info(PlayerId),
	ets:match_delete(?ETS_BUSINESS,#ets_business{player_id=PlayerId, _='_'}),
	ets:match_delete(?ETS_LOG_ROBBED,#ets_log_robbed{player_id=PlayerId, _='_'}).

%%购买令牌并开始跑商时要判断背包空间是否足够
check_bag_enough(PlayerStatus) ->
    (gen_server:call(PlayerStatus#player.other#player_other.pid_goods,{'cell_num'})) >= 1.

