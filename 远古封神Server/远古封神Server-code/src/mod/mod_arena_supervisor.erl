%%%------------------------------------
%%% @Module  : mod_arena_supervisor
%%% @Author  : ygfs
%%% @Created : 2011.02.12
%%% @Description: 战场主进程
%%%------------------------------------
-module(mod_arena_supervisor).

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
		rank_current_arena_week/0,
		analytics_join/0		
	]
).
-export(
    [
   		start_link/1,
		start_worker/2,
	 	get_mod_arena_supervisor_pid/0,
		get_mod_arena_supervisor_work_pid/0,
		create_arena_battle/1,
		change_player_name/2,
		rank_total_arena_query/1,
		rank_total_arena_query_order/2				
    ]
).

-define(ARENA_NUM, 40).												%% 战场人数
-define(ARENA_SCENE, 600).											%% 战场的场景ID
-define(ARENA_NUM_LIMIT, 19).										%% 每个战区战场的最少人数值
-define(ARENA_LEVEL_NUM_LIMIT, 9).									%% 每个等级战场的最少人数值
-define(INIT_ARENA_DELAY, 60).                                     	%% 60秒加载竞技排行数据
-define(ARENA_INTERVAL, 10).										%% 竞技间隔
-define(RANK_NUM, 10).												%% 排名最高前十放一组
-define(ARENA_WORKER_NUMBER, 100).									%% 战场工作进程数量

-record(state, {
	group = [],														%% 分组列表
	create_arena_timer = undefined,
	start_arena_timer = undefined,
	end_arena_timer = undefined,
	kill_arena_timer = undefined,
	worker_id = 0
}).

%% 启动战场监控服务
start_link(ProcessName) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [ProcessName, 0], []).

%% 启动工作服务进程
start_worker(ProcessName, WorkId) ->
	gen_server:start_link(?MODULE, [ProcessName, WorkId], []).

