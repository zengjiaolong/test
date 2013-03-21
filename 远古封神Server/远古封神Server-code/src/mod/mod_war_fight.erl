%% Author: Administrator
%% Created: 2011-8-22
%% Description: TODO: 跨服分组战场
-module(mod_war_fight).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").

%%
%% Exported Functions
%% 
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-export([start/1, start_link/1, stop/0]).


-record(state, {
				scene_mark = 0,
				scene = 0,
				pid_wait = undefined,
				scene_wait = 0,
				times = 0,			%%第几届
				level = 0,			%%等级
				max_level = 0,		%%最大等级 
				round = 0,			%%轮次
				battle_id = 0,		%% 战场ID
				blue_platform = 0,	%%蓝方平台
				blue_sn = 0,		%%蓝方服务器id
				blue_point = 0,		%% 蓝方积分
				blue_num = 0,		%% 蓝方人数人数
				red_sn = 0,			%%红方服务器id
				red_platform = 0,	%%红方平台
				red_point = 0, 		%% 红方比分
				red_num = 0,		%% 红方人数
				member = [],		%%参赛人员列表
				buff = 0,			%%气势值
				is_end= 0,			%% 战场是否结束
				state = 0,			%%2准备比赛，3比赛
				timestamp = 0,		%%战场结束时间
				flag_red = 0,		%%红方战旗数量
				flag_red_state = 0,	%%红方战旗状态 (0战旗刷新，1运旗，2提交战旗 )
				flag_red_time = 0,	%%红方战旗刷新时间 
				flag_blue = 0,		%%蓝方战旗数量
				flag_blue_state = 0, %%蓝方战旗状态 (0战旗刷新，1运旗，2提交战旗 )
				flag_blue_time = 0, 	%%蓝方战旗刷新时间
				flag_state = 0,		%%旗状态
				flag_time = 0,		%%旗子刷新时间
				flag_color = 0, 	%%旗子颜色（11红，12蓝）
			   	flag_owner = 0,      %%获得旗子的玩家
				worker_id = 0		%% 进程工作ID
			   }).

-record(competitor,{
					id=0,			%%玩家id
					nickname="",	%%玩家名字
					realm=0,		%%玩家部落
					career= 0,		%%玩家职业
					lv = 0,			%%玩家等级 
					sex = 0,		%%玩家性别
					double_hit = 0,	%%连击数
					title = 0,		%%称号
					max_hit = 0,	%%最大连击
					kill = 0,		%%击杀数
					die = 0,		%%死亡数
					last_die_time = 0,%%最后一次死亡时间
					state=0,		%%状态，1离开
					color = 0,		%%11红方，12蓝方
					point = 0,		%%积分
					att_flag = 0,	%%攻击战旗次数
					total_kill=0,		%%总击杀
				   total_point = 0	%%总加分
				   
				}).
%%
%% API Functions
%%

start([Id,Vs,Times,Lv,MaxLv,Round,PidWait,SceneWait,SceneMark,SceneId]) ->
    gen_server:start(?MODULE, [Id,Vs,Times,Lv,MaxLv,Round,PidWait,SceneWait,SceneMark,SceneId, 0], []).

start_link([Id,Vs,Times,Lv,MaxLv,Round,PidWait,SceneWait,SceneMark,SceneId, WorkerId]) ->
	gen_server:start_link(?MODULE, [Id,Vs,Times,Lv,MaxLv,Round,PidWait,SceneWait,SceneMark,SceneId, WorkerId], []).

%%停止服务
stop() ->
    gen_server:call(?MODULE, stop).


%%
%% Local Functions
%%

init([BattldId,Vs,Times,Lv,MaxLv,Round,PidWait,SceneWait,SceneMark,SceneId, WorkerId]) ->
    process_flag(trap_exit, true),
	Self = self(),
	Scene = SceneId,
	%% 初始战场
	SceneProcessName = misc:create_process_name(scene_p, [Scene, WorkerId]),
	misc:register(global, SceneProcessName, Self),
	if
        WorkerId =:= 0 -> 
			
            %% 复制场景
            lib_scene:copy_scene(Scene, 750),
            misc:write_monitor_pid(Self, ?MODULE, {750}),
            %%创建战场BOSS
        %% 	create_boss(Scene,39,48),
            %% 初始战场成员数据
            [BPlatform,BSn,BNum,RPlatform,RSn,RNum,MemberList] = init_war_member_data(Vs,Times,Round),
            %% 2秒通知进入战场
            erlang:send_after(2*1000, Self, {'NOTICE_ENTER_WAR'}), 
            %%刷新战旗
            FlagHandle = erlang:send_after(3*1000, Self, {'FLUSH_FLAG'}), 
            put(flag,FlagHandle),
        %% 	RedHandle = erlang:send_after(12*000, Self, {'FLUSH_FLAG_RED'}),
        %% 	put(flag_red,RedHandle),
        %% 	BlueHandle = erlang:send_after(12*000, Self, {'FLUSH_FLAG_BLUE'}),
        %% 	put(flag_blue,BlueHandle),
            %%50秒后检查战场状态
            erlang:send_after(60*1000,Self,{'CHECK_STATE'}),
            %% 	erlnag:send_after(10*60*1000,Self,{'FINISH_WAR'}),
            
            %% 启动跨服战场服务进程
            lists:foreach(
                fun(WorkId) ->
                    mod_war_fight:start_link([BattldId,Vs,Times,Lv,MaxLv,Round,PidWait,SceneWait,SceneMark,SceneId, WorkId])
                end,
            lists:seq(1, ?SCENE_WORKER_NUMBER)),
            
            State = #state{
               scene_mark = SceneMark,
               scene = Scene,
               pid_wait = PidWait,
               scene_wait = SceneWait,
               times = Times,
               level = Lv,
               max_level = MaxLv,
               round = Round,
               battle_id = BattldId,
               blue_platform = BPlatform,
               blue_sn = BSn,
               blue_point= 0,
               blue_num = BNum,
               red_platform = RPlatform,
               red_sn = RSn,
               red_point = 0,
               red_num = RNum,
               member = MemberList,
               buff = 30,
               flag_state = 2,
               is_end = 0,
               flag_owner='',
               worker_id = WorkerId
       		};
%% 	io:format("init war >>>>>>>>>~p~n",[[BPlatform,BSn,BNum,RPlatform,RSn,RNum,MemberList]]),
		true ->
			State = #state{
                worker_id = WorkerId			   
            }
	end,
    {ok, State}.

handle_call({apply_call, Module, Method, Args}, _From, State) ->
%% 	?DEBUG("mod_scene_apply_call: [~p/~p/~p]", [Module, Method, Args]),	
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_war_fight_apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
			 error;
		 DataRet -> DataRet
	end,
    {reply, Reply, State};

