%% Author: Administrator
%% Created: 2012-2-20
%% Description: TODO: 跨服单人竞技服务
-module(mod_war2_supervisor).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-export([start_link/1, 
		 start/0,
		 stop/0,
		 get_mod_war2_supervisor_pid/0
		 ]).

-export([sync_war2_elimination_local/1,
		 sync_war2_history_local/1,
		 bet_popular/1,
		 get_champoin/0,
		 cmd_open_war2/1,
		 cmd_open_elimination/0,
		 cmd_check_state/1,
		 cmd_change_war2_state/1,
		 notice_apply/0,
		 notice_enter_war2/1,
		 delwith_merge_data/3,
		 reset/0
		]).
%%
%% Exported Functions
%%
-export([]).

-record(state,{times = 0,			%%届次
				state = 0,			%% 状态（1、报名；2、选拔赛；3、32强；4、16强；5、8强；6、4强；7、决赛）
				sky = [],			%%天罡冠军信息
				land = [],			%%地煞冠军信息
				subarea = [],		%%分区场景服务pid信息[{分区，场景id，场景pid}]
				elimination = [],	%%淘汰赛休息区场景服务
				player_scene = [],	%%玩家场景信息[{玩家id，场景id，场景PID}]
				scene_temp = [],			%%公共临时场景
				match = [],			%%选拔赛配对表
				end_time = 0,		%%选拔赛结束时间
				member_count = [],	%%分区人数统计
				war2_state=0,		%%比赛状态
				is_bet = 0,			%%是否能投注
			   	is_end = 0,			%%阶段结束标记
				is_open=1			%%是否开启
				}).

-define(OPEN_REST_SCENE,(15*3600+45*60)*1000).%%休息区开放时间
-define(APPLY_TIME,9*3600*1000).%%开始报名时间
%%
%% API Functions
%%
%% 启动跨服战场超级服务
start_link([ProcessName, Worker_id]) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [ProcessName, Worker_id], []).

start() ->
    gen_server:start(?MODULE, [], []).

%%停止服务
stop() ->
    gen_server:call(?MODULE, stop). 

%%动态加载跨服竞技处理进程 
get_mod_war2_supervisor_pid() ->
	ProcessName = misc:create_process_name(mod_war2_supervisor_process, [0]),
	case misc:whereis_name({global, ProcessName}) of
		Pid when is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true -> Pid;
				false -> 
					start_mod_war2_supervisor(ProcessName)
			end;
		_ ->
			start_mod_war2_supervisor(ProcessName)
	end.


%%启动跨服竞技监控模块 (加锁保证全局唯一)
start_mod_war2_supervisor(ProcessName) ->
	global:set_lock({ProcessName, undefined}),	
	ProcessPid = 
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> Pid;
					false -> 
						start_war2_supervisor(ProcessName)
				end;
			_ ->
				start_war2_supervisor(ProcessName)
		end,	
	global:del_lock({ProcessName, undefined}),
	ProcessPid.

%%开启跨服竞技监控模块
start_war2_supervisor(ProcessName) ->
    case supervisor:start_child(
               yg_server_sup,
               {mod_war2_supervisor,
                {mod_war2_supervisor, start_link,[[ProcessName,0]]},
                permanent, 10000, supervisor, [mod_war2_supervisor]}) of 
		{ok, Pid} ->
				timer:sleep(1000),
				Pid;
		_ ->
				undefined
	end.


