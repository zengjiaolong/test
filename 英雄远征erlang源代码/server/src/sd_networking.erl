%%%-----------------------------------
%%% @Module  : sd_networking
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.06.1
%%% @Description: 网络
%%%-----------------------------------
-module(sd_networking).
-export([start/1]).

start([Ip, Port, Sid]) ->
    ok = start_kernel(),
    ok = start_disperse([Ip, Port, Sid]),
    ok = start_rand(),
    ok = start_client(),
    ok = start_tcp(Port),
    ok = start_mon(),
    ok = start_npc(),
    ok = start_scene(),
    ok = start_task(),
    ok = start_guild(),
    ok = start_pet(),
    ok = start_mail(),
    ok = start_rank(),
    ok = start_timer().

%%开启核心服务
start_kernel() ->
    {ok,_} = supervisor:start_child(
               sd_sup,
               {mod_kernel,
                {mod_kernel, start_link,[]},
                permanent, 10000, supervisor, [mod_kernel]}),
    ok.

%%开启多线
start_disperse([Ip, Port, Sid]) ->
    {ok,_} = supervisor:start_child(
               sd_sup,
               {mod_disperse,
                {mod_disperse, start_link,[Ip, Port, Sid]},
                permanent, 10000, supervisor, [mod_disperse]}),
    ok.

%%随机种子
start_rand() ->
    {ok,_} = supervisor:start_child(
               sd_sup,
               {mod_rand,
                {mod_rand, start_link,[]},
                permanent, 10000, supervisor, [mod_rand]}),
    ok.


%%开启客户端监控树
start_client() ->
    {ok,_} = supervisor:start_child(
               sd_sup,
               {sd_tcp_client_sup,
                {sd_tcp_client_sup, start_link,[]},
                transient, infinity, supervisor, [sd_tcp_client_sup]}),
    ok.

%%开启tcp listener监控树
start_tcp(Port) ->
    {ok,_} = supervisor:start_child(
               sd_sup,
               {sd_tcp_listener_sup,
                {sd_tcp_listener_sup, start_link, [Port]},
                transient, infinity, supervisor, [sd_tcp_listener_sup]}),
    ok.

%%开启怪物监控树
start_mon() ->
    {ok,_} = supervisor:start_child(
               sd_sup,
               {mod_mon_create,
                {mod_mon_create, start_link,[]},
                permanent, 10000, supervisor, [mod_mon_create]}),
    ok.
%%开启npc监控树
start_npc() ->
    {ok,_} = supervisor:start_child(
               sd_sup,
               {mod_npc_create,
                {mod_npc_create, start_link,[]},
                permanent, 10000, supervisor, [mod_npc_create]}),
    ok.

%%开启场景监控树
start_scene() ->
    {ok,_} = supervisor:start_child(
               sd_sup,
               {mod_scene,
                {mod_scene, start_link,[]},
                permanent, 10000, supervisor, [mod_scene]}),
    ok.

%%开启任务监控树
start_task() ->
    {ok,_} = supervisor:start_child(
               sd_sup,
               {mod_task,
                {mod_task, start_link,[]},
                permanent, 10000, supervisor, [mod_task]}),
    ok.

%%开启定时器监控树
start_timer() ->
    {ok,_} = supervisor:start_child(
               sd_sup,
               {timer_frame,
                {timer_frame, start_link,[]},
                permanent, 10000, supervisor, [timer_frame]}),
    ok.

%%开启帮派监控树
start_guild() ->
    {ok,_} = supervisor:start_child(
               sd_sup,
               {mod_guild,
                {mod_guild, start_link,[]},
                permanent, 10000, supervisor, [mod_guild]}),
    ok.

%%开启宠物监控树
start_pet() ->
    {ok,_} = supervisor:start_child(
               sd_sup,
               {mod_pet,
                {mod_pet, start_link,[]},
                permanent, 10000, supervisor, [mod_pet]}),
    ok.

%%开启邮件监控树
start_mail() ->
    {ok,_} = supervisor:start_child(
               sd_sup,
               {mod_mail,
                {mod_mail, start_link,[]},
                permanent, 10000, supervisor, [mod_mail]}),
    ok.

%%开启排行榜监控树
start_rank() ->
    {ok,_} = supervisor:start_child(
               sd_sup,
               {mod_rank,
                {mod_rank, start_link,[]},
                permanent, 10000, supervisor, [mod_rank]}),
    ok.
