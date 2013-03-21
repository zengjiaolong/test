%%%-----------------------------------
%%% @Module  : lib_scene
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.05.08
%%% @Description: 场景信息
%%%-----------------------------------
-module(lib_scene).
-export([
            get_scene_user/1,
            get_scene_mon/1,
            leave_scene/1,
            enter_scene/1,
            mon_move/4,
            get_scene_npc/1,
            check_enter/2,
            is_blocked/2,
            refresh_npc_ico/1,
            is_safe/2,
            get_border/0,
            get_xy/2,
            get_broadcast_user/3,
            move_broadcast/9,
            revive_to_scene/2,
            get_res_id/1,
            is_dungeon_scene/1,
            get_data/1
        ]).
-include("common.hrl").
-include("record.hrl").

%%获得当前场景用户
%%Q:场景ID
get_scene_user(Q) ->
    ets:match(?ETS_ONLINE, #ets_online{
            id = '$1',
            nickname = '$2',
            x = '$3',
            y = '$4',
            hp = '$5',
            hp_lim = '$6',
            mp = '$7',
            mp_lim = '$8',
            lv = '$9',
            career = '$10',
            speed = '$11',
            equip_current = '$12',
            sex = '$13',
            leader = '$14',
            scene = Q,
            _='_'
        }
    ).

%%获得当前场景信息
%%Q:场景ID
get_scene_mon(Q) ->
    ets:match(?ETS_MON, #ets_mon{
            id = '$1',
            name = '$2',
            x = '$3',
            y = '$4',
            hp = '$5',
            hp_lim = '$6',
            mp = '$7',
            mp_lim = '$8',
            lv = '$9',
            mid = '$10',
            speed = '$11',
            icon = '$12',
            scene = Q,
            _='_'
        }
    ).

%% 获取指定场景的npc列表
get_scene_npc(SceneId) ->
    ets:match(?ETS_NPC, #ets_npc{
            id = '$1',
            nid = '$2',
            name = '$3',
            x = '$4',
            y = '$5',
            icon = '$6',
            scene = SceneId,
            _='_'
        }
    ).

