%%%--------------------------------------
%%% @Module  : pp_scene
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.05.09
%%% @Description:  场景
%%%--------------------------------------
-module(pp_scene).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%%走路
%%Status:player_status record
%%X:x坐标
%%Y:y坐标
handle(12001, Status, [X, Y]) ->
    % 走路
    {ok, BinData} = pt_12:write(12001, [X, Y, Status#player_status.id]),
    % 移除
    {ok, BinData1} = pt_12:write(12004, Status#player_status.id),
    % 有玩家进入
    {ok, BinData2} = pt_12:write(12003, pt_12:trans_to_12003(Status)),
    lib_scene:move_broadcast(Status#player_status.scene, X, Y, Status#player_status.x, Status#player_status.y, BinData, BinData1, BinData2, Status#player_status.socket),
%    lib_send:rand_to_process(Status#player_status.sid) ! {move, Status#player_status.scene, X, Y, Status#player_status.x, Status#player_status.y, BinData, BinData1, BinData2},

    %%坐骑扣除
    case Status#player_status.mount_spirit of
        [0,0] -> %% 没有坐坐骑
            %%回调更新状态
            Status1 = Status#player_status{x = X, y = Y},
            {ok, Status1};
        [G, S] ->
            M =  abs(X - Status#player_status.x) + abs(Y - Status#player_status.y) + Status#player_status.mount_spirit_cur,
            G0 = 50,
            case M > G0 of
                true -> %% 满G0扣除灵力
                    Spr = Status#player_status.spirit - G0 div G * S,
                    Spr1 = case Spr > 0of
                        true ->
                            Spr;
                        false ->
                            0
                    end,
                    %% 通知客户端
                    lib_player:refresh_spirit(Status#player_status.socket, Spr1),
                    Status1 = Status#player_status{x = X, y = Y, spirit = Spr1, mount_spirit_cur = M - G0},
                    {ok, spirit, Status1};
                false ->
                    %%回调更新状态
                    Status1 = Status#player_status{x = X, y = Y, mount_spirit_cur = M},
                    {ok, Status1}
            end
    end;

%%加载场景
handle(12002, Status, load_scene) ->
    case ets:lookup(?ETS_SCENE, Status#player_status.scene) of
        [] ->
            skip;
        [Scene] ->
            %%当前场景玩家信息
            SceneUser = lib_scene:get_broadcast_user(Status#player_status.scene, Status#player_status.x, Status#player_status.y),
            %%当前怪物信息
            SceneMon = lib_scene:get_scene_mon(Status#player_status.scene),
            %%当前元素信息
            SceneElem = Scene#ets_scene.elem,
            %%当前npc信息
            SceneNpc = lib_scene:get_scene_npc(Status#player_status.scene),
            {ok, BinData} = pt_12:write(12002, {SceneUser, SceneMon, SceneElem, SceneNpc}),
            lib_send:send_one(Status#player_status.socket, BinData),
            %%进入场景广播给其他玩家
            lib_scene:enter_scene(Status),
            %% NPC状态
            lib_scene:refresh_npc_ico(Status),
            ok
    end;

%%离开场景
handle(12004, Status, _Q) ->
    lib_scene:leave_scene(Status);

%%切换场景
handle(12005, Status, Id) ->
    case Id == Status#player_status.scene of
        true ->
            {ok, BinData} = pt_12:write(12005, [Id, Status#player_status.x, Status#player_status.y, <<>>, Id]),
            lib_send:send_one(Status#player_status.socket, BinData);
        false ->
            case lib_scene:check_enter(Status, Id) of
                {false, _, _, _, Msg, _, _} ->
                    {ok, BinData} = pt_12:write(12005, [0, 0, 0, Msg, 0]),
                    lib_send:send_one(Status#player_status.socket, BinData);
                {true, Id1, X, Y, Name, Sid, Status1} ->
                    {ok, BinData} = pt_12:write(12005, [Id1, X, Y, Name, Sid]),
                    lib_send:send_one(Status#player_status.socket, BinData),
                    %%告诉原来场景玩家你已经离开
                    lib_scene:leave_scene(Status),
                    Status2 = Status1#player_status{scene = Id1, x = X, y = Y},
                    {ok, Status2}
            end
    end;

%%离开副本场景
handle(12030, Status, _) ->
    mod_dungeon:quit(Status#player_status.pid_dungeon, Status#player_status.id),
    mod_dungeon:clear(role, Status#player_status.pid_dungeon);

%% 获取场景相邻关系数据
handle(12080, Status, []) ->
    BL = lib_scene:get_border(),
    {ok, BinData} = pt_12:write(12080, [BL]),
    lib_send:send_one(Status#player_status.socket, BinData);

handle(_Cmd, _Status, _Data) ->
    ?DEBUG("pp_scene no match", []),
    {error, "pp_scene no match"}.
