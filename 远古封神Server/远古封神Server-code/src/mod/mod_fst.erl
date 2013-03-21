%%%-----------------------------------
%%% @Module  : mod_fst
%%% @Author  : lzz
%%% @Created : 2011.02.22
%%% @Description: 封神台
%%%-----------------------------------
-module(mod_fst).
-behaviour(gen_server).

%% Include files
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-define(SHOP_LOCS,[6,12,18,24]).

%% External exports
-compile([export_all]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {
	fst_start_time = 0, 				%% 本层封神台开始时间
	fst_scene_id = 0,					%% 副本唯一id
	scene_id = 0,							%% 场景原始id	
    pid_team = undefined,							%% 队伍进程Pid
    fst_role_list = [],   				%% 副本服务器内玩家列表
    fst_scene_requirement_list = [], 	%% 副本场景激活条件
    fst_scene_list =[],    				%% 副本服务器所拥有的场景
	boss_number = 0,							%% 本副本内BOSS个数
	type=0,						%%副本类型：1封神台，2诛仙台
	shops=[],					%%神秘商店
	drop_id = 1
}).

-record(fst_role,  {id, pid}).
-record(fst_scene, {id, did, sid, enable=true, tip = <<>>}).
-record(fst_shop, {player_id,    %%玩家ID
				   loc = 0,      %%层数
				   shop_list=[]  %%商店物品{goods_id,left_num}
				  }).


-define(TIMER_1, 3*60*1000).%% 定时器1间隔时间(定时检查角色进程, 如果不在线，则送出副本)
-define(TIMER_2, 5*60*1000).%% 定时器2间隔时间(定时检查可能没人的封神台进程，若无人，则清除)
%% ----------------------- 对外接口 ---------------------------------
%% 进入封神台
check_enter(SceneResId, SceneType, ScPid) ->
	case catch gen:call(ScPid, '$gen_call', {check_enter, SceneResId, SceneType}, 2000) of
		{'EXIT', _Reason} ->
			{false, <<"系统繁忙，请稍候重试！">>};
		{ok, Result} ->
			Result
	end.

%% 创建副本进程，由lib_scene_fst调用
start(TeamPid, FromPlayerPid, SceneId, RoleList, Members) ->
    {ok, FstPid} = gen_server:start(?MODULE, [TeamPid, SceneId, RoleList, Members], []),
    [gen_server:cast(PlayerPid, {'SET_PLAYER_FST', SceneId, FstPid}) || {_PlayerId, PlayerPid, _PlayerPidFst} <- RoleList, PlayerPid =/= FromPlayerPid],
    {ok, FstPid}.

%% 主动加入新的角色
join(Pid_fst, PlayerInfo) ->
	[_Sceneid, PlayerId, Player_Pid, _Player_Pid_fst] = PlayerInfo,
	Player = [PlayerId, Player_Pid],
    case misc:is_process_alive(Pid_fst) of
        false -> 
			false;
        true -> gen_server:call(Pid_fst, {join, Player})
    end.

%% 从副本清除角色(Type=0, 则不回调设置)
quit(Pid_fst, Rid, Type) ->
    case is_pid(Pid_fst) of
        false -> false;
        true -> Pid_fst ! {fst_quit, Rid, Type}
    end.

%% 封神台进入下一层
fst_to_next(Pid_fst, Rid) ->
    case is_pid(Pid_fst) of
        false -> false;
        true -> Pid_fst ! {fst_to_next, Rid}
    end.

%% 清除副本进程
clear(Pid_fst) ->
    case is_pid(Pid_fst) of
        false -> false;
        true -> Pid_fst ! role_clear
    end.

%% 关闭副本进程
close_fst(Pid_fst) ->
    case is_pid(Pid_fst) of
        false -> false;
        true -> 
			gen_server:cast(Pid_fst,{'close_fst'})
%% 			erlang:send_after(300,Pid_fst,close_fst)
%% 			Pid_fst ! close_fst
    end.	
  
