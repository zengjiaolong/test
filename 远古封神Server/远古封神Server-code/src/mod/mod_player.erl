%%%------------------------------------
%%% @Module  : mod_player
%%% @Author  : ygzj
%%% @Created : 2010.09.27
%%% @Description: 角色处理
%%%------------------------------------
-module(mod_player). 
-behaviour(gen_server).
-include("common.hrl").
-include("record.hrl").
-include("achieve.hrl").
-include("hot_spring.hrl").
-include("guild_info.hrl").

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-compile([export_all]).

%%启动角色主进程
start(PlayerId, AccountId, Socket) ->
    gen_server:start(?MODULE, [PlayerId, AccountId, Socket], []).
 
%% --------------------------------------------------------------------
%% Function: init/1
%% Description: Initiates the server
%% Returns: {ok, State}          |
%%          {ok, State, Timeout} |
%%          ignore               |
%%          {stop, Reason}
%% --------------------------------------------------------------------
init([PlayerId, _AccountId, Socket]) ->
	net_kernel:monitor_nodes(true),
	PlayerProcessName = misc:player_process_name(PlayerId),
	misc:unregister(PlayerProcessName),
	case misc:register(unique, PlayerProcessName, self()) of %%如果注册不成功，不再初始化。
		yes ->
			delete_etswhen_init(PlayerId),
%% 			lib_login_prize:init_holiday_info(PlayerId),
			PlayerState = #player_state{},
			[NewPlayerState, Player] = 
				case lib_war:is_war_server() of
					true->
						load_player_info_war_server(PlayerState, PlayerId, Socket);
					false->
						%% 检查目标状态(30秒后检查)
						erlang:send_after(30 * 1000, self(), {'TARGET_STATE'}),	
						%%检查师徒指引(10S)
						erlang:send_after(10 * 1000, self(), {'MASTER_LEAD'}),
						%%VIP状态检测
						erlang:send_after(10*1000,self(),{'CHECK_VIP_STATE'}),
						load_player_info(PlayerState, PlayerId, Socket)
				end,
			%% 检查防沉迷信息
			check_idcard_status(Player),
			%% 5秒后检查重复登陆
			erlang:send_after(10 * 1000, self(), 'CHECK_DUPLICATE_LOGIN'),
			%% 心跳包时间检测
			put(detect_heart_time, [0, 0, []]),
			%% 减速Timer
			put(change_speed_timer, [undefined, 0, 0]),
			%% 添加一个在线
			mod_online_count:add_online_num(),
			misc:write_monitor_pid(self(), ?MODULE, {PlayerId}),
    		{ok, NewPlayerState};
		_ ->
			{stop, normal, {}}
	end.

%% --------------------------------------------------------------------
%% Function: handle_call/3
%% Description: Handling call messages
%% Returns: {reply, Reply, State}          |
%%          {reply, Reply, State, Timeout} |
%%          {noreply, State}               |
%%          {noreply, State, Timeout}      |
%%          {stop, Reason, Reply, State}   | (terminate/2 is called)
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%% 路由
%% Cmd 命令号
%% Socket socket id
%% Bin 消息体
routing(Cmd, Status, Bin, PlayerState) ->
    %% 取前面二位区分功能类型
    [H1, H2, _, _, _] = integer_to_list(Cmd),
	
%%   	case lists:member(Cmd, [12001, 10006, 10030, 20001]) of
%%  		false ->
%%   			io:format("Cmd ~p~n", [Cmd]);
%%  		true ->
%%  			skip
%%  	end,
%% 	
%% 	{memory,Mem_used} = process_info(self(),memory),
%% 	if
%% 		Mem_used < 500000 ->
%% 		  	ok;
%% 		Cmd == 10006 ->
%% 			ok;
%% 		true ->
%% 			io:format("______mod_player/routing_______get_process_memory:~p__~p~n",[Cmd, Mem_used])
%% 	end,
	
    case [H1, H2] of
        %% 游戏基础功能处理
        "10" -> pp_base:handle(Cmd, Status, Bin);
        "11" -> pp_chat:handle(Cmd, Status, Bin);
        "12" -> pp_scene:handle(Cmd, Status, Bin);
        "13" -> pp_player:handle(Cmd, PlayerState, Bin);
        "14" -> pp_relationship:handle(Cmd, Status, Bin, PlayerState);
        "15" -> pp_goods:handle(Cmd, Status, Bin);
        "16" -> pp_mount:handle(Cmd, Status, Bin);
		"17" -> pp_sale:handle(Cmd, Status, Bin);
		"18" -> pp_trade:handle(Cmd, Status, Bin);
        "19" -> pp_mail:handle(Cmd, Status, Bin);
        "20" -> pp_battle:handle(Cmd, Status, Bin, PlayerState);
        "21" -> pp_skill:handle(Cmd, Status, Bin);
        "22" -> pp_rank:handle(Cmd, Status, Bin);
		"23" -> pp_arena:handle(Cmd, PlayerState, Bin);
        "24" -> pp_team:handle(Cmd, Status, Bin);
        "25" -> pp_meridian:handle(Cmd, Status, Bin);
        "26" -> pp_hook:handle(Cmd, Status, Bin);
		"27" -> pp_master_apprentice:handle(Cmd, Status, Bin);
		"28" -> pp_box:handle(Cmd, Status, Bin);
		"29" -> pp_antirevel:handle(Cmd, Status, Bin);
        "30" -> pp_task:handle(Cmd, Status, Bin);
		"31" -> pp_deliver:handle(Cmd, Status, Bin);
        "32" -> pp_npc:handle(Cmd, Status, Bin);
		"33" -> pp_exc:handle(Cmd, Status, Bin);	
		"34" -> pp_syssetting:handle(Cmd, Status, Bin);        
		"35" -> pp_fst:handle(Cmd, Status, Bin); 
		"36" -> pp_ore:handle(Cmd,Status,Bin);
		"37" -> pp_answer:handle(Cmd,Status,Bin);
		"38" -> pp_achieve:handle(Cmd, Status, Bin);
		"39" -> pp_skyrush:handle(Cmd, Status, Bin);
        "40" -> pp_guild:handle(Cmd, Status, Bin);
        "41" -> pp_pet:handle(Cmd, Status, Bin);
		"42" -> pp_manor:handle(Cmd, Status, Bin); 
		"43" -> pp_td:handle(Cmd, Status, Bin);
		"44" -> pp_appraise:handle(Cmd, Status, Bin);
		"45" -> pp_war:handle(Cmd,Status,Bin);
		"46" -> pp_deputy:handle(Cmd,Status,Bin);
		"47" -> pp_castle_rush:handle(Cmd, PlayerState, Bin);
		"48" -> pp_marry:handle(Cmd, PlayerState, Bin);
		"49" -> pp_coliseum:handle(Cmd, PlayerState, Bin);
        "60" -> pp_gateway:handle(Cmd, Status, Bin);
        _ -> %%错误处理
            ?ERROR_MSG("Routing Error [~w].", [Cmd]),
            {error, "Routing failure"}
    end.

%% 获取用户信息
handle_call('PLAYER', _from, PlayerState) ->
    {reply, PlayerState#player_state.player, PlayerState};

%% 获取用户信息(按字段需求)
handle_call({'PLAYER', List}, _from, PlayerState) ->
	Ret = lib_player_rw:get_player_info_fields(PlayerState#player_state.player, List),
    {reply, Ret, PlayerState};

%% 检查A与B是否存在Rela关系
handle_call({is_exists, IdA, IdB, Rela}, _from, PlayerState) ->
	Ret = lib_relationship:export_is_exists(IdA, IdB, Rela),
    {reply, Ret, PlayerState};

%% 获取玩家好友列表
handle_call({relaship, PlayerId, TeamPid}, _from, PlayerState) ->
	Player = PlayerState#player_state.player,
	{RetReply, RetPlayerState} = 
		case is_pid(Player#player.other#player_other.pid_team) of
			false ->
				NewPlayer = Player#player{
        			other = Player#player.other#player_other{
            			pid_team = TeamPid,
						leader = 2							  
        			}						
    			},
				save_online_info_fields(NewPlayer, [{pid_team, TeamPid}, {leader, 2}]),
				NewPlayerState = PlayerState#player_state{
					player = NewPlayer			   
				},
				[{FriendList, _VipList2}] = lib_relationship:get_ets_rela_record(PlayerId, 1),
				Reply = [
					FriendList,
					Player#player.nickname,
					Player#player.scene,
					Player#player.x,
					Player#player.y,
					Player#player.lv,
					Player#player.realm,
					Player#player.other#player_other.pid_send,
					Player#player.career,
					Player#player.sex,
					Player#player.hp_lim,
					Player#player.mp_lim
				],
				{Reply, NewPlayerState};
			true ->
				{have_team, PlayerState}
		end,
    {reply, RetReply, RetPlayerState};

%% 检查此用户的好友数量
handle_call({count_fri}, _from, PlayerState) ->
	Player = PlayerState#player_state.player,
	{NewPlayer, _, Award} = lib_vip:get_vip_award(friend, Player),
	NewMaxFriends = Award + 50,
	L = lib_relationship:get_idA_list(Player#player.id, 1),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {reply, length(L) >= NewMaxFriends, NewPlayerState};

%% 在队伍中被T出封神台，或者在封神台中退出队伍
handle_call('FST_OUTTEAM', _from, PlayerState) ->
	Status = PlayerState#player_state.player,
	case lib_scene:is_fst_scene(Status#player.scene) orelse lib_scene:is_zxt_scene(Status#player.scene) of
		true ->
			NewStatus = lib_scene_fst:quit_fst(Status),
			NewPlayerState = PlayerState#player_state{
				player = NewStatus			   
			},
    		{reply, out_team, NewPlayerState};
		_ ->
			{reply, ok, PlayerState}
	end;

%%更新装备磨损信息   
%% %% Todo 这个是否还需要？
%% handle_call({'ATTRITION'}, _from, Status) ->
%%     NewEquip_attrit = Status#player.other#player_other.equip_attrit + 1,
%%     %% 每战斗十次，更新一次状态
%%     case NewEquip_attrit >= 10 of
%%         true ->
%%             %% 更新装备磨损状态
%%             case (catch gen_server:call(Status#player.other#player_other.pid_goods, 
%% 										{'attrit', Status, NewEquip_attrit})) of
%%                 {ok, NewStatus} ->
%%                     save_online(NewStatus);
%%                 _ ->
%%                     NewStatus = Status#player{
%%                         other=Status#player.other#player_other{equip_attrit = 0}
%%                     }
%%             end;
%%         false ->
%%             NewStatus = Status#player{
%%                 other=Status#player.other#player_other{equip_attrit = NewEquip_attrit}
%%             }
%%     end,
%%     {reply, NewStatus, NewStatus};

