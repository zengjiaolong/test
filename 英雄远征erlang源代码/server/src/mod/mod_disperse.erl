%%%------------------------------------
%%% @Module  : mod_disperse
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.08.18
%%% @Description: 线路分布
%%%------------------------------------
-module(mod_disperse).
-behaviour(gen_server).
-export([
            start_link/3,
            rpc_server_add/4,
            rpc_server_update/2,
            server_id/0,
            server_list/0,
            send_to_all/1,
            broadcast_to_world/2
        ]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-include("common.hrl").
-include("record.hrl").
-record(state, {
        id,
        ip,
        port,
        node
    }
).

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
    ?MODULE ! {rpc_server_add, Id, Node, Ip, Port}.

%% 广播到所有线路
send_to_all(Data) ->
    Servers = server_list(),
    broadcast_to_world(Servers, Data).

%% 接收其它战区的状态更新信息
rpc_server_update(Id, Num) ->
    ?MODULE ! {rpc_server_update, Id, Num}.

start_link(Ip, Port, Sid) ->
    gen_server:start_link({local,?MODULE}, ?MODULE, [Ip, Port, Sid], []).

init([Ip, Port, Sid]) ->
    net_kernel:monitor_nodes(true),
    ets:new(?ETS_SERVER, [{keypos, #server.id}, named_table, public, set]),
    State = #state{id = Sid, ip = Ip, port = Port, node = node()},
    add_server([State#state.ip, State#state.port, State#state.id, State#state.node]),
    %% 获取并通知当前所有线路
    get_and_call_server(State),
    {ok, State}.

handle_cast(_R , State) ->
    {noreply, State}.

%% 获取战区ID号
handle_call(get_server_id, _From, State) ->
    {reply, State#state.id, State};

handle_call(_R , _FROM, State) ->
    {reply, ok, State}.

%% 广播到其它战区的世界
handle_info({all, Data}, State) ->
    Servers = server_list(),
    broadcast_to_world(Servers, Data),
    {noreply, State};

%% 新线加入
handle_info({rpc_server_add, Id, Node, Ip, Port}, State) ->
    case Id of
        0 -> skip;
        _ ->
            ets:insert(?ETS_SERVER, #server{id = Id, node = Node, ip = Ip, port = Port})
    end,
    {noreply, State};

%% 其它线人数更新
handle_info({rpc_server_update, Id, Num}, State) ->
    case ets:lookup(?ETS_SERVER, Id) of
        [S] -> ets:insert(?ETS_SERVER, S#server{num = Num});
        _ -> skip
    end,
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

%% 处理新节点加入事件
handle_info({nodeup, Node}, State) ->
    try
        rpc:cast(Node, mod_disperse, rpc_server_add, [State#state.id, State#state.node, State#state.ip, State#state.port])
    catch
        _:_ -> skip
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

terminate(_R, State) ->
    {ok, State}.

code_change(_OldVsn, State, _Extra)->
    {ok, State}.


%% ----------------------- 私有函数 ---------------------------------

%% 广播到其它战区的世界频道
broadcast_to_world([], _Data) -> ok;
broadcast_to_world([H | T], Data) ->
    rpc:cast(H#server.node, lib_send, send_to_local_all, [Data]),
    broadcast_to_world(T, Data).

%% 广播当前在线给其它线
broadcast_server_state([], _Id, _Num) -> ok;
broadcast_server_state([H | T], Id, Num) ->
    rpc:cast(H#server.node, mod_disperse, rpc_server_update, [Id, Num]),
    broadcast_server_state(T, Id, Num).

%%加入服务器集群
add_server([Ip, Port, Sid, Node]) ->
    db_sql:execute(<<"replace into `server` (id, ip, port, node) values(?, ?, ?, ?)">>,[Sid, Ip, Port, Node]).

%%退出服务器集群
del_server(Sid) ->
    db_sql:execute(io_lib:format(<<"delete from `server` where id = ~p">>,[Sid])).

%%获取并通知所有线路信息
get_and_call_server(State) ->
    case db_sql:get_all(<<"select * from server">>) of
        [] ->
            [];
        Server ->
            F = fun([Id, Ip, Port, Node]) ->
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
                                    rpc:cast(Node1, mod_disperse, rpc_server_add, [State#state.id, State#state.node, State#state.ip, State#state.port]);
                                pang ->
                                    del_server(Id)
                            end;
                        false ->
                            ok
                    end
                end,
            [F(S) || S <- Server]
    end.