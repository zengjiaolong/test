%%%------------------------------------
%%% @Module  : mod_ore 
%%% @Author  :	zj 
%%% @Created : 2011.03.3
%%% @Description: 挖矿主进程
%%%------------------------------------
-module(mod_ore_sup).

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
   		start_link/1,
	 	get_mod_ore_pid/0      
    ]
).
-include("common.hrl").
-include("record.hrl").

-define(ORE_TIMER_TIME,5000).
%%num 矿点数 num_lim 矿点最大数  limit矿点出矿限制 begtime开始时间 endtime结束时间
-record(ore_config,{num= 0,num_limit=0,limit = 0,begtime=0,endtime=0,scene=[]}).
-record(state, {
	num = 0,
	num_limit = 0,
	limit = 0,
	begtime = 0,
	endtime = 0,
	child = [],%%子矿点信息{ProcessName,Scene,X,Y,Pid,Valide};
	self = undefined ,
	sceneHis = [],
	scene =[],
	g1 =[],
	g2 =[]
}).
%% 启动
start_link([ProcessName]) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [ProcessName], []).

init([ProcessName]) ->
	process_flag(trap_exit, true),
	Self = self(),
	case misc:register(unique, ProcessName, Self) of
		yes ->
			misc:write_monitor_pid(Self, mod_ore, {}),
			misc:write_system_info(Self, mod_ore, {}),
	
			%%获取配置
			OreConfig = #ore_config{ num = ?ORE_NUM, 
							 num_limit = ?ORE_NUM_LIMIT, 
							 limit = ?ORE_GOODS_LIMIT, 
							 begtime = ?ORE_START_TIME, 
							 endtime = ?ORE_END_TIME,
							 scene =  lib_ore:get_ore_scene() 
						   },
%% 	OreConfig = #ore_config{
%% 							num=3,
%% 							num_limit = 5,
%% 							limit=3,
%% 							begtime = 22 * 3600 + 45 * 60,
%% 							endtime = 22 * 3600 + 45 * 60 + 30 * 60,
%% 							scene = [{100,23,18},{100,32,15},{100,39,21},{100,38,34},{100,28,33},{100,30,24}]
%% 							%%scene = lib_ore:get_ore_scene() 
%% 						   },
	
			OreSpecs = init_ore_point(OreConfig),
