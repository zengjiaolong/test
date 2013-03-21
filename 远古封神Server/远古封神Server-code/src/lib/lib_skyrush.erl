%% Author: Xianrong.Mai
%% Created: 2011-4-9
%% Description: 空岛神战的对外接口和处理方法
-module(lib_skyrush).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("guild_info.hrl").


-define(CONFING_FILE_LIST,[{kyrush_time, [{notice_sign_up, 20, 25},
										  {sky_rush_start_time, 20, 30},  
										  {sky_rush_end_time, 21, 05},
										  {sky_rush_start_time_email, 20, 35},
										  {sky_hold_week, [1, 4]}%%2,4,6开战
										 ]
						   }]).
%%测试时用以下数据
%%================================
%% -define(CONFING_FILE_LIST,[{kyrush_time, [{notice_sign_up, 19, 35},
%% 										  {sky_rush_start_time, 19, 40},  
%% 										  {sky_rush_end_time, 20, 50},
%% 										  {sky_rush_start_time_email, 19, 45},
%% 										  {sky_hold_week, [1, 2, 3, 4, 5, 6, 7]}%%测试用数据
%% 										 ]
%% 						   }]).
%%================================

-define(SKY_HOLD_WEEK_FORMAIL, [1, 4, 8]). %%邮件发送需要的数据，是sky_hold_week的演变，需要与sky_hold_week同步更新
%% -define(SKY_HOLD_WEEK_FORMAIL, [1, 2, 3, 4, 5, 6, 7, 8]). %%测试用数据

-define(KILL_GET_FEATS, 1).  %%杀人获得的个人功勋数
-define(SKY_RUSH_LEVEL_NEED, 3).	%%氏族报名等级限制

-define(AWARD_TIMEOUT, 24*3600).%%功勋奖励的过期时间
%% -define(AWARD_TIMEOUT, 200).%%功勋奖励的过期时间(测试)

%%
%% Exported Functions
%%
-export(
   [
	cast_notice_sky_player/2,		%%玩家进程处理神岛空战的通知
	notice_all_sky_player/1,		%%通知参加神岛空战的的所有成员
	ets_get_sky_gids/0,				%%获取整个参战的氏族列表Id
	set_guild_data/2,				%%用于即时修改氏族一些数据
	set_guild_data_inline/2,		%%不对外调用
	get_applied_guilds/0,			%% 39001 查看已报名氏族
	apply_skyrush/3,				%% 39002 报名空岛神战
	init_guild_feats/0,				%%初始化氏族功勋数据
	enter_sky_scene/1,				%% 39003 进入空岛神战
	check_applied_guild_inter/1,
	start_skyrush/2,				%%神岛空战初始化
	check_quit_skyscene/1,			%%离开空岛判断
	send_skyrush_notice/2,			%%系统公告
	send_skyrush_tips/2,			%%提示tips发送
	is_skyrush_scene/1,
	is_get_skyrush_scene/1,
	get_member_feats/2,				%%获取氏族成员的功勋
	kill_sky_bossmon/1,				%%杀死boss怪
	kill_sky_littlemon/1,			%%杀死小怪
	init_little_mon/1,
	submit_feats/10,				%% 39011 交战旗或魔核
	pickup_fn/4,					%% 39012 拾取战旗
	handle_skyrush_end/1,			%% 39009 结束神战
	send_outsky/0,
	handle_mfeats/2,
	handle_gfeats/3,
	reflesh_flags/0,				%%刷新旗
	reflesh_flag/1,					%%局部的刷新旗
	get_flags_coord/1,				%%旗的坐标
	get_point_coord/1,				%%获取据点坐标
	player_logout_sky/1,			%%玩家下线，数据更新
	discard_flags_battle/3,			%%因为战斗取消取旗
	get_sky_info/1,					%% 39007 战场信息
	player_goto_sky/3,
	update_player_flags_state/2,	%%通知玩家carry_mark状态的改变
	get_start_end_time/0,			%%获取配置的时间
	get_skyrush_start_infact/0,		%%获取空岛实际上开战的时间
	drop_fns_for_die/8,
	change_fns_player/9,
	rank_guild_member_feats/0,		%%空岛战场积分排行榜
	get_skyrush_rank/1,				%%玩家主动获取排行榜信息
	load_skyrush_g_rank/1,			%%加载氏族空岛排行榜
	load_skyrush_m_rank/2,			%%加载空岛神战的氏族成员排行榜
	flesh_point_l/1,
	flesh_point_h/1,
	update_skyrush_killdie/3,		%%更新杀敌数和死亡数
	sky_die_reset/4,
	add_kill_die_num/2,
	reflesh_flags_member/2,			%%定时刷新错误的数据
	get_sky_award/2,				%% 39025 氏族战奖励
	get_mail_date/1,				%%获取系统邮件日期
	make_guild_apply_log/1,
	reset_player_flags/2,
	query_skymem_rank/1,
	get_skyrush_state/0,
	make_member_join_log/2,
	flesh_clean_drop_flags/1,		%%清理过期丢在地上的战旗
	deduct_player_feat/5,			%%对外提供的扣除个人功勋的接口，返回剩余功勋
	deduct_member_feat/6,			%%警告：此方法不能对外调用
	sky_award_mail/3,				%%警告：此方法不能对外调用
%% 	氏族战奖励接口
	get_sky_award_and_members/1,
	assign_goods_man/4,
	assign_goods_auto/1,
	notice_to_sign_up/0,
	check_sign_up/3,
	check_sky_doornot/0,			%%检查是否能够进行一些在空战时不能执行的操作
	tobe_opening_skyrush/1,			%%判断是否要开神岛空战
	gmcmd_update_skyaward/1,		%%GM命令使用接口
	skyrush_send_mail/5,
	sync_member_feats/2
	]
).

%% ====================================================================
%% External functions
%% ====================================================================
%% -----------------------------------------------------------------
%% 39001 查看已报名氏族
%% -----------------------------------------------------------------
get_applied_guilds() ->
%% 	io:format("Now:~p; StartTime:~p, EndTime:~p\n", [Now, StartTime, EndTime]),
	MS = ets:fun2ms(fun(T) when T#ets_guild.sky_apply =:= 1 ->
							T end),
	MatchS = get_guilds_by_etsms(MS),
%% 	io:format("MatchS:~p\n", [MatchS]),
	handle_applied_guilds(MatchS, []).

handle_applied_guilds([], Result) ->
	Result;
handle_applied_guilds([Guild|MatchS], Result) ->
	#ets_guild{id = GuildId,
			   level = GLv,
			   member_num = GMems,
			   name = GuildName,
			   chief_name = ChiefName} = Guild,
	Elem = {GuildId, GLv, GMems, GuildName, ChiefName},
	handle_applied_guilds(MatchS, [Elem|Result]).
	
%% -----------------------------------------------------------------
%% 39002 报名空岛神战
%% -----------------------------------------------------------------
apply_skyrush(_PlayerId, GuildId, _Posit) ->
	Guild = lib_guild_inner:get_guild(GuildId),
	if
		Guild =:= [] ->
			0;
		is_record(Guild, ets_guild) =:= false ->
			0;
		Guild#ets_guild.level < ?SKY_RUSH_LEVEL_NEED ->
			3;
		Guild#ets_guild.funds < ?SKY_RUSH_FUNDS_NEED ->
			4;
