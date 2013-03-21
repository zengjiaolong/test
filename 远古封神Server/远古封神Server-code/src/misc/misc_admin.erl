%%%----------------------------------------
%%% @Module  : misc_admin
%%% @Author  : ygzj
%%% @Created : 2010.10.09
%%% @Description: 系统状态管理和查询
%%%----------------------------------------
-module(misc_admin).
%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

%%
%% Exported Functions
%%
-compile(export_all).

%% 处理http请求【需加入身份验证或IP验证】
treat_http_request(Socket, Packet0) ->
	case gen_tcp:recv(Socket, 0, ?RECV_TIMEOUT) of 
		{ok, Packet} -> 
			case check_ip(Socket) of
				true ->
					P = lists:concat([Packet0, tool:to_list(Packet)]),
					check_http_command(Socket, tool:to_binary(P)),
					{http_request,  ok};
				_ ->
					gen_tcp:send(Socket,  <<"no_right">>),
					{http_request,  no_right}	
			end;
		{error, Reason} -> 
			{http_request,  Reason}
	end.

%% 加入http来源IP验证 
check_ip(Socket) ->
	MyIp = misc:get_ip(Socket),
	lists:any(fun(Ip) ->tool:to_binary(MyIp)=:=tool:to_binary(Ip) end,config:get_http_ips(gateway)).

get_cmd_parm(Packet) ->
	Packet_list = string:to_lower(tool:to_list(Packet)),
	try
		case string:str(Packet_list, " ") of
			0 -> no_cmd;
			N -> CM = string:substr(Packet_list,2,N-2),
				 case string:str(CM, "?") of
					 0 -> [CM, ""];
				 	N1 -> [string:substr(CM,1,N1-1),  string:substr(CM, N1+1)]
				 end
		end
	catch
		_:_ -> no_cmd
	end.


%% 检查分析并处理http指令
check_http_command(Socket, Packet) ->
%% 		——节点信息查询:		/get_node_status?					(ok)
%%		--节点信息查询:		/get_node_info?t=1[cpu]2[memory]3[queue](ok)
%%  	--进程信息查询 		/get_process_info?p=pid					(ok)
%%		--获取进程信息		/get_proc_info?p=<0,1,2> (ok)
%% 		--关闭节点                           /close_nodes?t=1|2
%% 		——设置禁言: 			/donttalk?id=stoptime(分钟)			(ok)
%% 		——解除禁言: 			/donttalk?id=0						(ok)
%% 		——踢人下线：			/kickuser?id						(ok)
%%		——封/开角色：			/banrole?id=1/0						(ok)
%% 		——封/开账号：			/banaccount?accid=1/0				(ok)
%%		——通知客户端增减金钱	/notice_change_money?id=parm
%% 		——GM群发：   			/broadmsg?gmid_content[中文？]		(ok)
%% 		——安全退出游戏服务器：	/safe_quit?node						(ok)
%% 		——请求加载基础数据：	/load_base_data?					(ok)	
%% 		——禁言列表：			/donttalklist?	
%%		——更新诛邪系统物品	/updateboxgoods?						(ok)
%%		——获取在线人数		/online_count?						(ok)
%%		__获取场景人数		/scene_online_count?				(ok)
%%      --紧急广播消息                 /notice_broadcast?id					(ok)
%%      --发系统特殊物品:                 /send_gm_mail?					(ok)
	try
		case get_cmd_parm(Packet) of
			["get_node_status", _] ->
				Data = top(), 
				Data_len = length(tool:to_list(Data)),
				DataFormat = io_lib:format("~s", [Data]),
				if Data_len == 0 ->
					   	gen_tcp:send(Socket, <<"error!">>);
					true -> 
						gen_tcp:send(Socket, DataFormat)
				end;
			["get_node_info",Parm] ->
				[_n, Type] = string:tokens(Parm, "="),
				Data = get_nodes_cmq(1,tool:to_integer(Type)),
				DataFormat = io_lib:format("~p", [Data]),
				Data_len = length(tool:to_list(Data)),
				if Data_len == 0 ->
					   	gen_tcp:send(Socket, <<"error!">>);
					true -> 
						gen_tcp:send(Socket,DataFormat)
				end;
			["get_process_info",Parm]->
				[_,PidList] = string:tokens(Parm,"="),
				Data = get_porcess_info(PidList),
				DataFormat = io_lib:format("~p",[Data]),
				Data_len = length(tool:to_list(Data)),
				if Data_len == 0 ->
					   	gen_tcp:send(Socket, <<"error!">>);
					true -> 
						gen_tcp:send(Socket,DataFormat)
				end;
			["close_nodes",Parm] ->
				[_n,Type] = string:tokens(Parm, "="),
				Data = close_nodes(tool:to_integer(Type)),
				DataFormat = io_lib:format("~p", [Data]),
				gen_tcp:send(Socket,DataFormat);
			["donttalk", Parm] ->		
				[Id, Stoptime] = string:tokens(Parm, "="),
				operate_to_player(misc_admin, donttalk, [list_to_integer(Id), list_to_integer(Stoptime)]),
				gen_tcp:send(Socket, <<"ok!">>),
				ok;
			["kickuser", Parm] ->		
				operate_to_player(misc_admin, kickuser, [list_to_integer(Parm)]),
				gen_tcp:send(Socket, <<"ok!">>),
				ok;	
			["banrole", Parm] ->	
				[Id0, Action0] = string:tokens(Parm, "="),
				Id = list_to_integer(Id0),
				Action = list_to_integer(Action0),
				Action1 =
					if Action < 0 orelse Action >1 ->
						0;
	   					true -> Action
					end,
				db_agent:set_player_status(Id, Action1),
				operate_to_player(misc_admin, banrole, [Id, Action1]),
				gen_tcp:send(Socket, <<"ok!">>),
				ok;		
