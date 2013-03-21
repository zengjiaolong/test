%%%-----------------------------------
%%% @Module  : mod_era
%%% @Author  : ygzj
%%% @Created : 
%%% @Description: 封神纪元
%%%-----------------------------------
-module(mod_era).
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
   	player_id = 0,							%% 玩家ID
	nickname = undefined,					%% 玩家昵称
	pid = undefined,						%% 玩家PID
	oscene = undefined,						%% 进入场景id
	ox = 0,									%% 旧场景坐标x
	oy = 0,									%% 旧场景坐标y
	teminate_timer = undefined,				%% 玩家掉线副本结束定时器
	unixtime = 0,							%% 时间戳
	time = 0	,							%% 时间
	stage = 0 ,								%% 关卡数
	hkills = 0,								%% 历史最大连斩数
	ckills = 0,								%% 当前最大连斩数
	buff = 0,								%% 攻击是否已经加上buff
	is_passed_stage = false,				%% 是否已经通关
	finish = false,							%% 关卡任务完成
	hurt = 0,								%% 伤害值
	stage40_revive = false,					%% 标记应龙是否复活
	stage55_revive = false,					%% 力牧是否复活
	stage60_so_num = 0,						%% 护送士兵成功个数
	stage60_att_num = 0	,					%% 刷新波数
	wind_dct = 1,							%% 风向
	burning = false,						%% 被燃烧
	drop_id = 1,
	l_pct_num = 0,							%% 左护法个数
	r_pct_num = 0,							%%  右护法个数
	xy = []									%% 护法生成坐标集
}).

-define(TERMINATE,7200*1000).%% 副本2小时后关闭
-define(TIMEALERT,1*1000). %% 通关时间提醒
-define(STAGETIME,1800).%% 每一关通关时间
-define(STAGE60ATTACK,30*1000).%% 刷新士兵时间
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
start(Pid_team, From, SceneId, RoleInfo) ->
    {ok, PidDungeon} = gen_server:start(?MODULE, [Pid_team, SceneId, RoleInfo], []),
    [spawn(fun()-> clear(Player_Pid_dungeon) end) || {_Id, _Player_Pid, Player_Pid_dungeon} <- [RoleInfo]],
    [spawn(fun()-> mod_player:set_dungeon(Rpid, PidDungeon) end) || {_, Rpid, _} <- [RoleInfo], Rpid =/= From],
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

%% 副本杀怪
kill_mon(Scene, Pid_t, [MonId,Id]) ->
	try
  		Pid_t ! {kill_mon, Scene, [MonId,Id]}
	catch
		_:_ ->
			false
  	end.

%% 创建副本场景
create_dungeon_scene(SceneId, _SceneType, State) ->
    SceneUniqueId = get_unique_dungeon_id(SceneId),
	SceneProcessName = misc:create_process_name(scene_p, [SceneUniqueId, 0]),
	misc:register(global, SceneProcessName, self()),
    lib_scene:copy_scene(SceneUniqueId, SceneId), 
	%%第一次特殊怪
	if
		State#state.stage == 30 andalso State#state.is_passed_stage == false ->
			MonList = [{47936,1,6,29}];
		true ->
			MonList = data_era:get_stage_mon(State#state.stage)
	end,
	lib_scene:load_mon_era(MonList, SceneUniqueId),
    NewState = State#state{
		dungeon_scene_id = SceneUniqueId
	},    
	misc:write_monitor_pid(self(), ?MODULE, {SceneId}),
	create_mon_action(NewState),
    {SceneUniqueId, NewState}.

%% 对应关卡的怪物特殊行为
create_mon_action(State) ->
	case State#state.stage of
		40 ->%% 应龙沉默
			MonList = get_scene_mon_list(State),
			case length(MonList) > 0 of
				true ->
					F_set = fun(MonInfo) ->
									if
										MonInfo#ets_mon.mid == 47909 ->
											MonInfo#ets_mon.pid ! {'CHANGE_MON_ACTIVE',0};
										true ->
											skip
									end
							end,
					lists:foreach(F_set, MonList);
				false ->
					skip
			end;
		45 ->%% 应龙帮助杀怪
			active_mon_type(State,47909);
		60 ->%%
			%%catch timer:apply_after(2000, mod_era, active_mon_type, [47933]); 
			active_mon_type(State,47933);
		_ ->
			ok
	end.

