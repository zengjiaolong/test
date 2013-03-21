%%%-----------------------------------
%%% @Module  : mod_single_dungeon
%%% @Author  : hzj
%%% @Created : 2011.3.23
%%% @Description: 单人副本 副本精简版，与副本函数间有联系。
%%%-----------------------------------
-module(mod_single_dungeon).
-behaviour(gen_server).

%% Include files
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

%% External exports
-compile([export_all]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {
	single_dungeon_scene_id = 0,			%% 副本唯一id
	scene_id = 0,							%% 场景原始id
	player_pid = undefined,					%% 玩家进程id
	player_id = 0,							%% 玩家id
	realm = 0,								%% 玩家阵营
	career = 0,								%% 玩家职业
	boss_number = 0,						%% 本副本内BOSS个数
	drop_id = 1
}).

%%-record(dungeon_role,  {id, pid}).
%%-record(single_dungeon_scene, {id, did, sid, enable=true, tip = <<>>}).

%% 定时器1间隔时间(定时检查角色进程, 如果不在线，则关闭此进程)
-define(TIMER_1, 1*60*1000).

%% ----------------------- 对外接口 ---------------------------------
%% 进入副本

%% 创建副本进程，由lib_xx 调用  返回{ok,player}
%% sceneid = 909 单人副本
enter_single_dungeon_scene(Player) ->
	if
		Player#player.other#player_other.pid_team == undefined ->
			RoleInfo = {Player#player.id,Player#player.other#player_other.pid,Player#player.other#player_other.pid_dungeon,Player#player.realm},
			{_player_id, _Player_Pid,Pid_dungeon,_Realm} = RoleInfo,
			case lib_scene:get_scene_id_from_scene_unique_id(Player#player.scene) == ?DUNGEON_SINGLE_SCENE_ID of
				true -> InDungeon = true;
				_ -> InDungeon = false
			end,
			FinishTask = lib_task:check_task_is_finish(Player,20361),
			%%检查是否已经在单人副本
			if
				%%任务已经提交
				FinishTask == had_finish andalso InDungeon==true->
					Ret = FinishTask;
				%%第一次进入且没有完成任务
				InDungeon == false andalso FinishTask == false ->
					%%赠送神器
					Ret = ok;
%% 					Ret = gen_server:call(Player#player.other#player_other.pid_goods,{'GIVE_TASK_WEAPON',Player#player.career});
				true ->
					Ret = inDungeon
			end,
			if
				Ret == ok orelse Ret == inDungeon ->
					%%清除已存在的副本进程
					case misc:is_process_alive(Pid_dungeon) of
						true ->
							Pid_dungeon ! role_clear ;
						_ ->
							skip
					end,
					%%先创建副本进程
					UniqueId = create_single_dungeon_scene_resources(?DUNGEON_SINGLE_SCENE_ID,FinishTask),
    				{ok, New_pid_dungeon} = gen_server:start(?MODULE, [RoleInfo,?DUNGEON_SINGLE_SCENE_ID,UniqueId], []),
					if
						%%不在副本里且赠送成功
						is_pid(New_pid_dungeon) andalso Ret == ok  ->
							case data_scene:get(?DUNGEON_SINGLE_SCENE_ID) of
                                [] ->
                                    Content = <<"场景不存在！">>,
                                    {ok, BinData} = pt_12:write(12005, [0, 0, 0, Content, 0, 0, 0, 0]),
                                    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
                                    {fail,Player};
                                Scene ->
                                    #ets_scene{x = X, y = Y} = Scene,
                                    {ok, BinData} = pt_12:write(12005, [UniqueId, X, Y, <<>>,?DUNGEON_SINGLE_SCENE_ID, 0, 0, 0]),
                                    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
                                    put(change_scene_xy , [X, Y]),%%做坐标记录
                                    %%告诉原场景的玩家你已经离开
                                    pp_scene:handle(12004, Player, Player#player.scene),
                                    %%更新玩家新坐标
                                    NewPlayer = Player#player{scene = UniqueId, x = X, y = Y ,other = Player#player.other#player_other{pid_dungeon =New_pid_dungeon}},	
                                    ValueList = [{scene,UniqueId},{x,X},{y,Y}],
                                    WhereList = [{id, NewPlayer#player.id}],
                                    db_agent:mm_update_player_info(ValueList, WhereList),
                                    mod_player:set_dungeon(_Player_Pid, New_pid_dungeon),
                                    %%进入副本场景卸下坐骑
                                    {ok, NewPlayer2} = lib_goods:force_off_mount(NewPlayer),
                                    {ok, NewPlayer2}
							end;
						%%已经在副本里
						is_pid(New_pid_dungeon) andalso Ret == inDungeon ->
							case data_scene:get(?DUNGEON_SINGLE_SCENE_ID) of
								[] ->
                                    Content = <<"场景不存在！">>,
                                    {ok, BinData} = pt_12:write(12005, [0, 0, 0, Content, 0, 0, 0, 0]),
                                    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
                                    {fail,Player};
                                Scene ->
                                    #ets_scene{x = X, y = Y} = Scene,
                                    NewPlayer = Player#player{scene = UniqueId, x = X, y = Y ,other = Player#player.other#player_other{pid_dungeon =New_pid_dungeon}},	
                                    ValueList = [{scene,UniqueId},{x,X},{y,Y}],
                                    WhereList = [{id, NewPlayer#player.id}],
                                    db_agent:mm_update_player_info(ValueList, WhereList),
                                    mod_player:set_dungeon(_Player_Pid, New_pid_dungeon),

                                    {ok, NewPlayer}
							end;
						true ->
							{fail,Player}
					end;
				Ret == had_finish->
					[NextSenceId, X, Y] =
						case Player#player.realm of
							1 ->%%女娲
								[200,158,208];
							2 ->%%神农
								[280,157,208];
							3 ->%%伏羲
								[250,159,203];
							_ ->
								[250,159,203]
						end,
					ValueList = [{scene,NextSenceId},{x,X},{y,Y}],
					WhereList = [{id, Player#player.id}],
					db_agent:mm_update_player_info(ValueList, WhereList),
					{ok,Player#player{scene=NextSenceId,x=X,y=Y}};
				true->
					{Ret ,Player}
			end;
		true ->
			Msg = {'QUIT_TEAM', Player#player.id, Player#player.scene, Player#player.x, Player#player.y},
			case catch gen_server:call(Player#player.other#player_other.pid_team, Msg) of
				{'EXIT', _Error} ->
					 {teamStatus,Player};
				1 ->
					 NewPlayer = lib_player_rw:set_player_info_fields(Player, [{pid_team, undefined}, {leader, 0}]),
					 enter_single_dungeon_scene(NewPlayer);
				_ ->
					{teamStatus,Player}
			end		
	end.


%% 完成副本任务删除神器 {ok/fail,Player}
finish_single_dungeon_task(Player) ->
	%%卸下神奇
	Fb = goods_util:get_equip_fb(Player#player.id),
	Nplayer = 
	if
		Fb#goods.id /= undefined ->
			{ok,NewPlayer} = pp_goods:handle(15031, Player, Fb#goods.id),
			NewPlayer;
		true ->
			Player
	end,
	Ret = gen_server:call(Player#player.other#player_other.pid_goods,{'DEL_TASK_WEAPON',Player#player.career}),
	{Ret,Nplayer}.


%% 检查神器在不在
is_weapon_exists(Player) ->
	GoodsTypeId =
		case Player#player.career of
			1 -> 11014;
			2 -> 12014;
			3 -> 13014;
			4 -> 14014;
			5 -> 15014;
			_ -> fail
		end,
	case is_integer(GoodsTypeId) of
		true ->
	 		Pattern = #goods{ player_id=Player#player.id, goods_id=GoodsTypeId,stren = 10,grade = 50,bind = 2, _='_' },
     		GoodsList = goods_util:get_ets_list(?ETS_GOODS_ONLINE, Pattern),
			if
				length(GoodsList) > 0 ->
					true;
				true ->
					false
			end;
		false ->
			false
	end.
		
%% 获取玩家所在副本的外场景
get_outside_scene(SceneId) ->
   	DungeonData = data_dungeon:get(SceneId),
   	[SceneId, DungeonData#dungeon.out]. 

%% 检查是否已经完成任务
check_leave(Player) ->
	case lib_task:check_task_is_finish(Player,20361) of
		false->
			false;
		_had_finish ->
			true
	end.
%% 			finish_single_dungeon_task(Player), 
%% 			case is_weapon_exists(Player) of
%% 				false ->
%% 					true;
%% 				true ->
%% 					false
%% 			end;

%% 副本杀怪
kill_mon(Scene, Pid_dungeon, MonIdList) ->
    case misc:is_process_alive(Pid_dungeon) of
        false -> ok;
        true -> Pid_dungeon ! {kill_mon, Scene, MonIdList}
    end.

%% 从副本清除角色(Type=0, 则不回调设置)
quit(Pid_dungeon, Rid, Type) ->
    case misc:is_process_alive(Pid_dungeon) of
        false -> false;
        true -> Pid_dungeon ! {quit, Rid, Type}
    end.

%% 清除副本进程
clear(Pid_dungeon) ->
    case misc:is_process_alive(Pid_dungeon) of
        false -> false;
        true -> Pid_dungeon ! role_clear
    end.

%% 创建单人副本场景资源
create_single_dungeon_scene_resources(SceneId ,FinishTask) ->
	 %% 获取唯一副本场景id
    UniqueId = get_unique_dungeon_id(SceneId),
	if
		FinishTask == can_finish orelse FinishTask ==had_finish ->
			case data_scene:get(SceneId) of
        		[] ->
            		skip;
        		S ->
            		lib_scene:load_npc(S#ets_scene.npc, UniqueId),
            		ets:insert(?ETS_SCENE, S#ets_scene{id = UniqueId, mon=[], npc=[], mask=[]})
    		end;
		true ->
    		lib_scene:copy_scene(UniqueId, SceneId)
	end,
	UniqueId.


%% ------------------------- 服务器内部实现 ---------------------------------
%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([RoleInfo,SceneId,UniqueId]) ->
	ProcessName = misc:create_process_name(scene_p, [UniqueId, 0]),
	process_flag(trap_exit, true),
	misc:register(global, ProcessName, self()),
    {Player_id, Player_Pid,_Pid_dungeon,Realm} = RoleInfo,
    State = #state{
		single_dungeon_scene_id = UniqueId,
		scene_id = SceneId,
		player_pid = Player_Pid,
		player_id = Player_id,
		realm = Realm
    },
	erlang:send_after(?TIMER_1, self(), {check_player_pid}),
	%%?DEBUG("___________________________________________________________init:~p",[State]),
    {ok, State}.

%% --------------------------------------------------------------------
%% Function: handle_call/3
%% Description: Handling call messages
%% Returns: {reply, Reply, State}          |
%%          {reply, Reply, State, Timeout} |
%%          {noreply, State}               |
%%          {noreply, State, Timeout}      |
%%          {stop, Reason, Reply, State}   | (terminate/2 is called)
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------

%% 获取副本信息
handle_call({info}, _From, State) ->
	{reply, State, State};

%% 检查能否离开副本
handle_call({check_leave},_From,State) ->
	Ret =
	if
		State#state.boss_number > 0 ->
			false;
		true ->
			true
	end,
	{reply,Ret,State};

%% 统一模块+过程调用(call)
handle_call({apply_call, Module, Method, Args}, _From, State) ->
%% ?DEBUG("mod_dungeon_apply_call: [~p/~p/~p]", [Module, Method, Args]),	
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_dungeon_apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
			 error;
		 DataRet -> DataRet
	end,
    {reply, Reply, State};

%% 获取掉落物自增ID
handle_call({'GET_DROP_ID', DropNum}, _From, State) ->
	DropId = State#state.drop_id + DropNum + 1,
	NewDropId = 
		if
   			DropId > ?MON_LIMIT_NUM ->
				1;
	   		true ->
				DropId
        end,
	NewState = State#state{
		drop_id = NewDropId
	},
    {reply, State#state.drop_id, NewState};

handle_call(_Request, _From, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%% 统一模块+过程调用(cast)
handle_cast({apply_cast, Module, Method, Args}, State) ->
%% 	?DEBUG("mod_dungeon_apply_cast: [~p/~p/~p]", [Module, Method, Args]),	
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_dungeon_apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
			 error;
		 _ -> ok
	end,
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------

%% 接收杀怪事件
handle_info({kill_mon, _Scene, MonIdList}, State) ->
%% 判断杀的怪是否有用
	Kill_boss = lists:map(fun(MonId) ->
						case ets:lookup(?ETS_BASE_MON, MonId) of
							[] -> 0;
							[Mon] ->
								if Mon#ets_mon.type =:=3 orelse Mon#ets_mon.type =:=5 ->
											 1;
										 true -> 0
								end
						end
				end, 
			MonIdList),
	Kill_boss_number = lists:sum(Kill_boss),
	Alive_boss_number = State#state.boss_number - Kill_boss_number,
	NewState = State#state{boss_number = Alive_boss_number},
    {noreply, NewState};

    
%%检查进程是否存活，否认关闭副本进程
handle_info({check_player_pid},State) ->
	case misc:is_process_alive(State#state.player_pid) of
		true ->
			erlang:send_after(?TIMER_1, self(), {check_player_pid}),
			{noreply, State};
		_ ->
			lib_scene:clear_scene(State#state.single_dungeon_scene_id),
			{stop,normal,State}
	end;

%% 关闭单人副本进程
handle_info(role_clear,State) ->
	lib_scene:clear_scene(State#state.single_dungeon_scene_id),
	{stop,normal,State};

%% 将指定玩家传出副本
handle_info({quit, _Playre_id, Type}, State) ->
	if 
		Type > 0 ->
			case misc:is_process_alive(State#state.player_pid) of	
         		true -> 
             		send_out(State),
					{stop,normal,State};
				_-> 
					{noreply, State}	
			end;
		true -> 
			{noreply, State}	
	end;

%%NOT TICK
handle_info({check_alive, _Num}, State) ->
	{stop,normal,State};

handle_info(_Info, State) ->
    {noreply, State}.
%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, State) ->
	lib_scene:clear_scene(State#state.single_dungeon_scene_id),
	%%?DEBUG("________________________________TERMINATE__",[]),
	ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% -----------------------------私有方法--------------------------------
%% 传送出副本
send_out(State)  ->
	[NextSenceId, X, Y] =
	case State#state.realm of
		1 ->%%女娲
			[200,158,208];
		2 ->%%神农
			[280,157,208];
		3 ->%%伏羲
			[250,159,203];
		_ ->
			[250,159,203]
	end,
	gen_server:cast(State#state.player_pid, {send_out_dungeon, [NextSenceId, X, Y]}).

%% 获取唯一副本场景id
get_unique_dungeon_id(SceneId) ->
	case ?DB_MODULE of
		db_mysql ->
			gen_server:call(mod_auto_id:get_autoid_pid(), {dungeon_auto_id, SceneId});
		_ ->
			db_agent:get_unique_dungeon_id(SceneId)
	end.

%% 用场景资源获取副本id
get_dungeon_id(SceneResId) ->
    F = fun(DungeonId, P) ->
		Dungeon = data_dungeon:get(DungeonId),
		case lists:keyfind(SceneResId, 1, Dungeon#dungeon.scene) of
      		false -> 
				P;
           	_ -> 
				DungeonId
        end
    end,
    lists:foldl(F, 0, data_scene:dungeon_get_id_list()).


