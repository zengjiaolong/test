%%% -------------------------------------------------------------------
%%% Author  :devil 1812338@gmail.com
%%% Description : 
%%%
%%% Created :
%%% -------------------------------------------------------------------
-module(robot).

-behaviour(gen_server).
-compile(export_all).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

-define(CONFIG_FILE, "../config/gateway.config").

%% 连接网关端口，不读取gateway配置
-define(GATEWAY_ADD,"www.ygzj.com").
-define(GATEWAY_PORT,7777).

-define(ACTION_SPEED_CONTROL, 10).
-define(ACTION_INTERVAL, ?ACTION_SPEED_CONTROL*10*1000).  % 自动行为最大时间间隔
-define(ACTION_MIN, 1000).	% 自动行为最小时间间隔

-define(TCP_TIMEOUT, 1000). % 解析协议超时时间
-define(HEART_TIMEOUT, 60*1000). % 心跳包超时时间
-define(HEART_TIMEOUT_TIME, 0). % 心跳包超时次数
-define(HEADER_LENGTH, 6). %
-define(TCP_OPTS, [
        binary,
        {packet, 0}, % no packaging
        {reuseaddr, true}, % allow rebind without waiting
        {nodelay, false},
        {delay_send, true},
		{active, false},
        {exit_on_close, false}
    ]).

-define(ETS_ROBOT, ets_robot).

-define(CHECK_ROBOT_STATUS, 1*60*1000).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-record(robot, {
		orig_n,		
        accid,	%%account id
        socket,	%%socket
		socket2,
		socket3,
        pid,	%%process id
        x ,		%%x坐标
        y ,		%%y坐标
        scene,
        tox,
        toy,
        hp,
        id,		%% id
        act,	%% 动作
        status,	%% 当前状态
		step 
    }).
%%%
%%% API
start1() ->
	start(10000,1000).
start2() ->
	start(20000,1000).
start3() ->
	start(30000,1000).
start4() ->
	start(40000,1000).
start5() ->
	start(50000,1000).
start6() ->
	start(60000,1000).
start7() ->
	start(70000,1000).
start8() ->
	start(80000,1000).

start()-> 
	io:format("------------type0---",[]),
	start(30000, 1000).

start(Num)->

	start(10000,Num).

%%StartId 起始AccountID
%%Num int 数量
%%Mod 跑步模式 1 ,2
start(StartId,Num)->
    sleep(100),
    F=fun(N)->
			io:format("start ~p~n",[N]),
          	sleep(100),
       		robot:start_link(StartId + N)
    end,
    for(0,Num,F),
	%%lists:map(F, lists:seq(1, Num)),
	%%timer:apply_after(?CHECK_ROBOT_STATUS,  robot, check_robot_status, [{StartId, Num, Mod}]),	
	ok.


%%检查机器人状态
%% check_robot_status({StartId, Num, Mod}) ->
%% 	MS = ets:fun2ms(fun(T)-> T end),
%% 	L = ets:select(?ETS_ROBOT, MS),
%% 	lists:foreach(fun(T) ->
%% 					Orig_n = T#robot.orig_n,
%% 					Pid = T#robot.pid,
%% 					case Pid =:= undefined orelse is_process_alive(Pid) =:= false  of
%% 						true -> 
%% %% io:format("check_robot_status:  /~p/~p/~p ~n", [Orig_n, Pid, T]),							
%% 							robot:start_link(Orig_n, Mod),
%% %% 							sleep(100),
%% 							ok;
%% 						_-> is_alive
%% 					end,
%% 					ok
%% 				end,
%% 			L),	
%% 	timer:apply_after(?CHECK_ROBOT_STATUS, 
%% 					  robot, check_robot_status,
%% 					  [{StartId, Num, Mod}]),	
%% 	ok.

%%
%%创建 一个ROBOT 进程
start_link(N)->
    case gen_server:start(?MODULE,[N],[]) of
        {ok, Pid}->
%%			io:format("---------------start ~p finish!----------~n",[N]),
			gen_server:cast(Pid, {start_action});
        _->
            fail
    end.

