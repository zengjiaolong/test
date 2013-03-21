%%%--------------------------------------
%%% @Module  : yg_gateway
%%% @Author  : ygzj
%%% @Created : 2010.09.18 
%%% @Description: 游戏网关
%%%--------------------------------------
-module(yg_gateway).
-behaviour(gen_server).
-export([start_link/1,server_stop/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-include("common.hrl").
-include("record.hrl").
-record(gatewayinit, {
	id = 1,				  	
	init_time = 0,
	async_time = 0
    }).	
% 消息头长度
-define(HEADER_LENGTH, 6). 

%%开启网关
%%Node:节点
%%Port:端口
start_link(Port) ->
	misc:write_system_info(self(), tcp_listener, {"", Port, now()}),	
    gen_server:start(?MODULE, [Port], []).

init([Port]) ->
	misc:write_monitor_pid(self(),?MODULE, {}),
    F = fun(Sock) -> handoff(Sock) end,
    yg_gateway_server:stop(Port),
    yg_gateway_server:start_raw_server(Port, F, ?ALL_SERVER_PLAYERS),
	Now = util:unixtime(),
	Async_time = 
		case config:get_gateway_async_time() of
			undefined -> 0;
			Second -> Second
		end,
	ets:new(gatewayinit, [{keypos, #gatewayinit.id}, named_table, public, set,?ETSRC, ?ETSWC]), 
	ets:insert(gatewayinit,#gatewayinit{id = 1,init_time = Now,async_time = Async_time}),
	%%开始统计进程
	{ok, _Pid} = mod_statistics:start(),
    {ok, true}.

%%关闭服务器过程禁止刷进游戏
server_stop()-> 
	Now = util:unixtime(),
	ets:insert(gatewayinit,#gatewayinit{id = 1,init_time = Now,async_time = 100}).

handle_cast(_Rec, Status) ->
    {noreply, Status}.

handle_call(_Rec, _FROM, Status) ->
    {reply, ok, Status}.

handle_info(_Info, Status) ->
    {noreply, Status}.

terminate(normal, Status) ->
	misc:delete_monitor_pid(self()),
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
           
        {ok, <<_Len:32, 60000:16>>} ->
			%%延时允许客户端连接
			[{_,_,InitTime,AsyncTime}] = ets:match_object(gatewayinit,#gatewayinit{id =1 ,_='_'}),
			Now = util:unixtime(),
			if
				Now - AsyncTime > InitTime  ->
            		List = mod_disperse:get_server_list(),
            		{ok, Data} = pt_60:write(60000, List),
            		gen_tcp:send(Socket, Data),
            		gen_tcp:close(Socket);
				true ->
					gen_tcp:close(Socket)
			end;
        {ok, <<Len:32, 60001:16>>} ->
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
        {ok, Packet} ->
			P = tool:to_list(Packet),
			P1 = string:left(P, 4),
			if (P1 == "GET " orelse P1 == "POST") ->
				   P2 = string:right(P, length(P) - 4),
					misc_admin:treat_http_request(Socket, P2),
           		    gen_tcp:close(Socket);
				true ->
					gen_tcp:close(Socket)
			end;
         _Reason ->
            gen_tcp:close(Socket)	
    end.

%% 是否创建角色
is_create(Accname) ->
    case db_agent:is_create(Accname) of
        [] ->
            0;
        _R ->
            1
    end.

