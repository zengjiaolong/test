%% Author: xianrongMai
%% Created: 2012-3-5
%% Description: TODO: 活动类模块的处理接口
-module(lib_act_interf).

%%
%% Include files
%%

-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("activities.hrl").

%%
%% Exported Functions
%%
-export([
		 give_and_succeed/5,				%% 领取物品并且更新mid_award数据
		 march_consume_log/3,
		 check_mount_evolution_event/5,		%% 活动	坐骑进化，龙腾四海 (check)
		 check_artifact_color_step/6,		%% 活动	神器品质突破{每种奖励都有一次机会} (check)
		 get_artifact_color_step/6,			%% 活动	神器品质突破{每种奖励都有一次机会}(get)	
		 check_login_event/7,				%% 活动  登陆奖励(check)
		 get_login_event/9,					%% 活动  登陆奖励(get)
		 check_consume_count_event/8,		%% 活动	消费喜乐多(check)
		 march_arena_award_inner/1,
		 march_arena_award/0,				%% 竞技场排名奖励
		 check_player_arena_ranking/1,		%% 竞技场排名初始化数据
		 mount_rank_award/2,				%% 活动：坐骑大比拼	
		 mount_purple_skill/2,				%% 活动：紫魂助阵
		 march_count_consume/3,				%% 三月活动的消费统计
		 mayday_count_consume/3,			%% 五一活动的消费统计
		 manor_event_award/1,				%% 活动：农场收获随机触发奖励
		 check_player_linggen/1,			%% 活动：经脉速提升，保护免费送
		 check_fullstren_event/5,			%% 活动	全身强化，潜力无限(check)
		 get_fullstren_event/5,				%% 活动	全身强化，潜力无限(get)
		 fullstren_to_goodsid/1,			%% 全身强化对应的奖励物品Id
		 latern_activity_award/3,			%% 活动	任务达人，赢希望之种		
		 check_pet_aptitude/5,				%% 活动	灵兽资质大比拼{每种奖励都有一次机会}(check)
		 get_pet_aptitude/5,				%% 活动	灵兽资质大比拼{每种奖励都有一次机会}(get)
		 check_pet_grow/5,					%% 活动	灵兽成长大比拼{每种奖励都有一次机会}(check)
		 get_pet_grow/5,					%% 活动	灵兽成长大比拼{每种奖励都有一次机会}(get)	
		 get_pet_max_aptitude/1,			%% 获取灵兽最大资质,return -> the max aptitude (int)
		 get_god_pet/4,						%% 活动	领悟五阶神技，更有丰厚神兽蛋奖励
		 send_mail_petegg/3,				%% 活动	领悟五阶神技，更有丰厚神兽蛋奖励(发邮件的接口，仅此模块调用)
		 wardrobe_activited_award/2,		%% 活动	激活图鉴	
		 check_artifact/2,					%% 获取玩家神器的奖励数据,return -> is_tuple, {data, [{goods_id, Num, bind}], NeedCell, GiveNum}, {数据, 物品列表, 所需背包格子, 给予数量}
		 check_artifact_extra/2,			%% 获取玩家神器的奖励数据,return -> is_tuple, {data, [{goods_id, Num, bind, exprietime, trade}], NeedCell, GiveNum}, {数据, 物品列表, 所需背包格子, 给予数量}
		 delete_and_give/9					%% 删除物品发放物品的功能提取, return -> {ReturnType, Num}
		]).

