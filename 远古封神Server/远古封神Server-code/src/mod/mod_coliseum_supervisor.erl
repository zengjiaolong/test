%%%------------------------------------
%%% @Module  : mod_coliseum_supervisor
%%% @Author  : ygfs
%%% @Created : 2012.02.26
%%% @Description: 竞技场主进程
%%%------------------------------------
-module(mod_coliseum_supervisor).

-behaviour(gen_server).
-include("common.hrl").
-include("record.hrl").

-export(
	[
	 	init/1, 
		handle_call/3, 
		handle_cast/2, 
		handle_info/2, 
		terminate/2,
		code_change/3,
		test/0
	]
).
-export(
    [
   		start_link/1,
		start_worker/3,
	 	get_mod_coliseum_supervisor_pid/0,
		get_coliseum_worker_pid/0,
		get_coliseum_cal_worker_pid/0
    ]
).

-record(state, {
	worker_id = 0,
	award_time = 0														%% 领取奖励时间				
}).

-define(COLISEUM_CHALLENGE_LEN, 5).										%% 挑战人数长度
-define(COLISEUM_INTERVAL, 20).											%% 竞技场间隔
-define(COLISEUM_RANK_INTERVAL, 900).									%% 竞技场排行更新间隔
-define(COLISEUM_AWARD_DAY, 3).											%% 竞技场奖励时间
-define(COLISEUM_WORKER_NUMBER, 100).									%% 竞技场工作进程数
-define(COLISEUM_CAL_WORKER_ID, ?COLISEUM_WORKER_NUMBER + 1).			%% 竞技场计算结果的进程ID
-define(COLISEUM_RANK_ID, ?COLISEUM_CAL_WORKER_ID + 1).					%% 竞技场更新排行榜的进程ID
-define(COLISEUM_SEC, 69000).											%% 竞技场奖励领取时间
-define(COLISEUM_RANK_NUM, 20).											%% 竞技场排行榜获取数目

%% 启动战场监控服务
start_link(ProcessName) ->
	AwardTime = get_award_time(),
    gen_server:start_link({local, ?MODULE}, ?MODULE, [ProcessName, 0, AwardTime], []).

start_worker(WorkProcessName, WorkId, AwardTime) ->
	gen_server:start_link(?MODULE, [WorkProcessName, WorkId, AwardTime], []).

