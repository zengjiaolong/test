%%% -------------------------------------------------------------------
%%% Author  : hzj
%%% Description : 利用进程字典的 key-val 缓存模块
%%%
%%% Created : 2011-12-13
%%% -------------------------------------------------------------------
-module(mod_cache).
-define(EXPIRE,300). %%默认数据过期时间5分钟
-define(TIMER,1000). %%定时器 1秒钟
-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------

%% --------------------------------------------------------------------
%% External exports
-compile(export_all).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {ref = undefined}).

%% ====================================================================
%% External functions
%% ====================================================================
%% 本节点缓存处理 [使用进程字典]
get(Key) ->
	gen_server:call(get_local_cache_pid(),{apply_call, mod_cache, i_get, [Key]}).

gets(Keys) ->
	gen_server:call(get_local_cache_pid(),{apply_call, mod_cache, i_gets, [Keys]}).

set(Key,Val) ->
	set(Key,Val,?EXPIRE).

set(Key,Val,Expire) ->
	gen_server:call(get_local_cache_pid(),{apply_call, mod_cache, i_put, [Key,Val,Expire]}).

clear(Key) ->
	gen_server:call(get_local_cache_pid(),{apply_call, mod_cache, i_clear, [Key]}).

%%全局唯一节点缓存处理 [使用进程字典]
g_get(Key) ->
	gen_server:call(get_global_cache_pid(),{apply_call, mod_cache, i_get, [Key]}).

g_gets(Keys) ->
	gen_server:call(get_global_cache_pid(),{apply_call, mod_cache, i_get, [Keys]}).

g_set(Key,Val) ->
	g_set(Key,Val,?EXPIRE).

g_set(Key,Val,Expire) ->
	gen_server:call(get_global_cache_pid(),{apply_call, mod_cache, i_put, [Key,Val,Expire]}).

g_clear(Key) ->
	gen_server:call(get_global_cache_pid(),{apply_call, mod_cache, i_clear, [Key]}).



start_link(ProcessName) ->      %% 启动服务
    gen_server:start_link({local, ProcessName}, ?MODULE, [ProcessName], []).

%%启动本节点缓存模块进程
get_local_cache_pid() ->
	ProcessName = mod_local_cache_process,
	case misc:whereis_name({local,ProcessName}) of
		Pid when is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true ->
					Pid;
				false ->
					start_local_cache(ProcessName)
			end;
		_ ->
			start_local_cache(ProcessName)
	end.
%% 启动全局缓存模块进程 （唯一）
get_global_cache_pid() ->
	ProcessName = mod_global_cache_process,
	case misc:whereis_name({global,ProcessName}) of
		Pid when is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true ->
					Pid;
				false ->
					start_global_cache(ProcessName)
			end;
		_ ->
			start_global_cache(ProcessName)
	end.
		
%% ====================================================================
%% Server functions
%% ====================================================================

%%启动本节点cache进程
start_local_cache(ProcessName) ->
	case supervisor:start_child(yg_server_sup,{ProcessName,{mod_cache,start_link,[ProcessName]},permanent,10000,supervisor,[mod_cache]}) of
		{ok,Pid} ->
			Pid;
		_ ->
			undefined
	end.

%%启动全局cache进程
start_global_cache(ProcessName) ->
	global:set_lock({ProcessName, undefined}),	
	Cpid =
	case supervisor:start_child(yg_server_sup,{ProcessName,{mod_cache,start_link,[ProcessName]},permanent,10000,supervisor,[mod_cache]}) of
		{ok,Pid} ->
			timer:sleep(1000),
			Pid;
		_ ->
			undefined
	end,
	global:del_lock({ProcessName, undefined}),
	Cpid.
	
%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([ProcessName]) ->
	process_flag(trap_exit, true),
	case ProcessName of
		mod_local_cache_process ->
			Ref = erlang:send_after(?TIMER,self(), 'CLEAREXPIRE'),
			io:format("11.Init mod_local_cache finish!!!~n"),
			{ok,#state{ref = Ref}};
		mod_global_cache_process ->
			case misc:register(unique,ProcessName,self()) of
				yes ->
					Ref = erlang:send_after(?TIMER,self(), 'CLEAREXPIRE'),
					io:format("12.Init mod_global_cache finish!!!~n"),
    				{ok, #state{ref = Ref}};
				_ ->
					{stop,normal,#state{}}
			end
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
		 {'EXIT', _Info} ->	
			 %%?WARNING_MSG("mod_scene_apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
			 [];
		 DataRet -> DataRet
	end,
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
%%接受定时器清理过期缓存数据
handle_info('CLEAREXPIRE',State) ->
	case erlang:get(keylist) of
		undefined ->
			ignore;
		KeyList ->
			Now = util:unixtime(),
			do_clear(KeyList,Now)
	end,
	erlang:cancel_timer(State#state.ref),
	Ref = erlang:send_after(?TIMER,self(), 'CLEAREXPIRE'),
	{noreply, State#state{ref = Ref}};
			
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
%% 内部函数
%% return val | []
i_get(Key) ->
	Now = util:unixtime(),
	i_get(Key,Now).

i_get(Key,Now) ->
	case erlang:get(Key) of
		undefined  -> 
			[];
		{Val,Expire} -> 
			if
				Now > Expire ->
					i_clear(Key),
					[];
				true ->
					Val
			end
	end.

%% 获取多个key的返回值
i_gets(Keys) ->
	Now = util:unixtime(),
	lists:reverse(i_getloop(Keys,Now,[])).

i_getloop([],_Now,Result) ->
	Result;
i_getloop([K|Ks],Now,Result) ->
	V = i_get(K,Now),
	i_getloop(Ks,Now,[V|Result]).
	
%%保存数据
i_put(Key,Val) ->
  i_put(Key,Val,?EXPIRE).

i_put(Key,Val,Expire) ->
	case erlang:get(keylist) of
		undefined ->
			erlang:put(keylist,[Key]);
		KeyList ->
			erlang:put(keylist,[Key|KeyList])
	end,
	Now = util:unixtime(),
	erlang:put(Key,{Val,Now + Expire}),
	Val.

%%清除数据
i_clear(Key) ->
	case erlang:get(keylist) of
		undefined ->
			ignore;
		KeyList ->
			lists:delete(Key, KeyList)
	end,
	erlang:put(Key,undefined),
	ok.

%%处理过期数据
do_clear([],_Now) ->
	ok;
do_clear([K|Klist],Now) ->
	case erlang:get(K) of
		{_v,Expire} ->
			if
				Now >  Expire ->
					i_clear(K);
				true ->
					ignore
			end;
		_ ->
			ignore
	end,
	do_clear(Klist,Now).


%%teset%%
%% 测试结果
%%(ygzj_game1@127.0.0.1)34> mod_cache:t1().       
%%t:1710
%%ok
%%(ygzj_game1@127.0.0.1)35> mod_cache:t2().       
%%t:59
%%ok

t1() ->
	T1 = util:longunixtime(),
	lists:foreach(fun(N) ->
						  mod_cache:g_put(N,"nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",600)
				  end
						  , lists:seq(1, 10000)),
	Tp = util:longunixtime() - T1,
	io:format("t:~p~n",[Tp]).

t2() ->
	T1 = util:longunixtime(),
	lists:foreach(fun(N) ->
						  mod_cache:put(N,"nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",600)
				  end
						  , lists:seq(1, 10000)),
	Tp = util:longunixtime() - T1,
	io:format("t:~p~n",[Tp]).

p1() ->
	process_info(mod_cache:get_local_cache_pid()).

p2() ->
	process_info(mod_cache:get_global_cache_pid()).
	