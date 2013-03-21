%%%--------------------------------------
%%% @Module  : pp_team
%%% @Author  : ygzj
%%% @Created : 2010.09.23
%%% @Description:  组队功能管理 
%%%--------------------------------------
-module(pp_team).
-export([handle/3]).
-include("record.hrl").
-include("common.hrl").
-include("guild_info.hrl").

%% 创建队伍
handle(24000, Status, [Auto, Type]) ->
    case is_pid(Status#player.other#player_other.pid_team) of
        false ->
			case lib_scene:is_std_scene(Status#player.scene) of
				false ->  
					%% 战场内不能组队
					case lib_arena:is_arena_scene(Status#player.scene) of
                        false ->
							case lib_scene:get_scene_id_from_scene_unique_id(Status#player.scene) of
								?DUNGEON_SINGLE_SCENE_ID ->
									{ok, BinData} = pt_24:write(24000, [7, [], Auto]),
                            		lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
								%% 空岛不能组队
								?SKY_RUSH_SCENE_ID ->
									{ok, BinData} = pt_24:write(24000, [8, [], Auto]),
                                  	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
								%% 九霄攻城战不能组队
								?CASTLE_RUSH_SCENE_ID ->
									{ok, BinData} = pt_24:write(24000, [11, [], Auto]),
                                 	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
								_ ->
									%% 氏族副本状态不能组队
									case lib_box_scene:is_box_scene_idsp_for_team(Status#player.scene, Status#player.id) of
										false ->
                                            %% 跨服不能组队
                                            case lib_war:is_war_server() of
                                                false->
													TeamName = io_lib:format("~s的队伍",[Status#player.nickname]),
													TeamParam = [
														Status#player.id, 
                                                     	Status#player.other#player_other.pid, 
                                                    	Status#player.nickname, 
                                                   		TeamName,
                                                     	Status#player.other#player_other.pid_dungeon,
														Status#player.other#player_other.pid_send,
                                                      	Status#player.scene,
														Status#player.realm,
														Status#player.lv,
														Status#player.career,
														Status#player.sex,
														Status#player.hp_lim,
														Status#player.mp_lim,
                                                      	Auto, Type		 
													],
                                                    case mod_team:start(TeamParam) of
                                                        {ok, PidTeam} ->
															%% 告诉场景
                                                            lib_team:send_leaderid_area_scene(Status#player.id, 1, Status#player.id, Status#player.scene, Status#player.x, Status#player.y), 
                                                            mod_delayer:update_delayer_info(Status#player.id, Status#player.other#player_other.pid_dungeon, Status#player.other#player_other.pid_fst, PidTeam),
                                                            {ok, BinData} = pt_24:write(24000, [1, TeamName, Auto]),
                                                            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
															NewPlayer = Status#player{
																other = Status#player.other#player_other{
																	pid_team = PidTeam, 
																	leader = 1
																}
															},
															mod_player:save_online_info_fields(NewPlayer, [{pid_team, PidTeam}, {leader, 1}]),
															if 
																Type =/= 0 ->
																   %% 队伍招募
																   gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'raise_team_info',[PidTeam,Status#player.nickname,Status#player.lv,Type,Auto,Status#player.id]});
															   	true -> 
																   gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'del_member',[NewPlayer#player.id]}) 
															end,
                                                            {ok, change_status, NewPlayer};
                                                        _Any ->
                                                            {ok, BinData} = pt_24:write(24000, [0, [], Auto]),
                                                            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
                                                    end;
                                                true->
                                                    {ok, BinData} = pt_24:write(24000, [10, [], Auto]),
                                                    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
                                            end;
										true ->
											{ok, BinData} = pt_24:write(24000, [6, [], Auto]),
                            				lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
									end
							end;
                        true ->
                            {ok, BinData} = pt_24:write(24000, [5, [], Auto]),
                            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
                    end;
				_ ->
                    {ok, BinData} = pt_24:write(24000, [9, [], Auto]),
                    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
			end;
        true ->
            {ok, BinData} = pt_24:write(24000, [2, [], Auto]),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
    end;

%% 加入队伍
handle(24002, Status, [Uid, Type]) ->
    case is_pid(Status#player.other#player_other.pid_team) of
        false ->
			%% 你在副本中，不能申请入队
			case lib_scene:is_copy_scene(Status#player.scene) orelse 
					 lib_scene:get_scene_id_from_scene_unique_id(Status#player.scene) =:= ?DUNGEON_SINGLE_SCENE_ID of
				true ->	
              		{ok, BinData} = pt_24:write(24002, 6),
              		lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
				_->
					%% 战场内不能组队					
					case lib_arena:is_arena_scene(Status#player.scene) of
						false ->
							%% 氏族副本状态不能组队
							case lib_box_scene:is_box_scene_idsp_for_team(Status#player.scene, Status#player.id) of
								false ->
									case Status#player.scene of
										%% 空岛不能组队
										?SKY_RUSH_SCENE_ID ->
											{ok, BinData} = pt_24:write(24000, [8, [], 1]),
											lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
										%% 九霄攻城战不能组队
										?CASTLE_RUSH_SCENE_ID ->
											{ok, BinData} = pt_24:write(24000, [11, [], 1]),
											lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
										_ ->
                                            case lib_player:get_online_info_fields(Uid, [pid_team]) of
                                                [] -> %% 玩家不在线
                                                    {ok, BinData} = pt_24:write(24002, 3),
                                                    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
                                                [Pid_team] ->
                                                    %%队伍是否存在
                                                    case is_pid(Pid_team) of
                                                        true -> 
                                                            case (catch gen_server:call(Pid_team, 'JOIN_TEAM_REQ')) of
                                                                {'EXIT', _} -> %% 队伍已经不存在
                                                                    {ok, BinData} = pt_24:write(24002, 3),
                                                                    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);									
                                                                {ok, mb_max, _LeaderId} ->  %% 队伍人数已满
                                                                    {ok, BinData} = pt_24:write(24002, 2),
                                                                    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
                                                                {ok, auto_join, _LeaderId} ->  %% 自动加入
                                                                    lib_team:join_team(Pid_team, Status, join);
                                                                {ok, 1, LeaderId} ->
                                                                    %%向队长发送加入队伍请求				
                                                                    Data = [Status#player.id, Status#player.lv, Status#player.career, Status#player.realm, Status#player.nickname,Type],
                                                                    {ok, BinData} = pt_24:write(24003, Data),
                                                                    lib_send:send_to_uid(LeaderId, BinData),
                                                                    lib_chat:send_sys_msg_one(Status#player.other#player_other.socket, "入队请求已发出，等待队长回应");
                                                                {ok, in_dungeon, _} -> %%队伍在副本中
                                                                    {ok, BinData} = pt_24:write(24002, 5),
                                                                    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
                                                                _ -> ok
                                                            end;
                                                        false ->  %% 队伍已不存在
                                                            {ok, BinData} = pt_24:write(24002, 3),
                                                            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
                                                    end
                                            end
									end;
								true ->
									{ok, BinData} = pt_24:write(24000, [6, [], 1]),
                            		lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
							end;
						true ->
							{ok, BinData} = pt_24:write(24000, [5, [], 1]),
                            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
					end
            end;
        true -> 	%% 你已经加入队伍了
            {ok, BinData} = pt_24:write(24002, 4),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
    end;

%% 队长回应加入队伍请求
handle(24004, Player, [Res, Uid]) ->
	%% 是否有队伍
	if
		Player#player.other#player_other.pid_team =/= undefined ->
			%% 是否是队长
			if
				Player#player.other#player_other.leader =:= 1 ->
					%% 队长是否拒绝
					if
						Res =:= 1 ->
                      		gen_server:cast(Player#player.other#player_other.pid_team, 
										{'JOIN_TEAM_RESPONSE', Uid, Player#player.other#player_other.pid_send});
						true ->
							%% 队长拒绝申请人进队
							{ok, BinData} = pt_24:write(24002, 0),
                      		lib_send:send_to_uid(Uid, BinData)
					end;
				true ->
					%% 不是队长，无权操作
					{ok, BinData} = pt_24:write(24004, 3),
              		lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
			end;
        true ->
            {ok, BinData} = pt_24:write(24004, 4),
            lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
    end;

%% 离开队伍
handle(24005, Player, _Rsn) ->
	case lib_scene:is_td_scene(Player#player.scene) of
		true ->
            {ok, BinData} = pt_24:write(24005, 2),
            lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		_ ->
			TeamPid = Player#player.other#player_other.pid_team,
			case is_pid(TeamPid) of
				true ->
            		Msg = {'QUIT_TEAM', Player#player.id, Player#player.scene, Player#player.x, Player#player.y},
            		case catch gen_server:call(TeamPid, Msg) of
                		{'EXIT', _Error} ->
                    		{ok, BinData} = pt_24:write(24005, 0),
                    		lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);						
                		1 ->
							mod_delayer:update_delayer_info(Player#player.id, undefined),
                    		case lib_scene:is_dungeon_scene(Player#player.scene) 
									orelse lib_cave:is_cave_scene(Player#player.scene) of
                        		true ->
                            		pp_scene:handle(12030, Player, leave_team);
                        		_ -> 
									no_dungeon_td
                    		end,
                    		{ok, BinData} = pt_24:write(24005, 1),
                    		lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
							
							NewPlayer = Player#player{
								other = Player#player.other#player_other{
									pid_team = undefined,
									pid_fst = [],
									pid_dungeon = undefined,
									leader = 0
								}
							},
							mod_player:save_online_info_fields(NewPlayer, [{pid_team, undefined}, {leader, 0}]),
                            {ok, change_status, NewPlayer};
						Result ->
							{ok, BinData} = pt_24:write(24005, Result),
                      		lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
            		end;
				false ->
					skip
			end
	end;

%%邀请别人加入队伍(自己邀请自己)
handle(24006, Status, [Uid,_Type]) when Status#player.id =:= Uid->
	{ok, BinData} = pt_24:write(24006, 8),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);	
	
%% 邀请别人加入队伍
handle(24006, Player, [Uid, Type]) ->
	case Player#player.scene of
		%% 空岛不能组队
		?SKY_RUSH_SCENE_ID ->
			{ok, BinData} = pt_24:write(24000, [8, [], 1]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		%% 九霄攻城战不能组队
		?CASTLE_RUSH_SCENE_ID ->
			{ok, BinData} = pt_24:write(24000, [11, [], 1]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		_ ->
			%% 邀请人是否有队伍
			case is_pid(Player#player.other#player_other.pid_team) of 
                true ->
					gen_server:cast(Player#player.other#player_other.pid_team, 
							{'INVITE_REQ', Player#player.id, Player#player.nickname, Player#player.lv, Uid, Player#player.other#player_other.pid_send, Type});
                false ->
                    {ok, BinData} = pt_24:write(24006, 6),
                    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
            end
	end;
	
%% 被邀请人回应邀请请求
handle(24008, Status, [LeaderId, Res]) ->
  	case Res of
        0 -> ok; %%被邀请人拒绝了
        1 ->
			%% 战场内不能组队           	
			case lib_arena:is_arena_scene(Status#player.scene) of
         		false ->
					%% 氏族副本状态不能组队
					case lib_box_scene:is_box_scene_idsp_for_team(Status#player.scene, Status#player.id) of
						false ->
							case lib_scene:get_scene_id_from_scene_unique_id(Status#player.scene) of
								%% 空岛不能组队
								?SKY_RUSH_SCENE_ID ->
									{ok, BinData} = pt_24:write(24000, [8, [], 1]),
                            		lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
								%% 九霄攻城战不能组队
								?CASTLE_RUSH_SCENE_ID ->
									{ok, BinData} = pt_24:write(24000, [11, [], 1]),
                                  	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
								?DUNGEON_SINGLE_SCENE_ID ->
									{ok, BinData} = pt_24:write(24000, [7, [], 1]),
                            		lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
								_ ->
                                    case lib_scene:is_std_scene(Status#player.scene) of
                                        true ->
                                            {ok, BinData} = pt_24:write(24008, 5),
                                            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
                                        false ->
                                            %% 被邀请人同意了，检查队长还在线不
                                            case lib_player:get_online_info_fields(LeaderId, [pid_team]) of
                                                [] -> %%队伍已经不存在了,或者队长已下线
                                                    {ok, BinData} = pt_24:write(24008, 2),
                                                    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),			
                                                    ok;		
                                                [Pid_team] -> %%检查队伍还存在不
                                                    lib_team:join_team(Pid_team, Status, join)
                                            end
                                    end
							end;
						true ->
							{ok, BinData} = pt_24:write(24000, [6, [], 1]),
                            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
					end;
				true ->
					{ok, BinData} = pt_24:write(24000, [5, [], 1]),
                   	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
			end
     end;

%% 踢出队伍
%% Uid 被踢人id
%% TeamId 队伍id
handle(24009, Player, Uid) ->
	case Player#player.id =:= Uid of
        false ->
			if 
				Player#player.other#player_other.pid_team =:= undefined ->
					{ok, BinData} = pt_24:write(24009, 0),
    				lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		   		true ->
					if
						Player#player.other#player_other.leader =/= 1 ->
							{ok, BinData} = pt_24:write(24009, 2),
    						lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
						true ->
							gen_server:cast(Player#player.other#player_other.pid_team, 
									{'KICK_OUT', Uid, Player#player.id, Player#player.scene, Player#player.other#player_other.pid_send})	
					end
            end;
		%% 不能踢自己
        true ->
			{ok, BinData} = pt_24:write(24009, 3),
    		lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
    end;

%% 询问队伍信息
handle(24010, Player, _) ->
	case is_pid(Player#player.other#player_other.pid_team) of
		true ->
			%% 获取玩家好友列表
			[{FriendList, _VipList2}] = lib_relationship:get_ets_rela_record(Player#player.id, 1), 
			gen_server:cast(Player#player.other#player_other.pid_team, 
					{'RE_JOIN_TEAM', FriendList, Player#player.id, Player#player.scene, Player#player.x, Player#player.y, Player#player.other#player_other.pid_send});
		false ->
			skip
	end;

%% 委任队长
handle(24013, Player, Uid) ->
	TeamPid = Player#player.other#player_other.pid_team,
	case is_pid(TeamPid) of
    	true ->
			case catch gen_server:call(TeamPid, {'CHANGE_LEADER', Uid, Player#player.id, 
						  Player#player.scene, Player#player.x, Player#player.y}) of
        		1 ->
					{ok, BinData} = pt_24:write(24013, 1),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
					NewPlayer = Player#player{
						other = Player#player.other#player_other{
							leader = 2
						}
					},
					mod_player:save_online_info_fields(NewPlayer, [{leader, 2}]),
                    {ok, change_status, NewPlayer};
        		_ ->
					{ok, BinData} = pt_24:write(24013, 0),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
			end;
		false ->
			{ok, BinData} = pt_24:write(24013, 0),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
	end;

%% 获取队伍信息
handle(24016, Player, Uid) ->
    %%是否在线
    case lib_player:get_online_info_fields(Uid, [pid_team]) of
        [] -> ok;
        [PidTeam] ->%%是否有队伍
            case is_pid(PidTeam) of
                true ->
                    gen_server:cast(PidTeam, {'SEND_TEAM_INFO', Player#player.other#player_other.pid_send});
                false ->
                    {ok, BinData} = pt_24:write(24016, [0, 0, [], [], 0]),
                    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
            end
    end;

%% 获取附近队伍信息
handle(24018, Player, _) ->
	mod_scene:get_scene_team_info(Player#player.scene, Player#player.x, Player#player.y, Player#player.other#player_other.pid_send);

%% 可否传送进入副本或封神台
handle(24031, Status, Sid) ->
	Res =			
		case is_pid(Status#player.other#player_other.pid_team) of
			true ->
				if
					Sid < 900 ->
						2;
					true ->
						case lib_deliver:could_deliver(Status) of
							ok ->
								1;
							Val ->
								Val
						end
				end;
			_ ->
				3
		end,
    {ok, BinData} = pt_24:write(24031, [Sid, Res]),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);

%% 小黑板登记信息
handle(24050, Status, [Cdn1, Cdn2, Cdn3, MinLv, MaxLv]) ->
	Res =			
		case [is_pid(Status#player.other#player_other.pid_team), Status#player.other#player_other.leader] of
			[true, 1] ->
				NewBBM = #ets_blackboard{id = Status#player.id, nickname = Status#player.nickname,
										leader = 1, condition_1 = Cdn1, condition_2 = Cdn2, 
										 condition_3 = Cdn3, min_lv	= MinLv, max_lv	= MaxLv,
										 career = Status#player.career, lv = Status#player.lv},
				mod_delayer:add_blackboard_info(NewBBM),
				1;
			[true, _] ->
				2;
			[false, _] ->
				NewBBM = #ets_blackboard{id = Status#player.id, nickname = Status#player.nickname,
										leader = 1, condition_1 = Cdn1, condition_2 = Cdn2, 
										 condition_3 = Cdn3, min_lv	= MinLv, max_lv	= MaxLv,
										 career = Status#player.career, lv = Status#player.lv,
										 sex = Status#player.sex},
				mod_delayer:add_blackboard_info(NewBBM),
				1;
			_ ->
				0
		end,
    {ok, BinData} = pt_24:write(24050, Res),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);

handle(24051, Status, _R) ->
	Result = mod_delayer:check_blackboard_info(),
    {ok, BinData} = pt_24:write(24051, Result),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);

%% 修改队伍的组队方式
handle(24052, Player, AutoAccess) ->
    case is_pid(Player#player.other#player_other.pid_team) of
		true ->
      		gen_server:cast(Player#player.other#player_other.pid_team, 
					{'CHANGE_ACCESS_MODE', AutoAccess, Player#player.id, Player#player.other#player_other.pid_send});
     	_ ->
			{ok, BinData} = pt_24:write(24052, [0, AutoAccess]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
    end;

%% 查询招募信息
handle(24025,Status,[Type])->
	gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'raise_info',[Status,Type]});

%% 报名招募
handle(24026,Status,[Type])->
	gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'raise_member_info',[Status,Status#player.nickname,Status#player.lv,Status#player.career,Type]});

%% 取消招募
handle(24027,Status,[Type])->
	gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'cancel_raise',[Status,Type]});

%% 招募公告
handle(24028, Status, [Type])->
	gen_server:cast(Status#player.other#player_other.pid_team,{'raise_msg',[Status,Type]}), 
	ok; 

%% 队员集合
handle(24029, Status, [Type])->
	gen_server:cast(Status#player.other#player_other.pid_team,{'raise_call', [Status, Type ]});

%%队员传送
handle(24032,Status,[Type,P])->
%% 	gen_server:cast(Status#player.other#player_other.pid_team,{'raise_send',[Status,Type,P]});
	case is_pid(Status#player.other#player_other.pid_team) of
		false->ok;
		true->
			case catch gen_server:call(Status#player.other#player_other.pid_team, 'GET_TEAM_INFO') of
				{'EXIT', _} ->
					Status;
				TeamInfo ->
					if TeamInfo#team.team_type =/=0->
						   case lib_task:check_send(Status, 3) of
							   {ok, _}->
								   daily_deliver(Status,3,Type,P);
							   {error, Result}->
								   {ok, BinData} = pt_30:write(30091, [Result]),
								   lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
						   end;
					   true->skip
					end
			end
	end;

handle(_Cmd, _Status, _Data) ->
    {error, "pp_team no match"}.

%%检查队名长度是否合法
%% validate_team_name(len, TeamName) ->
%%     case asn1rt:utf8_binary_to_list(list_to_binary(TeamName)) of
%%         {ok, CharList} ->
%%             Len = string_width(CharList),  
%%             %% 队名最大长度暂时设为15个中文字 
%%             case Len < 31 andalso Len > 1 of
%%                 true ->
%%                     {true, ok};
%%                 false ->
%%                     %%队伍名称长度为1~15个汉字
%%                     {false, len_error}
%%             end;
%%         {error, _Reason} ->
%%             %%非法字符
%%             {false, illegal}
%%     end.

%% 字符宽度，1汉字=2单位长度，1数字字母=1单位长度
%% string_width(String) ->
%%     string_width(String, 0).
%% string_width([], Len) ->
%%     Len;
%% string_width([H | T], Len) ->
%%     case H > 255 of
%%         true ->
%%             string_width(T, Len + 2);
%%         false ->
%%             string_width(T, Len + 1)
%%     end.
%%%%%%每日活动面板传送(Type:1:Npc、2：怪物,3场景)
%% SendType 1元宝，2铜钱，3筋斗云
daily_deliver(PlayerStatus,SendType,Type,Id)->
	case Type of
		3->deliver_scene(PlayerStatus,SendType,Id);
		_->deliver_mon_npc(PlayerStatus,SendType,Type,Id)
	end.
%%场景传送
deliver_scene(PlayerStatus,SendType,Id)->
	%%检查是否副本类地图
	case lib_deliver:check_scene_enter(Id) of
		false->
			{ok,BinData} = pt_30:write(30091,[8]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
		true->
			%%获取场景数据
			case data_scene:get(Id) of
				[]->
					{ok,BinData} = pt_30:write(30091,[6]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
				SceneInfo->
					%%检查是否挂机区场景
					case lists:member(Id,data_scene:get_hook_scene_list()) of
						false->
							NewStatus=lib_deliver:deliver(PlayerStatus,Id,SceneInfo#ets_scene.x,SceneInfo#ets_scene.y,SendType),
							{ok,NewStatus};
						true->
							%%检查挂机区是否开放
							case lib_hook:is_open_hooking_scene() of
								opening->
									NewStatus=lib_deliver:deliver(PlayerStatus,Id,SceneInfo#ets_scene.x,SceneInfo#ets_scene.y,SendType),
									{ok,NewStatus};
								_->
									{ok,BinData} = pt_30:write(30091,[9]),
									lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
							end
					end
			end
	end.

%%%%查找目的地的场景id和坐标
get_secne(Realm, NpcId, Type, SceneId, Lv)->
	case Type of
		1->lib_task:get_npc_def_scene_info(NpcId, Realm, SceneId, Lv);
		2->lib_task:get_mon_def_scene_info(NpcId, Realm, SceneId);
		_->{0,0,0,0}
	end.

deliver_mon_npc(PlayerStatus,SendType,Type,Id)->%%查找目的地的场景id和坐标
	%%获取传送面板的场景坐标
	{SceneId,_,X1,Y1} = get_secne(PlayerStatus#player.realm,Id,Type,PlayerStatus#player.scene,PlayerStatus#player.lv),
	case SceneId of
		0->
			ErrorCode = 
				case Type of
					1->4;
					2->5;
					_->6
				end,
			{ok,BinData} = pt_30:write(30091,[ErrorCode]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
		_->
			%%检查是否副本类地图
			case lib_deliver:check_scene_enter(SceneId) of
				false->
					{ok,BinData} = pt_30:write(30091,[8]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);
				true->
					case lists:member(Id,data_scene:get_hook_scene_list()) of
						false->
							NewStatus=lib_deliver:deliver(PlayerStatus,SceneId,X1,Y1,SendType),
							{ok,NewStatus};
						true->
							case lib_hook:is_open_hooking_scene() of
								opening->
									NewStatus=lib_deliver:deliver(PlayerStatus,SceneId,X1,Y1,SendType),
									{ok,NewStatus};
								_->
									{ok,BinData} = pt_30:write(30091,[9]),
									lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData)
							end
					end
			end
	end.
