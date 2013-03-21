%%%----------------------------------------
%%% @Module  : misc
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 常用函数
%%%----------------------------------------

-module(misc).
 
%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").

%%
%% Exported Functions
%%

-compile(export_all).

%%
%% API Functions
%%
%% get the pid of a registered name
whereis_name({local, Atom}) -> 
	erlang:whereis(Atom);

whereis_name({global, Atom}) ->
	global:whereis_name(Atom).
 
register(local, Name, Pid) ->
	erlang:register(Name, Pid);

register(global, Name, Pid) ->
	global:re_register_name(Name, Pid);

register(unique,Name,Pid) ->
	global:register_name(Name, Pid).

unregister(Name) ->
	global:unregister_name(Name).

is_process_alive(Pid) ->    
	try 
		if is_pid(Pid) ->
     			case rpc:call(node(Pid), erlang, is_process_alive, [Pid]) of
					{badrpc, _Reason}  -> false;
					Res -> Res
				end;
			true -> false
		end
	catch 
		_:_ -> false
	end.

%% time format
one_to_two(One) -> io_lib:format("~2..0B", [One]).

%% @doc get the time's seconds for integer type
%% @spec get_seconds(Time) -> integer() 
get_seconds(Time)->
	{_MegaSecs, Secs, _MicroSecs} = Time, 
	Secs.
	
time_format(Now) -> 
	{{Y,M,D},{H,MM,S}} = calendar:now_to_local_time(Now),
	lists:concat([Y, "-", one_to_two(M), "-", one_to_two(D), " ", 
						one_to_two(H) , ":", one_to_two(MM), ":", one_to_two(S)]).
date_format(Now) ->
	{{Y,M,D},{_H,_MM,_S}} = calendar:now_to_local_time(Now),
	lists:concat([Y, "-", one_to_two(M), "-", one_to_two(D)]).
date_hour_format(Now) ->
	{{Y,M,D},{H,_MM,_S}} = calendar:now_to_local_time(Now),
	lists:concat([Y, "-", one_to_two(M), "-", one_to_two(D), " ", one_to_two(H)]).
date_hour_minute_format(Now) ->
	{{Y,M,D},{H,MM,_S}} = calendar:now_to_local_time(Now),
	lists:concat([Y, "-", one_to_two(M), "-", one_to_two(D), " ", one_to_two(H) , "-", one_to_two(MM)]).
%% split by -
minute_second_format(Now) ->
	{{_Y,_M,_D},{H,MM,_S}} = calendar:now_to_local_time(Now),
	lists:concat([one_to_two(H) , "-", one_to_two(MM)]).

hour_minute_second_format(Now) ->
	{{_Y,_M,_D},{H,MM,S}} = calendar:now_to_local_time(Now),
	lists:concat([one_to_two(H) , ":", one_to_two(MM), ":", one_to_two(S)]).

%%设定发送进程数量为2,同一进程下 循环发送。
%%原实现方式
%%	  Rand = random:uniform(?SEND_MSG),
%%    lists:nth(Rand, S).
rand_to_process(S) ->
	[Pid1, Pid2] = S,
	case get(rand_to_process) of
		undefined ->
			put(rand_to_process,1),
			Pid1;
		_ ->
			put(rand_to_process,undefined),
			Pid2
	end.


player_process_name(PlayerId) when is_integer(PlayerId) or is_atom(PlayerId) ->
	lists:concat([p_p_, PlayerId]);
player_process_name(PlayerId) when is_list(PlayerId) ->
	lists:flatten(["p_p_"|PlayerId]);
player_process_name(PlayerId) when is_binary(PlayerId) ->
	lists:concat([p_p_,tool:md5(PlayerId)]).

%% 在一账号多个角色的情况下，需要按账号ID判断唯一性
player_process_accountname(AccountId) when is_integer(AccountId) or is_atom(AccountId) ->
	lists:concat([p_a_, AccountId]);
player_process_accountname(AccountId) when is_list(AccountId) ->
	lists:flatten(["p_a_"|AccountId]);
