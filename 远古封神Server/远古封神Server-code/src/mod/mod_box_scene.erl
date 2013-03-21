%%% -------------------------------------------------------------------
%%% Author  : xiaomai
%%% Description :诛邪副本
%%%
%%% Created : 2011-3-1
%%% -------------------------------------------------------------------
-module(mod_box_scene).

-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
%% 定时器1间隔时间(定时检查角色进程, 如果不在线，则关闭此进程)
-define(TIMER_1, 5*60*1000).
%% --------------------------------------------------------------------
%% External exports
-export([stop/0,
		 get_box_scene_pid/1,
		 handle_box_scene/2,
		 build_box_scene/2,
		 enter_box_scene/2,
		 quit_box_scene/1,
		 quit_box_scene/3,
		 kill_mon/4,
		 kill_spar/2,
		 get_outside_scene/1,
		 is_box_scene/1,
		 logout_box_scene/1%%此方法仅export，不提供对外调用（待定）
		]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {pid, sid, player_id, drop_id = 1}).

%% ====================================================================
%% External functions
%% ====================================================================
handle_box_scene(PlayerStatus, GoodsTypeId) ->
	lib_box_scene:handle_box_scene(PlayerStatus, GoodsTypeId),
	case data_scene:get(?BOX_SCENE_ONE_ID) of
		[] ->
			Content = <<"场景不存在！">>,
			 {ok, BinData} = pt_12:write(12005, [0, 0, 0, Content, 0, 0, 0, 0]),
			 lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
			 PlayerStatus;
		 Scene ->
			 #ets_scene{x = X, y = Y} = Scene,
			 {ok, BinData12} = pt_12:write(12005, [?BOX_SCENE_ONE_ID, X, Y, <<>>, ?BOX_SCENE_ONE_ID, 0, 0, 0]),
			 lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData12),
			 %%告诉原场景的玩家你已经离开
			 pp_scene:handle(12004, PlayerStatus, PlayerStatus#player.scene),
			 %%更新玩家新坐标
			 NewStatus = PlayerStatus#player{scene = ?BOX_SCENE_ONE_ID, x = X, y = Y},	
			 ValueList = [{scene,?BOX_SCENE_ONE_ID},{x,X},{y,Y}],
			 WhereList = [{id, NewStatus#player.id}],
			 db_agent:mm_update_player_info(ValueList, WhereList),
			 %%进入副本场景卸下坐骑
			 {ok, NewPlayerStatus} = lib_goods:force_off_mount(NewStatus),
			 NewPlayerStatus
	end.
		
%%玩家重新进入之前开辟的诛邪副本(只有在玩家断线后重新上线才会调用)
enter_box_scene(UniqueSceneId, Player) ->
	start_player_box_scene(UniqueSceneId, Player, {3, {}}, 0).
	
build_box_scene(Player, BoxScene) ->
%% 	BoxScene = lib_box_scene:get_box_scene(Player#player.id),
	Param = lib_box_scene:get_open_box_info(Player#player.id),
	{UniqueSceneId, X, Y} = lib_box_scene:get_box_scene_unique_id_xy(?BOX_SCENE_ID), 
	GoodsType = lib_box_scene:get_goods_type(BoxScene#ets_box_scene.goods_id),
	{ok, ScenePid} = start_player_box_scene(UniqueSceneId, Player, {0, Param}, GoodsType),
	NewPlayer = Player#player{scene = UniqueSceneId,
							  x = X,
							  y = Y,
							  other = Player#player.other#player_other{pid_scene = ScenePid}},
	NewPlayer.

quit_box_scene(Status) ->
	case get_outside_scene(Status) of
		false ->
			Status;
		{SceneId, X, Y} ->
			case data_scene:get(SceneId) of
				[] ->
					Name = <<"场景不存在!">>;
				Scene ->
					Name = Scene#ets_scene.name
			end,
			pp_scene:handle(12004, Status, Status#player.scene),
			%%告诉客户端新场景情况
			{ok, BinData} = pt_12:write(12005, 
										[SceneId, X, Y, Name, SceneId, 0, 0, 0]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			NewStatus = Status#player{scene = SceneId, x = X, y = Y},
			put(change_scene_xy , [X, Y]),%%做坐标记录
			NewStatus
	end.

get_outside_scene(Player) ->
	case lib_box_scene:is_box_scene_idsp(Player#player.scene, Player#player.id) of
		false ->
			false;
		true ->
			case lib_box_scene:get_box_scene_ets(Player#player.id) of
				[] ->
					false;
				[BoxScene|_] ->
					#ets_box_scene{x = X,
								   y = Y,
								   scene = SceneId} = BoxScene,
					{SceneId, X, Y}
			end
	end.
	
%% 杀怪
kill_mon(_SceneId, Pid, PlayerId, Mon) ->
	Pid ! {kill_mon, PlayerId, Mon#ets_mon.type, Mon#ets_mon.x, Mon#ets_mon.y}.

%%点水晶
kill_spar(Player, SparId) ->
	case lib_box_scene:is_box_scene_idsp(Player#player.scene, Player#player.id) of
		false ->
			{3, 0};
		true ->
			gen_server:call(Player#player.other#player_other.pid_scene, {kill_spar, Player, SparId})
	end.
logout_box_scene(Player) ->
	{ok, ScenePid} = get_box_scene_pid(Player),
	ScenePid ! {logout, Player#player.scene, Player#player.id}.

quit_box_scene(ScenePid, PlayerId, SceneId) ->
	ScenePid ! {quit_scene, SceneId, PlayerId}.
	
%% ====================================================================
%% Server functions
%% ====================================================================
start_player_box_scene(UniqueSceneId, Player, BuildType, GoodsType) ->
	gen_server:start(?MODULE, [UniqueSceneId, ?BOX_SCENE_ID, Player, BuildType, GoodsType], []).

stop() ->
    gen_server:call(?MODULE, stop).
%%获取诛邪副本pid
get_box_scene_pid(Player) ->
	UniqueSceneId = Player#player.scene,
	ProcessName = misc:create_process_name(scene_p, [UniqueSceneId, 0]),
	case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
%% 				io:format("the process is built:~p\n", [Pid]),
				{ok, Pid};
			_OtherPid ->
%% 				io:format("OMG, the process is no built:~p\n", [_OtherPid]),
%% 				{PlayerPurpleNum, OpenCounter, PurpleTimeType, GoodsTraceInit} = {0, 0, 0, []},
				PupleETList = [],
				PurpleEList = {0, PupleETList},
				Param = {0, 0, 0, [], PurpleEList},
				start_player_box_scene(UniqueSceneId, Player, {0,Param}, 1)
	end.

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([UniqueSceneId, SceneId, Player, BuildType, GoodsType]) ->
	ProcessName = misc:create_process_name(scene_p, [UniqueSceneId, 0]),
	process_flag(trap_exit, true),	
	misc:register(global, ProcessName, self()), %% 多节点的情况下， 仅启用一个对应的氏族进程
%% 	lib_scene:copy_scene(UniqueSceneId, SceneId),  %% 复制场景
%% 	io:format("init start....\n"),
	case lib_box_scene:build_box_scene(UniqueSceneId, SceneId, Player, BuildType, GoodsType) of
		fail ->
			case BuildType of
				{3, _ErParam} ->
%% 					io:format("111\n"),
					skip;
				_ ->
%% 					io:format("222\n"),
					Msg = <<"数据出错，进入诛邪副本失败！囧">>,
			{ok, BinData} = pt_12:write(12005, [0, 0, 0, Msg, 0, 0, 0, 0]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
			end;
		{Name, UniqueSceneId, X, Y, _Num} ->
			case BuildType of
				{3, _ErParam} ->
%% 					io:format("333\n"),
					skip;
				_->
%% 					io:format("444\n"),
%% 					io:format("go into the scene\n"),
					{ok, BinData} = pt_12:write(12005, [UniqueSceneId, X, Y, Name, ?BOX_SCENE_ID, 0, 0, 0]),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
					%%告诉原场景的玩家你已经离开
					pp_scene:handle(12004, Player, Player#player.scene)
			end
	end,
%% 	io:format("init.... ok\n"),
	State = #state{pid = Player#player.other#player_other.pid,
				   sid = UniqueSceneId,
				   player_id = Player#player.id},
	misc:write_monitor_pid(self(),?MODULE, {State}),
	%%定时检查玩家是否已经下线了
	erlang:send_after(?TIMER_1, self(), {check_player_pid}),
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
	%% ?DEBUG("****************mod_box_apply_call:[~p,~p]*********", [Module, Method]),
	Reply = 
		case (catch apply(Module, Method, Args)) of
			{'EXIT', Info} ->
				?WARNING_MSG("mod_box_apply_call: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
				error;
			DataRet -> DataRet
		end,
	{reply, Reply, State};

%%拾取水晶
handle_call({kill_spar, Player, SparId}, _From, State) ->
	Reply = 
	case lib_box_scene:get_box_scene_ets(Player#player.id) of
		[] ->
			{0, 0};
		[BoxScene|_] ->
			case lists:keyfind(SparId, #ets_spar.spar_id, BoxScene#ets_box_scene.glist) of
				false ->
					{4, 0};
				Spar ->
					GoodsTypeId = Spar#ets_spar.goods_id,
					GoodsTypeInfo = goods_util:get_goods_type(GoodsTypeId),
					if 
						is_record(GoodsTypeInfo, ets_base_goods) =:= false ->
							{0, 0};
						true ->
							#ets_base_goods{type = Type,
											subtype = SubType} = GoodsTypeInfo,
							if Type == 25 andalso (SubType == 12 orelse SubType == 13) ->
								   Bind = 2;%%特殊物品，绑定
							   true ->
								   Bind = 0%%其他的，不绑定
							end,
							case catch (gen_server:call(Player#player.other#player_other.pid_goods, 
														{'give_goods',Player,GoodsTypeId,1,Bind})) of
								ok ->%%添加成功
									NewGlist = lists:keydelete(SparId, #ets_spar.spar_id, BoxScene#ets_box_scene.glist),
									NewBoxScene = BoxScene#ets_box_scene{glist = NewGlist},
									lib_box_scene:insert_box_scene_ets(NewBoxScene),
									GoodsList = util:term_to_string(NewBoxScene#ets_box_scene.glist),
									ValueList = [{glist, GoodsList}],
									db_agent:update_box_scene(ValueList, Player#player.id),
									%%广播
									spawn(lib_box_scene, broad_scene_goods, [GoodsTypeId, Player, Spar#ets_spar.type]),
									{1, GoodsTypeId};
								Error ->
									ErrorType = lib_box_scene:get_error_type(Error),
									{ErrorType, 0}
							end
					end
			end
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
%% 	%% ?DEBUG("mod_scene_apply_cast: [~p/~p/~p]", [Module, Method, Args]),	
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

handle_cast(_Msg, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%%诛邪副本杀怪
handle_info({kill_mon, PlayerId, _Mon, MonType, MX, MY}, State) ->
    case MonType of
        4 ->%%一般副本怪物
            case lib_box_scene:get_box_scene_ets(PlayerId) of
                [] ->
                    skip;
                [BoxScene|_] ->
                    NewMList = lists:keydelete({MX, MY}, #ets_box_mon.coord, BoxScene#ets_box_scene.mlist),
                    NewMonList = util:term_to_string(NewMList),
                    NewBoxScene = BoxScene#ets_box_scene{mlist = NewMList},
                    ValueList = [{mlist, NewMonList}],
                    db_agent:update_box_scene(ValueList, PlayerId),
                    lib_box_scene:insert_box_scene_ets(NewBoxScene)
            end;
        _ ->
            skip
    end,
	{noreply, State};
					
%%玩家点击npc，退出副本
handle_info({quit_scene, SceneId, PlayerId}, State) ->
	lib_scene:clear_scene(SceneId),%%清场景数据
	lib_box_scene:delete_box_scene_ets(PlayerId),
	{stop, normal,State};

%%玩家下线，清场景
handle_info({logout, SceneId, PlayerId}, State) ->
	lib_scene:clear_scene(SceneId),%%清场景数据
	lib_box_scene:delete_box_scene_ets(PlayerId),
	{stop, normal,State};

%%检查进程是否存活，否认关闭副本进程
handle_info({check_player_pid},State) ->
	case misc:is_process_alive(State#state.pid) of
		true ->
%% 			io:format("wait..~p\n", [self()]),
			erlang:send_after(?TIMER_1, self(), {check_player_pid}),
			{noreply, State};
		_ ->
%% 			io:format("kill now.~p\n", [self()]),
			lib_scene:clear_scene(State#state.sid),
			lib_box_scene:delete_box_scene_ets(State#state.player_id),
			{stop, normal,State}
	end;

handle_info(_Info, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
%% 	io:format("terminate:~p\n", [self()]),
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
is_box_scene(Player) ->
	#player{id = PlayerId,
			scene = SceneId,
			x = X,
			y = Y} = Player,
	case lib_box_scene:get_box_scene_id(SceneId) of
		?BOX_SCENE_ID ->%%旧秘境
			lib_box_scene:put_data_into_box_ets(PlayerId),
			[?BOX_SCENE_ID, X, Y];
		?BOXS_PIECE_ID ->%%新秘境 
			lib_box_scene:put_data_into_box_ets(PlayerId),
			[?BOXS_PIECE_ID, X, Y];
		_ ->
			false
	end.
			
