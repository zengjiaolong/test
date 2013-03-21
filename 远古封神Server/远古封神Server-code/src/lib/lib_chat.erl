%%%-----------------------------------
%%% @Module  	: lib_chat
%%% @Author  	: ygzj
%%% @Created 	: 2010.10.14
%%% @Description: 聊天  
%%%-----------------------------------
-module(lib_chat).
-compile(export_all).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-define(SOCKET_CHAT,3).
%% 处理世界聊天
chat_world(Status, [Data]) ->
   	case gmcmd:cmd(Status,Data) of
		is_cmd -> ok;
		_ ->
		if Status#player.lv < 1 ->  %%检查等级
		   	{ok, BinData} = pt_11:write(11011, [4, 14]),
		   	lib_send:send_one(get_socket(Status), BinData),
		   	ok;
	   	true ->
		    %%检查禁言情况
			[Can_chat,  Ret] = check_donttalk(Status#player.id),
			case Can_chat of
				true ->	%%可以聊天
		   				%%检查聊天间隔
		    			case check_chat_interval(previous_chat_time_world, 10) of
				 			true -> 
    							Data1 = [Status#player.id, Status#player.nickname, Status#player.career, Status#player.realm, Status#player.sex, 
										 Status#player.vip,Status#player.state,Data],
    							{ok, BinData} = pt_11:write(11010, Data1),
    							lib_send:send_to_all(BinData,?SOCKET_CHAT);
				 			false ->
		   						{ok, BinData} = pt_11:write(11011, [1, 10]),
		   						lib_send:send_one(get_socket(Status), BinData)	
						end;
				_ ->	%%不能聊天
		   			{ok, BinData} = pt_11:write(11011, [Ret, 0]),
		   			lib_send:send_one(get_socket(Status), BinData),						
					ok
			end
		end
	end.

%% 处理部落聊天
chat_realm(Status, [Data]) ->
   	case gmcmd:cmd(Status,Data) of
		is_cmd -> ok;
		_ ->
		%%检查禁言情况
		[Can_chat,  Ret] = check_donttalk(Status#player.id),
		case Can_chat of
			true ->	%%可以聊天
				%%检查聊天间隔
    			case check_chat_interval(previous_chat_time_realm, 2) of
					true -> 
						Data1 = [Status#player.id, Status#player.nickname, Status#player.career, Status#player.realm, Status#player.sex,
								 Status#player.vip, Status#player.state, Data],
						{ok, BinData} = pt_11:write(11020, Data1),
		 				lib_send:send_to_realm(Status#player.realm, BinData,?SOCKET_CHAT);
					false ->
						{ok, BinData} = pt_11:write(11021, [1, 2]),
						lib_send:send_one(get_socket(Status), BinData)	
				end;
			_ ->	%%不能聊天
				{ok, BinData} = pt_11:write(11021, [Ret, 0]),
				lib_send:send_one(get_socket(Status), BinData),						
				ok
		end
	end.

%% 处理氏族聊天
chat_guild(Status, [Data,DataGroup]) ->
   	case gmcmd:cmd(Status,Data) of
		is_cmd -> ok;
		_ ->
		%%检查禁言情况
		[Can_chat,  Ret] = check_donttalk(Status#player.id),
		case Can_chat of
			true ->	%%可以聊天
				%%检查聊天间隔
    			case check_chat_interval(previous_chat_time_guild, 2) of
					true ->
						Data1 = [Status#player.id, Status#player.nickname, Status#player.career, Status#player.realm, Status#player.sex,
								 Status#player.vip,Status#player.state, Data],
						{ok, BinData} = pt_11:write(11030, Data1),
						lib_send:send_to_guild(Status#player.guild_id, BinData),
						lib_send:send_to_guild(Status#player.guild_id, DataGroup);
					false ->
						{ok, BinData} = pt_11:write(11031, [1, 2]),
						lib_send:send_one(get_socket(Status), BinData)	
				end;
			_ ->	%%不能聊天
				{ok, BinData} = pt_11:write(11031, [Ret, 0]),
				lib_send:send_one(get_socket(Status), BinData),						
				ok
		end
	end.

%% 处理队伍聊天
chat_team(Status, [Data]) ->
   	case gmcmd:cmd(Status,Data) of
		is_cmd -> ok;
		_ ->
		%%检查禁言情况
		[Can_chat,  Ret] = check_donttalk(Status#player.id),
		case Can_chat of
			true ->	%%可以聊天
				%%检查聊天间隔
			    case check_chat_interval(previous_chat_time_team, 2) of
					true -> 
   				 		case misc:is_process_alive(Status#player.other#player_other.pid_team) of
        					true ->
								Data1 = [Status#player.id, Status#player.nickname, Status#player.career, Status#player.realm, Status#player.sex,
										 Status#player.vip,Status#player.state, Data],
								{ok, BinData} = pt_11:write(11040, Data1),
            					gen_server:cast(Status#player.other#player_other.pid_team, {'TEAM_CHAT', BinData});
        					false -> ok
    					end;
					false ->
						{ok, BinData} = pt_11:write(11041, [1, 2]),
						lib_send:send_one(get_socket(Status), BinData)	
				end;
			_ ->	%%不能聊天
				{ok, BinData} = pt_11:write(11041, [Ret, 0]),
				lib_send:send_one(get_socket(Status), BinData),						
				ok
		end
	end.

%% 处理场景聊天
chat_scene(Status, [Data]) ->
   	case gmcmd:cmd(Status,Data) of
		is_cmd -> ok;
		_ ->	
		%%检查禁言情况
		[Can_chat,  Ret] = check_donttalk(Status#player.id),
		case Can_chat of
			true ->	%%可以聊天
				%%检查聊天间隔
 			   	case check_chat_interval(previous_chat_time_scene, 2) of
					true -> 
						Data1 = [Status#player.id, Status#player.nickname, Status#player.career, Status#player.realm, Status#player.sex,
								 Status#player.vip,Status#player.state, Data],
						{ok, BinData} = pt_11:write(11050, Data1),
					 	mod_scene_agent:send_to_scene(Status#player.scene, BinData);		
					false ->
						{ok, BinData} = pt_11:write(11051, [1, 2]),
						lib_send:send_one(get_socket(Status), BinData)	
				end;
			_ ->	%%不能聊天
				{ok, BinData} = pt_11:write(11051, [Ret, 0]),
				lib_send:send_one(get_socket(Status), BinData),						
				ok
		end
	end.

%% 处理传音
chat_sound(Status, [Color, Data]) ->
%% 	%%检查禁言情况
	[Can_chat,  Ret] = check_donttalk(Status#player.id),
	case Can_chat of
		true ->	%% 可以聊天
			%% 检查聊天间隔
			case check_chat_interval(sound_chat_time_world, 1) of
				true -> 
						%%检查是否有传音符
    					case gen_server:call(Status#player.other#player_other.pid_goods, {'delete_more', 28013, 1}) of
							 1 ->  %%  使用传音符
								Data1 = [Status#player.id, Status#player.nickname, 
					 			Status#player.lv, Status#player.realm, Status#player.sex, Status#player.career, Color, Status#player.vip,Status#player.state, Data],
								{ok, BinData} = pt_11:write(11060, Data1),
								lib_send:send_to_all(BinData,?SOCKET_CHAT);
							  _ ->  %%  传音符不够
								{ok, BinData} = pt_11:write(11061, [4,0]),
								lib_send:send_one(get_socket(Status), BinData)	
						end;
				false -> %% 不到聊天间隔期
		   			{ok, BinData} = pt_11:write(11061, [1, 1]),
		   			lib_send:send_one(get_socket(Status), BinData)	
			end;
		_ ->	%%不能聊天
			{ok, BinData} = pt_11:write(11061, [Ret, 0]),
			lib_send:send_one(get_socket(Status), BinData),						
			ok
	end.

%% 处理同服聊天
chat_sn(Status, [Data]) ->
   	case gmcmd:cmd(Status,Data) of
		is_cmd -> ok;
		_ ->	
		%%检查禁言情况
		[Can_chat,  Ret] = check_donttalk(Status#player.id),
		case Can_chat of
			true ->	%%可以聊天
				%%检查聊天间隔
 			   	case check_chat_interval(previous_chat_time_sn, 2) of
					true -> 
						Data1 = [Status#player.id, Status#player.nickname, Status#player.career, Status#player.realm, Status#player.sex,
								 Status#player.vip,Status#player.state, Data],
						{ok, BinData} = pt_11:write(11090, Data1),
						gen_server:cast(mod_war_supervisor:get_mod_war_supervisor_pid(),{'chat',[Status#player.id,BinData]});
%% 						mod_war_supervisor:chat_sn(Status#player.sn, BinData);
					false ->
						{ok, BinData} = pt_11:write(11091, [1, 2]),
						lib_send:send_one(get_socket(Status), BinData)	
				end;
			_ ->	%%不能聊天
				{ok, BinData} = pt_11:write(11091, [Ret, 0]),
				lib_send:send_one(get_socket(Status), BinData),						
				ok
		end
	end.

%% 	%%检查是否有传音符
%% 	Can_sound =
%% 		case gen_server:call(Status#player.other#player_other.pid_goods, {'delete_more', 28013, 1}) of
%% 			 1 -> true;
%% 			_ -> false
%% 		end,
%%     case Can_sound of
%% 		true -> 
%% 		    %%  使用传音符
%% 			Data1 = [Status#player.id, Status#player.nickname, 
%% 					 Status#player.lv, Status#player.realm, Status#player.sex, Status#player.career, Color, Data],
%% 			{ok, BinData} = pt_11:write(11060, Data1),
%% 			lib_send:send_to_all(BinData);
%% 		false ->
%% 			{ok, BinData} = pt_11:write(11061, [1]),
%% 			lib_send:send_one(Status#player.other#player_other.socket, BinData)	
%% 	end.
  
%%检查禁言情况
check_donttalk(PlayerId) ->
	try 
	[Stop_begin_time, Stop_chat_minutes] = get(donttalk),
	case Stop_chat_minutes of
		undefined -> 	%% 没有被禁言
			[true,  undefined];
		999999 -> 		%% 永远禁言
			[false, 3];		
		Val ->			%% 有禁言
			TimeDiff = util:unixtime() - Stop_begin_time,
			if 
				TimeDiff >= Val*60 ->
					db_agent:delete_donttalk(PlayerId),
					put(donttalk, [undefined, undefined]),
					[true,  undefined];
				true ->
					[false, 2]
  			end
	end
	catch
		_:_ -> [true,  undefined]
	end.

%%私聊返回被加黑名单通知
chat_in_blacklist(Id, Sid) ->
    {ok, BinData} = pt_11:write(11071, Id),
    lib_send:send_to_sid(Sid, BinData).

%%发送系统信息给某个玩家
send_sys_msg_one(Socket, Msg) ->
    {ok, BinData} = pt_11:write(11080, Msg),
    lib_send:send_one(Socket, BinData).

%%发送系统信息(Type=1:系统；2:传闻; 3:开封印)
broadcast_sys_msg(Type, Msg) ->
	{ok, BinData} = pt_11:write(11080, Type, Msg),
	mod_disperse:broadcast_to_world(ets:tab2list(?ETS_SERVER), BinData),
	lib_send:send_to_local_all(BinData).

%%专门用于诛邪系统 的广播
boradcast_box_goods_msg(_Type, Msg, BroadCastGoodsList) ->
	{ok, BinData} = pt_11:write(11080, 3, Msg),
	mod_disperse:boradcast_box_goods_msg(ets:tab2list(?ETS_SERVER), BinData, BroadCastGoodsList),
	lib_send:send_to_local_all(BinData).


%% 发送聊天给指定玩家ID.
%% ToId 接收方ID
%% PidSid 发送方Id发送进程
%% Bin 二进制数据.
private_to_uid(ToId, PidSid, Bin) ->
	case lib_player:is_online(ToId) of
		false ->
			{ok, BinData} = pt_11:write(11072, ToId),
			lib_send:send_to_sid(PidSid, BinData);
		true ->
			lib_send:send_to_uid(ToId, Bin)
	end.
		
%% 获取聊天间隔
getChatTimeDiff(Previous_chat_time)->
	case get(Previous_chat_time) of
		undefined -> 
			PreviousChatTime = {0,0,0};
		Val ->
			PreviousChatTime = Val
	end,
	Now = yg_timer:now(),
	TimeDiff = timer:now_diff(Now, PreviousChatTime),
	{Now, TimeDiff}.

%% 检查聊天间隔
check_chat_interval(Previous_chat_time, Interval) ->
	{Now,TimeDiff} = getChatTimeDiff(Previous_chat_time),
	if TimeDiff >= Interval*1000000 ->
			put(Previous_chat_time, Now),
			true;
	   true ->
		   false
	end.

%% 选择玩家socket 默认socket3
get_socket(Player) ->
	case Player#player.other#player_other.socket3 of
		undefined ->
			Player#player.other#player_other.socket;
		Socket ->
			Socket
	end.

%%获取私聊面板人物信息
get_chat_info(PlayerId) ->
	case lib_player:get_online_info_fields(PlayerId,[realm, lv, guild_name, guild_id]) of
		[Rid, Level, Gname, GuildId] -> [PlayerId, Rid, Level, Gname, GuildId];   %%该玩家目前在线
		[] -> case db_agent:get_chat_info_by_id(PlayerId) of             %%不在线则从数据库读取
				  [Rid, Level, Gname, GuildId, _Nick] -> [PlayerId, Rid, Level, Gname, GuildId];
				  [] -> []
			  end		  
	end.
			