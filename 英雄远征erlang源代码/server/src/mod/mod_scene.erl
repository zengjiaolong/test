%%%------------------------------------
%%% @Module  : mod_scene
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.05.13
%%% @Description: 场景管理
%%%------------------------------------
-module(mod_scene).
-behaviour(gen_server).
-export([start_link/0, copy_scene/2, clear_scene/1, get_scene_auto_id/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include("common.hrl").
-include("record.hrl").

-record(state, {auto_sid, auto_eid}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

get_scene_auto_id() ->
    gen_server:call(?MODULE, scene_auto_id).

%% 复制一个副本场景
copy_scene(Id, SceneId) ->
    case data_scene:get(SceneId) of
        [] ->
            ok;
        S ->
            load_npc(S#ets_scene.npc, Id),
            load_mon(S#ets_scene.mon, Id),
            ets:insert(?ETS_SCENE, S#ets_scene{id = Id, mon=[], npc=[], mask=[]}),
%            %% 为了效率暂时不做位置检查
%            case data_mask:get(SceneId) of
%                "" -> ?ERR("场景的坐标MASK为空:~w", [SceneId]);
%                Mask1 -> load_mask(Mask1, 0, 0, SceneId)
%            end
            ok
    end.

%% 清除场景
clear_scene(Id) ->
    mod_mon_create:clear_scene_mon(Id),    %% 清除怪物
    ets:match_delete(?ETS_NPC, #ets_npc{scene=Id, _ = '_'}),%% 清除npc
    ets:delete(?ETS_SCENE, Id).         %% 清除场景
    %没有mask所以就不清除了

init([]) ->
    process_flag(trap_exit, true),
    lists:map(fun load_scene/1, data_scene:get_id_list()),
    State = #state{auto_sid = 1000000, auto_eid = 1},
    {ok, State}.

%% 申请一个唯一id
handle_call(scene_auto_id, _From, State) ->
    {reply, State#state.auto_sid, State#state{auto_sid = State#state.auto_sid + 1}};

handle_call(_Request, _From, State) ->
    {reply, State, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% 场景初始化
load_scene(SceneId) ->
    S = data_scene:get(SceneId),
    case S#ets_scene.type =:= 2 orelse S#ets_scene.type =:= 3 of
        true -> %% 副本、帮会的原始场景，就不加载
            ok;
        false ->
            load_npc(S#ets_scene.npc, SceneId),
            load_mon(S#ets_scene.mon, SceneId),
            ets:insert(?ETS_SCENE, S#ets_scene{id = SceneId, mon=[], npc=[], mask=[]}),
            case data_mask:get(SceneId) of
                "" -> ?ERR("场景的坐标MASK为空:~w", [SceneId]);
                Mask1 -> load_mask(Mask1, 0, 0, SceneId)
            end
    end.

%% 加载NPC
load_npc([], _) ->
    ok;
load_npc([[NpcId, X, Y] | T], SceneId) ->
    mod_npc_create:create_npc([NpcId, SceneId, X, Y]),
    load_npc(T, SceneId).

%% 加载NPC
load_mon([], _) ->
    ok;
load_mon([[MonId, X, Y, Type] | T], SceneId) ->
    mod_mon_create:create_mon([MonId, SceneId, X, Y, Type]),
    load_mon(T, SceneId).


%% 从地图的mask中构建ETS坐标表，表中存放的是可移动的坐标
%% load_mask(Mask,0,0)，参数1表示地图的mask列表，参数2和3为当前产生的X,Y坐标
load_mask([], _, _, _) ->
    null;
load_mask([H|T], X, Y, SceneId) ->
    case H of
        10 -> % 等于\n
            load_mask(T, 0, Y+1, SceneId);
        13 -> % 等于\r
            load_mask(T, X, Y, SceneId);
        48 -> % 0
            load_mask(T, X+1, Y, SceneId);
        49 -> % 1
            ets:insert(?ETS_SCENE_POSES, {{SceneId, X, Y}}),
            load_mask(T, X+1, Y, SceneId);
        50 -> % 2
            load_mask(T, X+1, Y, SceneId);
        Other ->
            ?ERR("场景Mask里面含有未知元素: ~w", [Other])
    end.
