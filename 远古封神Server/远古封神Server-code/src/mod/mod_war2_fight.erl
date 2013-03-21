%% Author: Administrator
%% Created: 2012-2-21
%% Description: TODO: 跨服单人竞技战斗服务
-module(mod_war2_fight).


%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").

%%
%% Exported Functions
%%
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-export([start/1,stop/0]).

-record(state, {
				times =  0 ,	%%届次
				round = 0,		%%轮次
				scene_self = 0, %%场景id
				status = 0,		%%当前状态
				grade = 0,		%%级别
				subarea = 0,		%%分区
				subarea_pid = 0,	%%分区pid
				scene_subarea=0,       %%分区场景id
				auto_id = 0,		%%配对唯一id
				member = [],			%%玩家列表[{Pid,PlayerId}]
				final = 0,			%%决赛标记
				is_end = 0,			%%战斗是否结束
				shadow = [],			%%分身id列表
				view = []
			   }).

%%
%% Local Functions
%%

start([Times,Grade,Subarea,State,SceneId,SubareaPid,SbuareaSceneId,Member,AutoId,Final,Round,ViewBag]) ->
    gen_server:start(?MODULE, [Times,Grade,Subarea,State,SceneId,SubareaPid,SbuareaSceneId,Member,AutoId,Final,Round,ViewBag], []).

%%停止服务
stop() ->
    gen_server:call(?MODULE, stop).

init([Times,Grade,Subarea,Status,SceneId,SubareaPid,SbuareaSceneId,Member,AutoId,Final,Round,ViewBag]) ->
    process_flag(trap_exit, true),
	Self = self(),
	SceneProcessName = misc:create_process_name(scene_p, [SceneId, 0]),
	misc:register(global, SceneProcessName, Self),
	%% 复制场景
    lib_scene:copy_scene(SceneId, 740),
	misc:write_monitor_pid(Self, ?MODULE, {740}),
	erlang:send_after(105*1000,Self,{'FIGHT_FINISH'}),
	erlang:send_after(1*1000, Self, {'NOTICE_FIGHT',Member}),
	if Status >=3->
		erlang:send_after(2*1000, Self, {'NOTICE_VIEW'});
	   true->skip
	end,
	State = #state{
				   times = Times,
				   round= Round,
				   subarea = Subarea,
				   subarea_pid = SubareaPid,
				   scene_subarea = SbuareaSceneId,
				   scene_self=SceneId,
				   status = Status,
				   grade=Grade,
				   member = Member,
				   auto_id = AutoId,
				   final = Final,
				   view = ViewBag
				  },
    {ok,State}.

%% 统一模块+过程调用(call)
handle_call({apply_call, Module, Method, Args}, _From, State) ->
%% 	?DEBUG("mod_war2_fight_apply_call: [~p/~p/~p]", [Module, Method, Args]),	
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_war2_fight_apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
			 error;
		 DataRet -> DataRet
	end,
    {reply, Reply, State};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

%% 统一模块+过程调用(cast)
handle_cast({apply_cast, Module, Method, Args}, State) ->
%% 	?DEBUG("mod_war2_fight_apply_cast: [~p/~p/~p]", [Module, Method, Args]),	
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_war2_fight_apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
			 error;
		 _ -> ok
	end,
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

