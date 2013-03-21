%%%------------------------------------
%%% @Module  : mod_coliseum
%%% @Author  : ygfs
%%% @Created : 2012.02.26
%%% @Description: 竞技场进程
%%%------------------------------------
-module(mod_coliseum).

-behaviour(gen_server).
-include("common.hrl").
-include("record.hrl").

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
-export(
    [
   		start_link/1
    ]
).

-record(state, {
	player_id1 = 0,
	nickname1 = 0,
	lv1 = 0,
	sex1 = 0,
	career1 = 0,
	rank1 = 0,
	
	player_id2 = 0,
	nickname2 = 0,
	lv2 = 0,
	sex2 = 0,
	career2 = 0,
	rank2 = 0,	

	sign = 0,											%% 1被挑战者真人，2替身
	scene_id = 0,
	coliseum_ready_check_timer = undefined,
	coliseum_end_timer = undefined,
	coliseum_end_check_timer = undefined,
	coliseum_result_timer = undefined,
	is_end = 0 											%% 是否结束，1结束，0否				
}).

-include_lib("stdlib/include/ms_transform.hrl").

-define(COLISEUM_FIGHT_TIME, 99).									%% 竞技场战斗时间

-define(COLISEUM_END_CHECK_TIME, 10).								%% 竞技场结束离开时间

%% 启动竞技场进程
start_link([ColiseumSceneId, Player, ChallengerId, ColiseumPlayerData]) ->
    gen_server:start(?MODULE, [ColiseumSceneId, Player, ChallengerId, ColiseumPlayerData], []).


