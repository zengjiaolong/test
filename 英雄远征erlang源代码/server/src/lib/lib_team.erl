%%%------------------------------------
%%% @Module  : lib_team
%%% @Author  : zzm
%%% @Email   : ming_up@163.com
%%% @Created : 2010.08.07
%%% @Description: 组队模块公共函数
%%%------------------------------------

-module(lib_team).
-export([send_leaderid_area_scene/2]).
-include("common.hrl").
-include("record.hrl").

%%Id：队长id
%%Type：
%%  1 => 上任队长
%%  0 => 卸任队长
send_leaderid_area_scene(Id, Type) ->
    case ets:lookup(?ETS_ONLINE, Id) of
        [] -> ok;
        [Player] -> 
            {ok, BinData} = pt_12:write(12018, [Id, Type]),
            lib_send:send_to_area_scene(Player#ets_online.scene, Player#ets_online.x,  Player#ets_online.y, BinData)
    end.

