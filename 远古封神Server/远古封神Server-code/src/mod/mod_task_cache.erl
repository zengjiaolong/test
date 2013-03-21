%%%------------------------------------
%%% @Module  : mod_task_cache
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 任务数据回写
%%%------------------------------------
-module(mod_task_cache).
-behaviour(gen_server).
-export(
    [
        start_link/0
        ,stop/0
        ,add_log/7
        ,del_log/2
        ,add_trigger/8
        ,upd_trigger/4
        ,del_trigger/2
        ,compress/2
        ,write_back/1,
		write_back_all/0
    ]
).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-include("common.hrl").

%% -record(state, {id = 1, interval = 0, limit = 0, cache = []}).
%% 定时器1间隔时间
-define(TIMER_1, 60*1000).


%% 添加完成日志
add_log(Lv, Pid, Rid, Tid,Type, TriggerTime, FinishTime) ->
	Data=[Rid, Tid, Type,TriggerTime, FinishTime],
	db_agent:syn_db_task_log_insert(Data),
%% 	case lists:member(Tid,?TaskRB) of
%% 		true->
%% 			Data=[Rid, Tid, Type,TriggerTime, FinishTime],
%% 		false->
%%     		gen_server:cast(?MODULE, {log, Rid, Tid, [Rid, Tid, Type,TriggerTime, FinishTime]})
%% 	end,
	%%任务成就 判断
	task_count(Lv, Pid, Rid, Tid).

%%  删除完成日志
del_log(Rid, Tid) ->
    gen_server:cast(?MODULE, {del_log, Rid, Tid, [Rid, Tid]}).

%% 添加触发
add_trigger(Rid, Tid, TriggerTime, TaskState, TaskEndState, TaskMark,TaskType,Other) ->
	Data = [Rid, Tid, TriggerTime, TaskState, TaskEndState, TaskMark,TaskType,Other],
	db_agent:syn_db_task_bag_insert(Data).
%% 	case lists:member(Tid,?TaskRB) of
%% 		true->
%% 			Data = [Rid, Tid, TriggerTime, TaskState, TaskEndState, TaskMark,TaskType],
%% 			db_agent:syn_db_task_bag_insert(Data);
%% 		false->
%%     		gen_server:cast(?MODULE, {add, Rid, Tid, [Rid, Tid, TriggerTime, TaskState, TaskEndState, TaskMark,TaskType]})
%% 	end.

%% 更新任务记录器
upd_trigger(Rid, Tid, TaskState, TaskMark) ->
	case lists:member(Tid,?TaskRB) of
		true->
			Data = [TaskState, TaskMark, Rid, Tid],
			db_agent:syn_db_task_bag_update(Data);
		false->
    		gen_server:cast(?MODULE, {upd, Rid, Tid, [TaskState, TaskMark, Rid, Tid]})
	end.

%% 删除触发的任务
del_trigger(Rid, Tid) ->
	Data = [Rid, Tid],
	db_agent:syn_db_task_bag_delete(Data).
%% 	case lists:member(Tid,?TaskRB) of
%% 		true->
%% 			Data = [Rid, Tid],
%% 			db_agent:syn_db_task_bag_delete(Data);
%% 		false->
%%     		gen_server:cast(?MODULE, {del, Rid, Tid, [Rid, Tid]})
%% 	end.

%% 立即回写单个玩家缓存
write_back(Rid) ->
    gen_server:cast(?MODULE, {'write_back',Rid}).

%%回写所有数据
write_back_all() ->
	gen_server:cast(?MODULE, {'write_back_all'}).

start_link()->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% 关闭服务器时回调
stop() ->
     gen_server:call(?MODULE, stop).

init([])->
	misc:write_monitor_pid(self(),?MODULE, {}),
	case  ?DB_MODULE =:= db_mysql of
		true->
    		erlang:send_after(10000, self(), syn_db);
		_->
			erlang:send_after(10000, self(), syn_db)
	end,
	erlang:send_after(lib_hook:get_end_time(),self(),{'HOOKING_END'}),
	{ok,[task_cache]}.

%% 同步任务数据
syn_db([]) ->
    ok;
%%添加任务日志
syn_db([{log, _, _, Data} | List]) ->
%%     db_agent:syn_db_task_log_insert(Data),
%% 	io:format("syn_db_task_log_insert ~p~n",[Data]),
	erlang:spawn(db_agent,syn_db_task_log_insert,[Data]),
    syn_db(List);

