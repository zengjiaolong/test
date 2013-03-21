%% Author: Administrator
%% Created: 2011-8-16
%% Description: TODO: 跨服战场
-module(mod_war_supervisor).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-export([start_link/1, 
		 start/0,
		 stop/0,
		 get_mod_war_supervisor_pid/0
		 ]).

-export([
		 get_wait_server_pid/1, 		%%获取分组休息区Pid
		 get_scene_server_pid/1	,		%%查询场景服务Pid
		 war_award/1,					%%	封神大会奖励
		 add_war_record/1,				%%添加封神大会历史记录到本地
		 get_record_to_remote/0,		%%获取记录到远程
		 update_to_team/1,
		 add_new_test/1,
		 had_syn_data/2,
		 get_timer_time/1,
		 check_state/1,					%%查询State参数
		 reset/0,
		 init_vs/0,
		 init_team/0,
		 change_state/2,
		 syn_war_point/1,
		 notice_enter_war/1,
		 set_war_award/3
		]).

-record(state,{
			   times  = 0,
			   max_lv = 0,			%%最大分组
			   round = 0,			%%轮次
			   status = 0,			%%1休息，2比赛,3比赛准备
			   state = 0,			%% 大会流程状态 0 报名1 第X轮 2 已结束
			   timestamp = 0,		%%剩余时间
			   max_round = 0,		%%最大轮次
			   start_time = 0,		%%开始时间
			   end_time = 0,		%%结束时间
			   team_info = [],		%%队伍信息
			   vs_info = [],		%%对战信息
			   group = [],			%%分组战场PID
			   wait_info=[],			%%等待区Pid
			   scene_pid = []		%%战斗场景Pid

			   }).
%% -define(BC_TIMER)

-define(WAR_SCENE,760).%%战场id
-define(INIT_SERVER_TIMER,25000). %%初始化参赛服务器定时器
-define(INIT_TEAM_TIMER,1*60*1000). %%初始化参赛队伍定时器
-define(INIT_REST_TIMER,3000).	%%初始化休息区定时器 
 -define(INIT_CAEATE_WAR,55*60*1000).%%初始化分组战场
%%-define(INIT_CAEATE_WAR,8*60*1000).%%初始化分组战场  
-define(GET_TOP_TEN,60*60*1000).%%获取前十
%% -define(GET_TOP_TEN,10*60*1000).%%获取前十
-define(NOTICE_WAR_STATE,32*60*1000).%%通知跨服开放
-define(NOTICE_WAR_STATE_SEC,55*60*1000).%%通知跨服开放
%% -define(NOTICE_WAR_STATE,5*60*1000).%%通知跨服开放
-define(NEXT_CAEATE_WAR,13*60*1000).%%开启下一轮分组战场
%% -define(NEXT_CAEATE_WAR,7*60*1000).%%开启下一轮分组战场
-define(REST,10*60*1000).%%进入休息
%% -define(REST,5*60*1000).%%进入休息

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

reset()->
	mod_leap_client:reset(),
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'reset'}).

%%获取分组等待区pid
get_wait_server_pid(PlayerId)->
	gen_server:call(mod_war_supervisor:get_mod_war_supervisor_pid(),{'get_wait_server',PlayerId}).
%%查询场景服务PID
get_scene_server_pid(SceneId)->
	gen_server:call(mod_war_supervisor:get_mod_war_supervisor_pid(),{'get_scene_pid',SceneId}).

%%封神大会奖励
war_award([GoodsNum,Other])->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'war_award',[GoodsNum,Other]}).

%%添加封神大会历史记录到本地
add_war_record(Record)->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'add_war_record',[Record]}).

%%获取封神大会历史记录到远程
get_record_to_remote()->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'get_record_to_remote'}).

%%数据同步通知
had_syn_data(Platform,Sn)->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'had_syn_data',[Platform,Sn]}).

%%查询state参数
check_state(Type)->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'check_state',[Type]}).

%%add_new_test
add_new_test(PlayerStatus)->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'add_new_test',[PlayerStatus]}).

%%
change_state(Key,Value)->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'change_state',[Key,Value]}).
init_team()->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'init_team'}).
%%init_vs
init_vs()->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'init_vs'}).

%%更新分组玩家数据
update_to_team([Id,PlayerId,NickName,Career,Realm,Lv,Sex,Vip,Att,Platform,Sn])->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'update_to_team',[Id,PlayerId,NickName,Career,Realm,Lv,Sex,Vip,Att,Platform,Sn]}),
	ok.

%%同步玩家积分
syn_war_point([NickName,P,Content])->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'syn_war_point',[NickName,P,Content]}),
	ok.

%%通知玩家进入战场
notice_enter_war(Status)->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'notice_enter_war',[Status]}),
	ok.

%%设置声望
set_war_award(PlayerId,Type,Value)->
	gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'set_war_award',[PlayerId,Type,Value]}),
	ok.

%%动态加载跨服战场处理进程 
get_mod_war_supervisor_pid() ->
	ProcessName = misc:create_process_name(mod_war_supervisor_process, [0]),
	case misc:whereis_name({global, ProcessName}) of
		Pid when is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true -> Pid;
				false -> 
					start_mod_war_supervisor(ProcessName)
			end;
		_ ->
			start_mod_war_supervisor(ProcessName)
	end.


%%启动跨服战场监控模块 (加锁保证全局唯一)
start_mod_war_supervisor(ProcessName) ->
	global:set_lock({ProcessName, undefined}),	
	ProcessPid = 
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> Pid;
					false -> 
						start_war_supervisor(ProcessName)
				end;
			_ ->
				start_war_supervisor(ProcessName)
		end,	
	global:del_lock({ProcessName, undefined}),
	ProcessPid.