%%
%% API Functions
%%
%% 删除物品发放物品的功能提取, return -> {ReturnType, Num}
delete_and_give(Player,DeleteType,DeleteNum,GiveType,GiveNum,Bind,ExpireTime,SuccessFun,SuccessFunArgs) ->
	case length(gen_server:call(Player#player.other#player_other.pid_goods,{'null_cell'})) > 0 of
		true ->%%优先扣绑定的
			case gen_server:call(Player#player.other#player_other.pid_goods,{'DELETE_MORE_BIND_PRIOR',DeleteType,DeleteNum}) of
				1 ->
					gen_server:call(Player#player.other#player_other.pid_goods, {'give_goods', Player,GiveType,GiveNum,Bind,ExpireTime}),
					case is_function(SuccessFun) of
						true ->
							erlang:apply(SuccessFun, SuccessFunArgs);
						false ->
							skip
					end,
					{ok, 1};
				2 ->%%物品不存在
					{fail, 4};
				3 ->%%数量不足
					{fail, 4};
				_ ->
					{fail,0}
			end;
		false ->
			{fail,3}
	end.

%% 活动：飞跃品阶
%% 活动：品质突破
%% 获取玩家神器的奖励数据,return -> is_tuple, {data, [{goods_id, Num, bind}], NeedCell, GiveNum}, {数据, 物品列表, 所需背包格子, 给予数量}
check_artifact(Pid, Type) ->
	Pattern = #ets_deputy_equip{pid = Pid, _='_'},
	DeputyInfo = goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern),
	case is_record(DeputyInfo,ets_deputy_equip) of
		true ->
			get_artifact_award(Type, DeputyInfo);
		false ->
			{10, [], 0, 0}
	end.

get_artifact_award(Type, DeputyInfo) ->
	case Type of
		step ->%%神器品阶
			case DeputyInfo#ets_deputy_equip.prof_lv of
				1 ->%%炼妖壶		太虚石*5
					{1, [{32027, 5, 2}], 1, 5};
				2 ->%%昆仑镜		太虚石*20
					{2, [{32027, 20, 2}], 1, 20};
				3 ->%%女娲石		精炼太虚石*20
					{3, [{32028, 20, 2}], 1, 20};
				4 ->%%神农鼎		精炼太虚石*50
					{4, [{32028, 50, 2}], 1, 40};
				5 ->%%崆峒印		精炼太虚石*100
					{5, [{32028, 100, 2}], 2, 100};
				6 ->%%昊天塔		精炼太虚石*200
					{6, [{32028, 200, 2}], 3, 200};
				7 ->%%镇妖剑		极品灵力丹*200，灵兽口粮*100
					{7, [{23306, 200, 2}, {24000, 100, 2}], 6, 250};
				_ ->%%不知道什么东西
					{10, [], 0, 0}
			end;
		color ->%%神器品质
			case DeputyInfo#ets_deputy_equip.color of
				0 ->%%白色	品质石*5
					{0, [{32021, 5, 2}], 1, 5};
				1 ->%%绿色	品质石*20
					{1, [{32021, 20, 2}], 1, 20};
				2 ->%%蓝色	品质石*40
					{2, [{32021, 40, 2}], 1, 40};
				3 ->%%金色	精炼品质石*60
					{3, [{32022, 60, 2}], 1, 60};
				4 ->%%紫色	玄石*80，高级铜币卡*100
					{4, [{32016, 80, 2}, {28002, 100, 2}], 3, 180};
				_ ->%%不知道什么东西
					{10, [], 0, 0}
			end
	end.

%% 活动：飞跃品阶
%% 活动：品质突破
%% 获取玩家神器的奖励数据,return -> is_tuple, {data, [{goods_id, Num, bind, exprietime, trade}], NeedCell, GiveNum}, {数据, 物品列表, 所需背包格子, 给予数量}
check_artifact_extra(Pid, Type) ->
	Pattern = #ets_deputy_equip{pid = Pid, _='_'},
	DeputyInfo = goods_util:get_ets_info(?ETS_DEPUTY_EQUIP,Pattern),
	case is_record(DeputyInfo,ets_deputy_equip) of
		true ->
			get_artifact_award_extra(Type, DeputyInfo);
		false ->
			{10, [], 0, 0}
	end.

get_artifact_award_extra(Type, DeputyInfo) ->
	case Type of
		step ->%%神器品阶
			case DeputyInfo#ets_deputy_equip.prof_lv of
				1 ->%%炼妖壶		太虚石*5
					{1, [{32027, 5, 2, 0, 0}], 1, 5};
				2 ->%%昆仑镜		太虚石*20
					{2, [{32027, 20, 2, 0, 0}], 1, 20};
				3 ->%%女娲石		精炼太虚石*20
					{3, [{32028, 20, 2, 0, 0}], 1, 20};
				4 ->%%神农鼎		精炼太虚石*50
					{4, [{32028, 50, 2, 0, 0}], 1, 40};
				5 ->%%崆峒印		精炼太虚石*100
					{5, [{32028, 100, 2, 0, 0}], 2, 100};
				6 ->%%昊天塔		精炼太虚石*200
					{6, [{32028, 200, 2, 0, 0}], 3, 200};
				7 ->%%镇妖剑		极品灵力丹*200，灵兽口粮*100
					{7, [{23306, 200, 2, 0, 0}, {24000, 100, 2}], 6, 250};
				_ ->%%不知道什么东西
					{10, [], 0, 0}
			end;
		color ->%%神器品质
			case DeputyInfo#ets_deputy_equip.color of
				0 ->%%白色	品质石*5
					{0, [{32021, 5, 2, 0, 0}], 1, 5};
				1 ->%%绿色	品质石*20
					{1, [{32021, 20, 2, 0, 0}], 1, 20};
				2 ->%%蓝色	品质石*40
					{2, [{32021, 40, 2, 0, 0}], 1, 40};
				3 ->%%金色	精炼品质石*60
					{3, [{32022, 60, 2, 0, 0}], 1, 60};
				4 ->%%紫色	玄石*80，高级铜币卡*100
					{4, [{32016, 80, 2, 0, 0}, {28002, 100, 2, 0, 0}], 3, 180};
				_ ->%%不知道什么东西
					{10, [], 0, 0}
			end
	end.

%% 活动：任务达人，赢希望之种					
latern_activity_award(OAct, NAct, PlayerId) ->
	%%判断是否 是 活动时间
	Now = util:unixtime(),
	case lib_activities:is_all_may_day_time(Now) of
		true ->
	GoodsList =
		if
			OAct < 30 andalso NAct >= 30 ->
				[{31235, 1}];%%【马兰花】*1
			OAct < 70 andalso NAct >= 70 ->
				[{31235, 1}];%%【马兰花】*1
			OAct < 120 andalso NAct >= 120 ->
				[{31235, 1}];%%【马兰花】*1
			OAct < 180 andalso NAct >= 180 ->
				[{31235, 1}];%%【马兰花】*1
			OAct < 190 andalso NAct >= 190 ->
				[{31229, 1}];%%【远古大转盘】*1		
			true ->
				[]
		end,
	Title = "任务达人奖励",
	case lib_player:get_role_name_by_id(PlayerId) of
		null ->%%找不到名字，OMG
			?WARNING_MSG("latern_activity_award can not find the player name and the id is ~p~n", [PlayerId]),
			skip;
		PName ->
			lists:foreach(fun(Elem) ->
								  {GoodsId, Num} = Elem,
								  GoodsTypeInfo = goods_util:get_goods_type(GoodsId),
								  if
									  %% 物品不存在
									  is_record(GoodsTypeInfo, ets_base_goods) =:= false ->
										  skip;
									  true ->
										  GoodsName = GoodsTypeInfo#ets_base_goods.goods_name,
										  Content = io_lib:format("一分耕耘，一分收获，付出总有回报！恭喜您活跃度达到~p获得[~s]*~p！感谢您的支持！",[NAct, GoodsName, Num]),
										  mod_mail:send_sys_mail([tool:to_list(PName)], Title, Content, 0, GoodsId, Num, 0, 0, 0)
								  end
						   end, GoodsList)
	end;
		false ->
			skip
	end.
%% 活动	领悟五阶神技，更有丰厚神兽蛋奖励	
%% 获取到N只五阶灵兽
get_god_pet(PlayerPid, PlayerName, PetNum, PetSkill) ->
	Now = util:unixtime(),
	%%对应的活动时间
	{TGStart, TGEnd} = lib_activities:consume_may_day_time(),
	if
		Now > TGStart andalso Now < TGEnd ->
			gen_server:cast(PlayerPid, {event, {lib_act_interf, send_mail_petegg, [PlayerName, PetNum, PetSkill]}});
		true ->
			skip
	end.

%%发邮件
send_mail_petegg(PlayerName, Num, PetSkill) ->
	NewMNum = trunc(Num * 10),
	Title = "五阶神技奖励",
	Content = io_lib:format("恭喜你获得[5阶~s],特发神兽蛋*10予以奖励,感谢你的支持！", [PetSkill]),
	NameList = [tool:to_list(PlayerName)],
	EggId = 24800,
	mod_mail:send_sys_mail(NameList, Title, Content, 0, EggId, NewMNum, 0, 0).

%% 活动	激活图鉴	
wardrobe_activited_award(PName, Num) ->
	case Num > 0 andalso Num < 3 of %%因为一件时装只有可能激活最多两个图鉴
		true ->%%有激活图鉴的
			%%判断是否 是 活动时间
			Now = util:unixtime(),
			case lib_activities:is_all_may_day_time(Now) of
				true ->
					GoodsId = 28841, %%时装礼包
					Title = "衣橱奖励",
					Content = io_lib:format("夏日时装大放送！恭喜您成功激活了~p个衣橱图鉴，特此获得时装礼包*~p，感谢您的支持！",[Num, Num]),
					mod_mail:send_sys_mail([tool:to_list(PName)], Title, Content, 0, GoodsId, Num, 0, 0, 0);
				false ->
					skip
			end;
		false ->
			skip
	end.

%% 活动	全身强化，潜力无限(check)
check_fullstren_event(NowTime, TGStart, TGEnd, Player, EventType) ->
		#player{id = PlayerId,
			other = PlayerOther} = Player,
	case NowTime > TGStart andalso NowTime < TGEnd of
		true ->
			FullStren = PlayerOther#player_other.fullstren,
			%%					?DEBUG("FullStren:~p", [FullStren]),
			if
				FullStren =/= undefined andalso FullStren >= 5 andalso FullStren =< 10 ->
					case db_agent:get_mid_prize(PlayerId, EventType) of
						[_Id,_Mpid,_Mtype,_Mnum,Got] ->
							if
								Got > 0 ->%%已经领取
									[FullStren, 2];
								true ->
									[FullStren, 1]
							end;
						[] ->%% 没有记录
							db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,EventType,0,0]),
							[FullStren, 1]
					end;
				true ->
					[0, 0]
			end;
		false ->
			[0,0]
	end.

