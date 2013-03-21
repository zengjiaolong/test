%%%-----------------------------------
%%% @Module  : lib_task
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 任务
%%%-----------------------------------
-module(lib_task).
-compile(export_all).

-include("common.hrl").
-include("record.hrl").
-include("guild_info.hrl").

%%初始化基础任务
init_base_task() ->
    F = fun(Task) ->
		D = list_to_tuple([task | Task]),
		TaskInfo = D#task{
			start_item = data_agent:task_getItemCode(D#task.start_item),
			talk_item = data_agent:task_getItemCode(D#task.talk_item),
 			end_item = data_agent:task_getItemCode(D#task.end_item),
			start_npc = data_agent:task_valToTagCode(D#task.start_npc),
 			condition = data_agent:task_getConditionCode(D#task.condition),
			content = data_agent:task_getContentCode(D#task.content, D#task.end_npc, D#task.end_talk),
			award_item = data_agent:task_getItemCode(D#task.award_item),
 			award_select_item = data_agent:task_getItemCode(D#task.award_select_item),
 			award_gift = data_agent:task_getItemCode(D#task.award_gift)				   
		},			
   		ets:insert(?ETS_BASE_TASK, TaskInfo)
   	end,
	L = db_agent:get_base_task(),
	lists:foreach(F, L),
    ok.

%% 从数据库加载角色的任务数据
flush_role_task(PS) ->
	%%1级新手不请内存数据
	if PS#player.lv =/= 1->
		mod_task_cache:write_back(PS#player.id),
		ets:match_delete(?ETS_ROLE_TASK, #role_task{player_id=PS#player.id, _='_'}),
    	ets:match_delete(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=PS#player.id, _='_'});
	   true->skip
	end,
	NowTime = util:unixtime(),
	RoleTaskList = db_agent:get_task_bag_info(PS#player.id),
            [
                ets:insert(?ETS_ROLE_TASK, #role_task{id={PS#player.id,Tid}, player_id=PS#player.id, task_id=Tid, trigger_time = Tt, state = S, end_state = ES, mark = util:string_to_term(tool:to_list(M)),type=Type,other = util:string_to_term(tool:to_list(Other))})
                || [_Id, _PlayerId, Tid, Tt, S ,ES, M,Type,Other] <-RoleTaskList,is_delete_trigger(PS#player.id,Tid,Tt,NowTime)==true,S=/=2,Tid>0
            ],
     RoleTaskLogList = db_agent:get_task_log_info(PS#player.id),
            [
                ets:insert(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=PS#player.id, task_id=Tid2, trigger_time = Tt2, finish_time = Ft2})
                || [_, Tid2,Type, Tt2, Ft2] <-RoleTaskLogList,check_task_type_and_date(Type,Ft2,NowTime)=:=true
            ],
	ConsignTaskList = db_agent:get_consign_task(PS#player.id),
			[
			 ets:insert(?ETS_TASK_CONSIGN, #ets_task_consign{id=Id,player_id=PS#player.id, task_id=TaskId, times = Times, exp =Exp,spt=Spt,cul=Cul, gold=Gold,timestamp = Timestamp})
                || [Id, _,TaskId,Exp,Spt,Cul,Gold, Times, Timestamp] <-ConsignTaskList
			 ],
     refresh_active(PS).
%%     case get_trigger(PS) =/= [] orelse get_finish(PS) =/= [] of
%%         true -> 
%% 			true;   %% 已经加载过就不再加载
%%         false ->
%%             RoleTaskList = db_agent:get_task_bag_info(PS#player.id),
%%             [
%%                 ets:insert(?ETS_ROLE_TASK, #role_task{id={PS#player.id,Tid}, player_id=PS#player.id, task_id=Tid, trigger_time = Tt, state = S, end_state = ES, mark = util:string_to_term(tool:to_list(M)),type=Type})
%%                 || [_Id, _PlayerId, Tid, Tt, S ,ES, M,Type] <-RoleTaskList,S=/=2
%%             ],
%%             RoleTaskLogList = db_agent:get_task_log_info(PS#player.id),
%%             [
%%                 ets:insert(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=PS#player.id, task_id=Tid2, trigger_time = Tt2, finish_time = Ft2})
%%                 || [_, Tid2, Tt2, Ft2] <-RoleTaskLogList
%%             ],
%% 			ConsignTaskList = db_agent:get_consign_task(PS#player.id),
%% 			[
%% 			 ets:insert(?ETS_TASK_CONSIGN, #ets_task_consign{id=Id,player_id=PS#player.id, task_id=TaskId, times = Times, exp =Exp,spt=Spt,cul=Cul, gold=Gold,timestamp = Timestamp})
%%                 || [Id, _,TaskId,Exp,Spt,Cul,Gold, Times, Timestamp] <-ConsignTaskList
%% 			 ],
%%             refresh_active(PS)
%% 	end.

%%运镖，跑商任务标记检查
check_carry_mark(PlayerStatus)->
	case PlayerStatus#player.carry_mark > 0 andalso PlayerStatus#player.carry_mark < 8 orelse (PlayerStatus#player.carry_mark >=20 andalso PlayerStatus#player.carry_mark<26)of
		true->
			CarryTask = data_task:task_get_carry_id_list(PlayerStatus#player.realm),
			GuildCarryTask = data_task:task_get_guild_carry_id_list(PlayerStatus#player.realm),
			BusinessTask = data_task:task_get_business_id_list(),
			case db_agent:check_task_accept(PlayerStatus#player.id,CarryTask++GuildCarryTask++BusinessTask) of
				[]->
					spawn(fun()->db_agent:mm_update_player_info([{carry_mark,0}],[{id,PlayerStatus#player.id}])end),
					PlayerStatus#player{carry_mark=0};
				_->
					PlayerStatus
			end;
		false->
			PlayerStatus
	end.

%%检查任务是否应该删除
is_delete_trigger(PlayerId,TaskId,TriggerTime,NowTime)->
	if TaskId == ?APPOINT_TASK_ID->
		   case util:is_same_date(TriggerTime, NowTime) of
			   true->
				   true;
			   false->
				   mod_task_cache:del_trigger(PlayerId, TaskId),
				   false
		   end;
	   true->true
	end.

%%检查任务类型和完成时间
check_task_type_and_date(Type,FinishTime,NowTime)->
	if Type =:= 2 orelse Type =:= 3 ->
		   case check_online_day(FinishTime,NowTime) >= 4 of
			   true-> false;
			   false->true
		   end;
	   Type =:= 5 ->
		   case check_online_day(FinishTime,NowTime) >= 1 of
			   true-> false;
			   false->true
		   end;
	   true->true
	end.
%%检查天数差
check_online_day(FinishTime,NowTime)->
	NDay = (NowTime+8*3600) div 86400,
	TDay = (FinishTime+8*3600) div 86400,
	NDay-TDay.

%% 删除角色的任务数据
delete_role_task(PlayerId) ->
	db_agent:delete_task_bag(PlayerId),
	db_agent:delete_task_log(PlayerId),
	db_agent:delete_consign_task_all(PlayerId),
    ets:match_delete(?ETS_ROLE_TASK, #role_task{player_id=PlayerId, _='_'}),
    ets:match_delete(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=PlayerId, _='_'}),
	ets:match_delete(?ETS_TASK_CONSIGN, #ets_task_consign{player_id=PlayerId, _='_'}),
	ok.
	
%% 角色下线操作
offline(PlayerId) ->
    %% 清除ets缓存 
    ets:match_delete(?ETS_TASK_QUERY_CACHE, {PlayerId,_='_'}),
    ets:match_delete(?ETS_ROLE_TASK, #role_task{player_id=PlayerId, _='_'}),
    ets:match_delete(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=PlayerId, _='_'}),
	ets:match_delete(?ETS_TASK_CONSIGN, #ets_task_consign{player_id=PlayerId, _='_'}),
	%%回写玩家任务信息
	mod_task_cache:write_back(PlayerId),
	lib_carry:offline(PlayerId),
	ok.

%% 刷新任务并发送更新列表
refresh_task(PS) ->
%%     refresh_active(PS),
%%     lib_scene:refresh_npc_ico(PS),
	{ok, BinData} = pt_30:write(30006, [1,0]),
    lib_send:send_to_sid(PS#player.other#player_other.pid_send, BinData).		


%% 遍历所有任务看是否可接任务 
refresh_active(PS) ->
	if 
		PS#player.lv < 10 ->
			MainActiveTids = [Tid || Tid <- data_task:task_get_novice_id_list(), can_trigger(Tid, PS)],
			ets:insert(?ETS_TASK_QUERY_CACHE, {PS#player.id, MainActiveTids});
 		true->
			MainActiveTids = [Tid || Tid <- data_task:task_get_main_id_list(), can_trigger(Tid, PS)],
			BtanchActiveTids = [Tid || Tid <- data_task:task_get_btanch_id_list(), can_trigger(Tid, PS)],
			if PS#player.lv < 20->
				   ets:insert(?ETS_TASK_QUERY_CACHE, {PS#player.id, MainActiveTids++BtanchActiveTids});
			   true->
					DaylyActiveTids = [Tid || Tid <- data_task:task_get_daily_id_list(), can_trigger(Tid, PS)],
					GuildActiveTids = [Tid || Tid<-data_task:task_get_guild_id_list(), can_trigger(Tid, PS)],
					%%运镖路线为唯一
					CarryActiveTids = [Tid || Tid <- data_task:task_get_carry_id_list(PS#player.realm), can_trigger(Tid, PS)],
					RandomCycleTids = [Tid || Tid <- data_task:task_get_random_cycle_id_list(), can_trigger(Tid, PS)],
					CycleList = data_task:task_get_cycle_id_list(),
					case check_has_cycle_task(PS,CycleList) of
						true->
							ets:insert(?ETS_TASK_QUERY_CACHE, {PS#player.id, RandomCycleTids++MainActiveTids++BtanchActiveTids++DaylyActiveTids++CarryActiveTids++GuildActiveTids});
						false->
							CycleActiveTids = [Tid || Tid<-CycleList, can_trigger(Tid, PS)],
							ets:insert(?ETS_TASK_QUERY_CACHE, {PS#player.id, RandomCycleTids++MainActiveTids++BtanchActiveTids++DaylyActiveTids++CarryActiveTids++GuildActiveTids++CycleActiveTids})
					end
%% 					case check_has_carry_task(PS) of
%% 						false ->
%% 							CarryActiveTids = [Tid || Tid<- data_task:task_get_carry_id_list(PS#player.realm), can_trigger(Tid, PS)],
%% 							%%io:format("Here is CarryActiveTids:~p~n",[CarryActiveTids]),
%% 							case CarryActiveTids of
%% 								 []->
%% 									ets:insert(?ETS_TASK_QUERY_CACHE, {PS#player.id, MainActiveTids++BtanchActiveTids++DaylyActiveTids++GuildActiveTids++ActiveTids2});
%% 								 _->
%% 									{NewCarryActiveTids,_} = tool:list_random(CarryActiveTids),
%% 									ets:insert(?ETS_TASK_QUERY_CACHE, {PS#player.id, MainActiveTids++BtanchActiveTids++DaylyActiveTids++[NewCarryActiveTids]++GuildActiveTids++ActiveTids2})
%% 							end;
%% 						true->
%% 							ets:insert(?ETS_TASK_QUERY_CACHE, {PS#player.id, MainActiveTids++BtanchActiveTids++DaylyActiveTids++GuildActiveTids++ActiveTids2})
%% 					end
			end
	end.

%% 获取任务详细数据
get_data(TaskId) -> 
    data_agent:task_get(TaskId).


check_same_id(List1,List2)->
	F=fun(Id)->
			  lists:member(Id,List2)
	  end,
	lists:filter(F, List1).


%%检查是否已经接了运镖任务
check_has_carry_task(PS)->
	Task_List = get_trigger(PS),
	Task_Id = [TD#role_task.task_id||TD<-Task_List],
	Carry_Id = data_task:task_get_carry_id_list(PS#player.realm),
%% 	case [ID||ID <- lists:merge(Task_Id,Carry_Id),lists:member(ID,Task_Id),lists:member(ID,Carry_Id)] of
	case check_same_id(Task_Id,Carry_Id) of
		[] ->
			false;
		_->true
	end.

%%检查是否已经接了循环任务task_get_cycle_id_list
check_has_cycle_task(PS,CycleList)->
	Task_List = get_trigger(PS),
	Task_Id = [TD#role_task.task_id||TD<-Task_List],
	case check_same_id(CycleList,Task_Id) of
		[]->false;
		_->true
	end.
%% 	case [ID||ID <- lists:merge(Task_Id,CycleList),lists:member(ID,Task_Id),lists:member(ID,CycleList)] of
%% 		[] ->
%% 			false;
%% 		_->true
%% 	end.

%% 获取下一等级的任务
next_lev_list(PS,ActiveIds) ->
	case PS#player.lv > 20 of
		true->
			Main_Tids = data_task:task_get_main_id_list(),
%% 			case [ID||ID <- lists:merge(Main_Tids,ActiveIds),lists:member(ID,Main_Tids),lists:member(ID,ActiveIds)] of
			case check_same_id(Main_Tids,ActiveIds) of
				[] ->
%% 					Btanch_Tids = data_task:task_get_btanch_id_list(),
					Btanch_Tids=[],
					Tids = Btanch_Tids++Main_Tids,
   					F = fun(Tid) -> TD = get_data(Tid), (PS#player.lv + 1) =:= TD#task.level end,
   					Next_task = [XTid || XTid<-Tids, F(XTid)],
					case Next_task of
						[]->
							[];
						_->
							[lists:min(Next_task)]
					end;
				_ ->
					[]
			end;
		false->
			[]
	end.



%% 获取玩家能在该Npc接任务或者交任务
get_npc_task_list(NpcId, PS) ->
	%%特殊NPC，部落穿越任务用
	if 
		NpcId >= 900 andalso NpcId =< 1000 ->
			npc_task_list_get(NpcId, PS);
		true ->
			CurSceneId = PS#player.scene,
			case lists:member(CurSceneId, [200, 250, 280]) of
				true ->
					AllowScene = get_sceneid_by_realm(PS#player.realm),
					if 
						CurSceneId =:= AllowScene ->
							npc_task_list_get(NpcId, PS);
				   		true -> 
							[]
					end;
			   	false ->
				  	npc_task_list_get(NpcId, PS)
			end
	end.


%%获取NPC任务
npc_task_list_get(NpcId, PS) ->
    {CanTrigger, Link, UnFinish, Finish} = get_npc_task(NpcId, PS),
    F = fun(Tid, NS) ->
				TD = get_data(Tid),
				case NS =:=2 orelse NS =:= 3 of 
					false->
						[Tid, NS, TD#task.name,TD#task.type];
					true->
						Task = get_one_trigger(Tid,PS),
						case Task#role_task.type of
							1->[Tid, NS, TD#task.name,6];
							_->[Tid, NS, TD#task.name,TD#task.type]
						end
				end
		end,
    L1 = [F(T1, 1) || T1 <- CanTrigger],
    L2 = [F(T2, 4) || T2 <- Link],
    L3 = [F(T3, 2) || T3 <- UnFinish],
    L4 = [F(T4, 3) || T4 <- Finish],
    L1++L2++L3++L4.


%% 获取npc任务状态
get_npc_state(NpcId, PS)->
	%%特殊NPC，部落穿越任务用
	if NpcId >= 900 andalso NpcId =< 1000 ->
		   get_task_state(NpcId, PS);
		true ->
			CurSceneId = PS#player.scene,
			case lists:member(CurSceneId,[200,250,280]) of
				true->
					AllowScene = get_sceneid_by_realm(PS#player.realm),
					if CurSceneId =:=AllowScene ->
						   get_task_state(NpcId, PS);
					   true->0
					end;
				false->
				   get_task_state(NpcId, PS)
			end
	end.

get_task_state(NpcId, PS)->
	%%CanTrigger, Link, UnFinish, Finish皆为列表
    {CanTrigger, Link, UnFinish, Finish} = get_npc_task(NpcId, PS),
    %% 0表示什么都没有，1表示有可接任务，2表示已接受任务但未完成，3表示有完成任务，4表示有任务相关
    case length(Finish) > 0 of
        true -> 3;
        false ->
            case length(Link)>0 of
                true-> 4;
                false-> 
                    case length(CanTrigger)>0 of
                        true ->    1;
                        false ->
                            case length(UnFinish)>0 of
                                true -> 2;
                                false -> 0
                            end
                    end
            end
    end.

%% 获取npc任务关联
%%{可接任务，关联，任务未完成，完成任务}
get_npc_task(NpcId, PS)->
    CanTrigger = get_npc_can_trigger_task(NpcId, PS),
    {Link, Unfinish, Finish} = get_npc_other_link_task(NpcId, PS),
    {CanTrigger, Link, Unfinish, Finish}.

%% 获取可接任务
get_npc_can_trigger_task(NpcId, PS) ->
    get_npc_can_trigger_task(get_active(PS), [], NpcId, PS).
get_npc_can_trigger_task([], Result, _, _) ->
    Result;
get_npc_can_trigger_task([TaskId | T ], Result, NpcId, PS) ->
%%     TD = get_data(TaskId),
	case get_data(TaskId) of
		[]->get_npc_can_trigger_task(T, Result, NpcId, PS);
		TD->
			case is_hero_task(TD) ==true orelse is_appoint_task(TD)==true of
				true->get_npc_can_trigger_task(T, Result, NpcId, PS);
				false->
    				case get_start_npc(TD#task.start_npc, PS#player.career) =:= NpcId of
        				false -> get_npc_can_trigger_task(T, Result, NpcId, PS);
        				true -> get_npc_can_trigger_task(T, Result ++ [TaskId], NpcId, PS)
					end
			end
    end.

%% 获取任务关联（是否对话,是否可接任务,是否可以完成）
get_npc_other_link_task(NpcId, PS) ->
    get_npc_other_link_task(get_trigger(PS), {[], [], []}, NpcId, PS).
get_npc_other_link_task([], Result, _, _) ->
    Result;
get_npc_other_link_task([RT | T], {Link, Unfinish, Finish}, NpcId, PS) ->
	%%委托的任务不显示
	case RT#role_task.state =/= 2 of 
		true->
			case get_data(RT#role_task.task_id) of
				[]->get_npc_other_link_task(T, {Link, Unfinish, Finish}, NpcId, PS);
				TD->
					%%英雄贴任务自动完成，不在NPC上面显示
					case is_hero_task(TD) of
						false->
							case is_finish(RT, PS) andalso get_end_npc_id(RT) =:= NpcId of  %% 判断是否完成
								true -> 
									case RT#role_task.task_id =:= ?GUILD_WISH_TASK_ID of%%氏族祝福任务 可提交状态时，客户端NPC上不显示
										true ->
											get_npc_other_link_task(T, {Link, Unfinish, Finish}, NpcId, PS);
										false ->
											get_npc_other_link_task(T, {Link, Unfinish, Finish++[RT#role_task.task_id]}, NpcId, PS)
									end;
 				       			false -> 
 		        		   			case task_talk_to_npc(RT, NpcId) of %% 判断是否和NPC对话
			 		    		           true -> get_npc_other_link_task(T, {Link++[RT#role_task.task_id], Unfinish, Finish}, NpcId, PS);
 		    			        		   false -> 
		 		                			   case get_start_npc(TD#task.start_npc, PS#player.career) =:= NpcId of %% 判断是否接任务NPC
					 		                       true -> get_npc_other_link_task(T, {Link, Unfinish++[RT#role_task.task_id], Finish}, NpcId, PS);
		    					                    false -> get_npc_other_link_task(T, {Link, Unfinish, Finish}, NpcId, PS)
		                					    end
						            end
							end;
						true->
							case is_finish(RT, PS) andalso get_end_npc_id(RT) =:= NpcId of  %% 判断是否完成
								true ->
									get_npc_other_link_task(T, {Link, Unfinish, Finish++[RT#role_task.task_id]}, NpcId, PS);
								false->
									get_npc_other_link_task(T, {Link, Unfinish, Finish}, NpcId, PS)
							end
					end
		 end;
		false->get_npc_other_link_task(T, {Link, Unfinish, Finish}, NpcId, PS)
    end.

%%检查任务的下一内容是否为与某npc的对话
task_talk_to_npc(RT, NpcId)->
    Temp = [0||[State,Fin,Type,Nid|_]<- RT#role_task.mark, State=:= RT#role_task.state, Fin=:=0, Type=:=talk, Nid =:= NpcId],
    length(Temp)>0.

%% 获取任务对话id
get_npc_task_talk_id(TaskId, NpcId, PS) ->
    case get_data(TaskId) of
        null -> 0;
        TD ->
            {CanTrigger, Link, UnFinish, Finish} = get_npc_task(NpcId, PS),
            case {
                lists:member(TaskId, CanTrigger), 
                lists:member(TaskId, Link),
                lists:member(TaskId, UnFinish),
                lists:member(TaskId, Finish)
            }of 
                {true, _, _, _} -> {start_talk, TD#task.start_talk};    %% 任务触发对话
                {_, true, _, _} ->    %% 关联对话
                    RT = get_one_trigger(TaskId, PS),
                    [Fir|_] = [TalkId || [State,Fin,Type,Nid,TalkId|_] <- RT#role_task.mark, State=:= RT#role_task.state, Fin=:=0, Type=:=talk, Nid =:= NpcId],
                    {link_talk, Fir};
                {_, _, true, _} -> {unfinished_talk, TD#task.unfinished_talk};  %% 未完成对话
                {_, _, _, true} ->   %% 提交任务对话
                    RT = get_one_trigger(TaskId, PS),
                    [Fir|_] = [TalkId || [_,_,Type,Nid,TalkId|_] <- RT#role_task.mark, Type=:=end_talk, Nid =:= NpcId],
                    {end_talk, Fir};
                _ -> {undefined, 0}
            end
    end.

%% =======================获取提示信息=========
%%可接
get_tip(active, TaskId, PS) ->
    TD = get_data(TaskId),
    case get_start_npc(TD#task.start_npc, PS#player.career) of
        0 -> [];
        StartNpcId -> 
			[to_same_mark([0, 0, start_talk, StartNpcId], PS)]
    end;
%%下一级
get_tip(next, TaskId, PS) ->
    TD = get_data(TaskId),
    case get_start_npc(TD#task.start_npc, PS#player.career) of
        0 -> [];
        StartNpcId -> 
			[to_same_mark([0, 1, next_talk, StartNpcId], PS)]
    end;
%%已接
get_tip(trigger, TaskId, PS) ->
	RT = get_one_trigger(TaskId, PS),
	case is_record(RT,role_task) of
		false->[];
		true->
			[to_same_mark([State|T], PS) || [State | T] <-RT#role_task.mark, RT#role_task.state=:= State]
	end.

%%=======================处理任务物品=======================

%%获取物品奖励
get_award_item(TD, PS) ->
    [{ItemId, Num} || {Career, ItemId, Num} <- TD#task.award_item, Career =:= 0 orelse Career =:= PS#player.career].

%%获取礼包奖励
get_award_gift(TD, PS) ->
    [{GiftId, Num} || {Career, GiftId, Num} <- TD#task.award_gift, Career =:= 0 orelse Career =:= PS#player.career].

%%获取触发物品奖励
get_start_award_item(Start_item, PS) ->
    [{ItemId, Num} || {Career, ItemId, Num} <- Start_item, Career =:= 0 orelse Career =:= PS#player.career].

%%获取对话物品奖励
get_talk_award_item(TD, PS) ->
    [{ItemId, Num} || {Career, ItemId, Num} <- TD#task.talk_item, Career =:= 0 orelse Career =:= PS#player.career].

%%任务结束回收物品
get_end_item(TD, PS) ->
%% 	io:format("TD#task.end_item~p~n",[TD#task.end_item]),
    [{ItemId, Num} || {Career, ItemId, Num} <- TD#task.end_item, Career =:= 0 orelse Career =:= PS#player.career].

%% 获取委托物品奖励
get_award_consign(ConsignAward)->
	[{GoodsId,Num}||{GoodsId,Num}<-ConsignAward,GoodsId>0].

%% 获取开始npc的id
%% 如果需要判断职业才匹配第2,3
get_start_npc(StartNpc, _) when is_integer(StartNpc) -> StartNpc;

get_start_npc([], _) -> 0;

get_start_npc([{career, Career, NpcId}|T], RoleCareer) ->
    case Career =:= RoleCareer of
        false -> get_start_npc(T, RoleCareer);
        true -> NpcId
    end.

%% =============================转换成一致的数据结构==============


%%开始NPC
to_same_mark([_, Finish, start_talk, NpcId | _], PS) ->
    {SId,SName,_,_} = get_npc_def_scene_info(NpcId, PS#player.realm,PS#player.scene,PS#player.lv),
    %% [类型, 完成, NpcId, Npc名称, 0, 0, 所在场景Id]
    [0, Finish, NpcId, lib_npc:get_name_by_npc_id(NpcId), 0, 0, SId, SName, []];
%%下一级任务
to_same_mark([_, Finish, next_talk, NpcId | _], PS) ->
    {SId,SName,_,_} = get_npc_def_scene_info(NpcId, PS#player.realm,PS#player.scene,PS#player.lv),
    %% [类型, 完成, NpcId, Npc名称, 0, 0, 所在场景Id]
    [0, Finish, NpcId, lib_npc:get_name_by_npc_id(NpcId), 0, 0, SId, SName, []];

%%结束NPC
to_same_mark([_, Finish, end_talk, NpcId | _], PS) ->
    {SId,SName,_,_} = get_npc_def_scene_info(NpcId, PS#player.realm,PS#player.scene,PS#player.lv),
%% 	io:format("{SId,SName}~p~n",[[{SId,SName}]]),
    %% [类型, 完成, NpcId, Npc名称, 0, 0, 所在场景Id]
    [1, Finish, NpcId, lib_npc:get_name_by_npc_id(NpcId), 0, 0, SId, SName, []];

%%杀怪
to_same_mark([_, Finish, kill, MonId, Num, NowNum | _], PS) ->
    {SId,SName, X, Y} = get_mon_def_scene_info(MonId,PS#player.realm,PS#player.scene),
%% 	io:format("{SId,SName, X, Y}~p~n",[[{SId,SName, X, Y}]]),
    %% [类型, 完成, MonId, Npc名称, 需要数量, 已杀数量, 所在场景Id]
    [2, Finish, MonId, lib_mon:get_name_by_mon_id(MonId), Num, NowNum, SId, SName, [X, Y]];

%%对话
to_same_mark([_, Finish, talk, NpcId | _], PS) ->
    {SId,SName,_,_} = get_npc_def_scene_info(NpcId, PS#player.realm,PS#player.scene,PS#player.lv),
    %% [类型, 完成, NpcId, Npc名称, 0, 0, 所在场景Id]
    [3, Finish, NpcId, lib_npc:get_name_by_npc_id(NpcId), 0, 0, SId, SName, []];

%%收集物品
to_same_mark([_, Finish, item, ItemId, Num, NowNum | _], PS) ->
    {MonId, ItemName, SceneId, SceneName, X, Y} = case goods_util:get_task_mon(ItemId) of
        0 -> {0, get_item_name(ItemId), 0, <<"未知场景">>, 0, 0};  %% 物品无绑定npc
        XMonId ->
            {XSId,XSName, X0, Y0} = get_mon_def_scene_info(XMonId,PS#player.realm,PS#player.scene),
            {XMonId, get_item_name(ItemId), XSId, XSName, X0, Y0}
    end,
    %% [类型, 完成, 物品id, 物品名称, 0, 0, 0]
    [4, Finish, MonId, ItemName, Num, NowNum, SceneId, SceneName, [MonId, lib_mon:get_name_by_mon_id(MonId), X, Y]];

%%打开商城
to_same_mark([_, Finish, open_store | _], _PS) ->
    [5, Finish, 0, <<>>, 0, 0, 0, <<>>, []];

%%装备法宝
to_same_mark([_, Finish, equip ,ItemId | _], _PS) ->
	 [6, Finish, ItemId, <<"法宝">>, 0, 0, 0, <<>>, []];
%%     [6, Finish, ItemId, get_item_name(ItemId), 0, 0, 0, <<>>, []];

%%购买物品
to_same_mark([_, Finish, buy_equip ,ItemId, NpcId| _], PS) ->
	{SId,SName,_,_} = get_npc_def_scene_info(NpcId, PS#player.realm,PS#player.scene,PS#player.lv),
   	[7, Finish, ItemId, get_item_name(ItemId), 0, 0, SId, SName, [NpcId, lib_npc:get_name_by_npc_id(NpcId)]];

%%学习技能
to_same_mark([_, Finish, learn_skill ,SkillId | _], _PS) ->
    [8, Finish, SkillId, <<"技能书">>, 0, 0, 0, <<>>, []];

%to_same_mark([_, Finish, train_equip ,Lev | _], _PS) ->
%    [10, Finish, Lev, <<"法宝修炼">>, 0, 0, 0, <<>>, []];

%%选择部落
to_same_mark([_, Finish, select_nation | _], _PS) ->
    [11, Finish, 0, <<"选择部落">>, 0, 0, 0, <<>>, []];

%%使用物品
to_same_mark([_, Finish, use_goods ,GoodsId | _], _PS) ->
	if GoodsId =:= 28100 orelse GoodsId =:= 28101 orelse GoodsId =:= 28102 
		 orelse GoodsId =:= 28103 orelse GoodsId =:= 28104 ->
		   [12, Finish, GoodsId,<<"新手礼包">>, 0, 0, 0, <<>>, []];
    	true->
	   [12, Finish, GoodsId,get_item_name(GoodsId), 0, 0, 0, <<>>, []]
	end;

%%召唤灵兽
to_same_mark([_, Finish, pet | _], _PS) ->
    [13, Finish, 0, <<"召唤灵兽">>, 0, 0, 0, <<>>, []];

%%添加好友
to_same_mark([_, Finish, friend | _], _PS) ->
    [14, Finish, 0, <<"添加好友">>, 0, 0, 0, <<>>, []];

%%加入氏族
to_same_mark([_, Finish, guild | _], _PS) ->
    [15, Finish, 0, <<"加入氏族">>, 0, 0, 0, <<>>, []];

%%拜师
to_same_mark([_, Finish, master | _], _PS) ->
    [16, Finish, 0, <<"拜师学艺">>, 0, 0, 0, <<>>, []];

%%熔合法宝
to_same_mark([_,Finish,trump | _],_PS) ->
	[17, Finish, 0, <<"熔合法宝">>, 0, 0, 0, <<>>, []];

%%坐骑
to_same_mark([_, Finish, mount | _], _PS) ->
    [18, Finish, 0, <<" 骑上坐骑">>, 0, 0, 0, <<>>, []];

%%技能升级
%% to_same_mark([_, Finish, up_skill | _], _PS) ->
%%     [19, Finish, 0, <<"技能升级">>, 0, 0, 0, <<>>, []];

%%商城购买
to_same_mark([_,Finish,shopping,ItemId|_],_PS) ->
	 [20, Finish, ItemId, get_item_name(ItemId), 0, 0, 0, <<>>, []];


%%收集物品
to_same_mark([_, Finish,collect, ItemId, Num, NowNum | _], PS) ->
    {MonId, ItemName, SceneId, SceneName, X, Y} = case goods_util:get_task_mon(ItemId) of
        0 -> {0, get_item_name(ItemId), 0, <<"未知场景">>, 0, 0};  %% 物品无绑定npc
        XMonId ->
            {XSId,XSName, X0, Y0} = get_mon_def_scene_info(XMonId,PS#player.realm,PS#player.scene),
            {XMonId, get_item_name(ItemId), XSId, XSName, X0, Y0}
    end,
    %% [类型, 完成, 物品id, 物品名称, 0, 0, 0]
    [21, Finish, MonId, ItemName, Num, NowNum, SceneId, SceneName, [MonId, lib_mon:get_name_by_mon_id(MonId), X, Y]];

%%护送NPC
to_same_mark([_, Finish, convoy | _], _PS) ->
    [22, Finish, 0, <<" 护送NPC">>, 0, 0, 0, <<>>, []];

%%藏宝图鉴定
to_same_mark([_, Finish, appraisal ,ItemId, NpcId| _], PS) ->
	{SId,SName,_,_} = get_npc_def_scene_info(NpcId, PS#player.realm,PS#player.scene,PS#player.lv),
   	[23, Finish, ItemId, get_item_name(ItemId), 0, 0, SId, SName, [NpcId, lib_npc:get_name_by_npc_id(NpcId)]];


%%战场竞技
to_same_mark([_, Finish, arena | _], PS) ->
	{SId,SName,_,_} = get_npc_def_scene_info(10219, PS#player.realm,PS#player.scene,PS#player.lv),
   	[24, Finish, 10219, lib_npc:get_name_by_npc_id(10219), 0, 0, SId, SName, []];

%%答题
to_same_mark([_, Finish, question ,QuestionId | _], _PS) ->
	[25 , Finish, QuestionId,<<>>, 0, 0, 0, <<>>, []];

%%升级
to_same_mark([_, Finish, up_level ,Level | _], _PS) ->
	[26 , Finish, Level,<<>>, 0, 0, 0, <<>>, []];

%%战场击杀
to_same_mark([_, Finish, arena_kill, Num, NowNum | _], _PS) ->
    %% [类型, 完成, _, _, 需要数量, 已杀数量, 所在场景Id]
    [27, Finish, 0, <<>>, Num, NowNum, 0, <<>>, []];

%%打开药店
to_same_mark([_, Finish, open_drugstore ,ItemId, NpcId| _], PS) ->
	{SId,SName,_,_} = get_npc_def_scene_info(NpcId, PS#player.realm,PS#player.scene,PS#player.lv),
   	[28, Finish, ItemId, get_item_name(ItemId), 0, 0, SId, SName, [NpcId, lib_npc:get_name_by_npc_id(NpcId)]];

%%英雄帖
to_same_mark([_, Finish, hero_kill,Lv, Num, NowNum | _], _PS) ->
    %% [29, 完成, 需求等级,<<"封神贴">> , 需要数量, 已杀数量,...]
    [29, Finish, Lv,<<"封神帖">>, Num, NowNum, 0, <<>>, []];

%%战场竞技
to_same_mark([_, Finish, guild_war | _], PS) ->
	{SId,SName,_,_} = get_npc_def_scene_info(20207, PS#player.realm,PS#player.scene,PS#player.lv),
   	[30, Finish, 20207, lib_npc:get_name_by_npc_id(20207), 0, 0, SId, SName, []];

%%仙侣情缘
to_same_mark([_, Finish, love | _], _PS) ->
    [31, Finish, 0, <<"寻找有缘人，赠送礼物">>, 0, 0, 0, <<>>, []];

%%打开庄园
to_same_mark([_, Finish, open_manor | _], _PS) ->
    [32, Finish, 0, <<"打开庄园">>, 0, 0, 0, <<>>, []];

%%击杀异族
to_same_mark([_, Finish, kill_enemy, Num, NowNum | _], _PS) ->
    %% [类型, 完成, _, _, 需要数量, 已杀数量, 所在场景Id]
    [33, Finish, 0, <<>>, Num, NowNum, 0, <<>>, []];


%%保存页面h
to_same_mark([_, Finish, save_html | _], _PS) ->
    [34, Finish, 0, <<"保存页面">>, 0, 0, 0, <<>>, []];

%%装备附魔
to_same_mark([_, Finish, magic  | _], _PS) ->
    [35, Finish, 0, <<"装备附魔">>, 0, 0, 0, <<>>, []];

%%氏族祝福
to_same_mark([_, Finish, guild_bless  | _], _PS) ->
    [36, Finish, 0, <<"氏族祝福">>, 0, 0, 0, <<>>, []];

%%了解强化
to_same_mark([_, Finish, open_strength  | _], _PS) ->
    [37, Finish, 0, <<"了解强化">>, 0, 0, 0, <<>>, []];

%%诛邪
to_same_mark([_, Finish, zhuxie  | _], _PS) ->
    [38, Finish, 0, <<"诛邪">>, 0, 0, 0, <<>>, []];

%%了解仓库
to_same_mark([_, Finish,open_storehouse  | _], PS) ->
	{SId,SName,_,_} = get_npc_def_scene_info(10215, PS#player.realm,PS#player.scene,PS#player.lv),
    [39, Finish, 10215, lib_npc:get_name_by_npc_id(10215), 0, 0, SId, SName, []];

%%开神兽蛋
to_same_mark([_, Finish, pet_eggs  | _], _PS) ->
    [40, Finish, 0, <<"开神兽蛋">>, 0, 0, 0, <<>>, []];

%%灵兽技能融合
to_same_mark([_, Finish, pet_skill  | _], _PS) ->
    [41, Finish, 0, <<"灵兽技能融合">>, 0, 0, 0, <<>>, []];


%%打开藏宝图
to_same_mark([_, Finish, open_appraisal  | _], _PS) ->
    [42, Finish, 0, <<"打开藏宝图">>, 0, 0, 0, <<>>, []];

%%爱侣完成仙侣情愿任务
to_same_mark([_, Finish, lover_task  | _], _PS) ->
    [43, Finish, 0, <<"爱侣完成仙侣情缘任务">>, 0, 0, 0, <<>>, []]; 

%%爱侣赠送鲜花
to_same_mark([_, Finish, lover_flower  | _], _PS) ->
    [44, Finish, 0, <<"爱侣赠送玫瑰">>, 0, 0, 0, <<>>, []]; 

%%爱侣温泉互动
to_same_mark([_, Finish, lover_hotspring, Num, NowNum | _], _PS) ->
    [45, Finish, 0, <<>>, Num, NowNum, 0, <<>>, []];

%%爱侣通关试炼
to_same_mark([_, Finish, lover_train  | _], _PS) ->
    [46, Finish, 0, <<"试炼通关">>, 0, 0, 0, <<>>, []]; 

%%学习被动技能
to_same_mark([_, Finish, passive_skill  | _], _PS) ->
    [47, Finish, 0, <<"学习被动技能">>, 0, 0, 0, <<>>, []];

%%坐骑出战
to_same_mark([_, Finish, mount_fight  | _], _PS) ->
    [48, Finish, 0, <<"坐骑出战">>, 0, 0, 0, <<>>, []];

%%坐骑变形
to_same_mark([_, Finish, mount_change  | _], _PS) ->
    [49, Finish, 0, <<"坐骑变形">>, 0, 0, 0, <<>>, []];

%%试炼副本击杀
to_same_mark([_, Finish, train_kill, Num, NowNum | _], _PS) ->
    %% [类型, 完成, _, _, 需要数量, 已杀数量, 所在场景Id]
    [50, Finish, 0, <<>>, Num, NowNum, 0, <<>>, []];

%%竞技场挑战
to_same_mark([_, Finish, arena_pk| _], _PS) ->
    [51, Finish, 0, <<"竞技场挑战">>, 0, 0, 0, <<>>, []]; 

%%参与封神纪元
to_same_mark([_, Finish, fs_era| _], _PS) ->
    [52, Finish, 0, <<"参与封神纪元">>, 0, 0, 0, <<>>, []]; 

%%参与斗兽
to_same_mark([_, Finish, mount_arena| _], _PS) ->
    [53, Finish, 0, <<"参与斗兽">>, 0, 0, 0, <<>>, []]; 

%%爱的宣言
to_same_mark([_, Finish, love_show| _], _PS) ->
    [54, Finish, 0, <<"爱的宣言">>, 0, 0, 0, <<>>, []]; 

%%斗兽挑战
to_same_mark([_, Finish, mount_pk, Num, NowNum | _], _PS) ->
    %% [类型, 完成, _, _, 需要数量, 已杀数量, 所在场景Id]
    [55, Finish, 0, <<>>, Num, NowNum, 0, <<>>, []];

%%竞技场击杀
to_same_mark([_, Finish, arena_fight, Num, NowNum | _], _PS) ->
    %% [类型, 完成, _, _, 需要数量, 已杀数量, 所在场景Id]
    [56, Finish, 0, <<>>, Num, NowNum, 0, <<>>, []];

%%使用桃子
to_same_mark([_, Finish, use_peach, Num, NowNum | _], _PS) ->
    %% [类型, 完成, _, _, 需要数量, 已杀数量, 所在场景Id]
    [57, Finish, 0, <<>>, Num, NowNum, 0, <<>>, []];

%%在线3小时
to_same_mark([_, Finish, online_time| _], _PS) ->
    [58, Finish, 0, <<"在线3小时">>, 0, 0, 0, <<>>, []]; 

%%活跃度100
to_same_mark([_, Finish, online_100| _], _PS) ->
    [59, Finish, 0, <<"活跃度100">>, 0, 0, 0, <<>>, []]; 

%%任意购物
to_same_mark([_, Finish, buy_anything| _], _PS) ->
    [60, Finish, 0, <<"任意购物">>, 0, 0, 0, <<>>, []]; 

%%未知格式
to_same_mark(MarkItem, _PS) ->
%% 	io:format("error************************"),
    MarkItem.

%%获取当前NPC所在的场景（自动寻路用）

get_npc_def_scene_info(NpcId, Realm,NowScene,Lv) ->
    case lib_npc:get_scene_by_npc_id(NpcId) of
        [] ->
            {0,<<" 找不到NPC对应的场景">>,0,0};
		SceneIdInfo->
			[[SceneId, _, _]|_] = SceneIdInfo,
			if NpcId >= 900 andalso NpcId =< 1000 ->
				get_scene_info(SceneId,SceneIdInfo,0);
			true->
				%%200,250,280为主城id
				HomeCity=lists:member(SceneId, [200,201,250,251,280,281]),
				%%新手村
				NoviceCity = lists:member(SceneId, [100,110,111]),
				%%雷泽
%% 				LeiZeCity = lists:member(SceneId,[101,102,103]),
				if HomeCity ->
					   if Lv >= 31->
							  case maincity_send_31up(SceneIdInfo,NowScene) of
								  0->
									  maincity_send_31down(SceneIdInfo,NpcId,Realm,Lv,SceneId);
								  SceneFind1->
									  SceneFind =  get_scene_id(Lv,Realm,SceneFind1,NpcId),
									  get_scene_info(SceneFind,SceneIdInfo,1)
							  end;
						  true->
							  maincity_send_31down(SceneIdInfo,NpcId,Realm,Lv,SceneId)
					   end;
				   NoviceCity->
					   case lists:member(NowScene, [100,110,111]) of
						   true-> get_scene_info(NowScene,SceneIdInfo,2);
						   false->get_scene_info(SceneId,SceneIdInfo,2)
					   end;
					true ->
						SceneFind = get_scene_id(Lv,Realm,SceneId,NpcId),
						get_scene_info(SceneFind,SceneIdInfo,3)
				end
			end
    end.

%%主城、城郊特殊处理
maincity_send_31up(SceneIdInfo,NowScene)->
	maincity_send_loop(SceneIdInfo,NowScene).

maincity_send_loop([],_NowScene)->0;
maincity_send_loop([[SceneId|_]|SceneIdInfo],NowScene)->
	if SceneId == NowScene->SceneId;
		true->
			maincity_send_loop(SceneIdInfo,NowScene)
	end.

maincity_send_31down(SceneIdInfo,NpcId,Realm,Lv,SceneId)->
	case lib_carry:check_npc(NpcId) of
		false->
			SceneId_List = [[Id]||[Id|_]<-SceneIdInfo],
			ScenId_Realm = lib_npc:get_scene_by_realm_id(Realm),
			case check_same_id(SceneId_List,ScenId_Realm) of
				[] ->
					{0,<<"场景分类中找不到该场景_1">>,0,0};
				SceneList->
					[[SceneId_1]|_]=SceneList,
					SceneFind =  get_scene_id(Lv,Realm,SceneId_1,NpcId),
					get_scene_info(SceneFind,SceneIdInfo,1)
			end;
		true->
			SceneFind = get_scene_id(Lv,Realm,SceneId,NpcId),
			get_scene_info(SceneFind,SceneIdInfo,3)
	end.
%%25副本寻路特殊处理
get_scene_id(Lv,Realm,SceneId,NpcId)->
	%%山神（30级以下寻城郊入口,其他的寻九霄入口）
	if NpcId =:= 10302 ->
		   case Lv < 30 of
			   true->
				   case Realm of
					   1->201;
					   2->281;
					   _->251
				   end;
			   false->300
		   end;
	   true->SceneId
	end.

	
%%自动寻路内容（[find]100（场景id）:目标类型（0场景1NPC2怪物）:目标id（要寻找的NPC或者怪物id）[/find]）
%%获取当前怪物所在的场景（自动寻路用）
get_mon_def_scene_info(MonId,Realm,NowScene) ->
    case lib_mon:get_scene_by_mon_id(MonId) of
        0 ->
			%%特殊处理70副本刷新出来的怪物
			case lists:member(MonId,[41103,41104,41107,41108,41109]) of
				true->{?CAVE_RES_SCENE_ID, <<"天回阵">>,0,0};
				false->
					{0,<<"找不到怪物对应的场景">>,0,0}
			end;
%%         [SceneId, X, Y] ->
		SceneIdInfo->
			[[SceneId, _, _]|_] = SceneIdInfo,
			if MonId > 49000 andalso MonId<50000 ->
				get_scene_info(SceneId,SceneIdInfo,4);
				true->
					%%200,250,280为主城id
					HomeCity=lists:member(SceneId, [200,201,250,251,280,281]),
					%%新手村
					NoviceCity = lists:member(SceneId, [100,110,111]),
					%%雷泽
%% 					LeiZeCity = lists:member(SceneId,[101,102,103]),
					if HomeCity ->
							SceneId_List = [[Id]||[Id|_]<-SceneIdInfo],
							ScenId_Realm = lib_npc:get_scene_by_realm_id(Realm),
%% 							case [ID||ID <- lists:merge(SceneId_List,ScenId_Realm),lists:member(ID,SceneId_List),lists:member(ID,ScenId_Realm)] of
							case check_same_id(SceneId_List,ScenId_Realm) of
								[] ->
									{0,<<"场景分类中没有该场景_2">>,0,0};
								SceneList->
									[[SceneId_1]|_]=SceneList,
		             				get_scene_info(SceneId_1,SceneIdInfo,5)
							end;
					   NoviceCity->
						   case lists:member(NowScene, [100,110,111]) of
							   true-> get_scene_info(NowScene,SceneIdInfo,6);
							   false->get_scene_info(SceneId,SceneIdInfo,6)
						   end;
						true ->
							get_scene_info(SceneId,SceneIdInfo,7)
					end
			end
    end.

%%获取场景信息
get_scene_info(SceneId,SceneIdInfo,Where)->
	case data_scene:get(SceneId) of
		[] ->
			Msg = io_lib:format("找不到场景信息_~p",[Where]),
			{0,Msg,0,0};
		Scene ->
			case get_point(SceneId,SceneIdInfo) of
				{error,_,_}->
					Msg = io_lib:format("找不到场景入口坐标_~p",[Where]),
					{0,Msg,0,0};
				{ok,X,Y} ->
					{SceneId, Scene#ets_scene.name, X, Y}
			end
	end.

%%获取坐标
get_point(_SceneId,[])->
	{error,0,0};
get_point(SceneId,SceneInfo)->
	[[ID,X,Y]|T]=SceneInfo,
	case SceneId=:= ID of
		true ->
			{ok,X,Y};
		false->
			get_point(SceneId,T)
	end.
	
%%获取物品名字接口
get_item_name(ItemId)->
    goods_util:get_goods_name(ItemId).

%%-------------------------------ETS处理——------------------------

%% 获取可接的任务
get_active(PS) ->
    case ets:lookup(?ETS_TASK_QUERY_CACHE, PS#player.id) of
        [] ->[];
        [{_,ActiveIds}] -> ActiveIds
    end.

%% 获取已触发任务列表
get_trigger(PS) when is_record(PS, player) ->
    ets:match_object(?ETS_ROLE_TASK, #role_task{player_id=PS#player.id, _='_'});

%% 获取已触发任务列表
get_trigger(Rid) when is_integer(Rid) ->
    ets:match_object(?ETS_ROLE_TASK, #role_task{player_id=Rid, _='_'}).

%%获取已触发当个任务
get_trigger_one(PlayerId,TaskId)->
	ets:match_object(?ETS_ROLE_TASK, #role_task{player_id=PlayerId,task_id=TaskId, _='_'}).

%%获取委托任务列表
get_consign_task(PlayerId)->
	ets:match_object(?ETS_TASK_CONSIGN,#ets_task_consign{player_id = PlayerId,_= '_'}).
%%获取单个委托任务
get_consign_task_one(PlayerId,TaskId)->
	ets:match_object(?ETS_TASK_CONSIGN,#ets_task_consign{player_id = PlayerId,task_id=TaskId,_= '_'}).

%% get_task_consign(TaskId)->
%% 	ets:match_object(?ETS_ROLE_TASK,#role_task{id=TaskId,_= '_'}).

%% 获取该阶段任务内容
get_phase(RT)->
    [[State | T] || [State | T] <- RT#role_task.mark, RT#role_task.state =:= State].

%% 获取任务阶段的未完成内容
get_phase_unfinish(RT)->
    [[State, Fin | T] || [State, Fin |T] <- RT#role_task.mark, RT#role_task.state =:= State ,Fin =:= 0].

%% 获取已完成的任务列表
get_finish(PS)when is_record(PS, player) ->
    ets:match_object(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=PS#player.id, _='_'});
get_finish(Pid) ->
    ets:match_object(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=Pid, _='_'}).

%%获取雇佣任务
get_employ_task(PlayerId)->
	ets:match_object(?ETS_ROLE_TASK,#role_task{player_id=PlayerId,type=1,_= '_'}).

%%根据任务id获取任务信息
get_one_trigger(TaskId, Rid) when is_integer(Rid) ->
    case ets:lookup(?ETS_ROLE_TASK, {Rid, TaskId}) of
        [] -> false;
        [RT] -> RT
    end;

get_one_trigger(TaskId, PS) when is_record(PS, player) ->
    case ets:lookup(?ETS_ROLE_TASK, {PS#player.id, TaskId}) of
        [] -> false;
        [RT] -> RT
    end.

get_task([])->
	false;
get_task([Task|TaskList])->
	if Task#role_task.state =:= 2->
		   get_task(TaskList);
	   true->
		   Task
	end.
	
%%获取结束任务的npcid
get_end_npc_id(TaskId, PS) ->
    case get_one_trigger(TaskId, PS) of
        false -> 0;
        RT -> get_end_npc_id(RT)
    end.

get_end_npc_id(RT) when is_record(RT, role_task)->  
    get_end_npc_id(RT#role_task.mark);

get_end_npc_id([]) -> 0;

get_end_npc_id(Mark) ->
    case lists:last(Mark) of
        [_, _, end_talk, NpcId, _] -> NpcId;
        _ -> 0  %% 这里是异常
    end.


%% 是否已触发过
in_trigger(TaskId, Rid) when is_integer(Rid)->
    ets:lookup(?ETS_ROLE_TASK, {Rid, TaskId}) =/= [];

in_trigger(TaskId, PS) ->
    ets:lookup(?ETS_ROLE_TASK, {PS#player.id, TaskId}) =/= [].

%% 是否已完成任务列表里
in_finish(TaskId, PS)->
	ets:match_object(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=PS#player.id, task_id=TaskId, _='_'}) /= [].

%% 获取今天完成某任务的数量	
get_today_count(TaskId, PS) ->
    {M, S, MS} = now(),
    {_, Time} = calendar:now_to_local_time({M, S, MS}),
    TodaySec = M * 1000000 + S - calendar:time_to_seconds(Time),
    TomorrowSec = TodaySec + 86400,
    length([0 || RTL <- get_finish(PS), TaskId=:=RTL#role_task_log.task_id, RTL#role_task_log.finish_time >= TodaySec, RTL#role_task_log.finish_time < TomorrowSec]).


%%===========================任务是否可接处理函数===========================


%%是否可以接受任务
can_trigger(TaskId, PS) ->
%% 	 ?DEBUG("lib_task/can_trigger~p~n/",[TaskId]),
	 Result = can_trigger_msg(TaskId, PS,0),
%% 	 io:format("~~~~~~~~~~~~~~~~~~can_trigger~p~n",[[TaskId,Result]]),
     Result =:= true.

can_trigger_normal(TaskId, PS,TaskType) ->
	 Result = can_trigger_msg(TaskId, PS,TaskType),
     {Result =:= true,Result}.

%%任务限制判定
can_trigger_msg(TaskId, PS,TaskType) ->
    case get_data(TaskId) of
        [] ->101;%%没有这个任务，不能接
        TD ->
			case in_trigger(TaskId, PS) of
				true -> 102;%%该任务已经触发过了，不能接！
                false ->
					case check_lvl(TD,PS#player.lv) of
						false ->103;%%您的等级不足，不能接
                		true ->
							case check_realm(TD#task.realm, PS#player.realm) of
								false -> 104;%%您的部落不符合，不能接
		                        true ->
									case check_career(TD#task.career, PS#player.career) of
										false -> 105;%%您的职业不符合，不能接！
                        		        true ->
											case check_prev_task(TD#task.prev, PS) of
												false -> 106;%%前置任务未完成，不能接
                                                true ->
													case check_repeat(TaskId, TD#task.repeat, PS) of
														false -> 107;%%不能重复接该任务
														true ->
															case check_carry(TD,PS) of  %%运镖任务处理
																{false,Reason} ->Reason;
																{true,_} ->
																	case check_cycle_link(TD,PS) of
																		false ->108;%%循环次数不对
																		true->
																			case check_business_pre(TD,PS)of
																				false->208;
																				true->
																					case check_guild_carry_pre(TD,PS) of
																						{false,GuildError}->GuildError;
																						true->
																							case check_accept_time(TD) of
																								false->211;
																								true->
																									case check_lover_task(PS,TD) of
																										false->212;
																										true->
																											length([1||ConditionItem <- TD#task.condition, check_condition(ConditionItem, TaskId, PS,TaskType)=:=false]) =:=0
																									end
																							end
																					end
																			end
																	end
															end
		                                            end
        		                            end
                		            end
                        	end
 		           end
			end
    end.

%%氏族判定
check_guild(TD,PS) ->
	case is_guild_task(TD) of
		false ->
			true;
		true ->
			case PS#player.guild_id of
				0 ->
					false;
				_ ->
					true
			end
	end.

%%运镖判定
check_carry(TD,PS)->
	case is_carry_task(TD) of
		false->
			{true,[]};
		true->
			lib_carry:check_carry(PS)
	end.

%%氏族运镖判定预处理
check_guild_carry_pre(TD,PS) ->
	case is_guild_carry_task(TD) of
		false->true;
		true->
			case  PS#player.guild_id > 0 of
				false->{false,109};
				true->
					case mod_guild:get_guild_carry_info(PS#player.guild_id) of
						[0,{}]->
							{false,109};
						[_,{_Lvevl,_Coin,CarryTime,_BanditsTime,ChiefId,DeputyId1,DeputyId2}]->
							case util:check_same_day(CarryTime) of
								true->
									{false,117};
								false->
									case lists:member(PS#player.id,[ChiefId,DeputyId1,DeputyId2]) of
										true->
											true;
										false->
											{false,118}
									end
							end
					end
			end
	end.	

%%氏族运镖判定
check_guild_carry(TD,PS)->
	case is_guild_carry_task(TD) of
		false->{true,0};
		true->
			case PS#player.carry_mark > 0 of
				true->{false,114};
				false->
					case PS#player.arena > 0 of 
						true->{false,200};
						false->
							case PS#player.status =:= 9 of
								true->{false,206};
								false->
									case PS#player.guild_id >0 of
										false->{false,109};
										true->
											case mod_guild:get_guild_carry_info(PS#player.guild_id) of
												[0,{}]->{false,109};
												[_,{Lvevl,Coin,_CarryTime,_BanditsTime,ChiefId,DeputyId1,DeputyId2}]->
													case lists:member(PS#player.id, [ChiefId,DeputyId1,DeputyId2]) of
														false->{false,118};
														true->
															Base_Coin = get_guild_carry_base_coin(guild,Lvevl),
															case Base_Coin > Coin of
																true->
																	carry_coin_unenough_guild(PS,Base_Coin),
																	{false,119};
																false->{true,Lvevl}
															end
													end
											end
									end
							end
					end
			end
	end.

%%兑换判定
check_convert(TD,PS)->
	case is_convert_task(TD) of
		true->
			case get_end_item(TD, PS) of
				[] -> true;
				GoodsList->
					check_goods_num(PS,GoodsList)
			end;
		false->
			true
	end.

check_place(TD,PS)->
	CarryTask = is_carry_task(TD),
	BusinessTask = is_business_task(TD),
	if CarryTask=:=true->
		   case lists:member(PS#player.scene,[101,190,191]) of
			   true->{true,1};
			   false->{false,209}
		   end;
	   BusinessTask =:= true ->
		   case lists:member(PS#player.scene,[300]) of
			   true->{true,1};
			   false->{false,209}
		   end; 
	   true->
		   {true,1}
	end.

check_finish_time(TD,TriggerTime,CarryMark)->
%% 	io:format("TriggerTime,CarryMark~p/~p/~p/~n",[TriggerTime,CarryMark,util:unixtime()]),
	case is_carry_task(TD) of
		false->{true,1};
		true->
			case CarryMark of
				0->{ok,1};
				_->
					case util:unixtime()-TriggerTime < 75 of
						true->{false,210};
						false->{true,1}
					end
			end
	end.

%%物品数量判定
check_goods_num(_PS,[])->
	true;
check_goods_num(PS,[GoodsInfo|GoodsList])->
	{GoodsId,Num} = GoodsInfo,
	GoodsTypeInfo = goods_util:get_goods_type(GoodsId),
	case GoodsTypeInfo#ets_base_goods.type of
		%%任务物品
		35->
			case goods_util:get_goods_num(PS#player.id, GoodsId,6) >= Num of
				true->
					check_goods_num(PS,GoodsList);
				false->
					false
			end;
		%%普通背包物品
		_->
			case goods_util:get_goods_num(PS#player.id, GoodsId,4) >= Num of
				true->
					check_goods_num(PS,GoodsList);
				false->
					false
			end
	end.

%%等级判定
check_lvl(TD,Lv)->
	case TD#task.level_limit>0 andalso TD#task.level<TD#task.level_limit of
		true->
			Lv >= TD#task.level andalso Lv<TD#task.level_limit;
		false->
			case TD#task.type of
				%%日常任务
				2->
					%%运镖/跑商/打怪/战场击杀/神岛空战任务为10级一个阶段,
					case lists:member(TD#task.child,[1,3,4,14,16]) of
						true->
							%%30级别特殊处理
				  		 if TD#task.level< 39 andalso TD#task.id=/=61021 ->
								Lv >= TD#task.level andalso Lv < 40;
%% 							TD#task.id =:= 61035->%%70日常守护任务特别处理
%% 								PS#player.lv >= 70;
							  true->
								  Lv >= TD#task.level andalso Lv < TD#task.level+10
				  		 end;
			 		  false->
						   Lv >= TD#task.level
					end;
				%%其他任务
				_->
					Lv >= TD#task.level
			end
	end.


%% 部落检测
check_realm(Realm, PSRealm) ->
    case Realm =:= 0 of
        true -> true;
        false -> PSRealm =:= Realm
    end.
%% 职业检测
check_career(Career, PSCareer) ->
    case Career =:= 0 of
        true -> true;
        false -> PSCareer =:= Career
    end.

%% 是否重复可以接
check_repeat(TaskId, Repeat, PS) ->
    case Repeat =:= 0 of
        true -> in_finish(TaskId, PS) =/= true;
        false -> true
    end.

%% 前置任务
check_prev_task(PrevId, PS) ->
    case PrevId =:= 0 of
        true -> true;
        false -> in_finish(PrevId, PS)
    end.

%%检查可接时间
check_accept_time(TD)->
	if TD#task.time_start=:=0 orelse TD#task.time_end=:=0 ->true;
	   true->
		   NowTime = util:unixtime(),
		   NowTime > TD#task.time_start andalso NowTime<TD#task.time_end
	end.

%%爱侣任务
check_lover_task(PS,TD)->
	case is_lover_task(TD)of
		false->true;
		true->
			 if PS#player.couple_name =/=<<>> andalso PS#player.couple_name =/=[]->
					Times = check_daily_times(TD#task.condition),
					lib_love:check_lover_task_times(PS#player.id,Times);
				true->false
			 end
	end.

%%
%%循环任务链判定
check_cycle_link(TD,PS)->
	case is_cycle_task(TD) of
		false->true;
		true->
%% 			false
			case TD#task.id of
				70100->
					IdList = data_task:task_get_cycle_id_list(),
					FirstCycle = get_today_count(70100, PS),
					Times = [get_today_count(Id, PS)||Id<-IdList],
					case lists:all(fun(M)-> M==FirstCycle end,Times) of
						true->true;
						false->
							case (get_today_count(70106, PS) - FirstCycle)>0 of
								true->true;
								false->false
							end
					end;
				_->
					get_today_count(TD#task.prev,PS)>get_today_count(TD#task.id,PS)
			end
	end.

%% 能否触发任务的其他非硬性影响条件
trigger_other_condition(Start_item, PS) ->
 	Items = get_start_award_item(Start_item, PS),
	case length(Items) of
		0->true;
		Num->
    		case gen_server:call(PS#player.other#player_other.pid_goods, {'cell_num'}) < Num of
        		true -> false; %% 空位不足，放不下触发时能获得的物品
        		false -> true
			end
    end.

%%=======================判定任务类型函数========================

%%检查是否主线任务
is_main_task(TD)->
	TD#task.type =:= 0 orelse TD#task.type == 4.

%%检查是否普通日常任务
is_normal_daily_task(TD)->
	case TD#task.type =:=2 of
		false->false;
		true->
			if TD#task.child=:=1 orelse TD#task.child=:=6 ->
				   if TD#task.kind=:=1 ->true;
					  true->false
				   end;
			   true->false
			end
	end.

%%普通日常打怪
is_daily_pk_mon_task(TD)->
	TD#task.type =:= 2 andalso TD#task.child=:=1.

%%运镖任务判定
is_carry_task(TD)->
	TD#task.type =:= 2 andalso TD#task.child=:=3.

%%氏族运镖判定
is_guild_carry_task(TD)->
	TD#task.type =:= 2 andalso TD#task.child=:=15.

%%副本任务
is_dug_task(TD)->
	TD#task.type =:= 2 andalso TD#task.child =:= 6.
%%跑商任务判定
is_business_task(TD) ->
	TD#task.type =:= 2 andalso TD#task.child =:= 4.

%%循环任务判定
is_cycle_task(TD)->
	if TD#task.id =:= 70100->true;
	   true->
			TD#task.type =:= 5 andalso TD#task.child=:=22
	end.

%%氏族任务判定
is_guild_task(TD) ->
	TD#task.type =:= 3.

%%护送任务判定
is_convoy_task(TD)->
	TD#task.child =:= 7.

%%兑换任务
is_convert_task(TD)->
	TD#task.child =:= 11.

%%英雄帖任务
is_hero_task(TD)->
	TD#task.type =:= 2 andalso TD#task.child =:= 17.

%%情缘任务
is_love_task(TD)->
	TD#task.type =:= 2 andalso TD#task.child =:= 18.

%%修为任务
is_culture_task(TD)->
	TD#task.type =:= 2 andalso TD#task.child =:= 5.

%%随机循环
is_random_cycle(TD)->
	TD#task.type =:=5 andalso TD#task.child =:= 21.

%%爱侣任务
is_lover_task(TD)->
	TD#task.type =:= 2 andalso TD#task.child =:= 32.

%%点名任务
is_appoint_task(TD)->
	TD#task.type =:= 2 andalso TD#task.child =:= 39.


check_business(TD,PS,Color)->
	case is_business_task(TD) of
		false->
			%%io:format("1386~n"),
			{true,0};
		true->
			case PS#player.carry_mark > 0 of
			   false ->
				   case Color > 0 of
					   true -> case lib_business:check_business(PS,Color) of
								   {true,CarClor} ->
									   {true,CarClor};
								   {false,Error} -> 
									   %%mat("1395 error = ~p~n",[Error]),
									   {false,Error}
							   end;
					   false ->
						   %%mat("1399~n"),
						   {false,207}
				   end;	   
			   true->
				   %%mat("1404~n"),
				   {false,207}
			end
	end.

%%是否可接跑商任务
check_business_pre(TD,PS)->
	case is_business_task(TD) of
		false->true;
		true->
			case lib_business:check_business(PS,10000) of
				{true,_}->true;
				{false,_}->false
			end
	end.

%%======================================接受任务处理函数========================
%% 接受任务
trigger(TaskId, Color, PS, TaskType) ->
    normal_trigger(TaskId, Color, PS, TaskType).

normal_trigger(TaskId, Color, PStatus,TaskType) ->
    case can_trigger_normal(TaskId, PStatus,TaskType) of
        {false,Reason}  ->
			%%io:format("1423~n"),
            {false,Reason};
        {true,_} ->
			TD = get_data(TaskId),
			case check_guild(TD,PStatus) of
				false->
					%%io:format("1428~n"),
					{false,109};%%<<"您还没有加入氏族，不能接！">>
				true ->
					case check_convert(TD,PStatus) of
						
						false ->
							%%io:format("1435~n"),
							{false,110};%%<<"兑换物品数量不足！">>
						true->
%% 							case is_carry_task(TD)=:=true andalso PStatus#player.status=:= 9 of
%% 								true->{false,206};
%% 								false->
							%%检查氏族运镖
							case check_guild_carry(TD,PStatus) of
								{false,GuildCarryError}->{false,GuildCarryError};
								{true,GuildLv}->
									Gold_Need = get_cash_need(PStatus,TD,GuildLv),
									case Gold_Need > PStatus#player.coin of
										true ->
											carry_coin_unenough(PStatus,Gold_Need),
											{false,111};
										false->
											%%检查跑商
											case check_business(TD,PStatus,Color) of
												
												{false,BusinessFail}->
													%%mat("1447~p~n",[BusinessFail]),
													{false,BusinessFail};
												{true,CarColor}->
													case check_place(TD,PStatus) of
														{false,TaskFail}->
															%%io:format("1447~n"),
															{false,TaskFail};
														{true,_}->
															PS = lib_player:add_coin(PStatus, -Gold_Need),
															case is_carry_task(TD) orelse is_guild_carry_task(TD) of
																true->
																carry_coin_del(PS,Gold_Need);
																false->skip
															end,
															case trigger_other_condition(TD#task.start_item, PS) of
				    			        		    		false ->
                                                                    %%io:format("1472~n"),
																	{false, 112};%%<<"您的背包空间不足，不能接!">>
        					    		    				true ->
															%% 任务开始给予物品
					    				            	   	get_goods_by_accept_task(PS,TD),
															%%更新任务缓存
															Content = get_task_content(PS#player.id,TD),
		    						    				    ets:insert(?ETS_ROLE_TASK, #role_task{id={PS#player.id, TaskId},
                	    		    									player_id=PS#player.id ,task_id = TaskId, 
        		    	        		    							trigger_time = util:unixtime(), state=0,
				    	        	    			        			end_state=TD#task.state,mark = Content,type=TaskType
		        								            	}),
														  %%io:format("TD#task.content___~p~n",[Content]),
															%%更新数据库
															 mod_task_cache:add_trigger(PS#player.id, TaskId, util:unixtime(), 0, 
																							TD#task.state, Content,TaskType,[]),
															%%刷新任务列表
							        				    	refresh_active(PS),
															%%一些特殊任务处理
															{ok,NewPS} = special_treat(PS,TD,CarColor),
															 	%%保存玩家数据
															case PS =/= NewPS of
																true->
													 				save_player_table(NewPS,PS,sub);
																false->
																	skip
															end,	
															case TD#task.end_talk=:=0 andalso TD#task.unfinished_talk=:=0 of
																true->
																	finish(TaskId,null,NewPS);
																false->
																		{true, NewPS}
															end
														end
%% 												end
											end
									end
 		   	 			       end
						end
				end
			end
    end.
	
%%获取任务内容
get_task_content(PlayerId,Td)->
	case is_random_cycle(Td) of
		false->
			case is_lover_task(Td) of
				false->
					case is_appoint_task(Td) of
						true->
							Content = lists:reverse(Td#task.content),
							EndContent = lists:nth(1, Content),
							NewContent = lists:delete(EndContent, Content),
							RandomContent = lib_love:update_lover_task(PlayerId,NewContent),
							lists:reverse([EndContent|RandomContent]);
						false->
							Td#task.content
					end;
				true->
					Content = lists:reverse(Td#task.content),
					EndContent = lists:nth(1, Content),
					NewContent = lists:delete(EndContent, Content),
					RandomContent = lib_love:update_lover_task(PlayerId,NewContent),
					lists:reverse([EndContent|RandomContent])
			end;
		true->
			%%随机循环任务处理（在多个任务内容中随机其中一个出来）
			Content = lists:reverse(Td#task.content),
			EndContent = lists:nth(1, Content),
			NewContent = lists:delete(EndContent, Content),
			RandomContent = util:get_random_list(NewContent,1),
			lists:reverse([EndContent|RandomContent])
	end.


%%触发任务获得物品
get_goods_by_accept_task(PlayerStatus,TD)->
	case get_start_award_item(TD#task.start_item, PlayerStatus) of
		[] -> false;
		Items ->
			F = fun(GoodsTypeId, GoodsNum) ->
						GoodsTypeInfo = goods_util:get_goods_type(GoodsTypeId),
						case GoodsTypeInfo#ets_base_goods.type of
							35->
								gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'give_task_goods', PlayerStatus, GoodsTypeId, GoodsNum});
							_TypeId->
								case lists:member(GoodsTypeId,[16009]) of
									true->
										lib_mount:add_active_type(PlayerStatus,[16010]);
%% 										ExpireTime = util:unixtime()+get_goods_expire_time(GoodsTypeId),
%% 										gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'give_goods', PlayerStatus, GoodsTypeId, GoodsNum,2,ExpireTime});
									false->
										gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'give_goods', PlayerStatus, GoodsTypeId, GoodsNum,2})
								end
						end
				end,
			[F(Id, Num) || {Id, Num} <- Items]
	end.

%%任务特殊处理
special_treat(PS,TD,Color)->
	%更新接镖状态
	case is_carry_task(TD) of
		true ->
			{ok,PS1} = lib_carry:update_carry_info(PS,1),
			PS2 = lib_player:count_player_speed(PS1),
			{ok,PS2};
	    false->
			%%更新护送状态
		   case is_convoy_task(TD) of
			   true ->
				   convoy_npc_start(PS,TD#task.start_npc);
			   false ->
				   %%更新氏族运镖状态(镖旗处理)
				   case is_guild_carry_task(TD) of
					   true-> 
						   {ok,PS1} = lib_carry:update_carry_info(PS,3),
						   PS2 = lib_player:count_player_speed(PS1),
						   {ok,PS2};
					   false->
						   case is_business_task(TD) of
							   true->
								   {ok,PS1} = lib_business:update_business_info(PS,Color),
								   PS2 = lib_player:count_player_speed(PS1),
								   {ok,PS2};
							   false->
								   {ok,PS}
						   end
				   end
		   end
	end.

%% %%某个任务触发一些东西
%% task_give_some_goods(PS,TD)->
%% 	case TD#task.kind  of
%% 		9 ->
%% 			%%直接生成一个灵兽的
%% 			lib_pet:give_pet_task(PS#player.id),
%% 			ok;
%% %% 		15 ->
%% %% 			event(up_skill,null,PS#player.id),
%% %% 			ok;
%% 		_->
%% 			ok
%% 	end.

%获得灵兽任务
get_a_pet(PlayerStatus,ItemList)->
	[{GoodsId,_}|_] = ItemList,
	case GoodsId=:=27003 of 
		true->
			%%新手灵兽，龙宝宝
			lib_pet:give_pet_task(PlayerStatus#player.id,24617),
			gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'delete_task_goods', 27036,1});
		false->skip
	end.

%%对话获得物品
get_goods_from_talk(TaskId,PS)->
	TD = get_data(TaskId), 
	case get_talk_award_item(TD, PS) of
		[] -> false;
		Items ->
			F = fun(GoodsTypeId, GoodsNum) ->
						GoodsTypeInfo = goods_util:get_goods_type(GoodsTypeId),
						case GoodsTypeInfo#ets_base_goods.type of
							35->
								gen_server:call(PS#player.other#player_other.pid_goods, {'give_task_goods', PS, GoodsTypeId, GoodsNum});
							_TypeId->
								gen_server:call(PS#player.other#player_other.pid_goods, {'give_goods', PS, GoodsTypeId, GoodsNum,2})
						end
			    end,
			[F(Id, Num) || {Id, Num} <- Items]
     end.

%%第一个任务(在玩家注册完毕之后调用)
first_task(PlayerId)->
	TD = get_data(20100),
	NowTime = util:unixtime(),
	ets:insert(?ETS_ROLE_TASK,#role_task{id={PlayerId, 20100},player_id=PlayerId ,
                        task_id = 20100, trigger_time = NowTime, 
                        state=0,end_state=TD#task.state,mark = TD#task.content,type=0,other=[]
                    }),
%% 	Rid, Tid, TriggerTime, TaskState, TaskEndState, TaskMark,TaskType
	Data = [PlayerId, 20100, NowTime, 0, TD#task.state, TD#task.content,0,[]],
 	erlang:spawn(db_agent,syn_db_task_bag_insert,[Data]),
%% 	mod_task_cache:add_trigger(PlayerId, 20100, NowTime, 0,TD#task.state, TD#task.content,0),
	ok.

%% 触发并完成任务
trigger_and_finish(TaskId, _ParamList, PStatus) ->
	case can_trigger_normal(TaskId, PStatus,0) of
        {false,Reason}  ->
            {false,Reason};
        {true,_} ->
			TD = get_data(TaskId),
			case check_guild(TD,PStatus) of
				false->{false,109};
			true ->
				case check_convert(TD,PStatus) of
					false ->{false,110};
					true->
						case award_condition(TD, PStatus) of
                			{false, Reason} -> {false, Reason};
                			{true, _PlayerStatus} ->
								case check_end_cost(PStatus,TD) of
									{false,NewReason} ->{false,NewReason};
									{true,PlayerStarus}->
										Gold_Need = get_cash_need(PStatus,TD,0),
										case Gold_Need > PlayerStarus#player.coin of
											true ->
%% 												Tips = io_lib:format("您的任务押金不足~p，不能接！",[Gold_Need]),
												carry_coin_unenough(PStatus,Gold_Need),
												{false,111};
											false->
												PS = lib_player:add_coin(PlayerStarus, -Gold_Need),
												case is_carry_task(TD) of
													true->
														carry_coin_del(PStatus,Gold_Need);
													false->skip
												end,
%% 	       			     						case trigger_other_condition(TD#task.start_item, PS) of
%%     	    		        						false -> {false, 112};
%%         	 			       						true ->
														Time = util:unixtime(),
				        		            			ets:insert(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=PStatus#player.id, 
																	task_id=TaskId, trigger_time = Time, finish_time = Time}),
        		        		    					mod_task_cache:add_log(PStatus#player.lv, PStatus#player.other#player_other.pid, PStatus#player.id,TaskId, TD#task.type, Time, Time),
														%% 任务开始给予物品
        		        	   							get_goods_by_accept_task(PS,TD),
														%%一些特殊任务处理
														{ok,NewPS} = special_treat(PS,TD,0),
														%% 回收物品
														get_goods_back(NewPS,TD),
				        		            			%% 奖励固定物品
        				        		    			award_goods(NewPS,TD),
														%%增加氏族经验
		                		   						add_guild_exp(NewPS,TD),
														%%增加灵力
        				            					PlayerStatus_1 = add_spirit(NewPS,TD),
														%%增加绑定铜
														PlayerStatus_2 = add_bind_coin(PlayerStatus_1,TD),
														%%增加修为
														PlayerStatus_3 = add_culture(PlayerStatus_2,TD),
														%%增加经验和铜钱
														PlayerStatus_4=add_exp_and_coin(PlayerStatus_3,TD),
														case is_convoy_task(TD) of
														true->
															{ok,PlayerStatus_5} = convoy_npc_finish(PlayerStatus_4);
														false->
															PlayerStatus_5 = PlayerStatus_4
														end,
														PlayerStatus_6 = add_honor(PlayerStatus_5,TD),
														PlayerStatus_7 = add_realm_honor(PlayerStatus_6,TD),
				        		            			LastPlayerStatus = PlayerStatus_7,
														%%刷新任务
				        		            			refresh_active(LastPlayerStatus),
														%%回收任务物品
														retrieve_task_goods(LastPlayerStatus,TD),
                				    					case LastPlayerStatus =/= PStatus of
		                        							true -> 
																case TD#task.end_cost > TD#task.coin of
																	true->
								   										SaveType=sub;
							   										false->
								   										SaveType = add
																end,
															save_player_table(LastPlayerStatus,PStatus,SaveType);
        				                					false -> ok
                				    					end,					
				        		            			{true, LastPlayerStatus}
%%      					       				end
										end
								end
						end
				end
			end
    end.

%%=============================任务预完成处理函数======================

%% 有部分任务内容在触发的时候可能就完成了
preact_finish(PS)  ->
    lists:member(true, [preact_finish(RT, PS) || RT <- get_trigger(PS#player.id)]).

preact_finish(TaskId, PS) when is_integer(TaskId) ->
    preact_finish(get_one_trigger(TaskId, PS), PS);

preact_finish(RT, PS) ->
    lists:member(true, [preact_finish_check([State, Fin | T], PS) || 
						  [State, Fin | T] <- RT#role_task.mark, State =:= RT#role_task.state, Fin =:= 0]).


%% 收集物品
preact_finish_check([_, 0, item, ItemId, _, NowNum | _], PS) ->
    Num = goods_util:get_goods_num(PS#player.id, ItemId,6),
    case Num >  NowNum of
        false -> false;
        true -> 
			event(item, [{ItemId, Num}], PS)
    end;
%%采集物品
preact_finish_check([_, 0, collect, ItemId, _, NowNum | _], PS) ->
    Num = goods_util:get_goods_num(PS#player.id, ItemId,6),
    case Num >  NowNum of
        false -> false;
        true -> event(collect, [{ItemId, Num}], PS)
    end;

%%学习技能
preact_finish_check([_,0,learn_skill,SkillId|_],PS) ->
	case lib_skill:get_all_skill(PS#player.id) of
		[]->
			false;
		_->
			event(learn_skill, {SkillId}, PS)
	end;

%%融入氏族
preact_finish_check([_,0,guild|_],PS) ->
	case PS#player.guild_id of
		0->
			false;
		_->
			event(guild, null, PS)
	end;

%%灵兽召唤
preact_finish_check([_,0,pet|_],PS) ->
	case PS#player.other#player_other.out_pet of
		[]->
			false;
		_->
			event(pet, null, PS)
	end;

%%拜师
preact_finish_check([_,0,master|_],PS)->
	case mod_master_apprentice:get_master_info(PS#player.id)=:=[] of
		false->
			event(master, null, PS);
		true->
			case mod_master_apprentice:get_own_master_id(PS#player.id)=:=0 of
				false->
					event(master, null, PS);
				true->
					case mod_master_apprentice:is_enter_master_charts(PS#player.id) of
						true->
							event(master,null,PS);
						false->
							false
					end
			end
	end;

%%商城购买
preact_finish_check([_,0,shopping,GoodsId|_],PS)->
	case db_agent:check_goods_shop(PS#player.id,GoodsId) of
		[]->false;
		_->
			event(shopping, {GoodsId}, PS)
	end;

%%升级
preact_finish_check([_,0,up_level,Level|_],PS)->
	case PS#player.lv>=Level of
		false->false;
		true->
			event(up_level, {PS#player.lv}, PS)
	end;

%%学习被动技能
preact_finish_check([_,0,passive_skill|_],PS) ->
	case db_agent:get_all_skill(PS#player.id,3) of
		[]->
			false;
		_->
			event(passive_skill, null, PS)
	end;
%%坐骑出战
preact_finish_check([_,0,mount_fight|_],PS) ->
	case lib_mount:get_out_mount(PS#player.id) of
		[]->
			false;
		_->
			event(mount_fight, null, PS)
	end;

%%使用桃子
preact_finish_check([_, 0, use_peach, _ItemId, _, _NowNum | _], PS) ->
    Num = lib_activity:check_player_activity(PS#player.id, peach),
    event(use_peach, [Num], PS);

%%在线3小时
preact_finish_check([_,0,online_time|_],PS)->
	case lib_activity:check_player_activity(PS#player.id, online) of
		true->event(online_time,null,PS);
		false->skip
	end;

%%活跃度100
preact_finish_check([_,0,online_100|_],PS)->
	case lib_activity:check_player_activity(PS#player.id, act) >= 100 of
		true-> event(online_100,null,PS);
		false->skip
	end;

%%商城任意购物
%% preact_finish_check([_,0,buy_anything|_],PS)->
%% 	case lib_activity:check_player_activity(PS#player.id, shop) of
%% 		true->event(buy_anything,null,PS);
%% 		false->skip
%% 	end;

%%通关试炼副本
preact_finish_check([_,0,lover_train|_],PS)->
	case lib_dungeon:get_dungeon_times(PS#player.id,PS#player.lv, 901) >=1  of
		true->
			event(lover_train,null,PS);
		false->skip
	end;
		

preact_finish_check(_, _) ->
    false.

%% 检测任务是否完成
is_finish(TaskId, PS) when is_integer(TaskId) ->
    case get_one_trigger(TaskId, PS) of
        false -> false;
        RT -> is_finish(RT, PS)
    end;

is_finish(RT, PS) when is_record(RT, role_task) ->
    is_finish_mark(RT#role_task.mark, PS);

is_finish(Mark, PS) when is_list(Mark) ->
    is_finish_mark(Mark, PS).

is_finish_mark([], _) ->
    true;
is_finish_mark([MarkItem | T], PS) ->
    case check_content(MarkItem, PS) of
        false -> false;
        true -> is_finish_mark(T, PS)
    end.

%%=====================================完成任务处理函数=====================
%% 完成任务
finish(TaskId, ParamList, PS) ->
	normal_finish(TaskId, ParamList, PS).


%%运镖任务失败
task_carry_lose(PS)->
	Task_List = get_trigger(PS),
	Task_Id= [TD#role_task.task_id||TD<-Task_List],
	Carry_Id = data_task:task_get_carry_id_list(PS#player.realm),
	GuildCarry = data_task:task_get_guild_carry_id_list(PS#player.realm),
	Carry_List = Carry_Id++GuildCarry,
%% 	case [ID||ID <- lists:merge(Task_Id,Carry_List),lists:member(ID,Task_Id),lists:member(ID,Carry_List)] of
	case check_same_id(Task_Id,Carry_List) of
		[] ->
			PS;
		[TaskId|_]->
			{ok,NewPS_1} = lib_carry:finish_carry(PS),
			 NewPS=lib_player:count_player_speed(NewPS_1),
			case normal_finish(TaskId,0,NewPS) of
				{false,_} ->
					NewPS;
				{true,NPS} ->
					refresh_task(NPS),
					NPS
			end
	end.
	

normal_finish(TaskId, _ParamList, PlayerStatus) ->
    case is_finish(TaskId, PlayerStatus) of
        false -> {false, 201};%%<<"任务未完成！">>
        true ->
            TD = get_data(TaskId),
            case award_condition(TD, PlayerStatus) of
                {false, Reason} -> {false, Reason};
                {true, _PlayerStatus} ->
					case check_end_cost(PlayerStatus,TD) of
						{false,NewReason} ->{false,NewReason};
						{true,PlayerStarus_0}->
							RT = get_one_trigger(TaskId, PlayerStarus_0),
							case is_record(RT,role_task) of
								true->
									%%检查任务时间
									case check_finish_time(TD,RT#role_task.trigger_time,PlayerStatus#player.carry_mark) of
										{false,ErrorCarry}->{false,ErrorCarry};
										_->
									LastPlayerStatus_1 = case RT#role_task.type of
										0->
											%%51活动接口
											holiday_award(PlayerStatus,TD),
											Time = util:unixtime(),
											%%更新缓存
 			    		           		    ets:delete(?ETS_ROLE_TASK, {PlayerStatus#player.id, TaskId}),
				        		            ets:insert(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=PlayerStatus#player.id, 
														task_id=TaskId, trigger_time = RT#role_task.trigger_time, finish_time = Time}),
	
		   			             		    %% 数据库回写
						                    mod_task_cache:del_trigger(PlayerStatus#player.id, TaskId),
     					   		            mod_task_cache:add_log(PlayerStatus#player.lv, PlayerStatus#player.other#player_other.pid, PlayerStatus#player.id, TaskId, TD#task.type,RT#role_task.trigger_time, Time),
		                    				%% 回收物品
											get_goods_back(PlayerStarus_0,TD),
						                    %% 奖励固定物品
        						            award_goods(PlayerStarus_0,TD),
											%%增加氏族经验
						                    add_guild_exp(PlayerStarus_0,TD),
											%%增加灵力
        						            PlayerStatus_1 = add_spirit(PlayerStarus_0,TD),
											%%增加绑定铜
											PlayerStatus_2 = add_bind_coin(PlayerStatus_1,TD),	
											%%增加修为
											PlayerStatus_3 = add_culture(PlayerStatus_2,TD),
											%%增加经验和铜钱
											PlayerStatus_4=add_exp_and_coin(PlayerStatus_3,TD),
											case is_convoy_task(TD) of
												true->
													{ok,PlayerStatus_5} = convoy_npc_finish(PlayerStatus_4);
												false->
													PlayerStatus_5 = PlayerStatus_4
											end,
											PlayerStatus_6 = add_honor(PlayerStatus_5,TD),
											PlayerStatus_7 = add_realm_honor(PlayerStatus_6,TD),
        				        		    LastPlayerStatus = PlayerStatus_7,
		                				   
											%%刷新任务
		                				    refresh_active(LastPlayerStatus),
											%%回收任务物品
											retrieve_task_goods(LastPlayerStatus,TD),
											appoint_award(LastPlayerStatus#player.nickname,RT),
											LastPlayerStatus;
										_->
											finish_task_consign(PlayerStatus,RT)
									end,
		        		            %% 完成后一些特殊操作
        		        		    %flush_ets(RS),
		                		    case LastPlayerStatus_1 =/= PlayerStatus of
        		                		true -> 
											case TD#task.end_cost > TD#task.coin of
												true->
						   							SaveType=sub;
					   							false->
								   				SaveType = add
											end,
											save_player_table(LastPlayerStatus_1,PlayerStatus,SaveType);
        		        		        false -> ok
 			               		    end,					
				                    {true, LastPlayerStatus_1}
									end;
								false->
									{false,205}
							end
        		    end
			end
    end.

%%立即完成任务(测试接口)
finish_now(PlayerStatus,TaskId)->
	TD = get_data(TaskId),
	case is_normal_daily_task(TD) of
		false->{false,PlayerStatus};
		true->
			Time = util:unixtime(),
            RT = get_one_trigger(TaskId, PlayerStatus),
			%%更新缓存
            ets:delete(?ETS_ROLE_TASK, {PlayerStatus#player.id, TaskId}),
            ets:insert(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=PlayerStatus#player.id, 
								task_id=TaskId, trigger_time = RT#role_task.trigger_time, finish_time = Time}),

            %% 数据库回写
            mod_task_cache:del_trigger(PlayerStatus#player.id, TaskId),
            mod_task_cache:add_log(PlayerStatus#player.lv, PlayerStatus#player.other#player_other.pid, PlayerStatus#player.id, TaskId, TD#task.type,RT#role_task.trigger_time, Time),
			%% 回收物品
			get_goods_back(PlayerStatus,TD),
            %% 奖励固定物品
            award_goods(PlayerStatus,TD),
			%%增加氏族经验
            add_guild_exp(PlayerStatus,TD),
			%%完成任务扣除铜钱
			PlayerStatus1 = finish_del_coin(PlayerStatus,TD),
			%%增加灵力
            PlayerStatus_1 = add_spirit(PlayerStatus1,TD),
			%%增加绑定铜
			PlayerStatus_2 = add_bind_coin(PlayerStatus_1,TD),
			%%增加修为
			PlayerStatus_3 = add_culture(PlayerStatus_2,TD),
			%%增加经验和铜钱
			PlayerStatus_4=add_exp_and_coin(PlayerStatus_3,TD),
			LastPlayerStatus = PlayerStatus_4,
          
			%%刷新任务
            refresh_active(LastPlayerStatus),
			%%回收任务物品
			retrieve_task_goods(LastPlayerStatus,TD),
            %% 保存玩家数据
            case LastPlayerStatus =/= PlayerStatus of
				true ->
					case TD#task.end_cost > TD#task.coin of
						true->
						   SaveType=sub;
					    false->
						   SaveType = add
					end,
					save_player_table(LastPlayerStatus,PlayerStatus,SaveType);
                false -> skip
			end,	
			{true, LastPlayerStatus}
	end.

%%立即完成跑商任务{1完成，2您当前没有跑商任务，3任务不存在，4该任务不是跑商任务,5元宝不足,6该场景不能立即完成任务}
finish_business_task(PlayerStatus,TaskId)->
	case lists:member(PlayerStatus#player.carry_mark,[4,5,6,7]) of
		false->{2,PlayerStatus};
		true->
			%%只能在九霄完成任务
			if PlayerStatus#player.scene =/= 300->{6,PlayerStatus};
			   true->
					case get_data(TaskId) of
						[]->{3,PlayerStatus};
						TD->
							case is_business_task(TD) of
								false->{4,PlayerStatus};
								true->
									case get_one_trigger(TaskId, PlayerStatus) of
										false->{2,PlayerStatus};
										RT->
											case goods_util:is_enough_money(PlayerStatus,50,gold) of
												false->{5,PlayerStatus};
												true->
													Time = util:unixtime(),
													%%更新缓存
													ets:delete(?ETS_ROLE_TASK, {PlayerStatus#player.id, TaskId}),
				        				   		    ets:insert(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=PlayerStatus#player.id, 
																						  task_id=TaskId, trigger_time = RT#role_task.trigger_time, finish_time = Time}),
													%% 数据库回写
													mod_task_cache:del_trigger(PlayerStatus#player.id, TaskId),
													mod_task_cache:add_log(PlayerStatus#player.lv, PlayerStatus#player.other#player_other.pid, PlayerStatus#player.id, TaskId, TD#task.type,RT#role_task.trigger_time, Time),
		                		    				%% 回收物品
													get_goods_back(PlayerStatus,TD),
													%% 奖励固定物品
													award_goods(PlayerStatus,TD),
													%%增加氏族经验
													add_guild_exp(PlayerStatus,TD),
													%%增加灵力
													PlayerStatus_1 = add_spirit(PlayerStatus,TD),
													%%增加绑定铜
													PlayerStatus_2 = add_bind_coin(PlayerStatus_1,TD),	
													%%增加修为
													PlayerStatus_3 = add_culture(PlayerStatus_2,TD),
													%%增加经验和铜钱
													PlayerStatus_4=add_exp_and_coin(PlayerStatus_3,TD),
													PlayerStatus_5 = add_honor(PlayerStatus_4,TD),
													PlayerStatus_6= add_realm_honor(PlayerStatus_5,TD),
        						        		    LastPlayerStatus = PlayerStatus_6,
													%%刷新任务
		                						    refresh_active(LastPlayerStatus),
													%%回收任务物品
													retrieve_task_goods(LastPlayerStatus,TD),
													%% 完成后一些特殊操作
        				        		    		%flush_ets(RS),
		        		        		    		case LastPlayerStatus =/= PlayerStatus of
        		        		        				true -> 
															case TD#task.end_cost > TD#task.coin of
																true->
						   											SaveType=sub;
							   									false->
										   						SaveType = add
															end,
															save_player_table(LastPlayerStatus,PlayerStatus,SaveType);
														false -> ok
													end,
													NewPlayerStatus = lib_goods:cost_money(LastPlayerStatus,50,gold,3011),
													{1, NewPlayerStatus}
											end
									end
							end
					end
			end
	end.

%%自动完成任务
auto_finish_task(PlayerStatus,TaskId)->
	case lib_task:finish(TaskId, 0, PlayerStatus) of
	{true, NewPlayerStatus} ->
			%通知客户端刷新任务列表
			{ok, BinData} = pt_30:write(30006, [1,0]),
			lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, BinData),
			case lists:member(TaskId,[83150]) of
				true->skip;
				false->
					mod_task:next_task_cue(PlayerStatus,TaskId,0)
			end,
			{ok,NewPlayerStatus};
		_ ->
			{ok,PlayerStatus}
	end.

%%回收物品
get_goods_back(PlayerStatus,TD)->
	case get_end_item(TD, PlayerStatus) of
		[] -> false;
		EndItems ->
			Fun = fun(GoodsTypeId, GoodsNum) ->
						  GoodsTypeInfo = goods_util:get_goods_type(GoodsTypeId),
						  case GoodsTypeInfo#ets_base_goods.type of
							  35->
								  gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
												   {'delete_task_goods', GoodsTypeId,GoodsNum});
								_->
									gen_server:call(PlayerStatus#player.other#player_other.pid_goods, 
													{'delete_more', GoodsTypeId,GoodsNum})
							end
				end,
			[Fun(Id, Num) || {Id, Num} <- EndItems]
    end.

%%完成任务扣除铜钱
finish_del_coin(PlayerStatus,TD)->
	case TD#task.end_cost>0 of
		true -> lib_player:add_coin(PlayerStatus, -TD#task.end_cost);
		false ->PlayerStatus
	end.

%%物品奖励
award_goods(PlayerStatus,TD)->
	%% 奖励固定物品
    case get_award_item(TD, PlayerStatus) of
		[] -> false;
		Items ->
			F = fun(GoodsTypeId, GoodsNum) ->
						%%飞行坐骑
						case lists:member(GoodsTypeId,[16009]) of
							true->
								lib_mount:add_active_type(PlayerStatus,[16010]);
%% 								ExpireTime = util:unixtime()+get_goods_expire_time(GoodsTypeId),
%% 								gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'give_goods', PlayerStatus, GoodsTypeId, GoodsNum,2,ExpireTime});
							false->
								gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'give_goods', PlayerStatus, GoodsTypeId, GoodsNum,2})
						end,
%% 						gen_server:call(PlayerStatus#player.other#player_other.pid_goods, 
%% 										{'give_goods', PlayerStatus, GoodsTypeId, GoodsNum,2}),
						case lists:member(GoodsTypeId, [19036,19037,19038,19039,19040]) of
							false->skip;
							true->
								NameColor = data_agent:get_realm_color(PlayerStatus#player.realm),
								Msg = io_lib:format("玩家[<a href='event:1,~p, ~s, ~p,~p'><font color='~s'><u>~s</u></font></a>]在商城中购买了【~s】完成神兵利器任务,并获得传说的神器【~s】,能力大大的提升！",
								[PlayerStatus#player.id,PlayerStatus#player.nickname,PlayerStatus#player.career,PlayerStatus#player.sex,NameColor,PlayerStatus#player.nickname,goods_msg(21101,PlayerStatus#player.id),goods_msg(GoodsTypeId,PlayerStatus#player.id)]),
								lib_chat:broadcast_sys_msg(2,Msg)
						end
                end,
			[F(Id, Num) || {Id, Num} <- Items]
	end.

%%获取物品过期时间
get_goods_expire_time(GoodsId)->
	_OtherData = goods_util:get_goods_other_data(GoodsId),
	_Ovalue = goods_util:parse_goods_other_data(_OtherData,expiretime),
	_Ovalue.

%%物品信息
goods_msg(GoodsId,PlayeId)->
	GiveGoodsInfo = goods_util:get_new_goods_by_type(GoodsId,PlayeId),
%% 	io:format("GiveGoodsInfo~p~n",[GiveGoodsInfo]),
	io_lib:format("<a href='event:2,~p,~p,1'><font color='~s'> <u> ~s </u> </font></a>",
												[GiveGoodsInfo#goods.id, PlayeId, goods_util:get_color_hex_value(GiveGoodsInfo#goods.color), goods_util:get_goods_name(GoodsId)]).
%%增加氏族经验和贡献
add_guild_exp(PlayerStatus,TD)->
	case TD#task.contrib > 0 orelse TD#task.guild_exp>0 orelse TD#task.guild_coin>0 of
		true -> 
			case is_guild_carry_task(TD) of
				true->
					if  PlayerStatus#player.carry_mark>0 ->
							mod_guild:increase_guild_exp(PlayerStatus#player.id, PlayerStatus#player.guild_id, 
											 TD#task.guild_exp, TD#task.contrib,TD#task.guild_coin,1);
						true->skip
					end;
				false->
					mod_guild:increase_guild_exp(PlayerStatus#player.id, PlayerStatus#player.guild_id, 
											 TD#task.guild_exp, TD#task.contrib,TD#task.guild_coin,0)
			end;
        false -> skip
    end.

%%增加灵力
add_spirit(PlayerStatus,TD)->
	case is_business_task(TD) of
		true->
			{_Exp,Spt} = lib_business:get_business_award(PlayerStatus#player.id,PlayerStatus#player.lv),
			lib_player:add_spirit(PlayerStatus,Spt);
		false->
			case is_love_task(TD)of
				true->
					{_Exp,Spt} = lib_love:base_task_award(PlayerStatus#player.lv),
					lib_player:add_spirit(PlayerStatus,Spt);
				false->
					case is_cycle_task(TD) of
						true->
							{_CycLeExp,Spt} = cycle_task_award(PlayerStatus,TD,finish),
							lib_player:add_spirit(PlayerStatus,Spt);
						false->
							case is_random_cycle(TD) of
								true->
									{_,Spt} = lib_cycle_flush:get_award_mult(PlayerStatus#player.id,TD,skip),
									lib_player:add_spirit(PlayerStatus,Spt);
								false->
									case TD#task.spt > 0 of
										true -> lib_player:add_spirit(PlayerStatus,TD#task.spt);
										false -> PlayerStatus
									end
							end
					end
			end
	end.

%%增加绑定铜
add_bind_coin(PlayerStatus,TD)->
	case  TD#task.binding_coin >0 of
		true -> lib_player:add_bcoin(PlayerStatus,TD#task.binding_coin);
		false ->PlayerStatus
	end.

%%增加修为
add_culture(PlayerStatus,TD) ->
	case TD#task.attainment > 0 of
		true -> lib_player:add_culture(PlayerStatus,TD#task.attainment);
		false ->PlayerStatus
	end.

%%增加荣誉
add_honor(PlayerStatus,TD)->
	case TD#task.honor > 0 of
		true-> lib_player:add_honor(PlayerStatus,TD#task.honor);
		false->PlayerStatus
	end.

%%增加部落荣誉
add_realm_honor(PlayerStatus,Td)->
	case Td#task.realm_honor > 0 of
		true->
			lib_player:add_realm_honor(PlayerStatus,Td#task.realm_honor);
		false->PlayerStatus
	end.

add_exp_and_coin(PlayerStatus,Task)->
	case is_carry_task(Task) of
		true->
			%%运镖任务奖励
			lib_carry:add_carry_award(PlayerStatus,Task);
		false->
			case is_guild_carry_task(Task) of
				true->
					%%氏族运镖任务奖励
					lib_carry:add_guild_carry_award(PlayerStatus,Task);
				false->
					case is_cycle_task(Task) of
						true->
							%%循环任务奖励
							PlayerStatus_1 = lib_player:add_coin(PlayerStatus, Task#task.coin),
							{CycLeExp,_} = cycle_task_award(PlayerStatus,Task,finish),
							lib_player:add_exp(PlayerStatus_1, CycLeExp, 0,0);
						false->
							%%跑商任务奖励处理
							case is_business_task(Task) of
								true->
									lib_business:add_business_award(PlayerStatus);
								false->
									%%仙侣情缘任务奖励处理
									case is_love_task(Task) of
										true->
											lib_love:add_love_award(PlayerStatus);
										false->
											case is_random_cycle(Task) of
												true->
													{Exp,_Spt} = lib_cycle_flush:get_award_mult(PlayerStatus#player.id,Task,reset),
													lib_player:add_exp(PlayerStatus, Exp, 0,0);
												false->
													PlayerStatus_1 = lib_player:add_coin(PlayerStatus, Task#task.coin),
													%%普通日常任务累积补偿
													case is_normal_daily_task(Task)==true orelse is_guild_task(Task)==true of
														true->
															{_,_,Award,_Day} = get_recoup_coefficient(PlayerStatus_1),
%% 															normal_daily_task_mail(PlayerStatus_1,Task,Award,Day),
															lib_player:add_exp(PlayerStatus_1, round(Task#task.exp*(Award+1)), 0,0);
														false->
															lib_player:add_exp(PlayerStatus_1, Task#task.exp, 0,0)
													end
											end
									end
							end
					end
			end
	end.

%%51活动奖励
holiday_award(PlayerStatus,TD)->
	case lists:member(TD#task.id, data_task:task_get_pk_mon_id_list()) of
		false->skip;
		true->
			NowTime = util:unixtime(),
			case lib_activities:is_all_may_day_time(NowTime) of
				true->
					NameList = [tool:to_list(PlayerStatus#player.nickname)],
					Title = "任务达人",
					Content =io_lib:format("一分耕耘，一分收获，付出总有回报！恭喜您完成日常守护任务【~s】，获得【欢乐礼包】*1！感谢您的支持！《远古封神》祝您节日愉快！",[TD#task.name]),
					mod_mail:send_sys_mail(NameList, Title, Content, 0, 28840, 1, 0,0,0);
				false->skip
			end
	end.

%%点名任务奖励
appoint_award(_NickName,RT)->
	if RT#role_task.task_id == ?APPOINT_TASK_ID->
		   [Name] = RT#role_task.other,
		   NameList = [tool:to_list(Name)],
		   Title = "点名奖励",
		   Content ="恭喜您和您的好友配合默契，成功完成点名任务，获得【马兰花】*1！祝您游戏愉快～",
		   mod_mail:send_sys_mail(NameList, Title, Content, 0, 31235, 1, 0,0,0),
%% 		   mod_mail:send_sys_mail([tool:to_list(NickName)], Title, Content, 0, 31235, 1, 0,0,0),
		   ok;
	   true->skip
	end.

%%运镖铜钱不足提示
carry_coin_unenough(PlayerStatus,Coin)->
	Msg = io_lib:format("您当前的任务手续费不足~p铜钱，不能接该任务",[Coin]),
	{ok,MyBin} = pt_15:write(15055,[Msg]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin).

carry_coin_unenough_guild(PlayerStatus,Coin)->
	Msg = io_lib:format("当前您所在的氏族资金不足~p铜钱，不能接氏族镖",[Coin]),
	{ok,MyBin} = pt_15:write(15055,[Msg]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin).

%%运镖扣除铜钱提示
carry_coin_del(PlayerStatus,Coin)->
	Msg = io_lib:format("运镖扣除手续费:~p铜钱",[Coin]),
	{ok,MyBin} = pt_15:write(15055,[Msg]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin).

%%运镖获得铜钱提示
carry_coin_tip(PlayerStatus,Coin)->
	Msg = io_lib:format("运镖获得铜钱奖励：~p",[Coin]),
	{ok,MyBin} = pt_15:write(15055,[Msg]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin).

%%运镖系统信件
carry_mail(PlayerStatus,Exp)->
	NameList = [tool:to_list(PlayerStatus#player.nickname)],
	Title = "运镖信件",
	Content =io_lib:format( "亲爱的玩家，您的镖银被劫，获得运镖经验奖励：~p。赠送您一个和平运镖令,该令可以在运镖状态下使用，使用成功后切换成和平状态。",[Exp]),
	mod_mail:send_sys_mail(NameList, Title, Content, 0, 28506, 1, 0,0).

%%氏族运镖信件
guild_carry_mail(PlayerStatus)->
	NameList = [tool:to_list(PlayerStatus#player.nickname)],
	Title = "运镖信件",
	Content="亲爱的玩家，很遗憾，您的氏族镖银被劫。",
	mod_mail:send_sys_mail(NameList, Title, Content, 0, 0, 0, 0,0).

%%普通日常任务补偿邮件
normal_daily_task_mail(PlayerStatus,TD,Award,Day)->
	case Day > 0 of
		true->
			NameList = [tool:to_list(PlayerStatus#player.nickname)],
			Title = "累积经验",
			Content =io_lib:format( "【~s】任务已完成，由于你前【~p】天没有完成任务，今天完成该任务获得额外~p%加成。原经验：~p 加成后所得经验：~p！！",[TD#task.name,Day,Award*100,TD#task.exp,round(TD#task.exp*(Award+1))]),
			mod_mail:send_sys_mail(NameList, Title, Content, 0, 0, 0, 0,0);
		false->skip
	end.

%%保存玩家信息
save_player_table(NewPlayerStatus,OldPlayerStatus,CoinType)->
	Bcoin = abs(NewPlayerStatus#player.bcoin-OldPlayerStatus#player.bcoin),
	Coin = abs(NewPlayerStatus#player.coin-OldPlayerStatus#player.coin),
	Spirit = abs(NewPlayerStatus#player.spirit-OldPlayerStatus#player.spirit),
	Culture = abs(NewPlayerStatus#player.culture-OldPlayerStatus#player.culture),
	Honor = abs(NewPlayerStatus#player.honor-OldPlayerStatus#player.honor),
	RealmHonor = abs(NewPlayerStatus#player.realm_honor-OldPlayerStatus#player.realm_honor),
	ValueList = [{spirit,Spirit,add},
				 {bcoin,Bcoin,add},
				 {coin,Coin,CoinType},
				 if CoinType == add ->
						 {coin_sum,Bcoin+Coin,CoinType};
					true ->
						 {coin_sum,Bcoin-Coin,CoinType}
				 end,				
				 {culture,Culture,add},
				 {honor,Honor,add},
				 {realm_honor,RealmHonor,add}],
	WhereList = [{id, NewPlayerStatus#player.id}],
	spawn(fun()->catch(db_agent:mm_update_player_info(ValueList, WhereList))end),
%% 	lib_player:send_player_attribute(NewPlayerStatus, 1),
	case Coin > 0 of
		true->
			case CoinType of
				add ->spawn(fun()->catch(db_agent:consume_log(3002, NewPlayerStatus#player.id,coin,NewPlayerStatus#player.coin,Coin,1))end);
				 _->spawn(fun()->catch(db_agent:consume_log(3002, NewPlayerStatus#player.id,coin,NewPlayerStatus#player.coin,Coin,0))end)
			end;
		false->skip
	end,
	if Bcoin > 0 ->
		spawn(fun()->catch(db_agent:consume_log(3002, NewPlayerStatus#player.id,bcoin,NewPlayerStatus#player.bcoin,Bcoin,1))end);
	   true->skip
	end.
		   

%%回收任务物品
retrieve_task_goods(PS,TD)->
	%%****************TD.task.content:[[0,0,item,27007,10,0],
    %%                             [1,1,end_talk,10114,2066]]
	[delete_task_goods(PS,Id,Num)||[_,_,Type,Id,Num,_]<-TD#task.content,TD#task.child =/=11,(Type=:=item orelse Type =:=collect)],
	ok.

%%删除物品
delete_task_goods(PS,GoodsTypeId,GoodsNum)->
	Num = goods_util:get_goods_num(PS#player.id, GoodsTypeId,6),
	if Num > GoodsNum ->
		   NumNeed = GoodsNum;
	   true->
		   NumNeed = Num
	end,
	gen_server:call(PS#player.other#player_other.pid_goods, {'delete_task_goods', GoodsTypeId,NumNeed}).

%% 奖励物品所需要的背包空间	
award_item_num(total,TD, PS) ->
    length(get_award_item(TD, PS)) + length(get_award_gift(TD, PS)) + TD#task.award_select_item_num - length(TD#task.end_item);
award_item_num(award,TD,PS) ->
	length(get_award_item(TD, PS)) + length(get_award_gift(TD, PS)) + TD#task.award_select_item_num.
%% 检查是否能完成奖励的条件
award_condition(TD, PlayerStatus) ->
	Cell_Num =gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
						  {'cell_num'}),
	Award_Num = award_item_num(award,TD,PlayerStatus),
	if Cell_Num=:=0 andalso Award_Num > 0->
		   {false,202};
	   true->
		   case Cell_Num < Award_Num of
        		true -> {false,202};  %% 空位不足
        		false ->
					case is_guild_task(TD) of
						true ->
							case PlayerStatus#player.guild_id of
								0 ->
									{false,203};
								_->{true,PlayerStatus}
							end;
						false ->
            				{true, PlayerStatus}
					end
		   end
    end.

%%检查完成任务需要的铜钱是否足够
check_end_cost(PlayerStatus,TD)->
	case TD#task.end_cost >0 of
		false ->{true,PlayerStatus};
		true->
			case PlayerStatus#player.coin >= TD#task.end_cost of
				true->
					{true,finish_del_coin(PlayerStatus,TD)};
				false->
%% 					Tips = io_lib:format("任务押金不足~p!",[TD#task.end_cost]),
					{false,204}
			end
	end.

%%任务押金
get_cash_need(PS,TD,GuildLv)->
	case is_carry_task(TD) of
		true ->
			lib_carry:get_kaution_by_lvl(PS#player.lv,PS#player.realm);
	   false ->
		   case is_guild_carry_task(TD) of
			   true->get_guild_carry_base_coin(player,GuildLv);
			   false->TD#task.start_cost
		   end
	end.

%%氏族运镖押金
get_guild_carry_base_coin(player,Lv)->
	round(5000+(Lv-1) *1000);
get_guild_carry_base_coin(guild,Lv)->
	round(15000+Lv*2500).
%%氏族运镖奖励
guild_carry_coin_award(guild,GuildLv)->
	case GuildLv > 0 of
		false->45000;
		true->
			round(45000+GuildLv*7500)
	end;
guild_carry_coin_award(player,GuildLv)->
	case GuildLv > 0 of
		false->15000;
		true->
			round(15000+3000*(GuildLv-1))
	end.
	


%%-------------------------------放弃任务处理函数-------------------
%%放弃氏族任务
abnegate_guild_task(PS)->
	 TriggerBag = lib_task:get_trigger(PS),
	 Task = [lib_task:get_data(TD#role_task.task_id)||TD<-TriggerBag],
	 [abnegate(T#task.id, PS)||T<-Task,T#task.type=:=3],
     {ok, BinData} = pt_30:write(30006, [1,0]),
     lib_send:send_to_sid(PS#player.other#player_other.pid_send, BinData).

%%放弃试炼任务
abnegate_dun_task(PS)->
	case lists:member(PS#player.lv,[40,50,60,70,80,90]) of
		false->skip;
		true->[abnegate_task(TaskId, PS)||TaskId<-[73000,73001,73002,73003,73004,73005]]
	end.

abnegate_task(TaskId,PlayerStatus)->
	case get_one_trigger(TaskId, PlayerStatus) of
        false -> skip;
        Task ->
			if Task#role_task.state >= 1->skip;
			   true->
				   ets:delete(?ETS_ROLE_TASK, {PlayerStatus#player.id, TaskId}),
           			mod_task_cache:del_trigger(PlayerStatus#player.id, TaskId)
			end
	end.

%% 放弃任务
abnegate(TaskId, PS) ->
    case get_one_trigger(TaskId, PS) of
        false -> {false,PS};
        Task ->
			case get_data(TaskId) of
				[] ->
					{false,PS};
				TD ->
%% 					case TaskId=:=20100 of 
					%%主线任务不能放弃
					case is_main_task(TD) orelse lists:member(TaskId,[20361,40101,40194,83180,?APPOINT_TASK_ID]) of	
						true->
							{false,PS};
						false ->
           					ets:delete(?ETS_ROLE_TASK, {PS#player.id, TaskId}),
           			 		mod_task_cache:del_trigger(PS#player.id, TaskId),
							case Task#role_task.type =:= 1 of
								false->skip;
								true->
									case mod_consign:get_consign_task_by_accept(PS#player.id,TaskId) of
										{ok,[]}->skip;
										{ok,ConsignTask}->
											mod_consign:reset_consign_task(ConsignTask#ets_consign_task.id),
											PlayerName= lib_player:get_role_name_by_id(ConsignTask#ets_consign_task.pid),
											Content =io_lib:format( "玩家【~s】任务失败，您的雇佣任务~s重置！",[PS#player.nickname,ConsignTask#ets_consign_task.name]),
											mod_mail:send_sys_mail([tool:to_list(PlayerName)], "雇佣信件", Content, 0, 0, 0, 0,0)
									end
							end,
							case is_carry_task(TD) orelse is_guild_carry_task(TD) of
								true->
								    {ok,NewPs_1} = lib_carry:finish_carry(PS),
									NewPs=lib_player:count_player_speed(NewPs_1),
									if NewPs_1 =/= NewPs ->
										   lib_player:send_player_attribute(NewPs, 1);
									   true->skip
									end,
									{true,NewPs};
								false ->
									case is_convoy_task(TD) of
										true->
											{ok,NewPs} = convoy_npc_finish(PS),
											{true,NewPs};
										false->
											case is_business_task(TD) of
												true->
													{ok,Ps1} = lib_business:finish_business(PS),
													Ps2=lib_player:count_player_speed(Ps1),
													if Ps2 =/= Ps1 ->
														   lib_player:send_player_attribute(Ps2, 1);
													   true->skip
													end,
													{true,Ps2};
												false->
													case is_hero_task(TD)of
														true->
															lib_hero_card:abnegate_task(PS),
															{true,PS};
														false->
															case TaskId =:= ?GUILD_WISH_TASK_ID of
																true ->%%氏族祝福任务
																	lib_guild_wish:task_gwish_giveup(PS),
																	{true,PS};
																false ->
																	{true,PS}
															end
													end
											end
									end
							end
           			 		
					end
			end
    end.


%% 已接所有任务更新判断
action(0, PlayerStatus, Event, ParamList) ->
    case get_trigger(PlayerStatus#player.id) of
        [] -> 
            false;
        RTL -> 
            Result = [action_one(RT, PlayerStatus, Event, ParamList)|| RT <- RTL],
            lists:member(true, Result)
    end;

%% 单个任务更新判断
action(TaskId, PlayerStatus, Event, ParamList)->
    case get_one_trigger(TaskId, PlayerStatus#player.id) of
        false -> false;
        RT -> action_one(RT, PlayerStatus, Event, ParamList)
    end.

action_one(RT, PlayerStatus, Event, ParamList) ->
	Rid = PlayerStatus#player.id,
    F = fun(MarkItem, Update)->
        [State, Finish, Eve| _T] = MarkItem,
        case State =:= RT#role_task.state andalso Finish =:= 0 andalso Eve=:=Event of
            false -> 
                {MarkItem, Update};
            true -> 
                {NewMarkItem, NewUpdate} = content(MarkItem, Rid, ParamList),
                case NewUpdate of
                    true -> 
                        {NewMarkItem, true};
                    false -> 
                        {NewMarkItem, Update}
                end
        end
    end,
    {NewMark, UpdateAble} = lists:mapfoldl(F ,false, RT#role_task.mark),
    case UpdateAble of
        false -> 
            false;
        true ->
            NewState = case lists:member(false, [Fi=:=1||[Ts,Fi|_T1 ] <- NewMark,Ts=:=RT#role_task.state]) of
                true -> RT#role_task.state; %%当前阶段有未完成的
                false -> RT#role_task.state + 1 %%当前阶段完成的
            end,
            %% 更新任务记录和任务状态
            ets:insert(?ETS_ROLE_TASK, RT#role_task{state=NewState, mark = NewMark}),
            mod_task_cache:upd_trigger(Rid, RT#role_task.task_id, NewState, NewMark),
			case NewState of
				1->
					case lists:member(RT#role_task.task_id,lib_hero_card:get_hero_task_list()) of
						true->
							case auto_finish_hero_card_task(PlayerStatus,RT#role_task.task_id) of
								false->true;
								_->false
							end;
						_->
							if RT#role_task.task_id == ?APPOINT_TASK_ID->true;
%% 								   auto_finish_appoint_task(PlayerStatus,RT#role_task.task_id);
							   true->
								   true
							end
					end;
				_->true
			end
    end.

%% 检查物品是否为任务需要
can_gain_item(Player, ItemId) ->
	gen_server:call(Player#player.other#player_other.pid_task,{'check_can_gain_item',Player, ItemId}).

check_can_gain_item(Player,ItemId)->
    case get_trigger(Player) of
        [] -> false;
        RTL ->
            Result = [can_gain_item(marklist, get_phase_unfinish(RT), ItemId) || RT <- RTL],
            lists:member(true, Result)
    end.

can_gain_item(marklist, MarkList, ItemId) ->
    length([0 || [_, _, Type, Id | _T] <- MarkList, (Type =:= item orelse Type =:=collect), Id =:= ItemId])>0.


after_event(PS,Type,Info) ->
    %% @summary 后续事件提前完成检测
    case preact_finish(PS) of
        true -> 
			ok;
        false -> 
            %% @summary 通知角色数据更新
%% 			if Type =:= 2->
%%             	lib_scene:refresh_npc_ico(PS); 
%% 			   true->skip
%% 			end,
			case Info of
				0->TypeId=0;
				_->
					[{Id,_}|_] = Info,
					if Type =:=4 orelse Type =:=5 ->
						   TypeId= goods_util:get_task_mon(Id);
					true->
							TypeId = Id
					end
					
			end,
            {ok, BinData} = pt_30:write(30006, [Type,TypeId]),
            lib_send:send_to_uid(PS#player.id, BinData)
    end.

%%接受任务失败，删除神器
kick_out_of_single_dungeon(PlayerStatus,TaskId)->
	case TaskId of
		20361->mod_single_dungeon:finish_single_dungeon_task(PlayerStatus);
		_->ok
	end.

%%自动完成封神贴任务
auto_finish_hero_card_task(PlayerStatus,TaskId)->
	RT = get_one_trigger(TaskId, PlayerStatus),
	NowTime = util:unixtime(),
	TD = get_data(TaskId),
	ets:delete(?ETS_ROLE_TASK, {PlayerStatus#player.id, TaskId}),
	ets:insert(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=PlayerStatus#player.id,
												  task_id=TaskId, trigger_time = RT#role_task.trigger_time, finish_time = NowTime}),
	%% 数据库回写
	mod_task_cache:del_trigger(PlayerStatus#player.id, TaskId),
	mod_task_cache:add_log(PlayerStatus#player.lv, PlayerStatus#player.other#player_other.pid, PlayerStatus#player.id, TaskId, TD#task.type,RT#role_task.trigger_time, NowTime),
	gen_server:cast(PlayerStatus#player.other#player_other.pid, {'EXP', TD#task.exp,TD#task.spt,0}),
	%通知客户端刷新任务列表
	{ok, BinData} = pt_30:write(30006, [1,0]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	lib_hero_card:reset_hero_card(PlayerStatus,TD#task.exp,TD#task.spt),
	ok.

auto_finish_appoint_task(PlayerStatus,TaskId)->
	RT = get_one_trigger(TaskId, PlayerStatus),
	NowTime = util:unixtime(),
	TD = get_data(TaskId),
	Trrtime = 
		case is_record(RT, role_task) of
		true->RT#role_task.trigger_time;
			false->
				NowTime
		end,
	ets:delete(?ETS_ROLE_TASK, {PlayerStatus#player.id, TaskId}),
	ets:insert(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=PlayerStatus#player.id,
												  task_id=TaskId, trigger_time = Trrtime, finish_time = NowTime}),
	%% 数据库回写
	mod_task_cache:del_trigger(PlayerStatus#player.id, TaskId),
	mod_task_cache:add_log(PlayerStatus#player.lv, PlayerStatus#player.other#player_other.pid, PlayerStatus#player.id, TaskId, TD#task.type,Trrtime, NowTime),
	%通知客户端刷新任务列表
	{ok, BinData} = pt_30:write(30006, [1,0]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	appoint_award(PlayerStatus#player.nickname,RT),
	ok.
%%=====================触发任务事件处理函数=================================
%% 事件
event(Event, Parm, Player) when is_record(Player, player)->
	gen_server:cast(Player#player.other#player_other.pid_task,{'task_event',Player,Event,Parm}). 
%% 	case Player#player.other#player_other.node == node() of
%% 		true -> event(Event, Parm, Player,null);
%% 		_ ->
%% 			gen_server:cast(Player#player.other#player_other.pid, 
%% 					{event, {?MODULE, event, [Event, Parm, Player,null]}})
%% 	end.

task_event(talk, {TaskId, NpcId}, PS) ->
    case action(TaskId, PS, talk, [NpcId]) of
        false-> false;
        true ->
            after_event(PS,2,0),
			get_goods_from_talk(TaskId,PS),
            true
    end;

%% 打怪事件成功
task_event(kill, Monid, PS) ->
    case action(0, PS, kill, Monid) of
        false -> 
            false;
        true ->
            after_event(PS,3,[{Monid,1}]),
            true
    end;

%% 获得物品事件
task_event(item, ItemList, PS) ->
    case action(0, PS, item, [ItemList]) of
        false -> false;
        true ->
            after_event(PS,4,ItemList),
            true
    end;
%%采集物品事件
task_event(collect, ItemList, PS) ->
    case action(0, PS, collect, [ItemList]) of
        false -> false;
        true ->
			%%获得灵兽任务
			get_a_pet(PS,ItemList),
            after_event(PS,5,ItemList),
            true
    end;

%% 打开商城事件
%task_event(open_store, _, PS) ->
%    case action(0, PS, open_store, []) of
%        false -> false;
%        true ->
%            after_event(PS,2,0),
%            true
%    end;

%% 技能学习
task_event(learn_skill, {SkillId}, PS) ->
    case action(0, PS, learn_skill, [SkillId]) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%% 装备物品事件
task_event(equip, {ItemId}, PS) ->
    case action(0, PS, equip, [ItemId]) of 
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%% 购买物品事件
task_event(buy_equip, {ItemId}, PS) ->
    case action(0, PS, buy_equip, [ItemId]) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%%选择部落
task_event(select_nation, _, PS) ->
    case action(0, PS, select_nation, []) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%%使用物品事件
task_event(use_goods,{GoodsId},PS) ->
	case action(0,PS,use_goods,[GoodsId]) of 
		false ->false;
		true ->
			after_event(PS,2,0),
			true
	end;

%% %%仙宠召唤
task_event(pet, _, PS) ->
    case action(0, PS, pet, []) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%% 添加好友
task_event(friend, _, PS) ->
    case action(0, PS, friend, []) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%% 加入氏族
task_event(guild, _, PS) ->
    case action(0, PS, guild, []) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%% 拜师
task_event(master, _, PS) ->
    case action(0, PS, master, []) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%% 坐骑
task_event(mount, _, PS) ->
    case action(0, PS, mount, []) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%% %%融合法宝
task_event(trump, _, PS) ->
    case action(0, PS, trump, []) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%% 护送NPC
task_event(convoy, _, PS) ->
    case action(0, PS, convoy, []) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%%技能升级
%% task_event(up_skill, _, PS) ->
%%     case action(0, PS, up_skill, []) of
%%         false -> false;
%%         true ->
%%             after_event(PS,2,0),
%%             true
%%     end;

%%商城购买
task_event(shopping,{GoodsId},PS) ->
	case action(0,PS,shopping,[GoodsId]) of 
		false ->false;
		true ->
			after_event(PS,2,0),
			true
	end;

%%藏宝图鉴定
task_event(appraisal,{MapId},PS) ->
	case action(0,PS,appraisal,[MapId]) of 
		false ->false;
		true ->
			after_event(PS,2,0),
			true
	end;

%% 战场竞技
task_event(arena, _, PS) ->
    case action(0, PS, arena, []) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%%答题
task_event(question,{QuestionId},PS) ->
	case action(0,PS,question,[QuestionId]) of 
		false ->false;
		true ->
			after_event(PS,2,0),
			true
	end;

%%升级
task_event(up_level,{Level},PS) ->
	case action(0,PS,up_level,[Level]) of 
		false ->false;
		true ->
			after_event(PS,2,0),
			true
	end;

%% 击杀对手
task_event(arena_kill, _, PS) ->
    case action(0, PS, arena_kill, []) of
        false -> 
            false;
        true ->
            after_event(PS,2,0),
            true
    end;

%% 英雄帖
task_event(hero_kill, {Level}, PS) ->
%% 	io:format("hero_kill_~p~n",[Level]),
    case action(0, PS, hero_kill, [Level]) of
        false -> 
            false;
        true ->
            after_event(PS,6,[{Level,1}]),
            true
    end;

%% 打开药店事件
task_event(open_drugstore,_, PS) ->
    case action(0, PS, open_drugstore, []) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%% 神岛空战竞技
task_event(guild_war, _, PS) ->
    case action(0, PS, guild_war, []) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;
%% 远古情缘
task_event(love, _, PS) ->
    case action(0, PS, love, []) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%%打开庄园
task_event(open_manor, _, PS) ->
    case action(0, PS, open_manor, []) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%% 击杀异族
task_event(kill_enemy, _, PS) ->
    case action(0, PS, kill_enemy, []) of
        false -> 
            false;
        true ->
            after_event(PS,2,0),
            true
    end;

%%保存页面
task_event(save_html, _, PS) ->
    case action(0, PS, save_html, []) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%%装备附魔
task_event(magic, _, PS) ->
    case action(0, PS, magic, []) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%%氏族祝福
task_event(guild_bless, _, PS) ->
    case action(0, PS, guild_bless, []) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%%了解强化
task_event(open_strength, _, PS) ->
    case action(0, PS, open_strength, []) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%%诛邪
task_event(zhuxie, _, PS) ->
    case action(0, PS, zhuxie, []) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%%了解仓库
task_event(open_storehouse, _, PS) ->
    case action(0, PS, open_storehouse, []) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%%开神兽蛋
task_event(pet_eggs, _, PS) ->
    case action(0, PS, pet_eggs, []) of
        false -> false;
        true ->
			lib_pet:give_pet_task(PS#player.id,24601),
            after_event(PS,2,0),
            true
    end;

%%灵兽技能融合
task_event(pet_skill, _, PS) ->
    case action(0, PS, pet_skill, []) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%%打开藏宝图
task_event(open_appraisal, _, PS) ->
    case action(0, PS, open_appraisal, []) of
        false -> false;
        true ->
            after_event(PS,2,0),
            true
    end;

%%仙侣完成仙侣情缘任务
task_event(lover_task,_LoverName,PS)->
	case action(0, PS, lover_task, []) of
		false -> false;
		true ->
			after_event(PS,2,0),
			true
	end;

%%爱侣送玫瑰
task_event(lover_flower,_LoverName,PS)->
	case action(0, PS, lover_flower, []) of
        false -> false;
        true ->
			after_event(PS,2,0),
			true
		 end;

%%爱侣温泉互动
task_event(lover_hotspring,_LoverName,PS)->
	case action(0, PS, lover_hotspring, []) of
        false -> false;
        true ->
			after_event(PS,2,0),
			true
	end;

task_event(lover_train,_LoverName,PS)->
	case action(0, PS, lover_train, []) of
		false -> false;
		true ->
			after_event(PS,2,0),
			true
	end;

%%学习被动技能
task_event(passive_skill,_,PS)->
	case action(0, PS, passive_skill, []) of
		false -> false;
		true ->
			after_event(PS,2,0),
			true
	end;
%%坐骑出战
task_event(mount_fight,_,PS)->
	case action(0, PS, mount_fight, []) of
		false -> false;
		true ->
			after_event(PS,2,0),
			true
	end;

%%坐骑变形
task_event(mount_change,_,PS)->
	case action(0, PS, mount_change, []) of
		false -> false;
		true ->
			after_event(PS,2,0),
			true
	end;

%% 试炼副本任意杀怪
task_event(train_kill, _, PS) ->
    case action(0, PS, train_kill, []) of
        false -> 
            false;
        true ->
            after_event(PS,2,0),
            true
    end;

%%竞技场挑战
task_event(arena_pk,_,PS)->
	case action(0, PS, arena_pk, []) of
		false -> false;
		true ->
			after_event(PS,2,0),
			true
	end;

%%参与封神纪元
task_event(fs_era,_,PS)->
	case action(0, PS, fs_era, []) of
		false -> false;
		true ->
			after_event(PS,2,0),
			true
	end;

%%参与斗兽
task_event(mount_arena,_,PS)->
	case action(0, PS, mount_arena, []) of
		false -> false;
		true ->
			after_event(PS,2,0),
			true
	end;

%%爱的宣言
task_event(love_show,_,PS)->
	case action(0, PS, love_show, []) of
		false -> false;
		true ->
			after_event(PS,2,0),
			true
	end;

%% 斗兽挑战
task_event(mount_pk, _, PS) ->
    case action(0, PS, mount_pk, []) of
        false -> 
            false;
        true ->
            after_event(PS,2,0),
            true
    end;
%% 竞技场挑战
task_event(arena_fight, _, PS) ->
    case action(0, PS, arena_fight, []) of
        false -> 
            false;
        true ->
            after_event(PS,2,0),
            true
    end;
%% 使用桃子
task_event(use_peach, _, PS) ->
    case action(0, PS, use_peach, [1]) of
        false -> 
            false;
        true ->
            after_event(PS,2,0),
            true
    end;

%%在线3小时
task_event(online_time,_,PS)->
	case action(0, PS, online_time, []) of
		false -> false;
		true ->
			after_event(PS,2,0),
			true
	end;
%%活跃度100
task_event(online_100,_,PS)->
	case action(0, PS, online_100, []) of
		false -> false;
		true ->
			after_event(PS,2,0),
			true
	end;

%%商城任意购物
task_event(buy_anything,_,PS)->
	case action(0, PS, buy_anything, []) of
		false -> false;
		true ->
			after_event(PS,2,0),
			true
	end;

task_event(_Item,_,_PS)->
	false.
%% 条件
%% =====================任务是否完成===================

%% 是否完成任务
check_condition({task, TaskId}, _, PS,_TaskType) ->
    in_finish(TaskId, PS);

%% 是否完成其中之一的任务
check_condition({task_one, TaskList}, _, PS,_TaskType) ->
    lists:any(fun(Tid)-> in_finish(Tid, PS) end, TaskList);

%% 今天的任务次数是否过多
check_condition({daily_limit, Num}, ThisTaskId, PS,TaskType) ->
	%%雇佣任务次数不在这里统计
	case TaskType of
		1->
    		true;
		_->
			TodayNom = get_today_count(ThisTaskId, PS),
			TodayNom < Num
	end;
    %{M, S, MS} = now(),
    %{_, Time} = calendar:now_to_local_time({M, S, MS}),
    %TodaySec = M * 1000000 + S - calendar:time_to_seconds(Time),
    %TomorrowSec = TodaySec + 86400,
    %%check_condition_daily_limit(get_finish(PS), ThisTaskId, Num, TodaySec, TomorrowSec);

%% 帮会任务等级
check_condition({guild_level, Lev}, _, PS,_TaskType) ->
    case PS#player.guild_id =:= 0 of
        true -> false;
        false ->
            case mod_guild:get_guild_lev_by_id(PS#player.guild_id) of
                null -> false;
                GLevel -> GLevel >= Lev
            end
    end;

%% 容错
check_condition(_Other, _, _PS,_TaskType) ->
    false.

check_condition_daily_limit([], _, Num, _, _) ->
    Num > 0;
check_condition_daily_limit([RTL | T], TaskId, Num, TodaySec, TomorrowSec) ->
    case 
        TaskId =:= RTL#role_task_log.task_id andalso 
        RTL#role_task_log.finish_time > TodaySec andalso
        RTL#role_task_log.finish_time < TomorrowSec 
    of
        false -> check_condition_daily_limit(T, TaskId, Num, TodaySec, TomorrowSec);
        true -> %% 今天所完成的任务
            case Num - 1 > 0 of
                true -> check_condition_daily_limit(T, TaskId, Num - 1, TodaySec, TomorrowSec);
                false -> false
            end
    end.

%%查询某日常任务是否可接
is_can_trigger(Status,TaskId)->
	case lib_task:get_one_trigger(TaskId,Status#player.id) of
		false->
			TD = get_data(TaskId),
			TodayNom = get_today_count(TaskId, Status),
			Times = check_daily_times(TD#task.condition),
			TodayNom < Times;
		_->false
	end.

%% 检测任务内容是否完成
%%杀怪
check_content([_, Finish, kill, _MonId, Num, NowNum], _Rid) ->
    Finish =:=1 andalso Num =:= NowNum;
%%对话
check_content([_, Finish, talk, _, _], _Rid) ->
    Finish =:=1;
%%收集物品
check_content([_, Finish, item, _, Num, NowNum], _Rid) ->
    Finish =:=1 andalso Num =:= NowNum;
%%采集物品
check_content([_, Finish, collect, _, Num, NowNum], _Rid) ->
    Finish =:=1 andalso Num =:= NowNum;
%%战场击杀
check_content([_, Finish, arena_kill, Num, NowNum], _Rid) ->
    Finish =:=1 andalso Num =:= NowNum;
%%英雄帖
check_content([_, Finish, hero_kill, _Lv,Num, NowNum], _Rid) ->
    Finish =:=1 andalso Num =:= NowNum;
%%击杀异族
check_content([_, Finish, kill_enemy, Num, NowNum], _Rid) ->
    Finish =:=1 andalso Num =:= NowNum;
%%试炼副本任意杀怪
check_content([_, Finish, train_kill, Num, NowNum], _Rid) ->
    Finish =:=1 andalso Num =:= NowNum;
check_content([_, Finish | _], _Rid) ->
    Finish =:= 1;

check_content(Other, _PS) ->
    ?DEBUG("错误任务内容~p",[Other]),
    false.

%%===============================任务事件是否完成检查函数===========================
%% 杀怪
content([State, 0, kill, NpcId, Num, NowNum], _Rid, NpcList) ->
	case State =/= 2 of
		true->
    		case NpcId =:= NpcList of
     		   false ->{[State, 0, kill, NpcId, Num, NowNum], false};
     		   true ->
     		       case NowNum + 1 >= Num of
     		            true -> {[State,1 , kill , NpcId, Num, Num],  true};
     	          		false ->{[State,0 , kill , NpcId, Num, NowNum + 1], true}
      		      end
			end;
		false->{[State, 0, kill, NpcId, Num, NowNum], false}
    end;

%% 对话
content([State, 0, talk, NpcId, TalkId], _Rid, [NowNpcId]) ->
    case NowNpcId =:= NpcId of
        true -> {[State, 1, talk, NpcId, TalkId], true};
        false -> {[State, 0, talk, NpcId, TalkId], false}
    end;

%% 物品
content([State, 0, item, ItemId, Num, NowNum], _Rid, [ItemList]) ->
    case [XNum || {XItemId, XNum} <- ItemList, XItemId =:= ItemId] of
        [] -> {[State, 0, item, ItemId, Num, NowNum], false}; %% 没有任务需要的物品
        [HaveNum | _] ->
            case HaveNum >= Num of
                true -> {[State, 1, item, ItemId, Num, Num], true};
                false -> {[State, 0, item, ItemId, Num, HaveNum], true}
            end
    end;

%% 采集
content([State, 0, collect, ItemId, Num, NowNum], _Rid, [ItemList]) ->
    case [XNum || {XItemId, XNum} <- ItemList, XItemId =:= ItemId] of
        [] -> {[State, 0, collect, ItemId, Num, NowNum], false}; %% 没有任务需要的物品
        [HaveNum | _] ->
            case HaveNum >= Num of
                true -> {[State, 1, collect, ItemId, Num, Num], true};
                false -> {[State, 0, collect, ItemId, Num, HaveNum], true}
            end
    end;
%% 打开商城
%content([State, 0, open_store], _Rid, _) ->
%    {[State, 1, open_store], true};

%% 购买物品
content([State, 0, buy_equip, ItemId ,NpcId], _Rid, [NowItemId]) ->
    case NowItemId =:= ItemId of
        false -> {[State, 0, buy_equip, ItemId,NpcId], false};
        true -> {[State, 1, buy_equip, ItemId,NpcId], true}
    end;

%% 装备物品
content([State, 0, equip, ItemId], _Rid, [_NowItemId]) ->
	{[State, 1, equip, ItemId], true};
%%     case NowItemId =:= ItemId of
%%         false -> {[State, 0, equip, ItemId], false};
%%         true -> {[State, 1, equip, ItemId], true}
%%     end;

%% 技能学习
content([State, 0, learn_skill, SkillId], _Rid, [_NowSkillId]) ->
	{[State, 1, learn_skill, SkillId], true};
%%     case NowSkillId =:= SkillId of
%%         false -> {[State, 0, learn_skill, SkillId], false};
%%         true -> {[State, 1, learn_skill, SkillId], true}
%%     end;

%%选择部落select_nation
content([State,0,select_nation],_Rid,_) ->
	{[State,1,select_nation],true};

%% %%仙宠
content([State,0,pet],_Rid,_) ->
	{[State, 1, pet], true};

%%使用物品
content([State,0,use_goods,GoodsId],_Rid,[NowGoodsId]) ->
	case NowGoodsId =:= GoodsId of
		false -> {[State, 0, use_goods, GoodsId], false};
		true -> {[State, 1, use_goods, GoodsId], true}
	end;

%% 添加好友
content([State,0,friend],_Rid,_) ->
	{[State, 1, friend], true};

%% 加入氏族
content([State,0,guild],_Rid,_) ->
	{[State, 1, guild], true};

%% 拜师
content([State,0,master],_Rid,_) ->
	{[State, 1, master], true};

%%坐骑
content([State,0,mount],_Rid,_) ->
	{[State,1,mount],true};

%%熔合法宝
content([State,0,trump],_Rid,_) ->
	{[State,1,trump],true};

%%技能升级
%% content([State,0,up_skill],_Rid,_) ->
%% 	{[State,1,up_skill],true};

%%商城购买
content([State,0,shopping,GoodsId],_Rid,[NowGoodsId]) ->
	case NowGoodsId =:= GoodsId of
     	false -> {[State, 0, shopping, GoodsId], false};
     	true -> {[State, 1, shopping, GoodsId], true}
	end;

%%护送
content([State,0,convoy],_Rid,_) ->
	{[State,1,convoy],true};

%%藏宝图鉴定
content([State,0,appraisal,MapId],_Rid,[NowMapId]) ->
	case NowMapId =:= MapId of
		false ->{[State,0,appraisal,MapId,false]};
		true ->{[State,1,appraisal,MapId],true}
	end;

%%战场竞技
content([State,0,arena],_Rid,_) ->
	{[State,1,arena],true};

%%答题
content([State,0,question,Questionid],_Rid,[NowQuestionid]) ->
	case NowQuestionid =:= Questionid of
		false -> {[State, 0, question, Questionid], false};
     	true -> {[State, 1, question, Questionid], true}
	end;

%%升级
content([State,0,up_level,Level],_Rid,[NowLevel]) ->
	case NowLevel >= Level of
		false -> {[State, 0, up_level, Level], false};
     	true -> {[State, 1, up_level, Level], true}
	end;

%% 击杀对手
content([State, 0, arena_kill, Num, NowNum], _Rid, _NpcList) ->
	case NowNum + 1 >= Num of
		true -> {[State,1 , arena_kill , Num, Num],  true};
     	false ->{[State,0 , arena_kill , Num, NowNum + 1], true}
    end;

%% 英雄帖
content([State, 0, hero_kill, Lv,Num, NowNum], _Rid, [NowLv]) ->
	if NowLv >= Lv ->
		case NowNum + 1 >= Num of
			true -> {[State,1 , hero_kill ,Lv ,Num, Num],  true};
     		false ->{[State,0 , hero_kill , Lv ,Num, NowNum + 1], true}
		end;
		true->{[State, 0, hero_kill, Lv,Num, NowNum],  false}
    end;

%% 打开药店
content([State, 0, open_drugstore, ItemId ,NpcId], _Rid, _) ->
    {[State, 1, open_drugstore, ItemId,NpcId], true};

%%神岛空战竞技
content([State,0,guild_war],_Rid,_) ->
	{[State,1,guild_war],true};

%%仙侣情缘
content([State,0,love],_Rid,_) ->
	{[State,1,love],true};

%%打开庄园
content([State,0,open_manor],_Rid,_) ->
	{[State,1,open_manor],true};

%% 击杀异族
content([State, 0, kill_enemy, Num, NowNum], _Rid, _NpcList) ->
	case NowNum + 1 >= Num of
		true -> {[State,1 , kill_enemy , Num, Num],  true};
     	false ->{[State,0 , kill_enemy , Num, NowNum + 1], true}
    end;

%%保存页面
content([State,0,save_html],_Rid,_)->
	{[State,1,save_html],true};

%%装备附魔
content([State,0,magic],_Rid,_)->
	{[State,1,magic],true};


%%氏族祝福
content([State,0,guild_bless],_Rid,_)->
	{[State,1,guild_bless],true};

%%了解强化
content([State,0,open_strength],_Rid,_)->
	{[State,1,open_strength],true};

%%诛邪
content([State,0,zhuxie],_Rid,_)->
	{[State,1,zhuxie],true};
%%了解仓库
content([State,0,open_storehouse],_Rid,_)->
	{[State,1,open_storehouse],true};

%%开神兽蛋
content([State,0,pet_eggs],_Rid,_)->
	{[State,1,pet_eggs],true};

%%灵兽技能融合
content([State,0,pet_skill],_Rid,_)->
	{[State,1,pet_skill],true};

%%打开藏宝图
content([State,0,open_appraisal],_Rid,_)->
	{[State,1,open_appraisal],true};

%%爱侣完成仙侣情缘任务
content([State,0,lover_task],_Rid,_)->
	{[State,1,lover_task],true};

%%爱侣送玫瑰
content([State,0,lover_flower],_Rid,_)->
	{[State,1,lover_flower],true};

%%爱侣温泉互动
content([State, 0, lover_hotspring, Num, NowNum], _Rid, _NpcList) ->
	case NowNum + 1 >= Num of
		true -> {[State,1 , lover_hotspring , Num, Num],  true};
     	false ->{[State,0 , lover_hotspring , Num, NowNum + 1], true}
    end;

%%爱侣通关试炼
content([State,0,lover_train],_Rid,_)->
	{[State,1,lover_train],true};

%%学习被动技能
content([State,0,passive_skill],_Rid,_)->
	{[State,1,passive_skill],true};
 
%%坐骑出战
content([State,0,mount_fight],_Rid,_)->
	{[State,1,mount_fight],true};

%%坐骑变形
content([State,0,mount_change],_Rid,_)->
	{[State,1,mount_change],true};

%% 试炼副本任意击杀
content([State, 0, train_kill, Num, NowNum], _Rid, _NpcList) ->
	case NowNum + 1 >= Num of
		true -> {[State,1 , train_kill , Num, Num],  true};
     	false ->{[State,0 , train_kill , Num, NowNum + 1], true}
    end;

%%竞技场挑战
content([State,0,arena_pk],_Rid,_)->
	{[State,1,arena_pk],true};

%%参与封神纪元
content([State,0,fs_era],_Rid,_)->
	{[State,1,fs_era],true};

%%参与斗兽
content([State,0,mount_arena],_Rid,_)->
	{[State,1,mount_arena],true};

%%爱的宣言
content([State,0,love_show],_Rid,_)->
	{[State,1,love_show],true};

%% 斗兽挑战
content([State, 0, mount_pk, Num, NowNum], _Rid, _NpcList) ->
	case NowNum + 1 >= Num of
		true -> {[State,1 , mount_pk , Num, Num],  true};
     	false ->{[State,0 , mount_pk , Num, NowNum + 1], true}
    end;

%% 竞技场挑战
content([State, 0, arena_fight, Num, NowNum], _Rid, _NpcList) ->
	case NowNum + 1 >= Num of
		true -> {[State,1 , arena_fight , Num, Num],  true};
     	false ->{[State,0 , arena_fight , Num, NowNum + 1], true}
    end;


%% 使用桃子
content([State, 0, use_peach, Num, NowNum], _Rid, [HadNum]) ->
	case NowNum + HadNum >= Num of
		true -> {[State,1 , use_peach , Num, Num],  true};
     	false ->{[State,0 , use_peach , Num, NowNum + HadNum], true}
    end;

%%在线3小时
content([State,0,online_time],_Rid,_)->
	{[State,1,online_time],true};

%%活跃度100
content([State,0,online_100],_Rid,_)->
	{[State,1,online_100],true};

%%商城任意购物
content([State,0,buy_anything],_Rid,_)->
	{[State,1,buy_anything],true};

content(MarkItem, _Other, _Other2) ->
%% 	io:format("content,error!!!!~p~n",[[MarkItem, _Other, _Other2]]),
    {MarkItem, false}.


%%=======================选择部落函数========================
%选择部落
select_nation(PS,Type,Realm) ->
	case Type of 
		1 ->
			case lists:member(Realm,[1,2,3]) of
				true->
					{ok, NewPS} = set_nation(PS,Realm),
					{ok, NewPS, [1,Type,Realm,0]};
				false->
					{ok, PS, [0,Type,Realm,0]}
			end;
		2->
%% 			NewRealm = random_nation(),
			NewRealm = mod_random_realm:get_realm(),
			{ok, NewPS} = set_nation(PS, NewRealm),
			case gen_server:call(PS#player.other#player_other.pid_goods, {'give_goods', PS,28110, 1,2}) of
				ok ->	
					Bag = 1;
				_->
					NameList = [tool:to_list(PS#player.nickname)],
					Content = "亲爱的玩家，您随机选择部落，系统赠送您一个听天由命礼包，祝你游戏愉快！",
					mod_mail:send_sys_mail(NameList, "选择部落", Content, 0,28110, 1, 0, 0),
					Bag = 2
			end,
			{ok,NewPS, [1,Type,NewRealm,Bag]};
		_->
			{ok, PS, [0,Type,Realm,0]}
	end.

%%设置部落
set_nation(PS,Realm)->
	ValueList = [{realm,Realm}],
	WhereList = [{id, PS#player.id}],
    db_agent:mm_update_player_info(ValueList, WhereList),
	db_agent:update_realm(Realm),
	{ok, PS#player{realm = Realm}}.

%%=========================护送任务处理函数====================================
%%开始护送NPC
convoy_npc_start(PS,NpcId)->
%% 	NowTimestamp = util:unixtime(),
	ValueList = [{task_convoy_npc,NpcId}],
	WhereList = [{id, PS#player.id}],
    db_agent:mm_update_player_info(ValueList, WhereList),			
	NewPs = PS#player{task_convoy_npc=NpcId},
	case lib_npc:get_data(NpcId) of
		[] ->NpcName='';
		NpcInfo ->
			NpcName=NpcInfo#ets_npc.name
	end,
	{ok,BinData2} = pt_12:write(12051,[NewPs#player.id,NewPs#player.task_convoy_npc,NpcName]),
	mod_scene_agent:send_to_area_scene(NewPs#player.scene,NewPs#player.x, NewPs#player.y, BinData2),
	{ok,NewPs}.

%%结束护送NPC
convoy_npc_finish(PS)->
	ValueList = [{task_convoy_npc,0}],
	WhereList = [{id, PS#player.id}],
    db_agent:mm_update_player_info(ValueList, WhereList),			
	NewPs = PS#player{task_convoy_npc=0},
	{ok,BinData2} = pt_12:write(12051,[NewPs#player.id,NewPs#player.task_convoy_npc,'']), 
	mod_scene_agent:send_to_area_scene(NewPs#player.scene,NewPs#player.x, NewPs#player.y, BinData2),
	{ok,NewPs}.

%%检查护送是否超时
check_convoy_timeout(_PS)->
	ok.
%% 	NowTime = util:unixtime(),
%% 	if 
%% 		{NowTime - PS#player.task_convoy_timestamp} < 30*60 ->
%% 			ok;
%% 	    true ->
%% 			ok
%% 	end.

%% 跟斗云使用条件检测
check_shoe_use(PS,Type,TaskId)->
	case lib_deliver:could_deliver(PS) of
		ok ->
			case Type of
				1 ->
					{ok,0};
			   	2 ->
					TD = get_data(TaskId),
				   	if 
						TD#task.child =:= 7 ->   
							{error, 6};
					  	TD#task.child =:= 6 orelse TD#task.type =:= 3 ->
							{error, 31};
					  	true ->
							{ok, 0}
				   	end;
		   		_ ->
					{error, 2}
		   	end;
		ErrorCode ->
			{error, ErrorCode}
	end.


%%######################打怪掉落处理########################
kill_mon(PlayerStatus,MonId,MonLv)->
	case MonId >= 41057 andalso MonId =< 41098 of
		true->lib_task:task_event(train_kill, MonId, PlayerStatus);
		false->
			skip	
	end,
	lib_task:task_event(kill, MonId, PlayerStatus),
	if PlayerStatus#player.lv >= 30->
		lib_task:task_event(hero_kill, {MonLv}, PlayerStatus);
	   true->skip
	end.

share_mon_kill(_PlayerStatus,[],_MonId,_MonLv,_Scene)->
	ok;
share_mon_kill(PlayerStatus,[PlayerId|PlayerList],MonId,MonLv,Scene)->
%% 	io:format("share_mon_kill_~p~n",[MonLv]),
	case PlayerStatus#player.id =:= PlayerId of
		true-> 
			gen_server:cast(PlayerStatus#player.other#player_other.pid_task,{'kill_mon',PlayerStatus,MonId,MonLv});
%% 			lib_task:event(kill, MonId, PlayerStatus),
%% 			lib_task:event(hero_kill, {MonLv}, PlayerStatus);
		false->
			case lib_mon:get_player(PlayerId, Scene) of 
				[]->skip;
				Player->
					case is_pid(Player#player.other#player_other.pid_team) of
						true->skip;
						false->
							gen_server:cast(Player#player.other#player_other.pid_task,{'kill_mon',Player,MonId,MonLv})
%% 							lib_task:event(kill, MonId, Player),
%% 							lib_task:event(hero_kill, {MonLv}, PlayerStatus)
					end
			end
	end,
	share_mon_kill(PlayerStatus,PlayerList,MonId,MonLv,Scene).

share_mon_drop(_PlayerStatus,_MonId,_MonType,_MonLv,[],_MonScene,_GoodList)->
	skip;
share_mon_drop(PlayerStatus,MonId,MonType,MonLv,[PlayerId|PlayerList],MonScene,GoodList)->
%% 	io:format("share_mon_drop_~p~n",[MonLv]),
	case PlayerStatus#player.id =:=PlayerId of
		true->
			gen_server:cast(PlayerStatus#player.other#player_other.pid_task, 
						{'mon_drop', PlayerStatus, MonId, MonType,MonLv, GoodList});
		false->
			case lib_mon:get_player(PlayerId, MonScene) of 
				[]->skip;
				Player->
					case is_pid(Player#player.other#player_other.pid_team) of
						true->skip;
						false->
							gen_server:cast(Player#player.other#player_other.pid_task, 
						{'mon_drop', Player, MonId, MonType,MonLv, GoodList})
					end
			end
	end,
	share_mon_drop(PlayerStatus,MonId,MonType,MonLv,PlayerList,MonScene,GoodList).

mon_drop(PlayerStatus,MonId,MonType,MonLv,GoodList)->
%% 	io:format("mon_drop:~p~n",[[MonId,GoodList]]),
	case length(GoodList) > 0 of 
		true->
			task_goods_drop(PlayerStatus,MonId,MonType,GoodList);
		false ->
			skip
	end,
	case MonType =:=6 orelse MonType =:= 7 of
		true->skip;
		false->
			lib_task:task_event(kill, MonId, PlayerStatus),
			lib_task:task_event(hero_kill, {MonLv}, PlayerStatus)
	end.

%%物品掉落
task_goods_drop(_PlayerStatus,_MonId,_MonType,[])->
	ok;
task_goods_drop(PlayerStatus,MonId,MonType,[GoodsInfo|GoodsList])->
	{GoodsId,Num} = GoodsInfo,
	case check_can_gain_item(PlayerStatus,GoodsId) of
		true->
			GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, GoodsId),
			case catch (gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
						{'mon_drop_task_goods',PlayerStatus#player.id,GoodsId,Num,GoodsTypeInfo})) of
				{ok,NowNum} ->
					case MonType =:=6 orelse MonType =:= 7 of
						true->lib_task:task_event(collect, [{GoodsId,NowNum}], PlayerStatus);
						false->lib_task:task_event(item, [{GoodsId,NowNum}], PlayerStatus)
					end;
				_->skip
				end;
		false ->
			skip
	end,
	task_goods_drop(PlayerStatus,MonId,MonType,GoodsList).

%%检查NPC类型
check_npc_type(Npc)->
	%% 0:【没有类型】1:【氏】2:【武】3:【仓】4:【杂】5:【商】6:【铁】
	%%7:【宝】8:【兽】9:【传】10:【镖】11:【药】12:【修】13:【委】14:
	%%【竞】15:【鉴】16:【移】17:【荣】18:【师】19:【副】
	%%10111凤四娘（新手卡领取）10235(牢头——单人副本出口),11005九霄灵儿（处理循环任务 ）
	%%20900红娘
	case is_record(Npc,ets_npc) of
		true->
			if Npc#ets_npc.nid =:= 10235 ->
				   true;
			   true->
					case Npc#ets_npc.nid =:= 10111  orelse Npc#ets_npc.nid =:= 21044 orelse Npc#ets_npc.nid=:=20900 orelse Npc#ets_npc.nid=:=11005 orelse Npc#ets_npc.npctype =/= 0  of
						true ->
							false;
						false->
							true
					end
			end;
		false->
			true
	end.

		   
%% 筛选标签转换函数====================================================================
get_sceneid_by_realm(Realm)->
	case Realm of 
		1->200;
		2->280;
		_->250
	end.

convert_select_tag(_, Val) when is_integer(Val) -> Val;

%% 职业筛选 职业 1，2，3，4，5（分别是玄武--战士、白虎--刺客、青龙--弓手、朱雀--牧师、麒麟--武尊）
convert_select_tag(RS, [career, Z, C, G, M, W ]) ->
    case RS#player.career of
        1 -> Z;
        2 -> C;
        3 -> G;
		4 -> M;
		_ -> W
    end;

%%落部筛选  女娲族、神农族、伏羲族
convert_select_tag(RS, [realm, N, S, F]) ->
    case RS#player.realm of
        1 -> N;
        2 -> S;
        _ -> F
    end;

%% 性别
convert_select_tag(RS, [sex, Msg, Msg2]) ->
    case RS#player.sex of
        1 -> Msg;
        _ -> Msg2
    end;

convert_select_tag(_, Val) -> Val.

%%##############跑环任务参数##############
%% get_cycle_task_exp(PlayerStatus,TD,Type)->
%% 	CycTimes = get_cycle_times(TD#task.id),
%% 	Cycles = get_cycle_task_times(TD#task.id,PlayerStatus,Type),
%% 	Mult = get_task_mult(PlayerStatus#player.lv,Cycles),
%% 	case Cycles < 11 of
%% 		true ->round(math:pow(PlayerStatus#player.lv,Mult) * Cycles* CycTimes+850);
%% 		false ->round(math:pow(PlayerStatus#player.lv,Mult) * CycTimes+850)
%% 	end.

%%循环任务奖励{经验，灵力}
cycle_task_award(PlayerStatus,TD,Type)->
	CycTimes = get_cycle_times(TD#task.id),
	Lv = PlayerStatus#player.lv,
	Cycles = get_cycle_task_times(TD#task.id,PlayerStatus,Type),
	{A,B} = cycle_mult(Lv),
	Exp = Lv * A + Lv * ((Cycles-1)*3+CycTimes) * B,
	{Exp,round(Exp/2)}.

cycle_mult(Lv)->
	if Lv < 40 -> {350,55};
	   Lv < 50 -> {400,95};
	   Lv < 60 -> {450,105};
	   Lv < 70 -> {500,130};
	   Lv < 80 -> {550,160};
	   Lv < 90 -> {600,200};
	   true-> {650,230}
	end.

%%测试接口
%% get_cycle_task_exp_test(LV,Cycles,CycTimes)->
%% 	Mult = get_task_mult(LV,Cycles),
%% 	case Cycles < 11 of
%% 		true ->round(math:pow(LV,Mult) * Cycles* CycTimes+850);
%% 		false ->round(math:pow(LV,Mult) * CycTimes+850)
%% 	end.


get_cycle_task_times(TaskId,PlayerStatus,Type)->
	case Type of
		finish->
			get_today_count(TaskId, PlayerStatus);
		tip->
			get_today_count(TaskId, PlayerStatus)+1
	end.

%% get_task_mult(Level,Times)->
%% 	case Times < 11 of
%% 		true->
%% 			if Level < 45 -> 1.54;
%% 			   Level < 60 -> 1.66;
%% 			   Level < 75 -> 1.71;
%% 			   Level < 90 -> 1.78;
%% 			   true -> 1.8
%% 			end;
%% 		false->
%% 			if Level < 45 -> 1.75;
%% 			   Level < 60 -> 1.82;
%% 			   Level < 75 -> 1.85;
%% 			   Level < 90 -> 1.9;
%% 			   true -> 2
%% 			end
%% 	end.

get_cycle_times(TaskId)->
	case TaskId of
		70100 -> 1;
		70103 -> 2;
		_70106 -> 3
%% 		70109 -> 4;
%% 		70112 -> 5;
%% 		_70115 -> 6
	end.

%%获取随机循环任务奖励
get_random_cycle_award(PlayerStatus,TaskId)->
	Times = get_today_count(TaskId,PlayerStatus),
	Exp = PlayerStatus#player.lv*Times+10000,
	{Exp,round(Exp/2)}.

%%%%%%%%%%%%%%%%%%%%%%%系统委托任务处理%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%查询委托任务
check_consign_task(PlayerStatus,TaskId)->
	case get_data(TaskId) of
		[]->[3,0,<<>>,0,0,0,0,0,0,0];
		TD->
			case check_task_type(TD) of
				false->[2,0,<<>>,0,0,0,0,0,0,0];
				true->
					case (TD#task.type =:= 5 andalso TD#task.child=:=22) orelse TaskId==70100 of
						false->
							{_,CanTimes} = check_task_times(PlayerStatus,TaskId,0),
							{Timestamp,_Total} = get_consign_time(TD),
							GoldNeed = tool:ceil(Timestamp / 60)*CanTimes,
							if TD#task.child =:= 21 ->
%% 								  {Exp,Spt} = get_random_cycle_exp(PlayerStatus,Total,CanTimes,0),
								   [1,TaskId,TD#task.name,CanTimes,round(TD#task.exp*CanTimes),
									TD#task.spt*CanTimes,TD#task.attainment*CanTimes,
								  	Timestamp*CanTimes,GoldNeed,0];
%% 								  [1,TaskId,TD#task.name,CanTimes,Exp,Spt,0,Timestamp*CanTimes,GoldNeed,0];
							   true->
									%%普通日常任务累积补偿
									{_,_,Award,_Day} = get_recoup_coefficient(PlayerStatus),
									[1,TaskId,TD#task.name,CanTimes,round(TD#task.exp*CanTimes*(Award+1)),
									TD#task.spt*CanTimes,TD#task.attainment*CanTimes,
								  	Timestamp*CanTimes,GoldNeed,0]
							end;
						true->
							{Exp,Spt,Cul} = get_cycle_consign_info(PlayerStatus,[70100,70103,70106],{0,0,0}),
							{_,CanTimes} = check_task_times(PlayerStatus,TaskId,0),
							{Timestamp,_} = get_consign_time(TD),
							GoldTotal =tool:ceil(Timestamp*CanTimes / 60),
							[1,TaskId,TD#task.name,CanTimes,Exp,Spt,Cul,
								   Timestamp*CanTimes,GoldTotal,0]
					end
			end
	end.

%%接受委托任务(1成功，2任务不能委托，3委托次数不对，4元宝不足,5任务不存在,6任务已经委托)
accept_consign_task(PlayerStatus,ConsignList)->
	case check_consign_task_bag(ConsignList) of
		ok->
			case check_can_consign(PlayerStatus,ConsignList) of
				{false,ErrorCode}->{false,PlayerStatus,ErrorCode};
				{true,_}->
					{ok,GoldNeed} = calc_consign_gold(ConsignList,0,PlayerStatus#player.lv),
					case goods_util:is_enough_money(PlayerStatus,GoldNeed,gold) of
						false->{false,PlayerStatus,4};
						true->
							NewPlayerStatus = lib_goods:cost_money(PlayerStatus,GoldNeed,gold,3003),
							consign_tips(PlayerStatus,GoldNeed),
							consign_task(NewPlayerStatus,ConsignList),
							spawn(fun()->catch(db_agent:consign_task_log(PlayerStatus#player.id,util:term_to_string(ConsignList),GoldNeed,util:unixtime()))end),
							{true,NewPlayerStatus,1}
					end
			end;
		_->{false,PlayerStatus,3}
	end.

%%委托消耗元宝提示
consign_tips(PlayerStatus,GoldNeed)->
	Msg = io_lib:format("本次委托任务消耗：~p元宝",[GoldNeed]),
	{ok,MyBin} = pt_15:write(15055,[Msg]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin).

%%委托任务
consign_task(_PlayerStatus,[])->
	ok;
consign_task(PlayerStatus,[Task|ConsignList])->
	{TaskId,Times} = Task,
	TD = get_data(TaskId),
	case TD#task.type =:= 5 andalso TD#task.child=:=22 orelse TaskId==70100 of
		false ->
			{TimeNeed,_Total} = get_consign_time(TD),
			Timestamp = util:unixtime()+TimeNeed*Times,
			{ok,Gold} = calc_consign_gold([Task],0,PlayerStatus#player.lv),
			if TD#task.child =:= 21 ->
%% 				   {Exp,Spt} = get_random_cycle_exp(PlayerStatus,Total,Times,0),
				   {_,Id} = db_agent:insert_consign_task(PlayerStatus#player.id,TaskId,Times,Timestamp,
												 round(TD#task.exp*Times),TD#task.spt*Times,0,Gold),
					ets:insert(?ETS_TASK_CONSIGN, #ets_task_consign{id=Id,player_id=PlayerStatus#player.id, task_id=TaskId, 
															times = Times, timestamp = Timestamp,exp =round(TD#task.exp*Times),
															spt = TD#task.spt*Times,cul = TD#task.attainment*Times,gold=Gold});
			   true->
				   {_,_,Award,_Day} = get_recoup_coefficient(PlayerStatus),
				   {_,Id} = db_agent:insert_consign_task(PlayerStatus#player.id,TaskId,Times,Timestamp,
												 round( TD#task.exp*Times*(Award+1)),TD#task.spt*Times,TD#task.attainment*Times,Gold),
					ets:insert(?ETS_TASK_CONSIGN, #ets_task_consign{id=Id,player_id=PlayerStatus#player.id, task_id=TaskId, 
															times = Times, timestamp = Timestamp,exp =round(TD#task.exp*Times*(Award+1)),
															spt = TD#task.spt*Times,cul = TD#task.attainment*Times,gold=Gold})
			end,
			consign(PlayerStatus,TD,Times),
			consign_task(PlayerStatus,ConsignList);
		true->
			{TimeNeed,_} = get_consign_time(TD),
			Timestamp = util:unixtime()+TimeNeed*Times,
			{Exp,Spt,Cul} = get_cycle_consign_info(PlayerStatus,[70100,70103,70106],{0,0,0}),
			{ok,Gold} = calc_consign_gold([Task],0,PlayerStatus#player.lv),
			{_,Id} = db_agent:insert_consign_task(PlayerStatus#player.id,TaskId,Times,Timestamp,
												  Exp,Spt,Cul,Gold),
			ets:insert(?ETS_TASK_CONSIGN, #ets_task_consign{id=Id,player_id=PlayerStatus#player.id, task_id=TaskId, 
															times = Times, timestamp = Timestamp,exp =Exp,
															spt = Spt,cul = Cul,gold=Gold}),
			consign(PlayerStatus,TD,Times),
			consign_task(PlayerStatus,ConsignList)

	end.

get_cycle_consign_info(_PlayerStatus,[],{Exp,Spt,Cul})->
	{Exp,Spt,Cul};
get_cycle_consign_info(PlayerStatus,[TaskId|TaskList],{Exp,Spt,Cul})->
	HadTimes = get_today_count(TaskId, PlayerStatus),
	{NewExp,NewSpt} = calc_cycle_exp(PlayerStatus#player.lv,TaskId,HadTimes+1,{0,0}),
	get_cycle_consign_info(PlayerStatus,TaskList,{Exp+NewExp,Spt+NewSpt,Cul}).

calc_cycle_exp(_Lv,_TaskId,6,{Exp,Spt})->
	{Exp,Spt};
calc_cycle_exp(Lv,TaskId,Cycles,{Exp,Spt})->
	CycTimes = get_cycle_times(TaskId),
	{A,B} = cycle_mult(Lv),
	NewExp = Lv * A + Lv * ((Cycles-1)*3+CycTimes) * B,
	calc_cycle_exp(Lv,TaskId,Cycles+1,{Exp+NewExp,Spt+round(NewExp/2)}).
 
%% %%获取随机循环任务奖励
%% get_random_cycle_exp(_PlayerStatus,_Total,0,Exp)->
%% 	{Exp,round(Exp/2)};
%% get_random_cycle_exp(PlayerStatus,Total,CanTimes,Exp)->
%% 	NewExp = 0,
%% 	get_random_cycle_exp(PlayerStatus,Total,CanTimes-1,Exp+NewExp).

consign(PlayerStatus,TD,0)->
	{ok,PlayerStatus,TD};
consign(PlayerStatus,TD,Times)->
	holiday_award(PlayerStatus,TD),
	TaskId = TD#task.id,
	case TD#task.type =:= 5 andalso TD#task.child=:=22 orelse TaskId==70100  of
		false ->
			case get_trigger_one(PlayerStatus#player.id,TaskId) of
				[]->
					Time = util:unixtime()+Times,
       		     	ets:insert(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=PlayerStatus#player.id, task_id=TaskId, trigger_time = Time, finish_time = Time}),
      		      	mod_task_cache:add_log(PlayerStatus#player.lv, PlayerStatus#player.other#player_other.pid, PlayerStatus#player.id, TaskId,TD#task.type, Time, Time);
				[RT]->
					ets:delete(?ETS_ROLE_TASK, {PlayerStatus#player.id, TaskId}),
					mod_task_cache:del_trigger(PlayerStatus#player.id, TaskId),
					Time = util:unixtime()+Times,
    		        ets:insert(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=PlayerStatus#player.id, task_id=TaskId, trigger_time = RT#role_task.trigger_time, finish_time = Time}),
     		        mod_task_cache:add_log(PlayerStatus#player.lv, PlayerStatus#player.other#player_other.pid, PlayerStatus#player.id, TaskId,TD#task.type, RT#role_task.trigger_time, Time)
			end,
			NewTimes = Times -1,
			consign(PlayerStatus,TD,NewTimes);
		true->
			case get_trigger_one(PlayerStatus#player.id,TaskId) of
				[]->
					Time = util:unixtime()+Times,
			  		record_cycle_task(PlayerStatus,Time,[70100,70103,70106]);
				 [_RT]->
					 ets:delete(?ETS_ROLE_TASK, {PlayerStatus#player.id, TaskId}),
					 mod_task_cache:del_trigger(PlayerStatus#player.id, TaskId),
					 Time = util:unixtime()+Times,
					 record_cycle_task(PlayerStatus,Time,[70100,70103,70106])
			  end,
			consign(PlayerStatus,TD,0)
	end.
			
%%处理循环任务日志
record_cycle_task(_PlayerStatus,_Timestamp,[])->
	ok;
record_cycle_task(PlayerStatus,Timestamp,[TaskId|TaskList])->
	PlayerId = PlayerStatus#player.id,
	HadFinish = get_today_count(TaskId, PlayerStatus),
	TD = get_data(TaskId),
	{_,AllTimes} = get_consign_time(TD),
	CanTimes = AllTimes-HadFinish,
	deal_cycle_task_log(PlayerStatus#player.lv,PlayerStatus#player.other#player_other.pid,PlayerId,TaskId,Timestamp,CanTimes),
	record_cycle_task(PlayerStatus,Timestamp,TaskList).

deal_cycle_task_log(_Lv,_Pid,_PlayerId,_TaskId,_Timestamp,0)->
	ok;
deal_cycle_task_log(Lv,Pid,PlayerId,TaskId,Timestamp,Times)->
	NewTimestamp = Timestamp  +Times,
	ets:insert(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=PlayerId, task_id=TaskId, trigger_time = NewTimestamp, finish_time = NewTimestamp}),
	TD = get_data(TaskId),
	mod_task_cache:add_log(Lv, Pid, PlayerId, TaskId,TD#task.type, NewTimestamp, NewTimestamp),
	deal_cycle_task_log(Lv,Pid,PlayerId,TaskId,Timestamp,Times-1).

%%计算委托金
calc_consign_gold([],Gold,_Lv)->
	{ok,Gold};
calc_consign_gold([Task|CosignList],Gold,Lv)->
	{TaskId,Times} = Task,
	TD = get_data(TaskId),
	case TD#task.type =:= 5 andalso TD#task.child=:=22 orelse TaskId==70100 of
		false->
			{Timestamp,_} = get_consign_time(TD),
			GoldNeed = tool:ceil(Timestamp / 60) * Times,
			calc_consign_gold(CosignList,Gold+GoldNeed,Lv);
		true->
			{Timestamp,_} = get_consign_time(TD),
			GoldTotal =tool:ceil( Timestamp * Times / 60 ),
			calc_consign_gold(CosignList,Gold+GoldTotal,Lv)
	end.
	

%%检查委托任务包
check_consign_task_bag(ConsignList)->
	TaskList = [TaskId||{TaskId,_}<-ConsignList],
	check_task_num(TaskList,TaskList).

check_task_num(_TaskList,[])->
	ok;
check_task_num(TaskList,[TaskId|T])->
	TD = get_data(TaskId),
	{_,Times} = get_consign_time(TD),
	case length([Id||Id<-TaskList,Id=:=TaskId]) > Times of
		true->error;
		false->check_task_num(TaskList,T)
	end.

%%检查任务是否能够委托
check_can_consign(_PlayerStatus,[])->
	{true,1};
check_can_consign(PlayerStatus,[Task|ConsignList])->
	{TaskId,Times} = Task,
	case get_data(TaskId) of
		[]->{false,5};
		TD->
			case check_task_type(TD) of
				true->
					case check_task_times(PlayerStatus,TaskId,Times) of
						{true,_}->
							case check_task_state(PlayerStatus#player.id,TaskId) of
								true->check_can_consign(PlayerStatus,ConsignList);
								false->{false,6}
							end;
						{false,_}->{false,3}
					end;
				false->{false,2}
			end
	end.

check_task_state(PlayerId,TaskId)->
	case get_consign_task_one(PlayerId,TaskId) of
		[]->true;
		_->false
	end.

%%检查任务类型
check_task_type(TD)->
	if TD#task.type =:= 2 andalso TD#task.child =:= 1->true;
	   TD#task.type =:= 2 andalso TD#task.child =:= 5 ->true;
	   TD#task.type =:= 5 andalso TD#task.child =:= 21 ->true;
	   TD#task.type =:= 5 andalso TD#task.child=:=22 orelse TD#task.id==70100 ->true;
	   true->false
	end.

%%获取委托时间
get_consign_time(TD)->
	Times = check_daily_times(TD#task.condition),
	{Gold,_} = 
		if TD#task.type =:= 2 andalso TD#task.child =:= 1->
		   if TD#task.level =< 30->{600,2};
			  TD#task.level =< 35->{600,2};
			  TD#task.level =< 40 ->{1400,1};
			  TD#task.level =< 45 ->{1400,1};
			  TD#task.level =< 50 ->{2400,1};
			  TD#task.level =< 55 ->{2400,1};
			  TD#task.level =< 60 ->{3000,1};
			  TD#task.level =< 65 ->{3000,1};
			  TD#task.level =< 70 ->{3000,1};
			  true-> {3600,1}
		   end;
	   TD#task.type =:= 2 andalso TD#task.child =:= 5 ->
		   if TD#task.level =< 30 -> {600,1};
			  TD#task.level =< 40 -> {720,1};
			  TD#task.level =< 50 -> {900,1};
			  true->{900,1}
		   end;
	   TD#task.type =:= 5 andalso TD#task.child =:= 21->
		    if TD#task.level < 40 -> 
				   if TD#task.id =:= 83140 ->{210,15};
					  TD#task.id =:= 83141 ->{210,15};
					  true->
				   		{210,10}
				   end;
			  	TD#task.level < 50 -> {300,10};
			 	 TD#task.level < 60 -> {360,10};
			   TD#task.level < 70 -> {420,10};
			  true->{480,10}
		   end;
	   TD#task.type =:= 5 andalso TD#task.child=:=22 orelse TD#task.id==70100->{240,5};
	   true->{0,0}
	end,
	{Gold,Times}.


%%获取任务可委托次数[["daily_limit","2"]]
check_daily_times([])->
	0;
check_daily_times([Type|Condition])->
	case Type of
		{daily_limit,Times}->Times;
		_->check_daily_times(Condition)
	end.

%%检查任务次数
check_task_times(PlayerStatus,TaskId,Times)->
	TD = get_data(TaskId),
	case TD#task.type =:= 5 andalso TD#task.child=:=22 orelse TD#task.id==70100of
		false->
			HadFinish = get_today_count(TaskId, PlayerStatus),
			{_,AllTimes} = get_consign_time(TD),
			CanTimes = AllTimes -HadFinish,
			case CanTimes >= Times of
				true->{true,CanTimes};
				false->{false,CanTimes}
			end;
		true->
			CanTimes = check_cycle_times(PlayerStatus,0,[70100,70103,70106]),
			case CanTimes>= Times of
				true->{true,CanTimes};
				false->{false,CanTimes}
			end
	end.

check_cycle_times(_PlayerStatus,Times,[])->
	Times;
check_cycle_times(PlayerStatus,Times,[TaskId|TaskList])->
	HadFinish = get_today_count(TaskId, PlayerStatus),
	TD = get_data(TaskId),
	{_,AllTimes} = get_consign_time(TD),
	CanTimes = AllTimes-HadFinish,
	check_cycle_times(PlayerStatus,CanTimes+Times,TaskList).

%%检查委托是否完成
check_consign_finish(PlayerStatus,[],NewConsignTask)->
	{PlayerStatus,NewConsignTask};
check_consign_finish(PlayerStatus,[Task|ConsignTask],NewConsignTask)->
	{TaskId,_Name,_Times,Exp,Spt,Cul,Timestamp,_Gold,_Mark}=Task,
	case util:unixtime() >= Timestamp of
		true->
			NewPlayerStatus = finish_consign_task(PlayerStatus,[TaskId,Exp,Spt,Cul,Timestamp]),
			check_consign_finish(NewPlayerStatus,ConsignTask,NewConsignTask);
		false->
			check_consign_finish(PlayerStatus,ConsignTask,[Task|NewConsignTask])
	end.

%%立即完成所有的委托任务
finish_consign_task_now(PlayerStatus)->
	case lib_task:get_consign_task(PlayerStatus#player.id) of
		[]->{2,PlayerStatus};
		TaskBag->
			Gold = calc_finish_gold(TaskBag,0),
			case goods_util:is_enough_money(PlayerStatus,Gold,gold) of
				false->{3,PlayerStatus};
				true->
					NewPlayerStatus = lib_goods:cost_money(PlayerStatus,Gold,gold,3006),
					NewPlayerStatus1 = finish_consign_now(TaskBag,NewPlayerStatus),
					consign_finish_tips(NewPlayerStatus1,Gold),
					{1,NewPlayerStatus1}
			end
	end.

calc_finish_gold([],Gold)->tool:ceil(Gold/2);
calc_finish_gold([Task|TaskBag],Gold)->
	calc_finish_gold(TaskBag,Gold+Task#ets_task_consign.gold).

finish_consign_now([],PlayerStatus)->
	PlayerStatus;
finish_consign_now([Task|TaskBag],PlayerStatus)->
	NewPlayer  = finish_consign_task(PlayerStatus,[Task#ets_task_consign.task_id,
												   Task#ets_task_consign.exp,
												   Task#ets_task_consign.spt,
												   Task#ets_task_consign.cul,
												   Task#ets_task_consign.timestamp]),
	finish_consign_now(TaskBag,NewPlayer).

%%委托消耗元宝提示
consign_finish_tips(PlayerStatus,GoldNeed)->
	Msg = io_lib:format("立即完成本次委托任务消耗：~p元宝",[GoldNeed]),
	{ok,MyBin} = pt_15:write(15055,[Msg]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin).

finish_consign_task(PlayerStatus,TaskBag)->
	[TaskId,Exp,Spt,Cul,Timestamp]=TaskBag,
	delete_consign_task(PlayerStatus#player.id,TaskId,Timestamp),
	case get_data(TaskId) of
		[]->
			PlayerStatus;
		TD->
			NewPlayerStatus1 = lib_player:add_spirit(PlayerStatus,Spt),
			NewPlayerStatus2 = lib_player:add_culture(NewPlayerStatus1,Cul),
			NewPlayerStatus3 = lib_player:add_exp(NewPlayerStatus2,Exp, 0, 0),
			consign_goods(PlayerStatus,TD),
			NewPlayerStatus3
	end.

%%委托任务物品，通过邮件发放
consign_goods(PlayerStatus,Task)->
	case get_award_item(Task, PlayerStatus) of
		[] -> skip;
		Items ->
			F = fun(GoodsTypeId, GoodsNum) ->
								NameList = [tool:to_list(PlayerStatus#player.nickname)],
								Content =io_lib:format("恭喜你完成【~s】的委托，获得物品奖励，请及时领取。 ",[Task#task.name]),
								mod_mail:send_sys_mail(NameList, "委托任务", Content, 0,GoodsTypeId, GoodsNum, 0,0,0)
						end,
			[F(Id, Num) || {Id, Num} <- Items]
%% 			case gen_server:call(PlayerStatus#player.other#player_other.pid_goods,{'cell_num'})< length(Items) of
%% 				false->
%% 					F = fun(GoodsTypeId, GoodsNum) ->
%% 								gen_server:call(PlayerStatus#player.other#player_other.pid_goods, 
%% 												{'give_goods', PlayerStatus, GoodsTypeId, GoodsNum,2})
%% 						end,
%% 					[F(Id, Num) || {Id, Num} <- Items];
%% 				true->
%% 					F = fun(GoodsTypeId, GoodsNum) ->
%% 								NameList = [tool:to_list(PlayerStatus#player.nickname)],
%% 								Content =io_lib:format("恭喜你完成【~s】的委托，获得物品奖励，请及时领取。 ",[Task#task.name]),
%% 								mod_mail:send_sys_mail(NameList, "委托任务", Content, 0,GoodsTypeId, GoodsNum, 0,0)
%% 						end,
%% 					[F(Id, Num) || {Id, Num} <- Items]
%% 			end
	end.
	

delete_consign_task(PlayerId,TaskId,Timestamp)->
	ets:match_delete(?ETS_TASK_CONSIGN, #ets_task_consign{player_id=PlayerId,task_id=TaskId,timestamp=Timestamp, _='_'}),
	db_agent:delete_consign_task(PlayerId,TaskId,Timestamp),
	ok.

%%%%%%%%%%%%%%%每日任务活动处理%%%%%%%%%%
check_send(PlayerStatus,MoneyType)->
	case lib_deliver:could_deliver(PlayerStatus) of
		ok->
			case MoneyType of
				1->
					case goods_util:is_enough_money(PlayerStatus, 3, gold) of
						true->{ok,1};
						false->{error,2}
					end;
				2->
					case goods_util:is_enough_money(PlayerStatus, 5000, coin) of
						true->{ok,1};
						false->{error,3}
					end;
				_->{ok,1}
			end;
		ErrorCode ->
			{error,ErrorCode}
	end.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%玩家委托任务%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%发布委托任务1发布成功，2任务没有接，3任务不存在,4物品1不存在，5物品1数量不足，6物品2不存在，
 %%7物品数量不足，8金钱奖励不能为0,9金钱奖励不足,10委托时间不对,11今天已委托三次,12数据异常,
	%%13委托手续费不足,14玩家等级不到30以上,15物品类型不对,16委托奖励不能为空,17该任务不能委托
publish_consign_task(PlayerStatus,TaskBag)->
	case lib_consign:check_publish_times(PlayerStatus#player.id) of
		{error,Error}->{error,Error};
		{ok,_}->
			case PlayerStatus#player.lv >= 30 of
				false->{error,14};
				true->
					[TaskId,Time,GoodsId1,Num1,GoodsId2,Num2,MoneyType,Num3] = TaskBag,
					if Num1 =:= 0 andalso Num2=:=0 andalso Num3 =:=0 ->
						   {error,15};
					true->
						case get_one_trigger(TaskId, PlayerStatus) of
							false->{error,2};
							Task->
								case get_data(TaskId) of
									[]->{error,3};
									RT->
										case check_task(Task,RT) of
											false->{error,17};
											true->
												case check_consign_goods(PlayerStatus,[[1,GoodsId1,Num1],[2,GoodsId2,Num2]]) of
													{error,ER}->{error,ER};
													{ok,_}->
														case check_consign_goods_both(PlayerStatus,[GoodsId1,Num1,GoodsId2,Num2]) of
															{ok,_}->
																PublishMoney = publish_money(Time,RT#task.level),
																case check_consign_money(PlayerStatus,MoneyType,Num3,PublishMoney) of
																	{error,Result}->{error,Result};
																	{ok,_}->
																		case change_time(Time) of
																			0->{error,10};
																			_->
																				NowTime = util:unixtime(),
																				AutoId = db_agent:get_task_auto_id(PlayerStatus#player.id,TaskId),
																				ConsignTask = [PlayerStatus#player.id,TaskId,RT#task.name,RT#task.level,Time,
																							 		  GoodsId1,Num1,GoodsId2,Num2,MoneyType,Num3,NowTime,AutoId],
																				mod_consign:publish_consign_task(ConsignTask),
																				change_task_state(PlayerStatus,Task,AutoId,NowTime),
																				NewPlayerStatus = case MoneyType of
																					  1->lib_goods:cost_money(PlayerStatus,Num3,coinonly,3005);
																					  _->lib_goods:cost_money(PlayerStatus,Num3,gold,3005)
																  				end,
																				NewPlayerStatus1 = lib_goods:cost_money(NewPlayerStatus,PublishMoney,coin,3006),
																				del_consign_goods(NewPlayerStatus1,[[GoodsId1,Num1],[GoodsId2,Num2]]),
																				lib_consign:update_publish_times(NewPlayerStatus1#player.id),
																				ConsignInfo = lib_consign:get_consign_times_list(NewPlayerStatus1#player.id),
																				mod_consign:check_consign_task(NewPlayerStatus1,ConsignInfo),
																				lib_player:send_player_attribute(NewPlayerStatus1, 1),
																				{ok,NewPlayerStatus1}
																	end
																end;
																{error,ErrorC}->{error,ErrorC}
														end
												end
										end
								end
						end	
					end
			end
	end.

%%修改发布玩家的任务状态
change_task_state(PlayerStatus,Task,AutoId,NowTime)->
	ets:delete(?ETS_ROLE_TASK,{PlayerStatus#player.id,Task#role_task.task_id}),
	db_agent:update_task_state(AutoId,2),
	ets:insert(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=PlayerStatus#player.id,
												  task_id=Task#role_task.task_id,
												  trigger_time = Task#role_task.trigger_time,
												  finish_time = NowTime}),
	TD = get_data(Task#role_task.task_id),
	mod_task_cache:add_log(PlayerStatus#player.lv, PlayerStatus#player.other#player_other.pid, PlayerStatus#player.id, Task#role_task.task_id, TD#task.type,Task#role_task.trigger_time, NowTime),
	gen_server:cast(PlayerStatus#player.other#player_other.pid_task,{'refresh_task',PlayerStatus}).

%%检查任务类型
check_task(TaskBag,Task)->
	case TaskBag#role_task.type =/= 1 of
		false->false;
		true->
			if Task#task.type =:= 3 ->true;
			   Task#task.type=:= 2 andalso Task#task.child =:= 6 andalso Task#task.kind =:=1 ->true;
			   true->false
			end
	end.

check_consign_goods_both(PlayerStatus,GoodsList)->
	[Goods1Id,Num1,Goods2id,Num2]=GoodsList,
	if Goods1Id =:= Goods2id andalso Goods1Id>0 ->
		   GoodsNum = goods_util:get_goods_num_unbind_trade(PlayerStatus#player.id, Goods1Id, 4, 0, 0),
			case GoodsNum >= Num1+Num2 of
				true->{ok,1};
				false->{error,7}
		   end;
	   true->{ok,1}
	end.

%%检查委托奖励物品
check_consign_goods(_PlayerStatus,[])->
	{ok,1};
check_consign_goods(PlayerStatus,[T|GoodsList])->
	[P,GoodsId,Num] = T,
	case GoodsId > 0 andalso Num>0 of
		false->
			check_consign_goods(PlayerStatus,GoodsList);
		true->
			GoodsNum = goods_util:get_goods_num_unbind_trade(PlayerStatus#player.id, GoodsId, 4, 0, 0),
			case GoodsNum >= Num of
				true->
					case check_goods_type(GoodsId) of
						{ok,_}->check_consign_goods(PlayerStatus,GoodsList);
						{error,Re}->{error,Re}
					end;
				false->
					case P of
						1->{error,5};
						_->{error,7}
					end
			end
	end.

%%检查物品类型
check_goods_type(GoodsId)->
	Goods = goods_util:get_goods_type(GoodsId),
	case Goods#ets_base_goods.type of
		15->
			if Goods#ets_base_goods.subtype >=10  andalso Goods#ets_base_goods.subtype =< 14 ->
				{ok,1};
			true->{error,15}
			end;
		20->
			if Goods#ets_base_goods.subtype >=10  andalso Goods#ets_base_goods.subtype =< 13 ->
				{ok,1};
			true->{error,15}
			end;
		30->
			if Goods#ets_base_goods.subtype >=10  andalso Goods#ets_base_goods.subtype =< 11 ->
				{ok,1};
			true->{error,15}
			end;
		_->{error,15}
	end.

%%删除委托物品
del_consign_goods(_PlayerStatus,[])->
	ok;
del_consign_goods(PlayerStatus,[Goods|T])->
	[GoodsId,Num]=Goods,
	if  GoodsId > 0 andalso Num>0 ->
		gen_server:call(PlayerStatus#player.other#player_other.pid_goods,{'delete_more_unbind', GoodsId,Num});
		true->skip
		end,
	del_consign_goods(PlayerStatus,T).

%%检查委托金
check_consign_money(PlayerStatus,MoneyType,Num,PublishMoney)->
	case Num < 0 of
		true->{error,12};
		false->
			case Num > 0 of
				false->
					{ok,1};
				true->
					Type = check_money_type(MoneyType),
					case goods_util:is_enough_money(PlayerStatus,Num,Type) of
						true->
							case goods_util:is_enough_money(PlayerStatus,Num+PublishMoney,coin) of
								true->{ok,1};
								false->{error,13}
							end;
						false->{error,9}
					end
			end
	end.

%%检查委托金类型
check_money_type(Type)->
	case Type of 
		1->coinonly;
		2->gold;
		_->cash
	end.

%%检查委托时间
change_time(Time)->
	NowTime = util:unixtime(),
	case Time of 
		6->NowTime+6*3600;
		12->NowTime+12*3600;
		24->NowTime+24*3600;
		_->0
	end.


%%委托手续费
publish_money(Time,Lv)->
	round(Time / 6 * Lv * 250).
%%接受委托押金
accept_money(Time,Lv)->
	round(2* Time / 6 *Lv * 250).

%%接受玩家委托的任务(1接受成功，2玩家已经接了相类似的任务，3接受失败，4任务已经被接，5任务已过期，
%%6任务不存在,7任务押金不足,8不能接受自己发布的任务,9今天接受委托到达上限，10数据异常)
accept_task_consign(PlayerStatus,TaskBag)->
	case lib_consign:check_accept_times(PlayerStatus#player.id) of
		{error,ErrorCode1} -> {error,ErrorCode1};
		{ok,_}->
			[Id,TaskId]= TaskBag,
			case get_employ_task(PlayerStatus#player.id) of
				[]->
					case get_one_trigger(TaskId, PlayerStatus) of
						false->
							case mod_consign:get_consign_task(Id) of
								{ok,[]}->{error,6};
								{ok,ConsignTask}->
									case ConsignTask#ets_consign_task.state =:= 0 of
										false -> {error,4};
										true->
											case ConsignTask#ets_consign_task.pid =/= PlayerStatus#player.id of
												false->{error,8};
												true->
													AcceptMoney = accept_money(ConsignTask#ets_consign_task.t1,ConsignTask#ets_consign_task.lv),
													case goods_util:is_enough_money(PlayerStatus,AcceptMoney,coinonly) of
													false->{error,7};
													true->
														GoodsWarid = [{ConsignTask#ets_consign_task.gid_1,ConsignTask#ets_consign_task.n_1},
														{ConsignTask#ets_consign_task.gid_2,ConsignTask#ets_consign_task.n_2}],
														case trigger_other_condition(GoodsWarid,PlayerStatus) of
															false->{error,10};
															true->
																EndTime = change_time(ConsignTask#ets_consign_task.t1),
																case trigger(TaskId, 0, PlayerStatus,1) of
																	{true,NewPlayerStatus}->
																		NewTaskBag = [NewPlayerStatus#player.id,EndTime,ConsignTask],
																		mod_consign:accept_consign_task(NewTaskBag),
																		lib_consign:update_accept_times(NewPlayerStatus#player.id),
																		NewPlayerStatus1 = lib_goods:cost_money(NewPlayerStatus,AcceptMoney,coinonly,3006),
																		{ok, BinData} = pt_30:write(30006, [1,0]),
				            											lib_send:send_to_sid(NewPlayerStatus1#player.other#player_other.pid_send, BinData),
																		PlayerName= lib_player:get_role_name_by_id(ConsignTask#ets_consign_task.pid),
																		NameList = [tool:to_list(PlayerName)],
																		Content =io_lib:format( "玩家【~s】接受了您发布的雇佣任务：~s",[NewPlayerStatus#player.nickname,ConsignTask#ets_consign_task.name]),
																		mod_mail:send_sys_mail(NameList, "系统信件", Content, 0, 0, 0, 0,0),
																		ConsignInfo = lib_consign:get_consign_times_list(NewPlayerStatus1#player.id),
																		mod_consign:check_consign_task(NewPlayerStatus1,ConsignInfo),
																		save_player_table(NewPlayerStatus1,PlayerStatus,add),
%% 																		mod_player:save_online(NewPlayerStatus1),
																		{ok,NewPlayerStatus1};
																	{false,CodeString}->{error,CodeString}
																end
														end
												end
										end
									end
							end;
					_Task->{error,2}
					end;
				_->{error,2}
			end
	end.

%%完成委托任务
finish_task_consign(PlayerStatus,TaskBag)->
	case mod_consign:get_consign_task_by_accept(PlayerStatus#player.id,TaskBag#role_task.task_id) of
		{ok,[]}->
			accept_consign_task_online(PlayerStatus,TaskBag#role_task.task_id),
			PlayerStatus;
		{ok,ConsignTask}->
			NowTime = util:unixtime(),
			accept_consign_task_online(PlayerStatus,TaskBag#role_task.task_id),
			case NowTime > ConsignTask#ets_consign_task.t3 of
				true->
					mod_consign:reset_consign_task(ConsignTask#ets_consign_task.id),
					Content_A =io_lib:format( "您接受的雇佣任务【~s】超时，任务失败,不能获得奖励！",[ConsignTask#ets_consign_task.name]),
					mod_mail:send_sys_mail([tool:to_list(PlayerStatus#player.nickname)], "雇佣信件", Content_A, 0, 0, 0, 0,0),
					PlayerName= lib_player:get_role_name_by_id(ConsignTask#ets_consign_task.pid),
					Content_P =io_lib:format( "玩家【~s】任务失败，您的雇佣任务【~s】重置！",[PlayerStatus#player.nickname,ConsignTask#ets_consign_task.name]),
					mod_mail:send_sys_mail([tool:to_list(PlayerName)], "雇佣信件", Content_P, 0, 0, 0, 0,0),
					PlayerStatus;
				false->
					GoodsBag = [{ConsignTask#ets_consign_task.gid_1,ConsignTask#ets_consign_task.n_1},
								{ConsignTask#ets_consign_task.gid_2,ConsignTask#ets_consign_task.n_2}],
					give_consign_goods(PlayerStatus,GoodsBag),
					MoneyType =check_money_type(ConsignTask#ets_consign_task.mt),
					NewPlayerStaus = lib_goods:add_money(PlayerStatus,ConsignTask#ets_consign_task.n_3,MoneyType,3005),
					CoinBack = accept_money(ConsignTask#ets_consign_task.t1,ConsignTask#ets_consign_task.lv),
					NewPlayerStaus_1 = lib_goods:add_money(NewPlayerStaus,CoinBack,coinonly,3005),
					mod_consign:finish_consign_task([ConsignTask#ets_consign_task.id]),
					finish_publish_task(ConsignTask,1,NewPlayerStaus_1#player.nickname),
					NewPlayerStaus_1
			end
	end.

%%处理发布玩家的委托任务
finish_publish_task(ConsignTask,Result,NickName)->
	case lib_player:get_online_info(ConsignTask#ets_consign_task.pid) of
		[]->
			change_consign_task_offline(ConsignTask#ets_consign_task.pid,ConsignTask,Result,NickName),
			ok;
		PlayerStatus->
			gen_server:cast(PlayerStatus#player.other#player_other.pid_task,
							{'change_consign_task_online',PlayerStatus,ConsignTask,Result,NickName}),
			ok
	end.

%%发布任务的玩家在线
change_consign_task_online(PlayerStatus,ConsignTask,Result,NickName)->
%% 	TaskId = ConsignTask#ets_consign_task.tid,
	case Result of 
		1->
			%%
			Task = get_data(ConsignTask#ets_consign_task.tid),
			case Task#task.type =:= 3 andalso PlayerStatus#player.guild_id =:= 0 of
				true->
					Content =io_lib:format( "玩家【~s】成功完成了您发布的雇佣任务：~s，已经领取奖 励。但是届于你没有氏族，所以你的氏族任务提交失败。",[NickName,Task#task.name]),
					mod_mail:send_sys_mail([tool:to_list(PlayerStatus#player.nickname)], "雇佣信件", Content, 0, 0, 0, 0,0);
				false->
					%%增加氏族经验
					add_guild_exp(PlayerStatus,Task),
					%%增加灵力
					PlayerStatus_1 = add_spirit(PlayerStatus,Task),
					%%增加绑定铜
					PlayerStatus_2 = add_bind_coin(PlayerStatus_1,Task),
					%%增加修为
					PlayerStatus_3 = add_culture(PlayerStatus_2,Task),
					%%增加经验和铜钱
					PlayerStatus_4=add_exp_and_coin(PlayerStatus_3,Task),
					save_player_table(PlayerStatus_4,PlayerStatus,add),
					mod_player:save_online_diff(PlayerStatus,PlayerStatus_4),
					gen_server:cast(PlayerStatus_4#player.other#player_other.pid,{'SET_PLAYER',PlayerStatus_4}),
					{_,_,Award,_Day} = get_recoup_coefficient(PlayerStatus_4),
					AwardBag=[round((Award+1)*Task#task.exp),Task#task.spt,Task#task.attainment,Task#task.coin,
					  Task#task.binding_coin,Task#task.guild_exp,Task#task.contrib],
					task_finish_mail(PlayerStatus#player.nickname,NickName,Task#task.name,AwardBag)
			end,
			%% 数据库回写
			db_agent:del_task_by_id(ConsignTask#ets_consign_task.autoid);
		0->
			ok
	end.

%%发布任务的玩家离线
change_consign_task_offline(PlayerId,ConsignTask,Result,PlayerName_A)->
	case Result of
		1->
			db_agent:del_task_by_id(ConsignTask#ets_consign_task.autoid),
			Task = get_data(ConsignTask#ets_consign_task.tid),
			PlayerName_P= lib_player:get_role_name_by_id(PlayerId),
			case Task#task.type =:= 3 andalso db_agent:get_guild_id(ConsignTask#ets_consign_task.pid)=:= 0 of
				true->
					Content =io_lib:format( "玩家【~s】成功完成了您发布的雇佣任务：~s，已经领取奖 励。但是届于你没有氏族，所以你的氏族任务提交失败。",[PlayerName_A,Task#task.name]),
					mod_mail:send_sys_mail([tool:to_list(PlayerName_P)], "雇佣信件", Content, 0, 0, 0, 0,0);
				false->
%% 					{_,_,Award,_Day} = get_recoup_coefficient(PlayerId),
					Award=0,
					AwardBag=[round((Award+1)*Task#task.exp),Task#task.spt,Task#task.attainment,Task#task.coin,
							  Task#task.binding_coin,Task#task.guild_exp,Task#task.contrib],
					lib_consign:update_consign_award(PlayerId,AwardBag),
					task_finish_mail(PlayerName_P,PlayerName_A,Task#task.name,AwardBag)
			end;
		0->ok
	end.

%%任务完成，发送系统邮件
task_finish_mail(PlayerName_P,Name,TaskName,AwardBag)->
	[Exp,Spt,Cul,Coin,Bcoin,Ge,Gc] = AwardBag,
	Content =io_lib:format( "玩家【~s】完成您发布的雇佣任务【~s】，您获得以下奖励：经验：~p、灵力：~p、修为：~p、铜币：~p、绑定铜币：~p、氏族经验：~p、氏族贡献：~p。",[Name,TaskName,Exp,Spt,Cul,Coin,Bcoin,Ge,Gc]),
	mod_mail:send_sys_mail([tool:to_list(PlayerName_P)], "雇佣信件", Content, 0, 0, 0, 0,0).
	
%%接受委托任务的玩家在线
accept_consign_task_online(PlayerStatus,TaskId)->
	%%更新缓存
	ets:delete(?ETS_ROLE_TASK, {PlayerStatus#player.id, TaskId}),
	%% 数据库回写
	mod_task_cache:del_trigger(PlayerStatus#player.id, TaskId),
	%%刷新任务
	refresh_active(PlayerStatus),
	{ok, BinData} = pt_30:write(30006, [1,0]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData).

%%玩家登陆获取委托奖励
get_consign_award(PlayerStatus)->
	[Exp,Spt,Cul,Coin,BCoin,Ge,Gc]= 
		case lib_consign:select_consign_award(PlayerStatus#player.id) of
			[]->[0,0,0,0,0,0,0];
			Award->Award
		end,
	case Gc > 0 orelse Ge>0 of
		true -> mod_guild:increase_guild_exp(PlayerStatus#player.id, PlayerStatus#player.guild_id,Ge,Gc,0,0);
        false -> false
    end,
	PlayerStatus1 = lib_player:add_spirit(PlayerStatus,Spt),
	PlayerStatus2 = lib_player:add_culture(PlayerStatus1,Cul),
	PlayerStatus3 = lib_player:add_exp(PlayerStatus2,Exp, 0, 0),
	PlayerStatus4 = lib_player:add_coin(PlayerStatus3,Coin),
	PlayerStatus5 = lib_player:add_bcoin(PlayerStatus4,BCoin),
	case PlayerStatus5 =/= PlayerStatus of
		false->PlayerStatus;
		true->
			lib_consign:reset_consign_award(PlayerStatus5#player.id),
			save_player_table(PlayerStatus5,PlayerStatus,add),
			PlayerStatus5
	end.

%%委托物品奖励
give_consign_goods(_PlayerStatus,[])->
	ok;
give_consign_goods(PlayerStaus,[Goods|T])->
	{GoodsId,Num}=Goods,
	case GoodsId>0 andalso Num>0 of
		false->skip;
		true->
			gen_server:call(PlayerStaus#player.other#player_other.pid_goods, {'give_goods', PlayerStaus,GoodsId, Num,0}) 
	end,
	give_consign_goods(PlayerStaus,T).	

%%取消委托任务(1任务不存在，2任务不属于你，3任务完成中)
cancel_task_consign(PlayerStatus,Id)->
	case mod_consign:get_consign_task(Id) of
		{ok,[]}->{error,1};
		{ok,ConsignTask}->
			case ConsignTask#ets_consign_task.pid =:= PlayerStatus#player.id of
				false->{error,2};
				true->
					case ConsignTask#ets_consign_task.state =:= 0 of
						false->{error,3};
						true->
							mod_consign:finish_consign_task([ConsignTask#ets_consign_task.id]),
							NameList = [tool:to_list(PlayerStatus#player.nickname)],
							Content = "您的取消了雇佣任务，退还任务奖励！",
							case ConsignTask#ets_consign_task.gid_1 > 0 andalso ConsignTask#ets_consign_task.n_1>0 of
								false->skip;
								true->
									mod_mail:send_sys_mail(NameList, "雇佣信件", Content, 0,ConsignTask#ets_consign_task.gid_1, ConsignTask#ets_consign_task.n_1, 0, 0)
							end,
							case ConsignTask#ets_consign_task.gid_2 > 0 andalso ConsignTask#ets_consign_task.n_2>0 of
								false->skip;
								true->
									mod_mail:send_sys_mail(NameList, "雇佣信件", Content, 0,ConsignTask#ets_consign_task.gid_2, ConsignTask#ets_consign_task.n_2, 0, 0)
							end,
							case ConsignTask#ets_consign_task.n_3 > 0 of
								false->skip;
								true->
									case ConsignTask#ets_consign_task.mt of
									1->
										mod_mail:send_sys_mail(NameList, "雇佣信件", Content, 0,0, 0,  ConsignTask#ets_consign_task.n_3,0);
										_->
											mod_mail:send_sys_mail(NameList, "雇佣信件", Content, 0,0, 0, 0, ConsignTask#ets_consign_task.n_3)
									end
							end,
							lib_consign:reset_publish_times(PlayerStatus#player.id),
							case db_agent:get_task_by_auto_id(ConsignTask#ets_consign_task.autoid) of
								[]->skip;
								[TriggerTime] ->
									db_agent:del_task_log(PlayerStatus#player.id,ConsignTask#ets_consign_task.tid,TriggerTime),
									ets:match_delete(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=PlayerStatus#player.id,
																				task_id= ConsignTask#ets_consign_task.tid,
																				trigger_time=TriggerTime,_='_'})
							end,
							db_agent:del_task_by_id(ConsignTask#ets_consign_task.autoid),
							ConsignInfo = lib_consign:get_consign_times_list(PlayerStatus#player.id),
							mod_consign:check_consign_task(PlayerStatus,ConsignInfo),
							{ok,1}
					end
			end
	end.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%日常任务补偿 系数%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
get_daily_task_info(PlayerStatus)->
	{_,TaskList,Award,_} = get_recoup_coefficient(PlayerStatus),
	case Award of 
		0->[];
		_->
			check_today_count(PlayerStatus,TaskList,round(Award*100),[])
	end.

%%获取补偿系数(20120109屏蔽)
get_recoup_coefficient(_PlayerStatus)->
%% 	DailyTaskIds = data_task:task_get_normal_daily_id_list(),
%% 	GuildTaskIds = data_task:task_get_guild_id_list(),
%% 	TaskList = DailyTaskIds++GuildTaskIds,
%% 	DateList = [1,2,3],
%% 	{Day,Award} = check_task_recoud(PlayerStatus,DateList,TaskList),
%% 	{ok,TaskList,Award,Day}.
	{ok,[],0,0}.

check_today_count(_PlayerStatus,[],_Award,TaskBag)->
	TaskBag;
check_today_count(PlayerStatus,[TaskId|TaskList],Award,TaskBag)->
	Td = get_data(TaskId),
	Times = check_daily_times(Td#task.condition),
	case get_today_count(TaskId,PlayerStatus) >= Times of
		true->
			check_today_count(PlayerStatus,TaskList,Award,TaskBag);
		false->
%% 			Td  = get_data(TaskId),
			case Td#task.type =:= 2 andalso Td#task.child =:= 1 of
				true->
					if Td#task.level < 35 ->
						   case PlayerStatus#player.lv >= Td#task.level andalso PlayerStatus#player.lv < 40 of
							   false->check_today_count(PlayerStatus,TaskList,Award,TaskBag);
							   true->
									NewTaskBag = [{TaskId,Td#task.name,Award}|TaskBag],
									check_today_count(PlayerStatus,TaskList,Award,NewTaskBag)
							end;
					   true->
							case PlayerStatus#player.lv >= Td#task.level andalso PlayerStatus#player.lv < Td#task.level+10 of
								false->check_today_count(PlayerStatus,TaskList,Award,TaskBag);
								true->
									NewTaskBag = [{TaskId,Td#task.name,Award}|TaskBag],
									check_today_count(PlayerStatus,TaskList,Award,NewTaskBag)
							end
					end;
				false->
					case PlayerStatus#player.lv >= Td#task.level andalso PlayerStatus#player.lv < Td#task.level+10 of
						false->check_today_count(PlayerStatus,TaskList,Award,TaskBag);
						true->
							NewTaskBag = [{TaskId,Td#task.name,Award}|TaskBag],
							check_today_count(PlayerStatus,TaskList,Award,NewTaskBag)
					end
			end
	end.

check_task_recoud(PlayerStatus,[],_TaskList)->
	case is_record(PlayerStatus,player) of
		true->
			case lib_target_gift:count_game_day(PlayerStatus#player.reg_time)of
				1->{0,recoup_coefficient(0)};
				2->{1,recoup_coefficient(1)};
				3->{2,recoup_coefficient(2)};
				_Day->{3,recoup_coefficient(3)}
			end;
		false->{0,recoup_coefficient(0)}
	end;
check_task_recoud(PlayerStatus,[Day|DateList],TaskList)->
	{OldDay1,OldDay2} = get_timetick(Day),
	case check_recoud_coefficient_by_task(OldDay1,OldDay2,PlayerStatus,TaskList) of
		false->
			{Day-1,recoup_coefficient(Day-1)};
		true->check_task_recoud(PlayerStatus,DateList,TaskList)
	end.

check_recoud_coefficient_by_task(_OldDay1,_OldDay2,_PlayerStatus,[])->
	true;
check_recoud_coefficient_by_task(OldDay1,OldDay2,PlayerStatus,[TaskId|TaskList])->
	TaskCount = get_task_count(TaskId, PlayerStatus,OldDay1,OldDay2),
	case TaskCount > 0 of
		false->check_recoud_coefficient_by_task(OldDay1,OldDay2,PlayerStatus,TaskList);
		true->false
	end.

%%补偿系数
recoup_coefficient(Day)->
	case Day of
		0->0;
		1->0.6;
		2->1.2;
		3->1.8;
		_->1.8
	end.

%%获取指定天数的零点时间戳
get_timetick(Day)->
	{M, S, MS} = now(),
    {_, Time} = calendar:now_to_local_time({M, S, MS}),
    TodaySec = M * 1000000 + S - calendar:time_to_seconds(Time),
	{TodaySec - 86400*Day,TodaySec-86400*(Day-1)}.

%%获取指定天数的任务统计
get_task_count(TaskId, PS,OldDay1,OldDay2) ->
    length([0 || RTL <- get_finish(PS), TaskId=:=RTL#role_task_log.task_id, RTL#role_task_log.finish_time >= OldDay1, RTL#role_task_log.finish_time < OldDay2]).

%%%%%%%%%%%%%%%%战场任务处理%%%%%%%%%%%%%%%
arena_task(Pid)->
	case is_pid(Pid) of
		true->
			case catch gen:call(Pid, '$gen_call', 'PLAYER', 2000) of
             	{'EXIT',_Reason} ->skip;
             	{ok, PlayerStatus} ->
					event(arena_kill,null,PlayerStatus),
					ok
			end;
		false->skip
	end.

%%击杀异族任务
kill_enemy_task(AerPid, AerRealm, DerRealm)->
	case AerRealm =/= DerRealm of
		true ->
			case catch gen:call(AerPid, '$gen_call', 'PLAYER', 2000) of
           		{'EXIT', _Reason} -> 
					skip;
             	{ok, Player} ->
					event(kill_enemy, null, Player)
			end;
		false ->
			skip
	end.

%%检查任务是否可提交或者已经完成 
check_task_is_finish(PlayerStatus,TaskId)->
	if TaskId=:= 20361->
		   case db_agent:check_task_by_id(PlayerStatus#player.id,[TaskId]) of
			   []->
				   case db_agent:check_task_can_finish(PlayerStatus#player.id,[TaskId])of
					   []->
						   false;
					   [Info]->
						   [State|_]=Info,
						   case State=:=1 of
							   true->
								   
								   can_finish;
							   false->
								   false
						   end
				   end;
			   _->
				   had_finish
		   end;
	   true->
			case in_finish(TaskId, PlayerStatus) of
				true->had_finish;
				false->
					case is_finish(TaskId, PlayerStatus) of
						false->false;
						true->can_finish
					end
			end
	end.

%%检查副本令任务状态()
%% 55=> 等级符合，不能使用
%% 		56=>没有氏族，不能使用
%% 		57=>您今天已经完成该令牌对应的所有任务
check_dungeon_card_task_state(PlayerStatus,GoodsId)->
	TaskId =goodsid_to_taskid(GoodsId), 
	Task = get_data(TaskId),
	case get_one_trigger(TaskId, PlayerStatus) of
		false->
			case check_lvl(Task,PlayerStatus#player.lv) of
				true->
					case check_guild(Task,PlayerStatus) of
						true->
							Times = check_daily_times(Task#task.condition),
							HadTimes =get_today_count(TaskId, PlayerStatus),
							case HadTimes>=Times of
								true->{false,57};
								false->{true,1}
							end;
						false->{false,56}
					end;
				false->{false,55}
			end;
		_true->
			{true,1}
	end.

%%完成一个副本令任务
finish_dungeon_card_task(PlayerStatus,GoodsId) ->
	NowTime = util:unixtime(),
	TaskId =goodsid_to_taskid(GoodsId), 
	TD = get_data(TaskId),
	%%处理日志
	case get_one_trigger(TaskId, PlayerStatus) of
		false->
			ets:insert(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=PlayerStatus#player.id,
														  task_id=TaskId, trigger_time = NowTime, finish_time = NowTime}),
			mod_task_cache:add_log(PlayerStatus#player.lv, PlayerStatus#player.other#player_other.pid, PlayerStatus#player.id, TaskId, TD#task.type,NowTime, NowTime),
			ok;
		Task->
			ets:delete(?ETS_ROLE_TASK, {PlayerStatus#player.id, TaskId}),
			ets:insert(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=PlayerStatus#player.id,
														  task_id=TaskId, trigger_time = Task#role_task.trigger_time, finish_time = NowTime}),
			%% 数据库回写
			mod_task_cache:del_trigger(PlayerStatus#player.id, TaskId),
			mod_task_cache:add_log(PlayerStatus#player.lv, PlayerStatus#player.other#player_other.pid, PlayerStatus#player.id, TaskId, TD#task.type,Task#role_task.trigger_time, NowTime),
			ok
	end,
	%%奖励
	%%增加氏族经验
	add_guild_exp(PlayerStatus,TD),
	%%增加灵力
	PlayerStatus_1 = add_spirit(PlayerStatus,TD),
	%%增加绑定铜
	PlayerStatus_2 = add_bind_coin(PlayerStatus_1,TD),	
	%%增加修为
	PlayerStatus_3 = add_culture(PlayerStatus_2,TD),
	%%增加经验和铜钱
	PlayerStatus_4=add_exp_and_coin(PlayerStatus_3,TD),
	NewPlayerStatus = PlayerStatus_4,
	%%刷新任务
	refresh_active(NewPlayerStatus),
	{ok, BinData1} = pt_30:write(30006, [1,0]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData1),
	case NewPlayerStatus =/= PlayerStatus of
		true -> 
			case TD#task.end_cost > TD#task.coin of
				true->
					SaveType=sub;
				false->
					SaveType = add
			end,
			save_player_table(NewPlayerStatus,PlayerStatus,SaveType);
		false -> ok
	end,
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
										   ]}),
	lib_player:send_player_attribute(NewPlayerStatus, 1),
	ok.

goodsid_to_taskid(GoodsId) ->
	case GoodsId of
		28621->61002;
		28622->60100;
		28623->61010;
		28624->61011;
		28625->61015;
		28626->61017;
		28627->61016;
		28628->61018;
		28629->61036;
		28630->61037;
		28631->61050;
		28632->61051;
		_->0
	end.

%%查询副本/氏族任务是否可使用副本令
%%{1可使用，2任务不存在，3等级不足，4没有氏族，5任务已完成,6该任务不能使用副本令}
check_dungeon_card_task(PlayerStatus,TaskId)->
	case get_data(TaskId) of
		[]->[2,0,<<>>,0,0,0,0,0,0,0,0,0];
		TaskData->
			case is_dug_task(TaskData) ==true orelse is_guild_task(TaskData)==true of
				false->[6,0,<<>>,0,0,0,0,0,0,0,0,0];
				true->
					case check_lvl(TaskData,PlayerStatus#player.lv) of
						false->[3,0,<<>>,0,0,0,0,0,0,0,0,0];
						true->
							case check_guild(TaskData,PlayerStatus) of
								false->[4,0,<<>>,0,0,0,0,0,0,0,0,0];
								true->
									Times = check_daily_times(TaskData#task.condition),
									HadTimes =get_today_count(TaskId, PlayerStatus),
									if HadTimes >= Times ->[5,0,<<>>,0,0,0,0,0,0,0,0,0];
									   true->
										   CanTimes = Times-HadTimes,
										   [1,
											TaskData#task.id,
											TaskData#task.name,
											CanTimes,
											round(TaskData#task.exp*CanTimes),
											round(TaskData#task.spt*CanTimes),
											round(TaskData#task.coin*CanTimes),
											round(TaskData#task.binding_coin*CanTimes),
											round(dungeon_card(TaskData#task.level)*CanTimes),
										    round(TaskData#task.contrib*CanTimes),
											round(TaskData#task.guild_exp*CanTimes),
											TaskData#task.type
											]
									end
							end
					end
			end
	end.

%%使用副本令
finish_task_by_dungeon_card(PlayerStatus,TaskBag)->
	{TaskInfo,Exp,Spt,Coin,BCoin,GuildContrib,GuildExp,Cards} = dungeon_card_task_award(TaskBag,PlayerStatus,{[],0,0,0,0,0,0,0}),
	case TaskInfo of
		[]->{1,PlayerStatus};
		_->
			case gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'delete_more', 28620,Cards}) of
				1->
					NowTime = util:unixtime(),
					dungeon_task_log_loop(TaskInfo,PlayerStatus,NowTime),
					%%奖励
					%%增加氏族经验
					mod_guild:increase_guild_exp(PlayerStatus#player.id, PlayerStatus#player.guild_id, 
															 GuildExp, GuildContrib,0,0),
					%%增加定铜
					PlayerStatus_1 = lib_player:add_bcoin(PlayerStatus,BCoin),	
					PlayerStatus_2 = lib_player:add_coin(PlayerStatus_1,Coin),
					%%增加经验和铜钱
					PlayerStatus_3=lib_player:add_exp(PlayerStatus_2,Exp,Spt,0),
					NewPlayerStatus = PlayerStatus_3,
					%%刷新任务
					refresh_active(NewPlayerStatus),
					{ok, BinData1} = pt_30:write(30006, [1,0]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData1),
					save_player_table(NewPlayerStatus,PlayerStatus,add),
					{1,NewPlayerStatus};
				_->{2,PlayerStatus}
			end
	end.

dungeon_task_log_loop([],_PlayerStatus,_NowTime)->ok;
dungeon_task_log_loop([{TaskId,TaskType,Times}|TaskInfo],PlayerStatus,NowTime)->
	dungeon_task_log(Times,PlayerStatus,TaskId,TaskType,NowTime),
	dungeon_task_log_loop(TaskInfo,PlayerStatus,NowTime).

dungeon_task_log(0,_PlayerStatus,_TaskId,_TaskType,_NowTime)->ok;
dungeon_task_log(Times,PlayerStatus,TaskId,TaskType,NowTime1)->
	NowTime = NowTime1-Times,
	case get_one_trigger(TaskId, PlayerStatus) of
		false->
			ets:insert(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=PlayerStatus#player.id,
														  task_id=TaskId, trigger_time = NowTime, finish_time = NowTime}),
			mod_task_cache:add_log(PlayerStatus#player.lv, PlayerStatus#player.other#player_other.pid, PlayerStatus#player.id, TaskId, TaskType,NowTime, NowTime),
			ok;
		Task->
			ets:delete(?ETS_ROLE_TASK, {PlayerStatus#player.id, TaskId}),
			ets:insert(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=PlayerStatus#player.id,
														  task_id=TaskId, trigger_time = Task#role_task.trigger_time, finish_time = NowTime}),
			%% 数据库回写
			mod_task_cache:del_trigger(PlayerStatus#player.id, TaskId),
			mod_task_cache:add_log(PlayerStatus#player.lv, PlayerStatus#player.other#player_other.pid, PlayerStatus#player.id, TaskId, TaskType,Task#role_task.trigger_time, NowTime),
			ok
	end,
	dungeon_task_log(Times-1,PlayerStatus,TaskId,TaskType,NowTime).

dungeon_card_task_award([],_PlayerStatus,Award)->Award;
dungeon_card_task_award([TaskId|TaskBag],PlayerStatus,{Info,Exp,Spt,Coin,BCoin,GuildContrib,GuildExp,Cards})->
	case check_dungeon_card_task(PlayerStatus,TaskId) of
		[1,_,_,Times,Exp1,Spt1,Coin1,BCoin1,Cards1,GuildContrib1,GuildExp1,Type]->
			dungeon_card_task_award(TaskBag,PlayerStatus,{[{TaskId,Type,Times}|Info],Exp+Exp1,Spt+Spt1,Coin+Coin1,BCoin+BCoin1,GuildContrib+GuildContrib1,GuildExp+GuildExp1,Cards+Cards1});
		_->
			dungeon_card_task_award(TaskBag,PlayerStatus,{Info,Exp,Spt,Coin,BCoin,GuildContrib,GuildExp,Cards})
	end.
 
dungeon_card(Lv)-> 
	if Lv =< 34 -> 2;
	   Lv =< 44 -> 3;
	   Lv =< 54 -> 4;
	   Lv =< 64 -> 6;
	   Lv =< 69 -> 8;
	   true-> 10
	end.

%%点名任务(3没有点名卡，4玩家不存在，5玩家不在线，6玩家已经被点名,7系统繁忙，稍后重试,8玩家不足30级)
appoint(Status,Name)->
	case lib_activities:is_all_may_day_time(util:unixtime()) of
		true->
			case  goods_util:get_goods_num(Status#player.id, 28055,4) >= 1 of
				true->
					if Status#player.lv < 30 -> [8];
					   true->
						   case lib_player:get_role_id_by_name(Name) of
							   null->[4];
							   []->[4];
							   InviteId->
								   if InviteId == Status#player.id ->[10];
									  true->
										  case lib_player:get_online_info(InviteId) of
											  []->[5];
											  Invite->
												  if Invite#player.lv < 30 -> [8];
													 true->
														 catch case gen_server:call(Invite#player.other#player_other.pid_task,{'is_can_trigger',[Invite,?APPOINT_TASK_ID]}) of
																   false->[6];
																   true->
																	   {ok,BinData} = pt_30:write(30029, [Status#player.nickname]),
																	   lib_send:send_to_sid(Invite#player.other#player_other.pid_send, BinData),
																	   [1];
																   _->[7]
															   end
												  end
										  end
								   end
						   end
					end;
				false->
					%%没有点名卡
					[3]
			end;
		false->[9]
	end.

%%应答点名
appoint_result(Status,Res,Name)->
	NowTime = util:unixtime(),
	case lib_activities:is_all_may_day_time(NowTime) of
		true->
			if Status#player.lv < 30 -> [8];
			   true->
				   case lib_player:get_role_id_by_name(Name) of
					   null->[4];
					   []->[4];
					   InviteId->
						   if Status#player.id == InviteId ->[10];	
							  true->
								  case lib_player:get_online_info(InviteId) of
									  []->[5];
									  Invite->
										  %%玩家拒绝
										  if Res == 2 ->
												 {ok,Bindata} = pt_30:write(30030, [Res]),
												 lib_send:send_to_sid(Invite#player.other#player_other.pid_send, Bindata),
												 [2];
											 true->
												 if Invite#player.lv < 30 -> [8];
													true->
														TaskId =?APPOINT_TASK_ID,
														case is_can_trigger(Status,TaskId) of
															true->
																catch case gen_server:call(Invite#player.other#player_other.pid_goods, {'delete_more', 28055,1}) of
																		  1->
																			  
																			  TD = get_data(TaskId),
																			  Content = get_task_content(Status#player.id,TD),
																			  ets:insert(?ETS_ROLE_TASK, #role_task{id={Status#player.id, TaskId},
																													player_id=Status#player.id ,task_id = TaskId, 
																													trigger_time = NowTime, state=0,
																													end_state=TD#task.state,mark = Content,type=0,other=[Name]
																												   }),
																			  %%更新数据库
																			  mod_task_cache:add_trigger(Status#player.id, TaskId, NowTime, 0, 
																										 TD#task.state, Content,0,[Name]),
																			  %%刷新任务列表
																			  refresh_active(Status),
																			  lib_task:preact_finish(TaskId, Status),
																			  %%通知接受点名
																			  {ok,BinData}= pt_30:write(30030, [1]),
																			  lib_send:send_to_sid(Invite#player.other#player_other.pid_send, BinData),
																			  [1];
																		  _->
																			  [3]
																	  end;
															false->[6]
														end
												 end
										  end
								  end
						   end
				   end
			end;
		false->[9]
	end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%任务测试接口%======================================
%%立即完成所有任务测试接口
finish_all_task(PlayerStatus)->
	TriggerBag = lib_task:get_trigger(PlayerStatus),
	case TriggerBag of
		[] ->
			ActiveIds = lib_task:get_active(PlayerStatus),
			[lib_task:trigger(TaskId, 0, PlayerStatus,0)||TaskId<-ActiveIds],
			save_player_info_task(PlayerStatus),
			NewPS = PlayerStatus;
		_->
			PS = finish_task(TriggerBag,PlayerStatus),
			refresh_active(PS),
			ActiveIds = lib_task:get_active(PS),
			[lib_task:trigger(TaskId,0, PS,0)||TaskId<-ActiveIds],
			save_player_info_task(PS),
			NewPS = PS
	end,
	NewPS.

%%任务测试接口
finish_task_under_lv(PlayerStatus,LV)->
	TriggerBag = lib_task:get_trigger(PlayerStatus),
	case TriggerBag of
		[] -> 
			ok;
		_->
			
			PS = finish_all_task(PlayerStatus),
			if PS#player.lv =<LV->
				finish_task_under_lv(PS,LV);
			   true->
				   ok
			end
	end.



save_player_info_task(Status)->
	ValueList = [{spirit,Status#player.spirit},
				 {bcoin,Status#player.bcoin},
				 {coin,Status#player.coin},
				 {culture,Status#player.culture},
				 {lv,Status#player.lv},
				 {exp,Status#player.exp},
				{realm,Status#player.realm}],
	WhereList = [{id, Status#player.id}],
    db_agent:mm_update_player_info(ValueList, WhereList),
	gen_server:cast(Status#player.other#player_other.pid, {'SET_PLAYER', [{spirit,Status#player.spirit},
				 {bcoin,Status#player.bcoin},
				 {coin,Status#player.coin},
				 {culture,Status#player.culture},
				 {lv,Status#player.lv},
				 {exp,Status#player.exp},
				{realm,Status#player.realm}]}),
	lib_player:send_player_attribute(Status, 1).

finish_task([],PS) ->
	PS;
finish_task([Task|T],RS)->
	TaskId= Task#role_task.task_id,
	TD = get_data(TaskId),
	case TD#task.contrib > 0 of
		true -> mod_guild:add_donation(RS#player.id, TD#task.contrib);
        false -> false
    end,
	%% 回收物品
	case get_end_item(TD, RS) of
		[] -> false;
		EndItems ->
			Fun = fun(GoodsTypeId, GoodsNum) ->
						  GoodsTypeInfo = goods_util:get_goods_type(GoodsTypeId),
						  case GoodsTypeInfo#ets_base_goods.type of
							  35->
								  gen_server:call(RS#player.other#player_other.pid_goods, {'delete_task_goods', GoodsTypeId,GoodsNum});
							  _->
								  gen_server:call(RS#player.other#player_other.pid_goods, {'delete_more', GoodsTypeId,GoodsNum})
						end
					end,
         [Fun(Id, Num) || {Id, Num} <- EndItems]
    end,
    %% 奖励固定物品
    case get_award_item(TD, RS) of
		[] -> false;
		Items ->
			F = fun(GoodsTypeId, GoodsNum) ->
						gen_server:call(RS#player.other#player_other.pid_goods, {'give_goods', RS, GoodsTypeId, GoodsNum,2})
                end,
            [F(Id, Num) || {Id, Num} <- Items]
    end,
%% 	Content = TD#task.content,
	
	RS0 = check_content_info(Task#role_task.mark,RS),
	case TD#task.contrib > 0 orelse TD#task.guild_exp>0 of
		true -> mod_guild:increase_guild_exp(RS#player.id, RS#player.guild_id, TD#task.guild_exp, TD#task.contrib,0,0);
        false -> false
	end,
	RS1 = case TD#task.spt > 0 of
			  true -> RS0#player{spirit = RS0#player.spirit + TD#task.spt};
			  false -> RS0
          end,
	RS2 = case  TD#task.binding_coin >0 of
			  	true -> lib_player:add_bcoin(RS1,TD#task.binding_coin);
				false ->RS1
		end,	  
	RS3 = case TD#task.attainment >0 of
			  true -> lib_player:add_culture(RS2,TD#task.attainment);
			false ->RS2
		end,
	RS4 = lib_player:add_coin(RS3, TD#task.coin),
	RS5 = lib_player:add_exp(RS4, TD#task.exp, 0,0), 
	ets:delete(?ETS_ROLE_TASK, {RS5#player.id, TaskId}),
    mod_task_cache:del_trigger(RS5#player.id, TaskId),
 	Time = util:unixtime(),
	ets:insert(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=RS5#player.id, task_id=TaskId, trigger_time = Task#role_task.trigger_time, finish_time = Time}),
	mod_task_cache:add_log(RS5#player.lv, RS5#player.other#player_other.pid, RS5#player.id, TaskId, TD#task.type,Task#role_task.trigger_time, Time),
%% 	lib_scene:refresh_npc_ico(RS5),
    {ok, BinData} = pt_30:write(30006, [1,0]),
    lib_send:send_to_sid(RS5#player.other#player_other.pid_send, BinData),
	finish_task(T,RS5).

check_content_info([], PS)-> PS;
check_content_info([Content | T],PS)->
	%%to_same_mark([_, Finish, kill, MonId, Num, NowNum | _]
	[_, _, Item | _] = Content,
	case Item of 
		kill ->
		   	[_,_,_,MonId,Num,NowNum|_]=Content,
		   	NumNeed = Num-NowNum,
		   	[Mexp|_] = db_agent:get_mon_exp_by_id(MonId),
		   	Exp = Mexp * NumNeed,
		   	NewPs = lib_player:add_exp(PS, Exp, 0,1);
	  	item ->
		   	[_,_,_,GoodsId,Num,NowNum|_]=Content,
		   	NumNeed = Num-NowNum,
		   	{MonId, _ItemName, _SceneId, _SceneName, _X, _Y} = 
				case goods_util:get_task_mon(GoodsId) of
        			0 -> {0, get_item_name(GoodsId), 0, <<"未知场景">>, 0, 0};  %% 物品无绑定npc
       				XNpcId ->
           				{XSId,XSName, X0, Y0} = get_mon_def_scene_info(XNpcId,PS#player.realm,PS#player.scene),
            			{XNpcId, get_item_name(GoodsId), XSId, XSName, X0, Y0}
   			 	end,
		   	[Mexp|_] = db_agent:get_mon_exp_by_id(MonId),
		   	Exp = Mexp * NumNeed,
		   	NewPs = lib_player:add_exp(PS, Exp, 0,1);
	  	select_nation ->
		   	{_, PS1, _Data} = lib_task:select_nation(PS,2,0),
		   	SceneId = lib_task:get_sceneid_by_realm(PS1#player.realm),
			pp_scene:handle(12005, PS1, SceneId),
	   		NewPs = PS1;
	 	convoy ->
		   	{ok,NewPs} = convoy_npc_finish(PS);
	   	_ ->
		   	NewPs = PS
	end,
	check_content_info(T, NewPs).

%%清除旧数据脚本
del_task_bag()->
	TaskBag = db_agent:get_task_bag(),
	[del_new_task(PlayerId,TaskId)||[TaskId,PlayerId]<-TaskBag],
%% 	[del_task(PlayerId,TaskId)||[TaskId,PlayerId]<-TaskBag],
%% 	del_god_weapon(),
%% 	del_goods_16009(),
	del_finish.

%%删除30级以下主支线任务
del_task(PlayerId,TaskId)->
	case get_data(TaskId) of
		[]->skip;
		TD->
			case is_main_task(TD) orelse TD#task.type==1 of
				false->skip;
				true->
					if TD#task.level =< 30 andalso TD#task.level>10 andalso TaskId =/=20100 ->
							case is_convoy_task(TD) of
								false->skip;
								true->
									ValueList = [{task_convoy_npc,0}],
									WhereList = [{id, PlayerId}],
    								db_agent:mm_update_player_info(ValueList, WhereList)
							end,
							db_agent:del_task_bag(PlayerId,TaskId),
							ok;
					   true->skip
					end
			end
	end,
	ok.

%%清除新手任务
del_new_task(PlayerId,TaskId)->
	case lists:member(TaskId, data_task:task_get_novice_id_list() ) of
		false->skip;
		true->
			if TaskId /= 20100->
				db_agent:del_task_bag(PlayerId,TaskId);
			   true->skip
			end
	end.

%%清除单人副本神器
del_god_weapon()->
	Weapon = db_agent:get_god_weapon(),
	[del_weapon(PlayerId,GoodsId)||[GoodsId,PlayerId]<-Weapon],
	ok.

%%清除时效的飞行坐骑
del_goods_16009()->
	Goods = db_agent:get_mount_16009(),
	[db_agent:del_god_weapon(GoodsId)||[GoodsId|_]<-Goods].

del_weapon(PlayerId,GoodsId)->
	db_agent:del_god_weapon(GoodsId),
	Data = db_agent:get_player_mult_properties([realm,scene],[PlayerId]),
	case Data of
		[{_,[Realm,Scene]}]->
			SceneId = Scene rem 1000,
			if SceneId =:= 910->
				   [NextSenceId, X, Y] =
					case Realm of
						1 ->%%女娲
							[200,158,208];
						2 ->%%神农
							[280,157,208];
						3 ->%%伏羲
							[250,159,203];
						_ ->
							[250,159,203]
					end,
				   ValueList = [{scene,NextSenceId},{x,X},{y,Y}],
				   WhereList = [{id, PlayerId}],
				   db_agent:mm_update_player_info(ValueList, WhereList),
				   ok;
			   true->skip
			end;
		_->skip
	end,
	ok.

%%任务重置：适合主支线任务，副本任务，氏族任务，日常打怪任务
cmd_reset_task(Status,TaskId)->
	mod_task_cache:del_log(Status#player.id, TaskId),
	ets:match_delete(?ETS_ROLE_TASK_LOG, #role_task_log{player_id=Status#player.id,task_id = TaskId,_='_'}),
	%%刷新任务
	refresh_active(Status),
	{ok, BinData1} = pt_30:write(30006, [1,0]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData1),
	ok.