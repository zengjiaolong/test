%%%-----------------------------------
%%% @Module  : mod_meridian
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 经脉模块
%%%-----------------------------------
-module(mod_meridian).
-behaviour(gen_server).
%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").

%%
%% Exported Functions
%%
-export(
    [
        start_link/1
        ,stop/0
    ]
).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-export([check_meridian_active/2,
		 meridian_active/2,
		 meridian_uplvl_finish/3,
		 meridian_uplvl_cancel/2,
		 meridian_uplvl_speed/3,
		 meridian_up_linggen/4,
		 check_condition/3,
		 merdian_break_through/2,
		 gm_merlv/2,
		 gm_linggen/2
		]).

%% 定时器1间隔时间
-define(TIMER_1, 60000).
-define(TIMER_2, 600000).
-record(state, {player_id = 0}).
%%
%% API Functions
%%

start_link(Pid)->
    gen_server:start_link(?MODULE, [Pid], []).

%% 关闭服务器时回调
stop() ->
    ok.

init([PlayerId])->
	misc:write_monitor_pid(self(),?MODULE, {}),
	%%初始化玩家经脉信息
	lib_meridian:online(PlayerId),
	erlang:send_after(10000, self(), meridian),
	State = #state{player_id=PlayerId},
    {ok,State}.

%%
%% Local Functions
%%

%%停止进程
handle_cast({stop, _Reason}, State) ->
    {stop, normal, State};

handle_cast(_Message,State)->
	{noreply,State}.

handle_call({meridian,PlayerId},_From,State)->
	Meridian = case lib_meridian:get_player_meridian_info(PlayerId) of
		[]->[[]];
		MeridianInfo->MeridianInfo
	end,
	{reply,Meridian,State};

handle_call(_Request, _From, State) ->
    {reply, State}.

