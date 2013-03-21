%%%-----------------------------------
%%% @Module  : mod_training
%%% @Author  : hzj
%%% @Created : 2011.07.13
%%% @Description: 试炼副本
%%%-----------------------------------
-module(mod_training).
-behaviour(gen_server).

-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-compile([export_all]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]). 

-record(state, {
	self = undefined,					%% 试炼副本进程
	start_time = 0,						%% 试炼开始时间
	t_scene_id = 0,					    %% 副本唯一id
	stop = false ,						%% 是否已停止
	att_num = 0,						%% 当前攻击波数
	att_mon_num = 0,					%% 当前波数的怪物数
	max_lv = 0,							%% 当前副本角色的最大等级
	scene_id = 0,						%% 场景原始id	
    pid_team = undefined,				%% 队伍进程Pid
    t_role_list = [],   				%% 副本服务器内玩家列表
    t_scene_requirement_list = [], 	    %% 副本场景激活条件
	boss_number = 0,					%% 本副本内BOSS个数
	drop_id = 1
}).

-record(t_role,  {id, pid}).
-define(TotalAttNum, 76).				%% 怪物波数
-define(TIMER_START, 3).         		%% 开始定时器
-define(TIMER_STOP, 3600).        		%% 结束定时器
-define(TERMINATE,3780).		%% 副本进程销毁定时器
-define(TIMER_CHECK,3).			%% 刷怪检测定时
%% ----------------------- 对外接口 ---------------------------------
%% 进入试炼副本
check_enter(SceneResId, SceneType, ScPid) ->
	case catch gen:call(ScPid, '$gen_call', {check_enter, SceneResId, SceneType}, 2000) of
		{'EXIT', _Reason} ->
			{false, <<"系统繁忙，请稍候重试！">>};
		{ok, Result} ->
			Result
	end.

%% 创建副本进程，由lib_scene调用
start(Pid_team, From, SceneId ,RoleInfo) ->
    case  gen_server:start(?MODULE, [Pid_team, SceneId ,RoleInfo], []) of
		{ok,Pid_t} ->
    		[mod_player:set_dungeon(Rpid, SceneId) || {_, Rpid} <- [RoleInfo], Rpid =/= From],
    		{ok, Pid_t};
		_Err ->
			?WARNING_MSG("mod_training:error:~p~n",[_Err]),
			fail
	end.

%% 主动加入新的角色
join(Pid_t, PlayerInfo) ->
    case misc:is_process_alive(Pid_t) of
		true ->
			try
        		gen_server:call(Pid_t, {join, PlayerInfo})
			catch
				_:_ ->
					false
			end;
		false ->
			false
	end.

%% 从副本清除角色(Type=0, 则不回调设置)
quit(Pid_t, Rid, Type) ->
    try
        Pid_t ! {t_quit, Rid, Type}
	catch
		_:_ ->
			false
    end.

%% 清除副本进程
clear(Pid_t) ->
  	try
        Pid_t ! role_clear
	catch
		_:_ ->
			false
    end.

%% 关闭副本进程
close_t(Pid_t) ->
    try
        Pid_t ! close_t
	catch
		_:_ ->
			false
    end.	
  
