%%%-----------------------------------
%%% @Module  : lib_task
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.05.05
%%% @Description: 任务
%%%-----------------------------------
-module(lib_task).
-compile(export_all).

-include("common.hrl").
-include("record.hrl").

%% 从数据库加载角色的任务数据
flush_role_task(PS) ->
    case get_trigger(PS) =/= [] orelse get_finish(PS) =/= [] of
        true -> true;   %% 已经加载过就不再加载
        false ->
            RoleTaskList = db_sql:get_all(<<"select * from task_bag where role_id=?">>, [PS#player_status.id]),
            [
                ets:insert(?ETS_ROLE_TASK, #role_task{id={PS#player_status.id, Tid}, role_id=PS#player_status.id, task_id=Tid, trigger_time = Tt, state = S, end_state = ES, mark = binary_to_term(M)})
                || [_, Tid, Tt, S ,ES, M] <-RoleTaskList
            ],
            RoleTaskLogList = db_sql:get_all(<<"select * from task_log where role_id=?">>, [PS#player_status.id]),
            [
                ets:insert(?ETS_ROLE_TASK_LOG, #role_task_log{role_id=PS#player_status.id, task_id=Tid2, trigger_time = Tt2, finish_time = Ft2})
                || [_, Tid2, Tt2, Ft2] <-RoleTaskLogList
            ],
            refresh_active(PS)
    end.

%% 角色下线操作
offline(PS) ->
    %% 清除ets缓存
    ets:match_delete(?ETS_TASK_QUERY_CACHE, PS#player_status.id),
    ets:match_delete(?ETS_ROLE_TASK, #role_task_log{role_id=PS#player_status.id, _='_'}),
    ets:match_delete(?ETS_ROLE_TASK_LOG, #role_task_log{role_id=PS#player_status.id, _='_'}).

%% 刷新任务并发送更新列表
refresh_task(PS) ->
    refresh_active(PS),
    lib_scene:refresh_npc_ico(PS),
    lib_conn:pack_send(PS#player_status.socket, 30006, []).

%% 遍历所有任务看是否可接任务
refresh_active(PS) ->
    Tids = data_task:get_ids(),
    ActiveTids = [Tid || Tid<-Tids, can_trigger(Tid, PS)],
    %ActiveTids2 = case srv_yunbiao:can_trigger(1000000, PS) of
    %    true -> [1000000];
    %   _ -> []
    %end,
    ActiveTids2 = [],
    ets:insert(?ETS_TASK_QUERY_CACHE, {PS#player_status.id, ActiveTids++ActiveTids2}).

%% 获取任务详细数据
get_data(TaskId, PS) ->
%    case srv_yunbiao:is(TaskId) of
%        false -> data_task:get(TaskId, PS);
%        true -> srv_yunbiao:get(TaskId, PS)
%    end.
    data_task:get(TaskId, PS).

%% 获取任务列表所需要的所有信息，因为任务类型不同，有些奖励是动态变化的，所以获取列表的奖励信息等也要分开处理
get_info(InfoType, TaskId, PS) ->
    TD = 
    case get_type(TaskId) of
        normal -> data_task:get(TaskId, PS);     %% 正常任务
        yunbiao -> srv_yunbiao:get(TaskId);  %% 
        guild -> data_task:get(TaskId, PS)
    end,
    TipList = 
    case InfoType of 
        active -> lib_task:get_tip(active, TaskId, PS);
        trigger -> lib_task:get_tip(trigger, TaskId, PS)
    end,
    {TD#task.id, TD#task.level, TD#task.type, TD#task.name, TD#task.desc, TipList, TD#task.coin, TD#task.exp, TD#task.spt, TD#task.binding_coin, TD#task.attainment, TD#task.guild_exp, TD#task.contrib, TD#task.award_select_item_num, get_award_item(TD, PS), TD#task.award_select_item}.

%% 获取任务类型
%% TODO 目前还没区别分一些特殊任务，暂时按任务id区分一下，往后将添加class属性来区分，并将所有任务写进ets
get_type(TaskId) ->
    case srv_yunbiao:is(TaskId) of
        true -> yunbiao;
        false -> 
            case is_guild_task(TaskId) of
                true -> guild;
                false -> normal
            end
    end.
        
is_special_task(TaskId) ->
    TaskId > 999999.

%% 获取玩家能在该Npc接任务或者交任务
get_npc_task_list(NpcId, PS) ->
    {CanTrigger, Link, UnFinish, Finish} = get_npc_task(NpcId, PS),
    F = fun(Tid, NS) -> TD = get_data(Tid, PS), [Tid, NS, TD#task.name] end,
    L1 = [F(T1, 1) || T1 <- CanTrigger],
    L2 = [F(T2, 4) || T2 <- Link],
    L3 = [F(T3, 2) || T3 <- UnFinish],
    L4 = [F(T4, 3) || T4 <- Finish],
    L1++L2++L3++L4.
    
%% 获取npc任务状态
get_npc_state(NpcId, PS)->
    {CanTrigger, Link, UnFinish, Finish} = get_npc_task(NpcId, PS),
    %% 0表示什么都没有，1表示有可接任务，2表示已接受任务但未完成，3表示有完成任务，4表示有任务相关
    case length(Finish) > 0 of
        true -> 3;
        false ->
            case length(Link)>0 of
                true-> 4;
                false-> 
                    case length(CanTrigger)>0 of
                        true ->    1;
                        false ->
                            case length(UnFinish)>0 of
                                true -> 2;
                                false -> 0
                            end
                    end
            end
    end.

%% 获取npc任务关联
%%{可接任务，关联，任务未完成，完成任务}
get_npc_task(NpcId, PS)->
    CanTrigger = get_npc_can_trigger_task(NpcId, PS),
    {Link, Unfinish, Finish} = get_npc_other_link_task(NpcId, PS),
    {CanTrigger, Link, Unfinish, Finish}.

%% 获取可接任务
get_npc_can_trigger_task(NpcId, PS) ->
    get_npc_can_trigger_task(get_active(PS), [], NpcId, PS).
get_npc_can_trigger_task([], Result, _, _) ->
    Result;
get_npc_can_trigger_task([TaskId | T ], Result, NpcId, PS) ->
    TD = get_data(TaskId, PS),
    case get_start_npc(TD#task.start_npc, PS#player_status.career) =:= NpcId of
        false -> get_npc_can_trigger_task(T, Result, NpcId, PS);
        true -> get_npc_can_trigger_task(T, Result ++ [TaskId], NpcId, PS)
    end.

%% 获取已触发任务
get_npc_other_link_task(NpcId, PS) ->
    get_npc_other_link_task(get_trigger(PS), {[], [], []}, NpcId, PS).
get_npc_other_link_task([], Result, _, _) ->
    Result;
get_npc_other_link_task([RT | T], {Link, Unfinish, Finish}, NpcId, PS) ->
    TD = get_data(RT#role_task.task_id, PS),
    case is_finish(RT, PS) andalso get_end_npc_id(RT) =:= NpcId of  %% 判断是否完成
        true -> get_npc_other_link_task(T, {Link, Unfinish, Finish++[RT#role_task.task_id]}, NpcId, PS);
        false -> 
            case task_talk_to_npc(RT, NpcId) of %% 判断是否和NPC对话
                true -> get_npc_other_link_task(T, {Link++[RT#role_task.task_id], Unfinish, Finish}, NpcId, PS);
                false -> 
                    case get_start_npc(TD#task.start_npc, PS#player_status.career) =:= NpcId of %% 判断是否接任务NPC
                        true -> get_npc_other_link_task(T, {Link, Unfinish++[RT#role_task.task_id], Finish}, NpcId, PS);
                        false -> get_npc_other_link_task(T, {Link, Unfinish, Finish}, NpcId, PS)
                    end
            end
    end.

%%检查任务的下一内容是否为与某npc的对话
task_talk_to_npc(RT, NpcId)->
    Temp = [0||[State,Fin,Type,Nid|_]<- RT#role_task.mark, State=:= RT#role_task.state, Fin=:=0, Type=:=talk, Nid =:= NpcId],
    length(Temp)>0.

%% 获取任务对话id
get_npc_task_talk_id(TaskId, NpcId, PS) ->
    case get_data(TaskId, PS) of
        null -> 0;
        TD ->
            {CanTrigger, Link, UnFinish, Finish} = get_npc_task(NpcId, PS),
            case {
                lists:member(TaskId, CanTrigger), 
                lists:member(TaskId, Link),
                lists:member(TaskId, UnFinish),
                lists:member(TaskId, Finish)
            }of 
                {true, _, _, _} -> {start_talk, TD#task.start_talk};    %% 任务触发对话
                {_, true, _, _} ->    %% 关联对话
                    RT = get_one_trigger(TaskId, PS),
                    [Fir|_] = [TalkId || [State,Fin,Type,Nid,TalkId|_] <- RT#role_task.mark, State=:= RT#role_task.state, Fin=:=0, Type=:=talk, Nid =:= NpcId],
                    {link_talk, Fir};
                {_, _, true, _} -> {unfinished_talk, TD#task.unfinished_talk};  %% 未完成对话
                {_, _, _, true} ->   %% 提交任务对话
                    RT = get_one_trigger(TaskId, PS),
                    [Fir|_] = [TalkId || [_,_,Type,Nid,TalkId|_] <- RT#role_task.mark, Type=:=end_talk, Nid =:= NpcId],
                    {end_talk, Fir};
                _ -> {none, 0}
            end
    end.

%% 获取提示信息
get_tip(active, TaskId, PS) ->
    TD = get_data(TaskId, PS),
    case get_start_npc(TD#task.start_npc, PS#player_status.career) of
        0 -> [];
        StartNpcId -> [to_same_mark([0, 0, start_talk, StartNpcId], PS)]
    end;

get_tip(trigger, TaskId, PS) ->
    RT = get_one_trigger(TaskId, PS),
    [to_same_mark([State|T], PS) || [State | T] <-RT#role_task.mark, RT#role_task.state=:= State].

get_award_item(TD, PS) ->
    [{ItemId, Num} || {Career, ItemId, Num} <- TD#task.award_item, Career =:= 0 orelse Career =:= PS#player_status.career].

get_award_gift(TD, PS) ->
    [{GiftId, Num} || {Career, GiftId, Num} <- TD#task.award_gift, Career =:= 0 orelse Career =:= PS#player_status.career].

%% 获取开始npc的id
%% 如果需要判断职业才匹配第2,3
get_start_npc(StartNpc, _) when is_integer(StartNpc) -> StartNpc;

get_start_npc([], _) -> 0;

get_start_npc([{career, Career, NpcId}|T], RoleCareer) ->
    case Career =:= RoleCareer of
        false -> get_start_npc(T, RoleCareer);
        true -> NpcId
    end.

%% 转换成一致的数据结构
to_same_mark([_, Finish, start_talk, NpcId | _], PS) ->
    {SId,SName} = get_npc_def_scene_info(NpcId, PS#player_status.realm),
    %% [类型, 完成, NpcId, Npc名称, 0, 0, 所在场景Id]
    [0, Finish, NpcId, lib_npc:get_name_by_npc_id(NpcId), 0, 0, SId, SName, []];

to_same_mark([_, Finish, end_talk, NpcId | _], PS) ->
    {SId,SName} = get_npc_def_scene_info(NpcId, PS#player_status.realm),
    %% [类型, 完成, NpcId, Npc名称, 0, 0, 所在场景Id]
    [1, Finish, NpcId, lib_npc:get_name_by_npc_id(NpcId), 0, 0, SId, SName, []];


to_same_mark([_, Finish, kill, MonId, Num, NowNum | _], _PS) ->
    {SId,SName, X, Y} = get_mon_def_scene_info(MonId),
    %% [类型, 完成, MonId, Npc名称, 需要数量, 已杀数量, 所在场景Id]
    [2, Finish, MonId, lib_mon:get_name_by_mon_id(MonId), Num, NowNum, SId, SName, [X, Y]];

to_same_mark([_, Finish, talk, NpcId | _], PS) ->
    {SId,SName} = get_npc_def_scene_info(NpcId, PS#player_status.realm),
    %% [类型, 完成, NpcId, Npc名称, 0, 0, 所在场景Id]
    [3, Finish, NpcId, lib_npc:get_name_by_npc_id(NpcId), 0, 0, SId, SName, []];
        
to_same_mark([_, Finish, item, ItemId, Num, NowNum | _], _PS) ->
    {NpcId, ItemName, SceneId, SceneName, X, Y} = case goods_util:get_task_mon(ItemId) of
        0 -> {0, get_item_name(ItemId), 0, <<"未知场景">>, 0, 0};  %% 物品无绑定npc
        XNpcId ->
            {XSId,XSName, X0, Y0} = get_mon_def_scene_info(XNpcId),
            {XNpcId, get_item_name(ItemId), XSId, XSName, X0, Y0}
    end,
    %% [类型, 完成, 物品id, 物品名称, 0, 0, 0]
    [4, Finish, NpcId, ItemName, Num, NowNum, SceneId, SceneName, [NpcId, lib_mon:get_name_by_mon_id(NpcId), X, Y]];

to_same_mark([_, Finish, open_store | _], _PS) ->
    [5, Finish, 0, <<>>, 0, 0, 0, <<>>, []];

to_same_mark([_, Finish, equip ,ItemId | _], _PS) ->
    [6, Finish, ItemId, get_item_name(ItemId), 0, 0, 0, <<>>, []];

to_same_mark([_, Finish, buy_equip ,ItemId, NpcId| _], PS) ->
    {SId,SName} = get_npc_def_scene_info(NpcId, PS#player_status.realm),
    [7, Finish, ItemId, get_item_name(ItemId), 0, 0, SId, SName, [NpcId, lib_npc:get_name_by_npc_id(NpcId)]];

to_same_mark([_, Finish, learn_skill ,SkillId | _], _PS) ->
    [8, Finish, SkillId, <<"技能名称">>, 0, 0, 0, <<>>, []];

%to_same_mark([_, Finish, learn_lineup ,LineupId | _], _PS) ->
%    [9, Finish, LineupId, <<"阵法名称">>, 0, 0, 0, <<>>, []];

%to_same_mark([_, Finish, train_equip ,Lev | _], _PS) ->
%    [10, Finish, Lev, <<"法宝修炼">>, 0, 0, 0, <<>>, []];

to_same_mark(MarkItem, _PS) ->
    MarkItem.

%%获取当前NPC所在的场景（自动寻路用）
get_npc_def_scene_info(NpcId, _Realm) ->
    case lib_npc:get_scene_by_npc_id(NpcId) of
        [] ->
            {0,<<>>};
        [SceneId, _, _] ->
             case ets:lookup(?ETS_SCENE, SceneId) of
                [] ->
                    {0,<<>>};
                [Scene] ->
                    {SceneId, Scene#ets_scene.name}
             end
    end.

%%获取当前NPC所在的场景（自动寻路用）
get_mon_def_scene_info(MonId) ->
    case lib_mon:get_scene_by_mon_id(MonId) of
        0 -> {0,<<>>};
        [SceneId, X, Y] ->
             case ets:lookup(?ETS_SCENE, SceneId) of
                [] -> {0,<<>>};
                [Scene] ->
                    {SceneId, Scene#ets_scene.name, X, Y}
             end
    end.

get_item_name(ItemId)->
    goods_util:get_goods_name(ItemId).

%% 获取可接的任务
get_active(PS) ->
    case ets:lookup(?ETS_TASK_QUERY_CACHE, PS#player_status.id) of
        [] ->[];
        [{_,ActiveIds}] ->ActiveIds
    end.

%% 获取已触发任务列表
get_trigger(PS) when is_record(PS, player_status) ->
    ets:match_object(?ETS_ROLE_TASK, #role_task{role_id=PS#player_status.id, _='_'});

%% 获取已触发任务列表
get_trigger(Rid) when is_integer(Rid) ->
    ets:match_object(?ETS_ROLE_TASK, #role_task{role_id=Rid, _='_'}).

%% 获取该阶段任务内容
get_phase(RT)->
    [[State | T] || [State | T] <- RT#role_task.mark, RT#role_task.state =:= State].

%% 获取任务阶段的未完成内容
get_phase_unfinish(RT)->
    [[State, Fin | T] || [State, Fin |T] <- RT#role_task.mark, RT#role_task.state =:= State ,Fin =:= 0].

%% 获取已完成的任务列表
get_finish(PS) ->
    ets:match_object(?ETS_ROLE_TASK_LOG, #role_task_log{role_id=PS#player_status.id, _='_'}).

get_one_trigger(TaskId, Rid) when is_integer(Rid) ->
    case ets:lookup(?ETS_ROLE_TASK, {Rid, TaskId}) of
        [] -> false;
        [RT] -> RT
    end;

get_one_trigger(TaskId, PS) when is_record(PS, player_status) ->
    case ets:lookup(?ETS_ROLE_TASK, {PS#player_status.id, TaskId}) of
        [] -> false;
        [RT] -> RT
    end.

%%获取结束任务的npcid
get_end_npc_id(TaskId, PS) ->
    case get_one_trigger(TaskId, PS) of
        false -> 0;
        RT -> get_end_npc_id(RT)
    end.

get_end_npc_id(RT) when is_record(RT, role_task)->  
    get_end_npc_id(RT#role_task.mark);

get_end_npc_id([]) -> 0;

get_end_npc_id(Mark) ->
    case lists:last(Mark) of
        [_, _, end_talk, NpcId, _] -> NpcId;
        _ -> 0  %% 这里是异常
    end.

%% 是否为帮会任务
is_guild_task(TaskId) ->
    case get_data(TaskId, null) of
        null -> false ;
        TD -> TD#task.contrib > 0 %% 有帮贡的任务一定是帮会任务
    end.


%% 是否已触发过
in_trigger(TaskId, Rid) when is_integer(Rid)->
    ets:lookup(?ETS_ROLE_TASK, {Rid, TaskId}) =/= [];

in_trigger(TaskId, PS) ->
    ets:lookup(?ETS_ROLE_TASK, {PS#player_status.id, TaskId}) =/= [].

%% 是否已完成任务列表里
in_finish(TaskId, PS)->
    ets:match_object(?ETS_ROLE_TASK_LOG, #role_task_log{role_id=PS#player_status.id, task_id=TaskId, _='_'}) =/= [].

%% 获取今天完成某任务的数量
get_today_count(TaskId, PS) ->
    {M, S, MS} = now(),
    {_, Time} = calendar:now_to_local_time({M, S, MS}),
    TodaySec = M * 1000000 + S - calendar:time_to_seconds(Time),
    TomorrowSec = TodaySec + 86400,
    length([0 || RTL <- get_finish(PS), TaskId=:=RTL#role_task_log.task_id, RTL#role_task_log.finish_time >= TodaySec, RTL#role_task_log.finish_time < TomorrowSec]).

%%是否可以接受任务
can_trigger(TaskId, PS) ->
    can_trigger_msg(TaskId, PS) =:= true.
    
can_trigger_msg(TaskId, PS) ->
    case get_data(TaskId, PS) of
        null ->
            <<"没有这个任务">>;
        TD ->
            case in_trigger(TaskId, PS) of
                true -> <<"已经触发过了">>; %%已经触发过了
                false ->
                    case PS#player_status.lv < TD#task.level of
                        true -> <<"等级不足">>; %% 等级不足
                        false ->
                            case check_realm(TD#task.realm, PS#player_status.realm) of
                                false -> <<"阵营不符合">>; %% 阵营不符合
                                true ->
                                    case check_career(TD#task.career, PS#player_status.career) of
                                        false -> <<"职业不符合">>; %% 职业不符合
                                        true ->
                                            case check_prev_task(TD#task.prev, PS) of
                                                false -> <<"前置任务未完成">>; %%前置任务未完成
                                                true ->
                                                    case check_repeat(TaskId, TD#task.repeat, PS) of
                                                        false -> <<"不能重复接受">>; %%不 能重复做
                                                        true ->
                                                            length([1||ConditionItem <- TD#task.condition, check_condition(ConditionItem, TaskId, PS)=:=false]) =:=0
                                                    end
                                            end
                                    end
                            end
                    end
            end
    end.

%% 获取下一等级的任务
next_lev_list(PS) ->
   Tids = data_task:get_ids(),
   F = fun(Tid) -> TD = get_data(Tid, PS), (PS#player_status.lv + 1) =:= TD#task.level end,
   [XTid || XTid<-Tids, F(XTid)].

%% 阵营检测
check_realm(Realm, PSRealm) ->
    case Realm =:= 0 of
        true -> true;
        false -> PSRealm =:= Realm
    end.
%% 职业检测
check_career(Career, PSCareer) ->
    case Career =:= 0 of
        true -> true;
        false -> PSCareer =:= Career
    end.

%% 是否重复可以接
check_repeat(TaskId, Repeat, PS) ->
    case Repeat =:= 0 of
        true -> in_finish(TaskId, PS) =/= true;
        false -> true
    end.

%% 前置任务
check_prev_task(PrevId, PS) ->
    case PrevId =:= 0 of
        true -> true;
        false -> in_finish(PrevId, PS)
    end.

%% 能否触发任务的其他非硬性影响条件
trigger_other_condition(TD, PS) ->
    case gen_server:call(PS#player_status.goods_pid, {'cell_num'}) < length(TD#task.start_item) of
        true -> false; %% 空位不足，放不下触发时能获得的物品
        false -> true
    end.

%% 触发任务
trigger(TaskId, PS) ->
%    case srv_yunbiao:is(TaskId) of
%        false -> normal_trigger(TaskId, PS);
%        true -> srv_yunbiao:trigger(TaskId, PS)
%    end.
    normal_trigger(TaskId, PS).

normal_trigger(TaskId, PS) ->
    case can_trigger(TaskId, PS) of
        false ->
            {false, <<"条件不足！">>};
        true ->
            TD = get_data(TaskId, PS),
%            case trigger_other_condition(TD, PS) of
%                false -> {false, <<"背包空间不足！">>};
%                true ->
                    %% TODO 任务开始给予物品
                    %case length(TD#task.start_item) > 0 of
                    %    true ->
                    %        lib_item:send_items_to_bag(TD#task.start_item, PS#player_status.id),
                    %        lib_storage:refresh_list(role_bag, PS#player_status.id);
                    %    false -> ok
                    %end,
                    ets:insert(?ETS_ROLE_TASK, 
                        #role_task{
                        id={PS#player_status.id, TaskId},
                        role_id=PS#player_status.id ,
                        task_id = TaskId, 
                        trigger_time = util:unixtime(), 
                        state=0,
                        end_state=TD#task.state,
                        mark = TD#task.content
                    }),
                    %% log:log(begin_task, [PS#player_status.id, PS#player_status.lev, TaskId]),
                    mod_task:add_trigger(PS#player_status.id, TaskId, util:unixtime(), 0, TD#task.state, term_to_binary(TD#task.content)),
                    refresh_active(PS),
                    {true, PS}
%            end
    end.

%% 有部分任务内容在触发的时候可能就完成了
preact_finish(Rid) ->
    lists:member(true, [preact_finish(RT, Rid) || RT <- get_trigger(Rid)]).

preact_finish(TaskId, Rid) when is_integer(TaskId) ->
    preact_finish(get_one_trigger(TaskId, Rid), Rid);

preact_finish(RT, Rid) ->
    lists:member(true, [preact_finish_check([State, Fin | T], Rid) || [State, Fin | T] <- RT#role_task.mark, State =:= RT#role_task.state, Fin =:= 0]).

%% 装备武器
preact_finish_check([_, 0, equip, _ItemId | _], _Rid) ->
    false; %% 默认都没穿上吧
%    case lib_storage:get_num_by_baseId(role_eqm, Rid, ItemId) of
%        0 -> false;
%        _ -> event(equip, {ItemId}, Rid)
%    end;

%% 购买武器
preact_finish_check([_, 0, buy_equip, ItemId | _], Rid) ->
    case goods_util:get_task_goods_num(Rid, ItemId) > 0 of
        false -> false;
        true -> event(buy_equip, {ItemId}, Rid)
    end;

%% 收集物品
preact_finish_check([_, 0, item, ItemId, _, NowNum | _], Rid) ->
    Num = goods_util:get_task_goods_num(Rid, ItemId),
    case Num >  NowNum of
        false -> false;
        true -> event(item, [{ItemId, Num}], Rid)
    end;

preact_finish_check(_, _) ->
    false.

%% 检测任务是否完成
is_finish(TaskId, PS) when is_integer(TaskId) ->
    case get_one_trigger(TaskId, PS) of
        false -> false;
        RT -> is_finish(RT, PS)
    end;

is_finish(RT, PS) when is_record(RT, role_task) ->
    is_finish_mark(RT#role_task.mark, PS);

is_finish(Mark, PS) when is_list(Mark) ->
    is_finish_mark(Mark, PS).

is_finish_mark([], _) ->
    true;
is_finish_mark([MarkItem | T], PS) ->
    case check_content(MarkItem, PS) of
        false -> false;
        true -> is_finish_mark(T, PS)
    end.

%% 完成任务
finish(TaskId, ParamList, PS) ->
    normal_finish(TaskId, ParamList, PS).

normal_finish(TaskId, _ParamList, RS) ->
    case is_finish(TaskId, RS) of
        false -> {false, <<"任务未完成！">>};
        true ->
            TD = get_data(TaskId, RS),
            case award_condition(TD, RS) of
                {false, Reason} -> {false, Reason};
                {true, RS0} ->
                    %% 回收物品
                    case length(TD#task.end_item) > 0 of
                        true -> gen_server:call(RS#player_status.goods_pid, {'throw_more', [ ItemId || {ItemId, _} <- TD#task.end_item]});
                        false -> false
                    end,

                    %% 奖励固定物品
                    case get_award_item(TD, RS) of
                        [] -> false;
                        Items ->
                            F = fun(GoodsTypeId, GoodsNum) ->
                                gen_server:call(RS0#player_status.goods_pid, {'give_goods', RS0, GoodsTypeId, GoodsNum})
                            end,
                            [F(Id, Num) || {Id, Num} <- Items]
                    end,

                    %% 礼包
                    %R3 = case length(get_award_gift(TD, RS)) > 0 of
                    %    true ->
                    %        [lib_gift:send_gift(RS0#player_status.id, GiftId) || {GiftId, _} <- get_award_gift(TD, RS)],
                    %        true;
                    %    false -> false
                    %end,
                
                    %% 暂时屏蔽可选奖励共呢，奖励可选物品
                    %R3 = case length(TD#task.award_select_item) > 0 of
                    %    true ->
                    %        case [{Xid, Xnum} || {Xid, Xnum} <- TD#task.award_select_item, Yid <- ParamList, Xid =:= Yid] of
                    %            [] -> false;
                    %            SIL ->
                    %                lib_item:send_items_to_bag(SIL, RS#role_state.id)
                    %        end;
                    %    false -> false
                    %end,
                    case TD#task.contrib > 0 of
                        true -> lib_guild:add_donation(RS#player_status.id, TD#task.contrib);
                        false -> false
                    end,
                    RS1 = lib_player:add_coin(RS0, TD#task.coin),
                    RS2 = lib_player:add_exp(RS1, TD#task.exp),
                    RS3 = case TD#task.spt > 0 of
                        true -> RS2#player_status{spirit = RS2#player_status.spirit + TD#task.spt};
                        false -> RS2
                    end,
                    LastRS = RS3,
                    Time = util:unixtime(),
                    RT = get_one_trigger(TaskId, LastRS),

                    ets:delete(?ETS_ROLE_TASK, {LastRS#player_status.id, TaskId}),
                    ets:insert(?ETS_ROLE_TASK_LOG, #role_task_log{role_id=LastRS#player_status.id, task_id=TaskId, trigger_time = RT#role_task.trigger_time, finish_time = Time}),

                    %% 数据库回写
                    mod_task:del_trigger(RS#player_status.id, TaskId),
                    mod_task:add_log(RS#player_status.id, TaskId, RT#role_task.trigger_time, Time),
                    refresh_active(LastRS),
                    %% 完成后一些特殊操作
                    %flush_ets(RS),
                    case LastRS =/= RS of
                        true -> lib_player:refresh_client(LastRS);
                        false -> ok
                    end,
                    {true, LastRS}
            end
    end.

%% 奖励物品所需要的背包空间
award_item_num(TD, PS) ->
    length(get_award_item(TD, PS)) + length(get_award_gift(TD, PS)) + TD#task.award_select_item_num - length(TD#task.end_item).

%% 检查是否能完成奖励的条件
award_condition(TD, RS) ->
    case gen_server:call(RS#player_status.goods_pid, {'cell_num'}) < award_item_num(TD, RS) of
        true -> {false, <<"背包空间不足！">>};  %% 空位不足
        false ->
            {true, RS}
%            F = fun(ItemId, Num) ->
%                lib_item:query_bag_item_num(ItemId, RS#player_status.id) < Num
%            end,
%            case length([0 || {I, N} <- TD#task.end_item, F(I, N)]) =/= 0 of
%                true -> {false, <<"没有回收物品！">>};  %% 回收物品不足
%                false ->
%                    case lib_role:spend_coin(RS, TD#task.end_cost) of
%                        {false} -> {false, <<"铜币不足！">>}; %% 上交金钱不足
%                        {true, RS1} ->
%                            case TD#task.contrib > 0 of
%                                false -> {true, RS1};
%                                true ->
%                                    G = lib_guild:get_guild_contrib_today(RS#player_status.guild_id, RS#player_status.id),
%                                    case G + TD#task.contrib > 1000 of
%                                        true -> {false, <<"您今天的帮贡已到达上限，无法完成任务！">>};
%                                        false -> {true, RS1}
%                                    end
%                            end
%                    end
%            end
    end.
    

%% 触发并完成任务
trigger_and_finish(TaskId, ParamList, PS) ->
    case trigger(TaskId, PS) of
        {false, Reason} -> {false, Reason};
        {true, PS1} -> finish(TaskId, ParamList, PS1)
    end.


%% 放弃任务
abnegate(TaskId, PS) ->
    case get_one_trigger(TaskId, PS) of
        false -> false;
        _ ->
            ets:delete(?ETS_ROLE_TASK, {PS#player_status.id, TaskId}),
            mod_task:del_trigger(PS#player_status.id, TaskId),
            refresh_active(PS),
            true
    end.


%% 或任务奖励的数据，帮会任务的个人经验和帮贡要做特殊处理、
get_award_data() -> 
    ok.

%% 组织奖励的描述信息
get_award_msg(TD, PS) ->
    list_to_binary(
    [
        <<"奖励：">>,
        case TD#task.exp>0 of
            false -> [];
            true -> [<<"经验">>, integer_to_list(TD#task.exp), <<" ">>]
        end,
        case TD#task.coin > 0 of
            false -> [];
            true ->[<<"铜钱">>, integer_to_list(TD#task.coin), <<" ">>]
        end,
%        case TD#task.binding_coin > 0 of
%            false -> [];
%            true -> [<<"绑定铜">>, integer_to_list(TD#task.binding_coin), <<" ">>]
%        end,
        case TD#task.spt > 0 of
            false -> [];
            true -> [<<"灵力">>, integer_to_list(TD#task.spt), <<" ">>]
        end,
%        case TD#task.attainment > 0 of
%            false -> [];
%            true -> [<<"修为">>, integer_to_list(TD#task.attainment), <<" ">>]
%        end,
        case length(TD#task.award_item) > 0 orelse length(TD#task.award_gift) > 0 of
            false -> [];
            true ->
                %% TODO 暂时没有礼包获取名字的接口
                %ItemNameList = [get_item_name(ItemId) || {ItemId, _} <- get_award_item(TD, PS)] ++ [lib_gift:get_name(GiftId) || {GiftId, _} <- get_award_gift(TD, PS)],
                ItemNameList = [get_item_name(ItemId) || {ItemId, _} <- get_award_item(TD, PS)],
                [<<"物品">>, util:implode("、", ItemNameList), <<" ">>]

        end
%        case TD#task.contrib > 0 of
%            false -> [];
%            true -> [<<"帮会贡献">>, integer_to_list(TD#task.contrib), <<" ">>]
%        end,
%        case TD#task.guild_exp > 0 of
%            false -> [];
%            true -> [<<"帮会经验">>, integer_to_list(TD#task.guild_exp), <<" ">>]
%        end
    ]).

%% 已接所有任务更新判断
action(0, Rid, Event, ParamList)->
    case get_trigger(Rid) of
        [] -> false;
        RTL -> 
            Result = [action_one(RT, Rid, Event, ParamList)|| RT<- RTL],
            lists:member(true, Result)
    end;

%% 单个任务更新判断
action(TaskId, Rid, Event, ParamList)->
    case get_one_trigger(TaskId, Rid) of
        false -> false;
        RT -> action_one(RT, Rid, Event, ParamList)
    end.

action_one(RT, Rid, Event, ParamList) ->
    F = fun(MarkItem, Update)->
        [State, Finish, Eve| _T] = MarkItem,
        case State =:= RT#role_task.state andalso Finish =:= 0 andalso Eve=:=Event of
            false -> {MarkItem, Update};
            true -> 
                {NewMarkItem, NewUpdate} = content(MarkItem, Rid, ParamList ),
                case NewUpdate of
                    true -> {NewMarkItem, true};
                    false -> {NewMarkItem, Update}
                end
            end
        end,
    {NewMark, UpdateAble} = lists:mapfoldl(F ,false, RT#role_task.mark),
    case UpdateAble of
        false -> false;
        true ->
            NewState = case lists:member(false, [Fi=:=1||[Ts,Fi|_T1 ] <- NewMark,Ts=:=RT#role_task.state]) of
                true -> RT#role_task.state; %%当前阶段有未完成的
                false -> RT#role_task.state + 1 %%当前阶段有未完成的
            end,
            %% 更新任务记录和任务状态
            %% db:execute(<<"update role_task_bag set state=?,mark=? where role_id=? and task_id=?">>, [NewState, term_to_binary(NewMark), PS#player_status.id, RT#role_task.task_id]),
            ets:insert(?ETS_ROLE_TASK, RT#role_task{state=NewState, mark = NewMark}),
            mod_task:upd_trigger(Rid, RT#role_task.task_id, NewState, term_to_binary(NewMark)),
            true
    end.
    

%% 检查物品是否为任务需要
can_gain_item(Rid, ItemId) ->
    case get_trigger(Rid) of
        [] -> false;
        RTL ->
            Result = [can_gain_item(marklist, get_phase_unfinish(RT), ItemId) || RT <- RTL],
            lists:member(true, Result)
    end.

can_gain_item(marklist, MarkList, ItemId) ->
    length([0 || [_, _, Type, Id | _T] <- MarkList, Type =:= item, Id =:= ItemId])>0.


%% pvp战斗完成时，需要失去的任务物品
pvp_task_item(Winners, Losers) ->
    LosersItem = [{Rid, get_loser_lose_item(Rid)} || Rid <- Losers],
    WinnerItam = [{Rid, get_winner_gain_item(Rid)} || Rid <- Winners],
    {WinnerItam, LosersItem}.


%% 获取失败者要掉出的任务品
get_loser_lose_item(Rid) ->
    case srv_yunbiao:is_trigger(Rid) of
        false -> [];
        true -> srv_yunbiao:get_task_item()
    end.

%% 获取胜利者可以得到的任务物品
get_winner_gain_item(Rid) ->
    case srv_yunbiao:can_rob(Rid) of   %% 检测今天还能不能再劫镖
        false -> [];
        true -> srv_yunbiao:get_task_item()
    end.

after_event(Rid) ->
    %% TODO 后续事件提前完成检测
    case preact_finish(Rid) of
        true -> ok;
        false -> 
            %% TODO 通知角色数据更新
            lib_scene:refresh_npc_ico(Rid),
            {ok, BinData} = pt_30:write(30006, []),
            lib_send:send_to_uid(Rid, BinData)
    end.

%% 后续扩展------------------------------------

%% 对话事件
event(talk, {TaskId, NpcId}, Rid) ->
    case action(TaskId, Rid, talk,[NpcId]) of
        false-> false;
        true ->
            after_event(Rid),
            true
    end;

%% 打怪事件成功
event(kill, Monid, Rid) ->
    case action(0, Rid, kill, Monid) of
        false-> false;
        true ->
            after_event(Rid),
            true
    end;

%% 获得物品事件
event(item, ItemList, Rid) ->
    case action(0, Rid, item, [ItemList]) of
        false -> false;
        true ->
            after_event(Rid),
            true
    end;

%% 打开商城事件
%event(open_store, _, Rid) ->
%    case action(0, Rid, open_store, []) of
%        false -> false;
%        true ->
%            after_event(Rid),
%            true
%    end;

%% 技能学习
event(learn_skill, {SkillId}, Rid) ->
    case action(0, Rid, learn_skill, [SkillId]) of
        false -> false;
        true ->
            after_event(Rid),
            true
    end;

%% 装备物品事件
event(equip, {ItemId}, Rid) ->
    case action(0, Rid, equip, [ItemId]) of
        false -> false;
        true ->
            after_event(Rid),
            true
    end;

%% 购买物品事件
event(buy_equip, {ItemId}, Rid) ->
    case action(0, Rid, buy_equip, [ItemId]) of
        false -> false;
        true ->
            after_event(Rid),
            true
    end.

%% 打怪事件失败
event(die, Rid) ->
    case srv_yunbiao:is_trigger(Rid) of
        false -> false;
        true -> %%srv_yunbiao:lose(Rid)
            srv_role:cast(Rid, {srv_yunbiao, lose, []}),
            true
    end.

%% 条件
%% 任务是否完成

%% 是否完成任务
check_condition({task, TaskId}, _, PS) ->
    in_finish(TaskId, PS);

%% 是否完成其中之一的任务
check_condition({task_one, TaskList}, _, PS) ->
    lists:any(fun(Tid)-> in_finish(Tid, PS) end, TaskList);

%% 今天的任务次数是否过多
check_condition({daily_limit, Num}, ThisTaskId, PS) ->
    get_today_count(ThisTaskId, PS) < Num;
    %{M, S, MS} = now(),
    %{_, Time} = calendar:now_to_local_time({M, S, MS}),
    %TodaySec = M * 1000000 + S - calendar:time_to_seconds(Time),
    %TomorrowSec = TodaySec + 86400,
    %%check_condition_daily_limit(get_finish(PS), ThisTaskId, Num, TodaySec, TomorrowSec);

%% 帮会任务等级
check_condition({guild_level, Lev}, _, PS) ->
    case PS#player_status.guild_id =:= 0 of
        true -> false;
        false ->
            case lib_guild:get_guild_lev_by_id(PS#player_status.guild_id) of
                null -> false;
                GLevel -> GLevel >= Lev
            end
    end;

%% 容错
check_condition(_Other, _, _PS) ->
    false.

check_condition_daily_limit([], _, Num, _, _) ->
    Num > 0;
check_condition_daily_limit([RTL | T], TaskId, Num, TodaySec, TomorrowSec) ->
    case 
        TaskId =:= RTL#role_task_log.task_id andalso 
        RTL#role_task_log.finish_time > TodaySec andalso
        RTL#role_task_log.finish_time < TomorrowSec 
    of
        false -> check_condition_daily_limit(T, TaskId, Num, TodaySec, TomorrowSec);
        true -> %% 今天所完成的任务
            case Num - 1 > 0 of
                true -> check_condition_daily_limit(T, TaskId, Num - 1, TodaySec, TomorrowSec);
                false -> false
            end
    end.

%% 检测任务内容是否完成
check_content([_, Finish, kill, _NpcId, Num, NowNum], _Rid) ->
    Finish =:=1 andalso Num =:= NowNum;

check_content([_, Finish, talk, _, _], _Rid) ->
    Finish =:=1;

check_content([_, Finish, item, _, Num, NowNum], _Rid) ->
    Finish =:=1 andalso Num =:= NowNum;

check_content([_, Finish | _], _Rid) ->
    Finish =:= 1;

check_content(Other, _PS) ->
    ?DEBUG("错误任务内容~p",[Other]),
    false.

%% 杀怪
content([State, 0, kill, NpcId, Num, NowNum], _Rid, NpcList) ->
    case NpcId =:= NpcList of
        false ->{[State, 0, kill, NpcId, Num, NowNum], false};
        true ->
            case NowNum + 1 >= Num of
                true -> {[State,1 , kill , NpcId, Num, Num],  true};
                false ->{[State,0 , kill , NpcId, Num, NowNum + 1], true}
            end
    end;

%% 对话
content([State, 0, talk, NpcId, TalkId], _Rid, [NowNpcId]) ->
    case NowNpcId =:= NpcId of
        true -> {[State, 1, talk, NpcId, TalkId], true};
        false -> {[State, 0, talk, NpcId, TalkId], false}
    end;

%% 物品
content([State, 0, item, ItemId, Num, NowNum], _Rid, [ItemList]) ->
    case [XNum || {XItemId, XNum} <- ItemList, XItemId =:= ItemId] of
        [] -> {[State, 0, item, ItemId, Num, NowNum], false}; %% 没有任务需要的物品
        [HaveNum | _] ->
            case HaveNum >= Num of
                true -> {[State, 1, item, ItemId, Num, Num], true};
                false -> {[State, 0, item, ItemId, Num, HaveNum], true}
            end
    end;

%% 打开商城
%content([State, 0, open_store], _Rid, _) ->
%    {[State, 1, open_store], true};

%% 装备物品
content([State, 0, buy_equip, ItemId | _], _Rid, [NowItemId]) ->
    case NowItemId =:= ItemId of
        false -> {[State, 0, buy_equip, ItemId], false};
        true -> {[State, 1, buy_equip, ItemId], true}
    end;

%% 购买物品
content([State, 0, equip, ItemId], _Rid, [NowItemId]) ->
    case NowItemId =:= ItemId of
        false -> {[State, 0, equip, ItemId], false};
        true -> {[State, 1, equip, ItemId], true}
    end;

%% 技能学习
content([State, 0, learn_skill, SkillId], _Rid, [NowSkillId]) ->
    case NowSkillId =:= SkillId of
        false -> {[State, 0, learn_skill, SkillId], false};
        true -> {[State, 1, learn_skill, SkillId], true}
    end;

%% 容错
content(MarkItem, _Other, _Other2) ->
    {MarkItem, false}.

%% 放弃任务后执行操作
after_finish(TaskId, _PS) when TaskId >= 1000000 andalso TaskId =< 1000003 ->
%    srv_yunbiao:after_finish(TaskId, PS);
    ok;

after_finish(_TaskId, _PS) ->
    ok.

%% 筛选标签转换函数====================================================================

convert_select_tag(_, Val) when is_integer(Val) -> Val;

%% 职业筛选 战士，法师，刺客
convert_select_tag(RS, [career, Z, F, C]) ->
    case RS#player_status.career of
        1 -> Z;
        2 -> F;
        _ -> C
    end;

%% 职业筛选 天下 无双 傲视
convert_select_tag(RS, [realm, T, W, A]) ->
    case RS#player_status.realm of
        1 -> T;
        2 -> W;
        _ -> A
    end;

%% 性别
convert_select_tag(RS, [sex, Msg, Msg2]) ->
    case RS#player_status.sex of
        1 -> Msg;
        _ -> Msg2
    end;

convert_select_tag(_, Val) -> Val.

%% 触发、完成、奖励相关==============================================================================
