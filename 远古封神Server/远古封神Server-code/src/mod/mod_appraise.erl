%%% -------------------------------------------------------------------
%%% Author  : ygzj
%%% Description : 玩家评价模块
%%% Created : 2011-4-8
%%% -------------------------------------------------------------------
-module(mod_appraise).

-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% External exports
-export(
 	[
		start_link/1,
		start/1,
		stop/0,
		get_mod_appraise_pid/0,
		adore/5,
		get_adore/2,
		get_max_appraise/2,
		get_all_max_appraise/0
	]
).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include("common.hrl").
-include("record.hrl").

-record(state, {}).

%% ====================================================================
%% Server functions
%% ====================================================================
%%启动评价服务
start_link([ProcessName, Worker_id]) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [ProcessName, Worker_id], []).

start([ProcessName, Worker_id]) ->
    gen_server:start(?MODULE, [ProcessName, Worker_id], []).

%%停止服务
stop() ->
    gen_server:call(?MODULE, stop).


%%开启评价全局模块
get_mod_appraise_pid() ->
	ProcessName = misc:create_process_name(mod_appraise_process, [0]),
	case misc:whereis_name({global, ProcessName}) of
		Pid when is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true -> Pid;
				false -> 
					start_mod_appraise(ProcessName)
			end;
		_ ->
			start_mod_appraise(ProcessName)
	end.

%%启动全局进程(加锁保证全局唯一)
start_mod_appraise(ProcessName) ->
	global:set_lock({ProcessName, undefined}),	
	ProcessPid =
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> Pid;
					false -> 
						start_appraise(ProcessName)
				end;
			_ ->
				start_appraise(ProcessName)
		end,	
	global:del_lock({ProcessName, undefined}),
	ProcessPid.

start_appraise(ProcessName) ->
	 case supervisor:start_child(
               yg_server_sup,
               {mod_appraise,
                {mod_appraise, start_link,[[ProcessName, 0]]},
                permanent, 10000, supervisor, [mod_appraise]}) of
		{ok, Pid} ->
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
%%进程初始化
init([ProcessName, _WorkerId]) ->
	process_flag(trap_exit, true),	
	case misc:register(unique, ProcessName, self()) of
		yes ->
			ets:new(?ETS_APPRAISE,[{keypos,#ets_appraise.id},named_table,public,set,?ETSRC, ?ETSWC]),%% 玩家评价表
			lib_appraise:init_data(),
			io:format("7.Init mod_appraise finish!!!~n"),
    		{ok, #state{}};
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
	Reply  = 
		case (catch apply(Module, Method, Args)) of
			{'EXIT', Info} ->	
?WARNING_MSG("mod_appraise_apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
			 	[];
		 	DataRet -> 
				DataRet
		end,
    {reply, Reply, State};

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
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
?WARNING_MSG("mod_appraise_apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
			 [];
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
terminate(Reason, State) ->
	misc:delete_monitor_pid(self()),
	?WARNING_MSG("APPRAISE_TERMINATE: Reason ~p~n State ~p~n", [Reason, State]),
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
%%玩家评价信息(打开界面返回相应的数据)
get_adore(Player_Id, OtherId) ->
	try 
		gen_server:call(mod_appraise:get_mod_appraise_pid(), 
			{apply_call, lib_appraise, get_adore, [Player_Id,OtherId]})
	catch
		_:_ -> []
	end.

%%评价
adore(Player, OtherId, Type, {Flag, Bool},NewRela) ->
	try 
		gen_server:call(mod_appraise:get_mod_appraise_pid(), 
			{apply_call, lib_appraise, adore, [Player, OtherId, Type, {Flag, Bool},NewRela]})
	catch
		_:_ -> []
	end.	

%%查找最终粉丝(type=2崇拜次数最多最早的,type=3鄙视次数最多最早的那位)
get_max_appraise(Type, Limit) ->
	try 
		gen_server:call(mod_appraise:get_mod_appraise_pid(), 
			{apply_call, lib_appraise, get_max_appraise, [Type, Limit]})
	catch
		_:_ -> []
	end.

%%排行一次性获取崇拜和鄙视最多
get_all_max_appraise() ->
	try 
		gen_server:call(mod_appraise:get_mod_appraise_pid(), 
						{apply_call, lib_appraise, get_all_max_appraise, []})
	catch
		_:_ -> 
			{[], []}
	end.