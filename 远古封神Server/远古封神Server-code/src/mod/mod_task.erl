%%%------------------------------------
%%% @Module  : mod_task
%%% @Author  : ygzj
%%% @Created : 2010.12.06
%%% @Description: 任务处理模块
%%%------------------------------------
-module(mod_task).
-behaviour(gen_server).
-export(
    [
        start_link/1
        ,stop/0
	,next_task_cue/3
    ]
).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-include("common.hrl").
-include("record.hrl").


-record(state, {player_id = 0,nowtime=0}).
-define(TIMER_1, 600000).

start_link([PlayerId])->
    gen_server:start_link(?MODULE, [PlayerId], []).

%% 关闭服务器时回调
stop() -> ok.

init([PlayerId])->
	misc:write_monitor_pid(self(),?MODULE, {}),
	State = #state{player_id=PlayerId,nowtime = util:unixtime()},
	erlang:send_after(get_refresh_time(), self(), refresh),
	{ok,State}.

%%接受任务
handle_call({'trigger',PlayerStatus,TaskId}, _From, State) ->
	{Result,Info} =  lib_task:trigger(TaskId, 0, PlayerStatus,0),
	{reply,{Result,Info}, State};

%%完成任务
handle_call({'finish',PlayerStatus,TaskId,SelectItemList}, _From, State) ->
	{Result,Info} = lib_task:finish(TaskId, SelectItemList, PlayerStatus),
	{reply,{Result,Info}, State};


%%放弃任务
handle_call({'abnegate',PlayerStatus,TaskId}, _From, State) ->
	{BinData1,NewPS} = case lib_task:abnegate(TaskId, PlayerStatus) of
        {true,PS} -> 
%%             lib_scene:refresh_npc_ico(PlayerStatus),
            {ok, BinData} = pt_30:write(30006, [1,0]),
            {BinData,PS};
        {false,PS} -> 
            {ok, BinData} = pt_30:write(30005, [0]),
            {BinData,PS}
    end,
	{reply,{BinData1,NewPS}, State};

%%触发并完成任务
handle_call({'trigger_and_finish',PlayerStatus,TaskId,SelectItemList}, _From, State) ->
	{Result,Info} = lib_task:trigger_and_finish(TaskId, SelectItemList, PlayerStatus),
	{reply,{Result,Info}, State};

%%委托任务
handle_call({'accept_consign_task',PlayerStatus,ConsignList},_From,State)->
	{Error,NewPlayerStatus,Result} = lib_task:accept_consign_task(PlayerStatus,ConsignList),
	{reply,{Error,NewPlayerStatus,Result},State};

%%发布委托任务
handle_call({'publish_consign_task',PlayerStatus,TaskInfo},_From,State)->
	{Result,Status} = lib_task:publish_consign_task(PlayerStatus,TaskInfo),
	{reply,{Result,Status},State};

%%接受委托任务
handle_call({'accept_task_consign',PlayerStatus,Id,TaskId},_From,State)->
	{Result,Status} = lib_task:accept_task_consign(PlayerStatus,[Id,TaskId]),
	{reply,{Result,Status},State};

%%选择阵营
handle_call({'select_realm',PlayerStatus,Type,Realm}, _From, State) ->
	{_, PS, Data} = lib_task:select_nation(PlayerStatus,Type,Realm),
	{reply,{PS, Data}, State};


%%查询物品是否掉落
handle_call({'check_can_gain_item',PlayerStatus,GoodsId},_From,State)->
	Result = lib_task:check_can_gain_item(PlayerStatus,GoodsId),
	{reply,Result,State};

