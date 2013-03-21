%%%--------------------------------------
%%% @Module  : pp_player
%%% @Author  : ygzj
%%% @Created : 2010.05.12
%%% @Description:  角色功能管理  
%%%--------------------------------------
-module(pp_player).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").
-include("guild_info.hrl").

%% 查询当前玩家信息
handle(13001, PlayerState, _) ->	
 	lib_player:send_player_attribute(PlayerState#player_state.player, 0);

%% 查询其他玩家信息
handle(13004, PlayerState, Id) ->
	Player = PlayerState#player_state.player,
    case Id =/= Player#player.id of
        true ->
			case lib_player:get_player_pid(Id) of
				[] -> 
					BinData = pt:pack(13004, <<0:32>>),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
					ok;
				Pid ->
					gen_server:cast(Pid, {'GET_OTHER_PLAYER_INFO', Player#player.id,  Player#player.other#player_other.pid_send})
			end;
        false ->
            skip
    end;

%% 请求快捷栏
handle(13007, PlayerState, _) ->
	Player = PlayerState#player_state.player,
    {ok, BinData} = pt_13:write(13007, PlayerState#player_state.quickbar),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);

%% 保存快捷栏
handle(13008, PlayerState, [T, S, Id]) ->
    Quickbar = save_quickbar([T, S, Id], PlayerState#player_state.quickbar),
	NewPlayerState = PlayerState#player_state{
		quickbar = Quickbar
  	},
	{ok, change_player_state, NewPlayerState};

%% 删除快捷栏
handle(13009, PlayerState, T) ->
    Quickbar = delete_quickbar(T, PlayerState#player_state.quickbar),
	NewPlayerState = PlayerState#player_state{
		quickbar = Quickbar
  	},
	{ok, change_player_state, NewPlayerState};

%% 替换快捷栏
handle(13010, PlayerState, [T1, T2]) ->
    Quickbar = replace_quickbar(T1, T2, PlayerState#player_state.quickbar),
	NewPlayerState = PlayerState#player_state{
		quickbar = Quickbar
  	},
	{ok, change_player_state, NewPlayerState};

%% 修改 Pk模式
%% Mode 要修改的PK模式
handle(13012, PlayerState, Mode) ->
	Player = PlayerState#player_state.player,
	PkMode = Player#player.pk_mode,
    case PkMode =/= Mode andalso Mode > 0 andalso Mode < 7 of
        true ->
            case Player#player.scene of
                %% 攻城战中只能使用氏族模式
                ?CASTLE_RUSH_SCENE_ID ->
					if 
						Mode =:= 3 orelse Mode =:= 6 ->
							[Result, RetMode, RetPkTime] = 
								if
                       				Player#player.guild_id /= 0 ->
                          				[1, Mode, 0];
                              		true ->
                            			[2, PkMode, 0]
                     			end,
							lib_battle:change_pk_mode(Player, Result, RetMode, RetPkTime, Mode);
						true ->
							{ok, BinData} = pt_13:write(13012, [8, PkMode]),
                    		lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
					end;
                %% 空战不能修改模式
                ?SKY_RUSH_SCENE_ID ->
					{ok, BinData} = pt_13:write(13012, [7, PkMode]),
                    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
                _ ->
                    [Result, RetMode, RetPkTime] =
                        case PkMode /= 1 of
                            true ->
                                case Mode of                    
                                    1 ->
                                        %% 运镖状态不能切换和平模式                                
                                        case lib_carry:check_has_carry(Player) of
                                            false ->
                                                case Player#player.evil > 450 of
                                                    true ->
                                                        [6, PkMode, 0];
                                                    false ->
                                                        PkDist = 7200,
                                                        Now = util:unixtime(),
                                                        %% 判断和平切换时间
                                                        case Now - Player#player.pk_time >= PkDist of
                                                            true ->								
                                                                [1, Mode, 0];
                                                            false ->                                
                                                                TimeDist = Player#player.pk_time + PkDist - Now,
                                                                [4, TimeDist, 0]
                                                        end                              
                                                end;
											true when Player#player.carry_mark =:= 27 ->%%您持有冥王之灵，不能切换到和平模式
												[9, PkMode, 0];
                                            true ->
                                                [5, PkMode, 0]
                                        end;
                                    %% 判断是否有氏族
                                    3 ->                        
                                        if
                                            Player#player.guild_id /= 0 ->
                                                [1, Mode, 0];
                                            true ->
                                                [2, PkMode, 0]
                                        end;
                                    %% 判断是否组队
                                    4 ->                        
                                        if
                                            Player#player.other#player_other.pid_team /= undefined ->
                                                [1, Mode, 0];
                                            true ->
                                                [3, PkMode, 0]
                                        end;
                                    %% 联盟模式(是否有氏族)
                                    6 ->
                                        if
                                            Player#player.guild_id /= 0 ->
                                                [1, Mode, 0];
                                            true ->
                                                [10, PkMode, 0]
                                        end;
                                    _ ->
                                        [1, Mode, 0]
                                end;
                            false ->
                                Now = util:unixtime(),
                                [1, Mode, Now]
                  		end,
					lib_battle:change_pk_mode(Player, Result, RetMode, RetPkTime, Mode)
            end;
        false ->
            skip
    end;

%% 获取技能BUFF信息
handle(13013, PlayerState, _) ->
	Player = PlayerState#player_state.player,
    Buff = Player#player.other#player_other.battle_status,
	Now = util:unixtime(),
	lib_player:refresh_player_buff(Player#player.other#player_other.pid_send, Buff, Now);

%% 获取物品buff信息
handle(13014, PlayerState, _) ->
	Player = PlayerState#player_state.player,
	{NewPlayer, _BuffInfo} = lib_goods:update_goods_buff_action(Player, force),
	{ok, change_status, NewPlayer};

%% 获取角色打坐信息
handle(13015, PlayerState, Data) ->
	Player = PlayerState#player_state.player,
	%% 温泉中，不能打坐
	case lib_spring:is_spring_scene(Player#player.scene) of
		false ->
			%% 竞技场里不能打坐
			case lib_coliseum:is_coliseum_scene(Player#player.scene) of
				false ->
					lib_player:send_player_sit_attribute(Player, Data);
				true ->
					{ok, BinData} = pt_13:write(13015, [Player#player.id, 11]),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
			end;
		true ->
			{ok, BinData} = pt_13:write(13015, [Player#player.id, 9]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
	end;

%% 获取玩家离线时间经验累积
handle(13020, PlayerState, []) ->
	lib_offline_award:get_offline_award(PlayerState#player_state.player);

%% 兑换玩家离线时间经验累积
handle(13021, PlayerState, [Hours, Mult]) ->
	Player = PlayerState#player_state.player,
	case lib_offline_award:convert_offline_award(Player, Hours, Mult) of
		{Result, _NewPlayer}->
			{ok, BinData} = pt_13:write(13021, [Result, 0, 0, 0]),
    		lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		{Res, NewPlayer, Seconds, Exp, Sprite} ->
			{ok, BinData} = pt_13:write(13021, [Res, Seconds, Exp, Sprite]),
    		lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send, BinData),
			lib_player:send_player_attribute2(NewPlayer, 1),
			{ok, change_status, NewPlayer}
	end;

%% 获取连续登陆物品奖励信息
handle(13022, PlayerState, [])->
	lib_online_award:continuous_online_info(PlayerState#player_state.player);

%% 领取连续登陆物品
handle(13023, PlayerState, [Day])->
	Player = PlayerState#player_state.player,
	{_, Res} = 
		case lib_online_award:get_continuous_online_award(Player, Day) of
			{ok, 1} ->
				lib_online_award:continuous_online_info(Player),
				{ok, 1};
			{error, Error} -> 
				{error, Error}
		end,
	{ok, BinData} = pt_13:write(13023, Res),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);

%% 获取在线时长礼券奖励信息
handle(13024, PlayerState, [])->
	lib_online_award:continuous_online_cash_info(PlayerState#player_state.player);

%% 领取在线时长礼券奖励
handle(13025, PlayerState, [Type])->
	Player = PlayerState#player_state.player,
	case lib_online_award:get_continuous_online_cash(Player, Type)  of
		{ok, NewPlayer}->
			{ok, BinData} = pt_13:write(13025, 1),
    		lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send, BinData),
			lib_player:send_player_attribute2(NewPlayer, 1),
			lib_online_award:continuous_online_cash_info(NewPlayer),
			{ok, change_status, NewPlayer};
		{error, Res}->
			{ok, BinData} = pt_13:write(13025, Res),
    		lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
	end;

handle(13026, PlayerState, []) ->
	Player = PlayerState#player_state.player,
	{ok, BinData} = pt_13:write(13026, Player#player.other#player_other.charm),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);

%% 获取积分面板积分
handle(13027, PlayerState, _) ->
	Player = PlayerState#player_state.player,
	List = [
		Player#player.arena_score,
		Player#player.other#player_other.guild_feats,
		Player#player.honor,
		lib_td:get_hor_td(Player#player.id),
		Player#player.other#player_other.charm,
		Player#player.realm_honor,
		Player#player.other#player_other.zxt_honor	
	],
	{ok, BinData} = pt_13:write(13027, List),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);


%% 角色改名
handle(13028, PlayerState, [NickName]) ->
	Player = PlayerState#player_state.player,
	case pp_account:validate_name([Player#player.sn, NickName]) of  %% 角色名合法性检测
		{false, Msg} ->
			{ok, BinData} = pt_13:write(13028, Msg),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		true ->
			case lib_player:change_playername(Player, NickName) of
				{Res}->
					{ok, BinData} = pt_13:write(13028,Res),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
				{Res, NewPlayer}->
					{ok, BinData} = pt_13:write(13028,Res),
					lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send, BinData),
					lib_player:send_player_attribute(NewPlayer, 1),
					{ok, BinData1} = pt_12:write(12044,[NewPlayer#player.id, NickName]),
				    mod_scene_agent:send_to_area_scene(NewPlayer#player.scene, NewPlayer#player.x, NewPlayer#player.y, BinData1),
					{ok, NewPlayer}
			end
	end;

%%排行榜玩家属性
handle(13029, PlayerState, OtherId)->
	Player = PlayerState#player_state.player,
	case OtherId div 100000000 == 1 of
		false->
			case mod_cache:get({pp_player,13029,OtherId}) of
				[] ->
					[Id, Nickname, Realm, Sex, Lv, Career, Vip, Mount] = lib_player:get_palyer_properties(OtherId,[id, nickname, realm, sex, lv, career, vip, mount]),
					case Mount of 
						0 -> 
							MountTypeId = 0;
						_ -> 
							MountTypeId1 = goods_util:get_goods_type_db(Mount),
							case MountTypeId1 == null of
								true -> MountTypeId = 0;
								false -> MountTypeId = MountTypeId1
							end
					end,
					Result = [Id, Nickname, Realm, Sex, Lv, Career, Vip, Mount,MountTypeId],
					mod_cache:set({pp_player,13029,OtherId},Result,3600),
					Result;
				CacheData -> 
					Result = CacheData
			end;
		true->
			case mod_cache:g_get({pp_player,13029,OtherId}) of
				[]->Result =[OtherId,<<>>,0,0,0,0,0,0,0];
				CacheData -> 
					Result = CacheData
			end
	end,
	{ok, BinData} = pt_13:write(13029, Result),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);

handle(13030, PlayerState, [_Mark])->
	Player = PlayerState#player_state.player,
%% 	if Mark =:= 1 ->
%% %% 		   {ok,NewPlayer} = pp_goods:handle(15020, Player, [28042, 1, 1 ,0]),
%% 		   PatternBag = #goods{ player_id=Player#player.id, goods_id=28042, location=4, _='_' },
%% 		   case goods_util:get_ets_list(?ETS_GOODS_ONLINE, PatternBag) of
%% 						[] -> {8,Player,0};
%% 						_ -> gen_server:cast(Player#player.other#player_other.pid, {'sex_change'})
%% 		   end;
%% 	   true ->
%% 		   
%% 	end;
	gen_server:cast(Player#player.other#player_other.pid, {'sex_change'});

%%
handle(13031,PlayerState,[])->
	Player = PlayerState#player_state.player,
	Times = lib_vip:get_send_times(Player#player.id,Player#player.vip),
	{ok, BinData} = pt_13:write(13031, Times),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);

%%查询双修角色列表
handle(13040,PlayerState,[])->
	Player = PlayerState#player_state.player,
	Data = lib_double_rest:get_double_rest_list(Player),
	{ok, BinData} = pt_13:write(13040, Data),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);

%%查询双修角色
handle(13041,PlayerState,Nickname)->
	Player = PlayerState#player_state.player,
	Data = lib_double_rest:get_double_rest_user(Nickname),
	{ok, BinData} = pt_13:write(13041, Data),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);

%%发出双修邀请
handle(13042,PlayerState,OtherPlayerId)->
	Player = PlayerState#player_state.player,
	Result = lib_double_rest:send_double_rest(Player,OtherPlayerId),
	[Data,OtherPlayer,Other_Id,OtherSceneId,X1,Y,X,Y,PlayerId,PlayerSceneId,X1,Y] = Result,
	{ok, BinData} = pt_13:write(13042, [Data,Other_Id,OtherSceneId,X1,Y,X,Y,PlayerId,PlayerSceneId,X1,Y]),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	%%Data为1，或3时对方自动开始寻路至被邀请人位置,为2时被邀请人弹出邀请窗口
	if
		Data == 2 ->
			%%通知对方弹出邀请窗口
			{ok, BinData1} = pt_13:write(13044, [Player#player.id,Player#player.nickname]),
			lib_send:send_to_sid(OtherPlayer#player.other#player_other.pid_send, BinData1);
		true ->
			skip
	end,
	if Data == 1 orelse Data == 2 -> 
			{ok, BinData2} = pt_13:write(13042, [14,Other_Id,OtherSceneId,X1,Y,X,Y,PlayerId,PlayerSceneId,X1,Y]),
			lib_send:send_to_sid(OtherPlayer#player.other#player_other.pid_send, BinData2);
		true ->
			skip
	end;

%%设置双修邀请
handle(13043,PlayerState,Code)->
	Player = PlayerState#player_state.player,
	{ok, BinData} = pt_13:write(13043, 1),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	NewPlayer = Player#player{other = Player#player.other#player_other{accept=Code}},
	{ok, NewPlayer};

%%同意或拒绝双修邀请
handle(13045,PlayerState,[OtherPlayerId,Code])->
	OtherPlayer = lib_player:get_online_info(OtherPlayerId),
	Player = PlayerState#player_state.player,
	Data = lib_double_rest:accept_double_rest(Player,OtherPlayerId,Code),
	[Res,Player_Id,SceneId,X1,Y1,X2,Y2,OtherId,OtherSceneId,_OtherX,_OtherY] = Data,
	if Res =/= 3 ->%%对方不在线不发消息
		   {ok, BinData} = pt_13:write(13045, Data),
		   lib_send:send_to_sid(OtherPlayer#player.other#player_other.pid_send, BinData);
	   true ->
		   skip
	end,
	case Res == 1 of
		true ->
			{ok, BinData1} = pt_13:write(13045, [11,Player_Id,SceneId,X1,Y1,X2,Y2,OtherId,OtherSceneId,X1,Y1]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData1);
		false ->
			skip
	end;
	
%%开始或取消双修
handle(13046,PlayerState,[OtherPlayerId,Code,InitX,InitY])->
	Player = PlayerState#player_state.player,
	[Data,NewPlayer] = lib_double_rest:double_rest_oper(Player,OtherPlayerId,Code,InitX,InitY),
	{ok, BinData} = pt_13:write(13046, Data),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	{ok, NewPlayer};

%%同意或拒绝双修邀请
handle(13053,_PlayerState,[OtherPlayerId])->
	OtherPlayer = lib_player:get_online_info(OtherPlayerId),
	if OtherPlayer =/= [] ->
		   {ok, BinData} = pt_13:write(13053, 1),
		   lib_send:send_to_sid(OtherPlayer#player.other#player_other.pid_send, BinData);
	   true->
		   skip
	end;

%%推送积分
handle(13054,PlayerState,[])->
	 Player = PlayerState#player_state.player,
	 %%通知客户端改变积分
	 {ok, BinData13054} =  pt_13:write(13054, Player#player.other#player_other.shop_score),
	 lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData13054);

%%封神争霸功勋属性升级
handle(13062,PlayerState,[Type])->
	Player = PlayerState#player_state.player,
	case lib_war2:use_war_honor(Player, Type) of
		{error,Err}->
			{ok, BinData} = pt_13:write(13062, [Err]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		{NewPlayer,1}->
			{ok, BinData} = pt_13:write(13062, [1]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
			{ok, change_status, NewPlayer};
		_->skip
	end;

handle(_Cmd, _Status, _Data) ->
    ?DEBUG("pp_player no match", []),
    {error, "pp_player no match"}.

%% ---------------快捷栏-----------------

%%删除指定位置的快捷栏
save_quickbar([T, S, Id], Q) ->
    case lists:keyfind(T, 1, Q) of
        false ->
            [{T, S, Id} | Q];
        _ -> 
            Q1 = lists:keydelete(T, 1, Q),
            [{T, S, Id} | Q1]
    end.

%%删除指定位置的快捷栏
delete_quickbar(T, Q) ->
    case lists:keyfind(T, 1, Q) of
        false ->
            Q;
        _ ->
            lists:keydelete(T, 1, Q)
    end.

%%删除指定位置的快捷栏
replace_quickbar(T1, T2,  Q) ->
    case lists:keyfind(T1, 1, Q) of
        false -> %T1没有物品
            Q;
        {_ , S1, Id1} ->
            Q1 = lists:keydelete(T2, 1, Q),
            Q2 = lists:keydelete(T1, 1, Q1),
            case lists:keyfind(T2, 1, Q) of
                false -> %T2没有物品
                    [{T2, S1, Id1} | Q2];
                {_, S2, Id2} ->
                    [{T2, S1, Id1}, {T1, S2, Id2} | Q2]
            end
    end.
%% -------------------快捷栏结束------------------