%% 		Posit >= 4 ->
%% 			5;
		true ->
			AppliedTime = Guild#ets_guild.sky_apply,
			%%配置表
			[WeekDate, SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = get_start_end_time(),
			%%判断今天星期几
			Date = util:get_date(),
			%%是否要开氏族战
			Judge = lists:member(Date, WeekDate),
			NowSec = util:get_today_current_second(),
			
			case AppliedTime =:= 1 of
				true ->
					6;
				false when Judge =:= false ->
					NewFunds = Guild#ets_guild.funds - ?SKY_RUSH_FUNDS_NEED,
					NewGuild = Guild#ets_guild{funds = NewFunds,
											   sky_apply = 1},
					ValueList = [{funds, NewFunds}, {sky_apply, 1}],
					FieldList = [{id, Guild#ets_guild.id}],
					db_agent:apply_skyrush(guild, ValueList, FieldList),
					%%更新氏族缓存
					lib_guild_inner:update_guild(NewGuild),
					%%做报名日志记录
					spawn(fun() -> lib_skyrush:make_guild_apply_log(GuildId) end),
					%%群发邮件
					[SHour, SMine, EHour, EMine] = get_startend_time_base(),
					Param = [Date, SHour, SMine, EHour, EMine],
					skyrush_send_mail(0, 0, GuildId, apply_skyrush_succeed, Param),
					1;
				false when Judge =:= true andalso (NowSec =< SKY_RUSH_START_TIME  orelse NowSec >= SKY_RUSH_END_TIME)  ->
					NewFunds = Guild#ets_guild.funds - ?SKY_RUSH_FUNDS_NEED,
					NewGuild = Guild#ets_guild{funds = NewFunds,
											   sky_apply = 1},
					ValueList = [{funds, NewFunds}, {sky_apply, 1}],
					FieldList = [{id, Guild#ets_guild.id}],
					db_agent:apply_skyrush(guild, ValueList, FieldList),
					%%更新氏族缓存
					lib_guild_inner:update_guild(NewGuild),
					%%做报名日志记录
					spawn(fun() -> lib_skyrush:make_guild_apply_log(GuildId) end),
					%%群发邮件
					[SHour, SMine, EHour, EMine] = get_startend_time_base(),
					if
						NowSec =< SKY_RUSH_START_TIME ->
							Param = [Date, SHour, SMine, EHour, EMine];
						true ->
							Param = [Date+1, SHour, SMine, EHour, EMine]
					end,
					skyrush_send_mail(0, 0, GuildId, apply_skyrush_succeed, Param),
					1;
				false ->
					2
			end
	end.
	
%% -----------------------------------------------------------------
%% 39003 进入空岛神战
%% -----------------------------------------------------------------
enter_sky_scene(Status) ->
	#player{lv = Lv,
			scene = PSceneId,
			guild_id = GuildId} = Status,
	SceneId = lib_guild_manor:get_scene_Id_from_scene_unique_id(PSceneId, GuildId),
	NowSec = util:get_today_current_second(),
	[_WeekDate, SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = get_start_end_time(),
	case NowSec >= (SKY_RUSH_START_TIME + 5*60 + 10) andalso NowSec  =< SKY_RUSH_END_TIME - 6 of
		true ->
	CheckResult = check_applied_guild(GuildId),
	TeamPid = Status#player.other#player_other.pid_team,
	if
		PSceneId =:= ?SKY_RUSH_SCENE_ID ->%%已经在里面了
			{8, Status};
		(SceneId =/= 500 andalso PSceneId > 500 andalso  PSceneId =/= 705) orelse PSceneId =:= ?WEDDING_SCENE_ID ->
			{7, Status};
		CheckResult =/= 1 ->%%未报名或者还未到时间:3,4
			{CheckResult, Status};
		is_pid(TeamPid) =:= true ->%%有队伍
			{5, Status};
		%% 红名
		Status#player.evil > 300 ->
			{6, Status};
		Lv < 35 ->
			{2, Status};
		true ->%%可以进去了
			Result = 
				case lib_guild_manor:check_guild_sky_enter(Status) of
					{fail, FailType} ->
%% 						?DEBUG("FailType:~p", [FailType]),
						{false, 0, 0, 0, FailType, 0, []};
					{ok} ->
				case data_scene:get(?SKY_RUSH_SCENE_ID) of
					[] ->
						{false, 0, 0, 0, <<"场景不存在!">>, 0, []};
					Scene ->
						case lib_scene:check_requirement(Status, Scene#ets_scene.requirement) of
							{false, Reason} -> 		
								{false, 0, 0, 0, Reason, 0, []};
							{true} when Scene#ets_scene.type =:= 9 ->
								get_skyrush_scene_info(Status, Scene#ets_scene.name,Scene#ets_scene.x, Scene#ets_scene.y);
							_Other ->
								{false, 0, 0, 0, <<"场景不存在!">>, 0, []}
						end
				end
				end,
			case Result of
				{false, _, _, _, Msg, _, _} ->
					{ok, BinData} = pt_12:write(12005, [0, 0, 0, Msg, 0, 0, 0, 0]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					{0, Status};
				{true, NewSceneId, _X, _Y, Name, SceneResId, Dungeon_times, Dungeon_maxtimes, Status1} ->
					%%告诉原场景的玩家你已经离开
					pp_scene:handle(12004, Status, Status#player.scene),
					Num = util:rand(1, 2),
					{X, Y} = lists:nth(Num, ?GUILD_SKYRUSH_COORD), %%随机产生一对坐标
%% 					io:format("Num:~p,,X,Y:[~p,~p]\n", [Num, X, Y]),
					{ok, BinData} = pt_12:write(12005, 
												[NewSceneId, X, Y, Name, SceneResId, Dungeon_times, Dungeon_maxtimes, 100]),%%空岛进入，标注为10
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					put(change_scene_xy , [X, Y]),%%做坐标记录

					
					Status2 = Status1#player{
						scene = NewSceneId, 
						x = X, 
						y = Y, 
						pk_mode = 3,
						other = Status1#player.other#player_other{leader = 100}
					},
					%%更新玩家新坐标和模式
					ValueList = [{scene,NewSceneId},{x,X},{y,Y}, {pk_mode, 3}],
					WhereList = [{id, Status1#player.id}],
					db_agent:mm_update_player_info(ValueList, WhereList),
					%%修改为氏族模式
					{ok, PkModeBinData} = pt_13:write(13012, [1, 3]),
					lib_send:send_to_sid(Status2#player.other#player_other.pid_send, PkModeBinData),
					
%% 					io:format("return the result~~NewSceneId:~p, X:~p, Y:~p, Name:~p, SceneResId:~p\n", [NewSceneId, X, Y, Name, SceneResId]),
					{1, Status2}
			end
	end;
		false ->
			{4, Status}
	end.

%% -----------------------------------------------------------------
%% 39007 战场信息
%% -----------------------------------------------------------------
get_sky_info(Status) ->
	#player{id = PlayerId,
			nickname = PlayerName,
			guild_id = GuildId,
			other = Other} = Status,
	#player_other{pid_send = PidSend,
				  pid_scene = PidScene} = Other,
	gen_server:cast(PidScene, {'GET_SKYRUSH_INFO', PlayerId, PlayerName, GuildId, PidSend}).
player_goto_sky(PlayerId, PlayerName, GuildId) ->
	case ets_get_guild_mem_feats(PlayerId) of
		[] ->
			InsertEts = #mem_feats_elem{player_id = PlayerId,	
										player_name = PlayerName,
										guild_id = GuildId},
			ets_update_guild_mem_feats(InsertEts);
		_ ->
			skip
	end.
			
%% -----------------------------------------------------------------
%% 39011 交战旗或魔核
%% -----------------------------------------------------------------
submit_feats(PidSend, Point, X, Y, FeatsType, PlayerId, PlayerName, GuildId, Color, State) ->
	PR = check_point_ok(Point, FeatsType, Color, X, Y, GuildId, PlayerId, State),
%% 	io:format("PR:~p\n", [PR]),
	case PR of
		{false, Res} ->%%有乱发包的嫌疑
			{Res, State};
		false ->
			{0, State};
		true ->
			 {GFeat, MFeat, NewStats} = get_submit_feats(Point, FeatsType, Color, State, PlayerId),
			 case ets_get_guild_feats(GuildId) of
				 [] ->
					 skip;
				 [GFeatsEts|_G] ->
					 NGFeat = GFeatsEts#g_feats_elem.guild_feats +GFeat,
					 NGFeatsEts = GFeatsEts#g_feats_elem{guild_feats = NGFeat},
					 ets_update_guild_feats(NGFeatsEts),
					 %%全场景的局部更新
					 ListUpdateG = [{0, NGFeat, GFeatsEts#g_feats_elem.guild_name}],
					 {ok, Data39007G} = pt_39:write(39007, [1, ListUpdateG]),
					 spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39007G) end)
			 end,
			 case ets_get_guild_mem_feats(PlayerId) of
				 [] ->
					 skip;
				 [MemFeatsEts|_M] ->
					 NMFeat = MemFeatsEts#mem_feats_elem.feats + MFeat,
					 case FeatsType of
						 0 ->%%旗
							 ParamGet = [PidSend, Color],
							 lib_skyrush:send_skyrush_tips(2, ParamGet),
							 Flags = MemFeatsEts#mem_feats_elem.get_flags + 1,
							 NMemFeatsEts = MemFeatsEts#mem_feats_elem{get_flags = Flags,
																	   feats = NMFeat};
						 1 ->%%魔核
							 ParamGet = [PidSend, Color],
							 lib_skyrush:send_skyrush_tips(3, ParamGet),
							 Nuts = MemFeatsEts#mem_feats_elem.magic_nut + 1,
							 NMemFeatsEts = MemFeatsEts#mem_feats_elem{magic_nut = Nuts,
																	   feats = NMFeat}
					 end,
					 ets_update_guild_mem_feats(NMemFeatsEts),
					 %%全场景的局部更新
					 ListUpdateM = [{1, NMFeat, PlayerName}],
					 {ok, Data39007M} = pt_39:write(39007, [1, ListUpdateM]),
					 spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39007M) end)
			 end,
			 Param = [PidSend, GFeat, MFeat],
			 lib_skyrush:send_skyrush_tips(1, Param),
			 {1, NewStats}
	end.
			 

%% -----------------------------------------------------------------
%% 39012 拾取战旗
%% -----------------------------------------------------------------	
pickup_fn(X, Y, PlayerId, State) ->
%% 	io:format("drop_flags:~p\n", [State#skyrush.drop_flags]),
	IsExist = lists:keyfind({X, Y}, #df_elem.coord, State#skyrush.drop_flags),
	case IsExist of
		false ->
			{4, 0, State};
		_ ->
			NewList = lists:keydelete({X, Y}, #df_elem.coord, State#skyrush.drop_flags),
			Type = IsExist#df_elem.type,
			StateF = update_flags_data(PlayerId, Type, State),
			NewState = StateF#skyrush{drop_flags = NewList},
				%%向客户端发送魔核情况,场景区域更新
%% 			PlayerNutType = Type + 7,%%保存在玩家的player_other.carry_mark中，以8,9,10,11表示旗
%% 			{ok, Data39010} = pt_39:write(39010, [PlayerId, 0, Type]),
%% 			spawn(fun() -> mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID, X, Y, Data39010) end),
			{1, Type, NewState}
	end.
			
			
%% -----------------------------------------------------------------
%% 39009 结束神战
%% -----------------------------------------------------------------
handle_skyrush_end(_State) ->
	Now = util:unixtime(),
	handle_skyrush_gmfeats(Now).

send_outsky() ->
	MFeats = ets:tab2list(?MEM_FEATS_ELEM),
	lists:foreach(fun(Elem) ->
						  PlayerId = Elem#mem_feats_elem.player_id,
						  case lib_player:get_player_pid(PlayerId) of
							  [] ->%%已经不在线了
								  skip;
							  Pid ->
								  gen_server:cast(Pid, {'SEND_OUT_OF_SKYRUSH'})
						  end
				  end, MFeats).
%%
%% API Functions
%%
%%提示tips发送
send_skyrush_tips(Type, Param) ->
	case Type of
		1 ->
			[PidSend, GFeat, MFeat] = Param,
			Msg = io_lib:format("获得<font color='#FEDB4F'>~p</font>氏族战功，<font color='#FEDB4F'>~p</font>个人功勋",[GFeat, MFeat]),
			{ok, BinData} = pt_39:write(39000, [3, Msg]),
			lib_send:send_to_sid(PidSend, BinData);
		2 ->
			[PidSend, Color] = Param,
			{ColorStr, ColorType} = color_num_to_name(Color),
			Msg = io_lib:format("提交[<font color='~s'>~s</font>]色战旗",[ColorStr, ColorType]),
			{ok, BinData} = pt_39:write(39000, [1, Msg]),
			lib_send:send_to_sid(PidSend, BinData);
		3 ->
			[PidSend, Color] = Param,
			{ColorStr, ColorType} = color_num_to_name(Color),
			Msg = io_lib:format("提交[<font color='~s'>~s</font>]色魔核",[ColorStr, ColorType]),
			{ok, BinData} = pt_39:write(39000, [1, Msg]),
			lib_send:send_to_sid(PidSend, BinData);
		4 ->%%主动捡取的战旗
			[Pid_send, Color] = Param,
			{ColorStr, ColorType} = color_num_to_name(Color),
			Msg = io_lib:format("获得[<font color='~s'>~s</font>]色战旗，请前往据点提交",[ColorStr, ColorType]),
			{ok, BinData} = pt_39:write(39000, [3, Msg]),
			lib_send:send_to_sid(Pid_send, BinData);
		5 ->%%主动捡取的魔核
			[Pid_send, Color] = Param,
			{ColorStr, ColorType} = color_num_to_name(Color),
			Msg = io_lib:format("获得[<font color='~s'>~s</font>]色魔核，请前往据点提交",[ColorStr, ColorType]),
			{ok, BinData} = pt_39:write(39000, [3, Msg]),
			lib_send:send_to_sid(Pid_send, BinData);
		6 ->%%失去战旗
			[Pid_send, Color] = Param,
			{ColorStr, ColorType} = color_num_to_name(Color),
			Msg = io_lib:format("失去[<font color='~s'>~s</font>]色战旗",[ColorStr, ColorType]),
			{ok, BinData} = pt_39:write(39000, [1, Msg]),
			lib_send:send_to_sid(Pid_send, BinData);
		7 ->%%失去魔核
			[Pid_send, Color] = Param,
			{ColorStr, ColorType} = color_num_to_name(Color),
			Msg = io_lib:format("失去[<font color='~s'>~s</font>]色魔核",[ColorStr, ColorType]),
			{ok, BinData} = pt_39:write(39000, [1, Msg]),
			lib_send:send_to_sid(Pid_send, BinData);
		8 ->%%杀人获得功勋
			[PlayerId] = Param,
			Msg = io_lib:format("获得<font color='#FEDB4F'>~p</font>个人功勋",[?KILL_GET_FEATS]),
			{ok, BinData} = pt_39:write(39000, [1, Msg]),
			lib_send:send_to_uid(PlayerId, BinData);
			
		_ ->
			skip
	end.

%% -----------------------------------------------------------------
%% 39025 氏族战奖励
%% -----------------------------------------------------------------
get_sky_award(PlayerId, GuildId) ->
	case lib_guild_inner:get_guild_member_by_guildandplayer_id(GuildId, PlayerId) of
		[] ->
			[0, 0, 0];
		Member ->
			NowTime = util:unixtime(),
			if
				Member#ets_guild_member.gr =:= 0 andalso NowTime =< (Member#ets_guild_member.f_uptime + ?AWARD_TIMEOUT) andalso Member#ets_guild_member.f_uptime =/= 0->
					#ets_guild_member{lv = Lv,
									  kill_foe = KillFoc, 
									  get_flags = Flags,   
									  magic_nut = Nuts} = Member,
					{Exp, Spirit} = get_skyrush_spirexp(Lv, KillFoc, Flags, Nuts),
					ValueList = [{gr,1}],
					FieldList = [{player_id, PlayerId}],
					db_agent:update_sky_guild(guild_member, ValueList, FieldList),
					NewGMember = Member#ets_guild_member{gr = 1},
					lib_guild_inner:update_guild_member(NewGMember),
%% 					io:format("Exp:~p, Spirit:~p\n", [Exp, Spirit]),
					[1, Exp, Spirit];
				Member#ets_guild_member.gr =:= 1 andalso NowTime =< (Member#ets_guild_member.f_uptime + ?AWARD_TIMEOUT) ->%%领过了
					[2, 0, 0];
				Member#ets_guild_member.gr =:= 0 andalso NowTime > (Member#ets_guild_member.f_uptime + ?AWARD_TIMEOUT) andalso Member#ets_guild_member.f_uptime =/= 0->%%过期了
					[5, 0, 0];
				true ->
					[4, 0, 0]
			end
	end.
					
					
					
	
%%系统公告
send_skyrush_notice(Type, Param) ->
	case Type of
		1 ->
			Msg = io_lib:format("<font color='#FEDB4F'>神岛空战</font>将于<font color='#FEDB4F'>5</font>分钟后开始，请各位勇士做好准备!",[]),
			lib_chat:broadcast_sys_msg(2, Msg);
		2 ->
			Msg = io_lib:format("<font color='#FEDB4F'>神岛空战</font>已经开始，请前往氏族领地的<font color='#FFFFFF'>[神岛使者]</font>处进入神岛",[]),
			lib_chat:broadcast_sys_msg(2, Msg);
		3->
			[BossName, PlayerId, PlayerName, Career, Sex] = Param,
			Realm = 
				case db_agent:get_realm_by_id(PlayerId) of
					null -> 100;
					R ->
						R
				end,
			NameColor = data_agent:get_realm_color(Realm),
			Msg = io_lib:format("谈笑间，<font color='#FFFFFF'>~s</font>已经被[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]击败",
								[BossName, PlayerId, PlayerName, Career, Sex, NameColor, PlayerName]),
			lib_chat:broadcast_sys_msg(2, Msg);
		4 ->
			Msg = io_lib:format("所有BOSS已经被击败，<font color='#FEDB4F'>彩旗据点</font>已经开启，可前往占领据点和提交战旗(魔核)！", []),
			lib_chat:broadcast_sys_msg(2, Msg);
		5 ->%%屏蔽高级据点，中级据点变成高级据点
%% 			[GuildName] = Param,
%% 			Msg = io_lib:format("中级据点已被<font color='#FEDB4F'>~s</font>氏族占领，氏族成员在该处提交战旗（魔核）可获得加成", [GuildName]),
%% 			lib_chat:broadcast_sys_msg(2, Msg);
			[GuildName] = Param,
			Msg = io_lib:format("高级据点已被<font color='#FEDB4F'>~s</font>氏族占领，氏族成员在该处提交战旗（魔核）可获得加成", [GuildName]),
			lib_chat:broadcast_sys_msg(2, Msg);
%% 		6 ->
%% 			[GuildName] = Param,
%% 			Msg = io_lib:format("高级据点已被<font color='#FEDB4F'>~s</font>氏族占领，氏族成员在该处提交战旗（魔核）可获得加成", [GuildName]),
%% 			lib_chat:broadcast_sys_msg(2, Msg);
		7 ->
			[BossName, PlayerId, PlayerName, Career, Sex] = Param,
			Realm = 
				case db_agent:get_realm_by_id(PlayerId) of
					null -> 100;
					R ->
						R
				end,
			NameColor = data_agent:get_realm_color(Realm),
			Msg = io_lib:format("谈笑间，<font color='#FFFFFF'>~s</font>已经被[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]击败，并掉落了<font color='#8800FF'>紫</font>色魔核",
								[BossName, PlayerId, PlayerName, Career, Sex, NameColor, PlayerName]),
			lib_chat:broadcast_sys_msg(2, Msg);
		8 ->
			[PlayerId, PlayerName, Career, Sex] = Param,
			Realm = 
				case db_agent:get_realm_by_id(PlayerId) of
					null -> 100;
					R ->
						R
				end,
			NameColor = data_agent:get_realm_color(Realm),
			Msg = io_lib:format("注意，[<a href='event:1,~p,~s,~p,~p'><font color='~s'><u>~s</u></font></a>]已经成功获取<font color='#8800FF'>紫</font>色战旗",
								[PlayerId, PlayerName, Career, Sex, NameColor, PlayerName]),
			lib_chat:broadcast_sys_msg(2, Msg);
		9 ->
			[GuildName] = Param,
			Msg = io_lib:format("经过一场惊心动魄的战斗，<font color='#FEDB4F'>~s</font>氏族全体成员浴血奋战，获得了本次氏族战最终胜利，<font color='#FFFFFF'>所有参与神岛空战的成员们</font>均可前往氏族领地的<font color='#FFFFFF'>[神岛使者]</font>处领取空战奖励",
								[GuildName]),
			lib_chat:broadcast_sys_msg(2, Msg);
		10 ->
			Msg = io_lib:format("<font color='#8800FF'>紫</font>色战旗已经刷新，请勇士们前往运送!", []),
			lib_chat:broadcast_sys_msg(2, Msg);
		11 ->
			Msg = io_lib:format("携带着大量魔核及空战礼包的<font color='#FFFFFF'>狼人、蛇人</font>已经刷新降临<font color='#FEDB4F'>神岛</font>，请速前往将其击败", []),
			lib_chat:broadcast_sys_msg(2, Msg);
		12 ->
			[DiePlayerId, DiePlayerName, DieCareer, DieSex,%%被击败的
			 WinPlayerId, WinPlayerName, WinCareer, WinSex] = Param,%%赢了的
			Msg = io_lib:format("[<a href='event:1,~p,~s,~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>]击败[<a href='event:1, ~p,~s,~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>]，获得了<font color='#8800FF'>紫</font>色魔核", 
								[WinPlayerId, WinPlayerName, WinCareer, WinSex, WinPlayerName,
								 DiePlayerId, DiePlayerName, DieCareer, DieSex, DiePlayerName]),
			lib_chat:broadcast_sys_msg(2, Msg);
		_ -> 
			skip
	end.
%%神岛空战初始化
start_skyrush(Type,NowSec) ->
	%% 配置表
	[WeekDate, SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = get_start_end_time(),
	case Type of
		0 ->%%没有启动
			%%是否要开氏族战
			Judge = lib_skyrush:tobe_opening_skyrush(WeekDate),
			case Judge =:= true of
				true ->
					NoticeSignUp = get_notice_sign_up_time(),
					case NowSec > NoticeSignUp andalso NowSec-NoticeSignUp=<10 of
						true->
							notice_to_sign_up();
						false->skip
					end,
					case NowSec > SKY_RUSH_START_TIME  andalso NowSec =< SKY_RUSH_END_TIME of
						true ->
							mod_skyrush:init_skyrush(),
							1;
						false ->
							0
					end;
				false ->
					0
			end;
		1 ->%%已经启动了
			case NowSec >= (SKY_RUSH_START_TIME - 600)  andalso NowSec =< (SKY_RUSH_END_TIME + 600) of
				true ->
					1;
				false ->
					0
			end
	end.
	
%%初始化氏族功勋数据
init_guild_feats() ->
%% 	MS = ets:fun2ms(fun(T) when T#ets_guild.sky_apply =:= 1 ->
%% 							T end),
	WhereList = [{sky_apply, 1}, {id, ">", 0}],
	GFeats = 
%% 		case get_guilds_by_etsms(MS) of%%改为从数据库里面直接导数据
		case db_agent:get_apply_skyrush_guilds(WhereList) of
			[] ->
				[];
			Guilds ->
				handle_guild_feats(Guilds, [])
		end,
	lists:foreach(fun ets_update_guild_feats/1, GFeats).
	
handle_guild_feats([], Result) ->
	Result;
handle_guild_feats([Guild|Guilds], Result) ->
	GFeats = #g_feats_elem{guild_id =Guild#ets_guild.id,
						   guild_name = Guild#ets_guild.name,
						   guild_feats = 0},
	handle_guild_feats(Guilds, [GFeats|Result]).
	
%%离开空岛判断
check_quit_skyscene(Status) ->
	if
		Status#player.scene =/= ?SKY_RUSH_SCENE_ID ->
			0;
		true ->
			1
	end.
			
is_skyrush_scene(Player) ->
	case Player#player.scene =:= ?SKY_RUSH_SCENE_ID of
		true ->
			%%产生种子
			{MegaSecs, Secs, MicroSecs} = now(),
			random:seed({MegaSecs, Secs, MicroSecs}),
			Num = random:uniform(4),
			{X, Y} = lists:nth(Num, ?GUILD_MANOR_COORD), %%随机产生一对坐标
			[500, X, Y];
		false ->
			false
	end.
is_get_skyrush_scene(SceneId) ->
	SceneId =:= ?SKY_RUSH_SCENE_ID.

%% 获取氏族成员的功勋
get_member_feats(GuildId, PlayerId) ->
	case lib_guild_inner:get_guild_member_by_guildandplayer_id(GuildId, PlayerId) of
		[] ->
			0;
		GuildMember ->
			GuildMember#ets_guild_member.feats_all
	end.
	
%%杀死boss怪
kill_sky_bossmon(Param) ->
	NutType = get_mon_nut_1(),
	[PidSend, PlayerPid, GuildId, PlayerId, _X, _Y, MonId, MonName, PlayerName, Career, Sex, CarryMark, State] = Param,
	{GFeats, MFeats, SendType} = get_boss_feats(MonId),
	case ets_get_guild_feats(GuildId) of
		[] ->
			skip;
		[GFeatsEts|_G] ->
			NewGFeats = GFeatsEts#g_feats_elem.guild_feats + GFeats,
			NGFeatsEts = GFeatsEts#g_feats_elem{guild_feats = NewGFeats},
			ets_update_guild_feats(NGFeatsEts),
			%%局部更新
			ListUpdateG = [{0,NewGFeats, GFeatsEts#g_feats_elem.guild_name}],
			{ok, Data39007G} = pt_39:write(39007, [1, ListUpdateG]),
			spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39007G) end)
%% 			io:format("the guild is ~p\n", [GFeatsEts]),
		end,
	case ets_get_guild_mem_feats(PlayerId) of
		[] ->
			skip;
		[MemFeatsEts|_M] ->
			NewMFeats = MemFeatsEts#mem_feats_elem.feats + MFeats,
			NMemFeatsEts = MemFeatsEts#mem_feats_elem{feats = NewMFeats},
			ets_update_guild_mem_feats(NMemFeatsEts),
			%%局部更新
			ListUpdateM = [{1, NewMFeats, PlayerName}],
			{ok, Data39007M} = pt_39:write(39007, [1, ListUpdateM]),
			spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39007M) end)
	end,
	%%广播
	NewParam = [MonName, PlayerId, PlayerName, Career, Sex],
%% 	send_skyrush_notice(3, NewParam),
	{ok, Data39005} = pt_39:write(39005, [SendType]),
	spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39005) end),
	%%向客户端发送魔核情况,场景区域更新
