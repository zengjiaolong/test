%%% -------------------------------------------------------------------
%%% Author  :devil 1812338@gmail.com
%%% Description :
%%%
%%% Created : 
%%% -------------------------------------------------------------------
-module(tt).

-behaviour(gen_server).
-compile(export_all).
-include("common.hrl").
-include("record.hrl").

-define(CONFIG_FILE, "../config/gateway.config").

-define(GATEWAY_ADD,"127.0.0.1").
-define(GATEWAY_PORT,7777).

-define(SERVER_ADD,"127.0.0.1").
-define(SERVER_PORT,7788).

-define(TCP_TIMEOUT, 1000). % 解析协议超时时间
-define(HEART_TIMEOUT, 60000). % 心跳包超时时间
-define(HEART_TIMEOUT_TIME, 0). % 心跳包超时次数
-define(HEADER_LENGTH, 4). % 消息头长度
-define(TCP_OPTS, [
        binary,
        {packet, 0}, % no packaging
        {reuseaddr, true}, % allow rebind without waiting
        {nodelay, false},
        {delay_send, true},
		{active, false},
        {exit_on_close, false}
    ]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-record(state, {
        socket
    }).
start()->
    spawn(fun()-> start_link() end).
%%功能测试提交数据%%
%%<<length:16,code:16,data:x>>
cmd(Bin)->
    case whereis(testtest) of
        Pid when is_pid(Pid) ->
            Pid !{cmd,Bin};
        undefined ->
            io:format("start tt first!")
    end.
%%创建gen_server 进程
start_link()->
    case gen_server:start_link(?MODULE,[ ],[]) of
        {ok,Pid}->
            case whereis(testtest) of
                Pid when is_pid(Pid) ->
                    unregister(testtest);
                undefined ->
                    register(testtest,Pid)
            end,
			case  get_db_config(?CONFIG_FILE) of
				[Host, Port, User, Password, DB, Encode] ->	
    				init_db(Host, Port, User, Password, DB, Encode),
            		login(),
            		%%Socket=gen_server:call(whereis(testtest),{get_socket}),
            		%%io:format("socket:~p~n",[Socket]),
            		%%功能测试提交数据%%
            		%%<<length:16,code:16,data:x>>
            		rec();
				_ -> mysql_config_fail
			end,					
            ok;
        {error,Reason}->
            io:format("error~p~n",[Reason])
    end.
rec()->
    receive
        {tcp, _Socket, Bin}->
            case Bin of
                <<_L:16,ProtoNum:16,Data/binary>>  ->
                io:format("~p/~p~n",[ProtoNum,Data]);
                B ->
                io:format("tcp receive:~p~n",[binary_to_list(B)])
            end;
        {tcp_closed,_Socket} ->
             io:format("socket closed!~n");
        BIN->
            io:format("no tcp BIN:~p~n",[BIN])
    end,
    rec().
init([])->
    io:format("init ok~n"),
    {ok,#state{}}.

%%连接网关服务器
get_game_server()->
    case gen_tcp:connect(?GATEWAY_ADD,?GATEWAY_PORT, ?TCP_OPTS, 10000) of
        {ok, Socket}->
			Data = pt:pack(60000, <<>>),
            gen_tcp:send(Socket, Data),
    		try
			case gen_tcp:recv(Socket, ?HEADER_LENGTH) of
				{ok, <<Len:16, 60000:16>>} ->
%% 					io:format("len: ~p ~n",[Len]),
					BodyLen = Len - ?HEADER_LENGTH,
            		case gen_tcp:recv(Socket, BodyLen, 3000) of
                		{ok, <<Bin/binary>>} ->
							<<Rlen:16, RB/binary>> = Bin,
							case Rlen of
								1 ->
									<<_Id:8, Bin1/binary>> = RB,
									{IP, Bin2} = pt:read_string(Bin1),
									<<Port:16, _State:8, _Num:16>> = Bin2,
%% 									io:format("IP, Port:  /~p/~p/~n",[IP, Port]),
									{IP, Port};
								_-> no_gameserver
							end;
                	 	_ ->
                    		gen_tcp:close(Socket),
							error
            		end;
				{error, _Reason} ->
%% 					io:format("error:~p~n",[Reason]),
					gen_tcp:close(Socket),
            		error
			end
			catch
				_:_ -> gen_tcp:close(Socket),
					   fail
			end;
        {error,_Reason}->
            error
    end.

%%登录游戏服务器
login()->
%% 	{Ip, Port} = {?SERVER_ADD, ?SERVER_PORT},
	case get_game_server() of
		{Ip, Port} ->
   			 case connect_server(Ip, Port) of
        		{ok,Socket}->
                    gen_server:call(whereis(testtest),{init_socket,Socket}),
            		handle(login,{2012,integer_to_list(2012)},Socket),
                    case get_player_id(2012) of
                        0 ->
                            handle(create_player, {1,1, 1,"2012"}, Socket),
                            sleep(1000),
                            PlayerId=get_player_id(2012),
                            if
                                PlayerId /=0 ->
                                    handle(enter_player, {PlayerId}, Socket);
                                true ->
                                    io:format("player id error! ~n")
                            end;
                        PlayerId->
                            handle(enter_player,{PlayerId},Socket)
                    end,
            		sleep(100);
        		{error,_Reason}->
            		error
    		end;
		_->	error
	end.

%%取socket
handle_call({get_socket},_From,State)->
    {reply,State#state.socket,State};
%%初始化socket
handle_call({init_socket,Socket},_From,State)->
    S2=State#state{socket=Socket},
    {reply,ok,S2};
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({cmd,Bin},State)->
    gen_tcp:send(State#state.socket,Bin),
    {noreply,State};

handle_info({tcp, _Socket, Bin},State)->
    case Bin of
       <<_L:16,ProtoNum:16,Data/binary>>  ->
            io:format("~p/~p~n",[ProtoNum,Data]),
            ok;
        B ->
            io:format("receive:~p~n",[binary_to_list(B)]),
            ok
    end,
    {noreply,State};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
%%     ets:delete(?ETS_MONITOR_PID),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%%游戏相关操作%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%心跳包
handle(heart, _, Socket) ->
    gen_tcp:send(Socket, <<4:16, 10006:16>>),
    sleep(20000),
    handle(heart,a,Socket);
%%登陆
handle(login, {Accid, AccName}, Socket) ->
    AccStamp = 1273027133,
    Tick = integer_to_list(Accid) ++ AccName ++ integer_to_list(AccStamp) ++ ?TICKET,
    TickMd5 = util:md5(Tick),
    TickMd5Bin = list_to_binary(TickMd5),
    AccNameLen = byte_size(list_to_binary(AccName)),
    AccNameBin = list_to_binary(AccName),
    Data = <<Accid:32, AccStamp:32, AccNameLen:16, AccNameBin/binary, 32:16, TickMd5Bin/binary>>,
    Len = byte_size(Data) + 4,
    gen_tcp:send(Socket, <<Len:16, 10000:16, Data/binary>>),
    ok;
%%创建用户
handle(create_player, {Realm,Career, Sex, Name}, Socket) ->
    io:format("client send: create_player ~p ~p ~p ~p ~n", [Realm, Career, Sex, Name]),
    NameBin = list_to_binary(Name),
    NameLen = byte_size(NameBin),
    Data = <<Realm:8,Career:8,Sex:8,NameLen:16, NameBin/binary>>,
    Len = byte_size(Data) + 4,
    gen_tcp:send(Socket, <<Len:16, 10003:16, Data/binary>>),
    ok;
%%玩家列表
handle(list_player, _, Socket) ->
    io:format("client send: list_player ~n"),
    gen_tcp:send(Socket, <<6:16, 10002:16, 1:16>>),
    ok;
%%选择角色进入
handle(enter_player, {PlayerId}, Socket) ->
    io:format("client send: enter_player ~p ~n", [PlayerId]),
    gen_tcp:send(Socket, <<8:16, 10004:16, PlayerId:32>>),
    ok;
%%跑步
handle(run,a,Socket)->
    X=util:rand(15,45),
    Y=util:rand(15,45),
    gen_tcp:send(Socket,<<8:16,12001:16,X:16,Y:16>>);
%%ai模式跑<6:16,13001:16,1:16>>);
%%复活
handle(revive,_,Socket)->
    gen_tcp:send(Socket,<<4:16,20004:16>>);

handle(Handle, Data, Socket) ->
    io:format("handle error: /~p/~p/~n", [Handle, Data]),
    {reply, handle_no_match, Socket}.

%%玩家列表
read(<<L:16, 10002:16, Num:16, Bin/binary>>) ->
    io:format("client read: ~p ~p ~p~n", [L, 10002, Num]),
    F = fun(Bin1) ->
        <<Id:32, S:16, C:16, Sex:16, Lv:16, Bin2/binary>> = Bin1,
        {Name, Rest} = read_string(Bin2),
        io:format("player list: Id=~p Status=~p Pro=~p Sex=~p Lv=~p Name=~p~n", [Id, S, C, Sex, Lv, Name]),
        Rest
    end,
    for(0, Num, F, Bin),
    io:format("player list end.~n");

read(<<L:16, Cmd:16>>) ->
    io:format("client read: ~p ~p~n", [L, Cmd]);
read(<<L:16, Cmd:16, Status:16>>) ->
    io:format("client read: ~p ~p ~p~n", [L, Cmd, Status]);
read(<<L:16, Cmd:16, Bin/binary>>) ->
    io:format("client read: ~p ~p ~p~n", [L, Cmd, Bin]);
read(Bin) ->
    io:format("client rec: ~p~n", [Bin]).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%辅助函数
%%读取字符串
read_string(Bin) ->
    case Bin of
        <<Len:16, Bin1/binary>> ->
            case Bin1 of
                <<Str:Len/binary-unit:8, Rest/binary>> ->
                    {binary_to_list(Str), Rest};
                _R1 ->
                    {[],<<>>}
            end;
        _R1 ->
            {[],<<>>}
    end.

 sleep(T) ->
    receive
    after T -> ok
    end.

for(Max, Max, _F) ->
    [];
for(Min, Max, F) ->
    [F(Min) | for(Min+1, Max, F)].

for(Max, Max, _F, X) ->
    X;
for(Min, Max, F, X) ->
    F(X),
    for(Min+1, Max, F, X).

sleep_send({T, S}) ->
    receive
    after T -> handle(run, a, S)
    end.

get_pid(Name)->
    case whereis(Name) of
        undefined ->
            err;
        Pid->Pid
    end.

%%连接网关服务器
connect_gateway()->
    gen_tcp:connect(?GATEWAY_ADD,?GATEWAY_PORT,?TCP_OPTS,10000).

%%连接服务端
connect_server(Ip, Port)->
    gen_tcp:connect(Ip, Port,[binary,{packet,0}],10000).

init_db(Host, Port, User, Password, DB, Encode)->
	mysql:start_link(?DB_POOL, Host, Port, User, Password, DB, fun(_, _, _, _) -> ok end, Encode),
	mysql:connect(?DB_POOL, Host, Port, User, Password, DB, Encode, true),
    ok.

%%根据accid取id。
get_player_id(N)->
    case db_sql:get_row(io_lib:format(<<"select id from `player` where accid=~p limit 1">>, [N])) of
        [ID]->ID;
        []->0
    end.

ping(Node)->
    case net_adm:ping(Node) of
        pang ->
            io:format("ping ~p error.~n",[Node]);
        pong ->
            io:format("ping ~p success.~n",[Node]);
        Error->
            io:format("error: ~p ~n",[Error])
    end.


%% 接受信息
async_recv(Sock, Length, Timeout) when is_port(Sock) ->
    case prim_inet:async_recv(Sock, Length, Timeout) of
        {error, Reason} -> 	{error, Reason};
        {ok, Res}       ->  {ok, Res};
        Res             ->	{ok, Res}
    end.

get_db_config(Config_file)->
	try
		{ok,[L]} = file:consult(Config_file),
		{_, C} = lists:keyfind(gateway, 1, L),
		{_, Mysql_config} = lists:keyfind(mysql_config, 1, C),
		{_, Host} = lists:keyfind(host, 1, Mysql_config),
		{_, Port} = lists:keyfind(port, 1, Mysql_config),
		{_, User} = lists:keyfind(user, 1, Mysql_config),
		{_, Password} = lists:keyfind(password, 1, Mysql_config),
		{_, DB} = lists:keyfind(db, 1, Mysql_config),
		{_, Encode} = lists:keyfind(encode, 1, Mysql_config),
		[Host, Port, User, Password, DB, Encode]		
	catch
		_:_ -> no_config
	end.