%%添加任务信息
syn_db([{add, _, _, Data} | List]) ->
%%     db_agent:syn_db_task_bag_insert(Data),
%% 	io:format("syn_db_task_bag_insert ~p~n",[Data]),
	erlang:spawn(db_agent,syn_db_task_bag_insert,[Data]),
	syn_db(List);

%%更新任务信息
syn_db([{upd, _, _, Data} | List]) ->
%%     db_agent:syn_db_task_bag_update(Data),
%% 	io:format("syn_db_task_bag_update ~p~n",[Data]),
	erlang:spawn(db_agent,syn_db_task_bag_update,[Data]),
    syn_db(List);

%%删除任务信息
syn_db([{del, _, _, Data} | List]) ->
%%     db_agent:syn_db_task_bag_delete(Data),
%% 	io:format("syn_db_task_bag_delete ~p~n",[Data]),
	erlang:spawn(db_agent,syn_db_task_bag_delete,[Data]),
    syn_db(List);

%%删除任务日志
syn_db([{del_log, Rid, Tid, _} | List]) ->
    Data = [Rid, Tid],
%%     db_agent:syn_db_task_log_delete(Data),
%% 	io:format("syn_db_task_log_delete ~p~n",[Data]),
	erlang:spawn(db_agent,syn_db_task_log_delete,[Data]),
    syn_db(List).

%% 数据压缩
compress([], Result) ->
    Result; %% 旧 -> 新

compress([{FirType, FirRid, FirTid, FirData} | T ], Result) ->
    R = lists:foldl(fun(X, R)-> compress(X, R) end, {FirType, FirRid, FirTid, FirData, []}, T),
    {_, _, _, _, Cache} = R,
    compress(lists:reverse(Cache), [{FirType, FirRid, FirTid, FirData} | Result]);
    
% compress({XType, XRid, XTid, XData}, {add, Rid, Tid, Data, Cache}) ->
%     case  XRid =:= Rid andalso XTid =:= Tid andalso XType =:= upd of
%         false -> {add, Rid, Tid, Data, [{XType, XRid, XTid, XData} | Cache]};
%         true -> {add, Rid, Tid, Data, Cache}
%     end;

compress({XType, XRid, XTid, XData}, {upd, Rid, Tid, Data, Cache}) ->
    case  XRid =:= Rid andalso XTid =:= Tid andalso XType =:= upd of
        false -> {upd, Rid, Tid, Data, [{XType, XRid, XTid, XData} | Cache]};
        true -> {upd, Rid, Tid, Data, Cache}
    end;

compress({XType, XRid, XTid, XData}, {del, Rid, Tid, Data, Cache}) ->
    case  XRid =:= Rid andalso XTid =:= Tid andalso (XType =:= upd orelse XType =:= add) of
        false -> {del, Rid, Tid, Data, [{XType, XRid, XTid, XData} | Cache]};
        true -> {del, Rid, Tid, Data, Cache}
    end;

%% 测试用
compress({XType, XRid, XTid, XData}, {del_log, Rid, Tid, Data, Cache}) ->
    case  XRid =:= Rid andalso XTid =:= Tid andalso XType =:= log of
        false -> {del_log, Rid, Tid, Data, [{XType, XRid, XTid, XData} | Cache]};
        true -> {del_log, Rid, Tid, Data, Cache}
    end;

compress(Elem, {Type, Rid, Tid, Data, Cache}) ->
    {Type, Rid, Tid, Data, [Elem | Cache]}.



%% 回写单个玩家数据到数据库
handle_cast({'write_back',PlayerId}, _State) ->
    NewCache = compress(get_task_cache(PlayerId), []), 
    syn_db(NewCache),
	delete_task_cache(PlayerId),
	{noreply,ok};

%%立即回写单人任务
handle_cast({'write_now',[Type,Data]},_State)->
	case Type of
		log->erlang:spawn(db_agent,syn_db_task_log_insert,[Data]);
		tri->erlang:spawn(db_agent,syn_db_task_bag_insert,[Data]);
		upd->erlang:spawn(db_agent,syn_db_task_bag_update,[Data]);
		del->erlang:spawn(db_agent,syn_db_task_bag_delete,[Data]);
		_->skip
	end,
	{noreply,ok}; 

%%回写所有玩家数据到数据库
handle_cast({'write_back_all'}, _State) ->
    [save_player_task(PlayerId,TaskCache)||{PlayerId,TaskCache}<-get_task_cache_all()],
	{reply,ok};