%% 	PlayerNutType = NutType + 11,%%保存在玩家的player_other.carry_mark中，以12,13,14,15表示魔核
%% 	{ok, Data39010} = pt_39:write(39010, [PlayerId, 1, NutType]),
%% %% 	spawn(fun() -> mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID, X, Y, Data39010) end),
%% 	spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39010) end),
%% 	gen_server:cast(PlayerPid, {'UPDATE_FEATS_MARK', PlayerNutType}),
	%%刷新Tips
	ParamTips = [PidSend, GFeats, MFeats],
	lib_skyrush:send_skyrush_tips(1, ParamTips),
	kill_update_state(1, MonId, State, NutType, PlayerId, CarryMark, PlayerPid, NewParam).

%%杀死小怪
kill_sky_littlemon(Param) ->
	[PlayerId, _X, _Y, PlayerPid, MonName, PlayerName, Career, Sex, CarryMark, State] = Param,
	NutType = get_mon_nut_2(),
	case NutType of
		0 ->
			State;
		_ ->
			%%向客户端发送魔核情况,场景区域更新
%% 			PlayerNutType = NutType + 11,%%保存在玩家的player_other.carry_mark中，以12,13,14,15表示魔核
%% 			{ok, Data39010} = pt_39:write(39010, [PlayerId, 1, NutType]),
%% %% 			spawn(fun() -> mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID, X, Y, Data39010) end),
%% 			spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39010) end),
%% 			gen_server:cast(PlayerPid, {'UPDATE_FEATS_MARK', PlayerNutType}),
			NewParam = [MonName, PlayerId, PlayerName, Career, Sex],
			kill_update_state(0, 0, State, NutType, PlayerId, CarryMark, PlayerPid, NewParam)
	end.
	
	
	
init_little_mon(MonList) ->
%% 	lib_scene:load_mon(?SKYRUSH_MON_LIST, ?SKY_RUSH_SCENE_ID).
	lib_scene:load_mon_retpid(MonList, {0, []}, ?SKY_RUSH_SCENE_ID).
%%ets操作	
ets_get_guild_feats(GuildId) ->
	ets:lookup(?G_FEATS_ELEM, GuildId).
ets_get_guild_mem_feats(PlayerId) ->
	ets:lookup(?MEM_FEATS_ELEM, PlayerId).
ets_update_guild_feats(NGFeatsEts) ->
	ets:insert(?G_FEATS_ELEM, NGFeatsEts).
ets_update_guild_mem_feats(NMemFeatsEts) ->
	ets:insert(?MEM_FEATS_ELEM, NMemFeatsEts).
count_jion_num(GuildId,MFeats) ->
	lists:foldl(fun(Elem, AccIn) ->
						MGuildId = Elem#mem_feats_elem.guild_id,
%% 						?DEBUG("count the num:~p", [AccIn]),
						case MGuildId =:= GuildId of
							true ->
								AccIn+1;
							false ->
								AccIn
						end
				end, 0, MFeats).

%%获取整个参战的氏族列表Id
ets_get_sky_gids() ->
	List = ets:tab2list(?G_FEATS_ELEM),
	lists:map(fun(Elem) ->
					  Elem#g_feats_elem.guild_id
			  end, List).
 	
%%刷新旗
reflesh_flags() ->
	List = [{1, 1}, {2, 2}, {3, 3}],
	lib_skyrush:reflesh_flag(List).

%%局部的刷新旗
reflesh_flag(List) ->
	lists:foreach(fun(ELem) ->
						  {Area, Color} = ELem,
						  [X, Y] = get_flags_coord(Area),
						  %%全场景通报旗开启
						  {ok, Data39014} = pt_39:write(39014, [Color, X, Y]),
						  spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39014) end)
				  end, List).
%%旗的坐标
get_flags_coord(Area) ->
	case Area of
		1 ->%白，紫
			[50, 56];
		2 ->%%绿
			[15, 30];
		3 ->%%蓝
			[64, 123]
	end.
%%获取据点坐标
get_point_coord(Type) ->
	case Type of
		1 ->%%中级据点
		  [5, 73];
%% 		2 ->%%高级据点
%% 			[58, 161];
		3 ->%%公共据点
		  [38, 156]
	end.

