%%%-----------------------------------
%%% @Module  : mod_td
%%% @Author  : lzz
%%% @Created : 2011.05.05
%%% @Description: 塔防
%%%-----------------------------------
-module(mod_td).
-behaviour(gen_server).

%% Include files
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

%% External exports
-compile([export_all]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {
	start_time = 0,						%% 塔防开始时间
	last_att_time = 0, 					%% 上次攻击时间
	stop_mon = 0,						%% 是否停止刷怪，0正常刷怪，1停止刷怪
	td_scene_id = 0,					%% 副本唯一id
	att_num = 0 ,						%% 当前攻击波数
	skip_att_num = 0,					%% 跳过波数
	kill_p = 0,							%% 是否有击杀1波
	mgc_td = 0,							%% 当前魔力值
	hor_td = 0,							%% 当前除魔功勋
	def_num = 0,					%% 当前守卫个数
	def_mon_list = [{0,1},{1,0},{2,0},{3,0}],	%% 防守方怪物等级， 0为镇妖剑，1为巫医，2为法师，3为甲士
	scene_id = 0,							%% 场景原始id	
    pid_team = undefined,					%% 队伍进程Pid
	pid_sword = undefined,					%%镇妖剑进程Pid
    td_role_list = [],   				%% 副本服务器内玩家列表
    td_scene_requirement_list = [], 	%% 副本场景激活条件
    td_scene_list =[],    				%% 副本服务器所拥有的场景
	boss_number = 0,					%% 本副本内BOSS个数
	drop_id = 1
}).

-record(td_role,  {id, pid}).
-record(td_scene, {id, did, sid, enable=true, tip = <<>>}).

%% 刷怪定时器1min 间隔时间60秒
-define(MON_TIMER_1M, 60*1000).
%% 刷怪定时器40s 间隔时间40秒
-define(MON_TIMER_40S, 40*1000).
%% 刷怪定时器20min 作测试用
-define(MON_TIMER_20M, 20*60*1000).

%% ----------------------- 对外接口 ---------------------------------
%% 进入塔防
check_enter(SceneResId, SceneType, ScPid) ->
	case catch gen:call(ScPid, '$gen_call', {check_enter, SceneResId, SceneType}, 2000) of
		{'EXIT', _Reason} ->
			{false, <<"系统繁忙，请稍候重试！">>};
		{ok, Result} ->
			Result
	end.

%% 创建副本进程，由lib_scene调用
start(Pid_team, From, SceneId, RoleList ,Attnum) ->
	{ok, Pid_td} = gen_server:start(?MODULE, [Pid_team, SceneId, RoleList ,Attnum], []),
    [mod_player:set_dungeon(Rpid, SceneId) || {_, Rpid, _} <- RoleList, Rpid =/= From],
    {ok, Pid_td}.

%% 主动加入新的角色
join(Pid_td, PlayerInfo) ->

    case misc:is_process_alive(Pid_td) of
        false -> false;
        true -> gen_server:call(Pid_td, {join_limit, PlayerInfo})
    end.

%% 从副本清除角色(Type=0, 则不回调设置)
quit(Pid_td, Rid, Type) ->
    case is_pid(Pid_td) of
        false -> false;
        true -> Pid_td ! {td_quit, Rid, Type}
    end.

%% 清除副本进程
clear(Pid_td) ->
    case is_pid(Pid_td) of
        false -> false;
        true -> Pid_td ! role_clear
    end.

%% 关闭副本进程
close_td(Pid_td) ->
    case is_pid(Pid_td) of
        false -> false;
        true -> Pid_td ! close_td
    end.	
  
