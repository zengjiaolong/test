%%% -------------------------------------------------------------------
%%% Author  : xiaomai
%%% Description :诛邪系统
%%%
%%% Created : 2010-11-17
%%% -------------------------------------------------------------------
-module(mod_box).

-behaviour(gen_server).
%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("common.hrl").
-include("record.hrl").
%% --------------------------------------------------------------------
%% External exports
-export([start_link/0,
		 start/0,
		 stop/0,
		 get_ets_boxgoods_type/0,
		 get_box_pro_list/2,
		 open_box/9,						%% 28002  开宝箱
		 get_warehouse/1,					%% 28003  获取诛邪仓库数据
		 put_goods_into_bag/2,				%% 28004  将物品放入背包
		 discard_box_goods/3,				%% 28005  将物品丢弃
		 discard_all_box_goods/1,			%% 28006  丢弃仓库中的所有物品
		 put_all_goods_into_bag/1,			%% 28007  将所有物品放入背包
		 get_box_remain_cells/1,			%% 28008  获取仓库的容量
		 box_enter_scene/1					%%进入秘境的分支判断
%% 		 get_pro_list/2
		]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).


%% ====================================================================
%% External functions
%% ====================================================================
start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

start() ->
	gen_server:start(?MODULE, [], []).

stop() ->
    gen_server:call(?MODULE, stop).
%% %%广播
%% boradcast_box_goods(PlayerId, PlayerName, Realm, PlayerLevel, HoleType, OpenType, GoodsList) ->
%% 	gen_server:cast(?MODULE, {'broadcast_box_goods',PlayerId, PlayerName, 
%% 							  Realm, PlayerLevel,HoleType, OpenType, GoodsList}).

%% ====================================================================
%% Server functions
%% ====================================================================

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([]) ->
	process_flag(trap_exit, true),	

