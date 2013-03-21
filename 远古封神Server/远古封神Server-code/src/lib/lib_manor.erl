%%% -------------------------------------------------------------------
%%% Description :神之农庄
%%% Author: ZKJ
%%% Created : 2010-11-17
%%% -------------------------------------------------------------------
-module(lib_manor).
-export(
	[
		send_manor_apply/3,  
		get_manor_state/2,   
		get_farm_info/2,          
		get_good_info/2, 
		send_fram_status_when_change/2,
		get_celerate_info/2, 
		get_friends_lists/2, 
		get_steal_remain_times/1, 
		get_mature_status/2, 
		write_log/11, 
		get_steal_sell_num/1,
		get_log/2,	 		  
		seed_on_farm/2,      
		get_on_farm/2,	         
		get_on_farm_one_key/2, 
		get_sell_limit/1,
		use_celerate/2,  	  
		farm_reclamation/2,  
		farm_exit/2,		         
		sell_goods/2, 
		update_farm_by_id/3,
		is_mature_status/1,
		judge_player_status/1, 
		get_seed_info/1, 
		get_farm_by_id/2,  
		get_db_farm_info_list/1, 
		get_reclaim_farm_num/1
	]
).

-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").




-define(FARM_COUNT, 9).%%农田块数
-define(FARM_COUNT_RESERVED, 3).%%预留的农田块数
-define(FARM_COUNT_LV30, 3).%%LV30农田块数
-define(FARM_COUNT_LV40, 4).%%LV40农田块数
-define(FARM_COUNT_LV45, 5).%%LV45农田块数
-define(FARM_COUNT_LV50, 6).%%LV50农田块数
-define(FARM_COUNT_LV55, 7).%%LV55农田块数
-define(FARM_COUNT_MONEY, 2).%%元宝农田块数

-define(FARM_DEV_GOLD_8, 150).%%需要用多少元宝才可以开垦第8块农田
-define(FARM_DEV_GOLD_9, 300).%%需要用多少元宝才可以开垦第9块农田
-define(FARM_DEV_MONEY_4, 25000).%%需要用多少铜币才可以开垦第4块农田
-define(FARM_DEV_MONEY_5, 35000).%%需要用多少铜币才可以开垦第5块农田
-define(FARM_DEV_MONEY_6, 42000).%%需要用多少铜币才可以开垦第6块农田
-define(FARM_DEV_MONEY_7, 50000).%%需要用多少铜币才可以开垦第7块农田

-define(FARM_LV30, 30).%%LV30农田块数
-define(FARM_LV40, 40).%%LV40农田块数
-define(FARM_LV45, 45).%%LV45农田块数
-define(FARM_LV50, 50).%%LV50农田块数
-define(FARM_LV55, 55).%%LV55农田块数

-define(MOD_SUCCESS, 1).%%成功的过程
-define(MOD_FAIL, 0).%%失败的过程

-define(SEED_SEEDED, 1).%%种子播种状态
-define(SEED_GROW, 2).%%种子成长状态
-define(SEED_MATURE, 3).%%种子收获状态


-define(SEED_MONEY, 29001).%%摇钱树种子种子
-define(SEED_PEACH, 29002).%%仙桃种子
-define(CELERATE, 29101).%%加速器

-define(FARM_TYPE, 81).%%农场物品的Type
-define(SEED_SUBTYPE, 10).%%种子的subType
-define(CELE_SUBTYPE, 11).%%加速器的subType

-define(MAX_STEAL_TIMES, 40).%%每天最大可以偷取的次数
-define(MAX_STEAL_PERCENT, 0.7).%%最多可偷取剩余的百分比 
%%-define(MAX_CELERATE_TIMES, 3).%%每块田最多可以使用加速器的次数
%%-define(CELERATE_RESULT, 1).%%每个加速器可以减少的时间


%%==================================业务逻辑模块=======================================================
  
