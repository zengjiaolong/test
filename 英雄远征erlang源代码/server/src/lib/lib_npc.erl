%%%-----------------------------------
%%% @Module  : lib_npc
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.05.05
%%% @Description: npc
%%%-----------------------------------
-module(lib_npc).
-include("common.hrl").
-include("record.hrl").
-export(
    [
        get_name_by_npc_id/1,
        get_data/1,
        get_npc_id/1,
        get_scene_by_npc_id/1,
        get_id/2
    ]
).

%% 获取npc名称用npc数据库id
get_name_by_npc_id(NpcId)->
    case data_npc:get(NpcId) of
        [] -> <<"">>;
        Npc -> Npc#ets_npc.name
    end.

%% 获取信息
get_data(NpcId) ->
    case data_npc:get(NpcId) of
        [] -> ok;
        Npc -> Npc
    end.

%%获取NPC真实id
get_npc_id(Id) ->
    case ets:lookup(?ETS_NPC, Id) of
        [] -> 0;
        [Npc] -> Npc#ets_npc.nid
    end.

%% 获取NPC当前场景信息
get_scene_by_npc_id(NpcId) ->
    case ets:match(?ETS_NPC, #ets_npc{nid = NpcId, scene = '$1', x = '$2', y = '$3',  _ = '_'}) of
        [] -> [];
        [[Scene, X, Y]|_] -> [Scene, X, Y]
    end.

%% 或得唯一id
get_id(NpcId, SceneId) ->
    case ets:match(?ETS_NPC, #ets_npc{id ='$1', nid = NpcId, scene = SceneId,  _ = '_'}) of
        [] -> 0;
        [[Id]|_] -> Id
    end.