%%             封平台帐号，如果打开则要修改db_agent:set_user_status(AccId, Action1),	其需要三个参数db_agent:set_user_status(Sn, AccId, Action1)
%% 			["banaccount", Parm] ->		
%% 				[AccId0, Action0] = string:tokens(Parm, "="),
%% 				AccId = list_to_integer(AccId0),
%% 				Action = list_to_integer(Action0),
%% 				Action1 =
%% 						case lists:member(Action, [0,1]) of
%% 							true -> Action;
%% 							_ -> 0
%% 						end,	
%% 				db_agent:set_user_status(AccId, Action1),	
%% 				operate_to_player(misc_admin, banaccount, [AccId, Action1]),
%% 				gen_tcp:send(Socket, <<"ok!">>),
%% 				ok;	
			["notice_change_money", Parm] ->		
				[Id, Action] = string:tokens(Parm, "="),
				operate_to_player(misc_admin, notice_change_money, [list_to_integer(Id),Action]),
				gen_tcp:send(Socket, <<"ok!">>),
				ok;	
			["broadmsg", Parm] ->	
				Content = http_lib:url_decode(Parm),
%%  io:format("broadmsg: ///~p///~p///~p/// ~n",[Parm, Content, tool:to_binary(Content)]),
				lib_chat:broadcast_sys_msg(2, Content),
				gen_tcp:send(Socket, tool:to_binary(Content)),
				ok;			
			["safe_quit", Parm] ->		
				safe_quit(Parm),
				gen_tcp:send(Socket, <<"ok!">>),
				ok;
			["remove_nodes", Parm] ->		
				remove_nodes(Parm),
				gen_tcp:send(Socket, <<"ok!">>),
				ok;
			["notice_broadcast",Parm] ->
%%				io:format("notice_broadcast~p~n",[Parm]),
				notice_broadcast(Parm),
				gen_tcp:send(Socket, <<"ok!">>),
				ok;
			["load_base_data", Parm] ->		
				load_base_data(Parm),
				gen_tcp:send(Socket, <<"ok!">>),
				ok;		
%% 			["updateboxgoods",_Parm] ->
%% 				update_box_goods(),
%% 				gen_tcp:send(Socket,<<"ok!OMG">>),
%% 				ok;
			["online_count", _Parm] ->
				Data = get_online_count(),
				Data_len = length(tool:to_list(Data)),
				if Data_len == 0 ->
					   	gen_tcp:send(Socket, <<"0">>);
					true -> 
						gen_tcp:send(Socket, Data)
				end;
			["scene_online_count",_Parm] ->
				Data = get_scene_online_num(),
				gen_tcp:send(Socket,Data);
			
			%% 双倍经验活动
			["exp_activity", Param] ->
				[StartTime, EndTime] = string:tokens(Param, "="),
				Now = util:unixtime(),
				spawn(fun()-> db_agent:add_exp_activity(StartTime, EndTime, Now) end),
				[gen_server:cast(Pid, {'UPDATE_EXP_ACTIVITY_DATA', StartTime, EndTime}) || Pid <- misc:pg2_get_members(scene_agent)],
				gen_tcp:send(Socket, <<"ok!">>),
				ok;
			%% 更新城战信息
			["update_castle_rush_info1", Param] ->
				gen_server:cast(mod_guild:get_mod_guild_pid_for_apply(), 
                        {apply_asyn_cast, lib_castle_rush, update_castle_rush_king_info, [Param]}),
				gen_tcp:send(Socket, <<"ok!">>),
				ok;
			["send_gm_mail", Param] ->
				[_,RoleId, _,GoodsTypeId, _,GoodsStren, _,TitleHex, _,ContentHex, _,Coin, _,Gold, _, Bind, _, Trade] = string:tokens(Param, "=&"),
				Name =  lib_player:get_role_name_by_id(list_to_integer(RoleId)),
				NameList = [tool:to_list(Name)],
%% 				io:format("RoleId:~p, Name:~p", [RoleId, NameList]),
				FNode = hd(nodes()),
				[{Title, _TKey}] = httpd:parse_query(TitleHex),
%% 				io:format("_TKey:~p, Title:~p", [_TKey, Title]),
				[{Content, _CKey}] = httpd:parse_query(ContentHex),
				Data = {NameList, Title, Content, list_to_integer(GoodsTypeId), list_to_integer(Coin), list_to_integer(Gold), list_to_integer(Bind), list_to_integer(GoodsStren), list_to_integer(Trade)},
				rpc:cast(FNode, mod_disperse, send_mail_goods, [Data]),
%% 				lib_mail_goods:stren_mail_goods(NameList, Title, Content, GoodsTypeId, Coin, Gold, Bind, GoodsStren),
				gen_tcp:send(Socket, <<"ok!">>),
				ok;
			_ -> 
				error_cmd
		end
	catch 
		_:_ -> error
	end.
	
%% 获取在线人数
get_online_count() ->
	Total_user_count = get_online_count(num),
	lists:concat(['online_count:',Total_user_count]).