%%玩家下线，数据更新
player_logout_sky(Status) ->
	#player{id = PlayerId, carry_mark = CarryMark} = Status,
	case CarryMark >= 8 andalso CarryMark =< 17 of
		true ->%%头顶有魔核或者旗
			gen_server:cast(Status#player.other#player_other.pid_scene, {'PLAYER_LOGOUT_SKY', CarryMark, PlayerId});
		false ->
			skip
	end.

drop_fns_for_die(PidScene, PlayerId, Param2, CarryMark, X, Y, Pid, AerId) ->
	if
		CarryMark >= 8 andalso CarryMark =< 11 ->%%旗
			Type = 0,
			Color = CarryMark - 7,
			gen_server:cast(PidScene, {'DROP_FNS_FOR_DIE', PlayerId, Param2, Type, Color, X, Y, Pid, AerId});
		 CarryMark >= 12 andalso CarryMark =< 15 ->%%魔核
			Type = 1,
			Color = CarryMark -11,
			gen_server:cast(PidScene, {'DROP_FNS_FOR_DIE', PlayerId, Param2, Type, Color, X, Y, Pid, AerId});
%% 		CarryMark =:= 16 orelse CarryMark =:= 17 ->
%% 			Type = 3,
%% 			Color = CarryMark - 15,
%% 			gen_server:cast(PidScene, {'DROP_FNS_FOR_DIE', PlayerId, Type, Color, X, Y, Pid, AerId});
		 true ->
			 skip
	end.
	
%%因为战斗取消取旗
discard_flags_battle(Type, PlayerA0, PlayerB0) ->
	case Type of
		1 ->%%打人%%被打
			[ABattleType, PlayerA] = PlayerA0,
			[BBattleType, PlayerB] = PlayerB0,
			if%%人打人
				ABattleType =:= 2 andalso BBattleType =:= 2 
				  andalso (PlayerA#player.carry_mark =:= 16 orelse PlayerA#player.carry_mark =:= 17) 
				  andalso (PlayerB#player.carry_mark =/= 16 andalso PlayerB#player.carry_mark =/= 17) ->
					APidSend = PlayerA#player.other#player_other.pid_send,
					AId = PlayerA#player.id,
					TypeA = PlayerA#player.carry_mark,
					AX = PlayerA#player.x,
					AY = PlayerA#player.y,
					gen_server:cast(PlayerA#player.other#player_other.pid_scene, {'DISCARD_FLAGS_BATTLE', 
																		  {TypeA, APidSend, AId, AX, AY},
																		  {0, {}, 0, 0, 0}}),
					{PlayerA#player{carry_mark = 0}, PlayerB};
				ABattleType =:= 2 andalso BBattleType =:= 2 
				  andalso (PlayerA#player.carry_mark =/= 16 andalso PlayerA#player.carry_mark =/= 17) 
				  andalso (PlayerB#player.carry_mark =:= 16 orelse PlayerB#player.carry_mark =:= 17) ->
					BPidSend = PlayerB#player.other#player_other.pid_send,
					BId = PlayerB#player.id,
					TypeB = PlayerB#player.carry_mark,
					BX = PlayerB#player.x,
					BY = PlayerB#player.y,
					gen_server:cast(PlayerA#player.other#player_other.pid_scene, {'DISCARD_FLAGS_BATTLE',
																				  {0, {}, 0, 0, 0},
																				  {TypeB, BPidSend, BId, BX, BY}}),
					{PlayerA, PlayerB#player{carry_mark = 0}};
				ABattleType =:= 2 andalso BBattleType =:= 2 
				  andalso (PlayerA#player.carry_mark =:= 16 orelse PlayerA#player.carry_mark =:= 17) 
				  andalso (PlayerB#player.carry_mark =:= 16 orelse PlayerB#player.carry_mark =:= 17) ->
					APidSend = PlayerA#player.other#player_other.pid_send,
					AId = PlayerA#player.id,
					TypeA = PlayerA#player.carry_mark,
					AX = PlayerA#player.x,
					AY = PlayerA#player.y,
					BPidSend = PlayerB#player.other#player_other.pid_send,
					BId = PlayerB#player.id,
					TypeB = PlayerB#player.carry_mark,
					BX = PlayerB#player.x,
					BY = PlayerB#player.y,
					gen_server:cast(PlayerA#player.other#player_other.pid_scene, {'DISCARD_FLAGS_BATTLE', 
																		  {TypeA, APidSend, AId, AX, AY},
																		  {TypeB, BPidSend, BId, BX, BY}}),
					{PlayerA#player{carry_mark = 0}, PlayerB#player{carry_mark = 0}};
				%%怪打人
				ABattleType =:= 1 andalso BBattleType =:= 2 
				  andalso (PlayerB#player.carry_mark =:= 16 orelse PlayerB#player.carry_mark =:= 17) ->
					BPidSend = PlayerB#player.other#player_other.pid_send,
					BId = PlayerB#player.id,
					TypeB = PlayerB#player.carry_mark,
					BX = PlayerB#player.x,
					BY = PlayerB#player.y,
					gen_server:cast(PlayerB#player.other#player_other.pid_scene, {'DISCARD_FLAGS_BATTLE',
																				  {0, {}, 0, 0, 0},
																				  {TypeB, BPidSend, BId, BX, BY}}),
					{PlayerA, PlayerB#player{carry_mark = 0}};
				%%人打怪
				ABattleType =:= 2 andalso BBattleType =:= 1 
				  andalso (PlayerA#player.carry_mark =:= 16 orelse PlayerA#player.carry_mark =:= 17) ->
					APidSend = PlayerA#player.other#player_other.pid_send,
					AId = PlayerA#player.id,
					TypeA = PlayerA#player.carry_mark,
					AX = PlayerA#player.x,
					AY = PlayerA#player.y,
					gen_server:cast(PlayerA#player.other#player_other.pid_scene, {'DISCARD_FLAGS_BATTLE', 
																		  {TypeA, APidSend, AId, AX, AY},
																		  {0, {}, 0, 0, 0}}),
					{PlayerA#player{carry_mark = 0}, PlayerB};
				true ->
					{PlayerA, PlayerB}
			end;
		3 ->%%走路取消的
			case PlayerA0#player.carry_mark =:= 16 orelse PlayerA0#player.carry_mark =:= 17 of
				true ->
%% 					io:format("cancel for walk:~p\n", [PlayerA#player.carry_mark]),
					gen_server:cast(PlayerA0#player.other#player_other.pid_scene, {'DISCARD_FLAGS_BATTLE', 
																		  {PlayerA0#player.carry_mark, PlayerA0#player.other#player_other.pid_send, 
																		   PlayerA0#player.id, PlayerA0#player.x, PlayerA0#player.y},
																		  {0, {}, 0, 0, 0}}),
					NewPlayerA = PlayerA0#player{carry_mark = 0},
					mod_player:save_online_diff(PlayerA0, NewPlayerA),	
					mod_player:save_player_table(NewPlayerA),
					{NewPlayerA, NewPlayerA};
				false ->
%% 					io:format("no action for cancel\n"),
					{PlayerA0, PlayerA0}
			end
	end.
			
			
%%通知玩家carry_mark状态的改变
update_player_flags_state(PlayerId, Color) ->
	case lib_player:get_player_pid(PlayerId) of
		[] ->
			skip;
		Pid ->
			gen_server:cast(Pid, {'UPDATE_FEATS_MARK', Color + 7, 1})
	end.
	
%%更新杀敌数和死亡数
update_skyrush_killdie(PidScene, PlayerId, AerId) ->
	gen_server:cast(PidScene, {'UPDATE_SKYRUSH_KILLDIE', PlayerId, AerId}).
sky_die_reset(PidScene, PlayerId, AerId, Type) ->
	gen_server:cast(PidScene, {'SKY_DIE_RESET', PlayerId, AerId, Type}).

change_fns_player(PlayerId, Param2, Type, Color, X, Y, Pid, AerId, State) ->
	NewState = 
	case Type of
		0 ->%旗
			case Color of
				1 ->
					#skyrush{white_flags = {Num, Flags},
							 drop_flags = DropFlags} = State,
					case lists:keyfind(PlayerId, #fns_elem.player_id, Flags) of
						false ->
							State;
						_Tuple ->
							NewFlags = lists:keydelete(PlayerId, #fns_elem.player_id, Flags),
							NewDropFlags = [#df_elem{coord = {X,Y},
													 type = Color}|DropFlags],
							%%广播掉落
							{ok, Data39013} = pt_39:write(39013, [Color, X, Y]),
							spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39013) end),
							%%通知所有玩家
							{ok,BinData2} = pt_12:write(12041, [PlayerId, 0]),
							mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID,X, Y, BinData2),
							State#skyrush{white_flags = {Num, NewFlags},
										  drop_flags = NewDropFlags}
					end;
				2 ->
					#skyrush{green_flags = {Num, Flags},
							 drop_flags = DropFlags} = State,
					case lists:keyfind(PlayerId, #fns_elem.player_id, Flags) of
						false ->
							State;
						_Tuple ->
							NewFlags = lists:keydelete(PlayerId, #fns_elem.player_id, Flags),
							NewDropFlags = [#df_elem{coord = {X,Y},
													 type = Color}|DropFlags],
							%%广播掉落
							{ok, Data39013} = pt_39:write(39013, [Color, X, Y]),
							spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39013) end),
							%%通知所有玩家
							{ok,BinData2} = pt_12:write(12041, [PlayerId, 0]),
							mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID,X, Y, BinData2),
							State#skyrush{green_flags = {Num, NewFlags},
										  drop_flags = NewDropFlags}
					end;
				3 ->
					#skyrush{blue_flags = {Num, Flags},
							 drop_flags = DropFlags} = State,
					case lists:keyfind(PlayerId, #fns_elem.player_id, Flags) of
						false ->
							State;
						_Tuple ->
							NewFlags = lists:keydelete(PlayerId, #fns_elem.player_id, Flags),
							NewDropFlags = [#df_elem{coord = {X,Y},
													 type = Color}|DropFlags],
							%%广播掉落
							{ok, Data39013} = pt_39:write(39013, [Color, X, Y]),
							spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39013) end),
							%%通知所有玩家
							{ok,BinData2} = pt_12:write(12041, [PlayerId, 0]),
							mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID,X, Y, BinData2),
							State#skyrush{blue_flags = {Num, NewFlags},
										  drop_flags = NewDropFlags}
					end;
				4 ->
					#skyrush{purple_flags = {Num, Flags},
							 drop_flags = DropFlags} = State,
					case lists:keyfind(PlayerId, #fns_elem.player_id, Flags) of
						false ->
							State;
						_Tuple ->
							NewFlags = lists:keydelete(PlayerId, #fns_elem.player_id, Flags),
							NewDropFlags = [#df_elem{coord = {X,Y},
													 type = Color}|DropFlags],
							%%广播掉落
							{ok, Data39013} = pt_39:write(39013, [Color, X, Y]),
							spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39013) end),
							%%通知所有玩家
							{ok,BinData2} = pt_12:write(12041, [PlayerId, 0]),
							mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID,X, Y, BinData2),
							State#skyrush{purple_flags = {Num, NewFlags},
										  drop_flags = NewDropFlags}
					end
			end;
		1 ->%%魔核
			case Color of
				1 ->
					#skyrush{white_nuts = {Num, Flags}} = State,
					case lists:keyfind(PlayerId, #fns_elem.player_id, Flags) of
						false ->
							State;
						_Tuple ->
							NewFlags0 = lists:keydelete(PlayerId, #fns_elem.player_id, Flags),
							case AerId =:= 0 of
								true ->%%怪物打死的
%% 									io:format("mon kill\n"),
									NewNum = Num -1,
									NewFlags = NewFlags0;
								false ->
									PlayerNutType = Color + 11,
									%%通知对应玩家更新魔核状态
									case catch(gen_server:call(Pid, {'UPDATE_FEATS_MARK_CALL', PlayerNutType, Param2, 0})) of
										changed ->
											NewNum = Num,
											NewFlags = [#fns_elem{player_id = AerId,
																  type = Color}|NewFlags0],
											%%通知所有玩家
											{ok,BinData2} = pt_12:write(12041, [PlayerId, 0]),
											mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID,X, Y, BinData2);
										unchanged ->
											%%通知所有玩家
											{ok,BinData2} = pt_12:write(12041, [PlayerId, 0]),
											mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID,X, Y, BinData2),
											NewNum = Num -1,
											NewFlags = NewFlags0;
										_Error ->
											%%通知所有玩家
											{ok,BinData2} = pt_12:write(12041, [PlayerId, 0]),
											mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID,X, Y, BinData2),
											NewNum = Num -1,
											NewFlags = NewFlags0
									end
							end,
							State#skyrush{white_nuts = {NewNum, NewFlags}}
					end;
				2 ->
					#skyrush{green_nuts = {Num, Flags}} = State,
					case lists:keyfind(PlayerId, #fns_elem.player_id, Flags) of
						false ->
							State;
						_Tuple ->
							NewFlags0= lists:keydelete(PlayerId, #fns_elem.player_id, Flags),
							case AerId =:= 0 of
								true ->%%怪物打死的
%% 									io:format("mon kill\n"),
									NewNum = Num -1,
									NewFlags = NewFlags0;
								false ->
									PlayerNutType = Color + 11,
									%%通知对应玩家更新魔核状态
									case catch(gen_server:call(Pid, {'UPDATE_FEATS_MARK_CALL', PlayerNutType, Param2, 0})) of
										changed ->
											NewNum = Num,
											NewFlags = [#fns_elem{player_id = AerId,
																  type = Color}|NewFlags0],
											%%通知所有玩家
											{ok,BinData2} = pt_12:write(12041, [PlayerId, 0]),
											mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID,X, Y, BinData2);
										unchanged ->
											%%通知所有玩家
											{ok,BinData2} = pt_12:write(12041, [PlayerId, 0]),
											mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID,X, Y, BinData2),
											NewNum = Num -1,
											NewFlags = NewFlags0;
										_Error ->
											%%通知所有玩家
											{ok,BinData2} = pt_12:write(12041, [PlayerId, 0]),
											mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID,X, Y, BinData2),
											NewNum = Num -1,
											NewFlags = NewFlags0
									end
							end,
							State#skyrush{green_nuts = {NewNum, NewFlags}}
					end;
				3 ->
					#skyrush{blue_nuts = {Num, Flags}} = State,
					case lists:keyfind(PlayerId, #fns_elem.player_id, Flags) of
						false ->
							State;
						_Tuple ->
							NewFlags0 = lists:keydelete(PlayerId, #fns_elem.player_id, Flags),
							case AerId =:= 0 of
								true ->%%怪物打死的
%% 									io:format("mon kill\n"),
									NewNum = Num -1,
									NewFlags = NewFlags0;
								false ->
									PlayerNutType = Color + 11,
									%%通知对应玩家更新魔核状态
									case catch(gen_server:call(Pid, {'UPDATE_FEATS_MARK_CALL', PlayerNutType, Param2, 0})) of
										changed ->
											NewNum = Num,
											NewFlags = [#fns_elem{player_id = AerId,
																  type = Color}|NewFlags0],
											%%通知所有玩家
											{ok,BinData2} = pt_12:write(12041, [PlayerId, 0]),
											mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID,X, Y, BinData2);
										unchanged ->
											%%通知所有玩家
											{ok,BinData2} = pt_12:write(12041, [PlayerId, 0]),
											mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID,X, Y, BinData2),
											NewNum = Num -1,
											NewFlags = NewFlags0;
										_Error ->
											%%通知所有玩家
											{ok,BinData2} = pt_12:write(12041, [PlayerId, 0]),
											mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID,X, Y, BinData2),
											NewNum = Num -1,
											NewFlags = NewFlags0
									end
							end,
							State#skyrush{blue_nuts = {NewNum, NewFlags}}
					end;
				4 ->
					#skyrush{purple_nuts = {Num, Flags}} = State,
					case lists:keyfind(PlayerId, #fns_elem.player_id, Flags) of
						false ->
							State;
						_Tuple ->
							NewFlags0 = lists:keydelete(PlayerId, #fns_elem.player_id, Flags),
							case AerId =:= 0 of
								true ->%%怪物打死的
%% 									io:format("mon kill\n"),
									NewNum = Num -1,
									NewFlags = NewFlags0;
								false ->
									PlayerNutType = Color + 11,
									%%通知对应玩家更新魔核状态
									case catch(gen_server:call(Pid, {'UPDATE_FEATS_MARK_CALL', PlayerNutType, Param2, 1})) of
										changed ->
											NewNum = Num,
											NewFlags = [#fns_elem{player_id = AerId,
																  type = Color}|NewFlags0],
											%%通知所有玩家
											{ok,BinData2} = pt_12:write(12041, [PlayerId, 0]),
											mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID,X, Y, BinData2);
										unchanged ->
											%%通知所有玩家
											{ok,BinData2} = pt_12:write(12041, [PlayerId, 0]),
											mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID,X, Y, BinData2),
											NewNum = Num -1,
											NewFlags = NewFlags0;
										_Error ->
											%%通知所有玩家
											{ok,BinData2} = pt_12:write(12041, [PlayerId, 0]),
											mod_scene_agent:send_to_area_scene(?SKY_RUSH_SCENE_ID,X, Y, BinData2),
											NewNum = Num -1,
											NewFlags = NewFlags0
									end
							end,
							State#skyrush{purple_nuts = {NewNum, NewFlags}}
					end
			end
	end,
	add_kill_die_num(PlayerId, AerId),
	NewState.
			
						
%%
%% Local Functions
%%
kill_update_state(Type, MonId, State, NutType, PlayerId, CarryMark, PlayerPid, NewParam) ->
	FElem = #fns_elem{player_id = PlayerId,
					  type = NutType},
	case Type of
		1 ->%%boss
			{BossNum, BossInfo} = State#skyrush.boss_num,
			NewBossInfo = lists:keyreplace(MonId, 1, BossInfo, {MonId, 0}),
			NewState =State#skyrush{boss_num = {BossNum - 1, NewBossInfo}},
			case CarryMark >= 8 andalso CarryMark =< 15 of
				false ->
					case NutType of
						1 ->%%白
							{Num, Nuts} =  State#skyrush.white_nuts,
							%%保存在玩家的player_other.carry_mark中，以12,13,14,15表示魔核
							gen_server:cast(PlayerPid, {'UPDATE_FEATS_MARK', NutType+11, 0}),
							send_skyrush_notice(3, NewParam),
							NewState#skyrush{white_nuts = {Num+1, [FElem|Nuts]}};
						2 ->%%绿
							{Num, Nuts} =  State#skyrush.green_nuts,
							%%保存在玩家的player_other.carry_mark中，以12,13,14,15表示魔核
							gen_server:cast(PlayerPid, {'UPDATE_FEATS_MARK', NutType+11, 0}),
							send_skyrush_notice(3, NewParam),
							NewState#skyrush{green_nuts = {Num+1, [FElem|Nuts]}};
						3 ->%%蓝
							{Num, Nuts} =  State#skyrush.blue_nuts,
							%%保存在玩家的player_other.carry_mark中，以12,13,14,15表示魔核
							gen_server:cast(PlayerPid, {'UPDATE_FEATS_MARK', NutType+11, 0}),
							send_skyrush_notice(3, NewParam),
							NewState#skyrush{blue_nuts = {Num+1, [FElem|Nuts]}};
						4 ->%%紫
							{Num, Nuts} =  State#skyrush.purple_nuts,
							%%保存在玩家的player_other.carry_mark中，以12,13,14,15表示魔核
							gen_server:cast(PlayerPid, {'UPDATE_FEATS_MARK', NutType+11, 0}),
							send_skyrush_notice(7, NewParam),
							NewState#skyrush{purple_nuts = {Num+1,[FElem|Nuts]}}
					end;
				true ->
					send_skyrush_notice(3, NewParam),
					NewState
			end;
		0 ->%%小怪
			case CarryMark >= 8 andalso CarryMark =< 15 of
				false ->
					case NutType of
						1 ->%%白
							{Num, Nuts} =  State#skyrush.white_nuts,
							%%保存在玩家的player_other.carry_mark中，以12,13,14,15表示魔核
							gen_server:cast(PlayerPid, {'UPDATE_FEATS_MARK', NutType+11, 0}),
							State#skyrush{white_nuts = {Num+1, [FElem|Nuts]}};
						2 ->%%绿
							{Num, Nuts} =  State#skyrush.green_nuts,
							%%保存在玩家的player_other.carry_mark中，以12,13,14,15表示魔核
							gen_server:cast(PlayerPid, {'UPDATE_FEATS_MARK', NutType+11, 0}),
							State#skyrush{green_nuts = {Num+1, [FElem|Nuts]}};
						3 ->%%蓝
							{Num, Nuts} =  State#skyrush.blue_nuts,
							%%保存在玩家的player_other.carry_mark中，以12,13,14,15表示魔核
							gen_server:cast(PlayerPid, {'UPDATE_FEATS_MARK', NutType+11, 0}),
							State#skyrush{blue_nuts = {Num+1, [FElem|Nuts]}};
						4 ->%%紫
							{Num, Nuts} =  State#skyrush.purple_nuts,
							%%保存在玩家的player_other.carry_mark中，以12,13,14,15表示魔核
							gen_server:cast(PlayerPid, {'UPDATE_FEATS_MARK', NutType+11, 0}),
							send_skyrush_notice(7, NewParam),
							State#skyrush{purple_nuts = {Num+1,[FElem|Nuts]}}
					end;
				true ->
					State
			end
	end.

get_boss_feats(MonId) ->
	case MonId of
		43001 ->
			{30, 15, 1};
		43002 ->
			{40, 20, 2};
		43003 ->
			{50, 25, 3};
		_ ->
			{0, 0, 0}
	end.