%% 将要更新的数据加入到缓存中
handle_cast(Elem, _State) ->
	{_,PlayId,_,_} = Elem,
	TaskCache = get_task_cache(PlayId),
	{noreply, insert_task_cache(PlayId,[Elem|TaskCache])}.
%% 	case ?DB_MODULE =:= db_mysql of
%% 		true->
%%    			{_,PlayId,_,_} = Elem,
%% 			TaskCache = get_task_cache(PlayId),
%% 			{noreply, insert_task_cache(PlayId,[Elem|TaskCache])};
%% 		_ ->
%% 			NewCache = compress([Elem], []), 
%%     		syn_db(NewCache), 
%% 			{noreply, ok}
%% 	end.

%% handle_cast(_Message,State)->
%% 	{noreply,State}.

handle_call(_Request, _From, State) ->
    {noreply, State}.

handle_info(syn_db, State) ->
    %% 开始异步回写
    spawn(
        fun() -> 
			[save_player_task(PlayerId,TaskCache)||{PlayerId,TaskCache}<-get_task_cache_all()]
            %% ?DEBUG("需回写任务数据[~w]，压缩并回写[~w]", [length(State#state.cache), length(NewCache)]) 
        end
		
    ),
    %% 再次启动闹钟
    erlang:send_after(?TIMER_1, self(), syn_db),
	 {noreply, State};
%%     {noreply, State#state{cache = []}};




%%挂机区结束系统
handle_info({'HOOKING_END'},State)->
	lib_hook:hook_scene_send_out(),
	erlang:send_after(lib_hook:get_end_time(),self(),{'HOOKING_END'}),
	{noreply,State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

save_player_task(Id,Cache)->
	NewCache = compress(Cache, []),
	syn_db(NewCache),
	delete_task_cache(Id).


%%成就系统任务统计
task_count(Lv, Pid, _PlayerId, TaskId)->
	if TaskId =:=70106 ->%%循环
		   lib_achieve:check_achieve_finish_cast(Pid, 118, [1]);
	   true->
		   Td = lib_task:get_data(TaskId),
		   case lib_task:is_carry_task(Td) of%%运镖 12
			   true->
				   %%氏族祝福任务判断
				   GWParam = {13, 1},
				   lib_gwish_interface:check_player_gwish(Pid, GWParam),
				   lib_achieve:check_achieve_finish_cast(Pid, 112, [1]),
				   lib_activity:update_activity_data_cast(yb, Pid, 1);%%添加玩家活跃度统计
			   false->
				   case lib_task:is_dug_task(Td) of%%副本 7
					   true->lib_achieve:check_achieve_finish_cast(Pid, 107, [1]),
							 case (Lv >= 25 andalso Lv =< 34 andalso TaskId =:= 61002)
								 orelse (Lv >= 35 andalso Lv =< 44 andalso TaskId =:= 61010)
								 orelse (Lv >= 45 andalso Lv =< 54 andalso TaskId =:= 61015)
								 orelse (Lv >= 55 andalso Lv =< 64 andalso TaskId =:= 61016)
								 orelse (Lv >= 65 andalso Lv =< 69 andalso TaskId =:= 61036)
								 orelse (Lv >= 70 andalso Lv =< 99 andalso TaskId =:= 61050) of 
								 true ->
									 %%氏族祝福任务判断
									 GWParam = {24, 1},
									 lib_gwish_interface:check_player_gwish(Pid, GWParam),
									 lib_activity:update_activity_data_cast(fb, Pid, 1);%%添加玩家活跃度统计;
								 false ->
									 skip
							 end;
					   false->
						   case lib_task:is_guild_task(Td) of%%氏族 4
							   true->lib_achieve:check_achieve_finish_cast(Pid, 104, [1]),
									 case (Lv >= 25 andalso Lv =< 34 andalso TaskId =:= 60100)
										 orelse (Lv >= 35 andalso Lv =< 99 andalso TaskId =:= 83150)
										 orelse (Lv >= 35 andalso Lv =< 44 andalso TaskId =:= 61011)
										 orelse (Lv >= 45 andalso Lv =< 54 andalso TaskId =:= 61017)
										 orelse (Lv >= 55 andalso Lv =< 64 andalso TaskId =:= 61018)
										 orelse (Lv >= 65 andalso Lv =< 74 andalso TaskId =:= 61037)
										 orelse (Lv >= 75 andalso Lv =< 99 andalso TaskId =:= 61051) of 
										 true ->
											 lib_activity:update_activity_data_cast(gt, Pid, 1);%%添加玩家活跃度统计;
										 false ->
											 skip
									 end;
							   false->
								   case lib_task:is_hero_task(Td) of%%封神贴 16
									   true->
										   lib_achieve:check_achieve_finish_cast(Pid, 116, [1]),
										   lib_activity:update_activity_data_cast(fst, Pid, 1),%%添加玩家活跃度统计
										   %%氏族祝福任务判断
										   GWParam = {5, 1},
										   lib_gwish_interface:check_player_gwish(Pid, GWParam);
									   false->
										   case lib_task:is_culture_task(Td) of%%修为10
											   true->
												   %%氏族祝福任务判断
												   GWParam = {22, 1},
												   lib_gwish_interface:check_player_gwish(Pid, GWParam),
												   lib_achieve:check_achieve_finish_cast(Pid, 110, [1]),
												   lib_activity:update_activity_data_cast(cult, Pid, 1);%%添加玩家活跃度统计;;
											   false->
												   case lib_task:is_business_task(Td) of%%跑商14
													   true->
														   %%氏族祝福任务判断
														   GWParam = {20, 1},
														   lib_gwish_interface:check_player_gwish(Pid, GWParam),
														   lib_achieve:check_achieve_finish_cast(Pid, 114, [1]),
														   lib_activity:update_activity_data_cast(bc, Pid, 1);%%添加玩家活跃度统计;;
													   false->
														   case lib_task:is_daily_pk_mon_task(Td) of%%日常打怪
															   true->
																   %%氏族祝福任务判断
																   GWParam = {26, 1},
																   lib_gwish_interface:check_player_gwish(Pid, GWParam),
																   lib_achieve:check_achieve_finish_cast(Pid, 102, [1]),
																   lib_activity:update_activity_data_cast(rc, Pid, 1);%%添加玩家活跃度统计;;
															   false->
																   case lib_task:is_cycle_task(Td) of%%普通循环
																	   true->
																		 lib_achieve:check_achieve_finish_cast(Pid, 118, [1]);
																	   false->
																		   case lib_task:is_random_cycle(Td) of%%随机循环
																			   true->
																				   lib_achieve:check_achieve_finish_cast(Pid, 118, [1]);
																			   false->
																				   if 
																					   TaskId =:= 80100 ->%%部落荣誉 
																						   %%氏族祝福任务判断
																						   GWParam = {21, 1},
																						   lib_gwish_interface:check_player_gwish(Pid, GWParam),
																						   lib_activity:update_activity_data_cast(rea_hor, Pid, 1);%%添加玩家活跃度统计;
																					   TaskId =:= 83000 ->%%仙侣情缘
																						   %%氏族祝福任务判断
																						   GWParam = {9, 1},
																						   lib_gwish_interface:check_player_gwish(Pid, GWParam),
																						   lib_activity:update_activity_data_cast(love, Pid, 1);%%添加玩家活跃度统计;
																					   TaskId >= 80002 andalso TaskId =< 80006 ->%%温柔一刀
																						    lib_activity:update_activity_data_cast(evil, Pid, 1);%%添加玩家活跃度统计;
																					   TaskId =:= 73000 orelse TaskId =:= 73001 orelse TaskId =:= 73002
																						 orelse TaskId =:= 73003 orelse TaskId =:= 73004 
																						 orelse TaskId =:= 73005 ->%%远古试炼
																						   %%氏族祝福任务判断
																						   GWParam = {18, 1},
																						   lib_gwish_interface:check_player_gwish(Pid, GWParam);
																					   TaskId =:= 40103 ->%%神兵利器的任务检查
																						   lib_achieve:check_achieve_finish_cast(Pid, 202, [1]);
																					   true ->
																						   skip
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
%%**************缓存区操作**************%%
%% 获取单个玩家任务信息
get_task_cache(PlayerId) ->
    case ets:lookup(?ETS_TASK_CACHE, PlayerId) of
        [] ->[];
        [{_,TaskCache}] -> TaskCache
    end.

%%获取所有玩家任务信息
get_task_cache_all()->
   	ets:tab2list(?ETS_TASK_CACHE).

insert_task_cache(PlayerId,Cache) ->
	ets:insert(?ETS_TASK_CACHE, {PlayerId,Cache}).

delete_task_cache(PlayerId) ->
	ets:match_delete(?ETS_TASK_CACHE,{PlayerId,_='_'}).