%%开启跨服战场监控模块
start_war_supervisor(ProcessName) ->
    case supervisor:start_child(
               yg_server_sup,
               {mod_war_supervisor,
                {mod_war_supervisor, start_link,[[ProcessName,0]]},
                permanent, 10000, supervisor, [mod_war_supervisor]}) of 
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
					misc:write_monitor_pid(self(), mod_war_supervisor, {}),
					misc:write_system_info(self(), mod_war_supervisor, {});
				true->
			 		misc:write_monitor_pid(self(), mod_war_supervisor_child, {Worker_id})
			end,
			Self = self(),
			%%加载历史记录
			lib_war:init_war_team_all(),
			%%加载玩家数据到内存
			lib_war:init_war_player(),
			lib_war:init_war_award(),
			%%启动初始化玩家数据定时器
			case lib_war:is_war_server() of
				true->
					%%启动初始化可参赛服务器定时器
					check_war_state(),
					TimerHandle2=erlang:send_after(get_timer_time(?INIT_WAR_TEAM_TIME), Self, {'init_team_info'}),
					put(init_team_info,TimerHandle2),
					ok;
				false->
					TimerHandle3 = erlang:send_after(get_timer_time(?WAR_SIGN_UP_OPEN),Self,{'init_match_player'}),
					put(init_match_player,TimerHandle3),
					erlang:send_after(10000,Self,{'init_war_record'}),
					ok
			end,	
			State = #state{},
			io:format("8.Init mod_war_supervisor finish!!!~n"),
    		{ok, State};
		_ ->
			{stop,normal,#state{}}
	end.

check_war_state()->
	{Type,Times,State,Lv,Round,MaxRound} =  lib_war:select_war_state(),
	if Type =:=0 orelse State =:= 3->
		   %%测试接口
%%		  ServerHandle=  erlang:send_after(?INIT_SERVER_TIMER,self(),{'init_server_info'}),
 			ServerHandle = erlang:send_after(get_timer_time(?WAR_SIGN_UP_OPEN),self(),{'init_server_info'}),
			put(init_server_info,ServerHandle);
	   true->
		   if State =:= 0 ->
				  TimesHandle = erlang:send_after(10000,self(),{'init_times_info',Times,Lv}),
				  put(init_times_info,TimesHandle);
			  true->
				   ConHandle= erlang:send_after(?INIT_SERVER_TIMER,self(),{'continue_team_info',Times,Lv,Round,MaxRound}),
				   put(continue_team_info,ConHandle)
		   end
	end,
	ok.
		
%% 统一模块+过程调用(call)
handle_call({apply_call, Module, Method, Args}, _From, State) ->
%% 	?DEBUG("mod_scene_apply_call: [~p/~p/~p]", [Module, Method, Args]),	
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_war_supervisor_apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
			 error;
		 DataRet -> DataRet
	end,
    {reply, Reply, State};

%%获取等待区服务Pid
handle_call({'get_wait_server',PlayerId},_,State)->
	{WaitPid,Scene,NewState}= 
		try 
			case lib_war:select_war_player(PlayerId) of
				[]->
					SceneId = mod_dungeon:get_unique_dungeon_id(760),
					case mod_war_rest:start([100,SceneId]) of
						{ok,Pid}->
							State1 = State#state{wait_info=[{100,Pid,SceneId}|State#state.wait_info]},
							{Pid,SceneId,State1};
						_->
							{undefined,undefined,State}
					end;
%% 					{undefined,undefined,State};
				[Info]->
					Lv = (Info#ets_war_player.lv+1)div 2,
					case lists:keyfind(Lv,1,State#state.wait_info) of
						false-> 
							SceneId = mod_dungeon:get_unique_dungeon_id(760),
							case mod_war_rest:start([Lv,SceneId]) of
								{ok,Pid}->
									State1 = State#state{wait_info=[{Lv,Pid,SceneId}|State#state.wait_info]},
									{Pid,SceneId,State1};
								_->
									{undefined,undefined,State}
							end;
						{_Lv,Pid,SceneId}->
							{Pid,SceneId,State}
					end
			end
		catch
			_:_Reason -> 
				SceneId1 = mod_dungeon:get_unique_dungeon_id(760),
				case mod_war_rest:start([100,SceneId1]) of
					{ok,Pid1}->
						State2 = State#state{wait_info=[{100,Pid1,SceneId1}|State#state.wait_info]},
						{Pid1,SceneId1,State2};
					_->
						{undefined,undefined,State}
				end
		end,
	{reply,{ok,[WaitPid,Scene]},NewState};

%%获取场景服务Pid
handle_call({'get_scene_pid',SceneId},_,State)->
	NewPid =
		try
			case lists:keyfind(State#state.round,1,State#state.scene_pid) of
				false->undefined;
				{_,ScenePid}->
					case lists:keyfind(SceneId, 1, ScenePid) of
						false->undefined;
						{_,Pid}->Pid
					end
			end
		catch
			_:_Reson->undefined
		end,
	{reply,{ok,[NewPid]},State};


handle_call(_Request, _From, State) ->
    {reply, ok, State}.

%% 统一模块+过程调用(cast)
handle_cast({apply_cast, Module, Method, Args}, State) ->
%% 	?DEBUG("mod_scene_apply_cast: [~p/~p/~p]", [Module, Method, Args]),	
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_war_supervisor_apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
			 error;
		 _ -> ok
	end,
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

%%本服聊天频道
handle_cast({'chat',[PlayerId, BinData]},State)->
	spawn(fun()->chat_sn(PlayerId,BinData)end),
	{noreply,State};

%%查看大会历史记录
handle_cast({'match_record',[Status,Times]},State)->
	spawn(fun()->get_war_record(Status,Times,State#state.times)end),
	{noreply, State};


%%报名
handle_cast({'sign_up',[Status]},State)->
	spawn(fun()->war_sign_up(Status)end),
	{noreply,State};

%%取消报名
handle_cast({'cancel_sign_up',[Status]},State)->
	spawn(fun()->war_cancel_sign_up(Status)end),
	{noreply,State};

%%查看报名信息
handle_cast({'sign_up_info',[Status]},State)->
	spawn(fun()->sign_up_info(Status)end),
	{noreply,State};

%%资格邀请
handle_cast({'invite',[Status,NickName]},State)->
	spawn(fun()->war_invite(Status,NickName)end),
	{noreply,State};

	
%%资格转让请求
handle_cast({'transfer_request',[Status,NickName]},State)->
	spawn(fun()->war_request_transfer(Status,NickName)end),
	{noreply,State};

%%回应资格转让
handle_cast({'transfer_answer',[Status,Res,NickName]},State)->
	spawn(fun()->war_answer_transfer(Status,NickName,Res)end),
	{noreply,State};


%%查看参赛队伍
handle_cast({'match_team',[Status]},State)->
	spawn(fun()->check_war_player(Status)end),
	{noreply,State};


%%进入封神大会
handle_cast({'enter_match',[Status]},State)->
	spawn(fun()->enter_match(Status)end),
	{noreply,State};


%%查看全体参赛队伍
handle_cast({'war_team',[Status]},State)->
	spawn(fun()->war_team(Status,State)end),
	{noreply,State};


%%查看对阵表
handle_cast({'war_vs',[Status]},State)->
	spawn(fun()->war_vs(Status,State)end),
	{noreply,State};


%%查看积分
handle_cast({'war_point',[Status]},State)->
	spawn(fun()->war_point(Status,State)end),
	{noreply,State};
 

%%查看比赛状态
handle_cast({'war_state',[Status]},State)->
	spawn(fun()->war_state(Status,State)end),
	{noreply,State};

%%查看比赛时间
handle_cast({'war_time',[Status]},State)->
	spawn(fun()->war_time(Status,State)end),
	{noreply,State};


%%封神大会奖励
handle_cast({'war_award',[GoodsNum,Other]},State)->
	Timestamp = util:unixtime()-7*3600,
	PlayerBag = db_agent:get_player_bag(Timestamp),
	[spawn(fun()->
				   lib_war:war_award(Pid,NickName,GoodsNum,Other)
		   end)||[Pid,NickName]<-PlayerBag],
	{noreply,State};

%%发放封神争霸奖励
handle_cast({'war2_award',[PlayerId,Grade,Rank,Point,Goods]},State)->
	spawn(fun()->lib_war2:award(PlayerId, Grade, Rank, Point, Goods)end),
	{noreply,State};

%%查询封神争霸物品奖励信息
handle_cast({'CHECK_GOODS_AWARD',[Status]},State)->
	spawn(fun()->lib_war2:check_award_info(Status)end),
	{noreply,State};

%%领取封神争霸物品奖励
handle_cast({'GOODS_AWARD',[Status]},State)->
	spawn(fun()->lib_war2:get_goods_award(Status)end),
	{noreply,State};

%%领取药品
handle_cast({'get_vip_drug',[Status]},State)->
	spawn(fun()->get_vip_drug(Status,State)end),
	{noreply,State};

%%同步积分
handle_cast({'syn_war_point',[NickName,Point,Content]},State)->
	spawn(fun()->lib_war:syn_war_award(NickName,Point,Content)end),
	{noreply,State};

%%查询积分
handle_cast({'get_war_awrd_point',[Status]},State)->
	spawn(fun()->get_war_awrd_point(Status)end),
	{noreply,State};

%%积分兑换物品
handle_cast({'change_goods',[Status,GoodsId,Num]},State)->
	spawn(fun()->change_goods(Status,GoodsId,Num)end),
	{noreply,State};

%%通知进入战场
handle_cast({'notice_enter_war',[Status]},State)->
	spawn(fun()->lib_war:notice_enter_war(Status)end),
	{noreply,State};

%%添加封神大会记录到本地
handle_cast({'add_war_record',[Data]},State)->
	{Times,MaxLv,MaxRound,TeamRecord,VsRecord} = Data,
	lib_war:del_war_record(Times),
	lib_war:add_war_record(Times,TeamRecord),
	VsInfo = lib_war:add_war_record_vs(MaxLv,MaxRound,VsRecord),
%% 	MaxLv = lib_war:get_lv_max(Times),
	{noreply,State#state{times=Times,max_lv=MaxLv,max_round=MaxRound,vs_info = VsInfo}}; 

%%获取封神大会记录到远程
handle_cast({'get_record_to_remote'},State)->
	spawn(fun()->
				  Data = lib_war:get_record_to_remote(State#state.times,State#state.max_lv,State#state.max_round),
				  mod_leap_server:war_record(Data)
		  end),
	{noreply,State};

%%had_syn_data
handle_cast({'had_syn_data',[Platform,Sn]},State)->
	spawn(fun()->
				  Platform1 = tool:to_binary(Platform),
				  case lib_war:select_war_team_by_sn(Platform1,Sn,State#state.times) of
					  []->skip;
					  [Team]->
						  NewTeam = Team#ets_war_team{syn=1},
						  lib_war:update_war_team(NewTeam),
						  db_agent:update_war_team([{syn,1}],[{id,Team#ets_war_team.id}])
				  end
		  end),
	{noreply,State};

%%check
handle_cast({'check_state',[Type]},State)->
	Res  = case Type of
			   times ->State#state.times;
			   max_lv -> State#state.max_lv;
			   round -> State#state.round;
			   status -> State#state.status;
			   timestamp -> State#state.timestamp;
			   max_round -> State#state.max_round;
			   start_time -> State#state.start_time;
			   end_time -> State#state.end_time;
			   team_info -> State#state.team_info;
			   vs_info -> State#state.vs_info;
			   group -> State#state.group;
			   wait_info-> State#state.wait_info;
			   scene_pid -> State#state.scene_pid;
			   state -> State#state.state;
			   _->null
		   end,
	io:format("The ~p status is ~p~n",[Type,Res]),
	{noreply,State};

%%退出封神大会
handle_cast({'exit_war',[Status]},State)->
	spawn(fun()->exit_war(Status)end),
	{noreply,State};

%%change state
handle_cast({'change_state',[Key,Value]},State)->
	NewState = case Key of
		times ->State#state{times=Value};
		max_lv -> State#state{max_lv=Value};
		round -> State#state{round=Value};
		status -> State#state{status=Value};
		timestamp -> State#state{timestamp=Value};
		max_round -> State#state{max_round=Value};
		start_time -> State#state{start_time=Value};
		end_time -> State#state{end_time=Value};
		team_info -> State#state{team_info=Value};
		vs_info -> State#state{vs_info=Value};
		group -> State#state{group=Value};
		wait_info-> State#state{wait_info=Value};
		scene_pid -> State#state{scene_pid=Value};
		state -> State#state{state=Value};
		_->
			io:format("key [~p] is not exits~n",[Key]),
			State
	end,
	{noreply,NewState};

%%init team
handle_cast({'init_team'},State)->
	%%清理内存数据
	lib_war:delete_war_player(),
	%%加载玩家数据到内存
	lib_war:init_war_player(),
	%%初始化队伍信息{最大分组数，{队伍id,队伍所在分组} 
	{MaxLv,TeamInfo,{MaxRound,VsInfo}} = lib_war:init_match_team_info(State#state.times),
	NewState = State#state{
						   max_lv=MaxLv,
						   team_info=TeamInfo,
						   max_round = MaxRound,
						   vs_info = VsInfo },
	{noreply,NewState};

%% {'init_vs'}
handle_cast({'init_vs'},State)->
	{_Type,Times,_State,Lv,_Round,MaxRound} =  lib_war:select_war_state(),
	{TeamInfo,VsInfo} = lib_war:continue_match_team_info(Times,Lv,MaxRound),
%% 	io:format("TeamInfo,VsInfo>>~p/~p~n",[TeamInfo,VsInfo]),
	NewState = State#state{
						   max_lv=Lv,
						   team_info=TeamInfo,
						   vs_info = VsInfo },
	{noreply,NewState};

%%更新玩家分组数据
handle_cast({'update_to_team',[Id,PlayerId,NickName,Career,Realm,Lv,Sex,Vip,Att,Platform,Sn]},State)->
	spawn(fun()->lib_war:update_to_team(Id,PlayerId,NickName,Career,Realm,Lv,Sex,Vip,Att,Platform,Sn,State#state.times)end),
	{noreply,State};

%%测试用
handle_cast({'add_new_test',[PlayerStatus]},State)->
	Res  = lib_war:init_war_data_test(PlayerStatus),
	io:format("add new test >>>>>>>~p~n",[Res]),
	{noreply,State};

%%设置封神声望
handle_cast({'set_war_award',[PlayerId,Type,Value]},State)->
	spawn(fun()->lib_war:set_war_award(PlayerId,Type,Value)end),
	{noreply,State};

%%数据重置
handle_cast({'reset'},State)->
	Self = self(),
	case lib_war:is_war_server() of
		false->
			misc:cancel_timer(init_match_player),
			TimerHandle3 = erlang:send_after(get_timer_time(?WAR_SIGN_UP_OPEN),Self,{'init_match_player'}),
			put(init_match_player,TimerHandle3),
			ok;
		true->
			misc:cancel_timer(init_team_info),
			TimerHandle2=erlang:send_after(get_timer_time(?INIT_WAR_TEAM_TIME), Self, {'init_team_info'}),
			put(init_team_info,TimerHandle2),
			misc:cancel_timer(init_server_info),
			ServerHandle = erlang:send_after(get_timer_time(?WAR_SIGN_UP_OPEN),self(),{'init_server_info'}),
			put(init_server_info,ServerHandle),
			ok
	end,
	{noreply,State};

handle_cast(_MSg,State)->
	 {noreply, State}.


%%获取参赛人员
%%周日14:00清除上一届数据，并开启报名
handle_info({'init_match_player'},State)->
	misc:cancel_timer(init_match_player),
	case config:get_war_server_info() of
		[]->skip;
		[_,_,1,_,_]->
			lib_war:get_war_player(),
			lib_war:notice_war_state_all(0),
			erlang:send_after(?GET_TOP_TEN,self(),{'match_player'}),
			EndHandle = erlang:send_after(3*3600*1000,self(),{'sign_up_end'}),
			put(sign_up_end,EndHandle),
			TimerHandle = erlang:send_after(next_timer(?WAR_SIGN_UP_OPEN),self(),{'init_match_player'}),
			put(init_match_player,TimerHandle);
		_->
			skip
	end,
	{noreply,State#state{status=0}};

%%确定参赛资格玩家
handle_info({'match_player'},State)->
	lib_war:select_top_ten(),
	erlang:send_after(?NOTICE_WAR_STATE,self(),{'notice_war_start'}),
	erlang:send_after(?NOTICE_WAR_STATE_SEC,self(),{'notice_war_start'}),
	{noreply,State#state{status=3}};

%%通知进入战场
handle_info({'notice_war_start'},State)->
	spawn(fun()->lib_war:notice_enter_war_all()end),
	{noreply,State};

%%初始化历史记录
handle_info({'init_war_record'},State)->
	Times = lib_war:check_times()-1, 
	lib_war:init_war_vs(),
	MaxLv = lib_war:get_lv_max(Times),
	VsBag = lib_war:select_war_vs_all(),
	MaxRound = case length(VsBag)> 0 of
				  false-> 0;
				  true->
					  lists:max([Vs#ets_war_vs.round||Vs<-VsBag])
			  end,
	VsInfo = [lib_war:continue_vs(Lv,MaxRound)||Lv<-lists:seq(1,MaxLv)],
	{noreply,State#state{times=Times,max_lv=MaxLv,max_round=MaxRound,vs_info = VsInfo}}; 

%%初始化参赛服务器
%%周日14:00初始化参赛服务器
handle_info({'init_server_info'},State)->
%% 	io:format("init_server_info>>>>>>>>>>>>time_~p~n",[State#state.times]),
	misc:cancel_timer(init_server_info),
%% 	{TypeTick,_Times,WarState,_Lv,_Round,_MaxRound} =  lib_war:select_war_state(),
%% 	if WarState =:=3 orelse TypeTick=:= 0->
			Self = self(),
			%%初始化服务器分组
			{ok,Times} = lib_war:init_server_team(),
			%%启动下次初始化定时器
			TimerHandle = erlang:send_after(next_timer(?WAR_SIGN_UP_OPEN),Self,{'init_server_info'}),
			put(init_server_info,TimerHandle),
			NewState = State#state{times=Times,state = 0},
%%  			mod_leap_server:clear_database(),%%打开测试，需要屏蔽
			%%启动初始化参赛队伍定时器(测试用)
%%		 	erlang:send_after(?INIT_TEAM_TIMER,self(),{'init_team_info'}),
			lib_war:update_war_state([{times,Times},{state,0},{type,1},{round,0}],[]),
			RecordHandle = erlang:send_after(10*1000,Self,{'syn_record_to_remote'}),
			put(syn_record_to_remote,RecordHandle),
			erlang:send_after(10*1000,Self,{'notice_sign_up'}),
			ok,
%% 	   true->
%% 		   NewState = State
%% 	end,
	{noreply,NewState};

handle_info({'notice_sign_up'},State)->
	spawn(fun()->
				  Msg = io_lib:format("亲爱的玩家，第<font color='#FEDB4F;'>~p</font>届封神大会开始接受报名，请到九霄封神大会负责人处确认参赛资格！",[State#state.times]),
				  mod_leap_server:remote_server_msg(Msg)
		  end),
	lib_war:notice_war_state_all(0),
	{noreply,State};

handle_info({'sign_up_end'},State)->
	misc:cancel_timer(sign_up_end),
	lib_war:notice_war_state_all(4),
	{noreply,State#state{status=5}};

%%同步初始化参赛队伍记录到各参赛服
handle_info({'syn_record_to_remote'},State)->
	misc:cancel_timer(syn_record_to_remote),
	Data = lib_war:get_record_to_remote(State#state.times,State#state.max_lv,State#state.max_round),
	mod_leap_server:war_record(Data),
	{noreply,State};

%%开启分组等待区服务
handle_info({'init_rest_server'},State)->
	misc:cancel_timer(init_rest_server),
	LvList = lists:seq(1,State#state.max_lv),
	Bag = start_wait_server(LvList,[]),
	NewState = State#state{wait_info=Bag},
%% 	io:format("init wait server ~p~p~n",[LvList,Bag]),
	{noreply,NewState};


%%关闭分组等待区服务
handle_info({'close_rest_server'},State)->
	misc:cancel_timer(close_rest_server),
	[gen_server:cast(Pid,{'CLOSE'})||{_,Pid}<-State#state.wait_info,Pid=/=undefined],
	%%循环测试
%% 	erlang:send_after(?INIT_SERVER_TIMER,self(),{'init_server_info'}),
	{noreply,State#state{wait_info=[]}};

%%获取远程各参赛服玩家信息
%%周日下午15：20分获取数据
%% handle_info({'get_player_from_remote',Type},State)-> 
%% 	misc:cancel_timer(get_player_from_remote),
%% 	Self  = self(),
%% 	case lib_war:is_war_server() of
%% 		false->skip;
%% 		true->
%% 			case Type of
%% 				first->
%% %% 					erlang:send_after(5*60*1000,self(),{'get_player_from_remote',second}),
%% 					TimerHandle = erlang:send_after(next_timer(?SYN_PLAYER_TIME),Self,{'get_player_from_remote',first}),
%% 					put(get_player_from_remote,TimerHandle),
%% 					lib_war:clear_war_player(),
%% 					mod_leap_server:notice_syn_data_fir(); 
%% 				_->
%% 					Team = lib_war:select_war_team_by_times(State#state.times),
%% 					[mod_leap_server:notice_syn_data_sec(T#ets_war_team.platform,T#ets_war_team.sn)||T<-Team,T#ets_war_team.syn=:=0]
%% 			end
%% 	end,
%% 	{noreply,State};


%%初始化分组队伍
%%周日下午15:05初始化队伍信息
handle_info({'init_team_info'},State)->
	misc:cancel_timer(init_team_info),
	Self = self(),
%% 	{Type,_Times,WarState,_Lv,_Round,_MaxRound} =  lib_war:select_war_state(),
%% 	if Type =:= 0 orelse WarState =:= 3 ->
%% 		   TimerHandle = case  get_timer_time(?INIT_WAR_TEAM_TIME) of
%% 			   0->
%% 				   erlang:send_after(get_timer_time(?INIT_WAR_TEAM_TIME),Self, {'init_team_info'});
%% 			   Timestamp ->
%% 				   erlang:send_after(Timestamp,Self, {'init_team_info'})
%% 		   end,
%% 		   put(init_team_info,TimerHandle),
%% 		   NewState = State;
%% 	   true->
		   %%清理内存数据
			lib_war:delete_war_player(), 
			%%加载玩家数据到内存
			lib_war:init_war_player(),
			%%初始化队伍信息{最大分组数，{队伍id,队伍所在分组} 
			{MaxLv,TeamInfo,{MaxRound,VsInfo}} = lib_war:init_match_team_info(State#state.times),
			TimerHandle = erlang:send_after(next_timer(?INIT_WAR_TEAM_TIME),self(),{'init_team_info'}),		
			 put(init_team_info,TimerHandle),
			%%55分钟后开启第一场战斗
			TimerHamdleFigit = erlang:send_after(?INIT_CAEATE_WAR,Self,{'CREATE_WAR'}),
			put(create_war,TimerHamdleFigit),
			%%开启休息区服务
			RestHandle = erlang:send_after(?INIT_REST_TIMER,Self,{'init_rest_server'}),
			put(init_rest_server,RestHandle),
			%%封神专服开放通知
%% 			spawn(fun()->war_server_open_msg(State#state.times)end),
			erlang:send_after(25*60*1000,Self,{'notice_enter_war',1}),
			lib_war:update_war_state([{state,1},{max_round,MaxRound},{lv,MaxLv}],[]),
			RecordHandle = erlang:send_after(10*1000,Self,{'syn_record_to_remote'}),
			put(syn_record_to_remote,RecordHandle),
			NewState = State#state{max_lv=MaxLv,
								   team_info=TeamInfo,
								   status=2,
								   state = 1,
								   timestamp = util:unixtime()+round(?INIT_CAEATE_WAR div 1000),
								   vs_info = VsInfo,
								   max_round=MaxRound},
%% 	end,
	{noreply,NewState};

handle_info({'notice_enter_war',Type},State)->
	spawn(fun()->war_server_enter_msg(State#state.times)end),  
	if Type =:= 1->
		   erlang:send_after(15*60*1000,self(),{'notice_enter_war',0});
	   true->skip
	end,
	{noreply,State};

handle_info({'init_times_info',Times,Lv},State)->
	NewState = State#state{times=Times,max_lv=Lv},
	{noreply,NewState};


handle_info({'init_vs'},State)->
	{TeamInfo,VsInfo} = lib_war:continue_match_team_info(2,4,7),
	io:format("TeamInfo,VsInfo>>~p/~p~n",[TeamInfo,VsInfo]),
	NewState = State#state{
						   max_lv=4,
						   team_info=TeamInfo,
						   vs_info = VsInfo },
	{noreply,NewState};

handle_info({'continue_team_info',Times,MaxLv,Round,MaxRound},State)->
	misc:cancel_timer(continue_team_info),
	Self = self(),
	%%清理内存数据
	lib_war:delete_war_player(),
	%%加载玩家数据到内存
	lib_war:init_war_player(),
	%%初始化队伍信
	{TeamInfo,VsInfo} = lib_war:continue_match_team_info(Times,MaxLv,MaxRound),
	TimerHandle = erlang:send_after(next_timer(?INIT_WAR_TEAM_TIME),self(),{'init_team_info'}),
	 put(init_team_info,TimerHandle),
	%%开启战斗
	NextTime = round_time(Round+1),
	TimerHamdleFigit = 
		case get_timer_time(NextTime) of
			0-> erlang:send_after(get_timer_time(NextTime),Self,{'CREATE_WAR'});
			WarTime->
				erlang:send_after(WarTime,Self,{'CREATE_WAR'})
		end,
	put(create_war,TimerHamdleFigit),
	%%开启休息区服务
	RestHandle = erlang:send_after(?INIT_REST_TIMER,Self,{'init_rest_server'}),
	put(init_rest_server,RestHandle),
	
	NewState = State#state{times=Times,
						   max_lv=MaxLv,
						   team_info=TeamInfo,
						   vs_info = VsInfo,
						   round=Round,
						   state = 1,
						   max_round=MaxRound,
						   status=1,
						   timestamp = round(util:unixtime()+NextTime-util:get_today_current_second()) },
	{noreply,NewState};


%%
%%创建分组竞技
%%周日16:00第一场战斗开始
handle_info({'CREATE_WAR'}, State) ->
	misc:cancel_timer(create_war),
	if State#state.max_round =< State#state.round ->
		   NewState = State#state{round=0,status=5},
		   %%发放总积分
		   lib_war:syn_war_award_remote(State#state.times,State#state.max_lv),
		   %%升降级 
		   lib_war:change_lv(State#state.times,State#state.max_lv),
		   lib_war:update_war_state([{state,3}],[]),
		   finish_msg(State#state.times),
		   %%5分钟后结束封神大会
		   FinishHandle = erlang:send_after(5*60*1000,self(),{'WAR_FINISH'}),
		   put(war_finish,FinishHandle);
	   true->
		   if State#state.round =:= 0->
				  %%第XX届封神大会正式打响，各服精英尽出，到底哪支队伍可以最终登顶封神？
				  Content = io_lib:format("第<font color='#FEDB4F;'>~p</font>届封神大会正式打响，各服精英尽出，到底哪支队伍可以最终登顶封神？",[State#state.times]),
				  lib_chat:broadcast_sys_msg(2,Content),
				  mod_leap_server:remote_server_msg(Content);
			  true->
				  RecordHandle = erlang:send_after(5*1000,self(),{'syn_record_to_remote'}),
				  put(syn_record_to_remote,RecordHandle)
		   end,
		   LvList = lists:seq(1,State#state.max_lv),
		   Round = State#state.round+1,
		   {NewGroupList,ScenePid} = create_war_battle(LvList,State#state.max_lv,State#state.times,Round,State#state.vs_info,State#state.wait_info,[],1,[]),
		   NewState = State#state{
				round = Round,
				group = NewGroupList,
				status = 3,
				timestamp = util:unixtime()+ 10*60,
				scene_pid = [{Round,ScenePid}]					   
			},
		   lib_war:update_war_state([{state,2},{round,Round}],[]),
			%%10分钟后进入休息
			TimerHandleRest = erlang:send_after(?REST,self(),{'REST',3*60}),
		   put(rest,TimerHandleRest),
		   %%20秒后开战
%% 		   StateHandle = erlang:send_after(10*1000,self(),{'FIGHT_STATE'}),
%% 		   put(fight_state,StateHandle),
			%%13分钟后开启下一轮
			TimerFight = erlang:send_after(?NEXT_CAEATE_WAR,self(),{'CREATE_WAR'}),
		   put(create_war,TimerFight)
	end,
	{noreply, NewState};

%%战斗状态
handle_info({'FIGHT_STATE'},State)->
	misc:cancel_timer(fight_state),
	NewState = State#state{status = 3,timestamp = util:unixtime()+ 9*60+50},
	{noreply,NewState};

%%休息
handle_info({'REST',Timetamp},State)->
	misc:cancel_timer(rest),
	case lists:keyfind(State#state.round,1,State#state.scene_pid) of
		false->skip;
		{_,ScenePid}->
			close_war_battle(ScenePid)
	end,
	NewState = State#state{status=1,timestamp = util:unixtime()+Timetamp,scene_pid=[]},
	spawn(fun()->lib_war:reset_vip_drug_loop()end),
	{noreply,NewState};

%%
%%结束战场
handle_info({'WAR_FINISH'},State)->
	misc:cancel_timer(war_finish),
	%%同步数据到各参赛服
%% 	RecordHandle = erlang:send_after(5*1000,self(),{'syn_record_to_remote'}),
%% 	put(syn_record_to_remote,RecordHandle),
	%%关闭休息区
	CloseHandle = erlang:send_after(10000,self(),{'close_rest_server'}),
	put(close_rest_server,CloseHandle),
	{noreply,State#state{state = 2}};

					 
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()).

code_change(_OldVsn, State, _Extra)->
    {ok, State}.

%%创建分组等待区服务
start_wait_server([],ServerInfo)->
	ServerInfo;
start_wait_server([Lv|Lvlist],ServerInfo)->
	SceneId = mod_dungeon:get_unique_dungeon_id(760),
	case mod_war_rest:start([Lv,SceneId]) of
		{ok,Pid}->
			start_wait_server(Lvlist,[{Lv,Pid,SceneId}|ServerInfo]);
		_->
			start_wait_server(Lvlist,[{Lv,undefined,undefined}|ServerInfo])
	end.

%%创建封神分组战斗进程
create_war_battle([],_MaxLv,_Times,_Round,_VsList,_WaitInfo,BattleInfo,_mark,SceneServer)->
	{BattleInfo,SceneServer};
create_war_battle([Lv|LvList],MaxLv,Times,Round,VsList,WaitInfo,BattleInfo,Mark,SceneServer)->
	VsInfo = lists:keyfind(Lv, 1, VsList),
	{_Lv,Vs} = VsInfo,
	{NewLv,NewPid,NewMark,NewSceneServer} = case length(Vs)>= Round of
		true->
			IdList = lists:nth(Round,Vs),
			{PidWait,SceneWait}= case lists:keyfind((Lv+1) div 2,1,WaitInfo) of
						 false->{undefined,0};
						 {_,Pid,Sid}->{Pid,Sid}
					 end,
			start_war_battle(Times,IdList,Lv,MaxLv,Round,PidWait,SceneWait,[],Mark+1,[]);
		false->{Lv,[],0,[]}
	end,
	create_war_battle(LvList,MaxLv,Times,Round,VsList,WaitInfo,[{NewLv,NewPid}|BattleInfo],NewMark,NewSceneServer++SceneServer).

start_war_battle(_Times,[],Lv,_MaxLv,_Round,_WaitInfo,_SceneWait,PidInfo,Mark,SceneServer)->
	{Lv,PidInfo,Mark,SceneServer};
start_war_battle(Times,[Id|IdList],Lv,MaxLv,Round,WaitInfo,SceneWait,PidInfo,Mark,SceneServer)->
	[Vs] = lib_war:select_war_vs(Id),
	if Vs#ets_war_vs.sn_a =:=0 orelse Vs#ets_war_vs.sn_b =:= 0->
		   spawn(fun()->notice_no_battle(Times,MaxLv,Lv,Round,Vs#ets_war_vs.sn_a,Vs#ets_war_vs.sn_b,Vs)end),
		   start_war_battle(Times,IdList,Lv,MaxLv,Round,WaitInfo,SceneWait,[{Id,undefined}|PidInfo],Mark+1,SceneServer);
	   true->
		    SceneId = mod_dungeon:get_unique_dungeon_id(750),
			case mod_war_fight:start([Id,Vs,Times,Lv,MaxLv,Round,WaitInfo,SceneWait,Mark,SceneId]) of
				{ok,Pid}->
					ScenePid = {SceneId,Pid}, 
					start_war_battle(Times,IdList,Lv,MaxLv,Round,WaitInfo,SceneWait,[{Id,Pid}|PidInfo],Mark+1,[ScenePid|SceneServer]);
				_->
					start_war_battle(Times,IdList,Lv,MaxLv,Round,WaitInfo,SceneWait,[{Id,undefined}|PidInfo],Mark+1,SceneServer)
			end
	end.

%%结束分组战斗进程
close_war_battle([])->ok;
close_war_battle([Scene|ScenePid])->
	{_,Pid} = Scene,
	case misc:is_process_alive(Pid) of
		true->
			Pid!{'FINISH_WAR'};
		false->skip
	end,
	close_war_battle(ScenePid).



%%通知玩家该轮比赛轮空
notice_no_battle(Times,MaxLv,Lv,Round,SnA,SnB,Vs)->
	{Sn,Platform} = if SnA=:= 0->{SnB,Vs#ets_war_vs.platform_b};
			true->{SnA,Vs#ets_war_vs.platform_a}
		 end,
	Team = case lib_war:select_war_team_by_sn(Platform,Sn,Times) of
				 []->[];
				 [B]->B
			 end,
	Msg = io_lib:format("勇士们，第~p届封神大会~s第~p轮战斗开始，由于您所在的队伍轮空，这一轮没有安排比赛,好好养精促锐吧！", [Times,lib_war:id_to_name(Lv,MaxLv),Round]),
	{ok, MsgBinData} = pt_11:write(11080, 2, Msg),
	[lib_send:send_to_uid(PlayerId, MsgBinData)||{PlayerId,_,_,_,_,_,_,_}<-Team#ets_war_team.team],
	ok.

timer_fix(InitTime)->
	InitTime - util:get_today_current_second()+1.

next_timer(InitTime)->
%% 	Days = case util:get_date() of
%% 			  3->4;
%% 			  7->3;
%% 			  _->7
%% 		  end,
%% 	Days = 1,
	round(timer_fix(InitTime)+24*3600*7)*1000.

get_timer_time(InitTime)->
	Week = util:get_date(),
	case lib_war:is_war_week() of 
		true->
			TodaySec = util:get_today_current_second()+1,
			case TodaySec < InitTime of
				true->
					round(InitTime-TodaySec)*1000;
				false->
					TodaySecLeft = 24*3600-TodaySec,
					Day = check_day_match(Week),
					round(Day*24*3600+TodaySecLeft+InitTime)*1000
			end;
		false->
			TodaySecLeft = 24*3600-util:get_today_current_second(),
			Day = check_day_match(Week),
			Timestamp = round(Day*24*3600+TodaySecLeft+InitTime)*1000,
%% 			io:format("Timestamp>>~p~n",[Timestamp]),
			Timestamp
	end.

check_day_match(Week)->
%% 	0.
case Week of
		1->5;
		2->4;
		3->3;
		4->2;
		5->1;
		6->0;
		7->6
	end.
%% 	case Week of
%% 		1->1;
%% 		2->0;
%% 		3->3;
%% 		4->2;
%% 		5->1;
%% 		6->0;
%% 		7->2
%% 	end.


round_time(Round)->
	16*3600+(Round-1)*15*60.

%%封神服开放通知
%% war_server_open_msg(Times)->
%% 	Msg = io_lib:format("亲爱的玩家，第<font color='#FEDB4F;'>~p</font>届封神大会专服已经开放，请到九霄封神大会负责人处进入到封神大会专服！",[Times]),
%% 	mod_leap_server:remote_server_msg(Msg).

%%通知进入封神大会
war_server_enter_msg(Times)->
	Msg = io_lib:format("亲爱的玩家，第<font color='#FEDB4F;'>~p</font>届封神大会封神大会专线已经开放，请到九霄封神大会负责人处进入到封神大会专服！",[Times]),
	mod_leap_server:remote_server_msg(Msg).
%%封神大会结束
finish_msg(Times)->
	Msg = io_lib:format("各服的勇士们，第<font color='#FEDB4F;'>~p</font>届封神大会圆满落下帷幕，感谢大家的参与，我们下届再会！！！",[Times]),
	lib_chat:broadcast_sys_msg(2,Msg),
	mod_leap_server:remote_server_msg(Msg),
	ok.

%%%%%%%%%%%%%%%%%%%%%%%%%%from pp_war msg
chat_sn(PlayerId,BinData)->
	case lib_war:select_war_player(PlayerId) of
		[]->skip;
		[P]->
			PlayerBag = lib_war:select_war_player_by_sn(P#ets_war_player.platform,P#ets_war_player.sn),
			[lib_send:send_to_uid(Player#ets_war_player.pid, BinData)||Player<-PlayerBag]
	end.

%%获取历史记录
get_war_record(Status,Times,NowTimes)->
	Data = lib_war:get_war_record(Times,NowTimes),
	{ok,BinData} = pt_45:write(45001,Data),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).

%%报名
war_sign_up(Status)->
 	Res = case lib_war:war_sign_up_new(Status) of
		{ok,1}->
			mod_leap_client:send_player_data(Status#player.id,Status#player.nickname),
			1;
		{_,Res1}->Res1
	end,
	Total = length(lib_war:select_war_player_sign_up()),
	{ok,BinData} = pt_45:write(45002,[Res,Total]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).

%%取消报名
war_cancel_sign_up(Status)->
	{_,Res} = lib_war:cancel_war_sign_up(Status),
	{ok,BinData} = pt_45:write(45023,[Res]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).

%%查询报名信息
sign_up_info(Status)->
	Data = lib_war:check_invite_info(Status),
	{ok,BinData} = pt_45:write(45003,Data),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).

%%邀请
war_invite(Status,NickName)->
	{_,Res} = lib_war:war_invite(Status,NickName),
	{ok,BinData} = pt_45:write(45004,[Res]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).

%%请求资格转让
war_request_transfer(Status,NickName)->
	case lib_war:war_request_transfer(Status,NickName) of
		{error,Error}->
			{ok,BinData} = pt_45:write(45005,[Error,1]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
		{_,Invitee,SignUp}->
			{ok,BinData} = pt_45:write(45006,[Status#player.nickname,SignUp]),
			lib_send:send_to_sid(Invitee#player.other#player_other.pid_send, BinData)
	end.

%%回应资格转让
war_answer_transfer(Status,NickName,Res)->
	case lib_war:war_answer_transfer(Status,NickName,Res) of
		{error,Error}->
			{ok,BinData} = pt_45:write(45005,[Error,2]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
		{ok,Player,Res1}->
			{ok,BinData} = pt_45:write(45005,[Res1,1]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
			if Res1 =:=0->skip;
			   true->
				   {ok,BinData1} = pt_45:write(45005,[Res1,2]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData1)
			end
	end.

%%查询参赛玩家
check_war_player(Status)->
	PlayerBag = lib_war:check_war_player(Status#player.id),
	{ok,BinData} = pt_45:write(45007,PlayerBag),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).

%%进入封神大会
enter_match(Status)->
	Data = case lib_war:enter_match(Status) of
		{ok,1}->
			case config:get_war_server_info() of
				[]-> [2,<<>>,0];
				[Ip,_,_,Port,_]->
					spawn(fun()->db_agent:update_war_player([{enter,1}],[{pid,Status#player.id}])end),
					mod_leap_client:update_player_data(Status#player.id,Status#player.nickname),
					timer:sleep(5000),
					[1,Ip,Port];
				_->[2,<<>>,0]
			end;
		{_error,Res2}->[Res2,<<>>,0]
	end,
	{ok,BinData} = pt_45:write(45008,Data),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).

%%查询参赛队伍
war_team(Status,State)->
	Data = lib_war:war_team(State#state.times,State#state.max_lv),
	{ok,BinData} = pt_45:write(45010,Data),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).

%%查询对战表
war_vs(Status,State)->
	Data = lib_war:war_vs(State#state.vs_info),
	{ok,BinData} = pt_45:write(45011,Data),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).

%%查询积分
war_point(Status,State)->
	Data = lib_war:war_point(State#state.times,State#state.max_lv),
	{ok,BinData} = pt_45:write(45012,Data),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).

%%获取当前状态
war_state(Status,State)->
	{ok,BinData} = pt_45:write(45013,[State#state.state,State#state.round]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).

%%获取时间
war_time(Status,State)->
	Timestamp = State#state.timestamp-util:unixtime(),
	{ok,BinData} = pt_45:write(45014,[State#state.status,State#state.round,Timestamp]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).

%%VIP领取药品
get_vip_drug(Status,State)->
	Res = lib_war:get_vip_drug(Status,State#state.round,State#state.max_round),
	{ok,BinData} = pt_45:write(45017,[Res]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).

exit_war(Status)->
	case lib_war:exit_war(Status#player.id) of
		{ok,IP,Port}->
			{ok,BinData} = pt_45:write(45022,[IP,Port]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
		_->skip
	end.

get_war_awrd_point(Status)->
	P = lib_war:get_war_award_point(Status#player.id),
	{ok,BinData} = pt_45:write(45025,[P]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).

change_goods(Status,GoodsId,Num)->
	{Res,P} = lib_war:change_goods(Status,GoodsId,Num),
	{ok,BinData} = pt_45:write(45026,[Res,P]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).