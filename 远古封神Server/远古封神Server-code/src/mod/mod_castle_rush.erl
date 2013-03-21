%%%-----------------------------------
%%% @Module  : mod_castle_rush
%%% @Author  : ygfs
%%% @Created : 2011.11.16
%%% @Description: 九霄攻城战
%%%-----------------------------------
-module(mod_castle_rush).
-behaviour(gen_server).

-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

-export(
	[
		start/0,
		start_link/1
	]
).
-export(
	[
		init/1, 
		handle_call/3, 
		handle_cast/2, 
		handle_info/2, 
		terminate/2, 
		code_change/3
	]
).

-record(state, {
	worker_id = 0,														%% 工作进程ID
	castle_rush_timer = undefined										%% 龙塔定时器
}).

%% 启动攻城战监控服务
start() ->
	gen_server:start(?MODULE, [0], []).
start_link(WorkerId) ->
	gen_server:start_link(?MODULE, [WorkerId], []).

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([WorkerId]) ->
	process_flag(trap_exit, true),
	Self = self(),
	SceneProcessName = misc:create_process_name(scene_p, [?CASTLE_RUSH_SCENE_ID, WorkerId]),
	misc:register(global, SceneProcessName, Self),
	if
		WorkerId =:= 0 ->
?WARNING_MSG("CASTLE_RUSH_START ------------------------- Pid ~p~n", [Self]),

			%% 清除上一次攻城战的人物数据
			catch ets:match_delete(?ETS_ONLINE_SCENE, #player{ scene = ?CASTLE_RUSH_SCENE_ID, _ = '_' }),
            %% 删除上一次攻城战的怪物数据
            mod_mon_create:clear_scene_mon(?CASTLE_RUSH_SCENE_ID),
            %% 复制场景数据
            lib_scene:copy_scene(?CASTLE_RUSH_SCENE_ID, ?CASTLE_RUSH_SCENE_ID),
            misc:write_monitor_pid(Self, ?MODULE, {?CASTLE_RUSH_SCENE_ID}),
            
            %% 攻城战数据初始
            lib_castle_rush:del_castle_rush_data(),
            lib_castle_rush:init_castle_rush_data(),
            
            %% 攻城战总开始
            castle_rush_action_start(Self),
           
            %% 启动战场服务进程
            lists:foreach(
                fun(WorkId)-> mod_castle_rush:start_link(WorkId) end,
            lists:seq(1, ?SCENE_WORKER_NUMBER));
		true ->
			skip
	end,
	State = #state{
  		worker_id = WorkerId			   
   	},
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
%% 统一模块+过程调用(call)
handle_call({apply_call, Module, Method, Args}, _From, State) ->
	Reply = 
		case (catch apply(Module, Method, Args)) of
			{'EXIT', Info} ->
