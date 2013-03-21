%%%-----------------------------------
%%% @Module  : lib_scene
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 场景信息
%%%-----------------------------------
-module(lib_scene).
-export(
	[
        init_base_scene/0,
        load_scene/1,
        init_base_dungeon/0,
		get_scene_user_info/1,
		get_scene_user_node_info/1,
        get_scene_user/1,
        get_scene_user_node/1,
        get_area_user_for_battle/4,
        get_area_mon_for_battle/6,
        get_user_mon_for_mon_hp/5,			
        get_scene_mon/1,
        get_scene_mon_td/2,
        get_scene_mon_td_by_mid/2,
        init_player_scene/1,
        get_scene_info/4,
        leave_scene/4,
        enter_scene/1,
        mon_move/5,
        get_scene_npc/1,
        check_enter/2,
		check_enter_std/4,
        is_blocked/2,
        refresh_npc_ico/1,
        get_battle_der/2,
        get_scene_elem/1,
        get_xy/2,
        get_broadcast_user/3,
        move_broadcast_node/11,
        revive_to_scene/3,
        revive_to_scene_node/10,
        create_unique_scene_id/2,
        get_scene_id_from_scene_unique_id/1,
        get_res_id/1,
        get_res_id_for_run/1,
        is_dungeon_scene/1,
        is_fst_scene/1,
        is_td_scene/1,
        is_std_scene/1,
        is_mtd_scene/1,
        is_zxt_scene/1,
        is_training_scene/1,
        is_fst_zxt_scene/1,
        get_scene_team_info/4,
        is_copy_scene/1,
        copy_scene/2,
        clear_scene/1,
        change_player_position/3,
        ver_location/3,
        check_fst_thru/2,
        check_zxt_thru/2,
        load_npc/2,
        load_mon/2,
        load_mon_td/2,
        load_def_td/2,
        load_mon_training/2,
		load_mon_era/2,
		loading_warfare_mon/5,
		load_christmas_mon/3,
		load_robot_mon/3,
        load_mon_retpid/3,
        check_requirement/2,
        is_in_area/3,
        get_player_in_screen_bless/2,  %% add by zkj
        update_player_position/4,
        update_player_info_fields/2,
		update_player_info_fields_for_battle/3,
        enter_hooking_scene/2,
        set_hooking_state/2,
		get_double_rest_user/4,
		leave_scene1/4,
		get_scene_player_id/1,
		get_scene_npc_list/2,
		get_area_mon_for_battlle_loop/6,
		revive_to_scene_agent/3,
		get_dungeon_base_times/1
	]
).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("hot_spring.hrl").
-include("guild_info.hrl").

-define(MOVE_SOCKET, 2).
-define(DUNGEON_MAXTIMES, 15).										%% 进入副本的最大次数
-define(TD_MAXTIMES, 1). 											%% 进入镇妖台次数

%% 获取场景用户信息
get_scene_user_info(PlayerId) ->
	MS = ets:fun2ms(fun(T) when T#player.id == PlayerId  andalso T#player.hp > 0 ->
		T
	end),
	case ets:select(?ETS_ONLINE_SCENE,MS) of
		[P|_] ->
			P;
		_ ->
			[]
	end.

get_scene_user_node_info(PlayerId) ->
	MS = ets:fun2ms(fun(T) when T#player.id == PlayerId  andalso T#player.hp > 0 ->
		T
	end),
	case ets:select(?ETS_ONLINE,MS) of
		[P|_] ->
			P;
		_ ->
			[]
	end.
	
%% 获得当前场景用户信息 
get_scene_user(SceneId) ->
	get_scene_user_from_ets(SceneId, ?ETS_ONLINE_SCENE).

%% 获得当前场景用户信息 (本节点)
get_scene_user_node(SceneId) ->
	get_scene_user_from_ets(SceneId, ?ETS_ONLINE).

%%进入跨服战场获取当前玩家信息
get_war_scene_user(SceneId) ->
	get_war_scene_user_from_ets(SceneId, ?ETS_ONLINE_SCENE).

%%从ets获得用户信息 
get_scene_user_from_ets(SceneId, EtsTab) ->			
	%% arena 3为 竞技场死亡状态
   	MS = ets:fun2ms(fun(T) when T#player.scene == SceneId andalso T#player.arena /= 3 ->				
		[
            T#player.id,
            T#player.nickname,
            T#player.x,
            T#player.y,
            T#player.hp,
            T#player.hp_lim,
            T#player.mp,
            T#player.mp_lim,
            T#player.lv,
            T#player.career,
            T#player.speed,
            T#player.other#player_other.equip_current,
            T#player.sex,
			T#player.other#player_other.out_pet,
            T#player.other#player_other.pid,
            T#player.other#player_other.leader,
            T#player.other#player_other.pid_team,
            T#player.realm,
            T#player.guild_name,
			T#player.guild_position,
            T#player.evil,
            T#player.status,
			T#player.carry_mark,
			T#player.task_convoy_npc,
			T#player.other#player_other.stren,
			T#player.other#player_other.suitid,
			T#player.vip,
			T#player.other#player_other.mount_stren,
			T#player.other#player_other.peach_revel,
			T#player.other#player_other.titles,
			T#player.other#player_other.is_spring,
			T#player.other#player_other.turned,
			T#player.other#player_other.accept,
			T#player.other#player_other.deputy_prof_lv,
			T#player.couple_name,
			T#player.other#player_other.suitid,
			T#player.other#player_other.fullstren,
			T#player.other#player_other.fbyfstren,
			T#player.other#player_other.spyfstren,
			T#player.other#player_other.pet_batt_skill
		]
	end),
   	ets:select(EtsTab, MS).	

%%从ets获得用户信息 
get_war_scene_user_from_ets(SceneId, EtsTab) ->			
	%% arena 3为 竞技场死亡状态，carry_mark 28为观战模式，玩家不可见
   	MS = ets:fun2ms(fun(T) when T#player.scene == SceneId andalso T#player.arena /= 3 andalso  T#player.carry_mark /=29 ->				
		[
            T#player.id,
            T#player.nickname,
            T#player.x,
            T#player.y,
            T#player.hp,
            T#player.hp_lim,
            T#player.mp,
            T#player.mp_lim,
            T#player.lv,
            T#player.career,
            T#player.speed,
            T#player.other#player_other.equip_current,
            T#player.sex,
			T#player.other#player_other.out_pet,
            T#player.other#player_other.pid,
            T#player.other#player_other.leader,
            T#player.other#player_other.pid_team,
            T#player.realm,
            T#player.guild_name,
			T#player.guild_position,
            T#player.evil,
            T#player.status,
			T#player.carry_mark,
			T#player.task_convoy_npc,
			T#player.other#player_other.stren,
			T#player.other#player_other.suitid,
			T#player.vip,
			T#player.other#player_other.mount_stren,
			T#player.other#player_other.peach_revel,
			T#player.other#player_other.titles,
			T#player.other#player_other.is_spring,
			T#player.other#player_other.turned,
			T#player.other#player_other.accept,
			T#player.other#player_other.deputy_prof_lv,
			T#player.couple_name,
			T#player.other#player_other.suitid,
			T#player.other#player_other.fullstren,
			T#player.other#player_other.fbyfstren,
			T#player.other#player_other.spyfstren,
			T#player.other#player_other.pet_batt_skill
		]
	end),
   	ets:select(EtsTab, MS).	

%% 获得当前场景怪物信息
get_scene_mon(SceneId) ->
	MS = ets:fun2ms(fun(M) when M#ets_mon.scene == SceneId, M#ets_mon.hp > 0 -> 
	    [
            M#ets_mon.id,			             
            M#ets_mon.name,
            M#ets_mon.x,
            M#ets_mon.y,
            M#ets_mon.hp,
            M#ets_mon.hp_lim,
            M#ets_mon.mp,
            M#ets_mon.mp_lim,
			M#ets_mon.lv,            
            M#ets_mon.mid,
            M#ets_mon.icon,			
			M#ets_mon.type,
			M#ets_mon.att_area
	    ]
	end),
	ets:select(?ETS_SCENE_MON, MS).

%% 获得当前场景怪物信息，塔防专用
get_scene_mon_td(SceneId, Type) ->
	MS = ets:fun2ms(fun(M) when M#ets_mon.scene == SceneId, M#ets_mon.hp > 0, M#ets_mon.type == Type -> 
	    [
            M#ets_mon.id,			             
            M#ets_mon.pid,
            M#ets_mon.mid
	    ]
	end),
	ets:select(?ETS_SCENE_MON, MS).

%% 获得当前场景怪物信息，塔防专用
get_scene_mon_td_by_mid(SceneId, MonId) ->
	MS = ets:fun2ms(fun(M) when M#ets_mon.scene == SceneId, M#ets_mon.hp > 0, M#ets_mon.mid == MonId -> 
	    [
            M#ets_mon.id,			             
            M#ets_mon.pid
	    ]
	end),
	ets:select(?ETS_SCENE_MON, MS).

get_area_scene_mon(SceneId, X, Y) ->
	Area = 50,
	X1 = X + Area,
	X2 = X - Area,
	Y1 = Y + Area,
	Y2 = Y - Area,
	MS = ets:fun2ms(fun(M) when M#ets_mon.scene == SceneId andalso M#ets_mon.hp > 0 andalso 
								M#ets_mon.x >= X2 andalso M#ets_mon.x =< X1 andalso 
								M#ets_mon.y >= Y2 andalso M#ets_mon.y =< Y1 -> 
	    [
            M#ets_mon.id,			             
            M#ets_mon.name,
            M#ets_mon.x,
            M#ets_mon.y,
            M#ets_mon.hp,
            M#ets_mon.hp_lim,
            M#ets_mon.mp,
            M#ets_mon.mp_lim,
			M#ets_mon.lv,            
            M#ets_mon.mid,
            M#ets_mon.icon,			
			M#ets_mon.type,
			M#ets_mon.att_area
	    ]
	end),
	ets:select(?ETS_SCENE_MON, MS).

%% 获取指定场景的npc列表
get_scene_npc(SceneId) ->
	%%可过滤隐藏npc
	MS = ets:fun2ms(fun(N) when N#ets_npc.scene == SceneId 
						 		andalso N#ets_npc.nid /= 0 andalso N#ets_npc.nid /= 21044->
							[
							 N#ets_npc.id,
							 N#ets_npc.nid,
							 N#ets_npc.name,
							 N#ets_npc.x,
							 N#ets_npc.y,
							 N#ets_npc.icon,
							 N#ets_npc.npctype
							] end),	
%% 	MS= #ets_npc{
%%    		id = '$1',
%%        	nid = '$2',
%%       	name = '$3',
%%       	x = '$4',
%%       	y = '$5',
%%        	icon = '$6',
%% 		npctype = '$7',
%%       	scene = SceneId,
%%        	_ = '_'
%%    	},
%% 	NPC1 = ets:match(?ETS_SCENE_NPC, MS),
	ets:select(?ETS_SCENE_NPC, MS).

	

%% 初始化用户场景
init_player_scene(Player) ->
	SceneId = get_scene_id_from_scene_unique_id(Player#player.scene),
	case data_scene:get(SceneId) of
		[]  ->
			Player;
		Scene ->
			case Scene#ets_scene.type of
				%% 普通副本
				2 ->
					if
						SceneId =/= ?DUNGEON_SINGLE_SCENE_ID ->
							Player;
						true ->
							%% 单人副本未完成重新进入
							{_Ret, NewPlayerStatus} = mod_single_dungeon:enter_single_dungeon_scene(Player),
							NewPlayerStatus
					end;
				%% 氏族领地
				5 ->
					case Player#player.guild_id of
						0 ->
							{SceneId, X, Y} = data_guild:get_manor_send_out(Player#player.scene),
							Player#player{
										  scene = SceneId, 
										  x = X, 
										  y = Y
										 };
						_ ->
							{ok, ScenePid} = mod_guild_manor:get_guild_manor_pid(500, Player#player.guild_id, Player#player.id, self()),
							UniqueSceneId = lib_guild_manor:get_unique_manor_id(Player#player.scene, Player#player.guild_id),
							Player#player{
								scene = UniqueSceneId,
								other = Player#player.other#player_other{
									pid_scene = ScenePid
								}
							}
					end;
				%% 封神台
				7 ->
					lib_scene_fst:init_player_scene(Player);					
				8 ->
				   case Scene#ets_scene.sid of
						700 ->%%旧秘境
							UniqueSceneId = lib_box_scene:get_box_scene_unique_id(?BOX_SCENE_ID),
							{ok, ScenePid} = mod_box_scene:enter_box_scene(UniqueSceneId, Player),
							Player#player{
								scene = UniqueSceneId,
								other = Player#player.other#player_other{
									pid_scene = ScenePid
								}
							};
						720 ->%%新秘境
							UniqueSceneId = lib_box_scene:get_box_scene_unique_id(?BOXS_PIECE_ID),
							[X, Y] = lib_boxs_piece:get_boxs_piece_xy(),
							{ok, ScenePid} = mod_boxs_piece:start_boxs_piece_pro(Player, UniqueSceneId, X, Y, 0),
							Player#player{
								scene = UniqueSceneId,
								other = Player#player.other#player_other{
									pid_scene = ScenePid
								}
							};
						_ ->
							Player
					end;
				%% 挂机场景
				10 ->
					case lib_hook:is_open_hooking_scene() of
						opening->Player;
						_->
							Player#player{scene=300,x=66,y=166}
					end;
				%% 攻城战
				12 ->
					[OutSceneId, OutX, OutY] = lib_castle_rush:get_castle_rush_outside(),
					Player#player{
						scene = OutSceneId,
						x = OutX, 
						y = OutY
					};
				%% 神魔乱斗，传到复活点
				13 ->
					{NewSceneId, X, Y} = ?WARFARE_OUT_SCENE,
					Player#player{scene = NewSceneId,
								  x = X, y = Y};
				%% 婚宴
				15 ->
					[Out_coord,Coord_length] = lib_marry:get_wedding_send_out(),
					{SpriSid, XYCoord} = Out_coord,
					RandNum = util:rand(1, Coord_length),
					%% 随机产生一对坐标
					{SpriX, SpriY} = lists:nth(RandNum, XYCoord),								
				  	Player#player{
						scene = SpriSid,
						x = SpriX,
						y = SpriY,
						carry_mark = 0,
						other = Player#player.other#player_other{
							turned = 0
						}
					};
				%% 试炼副本玩家重新加入
				20 ->
					mod_training:join(Player#player.other#player_other.pid_dungeon, 
							[Player#player.id, Player#player.other#player_other.pid, Player#player.lv]),
					Player;
				%% 诛仙台
				21 ->
					lib_scene_fst:init_player_scene(Player);
				%% 温泉
				22 ->
					{SpriSid, XYCoord} = ?SPRING_OUT_COORD,
				  	RandNum = util:rand(1, ?COORD_LENGTH),
				  	{SpriX, SpriY} = lists:nth(RandNum, XYCoord), %%随机产生一对坐标
				  	Player#player{
						scene = SpriSid,
						x = SpriX,
						y = SpriY,
						carry_mark = 0,
						other = Player#player.other#player_other{
							is_spring = 0
						}
								 };
				_ ->
						mod_scene:get_scene_pid(Player#player.scene, undefined, undefined),
						Player
			end
	end.

%% 获取场景基本信息
get_scene_info(SceneId, X, Y, PidSend) ->
	%% 当前场景玩家信息
	SceneUser = get_broadcast_user_by_enter(SceneId, X, Y),
	%% 当前怪物信息
	SceneMon = 
		case is_copy_scene(SceneId) of
			%% 副本是获取全屏怪
			true ->
				get_scene_mon(SceneId);
			false when SceneId =:= ?WARFARE_SCENE_ID ->%%神魔乱斗的怪物
				get_scene_mon(SceneId);
			false ->
				get_broadcast_mon(SceneId, X, Y)
		end,
    %% 当前元素信息
    SceneElem = get_scene_elem(SceneId),
    %% 当前npc信息
    SceneNpc = get_scene_npc(SceneId),
	SceneSpar = [],
	{ok, BinData} = pt_12:write(12002, {SceneUser, SceneMon, SceneElem, SceneNpc, SceneSpar}),
  	lib_send:send_to_sid(PidSend, BinData),
	ok.
	
%% 离开当前场景
leave_scene(PlayerId, SceneId, X, Y) ->
    {ok, BinData} = pt_12:write(12004, PlayerId),
	mod_scene_agent:send_to_area_scene(SceneId, X, Y, BinData),
	catch ets:delete(?ETS_ONLINE_SCENE, PlayerId).

%% 离开当前场景
leave_scene1(PlayerId, SceneId, X, Y) ->
    {ok, BinData} = pt_12:write(12004, PlayerId),
	mod_scene_agent:send_to_area_scene(SceneId, X, Y, BinData).

%%进入当前场景
enter_scene(Player) ->
    %% 通知所有玩家，战场死亡状态不通告 (carry_mark 29 为观战模式，玩家不可见)
	if
		Player#player.arena == 3  orelse  Player#player.carry_mark ==29->
    		skip;
		true ->
			{ok, BinData} = pt_12:write(12003, pt_12:trans_to_12003(Player)),
    		mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, BinData)
	end,
	ets:insert(?ETS_ONLINE_SCENE, Player).

%%怪物移动
mon_move(X, Y, MonId, SceneId, Speed) ->
    {ok, BinData} = pt_12:write(12008, [X, Y, Speed, MonId]),
	case is_copy_scene(SceneId) of
		true ->
			lib_send:send_to_online_scene(SceneId, BinData);
		false when SceneId =:= ?WARFARE_SCENE_ID ->%%神魔乱斗的怪物,场景广播
			lib_send:send_to_online_scene(SceneId, BinData);
		false ->
			lib_send:send_to_online_scene(SceneId, X, Y, BinData)
	end.

%% 进入场景条件检查
check_enter(Status0, _Scene_Id) when Status0#player.status == 10 ->
	{false, 0, 0, 0, <<"双修状态不能进入此场景!">>, 0, []};