%%激活怪物类型
active_mon_type(State,Mid) ->
	MonList = get_scene_mon_list(State),
	case length(MonList) > 0 of
		true ->
			F_set = fun(MonInfo) ->
							if
								MonInfo#ets_mon.mid == Mid ->
									MonInfo#ets_mon.pid ! {'CHANGE_MON_ATT_TYPE',100},
									MonInfo#ets_mon.pid ! {'CHANGE_MON_ACTIVE',1},
									gen_fsm:send_event(MonInfo#ets_mon.pid, sleep);
								true ->
									skip
							end
					end,
			lists:foreach(F_set, MonList);
		false ->
			skip
	end.
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
init([_Pid_team, SceneId, RoleInfo]) ->
	{PlayerId,Pid, _Player_Pid_dungeon,Nickname,Oscene,Ox,Oy} = RoleInfo,
	Stage = lib_era:scene_to_stage(SceneId),
	Is_passed_stage = lib_era:is_passed_stage(PlayerId, Stage),
	State = #state{
		scene_id = SceneId,
		player_id = PlayerId,
		nickname = Nickname,
		oscene = Oscene,
		ox = Ox,
		oy = Oy,
		pid = Pid,
		stage = Stage,
		unixtime = util:unixtime(),
		xy = create_pos(Stage),
		is_passed_stage = Is_passed_stage
    },
	%%连斩记录
	put(ckills,{0,0}),
	%%已经移动的士兵
	put(moved,[]),
	Self = self(),
	Timer1 = erlang:send_after(?TIMEALERT, Self, timealert),
	put(timer1,Timer1),
	Timer2 = erlang:send_after(?TERMINATE, Self, terminate),
	put(timer2, Timer2),
	misc:write_monitor_pid(Self, ?MODULE, {State}),
	%%剧情对话开始通知
	if
		Is_passed_stage == true ->
			Type = 3;
		true ->
			Type = 1
	end,
	{ok,BinData} = pt_35:write(35016,[State#state.stage,Type]),
	send_to_player(Pid,BinData),
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
	NewState = State#state{player_id = PlayerId,pid = Player_Pid},
   {reply,true,NewState};

%% 初始化时，如在副本，则加入副本服务
handle_call({join_init, [PlayerId, Player_Pid]}, _From, State) ->
	case State#state.teminate_timer of
		undefined ->
			skip;
		_ ->
			erlang:cancel_timer(State#state.teminate_timer)
	end,
	%% 恢复buff
	Mult = State#state.buff,
	Time = State#state.unixtime,
	if 
		Mult > 0 andalso is_pid(Player_Pid) ->
			MultAtt = Mult * 0.2 ,
			PassTime = State#state.time,
			SkillInfo = {last_zone_att, MultAtt, Time + (1800 -PassTime) , 90008, Mult},
			Player_Pid ! {'SET_BATTLE_STATUS', {7, [SkillInfo]}};
		true ->
			skip
	end,
  	NewState = State#state{player_id = PlayerId,pid = Player_Pid,teminate_timer = undefined},
	misc:write_monitor_pid(self(),?MODULE, {NewState}),
	{reply, true, NewState};

%% 获取副本信息
handle_call({info}, _From, State) ->
	{reply, State, State};

%% 获取副本场景ID
handle_call({info_id}, _From, State) ->
	{reply, State#state.scene_id, State};

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

%% 接收离开消息
handle_cast({'LEAVE_ERA', PlayerId},State) ->
	NewState = player_leave(State,PlayerId),
	{noreply,NewState};

handle_cast(_Msg, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------

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
handle_info({quit, PlayerId, Type}, State) ->
    case State#state.player_id == PlayerId of
        false -> 
			{noreply, State};
        true ->
			if 
				Type > 0 ->
					case misc:is_process_alive(State#state.pid) of
                		true ->
                    		send_out(State);
						_-> 
							offline   %% 不在线	
            		end;
			   	true -> 
					no_action
			end,
			NewState = player_leave(State,PlayerId),
			misc:write_monitor_pid(self(),?MODULE, {NewState}),
            {noreply, NewState}			
    end;

%% 清除角色, 关闭副本服务进程
handle_info(role_clear, State) ->
	case misc:is_process_alive(State#state.pid) of
		true ->
    		send_out(State);
		_-> 
			offline 
	end,
	NewState = State#state{player_id = 0 ,pid = undefined},
	{stop,normal,NewState};
	

%% 检查存活数
handle_info({check_alive, _Num}, State) ->
	{noreply, State};


%% 副本关闭
handle_info(terminate,State) ->
	case misc:is_process_alive(State#state.pid) of
		true ->
			send_out(State);
		false ->
			skip
	end,
	{stop,normal,State};

%% 通关时间提醒
handle_info(timealert,State) ->
	Unixtime = util:unixtime(),
	PassTime = 1 + State#state.time,
	LeftTime = ?STAGETIME - PassTime ,
	if
		LeftTime > 0 ->
			Lt = LeftTime;
		true ->
			erlang:send_after(3000, self(), terminate),
			Lt = 0
	end,
	if
		PassTime rem 10 == 1 ->
			{ok,BinData} = pt_35:write(35012,[Lt]),
			send_to_player(State#state.pid, BinData);
		true ->
			skip
	end,
	if
		is_pid(State#state.pid) ->
			State2 = do_timer_stage(State#state{unixtime = Unixtime});
		true ->
			State2 = State
	end,
	misc:cancel_timer(timer1),
	Timer1 = erlang:send_after(?TIMEALERT, self(), timealert),
	put(timer1,Timer1),
	
	{noreply,State2#state{time = PassTime}};

%% 通关
handle_info(pass_stage,State) ->
	clear_scene_mon(State),
	Stage = State#state.stage,
	PassTime = State#state.time,
	%%评价等级，根据时间跟气血损耗计算
	HpHurt = State#state.hurt,
	[TimeAdd,HpAdd] = data_era:add_score(Stage,PassTime,HpHurt),
	Total = TimeAdd + HpAdd,
	if
		State#state.stage == 30 andalso State#state.is_passed_stage == false ->
			Level = 1;
		State#state.stage == 60 ->
			Level = State#state.stage60_so_num;
		true ->
			Level = data_era:calc_score_level(Stage,Total)
	end,
	%%计算积分面板
	{ok,BinData35013} = pt_35:write(35013,[Stage,PassTime,TimeAdd,HpHurt,HpAdd,Total,Level]),
	%%剧情对话结束通知
	if
		State#state.is_passed_stage == true ->
			Type = 4;
		true ->
			Type = 2
	end,
	{ok,BinData35016} = pt_35:write(35016,[State#state.stage,Type]),
	BinData = <<BinData35013/binary,BinData35016/binary>>,
	send_to_player(State#state.pid, BinData),
	lib_era:update_player_era_info(State#state.player_id,State#state.nickname,Stage,Level,PassTime,1),
	%%erlang:send_after(10000, self(), terminate),
	NewState = State#state{finish = true},
	{noreply,NewState};
	
%% 伤害值消息
handle_info({hurt,Hurt},State) ->
	NewHurt = Hurt + State#state.hurt,
	NewState = State#state{hurt = NewHurt},
	{noreply,NewState};
	
%% 
%% 杀怪
handle_info({kill_mon, Scene, [MonId,Id]},State) when Scene == State#state.dungeon_scene_id ->
	NewState = 
	case State#state.stage of
		30 ->
			do_stage_kill_mon(State,[MonId,Id],1);
		35 ->
			do_stage_kill_mon(State,[MonId,Id],2);
		40 ->
			do_stage_kill_mon(State,[MonId,Id],3);
		45 ->
			do_stage_kill_mon(State,[MonId,Id],4);
		50 ->
			do_stage_kill_mon(State,[MonId,Id],5);
		55 ->
			do_stage_kill_mon(State,[MonId,Id],6);
%% 		60 ->
%% 			do_stage_kill_mon(State,[MonId,Id],7);
		65 ->
			do_stage_kill_mon(State,[MonId,Id],8);
		70 ->
			do_stage_kill_mon(State,[MonId,Id],9);
		75 ->
			do_stage_kill_mon(State,[MonId,Id],10);
		80 ->
			do_stage_kill_mon(State,[MonId,Id],11);
		
		_ ->
			State
	end,
	{noreply,NewState};

%% 士兵移动 17,41   5,12
handle_info({'MON_MOVE',Minfo},State) ->
	X = Minfo#ets_mon.x,
	Y = Minfo#ets_mon.y,
	NewX = 0,
	NewY = 0,
	case is_process_alive(Minfo#ets_mon.pid) of
		true ->
			if
				X == 5 andalso Y == 12 ->
					kill_mon(Minfo),
					SoNum = State#state.stage60_so_num,
					NewState = State#state{stage60_so_num = SoNum+1 };
				true ->
					NewState = State
			end,
			Minfo#ets_mon.pid ! {'MON_MOVIE',NewX,NewY};
		false ->
			NewState = State
	end,
	{noreply,NewState};

%% 刷新新怪物
handle_info({'REFRESH_NEW_MON_55'},State) ->
	if
		State#state.l_pct_num < 70 ->
			{State2,{X,Y}} = get_xy(State),
			lib_scene:load_mon_era([{47914,1,X,Y}], State#state.dungeon_scene_id),
			L_pct_num = State#state.l_pct_num + 1;
		true ->
			State2 = State,
			L_pct_num = State#state.l_pct_num
	end,
	if
		State#state.r_pct_num < 80 ->
			{State3,{X2,Y2}} = get_xy(State2),
			lib_scene:load_mon_era([{47915,1,X2,Y2}], State#state.dungeon_scene_id),
			R_pct_num = State#state.r_pct_num + 1;
		true ->
			State3 = State2,
			R_pct_num = State#state.r_pct_num
	end,
	NewState = State3#state{l_pct_num = L_pct_num ,r_pct_num = R_pct_num},
	{noreply,NewState};

%%刷新boss
handle_info({'REFRESH_NEW_MON_55_BOSS'},State) ->
	lib_scene:load_mon_era([{47917,1,12,25}], State#state.dungeon_scene_id),
	{noreply,State};

%% 刷新士兵波数
handle_info({'REFRESH_NEW_MON_60'},State) ->
	AttNum = State#state.stage60_att_num,
	if
		AttNum < 6 ->
			MonList = data_era:get_stage_mon(State#state.stage),
			lib_scene:load_mon_era(MonList, State#state.dungeon_scene_id),
			active_mon_type(State,47933),
			NewState = State#state{stage60_att_num = AttNum +1};
		true ->
			NewState = State
	end,
	{noreply,NewState};

%%刷新结晶
handle_info({'REFRESH_NEW_MON_80'},State) ->
	OldMonList = get_scene_mon_list(State),
	F_kill = fun(Moninfo) ->
					 if
						 Moninfo#ets_mon.mid == 47931 ->
							 Moninfo#ets_mon.pid ! 'CLEAR_MON' ;
						 true ->
							 skip
					 end
			 end,
	lists:foreach(F_kill, OldMonList),
	MonList = [{47931,1,13,34},{47931,1,19,28},{47931,1,7,27},{47931,1,12,20}],
	lib_scene:load_mon_era(MonList, State#state.dungeon_scene_id),
	{noreply,State};

%% 风怒
handle_info({'CHANGE_SCENE_WIND'},State) ->
	
	[X,_Y] =
		case ets:lookup(?ETS_ONLINE_SCENE, State#state.player_id) of
			[Player|_] ->
				[Player#player.x,Player#player.y];
			[] ->
				[0,0]
		end,
	MonList = get_scene_mon_list(State),
	[MX,_MY] =
		case length(MonList) > 0 of
			true ->
				F = fun(Minfo) ->
								Minfo#ets_mon.mid == 47932
					end,
				MonBoss = lists:filter(F, MonList),
				case length(MonBoss) > 0 of
					true ->
						MonInfo = hd(MonBoss),
						[MonInfo#ets_mon.x,MonInfo#ets_mon.y];
					false ->
						[0,0]
				end;
			false ->
				[0,0]
		end,
	WindDct = 
		if
			X < MX ->
				1;
			true ->
				3
		end,
	%% 伤害
	Time = State#state.unixtime,
	State#state.pid ! {'START_BURN_TIMER',1000,1000},
	SkillInfo = {burn, 0, Time + 10 , 90005, 0},
	State#state.pid ! {'SET_BATTLE_STATUS', {7, [SkillInfo]}},
	%% 风向信息
	{ok,WindBin} = pt_35:write(35017, [WindDct]),
	send_to_player(State#state.pid,WindBin),
	{noreply, State#state{wind_dct = WindDct}};
	
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
	player_leave(State,State#state.player_id),
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
send_out(State)  ->
	SceneId = State#state.scene_id,
	Pid = State#state.pid,
	case lib_scene:is_dungeon_scene(State#state.oscene) of
		true ->
			DungeonData = data_dungeon:get(SceneId),
			[NewSenceId, X, Y] = DungeonData#dungeon.out;
		false ->
			[NewSenceId, X, Y] = [State#state.oscene,State#state.ox,State#state.oy]
	end,
	gen_server:cast(Pid, {send_out_dungeon, [NewSenceId, X, Y]}).

%% 获取唯一副本场景id
get_unique_dungeon_id(SceneId) ->
	case ?DB_MODULE of
		db_mysql ->
			gen_server:call(mod_auto_id:get_autoid_pid(), {dungeon_auto_id, SceneId});
		_ ->
			db_agent:get_unique_dungeon_id(SceneId)
	end.

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

%% 玩家离开处理
player_leave(State,PlayerId) ->
	Time = State#state.unixtime,
	if
	 	State#state.stage == 35 andalso State#state.buff > 0 andalso is_pid(State#state.pid) ->
			SkillInfo = {last_zone_att, 0, Time +2 , 90008, 0},
			State#state.pid ! {'SET_BATTLE_STATUS', {7, [SkillInfo]}};
		State#state.stage == 80 andalso is_pid(State#state.pid) ->
			State#state.pid ! {'TURN_OFF_BURN_TIMER'},
			SkillInfo = {burn, 0, Time +2 , 90005, 0},
			State#state.pid ! {'SET_BATTLE_STATUS', {7, [SkillInfo]}};
		true ->
			skip
	end,	
	if
		PlayerId == State#state.player_id ->
			State#state{player_id = 0,pid = undefined};
		true ->
			State
	end.

send_to_player(Pid,BinData) ->
  gen_server:cast(Pid, {send_to_sid, BinData}).

%%每一关卡杀怪处理
%%第一关
do_stage_kill_mon(State,[MonId,_Id],1) ->
	if
		MonId == 47902 orelse MonId == 47936 ->
			erlang:send_after(1000, self(), pass_stage);
		true ->
			skip
	end,
	State;

%%第二关
do_stage_kill_mon(State, [MonId,Id], 2) ->
	Time = util:unixtime(),
	case get(kill_log) of
		undefined ->
			put(kill_log,[{Id,Time}]);
		[] ->
			put(kill_log,[{Id,Time}]);
		List ->
			put(kill_log,[{Id,Time}|List])
	end,
	NewCkills = check_ckills(Time),
	if
		NewCkills =< 0 ->
			skip;
		true ->
			{ok,Bin35015} = pt_35:write(35015,[NewCkills]),
			send_to_player(State#state.pid,Bin35015)
	end,
	%%历史最大连斩数
	if
		NewCkills > State#state.hkills ->
			Mult = NewCkills div 50 ,
			if
				Mult > 0  ->
					MultAtt = Mult * 0.2 ,
					SkillInfo = {last_zone_att, MultAtt, Time + 1800 , 90008, Mult},
					State#state.pid ! {'SET_BATTLE_STATUS', {7, [SkillInfo]}};
				true ->
					skip
			end,
			TopCkills = NewCkills;
		true ->
			Mult = State#state.buff,
			TopCkills =State#state.hkills
	end,
	%%通关boss
	if
		MonId == 47904 ->
			erlang:send_after(1000, self(), pass_stage);
		true ->
			skip
	end,
	State#state{hkills = TopCkills,ckills = NewCkills,buff = Mult};
	
%% 第三关
do_stage_kill_mon(State,[MonId,_Id],3) ->
	if
		MonId == 47909 ->
			erlang:send_after(1000, self(), pass_stage);
		true ->
			skip
	end,
	State;

%% 第四关
do_stage_kill_mon(State,[MonId,_Id],4) ->
	if
		MonId == 47911 ->
			erlang:send_after(1000, self(), pass_stage);
		true ->
			skip
	end,
	State;

%% 第五关
do_stage_kill_mon(State,[MonId,_Id],5) ->
	if
		MonId == 47913 ->
			erlang:send_after(1000, self(), pass_stage);
		true ->
			skip
	end,
	State;

%% 第六关
do_stage_kill_mon(State,[MonId,_Id],6) ->
	if
		MonId == 47917 ->
			erlang:send_after(1000, self(), pass_stage);
		true ->
			skip
	end,
	State;

%% 第七关 %%特殊关卡 护送士兵
do_stage_kill_mon(State,[MonId,_Id],7) ->
	if
		MonId == 47919 ->
			erlang:send_after(1000, self(), pass_stage);
		true ->
			skip
	end,
	State;

%% 第八关 
do_stage_kill_mon(State,[MonId,Id],8) ->
	if
		MonId == 47921 ->
			erlang:send_after(1000, self(), pass_stage);
		MonId == 47920 ->
			MonList = get_scene_mon_list(State),
			BossFilter = lists:filter(fun(Minfo) -> Minfo#ets_mon.mid == 47921 end, MonList),
			F_cancel = fun(Boss) ->
						{ok,BinData20201} = pt_20:write(20201, [Boss#ets_mon.id,Id,0]),
						lib_send:send_to_online_scene(Boss#ets_mon.scene, BinData20201)
					 end,
			lists:foreach(F_cancel, BossFilter);
		true ->
			skip
	end,
	State;

%% 第九关 
do_stage_kill_mon(State,[MonId,_Id],9) ->
	if
		MonId == 47924 ->
			erlang:send_after(1000, self(), pass_stage);
		true ->
			skip
	end,
	State;

%% 第十关 
do_stage_kill_mon(State,[MonId,_Id],10) ->
	MonList = get_scene_mon_list(State),
	FilterBoss = lists:filter(fun(Minfo) -> Minfo#ets_mon.mid == 47930 end, MonList),
	case length(FilterBoss) == 1 of
		true ->
			Boss = hd(FilterBoss),
			BossPid = Boss#ets_mon.pid;
		false ->
			BossPid = undefined
	end,
	if
		MonId == 47930 ->
			erlang:send_after(1000, self(), pass_stage);
		%% boss 技能失效
		MonId == 47929 andalso is_pid(BossPid) ->
			BossPid ! {'MON_SKILL_LOSE',10088};
		MonId == 47928 andalso is_pid(BossPid) ->
			BossPid ! {'MON_SKILL_LOSE',10087};
		MonId == 47927 andalso is_pid(BossPid) ->
			BossPid ! {'MON_SKILL_LOSE',10086};
		MonId == 47926 andalso is_pid(BossPid) ->
			BossPid ! {'MON_SKILL_LOSE',10085};
		MonId == 47925 andalso is_pid(BossPid) ->
			BossPid ! {'MON_SKILL_LOSE',10084};
		true ->
			skip
	end,
	State;

%% 第11关 
do_stage_kill_mon(State,[MonId,_Id],11) ->
	if
		MonId == 47932 ->
			erlang:send_after(1000, self(), pass_stage);
		true ->
			skip
	end,
	State;
do_stage_kill_mon(State,[_MonId,_Id],_) ->
	State.

%%真相大白
do_timer_stage(State) when State#state.stage == 40 ->
	Time = State#state.unixtime,
	if
		Time rem 2 == 0 ->
			case State#state.stage40_revive of
				false ->
					MonList = get_scene_mon_list(State),
					case length(MonList) == 1 of
						true ->
							MonInfo =  hd(MonList),
							NewState = 
							 if
								  MonInfo#ets_mon.mid == 47909 ->							 				  
									  erlang:send_after(1000, MonInfo#ets_mon.pid ,{'CHANGE_MON_ACTIVE',1}),
									  timer:apply_after(2000, gen_fsm, send_event, [MonInfo#ets_mon.pid, sleep]),
									  State#state{stage40_revive = true};
								  true ->
									  State
							  end,
							NewState;
						false ->
							State
					end;
				true ->
					State
			end;
		true ->
			State
	end;

%% 李牧叛变
do_timer_stage(State) when State#state.stage == 55 ->
	Time = State#state.unixtime,
	if
		State#state.finish == false , Time rem 5 == 0  ->
			self() ! {'REFRESH_NEW_MON_55'};
		true ->
			skip
	end,
	if
		State#state.l_pct_num == 70 andalso State#state.r_pct_num == 80 ->
			MonList = lib_scene:get_scene_mon(State#state.dungeon_scene_id),
			if
				length(MonList) == 0 andalso State#state.stage55_revive == false ->
					self() ! {'REFRESH_NEW_MON_55_BOSS'},
					NewState = State#state{stage55_revive =true};
				true ->
					NewState = State
			end;
		true ->
			NewState = State
	end,
	NewState;

%%MonList = get_scene_mon_list(State),
%% 	case length(MonList) > 0 of
%% 		true ->
%% 			Enemy = lists:filter(fun(Minfo) -> Minfo#ets_mon.mid /= 47933 end,MonList),
%% 			ExistsEnemy = length(Enemy) > 0,		
%% 			F_move = fun(MonInfo) ->
%% 							 if
%% 								 MonInfo#ets_mon.mid == 47933 andalso ExistsEnemy == false ->
%% 									erlang:send_after(4000, self(), {'MON_MOVE',MonInfo})
%% 								 true ->
%% 									 skip
%% 							 end
%% 					 end,
%% 			lists:foreach(F_move, MonList);
%% 		false ->
%% 			skip
%% 	end.
%%逐鹿之战
do_timer_stage(State) when State#state.stage == 60 ->
	Time = State#state.unixtime,
	TargetX = 5,
	TargetY = 12,
	StepY = 4,
	StepX = 2,
	case State#state.finish of
		false when Time rem 2 == 0 ->
			MonList =get_scene_mon_list(State),
			MonNum = length(MonList),
			SoldierList = lists:filter(fun(Minfo) -> Minfo#ets_mon.mid == 47933 end, MonList),
			SoldierNum = length(SoldierList),
			EnemyNum = MonNum - SoldierNum ,
			%%没有士兵则刷出下一波
			if
				SoldierNum == 0 andalso State#state.stage60_att_num < 6 ->
					self()  ! {'REFRESH_NEW_MON_60'};
				true ->
					skip
			end,
			%%士兵战斗or移动
			if
				EnemyNum > 0 ->
					So_num = State#state.stage60_so_num;
				true ->
					F_move = fun(Minfo,ReachNum) ->
							case is_process_alive(Minfo#ets_mon.pid) of
								true ->
									X = Minfo#ets_mon.x,
									Y = Minfo#ets_mon.y,
									DiffX = X - TargetX,
									DiffY = Y - TargetY,
									if
										DiffX > 0  ->
											case DiffX >= StepX of
												true ->
													NewX = X - StepX;
												false ->
													NewX = X -1
											end;
										DiffX < 0 ->
											case abs(DiffX) >= StepX of
												true ->
													NewX = X + StepX;
												false ->
													NewX = X + 1
											end;
										true ->
											NewX = TargetX
									end,
									if
										DiffY > 0 ->
											case DiffY >= StepY of
												true ->
													NewY = Y - StepY;
												false ->
													NewY = Y -1
											end;
										DiffY < 0 ->
											case abs(DiffY) >= StepY of
												true ->
													NewY = Y + StepY;
												false ->
													NewY = Y + 1
											end;
										true ->
											NewY = TargetY
									end,
									if
										X == 5 andalso Y == 12 ->
											kill_mon(Minfo),
											So_num = 1;
										true ->
											So_num = 0
									end,
									Minfo#ets_mon.pid ! {'MON_MOVIE',NewX,NewY},
									ReachNum + So_num;
								false ->
									ReachNum
							end
					end,
					NewReach = lists:foldl(F_move, 0, SoldierList),
					So_num = State#state.stage60_so_num + NewReach
			end,								 

			if
				State#state.stage60_att_num == 6  andalso Time rem 2 == 0 ->			
					case MonNum of
						0 ->
							erlang:send_after(1000, self(), pass_stage);
						_ ->				
							if
								SoldierNum > 0 ->
									skip;
								true ->
									erlang:send_after(1000, self(), pass_stage)
							end
					end;					
				true ->
					skip
			end;
		_ ->
			So_num = State#state.stage60_so_num
	end,
	State#state{stage60_so_num = So_num};

%% 空幻
do_timer_stage(State) when State#state.stage == 70 ->
	Time = State#state.unixtime,
	if
		Time rem 2 ==  0->
			Pattern = #player{scene = State#state.dungeon_scene_id ,_ ='_'},
			PlayerList = ets:match_object(?ETS_ONLINE_SCENE, Pattern),
			MonList = get_scene_mon_list(State),
			GetBoss = lists:filter(fun(B) -> B#ets_mon.mid == 47924 end, MonList),
			case length(GetBoss) > 0 of
				true ->
					Boss = hd(GetBoss),
					GetShadow = lists:filter(fun(P) -> P#player.other#player_other.shadow /= 0 end,PlayerList),
					ShadowNum = length(GetShadow),
					case ShadowNum > 0 of
						true ->
							Shadow = hd(GetShadow),
							Relation = [10,Shadow#player.id];
						_ ->
							Relation = []
					end,
					if
						ShadowNum > 0 andalso Boss#ets_mon.relation /= Relation ->
							Boss#ets_mon.pid ! {'CHANGE_MON_RELATION',Relation};
						true ->
							skip
					end;
				false ->
					skip
			end,
			State;
		true ->
			State
	end;
		

%% 旱神女魃
do_timer_stage(State) when State#state.stage == 80 ->
	Time = State#state.unixtime,
	PassTime = State#state.time,
	if
		Time rem 2 == 0 ->
			[X,Y] =
				case ets:lookup(?ETS_ONLINE_SCENE, State#state.player_id) of
					[Player|_] ->
						[Player#player.x,Player#player.y];
					[] ->
						[0,0]
				end,
			MonList = get_scene_mon_list(State),
			[MX,MY] =
				case length(MonList) > 0 of
					true ->
						F = fun(Minfo) ->
										Minfo#ets_mon.mid == 47932
							end,
						MonBoss = lists:filter(F, MonList),
						%%结晶怪对玩家加攻防
						MonCry = MonList -- MonBoss ,
						MonCryNum = length(MonCry),
						if
							MonCryNum > 0 ->
								AddAtt = MonCryNum * 1000 ,
								AddDef = MonCryNum * 500 ,
								BuffInfoList = [{castle_rush_att, AddAtt, Time + 5 , 90006, 0} ,{def, AddDef, Time + 5 , 90007, 0}],
								State#state.pid ! {'SET_BATTLE_STATUS', {7, BuffInfoList}};
							true ->
								skip
						end,
						case length(MonBoss) > 0 of
							true ->
								MonInfo = hd(MonBoss),
								[MonInfo#ets_mon.x,MonInfo#ets_mon.y];
							false ->
								[0,0]
						end;
					false ->
						[0,0]
				end,
			%% 30秒刷新结晶
			if
				Time rem 30 == 0 orelse Time rem 30 == 1 ->
					self() ! {'REFRESH_NEW_MON_80'};
				true ->
					skip
			end,
			%% 15秒转换风向
			WindDct = 
				if
					Time rem 15 == 0 orelse Time rem 15 == 1 ->
						util:rand(1, 4);
					true ->
						State#state.wind_dct
				end,
			if
					MX /= 0 andalso MY /= 0 ->
						if
							WindDct == 1 ->
								if
									X < MX  ->
										Hurt = true;
									true ->
										Hurt = false
								end;
							WindDct == 2 ->
								if
									Y < MY  ->
										Hurt = true;
									true ->
										Hurt = false
								end;
							WindDct == 3 ->
								if
									X > MX ->
										Hurt = true;
									true ->
										Hurt = false
								end;
							true ->
								if
									Y > MY ->
										Hurt = true;
									true ->
										Hurt = false
								end
						end;
					true ->%%boss 已死
						Hurt = false
			end,
			if
				PassTime > 19 ->
					spawn(fun()->
						{ok,WindBin} = pt_35:write(35017, [WindDct]),
						send_to_player(State#state.pid,WindBin)
					end),
					HurtState = State#state.burning,
					case Hurt of
						true when HurtState == false ->
							State#state.pid ! {'START_BURN_TIMER',1000,1000},
							SkillInfo = {burn, 0, Time + 1800 , 90005, 0},
							State#state.pid ! {'SET_BATTLE_STATUS', {7, [SkillInfo]}};
						false when HurtState == true ->
							State#state.pid ! {'TURN_OFF_BURN_TIMER'},
							SkillInfo = {burn, 0, Time +1 , 90005, 0},
							State#state.pid ! {'SET_BATTLE_STATUS', {7, [SkillInfo]}}; 
						_ ->
							skip
					end,
					State#state{wind_dct = WindDct ,burning = Hurt};
				true ->
					State
			end;
		true ->
			State
	end;




do_timer_stage(State) ->
	State.
		
%%清除副本怪物
clear_scene_mon(State) ->
	MonList = get_scene_mon_list(State),
	case length(MonList) > 0 of
		true ->
			F_c = fun(Mon) ->
						MonId = Mon#ets_mon.id,
						Mon#ets_mon.pid ! clear ,
						{ok, BinData} = pt_12:write(12082, [MonId, 0]),
						<<BinData/binary>>
				  end,
			BinData = tool:to_binary(lists:map(F_c, MonList)),
			send_to_player(State#state.pid,BinData);
		false ->
			skip
	end.

kill_mon(MonInfo) ->
	MonInfo#ets_mon.pid ! 'CLEAR_MON' ,
	ok.

%%获取场景怪物
get_scene_mon_list(State) ->
	SceneUniqueId = State#state.dungeon_scene_id,
	MS = ets:fun2ms(fun(M) when M#ets_mon.scene == SceneUniqueId, M#ets_mon.hp > 0 -> 
							M
					end),
	ets:select(?ETS_SCENE_MON, MS). 

%% 检测连斩数
check_ckills(Time) ->
	Kill_log = get(kill_log),
	{Ckills,LastKillTime} = get(ckills),
	F_k = fun({I_d,T},N) ->
				put(kill_log,lists:keydelete(I_d, 1, Kill_log)),
				if
					Time - T =< 5 ->
						N +1;
					true ->
						N
				end		
		  end,
	if
		Time - LastKillTime =< 5 ->
			NewCkills = lists:foldl(F_k, Ckills, Kill_log);
		true ->
			NewCkills = lists:foldl(F_k, -1, Kill_log)
	end,
	put(ckills,{NewCkills,Time}),
	NewCkills.

%% 获取连斩数 用于定时器检测是否清除buff
get_ckills(Time) ->
	case get(ckills) of
		undefined -> 
			0;
		{Ckills,LastTime} ->
			if
				Time - LastTime > 5 ->
					0;
				true ->
					Ckills
			end
	end.

%% 创建守卫刷新坐标xy
create_pos(Stage) ->
	if
		Stage == 55 ->
			Sx = 5,
			Sy = 21,
			Ex = 20,
			Ey = 38,
			F = fun(Y,List1) ->
						F2 = fun(X,List) ->
						 		{ok,[{X,Y}|List]}
							 end,
						{ok,List2} = util:for(Sx, Ex, F2, []),
						{ok,[lists:reverse(List2)| List1]}
				 end,
			{ok,L} = util:for(Sy, Ey, F, []),
			lists:flatten(lists:reverse(L));
		true ->
			[]
	end.
	  			
get_xy(State) ->
	case length(State#state.xy) > 0 of
		true ->
			{X,Y} = hd(State#state.xy),
			NewXY = lists:nthtail(1, State#state.xy),
			{State#state{xy = NewXY},{X,Y}};
		false ->
			{State,{0,0}}
	end.