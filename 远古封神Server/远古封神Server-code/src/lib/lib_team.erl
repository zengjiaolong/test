%%%------------------------------------
%%% @Module  : lib_team
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 组队模块公共函数
%%%------------------------------------
-module(lib_team).
-export(
    [
		send_leaderid_area_scene/6,
		send_leaderid_area_scene/5,
		send_leaderid_area_scene/2,
		update_team_player_info/1,
		update_fst_god/5,
		join_team/3,
		extra_team_exp_spt/1
    ]
).
-include("common.hrl").
-include("record.hrl").

%% Id 上任队长的玩家ID
%% Type 1上任队长，0卸任队长
%% FromId 卸任者ID
%% FromScene 卸任者所在的场景
%% FromX 卸任者所在的X坐标
%% FromY 卸任者所在的Y坐标
send_leaderid_area_scene(ToId, Type, FromId, FromScene, FromX, FromY) ->
	case Type of
		1 ->
			ok;
		_ ->
			mod_delayer:delete_blackboard_info(FromId)
			%%檫黑板
	end,
	{ok, BinData} = pt_12:write(12018, [ToId, Type]),	
	case ToId == FromId of
		true ->   
		   	mod_scene_agent:send_to_area_scene(FromScene, FromX, FromY, BinData);
		false ->
			%% 获取上任队长的一些信息
			case lib_player:get_online_info_fields(ToId, [scene, x ,y]) of
        		[] ->
					ok;
        		[ToScene, ToX ,ToY] ->	
					mod_scene_agent:send_to_area_scene(ToScene, ToX, ToY, BinData)
    		end	
	end.

%% 成为队员或者退队后对场景广播
send_leaderid_area_scene(Uid, Type, Scene, X, Y) ->
	{ok, BinData} = pt_12:write(12018, [Uid, Type]),
	mod_scene_agent:send_to_area_scene(Scene, X, Y, BinData).

%% 成为队员或者退队后对场景广播
send_leaderid_area_scene(Uid, Type) ->
	case lib_player:get_online_info_fields(Uid, [scene, x ,y]) of
		[] ->
			ok;
		[Scene, X ,Y] ->
			{ok, BinData} = pt_12:write(12018, [Uid, Type]),
			mod_scene_agent:send_to_area_scene(Scene, X, Y, BinData)
	end.