%%  	misc:register(global, ProcessName, self()),	%% 多节点的情况下， 仅启用一个诛邪系统处理进程
			%% ?DEBUG("init the mod_box ETS_BASE_BOX_GOODS_ONE now....", []),
			ets:new(?ETS_BASE_BOX_GOODS_ONE, [{keypos, #ets_base_box_goods.id}, named_table, public, set,?ETSRC, ?ETSWC]),
			%% ?DEBUG("init the mod_box ETS_BASE_BOX_GOODS_TWO now....", []),
			ets:new(?ETS_BASE_BOX_GOODS_TWO, [{keypos, #ets_base_box_goods.id}, named_table, public, set,?ETSRC, ?ETSWC]),
%%  		ets:new(?ETS_OPEN_BOXGOODS_PRO, [{keypos, #ets_open_boxgoods_pro.id}, named_table, public, set]),
			%%在此处新建一个用于保存诛邪副本的数据ets
			ets:new(?ETS_BOX_SCENE, [{keypos, #ets_box_scene.player_id}, named_table, public, set,?ETSRC, ?ETSWC]),
			
			EtsBoxGoodsType = 1,
			lib_box:load_all_box(EtsBoxGoodsType),
	
			BoxState = lib_box:load_all_box_goods_pro(EtsBoxGoodsType),
			NewBoxState = BoxState#box_status{ets_box_goods_type = EtsBoxGoodsType},
			misc:write_monitor_pid(self(),?MODULE, {}),
			misc:write_system_info(self(), mod_box, {}),
			erlang:send_after(?TIMESTAMP, self(), {event, mod_box_update_action}),
			%% ?DEBUG("init the mod_box process children now....please wait", []),
			 %%产生种子
			{MegaSecs, Secs, MicroSecs} = now(),
%% 			%% ?DEBUG("{~p, ~p,~p,~p}", [ProcessId, MegaSecs+ProcessId, Secs+ProcessId*10, MicroSecs+ProcessId*100]),
			random:seed({MegaSecs, Secs, MicroSecs}),
			{ok, NewBoxState}.

get_ets_boxgoods_type() ->
	gen_server:call(?MODULE, {'get_ets_boxgoods_type'}).

get_box_pro_list(Career, HoleType) ->
	gen_server:call(?MODULE, {'get_pro_list', Career, HoleType}).

%% broadcast_box_to_local_all(Data, BroadCastGoodsList) ->
%% 	gen_server:cast(?MODULE, {'send_to_local_all', Data, BroadCastGoodsList}).
%% get_pro_list(Career, HoleType) ->
%% 	gen_server:call(self(),{'get_pro_list', Career, HoleType}).
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
%% 统一模块+过程调用(call)
handle_call({apply_call, Module, Method, Args}, _From, State) ->
	%% ?DEBUG("****************mod_box_apply_call:[~p,~p]*********", [Module, Method]),
	Reply = 
		case (catch apply(Module, Method, Args)) of
			{'EXIT', Info} ->
				?WARNING_MSG("mod_box_apply_call: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
				error;
			DataRet -> DataRet
		end,
	{reply, Reply, State};

%%用于获取诛邪物品的列表
%%警告：此方法不能在不能通过外部的rpc调用，只能使用mod_boxget_box_pro_list/2进行调用，否则将会报错
handle_call({'get_pro_list', Career, HoleType}, _From, State) ->
	Type = lists:concat([Career, HoleType]),
	Reply  = 
		case Type of
			"11" -> State#box_status.box_goods_11;
			"12" -> State#box_status.box_goods_12;
			"13" -> State#box_status.box_goods_13;
			"14" -> State#box_status.box_goods_14;
			"21" -> State#box_status.box_goods_21;
			"22" -> State#box_status.box_goods_22;
			"23" -> State#box_status.box_goods_23;
			"24" -> State#box_status.box_goods_24;
			"31" -> State#box_status.box_goods_31;
			"32" -> State#box_status.box_goods_32;
			"33" -> State#box_status.box_goods_33;
			"34" -> State#box_status.box_goods_34;
			"41" -> State#box_status.box_goods_41;
			"42" -> State#box_status.box_goods_42;
			"43" -> State#box_status.box_goods_43;
			"44" -> State#box_status.box_goods_44;
			"51" -> State#box_status.box_goods_51;
			"52" -> State#box_status.box_goods_52;
			"53" -> State#box_status.box_goods_53;
			"54" -> State#box_status.box_goods_54
	end,
	{reply, Reply, State};


%% 获取当前诛邪系统的物品ets表类型：
%% 1：ETS_BASE_BOX_GOODS_ONE,
%% 2：ETS_BASE_BOX_GOODS_TWO
%%警告：此方法不能在不能通过外部的rpc调用，只能使用mod_box:get_ets_boxgoods_type/0进行调用，否则将会报错
handle_call({'get_ets_boxgoods_type'}, _From, State) ->
	Reply = State#box_status.ets_box_goods_type,
	{reply, Reply, State};

handle_call({'open_box_call', PlayerId, Gold, GoodsPid, PlayerPid, Career, BoxGoodsTrace, 
			 OpenCounter, PlayerPurpleNum, PurpleTimeType, HoleType, OpenType, PurpleEList, Proto}, _From, State) ->
	Type = lists:concat([Career, HoleType]),
	ProList  = 
		case Type of
			"11" -> State#box_status.box_goods_11;
			"12" -> State#box_status.box_goods_12;
			"13" -> State#box_status.box_goods_13;
			"14" -> State#box_status.box_goods_14;
			"21" -> State#box_status.box_goods_21;
			"22" -> State#box_status.box_goods_22;
			"23" -> State#box_status.box_goods_23;
			"24" -> State#box_status.box_goods_24;
			"31" -> State#box_status.box_goods_31;
			"32" -> State#box_status.box_goods_32;
			"33" -> State#box_status.box_goods_33;
			"34" -> State#box_status.box_goods_34;
			"41" -> State#box_status.box_goods_41;
			"42" -> State#box_status.box_goods_42;
			"43" -> State#box_status.box_goods_43;
			"44" -> State#box_status.box_goods_44;
			"51" -> State#box_status.box_goods_51;
			"52" -> State#box_status.box_goods_52;
			"53" -> State#box_status.box_goods_53;
			"54" -> State#box_status.box_goods_54
	end,
%% 	?DEBUG("'open_box_call'~p,,OpenCounter[~p], PlayerPurpleNum[~p], PurpleTimeType[~p], HoleType[~p], OpenType[~p], ProList:~p, ~n, State:~p", 
%% 		   [State#box_status.ets_box_goods_type, OpenCounter, PlayerPurpleNum, PurpleTimeType, HoleType, OpenType, ProList, State]),
	Reply = lib_box:open_box(State#box_status.ets_box_goods_type, 
							 PlayerId, Gold, GoodsPid, PlayerPid, 
							 Career, BoxGoodsTrace, OpenCounter, PlayerPurpleNum, 
							 PurpleTimeType, HoleType, OpenType, ProList, PurpleEList, Proto),
	{reply, Reply, State};

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%% 统一模块+过程调用(cast)
handle_cast({apply_cast, Module, Method, Args}, State) ->
	%% ?DEBUG("mod_box__apply_cast: [~p,~p]", [Module, Method]),	
	case (catch apply(Module, Method, Args)) of
		 {'EXIT', Info} ->	
			 ?WARNING_MSG("mod_box__apply_cast error: Module=~p, Method=~p, Reason=~p",[Module, Method,Info]),
			 error;
		 _ -> ok
	end,
    {noreply, State};

handle_cast({apply_asyn_cast, Module, Method, Args}, State) ->
    spawn(fun()-> apply(Module, Method, Args) end),
	{noreply, State};

handle_cast({event, mod_box_update_action}, State) ->
	NewState = lib_box:handle_update_action(1, State),
	{noreply, NewState};

%% handle_cast({'broadcast_box_goods', PlayerId, PlayerName, Realm, PlayerLevel, 
%% 			 HoleType, OpenType, GoodsList}, State) ->
%% 	%% ?DEBUG("******  the GoodsList length is [~p]  ******", [length(GoodsList)]),
%% 	{BroadCastGoodsList, CastListStr} = 
%% 		lists:foldl(fun(GoodsInfo, AccIn) ->
%% 							lib_box:handle_each_box_goods(State#box_status.ets_box_goods_type, 
%% 														  PlayerId, PlayerName, HoleType, 
%% 														  GoodsInfo, AccIn)
%% 					end, {[], ""}, GoodsList),
%% 	case length(CastListStr) == 0 of
%% 		false ->
%% 			erlang:spawn(lib_box, handle_box_system_msg, 
%% 						 [Realm, HoleType, PlayerId, PlayerName, PlayerLevel, CastListStr, BroadCastGoodsList]);
%% 		true ->
%% 			no_action
%% 	end,
%% 	{noreply, State};
%%开宝箱
%% handle_cast({'open_box', PlayerId, Gold, GoodsPid, PlayerPid, Career, HoleType, OpenType, ProList}, State) ->
%% 	lib_box:open_box(State#box_status.ets_box_goods_type, 
%% 					 PlayerId, Gold, GoodsPid, PlayerPid, 
%% 					 Career, HoleType, OpenType, ProList),
%% 	{noreply, State};


%% handle_cast({'send_to_local_all', Data, BroadCastGoodsList}, State) ->
%% 	lists:foreach(fun lib_box:lib_box_goods_log_local/1, BroadCastGoodsList),
%% 	lib_send:send_to_local_all(Data),
%% 	{noreply, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_info({event, mod_box_update_action}, State) ->
	%% ?DEBUG("MOD_BOX_UPDATE_ACTION--->NOW",[]),
	NewState = lib_box:mod_box_handle_update_action(0, State),
	erlang:send_after(?TIMESTAMP, self(), {event, mod_box_update_action}),
	{noreply, NewState};
	
handle_info(_Info, State) ->		
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, _State) ->
	misc:delete_monitor_pid(self()),
	misc:delete_system_info(self()),
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% --------------------------------------------------------------------
%%% API functions
%% --------------------------------------------------------------------


%% -----------------------------------------------------------------
%% 28002 开宝箱
%% -----------------------------------------------------------------
open_box(Status, GoodsTraceInit, OpenCounter, PlayerPurpleNum, PurpleTimeType, HoleType, OpenType, PurpleEList, Proto) ->
	%% ?DEBUG("**************** open_box 28002 *********************",[]),
%% 	ProList = get_box_pro_list(Status#player.career, HoleType),	
	[Gold, _Cash] = db_agent:query_player_money(Status#player.id),
	try
		case gen_server:call(?MODULE,
							 {'open_box_call',
							  Status#player.id, Gold,
							  Status#player.other#player_other.pid_goods,
							  Status#player.other#player_other.pid, 
							  Status#player.career,
							  GoodsTraceInit, OpenCounter, PlayerPurpleNum, PurpleTimeType, HoleType, OpenType, PurpleEList, Proto}) of
			error ->
				%% ?DEBUG("28002 open_box error", []),
				[fail, {0, 0, [], HoleType}];
			Data ->
				Data
		end
	catch 
		_:_Reason ->
			?WARNING_MSG("28002 open_box fail for the reason:[~p]", [_Reason]),
			[fail, {0, 0, [], HoleType}]
	end.

%% -----------------------------------------------------------------
%% 28003 获取诛邪仓库数据
%% -----------------------------------------------------------------
get_warehouse(Status) ->
	%% ?DEBUG("**************** get_warehouse 28003 *********************",[]),
	try
		case gen_server:call(Status#player.other#player_other.pid_goods, 
							 {'get_box_goods', Status#player.id})of
			[] -> 
				%% ?DEBUG("28003 get_warehouse []", []),
				[[]];
		BoxGoodsList ->
%% 			Result = lists:map(fun lib_box:handle_warehouse/1, BoxGoodsList),
%% 			Len = length(Result),
%% 			[Len, Result]
			[BoxGoodsList]
		end
	catch
		_:_Reason -> 
			?WARNING_MSG("28003 get_warehouse fail for the reason:[~p]", [_Reason]),
			[[]]
	end.

%% -----------------------------------------------------------------
%% 28004 将物品放入背包
%% -----------------------------------------------------------------
put_goods_into_bag(Status, [GoodsId, GoodsNum]) ->
		%% ?DEBUG("oh yeach put_goods_into_bag 28004 [~p,~p]",[GoodsId, GoodsNum]),
	try
		case gen_server:call(Status#player.other#player_other.pid_goods, 
							 {'goods_box_to_bag', Status#player.id, GoodsId, GoodsNum})of
			error -> 
				%% ?DEBUG("28004 put_goods_into_bag error", []),
				[0];
			Data ->
				%% ?DEBUG("28004 put_goods_into_bag result:[~p]", [Data]),
				Data
		end
	catch
		_:_Reason -> 
			?WARNING_MSG("28004 put_goods_into_bag fail for the reason:[~p]", [_Reason]),
			[0]
	end.

%% -----------------------------------------------------------------
%% 28005 将物品丢弃
%% -----------------------------------------------------------------
discard_box_goods(Status, GoodsId, GoodsNum) ->
	%% ?DEBUG("**************** discard_box_goods 28005 *********************",[]),
	try
		case gen_server:call(Status#player.other#player_other.pid_goods, 
							 {'delete_box_goods', Status#player.id, GoodsId, GoodsNum}) of 
			error -> 
				%% ?DEBUG("28005 discard_box_goods error", []),
				[0];
			Data ->
				%% ?DEBUG("28005 discard_box_goods result:[~p]", [Data]),
				Data
		end
	catch
		_:_Reason -> 
			?WARNING_MSG("28005 get_warehouse fail for the reason:[~p]", [_Reason]),
			[0]
	end.


%% -----------------------------------------------------------------
%% 28006 丢弃仓库中的所有物品
%% -----------------------------------------------------------------
discard_all_box_goods(Status) ->
	%% ?DEBUG("**************** discard_all_box_goods 28006 *********************",[]),
	try
		case gen_server:call(Status#player.other#player_other.pid_goods, 
							 {'delete_all_box_goods', Status#player.id}) of
			error -> 
				%% ?DEBUG("28006 discard_all_box_goods error", []),
				[0];
			Data ->
				%% ?DEBUG("28006 discard_all_box_goods result:[~p]", [Data]),
				Data
		end
	catch
		_:_Reason -> 
			?WARNING_MSG("28006 discard_all_box_goods fail for the reason:[~p]", [_Reason]),
			[0]
	end.

%% -----------------------------------------------------------------
%% 28007 将所有物品放入背包
%% -----------------------------------------------------------------
put_all_goods_into_bag(Status) ->
	%% ?DEBUG("**************** put_all_goods_into_bag 28007 *********************",[]),
	try
		case gen_server:call(Status#player.other#player_other.pid_goods, 
							 {'all_goods_box_to_bag', Status#player.id}) of
			error -> 
				%% ?DEBUG("28007 put_all_goods_into_bag error", []),
				[0];
			Data ->
				%% ?DEBUG("28007 put_all_goods_into_bag result:[~p]", [Data]),
				Data
		end
	catch
		_:_Reason -> 
			?WARNING_MSG("28007 put_all_goods_into_bag fail for the reason:[~p]", [_Reason]),
			[0]
	end.

%% -----------------------------------------------------------------
%% 28008 获取仓库的容量
%% -----------------------------------------------------------------
get_box_remain_cells(Status) ->
	%% ?DEBUG("**************** get_box_remain_cells 28008 *********************",[]),
	try
		case gen_server:call(Status#player.other#player_other.pid_goods, 
							 {'get_box_storage'}) of
			error -> 
				%% ?DEBUG("28008 get_box_remain_cells error", []),
				[0];
			Data ->
				%% ?DEBUG("28008 get_box_remain_cells result:[~p]", [Data]),
				[Data]
		end
	catch
		_:_Reason -> 
			?WARNING_MSG("28008 get_box_remain_cells fail for the reason:[~p]", [_Reason]),
			[0]
	end.
%%进入秘境钱的去向判断
box_enter_scene(Player) ->
	BoxScene = lib_box_scene:get_box_scene(Player#player.id),
	if
		BoxScene#ets_box_scene.goods_id =:= 28031 ->%%新的秘境场景
			mod_boxs_piece:start_boxs_piece(Player);
		true ->%%一般的秘境场景
			mod_box_scene:build_box_scene(Player, BoxScene)
	end.
