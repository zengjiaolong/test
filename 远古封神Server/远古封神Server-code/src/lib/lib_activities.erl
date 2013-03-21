%% Author: zj
%% Created: 2011-11-4
%% Description: TODO: 节日活动相关归类
-module(lib_activities).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("activities.hrl").
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
%% 临时活动类型10
%% 根据时间范围消费领取礼包
tmp_activity(Player,Type,GoodsList) ->
	Now = util:unixtime(),
	if
		Now > ?HOLIDAY_BEG_TIME andalso Now < ?HOLIDAY_END_TIME ->
			ConsumeLog = get_consume_log(Player#player.id, ?HOLIDAY_BEG_TIME, ?HOLIDAY_END_TIME),
			PayLog = get_pay_log(Player#player.id, ?HOLIDAY_BEG_TIME, ?HOLIDAY_END_TIME),
			%%消费元宝数
			ConsumeSum = 
				case length(ConsumeLog) > 0 of
					true ->
						F0 = fun([_,G0]) ->
										G0
								end,
						lists:sum(lists:map(F0, ConsumeLog));
					false ->
						0
				end,
			%%充值元宝数
			PaySum = 
				case length(PayLog) > 0 of
					true ->
						F1 = fun([_,G1]) ->
										G1
								end,
						lists:sum(lists:map(F1, PayLog));
					false ->
						0
				end,
			%%总积分
			TotalScore = trunc(ConsumeSum * 0.5 + PaySum * 0.5),
			case Type of
				1 ->				
					case db_agent:get_mid_prize(Player#player.id,10) of
						[_Id,_Mpid,_Mtype,_Mnum,Got] ->
							%% 有记录
							if
								TotalScore > Got ->
									[1,TotalScore - Got];
								true ->
									[1 , 0]
							end;
						[] ->
							%% 没有记录
							db_agent:insert_mid_prize([pid,type,num,got],[Player#player.id,10,0,0]),
							[1, TotalScore]
					end;
				2 ->
					%%兑换
					F_count = 
						fun(GoodsId) ->
									case GoodsId of
										31035 ->500;
										31036 ->1000;
										31037 ->3000;
										31038 ->5000;
										31039 ->10000;
										31040 ->20000;
										31041 ->30000;
										31042 ->50000;
										_ ->1000000000
									end
						end,
					Tscore = lists:sum(lists:map(F_count, GoodsList)),
					case db_agent:get_mid_prize(Player#player.id,10) of
						[Id,_Mpid,_Mtype,_Mnum,Got] ->
							if
								TotalScore > Got andalso Tscore =< (TotalScore - Got)->
									case length(gen_server:call(Player#player.other#player_other.pid_goods,{'null_cell'})) > length(GoodsList) of
										true ->
											F_give = fun(GoodsId2) ->
														gen_server:call(Player#player.other#player_other.pid_goods, {'give_goods', Player,GoodsId2, 1})
														end,
											lists:foreach(F_give, GoodsList),
											%%领取成功更新记录
											db_agent:update_mid_prize([{got,Tscore + Got}],[{id,Id}]),
											[1,TotalScore - Tscore - Got ];
										false ->
											[4,TotalScore - Got]
									end;
								true ->
									[2,TotalScore - Got]
							end;
						_ ->
							[0,0]
					end;
				_ ->
					[0,0]
			end;
		true ->
			[3,0]
	end.

%% 获取国庆活动信息
%% 1317398400 - 1318003200 %%国庆
send_holiday_award(PlayerId,Type,SubType) ->
	Now = util:unixtime(),
	if
		Now > ?HOLIDAY_BEG_TIME andalso Now < ?HOLIDAY_END_TIME -> 
			case Type of
				1 -> %%战场大比拼
					Title = "战场冠军奖励",
					if 
						SubType == 1 ->
							Goods = 31024,
			   				Level = "初级";
			   			SubType == 2 ->
							Goods = 31025,
				   			Level = "中级";
			   			true ->
							Goods = 31026,
				   			Level = "高级"
					end,
					Content = io_lib:format("恭喜你在今日的【~s】战场中勇夺第一，获得~s战场冠军礼包，以资鼓励！",[Level,Level]),
					lib_mail:insert_mail(1, Now, "系统", PlayerId, Title, Content, 0, Goods, 1, 0, 0);
				2 ->%% 活跃度
			
					Title = "活跃度奖励",
					Content = "恭喜你今日的活跃度达到180，获得活跃度礼包，祝你国庆快乐～",
					Goods = 31028 ,
					lib_mail:insert_mail(1, Now, "系统", PlayerId, Title, Content, 0, Goods, 1, 0, 0)
			end;
		true ->
			skip
	end.


%% 国庆返利活动
holiday_return_award(Player) ->
	Now = util:unixtime(),
	case db_agent:get_mid_prize(Player#player.id,5) of
		[] -> %% 还没有返利
			ConsumeLog = get_consume_log(Player#player.id, ?HOLIDAY_BEG_TIME, ?HOLIDAY_END_TIME),
			case length(ConsumeLog) > 0  of
				true ->
					F=fun([_,G]) ->
						G
					 end,
					Tgold = lists:sum(lists:map(F, ConsumeLog)),
					Return =  trunc(Tgold * 0.05),
					if
						Return > 0 ->
							db_agent:insert_mid_prize([pid,type,num,got],[Player#player.id,5,0,0]),
							Content = io_lib:format("你在国庆消费返利活动中，共计消费~p元宝，获得返利~p元宝，感谢你的参与，祝你游戏愉快～",[Tgold,Return]),
							lib_mail:insert_mail(1, Now, "系统", Player#player.id, "国庆返利通知", Content, 0, 0, 0, 0, Return);
						true ->
							skip
					end;
				false ->
					skip
			end;
		_ ->
			%%有返还记录
			skip
	end.

%% 红星 31206
%% 7天礼包 28705
%% 人气礼包 31027
get_mid_prize_info(Pid,Type) ->
	case Type of
		1 -> 
			%% 国庆期间的消费记录
			ConsumeLog = get_consume_log(Pid, ?HOLIDAY_BEG_TIME, ?HOLIDAY_END_TIME),
			case length(ConsumeLog) > 0  of
				true ->
					F=fun([_,G]) ->
							  G
					  end,
					Tgold = lists:sum(lists:map(F, ConsumeLog)),	
					case db_agent:get_mid_prize(Pid,1) of
						[_Id,_Mpid,_Mtype,_Mnum,Got] ->
							%% 有记录
							Snum = Tgold div 300 ,
							if
								Snum > Got ->
									[28706,Snum - Got];
								true ->
									[28706 , 0]
							end;
						[] ->
							%% 没有记录
							db_agent:insert_mid_prize([pid,type,num,got],[Pid,1,0,0]),
							[28706, Tgold div 300]
					end;
				false ->
					[28706,0]
			end;
		2 -> %% 登陆活动
			case db_agent:get_mid_prize(Pid ,2) of
				[_Id,_Mpid,_Mtype,Mnum,Got] ->
					if
						Mnum > Got ->
							[28705,Mnum -  Got];
						true ->
							[28705, 0]
					end;
				[] ->
					[28705, 0]
			end;
		3 -> %% 万人迷
			case db_agent:get_mid_prize(Pid,3) of
				[_Id,_Mpid,_Mtype,Mnum,Got] ->
					if
						Mnum > Got ->
							[31027,Mnum - Got];
						true ->
							[31027 ,0]
					end;
				[] ->
					[31027,0]
			end;
		4 -> %%全身强化
			case db_agent:get_mid_prize(Pid,4) of
				[_Id,_Mpid,_Mtype,Mnum,Got] ->
					HolidayInfo = goods_util:get_ets_info(?ETS_HOLIDAY_INFO, Pid),
					Fullstren = HolidayInfo#ets_holiday_info.full_stren,
					if
						Fullstren /= undefined andalso Fullstren >= 5 andalso Mnum > Got ->
							case Fullstren of
								5 ->[31029,1];
								6 ->[31029,1];
								7 ->[31030,1];
								8 ->[31031,1];
								9 ->[31032,1];
								10 ->[31033,1];
								_ ->[0,0]
							end;
						true ->
							[0 ,0]
					end;
				[] ->
					[0,0]
			end;						
		_ ->
			[0,0]
	end.
					
%% 国庆活动
get_mid_prize(Player,Type) ->
	HolidayInfo = goods_util:get_ets_info(?ETS_HOLIDAY_INFO, Player#player.id),
	Fullstren = HolidayInfo#ets_holiday_info.full_stren,
	case db_agent:get_mid_prize(Player#player.id,Type) of
		[Id,_Mpid,_Mtype,Mnum,Got] ->
			if
				Type == 1 -> %%充值互动
					ConsumeLog = get_consume_log(Player#player.id, ?HOLIDAY_BEG_TIME, ?HOLIDAY_END_TIME),
					case length(ConsumeLog) > 0 of
						true ->
							F=fun([_,G]) ->
							  		G
					  		end,
							Tgold = lists:sum(lists:map(F, ConsumeLog)),	
							Snum = Tgold div 300 ,
							if
								Snum > Got ->
									GiveNum = Snum - Got;
								true ->
									GiveNum = 0
							end;
						false ->
							GiveNum = 0
					end;
				Type == 2 orelse Type == 3  -> %% 2登陆 3万人迷
					if
						Mnum > Got ->
							GiveNum = Mnum -  Got;
						true ->
							GiveNum = 0
					end;
				Type == 4 -> %% 全身强化活动
					if
						Fullstren >= 5 andalso Mnum > Got ->
							GiveNum = Mnum -  Got;
						true ->
							GiveNum = 0
					end;
				true ->
					GiveNum = 0
			end;
		[] ->
			Got = 0,
			Id = 0,
			GiveNum = 0
	end,
	case GiveNum > 0 of
		true ->
			if Type == 1 -> GoodsId = 28706;%%红星
			   Type == 2 -> GoodsId = 28705;%%7天登陆
			   Type == 3 -> GoodsId = 31027;%%人气礼包
			   true ->%% 4 -强化礼包
				   case Fullstren of
					   7 -> GoodsId = 31030;
					   8 -> GoodsId = 31031;
					   9 -> GoodsId = 31032;
					   10 -> GoodsId = 31033;
					   _ -> GoodsId = 31029
				   end
			end,
			case length(gen_server:call(Player#player.other#player_other.pid_goods,{'null_cell'})) > 0 of
				true ->
					case gen_server:call(Player#player.other#player_other.pid_goods, {'give_goods', Player,GoodsId, GiveNum}) of
						ok ->
							%%领取成功更新记录
							db_agent:update_mid_prize([{got,GiveNum + Got}],[{id,Id}]),
							{ok,1};
						_ ->
							{fail,0}
					end;
				false ->
					{fail,3}
			end;
		false ->
			{fail,2}
	end.


%%兑换物品，根据传进来的类型来兑换 
exchange_goods(Player,Type) ->
	%%删除物品发放物品的功能提取
	Fun_give = fun(DeleteType,DeleteNum,GiveType,GiveNum,Bind,ExpireTime,SuccessFun,SuccessFunArgs) ->
		case length(gen_server:call(Player#player.other#player_other.pid_goods,{'null_cell'})) > 0 of
			true ->
					case gen_server:call(Player#player.other#player_other.pid_goods,{delete_more,DeleteType,DeleteNum}) of
						1 ->
							gen_server:call(Player#player.other#player_other.pid_goods, {'give_goods', Player,GiveType,GiveNum,Bind,ExpireTime}),
							case is_function(SuccessFun) of
								true ->
									erlang:apply(SuccessFun, SuccessFunArgs);
								false ->
									skip
							end,
							{ok,1};
						_ ->
							{fail,0}
					end;
			false ->
				{fail,3}
		end
	end,
	%%获取类型物品数量功能提取
	F_n = fun(Goods_id) ->
						NeedGoods = goods_util:get_type_goods_list(Player#player.id,Goods_id,4),
						goods_util:get_goods_totalnum(NeedGoods)
				end,
	case Type of
		1 -> %%兑换时装
			[G1,G2] =
				case Player#player.career of
					1 -> [10911,10912];
					2 -> [10913,10914];
					3 -> [10915,10916];
					4 -> [10917,10918];
					5 -> [10919,10920]
				end,
			Goods_id =
				if
					Player#player.sex == 1 ->
						G1;
					true ->
						G2
				end,
	
			NeedGoods = goods_util:get_type_goods_list(Player#player.id, 31206, 4),
			TotalNum = goods_util:get_goods_totalnum(NeedGoods),
			case TotalNum >= 7 of
				true ->
					Now = util:unixtime(),
					Expire = Now + 3600 * 24 * 10 , %%10天有效
					Fun_give(31206,7,Goods_id,1,0,Expire,[],[]);
				false ->
					{fail,2}
			end;
		2 -> %% 兑换时装变化券
			%%兑换时装变换券需要6个嫦娥之泪 31200
			NeedGoods = goods_util:get_type_goods_list(Player#player.id, 31206, 4),
			TotalNum = goods_util:get_goods_totalnum(NeedGoods),
			case TotalNum >= 7 of
				true ->
					Fun_give(31206,7,31205,1,0,0,[],[]);
				false ->
					{fail,2}
			end;
		3 -> %% 国庆活动 经验口粮		
			%%成功回调函数
			SucF = fun() ->
						case length(gen_server:call(Player#player.other#player_other.pid_goods,{'null_cell'})) > 0 of
							true ->
								%% 给经验
								gen_server:call(Player#player.other#player_other.pid_goods, {'give_goods', Player,23201,2,2,0});
							false ->
								lib_mail:insert_mail(1,util:unixtime(), "系统", Player#player.id, "背包已满","亲爱的玩家，您的背包已满，物品通过邮件发放。", 0, 23201, 2, 0, 0)
						end
				   end,		
			case F_n(31207) >= 5 of
				true ->
					Fun_give(31207,5,24000,2,2,0,SucF,[]);
				false ->
					case F_n(31208) >=5 of
						true ->
							Fun_give(31208,5,24000,2,2,0,SucF,[]);
						false ->
							case F_n(31209) >=5 of
								true ->
									Fun_give(31209,5,24000,2,2,0,SucF,[]);
								false ->
									case F_n(31210) >= 5 of
										true ->
											Fun_give(31210,5,24000,2,2,0,SucF,[]);
										false ->
											{fail,2}
									end
							end
					end
			end;
		4 -> %% 兑换国庆快乐礼包
			DelF = fun(DelTypeId ,Scode) ->
				case catch(gen_server:call(Player#player.other#player_other.pid_goods,{delete_more,DelTypeId,1})) of
					1 ->
						Scode;
					_ ->
						Scode + 1
				end			
			end,
			case F_n(31207) > 0 andalso F_n(31208) >0 andalso F_n(31209) > 0 andalso F_n(31210) > 0 of
				true ->
					case lists:foldl(DelF, 0, [31207,31208,31209,31210]) == 0 of
						true ->
							gen_server:call(Player#player.other#player_other.pid_goods, {'give_goods', Player,28706,1,2,0}),
							{ok,1};
						false ->
							{fail,0}
					end;
				false ->
					{fail,2}
			end;
		_ ->
			{fail,0}
	end.
	
%%开服活动5赠送+5护腕
give_stren5_hw(Player) ->
	case length(gen_server:call(Player#player.other#player_other.pid_goods,{'null_cell'})) > 0 of
		true ->
			GoodsId = 
			case Player#player.career of
				1 -> %%玄武
					11203;
				2 -> %%白虎
					12203;
				3 -> %%青龙
					13203;
				4 -> %%朱雀
					14203;
				5 ->%%麒麟
					15203
			end,
			case gen_server:call(Player#player.other#player_other.pid_goods, {'give_goods', Player,GoodsId, 1,2}) of
				ok ->
					GoodsInfo = goods_util:get_new_goods_by_type(GoodsId,Player#player.id),
					NewGoodsInfo = GoodsInfo#goods{stren = 5},
					spawn(fun()->db_agent:mod_strengthen(5, 0,NewGoodsInfo#goods.id)end),
					ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
					Step=goods_util:level_to_step(NewGoodsInfo#goods.level),
					Pattern2 = #ets_base_goods_strengthen_anti{subtype=NewGoodsInfo#goods.subtype,step=Step,stren=NewGoodsInfo#goods.stren, _='_' },
					GoodsStrengthenAntiRule = goods_util:get_ets_info(?ETS_BASE_GOODS_STRENGTHEN_ANTI,Pattern2),
					lib_make:mod_strengthen_anti(NewGoodsInfo,GoodsStrengthenAntiRule), 
					[1];
				_ ->
					[0]
			end;
		false ->
			[2]
	end.

%%开服活动5赠送+5护腕 预览
give_stren5_hw_preview(Player) ->
	GoodsId = 
		case Player#player.career of
			1 -> %%玄武
				11203;
			2 -> %%白虎
				12203;
			3 -> %%青龙
				13203;
			4 -> %%朱雀
				14203;
			5 ->%%麒麟
				15203
		end,
	TypeInfo = goods_util:get_goods_type(GoodsId),
	NewGoods = goods_util:get_new_goods(TypeInfo), 
	NewGoods2 = NewGoods#goods{id =0,player_id =0,location=4 ,cell=1 ,num = 1,stren = 5 ,bind = 0},
	Pattern = #ets_base_goods_add_attribute{ goods_id=NewGoods2#goods.goods_id,color=NewGoods2#goods.color,attribute_type=11, _='_' },
    BaseAddAttributeList = goods_util:get_ets_list(?ETS_BASE_GOODS_ADD_ATTRIBUTE, Pattern),
	Step=goods_util:level_to_step(NewGoods2#goods.level),
	Pattern2 = #ets_base_goods_strengthen_anti{subtype=NewGoods2#goods.subtype,step=Step,stren=NewGoods2#goods.stren, _='_' },
	GoodsStrengthenAntiRule = goods_util:get_ets_info(?ETS_BASE_GOODS_STRENGTHEN_ANTI,Pattern2),
	[?ETS_BASE_GOODS_STRENGTHEN_ANTI,_,_,_,_,Value] = tuple_to_list(GoodsStrengthenAntiRule),
	AttributeAnti = #goods_attribute{player_id = 0 ,attribute_type = 4,anti_wind = Value ,anti_fire = Value,anti_water = Value ,anti_thunder = Value,anti_soil = Value},
	F = fun(BaseAddAttribute,L) ->							
			case is_record(BaseAddAttribute,ets_base_goods_add_attribute) of
				true ->
					Attribute= goods_util:get_new_goods_add_attribute(BaseAddAttribute),
					[Attribute|L];
				false ->
					L
			end
		end,
	AttributeList = lists:foldl(F, [], BaseAddAttributeList),
	[NewGoods2,0,[AttributeAnti|AttributeList]].
%%
%% Local Functions
%%

%%获取活动消费日志
get_consume_log(Pid, BeginTime, EndTime) -> 
	db_agent:get_consume_log([{pid,Pid},{ct,">",BeginTime},{ct,"<",EndTime},{type,"gold"},{pit,"<>",1702},{pit,"<>",1703},{pit,"<>",1706},{pit,"<>",1808},{pit,"<>",3313},{pit,"<>",4104},{pit,"<>",3005},{oper,0}]).

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
%%====================================================================感恩节活动内容======================================

%%感恩节活动获取情况
get_Thanksgiving_info(PId,Type) ->
	Now = util:unixtime(),
	%%感恩节的开始和结束时间
	{TGStart, TGEnd} = thanksgiving_time(),
	if
		Now > TGStart andalso Now < TGEnd ->
	case Type of
		3 -> %% 活动二：登录送好礼
			case db_agent:get_mid_prize(PId ,3) of
				[_Id,_Mpid,_Mtype,Mnum,Got] ->
					if
						Mnum > Got ->
							[1, Mnum - Got];
						true ->
							[2, 0]
					end;
				[] ->
					%% 没有记录
					db_agent:insert_mid_prize([pid,type,num,got],[PId,3,1,0]),
					[1, 1]
			end;
		4 -> %% 活动三：经脉速提升，保护免费送
			Check = lib_act_interf:check_player_linggen(PId),
			case Check > 0 of
				true ->
					GiveNum = lingen_get_goods(Check),
					case db_agent:get_mid_prize(PId,4) of
						[_Id,_Mpid,_Mtype,_Mnum,Got] ->
							if
								Got > 0 ->
									[2, Got];
								true ->
									[1, GiveNum]
							end;
						[] ->
							%% 没有记录
							db_agent:insert_mid_prize([pid,type,num,got],[PId,4,0,0]),
							[1, GiveNum]
					end;
				false ->
					[0, 0]
			end;
		5 -> %%活动1充值奖励
			Tgold =  get_pay_gold(PId, TGStart, TGEnd),
			case Tgold > 0 of
				true ->
					Snum = Tgold div 500 ,
					Extra = get_thanksgiving_extra_info(PId,Tgold),
					case db_agent:get_mid_prize(PId,5) of
						[_Id,_Mpid,_Mtype,_Mnum,Got] ->					
							if
								Snum > Got ->
									[1,Snum - Got + Extra];
								true ->
									[2,0]
							end;
						[] ->
							db_agent:insert_mid_prize([pid,type,num,got],[PId,5,Snum,0]),
							if
								Snum > 0 ->
									[1,Snum + Extra];
								true ->
									[2,0]
							end
					end;
				false ->
					[0,0]
			end;
		6 -> %%充值金额显示
			Tgold = get_pay_gold(PId, TGStart, TGEnd),
			if
				Tgold > 0 ->
					[1,Tgold];
				true ->
					[0,0]
			end;
		7 -> %%返回额外感恩礼包数
			Tgold = get_pay_gold(PId, TGStart, TGEnd),
			Extra = get_thanksgiving_extra_info(PId,Tgold),
			[1,Extra];
		_ ->
			[0, 0]
	end;
		true ->
			[0, 0]
	end.

%%感恩节获取活动奖励
get_Thanksgiving(Player, Type) ->
	Now = util:unixtime(),
	%%感恩节的开始和结束时间
	{TGStart, TGEnd} = thanksgiving_time(),
	if
		Now > TGStart andalso Now < TGEnd ->
			
			%%删除物品发放物品的功能提取
			Fun_give = fun(DeleteType,DeleteNum,GiveType,GiveNum,Bind,ExpireTime,SuccessFun,SuccessFunArgs) ->
							   case length(gen_server:call(Player#player.other#player_other.pid_goods,{'null_cell'})) > 0 of
								   true ->
									   case gen_server:call(Player#player.other#player_other.pid_goods,{delete_more,DeleteType,DeleteNum}) of
										   1 ->
											   gen_server:call(Player#player.other#player_other.pid_goods, {'give_goods', Player,GiveType,GiveNum,Bind,ExpireTime}),
											   case is_function(SuccessFun) of
												   true ->
													   erlang:apply(SuccessFun, SuccessFunArgs);
												   false ->
													   skip
											   end,
											   {ok,1};
										   _ ->
											   {fail,0}
									   end;
								   false ->
									   {fail,3}
							   end
					   end,
			
			if %%6个感恩之心可兑换【感恩时装】、【龙凤时装变身券】		
				Type =:= 1 ->%%兑换时装
					[G1,G2] =
						case Player#player.career of
							1 -> [10921,10922];
							2 -> [10923,10924];
							3 -> [10925,10926];
							4 -> [10927,10928];
							5 -> [10929,10930]
						end,
					Goods_id =
						if
							Player#player.sex == 1 ->
								G1;
							true ->
								G2
						end,
					NeedGoods = goods_util:get_type_goods_list(Player#player.id, 31213, 4),
					TotalNum = goods_util:get_goods_totalnum(NeedGoods),
					case TotalNum >= 7 of
						true ->
							Now = util:unixtime(),
							Expire = Now + 3600 * 24 * 10 , %%10天有效
							Fun_give(31213,7,Goods_id,1,0,Expire,[],[]);
						false ->
							{fail,2}
					end;
				Type =:= 2  -> %% 兑换时装变化券
					NeedGoods = goods_util:get_type_goods_list(Player#player.id, 31213, 4),
					TotalNum = goods_util:get_goods_totalnum(NeedGoods),
					case TotalNum >= 7 of
						true ->
							Fun_give(31213,7,31214,1,0,0,[],[]);
						false ->
							{fail,2}
					end;
				Type =:= 5 -> %% 充值元宝兑换
					Tgold =  get_pay_gold(Player#player.id, TGStart, TGEnd),
					case Tgold > 0 of
						true ->
							Snum = Tgold div 500 ,
							case db_agent:get_mid_prize(Player#player.id,Type) of
								[Id,_Mpid,_Mtype,_Mnum,Got] ->
									GiveNum = Snum -  Got,
									Extra = get_thanksgiving_extra_info(Player#player.id,Tgold),
									NeedCell = util:ceil(Extra / 20) + 2 ,
									case length(gen_server:call(Player#player.other#player_other.pid_goods,{'null_cell'})) > NeedCell of
										true ->
											gen_server:call(Player#player.other#player_other.pid_goods, {'give_goods', Player,28817, GiveNum+Extra, 0}), 
											gen_server:call(Player#player.other#player_other.pid_goods, {'give_goods', Player,31213, GiveNum , 0}),
											db_agent:update_mid_prize([{got,GiveNum + Got}],[{id,Id}]),
											if
												Extra > 0 ->
													add_thanksgiving_extra_info(Player#player.id,Tgold);
												true ->
													skip
											end,
											{ok,1};
										false ->
											{fail,3}
									end;								
								[] ->
									{fail,2}
							end;
						false ->
							{fail,0}
					end;	
				true ->%%其他的兑换和领取
					case db_agent:get_mid_prize(Player#player.id,Type) of
						[Id,_Mpid,_Mtype,Mnum,Got] ->
							if
								Type == 3 ->%% 活动二：登录送好礼
									if
										Mnum > Got ->
											GiveNum = Mnum -  Got;
										true ->
											GiveNum = 0
									end;
								Type == 4 ->%% 活动三：经脉速提升，保护免费送
									Check = lib_act_interf:check_player_linggen(Player#player.id),
									case Check > 0 of
										true ->
											ShouldNum = lingen_get_goods(Check),
											if
												Got > 0 ->
													GiveNum = 0;
												true ->
													GiveNum = ShouldNum
											end;
										false ->
											GiveNum = 0
									end;
								true ->
									GiveNum = 0
							end;
						[] ->
							Got = 0,
							Id = 0,
							GiveNum = 0
					end,
					case GiveNum > 0 of
						true ->
							case Type of
								3 -> 
									GoodsId = 31047, %%感恩登陆礼包
									Bind = 2;
								4 -> 
									GoodsId = 22007, %%经脉保护符
									Bind = 0
							end,
							case length(gen_server:call(Player#player.other#player_other.pid_goods,{'null_cell'})) > 0 of
								true ->
									case gen_server:call(Player#player.other#player_other.pid_goods, {'give_goods', Player,GoodsId, GiveNum, Bind}) of
										ok ->
											%%领取成功更新记录
											db_agent:update_mid_prize([{got,GiveNum + Got}],[{id,Id}]),
											{ok,1};
										_ ->
											{fail,0}
									end;
								false ->
									{fail,3}
							end;
						false ->
							{fail,2}
					end
			end;
		true ->
			{fail, 0}
	end.



%%获取灵根情况对应给予的物品数量
lingen_get_goods(LinGen) ->
	if
		LinGen =:= 5 -> 10;
		LinGen =:= 4 -> 8;
		LinGen =:= 3 -> 6;
		LinGen =:= 2 -> 4;
		LinGen =:= 1 -> 2;
		true -> 0
	end.
%% 活动时间：2011年11月23日8点～26日0点			
thanksgiving_time() ->
	{1322006400, 1322236800}.	%%警告，正确的时间，不要随意修改，如需使用，请用下面的测试代码
	
	%%测试用代码
%% 	{1321959600, 1321965000}.

%% 感恩节充值活动额外奖励
get_thanksgiving_extra_info(Pid,Tgold) ->
	if
		Tgold >= 3000 andalso Tgold < 10000->
			case has_activity_record(Pid,11) of %%类型11，3000额外奖励
				true -> %%有数据表示已领取
					0;
				false ->
					3
			end;
		Tgold >= 10000 andalso  Tgold < 50000 ->
			case has_activity_record(Pid,12) of %%类型12，10000额外奖励
				true -> %%有数据表示已领取
					0;
				false ->
					R11 = has_activity_record(Pid,11),
					if
						R11 == false ->
							10 + 3;
						true ->
							10
					end
			end;
		Tgold >= 50000 ->
			case has_activity_record(Pid,13) of %%类型12，50000额外奖励
				true -> %%有数据表示已领取
					0;
				false  ->
					R11 = has_activity_record(Pid,11),
					R12 = has_activity_record(Pid,12),
					N0 = 50,
					if
						R11 == false ->
							N1 = N0 + 3;
						true ->
							N1 = N0
					end,
					if
						R12 == false ->
							N1 + 10;
						true ->
							N1
					end
			end;
		true ->
			0
	end.

%%增加额外奖励记录
add_thanksgiving_extra_info(Pid,Tgold) ->
	if
		Tgold >= 3000 andalso Tgold < 10000->
			db_agent:insert_mid_prize([pid,type,num,got],[Pid,11,1,0]),%%类型11，3000额外奖励
			ok;
		Tgold >= 10000 andalso  Tgold < 50000 ->
			db_agent:insert_mid_prize([pid,type,num,got],[Pid,12,1,0]),%%类型12，10000额外奖励
			ok;
		Tgold >= 50000 ->
			db_agent:insert_mid_prize([pid,type,num,got],[Pid,13,1,0]),%%类型13，50000额外奖励
			ok;
		true ->
			0
	end.
	
%%检查是否有活动记录
has_activity_record(Pid,Type) ->
	case db_agent:get_mid_prize(Pid,Type) of
		[] ->false;
		_ ->true
	end.
%% =======================================================================================================================
%% ===================================================================圣诞节活动内容=======================================
%% =======================================================================================================================
-define(CHRISTMAS_SNOWMAN_COORDS, 
		[{0, {69, 94}}, {0, {75, 94}},  {0, {81, 94}},  {0, {66, 100}}, {0, {65, 106}},
		 {0, {70, 109}}, {0, {61, 109}}, {0, {57, 114}}, {0, {65, 114}}, {0, {72, 114}},
		 {0, {56, 122}}, {0, {65, 122}}, {0, {69, 122}}, {0, {54, 129}}, {0, {64, 129}},
		 {0, {69, 129}}, {0, {53, 137}}, {0, {60, 137}}, {0, {50, 144}}, {0, {56, 144}},
		 {0, {62, 144}}, {0, {62, 155}}, {0, {67, 155}}, {0, {75, 155}}, {0, {80, 155}},
		 {0, {59, 162}}, {0, {64, 162}}, {0, {69, 162}}, {0, {75, 162}}, {0, {81, 162}},
		 {0, {57, 167}}, {0, {61, 167}}, {0, {65, 167}}, {0, {69, 167}}, {0, {75, 167}},
		 {0, {57, 174}}, {0, {61, 174}}, {0, {65, 174}}, {0, {69, 174}}, {0, {73, 174}},
		 {0, {41, 180}}, {0, {49, 180}}, {0, {57, 180}}, {0, {65, 180}}, {0, {72, 180}},
		 {0, {39, 190}}, {0, {47, 190}}, {0, {55, 190}}, {0, {63, 190}}, {0, {71, 190}}]).			%%雪人出现的场景坐标

-define(SNOWMAN_APPER_SCENE, 102).						%%雪人出现的场景
-define(SNOWMAN_MON_ID, 40117).							%%雪人Id
-define(SNOWMAN_REFRESH_TIME, 3600000).					%%雪人刷新的时间戳(3600000s)

%% -define(SNOWMAN_REFRESH_TIME, 1200000).					%%雪人刷新的时间戳测试

%%活动时间：2011年12月24日0时～2011年12月27日0点	
christmas_time() ->	
	{1324656000, 1324915200}.	%%警告，正确的时间，不要随意修改，如需使用，请用下面的测试代码
	
	%%测试用代码
%% 	{1324533600, 1324566000}.

snowman_time() ->%%活动期间	每天9：00～24：00
	{32400, 86400}.		%%警告，正确的时间，不要随意修改，如需使用，请用下面的测试代码
	
	%%测试用代码
%% 	{28800, 82800}.
get_christmas_info(PlayerId, Type) ->
	Now = util:unixtime(),
	%%圣诞节的开始和结束时间
	{TGStart, TGEnd} = christmas_time(),
	if
		Now > TGStart andalso Now < TGEnd ->
%% 			?DEBUG("it is on christmas time", []),
			case Type of
				4 -> %% 活动四：飞跃品阶，神器进化
					{Step, Check, _Cell, _NGiveNum} = lib_act_interf:check_artifact(PlayerId, step),
%% 					?DEBUG("Step:~p, Check:~p, _Cell:~p, _NGiveNum:~p", [Step, Check, _Cell, _NGiveNum]),
					case Check of
						[] ->
							[10, 0];
						_ ->
							case db_agent:get_mid_prize(PlayerId, 4) of
								[_Id,_Mpid,_Mtype,_Mnum,Got] ->
									if
										Got > 0 ->%%已经领取
											[Step, 2];
										true ->
											[Step, 1]
									end;
								[] ->%% 没有记录
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,4,0,0]),
									[Step, 1]
							end
					end;
				5 -> %% 活动五：神器品质突破
					{Color, Check, _Cell, _NGiveNum} = lib_act_interf:check_artifact(PlayerId, color),
%% 					?DEBUG("Color:~p, Check:~p, _Cell:~p, _NGiveNum:~p", [Color, Check, _Cell, _NGiveNum]),
					case Check of
						[] ->
							[10, 0];
						_ ->
							case db_agent:get_mid_prize(PlayerId, 5) of
								[_Id,_Mpid,_Mtype,_Mnum,Got] ->
									if
										Got > 0 ->%%已经领取
											[Color, 2];
										true ->
											[Color, 1]
									end;
								[] ->%% 没有记录
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,5,0,0]),
									[Color, 1]
							end
					end;
				6 -> %% 活动六：圣诞登录有惊喜
					case db_agent:get_mid_prize(PlayerId ,6) of
						[_Id,_Mpid,_Mtype,Mnum,Got] ->
							if
								Mnum > Got ->
									[Mnum - Got, 1];
								true ->
									[0, 2]
							end;
						[] ->
							%% 没有记录
							db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,6,1,0]),
							[1, 1]
					end;
				_ ->
					[0, 0]
			end;
		true ->
			[0, 0]
	end.

get_christmas(Player, Type) ->
	Now = util:unixtime(),
	%%圣诞节节的开始和结束时间
	{TGStart, TGEnd} = christmas_time(),
	if
		Now > TGStart andalso Now < TGEnd ->
			case db_agent:get_mid_prize(Player#player.id,Type) of
				[Id,_Mpid,_Mtype,Mnum,Got] ->
					if
						Type == 4 -> %% 活动四：飞跃品阶，神器进化
							{_Step, Check, Cell, NGiveNum} = lib_act_interf:check_artifact(Player#player.id, step),
							case Check of
								[] ->
									NeedCell = 0,
									Give = [];
								_ ->
									if
										Got > 0 ->
											NeedCell = 0,
											Give = [];
										true ->
											NeedCell = Cell,
											Give = Check
									end
							end;
						Type == 5 -> %% 活动五：神器品质突破
							{_Step, Check, Cell, NGiveNum} = lib_act_interf:check_artifact(Player#player.id, color),
							case Check of
								[] ->
									NeedCell = 0,
									Give = [];
								_ ->
									if
										Got > 0 ->
											NeedCell = 0,
											Give = [];
										true ->
											NeedCell = Cell,
											Give = Check
									end
							end;
						Type == 6 -> %% 活动六：圣诞登录有惊喜
							if
								Mnum > Got ->
									NeedCell = 1,
									GoodsId = 31052, %%圣诞节登陆礼包
									NGiveNum = Mnum -  Got,
									Give = [{GoodsId, NGiveNum, 2}];
								true ->
									NGiveNum = 0,
									NeedCell = 0,
									Give = []
							end;
						true ->
							NGiveNum = 0,
							NeedCell = 0,
							Give = []
					end,
					?DEBUG("give is :~p", [Give]),
					case Give of
						[] ->
							{fail, 0};
						_List ->
							case length(gen_server:call(Player#player.other#player_other.pid_goods,{'null_cell'})) >= NeedCell of
								true ->
									case give_list_goods(Player, Give, ok)of
										ok ->
											%%领取成功更新记录
											db_agent:update_mid_prize([{got, NGiveNum + Got}],[{id,Id}]),
											{ok,1};
										_ ->
											{fail,0}
									end;
								false ->
									{fail,2}
							end
					end;
				[] ->
					{fail, 0}
			end;
		true ->
			{fail, 0}
	end.

give_list_goods(_Player, [], Type) ->
	Type;
give_list_goods(Player, [{GiveGoodsId, GoodsNum, Bind}|Rest], Type) ->
	case Type of
		ok ->
			case catch (gen_server:call(Player#player.other#player_other.pid_goods, {'give_goods', Player, GiveGoodsId, GoodsNum, Bind})) of
				ok ->
					give_list_goods(Player, Rest, ok);
				_ ->
					give_list_goods(Player, [], fail)
			end;
		_ ->
			give_list_goods(Player, [], fail)
	end.


%%活动二：天降雪人，兑换圣诞袜		
refresh_snowman(NowSec) ->
	%%获取圣诞节的活动时间
	{ChrStart, ChrEnd} = christmas_time(),
	NowTime = util:unixtime(),
	case ChrStart =< NowTime andalso NowTime < ChrEnd of
		true ->%%活动期间哦
			%%获取雪人刷新的时间段
			{MonStart, MonEnd} = snowman_time(),
			case MonStart =< NowSec andalso NowSec < MonEnd of
				true ->
					case get_snowman_on() of
						1 ->%%已经开了
							skip;
						0 ->
							self() ! {'REFLESH_SNOWMAN'},%%想自己进程发信息，触发生产怪物的流程
							put_snowman_on(1)%%设置新的状态
					end;
				false ->
					put_snowman_on(0)%%恢复状态
			end;
		false ->
			skip
	end.


make_snowman() ->
	%%获取圣诞节的活动时间
	{ChrStart, ChrEnd} = christmas_time(),
	NowTime = util:unixtime(),
	case ChrStart =< NowTime andalso NowTime < ChrEnd of
		true ->%%活动期间哦
			TodaySec = util:get_today_current_second(),
			%%获取雪人刷新的时间段
			{MonStart, MonEnd} = snowman_time(),
			case MonStart =< TodaySec andalso TodaySec < MonEnd of
				true ->
					SnowMan = get_snowman_coord(),
					%%刷新雪人
%% 					?DEBUG("Refresh snowman:~p", [SnowMan]),
					%%获取需要复活的雪人坐标
					NewCoords = get_revive(SnowMan),
					%%获取场景的Pid
					ScenePid = mod_scene:get_scene_pid(?SNOWMAN_APPER_SCENE, undefined, undefined),
					%%雪人广播
					MSG = "圣诞老人洒下的礼物都被<font color='#FFFFFF'>雪人</font>抢走了，大家快去洛水夺回礼物吧！<a href='event:6,102,69,103'><font color='#00FF33'><u>》》我要前往《《</u></font></a>",
					spawn(fun()->lib_chat:broadcast_sys_msg(2, MSG)end),
					%%想场景发信息，通知生成怪物
					gen_server:cast(ScenePid, {apply_cast, lib_scene, load_christmas_mon, [?SNOWMAN_MON_ID, ?SNOWMAN_APPER_SCENE, SnowMan]}),
					%%更新当前存在的雪人数量
					put_snowman_coord(NewCoords),
					%%取消过去的定时器
					misc:cancel_timer(snowman_timer),
					TimeRef = erlang:send_after(?SNOWMAN_REFRESH_TIME, self(), {'REFLESH_SNOWMAN'}),
					%%添加timeref
					put(snowman_timer, TimeRef);
				false ->
					skip
			end;
		false ->
			skip
	end.

get_snowman_coord() ->
	case get(snowman) of
		Num when is_list(Num) ->
			Num;
		_ ->
			put(snowman, ?CHRISTMAS_SNOWMAN_COORDS),
			?CHRISTMAS_SNOWMAN_COORDS
	end.
put_snowman_coord(Coords) ->
	put(snowman, Coords).
update_snowman_num(X,Y) ->
	NSnowMan = 
		case get(snowman) of
			SnowMan when is_list(SnowMan) ->
				case lists:keyfind({X,Y}, 2, SnowMan) of
					false ->
						SnowMan;
					{_Type,{_X,_Y}} ->
						lists:keyreplace({X,Y}, 2, SnowMan, {0,{X,Y}})
				end;
			_ ->
				?CHRISTMAS_SNOWMAN_COORDS
		end,
%% 	?DEBUG("KILL_SNOWMAN:~p", [NSnowMan]),
	put_snowman_coord(NSnowMan).


get_snowman_on() ->
	case get(snowman_on) of
		1 ->
			1;
		_ ->
			0
	end.
put_snowman_on(Num) ->
	put(snowman_on, Num).


%%获取需要复活的雪人坐标
get_revive(SnowMan) ->
	lists:map(fun(Elem) ->
					  {Type, {X, Y}} = Elem,
					  NewType = 
						  case Type of
							  0 ->
								  1;
							  _ ->
								  1
						  end,
					  {NewType, {X, Y}}
			  end, SnowMan).
%%判断是否是雪人，进行数量更新通知
check_snowman_update(Minfo, SceneId, DX, DY) ->
	case Minfo#ets_mon.mid =:= 40117 of	%%%%雪人怪物
		true ->
			gen_server:cast(mod_title:get_mod_title_pid(), {'KILL_SNOWMAN', DX, DY}),
			%% 移除场景怪物
			{ok, BinData} = pt_20:write(20011, Minfo#ets_mon.id),
			mod_scene_agent:send_to_scene(SceneId, BinData);
		false ->
			skip
	end.

%% =======================================================================================================================
%% ===================================================================元旦活动内容=========================================
%% =======================================================================================================================
%%元旦活动时间
newyear_time() ->
	{1325203200, 1325519999}.			%%警告，正确的时间，不要随意修改，如需使用，请用下面的测试代码
	
	%%测试用代码
%% 	{1325159100, 1325519999}.


%%获取玩家的全身强化类型
get_player_equip_stren(PlayerId) ->
	HolidayInfo = goods_util:get_ets_info(?ETS_HOLIDAY_INFO, PlayerId),
	HolidayInfo#ets_holiday_info.full_stren.

%%获取元旦活动的领取情况
get_newyear_info(PlayerId, Type) ->
	Now = util:unixtime(),
	%%元旦的开始和结束时间
	{TGStart, TGEnd} = newyear_time(),
	if
		Now > TGStart andalso Now < TGEnd ->
			?DEBUG("it is on newyear time", []),
			case Type of
				2 -> %% 活动二：元旦登录礼包	
					case db_agent:get_mid_prize(PlayerId ,2) of
						[_Id,_Mpid,_Mtype,Mnum,Got] ->
							if
								Mnum > Got ->
									[Mnum - Got, 1];
								true ->
									[0, 2]
							end;
						[] ->
							%% 没有记录
							db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,2,1,0]),
							[1, 1]
					end;
				5 -> %% 活动五：	全身强化，潜力无限	
					FullStren = get_player_equip_stren(PlayerId),
					if
						FullStren =/= undefined andalso FullStren >= 5 ->
							case db_agent:get_mid_prize(PlayerId, 5) of
								[_Id,_Mpid,_Mtype,_Mnum,Got] ->
									if
										Got > 0 ->%%已经领取
											[FullStren, 2];
										true ->
											[FullStren, 1]
									end;
								[] ->%% 没有记录
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,5,0,0]),
									[FullStren, 1]
							end;
						true ->
							[0, 0]
					end;
				7 -> %% 活动七：	灵兽资质
					Aptitude = lib_act_interf:get_pet_max_aptitude(PlayerId),
					if 
						Aptitude >= 40 ->
							case db_agent:get_mid_prize(PlayerId, 7) of
								[_Id,_Mpid,_Mtype,_Mnum,Got] ->
									if
										Got > 0 ->%%已经领取
											[Aptitude, 2];
										true ->
											[Aptitude, 1]
									end;
								[] ->%% 没有记录
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,7,0,0]),
									[Aptitude, 1]
							end;
						true ->
							[Aptitude, 0]
					end;
				_ ->
					[0, 0]
			end;
		true ->
			[0, 0]
	end.

get_newyear(Player, Type) ->
	Now = util:unixtime(),
	%%元旦的开始和结束时间
	{TGStart, TGEnd} = newyear_time(),
	if
		Now > TGStart andalso Now < TGEnd ->
			if
				Type =:= 3 ->%%兑换物品的...
					%%删除物品发放物品的功能提取
					Fun_give = 
						fun(DeleteType,DeleteNum,GiveType,GiveNum,Bind,ExpireTime,SuccessFun,SuccessFunArgs) ->
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
												{ok,1};
											2 ->%%物品不存在
												{fail, 4};
											3 ->%%数量不足
												{fail, 4};
											_ ->
											   {fail,0}
										end;
									false ->
										{fail,3}
								end
						end,
					%% 如意礼包＝10*诺亚方舟船票
					{DeleteGoodsId, DeleteNum, GiveGoodsId, GiveNum} = {31220, 10, 28823, 1},
					%%给物品
					Fun_give(DeleteGoodsId, DeleteNum, GiveGoodsId, GiveNum, 2, 0, [], []);
				true ->
					case db_agent:get_mid_prize(Player#player.id,Type) of
						[Id,_Mpid,_Mtype,Mnum,Got] ->
							if
								Type == 2 -> %% 活动二：元旦登录礼包
									if
										Mnum > Got ->
											GoodsId = 31055, %%元旦登陆礼包
											GiveNum = Mnum -  Got;
										true ->
											GiveNum = 0,
											GoodsId = 0
									end;
								Type == 5 -> %% 活动五：	全身强化，潜力无限	
									FullStren = get_player_equip_stren(Player#player.id),
									?DEBUG("FullStren:~p, Got:~p", [FullStren, Got]),
									if
										FullStren =/= undefined andalso FullStren >= 5 ->
											if
												Got > 0 ->
													GiveNum  = 0,
													GoodsId = 0;
												true ->
													GiveNum  = 1,
													GoodsId = lib_act_interf:fullstren_to_goodsid(FullStren)
											end;
										true ->
											GiveNum  = 0,
											GoodsId = 0
									end;
								Type == 7 -> %% 活动七：	灵兽资质
									Aptitude = lib_act_interf:get_pet_max_aptitude(Player#player.id),
									if
										Aptitude >= 40->
											if
												Got > 0 ->
													GiveNum  = 0,
													GoodsId = 0;
												true ->
													{GoodsId, GiveNum} = aptitude_to_goodsid(Aptitude)
											end;
										true ->
											GiveNum  = 0,
											GoodsId = 0
									end;
								true ->
									GoodsId = 0,
									GiveNum = 0
							end,
							?DEBUG("give is :~p", [GoodsId]),
							case GoodsId =:= 0 of
								false ->
									case length(gen_server:call(Player#player.other#player_other.pid_goods,{'null_cell'})) > 0 of
										true ->
											case gen_server:call(Player#player.other#player_other.pid_goods, {'give_goods', Player,GoodsId, GiveNum, 2}) of
												ok ->
													%%领取成功更新记录
													db_agent:update_mid_prize([{got,GiveNum + Got}],[{id,Id}]),
													{ok,1};
												_ ->
													{fail,0}
											end;
										false ->
											{fail,3}
									end;
								true ->
									{fail,2}
							end;
						[] ->
							{fail, 0}
					end
			end;
		true ->
			{fail, 0}
	end.


aptitude_to_goodsid(Aptitude) ->
	if
		Aptitude >= 80 -> %%80	神兽蛋*20
			{24800, 20};
		Aptitude >= 70 -> %%70	灵兽保护符*5
			{24401, 5};
		Aptitude >= 60 -> %%60	灵兽保护符*2
			{24401, 2};
		Aptitude >= 50 -> %%60	灵兽保护符*1
			{24401, 1};
		Aptitude >= 40 -> %%40	灵兽资质符*2
			{24400, 2};
		true ->
			{0, 0}
	end.

%% =======================================================================================================================
%% =================================================================周年活动===============================================
%% =======================================================================================================================
%%周年活动时间				活动时间为：1月14日08：00---1月17日23：59				
anniversary_time() ->
	{1326499200, 1326815999}.			%%警告，正确的时间，不要随意修改，如需使用，请用下面的测试代码
	
	%%测试用代码
%% 	{1326464400, 1326468700}.

%%祈祷开放时间(NowSec) 活动时间：18：35---19：00
wish_tree_time() ->
	{66900, 68400}.			%%警告，正确的时间，不要随意修改，如需使用，请用下面的测试代码
	
	%%测试用代码
%%  	{trunc(22*3600+25*60), trunc(22*3600+45*60)}.

%%获取周年活动的领取情况
get_aninversary_info(Player, Type) ->
	#player{id = PlayerId,
			lv = Lv} = Player,
	Now = util:unixtime(),
	%%周年活动的开始和结束时间
	{TGStart, TGEnd} = anniversary_time(),
	if
		Now > TGStart andalso Now < TGEnd ->
%% 			?DEBUG("it is on anniversary time", []),
			case Type of
				4 -> %% 4、仙风道骨，登峰造极	
					Check = lib_anniversary:check_aninversary_linggen(PlayerId),
					case Check > 0 of
						true ->
							case db_agent:get_mid_prize(PlayerId,4) of
								[_Id,_Mpid,_Mtype,_Mnum,Got] ->
									G100 = trunc((Got rem 1000) div 100),
									G50 = trunc(Got rem 10),
									G70 = trunc((Got rem 100) div 10),
									if
										Check >= 50 andalso Check =< 60 andalso G50 =:= 0 ->%%50灵根礼包
											[Check, 1];
										Check >= 70 andalso Check =< 90 andalso G70 =:= 0 ->%%70灵根礼包
											[Check, 1];
										Check =:= 100 andalso G100 =:= 0 ->%%100灵根礼包
											[Check, 1];
										true ->
											[Check, 2]
									end;
								[] ->
									%% 没有记录
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,4,0,0]),
									[Check, 1]
							end;
						false ->
							[0, 0]
					end;
				5 -> %% 5、登录送好礼	
					case Lv >= 35 of
						true ->
					case db_agent:get_mid_prize(PlayerId ,5) of
						[_Id,_Mpid,_Mtype,Mnum,Got] ->
							if
								Mnum > Got ->
									[Mnum - Got, 1];
								true ->
									[0, 2]
							end;
						[] ->
							%% 没有记录
							db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,5,1,0]),
							[1, 1]
					end;
						false ->
							[0,0]
					end;
				8 -> %% 活动八：飞跃品阶，神器进化
					{Step, Check, _Cell, _NGiveNum} = lib_act_interf:check_artifact(PlayerId, step),
%% 					?DEBUG("Step:~p, Check:~p, _Cell:~p, _NGiveNum:~p", [Step, Check, _Cell, _NGiveNum]),
					case Check of
						[] ->
							[10, 0];
						_ ->
							case db_agent:get_mid_prize(PlayerId, 8) of
								[_Id,_Mpid,_Mtype,_Mnum,Got] ->
									if
										Got > 0 ->%%已经领取
											[Step, 2];
										true ->
											[Step, 1]
									end;
								[] ->%% 没有记录
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,8,0,0]),
									[Step, 1]
							end
					end;
				_ ->
					[0, 0]
			end;
		true ->
			[0, 0]
	end.

get_aninversary(Player, Type) ->
	Now = util:unixtime(),
	%%周年活动的开始和结束时间
	{TGStart, TGEnd} = anniversary_time(),
	if
		Now > TGStart andalso Now < TGEnd ->
			if
				Type =:= 6 ->%%兑换时装	使用6个嫦娥之泪可以兑换1个绯月或者金羽时装一套	
					[G1,G2] =
						case Player#player.career of %%职业 1，2，3，4，5（分别是玄武--战士、白虎--刺客、青龙--弓手、朱雀--牧师、麒麟--武尊）
							1 -> [10911,10912];
							2 -> [10913,10914];
							3 -> [10915,10916];
							4 -> [10917,10918];
							5 -> [10919,10920]
						end,
					Goods_id =
						if
							Player#player.sex == 1 ->%%1男，2女
								G1;
							true ->
								G2
						end,
					NeedGoods = goods_util:get_type_goods_list(Player#player.id, 31200, 4),
					TotalNum = goods_util:get_goods_totalnum(NeedGoods),
					case TotalNum >= 6 of
						true ->
							Expire = Now + 3600 * 24 * 10 , %%10天有效
							lib_act_interf:delete_and_give(Player, 31200,6,Goods_id,1,0,Expire,[],[]);
						false ->
							{fail,2}
					end;
				true ->
					case db_agent:get_mid_prize(Player#player.id,Type) of
						[Id,_Mpid,_Mtype,Mnum,Got] ->
							if
								Type == 5 -> %% 5、登录送好礼
									case Player#player.lv >= 35 of
										true ->
									if
										Mnum > Got ->
											NeedCell = 1,
											GoodsId = 31056, %%周年登陆礼包
											NGiveNum = Mnum -  Got,
											GGot = NGiveNum,
											Give = [{GoodsId, NGiveNum, 2}];
										true ->
											NGiveNum = 0,
											NeedCell = 0,
											GGot = NGiveNum,
											Give = []
									end;
										false ->
											NGiveNum = 0,
											NeedCell = 0,
											GGot = NGiveNum,
											Give = []
									end;
								Type == 4 -> %% 4、仙风道骨，登峰造极
									Check = lib_anniversary:check_aninversary_linggen(Player#player.id),
									?DEBUG("Check:~p, Got:~p", [Check, Got]),
									if
										Check >= 0 ->
											G100 = trunc((Got rem 1000) div 100),
											G50 = trunc(Got rem 10),
											G70 = trunc((Got rem 100) div 10),
											{Give, GGot, NeedCell} = 
												if
													Check >= 50 andalso Check =< 60 andalso G50 =:= 0 ->%%50灵根礼包
														{[{31057, 1, 2}], 1, 1};
													Check >= 70 andalso Check =< 90 andalso G70 =:= 0 ->%%70灵根礼包
														{[{31058, 1, 2}], 10, 1};
													Check =:= 100 andalso G100 =:= 0 ->%%100灵根礼包
														{[{31059, 1, 2}], 100, 1};
													true ->
														{[], 0, 0}
												end;
										true ->
											NeedCell = 0,
											NGiveNum  = 0,
											GGot = NGiveNum,
											Give = []
									end;
								Type == 8 -> %% 活动八：飞跃品阶，神器进化
									{_Step, Check, Cell, NGiveNum} = lib_act_interf:check_artifact(Player#player.id, step),
									GGot = NGiveNum,
									case Check of
										[] ->
											NeedCell = 0,
											Give = [];
										_ ->
											if
												Got > 0 ->
													NeedCell = 0,
													Give = [];
												true ->
													NeedCell = Cell,
													Give = Check
											end
									end;
								true ->
									NeedCell = 0,
									NGiveNum  = 0,
									GGot = NGiveNum,
									Give = []
							end,
							?DEBUG("give is :~p", [Give]),
							case Give of
								[] ->
									{fail, 0};
								_List ->
									case length(gen_server:call(Player#player.other#player_other.pid_goods,{'null_cell'})) >= NeedCell of
										true ->
											case give_list_goods(Player, Give, ok)of
												ok ->
													%%领取成功更新记录
													db_agent:update_mid_prize([{got, GGot + Got}],[{id,Id}]),
													{ok,1};
												_ ->
													{fail,0}
											end;
										false ->
											{fail,2}
									end
							end;
						[] ->
							{fail, 0}
					end
			end;
		true ->
			{fail, 0}
	end.


%% =======================================================================================================================
%% ===================================================春节活动============================================================
%% =======================================================================================================================
%% 1月21日0- 25日0
spring_festival_time_2() -> 
%%	{1326467737 ,1326497737}.
{1327075200 ,1327420800}.

%% 1月18日0- 29日0
spring_festival_time_1()->
%%	{0,1326497737}. 
{1326816000,1327766400}.


get_spring_festival_info(PlayerId,Type) ->
	Now = util:unixtime(),
	{TGStart, TGEnd} = spring_festival_time_1(),
	if
		Now > TGStart andalso Now < TGEnd ->
			if
				Type == 10 -> %%充值
					{TGStart2, TGEnd2} = spring_festival_time_2(),
					Tgold = get_pay_gold(PlayerId,TGStart2, TGEnd2),
					case Tgold > 0 of
						true ->
							Snum = Tgold div 500 ,
							case db_agent:get_mid_prize(PlayerId,Type) of
								[_Id,_Mpid,_Mtype,_Mnum,Got] ->
									GiveNum = Snum -  Got,
									if
										GiveNum  > 0 ->
											{GiveNum,1};
										true ->
											{0,0}
									end;
								_ -> 
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,Type,1,0]),
									{Snum,1}
							end;
						false ->
							{0,0}
					end;
				Type == 13 -> %% 坐骑进化
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
							case db_agent:get_mid_prize(PlayerId,Type) of
								[_Id,_Mpid,_Mtype,_Mnum,Got] ->
									if
										Step > Got ->
											{Got + 1,1};
										true ->
											{Step,0}
									end;
								_ ->
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,Type,1,0]),
									{1,1}
							end;
						false ->
							{1,0}
					end;
				Type == 14 -> %%坐骑训化
					AllMount = lib_mount:get_all_mount(PlayerId),
					case length(AllMount) > 0 of
						true ->
							F_color = fun(MountInfo,MaxColor) ->
									if
										MountInfo#ets_mount.color > MaxColor ->
											MountInfo#ets_mount.color;
										true ->
											MaxColor
									end
								end,
							Color = lists:foldl(F_color, 0, AllMount),
							case db_agent:get_mid_prize(PlayerId,Type) of
								%%Got 字段默认10000，后四位标记领取情况
								[_Id,_Mpid,_Mtype,_Mnum,Got] ->
									C1 = Got rem 2,
									C2 = (Got div 10) rem 2,
									C3 = (Got div 100) rem 2,
									C4 = (Got div 1000) rem 2,
									if
										C1 == 0 andalso Color == 2 ->
											{1,1};
										C2 == 0 andalso Color == 3 ->
											{2,1};
										C3 == 0 andalso Color == 4 ->
											{3,1};
										C4 == 0 andalso Color == 5 ->
											{4,1};
										true ->
											{Color - 1,0}
									end;
								_ ->
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,Type,1,10000]),
									{Color - 1,1}
							end;
						false ->
							{0,0}
					end;
				Type == 15 -> %%登陆
					case db_agent:get_mid_prize(PlayerId,Type) of
						[_Id,_Mpid,_Mtype,Mnum,Got] ->
							if
								Mnum > Got ->
									{Mnum - Got,1};
								true ->
									{0,0}
							end;
						_ ->
							db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,Type,1,0]),
							{1,1}
					end;
				Type == 16 -> %%充值总数
					{TGStart2, TGEnd2} = spring_festival_time_2(),
					Tgold = get_pay_gold(PlayerId,TGStart2, TGEnd2),
					{Tgold,1};
				true ->
					{0,0}
			end;
		true ->
			{0,0}
	end.

get_spring_festival(Player,Type) ->
	Now = util:unixtime(),
	{TGStart, TGEnd} = spring_festival_time_1(),
	if
		Now > TGStart andalso Now < TGEnd ->
				Del_give_more = 
						fun(DeleteType,DeleteNum,GoodsList,SuccessFun,SuccessFunArgs) ->
								NeedCell = length(GoodsList),
								case length(gen_server:call(Player#player.other#player_other.pid_goods,{'null_cell'})) > NeedCell of
									true ->%%优先扣绑定的
										case gen_server:call(Player#player.other#player_other.pid_goods,{'DELETE_MORE_BIND_PRIOR',DeleteType,DeleteNum}) of
											1 ->
												gen_server:call(Player#player.other#player_other.pid_goods, {'give_more', Player,GoodsList}),
												case is_function(SuccessFun) of
													true ->
														erlang:apply(SuccessFun, SuccessFunArgs);
													false ->
														skip
												end,
												{ok,1};
											2 ->%%物品不存在
												{fail, 4};
											3 ->%%数量不足
												{fail, 4};
											_ ->
											   {fail,0}
										end;
									false ->
										{fail,3}%%空间不足
								end
						end,
				Give_more = 
					fun(GoodsList,SuccessFun,SuccessFunArgs) ->
							NeedCell = length(GoodsList),
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
							end
					end,
				SuccFun = 
					fun(Id,ValueList) ->
							db_agent:update_mid_prize(ValueList,[{id,Id}])
					end,
			if
				Type == 10 -> %%充值兑换红包
					{TGStart2, TGEnd2} = spring_festival_time_2(),
					Tgold = get_pay_gold(Player#player.id,TGStart2, TGEnd2),
					case Tgold > 0 of
						true ->
							Snum = Tgold div 500 ,
							case db_agent:get_mid_prize(Player#player.id,Type) of
								[Id,_Mpid,_Mtype,_Mnum,Got] ->
									GiveNum = Snum -  Got,
									if
										GiveNum  > 0 ->
											GoodsList = [{31230,GiveNum,2,0,0}],
											Give_more(GoodsList,SuccFun,[Id,[{got,GiveNum + Got}]]);
										true ->
											{fail,0}
									end;
								_ -> {fail,0}
							end;
						false ->
							{fail,0}
					end;
				Type == 11 -> %%兑换时装					
					%% 龙凤时装＝7*春节红包
					FasionGoodsId =
					case {Player#player.career,Player#player.sex} of
						{1,1} -> 10921;
						{1,2} -> 10922;
						{2,1} -> 10923;
						{2,2} -> 10924;
						{3,1} -> 10925;
						{3,2} -> 10926;
						{4,1} -> 10927;
						{4,2} -> 10928;
						{5,1} -> 10929;
						{5,2} -> 10930
					end,
					%%[{物品id，数量，绑定状态，过期时间，交易状态}]
					Expire = util:unixtime() + 864000,
					GoodsList = [{FasionGoodsId,1,2,Expire,0}],
					Del_give_more(31230, 7, GoodsList , [], []);
				Type == 12 -> %% 兑换变身券
					GoodsList = [{31214,1,2,0,0}],
					Del_give_more(31230, 7, GoodsList ,[], []);
				Type == 13 -> %% 坐骑进化
					case db_agent:get_mid_prize(Player#player.id,Type) of
						[Id,_Mpid,_Mtype,_Mnum,Got] ->
							AllMount = lib_mount:get_all_mount(Player#player.id),
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
									MountStep = lists:foldl(F_step,0, AllMount),
									if
										MountStep > Got ->
											GotStep = Got + 1,
											GoodsList = 
												case GotStep of
													1 -> [{24822,2,2,0,0},{28023,1,2,0,0},{28024,1,2,0,0}];
													2 -> [{24822,4,2,0,0},{28023,2,2,0,0},{28024,2,2,0,0}];
													3 -> [{24823,3,2,0,0},{28023,3,2,0,0},{28024,3,2,0,0}];
													4 -> [{24823,5,2,0,0},{28023,4,2,0,0},{28024,3,2,0,0}];
													5 -> [{24823,10,2,0,0},{28023,5,2,0,0},{28024,3,2,0,0}];
													6 -> [{24823,15,2,0,0},{28023,6,2,0,0},{28024,3,2,0,0}];
													7 -> [{24823,20,2,0,0},{28023,7,2,0,0},{28024,3,2,0,0}];
													8 -> [{24823,25,2,0,0},{28023,8,2,0,0},{28024,3,2,0,0}];
													9 -> [{24823,30,2,0,0},{28023,9,2,0,0},{28024,3,2,0,0}];
													10 -> [{28023,20,2,0,0},{28024,10,2,0,0}];
													_ ->[]
												end,
											Give_more(GoodsList, SuccFun, [Id,[{got,GotStep}]]);
										true ->
											{fail,0}
									end;
								false ->
									{fail,0}
							end;
						_ ->
							{fail,0}
					end;
				Type == 14 -> %% 坐骑驯化
					case db_agent:get_mid_prize(Player#player.id,Type) of
						[Id,_Mpid,_Mtype,_Mnum,Got] ->
							if
								Got == 11111 ->
									{fail,0};
								true ->
									AllMount = lib_mount:get_all_mount(Player#player.id),
									case length(AllMount) > 0 of
										true ->
											F_color = fun(MountInfo,MaxColor) ->
													if
														MountInfo#ets_mount.color > MaxColor ->
															MountInfo#ets_mount.color;
														true ->
															MaxColor
													end
												end,
											MountColor = lists:foldl(F_color, 0, AllMount),
											if
												MountColor >= 2 ->
											C1 = Got rem 2,
											C2 = (Got div 10) rem 2,
											C3 = (Got div 100) rem 2,
											C4 = (Got div 1000) rem 2,
											if
												C1 == 0 andalso MountColor == 2 ->
													GetColor = 1;
												C2 == 0 andalso MountColor == 3 ->
													GetColor = 2;
												C3 == 0 andalso MountColor == 4 ->
													GetColor = 3;
												C4 == 0 andalso MountColor == 5 ->
													GetColor = 4;
												true ->
													GetColor = 0
											end,
											GoodsList = 
												case GetColor of
													1 -> [{24820,2,2,0,0},{28024,2,2,0,0}];
													2 -> [{24820,5,2,0,0},{28024,3,2,0,0}];
													3 -> [{24821,2,2,0,0},{28024,3,2,0,0}];
													4 -> [{24821,5,2,0,0},{28024,4,2,0,0}];
													_ ->[]
												end,
											NewGot = 
												case GetColor of
													1 -> 10000 + C4*1000 + C3*100 + C2*10 + 1;
													2 -> 10000 + C4*1000 + C3*100 + 10 + C1;
													3 -> 10000 + C4*1000 + 100 + C2*10 + C1;
													4 -> 10000 + 1000 + C3*100 + C2*10 + C1;
													_ -> 10000 + C4*1000 + C3*100 + C2*10 + C1
												end,
											Give_more( GoodsList, SuccFun, [Id,[{got,NewGot}]]);
												true ->
													{fail,2}
											end;
										false ->
											{fail,0}
									end
							end;
						_ ->
							{fail,0}
					end; 
				Type == 15 -> %% 登陆送好礼
					case db_agent:get_mid_prize(Player#player.id,Type) of
						[Id,_Mpid,_Mtype,Mnum,Got] ->
							if
								Mnum > Got ->
									GoodsList = [{31061,Mnum - Got ,2,0,0}],
									Give_more(GoodsList, SuccFun, [Id,[{got,Mnum}]]);
								true ->
									{fail,0}
							end;
						_ ->
							{fail,0}
					end;
				true ->
					{fail,0}
			end;
		true ->
			{fail,0}
	end.

%% =======================================================================================================================
%% ===================================================================元宵活动内容=========================================
%% =======================================================================================================================
%%元宵活动时间
lantern_festival_time() ->
	{1328313600, 1328543999}.			%%警告，正确的时间，不要随意修改，如需使用，请用下面的测试代码
	
	%%测试用代码
%% 	{1328274600, 1328278800}.

%%判断是否 是 元宵节活动时间
is_lantern_festival_time(Now) ->
	%%元宵活动时间
	{TGStart, TGEnd} = lantern_festival_time(),
	Now > TGStart andalso Now < TGEnd.

%%猜灯谜的时间，8点~~22点
get_lantern_riddles_time() ->
	{28800, 79200}.			%%警告，正确的时间，不要随意修改，如需使用，请用下面的测试代码
	
	%%测试用代码
%% 	{21*3600+55*60, 22*3600+10*60}.

%%获取元宵活动的领取情况
get_lantern_festival_info(Player, Type) ->
	#player{id = PlayerId,
			vip = Vip} = Player,
	Now = util:unixtime(),
	%%元宵活动时间
	{TGStart, TGEnd} = lantern_festival_time(),
%% 	判断是否 是 元宵节活动时间
	case Now > TGStart andalso Now < TGEnd of
		true ->
%% 			?DEBUG("it is on anniversary time", []),
			case Type of
				2 -> %%活动二	VIP专享！福利大反馈	
					case Vip >= 1 andalso Vip =< 4 of
						true ->
							case db_agent:get_mid_prize(PlayerId ,Type) of
								[_Id,_Mpid,_Mtype,_Mnum,Got] ->
									if
										Got =:= 0  ->
											[Vip, 1];
										true ->
											[Vip, 2]
									end;
								[] ->
									%% 没有记录
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,Type,1,0]),
									[Vip, 1]
							end;
						false ->%%不是vip，不能领取
							[0,0]
					end;
				1 -> %% 活动一	消费喜乐多
					Sum = count_consume(PlayerId, TGStart, TGEnd),
					case Sum > 0 of
						true ->
							Count = Sum div 500,
							case db_agent:get_mid_prize(PlayerId ,Type) of
								[_Id,_Mpid,_Mtype,_Mnum,Got] ->
									if
										Count > Got ->
											Rest = trunc(Sum - Got * 500),
											[Rest, 1];
										true ->
											Rest = trunc(Sum - Got * 500),
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
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,Type,0,0]),
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
				3 -> %% 活动三	元宵登录送好礼	
					case db_agent:get_mid_prize(PlayerId ,Type) of
						[_Id,_Mpid,_Mtype,Mnum,Got] ->
							if
								Mnum > Got ->
									[Mnum - Got, 1];
								true ->
									[0, 2]
							end;
						[] ->
							%% 没有记录
							db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,Type,1,0]),
							[1, 1]
					end;
				
				4 -> %% 活动四：经脉速提升，保护免费送			
					Check = lib_anniversary:check_aninversary_linggen(PlayerId),
					case Check >= 50 of
						true ->
							case db_agent:get_mid_prize(PlayerId,Type) of
								[_Id,_Mpid,_Mtype,_Mnum,Got] ->
									if
										Got > 0 ->
											[Check, 2];
										true ->
											[Check, 1]
									end;
								[] ->
									%% 没有记录
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,Type,0,0]),
									[Check, 1]
							end;
						false ->
							[Check, 0]
					end;
				5 -> %% 活动五：飞跃品阶，神器进化		
					{Step, Check, _Cell, _NGiveNum} = lib_act_interf:check_artifact(PlayerId, step),
%% 					?DEBUG("Step:~p, Check:~p, _Cell:~p, _NGiveNum:~p", [Step, Check, _Cell, _NGiveNum]),
					case Check of
						[] ->
							[10, 0];
						_ ->
							case db_agent:get_mid_prize(PlayerId, Type) of
								[_Id,_Mpid,_Mtype,_Mnum,Got] ->
									if
										Got > 0 ->%%已经领取
											[Step, 2];
										true ->
											[Step, 1]
									end;
								[] ->%% 没有记录
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,Type,0,0]),
									[Step, 1]
							end
					end;
				11 ->%%活动十一：如意汤圆，共庆元宵
					NeedGoods = goods_util:get_type_goods_list(Player#player.id, 31232, 4),
					TotalNum = goods_util:get_goods_totalnum(NeedGoods),
%% 					?DEBUG("TotalNum:~p", [TotalNum]),
					[TotalNum, 0];
				_ ->
					[0, 0]
			end;
		false ->
			[0, 0]
	end.

get_lantern_festival(Player, Type) ->
%% 	?DEBUG("Type:~p", [Type]),
	Now = util:unixtime(),
	%%元宵活动时间
	{TGStart, TGEnd} = lantern_festival_time(),
%% 	判断是否 是 元宵节活动时间
	case Now > TGStart andalso Now < TGEnd of
		true ->
			if
				Type >= 6 andalso Type =< 9 ->%%兑换功能
					{GoodsId, GNum, DNum} = 
						case Type of 
							6 -> {28823, 1, 20};%% 汤圆 * 20 ＝如意礼包 * 1		
							7 -> {32027, 1, 4};%% 汤圆 * 4 ＝太虚石 * 1		
							8 -> {32028, 1, 8};%% 汤圆 * 8 ＝精炼太虚石 * 1		
							9 -> {28018, 1, 5} %%汤圆 * 5 ＝9朵红玫瑰 * 1		

						end,
					NeedGoods = goods_util:get_type_goods_list(Player#player.id, 31232, 4),
					TotalNum = goods_util:get_goods_totalnum(NeedGoods),
%% 					?DEBUG("TotalNum:~p, DNum:~p", [TotalNum, DNum]),
					case TotalNum >= DNum of
						true ->
								lib_act_interf:delete_and_give(Player, 31232, DNum, GoodsId, GNum, 2, 0, [], []);
						false ->
							{fail,2}
					end;
				Type >= 1 andalso Type =< 5 ->%%领取功能
					case db_agent:get_mid_prize(Player#player.id,Type) of
						[Id,_Mpid,_Mtype,Mnum,Got] ->
							PVip = Player#player.vip,
							if
								Type =:= 2 -> %% 活动二	VIP专享！福利大反馈
									if
										Got =:= 0 andalso PVip >= 1 andalso PVip =< 4 ->
											{Give, GGot, NeedCell} = 
												case PVip of
													1 ->%%月卡
														{[{28827, 1, 2}], 1, 1};
													2 ->%%季卡
														{[{28828, 1, 2}], 1, 1};
													3 ->%%半年卡
														{[{28829, 1, 2}], 1, 1};
													4 ->%%周卡
														{[{28826, 1, 2}], 1, 1}
												end;
										true ->
											NeedCell = 0,
											GGot = 0,
											Give = []
									end;
								Type =:= 1 -> %% 活动一	消费喜乐多
									%%计算累计的消费元宝数
									Sum = count_consume(Player#player.id, TGStart, TGEnd),
									case Sum > 0 of
										true ->
											Count = Sum div 500,
											if
												Count > Got ->
													GGot = Count - Got,
													GoodsId1 = 28024,
													GoodsId2 = 28823,
													Num1 = GGot,
													Num2 = GGot,
													Cell1 = Num1 div 100 +1,
													Cell2 = Num2 div 100 +1,
													Give = [{GoodsId1, Num1, 0}, {GoodsId2, Num2, 0}],
													NeedCell = Cell1 + Cell2;
												true ->
													NeedCell = 0,
													GGot = 0,
													Give = []
											end;
										false ->
											NeedCell = 0,
											GGot = 0,
											Give = []
									end;
								Type =:= 3 -> %% 活动三	元宵登录送好礼	
									if
										Mnum > Got ->
											NeedCell = 1,
											GoodsId = 31062, %%元宵登陆礼包
											GGot = Mnum -  Got,
											Give = [{GoodsId, GGot, 2}];
										true ->
											NeedCell = 0,
											GGot = 0,
											Give = []
									end;
								Type =:= 4 -> %% 活动四：经脉速提升，保护免费送			
									Check = lib_anniversary:check_aninversary_linggen(Player#player.id),
%% 									?DEBUG("Check:~p, Got:~p", [Check, Got]),
									if
										Check >= 50 andalso Got =:= 0 ->
											{Give, GGot, NeedCell} = 
												case Check of
													50 ->
														{[{22007, 2, 2}], 1, 1};
													60 ->
														{[{22007, 4, 2}], 1, 1};
													70 ->
														{[{22007, 6, 2}], 1, 1};
													80 ->
														{[{22007, 8, 2}], 1, 1};
													90 ->
														{[{22007, 10, 2}], 1, 1};
													100 ->
														{[{23306, 88, 2},{24000,99, 2}], 2, 1};%%极品灵力丹*88；灵兽口粮*99		
													true ->
														{[], 0, 0}
												end;
										true ->
											NeedCell = 0,
											GGot = 0,
											Give = []
									end;
								Type =:= 5 -> %% 活动五：飞跃品阶，神器进化		
									{_Step, Check, Cell, NGiveNum} = lib_act_interf:check_artifact(Player#player.id, step),
									GGot = NGiveNum,
									case Check of
										[] ->
											NeedCell = 0,
											Give = [];
										_ ->
											if
												Got > 0 ->
													NeedCell = 0,
													Give = [];
												true ->
													NeedCell = Cell,
													Give = Check
											end
									end;
								true ->
									NeedCell = 0,
									GGot = 0,
									Give = []
							end,
							?DEBUG("give is :~p", [Give]),
							case Give of
								[] ->
									{fail, 0};
								_List ->
									case length(gen_server:call(Player#player.other#player_other.pid_goods,{'null_cell'})) >= NeedCell of
										true ->
											case give_list_goods(Player, Give, ok)of
												ok ->
													%%领取成功更新记录
													db_agent:update_mid_prize([{got, GGot + Got}],[{id,Id}]),
													{ok,1};
												_ ->
													{fail,0}
											end;
										false ->
											{fail,3}
									end
							end;
						[] ->
							{fail, 0}
					end;
				true ->
					{fail, 0}
			end;
		false ->
			{fail, 0}
	end.


%%二月活动
%%活动六：温泉双倍经验	
lantern_spring_award({ExpBase, SpiBase}) ->
	Now = util:unixtime(),
	%%判断是否 是 二月活动时间
	case is_february_event_time(Now) of
		true ->
			{tool:ceil(ExpBase*2), tool:ceil(SpiBase*2)};
		false ->
			{ExpBase, SpiBase}
	end.


count_consume(Pid, BeginTime, EndTime) ->
	%%获取活动消费日志
	Logs = get_lantern_consume_log(Pid, BeginTime, EndTime),
	case length(Logs) > 0 of
		true ->
			lists:foldl(fun(Elem, AccIn) ->
								[_, EG] = Elem,
								AccIn + EG
						end, 0, Logs);
		false ->
			0
	end.

%%获取二月活动活动消费日志
get_lantern_consume_log(Pid, BeginTime, EndTime) -> 
	db_agent:get_consume_log([{pid,Pid},{ct,">",BeginTime},{ct,"<",EndTime},{type,"gold"},{pit,"in", [2503, 4107, 4108, 1561, 2802,2151]},{oper,0}]).

%%活动十一：如意汤圆，共庆元宵
check_init_lantern_riddles(Player) ->
	Now = util:unixtime(),
	{_TGStart, TGEnd} = lantern_festival_time(),
%% 	判断是否 是 元宵节活动时间  的结束时间 之前
	case Now =< TGEnd of
		true ->
			case db_agent:get_lantern_riddles(Player#player.id) of
				[] ->%%第一次查询，还未弄过灯谜，需要新插数据
					%%插数据库
					db_agent:insert_lantern_riddles(Player#player.id),
					%%更新进程字典
					put(lantern, {0,0,0,0});
				[QTime, Num, State, Qid] ->
					%%更新进程字典
					put(lantern, {QTime,Num,State,Qid})
			end;
		false ->
			skip
	end.

%% -----------------------------------------------------------------
%% 30020 猜灯谜请求
%% -----------------------------------------------------------------
check_lantern_riddles(NowTime, Pid) ->
	case get(lantern) of
		undefined ->%%数据没初始化，直接返回错误
			?DEBUG("undefined", []),
			{0, 0, 0, 0};
		{QTime,Num,State,Qid} ->
			?DEBUG("QTime:~p,Num:~p,State:~p,Qid:~p", [QTime,Num,State,Qid]),
			case State of
				0 ->%%一次都没猜过
					%%随机新的灯谜Id	
					NQid = get_new_lantern_riddles(Qid),
					
					%%更新数据库数据
					WhereList = [{pid, Pid}],
					ValueList = [{qid, NQid}, {state, 1}],
					db_agent:update_lantern_riddles(ValueList, WhereList),
					%%改进程字典
					put(lantern, {QTime,Num,1,NQid}),
					{1, NQid, 1, Num+1};
				1 ->%%选好了灯谜题目，但是还未答呢
					{1, Qid, 1, Num+1};
				2 ->%%答错了一次的题目
					{1, Qid, 0, Num+1};
				3 ->%%灯谜已经答过了，重新开始判断
					case util:is_same_date(QTime, NowTime) andalso QTime =/= 0 of
						true ->
							case Num >= ?LANTERN_RIDDLES_LIMIT of
								true ->%%超过次数了
									{3, 0, 0, 0};
								false ->
									%%随机新的灯谜Id	
									NQid = get_new_lantern_riddles(Qid),
									
									%%更新数据库数据
									WhereList = [{pid, Pid}],
									ValueList = [{qid, NQid}, {state, 1}],
									db_agent:update_lantern_riddles(ValueList, WhereList),
									%%改进程字典
									put(lantern, {QTime,Num,1,NQid}),
									{1, NQid, 1, Num+1}
							end;
						false ->
							%%随机新的灯谜Id	
							NQid = get_new_lantern_riddles(Qid),
							
							%%更新数据库数据
							WhereList = [{pid, Pid}],
							ValueList = [{qid, NQid}, {state, 1}, {num, 0}],
							db_agent:update_lantern_riddles(ValueList, WhereList),
							%%改进程字典
							put(lantern, {QTime,0,1,NQid}),
							{1, NQid, 1, Num+1}
					end
			end;
		_E ->
			?DEBUG("_E:~p", [_E]),
			{0, 0, 0, 0}
	end.
%%随机新的灯谜Id	
get_new_lantern_riddles(OQid) ->
	%%灯谜Id和正确的答案
	{LLen, _LANTERN_RIDDLES} = get_lantern_riddles_answer(),
	Qid = random:uniform(LLen),
	case Qid =:= OQid of
		true ->%%居然随机到同一个，囧
			Qid rem LLen + 1;
		false ->
			Qid
	end.
	
%% -----------------------------------------------------------------
%% 30021 猜灯谜结果发送
%% -----------------------------------------------------------------
answer_lantern_riddles(Answer, NowTime, Player) ->
	#player{id = Pid} = Player,
	case get(lantern) of
		undefined ->
			0;
		{QTime,Num,State,Qid} ->
			case State of
				3 ->%%题目已经回答完啦
					7;
				2 ->%%还有一次机会
					%%灯谜Id和正确的答案
					{_LLen, LANTERN_RIDDLES} = get_lantern_riddles_answer(),
					{_Num, Key} = lists:nth(Qid, LANTERN_RIDDLES),
					case Key =:= Answer of
						false ->%%OMG,猜错了，连最后一次机会也没啦，所以没有奖励
							%%更新数据库数据
							WhereList = [{pid, Pid}],
							ValueList = [{state, 3}, {num, Num+1}, {time, NowTime}],
							db_agent:update_lantern_riddles(ValueList, WhereList),
							%%改进程字典
							put(lantern, {NowTime,Num+1,3,Qid}),
							
							3;
						true ->%%还好猜对了，有奖励
							%%发奖励
							lantern_riddles_award(Player),
							
							%%更新数据库数据
							WhereList = [{pid, Pid}],
							ValueList = [{state, 3}, {num, Num+1}, {time, NowTime}],
							db_agent:update_lantern_riddles(ValueList, WhereList),
							%%改进程字典
							put(lantern, {NowTime,Num+1,3,Qid}),
							
							1
					end;
				1 ->%%刚刚拿到题目，还未猜过
					%%灯谜Id和正确的答案
					{_LLen, LANTERN_RIDDLES} = get_lantern_riddles_answer(),
					{_Num, Key} = lists:nth(Qid, LANTERN_RIDDLES),
					case Key =:= Answer of
						false ->%%OMG,猜错了，还好有一次的容错机会
							%%更新数据库数据
							WhereList = [{pid, Pid}],
							ValueList = [{state, 2}],
							db_agent:update_lantern_riddles(ValueList, WhereList),
							%%改进程字典
							put(lantern, {QTime,Num,2,Qid}),
							
							2;
						true ->%%还好猜对了，有奖励
							%%发奖励
							lantern_riddles_award(Player),
							
							%%更新数据库数据
							WhereList = [{pid, Pid}],
							ValueList = [{state, 3}, {num, Num+1}, {time, NowTime}],
							db_agent:update_lantern_riddles(ValueList, WhereList),
							%%改进程字典
							put(lantern, {NowTime,Num+1,3,Qid}),
							
							1
					end;
				_ ->
					0
			end;
		_ ->
			0
	end.
%%猜灯谜奖励			
lantern_riddles_award(Player) ->
	Give = [{24000, 3, 2}, {31232, 2, 2}],
	case length(gen_server:call(Player#player.other#player_other.pid_goods, {'null_cell'})) >= 2 of
		true ->%%格子是足够的
			catch give_list_goods(Player, Give, ok);
		false ->%%格子不够，直接邮件
			Title = "猜灯谜奖励",
			Content = "亲爱的玩家，恭喜您猜灯谜正确，以下给予您的奖励，但是由于您的背包已满，因此直接邮件给予发送，感谢对远古封神的支持！",
			lists:foreach(fun(Elem) ->
								 {GoodsId, Num, _Bind} = Elem,
								 mod_mail:send_sys_mail([tool:to_list(Player#player.nickname)], Title, Content, 0, GoodsId, Num, 0, 0, 0)
						 end, Give)
								  
	end.

%%灯谜Id和正确的答案			
get_lantern_riddles_answer() ->
	{35, %%题目数量
	 [{1,3}, {2,1}, {3,2}, {4,4}, {5,3}, {6,1}, {7,2}, {8,4}, {9,3}, {10,1}, 
	  {11,2}, {12,4}, {13,3}, {14,1}, {15,2}, {16,4}, {17,3}, {18,1}, {19,2}, {20,4}, 
	  {21,3}, {22,1}, {23,2}, {24,4}, {25,3}, {26,1}, {27,2}, {28,4}, {29,3}, {30,1}, 
	  {31,2}, {32,4}, {33,3}, {34,1}, {35,2}]}.



%% =======================================================================================================================
%% ===================================================================情人节活动内容=========================================
%% =======================================================================================================================
%%情人节活动时间
lovedays_time() ->
	{1329091200,1329321599}.%%外服时间 2.13.08——2.15.23.59
%% 	{1329101876,1329103200}.

%%情人节表白只在14日开放1328962800
saylove_time()->
	{1329148800,1329235199}.%%外服时间2.14.08——2.14.23.59
%% 	{1329102300,1329102600}.

is_lovedays_time(Now) ->
	{S,E} = lovedays_time(),
	S=<Now andalso Now=<E.

is_saylove_time(Now) ->
	{S,E} = saylove_time(),
	S=<Now andalso Now=<E.

%% 表白面板获取当前全服的表白数据
get_all_lovers_info(Pid, PidSend) ->
	{GData, GVotes, GType} = 
		case ets:tab2list(?ETS_LOVEDAY) of
			[] ->
				{[], 0, 1};
			All ->
				{Data, Votes} = 
					lists:foldl(fun(Elem, AccIn) ->
								  {EData, ESelfVote} = AccIn,
								  #ets_loveday{id = EId,
											   pid = EPid,
											   pname = EPName,
											   rname = ERName,
											   content = EContent,
											   votes = EVotes} = Elem,
								  NESelfVote = 
									  case EPid =:= Pid of
										  true ->
											  EVotes;
										  false ->
											  ESelfVote
									  end,
								  
								  {[{EId,EPName,ERName,EContent,EVotes}|EData],NESelfVote}
						  end, {[],0}, All),
				{Data, Votes, 1}
		end,
	{ok,BinData} = pt_30:write(30024,{GData, GVotes, GType}),
	lib_send:send_to_sid(PidSend,BinData).

%%魅力排行榜
send_to_charmer(Ranking,Name) ->
	Nums = 
		case Ranking of
			1->5;
			2->3;
			3->1;
			4->1;
			5->1;
			_->0
		end,
	Title = "风华绝伦奖励",
	NameList = [tool:to_list(Name)],
	Content = io_lib:format("恭喜你荣获魅力榜排行第~p名, 特此奖励【巧克力】*~p, 感谢你的支持。",[Ranking,Nums]),
	mod_mail:send_sys_mail(NameList, Title, Content, 0, 28830, Nums, 0, 0, 0).

%%表达爱意任务，邮件奖励
send_to_task_1(Name) ->
	Title = "表达爱意奖励",
	NameList = [tool:to_list(Name)],
    Content = io_lib:format("恭喜你完成表达爱意任务, 你的勇气已经感动了爱神, 特此奖励【浓情蜜意礼包】*1",[]),
	mod_mail:send_sys_mail(NameList, Title, Content, 0, 28831, 1, 0, 0, 0).

%%默契100%，邮件奖励
send_to_task_2(Name) ->
	Title = "默契百分百奖励",
	NameList = [tool:to_list(Name)],
    Content = io_lib:format("恭喜你 在仙侣情缘中, 默契度达到100, 特此奖励【浓情蜜意礼包】*1",[]),
	mod_mail:send_sys_mail(NameList, Title, Content, 0, 28831, 1, 0, 0, 0).

%%最佳表白，邮件奖励
send_to_best_say(Name, AwardType, Num)->
	Title = io_lib:format("~s表白奖励",[AwardType]),
	NameList = [tool:to_list(Name)],
    Content = io_lib:format("恭喜您成为今日的~s表白！并获得【巧克力】*~p，祝您和您的伴侣百年好合！",[AwardType, Num]),
	mod_mail:send_sys_mail(NameList, Title, Content, 0, 28830, Num, 0, 0, 0).

%%最佳粉丝，邮件奖励 
send_to_best_fans(Name) ->
	Title = "最佳粉丝奖励",
	NameList = [tool:to_list(Name)],
    Content = io_lib:format("恭喜你所支持的玩家当选为当日最佳表白！并获得【浓情蜜意礼包】*1。",[]),
	mod_mail:send_sys_mail(NameList, Title, Content, 0, 28831, 1, 0, 0, 0).

%%新婚，邮件奖励
send_to_marry(Name)->
	Title = "新婚奖励",
	NameList = [tool:to_list(Name)],
    Content = io_lib:format("恭喜您和您的伴侣有情人终成眷属，特此获得远古情人节委员会颁发的【巧克力】1颗！",[]),
	mod_mail:send_sys_mail(NameList, Title, Content, 0, 28830, 1, 0, 0, 0).

%%情人节活动领取情况
get_lovedays_info(Player, Type) ->
	PlayerId = Player#player.id,
	Now = util:unixtime(),
	%%情人节活动时间
	{TGStart, TGEnd} = lovedays_time(),
%% 	判断是否是情人节活动时间
	case Now > TGStart andalso Now < TGEnd of
		true ->
			case Type of
				2 ->%%登录送礼包
					case db_agent:get_mid_prize(PlayerId ,Type) of
						[_Id,_Mpid,_Mtype,Mnum,Got,_Data] ->
							if
								Mnum > Got ->
									[Mnum - Got, 1];
								true ->
									[0, 2]
							end;
						[] ->
							%% 没有记录
							db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,Type,1,0]),
							[1, 1]
					end;
				3 ->%%灵兽资质大比拼
					case db_agent:get_mid_prize(PlayerId ,Type) of
						[_Id,_Mpid,_Mtype,_Mnum,_Got,Data] ->
							Params =
								case util:string_to_term(tool:to_list(Data)) of
								  undefined ->
									  [];
								  DataList ->
									  DataList
								end,
							case Params of
								[] -> %%第一次领取
									[Apt,_] = lib_pet:get_pet_max_apt_grow(PlayerId,1),
									Result = 
										if Apt >= 40 ->
											   1;    %%没有资质数据，而且在40以上， 可以领取
										   true ->
											   0     %%资质太低，领不到
										end,
									[Apt,Result];
								_->
									[Apt,_] = lib_pet:get_pet_max_apt_grow(PlayerId,1),
									Elem = trunc(Apt/10),
									Result = 
										case lists:member(Elem,Params) of%%是否有这个数据
											false ->
												if Apt >= 40 ->
													   1;   %%没有领取过这个阶段的资质数据，而且在40以上， 可以领取
												   true ->
													   0    %%资质太低，领不到
												end;
											true ->
												0 %%有这个数据，领过了，不可以再领了
												
										end,
									[Apt,Result]
							end;
						[] ->%%第一次打开领取页面
							[Apt,_] = lib_pet:get_pet_max_apt_grow(PlayerId,1),
							if Apt >= 40 ->
								   db_agent:insert_mid_prize([pid,type,num,got,other],[PlayerId,Type,0,0,util:term_to_string([])]),
								   [Apt,1];
							   true ->
								   [Apt,0]
							end
					end;
				4 -> %%成长大比拼
					case db_agent:get_mid_prize(PlayerId ,Type) of
						[_Id,_Mpid,_Mtype,_Mnum,_Got,Data] ->
							Params =
								case util:string_to_term(tool:to_list(Data)) of
								  undefined ->
									  [];
								  DataList ->
									  DataList
								end,
							case Params of
								[] ->
									[Grow,_] = lib_pet:get_pet_max_apt_grow(PlayerId,2),
									Result = 
										if Grow >= 30 ->
											   1;
										   true ->
											   0
										end,
									[Grow,Result];
								_->
									[Grow,_] = lib_pet:get_pet_max_apt_grow(PlayerId,2),
									Elem = trunc(Grow/10),
									Result = 
										case lists:member(Elem,Params) of%%是否有这个数据
											false ->
												if Grow >= 30 ->
													   1;   %%没有领取过这个阶段的成长数据，而且在40以上， 可以领取
												   true ->
													   0    %%成长太低，领不到
												end;
											true ->
												0 %%有这个数据，领过了，不可以再领了
										end,
									[Grow,Result]
							end;
						[] ->
							[Grow,_] = lib_pet:get_pet_max_apt_grow(PlayerId,2),
							if Grow >= 30 ->
								   %%没有奖励记录，但是符合条件，插入记录先
								   db_agent:insert_mid_prize([pid,type,num,got,other],[PlayerId,Type,0,0,util:term_to_string([])]),
								   [Grow,1];
							   true ->
								   [Grow,0]
							end
					end;
				_ ->
					[0,0]
			end;
		false ->
			[0,0]
	end.

%%资质阶段领取奖品、奖品数
apt_award_data(Apt) ->
	if Apt =:= 4 -> {24400,2};
	   Apt =:= 5 -> {24401,1};
	   Apt =:= 6 -> {24401,2};
	   Apt =:= 7 -> {24401,4};
	   Apt =:= 8 -> {24401,6};
	   Apt =:= 9 -> {24401,8};
	   Apt =:= 10 -> {24800,15};
	   true ->
		   {0,0}
	end.

%%成长阶段领取奖品、奖品数
grow_award_data(Grow) ->
	if Grow =:= 3 -> {24104,1};
	   Grow =:= 4 -> {24105,1};
	   Grow =:= 5 -> {24105,2};
	   Grow =:= 6 -> {24105,4};
	   Grow =:= 7 -> {24105,6};
	   Grow =:= 8 -> {24800,15};
	   true ->
		   {0,0}
	end.

%%领取奖品
get_loverdays_goods(Player,Type)->
	PlayerId = Player#player.id,
	Now = util:unixtime(),
	%%先判断是否活动时间
	case is_lovedays_time(Now) of
		true ->
			%%判断是否有领取资格
			case db_agent:get_mid_prize(Player#player.id,Type) of
				[Id,_Mpid,_Mtype,Mnum,Got,Data] ->
					if 
						Type =:= 2 ->%%情人节登陆礼包
							if
								Mnum > Got ->
									NeedCell = 1,
									GoodsId = 28705, %%情人节登陆礼包
									GGot = Mnum -  Got,
									Give = [{GoodsId, GGot, 2, 0}];
								true ->
									NeedCell = 0,
									GGot = 0,
									Give = []
							end;
						Type =:= 3 ->%%资质大比拼
							case util:string_to_term(tool:to_list(Data)) of
								  undefined ->
									  NeedCell = 0,
									  GGot = 0,
									  Give = [];
								  DataList ->
									  [Apt,_] = lib_pet:get_pet_max_apt_grow(PlayerId,1),
									  Elem = trunc(Apt/10),
									  case DataList of
										  [] -> %%还没领过
											  {GoodsId,Nums} = apt_award_data(Elem),
											  NeedCell = 1,
											  GGot = 0,
											  Give = [{GoodsId, Nums, 2, [Elem]}];
										  Old->
											  case lists:member(Elem,DataList) of
												  false ->
													  {GoodsId,Nums} = apt_award_data(Elem),
													  NeedCell = 1,
													  GGot = 0,
													  Give = [{GoodsId, Nums, 2, [Elem]++Old}];
												  true ->
													  NeedCell = 0,
													  GGot = 0,
													  Give = []
											  end
									  end
							end;
						Type =:= 4 ->
							case util:string_to_term(tool:to_list(Data)) of
								  undefined ->
									  NeedCell = 0,
									  GGot = 0,
									  Give = [];
								  DataList ->
									  [Grow,_] = lib_pet:get_pet_max_apt_grow(PlayerId,2),
									  Elem = trunc(Grow/10),
									  case DataList of
										  [] -> %%还没领过
											  {GoodsId,Nums} = grow_award_data(Elem),
											  NeedCell = 1,
											  GGot = 0,
											  Give = [{GoodsId, Nums, 2, [Elem]}];
										  Old->
											  case lists:member(Elem,DataList) of
												  false -> %%这个阶段还没领过
													  {GoodsId,Nums} = grow_award_data(Elem),
													  NeedCell = 1,
													  GGot = 0,
													  Give = [{GoodsId, Nums, 2, Old++[Elem]}];
												  true ->
													  NeedCell = 0,
													  GGot = 0,
													  Give = []
											  end
									  end
							end;
						true ->
							NeedCell = 0,
							GGot = 0,
							Give = []
					end,
				case Give of
					[] ->
						{fail, 0};
					[{Gid, Num, Bind, Value}] ->
						case length(gen_server:call(Player#player.other#player_other.pid_goods,{'null_cell'})) >= NeedCell of
							true ->
								case give_list_goods(Player, [{Gid, Num, Bind}], ok)of
									ok ->
										%%领取成功更新记录
										if Type =:= 2 ->
											   db_agent:update_mid_prize([{got, GGot + Got}],[{id,Id}]),
											   {ok,1};
										   Type =:= 3 orelse Type =:= 4 ->
											   AptData = util:term_to_string(Value),
											   db_agent:update_mid_prize([{other, AptData}],[{id,Id}]),
											   {ok,1};
										   true ->
											   {fail,0}
										end;
									_ ->
										{fail,0}
								end;
							false ->
								{fail,3}
						end
				end;
				[] ->%%条件不满足
					{fail,0}
			end;
		false ->
			{fail,0}
	end.

%%获取全部表白数据
get_all_love_data() ->
	case db_agent:get_love_data() of
		[] ->
			[];
		LoveData ->
			lists:foreach(fun(Elem) ->
								  [Id, Pid, Rid, PName, RName, Content, Votes, VotersStr] = Elem,
								  Voters = util:string_to_term(tool:to_list(VotersStr)),
								  LoveDay = 
									  #ets_loveday{
												   id = Id,
												   pid = Pid,		%%玩家Id
												   rid = Rid,
												   pname = PName,	%%玩家名字
												   rname = RName,
												   content = Content,	%%
												   votes = Votes,
												   voters = Voters
												  },
								  ets:insert(?ETS_LOVEDAY, LoveDay),
								  lists:foreach(fun(InsideElem) ->
														InsideEtsLove = #ets_voters{playerid = InsideElem},
														ets:insert(?ETS_VOTERS,InsideEtsLove)
												end, Voters)
				  end, LoveData)
	end.


%% =======================================================================================================================
%% ===================================================================二月活动内容=========================================
%% =======================================================================================================================
%% 二月活动时间
february_event_time() ->
	%%警告，正确的时间，不要随意修改，如需使用，请用下面的测试代码
	case config:get_platform_name()of
		"cmwebgame" ->%%台晚
			{1330041600, 1330358399};
		"memoriki" ->%%香港
			{1330041600, 1330358399};
		"1766game" ->%%杨麒
			{1330041600, 1330358399};
		_ ->%%默认
			{1330041600, 1330271999}
	end.

%% 	%%测试用代码
%% 	{1330003800, 1330008300}.

%%判断是否 是 二月活动时间
is_february_event_time(Now) ->
	%%元宵活动时间
	{TGStart, TGEnd} = february_event_time(),
	Now > TGStart andalso Now < TGEnd.


%%获取二月活动的领取情况
get_february_event_info(Player, Type) ->
	#player{id = PlayerId,
			vip = Vip} = Player,
	Now = util:unixtime(),
	%%二月活动时间
	{TGStart, TGEnd} = february_event_time(),
%% 	判断是否 是 二月活动时间
	case Now > TGStart andalso Now < TGEnd of
		true ->
%% 			?DEBUG("it is on anniversary time", []),
			case Type of
				1 -> %%活动一	VIP专享！福利大反馈	
					case Vip >= 1 andalso Vip =< 4 of
						true ->
							case db_agent:get_mid_prize(PlayerId ,Type) of
								[_Id,_Mpid,_Mtype,_Mnum,Got] ->
									if
										Got =:= 0  ->
											[Vip, 1];
										true ->
											[Vip, 2]
									end;
								[] ->
									%% 没有记录
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,Type,1,0]),
									[Vip, 1]
							end;
						false ->%%不是vip，不能领取
							[0,0]
					end;
				2 -> %% 活动二	消费喜乐多
					Sum = count_consume(PlayerId, TGStart, TGEnd),
					case Sum > 0 of
						true ->
							Count = Sum div 500,
							case db_agent:get_mid_prize(PlayerId ,Type) of
								[_Id,_Mpid,_Mtype,_Mnum,Got] ->
									if
										Count > Got ->
											Rest = trunc(Sum - Got * 500),
											[Rest, 1];
										true ->
											Rest = trunc(Sum - Got * 500),
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
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,Type,0,0]),
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
				3 -> %% 活动三	登录送好礼
					case db_agent:get_mid_prize(PlayerId ,Type) of
						[_Id,_Mpid,_Mtype,Mnum,Got] ->
							if
								Mnum > Got ->
									[Mnum - Got, 1];
								true ->
									[0, 2]
							end;
						[] ->
							%% 没有记录
							db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,Type,1,0]),
							[1, 1]
					end;
				4 -> %% 活动四：坐骑进化，龙腾四海 		
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
							case db_agent:get_mid_prize(PlayerId,Type) of
								[_Id,_Mpid,_Mtype,_Mnum,Got] ->
									if
										Step > Got ->
											[Step,1];
										true ->
											[Step,0]
									end;
								_ ->
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,Type,Step,0]),
									[Step,1]
							end;
						false ->
							[1,0]
					end;
				5 -> %% 活动五：飞跃品阶，神器进化		
					{Step, Check, _Cell, _NGiveNum} = lib_act_interf:check_artifact(PlayerId, step),
%% 					?DEBUG("Step:~p, Check:~p, _Cell:~p, _NGiveNum:~p", [Step, Check, _Cell, _NGiveNum]),
					case Check of
						[] ->
							[10, 0];
						_ ->
							case db_agent:get_mid_prize(PlayerId, Type) of
								[_Id,_Mpid,_Mtype,_Mnum,Got] ->
									if
										Got > 0 ->%%已经领取
											[Step, 2];
										true ->
											[Step, 1]
									end;
								[] ->%% 没有记录
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,Type,0,0]),
									[Step, 1]
							end
					end;
				13 -> %% 活动九：二月春播，希望之种		
					NeedGoods = goods_util:get_type_goods_list(Player#player.id, 31233, 4),
					TotalNum = goods_util:get_goods_totalnum(NeedGoods),
%% 					?DEBUG("TotalNum:~p", [TotalNum]),
					[TotalNum, 0];
				_ ->
					[0, 0]
			end;
		false ->
			[0, 0]
	end.

get_february_event(Player, Type) ->
%% 	?DEBUG("Type:~p", [Type]),
	Now = util:unixtime(),
	%%二月活动时间
	{TGStart, TGEnd} = february_event_time(),
%% 	判断是否 是 二月活动时间
	case Now > TGStart andalso Now < TGEnd of
		true ->
			if
				Type >= 9 andalso Type =< 12 ->%%兑换功能
					{GoodsId, GNum, DNum} = 
						case Type of 
							9 -> {28823, 1, 10};%% 希望之种 * 10 ＝如意礼包 * 1			
							10 -> {24822, 1, 2};%% 希望之种 * 2 ＝飞灵丹 * 1		
							11 -> {24823, 1, 6};%% 希望之种 * 6 ＝飞灵仙丹 * 1			
							12 -> {28018, 1, 3} %% 希望之种 * 3 ＝9朵红玫瑰 * 1			

						end,
					NeedGoods = goods_util:get_type_goods_list(Player#player.id, 31233, 4),
					TotalNum = goods_util:get_goods_totalnum(NeedGoods),
%% 					?DEBUG("TotalNum:~p, DNum:~p", [TotalNum, DNum]),
					case TotalNum >= DNum of
						true ->
								lib_act_interf:delete_and_give(Player, 31233, DNum, GoodsId, GNum, 2, 0, [], []);
						false ->
							{fail,2}
					end;
				Type >= 1 andalso Type =< 5 ->%%领取功能
					case db_agent:get_mid_prize(Player#player.id,Type) of
						[Id,_Mpid,_Mtype,Mnum,Got] ->
							PVip = Player#player.vip,
							if
								Type =:= 1 -> %% 活动一	VIP专享！福利大反馈	
									if
										Got =:= 0 andalso PVip >= 1 andalso PVip =< 4 ->
											{Give, GGot, NeedCell} = 
												case PVip of
													1 ->%%月卡
														{[{28827, 1, 2}], 1, 1};
													2 ->%%季卡
														{[{28828, 1, 2}], 1, 1};
													3 ->%%半年卡
														{[{28829, 1, 2}], 1, 1};
													4 ->%%周卡
														{[{28826, 1, 2}], 1, 1}
												end;
										true ->
											NeedCell = 0,
											GGot = 0,
											Give = []
									end;
								Type =:= 2 -> %% 活动二	消费喜乐多
									%%计算累计的消费元宝数
									Sum = count_consume(Player#player.id, TGStart, TGEnd),
									case Sum > 0 of
										true ->
											Count = Sum div 500,
											if
												Count > Got ->
													GGot = Count - Got,
													GoodsId1 = 28024,
													GoodsId2 = 28823,
													Num1 = GGot,
													Num2 = GGot,
													Cell1 = Num1 div 100 +1,
													Cell2 = Num2 div 100 +1,
													Give = [{GoodsId1, Num1, 0}, {GoodsId2, Num2, 0}],
													NeedCell = Cell1 + Cell2;
												true ->
													NeedCell = 0,
													GGot = 0,
													Give = []
											end;
										false ->
											NeedCell = 0,
											GGot = 0,
											Give = []
									end;
								Type =:= 3 -> %% 活动三	登录送好礼
									if
										Mnum > Got ->
											NeedCell = 1,
											GoodsId = 28705, %%节日登陆礼包
											GGot = Mnum -  Got,
											Give = [{GoodsId, GGot, 2}];
										true ->
											NeedCell = 0,
											GGot = 0,
											Give = []
									end;
								Type =:= 4 ->
									AllMount = lib_mount:get_all_mount(Player#player.id),
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
											MountStep = lists:foldl(F_step,0, AllMount),
											if
												MountStep > Got ->
													GGot = MountStep-Got,
													{Give, NeedCell} = 
														case MountStep of
															1 -> %% 1阶	飞灵丹*2，绑定铜钱卡*1，小礼券*1			
																{[{24822,2,2},{28023,1,2},{28024,1,2}], 3};
															2 -> %% 2阶	飞灵丹*4，绑定铜钱卡*2，小礼券*2			
																{[{24822,4,2},{28023,2,2},{28024,2,2}], 3};
															3 -> %% 3阶	飞灵仙丹*3，绑定铜钱卡*3，小礼券*3			
																{[{24823,3,2},{28023,3,2},{28024,3,2}], 3};
															4 -> %% 4阶	飞灵仙丹*5，绑定铜钱卡*4，小礼券*3			
																{[{24823,5,2},{28023,4,2},{28024,3,2}], 3};
															5 -> %% 5阶	飞灵仙丹*10，绑定铜钱卡*5，小礼券*3			
																{[{24823,10,2},{28023,5,2},{28024,3,2}], 3};
															6 -> %% 6阶	飞灵仙丹*15，绑定铜钱卡*6，小礼券*3			
																{[{24823,15,2},{28023,6,2},{28024,3,2}], 3};
															7 -> %% 7阶	飞灵仙丹*20，绑定铜钱卡*7，小礼券*3			
																{[{24823,20,2},{28023,7,2},{28024,3,2}], 3};
															8 -> %% 8阶	飞灵仙丹*25，绑定铜钱卡*8，小礼券*3			
																{[{24823,25,2},{28023,8,2},{28024,3,2}], 3};
															9 -> %% 9阶	飞灵仙丹*30，绑定铜钱卡*9，小礼券*3			
																{[{24823,30,2},{28023,9,2},{28024,3,2}], 3};
															10 -> %% 10阶	绑定铜钱卡*20，小礼券*10		
																{[{28023,20,2},{28024,10,2}], 3};
															_ ->%% 这是什么东东
																{[], 0}
														end;
												true ->
													NeedCell = 0,
													GGot = 0,
													Give = []
											end;
										false ->
											NeedCell = 0,
											GGot = 0,
											Give = []
									end;
								Type =:= 5 -> %% 活动五：飞跃品阶，神器进化		
									{_Step, Check, Cell, NGiveNum} = lib_act_interf:check_artifact(Player#player.id, step),
									GGot = NGiveNum,
									case Check of
										[] ->
											NeedCell = 0,
											Give = [];
										_ ->
											if
												Got > 0 ->
													NeedCell = 0,
													Give = [];
												true ->
													NeedCell = Cell,
													Give = Check
											end
									end;
								true ->
									NeedCell = 0,
									GGot = 0,
									Give = []
							end,
							?DEBUG("give is :~p", [Give]),
							case Give of
								[] ->
									{fail, 0};
								_List ->
									case length(gen_server:call(Player#player.other#player_other.pid_goods,{'null_cell'})) >= NeedCell of
										true ->
											case give_list_goods(Player, Give, ok)of
												ok ->
													%%领取成功更新记录
													db_agent:update_mid_prize([{got, GGot + Got}],[{id,Id}]),
													{ok,1};
												_ ->
													{fail,0}
											end;
										false ->
											{fail,3}
									end
							end;
						[] ->
							{fail, 0}
					end;
				true ->
					{fail, 0}
			end;
		false ->
			{fail, 0}
	end.


%% 整个个活动持续时间
arbor_white_time() ->
%% 	警告，正确的时间，不要随意修改，如需使用，请用下面的测试代码
	case config:get_platform_name()of
		"cmwebgame" ->%%台湾
			{1331517600, 1331999999};	%%	2012年3月12日10时 至 2012年3月17日23:59
		"memoriki" ->%%香港
			{1331517600, 1331999999};	%%	2012年3月12日10时 至 2012年3月17日23:59
		"1766game" ->%%杨麒
			{1331517600, 1331999999};	%%	2012年3月12日10时 至 2012年3月17日23:59
		_ ->%%默认
			{1331251200, 1331740799}	%%	2012年3月9日8时 至 2012年3月14日23时59分59秒
	end.

%% 	%%测试用代码
%% 	{1331204400+7200, 1331208000+7200}.

%% 白色情人节活动时间			
%% 活动时间：2012年3月13日0时 至 2012年3月14日23时59分59秒
whiteday_time() ->
%% 	警告，正确的时间，不要随意修改，如需使用，请用下面的测试代码
	case config:get_platform_name()of
		"cmwebgame" ->%%台湾
			{1331568000, 1331740799};	%%	2012年3月13日0时 至 2012年3月14日23时59分59秒
		"memoriki" ->%%香港
			{1331568000, 1331740799};	%%	2012年3月13日0时 至 2012年3月14日23时59分59秒
		"1766game" ->%%杨麒
			{1331568000, 1331740799};	%%	2012年3月13日0时 至 2012年3月14日23时59分59秒
		_ ->%%默认
			{1331568000, 1331740799}	%%	2012年3月13日0时 至 2012年3月14日23时59分59秒
	end.

%% 	%%测试用代码
%% 	{1331205600+7200, 1331207400+7200}.

%%判断是否 是 白色情人节活动时间
is_whiteday_time(Now) ->
	%%白色情人节活动时间
	{TGStart, TGEnd} = whiteday_time(),
	Now > TGStart andalso Now < TGEnd.

%% 植树节活动时间			
%% 活动时间：2012年3月9日8时 至 2012年3月12日23时59分59秒				
arborday_time() ->
%% 	警告，正确的时间，不要随意修改，如需使用，请用下面的测试代码
	case config:get_platform_name()of
		"cmwebgame" ->%%台湾
			{1331517600, 1331913599};	%%	2012年3月12日10时 至 2012年3月16日23:59
		"memoriki" ->%%香港
			{1331517600, 1331913599};	%%	2012年3月12日10时 至 2012年3月16日23:59
		"1766game" ->%%杨麒
			{1331517600, 1331913599};	%%	2012年3月12日10时 至 2012年3月16日23:59
		_ ->%%默认
			{1331251200, 1331567999}	%%	2012年3月9日8时 至 2012年3月12日23时59分59秒
	end.

%% 	%%测试用代码
%% 	{1331204400+7200, 1331205600+7200}.

%% 判断是否 是 植树节活动时间
is_arborday_time(Now) ->
	%%植树节活动时间
	{TGStart, TGEnd} = arborday_time(),
	Now > TGStart andalso Now < TGEnd.
%% 小魔头出来的时间
little_devil_time() ->
	{45000, 66600}.	%%警告，正确的时间，不要随意修改，如需使用，请用下面的测试代码
	
	%%测试用时间
%% 	{21*3600+05*60, 21*3600+15*60}.


%%获取植树、白色情人节活动的领取情况
get_arborwhite_info(Player, Type) ->
	#player{id = PlayerId,
			other = PlayerOther} = Player,
	Now = util:unixtime(),
	%% 整个个活动持续时间
	{EventStart, EventEnd} = arbor_white_time(),
	%% 植树节活动时间
	{ArborStart, ArborEnd} = arborday_time(),
	case Type of
		1 -> %% 活动二：登录送好礼
			%% 			判断是否是在活动指定的时间段里
			case Now > EventStart andalso Now < EventEnd of
				true ->
					case db_agent:get_mid_prize(PlayerId ,Type) of
						[_Id,_Mpid,_Mtype,Mnum,Got] ->
							if
								Mnum > Got ->
									[Mnum - Got, 1];
								true ->
									[0, 2]
							end;
						[] ->
							%% 没有记录
							db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,Type,1,0]),
							[1, 1]
					end;
				false ->
					[0, 0]
			end;
		2 -> %% 活动四：击败小魔头	
			%% 			判断是否是在活动指定的时间段里
			case Now > ArborStart andalso Now < ArborEnd of
				true ->
					NeedGoods = goods_util:get_type_goods_list(Player#player.id, 31234, 4),
					TotalNum = goods_util:get_goods_totalnum(NeedGoods),
					%% 					?DEBUG("TotalNum:~p", [TotalNum]),
					[TotalNum, 0];	
				false ->
					[0,0]
			end;
		3 -> %% 活动五：	全身强化，潜力无限 
			%% 			判断是否是在活动指定的时间段里
			case Now > EventStart andalso Now < EventEnd of
				true ->
					FullStren = PlayerOther#player_other.fullstren,
%%					?DEBUG("FullStren:~p", [FullStren]),
					if
						FullStren =/= undefined andalso FullStren >= 5 andalso FullStren =< 10 ->
							case db_agent:get_mid_prize(PlayerId, Type) of
								[_Id,_Mpid,_Mtype,_Mnum,Got] ->
									if
										Got > 0 ->%%已经领取
											[FullStren, 2];
										true ->
											[FullStren, 1]
									end;
								[] ->%% 没有记录
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,Type,0,0]),
									[FullStren, 1]
							end;
						true ->
							[0, 0]
					end;
				false ->
					[0,0]
			end;
		4 -> %% 活动六：经脉速提升，保护免费送	
			%% 			判断是否是在活动指定的时间段里
			case Now > EventStart andalso Now < EventEnd of
				true ->
					Check = lib_anniversary:check_aninversary_linggen(PlayerId),
					case Check >= 50 of
						true ->
							case db_agent:get_mid_prize(PlayerId,Type) of
								[_Id,_Mpid,_Mtype,_Mnum,Got] ->
									IfGot = 
										case Check of
											50 ->
												Got rem 2;
											60 ->
												(Got div 10) rem 2;
											70 ->
												(Got div 100) rem 2;
											80 ->
												(Got div 1000) rem 2;
											90 ->
												(Got div 10000) rem 2;
											100 ->
												(Got div 100000) rem 2;
											_ ->
												1
										end,
									case IfGot of
										0 ->
											[Check, 1];
										1 ->
											[Check, 2]
									end;
								[] ->
									%% 没有记录
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,Type,0,1000000]),
									[Check, 1]
							end;
						false ->
							[Check, 0]
					end;
				false ->
					[0,0]
			end;
		_ ->
			[0, 0]
	end.
%% 植树、白色情人节领取活动
get_arborwhite(Player, Type) ->
	#player{id = PlayerId,
			other = PlayerOther} = Player,
	Now = util:unixtime(),
	%% 整个个活动持续时间
	{EventStart, EventEnd} = arbor_white_time(),
	%% 植树节活动时间
	{ArborStart, ArborEnd} = arborday_time(),
	case Type of
		1 -> %% 活动二：登录送好礼
			%% 			判断是否是在活动指定的时间段里
			case Now > EventStart andalso Now < EventEnd of
				true ->
					case db_agent:get_mid_prize(PlayerId ,Type) of
						[Id,_Mpid,_Mtype,MNum,Got] ->
							if
								MNum > Got ->
									GoodsId = 31014,	%%	节日登录礼包
									case catch (gen_server:call(Player#player.other#player_other.pid_goods, 
																{'give_goods', Player, GoodsId, 1, 2})) of
										ok ->
											%%领取成功更新记录
											db_agent:update_mid_prize([{got, 1 + Got}],[{id,Id}]),
											{ok,1};
										cell_num ->%%背包空间不足
											{fail,3};
										_ ->%%其他报错，OMG
											{fail,0}
									end;
								true ->
									{fail, 0}
							end;
						[] ->
							{fail, 0}
					end;
				false ->
					{fail, 5}
			end;
		2 ->%% 活动四：击败小魔头	
			%% 			判断是否是在活动指定的时间段里
			case Now > ArborStart andalso Now < ArborEnd of
				true ->
					{GGoodsId, DGoodsId, GNum, DNum} = {28830, 31234, 1, 20},
					NeedGoods = goods_util:get_type_goods_list(Player#player.id, DGoodsId, 4),
					TotalNum = goods_util:get_goods_totalnum(NeedGoods),
					case TotalNum >= DNum of
						true ->
							lib_act_interf:delete_and_give(Player, DGoodsId, DNum, GGoodsId, GNum, 2, 0, [], []);
						false ->
							{fail,2}
					end;
				false ->
					{fail, 5}
			end;
		3 -> %% 活动五：	全身强化，潜力无限 
			%% 			判断是否是在活动指定的时间段里
			case Now > EventStart andalso Now < EventEnd of
				true ->
					FullStren = PlayerOther#player_other.fullstren,
					if
						FullStren =/= undefined andalso FullStren >= 5 andalso FullStren =< 10->
							case db_agent:get_mid_prize(PlayerId, Type) of
								[Id,_Mpid,_Mtype,_Mnum,Got] ->
									if
										Got > 0 ->%%已经领取
											{fail, 0};
										true ->
											GoodsId = lib_act_interf:fullstren_to_goodsid(FullStren),
											case catch (gen_server:call(Player#player.other#player_other.pid_goods, 
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
			end;
		4 -> %% 活动六：经脉速提升，保护免费送	
			%% 			判断是否是在活动指定的时间段里
			case Now > EventStart andalso Now < EventEnd of
				true ->
					Check = lib_anniversary:check_aninversary_linggen(PlayerId),
					case Check >= 50 of
						true ->
							case db_agent:get_mid_prize(PlayerId,Type) of
								[Id,_Mpid,_Mtype,_Mnum,Got] ->
									C100 = (Got div 100000) rem 2,
									C90 = (Got div 10000) rem 2,
									C80 = (Got div 1000) rem 2,
									C70 = (Got div 100) rem 2,
									C60 = (Got div 10) rem 2,
									C50 = Got rem 2,
									if
										Check =:= 100 andalso C100=:= 0 ->
											NewGot = 1000000 + 100000 + C90*10000 + C80*1000 + C70*100+ C60*10 + C50,
											NeedCell = 2,
											Give = [{23306, 88, 2}, {24000, 99, 2}];
										Check =:= 90 andalso C90 =:= 0 ->
											NewGot = 1000000 + C100*100000 + 10000 + C80*1000 + C70*100+ C60*10 + C50,
											NeedCell = 1,
											Give = [{22007, 8, 2}];
										Check =:= 80 andalso C80 =:= 0 ->
											NewGot = 1000000 + C100*100000 + C90*10000 + 1000 + C70*100+ C60*10 + C50,
											NeedCell = 1,
											Give = [{22007, 6, 2}];
										Check =:= 70 andalso C70 =:= 0 ->
											NewGot = 1000000 + C100*100000 + C90*10000 + C80*1000 + 100+ C60*10 + C50,
											NeedCell = 1,
											Give = [{22007, 4, 2}];
										Check =:= 60 andalso C60 =:= 0 ->
											NewGot = 1000000 + C100*100000 + C90*10000 + C80*1000 + C70*100+ 10 + C50,
											NeedCell = 1,
											Give = [{22007, 2, 2}];
										Check =:= 50 andalso C50 =:= 0 ->
											NewGot = 1000000 + C100*100000 + C90*10000 + C80*1000 + C70*100+ C60*10 + 1,
											NeedCell = 1,
											Give = [{22007, 1, 2}];
										true ->
											NewGot = Got,
											NeedCell = 0,
											Give = []
									end,
									case Give of
										[] ->
											{fail, 0};
										_ ->
											
											case length(gen_server:call(Player#player.other#player_other.pid_goods,{'null_cell'})) >= NeedCell of
												true ->
													case give_list_goods(Player, Give, ok)of
														ok ->
															%%领取成功更新记录
															db_agent:update_mid_prize([{got, NewGot}],[{id,Id}]),
															{ok,1};
														_ ->
															{fail,0}
													end;
												false ->
													{fail,3}
											end
									end;
								[] ->
									{fail, 0}
							end;
						false ->
							{fail, 0}
					end;
				false ->
					{fail, 5}
			end;
		_ ->
			{fail, 0}
	end.

-define(LITTLEDEVIL_APPER_SCENE, 300).
-define(LITTLEDEVIL_MON_ID, 40976).
-define(LITTLE_DEVIL_COORD, {55, 108}).

reflesh_littledevil(NowSec) ->
	Now = util:unixtime(),
	case is_arborday_time(Now) of
		true ->
			%% 小魔头出来的时间
			{TOne,TTwo} = little_devil_time(),
			IsOn = little_devil_ison(),
			case get_littledevil_start() of
				0 ->
					case ((NowSec >= TOne andalso NowSec =< TOne + 20) 
							  orelse (NowSec >= TTwo andalso NowSec =< TTwo + 20))
							 andalso IsOn =:= false of
						true ->
%% 							?DEBUG("ok",[]),
							put_littledevil_start(1),
							make_little_devil(),
							%%更新当前存在的小魔头的数量
							update_little_devil(),
							%%取消过去的定时器
%% 							?DEBUG("00000NowSec:~p",[NowSec]),
							ok;
						_ ->
%% 							?DEBUG("11111NowSec:~p",[NowSec]),
							case ((NowSec >= TOne andalso NowSec =< TOne + 20) =:= false
									  andalso  (NowSec >= TTwo andalso NowSec =< TTwo + 20)) =:= false of
								true ->
									put_littledevil_start(0);
								false ->
									skip
							end
					end;
				_ ->
%% 					?DEBUG("3333333NowSec:~p",[NowSec]),
					case ((NowSec >= TOne andalso NowSec =< TOne + 20) =:= false
							  andalso  (NowSec >= TTwo andalso NowSec =< TTwo + 20)) =:= false of
						true ->
							put_littledevil_start(0);
						false ->
							skip
					end
			end;
		false ->
%% 			?DEBUG("444444444NowSec:~p",[NowSec]),
			skip
	end.

get_littledevil_start() ->
	case get(lds) of
		{IsStart}  ->
			IsStart;
		_ ->
			0
	end.
put_littledevil_start(IsStart) ->
	put(lds, {IsStart}).

little_devil_ison() ->
	case get(little_devil) of
		{Nth,Num} ->
			case Num =< 0 andalso Nth =< 0 of
				true ->%%怪物的数量没了,可以刷怪物了
					false;
				false ->
					true
			end;
		_ ->
			false
	end.

minus_little_devil() ->
	case get(little_devil) of
		{Nth, Num} ->
			NNum = Num-1,
				case NNum =< 0 of
					true ->
						case Nth =< 0 of
							true ->
								put(little_devil,{Nth, NNum}),
								goon;
							false ->
								put(little_devil,{Nth-1, 2}),
								next
						end;
					false ->
						put(little_devil,{Nth, NNum}),
						goon
				end;
		_ ->
			put(little_devil,{0,0}),
			goon
	end.
%% 初始化小魔头的数据
update_little_devil() ->
	put(little_devil, {4, 2}).

%%小魔头出现的坐标
get_littledevil_coords() ->
	Num1 = util:rand(-5, 5),
	Num2 = util:rand(-5, 5),
	Num3 = util:rand(-5, 5),
	Num4 = util:rand(-5, 5),
	{PX,PY} = ?LITTLE_DEVIL_COORD,
	[{0, {trunc(PX+Num1),trunc(PY+Num2)}}, {0, {trunc(PX+Num3),trunc(PY+Num4)}}].

%%小魔头死亡，通知数量减少
little_devil_die() ->
	gen_server:cast(mod_title:get_mod_title_pid(), {'KILL_LITTLE_DEVIL'}).
kill_little_devil() ->
	case minus_little_devil() of
		goon ->
			skip;
		next ->
			make_little_devil()
	end.

%% 生成小魔头
make_little_devil() ->
	%%获取小魔头出现的坐标
	NewCoords = get_littledevil_coords(),
	%%获取场景的Pid
	ScenePid = mod_scene:get_scene_pid(?LITTLEDEVIL_APPER_SCENE, undefined, undefined),
	%%小魔头出现的广播
	MSG = "<font color='#FFFFFF'>毁林小魔头</font>意图偷食蟠桃！快去将其击退吧！  <a href='event:6,300,55,108'><font color='#00FF33'><u>》》我要前往《《</u></font></a>",
	spawn(fun()->lib_chat:broadcast_sys_msg(2, MSG)end),
	%%想场景发信息，通知生成怪物
	gen_server:cast(ScenePid, {apply_cast, lib_scene, load_christmas_mon, [?LITTLEDEVIL_MON_ID, ?LITTLEDEVIL_APPER_SCENE, NewCoords]}),
	MSGBroad = "OH my God！这么神奇的蟠桃树，简直就是暴殄天物哇，应该种我家里才对嘛...^_-",
	{ok, BinData39100} = pt_39:write(39100, [16, MSGBroad]),
	timer:apply_after(2000, mod_scene_agent, send_to_scene,[?LITTLEDEVIL_APPER_SCENE, BinData39100]).

%% 三月活动
%% 活动时间：2010年3月28日8时～2010年3月30日23时59分					
march_event_time() ->
%% 	警告，正确的时间，不要随意修改，如需使用，请用下面的测试代码
	case config:get_platform_name()of
		"cmwebgame" ->%%台湾
			{1332892800, 1333123199};	%%	2010年3月28日8时～2010年3月30日23时59分
		"memoriki" ->%%香港
			{1332892800, 1333123199};	%%	2010年3月28日8时～2010年3月30日23时59分
		"1766game" ->%%杨麒
			{1332892800, 1333123199};	%%	2010年3月28日8时～2010年3月30日23时59分
		_ ->%%默认
			{1332892800, 1333123199}	%%	2010年3月28日8时～2010年3月30日23时59分
	end.

%% 	%%测试用代码
%% 	{1332852900, 1332944100}.

%%判断是否 是 三月活动时间
is_march_event_time(Now) ->
	%%三月活动时间
	{TGStart, TGEnd} = march_event_time(),
	Now > TGStart andalso Now < TGEnd.

%%获取三月活动的领取情况
get_march_event_info(Player, Type) ->
	#player{id = PlayerId,
			lv = Level} = Player,
	Now = util:unixtime(),
	%%三月活动时间
	{TGStart, TGEnd} = march_event_time(),
	%% 			判断是否是在活动指定的时间段里
	case Now > TGStart andalso Now < TGEnd of
		true ->
			case Type of
				1 -> %% 活动二	消费喜乐多	
					Sum = lib_act_interf:march_count_consume(PlayerId, TGStart, TGEnd),
%% 					io:format("Sum is: ~p\n", [Sum]),
					case Sum > 0 of
						true ->
							Count = Sum div 500,
							case db_agent:get_mid_prize(PlayerId ,Type) of
								[_Id,_Mpid,_Mtype,_Mnum,Got] ->
									if
										Count > Got ->
											Rest = trunc(Sum - Got * 500),
											[Rest, 1];
										true ->
											Rest = trunc(Sum - Got * 500),
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
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,Type,0,0]),
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
				2 -> %% 活动三	阳春好礼
					case db_agent:get_mid_prize(PlayerId ,Type) of
						[_Id,_Mpid,_Mtype,Mnum,Got] ->
							if
								Mnum > Got ->
									[Mnum - Got, 1];
								true ->
									[0, 2]
							end;
						[] ->
							%% 没有记录
							db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,Type,1,0]),
							[1, 1]
					end;
				3 -> %%活动四：坐骑进化，龙腾四海 		
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
							case db_agent:get_mid_prize(PlayerId,Type) of
								[_Id,_Mpid,_Mtype,_Mnum,Got] ->
									if
										Step > Got ->
											[Step,1];
										true ->
											[Step,0]
									end;
								_ ->
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,Type,Step,0]),
									[Step,1]
							end;
						false ->
							[1,0]
					end;
				4 -> %% 活动七：飞跃竞技场	
					case Level < 30 of
						true ->
							[0,0];
						false ->
							PRank = lib_coliseum:get_player_coliseum_rank(PlayerId),
							case db_agent:get_mid_prize(PlayerId,Type) of
								[_Id,_Mpid,_Mtype,_Mnum,Got] ->
									[Got, PRank];
								_ ->
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,Type,0,PRank]),
									[PRank, PRank]
							end
					end;
				_ ->
					[0, 0]
			end;
		false ->
			[0, 0]
	end.


%% 三月活动领取活动
get_march_event(Player, Type) ->
	#player{id = PlayerId} = Player,
	Now = util:unixtime(),
	%%三月活动时间
	{TGStart, TGEnd} = march_event_time(),
	
	Give_more = 
		fun(GoodsList,SuccessFun,SuccessFunArgs, NeedCell) ->
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
				end
		end,
	SuccFun = 
		fun(Id,ValueList) ->
				db_agent:update_mid_prize(ValueList,[{id,Id}])
		end,
	%% 			判断是否是在活动指定的时间段里
	case Now > TGStart andalso Now < TGEnd of
		true ->
			case Type of
				1 ->
					case db_agent:get_mid_prize(PlayerId ,Type) of
						[Id,_Mpid,_Mtype,_MNum,Got] ->
							%%计算累计的消费元宝数
							Sum = lib_act_interf:march_count_consume(PlayerId, TGStart, TGEnd),
%% 							?DEBUG("Sum is: ~p", [Sum]),
							case Sum > 0 of
								true ->
									Count = Sum div 500,
									if
										Count > Got ->
											GGot = Count - Got,
											GoodsId1 = 28024,
											GoodsId2 = 28823,
											Num1 = GGot,
											Num2 = GGot,
											Cell1 = Num1 div 100 +1,
											Cell2 = Num2 div 100 +1,
											GoodsList = [{GoodsId1,Num1,2,0,0}, {GoodsId2,Num2,2,0,0}],
											NeedCell = Cell1 + Cell2,
											Give_more(GoodsList, SuccFun, [Id,[{got,GGot+Got}]], NeedCell);
										true ->
											{fail, 0}
									end;
								false ->
									{fail, 0}
							end;
						_ ->
							{fail,0}
					end;
				
				2 -> %% 活动三	阳春好礼
					case db_agent:get_mid_prize(PlayerId ,Type) of
						[Id,_Mpid,_Mtype,MNum,Got] ->
							if
								MNum > Got ->
									GoodsId = 31014,	%%	节日登录礼包
									GoodsList = [{GoodsId,1,2,0,0}],
									Give_more(GoodsList, SuccFun, [Id,[{got,Got+1}]], 1);
								true ->
									{fail, 0}
							end;
						_ ->
							{fail, 0}
					end;
				
				
				3 -> %%活动四：坐骑进化，龙腾四海 	
					case db_agent:get_mid_prize(Player#player.id,Type) of
						[Id,_Mpid,_Mtype,_Mnum,Got] ->
							AllMount = lib_mount:get_all_mount(Player#player.id),
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
									MountStep = lists:foldl(F_step,0, AllMount),
									if
										MountStep > Got ->
											GotStep = MountStep,
											{GoodsList,NeedCell} = 
												case GotStep of
													1 -> {[{24822,2,2,0,0},{28023,1,2,0,0},{28024,1,2,0,0}], 3};%%1阶	飞灵丹*2，绑定铜钱卡*1，小礼券*1
													2 -> {[{24822,4,2,0,0},{28023,2,2,0,0},{28024,2,2,0,0}], 3};%%2阶	飞灵丹*4，绑定铜钱卡*2，小礼券*2
													3 -> {[{24823,3,2,0,0},{28023,3,2,0,0},{28024,3,2,0,0}], 3};%%3阶	飞灵仙丹*3，绑定铜钱卡*3，小礼券*3
													4 -> {[{24823,5,2,0,0},{28023,4,2,0,0},{28024,3,2,0,0}], 3};%%4阶	飞灵仙丹*5，绑定铜钱卡*4，小礼券*3
													5 -> {[{24823,10,2,0,0},{28023,5,2,0,0},{28024,3,2,0,0}], 3};%%5阶	飞灵仙丹*10，绑定铜钱卡*5，小礼券*3
													6 -> {[{24823,15,2,0,0},{28023,6,2,0,0},{28024,3,2,0,0}], 3};%%6阶	飞灵仙丹*15，绑定铜钱卡*6，小礼券*3
													7 -> {[{24823,20,2,0,0},{28023,7,2,0,0},{28024,3,2,0,0}], 3};%%7阶	飞灵仙丹*20，绑定铜钱卡*7，小礼券*3
													8 -> {[{24823,25,2,0,0},{28023,8,2,0,0},{28024,3,2,0,0}], 3};%%8阶	飞灵仙丹*25，绑定铜钱卡*8，小礼券*3
													9 -> {[{24823,30,2,0,0},{28023,9,2,0,0},{28024,3,2,0,0}], 3};%%9阶	飞灵仙丹*30，绑定铜钱卡*9，小礼券*3
													10 -> {[{24821,10,2,0,0},{28023,20,2,0,0},{28024,10,2,0,0}], 2};%%10阶	封灵神符*10，绑定铜钱卡*20，小礼券*10	
													_ ->{[], 0}
												end,
											Give_more(GoodsList, SuccFun, [Id,[{got,GotStep}]], NeedCell);
										true ->
											{fail,0}
									end;
								false ->
									{fail,0}
							end;
						_ ->
							{fail,0}
					end;
				_ ->
					{fail, 0}
			end;
		false ->
			{fail, 5}
	end.

check_march_event_award() ->
	NowTime = util:unixtime(),
	%%三月活动时间
	{_TGStart, TGEnd} = march_event_time(),
	case NowTime >= TGEnd andalso NowTime < TGEnd+10 of
		true ->
			case get(march_event) of
				1 ->
					skip;
				_ ->
					%%做标识
					put(march_event, 1),
					%%排行榜坐骑奖励
					gen_server:cast(mod_rank:get_mod_rank_pid(),
									{apply_cast, lib_rank, march_mount_award, []}),
					%%竞技场奖励
					lib_act_interf:march_arena_award(),
					ok
			end;
		false ->
			skip
	end.

%% 时装活动
%% 活动时间：2012年4月12日8时 至 2012年4月14日23时59分59秒					
fashion_event_time() ->
%% 	警告，正确的时间，不要随意修改，如需使用，请用下面的测试代码
	case config:get_platform_name()of
		"cmwebgame" ->%%台湾
			{1334188800, 1334419199};	%%	2012年4月12日8时 至 2012年4月14日23时59分59秒
		"memoriki" ->%%香港
			{1334188800, 1334419199};	%%	2012年4月12日8时 至 2012年4月14日23时59分59秒
		"1766game" ->%%杨麒
			{1334188800, 1334419199};	%%	2012年4月12日8时 至 2012年4月14日23时59分59秒
		_ ->%%默认
			{1334188800, 1334419199}	%%	2012年4月12日8时 至 2012年4月14日23时59分59秒
	end.

%% 	%%测试用代码
%% 	{1334149200, 1334838670}.

%%判断是否 是 时装活动时间
is_fashion_event_time(Now) ->
	%%时装活动时间
	{TGStart, TGEnd} = fashion_event_time(),
	Now > TGStart andalso Now < TGEnd.

%%  时装活动		领取活动
get_fashion_event_info(Player, EventType) ->
	#player{id = PlayerId,
			lv = Level} = Player,
	Now = util:unixtime(),
	%%时装活动	时间
	{TGStart, TGEnd} = fashion_event_time(),
	case EventType of
		1 ->%%	活动一	消费喜乐多
			lib_act_interf:check_consume_count_event(Now, TGStart, TGEnd, PlayerId, lib_act_interf, march_count_consume, EventType, 500);
		2 ->%%嫦娥之泪		活动二	兑换绝版时装		活动三	超炫挂饰！震撼法宝！	
			NeedGoods = goods_util:get_type_goods_list(Player#player.id, 31200, 4),
			TotalNum = goods_util:get_goods_totalnum(NeedGoods),
			%% 					?DEBUG("TotalNum:~p", [TotalNum]),
			[TotalNum, 0];
		4 ->%%南瓜馅饼		活动二	兑换绝版时装		活动三	超炫挂饰！震撼法宝！	
			NeedGoods = goods_util:get_type_goods_list(Player#player.id, 31213, 4),
			TotalNum = goods_util:get_goods_totalnum(NeedGoods),
			%% 					?DEBUG("TotalNum:~p", [TotalNum]),
			[TotalNum, 0];
		6 ->%%	活动三	登录好礼
			lib_act_interf:check_login_event(Now, TGStart, TGEnd, PlayerId, Level, EventType, 0);
		7 ->%%	活动四	勇者回归
			case Now > TGStart andalso Now < TGEnd of
				true ->%%是否在时间
					case Level >= 40 of
						true ->%%等级限制
							case db_agent:get_mid_prize(PlayerId ,EventType) of
								[_Id,_Mpid,_Mtype,Mnum,Got] ->
									if
										Mnum > Got ->
											[Mnum - Got, 1];
										Mnum =:= 0 ->%%没得领取的
											[0, 0];
										true ->
											[0, 2]
									end;
								[] ->
									%% 没有记录
									db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,EventType,0,0]),
									[0, 0]
							end;
						false ->
							%% 没有记录
							db_agent:insert_mid_prize([pid,type,num,got],[PlayerId,EventType,0,0]),
							[0, 0]
					end;
				false ->
					[0, 0]
			end;
		8 ->%%	活动五：	全身强化，潜力无限	
			lib_act_interf:check_fullstren_event(Now, TGStart, TGEnd, Player, EventType);
		9 ->%%	活动六：	坐骑进化，龙腾四海 	
			lib_act_interf:check_mount_evolution_event(Now, TGStart, TGEnd, PlayerId, EventType);
		_ ->
			[0, 0]
	end.
			
get_fashion_event(Player, EventType) ->
	#player{id = PlayerId,
			lv = PLv} = Player,
	Now = util:unixtime(),
	%%时装活动	时间
	{TGStart, TGEnd} = fashion_event_time(),
	%%成功时执行方法
	SuccFun = fun(WereList, ValueList) ->
						 db_agent:update_mid_prize(ValueList,WereList)
				 end,
	Del_give_more = 
		fun(DeleteType,DeleteNum,GoodsList,SuccessFun,SuccessFunArgs) ->
				NeedCell = length(GoodsList),
				case length(gen_server:call(Player#player.other#player_other.pid_goods,{'null_cell'})) > NeedCell of
					true ->%%优先扣绑定的
						case gen_server:call(Player#player.other#player_other.pid_goods,{'DELETE_MORE_BIND_PRIOR',DeleteType,DeleteNum}) of
							1 ->
								gen_server:call(Player#player.other#player_other.pid_goods, {'give_more', Player,GoodsList}),
								case is_function(SuccessFun) of
									true ->
										erlang:apply(SuccessFun, SuccessFunArgs);
									false ->
										skip
								end,
								{ok, 6};
							2 ->%%物品不存在
								{fail, 4};
							3 ->%%数量不足
								{fail, 4};
							_ ->
								{fail,0}
						end;
					false ->
						{fail,3}%%空间不足
				end
		end,
	
	DoubleDeleteGive = 
		fun(FBDeleteType1,FBDeleteNum1,FBDeleteType2,FBDeleteNum2,FBGoodsList,FBSuccessFun,FBSuccessFunArgs) ->
				FBNeedCell = length(FBGoodsList),
				case length(gen_server:call(Player#player.other#player_other.pid_goods,{'null_cell'})) > FBNeedCell of
					true ->%%优先扣绑定的
						case gen_server:call(Player#player.other#player_other.pid_goods,{'DELETE_MORE_BIND_PRIOR',FBDeleteType1,FBDeleteNum1}) of
							1 ->
								case gen_server:call(Player#player.other#player_other.pid_goods,{'DELETE_MORE_BIND_PRIOR',FBDeleteType2,FBDeleteNum2}) of
									1 ->
										gen_server:call(Player#player.other#player_other.pid_goods, {'give_more', Player,FBGoodsList}),
										case is_function(FBSuccessFun) of
											true ->
												erlang:apply(FBSuccessFun, FBSuccessFunArgs);
											false ->
												skip
										end,
										{ok, 6};
									_ ->
										{fail,0}
								end;
							_ ->
								{fail,0}
						end;
					false ->
						{fail,3}%%空间不足
				end
		end,
	
	case EventType of
		1 ->%%	活动一	消费喜乐多
			%% 判断是否是在活动指定的时间段里
			case Now > TGStart andalso Now < TGEnd of
				true ->
					case db_agent:get_mid_prize(PlayerId, EventType) of
						[Id,_Mpid,_Mtype,_MNum,Got] ->
							%%计算累计的消费元宝数
							Sum = lib_act_interf:march_count_consume(PlayerId, TGStart, TGEnd),
							%% 							?DEBUG("Sum is: ~p", [Sum]),
							case Sum > 0 of
								true ->
									Count = Sum div 500,
									if
										Count > Got ->
											GGot = Count - Got,
											GoodsId1 = 28024,%%小礼券
											GoodsId2 = 28839,%%时装福袋
											Num1 = GGot,
											Num2 = GGot,
											Cell1 = Num1 div 100 +1,
											Cell2 = Num2 div 100 +1,
											GoodsList = [{GoodsId1,Num1,2,0,0}, {GoodsId2,Num2,0,0,0}],
											NeedCell = Cell1 + Cell2,
											SuccessFunArgs = [[{id,Id}], [{got,Got+GGot}]],
											lib_act_interf:give_and_succeed(Player, GoodsList, SuccFun, SuccessFunArgs, NeedCell);
										true ->
											{fail, 0}
									end;
								false ->
									{fail, 0}
							end;
						_ ->
							{fail,0}
					end;
				false ->%%不在活动时间里
					{fail, 0}
			end;
		2 ->%%	活动二	兑换绝版时装(集齐6个嫦娥之泪可兑换金菲时装)
			FasionGoodsId =
				case {Player#player.career,Player#player.sex} of
					{1,1} -> 10911;		%%玄武-男
					{1,2} -> 10912;		%%玄武-女
					{2,1} -> 10913;		%%白虎-男
					{2,2} -> 10914;		%%白虎-女
					{3,1} -> 10915;		%%青龙-男
					{3,2} -> 10916;		%%青龙-女
					{4,1} -> 10917;		%%朱雀-男
					{4,2} -> 10918;		%%朱雀-女
					{5,1} -> 10919;		%%麒麟-男
					{5,2} -> 10920		%%麒麟-女
				end,
			%%[{物品id，数量，绑定状态，过期时间，交易状态}]
			Expire = util:unixtime() + 864000,%%十天
			GoodsList = [{FasionGoodsId,1,0,Expire,0}],
			Del_give_more(31200, 6, GoodsList, [], []);
		3 ->%%	活动二	兑换绝版时装(集齐6个嫦娥之泪可兑换金菲时装变身券)
			FasionGoodsId = 31203,
			%%[{物品id，数量，绑定状态，过期时间，交易状态}]
			GoodsList = [{FasionGoodsId,1,0,0,0}],
			Del_give_more(31200, 6, GoodsList, [], []);
		4 ->%%	活动二	兑换绝版时装(集齐7个南瓜馅饼可兑换龙凤时装)
			FasionGoodsId =
				case {Player#player.career,Player#player.sex} of
					{1,1} -> 10921;		%%玄武-男
					{1,2} -> 10922;		%%玄武-女
					{2,1} -> 10923;		%%白虎-男
					{2,2} -> 10924;		%%白虎-女
					{3,1} -> 10925;		%%青龙-男
					{3,2} -> 10926;		%%青龙-女
					{4,1} -> 10927;		%%朱雀-男
					{4,2} -> 10928;		%%朱雀-女
					{5,1} -> 10929;		%%麒麟-男
					{5,2} -> 10930		%%麒麟-女
				end,
			%%[{物品id，数量，绑定状态，过期时间，交易状态}]
			Expire = util:unixtime() + 864000,%%十天
			GoodsList = [{FasionGoodsId,1,0,Expire,0}],
			Del_give_more(31213, 7, GoodsList, [], []);
		5 ->%%	活动二	兑换绝版时装(集齐7个南瓜馅饼可兑换龙凤时装变身券)
			FasionGoodsId = 31214,
			%%[{物品id，数量，绑定状态，过期时间，交易状态}]
			GoodsList = [{FasionGoodsId,1,0,0,0}],
			Del_give_more(31213, 7, GoodsList, [], []);
		6 ->%%	活动三	登录好礼
			GoodsId = 31014,	%%	节日登录礼包
			GoodsList = [{GoodsId,1,2,0,0}],
			lib_act_interf:get_login_event(Now, TGStart, TGEnd, Player, PLv, EventType, 0, GoodsList, 1);
		7 ->%%	活动四	勇者回归
			case Now > TGStart andalso Now < TGEnd of
				true ->%%是否在时间
					case PLv >= 40 of
						true ->%%等级限制
							case db_agent:get_mid_prize(PlayerId ,EventType) of
								[Id,_Mpid,_Mtype,MNum,Got] ->
									if
										MNum > Got ->
											GoodsId = 31071,	%%	勇者回归礼包
											GGot = MNum-Got,	%%给的数量
											GoodsList = [{GoodsId,GGot,2,0,0}],
											SuccessFunArgs = [[{id,Id}],[{got,Got+GGot}]],
											lib_act_interf:give_and_succeed(Player, GoodsList, SuccFun, SuccessFunArgs, 1);
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
			end;
		8 ->%%	活动五：	全身强化，潜力无限	
			lib_act_interf:get_fullstren_event(Now, TGStart, TGEnd, Player, EventType);
		9 ->%%	活动六：	坐骑进化，龙腾四海 	
			case db_agent:get_mid_prize(Player#player.id,EventType) of
				[Id,_Mpid,_Mtype,_Mnum,Got] ->
					AllMount = lib_mount:get_all_mount(Player#player.id),
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
							MountStep = lists:foldl(F_step,0, AllMount),
							if
								MountStep > Got ->
									GotStep = MountStep,
									{GoodsList,NeedCell} = 
										case GotStep of
											1 -> {[{24822,2,2,0,0},{28023,1,2,0,0},{28024,1,2,0,0}], 3};%%1阶	飞灵丹*2，绑定铜钱卡*1，小礼券*1
											2 -> {[{24822,4,2,0,0},{28023,2,2,0,0},{28024,2,2,0,0}], 3};%%2阶	飞灵丹*4，绑定铜钱卡*2，小礼券*2
											3 -> {[{24823,3,2,0,0},{28023,3,2,0,0},{28024,3,2,0,0}], 3};%%3阶	飞灵仙丹*3，绑定铜钱卡*3，小礼券*3
											4 -> {[{24823,5,2,0,0},{28023,4,2,0,0},{28024,3,2,0,0}], 3};%%4阶	飞灵仙丹*5，绑定铜钱卡*4，小礼券*3
											5 -> {[{24823,10,2,0,0},{28023,5,2,0,0},{28024,3,2,0,0}], 3};%%5阶	飞灵仙丹*10，绑定铜钱卡*5，小礼券*3
											6 -> {[{24823,15,2,0,0},{28023,6,2,0,0},{28024,3,2,0,0}], 3};%%6阶	飞灵仙丹*15，绑定铜钱卡*6，小礼券*3
											7 -> {[{24823,20,2,0,0},{28023,7,2,0,0},{28024,3,2,0,0}], 3};%%7阶	飞灵仙丹*20，绑定铜钱卡*7，小礼券*3
											8 -> {[{24823,25,2,0,0},{28023,8,2,0,0},{28024,3,2,0,0}], 3};%%8阶	飞灵仙丹*25，绑定铜钱卡*8，小礼券*3
											9 -> {[{24823,30,2,0,0},{28023,9,2,0,0},{28024,3,2,0,0}], 3};%%9阶	飞灵仙丹*30，绑定铜钱卡*9，小礼券*3
											10 -> {[{24821,10,2,0,0},{28023,20,2,0,0},{28024,10,2,0,0}], 2};%%10阶	封灵神符*10，绑定铜钱卡*20，小礼券*10	
											_ ->{[], 0}
										end,
									SuccessFunArgs = [[{id,Id}],[{got,GotStep}]],
									lib_act_interf:give_and_succeed(Player, GoodsList, SuccFun, SuccessFunArgs, NeedCell);
								true ->
									{fail,0}
							end;
						false ->
							{fail,0}
					end;
				_ ->
					{fail,0}
			end;
		10 ->%%	活动三	超炫挂饰！震撼法宝！	法宝时装
			ChangE = goods_util:get_type_goods_list(Player#player.id, 31200, 4),%%嫦娥之泪
			ChangENum = goods_util:get_goods_totalnum(ChangE),
			Pumpkin = goods_util:get_type_goods_list(Player#player.id, 31213, 4),%%南瓜馅饼
			PumpkinNum = goods_util:get_goods_totalnum(Pumpkin),
			case ChangENum < 6 orelse PumpkinNum < 6 of
				true ->
					{fail, 4};
				false ->
					FaBao =
						case {Player#player.career,Player#player.sex} of
							{1,1} -> 10822;		%%玄武-男	天堑斧
							{1,2} -> 10823;		%%玄武-女	昀霜斧  
							{2,1} -> 10826;		%%白虎-男	炎牙匕
							{2,2} -> 10827;		%%白虎-女	闇刃匕
							{3,1} -> 10820;		%%青龙-男	天诛弓
							{3,2} -> 10821;		%%青龙-女	百邪弓
							{4,1} -> 10828;		%%朱雀-男	望舒琴
							{4,2} -> 10829;		%%朱雀-女	清风琴
							{5,1} -> 10824;		%%麒麟-男	龙渊剑
							{5,2} -> 10825		%%麒麟-女	风翎剑
						end,
					%%[{物品id，数量，绑定状态，过期时间，交易状态}]
					Expire = util:unixtime() + 864000,%%十天
					GoodsList = [{FaBao,1,0,Expire,0}],
					DoubleDeleteGive(31200, 6, 31213, 6, GoodsList, [], [])
			end;
		11 ->%%	活动三	超炫挂饰！震撼法宝！	紫金大葫芦
			ChangE = goods_util:get_type_goods_list(Player#player.id, 31200, 4),%%嫦娥之泪
			ChangENum = goods_util:get_goods_totalnum(ChangE),
			Pumpkin = goods_util:get_type_goods_list(Player#player.id, 31213, 4),%%南瓜馅饼
			PumpkinNum = goods_util:get_goods_totalnum(Pumpkin),
			case ChangENum < 6 orelse PumpkinNum < 6 of
				true ->
					{fail, 4};
				false ->
					GusShiOne = 10701,
					%%[{物品id，数量，绑定状态，过期时间，交易状态}]
					Expire = util:unixtime() + 864000,%%十天
					GoodsList = [{GusShiOne,1,0,Expire,0}],
					DoubleDeleteGive(31200, 6, 31213, 6, GoodsList, [], [])
			end;
		12 ->%%	活动三	超炫挂饰！震撼法宝！	蝶恋花
			ChangE = goods_util:get_type_goods_list(Player#player.id, 31200, 4),%%嫦娥之泪
			ChangENum = goods_util:get_goods_totalnum(ChangE),
			Pumpkin = goods_util:get_type_goods_list(Player#player.id, 31213, 4),%%南瓜馅饼
			PumpkinNum = goods_util:get_goods_totalnum(Pumpkin),
			case ChangENum < 6 orelse PumpkinNum < 6 of
				true ->
					{fail, 4};
				false ->
					GusShiTwo = 10702,
					%%[{物品id，数量，绑定状态，过期时间，交易状态}]
					Expire = util:unixtime() + 864000,%%十天
					GoodsList = [{GusShiTwo,1,0,Expire,0}],
					DoubleDeleteGive(31200, 6, 31213, 6, GoodsList, [], [])
			end;
		_ ->
			{fail, 0}
	end.

			
			
%% 五一活动
%% 活动时间：4月27日8时0分0秒 至 5月2日23时59分59秒
all_may_day_time() ->
%% 	警告，正确的时间，不要随意修改，如需使用，请用下面的测试代码
	case config:get_platform_name()of
		"cmwebgame" ->%%台湾
			{1335497400, 1335974399};	%%	4月27日11时30分0秒 至 5月2日23时59分59秒
		"memoriki" ->%%香港
			{1335497400, 1335974399};	%%	4月27日11时30分0秒 至 5月2日23时59分59秒
		"1766game" ->%%杨麒
			{1335497400, 1335974399};	%%	4月27日11时30分0秒 至 5月2日23时59分59秒
		"yuengufs" ->%%香港
			{1335497400, 1335974399};	%%	4月27日11时30分0秒 至 5月2日23时59分59秒
		"mfs" ->%%新马
			{1335497400, 1335974399};	%%	4月27日11时30分0秒 至 5月2日23时59分59秒
		_ ->%%默认
			{1335484800, 1335974399}	%%	4月27日8时0分0秒 至 5月2日23时59分59秒
	end.

%% 	%%测试用代码
%% 	{1335438900, 1335447000}.

%%判断是否 是 五一活动时间
is_all_may_day_time(Now) ->
	%%五一活动时间
	{TGStart, TGEnd} = all_may_day_time(),
	Now > TGStart andalso Now < TGEnd.

%% 活动时间：4月27日8时0分0秒 至 4月30日23时59分59秒
consume_may_day_time() ->
%% 	警告，正确的时间，不要随意修改，如需使用，请用下面的测试代码
	case config:get_platform_name()of
		"cmwebgame" ->%%台湾
			{1335497400, 1335801599};	%%	4月27日11时30分0秒 至 4月30日23时59分59秒
		"memoriki" ->%%香港
			{1335497400, 1335801599};	%%	4月27日11时30分0秒 至 4月30日23时59分59秒
		"1766game" ->%%杨麒
			{1335497400, 1335801599};	%%	4月27日11时30分0秒 至 4月30日23时59分59秒
		"yuengufs" ->%%香港
			{1335497400, 1335801599};	%%	4月27日11时30分0秒 至 4月30日23时59分59秒
		"mfs" ->%%新马
			{1335497400, 1335801599};	%%	4月27日11时30分0秒 至 4月30日23时59分59秒
		_ ->%%默认
			{1335484800, 1335801599}	%%	4月27日8时0分0秒 至 4月30日23时59分59秒
	end.
%% 	%%测试用代码
%% 	{1335438900, 1335447000}.

is_consume_may_day_time(Now) ->
	%%五一活动时间
	{TGStart, TGEnd} = consume_may_day_time(),
	Now > TGStart andalso Now < TGEnd.

%% 活动时间：4月30日0时0分0秒 至 5月2日23时59分59秒
late_may_day_time() ->
%% 	警告，正确的时间，不要随意修改，如需使用，请用下面的测试代码
	case config:get_platform_name()of
		"cmwebgame" ->%%台湾
			{1335715200, 1335974399};	%%	4月30日0时0分0秒 至 5月2日23时59分59秒
		"memoriki" ->%%香港
			{1335715200, 1335974399};	%%	4月30日0时0分0秒 至 5月2日23时59分59秒
		"1766game" ->%%杨麒
			{1335715200, 1335974399};	%%	4月30日0时0分0秒 至 5月2日23时59分59秒
		"yuengufs" ->%%香港
			{1335715200, 1335974399};	%%	4月30日0时0分0秒 至 5月2日23时59分59秒
		"mfs" ->%%新马
			{1335715200, 1335974399};	%%	4月30日0时0分0秒 至 5月2日23时59分59秒
		_ ->%%默认
			{1335715200, 1335974399}	%%	4月30日0时0分0秒 至5月2日23时59分59秒
	end.
%% 	%%测试用代码
%% 	{1335438900, 1335447000}.

is_late_may_day_time(Now) ->
	%%五一活动时间
	{TGStart, TGEnd} = late_may_day_time(),
	Now > TGStart andalso Now < TGEnd.
			
%%  五一活动		领取活动
get_may_day_info(Player, EventType) ->
	#player{id = PlayerId,
			lv = Level} = Player,
	Now = util:unixtime(),
	%%五一活动	时间
	{AllStart, AllEnd} = all_may_day_time(),	
	{CSStart, CSEnd} = consume_may_day_time(),	
	case EventType of
		1 ->%%	活动一	消费喜乐多
			lib_act_interf:check_consume_count_event(Now, CSStart, CSEnd, PlayerId, lib_act_interf, mayday_count_consume, EventType, 500);
		2 ->%%雨花石		活动二	超炫挂饰！震撼法宝	
			NeedGoods = goods_util:get_type_goods_list(Player#player.id, 31236, 4),
			TotalNum = goods_util:get_goods_totalnum(NeedGoods),
			[TotalNum, 0];
		5 ->%%嫦娥之泪		活动三	兑换绝版时装	
			NeedGoods = goods_util:get_type_goods_list(Player#player.id, 31200, 4),
			TotalNum = goods_util:get_goods_totalnum(NeedGoods),
			[TotalNum, 0];
		7 ->%%南瓜馅饼		活动三	兑换绝版时装	
			NeedGoods = goods_util:get_type_goods_list(Player#player.id, 31213, 4),
			TotalNum = goods_util:get_goods_totalnum(NeedGoods),
			[TotalNum, 0];
		9 ->%%	活动四	登录好礼
			lib_act_interf:check_login_event(Now, AllStart, AllEnd, PlayerId, Level, EventType, 0);
		10 ->%%	活动五：神器品质突破
			lib_act_interf:check_artifact_color_step(Now, CSStart, CSEnd, PlayerId, EventType, color);
		11 ->%%	活动六：飞跃品阶，神器进化			
			lib_act_interf:check_artifact_color_step(Now, CSStart, CSEnd, PlayerId, EventType, step);
		13 ->%%	活动十二：兑换惊喜	
			NeedGoods = goods_util:get_type_goods_list(Player#player.id, 31235, 4),
			TotalNum = goods_util:get_goods_totalnum(NeedGoods),
			[TotalNum, 0];
		_ ->
			[0, 0]
	end.


get_may_day(Player, EventType) ->
	#player{id = PlayerId,
			lv = PLv} = Player,
	Now = util:unixtime(),
	%%五一活动	时间
	{AllStart, AllEnd} = all_may_day_time(),	
	{CSStart, CSEnd} = consume_may_day_time(),	
	%%成功时执行方法
	SuccFun = fun(WereList, ValueList) ->
						 db_agent:update_mid_prize(ValueList,WereList)
				 end,
	Del_give_more = 
		fun(DeleteType,DeleteNum,GoodsList,SuccessFun,SuccessFunArgs) ->
				NeedCell = length(GoodsList),
				case length(gen_server:call(Player#player.other#player_other.pid_goods,{'null_cell'})) > NeedCell of
					true ->%%优先扣绑定的
						case gen_server:call(Player#player.other#player_other.pid_goods,{'DELETE_MORE_BIND_PRIOR',DeleteType,DeleteNum}) of
							1 ->
								gen_server:call(Player#player.other#player_other.pid_goods, {'give_more', Player,GoodsList}),
								case is_function(SuccessFun) of
									true ->
										erlang:apply(SuccessFun, SuccessFunArgs);
									false ->
										skip
								end,
								{ok, 6};
							2 ->%%物品不存在
								{fail, 4};
							3 ->%%数量不足
								{fail, 4};
							_ ->
								{fail,0}
						end;
					false ->
						{fail,3}%%空间不足
				end
		end,
	
	case EventType of
		1 ->%%	活动一	消费喜乐多
			%% 判断是否是在活动指定的时间段里
			case Now > CSStart andalso Now < CSEnd of
				true ->
					case db_agent:get_mid_prize(PlayerId, EventType) of
						[Id,_Mpid,_Mtype,_MNum,Got] ->
							%%计算累计的消费元宝数
							Sum = lib_act_interf:mayday_count_consume(PlayerId, CSStart, CSEnd),
							%% 							?DEBUG("Sum is: ~p", [Sum]),
							case Sum > 0 of
								true ->
									Count = Sum div 500,
									if
										Count > Got ->
											GGot = Count - Got,
											GoodsId1 = 28024,%%小礼券
											GoodsId2 = 28841,%%时装礼包
											Num1 = GGot,
											Num2 = GGot,
											Cell1 = Num1 div 100 +1,
											Cell2 = Num2 div 100 +1,
											GoodsList = [{GoodsId1,Num1,2,0,0}, {GoodsId2,Num2,0,0,0}],
											NeedCell = Cell1 + Cell2,
											SuccessFunArgs = [[{id,Id}], [{got,Got+GGot}]],
											lib_act_interf:give_and_succeed(Player, GoodsList, SuccFun, SuccessFunArgs, NeedCell);
										true ->
											{fail, 0}
									end;
								false ->
									{fail, 0}
							end;
						_ ->
							{fail,0}
					end;
				false ->%%不在活动时间里
					{fail, 0}
			end;
		2 ->%%	活动二	超炫挂饰！震撼法宝！	法宝时装		集齐6个雨花石可兑换全新法宝时装1件
			%% 判断是否是在活动指定的时间段里
			case Now > AllStart andalso Now < AllEnd of
				true ->
					FaBao =
						case {Player#player.career,Player#player.sex} of
							{1,1} -> 10832;		%%玄武-男	无妄斧
							{1,2} -> 10833;		%%玄武-女	帝恨斧  
							{2,1} -> 10836;		%%白虎-男	破天匕
							{2,2} -> 10837;		%%白虎-女	星闪匕
							{3,1} -> 10830;		%%青龙-男	惊邪弓
							{3,2} -> 10831;		%%青龙-女	煞仙弓
							{4,1} -> 10838;		%%朱雀-男	曦和琴
							{4,2} -> 10839;		%%朱雀-女	神舞琴
							{5,1} -> 10834;		%%麒麟-男	赤霄剑
							{5,2} -> 10835		%%麒麟-女	天晶剑
						end,
					%%[{物品id，数量，绑定状态，过期时间，交易状态}]
					Expire = util:unixtime() + 864000,%%十天
					GoodsList = [{FaBao,1,0,Expire,0}],
					Del_give_more(31236, 6, GoodsList, [], []);
				false ->
					{fail, 0}
			end;
		3 ->%%	活动二	超炫挂饰！震撼法宝！	风车		集齐6个雨花石可兑换全新挂饰1件。			
			%% 判断是否是在活动指定的时间段里
			case Now > AllStart andalso Now < AllEnd of
				true ->
					GusShiOne = 10700,
					%%[{物品id，数量，绑定状态，过期时间，交易状态}]
					Expire = util:unixtime() + 864000,%%十天
					GoodsList = [{GusShiOne,1,0,Expire,0}],
					Del_give_more(31236, 6, GoodsList, [], []);
				false ->
					{fail, 0}
			end;
		4 ->%%	活动二	超炫挂饰！震撼法宝！	灵儿的布娃娃		集齐6个雨花石可兑换全新挂饰1件。
			%% 判断是否是在活动指定的时间段里
			case Now > AllStart andalso Now < AllEnd of
				true ->
					
					GusShiTwo = 10703,
					%%[{物品id，数量，绑定状态，过期时间，交易状态}]
					Expire = util:unixtime() + 864000,%%十天
					GoodsList = [{GusShiTwo,1,0,Expire,0}],
					Del_give_more(31236, 6, GoodsList, [], []);
				false ->
					{fail, 0}
			end;
		5 ->%%	活动三	兑换绝版时装(集齐6个嫦娥之泪可兑换金菲时装)
			%% 判断是否是在活动指定的时间段里
			case Now > AllStart andalso Now < AllEnd of
				true ->
					FasionGoodsId =
						case {Player#player.career,Player#player.sex} of
							{1,1} -> 10911;		%%玄武-男
							{1,2} -> 10912;		%%玄武-女
							{2,1} -> 10913;		%%白虎-男
							{2,2} -> 10914;		%%白虎-女
							{3,1} -> 10915;		%%青龙-男
							{3,2} -> 10916;		%%青龙-女
							{4,1} -> 10917;		%%朱雀-男
							{4,2} -> 10918;		%%朱雀-女
							{5,1} -> 10919;		%%麒麟-男
							{5,2} -> 10920		%%麒麟-女
						end,
					%%[{物品id，数量，绑定状态，过期时间，交易状态}]
					Expire = util:unixtime() + 864000,%%十天
					GoodsList = [{FasionGoodsId,1,0,Expire,0}],
					Del_give_more(31200, 6, GoodsList, [], []);
				false ->
					{fail, 0}
			end;
		6 ->%%	活动三	兑换绝版时装(集齐6个嫦娥之泪可兑换金菲时装变身券)
			%% 判断是否是在活动指定的时间段里
			case Now > AllStart andalso Now < AllEnd of
				true ->
					FasionGoodsId = 31203,
					%%[{物品id，数量，绑定状态，过期时间，交易状态}]
					GoodsList = [{FasionGoodsId,1,0,0,0}],
					Del_give_more(31200, 6, GoodsList, [], []);
				false ->
					{fail, 0}
			end;
		7 ->%%	活动三	兑换绝版时装(集齐7个南瓜馅饼可兑换龙凤时装)
			%% 判断是否是在活动指定的时间段里
			case Now > AllStart andalso Now < AllEnd of
				true ->
					FasionGoodsId =
						case {Player#player.career,Player#player.sex} of
							{1,1} -> 10921;		%%玄武-男
							{1,2} -> 10922;		%%玄武-女
							{2,1} -> 10923;		%%白虎-男
							{2,2} -> 10924;		%%白虎-女
							{3,1} -> 10925;		%%青龙-男
							{3,2} -> 10926;		%%青龙-女
							{4,1} -> 10927;		%%朱雀-男
							{4,2} -> 10928;		%%朱雀-女
							{5,1} -> 10929;		%%麒麟-男
							{5,2} -> 10930		%%麒麟-女
						end,
					%%[{物品id，数量，绑定状态，过期时间，交易状态}]
					Expire = util:unixtime() + 864000,%%十天
					GoodsList = [{FasionGoodsId,1,0,Expire,0}],
					Del_give_more(31213, 7, GoodsList, [], []);
				false ->
					{fail, 0}
			end;
		8 ->%%	活动三	兑换绝版时装(集齐7个南瓜馅饼可兑换龙凤时装变身券)
			%% 判断是否是在活动指定的时间段里
			case Now > AllStart andalso Now < AllEnd of
				true ->
					FasionGoodsId = 31214,
					%%[{物品id，数量，绑定状态，过期时间，交易状态}]
					GoodsList = [{FasionGoodsId,1,0,0,0}],
					Del_give_more(31213, 7, GoodsList, [], []);	
				false ->
					{fail, 0}
			end;
		9 ->%%	活动四	登录好礼
			NowSec = util:get_today_current_second(),
			Expire = util:unixtime() + ?ONE_DAY_SECONDS - NowSec,%%点名卡一天之内要删除
			GoodsList = [{31014,1,2,0,0}, {28055,1,2,Expire,0}],%%登录礼包*1；点名卡*1
			lib_act_interf:get_login_event(Now, AllStart, AllEnd, Player, PLv, EventType, 0, GoodsList, 2);
		10 ->%%	活动五：神器品质突破
			lib_act_interf:get_artifact_color_step(Player, Now, CSStart, CSEnd, EventType, color);
		11 ->%%	活动六：飞跃品阶，神器进化			
			lib_act_interf:get_artifact_color_step(Player, Now, CSStart, CSEnd, EventType, step);
		13 ->%%	活动十二：兑换惊喜	(时装礼包)
			%% 判断是否是在活动指定的时间段里
			case Now > AllStart andalso Now < AllEnd of
				true ->
					FasionGoodsId = 28841,
					%%[{物品id，数量，绑定状态，过期时间，交易状态}]
					GoodsList = [{FasionGoodsId,1,0,0,0}],
					Del_give_more(31235, 12, GoodsList, [], []);
				false ->
					{fail, 0}
			end;
		14 ->%%	活动十二：兑换惊喜	(神兽蛋)
			%% 判断是否是在活动指定的时间段里
			case Now > AllStart andalso Now < AllEnd of
				true ->
					FasionGoodsId = 24800,
					%%[{物品id，数量，绑定状态，过期时间，交易状态}]
					GoodsList = [{FasionGoodsId,1,0,0,0}],
					Del_give_more(31235, 6, GoodsList, [], []);
				false ->
					{fail, 0}
			end;
		_ ->
			{fail, 0}
	end.