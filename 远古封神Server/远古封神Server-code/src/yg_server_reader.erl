%%%-----------------------------------
%%% @Module  : yg_server_reader
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 读取客户端 
%%%-----------------------------------
-module(yg_server_reader).
-export([start_link/0, init/0]).
-include("common.hrl").
-include("record.hrl").
-define(TCP_TIMEOUT, 1000). % 解析协议超时时间
-define(HEART_TIMEOUT, 60*1000). % 心跳包超时时间
-define(HEART_TIMEOUT_TIME, 1).  % 心跳包超时次数
-define(HEADER_LENGTH, 6). % 消息头长度

%% 记录客户端进程
-record(client, {
  	player_pid = undefined,
	player_id = 0,
   	login  = 0,
   	accid  = 0,
   	accname = undefined,
   	timeout = 0,				% 超时次数
	sn = 0,						% 服务器号
	socketN = 0
}).

start_link() ->
 	{ok, proc_lib:spawn_link(?MODULE, init, [])}.

%% gen_server init
%% Host:主机IP
%% Port:端口
init() ->
    process_flag(trap_exit, true),
	Client = #client{},
    receive
  		{go, Socket} ->
       		login_parse_packet(Socket, Client);
		_ ->
			skip
    end.

%%接收来自客户端的数据 - 先处理登陆
%%Socket：socket id
%%Client: client记录
login_parse_packet(Socket, Client) ->
    Ref = async_recv(Socket, ?HEADER_LENGTH, ?HEART_TIMEOUT),
    receive
        %%flash安全沙箱
        {inet_async, Socket, Ref, {ok, ?FL_POLICY_REQ}} ->
            Len = 23 - ?HEADER_LENGTH,
            async_recv(Socket, Len, ?TCP_TIMEOUT),
            lib_send:send_one(Socket, ?FL_POLICY_FILE);
        %%登陆处理
        {inet_async, Socket, Ref, {ok, <<Len:32, Cmd:16>>}} ->
            BodyLen = Len - ?HEADER_LENGTH,
            case BodyLen > 0 of
                true ->
                    Ref1 = async_recv(Socket, BodyLen, ?TCP_TIMEOUT),
                    receive
                       {inet_async, Socket, Ref1, {ok, Binary}} ->
                            case routing(Client, Cmd, Binary) of
                                %%先验证登陆
                                {ok, login, Data} ->
                                    case pp_account:handle(10000, [], Data) of
                                         {true, L} ->
                                            [Sn, Accid, Accname, _, _] = Data,
                                            Client1 = Client#client{
												sn = Sn,
                                                login = 1,
                                                accid = Accid,
                                                accname = Accname
                                            },
                                            {ok, BinData} = pt_10:write(10000, [1, L]),
                                            lib_send:send_one(Socket, BinData),
                                            login_parse_packet(Socket, Client1);
                                        _ ->
                                            login_lost(Socket, Client, 2, "login fail")
                                    end;
                                %%读取玩家列表
                                {ok, lists, _Data} ->
                                    case Client#client.login == 1 of
                                        true ->
                                            pp_account:handle(10002, Socket, [Client#client.accid, Client#client.accname]),
                                            login_parse_packet(Socket, Client);
                                        false ->
                                            login_lost(Socket, Client, 3, "lists fail")
                                    end;
                                %%创建角色
                                {ok, create, Data} ->
                                    case Client#client.login == 1 of
                                        true ->
                                            Data1 = [Client#client.accid, Client#client.accname] ++ Data,
                                            pp_account:handle(10003, Socket, Data1),
                                            login_parse_packet(Socket, Client);
                                        false ->
                                            login_lost(Socket, Client, 4, "create fail")
                                    end;

                                %%删除角色
                                {ok, delete, Id} ->
                                    case Client#client.login == 1 of
                                        true ->
                                            pp_account:handle(10005, Socket, [Id, Client#client.accid]),
                                            login_parse_packet(Socket, Client);
                                        false ->
                                            login_lost(Socket, Client, 5, "delete fail")
                                    end;
                                %%进入游戏
                                {ok, enter, [Sn, Id]} ->
                                    case Client#client.login == 1 of
                                        true ->
                                            case mod_login:login(start, [Id, Client#client.accid, Client#client.accname], Socket) of
                                                {ok, Pid} ->
                                                    	{ok, BinData} = pt_10:write(10004, 1),
                                                    	lib_send:send_one(Socket, BinData),
                                                    	do_parse_packet(Socket, Client#client{
																						  sn = Sn,
																						  player_pid = Pid,																						  
																						  player_id = Id,
																						  socketN = 1
																					});										
                                                {error, _Reason} ->
                                                    %%告诉玩家登陆失败
                                                    {ok, BinData} = pt_10:write(10004, 0),
                                                    lib_send:send_one(Socket, BinData),
                                                    login_parse_packet(Socket, Client)
                                            end;
                                        false ->
                                            login_lost(Socket, Client, 6, "enter fail")
                                    end;
								
                                %%按照accid创建一个角色，或自动分配一个角色(accid=0)
                                {ok, new_role, [Sn, Accid]} ->
                                    case pp_account:handle(10010, Socket, [Sn, Accid]) of
                                        {true, NewAccid, RoleId, Accname} ->
                                            Client1 = Client#client{
                                                login = 1,
                                                accid = NewAccid,
                                                accname = Accname
                                            },
                                            {ok, BinData} = pt_10:write(10010, [NewAccid, RoleId, Accname]),
                                            lib_send:send_one(Socket, BinData),
                                            login_parse_packet(Socket, Client1);
                                        _ ->
                                            login_lost(Socket, Client, 7, "new_role fail")
                                    end;
								%%子socket
								{ok,mult_socket,[Sn,Accid,N]} ->
									%%加入socket组
									SocketGN = mod_socket:get_socket_group_name(Sn,Accid),
									case mod_socket:join([SocketGN,Socket,N]) of
										true ->
											pp_account:handle(10008,Socket,[1,N]),
											do_parse_packet(Socket, Client#client{sn=Sn,accid = Accid,socketN = N});
										false ->
											pp_account:handle(10008,Socket,[0,N]),
											login_lost(Socket, Client, 13, "child_socket fail")
									end;
								%%心跳包
								{ok,[heartbeat,_T]} ->
									login_parse_packet(Socket, Client);
								%%处理一开接收到子socket断开的消息
								{ok,[child_socket_break,N]} ->
									gen_server:cast(Client#client.player_pid, {'SOCKET_CHILD_LOST', N}),
									login_parse_packet(Socket, Client);
                                Other ->
                                    login_lost(Socket, Client, 8, Other)
                            end;
                        Other ->
                            login_lost(Socket, Client, 9, Other)
                    end;
                false ->
					case Cmd == 60000 of 
						true ->
						    ok;
					    _ ->	
                    		case Client#client.login == 1 of
                        		true ->
									case Cmd =:= 10002 of
										true -> pp_account:handle(Cmd, Socket,  [Client#client.accid, Client#client.accname]);
										_ ->  	pp_account:handle(Cmd, Socket,  Client#client.accid)
									end,
                            		login_parse_packet(Socket, Client);
                        		false ->
                            		login_lost(Socket, Client, 10, "other fail")
                    		end
					end
       		end;
        %% 超时处理
        {inet_async, Socket, Ref, {error,timeout}} ->
            case Client#client.timeout >= ?HEART_TIMEOUT_TIME  of
                true when Client#client.socketN == 1 ->
                    login_lost(Socket, Client, 11, {error,timeout});
				true -> %%子socket超时，断开子socekt
					do_lost_child(Socket,Client,0,{error,timeout},6);
                false ->
                    login_parse_packet(Socket, Client#client {timeout = Client#client.timeout+1})
            end;
        %%用户断开连接或出错
        Other ->
            login_lost(Socket, Client, 12, Other)
    end.


%%接收来自客户端的数据 - 登陆后进入游戏逻辑
%%Socket：socket id
%%Client: client记录
do_parse_packet(Socket, Client) ->
    Ref = async_recv(Socket, ?HEADER_LENGTH, ?HEART_TIMEOUT),
    receive
        {inet_async, Socket, Ref, {ok, <<Len:32, Cmd:16>>}} ->
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
			case RecvData of
				{ok, BinData} ->
		            case routing(Client, Cmd, BinData) of
                        %%这里是处理游戏逻辑
                        {ok, Data} ->
							%%处理子socket情况
							case Client#client.player_pid of
								undefined ->
									GroupName = mod_socket:get_socket_group_name(Client#client.sn,Client#client.accid),
									[Player_id,Pid] = mod_socket:get_state(GroupName),
									NewClient = Client#client{player_id = Player_id,player_pid = Pid};
								_ ->
									NewClient = Client
							end,
							gen_server:cast(NewClient#client.player_pid, {'SOCKET_EVENT', Cmd, Data}),
%% 							if Cmd /= 12001 ->
%% 									?DEBUG("CMD###########:~p~n",[Cmd]);
%% 							   true ->
%% 								   skip
%% 							end,
							do_parse_packet(Socket, NewClient);
                        Other2 ->
                            do_lost(Socket, Client, Cmd, Other2, 2)
                    end;
				{fail, Other3} -> 
					do_lost(Socket, Client, Cmd, Other3, 3)			
			end;
        %% 超时处理
        {inet_async, Socket, Ref, {error,timeout}} ->
            case Client#client.timeout >= ?HEART_TIMEOUT_TIME  of
                true when Client#client.socketN == 1 ->
                    do_lost(Socket, Client, 0, {error,timeout}, 4);
				true -> %%子socket超时，断开子socekt
					do_lost_child(Socket,Client,0,{error,timeout},6);
                false ->
                    do_parse_packet(Socket, Client#client{timeout = Client#client.timeout+1})            
            end;
        %%用户断开连接或出错
        Other ->
			case Client#client.socketN of
				1 ->
%%					?DEBUG("~s do_parse_packet_6_/~p/~p/",[misc:time_format(now()),Socket, Other]),		
            		do_lost(Socket, Client, 0, Other, 5);
				_ ->
%%					?DEBUG("~s do_parse_packet_6_/~p/~p/",[misc:time_format(now()),Socket, Other]),		
					do_lost_child(Socket, Client, 0, Other, 5)
			end
    end.

%%登录断开连接
login_lost(Socket, Client, Location, Reason) ->
	case lists:member(Location, [2,11,12]) of
		true -> no_log;
		_ ->
			?WARNING_MSG("login_lost_/loc: ~p/client:~p/reason: ~p/~n",[Location, Client, Reason])
	end,	   
	timer:sleep(100),
    gen_tcp:close(Socket),
    exit({unexpected_message, Reason}).

%%子socket断开
do_lost_child(_Socket,Client,Cmd,Reason,Location) ->
	case lists:member(Location, [3,4,5]) of
		true -> no_log;
		_ -> if Cmd =/= 12002 ->
					%%?WARNING_MSG("do_lost_/cmd: ~p/loc: ~p/client:~p/reason: ~p/~n",[Cmd, Location, Client, Reason]);
					no_log;
	   			true -> no_log
			 end
	end,
	gen_server:cast(Client#client.player_pid, {'SOCKET_CHILD_LOST', Client#client.socketN}),
	exit({unexpected_message, Reason}).

%%退出游戏
do_lost(_Socket, Client, Cmd, Reason, Location) ->
	case lists:member(Location, [3, 4, 5]) of
		true -> 
			no_log;
		_ -> 
			if 
				Cmd /= 12002 andalso Cmd /= 10030 ->
					?WARNING_MSG("do_lost_/cmd: ~p/loc: ~p/client:~p/reason: ~p/~n",[Cmd, Location, Client, Reason]);
	   			true -> 
					no_log
			end
	end,
    mod_login:logout(Client#client.player_pid, 0),
    exit({unexpected_message, Reason}).

%%路由
%%组成如:pt_10:read
routing(_Client, Cmd, Binary) ->
    %%取前面二位区分功能类型  
    [H1, H2, _, _, _] = integer_to_list(Cmd),
    Module = list_to_atom("pt_"++[H1,H2]),
%% 	if Cmd /= 10006 orelse Cmd /= 12001 ->?DEBUG("##read_cmd:~p",[Cmd]);
%% 	   true ->skip
%% 	end,
%% 	disp_read(2, Cmd, Client, Binary, Module),
    Module:read(Cmd, Binary).

%% 接受信息
async_recv(Sock, Length, Timeout) when is_port(Sock) ->
    case prim_inet:async_recv(Sock, Length, Timeout) of
        {error, Reason} -> 	throw({Reason});
        {ok, Res}       ->  Res; 
        Res             ->	Res
    end.

%% disp_read(Location, Cmd, Client, Binary, Module) ->
%% 	if Cmd =/= 10006 ->
%% 		?INFO_MSG("~s_read_~p[~p, ~p]: ~p / ~p / ~p ",[misc:time_format(now()), Location,  
%% 												  Client#client.player_id, Client#client.player_pid, 
%% 												  Cmd, Binary, Module]);
%%    	true -> no_out
%% 	end.	