%%% -------------------------------------------------------------------
%%% Author  : xianrongMai
%%% Description :处理当前全服的称号消息通知
%%%
%%% Created : 2011-10-8
%%% -------------------------------------------------------------------
-module(mod_title).

-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------

-include("common.hrl").
-include("record.hrl").
-include("achieve.hrl").

-record(timer, {hot_spring = 0,
				warfare = 0}).
-define(ACTION_TIMER, 10000).
%% --------------------------------------------------------------------
%% External exports
-export([start_link/0,
		 stop/0,
		 get_mod_title_pid/0
		 ]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).


%% ====================================================================
%% External functions
%% ====================================================================
start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

stop() ->
    gen_server:call(?MODULE, stop).

%%动态加载称号处理进程 
get_mod_title_pid() ->
	ProcessName = mod_title,
	case misc:whereis_name({global, ProcessName}) of
		Pid when is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true -> Pid;
				false -> 
					start_mod_title(ProcessName)
			end;
		_ ->
			start_mod_title(ProcessName)
	end.

%%启动称号监控模块 (加锁保证全局唯一)
start_mod_title(ProcessName) ->
	global:set_lock({ProcessName, undefined}),	
	ProcessPid =
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> Pid;
					false -> 
						start_title()
				end;
			_ ->
				start_title()
		end,	
	global:del_lock({ProcessName, undefined}),
	ProcessPid.

%%开启称号监控监控模块
start_title() ->
    case supervisor:start_child(
               yg_server_sup,
               {mod_title,
                {mod_title, start_link,[]},
                permanent, 10000, supervisor, [mod_title]}) of
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
%%  	io:format("init the title module..\n"),
	process_flag(trap_exit, true),	
	ProcessName = mod_title,		%% 多节点的情况下， 仅启用一个称号处理进程
 	case misc:register(unique, ProcessName, self()) of
		yes ->
			%%初始化称号的数据
%% 			io:format("2.Init mod_title begin !!!~n"),
			NewState = init_title_data(),
%% 			?DEBUG("NewState:~p", [NewState]),
			misc:write_monitor_pid(self(),?MODULE, {}),
			misc:write_system_info(self(), mod_title, {}),	
			Timer = #timer{},
			TimerRef = erlang:send_after(?ACTION_TIMER, self(), {action, Timer}),
			put(timer_action, TimerRef),%%放进程字典
			io:format("2.Init mod_title finish!!!~n"),
    		{ok, NewState};
		_ ->
			{stop,normal,#server_titles{}}
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
	%% ?DEBUG("****************mod_sale_apply_call:[~p,~p]*********", [Module, Method]),
	Reply = 
		case (catch apply(Module, Method, Args)) of
			{'EXIT', Info} ->
				?WARNING_MSG("mod_sale_apply_call: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
				error;
			DataRet -> DataRet
		end,
	{reply, Reply, State};

handle_call({'GET_TITLES_PLAYERS', Type}, _From, State) ->
	Reply = 
		case Type of
			fst ->
				State#server_titles.fst;				%%封神霸主
			area_king ->
				State#server_titles.area_king;		%%天下无敌
			nwfirst ->
				State#server_titles.nwfirst;		%%女娲英雄
			snfirst ->
				State#server_titles.snfirst;		%%神农英雄 
			fxfirst ->
				State#server_titles.fxfirst;		%%伏羲英雄
			rich ->
				State#server_titles.rich;			%%不差钱
			ach ->
				State#server_titles.ach;			%%八神之主
			equip ->
				State#server_titles.equip;			%%绝世神兵
			zxt ->
				State#server_titles.zxt;			%%诛仙霸主
			adore ->
				State#server_titles.adore;			%%全民偶像
			disdain ->
				State#server_titles.disdain;		%%全民公敌
			ygzs ->
				State#server_titles.ygzs;			%%远古战神
			castle ->
				State#server_titles.castle;			%%九霄城主
			world_first ->
				State#server_titles.world_first;	%%天下第一
			yg_unique ->
				State#server_titles.yg_unique;		%%远古无双
			mount_king ->
				State#server_titles.mount_king;		%%一骑绝尘
			_ ->
				[]
		end,
	{reply, {ok, Reply}, State};

handle_call({'GET_ALL_TITLES'}, _From, State) ->
	{reply, {ok, State}, State};

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
	%% ?DEBUG("mod_sale__apply_cast: [~p/~p/~p]", [Module, Method, Args]),	
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_sale__apply_cast error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
			 error;
		 _ -> ok
	end,
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

%%接收处理需要更新全服称号集
handle_cast({'UPDATE_SERVER_TITLES', Param}, State) ->
	{Fst, NWFirst, SNFirst, FXFirst, Rich, Ach, Equip, Zxt, YGZS} = Param,
	%% 	?DEBUG("UPDATE_SERVER_TITLES: {TType:~p, NewIds:~p}", [TType, NewIds]),
	AreaKing = lib_arena:get_arena_king(),		%%天下无敌
	{Adore, Disdain}= mod_appraise:get_all_max_appraise(),			%%{全民偶像,全民公敌}
	Castle = lib_castle_rush:get_castle_rush_king_id(),%%九霄城主
	WorldFirst = lib_coliseum:get_coliseum_king(),	%%天下第一
	YGUnique = mod_war2_supervisor:get_champoin(),%%远古无双
	MountKing = lib_mount_arena:get_mount_king(),	%%一骑绝尘
	NState = lib_title:update_server_titles({Fst, AreaKing, NWFirst, SNFirst, FXFirst, Rich, Ach, 
											 Equip, Zxt, Adore, Disdain, YGZS, Castle, WorldFirst, YGUnique, MountKing}, State),
%% 	?DEBUG("NState:~p", [NState]),
	{noreply, NState};

handle_cast({'KILL_SNOWMAN', X, Y}, State) ->
	lib_activities:update_snowman_num(X, Y),
	{noreply, State};

handle_cast({'KILL_LITTLE_DEVIL'}, State) ->
	lib_activities:kill_little_devil(),
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
handle_info({action, Timer}, State) ->
	NowSec = util:get_today_current_second(),
	#timer{hot_spring = HotSpring,
		   warfare = Warfare} = Timer,
	%%温泉开放处理
	NHotSpring = lib_spring:start_spring(HotSpring, NowSec),
	%%神魔乱斗怪物控制器处理
	NWarfare = lib_warfare:start_warfare_mon(Warfare, NowSec),
	%%修改新的timer
	NTimer = Timer#timer{hot_spring = NHotSpring,
						 warfare = NWarfare},
	%%先去掉定时器.
	misc:cancel_timer(timer_1_action),
	%%刷新小魔头