init([ColiseumSceneId, Player, ChallengerId, ColiseumPlayerData]) ->
	[Rank1, PlayerId, Nickname, Lv, Sex, Career, Rank2] = ColiseumPlayerData,
	process_flag(trap_exit, true),
	Self = self(),
	SceneProcessName = misc:create_process_name(scene_p, [ColiseumSceneId, 0]),
	misc:register(global, SceneProcessName, Self),
	
	%% 清除上一次场景的人物数据
	catch ets:match_delete(?ETS_ONLINE_SCENE, #player{ scene = ColiseumSceneId, _ = '_' }),
    %% 复制场景数据
    lib_scene:copy_scene(ColiseumSceneId, ?COLISEUM_RES_SCENE_ID),
	
	State =
		%% 判断被击方是否在线，不在线，则替身出战
		case lib_player:get_online_info(ChallengerId) of
			[] ->
				ChallengePlayer = lib_player:get_player_info(ChallengerId),
				lib_coliseum:create_coliseum_avatar(ChallengePlayer, ColiseumSceneId, []),
				
				ColiseumReadyCheckTimer = undefined,
				
				start_coliseum_timer(#state{}, Self, 2);
			ChallengePlayer ->
		
				erlang:send_after(3 * 1000, Self, {'COLISEUM_WAIT', Player#player.other#player_other.pid_send}),		
				
				%% 20秒没进入，自动用替身
				ColiseumReadyTime = lib_coliseum:get_coliseum_ready_time(),
				ColiseumReadyCheckTimer = erlang:send_after(ColiseumReadyTime * 1000, Self, {'COLISEUM_READY_CHECK', ChallengePlayer}),
				
				gen_server:cast(ChallengePlayer#player.other#player_other.pid, 
						{'COLISEUM_CHALLENGE', ColiseumSceneId, Player#player.nickname, Self}),
				#state{}
		end,
	
	%% 被挑战方的信息
	Data49009 = [
		ChallengerId, 
		ChallengePlayer#player.nickname, 
		ChallengePlayer#player.lv, 
		ChallengePlayer#player.sex, 
		ChallengePlayer#player.career,
		ChallengePlayer#player.hp_lim,
		ChallengePlayer#player.mp_lim
	],
	{ok, BinData49009} = pt_49:write(49009, Data49009),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData49009),
	
	NewState = State#state{
		player_id1 = Player#player.id,
		nickname1 = Player#player.nickname,
		lv1 = Player#player.lv,
		sex1 = Player#player.sex,
		career1 = Player#player.career,
		rank1 = Rank1,
		
		player_id2 = PlayerId,
		nickname2 = Nickname,
		lv2 = Lv,
		sex2 = Sex,
		career2 = Career,
		rank2 = Rank2,
		
		coliseum_ready_check_timer = ColiseumReadyCheckTimer,
		scene_id = ColiseumSceneId			   
	},
    {ok, NewState}.

%% 统一模块+过程调用(call)
handle_call({apply_call, Module, Method, Args}, _From, State) ->
	Reply  = 
        case (catch apply(Module, Method, Args)) of
             {'EXIT', Info} ->	
?WARNING_MSG("mod_coliseum_supervisor apply_call error: Module=~p, Method=~p, Reason=~p, Args = ~p",[Module, Method, Info, Args]),
                 error;
             DataRet -> 
                 DataRet
        end,
    {reply, Reply, State};

%% 被挑战者进入竞技场景检测
%% Type 1亲自上阵，2使用替身
handle_call({'COLISEUM_ENER_CHECK', ChallengedId, HpLim, MpLim, Type, PidSend}, _From, State) ->
	{Reply, RetState} = 
		%% 是否结束
		if
			State#state.is_end =/= 1 ->
				%% 是否已经开始了
				if
					State#state.sign > 0 -> 
						{ok, BinData} = pt_49:write(49008, 2),
		   				lib_send:send_to_sid(PidSend, BinData),
						{2, State};
					true ->
						%% 是否该挑战方
						if
							State#state.player_id2 =/= ChallengedId ->
								{ok, BinData} = pt_49:write(49008, 3),
		   						lib_send:send_to_sid(PidSend, BinData),
								{3, State};
							true ->
								if
									Type =:= 1 ->
										cancel_coliseum_timer(State#state.coliseum_ready_check_timer),
										
										%% 挑战方
										{AttHplim, AttMpLim} =
											case ets:lookup(?ETS_ONLINE_SCENE, State#state.player_id1) of
												[] ->
													{HpLim, MpLim};
												[AttPlayer | _] ->
													{AttPlayer#player.hp_lim, AttPlayer#player.mp_lim}
											end,
										AttackData = [
											State#state.player_id1, 
											State#state.nickname1, 
											State#state.lv1, 
											State#state.sex1, 
											State#state.career1,
											AttHplim,
											AttMpLim
										],
										{ok, AttackBinData} = pt_49:write(49009, AttackData),
										lib_send:send_to_uid(State#state.player_id2, AttackBinData),
										
										NewState = start_coliseum_timer(State, self(), 1),
										{1, NewState};
									true ->
										{1, State}
								end
						end
				end;
			true ->
				{ok, BinData} = pt_49:write(49008, 3),
		   		lib_send:send_to_sid(PidSend, BinData),
				{3, State}
		end,
	{reply, Reply, RetState};

handle_call(_Request, _From, State) ->
    {reply, State, State}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%% 统一模块+过程调用(cast)
handle_cast({apply_cast, Module, Method, Args}, State) ->
%% 	case catch apply(Module, Method, Args) of
%% 		{'EXIT', Info} ->	
%% ?WARNING_MSG("mod_scene_apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
%% 			error;
%% 		_ -> 
%% 			ok
%% 	end,
	spawn(fun()-> apply(Module, Method, Args) end),
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

%% 生成竞技场替身
handle_cast({'CREATE_COLISEUM_AVATAR', ChallengePlayer, SkillList}, State) ->
	lib_coliseum:create_coliseum_avatar(ChallengePlayer, State#state.scene_id, SkillList),
	
	NewState = start_coliseum_timer(State, self(), 2),
	{noreply, NewState};

%% 竞技场有一方死亡结束
%% PlayerId 死亡的玩家（替身）ID
handle_cast({'COLISEUM_LEAVE', PlayerId}, State) ->
	spawn(fun()->
		{ok, BinData} = pt_12:write(12004, PlayerId),
		lib_send:send_to_online_scene(State#state.scene_id, BinData),
		catch ets:delete(?ETS_ONLINE_SCENE, PlayerId)		  
	end),
	NewState = end_handle(State, PlayerId, 2),
	{noreply, NewState};

%% 竞技场有一方死亡结束
%% PlayerId 死亡的玩家（替身）ID
handle_cast({'COLISEUM_DIE', PlayerId}, State) ->
	NewState = end_handle(State, PlayerId, 1),
	{noreply, NewState};

%% 竞技场有一方死亡结束
%% PlayerId 分身ID
handle_cast({'SHADOW_DIE', PlayerId}, State) ->
	NewState = end_handle(State, PlayerId, 1),
	{noreply, NewState};

handle_cast(_Msg, State) ->
    {noreply, State}.

%% 发送等待时间
handle_info({'COLISEUM_WAIT', PidSend}, State) ->
	ColiseumTime = lib_coliseum:get_coliseum_ready_time(),
	{ok, BinData49010} = pt_49:write(49010, [1, ColiseumTime]),
	lib_send:send_to_sid(PidSend, BinData49010),
	{noreply, State};

%% 播放竞技动画
handle_info('COLISEUM_CARTON_START', State) ->
	{ok, BinData} = pt_49:write(49010, [2, 5]),
	lib_send:send_to_online_scene(State#state.scene_id, BinData),
	{noreply, State};

%% 竞技场战斗开始
handle_info('COLISEUM_START', State) ->
	MS = ets:fun2ms(fun(P) when P#player.scene == State#state.scene_id ->
		P
	end),
	All = ets:select(?ETS_ONLINE_SCENE, MS),
	Fun = fun(P)->
		if
			P#player.other#player_other.shadow == 0 ->
				NP = P#player{
			        other = P#player.other#player_other{
			            die_time = 0 
			        }
		    	},
				ets:insert(?ETS_ONLINE_SCENE, NP);
			true ->
				P#player.other#player_other.pid ! {'SET_PLAYER_INFO', [{die_time, 0}]}
		end
	end,
	[Fun(P) || P <- All],
	{ok, BinData} = pt_49:write(49010, [3, ?COLISEUM_FIGHT_TIME]),
	lib_send:send_to_online_scene(State#state.scene_id, BinData),
	{noreply, State};

%% 竞技场结束
handle_info('COLISEUM_END', State) ->
	if
		State#state.is_end =/= 1 ->
			MS = ets:fun2ms(fun(P) when P#player.scene == State#state.scene_id ->
				P
			end),
			All = ets:select(?ETS_ONLINE_SCENE, MS),
			Now = util:unixtime(),
			DieTime = Now + ?COLISEUM_FIGHT_TIME + ?COLISEUM_END_CHECK_TIME,
			Fun = fun(P)->
				if
					P#player.other#player_other.shadow == 0 ->
						NP = P#player{
					        other = P#player.other#player_other{
					            die_time = DieTime 
					        }
				    	},
						ets:insert(?ETS_ONLINE_SCENE, NP);
					true ->
						P#player.other#player_other.pid ! {'SET_PLAYER_INFO', [{die_time, DieTime}]}
				end
			end,
			[Fun(Pid) || Pid <- All];
		true ->
			skip
	end,
	NewState = end_handle(State, State#state.player_id1, 1),
	{noreply, NewState};

%% 发送竞技场结果
handle_info({'COLISEUM_RESULT', ResultBinData}, State) ->
	cancel_coliseum_timer(State#state.coliseum_result_timer),
	if
		State#state.is_end =:= 1 ->
			MS = ets:fun2ms(fun(P) when P#player.scene == State#state.scene_id andalso
											P#player.other#player_other.shadow == 0 andalso 
											(P#player.id == State#state.player_id1 orelse P#player.id == State#state.player_id2) -> 
				P#player.other#player_other.pid_send
			end),
		   	SendList = ets:select(?ETS_ONLINE_SCENE, MS),
			F = fun(PidSend) ->
				lib_send:send_to_sid(PidSend, ResultBinData)
		    end,
			[spawn(fun()-> F(Send) end) || Send <- SendList];
		true ->
			skip
	end,
	{noreply, State};

%% 10秒没进入，自动用替身
handle_info({'COLISEUM_READY_CHECK', ChallengePlayer}, State) ->
	if
		State#state.coliseum_ready_check_timer =/= undefined ->
			catch erlang:cancel_timer(State#state.coliseum_ready_check_timer);
		true ->
			skip
	end,
	
	lib_coliseum:create_coliseum_avatar(ChallengePlayer, State#state.scene_id, []),
	
	NewState = start_coliseum_timer(State, self(), 2),
	{noreply, NewState};

%% 竞技场结束检查
handle_info('COLISEUM_END_CHECK', State) ->
	MS = ets:fun2ms(fun(P) when P#player.scene == State#state.scene_id, 
								P#player.other#player_other.shadow == 0 ->
		P#player.other#player_other.pid
	end),
	All = ets:select(?ETS_ONLINE_SCENE, MS),
	Fun = fun(Pid)->
		case is_pid(Pid) of
			true ->
				gen_server:cast(Pid, 'COLISEUM_END_CHECK');
			false ->
				skip
		end
	end,
	[Fun(Pid) || Pid <- All],
	{stop, normal, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, State) ->
	lib_scene:clear_scene(State#state.scene_id),
%% io:format("mod_coliseum_terminate ~p ~p~n", [Reason, State]),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.




%% 开始竞技场定时
start_coliseum_timer(State, Self, Sign) ->
	cancel_coliseum_timer(State#state.coliseum_ready_check_timer),
	
	ColiseumTime = 8,
	erlang:send_after(ColiseumTime * 1000, Self, 'COLISEUM_START'),
	
	%% 播放动画
	erlang:send_after(3 * 1000, Self, 'COLISEUM_CARTON_START'),
	
	ColiseumEndTime = ColiseumTime + ?COLISEUM_FIGHT_TIME,
	ColiseumEndTimer = erlang:send_after(ColiseumEndTime * 1000, Self, 'COLISEUM_END'),

	ColiseumEndCheckTime = ColiseumTime + ?COLISEUM_FIGHT_TIME + ?COLISEUM_END_CHECK_TIME,
	ColiseumEndCheckTimer = erlang:send_after(ColiseumEndCheckTime * 1000, Self, 'COLISEUM_END_CHECK'),
	State#state{
		coliseum_end_timer = ColiseumEndTimer,
		coliseum_end_check_timer = ColiseumEndCheckTimer,
		sign = Sign	
	}.
	
%% 结束处理
%% EndType 1正常死亡结束、2有一方逃跑结束
end_handle(State, PlayerId, EndType) ->
	if
		State#state.is_end =/= 1 andalso State#state.coliseum_result_timer == undefined ->
			{Result, Rank, Coin, Culture} = 
				if
					%% 挑战成功
					PlayerId =/= State#state.player_id1 ->
						R = 
							if
								State#state.rank1 > State#state.rank2 ->
									State#state.rank2;
								true ->
									0
							end,
						Ret = 
							if
								EndType == 1 ->
									1;
								true ->
									3
							end,
						{Ret, R, 1000, 50};
					%% 挑战失败
					true ->
						Ret = 
							if
								EndType == 1 ->
									2;
								true ->
									4
							end,
						{Ret, 0, 200, 10}
				end,
			Data49011 = [
				State#state.player_id1,
				State#state.nickname1,
				State#state.lv1,
				State#state.sex1,
				State#state.career1,
				State#state.player_id2,
				State#state.nickname2,
				State#state.lv2,
				State#state.sex2,
				State#state.career2,
				Result,
				Coin,
				Culture,
				Rank
			],
			{ok, BinData} = pt_49:write(49011, Data49011),
			%% 发送竞技场结果
			ColiseumResultTimer = erlang:send_after(1000, self(), {'COLISEUM_RESULT', BinData}),
			
			ColiseumPid = mod_coliseum_supervisor:get_coliseum_cal_worker_pid(),
			gen_server:cast(ColiseumPid, {'CAL_COLISEUM_RESULT', State#state.player_id1, State#state.player_id2, Result}),
			
			case lib_player:get_player_pid(State#state.player_id1) of
				[] ->
					no_pid;
				AttPid ->
					gen_server:cast(AttPid, {'COLISEUM_AWARD', Coin, Culture})
			end,	
			
			cancel_coliseum_timer(State#state.coliseum_end_timer),
			cancel_coliseum_timer(State#state.coliseum_end_check_timer),
			ColiseumEndCheckTimer = erlang:send_after(?COLISEUM_END_CHECK_TIME * 1000, self(), 'COLISEUM_END_CHECK'),
			
			State#state{
				is_end = 1,
				coliseum_result_timer = ColiseumResultTimer,
				coliseum_end_check_timer = ColiseumEndCheckTimer				   
			};
		true ->
			State
	end.

%% 取消定时器
cancel_coliseum_timer(ColiseumTimer) ->
	if
		ColiseumTimer =/= undefined ->
			catch erlang:cancel_timer(ColiseumTimer);
		true ->
			skip
	end.