%%判断能不能进农场
%%协议号42000
send_manor_apply(PlayerStatus, Master_Id, Type) ->
	if
		PlayerStatus#player.id =/= Master_Id ->
				%%Lv = get_relat_lv(PlayerStatus, Master_Id),
				Lv = db_agent:get_player_properties(lv,Master_Id),
				if					
					Lv >= ?FARM_LV30 ->
						case abs(tool:to_integer(PlayerStatus#player.lv) - tool:to_integer(Lv)) > 15 of %%等级相差
							true ->
								[15,0];
							_ ->
								%%判断是否在好友列表中
								if Type == 1 ->
									   case judge_in_friend_list(PlayerStatus#player.id, Master_Id) of 
										   true ->
											   get_canin_manor(PlayerStatus, Master_Id);
										   _ ->
											   [14,0]
									   end;
								   %%判断是否在氏族成员列表中
								   Type == 2 ->
									   get_canin_manor(PlayerStatus, Master_Id);
								   true ->
									    [14,0]
								end
						end;
					true ->
						[1,0]					
				end;
		true ->
				 get_canin_manor(PlayerStatus, Master_Id)
	end.

%%取场景信息
%%协议号42010
get_manor_state(PlayerStatus, _ ) ->
	Target_User_Id = get_target_user(PlayerStatus),
	Target=[get_42010_pack(get_farm_info(PlayerStatus, 1)),
			get_42010_pack(get_farm_info(PlayerStatus, 2)),
			get_42010_pack(get_farm_info(PlayerStatus, 3)),
			get_42010_pack(get_farm_info(PlayerStatus, 4)),
			get_42010_pack(get_farm_info(PlayerStatus, 5)),
			get_42010_pack(get_farm_info(PlayerStatus, 6)),
			get_42010_pack(get_farm_info(PlayerStatus, 7)),
			get_42010_pack(get_farm_info(PlayerStatus, 8)),
			get_42010_pack(get_farm_info(PlayerStatus, 9)),
			get_42010_pack(get_farm_info(PlayerStatus, 10)),
			get_42010_pack(get_farm_info(PlayerStatus, 11)),
			get_42010_pack(get_farm_info(PlayerStatus, 12))],
	{Target, Target_User_Id}.

%% 取土地信息
%% 协议号：42011
get_farm_info(PlayerStatus, Farm_Id) ->	
	%%判断是否有效提交
	Target_User_Id = get_target_user(PlayerStatus),
	if
		Target_User_Id =:= [] -> %%在内存登录表ets_manor_enter中找不到该用户，是一个无效的提交
			[Farm_Id, 99, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]; %%异常
		Target_User_Id =:= PlayerStatus#player.id -> %%进入自己的农场
			case Farm_Id > (?FARM_COUNT_RESERVED+?FARM_COUNT) of %%判断需要查找的田地是否大于整个场景的土地
				true ->
					[Farm_Id, 99, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]; %%错误
				_ ->
					case Farm_Id > ?FARM_COUNT of %%判断需要查找的田地是否大于整个可开垦的土地(大于9)
						true ->
							[Farm_Id, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]; %%荒地
						_ ->
							Farm_Info_Mem = get_farm_info_mem(PlayerStatus,Farm_Id, PlayerStatus#player.id, Target_User_Id),
							if	
								Farm_Info_Mem =:= [] ->
									[Farm_Id, 99, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]; %%异常
								true ->
									Farm_Info_Mem
							end
					end
			end;
		true ->%%进入别人的农场
			get_farm_info_mem(PlayerStatus,Farm_Id, Target_User_Id, Target_User_Id)
	end.

%% 查看种子信息
%% 协议号：42012
get_good_info(PlayerStatus, _ ) ->
	%%判断是否有效提交
	Target_User_Id = get_target_user(PlayerStatus),
	if
		Target_User_Id =:= [] -> %%在内存登录表ets_manor_enter中找不到该用户，是一个无效的提交
			[];
		Target_User_Id =:= PlayerStatus#player.id ->
			MS = ets:fun2ms(fun(T) when T#ets_base_goods.type == ?FARM_TYPE andalso T#ets_base_goods.subtype == ?SEED_SUBTYPE ->
								T
							end),
			Base_Goods_List = ets:select(?ETS_BASE_GOODS, MS),
		
			Seed_list = lists:delete({}, get_good_info_loop(PlayerStatus, Base_Goods_List, [{}])),
			if
				length(Seed_list) =:= 0 ->
					[];
				true ->
					Seed_list
			end;
			%%Seed_Money=get_good_info_count(PlayerStatus,?SEED_MONEY),
			%%Seed_Peach=get_good_info_count(PlayerStatus,?SEED_PEACH),
			%%if
			%%	Seed_Money =/= 0 andalso Seed_Peach=/=0 ->
			%%		[{?SEED_MONEY,Seed_Money},{?SEED_PEACH,Seed_Peach}];
			%%	Seed_Money =/= 0 ->
			%%		[{?SEED_MONEY,Seed_Money}];
			%%	Seed_Peach=/=0 ->
			%%		[{?SEED_PEACH,Seed_Peach}];
			%%	true ->
			%%		[]
			%%end;
		true ->
			[]
	end.
	
%% 查看加速器信息
%% 协议号：42013
get_celerate_info(PlayerStatus, _) ->
	%%判断是否有效提交
	Target_User_Id = get_target_user(PlayerStatus),
	if
		Target_User_Id =:= [] -> %%在内存登录表ets_manor_enter中找不到该用户，是一个无效的提交
			99;
		Target_User_Id =:= PlayerStatus#player.id ->
			%%到内存表查找
			MS = ets:fun2ms(fun(T) when T#goods.player_id == PlayerStatus#player.id andalso T#goods.goods_id == ?CELERATE andalso T#goods.location == 4 ->
					T
			end),
			Seed_money_list = ets:select(?ETS_GOODS_ONLINE,MS),
			case length(Seed_money_list) > 0 of
				true ->
					1; %%有加速器
				_ ->
					2  %%无加速器
			end;
		true ->
			99
	end.

%%取好友列表
%% 协议号：42014
get_friends_lists(PlayerStatus, [] ) ->
	L= get_ets_rela_record(PlayerStatus#player.id),		%% 获取好友列表
    L1 = [pack_friend_list(X)||X <- L],
	L2 = lists:delete([], L1),
	%%根据等级倒序排序
	L2_Sort = lists:sort(fun({_, _, _, Lv1, _},{_, _, _, Lv2, _}) ->
						  Lv1 >= Lv2 
				   end ,
				   L2),
	L2_Sort.

%% 获取今日可偷次数
%% 协议号：42015
get_steal_remain_times(Player_Id) ->
	%%Now=util:unixtime(),
	Today = get_today_time(),
	MS = ets:fun2ms(fun(T) when T#ets_manor_steal.player_id == Player_Id andalso T#ets_manor_steal.steal_time >= Today andalso T#ets_manor_steal.actions == 2->
						T
						end),
	Steal_List =ets:select(?ETS_MANOR_STEAL, MS),
	Steal_Count = length(Steal_List),

	%%MS1 = ets:fun2ms(fun(T1) when T1#ets_manor_steal.player_id == Player_Id 
	%%					 andalso T1#ets_manor_steal.steal_time < (Now-24*3600) 
	%%					 andalso T1#ets_manor_steal.read ==1 ->
	%%					T1
	%%					end),
	%%Steal_Old_List=ets:select(?ETS_MANOR_STEAL, MS1),
	%%lists:foreach(fun(T1) ->
	%%							if
	%%								is_record(T1,ets_manor_steal)->
	%%									ets:delete(ets_manor_steal, T1#ets_manor_steal.steal_id);
	%%								true ->%%异常错误
	%%									[]
	%%							end
	%%						end,
	%%						Steal_Old_List),
	
	
	Remain_Times=?MAX_STEAL_TIMES-Steal_Count,
	Remain_Times.

%% 获取今日出售数量
get_steal_sell_num(Player_Id) ->
	Today = get_today_time(),
	MS = ets:fun2ms(fun(T) when T#ets_manor_steal.player_id == Player_Id andalso T#ets_manor_steal.steal_time >= Today andalso T#ets_manor_steal.actions == 3->
						T
						end),
	Steal_List =ets:select(?ETS_MANOR_STEAL, MS),
	F = fun(X,[BcoinNum,CoinNum]) ->
				if
					is_record(X,ets_manor_steal) ->
						IsBcoin =  lists:member(X#ets_manor_steal.sgoodsid, [29201,29202,29203]),
						IsCoin =  lists:member(X#ets_manor_steal.sgoodsid, [29204,29205,29206]),
						if IsBcoin ->
								[X#ets_manor_steal.count + BcoinNum,CoinNum];
							IsCoin-> 
								[BcoinNum,X#ets_manor_steal.count + CoinNum];
						   true ->
							   [BcoinNum,CoinNum]
						end;						
					true ->
						[BcoinNum,CoinNum]
				end
		end,					
   Steal_List1 = [Ets_manor || Ets_manor <- Steal_List,lists:member(Ets_manor#ets_manor_steal.sgoodsid, [29201,29202,29203,29204,29205,29206])],
   [BcoinTotalNum,CoinTotalNum] = lists:foldl(F, [0,0], Steal_List1),
   [BcoinTotalNum,CoinTotalNum].

%%获取LOG
%%协议号：42016
get_log(PlayerStatus, _ ) ->
	%%MS = ets:fun2ms(fun(T) when T#ets_manor_steal.player_id == PlayerStatus#player.id andalso T#ets_manor_steal.read ==1  ->
	MS = ets:fun2ms(fun(T) when T#ets_manor_steal.player_id == PlayerStatus#player.id  ->
						T
						end),
	Log_Info_List=ets:select(?ETS_MANOR_STEAL, MS),
	%%修改数据库和内存
	lists:foreach(fun(Manor_Steal) ->
								%%Manor_Steal_Info = list_to_tuple([ets_manor_steal] ++ Manor_Steal),
								New_Manor_Steal_Info=Manor_Steal#ets_manor_steal{read = 2},
                				ets:insert(?ETS_MANOR_STEAL, New_Manor_Steal_Info)
							end,
							Log_Info_List),
	db_agent:update_farm_info(log_manor_steal,
									[{read,2}],
									[{player_id,PlayerStatus#player.id}]),
	
	if
		length(Log_Info_List) =:= 0 ->
			[];
		true ->
			
			%%根据steal_time倒序排序
			Log_Info_List_Sort = lists:sort(fun({_,_,_,Y1,_,_,_,_,_,_,_},{_,_,_,Y2,_,_,_,_,_,_,_}) ->
								  Y1 >= Y2 
						   end ,
						   Log_Info_List),
			%%返回前20条
			Log_info=lists:sublist(lists:delete({}, Log_Info_List_Sort),1,20),
			Log_info
	end.

%% 获取本人庄园是否有东西成熟
%% 协议号：42017
get_mature_status(PlayerStatus, _ ) ->
	Farm_Info_list = get_db_farm_info_list(PlayerStatus#player.id),
	if
		length(Farm_Info_list) > 0 ->
			Farm_Info = lists:nth(1, Farm_Info_list),
			Remain_time = get_mature_status_loop(PlayerStatus, Farm_Info, 1, 0),			
			if
				Remain_time =:= 1 ->
					misc:cancel_timer(farm_mature_status_timer),
					Farm_mature_status_timer = erlang:send_after(Remain_time * 1000, self(), 'FARM_MATURE_STATUS'),
					put(farm_mature_status_timer, Farm_mature_status_timer),
					1;
				Remain_time =/= 0 ->
					misc:cancel_timer(farm_mature_status_timer),
					Farm_mature_status_timer = erlang:send_after(Remain_time * 1000, self(), 'FARM_MATURE_STATUS'),
					put(farm_mature_status_timer, Farm_mature_status_timer),
					2;
				true ->
					2
			end;
		true ->
			2
	end.



%% 播种
%% 协议号：42020
seed_on_farm(PlayerStatus, [Farm_Id, Seed_Id]) ->
	%%判断是否有效提交
	Target_User_Id = get_target_user(PlayerStatus),
	if
		Target_User_Id =:= [] -> %%在内存登录表ets_manor_enter中找不到该用户，是一个无效的提交
			[99,0]; %%异常
		Target_User_Id =:= PlayerStatus#player.id -> 
			Farm_Info_list = get_db_farm_info_list(Target_User_Id),
			
			if
				length(Farm_Info_list) > 0 ->
					Farm_Info = lists:nth(1, Farm_Info_list),
					Farm = get_farm_by_id(Farm_Id, Farm_Info),
					[Fstate, Sgoodsid, _Sstate, _Plant, _Grow, Fruit, _Celerate] = Farm,
					if 
						Fstate==0 ->
							[1,0]; %%土地不存在
						Fstate==1 ->
							[2,0]; %%荒地
						Fstate==2 andalso Sgoodsid==0 ->
							Stat_Code=gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'delete_more', Seed_Id, 1}),
							if
								Stat_Code =:= 1 ->
									Seed_lv = get_seed_lv_by_sgoodsid(Seed_Id),%%取种子lv
									if 
										Seed_Id == 29005 ->
											Seed_lv1 = 32;
										true ->
											Seed_lv1 = Seed_lv 
									end,
									if
										PlayerStatus#player.lv >= Seed_lv1 -> %%判断播种者的等级是否可以种植该种子										
											%%修改内存和数据库
											write_log(insert,
												  	get_id_key(),
													PlayerStatus#player.id, util:unixtime(), 6, PlayerStatus#player.id, PlayerStatus#player.nickname, Farm_Id,
													Sgoodsid, Fruit, 2),
											Now=util:unixtime(),
											%%update_farm_by_id(PlayerStatus#player.id, Farm_Id, util:term_to_string([2, 292220, 2, 2, 2, 2, 2])),
											update_farm_by_id(PlayerStatus#player.id, Farm_Id, [Fstate, Seed_Id, ?SEED_SEEDED, Now, 1, 0, 0]),
											
											%%广播消息
											send_fram_status_when_change(PlayerStatus, Farm_Id),
											get_mature_status(PlayerStatus, []),
											[0,0]; %%成功
										true ->
											[7,Seed_lv1]
									end;
								true ->
									[6,0] %%没有种子了
							end;
						Fstate==2 andalso Sgoodsid=/=0 ->
							[5,0]; %%土地上已有作物
						Fstate==3 ->
							[3,0]; %%需要铜币开垦
						Fstate==4 ->
							[4,0]; %%需要元宝开垦
						true ->
							[1,0] %%土地不存在
					end;
				true -> %%异常
					[99,0]
			end;
		true ->
			[99,0]
	end.

%%收获（偷菜）
%%协议号：42021
get_on_farm(PlayerStatus, Farm_Id) ->
	%%判断是否有效提交
	Target_User_Id = get_target_user(PlayerStatus),
	Max_celerate_time = get_cele_time_by_celeid(?CELERATE),
%% 	Max_celerate_count = get_cele_count_by_celeid(?CELERATE),
	if
		Target_User_Id =:= [] -> %%在内存登录表ets_manor_enter中找不到该用户，是一个无效的提交
			[99,0,0,0,0];
		true ->
			Farm_Info_list = get_db_farm_info_list(Target_User_Id),
			if
				length(Farm_Info_list) > 0 ->
					Farm_Info = lists:nth(1, Farm_Info_list),
					Farm = get_farm_by_id(Farm_Id, Farm_Info),
					[Fstate, Sgoodsid, Sstate, Plant, Grow, Fruit, Celerate] = Farm,
					if 
						Fstate==0 ->
							[1,0,0,0,0]; %%土地不存在
						Fstate==1 ->
							[2,0,0,0,0]; %%荒地
						Fstate==2 andalso Sgoodsid=/=0 ->
							Seed_Info = get_seed_info(Sgoodsid), %%取种子信息
							if
								Seed_Info =:= [] -> %%异常
									[99,0,0,0,0];
								true ->
									%%other_data
									[ _ , _ , { _ , Grow_Time, Max_Fruit, _, _ }] = Seed_Info,
									Now_Time = util:unixtime(),
									if
										(Now_Time + Celerate*Max_celerate_time*3600) >= Plant+ Grow_Time*3600  ->	%%可收获，现在的时间大于种植时间+成长时间
										%%Now_Time > (Farm_Info#ets_farm_info.plant+ Grow_Time*3600 + Farm_Info#ets_farm_info.celerate*Max_celerate_time*3600) ->	%%可收获，现在的时间大于种植时间+成长时间
											if
												Fruit =:= 0 -> %%成熟期并且果实数目为0
													if
														Grow =/= Grow_Time*3600 -> %%如果原来处于成长状态，则将该记录改为成熟状态(可以收获)
															%%update_farm_by_id(Target_User_Id, Farm_Id, [Fstate, Sgoodsid, ?SEED_MATURE, Plant, Plant+Grow_Time*3600, Max_Fruit, Celerate]),
															if
																Target_User_Id =:= PlayerStatus#player.id ->
																	%%自己的农场
																	write_log(insert,
																		  	get_id_key(),
																		  	PlayerStatus#player.id, Now_Time, 1, PlayerStatus#player.id, PlayerStatus#player.nickname, Farm_Id,
																	 		get_fruit_by_sgoodsid(Sgoodsid), Max_Fruit, 1),
																	pick_fruit(PlayerStatus,Target_User_Id, Farm_Id, [Fstate, Sgoodsid, Sstate, Plant, Grow, Max_Fruit, Celerate], Max_Fruit,Max_Fruit);
																true ->
																	%%不是自己的农场
																	Pick_Count1 = get_random_count(),
																	Min_Fruit = tool:ceil(Max_Fruit * ?MAX_STEAL_PERCENT),
																	if
																		(Max_Fruit-Pick_Count1)/Max_Fruit < ?MAX_STEAL_PERCENT ->
																			if
																				Max_Fruit > Min_Fruit ->
																					Pick_Count = Max_Fruit - Min_Fruit;
																				true ->
																					Pick_Count = 0
																			end;
																		(Max_Fruit-Pick_Count1)/Max_Fruit >= ?MAX_STEAL_PERCENT ->
																			Pick_Count = Pick_Count1;																
																		true ->
																			Pick_Count = 0
																	end,
																	if
																		Pick_Count =/= 0 ->
																			case (Max_Fruit-Pick_Count)/Max_Fruit >= ?MAX_STEAL_PERCENT of
																				true ->
																					Steal_status = judge_steal_this_farm(PlayerStatus#player.id, Target_User_Id, Farm_Id,1 ),%%判断是否超过可偷次数
																					if
																						Steal_status =:= 0 ->
																							Steal_status1 = judge_steal_this_farm(PlayerStatus#player.id, Target_User_Id, Farm_Id , 2),%%判断是否对该田进行偷取 
																							if
																								Steal_status1 =:= 0 ->
																									write_log(insert,
																								  			get_id_key(),
																										  	PlayerStatus#player.id, Now_Time, 2, Target_User_Id, get_relation_name_by_id(PlayerStatus#player.id,Target_User_Id), Farm_Id,
																									 		get_fruit_by_sgoodsid(Sgoodsid), Pick_Count, 1),
																									write_log(insert,
																										  	get_id_key(),
																										  	Target_User_Id, Now_Time, 5, PlayerStatus#player.id, PlayerStatus#player.nickname, Farm_Id,
																									 		get_fruit_by_sgoodsid(Sgoodsid), Pick_Count, 1),
																									%%发送今日可偷次数
%% 																									Data = lib_manor:get_steal_remain_times(PlayerStatus#player.id),	
%% 																									{ok, BinData} = pt_42:write(42015, Data),
%% 																									lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
																									pick_fruit(PlayerStatus,Target_User_Id, Farm_Id,Farm, Max_Fruit,Pick_Count);
																								true ->
																									[Steal_status1,0,0,0,0]
																							end;
																						true ->
																							[Steal_status,0,0,0,0]
																					end;
																				_ ->
																					[8,0,0,0,0] %%超过摘取的数量
																			end;
																		true ->
																			[10,0,0,0,0] %%不可以摘取
																	end																		
															end;
														true -> %%原来处于成熟状态 && 果实为0 &&生长时间相同 ，则将该田地修改为已开垦状态
															pick_fruit(PlayerStatus,Target_User_Id, Farm_Id,Farm, 0,get_random_count()) %%无果可摘，直接改为开垦状态
													end;
												true -> %%成熟期并且果实数目不为0，(可以收获)
													if
														Target_User_Id =:= PlayerStatus#player.id ->
															%%自己的农场
															write_log(insert,
																  	get_id_key(),
																  	PlayerStatus#player.id, Now_Time, 1, PlayerStatus#player.id, PlayerStatus#player.nickname, Farm_Id,
															 		get_fruit_by_sgoodsid(Sgoodsid), Fruit, 1),
															%%添加成就的记录触发事件
															lib_achieve:check_achieve_finish(PlayerStatus#player.other#player_other.pid_send, PlayerStatus#player.id, 619, [1]),
															%%活动三：勤劳致富
															lib_act_interf:manor_event_award(PlayerStatus),
															pick_fruit(PlayerStatus, Target_User_Id,Farm_Id,Farm, Fruit,Fruit);
														true ->
															
															%%不是自己的农场
															Pick_Count1 = get_random_count(),
															Min_Fruit = tool:ceil(Max_Fruit * ?MAX_STEAL_PERCENT),
															if
																(Fruit-Pick_Count1)/Max_Fruit < ?MAX_STEAL_PERCENT ->
																	if
																		Fruit > Min_Fruit ->
																			Pick_Count = Fruit - Min_Fruit;
																		true ->
																			Pick_Count = 0
																	end;
																(Fruit-Pick_Count1)/Max_Fruit >= ?MAX_STEAL_PERCENT ->
																	Pick_Count = Pick_Count1;																
																true ->
																	Pick_Count = 0
															end,
															
															if
																Pick_Count =/= 0 ->
																	case (Fruit-Pick_Count)/Max_Fruit >= ?MAX_STEAL_PERCENT of
																		true ->
																			Steal_status = judge_steal_this_farm(PlayerStatus#player.id, Target_User_Id, Farm_Id , 1),%%判断是否超过可偷次数
																			if
																				Steal_status =:= 0 ->
																					Steal_status1 = judge_steal_this_farm(PlayerStatus#player.id, Target_User_Id, Farm_Id , 2),%%判断是否对该田进行偷取
																					if
																						Steal_status1 =:= 0 ->
																							write_log(insert,
																						  			get_id_key(),
																								  	PlayerStatus#player.id, Now_Time, 2, Target_User_Id, get_relation_name_by_id(PlayerStatus#player.id,Target_User_Id), Farm_Id,
																							 		get_fruit_by_sgoodsid(Sgoodsid), Pick_Count, 1),
																							write_log(insert,
																								  	get_id_key(),
																								  	Target_User_Id, Now_Time, 5, PlayerStatus#player.id, PlayerStatus#player.nickname, Farm_Id,
																							 		get_fruit_by_sgoodsid(Sgoodsid), Pick_Count, 1),
%% 																						%%发送今日可偷次数
%% 																						Data = lib_manor:get_steal_remain_times(PlayerStatus#player.id),	
%% 																						{ok, BinData} = pt_42:write(42015, Data),
%% 																						lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
 																							%%添加成就的记录触发事件
																							lib_achieve:check_achieve_finish(PlayerStatus#player.other#player_other.pid_send, PlayerStatus#player.id, 621, [1]),
																							%%偷果实增加亲密度
																							case lib_relationship:find_is_exists(PlayerStatus#player.id, Target_User_Id, 1) of
																								{_Id, true} ->																									
																									TaTeamId =
																										case lib_player:get_online_info_fields(Target_User_Id,[other]) of
																											[] ->
%% 																												?DEBUG("lib_manor_________Other undefined PlayerId = ~p_____________",[Target_User_Id]),
																												undefined;
																											[Other] -> Other#player_other.pid_team
																										end,
																									spawn(fun()->lib_relationship:close(manor,PlayerStatus#player.id,Target_User_Id,[Pick_Count,PlayerStatus#player.other#player_other.pid_team,TaTeamId])end);
																								{ok, false} -> skip
																							end,
																							pick_fruit(PlayerStatus,Target_User_Id, Farm_Id,Farm, Fruit,Pick_Count);
																						true ->
																							[Steal_status1,0,0,0,0]
																					end;
																				true ->
																					[Steal_status,0,0,0,0]
																			end;
																		_ ->
																			[8,0,0,0,0] %%超过摘取的数量
																	end;
																true ->
																	[10,0,0,0,0] %%不可以摘取
															end
													end
											end;
										true ->
											[5,0,0,0,0] %%作物尚未成熟
									end
							end;
						Fstate==3 ->
							[3,0,0,0,0]; %%需要铜币开垦
						Fstate==4 ->
							[3,0,0,0,0]; %%需要元宝开垦
						Fstate==2 andalso Sgoodsid==0 ->
							[4,0,0,0,0]; %%无作物
						true ->
							[1,0,0,0,0] %%土地不存在
					end;
				true -> %%异常
					[99,0,0,0,0]
			end
	end.

%%一键收获（偷菜）
%%协议号42022
get_on_farm_one_key(PlayerStatus, _ ) ->
	%%判断是否有效提交
	Target_User_Id = get_target_user(PlayerStatus),
	if
		Target_User_Id =:= PlayerStatus#player.id ->
			if
				PlayerStatus#player.vip =:= 0 ->
					1;
				true ->
					get_all_farm_fruit(PlayerStatus, 1, 0),
					0
			end;
		true ->
			[]
	end.

%% 使用加速器
%% 协议号：42023
use_celerate(PlayerStatus, Farm_Id) ->
	%%判断是否有效提交
	Target_User_Id = get_target_user(PlayerStatus),
	Max_celerate_time = get_cele_time_by_celeid(?CELERATE),
	Max_celerate_count = get_cele_count_by_celeid(?CELERATE),
	
	if
		Target_User_Id =:= [] -> %%在内存登录表ets_manor_enter中找不到该用户，是一个无效的提交
			[Farm_Id,99];
		true ->
			Farm_Info_list = get_db_farm_info_list(PlayerStatus#player.id),
			if
				length(Farm_Info_list) > 0 ->
					Farm_Info = lists:nth(1, Farm_Info_list),
					Farm = get_farm_by_id(Farm_Id, Farm_Info),
					[Fstate, Sgoodsid, Sstate, Plant, Grow, Fruit, Celerate] = Farm,
					if
						Fstate =:= 2 -> %%已开垦
							if
								Sgoodsid =/=0 -> %%有作物
									Seed_Info = get_seed_info(Sgoodsid), %%取种子信息
									if 
										Seed_Info =:= [] -> %%异常
											[Farm_Id,99];
										true ->
											%%other_data
											[ _ , _ , { _ , Grow_Time, Max_Fruit, _, _ }] = Seed_Info,
											if
												Grow ==Plant+Grow_Time*3600 -> %%作物已成熟
													[Farm_Id,2,0];
												true ->
													Celerate_Can_Use=get_celerate_info(PlayerStatus, []),
													if
														Celerate_Can_Use==1 -> %%有加速器剩余，可以使用加速器,OK
															if
																Celerate < Max_celerate_count ->
																	Now=util:unixtime(),
																	case (Now + Max_celerate_time*3600 + Celerate*Max_celerate_time*3600) >= Plant+ Grow_Time*3600 of
																	%%case ((Now+Max_celerate_time*3600)-Farm_Info#ets_farm_info.plant)+Farm_Info#ets_farm_info.celerate*Max_celerate_time*3600>Grow_Time*3600 of 
																		true ->%%使用后成熟
																			%%修改内存数据库
																			%%fram_state_to_mature(Farm_Info, Grow_Time, Max_Fruit),
																			update_farm_by_id(PlayerStatus#player.id, Farm_Id, [Fstate, Sgoodsid, ?SEED_MATURE, Plant, Plant+Grow_Time*3600, Max_Fruit, Celerate+1]),
																			%%写log表
																			write_log(insert,
						  															get_id_key(),
																					PlayerStatus#player.id, util:unixtime(), 7, PlayerStatus#player.id, PlayerStatus#player.nickname, Farm_Id,
																					?CELERATE, 1, 1),
																			%%db_agent:insert_farm_info(manor_steal, 
																			%%				 [pid, fid, goodsid, utime], 
																			%%					[PlayerStatus#player.id, Farm_Info#ets_farm_info.fid, ?CELERATE, Now]),
																			%%调用mod_goods物品-1
																			gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'delete_more', ?CELERATE, 1}),
																			%%广播消息
																			send_fram_status_when_change(PlayerStatus, Farm_Id),
																			get_mature_status(PlayerStatus, []),
																			[Farm_Id,0,get_cele_time_by_celeid(?CELERATE)];
																		_ ->%%使用后没成熟
																			%%修改内存数据库
																			%%fram_state_change_celerate(Farm_Info),
																			update_farm_by_id(PlayerStatus#player.id, Farm_Id, [Fstate, Sgoodsid, Sstate, Plant, Grow, Fruit, Celerate+1]),
																			%%写log表
																			write_log(insert,
						  															get_id_key(),
																					PlayerStatus#player.id, util:unixtime(), 7, PlayerStatus#player.id, PlayerStatus#player.nickname, Farm_Id,
																					?CELERATE, 1, 1),
																			%%write_log(Optype,Steal_id, Player_id, Steal_time, Actions, Pid, Nickname, Fid, Sgoodsid, Count, Read) 
																			%%db_agent:insert_farm_info(manor_steal, 
																			%%				 [pid, fid, goodsid, utime], 
																			%%					[PlayerStatus#player.id, Farm_Info#ets_farm_info.fid, ?CELERATE, Now]),
																			%%调用mod_goods物品-1
																			gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'delete_more', ?CELERATE, 1}),
																			%%广播消息
																			send_fram_status_when_change(PlayerStatus, Farm_Id),
																			get_mature_status(PlayerStatus, []),
																			[Farm_Id,0,get_cele_time_by_celeid(?CELERATE)]
																	end;
																true ->%%超过了该块田可以使用的加速器次数
																	[Farm_Id,3,0]
															end;
														true ->%%没有加速器了
															[Farm_Id,4,0]
													end
											end
									end;
									true ->
										[Farm_Id,1,0] %%作物不存在
							end;
						true ->%%其他状态，返回错误
							[Farm_Id,1,0] %%作物不存在
					end
			end
	end.

%% 土地开垦
%% 协议号：42024
farm_reclamation(PlayerStatus, Farm_Id) ->
	%%判断是否有效提交
	Target_User_Id = get_target_user(PlayerStatus),
	if
		Target_User_Id =:= [] -> %%在内存登录表ets_manor_enter中找不到该用户，是一个无效的提交
			[Farm_Id, 99];
		true ->
			Reclamationed=judge_fram_reclamationed(PlayerStatus, Farm_Id),
			if
				Reclamationed=:= reclamationed ->%%土地已开垦
					[Farm_Id,5];
				Farm_Id > 9 andalso Farm_Id =< 12 -> %%荒地
					[Farm_Id, 1];%%不支持开垦
				Farm_Id > 7 andalso Farm_Id =< 9 -> %%需要元宝开垦
					Need_Gold = get_gold_by_farmid(Farm_Id),
					Gold_status = goods_util:is_enough_money(PlayerStatus, Need_Gold, gold),
					if
						Gold_status =:= false ->
						%%PlayerStatus#player.gold < Need_Gold ->
							[Farm_Id, 4];
						true ->
							if
								Farm_Id =:= 8 ->
									farm_reclamation_opration(PlayerStatus, 8);
								Farm_Id =:= 9 ->
									farm_reclamation_judge(PlayerStatus, Farm_Id, 9);
								true ->
									[Farm_Id,99] %%异常
							end
					end;
				Farm_Id > 3 andalso Farm_Id =< 7 -> %%需要铜钱开垦
					Need_Gold = get_dev_mon_by_farmid(Farm_Id),
					Coin_status = goods_util:is_enough_money(PlayerStatus, Need_Gold, coinonly),
					if
						Coin_status =:= false ->
						%%PlayerStatus#player.coin < Need_Gold ->
							[Farm_Id, 3];
						true ->
							if
								PlayerStatus#player.lv >= ?FARM_LV55 ->
									farm_reclamation_judge(PlayerStatus, Farm_Id, ?FARM_COUNT_LV55);
									%%lib_goods:cost_money(PlayerStatus, Cost, coin, 4202)
								PlayerStatus#player.lv >= ?FARM_LV50 ->
									farm_reclamation_judge(PlayerStatus, Farm_Id, ?FARM_COUNT_LV50);
								PlayerStatus#player.lv >= ?FARM_LV45 ->
									farm_reclamation_judge(PlayerStatus, Farm_Id, ?FARM_COUNT_LV45);
								PlayerStatus#player.lv >= ?FARM_LV40 ->
									farm_reclamation_judge(PlayerStatus, Farm_Id, ?FARM_COUNT_LV40);
								PlayerStatus#player.lv >= ?FARM_LV30 ->
									farm_reclamation_judge(PlayerStatus, Farm_Id, ?FARM_COUNT_LV30);
									%%farm_reclamation_opration(PlayerStatus, Farm_Id);
								true ->
									[Farm_Id, 99] %%异常
							end
					end;
				true ->
					[Farm_Id, 99]%%异常
			end
	end.

%%退出
%%协议号42025
farm_exit(PlayerStatus, _ ) ->
	List_Farm_Info = get_db_farm_info_list(PlayerStatus#player.id),
	if
		length(List_Farm_Info) > 0 ->
			Farm_Info= lists:nth(1, List_Farm_Info),
			P_status = get_db_p_status(Farm_Info),
			%%改变自己的状态
			db_agent:update_farm_info(farm, 
					  [{p_status,PlayerStatus#player.id}],
					  [{player_id,PlayerStatus#player.id}]),
			%%改变对方的状态
			List_Farm_Info1 = get_db_farm_info_list(P_status),
			if
				length(List_Farm_Info1) > 0 ->
					Farm_Info1= lists:nth(1, List_Farm_Info1),
					New_Client = list_to_tuple(lists:delete(PlayerStatus#player.id, get_db_client(Farm_Info1))),
					db_agent:update_farm_info(farm, 
							  [{client,util:term_to_string(New_Client)}],
					  		  [{player_id,P_status}]);
				true ->
					ok
			end,
			%%清除是否有作物成熟状态
			{ok, BinData} = pt_42:write(42017, 2),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
			%%删除内存表
			ets:match_delete(?ETS_MANOR_STEAL, #ets_manor_steal{player_id=PlayerStatus#player.id, _='_' }),
			%%清除定时器
			%%misc:cancel_timer(farm_mature_status_timer),
			misc:cancel_timer(farm_status_timer);
		true ->
			ok
	end.

%%卖出
%%协议号42031
sell_goods(PlayerStatus, Goods_list) ->
	if 
		Goods_list =/= [] ->
			 Goods_Info_list= lists:sublist(Goods_list,1,1),
			 {GoodsId,GoodsNum}=hd(Goods_Info_list),
			 Can_sell=get_goods_sell_sell(GoodsId), %%判断是否可卖
			 if 
				 Can_sell =:= 0 ->
					IsBCoinTrade = lists:member(GoodsId, [29201,29202,29203]),
					IsCoinTrade = lists:member(GoodsId, [29204,29205,29206]),
					%%今天总绑定铜和交易铜出售数量
					[BcoinTotalNum,CoinTotalNum] = get_steal_sell_num(PlayerStatus#player.id),
					%%等级每天出售绑定铜和交易铜的限制
					[BcoinNum,CoinNum] = get_sell_limit(PlayerStatus#player.lv),
					if 
						IsBCoinTrade andalso ( GoodsNum + BcoinTotalNum > BcoinNum) ->
							{5,PlayerStatus};
						IsCoinTrade andalso (GoodsNum + CoinTotalNum > CoinNum) ->
							{6,PlayerStatus};
						true ->
							 	Stat_Code=sell_goods_in_warehouse(PlayerStatus,GoodsId,GoodsNum),
								if
									Stat_Code =:= 1 ->
										%%写log
										write_log(insert,
												  get_id_key(),	PlayerStatus#player.id, util:unixtime(), 3, PlayerStatus#player.id, PlayerStatus#player.nickname, 0,	GoodsId, GoodsNum, 1),
										Sell_type = get_goods_sell_type(GoodsId),
										if
											Sell_type =:= 1 -> %%铜币
												NewStatus = lib_goods:add_money(PlayerStatus, GoodsNum*get_goods_sell_price(GoodsId), coinonly, 4203);
											Sell_type =:= 4 -> %%绑定铜币
												NewStatus = lib_goods:add_money(PlayerStatus, GoodsNum*get_goods_sell_price(GoodsId), bcoin, 4203);
											true ->
												NewStatus = PlayerStatus %%错误
										end,		
										lib_activity:update_activity_data(farm, NewStatus#player.other#player_other.pid, NewStatus#player.id, GoodsNum),%%添加玩家活跃度统计
										%%氏族祝福任务判断
										GWParam = {19, GoodsNum},
										lib_gwish_interface:check_player_gwish(NewStatus#player.other#player_other.pid, GWParam),
										%%NewStatus = lib_goods:add_money(PlayerStatus, GoodsNum*get_goods_sell_price(GoodsId), bcoin, 4203),
										sell_goods(NewStatus,lists:sublist(Goods_list, 2, length(Goods_list)-1));
									true ->
										{Stat_Code,PlayerStatus}
								end
					end;				
				 true ->
					 {4,PlayerStatus}
			 end;
		true ->
			%%发送现在的金币情况							
			lib_player:send_player_attribute2(PlayerStatus,3),
			{1,PlayerStatus}
	end.

%%==================================私有模块=======================================================
%%循环读取9块土地，判断是否有作物成熟
get_mature_status_loop(PlayerStatus, Farm_Info, Farm_Id, Remain_time) ->
	if
		Farm_Id > 9 ->
		  Remain_time;
		true ->
			Remain_time1 = judge_mature_status(PlayerStatus, Farm_Info, Farm_Id, Remain_time),
			get_mature_status_loop(PlayerStatus,Farm_Info, Farm_Id+1, Remain_time1)
	end.	

%%判断某人是否有可以偷取的作物
is_mature_status(Player_id) ->
	Farm_Info_list = db_agent:select_form_info(Player_id),
	case Farm_Info_list == [] of
		true -> 0;
		_ ->
			ALLFarmList = [util:string_to_term(tool:to_list(FramInfo)) || FramInfo <- Farm_Info_list],
			is_mature_status_loop(ALLFarmList,0)
	end.

is_mature_status_loop([],Num) ->
	Num;
is_mature_status_loop([Farm | Rest_Farm_Info_list],Num) ->
	[Fstate, Sgoodsid, _Sstate, Plant, _Grow, Fruit, _Celerate] = Farm,
	if 
		Fstate == 2 andalso Sgoodsid >0 ->
			Now_Time = util:unixtime(),
			Seed_Info = get_seed_info(Sgoodsid),
			[ _ , _ , { _ , Grow_Time, Max_Fruit, _ , _ }] = Seed_Info,
			if
				Now_Time  >= Plant+ Grow_Time*3600 andalso Fruit >=  trunc(Max_Fruit*0.6) ->	%%可收获，现在的时间大于种植时间+成长时间
					1;
				true ->
					is_mature_status_loop(Rest_Farm_Info_list,Num)
			end;
		true ->
			is_mature_status_loop(Rest_Farm_Info_list,Num)
	end.

%%判断该土地是否有作物新成熟
judge_mature_status(PlayerStatus,Farm_Info, Farm_Id, Remain_time) ->
	Max_celerate_time = get_cele_time_by_celeid(?CELERATE),
	try
		Farm = get_farm_by_id(Farm_Id, Farm_Info),
		[Fstate, Sgoodsid, _Sstate, Plant, Grow, Fruit, Celerate] = Farm,
		if 
			Fstate =:= 0 ->	%%土地不存在
				get_remain_time(Remain_time,0);
			Fstate =:= 1 ->	%%荒地
				get_remain_time(Remain_time,0); 
			Fstate==2 andalso Sgoodsid==0 ->	%%土地已开垦，尚未种植
				get_remain_time(Remain_time,0);
			Fstate==2 andalso Sgoodsid=/=0 ->	%%土地上已有作物
				Seed_Info = get_seed_info(Sgoodsid), %%取种子信息
				if
					Seed_Info =:= [] -> %%异常
						get_remain_time(Remain_time,0);
					true ->
						%%other_data
						[ _ , _ , { _ , Grow_Time, Max_Fruit, _, _ }] = Seed_Info,
						Now_Time = util:unixtime(),
						if
							(Now_Time + Celerate*Max_celerate_time*3600) >= Plant+ Grow_Time*3600  ->	%%可收获，现在的时间大于种植时间+成长时间
								if
									Fruit =:= 0 -> %%成熟期并且果实数目为0
										if
											Grow =/= Grow_Time*3600 -> %%如果原来处于成长状态，则将该记录改为成熟状态(可以收获)
												update_farm_by_id(PlayerStatus#player.id, Farm_Id, [Fstate, Sgoodsid, ?SEED_MATURE, Plant, Plant+Grow_Time*3600, Max_Fruit, Celerate]),
												get_remain_time(Remain_time,1);
											true -> %%原来处于成熟状态 && 果实为0 &&生长时间相同 ，则将该田地修改为已开垦状态
												get_remain_time(Remain_time,0)
											end;
									true -> %%成熟期并且果实数目不为0，(可以收获)
										get_remain_time(Remain_time,0)
								end;
							true ->
								%%得到剩余时间
								Remain_time1 = (Plant+ Grow_Time*3600) - (Now_Time + Celerate*Max_celerate_time*3600),
								get_remain_time(Remain_time, Remain_time1)	%%作物尚未成熟, 返回剩余时间
						end
				end;															
			Fstate==3 ->	 %%需要铜币开垦
				get_remain_time(Remain_time,0);
			Fstate==4 ->	%%需要元宝开垦
				get_remain_time(Remain_time,0); 
			true ->	%%土地不存在
				get_remain_time(Remain_time,0) 
		end
	catch
		_ : _ ->
			get_remain_time(Remain_time,0)
	end.

get_remain_time(Remain_time, New_remain_time) ->
	if
		Remain_time =:= 0 ->
			New_remain_time;
		New_remain_time =:= 0 ->
			Remain_time;
		true ->
			if
				Remain_time < New_remain_time ->
					Remain_time;
				true ->
					New_remain_time
			end
	end.
			

%%循环得到物品的总数
get_good_info_loop(PlayerStatus, Base_Goods_List, Goods_Count) ->
	case length(Base_Goods_List) > 0 of
		true ->
			Goods = lists:nth(1, Base_Goods_List),
			if
				is_record(Goods,ets_base_goods) ->
					case get_seed_lv_by_sgoodsid(Goods#ets_base_goods.goods_id) =< PlayerStatus#player.lv of
						true ->
							Seed_Count = get_good_info_count(PlayerStatus, Goods#ets_base_goods.goods_id),
							if
								Seed_Count =/= 0 ->
									get_good_info_loop(PlayerStatus, lists:sublist(Base_Goods_List, 2, length(Base_Goods_List)-1), lists:append(Goods_Count,[{Goods#ets_base_goods.goods_id, Seed_Count}]));
								true ->
									get_good_info_loop(PlayerStatus, lists:sublist(Base_Goods_List, 2, length(Base_Goods_List)-1), Goods_Count)
							end;
						_ ->
							get_good_info_loop(PlayerStatus, lists:sublist(Base_Goods_List, 2, length(Base_Goods_List)-1), Goods_Count)
					end;
				true ->
					[] %%异常
			end;
		_ ->
			Goods_Count
	end.

%%根据玩家ID得到好友关系列表
get_ets_rela_record(Uid) ->
    case ets:match_object(?ETS_RELA, #ets_rela{pid = Uid, rela = 1, _ = '_'}) of
        [] -> [];
        L -> L
    end.

%%判断是否在好友关系列表中
judge_in_friend_list(Uid, Rid) ->
    case ets:match_object(?ETS_RELA, #ets_rela{pid = Uid, rid = Rid, rela = 1, _ = '_'}) of
        [] -> false;
        _ -> true
    end.

%%根据id获得名字
get_relation_name_by_id(Uid, Friend_id) ->
	case ets:match_object(?ETS_RELA, #ets_rela{pid = Uid, rid=Friend_id,  _ = '_'}) of
        [] -> [];
        L -> 
			(lists:nth(1, L))#ets_rela.nickname
    end.

%%收获果实
pick_fruit(PlayerStatus, Target_User_Id, Farm_Id,Farm, Fruit_Count, Pick_Count) ->
	[Fstate, Sgoodsid, Sstate, Plant, Grow, Fruit, Celerate] = Farm,
	case Pick_Count >=Fruit of %%
		true ->
			%%偷取的数量大于等于剩余数量,将该田地修改为开垦状态
			update_farm_by_id(Target_User_Id, Farm_Id, [2, 0, 0, 0, 0, 0, 0]),
			%%gen_server:cast(PlayerStatus#player.other#player_other.pid_goods, {'give_plant_goods', get_fruit_by_sgoodsid(Sgoodsid), Fruit}),
			lib_goods:give_plant_goods({get_fruit_by_sgoodsid(Sgoodsid), Fruit}, PlayerStatus#player.id),
			%%广播消息
			send_fram_status_when_change(PlayerStatus, Farm_Id),
			if
				Fruit_Count=:=0 ->
					[6,0,0,0,0]; %%已经摘光
				true ->
					[0,Farm_Id,get_fruit_by_sgoodsid(Sgoodsid),Fruit, Fruit]
			end;
		_ ->
			if
				Pick_Count =:= 0 ->
					[10,0,0,0,0]; %%不能摘取
				true ->
					%%摘取的数量小于剩余数量,返回摘取的数量
					update_farm_by_id(Target_User_Id, Farm_Id, [Fstate, Sgoodsid, Sstate, Plant, Grow, Fruit_Count-Pick_Count, Celerate]),
					%%gen_server:cast(PlayerStatus#player.other#player_other.pid_goods, {'give_plant_goods', get_fruit_by_sgoodsid(Sgoodsid), Pick_Count}),
					lib_goods:give_plant_goods({get_fruit_by_sgoodsid(Sgoodsid), Pick_Count}, PlayerStatus#player.id),
					%%广播消息
					send_fram_status_when_change(PlayerStatus, Farm_Id),
					[0,Farm_Id,get_fruit_by_sgoodsid(Sgoodsid),Fruit_Count-Pick_Count,Pick_Count]
			end
		end.

%%得到随机偷取的个数
get_random_count() ->
	random:uniform(2).
	%case is_integer(Random_Num/2) of
	%	true ->
	%		2;
	%	_ ->
	%		1
	%end.

%%得到唯一的ID
get_id_key() ->
	Data = tool:to_integer(lists:concat([util:longunixtime(), random:uniform(9), random:uniform(9), random:uniform(9)])),
	Data.

%%封装一键收取
get_all_farm_fruit(PlayerStatus, Farm_Id, Fruit) ->
	if
		Farm_Id > 9 ->
			[0,Fruit];
		true ->
			Fruit_info = get_on_farm(PlayerStatus, Farm_Id),
			[Error_Code, _, _, _, _] = Fruit_info,
			if 
				Error_Code =:= 0 ->
					if
						Fruit=/=[] ->
							Fruit_back=Fruit+hd(lists:sublist(Fruit_info,5,1)),
							%%发送场景信息
							Data1 = lib_manor:get_farm_info(PlayerStatus, Farm_Id ),		
							{ok, BinData1} = pt_42:write(42011, Data1),
							lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData1),
							
							get_all_farm_fruit(PlayerStatus, Farm_Id+1, Fruit_back);
						true ->
							Fruit_back=hd(lists:sublist(Fruit_info,5,1)),
							%%发送场景信息
							Data1 = lib_manor:get_farm_info(PlayerStatus, Farm_Id ),		
							{ok, BinData1} = pt_42:write(42011, Data1),
							lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData1),
							
							get_all_farm_fruit(PlayerStatus, Farm_Id+1, Fruit_back)
					end;
				true ->
					get_all_farm_fruit(PlayerStatus, Farm_Id+1, Fruit)
			end
	end.

%%判断土地是否已经开垦
judge_fram_reclamationed(PlayerStatus, Farm_Id) ->
	Farm_Info_list = get_db_farm_info_list(PlayerStatus#player.id),
	if
		length(Farm_Info_list) > 0 ->
			Farm_Info = lists:nth(1, Farm_Info_list),
			Farm = get_farm_by_id(Farm_Id, Farm_Info),
			if 
				Farm =/= [] ->
					[_Fstate, _Sgoodsid, Sstate, _Plant, _Grow, _Fruit, _Celerate] = Farm,
					if
						Sstate =:= 2 ->
							reclamationed;
						true ->
							no_reclamationed
					end;
				true ->
					no_reclamationed
			end;
		true ->
			no_reclamationed
	end.

%%将土地设为开垦
farm_reclamation_opration(PlayerStatus, Farm_Id) ->
	Farm_Info_list = get_db_farm_info_list(PlayerStatus#player.id),
	if
		length(Farm_Info_list) > 0 ->
			%%Farm_Info = lists:nth(1, Farm_Info_list),
			%%Farm = get_farm_by_id(Farm_Id, Farm_Info),
			if
				Farm_Id =:= 8 orelse Farm_Id =:= 9 -> 
					Need_Gold = get_gold_by_farmid(Farm_Id),
					write_log(insert,
							get_id_key(),
							PlayerStatus#player.id, util:unixtime(), 9, PlayerStatus#player.id, PlayerStatus#player.nickname, Farm_Id,
							999, Need_Gold, 2),
					update_farm_by_id(PlayerStatus#player.id, Farm_Id, [2, 0, 0, 0, 0, 0, 0]),
					%%扣钱
					NewStatus = lib_goods:cost_money(PlayerStatus, Need_Gold, gold, 4201),
					%%发送现在的金币情况
					lib_player:send_player_attribute2(NewStatus,3),
					%%广播消息
					send_fram_status_when_change(PlayerStatus, Farm_Id),
					if
						Farm_Id =:= 8 ->
							%%将第9块田改为用元宝开垦
							%%farm_reclamation_update_gold(NewStatus);
							update_farm_by_id(PlayerStatus#player.id, 9, [3, 0, 0, 0, 0, 0, 0]),
							Data1 = lib_manor:get_farm_info(PlayerStatus, 9 ),	
							{ok, BinData1} = pt_42:write(42011, Data1),
							lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData1),
							%%广播消息
							send_fram_status_when_change(PlayerStatus, 9),
							ok;
						true ->
							ok
					end,
					[ok, NewStatus];
				true ->
					Need_Gold = get_dev_mon_by_farmid(Farm_Id),
					write_log(insert,
							get_id_key(),
							PlayerStatus#player.id, util:unixtime(), 9, PlayerStatus#player.id, PlayerStatus#player.nickname, Farm_Id,
							998, Need_Gold, 2),
					update_farm_by_id(PlayerStatus#player.id, Farm_Id, [2, 0, 0, 0, 0, 0, 0]),
					%%扣钱
					NewStatus = lib_goods:cost_money(PlayerStatus, Need_Gold, coinonly, 4202),
					%%发送现在的金币情况
					lib_player:send_player_attribute2(NewStatus,3),
					%%广播消息
					send_fram_status_when_change(PlayerStatus, Farm_Id),
					farm_change_by_lv(PlayerStatus, Farm_Id+1),
					[ok, NewStatus]
			end;
		true ->
			[Farm_Id,99] %%意外错误
	end.


%%判断前一块土地是否已开发，如果已开发则开发该土地	
farm_reclamation_judge(PlayerStatus, Farm_Id, Max_Farm_Id) ->
	%%判断上一块土地是否已开垦
	if
		Max_Farm_Id >= Farm_Id ->
			Farm_Info_list = get_db_farm_info_list(PlayerStatus#player.id),
			if
				length(Farm_Info_list) > 0 ->
					Farm_Info = lists:nth(1, Farm_Info_list),
					Farm = get_farm_by_id(Farm_Id - 1, Farm_Info),
					[Fstate, _Sgoodsid, _Sstate, _Plant, _Grow, _Fruit, _Celerate] = Farm,
					if
						Fstate =:= 2 -> %%上一块土地已开垦
							farm_reclamation_opration(PlayerStatus, Farm_Id);
						true ->%%上一块土地未开垦
							[Farm_Id,1] %%不支持开垦
					end;
				true ->
					[Farm_Id,99] %%异常
			end;
		true ->
			[Farm_Id,2] %%等级不够
	end.

%%判断自己能不能进农场
get_canin_manor(PlayerStatus, Master_Id) ->	
	Player_in_scence = judge_player_status(PlayerStatus),
	case Player_in_scence of
		ok ->
			%%复位自己的状态
			farm_exit(PlayerStatus, [] ),
			
			%%3秒后检查是否进入其他状态
			Farm_status_timer = erlang:send_after(3 * 1000, self(), 'FARM_STATUS'),
			put(farm_status_timer, Farm_status_timer),							

			%%判断数据库中是否有记录
			List_Enter = get_db_farm_info_list(Master_Id),															
			if
				length(List_Enter) =:= 0 ->
					spawn(fun() -> db_agent:insert_farm_info(farm,
						[player_id, farm1, farm2, farm3, farm4, farm5, farm6, farm7, farm8, farm9, farm10, farm11, farm12, client, p_status],
						[Master_Id, 
						 util:term_to_string([2, 0, 0, 0, 0, 0, 0]), 
						 util:term_to_string([2, 0, 0, 0, 0, 0, 0]), 
						 util:term_to_string([2, 0, 0, 0, 0, 0, 0]), 
						 util:term_to_string([4, 0, 0, 0, 0, 0, 0]), 
						 util:term_to_string([1, 0, 0, 0, 0, 0, 0]), 
						 util:term_to_string([1, 0, 0, 0, 0, 0, 0]), 
						 util:term_to_string([1, 0, 0, 0, 0, 0, 0]), 
						 util:term_to_string([3, 0, 0, 0, 0, 0, 0]), 
						 util:term_to_string([1, 0, 0, 0, 0, 0, 0]), 
						 util:term_to_string([1, 0, 0, 0, 0, 0, 0]), 
						 util:term_to_string([1, 0, 0, 0, 0, 0, 0]), 
						 util:term_to_string([1, 0, 0, 0, 0, 0, 0]), 
						 util:term_to_string({}),
						 Master_Id
						]) end),
					if
						PlayerStatus#player.id =/= Master_Id ->
							%%改变自己的状态
							db_agent:update_farm_info(farm, 
											  [{p_status,Master_Id}],
											  [{player_id,PlayerStatus#player.id}]),
							%%进入别人的农田
							db_agent:update_farm_info(farm, 
											  [{client,util:term_to_string({PlayerStatus#player.id})}],
											  [{player_id,Master_Id}]);										
						true ->
							%%进入庄园任务接口
							lib_task:event(open_manor,null,PlayerStatus),
							ok
					end;									
				
				true ->	
					if 
						PlayerStatus#player.id =/= Master_Id -> %%进入别人的农田											
							%%改变自己的状态
							db_agent:update_farm_info(farm, 
											  [{p_status,Master_Id}],
											  [{player_id,PlayerStatus#player.id}]),
							%%改变对方的Client状态
							Player_client = util:term_to_string(list_to_tuple(lists:append(get_db_client(lists:nth(1, List_Enter)), tuple_to_list({PlayerStatus#player.id})))),
							db_agent:update_farm_info(farm, 
											  [{client,Player_client}],
											  [{player_id,Master_Id}]);
						true ->
							Enter_Info=lists:nth(1, List_Enter),
							P_status = get_db_p_status(Enter_Info),
							if 
								PlayerStatus#player.id =/= P_status ->
									List_Farm_Info = get_db_farm_info_list(P_status),	
									db_agent:update_farm_info(farm, 
													[{client,util:term_to_string(list_to_tuple(lists:delete(PlayerStatus#player.id, get_db_client(lists:nth(1, List_Farm_Info)))))}],
												    [{player_id,P_status}]);
								true ->
									ok
							end,
							%%进入庄园任务接口
							lib_task:event(open_manor,null,PlayerStatus),
							%%进入自己的农田
							db_agent:update_farm_info(farm, 
											  [{p_status,PlayerStatus#player.id}],
											  [{player_id,PlayerStatus#player.id}])
					end
			end,
				
			trans_tb_to_mem(PlayerStatus),%%载入内存
			if
				PlayerStatus#player.id =/= Master_Id ->
%% 					Data = lib_manor:get_steal_remain_times(PlayerStatus#player.id),	
%% 					{ok, BinData} = pt_42:write(42015, Data),
%% 					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
					MasterName = db_agent:get_player_properties(nickname,Master_Id),
					[0,MasterName];	%%可以进入
				true ->
					[0,PlayerStatus#player.nickname]
			end;
		_ ->
			Player_in_scence
	end.

%%去内存中查找土地信息
get_farm_info_mem(PlayerStatus, Farm_Id, Target_User_Id, Sent_To_User) ->
	Max_celerate_time = get_cele_time_by_celeid(?CELERATE),
%%	Max_celerate_count = get_cele_count_by_celeid(?CELERATE),
	Farm_Info_list = get_db_farm_info_list(Target_User_Id),
	
	if
		length(Farm_Info_list) > 0 ->
			Farm_Info = lists:nth(1, Farm_Info_list),
			Farm = get_farm_by_id(Farm_Id, Farm_Info),
			if 
				Farm =:= [] ->
					[Farm_Id, 99, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]; %%异常
				true ->
					[Fstate, Sgoodsid, _Sstate, Plant, Grow, Fruit, Celerate] = Farm,
					if						
						Fstate =:=0 -> %%原始状态
							[Farm_Id, Fstate, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
						Fstate =:=1 -> %%未开垦（荒地）
							[Farm_Id, Fstate, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
						Fstate =:=2 -> %%已开垦
							if
								Sgoodsid =:=0 -> %%尚未种植
									[Farm_Id, Fstate, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
								true ->%%已经种植
									Seed_Info = get_seed_info(Sgoodsid), %%取种子信息
									if 
										Seed_Info =:= [] -> %%异常
											[Farm_Id, 99, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]; %%异常
										true ->
											%%other_data
											[ _ , _ , { _ , Grow_Time, Max_Fruit, _ , _ }] = Seed_Info,
											Now_Time = util:unixtime(),
											if										
												(Now_Time + Celerate * Max_celerate_time*3600) >= Plant+ Grow_Time*3600  ->	%%可收获，现在的时间大于种植时间+成长时间
													if
														Fruit =:= 0 -> %%成熟期
															if
																Grow =/= Grow_Time*3600 -> %%如果原来处于成长状态，则将该记录改为成熟状态
																	%%修改内存数据库
																	update_farm_by_id(Target_User_Id, Farm_Id, [Fstate, Sgoodsid, ?SEED_MATURE, Plant, Plant+Grow_Time*3600, Max_Fruit, Celerate]),
																	%%返回状态
																	[Farm_Id, Fstate, Sgoodsid, ?SEED_MATURE, Max_Fruit, Max_Fruit, 0, 0, 0, get_fruit_by_sgoodsid(Sgoodsid), 0, 0, get_seed_res_by_sgoodsid(Sgoodsid)];
																true -> %%原来处于成熟状态，则将该田地修改为已开垦状态
																	%%修改内存表和数据库
																	update_farm_by_id(Target_User_Id, Farm_Id, [2, 0, 0, 0, 0, 0, 0]),																																
																	%%返回状态
																	[Farm_Id, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
															end;															
														true ->
															Steal_Status_Tmp = judge_steal_this_farm(PlayerStatus#player.id, Target_User_Id, Farm_Id , 2),
															if
																Steal_Status_Tmp =:= 0 ->
																	Steal_Status = 0;
																true ->
																	Steal_Status = 1
															end,
															if
																PlayerStatus#player.id =:= Target_User_Id ->
																	[Farm_Id, Fstate, Sgoodsid, ?SEED_MATURE, Max_Fruit, Fruit, 0, 0, 0, get_fruit_by_sgoodsid(Sgoodsid), 0, 0, get_seed_res_by_sgoodsid(Sgoodsid)];
																Target_User_Id =/= Sent_To_User ->
																	Steal_Status_Tmp1 = judge_steal_this_farm(Sent_To_User, Target_User_Id, Farm_Id , 2),
																	[Farm_Id, Fstate, Sgoodsid, ?SEED_MATURE, Max_Fruit, Fruit, 0, 0, 0, get_fruit_by_sgoodsid(Sgoodsid), 0, Steal_Status_Tmp1, get_seed_res_by_sgoodsid(Sgoodsid)];
																true ->
																	[Farm_Id, Fstate, Sgoodsid, ?SEED_MATURE, Max_Fruit, Fruit, 0, 0, 0, get_fruit_by_sgoodsid(Sgoodsid), 0, Steal_Status, get_seed_res_by_sgoodsid(Sgoodsid)]
															end
													end;
												(Now_Time+ Celerate*Max_celerate_time*3600) >= (Plant+ Grow_Time*3600/2 ) ->	%%成长期，现在的时间大于种植时间+成长时间
													%%返回状态
													[Farm_Id, Fstate, Sgoodsid, ?SEED_GROW, Max_Fruit, 0, tool:to_integer(Grow_Time*3600 - (Now_Time-Plant) - Celerate*Max_celerate_time*3600), 0, 0, get_fruit_by_sgoodsid(Sgoodsid),tool:to_integer(Grow_Time*3600 - (Now_Time-Plant) - Celerate*Max_celerate_time*3600), 0, get_seed_res_by_sgoodsid(Sgoodsid)];													
												(Now_Time + Celerate*Max_celerate_time*3600)=< (Plant+ Grow_Time*3600/2 ) ->	%%种子期，现在的时间大于种植时间+成长时间
													[Farm_Id, Fstate, Sgoodsid, ?SEED_SEEDED, Max_Fruit, 0, tool:to_integer(Grow_Time*3600/2-(Now_Time-Plant) - Celerate*Max_celerate_time*3600), 0, 0, get_fruit_by_sgoodsid(Sgoodsid),tool:to_integer(Grow_Time*3600 - (Now_Time-Plant) - Celerate*Max_celerate_time*3600), 0, get_seed_res_by_sgoodsid(Sgoodsid)];
												true ->%%异常
													[Farm_Id, 99, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] %%异常
											end
									end
							end;
						Fstate=:=3 -> %%需要元宝开垦
							if
								PlayerStatus#player.id =:= Target_User_Id ->
									Need_Gold = get_gold_by_farmid(Farm_Id),
									[Farm_Id, Fstate, 0, 0, 0, 0, 0, 0, Need_Gold, 0,0,0,0];
								true ->
									[Farm_Id, 99, 0, 0, 0, 0, 0, 0, 0, 0,0,0,0] %%异常
							end;
						Fstate=:=4 -> %%需要铜币开垦
							if
								PlayerStatus#player.id =:= Target_User_Id -> 
									Need_Gold = get_dev_mon_by_farmid(Farm_Id),
									[Farm_Id, Fstate, 0, 0, 0, 0, 0, get_framlv_by_playerlv(Farm_Id), Need_Gold, 0,0,0,0];
								true ->
									[Farm_Id, 99, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 , 0] %%异常
							end;
						true ->
							[Farm_Id, 99, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 , 0] %%异常
					end
			end;
		true ->
			[Farm_Id, 99, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 , 0] %%异常
	end.
			
%%根据农田的ID返回该农田的等级
get_framlv_by_playerlv(Farm_Id) ->
	if
		Farm_Id =:=?FARM_COUNT_LV55 ->
			?FARM_LV55;
		Farm_Id =:=?FARM_COUNT_LV50 ->
			?FARM_LV50;
		Farm_Id =:=?FARM_COUNT_LV45 ->
			?FARM_LV45;
		Farm_Id =:=?FARM_COUNT_LV40 ->
			?FARM_LV40;
		Farm_Id =:=?FARM_COUNT_LV30 ->
			?FARM_LV30;
		true ->
			0
	end.

%%根据农田的ID返回该农田的开垦价格
get_dev_mon_by_farmid(Farm_Id) ->
	if
		Farm_Id =:=?FARM_COUNT_LV55 ->
			?FARM_DEV_MONEY_7;
		Farm_Id =:=?FARM_COUNT_LV50 ->
			?FARM_DEV_MONEY_6;
		Farm_Id =:=?FARM_COUNT_LV45 ->
			?FARM_DEV_MONEY_5;
		Farm_Id =:=?FARM_COUNT_LV40 ->
			?FARM_DEV_MONEY_4;
		Farm_Id =:=?FARM_COUNT_LV30 ->
			0;
		true ->
			0
	end.

%%根据农田的ID返回该农田的开垦元宝价格
get_gold_by_farmid(Farm_Id) ->
	if
		Farm_Id =:=8 ->
			?FARM_DEV_GOLD_8;
		Farm_Id =:=9 ->
			?FARM_DEV_GOLD_9;
		true ->
			0
	end.

%%封包42010协议
get_42010_pack(InData) ->
	[Fid,Fstate,Sgoodsid,Sstate,Max_fruit,Remain_fruit,Remain_time, Player_Lv, Gold_Use, Fruit_Id, All_time, Steal_Times, Res_id]=InData,
	Target={ets_farm_info_back,Fid,Fstate,Sgoodsid,Sstate,Max_fruit,Remain_fruit,Remain_time, Player_Lv, Gold_Use, Fruit_Id, All_time, Steal_Times, Res_id},
	Target.
	
%%向goods进程发送删除物品消息							
sell_goods_in_warehouse(PlayerStatus,GoodsId,GoodsNum) ->
	Stat_Code=gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'delete_plant_goods', GoodsId, GoodsNum}),
	Stat_Code.

%%得到物品的卖出的类型
get_goods_sell_type(Sgoodsid) ->
		MS = ets:fun2ms(fun(T) when T#ets_base_goods.goods_id == Sgoodsid ->
						T
						end),
		Base_Goods_List = ets:select(?ETS_BASE_GOODS, MS),
		
		case length(Base_Goods_List) > 0 of
			true ->
				Goods = lists:nth(1, Base_Goods_List),
				if
					is_record(Goods,ets_base_goods)->
						Goods#ets_base_goods.price_type;
					true ->%%异常错误
						[]
				end;
			false -> %%内存表中找不到
				[]
		end.

%%得到物品的卖出价格
get_goods_sell_price(Sgoodsid) ->
		MS = ets:fun2ms(fun(T) when T#ets_base_goods.goods_id == Sgoodsid ->
						T
						end),
		Base_Goods_List = ets:select(?ETS_BASE_GOODS, MS),
		
		case length(Base_Goods_List) > 0 of
			true ->
				Goods = lists:nth(1, Base_Goods_List),
				if
					is_record(Goods,ets_base_goods)->
					%% ===========================================
%% 						%%	活动三：勤劳致富	
%% 						Now = util:unixtime(),
%% 						%%判断是否 是 植树节活动时间
%% 						case lib_activities:is_arborday_time(Now) of
%% 							true ->
%% 								trunc(2*Goods#ets_base_goods.sell_price);
%% 							false ->
								Goods#ets_base_goods.sell_price;
%% 						end;
					%% ===========================================
					true ->%%异常错误
						[]
				end;
			false -> %%内存表中找不到
				[]
		end.
%%得到物品的可不可卖
get_goods_sell_sell(Sgoodsid) ->
		MS = ets:fun2ms(fun(T) when T#ets_base_goods.goods_id == Sgoodsid ->
						T
						end),
		Base_Goods_List = ets:select(?ETS_BASE_GOODS, MS),
		
		case length(Base_Goods_List) > 0 of
			true ->
				Goods = lists:nth(1, Base_Goods_List),
				if
					is_record(Goods,ets_base_goods)->
						Goods#ets_base_goods.sell;
					true ->%%异常错误
						[]
				end;
			false -> %%内存表中找不到
				[]
		end.

%%将数据库的玩家的土地信息载入内存
trans_tb_to_mem(PlayerStatus) ->
	%%先按第一个元素倒序排列，再按第二个元素到序排列
	%%A = [{4,1,1},{1,2,1},{3,1,2},{1,3,3},{2,3,4},{3,2,4},{3,3,6},{3,4,7},{2,5,8}],
	%%D = lists:sort(fun({X1,Y1,_},{X2,Y2,_}) -> 
	%%					   if X1 =/= X2 -> 
	%%							  X1 > X2; 
	%%						  true -> 
	%%							  Y1 >= Y2 
	%%					   end 
	%%			   end ,
	%%			   A),
	%%D = lists:sort(fun({_,Y1,_},{_,Y2,_}) -> 
	%%					   	  Y1 >= Y2 
	%%			   end ,
	%%			   A),
	%%E = lists:sublist(D,3),
	%%载入log表
	ets:match_delete(?ETS_MANOR_STEAL, #ets_manor_steal{player_id=PlayerStatus#player.id, _='_' }),
	Manor_Steal_List = db_agent:select_one_log(log_manor_steal, "steal_id, player_id, steal_time, actions, pid,nickname, fid, sgoodsid, count, read",[{player_id, PlayerStatus#player.id},{steal_time, ">", (util:unixtime()-48*3600)}],[{steal_time, desc}], []),
	if
		Manor_Steal_List =/= null ->
			lists:foreach(fun(Manor_Steal) ->
								Manor_Steal_Info = list_to_tuple([ets_manor_steal] ++ Manor_Steal),
								New_Manor_Steal_Info=Manor_Steal_Info#ets_manor_steal{nickname=tool:to_list(Manor_Steal_Info#ets_manor_steal.nickname)},
                				ets:insert(?ETS_MANOR_STEAL, New_Manor_Steal_Info)
							end,
							Manor_Steal_List);
		true ->
			[] %%异常
	end.
	


  
%%根据等级更新内存表
farm_change_by_lv(PlayerStatus, Farm_Id) ->
	if
		PlayerStatus#player.lv >= ?FARM_LV55 ->
			farm_change_by_lv_loop(PlayerStatus, Farm_Id, ?FARM_COUNT_LV55);
		PlayerStatus#player.lv >= ?FARM_LV50 ->
			farm_change_by_lv_loop(PlayerStatus, Farm_Id, ?FARM_COUNT_LV50+1);
		PlayerStatus#player.lv >= ?FARM_LV45 ->
			farm_change_by_lv_loop(PlayerStatus, Farm_Id, ?FARM_COUNT_LV45+1);
		PlayerStatus#player.lv >= ?FARM_LV40 ->
			farm_change_by_lv_loop(PlayerStatus, Farm_Id, ?FARM_COUNT_LV40+1);
		PlayerStatus#player.lv >= ?FARM_LV30 ->
			farm_change_by_lv_loop(PlayerStatus, Farm_Id,?FARM_COUNT_LV30+1);
		true ->
			[] %%异常
	end.

%%判断下一块土地是否可以开垦，将土地设为可用铜币开垦
farm_change_by_lv_loop(PlayerStatus, Farm_Id, Max_Farm_Id) ->
	Farm_Info_list = get_db_farm_info_list(PlayerStatus#player.id),
	if
		length(Farm_Info_list) > 0 ->
			if
				Max_Farm_Id >= (Farm_Id) ->
					%%将土地设为系要用铜币开垦
					update_farm_by_id(PlayerStatus#player.id, Farm_Id, [4, 0, 0, 0, 0, 0, 0]),
					%%发送土地信息给客户端
					Data1 = lib_manor:get_farm_info(PlayerStatus, Farm_Id),		
					{ok, BinData1} = pt_42:write(42011, Data1),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData1),
					ok;
				true ->
					[] %%异常
			end;
		true ->
			[] %%异常
	end.


%%元宝更新开垦
%%update_farm_info_by_gold_loop(Target_User_Id) ->
%%	MS = ets:fun2ms(fun(T) when T#ets_farm_info.pid == Target_User_Id andalso T#ets_farm_info.fstate==3 ->
%%						T
%%						end),
%%	Farm_Count = ets:select_count(?ETS_FARM_INFO, MS),
%%	if
%%		Farm_Count=:=2 ->
%%			db_agent:update_farm_info(manor_farm_info,
%%									[{fstate,1}],
%%									[{pid,Target_User_Id},{fid,9}]);
%%		true ->
%%			[]
%%	end.

%%得到目标用户
get_target_user(PlayerStatus) ->
	List_Enter_List = get_db_farm_info_list(PlayerStatus#player.id),
	if
		length(List_Enter_List) > 0 ->
			Enter_Info = get_db_p_status(lists:nth(1, List_Enter_List)),
			Enter_Info;
		true ->
			[]
	end.

%%得到田地的主人
%%get_farm_owner_user(PlayerStatus) ->
%%	List_Enter_List = get_db_farm_info_list(PlayerStatus#player.id),
%%	if
%%		length(List_Enter_List) > 0 ->
%%			Enter_Info = get_db_player_id(lists:nth(1, List_Enter_List)),
%%			Enter_Info;
%%		true ->
%%			[]
%%	end.

%%得到种子的附加信息
get_seed_info(Sgoodsid) ->
		MS = ets:fun2ms(fun(T) when T#ets_base_goods.goods_id == Sgoodsid  ->
						T
						end),
		Base_Goods_List = ets:select(?ETS_BASE_GOODS, MS),
		
		case length(Base_Goods_List) > 0 of
			true ->
				Goods = lists:nth(1, Base_Goods_List),
				if
					is_record(Goods,ets_base_goods)->
						OData = goods_util:parse_goods_other_data(Goods#ets_base_goods.other_data,farm),
						OData;
					true ->%%异常错误
						[]
				end;
			false -> %%内存表中找不到
				[]
		end.
%%根据种子信息得到果实的ID
%%other_data
get_fruit_by_sgoodsid(Sgoodsid) ->
	Seed_Info = get_seed_info(Sgoodsid), %%取种子信息
		if 
			Seed_Info =:= [] -> %%异常
				[];
			true ->
				[ _ , _ , { Fruit_id , _ , _ , _ , _ }] = Seed_Info,
				%%goods_util:get_goods_name(Fruit_id)
				Fruit_id
		end.

%%根据种子信息得到种子的等级
%%other_data
get_seed_lv_by_sgoodsid(Sgoodsid) ->
	Seed_Info = get_seed_info(Sgoodsid), %%取种子信息
		if 
			Seed_Info =:= [] -> %%异常
				[];
			true ->
				[ _ , _ , { _ , _ , _ , Seed_lv, _}] = Seed_Info,
				%%goods_util:get_goods_name(Fruit_id)
				Seed_lv
		end.
%%根据种子信息得到资源ID
%%other_data
get_seed_res_by_sgoodsid(Sgoodsid) ->
	Seed_Info = get_seed_info(Sgoodsid), %%取种子信息
		if 
			Seed_Info =:= [] -> %%异常
				[];
			true ->
				[ _ , _ , { _ , _ , _ , _, Seed_res }] = Seed_Info,
				%%goods_util:get_goods_name(Fruit_id)
				Seed_res
		end.

%%得到加速器附加信息
get_cele_info(Celeid) ->
		MS = ets:fun2ms(fun(T) when T#ets_base_goods.goods_id == Celeid ->
						T
						end),
		Base_Goods_List = ets:select(?ETS_BASE_GOODS, MS),
		
		case length(Base_Goods_List) > 0 of
			true ->
				Goods = lists:nth(1, Base_Goods_List),
				if
					is_record(Goods,ets_base_goods)->
						OData = goods_util:parse_goods_other_data(Goods#ets_base_goods.other_data,farm),
						OData;
					true ->%%异常错误
						[]
				end;
			false -> %%内存表中找不到
				[]
		end.
%%根据加速器的信息得到加速的时间
%%other_data
get_cele_time_by_celeid(Celeid) ->
	Cele_Info = get_cele_info(Celeid), %%取加速器信息
		if 
			Cele_Info =:= [] -> %%异常
				[];
			true ->
				[ _ , _ , { Cele_time , _ }] = Cele_Info,
				Cele_time
		end.

%%根据加速器的信息得到加速的使用次数
%%other_data
get_cele_count_by_celeid(Celeid) ->
	Cele_Info = get_cele_info(Celeid), %%取加速器信息
		if 
			Cele_Info =:= [] -> %%异常
				[];
			true ->
				[ _ , _ , { _ , Cele_count }] = Cele_Info,
				Cele_count
		end.

				
%%得到好友、黑名单和仇人的等级
%% get_relat_lv(PlayerStatus, Target_User_Id) ->	
%% 	if
%% 		PlayerStatus#player.id =:= Target_User_Id ->
%% 			PlayerStatus#player.lv;
%% 		  true ->			
%% 				case lib_player:get_player_pid(Target_User_Id) of
%% 					[] ->%%不在线
%% 						MS = ets:fun2ms(fun(T) when T#ets_rela.pid == PlayerStatus#player.id andalso T#ets_rela.rid ==Target_User_Id ->
%% 									T
%% 									end),
%% 						Relation_List = ets:select(?ETS_RELA, MS),
%% 						case length(Relation_List) > 0 of
%% 							true ->
%% 								Relation = lists:nth(1, Relation_List),
%% 								if
%% 									is_record(Relation,ets_rela)->
%% 										Relation#ets_rela.lv;
%% 									true ->%%异常错误
%% 										0
%% 								end;
%% 							false ->
%% 								0
%% 						end;
%% 						
%% 					Pid ->%%在线
%% 						%%Pid,
%% 						%%Lv=lib_relationship:get_online_user_lv(Target_User_Id),
%% 						case catch gen:call(Pid, '$gen_call', {'PLAYER', [lv]}, 2000) of
%%              						{'EXIT',_Reason} ->
%%               							0;
%%              						{ok, [Clv]} ->
%%                							Clv
%%             				 	end
%% 						
%% 				end
%% end.


%%写log操作
write_log(Optype,Steal_id, Player_id, Steal_time, Actions, Pid, Nickname, Fid, Sgoodsid, Count, Read) ->
	if
		Optype =:= update ->
			db_agent:update_farm_info(log_manor_steal,
									[{player_id,Player_id},
									 {steal_time,Steal_time},
									 {actions,Actions},
									 {pid,Pid},
									 {nickname,Nickname},
									 {fid,Fid},
									 {sgoodsid,Sgoodsid},
									 {count,Count},
									 {read,Read}],
									[{steal_id,Steal_id}]),
			ets:insert(?ETS_MANOR_STEAL, #ets_manor_steal{steal_id = Steal_id,  
														player_id = Player_id, 
														steal_time = Steal_time, 
														actions = Actions, 
														pid = Pid, 
														nickname = Nickname,
														fid = Fid, 
														sgoodsid = Sgoodsid, 
														count = Count, 
														read = Read});
		Optype =:= insert ->
			db_agent:insert_farm_info(log_manor_steal,
										[steal_id, player_id, steal_time, actions, pid, nickname,fid, sgoodsid, count, read],
										[get_id_key(),
	 									Player_id, Steal_time, Actions, Pid, Nickname, Fid, Sgoodsid, Count, Read]),
			ets:insert(?ETS_MANOR_STEAL, #ets_manor_steal{steal_id = Steal_id,  
														player_id = Player_id, 
														steal_time = Steal_time, 
														actions = Actions, 
														pid = Pid, 
														nickname = Nickname,
														fid = Fid, 
														sgoodsid = Sgoodsid, 
														count = Count, 
														read = Read});
		true ->
			[]
	end.

%%获得用户的名字
%%get_username_by_id(Player_id) ->
%%	case lib_player:get_user_info_by_id(Player_id) of
%%		[] -> %%到数据库中查
%%			lib_player:get_role_name_by_id(Player_id);
%%		Userinfo ->	%%在内存表中查找
%%			Userinfo#player.nickname		
%%	end.

%%组装好友列表
pack_friend_list(R) when is_record(R, ets_rela)->
	%%On_off_line =  case lib_player:is_online(R#ets_rela.rid) of
	%%					true -> 1;
	%%					_ -> 0
	%%				end,
	%%lib_player:is_online(R#ets_rela.rid),
    {R#ets_rela.rid, R#ets_rela.sex,R#ets_rela.career, R#ets_rela.lv, R#ets_rela.nickname}.

%%根据种子的ID得到种子的数量
get_good_info_count(PlayerStatus, Goods_Id) ->
	%%到内存表查找
	MS = ets:fun2ms(fun(T) when T#goods.player_id == PlayerStatus#player.id andalso T#goods.goods_id == Goods_Id andalso T#goods.location == 4 ->
			T
	end),
	Seed_money_list = ets:select(?ETS_GOODS_ONLINE,MS),
	case length(Seed_money_list) > 0 of
		true ->
			get_good_num_count(0, Seed_money_list);
		_ ->
			0 %%找不到时返回0
	end.
%%累加物品的数量
get_good_num_count(Sum_Money, Seed_money_list) ->
	case length(Seed_money_list) > 0 of
		true ->
			Seed_Money=lists:nth(1,Seed_money_list),
			Sum_Money1 = tool:to_integer(Sum_Money)+tool:to_integer(Seed_Money#goods.num),
			Seed_money_list1 = lists:delete(Seed_Money, Seed_money_list),
			get_good_num_count(Sum_Money1, Seed_money_list1);
		_ ->
			Sum_Money
	end.

%%判断是否对该田偷取过 
%% Type 1:判断是否超过每日限额，2:判断是否对该田进行偷取
judge_steal_this_farm(Player_Id, Target_User_Id, Farm_Id, Type)->
	%%Now=util:unixtime(),
	Today = get_today_time(),
	if
		Type =:= 2 ->%%判断log中的偷取时间是否大于该土地的种植时间，是则可以偷
			MS = ets:fun2ms(fun(T) when T#ets_manor_steal.player_id == Player_Id andalso T#ets_manor_steal.pid == Target_User_Id andalso T#ets_manor_steal.fid==Farm_Id  andalso T#ets_manor_steal.steal_time >= Today andalso T#ets_manor_steal.actions==2->
			%%MS = ets:fun2ms(fun(T) when T#ets_manor_steal.player_id == Player_Id andalso T#ets_manor_steal.pid == Target_User_Id andalso T#ets_manor_steal.fid==Farm_Id andalso T#ets_manor_steal.actions==2->
							T
							end),
			Steal_List =ets:select(?ETS_MANOR_STEAL, MS),
			if
				length(Steal_List)>0 ->
					%%根据steal_time倒序排序
					Log_Info_List_Sort = lists:sort(fun({_,_,_,Y1,_,_,_,_,_,_,_},{_,_,_,Y2,_,_,_,_,_,_,_}) ->
										  Y1 >= Y2 
									   end ,
									   Steal_List),
					Log_Info = lists:nth(1, Log_Info_List_Sort), %%得到第一条偷取时间
					Plant_time = get_plant_time_by_farm_id(Target_User_Id, Farm_Id),
					case  Log_Info#ets_manor_steal.steal_time > Plant_time  of
						true ->
							7; %%今天已经对该田偷取过了
						_ ->
							0
					end;
				true ->
					0 %%可以偷取
			end;
		true ->%%每日偷取的次数
%% 			MS = ets:fun2ms(fun(T) when T#ets_manor_steal.player_id == Player_Id andalso T#ets_manor_steal.steal_time >= Today andalso T#ets_manor_steal.actions==2->
%% 							T
%% 							end),
%% 			Steal_List =ets:select(?ETS_MANOR_STEAL, MS),
%% 			if
%% 				length(Steal_List) >= ?MAX_STEAL_TIMES ->
%% 					9; %%超过每日限额
%% 				true ->
%% 					0
%% 			end
			0
	end.



%%获得土地的种植时间
get_plant_time_by_farm_id(Player_Id, Farm_Id) ->
	Farm_Info_list = get_db_farm_info_list(Player_Id),
	
	if
		length(Farm_Info_list) > 0 ->
			Farm_Info = lists:nth(1, Farm_Info_list),
			Farm = get_farm_by_id(Farm_Id, Farm_Info),
			[_Fstate, _Sgoodsid, _Sstate, Plant, _Grow, _Fruit, _Celerate] = Farm,
					Plant;
		true ->
			0
	end.


%%当土地状态改变的时候像进入农场的玩家发送状态消息
send_fram_status_when_change(PlayerStatus, Farm_Id) ->
	%%得到当前在现农场的人的Pid
	Target_User_Id = get_target_user(PlayerStatus), %%得到目前所在的农场ID
	
	F = fun(Target_User_Info) ->
				%%判断该玩家是否在线
				case lib_player:get_player_pid(Target_User_Info) of
					[] -> %%不在线
						[];
					%%Pid -> %%在线
					_ ->
						%%得到土地主人的PID
						Data = get_farm_info_mem(PlayerStatus, Farm_Id, Target_User_Id, Target_User_Info),	
										{ok, BinData} = pt_42:write(42011, Data),
										lib_send:send_to_uid(Target_User_Info, BinData)
						%%case catch gen_server:call(Pid,{'PLAYER'}, 3000) of
             			%%			{'EXIT',_Reason} ->
              			%%				[];
             			%%			Target_Status ->
               			%%				Data = lib_manor:get_farm_info(Target_Status, Farm_Id),	
						%%				{ok, BinData} = pt_42:write(42011, Data),
						%%				lib_send:send_to_uid(Target_User_Info, BinData)
            			%%	 	end					
						%%发送该土地信息
						%%if 
						%%	PlayerStatus#player.id =/= Target_User_Info#ets_manor_enter.player_id ->
								
						%%	true ->
						%%		ok
						%%end
				end
         end,

	
	if 
		Target_User_Id =:= [] ->
			ok;
		true ->
			List_Enter_List = get_db_farm_info_list(Target_User_Id),
			List_Enter = lists:nth(1, List_Enter_List),
			Target_User_List = get_db_client(List_Enter),
			case length(Target_User_List) > 0 of
				true ->
					if
						PlayerStatus#player.id =/= Target_User_Id ->
							lists:foreach(F, lists:append(Target_User_List, [Target_User_Id]));
						true ->
							lists:foreach(F, Target_User_List)
					end,
					
					ok;
				_ ->
					ok
			end
	end.

%%判断玩家是否在其他状态，如果不在返回ok，否则返回错误
%%该方法在mod_player中调用
judge_player_status(PlayerStatus) ->
	Plv = PlayerStatus#player.lv,
	%%Status = PlayerStatus#player.status,
	
	if 
		Plv < 30 -> %%低于30级
			[1,0];
		true ->
			ok
	end.

%% 获取当天0点
get_today_time() ->
	{Today, _NextDay} = util:get_midnight_seconds(util:unixtime()),
	Today.

%%获得数据库信息
get_db_farm_info_list(Target_User_Id) ->
	db_agent:select_form_info(farm, "player_id, farm1, farm2, farm3, farm4, farm5, farm6, farm7, farm8, farm9, farm10, farm11, farm12, client, p_status",[{player_id, Target_User_Id}]).

%%获取数据库的p_status
get_db_p_status(List_Farm_Info) ->
	[_Player_id, _Farm1, _Farm2, _Farm3, _Farm4, _Farm5, _Farm6, _Farm7, _Farm8, _Farm9, _Farm10, _Farm11, _Farm12, _Client, P_status] = List_Farm_Info,
	P_status.

%%获取数据库的client
get_db_client(List_Farm_Info) ->
	[_Player_id, _Farm1, _Farm2, _Farm3, _Farm4, _Farm5, _Farm6, _Farm7, _Farm8, _Farm9, _Farm10, _Farm11, _Farm12, Client, _P_status] = List_Farm_Info,
	tuple_to_list(util:string_to_term(tool:to_list(Client))).

%%获取数据库的Player_id
%%get_db_player_id(List_Farm_Info) ->
%%	[Player_id, _Farm1, _Farm2, _Farm3, _Farm4, _Farm5, _Farm6, _Farm7, _Farm8, _Farm9, _Farm10, _Farm11, _Farm12, _Client, _P_status] = List_Farm_Info,
%%	Player_id.

%%获取数据库的第1块农田信息
get_db_farm1(List_Farm_Info) ->
	[_Player_id, Farm1, _Farm2, _Farm3, _Farm4, _Farm5, _Farm6, _Farm7, _Farm8, _Farm9, _Farm10, _Farm11, _Farm12, _Client, _P_status] = List_Farm_Info,
	util:string_to_term(tool:to_list(Farm1)).

%%获取数据库的第2块农田信息
get_db_farm2(List_Farm_Info) ->
	[_Player_id, _Farm1, Farm2, _Farm3, _Farm4, _Farm5, _Farm6, _Farm7, _Farm8, _Farm9, _Farm10, _Farm11, _Farm12, _Client, _P_status] = List_Farm_Info,
	util:string_to_term(tool:to_list(Farm2)).

%%获取数据库的第3块农田信息
get_db_farm3(List_Farm_Info) ->
	[_Player_id, _Farm1, _Farm2, Farm3, _Farm4, _Farm5, _Farm6, _Farm7, _Farm8, _Farm9, _Farm10, _Farm11, _Farm12, _Client, _P_status] = List_Farm_Info,
	util:string_to_term(tool:to_list(Farm3)).

%%获取数据库的第4块农田信息
get_db_farm4(List_Farm_Info) ->
	[_Player_id, _Farm1, _Farm2, _Farm3, Farm4, _Farm5, _Farm6, _Farm7, _Farm8, _Farm9, _Farm10, _Farm11, _Farm12, _Client, _P_status] = List_Farm_Info,
	util:string_to_term(tool:to_list(Farm4)).

%%获取数据库的第5块农田信息
get_db_farm5(List_Farm_Info) ->
	[_Player_id, _Farm1, _Farm2, _Farm3, _Farm4, Farm5, _Farm6, _Farm7, _Farm8, _Farm9, _Farm10, _Farm11, _Farm12, _Client, _P_status] = List_Farm_Info,
	util:string_to_term(tool:to_list(Farm5)).

%%获取数据库的第6块农田信息
get_db_farm6(List_Farm_Info) ->
	[_Player_id, _Farm1, _Farm2, _Farm3, _Farm4, _Farm5, Farm6, _Farm7, _Farm8, _Farm9, _Farm10, _Farm11, _Farm12, _Client, _P_status] = List_Farm_Info,
	util:string_to_term(tool:to_list(Farm6)).

%%获取数据库的第7块农田信息
get_db_farm7(List_Farm_Info) ->
	[_Player_id, _Farm1, _Farm2, _Farm3, _Farm4, _Farm5, _Farm6, Farm7, _Farm8, _Farm9, _Farm10, _Farm11, _Farm12, _Client, _P_status] = List_Farm_Info,
	util:string_to_term(tool:to_list(Farm7)).

%%获取数据库的第8块农田信息
get_db_farm8(List_Farm_Info) ->
	[_Player_id, _Farm1, _Farm2, _Farm3, _Farm4, _Farm5, _Farm6, _Farm7, Farm8, _Farm9, _Farm10, _Farm11, _Farm12, _Client, _P_status] = List_Farm_Info,
	util:string_to_term(tool:to_list(Farm8)).

%%获取数据库的第9块农田信息
get_db_farm9(List_Farm_Info) ->
	[_Player_id, _Farm1, _Farm2, _Farm3, _Farm4, _Farm5, _Farm6, _Farm7, _Farm8, Farm9, _Farm10, _Farm11, _Farm12, _Client, _P_status] = List_Farm_Info,
	util:string_to_term(tool:to_list(Farm9)).

%%获取数据库的第10块农田信息
get_db_farm10(List_Farm_Info) ->
	[_Player_id, _Farm1, _Farm2, _Farm3, _Farm4, _Farm5, _Farm6, _Farm7, _Farm8, _Farm9, Farm10, _Farm11, _Farm12, _Client, _P_status] = List_Farm_Info,
	util:string_to_term(tool:to_list(Farm10)).

%%获取数据库的第11块农田信息
get_db_farm11(List_Farm_Info) ->
	[_Player_id, _Farm1, _Farm2, _Farm3, _Farm4, _Farm5, _Farm6, _Farm7, _Farm8, _Farm9, _Farm10, Farm11, _Farm12, _Client, _P_status] = List_Farm_Info,
	util:string_to_term(tool:to_list(Farm11)).

%%获取数据库的第12块农田信息
get_db_farm12(List_Farm_Info) ->
	[_Player_id, _Farm1, _Farm2, _Farm3, _Farm4, _Farm5, _Farm6, _Farm7, _Farm8, _Farm9, _Farm10, _Farm11, Farm12, _Client, _P_status] = List_Farm_Info,
	util:string_to_term(tool:to_list(Farm12)).

%%根据ID的得到农田信息
get_farm_by_id(Farm_Id, Farm_Info) ->
	case Farm_Id of 
		1 -> get_db_farm1(Farm_Info);
		2 -> get_db_farm2(Farm_Info);
		3 -> get_db_farm3(Farm_Info);
		4 -> get_db_farm4(Farm_Info);
		5 -> get_db_farm5(Farm_Info);
		6 -> get_db_farm6(Farm_Info);
		7 -> get_db_farm7(Farm_Info);
		8 -> get_db_farm8(Farm_Info);
		9 -> get_db_farm9(Farm_Info);
		10 -> get_db_farm10(Farm_Info);
		11 -> get_db_farm11(Farm_Info);
		12 -> get_db_farm12(Farm_Info);
		_ -> []
	end.

%%更新农田信息
update_farm_by_id(Target_User_Id, Farm_Id, Farm_Info) ->
	case Farm_Id of 
		1 -> db_agent:update_farm_info(farm, 
									   [{farm1,util:term_to_string(Farm_Info)}],
									   [{player_id,Target_User_Id}]);
		2 -> db_agent:update_farm_info(farm, 
									   [{farm2,util:term_to_string(Farm_Info)}],
									   [{player_id,Target_User_Id}]);
		3 -> db_agent:update_farm_info(farm, 
									   [{farm3,util:term_to_string(Farm_Info)}],
									   [{player_id,Target_User_Id}]);
		4 -> db_agent:update_farm_info(farm, 
									   [{farm4,util:term_to_string(Farm_Info)}],
									   [{player_id,Target_User_Id}]);
		5 -> db_agent:update_farm_info(farm, 
									   [{farm5,util:term_to_string(Farm_Info)}],
									   [{player_id,Target_User_Id}]);
		6 -> db_agent:update_farm_info(farm, 
									   [{farm6,util:term_to_string(Farm_Info)}],
									   [{player_id,Target_User_Id}]);
		7 -> db_agent:update_farm_info(farm, 
									   [{farm7,util:term_to_string(Farm_Info)}],
									   [{player_id,Target_User_Id}]);
		8 -> db_agent:update_farm_info(farm, 
									   [{farm8,util:term_to_string(Farm_Info)}],
									   [{player_id,Target_User_Id}]);
		9 -> db_agent:update_farm_info(farm, 
									   [{farm9,util:term_to_string(Farm_Info)}],
									   [{player_id,Target_User_Id}]);
		10 -> db_agent:update_farm_info(farm, 
									   [{farm10,util:term_to_string(Farm_Info)}],
									   [{player_id,Target_User_Id}]);
		11 -> db_agent:update_farm_info(farm, 
									   [{farm11,util:term_to_string(Farm_Info)}],
									   [{player_id,Target_User_Id}]);
		12 -> db_agent:update_farm_info(farm, 
									   [{farm12,util:term_to_string(Farm_Info)}],
									   [{player_id,Target_User_Id}]);
		_ -> []
	end.
%%获取已经开垦的农田数量
get_reclaim_farm_num(PlayerId) ->
	Farms = get_db_farm_info_list(PlayerId),
%% 	?DEBUG("~p", [Farms]),
	Len = length(Farms),
	if
		Len > 0 ->
			FarmList = lists:nth(1, Farms),
			check_farm_reclaim(12, 0, PlayerId, FarmList);%%%12块地，开始遍历
		true ->
			0
	end.
check_farm_reclaim(0, Count, _PlayerId, _FarmList) ->
	Count;
check_farm_reclaim(Num, Count, PlayerId, FarmList) ->
	case get_farm_by_id(Num, FarmList) of
		[] ->
			check_farm_reclaim(Num-1, Count, PlayerId, FarmList);
		Farm ->
			[FState|_Other] = Farm,
			NCount =
				case FState =:= 2 of
					true ->
						Count + 1;
					false ->
						Count
				end,
			check_farm_reclaim(Num-1, NCount, PlayerId, FarmList)
	end.


%%根据等级算出每天可以出售的绑定铜和交易铜
get_sell_limit(Lv) ->
	if
		Lv >= 30 andalso Lv =< 40 ->
			[260,130];
		Lv >= 41 andalso Lv =< 44 ->
			[320,160];
		Lv >= 45 andalso Lv =< 49->
			[370,180];
		Lv >= 50 andalso Lv =< 54->
			[420,210];
		Lv >= 55 andalso Lv =< 100->
			[480,240];
		true ->
			[0,0]
	end.
