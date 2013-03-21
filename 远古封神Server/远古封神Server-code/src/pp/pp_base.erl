%%%--------------------------------------
%%% @Module  : pp_base
%%% @Author  : ygzj
%%% @Created : 2010.09.23
%%% @Description:  基础功能
%%%--------------------------------------
-module(pp_base).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%%退出登陆
handle(10001, Status, logout) ->
    gen_server:cast(Status#player.other#player_other.pid, 'LOGOUT'),
    {ok, BinData} = pt_10:write(10001, []),
    lib_send:send_one(Status#player.other#player_other.socket, BinData);

%%心跳包 
%%玩家登陆游戏会获取系统时间，内部定时器自增，通过心跳包发回到服务端做检测，
%%flash定时器变慢的时候通过服务器推送新时间校正
handle(10006, Status, [heartbeat,UnixTime]) ->
	Now = util:unixtime(),
	[PreTime, Num, _TimeList] = get(detect_heart_time),	
	Dist = Now - PreTime,
	[NewNum, NewTimeList] = 
		if
			Dist > 15 ->
				[0, []];
			true ->
				[Num + 1, []]	
		end,
	put(detect_heart_time, [Now, NewNum, NewTimeList]),
	if
		NewNum > 4 ->
			%% 涉嫌使用外挂
			spawn(fun()-> db_agent:insert_kick_off_log(Status#player.id, Status#player.nickname, 7, Now, Status#player.scene, Status#player.x, Status#player.y) end),
			mod_player:stop(Status#player.other#player_other.pid, 10),
			Status2 = Status;
		true ->
			if
				Now - UnixTime > 4 ->
					%%校正系统时间
					{ok,BinData} =pt_10:write(10032,[Now]),
					lib_send:send_one(Status#player.other#player_other.socket, BinData);
				UnixTime - 2 > Now ->
					%% 玩家系统加速了
					ok;
					%%?WARNING_MSG("pp_base_/speed_up: ~p~n",[Status#player.id]);
					%%spawn(fun()-> db_agent:insert_kick_off_log(Status#player.id, Status#player.nickname, 8, Now, Status#player.scene, Status#player.x, Status#player.y) end),
					%%mod_player:stop(Status#player.other#player_other.pid, 8);
				true ->
					skip
			end,
			Status2 = Status#player{
				other = Status#player.other#player_other{
             		heartbeat = Now
				}
          	}
	end,
	%%子socket异常断开检测
	case get({childsocketheartbeat,2}) of
		undefined ->
			NoS2 = true;
		Lt2 when Now - Lt2 > 25 ->
			NoS2 = true;
		_ ->
			NoS2 = false
	end,
	case get({childsocketheartbeat,3}) of
		undefined ->
			NoS3 = true;
		Lt3 when Now - Lt3 > 25 ->
			NoS3 = true;
		_ ->
			NoS3 = false
	end,
	if
		NoS2 == true ->
			Status3 = Status2#player{other=Status2#player.other#player_other{socket2 = undefined,pid_send2 = []}};
		true ->
			Status3 = Status2
	end,
	if
		NoS3 == true ->
			Status4 = Status3#player{other=Status2#player.other#player_other{socket3 = undefined,pid_send3 = []}};
		true ->
			Status4 = Status3
	end,
	Socket2 = Status4#player.other#player_other.socket2,
	Pid_send2 = Status4#player.other#player_other.pid_send2,
	Socket3 = Status4#player.other#player_other.socket3,
	Pid_send3 = Status4#player.other#player_other.pid_send3,
	mod_player:save_online_info_fields(Status4, [{heartbeat, Now},{socket2 ,Socket2},{pid_send2 ,Pid_send2},{socket3 ,Socket3},{pid_send3,Pid_send3}]),
	{ok, change_status, Status4};

%%子socekt心跳包
handle(10030,_Status,[heartbeat,SocketN]) ->
	Now = util:unixtime(),
	put({childsocketheartbeat,SocketN},Now),
	ok;

%%子socekt断开通知
handle(10031,Status,[child_socket_break,N]) ->
	gen_server:cast(Status#player.other#player_other.pid, {'SOCKET_CHILD_LOST', N}),
	ok;

handle(_Cmd, _Status, _Data) ->
    ?DEBUG("pp_base no match", []),
    {error, "pp_base no match"}.