player_process_accountname(AccountId) when is_binary(AccountId) ->
	lists:concat([p_a_,tool:md5(AccountId)]).

%% 创建进程名
create_process_name(Prefix, List) ->
	tool:to_atom(lists:concat(lists:flatten([Prefix] ++ lists:map(fun(T) -> ['_', T] end, List)))).
	
%% 获取来源IP 
get_ip(Socket) ->
	case inet:peername(Socket) of 
		{ok, {PeerIP,_Port}} ->
			ip_to_binary(PeerIP);
		{error, _NetErr} -> 
			""
	end.

ip_to_binary(Ip) ->
	case Ip of 
		{A1,A2,A3,A4} -> 
			[ integer_to_list(A1), "." , integer_to_list(A2), "." , integer_to_list(A3), "." , integer_to_list(A4) ];
		_ -> 
			"-"
	end.

ip_list_to_binary(Data) ->
	case Data of
		[]        -> "";
		undefined -> "-";
		{IP,_PORT} -> ip_to_binary(IP);
		_ when is_list(Data) -> 
			[H|T]=Data,
			[ip_list_to_binary(H), "," , ip_list_to_binary(T) ];
		_ -> "-"
	end. 

get_child_count(Atom) ->
	case whereis_name({local, Atom}) of
		undefined -> 
			0;
		_ ->
			[_,{active, ChildCount},_,_] = supervisor:count_children(Atom),
			ChildCount
	end.

get_child_message_queue_length(Atom) ->
	case whereis_name({local, Atom}) of
		undefined -> 
			[];
		_ ->
			Child_list = supervisor:which_children(Atom),
			lists:map(
		  		fun({Name, Pid, _Type, [Class]})  when is_pid(Pid) ->
					{message_queue_len, Qlen} = erlang:process_info(Pid, message_queue_len),
					{links, Links} = erlang:process_info(Pid, links),
					{Name, Pid, Qlen, Class, length(Links)}
				end,
		  		Child_list)
	end.	

%% --------------------------------------------------------------------
%% Func: get pid info/7
%% Param Process: atom Pid or Pid RegName
%% 		 Top: 0=all result, N=0-N record in the result
%% 		 NeedModule fiter Pid module,[]=all
%% 		 Layer node child layer, 0=all,1=self
%%       MinMsgLen message queue length >= MinMsgLen
%%       MinMemSize pid memory size >= MinMemSize
%%       OrderKey, type atom and the value is: msglen,memory
%% Purpose: get pid info
%% Returns: {ok,Result,Count} Result=[{Pid,RegName,MemSize,MessageLength,Module},...]
%% 			{error,Reason}
%% --------------------------------------------------------------------
get_process_info(Process, Top, NeedModule, Layer, MinMsgLen, MinMemSize, OrderKey) ->
	RootPid =
		if erlang:is_pid(Process) ->
			   Process;
		   true ->
			   case whereis_name({local, Process}) of
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
			AllPidList = get_process_all_pid(RootPid,Layer),
			RsList = get_process_info_detail(NeedModule, AllPidList,[]),
			Len = erlang:length(RsList),
			FilterRsList = 
			case OrderKey of 
				msglen ->
					lists:filter(fun({_,_,_,Qlen,_}) -> Qlen >= MinMsgLen end, RsList);
				memory ->
					lists:filter(fun({_,_,Qmem,_,_}) -> Qmem >= MinMemSize end, RsList);
				_ ->
					lists:filter(fun({_,_,_,Qlen,_}) -> Qlen >= MinMsgLen end, RsList)
			end,
			RsList2 = 
				case OrderKey of
					msglen ->
						lists:sort(fun({_,_,_,MsgLen1,_},{_,_,_,MsgLen2,_}) -> MsgLen1 > MsgLen2 end, FilterRsList);
					memory ->
						lists:sort(fun({_,_,MemSize1,_,_},{_,_,MemSize2,_,_}) -> MemSize1 > MemSize2 end, FilterRsList);
					_ ->
						lists:sort(fun({_,_,_,MsgLen1,_},{_,_,_,MsgLen2,_}) -> MsgLen1 > MsgLen2 end, FilterRsList)
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

