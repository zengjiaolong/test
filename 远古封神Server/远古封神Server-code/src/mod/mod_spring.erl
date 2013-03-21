%%% -------------------------------------------------------------------
%%% Author  : xianrongMai
%%% Description :温泉模块gen_server
%%%
%%% Created : 2011-8-2
%%% -------------------------------------------------------------------
-module(mod_spring).

-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("hot_spring.hrl").
%% --------------------------------------------------------------------
%% External exports
-export([leave_spring/4,	%%离开温泉
		 init_spring/1,		%%初始化温泉
		 get_spring_pid/1, 	%%获取温泉的Pid
		 enter_spring/2,	%%进入温泉
		 spring_faces/5,	%% 12052 温泉动作操作
		 stop/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {type = 0,	%%温泉类型
				lotuses = [],	%%莲花的坐标{{X,Y}, 颜色}
				count = 0,
				viptop = [],		%%钻石VIP泉水里的玩家
				vipnormal = [],		%%一般VIP泉水里的玩家
				public = []			%%大众泉水里的玩家
				}).
%%lotuses的元素
-record(lotus, {coord = {0,0},
				elem = []	%%玩家信息{Time, Pid}
				}).
-define(LOUTS_MAX_DIST, 2).%%玩家与莲花的最大距离

%% ====================================================================
%% External functions
%% ====================================================================
%% -----------------------------------------------------------------
%% 12054 进入温泉
%% -----------------------------------------------------------------
enter_spring(Status, Type) ->
	lib_spring:enter_spring(Status, Type).

%% ====================================================================
%% Server functions
%% ====================================================================
%%初始化温泉
init_spring([Type, EndTime]) ->
%% 	ProcessName = misc:create_process_name(scene_p, [Type, 0]),
%% 	gen_server:start_link({local, ProcessName}, ?MODULE, [Type, EndTime], []).
	gen_server:start(?MODULE, [Type, EndTime], []).
stop() ->
	gen_server:call(?MODULE, stop).

%%获取温泉的pid
get_spring_pid(Type) ->
	ProcessName = misc:create_process_name(scene_p, [Type, 0]),
	case misc:whereis_name({global, ProcessName}) of
		Pid when is_pid(Pid) ->
%% 			?DEBUG("THE PROCESS IS BUILD", []),
			{ok, Pid};
		_Other ->
%% 			?DEBUG("OMG THE PROCESS IS NOT BUILD, ~p", [_Other]),
			{error}
	end.

%% -----------------------------------------------------------------
%% 12052 温泉动作操作
%% -----------------------------------------------------------------
spring_faces(Self, Site, Status, RecId, Face) ->
	gen_server:cast(Status#player.other#player_other.pid_scene,
					{'SPRING_FACES', 
					 Self, Status#player.other#player_other.pid_send,
					 Site,Status#player.id, Status#player.nickname,
					 RecId, Face}).

%% -----------------------------------------------------------------
%% 12056 离开温泉
%% -----------------------------------------------------------------
leave_spring(PlayerId, SceneId,PidScene,Pid) ->
	case lib_spring:is_spring_scene(SceneId) of
		false ->%%不在温泉里，直接把信息扔了
			skip;
		true ->%%在温泉中
			PidScene ! {leave_spring, PlayerId, Pid}
	end.
			
%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([Type, EndTime]) ->
	process_flag(trap_exit, true),
	Self = self(),%%场景进程Pid
	ProcessName = misc:create_process_name(scene_p, [Type, 0]),
	case misc:register(unique, ProcessName, Self) of
		yes ->
			ets:new(?SPRING_TABLE, [{keypos, #p_info.player_id}, named_table, public, set,?ETSRC, ?ETSWC]),
			%% 复制场景
			lib_scene:copy_scene(Type, Type),
%% 			?DEBUG("11111 init the scene :~p, ~p, ~p", [Type, EndTime, Self]),
			misc:write_monitor_pid(Self, ?MODULE, {Type}),
			State = #state{type = Type},
			erlang:send_after(EndTime*1000, Self, {'ENG_SPRING', Type}),
			%%开启清理泉水里的过期玩家Ids定时器, 10秒一循环
			erlang:send_after(10000, self(), {'CLEAR_HOTSPRING_WATER_DUST', Type}),
%% 			产生种子
%% 			{MegaSecs, Secs, MicroSecs} = now(),
%% 			random:seed({MegaSecs, Secs, MicroSecs}),
%% 			erlang:send_after(60*1000, Self, {'LOTUS_BLOOM', 1}),%%一分钟后莲花开放(莲花不开了)
%%			?DEBUG("22222 init the scene :~p, ~p, ~p", [Type, EndTime, Self]),
			{ok, State};
		_ ->
%% 			?DEBUG("OMG,THE proce has been on", []),
			misc:register(global, ProcessName, Self),
			ets:new(?SPRING_TABLE, [{keypos, #p_info.player_id}, named_table, public, set,?ETSRC, ?ETSWC]),
			%% 复制场景
			lib_scene:copy_scene(Type, Type),
%% 			?DEBUG("11111 init the scene :~p, ~p, ~p", [Type, EndTime, Self]),
			misc:write_monitor_pid(Self, ?MODULE, {Type}),
			State = #state{type = Type},
			erlang:send_after(EndTime*1000, Self, {'ENG_SPRING', Type}),
			%%开启清理泉水里的过期玩家Ids定时器, 10秒一循环
			erlang:send_after(10000, self(), {'CLEAR_HOTSPRING_WATER_DUST', Type}),
%% 			产生种子
%% 			{MegaSecs, Secs, MicroSecs} = now(),
%% 			random:seed({MegaSecs, Secs, MicroSecs}),
%% 			erlang:send_after(60*1000, Self, {'LOTUS_BLOOM', 1}),%%一分钟后莲花开放(莲花不开了)
%%			?DEBUG("22222 init the scene :~p, ~p, ~p", [Type, EndTime, Self]),
			{ok, State}
	end.

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
%% 	?DEBUG("mod_scene_apply_call: [~p/~p/~p]", [Module, Method, Args]),	
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_scene_apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
			 error;
		 DataRet -> DataRet
	end,
    {reply, Reply, State};

%%采集莲花
handle_call({'COLLECT_LOTUS', PlayerId, Coord,{PX, PY, SceneId}}, _From, State) ->
	#state{lotuses = Lotuses,
		   type = SpriId} = State,
	Reply = 
		case lists:keyfind(Coord, #lotus.coord, Lotuses) of
			false ->
				NewState = State,
				{fail, 3};%%莲花不存在
			Lotus ->
				#lotus{coord = {LX,LY}} = Lotus,
				DX = abs(LX-PX),
				DY = abs(LY-PY),
				case DX =< ?LOUTS_MAX_DIST andalso DY =< ?LOUTS_MAX_DIST andalso SceneId =:= SpriId of
					true ->%%距离判断(少于2格，场景合法)
						Players = Lotus#lotus.elem,
						case lists:keyfind(PlayerId, 2,Players) of
							false ->
								NewPlayers = [{?LOTUS_COLLECT_TIME, PlayerId}|Players],
								NewLotus = Lotus#lotus{elem = NewPlayers},
								NewLotuses = lists:keyreplace(Coord, #lotus.coord, Lotuses, NewLotus),
								NewState = State#state{lotuses = NewLotuses},
								{ok, 1};
							{_Time, PlayerId} ->
								NewState = State,
								{fail, 5}%%已经在采集中
						end;
					false ->%%距离太远
						NewState = State,
						{fail,2}
				end
		end,
	{reply, Reply, NewState};
			
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
%% 	?DEBUG("mod_scene_apply_cast: [~p/~p/~p]", [Module, Method, Args]),	
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_scene_apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
			 error;
		 _ -> ok
	end,
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

%%玩家进入温泉，做标识
handle_cast({'PLAYER_ENTER_SPRING', RoleInfo, Type}, State) ->
	{PidSend, PlayerId, PlayerName, Vip} = RoleInfo,
	case ets:lookup(?SPRING_TABLE, PlayerId) of
		[] ->
			Num = lib_spring:get_faces(Vip),%%获取玩家能够戏水的次数
			Faces = lib_spring:make_faces_num(Num),
			PInfo = #p_info{player_id = PlayerId,
								   spring = Type, %%524：皇家，525：大众
								   name = PlayerName,
								   cd = 0,
								   faces = Faces};
		[OPInfo|_] ->
			PInfo = OPInfo#p_info{spring = Type} %%524：皇家，525：大众
								  
	end,
	ets:insert(?SPRING_TABLE, PInfo),
	%%发表情剩余数量
	Now = util:unixtime(),
	Cd = ?SPRING_FACE_CD - (Now - PInfo#p_info.cd),
%% 			?DEBUG("cd:~p,~p,~p", [Cd,PInfo#p_info.cd, Now]),
	CD = 
		case Cd > 0 of
			true ->
				Cd;
			false ->
				0
		end,
	{ok, BinDatra12055} = pt_12:write(12055, [CD, PInfo#p_info.faces]),
	lib_send:send_to_sid(PidSend, BinDatra12055),%%网客户端发送表情剩余次数
	#state{lotuses = Lotuses} = State,
			Coords = lists:map(fun(Elem) ->
									   Elem#lotus.coord
							   end, Lotuses),
%% 			SceneId = lib_spring:get_spring_scene(SpriType),%%获取温泉场景ID
			%%全场景广播莲花的开放
			{ok, BinData12060}  = pt_12:write(12060, [Coords]),
			lib_send:send_to_sid(PidSend, BinData12060),
	{noreply, State};


handle_cast({'GET_SPRING_FACES', PlayerId, PidSend}, State) ->
	case ets:lookup(?SPRING_TABLE, PlayerId) of
		[] ->
			skip;
		[PInfo|_] ->
			Now = util:unixtime(),
			Cd = ?SPRING_FACE_CD - (Now - PInfo#p_info.cd),
%% 			?DEBUG("cd:~p,~p,~p", [Cd,PInfo#p_info.cd, Now]),
			CD = 
				case Cd > 0 of
					true ->
						Cd;
					false ->
						0
				end,
			{ok, BinDatra12055} = pt_12:write(12055, [CD, PInfo#p_info.faces]),
			lib_send:send_to_sid(PidSend, BinDatra12055),%%网客户端发送表情剩余次数
			#state{lotuses = Lotuses} = State,
			Coords = lists:map(fun(Elem) ->
									   Elem#lotus.coord
							   end, Lotuses),
%% 			SceneId = lib_spring:get_spring_scene(SpriType),%%获取温泉场景ID
			%%全场景广播莲花的开放
			{ok, BinData12060}  = pt_12:write(12060, [Coords]),
			lib_send:send_to_sid(PidSend, BinData12060)
	end,
	{noreply, State};
		
%%玩家离开温泉
handle_cast({'PALYER_LEAVE_SPRING', PlayerId}, State) ->
	case ets:lookup(?SPRING_TABLE, PlayerId) of
		[] ->
			skip;
		[OPInfo|_] ->
			PInfo = OPInfo#p_info{spring = 0},
			ets:insert(?SPRING_TABLE, PInfo)
	end,
%% 	%%%如果在采集莲花，就直接删除采集的数据
%% 	NewState = cancel_collect_lotus(State, PlayerId),
	%%删除多余的数据
	DeleteState = 
		State#state{viptop = lists:delete(PlayerId, State#state.viptop),				%%钻石VIP泉水里的玩家
					vipnormal = lists:delete(PlayerId, State#state.vipnormal),		%%一般VIP泉水里的玩家
					public = lists:delete(PlayerId, State#state.public)				%%大众泉水里的玩家
				   },
	{noreply, DeleteState};
	
%%清理玩家的采集莲花轮询队列中的位置
handle_cast({'CANCEL_COLLECT_LOTUS', PlayerId}, State) ->
	%%清掉采集的数据
	NewState = cancel_collect_lotus(State, PlayerId),
	{noreply, NewState};

handle_cast({'HOTSPRING_SITE_CHANGE', Pid, NewSite}, State) ->
	DeleteState = State#state{viptop = lists:delete(Pid, State#state.viptop),		%%钻石VIP泉水里的玩家
							  vipnormal = lists:delete(Pid, State#state.vipnormal),		%%一般VIP泉水里的玩家
							  public = lists:delete(Pid, State#state.public)			%%大众泉水里的玩家
							 },
	NewState = 
		case NewSite of
			1 ->
				DeleteState;
			2 ->
				DeleteState#state{viptop = [Pid|DeleteState#state.viptop]};
			3 ->
				DeleteState#state{vipnormal = [Pid|DeleteState#state.vipnormal]};
			4 ->
				DeleteState#state{public = [Pid|DeleteState#state.public]};
			_ ->
				DeleteState
		end,
	{noreply, NewState};
		

handle_cast({'SPRING_FACES', Self, SelfPidSend, Site, SendId, SendName, RecId, Face}, State) ->
	Reply = 
	case ets:lookup(?SPRING_TABLE, SendId) of
		[] ->
			0;
		[SPInfo|_S] ->
			Now = util:unixtime(),
			#p_info{cd = CD,
					faces = Faces,
					spring = SSpri} = SPInfo,
			Diff = Now - CD,
			Num = lists:nth(Face, Faces),
			if
				Diff =< ?SPRING_FACE_CD andalso CD =/= 0->
					2;
				Num =< 0 ->
					3;
				true ->%%可以发送
					case ets:lookup(?SPRING_TABLE, RecId) of
						[] ->
							0;
						[RPInfo|_R] ->
							#p_info{name = RecName,
									spring = RSpri} = RPInfo,
							case RSpri =:= SSpri of
								true ->
									Data = [SendId, SendName, RecId, RecName, Face],
									 case lib_player:get_player_pid(RecId) of
										 [] ->
											 6;
										 Pid ->
											 IsSameSite = 
												 case Site of
													 2 ->
														 lists:member(RecId, State#state.viptop);
													 3 ->
														 lists:member(RecId, State#state.vipnormal);
													 4 ->
														 lists:member(RecId, State#state.public);
													 _ ->
														 false
												 end,
											 case IsSameSite of
												 true ->
													 Pid ! {'SPRING_FACES_ADD_EXPSPI',[SendName]},%%发送信息 + 经验
													 {ok, Data12056} = pt_12:write(12056, Data),%%局部更新
													 spawn(fun() -> mod_scene_agent:send_to_scene(SSpri, Data12056) end),
													 NewFaces = tool:replace(Faces, Face, Num -1),%%生成新的faces
													 NewSPInfo = SPInfo#p_info{faces = NewFaces,
																			   cd = Now},
													 ets:insert(?SPRING_TABLE, NewSPInfo),
													 {1,RecName};
												 false ->
													 7
											 end
									end;
								false ->
									7
							end
					end
			end
	end,
%% 	?DEBUG("Reply:~p", [Reply]),
	case Reply of
		{1,NRecName} ->
			Self ! {'SPRING_FACES_ADD_EXPSPI',[NRecName]}, %%开启温泉经验定时器
			{ok, NBinData12052} = pt_12:write(12052, [1]),
			lib_send:send_to_sid(SelfPidSend, NBinData12052),
			ok;
		_ ->
			{ok, NBinData12052} = pt_12:write(12052, [Reply]),
			lib_send:send_to_sid(SelfPidSend, NBinData12052),
			ok
	end,
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
%%温泉莲花开放
handle_info({'LOTUS_BLOOM', Count}, State) ->
%%	?DEBUG("lotuses are : ~p", [State#state.lotuses]),
	case lib_lotus:check_spring_time() of%%添加时间的判断
		true ->
			#state{lotuses = Lotuses,
				   type = SceneId} = State,
			Len = length(Lotuses),
			case Len >= ?LOTUS_MAX_NUM of
				true ->
					NewState = State;
				false ->
					Num = ?LOTUS_MAX_NUM - Len,%%需要开放Num朵莲花
					Coords = lists:map(fun(Elem) ->
											   Elem#lotus.coord
									   end, Lotuses),
					List = lists:seq(1,Num),
					SpriType = lib_spring:get_spring_type(SceneId),%%获取场景所对应的Id,VIP:1,NORMAL:2
					LotusCoords = lists:nth(SpriType, ?LOTUS_COORDS),%%获取对应的坐标s
					NewCoords = lib_lotus:random_lotus(Num, Coords, [], LotusCoords),%%产生需要的莲花坐标
					{BLotuses, NLotuses, _ECoords} =
						lists:foldl(fun(_Elem, AccIn) ->
											{EBLotus, ENLotus, ECoords} = AccIn,
											[{RX, RY}|ResCoords] = ECoords,
											NewLotus = #lotus{coord = {RX,RY},
															  elem = []},
											{[{RX, RY}|EBLotus], [NewLotus|ENLotus], ResCoords}
									end, {[], Lotuses, NewCoords}, List),
					%%全场景广播莲花的开放
					{ok, BinData12060} = pt_12:write(12060, [BLotuses]),
%% 					?DEBUG("the scene is :~p", [SceneId]),
					spawn(fun() -> mod_scene_agent:send_to_scene(SceneId, BinData12060) end),
					%%广播(把工作付给VIP温泉做)
					case Num >= 1 andalso SceneId =:= ?SPRING_SCENE_VIPTOP_ID of
						true ->
							Msg = io_lib:format("哇！<font color='#FFFFFF'>温泉</font>里的<font color='#FF9DCC'>七彩莲花</font>刷新了哦，亲。采集莲花可以获得丰厚的奖励哦，亲。",[]),
							spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg) end);
						false ->
							skip
					end,						
					erlang:send_after(1000, self(), {'LOTUS_PLAYER_FLUSH', Count+1}),%%一秒钟的轮询开始
					erlang:send_after(?LOTUS_PLAYERS_FLUSH_TIME, self(), {'LOTUS_PLAYERS_FLUSH', Count+1}),%%700毫秒后开始 轮询 ，清理垃圾的数据
					NewState = State#state{lotuses = NLotuses,
										   count = Count+1}
			end,
			case Count >= ?LOTUS_COUNT_NUM of
				true ->
					skip;
				false ->
					erlang:send_after(?LOTUS_TIMESTAMP, self(), {'LOTUS_BLOOM', Count+1})%%五分钟后莲花开放
			end,
			{noreply, NewState};
		false ->
			{noreply, State}
	end;
			
			
%%温泉莲花的一秒秒轮询
handle_info({'LOTUS_PLAYER_FLUSH', Count}, State) ->
	case lib_lotus:check_spring_time() of%%添加时间的判断
		true ->
			#state{lotuses = Lotuses,
				   count = OldCount,
				   type = SceneId} = State,
			case Count =:= OldCount of
				false ->%%这个定时器作废了，不用
					NewState = State;
				true ->
					NewLotuses = 
						lists:foldr(fun(Elem, AccIn) ->
											#lotus{coord = ECoord,
												   elem = Players} = Elem,
											NewPlayers = 
												lists:map(fun(PElem) ->
																  {Time, Pid} = PElem,
																  {Time - 1, Pid}
														  end, Players),
											case lists:keyfind(0, 1, NewPlayers) of
												false ->
													NewLotus = Elem#lotus{elem = NewPlayers},
													[NewLotus|AccIn];
												{_Time, PlayerId} ->%%应该有人拿到了
													lib_lotus:reset_player_lotus(Players),%%通知复位玩家的状态
%% 													SceneId = lib_spring:get_spring_scene(SpriType),%%获取温泉场景ID
													%%全场景广播莲花的消失
													{ok, BinData12059} = pt_12:write(12059, [ECoord]),
													spawn(fun() -> mod_scene_agent:send_to_scene(SceneId, BinData12059) end),
													lib_lotus:give_lotus(PlayerId),%%给玩家物品并且广播所获得的物品奖励
													AccIn
											end
									end, [], Lotuses),
					case length(NewLotuses) =:= 0 of
						true ->%%已经不用再轮询了
							skip;
						false ->
							erlang:send_after(1000, self(), {'LOTUS_PLAYER_FLUSH', Count})	%%继续一秒秒的轮询
					end,
					NewState = State#state{lotuses = NewLotuses}
			end,
			{noreply, NewState};
		false ->
			{noreply, State}
	end;

%%轮询 ，清理垃圾的数据
handle_info({'LOTUS_PLAYERS_FLUSH', Count}, State) ->
	case lib_lotus:check_spring_time() of%%添加时间的判断
		true ->
			#state{lotuses = Lotuses,
				   count = OldCount,
				   type = SpriId} = State,
			case Count =:= OldCount of
				true ->
					NewLotuses = 
						lists:map(
						  fun(Elem) ->
								  Players = Elem#lotus.elem,
								  NewPlayers = 
									  lists:foldr(
										fun(ElemIn, AccIn) ->
												{_Time, PlayerId} = ElemIn,
												case ets:lookup(?SPRING_TABLE, PlayerId) of
													[] ->%%人已经不在
														AccIn;
													[PInfo|_] ->%%人物在温泉的数据是否正确
														SceneId = PInfo#p_info.spring,
%% 														SpriId = lib_spring:get_spring_scene(SpriType),
														case lib_player:is_online(PlayerId) andalso SceneId =:= SpriId of
															true ->%%人物在线，并且是在正确的温泉里
																[ElemIn|AccIn];
															false ->
																AccIn
														end
												end
										 end, [], Players),
								  Elem#lotus{elem = NewPlayers}
						  end,Lotuses),
					NewState = State#state{lotuses = NewLotuses},
					case NewLotuses of
						[] ->%%本次的莲花已经被采集完了，不用再轮询了
							skip;
						_ ->
							erlang:send_after(?LOTUS_PLAYERS_FLUSH_TIME, self(), {'LOTUS_PLAYERS_FLUSH', Count})%%继续轮询
					end,
					{noreply, NewState};
				false ->%%这个定期器不用了，已经在用新的啦
					{noreply, State}
			end;
		false ->
			{noreply, State}
	end;
			
%%玩家离开温泉
handle_info({leave_spring, PlayerId, Pid}, State) ->
	case ets:lookup(?SPRING_TABLE, PlayerId) of
		[] ->
			skip;
		[OPInfo|_] ->
%% 			?DEBUG("leave scene", []),
			PInfo = OPInfo#p_info{spring = 0},
			ets:insert(?SPRING_TABLE, PInfo)
	end,
	gen_server:cast(Pid, {leave_spring}),
	%%删除多余的数据
	DeleteState = 
		State#state{viptop = lists:delete(PlayerId, State#state.viptop),				%%钻石VIP泉水里的玩家
					vipnormal = lists:delete(PlayerId, State#state.vipnormal),		%%一般VIP泉水里的玩家
					public = lists:delete(PlayerId, State#state.public)				%%大众泉水里的玩家
				   },
	{noreply, DeleteState};


%%清温泉场景的人
handle_info({'ENG_SPRING', Type}, State) ->
	%%广播关图标通知
%% 	lib_spring:broadcast_spring_time(0),
%% 	?DEBUG("END THE SPRING", []),
%% 	RoleList = ets:tab2list(?SPRING_TABLE),
%% 	lists:foreach(fun(Elem) ->
%% 						  PlayerId = Elem#p_info.player_id,
%% 						  db_agent:update_join_data(PlayerId, spring),%%玩家的温泉参与度统计
%% %% 						  ?DEBUG("Id:~p, ", [PlayerId]),
%% 						  case lib_player:get_player_pid(PlayerId) of
%% 							  [] ->
%% %% 								  ?DEBUG(" []", []),
%% 								  skip;
%% 							  Pid ->
%% %% 								  ?DEBUG("Pid:~p", [Pid]),
%% 								  gen_server:cast(Pid, {'SEND_OUT_SPRING'})
%% 						  end
%% 				   end, RoleList),%%T人
	mod_scene_agent:send_to_scene_for_event(Type, {'SEND_OUT_SPRING'}),
	erlang:send_after(300000, self(), {'END_SPRING_PRO', Type}),%%开始清理场景的定时器(300秒的延时)
	{noreply, State};
	

handle_info({'END_SPRING_PRO', Type}, State) ->
	lib_scene:clear_scene(Type),%%清场景数据
%% 	?DEBUG("end the spring scene", []),
	%%删除场景的ets表
	ets:delete(?SPRING_TABLE),
	{stop, normal, State};
%%清理温泉里的泉水垃圾
handle_info({'CLEAR_HOTSPRING_WATER_DUST', Type}, State) ->
	#state{viptop = VipTop,				%%钻石VIP泉水里的玩家
		   vipnormal = VipNormal,		%%一般VIP泉水里的玩家
		   public = Public				%%大众泉水里的玩家
		  } = State,
	NVipTop = lists:foldl(fun(EVipTop, VT) ->
								  case lib_player:get_player_pid(EVipTop) of
									  [] ->
										  VT;
									  _VTPid ->
										 [EVipTop|VT]
								  end
						  end, [], VipTop),
	NVipNormal = lists:foldl(fun(EVipNormal, NT) ->
								  case lib_player:get_player_pid(EVipNormal) of
									  [] ->
										  NT;
									  _NTPid ->
										 [EVipNormal|NT]
								  end
						  end, [], VipNormal),
	NPublic = lists:foldl(fun(EPublic, B) ->
								  case lib_player:get_player_pid(EPublic) of
									  [] ->
										  B;
									  _BPid ->
										 [EPublic|B]
								  end
						  end, [], Public),
	NState = State#state{viptop = NVipTop,				%%钻石VIP泉水里的玩家
						 vipnormal = NVipNormal,		%%一般VIP泉水里的玩家
						 public = NPublic				%%大众泉水里的玩家
						},
	ProcessName = misc:create_process_name(scene_p, [Type, 0]),
	misc:register(global, ProcessName, self()),
%% 	?DEBUG("ProcessName:~p, self:~p", [ProcessName, self()]),
	erlang:send_after(10000, self(), {'CLEAR_HOTSPRING_WATER_DUST', Type}),%%10秒一循环
	{noreply, NState};
	
handle_info(_Info, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()),
	misc:delete_system_info(self()),
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% --------------------------------------------------------------------
%%% Internal functions
%% --------------------------------------------------------------------
%%清理多余的玩家
cancel_collect_lotus(State, PlayerId) ->
	#state{lotuses = Lotuses} = State,
	NewLotuses = 
		lists:map(fun(Elem) ->
						  Players = Elem#lotus.elem,
						  NewPlayers = lists:keydelete(PlayerId, 2, Players),
						  Elem#lotus{elem = NewPlayers}
				  end, Lotuses),
	State#state{lotuses = NewLotuses}.