%% 更新队伍成员的血蓝数值信息
%% Player 玩家信息
update_team_player_info(Player) ->
	if
   		Player#player.other#player_other.pid_team =/= undefined ->
			Data = [
          		Player#player.id, 
           		Player#player.status,
             	Player#player.lv,
               	Player#player.hp,
                Player#player.hp_lim,
                Player#player.mp,
           		Player#player.mp_lim
            ],
			gen_server:cast(Player#player.other#player_other.pid_team, {'UPDATE_TEAM_PLAYER_INFO', Data});         
        true ->
            skip
    end.

%% 封神台霸主更新
update_fst_god(_L, 0, _Loc, _Thru_time, _Action) ->
	ok;
update_fst_god([], _Num, _Loc, _Thru_time, _Action) ->
	ok;
update_fst_god(L, Num, Loc, Thru_time, Action) ->
	[H|T] = L,
	gen_server:cast(H#mb.pid, {'SET_FST_GOD', Loc, Thru_time, Action, Num}),
	update_fst_god(T, Num - 1, Loc, Thru_time, Action).


%% 加入队伍，join为平时加入队伍，队伍进程ID为登陆后重新加入队伍
join_team(Pid_team, Status, Action) ->
	case [misc:is_process_alive(Pid_team), Action] of
		[true, join] ->
		    case is_pid(Status#player.other#player_other.pid_team) of
		        %% 邀请人没有加入队伍
				false ->
					%% 获取玩家好友列表
					[{FriendList, _VipList2}] = lib_relationship:get_ets_rela_record(Status#player.id, 1),
		            case gen_server:call(Pid_team, {'INVITE_RES', Status#player.id, Status#player.lv, Status#player.other#player_other.pid, 
														Status#player.nickname, Status#player.x, Status#player.y, Status#player.realm, 
														Status#player.scene, Status#player.other#player_other.pid_send, Status#player.career, 
														Status#player.sex, Status#player.hp_lim, Status#player.mp_lim, FriendList}) of
		               	%% 成功加入队伍
						{1, TPid, _TeamLength} ->						   
						   	NewStatus =
								case catch gen_server:call(Status#player.other#player_other.pid_team, 'GET_TEAM_INFO') of
                					{'EXIT', _} ->
                    					Status;
                					TeamInfo ->
										F = fun({U_scid, Pid}) -> {U_scid rem 10000, Pid} end,
										NewList = lists:map(F, TeamInfo#team.fst_pid),
										mod_delayer:update_delayer_info(Status#player.id, TeamInfo#team.dungeon_pid, NewList, Pid_team),										
                    					Status#player{other = Status#player.other#player_other{pid_fst = NewList, pid_dungeon = TeamInfo#team.dungeon_pid}}
            					end,
						   	gen_server:cast(NewStatus#player.other#player_other.pid, {'SET_PLAYER', [{pid_team, TPid}, {leader, 2}]}),
		                   	{ok, BinData} = pt_24:write(24008, 1),
		                   	lib_send:send_to_sid(NewStatus#player.other#player_other.pid_send, BinData);
		               	%% 队伍人数已满
						mb_max ->
		              		{ok, BinData} = pt_24:write(24008, 0),
		                    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
		               	_ -> 
							ok
		           end;
		       true -> 
				   ok %%邀请人已经加入队伍了
		   end;
		[true, PPid] ->
			[{FriendList, _VipList2}] = lib_relationship:get_ets_rela_record(Status#player.id, 1),
			case catch gen:call(Pid_team, '$gen_call', {'INVITE_RES', Status#player.id, Status#player.lv, PPid, Status#player.nickname, 
															Status#player.x, Status#player.y, Status#player.realm, Status#player.scene, 
															Status#player.other#player_other.pid_send, Status#player.career, Status#player.sex, 
															Status#player.hp_lim, Status#player.mp_lim, FriendList}, 2000) of
				%% 成功加入队伍
				{ok, {1, TPid, TeamLength}} ->  
					NewStatus =
						case catch gen_server:call(Status#player.other#player_other.pid_team, 'GET_TEAM_INFO') of
                			{'EXIT', _} ->
                    			Status;
                			TeamInfo ->
								F = fun({U_scid, Pid}) -> {U_scid rem 10000, Pid} end,
								NewList = lists:map(F, TeamInfo#team.fst_pid),
								mod_delayer:update_delayer_info(Status#player.id, TeamInfo#team.dungeon_pid, NewList, Status#player.other#player_other.pid_team),
                    			Status#player{
									other = Status#player.other#player_other{
										pid_fst = NewList, 
										pid_dungeon = TeamInfo#team.dungeon_pid
									}
								}
            			end,
					Leader = 
						case TeamLength > 1 of
							true ->
								2;
							false ->
								1
						end,
					gen_server:cast(NewStatus#player.other#player_other.pid, {'SET_PLAYER', [{pid_team, TPid}, {leader, Leader}]}),
					{ok, BinData} = pt_24:write(24008, 1),
					lib_send:send_to_sid(NewStatus#player.other#player_other.pid_send, BinData),
					TPid;
				{ok, mb_max} -> %%队伍人数已满
		             {ok, BinData} = pt_24:write(24008, 0),
		             lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					 undefined;
		        {'EXIT', _Reason} -> 
					undefined;
				_ -> 
					undefined
		    end;			
		[false, join] -> 
		   	%% 队伍已经不存在了
		   	{ok, BinData} = pt_24:write(24008, 2),
		   	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
		   	undefined;
		[false, _] -> 
		   	%% 队伍已经不存在了（登陆是如果之前的队伍不存在，则不提示）
		   	undefined
	end.

%% 组队经验灵力加成系数
extra_team_exp_spt(TeamNum) ->
	case TeamNum of
		5 ->
			1.1;
		4 ->
			1.075;
		3 ->
			1.05;
		2 ->
			1.025;
		_ ->
			1
	end.