handle_info(meridian, State) ->
	case ets:lookup(?ETS_ONLINE, State#state.player_id) of
		[] ->
			erlang:send_after(?TIMER_2, self(), meridian),
			ok;
		[PlayerStatus] ->
			if PlayerStatus#player.lv> 10->
				   meridian_finish_check(PlayerStatus),
				%% 再次启动闹钟
				if PlayerStatus#player.lv<15->
    				erlang:send_after(?TIMER_1, self(), meridian);
	   			true->
		   			erlang:send_after(?TIMER_2, self(), meridian)
				end;
			   true->erlang:send_after(?TIMER_1, self(), meridian)
			end
	end,
	{noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%========================================================================
%%业务处理函数
%%===========================================================================
meridian_finish_check(PlayerStatus)->
	case check_meridian_active(PlayerStatus,[1,2,3,4,5,6,7,8]) of
		{false,_}->skip;
		{true,NewPlayerStatus}->
			{ok,Bin} = pt_25:write(25010,[1]),
			lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, Bin)
	end.

check_meridian_active(PlayerStatus,MeridianList)->
	case PlayerStatus#player.lv > 10 of
		true->
			case lib_meridian:get_player_meridian_info(PlayerStatus#player.id) of
				[]->{false,PlayerStatus};
				[MeridianInfo]->
					meridian_active_check(PlayerStatus,MeridianInfo,MeridianList)
			end;
		false->{false,PlayerStatus}
	end.

%%检查经脉能否修炼
meridian_active_check(PlayerStatus,_MeridianInfo,[])->
	{false,PlayerStatus};
meridian_active_check(PlayerStatus,MeridianInfo,MeridianList)->
	[MeridianId|T]=MeridianList,
	case meridian_active_condition_check(PlayerStatus,MeridianInfo,MeridianId,1) of
		{error,NewPlayerStatus,_}->
			meridian_active_check(NewPlayerStatus,MeridianInfo,T);
		{ok,NewPlayerStatus,_}->
			{true,NewPlayerStatus}
	end.
%-----------------------------------------------------------
%经脉开脉:7修炼升级，1满等级，2前置经脉等级不符合，3没有该经脉记录,4玩家等级不足，5灵力不足，6其他经脉正在修炼中)
%-----------------------------------------------------------
meridian_active(PlayerStatus,MeridianId) ->
    %检测开脉条件
	case lib_meridian:get_player_meridian_info(PlayerStatus#player.id) of
		[]->{error,PlayerStatus,[3,0]};
		[MeridianInfo]->
			case meridian_active_condition_check(PlayerStatus,MeridianInfo,MeridianId,2) of
				{error,NewPlayerStatus,[Result,Timestamp]}->
					{error,NewPlayerStatus,[Result,Timestamp]};
				{ok,NewPlayerStatus,[Value,Timestamp,Lingli]}->
					PS1 = change_player_info(NewPlayerStatus,spirit,Lingli,sub,0),
					start_msg(PlayerStatus,MeridianId,Lingli),
 					lib_meridian:start_uplvl_meridian(NewPlayerStatus#player.id,MeridianInfo,MeridianId,Timestamp + util:unixtime()),
 					{ok,PS1,[Value,Timestamp]}
			end
	end.

%%经脉修炼条件检测
meridian_active_condition_check(PlayerStatus,MeridianInfo,MeridianId,Type)->
	%%经脉id检测
	case check_meridian_id(MeridianId) of
		{ok,_}->
			PlayerId = PlayerStatus#player.id,
			MeridianType = lib_meridian:id_to_type(MeridianId),
			%%当前是否有经脉在修炼
			case lib_meridian:check_can_uplvl1(PlayerStatus,MeridianInfo,Type) of
				{NewPlayerStatus,0,NewMeridianInfo} ->
					%检查关联的经脉等级
					case catch check_condition(NewMeridianInfo,PlayerId,MeridianType) of
						{ok,Data}->
							[Lvl,Value,BreakValue] = Data,
							%%获取经脉升级相关基础值
							case lib_meridian:get_meridian_uplvl_value(MeridianId,Lvl)of
								[]->
									{error,NewPlayerStatus,[8,0]};
								Info ->
									[PlayerLvl,Timestamp,Lingli]= Info,
									if 
										%灵力不足
										Lingli > NewPlayerStatus#player.spirit	->
											{error,NewPlayerStatus,[5,0]};
										true	->
											if 
												%等级不足
												NewPlayerStatus#player.lv < PlayerLvl ->
												   {error,NewPlayerStatus,[4,0]};
												true->
													if Lvl>11 andalso BreakValue<100->
														  {error,NewPlayerStatus,[9,0]};
													  true->
														{ok,NewPlayerStatus,[Value,Timestamp,Lingli]}
													end
											end
									end
							end;
						{error,Result}->
							{error,NewPlayerStatus,[Result,0]}
					end;
				{NewPlayerStatus,_,_}->
					{error,NewPlayerStatus,[6,0]}
			end;
		{error,ErrorValue}->
			{error,PlayerStatus,[ErrorValue,0]}
	end.

%经脉修炼结束
meridian_uplvl_finish(PlayerStatus,MeridianInfo,Type)->
	{ok,Mer_Attrit} = lib_meridian:get_meridian_att_current(PlayerStatus#player.id,MeridianInfo),
	PlayerStatus1 = PlayerStatus#player{
						  other = PlayerStatus#player.other#player_other{
                           		meridian_attribute = Mer_Attrit
								}
                    		},
	NewPS_1 = lib_player:count_player_attribute(PlayerStatus1),
    %刷新玩家信息
	lib_player:send_player_attribute(NewPS_1, 1),
	case Type of
		true->meridian_finish_check(PlayerStatus);
		_->skip
	end,
	NewPS_1.
	
%取消修炼
meridian_uplvl_cancel(PlayerStatus,MeridianId)->
	PlayerId = PlayerStatus#player.id,
	MerType = lib_meridian:id_to_type(MeridianId),
	case lib_meridian:get_player_meridian_info(PlayerStatus#player.id) of
		[]->{error,PlayerStatus,0};
		[MeridianInfo]-> 
			MerId = MeridianInfo#ets_meridian.meridian_uplevel_typeId,
			if 
				MerId =:= 0 orelse MerId =/= MeridianId ->
				   {error,PlayerStatus,0};
			 	true ->
					{ok,[Lvl,_LG,_value]} = lib_meridian:check_meridian_lvl_and_linggen(PlayerId,MeridianInfo,MerType),
					case lib_meridian:get_meridian_uplvl_value(MerId,Lvl+1) of
						[]->
							{error,PlayerStatus,0};
						[_,_,Spirit]->
							PS = change_player_info(PlayerStatus,spirit,Spirit,add,0),
							lib_meridian:meridian_uplvl_change(PlayerId,MeridianInfo,MerId,0),
							cancel_msg(PS,MeridianId,Spirit),
							{error,PS,1}
					end
			end
	end.


%经脉修炼加速
meridian_uplvl_speed(PlayerStatus,_MeridianId,GoodsType)->
	PlayerId = PlayerStatus#player.id,
	GoodsId = goodstype_to_goodsid(GoodsType),
	case lib_meridian:get_player_meridian_info(PlayerStatus#player.id) of
		[]->{error,PlayerStatus,[0,0]};
		[MeridianInfo]->
			case lib_meridian:check_uplvl_meridian(PlayerId,MeridianInfo) of
				{ok,[0,0]} -> 
					{error,PlayerStatus,[0,0]};
				{ok,Result}->
					[MerId,Timestamp] = Result,
					if 
						%当前没有经脉在修炼
						MerId =:= 0 orelse Timestamp=:=0 ->
						    {error,PlayerStatus,[0,0]};
						true ->	
							%获取加速时间和元宝
							[TimeSpeed,Gold] = goodsid_to_time_and_gold(GoodsId,Timestamp),
							TimeRemain = Timestamp - TimeSpeed,
							NowTime = util:unixtime(),
							if 
								%立即完成
								GoodsType =:= 1 -> 
									[PGold,_] = db_agent:query_player_money(PlayerId),
									if 
										%元宝不足
										PGold<Gold->
											{error,PlayerStatus,[3,0]};
										true ->
											%修炼完成
											NewMeridianInfo = lib_meridian:meridian_uplvl_change(PlayerId,MeridianInfo,MerId,1),
											%更新玩家属性
											PS = meridian_uplvl_finish(PlayerStatus,NewMeridianInfo,false),
											%扣除元宝
											NewPS = change_player_info(PS,gold,Gold,sub,2501),
											{error,NewPS,[1,0]}
									end;
								true ->
									Error_Goods = gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'delete_more', GoodsId, 1}),
									if 
										%物品扣除成功，修炼完成
										Error_Goods=:= 1 andalso TimeRemain =< NowTime ->
											%更新玩家修练时间
											NewMeridianInfo = lib_meridian:meridian_uplvl_change(PlayerId,MeridianInfo,MerId,1),
											%更新玩家属性
											PS = meridian_uplvl_finish(PlayerStatus,NewMeridianInfo,false),
											{error,PS,[1,0]};
										%物品扣除成功，减少修炼时间
									    Error_Goods =:= 1 andalso TimeRemain > NowTime ->
											lib_meridian:speed_uplvl_meridian(MeridianInfo,PlayerId,TimeRemain),
											{error,PlayerStatus,[2,TimeRemain]};
										%没有物品，扣除元宝代替
										true ->
											[PGold,_] = db_agent:query_player_money(PlayerId),
											if 
												PGold < Gold ->
													{error,PlayerStatus,[3,0]};
												true ->
													if 
														TimeRemain =< NowTime ->
															%修炼完成
															NewMeridianInfo = lib_meridian:meridian_uplvl_change(PlayerId,MeridianInfo,MerId,1),
															%更新玩家属性
															PS = meridian_uplvl_finish(PlayerStatus,NewMeridianInfo,false),
															%扣除元宝
															NewPS = change_player_info(PS,gold,Gold,sub,2501),
															{error,NewPS,[1,0]};
														true ->
															lib_meridian:speed_uplvl_meridian(MeridianInfo,PlayerId,TimeRemain),
															%扣除元宝
															NewPS = change_player_info(PlayerStatus,gold,Gold,sub,2501),
															{error,NewPS,[2,TimeRemain]}
													end
										end
									end
							end
					end
			end
					
	end.



%灵根洗练
%%(1洗练失败，灵根置零，2修炼失败，灵根不变，3修炼成功，4满级，5铜钱不足，6没有成长符，7其他错误,8没有保护符,9元宝不足
meridian_up_linggen(PlayerStatus,MeridianId,IsSave,AutoPay)->
	PlayerId = PlayerStatus#player.id,
	MerType = lib_meridian:id_to_type(MeridianId),
	MerLGType = lib_meridian:mertype_to_linggen(MerType),
	case lib_meridian:get_player_meridian_info(PlayerStatus#player.id) of
		[]->{error,PlayerStatus,0};
		[MeridianInfo]-> 
			{ok,[Lvl,LG_Value,_value]}=lib_meridian:check_meridian_lvl_and_linggen(PlayerId,MeridianInfo,MerType),
			Effect_1 = lib_meridian:get_meridian_effect(MeridianId,Lvl,LG_Value),
			if Lvl =< 0->
				   {error,PlayerStatus,[7,LG_Value,Effect_1]};
				true->
					if 
						LG_Value >= 100 ->
							{error,PlayerStatus,[4,LG_Value,Effect_1]};
						true ->
							Coin_Need = round(500 * (1 + LG_Value / 10 )), 
							if 
								%铜钱不足
								Coin_Need > PlayerStatus#player.coin+PlayerStatus#player.bcoin ->
								   {error,PlayerStatus,[5,LG_Value,Effect_1]};
					 			true ->
									%扣除灵根成长符
									Symbol_Grow = 22000, 
									{Error_Grow,NewPlayer} = 
										case gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'delete_more', Symbol_Grow, 1}) of
											1->{1,PlayerStatus};
											_->
												case AutoPay of
													1->
														case goods_util:is_enough_money_to_pay_goods(PlayerStatus,Symbol_Grow,1) of
															{true,Price}->
																spawn(fun() ->log:log_shop([1,1,PlayerStatus#player.id,PlayerStatus#player.nickname,Symbol_Grow,gold,Price,1]) end),
																{1,lib_goods:cost_money(PlayerStatus, Price, gold,2503)};
															{false,_}->
																{0,PlayerStatus}
														end;
													_0->
														{0,PlayerStatus}
												end
										end,
									%%测试
%% 									Error_Grow = 1,					
									if 
										Error_Grow =/= 1 ->
											case AutoPay of
												1->{error,PlayerStatus,[9,LG_Value,Effect_1]};
												_->
													{error,PlayerStatus,[6,LG_Value,Effect_1]}
											end;
										true ->
											SuccessValue = (100 - LG_Value) * 100,
											if SuccessValue >= 9000->
												   NewSuccessValue = SuccessValue;
											   SuccessValue > 5000->
												   NewSuccessValue=round(SuccessValue*1);
											   SuccessValue > 3000->
												   NewSuccessValue=round(SuccessValue*0.8);
											   true->
												   NewSuccessValue=round(SuccessValue*0.7)
											end,
											{NewPlayerStatus,_,_Mult} = lib_vip:get_vip_award(meridian,NewPlayer),
											NewSuccessValue1 = round(NewSuccessValue),
											RP = util:rand(1,10000),
											if 
												%RP爆发，灵根洗练成功
												RP =< NewSuccessValue1 ->
													if IsSave =:= 1	->
															Symbol_Protect = 22007,
															Error_Protect = gen_server:call(NewPlayerStatus#player.other#player_other.pid_goods, {'delete_more', Symbol_Protect, 1}),
															%%测试
%% 															Error_Protect = 1,											
															if 
																%%拥有灵根保护符
																Error_Protect =:= 1 ->
																	NewMeridianInfo = lib_meridian:update_meridian_linggen(PlayerId,MeridianInfo,MerLGType,10),
																	PS = meridian_uplvl_finish(NewPlayerStatus,NewMeridianInfo,false),
																	NewPS = change_player_info(PS,coin,Coin_Need,sub,2502),
																	Effect = lib_meridian:get_meridian_effect(MeridianId,Lvl,LG_Value+10),
																	sys_broadcast_msg(NewPS,MerType,LG_Value+10),
																	spawn(fun()->catch(db_agent:linggen_log(PlayerId,MeridianId,LG_Value,LG_Value+10,IsSave,1,util:unixtime()))end),
																	{error,NewPS,[3,LG_Value+10,Effect]};
																true->
																	gen_server:call(NewPlayerStatus#player.other#player_other.pid_goods, {'give_goods',NewPlayerStatus, 22000, 1,0}),
																	{error,NewPlayerStatus,[8,LG_Value,Effect_1]}
															end;
													true->
														NewMeridianInfo = lib_meridian:update_meridian_linggen(PlayerId,MeridianInfo,MerLGType,10),
														PS = meridian_uplvl_finish(NewPlayerStatus,NewMeridianInfo,false),
														NewPS = change_player_info(PS,coin,Coin_Need,sub,2502),
														Effect = lib_meridian:get_meridian_effect(MeridianId,Lvl,LG_Value+10),
														sys_broadcast_msg(NewPS,MerType,LG_Value+10),
														spawn(fun()->catch(db_agent:linggen_log(PlayerId,MeridianId,LG_Value,LG_Value+10,IsSave,1,util:unixtime()))end),
														{error,NewPS,[3,LG_Value+10,Effect]}
												end;
												true ->
													if 
														IsSave =:= 1	->
															Symbol_Protect = 22007,
															Error_Protect = gen_server:call(NewPlayerStatus#player.other#player_other.pid_goods, {'delete_more', Symbol_Protect, 1}),
															%%测试
%% 															Error_Protect = 1,											
															if 
																%%拥有灵根保护符，免除惩罚
																Error_Protect =:= 1 ->
																	PS = change_player_info(NewPlayerStatus,coin,Coin_Need,sub,2502),
																	Effect = lib_meridian:get_meridian_effect(MeridianId,Lvl,0),
																	spawn(fun()->catch(db_agent:linggen_log(PlayerId,MeridianId,LG_Value,LG_Value,IsSave,0,util:unixtime()))end),
																	{error,PS,[2,LG_Value,Effect]};
																true ->
																	{error,NewPlayerStatus,[8,LG_Value,Effect_1]}
																	%%没有保护符，灵根置零
%% 																	NewMeridianInfo = lib_meridian:update_meridian_linggen(PlayerId,MeridianInfo,MerLGType,-LG_Value),
%% 																	PS = meridian_uplvl_finish(PlayerStatus,NewMeridianInfo,false),
%% 																	NewPs = change_player_info(PS,coin,Coin_Need,sub,2502),
%% 																	Effect = lib_meridian:get_meridian_effect(MeridianId,Lvl,0),
%% 																	{error,NewPs,[1,0,Effect]}
																end;
														   true ->
														  	%%没有保护符，灵根置零
																NewMeridianInfo = lib_meridian:update_meridian_linggen(PlayerId,MeridianInfo,MerLGType,-LG_Value),
																PS = meridian_uplvl_finish(NewPlayerStatus,NewMeridianInfo,false),
																NewPS = change_player_info(PS,coin,Coin_Need,sub,2502),
																Effect = lib_meridian:get_meridian_effect(MeridianId,Lvl,0),
																spawn(fun()->catch(db_agent:linggen_log(PlayerId,MeridianId,LG_Value,0,IsSave,0,util:unixtime()))end),
																{error,NewPS,[1,0,Effect]} 
													end
											end
									end
							end
					end
			end
	end.

%%经脉突破,1突破成功，2数据异常,3铜钱不足，不能突破，4灵力不足，不能突破，5全部经脉未达11以上，不能突破，6突破失败，7突破丹不足，不能突破,8已到突破上限
merdian_break_through(PlayerStatus,MerId)->
	MerType = lib_meridian:id_to_type(MerId),
	TopType = lib_meridian:mertype_to_topvalue(MerType),
	case lib_meridian:get_player_meridian_info(PlayerStatus#player.id) of
		[]->{2,PlayerStatus,0};
		[MeridianInfo]-> 
			{ok,[_Lvl,_LG_Value,Value]}=lib_meridian:check_meridian_lvl_and_linggen(PlayerStatus#player.id,MeridianInfo,MerType),
			{Rp,Coin,Spt} = lib_meridian:break_through_value(Value,MerId),
			case Value >=100 of
				true->{8,PlayerStatus,0};
				false->
					case goods_util:is_enough_money(PlayerStatus,Coin,coin) of
						false->{3,PlayerStatus,0};
						true->
							case PlayerStatus#player.spirit < abs(Spt) of
								true->{3,PlayerStatus,0};
								false->
									Lvlist = [MeridianInfo#ets_meridian.mer_yang,
									  		MeridianInfo#ets_meridian.mer_yin,
									 		 MeridianInfo#ets_meridian.mer_wei,
									  		MeridianInfo#ets_meridian.mer_ren,
									  		MeridianInfo#ets_meridian.mer_du,
									  		MeridianInfo#ets_meridian.mer_chong,
									  		MeridianInfo#ets_meridian.mer_qi,
									  		MeridianInfo#ets_meridian.mer_dai],
									case lists:all(fun(M)-> M>=11 end,Lvlist) of
										false->{5,PlayerStatus,0};
										true->
											case catch gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'delete_more', 22008, 1}) of 
												1->
													case util:rand(1,10000) =< Rp of
														false->
															spawn(fun()->catch(db_agent:log_meridian_break(PlayerStatus#player.id,MerId,Value,Value,0,util:unixtime()))end),
															PlayerStatus1 = lib_goods:cost_money(PlayerStatus,Coin,coin,2503),
															PlayerStatus2 = change_player_info(PlayerStatus1,spirit,Spt,sub,0),
															{6,PlayerStatus2,0};
														true->
															lib_meridian:update_meridian_break_through(PlayerStatus#player.id,MeridianInfo,TopType,10),
															spawn(fun()->catch (db_agent:log_meridian_break(PlayerStatus#player.id,MerId,Value,Value+10,1,util:unixtime()))end),
															PlayerStatus1 = lib_goods:cost_money(PlayerStatus,Coin,coin,2503),
															PlayerStatus2 = change_player_info(PlayerStatus1,spirit,Spt,sub,0),
															{1,PlayerStatus2,Value+10}
													end;
												_->{7,PlayerStatus,0}
											end
									end
							end
					end
			end
	end.

%玩家铜钱、元宝、灵力操作
change_player_info(Status,Type,Num,SubType,PointId)->
	case Type of
		spirit->
			KeyValueList = [{Type,Num,SubType}],
			WhereList = [{id,Status#player.id}],
			catch db_agent:mm_update_player_info(KeyValueList,WhereList);
		_->
			case SubType of
				sub->
					db_agent:cost_money(Status,Num,Type,PointId);
				_->db_agent:add_money(Status,Num,Type,PointId)
			end
	end,
	if 
		Type =:= coin ->
			if Status#player.bcoin > abs(Num)->
				Coin=Status#player.bcoin - Num,
				Status3=Status#player{bcoin=Coin};
			   true->
				   Coin=Status#player.coin +Status#player.bcoin - Num,
				   Status3=Status#player{coin=Coin,bcoin = 0}
			end;
	  	Type =:= gold ->
			Gold=Status#player.gold - Num,
			Status3=Status#player{gold = Gold};
		Type =:= spirit ->
			case SubType of
				add ->
					Spirit=Status#player.spirit + Num,
					Status3=Status#player{spirit = Spirit};
				_->
					Spirit=Status#player.spirit - Num,
					Status3=Status#player{spirit = Spirit}
				end;
		true ->
			Status3=Status
	end,
%% 	gen_server:cast(Status3#player.other#player_other.pid, {'SET_PLAYER', [{Type,Num}]}),
	lib_player:send_player_attribute(Status3, 1),
	Status3.

%检查开脉条件——经脉限制
check_condition(MeridianInfo,PlayerId,MerType)	->
	%返回:7可以修炼升级，1满等级，2前置经脉等级不符合，3没有该玩家记录
	case check_lvl_prea(MeridianInfo,PlayerId,MerType) of
		{error,Data}->{error,Data};
		{ok,_}->
			case lib_meridian:check_relation_meridian_lvl(MeridianInfo,PlayerId,MerType) of
				[] ->
					{error,3};
				Result ->
					[Lvl,Lvl1,Lvl2,TopValue]=Result,
					NewLvl = Lvl+1,
					if 
						Lvl >= 17 -> 
							{error,1};
						true ->
							if 
								MerType =:= mer_yang orelse MerType =:= mer_yin ->
									if 
										NewLvl-1 =< Lvl1 andalso NewLvl-1 =< Lvl2 ->
											{ok,[NewLvl,7,TopValue]};
										true	->
											{error,2}
									end;
								true ->
									if 
										NewLvl =< Lvl1 andalso NewLvl =< Lvl2 ->
											{ok,[NewLvl,7,TopValue]};	
										true	->
											{error,2}
									end
							end
					end
			end
	end. 

%%0级前置检测
check_lvl_prea(MeridianInfo,PlayerId,MerType)->
	case lib_meridian:check_relation_meridian_prea(MeridianInfo,PlayerId,MerType) of
		[]->{error,3};
		Data->
			[MerLv,MerLvPrea]=Data,
			case MerLv of
				0->
					case MerLvPrea of
						0->
							{error,2};
						_->{ok,7}
					end;
				_->{ok,7}
			end
	end.

%%经脉id检查
check_meridian_id(MeridianId)->
%% 	case MeridianId =:= 1 orelse MeridianId =:= 2 orelse 
%% 			 MeridianId =:= 3 orelse MeridianId =:= 4 orelse 
%% 			 MeridianId =:= 5 orelse MeridianId =:= 6 orelse
%% 			 MeridianId =:= 7 orelse MeridianId =:= 8 of
	case lists:member(MeridianId,[1,2,3,4,5,6,7,8])of
		true->
			{ok,7};
		false->
			{error,3}
	end.

%获取加速物品类型id
goodstype_to_goodsid(GoodsType)->
	if
        GoodsType =:= 1   ->
            GoodsId= 99999;
        GoodsType =:= 2   ->
            GoodsId= 22001;
        GoodsType =:= 3   ->
            GoodsId= 22002;
        GoodsType =:= 4   ->
            GoodsId= 22003;
        GoodsType =:= 5   ->
            GoodsId= 22004;
        GoodsType =:= 6   ->
            GoodsId= 22005;
        GoodsType =:= 7   ->
            GoodsId= 22006;
        true    ->
            GoodsId = 0
    end,
    GoodsId.

%获取加速时间和所需元宝
goodsid_to_time_and_gold(GoodsId,Time)->
	if
		GoodsId =:= 99999   ->
            Timestamp= Time,
%% 			Gold = 0;
			Gold = tool:ceil((Time-util:unixtime()) / 180);
        GoodsId =:= 22001   ->
            Timestamp= 900,
			Gold = 5;
        GoodsId =:= 22002   ->
            Timestamp= 3600,
			Gold = 20;
        GoodsId =:= 22003   ->
            Timestamp= round(3600*2.5),
			Gold = 50;
        GoodsId =:= 22004   ->
            Timestamp= 3600*8,
			Gold = 160;
        GoodsId =:= 22005   ->
           Timestamp= util:rand(8,30)*3600,
		   Gold = 400;
        GoodsId =:= 22006   ->
            Timestamp= round((Time-util:unixtime())*0.3),
			Gold = 500;
        true    ->
            Timestamp = 0,
			Gold = 0
    end,
    [Timestamp,Gold].

%%灵根提升系统广播
sys_broadcast_msg(PS,MerType,LG)->	
	if LG>60 ->
		MerId = lib_meridian:type_to_id(MerType),
		Msg = case LG of
			70->
				io_lib:format("[~s]玩家[<a href='event:1,~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>]成功将~s灵根提升到~p，已经半人半神了！",[get_realm_name_by_id(PS#player.realm),PS#player.id,PS#player.nickname,PS#player.career,PS#player.sex,PS#player.nickname,get_name_by_id(MerId),LG]);
			80->
				io_lib:format("[~s]玩家[<a href='event:1,~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>]成功将~s灵根提升到~p，已经如同神一般了！",[get_realm_name_by_id(PS#player.realm),PS#player.id,PS#player.nickname,PS#player.career,PS#player.sex,PS#player.nickname,get_name_by_id(MerId),LG]);
			90->
				io_lib:format("[~s]玩家[<a href='event:1,~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>]成功将~s灵根提升到~p，已经超越神了！",[get_realm_name_by_id(PS#player.realm),PS#player.id,PS#player.nickname,PS#player.career,PS#player.sex,PS#player.nickname,get_name_by_id(MerId),LG]);
			_->
				io_lib:format("[~s]玩家[<a href='event:1,~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>]成功将~s灵根提升到~p，已经变态到了极点了！",[get_realm_name_by_id(PS#player.realm),PS#player.id,PS#player.nickname,PS#player.career,PS#player.sex,PS#player.nickname,get_name_by_id(MerId),LG])
		end,
		lib_chat:broadcast_sys_msg(2,Msg);
	true->
		skip
	end.

%%根据id获取经脉名称
get_name_by_id(Id)->
	case Id of
		1->"阳脉";
		2->"阴脉";
		3->"维脉";
		4->"任脉";
		5->"督脉";
		6->"冲脉";
		7->"奇脉";
		_->"带脉"
	end.

%%根据id获取部落名称
get_realm_name_by_id(Id)->
	case Id of
		1->"女娲";
		2->"神农";
		_->"伏羲"
	end.

start_msg(PlayerStatus,MerId,Spirit)->
	MerName = get_name_by_id(MerId),
	Msg = io_lib:format("你修炼【~s】,消耗了~p灵力", [MerName,Spirit]),
	{ok,MyBin} = pt_15:write(15055,[Msg]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin).

cancel_msg(PlayerStatus,MerId,Spirit)->
	MerName = get_name_by_id(MerId),
	Msg = io_lib:format("你取消了【~s】的修炼，返回~p灵力", [MerName,Spirit]),
	{ok,MyBin} = pt_15:write(15055,[Msg]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin).

%%GM命令，修改经脉等级
gm_merlv(Status,Lv)->
	case lib_meridian:get_player_meridian_info(Status#player.id) of
		[]->Status;
		[MeridianInfo]-> 
			NewMeridianInfo = MeridianInfo#ets_meridian{ mer_yang = Lv, mer_yin = Lv, 
														  mer_wei = Lv,mer_ren = Lv,
														  mer_du = Lv, mer_chong = Lv,
														 mer_qi = Lv, mer_dai = Lv,
														 meridian_uplevel_typeId=0,
														 meridian_uplevel_time=0},
			ets:insert(?ETS_MERIDIAN,NewMeridianInfo),
			db_agent:update_meridian_info([
										   {mer_yang,Lv},
										   {mer_yin,Lv},
										   {mer_wei,Lv},
										   {mer_ren,Lv},
										   {mer_du,Lv},
										   {mer_chong,Lv},
										   {mer_qi,Lv},
										   {mer_dai,Lv},
										   {meridian_uplevel_typeId,0},
										   {meridian_uplevel_time,0}
										   ],[{player_id,Status#player.id}]),
			meridian_uplvl_finish(Status,NewMeridianInfo,false)
	end.

gm_linggen(Status,Lv)->
	case lib_meridian:get_player_meridian_info(Status#player.id) of
		[]->Status;
		[MeridianInfo]-> 
			NewMeridianInfo = MeridianInfo#ets_meridian{ mer_yang_linggen = Lv, mer_yin_linggen = Lv, 
														  mer_wei_linggen = Lv,mer_ren_linggen = Lv,
														  mer_du_linggen = Lv, mer_chong_linggen = Lv,
														 mer_qi_linggen = Lv, mer_dai_linggen = Lv,
														 meridian_uplevel_typeId=0,
														 meridian_uplevel_time=0},
			ets:insert(?ETS_MERIDIAN,NewMeridianInfo),
			db_agent:update_meridian_info([
										   {mer_yang_linggen,Lv},
										   {mer_yin_linggen,Lv},
										   {mer_wei_linggen,Lv},
										   {mer_ren_linggen,Lv},
										   {mer_du_linggen,Lv},
										   {mer_chong_linggen,Lv},
										   {mer_qi_linggen,Lv},
										   {mer_dai_linggen,Lv},
										   {meridian_uplevel_typeId,0},
										   {meridian_uplevel_time,0}
										   ],[{player_id,Status#player.id}]),
			meridian_uplvl_finish(Status,NewMeridianInfo,false)
	end.