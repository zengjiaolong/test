%%%-----------------------------------
%%% @Module  : yg_server
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 游戏服务器
%%%-----------------------------------
-module(yg_server).
-export([start/1]).
-compile([export_all]).

start([Ip, Port, Node_id]) ->
	io:format("init start..\n"),
	misc:write_system_info(self(), tcp_listener, {Ip, Port, now()}),
	
	inets:start(),
	
    ok = start_kernel(),							%% 开启核心服务
	ok = start_rand(),								%% 随机种子
	ok = start_mon(),								%% 开启怪物监控树
    ok = start_npc(),								%% 开启npc监控树
    ok = start_task(),								%% 开启任务监控树
    ok = start_mail(),								%% 开启邮件监控树
    ok = start_client(),							%% 开启客户端连接监控树
	ok = start_flash_843(),							%% 开启 flash策略文件请求服务
    ok = start_tcp(Port),							%% 开启tcp listener监控树
	ok = start_scene_agent(),						%% 开启场景代理监控树
	ok = start_box(),								%% 开启诛邪系统进程监控树,
	ok = start_box_log(),							%% 开启诛邪系统日志进程;	
	ok = start_random_realm(), 						%% 开启选择部落监控树	
    ok = start_disperse([Ip, Port, Node_id]),		%% 开启服务器路由，连接其他节点	
	ok = start_scene(),								%% 开启本节点场景(按照配置文件)
	ok = start_local_cache(),						%% 开启本节点缓存进程
%%     ok = start_delayer(),%%开启延时信息监控树
	timer:sleep(1000),
	
	%%普通全局进程，分配到节点1
	
	%%开启延时信息监控树
	start_node_application(start_delayer,[], 1, Node_id),		
	%%开启市场监控树	
	start_node_application(start_sale,[], 1, Node_id),
	%%开启商城监控树					
	start_node_application(start_shop, [],1, Node_id),
	%%开启在线统计监控树		
	start_node_application(start_online_count,[],1,Node_id),
	%%开启师徒关系控制树
	start_node_application(start_master_apprentice, [],1, Node_id),
	%%开启vip监控树
	start_node_application(start_vip,[],1,Node_id),
	%%开启委托监控树
	start_node_application(start_consign, [],1, Node_id),
	%% 跨服通信服务端模块
	start_node_application(start_leap_server, [], 1, Node_id),
	%%递增ID服务
	start_node_application(start_auto_id,[],1,Node_id),
	%%开启求购监控树
	start_node_application(start_buy,[],1,Node_id),
	%%开启队伍招募服务
	start_node_application(start_team_raise,[], 1, Node_id),	
	
	%%活动全局进程，分配到独立节点 2
	
	%%开启氏族监控树	
	start_node_application(start_guild,[], 2, Node_id),
	%%开启氏族监控树	
	start_node_application(start_title,[], 2, Node_id),
	%%开启国运监控树
	start_node_application(start_carry,[], 2, Node_id),
	%%开启排行榜监控树
	start_node_application(start_rank,[], 2, Node_id),
	%% 开启战场控制树
	start_node_application(start_arena, [], 2, Node_id),
	%% 开启竞技场控制树
	start_node_application(start_coliseum, [], 2, Node_id),
	%% 开启挖矿监控树				
	start_node_application(start_ore_sup,[],2,Node_id),								
	%%开启答题监控树
	start_node_application(start_answer,[], 2, Node_id),
	%%开启跨服战场监控树
	start_node_application(start_war_supervisor,[],2,Node_id),
	%%开启评价监控树
	start_node_application(start_appraise,[], 2, Node_id),
	%% 跨服通信客户端模块
	start_node_application(start_leap_client, [], 2, Node_id),
	%% 开启婚宴监控树
	start_node_application(start_wedding, [], 2, Node_id),
	%%开启特殊活动进程
	start_node_application(start_event_process, [], 2, Node_id),
	%%开启斗兽进程
	start_node_application(start_mount_arena, [], 2, Node_id),
	%%开启全局缓存进程
	start_node_application(start_global_cache, [], 2, Node_id),
	%%开启跨服单人竞技监控树
	start_node_application(start_war2_server,[],2,Node_id),
	io:format("the global Pro ok! Please start the next node.. \n"),
	ok.	

