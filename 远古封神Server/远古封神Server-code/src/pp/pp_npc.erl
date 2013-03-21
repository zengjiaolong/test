%%%-----------------------------------
%%% @Module  : pp_npc
%%% @Author  : ygzj
%%% @Created : 2010.09.23
%%% @Description: npc
%%%-----------------------------------
-module(pp_npc).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%% 获取npc默认对话和关联任务 
%% return {ok, [int, list, list], record}
handle(32000, PlayerStatus, [NpcUniqueId]) ->
	SceneId = PlayerStatus#player.scene,
    case mod_scene:find_npc(NpcUniqueId, SceneId) of
        [] -> ok;
        [Npc] ->
            {TaskList, TalkList} = default_talk(Npc, PlayerStatus),
			case PlayerStatus#player.realm =:= 100 orelse length(TaskList)=:= 1 of
				true->
					%%[[20100,3, <<229,145,189,232,191,144,228,185,139,229,173,144>>,4]]
					case TaskList /= [] of
						true->
							case lib_task:check_npc_type(Npc) of
								true->
									[[TaskId|_]|_]=TaskList,
									handle(32001, PlayerStatus, [NpcUniqueId, TaskId]);
								false->
									{ok, BinData} = pt_32:write(32000, [NpcUniqueId, TaskList, TalkList]),
            				lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
							end;
						false->
							{ok, BinData} = pt_32:write(32000, [NpcUniqueId, TaskList, TalkList]),
            				lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
					end;
				false->
            		{ok, BinData} = pt_32:write(32000, [NpcUniqueId, TaskList, TalkList]),
            		lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData) 
			end
    end;

%% 任务对话
handle(32001, PlayerStatus, [NpcUniqueId, TaskId])->
	SceneId = PlayerStatus#player.scene,
    case mod_scene:find_npc(NpcUniqueId, SceneId) of
        [] -> ok;
        [Npc] -> task_talk(NpcUniqueId, TaskId, Npc, PlayerStatus)
    end;

handle(_Cmd, _PlayerStatus, _Data) ->
    {error, bad_request}.

%% --------- 私有函数 ----------

default_talk(Npc, PlayerStatus) ->
    TalkList = data_agent:talk_get(Npc#ets_npc.talk),
    TaskList = lib_task:get_npc_task_list(Npc#ets_npc.nid, PlayerStatus),
    {TaskList, TalkList}.

task_talk(Id, TaskId, Npc, PlayerStatus) ->
    {_Type, TalkId} = lib_task:get_npc_task_talk_id(TaskId, Npc#ets_npc.nid, PlayerStatus),
    TalkList = data_agent:talk_get(TalkId),
%    %% 如果是开始对话或结束对话，加入任务奖励
%    NewTalkList =
%    case (Type =:= start_talk orelse Type =:= end_talk ) andalso TalkList =/= [] of
%        false -> TalkList;
%        true -> add_awrad_talk(TaskId, TalkList, PlayerStatus)
%    end,
%% 	io:format("Task talk8****~p~n",[[Type,TalkList]]),
    {ok, BinData} = pt_32:write(32001, [Id, TaskId, TalkList]),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData).

%add_awrad_talk(TaskId, TalkList, PlayerStatus)->
%    [FiPlayerStatust | T ] = TalkList,
%    TD = lib_task:get_data(TaskId, PlayerStatus),
%    NewFiPlayerStatust = FiPlayerStatust ++ [{task_award, lib_task:get_award_msg(TD, PlayerStatus), []}],
%    [NewFiPlayerStatust | T].
