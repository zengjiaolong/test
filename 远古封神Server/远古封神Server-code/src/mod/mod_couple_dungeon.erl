%% Author: Administrator
%% Created: 2012-4-13
%% Description: TODO: 夫妻副本
-module(mod_couple_dungeon).

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
	dungeon_scene_id = 0,					%% 副本唯一id
	scene_id = 0,							%% 场景原始id	
    pid_team = 0,							%% 队伍进程Pid
    dungeon_role_list = [],   				%% 副本服务器内玩家列表
	teminate_timer = undefined,				%% 玩家掉线副本结束定时器
	drop_id = 1
}).

-record(dungeon_role,  {id, pid}).

-define(TIMER_1, 10*60*1000).%% 定时器1间隔时间(定时检查角色进程, 如果不在线，则送出副本)
-define(TERMINATE,7200*1000).%% 副本2小时后关闭
%% ----------------------- 对外接口 ---------------------------------
%% 进入副本
check_enter(SceneResId, SceneType, ScPid) ->
	case catch gen:call(ScPid, '$gen_call', {check_enter, SceneResId, SceneType}, 5000) of
		{'EXIT', _Reason} ->
			{false, <<"系统繁忙，请稍候重试！">>};
		{ok, Result} ->
			Result
	end.

%% 创建副本进程，由lib_scene调用
start(Pid_team, From, SceneId, RoleList) ->
    {ok, PidDungeon} = gen_server:start(?MODULE, [Pid_team, SceneId, RoleList], []),
    [spawn(fun()-> clear(Player_Pid_dungeon) end) || {_Id, _Player_Pid, Player_Pid_dungeon} <- RoleList],
    [spawn(fun()-> mod_player:set_dungeon(Rpid, PidDungeon) end) || {_, Rpid, _} <- RoleList, Rpid =/= From],
    {ok, PidDungeon}.

%% 主动加入新的角色
join(Pid_dungeon, PlayerInfo) ->
    case misc:is_process_alive(Pid_dungeon) of
        false -> false;
        true -> gen_server:call(Pid_dungeon, {join, PlayerInfo})
    end.

%% 从副本清除角色(Type=0, 则不回调设置)
quit(PidDungeon, Rid, Type) ->
    case is_pid(PidDungeon) of
		true -> 
			PidDungeon ! {quit, Rid, Type};
        false -> 
			false
    end.

%% 清除副本进程
clear(DungeonPid) ->
    case is_pid(DungeonPid) of
        true ->
			DungeonPid ! role_clear;
		false ->
			skip
    end.	
  
%% 获取玩家所在副本的外场景
get_outside_scene(SceneId) ->
	SceneResId = lib_scene:get_res_id(SceneId),
    case get_dungeon_id(SceneResId) of
        0 -> false;
        DungeonId ->
			Dungeon = data_dungeon:get(DungeonId),
            [DungeonId, Dungeon#dungeon.out]
    end.

%% 检查是否存活
check_alive(DungeonPid, Num) ->
	case is_pid(DungeonPid) of
		true -> 
			DungeonPid ! {check_alive, Num};
		false ->
			skip
    end.

%% 创建副本场景
create_dungeon_scene(SceneId, _SceneType, State) ->
	 %% 获取唯一副本场景ID
    SceneUniqueId = get_unique_dungeon_id(SceneId),
	SceneProcessName = misc:create_process_name(scene_p, [SceneUniqueId, 0]),
	misc:register(global, SceneProcessName, self()),
    lib_scene:copy_scene(SceneUniqueId, SceneId),  %% 复制场景
	%% 更新副本场景的唯一ID
    NewState = State#state{
		dungeon_scene_id = SceneUniqueId
	},    
	misc:write_monitor_pid(self(), ?MODULE, {SceneId}),
    {SceneUniqueId, NewState}.

