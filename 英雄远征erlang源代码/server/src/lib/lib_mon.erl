%%%-----------------------------------
%%% @Module  : lib_mon
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.05.08
%%% @Description: 怪物
%%%-----------------------------------
-module(lib_mon).
-include("common.hrl").
-include("record.hrl").
-export(
    [
        get_name_by_mon_id/1,
        get_scene_by_mon_id/1
    ]
).

%% 获取MON当前场景信息
get_scene_by_mon_id(MonId) ->
    case ets:match(?ETS_MON, #ets_mon{mid = MonId, scene = '$1', x = '$2', y = '$3',  _ = '_'}) of
        [] -> 0;
        [[Scene, X, Y]|_] -> [Scene, X, Y]
    end.

%% 获取mon名称用mon数据库id
get_name_by_mon_id(MonId)->
    case data_mon:get(MonId) of
        [] -> <<"">>;
        Mon -> Mon#ets_mon.name
    end.
