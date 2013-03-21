%%%------------------------------------
%%% @Module  : mod_mon_create
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.05.12
%%% @Description: 生成所有怪物进程
%%%------------------------------------
-module(mod_mon_create).
-behaviour(gen_server).
-export([start_link/0, create_mon/1, clear_scene_mon/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-include("common.hrl").
-include("record.hrl").
-record(state, {auto_id}).

%% 创建怪物
create_mon([MonId, Scene, X, Y, Type]) ->
    gen_server:call(?MODULE, {create, [MonId, Scene, X, Y, Type]}).

%% 清除场景怪物
clear_scene_mon(SceneId)->
    gen_server:call(?MODULE, {clear_scene_mon, SceneId}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).
    
init([]) ->
    process_flag(trap_exit, true),
    State = #state{auto_id = 1},
    {ok, State}.

handle_cast(_R , State) ->
    {noreply, State}.

handle_call({create, [MonId, Scene, X, Y, Type]} , _FROM, State) ->
    mod_mon_active:start([State#state.auto_id, MonId, Scene, X, Y, Type]),
    NewState = State#state{auto_id = State#state.auto_id + 1},
    {reply, ok, NewState};

%% 清除场景npc
handle_call({clear_scene_mon, SceneId}, _From, State) ->
    L = ets:match(?ETS_MON, #ets_mon{aid = '$1', scene = SceneId, _ = '_'}),
    [Aid ! clear|| [Aid] <- L, is_pid(Aid), is_process_alive(Aid)],
    {reply, true, State};

handle_call(_R , _FROM, State) ->
    {reply, ok, State}.

%%todo:查询mid为none的怪物重新启动
handle_info({'EXIT', _Mid, _Reason}, State) ->
    {noreply, State};

handle_info(_Reason, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra)->
	{ok, State}.
