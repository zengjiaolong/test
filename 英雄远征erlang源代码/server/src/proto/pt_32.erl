%%%-----------------------------------
%%% @Module  : pt_32
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.06.13
%%% @Description: 32 NPC模块
%%%-----------------------------------
-module(pt_32).
-export([read/2, write/2]).

%%
%%客户端 -> 服务端 ----------------------------
%%

%% 获取npc对话或关联任务
read(32000, <<NpcId:32>>) ->
    {ok, [NpcId]};

%% 获得npc任务对话
read(32001, <<NpcId:32, TaskId:32>>) ->
    {ok, [NpcId, TaskId]};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%% --- NPC对话开始 ----------------------------------

%% NPC对话
%% 数据格式[[{npc,<<"测试">>,[]},{yes,<<"后会有期">>,[]}]]
%% 数据格式:[任务id,状态(1:可接，2：关联，3：未完成，4：已完成),名称]
write(32000, [Id, TaskList, TalkList]) ->
    BinA = pack_talk_task_list(TaskList),
    BinB = pack_talk(TalkList),
    Data = <<Id:32, BinA/binary, BinB/binary>>,
    {ok, pt:pack(32000, Data)};

%% NPC任务对话
write(32001, [Id, TaskId, TalkList]) ->
    Bin = pack_talk(TalkList),
    Data = <<Id:32, TaskId:32, Bin/binary>>,
    {ok, pt:pack(32001, Data)};

write(_Cmd, _R) ->
    {ok, pt:pack(0, <<>>)}.

%% ----- 私有函数 -------

%% 打包对话数据
%% 数据格式[[{npc,<<"测试">>,[]},{yes,<<"后会有期">>,[]}]]
pack_talk([]) ->
    <<0:16, <<>>/binary>>;
pack_talk(TalkList) ->
    Bin = [pack_talk_item(X) || X<- TalkList],
    Len = length(TalkList),
    list_to_binary([<<Len:16>>, Bin]).
pack_talk_item(Item) ->
    Bin = [pack_talk_answer_item(X) || X<- Item],
    Len = length(Item),
    list_to_binary([<<Len:16>>, Bin]).
pack_talk_answer_item({Type, Text, Ex}) ->
    TypeInt = data_talk:type_to_int(Type),
    TLen = byte_size(Text),
    ExBin = list_to_binary(util:implode("#&", Ex)),
    ExL = byte_size(ExBin),
    list_to_binary([<<TypeInt:16, TLen:16>>, Text, <<ExL:16, ExBin/binary>> ]).

%% 打包对话里的任务列表
%% 数据格式:[任务id,状态(1:可接，2：关联，3：未完成，4：已完成),名称]
pack_talk_task_list([]) ->
    <<0:16, <<>>/binary>>;
pack_talk_task_list(TaskList) ->
    L = [pack_talk_task_list(TaskId, State, Name)|| [TaskId, State, Name] <- TaskList],
    Len = length(TaskList),
    list_to_binary([<<Len:16>>, L]).
pack_talk_task_list(TaskId, State, Name) ->
    NL = byte_size(Name),
    <<TaskId:32, State:8, NL:16, Name/binary>>.