%% Author: Administrator
%% Created: 2012-2-22
%% Description: TODO: 跨服选拔赛分区服务
-module(mod_war2_subarea).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").

%%
%% Exported Functions
%%
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-export([start/1,start_link/1,stop/0,
		 init_elimination_by_grade_32/2,	%%32强
		 init_elimination_by_grade_16/2,	%%16强
		 init_elimination_by_grade_8/2,		%%8强
		 init_elimination_by_grade_4/2,		%%4强
		 init_elimination_by_grade_third/2,	%%季军争夺
		 init_elimination_by_grade_final/2	%%冠军争夺
		]).
 
-record(state, {
				times = 0 ,		%%届次
				grade = 0,		%%级别%%1天罡，2地煞
				subarea = 0,	%%	分区id
				scene_id =  0,	%%场景id
				status=0,		%%进度
				work_id = 0,	%%工作进程id
				match=[],		%%战斗配对
				match_start=0,	%%配对开始
				member = [],	%%玩家信息
				tryout = [],		%%出线玩家列表
				elimination = [],%%淘汰赛对战表(包括季军争夺))
				champion = [],	%%决赛
				round = 0,		%%淘汰赛轮次
				final = 0,		%5是否决赛
				is_end = 0,		%%选拔赛是否结束
				end_time = 0,	%%结束时间
				next_gametime_view=0,%%观战时间
				member_view=[]	%%观战玩家列表
			   }).

-define(SUBAREA_OPEN_TIME,90*60*1000).	%%分区开放时间
-define(ELIMINATION_OPENTIME,60*60*1000).%%淘汰赛开放时间
-define(FINAL_OPENTIME,90*60*1000).%%决赛开放时间

%%
%% Local Functions
%%

start([Times,Grade,Subarea,SceneId,Status]) -> 
    gen_server:start(?MODULE, [Times,Grade,Subarea,SceneId,Status,0], []).

start_link([Times,Grade,Subarea,SceneId,Status,WorkId]) ->
	gen_server:start_link(?MODULE, [Times,Grade,Subarea,SceneId,Status,WorkId], []).

%%停止服务
stop() ->
    gen_server:call(?MODULE, stop).

init([Times,Grade,Subarea,SceneId,Status,WorkId]) ->
	 process_flag(trap_exit, true),
	Self = self(),
	%% 初始战场
	SceneProcessName = misc:create_process_name(scene_p, [SceneId, WorkId]),
	misc:register(global, SceneProcessName, Self),
	if WorkId == 0->		   
		   %% 复制场景
		   lib_scene:copy_scene(SceneId, 730),
		   misc:write_monitor_pid(Self, ?MODULE, {730}),
		   %% 启动跨服分区服务工作进程
		   lists:foreach(
			 fun(WorkId1) ->
					 mod_war2_subarea:start_link([Times,Grade,Subarea,SceneId,Status,WorkId1])
			 end,
			 lists:seq(1, ?SCENE_WORKER_NUMBER)),
		   if  Status == 0 ->
%% 				    erlang:send_after(3*60*1000, Self, {'NEXT_GAME_TIME',[2*60]});
					erlang:send_after(60*60*1000, self(), {'CLOSE'}),
				   erlang:send_after(15*60*1000, Self, {'NEXT_GAME_TIME',[5*60]});
			   Status == 2->
				   %% 				   erlang:send_after(3*60*1000, Self, {'MSG_TRYOUT'}),
				   erlang:send_after(15*60*1000, Self, {'MSG_TRYOUT'}),
				   erlang:send_after(45*60*1000, Self, {'OFFTRACK'}),
				   ok;
			   true->
				   erlang:send_after(10*1000, Self, {'SERVER_OPEN_MSG'}),
%% 				    Handle2 = erlang:send_after(15*1000, Self, {'ELIMINATION'}), 
				   Handle2 = erlang:send_after(15*60*1000, Self, {'ELIMINATION'}), 
				   put(elimination,Handle2)
		   end,
		   Tryout = init_offtrack(Grade,Subarea),
		   {Champion,Elimination} = init_elimination(Status),
		   State = #state{
						  times = Times,
						  grade=Grade,
						  subarea = Subarea,
						  scene_id = SceneId,
						  status=Status,
						  champion = Champion,
						  elimination = Elimination,
						  work_id=WorkId,
						  end_time = get_end_time1(Status),
						  next_gametime_view = get_end_time1(Status),
						  tryout = Tryout
						 };
	true->
		State = #state{work_id=WorkId}
	end,
    {ok,State}.

init_elimination(Week)->
	case Week of
		0->{[],[]};
		1->{[],[]};
		2->{[],[]};
		3->{[],init_elimination_by_grade_32([1,2],[])};
		4->{[],init_elimination_by_grade_16([1,2],[])};
		5->{[],init_elimination_by_grade_8([1,2],[])};
		6->{[],init_elimination_by_grade_4([1,2],[])};
		_->{init_elimination_by_grade_final([1,2],[]),init_elimination_by_grade_third([1,2],[])}
	end.
	