%% 获取玩家所在副本的外场景
get_outside_scene(SceneId) ->
    case get_td_id(lib_scene:get_res_id(SceneId)) of
        0 -> 
			false;  %% 不在副本场景
        DungeonId ->  %% 将传送出副本
            Dungeon = data_dungeon:get(DungeonId),
            [DungeonId, Dungeon#dungeon.out]
    end.

%% 副本杀怪
kill_mon(SceneId, TdPid, MonIdList) ->
	case is_pid(TdPid) of
  		true -> 
			TdPid ! {kill_mon, SceneId, MonIdList};
		false ->
			skip
  	end.

%% 创建副本场景
create_td_scene(SceneId, _SceneType, State) ->
	 %% 获取唯一副本场景id
    UniqueId = get_unique_td_id(SceneId),
	SceneProcessName = misc:create_process_name(scene_p, [UniqueId, 0]),
	misc:register(global, SceneProcessName, self()),
    lib_scene:copy_scene(UniqueId, SceneId),  %% 复制场景
    F = fun(DS) ->
        case DS#td_scene.sid =:= SceneId of
            true -> DS#td_scene{id = UniqueId};
            false -> DS
        end
    end,
    NewState = State#state{td_scene_id = UniqueId,
						   td_scene_list = [F(X)|| X <- State#state.td_scene_list]},    %% 更新副本场景的唯一id
	
	misc:write_monitor_pid(self(),?MODULE, {SceneId}),
    {UniqueId, NewState}.

%% 组织副本的基础数据
get_td_data([], Dungeon_scene_requirement, Dungeon_scene) ->
    {Dungeon_scene_requirement, Dungeon_scene};
get_td_data([DungeonId | NewDungeon_id_list], Dungeon_scene_requirement, Dungeon_scene) ->
	Dungeon = data_dungeon:get(DungeonId),
    Dungeon_scene_0 = [#td_scene{id = 0, did = DungeonId, sid = Sid, enable = Enable, tip = Msg} 
						|| {Sid, Enable, Msg} <- Dungeon#dungeon.scene],
    get_td_data(NewDungeon_id_list, 
					 Dungeon_scene_requirement ++ Dungeon#dungeon.requirement, 
					 Dungeon_scene ++ Dungeon_scene_0).

%% 获取副本信息
get_info(UniqueId) ->
	SceneProcessName = misc:create_process_name(scene_p, [UniqueId, 0]),
	case misc:whereis_name({global, SceneProcessName}) of
		Pid when is_pid(Pid) ->	
			gen_server:call(Pid, {info});
		_-> no_alive
	end.

rm_player_byscid(SceneUniqueId, PlayerId) ->
	TdScenePid = mod_scene:get_scene_real_pid(SceneUniqueId),
	case is_pid(TdScenePid) of
		true ->
			TdScenePid ! {rm_player, PlayerId};
		false ->
			skip
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
init([Pid_team, SceneId, RoleList,SkipAtt]) ->
	NowTime = util:unixtime(),
    Role_list = [#td_role{id=Role_id, pid=Role_pid} || {Role_id, Role_pid, _Player_Pid_td} <- RoleList],
    {Dungeon_scene_requirement_list, Dungeon_scene_list} = 
		get_td_data([SceneId], [], []),
	if
		SkipAtt > 0 ->
			AttNum = SkipAtt,
			[AddExp,AddSpi] = data_td:get_skip_exp_spi(SkipAtt),
			[AddHor,AddMgc] = data_td:get_skip_hor_mgc(SkipAtt,SceneId),
			Mgc_td = AddMgc,
			Hor_td = AddHor,
			%% 跳波后补偿
			skip_compensate(Role_list,AddExp,AddSpi),
			Timer_new_mon = erlang:send_after(?MON_TIMER_40S, self(), new_mon),
			put(new_mon_timer, Timer_new_mon);
		true ->
			Timer_new_mon = erlang:send_after(?MON_TIMER_1M, self(), new_mon),
			put(new_mon_timer, Timer_new_mon),
			AttNum = 0,
			Mgc_td = 0,
			Hor_td = 0
	end,
    State = #state{
		att_num = AttNum,
		mgc_td = Mgc_td,
		hor_td = Hor_td,
		skip_att_num = SkipAtt,
		start_time	= NowTime,
		last_att_time = NowTime,
		scene_id = SceneId,
        pid_team = Pid_team,
        td_role_list = Role_list,
        td_scene_requirement_list = Dungeon_scene_requirement_list,
        td_scene_list = Dungeon_scene_list
    },
	misc:write_monitor_pid(self(),?MODULE, {State}),
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
	case lists:keyfind(SceneResId, 4, State#state.td_scene_list) of
        		false ->
            		{reply, {false, <<"没有这个副本场景">>}, State};   %%没有这个副本场景
        		Td_scene ->
            		case Td_scene#td_scene.enable of
                		false ->
                    		{reply, {false, Td_scene#td_scene.tip}, State};    %%还没被激活
                		true ->
                    		{SceneUniqueId, NewState} = 
											case Td_scene#td_scene.id =/= 0 of
                        						true -> 
													{Td_scene#td_scene.id, State};   %%场景已经加载过
                        						_ -> 
													create_td_scene(SceneResId, SceneType, State)
                    						end,
							misc:write_monitor_pid(self(),?MODULE, {NewState}),
                    		{reply, {true, SceneUniqueId}, NewState}
            		end
    end;

%% 加入副本服务
handle_call({join, PlayerInfo}, _From, State) ->
	[_SceneId, PlayerId, Player_Pid, Player_Pid_dungeon] = PlayerInfo,
    clear(Player_Pid_dungeon),  %% 清除上个副本服务进程
    case lists:keyfind(PlayerId, 2, State#state.td_role_list) of
        false -> 
            NewRL = [#td_role{id = PlayerId, pid = Player_Pid} | State#state.td_role_list],
			NewState = State#state{td_role_list = NewRL},
			misc:write_monitor_pid(self(),?MODULE, {NewState}),
            {reply, true, NewState};
		_ -> 
			{reply, true, State}
    end;

%% 加入副本服务(60秒限制)
handle_call({join_limit, PlayerInfo}, _From, State) ->
	TimeLimit = (util:unixtime() - 60 > State#state.start_time),
	if
		State#state.scene_id =:= 999 andalso TimeLimit ->
			{reply, false, State};
		true ->
			[_SceneId, PlayerId, Player_Pid, Player_Pid_dungeon] = PlayerInfo,
    		clear(Player_Pid_dungeon),  %% 清除上个副本服务进程
			case lists:keyfind(PlayerId, 2, State#state.td_role_list) of
        			false -> 
           				NewRL = [#td_role{id = PlayerId, pid = Player_Pid} | State#state.td_role_list],
						NewState = State#state{td_role_list = NewRL},
						misc:write_monitor_pid(self(),?MODULE, {NewState}),
            			{reply, true, NewState};
					_ -> 
						{reply, true, State}
    		end
	end;

%% 初始化时，如在副本，则加入副本服务
handle_call({join_init, PlayerInfo}, _From, State) ->
	[PlayerId, Player_Pid] = PlayerInfo,
    case lists:keyfind(PlayerId, 2, State#state.td_role_list) of
        false -> 
            Rl = State#state.td_role_list;
		_ -> 
			Rl = lists:keydelete(PlayerId, 2, State#state.td_role_list)
    end,
    NewRL = [#td_role{id = PlayerId, pid = Player_Pid} | Rl],
	NewState = State#state{td_role_list = NewRL},
	misc:write_monitor_pid(self(),?MODULE, {NewState}),
	{reply, true, NewState};

handle_call({'TD_HANDLER', Cmd, Data}, _From, State) ->
	case Cmd of
		%% 退出镇妖台
		43002 ->
			case [lib_scene:get_scene_mon_td(State#state.td_scene_id, 101), State#state.stop_mon] of
				[[],_] ->
					{reply, {1, State#state.hor_td}, State};
				[_, 1] ->
					{reply, {1, State#state.hor_td}, State};
				_ ->
					%%中途退出
					State1 = State#state{td_role_list = lists:keydelete(Data, 2, State#state.td_role_list)},
					case check_alive(State1) of
						true ->
							Att_num = 
								if
									State#state.att_num =:= 0 ->
										0;
									true ->
										State#state.att_num - 1
								end,
							case State#state.scene_id of
								998 ->
									%%防止秒怪
									Kill_p = check_kill_p_state(State),
									{reply, {998, State#state.hor_td, State#state.mgc_td, Att_num ,State#state.skip_att_num,Kill_p}, State};
								_ ->
									{reply, {999, State#state.hor_td, Att_num}, State}
							end;
						_ ->
							case State#state.scene_id of
								998 ->
									rec_single(State);
								_ ->
									rec_multi(State)
							end,
							erlang:send_after(500, self(), {td_end, 3}),
							{reply, {0, State#state.hor_td}, State}
					end
			end;
		43005 ->
			DefInfo = lists:keyfind(Data, 1, State#state.def_mon_list),
			Mgc_Cost = lib_td:get_cost(43005, DefInfo, State#state.scene_id),
			Lv =
				case DefInfo of
					{_, Mon_lv} ->
						Mon_lv;
					_ ->
						false
				end,
			if
				Lv =:= false ->
					{reply, [0, Data], State};
				State#state.mgc_td < Mgc_Cost ->
					{reply, [2, Data], State};
				Data =:= 0 ->
					Nowtime = util:unixtime(),
					case get(recover_def) of
						undefined ->
							New_Mgc = State#state.mgc_td - Mgc_Cost,
							{ok, McgBinData} = pt_43:write(43000, [1, New_Mgc]),
							Msg= io_lib:format("消耗魔力值: ~p",[Mgc_Cost]),
							{ok,McgCostBinData} = pt_15:write(15055,[Msg]),
							send_to_scene_player(State, [McgBinData, McgCostBinData]),
							Sword_Pid = sword_op(1, State),
							put(recover_def, Nowtime),
							{reply, [1, Data], State#state{mgc_td = State#state.mgc_td - Mgc_Cost, pid_sword = Sword_Pid}};
						Last_recover_time when Nowtime - 40 > Last_recover_time ->
							New_Mgc = State#state.mgc_td - Mgc_Cost,
							{ok, McgBinData} = pt_43:write(43000, [1, New_Mgc]),
							Msg= io_lib:format("消耗魔力值: ~p",[Mgc_Cost]),
							{ok,McgCostBinData} = pt_15:write(15055,[Msg]),
							send_to_scene_player(State, [McgBinData, McgCostBinData]),
							Sword_Pid = sword_op(1, State),
							put(recover_def, Nowtime),
							{reply, [1, Data], State#state{mgc_td = State#state.mgc_td - Mgc_Cost, pid_sword = Sword_Pid}};
						_ ->
							{reply, [7, Data], State}
					end;
				Lv =:= 0 ->
					{reply, [3, Data], State};
				State#state.def_num >= 3 ->
					{reply, [5, Data], State};
				Data =:= 1 orelse Data =:= 2 orelse Data =:= 3 ->
					New_Mgc = State#state.mgc_td - Mgc_Cost,
					New_Def_Num = State#state.def_num + 1,
					{ok, McgBinData} = pt_43:write(43000, [1, New_Mgc]),
					{ok, DefBinData} = pt_43:write(43000, [3, New_Def_Num]),					
					Msg= io_lib:format("消耗魔力值: ~p",[Mgc_Cost]),
					{ok,McgCostBinData} = pt_15:write(15055,[Msg]),
					send_to_scene_player(State, [McgBinData, DefBinData, McgCostBinData]),
					DefInfo = lists:keyfind(Data, 1, State#state.def_mon_list),
					MonList = lib_td:get_def_list(DefInfo, State#state.scene_id),
					lib_scene:load_def_td(MonList, State#state.td_scene_id),
					{reply, [1, Data], State#state{mgc_td = New_Mgc, def_num = New_Def_Num}};
				true ->
					{reply, [0, Data], State}
			end;
		43006 ->
			DefInfo = lists:keyfind(Data, 1, State#state.def_mon_list),
			Mgc_Cost = lib_td:get_cost(43006, DefInfo, State#state.scene_id),
			Lv =
				case DefInfo of
					{_, Mon_lv} ->
						Mon_lv;
					false ->
						false
				end,
			if
				Lv =:= false ->
					{reply, [0, Data, 0], State};
				State#state.mgc_td < Mgc_Cost ->
					{reply, [2, Data, Lv], State};
				Lv =:= 5 ->
					{reply, [5, Data, Lv], State};
				Data =:= 0 ->
					New_Mgc = State#state.mgc_td - Mgc_Cost,
					{ok, McgBinData} = pt_43:write(43000, [1, New_Mgc]),
					Msg= io_lib:format("消耗魔力值: ~p",[Mgc_Cost]),
					{ok,McgCostBinData} = pt_15:write(15055,[Msg]),
					{ok, ResBinData} = pt_43:write(43006, [1, Data, Lv + 1]),		
					send_to_scene_player(State, [McgBinData, McgCostBinData, ResBinData]),
					Sword_Pid = sword_op(2, State),
					NewMonList = lists:keyreplace(Data, 1, State#state.def_mon_list, {Data, Lv + 1}),
					{reply, [1, Data, Lv + 1], State#state{def_mon_list = NewMonList, mgc_td = New_Mgc, pid_sword = Sword_Pid}};
				Data =:= 1 orelse Data =:= 2 orelse Data =:= 3 ->
					New_Mgc = State#state.mgc_td - Mgc_Cost,
					{ok, McgBinData} = pt_43:write(43000, [1, New_Mgc]),
					Msg= io_lib:format("消耗魔力值: ~p",[Mgc_Cost]),
					{ok,McgCostBinData} = pt_15:write(15055,[Msg]),
					{ok, ResBinData} = pt_43:write(43006, [1, Data, Lv + 1]),
					send_to_scene_player(State, [McgBinData, McgCostBinData, ResBinData]),
					NewMonList = lists:keyreplace(Data, 1, State#state.def_mon_list, {Data, Lv + 1}),
					{reply, [1, Data, Lv + 1], State#state{def_mon_list = NewMonList, mgc_td = New_Mgc}};
				true ->
					{reply, [0, Data, 0], State}
			end;
		%% 加速刷怪
		43008 ->
			if
				State#state.scene_id == 999 andalso State#state.att_num =:= 71 ->
					{reply, 4, State};
				State#state.scene_id == 998 andalso State#state.att_num =:= 81 ->
					{reply, 4, State};
				true ->
					MS = ets:fun2ms(fun(M) when M#ets_mon.scene == State#state.td_scene_id, 
												M#ets_mon.hp > 0, (M#ets_mon.type == 98 orelse M#ets_mon.type == 99) -> 
	    				[
            				M#ets_mon.id		             
	    				]
					end),
					case ets:select(?ETS_SCENE_MON, MS) of
						[] ->
							misc:cancel_timer(new_mon_timer),
							self() ! new_mon,
							{reply, 1, State};
						_ ->
							{reply, 2, State}
					end
			end;

		_ ->
			{reply, error, State}
	end;

%% 获取副本信息
handle_call({info}, _From, State) ->
	{reply, State, State};

%% 获取副本信息（用于人物数量记录）用来决定没有组队的情况下是否能刷新返回镇妖台
%% 不是1个返回out，1个则比较id是否相同，同则ok，不同则out
handle_call({info_num, Uid}, _From, State) ->
	case length(State#state.td_role_list) of
		1 ->
			case lists:keyfind(Uid, 2, State#state.td_role_list) of
				false ->
					{reply, out, State};
				_ ->
					{reply, ok, State}
			end;
		_ ->
			{reply, out, State}
	end;

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

handle_cast({'TD_HANDLER', Pid_send, Cmd, _Data}, State) ->
	case Cmd of
		43001 ->
			Nowtime = util:unixtime(),
			Next_att_time = 
				case State#state.att_num of
					0 ->
						abs(60 - (Nowtime - State#state.last_att_time));
					71 when State#state.scene_id == 999 ->
						0;
					81 when State#state.scene_id == 998 ->
						0;
					_ ->
						abs(40 - (Nowtime - State#state.last_att_time))
				end,
			{ok, BinData} = pt_43:write(43001,[State#state.att_num, Next_att_time, State#state.mgc_td, State#state.hor_td, State#state.def_num]),
			lib_send:send_to_sid(Pid_send, BinData),
			{noreply, State};
		43004 ->
			{ok, BinData} = pt_43:write(43004, lists:map(fun(R) -> {_, Lv} = R, Lv end, State#state.def_mon_list) ++ [State#state.def_num]),
			lib_send:send_to_sid(Pid_send, BinData),
			{noreply, State};			
		_ ->
			{noreply, State}
	end;

handle_cast({'TD_END', Res}, State) ->
	[Hor_ttl, Stop_mon] = end_td(Res, State),
	case Stop_mon of
		0 ->
			{noreply, State#state{hor_td = Hor_ttl, stop_mon = Stop_mon}};
		_ ->
			send_out_all(State),
			{stop,normal,State}
	end;

handle_cast({'RM_PLAYER', Uid}, State) ->
	State1 = State#state{td_role_list = lists:keydelete(Uid, 2, State#state.td_role_list)},
	misc:write_monitor_pid(self(),?MODULE, {State1}),
	{noreply, State1};

%% 玩家下线处理
handle_cast({'LEAVE_TD', PlayerId, Now}, State) ->
	case State#state.stop_mon of
		1 ->
			erlang:send_after(500, self(), {td_end, 1}),
			{noreply, State};
		_ ->
			db_agent:delete_log_td_unread(PlayerId, Now),
			AttNum =
				case State#state.att_num of
					0 ->
						State#state.att_num;
					_ ->
						State#state.att_num - 1
				end,
			spawn(fun()-> db_agent:add_td_log_unread(PlayerId, AttNum, State#state.hor_td, State#state.scene_id, Now) end),
			{noreply, State}
	end;

%% 怪物特定范围伤害
handle_cast({'LAST_AREA_DAM', Hurt, Last, AttArea, SceneId, X, Y, SkillId}, State) ->
	erlang:send_after(1000, self(), {'LAST_AREA_DAM', Hurt, Last, AttArea, SceneId, X, Y}),
	{ok, BinData} = pt_20:write(20103, [X, Y, (Last + 1) * 1000, SkillId]),
	lib_send:send_to_online_scene(SceneId, X, Y, BinData),
	{noreply, State};

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

%% 怪物特定范围伤害
handle_info({'LAST_AREA_DAM', Hurt, Last, AttArea, SceneId, X, Y}, State) ->
	lib_mon:battle(0, 0, 0, SceneId, X, Y, AttArea, Hurt, 0, 10048),
	case Last > 0 of
		true ->
			erlang:send_after(1000, self(), {'LAST_AREA_DAM', Hurt, Last - 1, AttArea, SceneId, X, Y});
		false ->
			skip
	end,
    {noreply, State};

%% 接收杀怪事件
handle_info({kill_mon, SceneId, MonIdList}, State) ->
    case lists:keyfind(SceneId, 2, State#state.td_scene_list) of
   		%% 没有这个场景ID
		false -> 
			{noreply, State};    
        _ ->
			[Hor_ttl, Mg_ttl] = lists:foldl(fun(MonId, [Hor_sum, Mg_sum]) ->
									case ets:lookup(?ETS_BASE_MON, MonId) of
										[] -> [Hor_sum, Mg_sum];
										[Mon] ->
											case lib_td:is_def(Mon#ets_mon.mid) of
												true ->
													erlang:send_after(500, self(), {kill_def, Mon#ets_mon.mid}),
													[Hor_sum, Mg_sum];
												_ ->
													[Hor_p, Mgc_p, Is_boss, Att_num, Mon_num] = data_td:get_mon_info(Mon#ets_mon.mid),
													case Is_boss of
														1 ->
															erlang:send_after(500, self(), {kill_td_boss, Att_num, Mon#ets_mon.mid, Mon_num});
														_ ->
														ok
													end,
													[Hor_sum + Hor_p, Mg_sum + Mgc_p]
											end
									end
						   	end, 
						   [0, 0], MonIdList),
            {NewDSRL, UpdateScene} = event_action(State#state.td_scene_requirement_list, [], MonIdList, []),
            EnableScene = get_enable(UpdateScene, [], NewDSRL),
			%% 检查是否有杀怪1波
			Kill_p = check_kill_p_state(State),
         	NewState_1 = enable_action(EnableScene, State#state{td_scene_requirement_list = NewDSRL ,kill_p = Kill_p}),
			case [Hor_ttl, Mg_ttl] of
				[0, 0] ->
					{noreply, NewState_1};
				_ ->
					New_mgc = NewState_1#state.mgc_td + Mg_ttl,
					New_hor = NewState_1#state.hor_td + Hor_ttl,
					{ok, McgBinData} = pt_43:write(43000, [1, New_mgc]),
					{ok, HorBinData} = pt_43:write(43000, [2, New_hor]),
					MsgMgc= io_lib:format("获得魔力值: ~p",[Mg_ttl]),
					{ok,McgGainBinData} = pt_15:write(15055,[MsgMgc]), 
					MsgHor= io_lib:format("获得镇妖功勋: ~p",[Hor_ttl]),
					{ok,HorGainBinData} = pt_15:write(15055,[MsgHor]),
					send_to_scene_player(State, [McgBinData, HorBinData, McgGainBinData, HorGainBinData]),
					NewState_2 = NewState_1#state{mgc_td = New_mgc, hor_td = New_hor},
            		{noreply, NewState_2}
			end
    end;

%% 塔防杀Boss事件
handle_info({kill_def, MonId}, State) ->
	if
		MonId =:= 46901 orelse MonId =:= 46917 ->
			%% 镇妖剑被杀，塔防失败
			erlang:send_after(500, self(), {td_end, 0}),
			{noreply, State};
		true ->
			New_Def_Num = State#state.def_num - 1,
			{ok, DefBinData} = pt_43:write(43000, [3, New_Def_Num]),
			send_to_scene_player(State, [DefBinData]),
			{noreply, State#state{def_num = New_Def_Num}}
	end;

%% 塔防杀Boss事件
handle_info({kill_td_boss, Att_num, MonId, MonNum}, State) ->
	if
		Att_num =:= 80 andalso State#state.scene_id == 998 ->
			bc_the_scene_player(Att_num, State),
			erlang:send_after(500, self(), {td_end, 1});
		Att_num =:= 70 andalso State#state.scene_id == 999 ->
			bc_the_scene_player(Att_num, State),
			rec_multi(State),
			erlang:send_after(500, self(), {td_end, 1});
		Att_num >= 40 andalso MonNum =:= 1 ->
			bc_the_scene_player(Att_num, State);
		Att_num >= 40 andalso MonNum =/= 1 ->
			case lib_scene:get_scene_mon_td_by_mid(State#state.td_scene_id, MonId) of
				[] ->
					bc_the_scene_player(Att_num, State);
				_ ->
					skip
			end;
		true ->
			skip
	end,
	{noreply, State};

handle_info({rm_player, Uid}, State) ->
	State1 = State#state{td_role_list = lists:keydelete(Uid, 2, State#state.td_role_list)},
	misc:write_monitor_pid(self(),?MODULE, {State1}),
	case length(State1#state.td_role_list) >= 1 of
		true ->
			{noreply, State1};
		_ ->
			{stop, normal, State1}
	end;

%%结算TD
handle_info({td_end, Res}, State) ->
	[Hor_ttl, Stop_mon] = end_td(Res, State),
	case Stop_mon of
		0 ->
			{noreply, State#state{hor_td = Hor_ttl, stop_mon = Stop_mon}};
		_ ->
			send_out_all(State),
			{stop,normal,State}
	end;

%% 将指定玩家传出副本
handle_info({td_quit, Rid, Type}, State) ->
NewState =
    case lists:keyfind(Rid, 2, State#state.td_role_list) of
        false -> State;
        Role ->
			if Type > 0 ->
				case misc:is_process_alive(Role#td_role.pid) of
                	true ->
                    	send_out(Role#td_role.pid, State#state.scene_id);
					_-> offline   %% 不在线	
            	end;
			   true -> no_action
			end,
			State1 = State#state{td_role_list = lists:keydelete(Rid, 2, State#state.td_role_list)},
			misc:write_monitor_pid(self(),?MODULE, {State1}),
           State1		
    end,
	case NewState#state.stop_mon of
		0 ->
			case length(NewState#state.td_role_list) >= 1 of
				true ->
					{noreply, NewState};
				_ ->
					case misc:is_process_alive(NewState#state.pid_team) of
						true ->
							gen_server:cast(State#state.pid_team, {clear_dungeon});
						_ ->
							ok
					end,
					{stop, normal, State}
			end;
		_ ->
			case misc:is_process_alive(NewState#state.pid_team) of
        		true -> %% 有组队
            		case length(NewState#state.td_role_list) >= 1 of  %% 判断副本是否没有人了
                		true ->
							case check_alive(NewState) of
								true ->
									{noreply, NewState};
								_ ->
									{stop, normal, State}
							end;
                		false ->
							gen_server:cast(State#state.pid_team, {clear_dungeon}),
                    		{stop, normal, State}
            		end;
        		false ->
            		{stop, normal, State}
			end
	end;

%% 塔防存在
handle_info({iamalive}, State) ->
	erlang:send_after(10 * 1000, self(), {iamalive}),
	{noreply, State};

%% 关闭塔防
handle_info(close_td, State) ->
	%% ?DEBUG("td_close_td_______/",[]),
	case misc:is_process_alive(State#state.pid_team) of
		true ->
			gen_server:cast(State#state.pid_team, {clear_dungeon});
		false ->
			ok
	end,
	{stop, normal, State};

%% 定时刷怪
handle_info(new_mon, State) ->
	case [State#state.att_num,  State#state.stop_mon] of
		[_, 1] ->
			{noreply, State};
		[71, 0] when State#state.scene_id == 999 ->
			{noreply, State};
		[81, 0] when State#state.scene_id == 998 ->
			{noreply, State};
		_ ->
			NowTime = util:unixtime(),
			Att_num = State#state.att_num + 1,
			{ok, BinData} = pt_43:write(43001, [Att_num, 40, State#state.mgc_td, State#state.hor_td, State#state.def_num]),
			send_to_scene_player(State, [BinData]),		
			case lib_td:get_mon_list(Att_num, State#state.scene_id) of
				error ->
					error;
				[{MonId1, X, Y, MonNum1},{MonId2, X, Y, MonNum2}] ->
					lib_scene:load_mon_td({MonId1, X, Y, MonNum1}, State#state.td_scene_id),
					lib_scene:load_mon_td({MonId2, X, Y, MonNum2}, State#state.td_scene_id);
				[{MonId1, X, Y, MonNum1}] ->
					lib_scene:load_mon_td({MonId1, X, Y, MonNum1}, State#state.td_scene_id);
				_ ->
					error
			end,
			Timer_new_mon = erlang:send_after(?MON_TIMER_40S, self(), new_mon),
			put(new_mon_timer, Timer_new_mon),
			{noreply, State#state{att_num = Att_num, last_att_time = NowTime}}
	end;

handle_info(_Info, State) ->
%% io:format("td_nomatch:/~p/ ~n", [length(State#state.td_role_list)]),
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, State) ->
%% io:format("td_exit ~n"),	
	misc:cancel_timer(new_mon_timer),
	[spawn(fun()->lib_scene:clear_scene(Ds#td_scene.id)end)|| 
				Ds <- State#state.td_scene_list, Ds#td_scene.id =/= 0],
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
%% 传送出塔防
send_out(Pid, SceneId)  ->
	DungeonData = data_dungeon:get(SceneId), 
	[NextSenceId, X, Y] = DungeonData#dungeon.out,
	gen_server:cast(Pid, {send_out_td, [NextSenceId, X, Y]}).

%% 所有玩家传出塔防
send_out_all(State) ->
	F = fun(TR) ->
				send_out(TR#td_role.pid,State#state.scene_id)
		end,
	lists:foreach(F, State#state.td_role_list).

%% 跳过波数后补偿经验灵力荣誉等
skip_compensate(Role_List,Rexp,Rspi) ->
	F = fun(TR) ->
				TR#td_role.pid ! {'TD_SKIP_COMPENSTATE',Rexp,Rspi} 
		end,
	lists:foreach(F ,Role_List).

%% %% 传送出塔防 需先判断是否在此场景
%% send_out_jd(Pid, SceneId)  ->
%% 	gen_server:cast(Pid, {send_out_td_mail, SceneId}).

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

enable_action([], State) -> State;
enable_action(undefined, State) -> State;
enable_action([SceneId | T], State) ->
    case lists:keyfind(SceneId, 4, State#state.td_scene_list) of
        false -> enable_action(T, State);%%这里属于异常
        DS -> %% 广播场景已激活
            NewDSL = lists:keyreplace(SceneId, 4, State#state.td_scene_list, DS#td_scene{enable = true}),
            enable_action(T, State#state{td_scene_list = NewDSL})
    end.

%% 获取唯一副本场景id
get_unique_td_id(SceneId) ->
	case ?DB_MODULE of
		db_mysql ->
			gen_server:call(mod_auto_id:get_autoid_pid(), {td_auto_id, SceneId});
		_ ->
			db_agent:get_unique_dungeon_id(SceneId)
	end.

%% 用场景资源获取副本id
get_td_id(SceneResId) ->
    F = fun(TdSceneId, P) ->
        Td = data_dungeon:get(TdSceneId),
		case lists:keyfind(SceneResId, 1, Td#dungeon.scene) of
       		false -> 
				P;
           	_ -> 
				TdSceneId
        end
    end,
    lists:foldl(F, 0, data_scene:dungeon_get_id_list()).


send_to_scene_player(State, BinDataList) ->
    F = fun(R) -> 
		[lib_send:send_to_uid(R#td_role.id, Bin) || Bin <- BinDataList]
	end,
    [F(Role) || Role <- State#state.td_role_list].


bc_the_scene_player(Att_num, State) ->
	Member = State#state.td_role_list,
	[ConTent_PL, Player_num] = lists:foldl(fun(R, [Sum, P_num]) ->
									 case R#td_role.pid of
										 undefined ->
											 [Sum, P_num];
										 _ ->
											 case lib_player:get_online_info_fields(R#td_role.pid, [id, nickname, career, sex, realm]) of
												 [] -> [Sum, P_num];
												 [PlayerId, Nickname, Career, Sex, Realm] ->
													 Country = lib_player:get_country(Realm),
													 NameColor = data_agent:get_realm_color(Realm),
													 [Sum++io_lib:format("【<font color='~s'>~s</font>】【<a href='event:1, ~p, ~s, ~p, ~p'><font color='~s'><u>~s</u></font></a>】",
																		["#FF0000",Country, PlayerId, Nickname, Career, Sex, NameColor,Nickname]),
													  P_num + 1];
												 _ -> [Sum, P_num]
											 end
									 end
							 end,
							 [[], 0], Member),
	ConTent =
		if
			Player_num =:= 1 ->
			 	io_lib:format("~s单枪匹马，顺利地击退镇妖台第<font color='#FFFF32'>~p</font>波的妖魔。",
									[ConTent_PL, Att_num]);
			true ->
				io_lib:format("~s强强联合，顺利地击退镇妖台第<font color='#FFFF32'>~p</font>波的妖魔。",
									[ConTent_PL, Att_num])
		end,
	lib_chat:broadcast_sys_msg(2, ConTent).

end_td(Res, State) ->
	[Hor_add, Stop_mon] =
		case Res of
			1 ->
				%% 完成
				Mon_List = lib_scene:get_scene_mon_td(State#state.td_scene_id, 99),
				[Hor, ConjureList] = lists:foldl(fun(MonInfo, [Hor_Sum, DesMonList]) ->
														 [MonID, Mon_pid, Mid] = MonInfo,
														 [Hor_p, _Mgc_p, _Is_boss, _Att_num, _Mon_num] = data_td:get_mon_info(Mid),
														 [Hor_Sum + Hor_p, DesMonList ++ [{MonID, Mon_pid}]]
												 end,
												 [0, []], Mon_List),
				lib_mon:destory_conjure_mon(ConjureList, State#state.td_scene_id),
				case State#state.scene_id of
					999 ->
						rec_multi(State);
					_ ->
						rec_single(State)
				end,
				[Hor, 1];
			0 ->
				Mon_List = lib_scene:get_scene_mon_td(State#state.td_scene_id, 99),
				ConjureList = lists:foldl(fun(MonInfo, DesMonList) ->
												  	[MonID, Mon_pid, _Mid] = MonInfo,
													DesMonList ++ [{MonID, Mon_pid}]
												 end,
												 [], Mon_List),
				lib_mon:destory_conjure_mon(ConjureList, State#state.td_scene_id),
				case State#state.scene_id of
					999 ->
						rec_multi(State);
					_ ->
						rec_single(State)
				end,
				[0, 1];			
			_ ->
				%% 中途退出
				[0, 0]
		end,
	Hor_ttl = Hor_add + State#state.hor_td,
	AttNum =
		case Res =/= 1 of
			true ->
				case State#state.att_num < 1 of
					true ->
						0;
					false ->
						State#state.att_num - 1
				end;
			false ->
				State#state.att_num
		end,
	case State#state.scene_id of
		998 ->
			Exp = 0,
			Spirit = 0,
			Content = io_lib:format("镇妖台守护结束，击退~p波，共计获得~p镇妖功勋。", [AttNum,Hor_ttl]);
		_ ->
			Exp = lib_td:get_exp(Hor_ttl, State#state.scene_id),
			Spirit = round(Exp / 2),
			Content = io_lib:format("镇妖台守护结束，击退~p波，共计获得~p经验~p灵力和~p镇妖功勋。",[AttNum,Exp,Spirit,Hor_ttl])
	end,	
    {ok, TdMailBinData} = pt_19:write(19005, {1,1}),
	%% 镇妖台结果面板信息
	{ok, TdResultBinData} = pt_43:write(43003, [AttNum, Exp, Spirit, Hor_ttl]),
 	Now = util:unixtime(),
	F = fun(R) -> 
		case misc:is_process_alive(R#td_role.pid) of	
       		true ->
				if
					%%跳波后需杀怪1波
					State#state.skip_att_num == 0 orelse (State#state.skip_att_num > 0 andalso State#state.kill_p == 1) ->
						db_agent:insert_mail(1, Now, "系统", R#td_role.id, "镇妖台守护记录", Content, 0, 0, 0, 0, 0),
						db_agent:delete_log_td_unread(R#td_role.id),
						db_agent:add_td_log_read(R#td_role.id, AttNum, State#state.hor_td, State#state.scene_id, Now),
						gen_server:cast(R#td_role.pid, {'END_TD', Exp, Spirit, TdMailBinData, TdResultBinData});
					true ->
						skip
				end;
			_ -> 
				offline   %% 不在线, 不处理，让玩家上线之后处理
   		end				
	end,
    [F(R)|| R <- State#state.td_role_list],
	[Hor_ttl, Stop_mon].

check_alive(State) ->
	NewRoleList = lists:filter(fun(Role)-> 
									misc:is_process_alive(Role#td_role.pid) 
							   end, 
				  			   State#state.td_role_list),
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

sword_op(Opr, State) ->
	PidMon =
		case State#state.pid_sword of
			undefined ->
				case lib_scene:get_scene_mon_td(State#state.td_scene_id, 101) of
					[[_MonID, Mon_pid, _Mid]] ->
						Mon_pid;
					_ ->
						undefined
				end;
			Pid ->
				Pid
		end,
	case [Opr, PidMon] of
		[_, undefined] ->
			undefined;
		[1, _] -> %%修复镇妖剑
			PidMon!{'CHANGE_MON_ATTR_TD'},
			PidMon;
		_ -> %%升级镇妖剑
			case lists:keyfind(0, 1, State#state.def_mon_list) of
				{_, SwLv} ->
					[Hp, HpLim, Name, Def] = data_td:get_sw_up_info(SwLv, State#state.scene_id),
					PidMon!{'CHANGE_MON_ATTR_UP', Hp, HpLim, Name, Def};
				_->
					skip
			end,
			PidMon
	end.

rec_multi(State) ->
	%% 对多人闯关进行记录
	Att_num =
		if
			State#state.att_num =:= 0 ->
				0;
			true ->
				State#state.att_num - 1
		end,
	UidList = lists:sort(lists:map(fun(R) -> {_, Id, _} = R, {Id} end, State#state.td_role_list)),
	Uids = util:term_to_string(UidList),
	lib_td:set_td_multi(Att_num, Uids, State#state.hor_td, State#state.mgc_td, UidList),
	F = fun(R) ->
				case lib_player:get_online_info_fields(R#td_role.pid, [id, nickname, career, realm, guild_name]) of
					[] -> ok;
					[PlayerId, Nickname, Career, Realm, Guild] ->
						lib_td:set_td_single(0, Guild, Nickname, Career, Realm, PlayerId, 0, 0, State#state.hor_td);
					_ -> ok
				end
		end,
	[F(L_item) || L_item <- State#state.td_role_list].

rec_single(State) ->
	%% 对单人人闯关进行记录
	Att_num =
		if
			State#state.att_num =:= 0 ->
				0;
			true ->
				State#state.att_num - 1
		end,
	Skip_att_num = State#state.skip_att_num,
	Kill_p = State#state.kill_p,
	if
		%%没有选择跳波或者跳波后击杀一波怪
		Skip_att_num == 0 orelse (Skip_att_num > 0 andalso Kill_p ==1) ->
			F = fun(R) ->
				case lib_player:get_online_info_fields(R#td_role.pid, [id, nickname, career, realm, guild_name]) of
					[] -> ok;
					[PlayerId, Nickname, Career, Realm, Guild] ->
						lib_td:set_td_single(Att_num, Guild, Nickname, Career, Realm, PlayerId, State#state.hor_td, State#state.mgc_td, State#state.hor_td);
					_ -> ok
				end
			end,
			[F(L_item) || L_item <- State#state.td_role_list];
		true ->
			skip
	end.


%% 检查是否有杀怪1波
check_kill_p_state(State) ->
	if
		State#state.kill_p == 1 ->
			Kill_p = 1;
		State#state.skip_att_num > 0 andalso State#state.kill_p == 0 andalso State#state.att_num /= State#state.skip_att_num ->
			Need_kill = data_td:get_mon_list(State#state.skip_att_num + 1, State#state.scene_id),
			F_kill = fun({KillMonid,_n},L) ->
				Pattern = #ets_mon{scene = State#state.td_scene_id ,mid = KillMonid, _ ='_'},
				KillList = ets:match_object(?ETS_SCENE_MON,Pattern),
				length(KillList) + L
			end,
			AliveNum = lists:foldl(F_kill, 0, Need_kill),
			case AliveNum =< 1 of
				true ->
					Kill_p = 1;
				false ->
					Kill_p = 0
			end;
		true ->
			Kill_p = 0
	end,
	Kill_p.