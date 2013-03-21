%%%-----------------------------------
%%% @Module  : lib_scene_fst
%%% @Author  : ygfs
%%% @Created : 2011.07.22
%%% @Description: 封神台信息
%%%-----------------------------------
-module(lib_scene_fst).
-export([
	check_enter_fst/3,%%进入封神台检测
	quit_fst/1,%%退出封神台
	is_fst_id/1 ,%%检查是否封神台场景
	is_zxt_id/1 , %%检查是否诛仙台场景
	init_base_tower_award/0,%%初始化塔奖励
	get_tower_award/1, %%获取塔奖励
	get_zxt_honor/1,  %%加载诛仙台荣誉
	update_zxt_honor/2, %%更新诛仙台荣誉
	update_fst_honor/2, %%更新封神台荣誉
	add_zxt_honor/2 ,%%增加诛仙台荣誉
	add_fst_honor/2, %%增加封神台荣誉
	cost_zxt_honor/4,%%减少诛仙台荣誉
	is_enough_zxt_honor/2,%%检查诛仙台荣誉是否足够
	init_player_scene/1,
	set_fst_god/5
]).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

-define(FST_MAXTIMES, 3). 											%% 进入封神台次数

%%注：封神台和诛仙台共用log_fst表，邮件表，type1表示封神台，2表示诛仙台 ;霸主表是独立的;
%%场景id：1001~1030为封神台(封神台削减为30层20111102)，1046~1065为诛仙台，封神台的层数用场景id的后两位数表示层数，同理，诛仙台也是；
%%所以诛仙台的第1层可看成是封神台的第46层，所以计算诛仙台层数的时候要在原来的层数上面减去45
%%诛仙台组队模式最大只支持3位玩家，封神台不限

%%初始化塔奖励数据
init_base_tower_award() ->
    F = fun(Award) ->
			AwardInfo = list_to_tuple([ets_tower_award] ++ Award),
            ets:insert(?ETS_TOWER_AWARD, AwardInfo)
           end,
	L = db_agent:get_base_tower_award(),
	lists:foreach(F, L),
    ok.