%% 	lib_activities:reflesh_littledevil(NowSec),
	%%三月活动奖励奖励
	lib_activities:check_march_event_award(),
	
	TimerRef = erlang:send_after(?ACTION_TIMER, self(), {action, NTimer}),
	put(timer_action, TimerRef),%%放进程字典
	{noreply, State};

%%刷新雪人的 操作
handle_info({'REFLESH_SNOWMAN'}, State) ->
	lib_activities:make_snowman(),
	{noreply, State};

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
init_title_data() ->
	Fields = "type, pid",
	case db_agent:load_server_titles(Fields, ?SERVER_TITLE_IDS) of
		[] ->	
%% 			?DEBUG("NO DATA", []),
%% 			lists:foreach(fun(Elem) ->
%% 								  db_agent:init_title_data(Elem)
%% 						  end, ?SERVER_TITLE_IDS),
			#server_titles{};
		List when is_list(List) ->
%% 			?DEBUG("Lists:~p", [List]),
			lists:foldl(fun(Elem, AccIn) ->
								[TNum, Pid] = Elem,
								case TNum of
									901 ->
										Data = [Pid|AccIn#server_titles.fst],
										AccIn#server_titles{fst = Data};
									902 ->
										Data = [Pid|AccIn#server_titles.area_king],
										AccIn#server_titles{area_king = Data};
									903 ->
										Data = [Pid|AccIn#server_titles.nwfirst],
										AccIn#server_titles{nwfirst = Data};
									904 ->
										Data = [Pid|AccIn#server_titles.snfirst],
										AccIn#server_titles{snfirst = Data};
									905 ->
										Data = [Pid|AccIn#server_titles.fxfirst],
										AccIn#server_titles{fxfirst = Data};
									906 ->
										Data = [Pid|AccIn#server_titles.rich],
										AccIn#server_titles{rich = Data};
									907 ->
										Data = [Pid|AccIn#server_titles.ach],
										AccIn#server_titles{ach = Data};
									908 ->
										Data = [Pid|AccIn#server_titles.equip],
										AccIn#server_titles{equip = Data};
									909 ->
										Data = [Pid|AccIn#server_titles.zxt],
										AccIn#server_titles{zxt = Data};
									910 ->
										Data = [Pid|AccIn#server_titles.adore],
										AccIn#server_titles{adore = Data};
									911 ->
										Data = [Pid|AccIn#server_titles.disdain],
										AccIn#server_titles{disdain = Data};
									912 ->
										Data = [Pid|AccIn#server_titles.ygzs],
										AccIn#server_titles{ygzs = Data};
									913 -> 
										Data = [Pid|AccIn#server_titles.castle],
										AccIn#server_titles{castle = Data};
									914 ->
										Data = [Pid|AccIn#server_titles.world_first],
										AccIn#server_titles{world_first = Data};
									915 ->
										Data = [Pid|AccIn#server_titles.yg_unique],
										AccIn#server_titles{yg_unique = Data};
									916 ->
										Data = [Pid|AccIn#server_titles.mount_king],
										AccIn#server_titles{mount_king = Data};
									_ ->
										AccIn
								end
						end, #server_titles{}, List);
		_ ->
			#server_titles{}
	end.