init_offtrack(Grade,Subarea)->
	case lib_war2:ets_select_war2_elimination_by_subarea(Grade,Subarea) of
		[]->[];
		Member->
			[M#ets_war2_elimination.pid||M<-Member]
		end.


get_end_time1(State)->
	case State of
		0-> 15*60 + util:unixtime();
%% 		2-> 180 + util:unixtime();
		2-> 15*60 + util:unixtime();
		_-> 15*60 + util:unixtime()
	end.

get_end_time(State)->
	case State of
		0-> 5*60 + util:unixtime();
%% 		2-> 180 + util:unixtime();
		2-> 30*60 + util:unixtime();
		_-> 5*60 + util:unixtime()
	end.

%% 统一模块+过程调用(call)
handle_call({apply_call, Module, Method, Args}, _From, State) ->
%% 	?DEBUG("mod_scene_apply_call: [~p/~p/~p]", [Module, Method, Args]),	
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_war2_rest_apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
			 error;
		 DataRet -> DataRet
	end,
    {reply, Reply, State};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

%% 统一模块+过程调用(cast)
handle_cast({apply_cast, Module, Method, Args}, State) ->
%% 	?DEBUG("mod_scene_apply_cast: [~p/~p/~p]", [Module, Method, Args]),	
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_war2_rest_apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
			 error;
		 _ -> ok
	end,
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

%%战斗配对
handle_cast({'MATCH_FIGHT',[Player]},State)->
	case State#state.match_start ==0 of
		true->
			{ok,BinData} = pt_45:write(45103, [3]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
			NewState = State;
		false->
			{PlayerPid1,PlayerId1,NickName} = {Player#player.other#player_other.pid,Player#player.id,Player#player.nickname},
			if State#state.status == 2 andalso State#state.is_end /= 1->
				   case lists:keyfind(PlayerId1, 2, State#state.match) of
					   false->
						   Match = State#state.match++[{PlayerPid1,PlayerId1,NickName}],
						   case length(Match) >= 2 of
							   false->
								   NewState = State#state{match=Match};
							   true->
								   [PlayerInfo1,PlayerInfo2|NewMatch] = Match,
								   fight_tryout(State#state.times,State#state.grade,State#state.subarea,self(),State#state.scene_id,State#state.status,[PlayerInfo1,PlayerInfo2],State#state.member_view),
								   NewState = State#state{match=NewMatch}
						   end,
						   {ok,BinData} = pt_45:write(45103, [1]),
						   lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
					   _->
						   NewState = State
				   end;
			   true->
				   {ok,BinData} = pt_45:write(45103, [2]),
				   lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
				   NewState = State
			end
	end,
	{noreply,NewState};

%%出线玩家
handle_cast({'TRYOUT_WINER',[PlayerId]},State)->
	if State#state.is_end /= 1->
		   case lists:member(PlayerId, State#state.tryout) of
			   false->
				   case lib_war2:ets_select_war2_record(PlayerId) of
					   []->NewState = State;
					   [Record]->
						   if Record#ets_war2_record.offtrack /=1 andalso Record#ets_war2_record.seed /=1->
								  NewRecord = Record#ets_war2_record{offtrack=1},
								  lib_war2:ets_update_war2_record(NewRecord),
								  db_agent:update_war2_record([{offtrack,1}], [{pid,PlayerId}]),
								  lib_war2:tryout(Record, State#state.subarea, length(State#state.tryout)+1, State#state.grade, 3, 1),
%% 								  spawn(fun()->offtrack_msg(Record)end),
								  ok;
							  true->
								  skip
						   end,
						   NewTryout = [PlayerId|State#state.tryout],
						   Is_end = case length(NewTryout) >= 8 of
										false->0;
										true->1
									end,
						   NewState = State#state{tryout=NewTryout,is_end=Is_end},
						   spawn(fun()->update_finght_info(NewState)end)
				   end;
			   true->
				   NewState = State
		   end;
	   true->
		   	   NewState = State
	end,
	{noreply,NewState};

%%修改配对状态
handle_cast({'IS_END',[Value]},State)->
	NewState = State#state{is_end=Value},
	{noreply,NewState};

%%玩家信息
handle_cast({'UPDATE_PID',[Pid,PlayerId]},State)->
	Data = {Pid,PlayerId},
	case lists:keyfind(PlayerId, 2, State#state.member) of
		false->
			NewMember = [Data|State#state.member];
		_->
			NewMember = lists:keyreplace(PlayerId, 2, State#state.member, Data)
	end,
	{noreply,State#state{member = NewMember}};

handle_cast({'NOTICE_CHECK_OFFTRACK'},State)->
	case length(State#state.tryout) >= 8 of
		true->skip;
		false->
			get_offtrack_other(State)
	end,
	{noreply,State};

%%通知进入淘汰赛玩家更换场景
handle_cast({'NOTICE_CHANGE_SCENE_OFFTRACK',[SceneId,ScenePid]},State)->
	case lib_war2:ets_select_war2_elimination_by_subarea(State#state.grade,State#state.subarea) of
		[]->skip;
		Member->
			notice_change_scene(Member,SceneId,ScenePid)
	end,
	{noreply,State#state{is_end=1}};

%%通知淘汰赛场景更换
handle_cast({'NOTICE_CHANGE_SCENE_ELIMINATION',[SceneId,ScenePid]},State)->
	case lib_war2:ets_select_war2_elimination_by_win() of
		[]->skip;
		Member->
			notice_change_scene(Member,SceneId,ScenePid)
	end,
	{noreply,State#state{is_end=1}};

%%推送比赛个人信息
handle_cast({'GET_FIGHT_INFO',[Pid,PlayerId]},State)->
	erlang:send_after(5*1000, self(), {'FIGHT_INFO',[Pid,PlayerId]}),
	{noreply,State};

%%淘汰赛数据更新
%% gen_server:cast(ScenePid, {'ELIMINATION_RESULT',[AutoId,WinnerId,WinnerWins]}),
handle_cast({'ELIMINATION_RESULT',[AutoId,WinnerId,WinnerWins]},State)->
	case lists:keyfind(AutoId, 1, State#state.elimination) of
		false->NewState = State;
		{_,_,PlayerIdA,NicknameA,AWins,PlayerIdB,NicknameB,BWins}->
			if WinnerWins >= 2->
				   if PlayerIdA == WinnerId->
						  NewAWins = WinnerWins,
						  NewBWins = BWins,
						  Finish = 1;
					  true->
						  NewAWins = AWins,
						  NewBWins = WinnerWins,
						  Finish = 1
				   end;
			   true->
				   if PlayerIdA == WinnerId ->
						  NewAWins = WinnerWins,
						  NewBWins = BWins,
						  Finish=0;
					  true->
						  NewAWins = AWins,
						  NewBWins = WinnerWins,
						  Finish = 0
				   end
			end,
			Member = lists:keyreplace(AutoId, 1, State#state.elimination, {AutoId,Finish,PlayerIdA,NicknameA,NewAWins,PlayerIdB,NicknameB,NewBWins}),
			NewState = State#state{elimination=Member}
	end,
	{noreply,NewState};

%%决赛数据更新
handle_cast({'FINAL_RESULT',[AutoId,WinnerId,WinnerWins]},State)->
	case lists:keyfind(AutoId, 1, State#state.champion) of
		false->NewState = State;
		{_,_,PlayerIdA,NicknameA,AWins,PlayerIdB,NicknameB,BWins}->
			if WinnerWins >= 2->
				   if PlayerIdA == WinnerId->
						  NewAWins = WinnerWins,
						  NewBWins = BWins,
						  Finish = 1;
					  true->
						  NewAWins = AWins,
						  NewBWins = WinnerWins,
						  Finish = 1
				   end;
			   true->
				   if PlayerIdA == WinnerId ->
						  NewAWins = WinnerWins,
						  NewBWins = BWins,
						  Finish=0;
					  true->
						  NewAWins = AWins,
						  NewBWins = WinnerWins,
						  Finish = 0
				   end
			end,
			Member = lists:keyreplace(AutoId, 1, State#state.champion, {AutoId,Finish,PlayerIdA,NicknameA,NewAWins,PlayerIdB,NicknameB,NewBWins}),
			NewState = State#state{champion=Member}
	end,
	{noreply,NewState};

%%玩家选择观战
handle_cast({'CHOICE_VIEW',[Status,FightId]},State)->
	case lib_war2:choice_view(Status,State#state.status,State#state.member_view,FightId) of
		true->
			NewMemberView = [{Status#player.id,FightId}|State#state.member_view],
			NewState = State#state{member_view=NewMemberView};
		false->
			NewState = State
	end,
	{noreply,NewState};

handle_cast(_MSg,State)->
	 {noreply, State}.

%%种子选手自动晋级
handle_info({'SEED_OFFTRACK',[Record]},State)->
	PlayerId = Record#ets_war2_record.pid,
%% 	offtrack_msg_seed(Record),
	case lists:member(PlayerId, State#state.tryout) of
		false->
			update_finght_info(State),
			NewMember = [PlayerId|State#state.tryout];
		true->
			NewMember = State#state.tryout
	end,
	{noreply,State#state{tryout=NewMember}};

%%选拔赛开始公告
handle_info({'MSG_TRYOUT'},State)->
	NewState = State#state{match_start=1,end_time=get_end_time(State#state.status)},
%% NewState = State#state{match_start=1,end_time=420 + util:unixtime()},
	spawn(fun()->update_finght_info(NewState)end),
	{noreply,NewState};

%%推送比赛个人信息
handle_info({'FIGHT_INFO',[Pid,PlayerId]},State)->
	if State#state.status == 2->
		   Timestamp = State#state.end_time - util:unixtime(),
		   {Wins,Offtrack} = 
			   case lib_war2:ets_select_war2_record(PlayerId) of
				   []->{0,0};
				   [R]->
					   if R#ets_war2_record.seed == 1 orelse R#ets_war2_record.offtrack==1->
							  
							  {R#ets_war2_record.wins,1};
						  true->
							  {R#ets_war2_record.wins,0}
					   end
			   end,
		   {ok,BinData} = pt_45:write(45112, [State#state.grade,State#state.subarea,Timestamp,Wins,10,length(State#state.tryout),State#state.match_start,Offtrack]),
		   lib_send:send_to_uid(PlayerId, BinData),
		   ok;
	   State#state.status >= 3 andalso State#state.status =< 7->
		   Timestamp = State#state.end_time - util:unixtime(),
		   spawn(fun()->fight_info_elimination_single(PlayerId,State,Timestamp)end),
		   ok;
	   State#state.status == 0 ->
		    Timestamp = State#state.next_gametime_view - util:unixtime(),
			{ok,BinData} = pt_45:write(45113, [0,Timestamp,0,0,0,0]),
			lib_send:send_to_uid(PlayerId, BinData),
		   ok;
	   true->skip
	end,
	case lists:keyfind(PlayerId, 2, State#state.member) of
		false->
			NewMember = [{Pid,PlayerId}|State#state.member];
		_->
			NewMember = lists:keyreplace(PlayerId, 2, State#state.member, {Pid,PlayerId})
	end,
	{noreply,State#state{member = NewMember}};

%%查询出线情况，关闭场景
handle_info({'OFFTRACK'},State)->
	case length(State#state.tryout) >= 8 of
		true->skip;
		false->
			get_offtrack_other(State)
	end,
	erlang:send_after(10*1000, self(), {'CLOSE'}),
	{noreply,State};

%%创建淘汰赛
handle_info({'ELIMINATION'},State)->
	misc:cancel_timer(elimination),
	Self = self(),
	mod_leap_server:sync_war2_state(3),
	{NewState,	NewContinue} = 
		if State#state.status >= 3 andalso State#state.status =< 6->
			   if State#state.round < 3 ->
					  {State1,Continue} = fight_elimination(State#state.elimination,State,Self,0,State#state.times,State#state.round,State#state.member_view),
					  {State1,Continue};
				  true->{State,false}
			   end;
		   State#state.status == 7->
			   {State1,Continue} = fight_elimination(State#state.elimination,State,Self,0,State#state.times,State#state.round,State#state.member_view),
			   State2 = 
				   case Continue of
				   true->State1;
				   false->
					   Self!{'FINAL',[0]},
					   State1#state{final=1}
			   end,
			   {State2,Continue};
		   true->
			   {State,false}
		end,
	if State#state.round < 3 andalso NewContinue==true->
		   TimerHandle = erlang:send_after(5*60*1000, Self, {'ELIMINATION'}),
		   put(elimination,TimerHandle);
	   true->
		   if State#state.status >= 3 andalso State#state.status =< 6->
				  erlang:send_after(1*1000, self(), {'SERVER_END_MSG'}),
				  erlang:send_after(10*1000, self(), {'BET_PROVIDE'}),
%% 				  gen_server:cast(mod_war2_supervisor:get_mod_war2_supervisor_pid(), {'NOTICE_OPEN_NEXT_GAME'}),
				   erlang:send_after(10*60*1000, self(), {'CLOSE'});
			  true->skip
		   end
	end,
	lib_war2:sync_elimination_data_remote(),
	if State#state.status /= 7->
		   Member_view = [];
	   true->
		   Member_view = State#state.member_view
	end,
	{noreply,NewState#state{round = NewState#state.round+1,member_view=Member_view,end_time = get_end_time(State#state.status)}};

%%服务开放通知
handle_info({'SERVER_OPEN_MSG'},State)->
%% 	mod_leap_server:sync_war2_state(5),
	mod_leap_server:sync_war2_state(3),
	spawn(fun()->server_open_msg(State#state.times,State#state.status)end),
	{noreply,State};

%%结束通知
handle_info({'SERVER_END_MSG'},State)->
	spawn(fun()->server_end_msg([1,2],State)end),
	{noreply,State};

%%通知发放投注
handle_info({'BET_PROVIDE'},State)->
	mod_leap_server:sync_war2_state(0),
	mod_leap_server:notice_bet_provide(),
	{noreply,State};

%%决赛
handle_info({'FINAL',[Round]},State)->
	if Round ==0->
		   spawn(fun()->final_msg(State#state.times)end);
	   true->skip
	end,
	misc:cancel_timer(final),
	Self = self(),
	NewState = 
		if Round < 3->
			   {State1,Continue} = fight_elimination(State#state.champion,State,Self,1,State#state.times,Round+1,State#state.member_view),
			   if Continue == true->
					  TimerHandle = erlang:send_after(5*60*1000, Self, {'FINAL',[Round+1]}),
					  put(final,TimerHandle),
					  State1#state{round=Round+1,end_time = get_end_time(State#state.status)};
				  true->
					  erlang:send_after(10*1000, self(), {'BET_PROVIDE'}),
					  erlang:send_after(1*60*1000, self(), {'NOTICE_AWARD'}),
					  erlang:send_after(10*60*1000, self(), {'CLOSE'}),
					  State1
			   end;
		   true->
			   erlang:send_after(10*1000, self(), {'BET_PROVIDE'}),
			   erlang:send_after(1*60*1000, self(), {'NOTICE_AWARD'}),
			   erlang:send_after(10*60*1000, self(), {'CLOSE'}),
			   State
		end,
	lib_war2:sync_elimination_data_remote(),
	{noreply,NewState#state{member_view=[]}};


%%通知发放奖励
handle_info({'NOTICE_AWARD'},State)->
	mod_leap_server:notice_war2_award(),
	mod_leap_server:sync_war2_state(4),
	gen_server:cast(mod_war2_supervisor:get_mod_war2_supervisor_pid(), {'CHANGE_WAR2_STATE',[4]}),
	{noreply,State};

handle_info({'CLOSE'},State)->
	exit_war2(State#state.scene_id),
	mod_leap_server:sync_war2_state(0),
	{stop, normal, State};

%%观战时间
%% NEXT_GAME_TIME
handle_info({'NEXT_GAME_TIME',[Timestamp]},State)->
	erlang:send_after(Timestamp, self(),{'NEXT_GAME_TIME',[Timestamp]} ),
	{noreply,State#state{next_gametime_view=Timestamp+util:unixtime()}};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, State) ->
	misc:delete_monitor_pid(self()),
	spawn(fun()-> lib_scene:clear_scene(State#state.scene_id) end),
	ok.

code_change(_OldVsn, State, _Extra)->
    {ok, State}.

%%服务开放通知
server_open_msg(_Times,State)->
	Msg = 
		if State >=3 andalso State =< 5->
			   io_lib:format("<font color='#FEDB4F'>封神争霸~p强淘汰赛</font>即将开始，请参赛选手/观战玩家进入比赛场景准备！<a href='event:5'><font color='#00FF00'><u>》》进入比赛《《</u></font></a>",[state_to_lv(State)]);
		   State ==6->
			    "<font color='#FEDB4F'>封神争霸</font>淘汰赛<font color='#FEDB4F'>半决赛</font>即将开始，请参赛选手/观战玩家进入比赛场景准备！<a href='event:5'><font color='#00FF00'><u>》》进入比赛《《</u></font></a>";
		   State ==7->
			   "<font color='#FEDB4F'>封神争霸季军赛</font>即将开始，请参赛选手/观战玩家进入比赛场景准备！<a href='event:5'><font color='#00FF00'><u>》》进入比赛《《</u></font></a>";
		   true->[]
		end,
	case Msg of
		[]->skip;
		_->
			lib_chat:broadcast_sys_msg(6,Msg),
			mod_leap_server:remote_server_msg(Msg)
	end.

final_msg(Times)->
	Msg = io_lib:format("第<font color='#FEDB4F;'>~p</font>届<font color='#FEDB4F'>封神争霸决赛</font>即将拉开帷幕，<font color='#FEDB4F;'>远古无双</font>的至尊称号会花落谁家？<a href='event:5'><font color='#00FF00'><u>》》进入比赛《《</u></font></a>", [Times]),
	lib_chat:broadcast_sys_msg(6,Msg),
			mod_leap_server:remote_server_msg(Msg).

%%比赛结束通知
server_end_msg([],_State)->skip;
server_end_msg([Grade|GradeBag],State)->
	Msg = 
		case State#state.status of
			3->
			%% 	封神争霸32强淘汰赛圆满结束，共XX位选手晋级，让我们期待他们在下一阶段的表现！>>>查看赛程<<<
				case length(lib_war2:ets_select_war2_elimination_by_win(Grade)) of
					0->[];
					Num->
						io_lib:format("<font color='#FEDB4F'>封神争霸~s32强淘汰赛</font>圆满结束，共~p位选手晋级，让我们期待他们在下一阶段的表现！<a href='event:5'><font color='#00FF00'><u>》》查看赛程《《</u></font></a>",[grade_to_name(Grade),Num])
				end;
			4->
			%%封神争霸16强淘汰赛圆满结束，共XX位选手晋级，让我们期待他们在下一阶段的表现！>>>查看赛程<<<
				case length(lib_war2:ets_select_war2_elimination_by_win(Grade)) of
					0->[];
					Num->
						io_lib:format("<font color='#FEDB4F'>封神争霸~s16强淘汰赛</font>圆满结束，共~p位选手晋级，让我们期待他们在下一阶段的表现！<a href='event:5'><font color='#00FF00'><u>》》查看赛程《《</u></font></a>",[grade_to_name(Grade),Num])
				end;
			5->
			%%封神争霸8强淘汰赛圆满结束，XXXX、XXXX、XXXX、XXXX晋级半决赛，让我们期待他们在下一阶段的表现！>>>查看赛程<<<%
				case lib_war2:ets_select_war2_elimination_by_win(Grade) of
					[]->[];
					Member->
						io_lib:format("<font color='#FEDB4F'>封神争霸~s8强淘汰赛</font>圆满结束，<font color='#FEDB4F'>~s</font>晋级<font color='#FEDB4F'>半决赛</font>，让我们期待他们在下一阶段的表现！<a href='event:5'><font color='#00FF00'><u>》》查看赛程《《</u></font></a>",[grade_to_name(Grade),get_win_name(Member,[])])
				end;
			6->
				%% 封神争霸淘汰赛半决赛圆满结束，XXXX、XXXX晋级决赛，让我们期待他们在下一阶段的表现！>>>查看赛程<<<%
				case lib_war2:ets_select_war2_elimination_by_win(Grade) of
					[]->[];
					Member->
						io_lib:format("<font color='#FEDB4F'>封神争霸~s半决赛</font>圆满结束，<font color='#FEDB4F'>~s</font>晋级<font color='#FEDB4F'>决赛</font>，让我们期待他们在下一阶段的表现！<a href='event:5'><font color='#00FF00'><u>》》查看赛程《《</u></font></a>",[grade_to_name(Grade),get_win_name(Member,[])])
				end;
			_->[]
		end,
	case Msg of
		[]->skip;
		_->
			lib_chat:broadcast_sys_msg(6,Msg),
			mod_leap_server:remote_server_msg(Msg)
	end,
	server_end_msg(GradeBag,State).

grade_to_name(Grade)->
	case Grade of
		1->"天罡";
		_->"地煞"
	end.

get_win_name([],Name)->Name;
get_win_name([M|Member],Name)->
	if Name ==[]->
		   NewName = io_lib:format("~s", [M#ets_war2_elimination.nickname]);
	   true->
			NewName = io_lib:format("~s,~s", [Name,M#ets_war2_elimination.nickname])
	end,
	get_win_name(Member,NewName).
%% 	[M#ets_war2_elimination.nickname||M<-Member].


state_to_lv(State)->
	case State of
		3->32;
		4->16;
		5->8;
		_6->4
	end.


%%创建选拔赛PK场景服务
fight_tryout(Times,Grade,Subarea,SubareaPid,SubareaSceneId,Status,Member,ViewBag)->
	SceneId = mod_dungeon:get_unique_dungeon_id(740),
	{ok,_Pid} = mod_war2_fight:start([Times,Grade,Subarea,Status,SceneId,SubareaPid,SubareaSceneId,Member,0,0,0,ViewBag]),
	ok.

%%创建淘汰赛强PK场景服务
fight_elimination(VsInfo,State,Self,Final,Times,Round,ViewBag)->
	MaxWin =
		if State#state.status == 7->2;
		   true->2
		end,
	{NewElimination,Continue} = elimination_server_loop(VsInfo,[],State#state.status,Self,State#state.scene_id,State#state.member,false,Final,Times,MaxWin,Round,ViewBag),
	if Final == 1->
		  {State#state{champion = NewElimination},Continue};
	   true->
		{State#state{elimination = NewElimination},Continue}
	end.

elimination_server_loop([],NewVs,_Status,_SubareaPid,_SubareaSceneId,_PidBag,Continue,_Final,_Times,_MaxWin,_Round,_ViewBag)->
	{NewVs,Continue};
elimination_server_loop([Vs|VsInfo],NewVs,Status,SubareaPid,SubareaSceneId,PidBag,Continue,Final,Times,MaxWin,Round,ViewBag)->
	{AutoId,Finish,PlayerIdA,NicknameA,WinA,PlayerIdB,NicknameB,WinB}=Vs,
	if WinA>=MaxWin orelse WinB >= MaxWin->
		   %%获得三场胜利
			NewFinish = if Finish == 1-> Finish;
						   true->
							   %%玩家晋级处理
							   if Status /= 7->
									  if WinA >=MaxWin->
											 promotion(PlayerIdA,Status,WinA,NicknameB,WinB),
											 elimination(PlayerIdB,Status,WinB,NicknameA,WinA);
										 true->
											 promotion(PlayerIdB,Status,WinB,NicknameA,WinA),
											 elimination(PlayerIdA,Status,WinA,NicknameB,WinB)
									  end;
								  true->
									  if Final == 1->
											 if WinA >=MaxWin->
													{LP,LS} = runnerup(PlayerIdB,Status,WinB,NicknameA,WinA),
													champion(PlayerIdA,Status,WinA,NicknameB,WinB,LP,LS);
												true->
													{LP,LS} = runnerup(PlayerIdA,Status,WinA,NicknameB,WinB),
													champion(PlayerIdB,Status,WinB,NicknameA,WinA,LP,LS)
											 end;
										 true->
											 if WinA >=MaxWin->
													{LP,LS} = fourthplace(PlayerIdB,Status,WinB,NicknameA,WinA),
													thirdplace(PlayerIdA,Status,WinA,NicknameB,WinB,LP,LS);
												true->
													{LP,LS} = fourthplace(PlayerIdA,Status,WinA,NicknameB,WinB),
													thirdplace(PlayerIdB,Status,WinB,NicknameA,WinA,LP,LS)
											 end
									  end
							   end,
							   1
						end,
			elimination_server_loop(VsInfo,[{AutoId,NewFinish,PlayerIdA,NicknameA,WinA,PlayerIdB,NicknameB,WinB}|NewVs],Status,SubareaPid,SubareaSceneId,PidBag,Continue,Final,Times,MaxWin,Round,ViewBag);
	   PlayerIdA == undefined orelse PlayerIdB == undefined->
		   %%没有对手，自动晋级
		   NewFinish = if Finish == 1-> Finish;
						  true->
							  %%玩家晋级处理
							  if Status /= 7->
									 if PlayerIdB == undefined andalso PlayerIdA /= undefined->
											promotion(PlayerIdA,Status,WinA,<<>>,0);
										PlayerIdA == undefined andalso PlayerIdB /= undefined ->
											promotion(PlayerIdB,Status,WinB,<<>>,0);
										true->skip
									 end;
								 true->
									 if Final == 1->
											if PlayerIdB == undefined andalso PlayerIdA /= undefined->
												   champion(PlayerIdA,Status,WinA,<<>>,0,null,0);
											   PlayerIdA == undefined andalso PlayerIdB /= undefined ->
												   champion(PlayerIdB,Status,WinB,<<>>,0,null,0);
											   true->skip
											end;
										true->
											if PlayerIdB == undefined andalso PlayerIdA /= undefined->
												   thirdplace(PlayerIdA,Status,WinA,<<>>,0,null,0);
											   PlayerIdA == undefined andalso PlayerIdB /= undefined ->
												   thirdplace(PlayerIdB,Status,WinB,<<>>,0,null,0);
											   true->skip
											end
									 end
							  end,
							  1
						end,
		   elimination_server_loop(VsInfo,[{AutoId,NewFinish,PlayerIdA,NicknameA,WinA,PlayerIdB,NicknameB,WinB}|NewVs],Status,SubareaPid,SubareaSceneId,PidBag,Continue,Final,Times,MaxWin,Round,ViewBag);
	   true->
		   %%查找玩家PId
		   PlayerAPid = check_player_pid(PlayerIdA,PidBag),
		   PlayerBPid = check_player_pid(PlayerIdB,PidBag),
		   %%创建战斗场景
		   SceneId = mod_dungeon:get_unique_dungeon_id(740),
		   MemberData = [{PlayerAPid,PlayerIdA,NicknameA},{PlayerBPid,PlayerIdB,NicknameB}],
		   {ok,_Pid} = mod_war2_fight:start([Times,0,0,Status,SceneId,SubareaPid,SubareaSceneId,MemberData,AutoId,Final,Round,ViewBag]),
		   elimination_server_loop(VsInfo,[Vs|NewVs],Status,SubareaPid,SubareaSceneId,PidBag,true,Final,Times,MaxWin,Round,ViewBag)
	end.

%%查找PID
check_player_pid(PlayerId,PidBag)->
	case lists:keyfind(PlayerId, 1, PidBag) of
		false->
			case lib_player:get_player_pid(PlayerId) of
				[]->undefined;
				Pid1->Pid1
			end;
		{Pid,_}->Pid
	end.

%%玩家晋级
promotion(PlayerId,State,Wins,LoserName,LoserWins)->
	case lib_war2:ets_select_war2_elimination(PlayerId) of
		[]->skip;
		[Eli]->
			NEli = Eli#ets_war2_elimination{state=State+1,wins=0},
			lib_war2:ets_update_war2_elimination(NEli),
			db_agent:update_war2_elimination([{state,NEli#ets_war2_elimination.state},{wins,0}], [{pid,PlayerId}]),
			lib_war2:elimination_history(Eli#ets_war2_elimination.platform,Eli#ets_war2_elimination.sn,Eli#ets_war2_elimination.nickname,[Eli#ets_war2_elimination.nickname,LoserName,State,util:term_to_string(lists:concat([Wins,":",LoserWins])),util:unixtime()]),
			ok
	end.


%%玩家被淘汰
elimination(PlayerId,State,Wins,WinnerName,WinnerWins)->
	case lib_war2:ets_select_war2_elimination(PlayerId) of
		[]->skip;
		[Eli]->
			NEli = Eli#ets_war2_elimination{elimination=0,wins=0},
			lib_war2:ets_update_war2_elimination(NEli),
			db_agent:update_war2_elimination([{elimination,0},{wins,0}], [{pid,PlayerId}]),
			lib_war2:elimination_history(Eli#ets_war2_elimination.platform,Eli#ets_war2_elimination.sn,Eli#ets_war2_elimination.nickname,[Eli#ets_war2_elimination.nickname,WinnerName,State,util:term_to_string(lists:concat([Wins,":",WinnerWins])),util:unixtime()]),
			ok
	end.


%%冠军
champion(PlayerId,State,Wins,LoserName,LoserWins,Platform,Sn)->
	case lib_war2:ets_select_war2_elimination(PlayerId) of
		[]->skip;
		[Eli]->
			ChampionData =  [Eli#ets_war2_elimination.nickname,
							 Eli#ets_war2_elimination.career,
							 Eli#ets_war2_elimination.sex,
							 Eli#ets_war2_elimination.platform,
							 Eli#ets_war2_elimination.sn,
							 Eli#ets_war2_elimination.grade,
							 0,
							 util:unixtime()],
			lib_war2:sync_champion(ChampionData),
			NEli = Eli#ets_war2_elimination{champion=1}, 
			lib_war2:ets_update_war2_elimination(NEli),
			db_agent:update_war2_elimination([{champion,1}], [{pid,PlayerId}]),
			lib_war2:elimination_history(Eli#ets_war2_elimination.platform,Eli#ets_war2_elimination.sn,Eli#ets_war2_elimination.nickname,[Eli#ets_war2_elimination.nickname,LoserName,State,util:term_to_string(lists:concat([Wins,":",LoserWins])),util:unixtime()]),
			spawn(fun()->champion_msg(Eli#ets_war2_elimination.platform,Eli#ets_war2_elimination.sn,Eli#ets_war2_elimination.nickname,Platform,Sn,LoserName,Eli#ets_war2_elimination.grade)end),
			ok
	end.

champion_msg(WinPlatform,WinSn,WinName,LoserPlatform,LoserSn,LoserName,Grade)->
	case Grade of
		1->
			%% 			在封神争霸决赛中，来自（平台）（服号）的XXXX击败了来自（平台）（服号）的XXXX，获得本届封神争霸的冠军！远古无双，舍我其谁！>>>查看赛程<<<
			case LoserPlatform of
				null->
					Content = io_lib:format("<font color='#FEDB4F'>~s</font>平台<font color='#FEDB4F'>~p</font>服的<font color='#FEDB4F'>~s</font>获得本届<font color='#FEDB4F'>封神争霸</font>的<font color='#FEDB4F'>冠军</font>！远古无双，舍我其谁！<a href='event:5'><font color='#00FF00'><u>》》查看赛程《《</u></font></a>", [lib_war:platform(WinPlatform),WinSn,WinName]);
				_->
					Content = io_lib:format("在<font color='#FEDB4F'>封神争霸决赛</font>中，来自<font color='#FEDB4F'>~s</font>平台<font color='#FEDB4F'>~p</font>服的<font color='#FEDB4F'>~s</font>击败了来自<font color='#FEDB4F'>~s</font>平台<font color='#FEDB4F'>~p</font>服的<font color='#FEDB4F'>~s</font>，获得本届<font color='#FEDB4F'>封神争霸</font>的<font color='#FEDB4F'>冠军</font>！远古无双，舍我其谁！<a href='event:5'><font color='#00FF00'><u>》》查看赛程《《</u></font></a>", 
											[lib_war:platform(WinPlatform),WinSn,WinName,lib_war:platform(LoserPlatform),LoserSn,LoserName])
			end;
		_->
			case LoserPlatform of
				null->
					Content = io_lib:format("<font color='#FEDB4F'>~s</font>平台<font color='#FEDB4F'>~p</font>服的<font color='#FEDB4F'>~s</font>获得本届<font color='#FEDB4F'>封神争霸</font>的<font color='#FEDB4F'>地煞冠军</font>！<a href='event:5'><font color='#00FF00'><u>》》查看赛程《《</u></font></a>", [lib_war:platform(WinPlatform),WinSn,WinName]);
				_->
					Content = io_lib:format("在<font color='#FEDB4F'>封神争霸决赛</font>中，来自<font color='#FEDB4F'>~s</font>平台<font color='#FEDB4F'>~p</font>服的<font color='#FEDB4F'>~s</font>击败了来自<font color='#FEDB4F'>~s</font>平台<font color='#FEDB4F'>~p</font>服的<font color='#FEDB4F'>~s</font>，获得本届<font color='#FEDB4F'>封神争霸</font>的<font color='#FEDB4F'>地煞冠军</font>！<a href='event:5'><font color='#00FF00'><u>》》查看赛程《《</u></font></a>", 
											[lib_war:platform(WinPlatform),WinSn,WinName,lib_war:platform(LoserPlatform),LoserSn,LoserName])
			end
	end,
	lib_chat:broadcast_sys_msg(6,Content),
	mod_leap_server:remote_server_msg(Content).

%%亚军
runnerup(PlayerId,State,Wins,WinnerName,WinnerWins)->
	case lib_war2:ets_select_war2_elimination(PlayerId) of
		[]->{null,0};
		[Eli]->
			NEli = Eli#ets_war2_elimination{elimination=0,champion=2,wins=0},
			lib_war2:ets_update_war2_elimination(NEli),
			db_agent:update_war2_elimination([{champion,2},{elimination,0},{wins,0},{state,8}], [{pid,PlayerId}]),
			lib_war2:elimination_history(Eli#ets_war2_elimination.platform,Eli#ets_war2_elimination.sn,Eli#ets_war2_elimination.nickname,[Eli#ets_war2_elimination.nickname,WinnerName,State,util:term_to_string(lists:concat([Wins,":",WinnerWins])),util:unixtime()]),
			{Eli#ets_war2_elimination.platform,Eli#ets_war2_elimination.sn}
	end.

%%季军
thirdplace(PlayerId,_State,Wins,LoserName,LoserWins,LP,LS)->
	case lib_war2:ets_select_war2_elimination(PlayerId) of
		[]->skip;
		[Eli]->
			NEli = Eli#ets_war2_elimination{champion=3}, 
			lib_war2:ets_update_war2_elimination(NEli),
			db_agent:update_war2_elimination([{champion,3}], [{pid,PlayerId}]),
			lib_war2:elimination_history(Eli#ets_war2_elimination.platform,Eli#ets_war2_elimination.sn,Eli#ets_war2_elimination.nickname,[Eli#ets_war2_elimination.nickname,LoserName,8,util:term_to_string(lists:concat([Wins,":",LoserWins])),util:unixtime()]),
			thirdplace_msg(Eli#ets_war2_elimination.grade,Eli#ets_war2_elimination.platform,Eli#ets_war2_elimination.sn,Eli#ets_war2_elimination.nickname,LP,LS,LoserName),
			ok
	end.

thirdplace_msg(Grade,WinPlatform,WinSn,WinName,LPlatform,LSn,LoserName)->
	%%在封神争霸的三四名决赛中，来自（平台）（服号）的XXXX击败了来自（平台）（服号）的XXXX，获得本届封神争霸的季军！>>>查看赛程<<<
	case Grade of
		1->
			case LPlatform of
				null->
					Content = io_lib:format("<font color='#FEDB4F'>~s</font>平台<font color='#FEDB4F'>~p</font>服的<font color='#FEDB4F'>~s</font>获得本届封神争霸的天罡季军！<a href='event:5'><font color='#00FF00'><u>》》查看赛程《《</u></font></a>", 
											[lib_war:platform(WinPlatform),WinSn,WinName]);
				_->
					Content = io_lib:format("在<font color='#FEDB4F'>封神争霸</font>的季军赛中，来自<font color='#FEDB4F'>~s</font>平台<font color='#FEDB4F'>~p</font>服的<font color='#FEDB4F'>~s</font>击败了来自<font color='#FEDB4F'>~s</font>平台<font color='#FEDB4F'>~p</font>服的<font color='#FEDB4F'>~s</font>，获得本届封神争霸的<font color='#FEDB4F'>天罡季军</font>！<a href='event:5'><font color='#00FF00'><u>》》查看赛程《《</u></font></a>",
											 [lib_war:platform(WinPlatform),WinSn,WinName,lib_war:platform(LPlatform),LSn,LoserName])
			end;
		_->case LPlatform of
			   null->
				   Content = io_lib:format("<font color='#FEDB4F'>~s</font>平台<font color='#FEDB4F'>~p</font>服的<font color='#FEDB4F'>~s</font>获得本届封神争霸的地煞季军！<a href='event:5'><font color='#00FF00'><u>》》查看赛程《《</u></font></a>", 
										   [lib_war:platform(WinPlatform),WinSn,WinName]);
			   _->
				   Content = io_lib:format("在<font color='#FEDB4F'>封神争霸</font>的季军赛中，来自<font color='#FEDB4F'>~s</font>平台<font color='#FEDB4F'>~p</font>服的<font color='#FEDB4F'>~s</font>击败了来自<font color='#FEDB4F'>~s</font>平台<font color='#FEDB4F'>~p</font>服的<font color='#FEDB4F'>~s</font>，获得本届封神争霸的<font color='#FEDB4F'>地煞季军</font>！<a href='event:5'><font color='#00FF00'><u>》》查看赛程《《</u></font></a>", 
										   [lib_war:platform(WinPlatform),WinSn,WinName,lib_war:platform(LPlatform),LSn,LoserName])
		   end
	end,
	lib_chat:broadcast_sys_msg(6,Content),
	mod_leap_server:remote_server_msg(Content).

%%殿军
fourthplace(PlayerId,_State,Wins,WinnerName,WinnerWins)->
	case lib_war2:ets_select_war2_elimination(PlayerId) of
		[]->{null,0};
		[Eli]->
			NEli = Eli#ets_war2_elimination{champion=1}, 
			lib_war2:ets_update_war2_elimination(NEli),
			db_agent:update_war2_elimination([{champion,4}], [{pid,PlayerId}]),
			lib_war2:elimination_history(Eli#ets_war2_elimination.platform,Eli#ets_war2_elimination.sn,Eli#ets_war2_elimination.nickname,[Eli#ets_war2_elimination.nickname,WinnerName,8,util:term_to_string(lists:concat([Wins,":",WinnerWins])),util:unixtime()]),
			{Eli#ets_war2_elimination.platform,Eli#ets_war2_elimination.sn}
	end.

%%选拔赛时间到，为满足8人出线，挑选候补
get_offtrack_other(State)->
	Members = lib_war2:ets_select_war2_record_by_subarea(State#state.grade,State#state.subarea),
	SortFun = fun({_,_,_,_,_,_,_,_,_,_,_,_,_,_,Wins1,_,_,_}, {_,_,_,_,_,_,_,_,_,_,_,_,_,_,Wins2,_,_,_}) ->
		Wins1 > Wins2 
		end,
	NewMembers = lists:sort(SortFun, Members),
	offtrack_other_loop(length(State#state.tryout),NewMembers,State),
	ok.

offtrack_other_loop(8,_,_State)->ok;
offtrack_other_loop(_,[],_State)->ok;
offtrack_other_loop(Offtracks,[M|Member],State)->
	if M#ets_war2_record.offtrack == 1->
		   offtrack_other_loop(Offtracks,Member,State);
	   M#ets_war2_record.seed == 1->
		   offtrack_other_loop(Offtracks,Member,State);
	   true->
		   lib_war2:tryout(M, State#state.subarea, Offtracks+1, State#state.grade, 3, 1),
		   NewM = M#ets_war2_record{offtrack=1},
		   lib_war2:ets_update_war2_record(NewM),
		   db_agent:update_war2_record([{offtrack,1}], [{pid,M#ets_war2_record.pid}]),
		   offtrack_other_loop(Offtracks+1,Member,State)
	end.


%%%%%%%%%%淘汰赛VS%%%%%%%%%%%%%%%%%%%%%%%%组织淘汰赛对战表

%%%32强
init_elimination_by_grade_32([],VsInfo)->VsInfo;
init_elimination_by_grade_32([Grade|GradeBag],VsInfo)->
	Info = init_elimination_by_subarea_32([1,2,3,4],Grade,[]),
	init_elimination_by_grade_32(GradeBag,Info++VsInfo).
init_elimination_by_subarea_32([],_Grade,VsInfo)->VsInfo;
init_elimination_by_subarea_32([Subarea|SubareaBag],Grade,VsInfo)->
	Info = pack_elimination_32(Grade,Subarea),
	init_elimination_by_subarea_32(SubareaBag,Grade,Info++VsInfo).

%%{PlayerIdA,NameA,WinA,PlayerIdB,NameB,WinB}
pack_elimination_32(Grade,Subarea)->
	Member = lib_war2:ets_select_war2_elimination_by_subarea(Grade, Subarea),
	A = lists:keyfind(1, 13, Member),
	B = lists:keyfind(8, 13, Member),
	C = lists:keyfind(2, 13, Member),
	D = lists:keyfind(7, 13, Member),
	E = lists:keyfind(3, 13, Member),
	F = lists:keyfind(6, 13, Member),
	G = lists:keyfind(4, 13, Member),
	H = lists:keyfind(5, 13, Member),
	Bag = [pack_info([A,B],[]),pack_info([C,D],[]),pack_info([E,F],[]),pack_info([G,H],[])],
	Bag.

%%16强
init_elimination_by_grade_16([],VsInfo)->VsInfo;
init_elimination_by_grade_16([Grade|GradeBag],VsInfo)->
	Info = init_elimination_by_grade_16([1,2,3,4],Grade,[]),
	init_elimination_by_grade_16(GradeBag,Info++VsInfo).
init_elimination_by_grade_16([],_Grade,VsInfo)->VsInfo;
init_elimination_by_grade_16([Subarea|SubareaBag],Grade,VsInfo)->
	Info = pack_elimination_16(Grade,Subarea),
	init_elimination_by_grade_16(SubareaBag,Grade,Info++VsInfo).

pack_elimination_16(Grade,Subarea)->
	Member = lib_war2:ets_select_war2_elimination_by_subarea(Grade, Subarea),
	NewMember = [M||M<-Member,M#ets_war2_elimination.elimination ==1],
	[find_player_16([1,8,2,7],NewMember,[]),find_player_16([3,6,4,5],NewMember,[])].

find_player_16([],_Member,NewMember)->
	Len = length(NewMember),
	if Len >= 2 ->
			[A,B|_] = NewMember,
			pack_info([A,B],[]);
		Len ==1->
			[A|_] = NewMember,
			pack_info([A,false],[]);
	   true->
		   pack_info([false,false],[])
	end;	
find_player_16([Num|NumBag],Member,NewMember)->
	case lists:keyfind(Num, 13, Member) of
		false->
			find_player_16(NumBag,Member,NewMember);
		M->
			find_player_16(NumBag,Member,[M|NewMember])
	end.
		
%%8强
init_elimination_by_grade_8([],VsInfo)->VsInfo;
init_elimination_by_grade_8([Grade|GradeBag],VsInfo)->
	Info = init_elimination_by_grade_8([1,2,3,4],Grade,[]),
	init_elimination_by_grade_8(GradeBag,Info++VsInfo).
init_elimination_by_grade_8([],_Grade,VsInfo)->VsInfo;
init_elimination_by_grade_8([Subarea|SubareaBag],Grade,VsInfo)->
	Info = pack_elimination_8(Grade,Subarea),
	init_elimination_by_grade_8(SubareaBag,Grade,Info++VsInfo).

pack_elimination_8(Grade,Subarea)->
	Member = lib_war2:ets_select_war2_elimination_by_subarea(Grade, Subarea),
	NewMember = [M||M<-Member,M#ets_war2_elimination.elimination ==1],
	Len = length(NewMember),
	if Len >= 2 ->
			[A,B|_] = NewMember,
			[pack_info([A,B],[])];
		Len ==1->
			[A|_] = NewMember,
			[pack_info([A,false],[])];
	   true->
		   [pack_info([false,false],[])]
	end.
	
%%4强
init_elimination_by_grade_4([],VsInfo)->VsInfo;
init_elimination_by_grade_4([Grade|GradeBag],VsInfo)->
	A = pack_elimination_4(Grade,1),
	B = pack_elimination_4(Grade,3),
	C = pack_elimination_4(Grade,2),
	D = pack_elimination_4(Grade,4),
	init_elimination_by_grade_4(GradeBag,[pack_info([A,B],[]),pack_info([C,D],[])]++VsInfo).

pack_elimination_4(Grade,Subarea)->
	Member = lib_war2:ets_select_war2_elimination_by_subarea(Grade, Subarea),
	NewMember = [M||M<-Member,M#ets_war2_elimination.elimination ==1],
	case length(NewMember) > 0 of
		true->
			[A|_] = NewMember,
			A;
		false->false
	end.

%%季军
init_elimination_by_grade_third([],VsInfo)->VsInfo;
init_elimination_by_grade_third([Grade|GradeBag],VsInfo)->
	Member = lib_war2:ets_select_war2_elimination_by_grade(Grade),
	NewMember = [M||M<-Member,M#ets_war2_elimination.state ==6],
	Len = length(NewMember),
	if Len >= 2 ->
		   [A,B|_] = NewMember,
		   Info = [pack_info([A,B],[])];
	   Len >= 1->
		   [A|_] = NewMember,
		   Info = [pack_info([A,false],[])];
	   true->
		    Info = [pack_info([false,false],[])]
	end,
	init_elimination_by_grade_third(GradeBag,Info++VsInfo).
	
%%决赛
init_elimination_by_grade_final([],VsInfo)->VsInfo;
init_elimination_by_grade_final([Grade|GradeBag],VsInfo)->
	Member = lib_war2:ets_select_war2_elimination_by_grade(Grade),
	NewMember = [M||M<-Member,M#ets_war2_elimination.elimination ==1],
	Len = length(NewMember), 
	if Len >= 2 ->
		   [A,B|_] = NewMember,
		   Info = [pack_info([A,B],[])];
	   Len >= 1->
		   [A|_] = NewMember,
		   Info = [pack_info([A,false],[])];
	   true->
		    Info = [pack_info([false,false],[])]
	end,
	init_elimination_by_grade_final(GradeBag,Info++VsInfo).



pack_info([],Info)->
	AutoId = mod_mon_create:get_mon_auto_id(1),
	erlang:list_to_tuple([AutoId,0]++Info);
pack_info([M|Member],Info)->
	case M of
		false->
			pack_info(Member,[undefined,undefined,0]++Info);
		_->
			pack_info(Member,[M#ets_war2_elimination.pid,M#ets_war2_elimination.nickname,M#ets_war2_elimination.wins]++Info)
	end.

%%更新所有玩家比赛个人信息
update_finght_info(State)->
	Timestamp = State#state.end_time - util:unixtime(),
	if State#state.status == 2->
		   Tryout = length(State#state.tryout),
			update_fight_info_tryout(State#state.member,Timestamp,State#state.status,Tryout,State#state.grade,State#state.subarea,State#state.match_start),
		   ok;
	   true->skip
	end,
	ok.
update_fight_info_tryout([],_EndTime,_State,_Tryout,_Grade,_Subarea,_MatchStart)->ok;
update_fight_info_tryout([M|Member],EndTime,State,Tryout,Grade,Subarea,MatchStart)->
	{Pid,PlayerId} = M,
	case misc:is_process_alive(Pid) of
		true->
			case  lib_player:get_online_info_fields(PlayerId, [scene]) of
				[SceneId]->
					case lib_war2:is_wait_scene(SceneId) of
						true->
							fight_info_tryout(PlayerId,EndTime,Tryout,Grade,Subarea,MatchStart);
						false->
							skip
					end;
				_->skip
			
			end;
		false->
			skip
	end,
	update_fight_info_tryout(Member,EndTime,State,Tryout,Grade,Subarea,MatchStart).

fight_info_tryout(PlayerId,EndTime,Tryout,Grade,Subarea,MatchStart)->
	{Wins,Offtrack} = 
			   case lib_war2:ets_select_war2_record(PlayerId) of
				   []->{0,0};
				   [R]->
					   if R#ets_war2_record.seed == 1 orelse R#ets_war2_record.offtrack==1->
							  
							  {R#ets_war2_record.wins,1};
						  true->
							  {R#ets_war2_record.wins,0}
					   end
			   end,
	{ok,BinData} = pt_45:write(45112, [Grade,Subarea,EndTime,Wins,10,Tryout,MatchStart,Offtrack]),
	lib_send:send_to_uid(PlayerId, BinData),
	ok.

fight_info_elimination_single(PlayerId,State,EndTime)->
	MaxRound = 
		if State#state.status ==7->3;
		   true->3
		end,
	{NewWins,NewEnemyWins,NewRemain,NewFinish} = 
		case lists:keyfind(PlayerId, 3, State#state.elimination) of
			false->
				case lists:keyfind(PlayerId, 6, State#state.elimination) of
					false->
						case lists:keyfind(PlayerId, 3, State#state.champion) of
							false->
								case lists:keyfind(PlayerId, 6, State#state.champion) of
									false->
										{0,0,0,1};
									{_,Finish,_,_,Wins,_EnemyId,_,EnemyWins}->
										{EnemyWins,Wins,MaxRound-EnemyWins-Wins,Finish}
								end;
							{_,Finish,_,_,Wins,_EnemyId,_,EnemyWins}->
								{Wins,EnemyWins,MaxRound-EnemyWins-Wins,Finish}
						end;
					{_,Finish,_,_,Wins,_EnemyId,_,EnemyWins}->
						{EnemyWins,Wins,MaxRound-EnemyWins-Wins,Finish}
				end;
			{_,Finish,_,_,Wins,_EnemyId,_,EnemyWins}->
				{Wins,EnemyWins,MaxRound-EnemyWins-Wins,Finish}
		end,
	NewStatus = 
		if State#state.status ==7 andalso State#state.final==1->8;
		   true->State#state.status
		end,
	{ok,BinData} = pt_45:write(45113, [NewStatus,EndTime,NewWins,NewEnemyWins,NewRemain,NewFinish]),
	lib_send:send_to_uid(PlayerId, BinData).

%%通知玩家更换场景
notice_change_scene([],_SceneId,_ScenePid)->
	ok;
notice_change_scene([M|Member],SceneId,ScenePid)->
	case lib_player:get_player_pid(M#ets_war2_elimination.pid) of
		[]->skip;
		Pid->
			gen_server:cast(Pid,{'CHANGE_WAR2_SCENE',[ScenePid,SceneId,730,22,54]}),
			ok
	end,
	notice_change_scene(Member,SceneId,ScenePid).

%% %%淘汰赛全服信息
%% elimination_msg()->
%% 	ok.

%%通知玩家退出封神争霸
exit_war2(SceneId)->
	PlayerBag = lib_scene:get_scene_user(SceneId),
	{ok,BinData} = pt_45:write(45117, [1]),
	F = fun(PlayerId,Bin)->
				lib_send:send_to_uid(PlayerId, Bin) 
		end,
	[F(Id,BinData)||[Id|_]<-PlayerBag].