?WARNING_MSG("apply_call_apply_call: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
				error;
			DataRet -> DataRet
		end,
	{reply, Reply, State};

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%% 统一模块+过程调用(cast)
handle_cast({apply_cast, Module, Method, Args}, State) ->
	case catch apply(Module, Method, Args) of
		{'EXIT', Info} ->	
?WARNING_MSG("mod_castle_rush_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
			error;
		_ -> 
			ok
	end,
	{noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

%% 攻城战防守方增加防御
handle_cast('CASTLE_RUSH_DEF_FEAT', State) ->
	lib_castle_rush:castle_rush_def_feat(),
    {noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

%% 攻城战正式开始时
handle_info('CASTLE_RUSH_START', State) ->
	CastleRushTimer = lib_castle_rush:castle_rush_start(),
	NewState = State#state{
		castle_rush_timer = CastleRushTimer			   
	},
    {noreply, NewState};

%% 攻城战结束
handle_info('CASTLE_RUSH_END', State) ->
	spawn(fun()-> lib_castle_rush:castle_rush_end() end),
	{noreply, State};

%% 关闭攻城战进程
handle_info('CASTLE_RUSH_KILL', State) ->
	MS = ets:fun2ms(fun(P) when P#player.scene == ?CASTLE_RUSH_SCENE_ID ->
		P#player.other#player_other.pid
	end),
	PlayerList = ets:select(?ETS_ONLINE_SCENE, MS),
	Fun = fun(Pid) ->
		gen_server:cast(Pid, 'CASTLE_RUSH_CHECK')
	end,
	lists:foreach(Fun, PlayerList),
	lib_castle_rush:del_castle_rush_data(),
	{stop, normal, State};

%% 获取怒气值
handle_info({'GET_CASTLE_RUSH_ANGRY', PidSend}, State) ->
	CastleRushAngry =
		case get(castle_rush_angry) of
			undefined ->
				0;
			CRA ->
				CRA
		end,
	{ok, BinData} = pt_47:write(47011, CastleRushAngry),
	lib_send:send_to_sid(PidSend, BinData),
	{noreply, State};

%% 更新怒气值（同时更新被击方和攻击方的个人功勋）
%% DerId 被击者
%% AerId 攻击者
%% GuildId 氏族ID
handle_info({'UPDATE_CASTLE_RUSH_ANGRY', DerId, AerId, GuildId, Leader}, State) ->
	lib_castle_rush:update_castle_rush_angry(DerId, AerId, GuildId, Leader),
	{noreply, State};
%% 更新怒气值
handle_info({'UPDATE_CASTLE_RUSH_ANGRY_EFFECT', GuildId, AngryNum, AngryParam, WinGuildId}, State) ->
	lib_castle_rush:update_castle_rush_angry_effect(GuildId, AngryNum, AngryParam, WinGuildId),
	{noreply, State};

%% 使用怒气技能
handle_info({'CASTLE_RUSH_ANGRY', GuildId, PidSend}, State) ->
	CastleRushAngry =
		case get(castle_rush_angry) of
			undefined ->
				0;
			CRA ->
				CRA
		end,
	if
		CastleRushAngry >= 15 ->
			CastleRushAngryParam = 
				case get(castle_rush_angry_param) of
					undefined ->
						put(castle_rush_angry_param, [0, 0]),
						zero;
					[WinGuildId, CRAP] ->
						CastleRushInfo = lib_castle_rush:get_castle_rush_info(),
						if
							WinGuildId =:= CastleRushInfo#ets_castle_rush_info.win_guild andalso GuildId =/= CastleRushInfo#ets_castle_rush_info.win_guild ->
								CRAP;
							true ->
								put(castle_rush_angry_param, [0, 0]),
								zero
						end;
					_ ->
						put(castle_rush_angry_param, [0, 0]),
						zero
				end,
			NewCastleRushAngryParam =
				if
					CastleRushAngryParam =/= zero ->
						CastleRushAngryParam;
					true ->
						0
				end,
			lib_castle_rush:castle_rush_angry(GuildId, NewCastleRushAngryParam),
			put(castle_rush_angry, 0),
			{ok, BinData} = pt_47:write(47011, 0),
			lib_castle_rush:send_to_castle_rush_guild(?CASTLE_RUSH_SCENE_ID, GuildId, BinData);
		true ->
			{ok, BinData} = pt_47:write(47012, 1),
			lib_send:send_to_sid(PidSend, BinData)
	end,
	{noreply, State};

%% 龙塔攻防
handle_info({'CASTLE_RUSH_ATT_DEF', Num}, State) ->
	case State#state.castle_rush_timer of
		undefined ->
			skip;	
		CastleRushTimer ->
			catch erlang:cancel_timer(CastleRushTimer)
	end,
	NewCastleRushTimer = lib_castle_rush:castle_rush_att_def(Num),
	NewState = State#state{
		castle_rush_timer = NewCastleRushTimer						   
	},
	{noreply, NewState};

%% 龙塔攻防更换
handle_info('CASTLE_RUSH_ATT_DEF_REPEAT', State) ->
	case State#state.castle_rush_timer of
		undefined ->
			skip;	
		CastleRushTimer ->
			catch erlang:cancel_timer(CastleRushTimer)
	end,
	NewCastleRushTimer = lib_castle_rush:get_castle_rush_repeat_timer(),
	NewState = State#state{
		castle_rush_timer = NewCastleRushTimer						   
	},
	{noreply, NewState};

handle_info(_Info, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, State) ->
	if
		State#state.worker_id =:= 0 ->
?WARNING_MSG("CASTLE_RUSH_END ------------------------- State ~p~n", [State]);
		true ->
			skip
	end,
	case State#state.castle_rush_timer of
		undefined ->
			skip;	
		CastleRushTimer ->
			catch erlang:cancel_timer(CastleRushTimer)
	end,
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% 攻城战开始（总开始，开始报名，开始各种定时操作）
castle_rush_action_start(Self) ->
	TodaySec = util:get_today_current_second(),
	CastleRushJoinTimeDist = lib_castle_rush:get_castle_rush_join_time_dist(TodaySec),
	CastleRushTimeDist = lib_castle_rush:get_castle_rush_time_dist(TodaySec),
	CastleRushCheckTimeDist = lib_castle_rush:get_castle_rush_check_time_dist(TodaySec),
	erlang:send_after(CastleRushJoinTimeDist * 1000, Self, 'CASTLE_RUSH_START'),
	erlang:send_after(CastleRushTimeDist * 1000, Self, 'CASTLE_RUSH_END'),
	erlang:send_after(CastleRushCheckTimeDist * 1000, Self, 'CASTLE_RUSH_KILL'),
	%% 广播攻城战报名时间
	spawn(fun()-> lib_castle_rush:broadcast_castle_rush_time(TodaySec) end).

