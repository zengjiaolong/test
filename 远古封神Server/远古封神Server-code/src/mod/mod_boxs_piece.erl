%%% -------------------------------------------------------------------
%%% Author  : Xianrong.Mai
%%% Description :新的秘境副本
%%%
%%% Created : 2011-4-7
%%% -------------------------------------------------------------------
-module(mod_boxs_piece).

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
-export([start_boxs_piece/1,
		 start_boxs_piece_pro/5]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {pid, sid, player_id, drop_id = 1}).

%% ====================================================================
%% External functions
%% ====================================================================
start_boxs_piece(Player) ->
	UniqueSceneId = lib_box_scene:get_box_scene_unique_id(?BOXS_PIECE_ID),
	[X, Y] = lib_boxs_piece:get_boxs_piece_xy(),
	{ok, ScenePid} = start_boxs_piece_pro(Player, UniqueSceneId, X, Y, 1),
	NewPlayer = Player#player{scene = UniqueSceneId,
							  x = X,
							  y = Y,
							  other = Player#player.other#player_other{pid_scene = ScenePid}},
	NewPlayer.

%% ====================================================================
%% Server functions
%% ====================================================================
start_boxs_piece_pro(Player, UniqueSceneId, X, Y, Type) ->
	gen_server:start(?MODULE, [Player, UniqueSceneId, X, Y, Type], []).

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([Player, UniqueSceneId, X, Y, Type]) ->
	ProcessName = misc:create_process_name(scene_p, [UniqueSceneId, 0]),
	process_flag(trap_exit, true),	
	misc:register(global, ProcessName, self()), %% 多节点的情况下， 仅启用一个对应的秘境进程
	case lib_boxs_piece:start_boxs_piece(UniqueSceneId, ?BOXS_PIECE_ID) of
		fail ->
			Msg = <<"数据出错，进入诛邪副本失败！囧">>,
			{ok, BinData} = pt_12:write(12005, [0, 0, 0, Msg, 0, 0, 0, 0]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		{SceneName} ->
			case Type of
				1 ->
					{ok, BinData} = pt_12:write(12005, [UniqueSceneId, X, Y, SceneName, ?BOXS_PIECE_ID, 0, 0, 0]),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
					%%告诉原场景的玩家你已经离开
					pp_scene:handle(12004, Player, Player#player.scene);
				0 ->
					skip
			end
	end,
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
%%玩家点击npc，退出副本
handle_info({quit_scene, SceneId, _PlayerId}, State) ->
	lib_scene:clear_scene(SceneId),%%清场景数据
	{stop, normal, State};

%%玩家下线，清场景
handle_info({logout, SceneId, _PlayerId}, State) ->
	lib_scene:clear_scene(SceneId),%%清场景数据
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