%% --------------------------------------------------------------------
%% Func: get_process_info_detail/3
%% Purpose: get pid detail info
%% Returns: [{Pid,RegName,MemSize,MessageLength,Module},...]
%% --------------------------------------------------------------------
get_process_info_detail(_NeedModule, [], Result) -> Result;
get_process_info_detail(NeedModule, [H|T], Result) ->
	Mql = get_process_data({message_queue_len, H}),
	MemSize = get_process_data({memory, H}),
	RegName = get_process_data({registered_name, H}),
	case NeedModule of
		[] ->
			Module =get_process_info_initial_call(H),
%% 			io:format("~p process RegName:~p,Mql:~p,MemSize:~p,Module:~p\n",[H, RegName, Mql, MemSize, Module]),
			get_process_info_detail(NeedModule, T, lists:append(Result, [{H,RegName,MemSize,Mql,Module}]));
		_ ->
			case get_process_info_check_initial_call(NeedModule, H) of
				"" ->
					get_process_info_detail(NeedModule, T, Result);
				Module ->
%% 					io:format("~p process RegName:~p,Mql:~p,MemSize:~p\n",[H, RegName, Mql, MemSize]),
					get_process_info_detail(NeedModule, T, lists:append(Result, [{H,RegName,MemSize,Mql,Module}]))
					
			end
	end.

%% --------------------------------------------------------------------
%% Func: get_process_info_check_initial_call/2
%% Purpose: check inital call
%% Returns: true or false
%% --------------------------------------------------------------------
get_process_info_check_initial_call(NeedModule, Pid) ->
	DictionaryList = get_process_data({dictionary, Pid}),
%% 	io:format("Dictionary List:~p\n",[DictionaryList]),
	case proplists:lookup('$initial_call', DictionaryList) of
		{'$initial_call',{Module, _, _}} ->
%% 			io:format("~p found initial_call Module=~p\n",[Pid,Module]),
			case lists:member(Module, NeedModule) of
				true ->
					Module;
			   _ ->
				   ""
			end;
		_ ->
			""
	end.
%% --------------------------------------------------------------------
%% Func: get_process_info_initial_call/1
%% Purpose: get initial call
%% Returns: true or false
%% --------------------------------------------------------------------
get_process_info_initial_call(Pid) ->
	DictionaryList = get_process_data({dictionary, Pid}),
%% 	io:format("Dictionary List:~p\n",[DictionaryList]),
	case proplists:lookup('$initial_call', DictionaryList) of
		{'$initial_call',{Module, _, _}} ->
			Module;
		_ ->
			""
	end.
%% --------------------------------------------------------------------
%% Func: get_process_all_pid/1
%% Purpose: get pid and child pid, Layer 0 all 1 fisrt
%% Returns: [Pid,...]
%% --------------------------------------------------------------------
get_process_all_pid(RootPid, Layer) -> 
	ParentPid =get_process_parent_pid(RootPid),
	RootLinkPidList = get_process_data({links, RootPid}),
%% 	io:format("~p links process links~p,and parent pid is~p\n",[RootPid, RootLinkPidList, ParentPid]),
	case RootLinkPidList of
		[] ->
			[RootPid];
		_ ->
			if erlang:length(RootLinkPidList) =:= 1 ->
		   		[RootPid];
	   		true ->
		   		NewLinkPidList = 
				if erlang:is_pid(ParentPid) ->
		   				lists:delete(ParentPid, RootLinkPidList);
	   				true ->
		   				RootLinkPidList
				end,
				LinkPidList = lists:delete(RootPid, NewLinkPidList),
				
%% 				io:format("~p do handle links process links~p\n",[RootPid,LinkPidList]),
				if  Layer =:= 1 ->
						[RootPid];
					true ->
						get_process_all_pid(LinkPidList, Layer, [RootPid], 2)
				end
			end
	end.
	