%% 获取副本信息
get_info(UniqueId) ->
	SceneProcessName = misc:create_process_name(scene_p, [UniqueId, 0]),
	case misc:whereis_name({global, SceneProcessName}) of
		Pid when is_pid(Pid) ->	
			gen_server:call(Pid, {info});
		_-> no_alive
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
init([Pid_team, SceneId, RoleList]) ->
    Role_list = [#dungeon_role{id=Role_id, pid=Role_pid} || {Role_id, Role_pid, _Player_Pid_dungeon} <- RoleList],
	State = #state{
		scene_id = SceneId,
        pid_team = Pid_team,
        dungeon_role_list = Role_list
    },
	Self = self(),
	Timer1 = erlang:send_after(?TIMER_1, Self, check_role_pid),
	Timer2 = erlang:send_after(?TERMINATE, Self, terminate),
	put(timer1, Timer1),
	put(timer2, Timer2),
	misc:write_monitor_pid(Self, ?MODULE, {State}),
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
handle_call({check_enter, SceneResId, SceneType}, _From, State) ->
	if 
		SceneResId =:= State#state.scene_id ->
			case State#state.dungeon_scene_id =/= 0 of
          		%% 场景已经加载过
				true -> 
					{reply, {true, State#state.dungeon_scene_id}, State};
             	_ -> 
					{SceneUniqueId, NewState} = create_dungeon_scene(SceneResId, SceneType, State),
					misc:write_monitor_pid(self(), ?MODULE, {NewState}),
                  	{reply, {true, SceneUniqueId}, NewState}
      		end;
		true ->
			{reply, {false, <<"没有这个副本场景">>}, State}
    end;

%% 加入副本服务
handle_call({join, [_Sceneid, PlayerId, Player_Pid, Player_Pid_dungeon]}, _From, State) ->
    %% 清除上个副本服务进程
	clear(Player_Pid_dungeon), 
    case lists:keyfind(PlayerId, 2, State#state.dungeon_role_list) of
        false -> 
            NewRL = State#state.dungeon_role_list ++ [#dungeon_role{id = PlayerId, pid = Player_Pid}],
			NewState = State#state{dungeon_role_list = NewRL},
			misc:write_monitor_pid(self(),?MODULE, {NewState}),
            {reply, true, NewState};
		_DungeonRole ->
			{reply, true, State}
    end;

%% 初始化时，如在副本，则加入副本服务
handle_call({join_init, [PlayerId, Player_Pid]}, _From, State) ->
	case State#state.teminate_timer of
		undefined ->
			skip;
		_ ->
			erlang:cancel_timer(State#state.teminate_timer)
	end,
    case lists:keyfind(PlayerId, 2, State#state.dungeon_role_list) of
        false -> 
            Rl = State#state.dungeon_role_list;
		_ -> 
			Rl = lists:keydelete(PlayerId, 2, State#state.dungeon_role_list)
    end,
    NewRL = Rl ++ [#dungeon_role{id = PlayerId, pid = Player_Pid}],
	NewState = State#state{
		dungeon_role_list = NewRL,
		teminate_timer = undefined
	},
	misc:write_monitor_pid(self(),?MODULE, {NewState}),
	{reply, true, NewState};

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
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_dungeon_apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
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
			 ?WARNING_MSG("mod_dungeon_apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
			 error;
		 _ -> ok
	end,
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

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

%% 将指定玩家传出副本
handle_info({quit, Rid, Type}, State) ->
    case lists:keyfind(Rid, 2, State#state.dungeon_role_list) of
        false -> 
			{noreply, State};
        Role ->
			if 
				Type > 0 ->
					case misc:is_process_alive(Role#dungeon_role.pid) of
                		true ->
                    		send_out(Role#dungeon_role.pid, State#state.scene_id);
						_-> 
							offline   %% 不在线	
            		end;
			   	true -> 
					no_action
			end,
			NewState = State#state{dungeon_role_list = lists:keydelete(Rid, 2, State#state.dungeon_role_list)},
			misc:write_monitor_pid(self(),?MODULE, {NewState}),
            {noreply, NewState}			
    end;

%% 清除角色, 关闭副本服务进程
handle_info(role_clear, State) ->
	case misc:is_process_alive(State#state.pid_team) of
        true -> %% 有组队
            case length(State#state.dungeon_role_list) >= 1 of  %% 判断副本是否没有人了
                true ->
					erlang:send_after(1000, self(), {check_alive, 0}),
                    {noreply, State};
                false ->
					gen_server:cast(State#state.pid_team, {clear_dungeon}),
                    {stop, normal, State}
            end;
        false ->
            {stop, normal, State}
    end;

%% 定时检查角色进程, 如果不在线，则送出副本
handle_info(check_role_pid, State) ->
	NewRoleList = get_role_alive_list(State),
	case length(NewRoleList) >= 1 of
		 true -> 
			erlang:send_after(?TIMER_1, self(), check_role_pid),
			NewState = State#state{dungeon_role_list = NewRoleList},
			misc:write_monitor_pid(self(),?MODULE, {NewState}),
			{noreply, NewState};			 
		 _ -> %% 没有角色啦，则 清除副本
			case misc:is_process_alive(State#state.pid_team) of
        		true -> %% 有组队, 通知队伍进程	
					gen_server:cast(State#state.pid_team, {clear_dungeon});
				_ -> no_action
			end,
			{stop, normal, State}
	end;

%% 检查存活数
handle_info({check_alive, Num}, State) ->
	NewRoleList = get_role_alive_list(State),
	case length(NewRoleList) > Num of
		true -> 
			{noreply, State};			 
		_ ->
			case State#state.teminate_timer of
				undefined ->
					TeminateTimer = erlang:send_after(300 * 1000, self(), 'INTERVAL_CHECK_ALIVE'),
					NewState = State#state{
						teminate_timer = TeminateTimer   
					},
					{noreply, NewState};
				_ ->
					{noreply, State}
			end
	end;

handle_info('INTERVAL_CHECK_ALIVE', State) ->
	case State#state.teminate_timer of
		undefined ->
			skip;
		_ ->
			erlang:cancel_timer(State#state.teminate_timer)
	end,
	NewState = State#state{
		teminate_timer = undefined   
	},
	NewRoleList = get_role_alive_list(NewState),
	case length(NewRoleList) > 0 of
		true ->
			{noreply, NewState};
		false ->
			case misc:is_process_alive(State#state.pid_team) of
        		true -> %% 有组队, 通知队伍进程	
					gen_server:cast(State#state.pid_team, {clear_dungeon});
				_ -> 
					no_action
			end,
			{stop, normal, NewState}
	end;

%% 副本关闭
handle_info(terminate,State) ->
	NewRoleList = get_role_alive_list(State),
	case length(NewRoleList) >= 1 of
		true ->
			F = fun(Role) ->
				send_out(Role#dungeon_role.pid, State#state.scene_id)
			end,
			lists:foreach(F, NewRoleList);
		false ->
			skip
	end,
	{stop,normal,State};

handle_info(_Info, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, State) ->
	misc:cancel_timer(timer1),
	misc:cancel_timer(timer2),
	%% 副本关闭清理资源
	spawn(fun()-> lib_scene:clear_scene(State#state.dungeon_scene_id) end),
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
%% 传送出副本
send_out(Pid, SceneId)  ->
	DungeonData = data_dungeon:get(SceneId),
	[NewSenceId, X, Y] = DungeonData#dungeon.out,
	gen_server:cast(Pid, {send_out_dungeon, [NewSenceId, X, Y]}).

%% 获取唯一副本场景id
get_unique_dungeon_id(SceneId) ->
	db_agent:get_unique_dungeon_id(SceneId).

%% 用场景资源获取副本id
get_dungeon_id(SceneResId) ->
    F = fun(DungeonId, P) ->
		Dungeon = data_dungeon:get(DungeonId),
		case lists:keyfind(SceneResId, 1, Dungeon#dungeon.scene) of
       		false -> 
				P;
           	_ -> 
				DungeonId
        end
    end,
    lists:foldl(F, 0, data_scene:dungeon_get_id_list()).

%% 获取存活的角色列表
get_role_alive_list(State) ->
	lists:filter(fun(Role)-> 
		misc:is_process_alive(Role#dungeon_role.pid) end, 
	State#state.dungeon_role_list).