handle_cast({'CLOSE'},State)->
	back_to_rest_scene(State#state.member,State#state.subarea_pid,State#state.scene_subarea),
	back_to_view_scene(State#state.view),
	{stop, normal, State};

%%战斗结果
handle_cast({'WAR2_FIGHT_RES',[WinnerId1,WinnerName,LoserId1,LoserName]},State)->
	if State#state.is_end /= 1->
		   WinnerId = real_id(State,WinnerId1),
		   LoserId = real_id(State,LoserId1),		   
		   if State#state.status == 2->
				  tryout_result_win(State#state.subarea_pid,WinnerId,LoserName),
				  tryout_result_failed(LoserId,WinnerName),
				  ok;
			  State#state.status >=3 andalso State#state.status =<  6->
				  elimination_result(State#state.subarea_pid,State#state.auto_id,WinnerId,WinnerName,LoserId,LoserName,State#state.status,2,State#state.grade,State#state.round);
			  State#state.status == 7->
				  if State#state.final == 1->
						 final_result(State#state.subarea_pid,State#state.auto_id,WinnerId,WinnerName,LoserId,LoserName,State#state.status,State#state.grade,State#state.round);
					 true->
						 elimination_result(State#state.subarea_pid,State#state.auto_id,WinnerId,WinnerName,LoserId,LoserName,State#state.status,2,State#state.grade,State#state.round)
				  end;
			  true->skip
		   end;
	   true->skip
	end,
	erlang:send_after(10*1000, self(), {'CLOSE'}),
	{noreply,State#state{is_end=1}};

%%分身死亡
handle_cast({'SHADOW_DIE',[LoserId,LoserName]},State)->
	if State#state.is_end /= 1->
		   case get_winner_id(State#state.member,LoserId) of
			   false->skip;
			   {WinnerId,WinnerName}->
				   if State#state.status == 2->
						  tryout_result_win(State#state.subarea_pid,WinnerId,LoserName),
						  tryout_result_failed(LoserId,WinnerName),
						  ok;
					  State#state.status >=3 andalso State#state.status =<  6->
						  elimination_result(State#state.subarea_pid,State#state.auto_id,WinnerId,WinnerName,LoserId,LoserName,State#state.status,2,State#state.grade,State#state.round);
					  State#state.status == 7->
						  if State#state.final == 1->
								 final_result(State#state.subarea_pid,State#state.auto_id,WinnerId,WinnerName,LoserId,LoserName,State#state.status,State#state.grade,State#state.round);
							 true->
								 elimination_result(State#state.subarea_pid,State#state.auto_id,WinnerId,WinnerName,LoserId,LoserName,State#state.status,2,State#state.grade,State#state.round)
						  end;
					  true->skip
				   end,
				   erlang:send_after(10*1000, self(), {'CLOSE'})
		   end;
	   true->skip
	end,
	{noreply,State#state{is_end=1}};

%%一方玩家下线，判另一方赢
handle_cast({'WAR2_OFFLINE',[PlayerId1,Nickname]},State)->
	if State#state.is_end /= 1->
		   PlayerId = real_id(State,PlayerId1),
		   if State#state.status == 2->
				  offline_result(State#state.subarea_pid,State#state.member,PlayerId,Nickname),
				  NewMember = lists:keydelete(PlayerId, 2, State#state.member),
				  NewState = State#state{member=NewMember};
			  State#state.status >= 3 andalso State#state.status =< 6->
				  offline_elimination(State,PlayerId,Nickname,2),
				  NewMember = lists:keydelete(PlayerId, 2, State#state.member),
				  NewState = State#state{member=NewMember};
			  State#state.status == 7->
				  if State#state.final ==1->
						 offline_final(State,PlayerId,Nickname),
						 NewMember = lists:keydelete(PlayerId, 2, State#state.member),
						 NewState = State#state{member=NewMember};
					 true->
						 offline_elimination(State,PlayerId,Nickname,2),
						 NewMember = lists:keydelete(PlayerId, 2, State#state.member),
						 NewState = State#state{member=NewMember}
				  end;
			  true->
				  NewState=State
		   end;
	   true->
		   NewState=State
	end,
	erlang:send_after(10*1000, self(), {'CLOSE'}),
	{noreply,NewState#state{is_end=1}};

%%玩家逃跑`
handle_cast({'ESCAPE',[Pid,PlayerId1,Nickname,CarryMark]},State)->
	if State#state.is_end /= 1->
		   PlayerId = real_id(State,PlayerId1),
		   case CarryMark of
			   29->
				   NewState=view_to_rest(Pid,PlayerId,State);
			   _->
				   if State#state.status == 2->
						  offline_result(State#state.subarea_pid,State#state.member,PlayerId,Nickname),
						  NewMember = lists:keydelete(PlayerId, 2, State#state.member),
						  NewState = State#state{member=NewMember};
					  State#state.status >= 3 andalso State#state.status =< 6->
						  offline_elimination(State,PlayerId,Nickname,2),
						  NewMember = lists:keydelete(PlayerId, 2, State#state.member), 
						  NewState = State#state{member=NewMember};
					  State#state.status == 7->
						  if State#state.final ==1->
								 offline_final(State,PlayerId,Nickname),
								 NewMember = lists:keydelete(PlayerId, 2, State#state.member),
								 NewState = State#state{member=NewMember};
							 true->
								 offline_elimination(State,PlayerId,Nickname,2),
								 NewMember = lists:keydelete(PlayerId, 2, State#state.member),
								 NewState = State#state{member=NewMember}
						  end;
					  true->
						  NewState=State
				   end,
				   gen_server:cast(Pid,{'CHANGE_WAR2_SCENE',[State#state.subarea_pid,State#state.scene_subarea,730,22,54]}),
				   erlang:send_after(10*1000, self(), {'CLOSE'})
		   end;
	   true->
		   NewState=State
	end,
	if CarryMark == 29->Is_end=0;
	   true->Is_end=1
	end,
	{noreply,NewState#state{is_end=Is_end}};

%%玩家请求返回休息区
handle_cast({'REQUST_TO_SUBAREA',[Pid]},State)->
	if State#state.is_end /= 0->
		   case lists:keyfind(Pid, 1, State#state.member) of
			   false->
				   NewMember = State#state.member;
			   _->
				   gen_server:cast(Pid,{'CHANGE_WAR2_SCENE',[State#state.subarea_pid,State#state.scene_subarea,730,22,54]}),
				   NewMember = lists:keydelete(Pid, 1, State#state.member)
		   end;
	   true->
		   NewMember = State#state.member
	end,
	{noreply,State#state{member=NewMember}};


handle_cast(_MSg,State)->
	 {noreply, State}.

%%通知玩家进入战场
handle_info({'NOTICE_FIGHT',[PlayerInfo1,PlayerInfo2]},State)->
	Self = self(),
	enter_fight(PlayerInfo1,Self,State#state.scene_self,9,26),
	enter_fight(PlayerInfo2,Self,State#state.scene_self,15,19),
	{noreply,State};

%%通知观战者进入
handle_info({'NOTICE_VIEW'},State)->
	FightBag = [PlayerId||{_,PlayerId,_}<-State#state.member],
	NewView = view_enter(State#state.view,FightBag,self(),State#state.scene_self,10,10,29,[]),
	{noreply,State#state{view=NewView}};

%%战斗自动结束
handle_info({'FIGHT_FINISH'},State)->
	if State#state.status >= 2 andalso State#state.status =< 7 andalso State#state.is_end /=1 ->
		   fight_finish(State);
	   true->skip
	end,
	erlang:send_after(10*1000, self(), {'CLOSE'}),
	{noreply,State};

handle_info({'SHADOW',[PlayerId,ShadowId]},State)->
	Data = {PlayerId,ShadowId},
	case lists:keyfind(PlayerId, 1,State#state.shadow ) of
		false->
			Shadow = [Data|State#state.shadow];
		_->
			Shadow = lists:keyreplace(PlayerId, 1, State#state.shadow, {PlayerId,ShadowId})
	end,
	{noreply,State#state{shadow=Shadow}};

handle_info({'CLOSE'},State)->
	back_to_rest_scene(State#state.member,State#state.subarea_pid,State#state.scene_subarea),
	back_to_view_scene(State#state.view),
	{stop, normal, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, State) ->
	misc:delete_monitor_pid(self()),
	spawn(fun()-> lib_scene:clear_scene(State#state.scene_self) end),
	ok.

code_change(_OldVsn, State, _Extra)->
    {ok, State}. 

real_id(State,PlayerId)->
	case lists:keyfind(PlayerId, 2, State#state.shadow) of
		false-> PlayerId;
		{P,_}->P
	end.

%%进入战斗区
enter_fight({Pid,PlayerId,_},ScenePid,SceneId,X,Y)->
	case misc:is_process_alive(Pid) of
		true->
			gen_server:cast(Pid,{'CHANGE_WAR2_SCENE',[ScenePid,SceneId,740,X,Y]});
		false->
			catch create_shadow(PlayerId,SceneId,X,Y)  
	end. 

create_shadow(PlayerId,SceneId,X,Y)->
	ShadowId = lib_war2:create_shadow(PlayerId,SceneId,X, Y),
	self()!{'SHADOW',[PlayerId,ShadowId]},
	ok.


%%观战者进入State#state.view,FightBag,Self,State#state.scene_self,15,19,28
view_enter([],_,_,_,_,_,_,NewView)->
	NewView;
view_enter([{ViewId,FightId}|ViewBag],FightBag,ScenePid,SceneId,X,Y,Mark,NewView)->
	case lists:member(FightId,FightBag) of
		false->
			view_enter(ViewBag,FightBag,ScenePid,SceneId,X,Y,Mark,NewView);
		true->
			case lib_player:get_player_pid(ViewId) of
				[] ->
					view_enter(ViewBag,FightBag,ScenePid,SceneId,X,Y,Mark,NewView);
				Pid ->
					gen_server:cast(Pid,{'WAR2_VIEW_SCENE',[ScenePid,SceneId,740,X,Y,Mark]}),
					view_enter(ViewBag,FightBag,ScenePid,SceneId,X,Y,Mark,[ViewId|NewView])
			end
	end.
		

get_winner_id([],_)->false;
get_winner_id([{_,WinnerId,Name}|Member],PlayerId)->
	if WinnerId == PlayerId->
		get_winner_id(Member,PlayerId);
	   true->{WinnerId,Name}
	end.

%%玩家下线
offline_result(_SubareaPid,[],_PlayerId,_LoserName)->skip;
offline_result(SubareaPid,[{_Pid,FighterId,_}|Member],PlayerId,LoserName)->
	if FighterId == PlayerId ->skip;
	   true->
		    tryout_result_win(SubareaPid,FighterId,LoserName)
	end,
	offline_result(SubareaPid,Member,PlayerId,LoserName).
		   
%%场景关闭，战斗未结束
%%判断胜负
check_win(PlayerIdA,PlayerIdB)->
	HpA =  case lib_player:get_online_info_fields(PlayerIdA, [hp, hp_lim]) of
			   [AHp,AMaxHp]->AHp / AMaxHp;
			   _-> 0
		   end,
	HpB =  case lib_player:get_online_info_fields(PlayerIdB, [hp, hp_lim]) of
			   [BHp,BMaxHp]->BHp / BMaxHp;
			   _-> 0
		   end,
			   
	if HpA > HpB->PlayerIdA;
	   HpB > HpA -> PlayerIdB;
	   true->
		   BattValueA = get_player_batt_value(PlayerIdA),
		   BattValueB = get_player_batt_value(PlayerIdB),
		   if BattValueA > BattValueB ->PlayerIdA;
			  true-> PlayerIdB
		   end
	end.

fight_finish(State)->
	Len = length(State#state.member),
	if Len >= 2->
		   [{_PidA,PlayerIdA,NickNameA}|NewMember] = State#state.member,
		   [{_PidB,PlayerIdB,NickNameB}|_NewMember1] = NewMember,
			WinMember = check_win(PlayerIdA,PlayerIdB),
		   if WinMember == PlayerIdA->
				  %%选拔赛
				  if State#state.status == 2->
						 tryout_result_win(State#state.subarea_pid,PlayerIdA,NickNameB),
						 tryout_result_failed(PlayerIdB,NickNameA);
					 %%淘汰赛
					 State#state.status >= 3 andalso State#state.status =< 6->
						 elimination_result(State#state.subarea_pid,State#state.auto_id,PlayerIdA,NickNameA,PlayerIdB,NickNameB,State#state.status,2,State#state.grade,State#state.round);
					 State#state.status == 7->
						 if State#state.final == 1->
								final_result(State#state.subarea_pid,State#state.auto_id,PlayerIdA,NickNameA,PlayerIdB,NickNameB,State#state.status,State#state.grade,State#state.round);
							true->
								elimination_result(State#state.subarea_pid,State#state.auto_id,PlayerIdA,NickNameA,PlayerIdB,NickNameB,State#state.status,2,State#state.grade,State#state.round)
						 end;
					 true->skip
				  end;
			  true->
				  if State#state.status == 2->
						 tryout_result_win(State#state.subarea_pid,PlayerIdB,NickNameA),
						 tryout_result_failed(PlayerIdA,NickNameB);
					 State#state.status >=3 andalso State#state.status =< 6 ->
						 elimination_result(State#state.subarea_pid,State#state.auto_id,PlayerIdB,NickNameB,PlayerIdA,NickNameA,State#state.status,2,State#state.grade,State#state.round);
					 State#state.status == 7->
						 if State#state.final == 1->
								final_result(State#state.subarea_pid,State#state.auto_id,PlayerIdA,NickNameA,PlayerIdB,NickNameB,State#state.status,State#state.grade,State#state.round);
							true->
								elimination_result(State#state.subarea_pid,State#state.auto_id,PlayerIdA,NickNameA,PlayerIdB,NickNameB,State#state.status,2,State#state.grade,State#state.round)
						 end;
					 true->skip
				  end
		   end;
	   Len == 1 ->
		   [{_PidA,PlayerIdA,NickNameA}|_NewMember] = State#state.member,
		   if State#state.status == 2->
				  tryout_result_win(State#state.subarea_pid,PlayerIdA,<<>>);
			  State#state.status >= 3 andalso State#state.status =< 6->
				  offline_elimination(State,PlayerIdA,NickNameA,2);
			  true->skip
		   end;
	   true->
		   skip
	end.
	
	
%%获取玩家战斗力
get_player_batt_value(PlayerId)->
	case lib_war2:ets_select_war2_record(PlayerId) of
		[]->0;
		[R]->
			R#ets_war2_record.batt_value
	end.


%%选拔赛胜利者
tryout_result_win(ScenePid,PlayerId,LoserName)->
	case lib_war2:ets_select_war2_record(PlayerId) of
		[]->
			Wins = 1;
		[Record]->
			Wins = Record#ets_war2_record.wins+1,
			NewRecord = Record#ets_war2_record{wins=Wins},
			lib_war2:ets_update_war2_record(NewRecord),
			db_agent:update_war2_record([{wins,1,add}], [{pid,PlayerId}]),
			if Wins >= 10 andalso Record#ets_war2_record.offtrack /= 1->
				   gen_server:cast(ScenePid, {'TRYOUT_WINER',[PlayerId]});
			   true->skip
			end
	end,
	{ok,BinData} = pt_45:write(45104, [1,LoserName,Wins]),
	lib_send:send_to_uid(PlayerId, BinData),
	ok.

%%选拔赛失败者
tryout_result_failed(PlayerId,WinnerName)->
	case lib_war2:ets_select_war2_record(PlayerId) of
		[]->
			Wins = 1;
		[Record]->
			Wins = Record#ets_war2_record.wins
	end,
	{ok,BinData} = pt_45:write(45104, [0,WinnerName,Wins]),
	lib_send:send_to_uid(PlayerId, BinData),
	ok.

%%淘汰赛PK结果处理
elimination_result(ScenePid,AutoId,WinnerId,WinnerName1,LoserId,LoserName1,State,MaxWin,_Grade,Round)->
	case lib_war2:ets_select_war2_elimination(WinnerId)of
		[]->
			WinPlatform = <<>>,
			WinSn=0,
			WinnerName = WinnerName1,
			NewGrade = 0,
			WinnerWins=1;
		[WinnerR]->
			WinnerWins = WinnerR#ets_war2_elimination.wins+1,
			WinPlatform = WinnerR#ets_war2_elimination.platform,
			WinnerName = WinnerR#ets_war2_elimination.nickname,
			WinSn=WinnerR#ets_war2_elimination.sn,
			NewGrade= WinnerR#ets_war2_elimination.grade,
			if WinnerWins >= MaxWin andalso State /=7->
				   NewWinnerR = WinnerR#ets_war2_elimination{state=State+1,wins=0};
			   WinnerWins >= MaxWin andalso State ==7->
				   NewWinnerR = WinnerR#ets_war2_elimination{champion=3,wins=0};
			   true->
				   NewWinnerR = WinnerR#ets_war2_elimination{wins=WinnerWins}
			end,
			lib_war2:ets_update_war2_elimination(NewWinnerR),
			db_agent:update_war2_elimination([{champion,NewWinnerR#ets_war2_elimination.champion},{state,NewWinnerR#ets_war2_elimination.state},{wins,NewWinnerR#ets_war2_elimination.wins}], [{pid,NewWinnerR#ets_war2_elimination.pid}]),
			ok
	end,
	case lib_war2:ets_select_war2_elimination(LoserId) of
		[]->
			LoserPlatform = <<>>,
			LoserSn = 0,
			LoserName = LoserName1,
			LoserWins=0;
		[LoserR]->
			LoserWins = LoserR#ets_war2_elimination.wins,
			LoserPlatform = LoserR#ets_war2_elimination.platform,
			LoserSn = LoserR#ets_war2_elimination.sn,
			LoserName = LoserR#ets_war2_elimination.nickname,
			if WinnerWins >= MaxWin ->
				   Rank = if State == 7-> 
								 spawn(fun()->thirdplace_msg(LoserR#ets_war2_elimination.grade,WinPlatform,WinSn,WinnerName,LoserPlatform,LoserSn,LoserName)end),
								 4;
							 true->0
						  end,
				   NewLoserR = LoserR#ets_war2_elimination{champion=Rank,elimination=0,wins=0},
					lib_war2:ets_update_war2_elimination(NewLoserR),
					db_agent:update_war2_elimination([{champion,Rank},{elimination,0},{wins,0}], [{pid,LoserId}]);
			   true->
				   skip
			end
	end,
	%%战报
	lib_war2:war2_pape_to_remote([NewGrade,State,WinnerId,LoserId,Round+1,WinnerName]),
	gen_server:cast(ScenePid, {'ELIMINATION_RESULT',[AutoId,WinnerId,WinnerWins]}),
	{ok,ABinData} = pt_45:write(45106,[1,WinnerName,WinnerWins,LoserName,LoserWins]),
	lib_send:send_to_uid(WinnerId, ABinData),
	{ok,BBinData} = pt_45:write(45106,[0,WinnerName,WinnerWins,LoserName,LoserWins]),
	lib_send:send_to_uid(LoserId, BBinData),
	if WinnerWins>=MaxWin andalso State  ==7->
		   NowTime = util:unixtime(),
		   elimination_history(WinPlatform,WinSn,WinnerName,[WinnerName,LoserName,8,util:term_to_string(lists:concat([WinnerWins,":",LoserWins])),NowTime]),
		   elimination_history(LoserPlatform,LoserSn,LoserName,[LoserName,WinnerName,8,util:term_to_string(lists:concat([LoserWins,":",WinnerWins])),NowTime]);
	   WinnerWins>=MaxWin ->
		   NowTime = util:unixtime(),
		   elimination_history(WinPlatform,WinSn,WinnerName,[WinnerName,LoserName,State,util:term_to_string(lists:concat([WinnerWins,":",LoserWins])),NowTime]),
		   elimination_history(LoserPlatform,LoserSn,LoserName,[LoserName,WinnerName,State,util:term_to_string(lists:concat([LoserWins,":",WinnerWins])),NowTime]);
	   true->
		   if State == 7->
				  spawn(fun()->third_round_msg(NewGrade,Round,WinnerName,LoserName,WinnerWins,LoserWins)end);
			  true->skip
		   end,
		   skip
	end,
	ok.

%%季军赛播报
third_round_msg(Grade,Round,WinName,LoseName,WinWins,LoserWins)->
	Msg = io_lib:format("<font color='#FEDB4F'>~s</font>季军赛第<font color='#FEDB4F'>~p</font>场比赛结束，<font color='#FEDB4F'>~s</font>力克<font color='#FEDB4F'>~s</font>获得胜利，当前比分为~p：~p！",[grade_to_name(Grade),Round+1,WinName,LoseName,WinWins,LoserWins]),
	lib_chat:broadcast_sys_msg(6,Msg),
	mod_leap_server:remote_server_msg(Msg).

%% 决赛结果
final_result(ScenePid,AutoId,WinnerId,WinnerName1,LoserId,LoserName1,State,_Grade,Round)->
	case lib_war2:ets_select_war2_elimination(WinnerId)of
		[]->
			WinPlatform = <<>>,
			WinSn=0,
			WinnerName = WinnerName1,
			NewGrade = 0,
			WinnerWins=1;
		[WinnerR]->
			WinnerWins = WinnerR#ets_war2_elimination.wins+1,
			WinPlatform = WinnerR#ets_war2_elimination.platform,
			WinSn=WinnerR#ets_war2_elimination.sn,
			WinnerName = WinnerR#ets_war2_elimination.nickname,
			NewGrade = WinnerR#ets_war2_elimination.grade,
			if WinnerWins >= 2 ->
				   ChampionData =  [WinnerR#ets_war2_elimination.nickname,
									WinnerR#ets_war2_elimination.career,
									WinnerR#ets_war2_elimination.sex,
									WinnerR#ets_war2_elimination.platform,
									WinnerR#ets_war2_elimination.sn,
									WinnerR#ets_war2_elimination.grade,
									0,
									util:unixtime()],
				   elimination_champion(ChampionData),
				   NewWinnerR = WinnerR#ets_war2_elimination{champion =1};
			   true->
				   NewWinnerR = WinnerR#ets_war2_elimination{wins=WinnerWins}
			end,
			lib_war2:ets_update_war2_elimination(NewWinnerR),
			db_agent:update_war2_elimination([{champion,NewWinnerR#ets_war2_elimination.champion},{wins,NewWinnerR#ets_war2_elimination.wins}], [{pid,NewWinnerR#ets_war2_elimination.pid}]),
			ok
	end,
	case lib_war2:ets_select_war2_elimination(LoserId) of
		[]->
			LoserPlatform = <<>>,
			LoserSn = 0,
			LoserName = LoserName1,
			LoserWins=0;
		[LoserR]->
			LoserWins = LoserR#ets_war2_elimination.wins,
			LoserPlatform = LoserR#ets_war2_elimination.platform,
			LoserSn = LoserR#ets_war2_elimination.sn,
			LoserName = LoserR#ets_war2_elimination.nickname,
			if WinnerWins >= 2 ->
				   NewLoserR = LoserR#ets_war2_elimination{elimination=0,champion=2},
					lib_war2:ets_update_war2_elimination(NewLoserR),
					db_agent:update_war2_elimination([{elimination,0},{champion,2}], [{pid,LoserId}]),
				   spawn(fun()->champion_msg(WinPlatform,WinSn,WinnerName,LoserR#ets_war2_elimination.platform,LoserR#ets_war2_elimination.sn,LoserName,LoserR#ets_war2_elimination.grade)end);
			   true->
				   spawn(fun()->final_round_msg(NewGrade,Round,WinnerName,LoserName,WinnerWins,LoserWins)end),
				   skip
			end
	end,
	%%战报
	lib_war2:war2_pape_to_remote([NewGrade,State,WinnerId,LoserId,Round,WinnerName]),
	gen_server:cast(ScenePid, {'FINAL_RESULT',[AutoId,WinnerId,WinnerWins]}),
	{ok,ABinData} = pt_45:write(45106,[1,WinnerName,WinnerWins,LoserName,LoserWins]),
	lib_send:send_to_uid(WinnerId, ABinData),
	{ok,BBinData} = pt_45:write(45106,[0,WinnerName,WinnerWins,LoserName,LoserWins]),
	lib_send:send_to_uid(LoserId, BBinData),
	if WinnerWins>=2 ->
		   NowTime = util:unixtime(),
		   elimination_history(WinPlatform,WinSn,WinnerName,[WinnerName,LoserName,State,util:term_to_string(lists:concat([WinnerWins,":",LoserWins])),NowTime]),
		   elimination_history(LoserPlatform,LoserSn,LoserName,[LoserName,WinnerName,State,util:term_to_string(lists:concat([LoserWins,":",WinnerWins])),NowTime]);
	   true->skip
	end,
	ok.

final_round_msg(Grade,Round,WinName,LoseName,WinWins,LoserWins)->
	Msg = io_lib:format("<font color='#FEDB4F'>~s</font>决赛第<font color='#FEDB4F'>~p</font>场比赛结束，<font color='#FEDB4F'>~s</font>力克<font color='#FEDB4F'>~s</font>获得胜利，当前比分为~p：~p！",[grade_to_name(Grade),Round,WinName,LoseName,WinWins,LoserWins]),
	lib_chat:broadcast_sys_msg(6,Msg),
	mod_leap_server:remote_server_msg(Msg).

grade_to_name(Grade)->
	case Grade of
		1->"天罡";
		_->"地煞"
	end.

%%同步历史记录
elimination_history(Platform,Sn,Name,Info)->
	lib_war2:elimination_history(Platform,Sn,Name,Info),
	ok.

%%同步冠军数据
%% [Nickname,Career,Sex,Platform,Sn,Grade,Times,Timestamp]
elimination_champion(Data)->
	lib_war2:sync_champion(Data).

%%淘汰赛一方下线
offline_elimination(State,PlayerId,Nickname,MaxWin)->
	offline_elimination_loop(State#state.member,PlayerId,Nickname,State,MaxWin).

offline_elimination_loop([],_PlayerId,_NickName,_State,_MaxWin)->ok;
offline_elimination_loop([{_Pid,WinnerId,WinnerName}|PlayerInfo],PlayerId,NickName,State,MaxWin)->
	if WinnerId == PlayerId->skip;
	   true->
		   case lib_war2:ets_select_war2_elimination(WinnerId) of
			   []->skip;
			   [WinnerR]->
				   Wins = WinnerR#ets_war2_elimination.wins+1,
				   if Wins >= MaxWin andalso State#state.status /=7->
						  NewWinnerR = WinnerR#ets_war2_elimination{state=State#state.status+1,wins=0};
					  Wins >= MaxWin andalso State#state.status ==7->
						  NewWinnerR = WinnerR#ets_war2_elimination{champion=3,wins=0};
					  true->
						  NewWinnerR = WinnerR#ets_war2_elimination{wins=Wins}
				   end,
				   lib_war2:ets_update_war2_elimination(NewWinnerR),
				   db_agent:update_war2_elimination([{champion,NewWinnerR#ets_war2_elimination.champion},{state,NewWinnerR#ets_war2_elimination.state},{wins,NewWinnerR#ets_war2_elimination.wins}], [{pid,NewWinnerR#ets_war2_elimination.pid}]),
%% 				   {LP,LS,LoserWins} = get_loser_wins(PlayerId),
				   case lib_war2:ets_select_war2_elimination(PlayerId) of
					   []->
						   LP = null,
						   LS = 0,
						   LoserWins=0;
					   [LoserR]->
						   LoserWins = LoserR#ets_war2_elimination.wins,
						   LP = LoserR#ets_war2_elimination.platform,
						   LS = LoserR#ets_war2_elimination.sn,
						   if Wins >= MaxWin ->
								  Rank = if State == 7-> 
												4;
											true->0
										 end,
								  NewLoserR = LoserR#ets_war2_elimination{champion=Rank,elimination=0,wins=0},
								  lib_war2:ets_update_war2_elimination(NewLoserR),
								  db_agent:update_war2_elimination([{champion,Rank},{elimination,0},{wins,0}], [{pid,PlayerId}]);
							  true->
								  skip
						   end
				   end,
				   %%战报
					lib_war2:war2_pape_to_remote([WinnerR#ets_war2_elimination.grade,State#state.status,WinnerId,PlayerId,State#state.round+1,WinnerName]),
				   NowTime = util:unixtime(),
				   if Wins >= MaxWin andalso State#state.status==7->
						  elimination_history(LP,LS,NickName,[NickName,WinnerName,8,util:term_to_string(lists:concat([NickName,":",Wins])),NowTime]),
						  elimination_history(WinnerR#ets_war2_elimination.platform,WinnerR#ets_war2_elimination.sn,WinnerName,[WinnerName,NickName,8,util:term_to_string(lists:concat([Wins,":",LoserWins])),NowTime]),
						  spawn(fun()->thirdplace_msg(WinnerR#ets_war2_elimination.grade,WinnerR#ets_war2_elimination.platform,WinnerR#ets_war2_elimination.sn,WinnerName,LP,LS,NickName)end);
					  Wins >= MaxWin ->
						  elimination_history(LP,LS,NickName,[NickName,WinnerName,State#state.status,util:term_to_string(lists:concat([NickName,":",Wins])),NowTime]),
						  elimination_history(WinnerR#ets_war2_elimination.platform,WinnerR#ets_war2_elimination.sn,WinnerName,[WinnerName,NickName,State#state.status,util:term_to_string(lists:concat([Wins,":",LoserWins])),NowTime]),
						  ok;
					  true->
						  if State#state.status == 7->
								 spawn(fun()->third_round_msg(WinnerR#ets_war2_elimination.grade,State#state.round,WinnerName,NickName,Wins,LoserWins)end);
							 true->skip
						  end,
						  skip
				   end,
				   gen_server:cast(State#state.subarea_pid, {'ELIMINATION_RESULT',[State#state.auto_id,WinnerId,Wins]}),
				   {ok,ABinData} = pt_45:write(45106,[1,WinnerName,Wins,NickName,LoserWins]),
				   lib_send:send_to_uid(WinnerId, ABinData),
				   ok
		   end,
		   ok
	end,
	offline_elimination_loop(PlayerInfo,PlayerId,NickName,State,MaxWin).

%%冠军战一方下线
offline_final(State,PlayerId,Nickname)->
	offline_final_loop(State#state.member,PlayerId,Nickname,State).

offline_final_loop([],_PlayerId,_NickName,_State)->ok;
offline_final_loop([{_Pid,WinnerId,WinnerName}|PlayerInfo],PlayerId,NickName,State)->
	if WinnerId == PlayerId->skip;
	   true->
		   case lib_war2:ets_select_war2_elimination(WinnerId) of
			   []->skip;
			   [WinnerR]->
				   Wins = WinnerR#ets_war2_elimination.wins+1,
				   if Wins >= 2 ->
						  ChampionData =  [WinnerR#ets_war2_elimination.nickname,
										   WinnerR#ets_war2_elimination.career,
										   WinnerR#ets_war2_elimination.sex,
										   WinnerR#ets_war2_elimination.platform,
										   WinnerR#ets_war2_elimination.sn,
										   WinnerR#ets_war2_elimination.grade,
										   0,
										   util:unixtime()],
						  elimination_champion(ChampionData),
						  NewWinnerR = WinnerR#ets_war2_elimination{champion=1};
					  true->
						  NewWinnerR = WinnerR#ets_war2_elimination{wins=Wins}
				   end,
				   lib_war2:ets_update_war2_elimination(NewWinnerR),
				   db_agent:update_war2_elimination([{champion,NewWinnerR#ets_war2_elimination.champion},{wins,NewWinnerR#ets_war2_elimination.wins}], [{pid,NewWinnerR#ets_war2_elimination.pid}]),
				   
				   case lib_war2:ets_select_war2_elimination(PlayerId) of
					   []->
						   LP = null,
						   PS = 0,
						   LoserWins=0;
					   [LoserR]->
						   LoserWins = LoserR#ets_war2_elimination.wins,
						   LP = LoserR#ets_war2_elimination.platform,
						   PS = LoserR#ets_war2_elimination.sn,
						   if Wins >= 2 ->
								  NewLoserR = LoserR#ets_war2_elimination{elimination=0,champion=2},
								  lib_war2:ets_update_war2_elimination(NewLoserR),
								  db_agent:update_war2_elimination([{elimination,0},{champion,2}], [{pid,PlayerId}]);
							  true->
								  skip
						   end
				   end,
				    %%战报
					lib_war2:war2_pape_to_remote([WinnerR#ets_war2_elimination.grade,State#state.status,WinnerId,PlayerId,State#state.round,WinnerName]),
				   if Wins >= 2->
						  %% 						  {LP,PS,LoserWins} = get_loser_wins(PlayerId),
						  NowTime=util:unixtime(),
						  spawn(fun()->champion_msg(WinnerR#ets_war2_elimination.platform,WinnerR#ets_war2_elimination.sn,WinnerName,LP,PS,NickName,WinnerR#ets_war2_elimination.grade)end),
						  elimination_history(WinnerR#ets_war2_elimination.platform,WinnerR#ets_war2_elimination.sn,WinnerName,[WinnerName,NickName,State#state.status,util:term_to_string(lists:concat([Wins,":",LoserWins])),NowTime]),
						  elimination_history(LP,PS,NickName,[NickName,WinnerName,State,util:term_to_string(lists:concat([LoserWins,":",Wins])),NowTime]);
					  ok;
					  true->
						  %% 						  {_LP,_PS,LoserWins} = get_loser_wins(PlayerId),
						  spawn(fun()->final_round_msg(WinnerR#ets_war2_elimination.grade,State#state.round,WinnerName,NickName,Wins,LoserWins)end)
				   end,
				   gen_server:cast(State#state.subarea_pid, {'FINAL_RESULT',[State#state.auto_id,WinnerId,Wins]}),
				   {ok,ABinData} = pt_45:write(45106,[1,WinnerName,Wins,NickName,LoserWins]),
				   lib_send:send_to_uid(WinnerId, ABinData)
		   end,
		   ok
	end,
	offline_final_loop(PlayerInfo,PlayerId,NickName,State).



champion_msg(WinPlatform,WinSn,WinName,LoserPlatform,LoserSn,LoserName,Grade)->
	case Grade of
		1->
			%% 			在封神争霸决赛中，来自（平台）（服号）的XXXX击败了来自（平台）（服号）的XXXX，获得本届封神争霸的冠军！远古无双，舍我其谁！>>>查看赛程<<<
			case LoserPlatform of
				null->
					Content = io_lib:format("<font color='#FEDB4F'>~s</font>平台<font color='#FEDB4F'>~p</font>服的<font color='#FEDB4F'>~s</font>获得本届封神争霸的<font color='#FEDB4F'>天罡冠军</font>！远古无双，舍我其谁！<a href='event:5'><font color='#00FF00'><u>》》查看赛程《《</u></font></a>", 
											[lib_war:platform(WinPlatform),WinSn,WinName]);
				_->
					Content = io_lib:format("在<font color='#FEDB4F'>封神争霸决赛</font>中，来自<font color='#FEDB4F'>~s</font>平台<font color='#FEDB4F'>~p</font>服的<font color='#FEDB4F'>~s</font>击败了来自<font color='#FEDB4F'>~s</font>平台<font color='#FEDB4F'>~p</font>服的<font color='#FEDB4F'>~s</font>，获得本届封神争霸的<font color='#FEDB4F'>天罡冠军</font>！远古无双，舍我其谁！<a href='event:5'><font color='#00FF00'><u>》》查看赛程《《</u></font></a>",
											 [lib_war:platform(WinPlatform),WinSn,WinName,lib_war:platform(LoserPlatform),LoserSn,LoserName])
			end;
		_->
			case LoserPlatform of
				null->
					Content = io_lib:format("<font color='#FEDB4F'>~s</font>平台<font color='#FEDB4F'>~p</font>服的<font color='#FEDB4F'>~s</font>获得本届封神争霸的<font color='#FEDB4F'>地煞冠军</font>！<a href='event:5'><font color='#00FF00'><u>》》查看赛程《《</u></font></a>", 
											[lib_war:platform(WinPlatform),WinSn,WinName]);
				_->
					Content = io_lib:format("在<font color='#FEDB4F'>封神争霸决赛</font>中，来自<font color='#FEDB4F'>~s</font>平台<font color='#FEDB4F'>~p</font>服的<font color='#FEDB4F'>~s</font>击败了来自<font color='#FEDB4F'>~s</font>平台<font color='#FEDB4F'>~p</font>服的<font color='#FEDB4F'>~s</font>，获得本届封神争霸的<font color='#FEDB4F'>地煞冠军</font>！<a href='event:5'><font color='#00FF00'><u>》》查看赛程《《</u></font></a>", 
											[lib_war:platform(WinPlatform),WinSn,WinName,lib_war:platform(LoserPlatform),LoserSn,LoserName])
			end
	end,
	lib_chat:broadcast_sys_msg(6,Content),
	mod_leap_server:remote_server_msg(Content).


thirdplace_msg(Grade,WinPlatform,WinSn,WinName,LPlatform,LSn,LoserName)->
	%%在封神争霸的季军赛决赛中，来自（平台）（服号）的XXXX击败了来自（平台）（服号）的XXXX，获得本届封神争霸的季军！>>>查看赛程<<<
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

%%返回休息区
back_to_rest_scene([],_ScenePid,_SceneId)->ok;
back_to_rest_scene([{Pid,_PlayerId,_}|Member],ScenePid,SceneId)->
	 case misc:is_process_alive(Pid) of
		true->
			gen_server:cast(Pid,{'CHANGE_WAR2_SCENE',[ScenePid,SceneId,730,22,54]});
		 false->skip
	end,
	back_to_rest_scene(Member,ScenePid,SceneId).

%%观战者返回等待区
back_to_view_scene(View)->
	case catch gen_server:call(mod_war2_supervisor:get_mod_war2_supervisor_pid(), {'VIEW_SCENE'}) of
		{ok,[undefined,undefined]}->
			back_to_view_scene_loop(View,undefined,undefined);
		{ok,[Pid,SceneId]}-> 
			back_to_view_scene_loop(View,SceneId,Pid)
	end.

back_to_view_scene_loop([],_SceneId,_ScenePid)->
	ok;
back_to_view_scene_loop([PlayerId|View],SceneId,ScenePid)->
	case lib_player:get_online_info(PlayerId) of
		[]->skip;
		Player->
			%% 			gen_server:cast(Pid,{'WAR2_VIEW_SCENE',[ScenePid,SceneId,740,X,Y,Mark]}),
			if SceneId == undefined ->
				   case Player#player.other#player_other.war2_scene of
					   []->skip;
					   [{NewSceneId,NewScenePid}]->
						   gen_server:cast(Player#player.other#player_other.pid,{'WAR2_VIEW_SCENE',[NewScenePid,NewSceneId,730,22,54,0]})
				   end;
			   true->
				   gen_server:cast(Player#player.other#player_other.pid,{'WAR2_VIEW_SCENE',[ScenePid,SceneId,730,22,54,0]})
			end
	end,
	back_to_view_scene_loop(View,SceneId,ScenePid).

%%观战者请求返回休息区
view_to_rest(Pid,PlayerId,State)->
	case catch gen_server:call(mod_war2_supervisor:get_mod_war2_supervisor_pid(), {'VIEW_SCENE'}) of
		{ok,[undefined,undefined]}->State;
		{ok,[ScenePid,SceneId]}-> 
			gen_server:cast(Pid,{'WAR2_VIEW_SCENE',[ScenePid,SceneId,730,22,54,0]}),
			NewView = lists:delete(PlayerId, State#state.view),
			State#state{view=NewView}
	end.