%%
%% Local Functions
%%
init([ProcessName, Worker_id]) ->
    process_flag(trap_exit, true),	
	case misc:register(unique, ProcessName, self()) of
		yes ->
			if 
				Worker_id =:= 0 ->
					misc:write_monitor_pid(self(), mod_war2_supervisor, {}),
					misc:write_system_info(self(), mod_war2_supervisor, {});
				true->
			 		misc:write_monitor_pid(self(), mod_war2_supervisor_child, {Worker_id})
			end,
			%% 启动跨服分区服务工作进程
			lists:foreach(
			  fun(WorkId1) ->
					  mod_war2_supervisor:start_link([ProcessName, WorkId1])
			  end,
			  lists:seq(1, ?SCENE_WORKER_NUMBER)),
			Self = self(),
			init_war2(),
			{Times,Status} = lib_war2:init_war2_state(),
			{Sky,Land} = init_champion(),
			case opening_service() of
				false->
					erlang:send_after(10*1000, Self, {'NOCTICE_ENTER_WAR2_ALL'}),
					ok;
				true->
					Handle = erlang:send_after(10*60*1000, Self, {'SYNC_ELIMINATION'}),
					put(sync_elimination,Handle)
			end,
			War2State = get_war2_state(),
			State = #state{
						   times = Times,
						   state = Status,
						   sky = Sky,
						   land = Land,
						   war2_state=War2State
						  },
			start_timer(Self),
			io:format("10.Init mod_war2_supervisor finish!!!~n"),
			{ok, State};
		_ ->
			{stop,normal,#state{}}
	end.

%%加载个人记录
init_war2()->
	lib_war2:init_war2_record(),
	lib_war2:init_war2_elimination(),
	lib_war2:init_war2_bet(),
	lib_war2:init_war2_pape(),
	ok.

%%加载冠军数据
init_champion()->
	Sky = lib_war2:init_war2_champion(1),
	Land = lib_war2:init_war2_champion(2),
	{Sky,Land}.

%%启动定时器
start_timer(Self)->
	case opening_service() of
		true->
			timer_start(Self);
		false->
			case config:get_war_server_info() of
				[_,_,_,_,1]->
					timer_start(Self);
				_->
					skip
			end
	end.


%% cmd_timer_start(Self)->
%% 	NowSec  = util:get_today_current_second(),
%%  	StartSec = 14*3600+55*60,
%% %% 	StartSec = 19*3600+30*60,
%% 	case NowSec < StartSec of
%% 		true->
%% 			Handle = erlang:send_after((StartSec-NowSec)*1000, Self, {'CMD_WAR2'}),
%% 			put(cmd_war2,Handle);
%% 		false->
%% 			Handle = erlang:send_after((StartSec+86400-NowSec)*1000, Self, {'CMD_WAR2'}),
%% 			put(cmd_war2,Handle)
%% 	end.

timer_start(Self)->
	Timestamp = get_timer_time(),
	Handle = erlang:send_after(Timestamp,Self, {'UPDATE_WAR2_STATE'}),
	put(update_war2_state,Handle),
	erlang:send_after(10*1000, Self, {'TIMER_RESET'}),
	ok.

%% 获取定时器时间
get_timer_time()->
	NowSec = util:get_today_current_second(),
	round(86400-NowSec+10)*1000.

opening_service()->
	lib_war2:is_war2_server().

sync_war2_elimination_local(Data)->
	gen_server:cast(get_mod_war2_supervisor_pid(), {'SYNC_ELIMINATION_TO_LOCAL',[Data]}),
	ok.

sync_war2_history_local(Data)->
	gen_server:cast(get_mod_war2_supervisor_pid(), {'SYNC_HISTORY_TO_LOCAL',[Data]}),
	ok.
	
bet_popular(Data)->
	gen_server:cast(get_mod_war2_supervisor_pid(), {'BET_POPULAR',[Data]}),
	ok.

notice_apply()->
	get_mod_war2_supervisor_pid()!{'NOTICE_APPLY'},
	ok.
	
notice_enter_war2(Player)->
	gen_server:cast(get_mod_war2_supervisor_pid(), {'NOTICE_ENTER_WAR2',[Player]}),
	ok.

delwith_merge_data(SnBag,Platform,Sn)->
	gen_server:cast(get_mod_war2_supervisor_pid(), {'delwith_merge_data',[SnBag,Platform,Sn]}),
	ok.

cmd_open_war2(State)->
	case State of
		2->
			gen_server:cast(get_mod_war2_supervisor_pid(), {'CMD_TRYOUT'});
		3->
			gen_server:cast(get_mod_war2_supervisor_pid(), {'CMD_ELIMINATION_32'});
		4->
			gen_server:cast(get_mod_war2_supervisor_pid(), {'CMD_ELIMINATION_16'});
		5->
			gen_server:cast(get_mod_war2_supervisor_pid(), {'CMD_ELIMINATION_8'});
		6->
			gen_server:cast(get_mod_war2_supervisor_pid(), {'CMD_ELIMINATION_4'});
		7->
			gen_server:cast(get_mod_war2_supervisor_pid(), {'CMD_FINAL'});
		_->skip
	end.

cmd_open_elimination()->
	gen_server:cast(get_mod_war2_supervisor_pid(), {'OPEN_ELIMINATION'}).

cmd_check_state(State)->
	gen_server:cast(get_mod_war2_supervisor_pid(), {'CMD_CHECK_STATE',[State]}).

cmd_change_war2_state(S)->
	gen_server:cast(get_mod_war2_supervisor_pid(), {'CHANGE_WAR2_STATE',[S]}).

%%获取总冠军id
get_champoin()->
	case catch gen_server:call(get_mod_war2_supervisor_pid(), {'CHAMPION_ID'}) of
		{ok,C}->C;
		_->[]
	end.

%%重置
reset()->
	gen_server:cast(get_mod_war2_supervisor_pid(), {'RESET'}),
	ok.

%%获取分区中人数少的一个区
%%MemberCount[{1,[{Pid,COunt},{}]},{2,[{Pid,COunt},{}]}]
find_scene_member_limit(Grade,MemberCount)->
	case lists:keyfind(Grade, 1, MemberCount) of
		false->null;
		{_,SubareaCount}->
			if SubareaCount == []->null;
			   true->
				   SortFun = fun({_,P1}, {_,P2}) ->
									 P1 < P2 
							 end,
%% SortFun = fun({P1,_}, {P2,_P2}) ->
%% 									 P1 < P2 
%% 							 end,
				   NewSubareaCount = lists:sort(SortFun, SubareaCount),
				   [{SceneId,Num}|_] = NewSubareaCount,
				   NewSubareaCount1 = lists:keyreplace(SceneId, 1, NewSubareaCount, {SceneId,Num+1}),
				   {SceneId,lists:keyreplace(Grade, 1, MemberCount, {Grade,NewSubareaCount1})}
			end
	end.
	
%%获取分区场景信息
handle_call({'SUBAREA_SERVICE',[_Pid,PlayerId,_Lv]},_From,State)->
%% 	Grade = lib_war2:get_grade(Lv),
%% 	Grade =1,
	{NewScenePid1,NewSceneId1,NewState} = 
		try
			if State#state.state == 2->
				   %%获取选拔赛分区服务pid
				   case lists:keyfind(PlayerId, 1, State#state.player_scene) of
					   false->
						   case lib_war2:ets_select_war2_record(PlayerId) of
							   []->
								   [{ScenePid,SceneId}] = State#state.scene_temp,
								   {ScenePid,SceneId,State};
							   [Record]->
								   if Record#ets_war2_record.seed /=1 ->
										  case lists:keyfind(Record#ets_war2_record.grade, 1, State#state.subarea) of
											  false->
												  [{ScenePid,SceneId}] = State#state.scene_temp,
												  {ScenePid,SceneId,State};
											  {_,SubareaBag}->
												  %%Test
%% 												[SubareaInfo|_] = SubareaBag,
												case find_scene_member_limit(Record#ets_war2_record.grade,State#state.member_count) of
													null->
														[{ScenePid,SceneId}] = State#state.scene_temp,
														{ScenePid,SceneId,State};
													{SceneIdFind,NewMemberCount}->
														SubareaInfo = lists:keyfind(SceneIdFind, 3, SubareaBag),
														{Subarea,ScenePid,SceneId} = SubareaInfo,
														NewRecord = Record#ets_war2_record{subarea=Subarea},
														lib_war2:ets_update_war2_record(NewRecord),
														spawn(fun()->db_agent:update_war2_record([{subarea,Subarea}], [{pid,PlayerId}])end),
														PlayerScene = [{PlayerId,ScenePid,SceneId}|State#state.player_scene],
%% 												{ScenePid,SceneId,State#state{player_scene=PlayerScene}}
														{ScenePid,SceneId,State#state{player_scene=PlayerScene,member_count=NewMemberCount}}
												end
										  end;
									  true->
										  case lists:keyfind(Record#ets_war2_record.grade, 1, State#state.subarea) of
											  false->[{ScenePid,SceneId}] = State#state.scene_temp,
													 {ScenePid,SceneId,State};
											  {_,SubareaBag}->
												  case lists:keyfind(Record#ets_war2_record.subarea, 1, SubareaBag) of
													  false->
														  [{ScenePid,SceneId}] = State#state.scene_temp,
														  {ScenePid,SceneId,State};
													  {_Subarea,ScenePid,SceneId}->
%% 														  NewRecord = Record#ets_war2_record{subarea=Subarea},
%% 														  lib_war2:ets_update_war2_record(NewRecord),
%% 														  spawn(fun()->db_agent:update_war2_record([{subarea,Subarea}], [{pid,PlayerId}])end),
														  PlayerScene = [{PlayerId,ScenePid,SceneId}|State#state.player_scene],
														  {ScenePid,SceneId,State#state{player_scene=PlayerScene}}
												  end
										  end
								   end
						   end;
					   Info->
						   {_,ScenePid,SceneId} = Info,
						   {ScenePid,SceneId,State}
				   end;
			   State#state.state >=3 andalso State#state.state =< 7 ->
				   case lib_war2:is_fighter(PlayerId) of
					   true->
						   [{ScenePid,SceneId}] = State#state.elimination,
						   {ScenePid,SceneId,State};
					   false->
						   [{ScenePid,SceneId}] = State#state.scene_temp,
						   {ScenePid,SceneId,State}
				   end;
			   true->
				   [{ScenePid,SceneId}] = State#state.scene_temp,
				   {ScenePid,SceneId,State}
			end
		catch 
			_:_Reason -> 
				NewSceneId = mod_dungeon:get_unique_dungeon_id(730),
				{ok,NewScenePid}= mod_war2_subarea:start([State#state.times,0,0,NewSceneId,0]),
				{NewScenePid,NewSceneId,State#state{scene_temp=[{NewScenePid,NewSceneId}]}}
		end,
	{reply,{ok,[NewScenePid1,NewSceneId1]},NewState};

%%获取观战者等待场景id
handle_call({'VIEW_SCENE'},_From,State)->
	{NewScenePid,NewSceenId,NewState} = 
		try 
			[{ScenePid,SceneId}] = State#state.scene_temp,
			{ScenePid,SceneId,State}
		catch 
			_:_Reason -> 
				NewSceneId1 = mod_dungeon:get_unique_dungeon_id(730),
				{ok,NewScenePid1}= mod_war2_subarea:start([State#state.times,0,0,NewSceneId1,0]),
				{NewScenePid1,NewSceneId1,State#state{scene_temp=[{NewScenePid1,NewSceneId1}]}}
		end,
	{reply,{ok,[NewScenePid,NewSceenId]},NewState};

%%获取总冠军id
handle_call({'CHAMPION_ID'},_From,State)->
	ChampionBag = 
		try
			case lib_war2:init_war2_champion(1) of
				[]->[];
				[NickName|_]->%%nickname,career,sex,platform,sn
					Platform = config:get_platform_name(),
					Sn = config:get_server_num(),
					case lib_war2:ets_select_war2_record_by_name(Platform,Sn,NickName) of
						[]->
							case lib_war2:ets_select_war2_record_by_name(tool:to_binary(Platform),Sn,NickName) of
								[]->[];
								[R1]->
									[R1#ets_war2_record.pid]
							end;
						[R]->
							[R#ets_war2_record.pid]
					end
			end
		catch
			_:_Reason -> 
				[]
		end,
	{reply,{ok,ChampionBag},State};

%%获取玩家进度状态
handle_call({'HISTORY_STATE',[PlayerId,Nickname]},_From,State)->
	Res = lib_war2:player_war2_state(PlayerId,Nickname),
	{reply,{ok,Res},State};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

%%报名
handle_cast({'APPLY',[Status]},State)->
	spawn(fun()->
		Res = lib_war2:apply(Status),
		{ok,BinData} = pt_45:write(45101, Res),
		lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
	end),
	{noreply,State};

%%获取跨服竞技信息
handle_cast({'WAR2_INFO',[Status,Type]},State)->
	spawn(fun()->war2_info(Status,State,Type)end),
	{noreply,State};

%%同步淘汰赛记录到本地
handle_cast({'SYNC_ELIMINATION_TO_LOCAL',[Data]},State)->
	lib_war2:sync_elimination_data_local(Data),
	{noreply,State};


%%同步个人历史记录到本地
handle_cast({'SYNC_HISTORY_TO_LOCAL',[Data]},State)->
	lib_war2:sync_history_local(Data),
	{noreply,State};

%%玩家人气增加
handle_cast({'BET_POPULAR',[Data]},State)->
	lib_war2:popular_up(Data),
	{noreply,State};
 
%%同步冠军数据到本地
handle_cast({'SYNC_CHAMPION',[Data]},State)->
	lib_war2:champion_local(Data),
	{noreply,State};

%%发放单人竞技奖励
handle_cast({'WAR2_AWARD'},State)->
	spawn(fun()->lib_war2:war2_award()end),
	{noreply,State};

%%发放下注奖励
handle_cast({'WAR2_BET_PROVIDE'},State)->
	lib_war2:bet_provide(),
	{noreply,State};

%% %%查询物品奖励信息
%% handle_cast({'CHECK_GOODS_AWARD',[Status]},State)->
%% 	spawn(fun()->lib_war2:check_award_info(Status)end),
%% 	{noreply,State};

%% %%领取物品奖励
%% handle_cast({'GOODS_AWARD',[Status]},State)->
%% 	spawn(fun()->lib_war2:get_goods_award(Status)end),
%% 	{noreply,State};

%%查询我的下注
handle_cast({'MY_BET',[Status]},State)->
	spawn(fun()->lib_war2:my_bet(Status)end),
	{noreply,State};

%%我要下注
handle_cast({'BETTING',[Status,Type,Money,PlayerId]},State)->
	spawn(fun()->lib_war2:betting(Status,Type,Money,PlayerId,State#state.is_bet)end),
	{noreply,State};



%%请求进入单人竞技服务器
handle_cast({'ENTER_WAR2',[Status]},State)->
	spawn(fun()->lib_war2:enter_war2(Status)end),
	{noreply,State};

%%查询当前比赛状态
handle_cast({'GET_WAR2_STATE',[Status]},State)->
	spawn(fun()->
			{ok,BinData} = pt_45:write(45118, [State#state.war2_state]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
		  end),
	{noreply,State};

%%更改比赛状态
handle_cast({'CHANGE_WAR2_STATE',[S]},State)->
	spawn(fun()->
				  notice_update_war2_state(S)
				  end),
	{noreply,State#state{war2_state=S}};

%%定时器重置
handle_cast({'RESET'},State)->
	misc:cancel_timer(cmd_war2),
	start_timer(self()),
	{noreply,State};

%%GM命令，开启测试服务
handle_cast({'CMD_OPEN_SERVER'},State)->
	mod_leap_server:clear_database(),
	{noreply,State};

%%GM命令，开启选拔赛
handle_cast({'CMD_TRYOUT'},State)->
	self()!{'TRYOUT'},
	erlang:send_after(60*1000,self(),{'CMD_ELIMINATION'}),
	io:format("CMD_TRYOUT OPEN OK~n"),
	{noreply,State#state{state=2}};

handle_cast({'OPEN_ELIMINATION'},State)->
	erlang:send_after(600*1000,self(),{'CMD_ELIMINATION'}),
	io:format("CMD_ELIMINATION OK~n"),
	{noreply,State};

%% -record(state,{times = 0,			%%届次
%% 				state = 0,			%% 状态（1、报名；2、选拔赛；3、32强；4、16强；5、8强；6、4强；7、决赛）
%% 				sky = [],			%%天罡冠军信息
%% 				land = [],			%%地煞冠军信息
%% 				subarea = [],		%%分区场景服务pid信息[{分区，场景id，场景pid}]
%% 				elimination = [],	%%淘汰赛休息区场景服务
%% 				player_scene = [],	%%玩家场景信息[{玩家id，场景id，场景PID}]
%% 				scene_temp = [],			%%公共临时场景
%% 				match = [],			%%选拔赛配对表
%% 				end_time = 0,		%%选拔赛结束时间
%% 			   	is_end = 0			%%阶段结束标记
%% 				}).
handle_cast({'CMD_CHECK_STATE',[Type]},State)->
	spawn(fun()->
				  Res = 
					  case Type of
						  times -> State#state.times;
						  sky -> State#state.sky;
						  land-> State#state.land;
						  subarea->State#state.subarea;
						  elimination->State#state.elimination;
						  player_scene->State#state.player_scene;
						  member_count -> State#state.member_count;
						  war2_state->State#state.war2_state;
						  is_bet->State#state.is_bet;
						  _->undefined
					  end,
				  io:format("~p is ~p",[Type,Res])
		  end),
	{noreply,State};
%%GM 命令，开启下一场淘汰赛服务
handle_cast({'NOTICE_OPEN_NEXT_GAME'},State)->
	if State#state.state == 2->
		   notice_check_offtrack_grade(State#state.subarea),
		   self()!{'MSG_TRYOUT_END'};
	   true->skip
	end,
	misc:cancel_timer(elimination),
	SceneId = mod_dungeon:get_unique_dungeon_id(730),
	NewPid = 
		 case mod_war2_subarea:start([State#state.times,0,0,SceneId,State#state.state+1]) of
			 {ok,Pid}->Pid;
			 _->undefined
		 end,
	NewState = State#state{state = State#state.state+1,elimination = [{NewPid,SceneId}]},
	if State#state.state == 2->
		   notice_next_tryout_grade(State#state.subarea,SceneId,NewPid);
	   State#state.state >= 3->
		    notice_next_elimination_grade(State#state.elimination,SceneId,NewPid);
		   ok;
	   true->skip
	end,
	lib_war2:sync_elimination_data_remote(),
	erlang:send_after(3*60*1000, self(), {'IS_BET',[0]}),
	spawn(fun()->
				  mod_leap_server:sync_war2_bet(1)
		  end),
	{noreply,NewState#state{is_bet=1}};



%%查询是否可进入封神争霸
handle_cast( {'NOTICE_ENTER_WAR2',[Player]},State)->
	spawn(fun()->
				  lib_war2:notice_enter_war2(Player)end),
	{noreply,State};

%%同步战报到本地
handle_cast({'WAR2_PAGE',Page},State)->
	spawn(fun()->
				  lib_war2:war2_pape_to_local(Page)
		  end),
	{noreply,State};

%%查询战报
handle_cast({'CHECK_WAR2_PAPE',[Status,Grade,Type,PidA,PidB]},State)->
	spawn(fun()->
				  lib_war2:check_war2_pape(Status,Grade,Type,PidA,PidB)
		  end),
	{noreply,State};

%%选择观战
handle_cast({'CHOICE_VIEW',[Status,FightId]},State)->
	case lib_war:is_war_server() of
		false->
			{ok,BinData} = pt_45:write(45120, [6]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
		true->
			if State#state.state >=3 ->
				    [{ScenePid,_SceneId}] = State#state.elimination,
					gen_server:cast(ScenePid,{'CHOICE_VIEW',[Status,FightId]});
			   true->
				   {ok,BinData} = pt_45:write(45120, [7]),
				   lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
			end
	end,
	{noreply,State};

%%处理合服数据
handle_cast({'delwith_merge_data',[SnBag,Platform,Sn]},State)->
	spawn(fun()->
				  lib_war2:delwith_merge_data(SnBag,tool:to_binary(Platform),Sn)
		  end),
	{noreply,State};

handle_cast(_Msg,State)->
	 {noreply, State}.

%%通知进入封神争霸
handle_info({'NOCTICE_ENTER_WAR2_ALL'},State)->
	erlang:send_after(300*1000, self(), {'NOCTICE_ENTER_WAR2_ALL'}),
	if State#state.is_open ==1->
		   spawn(fun()->
						 lib_war2:notice_enter_war2_all()end);
	   true->skip
	end,
	{noreply,State};

%%投注开关
handle_info({'IS_BET',[Res]},State)->
	spawn(fun()->
				  mod_leap_server:sync_war2_bet(Res)
		  end),
	mod_leap_server:sync_war2_state(0),
	{noreply,State#state{is_bet=Res}};

handle_info({'IS_BET_UPDATE',[Res]},State)->
	{noreply,State#state{is_bet=Res}};

%%测试接口
handle_info({'CMD_WAR2'},State)->
	Week = util:get_date(),
	if Week /= 7->
		   Self = self(),
		   %%开放报名
		   misc:cancel_timer(notice_apply),
		   Handle_1 = erlang:send_after(5*60*1000, Self, {'NOTICE_APPLY'}),
		   put(notice_apply,Handle_1),
		   %%清除上一届报名信息	
		   lib_war2:clear_war2_record(), 
		   %%清除历史记录
		   db_agent:delete_war2_history(),
		   %%开启选拔赛
		   case opening_service() of
			   true->
				   mod_leap_server:clear_database(),
				   %% 			erlang:send_after(15*60*1000, Self, {'UPDATE_WAR2_STATE_CMD'}),
				   erlang:send_after(50*60*1000, Self, {'UPDATE_WAR2_STATE_CMD'}),
				   ok;
			   false->
				   %%清除投注记录
				   lib_war2:clear_war2_bet(),
				   ok
		   end,
		   erlang:send_after(5*60*1000, Self, {'SEED_APPLY'}),
		   NewState = State#state{times=State#state.times+1,state=2,subarea=[],player_scene= [],is_open=1};
	   true->
		   NewState=State
	end,
	misc:cancel_timer(cmd_war2),
	HandleWar2 = erlang:send_after(24*3600*1000, self(), {'CMD_WAR2'}),
	put(cmd_war2,HandleWar2),
	db_agent:update_war2_state([{times,1,add}],[]),
	{noreply,NewState};

%%种子选手报名
handle_info({'SEED_APPLY'},State)->
	case opening_service() of
		true->skip;
		false->
		lib_war2:auto_apply()
	end,
	%%清除上一期淘汰赛记录
	lib_war2:clear_war2_elimination(),
	lib_war2:clear_war2_pape(),
	{Sky,Land} = init_champion(),
	{noreply,State#state{sky=Sky,land=Land}};

%%测试定时器，更新状态，开启赛区
handle_info({'UPDATE_WAR2_STATE_CMD'},State)->
	self()!{'TRYOUT'},
	erlang:send_after(30*60*1000,self(),{'CMD_ELIMINATION'}),
%% 	erlang:send_after(10*60*1000,self(),{'CMD_ELIMINATION'}),
	{noreply,State#state{state=2}};

%%GM命令，开启淘汰赛
handle_info({'CMD_ELIMINATION'},State)->
	gen_server:cast(self(),{'NOTICE_OPEN_NEXT_GAME'}),
	{noreply,State};

%%定时器重置
handle_info({'TIMER_RESET'},State)->
	Self = self(),
	Week = util:get_date(),
	NowSec = util:get_today_current_second()*1000,
	if Week == 7->
		   case opening_service()of
			   false->
				   if ?APPLY_TIME > NowSec-> 
						  misc:cancel_timer(notice_apply),
						  Handle_1 = erlang:send_after(?APPLY_TIME-NowSec, Self, {'NOTICE_APPLY'}),
						  put(notice_apply,Handle_1),
						  misc:cancel_timer(seed_apply),
						  HandleSeed = erlang:send_after(?APPLY_TIME-NowSec, Self, {'SEED_APPLY'}),
						  put(seed_apply,HandleSeed);
					  true->
						  misc:cancel_timer(notice_apply),
						  Handle_1 = erlang:send_after(10000, Self, {'NOTICE_APPLY'}),
						  put(notice_apply,Handle_1),
						  ok
				   end;
			   true->skip
		   end,
		   Is_bet=0,
		   ok;
	   Week == 1->
		   case opening_service() of
			   false->
				   if 
					   NowSec < 15*3600*1000->
						   misc:cancel_timer(notice_apply),
						   Handle_1 = erlang:send_after(10000, Self, {'NOTICE_APPLY'}),
						   put(notice_apply,Handle_1),
						   ok;
					   true->skip
				   end;
			   true->
				   if ?OPEN_REST_SCENE > NowSec ->
						  misc:cancel_timer(tryout),
						  Handle_2 = erlang:send_after(?OPEN_REST_SCENE-NowSec, Self, {'TRYOUT'}),
						  put(tryout,Handle_2);
					  true->skip
				   end
		   end,
		   Is_bet=0,
		   ok;
	   true->
		   case opening_service() of
			   true->
				   if NowSec < ?OPEN_REST_SCENE->
						  misc:cancel_timer(elimination),
						  Handle_3 = erlang:send_after(?OPEN_REST_SCENE-NowSec,Self ,{'ELIMINATION'}),
						  put(elimination,Handle_3);
					  true->skip
				   end;
			   false->skip
		   end,
		   Is_bet=
			   if NowSec <  15*3600*1000 ->
					  erlang:send_after(15*3600*1000-NowSec, self(), {'IS_BET',[0]}),
					  1;
				  true->0
			   end
	end,
	NewState = State#state{is_open=1,is_bet=Is_bet},
	GameDate =
		case util:get_date() of
			7->1;
			W->W+1
		end,
	db_agent:update_war2_state([{state,GameDate}],[]),
	{noreply,NewState#state{state=GameDate}};


%%更新跨服单人竞技届次状态
handle_info({'UPDATE_WAR2_STATE'},State)->
	misc:cancel_timer(update_war2_state),
	Self = self(),
	Week = util:get_date(),
	if Week == 7->
		   %%开放报名
		   misc:cancel_timer(notice_apply),
		   Handle_1 = erlang:send_after(?APPLY_TIME, Self, {'NOTICE_APPLY'}),
		   put(notice_apply,Handle_1),
		   %%种子选手报名
		   misc:cancel_timer(seed_apply),
		   HandleSeed = erlang:send_after(?APPLY_TIME, Self, {'SEED_APPLY'}),
		   put(seed_apply,HandleSeed),
		   %%清除上一届报名信息
		   lib_war2:clear_war2_record(),
		   %%清除历史记录
		   db_agent:delete_war2_history(),
		   case opening_service() of
			   true->
				   mod_leap_server:clear_database();
			   false->
				   %%清除投注记录
				   lib_war2:clear_war2_bet(),
				   ok
		   end,
		   NewState = State#state{state=1,times = State#state.times+1,subarea=[],player_scene= [],is_end=0,is_open=1};
	   Week == 1 ->
		   %%开启选拔赛
		   case opening_service() of
			   true->
				   misc:cancel_timer(tryout),
				   Handle_2 = erlang:send_after(?OPEN_REST_SCENE, Self, {'TRYOUT'}),
				   put(tryout,Handle_2),
				   ok;
			   false->
				   ok
		   end,
		   NewState = State#state{state=Week+1,subarea=[],player_scene= [],is_end=0,is_open=1};
	   Week >=2 andalso Week =< 6->
		   %%初始化报名数据
		   lib_war2:ets_clear_war2_record(),
		   lib_war2:init_war2_record(),
		   lib_war2:ets_clear_war2_elimination(),
		   lib_war2:init_war2_elimination(),
		   erlang:send_after(15*3600*1000, self(), {'IS_BET',[0]}),
		   %%淘汰赛
		   case opening_service() of
			   true->
				   mod_leap_server:sync_war2_state(5),
				   misc:cancel_timer(elimination),
				   Handle_3 = erlang:send_after(?OPEN_REST_SCENE,Self ,{'ELIMINATION'}),
				   put(elimination,Handle_3),
				   
				   ok;
			   false->skip
		   end,
		   NewState = State#state{state=Week+1,subarea=[],is_end=0,player_scene= [],is_open=1,is_bet=1};
	   true->
		   NewState = State
	end,
	db_agent:update_war2_state([{state,NewState#state.state},{times,NewState#state.times}],[]),
	TimerHandle = erlang:send_after(86400*1000, self(), {'UPDATE_WAR2_STATE'}),
	put(update_war2_state,TimerHandle),
	{noreply,NewState};

%%通知报名
handle_info({'NOTICE_APPLY'},State)->
	Msg = "<font color='#FEDB4F'>封神争霸</font>报名开放中，诚邀各路神仙豪杰踊跃参与！<a href='event:5'><font color='#00FF00'><u>》》我要报名《《</u></font></a>",
	lib_chat:broadcast_sys_msg(6,Msg),
	case  util:get_date() of
		7->
			erlang:send_after(60*60*1000, self(), {'NOTICE_APPLY'});
		1->
			
			case util:get_today_current_second() < 13*3600+0*60 of
				true->
					spawn(fun()->notice_update_war2_state(1)end),
					erlang:send_after(60*60*1000, self(), {'NOTICE_APPLY'});
				false->
					spawn(fun()->notice_update_war2_state(0)end)
			end;
		_->skip
	end,
	
	{noreply,State#state{war2_state=1}};

%%开启选拔赛
handle_info({'TRYOUT'},State)->
	misc:cancel_timer(tryout),
	lib_war2:ets_clear_war2_record(),
	lib_war2:init_war2_record(),
	%%创建分区服务
	{SkySubarea,LandSubarea} = create_subarea_service(State#state.state,State#state.times),
	SceneId = mod_dungeon:get_unique_dungeon_id(730),
	NewPid = 
		 case mod_war2_subarea:start([State#state.times,0,0,SceneId,0]) of
			 {ok,Pid}->Pid;
			 _->undefined
		 end,
	SkyCount = [{SceneId2,0}||{_,_,SceneId2}<-SkySubarea],
	LandCount = [{SceneId1,0}||{_,_,SceneId1}<-LandSubarea],
	NewState = State#state{member_count = [{1,SkyCount},{2,LandCount}],subarea=[{1,SkySubarea},{2,LandSubarea}],scene_temp=[{NewPid,SceneId}]},
	erlang:send_after((3600+20*60)*1000, self(), {'IS_END_STATE',[1]}),
%% 	封神争霸选拔赛即将开始，请已报名的选手进入比赛场景准备比赛！>>>进入比赛<<<
	Msg = "<font color='#FEDB4F'>封神争霸</font>选拔赛即将开始，请已报名的选手进入比赛场景准备比赛！<a href='event:5'><font color='#00FF00'><u>》》进入比赛《《</u></font></a>",
	spawn(fun()->mod_leap_server:remote_server_msg(Msg)end),
%% 	erlang:send_after(3*60*1000, self,{'MSG_TRYOUT'} ),
	erlang:send_after(15*60*1000, self,{'MSG_TRYOUT'} ),
	%%种子选手自动晋级
	erlang:send_after(5*1000, self(), {'SEED_PLAYER_OFFTRACK'}),
	spawn(fun()->
				  lib_war2:notice_enter_war2_all(),
				  notice_update_war2_state(2),
				  mod_leap_server:sync_war2_state(2)
				  end),
	
	{noreply,NewState#state{war2_state=2}};

%%选拔赛开始
handle_info({'MSG_TRYOUT'},State)->
	spawn(fun()->
				  Msg = "<font color='#FEDB4F'>封神争霸</font>选拔赛现在开始，请已报名的选手进入比赛场景比赛！<a href='event:5'><font color='#00FF00'><u>》》进入比赛《《</u></font></a>",
				  spawn(fun()->mod_leap_server:remote_server_msg(Msg)end),
				  lib_chat:broadcast_sys_msg(6,Msg)
		  end),
	spawn(fun()->
				  notice_update_war2_state(3),
					mod_leap_server:sync_war2_state(3)
				  end),
	{noreply,State#state{war2_state=3}};

%%选拔赛结束
handle_info({'MSG_TRYOUT_END'},State)->
	spawn(fun()->
				  Num = length(lib_war2:ets_select_war2_elimination_all()),
				  Msg = io_lib:format("<font color='#FEDB4F'>封神争霸</font>选拔赛圆满结束，共~p位选手晋级，让我们期待他们在下一阶段的表现！<a href='event:5'><font color='#00FF00'><u>》》查看赛程《《</u></font></a>",[Num]),
				  spawn(fun()->mod_leap_server:remote_server_msg(Msg)end),
				  lib_chat:broadcast_sys_msg(6,Msg)
		  end),
	{noreply,State};

%%开启淘汰赛服务
handle_info({'ELIMINATION'},State)->
	misc:cancel_timer(elimination),
	%%初始化数据
	lib_war2:ets_clear_war2_elimination(),
	lib_war2:init_war2_elimination(),
	TempSceneId = mod_dungeon:get_unique_dungeon_id(730),
	TempPid = 
		 case mod_war2_subarea:start([State#state.times,0,0,TempSceneId,0]) of
			 {ok,TPid}->TPid;
			 _->undefined
		 end,
	
	SceneId = mod_dungeon:get_unique_dungeon_id(730),
	NewPid = 
		 case mod_war2_subarea:start([State#state.times,0,0,SceneId,State#state.state]) of
			 {ok,Pid}->Pid;
			 _->undefined
		 end,
	NewState = State#state{elimination = [{NewPid,SceneId}],scene_temp=[{TempPid,TempSceneId}]},
	%%系统广播
%% 	elimination_msg(State#state.times,State#state.state),
	notice_update_war2_state(3),
	{noreply,NewState};

%%种子选手分区，自动晋级
handle_info({'SEED_PLAYER_OFFTRACK'},State)->
	seed_player_offtrack([1,2],State#state.subarea),
	{noreply,State};

%%更新比赛状态
handle_info({'WAR2_STATE',[S]},State)->
	spawn(fun()->
				  notice_update_war2_state(S)
				  end),
	mod_leap_server:sync_war2_state(S),
	{noreply,State#state{war2_state=S}};

handle_info({'IS_END_STATE',[STATE]},State)->
	{noreply,State#state{is_end=STATE}};

%%定时同步淘汰赛数据
handle_info({'SYNC_ELIMINATION'},State)->
	misc:cancel_timer(sync_elimination),
	Handle = erlang:send_after(10*60*1000, self(), {'SYNC_ELIMINATION'}),
	put(sync_elimination,Handle),
	if State#state.is_open ==1->
		lib_war2:sync_elimination_data_remote();
	   true->skip
	end,
	{noreply,State};


handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()).

code_change(_OldVsn, State, _Extra)->
    {ok, State}.

%%竞技信息
war2_info(Status,State,Type)->
	Champion = get_champion_info(State,Type),
	CNow = get_champion_now(Type),
	Award = lib_war2:check_godos_award(Status#player.id),
	EliInfo = lib_war2:get_elimination_info(Type),
	MyBet = lib_war2:get_my_bet(Status#player.id,State#state.is_bet),
	IsApply = lib_war2:is_apply(Status#player.id),
	{ok,BinData} = pt_45:write(45102,[State#state.times,util:get_date(),Champion,CNow,Award,MyBet,IsApply,EliInfo]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok.

get_champion_now(Grade)->
	case lib_war2:ets_select_war2_elimination_champion(Grade) of
		[]->[<<>>,0,0,<<>>,0];
		[R|_]->[R#ets_war2_elimination.nickname,
			  R#ets_war2_elimination.career,
			  R#ets_war2_elimination.sex,
			  R#ets_war2_elimination.platform,
			  R#ets_war2_elimination.sn
			 ]
	end.



get_champion_info(State,Type)-> 
	case Type of
		1->
			case State#state.sky of
				[]->[<<>>,<<>>,0]; 
				%%nickname,career,sex,platform,sn
				[NickName,_,_,Platform,Sn]->
					[NickName,Platform,Sn]
			end;
		_->
			case State#state.land of
				[]->
					[<<>>,<<>>,0];
				[NickName,_,_,Platform,Sn]->
					[NickName,Platform,Sn]
			end
	end.

%创建分区服务
create_subarea_service(State,Times)->
	SkySubarea = open_subarea_service([1,2,3,4],1,State,[],Times),
	LandSubarea = open_subarea_service([1,2,3,4],2,State,[],Times),
	{SkySubarea,LandSubarea}.

%%[{分区，[{场景id，场景pid,场景人数统计}]}]
open_subarea_service([],_Grade,_State,ServerInfo,_Times)->
	ServerInfo;
open_subarea_service([Subarea|Subarealist],Grade,State,ServerInfo,Times)->
	SceneId = mod_dungeon:get_unique_dungeon_id(730),
	case mod_war2_subarea:start([Times,Grade,Subarea,SceneId,State]) of
		{ok,Pid}->
			open_subarea_service(Subarealist,Grade,State,[{Subarea,Pid,SceneId}|ServerInfo],Times);
		_->
			open_subarea_service(Subarealist,Grade,State,ServerInfo,Times)
	end.


%%淘汰赛开启系统通知
%% elimination_msg(_Times,State)->
%% 	if State >=3 andalso State =< 6 ->
%% 		   spawn(fun()->
%% 						 Msg = io_lib:format("<font color='#FEDB4F'>封神争霸</font>~p强淘汰赛即将开始，请参赛选手进入比赛场景准备比赛！<a href='event:5'><font color='#00FF00'><u>》》进入比赛《《</u></font></a>",[get_state_name(State)]),
%% 						 mod_leap_server:remote_server_msg(Msg),
%% 						 ok
%% 				 end);
%% 	   true->skip
%% 	end.
%% 
%% get_state_name(State)->
%% 	case State of
%% 		3->32;
%% 		4->16;
%% 		5->8;
%% 		_6->4
%% 	end.
%%种子选手自动分区，自动晋级
seed_player_offtrack([],_PidSubarea)->ok;
seed_player_offtrack([Grade|GradeBag],PidSubarea)->
	case lib_war2:ets_select_war2_record_by_seed(Grade) of
		[]->skip;
		RecordBag ->
			seed_player_offtrack_loop(RecordBag,[1,2,3,4],Grade,PidSubarea)
	end,
	seed_player_offtrack(GradeBag,PidSubarea).

seed_player_offtrack_loop([],[],_Grade,_PidSubarea)->skip;
seed_player_offtrack_loop([],_,_Grade,_PidSubarea)->skip;
seed_player_offtrack_loop(_,[],_Grade,_PidSubarea)->skip;
seed_player_offtrack_loop([Record|RecordBag],[Subarea|SubareaBag],Grade,PidSubarea)->
	case get_subarea_pid(PidSubarea,Subarea,Grade) of
		undefined ->skip;
		Pid->
			Pid!{'SEED_OFFTRACK',[Record]},
			spawn(fun()->
						  NewRecord = Record#ets_war2_record{subarea=Subarea},
						  lib_war2:ets_update_war2_record(NewRecord),
						  db_agent:update_war2_record([{subarea,Subarea}], [{pid,Record#ets_war2_record.pid}])
				  end),
			lib_war2:tryout(Record, Subarea, 1, Grade, 3, 1)
	end,
	seed_player_offtrack_loop(RecordBag,SubareaBag,Grade,PidSubarea).
	
%%获取分区PID
get_subarea_pid(PidBag,Subarea,Grade)->
	case lists:keyfind(Grade, 1, PidBag) of
		false->undefined;
		{_,PidInfo} ->
			case lists:keyfind(Subarea, 1, PidInfo) of
				false->undefined;
				{_,Pid,_}->Pid
			end
	end.

%%通知场景检查出线名额
notice_check_offtrack_grade([])->
	ok;
notice_check_offtrack_grade([SceneInfo|SceneBag])->
	{_,SceneSub} = SceneInfo,
	notice_check_offtrack_subarea(SceneSub),
	notice_check_offtrack_grade(SceneBag).	

notice_check_offtrack_subarea([])->
	ok;
notice_check_offtrack_subarea([{_Subarea,ScenePid,_SceneId}|SceneBag])->
	gen_server:cast(ScenePid, {'NOTICE_CHECK_OFFTRACK'}),
	notice_check_offtrack_subarea(SceneBag).

%%GM命令，通知玩家进入淘汰赛场景
notice_next_tryout_grade([],_SceneId,_ScenePid)->
	ok;
notice_next_tryout_grade([SceneInfo|SceneBag],SceneId,ScenePid)->
	{_,SceneSub} = SceneInfo,
	notice_next_tryout_subarea(SceneSub,SceneId,ScenePid),
	notice_next_tryout_grade(SceneBag,SceneId,ScenePid).

notice_next_tryout_subarea([],_SceneId,_ScenePid)->
	ok;
notice_next_tryout_subarea([{_Subarea,ScenePid,_SceneId}|SceneBag],NextSceneId,NextScenePid)->
	gen_server:cast(ScenePid, {'NOTICE_CHANGE_SCENE_OFFTRACK',[NextSceneId,NextScenePid]}),
	notice_next_tryout_subarea(SceneBag,NextSceneId,NextScenePid).

%%GM命令，通知玩家更换淘汰赛场景
notice_next_elimination_grade([],_SceneId,_ScenePid)->
	ok;
notice_next_elimination_grade([{Pid,_SceneId}|SceneBag],NextSceneId,NextScenePid)->
	gen_server:cast(Pid, {'NOTICE_CHANGE_SCENE_ELIMINATION',[NextSceneId,NextScenePid]}),
	notice_next_elimination_grade(SceneBag,NextSceneId,NextScenePid).

%%全服更新比赛状态
notice_update_war2_state(State)->
	{ok,BinData} = pt_45:write(45118, [State]),
	mod_disperse:broadcast_to_world(ets:tab2list(?ETS_SERVER), BinData).
%% notice_next_elimination_subarea([],_SceneId,_ScenePid)->
%% 	ok;
%% notice_next_elimination_subarea([{_Subarea,ScenePid,SceneId}|SceneBag],NextSceneId,NextScenePid)->
%% 	gen_server:cast(ScenePid, {'NOTICE_CHANGE_SCENE_ELIMINATION',[NextSceneId,NextScenePid]}),
%% 	notice_next_elimination_subarea(SceneBag,SceneId,ScenePid).


%%获取比赛状态(0无，1报名，2开放进入，3比赛，4奖励，5投注)
get_war2_state()->
	NowSec = util:get_today_current_second(),
	case util:get_date() of
		7->
			if NowSec < 9 * 3600 -> 0;
			   true-> 1
			end;
		1->
			if NowSec < 15 * 3600-> 1;
			   NowSec < 15 * 3600 + 45 * 60 -> 0;
			   NowSec < 16 * 3600 + 30 * 60 -> 3;
			   true-> 0
			end;
		6->
			if NowSec < 15 * 3600-> 5;
			   NowSec < 15 * 3600 + 45 * 60 -> 0;
			   NowSec < 16 * 3600 + 30 * 60 -> 3;
			   true-> 4
			end;
		_->
			if NowSec < 15 * 3600-> 5;
			   NowSec < 15 * 3600 + 45 * 60 -> 0;
			   NowSec < 16 * 3600 + 30 * 60 -> 3;
			   true-> 0
			end 
	end.