%% 活动	全身强化，潜力无限(get)
get_fullstren_event(NowTime, TGStart, TGEnd, Player, EventType) ->
	#player{id = PlayerId,
			other = PlayerOther} = Player,
	case NowTime > TGStart andalso NowTime < TGEnd of
		true ->
			FullStren = PlayerOther#player_other.fullstren,
			if
				FullStren =/= undefined andalso FullStren >= 5 andalso FullStren =< 10->
					case db_agent:get_mid_prize(PlayerId, EventType) of
						[Id,_Mpid,_Mtype,_Mnum,Got] ->
							if
								Got > 0 ->%%已经领取
									{fail, 0};
								true ->
									GoodsId = lib_act_interf:fullstren_to_goodsid(FullStren),
									case catch (gen_server:call(PlayerOther#player_other.pid_goods, 
																{'give_goods', Player, GoodsId, 1, 2})) of
										ok ->
											%%领取成功更新记录
											db_agent:update_mid_prize([{got, 1}],[{id,Id}]),
											{ok,1};
										cell_num ->%%背包空间不足
											{fail,3};
										_ ->%%其他报错，OMG
											{fail,0}
									end
							end;
						[] ->
							{fail, 0}
					end;
				true ->
					{fail, 0}
			end;
		false ->
			{fail, 5}
	end.

