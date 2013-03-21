%% Author: xianrongMai
%% Created: 2011-11-8
%% Description: 氏族召唤功能模块
-module(lib_guild_call).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include("guild_info.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

-define(CHIEF_CONVENCE_LIMIT, 3).				%%族长召唤次数限制-->3次
-define(CHIEF_CONVENCE_FUNDS_NEED, 10000).		%%氏族召唤所花销的氏族资金
-define(PK_CALLTIME_LIMIT, 60).				%%玩家被攻击时实施召唤族员的冷却时间-->60秒
-define(GUILD_CALL_TIMELIMIT, 60).				%%氏族成员传送的地点有效时间

%%
%% Exported Functions
%%
-export([
		 reponse_chief_convence/1,				%% 40086 成员回应族长召唤
		 cast_receive_convence/2,				%%收到族长召唤的氏族成员进程向客户端发提示
		 dealwith_chief_convence/7,				%%氏族进程处理族长召唤功能
		 chief_convence/1,						%% 40085 族长召唤
		 handle_pk_call_guildhelp/7,			%%玩家被攻击收到消息后进行的处理
		 fly_to_help_pk/6,						%% 40084 族员答应传送求援PK
%% 		 get_pk_coord/0,						%%获取和更新玩家传送的坐标
%% 		 put_pk_coord/1,						%%获取和更新玩家传送的坐标
		 get_pkcall_time/0,						%%获取和更新氏族成员被PK时的救援时间
		 put_pkcall_time/1,						%%获取和更新氏族成员被PK时的救援时间
		 pk_call_guildhelp/5,					%%往被攻击方的玩家发通知判断
		 deal_with_pk_help/9,					%%氏族进程接受信息后，进行广播处理
		 cast_receive_pkhelp/2					%%收到求救信号的氏族成员进程向客户端发提示
		]).

%%
%% API Functions
%%
%%往被攻击方的玩家发通知判断
pk_call_guildhelp(AerRealm, AerGuildName, AerGuildId, AerName, Der) ->
	case Der#player.guild_id =/= 0 
		andalso AerGuildId =/= Der#player.guild_id 
		andalso(Der#player.scene < 500 orelse Der#player.scene =:= 705) 
		andalso Der#player.scene =/= ?WEDDING_SCENE_ID
		andalso Der#player.scene =/= ?WEDDING_LOVE_SCENE_ID of
		true ->%%被攻击方是有氏族的，且不是自己氏族内讧的，需要召唤族员帮忙打架
			gen_server:cast(Der#player.other#player_other.pid, 
							{'PK_CALL_GUILDEHLP', AerRealm, AerGuildName, AerName, Der#player.scene, Der#player.x, Der#player.y});
		false ->
			skip
	end.
%%玩家被攻击收到消息后进行的处理
handle_pk_call_guildhelp(AerRealm, AerGuildName, AerName, OSceneId, OX, OY, Player) ->
	#player{guild_id = GuildId,
			id = PlayerId,
			nickname = NickName} = Player,
	%%获取上次pkcall的时间戳
	PKCallTime = lib_guild_call:get_pkcall_time(),
	NowTime = util:unixtime(),
	Diff = NowTime - PKCallTime,
%% 	?DEBUG("handle_pk_call_guildhelp", []),
	case GuildId =/= 0 andalso Diff > ?PK_CALLTIME_LIMIT of
		true ->
			gen_server:cast(mod_guild:get_mod_guild_pid(),
							{apply_cast, lib_guild_call, deal_with_pk_help, 
							[AerRealm, AerGuildName, AerName, OSceneId, OX, OY, GuildId, PlayerId, NickName]}),
			%%更新进程字典
			lib_guild_call:put_pkcall_time(NowTime);	
		false ->
			skip
	end.

%%氏族进程接受信息后，进行广播处理
deal_with_pk_help(AerRealm, AerGuildName, AerName, OSceneId, OX, OY, GuildId, PlayerId, DerName) ->
	DealType = pk_call_guildhelp,		%%数据消息处理类型
	Data= [AerRealm, AerGuildName, AerName, OSceneId, OX, OY, DerName],
	send_guildcall_online(GuildId, PlayerId, Data, DealType).

%%查找在线的氏族成员
search_member_online(GuildId) -> 
	Ms = ets:fun2ms(fun(M) when M#ets_guild_member.guild_id =:= GuildId andalso M#ets_guild_member.online_flag =:= 1 ->
							M#ets_guild_member.player_id
					end),
	ets:select(?ETS_GUILD_MEMBER, Ms).

%%收到求救信号的氏族成员进程向客户端发提示
cast_receive_pkhelp(Param, Status) ->
	[_AerRealm, _AerGuildName, _AerName, OSceneId, OX, OY, _DerName] = Param,
	%%更新求援坐标
	NowTime = util:unixtime(),
	put_pk_coord({NowTime, OSceneId, OX, OY}),
	%%通知客户端
	{ok, Bin40083} = pt_40:write(40083, Param),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bin40083),
	Status.

%% -----------------------------------------------------------------
%% 40084 族员答应传送求援PK
%% -----------------------------------------------------------------
fly_to_help_pk(Status, Type, OSceneId, OX, OY, HelpType) ->
	PKCoord = 
		case HelpType of
			1 ->
				get_pk_coord();
			2 ->
				lib_marry:get_cuple_pk_coord()
		end,
	NowTime = util:unixtime(),
	Check = lists:any(fun(Elem) ->
							  {Time, SceneId, X, Y} = Elem,
							  Diff = NowTime - Time,
							  SceneId =:= OSceneId andalso X =:= OX andalso Y =:= OY andalso Diff =< ?GUILD_CALL_TIMELIMIT %%小于一分钟的才有效
					  end, PKCoord),
	Reply = 
		case Check of
			false ->%%已经没有这个坐标了，不能传了
				{16, Status};
			true ->
				case Type of
					1 ->%%一般的传送
						case Status#player.vip =:= 3 of
							false ->%%不是钻石VIP，有次数限制
								case lib_vip:check_send_times(Status#player.id,Status#player.vip) of
									false ->
										{19, Status};
									true ->
										case exchange_could_deliver(Status) of
											ok ->
												NewStatus=lib_deliver:deliver(Status, OSceneId, OX, OY,3),
												{1, NewStatus};
											ErrorCode ->
												{ErrorCode, Status}
										end
								end;
							true ->
								case exchange_could_deliver(Status) of
									ok ->
										NewStatus=lib_deliver:deliver(Status, OSceneId, OX, OY,3),
										{1, NewStatus};
									ErrorCode ->
										{ErrorCode, Status}
								end
						end;
					2 ->%%用铜币传送的
					case exchange_could_deliver(Status) of
						ok ->
							%%铜币是否足够
							case goods_util:is_enough_money(Status, 5000, coin) of
								true ->
									NewStatus=lib_deliver:deliver(Status, OSceneId, OX, OY,2),
									%%扣铜钱
									NewPlayerStatus = lib_goods:cost_money(NewStatus, 5000, coin, 4084),
									lib_player:send_player_attribute(NewPlayerStatus, 1),
									{1, NewPlayerStatus};
								false ->
									{18, Status}
							end;
						ErrorCode ->
							{ErrorCode, Status}
					end
				end
		end,
	Reply.


%% -----------------------------------------------------------------
%% 40085 族长召唤
%% -----------------------------------------------------------------
chief_convence(Status) ->
	GuildId = Status#player.guild_id,
	case GuildId of
		0 ->
			2;
		_ ->
			{Reply, ConvenceSceneId} = 
				case lib_deliver:could_deliver(Status) of
					ok ->
						{ok, Status#player.scene};
					Value when Value =:= 31 orelse Value =:= 33 orelse Value =:= 34 %%副本中;竞技场;封神台;
					  orelse Value =:= 35 orelse Value =:= 37 orelse Value =:= 38 orelse Value =:= 43 ->  %%秘境;镇妖台;诛仙台;婚宴
						{4, 0};
					39 ->%%温泉里
						{5, 0};
					32 -> %%氏族领地
						{ok, ?GUILD_SCENE_ID};
					36 ->%%空岛
						{10, 0};
					_ ->
						{ok, Status#player.scene}
				end,
			case Reply of
				ok ->
					case (ConvenceSceneId > 500 andalso ConvenceSceneId =/= 705) orelse ConvenceSceneId =:= ?WEDDING_SCENE_ID
						 orelse ConvenceSceneId =:= ?WEDDING_LOVE_SCENE_ID of%%灵兽盛园的Id705，排除到副本外
						true ->
							NReply = 4,
							%%向族长反馈
							{ok, BinData40085} = pt_40:write(40085, [NReply]),
							lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData40085);
						false ->
					gen_server:cast(mod_guild:get_mod_guild_pid(),
									{apply_cast, lib_guild_call, dealwith_chief_convence, 
									 [GuildId, Status#player.id, Status#player.guild_position, 
									  ConvenceSceneId, Status#player.x, Status#player.y,
									  Status#player.other#player_other.pid_send]})
					  end;
				_Other ->%%直接就返回结果
					%%向族长反馈
					{ok, BinData40085} = pt_40:write(40085, [Reply]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData40085)
			end
	end.

%%氏族进程处理族长召唤功能
dealwith_chief_convence(GuildId, ChiefId, ChiefPost, SceneId, X, Y, PidSend) ->
	Reply = 
		case lib_guild_inner:get_guild(GuildId) of
			[] ->
				6;
			Guild ->
				Funds = Guild#ets_guild.funds,
				if
					Funds < ?CHIEF_CONVENCE_FUNDS_NEED ->%%资金不足
						7;
					ChiefPost >= 4 ->%%不是族长和长老，没权限
						3;
					true ->
						OConvenceStr = Guild#ets_guild.convence,
						[Time, Num] = util:string_to_term(tool:to_list(OConvenceStr)),
						NowTime = util:unixtime(),
						IsDate = util:is_same_date(Time, NowTime),
						case IsDate of
							true ->
								case Num >= ?CHIEF_CONVENCE_LIMIT of
									true ->%%超过次数了
										8;
									false ->
										%%更新ets,和数据库
										NewFunds = Funds - ?CHIEF_CONVENCE_FUNDS_NEED,
										NConvence = [NowTime, Num +1],
										NConvenceStr = util:term_to_string(NConvence),
										NewGuild = Guild#ets_guild{convence = NConvenceStr,
																   funds = NewFunds},
										lib_guild_inner:update_guild(NewGuild),
										

										ValueList = [{convence, NConvenceStr}, {funds, NewFunds}],
										WhereList = [{id, GuildId}],
										db_agent:update_guild_call(guild, ValueList, WhereList),
										%%发送数据
										DealType = chief_convence,		%%数据消息处理类型
										Data = [SceneId, X, Y],
										send_guildcall_online(GuildId, ChiefId, Data, DealType),
										1
								end;
							false ->%%已经不是同一天了，这就不用判断次数
								%%更新ets,和数据库
								NewFunds = Funds - ?CHIEF_CONVENCE_FUNDS_NEED,
								NConvence = [NowTime, 1],
								NConvenceStr = util:term_to_string(NConvence),
								NewGuild = Guild#ets_guild{convence = NConvenceStr,
														   funds = NewFunds},
								lib_guild_inner:update_guild(NewGuild),
								
								ValueList = [{convence, NConvenceStr}, {funds, NewFunds}],
								WhereList = [{id, GuildId}],
								db_agent:update_guild_call(guild, ValueList, WhereList),
								%%发送数据
								DealType = chief_convence,		%%数据消息处理类型
								Data = [SceneId, X, Y],
								send_guildcall_online(GuildId, ChiefId, Data, DealType),
								1
						end
				end
		end,
%% 	?DEBUG("dealwith_chief_convence, Reply:~p", [Reply]),
	%%向族长反馈
	{ok, BinData40085} = pt_40:write(40085, [Reply]),
	lib_send:send_to_sid(PidSend, BinData40085).
	
%%收到族长召唤的氏族成员进程向客户端发提示
cast_receive_convence(Param, Status) ->
%% 	?DEBUG("Param:~p", [Param]),
	[SceneId, X, Y] = Param,
	%%更新求援坐标
	NowTime = util:unixtime(),
	put_convence_coord({NowTime, SceneId, X, Y}),
	{ok, Bin40083} = pt_40:write(40087, []),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, Bin40083),
	Status.
			

%% -----------------------------------------------------------------
%% 40086 成员回应族长召唤
%% -----------------------------------------------------------------
reponse_chief_convence(Status) ->
	case get_convence_coord() of
		{false, _} ->
			{16, Status};
		{true, {Time, SceneId, X, Y}} ->
			case (SceneId > 500 andalso SceneId =/= 705) orelse SceneId =:= ?WEDDING_SCENE_ID 
				 orelse SceneId =:= ?WEDDING_LOVE_SCENE_ID of%%灵兽盛园的Id705，排除到副本外
				true ->
					{12, Status};
				false ->
			NowTime = util:unixtime(),
			Diff = NowTime - Time,
			case Diff =< ?GUILD_CALL_TIMELIMIT of
				true ->%%还好，一分钟内传送
					case exchange_could_deliver(Status) of
						ok ->
							case SceneId =:= ?GUILD_SCENE_ID of
								true ->%%召唤回氏族领地的
									case reponse_convence_manor(Status, SceneId, X, Y) of
										fail ->
											{0, Status};
										{ok, NewStatus} ->
											{1, NewStatus}
									end;
								false ->
									NewStatus=lib_deliver:deliver(Status, SceneId, X, Y,3),
									{1, NewStatus}
							end;
						ErrorCode ->
							{ErrorCode, Status}
					end;
				false ->%%超过时限了，不提供服务啦
					{16, Status}
			end
			end
	end.
%%专门处理回氏族领地的请求
reponse_convence_manor(Status, CSceneId, CX, CY) ->
	Result = 
		case data_scene:get(CSceneId) of
			[] ->
				{false, 0, 0, 0, <<"场景不存在!">>, 0, []};
			Scene ->
				case lib_scene:check_requirement(Status, Scene#ets_scene.requirement) of
					{false, Reason} -> 
						{false, 0, 0, 0, Reason, 0, []};
					{true} when Scene#ets_scene.type =:= 5 ->
						%%开始处理进入氏族领地的逻辑
						#player{id = PlayerId,
								guild_id = GuildId} = Status,
						PlayerPid = Status#player.other#player_other.pid,
						{ok, ManorPid} = mod_guild_manor:get_guild_manor_pid(CSceneId, GuildId, PlayerId, PlayerPid),%%获取进程号
						UniqueSceneId = lib_guild_manor:get_unique_manor_id(CSceneId, GuildId),
						lib_guild_manor:update_guild_manor_dict(guild_manor_pid, ManorPid),%%更新进程字典
						NewStatus0 = Status#player{other = Status#player.other#player_other{pid_scene = ManorPid}},
						%%下坐骑
						{ok, NewStatus1} = lib_goods:force_off_mount(NewStatus0),
						{true, UniqueSceneId, Scene#ets_scene.x, Scene#ets_scene.y, Scene#ets_scene.name, Scene#ets_scene.sid, 0, 0, NewStatus1};
					_Other ->
						{false, 0, 0, 0, <<"场景不存在!">>, 0, []}
				end
		end,
	case Result of
		 {false, _, _, _, _Msg, _, _} ->
			 fail;
		{true, NewSceneId, _X, _Y, Name, SceneResId, Dungeon_times, Dungeon_maxtimes, Status1} ->
			%%告诉原场景的玩家你已经离开
			pp_scene:handle(12004, Status, Status#player.scene),
%% 			?DEBUG("X:~p,Y:~p", [CX,CY]),
			{ok, BinData} = pt_12:write(12005, 
										[NewSceneId, CX, CY, Name, SceneResId, Dungeon_times, Dungeon_maxtimes, 0]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			put(change_scene_xy , [CX, CY]),%%做坐标记录
			Status2 = Status1#player{scene = NewSceneId, x = CX, y = CY},
			%%更新玩家新坐标
			ValueList = [{scene,NewSceneId},{x,CX},{y,CY}, {carry_mark, Status2#player.carry_mark}],
			WhereList = [{id, Status1#player.id}],
			db_agent:mm_update_player_info(ValueList, WhereList),
			{ok, Status2}
	end.

%%
%% Local Functions
%%
%%向在线的玩家发送信息
send_guildcall_online(GuildId, PlayerId, Data, DealType) ->
%% 	?DEBUG("GuildId:~p, PlayerId:~p, Data:~p, DealType:~p", [GuildId, PlayerId, Data, DealType]),
	case search_member_online(GuildId) of
		[] ->
			skip;
		MemberIds ->
			NMIds = lists:delete(PlayerId, MemberIds),%%去掉自己
			%%广播
			lists:foreach(fun(Elem) ->
								  case lib_player:get_player_pid(Elem) of
									  [] ->
										  skip;	
									  Pid -> 
										  gen_server:cast(Pid, {'GUILD_SET_AND_SEND', DealType, Data})
								  end
						  end, NMIds)
	end.

%%由lib_deliver:could_deliver/1	方法返回的状态码 转化成本模块适合的状态吗
exchange_could_deliver(Status) ->
	case lib_deliver:could_deliver(Status) of
		ok ->
			ok;
		10->  %%战斗中
			2;
		11->  %%死亡中
			3;
		12->  %%蓝名
			4;
		13->  %%挂机状态
			5;
		14->  %%打坐状态
			6;
		15->  %%凝神修炼
			7;
		16->  %%挖矿状态
			8;
		17->  %%答题状态 
			ok;
		18->  %%双修不能使用筋斗云
			9;
		21->  %%红名（罪恶值>=450）
			ok;
		22->  %%运镖状态
			10;
		32 -> %%氏族领地
			11;
		Value when Value =:= 31 orelse Value =:= 33 orelse Value =:= 34 %%副本中;竞技场;封神台;
		  orelse Value =:= 35 orelse Value =:= 37 orelse Value =:= 38 orelse Value =:=  43 ->  %%秘境;镇妖台;诛仙台;婚宴
			12;
		36 ->  %%空岛
			13;
		39->  %%温泉
			14;
		40->  %%封神大会不能使用筋斗云
			15;
		_ ->
			0
	end.


%%获取和更新氏族成员被PK时的救援时间
get_pkcall_time() ->
	case get(pk_call_time) of
		Time when is_integer(Time) ->
			Time;
		_ ->
			0
	end.
put_pkcall_time(NowTime) ->
	put(pk_call_time, NowTime).

%%获取和更新玩家传送的坐标
get_pk_coord() ->
	case get(pk_coord) of
		List when is_list(List) ->
			List;
		_ ->
			[]
	end.
put_pk_coord({NowTime, SceneId, X, Y}) ->
	List = get_pk_coord(),
	%%过滤过期的数据
	FilteList = lists:foldl(fun(Elem, AccIn) ->
								  {ETime, _ESceneId, _EX, _EY} = Elem, 
								  Diff = NowTime - ETime,
								  case Diff > ?GUILD_CALL_TIMELIMIT of
									  true ->
										 AccIn;
									  false ->
										  [Elem|AccIn]
								  end
						  end, [], List),
	NewList = [{NowTime, SceneId, X, Y}|FilteList],
	put(pk_coord, NewList).
			
%%获取和更新氏族族长召唤的场景坐标数据
put_convence_coord({NowTime, SceneId, X, Y}) ->
	put(convence, {NowTime, SceneId, X, Y}).
get_convence_coord() ->
	case get(convence) of
		undefined ->
			{false, {0, 0, 0, 0}};
		{NowTime, SceneId, X, Y} ->
			{true, {NowTime, SceneId, X, Y}};
		_ ->
			{false, {0, 0, 0, 0}}
	end.