%%委托任务列表
handle_call({'consign_task',PlayerStatus},_From,State)->
	ConSign_Bag = lib_task:get_consign_task(PlayerStatus#player.id),
    ConSignList = lists:map(
        fun(RT) ->		
            			TD = lib_task:get_data(RT#ets_task_consign.task_id),
%% 						Times = RT#ets_task_consign.times,
%% 						{ok,Gold} = lib_task:calc_consign_gold([{RT#ets_task_consign.task_id,Times}],0),
			            {TD#task.id, TD#task.name,RT#ets_task_consign.times,
						 RT#ets_task_consign.exp,RT#ets_task_consign.spt,RT#ets_task_consign.cul,
						RT#ets_task_consign.timestamp,RT#ets_task_consign.gold,1}
        end,
        ConSign_Bag
    ),
	{reply,{true,ConSignList},State};

%%获取劫镖次数
handle_call({'bandits',Playerid},_From,State)->
	Times = lib_carry:get_bandits_times(Playerid),
	{reply,{ok,Times},State};

%%获取委托次数
%% handle_call({'consign_times',PlayerId},_From,State)->
%% 	TimesList = lib_consign:get_consign_times_list(PlayerId),
%% 	{reply,{ok,TimesList},State};

%%查询劫商次数
handle_call({'business_robbed_times',Playerid},_From,State)->
	Times = lib_business:get_robbed_count(Playerid),
	{reply,{ok,Times},State};

%%查询任务是否完成
handle_call({'is_finish',PlayerStatus,TaskId},_From,State)->
	Result = lib_task:is_finish(TaskId, PlayerStatus),
	{reply,Result,State};

%%查询任务是否完成或者可提交
handle_call({'is_can_finish',PlayerStatus,TaskId},_From,State)->
	Result = lib_task:check_task_is_finish(PlayerStatus,TaskId),
	{reply,Result,State};

%%查询玩家身上是否有某任务
handle_call({'get_one_trigger',PlayerId,TaskId},_From,State)->
	Res = case lib_task:get_one_trigger(TaskId,PlayerId) of
			  false->false;
			  _->true
		  end,
	{reply,Res,State};

%%查询是否可接某任务
handle_call({'is_can_trigger',[Status,TaskId]},_From,State)->
	Res = lib_task:is_can_trigger(Status,TaskId),	
	{reply,Res,State};


%%查询副本令任务状态
handle_call({'check_dungeon_card_task_state',[PlayerStatus,GoodsId]},_From,State)->
	Res = lib_task:check_dungeon_card_task_state(PlayerStatus,GoodsId),
	{reply,Res,State};

%%查询任务物品数量
handle_call({'task_goods_num',[PlayerId,GoodsId]},_From,State)->
	Res = goods_util:get_goods_num(PlayerId, GoodsId,6) >= 1,
	{reply,Res,State};

handle_call(_Null, _From, State) ->
	{reply,[], State}.

%%完成副本令任务
handle_cast({'finish_dungeon_card_task',[PlayerStatus,TaskId]},State)->
	lib_task:finish_dungeon_card_task(PlayerStatus,TaskId),
	{noreply,State};

%%获取任务列表
handle_cast({'task_list',PlayerStatus}, State) ->
	%%任务累积加成系数
	{_,_,Award,_Day} = lib_task:get_recoup_coefficient(PlayerStatus),
	ActiveIds = lib_task:get_active(PlayerStatus),
    ActiveList = lists:map(
        fun(Tid) ->
			case lib_task:get_data(Tid) of
				[]->skip;
				TD->
					case lib_task:is_hero_task(TD) ==true orelse lib_task:is_appoint_task(TD)==true of
						true->skip;
						false->
            				TipList = lib_task:get_tip(active, Tid, PlayerStatus),
							[Exp,Spt,Times] = 
								case lib_task:is_cycle_task(TD) of
									  true->
										  {CycExp,CycSpt} = lib_task:cycle_task_award(PlayerStatus,TD,tip),
										  [CycExp,CycSpt,lib_task:get_cycle_task_times(TD#task.id,PlayerStatus,tip)];
									  false->
										  case lib_task:is_normal_daily_task(TD)==true orelse lib_task:is_guild_task(TD)==true of
											  true->
												  [round(TD#task.exp*(Award+1)),TD#task.spt,0];
											  false-> 
												  case lib_task:is_business_task(TD)of
													  false->
														  case lib_task:is_love_task(TD) of
															  false->
																  case lib_task:is_random_cycle(TD) of
																	  true->
%% 																		  {ExpRandomCyc,SptRandomCyc} =lib_task:get_random_cycle_award(PlayerStatus,Tid),
																		  TodayTimes = lib_task:get_today_count(Tid, PlayerStatus)+1,
%% 																		  io:format("TodayTimes ~p~n",[TodayTimes]),
																		  [TD#task.exp,TD#task.spt,TodayTimes];
																	  false->
																		  case lib_task:is_carry_task(TD)of
																			  true->
																				  {ExpCarry,_} = lib_carry:base_carry_award(PlayerStatus#player.id,TD),
																				  [ExpCarry,TD#task.spt,0];
																			  false->
																				  [TD#task.exp,TD#task.spt,0]%%封神贴任务不出现在玩家可接任务列表中，此处可以不处理奖励
																		  end
																	  end;
															  true->
																  {ExpLove,SptLove}=lib_love:base_task_award(PlayerStatus#player.lv),
																  [ExpLove,SptLove,0]
														  end;
													  true->
														  {ExpBusiness,BusinessSpt}=lib_business:get_business_award(PlayerStatus#player.id,PlayerStatus#player.lv),
														  [ExpBusiness,BusinessSpt,0]
												  end
										  end
								
				  				end,
							[Coin,GuildCoin] = case lib_task:is_guild_carry_task(TD) of
												   false->
													   case lib_task:is_carry_task(TD)of
														   true->
															   {_ExpCarry,CoinCarry} = lib_carry:base_carry_award(PlayerStatus#player.id,TD),
															   [CoinCarry,TD#task.guild_coin];
														   false->[TD#task.coin,TD#task.guild_coin]
													   end;
												   true->
													   case PlayerStatus#player.guild_id > 0 of
												   		false->[lib_task:guild_carry_coin_award(player,0),lib_task:guild_carry_coin_award(guild,0)];
												   		true->
											  				 case mod_guild:get_guild_carry_info(PlayerStatus#player.guild_id) of
																	[0,{}]->[lib_task:guild_carry_coin_award(player,0),lib_task:guild_carry_coin_award(guild,0)];
														  		 [_,{Level,_Coin,_CarryTime,_BanditsTime,_ChiefId,_DeputyId1,_DeputyId2}]->
															  		 [lib_task:guild_carry_coin_award(player,Level),lib_task:guild_carry_coin_award(guild,Level)]
													  		 end
											   		end
							   				end,
 		           {TD#task.id, TD#task.level, TD#task.type,TD#task.child, TD#task.name, 
					 TD#task.desc,TD#task.end_npc, TipList,0, Coin, Exp, Spt,
					  TD#task.binding_coin, TD#task.attainment,TD#task.honor, TD#task.realm_honor,TD#task.guild_exp,GuildCoin, 
					 TD#task.contrib, TD#task.award_select_item_num, 
					 lib_task:get_award_item(TD, PlayerStatus), TD#task.award_select_item,Times}
        		end
			end
		end, 
        ActiveIds
    ),
    %% 已接任务
    TriggerBag = lib_task:get_trigger(PlayerStatus),
    TriggerList = lists:map(
        fun(RT) ->
				case is_record(RT,role_task) of
					true->
						case RT#role_task.state =/= 2 of
							true->
								case lib_task:get_data(RT#role_task.task_id) of
									[]->skip;
									TD->
        		    					TipList = lib_task:get_tip(trigger, RT#role_task.task_id, PlayerStatus),
										[Exp,Spt,Times1] = 
											case lib_task:is_cycle_task(TD) of
							  					true-> {CycExp,CycSpt} = lib_task:cycle_task_award(PlayerStatus,TD,tip),
										  				[CycExp,CycSpt,lib_task:get_cycle_task_times(TD#task.id,PlayerStatus,tip)];
							  					false->
													case lib_task:is_normal_daily_task(TD)==true orelse lib_task:is_guild_task(TD)==true of
														true->
															[round(TD#task.exp*(Award+1)),TD#task.spt,0];
														false-> 
															case lib_task:is_business_task(TD)of
												  				false->
																	case lib_task:is_love_task(TD) of
																		false->
																			case lib_task:is_random_cycle(TD) of
																	  			true->
																					{ExpRandomCyc,SptRandomCyc} =lib_cycle_flush:get_award_mult(PlayerStatus#player.id,TD,null),
																		  			[ExpRandomCyc,SptRandomCyc,lib_task:get_today_count(TD#task.id, PlayerStatus)+1];
																	  			false->
																					case lib_task:is_carry_task(TD)of
																						true->
																							{ExpCarry,_} = lib_carry:base_carry_award(PlayerStatus#player.id,TD),
																				  			[ExpCarry,TD#task.spt,0];
																						false->
																 	 						[TD#task.exp,TD#task.spt,0]%%封神贴任务不出现在玩家可接任务列表中，此处可以不处理奖励
																					end
																	  		end;
																		true->
																			{ExpLove,SptLove}=lib_love:base_task_award(PlayerStatus#player.lv),
																			[ExpLove,SptLove,0]
																	end;
																true->
																	{ExpBusiness,BusinessSpt}=lib_business:get_business_award(PlayerStatus#player.id,PlayerStatus#player.lv),
													  				[ExpBusiness,BusinessSpt,0]
								  							end
													end
									  		end,
									case RT#role_task.type of
										1->
											case mod_consign:get_consign_task_by_accept(PlayerStatus#player.id,RT#role_task.task_id) of
												{ok,[]}->{TD#task.id, TD#task.level, 6, TD#task.child,
								 						TD#task.name, TD#task.desc,TD#task.end_npc, TipList,0, 0, 0,
								 						0, 0, 0, 
								 						0, 0, 0, 0,0,
								 						TD#task.award_select_item_num, 
								 						[], 
			 											TD#task.award_select_item,Times1};
												{ok,ConsignTask}->
													ConsignAward = [{ConsignTask#ets_consign_task.gid_1, ConsignTask#ets_consign_task.n_1},
																{ ConsignTask#ets_consign_task.gid_2, ConsignTask#ets_consign_task.n_2}],
													Award_item = lib_task:get_award_consign(ConsignAward),
													case ConsignTask#ets_consign_task.mt of
														1->
															{TD#task.id, TD#task.level, 6, TD#task.child,
									 						TD#task.name, TD#task.desc,TD#task.end_npc, TipList,0, ConsignTask#ets_consign_task.n_3, 0,
										 						0, 0, 0, 
									 						0, 0, 0, 0,0,
									 						TD#task.award_select_item_num, 
									 						Award_item, 
			 												TD#task.award_select_item,Times1};
														_->
															{TD#task.id, TD#task.level, 6, TD#task.child,
								 							TD#task.name, TD#task.desc,TD#task.end_npc, TipList,ConsignTask#ets_consign_task.n_3, 0, 0,
								 							0, 0, 0, 
								 							0, 0, 0, 0,0,
								 							TD#task.award_select_item_num, 
								 							[], 
				 											TD#task.award_select_item,Times1}
													end
										end;
									_->
										[Coin,GuildCoin] = case lib_task:is_guild_carry_task(TD) of
															   false->
																   case lib_task:is_carry_task(TD)of
																	   true->
																		   {_ExpCarry,CoinCarry} = lib_carry:base_carry_award(PlayerStatus#player.id,TD),
																		   [CoinCarry,TD#task.guild_coin];
																	   false->[TD#task.coin,TD#task.guild_coin]
																   end;
															   true->
																   case PlayerStatus#player.guild_id > 0 of
																	   false->[lib_task:guild_carry_coin_award(player,0),lib_task:guild_carry_coin_award(guild,0)];
																	   true->
																		   case mod_guild:get_guild_carry_info(PlayerStatus#player.guild_id) of
																			   [0,{}]->[lib_task:guild_carry_coin_award(player,0),lib_task:guild_carry_coin_award(guild,0)];
																			   [_,{Level,_Coin,_CarryTime,_BanditsTime,_ChiefId,_DeputyId1,_DeputyId2}]->
																				   [lib_task:guild_carry_coin_award(player,Level),lib_task:guild_carry_coin_award(guild,Level)]
																		   end
									   								end
							   								end,
										{TD#task.id, TD#task.level, TD#task.type, TD#task.child,
								 		TD#task.name, TD#task.desc,TD#task.end_npc, TipList, 0,Coin, 
								 		Exp, Spt, TD#task.binding_coin, 
								 		TD#task.attainment,TD#task.honor, TD#task.realm_honor,TD#task.guild_exp,GuildCoin,  TD#task.contrib, 
								 		TD#task.award_select_item_num, 
								 		lib_task:get_award_item(TD, PlayerStatus), 
			 							TD#task.award_select_item,Times1}
								end
								end;
							false->skip
						end;
					false->
						skip
				end
						
        end,
        TriggerBag
    ),
	%%下一级主线任务
	TriggerBag_id =[Rt#role_task.task_id||Rt<-TriggerBag],
	NextBag = lib_task:next_lev_list(PlayerStatus,ActiveIds++TriggerBag_id),
	NextList = lists:map(
		fun(Tid)->
			case lib_task:get_data(Tid) of
				[]->skip;
				TD->
			TipList = lib_task:get_tip(next,Tid,PlayerStatus),
			[Exp,Spt,Times2] = [TD#task.exp,TD#task.spt,0],
			{TD#task.id, TD#task.level, TD#task.type,TD#task.child,
			  TD#task.name, TD#task.desc,TD#task.end_npc, TipList, 0,TD#task.coin,
			  Exp, Spt, TD#task.binding_coin,
			  TD#task.attainment,TD#task.honor, TD#task.realm_honor,TD#task.guild_exp, TD#task.guild_coin, TD#task.contrib,
			  TD#task.award_select_item_num, 
			 lib_task:get_award_item(TD, PlayerStatus), 
			 TD#task.award_select_item,Times2}
			end
		 end,
		 NextBag
	),
	{ok, BinData} = pt_30:write(30000, [ActiveList++NextList, TriggerList]),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	Process_id = self(),
	spawn(erlang, garbage_collect, [Process_id]),
	{noreply,State};

%%已接任务列表
handle_cast({'trigger_task',PlayerStatus},State)->
	%%任务累积加成系数
	{_,_,Award,_Day} = lib_task:get_recoup_coefficient(PlayerStatus),
	%% 已接任务
    TriggerBag = lib_task:get_trigger(PlayerStatus),
    TriggerList = lists:map(
        fun(RT) ->		
            case is_record(RT,role_task) of
					true->
						%%发布的雇佣任务不显示
						case RT#role_task.state =/= 2 of
							true->
								case lib_task:get_data(RT#role_task.task_id) of
									[]->skip;
									TD->
        		    			TipList = lib_task:get_tip(trigger, RT#role_task.task_id, PlayerStatus),
								[Exp,Spt,Times] = case lists:member(RT#role_task.task_id,[70100,70103,70106]) of
					  								true-> {CycExp,CycSpt} = lib_task:cycle_task_award(PlayerStatus,TD,tip),
										  					[CycExp,CycSpt,lib_task:get_cycle_task_times(TD#task.id,PlayerStatus,tip)];
					  								false->
														case lib_task:is_normal_daily_task(TD)==true orelse lib_task:is_guild_task(TD)==true of
															true->
																[round(TD#task.exp*(Award+1)),TD#task.spt,0];
															false-> 
																case lib_task:is_business_task(TD)of
																	false->
																		case lib_task:is_love_task(TD) of
																			false->
																				case lib_task:is_random_cycle(TD) of
																	  				true->
																						{ExpRandomCyc,SptRandomCyc} =lib_cycle_flush:get_award_mult(PlayerStatus#player.id,TD,null),
																		  				[ExpRandomCyc,SptRandomCyc,lib_task:get_today_count(TD#task.id, PlayerStatus)+1];
																	  				false->
																						case lib_task:is_carry_task(TD)of
																							true->
																								{ExpCarry,_} = lib_carry:base_carry_award(PlayerStatus#player.id,TD),
																				  				[ExpCarry,TD#task.spt,0];
																			  				false->
																								[TD#task.exp,TD#task.spt,0]
																						end
																	  			end;
																			true->
																				{ExpLove,SptLove}=lib_love:base_task_award(PlayerStatus#player.lv),
														  						[ExpLove,SptLove,0]
												  						end;
																	true->
																		{ExpBusiness,BusinessSpt}=lib_business:get_business_award(PlayerStatus#player.id,PlayerStatus#player.lv),
										  								[ExpBusiness,BusinessSpt,0]
								  								end
														end
						  						end,
								%%接受的雇佣任务处理
								case RT#role_task.type of
									1->
										case mod_consign:get_consign_task_by_accept(PlayerStatus#player.id,RT#role_task.task_id) of
											{ok,[]}->{TD#task.id, TD#task.level, 6, TD#task.child,
								 						TD#task.name, TD#task.desc,TD#task.end_npc, TipList,0, 0, 0,
								 						0, 0, 0, 
								 						0, 0, 0, 0,0,
								 						TD#task.award_select_item_num, 
								 						lib_task:get_award_item(TD, PlayerStatus), 
			 											TD#task.award_select_item,Times};
											{ok,ConsignTask}->
												ConsignAward = [{ConsignTask#ets_consign_task.gid_1, ConsignTask#ets_consign_task.n_1},
																{ ConsignTask#ets_consign_task.gid_2, ConsignTask#ets_consign_task.n_2}],
												Award_item = lib_task:get_award_consign(ConsignAward),
												case ConsignTask#ets_consign_task.mt of
													1->
														{TD#task.id, TD#task.level, 6, TD#task.child,
								 						TD#task.name, TD#task.desc,TD#task.end_npc, TipList,0, ConsignTask#ets_consign_task.n_3, 0,
								 						0, 0, 0, 
								 						0, 0, 0, 0,0,
								 						TD#task.award_select_item_num, 
								 						Award_item, 
			 											TD#task.award_select_item,Times};
													_->
														{TD#task.id, TD#task.level, 6, TD#task.child,
								 						TD#task.name, TD#task.desc,TD#task.end_npc, TipList,ConsignTask#ets_consign_task.n_3, 0, 0,
								 						0, 0, 0, 
								 						0, 0, 0, 0,0,
								 						TD#task.award_select_item_num, 
								 						lib_task:get_award_item(TD, PlayerStatus), 
			 											TD#task.award_select_item,Times}
												end
										end;
									_->
										[Coin,GuildCoin] = case lib_task:is_guild_carry_task(TD) of
															   false->
																   case lib_task:is_carry_task(TD)of
																	   true->
																		   {_ExpCarry,CoinCarry} = lib_carry:base_carry_award(PlayerStatus#player.id,TD),
																		   [CoinCarry,TD#task.guild_coin];
																	   false->
																		   [TD#task.coin,TD#task.guild_coin]
																   end;
															   true->
																   case PlayerStatus#player.guild_id > 0 of
																	   false->[lib_task:guild_carry_coin_award(player,0),lib_task:guild_carry_coin_award(guild,0)];
																	   true->
																		   case mod_guild:get_guild_carry_info(PlayerStatus#player.guild_id) of
																			   [0,{}]->[lib_task:guild_carry_coin_award(player,0),lib_task:guild_carry_coin_award(guild,0)];
																			   [_,{Level,_Coin,_CarryTime,_BanditsTime,_ChiefId,_DeputyId1,_DeputyId2}]->
																				   [lib_task:guild_carry_coin_award(player,Level),lib_task:guild_carry_coin_award(guild,Level)]
																		   end
									   								end
							   								end,
										{TD#task.id, TD#task.level, TD#task.type, TD#task.child,
								 		TD#task.name, TD#task.desc,TD#task.end_npc, TipList,0,Coin, 
								 		Exp, Spt, TD#task.binding_coin, 
								 		TD#task.attainment,TD#task.honor, TD#task.realm_honor,TD#task.guild_exp,GuildCoin,TD#task.contrib, 
								 		TD#task.award_select_item_num, 
								 		lib_task:get_award_item(TD, PlayerStatus), 
			 							TD#task.award_select_item,Times}
								end
								end;
							false->skip
						end;
					false->
						skip
				end
        end,
        TriggerBag
    ),
	{ok, BinData} = pt_30:write(30001, [TriggerList]),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	{noreply,State};



%% 初始化玩家任务
handle_cast({'init_task',PlayerStatus},State)->
	NowTime = util:unixtime(),
	case NowTime - PlayerStatus#player.reg_time >5 of
		true->
			lib_task:flush_role_task(PlayerStatus);
		false->skip
	end,
	{noreply,State};

%%打怪事件
handle_cast({'kill_mon',PlayerStatus,MonId,MonLv},State)->
	lib_task:kill_mon(PlayerStatus,MonId,MonLv),
	{noreply,State};

%%任务事件
handle_cast({'task_event',PlayerStatus,Event,Param},State) ->
	{_,NewPlayerStatus} = case lib_task:task_event(Event, Param, PlayerStatus) of
		false->{ok,PlayerStatus};
		true->
			case Event of
				use_goods->
					{GoodsId}=Param,
					%%使用新手礼包
					if GoodsId =:= 31043 -> 
						   lib_task:auto_finish_task(PlayerStatus,20201);
					   %%使用血包
						GoodsId =:=23006->lib_task:auto_finish_task(PlayerStatus,20210);
					   %%使用法力包
						GoodsId =:= 23106->lib_task:auto_finish_task(PlayerStatus,20101);
						true->{ok,PlayerStatus}
					end;
				%%学习技能
				learn_skill->lib_task:auto_finish_task(PlayerStatus,20206);
				%%装备法宝
				equip->lib_task:auto_finish_task(PlayerStatus,20223);
				%%商城购买
				shopping->lib_task:auto_finish_task(PlayerStatus,40103);
				%%添加好友
				friend->lib_task:auto_finish_task(PlayerStatus,40112);
				%%加入氏族
				guild -> lib_task:auto_finish_task(PlayerStatus,40121);
				%%仙侣情缘
				love-> lib_task:auto_finish_task(PlayerStatus,83000);
				%%氏族祝福
%% 				guild_bless -> lib_task:auto_finish_task(PlayerStatus,83150);
%% 				pet->lib_task:auto_finish_task(PlayerStatus,20214);
				_->{ok,PlayerStatus}
			end
	end,
	case NewPlayerStatus =/=PlayerStatus of
		true->
			gen_server:cast(NewPlayerStatus#player.other#player_other.pid, 
							{'SET_PLAYER', [{spirit,NewPlayerStatus#player.spirit},
											{bcoin,NewPlayerStatus#player.bcoin},
											{coin,NewPlayerStatus#player.coin},
											{culture,NewPlayerStatus#player.culture},
											{lv,NewPlayerStatus#player.lv},
											{gold,NewPlayerStatus#player.gold},
											{exp,NewPlayerStatus#player.exp},
											{realm,NewPlayerStatus#player.realm},
											{hp_lim,NewPlayerStatus#player.hp_lim},
											{hp,NewPlayerStatus#player.hp},
											{mp,NewPlayerStatus#player.mp},
											{mp_lim,NewPlayerStatus#player.mp_lim}
										   ]});
%% 				lib_player:send_player_attribute(NewPlayerStatus, 1);
		false->skip
	end,
	{noreply,State};

%%NPC对话事件
handle_cast({'talk_npc',PlayerStatus, TaskId, NpcUniqueId},State) ->
	SceneId = PlayerStatus#player.scene,
    case mod_scene:find_npc(NpcUniqueId, SceneId) of
        [] ->  skip;
        [Npc] ->
			lib_task:task_event(talk, {TaskId, Npc#ets_npc.nid}, PlayerStatus)
%% 			case lib_task:task_event(talk, {TaskId, Npc#ets_npc.nid}, PlayerStatus) of
%% 				true->skip;
					%%跑商任务商车变换处理
%% 					case lib_task:get_data(TaskId) of
%% 						[]->skip;
%% 						Task->
%% 							if PlayerStatus#player.carry_mark>3 andalso PlayerStatus#player.carry_mark<8 ->
%% 								case lib_task:is_business_task(Task) of
%% 									false->skip;
%% 									true->
%% 										case lib_business:get_business(PlayerStatus#player.id) of
%% 											[]->skip;
%% 											[Business]->
%% 												if Business#ets_business.color > PlayerStatus#player.carry_mark ->
%% 								   					lib_business:change_car(PlayerStatus,Business#ets_business.color);
%% 							   						true->skip
%% 												end
%% 										end
%% 								end;
%% 							   true->skip
%% 							end
%%    					 end;
%% 				false->skip
%% 			end
	end,
	{noreply,State};

%%帮派任务处理
handle_cast({'guild_task_del',PlayerStatus},State)->
	lib_task:abnegate_guild_task(PlayerStatus),
	{noreply,State};

%%运镖失败
handle_cast({'carry_lose',PlayerStatus,Pid},State)->
	if PlayerStatus#player.carry_mark>0 andalso PlayerStatus#player.carry_mark<4 orelse (PlayerStatus#player.carry_mark >=20 andalso PlayerStatus#player.carry_mark<26)->
		NewPlayerStatus = lib_task:task_carry_lose(PlayerStatus),
		gen_server:cast(NewPlayerStatus#player.other#player_other.pid, {'SET_PLAYER', [{exp, NewPlayerStatus#player.exp}]}),
		lib_carry:carry_failed(NewPlayerStatus, Pid,PlayerStatus#player.carry_mark);
	   true->
		   lib_business:robbed_business(PlayerStatus,Pid)
	end,
	{noreply,State};

%%更新接镖次数
handle_cast({'ud_bandits',PlayerId},State)->
	lib_carry:update_bandits_times(PlayerId),
	{noreply,State};

%%刷新任务列表
handle_cast({'refresh_task',PlayerStatus},State)->
	%%清理试炼任务
	lib_task:abnegate_dun_task(PlayerStatus),
	lib_task:refresh_active(PlayerStatus),
	{ok, BinData} = pt_30:write(30006, [1,0]),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	{noreply,State};

%%怪物掉落任务物品
handle_cast({'mon_drop',PlayerStatus,MonId,MonType,MonLv,GoodList},State)->
	lib_task:mon_drop(PlayerStatus,MonId,MonType,MonLv,GoodList),
	{noreply,State};

%%查询委托任务信息
handle_cast({'check_consign_task',PlayerStatus,TaskId},State)->
	Msg =  lib_task:check_consign_task(PlayerStatus,TaskId),
	{ok, BinData} = pt_30:write(30013, Msg),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	{noreply,State};

%%是否弹出NPC对口框next_task_cue
handle_cast({'next_task_cue',PlayerStatus,TaskId,Type},State)->
	next_task_cue(PlayerStatus,TaskId,Type),
	{noreply,State};

%%取消委托任务
handle_cast({'cancel_task_consign',PlayerStatus,Id},State)->
	case lib_task:cancel_task_consign(PlayerStatus,Id) of
		{error,Result}->
			{ok,BinData} = pt_30:write(30402,[Result]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
		{ok,_}->skip
	end,
	{noreply,State};

%%处理发布玩家的委托任务
handle_cast({'change_consign_task_online',PlayerStatus,ConsignTask,Result,NickName},State)->
	lib_task:change_consign_task_online(PlayerStatus,ConsignTask,Result,NickName),
	{noreply,State};

%%处理接受玩家的委托任务
handle_cast({'accept_consign_task_online',PlayerStatus,TaskId},State)->
	lib_task:accept_consign_task_online(PlayerStatus,TaskId),
	{noreply,State};

%%重置玩家的委托任务
handle_cast({'reset_consign_task_online',PlayerStatus,TaskId},State)->
	lib_task:reset_consign_task_online(PlayerStatus,TaskId),
	{noreply,State};

%%日常任务累积
handle_cast({'daily_task',PlayerStatus},State)->
	TaskBag = lib_task:get_daily_task_info(PlayerStatus),
	{ok, BinData} = pt_30:write(30600, TaskBag),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	{noreply,State};

%%添加劫商信息
handle_cast({'robbed_info',PlayerId,RobbedId,Color},State)->
	lib_business:add_robbed_info(PlayerId,RobbedId,Color),
	{noreply,State};

%%劫商奖励
handle_cast({'get_robbed_award',PlayerStatus,Exp,Spt},State)->
	lib_business:get_robbed_award(PlayerStatus,Exp,Spt),
	{noreply,State};

%%停止进程
handle_cast({stop, _Reason}, State) ->
    {stop, normal, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

%%零点刷新任务
handle_info(refresh, State) ->
	case ets:lookup(?ETS_ONLINE, State#state.player_id) of
		[] ->skip;
%% 			NewState = State
		[PlayerStatus] ->
%% 			io:format("refresh>>>>>>>>>>>~p~n",[State#state.player_id]),
			%%删除指定任务
			del_task(PlayerStatus,?APPOINT_TASK_ID),
			lib_task:refresh_active(PlayerStatus),
			{ok, BinData} = pt_30:write(30006, [1,0]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
	end,
	erlang:send_after(get_refresh_time(), self(), refresh),
%% 			Timestamp = State#state.nowtime,
%% 			case check_new_day(Timestamp) of
%% 				true->
%% 					NewState = State,
%% 					erlang:send_after(?TIMER_1, self(), refresh);
%% 				false->
%% 					lib_task:refresh_active(PlayerStatus),
%% 					{ok, BinData} = pt_30:write(30006, [1,0]),
%%     				lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
%% 		   			erlang:send_after(?TIMER_1, self(), refresh),
%% 					NewState = State#state{nowtime=util:unixtime()}
%% 			end
%% 	end,
	{noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% %%检查第二天
%% check_new_day(Timestamp)->
%% 	if Timestamp =/= 0 ->
%% 		NDay = (util:unixtime()+8*3600) div 86400,
%% 		TDay = (Timestamp+8*3600) div 86400,
%% 		NDay=:=TDay;
%% 	   true->
%% 		   true
%% 	end.

%%获取下次刷新任务时间(30秒误差)
get_refresh_time()->
	Sec = util:rand(10,50),
	round(24*3600 - util:get_today_current_second()+Sec)*1000.
	
	
next_task_cue(PlayerStatus,TaskId,Type)->
	case lib_task:get_data(TaskId) of 
        [] -> skip;
        TD ->
            case TD#task.next_cue of
                0 -> skip;
                _ -> 
					case Type of
						1->
                   			Npc = lib_npc:get_data(TD#task.start_npc),
							TaskList = lib_task:get_npc_task_list(TD#task.start_npc, PlayerStatus);
						_->
							Npc = lib_npc:get_data(TD#task.end_npc),
							TaskList = lib_task:get_npc_task_list(TD#task.end_npc, PlayerStatus)
					end,
				   if TaskList/=[] ->
						  Id = mod_scene:get_npc_unique_id(Npc#ets_npc.nid, PlayerStatus#player.scene),
%% 						  case Type of
%% 							  1->
%% 						  		Id = mod_scene:get_npc_unique_id(TD#task.start_npc, PlayerStatus#player.scene);
%% 							  _->
%% 								  Id = mod_scene:get_npc_unique_id(TD#task.end_npc, PlayerStatus#player.scene)
%% 						  end,
						  case PlayerStatus#player.realm =:=100 orelse length(TaskList) =:= 1 of
							  true->
								  case lib_task:check_npc_type(Npc) of
									  true->
										   case check_task_state(TaskList) of
											  true->
										  		%%[[20100,3, <<229,145,189,232,191,144,228,185,139,229,173,144>>,4]]
								  				[[NextTaskId|_]|_Other]=TaskList,
					              				pp_npc:handle(32001, PlayerStatus, [Id, NextTaskId]);
											   false->skip
										   end;
									  false->
										  case check_task_state(TaskList) of
											  true->
										  		TalkList = data_agent:talk_get(Npc#ets_npc.talk),
								  		  		{ok, BinData} = pt_32:write(32000, [Id, TaskList, TalkList]),
								   		  		lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
											  false->skip
										  end
								  end;
							   false->
								   case check_task_state(TaskList) of
									   true->
										   TalkList = data_agent:talk_get(Npc#ets_npc.talk),
										   {ok, BinData} = pt_32:write(32000, [Id, TaskList, TalkList]),
										   lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
									   false->skip
								   end
						  end;
					   true->
						   skip
				   end
			end
    end.

check_task_state([])->
	false;
check_task_state(TaskList)->
%% 	 L1 = [F(T1, 1) || T1 <- CanTrigger],
%%     L2 = [F(T2, 4) || T2 <- Link],
%%     L3 = [F(T3, 2) || T3 <- UnFinish],
%%     L4 = [F(T4, 3) || T4 <- Finish],
	[[_NextTaskId,State|_]|Other]=TaskList,
	if State =/= 2 ->
		   true;
	   true->check_task_state(Other)
	end.

%%删除指定任务
del_task(PlayerStatus,TaskId)->
	case lib_task:get_one_trigger(TaskId, PlayerStatus#player.id) of
		false->skip;
		RT ->
			NowTime = util:unixtime(),
			TD = lib_task:get_data(TaskId),
			ets:delete(?ETS_ROLE_TASK, {PlayerStatus#player.id, TaskId}),
			mod_task_cache:del_trigger(PlayerStatus#player.id, TaskId)
	end.