%% 活动：全身强化，潜力无限	
fullstren_to_goodsid(FullStren) ->
	case FullStren of
		5 -> %%+5 全身+5礼包
			31029;
		6 ->%%+5 全身+5礼包
			31029;
		7 -> %%+7 全身+7礼包
			31030;
		8 -> %%+8 全身+8礼包
			31031;
		9 -> %%+9 全身+9礼包
			31032;
		10 -> %%+10 全身+10礼包
			31033;
		_ ->
			0
	end.

%%活动：经脉速提升，保护免费送		
%% 0 ->什么都没
%% 1 ->全身经脉灵根达到50
%% 2 ->全身经脉灵根达到60
%% 3 ->全身经脉灵根达到70
%% 4 ->全身经脉灵根达到80
%% 5 ->全身经脉灵根达到90
check_player_linggen(PId) ->
	case lib_meridian:get_player_meridian_info(PId) of
		[] ->
			0;
		[Meri|_] ->
			LinGen = [Meri#ets_meridian.mer_yang_linggen, Meri#ets_meridian.mer_yin_linggen, 
					  Meri#ets_meridian.mer_wei_linggen, Meri#ets_meridian.mer_ren_linggen, 
					  Meri#ets_meridian.mer_du_linggen, Meri#ets_meridian.mer_chong_linggen, 
					  Meri#ets_meridian.mer_qi_linggen, Meri#ets_meridian.mer_dai_linggen],
			lists:foldl(fun(Elem, AccIn) ->
								if Elem >= 90 ->%%灵根90
									   AccIn;
								   Elem >= 80 ->%%灵根80
									   case AccIn >= 5 of
										   true ->
											   4;
										   false ->
											   AccIn
									   end;
								   Elem >= 70 ->%%灵根70
									   case AccIn >= 4 of
										   true ->
											   3;
										   false ->
											   AccIn
									   end;
								   Elem >= 60 ->%%灵根60
									   case AccIn >= 3 of
										   true ->
											   2;
										   false ->
											   AccIn
									   end;
								   Elem >= 50 ->%%灵根50
									   case AccIn >= 2 of
										   true ->
											   1;
										   false ->
											   AccIn
									   end;
								   true ->
									   0
								end
						end, 5, LinGen)
	end.

%% 活动：农场收获随机触发奖励
manor_event_award(Player) ->
	%%判断是否 是 植树节活动时间
	Now = util:unixtime(),
	case lib_activities:is_arborday_time(Now) of
		true ->
			Num = util:rand(1, 100),
%% 			?DEBUG("Num:~p", [Num]),
			case Num =<  30 of
				true ->
					Goodsid = 31234,%%木之灵
					case catch (gen_server:call(Player#player.other#player_other.pid_goods, 
												{'give_goods', Player, Goodsid, 1, 2})) of
						ok ->%%领取成功
							{ok,BinData} = pt_15:write(15018,[[[Goodsid,1]]]),
							lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
							1;
						cell_num ->%%背包空间不足
							Title = "意外收获",
							NameList = [tool:to_list(Player#player.nickname)],
							Content = io_lib:format("恭喜您收获果实的时候，意外获得【木之灵】*1！由于您背包已满，特此补发。",[]),
							mod_mail:send_sys_mail(NameList, Title, Content, 0, Goodsid, 1, 0, 0, 0);
						_OtherError ->
							skip
					end;
				false ->
					skip
			end;
		false ->
			skip
	end.
%%三月活动的消费统计
march_count_consume(PlayerId, TGStart, TGEnd) ->
	%%获取活动消费日志
	Logs = march_consume_log(PlayerId, TGStart, TGEnd),
	case length(Logs) > 0 of
		true ->
			lists:foldl(fun(Elem, AccIn) ->
								[_, EG] = Elem,
								AccIn + EG
						end, 0, Logs);
		false ->
			0
	end.
%%获取三月活动的消费日志
%% 商城购买 1561 诛邪2802 封神台神秘商店2151 经验找回3315 灵兽猎魂1604 
%% 自动购买1575, 1576, 1577, 1578, 1579, 1580, 1581, 1582, 1584, 1585, 1586, 1587, 1588, 1605, 1606, 2503, 4107, 4108, 4109, 4106, 1571
march_consume_log(Pid, BeginTime, EndTime) -> 
	db_agent:get_consume_log([{pid,Pid},{ct,">",BeginTime},{ct,"<",EndTime},{type,"gold"},
							  {pit,"in", [1561, 2802, 2151, 3315, 1604, 1575, 1576, 1577, 1578, 1579, 1580, 1581, 1582, 1584, 1585, 1586, 1587, 1588, 
										  1605, 1606, 2503, 4107, 4108, 4109, 4106, 1571]},{oper,0}]).

%% 五一活动的消费统计
mayday_count_consume(PlayerId, TGStart, TGEnd) ->
	%%获取活动消费日志
	Logs = mayday_consume_log(PlayerId, TGStart, TGEnd),
	case length(Logs) > 0 of
		true ->
			lists:foldl(fun(Elem, AccIn) ->
								[_, EG] = Elem,
								AccIn + EG
						end, 0, Logs);
		false ->
			0
	end.
%%获取五一活动的消费日志
%% 商城购买 1561 诛邪2802 封神台神秘商店2151 经验找回3315 灵兽猎魂1604 
%% 自动购买1575, 1576, 1577, 1578, 1579, 1580, 1581, 1582, 1584, 1585, 1586, 1587, 1588, 1605, 1606, 2503, 4107, 4108, 4109, 4106, 1571
%% 灵兽技能 4110 4111
mayday_consume_log(Pid, BeginTime, EndTime) -> 
	db_agent:get_consume_log([{pid,Pid},{ct,">",BeginTime},{ct,"<",EndTime},{type,"gold"},
							  {pit,"in", [1561, 2802, 2151, 3315, 1604, 1575, 1576, 1577, 1578, 1579, 1580, 1581, 1582, 1584, 1585, 1586, 1587, 1588, 
										  1605, 1606, 2503, 4107, 4108, 4109, 4106, 1571, 4110, 4111]},{oper,0}]).

%%三月活动
%%活动五：紫魂助阵	
mount_purple_skill(PName, Color) ->
	NowTime = util:unixtime(),
	case Color of
		4 ->
			case lib_activities:is_march_event_time(NowTime) of
				true ->
					Title = "紫色精魂",
					NameList = [tool:to_list(PName)],
					Content = io_lib:format("恭喜您鸿运降临，猎取到珍贵的紫色精魂，特此奖励小礼券*5，祝您好运连连。",[]),
					mod_mail:send_sys_mail(NameList, Title, Content, 0, 28024, 5, 0, 0, 0);
				false ->
					skip
			end;
		_ ->
			skip
	end.

%%活动六：坐骑大比拼	
mount_rank_award(PName, Rank) ->
	{GoodsId, Num, GoodsName} = 
		if
			Rank =:= 1 ->					%%1	坐骑大福袋*5	
				{28837, 5, "坐骑大福袋"};
			Rank =:= 2 ->					%%2	坐骑大福袋*3	
				{28837, 3, "坐骑大福袋"};
			Rank =:= 3 ->					%%3	坐骑大福袋*2	
				{28837, 2, "坐骑大福袋"};
			Rank >= 4 andalso Rank =< 5 ->	%%4～5	坐骑小福袋*2	
				{28836, 2, "坐骑小福袋"};
			Rank >= 6 andalso Rank =< 10 ->	%%6～10	坐骑小福袋*1	
				{28836, 1, "坐骑小福袋"};
			true ->
				{0, 0, ""}
		end,
	case GoodsId of
		0 ->
			skip;
		_O ->
			Title = "坐骑奖励",
			Content = io_lib:format("恭喜您荣登坐骑榜第~p名，特此奖励【~s】*【~p】，感谢您的支持。",[Rank, GoodsName, Num]),
			mod_mail:send_sys_mail([tool:to_list(PName)], Title, Content, 0, GoodsId, Num, 0, 0, 0)
	end.
%%三月活动
%%活动七：飞跃竞技场		
arena_jump_award(PName, Jump) ->
	GoodsList = 
		if
			Jump >= 100 ->
				[{23503, 10, "大修为丹"},{28023, 10, "绑定铜币卡"}];
			Jump >= 50 andalso Jump =< 99 ->
				[{23503, 5, "大修为丹"},{28023, 5, "绑定铜币卡"}];
			Jump >= 20 andalso Jump =< 49 ->
				[{23503, 2, "大修为丹"},{28023, 2, "绑定铜币卡"}];
			Jump >= 5 andalso Jump =< 19 ->
				[{23503, 1, "大修为丹"},{28023, 1, "绑定铜币卡"}];
			true ->
				[]
		end,
	case GoodsList of
		[] ->
			skip;
		_O ->
			lists:foreach(fun(Elem) ->
								  {GoodsId, Num, GoodsName} = Elem,
								  Title = "竞技场奖励",
								  Content = io_lib:format("恭喜您在活动期间竞技场名次提升了【~p】位，特此奖励【~s】*【~p】，感谢您的支持。",[Jump, GoodsName, Num]),
								  mod_mail:send_sys_mail([tool:to_list(PName)], Title, Content, 0, GoodsId, Num, 0, 0, 0)
						  end, GoodsList)
	end.
	
%%竞技场排名初始化数据
check_player_arena_ranking(Player) ->
	Now = util:unixtime(),
	%%三月活动时间
	{TGStart, TGEnd} = lib_activities:march_event_time(),
	%% 			判断是否是在活动指定的时间段里
	case Now > TGStart andalso Now < TGEnd andalso Player#player.lv >= 30 of
		true ->
			
			case db_agent:get_mid_prize(Player#player.id ,4) of
				[_Id,_Mpid,_Mtype,_Mnum,_Got] ->
					skip;
				_ ->
%% 					?DEBUG("check_player_arena_ranking", []),
					PRank = lib_coliseum:get_player_coliseum_rank(Player#player.id),
					db_agent:insert_mid_prize([pid,type,num,got],[Player#player.id,4,0,PRank])
			end;
		false ->
			skip
	end.

%%竞技场排名奖励
march_arena_award() ->
%% 	?DEBUG("march_arena_award", []),
	Fields = "pid,got",
	case db_agent:select_type_mid_award(4, Fields) of
		[] ->
			skip;
		List ->
%% 			?DEBUG("the list is: ~p", [List]),
			gen_server:cast(mod_coliseum_supervisor:get_coliseum_worker_pid(),
							{apply_cast, lib_act_interf, march_arena_award_inner, [List]})
	end.
march_arena_award_inner(List) ->
%% 	?DEBUG("march_arena_award_inner:~p", [List]),
	lists:foreach(fun([Pid, Rank]) ->
						  case ets:lookup(?ETS_COLISEUM_RANK, Pid) of
							  [] ->
								  skip;
							  [ColiseumPlayer | _] ->
								  #ets_coliseum_rank{rank = NRank,
													 nickname = PName} = ColiseumPlayer,
								  Jump = Rank - NRank,
								  arena_jump_award(PName, Jump)
						  end
				  end, List).

%% 活动	消费喜乐多(check)	
check_consume_count_event(NowTime, TGStart, TGEnd, PlayerId, Module, CountFun, EventType, CountBase) ->
	case NowTime > TGStart andalso NowTime < TGEnd of
		true ->
			Sum = Module:CountFun(PlayerId, TGStart, TGEnd),
			case Sum > 0 of
				true ->
					Count = Sum div CountBase,
					case db_agent:get_mid_prize(PlayerId ,EventType) of
						[_Id,_Mpid,_Mtype,_Mnum,Got] ->
							if
								Count > Got ->
									Rest = trunc(Sum - Got * CountBase),
									[Rest, 1];
								true ->
									Rest = trunc(Sum - Got * CountBase),
									NRest = 
										case Rest >= 0 of
											true ->
												Rest;
											false ->
												0
										end,
									[NRest, 0]
							end;
						[] ->
							%% 没有记录
							db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,EventType,0,0]),
							case Count >= 1 of
								true ->
									[Sum, 1];
								false ->
									[Sum, 0]
							end
					end;
				false ->
					[0,0]
			end;
		false ->
			[0,0]
	end.

%% 活动  登陆奖励(check)
check_login_event(NowTime, TGStart, TGEnd, PlayerId, PLv, EventType, LvNeed) ->
	case PLv >= LvNeed of
		true ->%%等级限制
			case NowTime > TGStart andalso NowTime < TGEnd of
				true ->%%是否在时间里
					case db_agent:get_mid_prize_extradata(PlayerId ,EventType) of
						[Id,_Mpid,_Mtype,Mnum,Got,DataStr] ->
							UpdataTime = util:string_to_term(tool:to_list(DataStr)),
							case util:is_same_date(NowTime, UpdataTime) of
								true ->
									if
										Mnum > Got ->
											[Mnum - Got, 1];
										Got > Mnum ->%%更新错误的那些bug
											NDataStr = util:term_to_string(NowTime),
											db_agent:update_mid_prize([{num, Got},{got, Got-1}, {other, NDataStr}],[{id,Id}]),
											[1, 1];
										true ->
											[0, 2]
									end;
								false ->
									NDataStr = util:term_to_string(NowTime),
									db_agent:update_mid_prize([{num, Mnum+1}, {other, NDataStr}],[{id,Id}]),
									[1, 1]
							end;
						[] ->
							%% 没有记录
							NDataStr = util:term_to_string(NowTime),
							db_agent:insert_mid_prize([pid,type,num,got,other],[PlayerId,EventType,1,0,NDataStr]),
							[1, 1]
					end;
				false ->
					[0, 0]
			end;
		false ->
			[0, 0]
	end.

%% 活动  登陆奖励(get)
%%GoodsList = [{GoodsTypeId, GoodsNum,Bind,Expire,Trade},...]
get_login_event(NowTime, TGStart, TGEnd, Player, PLv, EventType, LvNeed, GoodsList, NeedCell) ->
	PlayerId = Player#player.id,
	case PLv >= LvNeed of
		true ->%%等级限制
			case NowTime > TGStart andalso NowTime < TGEnd of
				true ->%%是否在时间里
					case db_agent:get_mid_prize(PlayerId ,EventType) of
						[Id,_Mpid,_Mtype,MNum,Got] ->
							if
								MNum > Got ->
									%%成功时执行方法
									SuccFun = fun(WereList, ValueList) ->
													  db_agent:update_mid_prize(ValueList,WereList)
											  end,
									SuccParam = [[{id,Id}],[{got,Got+1}]],
									give_and_succeed(Player, GoodsList, SuccFun, SuccParam, NeedCell);
								true ->
									{fail, 0}
							end;
						_ ->
							{fail, 0}
					end;
				false ->
					{fail, 0}
			end;
		false ->
			{fail, 0}
	end.

%% 活动	坐骑进化，龙腾四海 (check)		
check_mount_evolution_event(NowTime, TGStart, TGEnd, PlayerId, EventType) ->
	case NowTime > TGStart andalso NowTime < TGEnd of
		true ->%%是否在时间里
			AllMount = lib_mount:get_all_mount(PlayerId),
			case length(AllMount) > 0 of
				true ->
					F_step = fun(MountInfo,MaxStep) ->
									 if
										 MountInfo#ets_mount.step > MaxStep ->
											 MountInfo#ets_mount.step;
										 true ->
											 MaxStep
									 end
							 end,
					Step = lists:foldl(F_step, 0, AllMount),
					case db_agent:get_mid_prize(PlayerId,EventType) of
						[_Id,_Mpid,_Mtype,_Mnum,Got] ->
							if
								Step > Got ->
									[Step,1];
								true ->
									[Step,0]
							end;
						_ ->
							db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,EventType,Step,0]),
							[Step,1]
					end;
				false ->
					[1,0]
			end;
		false ->
			[0,0]
	end.

%% 活动	神器品质突破{每种奖励都有一次机会} (check)		
check_artifact_color_step(NowTime, TGStart, TGEnd, PlayerId, EventType, Type) ->
	case NowTime > TGStart andalso NowTime < TGEnd of
		true ->%%是否在时间里
			{Data, Check, _Cell, _NGiveNum} = lib_act_interf:check_artifact_extra(PlayerId, Type),
%% 			?DEBUG("EventType:~p, Type:~p, Data:~p, Check:~p, _Cell:~p, _NGiveNum:~p", [EventType, Type, Data, Check, _Cell, _NGiveNum]),
			case Check of
				[] ->
					[10, 0];
				_ ->
					case db_agent:get_mid_prize(PlayerId,EventType) of
						[_Id,_Mpid,_Mtype,_Mnum,Got] ->
							if
								Data > Got ->
									[Data,1];
								true ->
									[Data,0]
							end;
						[] ->
							[Data,1]
					end
			end;
		false ->
			[0,0]
	end.

%% 活动	神器品质突破{每种奖励都有一次机会}(get)		
get_artifact_color_step(Player, NowTime, TGStart, TGEnd, EventType, Type) ->
	PlayerId = Player#player.id,
	case NowTime > TGStart andalso NowTime < TGEnd of
		true ->%%是否在时间里
			{Data, Check, _Cell, _NGiveNum} = lib_act_interf:check_artifact_extra(PlayerId, Type),
%% 			?DEBUG("EventType:~p, Type:~p,Data:~p, Check:~p, _Cell:~p, _NGiveNum:~p", [EventType, Type, Data, Check, _Cell, _NGiveNum]),
			case Check of
				[] ->
					{fail, 0};
				_ ->
					case db_agent:get_mid_prize(PlayerId, EventType) of
						[Id,_Mpid,_Mtype,_Mnum,Got] ->
							if
								Got >= Data ->%%已经领取
									{fail, 0};
								true ->
									%%成功时执行方法
									SuccFun = fun(WereList, ValueList) ->
													  db_agent:update_mid_prize(ValueList,WereList)
											  end,
									SuccessFunArgs = [[{id,Id}],[{got,Data}]],
									lib_act_interf:give_and_succeed(Player, Check, SuccFun, SuccessFunArgs, 1),
									{ok, 1}
							end;
						[]->%% 没有记录
							%%成功时执行方法
							SuccFun = fun(Fields, Values) ->
											  db_agent:insert_mid_prize(Fields, Values)
									  end,
							SuccessFunArgs = [[pid,type,num,got],[PlayerId,EventType,0,Data]],
							lib_act_interf:give_and_succeed(Player, Check, SuccFun, SuccessFunArgs, 1),
							{ok, 1}
					end
			end;
		false ->
			{fail, 0}
	end.


%% 活动	灵兽资质大比拼{每种奖励都有一次机会}(check)		
check_pet_aptitude(NowTime, TGStart, TGEnd, PlayerId, EventType) ->
	case NowTime > TGStart andalso NowTime < TGEnd of
		true ->%%是否在时间里
			Aptitude = get_pet_max_aptitude(PlayerId),
			if 
				Aptitude >= 40 ->
					case db_agent:get_mid_prize(PlayerId, EventType) of
						[_Id,_Mpid,_Mtype,_Mnum,Got] ->
							if
								Got >= Aptitude ->%%已经领取
									[Aptitude, 2];
								true ->
									[Aptitude, 1]
							end;
						[] ->%% 没有记录
							db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,EventType,0,0]),
							[Aptitude, 1]
					end;
				true ->
					[Aptitude, 0]
			end;
		false ->
			[0,0]
	end.

