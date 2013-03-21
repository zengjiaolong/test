%%% -------------------------------------------------------------------
%%% Author  : xianrongMai
%%% Description :神岛空战中定时刷新小怪的处理进程
%%%
%%% Created : 2011-5-9
%%% -------------------------------------------------------------------
-module(mod_skyrush_mon).

-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("guild_info.hrl").
%% --------------------------------------------------------------------
%% External exports
-export([init_skyrush_mon/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

 %%[怪物ID, X, Y, 进入场景是否广播：1：广播,o：不广播, 怪物进程PId(默认为undefined)]
-define(SKYRUSH_MON_LIST, [[43004, 41, 54, 1, undifined], [43004, 43, 55, 1, undifined],
						   [43005, 46, 58, 1, undifined], [43004, 48, 60, 1, undifined], [43005, 50, 65, 1, undifined],
						   [43004, 64, 107, 1, undifined], [43005, 66, 109, 1, undifined], 
						   [43004, 68, 112, 1, undifined], [43004, 70, 115, 1, undifined], [43004, 73, 122, 1, undifined],
						   [43004, 18, 27, 1, undifined], [43005, 20, 30, 1, undifined], 
						   [43005, 22, 34, 1, undifined], [43004, 38, 45, 1, undifined], [43005, 25, 41, 1, undifined]]). %%小怪列表

-record(state, {sm_pids = ?SKYRUSH_MON_LIST, drop_id = 1}). %%上一次刷出的场景小怪的pid列表

%% ====================================================================
%% External functions
%% ====================================================================


%% ====================================================================
%% Server functions
%% ====================================================================
init_skyrush_mon() ->
	 gen_server:start_link({global, ?MODULE}, ?MODULE, [], []).

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
	Self = self(),
	%% 初始战场
	SceneProcessName = mod_skyrush_mon,
	misc:register(global, SceneProcessName, Self),
	%%开始结束战斗的定时器
	NowSec = util:get_today_current_second(),
	[_WeekDate, _SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = lib_skyrush:get_start_end_time(),
	ReTime = SKY_RUSH_END_TIME - NowSec,
%% 	io:format("init mod_skyrush_mon\n"),
	erlang:send_after(5000, self(), {'REFLESH_LITTLE_MON'}),
	erlang:send_after(ReTime * 1000, self(), {'END_SKY_RUSH'}),
	SkyRush = #state{},
    {ok, SkyRush}.

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
handle_info({'REFLESH_LITTLE_MON'}, State) ->
%% 	io:format("REFLESH_LITTLE_MON\n", []),
	%%结束战斗,屏蔽消息
	NowSec = util:get_today_current_second(),
	[_WeekDate, SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = lib_skyrush:get_start_end_time(),
	case NowSec >= SKY_RUSH_START_TIME + 5*60 andalso NowSec =< SKY_RUSH_END_TIME of
		true  ->
			{Num, NewSMPids} = lib_skyrush:init_little_mon(State#state.sm_pids),
			NewState = State#state{sm_pids = NewSMPids},
			case Num =/= 0 of
				true ->%%当=于0的时候就不广播
					lib_skyrush:send_skyrush_notice(11, []);
				false ->
					skip
			end,
			erlang:send_after(?LMON_REFLESH_TIME, self(), {'REFLESH_LITTLE_MON'}),
			{noreply, NewState};
		false ->
			 {noreply, State}
	end;
%%战场结束
handle_info({'END_SKY_RUSH'}, State) ->
	erlang:send_after(60000, self(), {'END_THE_PRO'}),
	{noreply, State};

handle_info({'END_THE_PRO'}, State) ->
	{stop, normal, State};
handle_info(_Info, State) ->
	
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
%% 	io:format("END_THE_PRO\n"),
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