%% 获取玩家所在副本的外场景 
get_outside_scene(SceneId) ->
    case get_fst_id(lib_scene:get_res_id(SceneId)) of
        0 -> 
			false;  %% 不在副本场景
        DungeonId ->  %% 将传送出副本
			Dungeon = data_dungeon:get(DungeonId),
            [DungeonId, Dungeon#dungeon.out]
    end.

%% 副本杀怪
kill_mon(SceneId, FstPid, MonIdList) ->
  	case is_pid(FstPid) of
		true ->
			FstPid ! {kill_mon, SceneId, MonIdList};
		false ->
			skip
  	end.

%% 创建副本场景
create_fst_scene(SceneId, _SceneType, State) ->
	 %% 获取唯一副本场景id
    UniqueId = get_unique_fst_id(SceneId),
	SceneProcessName = misc:create_process_name(scene_p, [UniqueId, 0]),
	misc:register(global, SceneProcessName, self()),
	
    lib_scene:copy_scene(UniqueId, SceneId),  %% 复制场景
	MS = ets:fun2ms(fun(T) when (T#ets_mon.type >= 10 orelse T#ets_mon.type =< 15), T#ets_mon.scene =:= UniqueId ->
							T
					end),		
	L = ets:select(?ETS_SCENE_MON, MS),	
	Boss_number = length(L),				%% 本副本内BOSS个数
    F = fun(DS) ->
        case DS#fst_scene.sid =:= SceneId of
            true -> DS#fst_scene{id = UniqueId};
            false -> DS
        end
    end,
    NewState = State#state{boss_number = Boss_number,
						   fst_scene_id = UniqueId,
						   fst_scene_list = [F(X)|| X <- State#state.fst_scene_list]},    %% 更新副本场景的唯一id
	
	misc:write_monitor_pid(self(),?MODULE, {SceneId}),
    {UniqueId, NewState}.

%% 组织副本的基础数据
get_fst_data([], Dungeon_scene_requirement, Dungeon_scene) ->
    {Dungeon_scene_requirement, Dungeon_scene};
get_fst_data([DungeonId | NewDungeon_id_list], Dungeon_scene_requirement, Dungeon_scene) ->
	Dungeon = data_dungeon:get(DungeonId),
    Dungeon_scene_0 = [#fst_scene{id = 0, did = DungeonId, sid = Sid, enable = Enable, tip = Msg} 
						|| {Sid, Enable, Msg} <- Dungeon#dungeon.scene],
    get_fst_data(NewDungeon_id_list, 
					 Dungeon_scene_requirement ++ Dungeon#dungeon.requirement, 
					 Dungeon_scene ++ Dungeon_scene_0).

%% 获取副本信息
get_info(UniqueId) ->
	SceneProcessName = misc:create_process_name(scene_p, [UniqueId, 0]),
	case misc:whereis_name({global, SceneProcessName}) of
		Pid when is_pid(Pid) ->	
			gen_server:call(Pid, {info});
		_-> no_alive
	end.

%% ------------------------- 服务器内部实现 ---------------------------------
%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([TeamPid, SceneId, RoleList, Members]) ->
	FstStartTime = util:unixtime(),
    FstRoleList = [#fst_role{id = Role_id, pid = Role_pid} || {Role_id, Role_pid, _Player_Pid_fst} <- RoleList],
    {DungeonSceneRequirementList, DungeonSceneList} = get_fst_data([SceneId], [], []),
	SceneType = case lib_scene_fst:is_fst_id(SceneId) of
					true->1;
					false->2
				end,
	Self = self(),
	ShopList = create_fst_shop(TeamPid, SceneId, RoleList,Members),
    State = #state{
		fst_start_time = FstStartTime,
		scene_id = SceneId,
        pid_team = TeamPid,
        fst_role_list = FstRoleList,
        fst_scene_requirement_list = DungeonSceneRequirementList,
        fst_scene_list = DungeonSceneList,
		type = SceneType,
		shops = ShopList
    },
	%%暂时注释
	[_, _, _, LT] = lib_scene_fst:get_tower_award(SceneId rem 100),%%原代码
%% 	LT = 25,
	misc:cancel_timer(timer1),
	Timer1 = erlang:send_after(LT * 1000, Self, {end_fst_check, LT}),
	misc:cancel_timer(timer2),
	Timer2 = erlang:send_after(?TIMER_1, Self, check_role_pid),
	put(timer1,Timer1),
	put(timer2,Timer2),
	misc:write_monitor_pid(self(),?MODULE, {State}),
    {ok, State}.

%%创建神秘商店
create_fst_shop(TeamPid, SceneId, RoleList, Members)->
	Loc = SceneId rem 1000,
	case lists:member(Loc, ?SHOP_LOCS) of
		true ->
			%%根据层数找到对应的商人
			{ShopType,ShopSubtype} = 
				case Loc of
					6 ->  {21048,1};
					12 -> {21049,1};
					18 -> {21050,1};
					24 -> {21051,1}
				end,						
			Rnd =  util:rand(1,100),
			%%按概率随机选择商品的个数
			GoodsNum = 
				case Rnd >= 50 of
					true ->
						5;
					false ->
						4
				end,
			%%根据概率动态生成商品列表
			GoodsId_Nums_List = data_agent:get_rand_goods(Loc,GoodsNum,[],[ShopType,ShopSubtype]),		
			case TeamPid of
				0 ->
					[#fst_shop{player_id = Role_id, loc = Loc, shop_list = GoodsId_Nums_List} || {Role_id, _Role_pid, _Player_Pid_fst} <- RoleList];
				undefined ->
					[#fst_shop{player_id = Role_id, loc = Loc, shop_list = GoodsId_Nums_List} || {Role_id, _Role_pid, _Player_Pid_fst} <- RoleList];
				_->
					Ids = [M#mb.id || M <- Members],
					[#fst_shop{player_id = Id, loc = Loc, shop_list = GoodsId_Nums_List} || Id <- Ids]
			end;
		false ->
			[]
	end.

%%显示隐藏的NPC


%%清除商店数据

%%根据NPCID判断是否神秘商店
is_fst_shop(Shoptype)->
	lists:member(Shoptype, [21048,21049,21050,21051]).

%%打开神秘商店
open_fst_shop(PlayerId,Loc,Fst_State) ->
	ShopList = lists:filter(fun(S)->S#fst_shop.loc =:= Loc andalso S#fst_shop.player_id =:= PlayerId end, Fst_State#state.shops),
	case ShopList of
		[] ->
			{fail,16}; %%商店还未开启
		[Shop|_Rets] ->%%要保证一个角色只有一个同层商店
			Goods_Num_List = lists:sort(Shop#fst_shop.shop_list),
			{ok,Goods_Num_List}
	end.

%%购买神秘商店物品
buy_from_fst_shop(Player,Loc,GoodsTypeId,GoodsNum,_ShopType,_ShopSubtype,Fst_State) ->
	NowSceneId = Player#player.scene,
	case (NowSceneId rem 1000) =/= Loc of
		true ->
			{fail,17}; %%所在场景不能购买此物品
		false ->
			ShopList = lists:filter(fun(S)->S#fst_shop.loc =:= Loc andalso S#fst_shop.player_id =:= Player#player.id end, Fst_State#state.shops),
			case ShopList of
				[] ->
					{fail,16}; %%商店还未开启
				[Shop|_Rets] ->%%要保证一个角色只有一个同层商店
					Goods_Num_List = Shop#fst_shop.shop_list,
					case lists:keyfind(GoodsTypeId, 1, Goods_Num_List) of
						false ->
							{fail,2};%%物品不存在
						Shop_Goods ->
							{Gid,LimitBuy} = Shop_Goods,
							case GoodsNum > LimitBuy of
								true ->
									{fail,15};%%物品已经达到限购上限，不能购买
								false ->
									%%走正常购买流程
%% 									pp_goods:handle(15020, Player, [GoodsTypeId, GoodsNum, ShopType ,ShopSubtype]),
									%%更新可购买个数
									Shops = lists:delete(ShopList, Fst_State#state.shops),
									Goods_Num_List1 = lists:delete(Shop_Goods, Goods_Num_List),
									RetNum = LimitBuy-GoodsNum,
									ShopList2 = Shop#fst_shop{player_id = Player#player.id, loc = Loc, shop_list = [{Gid,RetNum}|Goods_Num_List1]},
									%%通知客户端更新剩余个数
									{ok,BinData} = pt_15:write(15141,[GoodsTypeId,RetNum]),
									lib_send:send_to_sid(Player#player.other#player_other.pid_send,BinData),
									{ok,Fst_State#state{shops = [ShopList2|Shops]}}								
							end
					end
			end
	end.
	
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
%%检查进入副本
handle_call({check_enter, SceneResId, SceneType}, _From, State) ->   %% 这里的SceneId是数据库的里的场景id，不是唯一id
%% ?DEBUG("check_enter_~p~p", [SceneResId, State]),
    case lists:keyfind(SceneResId, 4, State#state.fst_scene_list) of
        false ->
            {reply, {false, <<"没有这个副本场景">>}, State};   %%没有这个副本场景
        Fst_scene ->
            case Fst_scene#fst_scene.enable of
                false ->
                    {reply, {false, Fst_scene#fst_scene.tip}, State};    %%还没被激活
                true ->
                    {SceneUniqueId, NewState} = 
									case Fst_scene#fst_scene.id =/= 0 of
                        				true -> 
											{Fst_scene#fst_scene.id, State};   %%场景已经加载过
                        				_ -> 
											create_fst_scene(SceneResId, SceneType, State)
                    				end,
					misc:write_monitor_pid(self(),?MODULE, {NewState}),
                    {reply, {true, SceneUniqueId}, NewState}
            end
    end;

%% 加入副本服务
handle_call({join, PlayerInfo}, _From, State) ->
	[PlayerId, Player_Pid] = PlayerInfo,
	[_, _, _, LimT] = lib_scene_fst:get_tower_award(State#state.scene_id rem 100),
	Nowtime = util:unixtime(),
	UsedT = Nowtime - State#state.fst_start_time,
	LeftT = LimT - UsedT,
	if
		LeftT >= 0 andalso UsedT >= 0 ->
            {ok, BinData} = pt_35:write(35004, [LeftT, UsedT]),
            lib_send:send_to_uid(PlayerId, BinData);
		true ->
            {ok, BinData} = pt_35:write(35004, [0, UsedT]),
            lib_send:send_to_uid(PlayerId, BinData)
	end,
	NewList = lists:keydelete(PlayerId, 2, State#state.fst_role_list),
    NewRL = NewList ++ [#fst_role{id = PlayerId, pid = Player_Pid}],
	NewState = State#state{fst_role_list = NewRL},
	misc:write_monitor_pid(self(),?MODULE, {NewState}),
    {reply, true, NewState};

%% 获取副本信息
handle_call({info}, _From, State) ->
	{reply, State, State};

%% 获取副本场景ID 
handle_call({info_id}, _From, State) ->
	{reply, State#state.scene_id, State};

%%购买神秘商店物品
%%buy_from_fst_shop(Player,Loc,GoodsTypeId,GoodsNum,Fst_State),
handle_call({buy_from_fst_shop,Player,GoodsTypeId,GoodsNum,ShopType,ShopSubtype}, _From, State) ->
	Loc = (State#state.scene_id) rem 1000,
	{Res,Ret,NewState} = 
		case buy_from_fst_shop(Player,Loc,GoodsTypeId,GoodsNum,ShopType,ShopSubtype,State) of
			{fail,Code} ->
				{fail,Code,State};
			{ok,State1} ->				
				{ok,0,State1}
		end,
	{reply, {Res,Ret}, NewState};

%% 打开神秘商店
%%open_fst_shop(PlayerId,Loc,Fst_State) ->
handle_call({open_fst_shop,PlayerId}, _From, State) ->
	Loc = (State#state.scene_id) rem 1000,
	Reply = open_fst_shop(PlayerId,Loc,State),
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

%% 统一模块+过程调用(call)
handle_call({apply_call, Module, Method, Args}, _From, State) ->
%%  ?DEBUG("mod_fst_apply_call: [~p/~p/~p]", [Module, Method, Args]),	
	Reply  = 
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_fst_apply_call error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
			 error;
		 DataRet -> DataRet
	end,
    {reply, Reply, State};

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
%% 	%% ?DEBUG("mod_fst_apply_cast: [~p/~p/~p]", [Module, Method, Args]),	
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_fst_apply_cast error: Module=~p, Method=~p, Args =~p, Reason=~p",[Module, Method, Args, Info]),
			 error;
		 _ -> ok
	end,
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

%% 怪物特定范围伤害
handle_cast({'LAST_AREA_DAM', Hurt, Last, AttArea, SceneId, X, Y, SkillId}, State) ->
	erlang:send_after(1000, self(), {'LAST_AREA_DAM', Hurt, Last, AttArea, SceneId, X, Y}),
	{ok, BinData} = pt_20:write(20103, [X, Y, (Last + 1) * 1000, SkillId]),
	lib_send:send_to_online_scene(SceneId, X, Y, BinData),
	{noreply, State};

%%接收关闭封神台信息
handle_cast({'close_fst'},State)->
	erlang:send_after(1000,self(),close_fst),
	{noreply,State};

%% handle_cast({'CHECK_THRU', Thru_time, Loc, U_pid}, State) ->
%% %% 	%% ?DEBUG("mod_fst_apply_cast: [~p/~p/~p]", [Module, Method, Args]),	
%% 	case State#state.fst_start_time of
%% 		 0 ->	
%% 			 {noreply, State};
%% 		 Beg_time ->
%% 			 Used_time = Thru_time - Beg_time,
%% 			 case lib_scene:check_fst_thru(Loc, Used_time) of
%% 				 norec ->
%% 					 case State#state.pid_team of
%% 						 undefined ->
%% 							gen_server:cast(U_pid, {'SET_FST_GOD', Loc, Used_time, add, 1});
%% 						 Team_pid ->
%% 					 		gen_server:cast(Team_pid, {'SET_FST_GOD_TEAM', Loc, Used_time, add})
%% 					end;
%% 				 [_] ->
%% 					 case State#state.pid_team of
%% 						 undefined ->
%% 							gen_server:cast(U_pid, {'SET_FST_GOD', Loc, Used_time, update, 1});
%% 						 Team_pid ->
%% 					 		gen_server:cast(Team_pid, {'SET_FST_GOD_TEAM', Loc, Used_time, update})
%% 					end;
%% 				 _ ->
%% 					 ok
%% 			 end,
%% 			 NewState = State#state{fst_start_time = 0},
%% 			 {noreply, NewState}
%% 	end;

handle_cast(_Msg, State) ->
    {noreply, State}.

%% 怪物特定范围伤害
handle_info({'LAST_AREA_DAM', Hurt, Last, AttArea, SceneId, X, Y}, State) ->
	lib_mon:battle(0, 0, 0, SceneId, X, Y, AttArea, Hurt, 0, 10048),
	case Last > 0 of
		true ->
			erlang:send_after(1000, self(), {'LAST_AREA_DAM', Hurt, Last - 1, AttArea, SceneId, X, Y});
		false ->
			skip
	end,
    {noreply, State};

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%% 在副本里创建队伍，需要设置到副本进程
handle_info({set_team, Pid_team}, State) ->
	NewState = State#state{pid_team = Pid_team},
  	{noreply, NewState};

%% 接收杀怪事件
handle_info({kill_mon, _EventSceneId, MonIdList}, State) ->
	lists:map(fun(MonId) ->
					  case ets:lookup(?ETS_BASE_MON, MonId) of
						  [] -> 0;
						  [Mon] ->
							  Loc = State#state.scene_id rem 100,							 
							  if Mon#ets_mon.type >=20 andalso Mon#ets_mon.type =< 25 andalso Mon#ets_mon.mid =/= 47057 ->
									 erlang:send_after(1 * 1000, self(), {kill_fst_boss, Loc, Mon#ets_mon.name,Mon#ets_mon.mid}),1;
								 true -> 0
							  end
					  end
			  end, 
			  MonIdList),
	{noreply,State};
	%% 判断杀的怪是否有用
%%     case lists:keyfind(EventSceneId, 2, State#state.fst_scene_list) of
%%         false -> {noreply, State};    %% 没有这个场景id
%%         _ ->
%% 			Kill_boss = lists:map(fun(MonId) ->
%% 								case ets:lookup(?ETS_BASE_MON, MonId) of
%% 									[] -> 0;
%% 									[Mon] ->
%% 										if Mon#ets_mon.type >=20 andalso Mon#ets_mon.type =< 25 andalso Mon#ets_mon.mid =/= 47057 ->
%%  											Loc = State#state.scene_id rem 100,
%% 											erlang:send_after(1 * 1000, self(), {kill_fst_boss, Loc, Mon#ets_mon.name}),
%% 											1;
%% 										   true -> 0
%% 										end
%% 								end
%% 						   end, 
%% 						   MonIdList),
%%             {NewDSRL, UpdateScene} = event_action(State#state.fst_scene_requirement_list, [], MonIdList, []),
%%             EnableScene = get_enable(UpdateScene, [], NewDSRL),
%%             NewState_1 = enable_action(EnableScene, State#state{fst_scene_requirement_list = NewDSRL}),
%% 			Kill_boss_number = lists:sum(Kill_boss),
%% 			Alive_boss_number = NewState_1#state.boss_number - Kill_boss_number,
%% 			NewState_2 = NewState_1#state{boss_number = Alive_boss_number},
%%             {noreply, NewState_2}
%%     end;

%% 封神台杀Boss事件
handle_info({kill_fst_boss, Loc, Monname, _Monid}, State) ->
	case lib_scene:get_scene_mon(State#state.fst_scene_id) of
		[] ->
			ThruTime = util:unixtime(),
			check_thru(State#state.fst_start_time, ThruTime, Loc, State#state.fst_role_list, State#state.pid_team),
			 case lists:member(Loc,?SHOP_LOCS) of
				 true ->
					 case lib_scene:get_scene_mon(State#state.fst_scene_id) of
						 [] ->
							 %%这里要增加显示BOSS的代码,协议？？？
							 {ok,BinData} = pt_32:write(32002,<<>>),
							 F = fun(Pid) ->
										 lib_send:send_to_uid(Pid,BinData) end,
							 [F(M#fst_role.id)|| M <- State#state.fst_role_list];
						 _ ->%%本层怪还没有全部消灭
							 skip
					 end;
				 false ->
					 skip
			end,
			if
				Loc >= 20 ->
					case State#state.pid_team of
						Val when Val =:= undefined orelse Val=:= 0 ->
							case State#state.fst_role_list of
								[R] ->
									gen_server:cast(R#fst_role.pid, {'BC_FST_KILL_BOSS', Loc, Monname}),
									{noreply, State};
								_ ->
									{noreply, State}
							end;
						Pid_team ->
							gen_server:cast(Pid_team, {'BC_FST_KILL_BOSS_TEAM', Loc, Monname}),
							{noreply, State}
					end;
				true ->
					{noreply, State}
			end;
		_ ->
			{noreply, State}
	end;

%% 将指定玩家传出副本
handle_info({fst_quit, Rid, Type}, State) ->
    case lists:keyfind(Rid, 2, State#state.fst_role_list) of
        false -> {noreply, State};
        Role ->
			if Type > 0 ->
				case misc:is_process_alive(Role#fst_role.pid) of	
                	true -> 
                    	send_out(Role#fst_role.id, State#state.scene_id);
					_-> offline   %% 不在线	
            	end;
			   true -> no_action
			end,
			NewState = State#state{fst_role_list = lists:keydelete(Rid, 2, State#state.fst_role_list),
								   shops = lists:filter(fun(S)->S#fst_shop.player_id =/= Rid end, State#state.shops )},
			erlang:send_after(?TIMER_2, self(), role_clear),
            {noreply, NewState}			
    end;

%% 玩家离开当前层
handle_info({fst_to_next, Rid}, State) ->
    case lists:keyfind(Rid, 2, State#state.fst_role_list) of
        false -> {noreply, State};
        _Role ->
			erlang:send_after(?TIMER_2, self(), role_clear),
            {noreply, State}		
    end;

%% 清除角色, 关闭副本服务进程
handle_info(role_clear, State) ->
	case misc:is_process_alive(State#state.pid_team) of
        true -> %% 有组队
            case length(State#state.fst_role_list) >= 1 of  %% 判断副本是否没有人了
                true ->
					erlang:send_after(?TIMER_2, self(), role_clear),
                    {noreply, State};
                false ->
					gen_server:cast(State#state.pid_team, {clear_fst, State#state.scene_id}),
                    {stop, normal, State}
            end;
        false ->
			case length(State#state.fst_role_list) >= 1 of
				true ->
					erlang:send_after(?TIMER_2, self(), role_clear),
                    {noreply, State};
				false ->
            		{stop, normal, State}
			end
    end;

%% 过了封神台限定时间，检查是否还有怪存在
%% 若有，则封神台结束
%% 若无，则延长时间的4倍 
handle_info({alert_b4_end, LT}, State) ->
	{ok, BinData} = pt_11:write(11081, "离本层结束时间还有一分钟"),
	F = fun(PlayerId) ->
				lib_send:send_to_uid(PlayerId, BinData)
		end,
	[F(M#fst_role.id)|| M <- State#state.fst_role_list],
	erlang:send_after(60 * 1000, self(), {end_fst_check, LT}),
	{noreply, State};

%% 过了封神台限定时间，检查是否还有怪存在
%% 若有，则封神台结束
%% 若无，则延长时间的4倍 
handle_info({end_fst_check, LT}, State) ->
	misc:cancel_timer(timer1),
	case lib_scene:get_scene_mon(State#state.fst_scene_id) of
		[] ->
            case length(State#state.fst_role_list) >= 1 of  %% 判断副本是否没有人了
                true ->
					{ok, BinData} = pt_35:write(35004, [LT * 4 , LT  + 1]),
					F = fun(Pid) ->			
						gen_server:cast(Pid, {sync_fst_time, [State#state.scene_id,BinData]})
%% 						lib_send:send_to_uid(PlayerId, BinData)
    				end,
					[F(M#fst_role.pid)|| M <- State#state.fst_role_list],					
					erlang:send_after(LT * 4  * 1000, self(), end_fst);
                false ->
					erlang:send_after(?TIMER_2, self(), end_fst)
            end;
		 _ ->
			 self() ! end_fst
	end,
	{noreply, State};

%% 过了封神台限定时间，封神台结束
handle_info(end_fst, State) ->
	{ok, BinData} = case State#state.type of
						1->
							pt_11:write(11081, "封神台时间到，您被送出封神台");
						_->
							pt_11:write(11081, "诛仙台时间到，您被送出诛仙台")
					end,
	F = fun(Role_Pid) ->
   		send_out_jd(Role_Pid, BinData,State#state.scene_id,self())
    end,
    [F(M#fst_role.pid)|| M <- State#state.fst_role_list],
	%%把角色送出封神台，3秒后关闭封神台
	erlang:send_after(3000, self(), close_fst),
	{noreply, State};


%%显示NPC
handle_info({'display_npc',Bin,Uid}, State) ->
	lib_send:send_to_uid(Uid,Bin),
	{noreply, State};

%% 关闭封神台
handle_info(close_fst, State) ->
	case misc:is_process_alive(State#state.pid_team) of
		true ->
			gen_server:cast(State#state.pid_team, {clear_fst, State#state.scene_id});
		false ->
			ok
	end,
	{stop, normal, State};

%% 定时检查角色进程, 如果不在线，则送出副本
handle_info(check_role_pid, State) ->
	misc:cancel_timer(timer2),
	NowMembers = length(lib_scene:get_scene_user(State#state.fst_scene_id)),
	NewRoleList = lists:filter(fun(Role)-> 
									misc:is_process_alive(Role#fst_role.pid) 
							   end, 
				  			   State#state.fst_role_list),
	case NowMembers >= 1 of
		 true -> 	 
				HandleTimer2 = erlang:send_after(?TIMER_1, self(), check_role_pid),
				put(timer2,HandleTimer2),
				NewState = State#state{fst_role_list = NewRoleList},
				misc:write_monitor_pid(self(),?MODULE, {NewState}),
				{noreply, NewState};			 
		 _ -> %% 没有角色啦，则 清除副本
				case misc:is_process_alive(State#state.pid_team) of
        			true -> %% 有组队, 通知队伍进程	
						gen_server:cast(State#state.pid_team, {clear_fst, State#state.scene_id});
					_ -> no_action
				end,
				{stop, normal, State}
	end;

handle_info(_Info, State) ->
%% io:format("fst_nomatch:/~p/ ~n", [length(State#state.fst_role_list)]),
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, State) ->
%% io:format("fst_exit ~n"),
	misc:cancel_timer(timer1),
	misc:cancel_timer(timer2),
	[lib_scene:clear_scene(Ds#fst_scene.id)|| 
				Ds <- State#state.fst_scene_list, Ds#fst_scene.id =/= 0],
	misc:delete_monitor_pid(self()),	
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% -----------------------------私有方法--------------------------------
%% 传送出封神台
send_out(Pid, SceneId) ->
	DungeonData = data_dungeon:get(SceneId), 
	[NextSenceId, X, Y] = DungeonData#dungeon.out,
	gen_server:cast(Pid, {send_out_fst, [NextSenceId, X, Y]}).

%% 传送出封神台 需先判断是否在此场景
send_out_jd(Pid, BinData,SceneId,FstPid)  ->
	gen_server:cast(Pid, {send_out_fst_mail, [BinData,SceneId,FstPid]}).

%% 类似格式： [[451, false, kill_mon, 30031, 10, 0],[452, false, kill_mon, 30032, 1, 0]]
event_action([], Req, _, Result) -> {Req, Result};
event_action(undefined, Req, _, Result) -> {Req, Result};
event_action([[EnableSceneResId, false, kill_mon, MonId, Num, NowNum] | T ], Req, Param, Result)->
    MonList = Param,
    case length([X||X <- MonList, MonId =:= X]) of
        0 -> event_action(T, [[EnableSceneResId, false, kill_mon, MonId, Num, NowNum] | Req], Param, Result);
        FightNum ->
            case NowNum + FightNum >= Num of
                true -> 
					event_action(T, [[EnableSceneResId, true, kill_mon, MonId, Num, Num] | Req], Param, lists:umerge(Result, [EnableSceneResId]));
                false -> 
					event_action(T, [[EnableSceneResId, false, kill_mon, MonId, Num, NowNum + FightNum] | Req], Param, lists:umerge(Result, [EnableSceneResId]))
            end
    end;
%% 丢弃异常和已完成的
event_action([_ | T], Req, Param, Result) ->
    event_action(T, Req, Param, Result).

get_enable([], Result, _) -> Result;
get_enable(undefined, Result, _) -> Result;
get_enable([SceneId | T ], Result, DSRL) ->
    case length([0 || [EnableSceneResId, Fin | _ ] <- DSRL, EnableSceneResId =:= SceneId, Fin =:= false]) =:= 0 of
        false -> get_enable(T, Result, DSRL);
        true -> get_enable(T, [SceneId | Result], DSRL)
    end.

enable_action([], State) -> State;
enable_action(undefined, State) -> State;
enable_action([SceneId | T], State) ->
    case lists:keyfind(SceneId, 4, State#state.fst_scene_list) of
        false -> enable_action(T, State);%%这里属于异常
        DS ->
            NewDSL = lists:keyreplace(SceneId, 4, State#state.fst_scene_list, DS#fst_scene{enable = true}),
            enable_action(T, State#state{fst_scene_list = NewDSL})
    end.

%% 获取唯一副本场景id
get_unique_fst_id(SceneId) ->
	case ?DB_MODULE of
		db_mysql ->
			gen_server:call(mod_auto_id:get_autoid_pid(), {fst_auto_id, SceneId});
		_ ->
			db_agent:get_unique_dungeon_id(SceneId)
	end.

%% 用场景资源获取副本id
get_fst_id(SceneResId) ->
    F = fun(FstId, P) ->
		Fst = data_dungeon:get(FstId), 
		case lists:keyfind(SceneResId, 1, Fst#dungeon.scene) of
      		false 
				-> P;
      		_ -> 
				FstId
        end
    end,
    lists:foldl(F, 0, data_scene:dungeon_get_id_list()).

%% 检查是否成为霸主，【内部函数】
check_thru(StartTime, ThruTime, Loc, Role_list, Team_Pid) ->
	case StartTime of
		 0 ->
			 ok;
		 Beg_time ->
			Used_time = ThruTime - Beg_time,
			case lib_scene:check_fst_thru(Loc, Used_time) of
				 norec ->
					 case Team_Pid of
						 undefined ->
							case Role_list of
								[R] ->
									U_pid = R#fst_role.pid,
									gen_server:cast(U_pid, {'SET_FST_GOD', Loc, Used_time, add, true});
								_ ->
									ok
							end;
						 0 ->
							case Role_list of
								[R] ->
									U_pid = R#fst_role.pid,
									gen_server:cast(U_pid, {'SET_FST_GOD', Loc, Used_time, add, true});
								_ ->
									ok
							end;
						 Team_pid ->
					 		gen_server:cast(Team_pid, {'SET_FST_GOD_TEAM', Loc, Used_time, add})
					end;
				 [_] ->
					 case Team_Pid of
						 undefined ->
							case Role_list of
								[R] ->
									U_pid = R#fst_role.pid,
									gen_server:cast(U_pid, {'SET_FST_GOD', Loc, Used_time, update, true});
								_ ->
									ok
							end;
						 0 ->
							case Role_list of
								[R] ->
									U_pid = R#fst_role.pid,
									gen_server:cast(U_pid, {'SET_FST_GOD', Loc, Used_time, update, true});
								_ ->
									ok
							end;
						 Team_pid ->
					 		gen_server:cast(Team_pid, {'SET_FST_GOD_TEAM', Loc, Used_time, update})
					end;
				 _ ->
					 ok
			 end,
			 ok
	end.

%%判断是否需要显示NPC
check_display_npc(PlayerId,SceneId,Dungeon_pid,FstPidList)->
	FstSceneId = SceneId rem 10000,
	ScenePid =
		case lists:keysearch(FstSceneId, 1, FstPidList) of
			{value,{_, Fst_pid_from_player}} ->
				Fst_pid_from_player;
			_ ->
				Dungeon_pid
		end,
	case lists:member(FstSceneId, [1006,1012,1018,1024]) of
		false -> skip;
		true ->
			gen_server:cast(ScenePid, {apply_cast, lib_mon, is_alive_scene_mon, [SceneId,PlayerId,ScenePid]})
	end.
		
%% 		{'EXIT',_Reason} ->
%% 			skip;
%% 		true ->
%% 			skip;
%% 		false ->
%% 			{ok,BinData} = pt_32:write(32002,<<>>),
%% 			ScenePid ! {'display_npc',BinData,PlayerId}
%% 	end.
			