check_enter(Status0, Scene_Id) ->
	case lib_spring:is_spring_scene(Status0#player.scene) of
		true ->%%温泉的特殊处理
			Status = Status0#player{other = Status0#player.other#player_other{is_spring = 0}};
		false ->
			Status = Status0
	end,
	%% 进入雷泽根据在线数分流 
	case Scene_Id of
		%%目标场景101 且 不是从分线切换过去
		101 when Status#player.scene /= 190 andalso Status#player.scene /=191 ->
			AutoBranching = config:get_auto_branching(),
			if
				AutoBranching == 1 ->
					Pattern = #player{scene = 101 ,_='_'},		
					OnlineNum = length(ets:match_object(?ETS_ONLINE_SCENE, Pattern)),
					if
						OnlineNum > 200 ->
							SceneId = 190;
						true ->
							SceneId = Scene_Id
					end;
				AutoBranching == 2 ->
					case util:rand_test(50) of
						true -> SceneId = 190;
						false -> SceneId = 191
					end;
				AutoBranching == 3 ->
					R = util:rand(1, 1000),
					if
						R > 666 -> SceneId = Scene_Id;
						R > 333 -> SceneId = 190;
						true -> SceneId = 191
					end;
				true ->
					SceneId = Scene_Id
			end;
		_ -> 
			SceneId = Scene_Id
	end,
	case data_scene:get(SceneId) of
        [] ->
            {false, 0, 0, 0, <<"场景不存在!">>, 0, []};
        Scene ->
            case check_requirement(Status, Scene#ets_scene.requirement) of
                {false, Reason} -> 
					{false, 0, 0, 0, Reason, 0, []};
                {true} ->
                    case Scene#ets_scene.type of
                        0 -> %% 普通场景
                            enter_normal_scene(SceneId, Scene, Status);
                        1 -> %% 普通场景
                            enter_normal_scene(SceneId, Scene, Status);
						2 -> %% 副本场景
							check_enter_dungeon(Status, SceneId, Scene);
						5 ->%%氏族领地
							lib_guild_manor:manor_check_and_enter(SceneId, Scene, Status);
						7 ->%%封神台
							lib_scene_fst:check_enter_fst(Status, SceneId, Scene);
						8 ->%% 诛邪副本的第一层
							enter_normal_scene(SceneId, Scene, Status);
						10 -> %% 挂机场景
                            enter_hook_scene(SceneId,Scene,Status);
						11 ->	%% 幻魔穴
							lib_cave:check_enter_cave(Status, SceneId, Scene);
						18 ->%% 单人塔防
							check_enter_std(Status, SceneId, Scene ,0);
						19 ->%% 多人塔防
							check_enter_mtd(Status, SceneId, Scene);
						20 ->%% 试炼副本
							check_enter_training(Status, SceneId, Scene);
							%%check_enter_era(Status,SceneId, Scene);
						21 ->%%诛仙台
							lib_scene_fst:check_enter_fst(Status, SceneId, Scene);
						13 ->%%神魔乱斗
							enter_warfare_scene(SceneId, Scene, Status);
						15 ->
							%%洞房或婚宴场景
							enter_wedding_love_scene(SceneId, Scene, Status);
						16 ->
							%%封神纪元
							check_enter_era(Status,SceneId, Scene);
						17 ->
							%%夫妻副本
							check_enter_coulpe_scene(Status,SceneId,Scene);
						_->
							{false, 0, 0, 0, <<"场景出错_那边没有返回本场景出口!">>, 0, []}
					end
			end
    end.

%% 逐个检查进入需求
check_requirement(_, []) ->  {true};
check_requirement(Status, [{K, V} | T]) ->
    case K of
        %% 等级需求
		lv -> 
            case Status#player.lv < V of
                true ->
					Msg = io_lib:format("等级不足~p级，无法进入该场景",[V]),
                    {false, list_to_binary(Msg)};
                false ->
                    check_requirement(Status, T)
            end;
        _ ->
            check_requirement(Status, T)
    end.

%%获取副本基础次数
%% 911 -> 25;
%% 		920 -> 35;
%% 		930 -> 45;
%% 		940 -> 55;
%% 		950 -> 65;
%% 		961 -> 70;
%% 		998 -> 33;
%% 		999 -> 40;
%% 		1001 -> 35;
%% 		1046 -> 55;
%% 		901 -> 33;
get_dungeon_base_times(SceneId)->
	case SceneId of
		911 -> 15;
		920 -> 15;
		930 -> 5;
		940 -> 5;
		950 -> 5;
		961 ->3;
		998 -> 1;
		999 -> 1;
		1001 -> 3;
		1046 -> 3;
		901 -> 1;
		_->0
	end.

%% 进入副本场景条件检查
check_enter_dungeon(Status, SceneId, Scene) ->
	case lib_dungeon:check_enter_dungeon_requirement(Status) of
		true ->
			{_NewPlayerStatus, _Auto, AwardTimes} = lib_vip:get_vip_award(dungeon, Status),
			Dungeon_maxtimes = get_dungeon_base_times(SceneId) + AwardTimes,
			{Enter, Counter} = lib_dungeon:check_dungeon_times(Status#player.id, Scene#ets_scene.sid, Dungeon_maxtimes),
			if
				Enter == fail ->
					Warning = io_lib:format("每天进入副本不能超过~p次!",[Dungeon_maxtimes]),
					{false, 0, 0, 0, tool:to_binary(Warning), 0, []};
				true ->
                    NewCounter = Counter + 1,
                    case misc:is_process_alive(Status#player.other#player_other.pid_dungeon) 
                                andalso SceneId =:= get_scene_id_from_scene_unique_id(Status#player.scene) of
                        %% 已经有副本服务进程
                        true ->
                            enter_dungeon_scene(Scene, Status ,NewCounter ,Dungeon_maxtimes);
                        %% 还没有副本服务进程
                        false ->
                            Result = 
                                case misc:is_process_alive(Status#player.other#player_other.pid_team) of
                                    %% 没有队伍，角色进程创建副本服务器
                                    false ->
										gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'del_member',[Status#player.id]}),
                                        mod_dungeon:start(0, self(), SceneId, [{Status#player.id, 
                                                        Status#player.other#player_other.pid, Status#player.other#player_other.pid_dungeon}]);
                                    %% 有队伍且是队长，由队伍进程创建副本服务器
                                    true ->
                                        mod_team:create_dungeon(Status#player.other#player_other.pid_team, self(), 
                                                            SceneId, [SceneId, Status#player.id, 
                                                            Status#player.other#player_other.pid,
                                                            Status#player.other#player_other.pid_dungeon])
                                end,
                            case Result of 
                                {ok, Pid} ->
                                    enter_dungeon_scene(Scene, Status#player{other=Status#player.other#player_other{pid_dungeon = Pid}},NewCounter,Dungeon_maxtimes);										
                                {fail, Msg} ->
                                    {false, 0, 0, 0, Msg, 0, []}
                            end
                    end
			end;
		FaultMsg ->
			FaultMsg
	end.

%% 进入普通场景(从新手村出去的话，不做返回点检查)
enter_normal_scene(SceneId, Scene, Status) when Status#player.scene =:= ?NEW_PLAYER_SCENE_ID 
															  orelse Status#player.scene =:= ?NEW_PLAYER_SCENE_ID_TWO
																				   orelse Status#player.scene =:= ?NEW_PLAYER_SCENE_ID_THREE->	
	{true, SceneId, Scene#ets_scene.x, Scene#ets_scene.y, Scene#ets_scene.name, Scene#ets_scene.sid, 0, 0, Status};

enter_normal_scene(SceneId, Scene, Status) when SceneId =:= ?NEW_PLAYER_SCENE_ID 
												orelse SceneId =:= ?NEW_PLAYER_SCENE_ID_TWO
												orelse SceneId =:= ?NEW_PLAYER_SCENE_ID_THREE->
	case lists:member(Status#player.scene,[ ?NEW_PLAYER_SCENE_ID ,?NEW_PLAYER_SCENE_ID_TWO,?NEW_PLAYER_SCENE_ID_THREE]) of
		false->{false, 0, 0, 0, <<"场景出错_那边没有返回本场景出口!">>, 0, []};
		true->
			case data_scene:get(?NEW_PLAYER_SCENE_ID) of
				[]->
					{true, SceneId, Scene#ets_scene.x, Scene#ets_scene.y, Scene#ets_scene.name, Scene#ets_scene.sid, 0, 0, Status};
				ResScene->
					{true, SceneId, Scene#ets_scene.x, Scene#ets_scene.y, Scene#ets_scene.name, ResScene#ets_scene.sid, 0, 0, Status}
			end
	end;

enter_normal_scene(SceneId, Scene, Status) when SceneId =:= 120 orelse SceneId =:= 121 orelse SceneId =:= 122 orelse SceneId =:= 123 orelse SceneId =:= 124->
	case data_scene:get(120) of
		[]->
			{true, SceneId, Scene#ets_scene.x, Scene#ets_scene.y, Scene#ets_scene.name, Scene#ets_scene.sid, 0, 0, Status};
		ResScene->
			{true, SceneId, Scene#ets_scene.x, Scene#ets_scene.y, Scene#ets_scene.name, ResScene#ets_scene.sid, 0, 0, Status}
	end;

%%进出灵兽圣园，不做返回点检查
%% enter_normal_scene(SceneId, Scene, Status) when SceneId =:= 705 andalso Status#player.scene =:= 300 ->	
%% 	{true, SceneId, Scene#ets_scene.x, Scene#ets_scene.y, Scene#ets_scene.name, Scene#ets_scene.sid, 0, 0, Status};
%% 
%% enter_normal_scene(SceneId, Scene, Status) when  Status#player.scene =:= 705 andalso SceneId =:= 300 ->	
%% 	{true, SceneId, 60,22, Scene#ets_scene.name, Scene#ets_scene.sid, 0, 0, Status};

%%进入副本 场景，不用做返回点检查
enter_normal_scene(SceneId, Scene, Status) when SceneId =:= ?BOX_SCENE_ONE_ID ->		
	{true, SceneId, Scene#ets_scene.x, Scene#ets_scene.y, Scene#ets_scene.name, Scene#ets_scene.sid, 0, 0, Status};

%%进入雷泽的分线
enter_normal_scene(SceneId,Scene,Status) when SceneId == 101 orelse SceneId == 190 orelse SceneId == 191 ->
	%% 判断场景切换坐标位置
%% 	case check_change_scene(Status, SceneId) of
%% 		true ->
            case [{X, Y} || [_Index, Id, _Name, X, Y] <- Scene#ets_scene.elem, Id =:= Status#player.scene] of
                [] -> 
                %% 雷泽切线				
                    {true, SceneId, Status#player.x, Status#player.y , Scene#ets_scene.name, get_res_id(Scene#ets_scene.sid), 0, 0, Status};
                %% 其他场景进入雷泽分线
                [{X, Y}] ->
					case data_scene:get(101) of
                        [] ->
                            {true, SceneId, Scene#ets_scene.x, Scene#ets_scene.y , Scene#ets_scene.name, Scene#ets_scene.sid, 0, 0, Status};
                        ResScene->
                            {true, SceneId, X, Y, Scene#ets_scene.name, ResScene#ets_scene.sid, 0, 0, Status}
                    end
            end;
%% 		false ->
%% 			{false, 0, 0, 0, <<"场景出错_那边没有返回本场景出口!">>, 0, []}	
%% 	end;
%%走出雷泽的分线
enter_normal_scene(SceneId, Scene, Status) when Status#player.scene == 101 orelse  Status#player.scene == 190 orelse  Status#player.scene == 191 ->
	case [{X, Y} || [_Index, Id, _Name, X, Y] <- Scene#ets_scene.elem, Id =:= 101] of
		 [] -> 
%% 			 io:format("Here_0100_ /~p// ~n",[SceneId]),				
			{false, 0, 0, 0, <<"场景出错_那边没有返回本场景出口!">>, 0, []};
        [{X, Y}] -> 
%% 			%% 判断场景切换坐标位置
%% 			case check_change_scene(Status, SceneId) of
%% 				true ->
					{true, SceneId, X, Y, Scene#ets_scene.name, Scene#ets_scene.sid, 0, 0, Status}
%% 				false ->
%% 					{false, 0, 0, 0, <<"场景出错_那边没有返回本场景出口!">>, 0, []}
%% 			end
    end;
%%进入普通场景
enter_normal_scene(SceneId, Scene, Status) ->
    case [{X, Y} || [_Index, Id, _Name, X, Y] <- Scene#ets_scene.elem, Id =:= Status#player.scene] of
        [] -> 
			%% io:format("Here_0100_ /~p// ~n",[SceneId]),				
			{false, 0, 0, 0, <<"场景出错_那边没有返回本场景出口!">>, 0, []};
        [{X, Y}] ->
%% 			%% 判断场景切换坐标位置
%% 			case check_change_scene(Status, SceneId) of
%% 				true ->
					{true, SceneId, X, Y, Scene#ets_scene.name, Scene#ets_scene.sid, 0, 0, Status}
%% 				false ->
%% 					{false, 0, 0, 0, <<"场景出错_那边没有返回本场景出口!">>, 0, []}
%% 			end
    end.

%%进入挂机场景
enter_hook_scene(SceneId,Scene,Status)->
	case lib_hook:is_open_hooking_scene() of
		opening->
			enter_normal_scene(SceneId, Scene, Status);
		early->
			{false, 0, 0, 0, <<"挂机区将于17点30分至23点开放！敬请准时参加！">>, 0, []};
		late->
			{false, 0, 0, 0, <<"今天的挂机区已结束开放！请明日准时参加！">>, 0, []}
	end. 
%%进入神魔乱斗场景
enter_warfare_scene(SceneId,Scene,Status) ->
	case lib_dungeon:check_enter_dungeon_requirement(Status) of
		true ->
			{true, SceneId, Scene#ets_scene.x, Scene#ets_scene.y, Scene#ets_scene.name, Scene#ets_scene.sid, 0, 0, Status};
		FaultMsg ->
			FaultMsg
	end.
	
%% 进入副本场景
enter_dungeon_scene(Scene, Status,Counter,Dungeon_maxtimes) ->
    case mod_dungeon:check_enter(Scene#ets_scene.sid, Scene#ets_scene.type, Status#player.other#player_other.pid_dungeon) of
        {false, Msg} ->
            {false, 0, 0, 0, Msg, 0, []};
        {true, UniqueId} ->
            DungeonSceneId = get_scene_id_from_scene_unique_id(Status#player.scene),
			case data_scene:get(DungeonSceneId) of
           		[]  -> 
                     {false, 0, 0, 0, <<"场景出错_2!">>, 0, []};
                S ->
                     %% 进入副本场景卸下坐骑
                    {ok, NewStatus} = lib_goods:force_off_mount(Status),
					if
						Scene#ets_scene.sid =:= 911 ->
							put(sce_b4_dg, Status#player.scene);
						true ->
							ok
					end,
					%% 成功进入更新进入副本次数
					lib_dungeon:add_dungeon_times(Status#player.id, Scene#ets_scene.sid),
					%% 更新人物延时保存信息
					mod_delayer:update_delayer_info(NewStatus#player.id, NewStatus#player.other#player_other.pid_dungeon, NewStatus#player.other#player_other.pid_fst, NewStatus#player.other#player_other.pid_team),
					Msg = io_lib:format("您的队友~s进入了~s",[NewStatus#player.nickname, Scene#ets_scene.name]),
					{ok,TeamBinData} = pt_15:write(15055,[Msg]),
					gen_server:cast(NewStatus#player.other#player_other.pid_team,{'SEND_TO_OTHER_MEMBER', NewStatus#player.id, TeamBinData}),
                    [RetX, RetY] = 
						case [{X, Y} || [_Index, Id0, _Name, X, Y] <- Scene#ets_scene.elem, Id0 =:= S#ets_scene.sid] of
                       		[] -> 
                        		[Scene#ets_scene.x, Scene#ets_scene.y];
                         	[{X, Y}] -> 
                          		[X, Y]
						end,
					{true, UniqueId, RetX, RetY, Scene#ets_scene.name, Scene#ets_scene.sid, Counter, Dungeon_maxtimes, NewStatus}
             end

    end.

%%进入洞房或婚宴场景处理
enter_wedding_love_scene(SceneId,Scene,Status)->
	case lib_marry:check_marry_scene_enter(SceneId) of
		{false,Msg} ->
			{false, 0, 0, 0, Msg, 0, []};
		{true,enter} ->
			{true, SceneId, Scene#ets_scene.x, Scene#ets_scene.y, Scene#ets_scene.name, Scene#ets_scene.sid, 0, 0, Status}
	end.

%% 创建全局唯一的副本场景ID(包含 SceneId和SceneType信息) 
create_unique_scene_id(SceneId, AutoIncId) ->
	AutoIncId*10000 + SceneId.
 
%% 从全局唯一副本场景 ID获取SceneId
get_scene_id_from_scene_unique_id(UniqueId) ->
	UniqueId rem 10000.

%% 是为副本场景，唯一id
is_copy_scene(SceneUniqueId) ->
    SceneUniqueId > 9999 orelse SceneUniqueId =:= ?CASTLE_RUSH_SCENE_ID.

%% 用唯一id获取场景的资源id
get_res_id(UniqueId) -> 
    case is_copy_scene(UniqueId) of
        false -> 
			if
				UniqueId == 190 orelse UniqueId == 191 ->
					101;
				true ->
					UniqueId    %% 无需转换
			end;
        true ->
			%%封神台，诛仙台每三层共用一张地图
			case is_zxt_scene(UniqueId) of
				false->
					case is_fst_scene(UniqueId) of
						false->
							UniqueId rem 10000;
						true->
							(UniqueId rem 10000) -((UniqueId rem 10000 -1)rem 1000 rem 2)
					end;
				true->
					%%诛仙台最后一层用独立的地图
					if UniqueId rem 10000=:= 1065->
						   UniqueId rem 10000;
					   true->
							(UniqueId rem 10000) -(UniqueId rem 10000 rem 1000 rem 2)
					end
			end
    end.

%% 场景资源ID（走路专用）
get_res_id_for_run(SceneId) ->
	case SceneId > 9999 of
		false ->
			SceneId;
		true ->
			SceneId rem 10000
	end.

%% 是否为副本场景，UniqueId唯一id，会检查是否存在这个场景
is_dungeon_scene(SceneUniqueId) ->
    case is_copy_scene(SceneUniqueId) of
        false -> 
			false;
        true ->
			SceneResId = get_scene_id_from_scene_unique_id(SceneUniqueId),
			lists:member(SceneResId, data_scene:dungeon_type2_get_id_list())
    end.


%% 判断在场景SceneId的[X,Y]坐标是否有障碍物
is_blocked(SceneId, [X, Y]) ->
    case ets:lookup(?ETS_BASE_SCENE_POSES, {SceneId, X, Y}) of
   		%% 无障碍物
		[] -> 
			true;
		%% 有障碍物
       	[_] -> 
			false 
    end.

%% 刷新npc任务状态
refresh_npc_ico(PlayerId) when is_integer(PlayerId)->
    case lib_player:get_player_pid(PlayerId) of
        [] -> ok;
        Pid -> gen_server:cast(Pid, {cast, {?MODULE, refresh_npc_ico, []}})
    end;

%% 刷新npc任务状态
refresh_npc_ico(Pid) when is_pid(Pid)->
   gen_server:cast(Pid, {cast, {?MODULE, refresh_npc_ico, []}});

%% 刷新npc任务状态
refresh_npc_ico(Status) ->
    NpcList = mod_scene:get_scene_npc(Status#player.scene),
    L = [[Id, lib_task:get_npc_state(NpcId, Status)]|| [Id,NpcId | _] <- NpcList],
    {ok, BinData} = pt_12:write(12020, [L]),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).

%% 获取当前场景NPC列表
get_scene_npc_list(SceneId, SendPid) ->
	NpcList = get_scene_npc(SceneId),
	ElemList = get_scene_elem(SceneId),
	{ok, BinData} = pt_12:write(12023, [SceneId, NpcList, ElemList]),
    lib_send:send_to_sid(SendPid, BinData).


%% 获取战斗被击方信息
%% PlayerId 玩家ID
%% SceneId 场景ID
get_battle_der(PlayerId, SceneId) ->
	case ets:lookup(?ETS_ONLINE, PlayerId) of
   		[] ->
			case lib_player:get_user_info_by_id(PlayerId) of
				[] -> 					
					call_fail;
				Player ->
					case Player#player.scene == SceneId of
						true ->
							Player;
						false ->
							no_find
					end
			end;
   		[Player] ->
       		case is_process_alive(Player#player.other#player_other.pid) of
           		true ->
					case Player#player.scene == SceneId of
						true ->
							Player;
						false ->
							no_find
					end;
           		false ->               		
               		no_find
       		end
	end.

%%当前元素信息
get_scene_elem(SceneId) ->
	case ets:lookup(?ETS_SCENE, SceneId) of
   		[] -> [];
     	[Scene] ->
			if 
				Scene#ets_scene.type =/= 11 ->
					Scene#ets_scene.elem;
				true ->
					[]
			end
	end.

%%--------------------------九宫格加载场景---------------------------
%% 把整个地图共有100*100个格子，0，0坐标点为原点，以10*10为一个格子，从左到右编号1，2，3，4最终成为10*10的正方形
%获取当前所在的格子
get_xy(X, Y) ->
	Y div 15 * 10 + X div 10 + 1.

%%  获取场景内要广播的范围用户信息(玩家进去场景调用)
get_broadcast_user_by_enter(SceneId, X, Y) ->
	%% 是否是在竞技场
	case lib_coliseum:is_coliseum_scene(SceneId) of
		false ->
			case lib_war:is_war_scene(SceneId) of
				false->
					AllUser = get_scene_user(SceneId),
					XY = get_xy(X, Y),
					get_broadcast_user_loop(AllUser, XY, []);
				true->
					AllUser = get_war_scene_user(SceneId),
					XY = get_xy(X, Y),
					get_broadcast_user_loop(AllUser, XY, [])
			end;
		true ->
			get_scene_user(SceneId)
	end.

%%  获取场景内要广播的范围用户信息
get_broadcast_user(SceneId, X, Y) ->
	%% 是否是在竞技场
	case lib_coliseum:is_coliseum_scene(SceneId) of
		false ->
			AllUser = get_scene_user(SceneId),
			XY = get_xy(X, Y),
			get_broadcast_user_loop(AllUser, XY, []);
		true ->
			get_scene_user(SceneId)
	end.

%%  获取场景内要广播的范围用户信息(本节点)
get_broadcast_user_node(SceneId, X, Y) ->
    AllUser = get_scene_user_node(SceneId),
    XY = get_xy(X, Y),
    get_broadcast_user_loop(AllUser, XY, []).

get_broadcast_user_loop([], _XY2, D) -> D;
get_broadcast_user_loop([P | U], XY, D) ->
    [_Id, _Nick, X, Y | _] = P,
	case is_in_area(X, Y, XY) of
		true ->
			get_broadcast_user_loop(U, XY, [P | D]);
		false ->
			get_broadcast_user_loop(U, XY, D)
	end.

%%  获取场景内要广播的范围怪物信息(本节点)
get_broadcast_mon(SceneId, X, Y) ->
	AllMon = get_area_scene_mon(SceneId, X, Y),
    XY = get_xy(X, Y),
    get_broadcast_mon_loop(AllMon, XY, []).

get_broadcast_mon_loop([], _XY, D) -> D;
get_broadcast_mon_loop([M | T], XY, D) ->
    [_Id, _Name, X, Y, _Hp, _HpLim, _Mp, _MpLim, _Lv, _Mid, _Icon, _Type, _AttArea] = M,
	case is_in_area(X, Y, XY) of
		true ->
			get_broadcast_mon_loop(T, XY, [M | D]);
		false ->
			get_broadcast_mon_loop(T, XY, D)
	end.

%% 获取场景所有队长
%% SceneId 玩家所在的场景ID
get_scene_team_info(SceneId, X, Y, PidSend) ->
	Arena = 16,
	X1 = X - Arena,
	X2 = X + Arena,
	Y1 = Y - Arena,
	Y2 = Y + Arena,
	MS = ets:fun2ms(fun(P) when P#player.scene == SceneId 
						 andalso P#player.other#player_other.leader == 1 
						 andalso P#player.x > X1 andalso X2 > P#player.x
						 andalso P#player.y > Y1 andalso Y2 > P#player.y ->
		[
            P#player.id,
            P#player.nickname,
            P#player.lv,
            P#player.career,
			P#player.realm,           
            P#player.other#player_other.pid_team                        
		]
	end),
   	AllUser = ets:select(?ETS_ONLINE_SCENE, MS),
    get_scene_team_info_loop(AllUser, PidSend, []).

%% 遍历获取场景所有队长
%% AllUser 场景所有的玩家
%% Data 存放该场景队长数据的累加器
get_scene_team_info_loop([], PidSend, SceneTeamInfo) ->
	{ok, BinData} = pt_24:write(24018, SceneTeamInfo),
    lib_send:send_to_sid(PidSend, BinData);
get_scene_team_info_loop([[Id, Nick, Lv, Career, Realm, TeamPid] | T], PidSend, SceneTeamInfo) ->
 	case catch gen_server:call(TeamPid, 'GET_SCENE_TEAM_INFO') of
   		{'EXIT', _} ->
  			get_scene_team_info_loop(T, PidSend, SceneTeamInfo);
     	{Num, Auto} ->
  			get_scene_team_info_loop(T, PidSend, [[Id, Nick, Lv, Career, Realm, Num, Auto] | SceneTeamInfo])
 	end.                    

%% 获取范围内的玩家(怪物使用)
get_area_user_for_battle(SceneId, X, Y, GuardArea) ->	
    X1 = X + GuardArea,
    X2 = X - GuardArea,
    Y1 = Y + GuardArea,
    Y2 = Y - GuardArea,
	MS = ets:fun2ms(fun(P) when P#player.scene == SceneId andalso P#player.hp > 0 andalso
								P#player.x >= X2 andalso P#player.x =< X1 andalso 
								P#player.y >= Y2 andalso P#player.y =< Y1 ->
		[
			P#player.id, 
			P#player.other#player_other.pid, 
			P#player.x, 
			P#player.y			
		]
	end),
	AllUser = ets:select(?ETS_ONLINE_SCENE, MS),
    get_area_user_for_battlle_loop(AllUser, X, Y, 1000000, []).
%% 获取一个最近的玩家
get_area_user_for_battlle_loop([], _MX, _MY, _Len, Ret) -> 
	Ret;
get_area_user_for_battlle_loop([[Id, Pid, X, Y] | U], MX, MY, Len, Ret) ->
    Dist = abs(X - MX) + abs(Y - MY),    
    {NewLen, NewRet} =
        case Dist < Len of
            true -> 
				{Dist, [Id, Pid]};
            false -> 
				{Len, Ret}
        end,
    get_area_user_for_battlle_loop(U, MX, MY, NewLen, NewRet).

%% 获取范围内的怪物(怪物使用)
get_area_mon_for_battle(SceneId, X, Y, GuardArea, MonType, Type) ->	
    X1 = X + GuardArea,
    X2 = X - GuardArea,
    Y1 = Y + GuardArea,
    Y2 = Y - GuardArea,
	All = 
		case Type of
			1 ->
				get_att_mon_for_mon(SceneId, X1, X2, Y1, Y2, MonType);
			2 ->
				get_att_user_for_mon(SceneId, X1, X2, Y1, Y2);
			_ ->
				AllMon = get_att_mon_for_mon(SceneId, X1, X2, Y1, Y2, MonType),
				AllUser = get_att_user_for_mon(SceneId, X1, X2, Y1, Y2),
				AllMon ++ AllUser
		end,
    get_area_mon_for_battlle_loop(All, X, Y, 1000000, MonType, []).
%% 获取一个最近的攻击者
get_area_mon_for_battlle_loop([], _MX, _MY, _Len, _MonType, Ret) -> 
	Ret;
get_area_mon_for_battlle_loop([[Id, Pid, X, Y, Type, AttType] | M], MX, MY, Len, MonType, Ret) ->
    Dist = abs(X - MX) + abs(Y - MY),    
    {NewLen, NewRet} =
        case Dist < Len of
            true ->
				case (Type == 100 andalso MonType == 101) orelse (Type == 101 andalso MonType == 100) of
					true ->
						{Len, Ret};
					false ->
						{Dist, [Id, Pid, AttType]}
				end;
            false -> 
				{Len, Ret}
        end,
    get_area_mon_for_battlle_loop(M, MX, MY, NewLen, MonType, NewRet).

get_att_mon_for_mon(SceneId, X1, X2, Y1, Y2, MonType) ->
	OtherMonType =
		case MonType of
			98 ->
				99;
			99 -> 
				98;
			_ ->
				0
		end,
	MS = ets:fun2ms(fun(M) when M#ets_mon.scene == SceneId andalso M#ets_mon.hp > 0 andalso
								M#ets_mon.x >= X2 andalso M#ets_mon.x =< X1 andalso 
								M#ets_mon.y >= Y2 andalso M#ets_mon.y =< Y1 andalso 
								M#ets_mon.type /= MonType andalso M#ets_mon.type /= OtherMonType ->
		[
			M#ets_mon.id, 
			M#ets_mon.pid, 
			M#ets_mon.x, 
			M#ets_mon.y,
			M#ets_mon.type,
			1			
		]
	end),
	ets:select(?ETS_SCENE_MON, MS).

get_att_user_for_mon(SceneId, X1, X2, Y1, Y2) ->
	MS = ets:fun2ms(fun(P) when P#player.scene == SceneId andalso P#player.hp > 0 andalso
								P#player.other#player_other.shadow == 0 andalso
								P#player.x >= X2 andalso P#player.x =< X1 andalso 
								P#player.y >= Y2 andalso P#player.y =< Y1 ->
		[
			P#player.id, 
			P#player.other#player_other.pid, 
			P#player.x, 
			P#player.y,
			0,
			2			
		]
	end),
	ets:select(?ETS_ONLINE_SCENE, MS).

%% 怪物加血（获取血量最少的目标）
get_user_mon_for_mon_hp(SceneId, X, Y, MonType, Area) ->
	X1 = X + Area,
    X2 = X - Area,
    Y1 = Y + Area,
    Y2 = Y - Area,
	MonMS = ets:fun2ms(fun(M) when M#ets_mon.scene == SceneId andalso M#ets_mon.hp > 0 andalso
								M#ets_mon.x >= X2 andalso M#ets_mon.x =< X1 andalso 
								M#ets_mon.y >= Y2 andalso M#ets_mon.y =< Y1 andalso 
								M#ets_mon.type == MonType andalso M#ets_mon.hp_lim > M#ets_mon.hp ->
		[
			M#ets_mon.id,
		 	M#ets_mon.pid, 
			M#ets_mon.hp, 
			1			
		]
	end),
	AllMon = ets:select(?ETS_SCENE_MON, MonMS),
	UserMS = ets:fun2ms(fun(P) when P#player.scene == SceneId andalso P#player.hp > 0 andalso
								P#player.x >= X2 andalso P#player.x =< X1 andalso 
								P#player.y >= Y2 andalso P#player.y =< Y1 andalso 
								P#player.hp_lim > P#player.hp ->
		[
			P#player.id,
		 	P#player.other#player_other.pid, 
			P#player.hp, 
			2			
		]
	end),
	AllUser = ets:select(?ETS_ONLINE_SCENE, UserMS),
	All = AllMon ++ AllUser,
	get_user_mon_for_mon_hp_loop(All, 10000000000000000, []).
get_user_mon_for_mon_hp_loop([], _MinHp, Ret) ->
	Ret;
get_user_mon_for_mon_hp_loop([[Id, Pid, Hp, Type] | A], MinHp, Ret) ->
	case MinHp > Hp of
		true ->
			get_user_mon_for_mon_hp_loop(A, Hp, [Id, Pid, Type]);
		false ->
			get_user_mon_for_mon_hp_loop(A, MinHp, Ret)
	end.

%% 获取场景内要广播的范围用户ID(本节点)
get_broadcast_id_node(SceneId, X, Y) ->
   	Pattern = ets:fun2ms(fun(P) when P#player.scene == SceneId ->
		[
       		P#player.id,
      		P#player.x,
       		P#player.y
		]
	end),
   	AllUser = ets:select(?ETS_ONLINE, Pattern),
    XY = get_xy(X, Y),
    get_broadcast_id_loop(AllUser, XY, []).

%% 获取场景内要广播的范围怪物ID(本节点)
get_broadcast_mon_id_node(SceneId, X, Y) ->
	Pattern = ets:fun2ms(fun(M) when M#ets_mon.scene == SceneId ->
		[
       		M#ets_mon.id,
      		M#ets_mon.x,
       		M#ets_mon.y
		]
	end),
	AllMon = ets:select(?ETS_SCENE_MON, Pattern),
    XY = get_xy(X, Y),
    get_broadcast_id_loop(AllMon, XY, []).

get_broadcast_id_loop([], _XY, D) -> D;
get_broadcast_id_loop([[Id, X, Y] | T], XY, D) ->
	case is_in_area(X, Y, XY) of
		true ->
			get_broadcast_id_loop(T, XY, [Id | D]);
		false ->
			get_broadcast_id_loop(T, XY, D)
	end.

%% 是否在同一区域
is_in_area(X, Y, XY2) ->
	XY1 = get_xy(X, Y),
	XY1 == XY2 orelse XY1 == XY2 + 1 orelse XY1 == XY2 - 1 orelse XY1 == XY2 - 10 orelse XY1 == XY2 + 10 orelse XY1 == XY2 - 11 orelse XY1 == XY2 + 11 orelse XY1 == XY2 - 9 orelse XY1 == XY2 + 9.	

%% 复活进入场景
%% ReviveType 1高级稻草人； 2稻草人； 3安全复活
revive_to_scene(Player1, ReviveType, FromType) ->
	%%复活前先卸下坐骑
	{ok,Player} = pp_mount:handle(16003,Player1,[]),
	lib_hack:reset_speed_mark(),
    case ReviveType of
        %% 高级稻草人
        1 ->
			special_revive_to_scene(Player, ReviveType, FromType, 28401, ?ADVANCED_REVIVE_COST, 2001, 1);
        %% 稻草人
        2 ->
			special_revive_to_scene(Player, ReviveType, FromType, 28400, ?REVIVE_COST, 2002, 2);
		%% 竞技场死亡复活
		4 ->
			{X, Y} =
				case lib_arena:is_new_arena_scene(Player#player.scene) of
					true ->
						lib_arena:get_new_arena_position(Player#player.other#player_other.leader);
					false ->
						list_to_tuple(lib_arena:get_arena_start_position(Player#player.other#player_other.leader))
				end,
			NewPlayer = Player#player{
                hp = Player#player.hp_lim,
                mp = Player#player.mp_lim,                            
                x = X,
                y = Y
            },
			revive_to_scene_agent(NewPlayer, Player, ReviveType);
		%% 新战场原地复活
		14 ->
			RetPlayer = 
				case lib_player:player_status(Player) of
               		3 ->										
             			lib_goods:cost_money(Player, 5, gold, 2001);
                 	_ ->
                   		Player
           		end,
			NewPlayer = RetPlayer#player{
          		hp = RetPlayer#player.hp_lim,
               	mp = RetPlayer#player.mp_lim,
				x = Player#player.x,
				y = Player#player.y
           	},
			revive_to_scene_agent(NewPlayer, Player, ReviveType);
		5 ->%%空岛死亡复活
			[SkyReX, SkyReY] = ?SKYRUSH_REVIVE_COORD, %%神岛复活坐标
			NewPlayer = Player#player{
									  hp = Player#player.hp_lim,
									  mp = Player#player.mp_lim,   
									  carry_mark = 0, 
									  x = SkyReX,
									  y = SkyReY
									 },
			revive_to_scene_agent(NewPlayer, Player, ReviveType);
		6 -> %% TD复活
			NewPlayer = Player#player{
                        hp = trunc(Player#player.hp_lim / 2),
                        mp = trunc(Player#player.mp_lim / 2),
						carry_mark = 0,
						x = 24,
						y = 81                           
                    	},
			revive_to_scene_agent(NewPlayer, Player, ReviveType);
		%% 跨服战场复活
		7 ->
			[X, Y, Hp,Mp] = 
				case Player#player.other#player_other.leader of
					11 ->
						[16,85,Player#player.hp_lim,Player#player.mp_lim];
					12 ->
						[54,29,Player#player.hp_lim,Player#player.mp_lim];
					_ ->
						[Player#player.x, Player#player.y,trunc(Player#player.hp_lim / 2),trunc(Player#player.mp_lim / 2)]
				end,
			NewPlayer = Player#player{
                        hp = Hp,
                        mp = Mp,
						x = X,
						y = Y ,
						carry_mark = 0
									                          
                    	},
			NewPlayer1 = lib_player:count_player_speed(NewPlayer),
			revive_to_scene_agent(NewPlayer1, Player, ReviveType);
		8 ->
			[X, Y, Hp,Mp] = 
				case Player#player.other#player_other.leader of
					11 ->
						[16,85,trunc(Player#player.hp_lim / 2),trunc(Player#player.mp_lim / 2)];
					12 ->
						[54,29,trunc(Player#player.hp_lim / 2),trunc(Player#player.mp_lim / 2)];
					_ ->
						[Player#player.x, Player#player.y,trunc(Player#player.hp_lim / 2),trunc(Player#player.mp_lim / 2)]
				end,
			NewPlayer = Player#player{
                        hp = Hp,
                        mp = Mp,
						x = X,
						y = Y,
						carry_mark = 0                           
                    	},
			NewPlayer1 = lib_player:count_player_speed(NewPlayer),
			revive_to_scene_agent(NewPlayer1, Player, ReviveType);
		
		%% 攻城战复活
		9 ->
			RetPlayer = 
				case lib_player:player_status(Player) of
               		3 ->										
             			lib_goods:cost_money(Player, 10, gold, 2001);
                 	_ ->
                   		Player
           		end,
			[X, Y] =
				if
					Player#player.other#player_other.leader =:= 14 ->
						[5, 15];
					true ->
						lib_castle_rush:castle_rush_position(Player#player.realm)
				end,
			NewPlayer = RetPlayer#player{
          		hp = RetPlayer#player.hp_lim,
               	mp = RetPlayer#player.mp_lim,
				x = X,
				y = Y
           	},
			revive_to_scene_agent(NewPlayer, Player, ReviveType);
		10 ->%%神魔乱斗立即复活
			special_revive_to_scene(Player, ReviveType, FromType, 0, ?WARFARE_REVIVE_COST, 2002, 5);
		15->%%封神争霸死亡复活
			revive_to_scene_agent(Player, Player, ReviveType);
        %% 安全复活
		_ ->
			RetPlayer =
				%% 跑商安全复活需要传送到跑商起始点或者中途休息点
				if 
					Player#player.carry_mark > 3 andalso Player#player.carry_mark < 8 ->
					   	case lists:member(Player#player.scene, [101, 191, 190,300]) of
						  	true->
							   	Player#player{
									hp = trunc(Player#player.hp_lim / 10),
                					mp = trunc(Player#player.mp_lim / 10),
                                    x = 70,
                                    y = 124,
                                    scene = 300			  
                                };
						   	false->
							   	Player#player{
									hp = trunc(Player#player.hp_lim / 10),
                					mp = trunc(Player#player.mp_lim / 10),
                                    x = 89,
                                    y = 215,
                                    scene = 101			  
                                }
					   	end;
				   	true ->
						case lists:member(Player#player.scene, data_scene:get_hook_scene_list()) of
							true ->
								set_hooking_state(Player, 300),
								Player#player{
									hp = trunc(Player#player.hp_lim / 10),
                					mp = trunc(Player#player.mp_lim / 10),
                     				x = 66,
                         			y = 166,
                         			scene = 300			  
                     			};
							false ->
                                case Player#player.scene of
                                    %% 女娲城郊
                                    201 ->
                                        city_wild_revive(Player);
                                    %% 伏羲城郊
                                    251 ->
                                        city_wild_revive(Player);
                                    %% 神农城郊
                                    281 ->
                                        city_wild_revive(Player);
                                    %% 女娲
                                    200 ->
                                        Player#player{
											hp = trunc(Player#player.hp_lim / 10),
                							mp = trunc(Player#player.mp_lim / 10),
                                            x = 66,
                                            y = 192,
                                            scene = 200			  
                                        };
                                    %% 神农
                                    280 ->
                                        Player#player{
											hp = trunc(Player#player.hp_lim / 10),
                							mp = trunc(Player#player.mp_lim / 10),
                                            x = 70,
                                            y = 191,
                                            scene = 280			  
                                        };
                                    %% 伏羲
                                    250 ->
                                        Player#player{
											hp = trunc(Player#player.hp_lim / 10),
                							mp = trunc(Player#player.mp_lim / 10),
                                            x = 66,
                                            y = 188,
                                            scene = 250			  
                                        };
									?WARFARE_SCENE_ID ->%%神魔乱斗
										[X, Y] = ?WARFARE_REVIVE_COORD,%%神魔乱斗复活坐标
										if 
											Player#player.carry_mark =:= 27 ->
												case mod_warfare_mon:get_warfare_mon() of
													{ok, Warfare} ->
														gen_server:cast(Warfare, {'PLUTO_OWN_OFFLINE', Player#player.id});
													_ ->
														skip
												end,
												Carry_mark = 0;
											true->
												Carry_mark = Player#player.carry_mark
										end,
										Player#player{
											hp = trunc(Player#player.hp_lim / 10),
                							mp = trunc(Player#player.mp_lim / 10),
											x = X,
											y = Y,
											carry_mark = Carry_mark
										};
									
									%% 攻城战
									?CASTLE_RUSH_SCENE_ID ->
										[X, Y] =
											if
												Player#player.other#player_other.leader =:= 14 ->
													[5, 15];
												true ->
													lib_castle_rush:castle_rush_position(Player#player.realm)
											end,
										Player#player{
          									hp = Player#player.hp_lim,
               								mp = Player#player.mp_lim,
											x = X,
											y = Y
           								};
                                    _ ->
                                        ReviveResSceneId = get_res_id(Player#player.scene),
                                        [X, Y] =
                                            case data_scene:get(ReviveResSceneId) of
                                                [] ->
                                                    [Player#player.x, Player#player.y];
                                                Scene ->
													if
														ReviveResSceneId =/= ?CAVE_RES_SCENE_ID ->
                                                    		[Scene#ets_scene.x, Scene#ets_scene.y];
														true ->
															lib_cave:cave_revive_position(Player#player.other#player_other.pid_dungeon, Scene#ets_scene.x, Scene#ets_scene.y)
													end
                                            end,
                                        if 
                                            Player#player.carry_mark > 0 andalso Player#player.carry_mark < 4 ->
                                                Carry_mark = 0;
                                            true->
                                                Carry_mark = Player#player.carry_mark
                                        end,
                                        Player#player{
											hp = trunc(Player#player.hp_lim / 10),
                							mp = trunc(Player#player.mp_lim / 10),
                                            x = X,
                                            y = Y,
                                            carry_mark = Carry_mark
                                        }	
                                end
						end
				end,
			NewPlayer = RetPlayer#player{
				status = 0 							 
			},
			{ok, HookBinData} = pt_26:write(26003, [0, 0]),
    		lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send, HookBinData),
            revive_to_scene_agent(NewPlayer, Player, ReviveType)            
    end.

%% 城外安全复活
city_wild_revive(Player) ->
	case Player#player.realm of
   		%% 女娲
        1 ->
       		Player#player{
				hp = trunc(Player#player.hp_lim / 10),
                mp = trunc(Player#player.mp_lim / 10),
          		x = 66,
           		y = 192,
             	scene = 200			  
           	};

       	%% 神农
      	2 ->
         	Player#player{
				hp = trunc(Player#player.hp_lim / 10),
                mp = trunc(Player#player.mp_lim / 10),
           		x = 70,
          		y = 191,
           		scene = 280			  
           	};
        %% 伏羲
     	_ ->
         	Player#player{
				hp = trunc(Player#player.hp_lim / 10),
                mp = trunc(Player#player.mp_lim / 10),
        		x = 66,
           		y = 188,
       			scene = 250			  
       		}
	end.

%% 稻草人复活
special_revive_to_scene(Player, ReviveType, FromType, GoodsId, Cost, CostType, HpParam) ->
	case FromType of
        hook ->
            case lib_goods:goods_find(Player#player.id, GoodsId) of
                false ->
              		Player;                                            
                _Goods ->
					[X, Y] =
						%% 封神台在复活点复活
						case is_fst_scene(Player#player.scene) of
							true ->
								ReviveResSceneId = get_res_id(Player#player.scene),
                       			case data_scene:get(ReviveResSceneId) of
                       				[] ->
                          				[Player#player.x, Player#player.y];
                     				Scene ->
                       					[Scene#ets_scene.x, Scene#ets_scene.y]
                  				end;
							false ->
								[Player#player.x, Player#player.y]
						end,
					gen_server:cast(Player#player.other#player_other.pid_goods, {'DELETE_MORE', GoodsId, 1}),
                    NewPlayer = Player#player{
                        hp = trunc(Player#player.hp_lim / HpParam),
                        mp = trunc(Player#player.mp_lim / HpParam),
						x = X,
						y = Y                           
                    },
                    revive_to_scene_agent(NewPlayer, Player, ReviveType)
            end;
        battle ->
			RetPlayer =
				case Player#player.scene =:= ?WARFARE_SCENE_ID of
					true ->%%神魔乱斗的，直接用元宝复活
						case lib_player:player_status(Player) of
                     		3 ->										
                     			lib_goods:cost_money(Player, Cost, gold, CostType);
                       		_ ->
                          		Player
                      	end;
					false ->
						case lib_goods:goods_find(Player#player.id, GoodsId) of
							false ->        
								case lib_player:player_status(Player) of
									3 ->		
										lib_goods:cost_money(Player, Cost, gold, CostType);
									_ ->
                          		Player
								end;
							_Goods ->
								gen_server:cast(Player#player.other#player_other.pid_goods, {'DELETE_MORE', GoodsId, 1}),
								Player
						end
				end,
			[X, Y] =
				%% 封神台在复活点复活
				case is_fst_scene(Player#player.scene) of
					true ->
						ReviveResSceneId = get_res_id(Player#player.scene),
                       	case data_scene:get(ReviveResSceneId) of
                       		[] ->
								Carry_mark = Player#player.carry_mark,
                          		[Player#player.x, Player#player.y];
                     		Scene ->
								Carry_mark = Player#player.carry_mark,
                       			[Scene#ets_scene.x, Scene#ets_scene.y]
                  		end;
					false ->
						case Player#player.scene =:= ?WARFARE_SCENE_ID of
							true ->%%神魔乱斗，也有指定的复活点
								if 
									Player#player.carry_mark =:= 27 ->
										case mod_warfare_mon:get_warfare_mon() of
											{ok, Warfare} ->
												gen_server:cast(Warfare, {'PLUTO_OWN_OFFLINE', Player#player.id});
											_ ->
												skip
										end,
										Carry_mark = 0;
									true->
										Carry_mark = Player#player.carry_mark
								end,
								?WARFARE_REVIVE_COORD;	%%神魔乱斗复活坐标
							false ->
								Carry_mark = Player#player.carry_mark,
								[Player#player.x, Player#player.y]
						end
				end,
			NewPlayer = RetPlayer#player{
				carry_mark = Carry_mark,
     			hp = trunc(RetPlayer#player.hp_lim / HpParam),
     			mp = trunc(RetPlayer#player.mp_lim / HpParam),
				x = X,
				y = Y
          	},
         	revive_to_scene_agent(NewPlayer, RetPlayer, ReviveType);
        _ ->
      		Player
    end.

revive_to_scene_agent(NewPlayer, Player, ReviveType) ->
	RetPlayer = 
		case NewPlayer#player.status of
			%% 挂机状态
			5 ->
				NewPlayer;
			_Other ->
				NewPlayer#player{
					status = 0
				}											
		end,
	case RetPlayer#player.scene == Player#player.scene of
		true ->			
            BinData = pt_12:trans_to_12003(RetPlayer),
			{ok, Bin12003} = pt_12:write(12003, BinData),
            NewReviveType = 
                case RetPlayer#player.arena /= 3 of
                    true ->
                        ReviveType;
                    false ->
                        6
                end,
            %% 复活到场景
            mod_scene_agent:revive_to_scene(
			  		[Player#player.other#player_other.pid_send, Player#player.other#player_other.pid_send2,Player#player.other#player_other.pid_send3],
                    Player#player.id, NewReviveType,
                    RetPlayer#player.scene, RetPlayer#player.x, RetPlayer#player.y,
                    Player#player.scene, Player#player.x, Player#player.y, Bin12003),
			lib_player:send_player_attribute(RetPlayer, 1);
		false ->
			%% 通知本屏玩家你离开死亡点
			{ok, BinData} = pt_12:write(12011, [[], [Player#player.id], [], []]),
			mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, BinData),
			pp_scene:handle(12004, Player, Player#player.scene),
			lib_player:send_player_attribute(RetPlayer, 0)
	end,
	lib_team:update_team_player_info(RetPlayer),
	RetPlayer.

%%获取复活时间限制(跨服战场)
%% get_revive_time_limit(Player)->
%% 	if Player#player.other#player_other.war_die_times =< 3->3;
%% 	   Player#player.other#player_other.war_die_times =< 5->5;
%% 	   Player#player.other#player_other.war_die_times =< 10->10;
%% %% 	   Player#player.other#player_other.war_die_times =< 20->15;
%% 	   true->10
%% 	end.

%% 复活进入场景(本节点)
revive_to_scene_node(PidSends, PlayerId, ReviveType, NewSceneId, X1, Y1, SceneId, X2, Y2, EnterBroadcastBinData) ->
	%% 通知本屏玩家你离开死亡点
	case lists:member(ReviveType, [3, 4, 5,7,8]) of
		true ->
			{ok, DieLeaveBinData} = pt_12:write(12011, [[], [PlayerId], [], []]),
			lib_send:send_to_local_scene(SceneId, X2, Y2, DieLeaveBinData);
		false ->
			skip
	end,
	%% 通知本玩家
    EnterUser = get_broadcast_user_node(NewSceneId, X1, Y1),
    LeaveUser = get_broadcast_id_node(SceneId, X2, Y2),
	EnterMon = 
		case is_copy_scene(NewSceneId) of
			false when SceneId =:= ?WARFARE_SCENE_ID ->%%神魔乱斗的怪物
				[];
			false ->
				get_broadcast_mon(NewSceneId, X1, Y1);
			true ->
				[]
		end,
	LeaveMon = 
		case is_copy_scene(SceneId) of
			false when SceneId =:= ?WARFARE_SCENE_ID ->%%神魔乱斗的怪物
				[];
			false ->
				get_broadcast_mon_id_node(SceneId, X2, Y2);
			true ->
				[]
		end,
	if 	
		length(EnterUser) + length(LeaveUser) + length(EnterMon) + length(LeaveMon) > 0 ->
    		{ok, EnterLeaveBinData} = pt_12:write(12011, [EnterUser, LeaveUser, EnterMon, LeaveMon]),
			lib_send:send_to_sids(PidSends, EnterLeaveBinData,?MOVE_SOCKET);
		true -> no_send
	end,
	%{ok, EnterBroadcastBinData} = pt_12:write(12003, Bin12003),
	%% 竞技场死亡进入观战模式
	case ReviveType /= 6 of
		true ->
			%% 告诉复活点的玩家你进入场景    		
    		lib_send:send_to_local_scene(NewSceneId, X1, Y1, EnterBroadcastBinData);
		false ->
			skip
	end,
	lib_send:send_to_sids(PidSends, EnterBroadcastBinData,?MOVE_SOCKET).


%% 获得同屏等级大于25的玩家ID列表,并向其发送祝福
get_player_in_screen_bless([PlayerId, NickName, Lv, SceneId, X, Y], L_friends) ->
	Broadcast_user = lib_scene:get_broadcast_user(SceneId, X, Y),
	L = get_broadcast_user_25_list_loop(Broadcast_user,[]),
	L1 = lists:delete(PlayerId, L),
	lib_relationship:send_bless_notes_nod(PlayerId, NickName, Lv, L1, L_friends).

%%获得同屏等级大于25的玩家ID列表
get_broadcast_user_25_list_loop([], Old_user_list) ->
	Old_user_list;

get_broadcast_user_25_list_loop([L_I|Broadcast_user], Old_user_list) ->
	[Id | _] = L_I,
	New_L=[Id | Old_user_list],
	get_broadcast_user_25_list_loop(Broadcast_user, New_L).

%%查找同屏玩家
get_double_rest_user(PlayerId,SceneId, X, Y) ->
	Broadcast_user = lib_scene:get_broadcast_user(SceneId, X, Y),
	get_double_rest_user_list_loop(PlayerId,Broadcast_user,[]).

get_double_rest_user_list_loop(_PlayerId,[],UserList) ->
	UserList;
get_double_rest_user_list_loop(PlayerId,[D|Broadcast_user],UserList) ->
	[Id, Nick, _X, _Y, _Hp, _Hp_lim, _Mp, _Mp_lim, Lv, Career, _Speed, _EquipCurrent, _Sex, _Out_pet, _Pid, _Leader, _Pid_team, _Realm, _Guild_name, _GuildPosition, _Evil, Status,_Carry_Mark,_ConVoy_Npc,_Stren,_SuitID,_Vip,_MountStren,_PeachRevel,_CharmTitle, _IsSpring, _Turned, Accept,_DeputyProfLv,_Couple,_SuitId,_FullStren,_FbyfStren,_SpyfStren,_Pet_batt_skill] = D,
	 if
		 Id =/= PlayerId andalso Status =/= 10 andalso Accept =/= 4 ->
			 NewUserList= [[Id, Nick, Lv, Career] | UserList],
			 get_double_rest_user_list_loop(PlayerId,Broadcast_user,NewUserList);
		 true ->
			 get_double_rest_user_list_loop(PlayerId,Broadcast_user,UserList)
	 end.

%% 当人物移动时候的广播(节点代理处理)
%% 终点要X1, Y1，原点是X2, Y2
move_broadcast_node(SceneId, PidSends, X1, Y1, X2, Y2, PlayerId, Sta, MoveBinData, LeaveBinData, EnterBinData) ->
	%% 更新当前移动玩家的场景数据 x,y,status
	Pattern = #player{id = PlayerId, scene = SceneId, _ = '_'},
	MovePlayer = goods_util:get_ets_info(?ETS_ONLINE_SCENE, Pattern),
	if
		MovePlayer =/= {} ->
			ets:insert(?ETS_ONLINE_SCENE, MovePlayer#player{x = X1, y = Y1, status = Sta});
		true ->
			skip
	end,
    XY1 = get_xy(X1, Y1),
    XY2 = get_xy(X2, Y2),
    %%当前场景玩家信息
	MS = ets:fun2ms(fun(T) when T#player.scene == SceneId andalso T#player.x < X2 + 25 andalso 
								T#player.x > X2 - 25 andalso T#player.y < Y2 + 35 andalso 
								T#player.y > Y2 - 35 ->
		[
            T#player.id,
            T#player.nickname,
            T#player.x,
            T#player.y,
            T#player.hp,
            T#player.hp_lim,
            T#player.mp,
            T#player.mp_lim,
            T#player.lv,
            T#player.career,
            [T#player.other#player_other.pid_send,T#player.other#player_other.pid_send2,T#player.other#player_other.pid_send3],
            T#player.speed,
            T#player.other#player_other.equip_current,
            T#player.sex,
			T#player.other#player_other.out_pet,
            T#player.other#player_other.pid,
            T#player.other#player_other.leader,
            T#player.other#player_other.pid_team,
            T#player.realm,
            T#player.guild_name,
			T#player.guild_position,
            T#player.evil,
            T#player.status,
			T#player.carry_mark,
			T#player.task_convoy_npc,
			T#player.other#player_other.stren,
			T#player.other#player_other.suitid,
			T#player.arena,
			T#player.vip,
			T#player.other#player_other.mount_stren,
			T#player.other#player_other.peach_revel,
			T#player.other#player_other.titles,
			T#player.other#player_other.is_spring,
			T#player.other#player_other.turned,
			T#player.other#player_other.accept,
			T#player.other#player_other.deputy_prof_lv,
			T#player.couple_name,
			T#player.other#player_other.suitid,
			T#player.other#player_other.fullstren,
			T#player.other#player_other.fbyfstren,
			T#player.other#player_other.spyfstren,
			T#player.other#player_other.pet_batt_skill
		]
	end),
   	AllUser = ets:select(?ETS_ONLINE, MS),
    %% 加入和移除玩家
	[EnterUser, LeaveUser, EnterMon, LeaveMon] = 
        if
            XY2 == XY1 -> %% 同一个格子内
                [EU, LU] = move_loop1(AllUser, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], [], []),
				[EU, LU, [], []];
            XY2 + 1 == XY1 -> %% 向右
                [EU, LU] = move_loop2(AllUser, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], [], []),
				case is_copy_scene(SceneId) of
					false when SceneId =:= ?WARFARE_SCENE_ID ->%%神魔乱斗的怪物
						[EU, LU, [], []];
					false ->
						AllMon = get_area_scene_mon(SceneId, X2, Y2),
						move_mon_loop2(AllMon, XY1, XY2, EU, LU, [], []);
					true ->
						[EU, LU, [], []]
				end;
            XY2 - 1 == XY1 -> %% 向左
                [EU, LU] = move_loop3(AllUser, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], [], []),
				case is_copy_scene(SceneId) of
					false when SceneId =:= ?WARFARE_SCENE_ID ->%%神魔乱斗的怪物
						[EU, LU, [], []];
					false ->
						AllMon = get_area_scene_mon(SceneId, X2, Y2),
						move_mon_loop3(AllMon, XY1, XY2, EU, LU, [], []);
					true ->
						[EU, LU, [], []]
				end;
            XY2 - 10 == XY1 -> %% 向上
                [EU, LU] = move_loop4(AllUser, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], [], []),
				case is_copy_scene(SceneId) of
					false when SceneId =:= ?WARFARE_SCENE_ID ->%%神魔乱斗的怪物
						[EU, LU, [], []];
					false ->
						AllMon = get_area_scene_mon(SceneId, X2, Y2),
						move_mon_loop4(AllMon, XY1, XY2, EU, LU, [], []);
					true ->
						[EU, LU, [], []]
				end;
				
            XY2 + 10 == XY1 -> %% 向下
                [EU, LU] = move_loop5(AllUser, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], [], []),
				case is_copy_scene(SceneId) of
					false when SceneId =:= ?WARFARE_SCENE_ID ->%%神魔乱斗的怪物
						[EU, LU, [], []];
					false ->
						AllMon = get_area_scene_mon(SceneId, X2, Y2),
						move_mon_loop5(AllMon, XY1, XY2, EU, LU, [], []);
					true ->
						[EU, LU, [], []]
				end;
            XY2 - 11 == XY1 -> %% 向左上
                [EU, LU] = move_loop6(AllUser, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], [], []),
				case is_copy_scene(SceneId) of
					false when SceneId =:= ?WARFARE_SCENE_ID ->%%神魔乱斗的怪物
						[EU, LU, [], []];
					false ->
						AllMon = get_area_scene_mon(SceneId, X2, Y2),
						move_mon_loop6(AllMon, XY1, XY2, EU, LU, [], []);
					true ->
						[EU, LU, [], []]
				end;
            XY2 + 9 == XY1 -> %% 向左下
                [EU, LU] = move_loop7(AllUser, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], [], []),
				case is_copy_scene(SceneId) of
					false when SceneId =:= ?WARFARE_SCENE_ID ->%%神魔乱斗的怪物
						[EU, LU, [], []];
					false ->
						AllMon = get_area_scene_mon(SceneId, X2, Y2),
						move_mon_loop7(AllMon, XY1, XY2, EU, LU, [], []);
					true ->
						[EU, LU, [], []]
				end;
            XY2 - 9 == XY1 -> %% 向右上
                [EU, LU] = move_loop8(AllUser, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], [], []),
				case is_copy_scene(SceneId) of
					false when SceneId =:= ?WARFARE_SCENE_ID ->%%神魔乱斗的怪物
						[EU, LU, [], []];
					false ->
						AllMon = get_area_scene_mon(SceneId, X2, Y2),
						move_mon_loop8(AllMon, XY1, XY2, EU, LU, [], []);
					true ->
						[EU, LU, [], []]
				end;
            XY2 + 11 == XY1 -> %% 向右下
                [EU, LU] = move_loop9(AllUser, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], [], []),
				case is_copy_scene(SceneId) of
					false when SceneId =:= ?WARFARE_SCENE_ID ->%%神魔乱斗的怪物
						[EU, LU, [], []];
					false ->
						AllMon = get_area_scene_mon(SceneId, X2, Y2),
						move_mon_loop9(AllMon, XY1, XY2, EU, LU, [], []);
					true ->
						[EU, LU, [], []]
				end;
            true ->
                [EU, LU] = move_loop1(AllUser, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], [], []),
				[EU, LU, [], []]
        end,
	if 	
		(length(EnterUser) + length(LeaveUser) + length(EnterMon) + length(LeaveMon)) > 0 ->
    		{ok, EnterLeaveBinData} = pt_12:write(12011, [EnterUser, LeaveUser, EnterMon, LeaveMon]),
			lib_send:send_to_sids(PidSends, EnterLeaveBinData,?MOVE_SOCKET);
		true -> 
			no_send
	end.

move_loop1([], _, EnterUser, LeaveUser) -> [EnterUser, LeaveUser];
move_loop1([D | T], [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser) ->
    [_Id, _Nick, X, Y, _Hp, _Hp_lim, _Mp, _Mp_lim, _Lv, _Career, Sids | _] = D,
    XY = get_xy(X, Y),
	
    if
		MoveBinData /= 0 andalso (XY == XY2 orelse XY == XY2 + 1 orelse XY == XY2 -1 orelse XY == XY2 -10 orelse XY == XY2 +10 orelse XY == XY2 -11 orelse XY == XY2 +11 orelse XY == XY2 -9  orelse XY == XY2+9) ->
			%%io:format("--------x:~p-----y:~p~n",[X,Y]),
			lib_send:send_to_sids(Sids, MoveBinData, ?MOVE_SOCKET);
        true ->
			skip
    end,
	move_loop1(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser).

move_loop2([], _, EnterUser, LeaveUser) -> [EnterUser, LeaveUser];
move_loop2([D | T], [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser) ->
    [Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Sids, Speed, EquipCurrent, Sex, Out_pet, Pid, Leader, Pid_team, Realm, Guild_name, GuildPosition, Evil, Status,Carry_Mark,ConVoy_Npc,Stren,SuitID, Arena,Vip,MountStren,PeachRevel,CharmTitle, IsSpring, Turned, Accept,DeputyProfLv,_Couple,SuitId,FullStren,FbyfStren,SpyfStren,Pet_batt_skill] = D,
    XY = get_xy(X, Y),	
    if
		XY == XY1 + 1 orelse XY == XY1 + 11 orelse XY == XY1 - 9 -> % 进入
			lib_send:send_to_sids(Sids, EnterBinData,?MOVE_SOCKET),
			%%?DEBUG("-----------------ENTER---2:~p~n",[Id]),
			case Arena == 3 of
				true ->
					move_loop2(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser);
				false ->
                    move_loop2(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], 
					   [[Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent, Sex, Out_pet, Pid, Leader, Pid_team, Realm, Guild_name, GuildPosition, Evil, Status, Carry_Mark, ConVoy_Npc,Stren,SuitID,Vip,MountStren,PeachRevel,CharmTitle, IsSpring, Turned, Accept,DeputyProfLv,_Couple,SuitId,FullStren,FbyfStren,SpyfStren,Pet_batt_skill] | EnterUser], LeaveUser)
			end;			
        XY == XY2 - 1 orelse XY == XY2 - 11 orelse XY == XY2 + 9 -> % 离开
			lib_send:send_to_sids(Sids, LeaveBinData,?MOVE_SOCKET),
            move_loop2(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, [Id | LeaveUser]);
		MoveBinData /= 0 andalso (XY == XY2 orelse XY == XY2 + 1  orelse XY == XY2 -10 orelse XY == XY2 +10 orelse XY == XY2 + 11 orelse XY == XY2 - 9) -> % 公共区域
			lib_send:send_to_sids(Sids, MoveBinData,?MOVE_SOCKET),
            move_loop2(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser);
        true ->
            move_loop2(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser)
    end.

move_loop3([],_ , EnterUser, LeaveUser) -> [EnterUser, LeaveUser];
move_loop3([D | T], [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser) ->
    [Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Sids, Speed, EquipCurrent, Sex, Out_pet, Pid, Leader, Pid_team, Realm, Guild_name, GuildPosition, Evil, Status,Carry_Mark,ConVoy_Npc,Stren,SuitID, Arena,Vip,MountStren,PeachRevel,CharmTitle, IsSpring, Turned, Accept,DeputyProfLv,_Couple,SuitId,FullStren,FbyfStren,SpyfStren,Pet_batt_skill] = D,
    XY = get_xy(X, Y),	
    if
		XY == XY1 - 1 orelse XY == XY1 - 11 orelse XY == XY1 + 9 -> % 进入
			%%?DEBUG("-----------------ENTER---3:~p~n",[Id]),
			lib_send:send_to_sids(Sids, EnterBinData,?MOVE_SOCKET),
			case Arena == 3 of
				true ->
					move_loop3(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser);
				false ->
					move_loop3(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], [[Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent, Sex, Out_pet, Pid, Leader, Pid_team, Realm, Guild_name, GuildPosition, Evil, Status,Carry_Mark,ConVoy_Npc,Stren,SuitID,Vip,MountStren,PeachRevel,CharmTitle, IsSpring, Turned, Accept,DeputyProfLv,_Couple,SuitId,FullStren,FbyfStren,SpyfStren,Pet_batt_skill] | EnterUser], LeaveUser)
			end;			
        XY == XY2 + 1 orelse XY == XY2 + 11 orelse XY == XY2 - 9 -> % 离开
			lib_send:send_to_sids(Sids, LeaveBinData,?MOVE_SOCKET),
             move_loop3(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, [Id | LeaveUser]);
		MoveBinData /= 0 andalso (XY == XY2 orelse XY == XY2 - 11 orelse XY == XY2 -1 orelse XY == XY2 -10 orelse XY == XY2 +10 orelse XY == XY2+9) ->
			lib_send:send_to_sids(Sids, MoveBinData,?MOVE_SOCKET),
            move_loop3(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser);
        true ->
            move_loop3(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser)
    end.

move_loop4([],_ , EnterUser, LeaveUser) -> [EnterUser, LeaveUser];
move_loop4([D | T], [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser) ->
    [Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Sids, Speed, EquipCurrent, Sex, Out_pet, Pid, Leader, Pid_team, Realm, Guild_name, GuildPosition, Evil, Status,Carry_Mark,ConVoy_Npc,Stren,SuitID, Arena,Vip,MountStren,PeachRevel,CharmTitle, IsSpring, Turned, Accept,DeputyProfLv,_Couple,SuitId,FullStren,FbyfStren,SpyfStren,Pet_batt_skill] = D,
    XY = get_xy(X, Y),	
    if
		XY == XY1 - 10 orelse XY == XY1 - 11 orelse XY == XY1 - 9 ->
			%%?DEBUG("-----------------ENTER---4:~p~n",[Id]),
			lib_send:send_to_sids(Sids, EnterBinData,?MOVE_SOCKET),
            case Arena == 3 of
		        true ->
                    move_loop4(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser);
		        false ->
                    move_loop4(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], [[Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent, Sex, Out_pet, Pid, Leader, Pid_team, Realm, Guild_name, GuildPosition, Evil, Status,Carry_Mark,ConVoy_Npc,Stren,SuitID,Vip,MountStren,PeachRevel,CharmTitle, IsSpring, Turned, Accept,DeputyProfLv,_Couple,SuitId,FullStren,FbyfStren,SpyfStren,Pet_batt_skill] | EnterUser], LeaveUser)
	        end;
        XY == XY2 + 10 orelse XY == XY2 + 11 orelse XY == XY2 + 9 -> % 离开
			lib_send:send_to_sids(Sids, LeaveBinData,?MOVE_SOCKET),
            move_loop4(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, [Id | LeaveUser]);
        MoveBinData /= 0 andalso (XY == XY2 orelse XY == XY2 + 1 orelse XY == XY2 - 1 orelse XY == XY2 - 10 orelse XY == XY2 - 11 orelse XY == XY2 - 9) ->
			lib_send:send_to_sids(Sids, MoveBinData,?MOVE_SOCKET),
            move_loop4(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser);
        true ->
            move_loop4(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser)
    end.

move_loop5([],_ , EnterUser, LeaveUser) -> [EnterUser, LeaveUser];
move_loop5([D | T], [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser) ->
    [Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Sids, Speed, EquipCurrent, Sex, Out_pet, Pid, Leader, Pid_team, Realm, Guild_name, GuildPosition, Evil, Status,Carry_Mark,ConVoy_Npc,Stren,SuitID, Arena,Vip,MountStren,PeachRevel,CharmTitle, IsSpring, Turned, Accept,DeputyProfLv,_Couple,SuitId,FullStren,FbyfStren,SpyfStren,Pet_batt_skill] = D,
    XY = get_xy(X, Y),
    if
		XY == XY1 + 10 orelse XY == XY1 + 11 orelse XY == XY1 + 9 ->
			%%?DEBUG("-----------------ENTER---5:~p~n",[Id]),
			lib_send:send_to_sids(Sids, EnterBinData,?MOVE_SOCKET),
			case Arena == 3 of
				true ->
					move_loop5(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser);
				false ->
					move_loop5(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], [[Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent, Sex, Out_pet, Pid, Leader, Pid_team, Realm, Guild_name, GuildPosition, Evil, Status,Carry_Mark,ConVoy_Npc,Stren,SuitID,Vip,MountStren,PeachRevel,CharmTitle, IsSpring, Turned, Accept,DeputyProfLv,_Couple,SuitId,FullStren,FbyfStren,SpyfStren,Pet_batt_skill] | EnterUser], LeaveUser)
			end;			
        XY == XY2 - 10 orelse XY == XY2 - 11 orelse XY == XY2 - 9 -> % 离开
			lib_send:send_to_sids(Sids, LeaveBinData,?MOVE_SOCKET),
            move_loop5(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, [Id | LeaveUser]);
        MoveBinData /= 0 andalso (XY == XY2 orelse XY == XY2 + 1 orelse XY == XY2 - 1 orelse XY == XY2 + 10 orelse XY == XY2 + 11 orelse XY == XY2 + 9) ->
			lib_send:send_to_sids(Sids, MoveBinData,?MOVE_SOCKET),
            move_loop5(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser);
        true ->
            move_loop5(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser)
    end.

move_loop6([],_ , EnterUser, LeaveUser) -> [EnterUser, LeaveUser];
move_loop6([D | T], [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser) ->
    [Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Sids, Speed, EquipCurrent, Sex, Out_pet, Pid, Leader, Pid_team, Realm, Guild_name, GuildPosition, Evil, Status,Carry_Mark,ConVoy_Npc,Stren,SuitID, Arena,Vip,MountStren,PeachRevel,CharmTitle, IsSpring, Turned, Accept,DeputyProfLv,_Couple,SuitId,FullStren,FbyfStren,SpyfStren,Pet_batt_skill] = D,
    XY = get_xy(X, Y),
    if
		XY == XY1 - 1 orelse XY == XY1 - 11 orelse XY == XY1 - 10 orelse XY == XY1 - 9 orelse XY == XY1 + 9 ->
			%%?DEBUG("-----------------ENTER---6:~p~n",[Id]),
			lib_send:send_to_sids(Sids, EnterBinData,?MOVE_SOCKET),
            case Arena == 3 of
		        true ->
                    move_loop6(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser);
		        false ->
                    move_loop6(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], [[Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent, Sex, Out_pet, Pid, Leader, Pid_team, Realm, Guild_name, GuildPosition, Evil, Status,Carry_Mark,ConVoy_Npc,Stren,SuitID,Vip,MountStren,PeachRevel,CharmTitle, IsSpring, Turned, Accept,DeputyProfLv,_Couple,SuitId,FullStren,FbyfStren,SpyfStren,Pet_batt_skill] | EnterUser], LeaveUser)
	        end;
        XY == XY2 + 1 orelse XY == XY2 + 11 orelse XY == XY2 + 10 orelse XY == XY2 + 9 orelse XY == XY2 - 9 ->
			lib_send:send_to_sids(Sids, LeaveBinData,?MOVE_SOCKET),
            move_loop6(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, [Id | LeaveUser]);
        MoveBinData /= 0 andalso (XY == XY2 orelse XY == XY2 - 11 orelse XY == XY2 - 1 orelse XY == XY2 - 10) ->
			lib_send:send_to_sids(Sids, MoveBinData,?MOVE_SOCKET),
            move_loop6(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser);
        true ->
            move_loop6(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser)
    end.

move_loop7([],_ , EnterUser, LeaveUser) -> [EnterUser, LeaveUser];
move_loop7([D | T], [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser) ->
    [Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Sids, Speed, EquipCurrent, Sex, Out_pet, Pid, Leader, Pid_team, Realm, Guild_name, GuildPosition, Evil, Status,Carry_Mark,ConVoy_Npc,Stren,SuitID, Arena,Vip,MountStren,PeachRevel,CharmTitle, IsSpring, Turned, Accept,DeputyProfLv,_Couple,SuitId,FullStren,FbyfStren,SpyfStren,Pet_batt_skill] = D,
    XY = get_xy(X, Y),
    if
		XY == XY1 - 11 orelse XY == XY1 - 1 orelse XY == XY1 + 9 orelse XY == XY1 + 10 orelse XY == XY1 + 11 ->
			%%?DEBUG("-----------------ENTER---7:~p~n",[Id]),
			lib_send:send_to_sids(Sids, EnterBinData,?MOVE_SOCKET),
            case Arena == 3 of
		        true ->
                    move_loop7(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser);
		        false ->
                    move_loop7(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], [[Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent, Sex, Out_pet, Pid, Leader, Pid_team, Realm, Guild_name, GuildPosition, Evil, Status,Carry_Mark,ConVoy_Npc,Stren,SuitID,Vip,MountStren,PeachRevel,CharmTitle, IsSpring, Turned, Accept,DeputyProfLv,_Couple,SuitId,FullStren,FbyfStren,SpyfStren,Pet_batt_skill] | EnterUser], LeaveUser)
	        end;
        XY == XY2 + 11 orelse XY == XY2 + 1 orelse XY == XY2 - 9 orelse XY == XY2 - 10 orelse XY == XY2 - 11 ->
			lib_send:send_to_sids(Sids, LeaveBinData,?MOVE_SOCKET),
            move_loop7(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, [Id | LeaveUser]);
        MoveBinData /= 3 andalso (XY == XY2 orelse XY == XY2 - 1 orelse XY == XY2 + 10 orelse XY == XY2 + 9) ->
			lib_send:send_to_sids(Sids, MoveBinData,?MOVE_SOCKET),
            move_loop7(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser);
        true ->
            move_loop7(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser)
    end.

move_loop8([],_ , EnterUser, LeaveUser) -> [EnterUser, LeaveUser];
move_loop8([D | T], [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser) ->
    [Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Sids,Speed, EquipCurrent, Sex, Out_pet, Pid, Leader, Pid_team, Realm, Guild_name, GuildPosition, Evil, Status,Carry_Mark,ConVoy_Npc,Stren,SuitID, Arena,Vip,MountStren,PeachRevel,CharmTitle, IsSpring, Turned, Accept,DeputyProfLv,_Couple,SuitId,FullStren,FbyfStren,SpyfStren,Pet_batt_skill] = D,
    XY = get_xy(X, Y),
    if
		XY == XY1 + 1 orelse XY == XY1 + 11 orelse XY == XY1 - 9 orelse XY == XY1 - 10 orelse XY == XY1 - 11 ->
			%%?DEBUG("-----------------ENTER---8:~p~n",[Id]),
			lib_send:send_to_sids(Sids, EnterBinData,?MOVE_SOCKET),
            case Arena == 3 of
		        true ->
                    move_loop8(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser);
		        false ->
                    move_loop8(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], [[Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent, Sex, Out_pet, Pid, Leader, Pid_team, Realm, Guild_name, GuildPosition, Evil, Status,Carry_Mark,ConVoy_Npc,Stren,SuitID,Vip,MountStren,PeachRevel,CharmTitle, IsSpring, Turned, Accept,DeputyProfLv,_Couple,SuitId,FullStren,FbyfStren,SpyfStren,Pet_batt_skill] | EnterUser], LeaveUser)
	        end;
        XY == XY2 - 1 orelse XY == XY2 - 11 orelse XY == XY2 + 9 orelse XY == XY2 + 10 orelse XY == XY2 + 11 ->
			lib_send:send_to_sids(Sids, LeaveBinData,?MOVE_SOCKET),
            move_loop8(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, [Id | LeaveUser]);
        MoveBinData /= 3 andalso (XY == XY2 orelse XY == XY2 + 1 orelse XY == XY2 - 10 orelse XY == XY2 - 9) ->
			lib_send:send_to_sids(Sids, MoveBinData,?MOVE_SOCKET),
            move_loop8(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser);
        true ->
            move_loop8(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser)
    end.

move_loop9([],_ , EnterUser, LeaveUser) -> [EnterUser, LeaveUser];
move_loop9([D | T], [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser) ->
    [Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Sids, Speed, EquipCurrent, Sex, Out_pet, Pid, Leader, Pid_team, Realm, Guild_name, GuildPosition, Evil, Status,Carry_Mark,ConVoy_Npc,Stren,SuitID, Arena,Vip,MountStren,PeachRevel,CharmTitle, IsSpring, Turned, Accept,DeputyProfLv,_Couple,SuitId,FullStren,FbyfStren,SpyfStren,Pet_batt_skill] = D,
    XY = get_xy(X, Y),
    if
		XY == XY1 + 1 orelse XY == XY1 + 9 orelse XY == XY1 + 10 orelse XY == XY1 + 11 orelse XY == XY1 - 9 ->
			lib_send:send_to_sids(Sids, EnterBinData,?MOVE_SOCKET),
            case Arena == 3 of
		        true ->
                    move_loop9(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser);
		        false ->
                    move_loop9(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], [[Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent, Sex, Out_pet, Pid, Leader, Pid_team, Realm, Guild_name, GuildPosition, Evil, Status,Carry_Mark,ConVoy_Npc,Stren,SuitID,Vip,MountStren,PeachRevel,CharmTitle, IsSpring, Turned, Accept,DeputyProfLv,_Couple,SuitId,FullStren,FbyfStren,SpyfStren,Pet_batt_skill] | EnterUser], [Id | LeaveUser])
	        end;
        XY == XY2 - 1 orelse XY == XY2 - 9 orelse XY == XY2 - 10 orelse XY == XY2 - 11 orelse XY == XY2 + 9 ->
			lib_send:send_to_sids(Sids, LeaveBinData,?MOVE_SOCKET),
            move_loop9(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, [Id | LeaveUser]);
        MoveBinData /= 0 andalso (XY == XY2 orelse XY == XY2 + 1 orelse XY == XY2 + 10 orelse XY == XY2 + 11) ->
			lib_send:send_to_sids(Sids, MoveBinData,?MOVE_SOCKET),
            move_loop9(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser);
        true ->
            move_loop9(T, [XY1, XY2, MoveBinData, LeaveBinData, EnterBinData], EnterUser, LeaveUser)
    end.

move_mon_loop2([], _XY1, _XY2, EnterUser, LeaveUser, EnterMon, LeaveMon) -> 
	[EnterUser, LeaveUser, EnterMon, LeaveMon];
move_mon_loop2([D | T], XY1, XY2, EnterUser, LeaveUser, EnterMon, LeaveMon) ->
    [Id, _Name, X, Y, _Hp, _HpLim, _Mp, _MpLim, _Lv, _Mid, _Icon, _Type, _AttArea] = D,
    XY = get_xy(X, Y),	
    if
		%% 进入
		XY == XY1 + 1 orelse XY == XY1 + 11 orelse XY == XY1 - 9 -> 
      		move_mon_loop2(T, XY1, XY2, EnterUser, LeaveUser, [D | EnterMon], LeaveMon);
        %% 离开
		XY == XY2 - 1 orelse XY == XY2 - 11 orelse XY == XY2 + 9 -> 
            move_mon_loop2(T, XY1, XY2, EnterUser, LeaveUser, EnterMon, [Id | LeaveMon]);
		%% 公共区域
        true ->
            move_mon_loop2(T, XY1, XY2, EnterUser, LeaveUser, EnterMon, LeaveMon)
    end.

move_mon_loop3([], _XY1, _XY2, EnterUser, LeaveUser, EnterMon, LeaveMon) -> 
	[EnterUser, LeaveUser, EnterMon, LeaveMon];
move_mon_loop3([D | T], XY1, XY2, EnterUser, LeaveUser, EnterMon, LeaveMon) ->
	[Id, _Name, X, Y, _Hp, _HpLim, _Mp, _MpLim, _Lv, _Mid, _Icon, _Type, _AttArea] = D,
    XY = get_xy(X, Y),
    if
		%% 进入
		XY == XY1 - 1 orelse XY == XY1 - 11 orelse XY == XY1 + 9 ->
			move_mon_loop3(T, XY1, XY2, EnterUser, LeaveUser, [D | EnterMon], LeaveMon);
        %% 离开
		XY == XY2 + 1 orelse XY == XY2 + 11 orelse XY == XY2 - 9 ->
			move_mon_loop3(T, XY1, XY2, EnterUser, LeaveUser, EnterMon, [Id | LeaveMon]);
        %% 公共区域
		true ->
			move_mon_loop3(T, XY1, XY2, EnterUser, LeaveUser, EnterMon, LeaveMon)
    end.

move_mon_loop4([], _XY1, _XY2, EnterUser, LeaveUser, EnterMon, LeaveMon) -> 
	[EnterUser, LeaveUser, EnterMon, LeaveMon];
move_mon_loop4([D | T], XY1, XY2, EnterUser, LeaveUser, EnterMon, LeaveMon) ->
	[Id, _Name, X, Y, _Hp, _HpLim, _Mp, _MpLim, _Lv, _Mid, _Icon, _Type, _AttArea] = D,
    XY = get_xy(X, Y),
    if
		%% 进入
		XY == XY1 - 10 orelse XY == XY1 - 11 orelse XY == XY1 - 9 ->
			move_mon_loop4(T, XY1, XY2, EnterUser, LeaveUser, [D | EnterMon], LeaveMon);
        %% 离开
		XY == XY2 + 10 orelse XY == XY2 + 11 orelse XY == XY2 + 9 ->
			move_mon_loop4(T, XY1, XY2, EnterUser, LeaveUser, EnterMon, [Id | LeaveMon]);
        %% 公共区域
		true ->
			move_mon_loop4(T, XY1, XY2, EnterUser, LeaveUser, EnterMon, LeaveMon)
    end.

move_mon_loop5([], _XY1, _XY2, EnterUser, LeaveUser, EnterMon, LeaveMon) -> 
	[EnterUser, LeaveUser, EnterMon, LeaveMon];
move_mon_loop5([D | T], XY1, XY2, EnterUser, LeaveUser, EnterMon, LeaveMon) ->
	[Id, _Name, X, Y, _Hp, _HpLim, _Mp, _MpLim, _Lv, _Mid, _Icon, _Type, _AttArea] = D,
    XY = get_xy(X, Y),
    if
		%% 进入
		XY == XY1 + 10 orelse XY == XY1 + 11 orelse XY == XY1 + 9 ->
			move_mon_loop5(T, XY1, XY2, EnterUser, LeaveUser, [D | EnterMon], LeaveMon);
        %% 离开
		XY == XY2 - 10 orelse XY == XY2 - 11 orelse XY == XY2 - 9 ->
			move_mon_loop5(T, XY1, XY2, EnterUser, LeaveUser, EnterMon, [Id | LeaveMon]);
        %% 公共区域
		true ->
			move_mon_loop5(T, XY1, XY2, EnterUser, LeaveUser, EnterMon, LeaveMon)
    end.

move_mon_loop6([], _XY1, _XY2, EnterUser, LeaveUser, EnterMon, LeaveMon) -> 
	[EnterUser, LeaveUser, EnterMon, LeaveMon];
move_mon_loop6([D | T], XY1, XY2, EnterUser, LeaveUser, EnterMon, LeaveMon) ->
	[Id, _Name, X, Y, _Hp, _HpLim, _Mp, _MpLim, _Lv, _Mid, _Icon, _Type, _AttArea] = D,
    XY = get_xy(X, Y),
    if
		%% 进入
		XY == XY1 - 1 orelse XY == XY1 - 11 orelse XY == XY1 - 10 orelse XY == XY1 - 9 orelse XY == XY1 + 9 ->
			move_mon_loop6(T, XY1, XY2, EnterUser, LeaveUser, [D | EnterMon], LeaveMon);
        %% 离开
		XY == XY2 + 1 orelse XY == XY2 + 11 orelse XY == XY2 + 10 orelse XY == XY2 + 9 orelse XY == XY2 - 9 ->
			move_mon_loop6(T, XY1, XY2, EnterUser, LeaveUser, EnterMon, [Id | LeaveMon]);
        %% 公共区域
		true ->
			move_mon_loop6(T, XY1, XY2, EnterUser, LeaveUser, EnterMon, LeaveMon)
    end.

move_mon_loop7([], _XY1, _XY2, EnterUser, LeaveUser, EnterMon, LeaveMon) -> 
	[EnterUser, LeaveUser, EnterMon, LeaveMon];
move_mon_loop7([D | T], XY1, XY2, EnterUser, LeaveUser, EnterMon, LeaveMon) ->
	[Id, _Name, X, Y, _Hp, _HpLim, _Mp, _MpLim, _Lv, _Mid, _Icon, _Type, _AttArea] = D,
    XY = get_xy(X, Y),
    if
		%% 进入
		XY == XY1 - 11 orelse XY == XY1 - 1 orelse XY == XY1 + 9 orelse XY == XY1 + 10 orelse XY == XY1 + 11 ->
			move_mon_loop7(T, XY1, XY2, EnterUser, LeaveUser, [D | EnterMon], LeaveMon);
        %% 离开
		XY == XY2 + 11 orelse XY == XY2 + 1 orelse XY == XY2 - 9 orelse XY == XY2 - 10 orelse XY == XY2 - 11 ->
			move_mon_loop7(T, XY1, XY2, EnterUser, LeaveUser, EnterMon, [Id | LeaveMon]);
        %% 公共区域
		true ->
			move_mon_loop7(T, XY1, XY2, EnterUser, LeaveUser, EnterMon, LeaveMon)
    end.

move_mon_loop8([], _XY1, _XY2, EnterUser, LeaveUser, EnterMon, LeaveMon) -> 
	[EnterUser, LeaveUser, EnterMon, LeaveMon];
move_mon_loop8([D | T], XY1, XY2, EnterUser, LeaveUser, EnterMon, LeaveMon) ->
	[Id, _Name, X, Y, _Hp, _HpLim, _Mp, _MpLim, _Lv, _Mid, _Icon, _Type, _AttArea] = D,
    XY = get_xy(X, Y),
    if
		%% 进入
		XY == XY1 + 1 orelse XY == XY1 + 11 orelse XY == XY1 - 9 orelse XY == XY1 - 10 orelse XY == XY1 - 11 ->
			move_mon_loop8(T, XY1, XY2, EnterUser, LeaveUser, [D | EnterMon], LeaveMon);
        %% 离开
		XY == XY2 - 1 orelse XY == XY2 - 11 orelse XY == XY2 + 9 orelse XY == XY2 + 10 orelse XY == XY2 + 11 ->
			move_mon_loop8(T, XY1, XY2, EnterUser, LeaveUser, EnterMon, [Id | LeaveMon]);
        %% 公共区域
		true ->
			move_mon_loop8(T, XY1, XY2, EnterUser, LeaveUser, EnterMon, LeaveMon)
    end.

move_mon_loop9([], _XY1, _XY2, EnterUser, LeaveUser, EnterMon, LeaveMon) -> 
	[EnterUser, LeaveUser, EnterMon, LeaveMon];
move_mon_loop9([D | T], XY1, XY2, EnterUser, LeaveUser, EnterMon, LeaveMon) ->
	[Id, _Name, X, Y, _Hp, _HpLim, _Mp, _MpLim, _Lv, _Mid, _Icon, _Type, _AttArea] = D,
    XY = get_xy(X, Y),
    if
		%% 进入
		XY == XY1 + 1 orelse XY == XY1 + 9 orelse XY == XY1 + 10 orelse XY == XY1 + 11 orelse XY == XY1 - 9 ->
			move_mon_loop9(T, XY1, XY2, EnterUser, LeaveUser, [D | EnterMon], LeaveMon);
        %% 离开
		XY == XY2 - 1 orelse XY == XY2 - 9 orelse XY == XY2 - 10 orelse XY == XY2 - 11 orelse XY == XY2 + 9 ->
			move_mon_loop9(T, XY1, XY2, EnterUser, LeaveUser, EnterMon, [Id | LeaveMon]);
        %% 公共区域
		true ->
			move_mon_loop9(T, XY1, XY2, EnterUser, LeaveUser, EnterMon, LeaveMon)
    end.

%% 基础_所有场景初始化
init_base_scene() ->
	L = db_agent:get_base_scene(),
	Scene_id_list = lists:flatten(L),
	lists:map(fun load_base_scene/1, Scene_id_list),
	ok.

%% 基础_某一场景初始化
load_base_scene(SceneId) ->
	L = db_agent:get_base_scene_one(SceneId),	
    if 
        L == [] ->
            ?ERROR_MSG("LOAD BASE SCENE DATA FAIL: ~w", [SceneId]);
        is_list(L) ->
            Scene = list_to_tuple([ets_scene | L]),
            Mask = binary_to_list(Scene#ets_scene.mask),
            Npc = data_agent:convert_npc(binary_to_list(Scene#ets_scene.npc)),
            Mon = data_agent:convert_mon(binary_to_list(Scene#ets_scene.mon)),
            load_base_npc(Npc, SceneId, 1),
            load_base_mon(Mon, SceneId, 1),
			load_base_scene_unique_mon(Mon, SceneId, []),
            case Mask of
                "" ->
                    ?ERROR_MSG("LOAD BASE SCENE MASK DATA ERROR: ~w", [SceneId]);
                _ ->
                    load_base_mask(Mask, 0, 0, SceneId)
            end,
            NewScene = Scene#ets_scene{
                id = SceneId,
                requirement = data_agent:convert_requirement(binary_to_list(Scene#ets_scene.requirement)),
                elem = data_agent:convert_elem(binary_to_list(Scene#ets_scene.elem)),  
                npc = Npc,
                mon = Mon,
                safe = util:string_to_term(binary_to_list(Scene#ets_scene.safe)),
                mask = Mask
            },
            ets:insert(?ETS_BASE_SCENE, NewScene);
        true ->
            ?ERROR_MSG("LOAD BASE SCENE DATA FAIL: ~w", [SceneId])
    end.

%% 加载场景怪物唯一信息
load_base_scene_unique_mon([], SceneId, Minfo) ->
	BSUM = #ets_base_scene_unique_mon{
		id = SceneId,
		mon = Minfo									
	},
	ets:insert(?ETS_BASE_SCENE_UNIQUE_MON, BSUM);
load_base_scene_unique_mon([[MonId, X, Y, _Type] | M], SceneId, Minfo) ->
    NewMinfo = 
        case lists:keyfind(MonId, 1, Minfo) of
            false ->
				case data_agent:mon_get(MonId) of
					[] ->
						Minfo;
					Mon ->
						%% 不列出BOSS怪
						case lists:member(Mon#ets_mon.type, [3, 6, 7]) of
                       		false ->
                                [{MonId, Mon#ets_mon.name, X, Y} | Minfo];                                
                            true ->
                                Minfo
                        end
				end;
            _ ->
                Minfo
        end,
    load_base_scene_unique_mon(M, SceneId, NewMinfo).

%% 加载基础_NPC 
load_base_npc([], _, _) -> ok;
load_base_npc([[NpcId, X, Y] | T], SceneId, Autoid) ->
     case data_agent:npc_get(NpcId) of
        [] ->
            ok;
        N ->
            N1 = N#ets_npc{
                id = Autoid,
                x = X,
                y = Y,
                scene = SceneId, 
				unique_key = {SceneId, Autoid}
            },
            ets:insert(?ETS_BASE_SCENE_NPC, N1)
    end,	
    load_base_npc(T, SceneId, Autoid+1).

%% 加载基础_mon
load_base_mon([], _, _) -> ok;
load_base_mon([[MonId, X, Y, Type] | M], SceneId, Autoid) ->
    case data_agent:mon_get(MonId) of
        [] ->
            ok;
        Minfo ->
            NewMinfo = Minfo#ets_mon{
                id = Autoid,
                scene = SceneId,
                x = X,
                y = Y,
                att_type = Type,
				skill = [],
                pid = undefined,
				battle_status = [],
				unique_key = {SceneId, Autoid}
            },
            ets:insert(?ETS_BASE_SCENE_MON, NewMinfo)
    end,	
    load_base_mon(M, SceneId, Autoid + 1).

%% 从地图的mask中构建ETS坐标表，表中存放的是可移动的坐标
%% load_mask(Mask,0,0)，参数1表示地图的mask列表，参数2和3为当前产生的X,Y坐标
load_base_mask([], _, _, _) ->  null;
load_base_mask([H | T], X, Y, SceneId) ->
    case H of
        10 -> % 等于\n
            load_base_mask(T, 0, Y+1, SceneId);
        13 -> % 等于\r
            load_base_mask(T, X, Y, SceneId);
        48 -> % 0
            load_base_mask(T, X+1, Y, SceneId);
        49 -> % 1
            ets:insert(?ETS_BASE_SCENE_POSES, {{SceneId, X, Y}}),
            load_base_mask(T, X+1, Y, SceneId);
        50 -> % 2
            load_base_mask(T, X+1, Y, SceneId);
		51 -> % 2
            load_base_mask(T, X+1, Y, SceneId);
        _Other ->
			load_base_mask(T, X, Y, SceneId)
            %%?ERROR_MSG("Unknown element in scene_mask: ~p", [[Other, X, Y, SceneId]])
    end.

%% 初始化基础副本信息
init_base_dungeon() ->
    F = fun(Dungeon) ->
		D = list_to_tuple([dungeon | Dungeon]),
		DungeonInfo = D#dungeon{
			out = util:string_to_term(tool:to_list(D#dungeon.out)),
			scene = util:string_to_term(tool:to_list(D#dungeon.scene)),
			requirement = util:string_to_term(tool:to_list(D#dungeon.requirement))  
		},				
		ets:insert(?ETS_BASE_DUNGEON, DungeonInfo)
   	end,
	L = db_agent:get_base_dungeon(),
	lists:foreach(F, L),	
	ok.

%% 本节点场景初始化
load_scene(SceneId) ->
	S = data_scene:get(SceneId),
    case S#ets_scene.type =:= 2 orelse S#ets_scene.type =:= 3 of
        true -> %% 副本、帮会的原始场景，就不加载
            ok; 
        false ->
            load_npc(S#ets_scene.npc, SceneId),
            load_mon(S#ets_scene.mon, SceneId),
            ets:insert(?ETS_SCENE, S#ets_scene{id = SceneId, mon=[], npc=[], mask=[]}),
			ok
    end.

%% 本节点加载NPC
load_npc([], _) -> ok;
load_npc([[NpcId, X, Y] | T], SceneId) ->
    mod_npc_create:create_npc([NpcId, SceneId, X, Y]),
    load_npc(T, SceneId).

%% 本节点加载怪物
load_mon(Minfo, SceneId) ->
	Len = length(Minfo),
	NewLen = Len + 20,
	AutoId = mod_mon_create:get_mon_auto_id(NewLen),
	load_mon_loop(Minfo, SceneId, AutoId).
load_mon_loop([], _SceneId, _AutoId) -> 
	ok;
load_mon_loop([[MonId, X, Y, _Type] | M], SceneId, AutoId) ->
	[_MonPid, NewAutoId] = mod_mon_create:create_mon_action(MonId, SceneId, X, Y, 0, [], AutoId),
    load_mon_loop(M, SceneId, NewAutoId).


%% 本节点加载TD mon
load_mon_td({MonId, X, Y, Num}, SceneId) ->
	Len = Num + 20,
	AutoId = mod_mon_create:get_mon_auto_id(Len),
	load_mon_td_loop({MonId, X, Y, Num}, SceneId, AutoId).
load_mon_td_loop({_MonId, _X, _Y, 0}, _SceneId, _AutoId) -> 
	ok;
load_mon_td_loop({MonId, X, Y, Num}, SceneId, AutoId) ->
	RX = X + 7 - random:uniform(12),
	RY = Y + 5 - random:uniform(8),
	[_MonPid, NewAutoId] = mod_mon_create:create_mon_action(MonId, SceneId, RX, RY, 1, [], AutoId),
    load_mon_td_loop({MonId, X, Y, Num - 1}, SceneId, NewAutoId).

%% 本节点加载TD def
load_def_td([MonId, X, Y, Num], SceneId) ->
	Len = Num + 20,
	AutoId = mod_mon_create:get_mon_auto_id(Len),
	load_def_td_loop([MonId, X, Y, Num], SceneId, AutoId).
load_def_td_loop([_MonId, _X, _Y, 0], _SceneId, _AutoId) -> 
	ok;
load_def_td_loop([MonId, X, Y, Num], SceneId, AutoId) ->
	RX = X + 4 - random:uniform(6),
	RY = Y + 4 - random:uniform(6),
	[_MonPid, NewAutoId] = mod_mon_create:create_mon_action(MonId, SceneId, RX, RY, 1, [], AutoId),
    load_def_td_loop([MonId, X, Y, Num - 1], SceneId, NewAutoId).

%% 加载试炼副本mon
load_mon_training([MonId, Num], SceneId) ->
	Len = Num + 20,
	AutoId = mod_mon_create:get_mon_auto_id(Len),
	load_mon_training_loop([MonId, Num], SceneId, AutoId).
load_mon_training_loop([_MonId, 0], _SceneId, _AutoId) -> 
	ok;
load_mon_training_loop([MonId, Num], SceneId, AutoId) ->
	[X, Y] = data_training:get_mon_xy(Num),
	[_MonPid, NewAutoId] = mod_mon_create:create_mon_action(MonId, SceneId, X, Y, 1, [], AutoId),
    load_mon_training_loop([MonId, Num - 1], SceneId, NewAutoId).

%% 加载封神纪元mon
load_mon_era(MonListData,SceneId) ->
	F = fun(DataInfo) ->
				case DataInfo of
					{MonId,Num} ->
						lists:duplicate(Num, {MonId,0,0});
					{MonId,Num,X,Y} ->
						lists:duplicate(Num, {MonId,X,Y})
				end
		end,
	MonList = lists:flatten(lists:map(F, MonListData)),
	Len = length(MonList) + 10,
	AutoId = mod_mon_create:get_mon_auto_id(Len),
	load_mon_era_loop(MonList,SceneId,AutoId).

load_mon_era_loop([],_SceneId,_AutoId) ->
	ok;
load_mon_era_loop([{MonId,X,Y}|L],SceneId,AutoId) ->
	if
		X == 0 ->
			NewX = util:rand(10, 15);
		true ->
			NewX = X
	end,
	if
		Y == 0 ->
			NewY = util:rand(10, 20);
		true ->
			NewY = Y
	end,
	[_MonPid, NewAutoId] = mod_mon_create:create_mon_action(MonId, SceneId, NewX, NewY, 1, [], AutoId),
	load_mon_era_loop(L,SceneId,NewAutoId).

%%本节点加载mon(能够返回怪物进程)紧神岛空战周期刷小怪用
load_mon_retpid([], Result, _) ->
	Result;
load_mon_retpid([[MonId, X, Y, Type, Pid] | T], {Num, RList}, SceneId) ->
	case misc:is_process_alive(Pid) of
		true ->
			MonPid = Pid,
			NewNum = Num,
			skip;
		false ->
			MonAutoId = mod_mon_create:get_mon_auto_id(1),
			[MonPid, _NewAutoId] = mod_mon_create:create_mon_action(MonId, SceneId, X, Y, Type, [], MonAutoId),
			NewNum = Num+1
	end,
	load_mon_retpid(T, {NewNum, [[MonId, X, Y, Type, MonPid]|RList]}, SceneId).

%%加载神魔乱斗怪物
loading_warfare_mon(RNum, MonId, MonAdd, Lv, SceneId) ->
	AutoId = mod_mon_create:get_mon_auto_id(100),
	loading_warfare_mon(RNum, MonId, MonAdd, Lv, SceneId, AutoId).
loading_warfare_mon(0, _MonId, _MonAdd, _Lv, _SceneId, _AutoId) ->
	skip;
loading_warfare_mon(RNum, MonId, MonAdd, Lv, SceneId, AutoId) ->
	[X, Y] = lib_warfare:get_mon_xy(MonId),
%% 	?DEBUG("MonId:~p,RNum:~p SceneId:~p, X:~p, Y:~p", [MonId, RNum, SceneId, X, Y]),
	[_MonPid, NewAutoId] = mod_mon_create:create_mon_action(MonId, SceneId, X, Y, 1, [MonAdd, Lv], AutoId),
	loading_warfare_mon(RNum-1, MonId, MonAdd, Lv, SceneId, NewAutoId).

%% 动态加载圣诞节活动的怪物
load_christmas_mon(MonId, SceneId, Coords) ->
	Len = length(Coords) + 30,
	AutoId = mod_mon_create:get_mon_auto_id(Len),
	load_christmas_mon_loop(MonId, SceneId, AutoId, Coords).
load_christmas_mon_loop(_MonId, _SceneId, _AutoId, []) -> 
	ok;
load_christmas_mon_loop(MonId, SceneId, AutoId, [{Type, {X, Y}}|Coords]) ->
	case Type of
		0 ->
			[_MonPid, NewAutoId] = mod_mon_create:create_mon_action(MonId, SceneId, X, Y, 1, [], AutoId),
			load_christmas_mon_loop(MonId, SceneId, NewAutoId, Coords);
		1 ->
			load_christmas_mon_loop(MonId, SceneId, AutoId, Coords)
	end.
%%初始化开发部怪物的第一个boss
load_robot_mon(MonId, SceneId, {X,Y}) ->
	Len = 20,
	AutoId = mod_mon_create:get_mon_auto_id(Len),
	[_MonPid, _NewAutoId] = mod_mon_create:create_mon_action(MonId, SceneId, X, Y, 1, [], AutoId),
	ok.

%% 复制一个副本场景
%% SceneUniqueId 场景唯一ID
%% SceneResId 场景资源ID
copy_scene(SceneUniqueId, SceneResId) ->
	case data_scene:get(SceneResId) of
        [] ->
            ok;
        S ->
            load_npc(S#ets_scene.npc, SceneUniqueId),
            load_mon(S#ets_scene.mon, SceneUniqueId),
            ets:insert(?ETS_SCENE, S#ets_scene{id = SceneUniqueId, mon = [], npc = [], mask = []}),
            ok
    end.

%% 清除场景
clear_scene(SceneId) ->
    mod_mon_create:clear_scene_mon(SceneId),    										%% 清除怪物 
    ets:match_delete(?ETS_SCENE_NPC, #ets_npc{ scene = SceneId, _ = '_' }),				%% 清除NPC
	ets:match_delete(?ETS_GOODS_DROP, #ets_goods_drop{ scene = SceneId, _ = '_' }),		%% 清除掉落物
    ets:delete(?ETS_SCENE, SceneId).         											%% 清除场景

%% 更改玩家位置
%% Player 玩家信息
%% X 目的点X坐标
%% Y 目的点Y坐标
change_player_position(Player, X, Y) ->	
	%% 走路
	MoveBinData = 
		if 
			Player#player.arena /= 3 ->
				{ok, BinData} = pt_12:write(12001, [X, Y, Player#player.id]),
				BinData;
			%% 竞技场死亡状态
			true ->
				0
		end,
    %% 移除
    {ok, LeaveBinData} = pt_12:write(12004, Player#player.id),
    %% 有玩家进入
    {ok, EnterBinData} = pt_12:write(12003, pt_12:trans_to_12003(Player)),	
	mod_scene_agent:move_broadcast(Player#player.scene, 
								   [Player#player.other#player_other.pid_send,
								   Player#player.other#player_other.pid_send2,
								   Player#player.other#player_other.pid_send3], 
			X, Y, Player#player.x, Player#player.y,Player#player.id,Player#player.status, MoveBinData, LeaveBinData, EnterBinData).

%%	ver_location(Sceneid, [X, Y], Type)
%% 所处位置判断
%% Type为判断类型 （safe 安全区判断 	exc 凝神修炼区判断）
	
ver_location(Sceneid, [X, Y], Type) ->
	SCid0 = 119, 	%%野外竞技场
	SCid1 = 200, 	%%娲皇城
	SCid2 = 250,	%%太昊城
	SCid3 = 280,	%%华阳城
	SCid4 = 100, 	%%新手村
	SCid5 = 300, 	%%九霄
	SCid6 = 101, 	%%雷泽
	SCid62 = 190, 	%%雷泽2
	SCid63 = 191, 	%%雷泽3
	SCid7 = 102, 	%%洛水
	SCid8 = 103, 	%%苍莽林
	SCid9 = 710,	%%诛邪副本一层
	SCid10 = 110,   %%新手村2
	SCid11 = 111,   %%新手村3
	SCid12 = 520,   %%神岛
%% 	SCid13 = ?SPRING_SCENE_NORMAL_ID, 	%%大众温泉
	SCid14 = ?SPRING_SCENE_VIPTOP_ID,		%%VIP温泉
	SCid15 = 214,	%%天涯海角
	SCid16 = 201,%%太昊城城郊
	SCid17 = 251,%%女娲城城郊
	SCid18 = 281, %%华阳城城郊
	SCid19 = ?WARFARE_SCENE_ID,	%%神魔乱斗场景
	SCid20 = ?WEDDING_SCENE_ID, %%婚宴场景
	SCid21 = ?WEDDING_LOVE_SCENE_ID,
	{[Xu,Yu],[Xd,Yd]} = 
	case Sceneid of
		SCid0 ->
				{[28,98],[1,53]};
		SCid1 ->
			case Type of
				safe ->
					{[125.5, 47],[101.5, 240]};
				exc ->
					{[121.5,96],[150.5,152]};		
				_->
					{[0, 0],[0, 0]}
			end;
		SCid2 ->
			case Type of
				safe ->
					{[124.5, 40],[99.5, 238]};
				exc ->
					{[121.5,96],[150.5,152]};	
				_->
					{[0, 0],[0, 0]}
			end;
		SCid3 ->
			case Type of
				safe ->
					{[128.5, 43],[102.5, 241]};
				exc ->
					{[121.5,96],[150.5,152]};		
				_->
					{[0, 0],[0, 0]}
			end;
		Value when Value =:= SCid6 orelse Value =:= SCid62 orelse Value =:= SCid63 ->
				{[113, 231],[89, 195]};
		SCid7 ->
				{[113, 68],[100, 51]};
		SCid8 ->
				{[64, 183],[42, 164]};
		SCid12 ->%%神岛安全区
			{[50,165], [27,134]};
		SCid5 ->%%九霄复活区
			{[70,170], [63,160]};
		SCid16 ->
			{[45,141],[35,131]};
		SCid17 ->
			{[45,141],[35,131]};
		SCid18 ->
			{[45,141],[35,131]};
		SCid19 ->%%神魔乱斗
			{[10, 82],[1, 68]};
		_ ->
			{[0, 0],[0, 0]}
	end,

	Rate1 = 0.984521,
	Rate2 = -1,

	case Sceneid of
		Val when Val =:= SCid0 andalso Type =:= safe ->
			if 
				(X > Xd andalso X < Xu andalso Y > Yd andalso Y < Yu)  ->
				   true;
			   	true ->
				   false
			end;
		Val when Val =:= SCid1 orelse Val =:= SCid2 orelse Val =:= SCid3 ->
			if
				Y > Yu andalso ((Y - Yu)/(X - Xu) >= Rate1 orelse (Y - Yu)/(X - Xu) =< Rate2) ->
					if
						Y < Yd andalso ((Y - Yd)/(X - Xd) >= Rate1 orelse (Y - Yd)/(X - Xd) =< Rate2)->
							true;
						true -> false
					end;
				true -> false					
			end;
		Val when (Val =:= SCid4 orelse Val =:= SCid9 orelse Val =:= SCid10 orelse Val =:= SCid11) andalso Type =:= safe -> 
			true;
		Val when (Val =:= SCid7 orelse Val =:= SCid8)andalso Type =:= safe ->
			if 
				X > Xd andalso X < Xu andalso Y > Yd andalso Y < Yu ->
				   true;
			   	true ->
				   false
			end;
		Val when (Val =:= SCid6 orelse Val =:= SCid62 orelse Val =:= SCid63) andalso Type =:= safe ->
			{[Xu2,Yu2],[Xd2,Yd2]} = {[25,158], [4,127]}, %%第二个安全区
			if 
				(X > Xd andalso X < Xu andalso Y > Yd andalso Y < Yu) orelse 
					(X > Xd2 andalso X < Xu2 andalso Y > Yd2 andalso Y < Yu2)  ->
				   true;
			   	true ->
				   false
			end;
		Val when Val =:= SCid12 andalso Type =:= safe -> %%{[Xu,Yu],[Xd,Yd]}{[66, 164], [45, 142]};
			{[Xu2,Yu2],[Xd2,Yd2]} = {[19,165], [0,133]}, %%第二个安全区{[Xu,Yu],[Xd,Yd]}{[9, 164], [1, 142]}
			if																
				(X > Xd andalso X < Xu andalso Y > Yd andalso Y < Yu) 
				  orelse (X > Xd2 andalso X < Xu2 andalso Y > Yd2 andalso Y < Yu2) ->
					true;
				true ->
					false
			end;
		Val when Val =:= SCid5 ->
			case Type of
				safe ->
					%%蟠桃区
					case lib_peach:is_local_peach(SCid5,[X,Y]) of
						ok->true;
						_->
							{[Xu2,Yu2],[Xd2,Yd2]} = {[51,176], [44,168]}, %%第二个安全区	
							%%复活区{[Xu,Yu],[Xd,Yd]}{[70,170], [63,160]};
							if (X > Xd andalso X < Xu andalso Y > Yd andalso Y < Yu) 
								 orelse (X > Xd2 andalso X < Xu2 andalso Y > Yd2 andalso Y < Yu2) ->
								   true;
							   true ->
								   false
							end
					end;
				_ ->%%%九霄凝神区(与蟠桃重合)
					case lib_peach:is_local_peach(SCid5,[X,Y]) of
						ok->
							true;
						_->
							false
					end
			end;
		Val when Val =:= SCid14 andalso Type =:= safe ->
			true;%%整个温泉场景都是安全区
		Val when Val =:= SCid20 andalso Type =:= safe ->
			true;%%整个婚宴场景都是安全区
		Val when Val =:= SCid21 andalso Type =:= safe ->
			true;
		Val when Val =:= SCid15 andalso Type =:= safe ->
			true;%%天涯海角是安全区
		%%太昊城城郊镖师
		Val when Val =:= SCid16 andalso Type =:= safe ->
			if (X > Xd andalso X < Xu andalso Y > Yd andalso Y < Yu) ->
				   true;
			   true ->
				   false
			end;
		%%女娲城城郊镖师
		Val when Val =:= SCid17 andalso Type =:= safe ->
			if (X > Xd andalso X < Xu andalso Y > Yd andalso Y < Yu) ->
				   true;
			   true ->
				   false
			end;
		%%华阳城城郊镖师
		Val when Val =:= SCid18 andalso Type =:= safe ->
			if (X > Xd andalso X < Xu andalso Y > Yd andalso Y < Yu) ->
				   true;
			   true ->
				   false
			end;
		%%跨服战休息区
		Val when (Val rem 1000=:=760 orelse Val rem 1000=:=730) andalso Type =:= safe ->
			%%纵坐标40以上的为安全区
			if Y > 40 ->true;
			   true->false
			end;
		%%夫妻副本为安全区
		Val when (Val rem 1000=:=918) andalso Type =:= safe ->
			true;
		%%神魔乱斗
		Val when Val =:= SCid19 andalso Type =:= safe ->
			X > Xd andalso X < Xu andalso Y > Yd andalso Y < Yu;
		_ -> 
			false
	end.

%% 是否为封神台场景，UniqueId唯一id，会检查是否存在这个场景
is_fst_scene(UniqueId) ->
    SceneId = UniqueId rem 10000,
	SceneId >= 1001 andalso SceneId=<1030.

is_td_scene(UniqueId) ->
	SceneId = UniqueId rem 10000,
    SceneId =:= 998 orelse SceneId =:= 999.

is_std_scene(UniqueId) ->
	UniqueId rem 10000 =:= 998.

is_mtd_scene(UniqueId) ->
    UniqueId rem 10000 =:= 999.

is_training_scene(UniqueId) ->
	UniqueId rem 10000 =:= 901.
%%是否诛仙台场景 1046~1065
is_zxt_scene(UniqueId) ->
    SceneId = UniqueId rem 10000,
	SceneId >= 1046 andalso SceneId=<1065.

%%是否封神台和诛仙台场景 1001~1076
is_fst_zxt_scene(SceneId)->
	SceneId > 1000 andalso SceneId < 1076.
%%封神台
check_fst_thru(Loc, Used_time) ->
	case Loc<46 of
		true->
			case db_agent:get_fst_god(Loc, 1) of
				[] -> norec;
				[[_Id, Rec_time, _Lv, _Realm, _Career, _Sex, _Light, _Nick, _G_name]] ->
					if 
						Used_time < Rec_time ->
							[Loc];
						true ->
							[]
					end;
				_ ->
					err
			end;
		false->
			check_zxt_thru(Loc-45, Used_time)
	end.


check_zxt_thru(Loc, Used_time) ->
	case db_agent:get_zxt_god(Loc, 1) of
		[] -> norec;
		[[_Id, Rec_time, _Lv, _Realm, _Career, _Sex, _Light, _Nick, _G_name]] ->
			if 
				Used_time < Rec_time ->
					[Loc];
				true ->
					[]
			end;
		_ ->
			err
	end.

%% 进入单人塔防场景条件检查
check_enter_std(Status, SceneId, Scene ,SkipAtt) ->
	%%进入次数
	{Enter,Counter} = lib_dungeon:check_dungeon_times(Status#player.id, SceneId, ?TD_MAXTIMES),
	case SkipAtt of
		19 -> Cost = 5;
		29 -> Cost = 10;
		39 -> Cost = 20;
		_ -> Cost = 0
	end,
	if 
		SkipAtt == 0 andalso Status#player.lv < 33 ->
			{false, 0, 0, 0, <<"等级需达到33级以上!">>, 0, []};
		SkipAtt >= 40 andalso Status#player.lv < 60 ->
			{false, 0, 0, 0, <<"等级需达到60级以上!">>, 0, []};
		SkipAtt >= 30 andalso Status#player.lv < 55 ->
			{false, 0, 0, 0, <<"等级需达到55级以上!">>, 0, []};
		SkipAtt >= 20 andalso Status#player.lv < 45 ->
			{false, 0, 0, 0, <<"等级需达到45级以上!">>, 0, []};
		Status#player.gold < Cost ->
			{false, 0, 0, 0, <<"元宝不足!">>, 0, []};
		Enter == fail andalso SceneId == 998 ->
			Warning = io_lib:format("每天进入镇妖台（单人）不能超过~p次!",[?TD_MAXTIMES]),
			{false, 0, 0, 0,tool:to_binary(Warning), 0, []};
		Enter == false andalso SceneId == 999 ->
			Warning = io_lib:format("每天进入镇妖台（多人）不能超过~p次!",[?TD_MAXTIMES]),
			{false, 0, 0, 0,tool:to_binary(Warning), 0, []};
		Status#player.evil >= 450 ->  %% 红名状态不能进入封神台
			{false, 0, 0, 0, <<"您处于红名状态，不能进入镇妖台!">>, 0, []};
		Status#player.carry_mark >0 andalso Status#player.carry_mark<4 orelse Status#player.carry_mark >=20 andalso Status#player.carry_mark<26->
			{false, 0, 0, 0, <<"运镖状态不能进入镇妖台！">>, 0, []};
		Status#player.carry_mark > 3 andalso Status#player.carry_mark<8 ->
			{false, 0, 0, 0, <<"跑商状态不能进入镇妖台！">>, 0, []};
		Status#player.other#player_other.pid_team =/= undefined ->
			{false, 0, 0, 0, <<"组队状态无法进入镇妖洞窟（单人）！">>, 0, []};
		Status#player.arena > 0 ->
			 {false, 0, 0, 0, <<"战场状态不能进入镇妖台！">>, 0, []};		
		Status#player.scene =:= ?SPRING_SCENE_VIPTOP_ID ->
			{false, 0, 0, 0, <<"在温泉中，不能进入副本">>, 0, []};
		true ->
			%%如果可以进入，则可以获取进入次数
%% 			{pass ,Counter} = Enter ,
			NewCounter = Counter +1 ,
			Now_dungeon_res_id = get_scene_id_from_scene_unique_id(Status#player.scene),
			Dungeon_alive = misc:is_process_alive(Status#player.other#player_other.pid_dungeon),
			if 
				Dungeon_alive, SceneId =:= Now_dungeon_res_id ->
					enter_td_scene(Scene, Status ,NewCounter); %% 已经有副本服务进程         
                true -> %% 还没有副本服务进程
					gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'del_member',[Status#player.id]}),
					Result = mod_td:start(0, self(), SceneId, [{Status#player.id, 
																Status#player.other#player_other.pid,
																Status#player.other#player_other.pid_dungeon}],SkipAtt),
					case Result of 
						{ok, Pid} ->
							Status2 = lib_goods:cost_money(Status,Cost,gold,3540),
							enter_td_scene(Scene, Status2#player{other=Status#player.other#player_other{pid_dungeon = Pid}} ,NewCounter);										
						{fail, Msg} ->
							{false, 0, 0, 0, Msg, 0, []}
					end
			end
	end.

%% 进入多人塔防场景条件检查
check_enter_mtd(Status, SceneId, Scene) ->
	%%进入次数
	{Enter,Counter} = lib_dungeon:check_dungeon_times(Status#player.id, SceneId, ?TD_MAXTIMES),
	if 
		Enter == fail andalso SceneId == 998 ->
			Warning = io_lib:format("每天进入镇妖台（单人）不能超过~p次!",[?TD_MAXTIMES]),
			{false, 0, 0, 0,tool:to_binary(Warning), 0, []};
		Enter == fail andalso SceneId == 999 ->
			Warning = io_lib:format("每天进入镇妖台（多人）不能超过~p次!",[?TD_MAXTIMES]),
			{false, 0, 0, 0,tool:to_binary(Warning), 0, []};
		Status#player.evil >= 450 ->  %% 红名状态不能进入封神台
			{false, 0, 0, 0, <<"您处于红名状态，不能进入镇妖台!">>, 0, []};
		Status#player.carry_mark >0 andalso Status#player.carry_mark<4 orelse (Status#player.carry_mark >=20 andalso Status#player.carry_mark<26) ->
			{false, 0, 0, 0, <<"运镖状态不能进入镇妖台！">>, 0, []};
		Status#player.carry_mark >3 andalso Status#player.carry_mark<8 ->
			{false, 0, 0, 0, <<"跑商状态不能进入镇妖台！">>, 0, []};
		Status#player.other#player_other.pid_team =:= undefined ->
			{false, 0, 0, 0, <<"非组队状态无法进入镇妖洞窟（多人）！">>, 0, []};
		Status#player.arena > 0 ->
			 {false, 0, 0, 0, <<"战场状态不能进入镇妖台！">>, 0, []};
		Status#player.scene =:= ?SPRING_SCENE_VIPTOP_ID ->
			{false, 0, 0, 0, <<"在温泉中，不能进入副本">>, 0, []};
		true ->
			%%如果可以进入，则可以获取进入次数
%% 			{pass ,Counter} = Enter ,
			NewCounter = Counter + 1,
			Now_dungeon_res_id = get_scene_id_from_scene_unique_id(Status#player.scene),
			Dungeon_alive = misc:is_process_alive(Status#player.other#player_other.pid_dungeon),
			if 
				Dungeon_alive, SceneId =:= Now_dungeon_res_id ->
					enter_td_scene(Scene, Status ,NewCounter); %% 已经有副本服务进程
                true -> %% 还没有副本服务进程
					Result = 
						case misc:is_process_alive(Status#player.other#player_other.pid_team) of
							false -> %% 非组队状态无法进入镇妖洞窟（多人）
								{false, 0, 0, 0, <<"非组队状态无法进入镇妖洞窟（多人）！">>, 0, []};
							true -> %% 有队伍且是队长，由队伍进程创建副本服务器
								%% io:format("Here_5_ ~p ~n",[Status#player.other#player_other.pid_dungeon]),
                              	mod_team:create_td(Status#player.other#player_other.pid_team, self(), 
													SceneId, [
															  SceneId,
															  Status#player.id, 
															  Status#player.other#player_other.pid,
															  Status#player.other#player_other.pid_dungeon
															 ])
						end,
					case Result of 
						{ok, Pid} ->
							enter_td_scene(Scene, Status#player{other=Status#player.other#player_other{pid_dungeon = Pid}} ,NewCounter);										
						{fail, Msg} ->
							{false, 0, 0, 0, Msg, 0, []}
					end
			end
	end.

%% 进入塔防副本场景
enter_td_scene(Scene, Status ,Counter) ->
    case mod_td:check_enter(Scene#ets_scene.sid, Scene#ets_scene.type, Status#player.other#player_other.pid_dungeon) of
        {false, Msg} ->
            {false, 0, 0, 0, Msg, 0, []};
        {true, UniqueId} ->
            DungeonSceneId = get_scene_id_from_scene_unique_id(Status#player.scene),
			case data_scene:get(DungeonSceneId) of
           		[]  -> 
					mod_td:rm_player_byscid(UniqueId, Status#player.id),
                    {false, 0, 0, 0, <<"场景出错_2!">>, 0, []};
                S ->
					 lib_activity:update_activity_data_cast(td, Status#player.other#player_other.pid, 1),%%添加玩家活跃度统计
					%% 成功进入更新进入副本次数
					lib_dungeon:add_dungeon_times(Status#player.id, Scene#ets_scene.sid),
                    %%进入副本场景卸下坐骑
                    {ok, NewStatus} = lib_goods:force_off_mount(Status),
					%% 更新人物延时保存信息
					mod_delayer:update_delayer_info(NewStatus#player.id, NewStatus#player.other#player_other.pid_dungeon, NewStatus#player.other#player_other.pid_fst, NewStatus#player.other#player_other.pid_team),
					Msg= io_lib:format("您的队友~s进入了~s",[NewStatus#player.nickname, Scene#ets_scene.name]),
					{ok,TeamBinData} = pt_15:write(15055,[Msg]),
					gen_server:cast(NewStatus#player.other#player_other.pid_team,
													{'SEND_TO_OTHER_MEMBER', NewStatus#player.id, TeamBinData}),
                    case [{X, Y} || [_Index, Id0, _Name, X, Y] <- Scene#ets_scene.elem, Id0 =:= S#ets_scene.sid] of
                         [] -> 
                             {true, UniqueId, Scene#ets_scene.x, Scene#ets_scene.y, Scene#ets_scene.name, 998, Counter, ?TD_MAXTIMES, NewStatus};
                         [{X, Y}] -> 
                             {true, UniqueId, X, Y, Scene#ets_scene.name, 998, Counter, ?TD_MAXTIMES, NewStatus}
                    end
             end
    end.


%% 判断上一个切换场景的位置
%% Player 玩家Record
%% SceneId 切换的场景
%% check_change_scene(Player, SceneId) ->
%% 	case lists:member(Player#player.scene, [101, 190, 191]) andalso lists:member(SceneId, [101, 190, 191]) of
%% 		false ->
%%             NewSceneId = 
%%                 case SceneId == 191 orelse SceneId == 190 of
%%                     true ->
%%                         101;
%%                     false ->
%%                         SceneId
%%                 end,
%% 			case data_scene:get(Player#player.scene) of
%%                 [] ->
%%                     true;
%%                 Scene ->
%%                     case [{X, Y} || [_Index, Id, _Name, X, Y] <- Scene#ets_scene.elem, Id =:= NewSceneId] of
%%                         [] ->
%% 							true;
%%                         [{X, Y}] ->
%%                             case abs(Player#player.x - X) + abs(Player#player.y - Y) > 10 of
%%                                 true ->
%%                                     %% 切换场景异常
%%                                     %Now = util:unixtime(),
%%                                     %spawn(fun()-> db_agent:insert_kick_off_log(Player#player.id, Player#player.nickname, 9, Now, Player#player.scene, Player#player.x, Player#player.y) end),
%%                                     mod_player:stop(Player#player.other#player_other.pid, 2),
%%                                     false;
%%                                 false ->
%%                                     true
%%                             end
%%                     end
%%             end;
%% 		true ->
%% 			true
%% 	end.

%% 更新玩家的坐标信息
update_player_position(PlayerId, X, Y, Sta) ->
   	case ets:lookup(?ETS_ONLINE_SCENE, PlayerId) of
   		[] -> 
			skip;
  		[Player | _] ->
			NewPlayer = Player#player{
				x = X,
				y = Y,
				status = Sta						  
			},
			ets:insert(?ETS_ONLINE_SCENE, NewPlayer)
    end.

%% 更新玩家场景信息
update_player_info_fields(PlayerId, ValueList) ->
	case ets:lookup(?ETS_ONLINE_SCENE,PlayerId) of
		[] -> 
			skip;
		[Player|_] ->
			NewPlayer = lib_player_rw:set_player_info_fields(Player, ValueList),
			ets:insert(?ETS_ONLINE_SCENE, NewPlayer)
	end.

%% 更新玩家场景信息
update_player_info_fields_for_battle(PlayerId, Hp, Mp) ->
	case ets:lookup(?ETS_ONLINE_SCENE, PlayerId) of
		[] ->
			skip;
		[Player | _] ->
			Sta = 
				if
					Player#player.status == 0 ->
						2;
					true ->
						Player#player.status
				end,
			NewPlayer = Player#player{
				hp = Hp,
				mp = Mp,
				status = Sta						  
			},
			ets:insert(?ETS_ONLINE_SCENE, NewPlayer)
	end.

%% 进入挂机场景
enter_hooking_scene(PlayerStatus,SceneId)->
	case lists:member(SceneId, [300 | data_scene:get_hook_scene_list()]) of
		false->{false,2};%%进入的不是挂机场景
		true->
			if 
				PlayerStatus#player.scene =:= SceneId ->
					{false,3};%%当前已经在该场景
			   	true->
					
				   	State = lib_deliver:could_deliver(PlayerStatus),
				   	case lists:member(State,[ok,17,21]) of 
						true ->
						  	if 
								%% 30级以下不能进入挂机场景
								PlayerStatus#player.lv<30 ->
									{false,4};
							  	true->
									case check_open_time(SceneId) of
										ok->
											case data_scene:get(SceneId) of
											  	[]->
													{false,5};
											  	SceneInfo->
												  	{X,Y} = get_hook_scene_xy(SceneInfo#ets_scene.elem,SceneInfo#ets_scene.x,SceneInfo#ets_scene.y),
												  	NewPlayerStatus=lib_deliver:deliver(PlayerStatus,SceneId,X,Y,4),
												  	{true,NewPlayerStatus}
										  	end;
										{_,Error}->
											{false,Error}
									end
						   	end;
						false ->
							{false,State}
				   	end
			end
	end.
get_hook_scene_xy([],X1,Y1)->
	{X1,Y1};
get_hook_scene_xy([[_Index, _Id, Name, X, Y]|T], X1, Y1)->
	case Name =:= tool:to_binary("进出挂机区" )of
		true->{X,Y};
		false->get_hook_scene_xy(T,X1,Y1)
	end.

check_open_time(SceneId)->
	if SceneId =:=300->
		   ok;
	   true->
		   case lib_hook:is_open_hooking_scene() of
			   opening->ok;
			   early->{false,6};
			   late->{false,7}
		   end
	end.
set_hooking_state(PlayerStatus, SceneId)->
	HookSceneList = data_scene:get_hook_scene_list(),
	case lists:member(SceneId, [300 | HookSceneList]) of
		true->
			case lists:member(PlayerStatus#player.scene, HookSceneList) of
				true->
					gen_server:cast(PlayerStatus#player.other#player_other.pid,{'end_hooking',PlayerStatus#player.scene});
				false->skip
			end,
			case SceneId =/= 300 of
				true->
					gen_server:cast(PlayerStatus#player.other#player_other.pid,{'start_hooking',SceneId});
				false->skip
			end;
		false->
			case lists:member(PlayerStatus#player.scene, HookSceneList) of
				true->
					gen_server:cast(PlayerStatus#player.other#player_other.pid,{'end_hooking',PlayerStatus#player.scene});
				false->skip
			end
	end.


%%进入试炼副本检查
check_enter_training(Status, SceneId, Scene) ->
	{Enter,Counter} = lib_dungeon:check_dungeon_times(Status#player.id,SceneId, 1),
	if
		Enter == fail andalso SceneId == 901 ->
			{false, 0, 0, 0, <<"每天进试炼副本不能超过1次！">>, 0, []};
		Status#player.arena > 0 ->
			{false, 0, 0, 0, <<"战场状态不能进入副本！">>, 0, []};
		Status#player.carry_mark >0 andalso Status#player.carry_mark<4 orelse (Status#player.carry_mark >=20 andalso Status#player.carry_mark<26)->
			{false, 0, 0, 0, <<"运镖状态不能进入副本！">>, 0, []};
		Status#player.carry_mark >3 andalso Status#player.carry_mark<8->
			{false, 0, 0, 0, <<"跑商状态不能进入副本！">>, 0, []};
		Status#player.scene =:= ?SPRING_SCENE_VIPTOP_ID ->
			{false, 0, 0, 0, <<"在温泉中，不能进入副本">>, 0, []};
		true ->
%% 			{pass ,Counter} = Enter ,
			NewCounter = Counter + 1,
			Now_dungeon_res_id = get_scene_id_from_scene_unique_id(Status#player.scene),
			Dungeon_alive = misc:is_process_alive(Status#player.other#player_other.pid_dungeon),
			if 
				Dungeon_alive, SceneId =:= Now_dungeon_res_id ->  %% 已经有副本服务进程并且是在试炼副本
					enter_training_scene(Scene, Status ,NewCounter); 
				Dungeon_alive, SceneId /= Now_dungeon_res_id ->  %% 已经有副本服务进程但不是在试炼副本，先移除并清理
					mod_training:quit(Status#player.other#player_other.pid_dungeon, Status#player.id, 0),
					mod_training:clear(Status#player.other#player_other.pid_dungeon),
					{false, 0, 0, 0, <<"旧副本已退出，请重试!">>, 0, []};
                true -> %% 还没有副本服务进程
					Result = 
						case misc:is_process_alive(Status#player.other#player_other.pid_team) of
							false -> %%没有队伍则自己创建
								case mod_training:start(undefined, self(), SceneId, {Status#player.id,Status#player.other#player_other.pid,Status#player.lv}) of 
									{ok,T_pid} ->
										gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'del_member',[Status#player.id]}),
										{ok,T_pid};
									_Err ->
										{fail, <<"进入试炼副本失败!">> }
								end;
							true -> %% 有队伍且是队长，由队伍进程创建副本服务器
								%% io:format("Here_5_ ~p ~n",[Status#player.other#player_other.pid_dungeon]),
                              	mod_team:create_training(Status#player.other#player_other.pid_team, self(), 
													SceneId, [Status#player.id, 
													Status#player.other#player_other.pid,
													Status#player.lv])
						end,
					case Result of 
						{ok, Pid} ->
							lib_activity:update_activity_data_cast(train, Status#player.other#player_other.pid, 1),%%添加玩家活跃度统计
							enter_training_scene(Scene, Status#player{other=Status#player.other#player_other{pid_dungeon = Pid}},NewCounter);										
						{fail, Msg} ->
							{false, 0, 0, 0, Msg, 0, []}
					end
			end
	end.

%%进入试炼副本
enter_training_scene(Scene,Status,Counter) ->
	case mod_training:check_enter(Scene#ets_scene.sid, Scene#ets_scene.type, Status#player.other#player_other.pid_dungeon) of
		{false, Msg} ->
            {false, 0, 0, 0, Msg, 0, []};
		{true, UniqueId} ->	
			%% 成功进入更新进入副本次数
			lib_dungeon:add_dungeon_times(Status#player.id, Scene#ets_scene.sid),
            %% 进入副本场景卸下坐骑
            {ok, NewStatus} = lib_goods:force_off_mount(Status),
			%% 更新人物延时保存信息
			mod_delayer:update_delayer_info(NewStatus#player.id, NewStatus#player.other#player_other.pid_dungeon, NewStatus#player.other#player_other.pid_fst, NewStatus#player.other#player_other.pid_team),
			Msg= io_lib:format("您的队友~s进入了~s",[NewStatus#player.nickname, Scene#ets_scene.name]),
			{ok,TeamBinData} = pt_15:write(15055,[Msg]),
			%% 加入副本
			mod_training:join(Status#player.other#player_other.pid_dungeon, [Status#player.id,Status#player.other#player_other.pid,Status#player.lv]),
			%%是否需要传送其他队友
			gen_server:cast(NewStatus#player.other#player_other.pid_team,{'SEND_TO_OTHER_MEMBER', NewStatus#player.id, TeamBinData}),
            case [{X, Y} || [_Index, Id0, _Name, X, Y] <- Scene#ets_scene.elem, Id0 =:= Scene#ets_scene.sid] of
                 [] -> 
                     {true, UniqueId, Scene#ets_scene.x, Scene#ets_scene.y, Scene#ets_scene.name, Scene#ets_scene.sid, Counter, 1, NewStatus};
                 [{X, Y}] -> 
                     {true, UniqueId, X, Y, Scene#ets_scene.name, Scene#ets_scene.sid, Counter, 1, NewStatus}
            end
	end.

%% 获取场景用户ID
get_scene_player_id(SceneId) ->
	MS = ets:fun2ms(fun(P) when P#player.scene == SceneId -> 
  		P#player.id			             
	end),
	ets:select(?ETS_ONLINE_SCENE, MS).


%%检查进入封神纪元
check_enter_era(Status,SceneId,Scene) ->
	if
		Status#player.arena > 0 ->
			{false, 0, 0, 0, <<"战场状态不能进入封神纪元！">>, 0, []};
		Status#player.carry_mark >0 andalso Status#player.carry_mark<4 orelse (Status#player.carry_mark >=20 andalso Status#player.carry_mark<26)->
			{false, 0, 0, 0, <<"运镖状态不能进入封神纪元！">>, 0, []};
		Status#player.carry_mark >3 andalso Status#player.carry_mark<8->
			{false, 0, 0, 0, <<"跑商状态不能进入封神纪元！">>, 0, []};
		Status#player.scene =:= ?SPRING_SCENE_VIPTOP_ID ->
			{false, 0, 0, 0, <<"在温泉中，不能进入封神纪元">>, 0, []};
		Status#player.other#player_other.pid_team =/= undefined ->
			{false, 0, 0, 0, <<"组队状态不能进入封神纪元！">>, 0, []};
		true ->
			IsAlreadyInEra = lib_era:is_era_scene(Status#player.scene),
			Now_dungeon_res_id = get_scene_id_from_scene_unique_id(Status#player.scene),
			Dungeon_alive = misc:is_process_alive(Status#player.other#player_other.pid_dungeon),
			Stage = lib_era:scene_to_stage(SceneId),
			MaxStage = lib_era:find_max_stage_by_playerid(Status#player.id),
			Is_passed_stage = lib_era:is_passed_stage(Status#player.id, Stage),
			IsWarServer = lib_war:is_war_server(),
			CouldDeliver = lib_deliver:could_deliver(Status),
			if
				Status#player.lv < 30 andalso (Stage /= 30 orelse (Stage == 30 andalso  Is_passed_stage == true))  ->
					{false, 0, 0, 0, <<"您的等级不足30级！">>, 0, []};
				Stage > MaxStage ->
					{false, 0, 0, 0, <<"该关卡未达到开启条件!">>, 0, []};
				IsAlreadyInEra ->
					{false,0,0,0,<<"已经在封神纪元">>,0,[]};
				CouldDeliver /= ok ->
					{false, 0, 0, 0, <<"当前场景不能进入封神纪元!">>, 0, []};
				Dungeon_alive, SceneId =:= Now_dungeon_res_id ->
					{false, 0, 0, 0, <<"已经在封神纪元，迟点送你进来!">>, 0, []};
				IsWarServer->
					{false, 0, 0, 0, <<"跨服活动不能进入封神纪元!">>, 0, []};
				Dungeon_alive, SceneId /= Now_dungeon_res_id ->  %% 已经有副本服务进程但不是在试炼副本，先移除并清理
					mod_era:quit(Status#player.other#player_other.pid_dungeon, Status#player.id, 0),
					mod_era:clear(Status#player.other#player_other.pid_dungeon),
					{false, 0, 0, 0, <<"旧副本已退出，请重试!">>, 0, []};
				true ->
					Result = 
						case mod_era:start(undefined, self(), SceneId, {
																		Status#player.id,
																		Status#player.other#player_other.pid,
																		Status#player.other#player_other.pid_dungeon,
																		Status#player.nickname,
																		Status#player.scene,
																		Status#player.x,
																		Status#player.y
																	   }) of 
							{ok,T_pid} ->
								{ok,T_pid};
							_Err ->
								{fail, <<"进入封神纪元失败!">> }
						end,
					case Result of
						{ok, Pid} ->
							enter_era_scene(Scene, Status#player{other=Status#player.other#player_other{pid_dungeon = Pid}});										
						{fail, Msg} ->
							{false, 0, 0, 0, Msg, 0, []}
					end
			end
	end.
enter_era_scene(Scene,Status)->
	case mod_era:check_enter(Scene#ets_scene.sid, Scene#ets_scene.type, Status#player.other#player_other.pid_dungeon) of
		{false, Msg} ->
            {false, 0, 0, 0, Msg, 0, []};
		{true, UniqueId} ->	
			%%参与封神纪元任务
			lib_task:event(fs_era, null, Status),
			%% 更新人物延时保存信息
			mod_delayer:update_delayer_info(Status#player.id, Status#player.other#player_other.pid_dungeon, Status#player.other#player_other.pid_fst, Status#player.other#player_other.pid_team),
			case [{X, Y} || [_Index, Id0, _Name, X, Y] <- Scene#ets_scene.elem, Id0 =:= Scene#ets_scene.sid] of
                 [] -> 
                     {true, UniqueId, Scene#ets_scene.x, Scene#ets_scene.y, Scene#ets_scene.name, Scene#ets_scene.sid, 0, 1, Status};
                 [{X, Y}] -> 
                     {true, UniqueId, X, Y, Scene#ets_scene.name, Scene#ets_scene.sid, 0, 1, Status}
            end
	end.
					
check_enter_coulpe_scene(Status,SceneId,Scene)->
	{Enter,Counter} = lib_dungeon:check_dungeon_times(Status#player.id,SceneId, 100),
	if
		Enter == fail andalso SceneId == 918 ->
			{false, 0, 0, 0, <<"每天进夫妻副本不能超过1次！">>, 0, []};
		Status#player.couple_name == [] ->
			{false, 0, 0, 0, <<"您还没有结婚，不能进入夫妻副本！">>, 0, []};
		Status#player.arena > 0 ->
			{false, 0, 0, 0, <<"战场状态不能进入夫妻副本！">>, 0, []};
		Status#player.carry_mark >0 andalso Status#player.carry_mark<4 orelse (Status#player.carry_mark >=20 andalso Status#player.carry_mark<26)->
			{false, 0, 0, 0, <<"运镖状态不能进入夫妻副本！">>, 0, []};
		Status#player.carry_mark >3 andalso Status#player.carry_mark<8->
			{false, 0, 0, 0, <<"跑商状态不能进入夫妻副本！">>, 0, []};
		Status#player.scene =:= ?SPRING_SCENE_VIPTOP_ID ->
			{false, 0, 0, 0, <<"在温泉中，不能进入夫妻副本！">>, 0, []};
		Status#player.other#player_other.pid_team == undefined ->
			{false, 0, 0, 0, <<"非组队状态不能进入夫妻副本！">>, 0, []};
		true ->
			NewCounter = Counter + 1,
			Now_dungeon_res_id = get_scene_id_from_scene_unique_id(Status#player.scene),
			Dungeon_alive = misc:is_process_alive(Status#player.other#player_other.pid_dungeon),
			if 
				Dungeon_alive, SceneId =:= Now_dungeon_res_id ->  %% 已经有副本服务
					enter_couple_scene(Status,Scene ,NewCounter); 
				true -> %% 还没有副本服务进程
					case mod_team:create_couple_dungeon(Status#player.other#player_other.pid_team, self(), 
														SceneId, Status#player.couple_name,[SceneId,Status#player.id, 
																							Status#player.other#player_other.pid,
																							Status#player.lv]) of
						{ok,Pid}->
							enter_couple_scene(Status#player{other=Status#player.other#player_other{pid_dungeon = Pid}},Scene,NewCounter);
						{fail,Msg}->
							{false, 0, 0, 0, Msg, 0, []}
					end
			end
	end.

%%进入夫妻副本
enter_couple_scene(Status,Scene,NewCounter)->
	case mod_couple_dungeon:check_enter(Scene#ets_scene.sid, Scene#ets_scene.type, Status#player.other#player_other.pid_dungeon) of
		{false, Msg} ->
            {false, 0, 0, 0, Msg, 0, []};
		{true, UniqueId} ->	
			%% 成功进入更新进入副本次数
			lib_dungeon:add_dungeon_times(Status#player.id, Scene#ets_scene.sid),
            %% 进入副本场景卸下坐骑
            {ok, NewStatus} = lib_goods:force_off_mount(Status),
			%% 更新人物延时保存信息
			mod_delayer:update_delayer_info(Status#player.id, Status#player.other#player_other.pid_dungeon, Status#player.other#player_other.pid_fst, Status#player.other#player_other.pid_team),
			case [{X, Y} || [_Index, Id0, _Name, X, Y] <- Scene#ets_scene.elem, Id0 =:= Scene#ets_scene.sid] of
                 [] -> 
                     {true, UniqueId, Scene#ets_scene.x, Scene#ets_scene.y, Scene#ets_scene.name, Scene#ets_scene.sid, NewCounter, 1, NewStatus};
                 [{X, Y}] -> 
                     {true, UniqueId, X, Y, Scene#ets_scene.name, Scene#ets_scene.sid, NewCounter, 1, NewStatus}
            end
	end.