%% 活动	灵兽资质大比拼{每种奖励都有一次机会}(get)		
get_pet_aptitude(Player, NowTime, TGStart, TGEnd, EventType) ->
	PlayerId = Player#player.id,
	case NowTime > TGStart andalso NowTime < TGEnd of
		true ->%%是否在时间里
			Aptitude = get_pet_max_aptitude(PlayerId),
			if 
				Aptitude >= 40 ->
					case db_agent:get_mid_prize(PlayerId, EventType) of
						[Id,_Mpid,_Mtype,_Mnum,Got] ->
							if
								Got >= Aptitude ->%%已经领取
									{fail, 0};
								true ->
									{GoodsList, NGot} = 
										if 
											Aptitude >= 40 andalso Aptitude < 50 ->%%	40	灵兽资质符*2	
												{{24400, 2, 2, 0, 0}, 49};
											Aptitude >= 50 andalso Aptitude < 60 ->%%	50	灵兽保护符*1	
												{{24401, 1, 2, 0, 0}, 59};
											Aptitude >= 60 andalso Aptitude < 70 ->%%	60	灵兽保护符*2	
												{{24401, 2, 2, 0, 0}, 69};
											Aptitude >= 70 andalso Aptitude < 80 ->%%	70	灵兽保护符*4	
												{{24401, 4, 2, 0, 0}, 79};
											Aptitude >= 80 andalso Aptitude < 90 ->%%	80	灵兽保护符*6	
												{{24401, 6, 2, 0, 0}, 89};
											Aptitude >= 90 andalso Aptitude < 100 ->%%	90	灵兽保护符*8	
												{{24401, 8, 2, 0, 0}, 99};
											Aptitude >= 100 ->%%	100	神兽蛋*15	
												{{24800, 15, 2, 0, 0}, 109};
											true ->
												{{0,0,0,0}, 0}
										end,
									%%成功时执行方法
									SuccFun = fun(WereList, ValueList) ->
													  db_agent:update_mid_prize(ValueList,WereList)
											  end,
									SuccessFunArgs = [[{id,Id}],[{got,NGot}]],
									if 
										NGot =:= 0 ->
											{fail, 0};
										true ->
											lib_act_interf:give_and_succeed(Player, GoodsList, SuccFun, SuccessFunArgs, 1),
											{ok, 1}
									end
							end;
						_->%% 没有记录
							{fail, 0}
					end;
				true ->
					{fail, 0}
			end;
		false ->
			{fail, 0}
	end.
			
