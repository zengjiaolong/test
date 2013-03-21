%%----------------------------------------
%% 任务模块
%%
%% @author cayleung@gmail.com
%%----------------------------------------
-module(pp_task).
-compile(export_all).
-include("common.hrl").
-include("record.hrl").

%% 获取任务列表
handle(30000, PlayerStatus, []) ->
    %% 可接任务
    ActiveIds = lib_task:get_active(PlayerStatus),
    ActiveList = lists:map(
        fun(Tid) ->
            TD = lib_task:get_data(Tid, PlayerStatus),
            TipList = lib_task:get_tip(active, Tid, PlayerStatus),
            {TD#task.id, TD#task.level, TD#task.type, TD#task.name, TD#task.desc, TipList, TD#task.coin, TD#task.exp, TD#task.spt, TD#task.binding_coin, TD#task.attainment, TD#task.guild_exp, TD#task.contrib, TD#task.award_select_item_num, lib_task:get_award_item(TD, PlayerStatus), TD#task.award_select_item}
        end,
        ActiveIds
    ),
    %% 已接任务
    TriggerBag = lib_task:get_trigger(PlayerStatus),
    TriggerList = lists:map(
        fun(RT) ->
            TD = lib_task:get_data(RT#role_task.task_id, PlayerStatus),
            TipList = lib_task:get_tip(trigger, RT#role_task.task_id, PlayerStatus),
            {TD#task.id, TD#task.level, TD#task.type, TD#task.name, TD#task.desc, TipList, TD#task.coin, TD#task.exp, TD#task.spt, TD#task.binding_coin, TD#task.attainment, TD#task.guild_exp, TD#task.contrib, TD#task.award_select_item_num, lib_task:get_award_item(TD, PlayerStatus), TD#task.award_select_item}
        end,
        TriggerBag
    ),
    {ok, BinData} = pt_30:write(30000, [ActiveList, TriggerList]),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%% 触发任务
handle(30003, PlayerStatus, [TaskId]) ->
    case lib_task:trigger(TaskId, PlayerStatus) of
        {true, NewRS} ->    
            lib_scene:refresh_npc_ico(NewRS),
            {ok, BinData} = pt_30:write(30006, []),
            lib_send:send_one(NewRS#player_status.socket, BinData),
            {ok, BinData1} = pt_30:write(30003, [1, <<>>]),
            lib_send:send_one(NewRS#player_status.socket, BinData1),
            lib_task:preact_finish(TaskId, NewRS),
            {ok, NewRS};
        {false, Reason} -> {ok, [0, Reason], PlayerStatus}
    end;

%% 阵营任务特殊处理 
handle(30004, PlayerStatus, [10012, _])->
    ?DEBUG("这里要弹出大地图窗口", []),
    lib_conn:pack_send(PlayerStatus#player_status.socket, 30011, []),
    {ok, PlayerStatus};

%% 完成任务
handle(30004, PlayerStatus, [TaskId, SelectItemList])->
    case lib_task:finish(TaskId, SelectItemList, PlayerStatus) of
        {true, NewRS} ->
            {ok, BinData} = pt_30:write(30004, [1, <<>>]),
            lib_send:send_one(NewRS#player_status.socket, BinData),
            lib_scene:refresh_npc_ico(NewRS),           %% 刷新npc图标
            {ok, BinData1} = pt_30:write(30006, []),
            lib_send:send_one(NewRS#player_status.socket, BinData1),
            next_task_cue(TaskId, NewRS),       %% 显示npc的默认对话
%            lib_task:after_finish(TaskId, NewRS),  %% 完成后的特殊操作
            {ok, NewRS};
        {false, _Reason} ->
            ok
    end;

%% 放弃任务
handle(30005, PlayerStatus, [TaskId])->
    BinData1 = case lib_task:abnegate(TaskId, PlayerStatus) of
        true -> 
            lib_scene:refresh_npc_ico(PlayerStatus),
            {ok, BinData} = pt_30:write(30006, []),
            BinData;
        false -> 
            {ok, BinData} = pt_30:write(30005, [0]),
            BinData
    end,
    lib_send:send_one(PlayerStatus#player_status.socket, BinData1);

%% 任务对话事件
handle(30007, PlayerStatus, [TaskId, Id])->
    case lib_npc:get_npc_id(Id) of
        0 ->  0;
        NpcId -> lib_task:event(talk, {TaskId, NpcId}, PlayerStatus#player_status.id)
    end;


%% 触发并完成任务
handle(30008, PlayerStatus, [TaskId, SelectItemList])->
    case lib_task:trigger_and_finish(TaskId, SelectItemList, PlayerStatus) of
        {true, NewRS} ->    
            lib_conn:pack_send(NewRS#player_status.socket, 30004, [1, <<>>]), %% 完成任务
            lib_scene:refresh_npc_ico(NewRS),           %% 刷新npc图标
            lib_conn:pack_send(NewRS#player_status.socket, 30006, []), %% 发送更新命令
            next_task_cue(TaskId, NewRS),       %% 显示npc的默认对话
            lib_task:after_finish(TaskId, NewRS),  %% 完成后的特殊操作
            {ok, NewRS};
        {false, Reason} -> 
            lib_task:abnegate(TaskId, PlayerStatus),
            {ok, [0, Reason], PlayerStatus}
    end;

%% 获取任务奖励信息
handle(30009, PlayerStatus, [TaskId]) ->
    case lib_task:get_data(TaskId, PlayerStatus) of
        null -> {ok, PlayerStatus};
        TD ->
            {ok, [TD#task.id, TD#task.coin, TD#task.exp, TD#task.spt, TD#task.binding_coin, TD#task.attainment, TD#task.guild_exp, TD#task.contrib, TD#task.award_select_item_num, lib_task:get_award_item(TD, PlayerStatus), TD#task.award_select_item], PlayerStatus}
    end;

%% 打开商城事件
%handle(30010, PlayerStatus, []) ->
%    lib_task:event(open_store, null, PlayerStatus#player_status.id),
%    {ok, PlayerStatus};

%% 阵营选择
%handle(30012, PlayerStatus, [Realm]) ->
%    case lib_task:in_trigger(10012, PlayerStatus) andalso PlayerStatus#player_status.realm =:= 0 andalso lists:member(Realm, [1, 2, 3]) of    %% 阵营选择任务是否完成
%        false ->
%            %% TODO 异常情况
%            ?DEBUG("角色[~w]阵营选择异常情况", [PlayerStatus#player_status.id]),
%            {ok, [0, <<>>], PlayerStatus};
%        true ->
%            %% TODO 修改realm和将玩家传送到阵营场景，暂时先传到飘渺村
%            PlayerStatus1 = PlayerStatus#player_status{realm = Realm},
%            case lib_task:finish(10012, [], PlayerStatus1) of
%                {true, PlayerStatus2} ->
%                    LastRS = case Realm of
%                        1 -> lib_scene:teleport(PlayerStatus2, 101020, <<"你加入了【极乐宗】">>);
%                        2 -> lib_scene:teleport(PlayerStatus2, 101020, <<"你加入了【浩然盟】">>);
%                        3 -> lib_scene:teleport(PlayerStatus2, 101020, <<"你加入了【魔尊门】">>)
%                    end,
%                    lib_conn:pack_send(LastRS#player_status.socket, 30004, [1, <<>>]), %% 完成任务
%                    lib_scene:refresh_npc_ico(LastRS),
%                    lib_conn:pack_send(LastRS#player_status.socket, 30006, []),
%                    lib_role:refresh_client(LastRS),
%                    {ok, [1, <<>>], LastRS};
%                {false, Reason} ->
%                    {ok, [0, Reason], PlayerStatus}
%            end
%    end;


%% 劫镖
%handle(30013, PlayerStatus, [YunbiaoRid]) ->
%    case srv_yunbiao:is_trigger(YunbiaoRid) of
%        false -> {ok, [0, <<"该玩家没有镖银！">>], PlayerStatus};     %% 这是异常情况
%        true ->
%            case srv_yunbiao:jiebiao_limit(PlayerStatus#player_status.id) of
%                false -> {ok, [0, <<"您今天劫镖次数已到上限！">>], PlayerStatus};
%                true -> {ok, [1, <<>>], PlayerStatus}
%            end
%    end;


%% 挑战心魔
%handle(30020, PlayerStatus, [Lev]) ->
%    case srv_xinmo:check(PlayerStatus) of
%        {false, Msg} -> {ok, [0, Msg], PlayerStatus};     %% 这是异常情况
%        true ->
%            %% TODO调用战斗模块
%            srv_xinmo:fight_init(PlayerStatus, Lev),
%            {ok, [1, <<>>], PlayerStatus}
%    end;

%% 学习技能
handle(30030, PlayerStatus, SkillId) ->
    lib_task:event(learn_skill, {SkillId}, PlayerStatus#player_status.id);

%% 测试接口，清除某个任务
handle(30100, PlayerStatus, [TaskId]) ->
    case lib_task:abnegate(TaskId, PlayerStatus) of
        true -> 
            lib_scene:refresh_npc_ico(PlayerStatus),
            lib_conn:pack_send(PlayerStatus#player_status.socket, 30006, []);
        false -> false
    end,
    {ok, PlayerStatus};

%% 测试接口，清除所有任务
handle(30200, PlayerStatus, []) ->
    lists:map(
        fun(RT) ->
            srv_task:del_trigger(PlayerStatus#player_status.id, RT#role_task.task_id),
            srv_task:del_log(PlayerStatus#player_status.id, RT#role_task.task_id)
        end,
        lib_task:get_trigger(PlayerStatus)
    ),
    db:execute(<<"delete from `role_task_bag` where role_id=?">>, [PlayerStatus#player_status.id]),
    db:execute(<<"delete from `role_task_log` where role_id=?">>, [PlayerStatus#player_status.id]),
    ets:match_delete(?ETS_ROLE_TASK, #role_task{role_id=PlayerStatus#player_status.id, _='_'}),
    ets:match_delete(?ETS_ROLE_TASK_LOG, #role_task_log{role_id=PlayerStatus#player_status.id, _='_'}),
    lib_task:flush_role_task(PlayerStatus),
    lib_scene:refresh_npc_ico(PlayerStatus),
    lib_conn:pack_send(PlayerStatus#player_status.socket, 30006, []),
    {ok, PlayerStatus};

handle(_Cmd, _PlayerStatus, _Data) ->
    {error, bad_request}.

%% 完成任务后是否弹结束npc的默认对话
next_task_cue(TaskId, PlayerStatus) ->
    case lib_task:get_data(TaskId, PlayerStatus) of
        null -> false;
        TD ->
            case TD#task.next_cue of
                0 -> false;
                _ -> 
                   Id = lib_npc:get_id(TD#task.end_npc, PlayerStatus#player_status.scene),
                   Npc = lib_npc:get_data(TD#task.end_npc),
                   TalkList = data_talk:get(Npc#ets_npc.talk),
                   TaskList = lib_task:get_npc_task_list(TD#task.end_npc, PlayerStatus),
                   {ok, BinData} = pt_32:write(32000, [Id, TaskList, TalkList]),
                    lib_send:send_one(PlayerStatus#player_status.socket, BinData),
                   true
            end
    end.
