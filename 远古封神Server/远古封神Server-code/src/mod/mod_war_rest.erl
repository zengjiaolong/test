%% Author: Administrator
%% Created: 2011-8-31
%% Description: TODO: 封神大会等待区
-module(mod_war_rest).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").

%%
%% Exported Functions
%%
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-export([start/1,stop/0]).

-record(state, {
				scene_mark = 0, %%场景id
				lv = 0,			%%级别
				member = [],	%%玩家列表
				state = 0		%%状态
			   }).

%%
%% Local Functions
%%

start([Lv,SceneId]) ->
    gen_server:start(?MODULE, [Lv,SceneId], []).

%%停止服务
stop() ->
    gen_server:call(?MODULE, stop).

init([Lv,SceneId]) ->
    process_flag(trap_exit, true),
	Self = self(),
	SceneProcessName = misc:create_process_name(scene_p, [SceneId, 0]),
	misc:register(global, SceneProcessName, Self),
	%% 复制场景
    lib_scene:copy_scene(SceneId, 760),
	misc:write_monitor_pid(Self, ?MODULE, {760}),
	erlang:send_after(3*3600*1000,Self,{'CLOSE'}),
	State = #state{scene_mark=SceneId,lv=Lv},
    {ok,State}.

%% 统一模块+过程调用(call)
handle_call({apply_call, Module, Method, Args}, _From, State) ->
%% 	?DEBUG("mod_scene_apply_call: [~p/~p/~p]", [Module, Method, Args]),	
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_war_rest_apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
			 error;
		 DataRet -> DataRet
	end,
    {reply, Reply, State};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

%% 统一模块+过程调用(cast)
handle_cast({apply_cast, Module, Method, Args}, State) ->
%% 	?DEBUG("mod_scene_apply_cast: [~p/~p/~p]", [Module, Method, Args]),	
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_war_rest_apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
			 error;
		 _ -> ok
	end,
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

handle_cast({'CLOSE'},State)->
	{stop, normal, State};

handle_cast(_MSg,State)->
	 {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, State) ->
	misc:delete_monitor_pid(self()),
	spawn(fun()-> lib_scene:clear_scene(State#state.scene_mark) end),
	ok.

code_change(_OldVsn, State, _Extra)->
    {ok, State}.