%%获取灵兽最大资质,return -> the max aptitude (int)
get_pet_max_aptitude(PlayerId)->
	PetList = lib_pet:get_all_pet(PlayerId),
	lists:foldl(fun(Elem, AccIn) ->
						case Elem#ets_pet.aptitude >= AccIn of
							true ->
								Elem#ets_pet.aptitude;
							false ->
								AccIn
						end
				end, 0, PetList).

%% 活动	灵兽成长大比拼{每种奖励都有一次机会}(check)		
check_pet_grow(NowTime, TGStart, TGEnd, PlayerId, EventType) ->
	case NowTime > TGStart andalso NowTime < TGEnd of
		true ->%%是否在时间里
			[Grow,_] = lib_pet:get_pet_max_apt_grow(PlayerId,2),
			if 
				Grow >= 30 ->
					case db_agent:get_mid_prize(PlayerId, EventType) of
						[_Id,_Mpid,_Mtype,_Mnum,Got] ->
							if
								Got >= Grow ->%%已经领取
									[Grow, 2];
								true ->
									[Grow, 1]
							end;
						[] ->%% 没有记录
							db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,EventType,0,0]),
							[Grow, 1]
					end;
				true ->
					[Grow, 0]
			end;
		false ->
			[0,0]
	end.

%% 活动	灵兽成长大比拼{每种奖励都有一次机会}(get)		
get_pet_grow(Player, NowTime, TGStart, TGEnd, EventType) ->
	PlayerId = Player#player.id,
	case NowTime > TGStart andalso NowTime < TGEnd of
		true ->%%是否在时间里
			[Grow,_] = lib_pet:get_pet_max_apt_grow(PlayerId,2),
			if 
				Grow >= 30 ->
					case db_agent:get_mid_prize(PlayerId, EventType) of
						[Id,_Mpid,_Mtype,_Mnum,Got] ->
							if
								Got >= Grow ->%%已经领取
									{fail, 0};
								true ->
									{GoodsList, NGot} = 
										if 
											Grow >= 30 andalso Grow < 40 ->%%	30	灵兽成长丹*1	
												{{24104, 1, 2, 0, 0}, 39};
											Grow >= 40 andalso Grow < 50 ->%%	40	成长保护丹*1	
												{{24105, 1, 2, 0, 0}, 49};
											Grow >= 50 andalso Grow < 60 ->%%	50	成长保护丹*2	
												{{24105, 2, 2, 0, 0}, 59};
											Grow >= 60 andalso Grow < 70 ->%%	60	成长保护丹*4	
												{{24105, 4, 2, 0, 0}, 69};
											Grow >= 70 andalso Grow < 80 ->%%	70	成长保护丹*6	
												{{24105, 6, 2, 0, 0}, 79};
											Grow >= 80 ->%%	80	神兽蛋*15	
												{{24800, 15, 2, 0, 0}, 99};
											true ->
												{{0,0,0,0}, 0}
										end,
									%%成功时执行方法
									SuccFun = fun(WereList, ValueList) ->
													  db_agent:update_mid_prize(ValueList,WereList)
											  end,
									SuccessFunArgs = [[{id,Id}],[{got,NGot}]],
									if 
										NGot =:= 0 ->
											{fail, 0};
										true ->
											lib_act_interf:give_and_succeed(Player, GoodsList, SuccFun, SuccessFunArgs, 1),
											{ok, 1}
									end
							end;
						_->%% 没有记录
							{fail, 0}
					end;
				true ->
					{fail, 0}
			end;
		false ->
			{fail, 0}
	end.

%% 领取物品并且更新mid_award数据
give_and_succeed(Player, GoodsList, SuccessFun, SuccessFunArgs, NeedCell) ->
	case length(gen_server:call(Player#player.other#player_other.pid_goods,{'null_cell'})) > NeedCell of
		true ->
			case gen_server:call(Player#player.other#player_other.pid_goods,{'give_more',Player,GoodsList}) of
				ok ->
					case is_function(SuccessFun) of
						true ->
							erlang:apply(SuccessFun,SuccessFunArgs);
						false ->
							skip
					end,
					{ok,1};
				_ ->
					{fail,0}
			end;
		false ->
			{fail,3}
	end.