%%获取塔奖励[经验，灵力，荣誉，时间(秒)]
%%1~30为封神台奖励，46~65为诛仙台奖励
get_tower_award(Loc)->
	case ets:lookup(?ETS_TOWER_AWARD, Loc) of
		[]->
			[0,0,0,0];
		[Award]->
			[Award#ets_tower_award.exp,
			 Award#ets_tower_award.spt,
			 Award#ets_tower_award.honor,
			 Award#ets_tower_award.time]
	end.

%% 进入副本场景条件检查
check_enter_fst(Status, SceneId, Scene) ->
	case check_enter_base_condition(Status,SceneId) of
		true ->
			Scid = Status#player.scene,
            case lib_scene:is_copy_scene(Scid) of
                false ->
					case lists:member(SceneId, [1001,1046,1006,1012,1018]) of
						true->
		                    [NewStatus, TeamDngPid,TeamNum] =
		                        case misc:is_process_alive(Status#player.other#player_other.pid_team) of
		                            true ->
		                                case catch gen_server:call(Status#player.other#player_other.pid_team, 'GET_TEAM_INFO') of
		                                    {'EXIT', _} ->
		                                        [Status, Status#player.other#player_other.pid_dungeon,1];
		                                    TeamInfo ->
		                                        F = fun({U_scid, Pid}) -> {U_scid rem 10000, Pid} end,
		                                        NewList = lists:map(F, TeamInfo#team.fst_pid),
		                                        mod_delayer:update_delayer_info(Status#player.id, undefined, NewList, Status#player.other#player_other.pid_team),
		                                        [Status#player{other = Status#player.other#player_other{pid_fst = NewList}}, TeamInfo#team.dungeon_pid,length(TeamInfo#team.member)]
		                                end;
		                            _ ->
		                                [Status, Status#player.other#player_other.pid_dungeon,1]
		                        end,
		                    FstPidList = NewStatus#player.other#player_other.pid_fst,
		                    case [FstPidList, misc:is_process_alive(TeamDngPid)] of
		                        [[], true] ->
									case is_fst_id(SceneId) of
										true->
		                       				{false, 0, 0, 0, <<"队伍中已有副本存在，不能开启封神台。">>, 0, []};
										false->
											{false, 0, 0, 0, <<"队伍中已有副本存在，不能开启诛仙台。">>, 0, []}
									end;
		                        _ ->
									%% 封神台次数判断
									{_NewPlayerStatus, _, AwardTimes} = lib_vip:get_vip_award(fst, Status),
		%% 							FstMaxTimes = ?FST_MAXTIMES + AwardTimes,
									[FstSceneId,FstMaxTimes] = case is_fst_id(SceneId) of
													 true->[1001,?FST_MAXTIMES + AwardTimes];
													 false->[1046,?FST_MAXTIMES]
												 end,
 									case lib_dungeon:check_dungeon_times(Status#player.id, FstSceneId, FstMaxTimes) of
										{fail,_Counter} ->
											case is_fst_id(SceneId) of
												true->
													Warning = io_lib:format("每天进入封神台不能超过~p次!",[ FstMaxTimes]);
												false->
													Warning = io_lib:format("每天进入诛仙台不能超过~p次!",[ FstMaxTimes])
											end,
											{false, 0, 0, 0, tool:to_binary(Warning), 0, []};
%% 											case lists:member(SceneId,[1006,1012,1018]) of
%% 												false->
%% 													case is_fst_id(SceneId) of
%% 														true->
%% 															Warning = io_lib:format("每天进入封神台不能超过~p次!",[ FstMaxTimes]);
%% 														false->
%% 															Warning = io_lib:format("每天进入诛仙台不能超过~p次!",[ FstMaxTimes])
%% 													end,
%% 													{false, 0, 0, 0, tool:to_binary(Warning), 0, []};
%% 												true->
%% 													check_enter_fst_action(NewStatus, Scene, SceneId, FstPidList, Counter, FstMaxTimes,TeamNum, enter)
%% 											end;
										{pass, Counter} ->
											%%
											check_enter_fst_action(NewStatus, Scene, SceneId, FstPidList, Counter + 1, FstMaxTimes,TeamNum, enter)
									end
		                    end;
						false->
							{false, 0, 0, 0, <<"层数异常，请与GM联系">>, 0, []}
					end;
                _ ->
					FstSceneId = Scid rem 10000,
                    ScenePid =
                        case lists:keysearch(FstSceneId, 1, Status#player.other#player_other.pid_fst) of
                            {value,{_, Fst_pid_from_player}} ->
                                Fst_pid_from_player;
                            _ ->
                                Status#player.other#player_other.pid_dungeon
                        end,
                    case catch gen_server:call(ScenePid, {apply_call, lib_mon, is_alive_scene_mon, [Scid]}) of
                        {'EXIT', _Reason} ->
                            {false, 0, 0, 0, <<"操作发送失败，请再点击！">>, 0, []};
                        Ret ->
							[ResSuc, ResFlt] =
								case SceneId-FstSceneId =/= 1 of
									true->
										[finished, <<"亲，你用挂了">>];
									false->
		                        		case Scid rem 100 of
		                            		30 ->
		                                		[finished, <<"恭喜您通关成功">>];
											65 ->
		                                		[finished, <<"恭喜您通关成功">>];
		                            		_ ->
		                                		[next, <<"本层怪还没有消灭，无法前往更高层。">>]
		                        		end
								end,
                            case Ret of
                           		false ->
                                    case ResSuc of
                                        finished ->
											{false, 0, 0, 0, ResFlt, 0, []};
                                        _ ->
                                            [NewStatus,TeamNums] =
                                                case misc:is_process_alive(Status#player.other#player_other.pid_team) of
                                                    true ->
                                                        case catch gen_server:call(Status#player.other#player_other.pid_team, 'GET_TEAM_INFO') of
                                                            {'EXIT', _} ->
                                                                [Status,1];
                                                            TeamInfo ->
                                                                PD_fst = 
                                                                    case lists:keysearch(FstSceneId, 1, TeamInfo#team.fst_pid) of
                                                                        {value,{_, Fst_pid_from_team}} ->
                                                                            Fst_pid_from_team;
                                                                        _ ->
                                                                            TeamInfo#team.dungeon_pid
                                                                    end,
                                                                F = fun({U_scid, Pid}) -> {U_scid rem 10000, Pid} end,
                                                                NewList = lists:map(F, TeamInfo#team.fst_pid),
                                                                mod_delayer:update_delayer_info(Status#player.id, PD_fst, NewList, Status#player.other#player_other.pid_team),
                                                                [Status#player{other = Status#player.other#player_other{pid_fst = NewList, pid_dungeon = PD_fst}},length(TeamInfo#team.member)]
                                                        end;
                                                    _ ->
                                                        [Status,1]
                                                end,
                                            Now_fst_loc = lib_scene:get_scene_id_from_scene_unique_id(NewStatus#player.scene) rem 100,
                                            [Exp, Spr, Hor, _Lefttime] = get_tower_award(Now_fst_loc),
											[FstHonor,ZxtHonor] = if Now_fst_loc=<30->
																		 [Hor,0];
																	 true->
																		 [0,Hor]
																  end,
                                            Status1 = lib_player:add_fst_esh(NewStatus, Exp, Spr, FstHonor,ZxtHonor),
											
                                            FstPidList = Status1#player.other#player_other.pid_fst,
										
											check_enter_fst_action(Status1, Scene, SceneId, FstPidList, 0, 0,TeamNums, next)
                                    end;										
                          		true ->
                               		{false, 0, 0, 0,<<"本层怪还没有消灭，无法前往更高层。">>, 0, []}	
                            end
                    end
            end;
		Ret ->
			Ret
	end.

%% 进入副本场景检查
check_enter_fst_action(Player, Scene, SceneId, FstPidList, Counter, FstMaxTimes,TeamNums, Action) ->
	[IsFstAlive, Pid_fst_next] = 
        case lists:keysearch(SceneId, 1, FstPidList) of
            {value,{SceneId, Fst_pid}} ->
                [misc:is_process_alive(Fst_pid), Fst_pid];
            _ ->
                [false, []]
        end,
    case IsFstAlive of
        %% 已经有副本服务进程
        true ->
            case mod_fst:join(Pid_fst_next, [SceneId, Player#player.id, Player#player.other#player_other.pid, Player#player.other#player_other.pid_fst]) of
				true->
					%%诛仙台人数限制为最多3为玩家
					if SceneId>=1046 andalso TeamNums >3 ->
						    {false, 0, 0, 0, <<"诛仙台组队模式只支持1到3位玩家,队伍人数过多！">>, 0, []};
					   true->
            				enter_fst_scene(Scene, Player, Action, SceneId, Pid_fst_next, Counter, FstMaxTimes)
					end;
				false->
					{false, 0, 0, 0, <<"系统繁忙，请重试!">>, 0, []}
			end;
        %% 还没有副本服务进程
        false -> 
            Result = 
                case misc:is_process_alive(Player#player.other#player_other.pid_team) of
                    %% 没有队伍，角色进程创建副本服务器
                    false ->	
						gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'del_member',[Player#player.id]}),
                        mod_fst:start(0, self(), SceneId, [{Player#player.id, 
                                    Player#player.other#player_other.pid, Pid_fst_next}],[]);
                    %% 有队伍，由队伍进程创建副本服务器
                    true ->				
						case (Player#player.other#player_other.leader =:= 1 andalso Action =:= enter) orelse Action =:= next of
                       		true ->
                                mod_team:create_fst(Player#player.other#player_other.pid_team, self(), 
                                                    SceneId, [SceneId, Player#player.id, 
                                                    Player#player.other#player_other.pid,
                                                    Pid_fst_next]);
                       		false ->
								case is_fst_id(SceneId) of
									true->
                                		{fail, <<"只有队长才能创建新封神台">>};
									false->
										{fail, <<"只有队长才能创建新诛仙台">>}
								end
                        end
                end,
            [_, _, _, LeftTime] = get_tower_award(SceneId rem 100),
            {ok, BinData} = pt_35:write(35004, [LeftTime, 0]),
            lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
            case Result of 
                {ok, Pid} ->
                    enter_fst_scene(Scene, Player, Action, SceneId, Pid, Counter, FstMaxTimes);										
                {fail, Msg} ->
                    {false, 0, 0, 0, Msg, 0, []}
            end
    end.

%% 进入封神台场景
enter_fst_scene(Scene, Status, Action, SceneId, ScenePid, Counter, FstMaxTimes) ->
	Res = mod_fst:check_enter(Scene#ets_scene.sid, Scene#ets_scene.type, ScenePid),
    case [Res, Action] of
        [{false, Msg}, _] ->
            {false, 0, 0, 0, Msg, 0, []};
        [{true, UniqueId}, enter] ->
            FstResId = lib_scene:get_scene_id_from_scene_unique_id(Status#player.scene),
			case data_scene:get(FstResId) of
                []  -> 
                    {false, 0, 0, 0, <<"场景出错_2!">>, 0, []};
             	S ->
					spawn(fun()-> 
						db_agent:delete_log_fst(Status#player.id),
                    	db_agent:add_log_fst(Status#player.id)	  
					end),				
                    %% 初始化累积的经验灵力荣誉
                    PlayerStatus = Status#player{
                        other = Status#player.other#player_other{
                            fst_exp_ttl = 0, 
                            fst_spr_ttl = 0, 
                            fst_hor_ttl = 0
                        }
                    },
                    enter_fst_scene_action(PlayerStatus, SceneId, ScenePid, Scene, S, UniqueId, Counter, FstMaxTimes)
            end;
		
		%% 通关进入下一层封神台
		[{true, UniqueId}, _] ->
			case data_scene:get(SceneId) of
                []  -> 
                    {false, 0, 0, 0, <<"场景出错_2!">>, 0, []};
                S ->
                    [Horon, Exp, Spt] = [Status#player.other#player_other.fst_hor_ttl, Status#player.other#player_other.fst_exp_ttl, Status#player.other#player_other.fst_spr_ttl],
                    %% 累积的经验灵力荣誉
                    Now = util:unixtime(),
					case is_fst_id(SceneId) of
						true->
							spawn(fun()-> db_agent:update_log_fst(Status#player.id, Horon, Exp, Spt, SceneId rem 100 - 1, Now, 1,1) end);
					   false->
						   spawn(fun()-> db_agent:update_log_fst(Status#player.id, Horon, Exp, Spt, SceneId rem 100 - 1-45, Now, 1,2) end)
					end,
					%%是否有怪物，无则通知显示NPC
					case lib_scene:get_scene_mon(Status#player.scene) of
						[]->
							{ok,BinData} = pt_32:write(32002,<<>>),
							lib_send:send_to_uid(Status#player.id,BinData);
						_->
							skip
					end,
					enter_fst_scene_action(Status, SceneId, ScenePid, Scene, S, UniqueId, 0, 0)
            end			
    end.

%% 进入封神台
enter_fst_scene_action(Player, SceneId, ScenePid, Scene, S, UniqueId, FstTimes, FstMaxTimes) ->
	case is_fst_id(SceneId) of
		true->
			Loc = SceneId rem 100;
		false->
			Loc = SceneId rem 100-45
	end,
	FstList = [
		Loc,
		Player#player.other#player_other.fst_hor_ttl, 
		Player#player.other#player_other.fst_exp_ttl, 
		Player#player.other#player_other.fst_spr_ttl
	],
    {ok, BinData} = pt_35:write(35000, FstList),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
    FstPidList = lists:keydelete(SceneId, 1, Player#player.other#player_other.pid_fst),
    NewFstPidList = lists:keymerge(1, FstPidList, [{SceneId, ScenePid}]),
    NewPlayer = Player#player{
		other = Player#player.other#player_other{
			pid_fst = NewFstPidList, 
			pid_dungeon = ScenePid
		}
	},
	%% 成功进入更新进入副本次数，只需要更新第一层的数据
	case lists:member(Scene#ets_scene.sid,[1001,1046,1006,1012,1018] ) of
		true->
            case lib_scene:is_copy_scene(Player#player.scene) of
				false->
					DungeonId = if Scene#ets_scene.sid ==1001->
									   1001;
								   Scene#ets_scene.sid == 1046 ->
									   1046;
								   true->1001
								end,
					lib_dungeon:add_dungeon_times(Player#player.id, DungeonId); 
				true->skip
			end;
		false->skip
	end,
	case lib_scene:get_scene_mon(Player#player.scene) of
		[]->
			{ok,BinData32002} = pt_32:write(32002,<<>>),
			lib_send:send_to_uid(Player#player.id,BinData32002);
		_->
			skip
	end,
    mod_delayer:update_delayer_info(NewPlayer#player.id, ScenePid, NewFstPidList, NewPlayer#player.other#player_other.pid_team),
    %% 进入副本场景卸下坐骑
	{ok, RetPlayer} = lib_goods:force_off_mount(NewPlayer),
    Msg = io_lib:format("您的队友~s进入了~s", [RetPlayer#player.nickname, Scene#ets_scene.name]),
    {ok, TeamBinData} = pt_15:write(15055, [Msg]),
    gen_server:cast(RetPlayer#player.other#player_other.pid_team,
                                {'SEND_TO_OTHER_MEMBER', RetPlayer#player.id, TeamBinData}),
    [RX, RY] =
        case [{X, Y} || [_Index, Id, _Name, X, Y] <- Scene#ets_scene.elem, Id =:= S#ets_scene.sid] of
            [] -> 
                [Scene#ets_scene.x, Scene#ets_scene.y];
            [{X, Y}] -> 
                [X, Y]
        end,
	%%封神台每2层共用一张地图，诛仙台每2层共用一张地图，诛仙台最后一层有独立的地图
	if Scene#ets_scene.sid =:=1065->
		   FstResId =Scene#ets_scene.sid;
	   true->
		   case is_fst_id(Scene#ets_scene.sid) of
			   true->
				   FstResId = Scene#ets_scene.sid - ((Scene#ets_scene.sid - 1) rem 1000 rem 2);
			   false->
				   FstResId = Scene#ets_scene.sid - (Scene#ets_scene.sid  rem 1000 rem 2)
		   end
	end,
    {true, UniqueId, RX, RY, Scene#ets_scene.name, FstResId, FstTimes, FstMaxTimes, RetPlayer}.


%% 离开封神台
quit_fst(Player) ->
	FstSceneId = Player#player.scene rem 10000,
	if 
		FstSceneId >= 1000 ->
			ScenePid =
				case lists:keysearch(FstSceneId, 1, Player#player.other#player_other.pid_fst) of
					{value,{_, Fst_pid_from_player}} ->
						Fst_pid_from_player;
					_ ->
						Player#player.other#player_other.pid_dungeon
				end,
			RetPlayer = 
                case catch gen_server:call(ScenePid, {apply_call, lib_mon, is_alive_scene_mon, [Player#player.scene]}) of
                    {'EXIT', _Reason} ->
%% ?WARNING_MSG("fst_quit_error: SceneId=~p ScenePid=~p Reason=~p", [FstSceneId, ScenePid, Reason]),
                        Player;
                    Ret ->
                        NewPlayer =
                            case Ret of
                                false ->
                                    FSceneId = Player#player.scene rem 100,
                                    [Exp, Spr, Hor, _LeftTime] = get_tower_award(FSceneId),
                                    [NewExp, NewSpt, NewHor, NewLoc] =
                                        case db_agent:get_log_fst(Player#player.id) of
                                            [] ->
                                                [Exp, Spr, Hor, FSceneId];
                                            [[Hor_log, Exp_log, Spr_log, Loc, _Endtime]] ->
                                                [Exp_log + Exp, Spr_log + Spr, Hor_log + Hor, Loc + 1]
                                        end,
                                    spawn(fun()-> send_fst_mail(Player, NewLoc, NewExp, NewSpt, NewHor) end),
                                    [FstHonor,ZxtHonor] = if FSceneId=<30->
                                                                 [Hor,0];
                                                             true->
                                                                 [0,Hor]
                                                          end,
                                    lib_player:add_fst_esh(Player, Exp, Spr, FstHonor, ZxtHonor);
                                true ->
                                    case db_agent:get_log_fst(Player#player.id) of
                                        [] -> skip;
                                        [[Horon, Exp, Spirit, Loc, _Endtime]] ->
                                            spawn(fun()-> send_fst_mail(Player, Loc, Exp, Spirit, Horon) end);
                                        _ -> skip
                                    end,
                                    Player							
                            end,
                        spawn(fun()-> db_agent:delete_log_fst(Player#player.id) end),
                        NewPlayer		
                end,
			DungeonData = data_dungeon:get(FstSceneId),
          	[NextSenceId, X, Y] = DungeonData#dungeon.out,
%% 			?DEBUG("BEFORE SEND OUT playerId = ~p~n",[Player#player.id]),
       		gen_server:cast(Player#player.other#player_other.pid, {send_out_fst, [NextSenceId, X, Y]}),
			RetPlayer;
		true ->
			Player
	end.

%% 发送封神台信件
send_fst_mail(Player, Loc, Exp, Spirit, Horon) ->
	Now = util:unixtime(),
	case is_fst_id(Player#player.scene) orelse lib_scene:is_fst_scene(Player#player.scene) of
		true->
			if 
				Loc == 30 ->
					GoodsType = 28814,
					Num = 1;
				true ->
					GoodsType = 0,
					Num = 0
			end,
			db_agent:add_fst_log_bak(Player#player.id, Loc,1 , Now),
			Content = io_lib:format("封神台闯关结束，闯至~s层，共计获得~s经验，~s灵力和~s荣誉。通关封神台30层，可获得1个封神通关礼包。", [tool:to_list(Loc),tool:to_list(Exp),tool:to_list(Spirit),tool:to_list(Horon)]),
			db_agent:insert_mail(0, Now, "系统", Player#player.id, "封神台闯关记录", Content, 0, GoodsType, Num, 0, 0);		
		false->
			if 
				Loc == 20 ->
					GoodsType = 28815,
					Num = 1;
				true ->
					GoodsType = 0,
					Num = 0
			end,
			db_agent:add_fst_log_bak(Player#player.id, Loc,2, Now),
			Content = io_lib:format("诛仙台闯关结束，闯至~s层，共计获得~s经验，~s灵力和~s荣誉。通关诛仙台20层，可获得1个诛仙通关礼包。", [tool:to_list(Loc),tool:to_list(Exp),tool:to_list(Spirit),tool:to_list(Horon)]),
			db_agent:insert_mail(0, Now, "系统", Player#player.id, "诛仙台闯关记录", Content, 0, GoodsType, Num, 0, 0)
	end,
	lib_mail:check_unread(Player#player.id).

%% 检查判断进入场景的一些基本条件
check_enter_base_condition(Player,SceneId) ->
	case is_fst_id(SceneId) orelse lib_scene:is_fst_scene(SceneId) of
		true->
			if 
				Player#player.evil >= 450 ->
					{false, 0, 0, 0, <<"您处于红名状态，不能进入封神台!">>, 0, []};
				Player#player.carry_mark > 0 andalso Player#player.carry_mark < 4 orelse (Player#player.carry_mark >=20 andalso Player#player.carry_mark<26)->
					{false, 0, 0, 0, <<"运镖状态不能进入封神台！">>, 0, []};
				Player#player.carry_mark > 3 andalso Player#player.carry_mark < 8 ->
					{false, 0, 0, 0, <<"跑商状态不能进入封神台！">>, 0, []};
				Player#player.arena > 0 ->
					{false, 0, 0, 0, <<"战场状态不能进入封神台！">>, 0, []};
				true ->
					true	
			end;
		false->
			if 
				Player#player.evil >= 450 ->
					{false, 0, 0, 0, <<"您处于红名状态，不能进入诛仙台!">>, 0, []};
				Player#player.carry_mark > 0 andalso Player#player.carry_mark < 4 orelse (Player#player.carry_mark >=20 andalso Player#player.carry_mark<26) ->
					{false, 0, 0, 0, <<"运镖状态不能进入诛仙台！">>, 0, []};
				Player#player.carry_mark > 3 andalso Player#player.carry_mark < 8 ->
					{false, 0, 0, 0, <<"跑商状态不能进入诛仙台！">>, 0, []};
				Player#player.arena > 0 ->
					{false, 0, 0, 0, <<"战场状态不能进入诛仙台！">>, 0, []};
				true ->
					true	
			end
	end.

%%进入的场景id是否封神台
is_fst_id(SceneId)->
	SceneId>=1001 andalso SceneId=<1030.

%%进入的场景id是否诛仙台
is_zxt_id(SceneId)->
	SceneId>=1046 andalso SceneId=< 1065.

%%加载诛仙台荣誉
get_zxt_honor(PlayerId)->
	case db_agent:select_zxt_honor(PlayerId) of
		[]->0;
		[Honor]->case Honor of
					 undefined->0;
					 null->0;
					 _->Honor
				 end
	end.

%%更新诛仙台荣誉
update_zxt_honor(PlayerId,Honor)->
	db_agent:update_zxt_honor(PlayerId,Honor).

%%更新封神台荣誉
update_fst_honor(PlayerId,Honor) ->
	db_agent:mm_update_player_info([{honor,Honor}], [{id,PlayerId}]).

%%增加诛仙台荣誉
add_zxt_honor(PlayerStatus,Honor)->
	add_honor_tips(PlayerStatus,Honor),
	NewHonor = PlayerStatus#player.other#player_other.zxt_honor+Honor,
	update_zxt_honor(PlayerStatus#player.id,NewHonor),
	PlayerStatus#player{
						other = PlayerStatus#player.other#player_other{
                           		zxt_honor=NewHonor
								}
                    		}.

%%减少诛仙台荣誉
cost_zxt_honor(PlayerStatus,Honor,GoodsId,Num)->
	NewHonor = case PlayerStatus#player.other#player_other.zxt_honor > Honor of
				   true->PlayerStatus#player.other#player_other.zxt_honor - Honor;
				   false->0
			   end,
	update_zxt_honor(PlayerStatus#player.id,NewHonor),
	spawn(fun()-> db_agent:log_zxt_honor(PlayerStatus#player.id,Honor,GoodsId,Num,util:unixtime())end),
	PlayerStatus#player{
						other = PlayerStatus#player.other#player_other{
                           		zxt_honor=NewHonor
								}
                    		}.

add_fst_honor(PlayerStatus,Honor) ->
	add_fst_honor_tips(PlayerStatus,Honor),
	NewHonor = PlayerStatus#player.honor + Honor,
	update_fst_honor(PlayerStatus#player.id,NewHonor),
	PlayerStatus#player{honor = NewHonor}.

%%判断荣誉是否足够
is_enough_zxt_honor(PlayerStatus,Honor)->
	PlayerStatus#player.other#player_other.zxt_honor >= Honor.

%%荣誉增加提示
add_honor_tips(PlayerStatus,Honor)->
	Msg = io_lib:format("诛仙台荣誉增加~p",[Honor]),
	{ok,MyBin} = pt_15:write(15055,[Msg]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin).

add_fst_honor_tips(PlayerStatus,Honor) ->
	Msg = io_lib:format("封神台台荣誉增加~p",[Honor]),
	{ok,MyBin} = pt_15:write(15055,[Msg]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin).


%% 初始化用户场景
init_player_scene(Player) ->
	[Fst_exp_ttl, Fst_spr_ttl, Fst_hor_ttl] =
		case db_agent:get_log_fst(Player#player.id) of
			[[Hor_log, Exp_log, Spr_log, _Loc, _Endtime]] -> 
				[Exp_log, Spr_log, Hor_log];
			_ -> 
				[0, 0, 0]
		end,
	Player#player{
		other = Player#player.other#player_other{
			fst_exp_ttl = Fst_exp_ttl, 
			fst_spr_ttl = Fst_spr_ttl, 
			fst_hor_ttl = Fst_hor_ttl
		}
	}.


%% 封神台记录更新
%% Loc 封神台层数
%% ThruTime 通关时间
%% BC 是否广播
set_fst_god(Player, Action, Loc, ThruTime, BC) ->
	IsFst = lib_scene:is_fst_scene(Player#player.scene),
	Operate =
		case IsFst of
			true->
				case Action of
					add ->
						case db_agent:ver_gods(Loc, Player#player.id) of
							[] ->
								add;
							_ ->
								noaction
						end;
					update ->
						case db_agent:ver_gods(Loc, Player#player.id) of
							[] ->
								%% 清除当层霸主
								spawn(fun()-> db_agent:clear_gods(Loc, ThruTime) end),
								add;
							_ ->
								noaction
						end;
					add_checked ->
						add;
					_ ->
						no_action
				end;
			false->
				case Action of
					add ->
						case db_agent:ver_gods_zxt(Loc-45, Player#player.id) of
							[] ->
								add;
							_ ->
								noaction
						end;
					update ->
						case db_agent:ver_gods_zxt(Loc-45, Player#player.id) of
							[] ->
								%% 清除当层霸主
								spawn(fun()-> db_agent:clear_gods_zxt(Loc-45, ThruTime) end),
								add;
							_ ->
								noaction
						end;
					add_checked ->
						add;
				_ ->
						no_action
				end
		end,
	case Operate of
		add ->
			%%14层以上的有广播
			case Loc >= 14 andalso BC of 
				true ->
					NameColor = data_agent:get_realm_color(Player#player.realm),
					case IsFst of
						true->
							ConTent = io_lib:format("恭喜【<a href='event:1, ~p, ~s, ~p, ~p'><font color='~s'><u>~s</u></font></a>】以疾风迅雷般的速度击穿封神台第<font color='#FFFF32'>~p</font>层，成为该层<font color='#8800FF'> 霸主 </font>。",
							[Player#player.id, Player#player.nickname, Player#player.career, Player#player.sex, NameColor,Player#player.nickname, Loc]),
							lib_chat:broadcast_sys_msg(2, ConTent);
						false->
							if Loc-45>=12->%%诛仙台的1层相当于承接封神台的46层
								ConTent = io_lib:format("恭喜【<a href='event:1, ~p, ~s, ~p, ~p'><font color='~s'><u>~s</u></font></a>】以疾风迅雷般的速度击穿诛仙台第<font color='#FFFF32'>~p</font>层，成为该层<font color='#8800FF'> 霸主 </font>。",
								[Player#player.id, Player#player.nickname, Player#player.career, Player#player.sex, NameColor, Player#player.nickname, Loc-45]),
								lib_chat:broadcast_sys_msg(2, ConTent);
							   true->skip
							end
					end;
				false -> 
					skip
			end,
			Light = data_fst:get_suit_light(Player#player.other#player_other.suitid, Player#player.other#player_other.stren),
			case IsFst of
				true->
					%% 清除此ID的低层霸主
					db_agent:clear_gods_lower(Player#player.id, Loc),
					%% 增加封神台霸主
					db_agent:add_fst_god(Loc, ThruTime, Player#player.id, Player#player.lv, Player#player.realm, Player#player.career, Player#player.sex, Light, Player#player.nickname, Player#player.guild_name);
				false->
					ZxtLoc = Loc - 45,
 					db_agent:clear_gods_lower_zxt(Player#player.id, ZxtLoc),
					db_agent:add_zxt_god(ZxtLoc, ThruTime, Player#player.id, Player#player.lv, Player#player.realm, Player#player.career, Player#player.sex, Light, Player#player.nickname, Player#player.guild_name)
			end;
		_ ->
			skip
	end.

