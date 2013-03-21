%%%--------------------------------------
%%% @Module  : pp_scene
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description:  场景
%%%--------------------------------------
-module(pp_scene).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").
-include("hot_spring.hrl").
-include("guild_info.hrl").

%% 走路
%% Player 玩家的record
%% PX x坐标
%% PY y坐标
handle(12001, Player, [X, Y, SceneId]) ->
  	case (Player#player.x /= X orelse Player#player.y /= Y) andalso Player#player.scene == SceneId
			%% 判断有没有被使用定身、昏迷等技能效果
			andalso lists:member(Player#player.other#player_other.battle_limit, [0, 3, 9]) of
		true ->
            {ok, SitPlayer} =
                case Player#player.status of
                    %% 从打坐状态恢复正常状态
                    6 ->
                        lib_player:cancelSitStatus(Player);
					10 ->
                        lib_double_rest:cancel_double_rest(Player);
                    _ ->
                        {ok, Player}
                end,
			lib_scene:change_player_position(SitPlayer, X, Y),
			%% 同步队友位置信息
			if
           		SitPlayer#player.other#player_other.pid_team =/= undefined ->
                    gen_server:cast(SitPlayer#player.other#player_other.pid_team,
                        {'SYNC_TEAMMATE_POSITION', SitPlayer#player.id, X, Y, SitPlayer#player.scene});
          		true ->
                    skip
            end,
            NewPlayer = SitPlayer#player{
                x = X,
                y = Y
            },
            RetPlayer = 
				case lib_war:is_fight_scene(NewPlayer#player.scene) of
					true->
						if NewPlayer#player.carry_mark=:= 26->
							   case check_flag_place(NewPlayer#player.x,NewPlayer#player.y,NewPlayer#player.other#player_other.leader) of
								   false->
%% 									   {ok,BinData} = pt_45:write(45024,[3]),
%% 										lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send, BinData),
									 	NewPlayer;
								   true->
									   {ok,BinData} = pt_45:write(45024,[1]),
										lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send, BinData),
									   gen_server:cast(NewPlayer#player.other#player_other.pid_dungeon,{'COMMIT_FLAG',[NewPlayer#player.other#player_other.pid,
																								NewPlayer#player.id,NewPlayer#player.nickname,
																								NewPlayer#player.other#player_other.leader,
																								NewPlayer#player.carry_mark]}),
									   NewPlayer
							   end;
						   true->
%% 							   {ok,BinData} = pt_45:write(45024,[2]),
%% 								lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send, BinData),
							   NewPlayer
						end;
					false->
						case lib_scene:get_res_id_for_run(NewPlayer#player.scene) of
							%% 空岛
							?SKY_RUSH_SCENE_ID ->
								{SkyRushPlayer, _Player} = lib_skyrush:discard_flags_battle(3, NewPlayer, NewPlayer),
								SkyRushPlayer;
							%% 修仙台最后一层
							1065 ->
								lib_skill:energy_skill(NewPlayer, X, Y);
							?SPRING_SCENE_VIPTOP_ID ->%%温泉场景
								%%温泉里进出水通知
								NewSpring = lib_spring:send_player_spring_site(NewPlayer#player.other#player_other.pid_scene, 
																			   NewPlayer#player.id, X, Y,
																			   NewPlayer#player.other#player_other.is_spring),
								SNPlayer = NewPlayer#player{other = NewPlayer#player.other#player_other{is_spring = NewSpring}},
								mod_player:save_online_diff(Player, SNPlayer),%%同步一次is_spring
								SNPlayer;
%% 								lib_lotus:player_spring_move(NewPlayer);
							300 ->
								lib_peach:check_player_enter_peach(NewPlayer);
							_ ->
                        		NewPlayer
		                end
				end,
			ets:insert(?ETS_ONLINE, RetPlayer),
            {ok, change_status, RetPlayer};
   		false ->
            skip
    end;

%% 进入场景
handle(12002, Status, load_scene) ->
	[X, Y] =
		case get(change_scene_xy) of
			undefined ->
				[Status#player.x, Status#player.y];
			[CS_X, CS_Y] ->
				erase(change_scene_xy),
				[CS_X, CS_Y];
			_ ->
				erase(change_scene_xy),
				[Status#player.x, Status#player.y]
		end,
    case mod_scene:get_scene_info(Status#player.scene, X, Y, Status#player.other#player_other.pid_send) of
        {ok, PidScene} ->
			NewStatus = 
				case lib_spring:is_spring_scene(Status#player.scene) of
					false ->
						case lib_war:is_war_server() of
							true->
								{ok,MountPlayerStatus}=lib_goods:force_off_mount(Status);
							false->
								MountPlayerStatus = Status
						end,
						MountPlayerStatus#player{x = X, 
												 y = Y, 
												 other = Status#player.other#player_other{pid_scene = PidScene}
												};
					true ->%%进温泉，下坐骑，取消挂机，温泉福利
						SpriPlayer = lib_spring:player_comeinto_spring(Status),
						SpriPlayer#player{x = X, 
									  y = Y, 
									  other = SpriPlayer#player.other#player_other{pid_scene = PidScene}
									 }
				end,
			%% 进入场景广播给其他玩家
			 mod_scene:enter_scene(PidScene, NewStatus),
            %% 灵兽进入场景
            case NewStatus#player.other#player_other.out_pet of
                [] -> skip;
                Pet ->	
                    PetColor = data_pet:get_pet_color(Pet#ets_pet.aptitude),
                    {ok, BinData1} = pt_12:write(12031,[Pet#ets_pet.status,Status#player.id,Pet#ets_pet.id,Pet#ets_pet.name,PetColor,Pet#ets_pet.goods_id,Pet#ets_pet.grow,Pet#ets_pet.aptitude]),
                    lib_send:send_to_sid(NewStatus#player.other#player_other.pid_send, BinData1)
            end,
            %%镖旗进入场景 (carry_mark 29 为观战模式，玩家不可见)
            case NewStatus#player.carry_mark > 0 andalso NewStatus#player.carry_mark /=29 of
                true ->
                    {ok,BinData2} = pt_12:write(12041,[Status#player.id,Status#player.carry_mark]),
                    lib_send:send_to_sid(NewStatus#player.other#player_other.pid_send, BinData2);
                false ->
                    skip
            end,
            %%Npc进入场景
            case Status#player.task_convoy_npc of
                0 ->
                    skip;
                NpcId ->
                    case lib_npc:get_data(NpcId) of
                        [] ->NpcName='';
                        NpcInfo ->
                            NpcName = NpcInfo#ets_npc.name
                    end,
                    {ok,BinData3} = pt_12:write(12051,[Status#player.id,NpcId,NpcName]),
                    lib_send:send_to_sid(NewStatus#player.other#player_other.pid_send, BinData3)
            end,
			%% 同步队友位置信息
			if
          		NewStatus#player.other#player_other.pid_team =/= undefined ->
             		gen_server:cast(NewStatus#player.other#player_other.pid_team,
                  		{'SYNC_TEAMMATE_POSITION', NewStatus#player.id, X, Y, NewStatus#player.scene});
          		true ->
              		skip
            end,
			%%封神台，是否需要显示神秘商人
			mod_fst:check_display_npc(NewStatus#player.id,NewStatus#player.scene,NewStatus#player.other#player_other.pid_dungeon,NewStatus#player.other#player_other.pid_fst),
                    %%保证玩家出温泉后换回原来的着装
%%                     SpriNewStatus = NewStatus#player{other=NewStatus#player.other#player_other{is_spring = 0}},
					%% 进入九霄，发送九霄城主信息
					if
						NewStatus#player.scene =:= 300 ->
							GuildPid = mod_guild:get_mod_guild_pid(),
							case is_pid(GuildPid) of
								true ->
									gen_server:cast(GuildPid, {apply_asyn_cast, lib_castle_rush, get_castle_rush_king, [NewStatus#player.other#player_other.pid_send]});
								false ->
									skip
							end;
						true ->
							case lib_marry:is_wedding_scene(NewStatus#player.scene) of
								true ->
									lib_marry:make_dinner_table(NewStatus#player.other#player_other.pid_send);
								false ->
                                    %%场景分线列表 101雷泽有分线
                                    case lists:member(NewStatus#player.scene, [101, 190, 191]) of
                                        true ->
											AutoBranching = config:get_auto_branching(),
											if 
												AutoBranching == 1 ->
												   	Pattern = #player{scene = 101 ,_='_'},		
													OnlineNum = length(ets:match_object(?ETS_ONLINE_SCENE, Pattern)),
													if
														OnlineNum > 200 ->
															{ok,BinLine} = pt_12:write(12022,[101,[101,190]]),
                                                    		lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinLine);
														true ->
															skip
													end;
												AutoBranching == 0 ->
													skip;
												true ->
													{ok,BinLine} = pt_12:write(12022,[101,[101,190,191]]),
                                                    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinLine)
											end;							
                                        false ->
											%% 矿点是否出现在场景
            								lib_ore:enter_scene_ore_display(NewStatus)
                                    end		
							end
					end,
					{ok, NewStatus};
        _SceneError ->
            fail
    end;

%% 离开场景
handle(12004, Status, SceneId) ->
	case lib_scene:is_copy_scene(Status#player.scene) of
		true ->
			%%副本的资源场景ID
			DungeonSceneId = lib_scene:get_scene_id_from_scene_unique_id(Status#player.scene),
			%%注意if条件下的判断顺序
			if
				DungeonSceneId == ?DUNGEON_SINGLE_SCENE_ID -> %%单人副本不能切换场景
					skip;
				DungeonSceneId == 998 orelse DungeonSceneId == 999 orelse DungeonSceneId == 901 ->  %% TD 和  试炼副本
					catch ets:delete(?ETS_ONLINE_SCENE, Status#player.id),
					mod_scene:leave_scene(Status#player.id, Status#player.scene, 
										  Status#player.other#player_other.pid_scene, 
										  Status#player.x, Status#player.y);
				DungeonSceneId < 998 -> %% 副本
					case lib_box_scene:is_box_scene_idsp(Status#player.scene, Status#player.id) of
						true ->
							mod_box_scene:quit_box_scene(Status#player.other#player_other.pid_scene, Status#player.id, Status#player.scene),
							catch ets:delete(?ETS_ONLINE_SCENE, Status#player.id);
						false ->
							mod_dungeon:quit(Status#player.other#player_other.pid_dungeon, Status#player.id, SceneId),
							mod_dungeon:clear(Status#player.other#player_other.pid_dungeon),
							catch ets:delete(?ETS_ONLINE_SCENE, Status#player.id),
							mod_scene:leave_scene(Status#player.id, Status#player.scene, 
								  Status#player.other#player_other.pid_scene, 
								  Status#player.x, Status#player.y)
					end;
				DungeonSceneId >=1001 andalso DungeonSceneId =< 1030 -> %% 封神台 封神台的资源场景ID在1001~1030
					PD_fst = 
						case lists:keysearch(DungeonSceneId, 1, Status#player.other#player_other.pid_fst) of
							{value,{_SceneId, Fst_pid_from_team}} ->
								Fst_pid_from_team;
							_ ->
								Status#player.other#player_other.pid_dungeon
						end,
					mod_fst:fst_to_next(PD_fst, Status#player.id),
					catch ets:delete(?ETS_ONLINE_SCENE, Status#player.id),
					mod_scene:leave_scene(Status#player.id, Status#player.scene, 
										  Status#player.other#player_other.pid_scene, 
										  Status#player.x, Status#player.y);
				true->
					PD_fst = 
						case lists:keysearch(DungeonSceneId, 1, Status#player.other#player_other.pid_fst) of
							{value,{_SceneId, Fst_pid_from_team}} ->
								Fst_pid_from_team;
							_ ->
								Status#player.other#player_other.pid_dungeon
						end,
					mod_fst:fst_to_next(PD_fst, Status#player.id),
					catch ets:delete(?ETS_ONLINE_SCENE, Status#player.id),
					mod_scene:leave_scene(Status#player.id, Status#player.scene, 
										  Status#player.other#player_other.pid_scene, 
										  Status#player.x, Status#player.y)
			end;
		_ ->
			catch ets:delete(?ETS_ONLINE_SCENE, Status#player.id),
			mod_scene:leave_scene(Status#player.id, Status#player.scene, 
										  Status#player.other#player_other.pid_scene, 
										  Status#player.x, Status#player.y)
	end,

	ok;

%% 切换场景
handle(12005, Status, SceneId) ->
	if
		SceneId =:= Status#player.scene  ->
			put(change_scene_xy , [Status#player.x, Status#player.y]),
			NewSceneId = 
				case lists:member(SceneId, [?NEW_PLAYER_SCENE_ID, ?NEW_PLAYER_SCENE_ID_TWO, ?NEW_PLAYER_SCENE_ID_THREE]) of
					true ->
						?NEW_PLAYER_SCENE_ID;
					false ->
						case lists:member(SceneId, data_scene:get_hook_scene_list()) of
							true -> 
								120;
							false ->
								%%跨服战场场景id
								case lib_war:is_war_scene(SceneId) of
									true ->
										SceneId rem 1000 ;
									false ->
										lib_scene:get_res_id(SceneId)
								end
						end
				end,
			SceneName =
				case data_scene:get(NewSceneId) of
					[] ->
						<<>>;
					Scene ->
						Scene#ets_scene.name
				end,
			{ok, BinData} = pt_12:write(12005, [SceneId, Status#player.x, Status#player.y, SceneName, NewSceneId, 0, 0, Status#player.other#player_other.leader]),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
		true ->
			%% 副本的资源场景ID
			DungeonSceneId = lib_scene:get_scene_id_from_scene_unique_id(Status#player.scene),
			case DungeonSceneId of
				%% 单人副本
				?DUNGEON_SINGLE_SCENE_ID ->
					skip;
				%% 幻魔穴
				?CAVE_RES_SCENE_ID ->
					case lib_scene:check_enter(Status, SceneId) of
                        {false, _, _, _, Msg, _, _} ->
                            {ok, BinData} = pt_12:write(12005, [0, 0, 0, Msg, 0, 0, 0, 0]),
                            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
                        {true, NewSceneId, X, Y, Name, SceneResId, _DungeonTimes, _DungeonMaxtimes, Status1} ->
                            %% 告诉客户端新场景情况
							{ok, BinData} = pt_12:write(12005, [NewSceneId, X, Y, Name, SceneResId, 0, 0, 0]),
                            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
                            Status2 = Status1#player{
                                scene = NewSceneId, 
                                x = X, 
                                y = Y
                            },
							mod_scene:leave_scene1(Status#player.id, Status#player.scene, 
										  Status#player.other#player_other.pid_scene, 
										  Status#player.x, Status#player.y),
                            put(change_scene_xy , [X, Y]),
                            {ok, change_ets_table, Status2}
                    end;
				_ ->
					SceneId1 = 
						case lib_war:is_war_scene(SceneId) of
							true->
								SceneId rem 1000 ;
							false->
								SceneId
						end,
                    case lib_scene:check_enter(Status, SceneId1) of
                        {false, _, _, _, Msg, _, _} ->
                            {ok, BinData} = pt_12:write(12005, [0, 0, 0, Msg, 0, 0, 0, 0]),
                            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
                        {true, NewSceneId, X, Y, Name, SceneResId, DungeonTimes, DungeonMaxtimes, Status1} ->
							lib_scene:set_hooking_state(Status, NewSceneId),
                            Process_id = self(),
                            spawn(erlang, garbage_collect, [Process_id]),
                            %% 告诉原来场景玩家你已经离开
                            handle(12004, Status, Status#player.scene),
                            %% 告诉客户端新场景情况
                            {ok, BinData} = pt_12:write(12005, [NewSceneId, X, Y, Name, SceneResId, DungeonTimes, DungeonMaxtimes, 0]),
                            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
                            Status2 = Status1#player{
								scene = NewSceneId, 
								x = X, 
								y = Y
							},
                            put(change_scene_xy , [X, Y]),
                            {ok, change_ets_table, Status2}
                    end
			end
    end;

%% 获取当前场景NPC列表
handle(12023, Player, SceneId) ->
	try 
		gen_server:cast(mod_scene:get_scene_pid(SceneId, undefined, undefined),
				 {apply_asyn_cast, lib_scene, get_scene_npc_list, [SceneId, Player#player.other#player_other.pid_send]})			
	catch
		_:_ -> []
	end;

%% 离开副本场景(只是副本)
handle(12030, Status, _Action) when Status#player.status == 10 ->
	{ok, BinData} = pt_12:write(12005, [0, 0, 0, <<"请取消双休状态再离开副本!">>, 0, 0, 0, 0]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);

handle(12030, Status, Action) ->
	%% 副本的资源场景ID
	SceneId = lib_scene:get_scene_id_from_scene_unique_id(Status#player.scene),
	case SceneId of
		?DUNGEON_SINGLE_SCENE_ID ->%%909 单人副本需完成任务才能离开
			case mod_single_dungeon:check_leave(Status) of
				true ->
					mod_single_dungeon:quit(Status#player.other#player_other.pid_dungeon, Status#player.id, Status#player.scene);
				false ->
					{ok,MsgData} = pt_15:write(15055,["任务还没完成，不能离开副本!"]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send,MsgData)
			end;			
		SceneId ->
			case Action of
				leave_team ->
					ok;
				_ ->
					Scene = data_scene:get(SceneId),
					Msg= io_lib:format("您的队友~s离开了~s",[Status#player.nickname, Scene#ets_scene.name]),
					{ok,TeamBinData} = pt_15:write(15055,[Msg]),
					gen_server:cast(Status#player.other#player_other.pid_team,
								{'SEND_TO_OTHER_MEMBER', Status#player.id, TeamBinData})
			end,
			if
				SceneId =:= 998 orelse SceneId =:= 999 -> %%TD
    				mod_td:quit(Status#player.other#player_other.pid_dungeon, Status#player.id, Status#player.scene),
    				mod_td:clear(Status#player.other#player_other.pid_dungeon);
				%% 离开试炼副本
				SceneId =:= 901 ->
					mod_training:quit(Status#player.other#player_other.pid_dungeon, Status#player.id, Status#player.scene),
					mod_training:clear(Status#player.other#player_other.pid_dungeon);
				SceneId >= 1101 andalso SceneId =< 1115 ->
					mod_era:quit(Status#player.other#player_other.pid_dungeon, Status#player.id, Status#player.scene),
					mod_era:clear(Status#player.other#player_other.pid_dungeon);
				%% 普通副本
				true ->
    				mod_dungeon:quit(Status#player.other#player_other.pid_dungeon, Status#player.id, Status#player.scene),
    				mod_dungeon:clear(Status#player.other#player_other.pid_dungeon)
			end
	end;

%% 获取场景相邻关系数据
handle(12080, Player, []) ->
	SceneBorderList = data_scene:scene_border_list(),
    {ok, BinData} = pt_12:write(12080, [SceneBorderList]),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);

%% 获取副本次数列表
handle(12100, Player, []) ->
	%%普通副本
	DungeonList = data_scene:dungeon_type2_get_id_list(),
	{DungeonPlayer, _, AwardTimes} = lib_vip:get_vip_award(dungeon, Player),
	{ok, DTimesList} = lib_dungeon:get_dungeon_times_list(Player#player.id, Player#player.lv, DungeonList, AwardTimes, []),
	%%试炼副本
	{ok, TrainTimesList} = lib_dungeon:get_dungeon_times_list(Player#player.id, Player#player.lv, [901], 0, []),
	%%70副本
	{DungeonPlayer, _, CaveTimes} = lib_vip:get_vip_award(cave, Player),
	{ok, CaveTimesList} = lib_dungeon:get_dungeon_times_list(Player#player.id, Player#player.lv, [?CAVE_RES_SCENE_ID],CaveTimes, []),
	%%封神台
	{FstPlayer, _, FstAwardTimes} = lib_vip:get_vip_award(fst, DungeonPlayer),
	{ok, FstTimesList} = lib_dungeon:get_dungeon_times_list(Player#player.id, Player#player.lv, [1001], FstAwardTimes, []),
%% 	{NewPlayerStatus1,_,ZxtAwardTimes} = lib_vip:get_vip_award(zxt,NewPlayerStatus),
	%%诛仙台
	{ok, ZxtTimesList} = lib_dungeon:get_dungeon_times_list(Player#player.id, Player#player.lv, [1046], 0, []),
	%%镇妖塔
	{ok, TdTimesList} = lib_dungeon:get_dungeon_times_list(Player#player.id, Player#player.lv, [998, 999], 0, []),
	
	{ok, BinData} = pt_12:write(12100, DTimesList ++ TrainTimesList++ CaveTimesList++FstTimesList ++ TdTimesList ++ ZxtTimesList),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	List = [
		{vip, FstPlayer#player.vip},
		{vip_time, FstPlayer#player.vip_time}
	],
	mod_player:save_online_info_fields(FstPlayer, List),
	{ok, change_status, FstPlayer};

%%获取水晶信息
handle(12301, Status, [SparId]) ->
	{NewSparID, X, Y} = lib_box_scene:get_spar_coord(SparId),
	{ok,BinData} = pt_12:write(12301, [NewSparID, X, Y]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;

%%诛邪副本拾取水晶
handle(12302, Status, [SparId]) ->
	case tool:is_operate_ok(pp_12302, 1) of
		true ->
			{Result, GoodsTypeId} = mod_box_scene:kill_spar(Status, SparId);
		false ->%%太快了，把包过滤掉
			{Result, GoodsTypeId} = {5, 0}
	end,
	{ok,BinData} = pt_12:write(12302,[Result, GoodsTypeId, SparId]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;
%%离开诛邪副本
handle(12303, Status, []) ->
	NewStatus = mod_box_scene:quit_box_scene(Status),
	{ok, change_ets_table, NewStatus};

%%进入诛邪副本
handle(12304, Status, []) ->
	NewPlayerStatus0 = mod_box:box_enter_scene(Status),
	%%进入副本场景卸下坐骑
	{ok, NewPlayerStatus} = lib_goods:force_off_mount(NewPlayerStatus0),
	{ok, change_ets_table, NewPlayerStatus};

%%进入挂机场景
handle(12400, Status, [SceneId])->
	case lib_scene:enter_hooking_scene(Status,SceneId) of
		{false,Res}->
			{ok,BinData} = pt_12:write(12400,[Res]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
		{true,NewStatus}->
			{ok,change_ets_table,NewStatus}
	end;
%%查询挂机去状态
handle(12401,Status,[])->
	lib_hook:send_open_msg(Status);

%%请求离开试炼副本
handle(12049, Status, _)->
	case catch gen_server:call(Status#player.other#player_other.pid_dungeon,{check_leave}) of
		0 -> Code = 0;
		_ -> Code = 1
	end,
	{ok,BinData} = pt_12:write(12049,[Code]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;


%% -----------------------------------------------------------------
%% 12052 温泉动作操作
%% -----------------------------------------------------------------
handle(12052, Status, [RecId, Face]) ->
	Site = lib_spring:check_hotspring_site(Status#player.x, Status#player.y),
	if
		Site =:= 1 ->%%不在泉水里，不能发起动作
			{ok, BinData12052} = pt_12:write(12052, [8]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData12052),
			ok;
		Status#player.scene =:= ?SPRING_SCENE_VIPTOP_ID 
					  andalso Face =< ?SPRING_FACES_NUM 
					  andalso Face > 0 
		  andalso Status#player.id =/= RecId ->
			mod_spring:spring_faces(self(), Site, Status, RecId, Face);
		true ->%%直接屏蔽错误的请求
			ok
	end;
	
%% -----------------------------------------------------------------
%% 12053 温泉开放与关闭通知
%% -----------------------------------------------------------------
handle(12053, Status, []) ->
	Scene = Status#player.scene,
	case lib_spring:is_spring_scene(Scene) of
		false ->
			lib_spring:check_spring_onsale(Status#player.lv,
								   Status#player.other#player_other.pid_send),
			ok;
		true ->
			skip
	end;
			
	
%% -----------------------------------------------------------------
%% 12054 进入温泉
%% -----------------------------------------------------------------
handle(12054, Status, [Type]) ->
	IsHSpring = lib_spring:is_spring_scene(Status#player.scene),
	case Type =:= 1 andalso  IsHSpring =:= false of
		true ->
			{Result, NewStatus} = mod_spring:enter_spring(Status, Type),
			{ok, BinData} = pt_12:write(12054, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			case Result of
				1 ->
					lib_activity:update_activity_data(hspri, Status#player.other#player_other.pid, Status#player.id, 1),%%添加玩家活跃度统计
%% 					%% 玩家卸下坐骑
%% 					{ok, MountPlayerStatus}=lib_goods:force_off_mount(NewStatus),
					misc:cancel_timer(spring_timer),
					%%开启温泉经验定时器 
					SpringTimeer = erlang:send_after(?SPRING_TIMER, self(), {'SPRING_ADD_EXP_SPRI'}), 
					put(spring_timer, SpringTimeer),%%进程字典
					%%做玩家在温泉的位置标注，0：温泉场景外面，1：温泉里但不在泉水里，2：VIPTOP泉水里，3：VIPNORMAL泉水里，4：PUBLIC泉水里
					lib_spring:mark_hotspring_site(?HOTSPRING_WATER_OUTSIDE),
					%%通知温泉，玩家进入
					gen_server:cast(NewStatus#player.other#player_other.pid_scene, 
									{'PLAYER_ENTER_SPRING',
									 {NewStatus#player.other#player_other.pid_send,
									  NewStatus#player.id,
									  NewStatus#player.nickname, 
									  NewStatus#player.vip},
									  NewStatus#player.scene}),
					{ok, change_ets_table, NewStatus};
				_ ->
					ok
			end;
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 12057 离开温泉
%% -----------------------------------------------------------------
handle(12057, Status, []) ->
	mod_spring:leave_spring(Status#player.id, Status#player.scene,
							Status#player.other#player_other.pid_scene,
							Status#player.other#player_other.pid),
	ok;


%% 试炼副本立即刷怪
handle(12060, Status, _)->
	case is_pid(Status#player.other#player_other.pid_dungeon) of
		true ->
			Status#player.other#player_other.pid_dungeon ! rush ;
		false ->
			skip
	end;

%% 轻功技能传送
handle(12062,Status,[X, Y]) ->
	[Res, NewStatus] = lib_deliver:light_deliver(Status, X, Y),
	%%进入场景广播给其他玩家 
	if 
		Res =/= 1 ->
		   {ok, BinData} = pt_12:write(12062, [Status#player.id,Res, Status#player.x, Status#player.y]),
		   lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
	    true ->
		   lib_scene:change_player_position(Status, X, Y),
		   {ok, BinData} = pt_12:write(12062, [Status#player.id, Res,X, Y]),
		   %%采用广播通知，附近玩家都能看到
		   mod_scene_agent:send_to_area_scene(Status#player.scene,X, Y, BinData),
		   {ok, NewStatus}
	end;

%% -----------------------------------------------------------------
%% 12063 采集莲花
%% -----------------------------------------------------------------
handle(12063, Status, [X,Y]) ->
	case lib_lotus:check_spring_time() of%%添加时间的判断
		false ->%%过期了
			{ok, BinData12063} = pt_12:write(12063, [4]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData12063),
			ok;
		true ->
			case Status#player.carry_mark =:= 19 of
				true ->%%已经是 采集状态
					{ok, BinData12063} = pt_12:write(12063, [5]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData12063),
					ok;
				false ->
					#player{x = PX,
							y = PY,
							scene = SceneId} = Status,
					case catch(gen_server:call(Status#player.other#player_other.pid_scene, {'COLLECT_LOTUS', Status#player.id, {X, Y}, {PX, PY, SceneId}})) of
						{fail, Error} ->
							{ok, BinData12063} = pt_12:write(12063, [Error]),
							lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData12063),
							ok;
						{ok, Result} ->
							%%返回正确结果
							{ok, BinData12063} = pt_12:write(12063, [Result]),
							lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData12063),
							NewStatus = Status#player{carry_mark = ?COLLECT_LOTUS_STATE}, 
							%通知场景附近所有玩家
							{ok,BinData12041} = pt_12:write(12041, [NewStatus#player.id, NewStatus#player.carry_mark]),
							mod_scene_agent:send_to_area_scene(NewStatus#player.scene,NewStatus#player.x, NewStatus#player.y, BinData12041),
							{ok, NewStatus};
						_OtherError ->
							{ok, BinData12063} = pt_12:write(12063, [0]),
							lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData12063),
							ok
					end
			end
	end;

%% -----------------------------------------------------------------
%% 12072 进入婚宴
%% -----------------------------------------------------------------
handle(12072, Status, _) ->
	IsWeddingScene= lib_marry:is_wedding_scene(Status#player.scene),
%% 	?DEBUG("ENTER pp_MARRY",[]),
	case IsWeddingScene =:= false of
		true ->	
			{Result, Wtype, NewStatus} = lib_marry:enter_wedding(Status),
			{ok, BinData} = pt_12:write(12072, [Result]),
			lib_send:send_to_sid(NewStatus#player.other#player_other.pid_send, BinData),
			case Result of
				1 ->
					%% 玩家卸下坐骑
					{ok, Mplayer}=lib_goods:force_off_mount(NewStatus),
					misc:cancel_timer(wedding_timer),
					%%开启经验定时器 
					WeddingTimeer = erlang:send_after(?WEDDING_TIMER, self(), {'WEDDING_ADD',Wtype}), 
					put(wedding_timer, WeddingTimeer),%%进程字典	
					%%删除一切变身buff(包括数据库记录)
					 F = fun({BuffGid, Value, _ExpireTime}) ->
									    {OldMid,_B} = Value,
									   if BuffGid =:= 31216 ->
											  {_MonId,{Fields,Value2,_BuffId}} = data_agent:get_chr_turned_buff_id(OldMid,Mplayer#player.career,Mplayer#player.sex);
										  true ->
											  {_MonId,{Fields,Value2,_BuffId}} = data_agent:get_turned_buff_id(OldMid)
									   end,
									   ValueList = lib_goods_use:get_turned_values(Mplayer,Fields,-Value2),
									   NewPlayer = lib_player_rw:set_player_info_fields(Mplayer, ValueList),
									   NewPlayer2 = NewPlayer#player{other = NewPlayer#player.other#player_other{turned = 0,
																												 goods_buff = NewPlayer#player.other#player_other.goods_buff#goods_cur_buff{turned_mult = []}}},
									   %%发送玩家属性变更通知到客户端,这就是 13001！！！！！！！！！！！！！
									   lib_player:send_player_attribute(NewPlayer2,2),
									   %%通知场景，模型改变
									   {ok,Data12066} = pt_12:write(12066,[NewPlayer2#player.id,NewPlayer2#player.other#player_other.turned]),
									   mod_scene_agent:send_to_area_scene(NewPlayer2#player.scene,NewPlayer2#player.x, NewPlayer2#player.y, Data12066),
									   %%通知客户端把旧的buff图标去除
										if BuffGid =:= 28045 ->
											   OldBuffGid = lib_goods:get_buff_goodstypeid(BuffGid, Value) + 100;
										   true ->
											   OldBuffGid = lib_goods:get_buff_goodstypeid(BuffGid, Value)
										end,
										{ok, BinData13014} = pt_13:write(13014, [[OldBuffGid,0,1]]),
										lib_send:send_to_sid(NewPlayer2#player.other#player_other.pid_send, BinData13014),
										db_agent:del_goods_buff(NewPlayer2#player.id,BuffGid),
										skip
				
						 end,
					GoodsBuffs = get(goods_buffs),
					Wpid = mod_wedding:get_mod_wedding_pid(),
					NewBuffs = 
						if Mplayer#player.other#player_other.goods_buff#goods_cur_buff.chr_fash > 0 
							 orelse	Mplayer#player.other#player_other.goods_buff#goods_cur_buff.turned_mult =/= []
							 ->
							   case gen_server:call(Wpid, {'IS_COUPLE',Status}) of
								   {true,_,_} ->
									   Buffs = [F({BuffGid, Value, ExpireTime}) || {BuffGid, Value, ExpireTime} <- GoodsBuffs,BuffGid =:= 31216 orelse BuffGid =:= 28043 orelse BuffGid =:= 28045],
									   lists:filter(fun(B) -> B=/=skip end, Buffs);
								   {false,_,_} ->
									   GoodsBuffs
							   end;
						   true ->
							   GoodsBuffs
						end,
					put(goods_buffs,lists:filter(fun(E)-> E=/=skip end, NewBuffs)),
					%%通知婚宴，玩家进入
					gen_server:cast(mod_wedding:get_mod_wedding_pid(),{'ENTER_WEDDING',Mplayer}),
%% 					?DEBUG("CUR_BUFF turned = ~p, fsh = ~p",[Mplayer#player.other#player_other.goods_buff#goods_cur_buff.turned_mult,
%% 											Mplayer#player.other#player_other.goods_buff#goods_cur_buff.chr_fash]),
					{ok, change_ets_table, Mplayer};
				_ ->
					ok
			end;
		false ->
			ok
	end;

handle(12074, Status, []) ->
	gen_server:cast(Status#player.other#player_other.pid,{'LEAVE_WEDDING'});
							
handle(_Cmd, _Status, _Data) ->
%%     ?DEBUG("pp_scene no match", []),
    {error, "pp_scene no match"}.


check_flag_place(X,Y,Color)->
	case Color of
		11->
			{[Xd,Yd],[Xu,Yu]} = {[14,83],[19,88]},
			if X >= Xd andalso X =< Xu andalso Y >= Yd andalso Y =< Yu ->true;
			   true->false
			end;
		_->
			{[Xd,Yd],[Xu,Yu]} = {[51,26],[56,31]},
			if X >= Xd andalso X =< Xu andalso Y >= Yd andalso Y =< Yu ->true;
			   true->false
			end
	end.
