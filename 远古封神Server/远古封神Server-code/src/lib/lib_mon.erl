%%%-----------------------------------
%%% @Module  : lib_mon
%%% @Author  : ygzj
%%% @Created : 2010.10.06
%%% @Description: 怪物
%%%-----------------------------------
-module(lib_mon).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("guild_info.hrl").
-export(
    [
	 	init_base_mon/0,
	 	get_mon/2,
		get_player/2,
		get_mon_att_object/5,
        get_name_by_mon_id/1,
        get_scene_by_mon_id/1,
        trace_line/5,
		attack_move/4,
		back/4,
		revive/4,
		trace_action/5,
		mon_die/5,
		conjure_mon/6,
		destory_conjure_mon/2,
		battle/10,
		conjure_after_die/4,
		energy_explode_user/2,
		battle_result/10,
		is_boss_mon/1,
		dynamic_create_mon/4,
		is_alive_scene_mon/1,
		is_alive_scene_mon/3,
		is_alive_scene_flag/2,
		del_mon_data/2,
		check_wild_boss_time/2,
		wild_boss_revive_broadcast/2,
		wild_boss_action/0,
		era_blood_relation/6,
		era_sky_relation/5
    ]
).

%% 初始化基础Mon
init_base_mon() ->
    F = fun(Mon) ->
		M = list_to_tuple([ets_mon | Mon]),
		MonInfo = M#ets_mon{					 	
 			skill = util:string_to_term(tool:to_list(M#ets_mon.skill)),
			x = util:string_to_term(tool:to_list(M#ets_mon.x)),
			y = util:string_to_term(tool:to_list(M#ets_mon.y)),
			relation = util:string_to_term(tool:to_list(M#ets_mon.relation))
		},	
  		ets:insert(?ETS_BASE_MON, MonInfo)
	end,
	L = db_agent:get_base_mon(),
	lists:foreach(F, L),
	ok.

%% 获取一个实际的Mon
get_mon(MonId, SceneId) ->
   	MS = ets:fun2ms(fun(M) when M#ets_mon.id == MonId, M#ets_mon.hp > 0, M#ets_mon.scene == SceneId -> M end),
   	case ets:select(?ETS_SCENE_MON, MS)	of
  		[] -> 
			[];
   		[Minfo | _] ->
			Minfo
    end.

%% 获取场景一个人物
get_player(PlayerId, SceneId) ->
	MS = ets:fun2ms(fun(P) when P#player.id == PlayerId, P#player.hp > 0, P#player.scene == SceneId -> P end),
   	case ets:select(?ETS_ONLINE_SCENE, MS) of
   		[] -> 
			[];
  		[Player | _] ->
			Player
    end.

%% 获取怪物攻击目标
get_mon_att_object(_MonName, _MonType, AttType, Id, SceneId) ->
	if
		AttType == 1 ->
			case get_mon(Id, SceneId) of
				[] ->
					[];
				Mon ->
					[Mon, Mon#ets_mon.hp, Mon#ets_mon.x, Mon#ets_mon.y]
			end;
		true ->
			case get_player(Id, SceneId) of
				[] ->
					[];
				Player ->
					[Player, Player#player.hp, Player#player.x, Player#player.y]
			end
	end.
	

%% 获取当前场景某类Mon信息
get_scene_by_mon_id(MonId) ->
	MS = ets:fun2ms(fun(T) when T#ets_mon.mid == MonId  andalso T#ets_npc.scene /= 99992-> 
		[
      		T#ets_mon.scene,
     		T#ets_mon.x,
      		T#ets_mon.y		 
		] 
	end),
   	case ets:select(?ETS_BASE_SCENE_MON, MS) of	
  		[] -> 
			0;
		Info ->
			Info
	end.

%% 获取mon名称用mon数据库id
get_name_by_mon_id(MonId)->
	case data_agent:mon_get(MonId) of
   		[] -> 
			<<"">>;
 		Mon -> 
			Mon#ets_mon.name
	end.

%% 先进入曼哈顿距离遇到障碍物再转向A*
%% 每次移动2格
%% MX,MY -> 怪物坐标
%% PX,PY -> 玩家坐标
%% @spec trace_line(MX, MY, PX, PY, AttArea) -> true | [X, Y]
trace_line(MX, MY, PX, PY, AttArea) ->
    MoveArea = 2,
    %% 先判断方向
    if
        %% 目标在正下方
        PX == MX andalso PY - MY > 0 ->
            Y = PY - MY,
            case Y =< MoveArea of
                true ->
                    {MX, PY - AttArea};
                false ->
                    {MX, MY + MoveArea}
            end;

        %% 目标在正上方
        PX == MX andalso PY - MY < 0 ->
            Y = MY - PY,
            case Y =< MoveArea of
                true ->
                    {MX, PY + AttArea};
                false ->
                    {MX, MY - MoveArea}
            end;

        %% 目标在正左方
        PX - MX < 0 andalso PY == MY ->
            X = MX - PX,
            case X =< MoveArea of
                true ->
                    {PX + AttArea, MY};
                false ->
                    {MX - MoveArea, MY}
            end;

        %% 目标在正右方
        PX - MX > 0 andalso PY == MY ->
            X = PX - MX,
            case X =< MoveArea of
                true ->
                    {PX - AttArea, MY};
                false ->
                    {MX + MoveArea, MY}
            end;

        %% 目标在左上方
        PX - MX < 0 andalso PY - MY < 0 ->
            Y = MY - PY,
            X = MX - PX,
            case Y =< MoveArea of
                true ->
                    case X < MoveArea of
                        true ->
                            {PX + AttArea, PY + AttArea};
                        false ->
                            {MX - MoveArea, PY + AttArea}
                    end;
                false ->
                    case X < MoveArea of
                        true ->
                            {PX + AttArea, MY - MoveArea};
                        false ->
                            {MX - MoveArea, MY - MoveArea}
                    end
            end;

        %% 目标在左下方
        PX - MX < 0 andalso PY - MY > 0 ->
            Y = PY - MY,
            X = MX - PX,
            case Y =< MoveArea of
                true ->
                    case X < MoveArea of
                        true ->
                            {PX + AttArea, PY - AttArea};
                        false ->
                            {MX - MoveArea, PY - AttArea}
                    end;
                false ->
                    case X < MoveArea of
                        true ->
                            {PX + AttArea, MY + MoveArea};
                        false ->
                            {MX - MoveArea, MY + MoveArea}
                    end
            end;

        %% 目标在右上方
        PX - MX > 0 andalso PY - MY < 0 ->
            Y = MY - PY,
            X = PX - MX,
            case Y =< MoveArea of
                true ->
                    case X < MoveArea of
                        true ->
                            {PX - AttArea, PY + AttArea};
                        false ->
                            {MX + MoveArea, PY + AttArea}
                    end;
                false ->
                    case X < MoveArea of
                        true ->
                            {PX - AttArea, MY - MoveArea};
                        false ->
                            {MX + MoveArea, MY - MoveArea}
                    end
            end;

        %% 目标在右下方
        PX - MX > 0 andalso PY - MY > 0 ->
            Y = PY - MY,
            X = PX - MX,
            case Y =< MoveArea of
                true ->
                    case X < MoveArea of
                        true ->
                            {PX - AttArea, PY - AttArea};
                        false ->
                            {MX + MoveArea, PY - AttArea}
                    end;
                false ->
                    case X < MoveArea of
                        true ->
                            {PX - AttArea, MY + MoveArea};
                        false ->
                            {MX + MoveArea, MY + MoveArea}
                    end
            end;

        true ->
            true
    end.

%% 移动
%% Minfo 怪物信息
%% BattleLimit 战斗限制
%% X 目的点的X坐标
%% Y 目的点的Y坐标
attack_move(Minfo, BattleLimit, X, Y) ->
	%% 判断有没有定身或昏迷
	case (BattleLimit == 0 orelse BattleLimit == 3) andalso Minfo#ets_mon.speed > 0 of
        true ->                       
            lib_scene:mon_move(X, Y, Minfo#ets_mon.id, Minfo#ets_mon.scene, Minfo#ets_mon.speed),
            NewMinfo = Minfo#ets_mon{
                x = X,
                y = Y
            },
            ets:insert(?ETS_SCENE_MON, NewMinfo),
            Interval = get_mon_walk_time(Minfo, X, Y),			
            [NewMinfo, Interval];
        false ->
            [Minfo, 1000]
    end.

%% 返回
%% Minfo 怪物信息
%% BattleLimit 战斗限制
back(Mon, BattleLimit, DX, DY) ->
	%% 判断有没有定身或昏迷
	case (BattleLimit == 0 orelse BattleLimit == 3) andalso Mon#ets_mon.speed > 0 of
        true ->
			case lists:member(Mon#ets_mon.type, [38,39]) of%%神魔乱斗的小怪，boss
				false ->
					Minfo = Mon#ets_mon{
										hp = Mon#ets_mon.hp_lim,
										mp = Mon#ets_mon.mp_lim,
										battle_status = []			
									   };
				true ->%%不回血
					Minfo = Mon#ets_mon{battle_status = []}
			end,
			ADX = abs(Minfo#ets_mon.x - DX),
			ADY = abs(Minfo#ets_mon.y - DY),
            case ADX < 3 andalso ADY < 3 of
                false ->
                    [X, Y] = 
                        case trace_line(Minfo#ets_mon.x, Minfo#ets_mon.y, DX, DY, Minfo#ets_mon.att_area) of
                            [XX, YY] ->
                                [XX, YY];
                            _ ->
                                [DX, DY]
                        end,
					MonSta = 
						case ADX < 5 orelse ADY < 5 of
							true ->
								0;
							false ->
								1
						end,
                    NewMinfo = Minfo#ets_mon{
                        x = X,
                        y = Y,                  
                        status = MonSta
                    },
                    lib_scene:mon_move(X, Y, NewMinfo#ets_mon.id, NewMinfo#ets_mon.scene, Minfo#ets_mon.speed),
                    ets:insert(?ETS_SCENE_MON, NewMinfo),
                    Interval = get_mon_walk_time(Minfo, X, Y),
                    NewInterval = 
                  		if
							Interval > 1000 ->
                                Interval;
                         	true ->
                                1000
                        end,
                    {back, NewMinfo, NewInterval};							
                true ->
                    NewMinfo = Minfo#ets_mon{
                   		status = 0
                    },
                    {ok, BinData} = pt_12:write(12081, [NewMinfo#ets_mon.id, NewMinfo#ets_mon.hp]),
					lib_send:send_to_online_scene(NewMinfo#ets_mon.scene, Minfo#ets_mon.x, Minfo#ets_mon.y, BinData),
                    ets:insert(?ETS_SCENE_MON, NewMinfo),
                    {sleep, NewMinfo, 1000}
            end;  
        false ->
            {sleep, Mon, 1000}
    end.

%% 获取怪物行到目的点的时间
%% Minfo 怪物信息
%% X 目的点的X坐标
%% Y 目的点的Y坐标
get_mon_walk_time(Minfo, X, Y) ->
	DX = abs(Minfo#ets_mon.x - X) * 60,
	DY = abs(Minfo#ets_mon.y - Y) * 30,
	round((math:sqrt(DX * DX + DY * DY) / Minfo#ets_mon.speed) * 1000) + 50.

%% 怪物重生
%% Minfo 怪物信息
%% X 复活点的X坐标
%% Y 复活点的Y坐标
revive(Minfo, X, Y, MonSpeed) ->
	Hp = 
        case Minfo#ets_mon.type of
            %% 世界BOSS重生世界播报
            3 ->
				spawn(fun()-> wild_boss_revive_broadcast(Minfo#ets_mon.scene, Minfo#ets_mon.name) end),
				Minfo#ets_mon.hp_lim;
			%% 龙塔
			37 ->
				spawn(fun()-> lib_castle_rush:castle_rush_mon_revive() end),
				Now = util:unixtime(),
				NewCastleRushTimer = erlang:send_after(10000, self(), 'CASTLE_RUSH_MON'),
				put(castle_rush_mon_boss, [NewCastleRushTimer, Now, Now]),
				case get(castle_rush_mon_boss) of
					undefined ->
						Minfo#ets_mon.hp_lim;
					[CastleRushTimer, _IntervalTime, ReviveTime] ->
						catch erlang:cancel_timer(CastleRushTimer),
						%% 5分钟内击败龙塔，增加10W血
						if
							Now - ReviveTime > 300 ->
								Minfo#ets_mon.hp_lim;
							true ->
								NewCastleRushBossHp = Minfo#ets_mon.hp_lim + 100000,
								spawn(fun()-> db_agent:update_castle_rush_boss_hp(NewCastleRushBossHp) end),
								NewCastleRushBossHp
						end;
					_ ->
						Minfo#ets_mon.hp_lim
				end;
            _ ->
				Minfo#ets_mon.hp_lim
        end,
	NewMinfo = Minfo#ets_mon{
        hp = Hp,
		hp_lim = Hp,
        mp = Minfo#ets_mon.mp_lim,
        x = X,
        y = Y,
		battle_status = [],
		status = 0,
		speed = MonSpeed
	},
    %% 通知客户端怪物重生
    {ok, BinData} = pt_12:write(12007, NewMinfo),
	case lib_scene:is_copy_scene(NewMinfo#ets_mon.scene) of
		true ->
			lib_send:send_to_online_scene(NewMinfo#ets_mon.scene, BinData);
		false ->
			lib_send:send_to_online_scene(NewMinfo#ets_mon.scene, X, Y, BinData)
	end,
	NewMinfo.

%% 野外BOSS重生广播
wild_boss_revive_broadcast(SceneId, MonName) ->
	case data_scene:get(SceneId) of
        [] ->
            skip;
        Scene ->
            Msg = io_lib:format("邪恶的世界大BOSS <font color='#FFCF00'>[~s]</font> 携带大量宝物出现在~s地区，召唤各位兄弟前来相助，为了世界和平，上啊！", [MonName, Scene#ets_scene.name]),
            lib_chat:broadcast_sys_msg(1, Msg)	
    end.

%% 追踪怪物的下一个动作
%% Minfo 怪物信息
%% X 被击方的X坐标
%% Y 被击方的Y坐标 
trace_action(Minfo, X, Y, RX, RY) ->    
    DX = abs(Minfo#ets_mon.x - X),    		
    case Minfo#ets_mon.att_area >= DX of
        true ->
            DY = abs(Minfo#ets_mon.y - Y),
            case Minfo#ets_mon.att_area >= DY of
                true ->
                    attack;
                false ->
                    trace_area(Minfo, X, Y, RX, RY)
            end;
        false ->
       		trace_area(Minfo, X, Y, RX, RY)
    end.

%% 追踪区域
%% Minfo 怪物信息
%% X 被击方的X坐标
%% Y 被击方的Y坐标
trace_area(Minfo, X, Y, RX, RY) ->
    TraceArea = Minfo#ets_mon.trace_area,
    DX = abs(RX - X),    
    %% 不在追踪范围内则停止追踪
    case TraceArea >= DX of
        true ->
			DY = abs(RY - Y),
           	case TraceArea >= DY of
            	true ->
                    trace;
                false ->
                    back
           	end;
        false ->
            back
    end.

%% 怪物死亡
%% Minfo 怪物信息
%% AttId 杀死怪物的人物ID
mon_die(Minfo, AttId, PlayeList, DX, DY) ->
	%% 是否有空幻阴阳怪关系
	case Minfo#ets_mon.relation of
		[5, EraBleedMonPid, MonTypeId, Type] ->
			EraBleedMonPid ! {'ERA_SKY_MON_DIE', Type},
			era_sky_mon_angry(MonTypeId, Minfo#ets_mon.scene);
		_ ->
			skip
	end,
	SceneId = Minfo#ets_mon.scene,
	case get_player(AttId, SceneId) of
		[] ->
    		%% 副本杀怪 单人副本杀怪
			case lib_scene:is_td_scene(SceneId) of
				true ->
					{ok, TdBinData} = pt_20:write(20011, Minfo#ets_mon.id),
					lib_send:send_to_online_scene(SceneId, TdBinData),
					TdScenePid = mod_scene:get_scene_real_pid(SceneId),
					case is_pid(TdScenePid) of
						true ->
							mod_td:kill_mon(SceneId, TdScenePid, [Minfo#ets_mon.mid]);
						false ->
							skip
					end;
				false ->
					%% 封神纪元怪杀怪
					case lib_era:is_era_scene(SceneId) of
						true ->
							{ok, TdBinData} = pt_20:write(20011, Minfo#ets_mon.id),
							lib_send:send_to_online_scene(SceneId, TdBinData);
						false ->
							case Minfo#ets_mon.type of
								%% 野外BOSS
								3 ->
									wild_boss_die_handle(Minfo#ets_mon.mid, Minfo#ets_mon.retime);
								_ ->
									skip
							end
					end
			end;
		Player ->
			[AttLv, AttParam, SceneType] =
                case Minfo#ets_mon.type of
					%% 普通怪
					1 ->
						[4, 3, 0];
                    %% 野外BOSS
                    3 ->
						%% 野外BOSS死亡处理
						wild_boss_die_handle(Minfo#ets_mon.mid, Minfo#ets_mon.retime),
						
						%% 添加野外BOSS参与统计
						spawn(fun()-> 
							lists:foreach(fun(PlayerId) ->
	                     		db_agent:update_join_data(PlayerId, wild_boss)
	                        end, PlayeList)		  
						end),
						
						%% 最高DPS的额外掉落
						spawn(fun()-> lib_goods_drop:wild_boss_dps_drop(Player, Minfo) end),
                        
                        %% 移除场景怪物
                        {ok, BinData} = pt_20:write(20011, Minfo#ets_mon.id),
						lib_send:send_to_online_scene(SceneId, Minfo#ets_mon.x, Minfo#ets_mon.y, BinData),
						NameColor = data_agent:get_realm_color(Player#player.realm),
                        MsgData = [
						    NameColor, 
                            lib_player:get_country(Player#player.realm),
                            Player#player.id,
                            Player#player.nickname,
                            Player#player.career,
                            Player#player.sex,
							NameColor, 
                            Player#player.nickname,
							"#FFCF00", 
                            Minfo#ets_mon.name
                        ],
                        Msg = io_lib:format("<font color='~s'>[~s]</font>玩家 [<a href='event:1, ~p, ~s, ~p, ~p'><font color='~s'>~s</font></a>] 经过一番天昏地暗的战斗后，轻松解决掉了<font color='~s'>[~s]</font>。", MsgData),
                        lib_chat:broadcast_sys_msg(1, Msg),
						[2, 3, 0];
                    
                    %% 氏族boss
					8 ->
                        {ok, BinData} = pt_20:write(20011, Minfo#ets_mon.id),
						lib_send:send_to_online_scene(SceneId, BinData),
%%                         MsgData = [Player#player.guild_id, Minfo#ets_mon.name],
%%                         gen_server:cast(mod_guild:get_mod_guild_pid(), {'kill_guild_boss', MsgData}),%%此处不用，挪到物品丢落那里
                        %% 添加玩家攻打氏族boss参与度统计
						lists:foreach(fun(PElem) ->
							db_agent:update_join_data(PElem, guild_boss)
                       	end, PlayeList),
						[2, 3, 7];
                    
                    %% 空岛boss
					30 ->
                        {ok, BinData} = pt_20:write(20011, Minfo#ets_mon.id),
						lib_send:send_to_online_scene(SceneId, BinData),
                        mod_skyrush:kill_sky_bossmon(Player, Minfo),
						[2, 3, 6];
					%% 空岛小怪
                    31 ->
                        {ok, BinData} = pt_20:write(20011, Minfo#ets_mon.id),
						lib_send:send_to_online_scene(SceneId, BinData),
                        mod_skyrush:kill_sky_littlemon(Player, Minfo),
						[2, 3, 6];
					%%跨服战场战旗
					36->
						{ok, BinData} = pt_20:write(20011, Minfo#ets_mon.id),
						lib_send:send_to_online_scene(SceneId, BinData),
						gen_server:cast(Player#player.other#player_other.pid_dungeon,{'GET_FLAG',[Player#player.other#player_other.pid,Player#player.id,Player#player.nickname,Player#player.other#player_other.leader,PlayeList]}),
						[4, 3, 0];
					%%神魔乱斗的小怪
					38 ->
						{ok, BinData} = pt_20:write(20011, Minfo#ets_mon.id),
						lib_send:send_to_online_scene(SceneId, BinData),
						case mod_warfare_mon:get_warfare_mon() of
							{ok, WarPid} ->
								WarPid ! {'REFRESH_MON', Minfo#ets_mon.mid, 1, []};
							_ ->
								skip
						end,
						[100, 3, 9];
					%%神魔乱斗的boss
					39 ->
						{ok, BinData} = pt_20:write(20011, Minfo#ets_mon.id),
						lib_send:send_to_online_scene(SceneId, BinData),
						case mod_warfare_mon:get_warfare_mon() of
							{ok, WarPid} ->
								PMems = 
									if
										Minfo#ets_mon.mid =:= 43104 ->%%路西法
											[];
										Minfo#ets_mon.mid =:= 43105 ->%%哈迪斯
											lists:foldl(fun(Elem, AccIn) ->
																case get_player(Elem, SceneId) of
																	[] ->
																		AccIn;
																	EPlayer ->
%% 																		{Pid, PName, PLv, Realm, Career, Sex, Gid, GName, PPid}
																		lib_achieve:check_achieve_finish_cast(EPlayer#player.other#player_other.pid, 353, [1]),%%参与击败哈迪斯成就计算
																		EDX = abs(Minfo#ets_mon.x - EPlayer#player.x),
																		EDY = abs(Minfo#ets_mon.y - EPlayer#player.y),
																		case EPlayer#player.scene =:= ?WARFARE_SCENE_ID andalso EDX =< 17 andalso EDY =< 20 of
																			true ->
																				[{EPlayer#player.id,
																				  EPlayer#player.nickname,
																				  EPlayer#player.lv,
																				  EPlayer#player.realm,
																				  EPlayer#player.career,
																				  EPlayer#player.sex, 
																				  EPlayer#player.guild_id,
																				  EPlayer#player.guild_name,
																				  EPlayer#player.other#player_other.pid}|AccIn];
																			false ->
																				AccIn
																		end
																end
														end, [],PlayeList);
										true ->
											[]
									end,
								WarPid ! {'REFRESH_MON', Minfo#ets_mon.mid, 1, PMems};
							_ ->
								skip
						end,
						[100, 3, 9];
					%% 雪怪
					40 ->
						%%判断是否是雪人，进行数量更新通知
						lib_activities:check_snowman_update(Minfo, SceneId, DX, DY),
						[100, 3, 9];
					42 ->%%掉落绑定怪物
						case Minfo#ets_mon.mid =:= 40976 of
							false ->
								skip;
							true ->
								%%小魔头死亡，通知数量减少
								lib_activities:little_devil_die()
						end,
						{ok, BinData} = pt_20:write(20011, Minfo#ets_mon.id),
						mod_scene_agent:send_to_scene(SceneId, BinData),
						[100, 3, 9];
                    _ ->
                        %% 副本杀怪 单人副本杀怪
                        case lib_scene:is_dungeon_scene(SceneId) of
                            true ->
                                {ok, DungeonBinData} = pt_20:write(20011, Minfo#ets_mon.id),
								lib_send:send_to_online_scene(SceneId, DungeonBinData),
                                [30, 30, 1];
                            false ->
								%% 幻魔穴
								case lib_cave:is_cave_scene(SceneId) of	
									true ->
										%% 是否共工
										if
											Minfo#ets_mon.mid == 41109 ->
												{ok, BinData31010} = pt_31:write(31010, [4]),
												lib_send:send_to_online_scene(SceneId, BinData31010);
											true ->
												skip
										end,
										mod_cave:kill_cave_mon(Player#player.other#player_other.pid_dungeon, Minfo#ets_mon.id),
										{ok, CaveBinData} = pt_20:write(20011, Minfo#ets_mon.id),
										lib_send:send_to_online_scene(SceneId, CaveBinData),
										[30, 30, 1];
									false ->
                                        %% TD杀怪
                                        case lib_scene:is_td_scene(SceneId) of
                                            true ->
												{ok, TdBinData} = pt_20:write(20011, Minfo#ets_mon.id),
												lib_send:send_to_online_scene(SceneId, TdBinData),
                                                mod_td:kill_mon(SceneId, Player#player.other#player_other.pid_dungeon, [Minfo#ets_mon.mid]),
                                                [2, 3, 2];
                                            false ->
                                                %% 封神台
                                                case lib_scene:is_fst_scene(SceneId) of
                                                    true ->
                                                        {ok, FstBinData} = pt_20:write(20011, Minfo#ets_mon.id),
														lib_send:send_to_online_scene(SceneId, FstBinData),
                                                        mod_fst:kill_mon(SceneId, Player#player.other#player_other.pid_dungeon, [Minfo#ets_mon.mid]),
                                                        [2, 3, 3];
                                                    false ->
                                                        %% 试炼副本
                                                        case lib_scene:is_training_scene(SceneId) of
                                                            true ->
                                                                mod_training:kill_mon(SceneId, Player#player.other#player_other.pid_dungeon, [Minfo#ets_mon.mid]),
                                                                [0, 1, 4];
                                                            false ->
                                                                %% 诛仙台杀怪
                                                                case lib_scene:is_zxt_scene(SceneId) of
                                                                    true ->
                                                                        {ok, FstBinData} = pt_20:write(20011, Minfo#ets_mon.id),
																		lib_send:send_to_online_scene(SceneId, FstBinData),
                                                                        mod_fst:kill_mon(SceneId, Player#player.other#player_other.pid_dungeon, [Minfo#ets_mon.mid]),
                                                                        [2, 3, 8];
                                                                    false ->
                                                                        %% 诛邪副本杀怪
                                                                        case lib_box_scene:is_box_scene_idsp(SceneId, Player#player.id) of
                                                                            true ->
                                                                                {ok, BoxBinData} = pt_20:write(20011, Minfo#ets_mon.id),
																				lib_send:send_to_online_scene(SceneId, BoxBinData),
                                                                                lib_boxs_piece:boxs_kill_mon(Player#player.other#player_other.pid, Minfo#ets_mon.mid),
                                                                                mod_box_scene:kill_mon(SceneId, Player#player.other#player_other.pid_scene, Player#player.id, Minfo),
                                                                                [2, 3, 5];
                                                                            false ->
																				%%封神纪元杀怪
																				case lib_era:is_era_scene(SceneId) of
																					true ->
																						   mod_era:kill_mon(SceneId, Player#player.other#player_other.pid_dungeon, [Minfo#ets_mon.mid,Minfo#ets_mon.id]), 
																						   [2, 3, 0];
																					false ->
                                                                                		[2, 3, 0]
																				end
                                                                        end
                                                                end
                                                        end
                                                end	
                                        end
								end                                
                        end
                end,
			
            %% 共享组队打怪经验和任务怪
            case is_pid(Player#player.other#player_other.pid_team) of
                true ->
                    gen_server:cast(Player#player.other#player_other.pid_team,
                		{'SHARE_TEAM_EXP', [Player#player.id, Minfo#ets_mon.exp, Minfo#ets_mon.spirit, Minfo#ets_mon.hook_exp, Minfo#ets_mon.hook_spirit, Minfo#ets_mon.mid, 
							SceneId, Player#player.x, Player#player.y, Minfo#ets_mon.lv, SceneType, Minfo#ets_mon.type, Minfo#ets_mon.mid]}),
					if
						SceneType =/= 4 ->
							lib_goods_drop:mon_drop(Player, Minfo, PlayeList);
						true ->
							%% 试炼特殊掉落
							MS = ets:fun2ms(fun(P) when P#player.scene == SceneId -> P end),
							TeamUserList = ets:select(?ETS_ONLINE_SCENE, MS),
							TrainMonDropFun = fun(P) -> 
								lib_goods_drop:train_mon_drop(P, Minfo, [P#player.id])
							end,
							lists:foreach(TrainMonDropFun, TeamUserList)
					end;
                _ ->
					%% 怪物经验，大于/小于5级经验减半（镇妖台没等级压制）
            		[MonExp, MonSpirit, HookExp, HookSpt] = 
						case abs(Player#player.lv - Minfo#ets_mon.lv) > AttLv andalso SceneType =/= 2 of
							true ->
								[trunc(Minfo#ets_mon.exp / AttParam), trunc(Minfo#ets_mon.spirit / AttParam), trunc(Minfo#ets_mon.hook_exp / 6), trunc(Minfo#ets_mon.hook_spirit / 6)];
							false ->
								[Minfo#ets_mon.exp, Minfo#ets_mon.spirit, Minfo#ets_mon.hook_exp, Minfo#ets_mon.hook_spirit]
						end,
               		gen_server:cast(Player#player.other#player_other.pid,
							{'EXP_FROM_MON', MonExp, MonSpirit, HookExp, HookSpt, SceneType, Minfo#ets_mon.type, Minfo#ets_mon.mid}),
					lib_goods_drop:mon_drop(Player, Minfo, PlayeList)
            end
    end.


%% 怪物召唤
conjure_mon(Num, MonId, SceneId, X, Y, ConjureList) ->
	Len = Num + 20,
	AutoId = mod_mon_create:get_mon_auto_id(Len),
	conjure_mon_loop(Num, MonId, SceneId, X, Y, AutoId, ConjureList).
conjure_mon_loop(0, _MonId, _SceneId, _X, _Y, _AutoId, ConjureList) ->
	ConjureList;
conjure_mon_loop(Num, MonId, SceneId, X, Y, AutoId, ConjureList) ->
	Rand = random:uniform(5),
	[RX, RY] =
		case Rand of
			1 ->
				[X - Rand, Y];
			2 ->
				[X, Y - Rand];
			3 ->
				[X + Rand, Y];
			4 ->
				[X, Y + Rand];
			_ ->
				[X, Y]
		end,
	[MonPid, NewAutoId] = mod_mon_create:create_mon_action(MonId, SceneId, RX, RY, 1, [], AutoId),
	conjure_mon_loop(Num - 1, MonId, SceneId, X, Y, NewAutoId, [{NewAutoId, MonPid} | ConjureList]).
	

%% 死亡召唤
conjure_after_die(Minfo, SceneId, X, Y) ->
	Len = length(Minfo),
	NewLen = Len + 20,
	AutoId = mod_mon_create:get_mon_auto_id(NewLen),
	conjure_after_die_loop(Minfo, SceneId, X, Y, AutoId).
conjure_after_die_loop([], _SceneId, _X, _Y, _AutoId) ->
	ok;
conjure_after_die_loop([MonId | M], SceneId, X, Y, AutoId) ->
	Rand = random:uniform(5),
	[RX, RY] =
		case Rand of
			1 ->
				[X - 1, Y];
			2 ->
				[X, Y - 1];
			3 ->
				[X + 1, Y];
			4 ->
				[X, Y + 1];
			_ ->
				[X - 1, Y]
		end,
	[_MonPid, NewAutoId] = mod_mon_create:create_mon_action(MonId, SceneId, RX, RY, 1, [], AutoId),
	conjure_after_die_loop(M, SceneId, X, Y, NewAutoId).

%% 销毁召唤怪物
destory_conjure_mon([], _SceneId) ->
	ok;
destory_conjure_mon([{MonId, Pid} | ConjureList], SceneId) ->
	case is_pid(Pid) of
		true ->
			Pid ! clear;
		false ->
			skip
	end,
	{ok, BinData} = pt_12:write(12082, [MonId, 0]),
	lib_send:send_to_online_scene(SceneId, BinData),
	destory_conjure_mon(ConjureList, SceneId).

%% 怪物特殊攻击
battle(MonId, MonHp, MonMp, SceneId, X, Y, AttArea, HpHurt, MpHurt, SkillId) ->
	X1 = X + AttArea,
    X2 = X - AttArea,
    Y1 = Y + AttArea,
    Y2 = Y - AttArea,
	MS = ets:fun2ms(fun(P) when P#player.scene == SceneId andalso P#player.hp > 0 andalso 
								P#player.x >= X2 andalso P#player.x =< X1 andalso 
								P#player.y >= Y2 andalso P#player.y =< Y1 andalso 
								P#player.other#player_other.battle_limit /= 9 ->
	    [
            P#player.id,
            P#player.hp,
            P#player.mp,
            P#player.other#player_other.pid
	    ]
	end),
	AllUser = ets:select(?ETS_ONLINE_SCENE, MS),
	battle_result(AllUser, MonId, MonHp, MonMp, SceneId, X, Y, HpHurt, MpHurt, SkillId).

battle_result(AllUser, MonId, MonHp, MonMp, SceneId, X, Y, HpHurt, MpHurt, SkillId) ->
	case SceneId =:= ?WARFARE_SCENE_ID of
		true ->
			MonName =
				case ets:match_object(?ETS_SCENE_MON, #ets_mon{scene = SceneId, id = MonId, _ = '_'}) of
					[] ->
						"神魔怪";
					[Mon|_R] ->
						Mon#ets_mon.name
				end;
		false ->
			MonName = ""
	end,
	BattleResult = battle_loop(AllUser, HpHurt, MpHurt, MonName, SceneId, []),
	{ok, BinData} = pt_20:write(20003, [MonId, MonHp, MonMp, SkillId, 1, BattleResult]),
	lib_send:send_to_online_scene(SceneId, X, Y, BinData).

battle_loop([], _HpHurt, _MpHurt, _MonId, _SceneId, Ret) ->
	Ret;
battle_loop([[PlayerId, Hp, Mp, Pid] | U], HpHurt, MpHurt, MonName, SceneId, Ret) ->
	[NewMp, NewMpHurt, MHurt] = 
		case Mp > MpHurt of
			true ->
				[Mp - MpHurt, 0, MpHurt];
			false ->
				[0, MpHurt - Mp, Mp]
		end,
	Hurt = HpHurt + NewMpHurt,
	NewHp = 
		case Hp > Hurt of
			true ->
				Hp - Hurt;
			false ->
				0
		end,
	Pid ! {'PLAYER_BATTLE_RESULT', [NewHp, NewMp, 0, 0, MonName, 0, 0, SceneId]},
	lib_scene:update_player_info_fields_for_battle(PlayerId, NewHp, NewMp),
	battle_loop(U, HpHurt, MpHurt, MonName, SceneId, [[2, PlayerId, NewHp, NewMp, Hurt, MHurt, 0] | Ret]).


%% 能量爆炸
energy_explode_user([], Ret) ->
	Ret;
energy_explode_user([[Id, Hp, Mp, Pid, Buff] | U], Ret) ->
	case lists:keyfind(energy_shield, 1, Buff) of
		false ->
			energy_explode_user(U, [[Id, Hp, Mp, Pid] | Ret]);
		_ ->
			energy_explode_user(U, Ret)
	end.

%% 是否BOSS怪物
is_boss_mon(MonType) ->
	lists:member(MonType, [3, 5, 8]) orelse MonType >= 10.

%% 动态生成怪 
dynamic_create_mon(Minfo, SceneId, X, Y) ->
	{ok, BinData} = pt_12:write(12007, Minfo),
    case lib_scene:is_copy_scene(SceneId) of
        true ->
			lib_send:send_to_online_scene(SceneId, BinData);
		false when SceneId =:= ?WARFARE_SCENE_ID ->%%神魔乱斗的怪物，也需要全场景广播
			lib_send:send_to_online_scene(SceneId, BinData);
        false ->
			lib_send:send_to_online_scene(SceneId, X, Y, BinData)
    end,
    {ok, ConjureBinData} = pt_20:write(20103, [X, Y, 1000, 10038]),
	lib_send:send_to_online_scene(SceneId, X, Y, ConjureBinData).

%% 是否还有存活的怪
is_alive_scene_mon(SceneId) ->
	MS = ets:fun2ms(fun(M) when M#ets_mon.scene == SceneId, M#ets_mon.hp > 0 -> 
	    [
  			M#ets_mon.id			             
	    ]
	end),
	Mon = ets:select(?ETS_SCENE_MON, MS),
	length(Mon) > 0.

%%目前只有神秘商店使用
is_alive_scene_mon(SceneId,PlayerId,ScenePid) ->
	MS = ets:fun2ms(fun(M) when M#ets_mon.scene == SceneId, M#ets_mon.hp > 0 -> 
	    [
  			M#ets_mon.id			             
	    ]
	end),
	Mon = ets:select(?ETS_SCENE_MON, MS),
	case length(Mon) > 0 of
		true ->
			skip;
		false ->
			%%告诉客户端显示神秘商人
			{ok,BinData} = pt_32:write(32002,<<>>),
			ScenePid ! {'display_npc',BinData,PlayerId}
	end.

%% 野外BOSS死亡处理
wild_boss_die_handle(MonId, MonRetime) ->
	RandPid = mod_rank:get_mod_rank_pid(),
	case is_pid(RandPid) of
		true ->
			Now = util:unixtime(),
			gen_server:cast(RandPid, {boss_killed_time, MonId, Now, MonRetime});
		false ->
			skip
	end.
	
%% 是否有战旗
is_alive_scene_flag(SceneId,MonId)->
	MS = ets:fun2ms(fun(M) when M#ets_mon.scene == SceneId, M#ets_mon.id ==MonId, M#ets_mon.hp > 0 -> 
	    [
  			M#ets_mon.id			             
	    ]
	end),
	Mon = ets:select(?ETS_SCENE_MON, MS),
	length(Mon) > 0.

%% 删除怪物数据
del_mon_data(MonPid, MonUniqueKey) ->
	catch ets:match_delete(?ETS_SCENE_MON, #ets_mon{ unique_key = MonUniqueKey, _ = '_' }),
	catch misc:delete_monitor_pid(MonPid).

%% 野外BOSS复活检测
check_wild_boss_time(NowSec, Interval) ->
	if
		NowSec >= 37800 andalso NowSec - 37800 < Interval ->
			wild_boss_action();
		NowSec >= 52200 andalso NowSec - 52200 < Interval ->
			wild_boss_action();
		NowSec >= 77400 andalso NowSec - 77400 < Interval ->
			wild_boss_action();
		true ->
			skip
	end.

wild_boss_action() ->
	MonList = [
		{42001, 101, 21, 66},
		{42023, 101, 36, 220},
		{42025, 101, 86, 118},
		
		{42003, 102, 7, 50},
		{42027, 102, 19, 222},
		{42029, 102, 107, 221},
		
		{42005, 103, 103, 223},
		{42031, 103, 6, 123},
		{42033, 103, 100, 28},
		
		{42015, 104, 13, 132},
		{42035, 104, 14, 212},
		{42037, 104, 11, 9},
		
		{42021, 105, 97, 71},
		{42039, 105, 53, 136},
		{42041, 105, 108, 208},
		
		{42007, 101,106,57},
		
		{42009, 102,13,158},
		{42011,103,39,28},
		{42013, 104,77,112},
		{42017,105,57,39},
		{42019,705,29,49}
		
	],
	Fun = fun({MonId, SceneId, X, Y})->
		ScenePid = mod_scene:get_scene_real_pid(SceneId),
		case is_pid(ScenePid) of
			true ->
				gen_server:cast(ScenePid, {'REFRESH_WILD_BOSS', MonId, SceneId, X, Y});
			false ->
				skip
%% 				?WARNING_MSG("WILD_BOSS_ACTION_ERROR: MonId ~p SceneId ~p ScenePid ~p~n", [MonId, SceneId, ScenePid])
		end
	end,
	[Fun(M) || M <- MonList],
	spawn(fun()-> wild_boss_broadcast() end).

%% 野外BOSS重生广播
wild_boss_broadcast() ->
	Msg1 = io_lib:format("邪恶的世界大BOSS <font color='#FFCF00'>[火凤]</font> <font color='#FFCF00'>[炎凤]</font> <font color='#FFCF00'>[焱凤]</font> 携带大量宝物出现在雷泽地区，召唤各位兄弟前来相助，为了世界和平，上啊！", []),
	lib_chat:broadcast_sys_msg(1, Msg1),
	
	Msg2 = io_lib:format("邪恶的世界大BOSS <font color='#FFCF00'>[千年老龟]</font> <font color='#FFCF00'>[千年古龟]</font> <font color='#FFCF00'>[千年巨龟]</font> 携带大量宝物出现在洛水地区，召唤各位兄弟前来相助，为了世界和平，上啊！", []),
	lib_chat:broadcast_sys_msg(1, Msg2),
	
	Msg3 = io_lib:format("邪恶的世界大BOSS <font color='#FFCF00'>[烈焰麒麟兽]</font> <font color='#FFCF00'>[烈炎麒麟兽]</font> <font color='#FFCF00'>[烈焱麒麟兽]</font> 携带大量宝物出现在苍茫林地区，召唤各位兄弟前来相助，为了世界和平，上啊！", []),
	lib_chat:broadcast_sys_msg(1, Msg3),
	
	Msg4 = io_lib:format("邪恶的世界大BOSS <font color='#FFCF00'>[穷奇巨兽]</font> <font color='#FFCF00'>[穷奇蛮兽]</font> <font color='#FFCF00'>[穷奇妖兽]</font> 携带大量宝物出现在天山瑶池地区，召唤各位兄弟前来相助，为了世界和平，上啊！", []),
	lib_chat:broadcast_sys_msg(1, Msg4),
	
	Msg5 = io_lib:format("邪恶的世界大BOSS <font color='#FFCF00'>[蛮荒巨龙]</font> <font color='#FFCF00'>[蛮荒古龙]</font> <font color='#FFCF00'>[蛮荒妖龙]</font> 携带大量宝物出现在洪荒原地区，召唤各位兄弟前来相助，为了世界和平，上啊！", []),
	lib_chat:broadcast_sys_msg(1, Msg5).

%%  血姬召唤血柱
era_blood_relation(RelationList, SceneId, _X, _Y, EraBleedMonPid,EraBlessMid) ->
	case is_list(RelationList) of
		true ->
			F = fun({MonTypeId, X1, Y1, Interval},Auto_Id)->
				[_Mpid,NewAutoId] = mod_mon_create:create_mon_action(MonTypeId, SceneId, X1, Y1, 4, [EraBleedMonPid,EraBlessMid,Interval], Auto_Id),
				NewAutoId
			end,
			MonNum = length(RelationList),
			AutoId = mod_mon_create:get_mon_auto_id(MonNum + 10),
			lists:foldl(F, AutoId, RelationList);
		false ->
			skip
	end.

%% 空幻
era_sky_relation(RelationList, SceneId, X, Y, EraBleedMonPid) ->
	case is_list(RelationList) of
		true ->
			F = fun({Type, MonTypeId, OtherMonTypeId},Auto_Id)->
				X1 = X + random:uniform(2),
				Y1 = Y + random:uniform(2),
				[_MonPid,NewAutoId] = mod_mon_create:create_mon_action(MonTypeId, SceneId, X1, Y1, 5, [EraBleedMonPid, OtherMonTypeId, Type], Auto_Id),
				NewAutoId
			end,
			AutoId = mod_mon_create:get_mon_auto_id(1),
			lists:foldl(F, AutoId, RelationList);
		false ->
			skip
	end.

%% 空幻阴阳怪有一个死亡
era_sky_mon_angry(MonTypeId, SceneId) ->
	MS = ets:fun2ms(fun(M) when M#ets_mon.mid == MonTypeId, M#ets_mon.hp > 0, M#ets_mon.scene == SceneId -> M end),
   	case ets:select(?ETS_SCENE_MON, MS)	of
  		[] -> 
			[];
   		[Minfo | _] ->
			case is_pid(Minfo#ets_mon.pid) of
				true ->
					Minfo#ets_mon.pid ! 'ERA_MON_ANGRY';
				false ->
					skip
			end
    end.
	