%% 获取玩家所在副本的外场景
%% get_outside_scene(SceneId) ->
%%     case get_td_id(lib_scene:get_res_id(SceneId)) of
%%         0 -> false;  %% 不在副本场景
%%         DungeonId ->  %% 将传送出副本
%%             Dungeon = data_dungeon:get(DungeonId),
%%             [DungeonId, Dungeon#dungeon.out]
%%     end.

%% 副本杀怪
kill_mon(Scene, Pid_t, MonIdList) ->
	try
  		Pid_t ! {kill_mon, Scene, MonIdList}
	catch
		_:_ ->
			false
  	end.

%% 强制刷怪
rush_mon(UniqueId) ->
	SceneProcessName = misc:create_process_name(scene_p, [UniqueId, 0]),
	case misc:whereis_name({global, SceneProcessName}) of
		Pid when is_pid(Pid) ->
			Pid ! rush ;
		_ ->
			skip
	end.

%% 获取怪物信息 
get_mon_info(UniqueId) ->
	SceneProcessName = misc:create_process_name(scene_p, [UniqueId, 0]),
	case misc:whereis_name({global, SceneProcessName}) of
		Pid when is_pid(Pid) ->
			gen_server:call(Pid,{mon_list,UniqueId});
		_ ->
			skip
	end.

%% 创建副本场景
create_t_scene(SceneId, _SceneType, State) ->
	 %% 获取唯一副本场景id
    UniqueId = get_unique_t_id(SceneId),
	
	SceneProcessName = misc:create_process_name(scene_p, [UniqueId, 0]),
	misc:register(global, SceneProcessName, self()),
    lib_scene:copy_scene(UniqueId, SceneId),  %% 复制场景
%% 	MS = ets:fun2ms(fun(T) when T#ets_mon.type >= 100, T#ets_mon.scene =:= UniqueId ->
%% 							T
%% 					end),		
%% 	L = ets:select(?ETS_SCENE_MON, MS),	
%% 	Boss_number = length(L),				%% 本副本内BOSS个数
    NewState = State#state{t_scene_id = UniqueId},	
	misc:write_monitor_pid(self(),?MODULE, {SceneId}),
    {UniqueId, NewState}.

%% 组织副本的基础数据
%% get_t_data([], Dungeon_scene_requirement, Dungeon_scene) ->
%%     {Dungeon_scene_requirement, Dungeon_scene};
%% get_t_data(Dungeon_id_list, Dungeon_scene_requirement, Dungeon_scene) ->
%%     [Dungeon_id | NewDungeon_id_list] = Dungeon_id_list,
%%     Dungeon = data_dungeon:get(Dungeon_id),
%%     Dungeon_scene_0 = [#t_scene{id=0, did=Dungeon_id, sid=Sid, enable=Enable, tip=Msg} 
%% 						|| {Sid, Enable, Msg} <- Dungeon#dungeon.scene],
%%     get_t_data(NewDungeon_id_list, 
%% 					 Dungeon_scene_requirement ++ Dungeon#dungeon.requirement, 
%% 					 Dungeon_scene ++ Dungeon_scene_0).

%% 获取副本信息
get_info(UniqueId) ->
	SceneProcessName = misc:create_process_name(scene_p, [UniqueId, 0]),
	case misc:whereis_name({global, SceneProcessName}) of
		Pid when is_pid(Pid) ->	
			gen_server:call(Pid, {info});
		_-> no_alive
	end.

%% 获取副本信息
get_pid(UniqueId) ->
	SceneProcessName = misc:create_process_name(scene_p, [UniqueId, 0]),
	case misc:whereis_name({global, SceneProcessName}) of
		Pid when is_pid(Pid) ->	
			Pid;
		_-> undefined
	end.

%% 根据副本id移除玩家
rm_player_byscid(UniqueId, Uid) ->
	case get_pid(UniqueId) of
		undefined ->
			ok;
		Pid ->
			Pid ! {rm_player, Uid}
	end.

%% ------------------------- 服务器内部实现 ---------------------------------
%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([Pid_team, SceneId, RoleInfo]) ->
	NowTime = util:unixtime(),
	{Role_id, Role_pid ,Lv} = RoleInfo,
    Role_list = [#t_role{id=Role_id, pid=Role_pid}],
    %%{Dungeon_scene_requirement_list, _Dungeon_scene_list} = get_t_data([SceneId], [], []),
	Self = self(),	
    State = #state{
		self = Self,
		start_time	= NowTime,
		max_lv = Lv,
		scene_id = SceneId,
        pid_team = Pid_team,
        t_role_list = Role_list
    },
	Timer_stop = erlang:send_after(?TIMER_STOP * 1000 ,Self ,stop),
	Terminate = erlang:send_after(?TERMINATE * 1000 ,Self,terminate),
	Timer_check = erlang:send_after(?TIMER_CHECK * 1000, Self, check_mon),
	put(mod_name,mod_training),
	put(timer_stop, Timer_stop),
	put(terminate,Terminate),
	put(timer_check,Timer_check),
	misc:write_monitor_pid(Self,?MODULE, {State}),
    {ok, State}.

%% --------------------------------------------------------------------
%% Function: handle_call/3
%% Description: Handling call messages
%% Returns: {reply, Reply, State}          |
%%          {reply, Reply, State, Timeout} |
%%          {noreply, State}               |
%%          {noreply, State, Timeout}      |
%%          {stop, Reason, Reply, State}   | (terminate/2 is called)
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%%检查进入副本
handle_call({check_enter, SceneResId, SceneType}, _From, State) ->   %% 这里的SceneId是数据库的里的场景id，不是唯一id
    case data_dungeon:get(SceneResId) of
        [] ->
            {reply, {false, <<"没有这个副本场景">>}, State};   %%没有这个副本场景
        _Dungeon ->
            {SceneUniqueId, NewState} = 
                            case State#state.t_scene_id =/= 0 of
                                true -> 
                                    {State#state.t_scene_id, State};   %%场景已经加载过
                                _ -> 
                                    create_t_scene(SceneResId, SceneType, State)
                            end,
            misc:write_monitor_pid(self(),?MODULE, {NewState}),
            {reply, {true, SceneUniqueId}, NewState}

    end;

%% 加入副本服务
handle_call({join, PlayerInfo}, _From, State) ->
	[PlayerId, Player_Pid, Lv] = PlayerInfo,
	F_filter = fun(R_info) ->
					   R_info#t_role.id /= PlayerId
			   end,
	NewRL = lists:filter(F_filter, State#state.t_role_list),
    %%NewRL = lists:keydelete(PlayerId, 2, State#state.t_role_list),
    NewRL2 = NewRL ++ [#t_role{id = PlayerId, pid = Player_Pid}],
	MaxLv = 
		if
			State#state.max_lv > Lv ->State#state.max_lv;
			true -> Lv
		end,
	NewState = State#state{t_role_list = NewRL2 ,max_lv = MaxLv},
	%%延时发送时间
	erlang:send_after(3000,State#state.self , {send_time,PlayerId}),
	%%加入检查
	State#state.self ! check_mon,
	
	TrainJoinList = 
		case get(train_join_list) of
			undefined ->
				[];
			TJL ->
				TJL
		end,
	case lists:member(PlayerId, TrainJoinList) of
		false ->
			%% 功能参与度
			spawn(fun()-> db_agent:update_join_data(PlayerId, train) end),
			put(train_join_list, [PlayerId | TrainJoinList]);
		true ->
			skip
	end,
	
	misc:write_monitor_pid(self(), ?MODULE, {NewState}),
    {reply, true, NewState};

%% 离开试炼副本检查是否已停止
handle_call({check_leave},_From,State) ->
	if
		State#state.stop == true ->
			Reply = 0;
		true ->
			Reply = 1
	end,
	{reply, Reply, State};

%% 获取副本信息
handle_call({info}, _From, State) ->
	{reply, State, State};


%% 获取副本场景ID
handle_call({info_id}, _From, State) ->
	{reply, State#state.scene_id, State};

%% 获取掉落物自增ID
handle_call({'GET_DROP_ID', DropNum}, _From, State) ->
	DropId = State#state.drop_id + DropNum + 1,
	NewDropId = 
		if
   			DropId > ?MON_LIMIT_NUM ->
				1;
	   		true ->
				DropId
        end,
	NewState = State#state{
		drop_id = NewDropId
	},
    {reply, State#state.drop_id, NewState};

%% 统一模块+过程调用(call)
handle_call({apply_call, Module, Method, Args}, _From, State) ->
%% %% ?DEBUG("mod_td_apply_call: [~p/~p/~p]", [Module, Method, Args]),	
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_td_apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
			 error;
		 DataRet -> DataRet
	end,
    {reply, Reply, State};

%% 获取当前怪物列表
handle_call({mon_list,T_scene_id},_From,State) ->
	Pattern = #ets_mon{scene = T_scene_id , _ ='_'},
	MonList = ets:match_object(?ETS_SCENE_MON,Pattern),
	{reply,MonList,State};

	
handle_call(_Request, _From, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%% 统一模块+过程调用(cast)
handle_cast({apply_cast, Module, Method, Args}, State) ->
%% 	%% ?DEBUG("mod_td_apply_cast: [~p/~p/~p]", [Module, Method, Args]),	
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_td_apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
			 error;
		 _ -> ok
	end,
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

handle_cast({'RM_PLAYER', Uid}, State) ->
	State1 = State#state{t_role_list = lists:keydelete(Uid, 2, State#state.t_role_list)},
	misc:write_monitor_pid(self(),?MODULE, {State1}),
	{noreply, State1};

handle_cast(_Msg, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%% 在副本里创建队伍，需要设置到副本进程
handle_info({set_team, Pid_team}, State) ->
	NewState = State#state{pid_team = Pid_team},
  	{noreply, NewState};

%%发送剩余时间
handle_info({send_time,PlayerId},State) ->
	Now = util:unixtime(),
	PassTime = Now - State#state.start_time,
	if
		PassTime < ?TIMER_STOP ->
			LeftTime = ?TIMER_STOP - PassTime;
		true ->
			LeftTime = 0
	end,
	{ok,Bin} = pt_12:write(12050,[LeftTime]),
	lib_send:send_to_uid(PlayerId,Bin),
	{noreply,State};

%% 试炼副本杀怪
handle_info({kill_mon, _Scene, _MonIdList},State) ->		
	{noreply,State};

%% 清除角色, 关闭副本服务进程
handle_info(role_clear, State) ->
	case misc:is_process_alive(State#state.pid_team) of
        true -> %% 有组队
            case length(State#state.t_role_list) >= 1 of  %% 判断副本是否没有人了
                true ->
                    {noreply, State};
                false ->
					gen_server:cast(State#state.pid_team, {clear_dungeon}),
                    {stop, normal, State}
            end;
        false ->
			%% 非队伍副本，退出则关闭副本
            {stop,normal,State}
    end;	

%% 将指定玩家传出副本
handle_info({t_quit, Rid, Type}, State) ->
    case lists:keyfind(Rid, 2, State#state.t_role_list) of
        false -> {noreply, State};
        Role ->
			if Type > 0 ->
				case misc:is_process_alive(Role#t_role.pid) of
                	true ->
                    	send_out(Role#t_role.pid, State#state.scene_id);
					_-> offline   %% 不在线	
            	end;
			   true -> no_action
			end,
			NewState = State#state{t_role_list = lists:keydelete(Rid, 2, State#state.t_role_list)},
			misc:write_monitor_pid(self(),?MODULE, {NewState}),
            {noreply, NewState}			
    end;

%% 将所有玩家传出副本 并关闭
handle_info({t_quit_all},State) ->
	F = fun(TR) ->
				send_out(TR#t_role.pid,State#state.scene_id),
				%%通知时间消失
				{ok,Bin} = pt_12:write(12050,[0]),
				lib_send:send_to_uid(TR#t_role.id,Bin)
		end,
	lists:foreach(F, State#state.t_role_list),
	{stop,normal,State};

%% 检查怪物刷新
handle_info(check_mon,State) ->
	T_scene_id = State#state.t_scene_id,
	Pattern = #ets_mon{scene = T_scene_id , _ ='_'},
	MonList = ets:match_object(?ETS_SCENE_MON,Pattern),
	Att_num = State#state.att_num,
	if
		length(MonList) == 0  andalso Att_num < ?TotalAttNum ->
			NewState = rush(State);
		length(MonList) == 0 andalso Att_num == ?TotalAttNum ->
			erlang:send_after(2000, self(), stop),
			NewState = State;
		true ->
			NewState = State
	end,
	misc:cancel_timer(timer_check),
	TimerCheck = erlang:send_after(?TIMER_CHECK * 1000, self(), check_mon),
	put(timer_check,TimerCheck),
	{noreply,NewState};

%%接收刷怪信息
handle_info(rush,State) ->
	T_scene_id = State#state.t_scene_id,
	Pattern = #ets_mon{scene = T_scene_id , _ ='_'},
	MonList = ets:match_object(?ETS_SCENE_MON,Pattern),
	Att_num = State#state.att_num,
	if
		Att_num < ?TotalAttNum ->
			F = fun(Mon) ->
				MonId = Mon#ets_mon.id,
				Mon#ets_mon.pid ! clear ,
				{ok, BinData} = pt_12:write(12082, [MonId, 0]),
				lib_send:send_to_online_scene(T_scene_id, BinData)
			end,
			lists:foreach(F, MonList),
			ets:match_delete(?ETS_SCENE_MON, Pattern),
			NewState = rush(State);
		true ->
			NewState = State
	end,
	{noreply,NewState};

%%停止刷怪
handle_info(stop,State) ->
	NewState = State#state{att_num = 0 ,stop = true},
	erlang:send_after(3000, State#state.self, {t_quit_all}),
	{noreply,NewState};

%% 副本进程消耗
handle_info(terminate,State) ->
	{stop,normal,State};

handle_info(_Info, State) ->
%% io:format("td_nomatch:/~p/ ~n", [length(State#state.td_role_list)]),
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, State) ->
%%	?DEBUG("--------------------------terminate----~p~n---",[_Reason]),
	lib_scene:clear_scene(State#state.t_scene_id),
	misc:cancel_timer(timer_stop),
	misc:cancel_timer(terminate),
	misc:cancel_timer(timer_check),
	misc:delete_monitor_pid(self()),
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% -----------------------------私有方法--------------------------------
%% 传送试炼副本
send_out(Pid, SceneId)  ->
	DungeonData = data_dungeon:get(SceneId), 
	[NextSenceId, X, Y] = DungeonData#dungeon.out,
	gen_server:cast(Pid, {send_out_training, [NextSenceId, X, Y]}).


%% 类似格式： [[451, false, kill_mon, 30031, 10, 0],[452, false, kill_mon, 30032, 1, 0]]
event_action([], Req, _, Result) -> {Req, Result};
event_action(undefined, Req, _, Result) -> {Req, Result};
event_action([[EnableSceneResId, false, kill_mon, MonId, Num, NowNum] | T ], Req, Param, Result)->
    MonList = Param,
    case length([X||X <- MonList, MonId =:= X]) of
        0 -> event_action(T, [[EnableSceneResId, false, kill_mon, MonId, Num, NowNum] | Req], Param, Result);
        FightNum ->
            case NowNum + FightNum >= Num of
                true -> 
					event_action(T, [[EnableSceneResId, true, kill_mon, MonId, Num, Num] | Req], Param, lists:umerge(Result, [EnableSceneResId]));
                false -> 
					event_action(T, [[EnableSceneResId, false, kill_mon, MonId, Num, NowNum + FightNum] | Req], Param, lists:umerge(Result, [EnableSceneResId]))
            end
    end;
%% 丢弃异常和已完成的
event_action([_ | T], Req, Param, Result) ->
    event_action(T, Req, Param, Result).

get_enable([], Result, _) -> Result;
get_enable(undefined, Result, _) -> Result;
get_enable([SceneId | T ], Result, DSRL) ->
    case length([0 || [EnableSceneResId, Fin | _ ] <- DSRL, EnableSceneResId =:= SceneId, Fin =:= false]) =:= 0 of
        false -> get_enable(T, Result, DSRL);
        true -> get_enable(T, [SceneId | Result], DSRL)
    end.


%% 获取唯一副本场景id
get_unique_t_id(SceneId) ->
	db_agent:get_unique_dungeon_id(SceneId).


%% 发送消息提示
send_to_scene_msg(State) ->
	Att_num = State#state.att_num,
	if
		Att_num == 0 ->
			Msg = io_lib:format("试炼副本结束!",[]) ;
		Att_num < ?TotalAttNum ->
			Msg = io_lib:format("试炼副本第~p波!",[Att_num]);
		true -> 
			Msg = io_lib:format("试炼副本BOSS!"	,[])
	end,
	{ok,Bin} = pt_15:write(15055,[Msg]),
	send_to_scene_player(State,[Bin]).

%%发送到副本场景内地玩家
send_to_scene_player(State, BinDataList) ->
	F_send = fun(Uid, BinData) -> lib_send:send_to_uid(Uid, BinData) end,			 
    F = fun(RX) -> 
				case misc:is_process_alive(RX#t_role.pid) of	
                	true ->
						[F_send(RX#t_role.id, BD)|| BD <- BinDataList];
					_-> offline   %% 不在线	
            	end				
		end,
    [F(R)|| R <- State#state.t_role_list].

%%检查是否存活
check_alive(State) ->
	NewRoleList = lists:filter(fun(Role)-> 
									misc:is_process_alive(Role#t_role.pid) 
							   end, 
				  			   State#state.t_role_list),
	case length(NewRoleList) >= 1 of
		 true -> 
			true;			 
		 _ -> %% 除了离线的人，没有其它队员在副本里
			case misc:is_process_alive(State#state.pid_team) of
        		true -> %% 有组队, 通知队伍进程
					gen_server:cast(State#state.pid_team, {clear_dungeon});
				_ -> no_action
			end,
			false
	end.

%% 刷出一波怪
rush(State) ->
	T_scene_id = State#state.t_scene_id,
	Att_num = State#state.att_num,
	MaxLv = State#state.max_lv,
	Stop = State#state.stop,
	case T_scene_id > 0  andalso Stop == false of
		true ->
			NewAtt_num = Att_num + 1,
			MonList = data_training:get_mon_list(NewAtt_num,MaxLv),
			Num = length(MonList),
			if
				Num == 0 ->%%如果会没有怪的情况
					Msg = io_lib:format("试炼副本第~p波,~p数据异常，请联系GM!",[NewAtt_num,MaxLv]),
					{ok,Bin} = pt_15:write(15055,[Msg]),
					send_to_scene_player(State,[Bin]),
					?WARNING_MSG("mod_training error: ~p~p~n",[NewAtt_num,MaxLv]),
					NewState = State;
				true ->
					MonId = hd(MonList),			
					lib_scene:load_mon_training([MonId,Num],T_scene_id),
					NewState = State#state{att_num = NewAtt_num ,att_mon_num = Num }
			end;
		false ->
			NewState = State
	end,
	send_to_scene_msg(NewState),
	NewState.
