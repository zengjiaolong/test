%%%------------------------------------
%%% @Module     : auto_id
%%% @Author     : ygzj
%%% @Created    : 2011.10.10
%%% @Description: 自增id服务
%%%------------------------------------
-module(mod_auto_id).
-behaviour(gen_server).
-include("common.hrl").
-include("record.hrl").
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-compile(export_all).

-record(state, {dungeon_auto_id, fst_auto_id}).
%%%------------------------------------
%%%             接口函数
%%%------------------------------------

start_link() ->      
	%% 启动服务
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

get_autoid_pid() ->
	ProcessName = mod_autoid_process,
	case misc:whereis_name({global, ProcessName}) of
        Pid when is_pid(Pid) ->
            case misc:is_process_alive(Pid) of
                true -> 
                    Pid;
                false -> 
                    start_mod_autoid(ProcessName)
            end;
        _ ->
            start_mod_autoid(ProcessName)
	end.

start_mod_autoid(ProcessName) ->
	global:set_lock({ProcessName, undefined}),	
	ProcessPid = start_autoid(),
	global:del_lock({ProcessName, undefined}),
	ProcessPid.

start_autoid() ->
	case supervisor:start_child(
       		yg_server_sup, {mod_auto_id,
            		{mod_auto_id, start_link,[]},
               		permanent, 10000, supervisor, [mod_auto_id]}) of
		{ok, Pid} ->
				timer:sleep(1000),
				Pid;
		_ ->
				undefined
	end.

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([]) ->
    process_flag(trap_exit, true),
	ProcessName = mod_autoid_process,
 	case misc:register(unique, ProcessName, self())of
		yes ->
			misc:write_monitor_pid(self(),?MODULE, {}),
			misc:write_system_info(self(), mod_auto_id, {}),
			State = #state{dungeon_auto_id = 0, fst_auto_id = 0},
			io:format("9.Init mod_auto_id finish!!!~n"),
			{ok, State};
		_ ->
			{stop,normal,#state{}}
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
%%  	?DEBUG("mod_rank__apply_call: [~p/~p]", [Module, Method]),	
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_rank__apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method, Info]),
			 error;
		 DataRet -> DataRet
	end,
    {reply, Reply, State};

%% 已不用,改成数据库创建
%% 申请一个唯一id(为副本使用)
handle_call({dungeon_auto_id, SceneId}, _From, State) ->
	NewAutoId = if State#state.dungeon_auto_id > 210000 ->
		   				1;
	   				true -> State#state.dungeon_auto_id + 1
				end,
	Reply = lib_scene:create_unique_scene_id(SceneId, NewAutoId),
	NewState = State#state{dungeon_auto_id = NewAutoId},
    {reply, Reply, NewState};
%% 已不用,改成数据库创建
%% 申请一个唯一id(为封神台使用)
handle_call({fst_auto_id, SceneId}, _From, State) ->
	NewAutoId = if State#state.fst_auto_id > 210000 ->
		   				1;
	   				true -> State#state.fst_auto_id + 1
				end,
	Reply = lib_scene:create_unique_scene_id(SceneId, NewAutoId),
	NewState = State#state{fst_auto_id = NewAutoId},
    {reply, Reply, NewState};

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
%% 	?DEBUG("mod_rank__apply_cast: [~p/~p/~p]", [Module, Method, Args]),	
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_rank__apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
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

%%=========================================================================
%% 业务处理函数
%%=========================================================================


