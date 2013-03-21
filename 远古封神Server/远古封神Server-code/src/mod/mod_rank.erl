%%%------------------------------------
%%% @Module     : mod_rank
%%% @Author     : ygzj
%%% @Created    : 2010.10.06
%%% @Description: 排行榜
%%%------------------------------------
-module(mod_rank).
-behaviour(gen_server).
-include("common.hrl").
-include("record.hrl").
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-compile(export_all).

-define(RANK_INTERVAL, 1*60*1000).	  %% 每10分钟 排名一次(1-9分钟分别加载数据)
-define(INIT_RANK_DELAY, 10*1000).    %% 初始化排行榜延时，10秒（10 * 1000 单位：毫秒）


-record(state, {}).
%%%------------------------------------
%%%             接口函数
%%%------------------------------------

start_link() ->      %% 启动服务
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%%动态加载排名处理进程 
get_mod_rank_pid() ->
	ProcessName = mod_rank_process,
	case misc:whereis_name({global, ProcessName}) of
        Pid when is_pid(Pid) ->
            case misc:is_process_alive(Pid) of
                true -> 
                    Pid;
                false -> 
                    start_mod_rank(ProcessName)
            end;
        _ ->
            start_mod_rank(ProcessName)
	end.

%%启动排名模块 (加锁保证全局唯一)
start_mod_rank(ProcessName) ->
	global:set_lock({ProcessName, undefined}),	
	ProcessPid =
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> 
						Pid;
					false -> 
						start_rank()
				end;
			_ ->
				start_rank()
		end,	
	global:del_lock({ProcessName, undefined}),
	ProcessPid.

