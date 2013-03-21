%%%------------------------------------
%%% @Module  : mod_guild
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 氏族处理 
%%%------------------------------------
-module(mod_guild).
-behaviour(gen_server).
-include("common.hrl").
-include("record.hrl").
-include("guild_info.hrl").
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-compile(export_all).

%%=========================================================================
%% 一些定义
%%=========================================================================


-record(state, {worker_id = 0}).

%% 定时器1间隔时间
-define(TIMER_1, 10*1000).

%%=========================================================================
%% 接口函数
%%=========================================================================
start_link([ProcessName, Worker_id]) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [ProcessName, Worker_id], []).

start([ProcessName, Worker_id]) ->
    gen_server:start_link(?MODULE, [ProcessName, Worker_id], []).

stop() ->
    gen_server:call(?MODULE, stop).

%% 动态加载氏族处理进程 
get_mod_guild_pid() ->
	ProcessName = misc:create_process_name(guild_p, [0]),
	case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true ->
						WorkerId = random:uniform(?GUILD_WORKER_NUMBER),
						ProcessName_1 = misc:create_process_name(guild_p, [WorkerId]),
 						misc:whereis_name({global, ProcessName_1});						
					false -> 
						start_mod_guild(ProcessName)
				end;
			_ ->
				start_mod_guild(ProcessName)
	end.

%% 获取报名氏族战的专用进程ID
get_mod_guild_pid_for_apply() ->
	ProcessName = misc:create_process_name(guild_p, [25]),
	case misc:whereis_name({global, ProcessName}) of
		Pid when is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true ->
					Pid;
				false ->
					mod_guild:start_mod_guild(ProcessName)
			end;
		_ ->
			mod_guild:start_mod_guild(ProcessName)
	end.

%%启动氏族监控模块 (加锁保证全局唯一)
start_mod_guild(ProcessName) ->
	global:set_lock({ProcessName, undefined}),	
	ProcessPid =
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true -> 
						WorkerId = random:uniform(?GUILD_WORKER_NUMBER),
						ProcessName_1 = misc:create_process_name(guild_p, [WorkerId]),
 						misc:whereis_name({global, ProcessName_1});						
					false -> 
						start_guild(ProcessName)
				end;
			_ ->
				start_guild(ProcessName)
		end,	
	global:del_lock({ProcessName, undefined}),
	ProcessPid.

