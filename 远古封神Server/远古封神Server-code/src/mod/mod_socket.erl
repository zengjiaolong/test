%%% -------------------------------------------------------------------
%%% Author  : hzj
%%% Description :玩家socket管理进程
%%%
%%% Created : 2011-3-28
%%% -------------------------------------------------------------------
-module(mod_socket).

-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% External exports
-export([
		 join/1,
		 get_state/1,
		 get_socket_group_name/2,
		 start/1,
		 stop/1
		]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-include("common.hrl").
-include("record.hrl").
-record(state, {
			socket1 = undefined, 		%%socket1
			socket2 = undefined,		%%socket2
			socket3 = undefined,		%%socket3
			groupname = undefined,		%%组名称
			player_id = undefined,		%%玩家ID
			player_pid = undefined		%%玩家进程
		}).

%% ====================================================================
%% External functions
%% ====================================================================

%%获取socket组名称
get_socket_group_name(Sn,Accid) ->
	tool:to_atom(lists:concat(["sg_",Sn,"_",Accid])).

%%获取进程信息
get_state(GroupName) ->
	case misc:whereis_name({local,GroupName}) of
		undefined ->
			[undefined,undefined];
		Pid ->
			gen_server:call(Pid,get_state)
	end.

%%子socket加入socket组
join([GroupName,Socket,N]) ->
	case misc:whereis_name({local,GroupName}) of
		undefined ->
			false;
		Pid when is_pid(Pid) ->
			Pid ! {join,Socket,N},
			true
	end.

stop(GroupName) ->
	case misc:whereis_name({local,GroupName}) of
		undefined ->
			ok;
		Pid ->
			Pid ! stop
	end.
%%开启进程
start([GroupName,Socket,Player_id,Player_pid]) ->
	catch erlang:unregister(GroupName),
	{ok,GPid} = gen_server:start_link({local,GroupName},?MODULE, [GroupName,Socket,Player_id,Player_pid], []),
	GPid.
%% ====================================================================
%% Server functions
%% ====================================================================

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([GroupName,Socket,Player_id,Player_pid]) ->
	process_flag(trap_exit, true),
	State = #state{
				   socket1 = Socket,
				   groupname = GroupName,
				   player_id = Player_id,
				   player_pid = Player_pid
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

%% 获取信息
handle_call(get_state,_From,State) ->
	Reply = [State#state.player_id,State#state.player_pid],
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
handle_cast(_Msg, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------



%%加入socket管理进程
handle_info({join,Socket,N},State) ->
	case N of
		2 ->
			NewState = State#state{socket2 = Socket},
			notice_child_join(State,N,Socket);
		3 ->
			NewState = State#state{socket3 = Socket},
			notice_child_join(State,N,Socket);			
		_ ->
			NewState = State
	end,
	{noreply,NewState};


%%停止
handle_info(stop,State) ->
	{stop,normal,State};

handle_info(_Info, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
%%	?DEBUG("_______________________________________________________________EXIT_1",[]),
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
%%子socket连接通知
notice_child_join(State,N,Socket) ->
	case State#state.player_pid of
		Pid when is_pid(Pid) ->
			Pid ! {child_socket_join,N,Socket};
		_ ->
			skip
	end.
