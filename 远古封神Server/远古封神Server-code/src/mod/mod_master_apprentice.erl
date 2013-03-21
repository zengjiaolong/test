%%% -------------------------------------------------------------------
%%% Description :师徒关系
%%% Author: ygzj
%%% Created : 2010-11-17
%%% -------------------------------------------------------------------
-module(mod_master_apprentice).

-behaviour(gen_server).
-include("common.hrl").
-include("record.hrl").
-record(state, {worker_id = 0}).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-compile(export_all).

%% 启动师徒关系服务
start_link([ProcessName, Worker_id]) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [ProcessName, Worker_id], []).

start([ProcessName, Worker_id]) ->
    gen_server:start(?MODULE, [ProcessName, Worker_id], []).

%%停止服务
stop() ->
    gen_server:call(?MODULE, stop).

%%初始化师徒关系数据
init([ProcessName, Worker_id]) ->
	process_flag(trap_exit, true),
	case misc:register(unique, ProcessName, self()) of %% 多节点的情况下， 仅在一个节点启用师徒关系处理进程
		yes ->
			if Worker_id =:= 0 ->	
		   	ets:new(?ETS_MASTER_APPRENTICE, [{keypos, #ets_master_apprentice.apprentenice_id}, named_table, public, set,?ETSRC, ?ETSWC]),%%师徒关系表
		   	lib_master_apprentice:load_master_apprentice(),
		   	misc:write_monitor_pid(self(), mod_master_apprentice, {?MASTAR_APPRENTICE_WORKER_NUMBER}),
		   	misc:write_system_info(self(), mod_master_apprentice, {}),	
		   	%% 启动多个场景服务进程
		   	io:format("5.Init mod_master_apprentice finish!!!~n"),
		   	lists:foreach(
				fun(WorkerId) ->
					ProcessName_1 = misc:create_process_name(master_apprentice_p, [WorkerId]),
					mod_master_apprentice:start([ProcessName_1, WorkerId])
				end,
				lists:seq(1, ?MASTAR_APPRENTICE_WORKER_NUMBER));
	   		true ->
		   		misc:write_monitor_pid(self(), mod_master_apprentice_child, {Worker_id})
			end,
	
			State= #state{worker_id = Worker_id},
    		{ok, State};
		_ ->
			{stop,normal,#state{}}
	end.

%%动态添加师徒关系处理进程
get_mod_master_apprentice_pid() ->
	ProcessName = misc:create_process_name(master_apprentice_p, [0]),
	case misc:whereis_name({global, ProcessName}) of
		Pid when is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true -> Pid;
				false ->
					start_mod_master_apprentice(ProcessName)
			end;
		_ ->
			start_mod_master_apprentice(ProcessName)
	end.

%%启动师徒关系模块(加锁保证全局唯一)
start_mod_master_apprentice(ProcessName) ->
	global:set_lock({ProcessName,undefined}),
	ProcessPid = 
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true ->	
						WorkerId = random:uniform(?MASTAR_APPRENTICE_WORKER_NUMBER),
						ProcessName_1 = misc:create_process_name(master_apprentice_p, [WorkerId]),
 						misc:whereis_name({global, ProcessName_1});		
					false ->
						start_master_apprentice(ProcessName)
				end;
			_ -> start_master_apprentice(ProcessName)
		end,
	global:del_lock({ProcessName, undefined}),
	ProcessPid.
			
%%开启师徒监控模块
start_master_apprentice(ProcessName) ->
	case supervisor:start_child(
               yg_server_sup,
               {mod_master_apprentice,
                {mod_master_apprentice, start_link,[[ProcessName, 0]]},
                permanent, 10000, supervisor, [mod_master_apprentice]}) of
		{ok, Pid} ->
				Pid;
		_ ->
				undefined
	end.

%% 统一模块+过程调用(call)
handle_call({apply_call, Module, Method, Args}, _From, State) ->
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', _Info} ->	
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
		 {'EXIT', _Info} ->	
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

terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()),
	misc:delete_system_info(self()),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%%==================================业务逻辑模块=======================================================
  
%%拜师申请
send_apprentice_apply(PlayerStatus,Master_Id) ->
	try 
		Ret =gen_server:call(mod_master_apprentice:get_mod_master_apprentice_pid(), 
					 {apply_call, lib_master_apprentice, send_apprentice_apply, [PlayerStatus,Master_Id]}),
		if Ret == error -> 
			   0;
		   true -> Ret 
		end
	catch
		_:_ -> 0
	end.

%%接受拜师申请
accept_apprentice_apply(PlayerStatus,Apprentenice_Id) ->
	try 
		gen_server:call(mod_master_apprentice:get_mod_master_apprentice_pid(), 
					 {apply_call, lib_master_apprentice, accept_apprentice_apply, [PlayerStatus,Apprentenice_Id]})
	catch
		_:_ -> 
			?WARNING_MSG("27001 [~p]", ["accept_apprentice_apply"]),
			2
	end.


%%收徒邀请， 邀请对象角色ID
invite_apprentice(PlayerStatus,Apprentenice_Id) ->
	try 
		gen_server:call(mod_master_apprentice:get_mod_master_apprentice_pid(), 
					 {apply_call, lib_master_apprentice, invite_apprentice, [PlayerStatus,Apprentenice_Id]})
	catch
		_:_ -> 
			?WARNING_MSG("27002 [~p]", ["invite_apprentice"]),
			[1,2,0,""]
	end.

%%是否同意拜师， 邀请对象角色ID
accpet_invite_apprentice(PlayerStatus,Master_Id0,Status) ->
	try 
		gen_server:call(mod_master_apprentice:get_mod_master_apprentice_pid(), 
					 {apply_call, lib_master_apprentice, accpet_invite_apprentice, [PlayerStatus,Master_Id0,Status]})
	catch
		_:_ -> []
	end.

%%查询当前角色的师傅信息
get_master_info(Player_Id) ->
	try 
		gen_server:call(mod_master_apprentice:get_mod_master_apprentice_pid(), 
					 {apply_call, lib_master_apprentice, get_master_info, [Player_Id]})
	catch
		_:_ -> []
	end.

%%查询同门师兄弟信息列表
get_master_apprentice_info_page(Player_Id) ->
	try 
		gen_server:call(mod_master_apprentice:get_mod_master_apprentice_pid(), 
					 {apply_call, lib_master_apprentice, get_master_apprentice_info_page, [Player_Id]})
	catch
		_:_ -> []
	end.

%%可否汇报成绩
is_need_report(PlayerStatus) ->
	try 
		gen_server:call(mod_master_apprentice:get_mod_master_apprentice_pid(), 
					 {apply_call, lib_master_apprentice, is_need_report, [PlayerStatus]})
	catch
		_:_ -> []
	end.

%%汇报成绩
report_lv(PlayerStatus) ->
	try 
		gen_server:call(mod_master_apprentice:get_mod_master_apprentice_pid(), 
					 {apply_call, lib_master_apprentice, report_lv, [PlayerStatus]})
	catch
		_:_ -> 
			[0,2,0,0]
	end.

%%退出师门,State是否使用决裂书
exit_master_apprentice(PlayerStatus,State) ->
	try 
		gen_server:call(mod_master_apprentice:get_mod_master_apprentice_pid(), 
					 {apply_call, lib_master_apprentice, exit_master_apprentice, [PlayerStatus,State]})
	catch
		_:_ -> []
	end.	

%%查询当前角色的信息
get_current_role_info(Player_Id) ->
	try 
		gen_server:call(mod_master_apprentice:get_mod_master_apprentice_pid(), 
					 {apply_call, lib_master_apprentice, get_current_role_info, [Player_Id]})
	catch
		_:_ -> []
	end.	

%%查询当前角色的徒弟信息
get_my_apprentice_info_page(Player_Id) ->
	try 
		gen_server:call(mod_master_apprentice:get_mod_master_apprentice_pid(), 
					 {apply_call, lib_master_apprentice, get_my_apprentice_info_page, [Player_Id]})
	catch
		_:_ -> []
	end.	
	
%%逐出师门,State是否使用决裂书
kick_out_master_apprentice(PlayerStatus,Apprentenice_Id,State) ->
	try 
		gen_server:call(mod_master_apprentice:get_mod_master_apprentice_pid(), 
					 {apply_call, lib_master_apprentice, kick_out_master_apprentice, [PlayerStatus,Apprentenice_Id,State]})
	catch
		_:_ -> 0
	end.	

%%查询所有伯乐 信息
get_all_master_info_page(PageNumber) ->
	try 
		gen_server:call(mod_master_apprentice:get_mod_master_apprentice_pid(), 
					 {apply_call, lib_master_apprentice, get_all_master_info_page, [PageNumber]})
	catch
		_:_ -> 
			[PageNumber, 0, []]
	end.	

%%登记上榜
enter_master_charts(PlayerStatus) ->
	try 
		gen_server:call(mod_master_apprentice:get_mod_master_apprentice_pid(), 
					 {apply_call, lib_master_apprentice, enter_master_charts, [PlayerStatus]})
	catch
		_:_ -> 
			1
	end.	

%%登取消上榜
exit_master_charts(Player_Id) ->
	try 
		gen_server:call(mod_master_apprentice:get_mod_master_apprentice_pid(), 
					 {apply_call, lib_master_apprentice, exit_master_charts, [Player_Id]})
	catch
		_:_ -> 1
	end.	

%%查找伯乐
query_master_charts(Nickname)->
	try 
		gen_server:call(mod_master_apprentice:get_mod_master_apprentice_pid(), 
					 {apply_call, lib_master_apprentice, query_master_charts, [Nickname]})
	catch
		_:_ -> []
	end.	

%%出师
finish_apprenticeship(Player_Id) ->
	try 
		gen_server:call(mod_master_apprentice:get_mod_master_apprentice_pid(), 
					 {apply_call, lib_master_apprentice, finish_apprenticeship, [Player_Id]})
	catch
		_:_ -> []
	end.	
	
%%更新师傅表和徒弟表的等级 
update_masterAndApprenteniceLv(PlayerStatus) ->
	try
		gen_server:cast(mod_master_apprentice:get_mod_master_apprentice_pid(),
											 {apply_cast, lib_master_apprentice, update_masterAndApprenteniceLv, [PlayerStatus]})
	catch
		_:_ -> []
	end.	

%%查询自己师傅的id
get_own_master_id(Player_Id) ->
	try 
		gen_server:call(mod_master_apprentice:get_mod_master_apprentice_pid(), 
					 {apply_call, lib_master_apprentice, get_own_master_id, [Player_Id]})
	catch
		_:_ -> []
	end.

%%查询是否已经上榜
is_enter_master_charts(Player_Id) ->
	try 
		gen_server:call(mod_master_apprentice:get_mod_master_apprentice_pid(), 
					 {apply_call, lib_master_apprentice, is_enter_master_charts, [Player_Id]})
	catch
		_:_ -> false
	end.

%%查询某师傅已出师的徒弟数量
get_finish_apprenticeship_count(Master_Id) ->
	try 
		gen_server:call(mod_master_apprentice:get_mod_master_apprentice_pid(), 
					 {apply_call, lib_master_apprentice, get_finish_apprenticeship_count, [Master_Id]})
	catch
		_:_ -> 0
	end.

%%更新师徒信息角色名
change_player_name(PlayerId,NewNickName) ->
		try
		gen_server:cast(mod_master_apprentice:get_mod_master_apprentice_pid(),
											 {apply_cast, lib_master_apprentice, change_player_name, [PlayerId,NewNickName]})
	catch
		_:_ -> []
	end.	