%%开启核心服务
    %%初始ets表
    %%初始mysql
    %%初始化物品类型及规则列表
    %%经脉列表
start_kernel() ->
    {ok,_} = supervisor:start_child(
               yg_server_sup,
               {mod_kernel,
                {mod_kernel, start_link,[]},
                permanent, 10000, supervisor, [mod_kernel]}),
    ok.

%%随机种子
start_rand() ->
    {ok,_} = supervisor:start_child(
               yg_server_sup,
               {mod_rand,
                {mod_rand, start_link,[]},
                permanent, 10000, supervisor, [mod_rand]}),
    ok.

%%开启怪物监控树
start_mon() ->
    {ok, _} = supervisor:start_child(
               yg_server_sup,
               {mod_mon_create,
                {mod_mon_create, start_link,[]},
                permanent, 10000, supervisor, [mod_mon_create]}),
    ok.

%%开启npc监控树
start_npc() ->
    {ok,_} = supervisor:start_child(
               yg_server_sup,
               {mod_npc_create,
                {mod_npc_create, start_link,[]},
                permanent, 10000, supervisor, [mod_npc_create]}),
    ok.

%%开启任务监控树
start_task() ->
    {ok,_} = supervisor:start_child(
               yg_server_sup,
               {mod_task_cache,
                {mod_task_cache, start_link,[]},
                permanent, 10000, supervisor, [mod_task_cache]}),
    ok.

%%开启氏族监控树
start_guild() ->
	_Pid = mod_guild:get_mod_guild_pid(),
	ok.

%%开启邮件监控树
start_mail() ->
    {ok,_} = supervisor:start_child(
               yg_server_sup,
               {mod_mail,
                {mod_mail, start_link,[]},
                permanent, 10000, supervisor, [mod_mail]}),
    ok.

%%开启排行榜监控树
start_rank() ->
	_Pid = mod_rank:get_mod_rank_pid(),	
    ok.

%%开启延时信息监控树
start_delayer() ->
	_Pid = mod_delayer:get_mod_delayer_pid(),	
    ok.

%开启交易市场监控树
start_sale() ->
	_Pid = mod_sale:get_mod_sale_pid(),
	ok.

%%开启商城监控树
start_shop() ->
	_Pid = mod_shop:get_mod_shop_pid(),
	ok.

%%开启在线统计监控树
start_online_count()->
	_Pid = mod_online_count:get_mod_online_count_pid(),
	ok.

%开启国运监控树
start_carry() ->
	%_Pid = mod_carry:get_mod_carry_pid(),
	ok.
%% 	 {ok,_} = supervisor:start_child(
%%                yg_server_sup,
%%                {mod_carry,
%%                 {mod_carry, start_link,[]},
%%                 permanent, 10000, supervisor, [mod_carry]}),
%%     ok.

%开启选择部落监控树
start_random_realm()->
	{ok,_} = supervisor:start_child(
               yg_server_sup,
               {mod_random_realm,
                {mod_random_realm, start_link,[]},
                permanent, 10000, supervisor, [mod_random_realm]}),
    ok.

%%开启诛邪系统进程监控树
start_box() ->
	{ok,_} = supervisor:start_child(
               yg_server_sup,
               {mod_box,
                {mod_box, start_link,[]},
                permanent, 10000, supervisor, [mod_box]}),
    ok.

%%开启诛邪系统日志进程
start_box_log() ->
	{ok,_} = supervisor:start_child(
               yg_server_sup,
               {mod_box_log,
                {mod_box_log, start_link,[]},
                permanent, 10000, supervisor, [mod_box_log]}),
    ok.

%%开启场景代理监控树
start_scene_agent() ->
    {ok,_} = supervisor:start_child(
               yg_server_sup,
               {mod_scene_agent,
                {mod_scene_agent, start_link, [{mod_scene_agent, 0}]},
                permanent, 10000, supervisor, [mod_scene_agent]}),
    ok.

%% 开启本节点场景(按照配置文件)
start_scene() ->
	lists:foreach(fun(SId)->  
				  	mod_scene:get_scene_pid(SId, undefined, undefined)
				  end, 
				  config:get_scene_here(server)),
	ok.

%%开启师徒关系监控树 
start_master_apprentice() ->
	_Pid = mod_master_apprentice:get_mod_master_apprentice_pid(),
	ok.

