%%% -------------------------------------------------------------------
%%% Author  : ygzj
%%% Description : 答题模块
%%% Created : 2011-4-8
%%% -------------------------------------------------------------------
-module(mod_answer).

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
		get_mod_answer_pid/0,
		load_base_answer/1,
		answer_join/1,
		answer_commit/6,
		answer_exit/1	,
		test/1,
		check_answer_time_info/1,
		send_answer_result/0,
		get_answer_data_by_type/1,
		repeat_answer/1,
		get_answer_hour_time_by_dict/0,
		get_mod_answer_data_by_type/1
	]
).

-define(ANSWER_HOUR_TIME,12*3600+15*60). %%设定答题时间值
-define(ANSWER_SUM,30).%%答题数量限制
-define(ANSWER_LV,30).%%答题等级限制
-define(ANSWER_DATA,[1,3,5]).%%星期1,3,5答题


%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include("common.hrl").
-include("record.hrl").
%% 定时器间隔时间
-define(INTERVAL, 10000).
-define(LONG_INTERVAL, 120000).

-record(state, {}).

get_answer_data_by_type(Type) ->
	if
		%%活动开始时间从字典中取值，如果没有则从宏定义中取值
		Type == answer_hour_time -> 
			Answer_hour_time = get(answer_hour_time),
			if Answer_hour_time == undefined ->
				   ?ANSWER_HOUR_TIME;
			   true ->
				   Answer_hour_time
			end;		
		Type == answer_notify_start -> get_answer_data_by_type(answer_hour_time) + 2*60; %%答题前二分钟广播（9:12）15*3600+10*60
		Type == answer_join_start -> get_answer_data_by_type(answer_hour_time) + 4*60;   %%答题报名开始时间广播（9:14）21*3600+14*60
		Type == answer_start -> get_answer_data_by_type(answer_hour_time) + 5*60;        %%答题开始时间广播（9:15）21*3600+14*60
		Type == answer_end -> get_answer_data_by_type(answer_hour_time) + 20*60;        %%答题结束时间广播（9:30）21*3600+30*60
		Type == answer_end_finish -> get_answer_data_by_type(answer_hour_time) + 20*60 + 10; %%答题结束检查时间20*3600+30*60
		Type == answer_sum -> ?ANSWER_SUM;
		Type == answer_lv -> ?ANSWER_LV;
		Type == answer_data -> ?ANSWER_DATA;
		true ->
			0
	end.	

%%重启答题活动(不能小于130s)
%%mod_answer:repeat_answer(17*3600+43*60).  
repeat_answer(Time) ->
	NowSec = util:get_today_current_second(),
	if Time - NowSec < 130 ->
		   fail;
	   true ->
		    case restart_answer(Time) of
               [] ->
				   fai;
                _ ->
                   ok
            end
	end.

%% ====================================================================
%% External functions
%% ====================================================================


%% ====================================================================
%% Server functions
%% ====================================================================
%%启动答题服务
start_link([ProcessName, Worker_id]) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [ProcessName, Worker_id], []).

start([ProcessName, Worker_id]) ->
    gen_server:start(?MODULE, [ProcessName, Worker_id], []).

%%停止服务
stop() ->
    gen_server:call(?MODULE, stop).

%%开户答题全局模块
get_mod_answer_pid() ->
	ProcessName = misc:create_process_name(mod_answer_process, [0]),
	case misc:whereis_name({global, ProcessName}) of
		Pid when is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true -> Pid;
				false -> 
					start_mod_answer(ProcessName)
			end;
		_ ->
			start_mod_answer(ProcessName)
	end.

%%启动全局进程(加锁保证全局唯一)
start_mod_answer(ProcessName) ->
	global:set_lock({ProcessName, undefined}),	
	ProcessPid =
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> Pid;
					false -> 
						start_answer(ProcessName)
				end;
			_ ->
				start_answer(ProcessName)
		end,	
	global:del_lock({ProcessName, undefined}),
	ProcessPid.