%%启动氏族监控树模块
start_guild(ProcessName) ->
	case supervisor:start_child(
       		yg_server_sup, {mod_guild,
            		{mod_guild, start_link,[[ProcessName, 0]]},
               		permanent, 10000, supervisor, [mod_guild]}) of
		{ok, Pid} ->
				Pid;
		_e ->
			?WARNING_MSG("mod_guild_start_error:~p~n",[_e]),
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
init([ProcessName, Worker_id]) ->
	process_flag(trap_exit, true),
 	case misc:register(unique, ProcessName, self()) of%% 多节点的情况下， 仅在一个节点启用氏族处理进程
		yes ->
			if 
				Worker_id =:= 0 ->
					
    			ets:new(?ETS_GUILD, [{keypos,#ets_guild.id}, named_table, public, set,?ETSRC, ?ETSWC]),               %%氏族
    			ets:new(?ETS_GUILD_MEMBER, [{keypos,#ets_guild_member.id}, named_table, public, set,?ETSRC, ?ETSWC]), %%氏族成员
    			ets:new(?ETS_GUILD_APPLY, [{keypos,#ets_guild_apply.id}, named_table, public, set,?ETSRC, ?ETSWC]),   %%氏族申请
    			ets:new(?ETS_GUILD_INVITE, [{keypos,#ets_guild_invite.id}, named_table, public, set,?ETSRC, ?ETSWC]), %%氏族邀请
    			ets:new(?ETS_LOG_GUILD, [{keypos, #ets_log_guild.id}, named_table, public, set,?ETSRC, ?ETSWC]),	   %%氏族事件日志
    			ets:new(?ETS_GUILD_SKILLS_ATTRIBUTE, [{keypos, #ets_guild_skills_attribute.id}, named_table, public, set,?ETSRC, ?ETSWC]),%%氏族技能表
				ets:new(?ETS_GUILD_UPGRADE_STATUS, [{keypos, #ets_guild_upgrade_status.guild_id}, named_table, public, set,?ETSRC, ?ETSWC]), %%氏族正在升级记录总汇
			
				ets:new(?GUILD_SKYRUSH_RANK, [{keypos, #guild_skyrush_rank.guild_id}, named_table, public, set,?ETSRC, ?ETSWC]),%%空岛神战氏族排行版
				ets:new(?GUILD_MEM_SKYRUSH_RANK, [{keypos, #guild_mem_skyrush_rank.player_id}, named_table, public, set,?ETSRC, ?ETSWC]),%%空岛神战个人排行版
				ets:new(?GUILD_UNION, [{keypos, #guild_union.id}, named_table, public, set,?ETSRC, ?ETSWC]),	%%氏族结盟/归附表
				ets:new(?MEMBER_GWISH, [{keypos, #mem_gwish.pid}, named_table, public, set,?ETSRC, ?ETSWC]),	%%%%氏族成员的氏族祝福运势数据
				
				ets:new(?ETS_CASTLE_RUSH_JOIN, [{keypos, #ets_castle_rush_join.guild_id}, named_table, public, set,?ETSRC, ?ETSWC]),	%% 攻城战氏族报名列表
				ets:new(?ETS_CASTLE_RUSH_INFO, [{keypos, #ets_castle_rush_info.id}, named_table, public, set,?ETSRC, ?ETSWC]),	%% 攻城战信息
				ets:new(?ETS_CASTLE_RUSH_RANK, [{keypos, #ets_castle_rush_rank.id}, named_table, public, set,?ETSRC, ?ETSWC]),	%% 攻城战排行
				ets:new(?ETS_CASTLE_RUSH_GUILD_SCORE, [{keypos, #ets_castle_rush_guild_score.guild_id}, named_table, public, set,?ETSRC, ?ETSWC]),	%% 攻城战 -- 氏族战功
				ets:new(?ETS_CASTLE_RUSH_HARM_SCORE, [{keypos, #ets_castle_rush_harm_score.guild_id}, named_table, public, set,?ETSRC, ?ETSWC]),	%% 攻城战 -- 伤害积分
				ets:new(?ETS_CASTLE_RUSH_PLAYER_SCORE, [{keypos, #ets_castle_rush_player_score.player_id}, named_table, public, set,?ETSRC, ?ETSWC]),	%% 攻城战 -- 个人战功
				ets:new(?ETS_CASTLE_RUSH_AWARD_MEMBER, [{keypos, #ets_castle_rush_award_member.guild_id}, named_table, public, set,?ETSRC, ?ETSWC]),	%% 攻城战奖励成员 
				
				ets:new(?GUILD_ALLIANCE, [{keypos, #ets_g_alliance.id}, named_table, public, set,?ETSRC, ?ETSWC]),					%% 氏族联盟表
				ets:new(?GUILD_ALLIANCE_APPLY, [{keypos, #ets_g_alliance_apply.id}, named_table, public, set,?ETSRC, ?ETSWC]),		%% 氏族联盟申请表
				
				
				%% 加载所有氏族并且对应加载升级记录
    			lib_guild_inner:load_all_guild(),
				%%加载所有的氏族技能属性
				lib_guild_inner:load_all_guild_skills_attribute(),
				%%加载氏族日志，加载最近三天的日志，三天前的日志即可删除
				lib_guild_inner:load_all_guild_log(),	
				%%加载氏族仓库(仅初始化表)
				lib_guild_warehouse:init_guild_warehouse(),
				%%加载氏族高级技能
				lib_guild_weal:load_all_guild_h_skills(),
				%%加载所有的氏族结盟/归附数据
				lib_guild_union:load_all_guild_union(),
				
				%% 加载攻城战初始数据
				lib_castle_rush:init_castle_rush_info(),
				%%5秒之后加载氏族联盟的数据
				erlang:send_after(5000, self(), {'LOAD_GUILD_ALLIANCE_DATA'}),
				GuildTime = erlang:send_after(?TIMER_1, self(), {event, timer_1_action, 0}),
				put(timer_1_action, GuildTime),%%放进程字典
				
				misc:write_monitor_pid(self(),?MODULE, {?GUILD_WORKER_NUMBER}),
				misc:write_system_info(self(), mod_guild, {}),	
				%% 启动多个场景服务进程
				io:format("1.Init mod_guild finish!!!~n"),
				lists:foreach(
				fun(WorkerId) ->
					ProcessName_1 = misc:create_process_name(guild_p, [WorkerId]),
					mod_guild:start([ProcessName_1, WorkerId])
				end,
				lists:seq(1, ?GUILD_WORKER_NUMBER));			
				true -> 
					misc:write_monitor_pid(self(), mod_guild_worker, {Worker_id})
			end,
			State= #state{worker_id = Worker_id},
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
  %%	%% ?DEBUG("*****  mod_guild__apply_call: [~p,~p]   *****", [Module, Method]),	
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_guild__apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
			 error;
		 DataRet -> DataRet
	end,
    {reply, Reply, State};
%%获取帮派成员的相关信息
handle_call({'get_guild_member_info', [GuildId, PlayerId]}, _From, State) ->
	Result = 
		case lib_guild_inner:get_guild(GuildId) of
			[] ->
				{0,0};
			Guild ->
				case lib_guild_inner:get_guild_member_by_guildandplayer_id(GuildId, PlayerId) of
					[] ->
						{0, 0};
					GuildMember ->
						{Guild#ets_guild.level, GuildMember#ets_guild_member.donate_total}
				end
		end,
	{reply, Result, State};

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
 	%% ?DEBUG("*****   mod_guild__apply_cast: [~p,~p]   *****", [Module, Method]),	
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_guild__apply_cast error: Module=~p, Method=~p, Reason=~p",[Module, Method, Info]),
			 error;
		 _ -> ok
	end,
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

%%神战结束后处理
handle_cast({'UPDATE_SKYRUSH_INFO', GFeats,MFeats,NowTime}, State) ->
	lib_skyrush:handle_gfeats(GFeats, MFeats, NowTime),
	lib_skyrush:handle_mfeats(MFeats, NowTime),
%% 	RankList = lib_skyrush:rank_guild_member_feats(),
%% 	{ok, Data39021} = pt_39:write(39021, [RankList]),%%全场景的人通知
%% 	spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39021) end),
	{noreply, State};

%%打开氏族群聊面板
handle_cast({'OPEN_GUILD_GROUP',Player},State) ->
	case ets:lookup(?ETS_GUILD, Player#player.guild_id) of
		[] -> 
			{ok,BinData} = pt_40:write(40080,[0,"",[]]);
		[Guild|_Other] ->
			case lib_guild_inner:get_guild_member_by_guild_id(Player#player.guild_id) of
				[] -> 
					{ok,BinData} = pt_40:write(40080,[0,"",[]]);
				Members ->		
					{ok,BinData} = pt_40:write(40080,[1,Guild#ets_guild.announce,Members])
			end
	end,
	lib_send:send_to_uid(Player#player.id, BinData),	
	{noreply, State};

%%氏族成员上下线通知群聊面板
handle_cast({'MEMBER_ONLINE_FLAG',Flag,GuildId,PlayerId},State) ->
	case lib_guild_inner:get_guild(GuildId) of
			[] ->skip;
			_Guild ->
				{ok,BinData} = pt_40:write(40081,[PlayerId,Flag]),
				case lib_guild_inner:get_guild_member_by_guild_id(GuildId) of
					[] ->skip;
					GuildMembers ->
						F = fun(Uid)-> 
									%%更新群聊面板成员在线状态
									lib_send:send_to_uid(Uid, BinData)
									end,
						[F(M#ets_guild_member.player_id) || M <- GuildMembers]
				end
	end,
	{noreply, State};

%%氏族有成员加入、退出，设置官职，修改公告，刷新群聊面板
handle_cast({'BROADCAST_GUILD_GROUP',GuildId},State) ->
	case lib_guild_inner:get_guild(GuildId) of
			[] ->skip;
			Guild ->
				case lib_guild_inner:get_guild_member_by_guild_id(GuildId) of
					[] ->skip;
					GuildMembers ->
						{ok,BinData} = pt_40:write(40080,[1,Guild#ets_guild.announce,GuildMembers]),
						F = fun(Uid)-> 
									%%更新群聊面板信息
									lib_send:send_to_uid(Uid, BinData)
									end,
						[F(M#ets_guild_member.player_id) || M <- GuildMembers]
				end
	end,
	{noreply, State};

%%新成员加入，在群聊面板广播
handle_cast({'BROADCAST_NEW_MEMBER',GuildId,PlayerName},State) ->
	case lib_guild_inner:get_guild(GuildId) of
			[] ->skip;
			_Guild ->
				case lib_guild_inner:get_guild_member_by_guild_id(GuildId) of
					[] ->skip;
					GuildMembers ->
						{ok,BinData} = pt_40:write(40082,[PlayerName]),
						F = fun(Uid)-> 
									%%发送新成员名字
									lib_send:send_to_uid(Uid, BinData)
									end,
						[F(M#ets_guild_member.player_id) || M <- GuildMembers]
				end
	end,
	{noreply, State};

		
%%GM命令用于增加氏族经验
handle_cast({'update_guild_info', NewGuild}, Status) ->
	lib_guild_inner:update_guild(NewGuild),
	{noreply, Status};

	
handle_cast(_Msg, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%%延时加载联盟数据
handle_info({'LOAD_GUILD_ALLIANCE_DATA'}, State) ->
	%%加载氏族联盟表
	lib_guild_alliance:load_guild_alliance(),
	%%加载氏族联盟申请表
	lib_guild_alliance:load_guild_alliance_apply(),
%% 	?DEBUG("OK!!!!!!!!!!!", []),
	{noreply, State};

handle_info({event, timer_1_action, Type}, State) ->
	NowSec = util:get_today_current_second(),
%%     io:format("guild upgrade! check ~p~n", [NowSec]),
	%%氏族战处理
	NewType = lib_skyrush:start_skyrush(Type, NowSec),
%% 	%%温泉开放处理(挪走到mod_title)
%% 	HSTYpe = lib_spring:start_spring(HSType, NowSec),
	
	%% 攻城战处理
	lib_castle_rush:start_castle_rush(NowSec),
	
	%% 野外BOSS刷新检测
%% 	spawn(fun()-> lib_mon:check_wild_boss_time(NowSec, round(?TIMER_1 / 1000)) end),
	
%% 	NewType = 0,
	%%氏族升级处理
	handle_timer_action(),
	NowTime = util:unixtime(),
	%%过期的氏族联盟处理
	lib_guild_union:handle_union_timeout(NowTime),
	%%中秋节亲密度礼品包(屏蔽掉)
%% 	lib_relationship:check_give_mid_close(NowTime),
	%%处理超时的氏族联盟申请
	lib_guild_alliance:handle_alliances_apply_timeout(NowTime),
	%%先去掉定时器.
	misc:cancel_timer(timer_1_action),
	GuildTime = erlang:send_after(?TIMER_1, self(), {event, timer_1_action, NewType}),
	put(timer_1_action, GuildTime),%%放进程字典
	{noreply, State};

%%通知氏族联盟更新的数据
handle_info({'UPDATE_GUILD_ALLIANCES', SourGid, SourAlliance, DestGid, DestAlliance}, State) ->
	lib_guild_alliance:send_member_alliances(SourGid, SourAlliance),
	lib_guild_alliance:send_member_alliances(DestGid, DestAlliance),
	{noreply, State};

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
%% -----------------------------------------------------------------
%% 定时处理事务
%% -----------------------------------------------------------------
handle_timer_action() ->
    {{_Year, _Month, _Day}, {Hour, _Min, _Sec}} = calendar:local_time(),
	%%做氏族升级处理
	lib_guild_inner:handle_guild_upgrade_record(),
    % 每天凌晨4点到6点，且隔30分钟收取一次
    if  ((Hour >= 4) and (Hour =< 6)) ->
%% 	if  ((Hour >= 0) and (Hour =< 24)) ->
			lib_guild_inner:handle_daily_consume(),		%% 处理收取每日氏族消耗
			lib_guild_inner:handle_delete_guild_logs();		%%清理过期的氏族日志（三天前）
        true ->
            no_action
    end.


%% -----------------------------------------------------------------
%% 40001 创建氏族
%% -----------------------------------------------------------------
create_guild(Status, [GuildName, BuildCoin]) ->
	%%%% ?DEBUG("********* mod_guild:create_guld begin *******",[]),
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_guild, create_guild, 
						 	[							 	
								 Status#player.guild_id,
								 Status#player.lv,
								 Status#player.coin,
								 Status#player.bcoin,
								 Status#player.other#player_other.pid_goods,
								 Status#player.id, 
								 Status#player.nickname, 
								 Status#player.realm,
								 Status#player.other#player_other.pid,
								[GuildName, BuildCoin]
							]})	of
			 error -> 
				 %% ?DEBUG("40001 create_guild error",[]),
				 [0, 0];
			 Data -> 
				 %% ?DEBUG("40001 create_guild succeed:[~p]",[Data]),
				 Data
		end			
	catch
		_:_Reason -> 
			%% ?DEBUG("40001 create_guild for the reason:[~p]",[_Reason]),
			[0, 0]
	end.

%% -----------------------------------------------------------------
%% 40002 解散氏族
%% -----------------------------------------------------------------
confirm_disband_guild(Status, [GuildId]) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_guild, confirm_disband_guild, 
						 [Status#player.id,
						  Status#player.nickname,
						  Status#player.guild_id, 
						   Status#player.guild_name, 
						   Status#player.guild_position, 
						  [GuildId]]})	of
			 error -> 
				 %% ?DEBUG("40002 confirm_disband_guild error",[]),
				 0;
			 Data -> 
				 %% ?DEBUG("40002 confirm_disband_guild succeed:[~p]",[Data]),
				 Data
		end		
	catch
		_:_Reason -> 
			%% ?DEBUG("40002 confirm_disband_guild fail for the reason:[~p]",[_Reason]),
			0
	end.

%% -----------------------------------------------------------------
%% 40004 申请加入氏族
%% -----------------------------------------------------------------
apply_join_guild(Status, [GuildId]) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_guild, apply_join_guild, 
						 [	Status#player.id,
							Status#player.nickname,
							Status#player.guild_id,
							Status#player.realm,
							Status#player.lv,
							Status#player.quit_guild_time,
							Status#player.other#player_other.pid,
							Status#player.sex,
							Status#player.jobs,
							Status#player.career,
							Status#player.vip,
						  	[GuildId]]})	of
			 error -> 
				 %% ?DEBUG("40004 apply_join_guild error",[]),
				 [2];
			 Data ->
				 %% ?DEBUG("40004 apply_join_guild succeed:[~p]",[Data]),
				 Data
		end		
	catch
		_:_Reason -> 
			%% ?DEBUG("40004 apply_join_guild fail for the reason:[~p]",[_Reason]),
			[2]
	end.

%% -----------------------------------------------------------------
%% 40005 审批加入氏族
%% -----------------------------------------------------------------
approve_guild_apply(Status, [HandleResult, ApplyList]) ->
		%%因为涉及到并发问题，此操作专门使用Id号为0的进程执行
	ProcessName = misc:create_process_name(guild_p, [0]),
	GuildPid = 
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true ->
						Pid;
					false ->
						start_mod_guild(ProcessName)
				end;
			_ ->
				start_mod_guild(ProcessName)
		end,
	try 
		case gen_server:call(GuildPid, 
						{apply_call, lib_guild, approve_guild_apply, 
						 	[Status#player.guild_id, 
							  Status#player.guild_name, 
							  Status#player.guild_position, 
							 [HandleResult, ApplyList]]}) of
			 error -> 
				 %% ?DEBUG("40005 approve_guild_apply error",[]),
				 [0, 0];
			 Data -> 
				 %% ?DEBUG("40005 approve_guild_apply succeed:[~p]",[Data]),
				 Data
		end			
	catch
		_:_Reason -> 
			%% ?DEBUG("40005 approve_guild_apply fail for the reason:[~p]",[_Reason]),
			[0, 0]
	end.

%% -----------------------------------------------------------------
%% 40006 邀请加入氏族
%% -----------------------------------------------------------------
invite_join_guild(Status, [PlayerName]) when is_record(Status, player)->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_guild, invite_join_guild, 
						 	[ Status#player.id,
							  Status#player.guild_id, 
							  Status#player.realm, 
							  Status#player.nickname,  
							  Status#player.guild_position, 
							 [PlayerName]]}) of
			 error -> 
				 %% ?DEBUG("40006 invite_join_guilde error",[]),
				 [0, 0];
			 Data -> 
				 %% ?DEBUG("40006 invite_join_guild succeed:[~p]",[Data]),
				 Data
		end			
	catch
		_:_Reason -> 
			%% ?DEBUG("40006 invite_join_guild fail for the reason:[~p]",[_Reason]),
			[0, 0]
	end.

%% -----------------------------------------------------------------
%% 40007 回应氏族邀请
%% -----------------------------------------------------------------
response_invite_guild(Status, [GuildId, ResponseResult]) ->
%% 	response_invite_guild(My_id, My_guild_id, My_nickname, PlayerSex, PlayerJobs, PlayerLevel, 
%% 					  PlayerLastLoginTime, PlayerOnlineFlag, PlayerCareer, PlayerCulture,
%% 					  [GuildId, ResponseResult])
	
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_guild, response_invite_guild, 
						 	[Status#player.id, 
							 Status#player.guild_id, 
							 Status#player.nickname,
							 Status#player.sex,
							 Status#player.jobs,
							 Status#player.lv,
							 Status#player.last_login_time,
							 Status#player.online_flag,
							 Status#player.career,
							 Status#player.culture,
							 Status#player.vip,
							 [GuildId, ResponseResult]]}) of
			 error -> 
				 %% ?DEBUG("40007 response_invite_guild error",[]),
				 [2, <<>>, 0, 0, <<>>];
			 Data -> 
				 %% ?DEBUG("40007 response_invite_guild succeed:[~p]",[Data]),
				 Data
		end			
	catch
		_:_Reason -> 
			%% ?DEBUG("40007 response_invite_guild fail for the reason:[~p]",[_Reason]),
			[2, <<>>, 0, 0, <<>>]
	end.

%% -----------------------------------------------------------------
%% 40008 开除帮众
%% PlayerId:指定的氏族成员
%% -----------------------------------------------------------------
kickout_guild(Status, [PlayerId]) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_guild, kickout_guild, 
						 	[	Status#player.id,
								Status#player.nickname,
								Status#player.guild_id,
								Status#player.guild_position,
								Status#player.guild_depart_id,							 
							 [PlayerId]]}) of
			 error -> 
				 %% ?DEBUG("40008 kickout_guild error",[]),
				 [2, <<>>];
			 Data -> 
				 %% ?DEBUG("40008 kickout_guild succeed:[~p]",[Data]),
				 Data
		end			
	catch
		_:_Reason -> 
			%% ?DEBUG("40008 kickout_guild fail for the reason:[~p]",[_Reason]),
			[2, <<>>]
	end.

%% -----------------------------------------------------------------
%% 40009 退出氏族
%% -----------------------------------------------------------------
quit_guild(Status, [QuitTime]) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_guild, quit_guild, 
						 	[Status#player.id, 
							 Status#player.nickname, 
							 Status#player.guild_id, 
							 Status#player.guild_position,							 
							 [QuitTime]]}) of
			 error -> 
				 %% ?DEBUG("40009 quit_guil error",[]),
				 2;
			 Data -> 
				 %% ?DEBUG("40009 quit_guild succeed:[~p]",[Data]),
				 Data
		end			
	catch
		_:_Reason -> 
			%% ?DEBUG("40009 quit_guild fail for the reason:[~p]",[_Reason]),
			2
	end.

%% -----------------------------------------------------------------
%% 40010 获取氏族列表
%% -----------------------------------------------------------------
list_guild(Status, [Realm, Type, Page, GuildName, ChiefName]) ->
%% ?DEBUG("list_guild: realm=[~p], GuildName=[~s], ChiefName = [~s]~n", [Realm, GuildName, ChiefName]),
	gen_server:cast(mod_guild:get_mod_guild_pid(), 
					{apply_cast, lib_guild_inner, get_guild_page, 
					 [Status#player.other#player_other.pid_send,
					  Status#player.guild_id, Realm, Type, Page, GuildName, ChiefName]}).

%% -----------------------------------------------------------------
%% 40011 获取成员列表
%% -----------------------------------------------------------------
list_guild_member(Status, [GuildId]) ->
%% ?DEBUG("**** mod_guild:list_guild_member: GuildId=[~p] ****", [GuildId]),
	gen_server:cast(mod_guild:get_mod_guild_pid(), 
					{apply_cast, lib_guild_inner, get_guild_member_page, 
					 [Status#player.other#player_other.pid_send, GuildId]}).

%% -----------------------------------------------------------------
%% 40012 获取申请列表
%% -----------------------------------------------------------------
list_guild_apply(Status, [GuildId]) ->
    %% ?DEBUG("list_guild_apply: GuildId=[~p]~n", [GuildId]),
	gen_server:cast(mod_guild:get_mod_guild_pid(), 
					{apply_cast, lib_guild_inner, get_guild_apply_page, 
					 [Status#player.other#player_other.pid_send,
					  GuildId]}).	

%% -----------------------------------------------------------------
%% 40013 获取邀请列表
%% -----------------------------------------------------------------
list_guild_invite(Status, [PlayerId]) ->
    %% ?DEBUG("**** list_guild_invite: PlayerId=[~p] **** ", [PlayerId]),
	gen_server:cast(mod_guild:get_mod_guild_pid(), 
					{apply_cast, lib_guild_inner, get_guild_invite_page, 
					 [Status#player.other#player_other.pid_send,
					  PlayerId]}).	

%% -----------------------------------------------------------------
%% 40014 获取氏族信息
%% -----------------------------------------------------------------
get_guild_info(_Status, [GuildId]) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_guild_inner, get_guild_info, 
						 [GuildId]})	of
			 error -> 
				 %% ?DEBUG("40014 get_guild_info error",[]),
				 [2, {}];
			 Data -> 
				 Data
		end			
	catch
		_:_Reason -> 
			%% ?DEBUG("40014 get_guild_info fail for the reason:[~p]",[_Reason]),
			[2, {}]
	end.

%% -----------------------------------------------------------------
%% 40016 修改氏族公告
%% -----------------------------------------------------------------
modify_guild_announce(Status, [GuildId, Announce]) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_guild, modify_guild_announce, 
						 [Status#player.guild_id, 
						  Status#player.guild_position,
						  [GuildId, Announce]]})	of
			 error -> 
				 %% ?DEBUG("40016 modify_guild_announce error",[]),
				 [0];
			 Data -> 
				 %% ?DEBUG("40016 modify_guild_announce succeed:[~p]",[Data]),
				 Data
		end			
	catch
		_:_Reason -> 
			%% ?DEBUG("40016 modify_guild_announce fail for the reason:[~p]", [_Reason]),
			[0]
	end.

%% -----------------------------------------------------------------
%% 40018 禅让族长
%% -----------------------------------------------------------------
demise_chief(Status, [PlayerId]) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_guild, demise_chief, 
						 [Status#player.id, 
						  Status#player.nickname, 
						  Status#player.guild_id, 
						  Status#player.guild_position,
						  [PlayerId]]})	of
			 error -> 
				 %% ?DEBUG("40018 demise_chief error",[]),
				 [0, <<>>];
			 Data -> 
				 %% ?DEBUG("40018 demise_chief succeed:[~p]",[Data]),
				 Data
		end			
	catch
		_:_Reason -> 
			%% ?DEBUG("40018 demise_chief fail for the reason:[~p]", [_Reason]),
			[0, <<>>]
	end.

%% -----------------------------------------------------------------
%% 40019 捐献钱币
%% -----------------------------------------------------------------
donate_money(Status, [GuildId, Num]) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_guild, donate_money, 
						 [Status, [GuildId, Num]]})	of
			 error -> 
				 %% ?DEBUG("40019 donate_moneye error",[]),
				 [0, Status];
			 Data -> 
%% 				 %% ?DEBUG("40019 donate_money succeed:[~p]",[Data]),
				 Data
		end			
	catch
		_:_Reason -> 
			%% ?DEBUG("40019 donate_money fail for the reason:[~p]", [_Reason]),
			[0, Status]
	end.

%% -----------------------------------------------------------------
%% 40020 氏族升级请求
%% -----------------------------------------------------------------
guild_upgrade(Status,[GuildId]) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_guild, guild_upgrade, 
						 [Status#player.guild_id, 
						  Status#player.lv,
						  Status#player.guild_position,
						  [GuildId]]})	of
			 error -> 
				 %% ?DEBUG("40020 guild_upgrade error",[]),
				 [0, 0, 0, 0];
			 Data -> 
				 %% ?DEBUG("40020 guild_upgrade succeed:[~p]",[Data]),
				 Data
		end			
	catch
		_:_Reason -> 
			%% ?DEBUG("40020 guild_upgrade fail for the reason:[~p]", [_Reason]),
			[0, 0, 0, 0]
	end.

%% -----------------------------------------------------------------
%% 40022 辞去官职
%% -----------------------------------------------------------------
resign_position(Status, [GuildId]) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_guild, resign_position, 
						 [Status#player.id, 
						  Status#player.nickname, 
						  Status#player.guild_id, 
						  Status#player.guild_position,
						  [GuildId]]})	of
			 error -> 
				 %% ?DEBUG("40022 resign_position error",[]),
				 [0, Status#player.guild_position];
			 Data -> 
				 %% ?DEBUG("40022 resign_position succeed:[~p]",[Data]),
				 Data
		end			
	catch
		_:_Reason -> 
			%% ?DEBUG("40022 resign_position fail for the reason:[~p]", [_Reason]),
			[0, Status#player.guild_position]
	end.

%% -----------------------------------------------------------------
%%40028 成员职务设置
%% -----------------------------------------------------------------
set_member_post(Status, [GuildId, PlayerId, Post, DepartId, GuildTitle, DepartName]) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_guild_inner, set_member_post, 
						 [Status#player.id, 
						  Status#player.nickname,
						  Status#player.guild_id,
						  Status#player.guild_position,
						  [GuildId, PlayerId, Post, DepartId, GuildTitle, DepartName]]})	of
			 error -> 
				 %% ?DEBUG("40028 set_member_post error",[]),
				 [0, <<>>, 0, ""];
			 Data -> 
				 %% ?DEBUG("40028 set_member_post succeed:[~p]",[Data]),
				 Data
		end			
	catch
		_:_Reason -> 
			%% ?DEBUG("40028 set_member_post fail for the reason:[~p]", [_Reason]),
			[0, <<>>, 0, ""]
	end.

%% -----------------------------------------------------------------
%% 40029 修改氏族堂堂名
%% -----------------------------------------------------------------
modify_guild_depart_name(Status, [GuildId, DepartId, DepartName, DepartsNames]) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_guild, modify_guild_depart_name, 
						 [Status#player.guild_id,
						  Status#player.guild_position,
						  [GuildId, DepartId, DepartName, DepartsNames]]})	of
			 error -> 
				 %% ?DEBUG("40029 modify_guild_depart_name error",[]),
				 [0];
			 Data -> 
				 %% ?DEBUG("40029 modify_guild_depart_name succeed:[~p]",[Data]),
				 Data
		end			
	catch
		_:_Reason -> 
			%% ?DEBUG("40029 modify_guild_depart_name fail for the reason:[~p]", [_Reason]),
			[0]
	end.


%% -----------------------------------------------------------------
%% 40031 获取氏族技能信息
%% -----------------------------------------------------------------
get_guild_skills_info(Status, [GuildId]) ->
%% 	?DEBUG("get_guild_skill_info", []),
	gen_server:cast(mod_guild:get_mod_guild_pid(), 
					{apply_cast, lib_guild, get_guild_skills_info, 
					 [Status#player.guild_id,
					  Status#player.guild_position,
					  Status#player.other#player_other.pid_send,
					  [GuildId]]}).



%% -----------------------------------------------------------------
%% 40032 氏族技能升级
%% -----------------------------------------------------------------
guild_skills_upgrade(Status, [GuildId, SkillId, Level]) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_guild, guild_skills_upgrade, 
						 [Status#player.guild_id,
						  Status#player.guild_position,
						  [GuildId, SkillId, Level]]})	of
			 error -> 
				 %% ?DEBUG("40032 guild_skills_upgrade error",[]),
				 [0, Level];
			 Data -> 
				 %% ?DEBUG("40032 guild_skills_upgrade succeed:[~p]",[Data]),
				 Data
		end			
	catch
		_:_Reason -> 
			%% ?DEBUG("40032 guild_skills_upgrade fail for the reason:[~p]", [_Reason]),
			[0, Level]
	end.



%% -----------------------------------------------------------------
%% 获取氏族排名信息
%% -----------------------------------------------------------------
rank_guild() ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_rank, rank_guild, []})	of
			 error -> [];
			 Data -> Data
		end			
	catch
		_:_ -> []
	end.	

%% -----------------------------------------------------------------
%% 查询人物相关属性排行(honor), 从氏族里
%% -----------------------------------------------------------------
query_roles_honor(Realm, Career, Sex, honor) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_rank, query_roles_honor, 
						 [Realm, Career, Sex, honor]}) of
			error ->
				[];
			Result -> 
				Result
		end			
	catch
		_:_ -> []
	end.	

%% -----------------------------------------------------------------
%% 角色登录时的氏族处理
%% -----------------------------------------------------------------
role_login(PlayerId, GuildId, LastLoginTime) ->
	try 
		gen_server:cast(mod_guild:get_mod_guild_pid(), 
						{apply_cast, lib_guild_inner, role_login, [PlayerId, GuildId, LastLoginTime]})
	catch
		_:_ -> []
	end.

%% -----------------------------------------------------------------
%% 角色退出时的氏族处理
%% -----------------------------------------------------------------
role_logout(PlayerId) ->
	try 
		gen_server:cast(mod_guild:get_mod_guild_pid(), 
						{apply_cast, lib_guild_inner, role_logout, [PlayerId]})
	catch
		_:_ -> []
	end.

%% -----------------------------------------------------------------
%% 删除角色时的氏族处理
%% -----------------------------------------------------------------
delete_role(PlayerId) ->
	try 
		gen_server:cast(mod_guild:get_mod_guild_pid(), 
						{apply_cast, lib_guild_inner, delete_role, [PlayerId]})
	catch
		_:_ -> []
	end.

%% -----------------------------------------------------------------
%% 更新氏族成员缓存
%% -----------------------------------------------------------------
role_upgrade(PlayerId, Lv) ->
	try 
		gen_server:cast(mod_guild:get_mod_guild_pid(), 
						{apply_cast, lib_guild_inner, role_upgrade, [PlayerId, Lv]})
	catch
		_:_ -> []
	end.

%% -----------------------------------------------------------------
%% 更新氏族成员缓存,玩家vip更新
%% -----------------------------------------------------------------
role_vip_update(PlayerId, Vip) ->
	try 
		gen_server:cast(mod_guild:get_mod_guild_pid(), 
						{apply_cast, lib_guild_inner, role_vip_update, [PlayerId, Vip]})
	catch
		_:_ -> []
	end.

%% -----------------------------------------------------------------
%% 氏族建设卡增加帮贡
%% -----------------------------------------------------------------
add_donation(PlayerId, Contrib) ->
	try 
		gen_server:cast(mod_guild:get_mod_guild_pid(), 
						{apply_cast, lib_guild_inner, add_donation, [PlayerId, Contrib]})
	catch
		_:_ -> []
	end. 

%% -----------------------------------------------------------------
%% 获取氏族等级
%% -----------------------------------------------------------------
get_guild_lev_by_id(GuildId) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_guild_inner, get_guild_lev_by_id, [GuildId]}) of
			error ->
				[];
			Result -> 
				Result
		end			
	catch
		_:_ -> []
	end. 

%% -----------------------------------------------------------------
%% 获取氏族日志
%% -----------------------------------------------------------------
get_log_guild(GuildId) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_guild_inner, get_log_guild, [GuildId]}) of
			error ->
				[0,[]];
			Result -> 
				Result
		end			
	catch
		_:_ -> [0,[]]
	end. 

%% -----------------------------------------------------------------
%%氏族福利，氏族成员战斗结束后，可额外获得原经验的2%*k
%% -----------------------------------------------------------------
get_guild_battle_exp(GuildId, ExpBase) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_guild_inner, get_guild_battle_exp, [GuildId, ExpBase]}) of
			error ->
				ExpBase;
			Result -> 
				Result
		end			
	catch
		_:_ -> ExpBase
	end. 

%% -----------------------------------------------------------------
%% 做帮派任务，添加帮派经验，
%% -----------------------------------------------------------------
increase_guild_exp(PlayerId, GuildId, Exp, Contribute, AddFunds,Type) ->
	%%因为涉及到并发问题，此操作专门使用Id号为33的进程执行
	ProcessName = misc:create_process_name(guild_p, [33]),
	GuildPid = 
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true ->
						Pid;
					false ->
						start_mod_guild(ProcessName)
				end;
			_ ->
				start_mod_guild(ProcessName)
		end,
	try 
		gen_server:cast(GuildPid, {apply_cast, lib_guild, increase_guild_exp, [PlayerId, GuildId, Exp, Contribute, AddFunds,Type]})
	catch
		_:_ -> []
	end.


%% ====================================================================
%% External functions(氏族仓库接口)
%% ====================================================================
%% -----------------------------------------------------------------
%% 40050 获取氏族仓库当前物品总数
%% -----------------------------------------------------------------
get_storage_num(Status, GuildId) ->
	gen_server:cast(mod_guild:get_mod_guild_pid(), 
					{apply_cast, lib_guild_warehouse, get_storage_num, 
					 [Status#player.other#player_other.pid_send,
					  Status#player.guild_id,
					  GuildId]}).

%% -----------------------------------------------------------------
%% 40051 获取氏族仓库物品列表
%% -----------------------------------------------------------------
get_guild_goods(Status, GuildId) ->
	gen_server:cast(mod_guild:get_mod_guild_pid(), 
					{apply_cast, lib_guild_warehouse, get_guild_goods, 
					 [Status#player.other#player_other.pid_send,
					  Status#player.guild_id,
					  GuildId]}).

%% -----------------------------------------------------------------
%% 40052 取出氏族仓库物品
%% -----------------------------------------------------------------
takeout_warehouse_goods(Status,GuildId, GoodsId) ->
	%%因为涉及到并发问题，此操作专门使用Id号为10的进程执行
	ProcessName = misc:create_process_name(guild_p, [10]),
	GuildPid = 
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true ->
						Pid;
					false ->
						mod_guild:start_mod_guild(ProcessName)
				end;
			_ ->
				mod_guild:start_mod_guild(ProcessName)
		end,
	try 
		case gen_server:call(GuildPid, 
							 {apply_call, lib_guild_warehouse, takeout_warehouse_goods, 
							  [Status#player.guild_id,
							   Status#player.guild_position,
							   GuildId, GoodsId,
							   Status#player.other#player_other.pid_goods,
							   Status#player.id]})	of
			error -> 
				0;
			Data -> 
				Data
		end			
	catch
		_:_Reason -> 
			?ERROR_MSG("takeout_warehouse_goods fail for the reason:[~p]", [_Reason]),
			0
	end.

%% -----------------------------------------------------------------
%% 40053 放入氏族仓库物品
%% -----------------------------------------------------------------
putin_warehouse_goods(Status, GuildId, GoodsId) ->
		%%因为涉及到并发问题，此操作专门使用Id号为10的进程执行
	ProcessName = misc:create_process_name(guild_p, [10]),
	GuildPid = 
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true ->
						Pid;
					false ->
						mod_guild:start_mod_guild(ProcessName)
				end;
			_ ->
				mod_guild:start_mod_guild(ProcessName)
		end,
	try 
		case gen_server:call(GuildPid, 
							 {apply_call, lib_guild_warehouse, putin_warehouse_goods, 
							  [Status#player.guild_id,
							   GuildId, GoodsId,
							   Status#player.other#player_other.pid_goods,
							   Status#player.id]})	of
			error -> 
				0;
			Data -> 
				Data
		end			
	catch
		_:_Reason -> 
			?ERROR_MSG("putin_warehouse_goods fail for the reason:[~p]", [_Reason]),
			0
	end.

%% -----------------------------------------------------------------
%% 40054 获取物品详细信息(仅在氏族模块用)
%% -----------------------------------------------------------------
get_warehouse_goods_info(Status, GuildId, GoodsId) ->
%% 	?DEBUG("get_warehouse_goods_info11111111111111111", []),
	gen_server:cast(mod_guild:get_mod_guild_pid(),
				   {apply_cast, lib_guild_warehouse, get_warehouse_goods_info, 
					[Status#player.other#player_other.pid_send,
					 Status#player.guild_id,
					 Status#player.guild_position,
					 GuildId, GoodsId]}).

%%获取氏族运镖相关信息
get_guild_carry_info(GuildId)->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(),
						{apply_call, lib_guild, get_guild_carry_info, 
						 [GuildId]}) of
			error -> 
				 [0, {}];
			 Data -> 
				 Data
		end			
	catch
		_:_Reason -> 
			?ERROR_MSG("get_guild_carry_info fail for the reason:[~p]", [_Reason]),
			[0, {}]
	end.

%%更新氏族运镖信息
update_guild_carry_info(PlayerStatus,Type)->
	gen_server:cast(mod_guild:get_mod_guild_pid(), 
					{apply_cast, lib_guild, update_guild_carry_info, 
					 [PlayerStatus#player.guild_id, 
					  PlayerStatus#player.other#player_other.pid_send,
					  Type]}).

%%更新氏族劫镖信息
update_guild_bandits_info(PlayerId,CarryGuildId,BanditsGuildId)->
	gen_server:cast(mod_guild:get_mod_guild_pid(), 
					{apply_cast, lib_guild, update_guild_bandits_info,
					 [PlayerId,CarryGuildId,BanditsGuildId]}).

%%使用弹劾令，对应氏族进程Id为12
accuse_chief(PlayerId, PlayerName, GuildId, GPosit) ->
	ProcessName = misc:create_process_name(guild_p, [12]),
	GuildPid = 
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true ->
						Pid;
					false ->
						mod_guild:start_mod_guild(ProcessName)
				end;
			_ ->
				mod_guild:start_mod_guild(ProcessName)
		end,
	try 
		case gen_server:call(GuildPid, 
						{apply_call, lib_guild, accuse_chief_inner, 
						 [PlayerId, PlayerName, GuildId, GPosit]})	of
			error -> 
				 {error, 0};
			 Data -> 
				 Data
		end			
	catch
		_:_Reason -> 
			?ERROR_MSG("accuse_chief fail for the reason:[~p]", [_Reason]),
			{error, 0}
	end.

%%氏族改名
change_guildname(Status,[GuildId, NewGuildName]) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_guild, change_guildname, 
						 [Status#player.id,
						  Status#player.other#player_other.pid_goods,
						  Status#player.guild_id,GuildId, NewGuildName]})	of
			 error -> 
				 0;
			 Data -> 
				 Data
		end			
	catch
		_:_Reason -> 
			0
	end.

%% -----------------------------------------------------------------
%%更新帮派角色名
%% -----------------------------------------------------------------
change_player_name(PlayerId,Guild_id,NewNickName) ->
	try 
		if Guild_id == 0 ->
			   skip;
		   true ->
			   gen_server:cast(mod_guild:get_mod_guild_pid(), {apply_cast, lib_guild_inner, change_player_name, [PlayerId,Guild_id,NewNickName]})
		end
	catch
		_:_ -> []
	end.

%% -----------------------------------------------------------------
%% 40057  氏族兼并/归附申请
%% -----------------------------------------------------------------
union_apply(Status ,TarGId, Type) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
							 {apply_call, lib_guild_union, union_apply, 
							  [Status#player.id,
							   Status#player.guild_id,
							   Status#player.guild_position,
							   TarGId,Type]}) of
			error ->
				0;
			Data->
				Data
		end
	catch
		_:_Reason -> 
			?ERROR_MSG("union_apply fail for the reason:[~p]", [_Reason]),
			0
	end.

%% -----------------------------------------------------------------
%% 40058  取消氏族兼并/归附申请
%% -----------------------------------------------------------------
cancel_union_apply(Status, TarGId) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
							 {apply_call, lib_guild_union, cancel_union_apply, 
							  [Status#player.id,
							   Status#player.guild_id,
							   Status#player.guild_position,
							   TarGId]}) of
			error ->
				0;
			Data ->
				Data
		end
	catch
		_:_Reason -> 
			?ERROR_MSG("cancel_union_apply fail for the reason:[~p]", [_Reason]),
			0
	end.

%% -----------------------------------------------------------------
%% 40059  拒绝氏族兼并/归附申请
%% -----------------------------------------------------------------
refuse_unioin_apply(Status, TarGId) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
							 {apply_call, lib_guild_union, refuse_unioin_apply, 
							  [Status#player.id,
							   Status#player.guild_id,
							   Status#player.guild_position,
							   TarGId]}) of
			error ->
				0;
			Data ->
				Data
		end
	catch
		_:_Reason -> 
			?ERROR_MSG("refuse_unioin_apply fail for the reason:[~p]", [_Reason]),
			0
	end.

%% -----------------------------------------------------------------
%% 40060  同意氏族兼并/归附申请
%% -----------------------------------------------------------------
agree_union_apply(Status, TarGId, Type) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
							 {apply_call, lib_guild_union, agree_union_apply, 
							  [Status#player.id,
							   Status#player.guild_id,
							   Status#player.guild_position,
							   TarGId, Type]}) of
			error ->
				0;
			Data ->
				Data
		end
	catch
		_:_Reason -> 
			?ERROR_MSG("agree_union_apply fail for the reason:[~p]", [_Reason]),
			0
	end.

%% -----------------------------------------------------------------
%% 40061  氏族联合请求(返回40063或者40062)
%% -----------------------------------------------------------------
get_union_info(Status) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
							 {apply_call, lib_guild_union, get_union_info, 
							  [Status#player.guild_id]}) of
			error ->
				{1,{[],[]}};%%进程爆掉了,默认传个40062
			Data ->
				Data
		end
	catch
		_:_Reason -> 
			?ERROR_MSG("get_union_info fail for the reason:[~p]", [_Reason]),
			{1,{[],[]}}%%错误了,默认传个40062
	end.

%% -----------------------------------------------------------------
%% 40064  兼并/依附氏族族长提交成员列表
%% -----------------------------------------------------------------
submit_union_members(Status, Handle, SubmitList) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
							 {apply_call, lib_guild_union, submit_union_members, 
							  [Status#player.id,
							   Status#player.guild_id,
							    Status#player.guild_position,
							   Handle, SubmitList]}) of
			error ->
				{0, 0, 0};
			Data ->
				Data
		end
	catch
		_:_Reason -> 
			?ERROR_MSG("submit_union_members fail for the reason:[~p]", [_Reason]),
			{0, 0, 0}
	end.	

%% -----------------------------------------------------------------
%% 40088 发出氏族联盟申请
%% -----------------------------------------------------------------
apply_guild_alliance(Status, TarGid) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
							 {apply_call, lib_guild_alliance, apply_alliance, 
							  [Status#player.id, Status#player.guild_id, 
							   TarGid]}) of
			error ->
				0;
			Data ->
				Data
		end
	catch
		_:_Reason -> 
			?ERROR_MSG("apply guild alliance fail for the reason:[~p]", [_Reason]),
			0
	end.	
	
%% -----------------------------------------------------------------
%% 40089 取消氏族联盟申请
%% -----------------------------------------------------------------
cancel_guild_alliance(Status, TarGid) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
							 {apply_call, lib_guild_alliance, cancel_alliance, 
							  [Status#player.id, Status#player.guild_id, 
							   TarGid]}) of
			error ->
				0;
			Data ->
				Data
		end
	catch
		_:_Reason -> 
			?ERROR_MSG("cancel guild alliance fail for the reason:[~p]", [_Reason]),
			0
	end.

%% -----------------------------------------------------------------
%% 40090 同意氏族联盟申请
%% -----------------------------------------------------------------
aggree_guild_alliance(Status, TarGid) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
							 {apply_call, lib_guild_alliance, agree_alliance, 
							  [Status#player.id, Status#player.guild_id, 
							   TarGid]}) of
			error ->
				0;
			Data ->
				Data
		end
	catch
		_:_Reason -> 
			?ERROR_MSG("cancel guild alliance fail for the reason:[~p]", [_Reason]),
			0
	end.

%% -----------------------------------------------------------------
%% 40091 拒绝氏族联盟申请
%% -----------------------------------------------------------------
refuse_guild_alliance(Status, TarGid) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
							 {apply_call, lib_guild_alliance, refuse_alliance, 
							  [Status#player.id, Status#player.guild_id, 
							   TarGid]}) of
			error ->
				0;
			Data ->
				Data
		end
	catch
		_:_Reason -> 
			?ERROR_MSG("refuse guild alliance fail for the reason:[~p]", [_Reason]),
			0
	end.

%% -----------------------------------------------------------------
%% 40092 中止氏族联盟关系
%% -----------------------------------------------------------------
stop_guild_alliance(Status, TarGid) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
							 {apply_call, lib_guild_alliance, stop_alliance, 
							  [Status#player.id, Status#player.guild_id, 
							   TarGid]}) of
			error ->
				0;
			Data ->
				Data
		end
	catch
		_:_Reason -> 
			?ERROR_MSG("refuse guild alliance fail for the reason:[~p]", [_Reason]),
			0
	end.

%% -----------------------------------------------------------------
%% 40093 获取指定的氏族的氏族信息
%% -----------------------------------------------------------------
get_target_guild(Status, GuildId) ->
	gen_server:cast(mod_guild:get_mod_guild_pid(), 
							 {apply_cast, lib_guild, get_target_guild, 
							  [Status#player.other#player_other.pid_send, GuildId]}).
