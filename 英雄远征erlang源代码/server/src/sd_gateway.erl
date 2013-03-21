%%%--------------------------------------
%%% @Module  : sd_gateway
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.04.25
%%% @Description: 游戏网关
%%%--------------------------------------
-module(sd_gateway).
-behaviour(gen_server).
-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-include("common.hrl").
-include("record.hrl").
-define(HEADER_LENGTH, 4). % 消息头长度

%%开启网关
%%Node:节点
%%Port:端口
start_link(Port) ->
    gen_server:start(?MODULE, [Port], []).

init([Port]) ->
    F = fun(Sock) -> handoff(Sock) end,
    sd_gateway_server:stop(Port),
    sd_gateway_server:start_raw_server(Port, F, ?ALL_SERVER_PLAYERS),
    {ok, true}.

handle_cast(_Rec, Status) ->
    {noreply, Status}.

handle_call(_Rec, _FROM, Status) ->
    {reply, ok, Status}.

handle_info(_Info, Status) ->
    {noreply, Status}.

terminate(normal, Status) ->
    {ok, Status}.

code_change(_OldVsn, Status, _Extra)->
	{ok, Status}.

%%发送要连接的IP和port到客户端，并关闭连接
handoff(Socket) ->
    case gen_tcp:recv(Socket, ?HEADER_LENGTH) of
        {ok, ?FL_POLICY_REQ} ->
            Len = 23 - ?HEADER_LENGTH,
            gen_tcp:recv(Socket, Len, 1000),
            gen_tcp:send(Socket, ?FL_POLICY_FILE),
            gen_tcp:close(Socket);
           
        {ok, <<_Len:16, 60000:16>>} ->
            List = get_server_list(),
            {ok, Data} = pt_60:write(60000, List),
            gen_tcp:send(Socket, Data),
            gen_tcp:close(Socket);

        {ok, <<Len:16, 60001:16>>} ->
            BodyLen = Len - ?HEADER_LENGTH,
            case gen_tcp:recv(Socket, BodyLen, 3000) of
                {ok, <<Bin/binary>>} ->
                    {Accname, _} = pt:read_string(Bin),
                    {ok, Data} = pt_60:write(60001, is_create(Accname)),
                    gen_tcp:send(Socket, Data),
                    handoff(Socket);
                 _ ->
                    gen_tcp:close(Socket)
            end;

         _ ->
            gen_tcp:close(Socket)
    end.

%% 获取服务器列表
get_server_list() ->
    case mod_disperse:server_list() of
        [] ->
            [];
        Server ->
            F = fun(S) ->
                    [State, Num] = case rpc:call(S#server.node, mod_kernel, online_state, []) of
                                {badrpc, _} ->
                                    [4, 0];
                                N ->
                                    N
                            end,
                    [S#server.id, S#server.ip, S#server.port, State, Num]
                end,
            [F(S) || S <- Server]
    end.

%% 是否创建角色
is_create(Accname) ->
    Sql = io_lib:format(<<"select id from player where accname = '~s' limit 1">>, [Accname]),
    case db_sql:get_all(Sql) of
        [] ->
            0;
        _R ->
            1
    end.
