%%%------------------------------------
%%% @Module  : mod_npc_create
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.07.02
%%% @Description: 生成NPC
%%%------------------------------------
-module(mod_npc_create).
-behaviour(gen_server).
-export([start_link/0, create_npc/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-include("common.hrl").
-include("record.hrl").
-record(state, {auto_id}).

%% 创建NPC
create_npc([NpcId, Scene, X, Y]) ->
    gen_server:call(?MODULE, {create, [NpcId, Scene, X, Y]}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).
    
init([]) ->
    process_flag(trap_exit, true),
    State = #state{auto_id = 1},
    {ok, State}.

handle_cast({'RESET', _Id} , State) ->
    {noreply, State};

handle_cast(_R , State) ->
    {noreply, State}.

handle_call({create, [NpcId, Scene, X, Y]} , _FROM, State) ->
    case data_npc:get(NpcId) of
        [] ->
            ok;
        N ->
            N1 = N#ets_npc{
                id = State#state.auto_id,
                x = X,
                y = Y,
                scene = Scene
            },
            ets:insert(?ETS_NPC, N1)
    end,
    NewState = State#state{auto_id = State#state.auto_id + 1},
    {reply, ok, NewState};

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
