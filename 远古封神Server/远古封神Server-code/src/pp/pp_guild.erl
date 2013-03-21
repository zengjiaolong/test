%%%--------------------------------------
%%% @Module  : pp_guild
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 氏族处理接口  
%%%--------------------------------------
-module(pp_guild).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").
-include("qlc.hrl").
-include("guild_info.hrl").

-define(GUILD_TASK_ID, 1000).
-import(data_guild, [get_guild_config/2]).

%%=========================================================================
%% 接口函数
%%=========================================================================

%% -----------------------------------------------------------------
%% 40001 创建氏族  
%% -----------------------------------------------------------------
handle(40001, Status, [GuildName, BuildCoin]) ->
	case tool:is_operate_ok(pp_40001, 2) of
		true ->
    [Result, GuildId] = mod_guild:create_guild(Status, [GuildName, BuildCoin]),
%%	?DEBUG("****** handle create_guild Result[~p], GuildId[~p], MoneyLeft[~p] *******", [Result, GuildId, MoneyLeft]),
    if  % 创建成功
        Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_40:write(40001, [Result, GuildId]),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			%%扣钱
			case BuildCoin of
				0 ->
					StatusCoin = Status;
				_ ->
					StatusCoin = lib_goods:cost_money(Status, BuildCoin, coin, 4001)
			end,
            % 返回新状态
            Status1 = StatusCoin#player{guild_id = GuildId,
									guild_name = tool:to_binary(GuildName),
									guild_position = 1},
			lib_player:send_player_attribute(Status1, 2),
			%%做加入氏族的成就统计
			lib_achieve:check_achieve_finish(Status#player.other#player_other.pid_send,
											 Status#player.id, 604, [1]),
			case Status#player.lv >= 35 of
				true ->%%加氏族
					lib_guild_wish:join_guild(Status1#player.id, Status1#player.nickname, Status1#player.sex, Status1#player.career, Status1#player.guild_id);
				false ->
					skip
			end,
			%%传闻广播
			RealmName = goods_util:get_realm_to_name(Status1#player.realm),
			ConTent = io_lib:format("天地变色，风起云涌，<font color='#FFFF32'>~s</font>的玩家[<a href='event:1, ~p, ~s, ~p, ~p'><font color='#FFFF32'><u>~s</u></font></a>]创建了名为[<font color='#FFFF32'>~s</font>]的氏族，号召各路英雄豪杰火速响应！<a href='event:5,~p'><font color='#00FF33'><u>》》我要加入《《<<</u></font></a>",
									[RealmName, Status1#player.id, Status1#player.nickname, Status1#player.career, Status1#player.sex, Status1#player.nickname, 
									 Status1#player.guild_name, Status1#player.guild_id]),
			lib_chat:broadcast_sys_msg(6, ConTent),
            {ok, Status1};            
        % 创建失败
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40001, [Result, 0]),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            ok
    end;
		false ->
            ok
	end;
    
%% -----------------------------------------------------------------
%% 40002 解散氏族  
%% -----------------------------------------------------------------
handle(40002, Status, [GuildId]) ->
	%%%%检查是否能够进行一些在空战时不能执行的操作
	CheckEnter = lib_skyrush:check_sky_doornot(),
	case CheckEnter of
		false ->
	Result = mod_guild:confirm_disband_guild(Status, [GuildId]),
	if  % 解散成功
        Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_40:write(40002, Result),
             lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            % 返回新状态
            Status1 = Status#player{guild_id = 0,
									guild_name = <<>>,
									guild_position = 0,
									quit_guild_time = 0,
									guild_title = <<>>,
									guild_depart_name = <<>>,
									guild_depart_id = 0,
									other = 
										Status#player.other#player_other{guild_feats = 0,	%%氏族功勋变回0
																		 g_alliance = []	%%联盟中的氏族Id清空
																		}},
			gen_server:cast(Status1#player.other#player_other.pid_task,{'guild_task_del',Status1}),
			%%处理氏族祝福数据
			lib_guild_wish:leave_guild(Status#player.id),
			%%解散氏族时，传出领地中的所有的成员
			mod_guild_manor:send_out_all_manor(GuildId),
			%%氏族祝福数据清理
			case Status1#player.lv >= 35 of
				true ->
					lib_guild_wish:leave_guild(Status1#player.id);
				false ->
					skip
			end,
            {ok, Status1};
        % 解散失败
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40002, Result),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            ok
    end;
		true ->
			% 发送回应
            {ok, BinData} = pt_40:write(40002, 6),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            ok
	end;

%% -----------------------------------------------------------------
%% 40004 申请加入 
%% -----------------------------------------------------------------
handle(40004, Status, [GuildId]) ->
    [Result] = mod_guild:apply_join_guild(Status, [GuildId]),
    if  % 申请成功
        Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_40:write(40004, Result),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            ok;
        % 申请失败
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40004, Result),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 40005 审批加入 
%% -----------------------------------------------------------------
handle(40005, Status, [HandleResult, ApplyList]) ->
	if
		Status#player.guild_id =:= 0 ->%%没氏族
			[Result, Num] = [3, 0];
		Status#player.guild_position > 7 ->%%没权限
			[Result, Num] = [4, 0];
		true ->
			[Result, Num] =  mod_guild:approve_guild_apply(Status, [HandleResult, ApplyList])
	end,
	%% 发送回应
	{ok, BinData} = pt_40:write(40005, [Result, Num]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;

%% -----------------------------------------------------------------
%% 40006 邀请加入
%% -----------------------------------------------------------------
handle(40006, Status, [PlayerName]) ->
    [Result, PlayerId] = mod_guild:invite_join_guild(Status, [PlayerName]),
    if  % 邀请成功
        Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_40:write(40006, Result),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            % 通知被邀请人
			lib_guild_inner:send_msg_to_player(PlayerId, guild_invite_join, 
										 [Status#player.guild_id, Status#player.guild_name, Status#player.id, Status#player.nickname]),
            % 同时邮件通知给被邀请人
            lib_guild:send_guild_mail(guild_invite_join, [PlayerName, Status#player.nickname, Status#player.guild_name]),
            ok;
        % 邀请失败
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40006, Result),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 40007 回应氏族邀请 
%% -----------------------------------------------------------------
handle(40007, Status, [GuildId, ResponseResult]) ->
    [Result, GuildName, GuildPosition, RecommenderId, RecommenderName] = mod_guild:response_invite_guild(Status, [GuildId, ResponseResult]),
    if  % 回应成功且加入氏族
        ((Result == 1) and (ResponseResult == 1)) ->
            % 发送回应
            {ok, BinData} = pt_40:write(40007, [Result, ResponseResult, GuildId, GuildName, GuildPosition]),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			%%做加入氏族的成就统计
			lib_achieve:check_achieve_finish(Status#player.other#player_other.pid_send,
											 Status#player.id, 604, [1]),
			%%更新氏族聊天面板信息
			gen_server:cast(mod_guild:get_mod_guild_pid(), {'BROADCAST_GUILD_GROUP',Status#player.guild_id}),
            % 返回新状态
            Status1 = Status#player{guild_id = GuildId,
                                    guild_name = tool:to_binary(GuildName),
                                    guild_position 	= GuildPosition},
            {ok, Status1};
        % 回应成功且拒绝入帮
        ((Result == 1) and (ResponseResult == 0)) ->
            % 发送回应
            {ok, BinData} = pt_40:write(40007, [Result, ResponseResult, GuildId, GuildName, GuildPosition]),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            % 向邀请人回应信息
			case lib_player:is_online(RecommenderId) of
				[] ->%%不在线了
					void;
				_Pid ->
					lib_guild_inner:send_msg_to_player(RecommenderId, guild_reject_invite, [Status#player.id, Status#player.nickname])
			end,
			%%想邀请人发邮件
			 lib_guild:send_guild_mail(guild_reject_invite, 
									   [RecommenderName, Status#player.id, Status#player.nickname, 
										Status#player.guild_id, Status#player.guild_name]),
            ok;
        % 创建失败
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40007, [Result, ResponseResult, GuildId, GuildName, GuildPosition]),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 40008 开除帮众
%% PlayerId:指定的氏族成员
%% -----------------------------------------------------------------
handle(40008, Status, [PlayerId]) ->
	%%%%检查是否能够进行一些在空战时不能执行的操作
	CheckEnter = lib_skyrush:check_sky_doornot(),
	case CheckEnter of
		false ->
    [Result, PlayerName] = mod_guild:kickout_guild(Status, [PlayerId]),
    if  % 踢出成功
        Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_40:write(40008, Result),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            % 通知氏族成员
            lib_guild_inner:send_msg_to_player(PlayerId, guild_kickout, [PlayerId, PlayerName, Status#player.guild_id, Status#player.guild_name]),
			%%如果在领地里面，则主动传出
			mod_guild_manor:quit_guild_manor(0, {PlayerId, Status#player.guild_id, 1}),
            % 邮件通知给被踢出人
            lib_guild:send_guild_mail(guild_kickout, [PlayerId, PlayerName, Status#player.guild_id, Status#player.guild_name]),
			%%更新氏族聊天面板信息
			gen_server:cast(mod_guild:get_mod_guild_pid(), {'BROADCAST_GUILD_GROUP',Status#player.guild_id}),
            ok;
        % 踢出失败
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40008, Result),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            ok
    end;
		true ->
			% 发送回应
            {ok, BinData} = pt_40:write(40008, 10),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            ok
	end;

%% -----------------------------------------------------------------
%% 40009 退出氏族 
%% -----------------------------------------------------------------
handle(40009, Status, []) ->
	%%检查是否能够进行一些在空战时不能执行的操作
	CheckEnter = lib_skyrush:check_sky_doornot(),
	case CheckEnter of
		false ->
	QuitTime = util:unixtime(),
    Result = mod_guild:quit_guild(Status, [QuitTime]),
    if  % 退出成功
        Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_40:write(40009, Result),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			% 返回新状态
            Status1 = Status#player{guild_id       = 0,
                                    guild_name     = <<>>,
                                    guild_position = 0,
									quit_guild_time = QuitTime,
									other = Status#player.other#player_other{g_alliance = [],	%%联盟中的氏族Id清空
																			 guild_feats = 0}%%氏族功勋变回0
								   },
			%%如果在领地里面，则主动传出
			mod_guild_manor:quit_guild_manor(1, {Status#player.other#player_other.pid_scene, Status#player.scene,
												 Status#player.id,Status#player.guild_id, 1}),
			%%玩家退出帮派，处理帮派任务
%% 			lib_task:abnegate_guild_task(Status1),
			gen_server:cast(Status#player.other#player_other.pid_task,{'guild_task_del',Status1}),
			%%处理氏族祝福数据
			lib_guild_wish:leave_guild(Status#player.id),
			%%更新氏族聊天面板信息
			gen_server:cast(mod_guild:get_mod_guild_pid(), {'BROADCAST_GUILD_GROUP',Status#player.guild_id}),
            {ok, Status1};
        % 退出失败
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40009, Result),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            ok
    end;
		true ->
			% 发送回应
            {ok, BinData} = pt_40:write(40009, 5),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            ok
	end;

%% -----------------------------------------------------------------
%% 40010 获取氏族列表	
%% -----------------------------------------------------------------
handle(40010, Status, [Realm, Type, Page, GuildName, ChiefName]) ->
%% 	?DEBUG("40010, Realm:~p, Type~p, Page:~p, GuildName:~p, ChiefName:~p", [Realm, Type, Page, GuildName, ChiefName]),
	case tool:is_operate_ok(pp_40010, 1) of
		true ->%%1秒钟的间隔
			if
				Type =:= 1 orelse (Type =:= 2 andalso Realm > 0 andalso Realm < 4)  andalso Page >= 1 ->%%只有1，或者2才会做操作
					mod_guild:list_guild(Status, [Realm, Type, Page, GuildName, ChiefName]),
					ok;
				true ->
					ok
			end;
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 40011 获取氏族成员列表 
%% -----------------------------------------------------------------
handle(40011, Status, [GuildId]) ->
	mod_guild:list_guild_member(Status, [GuildId]),
	ok;

%% -----------------------------------------------------------------
%% 40012 获取氏族申请列表  
%% -----------------------------------------------------------------
handle(40012, Status, [GuildId]) ->
	mod_guild:list_guild_apply(Status, [GuildId]),
    ok;

%% -----------------------------------------------------------------
%% 40013 获取氏族邀请列表  
%% -----------------------------------------------------------------
handle(40013, Status, []) ->
	mod_guild:list_guild_invite(Status, [Status#player.id]),
    ok;

%% -----------------------------------------------------------------
%% 40014 查看氏族信息	
%% -----------------------------------------------------------------
handle(40014, Status, [GuildId]) -> 
    [Result, Data] = mod_guild:get_guild_info(Status, [GuildId]),
    {ok, BinData} = pt_40:write(40014, [Result, Data]),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
    ok;

%% -----------------------------------------------------------------
%% 40016 修改氏族公告 	
%% -----------------------------------------------------------------
handle(40016, Status, [GuildId, Announce]) ->
    [Result] = mod_guild:modify_guild_announce(Status, [GuildId, Announce]),
    {ok, BinData} = pt_40:write(40016, Result),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	%%更新氏族聊天面板信息
	gen_server:cast(mod_guild:get_mod_guild_pid(), {'BROADCAST_GUILD_GROUP',Status#player.guild_id}),
    ok;


%% -----------------------------------------------------------------
%% 40018 禅让族长
%% -----------------------------------------------------------------
handle(40018, Status, [PlayerId]) ->
	%%检查是否能够进行一些在空战时不能执行的操作
	CheckEnter = lib_skyrush:check_sky_doornot(),
	case CheckEnter of
		false ->
    [Result, PlayerName] = mod_guild:demise_chief(Status, [PlayerId]),
    if % 禅让成功
        Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_40:write(40018, Result),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            % 通知氏族成员
            lib_guild:send_guild(1, Status#player.id, Status#player.guild_id, 
								 guild_demise_chief, [Status#player.id, Status#player.nickname, PlayerId, PlayerName]),
           %向整个氏族成员发送信件
			lib_guild:send_mail_guild_everyone(1, Status#player.id, Status#player.guild_id, guild_demise_chief,
											   [Status#player.nickname, PlayerName, Status#player.guild_name]),
			%%更新氏族聊天面板信息
			gen_server:cast(mod_guild:get_mod_guild_pid(), {'BROADCAST_GUILD_GROUP',Status#player.guild_id}),
			% 返回新状态
            Status1 = Status#player{guild_position = 12},
            {ok, Status1};
        % 创建失败
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40018, Result),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            ok
    end;
		true ->
			 % 发送回应
            {ok, BinData} = pt_40:write(40018, 8),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            ok
    end;
%% -----------------------------------------------------------------
%% 40019 捐献钱币
%% -----------------------------------------------------------------
handle(40019, Status, [GuildId, Type]) ->
	case tool:is_operate_ok(pp_40019, 1) of
		true ->
			if Type < 1 orelse Type > 5 ->
				   {ok, BinData} = pt_40:write(40019, [0, 0]),
				   lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
				   ok;
			   true ->
				   Num = data_guild:get_donate_money(Type),
				   [Result, NewStatus] = mod_guild:donate_money(Status, [GuildId, Num]),
				   if  % 捐献成功
					   Result == 1 ->
						   % 发送回应
						   {ok, BinData} = pt_40:write(40019, [Result, Num]),
						   lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
						   % 返回新状态
						   lib_player:send_player_attribute(NewStatus, 2),
						   {ok, NewStatus};
					   true ->% 捐献失败
						   % 发送回应
						   {ok, BinData} = pt_40:write(40019, [Result, Num]),
						   lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
						   ok
				   end
			end;
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 40020 氏族升级请求
%% -----------------------------------------------------------------
handle(40020, Status, [GuildId]) ->
	[Result, NewExp, NeedTime, StartTime] = mod_guild:guild_upgrade(Status,[GuildId]),
	case Result == 1 of
		true ->
			 {ok, BinData} = pt_40:write(40020, [Result, NewExp, NeedTime, StartTime]),
			 lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			 ok;
		false ->
			 {ok, BinData} = pt_40:write(40020, [Result, NewExp, NeedTime, StartTime]),
             lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			 ok
	end;
%% -----------------------------------------------------------------
%% 40022 辞去官职
%% -----------------------------------------------------------------
handle(40022, Status, [GuildId]) ->
	%%检查是否能够进行一些在空战时不能执行的操作
	CheckEnter = lib_skyrush:check_sky_doornot(),
	case CheckEnter of
		false ->
    [Result, NewPosition] = mod_guild:resign_position(Status, [GuildId]),
    if
        % 辞去成功
        Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_40:write(40022, Result),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			%%更新氏族聊天面板信息
			gen_server:cast(mod_guild:get_mod_guild_pid(), {'BROADCAST_GUILD_GROUP',Status#player.guild_id}),
            %返回新状态
            Status1 = Status#player{guild_position = NewPosition,
									guild_depart_name = <<>>,
									guild_depart_id = 5},
            {ok, Status1};
        % 创建失败
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40022, Result),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            ok
    end;
		true ->
		% 发送回应
            {ok, BinData} = pt_40:write(40022, 7),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            ok
    end;



%% -----------------------------------------------------------------
%% 成员职务设置
%% -----------------------------------------------------------------
handle(40028, Status, [GuildId, PlayerId, Post, DepartId, GuildTitle, DepartName]) ->
	[Result, PlayerName, NewPosition, PositionName] = mod_guild:set_member_post(Status, [GuildId, PlayerId, Post, DepartId, GuildTitle, DepartName]),
	case Result of
		1 ->
			{ok, BinData} = pt_40:write(40028, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			%%相对应的成员发即时信息	
			lib_guild_inner:send_msg_to_player(PlayerId, guild_set_position, 
											   [1, Status#player.id, Status#player.nickname, NewPosition, 
												GuildTitle, DepartId, DepartName,PositionName]),
			%%更新氏族聊天面板信息
			gen_server:cast(mod_guild:get_mod_guild_pid(), {'BROADCAST_GUILD_GROUP',Status#player.guild_id}),
			%%邮件通知
			Param = [PlayerName, Status#player.nickname, PositionName],
			lib_guild:send_guild_mail(guild_set_position, Param),
            ok;
		20 ->
			lib_guild_inner:send_msg_to_player(PlayerId, guild_set_position, 
										 [2, Status#player.id, Status#player.nickname, NewPosition, GuildTitle, DepartId, DepartName,PositionName]),
			{ok, BinData} = pt_40:write(40028, [1]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok;
        _ ->
            {ok, BinData} = pt_40:write(40028, [Result]),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            ok
    end;


%% -----------------------------------------------------------------
%% 40029 修改氏族堂堂名
%% -----------------------------------------------------------------
handle(40029, Status, [GuildId, DepartId, DepartName, DepartsNames]) ->
	[Result] = mod_guild:modify_guild_depart_name(Status, [GuildId, DepartId, DepartName, DepartsNames]),
	case Result of
		1 ->
			{ok, BinData} = pt_40:write(40029, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            ok;
		_ ->
			{ok, BinData} = pt_40:write(40029, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok
	end;

%% -----------------------------------------------------------------
%% 40030 获取好友列表
%% -----------------------------------------------------------------
handle(40030, Status, []) ->
    L = lib_guild_inner:get_ets_rela_record(Status#player.id, 1),
    L1 = [pp_relationship:pack_friend_list_guild(X)||X <- L],
	L2 = lists:delete([], L1),
    {ok,BinData} = pt_40:write(40030, [L2]),
    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;

%% -----------------------------------------------------------------
%% 获取氏族技能信息
%% -----------------------------------------------------------------
handle(40031, Status, [GuildId]) ->
	mod_guild:get_guild_skills_info(Status, [GuildId]),
	ok;

%% -----------------------------------------------------------------
%% 氏族技能升级
%% -----------------------------------------------------------------
handle(40032, Status, [GuildId, SkillId, Level]) ->
	case SkillId >= 1 andalso SkillId =< 10 of%%屏蔽不是1--10的技能id升级
		true ->
	[Result, NewLevel] = mod_guild:guild_skills_upgrade(Status, [GuildId, SkillId, Level]),
	case Result of
		1 ->%%升级成功
			SkillName = data_guild:get_skills_names(SkillId),
%% 			Data = [Status#player.guild_name, SkillId, SkillName, NewLevel],
			%%给在线的通知
			lib_guild:send_guild(1, Status#player.id, GuildId, guild_skill_upgrade, 
								 [Status#player.guild_name, SkillId, SkillName, NewLevel]);
%% 			%%全体发邮件(暂时不用了)
%% 			lib_guild:send_mail_guild_everyone(1, Status#player.id, GuildId, guild_skill_upgrade, [Status#player.guild_name, SkillName, NewLevel]);
		_ ->
			void
	end,
	{ok, BinData} = pt_40:write(40032, [Result]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 40033 回氏族领地
%% -----------------------------------------------------------------
handle(40033, Status, []) ->
	case tool:is_operate_ok(pp_40033, 1) of
		true ->
            [Result, RemainTime] = lib_guild_manor:check_use_guild_token(Status),
            {ok, BinData} = pt_40:write(40033, [Result, RemainTime]),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            case Result of
                1 ->
        %% 			lib_guild_manor:mark_manor_enter_coord(0, Status#player.id, 300),
        %% 			pp_scene:handle(12005, Status, 500),
                    lib_guild_manor:enter_manor_scene_40033(Status, 500);
                _ ->
                    ok
            end;
		false ->
			{ok, BinData} = pt_40:write(40033, [0, ?GUILDTOKENTIME]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok
	end;

handle(40034, Status, []) ->
	mod_guild_manor:quit_guild_manor(1, {Status#player.other#player_other.pid_scene, Status#player.scene,
										 Status#player.id,Status#player.guild_id, 0});
%% -----------------------------------------------------------------
%% 40050 获取氏族仓库当前物品总数
%% -----------------------------------------------------------------
handle(40050, Status, [GuildId]) ->
	mod_guild:get_storage_num(Status, GuildId),
	ok;

%% -----------------------------------------------------------------
%% 40051 获取氏族仓库物品列表
%% -----------------------------------------------------------------
handle(40051, Status, [GuildId]) ->
	mod_guild:get_guild_goods(Status, GuildId),
	ok;

%% -----------------------------------------------------------------
%% 40052 取出氏族仓库物品
%% -----------------------------------------------------------------
handle(40052, Status, [GuildId, GoodsId]) ->
%% 	Result = mod_guild_manor:takeout_warehouse_goods(Status, GuildId, GoodsId),
	Result = mod_guild:takeout_warehouse_goods(Status, GuildId, GoodsId),
%% 	io:format("40052**~p\n", [Result]),
	{ok, BinData} = pt_40:write(40052, [Result,GoodsId]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;

%% -----------------------------------------------------------------
%% 40053 放入氏族仓库物品
%% -----------------------------------------------------------------
handle(40053, Status, [GuildId, GoodsId, GoodsTypeId, GoodsNum]) ->
%% 	Result = mod_guild_manor:putin_warehouse_goods(Status, GuildId, GoodsId),
	Result = mod_guild:putin_warehouse_goods(Status, GuildId, GoodsId),
%% 	io:format("40053**~p\n", [Result]),
	{ok, BinData} = pt_40:write(40053, [Result, GoodsId, GoodsTypeId, GoodsNum]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;

%% -----------------------------------------------------------------
%% 40054 获取物品详细信息(仅在氏族模块用)
%% -----------------------------------------------------------------
handle(40054, Status, [GuildId, GoodsId]) ->
%% 	[Result, Info] = mod_guild_manor:get_warehouse_goods_info(Status, GuildId, GoodsId),
	mod_guild:get_warehouse_goods_info(Status, GuildId, GoodsId),
	ok;
	
%% -----------------------------------------------------------------
%% 40017 召唤氏族boss
%% -----------------------------------------------------------------
handle(40017, Status, [Type]) ->
%% 	IsOk = lib_task:is_trigger(?GUILD_TASK_ID, Status),
	IsOk = true,
	case tool:is_operate_ok(pp_40017, 1) of
		true ->
			case Type >= 1 andalso Type =< 3 of
				true ->
					[Result] = mod_guild_manor:guild_call_boss(Status, Type, IsOk),
					{ok, BinData} = pt_40:write(40017, [Result]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					ok;
				false ->%%直接过滤了
					ok
			end;
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 40025 领取福利
%% -----------------------------------------------------------------
handle(40025, Status, []) ->
	case tool:is_operate_ok(pp_40025, 1) of
		true ->
	LTGetWeal = lib_guild_weal:get_weal_lasttime(Status#player.id),
	[Result, NewStatus] = mod_guild_manor:check_get_member_weal(Status, LTGetWeal),
	case Result of
		1 -> 
			{ok, BinData} = pt_40:write(40025, [Result]),
			lib_send:send_to_sid(NewStatus#player.other#player_other.pid_send, BinData),
			lib_player:send_player_attribute2(NewStatus, 2),
			{ok, NewStatus};
		_ ->
			{ok, BinData} = pt_40:write(40025, [Result]),
			lib_send:send_to_sid(NewStatus#player.other#player_other.pid_send, BinData),
			ok
	end;
		false ->
			ok
	end;
%% -----------------------------------------------------------------
%% 40026  获取氏族高级技能信息
%% -----------------------------------------------------------------
handle(40026, Status, [GuildId]) ->
	mod_guild_manor:get_guild_skilltoken(Status, GuildId),
	ok;

%% -----------------------------------------------------------------
%% 40027  高级技能升级 
%% -----------------------------------------------------------------
handle(40027, Status, [GuildId, HSkillId, HKLevel]) ->
	case HSkillId >= 1 andalso HSkillId =< 10 of%%屏蔽不是1--10的技能id升级
		true ->
	case tool:is_operate_ok(pp_40027, 1) of
		true ->
	[Result, NewHKLevel, _ChiefId] = mod_guild_manor:upgrade_h_skill(Status, GuildId, HSkillId, HKLevel),
	case Result of
		1 ->%%升级成功了
%% 			Data = [Status#player.guild_name, SkillId, SkillName, NewLevel],
			{ok, BinData} = pt_40:write(40027, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			%%给在线的通知(包括自己)
			lib_guild:send_guild(0, Status#player.id, GuildId, upgrade_h_skill, 
								 [Status#player.guild_name, HSkillId, NewHKLevel, GuildId]),
			ok;
		_ ->
			{ok, BinData} = pt_40:write(40027, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok
	end;
		false ->
			ok
	end;
		false ->
			ok
	end;

%%-----------------------------------------------------------------
%% 氏族改名
%%-----------------------------------------------------------------
handle(40056,Status,[GuildId, NewGuildName]) ->
	 Result = mod_guild:change_guildname(Status, [GuildId, NewGuildName]),
	 {ok, BinData} = pt_40:write(40056, [Result, GuildId]),
	 lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	 ok;

%% -----------------------------------------------------------------
%% 40057  氏族兼并/归附申请
%% -----------------------------------------------------------------
handle(40057, Status, [TarGId, Type]) ->
	case Type >= 1 andalso Type =< 2 of
		true ->
			Result = mod_guild:union_apply(Status ,TarGId, Type),
%% 			?DEBUG("40057 :~p", [Result]),
			{ok, BinData} = pt_40:write(40057, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok;
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 40058  取消氏族兼并/归附申请
%% -----------------------------------------------------------------
handle(40058, Status, [TarGId]) ->
	case tool:is_operate_ok(pp_40058, 1) of
		true ->%%频率控制
			Result = mod_guild:cancel_union_apply(Status, TarGId),
%% 			?DEBUG("40058 :~p", [Result]),
			{ok, BinData} = pt_40:write(40058, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok;
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 40059  拒绝氏族兼并/归附申请
%% -----------------------------------------------------------------
handle(40059, Status, [TarGId]) ->
	case tool:is_operate_ok(pp_40059, 1) of
		true ->%%频率控制
			Result = mod_guild:refuse_unioin_apply(Status, TarGId),
%% 			?DEBUG("40059 :~p", [Result]),
			{ok, BinData} = pt_40:write(40059, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok;
		false ->
			skip
	end;

%% -----------------------------------------------------------------
%% 40060  同意氏族兼并/归附申请
%% -----------------------------------------------------------------
handle(40060, Status, [TarGId, Type]) ->
	case tool:is_operate_ok(pp_40060, 1) of
		true ->%%频率控制
			Result = mod_guild:agree_union_apply(Status, TarGId, Type),
%% 			?DEBUG("40060 :~p", [Result]),
			{ok, BinData} = pt_40:write(40060, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok;
		false ->
			skip
	end;

%% -----------------------------------------------------------------
%% 40061  氏族联合请求(返回40063或者40062)
%% -----------------------------------------------------------------
handle(40061, Status, []) ->
	{Type, Result} = mod_guild:get_union_info(Status),
	{ok, BinData} = 
		case Type of
			1 ->%%40062
%% 				?DEBUG("40062 :Type:~p, ~p", [Type, Result]),
				pt_40:write(40062, [Result]);
			2 ->%%40063
%% 				?DEBUG("40063 :Type:~p, ~p", [Type, Result]),
				pt_40:write(40063, [Result])
			
		end,
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;
			
	
%% -----------------------------------------------------------------
%% 40064  兼并/依附氏族族长提交成员列表
%% -----------------------------------------------------------------
handle(40064, Status, [Handle, SubmitList]) ->
%% 	?DEBUG("40064", []),
	%%做频率的限制
	case tool:is_operate_ok(pp_40064, 1) of
		true ->
			%%做氏族战期间的时间限制
			%%检查是否能够进行一些在空战时不能执行的操作
			CheckEnter = lib_skyrush:check_sky_doornot(),
			case CheckEnter of
				false ->
					case Handle >= 1 andalso Handle =< 3 of
						true ->
%%							?DEBUG("handle ~p, List:~p", [Handle, SubmitList]),
							Result = mod_guild:submit_union_members(Status, Handle, SubmitList),
							 %%更新氏族聊天面板信息,当且仅当客户端发送2，服务端发回{10,_T,_E}时才更新
							case Result of
								{10,_T,_E} ->
									if Handle =:= 2 ->
										   gen_server:cast(mod_guild:get_mod_guild_pid(), {'OPEN_GUILD_GROUP',Status});
									   true ->
										   skip
									end;
								_Other ->
									skip
							end,
							Result;
						false ->
							Result = {0, 0, 0}
					end;
				true ->
					Result = {9, 0, 0}
			end;
		false ->
			Result = {0, 0, 0}
	end,
%% 	?DEBUG("40064 :~p", [Result]),
	{ok, BinData} = pt_40:write(40064, [Result]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;

%% -----------------------------------------------------------------
%% 40066  氏族祝福个人信息
%% -----------------------------------------------------------------
handle(40066, Status, []) ->
	case Status#player.lv < 35 of
		false ->
			case lib_task:get_one_trigger(?GUILD_WISH_TASK_ID, Status#player.id) of
				false ->%%没加任务
					ok;
				_ ->%%任务接了
					%%检查是否已经初始化过了
					lib_guild_wish:check_init_guild_wish(Status#player.id, Status#player.nickname, Status#player.sex, Status#player.career, Status#player.guild_id),
					{TId, Luck, TColor, TState, ReTime, Logs} = lib_gwish_interface:get_p_gwish(Status),
					TCount = lib_task:get_today_count(?GUILD_WISH_TASK_ID, Status),
%% 					?DEBUG("40066: PId:~p, TId:~p, Luck:~p, TColor:~p, TState:~p, ReTime:~p, TCount:~p", [Status#player.id, TId, Luck, TColor, TState, ReTime, TCount]),
					{ok, BinData} = pt_40:write(40066, [{TId, Luck, TColor, TState, ReTime, TCount, Logs}]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					ok
			end;
		true ->
			ok
	end;
	
%% -----------------------------------------------------------------
%% 40067  获取氏族祝福任务
%% -----------------------------------------------------------------
handle(40067, Status, []) ->
	case Status#player.lv < 35 of
		false ->
	case Status#player.guild_id =/= 0 of
		true ->
			case lib_task:get_one_trigger(?GUILD_WISH_TASK_ID, Status#player.id) of
				false ->%%没加任务
					Result = {4, 0};
				_ ->%%任务接了
					%%检查是否已经初始化过了
					lib_guild_wish:check_init_guild_wish(Status#player.id, Status#player.nickname, Status#player.sex, Status#player.career, Status#player.guild_id),
					Result = lib_gwish_interface:get_gwish_task(Status)
			end;
		false ->
			Result = {3, 0}
	end,
%% 	?DEBUG("40067 :~p", [Result]),
	{ok, BinData} = pt_40:write(40067, [Result]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;
		true ->
			ok
	end;

%% -----------------------------------------------------------------
%% 40068  刷新氏族祝福任务
%% -----------------------------------------------------------------
handle(40068, Status, []) ->
	case Status#player.lv < 35 of
		false ->
	case Status#player.guild_id =/= 0 of
		true ->
			case lib_task:get_one_trigger(?GUILD_WISH_TASK_ID, Status#player.id) of
				false ->%%没加任务
					Result = {6, 0, 0};
				_ ->%%任务接了
					%%检查是否已经初始化过了
					lib_guild_wish:check_init_guild_wish(Status#player.id, Status#player.nickname, Status#player.sex, Status#player.career, Status#player.guild_id),
					Result = lib_gwish_interface:f5_gwish_task(Status)
			end;
		false ->
			Result = {5, 0, 0}
	end,
%% 	?DEBUG("40068 :~p", [Result]),
	{ok, BinData} = pt_40:write(40068, [Result]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;
		true ->
			ok
	end;
	
%% -----------------------------------------------------------------
%% 40069  接受当前任务
%% -----------------------------------------------------------------
handle(40069, Status, []) ->
	case Status#player.lv < 35 of
		false ->
	case Status#player.guild_id =/= 0 of
		true ->
			case lib_task:get_one_trigger(?GUILD_WISH_TASK_ID, Status#player.id) of
				false ->%%没加任务
					Result = 5;
				_ ->%%任务接了
					%%检查是否已经初始化过了
					lib_guild_wish:check_init_guild_wish(Status#player.id, Status#player.nickname, Status#player.sex, Status#player.career, Status#player.guild_id),
					Result = lib_gwish_interface:accept_gwish_task(Status)
			end;
		false ->
			Result = 4
	end,
%% 	?DEBUG("40069 :~p", [Result]),
	{ok, BinData} = pt_40:write(40069, [Result]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
	ok;
		true ->
			ok
	end;

%% -----------------------------------------------------------------
%% 40070  放弃当前任务
%% -----------------------------------------------------------------
handle(40070, Status, []) ->
	case Status#player.lv < 35 of
		false ->
			case lib_task:get_one_trigger(?GUILD_WISH_TASK_ID, Status#player.id) of
				false ->%%没加任务
					Result = 4;
				_ ->%%任务接了
					%%检查是否已经初始化过了
					lib_guild_wish:check_init_guild_wish(Status#player.id, Status#player.nickname, Status#player.sex, Status#player.career, Status#player.guild_id),
					Result = lib_gwish_interface:giveup_gwish_task(Status)
			end,
%% 			?DEBUG("40070 :~p", [Result]),
			{ok, BinData} = pt_40:write(40070, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok;
		true ->
			ok
	end;
	
%% -----------------------------------------------------------------
%% 40072  氏族祝福成员运势
%% -----------------------------------------------------------------
handle(40072, Status, []) ->
%% 	?DEBUG("get the guild wish", []),
	case Status#player.lv < 35 of
		false ->
			%%检查是否已经初始化过了
			lib_guild_wish:check_init_guild_wish(Status#player.id, Status#player.nickname, Status#player.sex, Status#player.career, Status#player.guild_id),
			%%获取氏族祝福任务的详细数据
			GWish = lib_guild_wish:get_gwish_dict(),
			Help = GWish#p_gwish.help,
			%%计算剩余的
			Rest = ?GWISH_HELP_LIMIT - Help,
			ReHelp = 
				case Rest >= 0 of
					true ->
						Rest;
					false ->
						0
				end,
			lib_gwish_interface:get_guild_gwish(ReHelp, Status),
			ok;
		true ->
			ok
	end;

%% -----------------------------------------------------------------
%% 40073  帮他人刷新运势
%% -----------------------------------------------------------------
handle(40073, Status, [DPId]) ->
	%%做频率的限制
	case tool:is_operate_ok(pp_40073, 1) of
		true ->
			case Status#player.lv < 35 of
				false ->
					case Status#player.guild_id =/= 0 of
						true ->
							%%检查是否已经初始化过了
							lib_guild_wish:check_init_guild_wish(Status#player.id, Status#player.nickname, Status#player.sex, Status#player.career, Status#player.guild_id),
							Result = lib_gwish_interface:help_other_flush(Status, DPId);
						false ->%%已经没有氏族了
							Result = {3, 0, ""}
					end,
%% 					?DEBUG("40073 :~p", [Result]),
					{ok, BinData} = pt_40:write(40073, [Result]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					ok;
				true ->
					ok
			end;
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 40075  邀请别人帮忙刷任务运势
%% -----------------------------------------------------------------
handle(40075, Status, [DPId]) ->
	%%做频率的限制
	case tool:is_operate_ok(pp_40075, 1) of
		true ->
			case Status#player.lv < 35 of
				false ->
					case Status#player.guild_id =/= 0 of
						true ->
							case lib_task:get_one_trigger(?GUILD_WISH_TASK_ID, Status#player.id) of
								false ->%%没加任务
									Result = 9;
								_ ->
									%%检查是否已经初始化过了
									lib_guild_wish:check_init_guild_wish(Status#player.id, Status#player.nickname, Status#player.sex, Status#player.career, Status#player.guild_id),
									Result = lib_gwish_interface:invite_other_flush(Status, DPId)
							end;
						false ->
							Result = 7
					end,
%% 					?DEBUG("40075 :~p", [Result]),
					{ok, BinData} = pt_40:write(40075, [Result]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					ok;
				true ->
					ok
			end;
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 40077  领取奖励
%% -----------------------------------------------------------------
handle(40077, Status, []) ->
	case Status#player.lv < 35 of
		false ->
			case lib_task:get_one_trigger(?GUILD_WISH_TASK_ID, Status#player.id) of
				false ->%%没加任务
					Result = {7, 0},
%% 					?DEBUG("40077 :~p", [Result]),
					{ok, BinData} = pt_40:write(40077, [Result]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					ok;
				_ ->
					%%检查是否已经初始化过了
					lib_guild_wish:check_init_guild_wish(Status#player.id, Status#player.nickname, Status#player.sex, Status#player.career, Status#player.guild_id),
					{Type, Goods, NewStatus} = lib_gwish_interface:get_gwish_award(Status),
%% 					?DEBUG("40077 :~p", [{Type, Goods}]),
					{ok, BinData} = pt_40:write(40077, [{Type, Goods}]),
					lib_send:send_to_sid(NewStatus#player.other#player_other.pid_send, BinData),
					%%通知客户端刷新
					lib_player:send_player_attribute2(NewStatus, 2),
					{ok, change_ets_table, NewStatus}
			end;
		true ->
			ok
	end;

%% -----------------------------------------------------------------
%% 40078  刷新时间
%% -----------------------------------------------------------------
handle(40078, Status, []) ->
	if
		Status#player.lv < 3 ->
			ok;
		Status#player.guild_id =:= 0 ->
			Result = {3, 0},
			{ok, BinData} = pt_40:write(40078, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			ok;
		true ->
			%%检查是否已经初始化过了
			lib_guild_wish:check_init_guild_wish(Status#player.id, Status#player.nickname, Status#player.sex, Status#player.career, Status#player.guild_id),
			{NewStatus, Type, GoldNeed} = lib_gwish_interface:flush_gwish_time(Status),
%% 			?DEBUG("40078 :~p", [{Type, GoldNeed}]),
			{ok, BinData} = pt_40:write(40078, [{Type, GoldNeed}]),
			lib_send:send_to_sid(NewStatus#player.other#player_other.pid_send, BinData),
			case Type of
				1 ->%%刷新客户端元宝
					lib_player:send_player_attribute2(NewStatus, 2),
					{ok, change_ets_table, NewStatus};
				_ ->%%什么都不用做
					ok
			end
	end;

%% -----------------------------------------------------------------
%%氏族群聊面板
%% -----------------------------------------------------------------
handle(40079,Status,[Color,Msg]) ->
	case lib_war:is_war_server() of
		false ->
			Data_filtered = lib_words_ver:words_filter([Msg]),
			Data1 = [Status#player.id, Status#player.career, Status#player.sex, Status#player.vip, 
					 Status#player.nickname, Color, Data_filtered],
			{ok, BinData} = pt_40:write(40079, Data1),
			lib_chat:chat_guild(Status, [Data_filtered,BinData]);
		true ->
			%%跨服不能氏族聊天
			skip
	end;	

%% -----------------------------------------------------------------
%%氏族群聊面板
%% -----------------------------------------------------------------
handle(40080,Status,[]) ->
	gen_server:cast(mod_guild:get_mod_guild_pid(), {'OPEN_GUILD_GROUP',Status});

%% -----------------------------------------------------------------
%% 40084 族员答应传送求援PK
%% -----------------------------------------------------------------
handle(40084, Status, [Type, OSceneId, OX, OY]) ->
	%%做频率的限制
	case tool:is_operate_ok(pp_40083, 1) of
		true ->
			case Status#player.guild_id =/= 0 of
				true ->
					{Result, NewStatus} = lib_guild_call:fly_to_help_pk(Status, Type, OSceneId, OX, OY, 1),
					{ok, BinData40083} = pt_40:write(40084, [Result]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData40083),
					case NewStatus#player.scene =:= ?WARFARE_SCENE_ID of
						true ->
							%%修改战斗模式为氏族模式
							NStatus = NewStatus#player{pk_mode = 3},
							%%更新玩家新模式
							ValueList = [{pk_mode, 3}],
							WhereList = [{id, NStatus#player.id}],
							db_agent:mm_update_player_info(ValueList, WhereList),
							%%通知客户端
							{ok, PkModeBinData} = pt_13:write(13012, [1, 3]),
							lib_send:send_to_sid(NStatus#player.other#player_other.pid_send, PkModeBinData),
							%%获取 冥王之灵的图标显示
							lib_warfare:get_plutos_owns(NStatus#player.other#player_other.pid_send);
						false ->
							NStatus = NewStatus
					end,
					case Result of
						1 ->%%需要保存数据的
							{ok, change_ets_table, NStatus};
						_ ->
							ok
					end;
				false ->
					{ok, BinData40083} = pt_40:write(40084, [17]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData40083),
					ok
			end;
		false ->
			{ok, BinData40083} = pt_40:write(40083, [20]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData40083),
			ok
	end;
	
%% -----------------------------------------------------------------
%% 40085 族长召唤
%% -----------------------------------------------------------------
handle(40085, Status, []) ->
	%%做频率的限制
	case tool:is_operate_ok(pp_40085, 1) of
		true ->
			lib_guild_call:chief_convence(Status),
			ok;
		false ->
			%%向族长反馈
			{ok, BinData40085} = pt_40:write(40085, [9]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData40085),
			ok
	end;

%% -----------------------------------------------------------------
%% 40086 成员回应族长召唤
%% -----------------------------------------------------------------
handle(40086, Status, []) ->
	%%做频率的限制
	case tool:is_operate_ok(pp_40086, 1) of
		true ->
			case Status#player.guild_id =/= 0 of
				true ->
					{Result, NewStatus} = lib_guild_call:reponse_chief_convence(Status),
					{ok, BinData40083} = pt_40:write(40086, [Result]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData40083),
					case NewStatus#player.scene =:= ?WARFARE_SCENE_ID of
						true ->
							%%修改战斗模式为氏族模式
							NStatus = NewStatus#player{pk_mode = 3},
							%%更新玩家新模式
							ValueList = [{pk_mode, 3}],
							WhereList = [{id, NStatus#player.id}],
							db_agent:mm_update_player_info(ValueList, WhereList),
							%%通知客户端
							{ok, PkModeBinData} = pt_13:write(13012, [1, 3]),
							lib_send:send_to_sid(NStatus#player.other#player_other.pid_send, PkModeBinData),
							%%获取 冥王之灵的图标显示
							lib_warfare:get_plutos_owns(NStatus#player.other#player_other.pid_send);
						false ->
							NStatus = NewStatus
					end,
					
					case Result of
						1 ->%%需要保存数据的
							{ok, change_ets_table, NStatus};
						_ ->
							ok
					end;
				false ->
					{ok, BinData40083} = pt_40:write(40086, [17]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData40083),
					ok
			end;
		false ->
			{ok, BinData40083} = pt_40:write(40086, [18]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData40083),
			ok
	end;

%% -----------------------------------------------------------------
%% 40088 发出氏族联盟申请
%% -----------------------------------------------------------------
handle(40088, Status, [TarGid]) ->
	%%做频率的限制
	case tool:is_operate_ok(pp_40088, 1) of
		true ->
			Result = 
				if
					Status#player.guild_id =:= 0 ->%%你冇氏族，不能发出申请
						2;
					Status#player.guild_position =/= 1 ->%%只有氏族长才能发起联盟申请
						5;
					Status#player.guild_id =:= TarGid ->%%不能向自己的氏族发起申请
						11;
					true ->
						mod_guild:apply_guild_alliance(Status, TarGid)
				end,
			{ok, BinData40087} = pt_40:write(40088, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData40087);
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 40089 取消氏族联盟申请
%% -----------------------------------------------------------------
handle(40089, Status, [TarGid]) ->
	%%做频率的限制
	case tool:is_operate_ok(pp_40089, 1) of
		true ->
			Result = 
				if
					Status#player.guild_id =:= 0 ->%%你冇氏族，不能取消申请
						2;
					Status#player.guild_position =/= 1 ->%%只有氏族长才能取消联盟申请
						3;
					Status#player.guild_id =:= TarGid ->%%不能向自己的氏族发起申请
						5;
					true ->
						mod_guild:cancel_guild_alliance(Status, TarGid)
				end,
			{ok, BinData40087} = pt_40:write(40089, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData40087);
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 40090 同意氏族联盟申请
%% -----------------------------------------------------------------
handle(40090,  Status, [TarGid]) ->
	%%做频率的限制
	case tool:is_operate_ok(pp_40090, 1) of
		true ->
			Result = 
				if
					Status#player.guild_id =:= 0 ->%%你冇氏族，不能同意
						4;
					Status#player.guild_position =/= 1 ->%%只有氏族长才能发起联盟申请
						3;
					Status#player.guild_id =:= TarGid ->%%不能向自己的氏族发起申请
						7;
					true ->
						mod_guild:aggree_guild_alliance(Status, TarGid)
				end,
%%			?DEBUG("40090, Result:~p", [Result]),
			{ok, BinData40087} = pt_40:write(40090, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData40087);
		false ->
			ok
	end;

%% -----------------------------------------------------------------
%% 40091 拒绝氏族联盟申请
%% -----------------------------------------------------------------
handle(40091,  Status, [TarGid]) ->
	%%做频率的限制
	case tool:is_operate_ok(pp_40091, 1) of
		true ->
			Result = 
				if
					Status#player.guild_id =:= 0 ->%%你冇氏族，不能同意
						2;
					Status#player.guild_position =/= 1 ->%%只有氏族长才能拒绝联盟申请
						3;
					Status#player.guild_id =:= TarGid ->%%目标氏族不能是本氏族
						4;
					true ->
						mod_guild:refuse_guild_alliance(Status, TarGid)
				end,
			{ok, BinData40087} = pt_40:write(40091, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData40087);
		false ->
			ok
	end;


%% -----------------------------------------------------------------
%% 40092 中止氏族联盟关系
%% -----------------------------------------------------------------
handle(40092,  Status, [TarGid]) ->
	%%做频率的限制
	case tool:is_operate_ok(pp_40092, 1) of
		true ->
			Result = 
				if
					Status#player.guild_id =:= 0 ->%%你冇氏族，不能同意
						2;
					Status#player.guild_position =/= 1 ->%%只有氏族长才能拒绝联盟申请
						3;
					Status#player.guild_id =:= TarGid ->%%目标氏族不能是本氏族
						4;
					true ->
						mod_guild:stop_guild_alliance(Status, TarGid)
				end,
			{ok, BinData40087} = pt_40:write(40092, [Result]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData40087);
		false ->
			ok
	end;
%% -----------------------------------------------------------------
%% 40093 获取指定的氏族的氏族信息
%% -----------------------------------------------------------------
handle(40093, Status, [GuildId]) ->
	%%做频率的限制
	case tool:is_operate_ok(pp_40093, 1) of
		true ->
			mod_guild:get_target_guild(Status, GuildId);
		false ->
			skip
	end,
	ok;
%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------

handle(_Cmd, _Status, _Data) ->
    ?DEBUG("pp_guild no match", []),
    {error, "pp_guild no match"}.



