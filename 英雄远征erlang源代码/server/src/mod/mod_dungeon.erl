%%%-----------------------------------
%%% @Module  : mod_dungeon
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.07.05
%%% @Description: 副本
%%%-----------------------------------
-module(mod_dungeon).
-behaviour(gen_server).
-export([
        start/3,
        check_enter/2,
        join/2,
        quit/2,
        clear/2,
        out/2,
        get_outside_scene/1,
        kill_npc/2,
        clear_rl/2
    ]
).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include("common.hrl").
-include("record.hrl").
-record(state, {
    team_pid = 0,
    rl = [],   %% 副本服务器所属玩家
    dsrl = [], %% 副本场景激活条件
    dsl =[]    %% 副本服务器所拥有的场景
}).

-record(r, {id, pid}).
-record(ds, {id, did, sid, enable=true, tip = <<>>}).

%% ----------------------- 对外接口 ---------------------------------
%% 进入副本
check_enter(SceneResId, Status) ->
    gen_server:call(Status#player_status.pid_dungeon, {check_enter, SceneResId}).

%% 创建副本进程，由srv_scene调用
start(TeamPid, From, RoleList) ->
    {ok, Pid} = gen_server:start(?MODULE, [TeamPid, RoleList], []),
    [clear(role, Id) || {Id, _} <- RoleList],
    [mod_player:set_dungeon(Rpid, Pid) || {_, Rpid} <- RoleList, Rpid =/= From],
    Pid.

%% 主动加入新的角色
join(DungeonPid, Rid) ->
    clear(role, Rid),
    case is_pid(DungeonPid) andalso is_process_alive(DungeonPid) of
        false -> false;
        true -> gen_server:call(DungeonPid, {join, Rid}) %% DungeonPid ! {join, Rid}
    end.

%% 角色主动清除
quit(DungeonPid, Rid) ->
    case is_pid(DungeonPid) andalso is_process_alive(DungeonPid) of
        false -> false;
        true -> DungeonPid ! {quit, Rid}
    end.

%% 清除副本进程
clear(Type, Id) when is_integer(Id) ->
    case lib_player:get_online_info(Id) of
        [] -> false;
        R -> clear(Type, R#ets_online.pid_dungeon)
    end;
clear(Type, DungeonPid) when is_pid(DungeonPid) ->
    case is_process_alive(DungeonPid) of
        false -> false;
        true -> 
            case Type of
                team -> DungeonPid ! team_clear;
                role -> DungeonPid ! role_clear
            end,
            true
    end;
clear(_Type, _Id) -> false.

%% 将玩家传出副本
out(DungeonPid, Rid) ->
    case is_pid(DungeonPid) andalso is_process_alive(DungeonPid) of
        false -> false;
        true -> DungeonPid ! {out, Rid}
    end.

%% 清楚clear_rl列表
clear_rl(DungeonPid, Rid) ->
    case is_pid(DungeonPid) andalso is_process_alive(DungeonPid) of
        false -> false;
        true -> DungeonPid ! {clear_rl, Rid}
    end.

%% 获取玩家所在副本的外场景
get_outside_scene(SceneId) ->
    case get_dungeon_id(lib_scene:get_res_id(SceneId)) of
        0 -> false;  %% 不在副本场景
        Did ->  %% 将传送出副本
            DD = data_dungeon:get(Did),
            DD#dungeon.out
    end.

kill_npc(PS, NpcIdList) ->
    case lib_scene:is_dungeon_scene(PS#player_status.scene) of
        false -> ok; %% 不处理非副本的打怪事件
        true ->
            case is_pid(PS#player_status.pid_dungeon) andalso is_process_alive(PS#player_status.pid_dungeon) of
                false -> ok; %% TODO 异常暂时不处理
                true -> PS#player_status.pid_dungeon ! {kill_npc, PS#player_status.scene, NpcIdList}
            end
    end.

%% 创建副本场景
create_scene(SceneId, State) ->
    Id = mod_scene:get_scene_auto_id(), %% 获取唯一id
    mod_scene:copy_scene(Id, SceneId),  %% 复制场景
    F = fun(DS) ->
        case DS#ds.sid =:= SceneId of
            true -> DS#ds{id = Id};
            false -> DS
        end
    end,
    NewState = State#state{dsl = [F(X)|| X <- State#state.dsl]},    %% 更新副本场景的唯一id
    {Id, NewState}.

%% 组织副本的基础数据
get_dungeon_data([], DSR, DS) ->
    {DSR, DS};
get_dungeon_data(DidList, DSR, DS) ->
    [Did | NewDidList] = DidList,
    D = data_dungeon:get(Did),
    S = [#ds{id=0, did=Did, sid=Sid, enable=Enable, tip=Msg} || {Sid, Enable, Msg} <- D#dungeon.scene],
    get_dungeon_data(NewDidList, DSR ++ D#dungeon.requirement, DS ++ S).


%% ------------------------- 服务器内部实现 ---------------------------------
init([TeamPid, RoleList]) ->
    RL = [#r{id=Rid, pid=Rpid} || {Rid, Rpid} <- RoleList],
    {DSRL, DSL} = get_dungeon_data(data_dungeon:get_ids(), [], []),
    State = #state{
        team_pid = TeamPid,
        rl = RL,
        dsrl = DSRL,
        dsl = DSL
    },
    {ok, State}.

%%检查进入副本
handle_call({check_enter, SceneResId}, _From, State) ->   %% 这里的SceneId是数据库的里的场景id，不是唯一id
    case lists:keyfind(SceneResId, 4, State#state.dsl) of
        false ->
            {reply, {false, <<"没有这个副本场景">>}, State};   %%没有这个副本场景
        DS ->
            case DS#ds.enable of
                false ->
                    {reply, {false, DS#ds.tip}, State};    %%还没被激活
                true ->
                    {SceneId, NewState} = case DS#ds.id =/= 0 of
                        true -> {DS#ds.id, State};   %%场景已经加载过
                        false -> create_scene(SceneResId, State)
                    end,
                    {reply, {true, SceneId}, NewState}
            end
    end;

%% 加入副本服务
handle_call({join, Rid}, _From, State) ->
    case lib_player:get_online_info(Rid) of
        false -> {reply, false, State};
        R ->
            clear(role, R#ets_online.pid_dungeon),  %% 清除上个副本服务进程
            case lists:keyfind(Rid, 2, State#state.rl) of
                true -> {reply, true, State};
                false -> 
                    NewRL = State#state.rl ++ [#r{id = Rid, pid = R#ets_online.pid}],
                    {reply, true, State#state{rl = NewRL}}
            end
    end;

handle_call(_Request, _From, State) ->
    {noreply, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

%% 将指定玩家传出副本,不保留个人信息副本进程不让进入
%% Rid：玩家ID
handle_info({quit, Rid}, State) ->
    case lists:keyfind(Rid, 2, State#state.rl) of
        false -> {noreply, State};
        _ ->
            case lib_player:get_online_info(Rid) of
                [] -> ok;   %% 不在线
                R -> 
                    mod_player:set_dungeon(R#ets_online.pid, none),
                    send_out(R)
            end,
            {noreply, State#state{rl = lists:keydelete(Rid, 2, State#state.rl)}}
    end;

%% 将指定玩家传出副本,不保留个人信息副本进程不让进入
%% Rid：玩家ID
handle_info({clear_rl, Rid}, State) ->
    case lists:keyfind(Rid, 2, State#state.rl) of
        false -> {noreply, State};
        _ ->
            {noreply, State#state{rl = lists:keydelete(Rid, 2, State#state.rl)}}
    end;

%% 将指定玩家传出副本,保留个人信息的副本进程还让进入
%% Rid：玩家ID
handle_info({out, Rid}, State) ->
    case lists:keyfind(Rid, 2, State#state.rl) of
        false -> {noreply, State};
        _ ->
            case lib_player:get_online_info(Rid) of
                [] -> ok;   %% 不在线
                R -> send_out(R)
            end,
            {noreply, State}
    end;


%% 关闭副本服务进程
handle_info(team_clear, State) ->
    F = fun(RX) -> mod_player:set_dungeon(RX#r.pid, none), send_out(RX#r.id) end,
    [F(R)|| R <- State#state.rl],
    [mod_scene:clear_scene(Ds#ds.id)|| Ds <- State#state.dsl, Ds#ds.id =/= 0],
    {stop, normal, State};

%% 关闭副本服务进程
handle_info(role_clear, State) ->
    case is_pid(State#state.team_pid) of
        true -> %% 有组队
            case length(State#state.rl) > 1 of  %% 判断队伍是否没有人了
                true ->
                    {noreply, State};
                false ->
                    [mod_scene:clear_scene(Ds#ds.id)|| Ds <- State#state.dsl, Ds#ds.id =/= 0],
                    {stop, normal, State}
            end;
        false ->
            [mod_scene:clear_scene(Ds#ds.id)|| Ds <- State#state.dsl, Ds#ds.id =/= 0],
            {stop, normal, State}
    end;

%% 接收杀怪事件
handle_info({kill_npc, EventSceneId, NpcIdList}, State) ->
    %% TODO 杀的怪是否有用
    case lists:keyfind(EventSceneId, 2, State#state.dsl) of
        false -> {noreply, State};    %% 没有这个场景id
        _ ->
            {NewDSRL, UpdateScene} = event_action(State#state.dsrl, [], NpcIdList, []),
            EnableScene = get_enable(UpdateScene, [], NewDSRL),
            NewState = enable_action(EnableScene, State#state{dsrl = NewDSRL}),
            {noreply, NewState}
    end;

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% 私有方法--------------------------------
%% 传送出副本

send_out(Id) when is_integer(Id)->
    case lib_player:get_online_info(Id) of
        false -> offline;   %% 不在线
        R -> send_out(R)
    end;

send_out(R) when is_record(R, ets_online) ->
    case get_dungeon_id(lib_scene:get_res_id(R#ets_online.scene)) of
        0 -> scene_not_exist;  %% 不在副本场景
        Did -> %% 将传送出副本
            DD = data_dungeon:get(Did),
            [Sid, X, Y] = DD#dungeon.out,
            Player = gen_server:call(R#ets_online.pid, 'PLAYER'),
            lib_scene:leave_scene(Player),
            Player1 = Player#player_status{pid_dungeon = none, scene = Sid, x = X, y = Y},
            gen_server:cast(R#ets_online.pid, {'SET_PLAYER', Player1}),
            {ok, BinData} = pt_12:write(12005, [Sid, X, Y, <<>>, Sid]),
            lib_send:send_one(Player1#player_status.socket, BinData)
    end.

get_enable([], Result, _) ->
    Result;

get_enable([SceneId | T ], Result, DSRL) ->
    case length([0 || [EnableSceneResId, Fin | _ ] <- DSRL, EnableSceneResId =:= SceneId, Fin =:= false]) =:= 0 of
        false -> get_enable(T, Result, DSRL);
        true -> get_enable(T, [SceneId | Result], DSRL)
    end.

enable_action([], State) ->
    State;

enable_action([SceneId | T], State) ->
    case lists:keyfind(SceneId, 4, State#state.dsl) of
        false -> enable_action(T, State);%%这里属于异常
        DS -> %% TODO 广播场景以激活
            NewDSL = lists:keyreplace(SceneId, 4, State#state.dsl, DS#ds{enable = true}),
            %S = lib_scene:get_data(SceneId),
            %lib_conn:pack_cast(dungeon, self(), 10010 , [list_to_binary(["场景【", S#scene.name, "】已激活！"])]),
            enable_action(T, State#state{dsl = NewDSL})
    end.

event_action([], Req, _, Result) ->
    {Req, Result};

event_action([[EnableSceneResId, false, kill_npc, NpcId, Num, NowNum] | T ], Req, Param, Result)->
    NpcList = Param,
    case length([X||X <- NpcList, NpcId =:= X]) of
        0 -> event_action(T, [[EnableSceneResId, false, kill_npc, NpcId, Num, NowNum] | Req], Param, Result);
        FightNum ->
            case NowNum + FightNum >= Num of
                true -> event_action(T, [[EnableSceneResId, true, kill_npc, NpcId, Num, Num] | Req], Param, lists:umerge(Result, [EnableSceneResId]));
                false -> event_action(T, [[EnableSceneResId, false, kill_npc, NpcId, Num, NowNum + FightNum] | Req], Param, lists:umerge(Result, [EnableSceneResId]))
            end
    end;

%% 丢弃异常和已完成的
event_action([_ | T], Req, Param, Result) ->
    event_action(T, Req, Param, Result).

%% 用场景资源获取副本id
get_dungeon_id(SceneResId) ->
    F = fun(Did, P) ->
        DD = data_dungeon:get(Did),
        case lists:keyfind(SceneResId, 1, DD#dungeon.scene) of
            false -> P;
            _ -> Did
        end
    end,
    lists:foldl(F, 0, data_dungeon:get_ids()).