%%离开当前场景
%%Socket:socket id
%%player记录
leave_scene(Status) ->
    {ok, BinData} = pt_12:write(12004, Status#player_status.id),
%    lib_send:send_to_scene(Status#player_status.scene, BinData).
    lib_send:send_to_area_scene(Status#player_status.scene, Status#player_status.x, Status#player_status.y, BinData).

%%进入当前场景
%%Socket:socket id
%%player记录
enter_scene(Status) ->
    %%通知所有玩家
    {ok, BinData} = pt_12:write(12003, pt_12:trans_to_12003(Status)),
%    lib_send:send_to_scene(Status#player_status.scene, BinData).
    lib_send:send_to_area_scene(Status#player_status.scene, Status#player_status.x, Status#player_status.y, BinData).

%%怪物移动
%%Q:情景
mon_move(X, Y, Mid, Q) ->
    {ok, BinData} = pt_12:write(12008, [X, Y, Mid]),
    lib_send:send_to_scene(Q, BinData).

%% 进入场景条件检查
check_enter(Status, Id) ->
    case get_data(Id) of
        [] ->
            {false, 0, 0, 0, <<"场景不存在!">>, 0, []};
        Scene ->
            case check_requirement(Status, Scene#ets_scene.requirement) of
                {false, Reason} -> {false, 0, 0, 0, Reason, 0, []};
                {true} ->
                    case Scene#ets_scene.type of
                        0 -> %% 普通场景
                            enter_normal_scene(Id, Scene, Status);
                        1 -> %% 普通场景
                            enter_normal_scene(Id, Scene, Status);
                        2 -> %% 副本场景
                            case is_pid(Status#player_status.pid_dungeon) andalso is_process_alive(Status#player_status.pid_dungeon) of
                                true ->
                                    enter_dungeon_scene(Scene, Status); %% 已经有副本服务进程
                                false -> %% 还没有副本服务进程
                                    Pid = case is_pid(Status#player_status.pid_team) andalso is_process_alive(Status#player_status.pid_team) of
                                        false -> %% 没有队伍，角色进程创建副本服务器
                                            mod_dungeon:start(0, self(), [{Status#player_status.id, Status#player_status.pid}]);
                                        true -> %% 有队伍，由队伍进程创建副本服务器
                                            mod_team:create_dungeon(Status#player_status.pid_team, self(), [Id, Status#player_status.id, Status#player_status.pid])
                                    end,
                                    case is_pid(Pid) of
                                        false ->
                                            {false, 0, 0, 0, <<"你不是队长不能创建副本!">>, 0, []};
                                        true ->
                                            enter_dungeon_scene(Scene, Status#player_status{pid_dungeon = Pid})
                                    end
                            end
                    end
            end
    end.

%% 逐个检查进入需求
check_requirement(_, []) ->
    {true};
check_requirement(Status, [{K, V} | T]) ->
    case K of
        lv -> %% 等级需求
            case Status#player_status.lv < V of
                true ->
                    Msg = "等级不够"++integer_to_list(V)++"级，无法进入该场景",
                    {false, list_to_binary(Msg)};
                false ->
                    check_requirement(Status, T)
            end;
        item -> %% 物品需求
%            case lib_storage:has_item(V) of
%                false ->
%                    Item = lib_item:item_info(V),
%                    Msg = [<<"你必需有">>, Item#item_base.name, <<"才能进入该场景">>],
%                    {false, list_to_binary(Msg)};
%                true -> check_requirement(Status, T)
%            end;
            check_requirement(Status, T);
        _ ->
            check_requirement(Status, T)
    end.

%%进入普通场景
enter_normal_scene(SceneId, Scene, Status) ->
    case [{X, Y} || [Id, _Name, X, Y] <- Scene#ets_scene.elem, Id =:= Status#player_status.scene] of
        [] -> {false, 0, 0, 0, <<"场景出错!">>, 0, []};
        [{X, Y}] -> {true, SceneId, X, Y, Scene#ets_scene.name, Scene#ets_scene.sid, Status}
    end.

 %% 进入副本场景
 enter_dungeon_scene(Scene, Status) ->
    case mod_dungeon:check_enter(Scene#ets_scene.sid, Status) of
        {false, Msg} ->
            {false, 0, 0, 0, Msg, 0, []};
        {true, Id} ->
            case ets:lookup(?ETS_SCENE, Status#player_status.scene) of
                []  -> {false, 0, 0, 0, <<"场景出错!">>, 0, []};
                [S] ->
                    case [{X, Y} || [Id0, _Name, X, Y] <- Scene#ets_scene.elem, Id0 =:= S#ets_scene.sid] of
                        [] -> {true, Id, Scene#ets_scene.x, Scene#ets_scene.y, Scene#ets_scene.name, Scene#ets_scene.sid, Status};
                        [{X, Y}] -> {true, Id, X, Y, Scene#ets_scene.name, Scene#ets_scene.sid, Status}
                    end
            end
    end.

%% 获取场景信息，唯一id，区分是不是副本
get_data(Id) ->
    case ets:lookup(?ETS_SCENE, Id) of
        []  -> data_scene:get(Id);
        [S] -> S
    end.

%% 用唯一id获取场景的资源id
get_res_id(Id) ->
    case is_copy_scene(Id) of
        false -> Id;    %% 无需转换
        true ->
            case ets:lookup(?ETS_SCENE, Id) of
                []  -> 0;
                [S] -> S#ets_scene.sid
            end
    end.

%% 是为拷贝本场景，唯一id
is_copy_scene(Id) ->
    Id > 999999.

%% 是否为副本场景，唯一id，会检查是否存在这个场景
is_dungeon_scene(Id) ->
    case is_copy_scene(Id) of
        false -> false;
        true ->
            case ets:lookup(?ETS_SCENE, Id) of
                [] -> false;
                [S] -> S#ets_scene.type =:=2
            end
    end.

%% 判断在场景SID的[X,Y]坐标是否有障碍物
is_blocked(SID, [X, Y]) ->
    case ets:lookup(?ETS_SCENE_POSES, {SID, X, Y}) of
            [] -> true; % 无障碍物
            [_] -> false % 有障碍物
    end.

%% 刷新npc任务状态
refresh_npc_ico(Rid) when is_integer(Rid)->
    case lib_player:get_online_info(Rid) of
        [] -> ok;
        S ->
            gen_server:cast(S#ets_online.pid, {cast, {?MODULE, refresh_npc_ico, []}})
    end;
        
refresh_npc_ico(Status) ->
    NpcList = get_scene_npc(Status#player_status.scene),
    L = [[NpcId, lib_task:get_npc_state(NpcId, Status)]|| [NpcId | _] <- NpcList],
    {ok, BinData} = pt_12:write(12020, [L]),
    lib_send:send_one(Status#player_status.socket, BinData).

%%是否安全区域
is_safe(Sid, [X1, Y1]) ->
    case ets:lookup(?ETS_SCENE, Sid) of
        [] ->
            flase;
        [Scene] ->
            [X, Y, W, H] = Scene#ets_scene.safe,
            if
                X1 >= X andalso X1 =< X + W ->
                    if
                        Y1 >= Y andalso Y1 =< Y + H ->
                            true;
                        true ->
                            false
                    end;
                true ->
                    false
            end
    end.

%% 获取所有场景的相邻关系
get_border() ->
    L = ets:tab2list(?ETS_SCENE),
    get_border_list(L, []).

%% 抽取相邻关系
get_border_list([], List) ->
    List;
get_border_list([S | T], List) ->
    BL = get_border_id_list(S#ets_scene.elem, []),
    B = {S#ets_scene.id, BL},
    get_border_list(T, [B | List]).

%% 抽取相邻场景的ID列表
get_border_id_list([], List) ->
    List;
get_border_id_list([[Id, _, _, _] | T], List) ->
    get_border_id_list(T, [Id | List]).

%%--------------------------九宫格加载场景---------------------------
%% 把整个地图共有100*100个格子，0，0坐标点为原点，以10*10为一个格子，从左到右编号1，2，3，4最终成为10*10的正方形
%获取当前所在的格子
get_xy(X, Y) ->
    Y div 16 * 8 + X div 8 + 1.

%%  获取要广播的范围用户信息
get_broadcast_user(Q, X0, Y0) ->
    AllUser = get_scene_user(Q),
    XY2 = lib_scene:get_xy(X0, Y0),
    get_broadcast_user_loop(AllUser, XY2, []).
    
get_broadcast_user_loop([], _XY2, D) ->
    D;
get_broadcast_user_loop([S|T], XY2, D) ->
    [Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent, Sex, Leader] = S,
    XY = lib_scene:get_xy(X, Y),
    if
        XY == XY2 orelse XY == XY2 + 1 orelse XY == XY2 -1 orelse XY == XY2 -8 orelse XY == XY2 +8 orelse XY == XY2 -9 orelse XY == XY2 +9 orelse XY == XY2 -7  orelse XY == XY2+7 ->
            get_broadcast_user_loop(T, XY2, D++[[Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent, Sex, Leader]]);
        true->
            get_broadcast_user_loop(T, XY2, D)
    end.

%%  获取要广播的范围用户ID
get_broadcast_id(Q, X0, Y0) ->
    AllUser = ets:match(?ETS_ONLINE, #ets_online{id = '$1',x = '$2', y='$3', scene = Q, _='_'}),
    XY2 = lib_scene:get_xy(X0, Y0),
    get_broadcast_id_loop(AllUser, XY2, []).

get_broadcast_id_loop([], _XY2, D) ->
    D;
get_broadcast_id_loop([[Id, X, Y]|T], XY2, D) ->
    XY = lib_scene:get_xy(X, Y),
    if
        XY == XY2 orelse XY == XY2 + 1 orelse XY == XY2 -1 orelse XY == XY2 -8 orelse XY == XY2 +8 orelse XY == XY2 -9 orelse XY == XY2 +9 orelse XY == XY2 -7  orelse XY == XY2+7 ->
            get_broadcast_id_loop(T, XY2, D++[Id]);
        true->
            get_broadcast_id_loop(T, XY2, D)
    end.
    
%% 复活进入场景
revive_to_scene(Status1, Status2) ->
    %%加载当前格子玩家和离开格子的玩家
    EnterUser = get_broadcast_user(Status2#player_status.scene, Status2#player_status.x, Status2#player_status.y),
    LeaveUser = get_broadcast_id(Status1#player_status.scene, Status1#player_status.x, Status1#player_status.y),
    %%加入和移除玩家
    {ok, BinData1} = pt_12:write(12011, [EnterUser, LeaveUser]),
    lib_send:send_one(Status2#player_status.socket, BinData1),
    %%告诉复活点的玩家你进入场景进
    {ok, BinData} = pt_12:write(12003, pt_12:trans_to_12003(Status2)),
    lib_send:send_to_area_scene(Status2#player_status.scene, Status2#player_status.x, Status2#player_status.y, BinData),
    lib_send:send_one(Status2#player_status.socket, BinData). % 还没写入新场景的坐标,所以要再发给自己
    

%%当人物或者怪物移动时候的广播
%%终点要X1，Y2，原点是X2,Y2
move_broadcast(Q, X1, Y1, X2, Y2, BinData, BinData1, BinData2, Socket) ->
    XY1 = get_xy(X1, Y1),
    XY2 = get_xy(X2, Y2),
    %%当前场景玩家信息
    AllUser = ets:match(?ETS_ONLINE, #ets_online{
            id = '$1',
            nickname = '$2',
            x = '$3',
            y = '$4',
            hp = '$5',
            hp_lim = '$6',
            mp = '$7',
            mp_lim = '$8',
            lv = '$9',
            career = '$10',
            sid = '$11',
            speed = '$12',
            equip_current = '$13',
            sex = '$14',
            leader = '$15',
            scene = Q,
            _='_'
    }),
    [SceneUser1, SceneUser2] = if
        XY2 == XY1 -> %% 同一个格子内
            move_loop1(AllUser, [XY1, XY2, BinData, BinData1, BinData2], [], []);
        XY2 + 1 == XY1 -> %% 向右
            move_loop2(AllUser, [XY1, XY2, BinData, BinData1, BinData2], [], []);
        XY2 - 1 == XY1 -> %% 向左
            move_loop3(AllUser, [XY1, XY2, BinData, BinData1, BinData2], [], []);
        XY2 - 8 == XY1 -> %% 向上
            move_loop4(AllUser, [XY1, XY2, BinData, BinData1, BinData2], [], []);
        XY2 + 8 == XY1 -> %% 向下
            move_loop5(AllUser, [XY1, XY2, BinData, BinData1, BinData2], [], []);
        XY2 - 9 == XY1 -> %% 向左上
            move_loop6(AllUser, [XY1, XY2, BinData, BinData1, BinData2], [], []);
        XY2 + 7 == XY1 -> %% 向左下
            move_loop7(AllUser, [XY1, XY2, BinData, BinData1, BinData2], [], []);
        XY2 - 7 == XY1 -> %% 向右上
            move_loop8(AllUser, [XY1, XY2, BinData, BinData1, BinData2], [], []);
        XY2 + 9 == XY1 -> %% 向右下
            move_loop9(AllUser, [XY1, XY2, BinData, BinData1, BinData2], [], []);
        true ->
            move_loop1(AllUser, [XY1, XY2, BinData, BinData1, BinData2], [], [])
    end,
    %%加入和移除玩家
    {ok, BinData3} = pt_12:write(12011, [SceneUser1, SceneUser2]),
    lib_send:send_one(Socket, BinData3).
    
move_loop1([],_ , User1, User2) ->
    [User1, User2];
move_loop1([D | T], [XY1, XY2, BinData, BinData1, BinData2], User1, User2 ) ->
    [_Id, _Nick, X, Y, _Hp, _Hp_lim, _Mp, _Mp_lim, _Lv, _Career, Sid | _] = D,
     XY = get_xy(X, Y),
    if
        XY == XY2 orelse XY == XY2 + 1 orelse XY == XY2 -1 orelse XY == XY2 -8 orelse XY == XY2 +8 orelse XY == XY2 -9 orelse XY == XY2 +9 orelse XY == XY2 -7  orelse XY == XY2+7 ->
            lib_send:send_to_sid(Sid, BinData),
            move_loop1(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2);
        true ->
            move_loop1(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2)
    end.

move_loop2([],_ , User1, User2) ->
    [User1, User2];
move_loop2([D | T], [XY1, XY2, BinData, BinData1, BinData2], User1, User2) ->
    [Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Sid, Speed, EquipCurrent, Sex, Leader] = D,
    XY = get_xy(X, Y),
    if
        XY == XY1 + 1 orelse XY == XY1 + 9 orelse XY == XY1 - 7 -> % 进入
            lib_send:send_to_sid(Sid, BinData2),
            move_loop2(T, [XY1, XY2, BinData, BinData1, BinData2], User1++[[Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent, Sex, Leader]], User2);
        XY == XY2 - 1 orelse XY == XY2 - 9 orelse XY == XY2 + 7 -> % 离开
            lib_send:send_to_sid(Sid, BinData1),
            move_loop2(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2++[Id]);
        XY == XY2 orelse XY == XY2 + 1  orelse XY == XY2 -8 orelse XY == XY2 +8 orelse XY == XY2 + 9 orelse XY == XY2 - 7 -> % 公共区域
            lib_send:send_to_sid(Sid, BinData),
            move_loop2(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2);
        true ->
            move_loop2(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2)
    end.

move_loop3([],_ , User1, User2) ->
    [User1, User2];
move_loop3([D | T], [XY1, XY2, BinData, BinData1, BinData2], User1, User2 ) ->
    [Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Sid, Speed, EquipCurrent, Sex, Leader] = D,
    XY = get_xy(X, Y),
    if
        XY == XY1 - 1 orelse XY == XY1 - 9 orelse XY == XY1 + 7 -> % 进入
            lib_send:send_to_sid(Sid, BinData2),
            move_loop3(T, [XY1, XY2, BinData, BinData1, BinData2], User1++[[Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent, Sex, Leader]], User2);
        XY == XY2 + 1 orelse XY == XY2 + 9 orelse XY == XY2 - 7 -> % 离开
            lib_send:send_to_sid(Sid, BinData1),
             move_loop3(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2++[Id]);
         XY == XY2 orelse XY == XY2 - 9 orelse XY == XY2 -1 orelse XY == XY2 -8 orelse XY == XY2 +8 orelse XY == XY2+7 ->
            lib_send:send_to_sid(Sid, BinData),
            move_loop3(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2);
        true ->
            move_loop3(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2)
    end.

move_loop4([],_ , User1, User2) ->
    [User1, User2];
move_loop4([D | T], [XY1, XY2, BinData, BinData1, BinData2], User1, User2) ->
    [Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Sid, Speed, EquipCurrent, Sex, Leader] = D,
    XY = get_xy(X, Y),
    if
        XY == XY1 - 8 orelse XY == XY1 - 9 orelse XY == XY1 - 7 ->
            lib_send:send_to_sid(Sid, BinData2),
            move_loop4(T, [XY1, XY2, BinData, BinData1, BinData2], User1++[[Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent, Sex, Leader]], User2);
        XY == XY2 + 8 orelse XY == XY2 + 9 orelse XY == XY2 + 7 -> % 离开
            lib_send:send_to_sid(Sid, BinData1),
            move_loop4(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2++[Id]);
        XY == XY2 orelse XY == XY2 + 1 orelse XY == XY2 -1 orelse XY == XY2 -8 orelse XY == XY2 -9 orelse XY == XY2 -7 ->
            lib_send:send_to_sid(Sid, BinData),
            move_loop4(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2);
        true ->
            move_loop4(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2)
    end.

move_loop5([],_ , User1, User2) ->
    [User1, User2];
move_loop5([D | T], [XY1, XY2, BinData, BinData1, BinData2], User1, User2) ->
    [Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Sid, Speed, EquipCurrent, Sex, Leader] = D,
    XY = get_xy(X, Y),
    if
        XY == XY1 + 8 orelse XY == XY1 + 9 orelse XY == XY1 + 7 ->
            lib_send:send_to_sid(Sid, BinData2),
            move_loop5(T, [XY1, XY2, BinData, BinData1, BinData2], User1++[[Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent, Sex, Leader]], User2);
        XY == XY2 - 8 orelse XY == XY2 - 9 orelse XY == XY2 - 7-> % 离开
            lib_send:send_to_sid(Sid, BinData1),
            move_loop5(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2++[Id]);
        XY == XY2 orelse XY == XY2 + 1 orelse XY == XY2 -1 orelse XY == XY2 +8 orelse XY == XY2 +9 orelse XY == XY2 +7 ->
            lib_send:send_to_sid(Sid, BinData),
            move_loop5(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2);
        true ->
            move_loop5(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2)
    end.

move_loop6([],_ , User1, User2) ->
    [User1, User2];
move_loop6([D | T], [XY1, XY2, BinData, BinData1, BinData2], User1, User2) ->
    [Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Sid, Speed, EquipCurrent, Sex, Leader] = D,
    XY = get_xy(X, Y),
    if
        XY == XY1 - 1 orelse XY == XY1 - 9 orelse XY == XY1 - 8 orelse XY == XY1 - 7 orelse XY == XY1 + 7 ->
            lib_send:send_to_sid(Sid, BinData2),
            move_loop6(T, [XY1, XY2, BinData, BinData1, BinData2], User1++[[Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent, Sex, Leader]], User2);
        XY == XY2 + 1 orelse XY == XY2 + 9 orelse XY == XY2 + 8 orelse XY == XY2 + 7 orelse XY == XY2 - 7 ->
            lib_send:send_to_sid(Sid, BinData1),
            move_loop6(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2++[Id]);
        XY == XY2 orelse XY == XY2 - 9 orelse XY == XY2 -1 orelse XY == XY2 -8 ->
            lib_send:send_to_sid(Sid, BinData),
            move_loop6(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2);
        true ->
            move_loop6(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2)
    end.

move_loop7([],_ , User1, User2) ->
    [User1, User2];
move_loop7([D | T], [XY1, XY2, BinData, BinData1, BinData2], User1, User2) ->
    [Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Sid, Speed, EquipCurrent, Sex, Leader] = D,
    XY = get_xy(X, Y),
    if
        XY == XY1 - 9 orelse XY == XY1 - 1 orelse XY == XY1 + 7 orelse XY == XY1 + 8 orelse XY == XY1 + 9 ->
            lib_send:send_to_sid(Sid, BinData2),
            move_loop7(T, [XY1, XY2, BinData, BinData1, BinData2], User1++[[Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent, Sex, Leader]], User2);
        XY == XY2 + 9 orelse XY == XY2 + 1 orelse XY == XY2 - 7 orelse XY == XY2 - 8 orelse XY == XY2 - 9 ->
            lib_send:send_to_sid(Sid, BinData1),
            move_loop7(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2++[Id]);
        XY == XY2 orelse XY == XY2 -1 orelse XY == XY2 + 8 orelse XY == XY2 +7 ->
            lib_send:send_to_sid(Sid, BinData),
            move_loop7(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2);
        true ->
            move_loop7(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2)
    end.

move_loop8([],_ , User1, User2) ->
    [User1, User2];
move_loop8([D | T], [XY1, XY2, BinData, BinData1, BinData2], User1, User2) ->
    [Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Sid, Speed, EquipCurrent, Sex, Leader] = D,
    XY = get_xy(X, Y),
    if
        XY == XY1 + 1 orelse XY == XY1 + 9 orelse XY == XY1 - 7 orelse XY == XY1 - 8 orelse XY == XY1 - 9 ->
            lib_send:send_to_sid(Sid, BinData2),
            move_loop8(T, [XY1, XY2, BinData, BinData1, BinData2], User1++[[Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent, Sex, Leader]], User2);
        XY == XY2 - 1 orelse XY == XY2 - 9 orelse XY == XY2 + 7 orelse XY == XY2 + 8 orelse XY == XY2 + 9 ->
            lib_send:send_to_sid(Sid, BinData1),
            move_loop8(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2++[Id]);
        XY == XY2 orelse XY == XY2 +1 orelse XY == XY2 -8 orelse XY == XY2 - 7 ->
            lib_send:send_to_sid(Sid, BinData),
            move_loop8(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2);
        true ->
            move_loop8(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2)
    end.

move_loop9([],_ , User1, User2) ->
    [User1, User2];
move_loop9([D | T], [XY1, XY2, BinData, BinData1, BinData2], User1, User2) ->
    [Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Sid, Speed, EquipCurrent, Sex, Leader] = D,
    XY = get_xy(X, Y),
    if
        XY == XY1 + 1 orelse XY == XY1 + 7 orelse XY == XY1 + 8 orelse XY == XY1 + 9 orelse XY == XY1 - 7 ->
            lib_send:send_to_sid(Sid, BinData2),
            move_loop9(T, [XY1, XY2, BinData, BinData1, BinData2], User1++[[Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent, Sex, Leader]], User2++[Id]);
        XY == XY2 - 1 orelse XY == XY2 - 7 orelse XY == XY2 - 8 orelse XY == XY2 - 9 orelse XY == XY2 + 7 ->
            lib_send:send_to_sid(Sid, BinData1),
            move_loop9(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2++[Id]);
        XY == XY2 orelse XY == XY2 + 1 orelse XY == XY2 +8 orelse XY == XY2 + 9 ->
            lib_send:send_to_sid(Sid, BinData),
            move_loop9(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2);
        true ->
            move_loop9(T, [XY1, XY2, BinData, BinData1, BinData2], User1, User2)
    end.