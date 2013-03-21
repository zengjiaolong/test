%%%------------------------------------
%%% @Module     : mod_online_count
%%% @Author     : ygzj
%%% @Created    : 2010.10.06
%%% @Description: 玩家在线数统计
%%%------------------------------------
-module(mod_online_count).
-behaviour(gen_server).
-include("common.hrl").
-include("record.hrl").
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-compile(export_all).

-define(REFRESH_SHOP_GOODS, 24*3600*1000).   

-record(state, 
		{online}
	   ).
%%%------------------------------------
%%%             接口函数
%%%------------------------------------
%%获取在线人数
get_online_num() ->
	case misc:whereis_name({global, mod_online_count_process}) of
		Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> 
						gen_server:call(Pid,{get_online_num});
					false -> 
						0
				end;
			_ ->
				0
	end.

%% 增加在线人数
add_online_num()->
	case misc:whereis_name({global, mod_online_count_process}) of
		Pid when is_pid(Pid) ->
			gen_server:cast(Pid, {add_online_num});
		_ ->
			0
	end.

%% 减少在线人数
dec_online_num()->
	case misc:whereis_name({global, mod_online_count_process}) of
		Pid when is_pid(Pid) ->
			gen_server:cast(Pid, {dec_online_num});
		_ ->
			0
	end.

%%校正在线人数
set_online_num(N)->
	case misc:whereis_name({global, mod_online_count_process}) of
		Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> 
						gen_server:cast(Pid,{set_online_num,N});
					false -> 
						0
				end;
			_ ->
				0
	end.

start_link() ->      %% 启动服务
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

get_mod_online_count_pid() ->
	ProcessName = mod_online_count_process,
	case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> 
						Pid;
					false -> 
						start_mod_online_count(ProcessName)
				end;
			_ ->
				start_mod_online_count(ProcessName)
	end.

start_mod_online_count(ProcessName) ->
	global:set_lock({ProcessName, undefined}),	
	ProcessPid =
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> 
						Pid;
					false -> 
						start_online_count()
				end;
			_ ->
				start_online_count()
		end,	
	global:del_lock({ProcessName, undefined}),
	%%io:format("_______________________________mod_online_pid:~p~n",[ProcessPid]),
	ProcessPid.

start_online_count() ->
	case supervisor:start_child(
       		yg_server_sup, {mod_online_count,
            		{mod_online_count, start_link,[]},
               		permanent, 10000, supervisor, [mod_online_count]}) of
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
	ProcessName = mod_online_count_process,		%% 多节点的情况下， 仅启用一个进程
 	misc:register(global, ProcessName, self()),		
	misc:write_monitor_pid(self(),?MODULE, {}),
	misc:write_system_info(self(), mod_online_count, {}),	
	State = #state{
					online = 0
				  },
	io:format("4.Init mod_online_count finish!!!~n"),
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
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_shop__apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method, Info]),
			 error;
		 DataRet -> DataRet
	end,
    {reply, Reply, State};


handle_call({get_online_num},_From,State) ->
	{reply,State#state.online,State};

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
			 ?WARNING_MSG("mod_shop__apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
			 error;
		 _ -> ok
	end,
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

handle_cast({add_online_num},State) ->
	Online = State#state.online,
	{noreply,State#state{online = Online +1}};

handle_cast({dec_online_num},State) ->
	Online = State#state.online,
	if
		Online - 1 > 0 ->
			NewOnline = Online -1;
		true ->
			NewOnline = 0
	end,
	{noreply,State#state{online = NewOnline}};

handle_cast({set_online_num,N},State)->
	{noreply,State#state{online=N}};

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


	