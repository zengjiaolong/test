%%%-----------------------------------
%%% @Module  : lib_send
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 发送消息
%%%-----------------------------------
-module(lib_send).
-include("record.hrl").
-include("common.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-define(SOCKET_BROADCAST, 2).										%% 默认广播SOCKET
-compile(export_all).

%%发送信息给指定socket玩家.
%%Socket:游戏Socket
%%Bin:二进制数据
send_one(Socket, Bin) ->
    gen_tcp:send(Socket, Bin).

%% 发送信息给指定sid玩家
%% PidSend 游戏发送进程PidSend
%% BinData 二进制数据
send_to_sid(PidSend, BinData) ->
	case PidSend of
		[PidSend1, PidSend2] ->
			case get(rand_to_process) of
				undefined ->
					put(rand_to_process, 1),
					PidSend1 ! {send, BinData};
				_ ->
					put(rand_to_process, undefined),
					PidSend2 ! {send, BinData}
			end;
		_ ->
			skip
	end.

%% 发送到指定的socket pid 进程
send_to_sids([Pid_send1, _Pid_send2, _Pid_send3], Bin, 1)  ->
	Pid = (catch misc:rand_to_process(Pid_send1)),
	case is_pid(Pid) of
		true ->
			Pid ! {send, Bin};
		false ->
			skip
	end;
send_to_sids([Pid_send1, Pid_send2, Pid_send3], Bin, 2) ->
	Pid = (catch misc:rand_to_process(Pid_send2)),
	case is_pid(Pid) of
		true ->
			Pid ! {send, Bin};
		false ->
			send_to_sids([Pid_send1, Pid_send2, Pid_send3], Bin, 1)
	end;
send_to_sids([Pid_send1, Pid_send2, Pid_send3], Bin, 3) ->
	Pid = (catch misc:rand_to_process(Pid_send3)),
	case is_pid(Pid) of
		true ->
			Pid ! {send, Bin};
		false ->
			send_to_sids([Pid_send1, Pid_send2, Pid_send3], Bin, 1)
	end;
send_to_sids([_Pid_send1,_Pid_send2,_Pid_send3], _Bin, _) ->
	skip;
send_to_sids([], _Bin, _) ->
	skip.

%%发送信息给指定玩家名.
%%Nick:名称 
%%Bin:二进制数据.
send_to_nick(Nick, Bin) ->
   case lib_player:get_role_id_by_name(Nick) of
		null -> no_player;
		PlayerId -> send_to_uid(PlayerId, Bin)
   end.

%% 发送信息给指定玩家ID.
%% PlayerId 玩家ID
%% BinData 二进制数据.
send_to_uid(PlayerId, BinData) ->
	PlayerSendName = misc:create_process_name(pid_send, [PlayerId, 2]),
	case misc:whereis_name({global, PlayerSendName}) of
		PidSend when is_pid(PidSend) ->
			PidSend ! {send, BinData};
		_ ->
			PlayerProcessName = misc:player_process_name(PlayerId),
			case misc:whereis_name({global, PlayerProcessName}) of
				Pid when is_pid(Pid) ->
					gen_server:cast(Pid, {send_to_sid, BinData});
				_ -> 
					skip
			end
	end.

%% 发送信息到本地情景(定时清理灵兽幸运值0，坐骑幸运值1)
%% SceneId 场景ID
%% Bin 数据
send_to_local_scene_for_time(Bin) ->
	MS = ets:fun2ms(fun(T) when T#player.scene =/= 0 -> 
		[
			T#player.other#player_other.pid
		]
	end),
   	L = ets:select(?ETS_ONLINE, MS),
	if L == [] ->
		   skip;
	   true ->
		   if Bin == 0 ->
				  [gen_server:cast(Pid, {'CLEAY_PET_LUCKY_VALUE'}) || [Pid] <- L];
			  Bin == 1 ->
				  [gen_server:cast(Pid, {'CLEAY_MOUNT_LUCKY_VALUE'}) || [Pid] <- L];
			  true ->
				  skip
		   end
	end.


send_to_node(Bin) ->
	MS = ets:fun2ms(fun(P) when P#player.scene =/= 0 -> 
		[
			P#player.other#player_other.pid_send,
			P#player.other#player_other.pid_send2,
			P#player.other#player_other.pid_send3
		]
	end),
   	L = ets:select(?ETS_ONLINE, MS),
	do_broadcast(L, Bin, ?SOCKET_BROADCAST).


send_to_local_scene(SceneId, Bin) ->
	send_to_local_scene(SceneId, Bin, ?SOCKET_BROADCAST).

send_to_local_scene(SceneId, Bin, SocketN) ->
   	MS = ets:fun2ms(fun(T) when T#player.scene == SceneId -> 
		[
			T#player.other#player_other.pid_send,
			T#player.other#player_other.pid_send2,
			T#player.other#player_other.pid_send3
		]
	end),
   	L = ets:select(?ETS_ONLINE, MS),	
   	do_broadcast(L, Bin, SocketN).

%% 发送信息到场景(9宫格区域，不是整个场景)
%% SceneId 场景ID
%% X,Y 坐标
%% Bin 数据
send_to_local_scene(SceneId, X, Y, Bin) ->
	send_to_local_scene(SceneId, X, Y, Bin, ?SOCKET_BROADCAST).

send_to_local_scene(SceneId, X2, Y2, Bin, SocketN) ->
   	MS = ets:fun2ms(fun(T) when T#player.scene == SceneId -> 
		[
			[
				T#player.other#player_other.pid_send, 
				T#player.other#player_other.pid_send2,
				T#player.other#player_other.pid_send3
			],
			T#player.x, 
			T#player.y
		] 
	end),
   	AllUser = ets:select(?ETS_ONLINE, MS),	
	XY2 = lib_scene:get_xy(X2, Y2),	
    F = fun([Sids, X, Y]) ->
		case lib_scene:is_in_area(X, Y, XY2) of
			true ->
				send_to_sids(Sids, Bin, SocketN);
			false ->
				skip
		end
    end,
    [spawn(fun()-> F([Sids, X, Y]) end) || [Sids, X, Y] <- AllUser].

send_to_local_scene_for_event(SceneId, Event) ->
	%%?DEBUG("send_to_local_scene_for_event", []),
	MS = ets:fun2ms(fun(T) when T#player.scene =:= SceneId ->
							T#player.other#player_other.pid
					end),
	AllUser = ets:select(?ETS_ONLINE, MS),
	F = fun(PlayerPid) ->
				gen_server:cast(PlayerPid, Event)
		end,
	[spawn(fun() -> F(Pid) end) || Pid <- AllUser].

%% 场景节点广播
send_to_online_scene(SceneId, Bin) ->
	spawn(fun()->
		MS = ets:fun2ms(fun(P) when P#player.scene == SceneId -> 
			[
				P#player.other#player_other.pid_send, 
				P#player.other#player_other.pid_send2,
				P#player.other#player_other.pid_send3
			]
		end),
	   	AllUser = ets:select(?ETS_ONLINE_SCENE, MS),
		F = fun(SendList) ->
			lib_send:send_to_sids(SendList, Bin, ?SOCKET_BROADCAST)
	    end,
	 	[F(SendList) || SendList <- AllUser]  
	end).
send_to_online_scene(SceneId, X, Y, Bin) ->
	spawn(fun()->
		MS = ets:fun2ms(fun(P) when P#player.scene == SceneId -> 
			[
				[
					P#player.other#player_other.pid_send, 
					P#player.other#player_other.pid_send2,
					P#player.other#player_other.pid_send3
				],
				P#player.x, 
				P#player.y
			] 
		end),
	   	AllUser = ets:select(?ETS_ONLINE_SCENE, MS),	
		XY = lib_scene:get_xy(X, Y),	
	    F = fun([SendList, X1, Y1]) ->
			case lib_scene:is_in_area(X1, Y1, XY) of
				true ->
					lib_send:send_to_sids(SendList, Bin, ?SOCKET_BROADCAST);
				false ->
					skip
			end
	    end,
	   	[F([SendList, X1, Y1]) || [SendList, X1, Y1] <- AllUser]			  
	end).

%%发送信息到氏族
%%GuildId:氏族ID
%%Bin:数据
send_to_guild(GuildId, Bin) ->
    if 
		GuildId > 0 ->
		   lib_guild:send_guild(0 ,0, GuildId, Bin);
        true -> 
           void
    end.

%% 发送信息到组队
%% SendPid 本用户消息发送进程
%% TeamPid 组队PID
%% Bin 数据
send_to_team(SendPid, TeamPid, Bin) ->
	case is_pid(TeamPid) of 
		true ->
			gen_server:cast(TeamPid, {'SEND_TO_MEMBER', Bin});
   		false ->
       		send_to_sid(SendPid, Bin)
    end.
    
%% 发送信息到世界 
%% 添加指定socket接口
send_to_all(Bin) ->
	send_to_all(Bin,?SOCKET_BROADCAST).

send_to_all(Bin,SocketN) ->
    send_to_local_all(Bin,SocketN),
    mod_disperse:broadcast_to_world(ets:tab2list(?ETS_SERVER), Bin).

send_to_local_all(Bin) ->
	send_to_local_all(Bin,?SOCKET_BROADCAST).

send_to_local_all(Bin ,SocketN) ->
	MS = ets:fun2ms(fun(T) -> 
		[
		 	T#player.other#player_other.pid_send,
			T#player.other#player_other.pid_send2,
			T#player.other#player_other.pid_send3
		]
	end),
	L = ets:select(?ETS_ONLINE, MS),	
    do_broadcast(L, Bin ,SocketN).


%% 广播制定选择条件
send_to_ms(BinData, MS) ->
	L = ets:select(?ETS_ONLINE, MS),
    do_broadcast(L, BinData, ?SOCKET_BROADCAST).


%% 发送信息到部落
send_to_realm(Realm, Bin) ->
	send_to_realm(Realm, Bin, ?SOCKET_BROADCAST).

send_to_realm(Realm, Bin,SocketN) ->
    send_to_local_realm(Realm,Bin,SocketN),
    mod_disperse:broadcast_to_realm(ets:tab2list(?ETS_SERVER), Realm, Bin).

send_to_local_realm(Realm, Bin) ->
	send_to_local_realm(Realm, Bin ,?SOCKET_BROADCAST).

send_to_local_realm(Realm, Bin ,SocketN) ->
	MS = ets:fun2ms(fun(T) when T#player.realm == Realm -> 
		[
			T#player.other#player_other.pid_send,
			T#player.other#player_other.pid_send2,
			T#player.other#player_other.pid_send3
		]
	end),
	L = ets:select(?ETS_ONLINE, MS),	
    do_broadcast(L, Bin, SocketN).

%% 对列表中的所有socket进行广播
do_broadcast(L, Bin, SocketN) ->
    [spawn(fun()-> send_to_sids(Sids, Bin, SocketN) end) || Sids <- L].


%% 初始玩家发送信息
init_send_info(PlayerId, PidSend, N) ->
	PlayerSendName = misc:create_process_name(pid_send, [PlayerId, N]),
	misc:unregister(PlayerSendName),
	misc:register(global, PlayerSendName, PidSend).
%% 	misc:register(unique, PlayerSendName, PidSend).

get_player_send_pid(PlayerId, N) ->
	PlayerSendName = misc:create_process_name(pid_send, [PlayerId, N]),
	misc:whereis_name({global, PlayerSendName}).

u(PlayerId, N) ->
	PlayerSendName = misc:create_process_name(pid_send, [PlayerId, N]),
	misc:unregister(PlayerSendName).

