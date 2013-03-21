%% Author: hxming
%% Created: 2011-2-18
%% Description: TODO: Add description to lib_consign
-module(lib_consign).

-compile(export_all).

-include("common.hrl").
-include("record.hrl").




%%
%% Local Functions
%%
%%加载委托任务数据
init_consign_task()->
	ConsignTask = db_agent:init_consign_task(),
	[
	 ets:insert(?ETS_CONSIGN_TASK, 
				#ets_consign_task{id=Id,pid=PlayerId,tid=TaskId,name=Name,lv=Lv,t1=Time,
								  state=State,gid_1=GoodsId1,n_1=Num1,gid_2=GoodsId2,n_2=Num2,
								  mt=MoneyType,n_3=Num3,t2=Timestamp,aid=AcceptId,t3=AcceptTime,autoid=AutoId})
                || 
	   [Id, PlayerId,TaskId,Name,Lv,Time,
		State,GoodsId1,Num1,GoodsId2,Num2,
		MoneyType,Num3,Timestamp,
		AcceptId,AcceptTime,AutoId] <-ConsignTask
	],
	ok.

%%获取所有的委托任务
get_all_consign_task()->
	ets:tab2list(?ETS_CONSIGN_TASK).

%%根据id查找委托任务
get_consign_task_by_id(Id)->
	ets:match_object(?ETS_CONSIGN_TASK, #ets_consign_task{id=Id, _='_'}).

%%根据接受玩家查找委托任务
get_consign_task_by_accept(PlayerId,TaskId)->
	ets:match_object(?ETS_CONSIGN_TASK, #ets_consign_task{aid=PlayerId,tid=TaskId, _='_'}).


%%发布委托任务
publish_consign_task(TaskBag)->
	{_,Id} = db_agent:new_consign_task(TaskBag),
	spawn(fun()->catch(db_agent:employ_log(TaskBag))end),
	[PlayerId,TaskId,Name,Lv,Time,GoodsId1,Num1,GoodsId2,Num2,MoneyType,Num3,Timestamp,AutoId] = TaskBag,
	ets:insert(?ETS_CONSIGN_TASK, 
				#ets_consign_task{id=Id,pid=PlayerId,tid=TaskId,name=Name,lv=Lv,t1=Time,
								  state=0,gid_1=GoodsId1,n_1=Num1,gid_2=GoodsId2,n_2=Num2,
								  mt=MoneyType,n_3=Num3,t2=Timestamp,autoid=AutoId}).

%%接受委托任务
accept_consign_task(TaskBag)->
	[PlayerId,Timestamp,ConsignTask] = TaskBag,
%% 	[ConsignTask] = get_consign_task_by_id(Id),
	NewConsignTask = ConsignTask#ets_consign_task{state=1,aid=PlayerId,t3=Timestamp},
	ets:insert(?ETS_CONSIGN_TASK, NewConsignTask),
	db_agent:accept_consign_task(PlayerId,Timestamp,ConsignTask#ets_consign_task.id).

%%修改委托任务状态
update_consign_state(PlayerId,TaskId)->
	[ConsignTask]=get_consign_task_by_accept(PlayerId,TaskId),
	NewConsignTask = ConsignTask#ets_consign_task{state=2},
	ets:insert(?ETS_CONSIGN_TASK, NewConsignTask),
	db_agent:update_consign_state(NewConsignTask#ets_consign_task.id).

%%完成委托任务
finish_consign_task([Id])->
	 ets:match_delete(?ETS_CONSIGN_TASK, #ets_consign_task{id=Id, _='_'}),
	 db_agent:del_task_consign(Id).

%%重置委托任务
reset_consign_task(Id)->
	[ConsignTask]=get_consign_task_by_id(Id),
	NewConsignTask = ConsignTask#ets_consign_task{state=0,aid=0,t3=0},
	ets:insert(?ETS_CONSIGN_TASK, NewConsignTask),
	db_agent:reset_consign_task(Id).


%%加载玩家委托数据
init_consign_player_info(PlayerId)->
	case db_agent:init_consign_player_info(PlayerId) of
		[]->
			%插入新玩家数据
			NowTime = util:unixtime(),
			{_,Id}=db_agent:new_consign_player_info(PlayerId,NowTime),
			Data = [Id,PlayerId,0,NowTime,0,NowTime,NowTime],
			EtsData = match_ets_playerinfo(Data),
 			ets:insert(?ETS_CONSIGN_PLAYER,EtsData);
		Result ->
				Data = match_ets_playerinfo(Result),
				ets:insert(?ETS_CONSIGN_PLAYER,Data)
	end.

match_ets_playerinfo(Data)->
	[Id,PlayerId,Publish,Ptime,Accept,Atime,Timestamp]= Data,
	EtsData = #ets_consign_player{
							    id=Id,
      							pid = PlayerId,          %% 玩家ID	
	  							publish = Publish,
								pt = Ptime,
								accept = Accept,
								at = Atime,
								timestamp = Timestamp
							},
	EtsData.

%%检查第二天
check_new_day(Timestamp)->
	if Timestamp =/= 0 ->
		NDay = (util:unixtime()+8*3600) div 86400,
		TDay = (Timestamp+8*3600) div 86400,
		NDay=:=TDay;
	   true->
		   true
	end.

select_consign_player(PlayerId)->
	ets:match_object(?ETS_CONSIGN_PLAYER, #ets_consign_player{pid=PlayerId,_='_'}).

%%获取今天委托次数
get_consign_times_list(PlayerId)->
	case select_consign_player(PlayerId) of
		[]->{0,3,0,3};
		[ConsignInfo]->
			NewConsignInfo = case check_new_day(ConsignInfo#ets_consign_player.pt) of
								 true->
									 ConsignInfo;
								 false->
									 NowTime = util:unixtime(),
									 db_agent:reset_consign_times(PlayerId,NowTime),
									 ConsignInfo1 = ConsignInfo#ets_consign_player{publish=0,pt=NowTime,accept=0,at=NowTime},
									 ets:insert(?ETS_CONSIGN_PLAYER,ConsignInfo1),
									 ConsignInfo1
							 end,
			{NewConsignInfo#ets_consign_player.publish,3,NewConsignInfo#ets_consign_player.accept,3}
	end.
		
check_publish_times(PlayerId)->
	case select_consign_player(PlayerId) of 
		[]->
%% 			init_consign_player_info(PlayerId),
			{error,12};
		[ConsignInfo]->
			NewConsignInfo = case check_new_day(ConsignInfo#ets_consign_player.pt) of
								 true->
									 ConsignInfo;
								 false->
									 NowTime = util:unixtime(),
									 db_agent:update_consign_publish(PlayerId,0,NowTime),
									 ConsignInfo1 = ConsignInfo#ets_consign_player{publish=0,pt=NowTime},
									 ets:insert(?ETS_CONSIGN_PLAYER,ConsignInfo1),
									 ConsignInfo1
							 end,
			case NewConsignInfo#ets_consign_player.publish >=3 of
				true ->{error,11};
				false->{ok,1}
			end
				
	end.

update_publish_times(PlayerId)->
	[ConsignInfo] = select_consign_player(PlayerId),
	Times = case  ConsignInfo#ets_consign_player.publish +1 > 3 of
				false ->ConsignInfo#ets_consign_player.publish +1;
				true-> 3
			end,
	NewConsignInfo = ConsignInfo#ets_consign_player{publish=Times},
	ets:insert(?ETS_CONSIGN_PLAYER,NewConsignInfo),
	db_agent:update_consign_publish(PlayerId,Times,NewConsignInfo#ets_consign_player.pt).

reset_publish_times(PlayerId)->
	[ConsignInfo] = select_consign_player(PlayerId),
	Times = case  ConsignInfo#ets_consign_player.publish -1 <0 of
			  true->0;
			  false->ConsignInfo#ets_consign_player.publish -1
		  end,
	NewConsignInfo = ConsignInfo#ets_consign_player{publish=Times},
	ets:insert(?ETS_CONSIGN_PLAYER,NewConsignInfo),
	db_agent:update_consign_publish(PlayerId,Times,NewConsignInfo#ets_consign_player.pt).

check_accept_times(PlayerId)->
	case select_consign_player(PlayerId) of 
		[]->
%% 			init_consign_player_info(PlayerId),
			{error,10};
		[ConsignInfo]->
			NewConsignInfo = case check_new_day(ConsignInfo#ets_consign_player.at) of
								 true->
									 ConsignInfo;
								 false->
									 NowTime = util:unixtime(),
									 db_agent:update_consign_accept(PlayerId,0,NowTime),
									 ConsignInfo1 = ConsignInfo#ets_consign_player{accept=0,at=NowTime},
									 ets:insert(?ETS_CONSIGN_PLAYER,ConsignInfo1),
									 ConsignInfo1
							 end,
			case NewConsignInfo#ets_consign_player.accept >=3 of
				false ->{ok,1};
				true->{error,9}
			end
	end.
update_accept_times(PlayerId)->
	[ConsignInfo] = select_consign_player(PlayerId),
	Times = case  ConsignInfo#ets_consign_player.accept +1 > 3 of
				false->ConsignInfo#ets_consign_player.accept +1;
				true->3
			end,
	NewConsignInfo = ConsignInfo#ets_consign_player{accept=Times},
	ets:insert(?ETS_CONSIGN_PLAYER,NewConsignInfo),
	db_agent:update_consign_accept(PlayerId,Times,NewConsignInfo#ets_consign_player.at).

update_consign_award(PlayerId,AwardBag)->
	db_agent:update_consign_award(PlayerId,AwardBag).

select_consign_award(PlayerId)->
	db_agent:select_consign_award(PlayerId).

reset_consign_award(PlayerId)->
	db_agent:reset_consign_award(PlayerId).

clear_consign_task()->
	ConsignTask = get_all_consign_task(),
%% 	io:format("clear_consign_task~p~n",[ConsignTask]),
	deal_with_task(ConsignTask),
	ok.

deal_with_task([])->
	ok;
deal_with_task([Task|ConsignTask])->
%% 	[Task]=T,
%% 	io:format("clear_consign_task_________~p~n",[Task]),
	case check_new_day(Task#ets_consign_task.t2 )of
		true->
%% 			io:format("deal_with_task_222~n"),
			skip;
		false->
%% 			io:format("deal_with_task_1~n"),
			case Task#ets_consign_task.aid > 0 of
				false ->
					skip;
				true->
					case lib_player:get_online_info(Task#ets_consign_task.aid) of
						[]->
							AutoId = db_agent:get_task_auto_id(Task#ets_consign_task.aid, Task#ets_consign_task.tid),
							db_agent:del_task_by_id(AutoId);
%% 							mod_task_cache:del_trigger(Task#ets_consign_task.aid, Task#ets_consign_task.tid);
						APlayerStatus->
							gen_server:cast(APlayerStatus#player.other#player_other.pid_task,
									{'accept_consign_task_online',APlayerStatus,Task#ets_consign_task.tid})
					end,
					PlayerName= lib_player:get_role_name_by_id(Task#ets_consign_task.aid),
					NameList = [tool:to_list(PlayerName)],
					Content =io_lib:format( "您接受的雇佣任务【~s】超时，任务失败!",[Task#ets_consign_task.name]),
					mod_mail:send_sys_mail(NameList, "雇佣信件", Content, 0, 0, 0, 0,0)
			end,
%% 			io:format("deal_with_task_2~n"),
%% 			case lib_player:get_online_info(Task#ets_consign_task.pid) of
%% 				[]->
%% 					db_agent:update_task_state(Task#ets_consign_task.autoid,0);
%% 				PlayerStatus->
%% 					gen_server:cast(PlayerStatus#player.other#player_other.pid_task,
%% 									{'reset_consign_task_online',PlayerStatus,Task#ets_consign_task.autoid})
%% 			end,
			db_agent:del_task_by_id(Task#ets_consign_task.autoid),
%% 			io:format("deal_with_task_3~n"),
			return_award(Task),
%% 			io:format("deal_with_task_4~n"),
			finish_consign_task([Task#ets_consign_task.id])
	end,
	deal_with_task(ConsignTask).

return_award(Task) ->
%% 	io:format("return_award~p~n",[Task#ets_consign_task.n_3]),
	PlayerName= lib_player:get_role_name_by_id(Task#ets_consign_task.pid),
	NameList = [tool:to_list(PlayerName)],
	Content = "您的雇佣任务已过期，任务将重置，退还雇佣奖励！",
	case Task#ets_consign_task.gid_1 > 0 andalso Task#ets_consign_task.n_1>0 of
		false->skip;
		true->
			mod_mail:send_sys_mail(NameList, "雇佣信件", Content, 0,Task#ets_consign_task.gid_1, Task#ets_consign_task.n_1, 0, 0)
	end,
	case Task#ets_consign_task.gid_2 > 0 andalso Task#ets_consign_task.n_2>0 of
		false->skip;
		true->
			mod_mail:send_sys_mail(NameList, "雇佣信件", Content, 0,Task#ets_consign_task.gid_2, Task#ets_consign_task.n_2, 0, 0)
	end,
	case Task#ets_consign_task.n_3 > 0 of
		false->skip;
		true->
			case Task#ets_consign_task.mt of
				1->
					mod_mail:send_sys_mail(NameList, "雇佣信件", Content, 0,0, 0,  Task#ets_consign_task.n_3,0);
				_->
					mod_mail:send_sys_mail(NameList, "雇佣信件", Content, 0,0, 0, 0, Task#ets_consign_task.n_3)
			end
	end,
	ok.

offline(PlayerId)->
	ets:match_delete(?ETS_CONSIGN_PLAYER, #ets_consign_player{pid=PlayerId,_='_'}).