%%	[G1,G2,_] = get_goods_storing([],[],OreConfig#ore_config.limit),
			State = #state{
				   num = OreConfig#ore_config.num,
				   num_limit = OreConfig#ore_config.num_limit,
				   limit = OreConfig#ore_config.limit,
				   begtime = OreConfig#ore_config.begtime,
				   endtime = OreConfig#ore_config.endtime,
				   child=OreSpecs,
				   self = Self,
				   sceneHis = [],
				   g1 = [],
				   g2 = [],
				   scene = OreConfig#ore_config.scene
				  },
			erlang:send_after(?ORE_TIMER_TIME, Self, {'mod_ore_timer',Self}),
			io:format("5.Init mod_ore_sup finish!!!~n"),
    		{ok, State};
		_ ->
			{stop,normal,#state{}}
	end.

%%启动子矿点进程
init_ore_point(OreConfig) ->
	Scene = OreConfig#ore_config.scene,
	SceneNum = length(Scene),
	if
		SceneNum >= OreConfig#ore_config.num ->
			F = fun(N,_oreConfis) ->
						_ProcName = list_to_atom(lists:concat([ore,N])),
						[_ProcName|_oreConfis]
				end,
			OreConfis = lists:foldl(F,[],lists:seq(1, OreConfig#ore_config.num)),
			[mod_ore:start(_Oc)||_Oc <-OreConfis];
		true ->
			[]
	end.

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

%%请求路由
handle_cast({'routing',Player_id,Nickname,Pidsend,Pid_goods,Scene,X,Y,S},State) ->
	IsOreTime = is_ore_time(State),
%%	?DEBUG("____________routing___________is_ore_time:~p",[IsOreTime]),
	if
		IsOreTime >  0 ->
			case routing({Scene,X,Y},State) of
				Pid when is_pid(Pid) ->
					gen_server:cast(Pid,{'ore_dig',Player_id,Nickname,Pidsend,Pid_goods}),
					ok;
				_Err ->
					{ok,BinData} = pt_36:write(36002,[0,S]),
					lib_send:send_to_sid(Pidsend, BinData),
					%%位置不正确或矿点已消失
					skip
			end;
		true ->
			skip
	end,
	{noreply,State};

%%子矿挖空通知,改变状态不再路由到此矿点进程
handle_cast({'empty_notice',ProcessName},State) ->
	Child = State#state.child,
	case lists:keyfind(ProcessName, 1, Child) of
		{ProcessName,Scene,X,Y,Pid,_Valide} ->
			NewChild=lists:keyreplace(ProcessName, 1, Child, {ProcessName,Scene,X,Y,Pid,0}),
			NewState=State#state{child=NewChild};
		false ->
			NewState = State
	end,
	{noreply,NewState};

%%获取挖矿时间
handle_cast({'ore_running_time',Pidsend},State) ->
	LeftTime = is_ore_time(State),
	if 
		LeftTime > 0 ->
			SceneName = get(ore_scene_name),
		   	S = 1;
	   	true ->
			SceneName = [],
		   S = 0
	end,
	{ok,BinData} = pt_36:write(36000,[S,LeftTime,SceneName]),
	lib_send:send_to_sid(Pidsend, BinData),	
	{noreply,State};
%%
%%进入场景广播给自己
handle_cast({'enter_scene_ore_display',ToScene,Pidsend},State) ->
	enter_scene_ore_display(State,ToScene,Pidsend),
	{noreply,State};

%% 退出挖矿状态广播
handle_cast({'out_ore_dig',Player_id},State) ->
	broadcast_out_ore_dig(Player_id,State),
	{noreply,State};

%% 玩家退出游戏处理
handle_cast({'do_logout_clean',Player_id},State) ->
	broadcast_out_ore_dig(Player_id,State),
	{noreply,State};

%% 测试
handle_cast({'test',Min},State) ->
	NowSec = util:get_today_current_second(),
	M = tool:to_integer(Min),
	Begtime = NowSec +  M * 60 ,
	Endtime = NowSec - M * 60 + 1800,
	State2=State#state{begtime =Begtime,endtime =Endtime},
	State3 = refresh_ore_child(State2,false),
	lib_ore:cancel_timer(),
	{noreply,State3};
%% 测试 结束
handle_cast({'test_over'},State) ->
	State#state.self ! {'ore_stop'} ,
	lib_ore:cancel_timer(),
	{noreply, State};

%% 测试1分钟后结束
handle_cast({'test_over_1'},State) ->
	NowSec = util:get_today_current_second(),
	if
		NowSec > 1740 ->
			Begtime = NowSec  - 1740 ,
			Endtime = NowSec  + 60 ;
		true ->
			Begtime = NowSec,
			Endtime = NowSec + 1800
	end,
	State2 = refresh_ore_child(State,true),
	State3=State2#state{begtime =Begtime,endtime =Endtime},
	{ok,BinData} = pt_36:write(36000,[1,60,"测试"]),
	mod_disperse:broadcast_to_world(ets:tab2list(?ETS_SERVER), BinData),
	lib_ore:cancel_timer(),
	{noreply,State3};

handle_cast(_Msg, State) ->
    {noreply, State}.


%%处理子矿点进程异常终止{'EXIT', _Reason}
handle_info({'EXIT',_Pid,_why},State) ->
	?DEBUG("_get_exit_________________1",[]),
	{noreply,State};

handle_info({'EXIT',_},State) ->
	?DEBUG("_get_exit_________________2",[]),
	{noreply,State};

%%定时器
handle_info({'mod_ore_timer',Self},State) ->
	timer_alert(State),
	erlang:send_after(?ORE_TIMER_TIME,Self,{'mod_ore_timer',Self}),
	{noreply,State};

%%挖矿通知广播
handle_info({'broadcast_ore_beg',Time},State) ->
	broadcast_ore_beg(Time),
	{noreply,State};

%%刷新矿点通知
handle_info({'refresh_ore_notice',LT},State) ->
	broadcast_hide(State),
	NewState = refresh_ore_child(State,true),
	SceneName = get(ore_scene_name),
	LeftTime = LT * 60,
	{ok,BinData} = pt_36:write(36000,[1,LeftTime,SceneName]),
	mod_disperse:broadcast_to_world(ets:tab2list(?ETS_SERVER), BinData),
	lib_send:send_to_local_all(BinData),
	{noreply,NewState};

%%挖矿开始全服广播
handle_info({'ore_start'},State) ->
	%%初始化采石上限
	Limit = lib_ore:get_limit(),
	%%初始化物品
	[G1,G2,_] = get_goods_storing([],[],Limit),
	State2 =State#state{limit = Limit,g1=G1,g2=G2},	
	NewState = refresh_ore_child(State2,true),
	%%计时
	SceneName = get(ore_scene_name),
	{ok,BinData} = pt_36:write(36000,[1,1800,SceneName]),
	mod_disperse:broadcast_to_world(ets:tab2list(?ETS_SERVER), BinData),
	lib_send:send_to_local_all(BinData),
	%%传闻
	lib_ore:broadcast_msg(2,0),
	%%矿点出现
	%%broadcast_view(State),
	{noreply,NewState};

%%挖矿结束全服广播
handle_info({'ore_stop'},State) ->
	%%计时器
	SceneName = get(ore_scene_name),
	{ok,BinData} = pt_36:write(36000,[0,0,SceneName]),
	mod_disperse:broadcast_to_world(ets:tab2list(?ETS_SERVER), BinData),
	lib_send:send_to_local_all(BinData),
	%%传闻
	lib_ore:broadcast_msg(4,0),
	%%矿点消失
	broadcast_hide(State),
	%%刷新矿点进程信息
	State1 =refresh_ore_child(State,false),
	NewState = State1#state{sceneHis = [],g1 =[],g2=[]},
	{noreply,NewState};
	
handle_info(_Info, State) ->
    {noreply, State}.

terminate(Reason, State) ->
	misc:delete_monitor_pid(self()),
	misc:delete_system_info(self()),	
?WARNING_MSG("ORE_Main_Process_terminate: Reason ~p~n State ~p~n", [Reason, State]),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% 获取采矿进程
get_mod_ore_pid() ->
	ProcessName = mod_ore_sup,
	case misc:whereis_name({global, ProcessName}) of
		Pid when is_pid(Pid) ->
			case misc:is_process_alive(Pid) of
				true -> 
					Pid;
				false ->
					start_mod_ore_sup(ProcessName)
			end;
		_ ->
			start_mod_ore_sup(ProcessName)			
	end.

%% 开启采矿进程
start_mod_ore_sup(ProcessName) ->
	global:set_lock({ProcessName, undefined}),
	ProcessPid = 
		case misc:whereis_name({global, ProcessName}) of
			Pid when is_pid(Pid) ->
				case misc:is_process_alive(Pid) of
					true ->	
						Pid;		
					false ->
						start_ore_sup(ProcessName)
				end;
			_ ->
				start_ore_sup(ProcessName)
		end,
	global:del_lock({ProcessName, undefined}),
	ProcessPid.

start_ore_sup(ProcessName) ->
	ChildSpec = {
		mod_ore_sup,
      	{
			mod_ore_sup, 
			start_link,
			[[ProcessName]]
		},
   		permanent, 
		brutal_kill,
		worker, 
		[mod_ore_sup]
	},
	case supervisor:start_child(yg_server_sup, ChildSpec) of
		{ok, Pid} ->
			Pid;
		Error->
			?DEBUG("___________mod_ore_start_pid_error:~p",[Error]),
			undefined
	end.


%%%%%% functions %%%%%%%%%%%%%

%%-----------------------------------------
%%子矿点路由
routing({Scene,X,Y},State) ->
	ChildSpec = State#state.child,
	get_child(ChildSpec,[Scene,X,Y]).

get_child([],[_Scene,_X,_Y]) ->
	invalid;
get_child([{_Pname,Pscene,PX,PY,Pid,Valide}|R_child],[Scene,X,Y]) ->
	if
		Scene == Pscene andalso abs(PX-X) =< ?ORE_AREA andalso abs(PY-Y) =< ?ORE_AREA andalso Valide == 1 ->
			Pid;
		true ->
			get_child(R_child,[Scene,X,Y])
	end.

%%刷新矿点 State 状态 Display 是否出现
refresh_ore_child(State,Display) ->
	SceneList = State#state.scene,
	SceneHis = State#state.sceneHis,
	Child = State#state.child,
	Limit = State#state.limit,
	[NewSceneHis,_SceneID] = get_ore_scene_id(SceneHis,SceneList),
	if
		_SceneID == 0 ->
			{SceneID,_,_} = hd(SceneList);
		true ->
			SceneID = _SceneID
	end,
	SceneName = lib_ore:get_scene_name(SceneID),
	put(ore_scene_name,SceneName),
	if
		Display == true ->
			spawn(fun()-> lib_ore:broadcast_msg(6,[SceneID])end);
		true ->
			skip
	end,
	F = fun({_ProcessName,_Scene,_X,_Y,_Pid,_Valide},[_Copy,_g1,_g2,_Child]) ->
				[_NCopy,{_NewScene,_NewX,_NewY}]= get_ore_scene_rand(SceneID,_Copy),
				[_Ng1,_Ng2,_goods] = get_goods_storing(_g1,_g2,Limit),
				%%通知子矿点更新信息
				gen_server:cast(_Pid,{'refresh_ore_child',Display,_goods,_NewScene,_NewX,_NewY}),
				_Cspec ={_ProcessName,_NewScene,_NewX,_NewY,_Pid,1},
				[_NCopy,_Ng1,_Ng2,[_Cspec|_Child]]
		end,
	G1 = State#state.g1,
	G2 = State#state.g2,
	[_,Ng1,Ng2,NewChild] = lists:foldl(F, [SceneList,G1,G2,[]], Child),
	NewState=State#state{sceneHis = NewSceneHis,child = NewChild,g1=Ng1,g2=Ng2},
	NewState.

%%--------------广播----------------------------

%%倒计时广播
broadcast_ore_beg(Time) ->
	lib_ore:broadcast_msg(1,Time),
	ok.

%% %%广播场景出现
%% broadcast_view(State) ->
%% 	Child = State#state.child,
%% 	{_,SceneId,_,_,_,_} = hd(Child),
%% 	spawn(fun()-> lib_ore:broadcast_msg(6,[SceneId])end),
%% 	F = fun({_ProcessName,_Scene,_X,_Y,_Pid,_Valide}) ->
%% 				%%只对没有采完的广播
%% 				if 
%% 					_Valide == 1 ->
%% 						OreId = lib_ore:make_ore_id(_Scene,_X,_Y),
%% 						{ok,_BinD} = pt_12:write(12200,[OreId,_X,_Y]),
%% 						mod_scene_agent:send_to_scene(_Scene,_BinD);							
%% 				   	true ->
%% 					   	skip
%% 				end
%% 		end,
%% 	lists:foreach(F, Child).

%%广播场景消失
broadcast_hide(State) ->
	Child = State#state.child,
	F = fun({_ProcessName,_Scene,_X,_Y,_Pid,_Valide}) ->
				%%只对没有采完的广播
				if 
					_Valide == 1 ->
						OreId = lib_ore:make_ore_id(_Scene,_X,_Y),
						{ok,_BinD} = pt_12:write(12201,[OreId]),
						mod_scene_agent:send_to_scene(_Scene,_BinD);							
				   	true ->
					   	skip
				end
		end,
	lists:foreach(F, Child).

%%广播进入当前场景
enter_scene_ore_display(State,ToScene,Pidsend) ->
	OreTime = is_ore_time(State),
	if
		OreTime >  0 ->
			Child = State#state.child,
			broadcast_scene_ore(Child,ToScene,Pidsend);
		true ->
			skip
	end.

broadcast_scene_ore([],_ToScene,_Pidsend) ->
	ok;
broadcast_scene_ore([{_ProcessName,_Scene,_X,_Y,_Pid,_Valide}|Lchild],ToScene,Pidsend) ->
	if
		_Valide == 1 andalso _Scene == ToScene ->
			OreId = lib_ore:make_ore_id(_Scene,_X,_Y),
			{ok,BinD} = pt_12:write(12200,[OreId,_X,_Y]),
			lib_send:send_to_sid(Pidsend,BinD);
		true ->
			skip
	end,
	broadcast_scene_ore(Lchild,ToScene,Pidsend).

%%广播子矿点玩家退出挖矿状态，同步维护列表
broadcast_out_ore_dig(Player_id,State) ->
	Child = State#state.child,
	F = fun({_ProcessName,_Scene,_X,_Y,_Pid,_Valide}) ->
				gen_server:cast(_Pid,{'out_ore_dig',Player_id})
		end,
	lists:foreach(F, Child).

%%辅助函数%%

%%随机取出一个没有出现过的场景id
get_ore_scene_id(SceneHis,[]) ->
	[SceneHis,0];

get_ore_scene_id(SceneHis,Scene) ->
	L = length(Scene),
	R = util:rand(1,L),
	{S,_X,_Y} = lists:nth(R, Scene),
	F = fun(E) ->
		S == E
	end,
	Exists = lists:any(F, SceneHis),
	if
		Exists ->
			NewScene = lists:delete({S,_X,_Y}, Scene),
			get_ore_scene_id(SceneHis,NewScene);
		true ->
			NewSceneHis = [S|SceneHis],
			[NewSceneHis,S]
	end.

%%随机取出相同场景的坐标
get_ore_scene_rand(_SceneID,[])->
	[[],{0,0,0}];
get_ore_scene_rand(SceneID,Scene)->
	L = length(Scene),
	R = util:rand(1,L),
	{S,_X,_Y} = lists:nth(R, Scene),
	if
		S == SceneID ->
			NewScene = lists:delete({S,_X,_Y}, Scene),
			[NewScene,{S,_X,_Y}];
		true ->
			get_ore_scene_rand(SceneID,Scene)
	end.

%%物品分组处理
goods_storing(BaseGoodsOre) ->
	case length(BaseGoodsOre)> 0 of
		true ->
				F = fun(_G,[_G1,_G2]) ->
							_goods_id=_G#ets_base_goods_ore.goods_id,
							_n1 = _G#ets_base_goods_ore.n1,
							_n2 = _G#ets_base_goods_ore.n2,
							_w = _G#ets_base_goods_ore.w,
							[[{_goods_id,_n1,_w}|_G1],[{_goods_id,_n2,_w}|_G2]]
					end,
				[G1,G2]=lists:foldl(F, [[],[]], BaseGoodsOre),
				NewG1 = goods_storing_flatten(G1,[]),
				NewG2 = goods_storing_flatten(G2,[]),
				[NewG1,NewG2];
		false ->
			[[],[]]
	end.

goods_storing_flatten([],NewList) ->
	NewList;

goods_storing_flatten([{Goods_id,N,W}|L],NewList) ->
	F = fun(_)->
			{Goods_id,1,W}
		end,
	OneList= lists:map(F, lists:seq(1, N)),
	goods_storing_flatten(L,OneList++NewList).

%%获取Limit个数组物品
get_goods_storing([],_g2,Limit) ->
	BaseOreList = ets:tab2list(ets_base_goods_ore),
	[G1,G2]=goods_storing(BaseOreList),
	get_goods_storing(G1,G2,Limit);

get_goods_storing(G1,G2,Limit) ->
	Len1 = length(G1),
	if
		Len1 > Limit ->
			[NG1,Goods] = get_goods_random(G1, Limit),
			[NG1,G2,Goods];
		Len1 == Limit ->
			Goods = G1,
			NG1 = [],
			[G2,NG1,Goods];
		true ->
			get_goods_storing(G2,[],Limit)
	end.

%%随机取出	[NewGoods,GetList]		
get_goods_random(Goods,Num) ->
	F = fun(_,[_Goods,_List]) ->
			L = length(_Goods),
			R = util:rand(1,L),
			G = lists:nth(R, _Goods),
			NewGoods = lists:delete(G, _Goods),
			[NewGoods,[G|_List]]
		end,
	lists:foldl(F, [Goods,[]], lists:duplicate(Num,1)).
	
	
		
%% 是否挖矿时间 返回剩余时间
is_ore_time(State) ->
	NowSec = util:get_today_current_second(),
	if
		NowSec >= State#state.begtime andalso NowSec =< State#state.endtime ->
			State#state.endtime - NowSec;
		true ->
			0
	end.

%% 定时器提醒NowSce = util:get_today_current_second(),
timer_alert(State) ->
	NowSec = util:get_today_current_second(),
	BegTime = State#state.begtime,
	EndTime = State#state.endtime,
	Self = State#state.self,
	if
		NowSec > BegTime -720 andalso NowSec =< BegTime - 600 ->
			Diff_10 = BegTime - 600  - NowSec,
			%%?DEBUG("____________________________1",[]),
			case get(diff_10) of
				undefined -> 
					Timer_diff_10 = erlang:send_after(Diff_10 * 1000 ,Self ,{'broadcast_ore_beg',10}),
					put(diff_10,Timer_diff_10);
				_ ->skip
			end;
		NowSec > BegTime -600 andalso NowSec =< BegTime - 300 ->
			%%?DEBUG("____________________________2",[]),
			Diff_5 = BegTime - 300 - NowSec,
			case get(diff_5) of
				undefined -> 
					Timer_diff_5 = erlang:send_after(Diff_5 * 1000 ,Self ,{'broadcast_ore_beg',5}),
					put(diff_5,Timer_diff_5);
				_ ->skip
			end;
		NowSec > BegTime -300 andalso NowSec =< BegTime - 180 ->
			%%?DEBUG("____________________________3",[]),
			Diff_3 = BegTime - 180 - NowSec,
			case get(diff_3) of
				undefined -> 
					Timer_diff_3 = erlang:send_after(Diff_3 * 1000 ,Self ,{'broadcast_ore_beg',3}),
					put(diff_3,Timer_diff_3);
				_ ->skip
			end;
		NowSec > BegTime - 180 andalso NowSec =< BegTime ->
			%%?DEBUG("____________________________4",[]),
			Diff_beg = BegTime -NowSec,
			case get(diff_beg) of
				undefined -> 
					Timer_diff_beg = erlang:send_after(Diff_beg * 1000 ,Self ,{'ore_start'}),
					put(diff_beg,Timer_diff_beg);
				_ ->skip
			end;
		NowSec > BegTime andalso NowSec =< BegTime + 600 ->
			%%?DEBUG("____________________________5:~p",[EndTime - NowSec]),
			Diff_re_10 = BegTime + 600 - NowSec,
			case get(diff_re_10) of
				undefined ->
					Timer_diff_re_10 = erlang:send_after(Diff_re_10 * 1000,Self ,{'refresh_ore_notice',20}),
					put(diff_re_10,Timer_diff_re_10);
				_ ->skip
			end;
		NowSec > BegTime + 600 andalso NowSec =< BegTime + 1200 ->
			%%?DEBUG("____________________________6:~p",[EndTime - NowSec]),
			Diff_re_20 = BegTime + 1200 - NowSec,
			case get(diff_re_20) of
				undefined ->
					Timer_diff_re_20 = erlang:send_after(Diff_re_20 * 1000,Self ,{'refresh_ore_notice',10}),
					put(diff_re_20,Timer_diff_re_20);
				_ ->skip
			end;
		NowSec > BegTime + 1200 andalso NowSec =< EndTime ->
			%%?DEBUG("____________________________7:~p",[EndTime - NowSec]),
			Diff_end = EndTime - NowSec,
			case get(diff_end) of
				undefined ->
					Timer_diff_end = erlang:send_after(Diff_end * 1000,Self ,{'ore_stop'}),
					put(diff_end,Timer_diff_end);
				_ ->skip
			end;
		true ->
			%%?DEBUG("____________________________888",[]),
			put(diff_10,undefined),
			put(diff_5,undefined),
			put(diff_3,undefined),
			put(diff_beg,undefined),
			put(diff_re_10,undefined),
			put(diff_re_20,undefined),
			put(diff_end,undefined)	
	end.
			 
			
%%------------------------------------------