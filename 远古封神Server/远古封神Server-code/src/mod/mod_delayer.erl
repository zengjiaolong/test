%%%------------------------------------
%%% @Module     : mod_delayer
%%% @Author     : ygzj
%%% @Created    : 2011.02.28
%%% @Description: 人物信息延时器
%%%------------------------------------
-module(mod_delayer).
-behaviour(gen_server).
-include("common.hrl").
-include("record.hrl").
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-compile(export_all).
-record(state, {worker_id = 0}).
-include_lib("stdlib/include/ms_transform.hrl").


%%%------------------------------------
%%%             接口函数
%%%------------------------------------

start_link([Wid,DelayerWorkerProcessName]) ->      %% 启动服务
    gen_server:start_link(?MODULE, [Wid,DelayerWorkerProcessName], []).

%%动态加载延时信息处理进程 
get_mod_delayer_pid() ->
	ProcessName = misc:create_process_name(delayer,[0]),
	case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> 
						WorkerId = random:uniform(?DELAYER_WORKER_NUMBER),
						WorkerProcessName = misc:create_process_name(delayer,[WorkerId]),
						misc:whereis_name({global,WorkerProcessName});
					false -> 
						start_mod_delayer(ProcessName)
				end;
			_ ->
				start_mod_delayer(ProcessName)
	end.

%%启动延时信息模块 (加锁保证全局唯一)
start_mod_delayer(ProcessName) ->
	global:set_lock({ProcessName, undefined}),
	ProcessPid = start_delayer(ProcessName),
	global:del_lock({ProcessName, undefined}),
	ProcessPid.

%%启动延时信息模块
start_delayer(ProcessName) ->
	case supervisor:start_child(
       		yg_server_sup, {mod_delayer,
            		{mod_delayer, start_link,[[0,ProcessName]]},
               		permanent, 10000, supervisor, [mod_delayer]}) of
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
init([Worker_id ,DelayerProcessName]) ->
    process_flag(trap_exit, true),
 	case misc:register(unique, DelayerProcessName, self()) of
		yes ->
			if
				Worker_id =:= 0 ->
					net_kernel:monitor_nodes(true),
					misc:write_monitor_pid(self(),?MODULE, {Worker_id}),
					%%misc:write_system_info(self(), mod_delayer, {Worker_id}),
					io:format("1.init Delayer finish!!!\n"),
					lists:foreach(
						fun(Wid) ->
							DelayerWorkerProcessName = misc:create_process_name(delayer,[Wid]),
							mod_delayer:start_link([Wid,DelayerWorkerProcessName])
						end,
						lists:seq(1, ?DELAYER_WORKER_NUMBER));
				true ->
					misc:write_monitor_pid(self(),?MODULE, {Worker_id})
			end,			
			State= #state{worker_id = Worker_id},	
	 		{ok, State};
		_ ->
			{stop,normal,{}}
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
%%  	%% ?DEBUG("mod_delayer__apply_call: [~p/~p]", [Module, Method]),	
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_delayer__apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method, Info]),
			 error;
		 DataRet -> DataRet
	end,
    {reply, Reply, State};

%%获取玩家延时信息
handle_call({'GET_DELAYER_INFO', Uid}, _From, State) ->
	Reply =
    	case ets:lookup(?ETS_DELAYER, Uid) of
        	[] -> [undefined, [], undefined];
        	[Delayer] -> [Delayer#ets_delayer.dungeon_pid, Delayer#ets_delayer.fst_pid, Delayer#ets_delayer.team_pid];
			_ -> [undefined, [], undefined]
    	end,
    {reply, Reply, State};

%%获取小黑板信息
handle_call({'GET_BLACKBOARD_INFO'}, _From, State) ->
	Reply = ets:tab2list(?ETS_BLACKBOARD),
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
%% 	%% ?DEBUG("mod_delayer__apply_cast: [~p/~p/~p]", [Module, Method, Args]),	
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_delayer__apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
			 error;
		 _ -> ok
	end,
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

handle_cast({'REC_PLAYER', Uid, Dungeon_pid, Fst_pid, Team_pid}, State) ->
	Player_Delayer = #ets_delayer{
            id = Uid, 
            dungeon_pid = Dungeon_pid, 
            fst_pid = Fst_pid, 
            team_pid = Team_pid
        },
    ets:insert(?ETS_DELAYER, Player_Delayer),
	{noreply, State};

%% handle_cast({'REC_PLAYER_FST_SHOP', Uid, Dungeon_pid, Fst_pid, Team_pid, Fst_Shop}, State) ->
%% 	Player_Delayer = #ets_delayer{
%%             id = Uid, 
%%             dungeon_pid = Dungeon_pid, 
%%             fst_pid = Fst_pid, 
%%             team_pid = Team_pid,			 
%%         },
%%     ets:insert(?ETS_DELAYER, Player_Delayer),
%% 	{noreply, State};


handle_cast({'REC_PLAYER_TEAM', Uid, Team_pid}, State) ->
	%% ?DEBUG("REC_PLAYER_TEAM/debug__0_~p/",[Team_pid]),
	%% ?DEBUG("REC_PLAYER_TEAM/debug__0_~p/",[ets:lookup(?ETS_DELAYER, Uid)]),
	[Dungeon_pid, Fst_pid] =
	    case ets:lookup(?ETS_DELAYER, Uid) of
        	[] -> [undefined, []];
        	[Delayer] -> [Delayer#ets_delayer.dungeon_pid, Delayer#ets_delayer.fst_pid];
			_ -> [undefined, []]
    	end,
	Player_Delayer = #ets_delayer{
            id = Uid, 
            dungeon_pid = Dungeon_pid, 
            fst_pid = Fst_pid, 
            team_pid = Team_pid
        },
    ets:insert(?ETS_DELAYER, Player_Delayer),
	%% ?DEBUG("REC_PLAYER_TEAM/debug__1_~p/",[ets:lookup(?ETS_DELAYER, Uid)]),
	{noreply, State};

handle_cast({'UPDATE_BLACKBOARD_INFO', NewBBM}, State) ->
    ets:insert(?ETS_BLACKBOARD, NewBBM),
	{noreply, State};

handle_cast({'DELETE_BLACKBOARD_INFO', Uid}, State) ->
    ets:delete(?ETS_BLACKBOARD, Uid),
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
check_delayer_info(Uid)->
	gen_server:call(mod_delayer:get_mod_delayer_pid(), {'GET_DELAYER_INFO', Uid}).

update_delayer_info(Uid, Dungeon_pid, Fst_pid, Team_pid)->
	gen_server:cast(mod_delayer:get_mod_delayer_pid(), {'REC_PLAYER', Uid, Dungeon_pid, Fst_pid, Team_pid}).
  
update_delayer_info(Uid, Team_pid)->
	gen_server:cast(mod_delayer:get_mod_delayer_pid(), {'REC_PLAYER_TEAM', Uid, Team_pid}).

%% update_delayer_info(fst, Uid, Fst_Shop)->
%% 	gen_server:cast(mod_delayer:get_mod_delayer_pid(), {'REC_PLAYER_FST_SHOP', Uid, Fst_Shop}).

check_blackboard_info()->
	gen_server:call(mod_delayer:get_mod_delayer_pid(), {'GET_BLACKBOARD_INFO'}).

add_blackboard_info(NewBBM) ->
	gen_server:cast(mod_delayer:get_mod_delayer_pid(), {'UPDATE_BLACKBOARD_INFO', NewBBM}).

delete_blackboard_info(Uid) ->
	gen_server:cast(mod_delayer:get_mod_delayer_pid(), {'DELETE_BLACKBOARD_INFO', Uid}).