get_process_all_pid([], _Layer, ResultList, _Index) -> ResultList;
get_process_all_pid([H|T], Layer, ResultList, Index) -> 
%% 	io:format("get process all pid Index=~p", [Index]),
	if erlang:is_pid(H) ->
			ParentPid =get_process_parent_pid(H),
			RootLinkPidList = get_process_data({links, H}),
%% 			io:format("~p links process links~p,and parent pid is~p\n",[H, RootLinkPidList, ParentPid]),
			case RootLinkPidList of
				[] ->
					get_process_all_pid(T, Layer, lists:append(ResultList, [H]), Index);
				_ ->
					if erlang:length(RootLinkPidList) =:= 1 ->
						   get_process_all_pid(T, Layer, lists:append(ResultList, [H]), Index);
					   true ->
						   NewLinkPidList =
							   if erlang:is_pid(ParentPid) ->
									  lists:delete(ParentPid, RootLinkPidList);
								  true ->
									  RootLinkPidList
							   end,
						   LinkPidList = lists:delete(H, NewLinkPidList),
						   NewIndex = Index + 1,
						   SubResultList =
						   if NewIndex > Layer, Layer =/= 0 ->
								  [H];
							  true ->
								  get_process_all_pid(LinkPidList, Layer, [H], NewIndex)
						   end,
						   get_process_all_pid(T, Layer, lists:append(ResultList, SubResultList), Index)
					end
			end;
	   true ->
		   get_process_all_pid(T, Layer, ResultList, Index)
	end.

%% --------------------------------------------------------------------
%% Func: get_process_parent_pid/1
%% Purpose: get the pid parent pid
%% Returns: Pid or ignore
%% --------------------------------------------------------------------
get_process_parent_pid(Pid) ->
	DictionaryList = get_process_data({dictionary, Pid}),
%% 	io:format("Dictionary List:~p\n",[DictionaryList]),
	case proplists:lookup('$ancestors', DictionaryList) of
		{'$ancestors',[ParentPid|_]} ->
%% 			io:format("~p found parent pid is ~p\n",[Pid,ParentPid]),
			if erlang:is_pid(ParentPid) ->
				   ParentPid;
			   	true ->
					whereis_name({local, ParentPid})
			end;
		_ ->
			ignore
	end.
%% --------------------------------------------------------------------
%% Func: get_process_data/1
%% Purpose: get the dictionary info of the process
%% Returns: [] or DictionaryList
%% --------------------------------------------------------------------
get_process_data({dictionary, Pid}) ->
	try erlang:process_info(Pid, dictionary) of
		{_, DList} -> DList;
		_ -> []
	catch 
		_:_ -> []
	end;
%% --------------------------------------------------------------------
%% Func: get_process_data/1
%% Purpose: get the links info of the process
%% Returns: [] or LinksList
%% --------------------------------------------------------------------
get_process_data({links, Pid}) ->
	try erlang:process_info(Pid,links) of
		{_, Links} -> lists:filter(fun(I) -> erlang:is_pid(I) end, Links);
		_ -> []
	catch 
		_:_ -> []
    end;
%% --------------------------------------------------------------------
%% Func: get_process_data/1
%% Purpose: get the message queue length info of the process
%% Returns: 0 or Length
%% --------------------------------------------------------------------
get_process_data({message_queue_len, Pid}) ->
	try erlang:process_info(Pid, message_queue_len) of
		{message_queue_len, Length} -> Length;
		_ -> 0
	catch 
		_:_ -> 0
    end;
%% --------------------------------------------------------------------
%% Func: get_process_data/1
%% Purpose: get the memory size info of the process
%% Returns: 0 or MemorySize
%% --------------------------------------------------------------------
get_process_data({memory, Pid}) ->
	try erlang:process_info(Pid, memory) of
		{memory, Size} -> Size;
		_ -> 0
	catch 
		_:_ -> 0
    end;
