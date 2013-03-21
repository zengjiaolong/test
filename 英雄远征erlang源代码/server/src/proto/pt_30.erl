%%%-----------------------------------
%%% @Module  : pt_30
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.06.17
%%% @Description: 30 任务信息
%%%-----------------------------------
-module(pt_30).
-export([read/2, write/2]).

%%
%%客户端 -> 服务端 ----------------------------
%%

%% 任务列表
read(30000, _Data) ->
    {ok, []};

%% 任务追踪
read(30001, _Data) ->
    {ok, []};

%% 可接任务
read(30002, _Data) ->
    {ok, []};

%% 接受任务
read(30003, <<TaskId:32>>) ->
    {ok, [TaskId]};

%% 完成任务
read(30004, <<TaskId:32, ILen:16, Bin/binary>>) ->
    F = fun(_, {TB, Result}) ->
            <<ItemId:32, NewTB/binary>> = TB,
            {ok, {NewTB, Result++[ItemId]}}
    end,
    {ok,{ _, ItemList}} = util:for(1, ILen, F, {Bin, []}),
    {ok, [TaskId, ItemList]};

%% 放弃任务
read(30005, <<TaskId:32>>) ->
    {ok, [TaskId]};

%% 任务对话事件
read(30007, <<TaskId:32, NpcId:32>>) ->
    {ok, [TaskId, NpcId]};

%% 触发并完成任务
read(30008, <<TaskId:32, ILen:16, Bin/binary>>) ->
    F = fun(_, {TB, Result}) ->
            <<ItemId:32, NewTB/binary>> = TB,
            {ok, {NewTB, Result++[ItemId]}}
    end,
    {ok,{ _, ItemList}} = util:for(1, ILen, F, {Bin, []}),
    {ok, [TaskId, ItemList]};

%% 获取任务奖励信息
read(30009, <<TaskId:32>>) ->
    {ok, [TaskId]};

%% 接受任务
read(30010,<<>>)->
    {ok, []};

%% 选择阵营
read(30012, <<Realm:16>>) ->
    {ok, [Realm]};

%% 劫镖
read(30013, <<Rid:32>>) ->
    {ok, [Rid]};

%% 劫镖
read(30020, <<Lev:32>>) ->
    {ok, [Lev]};

%% 学习技能
read(30030, <<Sid:32>>) ->
    {ok, Sid};

%% 清空角色单个任务
read(30100, <<TaskId:32>>) ->
    {ok, [TaskId]};

%% 清空角色所有任务
read(30200, <<>>) ->
    {ok, []};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%% --- NPC对话开始 ----------------------------------

%% 任务列表
write(30000,[ActiveList, TriggerList])->
    ABin = pack_task_list(ActiveList),
    TBin = pack_task_list(TriggerList),
    Data = <<ABin/binary, TBin/binary>>,
    {ok, pt:pack(30000, Data)};

%% 接受任务
write(30003,[Result, Msg])->
    L = byte_size(Msg),
    {ok, pt:pack(30003, <<Result:8, L:16, Msg/binary>>)};

%% 完成任务
write(30004,[Result, Msg])->
    L = byte_size(Msg),
    {ok, pt:pack(30004, <<Result:8, L:16, Msg/binary>>)};

%% 放弃任务
write(30005,[Result])->
    {ok, pt:pack(30005, <<Result:8>>)};

%% 更新任务数据
write(30006, [])->
    Data = <<>>,
    {ok, pt:pack(30006, Data)};

%% 触发并完成任务
write(30008,[Result, Msg])->
    L = byte_size(Msg),
    {ok, pt:pack(30008, <<Result:8, L:16, Msg/binary>>)};

%% 任务奖励提示
write(30009,[Tid, Coin, Exp, Spt, BindingCoin, Attainment, GuildExp, Contrib, AwardSelectItemNum , AwardItem, AwardSelectItem])->
    AILen = length(AwardItem),
    AIBin = list_to_binary([<<ItemIdA:32, NumA:16>>||{ItemIdA, NumA} <- AwardItem]),
    ASILen = length(AwardSelectItem),
    ASIBin = list_to_binary([<<ItemIdB:32, NumB:16>>||{ItemIdB, NumB} <- AwardSelectItem]),
    Data = <<Tid:32, Coin:32, Exp:32, Spt:16, BindingCoin:32, Attainment:16, GuildExp:32, Contrib:32,AwardSelectItemNum:16, AILen:16, AIBin/binary,  ASILen:16, ASIBin/binary>>,
    {ok, pt:pack(30009, Data)};

%% 通知客户端弹出阵营选择界面
write(30011, []) ->
    {ok, pt:pack(30011, <<>>)};

%% 阵营选择
write(30012, [Result, Msg]) ->
    L = byte_size(Msg),
    {ok, pt:pack(30012, <<Result:8, L:16, Msg/binary>>)};

%% 劫镖
write(30013, [Result, Msg]) ->
    L = byte_size(Msg),
    {ok, pt:pack(30013, <<Result:8, L:16, Msg/binary>>)};

%% 挑战心魔
write(30020, [Result, Msg]) ->
    L = byte_size(Msg),
    {ok, pt:pack(30013, <<Result:8, L:16, Msg/binary>>)};

write(_Cmd, _R) ->
    {ok, pt:pack(0, <<>>)}.

%% -----------私有函数------------
pack_task_list([]) -> <<0:16>>;
pack_task_list(TaskList) ->
    Len = length(TaskList),
    Bin = list_to_binary([pack_task(X) || X <- TaskList]),
    <<Len:16, Bin/binary>>.

pack_task({Tid,Lev,Type,Name,Desc,Tip, Coin, Exp, Spt, BindingCoin, Attainment, GuildExp, Contrib, AwardSelectItemNum , AwardItem, AwardSelectItem}) ->
    NameLen = byte_size(Name),
    DescLen = byte_size(Desc),
    TipBin = pack_task_tip_list(Tip),
    AILen = length(AwardItem),
    AIBin = list_to_binary([<<ItemIdA:32, NumA:16>>||{ItemIdA, NumA} <- AwardItem]),
    ASILen = length(AwardSelectItem),
    ASIBin = list_to_binary([<<ItemIdB:32, NumB:16>>||{ItemIdB, NumB} <- AwardSelectItem]),
    <<Tid:32, Lev:16, Type:16, NameLen:16, Name/binary, DescLen:16, Desc/binary,Coin:32, Exp:32, Spt:16, BindingCoin:32, Attainment:16, GuildExp:32, Contrib:32,AwardSelectItemNum:16, AILen:16, AIBin/binary,  ASILen:16, ASIBin/binary, TipBin/binary>>.

 %% 打包任务目标
pack_task_tip_list([]) -> <<0:16>>;
pack_task_tip_list(TipList) ->
    Len = length(TipList),
    Bin = list_to_binary([ pack_task_tip(X) || X <- TipList]),
    <<Len:16, Bin/binary>>.
pack_task_tip(X) ->
    [Type,Finish,Id,Name,Num,NowNum,SceneId, SceneName, Ex] = X,
    NLen = byte_size(Name),
    SNLen = byte_size(SceneName),
    ExBin = list_to_binary(util:implode("#&", Ex)),
    ExL = byte_size(ExBin),
    <<Type:16, Finish:16, Id:32, NLen:16, Name/binary, Num:16, NowNum:16, SceneId:32, SNLen:16, SceneName/binary, ExL:16, ExBin/binary>>.