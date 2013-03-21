%%% -------------------------------------------------------------------
%%% Author  : Administrator
%%% Description :
%%%
%%% Created : 2012-2-28
%%% -------------------------------------------------------------------
-module(mod_mount_arena).

-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
%% --------------------------------------------------------------------
%% External exports
-export([]).
-compile(export_all).
%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-define(AWARD_TIME,23*3600+0*60).
-record(state, {
				mount_ranker_num = 0,   %%竞技榜现有坐骑个数
				award_time
			   }).

%% ====================================================================
%% External functions
%% ====================================================================
start_link() ->
	gen_server:start_link({local,?MODULE}, ?MODULE , [], []).

get_mod_mount_arena_pid() ->
	ProcessName = mod_mount_arena_process,
	case misc:whereis_name({global,ProcessName}) of
		Pid when erlang:is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true ->
					Pid;
				false ->
					start_mod_mount_arena(ProcessName)
			end;
		_ ->
			start_mod_mount_arena(ProcessName)
	end.

start_mod_mount_arena(ProcessName) ->
	global:set_lock({ProcessName,undefined}),
	ProcessPid =
		case misc:whereis_name({global,ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive({global,ProcessName}) of
					true ->
						Pid;
					false ->
						start_mount_arena()
				end;
			_->
				start_mount_arena()
		end,
	ProcessPid.

start_mount_arena() ->
	case supervisor:start_child(
		   yg_server_sup, {mod_mount_arena,
            		{mod_mount_arena, start_link,[]},
               		permanent, 10000, supervisor, [mod_mount_arena]}) of
		{ok,Pid} ->
			timer:sleep(1000),
			Pid;
		_Other ->
			?DEBUG("_Other = ~p",[_Other]),
			undefined
	end.

%% ====================================================================
%% Server functions
%% ====================================================================

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([]) ->	
	ProcessName = mod_mount_arena_process,		%%
 	case misc:register(unique, ProcessName, self())of
		yes ->
			%%加载斗兽信息数据，并返回进入竞技榜的斗兽个数
			Nums = lib_mount_arena:load_mount_arena(),
			misc:write_monitor_pid(self(),?MODULE, {}),
			misc:write_system_info(self(), mod_mount_arena, {}),
			io:format("9.Init mod_mount_arena finish!!!!!!!!!!~n"),
			erlang:send_after(2000, self(), {'COUNT_AWRD'}),
			{ok, #state{mount_ranker_num = Nums}};
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
	Reply = 
		case (catch apply(Module, Method, Args)) of
			{'EXIT', Info} ->
?WARNING_MSG("apply_call_apply_call: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
				error;
			DataRet -> DataRet
		end,
	{reply, Reply, State};

%%获取第一的玩家id
handle_call({'GET_KING'}, _From, State) ->
    Reply = 
		case ets:lookup(?ETS_MOUNT_ARENA, 1) of
			[] ->
				{false,0};
			[M|_R] ->
				{true, M#ets_mount_arena.player_id}
		end,
    {reply, Reply, State};

handle_call({'test'}, _From, State) ->
	Nownum = State#state.mount_ranker_num,
	A = [Nownum,Nownum-1,Nownum-2,Nownum-3],
	F = fun(Rank)->
				if Rank =< 0 ->
					   {Rank =< 0};
				   true ->
					   case ets:lookup(?ETS_MOUNT_ARENA, Rank) of
						   []->
							   {Rank,null};
						   [Minfo|_R] ->
							   {Rank,Minfo#ets_mount_arena.mount_id}
					   end
				end
		end,
	B = [F(R) || R<-A],
    Reply = {A,B},	
    {reply, Reply, State};

handle_call({'ADD_COUNTER'},_From, State) ->
	Reply = State#state.mount_ranker_num + 1,
	{reply, Reply, State#state{mount_ranker_num = Reply}};

%%针对360平台42区出现的情况
handle_call({'test_change'},_From, State) ->
	A = [500,500-1,500-2,500-3],
	F = fun(Rank)->
				if Rank =< 0 ->
					   {Rank =< 0};
				   true ->
					   case ets:lookup(?ETS_MOUNT_ARENA, Rank) of
						   []->
							   {no,Rank,null};
						   [_Minfo|_R] ->
							  catch ets:delete(?ETS_MOUNT_ARENA, Rank),
							  {yes,del,Rank}
					   end
				end
		end,
	Reply1 = [F(R) || R <- A],
	Reply2 = lib_mount_arena:update_data(),
	Reply = {Reply1,Reply2},
	{reply,Reply,State#state{mount_ranker_num = 1310}};

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
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
?WARNING_MSG("mod_mount_arena error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
			 error;
		 _ -> ok
	end,
    {noreply, State};
%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------

%%打开面板
handle_cast({'OPEN_MOUNT_ARENA_PANEL',Player,Mount}, State) ->
	%%?DEBUG("into mod_mount_arena..  = []",[]),
	lib_mount_arena:open_arena_panel(Player,State#state.mount_ranker_num,Mount),
	{noreply, State};

%%坐骑加入竞技榜
handle_cast({'MOUNT_JOIN_RANKER',[Mount,PlayerId,Nickname,Realm,Vip]}, State) ->
	NewNums = lib_mount_arena:mount_join_ranker(State#state.mount_ranker_num, [Mount,PlayerId,Nickname,Realm,Vip]),
	{noreply,State#state{mount_ranker_num = NewNums}};

%%斗兽竞技榜
handle_cast({'OPEN_ARENA_RANK',PidSend}, State) ->
	lib_mount_arena:get_arena_ranker(PidSend),
	 {noreply, State};

%%增加挑战次数
handle_cast({'ADD_CGE_TIMES',Player}, State) ->
	case ets:lookup(?ETS_MOUNT_RECENT, Player#player.id) of
		[] ->
			%%500名外的只有读数据库了
			case db_agent:select_mount_arena() of
				null -> skip;
				Data ->
					Mr = list_to_tuple([ets_mount_arena|Data]),
					lib_mount_arena:add_cge_times(Mr,Player)
			end;
		[Mr | _R] ->
			lib_mount_arena:add_cge_times(Mr,Player)
	end,
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

%%同步更新竞技榜中坐骑属性信息
handle_info({'SYNC_MOUNT_DATA',Mount}, State) ->
	lib_mount_arena:update_arena_mount(Mount),
    {noreply, State};

%%斗兽竞技
%%{'MOUNT_BATTLE',PlayerStatus#player.other#player_other.pid_send, PlayerStatus#player.other#player_other.pid, PlayerStatus#player.nickname, PlayerStatus#player.vip, Speed, M, EnemyId}
handle_info({'MOUNT_BATTLE',Pid_Send, Pid, PlayerName, Vip, MySpeed, Mymount, EmountId}, State) ->
	Ms = ets:fun2ms(fun(M) when M#ets_mount_arena.mount_id =:= EmountId -> M end),
	case ets:select(?ETS_MOUNT_ARENA, Ms) of
		[] ->
			%%正常情况下，可以被挑战的坐骑都在斗兽榜上，无论玩家是否在线
			{ok,Bin} = pt_16:write(16044,[4,0,"","",0,0,"","",0,[],0,0]),
			lib_send:send_to_sid(Pid_Send, Bin);
		[Emount|_R] ->
			Mf = ets:fun2ms(fun(Ma) when Ma#ets_mount_arena.mount_id =:= Mymount#ets_mount.id -> Ma end),
			{MyRank,MyArena} = 
				case ets:select(?ETS_MOUNT_ARENA, Mf) of
					[]->
						%%正常情况下，自己的斗兽数据(登录时)、战斗、近况数据(打开斗兽面板时)已经被加载了
						{0,#ets_mount_arena{}};
					[MyAre|_RR]->
						{MyAre#ets_mount_arena.rank,MyAre}
				end,
			{Gold_times,Cge_times} = 
				case ets:lookup(?ETS_MOUNT_RECENT,Mymount#ets_mount.player_id) of
					[]->
						%%正常情况下，战斗、近况数据(打开斗兽面板时)已经被加载了
						{99,99};
					[MyRecent|_Rets] ->
						lib_mount_arena:count_cge_times(MyRecent)
				end,
			VipAdd = lib_mount_arena:vip_add_times(Vip),
			Total = ?MAX_CGE_TIMES + VipAdd,
			{CanCge,Result} =
				case (Total + Gold_times - Cge_times) =< 0 of
					true ->
						{ok,Bin} = pt_16:write(16044,[5,0,"","",0,0,"","",0,[],0,0]),%%挑战次数已满
						{false,Bin};
					false ->
						if 
						   MyRank =:= 0 ->
							   {ok,Bin0} = pt_16:write(16044,[4,0,"","",0,0,"","",0,[],0,0]),
							   {false,Bin0};
						   MyRank =< 5 andalso MyRank >= 1 ->
							   case lists:member(Emount#ets_mount_arena.rank, lists:delete(MyRank, [1,2,3,4,5])) of
								   false ->
									   {ok,Bin} = pt_16:write(16044,[4,0,"","",0,0,"","",0,[],0,0]),
									   {false,Bin};
								   true ->
									   {true,Emount#ets_mount_arena.rank}
							   end;
						   MyRank =< ?MAX_MOUNT_NUM ->
							   case lists:member(Emount#ets_mount_arena.rank, [MyRank-1,MyRank-2,MyRank-3,MyRank-4]) of
								   false ->
									   {ok,Bin} = pt_16:write(16044,[4,0,"","",0,0,"","",0,[],0,0]),
									   {false,Bin};
								   true ->
									   {true,Emount#ets_mount_arena.rank}
							   end;
						   MyRank > ?MAX_MOUNT_NUM -> %%500名外的数据
							   case lists:member(Emount#ets_mount_arena.rank, [?MAX_MOUNT_NUM,?MAX_MOUNT_NUM-1,?MAX_MOUNT_NUM-2,?MAX_MOUNT_NUM-3]) of
								   false ->
									   %%?DEBUG("ERANK = ~p",[Emount#ets_mount_arena.rank]),
									   {ok,Bin} = pt_16:write(16044,[4,0,"","",0,0,"","",0,[],0,0]),
									   {false,Bin};
								   true ->
									   {true,Emount#ets_mount_arena.rank}
							   end;
						   true ->
							   {ok,Bin} = pt_16:write(16044,[4,0,"","",0,0,"","",0,[],0,0]),
							   {false,Bin}
						end
				end,
			case CanCge of
				false ->
					lib_send:send_to_sid(Pid_Send, Result);
				true ->
					%%斗兽挑战任务
					Pid!{'MOUNT_PK'},
					%%条件满足，进入战斗计算
					%%初始数据MyMId,MyName,MyMountName,MyColor,EtkMId,EName,EMountName,EColor
					A = lib_mount_arena:parse_to_battle_data(Mymount),
					B = 
						case ets:lookup(?ETS_MOUNT_BATTLE, Emount#ets_mount_arena.mount_id) of
							[] ->
								lib_mount_arena:parse_to_battle_data_from_db(Emount#ets_mount_arena.mount_id);
							[Bale | _Retss] ->
								Bale
						end,
					%%对方战斗数据
					case B of
						[] ->
							%%如果斗兽榜内的坐骑被放生，就会跑这里
							%%竟然没有战斗数据
							{ok,NoDataBin} = pt_16:write(16044,[4,0,"","",0,0,"","",0,[],0,0]),
							lib_send:send_to_sid(Pid_Send, NoDataBin);
						_Other ->
							%%先发送16043协议，战斗初始信息
							F_init = fun(Batt) ->
											 BattleSpeed = 
												 if Batt =:= A ->
														MySpeed;
													true ->
														Batt#ets_mount_battle.speed
												 end,
											 {Batt#ets_mount_battle.hp,Batt#ets_mount_battle.atk,Batt#ets_mount_battle.def,round((Batt#ets_mount_battle.hit-0.85)*1000),
											  round(Batt#ets_mount_battle.dodge*1500),round(Batt#ets_mount_battle.crit*2000),BattleSpeed,Batt#ets_mount_battle.anti_wind,
											  Batt#ets_mount_battle.anti_water,Batt#ets_mount_battle.anti_fire,Batt#ets_mount_battle.anti_soil,Batt#ets_mount_battle.anti_thunder,
											  Batt#ets_mount_battle.val}
									 end,
							InitList = [F_init(E) || E <- [A,B]],
							%%判断速度，决定出手顺序
							{C,D} = lib_mount_arena:compare_speed(A#ets_mount_battle{speed = MySpeed},B),
							{Win_battler,IsPeace,BattleList} = lib_mount_arena:mount_battle(C,D,[],0,C#ets_mount_battle.hp,D#ets_mount_battle.hp,C#ets_mount_battle.hp,D#ets_mount_battle.hp),
							if length(BattleList) =:= 0 ->
								   {ok,NoDataBin2} = pt_16:write(16044,[4,0,"","",0,0,"","",0,[],0,0]),
								   lib_send:send_to_sid(Pid_Send, NoDataBin2);
							   true ->
								   %%发送战斗协议
								   {ok,InitBin} = pt_16:write(16043,InitList),
								   lib_send:send_to_sid(Pid_Send, InitBin),
								   {ok,BattleBin} = pt_16:write(16044, [1,Mymount#ets_mount.id,PlayerName,Mymount#ets_mount.name,Mymount#ets_mount.color,
																		Emount#ets_mount_arena.mount_id,Emount#ets_mount_arena.player_name,Emount#ets_mount_arena.mount_name,Emount#ets_mount_arena.mount_color,BattleList,
																		Mymount#ets_mount.goods_id,Emount#ets_mount_arena.mount_typeid]),
								   lib_send:send_to_sid(Pid_Send, BattleBin),
								   %%战后处理
								   {Winner,Failer,IsAcker,Cge_award} = 
									   case Win_battler#ets_mount_battle.mount_id =:= B#ets_mount_battle.mount_id of
										   true ->
											   {Emount,MyArena,false,[2,1,500]};
										   false ->	
											   {MyArena,Emount,true,[1,2,1000]}
									   end,
								   Rounds = round(length(BattleList)/2),
								   %%生成战报
								   BattleId = lib_mount_arena:make_battle_record(Winner#ets_mount_arena.player_id,Failer#ets_mount_arena.player_id,Mymount#ets_mount.id,PlayerName,Mymount#ets_mount.name,Mymount#ets_mount.color,
																				 Mymount#ets_mount.goods_id,Emount#ets_mount_arena.mount_id,Emount#ets_mount_arena.player_name,Emount#ets_mount_arena.mount_name,Emount#ets_mount_arena.mount_color,
																				 Emount#ets_mount_arena.mount_typeid,InitList,BattleList),
								   lib_mount_arena:exchange_rank(Winner,Failer,IsPeace,IsAcker,BattleId,Rounds),
								   %%奖励挑战者
								   Pid ! {'MOUNT_CGE_AWARD',Cge_award,Rounds},
								   %%日志
								   spawn(fun()->db_agent:log_mount_cge([Mymount#ets_mount.player_id,Emount#ets_mount_arena.player_id,Mymount#ets_mount.id,Emount#ets_mount_arena.mount_id,
																		Rounds,util:unixtime(),Win_battler#ets_mount_battle.mount_id,MyArena#ets_mount_arena.rank,
																		Emount#ets_mount_arena.rank]) end)
							end
					end
			end
	end,	
{noreply, State};

%%请求战报
handle_info({'REQUEST_DEMO',PidSend, BattleId}, State) ->
	case ets:lookup(?ETS_BATTLE_RESULT, BattleId) of
		[] ->
			case db_agent:select_battle_result(BattleId) of
				[] ->
					{ok,Bin} = pt_16:write(16044,[6,0,"","",0,0,"","",0,[],0,0]);
				Data ->
					B = list_to_tuple([ets_battle_result|Data]),
					InitData = util:string_to_term(tool:to_list(B#ets_battle_result.init)),
					BattleData = util:string_to_term(tool:to_list(B#ets_battle_result.battle_data)),
					{ok,InitBin} = pt_16:write(16043,InitData),
					lib_send:send_to_sid(PidSend, InitBin),
					%%插入ets
					ets:insert(?ETS_BATTLE_RESULT, B#ets_battle_result{init = InitData,battle_data = BattleData}),
					{ok,Bin} = pt_16:write(16044, [1,B#ets_battle_result.a_mount_id,B#ets_battle_result.a_player_name,
												   B#ets_battle_result.a_mount_name,B#ets_battle_result.a_mount_color,
												   B#ets_battle_result.b_mount_id,B#ets_battle_result.b_player_name,
												   B#ets_battle_result.b_mount_name,B#ets_battle_result.b_mount_color,								
												   BattleData,
												   B#ets_battle_result.a_mount_type, B#ets_battle_result.b_mount_type])
			end;
		[B|_R] ->
%% 			 ParseData = util:string_to_term(tool:to_list(B#ets_battle_result.init)),
			 {ok,InitBin} = pt_16:write(16043,B#ets_battle_result.init),
			 lib_send:send_to_sid(PidSend, InitBin),
			 {ok,Bin} = pt_16:write(16044, [1,B#ets_battle_result.a_mount_id,B#ets_battle_result.a_player_name,
											B#ets_battle_result.a_mount_name,B#ets_battle_result.a_mount_color,
											B#ets_battle_result.b_mount_id,B#ets_battle_result.b_player_name,
											B#ets_battle_result.b_mount_name,B#ets_battle_result.b_mount_color,
											B#ets_battle_result.battle_data,
											B#ets_battle_result.a_mount_type, B#ets_battle_result.b_mount_type])
	end,
	lib_send:send_to_sid(PidSend, Bin),
	{noreply, State};

%%登陆排名
handle_info({'RANK_BY_LOGIN',Mount,PlayerId,Nickname,Realm,Vip}, State) ->
	Ms = ets:fun2ms(fun(M) when M#ets_mount_arena.mount_id =:= Mount#ets_mount.id -> M end),
	case ets:select(?ETS_MOUNT_ARENA, Ms) of
		[] ->
			%%还没有则插入
			NowNum = State#state.mount_ranker_num,
			NewNum = lib_mount_arena:mount_join_ranker(NowNum,[Mount,PlayerId,Nickname,Realm,Vip]);
		_-> 
			NewNum = State#state.mount_ranker_num
	end,
	{noreply, State#state{mount_ranker_num = NewNum}};

%%领取奖励
handle_info({'GET_AWRD',Player,Mount} , State) ->
	Ms = ets:fun2ms(fun(M) when M#ets_mount_arena.mount_id =:= Mount#ets_mount.id -> M end),
	case ets:select(?ETS_MOUNT_ARENA, Ms) of
		[] ->
			{ok,Bin} = pt_16:write(16048,2),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, Bin);
		[My|_Other] ->
			case My#ets_mount_arena.get_ward_time of
				0 ->
					Data = lib_mount_arena:award_rule_num(My#ets_mount_arena.rank_award),
					case Player#player.other#player_other.pid of
						undefined ->
							skip;
						Pid ->
							Now = util:unixtime(),
							NewM = My#ets_mount_arena{get_ward_time = Now},				
							Pid ! {'MOUNT_GET_AWARD',Data,Mount#ets_mount.id,NewM}
					end;
				_ ->
					{ok,Bin} = pt_16:write(16048,2),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, Bin)
			end
	end,
	{noreply,State};

%%连胜公告
handle_info({'BROAD_WIN',A,WinTimes} , State) ->
	lib_chat:broadcast_sys_msg(1, io_lib:format("<font color = '#FFCF00'>[~s]</font>的~s势如破竹，在斗兽中连胜达到~p次！", [A#ets_mount_arena.player_name,A#ets_mount_arena.mount_name,WinTimes])),
	{noreply,State};

%%第一公告
handle_info({'BROAD_KING',A,B} , State) ->
	lib_chat:broadcast_sys_msg(1, io_lib:format("<font color = '#FFCF00'>[~s]</font>的~s击败了<font color = '#FFCF00'>[~s]</font>的~s，登上了斗兽第一的宝座！", [A#ets_mount_arena.player_name,A#ets_mount_arena.mount_name,B#ets_mount_arena.player_name,B#ets_mount_arena.mount_name])),
	{noreply,State};

%%奖励统计
handle_info({'COUNT_AWRD'}, State) ->
%% 	TodaySec = util:get_today_current_second(),
%% 	case TodaySec =:= ?AWARD_TIME of
%% 		true ->
%% 			lib_mount_arena:create_award(),
%% 			erlang:send_after(1000, self(), {'COUNT_AWRD'});
%% 		false ->
%% 			erlang:send_after(1000, self(), {'COUNT_AWRD'})
%% 	end,
	{Ws,_We} = util:get_this_week_duringtime(),
	%%周二、周五、下周二晚上十一点, 
	{T1,T2} = {Ws+86400+?AWARD_TIME, Ws+4*86400+?AWARD_TIME},
	Now = util:unixtime(),
	case util:get_date() of
		2 ->
			if T1 =:= Now ->
				   lib_mount_arena:create_award(),
				   erlang:send_after(1000, self(), {'COUNT_AWRD'});
			   true ->
				   erlang:send_after(1000, self(), {'COUNT_AWRD'})
			end;
		5 ->
			if T2 =:= Now  ->
				   lib_mount_arena:create_award(),
				   erlang:send_after(1000, self(), {'COUNT_AWRD'});
			   true ->
				   erlang:send_after(1000, self(), {'COUNT_AWRD'})
			end;
		_ ->
			erlang:send_after(60*1000, self(), {'COUNT_AWRD'})
	end,
	{noreply, State};

handle_info({'AFTER_GET_AWARD',NewM}, State) ->
	Now = util:unixtime(),
	ets:insert(?ETS_MOUNT_ARENA, NewM#ets_mount_arena{get_ward_time = Now}),
	db_agent:update_mount_arena([{get_ward_time,Now}],[{id,NewM#ets_mount_arena.id}]),
	{noreply, State};

%%玩家下线清除部分ETS数据
handle_info({'RELEASE_ETS',PlayerId}, State) ->
	Ms = ets:fun2ms(fun(M) when M#ets_mount_arena.player_id =:= PlayerId -> M end),
	case ets:select(?ETS_MOUNT_ARENA, Ms) of
		[] ->
			skip;
		Mys ->
			F = fun(M) ->
						if M#ets_mount_arena.rank =:= 0 orelse 
											M#ets_mount_arena.rank > ?MAX_MOUNT_NUM ->  %%这是500以外的斗兽榜数据，清除
							   catch ets:delete(?ETS_MOUNT_ARENA, M#ets_mount_arena.rank),
							   catch ets:delete(?ETS_MOUNT_RECENT,PlayerId);
						   true ->
							   skip
						end
				end,
			[F(M) || M <- Mys]
	end,
	{noreply, State};

%%凌晨四点清除ETS的战报数据、检查纠正斗兽排行数据（针对坐骑被放生）
handle_info({'CLEARE_BATTLE'}, State) ->
	catch ets:delete_all_objects(?ETS_BATTLE_RESULT),
	%%检查斗兽榜数据，清除被放生坐骑、排名重复的数据
	Nums = lib_mount_arena:load_arena_datas(),
	{noreply, State#state{mount_ranker_num = Nums}};

%%测试删除某个坐骑的战斗信息
handle_info({'test_del',Mid}, State) ->
	catch ets:delete(?ETS_MOUNT_BATTLE, Mid),
	{noreply, State};

handle_info(_Info, State) ->
	%%?DEBUG("_Info = ~p ~n",[_Info]),
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

display_award(Mid)->
	Ms = ets:fun2ms(fun(M) when M#ets_mount_arena.mount_id =:= Mid -> M end),
	case ets:select(?ETS_MOUNT_ARENA, Ms) of
		[]->
			9999999;
		[My|_Other] ->
			case My#ets_mount_arena.get_ward_time =:= 0 of
				true ->
					0;
				false ->
					count_award_time()
			end
	end.

count_award_time() ->
	{Ws,We} = util:get_this_week_duringtime(),
	%%周二、周五、下周二晚上十一点, 
	{T1,T2,T3} = {Ws+86400+?AWARD_TIME, Ws+4*86400+?AWARD_TIME, We+86400+?AWARD_TIME},
	Now = util:unixtime(),
	if Now < T1 ->
		   SendT = T1 - Now,
		   if SendT < 0 ->
				  0;
			  true ->
				  SendT
		   end;
	   Now < T2 ->
		    SendT = T2 - Now,
		   if SendT < 0 ->
				  0;
			  true ->
				  SendT
		   end;
	   Now < T3 ->
		   SendT = T3 - Now,
		   if SendT < 0 ->
				  0;
			  true ->
				  SendT
		   end;
		true ->
			999999999
	end.