%% --------------------------------------------------------------------
%% Func: get_process_data/1
%% Purpose: get the registered name info of the process
%% Returns: "" or RegisteredName
%% --------------------------------------------------------------------
get_process_data({registered_name, Pid}) ->
	try erlang:process_info(Pid, registered_name) of
		{registered_name, RegName} -> RegName;
		_ -> ""
	catch 
		_:_ -> ""
    end.
%% --------------------------------------------------------------------
%% Func: get_online_role_count/1
%% Purpose: get online role count
%% Returns: {0,0} or {SpecsCount,ActiveCount}
%% --------------------------------------------------------------------
%% get_online_role_count(AccountList) ->
%% 	case AccountList of
%% 		AccAtom when is_atom(AccAtom) ->
%% 			get_online_role_count([AccAtom], 0, 0);
%% 		AccList when is_list(AccList) ->
%% 			get_online_role_count(AccList, 0, 0)
%% 	end.
%% 
%% get_online_role_count([], Count, ActiveCount) ->{Count,ActiveCount};
%% get_online_role_count(Ports, Count, ActiveCount) ->
%% 	[AccountSupName|T] = Ports,
%% 	{SNum,ANum} = get_online_role_count_item(AccountSupName),
%% 	get_online_role_count(T, Count + SNum, ActiveCount + ANum).
%% 
%% get_online_role_count_item(SupName) ->
%% 	try supervisor:count_children(SupName) of
%% 		[] -> {0,0};
%% 		SupList when erlang:is_list(SupList) ->
%% %% 			io:format("SupList ~p ~n", [SupList]),
%% 			SCount = 
%% 			case proplists:lookup(specs, SupList) of
%% 				{specs, SNum} -> SNum;
%% 				_ -> 0
%% 			end,
%% 			ACount = 
%% 			case proplists:lookup(active, SupList) of
%% 				{active, ANum} -> ANum;
%% 				_ -> 0
%% 			end,
%% 			{SCount,ACount};
%% 		_ -> {0,0}
%% 	catch 
%% 		_:_ -> {0,0}
%% 	end.

%% --------------------------------------------------------------------
%% Func: replace_all/4
%% Purpose: Subject,RE,Replacement,Options
%% Returns: List
%% --------------------------------------------------------------------
replace_all(Subject,RE,Replacement,Options) ->
	ReSubject = re:replace(Subject, RE, Replacement, Options),
	case ReSubject =:= Subject of
		false ->
			replace_all(ReSubject,RE,Replacement,Options);
		_ ->
			ReSubject
	end.

pg2_get_members(Pg2_name) ->
    L = case pg2:get_members(Pg2_name) of 
            {error, _} ->
                timer:sleep(100),
                pg2:get_members(Pg2_name);
            Other when is_list(Other) ->
                Other
        end,
    if  not is_list(L) -> [];
        true -> lists:usort(L)
    end.

get_http_content(Url) ->
	case httpc:request(Url) of
		{ok, {_Status, _Headers, Raw}} ->
			Raw;
		{error, _Reason} ->
			""
	end.

cancel_timer(TimerKey) ->
	case get(TimerKey) of
   		undefined -> 
			skip;
		Timer ->	
       		erlang:cancel_timer(Timer)
	end.

write_system_info(Pid, Module, Args) ->
	ets:insert(?ETS_SYSTEM_INFO, {Pid, Module, Args}).
	
delete_system_info(Pid) ->
	ets:delete(?ETS_SYSTEM_INFO, Pid).	

write_monitor_pid(Pid, Module, Args) ->
	ets:insert(?ETS_MONITOR_PID, {Pid, Module, Args}).
	
delete_monitor_pid(Pid) ->
	catch ets:delete(?ETS_MONITOR_PID, Pid).	

%%取进程信息
%%Type registered_name,current_function,message_queue_len,messages,reductions,memory,
get_pid_info(Pid,Type) ->
	erlang:process_info(Pid,Type).
		  