%%启动排名模块
start_rank() ->
	case supervisor:start_child(
       		yg_server_sup, {mod_rank,
            		{mod_rank, start_link,[]},
               		permanent, 10000, supervisor, [mod_rank]}) of
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
    process_flag(trap_exit, true),
	ProcessName = mod_rank_process,		%% 多节点的情况下， 仅启用一个排名进程
 	case misc:register(unique, ProcessName, self())of
		yes ->
			misc:write_monitor_pid(self(),?MODULE, {}),
			misc:write_system_info(self(), mod_rank, {}),
			
			lib_sys_acm:init_sys_acm(),			%% 系统公告定时器
    		lib_rank:init_rank(),           	%% 创建空排行榜
			%%加载单人镇妖竞技奖励
			lib_rank:init_single_td_award(),
			SingleTdAward = erlang:send_after(lib_rank:single_td_rank_timer()*1000,self(),{'single_td_award'}),
			put(single_td_award,SingleTdAward),
			erlang:send_after(?INIT_RANK_DELAY, self(), {event, timer_1_action, 0}),
			case lib_war:is_war_server() of
				true->
					erlang:send_after(15*60*1000, self(), {sync_war_rank});
				false->skip
			end,
			State = #state{},
			io:format("3.Init mod_rank finish!!!~n"),
			{ok, State};
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
%%  	?DEBUG("mod_rank__apply_call: [~p/~p]", [Module, Method]),	
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_rank__apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method, Info]),
			 error;
		 DataRet -> DataRet
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
			 ?WARNING_MSG("mod_rank__apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
			 error;
		 _ -> ok
	end,
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

%%
%%=================================================================================
%%	手动即时刷新排行榜
%%	警告：此方法只提供给lib_rank:update_rank_rightnow/1使用，
%%  如需使用相似方法，请额外添加
%%=================================================================================
%%
handle_cast({'UPDATE_RANK_RIGHTNOW'}, State) ->
	erlang:spawn(lib_rank, update_rank, []),
	io:format("updated rank ok!\n", []),
	{noreply, State};

%%即时更新魅力排行榜
%%用于情人节活动
handle_cast({'UPDATE_CHARM_RANK_NOW'}, State) ->
	?DEBUG("UPDATE_CHARM_RANK_NOW",[]),
  erlang:spawn(fun()->lib_rank:update_rank(14) end),
  {noreply, State};

%%重启公告
handle_cast({'MORE_SYS_ACM'}, State) ->
	lib_sys_acm:cancel_sys_acm(),
	lib_sys_acm:init_sys_acm(),
	io:format("new sys acm ok!\n", []),
	{noreply, State};

%%取消公告
handle_cast({'CANCLE_SYS_ACM'}, State) ->
	lib_sys_acm:cancel_sys_acm(),
	io:format("cancel sys acm ok!\n", []),
	{noreply, State};

%%播报指定id系统消息
handle_cast({'BROADCAST_ACM',Id},State) ->
	OneAcm = db_agent:get_one_acm(Id),
	case OneAcm of
		[_Id, Acm_type, _Acm_ivl,_Nexttime, Content, Acm_clr, Acm_link, _Acm_times] ->
			Content_link =
				case Acm_link of
						<<>> -> Content;
						<<"http://">> -> Content;
						_ ->
							Content1 = io_lib:format("~s<u><a href='event:3, ~s'><font color='~s'>详情点击</font></a></u>",[util:thing_to_list(Content),util:thing_to_list(Acm_link), util:thing_to_list(Acm_clr)]),
							case catch Content1 of
								{'EXIT', Reason_link} ->
									?WARNING_MSG("do_lost_~p/reason: ~p/~n",[sys_acm_Content_link, Reason_link]),
									Content;
								Val_link ->
									Val_link
							end
				end,
			Content2 = io_lib:format("<font color='~s'>~s</font>",[util:thing_to_list(Acm_clr),util:thing_to_list(Content_link)]),
			NewContent = 
				case catch Content2 of
							{'EXIT', Reason} ->
								?WARNING_MSG("do_lost_~p/reason: ~p/~n",[sys_acm_NewContent, Reason]),
								Content;
							Val ->
								Val						
				end,
			handle_info({broadcast_sys_acm,NewContent,Acm_type},State);
		[]->
			skip
	end,
	{noreply,State};
			
%%存储BOSS被杀时间
handle_cast({boss_killed_time,BossId,KillTime,ReTime}, State) ->
	erlang:put({boss_time,BossId},{KillTime, ReTime}),
    {noreply, State};

%%计算并发送BOSS刷新时间 
handle_cast({boss_refresh_time,SendId}, State) ->
	Now = util:unixtime(),
	Result = get_boss_time(Now),
	{ok, BinData} = pt_30:write(30902, Result),
	lib_send:send_to_sid(SendId, BinData),
    {noreply, State};

%%从掉落表获取boss死亡时间, 用于手工恢复BOSS死亡时间
handle_cast({change_boss_refresh_time}, State) ->
	F = fun(BossId) ->
				case ets:lookup(?ETS_BASE_MON,BossId) of
					[Minfo|_Info] -> 
						case db_agent:query_boss_time(BossId) of
							[KillTime] -> 
								erlang:put({boss_time,BossId},{KillTime, Minfo#ets_mon.retime});
							[] ->
								erlang:put({boss_time,BossId},{0, 0})
						end;
					[] ->
						skip
				end
		end,
	[F(BossId) || BossId <- ?BOSSID],
	{noreply,State};

%%同步跨服战力榜到本地
handle_cast({'war_battvalue_rank',Data},State)->
	spawn(fun()->lib_rank:get_war_rank_to_local(Data)end),
	{noreply,State};

%%回应跨服战力榜请求
handle_cast({answer_war_rank,Data},State)->
	spawn(fun()->lib_rank:answer_war_rank(Data)end),
	{noreply,State};

handle_cast(_Msg, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_info({event, timer_1_action, Order}, State) ->
	spawn(lib_rank, update_rank, [Order]),
	%%国庆活动奖励定时器
	%%spawn(lib_login_prize,hot_fans_award_timer,[]),
	erlang:send_after(?RANK_INTERVAL, self(), {event, timer_1_action, Order + 1}),
	{noreply, State};

%% 系统公告定时器
handle_info({sys_acm}, State) ->
	Now = util:unixtime(),
	Sys_acms = db_agent:get_sys_acm(Now),
	lib_sys_acm:cancel_sys_acm(),
	case length(Sys_acms) > 0 of
		true ->
			F = fun([_Id, Acm_type, Acm_ivl,_Nexttime, Content, Acm_clr, Acm_link, _Acm_times],Acc)   ->				
					Content_link =
						case Acm_link of
								<<>> -> Content;
								<<"http://">> -> Content;
							_ ->
								Content1 = io_lib:format("~s<u><a href='event:3, ~s'><font color='~s'>详情点击</font></a></u>",[util:thing_to_list(Content),util:thing_to_list(Acm_link), util:thing_to_list(Acm_clr)]),
								case catch Content1 of
								{'EXIT', Reason_link} ->
									?WARNING_MSG("do_lost_~p/reason: ~p/~n",[sys_acm_Content_link, Reason_link]),
									Content;
								Val_link ->
									Val_link
							end
						end,
					Content2 = io_lib:format("<font color='~s'>~s</font>",[util:thing_to_list(Acm_clr),util:thing_to_list(Content_link)]),
				 	NewContent = 
						case catch Content2 of
							{'EXIT', Reason} ->
								?WARNING_MSG("do_lost_~p/reason: ~p/~n",[sys_acm_NewContent, Reason]),
								Content;
							Val ->
								Val						
						end,
					if
						Acm_ivl =< 0 ->
							Acm_ivl_e = 1;
						true ->
							Acm_ivl_e = Acm_ivl
					end,
					Acm_timer = erlang:send_after((Acm_ivl_e + Acc) * 60 * 1000 ,self(), {broadcast_sys_acm ,NewContent,Acm_type}),
					%% 将timer引用存入组，用于取消定时器
					case get(acm_timer_group) of
						undefined ->
							put(acm_timer_group,[Acm_timer]);
						Group ->
							put(acm_timer_group,[Acm_timer|Group])
					end,
					Acm_ivl_e + Acc
				end,
			OverTime = lists:foldl(F, 0, Sys_acms),
			misc:cancel_timer(acm_init_timer),
			Acm_init_timer = erlang:send_after(OverTime * 60 * 1000, self(), {sys_acm}),
			put(acm_init_timer, Acm_init_timer);
		false ->
			lib_sys_acm:init_sys_acm()
	end,
	{noreply, State};

%% 发送系统公告
handle_info({broadcast_sys_acm,Msg,Acm_type},State) ->
	%%ps  Acm_type + 3 为类型调整
	{ok, BinData} = pt_11:write(11080, Acm_type + 3, Msg),
	lib_send:send_to_all(BinData),
	{noreply,State};

%%单人镇妖竞技榜
handle_info({'single_td_award'},State)->
	misc:cancel_timer(single_td_award),
	lib_rank:single_td_award(),
	SingleTdAward = erlang:send_after(24*3600*1000,self(),{'single_td_award'}),
	put(single_td_award,SingleTdAward),
	{noreply,State};

%%同步跨服战力排行数据
handle_info({sync_war_rank},State)->
	lib_rank:get_war_rank_to_remote(),
	erlang:send_after(3*3600*1000, self(), {sync_war_rank}),
	{noreply,State};

handle_info(_Info, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()),
	misc:delete_system_info(self()),
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%=========================================================================
%% 业务处理函数
%%=========================================================================
get_role_rank(PidSend,Realm, Career, Sex, Type) ->
 	gen_server:cast(mod_rank:get_mod_rank_pid(), 
							 {apply_cast, lib_rank, get_role_rank_order, [PidSend,Realm, Career, Sex, Type]}).
	

get_equip_rank(PidSend,Type) ->
	gen_server:cast(mod_rank:get_mod_rank_pid(),
							 {apply_cast, lib_rank, get_equip_rank_order, [PidSend,Type]}).


get_guild_rank(PidSend,Type) ->
 	gen_server:cast(mod_rank:get_mod_rank_pid(),
							 {apply_cast, lib_rank, get_guild_rank_order, [PidSend,Type]}).


%%宠物排行榜
get_pet_rank(PidSend) ->
 	gen_server:cast(mod_rank:get_mod_rank_pid(),
							 {apply_cast, lib_rank, get_pet_rank_order, [PidSend]}).

%%氏族战排行
query_guildbat_rank(PidSend) ->
	gen_server:cast(mod_rank:get_mod_rank_pid(),
							 {apply_cast, lib_rank, query_guildbat_rank_order, [PidSend]}).


%%22007 上场个人功勋排行
query_skymem_rank(PidSend) ->
	gen_server:cast(mod_guild:get_mod_guild_pid(), 
						  {apply_cast, lib_skyrush, query_skymem_rank, 
						   [PidSend]}).

%%22010	魅力值排行榜
get_charm_rank(PidSend) ->
	gen_server:cast(mod_rank:get_mod_rank_pid(),
							 {apply_cast, lib_rank, get_charm_rank_order, [PidSend]}).

%% 成就点排行榜
get_achieve_rank(PidSend) ->
	gen_server:call(mod_rank:get_mod_rank_pid(),
							 {apply_call, lib_rank, get_achieve_rank_order, [PidSend]}).

%% 封神台霸主榜
get_fst_god(PidSend) ->
	gen_server:cast(mod_rank:get_mod_rank_pid(),
							 {apply_cast, lib_rank, get_fst_god_order, [PidSend]}).


%% 镇妖台（单）排行榜
get_tds_rank(PidSend) ->
	gen_server:cast(mod_rank:get_mod_rank_pid(),
							 {apply_cast, lib_rank, get_tds_rank_order, [PidSend]}).

rank_single_td_rank(PidSend,PlayerId,Lv,Type)->
	gen_server:cast(mod_rank:get_mod_rank_pid(),
							 {apply_cast, lib_rank, get_tds_rank_order_all, [PidSend,PlayerId,Lv,Type]}).
get_single_td_award(PlayerStatus)->
	gen_server:cast(mod_rank:get_mod_rank_pid(),
							 {apply_cast, lib_rank, award_single_td_get, [PlayerStatus]}).

single_td_award_cmd()->
	gen_server:cast(mod_rank:get_mod_rank_pid(),
							 {apply_cast, lib_rank, single_td_award, []}).
single_td_rank_cmd()->
	gen_server:cast(mod_rank:get_mod_rank_pid(),
							 {apply_cast, lib_rank, sigle_td_rank_cmd, []}).

cmd_single_td_rank(PlayerId,Rank)->
	gen_server:cast(mod_rank:get_mod_rank_pid(),
							 {apply_cast, lib_rank, cmd_single_td_rank, [PlayerId,Rank]}).
	

%% 镇妖台（多）排行榜
get_tdm_rank(PidSend) ->
	gen_server:call(mod_rank:get_mod_rank_pid(),
							 {apply_call, lib_rank, get_tdm_rank_order, [PidSend]}).


%%从进程字典里取BOSS刷新剩余时间，顺序按照 ?BOSSID 的顺序
get_boss_time(Now) ->
	Times = lists:map(fun(E)->case get({boss_time, E}) of
                                {Time,ReTime} -> {E,{Time,ReTime}};
                                undefined -> {E,{0,0}} 
                              end 
                      end, ?BOSSID),
	count_boss_time(Times,[],Now).

count_boss_time([],Result,_Now) ->
    lists:reverse(Result);
count_boss_time([H|T],Result,Now) ->
    {BossId,{LastKill,ReTime}} = H,
    TimeInter = Now-LastKill,
	ReTimeSecond = ReTime div 1000,
    case TimeInter>ReTimeSecond of
         true -> 
			 count_boss_time(T,[{BossId,0}|Result],Now);
         false -> count_boss_time(T,[{BossId,ReTimeSecond-TimeInter}|Result],Now)
    end.


%%总排行战场总排行和周排行RankType(1周战绩排行	2总战绩排行)
rank_arena_query(PidSend,RankType) ->
	gen_server:cast(mod_rank:get_mod_rank_pid(),
							 {apply_cast, mod_arena_supervisor, rank_total_arena_query_order, [PidSend,RankType]}).

%% 诛仙台霸主榜
get_zxt_god(PidSend) ->
	gen_server:cast(mod_rank:get_mod_rank_pid(),
							 {apply_cast, lib_rank, get_zxt_god_order, [PidSend]}).

%%查询某人战斗力的排名(只查询前100名中的名次，返回结果超过0说明没有给其排名)
get_batt_value_place(PlayerId) ->
	try
		case gen_server:call(mod_rank:get_mod_rank_pid(),
							 {apply_call, lib_rank, get_batt_value_place, [PlayerId]}) of
			error ->
				0;
			Data ->
				Data
		end
	catch
		_:_ ->
			0
	end.

%%神器战力排行
rank_deputy_equip_rank(PidSend) ->
	gen_server:cast(mod_rank:get_mod_rank_pid(),
							 {apply_cast, lib_rank, rank_deputy_equip_rank_order, [PidSend]}) .

%%坐骑战力排行
rank_mount_rank(PidSend) ->
	gen_server:cast(mod_rank:get_mod_rank_pid(),
							 {apply_cast, lib_rank, rank_mount_rank, [PidSend]}) .