start_answer(ProcessName) ->
	 case supervisor:start_child(
               yg_server_sup,
               {mod_answer,
                {mod_answer, start_link,[[ProcessName, 0]]},
                permanent, 10000, supervisor, [mod_answer]}) of
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
init([ProcessName, WorkerId]) ->
	process_flag(trap_exit, true),	
	case misc:register(unique, ProcessName, self()) of
		yes ->
			if 
				WorkerId =:= 0 ->
					erlang:send_after(?INTERVAL, self(), 'DETECT_INTERVAL');
					%%misc:write_monitor_pid(self(), mod_answer, {}),
					%%misc:write_system_info(self(), mod_answer, {});
				true->
			 		%%misc:write_monitor_pid(self(), mod_answer_child, {WorkerId}),
					skip
			end,
			ets:new(?ETS_BASE_ANSWER, [named_table, public, set, {keypos,#ets_base_answer.id}]),
			ets:new(?ETS_ANSWER, [named_table, public, set, {keypos,#ets_answer.player_id}]), 
			erlang:send_after(lib_hook:get_open_time(),self(),{'HOOKING_OPEN'}),
			erlang:send_after(lib_hook:get_end_time(),self(),{'HOOKING_END'}),
%% 			Handle = erlang:send_after(lib_find_exp:get_update_time(),self(),{'update_find_exp'}),
%% 			put(update_find_exp,Handle),
%% 			Handle1 = erlang:send_after(lib_find_exp:get_update_time_1(),self(),{'update_find_exp_1'}),
%% 			put(update_find_exp_1,Handle1),
			io:format("6.Init mod_answer finish!!!~n"),
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
?WARNING_MSG("mod_answer_apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
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
?WARNING_MSG("mod_answer_apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
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
%% 答题定时器
handle_info('DETECT_INTERVAL', State) ->
	NowSec = util:get_today_current_second(),
	BUSINESS_DOUBLE_START_CHANGE = ?BUSINESS_DOUBLE_START_CHANGE,
	BUSINESS_DOUBLE_END_CHANGE = ?BUSINESS_DOUBLE_END_CHANGE,
	ANSWER_NOTIFY_START = get_answer_data_by_type(answer_notify_start),
	ANSWER_END_FINISH = get_answer_data_by_type(answer_end_finish),
	INTERVAL = 
		if
			%% 运镖
			NowSec > ?CARRY_BC_START_CHANGE andalso NowSec < ?CARRY_BC_END_CHANGE ->
				broadcast_sys_msg(NowSec),
				?INTERVAL;
			%% 答题
			NowSec > ANSWER_NOTIFY_START - 120  andalso NowSec < ANSWER_END_FINISH ->
				WeekDay = util:get_date(),
				case lists:member(WeekDay, ?ANSWER_DATA) of
					true ->
						broadcast_msg(NowSec),
						?INTERVAL;
					false ->
		   				?LONG_INTERVAL	
				end;
			%% 跑商
			NowSec > BUSINESS_DOUBLE_START_CHANGE andalso NowSec < BUSINESS_DOUBLE_END_CHANGE ->
				case util:get_date() of
					?BUSINESS_DOUBLE_DAY ->
						broadcast_business_msg(NowSec),
						?INTERVAL;
					_ ->
						?LONG_INTERVAL
				end;
			true ->
				?LONG_INTERVAL
		end,
	erlang:send_after(INTERVAL, self(), 'DETECT_INTERVAL'),
	{noreply,State};

%%推送答题信息 
%%Order表示题库顺序 从1-30
handle_info({'send_answer',Order,_Type},State)->
	BaseAnswerList = ets:match(?ETS_BASE_ANSWER, _='$1'),
	[Ets_Base_Answer] =  lists:nth(Order,BaseAnswerList),
	case BaseAnswerList of
		[] -> skip;
		_ ->
			if Order >= 1 andalso Order =< 30 ->
				   [Ets_Base_Answer] =  lists:nth(Order,BaseAnswerList),
				   send_answer_info(Order,Ets_Base_Answer),
				   %%推送题目 并启动阅题倒计时
				   erlang:send_after(0, self(), {'send_timer',10 ,5}),%%阅题开始倒计时
				   erlang:send_after(10000, self(), {'send_timer',15,6}),%%答题开始倒计时
				   erlang:send_after(25000, self(), {'statics_answer',Order}),%%答题统计(提前1秒开始统计)
				   erlang:send_after(25000, self(), {'send_timer',5,7}),%%等待出题倒计时
				   if Order == 30 ->  skip;%%超过30停止出题
					  true ->  erlang:send_after(30000, self(), {'send_answer',Order+1,0})
				   end;
			   true -> skip
			end
	end,
	{noreply,State};

%% 推送答题信息 
%% Order 表示题库顺序 从1-30
handle_info({'statics_answer',Order},State)->
	lib_answer:statics_answer(Order),%%同时将每题的选择累计数,正确答案推送客户端
	{noreply,State};


%% 答题倒计时
handle_info({'send_timer',TimeValue,Type},State)->
	broadcast_answer_time(Type,TimeValue),
    {noreply,State};

%%挂机区开放系统通知
handle_info({'HOOKING_OPEN'},State)->
	lib_hook:opening_msg(1),
	{ok,BinData} = pt_12:write(12401,[1]),
	mod_disperse:broadcast_to_world(ets:tab2list(?ETS_SERVER), BinData),
	lib_send:send_to_local_all(BinData),
	erlang:send_after(lib_hook:get_open_time(),self(),{'HOOKING_OPEN'}),
	{noreply,State};

%%挂机区结束系统通知
handle_info({'HOOKING_END'},State)->
	lib_hook:opening_msg(2),
	{ok,BinData} = pt_12:write(12401,[0]),
	mod_disperse:broadcast_to_world(ets:tab2list(?ETS_SERVER), BinData),
	erlang:send_after(lib_hook:get_end_time(),self(),{'HOOKING_END'}),
	{noreply,State};

%%更新玩家经验找回
%% handle_info({'update_find_exp'},State)->
%% 	misc:cancel_timer(update_find_exp),
%% 	lib_find_exp:find_exp_all_1(),
%% 	Handle = erlang:send_after(86400*1000,self(),{'update_find_exp'}),
%% 	put(update_find_exp,Handle),
%% 	{noreply,State};
%% 
%% handle_info({'update_find_exp_1'},State)->
%% 	misc:cancel_timer(update_find_exp_1),
%% 	lib_find_exp:find_exp_all_2(),
%% 	Handle = erlang:send_after(86400*1000,self(),{'update_find_exp_1'}),
%% 	put(update_find_exp_1,Handle),
%% 	{noreply,State};

handle_info(_Info, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(Reason, State) ->
	misc:delete_monitor_pid(self()),
	?WARNING_MSG("ANSWER_TERMINATE: Reason ~p~n State ~p~n", [Reason, State]),
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

%%广播答题系统消息
broadcast_msg(NowSec)->
	ANSWER_NOTIFY_START = get_answer_data_by_type(answer_notify_start),
	ANSWER_JOIN_START = get_answer_data_by_type(answer_join_start),
	ANSWER_START = get_answer_data_by_type(answer_start),
	ANSWER_END = get_answer_data_by_type(answer_end),
	ANSWER_END_FINISH = get_answer_data_by_type(answer_end_finish),
	if  (NowSec >= ANSWER_NOTIFY_START) andalso (NowSec - ANSWER_NOTIFY_START) < 10 ->
			put(timerdelay,NowSec - ANSWER_NOTIFY_START),
			lib_answer:init_answer(),      %% 创建答题ets
			load_base_answer(?ANSWER_SUM),%%初始化答题数据
			broadcast_answer_time(1,120),
			Msg = "<font color='#FEDB4F'>本服答题活动将会在2分钟后开启,欢迎诸神共同参与！</font>";
		(NowSec >= ANSWER_JOIN_START) andalso (NowSec - ANSWER_JOIN_START) < 10 ->
			broadcast_answer_time(2,60),
			Msg = "<font color='#FEDB4F'>本服答题活动开始报名,欢迎诸神共同参与！</font>";
		(NowSec >= ANSWER_START) andalso (NowSec - ANSWER_START) < 10 ->
			broadcast_answer_time(8,15*60),
			show(1),
			erlang:send_after(0, self(), {'send_answer',1,0}),%%推送答题1信息,
			Msg = "<font color='#FEDB4F'>本服答题活动正在进行中,欢迎诸神共同参与！</font>";
		(NowSec >= ANSWER_END) andalso (NowSec - ANSWER_END_FINISH) < 10 ->
			broadcast_answer_time(4,5),
			send_answer_result(),%%活动结束，显示答对题数，分数，经验，灵力,答题60*5秒后删除答题基础数据
			Msg = "<font color='#FEDB4F'>本服答题活动已经结束,感谢大家的参与！</font>";
		true->
			Msg = []
	end,
	case Msg of
		[]->skip;
		_->
			lib_chat:broadcast_sys_msg(6,Msg)
	end.

%% 活动结束，显示答对题数，分数，经验，灵力
send_answer_result() ->
	lib_answer:send_answer_result().

%% 通知客户端显示logo,打开,关闭答题窗口
show(Type) ->
	AnswerList = ets:match(?ETS_ANSWER,_='$1'),
	case AnswerList of
		[] ->
			skip;
		_->
			F = fun(Ets_Answer) ->
						{ok, BinData} = pt_37:write(37005,[Type,0,0,0]),
						lib_send:send_to_uid(Ets_Answer#ets_answer.player_id, BinData)
				end,
			[F(Ets_Answer) || [Ets_Answer] <- AnswerList]
	end.
	   
%% 答题活动时间广播Type 1表示全服显示，2表示部分人显示
broadcast_answer_time(Type,Timestamp)->
	if Type == 1  orelse Type == 2  orelse Type == 8 ->
		   {ok, BinData} = pt_37:write(37002, [Type,Timestamp]),
		   mod_disperse:broadcast_to_world(ets:tab2list(?ETS_SERVER), BinData),
		   lib_send:send_to_local_all(BinData);
	  Type == 3 orelse Type == 4 orelse Type == 5 orelse Type == 6 orelse Type == 7->
		   AnswerList = ets:match(?ETS_ANSWER,_='$1'),
		   case AnswerList of
			   [] ->
				   skip;
			   _ ->
				   F = fun(Ets_Answer) ->
								{ok, BinData} = pt_37:write(37002, [Type,Timestamp]),
								lib_send:send_to_uid(Ets_Answer#ets_answer.player_id, BinData)
						end,
				   [F(Ets_Answer) || [Ets_Answer] <- AnswerList]
		   end;
	   true -> skip
	end.	   


%% 加载基础题库
load_base_answer(Sum) ->
	Data = lib_answer:load_base_answer(Sum),
	case Data of
		[] -> skip;
		_ ->
			F = fun([Id,Reply,Quest,Opt1,Opt2,Opt3,Opt4,Order]) ->
				EtsBaseAnswer = #ets_base_answer{
					id = Id,
      				reply = Reply,       
	  				quest = Quest,
					opt1 = Opt1,
					opt2 = Opt2,
					opt3 = Opt3,
					opt4 = Opt4,
					order = Order	
				},
				ets:insert(?ETS_BASE_ANSWER,EtsBaseAnswer)
			end,
			[F(Base_Answer) || Base_Answer <- Data]
	end.

%% 推送题目
send_answer_info(Order,Ets_Base_Answer) ->
	try 
		gen_server:cast(mod_answer:get_mod_answer_pid(), 
					 {apply_cast, lib_answer, send_answer_info, [Order,Ets_Base_Answer]})
	catch
		_:_ -> []
	end.	

%% 报名
answer_join(Player) ->
	try 
		gen_server:cast(mod_answer:get_mod_answer_pid(), 
			{apply_cast, lib_answer, answer_join, [Player#player.id, Player#player.nickname, Player#player.lv, Player#player.realm, Player#player.other#player_other.pid_send]})
	catch
		_:_ -> []
	end.	

%% 答题提交
answer_commit(Player, Order, BaseAnswerId, Opt, Tool, Reference_id) ->
	try 
		gen_server:call(mod_answer:get_mod_answer_pid(), 
			{apply_call, lib_answer, answer_commit, [Player#player.id, Order, BaseAnswerId, Opt, Tool, Reference_id]})
	catch
		_:_ -> []
	end.	

%% 答题活动退出
answer_exit(Player) ->
	try 
		gen_server:call(mod_answer:get_mod_answer_pid(), 
				{apply_call, lib_answer, answer_exit, [Player#player.id, Player#player.status]})
	catch
		_:_ -> []
	end.	

%%重启答题活动
restart_answer(Time) ->
	try 
		gen_server:call(mod_answer:get_mod_answer_pid(), 
				{apply_call, lib_answer, put_answer_hour_time, [Time]})
	catch
		_:_ -> []
	end.	

get_answer_hour_time_by_dict() ->
	try 
		gen_server:call(mod_answer:get_mod_answer_pid(), 
				{apply_call, lib_answer, get_answer_hour_time_by_dict, []})
	catch
		_:_ -> error
	end.

get_mod_answer_data_by_type(Type) ->
	try 
		gen_server:call(mod_answer:get_mod_answer_pid(), 
				{apply_call, lib_answer, get_mod_answer_data_by_type, [Type]})
	catch
		_:_ -> error
	end.

%% 重新登陆检查是否在答题时间内
check_answer_time_info(Player) ->
	try 
		gen_server:cast(mod_answer:get_mod_answer_pid(), {apply_cast, lib_answer, check_answer_time, 
				[Player]})
	catch
		_:_ -> []
	end.	

test(Order) ->
	AnswerList = ets:match(ets_answer,_='$1'), 
	lib_answer:handleTool3(Order,AnswerList,{"A",0},{"B",0},{"C",0},{"D",0}),
	ok.

%% 部落国运时间广播
broadcast_carry_time(Timestamp)->
	{ok, BinData} = pt_30:write(30300, [1,1,Timestamp]),
	mod_disperse:broadcast_to_world(ets:tab2list(?ETS_SERVER), BinData),
	lib_send:send_to_local_all(BinData).

%% 跑商双倍时间广播
broadcast_business_time(Result, Timestamp)->
	{ok, BinData} = pt_30:write(30702, [Result, Timestamp]),
	mod_disperse:broadcast_to_world(ets:tab2list(?ETS_SERVER), BinData),
	lib_send:send_to_local_all(BinData).

%%广播国运系统消息
broadcast_sys_msg(NowSec)->
	if  
		(NowSec >= ?CARRY_BC_START_THREE) andalso (NowSec - ?CARRY_BC_START_THREE) =< 10 ->
			Msg = "<font color='#FEDB4F'>全体部落国运三倍运镖活动将会在3分钟后开启,欢迎诸神共同参与！</font>";
		(NowSec >= ?CARRY_BC_START_ONE) andalso (NowSec - ?CARRY_BC_START_ONE) =< 10 ->
			Msg = "<font color='#FEDB4F'>全体部落国运三倍运镖活动将会在1分钟后开启,欢迎诸神共同参与！</font>";
		(NowSec >= ?CARRY_BC_START) andalso (NowSec - ?CARRY_BC_START) =< 10 ->
			broadcast_carry_time(1500),
			Msg = "<font color='#FEDB4F'>全体部落国运三倍运镖活动开启,欢迎诸神共同参与！</font>";
		(NowSec >= ?CARRY_BC_END_THREE) andalso (NowSec - ?CARRY_BC_END_THREE) =< 10 ->
			Msg = "<font color='#FEDB4F'>全体部落国运三倍运镖活动将会在3分钟后关闭！</font>";
		(NowSec >= ?CARRY_BC_END_ONE) andalso (NowSec - ?CARRY_BC_END_ONE) =< 10 ->
			Msg = "<font color='#FEDB4F'>全体部落国运三倍运镖活动将会在1分钟后关闭！</font>";
		(NowSec >= ?CARRY_BC_END) andalso (NowSec - ?CARRY_BC_END) < 10 ->
			broadcast_carry_time(0),
			Msg = "<font color='#FEDB4F'>全体部落国运三倍运镖活动已经结束,感谢大家的参与！</font>";
		true->Msg=[]
	end,
	case Msg of
		[] -> 
			skip;
		_ ->
			lib_chat:broadcast_sys_msg(2, Msg)
	end.

%% 跑商广播系统消息
broadcast_business_msg(NowSec) ->
	BUSINESS_DOUBLE_BROAD_TIME = ?BUSINESS_DOUBLE_BROAD_TIME,
	BUSINESS_DOUBLE_START_TIME = ?BUSINESS_DOUBLE_START_TIME,
	BUSINESS_DOUBLE_END_TIME = ?BUSINESS_DOUBLE_END_TIME,
	if 
		(NowSec >= BUSINESS_DOUBLE_BROAD_TIME) andalso ((NowSec - BUSINESS_DOUBLE_BROAD_TIME) =< 10) ->
			Msg = "<font color='#FEDB4F'>全体部落跑商双倍活动将会在3分钟后开启,欢迎诸神共同参与！</font>";
		(NowSec >= BUSINESS_DOUBLE_START_TIME) andalso ((NowSec - BUSINESS_DOUBLE_START_TIME) =< 10) ->
			broadcast_business_time(1, BUSINESS_DOUBLE_END_TIME - NowSec),
			Msg = "<font color='#FEDB4F'>全体部落跑商双倍活动开启,欢迎诸神共同参与！</font>";
		(NowSec >= BUSINESS_DOUBLE_END_TIME) andalso ((NowSec - BUSINESS_DOUBLE_END_TIME) =< 10) ->
			broadcast_business_time(0, 0),
			Msg = "<font color='#FEDB4F'>全体部落跑商双倍活动已经结束,感谢大家的参与！</font>";
		true->
			Msg = []
	end,
	case Msg of
		[] ->
			skip;
		_ ->
			lib_chat:broadcast_sys_msg(2, Msg)
	end.