init([ProcessName, WorkerId]) ->
	process_flag(trap_exit, true),
	Self = self(),
	case misc:register(unique, ProcessName, Self) of
		yes ->
			if
				WorkerId == 0 ->
					misc:write_monitor_pid(Self, mod_arena_supervisor, {}),
					misc:write_system_info(Self, mod_arena_supervisor, {}),
					erlang:send_after(?ARENA_INTERVAL * 1000, Self, 'ARENA_INTERVAL'),	
					%% 战场
					ets:new(?ETS_ARENA, [{keypos, #ets_arena.player_id}, named_table, public, set,?ETSRC, ?ETSWC]),
					%% 战场周排行
					ets:new(?ETS_ARENA_WEEK, [{keypos, #ets_arena_week.id}, named_table, public, set,?ETSRC, ?ETSWC]),
					%% 一分钟后加载战场数据
					erlang:send_after(?INIT_ARENA_DELAY, Self, {'LOAD_ARENA'}),
					
					%% 启动竞技场服务工作进程
		            lists:foreach(
		                fun(WorkId) ->
							WorkProcessName = misc:create_process_name(arena_worker, [WorkId]),
		         			mod_arena_supervisor:start_worker(WorkProcessName, WorkId)
		                end,
		            lists:seq(1, ?ARENA_WORKER_NUMBER)),
					
					io:format("4.Init mod_arena_sup finish!!!~n");
				true ->
					skip
			end,
			State = #state{
				worker_id = WorkerId						   
			},
    		{ok, State};
		_ ->
			{stop, normal, #state{}}
	end.

%% 检查是否参加了战场
handle_call({'CHECK_JOIN_ARENA', PlayerId}, _From, State) ->
	Reply = check_join_arena(State#state.group, 3, PlayerId),
	NewReply = 
		if
			Reply =/= 0 ->
				Reply;
			true ->
				check_join_arena(State#state.group, 2, PlayerId)
		end,
	RetReply = 
		if
			NewReply =/= 0 ->
				NewReply;
			true ->
				check_join_arena(State#state.group, 1, PlayerId)
		end,
    {reply, RetReply, State};

%% 统一模块+过程调用(call)
handle_call({apply_call, Module, Method, Args}, _From, State) ->
	Reply  = 
        case (catch apply(Module, Method, Args)) of
             {'EXIT', Info} ->	
?WARNING_MSG("mod_arena_supervisor apply_call error: Module=~p, Method=~p, Reason=~p, Args = ~p",[Module, Method, Info, Args]),
                 error;
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

handle_cast(_Msg, State) ->
    {noreply, State}.

%% 战场定时器
handle_info('ARENA_INTERVAL', State) ->
	NowSec = util:get_today_current_second(),
	%%获取今天凌晨到现在的秒数
	DistTime = 120,
	ArenaJoinTime = lib_arena:get_arena_join_time(),
	{NewState, Interval} =
		if
	 		NowSec >= ArenaJoinTime - DistTime andalso NowSec =< ArenaJoinTime + DistTime ->
				ARENA_INTERVAL = ?ARENA_INTERVAL,
				if 
					%% 报名开始
					NowSec >= ArenaJoinTime andalso NowSec - ArenaJoinTime < ARENA_INTERVAL ->
	?WARNING_MSG("ARENA_SUP_PROC_START: Time ~p~n State ~p~n", [NowSec, State]),
						lib_arena:start_arena_timer(NowSec, self()),
						{#state{}, ARENA_INTERVAL};
		   			true->
						{State, ARENA_INTERVAL}
				end;
			NowSec >= 14400 - DistTime andalso NowSec < 14400 ->
				%% 统计每天剩余元宝（铜币）
				spawn(fun()-> db_agent:sum_remain_gold_coin(NowSec) end),
				%% 流失率统计
				spawn(fun()-> db_agent:count_player_leave(NowSec) end),
				%%斗兽模块清除战报数据(ETS)
				spawn(fun()-> lib_mount_arena:clear_battle_result() end),
				{State, DistTime};
			%% 活跃度统计
			NowSec >= 7500 - DistTime andalso NowSec < 7500 ->
				spawn(fun()-> analytics_join() end),
				{State, DistTime};
			true ->
				{State, DistTime}
		end,
	erlang:send_after(Interval * 1000, self(), 'ARENA_INTERVAL'),
	{noreply, NewState};

%% 初始化战场数据
handle_info({'LOAD_ARENA'}, State) ->
	spawn(lib_arena, init_arena_data, []),
	{noreply, State};

%% 创建战场
handle_info('CREATE_ARENA', State) ->
	JoinList = lib_arena:get_arena_join_list(),
	NewGroupList = create_arena_battle(JoinList),
	NewState = State#state{
		group = NewGroupList					   
	},
	{noreply, NewState};

%% 战场开始
handle_info('START_ARENA', State) ->
	Fun = fun({_Mark, ArenaList}) ->
		case ArenaList of
			[] ->
				skip;
			_ ->
				[gen_server:cast(ArenaPid, 'ARENA_START') || {_ArenaSceneId, _ArenaLevel, ArenaPid, _ArenaerList} <- ArenaList]
		end
	end,
	[Fun(A) || A <- State#state.group],
	{noreply, State};

%% 战场结束
handle_info('ARENA_END', State) ->
	Fun = fun({_Mark, ArenaList}) ->
		case ArenaList of
			[] ->
				skip;
			_ ->
				[ArenaPid ! 'END_ARENA' || {_ArenaSceneId, _ArenaLevel, ArenaPid, _ArenaerList} <- ArenaList]
		end
	end,
	[Fun(A) || A <- State#state.group],
	{noreply, State};

%% 结束战场进程
handle_info('KILL_ARENA', State) ->
	Fun = fun({_Mark, ArenaList}) ->
		case ArenaList of
			[] ->
				skip;
			_ ->
				[gen_server:cast(ArenaPid, 'KILL_ARENA') || {_ArenaSceneId, _ArenaLevel, ArenaPid, _ArenaerList} <- ArenaList]
		end
	end,
	[Fun(A) || A <- State#state.group],
	NewState = State#state{
		group = []					   
	},
	{noreply, NewState};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(Reason, State) ->
	misc:delete_monitor_pid(self()),
	misc:delete_system_info(self()),
	if
		State#state.worker_id == 0 ->
?WARNING_MSG("ARENA_SUPERVISOR_TERMINATE: Reason ~p~n State ~p~n", [Reason, State]);		
		true ->
			skip
	end,
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%% 获取战场工作进程
get_mod_arena_supervisor_work_pid() ->
	WorkerId = random:uniform(?ARENA_WORKER_NUMBER),
   	ProcessName = misc:create_process_name(arena_worker, [WorkerId]),
  	Pid = misc:whereis_name({global, ProcessName}),
	case is_pid(Pid) of
		true ->
			Pid;
		false ->
			get_mod_arena_supervisor_pid()
	end.


%% 获取战场监控进程
get_mod_arena_supervisor_pid() ->
	ProcessName = mod_arena_supervisor_mark,
	Pid = misc:whereis_name({global, ProcessName}),
	case misc:is_process_alive(Pid) of
		true -> 
			Pid;
		false ->
			start_mod_arena_supervisor(ProcessName)
	end.

%% 开启战场监控进程
start_mod_arena_supervisor(ProcessName) ->
	global:set_lock({ProcessName, undefined}),
	Pid = misc:whereis_name({global, ProcessName}),
	ProcessPid = 
		case misc:is_process_alive(Pid) of
			true ->	
				Pid;		
			false ->
				start_arena_supervisor(ProcessName)
		end,
	global:del_lock({ProcessName, undefined}),
	ProcessPid.
start_arena_supervisor(ProcessName) ->
	ChildSpec = {
		mod_arena_supervisor,
      	{
			mod_arena_supervisor, 
			start_link,
			[ProcessName]
		},
   		permanent, 
		10000, 
		supervisor, 
		[mod_arena_supervisor]
	},
	case supervisor:start_child(yg_server_sup, ChildSpec) of
		{ok, Pid} ->
			Pid;
		_ ->
			undefined
	end.


%% 创建战场
create_arena_battle(JoinList) ->
	%% 创建每个等级段的战区
	ArenaZoneList = create_arena_zone(JoinList, [], [], []),
	start_arena_loop(ArenaZoneList, ?ARENA_SCENE, []).
start_arena_loop([], _ArenaScene, ArenaGroupList) ->
	ArenaGroupList;
start_arena_loop([{Level, ArenaList} | S], ArenaScene, ArenaGroupList) ->
	case ArenaList of
		[] ->
			start_arena_loop(S, ArenaScene, [{Level, ArenaList} | ArenaGroupList]);
		_ ->
			case Level of
				%% 中级战场
				2 ->
					case mod_arena_new:start(Level, 1, 650, ArenaList) of 
						{ok, ArenaPid} ->
							NewArenaList = [{650, 0, ArenaPid, ArenaList}],
							start_arena_loop(S, ArenaScene, [{Level, NewArenaList} | ArenaGroupList]);
						_ ->
							start_arena_loop(S, ArenaScene, [{Level, ArenaList} | ArenaGroupList])
					end;
				%% 高级战场
				3 ->
					case mod_arena_new:start(Level, 1, 651, ArenaList) of 
						{ok, ArenaPid} ->
							NewArenaList = [{651, 0, ArenaPid, ArenaList}],
							start_arena_loop(S, ArenaScene, [{Level, NewArenaList} | ArenaGroupList]);
						_ ->
							start_arena_loop(S, ArenaScene, [{Level, ArenaList} | ArenaGroupList])
					end;
				_ ->
%% 					case mod_arena_new:start(Level, 1, 651, ArenaList) of 
%% 						{ok, ArenaPid} ->
%% 							NewArenaList = [{651, 0, ArenaPid, ArenaList}],
%% 							start_arena_loop(S, ArenaScene, [{Level, NewArenaList} | ArenaGroupList]);
%% 						_ ->
%% 							start_arena_loop(S, ArenaScene, [{Level, ArenaList} | ArenaGroupList])
%% 					end
					[NewArenaList, NewArenaScene] = allot_arena_battle(Level, ArenaList, ArenaScene),
					start_arena_loop(S, NewArenaScene, [{Level, NewArenaList} | ArenaGroupList])	
			end
	end.

%% 分配战区战场（战区内的战场）
%% Level 战区级别（高、中、低）
%% ArenaZoneMember 该战区人员
%% ArenaScene 该战区每个战场的场景ID
allot_arena_battle(Level, ArenaZoneMember, ArenaScene) ->
	ArenaNum = 
		if
			Level =/= 3 ->
				?ARENA_NUM;
			true ->
				100
		end,
	%% 战区数
	[ArenaNumList, NewArenaScene] = get_arena_battle_num(ArenaZoneMember, ArenaScene, ArenaNum),
	%% 由高到低排序
	SortFun = fun({_, _, _, _, L1, A1, _}, {_, _, _, _, L2, A2, _}) ->
		L1 * A1 > L2 * A2 
	end,
	ArenaZoneMember1 = lists:sort(SortFun, ArenaZoneMember),
	[ArenaZoneMember2, NewArenaNumList] = special_arena_group(ArenaZoneMember1, ArenaNumList),
	%% 分配该战区各自小战场的人数
	LevelSortFun = fun({_, L1, _, _}, {_, L2, _, _}) ->
		L1 < L2 
	end,
	ArenaGroupList = allot_arena_battle_loop(ArenaZoneMember2, LevelSortFun, NewArenaNumList),
	%% 真正开始初始创建战场进程
	NewArenaGroupList = create_arena_battle_loop(ArenaGroupList, ArenaGroupList, Level, 1),
	[NewArenaGroupList, NewArenaScene].

%% 真正开始初始创建战场进程
create_arena_battle_loop([], ArenaGroupList, _Level, _Zone) ->
	ArenaGroupList;
create_arena_battle_loop([{Mark, Lvs, _ArenaPid, MemberList} | A], ArenaGroupList, Level, Zone) ->
	NewArenaGroupList = 
		case mod_arena:start(Level, Zone, Mark, MemberList) of 
			{ok, ArenaPid} ->
				lists:keyreplace(Mark, 1, ArenaGroupList, {Mark, Lvs, ArenaPid, MemberList});			
			_ ->
				ArenaGroupList			
		end,
	create_arena_battle_loop(A, NewArenaGroupList, Level, Zone + 1).

%% 分配该战区各自小战场的人数
allot_arena_battle_loop([], _LevelSortFun, RetList) ->
	RetList;
allot_arena_battle_loop(A, LevelSortFun, RetList) ->
	Rand = random:uniform(length(A)),
	{PlayerId, NickName, Realm, Career, Lv, Att, Sex} = lists:nth(Rand, A),
	NewRetList = insert_arena_member(RetList, LevelSortFun, {PlayerId, NickName, Realm, Career, Lv, Att, Sex}),
	S = lists:keydelete(PlayerId, 1, A),
	allot_arena_battle_loop(S, LevelSortFun, NewRetList).

insert_arena_member(List, LevelSortFun, P) ->
	{_PlayerId, _NickName, _Realm, _Career, Lv, _Att, _Sex} = P,
	[{ZoneNum, L, ArenaPid, MList} | _OtherList] = lists:sort(LevelSortFun, List),
	NewItemList = {ZoneNum, L + Lv, ArenaPid, [P | MList]},
	lists:keyreplace(ZoneNum, 1, List, NewItemList).


%% 特殊分配（最高前十名放一起）
special_arena_group(ArenaZoneMember, ArenaNumList) ->
	Len = length(ArenaZoneMember),
	if
		Len >= ?RANK_NUM ->
			{ArenaZoneMember1, ArenaZoneMember2} = lists:split(?RANK_NUM, ArenaZoneMember),
			special_arena_group_loop(ArenaZoneMember1, ArenaZoneMember2, ArenaNumList);
		true ->
			[ArenaZoneMember, ArenaNumList]
	end.
special_arena_group_loop([], ArenaZoneMember, ArenaNumList) ->
	[ArenaZoneMember, ArenaNumList];
special_arena_group_loop([P | A], ArenaZoneMember, ArenaNumList) ->
	{_PlayerId, _NickName, _Realm, _Career, Lv, _Att, _Sex} = P,
	[{ZoneNum, L, ArenaPid, MemberList} | _] = ArenaNumList,
	NewArenaNumList = lists:keyreplace(ZoneNum, 1, ArenaNumList, {ZoneNum, L + Lv, ArenaPid, [P | MemberList]}),
	special_arena_group_loop(A, ArenaZoneMember, NewArenaNumList).

%% 获取战场个数
get_arena_battle_num(ArenaList, ArenaScene, ArenaNum) ->
	Total = length(ArenaList),
	N = util:floor(Total / ArenaNum),
	Remainder = Total rem ArenaNum,
	Num = 
		if
			Remainder > ?ARENA_NUM_LIMIT ->
				N + 1;
			N == 0 ->
				1;
			true ->
				N
		end,
	get_arena_battle_num_loop(Num, ArenaScene, []).
get_arena_battle_num_loop(0, RetArenaScene, RetList) ->
	[RetList, RetArenaScene];
get_arena_battle_num_loop(Num, ArenaScene, RetList) ->
	NewArenaScene = ArenaScene + 1,
	get_arena_battle_num_loop(Num - 1, NewArenaScene, [{NewArenaScene, 0, undefined, []} | RetList]).

%% 创建每个等级段的战区
%% Junior 初级战场人员（40以下）
%% Bec 中级战场人员（40 - 60）
%% Senior 高级战场人员（60以上）
create_arena_zone([], Junior, Bec, Senior) ->
	[RetJunior, RetBec, RetSenior] =
		if
			length(Senior) > ?ARENA_LEVEL_NUM_LIMIT ->
				if
					length(Bec) > ?ARENA_LEVEL_NUM_LIMIT ->
						[Junior, Bec, Senior];
					true ->
						[Junior ++ Bec, [], Senior]
				end;
			true ->
				NewBec = Bec ++ Senior,
				if
					length(NewBec) > ?ARENA_LEVEL_NUM_LIMIT ->
						[Junior, NewBec, []];				
					true ->
						[Junior ++ NewBec, [], []]
				end
		end,
	[{1, RetJunior}, {2, RetBec}, {3, RetSenior}];
create_arena_zone([[PlayerId, NickName, Realm, Career, Lv, Att, Sex] | A], Junior, Bec, Senior) ->
	[NewJunior, NewBec, NewSenior] =
		if
			Lv < 40 ->
				[[{PlayerId, NickName, Realm, Career, Lv, Att, Sex} | Junior], Bec, Senior];
			Lv >= 40 andalso Lv < 60 ->
				[Junior, [{PlayerId, NickName, Realm, Career, Lv, Att, Sex} | Bec], Senior];
			true ->
				[Junior, Bec, [{PlayerId, NickName, Realm, Career, Lv, Att, Sex} | Senior]]
		end,
	create_arena_zone(A, NewJunior, NewBec, NewSenior).


%% 总排行的战场排行榜(1周战绩排行	2总战绩排行)
rank_total_arena_query_order(PidSend,RankType) ->
	RankInfo = rank_total_arena_query(RankType),
	{ok, BinData} = pt_22:write(22014, RankInfo),
	lib_send:send_to_sid(PidSend, BinData).
	
rank_total_arena_query(RankType) ->
	try 
		Ret = gen_server:call(mod_arena_supervisor:get_mod_arena_supervisor_work_pid(), 
					 {apply_call, lib_arena, rank_total_arena_query, [RankType]}),
		if 
			Ret == error -> 
				[];
			true -> 
				Ret 
		end
	catch
		_:_ -> 
			[]
	end.

%% 更新战场角色名
change_player_name(PlayerId, NewNickName) ->
	try 
		gen_server:cast(mod_arena_supervisor:get_mod_arena_supervisor_work_pid(), 
					 {apply_cast, lib_arena, change_player_name, [PlayerId,NewNickName]})
	catch
		_:_ -> 
			[]
	end.

%% 查询本周一到现在的周排行
rank_current_arena_week() ->
	try 
		Ret =gen_server:call(mod_arena_supervisor:get_mod_arena_supervisor_work_pid(), 
					 {apply_call, lib_arena, rank_current_arena_week, []}),
		if 
			Ret == error -> 
				[];
		   	true -> 
				Ret 
		end
	catch
		_:_ ->
			[]
	end.


%% 参与度统计
analytics_join() ->
	Now = util:unixtime(),
	YestodayNow = Now - 86400,
	{DayStart, DayEnd} = util:get_midnight_seconds(YestodayNow),
	[LoginNum] = db_agent:day_login_num(DayStart, Now),
	Item = analytics_join_loop([fst, tds, tdm, fb_911, fb_920, fb_930, fb_940, fb_950, business, carry, peach, arena, guild, wild_boss, guild_boss, guild_carry, exc, orc, answer, train, spring], DayStart, DayEnd, []),
	KeyList = [fst, fst_num, tds, tds_num, tdm, tdm_num, fb_911, fb_911_num, fb_920, fb_920_num, fb_930, fb_930_num, fb_940, fb_940_num, fb_950, fb_950_num, business, business_num, carry, carry_num, peach, peach_num, arena, arena_num, guild, guild_num, wild_boss, wild_boss_num, guild_boss, guild_boss_num, guild_carry, guild_carry_num, exc, exc_num, orc, orc_num, answer, answer_num, train, train_num, spring, spring_num, login_num, jtime],
	ValList = Item ++ [LoginNum, Now - 10],
	db_agent:insert_join_summary(KeyList, ValList),
	%% 注册统计
	[RegNum] = db_agent:day_reg_num(DayStart, DayEnd),
	YesDayStart = DayStart - 86400,
	OldList = lists:flatten(db_agent:old_player(YesDayStart, DayStart)),
	PlayerIdList = lists:usort(OldList),
	%% 老玩家数（连续2天登录）
	[OldNum] = db_agent:day_old_player_num(DayStart, Now, PlayerIdList),
	db_agent:insert_login_data(LoginNum, OldNum, RegNum, YestodayNow),
	%% 玩家注册登录元宝数据统计
	db_agent:insert_daily_data(RegNum, LoginNum, Now).
	
analytics_join_loop([], _DayStart, _DayEnd, Item) ->
	lists:reverse(Item);
analytics_join_loop([I | L], DayStart, DayEnd, Item) ->
	[It] = db_agent:count_join_data(I, DayStart, DayEnd),
	In = db_agent:sum(log_join, lists:concat([I]), [{jtime, ">", DayStart}, {jtime, "<", DayEnd}]),
	analytics_join_loop(L, DayStart, DayEnd, [In | [It | Item]]).

%% 检查是否参加了战场
check_join_arena(ArenaGroup, ArenaLevel, PlayerId) ->
	case lists:keyfind(ArenaLevel, 1, ArenaGroup) of
		{_LevelKey, [{ArenaSceneId, _LevelNum, ArenaPid, ArenaList}]} ->
			case lists:keyfind(PlayerId, 1, ArenaList) of
				false ->
					0;
				_ ->
					{ArenaSceneId, ArenaPid}
			end;
		_ ->
			0
	end.	

