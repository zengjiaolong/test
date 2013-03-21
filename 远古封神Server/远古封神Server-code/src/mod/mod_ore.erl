%%%------------------------------------
%%% @Module  : mod_ore 
%%% @Author  : zj
%%% @Created : 2011.03.3
%%% @Description: 矿点子进程
%%%------------------------------------
-module(mod_ore).

-behaviour(gen_server).
-export(
	[
	 	init/1, 
		handle_call/3, 
		handle_cast/2, 
		handle_info/2, 
		terminate/2, 
		code_change/3
	]
).
-export(
    [
   		start/1     
    ]
).
-include("common.hrl").
-include("record.hrl").
-define(ORE_POINT,5).
-record(state, {
	self = undefined,
	pname = undefined,
	scene = 0,
	x = 0,
	y = 0,
	total = 0,
	hist = [],
	player =[],
	ore = []
}).

%% 启动
%% 全局进程名称 
start(ProcessName)-> 
	case misc:whereis_name({global,ProcessName}) of
		Pid when is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true ->
					{ProcessName,0,0,0,Pid,0};
				false ->							
    				case gen_server:start_link(?MODULE, [ProcessName], []) of
						{ok,NewPid} -> 
							{ProcessName,0,0,0,NewPid,0};
						_err ->
							?DEBUG("_______________ore_child_err___1:~p",[_err]),
							{undefined,0,0,0,undefined,0}
					end
			end;
		_ ->
			case gen_server:start_link(?MODULE, [ProcessName], []) of
						{ok,NewPid} -> 
							{ProcessName,0,0,0,NewPid,0};
						_err ->
							?DEBUG("_______________ore_child_err___2:~p",[_err]),
							{undefined,0,0,0,undefined,0}
			end
	end.


init([ProcessName]) ->
	process_flag(trap_exit, true),
	Self = self(),
	misc:register(global, ProcessName, Self),
	misc:write_monitor_pid(Self, ProcessName, {}),
	misc:write_system_info(Self, ProcessName, {}),
	State = #state{
				   self = Self,
				   pname = ProcessName,
				   scene = 0,
				   x = 0,
				   y = 0,
				   total = 0,
				   hist = [],
				   player = [],
				   ore = []
				   },
	%%?DEBUG("_______________ORE:~p",[Ore]),
    {ok, State}.	


%% 统一模块+过程调用(call)
handle_call({apply_call, Module, Method, Args}, _From, State) ->
%%   	?DEBUG("*****  mod_arena_supervisor apply_call: [~p,~p]   *****", [Module, Method]),	
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_ore apply_call error: Module=~p, Method=~p, Reason=~p, Args = ~p",[Module, Method, Info, Args]),
			 error;
		 DataRet -> 
			 DataRet
	end,
    {reply, Reply, State};

handle_call(_Request, _From, State) ->
    {reply, State, State}.

%%挖矿
handle_cast({'ore_dig',Player_id,Nickname,Pidsend,Pid_goods},State) ->
	NewState = ore_dig({Player_id,Nickname,Pidsend,Pid_goods},State),
	{noreply,NewState};
	

%%刷新矿点
handle_cast({'refresh_ore_child',Display,Ore,Scene,X,Y},State) ->
	%%通知玩家改变状态
	case length(State#state.player) > 0 of
		true ->
			{ok,BinData} = pt_36:write(36003,[State#state.player]),
			mod_scene_agent:send_to_area_scene(State#state.scene,State#state.x,State#state.y,BinData);
		false ->
			skip
	end,
	NewState =State#state{
				   scene = Scene,
				   x = X,
				   y = Y,
				   total = 0,
				   hist =[],
				   player = [],
				   ore = Ore
				   },
	OreId = lib_ore:make_ore_id(Scene,X,Y),
	if
		Display == true ->
			%%重新刷出来
			{ok,BinD} = pt_12:write(12200,[OreId,X,Y]),
			mod_scene_agent:send_to_scene(Scene,BinD);
		true ->
			skip
	end,
	{noreply,NewState};

%%同步玩家列表
handle_cast({'out_ore_dig',Player_id},State) ->
	Player = State#state.player,
	NewPlayer = lists:delete(Player_id,Player),
	NewState = State#state{player = NewPlayer},
	{noreply,NewState};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(Reason, State) ->
	misc:delete_monitor_pid(self()),
	misc:delete_system_info(self()),	
?WARNING_MSG("mod_ore_terminate: Reason ~p~n State ~p~n", [Reason, State]),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% 挖矿函数
ore_dig({Player_id,Nickname,Pidsend,Pid_goods},State) ->
	Ore=State#state.ore,
	Num =length(Ore),
	{_Ret,NewState}=
	if
		%%第一组矿石
		Num > 0  ->
			R = util:rand(1,Num),
			{Goods_id,_N,W} = lists:nth(R, Ore),
			NewOre = lists:keydelete(Goods_id, 1, Ore),
			Hist = [{Goods_id,_N,W}|State#state.hist],
			Total = State#state.total +1,
			%%玩家挖矿列表
			F = fun(P) ->
						P == Player_id
				end,
			Exists = lists:any(F, State#state.player),
			if 
				Exists ->
					gen_server:cast(Pid_goods,{'give_ore_goods', Goods_id, 1 ,Nickname, Pidsend}),
					State1 = State;
				true ->
					Player = [Player_id|State#state.player],
					State1 =State#state{player = Player}
			end,
			{ok,State1#state{ore = NewOre,hist=Hist,total = Total}};
		true ->
			{ok,BinData} = pt_36:write(36002,[2,1]),
			lib_send:send_to_sid(Pidsend, BinData),
			%%挖空通知
			empty_notice(State),
			{err,State}
	end,
	NewState.

%%%
%%挖空矿点消失并通知父进程
empty_notice(State) ->
	case mod_ore_sup:get_mod_ore_pid() of
		Pid when is_pid(Pid) ->
			ProcessName = State#state.pname,
			gen_server:cast(Pid,{'empty_notice',ProcessName});
		_ ->
			skip
	end,
	%%通知场景矿点消失
	OreId = lib_ore:make_ore_id(State#state.scene,State#state.x,State#state.y),
	{ok,BinData} = pt_12:write(12201,[OreId]),
	mod_scene_agent:send_to_scene(State#state.scene,BinData),
	%%通知玩家改变状态
	case length(State#state.player) > 0 of
		true ->
			{ok,BinData2} = pt_36:write(36003,[State#state.player]),
			mod_scene_agent:send_to_area_scene(State#state.scene,State#state.x,State#state.y,BinData2);
		false ->
			skip
	end.