get_online_count(num) ->
	L = mod_disperse:server_list(),
	Count_list =
    if 
        L == [] ->
            [0];
        true ->
			Info_list =
				lists:map(
			  		fun(S) ->
						{_Node_name, User_count} = 
					  		case rpc:call(S#server.node, mod_disperse, online_state, []) of
								{badrpc, _} ->
                                    {error, 0};
                                [_State, Num, _] ->
                                    {S#server.node, Num}
							end,
						User_count
					end,
			  		L),
			Info_list
    end,
	lists:sum(Count_list).


%% 获取场景在线数
get_scene_online_num() ->
	_Total_scene_user_count=get_scene_online_num(num).

%%获取场景在线数
get_scene_online_num(num) ->
	L = mod_disperse:server_list(),
	Count_list =
		if
			L == [] ->
				[{0,<<>>,0}];
			true ->
					lists:map(
					  fun(S) ->
								  case rpc:call(S#server.node,mod_disperse,scene_online_num,[]) of
									  {badrpc,_}->
										  [];
									  GetList ->
										  GetList
								  end
					  end
					  ,L)
		end,
	FlattenList = lists:flatten(Count_list),
	CountData = lists:foldl(fun count_scene_online_num/2, [], FlattenList),
	F_print = fun({SceneId,SceneName,Num},Str) ->
			lists:concat([Str,'[',tool:to_list(SceneName),']  [',SceneId,']  [',Num,']\t\n'])	
	end,
	lists:foldl(F_print,[],CountData).
					  

count_scene_online_num({SceneId,SceneName,Num},CountInfo) ->
	case lists:keysearch(SceneId, 1, CountInfo) of
		false ->
			[{SceneId,SceneName,Num}|CountInfo];
		{value,{_sceneid,SceneName,Total}} ->
			lists:keyreplace(SceneId, 1, CountInfo,{SceneId,SceneName,Num+Total})
	end.
	
% 获取各节点状态
top() ->
	top(all).
top(Node) ->
	if
		is_integer(Node) ->
			L = lists:usort(mod_disperse:server_list()),
			Filter = fun({_,_,_,_,N,_,_}) ->
							 Key= lists:concat(["game",Node]),
							 case re:run(tool:to_list(N),Key,[caseless]) of
								{match,_} -> 
									true;							 
								 _ ->false
							 end
					 end,
			NL = lists:filter(Filter, L);
		true ->
			NL = lists:usort(mod_disperse:server_list())
	end,
	topNode(NL).
	
topNode(NoldeList) ->
	case get_node_info_list(NoldeList) of
		{ok, Node_info_list} ->
			Count_list =
				lists:map(
				  fun({_Node_status, _Node_name, User_count, _Node_info})->
						  User_count
				  end,
				  Node_info_list),	
			Total_user_count = lists:sum(Count_list),	
			Node_ok_list =
				lists:map(
				  fun({Node_status, _Node_name, _User_count, _Node_info})->
						  case Node_status of
							  fail -> 0;
							  _ ->  1
						  end
				  end,
				  Node_info_list),	
			Total_node_ok = lists:sum(Node_ok_list),
			Total_node = length(Node_info_list),
			NodesErr = 
				case Total_node_ok =:= Total_node of
					true -> 0;
					_ -> Total_node - Total_node_ok
				end,			
			lists:foldl(fun node_info_format_view/2, [0,Total_node,Total_user_count,NodesErr],Node_info_list);
		_ ->
			io:format("GET_NODES_INFO_ERROR!~n",[])
	end.


%% 获取节点列表
get_node_info_list() ->
	L = lists:usort(mod_disperse:server_list()),
	get_node_info_list(L).

get_node_info_list(L) ->
	Info_list =
		lists:map(
	  		fun(S) ->
				{Node_status, Node_name, User_count} = 
			  		case rpc:call(S#server.node, mod_disperse, online_state, []) of
						{badrpc, _} ->
                              {fail, S#server.node, 0};
                       [_State, Num, _] ->
                              {ok,   S#server.node, Num}
					end,	
				Node_info = 
						case rpc:call(S#server.node, misc_admin, node_info, []) of
				  			{ok, Node_info_0} ->
								Node_info_0;
							_ ->
								error
						end,							
				{Node_status, Node_name, User_count, Node_info}
			end,
	  		L),
	%%{ok, Gateway_node_info} = misc_admin:node_info(),
	{ok, Info_list}.

%%格式化打印数据显示
%%[
%%	 Info_log_level,[Host_tcp,Port_tcp,Start_time],[PoolId_mongo, Host_mongo, Port_mongo, DB_mongo, EmongoSize_mongo],
%%	 [PoolId_mongo_slave, Host_mongo_slave, Port_mongo_slave, DB_mongo_slave, EmongoSize_mongo_slave],
%%	 Stat_info_socket_out,Stat_info_db_op,Info_process_queue_top,Info_process_memory_top,System_process_info,System_memory_info,System_other_info,
%%	 Info_scene,Info_dungeon
%%	 ].
node_info_format_view(NodeData,[N,NodesNum,Total_user_count,NodeErr]) ->
	case N of
		0 ->
		io:format("############### YGFS_GAME_INFO ###############~n",[]),
		io:format("Nodes_count:~p~n",[NodesNum]),
		io:format("Total_connections:~p~n",[Total_user_count]),
		io:format("Error_Node_num:~p~n",[NodeErr]);
	    _ ->
		   skip
	end,
	io:format("-----------------------------------------------------------------------~n",[]),
	case NodeData of
		{_Node_status,Node_name,User_count,Node_info} ->
			case Node_info of
				[
	 				SceneUserCount,Info_log_level,[Host_tcp,Port_tcp,Start_time],[PoolId_mongo, Host_mongo, Port_mongo, DB_mongo, EmongoSize_mongo],
	 				[PoolId_mongo_slave, Host_mongo_slave, Port_mongo_slave, DB_mongo_slave, EmongoSize_mongo_slave],
	 				Stat_info_socket_out,Stat_info_db_op,Info_process_queue_top,Info_process_memory_top,System_process_info,System_memory_info,System_other_info,
	 				Info_scene,Info_dungeon
	 			] -> 
					case Start_time of
						{M,S,_} ->
							St = M * 1000000 + S ;
						true ->
							St = 0
					end,
					io:format("<<<<[~p]<<<<~n",[Node_name]),
					io:format("[User:[~p]]~n",[User_count]),
					io:format("[SceneUser:[~p]]~n",[SceneUserCount]),
					io:format("[Node_start_time:~p]~n",[St]),
					io:format("[Node_log_level:~p]~n",[Info_log_level]),
					io:format("[Ip:~p:~p]~n",[Host_tcp,Port_tcp]),
					io:format("[MongoDb:PoolId:[~p] Host:[~p] Port:[~p] DB:[~p] Size:[~p]]~n",[PoolId_mongo, Host_mongo, Port_mongo, DB_mongo, EmongoSize_mongo]),
					io:format("[MongoSlave:PoolId:[~p] Host:[~p] Port:[~p] DB:[~p] Size:[~p]]~n",[PoolId_mongo_slave, Host_mongo_slave, Port_mongo_slave, DB_mongo_slave, EmongoSize_mongo_slave]),
					case length(Stat_info_socket_out) > 0  of
						true ->
							F_1 = fun(D1) ->
										case D1 of
											[TimeDiff,Cmd,Count,Avg] ->
												io:format("[TopCmd:Cmd:[~p]  avg/sec:[~p / ~p] = ~p]~n",[Cmd,Count,TimeDiff,Avg]);
											 _ ->
												 skip
										end
								  end,
							lists:foreach(F_1, Stat_info_socket_out);
						false ->
							skip
					end,
					case length(Stat_info_db_op) > 0  of
						true ->
							F_2 = fun(D1) ->
										case D1 of
											[TimeDiff,Table,Operation,Count,Avg] ->
												io:format("[TopTable:Table:[~p] op:[~p] avg/sec:[~p / ~p] = ~p]~n",[Table,Operation,Count,TimeDiff,Avg]);
											 _ ->
												 skip
										end
								  end,
							lists:foreach(F_2, Stat_info_db_op);
						false ->
							skip
					end,
					case Info_process_queue_top of
						[0,_] ->skip;
						[Process_queue_List_len,Info_process_queue_list] ->
							case length(Info_process_queue_list) > 0 of
								true ->
									io:format("[ ~p processes being monitored] ~n",[Process_queue_List_len]),
									F_3 = fun(D1) ->
												  case D1 of
														[Name,PidList,Qlen,Mlen,_Messages] ->
															io:format("[MessageQueueTop5:Name:[~p] PidList:[~p] Q:[~p] M:[~p]]~n",[Name,PidList,Qlen,Mlen]);
													  _ ->
														  skip
												  end
										  end,
									lists:foreach(F_3, Info_process_queue_list);
								false ->
									skip
							end
					end,
					case Info_process_memory_top of
						[0,_] ->skip;
						[Process_memory_List_len,Info_process_memory_list] ->
							case length(Info_process_memory_list) > 0 of
								true ->
									io:format("[ ~p processes being monitored] ~n",[Process_memory_List_len]),
									F_4 = fun(D1) ->
												  case D1 of
														[Name,PidList,Qlen,Mlen,_Messages] ->
															io:format("[MemoryTop5:Name:[~p] PidList:[~p] Q:[~p] M:[~p]]~n",[Name,PidList,Qlen,Mlen]);
													  _ ->
														  skip
												  end
										  end,
									lists:foreach(F_4, Info_process_memory_list);
								false ->
									skip
							end
					end,
					case System_process_info of
						[ProcessNum,ProcessLimit,Ports] ->
							io:format("[ProcessInfo:TotalPorcess:[~p]  Limit:[~p]  Ports:[~p]]~n",[ProcessNum,ProcessLimit,Ports]);
						_ ->
							skip
					end,
					case System_memory_info of
						[Tm,Pm,Um,Sm,Am,Aum,Bm,Cm,Em] ->
							io:format("[MemoryInfo:Total:[~p]  Porcess:[~p] Porcess_used:[~p] ~n System:[~p]  Atom:[~p]  Atom_used:[~p] ~n Binary:[~p]  Code:[~p] Ets:[~p]]~n",[Tm,Pm,Um,Sm,Am,Aum,Bm,Cm,Em]);
						_ ->
							skip
					end,
					case System_other_info of
						[Wallclock_time,Run_queue,Input,Output] ->
							io:format("[SystemOther:Wallclock:[~p]  Run_queue:[~p]  Input:[~p]  Output:[~p]]~n",[Wallclock_time,Run_queue,Input,Output]);
						_ ->
							skip
					end,
					case length(Info_scene) > 0 of 
						true ->
							F_5 = fun(SceneD) ->
									case SceneD of
										[SceneId,WorkerId,Num] ->
											io:format("[Scene:[~p(~p)(~p)]]",[SceneId,WorkerId,Num]);
										_ ->
											skip
									end
								  end,
							lists:foreach(F_5, Info_scene),
							io:format("~n",[]);
						false ->
							skip
					end,
					case length(Info_dungeon) > 0 of
						true ->
							F_6 = fun(DunD) ->
										  case DunD of
											  [SceneId,DungeonId,Num] ->
												  io:format("[Dungeon:[~p(~p)(~p)]]",[SceneId,DungeonId,Num]);
											  _ ->
												  skip
										  end
								  end,
							lists:foreach(F_6, Info_dungeon),
							io:format("~n",[]);
						false ->
							skip
					end;
				_ ->
					io:format("Node_info_error:~p~n",[?LINE])
			end;
		_ ->
			io:format("Node_data_error:~p~n",[?LINE])
	end,
	io:format("-----------------------------------------------------------------------~n",[]),
	[N+1,NodesNum,Total_user_count,NodeErr].
	
				
				




%% 获取本节点的基本信息
node_info() ->
  	Info = get_node_info(),
 	{ok, Info}.

get_node_info() ->
	Info_log_level = config:get_log_level(server),
	SceneUserCount = ets:info(ets_online_scene,size),
	[Host_tcp,Port_tcp,Start_time] = 
	case catch(ets:match(?ETS_SYSTEM_INFO,{'_',tcp_listener,'$3'})) of
		[[{_Host_tcp, _Port_tcp, _Start_time}]] ->
			[_Host_tcp,_Port_tcp,_Start_time];
		_ ->
			[0,0,0]
	end,
	[PoolId_mongo, Host_mongo, Port_mongo, DB_mongo, EmongoSize_mongo] =
	case catch(ets:match(?ETS_SYSTEM_INFO,{'_',mongo,'$3'})) of
		[[{_PoolId_mongo, _Host_mongo, _Port_mongo, _DB_mongo, _EmongoSize_mongo}]] ->
			[_PoolId_mongo, _Host_mongo, _Port_mongo, _DB_mongo, _EmongoSize_mongo];
		_ ->
			[0,0,0,0,0]
	end,
	[PoolId_mongo_slave, Host_mongo_slave, Port_mongo_slave, DB_mongo_slave, EmongoSize_mongo_slave] =
	case catch(ets:match(?ETS_SYSTEM_INFO,{'_',mongo_slave,'$3'})) of
		[[{_PoolId_mongo_slave, _Host_mongo_slave, _Port_mongo_slave, _DB_mongo_slave, _EmongoSize_mongo_slave}]] ->
			[_PoolId_mongo_slave, _Host_mongo_slave, _Port_mongo_slave, _DB_mongo_slave, _EmongoSize_mongo_slave];
		_ ->
			[0,0,0,0,0]
	end,
	%%[[TimeDiff,Cmd,Count,Avg]|..]
	Stat_info_socket_out = 
	case ets:info(?ETS_STAT_SOCKET) of
				undefined ->
					[];
				_ ->
					Stat_list_socket_out = ets:match(?ETS_STAT_SOCKET,{'$1', socket_out , '$3','$4'}),
					Stat_list_socket_out_1 = lists:sort(fun([_,_,Count1],[_,_,Count2]) -> Count1 > Count2 end, Stat_list_socket_out),
					Stat_list_socket_out_2 = lists:sublist(Stat_list_socket_out_1, 5),
					lists:map( 
	  					fun(Stat_data) ->
							case Stat_data of				
								[Cmd, BeginTime,Count] ->
									TimeDiff = round(timer:now_diff(erlang:now(), BeginTime)/(1000*1000)+1),
									Avg = round(Count/TimeDiff),
									[TimeDiff,Cmd,Count,Avg];
								_->
									[]
							end 
	  					end, 
						Stat_list_socket_out_2)				
	end	,
	%%[[TimeDiff,Table,Operation,Count,Avg]|..]
	Stat_info_db_op =
	case ets:info(?ETS_STAT_DB) of
				undefined ->
					[];
				_ ->
					Stat_list_db = ets:match(?ETS_STAT_DB,{'$1', '$2', '$3', '$4', '$5'}),
					Stat_list_db_1 = lists:sort(fun([_,_,_,_,Count1],[_,_,_,_,Count2]) -> Count1 > Count2 end, Stat_list_db),
					Stat_list_db_2 = lists:sublist(Stat_list_db_1, 15), 
					lists:map( 
	  					fun(Stat_data) ->
							case Stat_data of				
								[_Key, Table, Operation, BeginTime, Count] ->
									TimeDiff = round(timer:now_diff(erlang:now(), BeginTime)/(1000*1000)+1),
									Avg = round(Count/TimeDiff),
									[TimeDiff,Table,Operation,Count,Avg];
								_->
									[0,0,0,0,0]
							end 
	  					end, 
						Stat_list_db_2)			
	end	,
	
	Process_info_detail = get_monitor_process_info_list(),

	Info_process_queue_top = 
		try
			case get_process_info(Process_info_detail, 5, 1, 0, msglen) of 
				{ok, Process_queue_List, Process_queue_List_len} ->
					Info_process_queue_list = 
					lists:map( 
	  					fun({Pid, RegName, Mlen, Qlen, Module, _Other, Messages}) ->
							if 	
								is_atom(RegName) -> 
									[RegName,erlang:pid_to_list(Pid),Qlen,Mlen,Messages];
								is_atom(Module) ->
									[Module,erlang:pid_to_list(Pid),Qlen,Mlen,Messages];
								true ->
									[null,erlang:pid_to_list(Pid),Qlen,Mlen,Messages]
							end	
						end,
					Process_queue_List),
					[Process_queue_List_len,Info_process_queue_list];
				_ ->
					[0,[]]
			end
		catch
			_:_ ->  [0,[]]
		end,
	Info_process_memory_top = 
		try
			case get_process_info(Process_info_detail, 5, 0, 0, memory) of 
				{ok, Process_memory_List, Process_memory_List_len} ->
					Info_process_memory_list = 
					lists:map( 
	  					fun({Pid, RegName, Mlen, Qlen, Module, _Other, Messages}) ->
							if 	is_atom(RegName) -> 
									[RegName,erlang:pid_to_list(Pid),Qlen,Mlen,Messages];
								is_atom(Module) ->
									[Module,erlang:pid_to_list(Pid),Qlen,Mlen,Messages];
								true ->
									[null,erlang:pid_to_list(Pid),Qlen,Mlen,Messages]
							end	
						end,
					Process_memory_List),
					[Process_memory_List_len,Info_process_memory_list];
				_ ->
					[0,[]]
			end
		catch
			_:_ -> [0,[]]
		end,
	System_process_info = [erlang:system_info(process_count),erlang:system_info(process_limit),length(erlang:ports())],

%% 		   total = processes + system
%%         processes = processes_used + ProcessesNotUsed
%%         system = atom + binary + code + ets + OtherSystem
%%         atom = atom_used + AtomNotUsed
%% 
%%         RealTotal = processes + RealSystem
%%         RealSystem = system + MissedSystem
	System_memory_info = [erlang:memory(total),
						  erlang:memory(processes),
						  erlang:memory(processes_used),
						  erlang:memory(system),
						  erlang:memory(atom),
						  erlang:memory(atom_used),
						  erlang:memory(binary),
						  erlang:memory(code),
						  erlang:memory(ets)
						  ],
	{{input,Input},{output,Output}} = statistics(io),
	System_load = mod_disperse:get_system_load(),
	System_other_info = [io_lib:format("~.f", [System_load]),
						 statistics(run_queue),
						 Input,
						 Output
						 ],
		
	Info_scene = 
		try 
			case ets:info(?ETS_MONITOR_PID) of
				undefined ->
					[];
				_ ->
					Stat_list_scene = ets:match(?ETS_MONITOR_PID,{'$1', mod_scene ,'$3'}),
					lists:map( 
	  					fun(Stat_data) ->
							case Stat_data of				
								[_SceneAgentPid, {SceneId, Worker_Number}] ->
									MS = ets:fun2ms(fun(T) when T#player.scene == SceneId  -> 
												[T#player.id] 
												end),
									Players = ets:select(?ETS_ONLINE_SCENE, MS),
									[SceneId,Worker_Number,length(Players)];
								_->
									[0,0,0]
							end 
	  					end, 
						Stat_list_scene)
			end
		catch
			_:_ -> []
		end,
	Info_dungeon = 
		try
			case ets:info(?ETS_MONITOR_PID) of
				undefined ->
					[];
				_ ->
					Stat_list_dungeon = ets:match(?ETS_MONITOR_PID,{'$1', mod_dungeon ,'$3'}),
					lists:map( 
	  					fun(Stat_data) ->
							case Stat_data of				
								[_,{{_,Dungeon_scene_id, Scene_id, _, Dungeon_role_list,_}}] ->
									[Scene_id,Dungeon_scene_id,length(Dungeon_role_list)];
								_->
									[0,0,0]
							end 
	  					end, 
						Stat_list_dungeon)
			end
		catch
			_:_ ->[]
		end,
	[
	 SceneUserCount,Info_log_level,[Host_tcp,Port_tcp,Start_time],[PoolId_mongo, Host_mongo, Port_mongo, DB_mongo, EmongoSize_mongo],
	 [PoolId_mongo_slave, Host_mongo_slave, Port_mongo_slave, DB_mongo_slave, EmongoSize_mongo_slave],
	 Stat_info_socket_out,Stat_info_db_op,Info_process_queue_top,Info_process_memory_top,System_process_info,System_memory_info,System_other_info,
	 Info_scene,Info_dungeon
	 ].
		

get_process_info(Process_info_detail, Top, MinMsgLen, MinMemSize, OrderKey) ->
	case Process_info_detail of
		[] ->
			{error,'error'};
		RsList ->
			Len = erlang:length(RsList),
			FilterRsList = 
			case OrderKey of 
				msglen ->
					lists:filter(fun({_,_,_,Qlen,_,_,_}) -> Qlen >= MinMsgLen end, RsList);
				memory ->
					lists:filter(fun({_,_,Qmem,_,_,_,_}) -> Qmem >= MinMemSize end, RsList);
				_ ->
					lists:filter(fun({_,_,_,Qlen,_,_,_}) -> Qlen >= MinMsgLen end, RsList)
			end,
			RsList2 = 
				case OrderKey of
					msglen ->
						lists:sort(fun({_,_,_,MsgLen1,_,_,_},{_,_,_,MsgLen2,_,_,_}) -> MsgLen1 > MsgLen2 end, FilterRsList);
					memory ->
						lists:sort(fun({_,_,MemSize1,_,_,_,_},{_,_,MemSize2,_,_,_,_}) -> MemSize1 > MemSize2 end, FilterRsList);
					_ ->
						lists:sort(fun({_,_,_,MsgLen1,_,_,_},{_,_,_,MsgLen2,_,_,_}) -> MsgLen1 > MsgLen2 end, FilterRsList)
				end,
			NewRsList = 
				if Top =:= 0 ->
					   RsList2;
				   true ->
					   if erlang:length(RsList2) > Top ->
							  lists:sublist(RsList2, Top);
						  true ->
							  RsList2
					   end
				end,
			{ok,NewRsList, Len}
			
	end.

get_process_info_detail_list(Process, NeedModule, Layer) ->
	RootPid =
		if erlang:is_pid(Process) ->
			   Process;
		   true ->
			   case misc:whereis_name({local, Process}) of
				   undefined ->
					   error;
				   ProcessPid ->
					   ProcessPid
			   end
		end,
	case RootPid of
		error ->
			{error,lists:concat([Process," is not process reg name in the ", node()])};
		_ ->
			AllPidList = misc:get_process_all_pid(RootPid,Layer),
			RsList = misc:get_process_info_detail(NeedModule, AllPidList,[]),
			{ok, RsList}
	end.

get_monitor_process_info_list() ->
		try
			case ets:match(?ETS_MONITOR_PID,{'$1','$2','$3'}) of
				List when is_list(List) ->
					lists:map(
					  	fun([Pid, Module, Pars]) ->
							get_process_status({Pid, Module, Pars})
						end,
						List);	 
				_ ->
					[]
			end
		catch
			_:_ -> []
		end.

%% get_process_status({Pid, Module, Pars}) when Module =/= mcs_role_send ->
%% 	{'', '', -1, -1, '', '', ''};
get_message_queue_len(Pid) ->
	try 
	    case erlang:process_info(Pid, [message_queue_len]) of
			[{message_queue_len, Qlen}] ->	Qlen;
			 _ -> -1
		end
	catch 
		_:_ -> -2
	end.

get_process_status({Pid, Module, _Pars}) ->
%% 	Other = 
%% 		case Module of
%% 			mod_player -> 
%% 				{PlayerId} = Pars,
%% 				lists:concat([PlayerId]);
%% %% 			
%% %% 				{#role_send_state{roleid = Roleid,  client_ip = {P1,P2,P3,P4}, 
%% %% 							rolepid = RolePid, accountpid = AccountPid, 
%% %% 							role_status = Role_status, account_status = Account_status,	  
%% %% 							start_time = StartTime, now_time = CheckTime,priority =Priority,
%% %% 							canStopCount = CanStopCount, lastMsgLen = LastMsgLen,  getMsgError = GetMsgError
%% %% 							}} = Pars,
%% %% 				lists:concat([Roleid,'/',P1,'.',P2,'.',P3,'.',P4,'/',mcs_misc:time_format( StartTime)
%% %% 							,'/',mcs_misc:time_format( CheckTime)
%% %% 							,'/',CanStopCount
%% %% 							,',', LastMsgLen
%% %% 							,',', GetMsgError
%% %% 							,',', Priority
%% %%  							,'/',erlang:is_process_alive(Pid)
%% %% 							,'/R', erlang:pid_to_list(RolePid), '[',Role_status,']_', erlang:is_process_alive(RolePid), '_', get_message_queue_len(RolePid)
%% %% 							,'/A', erlang:pid_to_list(AccountPid), '[',Account_status,']_', erlang:is_process_alive(AccountPid), '_', get_message_queue_len(AccountPid)
%% %% 							]);
%% 			_->
%% 				''
%% 		end,
%% 	Other = %%根据刘哥的方案修改,只处理mod_player----xiaomai
%% 		case Module of
%% 			mod_player -> 
%% 				{PlayerId} = Pars,
%% 				Dic = erlang:process_info(Pid,[dictionary]),
%% 				[{_, Dic1}] = Dic,
%% 				case lists:keyfind(last_msg, 1, Dic1) of 
%% 					{last_msg, Last_msg} -> 
%% 						lists:concat([PlayerId, "__", io_lib:format("~p", Last_msg)]);
%% 					_-> lists:concat([PlayerId])
%% 				end;
%% 			_ ->
%% 				''
%% 		end,

	
	try 
	 case erlang:process_info(Pid, [message_queue_len,memory,registered_name, messages]) of
		[{message_queue_len,Qlen},{memory,Mlen},{registered_name, RegName},{messages, _MessageQueue}] ->
			Messages = '',
%% 			if length(MessageQueue) > 0, Module == mod_player ->
%% 				   Message_Lists = 
%% 				   lists:map(
%% 					 fun({Mclass, Mbody}) ->
%% 							 if is_tuple(Mbody) ->
%% %% 									[Mtype] = lists:sublist(tuple_to_list(Mbody),1),
%% 									[Mtype, Module1, Method1] = lists:sublist(tuple_to_list(Mbody),3),
%% 							 		lists:concat(['            <'
%% 												 ,Mclass,
%% 												 ', ' ,Mtype,
%% 												 ', ',binary_to_list(Module1), 
%% 												 ', ',binary_to_list(Method1),
%% 												 '>\t\n']);
%% 							   true ->
%% 									lists:concat(['            <',Mclass,'>\t\n'])
%% 							 end
%% 					 end,
%% 				   lists:sublist(MessageQueue,5)),				   
%% 				   lists:concat(['/\t\n',Message_Lists,'            ']);
%% 			   true -> ''
%% 			end,
			{Pid, RegName, Mlen, Qlen, Module, 0,Messages};
		_ -> 
			{0, 0, 0, 0, 0, 0, 0 }
	 end
	catch 
		_:_ -> {0,0,0,0, 0, 0 ,0 }
	end.


%% =========================================================================
%%获取所有进程的cpu 内存 队列
get_nodes_cmq(_Node,Type)->
	L = mod_disperse:server_list(),
	Info_list0 =
		if
			L == [] ->
				[];
			true ->
					lists:map(
					  fun(S)  ->
								  case rpc:call(S#server.node,mod_disperse,get_nodes_cmq,[Type]) of
									  {badrpc,_}->
										  [];
									  GetList ->
										  GetList
								  end
					  end
					  ,L)
		end,
	
	try
		Info_list = lists:flatten(Info_list0),
		F_sort = fun(A,B)->					
						 {_,_,{_K1,V1}}=A,
						 {_,_,{_K2,V2}}=B,
						 V1 > V2
				 end,
		Sort_list = lists:sort(F_sort,Info_list),
		F_print = fun(Ls,Str) ->
			lists:concat([Str,tuple_to_list(Ls)])
		end,
		lists:foldl(F_print,[],Sort_list)
	catch _e:_e2 ->
			 %%file:write_file("get_nodes_cmq_err.txt",_e2)
			 ?DEBUG("_GET_NODES_CMQ_ERR:~p",[[_e,_e2]])
	end.

%%查进程信息	
get_porcess_info(Pid_list) ->
	L = mod_disperse:server_list(),
	Info_list0 =
		if
			L == [] ->
				[];
			true ->
				lists:map(
				  fun(S) ->
						  case rpc:call(S#server.node,mod_disperse,get_process_info,[Pid_list]) of
							  {badrpc,_} ->
								  [];
							  GetList ->
								  GetList
						  end
				  end
						 ,
				  L						 
				  )
		end,
	file:write_file("info_1.txt",Info_list0),
	Info_list = lists:flatten(Info_list0),
	F_print = fun(Ls,Str) ->
					  lists:concat([Str,Ls])
			  end,
	lists:foldl(F_print, [],Info_list).

close_nodes(Type) ->
	case Type of
		2 ->
			safe_quit([]);
		_ ->
			nodes()
	end.

%%紧急播报消息
notice_broadcast(Id) ->
	lib_sys_acm:broadcast_acm(list_to_integer(Id)).

%%系统内契使用分析
sys_mem_report() ->
	{{Y, M, D}, _} = erlang:localtime(),
	File1 = "..\\logs\\" ++ integer_to_list(Y) ++ integer_to_list(M) ++ integer_to_list(D) ++ "info.log",
	io:format("File1 si ~p~n",[File1]),
	A = lists:foldl( 
        fun(P, Acc0) -> 
                case is_pid(P) andalso is_process_alive(P)  of
					true ->
						{memory, Mem} = erlang:process_info(P, memory),
						case Mem  > 1000 of
							true ->
								[{P, erlang:process_info(P, registered_name), erlang:process_info(P, memory), erlang:process_info(P, message_queue_len), erlang:process_info(P, current_function), erlang:process_info(P, initial_call)} | Acc0];
							false ->
								[{} |Acc0]
						end;
					false ->
						[]
				end
		end, [], erlang:processes()),
	[B] = io_lib:format("~p", [A]),
	file:write_file(File1, B).


%% ===================针对玩家的各类操作=====================================
operate_to_player(Module, Method, Args) ->
    F = fun(S)->  
			io:format("node__/~p/ ~n",[[S, Module, Method, Args]]),	
			rpc:cast(S#server.node, Module, Method, Args)
    	end,
    [F(S) || S <- ets:tab2list(?ETS_SERVER)],
	ok.

%% 取得本节点的角色状态
get_player_info_local(Id) ->
	case ets:lookup(?ETS_ONLINE, Id) of
   		[] -> [];
   		[R] ->
       		case misc:is_process_alive(R#player.other#player_other.pid) of
           		false -> [];		
           		true -> R
       		end
	end.

%% 设置禁言 或 解除禁言
donttalk(Id, Stop_minutes) ->
	case get_player_info_local(Id) of
		[] -> no_action;
		Player ->
			if Stop_minutes > 0 ->
				Stop_begin_time = util:unixtime(),
				Stop_chat_minutes = Stop_minutes,
				gen_server:cast(Player#player.other#player_other.pid, 
								{set_donttalk, Stop_begin_time, Stop_chat_minutes}),
				db_agent:set_donttalk_status(Id, Stop_begin_time, Stop_chat_minutes),
				ok;
			Stop_minutes == 0 ->
				gen_server:cast(Player#player.other#player_other.pid, 
								{set_donttalk, undefined, undefined}),				
				db_agent:delete_donttalk(Id)
			end
	end.

%% 踢人下线
kickuser(Id) ->
	case get_player_info_local(Id) of
		[] -> no_action;
		Player ->	
    		mod_login:logout(Player#player.other#player_other.pid, 2)		
	end.

%% 封/开角色
banrole(Id, Action) ->
	case get_player_info_local(Id) of
		[] -> no_action;	
		Player ->
			if Action == 1 ->
				gen_server:cast(Player#player.other#player_other.pid,{'SET_PLAYER', [{status,1}]}),
    			mod_login:logout(Player#player.other#player_other.pid, 3)
			end
	end.	

%% 封/开账号
banaccount(Accid, Action) ->
    case db_agent:get_playerid_by_accountid(Accid) of
        null ->
            false;
        Id ->
			case get_player_info_local(Id) of
				[] -> no_action;	
				Player ->
					if Action == 1 ->
						   mod_login:logout(Player#player.other#player_other.pid, 4);
	   					true -> no_action
					end
			end
	end.

%% 通知客户端增减金钱
notice_change_money(Id, Action) ->
	try
		case get_player_info_local(Id) of
			[] -> no_action;
			Player ->			
				[Val1, Val2, Val3, Val4] = string:tokens(Action, "_"),
				Field = case Val1 of
						"gold"  -> 1;
						"coin"  -> 2;
						"cash"  -> 3;
						"bcoin" -> 4;
						_ ->0
					end,
				Optype = case Val2 of
						"add"  -> 1;
						"sub"  -> 2;
						_ ->0
					end,
				Value = list_to_integer(Val3),
				Source = list_to_integer(Val4),
				if Field =/=0, Optype =/=0, Value =/=0 ->
						gen_server:cast(Player#player.other#player_other.pid, {'CHANGE_MONEY', [Field, Optype, Value, Source]});
		 	 		true -> no_action
				end
		end
	catch
		_:_ -> error
	end.
  
%% 安全退出游戏服务器
safe_quit(Node) ->
	yg_gateway:server_stop(),
	case Node of
		[] -> 
			mod_disperse:stop_game_server(ets:tab2list(?ETS_SERVER));
		_ ->
			rpc:cast(tool:to_atom(Node), yg, server_stop, [])
	end,
	ok.

%% 动态撤节点
remove_nodes(NodeOrIp) ->
	case NodeOrIp of
		[] -> 
			io:format("You Must Input Ip or NodeName!!!",[]);
		_ ->
			NI_atom = tool:to_atom(NodeOrIp),
			NI_str = tool:to_list(NodeOrIp),
			case string:tokens(NI_str, "@") of
				[_, _] ->
					rpc:cast(NI_atom, yg, server_remove, []);
				_ ->
					Server = nodes(),
					F = fun(S) ->
							case string:tokens(tool:to_list(S), "@") of
								[_Left, Right] when Right =:= NI_str ->
									rpc:cast(S, yg, server_remove, []);
								_ ->
									ok
							end
						end,
					[F(S) || S <- Server]
			end
	end,
	ok.


%% 请求加载基础数据
load_base_data(Parm) ->
	Parm_1 = 
		case Parm of 
			[] -> [];
			_ -> [tool:to_atom(Parm)]
		end,
	mod_disperse:load_base_data(ets:tab2list(?ETS_SERVER), Parm_1),
	ok.

%% 重新加载基础数据
reload_base_data(Parm) ->
	Parm_1 = 
		case Parm of 
			[] -> [];
			_ -> [tool:to_atom(Parm)]
		end,
	mod_disperse:reload_base_data(ets:tab2list(?ETS_SERVER), Parm_1),
	ok.

%% update_box_goods() ->
%% 	BoxPid = mod_box:get_mod_box_pid(),
%% 	gen_server:cast(BoxPid, {event, update_action}).

%%最好在geteway节点执行
%%查询节点的场景及对应的在线人数(0表示所有节点，其它数字对应相应的节点)
%%返回节点名称，节点在线人数，{场景,场景在线人数}，{场景,场景在线人数}
get_sence_online_info(Num) ->
	L = mod_disperse:server_list(),
	if L == [] -> [];
	   true ->
			L1 = lists:sort(fun(S1,S2) -> S1#server.id > S2#server.id end, L),
			if Num == 0 ->
				   L2 = L1;
			   true ->
				   L2 = lists:filter(fun(S) ->  S#server.id == Num end, L1)
			end,
			if L2 == [] -> [];
			   true ->
				   F = fun(S3)->
						Result = rpc:call(S3#server.node,mod_disperse,get_scene_and_online_sum,[]),
						TotalNum = 						
						case rpc:call(S3#server.node, mod_disperse, online_state, []) of
								{badrpc, _} ->
                                    0;
                                [_State, Num1, _] ->
                                    Num1
							end,
						if Result == [] -> [S3#server.node,TotalNum,[]];
						   true -> [S3#server.node,TotalNum]++Result
						end
					   end,
				   Result1 = [F(S3) ||S3 <- L2],
				   if length(Result1) >= 2 ->
						  Result2 = lists:sort(fun(R1,R2) -> lists:nth(2, R1) > lists:nth(2, R2) end, Result1),
						  Result2;
					  true ->
						  Result1
				   end
			end
	end.