%% 开启战场控制树
start_arena() ->
 	_Pid = mod_arena_supervisor:get_mod_arena_supervisor_pid(),
 	ok.

%% 开启竞技场控制树
start_coliseum() ->
 	_Pid = mod_coliseum_supervisor:get_mod_coliseum_supervisor_pid(),
 	ok.

start_answer() ->
	_Pid = mod_answer:get_mod_answer_pid(),
 	ok.

%%玩家评价
start_appraise() ->
	_Pid = mod_appraise:get_mod_appraise_pid(),
 	ok.

%%开启委托监控树
start_consign()->
	_Pid = mod_consign:get_mod_consign_pid(),
	ok.

%%开启VIP监控树
start_vip()->
	_Pid = mod_vip:get_mod_vip_pid(),
	ok.


%% 开启挖矿监控树
start_ore_sup() ->
	mod_ore_sup:get_mod_ore_pid(),
	ok.

%%开启委托监控树
start_war_supervisor()->
	_Pid = mod_war_supervisor:get_mod_war_supervisor_pid(),
	ok.

%%开启婚宴
start_wedding()->	
	_Pid = mod_wedding:get_mod_wedding_pid(),	
	ok.

%%开启特殊活动进程
start_event_process() ->
	%%周年活动时间
	{_ST, ET} = lib_activities:all_may_day_time(),
	NowTime = util:unixtime(),
	case NowTime =< ET of
		true ->
			_Pid = mod_quizzes:get_quizzes_pid(),
			ok;
		false ->
			ok
	end.

%%开启客户端监控树
start_client() ->
    {ok,_} = supervisor:start_child(
               yg_server_sup,
               {yg_tcp_client_sup,
                {yg_tcp_client_sup, start_link,[]},
                transient, infinity, supervisor, [yg_tcp_client_sup]}),
    ok.

%开启全服称号处理监控树
start_title() ->
	_Pid = mod_title:get_mod_title_pid(),
	ok.

%%开启843flash安全测试文件服务
start_flash_843()->
	yg_flash_843:start_link(),
	ok.

%%开启tcp listener监控树
start_tcp(Port) ->
    {ok,_} = supervisor:start_child(
               yg_server_sup,
               {yg_tcp_listener_sup,
                {yg_tcp_listener_sup, start_link, [Port]},
                transient, infinity, supervisor, [yg_tcp_listener_sup]}),
    ok.

%%开启多线
start_disperse([Ip, Port, Node_id]) ->
    {ok,_} = supervisor:start_child(
               yg_server_sup,
               {mod_disperse,
                {mod_disperse, start_link,[Ip, Port, Node_id]},
                permanent, 10000, supervisor, [mod_disperse]}),
    ok.

%% 跨服通信服务端模块
start_leap_server() ->
	_Pid = mod_leap_server:get_mod_leap_server_pid(),
	ok.

%% 跨服通信客户端模块
start_leap_client() ->
	_Pid = mod_leap_client:get_mod_leap_client_pid(),
	ok.

%% 递增ID服务
start_auto_id() ->
	_Pid = mod_auto_id:get_autoid_pid(),
	ok.

%%开启求购监控树
start_buy() ->
	_Pid = mod_buy:get_buy_pid(),
	ok.

%%队伍招募模块
start_team_raise()->
	_Pid = mod_team_raise:get_mod_team_raise_pid(),
	ok.

%%跨服单人竞技服务
start_war2_server()->
	_Pid = mod_war2_supervisor:get_mod_war2_supervisor_pid(),
	ok.

%% 开启本节点缓存进程
start_local_cache() ->
	_Pid = mod_cache:get_local_cache_pid(),
	ok.

%% 开启全局节点缓存进程
start_global_cache() ->
	_Pid = mod_cache:get_global_cache_pid(),
	ok.

%%开启斗兽进程
start_mount_arena() ->
%% 	io:format("Format start_mount_arena.....................~n ", []),
	_Pid = mod_mount_arena:get_mod_mount_arena_pid(),
%% 	io:format("Format finish.....................~n ", []),
	ok.

start_node_application(Fun, Item,Type, NodeId) ->
	case NodeId =:= Type of
		true ->
			erlang:apply(?MODULE,Fun, Item);
		false ->
			skip
	end.
