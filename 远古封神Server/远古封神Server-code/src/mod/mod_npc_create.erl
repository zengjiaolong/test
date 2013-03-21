%%%------------------------------------
%%% @Module  : mod_npc_create
%%% @Author  : ygzj
%%% @Created : 2010.10.06
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
	misc:write_monitor_pid(self(),?MODULE, {}),	
    State = #state{auto_id = 1},
    {ok, State}.

handle_cast({'RESET', _Id} , State) ->
    {noreply, State};

handle_cast(_R , State) ->
    {noreply, State}.

handle_call({create, [NpcId, Scene, X, Y]} , _FROM, State) ->
	NewAutoId = if State#state.auto_id > 4000000000 ->
		   				1;
	   				true -> State#state.auto_id + 1
				end,
    case data_agent:npc_get(NpcId) of
        [] ->
            ok;
        N ->
            N1 = N#ets_npc{
                id = NewAutoId,
                x = X,
                y = Y,
                scene = Scene,
				unique_key = {Scene, NewAutoId}
            },
            ets:insert(?ETS_SCENE_NPC, N1)
    end,
    NewState = State#state{auto_id = NewAutoId},
    {reply, ok, NewState};

handle_call(_R , _FROM, State) ->
    {reply, ok, State}.

%%todo:查询mid为undefined的怪物重新启动
handle_info({'EXIT', _Mid, _Reason}, State) ->
    {noreply, State};

handle_info(_Reason, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()),
    ok.

code_change(_OldVsn, State, _Extra)->
	{ok, State}.
