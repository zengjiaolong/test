%%% -------------------------------------------------------------------
%%% Author  : xianrongMai
%%% Description :大竞猜活动
%%%
%%% Created : 2012-4-20
%%% -------------------------------------------------------------------
-module(mod_quizzes).

-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("activities.hrl").
-include("common.hrl").
-include("record.hrl").

-define(ACTION_TIME, 10000).		%%循环检测时间戳 
%% --------------------------------------------------------------------
%% External exports
-export([
		 get_quizzes_pid/0,			%%获取大竞猜的经常Pid
		 start_link/0,
		 stop/0
		]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {lucky = 0,			%%幸运号码
				award = ?PRIZE_NUM,	%%奖池奖金
				prize3 = 0			%%幸运之星领取的奖金
			   }).

%% ====================================================================
%% External functions
%% ====================================================================
start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

stop() ->
	gen_server:call(?MODULE, stop).

%% ====================================================================
%% Server functions
%% ====================================================================
%%动态加载市场交易处理进程 
get_quizzes_pid() ->
	ProcessName = mod_quizzes,
	case misc:whereis_name({global, ProcessName}) of
		Pid when is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true -> Pid;
				false -> 
					start_mod_quizzes(ProcessName)
			end;
		_ ->
			start_mod_quizzes(ProcessName)
	end.

%%启动市场交易监控模块 (加锁保证全局唯一)
start_mod_quizzes(ProcessName) ->
	global:set_lock({ProcessName, undefined}),	
	ProcessPid =
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> Pid;
					false -> 
						start_quizzes()
				end;
			_ ->
				start_quizzes()
		end,	
	global:del_lock({ProcessName, undefined}),
	ProcessPid.

%%开启市场交易监控模块
start_quizzes() ->
	case supervisor:start_child(
		   yg_server_sup,
		   {mod_quizzes,
			{mod_quizzes, start_link,[]},
			permanent, 10000, supervisor, [mod_quizzes]}) of
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
	ProcessName = mod_quizzes,		%% 多节点的情况下， 仅启用一个进程
	case misc:register(unique, ProcessName, self()) of
		yes ->
			ets:new(?ETS_QUIZZES, [{keypos, #quizzes.pid}, named_table, public, set,?ETSRC, ?ETSWC]), %%交易市场表
			erlang:send_after(4000, self(), {'LOAD_ALL_QUIZZES'}),%%4秒之后开始数据的加载
			misc:write_monitor_pid(self(),?MODULE, {}),
			misc:write_system_info(self(), mod_quizzes, {}),	
			io:format("14.Init mod_quizzes finish!!!~n"),
			{ok, #state{}};
		_ ->
			{stop, normal, #state{}}
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
	%% 	?DEBUG("mod_quizzes apply_call:[~p, ~p, ~p]", [Module, Method, Args]),
	Reply = 
		case (catch apply(Module, Method, Args)) of
			{'EXIT', Info} ->
				?WARNING_MSG("mod_quizzes apply_call fail: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
				error;
			DataRet -> DataRet
		end,
	{reply, Reply, State};

handle_call(_Request, _From, State) ->
	?WARNING_MSG("mod_quizzes unknow call:~p, from:~p", [_Request, _From]),
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
	%% 	?DEBUG("mod_quizzes apply_cast: [~p, ~p, ~p]", [Module, Method, Args]),	
	case (catch apply(Module, Method, Args)) of
		{'EXIT', Info} ->	
			?WARNING_MSG("mod_quizzes apply_cast fail: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
			error;
		_ -> ok
	end,
	{noreply, State};

%% -----------------------------------------------------------------
%% 30031 竞猜面板请求
%% -----------------------------------------------------------------
handle_cast({'GET_SELF_QUIZZES', Pid, PidSend}, State) ->
	#state{lucky = LuckyNum,
		   award = PrizeNum,
		   prize3 = ThreePrize} = State,
	lib_quizzes:get_myself_quizzes(LuckyNum, PrizeNum, Pid, PidSend, ThreePrize),
	{noreply, State};

%% -----------------------------------------------------------------
%% 30032 开始竞猜
%% -----------------------------------------------------------------
handle_cast({'MAKE_SELF_QUIZZES', Pid, PName, PidSend}, State) ->
	lib_quizzes:make_myself_quizzes(Pid, PName, PidSend),
	{noreply, State};

%% -----------------------------------------------------------------
%% 30034 领取奖励
%% -----------------------------------------------------------------
handle_cast({'GET_QUIZZES_AWARD', Pid, PPid, PidSend}, State) ->
	lib_quizzes:get_quizzes_award(Pid, PPid, PidSend, State#state.prize3),
	{noreply, State};

%%ＧＭ命令
handle_cast({'GM_CLEAR_QUIZZES', PlayerId}, State) ->
	lib_quizzes:gm_clear_player_quizzes(PlayerId),
	{noreply, State};

%% 判断是否需要通知客户端领取竞猜奖励
handle_cast({'CHECK_PLZYER_QUIZZES_RECEIVE', PlayerId, PidSend}, State) ->
	lib_quizzes:check_player_quizzes(PlayerId, PidSend),
	{noreply, State};

handle_cast(_Msg, State) ->
	?WARNING_MSG("mod_quizzes unknow cast:~p, from:~p", [_Msg]),
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%%初始化数据
handle_info({'LOAD_ALL_QUIZZES'}, State) ->
	{LuckyNum, PrizeNum, ThreePrize} = lib_quizzes:load_quizzes_data(),
	NState = State#state{lucky = LuckyNum,
						 award = PrizeNum,
						 prize3 = ThreePrize},
	%%轮询开始
	misc:cancel_timer(time_action),
	TimeRef = erlang:send_after(?ACTION_TIME, self(), {'CHECK_QUIZZES'}),
	put(time_action, TimeRef),%%进程字典
	{noreply, NState};

handle_info({'CHECK_QUIZZES'}, State) ->
	%% 检查整个大竞猜活动流程的处理
	#state{lucky = LuckyNum,
		   award = PrizeNum,
		   prize3 = ThreePrize} = State,
	case lib_quizzes:check_quizzes(LuckyNum, PrizeNum, ThreePrize) of
		{1, NLuckyNum, NPrizeNum, NThreePrize} ->
			misc:cancel_timer(time_action),
			TimeRef = erlang:send_after(?ACTION_TIME, self(), {'CHECK_QUIZZES'}),
			put(time_action, TimeRef),%%进程字典
			NState = State#state{lucky = NLuckyNum,
								 award = NPrizeNum,
								 prize3 = NThreePrize};
		_ ->
			NState = State
	end,
	{noreply, NState};

handle_info(_Info, State) ->
	?WARNING_MSG("mod_quizzes unknow info:~p, from:~p", [_Info]),
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