init([ProcessName, WorkerId, AwardTime]) ->
	process_flag(trap_exit, true),
	Self = self(),
	misc:register(global, ProcessName, Self),
	if
		WorkerId =:= 0 ->
			ets:new(?ETS_COLISEUM_RANK, [{keypos, #ets_coliseum_rank.player_id}, named_table, public, set, ?ETSRC, ?ETSWC]),
			ets:new(?ETS_COLISEUM_INFO, [{keypos, #ets_coliseum_info.id}, named_table, public, set, ?ETSRC, ?ETSWC]),
			ets:new(?ETS_COLISEUM_DATA, [{keypos, #ets_coliseum_data.id}, named_table, public, set, ?ETSRC, ?ETSWC]),
			misc:write_monitor_pid(Self, mod_coliseum_supervisor, {}),
			misc:write_system_info(Self, mod_coliseum_supervisor, {}),
			%% 初始竞技场数据
			spawn(fun()-> init_coliseum_data(AwardTime) end),
			
			%% 启动竞技场服务工作进程
            lists:foreach(
                fun(WorkId) ->
					WorkProcessName = misc:create_process_name(coliseum_worker, [WorkId]),
         			mod_coliseum_supervisor:start_worker(WorkProcessName, WorkId, AwardTime)
                end,
            lists:seq(1, ?COLISEUM_WORKER_NUMBER)),
			
			%% 专门启动计算挑战结果的进程
			CalWorkProcessName = misc:create_process_name(coliseum_worker, [?COLISEUM_CAL_WORKER_ID]),
         	mod_coliseum_supervisor:start_worker(CalWorkProcessName, ?COLISEUM_CAL_WORKER_ID, AwardTime),
			
			%% 定时更新排行榜的进程
			RankProcessName = misc:create_process_name(coliseum_worker, [?COLISEUM_RANK_ID]),
         	mod_coliseum_supervisor:start_worker(RankProcessName, ?COLISEUM_RANK_ID, AwardTime),
			
			erlang:send_after(?COLISEUM_INTERVAL * 1000, Self, 'COLISEUM_INTERVAL'),
			
			io:format("13.Init mod_coliseum_supervisor finish!!!~n");
		WorkerId =:= ?COLISEUM_RANK_ID ->
			erlang:send_after(?COLISEUM_RANK_INTERVAL * 1000, Self, 'COLISEUM_RANK_INTERVAL');
		true ->
			skip
	end,
	State = #state{
        worker_id = WorkerId,
		award_time = AwardTime		   
    },
    {ok, State}.
	
%% 统一模块+过程调用(call)
handle_call({apply_call, Module, Method, Args}, _From, State) ->
	Reply  = 
        case (catch apply(Module, Method, Args)) of
             {'EXIT', Info} ->	
?WARNING_MSG("mod_coliseum_supervisor apply_call error: Module=~p, Method=~p, Reason=~p, Args = ~p",[Module, Method, Info, Args]),
                 error;
             DataRet -> 
                 DataRet
        end,
    {reply, Reply, State};

%% 竞技场检查
handle_call({'CHECK_COLISEUM_ENTER', ChallengerId, ChallengeredId}, _From, State) ->
	%% 挑战方
	case ets:lookup(?ETS_COLISEUM_RANK, ChallengerId) of
		[] ->
			{reply, 2, State};
		[Challenger1 | _] ->
			%% 被挑战方
			case ets:lookup(?ETS_COLISEUM_RANK, ChallengeredId) of
				[] ->
					{reply, 2, State};
				[Challenger2 | _] ->
					Rank1 = Challenger1#ets_coliseum_rank.rank,
					Rank2 = Challenger2#ets_coliseum_rank.rank,
					case lib_coliseum:check_coliseum_rank(Rank1, Rank2) of
						true ->
							ColiseumPlayerData = [
								Rank1,
								Challenger2#ets_coliseum_rank.player_id,
								Challenger2#ets_coliseum_rank.nickname,
								Challenger2#ets_coliseum_rank.lv,
								Challenger2#ets_coliseum_rank.sex,
								Challenger2#ets_coliseum_rank.career,
								Rank2					  
							],
							{reply, {1, ColiseumPlayerData}, State};
						false ->
							{reply, 2, State}
					end
			end
	end;

%% 获取竞技场奖励时间
handle_call('AWARD_TIME', _From, State) ->
	{reply, {1, State#state.award_time}, State};

%% 获取竞技场第一名玩家
handle_call('COLISEUM_KING', _From, State) ->
	Pattern = #ets_coliseum_rank{rank = 1, _='_'},
	First = 
		case ets:match_object(?ETS_COLISEUM_RANK, Pattern) of
			[] ->
				0;
			[FirstRank|_] ->
				FirstRank#ets_coliseum_rank.player_id
		end,
	{reply, {1, First}, State};

%% 获取竞技场排名
handle_call({'PLAYER_COLISEUM_RANK', PlayerId}, _From, State) ->
	Rank = 
		case ets:lookup(?ETS_COLISEUM_RANK, PlayerId) of
			[] ->
				0;
			[ColiseumPlayer | _] ->
				ColiseumPlayer#ets_coliseum_rank.rank
		end,
	{reply, {1, Rank}, State};

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
	case catch apply(Module, Method, Args) of
		{'EXIT', Info} ->	
?WARNING_MSG("mod_scene_apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
			error;
		_ -> 
			ok
	end,
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

%% 竞技场登陆检查
handle_cast({'COLISEUM_CHECK', PlayerId, Nickname, Lv, Battle, Realm, Sex, Career}, State) ->
	Now = util:unixtime(),
	NewColiseumPlayer = 
		case ets:lookup(?ETS_COLISEUM_RANK, PlayerId) of
			[] ->
				Rank = db_agent:select_one(coliseum_rank, "rank", [{player_id, PlayerId}]),
				NewRank = 
					case is_integer(Rank) of
						true ->
							Rank;
						false ->
							NR = length(ets:tab2list(?ETS_COLISEUM_RANK)) + 1,
							FieldList = [player_id, nickname, lv, battle, realm, sex, career, rank, time],
							ValueList = [PlayerId, Nickname, Lv, Battle, Realm, Sex, Career, NR, Now],
							spawn(fun()->
								db_agent:delete(coliseum_rank, [{player_id, PlayerId}]),
								db_agent:insert(coliseum_rank, FieldList, ValueList) 
							end),
							NR
					end,
				#ets_coliseum_rank{
					rank = NewRank
				};
			[ColiseumPlayer | _] ->
				spawn(fun()-> db_agent:update(coliseum_rank, [{time, Now}], [{player_id, PlayerId}]) end),
				ColiseumPlayer
		end,
	Report = lib_coliseum:get_coliseum_report(PlayerId),
	RetColiseumPlayer = NewColiseumPlayer#ets_coliseum_rank{
		player_id = PlayerId,                          
		nickname = Nickname,                          
		lv = Lv,                                
		battle = Battle,
		realm = Realm,
		sex = Sex,
		career = Career,
		report = Report													
	},
	ets:insert(?ETS_COLISEUM_RANK, RetColiseumPlayer),
	{noreply, State};

%% 打开竞技场面板
handle_cast({'SEND_COLISEUM_INFO', PlayerId, ColiseumData, PidSend, Now}, State) ->
	ColiseumRankData = ets:tab2list(?ETS_COLISEUM_RANK),
	{Rank, Win, Report} = 
		case ets:lookup(?ETS_COLISEUM_RANK, PlayerId) of
			[] ->
				{length(ColiseumRankData) + 1, 0, []};
			[ColiseumPlayer | _] ->
				{ColiseumPlayer#ets_coliseum_rank.rank, ColiseumPlayer#ets_coliseum_rank.win, ColiseumPlayer#ets_coliseum_rank.report}
		end,
	NewColiseumRankData = lib_coliseum:get_challenger_list(ColiseumRankData, Rank),
	AwardTime = State#state.award_time - Now,
	{ok, BinData} = pt_49:write(49001, [ColiseumData, Rank, Win, AwardTime, NewColiseumRankData]),
   	lib_send:send_to_sid(PidSend, BinData),
%% io:format("Report ~p~n", [Report]),
	%% 竞技场战报返回
	lib_coliseum:coliseum_result(Report, PidSend),
	{noreply, State};

%% 竞技场排行榜
handle_cast({'COLISEUM_RANK', PidSend}, State) ->
	ColiseumRankBinData = 
        case ets:lookup(?ETS_COLISEUM_DATA, 1) of
            [] ->
				get_coliseum_rank_data();
            [ColiseumRankData | _] ->
                ColiseumRankData#ets_coliseum_data.data;
			_ ->
				get_coliseum_rank_data()
        end,
	lib_send:send_to_sid(PidSend, ColiseumRankBinData),
	{noreply, State};

%% 竞技场战报展示
handle_cast({'COLISEUM_REPORT_SHOW', PlayerId, Nickname, Vip, Sta, ReportId}, State) ->
	case ets:lookup(?ETS_COLISEUM_RANK, PlayerId) of
		[] ->
			skip;
		[ColiseumPlayer | _] ->
			lib_coliseum:coliseum_report_show(ColiseumPlayer, ReportId, Nickname, Vip, Sta)
	end,
	{noreply, State};
	
%% 竞技场结算
%% Result 结果，1挑战成功，2挑战失败
handle_cast({'CAL_COLISEUM_RESULT', AttId, DefId, Result}, State) ->
	case ets:lookup(?ETS_COLISEUM_RANK, AttId) of
		[] ->
			skip;
		[AttPlayer | _] ->
			case ets:lookup(?ETS_COLISEUM_RANK, DefId) of
				[] ->
					skip;
				[DefPlayer | _] ->
					Now = util:unixtime(),
					%% 挑战成功
					if
						Result =:= 1 orelse Result =:= 3 ->
							AttPlayer1 = AttPlayer#ets_coliseum_rank{
								win = AttPlayer#ets_coliseum_rank.win + 1
							},
							%% 当玩家连胜次数每达到10的倍数时
							if
								AttPlayer1#ets_coliseum_rank.win > 0 andalso AttPlayer1#ets_coliseum_rank.win rem 10 == 0 ->
									spawn(fun()-> broadcast_win(AttPlayer1, AttPlayer1#ets_coliseum_rank.win) end);
								true ->
									skip
							end,
							DefPlayer1 = DefPlayer#ets_coliseum_rank{
								win = 0
							},
							{AttRank, DefRank} = 
								%% 判断排名
								if
									AttPlayer#ets_coliseum_rank.rank > DefPlayer#ets_coliseum_rank.rank ->
										AttPlayer2 = AttPlayer1#ets_coliseum_rank{
											rank = DefPlayer#ets_coliseum_rank.rank,
											trend = 1
										},
										DefPlayer2 = DefPlayer1#ets_coliseum_rank{
											rank = AttPlayer#ets_coliseum_rank.rank,
											trend = 2
										},
										
%% 										spawn(fun()->
%% 											NameList = [tool:to_list(DefPlayer2#ets_coliseum_rank.nickname)],
%% 											Content =io_lib:format("玩家 ~s 在竞技场中挑战你，你战败了，排名降到第~p位。", [AttPlayer2#ets_coliseum_rank.nickname, DefPlayer2#ets_coliseum_rank.rank]),
%% 											mod_mail:send_sys_mail(NameList, "挑战通知", Content, 0, 0, 0, 0, 0)
%% 										end),
										
										%% 排名第一的玩家被挑战者击败
										if
											DefPlayer#ets_coliseum_rank.rank =:= 1 ->
												spawn(fun()-> broadcast_one(AttPlayer2, DefPlayer2) end);
											true ->
												skip
										end,
										{DefPlayer#ets_coliseum_rank.rank, AttPlayer#ets_coliseum_rank.rank};
									true ->
										AttPlayer2 = AttPlayer1,
										DefPlayer2 = DefPlayer1,
										{0, 0}
								end,
							AttPlayer3 = lib_coliseum:insert_coliseum_report(AttPlayer2, DefPlayer2#ets_coliseum_rank.player_id, DefPlayer2#ets_coliseum_rank.nickname, 1, 1, AttRank, Now), 
							DefPlayer3 = lib_coliseum:insert_coliseum_report(DefPlayer2, AttPlayer2#ets_coliseum_rank.player_id, AttPlayer2#ets_coliseum_rank.nickname, 2, 2, DefRank, Now),
							ets:insert(?ETS_COLISEUM_RANK, AttPlayer3),
							ets:insert(?ETS_COLISEUM_RANK, DefPlayer3);
						true ->
							AttPlayer1 = AttPlayer#ets_coliseum_rank{
								win = 0
							},
							DefPlayer1 = DefPlayer#ets_coliseum_rank{
								win = DefPlayer#ets_coliseum_rank.win + 1
							},
							AttPlayer2 = lib_coliseum:insert_coliseum_report(AttPlayer1, DefPlayer1#ets_coliseum_rank.player_id, DefPlayer1#ets_coliseum_rank.nickname, 1, 2, 0, Now), 
							DefPlayer2 = lib_coliseum:insert_coliseum_report(DefPlayer1, AttPlayer1#ets_coliseum_rank.player_id, AttPlayer1#ets_coliseum_rank.nickname, 2, 1, 0, Now),
							ets:insert(?ETS_COLISEUM_RANK, AttPlayer2),
							ets:insert(?ETS_COLISEUM_RANK, DefPlayer2)
					end
			end
	end,
	{noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

%% 竞技场间隔
handle_info('COLISEUM_INTERVAL', State) ->
	Now = util:unixtime(),
	InitColiseumRankTime = State#state.award_time - 30,
	NewState = 
		if 
			Now >= InitColiseumRankTime andalso Now - InitColiseumRankTime < ?COLISEUM_INTERVAL ->
				spawn(fun()-> db_agent:update(player_other, [{coliseum_rank, 0}], []) end),
				State;
			Now >= State#state.award_time andalso Now - State#state.award_time < ?COLISEUM_INTERVAL ->
%% 				DistTime = 86400 * ?COLISEUM_AWARD_DAY,
				
				{_SecStart, SecEnd} = util:get_midnight_seconds(Now),
				AwardTime = SecEnd + ?COLISEUM_SEC + 86400,
				
%% 				AwardTime = Now + 180,

				spawn(fun()-> coliseum_award(Now, AwardTime) end),
				
				State#state{
					award_time = AwardTime			
				};
			true->
				State
		end,
	erlang:send_after(?COLISEUM_INTERVAL * 1000, self(), 'COLISEUM_INTERVAL'),
	{noreply, NewState};

handle_info('TEST', State) ->
	Now = util:unixtime(),
%% 	{_SecStart, SecEnd} = util:get_midnight_seconds(Now),
%% 	AwardTime = SecEnd + ?COLISEUM_SEC,
	
	AwardTime = Now + 180,
	
	spawn(fun()-> coliseum_award(Now, AwardTime) end),
	NewState = State#state{
		award_time = AwardTime			
	},
	{noreply, NewState};

%% 竞技场排行榜更新间隔
handle_info('COLISEUM_RANK_INTERVAL', State) ->
	spawn(fun()-> get_coliseum_rank_data() end),
	erlang:send_after(?COLISEUM_RANK_INTERVAL * 1000, self(), 'COLISEUM_RANK_INTERVAL'),
	{noreply, State};

%% 设置奖励时间
handle_info({'SET_AWARD_TIME', AwardTime}, State) ->
	NewState = State#state{
		award_time = AwardTime				   
    },
	{noreply, NewState};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(Reason, State) ->
	misc:delete_monitor_pid(self()),
	misc:delete_system_info(self()),
?WARNING_MSG("MOD_COLISEUM_SUPERVISOR_TERMINATE: Reason ~p~n State ~p~n", [Reason, State]),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%% 获取战场监控进程
get_mod_coliseum_supervisor_pid() ->
	ProcessName = mod_coliseum_supervisor_mark,
	Pid = misc:whereis_name({global, ProcessName}),
	case misc:is_process_alive(Pid) of
		true -> 
			Pid;
		false ->
			start_mod_coliseum_supervisor(ProcessName)
	end.

%% 获取竞技场工作进程
get_coliseum_worker_pid() ->
	WorkerId = random:uniform(?COLISEUM_WORKER_NUMBER),
   	ProcessName = misc:create_process_name(coliseum_worker, [WorkerId]),
  	Pid = misc:whereis_name({global, ProcessName}),
	case is_pid(Pid) of
		true ->
			Pid;
		false ->
			get_mod_coliseum_supervisor_pid()
	end.

%% 获取竞技场计算挑战结果的进程
get_coliseum_cal_worker_pid() ->
   	ProcessName = misc:create_process_name(coliseum_worker, [?COLISEUM_CAL_WORKER_ID]),
  	Pid = misc:whereis_name({global, ProcessName}),
	case is_pid(Pid) of
		true ->
			Pid;
		false ->
			get_coliseum_worker_pid()
	end.

%% 开启战场监控进程
start_mod_coliseum_supervisor(ProcessName) ->
	global:set_lock({ProcessName, undefined}),
	Pid = misc:whereis_name({global, ProcessName}),
	ProcessPid = 
		case misc:is_process_alive(Pid) of
			true ->	
				Pid;		
			false ->
				start_coliseum_supervisor(ProcessName)
		end,
	global:del_lock({ProcessName, undefined}),
	ProcessPid.
start_coliseum_supervisor(ProcessName) ->
	ChildSpec = {
		mod_coliseum_supervisor,
      	{
			mod_coliseum_supervisor, 
			start_link,
			[ProcessName]
		},
   		permanent, 
		10000, 
		supervisor, 
		[mod_coliseum_supervisor]
	},
	case supervisor:start_child(yg_server_sup, ChildSpec) of
		{ok, Pid} ->
			Pid;
		_ ->
			undefined
	end.

%% 初始竞技场数据
init_coliseum_data(AwardTime) ->
	%% 初始竞技场信息
	init_coliseum_info(AwardTime),
	
	ColiseumData = db_agent:select_all(coliseum_rank, "*", [], [{rank, asc}]),
	%% 初始挑战者列表数据
	init_coliseum_rank(ColiseumData, 1),
	
	%% 获取竞技场排行数据
	get_coliseum_rank_data().

%% 初始挑战者列表数据
init_coliseum_rank([], _Rank) ->
	skip;
init_coliseum_rank([C | ColiseumData], Rank) ->
	ColiseumPlayer = list_to_tuple([?ETS_COLISEUM_RANK | C]),
	NewColiseumPlayer = ColiseumPlayer#ets_coliseum_rank{
		rank = Rank													 
	},
	ets:insert(?ETS_COLISEUM_RANK, NewColiseumPlayer),
	spawn(fun()-> db_agent:update(coliseum_rank, [{rank, Rank}], [{player_id, ColiseumPlayer#ets_coliseum_rank.player_id}]) end),
	init_coliseum_rank(ColiseumData, Rank + 1).

%% 初始竞技场信息
init_coliseum_info(AwardTime) ->
	NewKingId =
	    case db_agent:select_row(coliseum_info, "award_time, king_id", []) of
			[_AwardTime, KingId] ->
				KingId;
			_ ->
				spawn(fun()-> 
					db_agent:insert(coliseum_info, [award_time, king_id], [AwardTime, 0]) 
				end),
				0
		end,
	ColiseumInfo = #ets_coliseum_info{
		award_time = AwardTime,
		king_id = NewKingId							  
	},
	ets:insert(?ETS_COLISEUM_INFO, ColiseumInfo),
	ColiseumInfo.

%% 获取竞技场信息
get_coliseum_info(AwardTime) ->
	case ets:tab2list(?ETS_COLISEUM_INFO) of
		[] ->
			init_coliseum_info(AwardTime);
		[ColiseumInfo | _] ->
			ColiseumInfo
	end.

%% 连胜播报
broadcast_win(ColiseumPlayer, Win) ->
	NameColor = data_agent:get_realm_color(ColiseumPlayer#ets_coliseum_rank.realm),
	Data = [
		ColiseumPlayer#ets_coliseum_rank.player_id, 
		ColiseumPlayer#ets_coliseum_rank.nickname, 
		ColiseumPlayer#ets_coliseum_rank.career, 
		ColiseumPlayer#ets_coliseum_rank.sex, 
		NameColor, 
		ColiseumPlayer#ets_coliseum_rank.nickname,
		Win	
	],
	Msg = io_lib:format("玩家 <a href='event:1, ~p, ~s, ~p, ~p'><font color='~s'>[~s]</font></a> 势如破竹，在竞技场中的连胜次数达到 <font color='#FEDB4F;'>~p</font> 次！！", Data),
	lib_chat:broadcast_sys_msg(2, Msg).

%% 第一播报
broadcast_one(AttPlayer, DefPlayer) ->
	AttNameColor = data_agent:get_realm_color(AttPlayer#ets_coliseum_rank.realm),
	DefNameColor = data_agent:get_realm_color(DefPlayer#ets_coliseum_rank.realm),
	Data = [
		AttPlayer#ets_coliseum_rank.player_id, 
		AttPlayer#ets_coliseum_rank.nickname, 
		AttPlayer#ets_coliseum_rank.career, 
		AttPlayer#ets_coliseum_rank.sex, 
		AttNameColor, 
		AttPlayer#ets_coliseum_rank.nickname,
		
		DefPlayer#ets_coliseum_rank.player_id, 
		DefPlayer#ets_coliseum_rank.nickname, 
		DefPlayer#ets_coliseum_rank.career, 
		DefPlayer#ets_coliseum_rank.sex, 
		DefNameColor, 
		DefPlayer#ets_coliseum_rank.nickname
	],
	Msg = io_lib:format("玩家 <a href='event:1, ~p, ~s, ~p, ~p'><font color='~s'>[~s]</font></a> 成功击败了玩家 <a href='event:1, ~p, ~s, ~p, ~p'><font color='~s'>[~s]</font></a>，登上了竞技场第一的宝座！！", Data),
	lib_chat:broadcast_sys_msg(2, Msg).

%% 获取领奖时间
get_award_time() ->
	Now = util:unixtime(),
	spawn(fun()->
		%% 删除一个月外的战报
		Ctime = Now - 86400 * 10,
		db_agent:delete(log_coliseum_report, [{ctime, "<", Ctime}])			  
	end),
	Sec = ?COLISEUM_SEC,
	AwardTime = db_agent:select_one(coliseum_info, "award_time", []),
	case is_integer(AwardTime) of
		true ->
			if
				Now >= AwardTime ->
					{_TodayMidNightSecond, YestodayMidNightSecond} = util:get_midnight_seconds(Now),
					NewAwardTime = YestodayMidNightSecond + Sec,
					spawn(fun()-> db_agent:insert(coliseum_info, [award_time, king_id], [NewAwardTime, 0]) end),
					NewAwardTime;
				true ->
					AwardTime
			end;
		false ->
			{_TodayMidNightSecond, YestodayMidNightSecond} = util:get_midnight_seconds(Now),
			NewAwardTime = YestodayMidNightSecond + Sec,
			spawn(fun()-> db_agent:insert(coliseum_info, [award_time, king_id], [NewAwardTime, 0]) end),
			NewAwardTime
	end.

%% 发放竞技场奖励
coliseum_award(_Now, AwardTime) ->
	lists:foreach(
        fun(WorkerId) ->
		   	ProcessName = misc:create_process_name(coliseum_worker, [WorkerId]),
		  	Pid = misc:whereis_name({global, ProcessName}),
			case is_pid(Pid) of
				true ->
					Pid ! {'SET_AWARD_TIME', AwardTime};
				false ->
					skip
			end
        end,
    lists:seq(1, ?COLISEUM_WORKER_NUMBER)),
	
	spawn(fun()-> db_agent:update(coliseum_info, [{award_time, AwardTime}], []) end),
%% 	LastLoginTime = Now - 86400 * ?COLISEUM_AWARD_DAY,
%% 	RankList = db_agent:select_all(coliseum_rank, "player_id, rank", [{time, ">=", LastLoginTime}], []),
	RankList = db_agent:select_all(coliseum_rank, "player_id, rank", [], []),
	RankListFun = fun([PlayerId, Rank]) ->
		spawn(fun()->
			if
				%% 更新第一名信息
				Rank == 1 ->
					spawn(fun()-> db_agent:update(coliseum_info, [{king_id, PlayerId}], []) end),
					ColiseumInfo = get_coliseum_info(AwardTime),
					NewColiseumInfo = ColiseumInfo#ets_coliseum_info{
						award_time = AwardTime,
						king_id = PlayerId												 
					},
					ets:insert(?ETS_COLISEUM_INFO, NewColiseumInfo);
				true ->
					skip
			end,
			case lib_player:get_player_pid(PlayerId) of
				[] ->
					db_agent:update(player_other, [{coliseum_rank, Rank}], [{pid, PlayerId}]);
				Pid ->
					gen_server:cast(Pid, {'REFRESH_COLISEUM_AWARD', Rank})
			end
		end)				  
	end,
	[RankListFun(R) || R <- RankList].

%% 获取竞技场排行数据
get_coliseum_rank_data() ->
	ColiseumRankData = lib_coliseum:get_coliseum_rank_player(?COLISEUM_RANK_NUM),
	{ok, ColiseumRankBinData} = pt_49:write(49003, ColiseumRankData),
	CastleRushRank = #ets_coliseum_data{
        id = 1,
        data = ColiseumRankBinData										
    },
    ets:insert(?ETS_COLISEUM_DATA, CastleRushRank),
	ColiseumRankBinData.


test() ->
	Pid = get_mod_coliseum_supervisor_pid(),
	Pid ! 'TEST'.
