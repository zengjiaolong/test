%%%--------------------------------------
%%% @Module  : pp_base
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.04.29
%%% @Description:  基础功能
%%%--------------------------------------
-module(pp_base).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%%退出登陆
handle(10001, Status, logout) ->
    gen_server:cast(Status#player_status.pid, 'LOGOUT'),
    {ok, BinData} = pt_10:write(10001, []),
    lib_send:send_one(Status#player_status.socket, BinData);

%%心跳包
handle(10006, Status, heartbeat) ->
    %%todo:测试数据而已
    %% 通过心跳包回血回蓝
    case Status#player_status.hp >0 andalso (Status#player_status.hp < Status#player_status.hp_lim orelse Status#player_status.mp < Status#player_status.mp_lim) of
        true ->
            Hp = if
                Status#player_status.hp + 50 > Status#player_status.hp_lim ->
                    Status#player_status.hp_lim;
                true ->
                    Status#player_status.hp + 50
            end,
            Mp = if
                Status#player_status.mp + 50 > Status#player_status.mp_lim ->
                    Status#player_status.mp_lim;
                true ->
                    Status#player_status.mp + 50
            end,
            Status1 = Status#player_status{hp = Hp, mp = Mp},
            {ok, BinData1} = pt_12:write(12009, [Status1#player_status.id, Status1#player_status.hp, Status1#player_status.hp_lim]),
            lib_send:send_to_area_scene(Status1#player_status.scene, Status1#player_status.x, Status1#player_status.y, BinData1),
            {ok, Status1};
        false ->
            ok
    end;
    
    %{ok, BinData2} = pt_10:write(10006, []),
    %lib_send:send_one(Status#player_status.socket, BinData2)

handle(_Cmd, _Status, _Data) ->
    ?DEBUG("pp_base no match", []),
    {error, "pp_base no match"}.