%%查询复活时间
handle_call({'ReviveTimestamp',PlayerId},_F,State)->
	Time = case lists:keyfind(PlayerId,2,State#state.member) of
			false-> 20;
			Com->
				if Com#competitor.die =< 3->3;
				   Com#competitor.die =< 5->5;
				   Com#competitor.die =< 10->10;
				   Com#competitor.die =< 20->15;
				   true->20
				end
			end,
	 {reply, {ok,Time}, State};

%%查询分组信息
handle_call({'get_color',PlayerId},_F,State)->
	Color = case lists:keyfind(PlayerId,2,State#state.member) of
			false-> 0;
			Com->
				Com#competitor.color
			end,
	 {reply, {ok,[Color,State#state.state]}, State};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.


%%战场死亡
handle_cast({'WAR_DIE',LiveId,LivePid,DieId,DiePid,Flag},State)->
	if State#state.is_end=:= 1 ->
		   NewState = State;
	   true->
			if LiveId =:= DieId ->NewState = State;
			   true->
				   Live = lists:keyfind(LiveId,2,State#state.member),
				   Die = lists:keyfind(DieId,2,State#state.member),
				   if Live =:= false orelse Die =:= false->
						  NewState = State;
					  true->
						  if Live#competitor.color =:= Die#competitor.color ->NewState = State;
							 true->
								 spawn(fun()->title_lose_msg(Live,Die,State) end),
								 NewState1  = competitor_live(LivePid,Live,State,Flag,Die#competitor.nickname),
								 if Flag=:=26->
										gen_server:cast(LivePid, {'WAR_FLAG_MARK',[26]}),
										gen_server:cast(self(),{'LOST_FLAG',[DiePid,Die#competitor.color,Flag]});
									true->skip
								 end,
								 NewState = competitor_die(Die,NewState1),
								 spawn(fun()->fight_info(NewState) end)	,   
								 NewState
						  end
				  end
		   end
	end,
	{noreply,NewState};

%%boss死亡
handle_cast({'BOSS_DIE',[Red,Blue]},State)->
	if Red =:= Blue->
		   NewState = State;
	   Red > Blue->
		   NewState = State#state{red_point = State#state.red_point+500};
	   true->
		   NewState = State#state{blue_point = State#state.blue_point+500}
	end,
	spawn(fun()->fight_info(NewState) end), 
	{noreply,NewState};

%%小怪死亡
handle_cast({'MON_DIE',[Color]},State)->
	case Color of
		11->
			NewState = State#state{red_point = State#state.red_point+5};
		_->
			NewState = State#state{blue_point = State#state.blue_point+5}
	end,
	spawn(fun()->fight_info(NewState) end), 
	{noreply,NewState};

%%玩家进入、离开
handle_cast({'WAR_ENTER_LEAVE',PlayerId,Type,PidSend,Pid,Color,Flag},State)->
	case lists:keyfind(PlayerId, 2, State#state.member) of
		false->
			NewState = State;
		Player->
			Res = case Type of
					  in->
						  gen_server:cast(Pid,{'WAR_DIE_TIMES',Player#competitor.die}),
%% 						  spawn(fun()->fight_info_single(PlayerId,State,PidSend)end),
						  spawn(fun()->finght_time(PidSend,State)end),
						  0;
					  out->
						  if  Flag =:= 26->
								  gen_server:cast(self(),{'LOST_FLAG',[Pid,Color,0]}),
								  ok;
							  true->skip
						  end,
						  1
				  end,
			NewPlayer = Player#competitor{state=Res},
			Member = lists:keyreplace(Player#competitor.id, 2, State#state.member, NewPlayer),
			if Flag =:=26->
				   NewState=State#state{member=Member,flag_color = 0,flag_owner=''},
				   spawn(fun()->fight_info(NewState) end),
				   NewState;
			   true->
					NewState = State#state{member=Member}
			end
	end,
	{noreply,NewState};

%%请求比赛信息
handle_cast({'fight_info',PlayerId,PidSend},State)->
	spawn(fun()->fight_info_single(PlayerId,State,PidSend)end),
	{noreply,State};

%%玩家请求离开
handle_cast({'send_to_rest',PlayerId,Pid},State)->
	case State#state.is_end =:= 1 of
		true->
			case lists:keyfind(PlayerId, 2, State#state.member) of
				false->skip;
				Info->
					gen_server:cast(Pid, {'NOTICE_LEAVE_WAR',State#state.pid_wait,State#state.scene_wait}),
					gen_server:cast(self(),{'WAR_ENTER_LEAVE',PlayerId,out,undefined,undefined,Info#competitor.color,0})
			end;
		false->skip
	end,
	{noreply,State};

%%查看比赛比分
handle_cast({'result',_PlayerId,_PidSend},State)->
	war_reslut(State),
	{noreply,State};

%%查看其他分组比分
handle_cast({'other_result',_PlayerId,PidSend},State)->
	case State#state.is_end=:= 1 of
		true->
			VsBag = lib_war:select_war_vs_by_lv(State#state.level,State#state.round),
			VsInfo = [{Vs#ets_war_vs.platform_a,Vs#ets_war_vs.sn_a,Vs#ets_war_vs.res_a,Vs#ets_war_vs.platform_b,Vs#ets_war_vs.sn_b,Vs#ets_war_vs.res_b}||Vs<-VsBag,Vs#ets_war_vs.sn_a=/=State#state.red_sn,Vs#ets_war_vs.sn_a=/=State#state.blue_sn],
			{ok,BinData} = pt_45:write(45019,[VsInfo]),
			lib_send:send_to_sid(PidSend, BinData);
		false->
			{ok,BinData} = pt_45:write(45019,[[]]),
			lib_send:send_to_sid(PidSend, BinData)
	end,
	{noreply,State};

%%获取战旗
handle_cast({'GET_FLAG',[Pid,PlayerId,NickName,Color,PlayerList]},State)->
	NewState1 = 
	if State#state.is_end=/=1->
		   {NewState,Platform,Sn} = 
			   case Color of
				   11->
					   {Member,Name} = get_flag(State,PlayerId,PlayerList),
					   {State#state{red_point = State#state.red_point+10,flag_state = 1,member=Member,flag_color=11,flag_owner =Name },State#state.red_platform,State#state.red_sn};
				   _->
					    {Member,Name} = get_flag(State,PlayerId,PlayerList),
					   {State#state{blue_point = State#state.blue_point+10,flag_state = 1,member= Member,flag_color=12,flag_owner =Name},State#state.blue_platform,State#state.blue_sn}
			   end,
		   gen_server:cast(Pid, {'WAR_FLAG_MARK',[26]}),
		   %%（队名）的（玩家名）英勇地于万军丛中抢到了战旗！
		   Content = io_lib:format("<font color='#FEDB4F;'>~s</font>平台<font color='#FEDB4F;'>~p</font>服的<font color='#FEDB4F;'>~s</font>英勇地于万军丛中抢到了战旗！",[lib_war:platform(Platform),Sn,NickName]),
		   lib_chat:broadcast_sys_msg(6, Content),
		   spawn(fun()->mod_leap_server:remote_server_msg_by_sn(Platform,Sn,Content)end),
		   spawn(fun()->fight_info(NewState) end),
		   NewState;
	   true->State
	end,
	{noreply,NewState1};

%%提交战旗
handle_cast({'COMMIT_FLAG',[Pid,PlayerId,NickName,Color,Flag]},State)->
	NewState = 
		if State#state.is_end=:= 1 ->State;
		   true->
				case Flag of
					26->
						NowTime = util:unixtime(),
						case NowTime  - State#state.flag_time >= 30 of
							true->
								erlang:send_after(1000,self(),{'FLUSH_FLAG'});
							false->skip
						end,
						case Color of
							11->
								Member = commit_flag(State,PlayerId),
								State#state{red_point = State#state.red_point+30,flag_state = 2,flag_red = State#state.flag_red+1,member = Member,flag_color=0,flag_owner =''};
							12->
								Member = commit_flag(State,PlayerId),
								State#state{blue_point = State#state.blue_point+30,flag_state = 2,flag_blue = State#state.flag_blue+1,member = Member,flag_color=0,flag_owner =''};
							_->State#state{flag_state=2}
						end;
					_->State
				end
		end,
	%5（队名）的（玩家名）成功将战旗运到了红/蓝方战台！
	{Platform,Sn,ColorName} = 
		case Color of
			11->{State#state.red_platform,State#state.red_sn,"红"};
			_->{State#state.blue_platform,State#state.blue_sn,"蓝"}
		end,
	Content = io_lib:format("<font color='#FEDB4F;'>~s</font>平台<font color='#FEDB4F;'>~p</font>服的<font color='#FEDB4F;'>~s</font>成功将战旗运到了~s方战台",[lib_war:platform(Platform),Sn,NickName,ColorName]),
	lib_chat:broadcast_sys_msg(6, Content),
	spawn(fun()->mod_leap_server:remote_server_msg_by_sn(Platform,Sn,Content)end),
	gen_server:cast(Pid, {'WAR_FLAG_MARK',[0]}),
	spawn(fun()->fight_info(NewState) end)	, 
	{noreply,NewState};

%%失去战旗
handle_cast({'LOST_FLAG',[Pid,Color,Flag]},State)->	
	NewState = 
		case Flag of
			26->
				gen_server:cast(Pid, {'WAR_FLAG_MARK',[0]}),
				NewColor = case Color of
							   11->12;
							   _->11
						   end,
				State#state{flag_state=NewColor};
		_->State#state{flag_state=0}
	end,
	{noreply,NewState};

%% 统一模块+过程调用(cast)
handle_cast({apply_cast, Module, Method, Args}, State) ->
%% 	?DEBUG("mod_scene_apply_cast: [~p/~p/~p]", [Module, Method, Args]),	
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_war_fight_apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
			 error;
		 _ -> ok
	end,
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

%%
handle_cast(_MSg,State)->
	 {noreply, State}.

%%刷新战旗
handle_info({'FLUSH_FLAG'},State)->
%% 	io:format("FLUSH_FLAG>>~p/~p~n",[State#state.flag_state,State#state.is_end]),
	misc:cancel_timer(flag),
	NowTime = util:unixtime(),
	NewState = 
		if State#state.is_end =/=1->
			   if State#state.flag_state =:= 2 ->
					  refresh_flag(all,State#state.scene,State#state.flag_red+State#state.flag_blue),
					  State#state{flag_state = 0,flag_time=NowTime};
				  State#state.flag_state =:= 0 ->State#state{flag_time=NowTime};
				  true->
					  case State#state.flag_time + 90 > NowTime of
						  true->State;
						  false->
							  case check_player_flag_all(State#state.member) of
								  true->State;
								  false->
									  IsMonA = lib_mon:is_alive_scene_flag(State#state.scene,42903),
									  IsMonB = lib_mon:is_alive_scene_flag(State#state.scene,42905),
									  if IsMonA==false andalso IsMonB==false->
											 refresh_flag(all,State#state.scene,State#state.flag_red+State#state.flag_blue),
											 State#state{flag_state = 0,flag_time=NowTime};
										 true->State
									  end
							  end
					  end
			   end;
		   true->State
		end,
	TimerHandle = erlang:send_after(30*1000,self(),{'FLUSH_FLAG'}),
	put(flag,TimerHandle),
	{noreply,NewState};

handle_info({'FLUSH_FLAG_RED'},State)->
	misc:cancel_timer(flag_red),
	NowTime = util:unixtime(),
%% 	io:format("FLUSH_FLAG_RED>>>~p~n",[State#state.flag_red_state]),
	NewState = 
		if State#state.flag_red_state =:= 2 ->
			   refresh_flag(red,State#state.scene,State#state.flag_red),
			   State#state{flag_red_state = 0,flag_red_time=NowTime};
		   State#state.flag_red_state =:= 0 ->State#state{flag_red_time=NowTime};
		   true->
			   case State#state.flag_red_time + 90 > NowTime of
					true->State;
					false->
						case check_player_flag(State#state.member,11) of
							true->State;
							false->
								IsMonA = lib_mon:is_alive_scene_flag(State#state.scene,42904),
								IsMonB = lib_mon:is_alive_scene_flag(State#state.scene,42906),
								if IsMonA==false andalso IsMonB==false->
									refresh_flag(red,State#state.scene,State#state.flag_red),
									State#state{flag_red_state = 0,flag_red_time=NowTime};
								   true->State
								end
						end
				end
		end,
	TimerHandle = erlang:send_after(30*1000,self(),{'FLUSH_FLAG_RED'}),
	put(flag_red,TimerHandle),
	{noreply,NewState};

handle_info({'FLUSH_FLAG_BLUE'},State)->
	misc:cancel_timer(flag_blue),
%% 	io:format("FLUSH_FLAG_BLUE>>>~p~n",[State#state.flag_blue_state]),
	NowTime = util:unixtime(),
	NewState = 
		if State#state.flag_blue_state =:= 2 ->
			   refresh_flag(blue,State#state.scene,State#state.flag_blue),
			   State#state{flag_blue_state = 0,flag_blue_time=NowTime};
		    State#state.flag_blue_state =:= 0 ->State#state{flag_blue_time=NowTime};
		   true->
				case State#state.flag_blue_time + 90 > NowTime of
					true->State;
					false->
						case check_player_flag(State#state.member,11) of
							true->State;
							false->
								IsMonA = lib_mon:is_alive_scene_flag(State#state.scene,42903),
								IsMonB = lib_mon:is_alive_scene_flag(State#state.scene,42905),
								if IsMonA==false andalso IsMonB==false->
									refresh_flag(blue,State#state.scene,State#state.flag_blue),
									State#state{flag_blue_state = 0,flag_blue_time=NowTime};
								   true->State
								end
						end
				end
		end,
	TimerHandle = erlang:send_after(30*1000,self(),{'FLUSH_FLAG_BLUE'}),
	put(flag_blue,TimerHandle),
	{noreply,NewState};
%%
%%战场BOSS
handle_info({'BOSS'},State)->
	create_boss(State#state.scene,33,44),
	{noreply,State};

%%通知进入战场
handle_info({'NOTICE_ENTER_WAR'},State)->
	Member = notice_enter_war(State#state.times,State#state.level,State#state.round, State#state.scene, State#state.member, self()),
	spawn(fun()->fight_info(State) end)	, 
	spawn(fun()->start_msg_remote(State#state.times,State#state.max_level,State#state.level,State#state.round,State#state.red_platform,State#state.red_sn,State#state.blue_platform,State#state.blue_sn)end),
	%%20秒后开始战斗 
%% 	erlang:send_after(10*1000, self(), {'WAR_START'}),
	Timestamp = util:unixtime()+10*60,
	{noreply,State#state{timestamp = Timestamp,state = 3,member=Member}};

%%封神大会分组赛正式开始
%% handle_info({'WAR_START'},State)->
%% 	MemberList = notice_start_war(State#state.member,State#state.times,State#state.level,State#state.round),
%% 	spawn(fun()->start_msg_remote(State#state.times,State#state.level,State#state.round,State#state.red_platform,State#state.red_sn,State#state.blue_platform,State#state.blue_sn)end),
%% 	Timestamp = util:unixtime()+9*60+40,
%% 	NewState=State#state{timestamp = Timestamp,state = 3,member = MemberList},
%% 	{noreply,NewState};


%%战台气势
handle_info({'BUFF'},State)->
	if State#state.is_end =/= 1->
			{Buff,_Red,_Blue} = get_buff(State),
			if Buff < 20->
				   Add = (20-Buff),
				   NewState = State#state{buff = Buff,blue_point=Add+State#state.blue_point };
			   Buff< 40->
				   NewState = State#state{buff = Buff};
			   true->
				   Add = (Buff-40),
				   NewState = State#state{buff = Buff,red_point=Add+State#state.red_point }
			end,
			spawn(fun()->fight_info(NewState) end)	, 
			erlang:send_after(5000,self(),{'BUFF'});
	   true->NewState=State
	end,
	{noreply,NewState};

handle_info({'CHECK_STATE'},State)->
	{Red,Blue} = count_member(State#state.member,0,0),
	if Red =:=0 orelse Blue =:= 0 ->
		   NewState=finish_war_now(State,Red,Blue),
		   %%额外声望加成
		   N = State#state.max_level-State#state.level+1,
		   Extra = round((15*N+20)*0.5),
		   %%对方弃权，10秒后关闭战斗
		   erlang:send_after(10*1000,self(),{'FINISH_WAR',[Extra]});
	   true->
		   NewState = State,
		   %%9分钟后关闭战场
		   erlang:send_after((9*60+10)*1000,self(),{'FINISH_WAR',[0]})
	end,
	{noreply,NewState};
%% 
handle_info({'FINISH_WAR',[Extra]}, State) ->
	if
		State#state.is_end /= 1 ->
			finish_war(State,Extra),
			%%30秒后关闭战场
			erlang:send_after(30*1000,self(),{'CLOSE_WAR'});
		true ->
			skip
	end,
	NewState = State#state{
		is_end = 1
	},
	{noreply, NewState};

handle_info({'CLOSE_WAR'},State)->
	Member = [Mem||Mem<-State#state.member,Mem#competitor.state=:=0],
	send_out(Member,State#state.pid_wait,State#state.scene_wait),
	{stop, normal, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, State) ->
	misc:delete_monitor_pid(self()),
	spawn(fun()-> lib_scene:clear_scene(State#state.scene) end),
	ok.

code_change(_OldVsn, State, _Extra)->
    {ok, State}.

%%刷新战旗(红色)
refresh_flag(all,SceneId,Flags)->
	if Flags=<15->
		   MonAutoId = mod_mon_create:get_mon_auto_id(1),
		   mod_mon_create:create_mon_action(42903, SceneId,38,63, 1, [], MonAutoId);
	   true->
		   MonAutoId = mod_mon_create:get_mon_auto_id(1),
		   mod_mon_create:create_mon_action(42905, SceneId, 38,63, 1, [], MonAutoId)
	end;
refresh_flag(red,SceneId,Flags)->
%% 	io:format("refresh_flag>>>>>~p~n",[11]),
	if Flags=<15->
		   MonAutoId = mod_mon_create:get_mon_auto_id(1),
		   mod_mon_create:create_mon_action(42904, SceneId,59,23, 1, [], MonAutoId);
	   true->
		   MonAutoId = mod_mon_create:get_mon_auto_id(1),
		   mod_mon_create:create_mon_action(42906, SceneId, 59,23, 1, [], MonAutoId)
	end;
%%刷新蓝色战旗
refresh_flag(blue,SceneId,Flags)->
%% 	io:format("refresh_flag>>>>>~p~n",[12]),
	if Flags=<15->
		   MonAutoId = mod_mon_create:get_mon_auto_id(1),
		   mod_mon_create:create_mon_action(42903, SceneId, 12,90, 1, [], MonAutoId);
	   true->
		   MonAutoId = mod_mon_create:get_mon_auto_id(1),
		   mod_mon_create:create_mon_action(42905, SceneId, 12,90, 1, [], MonAutoId)
	end;
refresh_flag(_,_,_)->skip.

%%获取战旗
get_flag(State,PlayerId,PlayerList)->
	case lists:keyfind(PlayerId,2,State#state.member) of
		false->
			{State#state.member,''};
		Com->
			Point = tool:ceil((State#state.max_level-State#state.level+1)/4)+2+Com#competitor.point,
			MaxP = get_max_p(State#state.max_level,State#state.level),
			NewPoint = case Point > MaxP of
						   false->Point;
						   true->MaxP
					   end,
			NewCom = Com#competitor{point=NewPoint},
			Member = lists:keyreplace(NewCom#competitor.id, 2, State#state.member, NewCom),	
			NewMember = att_flag_count(Member,PlayerList,[]),
			{NewMember,Com#competitor.nickname}
	end.

att_flag_count([],_PlayerList,Member)->Member;
att_flag_count([M|PlayerBag],PlayerList,Member)->
	case lists:member(M#competitor.id,PlayerList) of
		true->
			NewM = M#competitor{att_flag=M#competitor.att_flag+1},
			att_flag_count(PlayerBag,PlayerList,[NewM|Member]);
		false->
			att_flag_count(PlayerBag,PlayerList,[M|Member])
	end.
%%提交战旗
commit_flag(State,PlayerId)->
	case lists:keyfind(PlayerId,2,State#state.member) of
		false->State#state.member;
		Com ->
			Point = State#state.max_level-State#state.level+1+3+Com#competitor.point,
			MaxP = get_max_p(State#state.max_level,State#state.level),
			NewPoint = case Point > MaxP of
						   false->Point;
						   true->MaxP
					   end,
			NewCom = Com#competitor{point=NewPoint},
			Member = lists:keyreplace(NewCom#competitor.id, 2, State#state.member, NewCom),	
			Member
	end.

%%检查场景战旗状态
check_player_flag([],_Color)->false;
check_player_flag([P|PBag],Color)->
	case P#competitor.color =:= Color of
		false->check_player_flag(PBag,Color);
		true->
			case lib_player:get_online_info(P#competitor.id) of
				[]->check_player_flag(PBag,Color);
				Player ->
					case Player#player.carry_mark > 0 of
						true->
							true;
						false->
							check_player_flag(PBag,Color)
					end
			end
	end.

check_player_flag_all([])->false;
check_player_flag_all([P|PBag])->
	case lib_player:get_online_info(P#competitor.id) of
		[]->check_player_flag_all(PBag);
		Player ->
			case Player#player.carry_mark > 0 of
				true->true;
				false->check_player_flag_all(PBag)
			end
	end.

%%创建boss
create_boss(SceneId,X,Y)->
	MonAutoId = mod_mon_create:get_mon_auto_id(1),
	mod_mon_create:create_mon_action(42901, SceneId, X, Y, 1, [], MonAutoId),
	ok.

%%通知进入战场
notice_enter_war(Times,Level, Round,SceneId, MemberList, ArenaPid) ->	
	notice_enter_war_loop(MemberList, Times,Level, Round,SceneId, ArenaPid,MemberList).
notice_enter_war_loop([],_Times, _Level, _Round,_SceneId, _ArenaPid,MemberList) ->
	MemberList;
notice_enter_war_loop([Com | M], Times,Level, Round,SceneId, ArenaPid,MemberList) ->
	case lib_player:get_player_pid(Com#competitor.id) of
		[] ->
			NewCom = Com#competitor{state=1},
			NewMemberList = lists:keyreplace(Com#competitor.id, 2, MemberList, NewCom),	
			no_pid;
		Pid ->
			%%比赛区出生点：红（16,85）蓝（54,29）
			[X,Y]=case Com#competitor.color of
					  11->[16,85];
					  _->[54,29]
				  end,
			gen_server:cast(Pid, {'NOTICE_ENTER_WAR',Times,Level, Round,SceneId,X,Y,Com#competitor.color, ArenaPid}),
			NewMemberList = MemberList
	end,	
	notice_enter_war_loop(M, Times,Level, Round, SceneId,ArenaPid,NewMemberList).

%% %%通知战场开始
%% notice_start_war(MemberList,Times,Level,Round)->
%% %% 	erlang:send_after(10000,self(),{'BUFF'}),
%% 	notice_start_war_loop(MemberList,Times,Level,Round,MemberList).
%% 
%% notice_start_war_loop([],_Times,_Level,_Round,MemberBag)->
%% 	MemberBag;
%% notice_start_war_loop([Com|MemberList],Times,Level,Round,MemberBag)->
%% 	case lib_player:get_player_pid(Com#competitor.id) of
%% 		[] ->
%% 			NewCom = Com#competitor{state=1},
%% 			NewMemberBag = lists:keyreplace(Com#competitor.id, 2, MemberBag, NewCom),	
%% 			no_pid;
%% 		Pid ->
%% 			gen_server:cast(Pid, {'WAR_START',Times,Level,Round}),
%% 			NewMemberBag = MemberBag
%% 	end,	
%% 	notice_start_war_loop(MemberList,Times,Level,Round,NewMemberBag).

%%获取战台气势值
get_buff(State)->
	[X1,Y1,X2,Y2] = [33,44,44,57],
	{Red,Bule} = count_buff(State#state.member,0,0,[X1,Y1,X2,Y2]),
%% 	io:format("BUFF>>>>>>>>>>~p/~p/~p~n",[State#state.buff,Red,Bule]),
	Buff = State#state.buff+Red-Bule,
	NewBuff = if Buff < 0->0;
				 Buff>60->60;
				 true->Buff
			  end,
	{NewBuff,Red,Bule}.

count_buff([],Red,Blue,_)->
	{Red,Blue};
count_buff([P|PBag],Red,Blue,[X1,Y1,X2,Y2])->
	case lib_player:get_online_info(P#competitor.id) of
		[]->count_buff(PBag,Red,Blue,[X1,Y1,X2,Y2]);
		Player->
			if (Player#player.x > X1 andalso Player#player.x < X2 andalso Player#player.y > Y1 andalso Player#player.y < Y2) andalso Player#player.hp>0 ->
				   if Player#player.other#player_other.leader=:= 11->
						  count_buff(PBag,Red+1,Blue,[X1,Y1,X2,Y2]);
					  true->
						  count_buff(PBag,Red,Blue+1,[X1,Y1,X2,Y2])
				   end;
			   true->
				   count_buff(PBag,Red,Blue,[X1,Y1,X2,Y2])
			end
	end.

%%立即结束
finish_war_now(State,Red,Blue)->
	Point = 300,
%% 	{Red,Blue} = count_member(State#state.member,0,0),
	{PointA,PointB} = if Red =:= Blue->{0,0};
						 Blue =:= 0 ->{Point,0};
						 true->{0,Point}
					  end,
	State#state{red_point=PointA,blue_point=PointB}.

%%计算双方战场人数
count_member([],Red,Blue)->{Red,Blue};
count_member([M|Member],Red,Blue)->
	if M#competitor.color =:= 11->
		   if M#competitor.state =:= 0->
				  count_member(Member,Red+1,Blue);
			  true->
				  count_member(Member,Red,Blue)
		   end;
	   true->
		   if M#competitor.state =:= 0->
				  count_member(Member,Red,Blue+1);
			  true->
				  count_member(Member,Red,Blue)
		   end
	end.

%%获取声望封顶值
get_max_p(MaxLv,Lv)->
	N = MaxLv-Lv+1,
	MaxPoint = 10*N+80,
	MaxPoint.

%%战场结束，结算
finish_war(State,Extra)->
	[Vs] = lib_war:select_war_vs(State#state.battle_id),
	N = State#state.max_level-State#state.level+1,
%% 	TeamPoint = 15+5 * N,
%% 	MaxPoint = 15*N+20,
	[Win,WinPf,WinSn,WinP,WinTotal,LosePf,LoseSn,LoseP,LoseTotal] = 
		if State#state.red_point > State#state.blue_point->
			   spawn(fun()->finish_msg_local(State#state.times,State#state.max_level,State#state.level,State#state.round,State#state.red_platform,State#state.red_sn,State#state.blue_platform,State#state.blue_sn,1)end),
			   [red,State#state.red_platform,State#state.red_sn,3, 10+N,State#state.blue_platform,State#state.blue_sn,0,N];
		   State#state.red_point =:= State#state.blue_point->
			   spawn(fun()->finish_msg_local(State#state.times,State#state.max_level,State#state.level,State#state.round,State#state.red_platform,State#state.red_sn,State#state.blue_platform,State#state.blue_sn,2)end),
			   [null,State#state.red_platform,State#state.red_sn,1,3+N,State#state.blue_platform,State#state.blue_sn,1,3+N];
		   true->
			   spawn(fun()->finish_msg_local(State#state.times,State#state.max_level,State#state.level,State#state.round,State#state.blue_platform,State#state.blue_sn,State#state.red_platform,State#state.red_sn,1)end),
			   [blue,State#state.blue_platform,State#state.blue_sn,3, 10+N,State#state.red_platform,State#state.red_sn,0, N]
		end,
	case Vs#ets_war_vs.sn_a =:= State#state.red_sn of
		true->
			update_vs(Vs,State#state.red_point,State#state.blue_point);
		false->
			update_vs(Vs,State#state.blue_point,State#state.red_point)
	end,
	update_team(WinPf,WinSn,State#state.times,WinP,WinTotal),
	update_team(LosePf,LoseSn,State#state.times,LoseP,LoseTotal),
	Mvp = get_mvp(State#state.member,[]),
	update_player(State#state.member,Win,WinTotal,LoseTotal,Extra,Mvp),
	war_reslut(State),
	ok.

start_msg_remote(Times,MaxLv,Lv,Round,PlatA,SnA,PlatB,SnB)->
	%%封神大会X级第X轮比赛已经开始，本服的比赛对手是XX服，请为本服代表队呐喊助威吧！
	ContentA = io_lib:format("第<font color='#FEDB4F;'>~p</font>届封神大会<font color='#FEDB4F;'>~s</font>第<font color='#FEDB4F;'>~p</font>轮比赛已经开始，本服的比赛对手是<font color='#FEDB4F;'>[~s平台~p服]</font>，请为本服代表队呐喊助威吧！",[Times,lib_war:id_to_name(Lv,MaxLv),Round,lib_war:platform(PlatB),SnB]),
	ContentB = io_lib:format("第<font color='#FEDB4F;'>~p</font>届封神大会<font color='#FEDB4F;'>~s</font>第<font color='#FEDB4F;'>~p</font>轮比赛已经开始，本服的比赛对手是<font color='#FEDB4F;'>[~s平台~p服]</font>，请为本服代表队呐喊助威吧！",[Times,lib_war:id_to_name(Lv,MaxLv),Round,lib_war:platform(PlatA),SnA]),
	spawn(fun()->mod_leap_server:remote_server_msg_by_sn(PlatA,SnA,ContentA)end),
	spawn(fun()->mod_leap_server:remote_server_msg_by_sn(PlatB,SnB,ContentB)end),
	ok.

finish_msg_local(Times,MaxLv,Lv,Round,WinPlatform,WinSn,LosePlatform,LoseSn,Type)-> 
%% 	io:format("finish msg>>>>>>>>>>>>>>~n"),
	spawn(fun()->finish_msg_remote(Times,MaxLv,Lv,Round,WinPlatform,WinSn,LosePlatform,LoseSn,Type)end),
	Content = case Type of
				  1->
					  %%封神大会X级第X轮比赛，经过一番龙争虎斗，本服代表队击败XX服代表队，获得了本轮的胜利！
					  io_lib:format("第<font color='#FEDB4F;'>~p</font>届封神大会<font color='#FEDB4F;'>~s</font>级第<font color='#FEDB4F;'>~p</font>轮比赛，经过一番龙争虎斗，<font color='#FEDB4F;'>[~s平台~p服]</font>代表队击败<font color='#FEDB4F;'>[~s平台~p服]</font>代表队，获得了本轮的胜利！",[Times,lib_war:id_to_name(Lv,MaxLv),Round,lib_war:platform(WinPlatform),WinSn,lib_war:platform(LosePlatform),LoseSn]);
				  _->
					  %%封神大会X级第X轮比赛，经过一番龙争虎斗，本服和XX服最终握手言和！
					  io_lib:format("第<font color='#FEDB4F;'>~p</font>届封神大会<font color='#FEDB4F;'>~s</font>级第<font color='#FEDB4F;'>~p</font>轮比赛，经过一番龙争虎斗，<font color='#FEDB4F;'>[~s平台~p服]</font>和<font color='#FEDB4F;'>[~s平台~p服]</font>最终握手言和！",[Times,lib_war:id_to_name(Lv,MaxLv),Round,lib_war:platform(WinPlatform),WinSn,lib_war:platform(LosePlatform),LoseSn])
			  end,
	lib_chat:broadcast_sys_msg(6, Content).

finish_msg_remote(Times,MaxLv,Lv,Round,WinPlatform,WinSn,LosePlatform,LoseSn,Type)->
	case Type of
		1->
			%%封神大会X级第X轮比赛，经过一番龙争虎斗，本服代表队击败XX服代表队，获得了本轮的胜利！
			%%封神大会X级第X轮比赛，经过一番龙争虎斗，本服代表队遗憾地输给了XX服代表队！
			ContentWin = io_lib:format("第<font color='#FEDB4F;'>~p</font>届封神大会<font color='#FEDB4F;'>~s</font>级第<font color='#FEDB4F;'>~p</font>轮比赛，经过一番龙争虎斗，本服代表队击败<font color='#FEDB4F;'>[~s平台~p服]</font>代表队，获得了本轮的胜利！",[Times,lib_war:id_to_name(Lv,MaxLv),Round,lib_war:platform(LosePlatform),LoseSn]),
			ConttentLose = io_lib:format("第<font color='#FEDB4F;'>~p</font>届封神大会<font color='#FEDB4F;'>~s</font>级第<font color='#FEDB4F;'>~p</font>轮比赛，经过一番龙争虎斗，本服代表队遗憾地输给了<font color='#FEDB4F;'>[~s平台~p服]</font>代表队！",[Times,lib_war:id_to_name(Lv,MaxLv),Round,lib_war:platform(WinPlatform),WinSn]);
		_->
			%%封神大会X级第X轮比赛，经过一番龙争虎斗，本服和XX服最终握手言和！
			ContentWin = io_lib:format("第<font color='#FEDB4F;'>~p</font>届封神大会<font color='#FEDB4F;'>~s</font>级第<font color='#FEDB4F;'>~p</font>轮比赛，经过一番龙争虎斗，本服和<font color='#FEDB4F;'>[~s平台~p服]</font>最终握手言和！",[Times,lib_war:id_to_name(Lv,MaxLv),Round,lib_war:platform(LosePlatform),LoseSn]),
			ConttentLose = io_lib:format("第<font color='#FEDB4F;'>~p</font>届封神大会<font color='#FEDB4F;'>~s</font>级第<font color='#FEDB4F;'>~p</font>轮比赛，经过一番龙争虎斗，本服和<font color='#FEDB4F;'>[~s平台~p服]</font>最终握手言和！",[Times,lib_war:id_to_name(Lv,MaxLv),Round,lib_war:platform(WinPlatform),WinSn])
	end,
	spawn(fun()->mod_leap_server:remote_server_msg_by_sn(WinPlatform,WinSn,ContentWin)end),
	spawn(fun()->mod_leap_server:remote_server_msg_by_sn(LosePlatform,LoseSn,ConttentLose)end),
	ok.

%%获取本次MVP
get_mvp([],Info)->Info;
get_mvp([M|Member],Info)->
	case Info of
		[]->get_mvp(Member,M);
		_->
			if M#competitor.kill > Info#competitor.kill ->
				   get_mvp(Member,M);
			   true->
				   get_mvp(Member,Info)
			end
	end.

%%更新对战结果
update_vs(Vs,ResA,ResB)->
	NewVs = Vs#ets_war_vs{res_a=ResA,res_b=ResB},
	lib_war:update_war_vs(NewVs),
	db_agent:update_war_vs([{res_a,ResA},{res_b,ResB}],[{id,Vs#ets_war_vs.id}]).

%%更新队伍积分
update_team(Pf,Sn,Times,Point,Total)->
	[Team] = lib_war:select_war_team_by_sn(Pf,Sn,Times),
	NewTeam = Team#ets_war_team{point = Team#ets_war_team.point+Point,total=Team#ets_war_team.total+Total},
	lib_war:update_war_team(NewTeam),
	db_agent:update_war_team([{point,Point,add},{total,Total,add}],[{id,Team#ets_war_team.id}]).

%%更新玩家积分 
update_player(Member,Win,WinPoint,LosePoint,ExtraPoint,Mvp)->
	update_player_loop(Member,Win,WinPoint,LosePoint,ExtraPoint,Mvp),
	ok.

update_player_loop([],_,_,_,_,_)->skip;
update_player_loop([M|Member],Win,WinPoint,LosePoint,ExtraPoint,Mvp)->
	case Win of
		red->
			update_point_loop(M,WinPoint,LosePoint,ExtraPoint,Mvp);
		blue->
			update_point_loop(M,LosePoint,WinPoint,ExtraPoint,Mvp);
		_->
			update_point_loop(M,WinPoint,LosePoint,ExtraPoint,Mvp)
	end,
	update_player_loop(Member,Win,WinPoint,LosePoint,ExtraPoint,Mvp).

update_point_loop(M,P1,P2,ExtraPoint,Mvp)->
	case lib_war:select_war_player(M#competitor.id) of
		[]->skip;
		[Info]->
			case lib_player:get_online_info(M#competitor.id) of
				[]->add_point(Info,M,0,0,ExtraPoint,Mvp);
				Player->
					case lib_war:is_fight_scene(Player#player.scene) of
						false->
							add_point(Info,M,0,0,ExtraPoint,Mvp);
						true->
							add_point(Info,M,P1,P2,ExtraPoint,Mvp)
					end
			end
	end.

add_point(Info,M,P1,P2,ExtraPoint,Mvp)->
	case M#competitor.color of
		11->
			Point = 
				if M =:=Mvp-> 
					if  ExtraPoint > 0->
							P1+M#competitor.point+ExtraPoint;
						true->
							if Mvp#competitor.kill > 0 ->
								round(P1+M#competitor.point+(P1+M#competitor.point)*0.1);
							   true->
								   P1+M#competitor.point+ExtraPoint
							end
					end;
				   true->
					   P1+M#competitor.point+ExtraPoint
				   end,
			NewInfo = Info#ets_war_player{point=Info#ets_war_player.point+Point,kill=M#competitor.total_kill,att_flag=M#competitor.att_flag},
			lib_war:update_war_player(NewInfo),
			db_agent:update_war_player([{point,NewInfo#ets_war_player.point},{att_flag,M#competitor.att_flag},{kill,M#competitor.total_kill}],[{id,NewInfo#ets_war_player.id}]);
		_->
			Point = 
				if M =:=Mvp-> 
					if  ExtraPoint > 0->
							P2+M#competitor.point+ExtraPoint;
						true->
							if Mvp#competitor.kill > 0 ->
								   round(P2+M#competitor.point+(P1+M#competitor.point)*0.1);
							true->
								P2+M#competitor.point+ExtraPoint
							end
					end;
				   true->
					   P2+M#competitor.point+ExtraPoint
				   end,
			NewInfo = Info#ets_war_player{point=Info#ets_war_player.point+Point,kill=M#competitor.total_kill,att_flag=M#competitor.att_flag},
			lib_war:update_war_player(NewInfo),
			db_agent:update_war_player([{point,NewInfo#ets_war_player.point},{att_flag,M#competitor.att_flag},{kill,M#competitor.total_kill}],[{id,NewInfo#ets_war_player.id}])
	end.
%%推送战斗结果
war_reslut(State)->
	{RedKill,RedRes} = pack_result(State#state.member,11),
	{BlueKill,BlueRes} = pack_result(State#state.member,12),
%% 	ResBin = pack_war_res(State#state.red_point,RedKill,RedRes,State#state.blue_point,BlueKill,BlueRes),
	result(State#state.member,[State#state.red_point,RedKill,RedRes,State#state.blue_point,BlueKill,BlueRes]).

result([],_)->ok;
result([M|Member],ResBin)->
	case lib_player:get_online_info(M#competitor.id) of
			[]->skip;
			Player->
				if Player#player.carry_mark =:=26->
					   gen_server:cast(Player#player.other#player_other.pid, {'WAR_FLAG_MARK',[0]});
					   ok;
				   true->skip
				end,
				{ok,BinData} = pt_45:write(45018,[M#competitor.color|ResBin]),
				lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
	end,
	result(Member,ResBin).

pack_result(Member,Color)->
	PlayerBag = [{P#competitor.nickname,P#competitor.kill,P#competitor.die,P#competitor.max_hit}||P<-Member,P#competitor.color=:=Color],
	%% 分数由高到底
	SortFun = fun({_,P1,_,_}, {_,P2,_,_}) ->
		P1 < P2 
	end,
	PlayerBag1 = lists:sort(SortFun, PlayerBag),
	Kill = sum_kill(PlayerBag1,0),
	{Kill,PlayerBag1}.



sum_kill([],Kill)->Kill;
sum_kill([P|Member],Kill)->
	{_,K,_,_}=P,
	sum_kill(Member,Kill+K).

%%初始化玩家数据
init_war_member_data(VsInfo,Times,_Round)->
%% 	Times= lib_war:check_times()-1,
	RedSn = VsInfo#ets_war_vs.sn_a,
	RedPlatform = VsInfo#ets_war_vs.platform_a,
	BluePlatform = VsInfo#ets_war_vs.platform_b,
	BlueSn = VsInfo#ets_war_vs.sn_b,
	Red = case lib_war:select_war_team_by_sn(RedPlatform,RedSn,Times) of
				 []->[];
				 [B]->B
			 end,
	Blue = case lib_war:select_war_team_by_sn(BluePlatform,BlueSn,Times) of
			  []->[];
			  [R]->R
		  end,
	Member1 = [pack_competitor(Info,11)||Info<-Red#ets_war_team.team],
%% 	update_round(Round,Red#ets_war_team.team),
	Member = [pack_competitor(Info,12)||Info <-Blue#ets_war_team.team],
%% 	update_round(Round,Blue#ets_war_team.team),
	[BluePlatform,BlueSn,length(Blue#ets_war_team.team),RedPlatform,RedSn,length(Red#ets_war_team.team),Member++Member1].

%% update_round(Round,Team)->
%% 	[update_round_loop(Id,Round)||{Id,_,_,_,_,_}<-Team],
%% 	ok.
%% update_round_loop(Id,Round)->
%% 	case lib_war:select_war_player(Id) of
%% 		[]->skip;
%% 		[Player]->
%% 			NewPlayer = Player#ets_war_player{round=Round},
%% 			lib_war:update_war_player(NewPlayer),
%% 			db_agent:update_war_player([{round,Round}],[{pid,Player#ets_war_player.pid}])
%% 	end.

pack_competitor(Info,Color)->
	{Id,NickName,Career,Realm,Level,Sex,_,_} = Info,
	case lib_war:select_war_player(Id) of
		[]->
			#competitor{id=Id,
						nickname=NickName,
						realm =Realm,
						career =Career,
						color=Color,
						lv= Level,
						sex = Sex
						};
		[P]->
			#competitor{id=Id,
						nickname=NickName,
						realm =Realm,
						career =Career,
						color=Color,
						lv= Level,
						sex = Sex,
						att_flag = P#ets_war_player.att_flag,
						total_kill = P#ets_war_player.kill,
						total_point = P#ets_war_player.point
				}
	end.

competitor_live(LivePid,Live,State,Flag,DieName)->
	NewKill = Live#competitor.kill+1,
	TotalKill = Live#competitor.total_kill+1,
	NewDoubleHit = Live#competitor.double_hit+1,
	MaxHit = if NewDoubleHit > Live#competitor.max_hit->NewDoubleHit;
				   true->Live#competitor.max_hit
				end,
	NewTitle = if NewDoubleHit>=3->NewDoubleHit;
				  true->0
			   end,
	DoubleHitP = if NewDoubleHit =< 20->
						case lists:member(NewDoubleHit,[5,10,15,20])of
							false->0;
							true->NewDoubleHit
						end;
					true->
						case  NewDoubleHit rem 10 of
							0->10;
							_->0
						end
				 end,
	KillPoint = tool:ceil((State#state.max_level-State#state.level+1)/4)+2+DoubleHitP+Live#competitor.point,
	MaxP = get_max_p(State#state.max_level,State#state.level),
	NewPoint = case KillPoint > MaxP of
				   false-> KillPoint;
				   true-> MaxP
			   end,
	{_SinglePoint,TeamPoint}=
		case Flag of
			0->{0,5+NewDoubleHit};
			_->
				{tool:ceil((State#state.max_level-State#state.level+1)/4)+2,8+2}
		end,
	NewLive = Live#competitor{kill=NewKill,total_kill = TotalKill, double_hit=NewDoubleHit,max_hit=MaxHit,title = NewTitle,point=NewPoint},
	Member = lists:keyreplace(Live#competitor.id, 2, State#state.member, NewLive),		
	%%击杀广播
	{Platform,ServerId,NewState} = case Live#competitor.color of
				   11->
					   {State#state.red_platform,State#state.red_sn,State#state{red_point =State#state.red_point+ TeamPoint,member=Member}};
				   _->
					   {State#state.blue_platform,State#state.blue_sn,State#state{blue_point =State#state.blue_point+ TeamPoint,member=Member}}
			   end, 
	lib_war:bc_double_hit_msg(Platform,ServerId,NewLive#competitor.id, NewLive#competitor.nickname, NewLive#competitor.career, NewLive#competitor.sex, NewDoubleHit),
	%%（队名）的（玩家名）大喝一声，将（玩家名）手中的战旗夺到手中！
	NewState1 = if Flag >0 ->
		   Msg = io_lib:format("<font color='#FEDB4F;'>~s</font>平台<font color='#FEDB4F;'>~p</font>服的<font color='#FEDB4F;'>~s</font>大喝一声，将<font color='#FEDB4F;'>~s</font>手中的战旗夺到手中！",[lib_war:platform(Platform),ServerId,NewLive#competitor.nickname,DieName]),
		   lib_chat:broadcast_sys_msg(6, Msg),
		   spawn(fun()->mod_leap_server:remote_server_msg_by_sn(Platform,ServerId,Msg)end),
		   NewState#state{flag_color = Live#competitor.color,flag_owner=NewLive#competitor.nickname};
	   true->NewState
	end,
	if NewDoubleHit >= 3 ->
		gen_server:cast(LivePid, {'WAR_TITLE',get,NewDoubleHit});
	   true->ship
	end,
	NewState1.

competitor_die(Die,State)->
	NewDie = Die#competitor{die=Die#competitor.die+1,double_hit=0,title=0,last_die_time = util:unixtime()},
	Member = lists:keyreplace(Die#competitor.id, 2, State#state.member, NewDie),	 
	NewState = State#state{member=Member},
	case lib_player:get_player_pid(Die#competitor.id) of
		[] ->
			no_pid;
		Pid ->
			gen_server:cast(Pid, {'WAR_TITLE',lose,0})
	end,
	NewState.

title_lose_msg(Win,Lose,State)->
	%%（A玩家名）的（称号）被（B玩家名）终结了！
	case Lose#competitor.title>=3 of
		false->skip;
		true->
			{WinPlat,WinServerid,LosePlat,LoseServerId} = 
				case Win#competitor.color of
					12-> {State#state.red_platform,State#state.red_sn,State#state.blue_platform,State#state.blue_sn};
					_->{State#state.blue_platform,State#state.blue_sn,State#state.red_platform,State#state.red_sn}
				end,
			Msg = io_lib:format("<font color='#FEDB4F;'>~s</font>平台<font color='#FEDB4F;'>~p</font>服的勇士~s的<font color='#FEDB4F;'>~s</font>称号被<font color='#FEDB4F;'>~s</font>平台<font color='#FEDB4F;'>~p</font>服的勇士~s终结了！",[lib_war:platform(WinPlat),WinServerid,pack_player(Lose),title(Lose#competitor.title),lib_war:platform(LosePlat),LoseServerId,pack_player(Win)]),
			lib_chat:broadcast_sys_msg(6, Msg),
			spawn(fun()->mod_leap_server:remote_server_msg_by_sn(WinPlat,WinServerid,Msg)end)
	end,
	ok.
pack_player(P)->
	io_lib:format("<a href='event:1, ~p, ~s, ~p, ~p'><font color='#FEDB4F'>~s</font></a>",[P#competitor.id, P#competitor.nickname, P#competitor.career, P#competitor.sex, P#competitor.nickname]).
title(Type)->
	case Type of
		3->"大杀特杀";
		4->"主宰比赛";
		5->"疯狂杀戮";
		6->"无人能挡";
		7->"变态杀戮";
		8->"妖怪";
		9->"神";
		_->"弑神者"
	end.

%%传送玩家到等待区
send_out([],_PidWait,_SceneId)->ok;
send_out([M|Member],PidWait,SceneId)->
	case lib_player:get_player_pid(M#competitor.id) of
		[] ->
			no_pid;
		Pid ->
			gen_server:cast(Pid, {'NOTICE_LEAVE_WAR',PidWait,SceneId})
	end,
	send_out(Member,PidWait,SceneId).

%%战斗信息
%%string红方平台
%%int8 红方服id
%% 	int	32红方积分
%%string蓝方平台
%%int8 蓝方服id
%% 	int 32蓝方积分
%%	int 8 战旗状态（11红，12 蓝，0中立)
%%string 持旗玩家 
%%  string MVP
%%int 16本场击杀数
%%int16 连击数
%% int32 本场获得积分 
%%int32本届总积分
%% int16 当前攻击战旗数
%% int16  需要攻击战旗数
%% int16当前击倒玩家数
%% int16需要击倒玩家数

fight_info(State)->
	Data = [{M#competitor.nickname,M#competitor.career,M#competitor.color,M#competitor.kill}||M<-State#state.member],
			%% 分数由高到底
			SortFun = fun({_,_,_,Kill1}, {_,_,_,Kill2}) ->
				Kill1 > Kill2
			end,	
			NewMemberList = lists:sort(SortFun, Data),
	Mvp = get_mvp(State#state.member,[]),
	[bc_fight_info(P,State,Mvp,NewMemberList)||P<-State#state.member],
	ok.
%%个人
fight_info_single(PlayerId,State,PidSend)->
	case lists:keyfind(PlayerId,2,State#state.member) of
		false->skip;
		Info->
			Data = [{M#competitor.nickname,M#competitor.career,M#competitor.color,M#competitor.kill}||M<-State#state.member],
			%% 分数由高到底
			SortFun = fun({_,_,_,Kill1}, {_,_,_,Kill2}) ->
				Kill1 > Kill2
			end,	
			NewMemberList = lists:sort(SortFun, Data),
			Mvp = get_mvp(State#state.member,[]),
			Kill = case Info#competitor.total_kill > 3 of
						   false-> Info#competitor.total_kill;
						   true->3
					   end,
			{MvpName,MvpColor} =  case Mvp#competitor.kill >0 of
						   false-> {'',0};
						   true->{Mvp#competitor.nickname,Mvp#competitor.color}
					   end,
			AttFlag = case Info#competitor.att_flag > 10 of
							  false-> Info#competitor.att_flag;
							  true->10
						  end,
			MaxP = get_max_p(State#state.max_level,State#state.level),
				{ok,BinData} = pt_45:write(45015,[
												  State#state.red_platform,
												  State#state.red_sn,
												  State#state.red_point,
												  State#state.blue_platform,
												  State#state.blue_sn,
												  State#state.blue_point,
												  State#state.flag_color,
												  State#state.flag_owner,
												  MvpColor,
												  MvpName,
												  Info#competitor.kill,
												  Info#competitor.double_hit,
												  Info#competitor.point,
												  MaxP,
												  Info#competitor.total_point+Info#competitor.point,
												  AttFlag,
												  10,
												  Kill,
												  3,NewMemberList]),
				lib_send:send_to_sid(PidSend, BinData)
	end.
	
bc_fight_info(P,State,Mvp,NewMemberList)->
	if P#competitor.state =/=1->
		case lib_player:get_online_info(P#competitor.id) of
			[]->skip;
			Player->
				Kill = case P#competitor.total_kill > 3 of
						   false-> P#competitor.total_kill;
						   true->3
					   end,
				{MvpName,MvpColor} =  case Mvp#competitor.kill >0 of
						   false-> {'',0};
						   true->{Mvp#competitor.nickname,Mvp#competitor.color}
					   end,
				AttFlag = case P#competitor.att_flag > 10 of
							  false-> P#competitor.att_flag;
							  true->10
						  end,
				MaxP = get_max_p(State#state.max_level,State#state.level),
				{ok,BinData} = pt_45:write(45015,[
												  State#state.red_platform,
												  State#state.red_sn,
												  State#state.red_point,
												  State#state.blue_platform,
												  State#state.blue_sn,
												  State#state.blue_point,
												  State#state.flag_color,
												  State#state.flag_owner,
												  MvpColor,
												  MvpName,
												  P#competitor.kill,
												  P#competitor.double_hit,
												  P#competitor.point,
												  MaxP,
												  P#competitor.total_point+P#competitor.point,
												  AttFlag,
												  10,
												  Kill,
												  3,NewMemberList]),
				lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
		end;
	   true->skip
	end.

%%战斗剩余时间
finght_time(PidSend,State)->
	Timestamp = State#state.timestamp-util:unixtime(),
	{ok,BinData} = pt_45:write(45014,[State#state.state,State#state.round,Timestamp]),
	lib_send:send_to_sid(PidSend, BinData).

	