%% 获取我的物品列表信息
handle_call({'equit_list'}, _From, PlayerState) ->
	Status = PlayerState#player_state.player,
	EquipList = goods_util:get_equip_list(Status#player.id, 10, Status#player.equip),
	{reply, EquipList, PlayerState};

%% 远程调用获取玩家单个的系统配置
handle_call({'get_player_sys_setting', Type}, _From, PlayerState) ->
	Result = lib_syssetting:get_player_sys_setting(Type),
	{reply, Result, PlayerState};

%%判断好友关系(跨进程)
handle_call({'get_relationship', {IdA, IdB, Rela}}, _From, PlayerState) ->
	{Flag, Bool} = lib_relationship:find_is_exists(IdA, IdB, Rela),
	{reply, {Flag, Bool}, PlayerState};

%% 玩家得到(失去)魔核或者旗
handle_call({'UPDATE_FEATS_MARK_CALL', PlayerNutType, Param2, Type}, _From, PlayerState) ->
	Player = PlayerState#player_state.player,
	case Player#player.carry_mark >= 8 andalso Player#player.carry_mark =< 15 of
		true ->%%本身头上有东西，就不改了
			{reply, unchanged, PlayerState};
		false ->%%头上没东西，就获得打死的那个的魔核
			db_agent:mm_update_player_info([{carry_mark, PlayerNutType}],[{id, Player#player.id}]),
			NewPlayer= Player#player{carry_mark = PlayerNutType},
			%%通知客户端更新玩家属性
			%%通知所有玩家
			{ok,BinData2} = pt_12:write(12041, [NewPlayer#player.id,NewPlayer#player.carry_mark]),
			mod_scene_agent:send_to_area_scene(NewPlayer#player.scene,NewPlayer#player.x,NewPlayer#player.y, BinData2),
			if 
				Type =:= 1 andalso PlayerNutType =:= 11 ->
					#player{id = PlayerId,
							nickname = PlayerName,
							career = Career,
							sex = Sex} = NewPlayer,
					Param = [PlayerId, PlayerName, Career, Sex],
					lib_skyrush:send_skyrush_notice(8, Param);
				Type =:= 1 andalso PlayerNutType =:= 15 ->%%获得紫魔核广播
					[DiePlayerId, DiePlayerName, DieCareer, DieSex] = Param2,
					Param = [DiePlayerId, DiePlayerName, DieCareer, DieSex, 
							 Player#player.id, Player#player.nickname, Player#player.career, Player#player.sex],
					lib_skyrush:send_skyrush_notice(12, Param);
				true ->
					skip
			end,
			%%tips提示更新
			if
				PlayerNutType >= 8 andalso PlayerNutType =< 11 ->
					Color = PlayerNutType - 7,
					ParamTips = [Player#player.other#player_other.pid_send, Color],
					lib_skyrush:send_skyrush_tips(4, ParamTips);
				PlayerNutType >= 12 andalso PlayerNutType =< 15 ->
					Color = PlayerNutType - 11,
					ParamTips = [Player#player.other#player_other.pid_send, Color],
					lib_skyrush:send_skyrush_tips(5, ParamTips);
				true ->
					skip
			end,
			save_online(NewPlayer),%%保存ets
			%%跑速减小
			ResetPlayer = lib_player:count_player_speed(NewPlayer),
			lib_player:send_player_attribute(ResetPlayer, 1),
			NewPlayerState = PlayerState#player_state{
				player = ResetPlayer			   
			},
			{reply, changed, NewPlayerState}
	end;

%% 获取玩家的神器信息
handle_call({'get_deputy_equip_info'},_From,PlayerState) ->
	Player = PlayerState#player_state.player,
	DeputyEquipInfo = lib_deputy:get_deputy_equip_info(Player,Player#player.id),
	{reply, DeputyEquipInfo, PlayerState};

%% 指定角色执行一个事件(函数形式)
handle_call({event, {M, F, A}}, _From,PlayerState) ->
    Reply = erlang:apply(M, F, A),
	{reply , Reply,PlayerState};

%%是否够满足结婚条件
handle_call({'CAN_MARRY'},_From,PlayerState) ->
	Player = PlayerState#player_state.player,
	Reply = 
		case lib_marry:is_enough_coin(Player) of
			false ->{false,3};
			true ->
				case Player#player.sex =:= 1 of
					false -> {false,4};
					true -> {true,ok}
				end
		end,
	{reply ,Reply,PlayerState};

%%玩家杀死拥有冥王之灵的玩家，从而得到冥王之灵 
handle_call({'GOT_WARFARE_PLUTO'}, _From, PlayerState) ->
	Player = PlayerState#player_state.player,
%% 	%%?DEBUG("GOT_WARFARE_PLUTO:~p", [Player#player.carry_mark]),
%% 	spawn(fun()-> db_agent:mm_update_player_info([{carry_mark, 27}], [{id, Player#player.id}]) end),
	case Player#player.carry_mark of
		27 ->
			NPlayer = Player,
			%% 通知客户端更新玩家属性
			{ok, BinData12041} = pt_12:write(12041, [NPlayer#player.id, 27]),
			mod_scene_agent:send_to_area_scene(NPlayer#player.scene, NPlayer#player.x, NPlayer#player.y, BinData12041),
			lib_send:send_to_sid(NPlayer#player.other#player_other.pid_send, BinData12041),
			%%处理返回值	{NPName, NGName}
			Reply = {2, {NPlayer#player.id, NPlayer#player.nickname, NPlayer#player.lv,
						NPlayer#player.realm, NPlayer#player.career, NPlayer#player.sex, 
						NPlayer#player.guild_id, NPlayer#player.guild_name, NPlayer#player.other#player_other.pid}};
		_ ->
			case Player#player.hp > 0 andalso Player#player.scene =:= ?WARFARE_SCENE_ID of
				true ->
					%% 玩家卸下坐骑
					{ok, MountPlayer}= lib_goods:force_off_mount(Player),
					%% 通知客户端更新玩家属性
					{ok, BinData12041} = pt_12:write(12041, [MountPlayer#player.id, 27]),
					mod_scene_agent:send_to_area_scene(MountPlayer#player.scene, MountPlayer#player.x, MountPlayer#player.y, BinData12041),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData12041),
					PLutoPlayer = MountPlayer#player{
												 carry_mark = 27
												},
%% 					修改战斗模式为全体模式
					NPlayer = PLutoPlayer#player{pk_mode = 5},
%% 					更新玩家新模式
					ValueList = [{pk_mode, 5}],
					WhereList = [{id, PLutoPlayer#player.id}],
					db_agent:mm_update_player_info(ValueList, WhereList),
%% 					通知客户端
					{ok, PkModeBinData} = pt_13:write(13012, [1, 5]),
					lib_send:send_to_sid(PLutoPlayer#player.other#player_other.pid_send, PkModeBinData),

					%%因为玩家下线就立即消失的冥王之灵，因此不用保存到数据库了
					save_online_diff(Player,NPlayer),
					%%处理返回值	{NPid, NPName, NRealm, NCareer, NSex, NGid, NGName, NPPid}
					Reply = {1, {NPlayer#player.id, NPlayer#player.nickname, NPlayer#player.lv,
								 NPlayer#player.realm, NPlayer#player.career, NPlayer#player.sex, 
								 NPlayer#player.guild_id, NPlayer#player.guild_name, NPlayer#player.other#player_other.pid}};
				false ->%%死亡了
					NPlayer = Player,
					%%处理返回值	{NPName, NGName}
					Reply = {0, {Player#player.id, Player#player.nickname, Player#player.guild_name, Player#player.guild_id}}
			end
	end,
	NewPlayerState = 
		PlayerState#player_state{
								 player = NPlayer	
								},
	{reply, Reply, NewPlayerState};
		
%%查看玩家封神纪元tooltip
handle_call('{GET_PLAYER_ERA_TOOLTIP}',_From,PlayerState) ->
	Player = PlayerState#player_state.player,
	EraToolTip = lib_era:get_player_era_tooltip(Player, Player#player.id),
	{reply,EraToolTip,PlayerState};

handle_call(Event, From, PlayerState) ->
	?WARNING_MSG("Mod_player_call: /~p/~n",[[Event, From, PlayerState]]),
    {reply, ok, PlayerState}.

%% --------------------------------------------------------------------
%% Function: handle_cast/2
%% Description: Handling cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%%被加入黑名单
handle_cast({'IN_BLACK_LIST'}, PlayerState) ->
	Status = PlayerState#player_state.player,
	NewStatus = Status#player.other#player_other{blacklist = true},
	ets:insert(?ETS_ONLINE, NewStatus),
	NewPlayerState = PlayerState#player_state{
		player = NewStatus			   
	},
	{noreply, NewPlayerState};

%% 向玩家发送好友祝福
handle_cast({'GET_BLESS_TIMES', FriendId, FriendName, FriendLv}, PlayerState) ->
	Player = PlayerState#player_state.player,
	[BlessTimes, NewPlayerState] = lib_relationship:get_bless_time(PlayerState, Player),
	if
		BlessTimes < 31 andalso Player#player.lv > 24 ->
			Exp = data_bless_exp:get_bless(Player#player.lv),		
			{ok, BinData} = pt_14:write(14050, [FriendId, FriendName, FriendLv, Exp, BlessTimes]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		true ->
			skip
	end,
	{noreply, NewPlayerState};

%% 子socket断开消息
handle_cast({'SOCKET_CHILD_LOST', N}, PlayerState) ->
	Status = PlayerState#player_state.player,
	NewStatus =
		case N of
			2 ->
				F = fun(Pid) ->
					Pid ! {stop}
				end,
				lists:foreach(F, Status#player.other#player_other.pid_send2),
				Status#player{other=Status#player.other#player_other{socket2 = undefined,pid_send2 = []}};
			3 ->
				F = fun(Pid) ->
					Pid ! {stop}
				end,
				lists:foreach(F, Status#player.other#player_other.pid_send3),
				Status#player{other=Status#player.other#player_other{socket3 = undefined,pid_send3 = []}};
			_ -> 
				Status
		end,
	ets:insert(?ETS_ONLINE, NewStatus),
	NewPlayerState = PlayerState#player_state{
		player = NewStatus			   
	},
	{noreply, NewPlayerState};

%% 停止角色进程(Reason 为停止原因)
handle_cast({stop, Reason}, PlayerState) ->
	Status = PlayerState#player_state.player,
	{ok, BinData} = pt_10:write(10007, Reason),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	misc:cancel_timer(update_goods_buff_timer),	
    {stop, normal, PlayerState};

%% 取消战斗进程中打坐的状态
handle_cast({'CANCEL_SIT_STATUS'}, PlayerState) ->
	{ok, NewPlayer} = lib_player:cancelSitStatus(PlayerState#player_state.player),
	List = [
		{status, NewPlayer#player.status},
		{peach_revel, NewPlayer#player.other#player_other.peach_revel}		
	],
	save_online_info_fields(NewPlayer, List),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
	{noreply, NewPlayerState};

%%统一处理氏族事务
handle_cast({'GUILD_SET_AND_SEND', Type, Param}, PlayerState) ->
	NewStatus = lib_guild:guild_set_and_send(Type, Param, PlayerState#player_state.player),
	NewPlayerState = PlayerState#player_state{
		player = NewStatus			   
	},
	{noreply, NewPlayerState};

%%玩家被攻击收到消息后进行的处理
handle_cast({'PK_CALL_GUILDEHLP', AerRealm, AerGuildName, AerName, OSceneId, OX, OY}, PlayerState) ->
	Player = PlayerState#player_state.player,
	lib_guild_call:handle_pk_call_guildhelp(AerRealm, AerGuildName, AerName, OSceneId, OX, OY, Player),
	{noreply, PlayerState};

%% 角色氏族改名
handle_cast({'SET_GUILD_NAME', GuildName}, PlayerState) ->
	Status = PlayerState#player_state.player,
	NewStatus = Status#player{guild_name = tool:to_binary(GuildName)},
	NewPlayerState = PlayerState#player_state{
		player = NewStatus			   
	},
	{noreply, NewPlayerState};

%% 加入氏族
handle_cast({'guild', Event, _PlayerId}, PlayerState) ->
	lib_task:event(guild, Event, PlayerState#player_state.player),
	{noreply, PlayerState};

%% 设置用户信息
handle_cast({'SET_PLAYER', NewStatus}, PlayerState) when is_record(NewStatus, player)->
	save_online_diff(PlayerState#player_state.player, NewStatus),
	NewPlayerState = PlayerState#player_state{
		player = NewStatus			   
	},
	{noreply, NewPlayerState};

%% 设置用户信息(按字段+数值)
handle_cast({'SET_PLAYER', List}, PlayerState) when is_list(List) ->
	NewPlayer = lib_player_rw:set_player_info_fields(PlayerState#player_state.player, List),
	save_online_info_fields(NewPlayer, List),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
	{noreply, NewPlayerState};

%% 设置用户信息(战斗用)
handle_cast({'SET_PLAYER_FOR_BATTLE', List}, PlayerState) ->
	NewPlayer = lib_player_rw:set_player_info_fields(PlayerState#player_state.player, List),
	BattlePlayer = lib_battle:enter_battle_status(NewPlayer),
	ets:insert(?ETS_ONLINE, BattlePlayer),
	NewPlayerState = PlayerState#player_state{
		player = BattlePlayer			   
	},
	{noreply, NewPlayerState};

%% 设置用户封神台
handle_cast({'SET_PLAYER_FST', SceneId, FstPid}, PlayerState) ->
	Player = PlayerState#player_state.player,
	Fst_pid_list = lists:keydelete(SceneId, 1, Player#player.other#player_other.pid_fst),
	FstPidList = lists:keymerge(1, Fst_pid_list, [{SceneId, FstPid}]), 
	NewPlayer = Player#player{
		other = Player#player.other#player_other{
			pid_fst = FstPidList, 
			pid_dungeon = FstPid
		}
	},
	mod_delayer:update_delayer_info(NewPlayer#player.id, FstPid, FstPidList, NewPlayer#player.other#player_other.pid_team),
	save_online_info_fields(NewPlayer, [{pid_fst, FstPidList}, {pid_dungeon, FstPid}]),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
	{noreply, NewPlayerState};

%% 通知客户端增减金钱(不用写数据库，在外部已经写入)
handle_cast( {'CHANGE_MONEY', [Field, Optype, Value, Source]}, PlayerState) ->
	Player = PlayerState#player_state.player,
	{ok, BinData} =  pt_13:write(13017, [Player#player.id, Field, Optype, Value, Source]),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	[Gold, Cash, Coin, Bcoin] = db_agent:get_player_money(Player#player.id),
	RetPlayer = 
		case Field of
			1 ->
				if Optype =:= 1 andalso Field =:= 1->	
					   NewScore = lib_player:get_player_pay_gold(Player#player.id),
					   %%通知客户端改变积分
					   {ok, BinData13017} =  pt_13:write(13017, [Player#player.id, 5, Optype, NewScore, Source]),
					   lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData13017),
					   NewScore;
				   true ->
					   skip
				end,
				NewPlayer = Player#player{gold = Gold},
				save_online_info_fields(NewPlayer, [{gold, Gold}]),
				NewPlayer;
			2 ->
				NewPlayer = Player#player{coin = Coin},
				save_online_info_fields(NewPlayer, [{coin, Coin}]),
				NewPlayer;
			3 ->
				NewPlayer = Player#player{cash = Cash},
				save_online_info_fields(NewPlayer, [{cash, Cash}]),
				NewPlayer;
			4 ->
				NewPlayer = Player#player{bcoin = Bcoin},
				save_online_info_fields(NewPlayer, [{bcoin, Bcoin}]),
				NewPlayer;
			_ -> 
				Player
		end,
	save_online_diff(Player, RetPlayer),
	NewPlayerState = PlayerState#player_state{
		player = RetPlayer			   
	},
	{noreply, NewPlayerState};

%% 战斗中神器技能的效果影响
handle_cast({'DEPUTY_SKILL_EFFECT',Data},PlayerState) ->
	Player = PlayerState#player_state.player,
	RetPlayer = 
	case Data of
		{speed,Mount,NewSpeed,Speed,Interval} ->
			case get(change_speed_timer) of
				[undefined, _, _] ->
						skip;
				[OldChangeSpeedTimer, _Sp, _Mnt] ->
						erlang:cancel_timer(OldChangeSpeedTimer)
			end,
			{ok, BinData} =  pt_20:write(20009, [Player#player.id, NewSpeed]),
            mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, BinData),
			NewPlayer = Player#player{speed = NewSpeed},	
            ChangeSpeedTimer = erlang:send_after(Interval, self(), {'CHANGE_SPEED', Speed, Mount}),
			put(change_speed_timer, [ChangeSpeedTimer, Speed, Mount]),
			%%save_online_info_fields(NewPlayer, [{speed, NewSpeed}]),
			Now = util:unixtime(),
			SkillInfo = {deputy_skill_90004, 0, Now + trunc(Interval / 1000), 90004, 1},
			Buff = Player#player.other#player_other.battle_status,
    		NewBuff = 
        		case lists:keyfind(deputy_skill_90004, 1, Buff) of
            		false ->
                		[SkillInfo | Buff];
            		_ -> 
                		lists:keyreplace(deputy_skill_90004, 1, Buff, SkillInfo)
        		end,
    		lib_player:refresh_player_buff(NewPlayer#player.other#player_other.pid_send, NewBuff, Now),
			mod_player:save_online_info_fields(NewPlayer, [{battle_status, NewBuff},{speed, NewSpeed}]),
			NewPlayer#player{
        		other = NewPlayer#player.other#player_other{
            		battle_status = NewBuff							  
        		}						
    		};
		{add_prof,N} ->
			lib_deputy:add_deputy_equip_prof_val(Player#player.id ,N),
			Player;
%% 		{mp_hurt,NewMp} ->
%% 			NewPlayer = Player#player{mp = NewMp},
%% 			save_online_info_fields(NewPlayer, [{mp, NewMp}]),
%%             NewPlayer;
		_ ->
			Player
	end,
	NewPlayerState = PlayerState#player_state{
		player = RetPlayer			   
	},
	{noreply, NewPlayerState};
	
%% 指定角色执行一个操作(函数形式)
handle_cast({cast, {M, F, A}}, PlayerState) ->
    case erlang:apply(M, F, [PlayerState#player_state.player | A]) of
        {ok, NewStatus} ->
            %save_online_diff(PlayerState#player_state.player, NewStatus),
			NewPlayerState = PlayerState#player_state{
				player = NewStatus			   
			},
			{noreply, NewPlayerState};
        _ ->
            {noreply, PlayerState}
    end;

%% 指定角色执行一个事件(函数形式)
handle_cast({event, {M, F, A}}, PlayerState) ->
    erlang:apply(M, F, A),
	{noreply, PlayerState};

%% 查询其他玩家信息
handle_cast({'GET_OTHER_PLAYER_INFO', Id, PidSend}, PlayerState) ->
	spawn(fun()-> lib_player:get_other_player_info(PlayerState#player_state.player, Id, PidSend) end),
	{noreply, PlayerState};

%% 场景的PID改变了
handle_cast({change_pid_scene, ScenePid, SceneId}, PlayerState) ->
	Player = PlayerState#player_state.player,
	NewPlayer = Player#player{
		other = Player#player.other#player_other{
			pid_scene = ScenePid
		}
	},
	RetPlayerState =
		case lib_scene:is_dungeon_scene(SceneId) orelse lib_cave:is_cave_scene(SceneId) of
			true ->
				ResSceneId = lib_scene:get_res_id_for_run(Player#player.scene),
				DungeonTimes = lib_dungeon:get_dungeon_times(Player#player.id, Player#player.lv, ResSceneId),
				DungeonExp =
					if
						DungeonTimes > 3 ->
							0;
						true ->
							1
					end,
				PlayerState#player_state{
					dungeon_exp = DungeonExp		   
				};
			false ->
				PlayerState
		end,
	NewPlayerState = RetPlayerState#player_state{
		player = NewPlayer			   
	},
	{noreply, NewPlayerState};

%% 在队伍中被T出封神台
handle_cast('FST_KICK', PlayerState) ->
	NewStatus = lib_scene_fst:quit_fst(PlayerState#player_state.player),
	NewPlayerState = PlayerState#player_state{
		player = NewStatus			   
	},
	{noreply, NewPlayerState};

%% 封神台记录更新
%% Loc 封神台层数
%% ThruTime 通关时间
%% BC 是否广播
handle_cast({'SET_FST_GOD', Loc, ThruTime, Action, BC}, PlayerState) ->
	Player = PlayerState#player_state.player,
	spawn(fun()-> lib_scene_fst:set_fst_god(Player, Action, Loc, ThruTime, BC) end),
    {noreply, PlayerState};

%% 增加经验
handle_cast({'EXP', Exp, Spirit, From}, PlayerState) ->
	NewStatus = lib_player:add_exp(PlayerState#player_state.player, Exp, Spirit, From),
	NewPlayerState = PlayerState#player_state{
		player = NewStatus			   
	},
	{noreply, NewPlayerState};

%% 增加经验
handle_cast({'EXP', Exp, Spirit}, PlayerState) ->
    NewStatus = lib_player:add_exp(PlayerState#player_state.player, Exp, Spirit, 1),
	NewPlayerState = PlayerState#player_state{
		player = NewStatus			   
	},
	{noreply, NewPlayerState};

%% 清除玩家灵兽幸运值
handle_cast({'CLEAY_PET_LUCKY_VALUE'}, PlayerState) ->
    NewStatus = PlayerState#player_state.player,
	Ets_Pet_Extra = lib_pet:get_pet_extra(NewStatus#player.id),
	Ets_Pet_Extra1 = Ets_Pet_Extra#ets_pet_extra{lucky_value = 0},
	lib_pet:update_pet_extra(Ets_Pet_Extra1),
	{noreply, PlayerState};

%% 清除玩家坐骑幸运值清0
handle_cast({'CLEAY_MOUNT_LUCKY_VALUE'}, PlayerState) ->
	NewStatus = PlayerState#player_state.player,
	lib_mount:clear_mount_lucky_value(NewStatus#player.id),
	{noreply, PlayerState};


%% 增加经验
handle_cast({'EXP_FROM_MON', Exp, Spirit, HookExp, HookSpt, SceneType, MonType, MonTypeId}, PlayerState) ->
	Player = PlayerState#player_state.player,
	%% 杀怪成就
	lib_achieve:kill_mon_achieve(Player#player.id, Player#player.other#player_other.pid, Player#player.other#player_other.pid_send, MonType, MonTypeId),
	[NewExp, NewSpt, AddType] = 
		case SceneType of
			%% 在副本
			1 ->
				%% 是否有前3次副本经验加成
				DungeonParam = 
					if
						PlayerState#player_state.dungeon_exp /= 1 ->
							1;
						true ->
							30
					end,
				[Exp * DungeonParam, Spirit * DungeonParam, 1];
			%% 神魔乱斗
			9 ->
				[Exp, Spirit, 21];
			_ ->
				case lib_hook:check_max_exp_time_limit(Player, Player#player.scene) of
					false ->
						IsTrainingScene = lib_scene:is_training_scene(Player#player.scene),
						if
							IsTrainingScene ->%%试炼副本
								[TExp,TSpi] = data_training:get_training_mon_exp_spi(Player#player.lv,MonTypeId),
								[TExp,TSpi,1];
							true ->
								%% 是否在双倍经验活动时间
								case SceneType == 0 andalso lib_player:is_exp_activity() of
									true ->
										[Exp * 2, Spirit, 1];
									false ->
										[Exp, Spirit, 1]
								end
						end;
					true ->
						[HookExp, HookSpt, 1]
				end
		end,
    NewPlayer = lib_player:add_exp(Player, NewExp, NewSpt, AddType),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
	{noreply, NewPlayerState};

%% 组队经验共享
handle_cast({'SHARE_TEAM_EXP', [{TeamNum, CloseParam}, PlayerId, MonExp, MonSpirit, HookExp, HookSpt, MonId, SceneId, X, Y, MonLv, SceneType, MonType, MonTypeId]}, PlayerState) ->
	Player = PlayerState#player_state.player,
	X1 = X + ?TEAM_X_RANGE,
    X2 = X - ?TEAM_X_RANGE,
    Y1 = Y + ?TEAM_Y_RANGE,
    Y2 = Y - ?TEAM_Y_RANGE,
	PX = Player#player.x,
   	PY = Player#player.y,
	NewPlayer = 
        case Player#player.scene == SceneId of
			false ->%%不在同一场景
				Player;
			true ->%%在同一场景，有成就+的
				lib_achieve:kill_mon_achieve(Player#player.id, Player#player.other#player_other.pid, Player#player.other#player_other.pid_send, MonType, MonTypeId),
				case PX < X1 andalso PX > X2 andalso PY < Y1 andalso PY > Y2 of
					true ->
						[NewMonExp, NewMonSpt] = 
							case SceneType of
								%% 在副本
								1 ->
									ESAddType = 1,%%经验灵力增加类型
									[AttLv, AttParam] = [30,30],
									[LvExp, LvSpt] =
										case abs(Player#player.lv - MonLv) > AttLv of
											true ->
												[round(MonExp / AttParam), round(MonSpirit / AttParam)];
											false ->
												[MonExp, MonSpirit]
										end,
									%% 角色杀掉怪物
									case PlayerId == Player#player.id of
										true ->
											skip;
										false ->
											gen_server:cast(Player#player.other#player_other.pid_task,{'kill_mon',Player,MonId,MonLv})
									end,
									%% 组队副本加成
									TeamParam = lib_team:extra_team_exp_spt(TeamNum),
									%% 是否有前3次副本经验加成
									DungeonParam = 
										if
											PlayerState#player_state.dungeon_exp /= 1 ->
												1;
											true ->
												30
										end,
									[round(LvExp * TeamParam * DungeonParam * CloseParam), round(LvSpt * TeamParam * DungeonParam)];
								
								%% 封神台
								3 ->
									ESAddType = 1,%%经验灵力增加类型
									%% 角色杀掉怪物
									case PlayerId == Player#player.id of
										true ->
											skip;
										false ->
											gen_server:cast(Player#player.other#player_other.pid_task,{'kill_mon',Player,MonId,MonLv})
									end,
									%% 组队副本加成
									TeamParam = lib_team:extra_team_exp_spt(TeamNum),
									[round(MonExp * TeamParam), round(MonSpirit * TeamParam)];
								%% 诛仙台
								8 ->
									ESAddType = 1,%%经验灵力增加类型
									%% 角色杀掉怪物
									case PlayerId == Player#player.id of
										true ->
											skip;
										false ->
											gen_server:cast(Player#player.other#player_other.pid_task,{'kill_mon',Player,MonId,MonLv})
									end,
									%% 组队副本加成
									TeamParam = lib_team:extra_team_exp_spt(TeamNum),
									[round(MonExp * TeamParam), round(MonSpirit * TeamParam)];
								%% 神魔乱斗
								9 ->
									ESAddType = 21,%%经验灵力增加类型
									%% 角色杀掉怪物
									%% 组队副本加成
									TeamParam = lib_team:extra_team_exp_spt(TeamNum),
									case PlayerId == Player#player.id of
										true ->
											[util:ceil(MonExp * CloseParam * TeamParam), util:ceil(MonSpirit * TeamParam)];
										false ->
											gen_server:cast(Player#player.other#player_other.pid_task, {'kill_mon', Player, MonId, MonLv}),
											[util:ceil(MonExp * CloseParam * TeamParam), util:ceil(MonSpirit * TeamParam)]
									end;
								_ ->
									ESAddType = 1,%%经验灵力增加类型
									IsTrainingScene = lib_scene:is_training_scene(Player#player.scene),
									[NewExp, NewSpt] = 
										case lib_hook:check_max_exp_time_limit(Player, Player#player.scene) of
											false -> 
												%% 在试炼副本
												case IsTrainingScene of
													true ->
														[TExp,TSpi] = data_training:get_training_mon_exp_spi(Player#player.lv,MonTypeId),
														[TExp,TSpi];
													false ->
														[AttLv, AttParam] = [4, 3],
														case abs(Player#player.lv - MonLv) > AttLv of
															true ->
																[trunc(MonExp / AttParam), trunc(MonSpirit / AttParam)];
															false ->
																[MonExp, MonSpirit]
														end
												end;
											true ->
												[AttLv, AttParam] = [4, 6],
												case abs(Player#player.lv - MonLv) > AttLv of
													true ->
														[trunc(HookExp / AttParam), trunc(HookSpt / AttParam)];
													false ->
														[HookExp, HookSpt]
												end
										end,
									%% 在试炼副本跟副本组队一样有经验加成 ps试炼副本不是副本
									case IsTrainingScene of
										true ->
											%% 组队副本加成
											TeamParam = lib_team:extra_team_exp_spt(TeamNum),
											case PlayerId == Player#player.id of
												true ->
													skip;
												false ->
													gen_server:cast(Player#player.other#player_other.pid_task,{'kill_mon',Player,MonId,MonLv})
											end,
											[round(NewExp * TeamParam * CloseParam),round(NewSpt * TeamParam)];
										%% 一般情况跑到这里
										false ->
											%% 角色杀掉怪物
											case PlayerId == Player#player.id of
												true ->
													%% 是否在双倍经验活动时间
													case SceneType == 0 andalso lib_player:is_exp_activity() of
														true ->
															[NewExp * 2 * CloseParam, NewSpt];
														false ->
															[NewExp * CloseParam, NewSpt]
													end;
												false ->
													gen_server:cast(Player#player.other#player_other.pid_task, {'kill_mon', Player, MonId, MonLv}),
													[util:ceil(NewExp * 0.025 * CloseParam), util:ceil(NewSpt * 0.025)]
											end
									end
							end,
						lib_player:add_exp(Player, NewMonExp, NewMonSpt, ESAddType);
					_ ->
						Player  
				end
		end,
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
	{noreply, NewPlayerState};

%% 劫商增加经验
handle_cast({'business', Exp, Spt}, PlayerState) ->
	NewPlayer = lib_player:add_exp(PlayerState#player_state.player, Exp, Spt, 0),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
	{noreply, NewPlayerState};


%%仙侣情缘扣除玩家元宝，或者亲密度
handle_cast({'del_gold_close',Pid,Type},PlayerState)->
	case Type of
		1->
			{ok,NewPlayerStatus} = lib_love:del_invite_gold(PlayerState#player_state.player,30),
			lib_player:send_player_attribute(NewPlayerStatus, 1),
		    lib_love:invite_msg_gold(NewPlayerStatus,30),
			NewPlayerState = PlayerState#player_state{
									player = NewPlayerStatus			   
								};
		2->NewPlayerState = PlayerState;
		3->
			lib_relationship:del_close_etsonly(PlayerState#player_state.player#player.id,Pid,10),
			NewPlayerState = PlayerState;
		_->NewPlayerState = PlayerState
	end,
	{noreply, NewPlayerState};

%% 仙侣情缘共享经验
handle_cast({'love_share_exp', Exp, Spt}, PlayerState) ->
	NewPlayer = lib_player:add_exp(PlayerState#player_state.player, Exp, Spt, 0),
	lib_player:send_player_attribute(NewPlayer, 1),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
	{noreply, NewPlayerState};

%% 25副本直接传送
handle_cast({'DELIVER_TEAM', Bin, SceneId}, PlayerState)->
	Player = PlayerState#player_state.player,
	case lib_deliver:could_deliver(Player) of
		ok ->
			{ok, BinData} = pt_24:write(24031, [SceneId, 1]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		_ ->
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, Bin)
	end,
    {noreply, PlayerState};

%% 开启默契度测试定时器
handle_cast({'start_privity_test_timer', Timestamp}, PlayerState)->
	erlang:send_after(Timestamp * 1000, self(), end_privity_test),
	{noreply, PlayerState};

%% 更新默契度测试信息
handle_cast({'update_privity_info', PrivityInfo, StartTimer, Timestamp}, PlayerState)->
	NewPlayer = lib_love:update_privity(PlayerState#player_state.player, PrivityInfo),
	save_online_info_fields(NewPlayer, [{privity_info, PrivityInfo}]),
	case StartTimer of
		true->
			erlang:send_after(Timestamp * 1000, self(), end_privity_test);
		false->
			skip
	end,
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
	{noreply, NewPlayerState};

%% 默契度测试奖励
handle_cast({'privity_award', Privity}, PlayerState) ->
	RetPlayer = lib_love:privity_award(PlayerState#player_state.player, Privity),
	NewPlayer = lib_love:update_privity(RetPlayer, []),
	lib_player:send_player_attribute(NewPlayer, 1),
	save_online_info_fields(NewPlayer, [{privity_info, []}, {spirit, NewPlayer#player.spirit}]),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
	{noreply, NewPlayerState};

%% 结束默契度测试
handle_cast({'privity_finish', Privity}, PlayerState) ->
	RetPlayer = lib_love:privity_award(PlayerState#player_state.player, Privity),
	NewPlayer = lib_love:update_privity(RetPlayer, []),
	lib_player:send_player_attribute(NewPlayer, 1),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
	{noreply, NewPlayerState};

%% 增加魅力值
handle_cast({'add_charm', Charm}, PlayerState) ->
	NewPlayer = lib_love:get_evaluate(PlayerState#player_state.player, Charm),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
	{noreply, NewPlayerState};

%% 周年掉落
handle_cast({'ONE_YEAR_DROP_GOODS', SceneId, MonId, DropGoods}, PlayerState) ->
	Player = PlayerState#player_state.player,
	if
		Player#player.scene =:= SceneId ->
			DropId = ?MON_LIMIT_NUM * 2 + Player#player.id,
			PlayerData = [
       			Player#player.id,
            	Player#player.nickname,
            	Player#player.career,
            	Player#player.sex,
            	Player#player.realm,
           		Player#player.scene,
           		Player#player.other#player_other.pid_team,
          		Player#player.other#player_other.pid_scene,
          		Player#player.other#player_other.pid_send,
           		Player#player.other#player_other.socket
     		],
 			gen_server:cast(Player#player.other#player_other.pid_goods, 
     			{'HOOK_GIVE_GOODS', DropGoods, PlayerData, DropId, MonId, Player#player.x, Player#player.y, 0});
		true ->
			skip
	end,
	{noreply, PlayerState};

handle_cast({'NOTICES_TITLE_CHANGE', TNum}, PlayerState) ->
	Player = PlayerState#player_state.player,
	NPlayer = lib_title:notices_title_change(TNum, Player),
	NewPlayerState = 
				PlayerState#player_state{
										 player = NPlayer			 
										},
	{noreply, NewPlayerState};
			
			

%% 开始挂机区挂机计时
handle_cast({'start_hooking', SceneId}, PlayerState) ->
	lib_hook:start_hooking(PlayerState#player_state.player, SceneId),
%% 	misc:cancel_timer(hook_send_out_timer),
%% 	SendOutTimer = erlang:send_after(lib_hook:send_out_time(),self(),{'HOOK_SECNE_SEND_OUT'}),
%% 	put(hook_send_out_timer,SendOutTimer),
	{noreply, PlayerState};

%% 停止挂机区挂机计时
handle_cast({'end_hooking', SceneId}, PlayerState) ->
	Player = PlayerState#player_state.player,
	lib_hook:end_hooking(Player#player.id, SceneId),
%% 	misc:cancel_timer(hook_send_out_timer),
	{noreply, PlayerState};

%% 物品BUFF持续效果
handle_cast({'buff_AddHPMP', GoodsInfo}, PlayerState) ->
	Player = PlayerState#player_state.player,
	if
		Player#player.hp > 0 ->
			{ok, NewPlayer} = lib_goods_use:useHPMP(Player, GoodsInfo, 1),
			save_online_info_fields(NewPlayer, [{hp, NewPlayer#player.hp}, {mp, NewPlayer#player.mp}]),
			NewPlayerState = PlayerState#player_state{
				player = NewPlayer			   
			},
			{noreply, NewPlayerState};
		true ->
			{noreply, PlayerState}
	end;

%% 发送信息到socket端口
handle_cast({send_to_sid, Bin}, PlayerState) ->
	Player = PlayerState#player_state.player,
 	lib_send:send_to_sid(Player#player.other#player_other.pid_send, Bin),
    {noreply, PlayerState};

%% 发送信息到socket2端口
handle_cast({send_to_sid2, Bin}, PlayerState) ->
	Player = PlayerState#player_state.player,
	case Player#player.other#player_other.pid_send2 of
		[] ->
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, Bin);
		_ ->
			lib_send:send_to_sid(Player#player.other#player_other.pid_send2, Bin)
	end,
	{noreply, PlayerState};

%% 发送信息到socket3端口
handle_cast({send_to_sid3, Bin}, PlayerState) ->
	Player = PlayerState#player_state.player,
	case Player#player.other#player_other.pid_send3 of
		[] ->
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, Bin);
		_ ->
			lib_send:send_to_sid(Player#player.other#player_other.pid_send3, Bin)
	end,
	{noreply, PlayerState};

%% 发出的好友请求，被接受
handle_cast({request_friend_ok, BinData, RequestId, ResponseId, Id, Close}, PlayerState) ->
	pp_relationship:response_friend_request(BinData, RequestId, ResponseId, Id, PlayerState#player_state.player, Close),
    {noreply, PlayerState};

%% 要求对方进程删除好友信息
handle_cast({request_friend_del, Rid, Id, Rela}, PlayerState) ->
	pp_relationship:response_friend_delete(Rid, Id, PlayerState#player_state.player,Rela),
    {noreply, PlayerState};

%%对方删除自己时
handle_cast({add_special, Rela}, PlayerState) ->
	
	Player = PlayerState#player_state.player,
	{DbId,_P,_R} = Rela#ets_rela.id,
	IdB = Rela#ets_rela.pid,
	NewRela = Rela#ets_rela{id = {DbId,Player#player.id,4}, pid = Player#player.id, rid = IdB, rela = 4},
    ets:insert(?ETS_RELA, NewRela),
    {noreply, PlayerState};

%% 处理好友祝福
handle_cast({request_bless_process, Bless_id, Nick, Lv, Type}, PlayerState) ->
	NewPlayerState = pp_relationship:response_bless_process(Bless_id, Nick, Lv, Type, PlayerState),
	NewPlayer = NewPlayerState#player_state.player,
	%% 发送祝福增加5点亲密度
    spawn(fun()-> 
        TaTeamId =
            case lib_player:get_online_info_fields(Bless_id, [pid_team]) of
                [] ->undefined;
                [PidTeam] -> PidTeam
            end,
        case lib_relationship:find_is_exists(NewPlayer#player.id, Bless_id, 1) of
            {_Id, true} ->
                lib_relationship:close(bless,NewPlayer#player.id,Bless_id,[5,NewPlayer#player.other#player_other.pid_team,TaTeamId]);		
            {ok,false} -> 
                skip
        end 
    end),
	{noreply, NewPlayerState};

%% 响应好友祝福处理
handle_cast({request_bless_result, PlayerId, Plv, Res}, PlayerState) ->
	NewPlayerState = pp_relationship:response_bless_result(PlayerId, Plv, Res, PlayerState),
	{noreply, NewPlayerState};

%% 设置禁言 或 解除禁言
handle_cast({set_donttalk, StopBeginTime, StopChatMinutes}, PlayerState) ->
	put(donttalk, [StopBeginTime, StopChatMinutes]),
    {noreply, PlayerState};	

%% 被传送出副本
handle_cast({send_out_dungeon, [SceneId, X, Y]}, PlayerState) ->
	Player = PlayerState#player_state.player,
	[NewSceneId, NX, NY] =
		case get(sce_b4_dg) of
			undefined ->
				[SceneId, X, Y];
			Scid ->
				case lists:member(Scid, [201, 251, 281]) of
					true ->
						put(sce_b4_dg, undefined),
						[Scid, 57, 151];
					false ->
						%% 雷泽分线处理
						case lists:member(Scid, [101, 190, 191]) of
							true ->
								put(sce_b4_dg, undefined),
								[Scid, X, Y];
							false ->
								[SceneId, X, Y]
						end
				end
		end,
	%% 记录目的XY
	put(change_scene_xy , [NX, NY]),
    mod_scene:leave_scene(Player#player.id, Player#player.scene, 
						  Player#player.other#player_other.pid_scene,
						  Player#player.x, Player#player.y),
	ResSceneId = 
		case lists:member(NewSceneId, [101, 190, 191]) of
			%% 雷泽分线处理
			true ->
				101;
			false ->
    			NewSceneId
		end,
	{ok, BinData} = pt_12:write(12005, [NewSceneId, NX, NY, <<>>, ResSceneId, 0, 0, 0]),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	%% 判断是否在挂机
	HookPlayer = lib_hook:cancel_hoook_status(Player),
    NewPlayer = HookPlayer#player{
		scene = NewSceneId,
		x = NX, 
		y = NY,
		other = Player#player.other#player_other{
			pid_dungeon = undefined
		}
	},
	List = [
		{scene, NewSceneId},
		{x, NX},
		{y, NY},
		{status, NewPlayer#player.status},
		{pid_dungeon, undefined}	
	],
	save_online_info_fields(NewPlayer, List),
    save_player_table(NewPlayer),
	mod_delayer:update_delayer_info(Player#player.id, undefined, Player#player.other#player_other.pid_fst, Player#player.other#player_other.pid_team),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer,
		dungeon_exp = 0			   
	},
	{noreply, NewPlayerState};

%% 被传送出封神台
handle_cast({send_out_fst, [SceneId, X, Y]}, PlayerState) ->
	Player = PlayerState#player_state.player,
%% 	?DEBUG("FST SEND OUT PLAYER  ->>>>>!!!  PLAYERID = ~p~n",[Player#player.id]),
    {ok, BinData} = pt_12:write(12005, [SceneId, X, Y, <<>>, SceneId, 0, 0, 0]),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	pp_scene:handle(12004, Player, Player#player.scene),
	put(change_scene_xy , [X, Y]),%%记录目标XY坐标
    
	%% 判断是否在挂机
	HookPlayer = lib_hook:cancel_hoook_status(Player),
	
	NewPlayer = HookPlayer#player{
		scene = SceneId, 
		x = X, 
		y = Y,
		other = Player#player.other#player_other{
			pid_fst = [], 
			pid_dungeon = undefined
		}
	},
	List = [
		{scene, SceneId},
		{x, X},
		{y, Y},
		{status, NewPlayer#player.status},
		{pid_fst, []},
		{pid_dungeon, undefined}
	],
	save_online_info_fields(NewPlayer, List),
    save_player_table(NewPlayer),
	mod_delayer:update_delayer_info(Player#player.id, undefined, [], Player#player.other#player_other.pid_team),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%% 被传送出封神台
handle_cast({send_out_fst_mail, [BinData,SceneId,FstPid]}, PlayerState) ->
	Player = PlayerState#player_state.player,
	NowFstPid = 
		case lists:keyfind(SceneId, 1, Player#player.other#player_other.pid_fst) of
			false->
				undefined;
			{_SceneId, Fst_pid}->Fst_pid;
			_->undefined
		end,
	NewPlayer =
		if
			SceneId =:= Player#player.scene rem 10000 andalso FstPid ==NowFstPid->
				case Player#player.other#player_other.pid_team =/= undefined of
					true ->
						gen_server:cast(Player#player.other#player_other.pid_team, {'MEMBER_FST_QUIT',[Player#player.other#player_other.pid,Player#player.scene]});
					false ->
						skip
				end,
				lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
				lib_scene_fst:quit_fst(Player);
			true ->
    			Player
		end,
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%%同步封神台时间
handle_cast({sync_fst_time, [SceneId,BinData]}, PlayerState) ->
	Player = PlayerState#player_state.player,
	if SceneId =:= Player#player.scene rem 10000 ->
		   lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
	   true ->
		   skip
	end,
    {noreply, PlayerState};

%% 被传送出镇妖台
handle_cast({send_out_td, [SceneId, X, Y]}, PlayerState) ->
	Player = PlayerState#player_state.player,
    mod_scene:leave_scene(Player#player.id, Player#player.scene, 
						  Player#player.other#player_other.pid_scene,
						  Player#player.x, Player#player.y),
	{ok, BinData} = pt_12:write(12005, [SceneId, X, Y, <<>>, SceneId, 0, 0, 0]),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
    
	%% 判断是否在挂机
	HookPlayer = lib_hook:cancel_hoook_status(Player),
	
	NewPlayer = HookPlayer#player{
		scene = SceneId, 
		x = X, 
		y = Y,
		other = Player#player.other#player_other{
			pid_dungeon = undefined
		}
	},	
	List = [
		{scene, SceneId},
		{x, X},
		{y, Y},
		{status, NewPlayer#player.status},
		{pid_dungeon, undefined}
	],
	save_online_info_fields(NewPlayer, List),
    save_player_table(NewPlayer),
	mod_delayer:update_delayer_info(Player#player.id, undefined, Player#player.other#player_other.pid_fst, Player#player.other#player_other.pid_team),
  	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%% 被传出试炼副本
handle_cast({send_out_training, [SceneId, X, Y]}, PlayerState) ->
	Player = PlayerState#player_state.player,
    mod_scene:leave_scene(Player#player.id, Player#player.scene, 
						  Player#player.other#player_other.pid_scene,
						  Player#player.x, Player#player.y),
	{ok, BinData} = pt_12:write(12005, [SceneId, X, Y, <<>>, SceneId, 0, 0, 0]),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	
	%% 判断是否在挂机
	HookPlayer = lib_hook:cancel_hoook_status(Player),
	
	NewPlayer = HookPlayer#player{
		scene = SceneId, 
		x = X, 
		y = Y,
		other = Player#player.other#player_other{
			pid_dungeon = undefined
		}
	},	
	List = [
		{scene, SceneId},
		{x, X},
		{y, Y},
		{status, NewPlayer#player.status},
		{pid_dungeon, undefined}
	],
	save_online_info_fields(NewPlayer, List),
    save_player_table(NewPlayer),
	mod_delayer:update_delayer_info(Player#player.id, undefined, Player#player.other#player_other.pid_fst, Player#player.other#player_other.pid_team),
	lib_task:event(lover_train,null,NewPlayer),
    NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%% 封神台闯关播报
handle_cast({'BC_FST_KILL_BOSS', Loc, MonName}, PlayerState) ->
	Player = PlayerState#player_state.player,
	NameColor = data_agent:get_realm_color(Player#player.realm),
	case lib_scene:is_fst_scene(Player#player.scene) of
		true->
			ConTent = io_lib:format("【<a href='event:1, ~p, ~s, ~p, ~p'><font color='~s'><u>~s</u></font></a>】单枪匹马杀入封神台第<font color='#FFFF32'>~p</font>层，成功打败<font color='#8800FF'> ~s </font>，闯关成功。",
				[Player#player.id, Player#player.nickname, Player#player.career, Player#player.sex, NameColor, Player#player.nickname, Loc, MonName]),
			lib_chat:broadcast_sys_msg(2, ConTent);
		false->
			NewLoc = Loc - 45,
			if 
				NewLoc >= 18->
					ConTent = io_lib:format("【<a href='event:1, ~p, ~s, ~p, ~p'><font color='~s'><u>~s</u></font></a>】单枪匹马杀入诛仙台第<font color='#FFFF32'>~p</font>层，成功打败<font color='#8800FF'> ~s </font>，闯关成功。",
						[Player#player.id, Player#player.nickname, Player#player.career, Player#player.sex, NameColor, Player#player.nickname, NewLoc, MonName]),
					lib_chat:broadcast_sys_msg(2, ConTent);
			   	true ->
					skip
			end
	end,
    {noreply, PlayerState};

%% 被请出了氏族领地
handle_cast({send_out_manor, _SceneId, Type}, PlayerState) ->
	Player = PlayerState#player_state.player,
	{SceneId, X, Y} = lib_guild_manor:get_manor_sentout_coord(2, Player#player.id),
	mod_scene:leave_scene(Player#player.id, Player#player.scene, 
						  Player#player.other#player_other.pid_scene,
						  Player#player.x, Player#player.y),
	
    {ok, BinData} = pt_12:write(12005, [SceneId, X, Y, <<>>, SceneId, 0, 0, 0]),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	NewPlayer = Player#player{
		scene = SceneId, 
		x = X, 
		y = Y
	},	
	List = [
		{scene, SceneId},
		{x, X},
		{y, Y}
	],
	save_online_info_fields(NewPlayer, List),
    save_player_table(NewPlayer),	
	%% 被请出了的，直接删除相关的玩家数据
	case Type of
		1 ->
			spawn(fun()-> db_agent:delete_guild_manor_cd(Player#player.id) end);
		0 ->
			no_action
	end,
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};
	
handle_cast({'union_player_change', Type, MemId, GId, GName, DepartName, AllianceId}, PlayerState) ->
	Player = PlayerState#player_state.player,
	NewPlayer = lib_guild_union:cast_union_player_change(Player, Type, MemId, GId, GName, DepartName, AllianceId),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%% 玩家自己离开婚宴场景
handle_cast({'LEAVE_WEDDING'}, PlayerState) ->
	Player = PlayerState#player_state.player,
	%通知场景附近所有玩家
	case Player#player.carry_mark =/= 0 of
		true ->
			{ok,BinData12041} = pt_12:write(12041, [Player#player.id, 0]),
			mod_scene_agent:send_to_area_scene(Player#player.scene,Player#player.x, Player#player.y, BinData12041);
		false ->
			skip
	end,
	%% 发送离开通知
	{ok, BinData12074} = pt_12:write(12074, [1]),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData12074),
	%% 去掉玩家的婚宴经验定时器
	misc:cancel_timer(wedding_timer),
	%% 离开场景
	[Out_coord,Coord_length] = lib_marry:get_wedding_send_out(),
	{SpriSid, XYCoord} = Out_coord,
	RandNum = util:rand(1, Coord_length),
	%% 随机产生一对坐标
	{SpriX, SpriY} = lists:nth(RandNum, XYCoord),
	%%婚宴进程做清理工作
	gen_server:cast(mod_wedding:get_mod_wedding_pid(),{'PLAYER_LEAVE',Player#player.id}),
	mod_scene:leave_scene(Player#player.id, Player#player.scene,
						  Player#player.other#player_other.pid_scene,
						  Player#player.x, Player#player.y),
	{ok, BinData12005} = pt_12:write(12005, [SpriSid, SpriX, SpriY, <<>>, SpriSid, 0, 0, 0]),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData12005),
	%%做坐标记录
	put(change_scene_xy , [SpriX, SpriY]),
	NewPlayer = Player#player{
		scene = SpriSid, 
		x = SpriX, 
		y = SpriY,
		carry_mark = 0,
		other = Player#player.other#player_other{
			turned = 0
		}
	},
	List = [
		{scene, SpriSid},
		{x, SpriX},
		{y, SpriY},
		{carry_mark, 0},
		{turned, 0}
	],
	save_online_info_fields(NewPlayer, List),
	%% 更新玩家新坐标和模式
    save_player_table(NewPlayer),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
	lib_player:send_player_attribute(NewPlayer,2),
    {noreply, NewPlayerState};

%% 系统强制性把玩家传出wedding
handle_cast({'SEND_OUT_WEDDING'}, PlayerState) ->
	Player = PlayerState#player_state.player,
	case lib_marry:is_wedding_love_scene(Player#player.scene) of
		true->
			%通知场景附近所有玩家
			case Player#player.carry_mark =/= 0 of
				true ->
					{ok,BinData12041} = pt_12:write(12041, [Player#player.id, 0]),
					mod_scene_agent:send_to_area_scene(Player#player.scene,Player#player.x, Player#player.y, BinData12041);
				false ->
					skip
			end,
			%% 发送离开通知
			{ok, BinData12074} = pt_12:write(12074, [1]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData12074),
			%%婚宴进程全面清理
			gen_server:cast(mod_wedding:get_mod_wedding_pid(),{'PLAYER_LEAVE',Player#player.id}),
			%% 去掉玩家的婚宴经验定时器
			misc:cancel_timer(wedding_timer),
			%% 离开场景
			[Out_coord,Coord_length] = lib_marry:get_wedding_send_out(),
			{SpriSid, XYCoord} = Out_coord,
			RandNum = util:rand(1, Coord_length),
			{SpriX, SpriY} = lists:nth(RandNum, XYCoord), %% 随机产生一对坐标
			mod_scene:leave_scene(Player#player.id, Player#player.scene,
								  Player#player.other#player_other.pid_scene,
								  Player#player.x, Player#player.y),
			{ok, BinData12005} = pt_12:write(12005, [SpriSid, SpriX, SpriY, <<>>, SpriSid, 0, 0, 0]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData12005),
			
			%%做坐标记录
			put(change_scene_xy , [SpriX, SpriY]),
			NewPlayer = Player#player{
				scene = SpriSid, 
				x = SpriX, 
				y = SpriY,
				carry_mark = 0,
				other = Player#player.other#player_other{
					turned = 0
				}
			},
			List = [
				{scene, SpriSid},
				{x, SpriX},
				{y, SpriY},
				{carry_mark, 0},
				{turned, 0}
			],
			save_online_info_fields(NewPlayer, List),
			%%更新玩家新坐标和模式
			save_player_table(NewPlayer),
			NewPlayerState = PlayerState#player_state{
				player = NewPlayer			   
			},
			lib_player:send_player_attribute(NewPlayer,2),
    		{noreply, NewPlayerState};
		false ->
			{noreply, PlayerState}
	end;

%%强制传送到观看拜堂的地方
handle_cast({'WEDDING_FORCE_SEND'},PlayerState) ->
	Player = PlayerState#player_state.player,
	% 离开场景
	Place = [{13,36},{17,32},{15,36},{18,34}],
	RandNum = util:rand(1, 4),
	%% 随机产生一对坐标
	{SpriX, SpriY} = lists:nth(RandNum, Place),		
	mod_scene:leave_scene(Player#player.id, Player#player.scene,
						  Player#player.other#player_other.pid_scene,
						  Player#player.x, Player#player.y),
	{ok, BinData12005} = pt_12:write(12005, [?WEDDING_SCENE_ID, SpriX, SpriY, <<>>, ?WEDDING_SCENE_ID, 0, 0, 0]),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData12005),
	%%做坐标记录
	put(change_scene_xy , [SpriX, SpriY]),
	NewPlayer = Player#player{
							  scene = ?WEDDING_SCENE_ID,
							  x = SpriX, 
							  y = SpriY,
							  carry_mark = 0
							 },
	List = [
			{scene, ?WEDDING_SCENE_ID},
			{x, SpriX},
			{y, SpriY},
			{carry_mark, 0}
		   ],
	save_online_info_fields(NewPlayer, List),
	%%更新玩家新坐标和模式
	save_player_table(NewPlayer),
	lib_player:send_player_attribute(NewPlayer,2),
	NewPlayerState = PlayerState#player_state{
											  player = NewPlayer
											 },
	{noreply,NewPlayerState};

%% 强制传送 新郎、新娘到拜堂的位置
handle_cast({'WEDDING_BEGIN_SEND'},PlayerState) ->
	Player = PlayerState#player_state.player,
	if Player#player.sex =:= 1 ->
		   {SpriX, SpriY} = {11,33};
	   true ->
		   {SpriX, SpriY} = {14,30}
	end,
	mod_scene:leave_scene(Player#player.id, Player#player.scene,
						  Player#player.other#player_other.pid_scene,
						  Player#player.x, Player#player.y),
	{ok, BinData12005} = pt_12:write(12005, [?WEDDING_SCENE_ID, SpriX, SpriY, <<>>, ?WEDDING_SCENE_ID, 0, 0, 0]),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData12005),
	%%做坐标记录
	put(change_scene_xy , [SpriX, SpriY]),
	NewPlayer = Player#player{
							  scene = ?WEDDING_SCENE_ID,
							  x = SpriX, 
							  y = SpriY,
							  carry_mark = 0
							 },
	List = [
			{scene, ?WEDDING_SCENE_ID},
			{x, SpriX},
			{y, SpriY},
			{carry_mark, 0}
		   ],
	save_online_info_fields(NewPlayer, List),
	%%更新玩家新坐标和模式
	save_player_table(NewPlayer),
	{ok,Player2} = lib_player:cancelSitStatus(NewPlayer),
	NewPlayerState = PlayerState#player_state{
											  player = Player2
											 },
	{noreply,NewPlayerState};

%% 玩家自己离开温泉
handle_cast({leave_spring}, PlayerState) ->
	Player = PlayerState#player_state.player,
	%通知场景附近所有玩家
	case Player#player.carry_mark =/= 0 of
		true ->
			{ok,BinData12041} = pt_12:write(12041, [Player#player.id, 0]),
			mod_scene_agent:send_to_area_scene(Player#player.scene,Player#player.x, Player#player.y, BinData12041);
		false ->
			skip
	end,
	%% 发送离开通知
	{ok, BinData12057} = pt_12:write(12057, [1]),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData12057),
	%% 去掉玩家的温泉经验定时器
	misc:cancel_timer(spring_timer),
	%%做玩家在温泉的位置标注，0：温泉场景外面，1：温泉里但不在泉水里，2：VIPTOP泉水里，3：VIPNORMAL泉水里，4：PUBLIC泉水里
	lib_spring:mark_hotspring_site(?HOTSPRING_OUTSIDE),
	%% 离开场景
	{SpriSid, XYCoord} = ?SPRING_OUT_COORD,
	RandNum = util:rand(1, ?COORD_LENGTH),
	%% 随机产生一对坐标
	{SpriX, SpriY} = lists:nth(RandNum, XYCoord),
	catch ets:delete(?ETS_ONLINE_SCENE, Player#player.id),
	mod_scene:leave_scene(Player#player.id, Player#player.scene,
						  Player#player.other#player_other.pid_scene,
						  Player#player.x, Player#player.y),
	%%做坐标记录
	put(change_scene_xy , [SpriX, SpriY]),
	NewPlayer = Player#player{
		scene = SpriSid, 
		x = SpriX, 
		y = SpriY,
		carry_mark = 0,
		other = Player#player.other#player_other{
			is_spring = 0
		}
	},
	List = [
		{scene, SpriSid},
		{x, SpriX},
		{y, SpriY},
		{carry_mark, 0},
		{is_spring, 0}
	],
	save_online_info_fields(NewPlayer, List),
	%% 更新玩家新坐标和模式
    save_player_table(NewPlayer),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
	{ok, BinData12005} = pt_12:write(12005, [SpriSid, SpriX, SpriY, <<>>, SpriSid, 0, 0, 0]),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData12005),
    {noreply, NewPlayerState};

%% 系统强制性把玩家传出温泉
handle_cast({'SEND_OUT_SPRING'}, PlayerState) ->
	Player = PlayerState#player_state.player,
%% 	?DEBUG("SEND_OUT_SPRING:Id:~p, Scene:~p", [Player#player.id, Player#player.scene]),
	case lib_spring:is_spring_scene(Player#player.scene) of
		true->
			%通知场景附近所有玩家
			case Player#player.carry_mark =/= 0 of
				true ->
					{ok,BinData12041} = pt_12:write(12041, [Player#player.id, 0]),
					mod_scene_agent:send_to_area_scene(Player#player.scene,Player#player.x, Player#player.y, BinData12041);
				false ->
					skip
			end,
			%% 发送离开通知
			{ok, BinData12057} = pt_12:write(12057, [1]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData12057),
			%% 去掉玩家的温泉经验定时器
			misc:cancel_timer(spring_timer),
			%% 离开场景
			{SpriSid, XYCoord} = ?SPRING_OUT_COORD,
			RandNum = util:rand(1, ?COORD_LENGTH),
			{SpriX, SpriY} = lists:nth(RandNum, XYCoord), %% 随机产生一对坐标
			mod_scene:leave_scene(Player#player.id, Player#player.scene,
								  Player#player.other#player_other.pid_scene,
								  Player#player.x, Player#player.y),
			{ok, BinData12005} = pt_12:write(12005, [SpriSid, SpriX, SpriY, <<>>, SpriSid, 0, 0, 0]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData12005),
			
			%%做坐标记录
			put(change_scene_xy , [SpriX, SpriY]),
			NewPlayer = Player#player{
				scene = SpriSid, 
				x = SpriX, 
				y = SpriY,
				carry_mark = 0,
				other = Player#player.other#player_other{
					is_spring = 0
				}
			},
			List = [
				{scene, SpriSid},
				{x, SpriX},
				{y, SpriY},
				{carry_mark, 0},
				{is_spring, 0}
			],
			save_online_info_fields(NewPlayer, List),
			%%更新玩家新坐标和模式
			save_player_table(NewPlayer),
			NewPlayerState = PlayerState#player_state{
				player = NewPlayer			   
			},
    		{noreply, NewPlayerState};
		false ->
			{noreply, PlayerState}
	end;

%%温泉莲花给予玩家物品
handle_cast({'GIVE_LOTUS_AWARD', GoodsTypeId}, PlayerState) ->
	Player = PlayerState#player_state.player,
	case catch(gen_server:call(Player#player.other#player_other.pid_goods, {'give_goods', Player, GoodsTypeId, 1, 2})) of
		cell_num ->%%背包格子不够，发邮件去
			Content = "亲爱的玩家，这是你采集的七彩莲花获得的奖励哦~亲！",
			mod_mail:send_sys_mail([tool:to_list(Player#player.nickname)], "七彩莲花奖励", Content, 0, GoodsTypeId, 1, 0, 0),
			BroadCast = 1;
		ok ->
			BroadCast = 1;
		_Other ->
			BroadCast = 0
	end,
	case BroadCast of
		1 ->%%需要全服广播
			GoodsTypeInfo = goods_util:get_goods_type(GoodsTypeId),
			#player{id = PlayerId,
					nickname = PlayerName,
					career = Career,
					sex = Sex} = Player,
			ColorContent = goods_util:get_color_hex_value(GoodsTypeInfo#ets_base_goods.color),
			Msg = 
				io_lib:format("[<a href='event:1,~p,~s,~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>]成功抢到七彩莲花，获得了 [<font color='~s'>~s</u></font>]。",
							  [PlayerId, PlayerName, Career, Sex, PlayerName, ColorContent, GoodsTypeInfo#ets_base_goods.goods_name]),
			spawn(fun()->lib_chat:broadcast_sys_msg(2, Msg) end);
		0 ->
			skip
	end,
	{noreply, PlayerState};

%%莲花被采集了，其他人的所有标志位复位！
handle_cast({'RESET_LOTUS_MARK'}, PlayerState) ->
	Player = PlayerState#player_state.player,
	%% 通知客户端更新玩家属性
	{ok, BinData12041} = pt_12:write(12041, [Player#player.id, 0]),
	mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, BinData12041),
	NewPlayer = Player#player{carry_mark = 0},
	List = [{carry_mark, 0}],
	save_online_info_fields(NewPlayer, List),
	%%更新玩家新坐标和模式
	save_player_table(NewPlayer),
	NewPlayerState = PlayerState#player_state{player = NewPlayer},
	{noreply, NewPlayerState};
			
%% 处理交易发过来的即时信息
handle_cast({'TRADE_SET_AND_SEND', Type, BinData, UpdateList}, PlayerState) ->
	Player = PlayerState#player_state.player,
	case Type of
		1 ->
			%%添加交易后的时间限制
			NowTime = util:unixtime(),
			put(trade_limit, NowTime);
		_ ->
			skip
	end,
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	NewPlayer = lib_trade:trade_set_and_send(UpdateList, Player),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%%进入封神大会比赛区
handle_cast({'NOTICE_ENTER_WAR',Times,Level, Round,SceneId,X,Y,Color,WarPid}, PlayerState) ->
	Player = PlayerState#player_state.player,
	NewPlayer = lib_war:war_start(Player,Times,Level, Round,SceneId,X,Y,Color,WarPid),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};


%%封神大会第**轮比赛结束
handle_cast({'NOTICE_LEAVE_WAR',PidWait,SceneId},PlayerState)->
	NewPlayer = lib_war:war_finish(PlayerState#player_state.player,PidWait,SceneId),
	NewPlayerState = PlayerState#player_state{player=NewPlayer},
	{noreply,NewPlayerState};

%%跨服战场战旗标记
handle_cast({'WAR_FLAG_MARK',[Mark]},PlayerState)->
	Player = PlayerState#player_state.player,
	NewPlayer = Player#player{carry_mark=Mark},
	NewPlayer1 = lib_player:count_player_speed(NewPlayer),
	lib_player:send_player_attribute(NewPlayer1,1),
	save_online_diff(Player, NewPlayer1),
	%%通知所有玩家
    {ok,BinData2} = pt_12:write(12041,[NewPlayer1#player.id,NewPlayer1#player.carry_mark]),
	mod_scene_agent:send_to_area_scene(NewPlayer1#player.scene,NewPlayer1#player.x,NewPlayer1#player.y, BinData2),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer1			   
	},
	{noreply,NewPlayerState};

%%设置死亡次数
handle_cast({'WAR_DIE_TIMES',Times},PlayerState)->
	Player = PlayerState#player_state.player,
	Player1 =Player#player{
             		other = Player#player.other#player_other{
						war_die_times = Times					  
              		}						
               	},
	NewPlayerState = PlayerState#player_state{player=Player1},
	{noreply,NewPlayerState};

%%封神大会称号
handle_cast({'WAR_TITLE',Type,TitleId},PlayerState)->
	NewPlayer = lib_war:war_title(PlayerState#player_state.player,Type,TitleId),
	NewPlayerState = PlayerState#player_state{player=NewPlayer},
	lib_player:send_player_attribute(NewPlayer, 2),   
	{noreply,NewPlayerState};

%%更换跨服个人竞技场景
handle_cast({'CHANGE_WAR2_SCENE',[ScenePid,SceneId,ResId,X,Y]}, PlayerState) ->
	Player = PlayerState#player_state.player,
	NewPlayer = lib_war2:change_scene(Player,ScenePid,ResId,SceneId,X,Y),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%%封神争霸观战者更换场景
handle_cast({'WAR2_VIEW_SCENE',[ScenePid,SceneId,ResId,X,Y,Mark]},PlayerState)->
Player = PlayerState#player_state.player,
	NewPlayer = lib_war2:war2_view_scene(Player,ScenePid,ResId,SceneId,X,Y,Mark),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%%跨服下注
handle_cast({'WAR2_BET',[Type,Money]},PlayerState)->
	Player = PlayerState#player_state.player,
	NewPlayer = 
		case Type of
		1->
			lib_goods:cost_money(Player, Money, bcoin, 4501);
		_->
			lib_goods:cost_money(Player, Money, cash, 4501)
	end,
	lib_player:send_player_attribute(NewPlayer, 2),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
	{noreply,NewPlayerState};

%% 进入战场（给前端发送进入战场信号）
handle_cast({'NOTICE_ENTER_ARENA', ArenaMark, ArenaZone, ArenaSceneId, ArenaPid}, PlayerState) ->
	Player = PlayerState#player_state.player,
	ArenaInfo = util:term_to_string([ArenaZone, ArenaSceneId]),
	case db_agent:get_arena_data_by_id(Player#player.id, "id") of
		[] ->
			spawn(fun()-> lib_arena:init_arena_info(Player, ArenaInfo, 0) end);
		_ ->
			spawn(fun()-> db_agent:update_arena_battle_info(Player#player.id, [{pid, ArenaInfo}]) end)
	end,
	spawn(fun()-> db_agent:update_arena_status(Player#player.id, 1) end),
	%% 更新战场信息
	spawn(fun()-> db_agent:update_arena_start_time(Player#player.id, ArenaZone, ArenaSceneId) end),
	
	case lib_arena:is_new_arena_scene(ArenaSceneId) of
		false ->
			%% 通知前端进入战场
			lib_arena:notice_enter_arena(Player, ArenaZone, ArenaSceneId);
		true ->
			%% 竞技场状态信息
			TodaySec = util:get_today_current_second(),
			ArenaStartTime = lib_arena:get_arena_start_time(),
			{ok, TimeBinData} = pt_23:write(23001, [ArenaStartTime - TodaySec, 2]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, TimeBinData)
	end,

	NewPlayer = Player#player{
		other = Player#player.other#player_other{
			pid_dungeon = ArenaPid									  
   		}							  
	},
	save_online_info_fields(NewPlayer, [{pid_dungeon, ArenaPid}]),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer,
		arena_mark = ArenaMark			   
	},
    {noreply, NewPlayerState};

%% 战场正式开始（跳到战场中）
%% Type 1旧战场，2新战场
handle_cast({'ARENA_START', Type, ArenaZone, ArenaSceneId, ArenaPid}, PlayerState) ->
	Player = PlayerState#player_state.player,
	RetPlayer =
		if
			Type == 1 ->
				lib_arena:arena_start(Player);
			true ->
				%% 通知前端进入战场
				lib_arena:notice_enter_arena(Player, ArenaZone, ArenaSceneId),
				NewPlayer = Player#player{
         			other = Player#player.other#player_other{
               			battle_limit = 0,
						pid_dungeon = ArenaPid																				  
              		}						
              	},
             	mod_player:save_online_info_fields(NewPlayer, [{battle_limit, 0}, {pid_dungeon, ArenaPid}]),
              	NewPlayer
		end,
	NewPlayerState = PlayerState#player_state{
		player = RetPlayer			   
	},
    {noreply, NewPlayerState};

%% 战场结束
handle_cast({'END_ARENA', BinData, ArenaScore, Kill}, PlayerState) ->
	Player = PlayerState#player_state.player,
	NewArenaScore = Player#player.arena_score + ArenaScore,
	spawn(fun()-> db_agent:update_arena_score(Player#player.id, NewArenaScore, 0) end),
	
	%% 战场杀人成就
	lib_achieve:check_achieve_finish(Player#player.other#player_other.pid_send, Player#player.id, 317, [Kill]),
	%%氏族祝福任务判断
	GWParam = {14, Kill},
	lib_gwish_interface:check_player_gwish(Player#player.other#player_other.pid, GWParam),

	{ok, ArenaScoreBinData} = pt_13:write(13018, [{1, NewArenaScore}]),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, ArenaScoreBinData),
   	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
 	NewPlayer = Player#player{
		arena = 0,
		arena_score = NewArenaScore						
   	},
	ArenaList = [
		{arena,	NewPlayer#player.arena},
		{arena_score, NewPlayer#player.arena_score}			 
	],
	save_online_info_fields(NewPlayer, ArenaList),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%% 战场最后检查
handle_cast('ARENA_FINAL_CHECK', PlayerState) ->
	NewPlayer = lib_arena:leave_arena(PlayerState#player_state.player),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%% 竞技场挑战
handle_cast({'COLISEUM_CHALLENGE', ColiseumSceneId, ChallengeName, ColiseumPid}, PlayerState) ->
	Player = PlayerState#player_state.player,
	%% 判断是否自动使用替身,1是0否
	if
		PlayerState#player_state.is_avatar =:= 1 ->
			SkillList = mod_mon_create:shadow_skill(Player),
			gen_server:cast(ColiseumPid, {'CREATE_COLISEUM_AVATAR', Player, SkillList});
		true ->
			{ok, BinData} = pt_49:write(49007, [1, ColiseumSceneId, ChallengeName]),
   			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
	end,
    {noreply, PlayerState};

%% 竞技场挑战
handle_cast({'COLISEUM_AWARD', Coin, Culture}, PlayerState) ->
	Player = PlayerState#player_state.player,
	CoinPlayer = lib_goods:add_money(Player, Coin, bcoin, 4911),
	NewPlayer = CoinPlayer#player{
		culture = CoinPlayer#player.culture + Culture						  
	},
	AttrList = [
		{3, NewPlayer#player.bcoin},
		{4, NewPlayer#player.culture}			
	],
	{ok, BinData} = pt_13:write(13018, AttrList),
   	lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send, BinData),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%% 更新竞技场挑战次数
handle_cast({'CHANGE_COLISEUM_TIMES', Vip1, Vip2}, PlayerState) ->
	NewPlayerState = lib_coliseum:change_coselium_vip_times(PlayerState, Vip1, Vip2),
    {noreply, NewPlayerState};

%% 刷新竞技场奖励
handle_cast({'REFRESH_COLISEUM_AWARD', Rank}, PlayerState) ->
	Player = PlayerState#player_state.player,
	spawn(fun()-> db_agent:update(player_other, [{coliseum_rank, Rank}], [{pid, Player#player.id}]) end),
	{ok, BinData49013} = pt_49:write(49013, Rank),
   	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData49013),
	NewPlayerState = PlayerState#player_state{
		coliseum_rank = Rank			   
	},
    {noreply, NewPlayerState};

%% 竞技场结束
handle_cast('COLISEUM_END_CHECK', PlayerState) ->
	NewPlayer = lib_coliseum:coliseum_end(PlayerState),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%% 攻城战回合重新开始
handle_cast({'CASTLE_RUSH_ROUND_REPEAT', X, Y, Buff, GuildId}, PlayerState) ->
	Player = PlayerState#player_state.player,
	NewPlayer =
		if
			Player#player.guild_id =/= GuildId ->
				pp_scene:handle(12004, Player, 0),
				%% 坐标记录
				put(change_scene_xy, [X, Y]),
				{ok, BinData} = pt_12:write(12005, [?CASTLE_RUSH_SCENE_ID, X, Y, <<>>, ?CASTLE_RUSH_SCENE_ID, 0, 0, 13]),
   				lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
				Player#player{
					x = X,
					y = Y,
					other = Player#player.other#player_other{
						leader = 13,
						battle_status = Buff
					}									  
   				};
			true ->
				Player#player{
					other = Player#player.other#player_other{
						leader = 14,
						battle_status = Buff									  
   					}		  
				}
		end,
	ets:insert(?ETS_ONLINE, NewPlayer),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%% 攻城战最后检查
handle_cast('CASTLE_RUSH_CHECK', PlayerState) ->
	NewPlayer = lib_castle_rush:leave_castle_rush(PlayerState#player_state.player),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};
								
%% 攻城战怒气技能
handle_cast({'CASTLE_RUSH_ANGRY', SkillId, AngryParam}, PlayerState) ->
	Player = PlayerState#player_state.player,
	Buff = Player#player.other#player_other.battle_status,
	AttBuff = lists:keydelete(castle_rush_att, 1, Buff),
	AntiBuff = lists:keydelete(castle_rush_anti, 1, AttBuff),
	
	[SkillAttVal, SkillAntiVal] = lib_castle_rush:castle_rush_angry_val(SkillId),
	[NewSkillAttVal, NewSkillAntiVal] = [trunc(SkillAttVal * (1 + AngryParam)), trunc(SkillAntiVal * (1 + AngryParam))],
	
	LastTime = 60,
	Now = util:unixtime(),
	EndTime = Now + LastTime,
	
	NewAttBuff = [{castle_rush_att, NewSkillAttVal, EndTime, SkillId, 1} | AntiBuff],
	AttBuffTimer = erlang:send_after(LastTime * 1000, self(), {'UPDATE_SKILL_BUFF', castle_rush_att}),
	lib_player:set_skill_buff_timer(AttBuffTimer, castle_rush_att),
	
	NewBuff = [{castle_rush_anti, NewSkillAntiVal, EndTime, SkillId, 1} | NewAttBuff],
	AntiBuffTimer = erlang:send_after(LastTime * 1000, self(), {'UPDATE_SKILL_BUFF', castle_rush_anti}),
	lib_player:set_skill_buff_timer(AntiBuffTimer, castle_rush_anti),
	
	RetPlayer = Player#player{
  		other = Player#player.other#player_other{
      		battle_status = NewBuff									  
     	}						
    },
	NewPlayer = lib_player:count_player_attribute(RetPlayer),
    lib_player:send_player_attribute(NewPlayer, 2),    
	lib_player:refresh_player_buff(Player#player.other#player_other.pid_send, NewBuff, Now),
	save_online_diff(Player, NewPlayer),
	
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%% 攻城战灵力
handle_cast({'CASTLE_RUSH_SPIRIT', Spt}, PlayerState) ->
	Player = PlayerState#player_state.player,
	Spirit = Player#player.spirit + Spt,
	{ok, BinData} = pt_13:write(13002, [Player#player.exp, Spirit]),
  	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	NewPlayer = Player#player{
  		spirit = Spirit						
    },
	ets:insert(?ETS_ONLINE, NewPlayer),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
	{noreply, NewPlayerState};

%% 更改攻城战霸主
handle_cast({'CHANGE_CASTLE_RUSH_KING', CastleRushKing, BinData}, PlayerState) ->
	Player = PlayerState#player_state.player,
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	NewPlayer = Player#player{
  		other = Player#player.other#player_other{
      		castle_king = CastleRushKing									  
     	}						
    },
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
	{noreply, NewPlayerState};

%% 部落荣誉更新
handle_cast({'UPDATE_REALM_HONOR', RealmHonor}, PlayerState) ->
	Player = PlayerState#player_state.player,
	{ok, BinData} = pt_13:write(13018, [{2, RealmHonor}]),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	NewPlayer = Player#player{
		realm_honor = RealmHonor						  
	},
	save_online_info_fields(NewPlayer, [{realm_honor, NewPlayer#player.realm_honor}]),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

handle_cast({'SEND_SET_OPEN_BOX_INFO', Param}, PlayerState) ->
	Player = PlayerState#player_state.player,
	lib_box_scene:set_open_box_info(Player#player.id, Param),
	{noreply, PlayerState};

%% 新秘境获取物品
handle_cast({'BOX_KILL_MON', HoleType, OpenType}, PlayerState) ->
	{ok, NewPlayer} = lib_boxs_piece:boxs_kill_mon_goods(PlayerState#player_state.player, HoleType, OpenType),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};
	
%% 玩家得到(失去)魔核或者旗
handle_cast({'UPDATE_FEATS_MARK', PlayerNutType, Type}, PlayerState) ->
	Player = PlayerState#player_state.player,
	spawn(fun()-> db_agent:mm_update_player_info([{carry_mark, PlayerNutType}], [{id, Player#player.id}]) end),
	%% 通知客户端更新玩家属性
    {ok, BinData} = pt_12:write(12041, [Player#player.id, PlayerNutType]),
	mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, BinData),
	case Type =:= 1 andalso PlayerNutType =:= 11 of
		true ->
			#player{id = PlayerId,
					nickname = PlayerName,
					career = Career,
					sex = Sex} = Player,
			Param = [PlayerId, PlayerName, Career, Sex],
			lib_skyrush:send_skyrush_notice(8, Param);
		false ->
			skip
	end,
	%% tips提示更新
	if
		PlayerNutType >= 8 andalso PlayerNutType =< 11 ->
			Color = PlayerNutType - 7,
			ParamTips = [Player#player.other#player_other.pid_send, Color],
			lib_skyrush:send_skyrush_tips(4, ParamTips);
		PlayerNutType >= 12 andalso PlayerNutType =< 15 ->
			Color = PlayerNutType - 11,
			ParamTips = [Player#player.other#player_other.pid_send, Color],
			lib_skyrush:send_skyrush_tips(5, ParamTips);
		true ->
			skip
	end,
	NewPlayer = Player#player{
		carry_mark = PlayerNutType
	},
	save_online_info_fields(NewPlayer, [{carry_mark, PlayerNutType}]),
	%%帮其减速
	ResetNewPlayer = lib_player:count_player_speed(NewPlayer),
	lib_player:send_player_attribute(ResetNewPlayer, 1),
%% 	?DEBUG("slow speed:Id:~p, NewSpeed:~p, OldSpeed:~p", [ResetNewPlayer#player.id, ResetNewPlayer#player.speed, NewPlayer#player.speed]),
	NewPlayerState = PlayerState#player_state{
		player = ResetNewPlayer			   
	},
    {noreply, NewPlayerState};

%%向玩家发冥王之灵
handle_cast({'GIVE_WARFARE_PLUTO'}, PlayerState) ->
	 Player = PlayerState#player_state.player,
%% 	 ?DEBUG("GIVE_WARFARE_PLUTO:~p, Scene:~p", [Player#player.id, Player#player.scene]),
%% 	spawn(fun()-> db_agent:mm_update_player_info([{carry_mark, 27}], [{id, Player#player.id}]) end),
	%% 通知客户端更新玩家属性
	 case Player#player.scene =:= ?WARFARE_SCENE_ID of
		 true ->
	 {ok, BinData} = pt_12:write(12041, [Player#player.id, 27]),
	 mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, BinData),
	 lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	 %% 玩家卸下坐骑
	 {ok, MountPlayer}= lib_goods:force_off_mount(Player),
	 PLutoPlayer = MountPlayer#player{
								  carry_mark = 27
								 },
%% 	 修改战斗模式为全体模式
	 NPlayer = PLutoPlayer#player{pk_mode = 5},
%% 	 更新玩家新模式
	 ValueList = [{pk_mode, 5}],
	 WhereList = [{id, PLutoPlayer#player.id}],
	 db_agent:mm_update_player_info(ValueList, WhereList),
%% 	 通知客户端
	 {ok, PkModeBinData} = pt_13:write(13012, [1, 5]),
	 lib_send:send_to_sid(PLutoPlayer#player.other#player_other.pid_send, PkModeBinData),
	 
	 %%因为玩家下线就立即消失的冥王之灵，因此不用保存到数据库了
	 save_online_diff(Player,NPlayer),
	 NewPlayerState = 
		 PlayerState#player_state{
								   player = NPlayer		
								 },
	 {noreply, NewPlayerState};
		 false ->
		 {noreply, PlayerState}
	 end;
%%系统主动通知玩家去掉冥王之灵
handle_cast({'PLUTO_SYSTEM_CHANGE'}, PlayerState) ->
	Player = PlayerState#player_state.player,
	?DEBUG("Scene:~p, Carry:~p", [Player#player.scene,Player#player.carry_mark]),
	{ok, BinData} = pt_12:write(12041, [Player#player.id, 0]),
	mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, BinData),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	NPlayer = Player#player{carry_mark = 0},
	%%因为玩家下线就立即消失的冥王之灵，因此不用保存到数据库了
	save_online_diff(Player,NPlayer),
	NewPlayerState = 
		PlayerState#player_state{
								 player = NPlayer		
								},
	{noreply, NewPlayerState};

%% 从空岛中主动传出玩家
handle_cast({'SEND_OUT_OF_SKYRUSH'}, PlayerState) ->
	Player = PlayerState#player_state.player,
	if
		Player#player.scene =:= ?SKY_RUSH_SCENE_ID ->
			spawn(fun()-> db_agent:mm_update_player_info([{carry_mark, 0}],[{id, Player#player.id}]) end),
			Player0 = Player#player{carry_mark = 0},
			{ok, NewStatusEnter} = lib_guild_manor:enter_manor_scene_39sky(Player0, 500),
			%% 通知所有玩家
			{ok, BinData2} = pt_12:write(12041, [NewStatusEnter#player.id, NewStatusEnter#player.carry_mark]),
			%% 通知个人头顶上的东西消失
			lib_send:send_to_sid(NewStatusEnter#player.other#player_other.pid_send, BinData2),
			%% 通知清除据点图标
			{ok, BinData39004} = pt_39:write(39004, [1]),
			lib_send:send_to_sid(NewStatusEnter#player.other#player_other.pid_send, BinData39004),
			%% 是在结束后才有系统强制性传出,添加任务完成消息
			lib_task:event(guild_war, null, NewStatusEnter),
			%% 修改leader为0
			NewPlayer = NewStatusEnter#player{other = NewStatusEnter#player.other#player_other{leader = 0}},
			save_online_diff(Player, NewPlayer);
		true ->
			NewPlayer = Player
	end,
	%%重新算一次速度
	ResetNewPlayer = lib_player:count_player_speed(NewPlayer),
	lib_player:send_player_attribute(ResetNewPlayer, 1),
%% 	?DEBUG("reset speed:Id:~p, NewSpeed:~p, OldSpeed:~p", [ResetNewPlayer#player.id, ResetNewPlayer#player.speed, NewPlayer#player.speed]),
	NewPlayerState = PlayerState#player_state{
		player = ResetNewPlayer			   
	},
    {noreply, NewPlayerState};

%% 更新个人功勋
handle_cast({'SYNC_MEMBER_FEATS', NewFeatAll}, PlayerState) ->
	Player = PlayerState#player_state.player,
	NewPlayer = Player#player{
		other = Player#player.other#player_other{
			guild_feats = NewFeatAll
		}
	},
	save_online_info_fields(NewPlayer, [{guild_feats, NewFeatAll}]),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%% 个人成就系统信息更新
handle_cast({'UDATE_ACHIEVE', AchId, Param}, PlayerState) ->
	Player = PlayerState#player_state.player,
	lib_achieve:check_achieve_finish(Player#player.other#player_other.pid_send, Player#player.id, AchId, Param),
	{noreply, PlayerState};

%% 有队员加入队伍
handle_cast({'MEMBER_JOIN_TEAM', PidSend, BinData24010, BinData11080, BinData24022}, PlayerState) ->
	Player = PlayerState#player_state.player,
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData24010),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData11080),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData24022),
	{ok, BinData} = pt_24:write(24022, [Player#player.id, Player#player.x, Player#player.y, Player#player.scene]),
	lib_send:send_to_sid(PidSend, BinData),
	{noreply, PlayerState};
handle_cast({'MEMBER_JOIN_TEAM', PidSend}, PlayerState) ->
	Player = PlayerState#player_state.player,
	{ok, BinData} = pt_24:write(24022, [Player#player.id, Player#player.x, Player#player.y, Player#player.scene]),
	lib_send:send_to_sid(PidSend, BinData),
	{noreply, PlayerState};

%% 处理SOCKET协议
%% Cmd 协议号
%% Bin 协议数据
handle_cast({'SOCKET_EVENT', Cmd, Bin}, PlayerState) ->
	Player = PlayerState#player_state.player,
	lib_hack:socket_event_mark(),
	%%玩家黑名单监控
	case Player#player.other#player_other.blacklist of
		true ->
			case lists:member(Cmd, [10006,10030,12001]) orelse Cmd div 10000 == 2 of
				true ->
					skip;
				false ->
					Now = util:unixtime(),
					BlackList = #ets_blacklist{
						id = tool:to_integer(lists:concat([Now,util:rand(10,20)])),
						player_id = Player#player.id,
						cmd = Cmd,
						scene = Player#player.scene,
						x = Player#player.x,
						y = Player#player.y,
						gold = Player#player.gold,
						coin = Player#player.coin,
						bcoin = Player#player.bcoin,
						cash = Player#player.cash,
						time = Now								
					},
					ets:insert(?ETS_BLACKLIST, BlackList)
			end;				
		_ ->
			skip
	end,
    case routing(Cmd, Player, Bin, PlayerState) of
        %% 修改ets和status
        {ok, NewPlayer} ->												
            save_online_diff(Player, NewPlayer),
            NewPlayerState = PlayerState#player_state{
                player = NewPlayer			   
            },
            {noreply, NewPlayerState};
        
        %% 修改ets、status和table
        {ok, change_ets_table, NewPlayer} -> 							
            save_online_diff(Player, NewPlayer),			
            save_player_table(NewPlayer),
            NewPlayerState = PlayerState#player_state{
                player = NewPlayer			   
            },
            {noreply, NewPlayerState};
        
        %% 修改status
        {ok, change_status, NewPlayer} ->
            NewPlayerState = PlayerState#player_state{
                player = NewPlayer			   
            },
            {noreply, NewPlayerState};
		
		%% 修改player_state
        {ok, change_player_state, NewPlayerState} ->
      		{noreply, NewPlayerState};
		
		{ok, change_diff_player_state, NewPlayerState} ->
			save_online_diff(Player, NewPlayerState#player_state.player),
			{noreply, NewPlayerState};
        
        _ ->
            {noreply, PlayerState}
    end;

%% 镇妖台结束
handle_cast({'END_TD', Exp, Spirit, TdMailBinData, _TdResultBinData}, PlayerState) ->
	Player = PlayerState#player_state.player,
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, TdMailBinData),
	%%lib_send:send_to_sid(Player#player.other#player_other.pid_send, TdResultBinData),
	NewPlayer = lib_player:add_exp(Player, Exp, Spirit, 11),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%% 更新玩家亲密度
handle_cast({'close',Type,IdA,IdB,[Value,SceneId]},PlayerState)->
    spawn(fun()-> lib_relationship:close(Type,IdA,IdB,[Value,SceneId]) end),
	{noreply,PlayerState};

%%对外提供的更新玩家活跃度数据接口
handle_cast({'UPDATE_ACITVITY_DATA', AtomType, Param}, PlayerState) ->
	Player = PlayerState#player_state.player,
    spawn(fun()-> lib_activity:update_activity_data(AtomType, Player#player.other#player_other.pid, Player#player.id, Param) end),
	{noreply,PlayerState}; 

%% 变性
handle_cast({'sex_change'},PlayerState)->
	{Result,NewPlayerState,IsFashion} = lib_player:check_sex_change(PlayerState),
	NewPlayer = NewPlayerState#player_state.player,
	%%变性结果
	{ok,Data} = pt_13:write(13030,Result),
	lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send, Data),
	if Result =:= 7 ->
  		   {ok,Data1} = pt_13:write(13005,1),
 		   {ok,Data2} = pt_13:write(13005,2),
		   save_online_diff(PlayerState#player_state.player,NewPlayer),
		   db_agent:mm_update_player_info([{sex,NewPlayer#player.sex}],[{id,NewPlayer#player.id}]),
		   db_agent:update_sex_time(PlayerState#player_state.sex_change_time,NewPlayer#player.id),
		   
 		   lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send, Data1),
  		   lib_send:send_to_sid(NewPlayer#player.other#player_other.pid_send, Data2),
 		   lib_player:send_player_attribute(NewPlayer,2),
		   NameColor = data_agent:get_realm_color(NewPlayer#player.realm),
		   if NewPlayer#player.sex =:=1 ->
				   Msg = io_lib:format("天空一声巨响，【<a href='event:1, ~p, ~s, ~p, ~p'><font color='~s'><u>~s</u></font></a>】在变性使者的巧手之下变成了男儿身！",
									   [NewPlayer#player.id,NewPlayer#player.nickname,NewPlayer#player.career,NewPlayer#player.sex,NameColor,NewPlayer#player.nickname]);
			  
		      true ->
				    Msg = io_lib:format("天空一声巨响！,【<a href='event:1, ~p, ~s, ~p, ~p'><font color='~s'><u>~s</u></font></a>】在变性使者的巧手之下变成了女儿身！",
									   [NewPlayer#player.id,NewPlayer#player.nickname,NewPlayer#player.career,NewPlayer#player.sex,NameColor,NewPlayer#player.nickname])
		   end,
		   %%变性成功，通知更新氏族祝福数据
		   lib_gwish_interface:sex_change_succeed(NewPlayer),
		   lib_chat:broadcast_sys_msg(2, Msg),
		   %%主动推送更新衣橱的数据
		   lib_wardrobe:check_need_f5_wardrobe(NewPlayer#player.other#player_other.pid_goods, NewPlayer#player.id, NewPlayer#player.other#player_other.pid_send, 3, {}, {}),
		   %%判断是否需要重新通知身上的时装变化
		   case IsFashion of
			   [] ->
				   skip;
			   IsList when is_list(IsList) ->
				   lists:foreach(fun({PGid, NLocation}) ->
										 gen_server:cast(NewPlayer#player.other#player_other.pid_goods, 
														 {'info_15000', PGid, NLocation})
								 end, IsList);
			   _Other ->
				   skip
		   end;
	   true ->
		   skip
	end,
	{noreply,NewPlayerState};

%%解除被邀请状态，只用与变性
handle_cast({'sex_change_reset_invited'},PlayerState)->
	put(sex_change_invited,undefined),
	{noreply,PlayerState}; 


%%通知玩家氏族祝福任务运势被刷新啦
handle_cast({'HELP_FLUSH_GWISH_TASK', Notices}, PlayerState) ->
	Player = PlayerState#player_state.player,
	case Player#player.guild_id =/= 0 of
		true ->
			[SPId, SPName, SLuck, TColor] = Notices,
			%%获取氏族祝福任务的详细数据
			GWish = lib_guild_wish:get_gwish_dict(),
			#p_gwish{luck = Luck,
					 tid = TId,
					 t_color = OTColor,
					 tstate = TState,
					 help = Help,
					 bhelp = BHelp} = GWish,
			#player{id = PId,
					nickname = PName,
					sex = Sex,
					career = Career,
					guild_id = PGId} = Player,
			NBHelp = BHelp + 1,
			NGWish = GWish#p_gwish{t_color = TColor,
								   bhelp = NBHelp},
			NowTime = util:unixtime(),
			ValueList = [{t_color, TColor}, {bhelp, NBHelp}],
			WhereList = [{pid, PId}],
			%%更新dict
			lib_guild_wish:put_gwish_dict(NGWish),
			%%更新数据库
			lib_guild_wish:db_update_gwish(ValueList, WhereList),
			MemNotices = [PId, PGId, PName, Sex, Career, Luck, TId, TColor, TState, Help, NBHelp],
			%%通知氏族玩家数据更新啦(重新更新一下玩家的数据)
			lib_guild_wish:notice_mem_gwish(MemNotices),
			%%加帮助日志
			lib_guild_wish:add_gwish_logs(PId, SPId, SPName, SLuck, OTColor, TColor, TId, NowTime),
			%%通知玩家客户端
			{ok, BinData} = pt_40:write(40074, [{TColor,SPName}]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		false ->
			skip
	end,
	{noreply, PlayerState};
	
%%邀请玩家氏族祝福任务运势被刷新啦
handle_cast({'INVITE_FLUSH_GWISH_TASK', Notices}, PlayerState) ->
	%%通知玩家客户端
	Player = PlayerState#player_state.player,
	case Player#player.guild_id =/= 0 of
		true ->
			{ok, BinData} = pt_40:write(40076, [Notices]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		false ->
			skip
	end,
	{noreply, PlayerState};

%%% 玩家氏族祝福任务完成情况检查
handle_cast({'CHEKC_PLAYER_GWISH', GWParam}, PlayerState) ->
	Player = PlayerState#player_state.player,
	%%检查是否已经初始化过了
	lib_guild_wish:check_init_guild_wish(Player#player.id, Player#player.nickname, Player#player.sex, Player#player.career, Player#player.guild_id),
	lib_guild_wish:check_player_gwish(Player, GWParam),
	{noreply, PlayerState};
	
%% 计算在神魔乱战的时候砍怪获得的经验和灵力
handle_cast({'WARFARE_ADD_EXPSPRI', MonType, Hurt}, PlayerState) ->
	Player = PlayerState#player_state.player,
	 %% 添加经验和灵力
	NewPlayer = lib_warfare:warfare_add_expspri(Player, MonType, Hurt),
	NewPlayerState = PlayerState#player_state{player = NewPlayer},
	{noreply, NewPlayerState};

%%玩家碰撞铜币成功，通知玩家加绑定铜
handle_cast({'TRANSLATE_BCOIN_SUCCEED', AddBCoin}, PlayerState) ->
	Player = PlayerState#player_state.player,
	Nplayer = lib_goods:add_money(Player, AddBCoin, bcoin, 3919),
	%% 	lib_player:send_player_attribute(Nplayer, 2),
	%% 	通知客户端
	{ok, BinData39108} = pt_39:write(39108, [1, AddBCoin]),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData39108),
	%% 更新当前拿到的绑定铜数值
	lib_warfare:update_warfare_award_self(AddBCoin),
	NewPlayerState = PlayerState#player_state{
											  player = Nplayer			   
											 },
	{noreply,NewPlayerState};


%%购买喜帖
handle_cast({'BUY_INVITES',Num}, PlayerState) ->
	Player = PlayerState#player_state.player,
	NeedGold = Num*10,
	Player2 =
		case goods_util:is_enough_money(Player,NeedGold,gold) of
			false ->
				{ok,BinData2} = pt_48:write(48007,{2,0}),
				lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData2),
				Player;
			true ->
				Player1 = lib_goods:cost_money(Player, NeedGold, gold, 4807),
				gen_server:cast(mod_wedding:get_mod_wedding_pid(),{'ADD_INVITES',NeedGold,Player1}),
				Player1
		end,%%3702
	lib_player:send_player_attribute(Player2, 2),
	{noreply, PlayerState#player_state{player = Player2}};
		   
%%给在神魔乱斗场景上的玩家发经验和灵力奖励
handle_cast({'WARFARE_AWARD', SGInfo}, PlayerState) ->
	Player = PlayerState#player_state.player,
	%%给玩家+经验和灵力奖励
	NPlayer = lib_warfare:give_warfare_award(SGInfo, Player),
	NewPlayerState = PlayerState#player_state{player = NPlayer},
	{noreply, NewPlayerState};
	
%%强制性传出玩家
handle_cast({'SEND_OUT_WARFARE'}, PlayerState) ->
	Player = PlayerState#player_state.player,
%% 	?DEBUG("SEND_OUT_SPRING:Id:~p, Scene:~p", [Player#player.id, Player#player.scene]),
	case Player#player.scene =:= ?WARFARE_SCENE_ID of
		true->
			%%通知去掉冥王之灵图标
			{ok,BinData39104} = pt_39:write(39104, []),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData39104),
			%通知场景附近所有玩家
			case Player#player.carry_mark =/= 0 of
				true ->
					{ok,BinData12041} = pt_12:write(12041, [Player#player.id, 0]),
					mod_scene_agent:send_to_area_scene(Player#player.scene,Player#player.x, Player#player.y, BinData12041),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData12041),
					Player1 = Player#player{carry_mark = 0};
				false ->
					Player1 = Player
			end,
			%%先保存数据
			ListCArryMark = [{carry_mark, 0}],
			mod_player:save_online_info_fields(Player1, ListCArryMark),
			%% 离开场景
			{NewSceneId, X, Y} = ?WARFARE_OUT_SCENE,
			mod_scene:leave_scene(Player#player.id, Player#player.scene,
								  Player#player.other#player_other.pid_scene,
								  Player#player.x, Player#player.y),
			{ok, BinData12005} = pt_12:write(12005, [NewSceneId, X, Y, <<>>, NewSceneId, 0, 0, 0]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData12005),
			%% 通知玩家去掉绑定铜
			{ok, BinData39111} = pt_39:write(39111, [2, 0]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData39111),
			%%做坐标记录
			put(change_scene_xy , [X, Y]),
			NewPlayer = 
				Player1#player{scene = NewSceneId, 
							   x = X, 
							   y = Y,
							   carry_mark = 0},
			List = [{scene, NewSceneId},
					{x, X},
					{y, Y},
					{carry_mark, 0}],
			save_online_info_fields(NewPlayer, List),
			%%更新玩家新坐标和模式
			save_player_table(NewPlayer),
			NewPlayerState = PlayerState#player_state{
				player = NewPlayer			   
			},
    		{noreply, NewPlayerState};
		false ->
			{noreply, PlayerState}
	end;

%%更新玩家的氏族联盟数据
handle_cast({'UPDATE_ALLIANCE_IDS', AlliancesId, SendInfo}, PlayerState) ->
	Player = PlayerState#player_state.player,
	NewPlayer = Player#player{other = Player#player.other#player_other{g_alliance = AlliancesId}},
	NewPlayerState = PlayerState#player_state{player = NewPlayer},
	save_online_info_fields(NewPlayer, [{g_alliance, NewPlayer#player.other#player_other.g_alliance}]),
	%% 	通知客户端,通知更新联盟信息
	{ok, BinData40094} = pt_40:write(40094, [SendInfo]),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData40094),
	{noreply, NewPlayerState};
	
%% %%更新经验找回信息
%% handle_cast({'UPDATE_FIND_EXP_1',[PlayerId,Lv,GuildId,ZeroToday,ZeroYesterday]},PlayerState)->
%% 	Status = PlayerState#player_state.player,
%% 	lib_find_exp:exp_find_1(PlayerId,Lv,GuildId,ZeroToday,ZeroYesterday),
%% 	lib_find_exp:delete_by_pid(Status#player.id),
%% 	lib_find_exp:init_find_exp(Status#player.id),
%% 	pp_exc:handle(33006,Status,[]),
%% 	{noreply, PlayerState};
%% %%更新经验找回信息
%% handle_cast({'UPDATE_FIND_EXP_2',[PlayerId,Lv,GuildId,ZeroToday,ZeroYesterday]},PlayerState)->
%% 	Status = PlayerState#player_state.player,
%% 	lib_find_exp:exp_find_2(PlayerId,Lv,GuildId,ZeroToday,ZeroYesterday),
%% 	lib_find_exp:delete_by_pid(Status#player.id),
%% 	lib_find_exp:init_find_exp(Status#player.id),
%% 	pp_exc:handle(33006,Status,[]),
%% 	{noreply, PlayerState};

%%接收VIP状态检测信号
handle_cast({'ACCEPT_VIP_CHECK',[Times]},PlayerState)->
	if Times < 86400 ->
		erlang:send_after((Times+3)*1000,self(),{'CHECK_VIP_STATE'});
	   true->skip
	end, 
	{noreply, PlayerState};

%%单人镇妖竞技奖励
handle_cast({'single_td_award',[Spt,BCoin]},PlayerState)->
	Status = PlayerState#player_state.player,
	Status1 = lib_player:add_exp(Status,0,Spt,0),
	Status2 = lib_goods:add_money(Status1, BCoin, bcoin, 2201),
	lib_player:send_player_attribute(Status2, 2),
	NewPlayerState = PlayerState#player_state{
				player = Status2			   
			},
	{noreply,NewPlayerState};

%%活跃度任务检查
handle_cast({'ACTIVITY_TASK_FINISH', Type}, PlayerState) ->
	lib_activity:check_player_activity_task(Type, PlayerState#player_state.player),
	{noreply, PlayerState};
%%怪物变身卡
handle_cast({'BE_MON_CHANGE', GoodsInfo}, PlayerState) ->
	%%?DEBUG("BE_MON_CHANGE:~p", [GoodsInfo#goods.goods_id]),
	Player = PlayerState#player_state.player,
	GoodsBuffs = lib_goods:get_player_goodsbuffs(),
	{NPlayer, NewGoodsBuffs} = lib_goods_use:buff_add(Player, GoodsInfo, GoodsBuffs),
	PlayerStatus2 = lib_goods:update_player_goodsbuffs(NPlayer, NewGoodsBuffs),
%% 	?DEBUG("Id:~p, Buffs:~p", [Player#player.id,lib_goods:get_player_goodsbuffs()]),
	NPlayerState = PlayerState#player_state{player = PlayerStatus2},
	{noreply,NPlayerState};

handle_cast({'SEND_QUIZZES_AWARD', Prize}, PlayerState) ->
	Player = PlayerState#player_state.player,
	%%加钱
	NPlayer = lib_goods:add_money(Player, Prize, bcoin, 3034),
	{ok, BinData30034} = pt_30:write(30034, [1]),
	lib_send:send_to_sid(NPlayer#player.other#player_other.pid_send, BinData30034),
	%%刷新
	lib_player:send_player_attribute2(NPlayer, 2),
	NPlayerState = PlayerState#player_state{player = NPlayer},
	{noreply,NPlayerState};

handle_cast(_Event, PlayerState) ->
	io:format("Mod_player_cast: /~p/~n",[_Event]),
    {noreply, PlayerState}.

%% --------------------------------------------------------------------
%% Function: handle_info/2
%% Description: Handling all non call/cast messages
%% Returns: {noreply, State}          |
%%          {noreply, State, Timeout} |
%%          {stop, Reason, State}            (terminate/2 is called)
%% --------------------------------------------------------------------
%%更新战斗信息
handle_info({'PLAYER_BATTLE_RESULT', [Hp, Mp, Pid, Id, NickName, Career, Realm, SceneId]}, PlayerState) ->
	Player = PlayerState#player_state.player,
    RetPlayerState =
		if
   			Player#player.hp > 0 andalso Player#player.scene == SceneId ->
				NewPlayerState = 
                    case lib_arena:is_arena_scene(Player#player.scene) of
                        true ->
                            %% 竞技场怒气
                            Hurt = Player#player.hp - Hp,
							if
                           		Hurt > 0 ->
                                    Angry = round(100 * (Hurt / Player#player.hp_lim)),
                                    lib_arena:update_arena_angry(Player, Angry);
                              	true ->
                                    skip
                            end,
                            PlayerState;
                        false ->
                            %% 氏族运镖别劫，通知氏族成员
                            lib_player:guild_carry_tip(PlayerState, Player)
                    end,
				HpMpPlayer = Player#player{
                    hp = Hp,
                    mp = Mp
                },
                if
                    Hp > 0 ->
						if
                     		Player#player.hp > Hp ->
                          		%% 检查是否已经进入了战斗状态
                         		NewPlayer = lib_battle:enter_battle_status(HpMpPlayer),
								ets:insert(?ETS_ONLINE, NewPlayer);
                         	true ->
                          		NewPlayer = HpMpPlayer,
								List = [
                            		{hp, NewPlayer#player.hp},
                            		{mp, NewPlayer#player.mp}
                        		],
								save_online_info_fields(NewPlayer, List)
                      	end;
                    true ->
                        NewPlayer = lib_player:player_die(HpMpPlayer, Pid, Id, NickName, Career, Realm),
                        save_online_diff(Player, NewPlayer)
                end,
				lib_team:update_team_player_info(NewPlayer),
				lib_era:calc_era_scene_hurt(NewPlayer, Player#player.hp - Hp),
				NewPlayerState#player_state{
					player = NewPlayer			   
				};
      		true ->
           		PlayerState				
        end,
    {noreply, RetPlayerState};

%% 开启燃烧 
handle_info({'START_BURN_TIMER',Hurt,Interval},PlayerState) ->
	Player = PlayerState#player_state.player,
	misc:cancel_timer(burn_bleed_timer),
	if
		Player#player.hp > 0 andalso Player#player.status =/= 3 andalso Player#player.scene > 10000  ->
			mod_scene:bleed_hp(Player#player.id, Player#player.scene, Hurt, 0 ,0, 0, 0, 0, 0);
		true ->
			skip
	end,
	BleedTimer = erlang:send_after(Interval, self(), {'START_BURN_TIMER',Hurt,Interval}),
    put(burn_bleed_timer, BleedTimer),
	{noreply, PlayerState};
  
%% 关闭燃烧
handle_info({'TURN_OFF_BURN_TIMER'},PlayerState) ->
	misc:cancel_timer(burn_bleed_timer),
	{noreply, PlayerState};

%% 开启一个流血（或加血）计时器
%% ValType 0 数值  1百分比
handle_info({'START_HP_TIMER', Pid, Id, NickName, Career, Realm, Hurt, ValType, Time, Interval}, PlayerState) ->
	Player = PlayerState#player_state.player,
	misc:cancel_timer(bleed_timer),
  	%% 先判断是否已经死亡
 	if 
		Player#player.hp > 0 andalso Player#player.status =/= 3 ->
            NewTime = Time - 1,
			if
           		NewTime > 0 ->
					mod_scene:bleed_hp(Player#player.id, Player#player.scene, Hurt, ValType ,Pid, Id, NickName, Career, Realm),
                    BleedTimer = erlang:send_after(Interval, self(), {'START_HP_TIMER', Pid, Id, NickName, Career, Realm, Hurt,ValType, NewTime, Interval}),
                    put(bleed_timer, BleedTimer);
              	true ->
                    put(bleed_timer, undefined)
            end;
        true ->
            skip
   	end,
    {noreply, PlayerState};

%% 流血
handle_info({'BLEED_HP', Hp, Pid, Id, NickName, Career, Realm}, PlayerState) ->
	Player = PlayerState#player_state.player,
    RetPlayerState = 
   		case Player#player.status =/= 3 of
            true ->                 
				%% 竞技场怒气
				case lib_arena:is_arena_scene(Player#player.scene) of
					true ->
              			Hurt = Player#player.hp - Hp,
                      	case Hurt > 0 of
                       		true ->
                    			Angry = round(100 * (Hurt / Player#player.hp_lim)),
								lib_arena:update_arena_angry(Player, Angry);
                         	false ->
                       			skip
                      	end;
					false ->
						skip
				end,
				HpPlayer = Player#player{
                    hp = Hp
                },
				RetPlayer = 
                    case Hp > 0 of
                        true ->
							HpPlayer;
                        false ->
                            NewPlayer = lib_player:player_die(HpPlayer, Pid, Id, NickName, Career, Realm),
                            save_online_diff(Player, NewPlayer),
                            NewPlayer
                    end,
				ets:insert(?ETS_ONLINE, RetPlayer),
				PlayerState#player_state{
					player = RetPlayer			   
				};
            false ->
           		PlayerState				
        end,
	{noreply, RetPlayerState};

%% 加血/蓝
%% Type 1加血，0加蓝
handle_info({'ADD_PLAYER_HP_MP', Type, Val, Time, Interval}, PlayerState) ->
	Player = PlayerState#player_state.player,
	misc:cancel_timer(bleed_timer),
	NewPlayer =
		case Player#player.hp > 0 andalso Player#player.status =/= 3 of
			true ->
				RetPlayer = 
					case Type == 1 of
						true ->
							NewVal = Player#player.hp + Val,
							NewHp = 
								case Player#player.hp_lim > NewVal of
									true ->
										NewVal;
									false ->
										Player#player.hp_lim	
								end,
							{ok, BinData} = pt_12:write(12009, [Player#player.id, NewHp, Player#player.hp_lim]),
                			mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, BinData),
							Player#player{
								hp = NewHp
							};
						false ->
							NewVal = Player#player.mp + Val,
							NewMp = 
								case Player#player.mp_lim > NewVal of
									true ->
										NewVal;
									false ->
										Player#player.mp_lim	
								end,
							
							NewPlayer1 = Player#player{
								mp = NewMp
							},
							lib_player:send_player_attribute2(NewPlayer1, 2),
							NewPlayer1
					end,
				NewTime = Time - 1,
    			case NewTime > 0 of
        			true ->					
            			BleedTimer = erlang:send_after(Interval*1000, self(), {'ADD_PLAYER_HP_MP', Type, Val, NewTime, Interval}),
						put(bleed_timer, BleedTimer);
        			false ->
						put(bleed_timer, undefined)
    			end,
				lib_team:update_team_player_info(RetPlayer),
				save_online_info_fields(RetPlayer, [{hp, RetPlayer#player.hp}, {mp, RetPlayer#player.mp}]),
              	RetPlayer;
			false ->
				Player
		end,
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

handle_info({'SET_CLOSE', [Id, PkMon, Timestamp, Close]}, PlayerState) ->
%% 	?DEBUG("add close:~p", [[Id, PkMon, Timestamp, Close]]),
	case ets:lookup(?ETS_RELA, Id) of
		[] ->skip;
		[R] ->
			NewRela = R#ets_rela{pk_mon = PkMon, timestamp = Timestamp, close = Close},
			ets:insert(?ETS_RELA,NewRela)
	end,
%% 	%%更新玩家亲密度时，顺便给玩家发邮件奖励(先判断，再颁发)
%% 	Player = PlayerState#player_state.player,
%% 	lib_relationship:give_mid_festival_award(MidAward,Player,Close),
	{noreply, PlayerState};

%% 发送信息到socket端口
handle_info({send_to_sid, Bin}, PlayerState) ->
	Player = PlayerState#player_state.player,
 	lib_send:send_to_sid(Player#player.other#player_other.pid_send, Bin),
    {noreply, PlayerState};

%% 脱离战斗状态
handle_info('ESCAPE_BATTLE_STATUS', PlayerState) ->
	Player = PlayerState#player_state.player,
	{ok, BinData} = pt_20:write(20007, 0), 
   	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	Sta = lib_player:player_status(Player),
    RetPlayer =        
       	%% 判断有没有处在死亡、蓝名、挂机、打坐状态    	
		case lists:member(Sta, [3, 4, 5, 6]) of
			false ->
				misc:cancel_timer(battle_status_timer),
    			NewPlayer = Player#player{status = 0},
				save_online_info_fields(NewPlayer, [{status, 0}]),
				NewPlayer;
            true ->
                Player
        end,
	NewPlayerState = PlayerState#player_state{
		player = RetPlayer			   
	},
    {noreply, NewPlayerState};

%% 检查是否有重复登陆
handle_info('CHECK_DUPLICATE_LOGIN', PlayerState) ->
	Player = PlayerState#player_state.player,
	PlayerProcessName = misc:player_process_name(Player#player.id),
	case misc:whereis_name({global,PlayerProcessName}) of
		Pid when is_pid(Pid)->
			case misc:is_process_alive(Pid) of
				true  ->
					Self = self(),
					if 
						Pid /= Self ->
							mod_login:logout(Self, 1);
					   	true ->
						  	skip
					end;
				flase ->
					skip
			end;
		_E ->
			skip
	end,
	{noreply, PlayerState};
							 
%% 防沉迷信息播报
handle_info({'ALART_REVEL', Min}, PlayerState) ->
	Player = PlayerState#player_state.player,
	case db_agent:get_idcard_status(Player#player.sn, Player#player.accid) of
		1 -> 
			skip;
		_ ->
			case Min of
				60 ->
					{ok, BinData} = pt_11:write(11082, "您累计在线时间已满1小时"),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
				120 ->
					{ok, BinData} = pt_11:write(11082, "您累计在线时间已满2小时"),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
				_ ->
					{ok, BinData} = pt_29:write(29001, <<>>),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
			end
	end,
	{noreply, PlayerState};

%% GM命令"task_zp"，自动完成25级以下的任务(不包括25级)
handle_info('TASK_ZP', PlayerState) ->
	Player = PlayerState#player_state.player,
	if
		Player#player.lv > 24 ->
			ok;
		true ->
			gen_server:cast(Player#player.other#player_other.pid_task,{'init_task', Player}),
			lib_task:finish_task_under_lv(Player, Player#player.lv),
			erlang:send_after(2 * 1000, self(), 'TASK_ZP')
	end,
	{noreply, PlayerState};

%% 防沉迷强制退出
handle_info('FORCE_OUT_REVEL', PlayerState) ->
	Player = PlayerState#player_state.player,
	case db_agent:get_idcard_status(Player#player.sn, Player#player.accid) of
		1 -> 
			skip;
		_ ->
			mod_login:logout(Player#player.other#player_other.pid, 5)
	end,
	{noreply, PlayerState};

%% 凝神修炼定时器补时
handle_info({'EXC_ING_EX', Ty, ExcTime, EndTime}, PlayerState) ->
	Player = PlayerState#player_state.player,
	case Player#player.status of
		7 ->
			erlang:send_after(60 * 1000, self(), {'EXC_ING', Ty, ExcTime, EndTime}),
			Exp = data_exc:get_exc_gain(Ty, exp, Player#player.lv),
			Spirit = data_exc:get_exc_gain(Ty, spr, Player#player.lv),
			NewPlayer = lib_player:add_exp(Player, Exp, Spirit, 4),
			NewPlayerState = PlayerState#player_state{
				player = NewPlayer			   
			},
    		{noreply, NewPlayerState};
		_->
			{noreply, PlayerState}
	end;

%% 登陆时候延迟2秒发放经验
handle_info({'EXC_ING_LOGIN', Exp, Spirit}, PlayerState) ->
	Player = PlayerState#player_state.player,
	spawn(fun()-> 
		Now = util:unixtime(),
		%% 重置上次登陆时间
		db_agent:set_exc_logout_tm(Player#player.id, Now)		  
	end),
	NewPlayer = lib_player:add_exp(Player, Exp, Spirit, 4),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%% 延迟15秒统计凝神时间
handle_info({'EXC_CHECK_ACHIEVE', ExcTimeMin}, PlayerState) ->
	Player = PlayerState#player_state.player,
	lib_achieve:check_achieve_finish(Player#player.other#player_other.pid_send,
									 Player#player.id, 510, [ExcTimeMin]),
	{noreply, PlayerState};

%% 凝神修炼持续加经验
handle_info({'EXC_ING', Ty, ExcTime, EndTime}, PlayerState) ->
	Player = PlayerState#player_state.player,
	case Player#player.status of
		7 ->
			Nowtime = util:unixtime(),
			[New_endtime, Newexctime] = db_agent:get_exc_endexc_time(Player#player.id),
			if 	
				Newexctime =/= ExcTime ->					
					{noreply, PlayerState};		
				New_endtime > EndTime ->					
					{noreply, PlayerState};
				EndTime > Nowtime ->
					Exp = data_exc:get_exc_gain(Ty, exp, Player#player.lv),
					Spirit = data_exc:get_exc_gain(Ty, spr, Player#player.lv),
					NewPlayer = lib_player:add_exp(Player, Exp, Spirit, 4),
					erlang:send_after(60 * 1000, self(), {'EXC_ING', Ty, ExcTime, New_endtime}),
					lib_achieve:check_achieve_finish(Player#player.other#player_other.pid_send,
													 Player#player.id, 510, [1]),
					NewPlayerState = PlayerState#player_state{
						player = NewPlayer			   
					},
    				{noreply, NewPlayerState};
				true ->
					Exp = data_exc:get_exc_gain(Ty, exp, Player#player.lv),
					Spirit = data_exc:get_exc_gain(Ty, spr, Player#player.lv),
					ExpPlayer = lib_player:add_exp(Player, Exp, Spirit, 4),
					lib_achieve:check_achieve_finish(Player#player.other#player_other.pid_send,
													 Player#player.id, 510, [1]),
					NewPlayer = lib_exc:finish_exc(ExpPlayer),
					NewPlayerState = PlayerState#player_state{
						player = NewPlayer			   
					},
    				{noreply, NewPlayerState}
			end;
		_->
			{noreply, PlayerState}
	end;

%% 读取镇妖台封存经验
handle_info({'READ_TD', AttNum, Horon, MapType, Exp, Spirit}, PlayerState) ->
	Player = PlayerState#player_state.player,
	spawn(fun()-> db_agent:update_td_log_read(Player#player.id) end),
	[NewAttNum, NewHoron, AddHoron] = 
		case MapType of
			999 ->
				[0, 0, Horon];
			_ ->
				[AttNum, Horon, Horon]
		end,
	lib_td:set_td_single(NewAttNum, Player#player.guild_name, Player#player.nickname, 
						  Player#player.career, Player#player.realm, Player#player.id, 
						  NewHoron, 0, AddHoron),
	NewPlayer = lib_player:add_exp(Player, Exp, Spirit, 11),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%% 镇妖台跳波经验补偿
handle_info({'TD_SKIP_COMPENSTATE',Rexp,Rspi},PlayerState) ->
	Player = PlayerState#player_state.player,
	Vip = Player#player.vip,
	Exp_mult = Player#player.other#player_other.goods_buff#goods_cur_buff.exp_mult,
	Spi_mult = Player#player.other#player_other.goods_buff#goods_cur_buff.spi_mult,
	[Addexp,Addspi] = lib_td:count_skip_exp_spi(Vip,Exp_mult,Spi_mult,Rexp,Rspi),
	NewPlayer = lib_player:add_exp(Player,Addexp,Addspi,11),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%% 进入蓝名状态
handle_info('ENTER_BLUE_STATUS', PlayerState) ->
	Player = PlayerState#player_state.player,
	misc:cancel_timer(blue_status_timer),
	BlueStatusTimer = erlang:send_after(30000, self(), 'EXIT_BLUE_STATUS'),
  	NewPlayer = Player#player{
		status = 4
	},
	save_online_info_fields(NewPlayer, [{status, 4}]),
	%% 通知客户端
   	{ok, BinData} = pt_20:write(20008, [NewPlayer#player.id, 4]),
   	mod_scene_agent:send_to_area_scene(NewPlayer#player.scene, NewPlayer#player.x, NewPlayer#player.y, BinData),
	put(blue_status_timer, BlueStatusTimer),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%% 退出蓝名状态
handle_info('EXIT_BLUE_STATUS', PlayerState) ->
	Player = PlayerState#player_state.player,
	NewPlayer = 
        case lib_player:player_status(Player) of
            %% 蓝名
            4 ->                		
                BluePlayer = Player#player{status = 0},
				save_online_info_fields(BluePlayer, [{status, 0}]),
          		BluePlayer;
            _ ->
          		Player
        end,
  	%% 通知客户端
 	{ok, BinData} = pt_20:write(20008, [NewPlayer#player.id, 0]),
  	mod_scene_agent:send_to_area_scene(NewPlayer#player.scene, NewPlayer#player.x, NewPlayer#player.y, BinData),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%% 自动复活
%% ReviveType 复活方式
handle_info({'HOOK_ACTION', Type, Data}, PlayerState) ->
	Player = PlayerState#player_state.player,
	NewPlayerState = 
		case Type of
			%% 自动复活
			1 ->
				[ReviveType] = Data,
				[NewPlayer, RetPlayerState] = lib_battle:player_revive(Player, ReviveType, hook, PlayerState),
				save_online_diff(Player, NewPlayer),
				RetPlayerState#player_state{
					player = NewPlayer			   
				};
			
			%% 自动使用气血包
			2 ->
				[GoodsId] = Data,
				case pp_goods:handle(15050, Player, [GoodsId, 1]) of
					{ok, NewPlayer}  ->
						save_online_diff(Player, NewPlayer),
						lib_player:refresh_client(Player#player.id, 2),
						PlayerState#player_state{
							player = NewPlayer			   
						};
					_ ->
						PlayerState
				end;		
			_ ->
				PlayerState
		end,
    {noreply, NewPlayerState};

%% 打坐回升气血和法力(分城内和城外)
handle_info({'ADD_ROLE_HP_MP', SenceType}, PlayerState) ->
	Player = PlayerState#player_state.player,
	misc:cancel_timer(sit_status_timer),
	NewPlayer = lib_player:handle_role_hp_mp(Player, SenceType),
	save_online_info_fields(NewPlayer, [{hp, NewPlayer#player.hp}, {mp, NewPlayer#player.mp}]),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%% 添加技能持续BUFF
handle_info({'ADD_LAST_SKILL_BUFF', SkillEffect, SkillId, Slv}, PlayerState) ->
	Player = PlayerState#player_state.player,
	Now = util:unixtime(),
	Buff = Player#player.other#player_other.battle_status,					
   	{NewBuff, BuffPlayer} = lib_player:cast_last_skill_buff_loop(SkillEffect, Player, SkillId, Slv, Now, Buff),
	RetPlayer = BuffPlayer#player{
  		other = BuffPlayer#player.other#player_other{
      		battle_status = NewBuff									  
   		}						
   	},
	NewPlayer = lib_player:count_player_attribute(RetPlayer),
    lib_player:send_player_attribute(NewPlayer, 2),    
	lib_player:refresh_player_buff(Player#player.other#player_other.pid_send, NewBuff, Now),
	save_online_diff(Player, NewPlayer),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%% 更新玩家BUFF信息
handle_info({'UPDATE_SKILL_BUFF', Key}, PlayerState) ->
	Player = PlayerState#player_state.player,
	lib_player:set_skill_buff_timer(undefined, Key),
	Buff = Player#player.other#player_other.battle_status,
    NewPlayer = 
		case Key of
			%% 朱雀盾
			shield ->
				NewBuff = lists:keydelete(Key, 1, Buff),
				IsSpring =
					case lib_spring:is_spring_scene(Player#player.scene) of
						true ->
							Player#player.other#player_other.is_spring;
						false ->
							0
					end,
				RetPlayer = Player#player{
              		other = Player#player.other#player_other{
                   		battle_status = NewBuff,
						is_spring = IsSpring
                	}						
              	},
				save_online_info_fields(RetPlayer, [{battle_status, NewBuff}, {is_spring, IsSpring}]),
				{ok, BinData} = pt_20:write(20105, Player#player.id),
				mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, BinData),
				RetPlayer;
			_ ->
		        case lists:keyfind(Key, 1, Buff) of
		            false ->
		                Player;
		            {Key, _Val, _EndTime, _SkillId, _Slv} ->
						NewBuff = lists:keydelete(Key, 1, Buff),
						RetPlayer = Player#player{
		              		other = Player#player.other#player_other{
		                   		battle_status = NewBuff									  
		                	}						
		              	},
						CountPlayer = lib_player:count_player_attribute(RetPlayer),
						lib_player:send_player_attribute(CountPlayer, 2),
						save_online_diff(Player, CountPlayer),
						CountPlayer		
		        end
		end,
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%% 更新玩家物品buff效果
handle_info({'UPDATE_GOODS_BUFF', Type}, PlayerState) ->
	{PlayerBuff, _BuffInfo} = lib_goods:update_goods_buff_action(PlayerState#player_state.player, Type),
	NewPlayer = lib_peach:player_sit_auto_add(PlayerBuff),
	save_online_info_fields(NewPlayer, [{status,NewPlayer#player.status}]),
	NewPlayerState = PlayerState#player_state{ player = NewPlayer},
%% 	?DEBUG("PLAYER CUR_BUFF turned = ~p, fsh = ~p",[NewPlayer#player.other#player_other.goods_buff#goods_cur_buff.turned_mult,
%% 											NewPlayer#player.other#player_other.goods_buff#goods_cur_buff.chr_fash]),
    {noreply, NewPlayerState};

%% 设置用户信息(按字段+数值)
handle_info({'SET_PLAYER_INFO', List}, PlayerState) when is_list(List) ->
	NewPlayer = lib_player_rw:set_player_info_fields(PlayerState#player_state.player, List),
	save_online_info_fields(NewPlayer, List),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%% 设置玩家状态数据
handle_info({'SET_BATTLE_LIMIT', BattleLimit}, PlayerState) ->
	Player = PlayerState#player_state.player,
	NewPlayer = Player#player{
  		other = Player#player.other#player_other{
    		battle_limit = BattleLimit									 
     	}			  
   	},
	save_online_info_fields(NewPlayer, [{battle_limit, BattleLimit}]),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%%组队亲密度加成                                       
handle_info({'SET_TEAM_CLOSE_INFO', [BuffLevel,Mp,Hp,Ap,Attack,Mark]}, PlayerState)->
	Player = PlayerState#player_state.player,
	
	if 
		Mark =:= 1 ->	
			List = [{mp_lim,Player#player.mp_lim+Mp},{hp_lim,Player#player.hp_lim+Hp}, {anti_wind,Player#player.anti_wind+Ap}, 
															  {anti_fire,Player#player.anti_fire+Ap}, {anti_water,Player#player.anti_water+Ap},
															  {anti_thunder,Player#player.anti_thunder+Ap},{anti_soil,Player#player.anti_soil+Ap},
															   {min_attack,Player#player.min_attack+Attack},{max_attack,Player#player.max_attack+Attack}],
		   	NewPlayer = lib_player_rw:set_player_info_fields(Player, List),
		   	%%组队亲密度加成buff
		   	NewPlayer1 = NewPlayer#player{other = NewPlayer#player.other#player_other{team_buff_level = BuffLevel}},
		   	save_online_info_fields(NewPlayer1, List);
	   	true ->
			List1 = [{mp_lim,Player#player.mp_lim-Mp},{hp_lim,Player#player.hp_lim-Hp}, {anti_wind,Player#player.anti_wind-Ap}, 
															  {anti_fire,Player#player.anti_fire-Ap}, {anti_water,Player#player.anti_water-Ap},
															  {anti_thunder,Player#player.anti_thunder-Ap},{anti_soil,Player#player.anti_soil-Ap},
															   {min_attack,Player#player.min_attack-Attack},{max_attack,Player#player.max_attack-Attack}],
		   	NewPlayer = lib_player_rw:set_player_info_fields(Player,List1),
		   	NewPlayer1 = NewPlayer#player{other = NewPlayer#player.other#player_other{team_buff_level = 0}},
           	save_online_info_fields(NewPlayer1, List1)
	end,	   
	lib_player:send_player_attribute(NewPlayer1, 1),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer1			   
	},
    {noreply, NewPlayerState};

%% 改变玩家移动速度
handle_info({'CHANGE_SPEED', _Speed, _Mount}, PlayerState) ->
	Player = PlayerState#player_state.player,
	case get(change_speed_timer) of
		[undefined, _, _] ->
			skip;
		[ChangeSpeedTimer, _, _] ->
			erlang:cancel_timer(ChangeSpeedTimer);
		_ ->
			skip
	end,
	put(change_speed_timer, [undefined, ?PLAYER_SPEED, 0]),

	NewPlayer = lib_player:count_player_speed(Player),
	save_online_info_fields(NewPlayer, [{speed, NewPlayer#player.speed}]),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

handle_info({'SET_TIME_PLAYER', Interval, Message}, PlayerState) ->
	erlang:send_after(Interval, self(), Message),
	{noreply, PlayerState};

%% 诛邪的特殊物品记录清零操作
handle_info('UPDATE_BOX_GOODS_TRACE', PlayerState) ->
	Player = PlayerState#player_state.player,
	case lib_box:get_box_goods_trace() of
		[] ->
			no_action;
		_Value ->
			spawn(fun()-> db_agent:update_player_box_goods_trace_time_num(log_box_player, 
													[{box_goods_trace, util:term_to_string([])}], 
													[{player_id, Player#player.id}]) end),
			lib_box:put_box_goods_trace([])
	end,
	%%启动定时器，准备下一次清零操作
	erlang:send_after(?ONE_DAY_MILLISECONDS, self(), 'UPDATE_BOX_GOODS_TRACE'),
	{noreply, PlayerState};

%%LIMIT_PURPLE_EQUIT_TIME后，诛邪的紫装出现标志位归零
handle_info('UPDATE_BOX_PURPLE_TIME', PlayerState) ->
	Player = PlayerState#player_state.player,
	spawn(fun()-> db_agent:update_player_box_goods_trace_time_num(log_box_player, 
													[{purple_time, 0}], 
													[{player_id, Player#player.id}]) end),
	lib_box:put_box_purple_time(0),
	{noreply, PlayerState};

%% 处理节点开启事件
handle_info({nodeup, _Node}, PlayerState) ->
	{noreply, PlayerState};

%% 处理节点关闭事件
handle_info({nodedown, _Node}, PlayerState) ->
	Player = PlayerState#player_state.player,
	TeamPlayer =
		case is_pid(Player#player.other#player_other.pid_team) of
			true ->
			  	case misc:is_process_alive(Player#player.other#player_other.pid_team) of
					true -> 
						Player;
					%% 队伍进程节点关闭
					_ ->	
						{ok, BinData} = pt_24:write(24017, []),
						lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
						Player#player{
							other = Player#player.other#player_other{
								pid_team = undefined
							}
						}
				end;
			false -> 
				Player
		end,
 	NewPlayer =
		case is_pid(TeamPlayer#player.other#player_other.pid_dungeon) of
			true ->
			   	case misc:is_process_alive(TeamPlayer#player.other#player_other.pid_dungeon) of
					true -> 
						TeamPlayer;
					%% 副本所在节点关闭
					_ ->	
						case mod_dungeon:get_outside_scene(TeamPlayer#player.scene) of
         					[_Dungeon_id, Dungeon_out] -> 
								[Sid, X, Y] = Dungeon_out,
								{ok, BinData1} = pt_12:write(12005, [Sid, X, Y, <<>>, Sid, 0, 0, 0]),
    							lib_send:send_to_sid(TeamPlayer#player.other#player_other.pid_send, BinData1),
	 					    	TeamPlayer#player{
									other=TeamPlayer#player.other#player_other{
										pid_dungeon = undefined
									}, 
									scene = Sid, 
									x = X, 
									y = Y
								};
							_ -> 
								TeamPlayer
						end
				end;
		  	false -> 
				TeamPlayer
		end,
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%% 判断是否死游客
handle_info({check_static_player, [Scene, X, Y, Counter]}, PlayerState) ->
	Player = PlayerState#player_state.player,
	if 
		[Player#player.scene, Player#player.x, Player#player.y] == [Scene, X, Y] ->
			if 
				%% 9级以下，30分钟都不移动, 则做退出处理  
				Counter >= 30 -> 
		   			{ok, BinData} = pt_10:write(10007, 6),
					lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
%% 					Now = util:unixtime(),
%% 					db_agent:insert_kick_off_log(Player#player.id, Player#player.nickname, 1, Now, Scene, X, Y),
    				{stop, normal, PlayerState};
		   		true ->
					erlang:send_after(60 * 1000, self(), {check_static_player, [Player#player.scene, Player#player.x, Player#player.y, Counter + 1]}),
					{noreply, PlayerState}
			end;
		true -> 
			{noreply, PlayerState}
	end;

%% 删除N milliseconds 后的紫装id
handle_info({delete_purple_equip, NewPurpleGoods}, PlayerState) ->
	lib_box:delete_purple_equip_list_record(NewPurpleGoods),
	{noreply, PlayerState};

%% 子socket连接
handle_info({child_socket_join, N, Socket}, PlayerState) ->
	Player = PlayerState#player_state.player,
	NewPlayer = 
        case N of
            2 ->
                %% 打开socket2广播信息进程
                Pid_send2 = lists:map(fun(_N)-> 
                            {ok,_Pid_send} = mod_pid_send:start(Socket,_N),
                            _Pid_send
                        end, lists:seq(1,?SEND_MSG)),
                Player#player{other=Player#player.other#player_other{socket2 = Socket,pid_send2 = Pid_send2}};
            3 ->
                %% 打开socket3广播信息进程
                Pid_send3 = lists:map(fun(_N)-> 
                            {ok,_Pid_send} = mod_pid_send:start(Socket,_N),
                            _Pid_send
                        end, lists:seq(1,?SEND_MSG)),
                Player#player{other=Player#player.other#player_other{socket3 = Socket,pid_send3 = Pid_send3}};
            _ -> Player
        end,
	if
		N > 1 -> 
			ets:insert(?ETS_ONLINE, NewPlayer);
		true ->
			skip
	end,
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};
	
handle_info({'PLAYER_INTO_PEACH'}, PlayerState) ->
	Player = PlayerState#player_state.player,
	{SaveType, NPlayer} = lib_peach:player_revive_into_peach(Player),
	%%因为是保存在player_other中，仅做内存的更新操作,
	case SaveType =:= 1 of
		true ->
			save_online_diff(Player, NPlayer);
		false ->
			skip
	end,
	NewPlayerState = PlayerState#player_state{
		player = NPlayer			   
	},
    {noreply, NewPlayerState};

handle_info({'PEACH_ADD_EXP_SPIRIT'}, PlayerState) ->
	Status = PlayerState#player_state.player,
	case lib_peach:is_local_peach(Status#player.scene, [Status#player.x, Status#player.y])of
		ok -> %%是否在桃树区域
			case lib_peach:get_player_dict(peach_add_exp_spirit) of
				true ->
					case Status#player.other#player_other.goods_buff#goods_cur_buff.peach_mult of
						Type when Type =:= 2 orelse Type =:= 3 orelse Type =:= 4 -> %%buff是否还在
							PlayerBuff = lib_goods:get_player_goodsbuffs(),
							case lists:keyfind(23409, 1, PlayerBuff) of
								false ->
									lib_peach:erase_player_dict(peach_add_exp_spirit),
									case Status#player.status =:= 7 of
										true ->
											lib_peach:cancel_peach_timer(eat_peach_timer),%%蟠桃的取消定时器
											lib_peach:cancel_auto_sit_timer(Status#player.scene, Status#player.x, Status#player.y, Status#player.mount),%%取消自动打坐+经验的定时器
											{SaveType, NewStatus} = lib_peach:update_peach_revel(1, Status, true);
										false ->
											{SaveType, NewStatus} = lib_peach:update_peach_revel(1, Status, true)
									end;
								{_Id, _V, T} ->
									NowTime = util:unixtime(),
									case NowTime > T of
										true ->
											NPlayerBuff = lists:keydelete(23409, 1, PlayerBuff),
											db_agent:del_goods_buff(Status#player.id, 23409),
											put(goods_buffs, NPlayerBuff),
											lib_peach:erase_player_dict(peach_add_exp_spirit),
											case Status#player.status =:= 7 of
												true ->
													lib_peach:cancel_peach_timer(eat_peach_timer),%%蟠桃的取消定时器
													lib_peach:cancel_auto_sit_timer(Status#player.scene, Status#player.x, Status#player.y, Status#player.mount),%%取消自动打坐+经验的定时器
													{SaveType, NewStatus} = lib_peach:update_peach_revel(1, Status, true);
												false ->
													{SaveType, NewStatus} = lib_peach:update_peach_revel(1, Status, true)
											end;
										false ->
											{Exp, Spirit} = lib_peach:get_peach_exp_spirit(Type, Status#player.lv),
											lib_peach:put_player_dict(peach_add_exp_spirit, 1),
											lib_peach:cancel_peach_timer(eat_peach_timer),%%蟠桃的取消定时器
											lib_peach:cancel_auto_sit_timer(Status#player.scene, Status#player.x, Status#player.y, Status#player.mount),%%取消自动打坐+经验的定时器
											TimeRef = erlang:send_after(?PEACH_ADD_EXP_SPIRIT_STAMPTIME, self(), {'PEACH_ADD_EXP_SPIRIT'}),
											put(eat_peach_timer, TimeRef),
											NewStatus1 = lib_player:add_exp(Status, Exp, Spirit, 7),
											%%做位置的标注
											put(peach_coord, 1),
											{SaveType, NewStatus} = lib_peach:update_peach_revel(Type, NewStatus1, false)
									end
							end;
						_Other ->
							lib_peach:erase_player_dict(peach_add_exp_spirit),
							case Status#player.status =:= 7 of
								true ->
									lib_peach:cancel_peach_timer(eat_peach_timer),%%蟠桃的取消定时器
									lib_peach:cancel_auto_sit_timer(Status#player.scene, Status#player.x, Status#player.y, Status#player.mount),%%取消自动打坐+经验的定时器
%% 									?DEBUG("11111111111:~p",[Status#player.other#player_other.peach_revel]),
									{SaveType, NewStatus} = lib_peach:update_peach_revel(1, Status, true);
								false ->
%% 									{ok, NewStatus} = lib_player:cancelSitStatus(Status),
%% 									SaveType = 1
%% 									?DEBUG("222222222222:~p",[Status#player.other#player_other.peach_revel]),
									{SaveType, NewStatus} = lib_peach:update_peach_revel(1, Status, true)
							end
					end;
				false ->
%% 					?DEBUG("33333333:~p",[Status#player.other#player_other.peach_revel]),
					{SaveType, NewStatus} = lib_peach:update_peach_revel(1, Status, false);
				undefined ->
%% 					?DEBUG("44444444:~p",[Status#player.other#player_other.peach_revel]),
					{SaveType, NewStatus} = lib_peach:update_peach_revel(1, Status, false),
					lib_peach:erase_player_dict(peach_add_exp_spirit)
			end;
		_Fail ->%%不在了
%% 			?DEBUG("555555555:~p",[Status#player.other#player_other.peach_revel]),
			{SaveType, NewStatus} = lib_peach:update_peach_revel(1, Status, false)
	end,
	%%因为是保存在player_other中，仅做内存的更新操作,
	case SaveType =:= 1 of
		true ->
			save_online_diff(Status, NewStatus);
		false ->
			skip
	end,
	NewPlayerState = PlayerState#player_state{
		player = NewStatus			   
	},
    {noreply, NewPlayerState};

%%玩家传送
handle_info({'PEACH_SCENE_CHANGE'}, PlayerState) ->
	Status = PlayerState#player_state.player,
	{SaveType, NewStatus} = 
		case lib_peach:is_local_peach(Status#player.scene, [Status#player.x, Status#player.y])of
			ok -> %%是否在桃树区域
				erlang:send_after(3000, self(), {'PLAYER_INTO_PEACH'}),
				{0, Status};
			_Fail ->%%不在了
%% 				?DEBUG("555555555:~p",[Status#player.other#player_other.peach_revel]),
				lib_peach:update_peach_revel(1, Status, false)
		end,
	%%因为是保存在player_other中，仅做内存的更新操作,
	case SaveType =:= 1 of
		true ->
			save_online_diff(Status, NewStatus);
		false ->
			skip
	end,
	NewPlayerState = PlayerState#player_state{
		player = NewStatus			   
	},
    {noreply, NewPlayerState};

%% 双修增加经验，灵力，修为
handle_info({'DOUBLE_REST_ADD_EXP',[OtherPlayerId,Pid,Num]}, PlayerState) ->
	misc:cancel_timer(double_rest_timer),
	Status = PlayerState#player_state.player,
	%%对方不在线立即取消双修状态
	case misc:is_process_alive(Pid) == false of
		true ->
		   {ok, NewPlayer} = lib_player:cancel_double_rest(Status,1),
		   save_online_info_fields(NewPlayer, [{status,NewPlayer#player.status},{double_rest_id, 0}]),
		   NewPlayerState = PlayerState#player_state{player = NewPlayer},
		   {noreply, NewPlayerState};
	   %%对方在线，开始加经验
	   false ->
		   {ok, NewPlayer} = lib_player:start_double_rest(Status,[OtherPlayerId,Pid,Num]),
		   save_online_info_fields(NewPlayer, [{status,NewPlayer#player.status},{double_rest_id, OtherPlayerId}]),
		   NewPlayerState = PlayerState#player_state{player = NewPlayer},
		   {noreply, NewPlayerState}
	end;

%%取消双修加经验定时器
handle_info({'CANEL_DOUBLE_REST_EXP'}, PlayerState) ->
	Status = PlayerState#player_state.player,
	{ok, NewPlayer} = lib_player:cancel_double_rest(Status,1),
	save_online_info_fields(NewPlayer, [{status,NewPlayer#player.status}, {double_rest_id, 0}]),
	NewPlayerState = PlayerState#player_state{player = NewPlayer},
	{noreply, NewPlayerState};

%% 双修增加亲密度
handle_info({'DOUBLE_TEST_LOVE',OtherPlayer}, PlayerState) ->
	misc:cancel_timer(double_rest_close_timer),
	Player = PlayerState#player_state.player,
	lib_relationship:close(double_rest,Player#player.id,OtherPlayer#player.id,[0,Player#player.other#player_other.pid_team,OtherPlayer#player.other#player_other.pid_team]),
	Double_rest_close_timer = erlang:send_after(lib_double_rest:get_double_love_value_time(), self(), {'DOUBLE_TEST_LOVE',OtherPlayer}),
	put(double_rest_close_timer,Double_rest_close_timer),
	{noreply, PlayerState};

%% 双修增加吃桃经验
handle_info({'DOUBLE_TEST_PEACH'}, PlayerState) ->
	misc:cancel_timer(double_rest_peach),
	Status = PlayerState#player_state.player,
	{ok, NewPlayer} = lib_player:double_rest_peach(Status),
	save_online_info_fields(NewPlayer, [{status,NewPlayer#player.status}]),
	NewPlayerState = PlayerState#player_state{player = NewPlayer},
	{noreply, NewPlayerState};

%%检查轻功技能
handle_info({'UPDATE_LIGHT_SKILL'}, Status) ->
	NewPlayer = lib_skill:updata_light_skill(Status#player_state.player),
	NewPlayerState = Status#player_state{
		player = NewPlayer			   
	},
	{noreply, NewPlayerState};

%%检查VIP状态
handle_info({'CHECK_VIP_STATE'},PlayerState)->
	misc:cancel_timer(check_vip_state),
	Status = PlayerState#player_state.player,
	NewStatus1 = if Status#player.vip >0 ->
		NewStatus = lib_vip:check_vip_state(Status),
		if NewStatus#player.vip > 0 ->
			   Timer = abs(Status#player.vip_time-util:unixtime())+3,
			   if Timer < 86400->
					  HandleTimer=erlang:send_after(Timer*1000,self(),{'CHECK_VIP_STATE'}),
					  put(check_vip_state,HandleTimer);
				  true->skip
			   end,
			   NewStatus;
		   true->
			   NewStatus
		end;
		true->
			Status
	end,
	NewPlayerState = PlayerState#player_state{
		player = NewStatus1			   
	},
	{noreply, NewPlayerState};

%% 农庄定时器 add by zkj
%% 当状态改变的时候离开农庄
handle_info('FARM_STATUS', PlayerState) ->
	Player = PlayerState#player_state.player,
	case lib_manor:judge_player_status(Player) of
		ok ->
			Farm_status_timer = erlang:send_after(5 * 1000, self(), 'FARM_STATUS'),
			put(farm_status_timer, Farm_status_timer);
		_ ->
			lib_manor:farm_exit(Player, []),
			{ok, BinData} = pt_42:write(42025, [ok]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData)
	end,
	{noreply, PlayerState};

%% 农庄定时器 add by zkj
%% 判断庄园是否有果实成熟
handle_info('FARM_MATURE_STATUS', PlayerState) ->
	Player = PlayerState#player_state.player,
	{ok, BinData} = pt_42:write(42017, 1),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	lib_manor:get_mature_status(Player,[]),
	{noreply, PlayerState};

%%传送出挂机区
handle_info({'HOOK_SECNE_SEND_OUT'},PlayerState)->
	Player = PlayerState#player_state.player,
	case lists:member(Player#player.scene,data_scene:get_hook_scene_list()) of
		true->
			NewPlayer = lib_deliver:deliver(Player,300,66,166,0);
		false->
			NewPlayer=Player
	end,
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
    {noreply, NewPlayerState};

%%检查拜师，收徒指引
handle_info({'MASTER_LEAD'},PlayerState)->
	Player = PlayerState#player_state.player,
	if Player#player.lv < 10 orelse Player#player.lv>36 ->skip;
	   Player#player.lv>=10 andalso Player#player.lv =< 29->
		   case mod_master_apprentice:get_master_info(Player#player.id)=:=[] of
			   false->
				   pp_task:handle(30086,Player,[0]);
			   true->
				   pp_task:handle(30086,Player,[1])
		   end;
	   true->
			case mod_master_apprentice:get_my_apprentice_info_page(Player#player.id)=:=[] of
				false->
					pp_task:handle(30086,Player,[0]);
				true->
					case mod_master_apprentice:is_enter_master_charts(Player#player.id) of
						true->
							pp_task:handle(30086,Player,[0]);
						false->
							pp_task:handle(30086,Player,[2])
					end
			end
	end,
	   
	{noreply,PlayerState};


%%在活动前一段时间的检查
handle_info({'CHECK_HOLIDAY_TIME'}, PlayerState) ->
	%% 活动七：飞跃竞技场	
	Player = PlayerState#player_state.player,
	lib_act_interf:check_player_arena_ranking(Player),
	pp_task:handle(30087,PlayerState#player_state.player,[]),
	{noreply,PlayerState};

%% 活动结束
handle_info({'OPENING_AWARD_END'},PlayerState)->
	Player = PlayerState#player_state.player,
	{ok, BinData} = pt_30:write(30087, []),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	{noreply,PlayerState};

%% 检查目标是否可领取
handle_info({'TARGET_STATE'}, PlayerState) ->
	Player = PlayerState#player_state.player,
	spawn(fun()-> lib_target:check_target_state(Player) end),
	{noreply, PlayerState};

%% 结束默契度测试
handle_info(end_privity_test,PlayerState)->
	PlayerStatus = PlayerState#player_state.player,
	case PlayerStatus#player.other#player_other.privity_info of
		[]->NewPlayerStatus=PlayerStatus;
		PrivityInfo->
			%%[对手，时间，默契度，当前答案，[题库]]
			[_InviteId,Timestamp,Privity,Answer,_Question] = PrivityInfo,
			NowTime = util:unixtime(),
			case NowTime>Timestamp of
				true->
					NewPlayer = lib_love:update_privity(PlayerStatus,[]),
					lib_love:privity_finish(NewPlayer,Privity),
					NewPlayerStatus = lib_love:privity_award(NewPlayer,Privity),
					save_online_diff(PlayerStatus,NewPlayerStatus);
				false->
					NewPlayerStatus= lib_love:answer(PlayerStatus,Answer),
					Time = Timestamp-NowTime,
					erlang:send_after(Time*1000, self(), end_privity_test)
			end
	end,
	NewPlayerState = PlayerState#player_state{
		player = NewPlayerStatus			   
	},
    {noreply, NewPlayerState};

%% 初始化玩家的成就系统数据
handle_info({'UPDATE_PLAYER_ACHIEVE'}, PlayerState) ->
	Player = PlayerState#player_state.player,
	#player{id = PlayerId,
			other = Other} = Player,
	#player_other{titles = Titles} = Other,
	%%检测是否已经加载过 成就系统的数据
	lib_achieve_inline:check_achieve_init(PlayerId),
	case lib_achieve_inline:get_achieve_ets(PlayerId) of
		[] ->
			NPlayer = Player;
		[Achieve] ->
			PTitles = Achieve#ets_achieve.ach_titles,
			NowTime = util:unixtime(),
			{U1, U2, NTitles, NPTitles} = 
				lists:foldl(fun(Elem, AccIn) ->
									{EU1, EU2, Ts, PTs} = AccIn,
									#p_title_elem{tid = Tid,
												  expi = Expi} = Elem,
									case Expi of
										1 ->
											{EU1, EU2, Ts, [Elem|PTs]};
										_ ->
											case NowTime > Expi of
												true ->
													case lists:member(Tid, Ts) of
														true ->
															{1, 1, lists:delete(Tid, Ts), PTs};
														false ->
															{EU1, 1, Ts, PTs}
													end;
												false ->
													{EU1, EU2, Ts, [Elem|PTs]}
											end
									end
							end, {0, 0, Titles, []}, PTitles),
			case U1 of
				1->%%有更新
					lib_love:bc_title_in_scene(Player, NTitles);
				_->
					skip
			end,
			case U1 =:= 1 orelse U2 =:= 1 of
				true ->
					%%改ets
					NewAchieve = Achieve#ets_achieve{ach_titles = NPTitles},
					lib_achieve_inline:update_achieve_ets(NewAchieve),
					NewOther = Player#player.other#player_other{titles = NTitles},
					NPlayer = Player#player{other = NewOther},
					save_online_info_fields(NPlayer, [{titles, NTitles}]),
					%%改数据库
					NTitlesStr = util:term_to_string(NTitles),
					NPTitlesStr = util:term_to_string(NPTitles),
					ValueList = [{ptitle, NTitlesStr}, {ptitles, NPTitlesStr}],
					WhereList = [{pid, Player#player.id}],
					db_agent:update_player_other(player_other, ValueList, WhereList);
				false ->
					NPlayer = Player
			end
	end,
	erlang:send_after(300000, self(), {'UPDATE_PLAYER_ACHIEVE'}),
	NewPlayerState = PlayerState#player_state{player = NPlayer},
	{noreply, NewPlayerState};


%% 触发统计玩家的成就系统数据
handle_info({'CHECK_ACH_OLD_DATA', AchIeveUpdate}, PlayerState) ->
	%% 统计老数据
	spawn(fun()-> lib_achieve_outline:check_player_old_date(PlayerState#player_state.player, AchIeveUpdate) end),
	{noreply, PlayerState};

%% 定时保存成就数据和活跃度在线时间统计
handle_info({'UPDATE_ACH_STATISTICS'}, PlayerState) ->
	Player = PlayerState#player_state.player,
	spawn(fun()->
		%% 添加玩家活跃度统计
		lib_activity:update_activity_data(online, Player#player.other#player_other.pid, Player#player.id, 10),
		lib_achieve_outline:update_player_statistics(Player#player.id),
		%% 更新玩家的战斗力值(只有大于24级才记录表)
		if 
			Player#player.lv >= 25  ->
				%%坐骑战斗力
				MountInfo = lib_mount:get_out_mount(Player#player.id),
				if is_record(MountInfo,ets_mount) ->
					   	MountMultAttributeList = data_mount:get_prop_mount(MountInfo), 
					   	Mount_Batt_val = data_mount:count_mount_batt(MountMultAttributeList),
						db_agent:update_mount_value(MountInfo#ets_mount.id,MountInfo#ets_mount.level,MountInfo#ets_mount.exp,Mount_Batt_val);
					true ->
					   skip
				end,
				%%角色战斗力
				Batt_Value = lib_player:count_value(Player#player.other#player_other.batt_value),
				db_agent:update_batt_value(Player#player.id, Batt_Value);
			true ->
				skip
		end
	end),
	%% 减罪恶值
	NewPlayer = lib_player:deduct_evil(Player),
	NewPlayerState = PlayerState#player_state{
		player = NewPlayer			   
	},
	{noreply, NewPlayerState};

%% 温泉定时+经验
handle_info({'SPRING_ADD_EXP_SPRI'}, PlayerState) ->
	case lib_spring:is_spring_scene(PlayerState#player_state.player#player.scene) of
		true ->
			NewPlayer = lib_spring:spring_add_expspi(PlayerState#player_state.player, 1),
			NewPlayerState = 
				PlayerState#player_state{
										  player = NewPlayer	
										};
		false ->
			NewPlayerState = PlayerState
	end,
    {noreply, NewPlayerState};
	
%% 表情动作，+经验
handle_info({'SPRING_FACES_ADD_EXPSPI',[CoupleName]}, PlayerState) ->
	case lib_spring:is_spring_scene(PlayerState#player_state.player#player.scene) of
		true ->
			Player = PlayerState#player_state.player,
			case tool:to_list(Player#player.couple_name) == CoupleName of
				true->
					lib_task:event(lover_hotspring,null,Player);
				false->skip
			end,
			NewPlayer = lib_spring:spring_add_expspi(Player, 0),
			NewPlayerState = PlayerState#player_state{
													  player = NewPlayer		
													 };
		false ->
			NewPlayerState = PlayerState
	end,
	{noreply, NewPlayerState};

%% 婚宴经验灵力定时器
handle_info({'WEDDING_ADD',Wtype}, PlayerState) ->
	case lib_marry:is_wedding_love_scene(PlayerState#player_state.player#player.scene) of
		true ->
			NewPlayer = lib_marry:wedding_add_timmer(PlayerState#player_state.player,Wtype),
			NewPlayerState = 
				PlayerState#player_state{
										  player = NewPlayer	
										};
		false ->
			NewPlayerState = PlayerState
	end,
    {noreply, NewPlayerState};

%%取消婚期，扣除100YB
handle_info({'cancel_wedding_pay'}, PlayerState) ->
	Player = PlayerState#player_state.player,
	Player1 = lib_goods:cost_money(Player, 100, gold, 4820),
	lib_player:send_player_attribute(Player1, 2),
	{noreply,PlayerState#player_state{player = Player1}};

%% 节日活动充值返还
handle_info({'HOLIDAY_RETURN_AWARD'},PlayerState) ->
	lib_activities:holiday_return_award(PlayerState#player_state.player),
	{noreply,PlayerState};

%% 氏族祝福任务触发立即完成(跟活跃度的完成情况挂钩)
handle_info({'GWISH_TASK_FINISH_RIGHTNOW', TId}, PlayerState) ->
	Player = PlayerState#player_state.player,
	PId = Player#player.id,
	{_Act, Actions, _Goods} = lib_activity:check_load_activity(PId),
	lib_guild_wish:gwish_task_finish_rightnow(Actions, TId, Player),
	{noreply,PlayerState};

%%给玩家在神魔乱斗的时间做最后5分钟的倒计时纠正
handle_info({'UPDATE_SEND_WARFARE_ICON'}, PlayerState) ->
	Player = PlayerState#player_state.player,
	lib_warfare:check_send_warfare_icon(Player#player.other#player_other.pid_send),
	{noreply,PlayerState};

%%收贺礼
handle_info({'ADD_WEDDING_GIFT',Coin,Gold,Mid},PlayerState) ->
	Player = PlayerState#player_state.player,
	Player1 = lib_goods:add_money(Player, Gold, gold, 4809),
	Player2 = lib_goods:add_money(Player1, Coin, coin, 4809),
	case ets:lookup(?ETS_MARRY,{Mid,Player#player.id}) of 
		[] -> skip;
		[M|_Rets] ->
			%%内存更新结婚记录中收到的铜币、元宝
			NewCoin = M#ets_marry.rec_coin + Coin,
			NewGold = M#ets_marry.rec_gold + Gold,
			ets:insert(?ETS_MARRY, M#ets_marry{rec_coin = NewCoin, rec_gold = NewGold})
	end,
	lib_player:send_player_attribute(Player2, 2),
	{noreply,PlayerState#player_state{player = Player2}};

handle_info({'BOOK_WEDDING_PAY',Gold},PlayerState) ->
	Player = PlayerState#player_state.player,
	Player2 =
		if Player#player.gold < Gold ->
			   {ok,BinData} = pt_48:write(48004,6),
			   lib_send:send_to_uid(Player#player.id,BinData),
			   Player;
		   true ->
			   Player1 = lib_goods:cost_money(Player, Gold, gold, 4809),
			   Player1
		end,
	lib_player:send_player_attribute(Player2,2),
	{noreply,PlayerState#player_state{player = Player2}};

%%女方检测结婚条件
handle_info({'girl_propose_check',Bpid,Bname,Bid},PlayerState) ->
	lib_marry:check_girl_propose(PlayerState#player_state.player,Bpid,Bname,Bid),
	{noreply, PlayerState};

%%男方记录提亲信息
handle_info({'propose_sucess',Gid},PlayerState) ->
	Player = PlayerState#player_state.player,
	Propose = #ets_propose_info{boy_id = Player#player.id, girl_id = Gid},
	ets:insert(?ETS_PROPOSE_INFO, Propose),
	%%一分钟后删除
	erlang:send_after(60000, self(), {'delete_propose'}),
	{noreply, PlayerState};

%%女方处理结婚成功
handle_info({'marry_sucess',Marry},PlayerState) ->
	Player = PlayerState#player_state.player,
	ets:insert(?ETS_MARRY, Marry),
	gen_server:cast(Player#player.other#player_other.pid_task,{'refresh_task',Player}),
	{noreply, PlayerState};

%%删除提亲记录
handle_info({'delete_propose'},PlayerState) ->
	Player = PlayerState#player_state.player,
	catch ets:delete(?ETS_PROPOSE_INFO, Player#player.id),
	{noreply, PlayerState};

%%结婚处理
handle_info({'check_can_marry',Gpid,Gid,Grealm},PlayerState) ->
	Player = PlayerState#player_state.player,
	{Res,Player2} = lib_marry:check_can_marry(Player,Gpid,Gid,Grealm),
	case Res of
		false -> skip;
		true -> save_online_diff(Player,Player2),
				lib_player:send_player_attribute(Player2, 2)
	end,
	{noreply, PlayerState#player_state{player = Player2}};

%%婚宴结束处理
handle_info({'end_do_marry',RName,DbId},PlayerState) ->
	Player = PlayerState#player_state.player,
	case ets:lookup(?ETS_MARRY,{DbId,Player#player.id}) of
		[] -> skip;
		[Marry|_Os] ->
			ets:insert(?ETS_MARRY,Marry#ets_marry{do_wedding = 1})
	end,
	{ok,Data12075} = pt_12:write(12075,{Player#player.id,RName}),
	%%场景广播
	mod_scene_agent:send_to_area_scene(Player#player.scene,Player#player.x, Player#player.y, Data12075),
	Player1 = Player#player{couple_name = RName},
	erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(Player#player.other#player_other.pid, 632, [1]))end),%%婚宴成就判断
	save_online_diff(Player, Player1),
	%%通知客户端更新
	lib_player:send_player_attribute(Player1,2),
	{noreply, PlayerState#player_state{player = Player1}};

%%离婚处理
handle_info({'do_divorce',Id,Type,Now},PlayerState) ->
	Player = PlayerState#player_state.player,
	{DbId,Rid} = Id,
	case ets:lookup(?ETS_MARRY, {DbId,Player#player.id}) of
		[]->
			skip;
		[M|_Rets] ->
			ets:insert(?ETS_MARRY, M#ets_marry{divorce = 1, div_time = Now})
	end,
	%%扣除亲密度
	case Type of
		1 ->
			skip;
		2 ->
			lib_relationship:del_close_etsonly(Player#player.id,Rid,2000)
	end,
	%%清除夫妻任务
	pp_task:handle(30005, Player, [84010]),
	Player1 = Player#player{couple_name = ""},
	save_online_diff(Player,Player1),
	lib_player:send_player_attribute(Player1,2),
	%%广播
	{ok,Data12075} = pt_12:write(12075,{Player#player.id,""}),
	%%场景广播
	mod_scene_agent:send_to_area_scene(Player#player.scene,Player#player.x, Player#player.y, Data12075),
	{noreply, PlayerState#player_state{player = Player1}};

%%查找配偶，并求助
handle_info({'call_help',[Der,Aname,Aid]}, PlayerState) ->
	lib_marry:call_help([Der,Aname,Aid]),
	{noreply, PlayerState};

%%接收配偶被打信息
handle_info({'cuple_help',[Aname,Scene,X,Y,Field]}, PlayerState) ->
	Player = PlayerState#player_state.player,
	NowTime = util:unixtime(),
	lib_marry:put_pk_coord({NowTime, Scene, X, Y}),
	{ok,Bin} = pt_48:write(48022,{Aname,Field,Scene,X,Y}),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, Bin),
	{noreply, PlayerState};
    
%% 设置战斗中产生的修改
handle_info({'SET_BATTLE_STATUS', {Type, Data}}, PlayerState) ->
	Player = PlayerState#player_state.player,
	RetPlayer = 
        case Type of
			%% 限制状态
            1 -> 
                [Buff, BattleLimit, Interval] = Data,
				NewPlayer = Player#player{
             		other = Player#player.other#player_other{
             			battle_status = Buff,
						battle_limit = BattleLimit								  
              		}						
               	},
                erlang:send_after(Interval, self(), {'SET_PLAYER_INFO', [{battle_limit, 0}]}),
				Now = util:unixtime(),
                lib_player:refresh_player_buff(Player#player.other#player_other.pid_send, Buff, Now),
				save_online_info_fields(NewPlayer, [{battle_status, Buff}, {battle_limit, BattleLimit}]),
                NewPlayer;
            %% 减速
            2 ->
				[Buff, Mount, NewSpeed, Speed, Interval] = Data,
				%% 速度的重新计算方式改变
				%% mount ,speed 似乎已经没有作用
				case get(change_speed_timer) of
					[undefined, _, _] ->
						skip;
					[OldChangeSpeedTimer, _Sp, _Mnt] ->
						erlang:cancel_timer(OldChangeSpeedTimer)
				end,
                {ok, BinData} =  pt_20:write(20009, [Player#player.id, NewSpeed]),
				mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, BinData),
                NewPlayer = Player#player{speed = NewSpeed},	
                ChangeSpeedTimer = erlang:send_after(Interval, self(), {'CHANGE_SPEED', Speed, Mount}),
				put(change_speed_timer, [ChangeSpeedTimer, Speed, Mount]),
				Now = util:unixtime(),
                lib_player:refresh_player_buff(Player#player.other#player_other.pid_send, Buff, Now),
				save_online_info_fields(NewPlayer, [{speed, NewSpeed}]),
                NewPlayer;
			%% 更新朱雀盾BUFF
			3 ->
				[Buff] = Data,
				NewPlayer = Player#player{
             		other = Player#player.other#player_other{
             			battle_status = Buff,
						is_spring = 0								  
              		}						
               	},
				Now = util:unixtime(),
				{ok, BinData20105} = pt_20:write(20105, Player#player.id),
				mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, BinData20105),
                lib_player:refresh_player_buff(Player#player.other#player_other.pid_send, Buff, Now),
				save_online_info_fields(NewPlayer, [{battle_status, Buff}, {is_spring, 0}]),
                NewPlayer;
			%% 更新BUFF
            4 ->
                [Buff] = Data,
				NewPlayer = Player#player{
             		other = Player#player.other#player_other{
             			battle_status = Buff								  
              		}						
               	},
				Now = util:unixtime(),
                lib_player:refresh_player_buff(Player#player.other#player_other.pid_send, Buff, Now),
				save_online_info_fields(NewPlayer, [{battle_status, Buff}]),
                NewPlayer;
			
			%% 物品技能BUFF
			5 ->
				[SkillKey, SkillVal, SkillTime, SkillId, SkillLv, CD, Now] = Data,
				GoodsBuffCd = Player#player.other#player_other.goods_buf_cd,
				case lists:keyfind(SkillId, 1, GoodsBuffCd) of
                    false ->
						lib_player:refresh_player_goods_buff(Player, SkillKey, SkillVal, SkillTime, SkillId, SkillLv, Now);
                    {_SkillId, LastUseTime} ->
                        if
                            Now > LastUseTime + CD ->
								lib_player:refresh_player_goods_buff(Player, SkillKey, SkillVal, SkillTime, SkillId, SkillLv, Now);
                            true ->
								Player
                        end
                end;
			
			%% 物品技能BUFF
			6 ->
				[SkillKey, SkillVal, SkillTime, SkillId, SkillLv, CD, Now, Kind, Val, Time, Interval] = Data,
				GoodsBuffCd = Player#player.other#player_other.goods_buf_cd,
				case lists:keyfind(SkillId, 1, GoodsBuffCd) of
                    false ->
						BleedTimer = erlang:send_after(Interval, self(), {'ADD_PLAYER_HP_MP', Kind, Val, Time, Interval}),
						put(bleed_timer, BleedTimer),
						lib_player:refresh_player_goods_buff(Player, SkillKey, SkillVal, SkillTime, SkillId, SkillLv, Now);
                    {_SkillId, LastUseTime} ->
                        if
                            Now > LastUseTime + CD ->
								BleedTimer = erlang:send_after(Interval, self(), {'ADD_PLAYER_HP_MP', Kind, Val, Time, Interval}),
								put(bleed_timer, BleedTimer),
								lib_player:refresh_player_goods_buff(Player, SkillKey, SkillVal, SkillTime, SkillId, SkillLv, Now);
                            true ->
								Player
                        end
                end;
			%% 额外增加BUFF
			7 ->
				CheckBuff = fun({K, V, T, S, L},CurBuff) ->
									case lists:keyfind(K, 1, CurBuff) of
										{_K, _V, _T, _S, _L} ->
											lists:keyreplace(K, 1, CurBuff, {K, V, T, S, L});
										false ->
											[{K, V, T, S, L}|CurBuff]
									end
							end,
				Buff = lists:foldl(CheckBuff, Player#player.other#player_other.battle_status, Data),
				NewPlayer = Player#player{
             		other = Player#player.other#player_other{
             			battle_status = Buff								  
              		}						
               	},
				Now = util:unixtime(),
                lib_player:refresh_player_buff(Player#player.other#player_other.pid_send, Buff, Now),
				save_online_info_fields(NewPlayer, [{battle_status, Buff}]),
                NewPlayer;
			%% 不用更新前端的BUFF
			8 ->
				[Buff] = Data,
				NewPlayer = Player#player{
             		other = Player#player.other#player_other{
             			battle_status = Buff								  
              		}						
               	},
				save_online_info_fields(NewPlayer, [{battle_status, Buff}]),
                NewPlayer;
            _ -> 
           		Player
        end,
	NewPlayerState = PlayerState#player_state{
		player = RetPlayer			   
	},
	{noreply, NewPlayerState};

%% 发送消息到场景改变风向
handle_info({'CHANGE_SCENE_WIND'},PlayerState) ->
	SceneId = PlayerState#player_state.player#player.scene,
	mod_scene:get_scene_pid(SceneId, undefined, undefined) ! {'CHANGE_SCENE_WIND'} ,
	{noreply, PlayerState};

%%领取斗兽竞技奖励
handle_info({'MOUNT_GET_AWARD',Data,Mid,NewM}, PlayerState) ->
	[Cash,Coin,{Gid,Num}] = Data,
	Player = PlayerState#player_state.player,
	case lib_daily_award:check_bag_enough(Player) of
		false ->
			NewPlayer2 = Player,
			{ok,Bin} = pt_16:write(16048,3);
		true ->
			NewPlayer = lib_goods:add_money(Player,Cash,cash,1648),
			NewPlayer2 = lib_goods:add_money(NewPlayer,Coin,bcoin,1648),
			case catch(gen_server:call(Player#player.other#player_other.pid_goods,
								{'give_goods',Player,Gid,Num,2})) of
				ok-> ok;
				_Other->
					error
			end,
			Now = util:unixtime(),
			lib_mount_arena:after_get_award(NewM),
			spawn(fun()-> db_agent:log_mount_award([Player#player.id,Mid,Cash,Coin,Gid,Num,Now])end),
			{ok,Bin} = pt_16:write(16048,1)
	end,
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, Bin),
	spawn(fun()->lib_player:send_player_attribute2(NewPlayer2,3)end),
	NewPlayerState = PlayerState#player_state{
											  player = NewPlayer2
											 },
	{noreply, NewPlayerState};

%%奖励斗兽挑战者
handle_info({'MOUNT_CGE_AWARD',Cge_award,_Rounds}, PlayerState) ->
	NewPlayer = lib_mount_arena:cge_award(PlayerState#player_state.player,Cge_award),
	spawn(fun()->lib_player:send_player_attribute2(NewPlayer,3)end),
	NewPlayerState = PlayerState#player_state{
											  player = NewPlayer
											 },
	{noreply, NewPlayerState};

%% handle_info({'GET_MOUNT_CGE_AWARD',Cge_award}, PlayerState) ->
%% 	NewPlayer = lib_mount_arena:cge_award(PlayerState#player_state.player,Cge_award),
%% 	spawn(fun()->lib_player:send_player_attribute2(NewPlayer,3)end),
%% 	NewPlayerState = PlayerState#player_state{
%% 											  player = NewPlayer
%% 											 },
%% 	{noreply, NewPlayerState};

%%增加斗兽竞技次数，扣除YB
handle_info({'ADD_MOUNT_ARENA_TIMES',Gold},PlayerState) ->
	Player = PlayerState#player_state.player,
%% 	?DEBUG("IN add_cge_times , BEFORE SEND..........~n",[]),
	case goods_util:is_enough_money(Player, Gold, gold) of
		false ->
			{ok,Bin} = pt_16:write(16046,2),
			Player2 = Player;
		true ->
			Player2 = lib_goods:cost_money(Player, Gold, gold, 1646),
			lib_player:send_player_attribute(Player2, 2),
			{ok,Bin} = pt_16:write(16046,1)
	end,
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, Bin),
	NewPlayerState = PlayerState#player_state{
											  player = Player2
											 },
	{noreply, NewPlayerState};

%%用于GM命令！！
handle_info({'gm_del_marry',Id},PlayerState) ->  
	Player = PlayerState#player_state.player,
	catch ets:delete(?ETS_MARRY, {Id,Player#player.id}),
	Player1 = Player#player{couple_name = ""},
	save_online_diff(Player,Player1),
	lib_player:send_player_attribute(Player1,2),
	{noreply, PlayerState#player_state{player = Player1}};

%%用于GM命令！！
handle_info({'gm_marry_3_days',NewTime,DbId},PlayerState) ->  
	Player = PlayerState#player_state.player,
	case ets:lookup(?ETS_MARRY, {DbId,Player#player.id}) of
		[]->
			skip;
		[M|_Rets] ->
			ets:insert(?ETS_MARRY, M#ets_marry{marry_time = NewTime})
	end,
	{noreply, PlayerState};

%%用于GM命令！！
handle_info({'gm_unmarry_7_days',NewTime,DbId},PlayerState) ->  
	Player = PlayerState#player_state.player,
	case ets:lookup(?ETS_MARRY, {DbId,Player#player.id}) of
		[]->
			skip;
		[M|_Rets] ->
			ets:insert(?ETS_MARRY, M#ets_marry{div_time = NewTime})
	end,
	{noreply, PlayerState};

%%斗兽任务
handle_info({'MOUNT_PK'},PlayerState)->
	lib_task:event(mount_pk, null, PlayerState#player_state.player),
	{noreply,PlayerState};

handle_info(_Info, PlayerState) ->
	%%put(last_msg, [_Info]),%%监控记录接收到的最后的消息
	%%?WARNING_MSG("Mod_player_info: /~p/~n",[[Info, 0]]),
    {noreply, PlayerState}.

%% --------------------------------------------------------------------
%% Function: terminate/2
%% Description: Shutdown the server
%% Returns: any (ignored by gen_server)
%% --------------------------------------------------------------------
terminate(_Reason, PlayerState) ->
	%% 卸载角色数据
    unload_player_info(PlayerState),	
	misc:delete_monitor_pid(self()),
    ok.

%% --------------------------------------------------------------------
%% Func: code_change/3
%% Purpose: Convert process state when code is changed
%% Returns: {ok, NewState}
%% --------------------------------------------------------------------
code_change(_oldvsn, PlayerState, _extra) ->
    {ok, PlayerState}.

%%
%% ------------------------私有函数------------------------
%%
%% 加载角色数据
load_player_info(PlayerState, PlayerId, Socket) ->
	Nowtime = util:unixtime(),
	LastLoginTime = Nowtime + 5,
	PlayerInfo = lib_account:get_info_by_id(PlayerId),	
	PlayerData = list_to_tuple([player | PlayerInfo]),
	%% 处理注册初始化 and 更新最近登录时间
	LastLoginIP = misc:get_ip(Socket),
	Player = lib_player:update_last_login(PlayerData, LastLoginTime, LastLoginIP),
	%%加载结婚信息，并获取配偶名
	CoupleName = lib_marry:get_couple_name(Player#player.sex,Player#player.id),
	Pid = self(),

	%% 开启socket管理进程
	Socket_gn = mod_socket:get_socket_group_name(Player#player.sn, Player#player.accid),
	mod_socket:stop(Socket_gn),
	Pid_socket = mod_socket:start([Socket_gn, Socket, Player#player.id, Pid]),
    %% 打开广播信息进程
	Pid_send = lists:map(fun(_N)-> 
							{ok, _Pid_send} = mod_pid_send:start(Socket, _N),
							lib_send:init_send_info(PlayerId, _Pid_send, _N),
							_Pid_send
						end, lists:seq(1, ?SEND_MSG)),

	%%打开任务进程
	{ok, Pid_task} = mod_task:start_link([PlayerId]),
	%%打开经脉进程
	{ok,Pid_Meridian} = mod_meridian:start_link(PlayerId),	
	%%打开情缘进程
	{ok,Pid_Love} = mod_love:start_link(PlayerId,Pid_send,Pid,Player#player.sex),
	%% 获取诛仙台荣誉
	{LTime, NPTitle, ZxtHonor, NewPlayerState} = lib_player:get_other_player_data(PlayerState, Player, LastLoginTime),%%获取最近的记录玩家在线的时间和玩家成就称号列表
	%%玩家登陆首先把当前节点的有可能残留的活跃度数据清除
	lib_activity:player_logout(PlayerId),
	
	%% 创建物品模块PID
	{ok, Pid_goods} = mod_goods:start(PlayerId, Player#player.cell_num, Pid_send),
	%% 初始化在线玩家物品buff表   ----由物品模块转移到此
	{_TurnedValue,GoodsBuffs} = goods_util:init_goods_buff(Player, Player#player.last_login_time, LastLoginTime, LTime),
	put(goods_buffs, GoodsBuffs),%%把buff塞到进程里
    GoodsStatus = gen_server:call(Pid_goods, {'STATUS'}),
    %% 灵兽初始化
    lib_pet:role_login(Player,Pid_send,Pid_goods),
	mod_mount:role_login(PlayerId),
    %% 氏族初始化 
    mod_guild:role_login(Player#player.id, Player#player.guild_id, LastLoginTime),
	%% 封神纪元初始化
	lib_era:init_player_era_info(Player#player.id),
	%%初始化角色属性%%
	%% 1 角色一级属性 (在player中skip)
	%% 2 装备加成的一级属性
	[E_forza,E_physique,E_wit,E_agile,E_speed] = 
		goods_util:get_equip_player_attribute(Player#player.id,GoodsStatus#goods_status.equip_suit),
	
	%% 3  灵兽加成的一级属性
	[Pet_forza, Pet_agile, Pet_wit, Pet_physique] = lib_pet:get_out_pet_attribute(Player),
	
	%% 4 灵兽技能二级属性系数加成
	[PetMult_hp,PetMult_mp,PetMult_def,PetMult_att,PetMult_anti,PetMult_hit,PetMult_dodge,PetMult_r_hp,PetMult_r_mp] =
		lib_pet:get_out_pet_skill_effect(Player),
	
	%% 5 技能BUFF加成(包括一级属性/二级属性)
	SkillBuff = lib_player:get_skill_buff_effect(PlayerId, Pid, Nowtime),
	%%[SkillBuffHpLim, SkillBuffAgile, SkillBuffPhysique, SkillBuffDef, _SkillBuffAnti] = lib_player:get_skill_buff_attr(SkillBuff),
	
	%% 6 装备二级属性的系数加成
	[Mult_hp,Mult_crit,Max_attack] = 
		goods_util:get_equip_mult_attribute(Player#player.id,GoodsStatus#goods_status.equip_suit),
	
	%% 7 经脉二级属性加成
	[MeridianInfo]= case lib_meridian:get_player_meridian_info(PlayerId) of
						[]->[[]];
						Meridian->Meridian
					end,
	{ok,[MerHp,MerDef,MerMp,MerHit,MerCrit,MerShun,MerAtt,MerTen,LgHp,LgMp,LgAtt]} = lib_meridian:get_meridian_att_current(PlayerId,MeridianInfo),
	
	%% 8 原始 二级属性 (在player中skip)
	
	%% 9 装备二级属性加成
    [FullStren,[Hp2, Mp2, MaxAtt2, MinAtt2, Def2, Hit2, Dodge2, Crit2, Anti_wind2,Anti_fire2,Anti_water2,Anti_thunder2,Anti_soil2,Anti_rift2]] = 
			goods_util:get_equip_attribute(
					Player#player.id, 
					Player#player.equip, 
					GoodsStatus#goods_status.equip_suit),
	%% 10 当前装备
	[WQ,YF,_Fbyf, _Spyf,_MountTypeId] = GoodsStatus#goods_status.equip_current,

	%% 11 坐骑信息
	[_MountType,_MountSpeed,MountStren] = goods_util:get_mount_info(Player),
	%% 12氏族高级技能加成[13氏族攻击，14氏族防御，15氏族气血，16氏族法力，17氏族命中，18氏族闪躲，19氏族暴击] 
		case Player#player.guild_id of 
			0 ->
				GAlliance = [],
				GFeats = 0,
				GuildSkills = #guild_h_skill{g_att = 0, 
											 g_def = 0,
											 g_hp = 0, 
											 g_mp = 0, 
											 g_hit = 0, 
											 g_dodge = 0, 
											 g_crit = 0};
			GuildId ->
				%%获取角色氏族功勋
				{GAlliance, GFeats, GuildSkills} = lib_guild_weal:get_guild_h_skills_info(GuildId, PlayerId)
		end,
	AchPrearls = gen_server:call(Pid_goods, {'GET_ACH_PEARLS_INFO'}),
	%%初始化end
	%%%%%%%%%%%
    %% 获取普通技能
    Skill = lib_skill:get_all_skill(PlayerId),
	%% 获取轻功技能
    Light_Skill = lib_skill:get_light_skill(PlayerId),
	%% 获取被动技能
	Passive_Skill = lib_skill:get_passive_skill(PlayerId),
	%% 获取神器技能
	[Deputy_prof_lv,Deputy_Skill]= lib_deputy:get_deputy_add_skills(PlayerId),
	%%灵兽战斗技能
	Pet_batt_skill = lib_pet:get_out_pet_batt_skill(PlayerId),
	%%坐骑属性加成
	Mount = lib_mount:get_out_mount(PlayerId),
	MountMultAttributeList = data_mount:get_prop_mount(Mount), 
	%% 获取禁言信息
	[Stop_begin_time, Stop_chat_minutes] = lib_player:get_donttalk_status(PlayerId),
	put(donttalk, [Stop_begin_time, Stop_chat_minutes]), 
	
	%% 挂机设置信息
	HookConfig = lib_hook:init_hook_config(PlayerId, Player#player.scene),
	%% 装备强化信息和套装信息
	SuitID = goods_util:is_full_suit(GoodsStatus#goods_status.equip_suit),
	StrenEff = lib_goods:get_player_stren_eff(PlayerId),
	FbyfStren = lib_goods:get_player_fbyf_stren(PlayerId),
	SpyfStren = lib_goods:get_player_spyf_stren(PlayerId),
	
	Goods_ring4 = goods_util:get_ring_color4(PlayerId),
	%% 获取角色祝福信息
	[BlessTimes, B_exp, B_spr, LastBlessTime] = lib_relationship:get_bless_info(PlayerId),
	%%计算商城积分
	ShopScore = lib_player:get_player_pay_gold(Player#player.id),
	%% 设置角色的相关信息
    Other = #player_other {
		shop_score = ShopScore,
		base_player_attribute = [
			Player#player.forza,
			Player#player.physique,
			Player#player.wit,
			Player#player.agile,
			Player#player.speed
		],
    	base_attribute = [
            Player#player.hp_lim, 
            Player#player.mp_lim, 
            Player#player.max_attack,
            Player#player.min_attack,
            Player#player.def, 
            Player#player.hit, 
            Player#player.dodge, 
            Player#player.crit, 
            Player#player.anti_wind,
            Player#player.anti_fire,
            Player#player.anti_water,
            Player#player.anti_thunder,
            Player#player.anti_soil
        ],	

		%%two_attribute = [Hp1, Mp1, MaxAtt1, MinAtt1, Def1, Hit1, Dodge1, Crit1, Anti_wind1,Anti_fire1,Anti_water1,Anti_thunder1,Anti_soil1],
		%% 3 灵兽加成的一级属性			   
        pet_attribute = [Pet_forza,Pet_agile,Pet_wit,Pet_physique],
		%% 4 灵兽技能二级属性系数加成
		pet_skill_mult_attribute = [PetMult_hp,PetMult_mp,PetMult_def,PetMult_att,PetMult_anti,PetMult_hit,PetMult_dodge,PetMult_r_hp,PetMult_r_mp],
		%% 当前出战灵兽
		out_pet = lib_pet:get_out_pet(PlayerId),
		%% 装备二级属性的系数加成
		equip_mult_attribute = [Mult_hp,Mult_crit,Max_attack],
		%% 10 当前装备
        equip_current = [WQ,YF,_Fbyf, _Spyf,_MountTypeId],
		%% 9  装备二级属性加成
        equip_attribute = [Hp2, Mp2, MaxAtt2, MinAtt2, Def2, Hit2, Dodge2, Crit2, Anti_wind2,Anti_fire2,Anti_water2,Anti_thunder2,Anti_soil2,Anti_rift2],
		%% 2 装备加成一级属性
		equip_player_attribute = [E_forza,E_physique,E_wit,E_agile,E_speed],
		%% 7 经脉二级属性加成
		meridian_attribute = [MerHp,MerDef,MerMp,MerHit,MerCrit,MerShun,MerAtt,MerTen,LgHp,LgMp,LgAtt],
		%%坐骑属性加成
		mount_mult_attribute = MountMultAttributeList,
        skill = Skill,
		light_skill = Light_Skill,
		passive_skill = Passive_Skill,
		deputy_skill = Deputy_Skill,
		deputy_prof_lv = Deputy_prof_lv,
		stren = StrenEff,
		fbyfstren = FbyfStren,
		spyfstren = SpyfStren,
		fullstren = FullStren,
		suitid = SuitID,
        socket = Socket,
        pid = Pid,
		pid_socket = Pid_socket,
        pid_goods = Pid_goods,
        pid_send = Pid_send,
		pid_task = Pid_task,
		pid_meridian = Pid_Meridian,
		pid_love = Pid_Love,
        battle_status = SkillBuff,
		node = node(),
		mount_stren = MountStren,
		guild_h_skills = GuildSkills,
		guild_feats = GFeats,
%% 		charm_title = NPTitle,%%称号
%% 		charm_title_time = Expi,%%称号过期时间
		ach_pearl = AchPrearls,
		goods_ring4 = Goods_ring4,
		zxt_honor=ZxtHonor,
		titles = NPTitle, %%称号
		g_alliance = GAlliance,	%%联盟中的氏族Id
		pet_batt_skill = Pet_batt_skill	% 灵兽战斗功技能
	},
	
	Llast_login_time = Player#player.last_login_time,
	
	DelayerPlayer = Player#player{
		nickname = binary_to_list(Player#player.nickname), 
		other = Other
	},
	[[Scene0, X0, Y0], TeamPid, [PidDungeon, PidFst]] = lib_delayer:delayer_login(DelayerPlayer, Pid),
	%%处理场景为0情况，默认送到九霄
	if
		Scene0 == 0 ->
			Scene = 300,
			X = 52,
			Y = 162;
		true ->
			Scene = Scene0,
			X = X0,
			Y = Y0
	end,
	
	if
		Scene =/= Player#player.scene andalso Player#player.scene rem 10000 >= 998 ->
			%% 检查是否有未发送的封神台塔防通知
			spawn(fun()-> lib_player:check_fst_td_log(Player#player.id, Player#player.scene, Pid) end);
		true ->
			ok
	end,
	
	%%修改玩家的旗或者魔核数据-----复用了玩家运镖状态标志, 8-15为旗或者魔核的状态标志
	CarryMark = 
		case Player#player.carry_mark >= 8 andalso Player#player.carry_mark < 20 of
			true ->
				0;
			false ->
				Player#player.carry_mark
		end,
	
	%%战斗力值
	Batt_value = lib_player:count_player_batt_value(Player),
	
    %% 设置 mod_player state
	%% 初始化部分角色属性
    Player2 = Player#player { 
		scene = Scene,
		x = X,
		y = Y,
        accname = binary_to_list(Player#player.accname),
        nickname = binary_to_list(Player#player.nickname),
        guild_name = binary_to_list(Player#player.guild_name),
        quit_guild_time = Player#player.quit_guild_time,
        guild_title = Player#player.guild_title,
        guild_depart_name = Player#player.guild_depart_name,
        guild_depart_id = Player#player.guild_depart_id,
        mount = Player#player.mount,
		last_login_time = LastLoginTime,
		last_login_ip = LastLoginIP ,
		online_flag = 1,
		carry_mark = CarryMark,
		couple_name = CoupleName,
        other = Other#player_other{
			pid_team = TeamPid, 
			pid_dungeon = PidDungeon, 
			pid_fst = PidFst,
			heartbeat = LastLoginTime,
			batt_value = Batt_value,
			hook_pick = HookConfig#hook_config.pick,
			hook_equip_list = HookConfig#hook_config.equip_list,
			hook_quality_list = HookConfig#hook_config.quality_list
		}
    },
	%%加载玩家封神争霸功勋(可给玩家增加属性，要在计算属性之前加载)
	Player3 = lib_war2:init_war_honor(Player2),
	%% 初始化角色装备数值 统一接口，数据要一致
	AttributePlayer = lib_player:count_player_attribute(Player3),
	%%加载夫妻传送技能信息
	NewPlayer1 = lib_skill:init_couple_skill(AttributePlayer),
	%% 竞技场状态判断
	NewPlayer = lib_arena:player_login_check(NewPlayer1),
    %%更新ETS_ONLINE在线表
	ets:insert(?ETS_ONLINE, NewPlayer),
	
	%%计算开封印数据更新
	%%更新开紫装的数据和时间
	lib_box:init_box_goods_player_info(PlayerId, LastLoginTime, Llast_login_time),
	
	%%斗兽按登陆顺序排名(出战坐骑)
	spawn(fun() ->
		lib_mount_arena:rank_by_login(Mount,NewPlayer)
	end),
	
	%%
	%% 以下数据使用spawn_link 初始化的，必须不存在数据初始化顺序依赖，不写玩家进程字典。 
	%%
	%%运镖初始化
	spawn_link(fun()->
		lib_carry:init_carry(PlayerId)
	end),
	%%跑商初始化
	spawn_link(fun()->
		lib_business:online(NewPlayer)
	end),
	%% 玩家初始化时，初始化游戏系统配置
	lib_syssetting:init_player_sys_setting_info(PlayerId),
    %% 初始化任务
	gen_server:cast(Pid_task,{'init_task',NewPlayer}),
	%%在线奖励初始化
	spawn_link(fun()->
		lib_online_gift:online(NewPlayer)
	end),
	%%目标奖励初始化
	spawn_link(fun()->
		lib_target:init_target(NewPlayer)
	end),
	%%离线奖励累积
	spawn_link(fun()->
		lib_offline_award:init_offline_award(PlayerId,NewPlayer#player.lv)
	end),
	%%在线奖励累积
	spawn_link(fun()->
		lib_online_award:init_online_award(NewPlayer)
	end),
	spawn_link(fun()->
		lib_lucky_draw:init_lucky_draw(PlayerId)
	end),
	spawn_link(fun()->lib_master_apprentice:update_master_charts_online(PlayerId,1)end),
	%%假日登陆奖励
%% 	lib_online_award:init_online_award_holiday(NewPlayer),
	%% 加载关系信息
	spawn_link(fun()->
		lib_relationship:set_ets_rela_record(PlayerId),
		%% 上线通知好友
		lib_relationship:notice_friend_online(PlayerId, 1, NewPlayer#player.nickname),
		%% 上线通知仇人
		lib_relationship:notice_enemy_online(PlayerId, 1, NewPlayer#player.nickname)
	end),
	%%上线通知氏族群聊面板
	if NewPlayer#player.guild_id > 0 ->
		   gen_server:cast(mod_guild:get_mod_guild_pid(),{'MEMBER_ONLINE_FLAG',1,NewPlayer#player.guild_id,NewPlayer#player.id});
	   true ->
		   skiP
	end,
	
	%%加载委托数据
	spawn_link(fun()->
		lib_consign:init_consign_player_info(PlayerId)
	end),
	%%加载循环任务奖励倍数
	spawn_link(fun()->
					   lib_cycle_flush:init_cycle_flush(PlayerId)
			   end),
	%%加载经验找回信息
	spawn_link(fun()->
					   lib_find_exp:init_find_exp(PlayerId,NewPlayer#player.lv,NewPlayer#player.guild_id,NewPlayer#player.reg_time)
			   end),
	
	%%凝神修炼预加载
	Status2 = lib_exc:exc_login(NewPlayer, Nowtime),
	%%登录奖励
	Status3 = lib_login_prize:do_login_prize(Status2,Llast_login_time),
	%%登陆查询委托奖励
	Status4 = lib_task:get_consign_award(Status3),
%% 	%%加载魅力头衔相关信息
	Status5 = lib_love:load_title(Status4),
	%%玩家跑商，运镖标记检查
	Status6 = lib_task:check_carry_mark(Status5),
	%% 加载或进入场景
	MyStatus = lib_scene:init_player_scene(Status6),

	%%初始化封神贴数据
	spawn_link(fun()->
		lib_hero_card:init_hero_card(PlayerId)
	end),
	%%初始化目标引导
	spawn_link(fun()->
		lib_target_lead:init_target_lead(PlayerId)
	end),
					   
	%%初始化登陆奖励（新）
	spawn_link(fun() ->
					  lib_login_award:init_login_award(PlayerId)
			   end),
	
	erlang:send_after(7000, self(), {'UPDATE_PLAYER_ACHIEVE'}),%%7秒之后开始倒计时玩家称号

	if 
		MyStatus#player.lv >= 30 ->
			%% 1秒之后开始检查玩家的轻功技能
			erlang:send_after(1000*1, self(), {'UPDATE_LIGHT_SKILL'}),
			%% 初始战场信息
			spawn(fun()-> lib_coliseum:init_coliseum_data(MyStatus) end),
			%%三月活动
			%% 活动七：飞跃竞技场	
			lib_act_interf:check_player_arena_ranking(MyStatus),
			SameDay = util:is_same_date(Llast_login_time, Nowtime),
			if
				SameDay == false ->
					%% 第一次登陆处理
					%% 物品快照 
					if MyStatus#player.lv >= 35 ->
							erlang:send_after(1000 * 10, Pid_goods, 'snapshot');
					   true ->
						   skip
					end;
				true ->
					skip
			end;
		true ->
			skip
	end,
	
	spawn_link(fun()->
		lib_vip:init_vip_info(PlayerId,MyStatus#player.vip)
	end),
	
	put(update_exp_timestamp,[Nowtime]),
	
	%% 初始玩家功能参与数据
	spawn_link(fun()->
		lib_player:init_join_data(PlayerId, Nowtime)
	end),
	
	%%初始化新手礼包
	spawn_link(fun()->
		lib_novice_gift:init_novice_gift(PlayerId, MyStatus#player.lv)
			   end),
	%%初始化跨服历史记录
	spawn_link(fun()->
					   lib_war2:init_war2_history(PlayerId,PlayerData#player.nickname)
			   end),
	OnlinePlayerState = lib_player:update_online_time(NewPlayerState, PlayerId, Nowtime, PlayerData#player.last_login_time),
	RetPlayerState = OnlinePlayerState#player_state{
		player = MyStatus,
		bless_times = BlessTimes,
		last_bless_time = LastBlessTime,
		bottle_exp = B_exp, 
		bottle_spr = B_spr
	}, 
	[RetPlayerState, MyStatus].

load_player_info_war_server(PlayerState, PlayerId, Socket) ->
	Nowtime = util:unixtime(),
	LastLoginTime = Nowtime + 5,
	PlayerInfo = lib_account:get_info_by_id(PlayerId),
	%%
	PlayerData = list_to_tuple([player | PlayerInfo]),
	%% 处理注册初始化 and 更新最近登录时间
	LastLoginIP = misc:get_ip(Socket),
	Player = lib_player:update_last_login(PlayerData, LastLoginTime, LastLoginIP),
	Pid = self(),

	%% 开启socket管理进程
	Socket_gn = mod_socket:get_socket_group_name(Player#player.sn, Player#player.accid),
	mod_socket:stop(Socket_gn),
	Pid_socket = mod_socket:start([Socket_gn, Socket, Player#player.id, Pid]),
	%% 打开广播信息进程
	Pid_send = lists:map(fun(_N)-> 
							{ok, _Pid_send} = mod_pid_send:start(Socket, _N),
							lib_send:init_send_info(PlayerId, _Pid_send, _N),
							_Pid_send
						 end, lists:seq(1, ?SEND_MSG)),

	%%打开任务进程
%% 	{ok, Pid_task} = mod_task:start_link([PlayerId]),
	%%打开经脉进程
	{ok,Pid_Meridian} = mod_meridian:start_link(PlayerId),	
	%%打开情缘进程
%% 	{ok,Pid_Love} = mod_love:start_link(PlayerId,Pid_send,Pid),
	%% 获取诛仙台荣誉
	{LTime, NPTitle, ZxtHonor, NewPlayerState} = lib_player:get_other_player_data(PlayerState, Player, LastLoginTime),%%获取最近的记录玩家在线的时间和玩家成就称号列表
	
	%%玩家登陆首先把当前节点的有可能残留的活跃度数据清除
	lib_activity:player_logout(PlayerId),
	
	%% 创建物品模块PID
	{ok, Pid_goods} = mod_goods:start(PlayerId, Player#player.cell_num, Pid_send),
	
	%% 初始化在线玩家物品buff表   ----由物品模块转移到此
	{_TurnedValue,GoodsBuffs} = goods_util:init_goods_buff(Player, Player#player.last_login_time, LastLoginTime, LTime),
	put(goods_buffs, GoodsBuffs),%%把buff塞到进程里
    GoodsStatus = gen_server:call(Pid_goods, {'STATUS'}),
    %% 灵兽初始化
    lib_pet:role_login(Player,Pid_send,Pid_goods),	
	mod_mount:role_login(PlayerId),
    %% 氏族初始化 c
%%     mod_guild:role_login(Player#player.id, Player#player.guild_id, LastLoginTime), 	
	%% 封神纪元初始化
	lib_era:init_player_era_info(Player#player.id),
	%%初始化角色属性%%
	%% 1 角色一级属性 (在player中skip)
	%% 2 装备加成的一级属性
	[E_forza,E_physique,E_wit,E_agile,E_speed] = 
		goods_util:get_equip_player_attribute(Player#player.id,GoodsStatus#goods_status.equip_suit),
	
	%% 3  灵兽加成的一级属性
	[Pet_forza,Pet_agile,Pet_wit,Pet_physique] = 
		lib_pet:get_out_pet_attribute(Player), 
	
	%% 4 灵兽技能二级属性系数加成
	[PetMult_hp,PetMult_mp,PetMult_def,PetMult_att,PetMult_anti,PetMult_hit,PetMult_dodge,PetMult_r_hp,PetMult_r_mp] =
		lib_pet:get_out_pet_skill_effect(Player),
	
	%% 5 技能BUFF加成(包括一级属性/二级属性)
	SkillBuff = lib_player:get_skill_buff_effect(PlayerId, Pid, Nowtime),
	%%[SkillBuffHpLim, SkillBuffAgile, SkillBuffPhysique, SkillBuffDef, _SkillBuffAnti] = lib_player:get_skill_buff_attr(SkillBuff),
	
	%% 6 装备二级属性的系数加成
	[Mult_hp,Mult_crit,Max_attack] = 
		goods_util:get_equip_mult_attribute(Player#player.id,GoodsStatus#goods_status.equip_suit),
	
	%% 7 经脉二级属性加成
	[MeridianInfo]= case lib_meridian:get_player_meridian_info(PlayerId) of
						[]->[[]];
						Meridian->Meridian
					end,
	{ok,[MerHp,MerDef,MerMp,MerHit,MerCrit,MerShun,MerAtt,MerTen,LgHp,LgMp,LgAtt]} = lib_meridian:get_meridian_att_current(PlayerId,MeridianInfo),
	
	%% 8 原始 二级属性 (在player中skip)
	
	%% 9 装备二级属性加成
    [FullStren,[Hp2, Mp2, MaxAtt2, MinAtt2, Def2, Hit2, Dodge2, Crit2, Anti_wind2,Anti_fire2,Anti_water2,Anti_thunder2,Anti_soil2,Anti_rift2]] = 
			goods_util:get_equip_attribute(Player#player.id, Player#player.equip, GoodsStatus#goods_status.equip_suit),
	%% 10 当前装备
	[WQ,YF, _Fbyf, _Spyf,_MountTypeId] = GoodsStatus#goods_status.equip_current,

	%% 11 坐骑信息
	[_MountType,_MountSpeed,MountStren] = goods_util:get_mount_info(Player),
	%% 12氏族高级技能加成[13氏族攻击，14氏族防御，15氏族气血，16氏族法力，17氏族命中，18氏族闪躲，19氏族暴击] 
		case Player#player.guild_id of
			0 ->
				GAlliance = [],
				GFeats = 0,
				GuildSkills = #guild_h_skill{g_att = 0, 
											 g_def = 0,
											 g_hp = 0, 
											 g_mp = 0, 
											 g_hit = 0, 
											 g_dodge = 0, 
											 g_crit = 0};
			GuildId ->
				%%获取角色氏族功勋
				{GAlliance, GFeats, GuildSkills} = lib_guild_weal:get_guild_h_skills_info(GuildId, PlayerId)
		end,
	AchPrearls = gen_server:call(Pid_goods, {'GET_ACH_PEARLS_INFO'}),
	%%初始化end
	%%%%%%%%%%%
    %% 获取普通技能
    Skill = lib_skill:get_all_skill(PlayerId),
	%% 获取轻功技能
    Light_Skill = lib_skill:get_light_skill(PlayerId),
	%%%% 获取被动技能
	Passive_Skill = lib_skill:get_passive_skill(PlayerId),
	%% 获取神器技能
	[Deputy_prof_lv,Deputy_Skill]= lib_deputy:get_deputy_add_skills(PlayerId),
	%%灵兽战斗技能
	Pet_batt_skill = lib_pet:get_out_pet_batt_skill(PlayerId),
	%%坐骑属性加成
	MountMultAttributeList = data_mount:get_prop_mount(lib_mount:get_out_mount(PlayerId)), 
	%% 获取禁言信息
	[Stop_begin_time, Stop_chat_minutes] =  lib_player:get_donttalk_status(PlayerId),
	put(donttalk, [Stop_begin_time, Stop_chat_minutes]), 
	
	%% 挂机设置信息
	lib_hook:init_hook_config(PlayerId,Player#player.scene),
	
	%% 装备强化信息和套装信息
	SuitID = goods_util:is_full_suit(GoodsStatus#goods_status.equip_suit),
	StrenEff = lib_goods:get_player_stren_eff(PlayerId),
	FbyfStren = lib_goods:get_player_fbyf_stren(PlayerId),
	SpyfStren = lib_goods:get_player_spyf_stren(PlayerId),

	Goods_ring4 = goods_util:get_ring_color4(PlayerId),
	%% 获取角色祝福信息
%% 	[BlessTimes, B_exp, B_spr, LastBlessTime] = lib_relationship:get_bless_info(PlayerId),
	%% 设置角色的相关信息
    Other = #player_other {
		base_player_attribute = [
				Player#player.forza,
				Player#player.physique,
				Player#player.wit,
				Player#player.agile,
				Player#player.speed
			],
    	base_attribute = [
            Player#player.hp_lim, 
            Player#player.mp_lim, 
            Player#player.max_attack,
            Player#player.min_attack,
            Player#player.def, 
            Player#player.hit, 
            Player#player.dodge, 
            Player#player.crit, 
            Player#player.anti_wind,
            Player#player.anti_fire,
            Player#player.anti_water,
            Player#player.anti_thunder,
            Player#player.anti_soil
        	],	

		%%two_attribute = [Hp1, Mp1, MaxAtt1, MinAtt1, Def1, Hit1, Dodge1, Crit1, Anti_wind1,Anti_fire1,Anti_water1,Anti_thunder1,Anti_soil1],
		%% 3 灵兽加成的一级属性			   
        pet_attribute = [Pet_forza,Pet_agile,Pet_wit,Pet_physique],
		%% 4 灵兽技能二级属性系数加成
		pet_skill_mult_attribute = [PetMult_hp,PetMult_mp,PetMult_def,PetMult_att,PetMult_anti,PetMult_hit,PetMult_dodge,PetMult_r_hp,PetMult_r_mp],
		%% 当前出战灵兽
		out_pet = lib_pet:get_out_pet(PlayerId),
		%% 装备二级属性的系数加成
		equip_mult_attribute = [Mult_hp,Mult_crit,Max_attack],
		%% 10 当前装备
        equip_current = [WQ,YF,_Fbyf, _Spyf,_MountTypeId],
		%% 9  装备二级属性加成
        equip_attribute = [Hp2, Mp2, MaxAtt2, MinAtt2, Def2, Hit2, Dodge2, Crit2, Anti_wind2,Anti_fire2,Anti_water2,Anti_thunder2,Anti_soil2,Anti_rift2],
		%% 2 装备加成一级属性
		equip_player_attribute = [E_forza,E_physique,E_wit,E_agile,E_speed],
		%% 7 经脉二级属性加成
		meridian_attribute = [MerHp,MerDef,MerMp,MerHit,MerCrit,MerShun,MerAtt,MerTen,LgHp,LgMp,LgAtt],
		%%坐骑属性加成
		mount_mult_attribute = MountMultAttributeList,
        skill = Skill,
		light_skill = Light_Skill,
		passive_skill = Passive_Skill,
		deputy_skill = Deputy_Skill,
		deputy_prof_lv = Deputy_prof_lv,
		stren = StrenEff,
		fbyfstren = FbyfStren,
		spyfstren = SpyfStren,
		fullstren = FullStren,
		suitid = SuitID,
        socket = Socket,
        pid = Pid,
		pid_socket = Pid_socket,
        pid_goods = Pid_goods,
        pid_send = Pid_send,
%% 		pid_task = Pid_task,
		pid_meridian = Pid_Meridian,
%% 		pid_love = Pid_Love,
        battle_status = SkillBuff,
		node = node(),
		mount_stren = MountStren,
		guild_h_skills = GuildSkills,
		guild_feats = GFeats,
%% 		charm_title = NPTitle,%%称号
%% 		charm_title_time = Expi,%%称号过期时间
		ach_pearl = AchPrearls,
		goods_ring4 = Goods_ring4,
		zxt_honor=ZxtHonor,
		titles = NPTitle, %%称号
		g_alliance = GAlliance,	%%联盟中的氏族Id
		pet_batt_skill = Pet_batt_skill
	},
	
	Llast_login_time = Player#player.last_login_time,
	%%处理场景为0情况，默认送到九霄
	if
		Player#player.scene == 0 ->
			Scene = 300,
			X = 52,
			Y = 162;
		true ->
			Scene = Player#player.scene,
			X = Player#player.x,
			Y = Player#player.y
	end,
	
	%%修改玩家的旗或者魔核数据-----复用了玩家运镖状态标志, 8-15为旗或者魔核的状态标志
	CarryMark = 
		case Player#player.carry_mark >= 8 andalso Player#player.carry_mark <20 of
			true ->
				0;
			false ->
				Player#player.carry_mark
		end,
	%%战斗力值
	Batt_value = lib_player:count_player_batt_value(Player),
    %% 设置 mod_player state
	%% 初始化部分角色属性
    Player2 = Player#player { 
		scene = Scene,
		x = X,
		y = Y,
        accname = binary_to_list(Player#player.accname),
        nickname = binary_to_list(Player#player.nickname),
        guild_name = binary_to_list(Player#player.guild_name),
        quit_guild_time = Player#player.quit_guild_time,
        guild_title = Player#player.guild_title,
        guild_depart_name = Player#player.guild_depart_name,
        guild_depart_id = Player#player.guild_depart_id,
        mount = Player#player.mount,
		last_login_time = LastLoginTime,
		last_login_ip = LastLoginIP ,
		online_flag = 1,
		carry_mark = CarryMark,
        other = Other#player_other{
			heartbeat = LastLoginTime,
			batt_value = Batt_value
		}
    },
	%%加载玩家封神争霸功勋
	Player3 = lib_war2:init_war_honor(Player2),
	%% 初始化角色装备数值 统一接口，数据要一致
	NewPlayer = lib_player:count_player_attribute(Player3),

	%%计算开封印数据更新
	%%更新开紫装的数据和时间
	lib_box:init_box_goods_player_info(PlayerId, LastLoginTime, Llast_login_time),
	%%
	%% 以下数据使用spawn_link 初始化的，必须不存在数据初始化顺序依赖，不写玩家进程字典。 
	%%
	
	%% 玩家初始化时，初始化游戏系统配置
	lib_syssetting:init_player_sys_setting_info(PlayerId),

	%% 加载或进入场景
	MyStatus =
%% lib_war2:enter_war2_scene(NewPlayer), 
		case util:get_date() of
			7->
				lib_war:enter_war_scene(NewPlayer,NewPlayer#player.scene);
			_->
				lib_war2:enter_war2_scene(NewPlayer)
		end,
	SameDay = util:is_same_date(Llast_login_time,Nowtime),
	erlang:send_after(7000, self(), {'UPDATE_PLAYER_ACHIEVE'}),%%7秒之后开始倒计时玩家称号
	if MyStatus#player.lv >= 30 ->
		    erlang:send_after(1000*1, self(), {'UPDATE_LIGHT_SKILL'});%%1秒之后开始检查玩家的轻功技能
		   true ->
			   skip
	end,
	put(update_exp_timestamp,[Nowtime]),
	if
		SameDay == false ->
			%%第一次登陆处理
			%%物品快照 
			if MyStatus#player.lv >=35 ->
					erlang:send_after(1000 * 10, Pid_goods, 'snapshot');
			   true ->
				   skip
			end;
		true ->
			skip
	end,
	OnlinePlayerState = lib_player:update_online_time(NewPlayerState, PlayerId, Nowtime, PlayerData#player.last_login_time),
	
	RetPlayerState = OnlinePlayerState#player_state{
		player = MyStatus
	}, 
	%%更新ETS_ONLINE在线表
	ets:insert(?ETS_ONLINE, MyStatus),
	%%跨服玩家数据，测试用
%% 	mod_war_supervisor:add_new_test(MyStatus),  
	[RetPlayerState, MyStatus].


%% 卸载角色数据
unload_player_info(PlayerState) ->
	Player = PlayerState#player_state.player,
	Now = util:unixtime(),
	
	TeamPidAlive = is_pid(Player#player.other#player_other.pid_team),
	%% 玩家下线，如有队伍，则通知队伍自己下线了
	case TeamPidAlive of
		true ->
			gen_server:cast(Player#player.other#player_other.pid_team, 
					{'MARK_LEAVES', Player#player.id, Player#player.nickname, 
					Player#player.career, Player#player.lv, Player#player.hp, Player#player.hp_lim, 
					Player#player.mp, Player#player.mp_lim, Player#player.sex, Player#player.scene});
		_ ->
			skip
	end,
	%%清除队伍招募信息
	gen_server:cast(mod_team_raise:get_mod_team_raise_pid(),{'del_member',[Player#player.id]}),
	NewPlayer =
        case lib_arena:is_arena_scene(Player#player.scene) of
            %% 战场
            true ->
                %% 战场玩家意外退出处理
                lib_arena:arena_terminate_quit(Player),
				[ArenaSceneId, ArenaX, ArenaY] = lib_arena:get_arena_position(Player#player.realm),
                ArenaPlayer = Player#player{
                    scene = ArenaSceneId,
                    x = ArenaX,
                    y = ArenaY,
                    hp = Player#player.hp_lim,
                    mp = Player#player.mp_lim			  
                },
				ArenaPid = lib_arena:get_arena_pid(Player),
				gen_server:cast(ArenaPid, 
				 		{apply_asyn_cast, lib_arena, leave_arena, [Player#player.id, Player#player.scene]}),
				ArenaPlayer;
			
            false ->
                %% 副本
                case lib_scene:is_dungeon_scene(Player#player.scene) of
                    true ->
                      	mod_dungeon:check_alive(Player#player.other#player_other.pid_dungeon, 1),
						mod_scene:leave_scene(Player#player.id, Player#player.scene, 
								  	Player#player.other#player_other.pid_scene, 
								  	Player#player.x, Player#player.y);
                    _ ->
						%% 幻魔穴
						case lib_cave:is_cave_scene(Player#player.scene) of
							true ->
								mod_cave:check_alive(Player#player.other#player_other.pid_dungeon, 1),
								mod_scene:leave_scene(Player#player.id, Player#player.scene, 
								  		Player#player.other#player_other.pid_scene, 
								  		Player#player.x, Player#player.y);
							false ->
                                %% 镇妖台
                                case lib_scene:is_td_scene(Player#player.scene) of
                                    true ->
                                        case is_pid(Player#player.other#player_other.pid_dungeon) of
                                            true ->
                                                gen_server:cast(Player#player.other#player_other.pid_dungeon, {'LEAVE_TD', Player#player.id, Now});
                                            false ->
                                                skip
                                        end;
                                    _ ->
                                        %% 帮派领地
                                        case lib_guild_manor:is_guild_manor_scene(Player#player.scene, Player#player.guild_id) of
                                            true ->
                                                case is_pid(Player#player.other#player_other.pid_scene) of
                                                    true ->
                                                        Player#player.other#player_other.pid_scene ! {logout, Player#player.id};
                                                    false ->
                                                        false
                                                end;
                                            false ->
                                                %% 温泉
                                                case lib_spring:is_spring_scene(Player#player.scene) of
                                                    true ->
                                                        gen_server:cast(Player#player.other#player_other.pid_scene, 
                                                                {'PALYER_LEAVE_SPRING', Player#player.id});
                                                    false ->
														case lib_marry:is_wedding_love_scene(Player#player.scene) of
															true ->
																gen_server:cast(mod_wedding:get_mod_wedding_pid(),{'PLAYER_LEAVE',Player#player.id});
															false ->
																%% 空岛
																case Player#player.scene =:= ?SKY_RUSH_SCENE_ID of
																	true ->
																		lib_skyrush:player_logout_sky(Player);
																	false ->
																		case lib_war:is_fight_scene(Player#player.scene) of
																			true->
																				gen_server:cast(Player#player.other#player_other.pid_dungeon,{'WAR_ENTER_LEAVE',Player#player.id,out,undefined,undefined,Player#player.other#player_other.leader,Player#player.carry_mark});
																			false->
																				case lib_war2:is_fight_scene(Player#player.scene) of
																					true->
																						if Player#player.carry_mark /=29->
																							   gen_server:cast(Player#player.other#player_other.pid_dungeon, {'WAR2_OFFLINE',[Player#player.id,Player#player.nickname]});
																						   true->skip
																						end;
																					false->
																						case Player#player.scene =:= ?WARFARE_SCENE_ID of%%神魔乱斗的场景出来的
																							true when Player#player.carry_mark =:= 27 ->%%头上有冥王之灵
																								case mod_warfare_mon:get_warfare_mon() of
																									{ok, Warfare} ->
																										gen_server:cast(Warfare, {'PLUTO_OWN_OFFLINE', Player#player.id});
																									_ ->
																										skip
																								end;
																							true ->%%直接就可以跑了
																								skip;
																							false ->
																								case lib_era:is_era_scene(Player#player.scene) of
																									true ->
																										gen_server:cast(Player#player.other#player_other.pid_dungeon, {'LEAVE_ERA', Player#player.id});
																									false ->
																										%% 是否在竞技场
																										case lib_coliseum:is_coliseum_scene(Player#player.scene) of
																											true ->
																												ColiseumScenePid = mod_scene:get_scene_real_pid(Player#player.scene),
																												gen_server:cast(ColiseumScenePid, {'COLISEUM_LEAVE', Player#player.id});
																											false ->
																												%% 如果在采矿点
																												lib_ore:do_logout(Player)
																										end
																								end
																						end
																				end
																		end
																end
														end
												end
										end
								end,
                                pp_scene:handle(12004, Player, 0)
						end
                end,
				case Player#player.arena > 0 andalso lib_arena:is_arena_time() of
					true ->
						%% 战场玩家意外退出处理
                		lib_arena:arena_terminate_quit(Player);
					false ->
						skip
				end,
				Player
        end,
	
	%% 更新在线时间
	spawn(fun()->
		OnlineTime = Now - NewPlayer#player.last_login_time + PlayerState#player_state.online_time,
		db_agent:update_player_online_time(NewPlayer#player.id, OnlineTime, PlayerState#player_state.online_time),
		%% 更新玩家登陆日志
		db_agent:upadte_login_user(NewPlayer#player.id, NewPlayer#player.last_login_time, Now)
	end),
	
	%% 更新player_other信息
	QuickBar = 
		case util:term_to_bitstring(PlayerState#player_state.quickbar) of 
			<<"undefined">> -> <<>>; 
			QB -> QB 
		end,
	PlayerOtherFieldList = [
		{quickbar, QuickBar},
		{coliseum_time, PlayerState#player_state.coliseum_time},
		{coliseum_cold_time, PlayerState#player_state.coliseum_cold_time},
		{coliseum_surplus_time, PlayerState#player_state.coliseum_surplus_time},
		{coliseum_extra_time, PlayerState#player_state.coliseum_extra_time},
		{is_avatar, PlayerState#player_state.is_avatar}
	],
	spawn(fun()-> db_agent:update_player_other(player_other, PlayerOtherFieldList, [{pid, Player#player.id}]) end),
	
	%% 檫黑板
	mod_delayer:delete_blackboard_info(NewPlayer#player.id),		
	
	spawn(fun()->
		%% 好友下线通知
		lib_relationship:notice_friend_online(NewPlayer#player.id, 0, NewPlayer#player.nickname),
    	%% 仇人下线通知
		lib_relationship:notice_enemy_online(NewPlayer#player.id, 0, NewPlayer#player.nickname)
	end),
	
	spawn_link(fun()->
					 lib_marry:unload_marry_info(NewPlayer#player.id,NewPlayer#player.sex),
					 %%提亲信息也清除
					 catch ets:delete(?ETS_PROPOSE_INFO, Player#player.id)
			   end),
	
	%%下线通知氏族聊天面板
	if 
		NewPlayer#player.guild_id > 0 ->
		   gen_server:cast(mod_guild:get_mod_guild_pid(),{'MEMBER_ONLINE_FLAG',0,NewPlayer#player.guild_id,NewPlayer#player.id});
	   	true ->
		   skip
	end,

	%%如果在交易的话，立即退出交易状态,通知取消交易
	{ATrade, _BPlayerId} = NewPlayer#player.other#player_other.trade_status,
	if 
		ATrade /= 0 ->
			pp_trade:handle(18007, NewPlayer, [1]);
		true ->	void
	end,
	
    %% 如果正在修炼，先处理再退出
	if
		NewPlayer#player.status =:= 7 orelse NewPlayer#player.other#player_other.exc_status =:= 7 ->
  			spawn(fun()-> db_agent:set_exc_logout_tm(NewPlayer#player.id, Now) end);
  		true ->
  			ok
  	end,
	
	%% 如果已经发送过好友祝福，则保存每日祝福信息
	Pretimes = PlayerState#player_state.bless_times,
  	case Pretimes of
  		0 ->
			ok;
  		_ ->
			spawn(fun()-> db_agent:set_bless_info(NewPlayer#player.id, Pretimes, PlayerState#player_state.last_bless_time) end)
  	end,	

	%% 保存挂机设置
	HookConfig = get(hook_config),
	spawn(fun()-> db_agent:update_hook_config(NewPlayer#player.id, HookConfig) end),
	
	%% 保存玩家分身数据
	spawn(fun()-> lib_player:backup_player_data(NewPlayer) end),
	
	lib_hook:end_hooking(NewPlayer#player.id, NewPlayer#player.scene),
	
	%% 停掉持续BUFF定时器
	lib_player:stop_skill_buff_timer(),
	
	%% 关闭socket组进程
	Socket_gn = mod_socket:get_socket_group_name(NewPlayer#player.sn, NewPlayer#player.accid),
	mod_socket:stop(Socket_gn),
	%% 取消发送进程全局注册
	lists:map(fun(SendNum)-> 
		PlayerSendName = misc:create_process_name(pid_send, [NewPlayer#player.id, SendNum]),
		misc:unregister(PlayerSendName)
	end, lists:seq(1, ?SEND_MSG)),
	
  	%% 处理防沉迷
	case config:get_infant_ctrl(server) of
		1 -> %%防沉迷开启
			Accid = NewPlayer#player.accid,
			case db_agent:get_idcard_status(NewPlayer#player.sn, Accid) of
				%%成年人 
				1 -> 
					ok; 
				_ ->
					TotalTime = 
						case lib_antirevel:get_total_gametime(NewPlayer#player.sn, Accid) of
							null -> 0;
							T -> T
						end,
					T_total_time = Now - NewPlayer#player.last_login_time + TotalTime,
					lib_antirevel:set_total_gametime(NewPlayer#player.sn, Accid, T_total_time),
					lib_antirevel:set_logout_time(NewPlayer#player.sn, Accid, Now)
			end;
		_ -> ok
	end,
	
	%% 更新物品buff和cd
	lib_goods:do_logout(NewPlayer),
	
	%%玩家下线，活跃度数据更新
	lib_activity:player_logout(NewPlayer#player.id),
	
	%% 保存状态数据
    save_player_table(NewPlayer#player{ online_flag = 0 }),
	
	%% 退出物品进程
	gen_server:cast(NewPlayer#player.other#player_other.pid_goods, {stop, 0}),
	%% 退出任务进程
	gen_server:cast(NewPlayer#player.other#player_other.pid_task, {stop, 0}),
	%% 退出经脉进程
	gen_server:cast(NewPlayer#player.other#player_other.pid_meridian, {stop, 0}),
	%% 退出情缘进程
	gen_server:cast(NewPlayer#player.other#player_other.pid_love, {stop, 0}),
	
	%% 清除相关ets数据
	delete_player_ets(NewPlayer#player.id),
	
	%%更新cion+bcion = coin_sum
	spawn(fun()-> db_agent:coin_sum_process(NewPlayer#player.id) end),
	
	%%更新师徒信息
	spawn(fun()-> db_agent:update_apprentice_sum(NewPlayer#player.id) end),
	
    %% 关闭socket连接
    gen_tcp:close(NewPlayer#player.other#player_other.socket),
	catch gen_tcp:close(NewPlayer#player.other#player_other.socket2),
	catch gen_tcp:close(NewPlayer#player.other#player_other.socket3),
	
	%%减少一个在线
	mod_online_count:dec_online_num(),
	
	%%退出农庄  add by zkj
	lib_manor:farm_exit(NewPlayer, []),
	misc:cancel_timer(farm_mature_status_timer),
	%%双修一方下线通知另一方更新双修状态
	Double_rest_id = Player#player.other#player_other.double_rest_id,
	if Double_rest_id > 0  ->
		   %%lib_double_rest:cancel_double_rest(Player);
		   case lib_player:get_online_info_fields(Double_rest_id, [pid]) of
			   [] -> 
				   skip;
			   [OtherPid] ->
				   OtherPid!{'CANEL_DOUBLE_REST_EXP'}
			   end;
	   true ->
		   skip
	end,
	%%如果是在神魔乱斗时间，并且符合条件的则保存玩家的记录(获取的绑定铜的数据)
	lib_warfare:check_save_warfare_award(NewPlayer#player.id, Now),
	%%斗兽系统清除内存数据
	spawn(fun()->lib_mount_arena:release_ets(NewPlayer#player.id) end),	
    ok.

delete_etswhen_init(PlayerId)->
	lib_pet:delete_all_pet(PlayerId),
	lib_dungeon:offline(PlayerId), 
	ets:delete(?ETS_ONLINE, PlayerId).

	
delete_player_ets(PlayerId) ->
	%%清除玩家ets数据
	ets:delete(?ETS_ONLINE, PlayerId),
	%%清除任务模块 
	lib_task:offline(PlayerId),
	%%清除在线奖励模块
	lib_online_gift:offline(PlayerId),
	%%清除经脉模块
	lib_meridian:offline(PlayerId),
    %%删除在线玩家的ets物品表
    goods_util:goods_offline(PlayerId),
    %%清除该玩家在ets_rela的数据,并保存亲密度到DB
    lib_relationship:delete_ets(PlayerId),
    %%清理宠物模块
    lib_pet:role_logout(PlayerId),
    %%清理氏族模块
    mod_guild:role_logout(PlayerId),	
	%%清除雇佣模块
	lib_consign:offline(PlayerId),
	%%清除离线奖励模块
	lib_offline_award:offline(PlayerId),
	%%清除在线时间累积模块
	lib_online_award:offline(PlayerId),
	%%清除跑商数据
	lib_business:offline(PlayerId),
	%%清除情缘数据
	lib_love:offline(PlayerId),
	%%清楚封神贴数据
	lib_hero_card:offline(PlayerId),
	%%清除登陆抽奖数据
	lib_lucky_draw:offline(PlayerId),
	%%清除目标引导数据
	lib_target_lead:offline(PlayerId),
	%%清楚成就系统数据
	lib_achieve:offline(PlayerId),
	%%清除登陆奖励数据
	lib_login_award:offline(PlayerId),
	%%清除副本信息
	lib_dungeon:offline(PlayerId),
	%%清除循环任务奖励
	lib_cycle_flush:delete_cyc_mult(PlayerId),
	%%清除VIP信息
	lib_vip:offline(PlayerId),
	%%氏族祝福玩家下线数据处理
	lib_guild_wish:logout(PlayerId),
	%%清除新手礼包信息
	lib_novice_gift:offline(PlayerId),
	%%神器玩家数据下线处理
	lib_deputy:do_logout(PlayerId),
	%%清除经验找回信息
	lib_find_exp:delete_by_pid(PlayerId),
	%%更新伯乐榜状态
	lib_master_apprentice:update_master_charts_online(PlayerId,0),
	%%清除坐骑信息
	lib_mount:role_logout(PlayerId),
	%%封神纪元信息清除
	lib_era:unload_player_era_info(PlayerId),
	%%清除跨服个人竞技历史记录
	lib_war2:offline_clear_history(PlayerId),
	%%清除目标
	lib_target:offline(PlayerId),
	ok.

%%发消息
%% send_msg(Socket) ->
%%     receive
%%         {send, Bin} ->
%%             gen_tcp:send(Socket, Bin),
%%             send_msg(Socket)
%%     end.

%%停止本游戏进程
stop(Pid, Reason) when is_pid(Pid) ->
    gen_server:cast(Pid, {stop, Reason}).

%% 设置副本
set_dungeon(Pid, PidDungeon) ->
    case is_pid(Pid) of
		true -> 
			gen_server:cast(Pid, {'SET_PLAYER', [{pid_dungeon, PidDungeon}]});
   		false -> 
			false
    end.

%% 设置封神台
set_fst(PlayerPid, SceneId, FstPid) ->
    case is_pid(PlayerPid) of
        false -> false;
        true -> gen_server:cast(PlayerPid, {'SET_PLAYER_FST', SceneId, FstPid})
    end.

%%获取封神台时间信息
get_fst_timeinfo(FstPid)->
	case is_pid(FstPid) of
        false -> false;
        true -> gen_server:cast(FstPid, {'TIMEINFO'})
    end.

%% 设置禁言 或 解除禁言
set_donttalk(PlayerId, {Stop_begin_time, Stop_chat_minutes}) ->
  	gen_server:cast({global, misc:player_process_name(PlayerId)}, 
					{set_donttalk, Stop_begin_time, Stop_chat_minutes}).

%% 同步更新ETS中的角色数据
save_online(PlayerStatus) ->
	%% 更新本地ets里的用户信息
    ets:insert(?ETS_ONLINE, PlayerStatus),
	%% 更新对应场景中的用户信息
    mod_scene:update_player(PlayerStatus),
	ok.

%% 同步场景玩家属性 [{k,v}]形式
save_online_info_fields(NewPlayer, KeyValue) ->
%%	?DEBUG("~pINFO_FIELDS:~p~n",[util:unixtime(),KeyValue]),
	ets:insert(?ETS_ONLINE, NewPlayer),
	mod_scene:update_player_info_fields(NewPlayer, KeyValue),
	ok.

%% 差异同步场景玩家属性
save_online_diff(OldPlayer,NewPlayer) ->
    Plist = record_info(fields,player),
    Olist = record_info(fields,player_other),
    Fields = lists:append(Plist, Olist),
    OvalList = lib_player_rw:get_player_info_fields(OldPlayer,Fields),
    NvalList = lib_player_rw:get_player_info_fields(NewPlayer,Fields),
    KeyValue = get_diff_val(OvalList,NvalList,Fields),
%%	?DEBUG("~pKEY-VAL:~p~n",[util:unixtime(),KeyValue]),
    if
        length(KeyValue) > 0 ->
            ets:insert(?ETS_ONLINE, NewPlayer),
            mod_scene:update_player_info_fields(NewPlayer, KeyValue);
        true ->
            skip
    end.

get_diff_val(Ol,Nl,Fs)->
	get_diff_val_loop(Ol,Nl,Fs,[]).

get_diff_val_loop([],_,_,DiffList) ->
	DiffList;
get_diff_val_loop(_,[],_,DiffList) ->
	DiffList;
get_diff_val_loop(_,_,[],DiffList) ->
	DiffList;
get_diff_val_loop([V1|Ol],[V2|Nl],[K|Fs],DiffList) ->
	if
		K /= other andalso V1 /= V2 ->
			get_diff_val_loop(Ol,Nl,Fs,[{K,V2}|DiffList]);
		true ->
			get_diff_val_loop(Ol,Nl,Fs,DiffList)
	end.
	
				
%% 保存基本信息
%% 这里主要统一更新一些相对次要的数据。譬如经验exp不会实时写入数据库，它会等下次和灵力值一起写入
%% 当玩家退出的时候也会执行一次这边的信息 
save_player_table(Player) ->
	Sta = 
		case lists:member(Player#player.status, [0, 1]) of
			true ->
				Player#player.status;
			_ ->
				0
		end,
	FieldList = [scene, x, y, hp, mp, exp, spirit, online_flag, cash, pk_mode, 
				 pk_time, status, evil, honor, culture, arena, realm_honor],
	Hp =
		if
			Player#player.hp > 0 ->
				Player#player.hp;
			true ->
				0
		end,
	Mp = 
		if
			Player#player.mp > 0 ->
				Player#player.mp;
			true ->
				0
		end,
	ValueList = [
   		Player#player.scene,
       	Player#player.x,
    	Player#player.y,
       	Hp,
    	Mp,
   		Player#player.exp,
       	Player#player.spirit,
     	Player#player.online_flag,
		Player#player.cash,
     	Player#player.pk_mode,
     	Player#player.pk_time,
    	Sta,
    	Player#player.evil,
       	Player#player.honor,
    	Player#player.culture,
		Player#player.arena,
		Player#player.realm_honor
    ],
	spawn(fun()-> db_agent:save_player_table(Player#player.id, FieldList, ValueList) end).

%%玩家登陆处理防沉迷信息
check_idcard_status(Player) ->
	case config:get_infant_ctrl(server) of
		0 ->
			skip;
		1 ->
			Sn = Player#player.sn,
			Accid = Player#player.accid,
			Accname = Player#player.accname,
			Pid_send = Player#player.other#player_other.pid_send,
			Alart_time_1h = 60*60 + 5,
			Alart_time_2h = 120*60 + 5,
			Alart_time = (3*60-5)*60 + 5,
			Force_out_time = 3*60*60 + 5,%%3*60*60 + 5,
			S = db_agent:get_idcard_status(Sn, Accid, Accname),
			if
				S == 0 orelse S == 1 ->
					T_game_time = 0;
				true ->
					T_game_time = lib_antirevel:get_total_gametime(Sn, Accid)
					%%T_game_time = 4 * 3600
			end,
			if
				S /= 1 andalso S /= 0 ->					
					Leave_time = util:unixtime() - lib_antirevel:get_logofftime(Sn, Accid),
					if 
						%%如果游戏时间大于3小时
						T_game_time >=	3*3600 ->
								if 
									%%如果离开时间小于5小时
									Leave_time < 5*3600 ->															
										%%这里需要断开游戏
										erlang:send_after(5 * 1000, self(), 'FORCE_OUT_REVEL'),
										{ok, Bin} = pt_10:write(10040, 0),
										lib_send:send_to_sid(Pid_send, Bin);
									true ->
										%%可以正常游戏，累计时间重置
										lib_antirevel:set_total_gametime(Sn, Accid, 0),
										skip
								end;
						true -> 
							skip
					end;
				true ->
					skip
			end,
			case S of
				0 ->
					%%告诉玩家登陆成功(第一次登陆)
                    {ok, BinData} = pt_10:write(10040, 2);
				1 ->
					%%告诉玩家登陆成功(成年人)
                    {ok, BinData} = pt_10:write(10040, 1);
				2 ->
					%%告诉玩家登陆成功(未成年人)
                    {ok, BinData} = pt_10:write(10040, 3);
				3 ->
					%%告诉玩家登陆成功(尚未输入身份证信息)
                    {ok, BinData} = pt_10:write(10040, 4);
				_ ->
					{ok, BinData} = pt_10:write(10040, 4)
			end,
			lib_send:send_to_sid(Pid_send, BinData),
			if
				S == 0 ->
					erlang:send_after(Alart_time_1h *1000, self(), {'ALART_REVEL', 60}),
					erlang:send_after(Alart_time_2h *1000, self(), {'ALART_REVEL', 120}),
					erlang:send_after(Alart_time *1000, self(), {'ALART_REVEL', 180}),
					erlang:send_after(Force_out_time *1000, self(), 'FORCE_OUT_REVEL');
				S == 1 ->
					skip;
				true ->
					if T_game_time < Alart_time_1h ->
						erlang:send_after((Alart_time_1h - T_game_time) * 1000, self(), {'ALART_REVEL', 60});
					   true -> ok
					end,
					if T_game_time < Alart_time_2h ->
						erlang:send_after((Alart_time_2h - T_game_time) * 1000, self(), {'ALART_REVEL', 120});
					   true -> ok
					end,
					if T_game_time < Alart_time ->
						erlang:send_after((Alart_time - T_game_time) * 1000, self(), {'ALART_REVEL', 180});
					   true -> ok
					end
					
			end				
	end.