get_submit_feats(Point, Type, Color, State, PlayerId) ->
	AddPoint = get_addition(Point),
	{GFeat, MFeat} = get_feats_give(AddPoint, Type, Color),
	case Type of
		0 ->%%旗
			case Color of
				1 ->%%白
					{Num,Flags} = State#skyrush.white_flags,
					NFlags = lists:keydelete(PlayerId, #fns_elem.player_id, Flags),
					NewStats = State#skyrush{white_flags = {Num - 1, NFlags}},
					{GFeat, MFeat, NewStats};
				2 ->%%绿
					{Num,Flags} = State#skyrush.green_flags,
					NFlags = lists:keydelete(PlayerId, #fns_elem.player_id, Flags),
					NewStats = State#skyrush{green_flags = {Num - 1, NFlags}},
					{GFeat, MFeat, NewStats};
				3 ->%%蓝
					{Num,Flags} = State#skyrush.blue_flags,
					NFlags = lists:keydelete(PlayerId, #fns_elem.player_id, Flags),
					NewStats = State#skyrush{blue_flags = {Num - 1, NFlags}},
					{GFeat, MFeat, NewStats};
				4 ->%%紫
					{Num,Flags} = State#skyrush.purple_flags,
					NFlags = lists:keydelete(PlayerId, #fns_elem.player_id, Flags),
					NewStats = State#skyrush{purple_flags = {Num - 1, NFlags}},
					{GFeat, MFeat, NewStats}
			end;
		1 ->
			case Color of
				1 ->%%白
					{Num, Nuts} = State#skyrush.white_nuts,
					NNuts = lists:keydelete(PlayerId, #fns_elem.player_id, Nuts),
					NewStats = State#skyrush{white_nuts = {Num -1, NNuts}},
					{GFeat, MFeat, NewStats};
				2 ->%%绿
					{Num, Nuts} = State#skyrush.green_nuts,
					NNuts = lists:keydelete(PlayerId, #fns_elem.player_id, Nuts),
					NewStats = State#skyrush{green_nuts = {Num -1, NNuts}},
					{GFeat, MFeat, NewStats};
				3 ->%%蓝
					{Num, Nuts} = State#skyrush.blue_nuts,
					NNuts = lists:keydelete(PlayerId, #fns_elem.player_id, Nuts),
					NewStats = State#skyrush{blue_nuts = {Num -1, NNuts}},
					{GFeat, MFeat, NewStats};
				4 ->%%紫
					{Num, Nuts} = State#skyrush.purple_nuts,
					NNuts = lists:keydelete(PlayerId, #fns_elem.player_id, Nuts),
					NewStats = State#skyrush{purple_nuts = {Num -1, NNuts}},
					{GFeat, MFeat, NewStats}
			end
	end.

get_addition(Point) ->
	case Point of
		1 ->
			0.2;
		2 ->
			0.4;
		_ ->
			0
	end.
					

%%根据MS获取guild数据
get_guilds_by_etsms(MS) ->
	ets:select(?ETS_GUILD, MS).

skyrush_send_mail(Type, PlayerId, GuildId, SubjectType, BaseParam) ->
	GuildMembers = lib_guild_inner:get_guild_member_by_guild_id(GuildId),
	case GuildMembers of
		[] ->
			no_action;
		_ ->
			case Type of
				0 ->%%不用删除本人 PlayerId
					NewGuildMembers = GuildMembers;
				1 ->%%需要删除本人 PlayerId
					NewGuildMembers = lists:keydelete(PlayerId, #ets_guild_member.player_id, GuildMembers)
			end,
			spawn(fun() ->
						  lists:foreach(fun(Member) ->
												Param = [Member#ets_guild_member.player_name | BaseParam],
												lib_guild_inner:send_mail(SubjectType, Param)
										end, NewGuildMembers)
				  end)
	end.
				
get_skyrush_scene_info(Status, Name, X, Y) ->
	case mod_skyrush:get_skyrush_pid() of
		{ok, Pid} ->
			Status1 = Status#player{other = Status#player.other#player_other{pid_scene = Pid}},
			{true, ?SKY_RUSH_SCENE_ID, X, Y, Name, ?SKY_RUSH_SCENE_ID, 0, 0, Status1};
		_ ->
			{false, 0, 0, 0, <<"场景不存在!">>, 0, []}
	end.

			
check_applied_guild(GuildId) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
							 {apply_call, lib_skyrush, check_applied_guild_inter, 
							  [GuildId]})	of
			error -> 
%% 				?DEBUG("40004 apply_join_guild error",[]),
				0;
			Data ->
%% 				?DEBUG("40004 apply_join_guild succeed:[~p]",[Data]),
				Data
		end		
	catch
		_:_Reason -> 
%% 			?DEBUG("40004 apply_join_guild fail for the reason:[~p]",[_Reason]),
			0
	end.
check_applied_guild_inter(GuildId) ->
	Guild = lib_guild_inner:get_guild(GuildId),
	if 
		Guild =:= [] ->
			0;
		is_record(Guild, ets_guild) =:= false ->
			0;
		true ->
			AppliedTime = Guild#ets_guild.sky_apply,
%% 			io:format("check apply AppliedTime:~p, StartTime:~p, EndTime:~p\n", [AppliedTime, StartTime, EndTime]),
			
			%%配置表
			[WeekDate, SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = get_start_end_time(),
			NowSec = util:get_today_current_second(),
			%%是否要开氏族战
			Judge = lib_skyrush:tobe_opening_skyrush(WeekDate),
			case AppliedTime =:= 1 of
				true when Judge =:= true andalso NowSec > SKY_RUSH_START_TIME andalso NowSec < SKY_RUSH_END_TIME - 10 ->
					1;
				true ->
					4;
				false ->
					3
			end
	end.
					
%%boss刷魔核
get_mon_nut_1() ->
	Random = random:uniform(1000),
	if 
		Random =< 300 ->
			1;
		Random =< 550 ->
			2;
		Random =< 800 ->
			3;
		true ->
			4
	end.
%%小怪刷魔核
get_mon_nut_2() ->
	Random = random:uniform(1000),
	if 
		Random > 100 andalso Random =< 200 ->
			1;
		Random > 300 andalso Random =< 420 ->
			2;
		Random > 500 andalso Random =< 580 ->
			3;
		Random > 900 andalso Random =< 950 ->
			4;
		true ->
			0
	end.
		
%%判断坐标和个人数据是否合法
check_point_ok(Point, FeatsType, Color, X, Y, GuildId, PlayerId, State) ->
	PointOk = check_coord_ok(1, Point, X, Y, GuildId, State#skyrush.point_l, State#skyrush.point_h),%%1为去据点提交
	case PointOk of
		false ->
			{false, 3};
		{false, Res} ->
			{false, Res};
		true ->
			check_submit_ok(FeatsType, Color, PlayerId, GuildId, State)
	end.
%%判断坐标是否合法
check_coord_ok(Type, Point, X, Y, GuildId, PointLInfo, PointHInfo) ->
	{PointL, _LName} = PointLInfo,
	{PointH, _HName} = PointHInfo,
	case Type of
		1 ->%%1为去据点提交
			%%获取据点坐标
			[PX,PY] = get_point_coord(Point),
			case Point of
				1 ->%%中级据点
					ABX = abs(X - PX),
					ABY = abs(Y - PY),
					if 
						GuildId =/= PointL ->
							{false, 4};%%据点不是所在氏族再有的
						(ABX =< ?COORD_DIST_LIMIT andalso ABY =< ?COORD_DIST_LIMIT) =:= true andalso GuildId =:= PointL ->
							true;
						true ->
							{false, 3}
					end;
				2 ->%%高级据点
					ABX = abs(X - PX),
					ABY = abs(Y - PY),
					if 
						GuildId =/= PointH ->
							{false, 4};%%据点不是所在氏族再有的
						(ABX =< ?COORD_DIST_LIMIT andalso ABY =< ?COORD_DIST_LIMIT) =:= true andalso GuildId =:= PointH ->
							true;
						true ->
							{false, 3}
					end;
				3 ->%%共用据点
					ABX = abs(X - PX),
					ABY = abs(Y - PY),
					ABX =< ?COORD_DIST_LIMIT andalso ABY =< ?COORD_DIST_LIMIT
			end;
		0 ->%%case为0的情况很少用，都写得到各自代码需要的地方去了
			case Point of
				1 ->%%白
					[FX, FY] = get_flags_coord(1),
					ABX = abs(X - FX),
					ABY = abs(Y - FY),
					ABX =< ?COORD_DIST_LIMIT andalso ABY =< ?COORD_DIST_LIMIT;
				2 ->%%绿
					[FX, FY] = get_flags_coord(2),
					ABX = abs(X - FX),
					ABY = abs(Y - FY),
					ABX =< ?COORD_DIST_LIMIT andalso ABY =< ?COORD_DIST_LIMIT;
				3 ->%%蓝
					[FX, FY] = get_flags_coord(3),
					ABX = abs(X - FX),
					ABY = abs(Y - FY),
					ABX =< ?COORD_DIST_LIMIT andalso ABY =< ?COORD_DIST_LIMIT;
				4 ->%%紫
					[FX, FY] = get_flags_coord(1),
					ABX = abs(X - FX),
					ABY = abs(Y - FY),
					ABX =< ?COORD_DIST_LIMIT andalso ABY =< ?COORD_DIST_LIMIT
			end
	end.
%%判断个人数据是否合法
check_submit_ok(FeatsType, Color, PlayerId, GuildId, State) ->
	case ets_get_guild_feats(GuildId) of
		[] ->
%% 			io:format("no guild feats\n"),
			false;
		_GFeatsEts ->
			case ets_get_guild_mem_feats(PlayerId) of
				[] ->
%% 					io:format("no guild member feats\n"),
					false;
				_MemFeatsEts ->
					check_feats_exist(FeatsType, Color, PlayerId, State)
			end
	end.
				
check_feats_exist(FeatsType, Color, PlayerId, State) ->
	case FeatsType of
		0 ->%%旗
			case Color of
				1 ->%%白
					{_Num, Flags} = State#skyrush.white_flags,
					lists:keymember(PlayerId, #fns_elem.player_id, Flags);
				2 ->%%绿
					{_Num, Flags} = State#skyrush.green_flags,
					lists:keymember(PlayerId, #fns_elem.player_id, Flags);
				3 ->%%蓝
					{_Num, Flags} = State#skyrush.blue_flags,
					lists:keymember(PlayerId, #fns_elem.player_id, Flags);
				4 ->%%紫
					{_Num, Flags} = State#skyrush.purple_flags,
					lists:keymember(PlayerId, #fns_elem.player_id, Flags)
			end;
		1 ->
			case Color of
				1 ->%%白
					{_Num, Nuts} = State#skyrush.white_nuts,
					lists:keymember(PlayerId, #fns_elem.player_id, Nuts);
				2 ->%%绿
					{_Num, Nuts} = State#skyrush.green_nuts,
					lists:keymember(PlayerId, #fns_elem.player_id, Nuts);
				3 ->%%蓝
					{_Num, Nuts} = State#skyrush.blue_nuts,
					lists:keymember(PlayerId, #fns_elem.player_id, Nuts);
				4 ->%%紫
					{_Num, Nuts} = State#skyrush.purple_nuts,
					lists:keymember(PlayerId, #fns_elem.player_id, Nuts)
			end
	end.

%%获取氏族和个人功勋
get_feats_give(AddPoint, Type, Color) ->
	{G, M} = 
		case Type of
			0 ->%%旗
				case Color of
					1 ->
						{8, 4};
					2 ->
						{16, 8};
					3 ->
						{24, 12};
					4 ->
						{40, 20}
				end;
			1 ->%%魔核
				case Color of
					1 ->
						{10, 5};
					2 ->
						{20, 10};
					3 ->
						{30, 15};
					4 ->
						{50, 25}
				end
		end,
	GFeats = util:floor(G * (1 + AddPoint)),
	MFeat = util:floor(M * (1 + AddPoint)),
	{GFeats, MFeat}.
	
%%更新旗的数据
update_flags_data(PlayerId, Type, State) ->
	case Type of
		1 ->%白旗
			{Num, Flags} = State#skyrush.white_flags,
			FElem = #fns_elem{player_id = PlayerId,
							   type = 1},
			NFlags = [FElem|Flags],
			State#skyrush{white_flags = {Num, NFlags}};
		2 ->%绿旗
			{Num, Flags} = State#skyrush.green_flags,
			FElem = #fns_elem{player_id = PlayerId,
							   type = 2},
			NFlags = [FElem|Flags],
			State#skyrush{green_flags = {Num, NFlags}};
		3 ->%蓝旗
			{Num, Flags} = State#skyrush.blue_flags,
			FElem = #fns_elem{player_id = PlayerId,
							   type = 3},
			NFlags = [FElem|Flags],
			State#skyrush{blue_flags = {Num, NFlags}};
		4 ->%紫旗
			{Num, Flags} = State#skyrush.purple_flags,
			FElem = #fns_elem{player_id = PlayerId,
							   type = 4},
			NFlags = [FElem|Flags],
			State#skyrush{purple_flags = {Num, NFlags}}
	end.
	
%%神战结束后处理
handle_skyrush_gmfeats(NowTime) ->
	GFeats = ets:tab2list(?G_FEATS_ELEM),
	MFeats = ets:tab2list(?MEM_FEATS_ELEM),
	notice_best_guild(GFeats),
	gen_server:cast(mod_guild:get_mod_guild_pid(), {'UPDATE_SKYRUSH_INFO', GFeats, MFeats, NowTime}).
	
handle_gfeats(GFeats, MFeats, NowTime) ->
%% 	ets:delete_all_objects(?GUILD_SKYRUSH_RANK),
	SortGFeats = 
		lists:sort(fun(GFA,GFB) ->
						   GFA#g_feats_elem.guild_feats >=  GFB#g_feats_elem.guild_feats
				   end, GFeats),
	
	lists:foldl(fun(Elem, AccIn) ->
						  #g_feats_elem{guild_id = GuildId,
										guild_feats = GFeat} = Elem,
						  case lib_guild_inner:get_guild(GuildId) of
							  [] ->
								  AccIn +1;
							  Guild ->
								  Award = %%取得奖励的数据
									  case AccIn =< 5 andalso GFeat > 0 of
										  true ->
											  util:term_to_string(lists:nth(AccIn, ?SKYRUSH_AWARD_GOODS));
										  false ->
											  util:term_to_string(?SKYRUSH_AWARD_ZERO)
									  end,
								  APlist =  util:term_to_string([]),%%玩家表置为空
								  #ets_guild{combat_all_num = FeatsAll,
											 combat_week_num = FeatsWStr} = Guild,
								  FeatsW = util:string_to_term(tool:to_list(FeatsWStr)),
								  [Week, FeatsWeek] = FeatsW,
								  IsSW = util:is_same_week(Week, NowTime),
								  NewFeatsWeek= 
									  case IsSW of
										  true ->
											  FeatsWeek + GFeat;
										  false ->
											  GFeat
									  end,
								  NewFeatsW = [NowTime, NewFeatsWeek],
								  NewFeatsWStr = util:term_to_string(NewFeatsW),
								  MemNum = count_jion_num(GuildId, MFeats),
								  NewFeatsAll = FeatsAll + GFeat,
								  NewGuild = Guild#ets_guild{combat_num = MemNum,
															 combat_victory_num = GFeat,
															 combat_all_num = NewFeatsAll,
															 combat_week_num = NewFeatsWStr,
															 jion_ltime = NowTime,
															 sky_apply = 0,
															 sky_award = Award,
															 a_plist = APlist},
								  ValueList = [{combat_num, MemNum}, {combat_victory_num, GFeat}, {combat_all_num, NewFeatsAll}, 
											   {combat_week_num, NewFeatsWStr},{jion_ltime, NowTime}, {sky_apply, 0}, 
											   {sky_award, Award}, {a_plist, APlist}],
								  FieldList = [{id, GuildId}],
								  db_agent:update_sky_guild(guild, ValueList, FieldList),
								  lib_guild_inner:update_guild(NewGuild),
								  InsertGRank = #guild_skyrush_rank{guild_id = GuildId,
																	guild_name = NewGuild#ets_guild.name,
																	lv = NewGuild#ets_guild.level,
																	jion_m_num = NewGuild#ets_guild.combat_num,
																	feat_last = GFeat,
																	feat_week = NewFeatsWeek,
																	feat_all = NewGuild#ets_guild.combat_all_num,
																	last_join_time = NowTime},
								  ets:insert(?GUILD_SKYRUSH_RANK, InsertGRank),%%插入排行榜数据
								  AccIn + 1
						  end
				  end, 1, SortGFeats).


handle_mfeats(MFeats, NowTime) ->
	ets:delete_all_objects(?GUILD_MEM_SKYRUSH_RANK),
%% 	io:format("the member feats: ~p\n", [MFeats]),
	lists:foreach(fun(Elem) ->
						  #mem_feats_elem{player_id = PlayerId,
										  guild_id = GuildId,
										  kill_foe = KillFoe,	%%杀敌数
										  die_count = DieC,	%%死亡次数
										  get_flags = GFlags,	%%夺旗数
										  magic_nut = MNuts,	%%魔核数
										  feats = Feat} = Elem,
						  case lib_guild_inner:get_guild_member_by_guildandplayer_id(GuildId, PlayerId) of
							  [] ->
								  skip;
							  GMember ->
								  #ets_guild_member{feats_all = FeatAll,
													player_name = PlayerName,
													career = Career,
													lv = Level} = GMember,
								  NewFeatAll = abs(FeatAll + Feat),
								  NewGMember = GMember#ets_guild_member{kill_foe = KillFoe,
																		die_count = DieC,
																		get_flags = GFlags,
																		magic_nut = MNuts,
																		feats = Feat,
																		feats_all = NewFeatAll,
																		f_uptime = NowTime,
																		gr = 0},
								  ValueList = [{kill_foe, KillFoe}, {die_count, DieC}, {get_flags, GFlags}, 
											   {magic_nut, MNuts}, {feats, Feat}, {feats_all, NewFeatAll}, 
											   {f_uptime, NowTime}, {gr, 0}],
								  FieldList = [{player_id, PlayerId}],
								  db_agent:update_sky_guild(guild_member, ValueList, FieldList),
								  lib_guild_inner:update_guild_member(NewGMember),
								  %%同步更新玩家功勋信息
								  sync_member_feats(PlayerId, NewFeatAll),
								  InsertMRank = #guild_mem_skyrush_rank{player_id = PlayerId,
																		player_name = PlayerName,
																		guild_id = GuildId,
																		career = Career,
																		lv = Level,
																		kill_foe = KillFoe,
																		die_num = DieC,
																		get_flags = GFlags,
																		magic_nut = MNuts,
																		feats = Feat},
								  ets:insert(?GUILD_MEM_SKYRUSH_RANK, InsertMRank),
								  %%添加玩家氏族战参与度统计
								  db_agent:update_join_data(PlayerId, guild)
%% 								  make_member_join_log(PlayerId, NowTime)
						  end
				  end, MFeats).

%%空岛战场积分排行榜
rank_guild_member_feats() ->
	GFeats = ets:tab2list(?GUILD_SKYRUSH_RANK),
	MFeats = ets:tab2list(?GUILD_MEM_SKYRUSH_RANK),
	{OneList, TwoList} = lists:foldl(fun(Elem1, AccIn) ->
											 {One, Two} = AccIn,
											 #guild_skyrush_rank{guild_id = _GuildId,
																 guild_name = GuildName,
																 lv = GLv,
																 jion_m_num = JoinNum,
																 feat_last = FeatsL,
																 feat_week = FeatsW,
																 feat_all =FeatsAll,
																 last_join_time = LJTime} = Elem1,
											 NowTime = util:unixtime(),
											 %%配置表
											 [WeekDate, _SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = 
												 lib_skyrush:get_start_end_time(),
											 %%判断今天星期几
											 Date = util:get_date(),
											 %%获取除了今天的最近开战的星期
											 LastDate = get_last_skyrush_week(WeekDate, Date, lists:last(WeekDate)),
											 %%上次开战的星期
											 {{Year, Month, Day}, _Time}= util:seconds_to_localtime(LJTime),
											 LJDate = calendar:day_of_the_week({Year, Month, Day}),
											 
											 NowSec = util:get_today_current_second(),
											 
											 %%在一个星期内
											 DifferTime = abs(NowTime - LJTime),
											 
											 case NowSec < SKY_RUSH_END_TIME of
												 true ->%%在开场的前段时间，加载最近的一次帮战
													 case LastDate =:= LJDate andalso (DifferTime < 7*24*3600)of
														 true ->%%是否参加
															 NewOne = [{GuildName, GLv, JoinNum, FeatsL}|One];
														 false ->
															 NewOne =  One
													 end;
												 false ->
													 case lists:member(Date, WeekDate) =:= true of
														 true ->%%今天是否开了氏族战
															 case util:is_same_date(NowTime, LJTime) of
																 true ->%%记录是今天的
																	 NewOne = [{GuildName, GLv, JoinNum, FeatsL}|One];
																 false ->
																	 NewOne =  One
															 end;
														 false ->
															 case LastDate =:= LJDate andalso (DifferTime < 7*24*3600)of
																 true ->%%是否参加
																	 NewOne = [{GuildName, GLv, JoinNum, FeatsL}|One];
																 false ->
																	 NewOne =  One
															 end
													 end
											 end,
											 
											 case util:is_same_week(NowTime, LJTime) of
												 true ->
													 NewTwo = [{GuildName, GLv, FeatsAll, FeatsW}|Two];
												 false ->
													 NewTwo = Two
											 end,
											 {NewOne, NewTwo}
									 end, {[],[]}, GFeats),
	
	ThreeList = lists:map(fun(Elem2) ->
								  #guild_mem_skyrush_rank{player_id = _PlayerId,
														  player_name = PlayerName,
														  career = Career,
														  lv = PLv,
														  kill_foe = KillFoe,
														  die_num = DieC,
														  get_flags = GFlags,
														  magic_nut = MNuts,
														  feats = Feat} = Elem2,
								  {PlayerName, Career, PLv, KillFoe, DieC, GFlags, MNuts, Feat}
						  end, MFeats),
	{OneList, TwoList, ThreeList}.

%%玩家主动获取排行榜信息
get_skyrush_rank(PidSend) ->
	RankList = lib_skyrush:rank_guild_member_feats(),
	{ok, Data39021} = pt_39:write(39021, [RankList]),
	spawn(fun() -> lib_send:send_to_sid(PidSend, Data39021) end).
	

%%22007 上场个人功勋排行
query_skymem_rank(PidSend) ->
	RankInfo = query_skymem_rank_inner(),
	{ok, BinData} = pt_22:write(22007, RankInfo),
	spawn(fun() -> lib_send:send_to_sid(PidSend, BinData) end).


query_skymem_rank_inner() ->
	MFeats = ets:tab2list(?GUILD_MEM_SKYRUSH_RANK),
	lists:map(fun(Elem2) ->
					  #guild_mem_skyrush_rank{player_id = _PlayerId,
											  player_name = PlayerName,
											  career = Career,
											  lv = PLv,
											  kill_foe = KillFoe,
											  die_num = DieC,
											  get_flags = GFlags,
											  magic_nut = MNuts,
											  feats = Feat} = Elem2,
					  {PlayerName, Career, PLv, KillFoe, DieC, GFlags, MNuts, Feat}
			  end, MFeats).


get_start_end_time() ->
	%%使用宏
	{_, C} = lists:keyfind(kyrush_time, 1, ?CONFING_FILE_LIST),
	{_, SHour, SMine} = lists:keyfind(sky_rush_start_time, 1, C),
	{_, EHour, EMine} = lists:keyfind(sky_rush_end_time, 1, C),
	{_, WeekDate} = lists:keyfind(sky_hold_week, 1, C),
	[WeekDate, SHour*3600+SMine*60, EHour*3600+EMine*60].		

get_notice_sign_up_time()->
	{_, C} = lists:keyfind(kyrush_time, 1, ?CONFING_FILE_LIST),
	{_, SHour, SMine} = lists:keyfind(notice_sign_up, 1, C),
	SHour*3600+SMine*60.

%%此方法内部邮件内容时间调用
get_startend_time_base() ->
	%%使用宏
	{_, C} = lists:keyfind(kyrush_time, 1, ?CONFING_FILE_LIST),
	{_, SHour, SMine} = lists:keyfind(sky_rush_start_time_email, 1, C),
	{_, EHour, EMine} = lists:keyfind(sky_rush_end_time, 1, C),
	[SHour, SMine, EHour, EMine].		

%%获取空岛实际上开战的时间
get_skyrush_start_infact() ->
	{_, C} = lists:keyfind(kyrush_time, 1, ?CONFING_FILE_LIST),
	{_, SHour, SMine} = lists:keyfind(sky_rush_start_time_email, 1, C),
	SHour*3600+SMine*60.

%%加载氏族空岛排行榜
load_skyrush_g_rank(Guild) ->
	Now = util:unixtime(),
	#ets_guild{jion_ltime = NowTime} = Guild,
	case util:is_same_week(Now, NowTime) of
		true ->
			[_Week, FeatsWeek] = util:string_to_term(tool:to_list(Guild#ets_guild.combat_week_num)),
			InsertGRank = #guild_skyrush_rank{guild_id = Guild#ets_guild.id,
											  guild_name = Guild#ets_guild.name,
											  lv = Guild#ets_guild.level,
											  jion_m_num = Guild#ets_guild.combat_num,
											  feat_last = Guild#ets_guild.combat_victory_num,
											  feat_week = FeatsWeek,
											  feat_all = Guild#ets_guild.combat_all_num,
											  last_join_time = Guild#ets_guild.jion_ltime},
				   ets:insert(?GUILD_SKYRUSH_RANK, InsertGRank);%%插入排行榜数据
		false ->
			skip
	end.

		
%%加载空岛神战的氏族成员排行榜
load_skyrush_m_rank(GuildMember, NowTime) ->
	#ets_guild_member{player_id = PlayerId,
					  player_name = PlayerName,
					  guild_id = GuildId,
					  career = Career,
					  sex = Sex,
					  lv = Level,
					  kill_foe = KillFoe,
					  die_count = DieC,
					  get_flags = GFlags,
					  magic_nut = MNuts,
					  feats = Feat,
					  feats_all = _NewFeatAll,
					  f_uptime = FupTime} = GuildMember,
	case FupTime =:= 0 of
		false ->
			%%配置表
			[WeekDate, _SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = 
				lib_skyrush:get_start_end_time(),
			%%判断今天星期几
			Date = util:get_date(),
			%%获取除了今天的最近开战的星期
			LastDate = get_last_skyrush_week(WeekDate, Date, lists:last(WeekDate)),
			%%上次开战的星期
			{{Year, Month, Day}, _Time}= util:seconds_to_localtime(FupTime),
			LFDate = calendar:day_of_the_week({Year, Month, Day}),
			NowSec = util:get_today_current_second(),
%% 			io:format("LastDate:~p,LFDate:~p\n", [LastDate, LFDate]),
			%%在一个星期内
			DifferTime = abs(NowTime - FupTime),
			
			case NowSec < SKY_RUSH_END_TIME of
				true ->%%在开场的前段时间，加载最近的一次帮战
					case LastDate =:= LFDate andalso (DifferTime < 7*24*3600) of
						true ->%%是否参加
							insert_member_skyrush_rank(PlayerId, PlayerName, GuildId, Career, Sex, Level, 
													   KillFoe, DieC, GFlags, MNuts, Feat);
						false ->
							skip
					end;
				false ->
					case lists:member(Date, WeekDate) =:= true of
						true ->%%今天是否开了氏族战
							case util:is_same_date(NowTime, FupTime) of
								true ->%%记录是今天的
									insert_member_skyrush_rank(PlayerId, PlayerName, GuildId, Career, Sex, Level, 
															   KillFoe, DieC, GFlags, MNuts, Feat);
								false ->
									skip
							end;
						false ->%%否，则加载最近的一次帮战
							case LastDate =:= LFDate andalso (DifferTime < 7*24*3600) of
								true ->%%是否参加
									insert_member_skyrush_rank(PlayerId, PlayerName, GuildId, Career, Sex, Level, 
															   KillFoe, DieC, GFlags, MNuts, Feat);
								false ->
									skip
							end
					end
			end;
		true ->
			skip
	end.

insert_member_skyrush_rank(PlayerId, PlayerName, GuildId, Career, Sex, Level, 
						   KillFoe, DieC, GFlags, MNuts, Feat) ->
	InsertMRank = 
		#guild_mem_skyrush_rank{player_id = PlayerId,
								player_name = PlayerName,
								guild_id = GuildId,
								career = Career,
								sex = Sex,
								lv = Level,
								kill_foe = KillFoe,
								die_num = DieC,
								get_flags = GFlags,
								magic_nut = MNuts,
								feats = Feat},
	ets:insert(?GUILD_MEM_SKYRUSH_RANK, InsertMRank).

notice_best_guild(GFeats) ->
	[Name, OldFeat] = get_the_best(GFeats, ["", 0]),
	case OldFeat =:= 0 of
		true ->
			skip;
		false ->
			send_skyrush_notice(9, [Name])
	end.

get_the_best([], Result) ->
	Result;
get_the_best([GFeat|GFeats], Result) ->
	[Name, OldFeat] = Result,
	#g_feats_elem{guild_name = GuildName,
				  guild_feats = Feat} = GFeat,
	NewResult = 
		case OldFeat > Feat of
			true ->
				[Name, OldFeat];
			false ->
				[GuildName, Feat]
		end,
	get_the_best(GFeats, NewResult).
		
	
sync_member_feats(PlayerId, NewFeatAll) ->
	case lib_player:get_player_pid(PlayerId) of
		[] ->
			skip;
		Pid ->
			gen_server:cast(Pid, {'SYNC_MEMBER_FEATS', NewFeatAll})
	end.

%%对外提供的扣除个人功勋的接口，返回剩余功勋
deduct_player_feat(Player, Feats, GoodsTypeId, GoodsNum, ShopType) ->
	try 
		case gen_server:call(mod_guild:get_mod_guild_pid(), 
						{apply_call, lib_skyrush, deduct_member_feat, [Player#player.id, Player#player.other#player_other.guild_feats, Feats, GoodsTypeId, GoodsNum,ShopType]})	of
			 error -> {error, Player};
			 Data -> {ok, Player#player{other = Player#player.other#player_other{guild_feats = Data}}}
		end			
	catch
		_:_ -> {error, Player}
	end.	
%%警告：此方法不能对外调用
deduct_member_feat(PlayerId, PFeat, Feats, GoodsTypeId, GoodsNum, ShopType) ->
	case lib_guild_inner:get_guild_member_by_player_id(PlayerId) of
		[] ->
			PFeat;
		Member ->
			NewFeat = abs(Member#ets_guild_member.feats_all - Feats),
			NewMember = Member#ets_guild_member{feats_all = NewFeat},
			ValueList = [{feats_all, NewFeat}],
			FieldList = [{player_id, PlayerId}],
			db_agent:update_sky_guild(guild_member, ValueList, FieldList),
			lib_guild_inner:update_guild_member(NewMember),
			spawn(fun()-> db_agent:log_feat_count(ShopType, PlayerId, Member#ets_guild_member.feats_all, NewFeat, GoodsTypeId, GoodsNum) end),
			NewFeat
	end.

color_num_to_name(Color) ->
	case Color of
		4 ->
			{"#8800FF","紫"};
		3 ->
			{"#313bdd","蓝"};
		2 ->
			{"#00FF33", "绿"};
		_ ->
			{"#FFFFFF", "白"}
	end.


%%获取发邮件的日期
get_mail_date(Date) ->
	[FirstDate|_] = ?SKY_HOLD_WEEK_FORMAIL,
	Num = get_next_skyrush_week(?SKY_HOLD_WEEK_FORMAIL, Date, FirstDate),
%% 	io:format("FirstDate:~p, Date:~p, Num:~p\n", [FirstDate, Date, Num]),
	{StartTime, _EndTime} = util:get_this_week_duringtime(),
	NeedSec = StartTime + (Num-1)*24*60*60+ 3600,
	{{_Year, Month, Day}, _Time} = util:seconds_to_localtime(NeedSec),
	[Month, Day].


%%=================================================据点刷新	清理过期丢在地上的战旗 =========================================================

flesh_point_l(State) ->
	Point_l = State#skyrush.point_l_read,
	NewPoint_l = 
		lists:map(fun(Elem) ->
						  {Time, InPlayerId, InGuildId, InGuildName} = Elem,
						  {Time -1, InPlayerId, InGuildId, InGuildName}
				  end, Point_l),
	case lists:keyfind(0, 1, NewPoint_l) of
		false ->
			StateL = State#skyrush{point_l_read = NewPoint_l};
		{_Time, PlayerIdG, GuildId, GuildName} ->
%% 			io:format("POINT_L_READ:~p\n", [PlayerIdG]),
			{ok, Data39006} = pt_39:write(39006, [1, GuildName]),
			spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39006) end),
			Param = [GuildName],
			lib_skyrush:send_skyrush_notice(5, Param),
			StateL = State#skyrush{point_l_read = [],
								   point_l = {GuildId, GuildName}},
			erlang:spawn(fun() ->
								 lists:foreach(fun(Elem) ->
													   {_BTime, BPlayerId,_BGuildId, _BGuildName} = Elem,
													   case BPlayerId =:= PlayerIdG of
														   true ->
															   reset_player_carry_mark(1, PlayerIdG, BPlayerId),
															   skip;
														   false ->
															   {ok, Data39017} = pt_39:write(39017, []),
															   %%通知复位玩家carry_mark
															   reset_player_carry_mark(1, PlayerIdG, BPlayerId),
															   lib_send:send_to_uid(BPlayerId, Data39017)
													   end
											   end, NewPoint_l)
						 end)
	end,
	StateL.

flesh_point_h(StateL) ->
	Point_h = StateL#skyrush.point_h_read,
	NewPoint_h = 
		lists:map(fun(Elem) ->
						  {Time, PlayerId, GuildId, GuildName} = Elem,
						  {Time -1, PlayerId, GuildId, GuildName}
				  end, Point_h),
	case lists:keyfind(0, 1, NewPoint_h) of
		false ->
			StateH = StateL#skyrush{point_h_read = NewPoint_h};
		{_Time, PlayerIdG, GuildId, GuildName} ->
%% 			io:format("POINT_H_READ:~p\n", [PlayerIdG]),
			{ok, Data39006} = pt_39:write(39006, [2, GuildName]),
			spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39006) end),
			Param = [GuildName],
			lib_skyrush:send_skyrush_notice(6, Param),
			StateH = StateL#skyrush{point_h_read = [],
									 point_h = {GuildId, GuildName}},
			erlang:spawn(fun() ->
								 lists:foreach(fun(Elem) ->
													   {_BTime, BPlayerId,_BGuildId, _BGuildName} = Elem,
													   case BPlayerId =:= PlayerIdG of
														   true ->
															   reset_player_carry_mark(1, PlayerIdG, BPlayerId),
															   skip;
														   false ->
															   {ok, Data39017} = pt_39:write(39017, []),
															   %%通知复位玩家carry_mark
															   reset_player_carry_mark(1, PlayerIdG, BPlayerId),
															   lib_send:send_to_uid(BPlayerId, Data39017)
													   end
											   end, NewPoint_h)
						 end)
	end,
	StateH.

flesh_clean_drop_flags(StateH) ->
%% 	DropFlags = StateH#skyrush.drop_flags,
	#skyrush{white_flags = {WhiteNum, WhiteF},	
			 green_flags = {GreenNum, GreenF},
			 blue_flags = {BlueNum, BlueF},	
			 purple_flags = {PurpleNum, PurpleF},
			 drop_flags = DropFlags} = StateH,
	{[W,G,B,P], NewDropFlags} = 
		lists:foldl(fun(Elem, AccIn) ->
							#df_elem{time = Time,
									 coord = {X,Y},	%%丢落的坐标
									 type = Type} = Elem,
							{[W0,G0,B0,P0], S} = AccIn,
							case Time =< 0 of
								true ->
									{ok, BinData39022} = pt_39:write(39022, [X,Y,Type]),
									spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, BinData39022) end),
									New = 
									case Type of
										1 ->
											[W0-1,G0,B0,P0];
										2 ->
											[W0,G0-1,B0,P0];
										3 ->
											[W0,G0,B0-1,P0];
										4 ->
											[W0,G0,B0,P0-1]
									end,
									{New, S};
								false ->
									NewElem = Elem#df_elem{time = Time -1},
									{[W0,G0,B0,P0], [NewElem|S]}
							end
					end, {[WhiteNum,GreenNum,BlueNum,PurpleNum],[]}, DropFlags),
%% 	io:format("remain the drop list: ~p\n", [NewDropFlags]),
	StateH#skyrush{white_flags = {W, WhiteF},	
				   green_flags = {G, GreenF},
				   blue_flags = {B, BlueF},	
				   purple_flags = {P, PurpleF},
				   drop_flags = NewDropFlags}.

%%=================================================据点刷新	清理过期丢在地上的战旗 =========================================================

%%添加死亡数和杀敌数
add_kill_die_num(DieId, AerId) ->
	case ets_get_guild_mem_feats(DieId) of
		[] ->
			skip;
		[DieMem] ->
			NewDieMem = DieMem#mem_feats_elem{die_count = DieMem#mem_feats_elem.die_count + 1 },
			ets_update_guild_mem_feats(NewDieMem)
	end,
	case ets_get_guild_mem_feats(AerId) of
		[] ->
			skip;
		[AerMem] ->
			NewAerMem = AerMem#mem_feats_elem{feats = AerMem#mem_feats_elem.feats + ?KILL_GET_FEATS,
											  kill_foe = AerMem#mem_feats_elem.kill_foe + 1},
			ParamTips = [AerId],
			%%通知获得?KILL_GET_FEATS功勋
			lib_skyrush:send_skyrush_tips(8, ParamTips),
			ListUpdate = [{1, NewAerMem#mem_feats_elem.feats, NewAerMem#mem_feats_elem.player_name}],
			{ok, Data39007} = pt_39:write(39007, [1, ListUpdate]),%%局部更新
			spawn(fun() -> mod_scene_agent:send_to_scene(?SKY_RUSH_SCENE_ID, Data39007) end),
			ets_update_guild_mem_feats(NewAerMem)
	end.


%%获取最近的那次氏族战的星期时间 param:list[1,2,3,4,5,6], 1, Num
get_last_skyrush_week([], _Date, Result) ->
	Result;
get_last_skyrush_week([DateOpen|WeekDate], Date, Result) ->
	if DateOpen < Date ->
			get_last_skyrush_week(WeekDate, Date, DateOpen);
		DateOpen > Date ->
			get_last_skyrush_week(WeekDate, Date, Result);
	   true ->
		   get_last_skyrush_week(WeekDate, Date, Date)
	end.

%%获取最近的下一次氏族战的星期时间param:list[1,2,3,4,5,6], 1, Num
%%[FirstDate|_] = WeekDate
%get_next_skyrush_week(WeekDate, Date, FirstDate)
get_next_skyrush_week([], _Date, Result) ->
	Result;
get_next_skyrush_week([DateOpen|WeekDate], Date, Result) ->
	if
		DateOpen > Date ->
			get_next_skyrush_week([], Date, DateOpen);
		DateOpen < Date ->
			get_next_skyrush_week(WeekDate, Date, Result);
		true ->%%如果相等即是当天
			get_next_skyrush_week([], Date, Date)
	end.
			
	
%%复位玩家数据
reset_player_flags(PlayerId, NewPlayers) ->
	lists:map(fun(Elem) ->
					  {_Time, NewPlayerId} = Elem,
					  reset_player_carry_mark(0, PlayerId, NewPlayerId)
			  end, NewPlayers).

%%通知复位玩家carry_mark
reset_player_carry_mark(Type, PlayerIdG, PlayerId) ->
	case Type of
		0 ->
			case PlayerIdG =:= PlayerId of
				true ->
					skip;
				false ->
					case lib_player:get_player_pid(PlayerId) of
						[] ->
							skip;
						Pid ->
							gen_server:cast(Pid, {'UPDATE_FEATS_MARK', 0, 0})
					end
			end;
		1 ->
			case lib_player:get_player_pid(PlayerId) of
				[] ->
					skip;
				Pid ->
					gen_server:cast(Pid, {'UPDATE_FEATS_MARK', 0, 0})
			end
	end.
	
%%定时刷新错误的数据
reflesh_flags_member(NumBase, Flags) ->
	{NewNum, NewFlags} = 
		lists:foldl(fun(Elem, AccIn) ->
							{Num, Players} = AccIn,
							PlayerId = Elem#fns_elem.player_id,
							case lib_player:is_online(PlayerId) of
								true ->
									{Num, [Elem|Players]};
								false ->
									{Num -1, Players}
							end
					end, {NumBase, []}, Flags),
	{NewNum, NewFlags}.

%%报名和个人参战的日志
make_guild_apply_log(GuildId) ->
	 Now = util:unixtime(),
	 case db_agent:get_guild_apply_log(GuildId) of
		[] ->%%没记录
			FieldList = [gd,at],
			ValueList = [GuildId, Now],
			db_agent:make_guild_apply_log(FieldList, ValueList);
		_ ->
			FieldList = [{gd, GuildId}],
			ValueList = [{at, Now}],
			db_agent:update_guild_apply_log(FieldList, ValueList)
	 end.



make_member_join_log(PlayerId, JoinTime) ->
	FieldList = [pd, jt],
	 ValueList = [PlayerId, JoinTime],
	 db_agent:make_member_join_log(FieldList, ValueList).

%%计算参战所得经验
get_skyrush_spirexp(Lv, KillFoc, Flags, Nuts) ->
	A = Lv,
	B = KillFoc,
	C = (Flags + Nuts) * 20,
	
	D = math:pow(A, 2.9) + math:pow(B, 2) + math:pow(C, 1.8),
	E = D / 250,
	
	F = math:pow(E, 2),
	
	G = (F * 2) / 3,
	
	Exp = util:floor(G),
	Spirit = util:floor(Exp / 2),
	
	{Exp, Spirit}.

%%专门用来测试,获取氏族战进程信息
get_skyrush_state() ->
	case mod_skyrush:get_skyrush_pid() of
		{ok, Pid} ->
			gen_server:call(Pid, {'GET_THE_STATE'});
		_ ->
			skip
	end.

%% --------------------------------------------------------------------
%%% 提供氏族战奖励的接口
%% --------------------------------------------------------------------
%% -----------------------------------------------------------------
%% 39026 氏族战奖励	分配上一场空战信息及物品获取物品
%% -----------------------------------------------------------------
get_sky_award_and_members(GuildId) ->
	AwardGoods = get_sky_award_goods(GuildId),
	Members = get_sky_f_members(GuildId),
	FeatMember = 
		lists:map(fun(Elem) ->
						  #guild_mem_skyrush_rank{player_id = PlayerId,
												  player_name = PlayerName,
												  career = Career,
												  sex = Sex,
												  feats = Feats} = Elem,
						  {PlayerId, PlayerName,Career, Sex, Feats}
				  end, Members),
	[AwardGoods, FeatMember].

%%获取氏族战 奖励 物品 列表
get_sky_award_goods(GuildId) ->
	case lib_guild_inner:get_guild(GuildId) of
		[] ->
			?SKYRUSH_AWARD_ZERO;
		Guild ->
			#ets_guild{jion_ltime = LJTime} = Guild,
			Result = check_operate_ok(LJTime),
			case Result of
				1 ->
					AwardList = util:string_to_term(tool:to_list(Guild#ets_guild.sky_award)),
					case AwardList =:= [] orelse AwardList =:= undefined of
						true ->
							?SKYRUSH_AWARD_ZERO;
						false ->
							AwardList
					end;
				_ ->
					?SKYRUSH_AWARD_ZERO
			end
	end.
		
%%获取氏族战最近功勋的成员列表
get_sky_f_members(GuildId) ->
	Pattern = #guild_mem_skyrush_rank{guild_id = GuildId, _ = '_'},
	ets:match_object(?GUILD_MEM_SKYRUSH_RANK, Pattern).

%% -----------------------------------------------------------------
%% 39027 氏族战奖励	物品分配物品
%% -----------------------------------------------------------------
assign_goods_man(GuildId, PlayerId, GoodsId, Num) ->
	case lib_guild_inner:get_guild(GuildId) of
		[] ->
			[0, GoodsId, 0];		%%没这个氏族
		Guild ->
			case lib_guild_inner:get_guild_member_by_guildandplayer_id(GuildId, PlayerId) of
				[] ->
					[0, GoodsId, 0];		%%没有这个人？
				Member ->
					#ets_guild{jion_ltime = LJTime} = Guild,
					Result = check_operate_ok(LJTime),
					if
						Result =/= 1 ->%%不在合法的范围里操作
							[2, GoodsId, 0];
						true ->
							Award = util:string_to_term(tool:to_list(Guild#ets_guild.sky_award)),
							case lists:keyfind(GoodsId, 1, Award) of
								false ->
									[4, GoodsId, 0];		%%不存在这样的物品
								{_GoodsId, GNum} ->
									if
										GNum =< 0 orelse GNum < Num ->	%%物品数量不足
											[5, GoodsId, 0];
										true ->
											APList = util:string_to_term(tool:to_list(Guild#ets_guild.a_plist)),
											case lists:keyfind({PlayerId, GoodsId}, 1, APList) of
												false ->
													spawn(fun() -> lib_skyrush:sky_award_mail(GoodsId, Member#ets_guild_member.player_name,Num) end),
%% 													更新内存和数据库数据(测试时，把一下代码屏蔽，用于多次发物品)
													NewAPList = util:term_to_string([{{PlayerId, GoodsId}, Num}|APList]),
													NewNum = GNum - Num,
													NewAward = util:term_to_string(lists:keyreplace(GoodsId, 1, Award, {GoodsId, NewNum})),
													ValueList = [{sky_award, NewAward}, {a_plist, NewAPList}],
													FieldList = [{id, GuildId}],
													db_agent:update_sky_goods(ValueList, FieldList),
													NewGuild = Guild#ets_guild{sky_award = NewAward,
																			   a_plist = NewAPList},
													lib_guild_inner:update_guild(NewGuild),
													
													[1, GoodsId, NewNum];			%%返回结果
												{{_PlayerId, _GoodsId}, PNum} ->
%% 													?DEBUG("PlayerId:~p, APList:~p, Num:~p, PNum:~p", [PlayerId, APList, Num, PNum]),
													case Num =< ?AWARDGOODS_NUM_LIMIT andalso PNum =< ?AWARDGOODS_NUM_LIMIT andalso (PNum + Num) =< ?AWARDGOODS_NUM_LIMIT of
														false ->
															[6, GoodsId, 0];		%%超过数量了
														true ->
															spawn(fun() -> lib_skyrush:sky_award_mail(GoodsId, Member#ets_guild_member.player_name,Num) end),
%% 															更新内存和数据库数据(测试时，把一下代码屏蔽，用于 多次发物品)
															NewAPList = util:term_to_string(lists:keyreplace({PlayerId, GoodsId}, 1, APList, {{PlayerId, GoodsId}, PNum+Num})),
															NewNum = GNum - Num,
															NewAward = util:term_to_string(lists:keyreplace(GoodsId, 1, Award, {GoodsId, NewNum})),
															ValueList = [{sky_award, NewAward}, {a_plist, NewAPList}],
															FieldList = [{id, GuildId}],
															db_agent:update_sky_goods(ValueList, FieldList),
															NewGuild = Guild#ets_guild{sky_award = NewAward,
																					   a_plist = NewAPList},
															lib_guild_inner:update_guild(NewGuild),
															
															[1, GoodsId, NewNum]  		%%返回结果
													end
											end
									end
							end
					end
			end
	end.

%% -----------------------------------------------------------------
%% 39028 氏族战奖励	物品自动分配
%% -----------------------------------------------------------------
assign_goods_auto(GuildId) ->
	case lib_guild_inner:get_guild(GuildId) of
		[] ->
			0;
		Guild ->
			#ets_guild{jion_ltime = LJTime} = Guild,
			Result = check_operate_ok(LJTime),
			GMems = get_sky_f_members(GuildId),
			if 
				Result =/= 1 ->
					2;%%不在合法的范围里操作
				GMems =:= [] ->
					1;%%不用分配了
				true ->
					Award = util:string_to_term(tool:to_list(Guild#ets_guild.sky_award)),
					APList = util:string_to_term(tool:to_list(Guild#ets_guild.a_plist)),
					SortGMems = %%排序
						lists:sort(fun(ElemA, ElemB) ->
										   ElemA#guild_mem_skyrush_rank.feats >= ElemB#guild_mem_skyrush_rank.feats
								   end, GMems),
%% 					对每一排物品进行自动分配
					assign_auto(SortGMems, Award, APList),
%% 					更新内存和数据库数据(测试时，把一下代码屏蔽，用于多次发物品)
					NewAPList = util:term_to_string([]),
					NewAward = util:term_to_string(?SKYRUSH_AWARD_ZERO),
					ValueList = [{sky_award, NewAward}, {a_plist, NewAPList}],
					FieldList = [{id, GuildId}],
					db_agent:update_sky_goods(ValueList, FieldList),
					NewGuild = Guild#ets_guild{sky_award = NewAward,
											   a_plist = NewAPList},
					lib_guild_inner:update_guild(NewGuild),
					
					1		%%返回结果
			end
	end.
			
			
%%用来发送氏族战物品奖励的邮件接口
sky_award_mail(GoodsId, PlayerName, Num) ->
	Title = "神岛空战奖励",
	Content = io_lib:format("您在神岛空站期间表现神勇，杀敌无数，特发此奖。", []),
	mod_mail:send_sys_mail([tool:to_list(PlayerName)], Title, Content, 0, GoodsId, Num, 0,0).

%%检查是否合法的请求或者其他数据的时机是否合法
check_operate_ok(LJTime) ->
	NowTime = util:unixtime(),
	NowSec = util:get_today_current_second(),
%% 	?DEBUG("NowSec:~p", [NowSec]),
	%%配置表
	[WeekDate, SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = get_start_end_time(),
	%%判断今天星期几
	Date = util:get_date(),
	%%是否要开氏族战
	Judge = lists:member(Date, WeekDate),
	%%获取除了今天的最近开战的星期
	LastDate = get_last_skyrush_week(WeekDate, Date, lists:last(WeekDate)),
	%%上次开战的星期
	{{Year, Month, Day}, _Time}= util:seconds_to_localtime(LJTime),
	LJDate = calendar:day_of_the_week({Year, Month, Day}),
	DiffTime = NowTime - LJTime,
	case LJDate =:= LastDate andalso (DiffTime < 7*24*3600) of
		true ->
			case Judge =:= true andalso NowSec >= (SKY_RUSH_START_TIME - 3600) andalso NowSec =< SKY_RUSH_END_TIME of
				true ->%%到了过期的时间，直接更新清除数据
					2;
				false ->%%其他的时间，随便看数据吧
					1
			end;
		false ->%%最近的那次没有参加，所以返回空
			3
	end.
	
assign_auto(_GMems, [], _APList) ->
	ok;
assign_auto(GMems, [{_GoodsId, 0}|Award], APList) ->
	assign_auto(GMems, Award, APList);
assign_auto(GMems, [{GoodsId, Num}|Award], APList) ->
	PlayerList = assign_elem_auto(GMems, GMems, GoodsId, Num, APList, [], 0),%%自动分配
%% 	?DEBUG("PlayerList is: ~p", [PlayerList]),
%% 	开始发邮件
	spawn(fun() ->
				  lists:foreach(fun(Elem) ->
										{_ELemPlayerId, ELemPlayerName, ELemGoodsId, ELemNum} = Elem,
										sky_award_mail(ELemGoodsId, ELemPlayerName, ELemNum)
								end,
								PlayerList) end),
	assign_auto(GMems, Award, APList).

assign_elem_auto(_GMems, _GMemsBase, _GoodsId, 0, _APlist, PlayerList, _Count) ->
	PlayerList;
assign_elem_auto([], GMemsBase, GoodsId, Num, APlist, PlayerList, Count) when length(GMemsBase) =< Count ->
	assign_elem_auto_inner2(GMemsBase, GMemsBase, GoodsId, Num, APlist, PlayerList);
assign_elem_auto([], GMemsBase, GoodsId, Num, APlist, PlayerList, Count) ->
	assign_elem_auto(GMemsBase, GMemsBase, GoodsId, Num, APlist, PlayerList, Count);
assign_elem_auto([Mem|GMems], GMemsBase, GoodsId, Num, APlist, PlayerList, Count) ->
	#guild_mem_skyrush_rank{player_id = PlayerId,
							player_name = PlayerName} = Mem,
	case lists:keyfind({PlayerId, GoodsId}, 1, APlist) of
		false ->
			AwardNum = 0,%%手动分配的数量
			GiveNum = util:ceil(Num/10),
			assign_elem_auto_inner1(AwardNum, GiveNum, PlayerId, PlayerName, GMems, 
								   GMemsBase, GoodsId, Num, APlist, PlayerList, Count);
		{{_PlayerId, _GoodsId}, AwardNum} ->
			GiveNum = util:ceil(Num/10),
			assign_elem_auto_inner1(AwardNum, GiveNum, PlayerId, PlayerName, GMems, 
								   GMemsBase, GoodsId, Num, APlist, PlayerList, Count)
	end.
			
			
%% 有限制的把物品分配下去(过去手动分配的物品数量，当前可以分配的物品数量，玩家Id，玩家名字，
%% 排行榜，排行榜，物品Id，物品剩余数量，过去拿过物品的玩家列表，
%% 定义的分配玩家列表，已经爆满的玩家数量)
assign_elem_auto_inner1(AwardNum, GiveNum, PlayerId, PlayerName, GMems, 
					   GMemsBase, GoodsId, Num, APlist, PlayerList, Count) ->
	case lists:keyfind(PlayerId, 1, PlayerList) of
		false ->%%之前没手动分配过的
			case GiveNum =< ?AWARDGOODS_NUM_LIMIT of
				true ->
					NewPlayerList = [{PlayerId, PlayerName, GoodsId, GiveNum}|PlayerList],
					NewCount = Count,
					NewNum = Num - GiveNum,
					assign_elem_auto(GMems, GMemsBase, GoodsId, NewNum, APlist, NewPlayerList, NewCount);
				false ->%%需要分配的物品太多啦，先分配最大数
					NewPlayerList = [{PlayerId, PlayerName, GoodsId, ?AWARDGOODS_NUM_LIMIT}|PlayerList],
					NewCount = Count + 1,	%%爆满了，+1
					NewNum = Num - GiveNum,
					assign_elem_auto(GMems, GMemsBase, GoodsId, NewNum, APlist, NewPlayerList, NewCount)
			end;
		{_PlayerId, _PlayerName, _GoodsId, GiveNumOld} ->%%之前手动分配过的了
			if
				GiveNumOld + AwardNum >= ?AWARDGOODS_NUM_LIMIT ->
					NewCount = Count +1,	%%爆满了，+1
					assign_elem_auto(GMems, GMemsBase, GoodsId, Num, APlist, PlayerList, NewCount);
				GiveNum + AwardNum + GiveNumOld >= ?AWARDGOODS_NUM_LIMIT ->
					NewPlayerList = lists:keyreplace(PlayerId, 1, PlayerList, {PlayerId, PlayerName, GoodsId, ?AWARDGOODS_NUM_LIMIT}),
					NewCount = Count +1,	%%爆满了，+1
					NewNum = Num - (?AWARDGOODS_NUM_LIMIT - GiveNumOld - AwardNum),
					assign_elem_auto(GMems, GMemsBase, GoodsId, NewNum, APlist, NewPlayerList, NewCount);
				true ->
					NewPlayerList = lists:keyreplace(PlayerId, 1, PlayerList, {PlayerId, PlayerName, GoodsId, GiveNum + GiveNumOld}),
					NewCount = Count,
					NewNum = Num - GiveNum,
					assign_elem_auto(GMems, GMemsBase, GoodsId, NewNum, APlist, NewPlayerList, NewCount)
			end
	end.
%%没限制的把物品分配下去
assign_elem_auto_inner2(_GMems, _GMemsBase, _GoodsId, 0, _APlist, PlayerList) ->
	PlayerList;
assign_elem_auto_inner2([], GMemsBase, GoodsId, Num, APlist, PlayerList) when Num =/= 0 ->
	assign_elem_auto_inner2(GMemsBase, GMemsBase, GoodsId, Num, APlist, PlayerList);
assign_elem_auto_inner2([Mem|GMems], GMemsBase, GoodsId, Num, APlist, PlayerList) ->
	#guild_mem_skyrush_rank{player_id = PlayerId,
							player_name = PlayerName} = Mem,
	GiveNum = util:ceil(Num/10),
	case lists:keyfind(PlayerId, 1, PlayerList) of
		false ->%%直接新增
			NewPlayerList = [{PlayerId, PlayerName, GoodsId, GiveNum}|PlayerList],
			NewNum = Num - GiveNum,
			assign_elem_auto_inner2(GMems, GMemsBase, GoodsId, NewNum, APlist, NewPlayerList);
		{_PlayerId, _PlayerName, _GoodsId, GiveNumOld} ->
			NewPlayerList = lists:keyreplace(PlayerId, 1, PlayerList, {PlayerId, PlayerName, GoodsId, GiveNum + GiveNumOld}),
			NewNum = Num - GiveNum,
			assign_elem_auto_inner2(GMems, GMemsBase, GoodsId, NewNum, APlist, NewPlayerList)
	end.
					
			
gmcmd_update_skyaward(GuildName) ->
	case lib_guild_inner:get_guild_by_name(GuildName) of
		[] ->
			skip;
		Guild ->
			Award = util:term_to_string(lists:nth(1, ?SKYRUSH_AWARD_GOODS)),
			APList = util:term_to_string([]),
			ValueList = [{sky_award, Award}, {a_plist, APList}],
			FieldList = [{id, Guild#ets_guild.id}],
			db_agent:update_sky_goods(ValueList, FieldList),
			NewGuild = Guild#ets_guild{sky_award = Award,
									   a_plist = APList},
			lib_guild_inner:update_guild(NewGuild)
	end.
			
			
%%通知符合条件未报名空战的氏族报名空战
notice_to_sign_up()->
	%%获取氏族列表
	MS = ets:fun2ms(fun(T) when T#ets_guild.sky_apply =/= 1 andalso T#ets_guild.level>=3->
							T end),
	GuildList = get_guilds_by_etsms(MS),
	loop_notice(GuildList),
	ok.

loop_notice([])->
	ok;
loop_notice([Guild|GuildList])->
	%%获取氏族成员列表
	MS = ets:fun2ms(fun(T) when T#ets_guild_member.guild_id=:=Guild#ets_guild.id ,T#ets_guild_member.guild_position=< 3->
							T end),
	MemberInfoList = ets:select(?ETS_GUILD_MEMBER, MS),
	MemberIdList = [MemberInfo#ets_guild_member.player_id||MemberInfo<-MemberInfoList],
%% 	io:format("MemberId~p~n",[MemberIdList]),
	notice(MemberIdList),
	loop_notice(GuildList).


notice([])->
	ok;
notice([PlayerId|IdList])->
	if PlayerId > 0->
		case lib_player:get_online_info(PlayerId) of
			[]->skip;
			PlayerStatus->
				{ok,BinData} = pt_39:write(39029,[600-5]),
				lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,BinData)
		end;
	   true->skip
	end,
	notice(IdList).

%% 检查该氏族是否已经报名氏族战
check_sign_up(GuildId, SendPid, Lv)->
	[WeekDate, SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = get_start_end_time(),
	%%是否要开氏族战
	case lib_skyrush:tobe_opening_skyrush(WeekDate) of
		true ->
			NowSec = util:get_today_current_second(),
			NoticeSignUp = get_notice_sign_up_time(),
			if 
				NowSec > NoticeSignUp andalso NowSec < NoticeSignUp + 300->
				   MS = ets:fun2ms(fun(T) when T#ets_guild.id =:= GuildId 
						 andalso T#ets_guild.sky_apply =/= 1 
						 andalso T#ets_guild.level >= 3->
							T end),
				   case get_guilds_by_etsms(MS) of
					   	[] ->
							skip;
					   	_ ->
						   {ok,BinData} = pt_39:write(39029,[SKY_RUSH_START_TIME - NowSec]),
						   lib_send:send_to_sid(SendPid, BinData)
				   end;
				NowSec >= (SKY_RUSH_START_TIME + 5*60 + 10) andalso NowSec  =< (SKY_RUSH_END_TIME - 20) andalso Lv >= 35 ->%%神岛空战已经开始，在结束的30秒之前通知一下
					MS = ets:fun2ms(fun(T) when T#ets_guild.id =:= GuildId 
										 andalso T#ets_guild.sky_apply =:= 1 
										 andalso T#ets_guild.level >= 3->
											T end),
					case get_guilds_by_etsms(MS) of
						[] ->
							skip;
						_ ->%%通知进入神岛空战
						   {ok,BinData} = pt_39:write(39030,[]),
						   lib_send:send_to_sid(SendPid, BinData)
				   end;
			   	true -> 
					skip
			end;
		false -> 
			skip
	end,
	ok.

%%通知参加神岛空战的的所有成员
notice_all_sky_player(Gids) ->
	lists:foreach(fun(Gid) ->
						  lib_guild_inner:send_guild(0, 0, Gid, notice_sky_player, [])
				  end, Gids).
%%玩家进程处理神岛空战的通知
cast_notice_sky_player(_Param, Status) ->
%% 	?DEBUG("cast_notice_sky_player", []),
	case Status#player.lv < 35 of
		false ->
	{ok,BinData39030} = pt_39:write(39030,[]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData39030);
		true ->
			skip
	end,
	Status.

%%检查是否能够进行一些在空战时不能执行的操作
%% return 
%% 		true:正在空战中，不能操作
%% 		false:正常时间，可以操作
check_sky_doornot() ->
	%%配置表
	[WeekDate, SKY_RUSH_START_TIME, SKY_RUSH_END_TIME] = lib_skyrush:get_start_end_time(),
	NowSec = util:get_today_current_second(),
	%%是否要开氏族战
	Judge = tobe_opening_skyrush(WeekDate),
%% 	?DEBUG("check do or not:~p", [Judge]),
	Judge =:= true andalso NowSec >= SKY_RUSH_START_TIME - 10 andalso NowSec =< SKY_RUSH_END_TIME + 5 * 60.

%%判断是否要开神岛空战
tobe_opening_skyrush(WeekDate) ->
	%%判断今天星期几
	Date = util:get_date(),
	%%是否要开氏族战
	lists:member(Date, WeekDate).

%% *******************************************************************************
%%用于即时修改氏族一些数据
set_guild_data(GuildId, Param) ->
	gen_server:cast(mod_guild:get_mod_guild_pid(), 
					{apply_cast, 
					 lib_skyrush, 
					 set_guild_data_inline, 
					 [GuildId, Param]}).
set_guild_data_inline(GuildId, Param) ->
	case lib_guild_inner:get_guild(GuildId) of
		[] ->
			skip;
		Guild ->
			NewGuild = handle_set_guild_data(Guild, Param),
			lib_guild_inner:update_guild(NewGuild),
			WhereList = [{id, Guild#ets_guild.id}],
			db_agent:update_sky_guild(guild, Param, WhereList)
	end,
	io:format("good! it is OK!").
handle_set_guild_data(Guild, []) ->
	Guild;
handle_set_guild_data(Guild, [H|T]) ->
	{Field, Value} = H,
	NewGuild = 
		case Field of
			member_num ->
				Guild#ets_guild{member_num = Value};
			member_capacity ->
				Guild#ets_guild{member_capacity = Value};
			reputation ->
				Guild#ets_guild{reputation = Value};
			boss_sv ->
				Guild#ets_guild{boss_sv = Value};
			funds ->
				Guild#ets_guild{funds = Value};
			deputy_chief_num ->
				Guild#ets_guild{deputy_chief_num = Value};
			level ->
				Guild#ets_guild{level = Value};
			skills ->
				Guild#ets_guild{skills = Value};
			_ ->
				Guild
		end,
	handle_set_guild_data(NewGuild, T).
%% *******************************************************************************