%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
%%初始化玩家数据
init([N]) ->
%%	io:format("---------------------------~p~n",[N]),
    process_flag(trap_exit,true),
	Pid = self(),
    case login(N, Pid) of
        {ok, Socket, Accid, Id}->
%%			io:format("-----------------------login-----------ok------~p----~n",[[Socket, Accid, Id]]),	
			%%io:format("-------------robot:~p~n",[#robot{}]),
            Robot= #robot{socket=Socket, 
							 accid=list_to_integer(Accid), 
							 id=Id, 
							 pid = Pid,
							 act=run,
							 status=standing,
							 tox=rand(30,40),
							 toy=rand(30,40),
							 orig_n = N,
							 step = 0
							 },
			%%登陆成功后开始动作
			{ok,Robot};
        _Error ->
            io:format("--------------------init---------err----~p----~n",[_Error]),
			{stop,normal,{}}
    end.
	

	



%%登录游戏服务器
login(N, Pid)->
	case get_game_server() of
		{Ip, Port} ->
   			 case connect_server(Ip, Port) of
        		{ok, Socket}->
%%					io:format("-----------------connect-ok---------------------~n",[]),
					Data = pack(10010, <<9999:16,N:32>>),%%创建角色
            		gen_tcp:send(Socket, Data),	
					try
    					Ref = async_recv(Socket, ?HEADER_LENGTH, ?TCP_TIMEOUT),
    				receive
        				{inet_async, Socket, Ref, {ok, <<Len:32, Cmd:16>>}} ->
%%							io:format("--------------------------cmd:~p~n",[Cmd]),
            				BodyLen = Len - ?HEADER_LENGTH,
            				case BodyLen > 0 of
                				true ->
                   					Ref1 = async_recv(Socket, BodyLen, ?TCP_TIMEOUT),
                    				receive
                       					{inet_async, Socket, Ref1, {ok, Binary}} when Cmd =:= 10010->
										
											<<AccId:32, PlayerId:32, Bin/binary>> = Binary,
											io:format("----------------Accid:~p --- playerid:~p",[AccId,PlayerId]),
												{_Accname, _} = pt:read_string(Bin),
%% 													handle(login, {N, "N"}, Socket),
												spawn_link(fun()->do_parse_packet(Socket, Pid) end),													
 												handle(enter_player,{PlayerId},Socket),
												{ok, Socket, integer_to_list(N), PlayerId};
										Other ->
											io:format("--------------------------cmd--other:~p~n",[Other]),
											gen_tcp:close(Socket),
											error_60
									end;
								false ->
									error_70
							end;					   
        				%%用户断开连接或出错
        				_Other ->
%%							io:format("---------------------------------other-----err---------~p~n",[Other]),
							gen_tcp:close(Socket),
							error_80
    				end
					catch
						_:_ -> gen_tcp:close(Socket),
					   		   error_90
					end;
        		_ ->
            		error_100
    		end;
		_->	error_110
	end.

%% 获取网关服务器参数
get_gateway_config(Config_file)->
	try
		{ok,[L]} = file:consult(Config_file),
		{_, C} = lists:keyfind(gateway, 1, L),
		{_, Mysql_config} = lists:keyfind(tcp_listener, 1, C),
		{_, Ip} = lists:keyfind(ip, 1, Mysql_config),
		{_, Port} = lists:keyfind(port, 1, Mysql_config),
		[Ip, Port]		
	catch
		_:_ -> [?GATEWAY_ADD,?GATEWAY_PORT]
	end.

%%连接网关服务器
get_game_server()->
	%%[Gateway_Ip, Gateway_Port] = get_gateway_config(?CONFIG_FILE),
	[Gateway_Ip, Gateway_Port] = [?GATEWAY_ADD,?GATEWAY_PORT] ,
    case gen_tcp:connect(Gateway_Ip, Gateway_Port, ?TCP_OPTS, 10000) of
        {ok, Socket}->
			Data = pack(60000, <<>>),
            gen_tcp:send(Socket, Data),
    		try
			case gen_tcp:recv(Socket, ?HEADER_LENGTH) of
				{ok, <<Len:32, 60000:16>>} ->
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
								_-> 
									no_gameserver
							end;
                	 	_ ->
                    		gen_tcp:close(Socket),
							error_10
            		end;
				{error, _Reason} ->
%% 					io:format("error:~p~n",[Reason]),
					gen_tcp:close(Socket),
            		error_20
			end
			catch
				_:_ -> gen_tcp:close(Socket),
					   error_30
			end;
        {error,_Reason}->
			io:format("-------------------error:~p",[_Reason]),
            error_40
    end.

%%连接服务端
connect_server(Ip, Port)->
	gen_tcp:connect(Ip, Port, ?TCP_OPTS, 10000).

%% 接受信息
async_recv(Sock, Length, Timeout) when is_port(Sock) ->
    case prim_inet:async_recv(Sock, Length, Timeout) of
        {error, Reason} -> 	throw({Reason});
        {ok, Res}       ->  Res;
        Res             ->	
			Res
    end.

%%接收来自服务器的数据 - 登陆后进入游戏逻辑
%%Socket：socket id
%%Client: client记录
do_parse_packet(Socket, Pid) ->
%% io:format("do_parse_packet_0_:/~p/~p/~n",[Socket, Pid]),	
    Ref = async_recv(Socket, ?HEADER_LENGTH, ?HEART_TIMEOUT),
    receive
        {inet_async, Socket, Ref, {ok, <<Len:32, Cmd:16>>}} ->
%% io:format("do_parse_packet_1_:/~p/~p/~n",[Socket, Pid]),			
            BodyLen = Len - ?HEADER_LENGTH,
			RecvData = 
            case BodyLen > 0 of
                true ->
                    Ref1 = async_recv(Socket, BodyLen, ?TCP_TIMEOUT),
                    receive
                       {inet_async, Socket, Ref1, {ok, Binary}} ->
						    {ok, Binary};
                       Other ->
                            {fail, Other}
                    end;
                false ->
					{ok, <<>>}
            end,
%% 	io:format("do_parse_packet_11_:/~p/~p/~n",[Socket, RecvData]),	
			case RecvData of
				{ok, BinData} ->
%%io:format("do_parse_packet_CMD_:/~p/~n",[Cmd]),						
					case Cmd of
						13001 ->
%% 							io:format("do_parse_packet_6_:/~p/~p/~n",[Cmd, BinData]),
							<<Scene:32, X:16, Y:16,_Id:32,Hp:32,_Other/binary>> = BinData,
%% 							io:format("do_parse_packet_7_:/~p/~n",[[Pid, Cmd, Scene, X, Y, Hp]]),
            				%%更新信息
            				gen_server:cast(Pid,{upgrade_state_13001, [Scene, X, Y, Hp]}),
							ok;
						10007 ->
%% 							io:format("do_parse_packet_6_:/~p/~p/~n",[Cmd, BinData]),
							<<_Code:16>> = BinData,
%% 							io:format("do_parse_packet_10007_:/~p/~n",[Code]),
							ok;						
						_ -> no_action
					end,
					do_parse_packet(Socket, Pid);
				{fail, _} -> 
io:format("do_parse_packet_1_:/~p/~p/~n",[Socket, Pid]),						
					gen_tcp:close(Socket),
					gen_server:cast(Pid,{stop, socket_error_1})
			end;
         %%超时处理
         {inet_async, Socket, Ref, {error,timeout}} ->
io:format("do_parse_packet_2_:/~p/~p/~n",[Socket, Pid]),			 
			 gen_tcp:close(Socket),
			 gen_server:cast(Pid,{stop, socket_error_2});
        %%用户断开连接或出错
        Reason ->
io:format("do_parse_packet_3_:/~p/~p/~n",[Socket, Reason]),			
            gen_tcp:close(Socket),
			gen_server:cast(Pid,{stop, socket_error_3})
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
handle_call({act},_From,State)->
    %%act有跑步run或者静止undefined
    handle(State#robot.act, a, State#robot.socket),
    {reply,ok,State};

handle_call({get_state},_From,State)->
    {reply,State,State};

handle_call({get_socket},_From,State)->
    Reply=State#robot.socket,
    {reply,Reply,State};

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
handle_cast({start_action}, State)->
	if is_port(State#robot.socket) ->
        %%心跳进程
        spawn_link(fun()->handle(heart, a , State#robot.socket) end),
		%%socket2 进程
		%%spawn_link(fun()->handle(start_child_socket,{State,2},c) end),
		%%socket3 进程
		%%spawn_link(fun()->handle(start_child_socket,{State,3},c) end),
		Pid= self(),
		spawn_link(fun()-> ai(Pid) end),

		{noreply, State};
	   true -> 
		   io:format("      start_action  stop_1: /~p/,~n",[State]),
		   {stop, normal, State}
	end;

handle_cast({add_child_socket,N,Socket},State)->
%%	io:format("------------------------add_child_socket----------- ~p~n",[N]),
	NewState = 
	if
		is_pid(State#robot.pid) andalso is_port(Socket) ->
			case N of
				2 -> State#robot{socket2 = Socket};
				3 -> State#robot{socket3 = Socket};
				_ -> State
			end;
		true ->
			io:format(" start_child_socket err : /~p/,~n",[State]),
			State
	end,
	{noreply,NewState};

handle_cast({upgrade_state, NewState},_State) ->
%% io:format("----------upgrade_state--------------------------:~n",[]),
%%	ets:insert(?ETS_ROBOT, NewState),
    {noreply,NewState};

handle_cast({get_state_13001},State) ->
	handle(get_self_info, a,State#robot.socket),
%%io:format("--------------------------get_state_13001~n",[]),
	{noreply, State};
	
handle_cast({upgrade_state_13001, [Scene, X, Y, Hp]},State) ->
	NewState = State#robot{x=X, y=Y, hp=Hp, scene=Scene},
%% io:format("--------------------------upgrade_state_13001:   ~p ~n",[NewState]), 	
    {noreply, NewState};

handle_cast({run}, State)->
    State2=State#robot{act=run},
    {noreply,State2};

handle_cast({stop}, State)->
    State2=State#robot{act=undefined},
    {noreply,State2};

handle_cast({stop, Reason},State)->
	io:format("      ~s_quit_2: /~p/~p/~p/,~n",[misc:time_format(now()), State#robot.accid, State#robot.id, Reason]),	
	{stop, normal, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
handle_info({stop, Reason},State)->
	io:format("      ~s_quit_3: /~p/~p/~p/,~n",[misc:time_format(now()), State#robot.accid, State#robot.id, Reason]),
	{stop, normal, State};

handle_info({event, action_random, PlayerId, Socket},State) ->
	Random_interval = random:uniform(?ACTION_INTERVAL) + ?ACTION_MIN,
%% io:format("~s_action_random: ~p~n", [misc:time_format(now()), Random_interval]),
	handle_action_random(PlayerId, Socket),
	erlang:send_after(Random_interval, self(), {event, action_random, PlayerId, Socket}),
	{noreply,State};

handle_info(close, State)->
    gen_tcp:close(State#robot.socket),
    {noreply,State};

handle_info(_Info, State) ->
    {noreply, State}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(Reason, State) ->
io:format(" ----------terminate-----------~s_quit_4: /~p/~p/~p/,~n",[misc:time_format(now()), State#robot.accid, State#robot.id, Reason]),
	if is_port(State#robot.socket) ->
		gen_tcp:close(State#robot.socket);
	   true -> no_socket
	end,
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%%=========================================================================
%% 业务处理函数
%%=========================================================================
%% 随机事件处理
handle_action_random(PlayerId, Socket) ->
	Actions = [chat1, others],
	Action = lists:nth(random:uniform(length(Actions)), Actions),
	Module = list_to_atom(lists:concat(["robot_",Action])),
	catch Module:handle(PlayerId, Socket),
	ok.
  

%%游戏相关操作%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%心跳包
handle(heart, _, Socket) ->
%% io:format("----------------------------------------Heart_0_~n"),	
    case gen_tcp:send(Socket, pack(10006, <<>>)) of
		ok ->
%%			io:format("-------iii--------Heart-------iii--------~n"),	
			sleep(24*1000),
    		handle(heart, a, Socket);
		_ ->
			error
	end;

%%子socket链接
handle(start_child_socket,{State,N},_) ->
	sleep(5000),
	case get_game_server() of
		{Ip, Port} ->
   			 case connect_server(Ip, Port-N*100) of
        		{ok, Socket}->
%%					io:format("---------------childsocket--connect-ok---------------------~n",[]),
					Accid = State#robot.accid,
					Pid = State#robot.pid,
					Data = pack(10008, <<9999:16,Accid:32,N:8>>),
            		gen_tcp:send(Socket, Data),	
					try
    					Ref = async_recv(Socket, ?HEADER_LENGTH, ?TCP_TIMEOUT),
    				receive
        				{inet_async, Socket, Ref, {ok, <<Len:32, Cmd:16>>}} ->
							%%io:format("--------------------------cmd:~p~n",[Cmd]),
            				BodyLen = Len - ?HEADER_LENGTH,
            				case BodyLen > 0 of
                				true ->
                   					Ref1 = async_recv(Socket, BodyLen, ?TCP_TIMEOUT),
                    				receive
                       					{inet_async, Socket, Ref1, {ok, Binary}} when Cmd =:= 10008 ->
											%%io:format("----------------------rev--10008~n",[]),
											<<Code:16,N:8>> = Binary,
												%%io:format("----------------------rev--10008:~p~n",[Code]),
												if
													Code == 1 ->
														%%spawn_link(fun()->do_parse_packet(Socket, Pid) end),
														gen_server:cast(Pid,{add_child_socket,N,Socket}),
														{ok, N};
													true ->
														error_50
											end;
										Other ->
											io:format("---------------child-----------cmd--other:~p~n",[Other]),
											gen_tcp:close(Socket),
											error_60
									end;
								false ->
									error_70
							end;					   
        				%%用户断开连接或出错
        				Other ->
							io:format("---------------------child------------other-----err---------~p~n",[Other]),
							gen_tcp:close(Socket),
							error_80
    				end
					catch
						_:_ -> gen_tcp:close(Socket),
					   		   error_90
					end;
        		_ ->
            		error_100
    		end;
		_->	error_110
	end;

%%登陆
handle(login, {Accid, AccName}, Socket) ->
    AccStamp = 1273027133,
    Tick = integer_to_list(Accid) ++ AccName ++ integer_to_list(AccStamp) ++ ?TICKET,
    TickMd5 = util:md5(Tick),
    TickMd5Bin = list_to_binary(TickMd5),
    AccNameLen = byte_size(list_to_binary(AccName)),
    AccNameBin = list_to_binary(AccName),
    Data = <<1:16, Accid:32, AccStamp:32, AccNameLen:16, AccNameBin/binary, 32:16, TickMd5Bin/binary>>,
    gen_tcp:send(Socket, pack(10000, Data)),
    ok;
%%玩家列表
handle(list_player, _, Socket) ->
%%     io:format("      client send: list_player ~n"),
    gen_tcp:send(Socket, pack(10002, <<1:16>>)),
    ok;
%%选择角色进入
handle(enter_player, {PlayerId}, Socket) ->
    gen_tcp:send(Socket, pack(10004, <<9999:16,PlayerId:32>>)),	
	%%erlang:send_after(random:uniform(?ACTION_INTERVAL)+1000, self(), {event, action_random, PlayerId, Socket}),	
    ok;
%%跑步
handle(run,a,Socket)->
    X=util:rand(15,45),
    Y=util:rand(15,45),
    gen_tcp:send(Socket, pack(12001, <<X:16,Y:16>>));
%%ai模式跑步
handle(run, {X,Y}, Socket) ->
%%	io:format("----running:[~p][~p]~n",[X,Y]),
    gen_tcp:send(Socket,  pack(12001, <<X:16, Y:16>>));
%%进入场景
handle(enter_scene,Sid, Socket) ->
    gen_tcp:send(Socket,  pack(12005, <<Sid:32>>));
%%聊天
handle(chat,Data,Socket)->
    Bin=list_to_binary(Data),
    _L=byte_size(Bin) + ?HEADER_LENGTH,
    gen_tcp:send(Socket,  pack(11010, <<0:8,Bin/binary>>));
%%静止
handle(undefined,a,_Socket)->
    ok;
%%获取其他玩家信息
handle(get_player_info,Id,Socket)->
    gen_tcp:send(Socket,  pack(13004, <<Id:16>>));

%%获取自己信息
handle(get_self_info, _ ,Socket)->
    gen_tcp:send(Socket,  pack(13001, <<1:16>>));

%%复活
handle(revive, _, Socket)->
	gen_tcp:send(Socket, pack(20004, <<3:8>>)),
    Action = tool:to_binary("-加血 100000"),
	ActionLen= byte_size(Action),
	Data = <<ActionLen:16, Action/binary>>,
    Packet =  pack(11020, Data),	
	gen_tcp:send(Socket, Packet);

handle(Handle, Data, Socket) ->
    io:format("handle error: /~p/~p/~n", [Handle, Data]),
    {reply, handle_no_match, Socket}.

%%玩家列表
read(<<L:32, 10002:16, Num:16, Bin/binary>>) ->
    io:format("client read: ~p ~p ~p~n", [L, 10002, Num]),
    F = fun(Bin1) ->
        <<Id:32, S:16, C:16, Sex:16, Lv:16, Bin2/binary>> = Bin1,
        {Name, Rest} = read_string(Bin2),
        io:format("player list: Id=~p Status=~p Pro=~p Sex=~p Lv=~p Name=~p~n", [Id, S, C, Sex, Lv, Name]),
        Rest
    end,
    for(0, Num, F, Bin),
    io:format("player list end.~n");

read(<<L:32, Cmd:16>>) ->
    io:format("client read: ~p ~p~n", [L, Cmd]);
read(<<L:32, Cmd:16, Status:16>>) ->
    io:format("client read: ~p ~p ~p~n", [L, Cmd, Status]);
read(<<L:32, Cmd:16, Bin/binary>>) ->
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

ping(Node)->
    case net_adm:ping(Node) of
        pang ->
            io:format("ping ~p error.~n",[Node]);
        pong ->
            io:format("ping ~p success.~n",[Node]);
        Error->
            io:format("error: ~p ~n",[Error])
    end.

do_act(Pid)->
    State=gen_server:call(Pid,{get_state}),
    handle(State#robot.act,a,State#robot.socket),
    sleep(20000),
    do_act(Pid).

%%根据机器人状态进行动作
ai(Pid)->
	%%更新信息
	gen_server:cast(Pid,{get_state_13001}),
	Random_interval = random:uniform(1000)+3000,
    sleep(Random_interval),	
    State=gen_server:call(Pid,{get_state}),
%%io:format("--------act:[~p]--hp:[~p]---status:[~p]--x:[~p]---y:[~p]---~n",[State#robot.act,State#robot.hp,State#robot.status,State#robot.x,State#robot.y]),
    case State#robot.act of
        run   ->
			case State#robot.hp > 0 of
				true ->
                    case State#robot.status of
                        standing ->
                            %%Scenes = [{100,{23,21}}, {101,{112,207}}, {200,{58,157}}, {250,{64,86}}, {280,{65,93}}, {300,{52,162}}],
                            Scenes = get_scene(),
                            if State#robot.step == 0 ->						   
                                   R = util:rand(1,length(Scenes)),
                                   {Scene,{X, Y}} = lists:nth(R, Scenes),
                                   if State#robot.scene =/= Scene ->
                                          handle(enter_scene, Scene, State#robot.socket),
                                          Tox = X,
                                          Toy = Y;
                                      true ->
                                          Tox = State#robot.tox,
                                          Toy = State#robot.toy							  
                                   end,
                                   New_step = 1;
                               true ->
                                   case lists:keyfind(State#robot.scene,1,Scenes) of
                                       false ->
                                          Tox = State#robot.tox,
                                          Toy = State#robot.toy;
                                       {_Scene,{X, Y}} ->
                                            Tox = rand(X-8,X+8),
                                            Toy = rand(Y-10,Y+10)								   
                                   end,
                                   New_step = 1					
                            end,
                            State2=State#robot{tox=Tox,toy=Toy,step=New_step,status=running},
                            gen_server:cast(State#robot.pid,{upgrade_state,State2});
                        running ->
                            if
                                State#robot.x /= State#robot.tox andalso State#robot.y /=State#robot.toy ->
        %%                            io:format("x:~p y:~p~n",[State#robot.x,State#robot.y]),
        %%                           io:format("tox:~p toy:~p~n",[State#robot.tox,State#robot.toy]),
                                    if

                                        State#robot.x > State#robot.tox andalso State#robot.y > State#robot.toy ->
                                            %%io:format("----------------run1~n"),
                                            if
                                                State#robot.x -6 =< State#robot.tox andalso State#robot.y - 6 =< State#robot.toy ->
                                                    handle(run,{State#robot.tox,State#robot.toy},State#robot.socket);
                                                State#robot.x -6 =< State#robot.tox andalso State#robot.y - 6 > State#robot.toy ->
                                                    handle(run,{State#robot.tox,State#robot.y-6},State#robot.socket);
                                                State#robot.x -6 > State#robot.tox andalso State#robot.y - 6 =< State#robot.toy ->
                                                    handle(run,{State#robot.x -6,State#robot.toy},State#robot.socket);
                                                State#robot.x -6 > State#robot.tox andalso State#robot.y - 6 > State#robot.toy ->
                                                    handle(run,{State#robot.x -6,State#robot.y-6},State#robot.socket);
                                                true ->
                                                    io:format("stop1~n"),
                                                    ok
                                            end;
                                        State#robot.x < State#robot.tox andalso State#robot.y > State#robot.toy ->
                                            %%io:format("----------------run2~n"), 
                                            if
                                                State#robot.x + 6 >= State#robot.tox andalso State#robot.y - 6 > State#robot.toy ->
                                                    handle(run,{State#robot.tox,State#robot.y-6},State#robot.socket);
                                                State#robot.x + 6 >= State#robot.tox andalso State#robot.y - 6 =< State#robot.toy ->
                                                    handle(run,{State#robot.tox,State#robot.toy},State#robot.socket);
                                                State#robot.x + 6 < State#robot.tox andalso State#robot.y - 6 > State#robot.toy ->
                                                    handle(run,{State#robot.x +6,State#robot.y-6},State#robot.socket);
                                                State#robot.x + 6 < State#robot.tox andalso State#robot.y - 6 =< State#robot.toy ->
                                                    handle(run,{State#robot.x +6,State#robot.toy},State#robot.socket);
                                                true ->
                                                    io:format("stop2~n"),
                                                    ok
                                            end;
                                        State#robot.x > State#robot.tox andalso State#robot.y < State#robot.toy ->
                                            %%io:format("----------------run3~n"),
                                            if
                                                State#robot.x - 6 > State#robot.tox andalso State#robot.y + 6 >= State#robot.toy ->
                                                    handle(run,{State#robot.x -6 ,State#robot.toy},State#robot.socket);
                                                State#robot.x - 6 > State#robot.tox andalso State#robot.y + 6 < State#robot.toy ->
                                                    handle(run,{State#robot.x -6 ,State#robot.y+6},State#robot.socket);
                                                State#robot.x - 6 =< State#robot.tox andalso State#robot.y + 6 >= State#robot.toy ->
                                                    handle(run,{State#robot.tox ,State#robot.toy},State#robot.socket);
                                                State#robot.x - 6 =< State#robot.tox andalso State#robot.y + 6 < State#robot.toy ->
                                                    handle(run,{State#robot.tox ,State#robot.y+6},State#robot.socket);
                                                true ->
                                                    io:format("stop3~n"),
                                                    ok
                                            end;
                                        State#robot.x < State#robot.tox andalso State#robot.y < State#robot.toy ->
                                            %%io:format("----------------run4~n"),
                                            if
                                                State#robot.x + 6 >= State#robot.tox andalso State#robot.y + 6 >= State#robot.toy ->
                                                    handle(run,{State#robot.tox ,State#robot.toy},State#robot.socket);
                                                State#robot.x + 6 >= State#robot.tox andalso State#robot.y + 6 < State#robot.toy ->
                                                    handle(run,{State#robot.tox ,State#robot.y+6},State#robot.socket);
                                                State#robot.x + 6 < State#robot.tox andalso State#robot.y + 6 >= State#robot.toy ->
                                                    handle(run,{State#robot.x +6 ,State#robot.toy},State#robot.socket);
                                                State#robot.x + 6 < State#robot.tox andalso State#robot.y + 6 < State#robot.toy ->
                                                    handle(run,{State#robot.x +6 ,State#robot.y+6},State#robot.socket);
                                                true ->
                                                    io:format("stop4~n"),
                                                    ok
                                            end;
                                        true ->
                                            handle(get_self_info,a,State#robot.socket),
                                            io:format("--stop5~n"),
                                            ok
                                    end;
         %%                        gen_server:cast(State#robot.pid,{upgrade_state,State2});
                            true ->
                                %%到达目的地并且x，y是场景入口，进入其他场景
        %%  io:format("new run_5:id=~p,scene=~p, hp=~p, x=~p y=~p~n",[State#robot.id, State#robot.scene, State#robot.hp, State#robot.x,State#robot.y]),
        %%						io:format("-------------------------target----~n",[]),
                                State2=State#robot{status=standing},
                                gen_server:cast(State#robot.pid,{upgrade_state,State2})
                            end;
                        _->
                            io:format("robot status error!~n")
                    end;
				false ->
					handle(revive,a,State#robot.socket)
			end;
%%         run when State#robot.hp =< 0 ->
%% %% io:format("                 revive:id=~p,scene=~p,hp=~p~n",[State#robot.id, State#robot.scene, State#robot.hp]),			
%%             handle(revive,a,State#robot.socket);
        undefined ->
            ok
    end,
	%%io:format("-------------------------------------------ai-end---~n",[]),
    ai(Pid).

pack(Cmd, Data) ->
    L = byte_size(Data) + ?HEADER_LENGTH,
    <<L:32, Cmd:16, Data/binary>>.


rand(Same, Same) -> Same;
rand(Min, Max) ->
    M = Min - 1,
	if
		Max - M =< 0 ->
			0;
		true ->
			random:uniform(Max - M) + M
	end.


get_scene() ->
[
{201,{55,160}},
{201,{42,141}},
{201,{57,158}},
{201,{20,145}},
{201,{17,161}},
{201,{9,110}},
{201,{16,94}},
{201,{23,77}},
{201,{28,59}},
{201,{40,69}},
{201,{50,64}},
{201,{67,62}},
{201,{47,45}},
{201,{40,54}},
{201,{79,16}},
{251,{55,160}},
{251,{42,141}},
{251,{57,158}},
{251,{20,145}},
{251,{17,161}},
{251,{9,110}},
{251,{16,94}},
{251,{23,77}},
{251,{28,59}},
{251,{40,69}},
{251,{50,64}},
{251,{67,62}},
{251,{47,45}},
{251,{40,54}},
{251,{79,16}},
{281,{55,160}},
{281,{42,141}},
{281,{57,158}},
{281,{20,145}},
{281,{17,161}},
{281,{9,110}},
{281,{16,94}},
{281,{23,77}},
{281,{28,59}},
{281,{40,69}},
{281,{50,64}},
{281,{67,62}},
{281,{47,45}},
{281,{40,54}},
{281,{79,16}}
].
