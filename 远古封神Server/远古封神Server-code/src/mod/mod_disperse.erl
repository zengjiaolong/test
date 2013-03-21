%%%------------------------------------
%%% @Module  : mod_disperse
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 游戏服务器路由器
%%%------------------------------------
-module(mod_disperse).
-behaviour(gen_server).
-export([
            start_link/3,
            rpc_server_add/4,
            rpc_server_update/2,
			rpc_server_update_sc/1,
            server_id/0,
            server_list/0,
            send_to_all/1,
            broadcast_to_world/2,
			broadcast_to_realm/3,
			boradcast_box_goods_msg/3,
			get_server_list/0,
			stop_game_server/1,
			stop_server_access/1,
			stop_server_access_self/1,
			load_base_data/2,
			reload_base_data/2,
			online_state/0,
			get_system_load/0,
			dsp_node_status/1,
			sc_status/0,
			scene_online_num/0,
			get_nodes_cmq/1,
			get_process_info/1,
			send_mail_goods/1,	%%发系统特殊物品
			get_scene_and_online_sum/0,
			broadcast_to_ms/3,
			get_ets_info_fields/3
        ]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-define(TIMER,1000 * 5).
-record(state, {
        id,
        ip,
        port,
        node,
		stop_access = 0
    }
).

%% ====================================================================
%% 对外函数
%% ====================================================================

%% 查询当前战区ID号
%% 返回:int()
server_id() ->
    gen_server:call(?MODULE, get_server_id).

%% 获取所有战区的列表(不包括当前战区)
%% 返回:[#server{} | ...]
server_list() ->
    ets:tab2list(?ETS_SERVER).

%% 接收其它战区的加入信息
rpc_server_add(Id, Node, Ip, Port) ->
	gen_server:cast(?MODULE, {rpc_server_add, Id, Node, Ip, Port}).

%% 接收其它战区的状态更新信息
rpc_server_update(Id, Num) ->
	gen_server:cast(?MODULE, {rpc_server_update, Id, Num}).

rpc_server_update_sc(Id) ->
	gen_server:cast(?MODULE, {rpc_server_update_sc, Id}).

stop_server_access(Val) ->
	lists:foreach(fun(N)->rpc:cast(N, mod_disperse, stop_server_access_self, [Val]) end,nodes()).

stop_server_access_self(Val) ->
	gen_server:cast(?MODULE, {stop_server_access, Val}).

%%发系统特殊物品
send_mail_goods(Data) ->
	gen_server:cast(?MODULE, {send_mail_goods, Data}).

%% 广播到所有线路
send_to_all(Data) ->
    Servers = server_list(),
    broadcast_to_world(Servers, Data).

start_link(Ip, Port, Node_id) ->
    gen_server:start_link({local,?MODULE}, ?MODULE, [Ip, Port, Node_id], []).

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([Ip, Port, Node_id]) ->
    net_kernel:monitor_nodes(true), 
	%% 服务器列表
    ets:new(?ETS_SERVER, [{keypos, #server.id}, named_table, public, set,?ETSRC, ?ETSWC]),
    State = #state{id = Node_id, ip = Ip, port = Port, node = node(), stop_access = 0},
    add_server_db([State#state.ip, State#state.port, State#state.id, State#state.node]),
	%% 存储连接的服务器
	ets:new(?ETS_GET_SERVER,[named_table,public,set,?ETSRC, ?ETSWC]),	
	erlang:send_after(100, self(), {event, get_and_call_server}),
	misc:write_monitor_pid(self(),?MODULE, {}),
	%%获取系统负载
	erlang:send_after(1000, self(), {fetch_node_load}),
    {ok, State}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%% 新线加入
handle_cast({rpc_server_add, Id, Node, Ip, Port}, State) ->
    case Id of
        0 -> skip;
        _ ->
            ets:insert(?ETS_SERVER, #server{id = Id, node = Node, ip = Ip, port = Port, stop_access = 0})
    end,
    {noreply, State};

%% 根据本节点信息，更新本节点服务状态，并广播给其它节点
handle_cast({stop_server_access, Val}, State) ->
io:format("stop_server_access__/~p/~n",[[Val, State#state.node, State#state.ip]]),
	[ValAtom, ValStr] =
		case Val of
			_ when is_atom(Val) ->
				[Val, tool:to_list(Val)];
			_ when is_list(Val) ->
				[tool:to_atom(Val), Val];
			_ ->
				[Val, Val]
		end,
	if
		State#state.node =:= ValAtom orelse State#state.ip =:= ValStr ->
			Num = ets:info(?ETS_ONLINE, size),
            NewServer =
                #server{
                    id = State#state.id,
                    node = State#state.node,
                    ip = State#state.ip,
                    port = State#state.port,
                    num = Num,
					stop_access = 1
                },
			ets:insert(?ETS_SERVER,	NewServer),
            broadcast_server_state_sc(State#state.id),
			{noreply, State#state{stop_access = 1}};
		true ->
			{noreply, State}
	end;

%% 其它线人数更新
handle_cast({rpc_server_update, Id, Num} , State) ->
    case ets:lookup(?ETS_SERVER, Id) of
        [S] -> ets:insert(?ETS_SERVER, S#server{num = Num});
        _ -> skip
    end,
    {noreply, State};

%% 其它线状态更新
handle_cast({rpc_server_update_sc, Id} , State) ->
    case ets:lookup(?ETS_SERVER, Id) of
        [S] -> ets:insert(?ETS_SERVER, S#server{stop_access = 1});
        _ -> skip
    end,
    {noreply, State};

%%发系统特殊物品
handle_cast({send_mail_goods, Data}, State) ->
	{NameList, Title, Content, GoodsTypeId, Coin, Gold, Bind, GoodsStren, Trade} = Data,
	lib_mail_goods:stren_mail_goods(NameList, Title, Content, GoodsTypeId, Coin, Gold, Bind, GoodsStren, Trade),
	{noreply, State};

handle_cast(_R , State) ->
    {noreply, State}.

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
%% 获取战区ID号 
handle_call(get_server_id, _From, State) ->
    {reply, State#state.id, State};

%% 获取服务器列表
handle_call('get_server_list',_From,State) ->
	{reply,ok,State};

handle_call(_R , _FROM, State) ->
    {reply, ok, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%% 获取并通知当前所有线路
handle_info({event, get_and_call_server}, State) ->
	get_and_call_server(State),
	{noreply, State};

%% 统计当前线路人数并广播给其它线路
handle_info(online_num_update, State) ->
    case State#state.id of
        0 -> skip;
        _ ->
            Num = ets:info(?ETS_ONLINE, size),
            ets:insert(?ETS_SERVER,
                #server{
                    id = State#state.id,
                    node = State#state.node,
                    ip = State#state.ip,
                    port = State#state.port,
                    num = Num
                }
            ),
            Servers = server_list(),
            broadcast_server_state(Servers, State#state.id, Num)
    end,
    {noreply, State};

%% 获取最低负载节点
handle_info({fetch_node_load},State) ->
	if
		State#state.id == 0 ->
			List =
    		case server_list() of
        		[] -> [];
        		Server ->
            		F = fun(S) ->
                    		[State0, Num, System_Status] =
								case S#server.stop_access of
									1 ->
										[4, 0, 9999999999];
									_ ->
										case rpc:call(S#server.node, mod_disperse, online_state, []) of
                                				{badrpc, _} ->	
                                    				[4, 0, 9999999999];
                                				Ret ->
                                    				Ret
                            			end
								end,
                    		[S#server.id, S#server.ip, S#server.port, State0, Num, System_Status]
                		end,
            		[F(S) || S <- Server]
    		end,
			Server_member_list = lists:map(fun([_, _, _, _, Num, _]) -> Num end, List),
			Online_count = lists:sum(Server_member_list),
			List1 = lists:filter(fun([_,_,_,_,_,S1])-> S1 < 900000000 end, List),
			Low = find_game_server_minimum(List1, Online_count),
			case length(Low) > 0 of
				true ->
					ets:insert(?ETS_GET_SERVER, {get_list,Low});
				false ->
					skip
			end;
		true ->
			skip
	end,
	erlang:send_after(?TIMER, self(), {fetch_node_load}),
	{noreply,State};
	
%% 处理新节点加入事件
handle_info({nodeup, Node}, State) ->
    try
        rpc:cast(Node, mod_disperse, rpc_server_add, 
				 [State#state.id, State#state.node, State#state.ip, State#state.port]),
		ok
    catch
        _:_ -> 
			skip
    end,
    {noreply, State};

%% 处理节点关闭事件
handle_info({nodedown, Node}, State) ->
    %% 检查是否战区节点，并做相应处理
    case ets:match_object(?ETS_SERVER, #server{node = Node, _ = '_'}) of
        [_Z] ->
            ets:match_delete(?ETS_SERVER, #server{node = Node, _ = '_'});
        _ ->
            skip
    end,
    {noreply, State};

handle_info(_Reason, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_R, State) ->
	misc:delete_monitor_pid(self()),
    {ok, State}.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra)->
    {ok, State}.


%% ----------------------- 私有函数 ---------------------------------

%% 广播到其它节点的世界频道
broadcast_to_world([], _Data) -> ok;
broadcast_to_world([H | T], Data) ->
    rpc:cast(H#server.node, lib_send, send_to_local_all, [Data]),
	broadcast_to_world(T, Data).

%% 广播制定选择条件
broadcast_to_ms([], _BinData, _MS) -> ok;
broadcast_to_ms([H | T], BinData, MS) ->
    rpc:cast(H#server.node, lib_send, send_to_ms, [BinData, MS]),
    broadcast_to_ms(T, BinData, MS).

%% 广播到其它节点的部落频道
broadcast_to_realm([], _Realm, _Data) -> ok;
broadcast_to_realm([H | T], Realm, Data) ->
    rpc:cast(H#server.node, lib_send, send_to_local_realm, [Realm, Data]),
    broadcast_to_realm(T, Realm, Data).

%% 广播当前在线给其它线
broadcast_server_state([], _Id, _Num) -> ok;
broadcast_server_state([H | T], Id, Num) ->
    rpc:cast(H#server.node, mod_disperse, rpc_server_update, [Id, Num]),
    broadcast_server_state(T, Id, Num).

%% 广播当前在线给其它线
broadcast_server_state_sc(Id) ->
	lists:foreach(fun(N)->rpc:cast(N,mod_disperse,rpc_server_update_sc,[Id]) end,nodes()).

%%广播诛邪的系统公告
boradcast_box_goods_msg([], _Data, _BroadCastGoodsList) -> ok;
boradcast_box_goods_msg([H | T], Data, BroadCastGoodsList) ->
	rpc:cast(H#server.node, mod_box_log, broadcast_box_to_local_all, [Data, BroadCastGoodsList]),
	boradcast_box_goods_msg(T, Data, BroadCastGoodsList).

%%加入服务器集群
add_server_db([Ip, Port, Sid, Node]) ->
    db_agent:add_server([Ip, Port, Sid, Node]).

%% 安全退出游戏服务器集群
stop_game_server([]) -> ok;
stop_game_server([H | T]) ->
%%     rpc:cast(H#server.node, mod_login, stop_all, []),
	rpc:cast(H#server.node, yg, server_stop, []),
	stop_game_server(T).

%% 请求节点加载基础数据
load_base_data([], _Parm) -> ok;
load_base_data([H | T], Parm) ->
	rpc:cast(H#server.node, mod_kernel, load_base_data, Parm),
	load_base_data(T, Parm).

%% 重新加载基础数据
reload_base_data([], _Parm) -> ok;
reload_base_data([H | T], Parm) ->
	rpc:cast(H#server.node, mod_kernel, reload_base_data, Parm),
	reload_base_data(T, Parm).

  %%退出服务器集群
del_server_db(Sid) ->
    db_agent:del_server(Sid).

%%获取并通知所有线路信息
get_and_call_server(State) ->
    case db_agent:select_all_server() of
        [] ->
            [];
        Server ->
            F = fun([Id, Ip, Port, Node, _, _]) ->
                    Node1 = list_to_atom(binary_to_list(Node)),
                    Ip1 = binary_to_list(Ip),
                    case Id /= State#state.id of  % 自己不写入和不通知
                        true ->
                            case net_adm:ping(Node1) of
                                pong ->
                                    case Id /= 0 of
                                        true ->
                                            ets:insert(?ETS_SERVER,
                                                #server{
                                                    id = Id,
                                                    node = Node1,
                                                    ip = Ip1,
                                                    port = Port
                                                }
                                            );
                                        false ->
                                            ok
                                    end,
                                     %% 通知已有的线路加入当前线路的节点，包括线路0网关 
									try
                                    	rpc:cast(Node1, mod_disperse, rpc_server_add, [State#state.id, State#state.node, State#state.ip, State#state.port])
									catch
										_:_ -> error
									end;
                                pang ->
                                    del_server_db(Id)
                            end;
                        false ->
                            ok
                    end
                end,
            [F(S) || S <- Server]
    end.


%% 获取服务器列表
get_server_list() ->
	case ets:match(?ETS_GET_SERVER,{get_list,'$1'}) of
		[LS] ->
%% io:format("get_server_list__/~p/~n",[LS]),	
			case length(LS) > 0 of
				true ->hd(LS);
				false ->LS
			end;
		[] -> []
	end.


find_game_server_minimum(L, Online_count) ->
%% io:format("Online_count__/~p/~n",[[L, Online_count]]),	
	if length(L) == 0 -> [];
	   true -> 
		   NL = lists:sort(fun([_,_,_,_,_,S1],[_,_,_,_,_,S2]) -> S1 < S2 end, L),
		   [[Id, Ip, Port, State, _Num, System_Status]|_] = NL,
		   [[Id, Ip, Port, State, Online_count, System_Status]]
    end.

%% 在线状况
online_state() ->
	System_load = get_system_load(),
    case ets:info(?ETS_ONLINE, size) of
        undefined ->
            [0, 0, 0];
        Num when Num < 200 -> %顺畅
            [1, Num, System_load];
        Num when Num > 200 , Num < 500 -> %正常
            [2, Num, System_load];
        Num when Num > 500 , Num < 800 -> %繁忙
            [3, Num, System_load];
        Num when Num > 800 -> %爆满
            [4, Num, System_load]
    end.

% 场景人数
scene_online_num()->
	BaseScenes = ets:tab2list(?ETS_BASE_SCENE),
	F = fun(Sinfo,SceneInfoList) ->
				SceneInfo = lib_scene:get_scene_user(Sinfo#ets_scene.sid),
				[{Sinfo#ets_scene.sid,Sinfo#ets_scene.name,length(SceneInfo)}|SceneInfoList]
		end,
	lists:foldl(F, [], BaseScenes).

%% 获取系统负载
get_system_load() ->
	Load_fact = 10,  %% 全局进程负载权重
	Load_fact_more = 20,  %% 全局进程负载权重2
	If_mod_guild =	
		    case ets:match(?ETS_MONITOR_PID,{'$1', mod_guild ,'$3'}) of
				[[_GuildPid, _]] -> Load_fact;
				_ -> 0									
			end,	

	If_mod_sale =	
		    case ets:match(?ETS_MONITOR_PID,{'$1', mod_sale ,'$3'}) of
				[[_SalePid, _]] -> Load_fact;
				_ -> 0
			end,

	If_mod_rank =	
		    case ets:match(?ETS_MONITOR_PID,{'$1', mod_rank ,'$3'}) of
				[[_RankPid, _]] -> Load_fact;
				_ -> 0
			end,

	If_mod_delayer =	
		    case ets:match(?ETS_MONITOR_PID,{'$1', mod_delayer ,'$3'}) of
				[[_delayerPid, _]] -> Load_fact;
				_ -> 0
			end,	
	
	If_mod_master_apprentice = 
		    case ets:match(?ETS_MONITOR_PID,{'$1', mod_master_apprentice ,'$3'}) of
				[[_MasterPid, _]] -> Load_fact;
				_ -> 0
			end,

	If_mod_shop = 
		    case ets:match(?ETS_MONITOR_PID,{'$1', mod_shop ,'$3'}) of
				[[_ShopPid, _]] -> Load_fact;
				_ -> 0
			end,	
	
	If_mod_kernel = 
		    case ets:match(?ETS_MONITOR_PID,{'$1', mod_kernel ,'$3'}) of
				[[_KernelPid, {Val}]] -> Val;
				_ -> 0
			end,
	
	If_mod_analytics = 
		    case ets:match(?ETS_MONITOR_PID,{'$1', dungeon_analytics ,'$3'}) of
				[[_AnalyticsPid, _]] -> Load_fact;
				_ -> 0
			end,	

	If_mod_vip = 
		    case ets:match(?ETS_MONITOR_PID,{'$1', vip ,'$3'}) of
				[[_VipPid, _]] -> Load_fact;
				_ -> 0
			end,
	
	If_mod_consign = 
		    case ets:match(?ETS_MONITOR_PID,{'$1', consign ,'$3'}) of
				[[_CconsignPid, _]] -> Load_fact;
				_ -> 0
			end,

	If_mod_carry = 
		    case ets:match(?ETS_MONITOR_PID,{'$1', carry ,'$3'}) of
				[[_CcarryPid, _]] -> Load_fact_more;
				_ -> 0
			end,	

	If_mod_arena = 
		    case ets:match(?ETS_MONITOR_PID,{'$1', arena ,'$3'}) of
				[[_AarenaPid, _]] -> Load_fact_more;
				_ -> 0
			end,
	
	If_mod_ore_sup = 
		    case ets:match(?ETS_MONITOR_PID,{'$1', ore_sup ,'$3'}) of
				[[_Oore_supPid, _]] -> Load_fact_more;
				_ -> 0
			end,
	
	If_mod_answer = 
		    case ets:match(?ETS_MONITOR_PID,{'$1', answer ,'$3'}) of
				[[_AanswerPid, _]] -> Load_fact;
				_ -> 0
			end,
	
	ScenePlayerCount = ets:info(?ETS_ONLINE_SCENE, size),
	ConnectionCount = ets:info(?ETS_ONLINE, size),
	
	Mod_load = If_mod_guild + If_mod_sale + If_mod_rank + If_mod_delayer + If_mod_master_apprentice + If_mod_shop + If_mod_kernel + If_mod_analytics  + If_mod_vip + If_mod_consign + If_mod_carry + If_mod_arena + If_mod_ore_sup + If_mod_answer,
%% 	yg_timer:cpu_time() + Mod_load + ScenePlayerCount/100.
	yg_timer:cpu_time() + Mod_load + ScenePlayerCount/5 + ConnectionCount/10.

dsp_node_status(NodeName) ->
	io:format("~p :::: CpuTime:~p ScenePlayerCount:~p Connections:~p ~n",
					[NodeName, yg_timer:cpu_time(), ets:info(?ETS_ONLINE_SCENE, size), ets:info(?ETS_ONLINE, size)]).

sc_status() ->
   	case server_list() of
        [] -> [];
        Server ->
            F = fun(S) ->
					case S#server.stop_access of
						1 ->
							io:format("~p ::: Stop Access. ~n", [S#server.node]);
						_ ->
							io:format("~p ::: Could Access..... ~n", [S#server.node])
					end
              end,
            [F(S) || S <- Server]
    end.

get_nodes_cmq(Type)->
	A = lists:foldl( 
		  fun(P, Acc0) -> 
				 case Type of
					 1 ->
						[{P, 
						  	erlang:process_info(P, registered_name), 
							erlang:process_info(P, reductions) }
						| Acc0] ;
					 2 ->
						 [{P,
							erlang:process_info(P, registered_name), 
							erlang:process_info(P, memory)}
						| Acc0] ;
					 3 ->
						 [{P, 
							erlang:process_info(P, registered_name), 
							erlang:process_info(P, message_queue_len)} 
						| Acc0] 
				 end
			end, 
		  [], 
		  erlang:processes()
		),
	F = fun({_,_,R1},{_,_,R2}) ->
				if R1 =/= undefined andalso R2 =/= undefined ->
					   {_,N1} = R1,{_,N2} = R2,
					   N1 > N2;
				   true ->
					   false
				end
		end,
	B = lists:sort(F,A),
	B.

%%本节点尝试解析获取进程信息
get_process_info(Pid_list) ->
	try
		Pid = list_to_pid(Pid_list),
		Pinfo = process_info(Pid),
		%%file:write_file("info.txt", io_lib:format("~p", Pinfo)),
		Pinfo
	catch
		_:E ->
			E
	end.


get_scene_and_online_sum() ->
	case ets:info(?ETS_MONITOR_PID) of
				undefined ->
					[];
				_ ->
					Stat_list_scene = ets:match(?ETS_MONITOR_PID,{'$1', mod_scene ,'$3'}),
					lists:map( 
	  					fun(Stat_data) ->
							case Stat_data of				
								[_SceneAgentPid, {SceneId, _Worker_Number}] ->
									MS = ets:fun2ms(fun(T) when T#player.scene == SceneId  -> 
												[T#player.id] 
												end),
									Players = ets:select(?ETS_ONLINE_SCENE, MS),
									{SceneId,length(Players)};
								_->
									[]
							end 
	  					end, 
						Stat_list_scene)
			end.

get_ets_info(Tab, Id) ->
    L = case is_integer(Id) of
            true -> ets:lookup(Tab, Id);
            false -> ets:match_object(Tab, Id)
        end,
    case L of
        [Info|_] -> Info;
        _ -> {}
    end.

get_ets_info_fields(Tab,Id,FieldList) ->
	Info = get_ets_info(Tab, Id),
	if Info == {} ->
		   ets_empty;
	   true ->
		   ValueList = lists:nthtail(1, tuple_to_list(Info)),
		   NewFieldList = record_info_list(Info),		
		   F = fun(Field) ->
					   Pos = get_pos(Field,NewFieldList),
					   if Pos == 0 ->
							  [];
						  true ->
							  lists:nth(Pos, ValueList)
					   end
			   end,
		   [F(Field) || Field <- FieldList]
	end.

get_pos(Field,FieldList) ->
	if length(FieldList) == 0 ->
		   0;
	   true ->
		   Result = [Order || Order <- lists:seq(1, length(FieldList)),lists:nth(Order, FieldList) == Field],
		   if Result == [] ->
				  0;
			  true ->
				  [Pos|_] = Result,
				  Pos
		   end
	end.
		   
record_info_list(Info) ->
	%%table_to_record record
	if is_record(Info,server) -> NewFieldList = record_info(fields, server);
	   is_record(Info,player)  -> NewFieldList = record_info(fields, player);
	   is_record(Info,goods) -> NewFieldList = record_info(fields, goods);
	   is_record(Info,goods_attribute) -> NewFieldList = record_info(fields, goods_attribute);
	   is_record(Info,goods_buff) -> NewFieldList = record_info(fields, goods_buff);
	   is_record(Info,ets_goods_cd) -> NewFieldList = record_info(fields, ets_goods_cd);
	   is_record(Info,ets_deputy_equip) -> NewFieldList = record_info(fields, ets_deputy_equip);
	   is_record(Info,ets_base_answer) -> NewFieldList = record_info(fields, ets_base_answer);
	   is_record(Info,ets_base_career) -> NewFieldList = record_info(fields, ets_base_career);
	   is_record(Info,ets_base_culture_state) -> NewFieldList = record_info(fields, ets_base_culture_state);
	   is_record(Info,ets_scene) -> NewFieldList = record_info(fields, ets_scene);
	   is_record(Info,ets_mon) -> NewFieldList = record_info(fields, ets_mon);
	   is_record(Info,ets_npc) -> NewFieldList = record_info(fields, ets_npc);
	   is_record(Info,ets_base_goods) -> NewFieldList = record_info(fields, ets_base_goods);
	   is_record(Info,ets_base_goods_add_attribute) -> NewFieldList = record_info(fields, ets_base_goods_add_attribute);
	   is_record(Info,ets_base_goods_suit_attribute) -> NewFieldList = record_info(fields, ets_base_goods_suit_attribute);
	   is_record(Info,ets_base_goods_suit) -> NewFieldList = record_info(fields, ets_base_goods_suit);
	   is_record(Info,ets_base_goods_strengthen) -> NewFieldList = record_info(fields, ets_base_goods_strengthen);
	   is_record(Info,ets_base_goods_strengthen_anti) -> NewFieldList = record_info(fields, ets_base_goods_strengthen_anti);
	   is_record(Info,ets_base_goods_strengthen_extra) -> NewFieldList = record_info(fields, ets_base_goods_strengthen_extra);
	   is_record(Info,ets_base_goods_practise) -> NewFieldList = record_info(fields, ets_base_goods_practise);
	   is_record(Info,ets_base_goods_compose) -> NewFieldList = record_info(fields, ets_base_goods_compose);
	   is_record(Info,ets_base_goods_inlay) -> NewFieldList = record_info(fields, ets_base_goods_inlay);
	   is_record(Info,ets_base_goods_idecompose) -> NewFieldList = record_info(fields, ets_base_goods_idecompose);
	   is_record(Info,ets_base_goods_icompose) -> NewFieldList = record_info(fields, ets_base_goods_icompose);
	   is_record(Info,ets_base_goods_drop_num) -> NewFieldList = record_info(fields, ets_base_goods_drop_num);
	   is_record(Info,ets_base_goods_drop_rule) -> NewFieldList = record_info(fields, ets_base_goods_drop_rule);
	   is_record(Info,ets_base_goods_ore) -> NewFieldList = record_info(fields, ets_base_goods_ore);
	   is_record(Info,ets_shop) -> NewFieldList = record_info(fields, ets_shop);
	   is_record(Info,talk) -> NewFieldList = record_info(fields, talk);
	   is_record(Info,task) -> NewFieldList = record_info(fields, task);
	   is_record(Info,role_task) -> NewFieldList = record_info(fields, role_task);
	   is_record(Info,role_task_log) -> NewFieldList = record_info(fields, role_task_log);
	   is_record(Info,ets_skill) -> NewFieldList = record_info(fields, ets_skill);
       is_record(Info,ets_guild) -> NewFieldList = record_info(fields, ets_guild);
	   is_record(Info,ets_guild_member) -> NewFieldList = record_info(fields, ets_guild_member);
	   is_record(Info,ets_guild_apply) -> NewFieldList = record_info(fields, ets_guild_apply);
	   is_record(Info,ets_insert_guild_member) -> NewFieldList = record_info(fields, ets_insert_guild_member);
	   is_record(Info,ets_insert_guild_apply) -> NewFieldList = record_info(fields, ets_insert_guild_apply);
	   is_record(Info,ets_guild_invite) -> NewFieldList = record_info(fields, ets_guild_invite);
	   is_record(Info,ets_guild_skills_attribute) -> NewFieldList = record_info(fields, ets_guild_skills_attribute);
	   is_record(Info,ets_log_guild) -> NewFieldList = record_info(fields, ets_log_guild);
	   is_record(Info,ets_log_warehouse_flowdir) -> NewFieldList = record_info(fields, ets_log_warehouse_flowdir);
	   is_record(Info,ets_base_pet) -> NewFieldList = record_info(fields, ets_base_pet);
	   is_record(Info,ets_pet) -> NewFieldList = record_info(fields, ets_pet);
	   is_record(Info,dungeon) -> NewFieldList = record_info(fields, dungeon);
	   is_record(Info,ets_dungeon) -> NewFieldList = record_info(fields, ets_dungeon);
	   is_record(Info,ets_master_apprentice) -> NewFieldList = record_info(fields, ets_master_apprentice);
	   is_record(Info,ets_master_charts) -> NewFieldList = record_info(fields, ets_master_charts);
	   is_record(Info,ets_meridian) -> NewFieldList = record_info(fields, ets_meridian);
	   is_record(Info,ets_base_meridian) -> NewFieldList = record_info(fields, ets_base_meridian);
	   is_record(Info,ets_log_sale_dir) -> NewFieldList = record_info(fields, ets_log_sale_dir);
	   is_record(Info,ets_online_gift) -> NewFieldList = record_info(fields, ets_online_gift);
	   is_record(Info,ets_base_online_gift) -> NewFieldList = record_info(fields, ets_base_online_gift);
	   is_record(Info,ets_carry_time) -> NewFieldList = record_info(fields, ets_carry_time);
	   is_record(Info,ets_base_map) -> NewFieldList = record_info(fields, ets_base_map);
	   is_record(Info,ets_base_box_goods) -> NewFieldList = record_info(fields, ets_base_box_goods);
	   is_record(Info,ets_log_box_open) -> NewFieldList = record_info(fields, ets_log_box_open);
	   is_record(Info,ets_log_box_player) -> NewFieldList = record_info(fields, ets_log_box_player);
	   is_record(Info,ets_box_scene) -> NewFieldList = record_info(fields, ets_box_scene);
	   is_record(Info,feedback) -> NewFieldList = record_info(fields, feedback);
	   is_record(Info,ets_base_target_gift) -> NewFieldList = record_info(fields, ets_base_target_gift);
	   is_record(Info,ets_target_gift) -> NewFieldList = record_info(fields, ets_target_gift);
	   is_record(Info,ets_task_consign) -> NewFieldList = record_info(fields, ets_task_consign);
	   is_record(Info,player_sys_setting) -> NewFieldList = record_info(fields, player_sys_setting);
	   is_record(Info,ets_arena) -> NewFieldList = record_info(fields, ets_arena);
	   is_record(Info,ets_arena_week) -> NewFieldList = record_info(fields, ets_arena_week);
	   is_record(Info,ets_consign_task) -> NewFieldList = record_info(fields, ets_consign_task);
	   is_record(Info,ets_consign_player) -> NewFieldList = record_info(fields, ets_consign_player);
	   is_record(Info,ets_carry) -> NewFieldList = record_info(fields, ets_carry);
	   is_record(Info,ets_offline_award) -> NewFieldList = record_info(fields, ets_offline_award);
	   is_record(Info,ets_online_award) -> NewFieldList = record_info(fields, ets_online_award);
	   is_record(Info,ets_business) -> NewFieldList = record_info(fields, ets_business);
	   is_record(Info,ets_log_robbed) -> NewFieldList = record_info(fields, ets_log_robbed);
	   is_record(Info,ets_base_business) -> NewFieldList = record_info(fields, ets_base_business);
	   is_record(Info,ets_online_award_holiday) -> NewFieldList = record_info(fields, ets_online_award_holiday);
	   is_record(Info,ets_hero_card) -> NewFieldList = record_info(fields, ets_hero_card);
	   is_record(Info,ets_base_hero_card) -> NewFieldList = record_info(fields, ets_base_hero_card);
	   is_record(Info,ets_love) -> NewFieldList = record_info(fields, ets_love);
	   is_record(Info,ets_base_privity) -> NewFieldList = record_info(fields, ets_base_privity);
	   is_record(Info,ets_base_goods_fashion) -> NewFieldList = record_info(fields, ets_base_goods_fashion);
	   is_record(Info,ets_luckydraw) -> NewFieldList = record_info(fields, ets_luckydraw);
	   is_record(Info,ets_targetlead) -> NewFieldList = record_info(fields, ets_targetlead);
	   is_record(Info,ets_ach_stats) -> NewFieldList = record_info(fields, ets_ach_stats);
	   is_record(Info,ets_log_ach_f) -> NewFieldList = record_info(fields, ets_log_ach_f);
	   is_record(Info,ets_login_award) -> NewFieldList = record_info(fields, ets_login_award);
	   is_record(Info,ets_base_daily_gift) -> NewFieldList = record_info(fields, ets_base_daily_gift);
	   is_record(Info,ets_tower_award) -> NewFieldList = record_info(fields, ets_tower_award);
	   is_record(Info,ets_base_magic) -> NewFieldList = record_info(fields, ets_base_magic);
	   is_record(Info,ets_cycle_flush) -> NewFieldList = record_info(fields, ets_cycle_flush);
	   is_record(Info,ets_war_player) -> NewFieldList = record_info(fields, ets_war_player);
	   is_record(Info,ets_war_team) -> NewFieldList = record_info(fields, ets_war_team);
	   is_record(Info,ets_war_vs) -> NewFieldList = record_info(fields, ets_war_vs);
	   is_record(Info,ets_war_state) -> NewFieldList = record_info(fields, ets_war_state);
	   is_record(Info,ets_appraise) -> NewFieldList = record_info(fields, ets_appraise);
	   is_record(Info,ets_pet_buy) -> NewFieldList = record_info(fields, ets_pet_buy);
	   is_record(Info,ets_pet_split_skill) -> NewFieldList = record_info(fields, ets_pet_split_skill);
	   is_record(Info,ets_base_pet_skill_effect) -> NewFieldList = record_info(fields, ets_base_pet_skill_effect);
	   is_record(Info,guild_union) -> NewFieldList = record_info(fields, guild_union);
	   is_record(Info,ets_vip) -> NewFieldList = record_info(fields, ets_vip);
	   is_record(Info,ets_f5_gwish) -> NewFieldList = record_info(fields, ets_f5_gwish);
	   is_record(Info,ets_novice_gift) -> NewFieldList = record_info(fields, ets_novice_gift);
	   is_record(Info,ets_pet_extra) -> NewFieldList = record_info(fields, ets_pet_extra);
	   is_record(Info,ets_pet_extra_value) -> NewFieldList = record_info(fields, ets_pet_extra_value);
	   is_record(Info,ets_war_award) -> NewFieldList = record_info(fields, ets_war_award);
	   is_record(Info,ets_castle_rush_info) -> NewFieldList = record_info(fields, ets_castle_rush_info);
	   is_record(Info,ets_castle_rush_join) -> NewFieldList = record_info(fields, ets_castle_rush_join);
	   is_record(Info,ets_marry) -> NewFieldList = record_info(fields, ets_marry);
	   is_record(Info,ets_wedding) -> NewFieldList = record_info(fields, ets_wedding);
	   is_record(Info,ets_loveday) -> NewFieldList = record_info(fields, ets_loveday);
	   is_record(Info,ets_g_alliance) -> NewFieldList = record_info(fields, ets_g_alliance);
	   is_record(Info,ets_g_alliance_apply) -> NewFieldList = record_info(fields, ets_g_alliance_apply);
	   is_record(Info,ets_find_exp) -> NewFieldList = record_info(fields, ets_find_exp);
	   is_record(Info,ets_mount) -> NewFieldList = record_info(fields, ets_mount);
	   is_record(Info,ets_mount_skill_exp) -> NewFieldList = record_info(fields, ets_mount_skill_exp);
	   is_record(Info,ets_mount_skill_split) -> NewFieldList = record_info(fields, ets_mount_skill_split);
	   is_record(Info,log_buy_goods) -> NewFieldList = record_info(fields, log_buy_goods);
	   is_record(Info,ets_single_td_award) -> NewFieldList = record_info(fields, ets_single_td_award);
	   is_record(Info,ets_coliseum_rank) -> NewFieldList = record_info(fields, ets_coliseum_rank);
	   is_record(Info,ets_coliseum_info) -> NewFieldList = record_info(fields, ets_coliseum_info);
	   is_record(Info,ets_player_other) -> NewFieldList = record_info(fields, ets_player_other);
	   is_record(Info,ets_war2_record) -> NewFieldList = record_info(fields, ets_war2_record);
	   is_record(Info,ets_war2_elimination) -> NewFieldList = record_info(fields, ets_war2_elimination);
	   is_record(Info,ets_war2_history) -> NewFieldList = record_info(fields, ets_war2_history);
	   is_record(Info,ets_war2_bet) -> NewFieldList = record_info(fields, ets_war2_bet);
	   is_record(Info,ets_fs_era) -> NewFieldList = record_info(fields, ets_fs_era);
	   is_record(Info,ets_war2_pape) -> NewFieldList = record_info(fields, ets_war2_pape);
	   
	   
	   %%record.hrl record
	   is_record(Info,goods_cur_buff) -> NewFieldList = record_info(fields, goods_cur_buff);
	   is_record(Info,guild_h_skill) -> NewFieldList = record_info(fields, guild_h_skill);
	   is_record(Info,battle_dict) -> NewFieldList = record_info(fields, battle_dict);
	   is_record(Info,player_other) -> NewFieldList = record_info(fields, player_other);
	   is_record(Info,player_other) -> NewFieldList = record_info(fields, ets_goods_drop);
	   is_record(Info,ets_rank) -> NewFieldList = record_info(fields, ets_rank);
	   is_record(Info,goods_status) -> NewFieldList = record_info(fields, goods_status);
	   is_record(Info,team) -> NewFieldList = record_info(fields, team);
	   is_record(Info,mb) -> NewFieldList = record_info(fields, mb);
	   is_record(Info,ets_guild_upgrade_status) -> NewFieldList = record_info(fields, ets_guild_upgrade_status);
	   is_record(Info,box_status) -> NewFieldList = record_info(fields, box_status);
	   is_record(Info,ets_open_boxgoods_trace) -> NewFieldList = record_info(fields, ets_open_boxgoods_trace);
	   is_record(Info,collect_status) -> NewFieldList = record_info(fields, collect_status);
	   is_record(Info,ets_blacklist) -> NewFieldList = record_info(fields, ets_blacklist);
	   is_record(Info,ets_rela) -> NewFieldList = record_info(fields, ets_rela);
	   is_record(Info,ets_delayer) -> NewFieldList = record_info(fields, ets_delayer);
	   is_record(Info,ets_blackboard) -> NewFieldList = record_info(fields, ets_blackboard);
	   is_record(Info,ets_spar) -> NewFieldList = record_info(fields, ets_spar);
	   is_record(Info,ets_box_mon) -> NewFieldList = record_info(fields, ets_box_mon);
	   is_record(Info,answer_properties) -> NewFieldList = record_info(fields, answer_properties);
	   is_record(Info,ets_answer) -> NewFieldList = record_info(fields, ets_answer);
	   is_record(Info,ets_farm_info) -> NewFieldList = record_info(fields, ets_farm_info);
	   is_record(Info,ets_manor_enter) -> NewFieldList = record_info(fields, ets_manor_enter);
	   is_record(Info,ets_farm_info_back) -> NewFieldList = record_info(fields, ets_farm_info_back);
	   is_record(Info,ets_manor_steal) -> NewFieldList = record_info(fields, ets_manor_steal);
	   is_record(Info,ets_daily_online_award) -> NewFieldList = record_info(fields, ets_daily_online_award);
	   is_record(Info,ets_base_scene_unique_mon) -> NewFieldList = record_info(fields, ets_base_scene_unique_mon);
	   is_record(Info,ets_exp_activity) -> NewFieldList = record_info(fields, ets_exp_activity);
	   is_record(Info,hook_config) -> NewFieldList = record_info(fields, hook_config);
	   is_record(Info,ets_holiday_info) -> NewFieldList = record_info(fields, ets_holiday_info);
	   is_record(Info,ets_propose_info) -> NewFieldList = record_info(fields, ets_propose_info);
	   is_record(Info,ets_wedding_player) -> NewFieldList = record_info(fields, ets_wedding_player);
	   is_record(Info,ets_voters) -> NewFieldList = record_info(fields, ets_voters);
	   is_record(Info,player_state) -> NewFieldList = record_info(fields, player_state);
	   is_record(Info,ets_castle_rush_guild_score) -> NewFieldList = record_info(fields, ets_castle_rush_guild_score);
	   is_record(Info,ets_castle_rush_harm_score) -> NewFieldList = record_info(fields, ets_castle_rush_harm_score);
	   is_record(Info,ets_castle_rush_player_score) -> NewFieldList = record_info(fields, ets_castle_rush_player_score);
	   is_record(Info,ets_castle_rush_rank) -> NewFieldList = record_info(fields, ets_castle_rush_rank);
	   is_record(Info,ets_castle_rush_award_member) -> NewFieldList = record_info(fields, ets_castle_rush_award_member);
	   is_record(Info,ets_coliseum_data) -> NewFieldList = record_info(fields, ets_coliseum_data);
	   is_record(Info,raise_team) -> NewFieldList = record_info(fields, raise_team);
	   is_record(Info,raise_member) -> NewFieldList = record_info(fields, raise_member);
	   is_record(Info,ets_sale_goods) -> NewFieldList = record_info(fields, ets_sale_goods);
	   is_record(Info,ets_buy_goods) -> NewFieldList = record_info(fields, ets_buy_goods);
	   true ->
		   NewFieldList = []
	end,
	NewFieldList.

	   





