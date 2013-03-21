%%%-----------------------------------
%%% @Module  : pp_npc
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.06.13
%%% @Description: npc
%%%-----------------------------------
-module(pp_npc).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%% 获取npc默认对话和关联任务
%% return {ok, [int, list, list], record}
handle(32000, PlayerStatus, [Id]) ->
    case ets:lookup(?ETS_NPC, Id) of
        [] -> ok;
        [Npc] ->
            {TaskList, TalkList} = default_talk(Npc, PlayerStatus),
            {ok, BinData} = pt_32:write(32000, [Id, TaskList, TalkList]),
            lib_send:send_one(PlayerStatus#player_status.socket, BinData)
    end;

%% 任务对话
handle(32001, PlayerStatus, [Id, TaskId])->
    case ets:lookup(?ETS_NPC, Id) of
        [] -> ok;
        [Npc] -> task_talk(Id, TaskId, Npc, PlayerStatus)
    end;

handle(_Cmd, _PlayerStatus, _Data) ->
    {error, bad_request}.

%% --------- 私有函数 ----------

default_talk(Npc, PlayerStatus) ->
    TalkList = data_talk:get(Npc#ets_npc.talk),
    TaskList = lib_task:get_npc_task_list(Npc#ets_npc.nid, PlayerStatus),
    {TaskList, TalkList}.

task_talk(Id, TaskId, Npc, PlayerStatus) ->
    {_Type, TalkId} = lib_task:get_npc_task_talk_id(TaskId, Npc#ets_npc.nid, PlayerStatus),
    TalkList = data_talk:get(TalkId),
%    %% 如果是开始对话或结束对话，加入任务奖励
%    NewTalkList =
%    case (Type =:= start_talk orelse Type =:= end_talk ) andalso TalkList =/= [] of
%        false -> TalkList;
%        true -> add_awrad_talk(TaskId, TalkList, PlayerStatus)
%    end,
    {ok, BinData} = pt_32:write(32001, [Id, TaskId, TalkList]),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData).

%add_awrad_talk(TaskId, TalkList, PlayerStatus)->
%    [FiPlayerStatust | T ] = TalkList,
%    TD = lib_task:get_data(TaskId, PlayerStatus),
%    NewFiPlayerStatust = FiPlayerStatust ++ [{task_award, lib_task:get_award_msg(TD, PlayerStatus), []}],
%    [NewFiPlayerStatust | T].
