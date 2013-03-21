%%%--------------------------------------
%%% @Module  : lib_guild_inner
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description : 氏族业务内部处理实现
%%%--------------------------------------
-module(lib_guild_inner).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("guild_info.hrl").
-compile(export_all).
-export([handle_guild_upgrade_record/0]).

%%=========================================================================
%% 初始化回调函数
%%=========================================================================

%% -----------------------------------------------------------------
%% 角色登录
%% -----------------------------------------------------------------
role_login(PlayerId, GuildId, LastLoginTime) ->
	%%玩家氏族申请列表在线情况更新
	case get_guild_apply_by_player_id(PlayerId) of
		[] ->
			skip;
		GuildApply ->	
			lists:foreach(fun(Elem) ->
								  GuildApplyNew = Elem#ets_guild_apply{online_flag = 1},
								  update_guild_apply(GuildApplyNew)
						  end, GuildApply)
	end,
	%%玩家氏族成员列表在线情况更新
    GuildMember = get_guild_member_by_guildandplayer_id(GuildId, PlayerId),
    case  GuildMember of
        % 未参加氏族
        [] -> void;
        % 参加了氏族
        _  ->
            GuildMemberNew = GuildMember#ets_guild_member{online_flag = 1, last_login_time=LastLoginTime},
            update_guild_member(GuildMemberNew)
    end,
    load_all_guild_invite(PlayerId).
    

%% -----------------------------------------------------------------
%% 角色退出
%% -----------------------------------------------------------------
role_logout(PlayerId) ->
	%%玩家氏族申请列表在线情况更新
	case get_guild_apply_by_player_id(PlayerId) of
		[] ->
			skip;
		GuildApply ->
			lists:foreach(fun(Elem) ->
								  GuildApplyNew = Elem#ets_guild_apply{online_flag = 0},
								  update_guild_apply(GuildApplyNew)
						  end, GuildApply)
	end,
    GuildMember = get_guild_member_by_player_id(PlayerId),
    case  GuildMember of
        % 未参加氏族
        [] -> void;
        % 参加了氏族
        _  ->
            GuildMemberNew = GuildMember#ets_guild_member{online_flag = 0},
            update_guild_member(GuildMemberNew)
    end,
    delete_guild_invite_by_player_id(PlayerId).

%% -----------------------------------------------------------------
%% 角色升级
%% -----------------------------------------------------------------
role_upgrade(PlayerId, Level) ->
    % 如果是氏族成员则更新缓存
    GuildMember = get_guild_member_by_player_id(PlayerId),
    case  GuildMember of
        [] -> void;
        _  ->
            GuildMemberNew = GuildMember#ets_guild_member{lv = Level},
            update_guild_member(GuildMemberNew)
    end,
    % 如果是申请了氏族则更新缓存
    GuildApply = get_guild_apply_by_player_id(PlayerId),
    case  GuildApply of
        [] -> void;
        _  ->
            lists:foreach(fun(GuildApplyElem) ->
								  GuildApplyNew = GuildApplyElem#ets_guild_apply{lv = Level},
								  update_guild_apply(GuildApplyNew)
						  end, GuildApply)
    end.

%% -----------------------------------------------------------------
%% 角色VIP 状态更新
%% -----------------------------------------------------------------
role_vip_update(PlayerId, Vip) ->
%% 	?DEBUG("PlayerId:~p, Vip:~p", [PlayerId, Vip]),
    % 如果是氏族成员则更新缓存
    GuildMember = get_guild_member_by_player_id(PlayerId),
    case  GuildMember of
        [] -> void;
        _  ->
            GuildMemberNew = GuildMember#ets_guild_member{vip = Vip},
            update_guild_member(GuildMemberNew)
    end,
    % 如果是申请了氏族则更新缓存
    GuildApply = get_guild_apply_by_player_id(PlayerId),
    case  GuildApply of
        [] -> void;
        _  ->
            lists:foreach(fun(GuildApplyElem) ->
								  GuildApplyNew = GuildApplyElem#ets_guild_apply{vip = Vip},
								  update_guild_apply(GuildApplyNew)
						  end, GuildApply)
    end.

%% -----------------------------------------------------------------
%% 删除角色
%% -----------------------------------------------------------------
delete_role(PlayerId) ->
    GuildMember = get_guild_member_by_player_id(PlayerId),
    case  GuildMember of
        % 未参加氏族
        [] ->
            % 删除氏族申请
            remove_guild_invite_all(PlayerId),
            % 删除氏族邀请
            remove_guild_apply_all(PlayerId);
        	% 参加了氏族
        _  ->
            case GuildMember#ets_guild_member.guild_position of
                % 族长
                1 ->
                    % 解散氏族
                    confirm_disband_guild(GuildMember#ets_guild_member.guild_id,
										  GuildMember#ets_guild_member.guild_name,
										  GuildMember#ets_guild_member.player_id,
										  GuildMember#ets_guild_member.player_name);
                % 副族长
                _ ->
                    % 删除氏族成员
                    GuildId = GuildMember#ets_guild_member.guild_id,
                    Guild = get_guild(GuildId),
                    case Guild of
                        [] ->
                            ?ERROR_MSG("delete_role: Not find guild, id=[~p]", [GuildId]);
                        _  ->
                            case remove_guild_member(0, PlayerId, GuildId,
													 Guild#ets_guild.deputy_chief1_id,
													 Guild#ets_guild.deputy_chief2_id) of
                                [ok, MemberType] ->
                                % 更新缓存
                                        case MemberType of
                                            0 ->
                                                GuildNew = Guild#ets_guild{member_num = Guild#ets_guild.member_num-1},
                                                update_guild(GuildNew);
                                            1 ->
                                                GuildNew = Guild#ets_guild{member_num         = Guild#ets_guild.member_num-1,
                                                                          deputy_chief_num   = Guild#ets_guild.deputy_chief_num -1,
                                                                          deputy_chief1_id   = 0,
                                                                          deputy_chief1_name = <<>>},
                                                update_guild(GuildNew);
                                            2 ->
                                                GuildNew = Guild#ets_guild{member_num         = Guild#ets_guild.member_num-1,
                                                                           deputy_chief_num   = Guild#ets_guild.deputy_chief_num -1,
                                                                           deputy_chief2_id   = 0,
                                                                           deputy_chief2_name = <<>>},
                                              update_guild(GuildNew)
                                        end;
                                _  ->
                                        void
                            end,
                            % 删除氏族申请
                           remove_guild_invite_all(PlayerId),
                            % 删除氏族邀请
                          remove_guild_apply_all(PlayerId)
                    end
            end
    end,
    ok.

%% -----------------------------------------------------------------
%% 加载所有氏族
%% -----------------------------------------------------------------
load_all_guild() ->
	%%从数据库获取所有的氏族数据
    GuildList = db_agent:load_all_guild(),
    lists:map(fun load_guild_record/1, GuildList).

load_guild_record(GuildInfo) ->
    Guild = list_to_tuple([ets_guild] ++ GuildInfo),
	load_guild_into_ets(Guild),
	%%加载氏族空岛排行榜
	lib_skyrush:load_skyrush_g_rank(Guild).

load_guild_into_ets(Guild) ->	
	#ets_guild{id = GuildId,
			   name = GuildName,
			   level = GuildLevel,
			   upgrade_last_time = UpGradeLastTime} = Guild,
	case UpGradeLastTime =:= 0 of
		false ->%%还在升级中,插入升级记录
		%%	ActualLevel = GuildLevel -1;
			[_NeedFunds, _NeedExp, NeedTime, _AddSkills] = data_guild:get_guild_upgrade_info(GuildLevel + 1),
			UpGradeList = 
				#ets_guild_upgrade_status{
										   guild_id = GuildId,
										   guild_name = GuildName,
										   current_level = GuildLevel,
										   upgrade_succeed_time = UpGradeLastTime +  NeedTime},
			insert_into_ets_guild_upgrade(UpGradeList);
		true ->%%最近没有在升级
		%%	ActualLevel = GuildLevel
			void
	end,
		% 2- 插入缓存
	update_guild(Guild),
	% 加载该氏族成员
    load_all_guild_member(GuildId),
    % 加载该氏族申请
    load_all_guild_apply(GuildId),
	ok.

%%加载所有的氏族技能属性
load_all_guild_skills_attribute() ->
	SkillsRecords = db_agent:load_all_guild_skills_attribute(),
	lists:map(fun load_guild_skills_into_ets/1, SkillsRecords).

load_guild_skills_into_ets(SkillsRecord) ->
	SkillAttribute = list_to_tuple([ets_guild_skills_attribute] ++ SkillsRecord),
	update_guild_skill_attribute(SkillAttribute).

%% -----------------------------------------------------------------
%% 加载所有氏族成员
%% -----------------------------------------------------------------
load_all_guild_member(GuildId) ->
    GuildMemberList = db_agent:load_all_guild_member(GuildId),
	Now = util:unixtime(),
    lists:map(fun(Elem) ->
					  load_guild_member_record(Elem, Now)
			  end, GuildMemberList).
    
load_guild_member_record(GuildMemberInfo, Now) ->
	GuildMember = list_to_tuple([ets_guild_member] ++ GuildMemberInfo),
	%%加载空岛神战的氏族成员排行榜
	lib_skyrush:load_skyrush_m_rank(GuildMember, Now),
	load_guild_member_into_ets(GuildMember).

load_guild_member_into_ets(GuildMember) ->
    % 插入缓存
    update_guild_member(GuildMember).

%% -----------------------------------------------------------------
%% 加载所有氏族申请
%% -----------------------------------------------------------------
load_all_guild_apply(GuildId) ->
    GuildApplyList = db_agent:load_all_guild_apply(GuildId),
    lists:map(fun make_guild_apply_record/1, GuildApplyList).

make_guild_apply_record(GuildApplyElem) ->
	GuildApply = list_to_tuple([ets_guild_apply] ++ GuildApplyElem),
	load_guild_apply_into_ets(GuildApply).

load_guild_apply_into_ets(GuildApply) ->
    % 插入缓存
%% 	GuildApplyInfo = list_to_tuple([ets_guild_apply] ++ GuildApply),
    update_guild_apply(GuildApply).

%% -----------------------------------------------------------------
%% 加载所有氏族邀请
%% -----------------------------------------------------------------
load_all_guild_invite(PlayerId) ->
    GuildInviteList = db_agent:load_all_guild_invite(PlayerId),
    lists:map(fun make_guild_invite_record/1, GuildInviteList).

make_guild_invite_record(GuildInviteElem) ->
	GuildInvite = list_to_tuple([ets_guild_invite] ++ GuildInviteElem),
	load_guild_invite_into_ets(GuildInvite).

load_guild_invite_into_ets(GuildInvite) ->
    % 插入缓存
%% 	GuildInviteInfo = list_to_tuple([ets_guild_invite] ++ GuildInvite),
    update_guild_invite(GuildInvite).

%% -----------------------------------------------------------------
%% 加载所有氏族日志
%% -----------------------------------------------------------------
load_all_guild_log() ->
	GuildLogList = db_agent:load_all_guild_log(),
	lists:map(fun load_guild_log_into_ets/1, GuildLogList).

load_guild_log_into_ets(GuildLogList) ->
	GuildLog = list_to_tuple([ets_log_guild] ++ GuildLogList),
	update_guild_log(GuildLog).

%%=========================================================================
%% 业务操作函数
%%=========================================================================

%% -----------------------------------------------------------------
%% 创建氏族
%% -----------------------------------------------------------------
create_guild(PlayerId, PlayerName, PlayerRealm, GuildName, LevelAdd, SkillsAdd) ->
%%     ?DEBUG("create_guild: PlayerId=[~p], PlayerName=[~s], PlayerRealm=[~p], GuildName=[~s]", [PlayerId, PlayerName, PlayerRealm, GuildName]),
%%     [_MemberCapacityBase, MemberCapcity] = 
%% 					data_guild:get_level_info(1),
	MemberCapcity = data_guild:get_guild_config(guild_member_base,[]),
	
    CreateTime              = util:unixtime(),
    ContributionGetNextTime = CreateTime + ?ONE_DAY_SECONDS,
    % 插入氏族
	%%获取默认的所有堂名
	DepartmentNames = data_guild:get_departmemt_names(0, 0),
	
	
%% 	name, = "",chief_id = 0,chief_name = "",deputy_chief1_id = 0,deputy_chief1_name = "",
%% 	deputy_chief2_id = 0,deputy_chief2_name = "",deputy_chief_num = 0,member_num = 0,member_capacity = 0,
%% 	realm = 0,level = 0,upgrade_last_time = 0,reputation = 0,
%% 	skills = 0,exp = 0,funds = 0,storage_num, storage_limit = 0, consume_get_nexttime = 0, 
%% 	combat_num = 0,combat_victory_num = 0, create_time = 0, depart_names = ""
	
	New_guild = #ets_guild{
					   name = GuildName,
					   chief_id = PlayerId, 
					   chief_name = PlayerName,
					   member_num = 1,
					   member_capacity = MemberCapcity, 
					   realm = PlayerRealm,
					   level = 1+LevelAdd,
					   skills = ?GUILD_SKILL_INIT+SkillsAdd,
					   consume_get_nexttime = ContributionGetNextTime,
					   create_time = CreateTime, 
					   depart_names = tool:to_binary(DepartmentNames),
					   lct_boss = util:term_to_string([0,0,0]),
					   combat_num = 0,
					   combat_victory_num = 0,
					   combat_all_num = 0,
					   combat_week_num = util:term_to_string([0,0]),
					   sky_apply = 0,
					   sky_award = util:term_to_string(?SKYRUSH_AWARD_ZERO),
					   a_plist = util:term_to_string([]),
					   convence =  util:term_to_string([0,0])
					   },
    case db_agent:guild_insert(New_guild) of
		{mongo, NewGuildId} ->
			Guild = New_guild#ets_guild{id = NewGuildId};
		1 ->
			% 获取刚插入的氏族
			case db_agent:guild_select_create(GuildName) of
				[] ->
					Guild = [];
				GuildResult ->
					Guild = list_to_tuple([ets_guild] ++ GuildResult)
			end;
		_Other ->
			Guild = []
	end,
	if Guild =:= [] ->
		   ?ERROR_MSG("create_guild: guild id is null, name=[~s]", [GuildName]),
		   error;
        true ->
			GuildId = Guild#ets_guild.id,
            % 插入氏族成员			
			Guild_member = #ets_insert_guild_member{
								guild_id = GuildId, 
								guild_name = GuildName, 
								player_id = PlayerId, 
								player_name = PlayerName, 
								create_time = CreateTime,
								guild_depart_id = 5
								},
            db_agent:guild_member_insert(Guild_member),
            % 更新角色表 
			ValueListNew = [{guild_id, GuildId}, 
							{guild_name, GuildName},
							{guild_position, 1},
							{guild_depart_id, 5}],
			WhereList = [{id,PlayerId}],
			
            db_agent:guild_player_update_info(ValueListNew, WhereList),
			%%初始化氏族技能信息
%% 			lib_guild_weal:init_h_skill(GuildId),%%高级技能
			case init_guild_skill_attribute(GuildId) of
				ok ->
					% 更新缓存
					load_guild_into_ets(Guild),
					
					% 删除氏族申请
					remove_guild_apply_all(PlayerId),
					% 删除氏族邀请
					remove_guild_invite_all(PlayerId),
 
					%%以下更新氏族日志
					Content = lists:concat([?CREATE_GUILD_ONE, PlayerName, ?CREATE_GUILD_TWO, binary_to_list(GuildName), ?CREATE_GUILD_THREE]),
					Log_guild = #ets_log_guild{
											   guild_id = GuildId, 
											   guild_name = tool:to_binary(GuildName), 
											   time = CreateTime, 
											   content	= tool:to_binary(Content)	   
											  },
					case db_agent:guild_log_insert(Log_guild) of
						{mongo, Ret} ->
							GuildLogEts = Log_guild#ets_log_guild{id = Ret},
							update_guild_log(GuildLogEts),
							{ok, GuildId};
						1 ->
							GuildLog = db_agent:guild_log_select_create(GuildId, GuildName),
							if GuildLog =:= [] ->
								   error;
							   true ->
								   GuildLogEts = list_to_tuple([ets_log_guild] ++ GuildLog),
								   update_guild_log(GuildLogEts),	
								   {ok, GuildId}
							end;
						_OtherResult ->
							error
					end;
				fail ->
					error
			end
	end.

%% -----------------------------------------------------------------
%% 确认解散氏族
%% -----------------------------------------------------------------
confirm_disband_guild(GuildId, GuildName, PlayerId, PlayerName) ->
    % 更新角色表
	ValueList = [{guild_id, 0}, 
				 {guild_name, ""}, 
				 {guild_position, 0},
				 {quit_guild_time, 0},
				 {guild_title, ""},
				 {guild_depart_name, ""},
				 {guild_depart_id, 0}],
	WhereList = [{guild_id, GuildId}],			
    db_agent:guild_player_update_info(ValueList, WhereList),
	%%删除氏族升级的记录
	delete_ets_guild_upgrade(GuildId),	
    % 删除氏族表
    db_agent:guild_delete(GuildId),
    % 删除氏族成员表
    db_agent:guild_member_delete(GuildId),
    % 删除氏族申请表
    db_agent:guild_apply_delete(GuildId),
    % 删除氏族邀请表
    db_agent:guild_invite_delete(GuildId),
	%%氏族解散，删除氏族仓库的所有物品(加载氏族仓库的时候要用)
	lib_guild_warehouse:delete_warehouse_disband(GuildId),
	% 广播% 通知氏族成员
	lib_guild_inner:send_guild(1, PlayerId, GuildId,
						 confirm_disband_guild, [GuildId, PlayerName, GuildName]),
    % 邮件通知给氏族成员
    NameList  = get_member_name_list(GuildId, PlayerId),
	case NameList of
		[] ->
			no_action;
		_ ->
%%	NewNameList = lists:delete(PlayerName, NameList),
			lib_guild:send_guild_mail(guild_disband, [GuildId, GuildName, NameList])
	end,
    % 更新缓存
    delete_guild(GuildId),
    delete_guild_member_by_guild_id(GuildId),
    delete_guild_invite_by_guild_id(GuildId),
    delete_guild_apply_by_guild_id(GuildId),
	%%删除氏族技能信息表
	delete_guild_skills_attribute(GuildId),
    ok.

%% -----------------------------------------------------------------
%% 删除解散的氏族日志所有记录
%% -----------------------------------------------------------------
delete_log_guild(GuildId) ->
	db_agent:delete_log_guild(GuildId),
	ets:delete_object(?ETS_LOG_GUILD, {'_', GuildId, '_', '_'}).
	
%% -----------------------------------------------------------------
%% 添加加入氏族申请
%% -----------------------------------------------------------------
add_guild_apply(PlayerId, PlayerName, PlayerLevel, PlayerSex, PlayerJobs, PlayerCareer, PlayerVip, GuildId) ->
    % 删除其他申请
 %%   db_agent:guild_apply_delete_player(PlayerId),
    % 插入氏族申请
    CreateTime  = util:unixtime(),
    case db_agent:guild_apply_insert(PlayerId, GuildId, CreateTime) of
		{mongo, Ret} ->
			Id = Ret,
			GuildApply = #ets_guild_apply{
											id = Id,
											guild_id = GuildId,   
											player_id = PlayerId,         
											create_time = CreateTime,      
											nickname = PlayerName,  
											sex = PlayerSex,     
											jobs = PlayerJobs,   
											lv = PlayerLevel,         
											career = PlayerCareer,
											online_flag = 1,
											vip = PlayerVip
										   };
		1 ->
			case db_agent:guild_apply_select_new(PlayerId, GuildId) of
				[] ->
					GuildApply = [];
				GuildApplyList ->
					GuildApply = list_to_tuple([ets_guild_apply] ++ GuildApplyList)
			end;
		_Other ->
			GuildApply = []
	end,
	if GuildApply =:=  [] ->
		   fail;
	   true ->
    % 更新缓存
		   load_guild_apply_into_ets(GuildApply),
		   ok
	end.
    
%%初始化氏族技能信息
init_guild_skill_attribute(GuildId) ->
	%%更新数据库
	%%获取技能名字
	SkillsAttr = data_guild:get_skills_names(0),
	insert_guild_skill_attributes(ok, SkillsAttr, GuildId).

insert_guild_skill_attributes(ok, [List|RestSkillsAttr], GuildId) ->
	{SkillId, _SkillName} = List,
	Guild_skills_attribute = 
		#ets_guild_skills_attribute{
									guild_id = GuildId,
									skill_id = SkillId, 
									skill_name = "",
									skill_level	= 0	
								   },
	case db_agent:init_guild_skill_attribute(Guild_skills_attribute) of
		{mongo, Ret} ->
			GuildSkillsAttrEts = Guild_skills_attribute#ets_guild_skills_attribute{id = Ret};
		1 ->
			case db_agent:get_guild_skill_attribute(GuildId, SkillId) of
				[] ->
					GuildSkillsAttrEts = [];
				GuildSkillsAttr ->
					GuildSkillsAttrEts = list_to_tuple([ets_guild_skills_attribute] ++ GuildSkillsAttr)
				end;
		_Other ->
			GuildSkillsAttrEts = []
	end,
	if GuildSkillsAttrEts =:= [] ->
		   insert_guild_skill_attributes(fail, RestSkillsAttr, GuildId);
	   true ->
		   update_guild_skill_attribute(GuildSkillsAttrEts),
		   insert_guild_skill_attributes(ok, RestSkillsAttr, GuildId)
	end;
insert_guild_skill_attributes(ok, [], _GildId) ->
	ok;
insert_guild_skill_attributes(fail, _SkillsAttr, _GuildId) ->
	fail.

%%删除氏族技能信息表
delete_guild_skills_attribute(GuildId) ->
	db_agent:delete_guild_skills(GuildId),
	ets_delete_guild_skills_attribute(GuildId).
	
						  
%% -----------------------------------------------------------------
%% 添加氏族邀请
%% -----------------------------------------------------------------
add_guild_invite(PlayerId, MyPlayerId, GuildId, RecommanderName) ->
    % 插入氏族邀请
    CreateTime = util:unixtime(),
	GuildInviteInit = #ets_guild_invite{
										guild_id = GuildId,
										player_id = PlayerId,
										create_time = CreateTime,
										recommander_name = RecommanderName,
										recommander_id = MyPlayerId},
	case db_agent:guild_invite_insert(GuildInviteInit) of
		{mongo, Ret} ->
			GuildInvite = GuildInviteInit#ets_guild_invite{id = Ret};
		1 ->
			case db_agent:guild_invite_select_new(PlayerId, GuildId) of
				[] ->
					GuildInvite = [];
				GuildInviteInfo ->
					GuildInvite = list_to_tuple([ets_guild_invite] ++ GuildInviteInfo)
			end;
		_other ->
			GuildInvite = []
	end,
	% 更新缓存
	if GuildInvite =:= [] ->
		   fail;
	   true ->
		   load_guild_invite_into_ets(GuildInvite),
		   ok
	end.

%% -----------------------------------------------------------------
%% 删除氏族申请
%% -----------------------------------------------------------------
remove_guild_apply(PlayerId, GuildId) ->
    % 删除氏族申请
    db_agent:remove_guild_apply(PlayerId, GuildId),
    % 更新缓存
    delete_guild_apply_by_player_id(PlayerId, GuildId),
    ok.

delete_remove_guild_apply(PlayerId, GuildId, GuildName, PlayerNameGet) ->
	case get_guild_apply_by_player_id(PlayerId, GuildId) of
		[] ->
			noaction;
		_GuildApplyElem ->
			% 删除氏族申请
			db_agent:remove_guild_apply(PlayerId, GuildId),
			% 更新缓存
			delete_guild_apply_by_player_id(PlayerId, GuildId),
			% 广播氏族成员
			lib_guild_inner:send_msg_to_player(PlayerId, guild_reject_apply, [GuildId, GuildName]),
			% 邮件通知给被审批人
			lib_guild:send_guild_mail(guild_reject_apply, [PlayerId, PlayerNameGet, GuildId, GuildName])
	end.

			
%% -----------------------------------------------------------------
%% 删除氏族邀请
%% -----------------------------------------------------------------
remove_guild_invite(PlayerId, GuildId) ->
    % 删除氏族邀请
    db_agent:guild_invite_delete1(PlayerId, GuildId),
    % 更新缓存
    delete_guild_invite_by_player_id(PlayerId, GuildId),
    ok.

%% -----------------------------------------------------------------
%% 删除角色所有的氏族申请
%% -----------------------------------------------------------------
remove_guild_apply_all(PlayerId) ->
    % 删除氏族申请
    db_agent:guild_apply_delete_player(PlayerId),
    % 更新缓存
    delete_guild_apply_by_player_id(PlayerId),
    ok.

%% -----------------------------------------------------------------
%% 删除氏族邀请
%% -----------------------------------------------------------------
remove_guild_invite_all(PlayerId) ->
    db_agent:guild_invite_delete2(PlayerId),
    % 更新缓存
    delete_guild_invite_by_player_id(PlayerId),
    ok.

%% -----------------------------------------------------------------
%% 40005 处理审批加入氏族
%% -----------------------------------------------------------------
%%同意加入
reply_apply_guild_each(Num, SendList, _GuildId, _GuildName, _GuildRealm, []) ->
	{Num, SendList};
reply_apply_guild_each(Num, SendList, GuildId, GuildName, GuildRealm, [Apply|ApplyList]) ->
	{PlayerId, _PlayerNameGet} = Apply,
	case lib_guild_inner:get_player_guild_info(PlayerId) of
		[] ->%%玩家已经不存在
			lib_guild_inner:remove_guild_apply(PlayerId),
			reply_apply_guild_each(Num, SendList, GuildId, GuildName, GuildRealm, ApplyList);
		PlayerInfo ->
			[PlayerNickname, PlayerRealm, PlayerGuildId, _PlayerGuildName, 
			 _PlayerGuildPosition, PlayerLv, PlayerQuitGuildTime, 
			 PlayerSex, PlayerJobs, PlayerLastLoginTime,
			 PlayerOnlineFlag, PlayerCareer, PlayerCulture, _PlayerDepartMentId, PlayerVip] = PlayerInfo,
			GuildApply = lib_guild_inner:get_guild_apply_by_player_id(PlayerId, GuildId),
			TimeNow = util:unixtime(),
			TimeRest = TimeNow - PlayerQuitGuildTime,
			if 
				GuildApply =:= [] ->%%不在申请列表
					lib_guild_inner:remove_guild_apply(PlayerId, GuildId),
					reply_apply_guild_each(Num, SendList, GuildId, GuildName, GuildRealm, ApplyList);
				true ->
					if 
						PlayerGuildId =/= 0 ->%%已拥有氏族
							lib_guild_inner:remove_guild_apply(PlayerId, GuildId),
							reply_apply_guild_each(Num, SendList, GuildId, GuildName, GuildRealm, ApplyList);
						PlayerRealm =:= 100 ->%%还是新手
							lib_guild_inner:remove_guild_apply(PlayerId, GuildId),
							reply_apply_guild_each(Num, SendList, GuildId, GuildName, GuildRealm, ApplyList);
						PlayerRealm =/= GuildRealm ->%%阵营不一样
							lib_guild_inner:remove_guild_apply(PlayerId, GuildId),
							reply_apply_guild_each(Num, SendList, GuildId, GuildName, GuildRealm, ApplyList);
						PlayerLv < ?CREATE_GUILD_LV ->%%允许加入但对方等级不够
							lib_guild_inner:remove_guild_apply(PlayerId, GuildId),
							reply_apply_guild_each(Num, SendList, GuildId, GuildName, GuildRealm, ApplyList);
						TimeRest =< 43200 ->%%允许加入但最近有加入并退出过氏族，间隔时间太短
							lib_guild_inner:remove_guild_apply(PlayerId, GuildId),
							reply_apply_guild_each(Num, SendList, GuildId, GuildName, GuildRealm, ApplyList);
						true ->
							DefaultPosition = data_guild:get_guild_config(default_position, []),
							case lib_guild_inner:add_guild_member(PlayerId, PlayerNickname, GuildId, GuildName, DefaultPosition,
																  PlayerSex, PlayerJobs, PlayerLv, PlayerLastLoginTime, PlayerOnlineFlag,
																  PlayerCareer, PlayerCulture, PlayerVip) of
								ok ->
									SendElem = {PlayerId,PlayerNickname,GuildId, GuildName, DefaultPosition},
									reply_apply_guild_each(Num+1, [SendElem|SendList], GuildId, GuildName, GuildRealm, ApplyList);
								_  ->
									reply_apply_guild_each(Num, SendList, GuildId, GuildName, GuildRealm, ApplyList)
							end
					end
			end
	end.

%%拒绝加入		
refuse_join_guild_inner(GuildId, GuildName, ApplyList) ->
	lists:foreach(fun(Elem) ->
						  {PlayerId, PlayerNameGet} = Elem,
						  delete_remove_guild_apply(PlayerId, GuildId, GuildName, PlayerNameGet)
				  end, ApplyList).
% 发送通知/邮件通知
handle_msg_to_player_each([]) ->
	ok;
handle_msg_to_player_each([SendElem|SendList]) ->
	{PlayerId,PlayerNickname,GuildId, GuildName, DefaultPosition} = SendElem,
	% 发送通知/邮件通知
	lib_guild_inner:send_msg_to_player(PlayerId, guild_new_member, 
									   [PlayerId, PlayerNickname, GuildId, GuildName, DefaultPosition]),
	lib_guild:send_guild_mail(guild_new_member, [PlayerId, PlayerNickname, GuildId, GuildName]),
	%%添加成员加入氏族日志
	lib_guild_inner:jion_guild_log(PlayerNickname, GuildId, GuildName),
	handle_msg_to_player_each(SendList).

%% -----------------------------------------------------------------
%% 添加新成员
%% -----------------------------------------------------------------
add_guild_member(PlayerId, PlayerName, GuildId, GuildName, GuildPosition,
				 PlayerSex, PlayerJobs, PlayerLevel, PlayerLastLoginTime, PlayerOnlineFlag, PlayerCareer, PlayerCulture,PlayerVip) ->
    % 插入氏族成员
	DepartName = tool:to_binary(""),
    CreateTime    = util:unixtime(),
%% 	FieldList = [guild_id,guild_name,player_id,player_name,create_time, guild_depart_name],
%%     Data      = [GuildId, GuildName, PlayerId, PlayerName,CreateTime, DepartName],
%% 	FieldList =  [guild_id, guild_name, player_id, player_name, donate_funds, donate_total,
%% 				  donate_lasttime, donate_total_lastday, donate_total_lastweek, create_time,
%% 				  title, remark, honor, guild_depart_name, guild_depart_id],
%% 	Data = [GuildId, GuildName, PlayerId, PlayerName, 0,0,
%% 			0, 0, 0, CreateTime,
%% 			"", "", "", "", 0],
%% 	
%%     db_agent:guild_member_insert(FieldList, Data),
	% 插入氏族成员
	Guild_member = 
		#ets_insert_guild_member{
						  guild_id = GuildId,
						  guild_name = GuildName,
						  player_id = PlayerId, 
						  player_name = PlayerName, 
						  create_time = CreateTime,
						  guild_depart_id = 5,
						  unions = 0},
	case db_agent:guild_member_insert(Guild_member) of
		{mongo, Ret} ->
			Id = Ret,
			    % 更新角色表
			ValueList = [{guild_id, GuildId}, 
						 {guild_name, GuildName}, 
						 {guild_position, GuildPosition},
						 {quit_guild_time, 0},
						 {guild_depart_name, DepartName},
						 {guild_depart_id, 5}
						],
			WhereList = [{id, PlayerId}],	
			db_agent:guild_player_update_info(ValueList, WhereList),
			% 更新氏族表
			db_agent:guild_update_member_num(GuildId),
			% 删除氏族申请
			remove_guild_apply_all(PlayerId),
			% 删除氏族邀请
			remove_guild_invite_all(PlayerId),
			% 更新缓存
			GuildMember = #ets_guild_member{id = Id,       
											guild_id = GuildId,     
											guild_name = GuildName,        
											player_id = PlayerId,        
											player_name = PlayerName,     
											donate_funds = 0,    
											donate_total = 0,                   
											donate_lasttime = 0,    
											donate_total_lastday = 0,      
											donate_total_lastweek = 0,      
											create_time = CreateTime,          
											title = Guild_member#ets_insert_guild_member.title, 
											remark = Guild_member#ets_insert_guild_member.remark,    
											honor = Guild_member#ets_insert_guild_member.honor,         
											guild_depart_name = DepartName,    
											guild_depart_id = Guild_member#ets_insert_guild_member.guild_depart_id,    
											sex = PlayerSex,
											jobs = PlayerJobs,      
											lv = PlayerLevel, 
											guild_position = GuildPosition,          
											last_login_time = PlayerLastLoginTime,
											online_flag = PlayerOnlineFlag,
											career = PlayerCareer,  
											culture = PlayerCulture,
											vip = PlayerVip,
											unions = 0},
			load_guild_member_into_ets(GuildMember),
			%%更新氏族聊天面板信息
			gen_server:cast(mod_guild:get_mod_guild_pid(), {'BROADCAST_GUILD_GROUP',GuildId}),
			%%在群聊面板广播
			gen_server:cast(mod_guild:get_mod_guild_pid(), {'BROADCAST_NEW_MEMBER',GuildId,PlayerName}),
			ok;
		1 ->
			ValueList = [{guild_id, GuildId}, 
						 {guild_name, GuildName},
						 {guild_position, GuildPosition},
						 {quit_guild_time, 0},
						 {guild_depart_name, DepartName}],
			WhereList = [{id, PlayerId}],	
			db_agent:guild_player_update_info(ValueList, WhereList),
			case db_agent:guild_member_select_new(PlayerId, GuildId) of
				[] ->
					fail;
				GuildMemberInfo ->
					% 更新氏族表
					db_agent:guild_update_member_num(GuildId),
					% 删除氏族申请
					remove_guild_apply_all(PlayerId),
					% 删除氏族邀请
					remove_guild_invite_all(PlayerId),
					% 更新缓存
					GuildMember = list_to_tuple([ets_guild_member] ++ GuildMemberInfo),
					load_guild_member_into_ets(GuildMember),
					ok
			end;
		_Other ->
			fail
	end.

%% -----------------------------------------------------------------
%% 添加成员氏族日志
%% -----------------------------------------------------------------
jion_guild_log(PlayerName, GuildId, GuildName) ->
	CreateTime = util:unixtime(),
	Content = lists:concat([?JOIN_GUILD_ONE, tool:to_list(PlayerName), ?JOIN_GUILD_TWO]),
	Log_guild = #ets_log_guild{
					guild_id = GuildId, 
					guild_name = GuildName, 
					time = CreateTime, 
					content	= Content	   
					},
	case db_agent:guild_log_insert(Log_guild) of
		{mongo, Ret} ->
			GuildLogEts = Log_guild#ets_log_guild{id = Ret},
			lib_guild_inner:update_guild_log(GuildLogEts);
		1 ->
			GuildLog = db_agent:guild_log_select_create(GuildId, GuildName),
			if GuildLog =:= [] ->
				   ?ERROR_MSG("create_guild: guild id is null, name=[~s]", [GuildName]);
			   true ->
				   GuildLogEts = list_to_tuple([ets_log_guild] ++ GuildLog),
				   lib_guild_inner:update_guild_log(GuildLogEts)
			end;
		_Other ->
			noaction
	end.

%% -----------------------------------------------------------------
%% 添加氏族会员退出帮会日志
%% -----------------------------------------------------------------
quit_guild_log(PlayerName, Guild) ->
	#ets_guild{name = GuildName,
			   id = GuildId} = Guild,
	CreateTime = util:unixtime(),
	Content = lists:concat([PlayerName, ?QUIT_GUILD]),
	Log_guild = #ets_log_guild{
					guild_id = GuildId, 
					guild_name = GuildName, 
					time = CreateTime, 
					content	= Content	   
					},
%% 	db_agent:guild_log_insert(Log_guild),	
%% 	GuildLog = db_agent:guild_log_select_create(GuildId, GuildName),
%% 	if GuildLog =:= [] ->
%% 		   ?ERROR_MSG("create_guild: guild id is null, name=[~s]", [GuildName]);
%% 	   true ->
%% 		   GuildLogEts = list_to_tuple([ets_log_guild] ++ GuildLog),
%% 		   lib_guild_inner:update_guild_log(GuildLogEts)
%% 	end.
	case db_agent:guild_log_insert(Log_guild) of
		{mongo, Ret} ->
			GuildLogEts = Log_guild#ets_log_guild{id = Ret},
			lib_guild_inner:update_guild_log(GuildLogEts);
		1 ->
			GuildLog = db_agent:guild_log_select_create(GuildId, GuildName),
			if GuildLog =:= [] ->
				   ?ERROR_MSG("create_guild: guild id is null, name=[~s]", [GuildName]);
			   true ->
				   GuildLogEts = list_to_tuple([ets_log_guild] ++ GuildLog),
				   lib_guild_inner:update_guild_log(GuildLogEts)
			end;
		_Other ->
			noaction
	end.

%% -----------------------------------------------------------------
%% 删除成员
%% -----------------------------------------------------------------
remove_guild_member(QuitTime, PlayerId, GuildId, DeputyChielfId1, DeputyChielfId2) ->
    % 更新角色表
	ValueList = [{guild_id, 0}, 
				 {guild_name, ""}, 
				 {guild_position, 0},
				 {guild_depart_id, 0},
				 {guild_depart_name, ""},
				 {guild_title, ""},
				 {quit_guild_time ,QuitTime}
				],
	WhereList = [{id, PlayerId}],	
    db_agent:guild_player_update_info(ValueList, WhereList),
    % 更新氏族表
    case PlayerId =:= DeputyChielfId1 of
        true ->
            db_agent:guild_update_remove_deputy1(GuildId),
           MemberType =  1;
        false when PlayerId =:= DeputyChielfId2 ->
            db_agent:guild_update_remove_deputy2(GuildId),
           MemberType =  2;
        false ->
            db_agent:guild_update_member_num_deduct(GuildId),
            MemberType = 0
    end,
    % 删除氏族成员表
    db_agent:guild_member_delete_one(PlayerId, GuildId),
    % 更新缓存
    delete_guild_member_by_player_id(PlayerId),
    [ok, MemberType].

match_guild_object(0, Match, _Continuation) ->
	Match;
match_guild_object(Num, Match, Continuation) ->
	case ets:match_object(Continuation) of
		'$end_of_table' ->
			Match;
		{MMatch, NC} ->
			match_guild_object(Num-1, MMatch, NC);
		 _ ->
			 Match
	end.
%% -----------------------------------------------------------------
%% 40010 获取氏族列表
%% -----------------------------------------------------------------
get_guild_page(PidSend, _OwnGId, Realm, Type, Page, GuildName, ChiefName) ->
%%     ?DEBUG("OwnGId:~p, Realm:~p, Type:~p, Page:~p, GuildName:~p, ChiefName:~p", [OwnGId, Realm, Type, Page, GuildName, ChiefName]),
	Pattern= 
		case Type of
			1 ->
				case Realm of
					0 ->%%没有部落的判断
						CNLen = length(ChiefName),
						case length(GuildName) of
							0 ->%%不用判断氏族名
								case CNLen of
									0 ->%%没有族长的判断
										MatchSpec = ets:fun2ms(fun(G) when G#ets_guild.id > 0 -> true end),
										#ets_guild{_='_'};
									_ ->
										CNBin = list_to_binary(ChiefName),
										MatchSpec = ets:fun2ms(fun(G) when G#ets_guild.realm =/= 0
																	andalso G#ets_guild.chief_name =:= CNBin -> true end),
										#ets_guild{chief_name = CNBin, _='_'}
								end;
							_ ->
								GNBin = list_to_binary(GuildName),
								case CNLen of
									0 ->%%没有族长的判断
										MatchSpec = ets:fun2ms(fun(G) when G#ets_guild.id > 0 -> true end),
										#ets_guild{name = GNBin, _='_'};
									_ ->
										CNBin = list_to_binary(ChiefName),
										MatchSpec = ets:fun2ms(fun(G) when G#ets_guild.realm =/= 0
																	andalso G#ets_guild.chief_name =:= CNBin 
																	andalso G#ets_guild.name =:= GNBin -> true end),
										#ets_guild{name = GNBin, chief_name = CNBin, _='_'}
								end
						end;
					_ ->
						CNLen = length(ChiefName),
						case length(GuildName) of
							0 ->%%不用判断氏族名
								case CNLen of
									0 ->%%没有族长的判断
										MatchSpec = ets:fun2ms(fun(G) when G#ets_guild.realm =:= Realm -> true end),
										#ets_guild{realm = Realm, _='_'};
									_ ->
										CNBin = list_to_binary(ChiefName),
										MatchSpec = ets:fun2ms(fun(G) when G#ets_guild.realm =:= Realm 
																	andalso G#ets_guild.chief_name =:= CNBin -> true end),
										#ets_guild{realm = Realm, chief_name = CNBin, _='_'}
								end;
							_ ->
								GNBin = list_to_binary(GuildName),
								case CNLen of
									0 ->%%没有族长的判断
										MatchSpec = ets:fun2ms(fun(G) when G#ets_guild.realm =:= Realm 
																	andalso G#ets_guild.name =:= GNBin -> true end),
										#ets_guild{realm = Realm, name = GNBin, _='_'};
									_ ->
										CNBin = list_to_binary(ChiefName),
										MatchSpec = ets:fun2ms(fun(G) when G#ets_guild.realm =:= Realm 
																	andalso G#ets_guild.chief_name =:= CNBin 
																	andalso G#ets_guild.name =:= GNBin -> true end),
										#ets_guild{realm = Realm, name = GNBin, chief_name = CNBin, _='_'}
								end
						end
				end;
			2 ->%%查询其他氏族，直接只是匹配部落即可
				MatchSpec = ets:fun2ms(fun(G) when G#ets_guild.realm =:= Realm -> true end),
				#ets_guild{realm = Realm, _='_'}
		end,			
	%%分页的数量
	Limit = 
		case Type of
			1 ->
				8;
			2 ->
				9
		end,
	%%求长度
	Total = ets:select_count(?ETS_GUILD, MatchSpec),
	%%向上取整，不足一页取一页
	TPage = util:ceil(Total/Limit),
	%%求需要返回的分页
	Guilds = 
		case Page > TPage of
			true ->%%发的分页太大了，没数据啦
%% 				?DEBUG("page to large:~p", [Page]),
				NewPage = 1,
				case ets:match_object(?ETS_GUILD, Pattern, Limit) of
					'$end_of_table' ->
%% 						?DEBUG("$end_of_table", []),
						[];
					{Match,_Continuation} ->%% 是第一页
						Match;
					_ ->
						[]
				end;
			false ->
				NewPage = Page,
				case ets:match_object(?ETS_GUILD, Pattern, Limit) of
					'$end_of_table' ->
%% 						?DEBUG("$end_of_table", []),
						[];
					{Match,Continuation} ->%%这是第一页
%% 						?DEBUG("page:~p", [Page]),
						case Page of
							1 ->
								Match;
							_ ->
								match_guild_object(Page-1, [],Continuation)
						end;
					_ ->
						[]
				end
		end,
	%%处理返回数据
    Records = lists:map(fun handle_guild_page/1, Guilds),
%%	?DEBUG("the result guilds len is ~p, ~p, ~p", [Total, NewPage, TPage]),
	{ok, BinData} = pt_40:write(40010, [TPage, NewPage, Records]),
    lib_send:send_to_sid(PidSend, BinData).

%%按照氏族的等级排序
sort_guild_by_level(Guild1, Guild2) ->
    case Guild1#ets_guild.level =< Guild2#ets_guild.level of
        true  -> false;
        false -> true
    end.

handle_guild_page(Guild) ->
	#ets_guild{id = GuildId,
			   name = GuildName,
			   chief_id = ChiefId,
			   chief_name = ChiefName,
			   member_num = MemberNum,
%% 			   member_capacity = MemberCapacity,
			   level = Level,
			   realm = Realm,
			   announce = Announce,
			   exp = Exp,
			   funds = Funds} = Guild,
	%%计算氏族人数上限
	PopulationLevel = lib_guild:get_guild_skill_level(GuildId, 3),
	MemberCapacity = data_guild:get_guild_config(guild_member_base,[]) + PopulationLevel * 5,
	{GuildId, GuildName, Announce, Realm, Level, Exp, MemberNum, MemberCapacity, ChiefId, ChiefName, Funds}.


%% -----------------------------------------------------------------
%% 获取成员列表
%% -----------------------------------------------------------------
get_guild_member_page(PidSend, GuildId) ->
	[RLevel, RLen, RData] = 
	case get_guild(GuildId) of
		[] ->
			[0, 0, list_to_binary([])];
		Guild ->
    % 获取总记录数
    GuildMembers = get_guild_member_by_guild_id(GuildId),
	
    RecordTotal  = length(GuildMembers),
	%%处理返回数据
    Records = lists:map(fun handle_member_page/1, GuildMembers),
    % 发送回应
    [Guild#ets_guild.level, RecordTotal, list_to_binary(Records)]
	end,
%% 	?DEBUG("******** 4001140011400114001140011 *********", []),
	{ok, BinData} = pt_40:write(40011, [RLevel, RLen, RData]),
    lib_send:send_to_sid(PidSend, BinData).

handle_member_page(GuildMember) ->
	#ets_guild_member{player_id = PlayerId,
					  player_name = PlayerName,
					  sex = PlayerSex,
					  lv = PlayerLevel,
					  last_login_time = LastLoginTime,
					  guild_position = GuildPosition,
					  donate_funds = DonateFunds,
					  donate_total = DonateTotal,
					  online_flag = OnlineFlag,
					  career = PlayerCareer,
					  title = Title,
					  guild_depart_name = DepartmentName,
					  vip = MemberVip} = GuildMember,
	{PlayerNameLen, PlayerNameBin} = string_to_binary_and_len(PlayerName),
%%     PlayerNameLen = byte_size(PlayerName),
	{TitleLen, TitleBin} = string_to_binary_and_len(Title),
%% 	TitleLen = byte_size(Title),
	{DepartmentNameLen, DepartmentNameBin} = string_to_binary_and_len(DepartmentName),
%% 	DepartmentNameBin = tool:to_binary(DepartmentName),
%% 	DepartNameLen = byte_size(DepartmentNameBin),
    <<PlayerId:32, PlayerNameLen:16, PlayerNameBin/binary, PlayerSex:16, PlayerCareer:16, 
	  PlayerLevel:16, LastLoginTime:32, GuildPosition:16, DonateTotal:32, OnlineFlag:16,
	  DonateFunds:32, TitleLen:16, TitleBin/binary, DepartmentNameLen:16, DepartmentNameBin/binary,MemberVip:8>>.


%% -----------------------------------------------------------------
%% 40012 获取申请列表
%% -----------------------------------------------------------------
get_guild_apply_page(PidSend, GuildId) ->
    % 获取总记录数
    GuildApplys = get_guild_apply_by_guild_id(GuildId),
    RecordTotal  = length(GuildApplys),
	%%处理返回数据
    Records = lists:map(fun handle_apply_page/1, GuildApplys),
    % 发送回应
	{ok, BinData} = pt_40:write(40012, [RecordTotal, list_to_binary(Records)]),
    lib_send:send_to_sid(PidSend, BinData).

handle_apply_page(GuildApply) ->
	#ets_guild_apply{player_id = PlayerId,
					 nickname = PlayerName,
					 sex = PlayerSex,
					 lv = PlayerLevel,
					 create_time = ApplyTime,
					 career = PlayerCareer,
					 online_flag = OnLineFlag,
					 vip = PlayerVip} = GuildApply,
	{PlayerNameLen, PlayerNameBin} = string_to_binary_and_len(PlayerName),
%% 	?DEBUG("PlayerId:~p, PlayerSex:~p, PlayerCareer:~p, PlayerLevel:~p, ApplyTime:~p,OnLineFlag:~p,PlayerVip:~p",
%% 		   [PlayerId, PlayerSex, PlayerCareer, PlayerLevel, ApplyTime,OnLineFlag,PlayerVip]),
    <<PlayerId:32, PlayerSex:16, PlayerCareer:16, PlayerLevel:32, ApplyTime:32, PlayerNameLen:16, PlayerNameBin/binary, OnLineFlag:16, PlayerVip:8>>.

%% -----------------------------------------------------------------
%% 40013 获取邀请列表
%% -----------------------------------------------------------------
get_guild_invite_page(PidSend, PlayerId) ->
    % 获取总记录数
    GuildInvites = get_guild_invite_by_player_id(PlayerId),
%%     RecordTotal = length(GuildInvites),
    % 处理返回数据
%%     Records = lists:map(fun handle_invite_page/1, GuildInvites),
	Records = handle_invite_page(GuildInvites, []),
    % 发送回应
%%     [RecordTotal, list_to_binary(Records)].
	{ok, BinData} = pt_40:write(40013, [Records]),
    lib_send:send_to_sid(PidSend, BinData).

handle_invite_page([],Result) ->
	Result;
handle_invite_page([GuildInvite|ResGuildInvite], Result) ->
	#ets_guild_invite{guild_id = GuildId,
					  create_time = InviteTime,
					  recommander_name = RecommanderName} = GuildInvite,
    Guild = get_guild(GuildId),
    case Guild of
        [] ->
            handle_invite_page(ResGuildInvite, Result);
        _ ->
			#ets_guild{name = GuildName,
					   announce = Announce,
					   chief_id = ChiefId,
					   chief_name = ChiefName,
					   member_num = MemberNum,
%% 					   member_capacity = MemberCapacity,
					   level = Level,
					   realm = Realm,
					   upgrade_last_time = UpGradeLastTime} = Guild,
				%%计算氏族人数上限
			PopulationLevel = lib_guild:get_guild_skill_level(GuildId, 3),
			MemberCapacity = data_guild:get_guild_config(guild_member_base,[]) + PopulationLevel * 5,
			
			%%判断氏族的等级和升级时间
			case UpGradeLastTime == 0 of
				true ->
					NewLevel = Level;
				false ->
					NewLevel = Level - 1
			end,
			Elem = {GuildId, GuildName, ChiefId, ChiefName, MemberNum, MemberCapacity, 
					NewLevel, Realm, Announce, InviteTime, RecommanderName},
			handle_invite_page(ResGuildInvite, [Elem|Result])
	end.


%% -----------------------------------------------------------------
%%获取玩家的氏族中所属的堂ID
%% -----------------------------------------------------------------
get_player_apart_id(PlayerId) ->
	db_agent:get_player_apart_id(PlayerId).

%% -----------------------------------------------------------------
%% 获取氏族信息
%% -----------------------------------------------------------------
get_guild_info(GuildId) ->
%%     io:format("****** get_guild_info: GuildId=[~p] ****** ", [GuildId]),
    Guild = get_guild(GuildId),
    if  % 氏族不存在
        Guild =:= [] ->
            [2, {}];
        true ->
			#ets_guild{id = GuildId,
					   name = Name,
					   announce = Announce,
					   chief_id = ChiefId,
					   chief_name = ChiefName,
					   member_num = MemberNum,
%% 					   member_capacity = MemberCapacity,
					   realm = Realm,
					   exp = Exp,
					   level = Level,
					   funds = Funds,
					   upgrade_last_time = UpGradeLastTime,
					   depart_names = DepartNames} = Guild,
			%%计算氏族人数上限
			PopulationLevel = lib_guild:get_guild_skill_level(GuildId, 3),
			MemberCapacity = data_guild:get_guild_config(guild_member_base,[]) + PopulationLevel * 5,
			
			[_NeedFunds, NeedExp, UpGradeNeedTime, _AddSkills] = data_guild:get_guild_upgrade_info(Level+1),

			NowTime = util:unixtime(),
			%%获取升级剩余时间
			case UpGradeLastTime =:= 0 of
				true ->
					NewRestUpGradeTime = 0;
				false ->
					RestTime = UpGradeLastTime + UpGradeNeedTime - NowTime,
					case RestTime >= 0 of
						true ->
							NewRestUpGradeTime = RestTime;
						false ->%%7秒的延时
							NewRestUpGradeTime = 7
					end
			end,
			%%获取氏族日志
			[LogsLen, Logs] = get_log_guild(GuildId),
			%%获取当前氏族的联盟氏族信息
			Alliances = lib_guild_alliance:get_guild_alliances(GuildId),
			Data = {GuildId, Name, Announce, Realm, Level, Exp, NeedExp, MemberNum, 
					MemberCapacity, ChiefId, ChiefName, Funds, NewRestUpGradeTime,
					DepartNames, LogsLen, Logs, Alliances},
					[1, Data]
    end.

%% -----------------------------------------------------------------
%% 修改氏族公告
%% -----------------------------------------------------------------
modify_guild_announce(GuildId, Announce) ->
    db_agent:guild_update_announce(GuildId, Announce),
    ok.

%% -----------------------------------------------------------------
%% 职位设置
%% -----------------------------------------------------------------
set_member_post(HostPlayerId, HostPlayerName, HostGuildId, HostGuildPosition,
				[MemGuildId, MemPlayerId, MemPost, MemDepartId, MemGuildTitle, MemDepartName]) ->
	if%%你没有加入任何氏族
		HostPlayerId == 0 -> [2, <<>>, 0, ""];
		%%你不能自封职位
		HostPlayerId == MemPlayerId -> [3, <<>>, 0, ""];
		%%不是族长或长老，没权限
		HostGuildPosition > 3 -> [4, <<>>, 0, ""];
		true ->
			PlayerInfo = lib_guild_inner:get_player_guild_info(MemPlayerId),
			Guild = lib_guild_inner:get_guild(HostGuildId),
			if%%玩家不存在
				PlayerInfo =:= [] -> [5, <<>>, 0, ""];
				%%氏族信息缺失
				Guild =:= [] -> [6, <<>>, 0, ""];
				true ->
					[MemPlayerName, _MemPlayerRealm, MemPlayerGuildId, 
					 _MemPlayerGuldName, MemPlayerPosition, _MemPlayerLv, _MemPlayerQuitGuildTime, 
					 _PlayerSex, _PlayerJobs,
					 _PlayerLastLoginTime, _PlayerOnlineFlag, _PlayerCareer, _PlayerCulture, _PlayerDepartMentId, _PlayerVip] = PlayerInfo,
					if%%对方没有加入氏族
						MemPlayerGuildId == 0 -> [7, <<>>, 0, ""];
						%%对方不是本帮成员
						MemGuildId /= HostGuildId -> [8, <<>>, 0, ""];
						%%对方的职位不比你低
						MemPlayerPosition =:= 2 andalso HostGuildPosition =:= 3 -> [9, <<>>, 0, ""];
						MemPlayerPosition =:= 3 andalso HostGuildPosition =:= 2 -> [9, <<>>, 0, ""];
						%%对方的职位不比你低
						MemPlayerPosition =< HostGuildPosition -> [9, <<>>, 0, ""];
						true ->%% 够设置职位
							#ets_guild{id = GuildId,
									   name = GuildName,
									   deputy_chief1_id = DeputyChief1Id,
									   deputy_chief2_id = DeputyChief2Id,
									   deputy_chief_num = DeputyChiefNum} = Guild,
							case MemPost of
								1 ->%%设为长老
									if 
										HostGuildPosition =:= 2 orelse HostGuildPosition =:= 3 ->%%自己也是长老
											[4, <<>>, 0, ""];
										DeputyChiefNum == 2 -> %%长老位置已满
											[10, <<>>, 0, ""];
										MemDepartId /= 5 -> error;
										true  ->
											GuildPositName = get_guild_position_names(MemPost, MemDepartId, MemDepartName),
											SetType = set_position_deputy(MemPlayerId, MemPlayerName, 
																		  MemGuildId, MemGuildTitle, 
																		  DeputyChief1Id, DeputyChief2Id),
											%%更新player的信息，SetType = 2 or 3 or 0
											update_guild_post(SetType, Guild, DeputyChiefNum, MemPlayerId, MemPlayerName),
										%%	GuildMember = get_guild_member_by_player_id(MemPlayerId),
											case SetType of
												0 ->
													error;
												_ ->
												%%	GuildMemberNew = GuildMember#ets_guild_member{guild_position = SetType},
												%%	update_guild_member(GuildMemberNew),
													%%更新氏族职位变化日志
													set_position_log(MemPlayerName, HostPlayerName, GuildId, GuildName, 2, GuildPositName),
													[1, MemPlayerName, SetType, GuildPositName]
											end										
									end;
								2 ->%%设为堂主
									if 
									   (MemDepartId < 1) orelse (MemDepartId > 4) -> error;
										true  ->
											Depart = %%参数：帮派名，堂Id，帮派位置Id（只要是堂主，其帮派位置Id一定要等于堂id+3）
												db_agent:guild_get_depart(GuildId, MemDepartId, MemDepartId+3),
											case Depart =:= [] of
												false ->
													[11, <<>>, 0, ""];%%该堂主职位已赋予别人
												true ->
													GuildPositName = get_guild_position_names(MemPost, MemDepartId, MemDepartName),
													if%%对方本来就是长老
														MemPlayerId =:= DeputyChief1Id ->
															update_guild_post(4, Guild, DeputyChiefNum, MemPlayerId, MemPlayerName),
															%%更新氏族职位变化日志
															set_position_log(MemPlayerName, HostPlayerName, GuildId, GuildName, 1, GuildPositName);
														MemPlayerId =:= DeputyChief2Id ->
															update_guild_post(5, Guild, DeputyChiefNum, MemPlayerId, MemPlayerName),
															%%更新氏族职位变化日志
															set_position_log(MemPlayerName, HostPlayerName, GuildId, GuildName, 1, GuildPositName);
														true ->%%不用做什么操作
															%%更新氏族职位变化日志
															set_position_log(MemPlayerName, HostPlayerName, GuildId, GuildName, 3, GuildPositName),
															void
													end,
													case set_position_depart(GuildId, MemPlayerId, MemDepartId, MemPost, MemGuildTitle, MemDepartName) of
														error ->
															error;
														GuildPosition ->
															[1, MemPlayerName, GuildPosition, GuildPositName]
													end
											end
									end;
								3 ->%%设为弟子
									if
										MemDepartId < 1 orelse MemDepartId > 5 -> error;
										%%对方本来就是长老
										true ->
											GuildPositName = get_guild_position_names(MemPost, MemDepartId, MemDepartName),
											if MemPlayerId =:= DeputyChief1Id ->
												   update_guild_post(4, Guild, DeputyChiefNum, MemPlayerId, MemPlayerName),
												   %%更新氏族职位变化日志
												   set_position_log(MemPlayerName, HostPlayerName, GuildId, GuildName, 1, GuildPositName);
											   MemPlayerId =:= DeputyChief2Id ->
												   update_guild_post(5, Guild, DeputyChiefNum, MemPlayerId, MemPlayerName),
												   %%更新氏族职位变化日志
												   set_position_log(MemPlayerName, HostPlayerName, GuildId, GuildName, 1, GuildPositName);
											   true ->%%不是长老，因此不用更新长老的问题
												   %%更新氏族职位变化日志
												   set_position_log(MemPlayerName, HostPlayerName, GuildId, GuildName, 3, GuildPositName),
												   void
											end,
											case set_position_depart(GuildId, MemPlayerId, MemDepartId, MemPost, MemGuildTitle, MemDepartName) of
												error ->
													error;
												GuildPosition ->
													[1, MemPlayerName, GuildPosition, GuildPositName]
											end
									end;
 								0 ->%% 位没变，仅改 称号
									%%更新玩家数据库数据
%% 									db_agent:player_guild_title_update_only(MemGuildTitle, MemPlayerId),
%% 									%%更新氏族成员数据库信息
%% 									db_agent:guild_member_title_update_only(MemGuildTitle, MemPlayerId),
%% 									GuildMember = db_agent:guild_member_select_new(MemPlayerId),
%% 									GuildMemberNew = list_to_tuple([ets_guild_member]++GuildMember),
%% 									update_guild_member(GuildMemberNew),
									case db_agent:guild_member_select_new(MemPlayerId, MemGuildId) of
										[] -> [5, <<>>, 0, ""];
										GuildMember ->
											db_agent:player_guild_title_update_only(MemGuildTitle, MemPlayerId),
											%%更新氏族成员数据库信息
											db_agent:guild_member_title_update_only(MemGuildTitle, MemPlayerId),
											GuildMemberEts = list_to_tuple([ets_guild_member]++GuildMember),
											GuildMemberNew = GuildMemberEts#ets_guild_member{title = MemGuildTitle},
											update_guild_member(GuildMemberNew),
											[20, MemPlayerName, 0, ""]
									end
							end
					end
			end
	end.
									
%%设置长老位子							
set_position_deputy(MemPlayerId, MemPlayerName, MemGuildId, MemGuildTitle, DeputyChief1Id, DeputyChief2Id) ->
	%%设置长老的位子
	if%%对方本来就是长老
		MemPlayerId == DeputyChief1Id orelse MemPlayerId == DeputyChief2Id
		  -> 
			SetType = 0;
		DeputyChief1Id == 0 -> 
			db_agent:guild_update_add_deputy1(MemPlayerId, MemPlayerName, MemGuildId),
			SetType = 2;
		DeputyChief2Id == 0 -> 
			db_agent:guild_update_add_deputy2(MemPlayerId, MemPlayerName, MemGuildId),
			SetType = 3;
		true ->
			SetType = 0
	end,
	case SetType of
		0 ->
		NewSetType = SetType;
		_ ->
			case db_agent:guild_member_select_new(MemPlayerId, MemGuildId) of
				[] ->
					NewSetType = 0;
				GuildMember ->
					% 更新角色表
					db_agent:player_update_guild_position_deputy(SetType, MemGuildTitle, MemPlayerId),
					%%更新氏族成员列表(GuildTitle, DepartId, DepartName, PlayerId)
					db_agent:update_guild_member_position(MemGuildTitle, 5, "", MemPlayerId),		
					GuildMemberEts = list_to_tuple([ets_guild_member]++GuildMember),
					GuildMemberNew = GuildMemberEts#ets_guild_member{title = MemGuildTitle,
																	  guild_position = SetType,
																	  guild_depart_id = 5,
																	  guild_depart_name = ""},
					update_guild_member(GuildMemberNew),
					NewSetType = SetType
			end
	end,
    NewSetType.

update_guild_post(SetType, Guild, DeputyChiefNum, MemPlayerId, MemPlayerName) ->
	case SetType of 
		0 ->
			void;
		2 ->
			GuildNew = Guild#ets_guild{deputy_chief_num   = DeputyChiefNum+1,
									   deputy_chief1_id   = MemPlayerId,
									   deputy_chief1_name = MemPlayerName},
			lib_guild_inner:update_guild(GuildNew);
%% 			%%添加职位更新日志
%% 			lib_guild_inner:set_position_log(HostPlayerName, MemPlayerName, GuildNew, 2, GuildPositName);
		3 ->
			GuildNew = Guild#ets_guild{deputy_chief_num   = DeputyChiefNum+1,
									   deputy_chief2_id   = MemPlayerId,
									   deputy_chief2_name = MemPlayerName},
			lib_guild_inner:update_guild(GuildNew);
%% 			lib_guild_inner:set_position_log(HostPlayerName, MemPlayerName, GuildNew, 2, GuildPositName);
		4 ->
			GuildNew = Guild#ets_guild{deputy_chief_num   = DeputyChiefNum-1,
									   deputy_chief1_id   = 0,
									   deputy_chief1_name = <<>>},
			db_agent:guild_update_deduct_deputy1(Guild#ets_guild.id),
			lib_guild_inner:update_guild(GuildNew);
%% 			lib_guild_inner:set_position_log(HostPlayerName, MemPlayerName, GuildNew, 1, GuildPositName);
		5 ->
			GuildNew = Guild#ets_guild{deputy_chief_num   = DeputyChiefNum-1,
									   deputy_chief2_id   = 0,
									   deputy_chief2_name = <<>>},
			db_agent:guild_update_deduct_deputy2(Guild#ets_guild.id),
			lib_guild_inner:update_guild(GuildNew)
%% 			lib_guild_inner:set_position_log(HostPlayerName, MemPlayerName, GuildNew, 1, GuildPositName)
	end.
			

set_position_depart(GuildId, MemPlayerId, MemDepartId, MemPost, MemGuildTitle, MemDepartName) ->
	case MemPost of
		3 ->
			GuildPosition = 
				case MemDepartId of
					0 ->
						12;
					1 ->
						8;
					2 ->
						9;
					3 ->
						10;
					4 ->
						11;
					5 ->
						12
				end;
		_ ->
			GuildPosition = MemDepartId + 3
	end,
	case db_agent:guild_member_select_new(MemPlayerId, GuildId) of
		[] ->
			error;
		GuildMember ->
			db_agent:player_update_guild_position_depart(MemDepartId, GuildPosition, MemGuildTitle, MemDepartName, MemPlayerId),
			%%更新氏族成员列表(GuildTitle, DepartId, DepartName, PlayerId)
			db_agent:update_guild_member_position(MemGuildTitle, MemDepartId, MemDepartName, MemPlayerId),
			GuildMemberEts = list_to_tuple([ets_guild_member]++GuildMember),
			GuildMemberNew = GuildMemberEts#ets_guild_member{guild_depart_id = MemDepartId,
															 guild_position = GuildPosition,
															 title = MemGuildTitle,
															 guild_depart_name = MemDepartName},
			update_guild_member(GuildMemberNew),
			GuildPosition
	end.

%%获取氏族职位的名称
get_guild_position_names(Post, DepartId, DepartName) ->
	PositionNameRest = data_guild:get_departmemt_names(Post, DepartId),
	if Post == 2 ->
		   DepartName++PositionNameRest;
	   Post == 3 andalso (DepartId >= 1) -> 
		   DepartName++PositionNameRest;
	   true ->
		   PositionNameRest
	end.

					
%% -----------------------------------------------------------------
%% 辞去官职处理
%% -----------------------------------------------------------------
resign_position(PlayerId, _PlayerName, GuildId, _Position, DefaultPosition, DeputyChielfId1, DeputyChielfId2) ->
   db_agent:player_update_guild_position(DefaultPosition, PlayerId, 5),
  % 更新缓存
  GuildMember = get_guild_member_by_player_id(PlayerId),
  MemberType  = if
				 PlayerId == DeputyChielfId1 ->
					 db_agent:guild_update_deduct_deputy1(GuildId),
					 1;
				 PlayerId == DeputyChielfId2 ->
					 db_agent:guild_update_deduct_deputy2(GuildId),
					 2;
				 true ->
					 3
			 end,
  
  %%更新氏族成员列表(GuildTitle, DepartId, DepartName, PlayerId)
  db_agent:update_guild_member_position(GuildMember#ets_guild_member.title, 5, "", PlayerId),
%%   GuildMemberNewList = db_agent:guild_member_select_new(PlayerId),
%%   GuildMemberNew = list_to_tuple([ets_guild_member]++GuildMemberNewList),
  GuildMemberNew = GuildMember#ets_guild_member{guild_position = DefaultPosition,
												guild_depart_id = 5,
												guild_depart_name = "",
												title = GuildMember#ets_guild_member.title},
  update_guild_member(GuildMemberNew),
  MemberType.
  
  
  
  
set_position(PlayerId, PlayerName, GuildId, NewGuildPosition, DeputyChielfId1, DeputyChielfId2) ->
    % 更新角色表
    db_agent:player_update_guild_position(NewGuildPosition, PlayerId, 0),
    % 更新氏族表
    MemberType = case  ((PlayerId == DeputyChielfId1) and (NewGuildPosition /= 2)) of
        true ->
            db_agent:guild_update_deduct_deputy1(GuildId),
            1;
        false when ((PlayerId == DeputyChielfId2) and (NewGuildPosition /= 2)) ->
            db_agent:guild_update_deduct_deputy2(GuildId),
            2;
         % 副族长数增加
        false when ((DeputyChielfId1 == 0) and (NewGuildPosition == 2)) ->
            db_agent:guild_update_add_deputy1(PlayerId, PlayerName, GuildId),
            3;
        false when ((DeputyChielfId2 == 0) and (NewGuildPosition == 2)) ->
            db_agent:guild_update_add_deputy2(PlayerId, PlayerName, GuildId),
            4;
        false ->
            0
    end,
    % 更新缓存
    GuildMember = get_guild_member_by_player_id(PlayerId),
    GuildMemberNew = GuildMember#ets_guild_member{guild_position = NewGuildPosition},
    update_guild_member(GuildMemberNew),
    [ok, MemberType].
%% -----------------------------------------------------------------
%% 添加氏族会员职位变化日志
%% -----------------------------------------------------------------
set_position_log(PlayerName2Bin, PlayerName1Bin, GuildId, GuildName, Type, PositionName) ->
	PlayerName1 = tool:to_list(PlayerName1Bin),
	PlayerName2 = tool:to_list(PlayerName2Bin),
%% 	#ets_guild{name = GuildName,
%% 			   id = GuildId} = Guild,
	CreateTime = util:unixtime(),
	case Type of
		1 ->%%降职
			Content = lists:concat([PlayerName2, ?DEMOTION_ONE, PlayerName1, ?DEMOTION_TWO, PositionName]);
		2 ->%%升职
			Content = lists:concat([PlayerName2, ?PROMOTION_ONE, PlayerName1, ?PROMOTION_TWO, PositionName]);
		3 ->%%直接设为堂主或者弟子
			Content = lists:concat([PlayerName2, ?POSITION_CHANGE_ONE, PlayerName1, ?POSITION_CHANGE_TWO, PositionName])
	end, 
	Log_guild = #ets_log_guild{
					guild_id = GuildId, 
					guild_name = GuildName, 
					time = CreateTime, 
					content	= Content	   
					},
%% 	db_agent:guild_log_insert(Log_guild),
%% 	GuildLog = db_agent:guild_log_select_create(GuildId, GuildName),
%% 	if GuildLog =:= [] ->
%% 		   ?ERROR_MSG("create_guild: guild id is null, name=[~s]", [GuildName]);
%% 	   true ->
%% 		%%   [LogId | _] = GuildLog,
%% 		   GuildLogEts = list_to_tuple([ets_log_guild] ++ GuildLog),
%% 		   lib_guild_inner:update_guild_log(GuildLogEts)
%% 	end,
%% 	?DEBUG("**** set_position_log ok*****",[]).
	case db_agent:guild_log_insert(Log_guild) of
		{mongo, Ret} ->
			GuildLogEts = Log_guild#ets_log_guild{id = Ret},
			lib_guild_inner:update_guild_log(GuildLogEts);
		1 ->
			GuildLog = db_agent:guild_log_select_create(GuildId, GuildName),
			if GuildLog =:= [] ->
				   ?ERROR_MSG("create_guild: guild id is null, name=[~s]", [GuildName]);
			   true ->
				   GuildLogEts = list_to_tuple([ets_log_guild] ++ GuildLog),
				   lib_guild_inner:update_guild_log(GuildLogEts)
			end;
		_Other ->
			noaction
	end.

%%添加成员被踢出氏族的日志
kickout_guild_log(Guild, APlayerName, BPlayerName) ->
	APlayerNameList = tool:to_list(APlayerName),
	BPlayerNameList = tool:to_list(BPlayerName),
	CreateTime = util:unixtime(),
	Content = lists:concat([BPlayerNameList, ?KICKOUT_GUILD_ONE, APlayerNameList, ?KICKOUT_GUILD_TWO]),
	#ets_guild{name = GuildName,
			   id = GuildId} = Guild,
	Log_guild = #ets_log_guild{
					guild_id = GuildId, 
					guild_name = GuildName, 
					time = CreateTime, 
					content	= Content	   
					},
%% 	db_agent:guild_log_insert(Log_guild),
%% 	GuildLog = db_agent:guild_log_select_create(GuildId, GuildName),
%% 	if GuildLog =:= [] ->
%% 		   ?ERROR_MSG("create_guild: guild id is null, name=[~s]", [GuildName]);
%% 	   true ->
%% 		   GuildLogEts = list_to_tuple([ets_log_guild] ++ GuildLog),
%% 		   lib_guild_inner:update_guild_log(GuildLogEts)
%% 	end.
	case db_agent:guild_log_insert(Log_guild) of
		{mongo, Ret} ->
			GuildLogEts = Log_guild#ets_log_guild{id = Ret},
			lib_guild_inner:update_guild_log(GuildLogEts);
		1 ->
			GuildLog = db_agent:guild_log_select_create(GuildId, GuildName),
			if GuildLog =:= [] ->
				   ?ERROR_MSG("create_guild: guild id is null, name=[~s]", [GuildName]);
			   true ->
				   GuildLogEts = list_to_tuple([ets_log_guild] ++ GuildLog),
				   lib_guild_inner:update_guild_log(GuildLogEts)
			end;
		_Other ->
			noaction
	end.


%%设置新的堂主职位
set_depart_position(PlayerId, DepartId, GuildTitle, DepartName) ->
			GuildMemUpdateList = [{guild_depart_name, DepartName}, {guild_depart_id, DepartId}, {title, GuildTitle}],
			PlayerUpdateList = [{guild_depart_name, DepartName}, {guild_depart_id, DepartId}, {guild_title, GuildTitle}],
	db_agent:set_depart_position(GuildMemUpdateList,PlayerUpdateList, PlayerId).

%% -----------------------------------------------------------------
%% 修改氏族堂堂名
%% -----------------------------------------------------------------
modify_guild_depart_name(GuildId, DepartId, DepartName, DepartsNames) ->
	db_agent:modify_guild_depart_name(GuildId, DepartId, DepartName, DepartsNames),
	ok.


	
	
%% -----------------------------------------------------------------
%% 禅让族长
%% -----------------------------------------------------------------
demise_chief(PlayerId1, _PlayerName1,PlayerId2, PlayerName2, GuildId, DeputyChielfId1, DeputyChielfId2) ->
	GuildMember1 = get_guild_member_by_player_id(PlayerId1),
	GuildMember2 = get_guild_member_by_player_id(PlayerId2),
    
	% 更新角色表
    db_agent:player_update_guild_position(12, PlayerId1, 5),
    db_agent:player_update_guild_position(1, PlayerId2, 5),
    % 更新氏族表
    MemberType = case PlayerId2 == DeputyChielfId1 of
        true ->
            db_agent:guild_update_change_deputy1(PlayerId2, PlayerName2, GuildId),
            1;
        false when PlayerId2 == DeputyChielfId2 ->
            db_agent:guild_update_change_deputy2(PlayerId2, PlayerName2, GuildId),
            2;
        false ->
            db_agent:guild_update_change_chief(PlayerId2, PlayerName2, GuildId),
			0
    end,
	
	
%% drr	GuildMember = get_guild_member_by_player_id(PlayerId),
	
	
	%%更新氏族成员列表(GuildTitle, DepartId, DepartName, PlayerId)
	db_agent:update_guild_member_demise_chief(5, PlayerId1),
	% 更新缓存(原来的族长)
%% 	GuildMember1 = db_agent:guild_member_select_new(PlayerId1),
%% 	GuildMemberNew1 = list_to_tuple([ets_guild_member]++GuildMember1),
	GuildMemberNew1 = GuildMember1#ets_guild_member{guild_position = 12,
													guild_depart_id = 5,
													guild_depart_name = ""},
	update_guild_member(GuildMemberNew1),
	
	%%更新氏族成员列表(GuildTitle, DepartId, DepartName, PlayerId)
	db_agent:update_guild_member_demise_chief(5, PlayerId2),
	% 更新缓存(新的族长)
%% 	GuildMember2 = db_agent:guild_member_select_new(PlayerId2),
%% 	GuildMemberNew2 = list_to_tuple([ets_guild_member]++GuildMember2),
	GuildMemberNew2 = GuildMember2#ets_guild_member{guild_position = 1,
													guild_depart_id = 5,
													guild_depart_name = ""},
	update_guild_member(GuildMemberNew2),
%%     % 更新缓存
%%     GuildMember1 = get_guild_member_by_player_id(PlayerId1),
%%     GuildMemberNew1 = GuildMember1#ets_guild_member{guild_position = 12},
%%     update_guild_member(GuildMemberNew1),
%%     GuildMember2 = get_guild_member_by_player_id(PlayerId2),
%%     GuildMemberNew2 = GuildMember2#ets_guild_member{guild_position = 1},
%%     update_guild_member(GuildMemberNew2),
    [ok, MemberType].

%% -----------------------------------------------------------------
%% 添加氏族族长禅让族长之位日志
%% -----------------------------------------------------------------
demise_chief_log(PlayerName1, PlayerName2, Guild) ->
	#ets_guild{name = GuildName,
			   id = GuildId} = Guild,
	CreateTime = util:unixtime(),
	Content = lists:concat([?DEMISE_CHIEF_ONE, PlayerName1,?DEMISE_CHIEF_TWO, PlayerName2]),
	
	Log_guild = #ets_log_guild{
					guild_id = GuildId, 
					guild_name = GuildName, 
					time = CreateTime, 
					content	= Content	   
					},
%% 	db_agent:guild_log_insert(Log_guild),
%% 	GuildLog = db_agent:guild_log_select_create(GuildId, GuildName),
%% 	if GuildLog =:= [] ->
%% 		   ?ERROR_MSG("create_guild: guild id is null, name=[~s]", [GuildName]);
%% 	   true ->
%% 		   GuildLogEts = list_to_tuple([ets_log_guild] ++ GuildLog),
%% 		   lib_guild_inner:update_guild_log(GuildLogEts)
%% 	end.
	case db_agent:guild_log_insert(Log_guild) of
		{mongo, Ret} ->
			GuildLogEts = Log_guild#ets_log_guild{id = Ret},
			lib_guild_inner:update_guild_log(GuildLogEts);
		1 ->
			GuildLog = db_agent:guild_log_select_create(GuildId, GuildName),
			if GuildLog =:= [] ->
				   ?ERROR_MSG("create_guild: guild id is null, name=[~s]", [GuildName]);
			   true ->
				   GuildLogEts = list_to_tuple([ets_log_guild] ++ GuildLog),
				   lib_guild_inner:update_guild_log(GuildLogEts)
			end;
		_Other ->
			noaction
	end.

% -----------------------------------------------------------------
%% 40019 捐献钱币
%% -----------------------------------------------------------------
donate_money(Status, GuildId, Num) ->
	PlayerId = Status#player.id,
%%     ?DEBUG("donate_money: PlayerId=[~p], GuildId=[~p], Num=[~p]", [PlayerId, GuildId, Num]),
    % 更新角色表
%%     db_agent:player_update_deduct_coin(Num, PlayerId),
	NewStatus = lib_goods:cost_money(Status, Num, coin, 4019),
    % 更新氏族表
    db_agent:guild_update_add_funds(Num, GuildId),
    % 更新氏族成员表
    DonateMoneyRatio = data_guild:get_guild_config(donate_money_ratio, []),
    DonateAdd        = Num div DonateMoneyRatio,
	%%更新氏族贡献
    money_add_donation(PlayerId, DonateAdd, Num, GuildId),
	{ok, NewStatus}.
    
%% -----------------------------------------------------------------
%% 添加氏族捐献日志
%% -----------------------------------------------------------------
donate_money_log(PlayerName, Guild, Num) ->
	#ets_guild{name = GuildName,
			   id = GuildId} = Guild,
	CreateTime = util:unixtime(),
	Content = lists:concat([PlayerName, ?DONATE_MONEY_ONE, Num, ?DONATE_MONEY_TWO]),
	Log_guild = #ets_log_guild{
					guild_id = GuildId, 
					guild_name = GuildName, 
					time = CreateTime, 
					content	= Content	   
					},
%% 	db_agent:guild_log_insert(Log_guild),
%% 	GuildLog = db_agent:guild_log_select_create(GuildId, GuildName),
%% 	if GuildLog =:= [] ->
%% 		   ?ERROR_MSG("create_guild: guild id is null, name=[~s]", [GuildName]);
%% 	   true ->
%% 		   GuildLogEts = list_to_tuple([ets_log_guild] ++ GuildLog),
%% 		   lib_guild_inner:update_guild_log(GuildLogEts)
%% 	end.
	case db_agent:guild_log_insert(Log_guild) of
		{mongo, Ret} ->
			GuildLogEts = Log_guild#ets_log_guild{id = Ret},
			lib_guild_inner:update_guild_log(GuildLogEts);
		1 ->
			GuildLog = db_agent:guild_log_select_create(GuildId, GuildName),
			if GuildLog =:= [] ->
				   ?ERROR_MSG("create_guild: guild id is null, name=[~s]", [GuildName]);
			   true ->
				   GuildLogEts = list_to_tuple([ets_log_guild] ++ GuildLog),
				   lib_guild_inner:update_guild_log(GuildLogEts)
			end;
		_Other ->
			noaction
	end.

% -----------------------------------------------------------------
%% 氏族升级,获取氏族剩余技能点
%% -----------------------------------------------------------------
get_guild_skills(GuildId) ->
%%	db_agent:get_guild_skills(GuildId).
	match_one(?ETS_GUILD, #ets_guild{id = GuildId, _ = '_'}).

update_guild_upgrade(GuildId, NewFunds, NewExp, UpGradeTime) ->
	db_agent:update_guild_upgrade(GuildId, NewFunds, NewExp, UpGradeTime).
%升级氏族指定技能属性等级
guild_skills_level_upgrade(GuildId, SkillId, SkillLevelNew) ->
	db_agent:guild_skills_level_upgrade(GuildId, SkillId, SkillLevelNew).
%%更新因为技能等级变化而引起的氏族信息变化
update_guild_by_skills(ValueList, WhereList) ->
	db_agent:update_guild_by_skills(ValueList, WhereList).


%% -----------------------------------------------------------------
%% 捐款资金而增加帮贡
%% -----------------------------------------------------------------
money_add_donation(PlayerId, DonateAdd, Num, GuildId) ->
    % 查询贡献信息
    GuildMember = get_guild_member_by_guildandplayer_id(GuildId, PlayerId),
    if  % 氏族成员不存在
        GuildMember =:= [] ->
            ?ERROR_MSG("add_donation: guild member not find ,id=[~p]", [PlayerId]),
            error;
        true ->
            [DonateTotal, DonateLastTime, DonateTotalLastWeek, DonateTotalLastdDay, DonateFunds] =
                [GuildMember#ets_guild_member.donate_total, GuildMember#ets_guild_member.donate_lasttime, 
				 GuildMember#ets_guild_member.donate_total_lastweek, GuildMember#ets_guild_member.donate_total_lastday, 
				 GuildMember#ets_guild_member.donate_funds],
            DonateTime = util:unixtime(),
            SameDay    = is_same_date(DonateTime, DonateLastTime),
            SameWeek   = is_same_week(DonateTime, DonateLastTime),
            if  % 同一个星期且同一天
               (SameDay == true) ->
                    Data3 = [DonateFunds + Num, DonateTotal+DonateAdd, DonateTime, DonateTotalLastWeek+DonateAdd, DonateTotalLastdDay+DonateAdd, PlayerId],
                    db_agent:guild_member_update_money_donate_info(Data3),
                    % 更新缓存
                    GuildMemberNew = GuildMember#ets_guild_member{donate_funds 			= DonateFunds + Num,
																  donate_total          = DonateTotal+DonateAdd,
                                                                  donate_lasttime       = DonateTime,
                                                                  donate_total_lastweek = DonateTotalLastWeek+DonateAdd,
                                                                  donate_total_lastday  = DonateTotalLastdDay+DonateAdd},
					%%做加入氏族的成就统计
					lib_achieve:check_achieve_finish_cast(PlayerId, 605, [GuildMemberNew#ets_guild_member.donate_total]),
                    update_guild_member(GuildMemberNew);
              % 同一个星期且不同天
              ((SameWeek == true) and (SameDay == false)) ->
                    Data3 = [DonateFunds + Num, DonateTotal+DonateAdd, DonateTime, DonateTotalLastWeek+DonateAdd, DonateAdd, PlayerId],
                    db_agent:guild_member_update_money_donate_info(Data3),
                    % 更新缓存
                    GuildMemberNew = GuildMember#ets_guild_member{donate_funds 			= DonateFunds + Num,
																  donate_total          = DonateTotal+DonateAdd,
                                                                  donate_lasttime       = DonateTime,
                                                                  donate_total_lastweek = DonateTotalLastWeek+DonateAdd,
                                                                  donate_total_lastday  = DonateAdd},
					%%做加入氏族的成就统计
					lib_achieve:check_achieve_finish_cast(PlayerId, 605, [GuildMemberNew#ets_guild_member.donate_total]),
                    update_guild_member(GuildMemberNew);
              % 不同一个星期且不同天
              (SameWeek == false) ->
                    Data3 = [DonateFunds + Num, DonateTotal+DonateAdd, DonateTime, DonateAdd, DonateAdd, PlayerId],
                    db_agent:guild_member_update_money_donate_info(Data3),
                    % 更新缓存
                    GuildMemberNew = GuildMember#ets_guild_member{donate_funds 			= DonateFunds + Num,
																  donate_total          = DonateTotal+DonateAdd,
                                                                  donate_lasttime       = DonateTime,
                                                                  donate_total_lastweek = DonateAdd,
                                                                  donate_total_lastday  = DonateAdd},
					%%做加入氏族的成就统计
					lib_achieve:check_achieve_finish_cast(PlayerId, 605, [GuildMemberNew#ets_guild_member.donate_total]),
                    update_guild_member(GuildMemberNew);
               true ->
                    void
           end
    end,
    ok.

%% -----------------------------------------------------------------
%% 氏族建设卡增加帮贡
%% -----------------------------------------------------------------
add_donation(PlayerId, DonateAdd) ->
    % 查询贡献信息
    GuildMember = get_guild_member_by_player_id(PlayerId),
    if  % 氏族成员不存在
        GuildMember =:= [] ->
            ?ERROR_MSG("add_donation: guild member not find ,id=[~p]", [PlayerId]),
            error;
        true ->
            [DonateTotal, DonateLastTime, DonateTotalLastWeek, DonateTotalLastdDay] =
                [GuildMember#ets_guild_member.donate_total, GuildMember#ets_guild_member.donate_lasttime, 
				 GuildMember#ets_guild_member.donate_total_lastweek, GuildMember#ets_guild_member.donate_total_lastday],
            DonateTime = util:unixtime(),
            SameDay    = is_same_date(DonateTime, DonateLastTime),
            SameWeek   = is_same_week(DonateTime, DonateLastTime),
            if  % 同一个星期且同一天
               (SameDay == true) ->
                    Data3 = [DonateTotal+DonateAdd, DonateTime, DonateTotalLastWeek+DonateAdd, DonateTotalLastdDay+DonateAdd, PlayerId],
                    db_agent:guild_member_update_donate_info(Data3),
                    % 更新缓存
                    GuildMemberNew = GuildMember#ets_guild_member{donate_total          = DonateTotal+DonateAdd,
                                                                  donate_lasttime       = DonateTime,
                                                                  donate_total_lastweek = DonateTotalLastWeek+DonateAdd,
                                                                  donate_total_lastday  = DonateTotalLastdDay+DonateAdd},
					%%做加入氏族的成就统计
					lib_achieve:check_achieve_finish_cast(PlayerId, 605, [GuildMemberNew#ets_guild_member.donate_total]),
                    update_guild_member(GuildMemberNew);
              % 同一个星期且不同天
              ((SameWeek == true) and (SameDay == false)) ->
                    Data3 = [DonateTotal+DonateAdd, DonateTime, DonateTotalLastWeek+DonateAdd, DonateAdd, PlayerId],
                    db_agent:guild_member_update_donate_info(Data3),
                    % 更新缓存
                    GuildMemberNew = GuildMember#ets_guild_member{donate_total          = DonateTotal+DonateAdd,
                                                                  donate_lasttime       = DonateTime,
                                                                  donate_total_lastweek = DonateTotalLastWeek+DonateAdd,
                                                                  donate_total_lastday  = DonateAdd},
					%%做加入氏族的成就统计
					lib_achieve:check_achieve_finish_cast(PlayerId, 605, [GuildMemberNew#ets_guild_member.donate_total]),
                    update_guild_member(GuildMemberNew);
              % 不同一个星期且不同天
              (SameWeek == false) ->
                    Data3 = [DonateTotal+DonateAdd, DonateTime, DonateAdd, DonateAdd, PlayerId],
                    db_agent:guild_member_update_donate_info(Data3),
                    % 更新缓存
                    GuildMemberNew = GuildMember#ets_guild_member{donate_total          = DonateTotal+DonateAdd,
                                                                  donate_lasttime       = DonateTime,
                                                                  donate_total_lastweek = DonateAdd,
                                                                  donate_total_lastday  = DonateAdd},
					%%做加入氏族的成就统计
					lib_achieve:check_achieve_finish_cast(PlayerId, 605, [GuildMemberNew#ets_guild_member.donate_total]),
                    update_guild_member(GuildMemberNew);
               true ->
                    void
           end
    end,
    ok.

%% -----------------------------------------------------------------
%% 获取日福利
%% -----------------------------------------------------------------
get_paid(PlayerId, PaidDaily, NowTime) ->
    % 更新角色表
    db_agent:player_update_add_coin(PaidDaily, PlayerId),
    % 更新氏族成员表
    db_agent:guild_member_update_paid(NowTime, PlayerId),
    ok.


%% -----------------------------------------------------------------
%% 处理返回的氏族技能属性表
%% -----------------------------------------------------------------
get_guild_skills_attribute(GuildId) ->
	get_ets_guild_skills_attribute(GuildId).

handle_guild_skills_info(Record) ->
	#ets_guild_skills_attribute{skill_id = SkillId,
								skill_level = SkillLevel} = Record,
	SkillName = data_guild:get_skills_names(SkillId),
%% 	[Description] = data_guild:get_skill_description(SkillId, SkillLevel),
	%%返回氏族技能升级信息{技能ID，最高等级上限，氏族等级条件A*Level+B{A，B}， 氏族资金}
	[LevelBase, LevelLimit, FundsBase] = data_guild:get_guild_skill_upgrade_info(SkillId),
	case SkillLevel >= LevelLimit of
		true ->%%已经是满级了
			NeedLevel = 0,
			NeedFunds = 0,
			SkillTosNeed = 0;
		false ->
			GoalSkillLevel = SkillLevel + 1,
			{LevelBaseA, LevelBaseB} = LevelBase,
			NeedLevel = GoalSkillLevel * LevelBaseA + LevelBaseB,
			NeedFunds = GoalSkillLevel * FundsBase,
			%%获取下一级所需要的技能令数
%% 			?DEBUG("SkillId:~p, GoalSkillLevel:~p", [SkillId, GoalSkillLevel]),
			case SkillId >= 4 andalso SkillId =< 10 of
				true ->%%高级技能，需要查找下一级所需要的技能令数
					{_HSKillAdd, _Funds, SkillTosNeed} = data_guild:get_guild_h_skill_base(SkillId, GoalSkillLevel);
				false ->
					SkillTosNeed = 1
			end
	end,
%% 	NeedTokens = 1,
	{SkillNameLen, SkillNameBinary} = string_to_binary_and_len(SkillName),
	%%氏族描述
%% 	{DescriptionLen, DescriptionBin} = string_to_binary_and_len(Description),
	<<SkillId:32, SkillNameLen:16, SkillNameBinary/binary, SkillLevel:32,
	  NeedLevel:32, NeedFunds:32, SkillTosNeed:16>>.


%%=========================================================================
%% 邮件服务
%%=========================================================================
send_mail(SubjectType, Param) ->
    [NameListNew, TitleNew, ContentNew, GoodsTypeId, GoodsNum, GoodsBind] =
		case SubjectType of
			guild_disband ->
				[_GuildId, GuildName, MemberNameList] = Param,
				NameList  = MemberNameList,
				Title     = "氏族已解散",
				Content   = io_lib:format("你所属的氏族【~s】已经解散了。", [GuildName]),
				[NameList, Title, Content, 0, 0, 1];
			guild_reject_apply ->
				[_PlayerId, PlayerName, _GuildId, GuildName] = Param,
				NameList = [PlayerName],
				Title    = "氏族申请被拒绝",
				Content  = io_lib:format("氏族【~s】拒绝了你的加入申请。", [GuildName]),
				[NameList, Title, Content, 0, 0, 1];
			guild_new_member ->
				[_PlayerId, PlayerName, _GuildId, GuildName] = Param,
				NameList = [PlayerName],
				Title    = "成功加入氏族",
				Content  = io_lib:format("恭喜你成功加入了氏族【~s】。", [GuildName]),
				[NameList, Title, Content, 0, 0, 1];
			guild_invite_join ->
				[PlayerName, APlayerName, GuildName] = Param,
				NameList = [PlayerName],
				Title   = "氏族邀请",
				Content = io_lib:format("【~s】邀请您加入氏族【~s】。", [APlayerName, GuildName]),
				[NameList, Title, Content, 0, 0, 1];
			guild_reject_invite ->
				[APlayerName, _PlayerId, PlayerName, _GuildId, _GuildName] = Param,
				NameList = [APlayerName],
				Title    = "氏族邀请被拒绝",
				Content  = io_lib:format("【~s】拒绝了你的 氏族加入邀请。", [PlayerName]),
				[NameList, Title, Content, 0, 0, 1];
			guild_demise_chief ->
				[PlayerName, ChiefName, NewChiefName, _GuildName] = Param,
				NameList = [PlayerName],
				Title = "族长让贤",
				Content = io_lib:format("【~s】将族长之位让于【~s】", [ChiefName, NewChiefName]),
				[NameList, Title, Content, 0, 0, 1];
			guild_accuse_chief ->
				[PlayerName, NewChiefName, _OldChiefName, GuildName] = Param,
				NameList = [PlayerName],
				Title = "弹劾状",
				Content = io_lib:format("【~s】利用弹劾令成功弹劾3天未上线的族长，并成为【~s】氏族的新任族长", [NewChiefName, GuildName]),
				[NameList, Title, Content, 0, 0, 1];
			guild_kickout ->
				[_PlayerId, PlayerName, _GuildId, GuildName] = Param,
				NameList = [PlayerName],
				Title   = "你被踢出氏族",
				Content = io_lib:format("你被踢出了氏族【~s】。", [GuildName]),
				[NameList, Title, Content, 0, 0, 1];
			guild_upgrade -> 
				[PlayerName, GuildName, NewLevel] = Param,
				NameList = [PlayerName],
				Title = "氏族升级",
				Content = io_lib:format("恭喜，你所属的氏族【~s】等级升级为~p", [GuildName, NewLevel]),
				[NameList, Title, Content, 0, 0, 1];
			guild_skill_upgrade ->
				[PlayerName, GuildName, SkillName, NewLevel] = Param,
				NameList = [PlayerName],
				Title = "氏族技能升级",
				Content = io_lib:format("恭喜，你所属的氏族【~s】的【~s】等级升级为~p",[GuildName, SkillName, NewLevel]),
				[NameList, Title, Content, 0, 0, 1];
			guild_set_position ->
				[PlayerName, APlayerName, PositionName] = Param,
				NameList = [PlayerName],
				Title = "职位通告",
				Content = io_lib:format("您好，【~s】把你职位变更为：【~s】", [APlayerName, PositionName]),
				[NameList, Title, Content, 0, 0, 1];
			apply_skyrush_succeed ->
				[PlayerName, Date, SHour, SMine, EHour, EMine] = Param,
				NameList = [PlayerName],
				Title = "神岛公告",
				case SMine >= 0 andalso SMine =< 9 of
					true ->
						SMine0 = "0";
					false ->
						SMine0 = ""
				end,
				case EMine >= 0 andalso EMine =< 9 of
					true ->
						EMine0 = "0";
					false ->
						EMine0 = ""
				end,
				[Month, Day] = lib_skyrush:get_mail_date(Date),
				Content = io_lib:format("你所在的氏族已经成功报名~p月~p日晚上的神岛空战，请于当天的~p:~s~p-~p:~s~p准时参加", [Month, Day, SHour, SMine0, SMine, EHour, EMine0, EMine]),
				[NameList, Title, Content, 0, 0, 1];
			apply_castle_rush_succeed ->
				[PlayerName, Date] = Param,
				NameList = [PlayerName],
				Title = "九霄攻城战公告",
				[Month, Day] = lib_castle_rush:get_mail_date(Date),
				Content = io_lib:format("你所在的氏族已经成功报名~p月~p日晚上的九霄攻城战，请于当天的20:35-20:55准时参加", [Month, Day]),
				[NameList, Title, Content, 0, 0, 1];
			agree_guild_union ->
				[Type, GuildName, PlayerName] = Param,
				NameList = [PlayerName],
				Title = "联盟公告",
				case Type of
					1 ->
						Content = io_lib:format("氏族【~s】同意了你的 兼并 申请,请尽快处理。★敬告★：即日起，若结盟/归附成功，归附方氏族的氏族仓库里的所有物品将会被毫无保留的清理，敬请提前取出！", [GuildName]);
					2 ->
						Content = io_lib:format("氏族【~s】同意了你的 归附 申请,请尽快处理。★敬告★：即日起，若结盟/归附成功，归附方氏族的氏族仓库里的所有物品将会被毫无保留的清理，敬请提前取出！", [GuildName])
				end,
				[NameList, Title, Content, 0, 0, 1];
			refuse_guild_union ->
				[Type, GuildName, PlayerName] = Param,
				NameList = [PlayerName],
				Title = "联盟公告",
				case Type of
					1 ->
						Content = io_lib:format("氏族【~s】拒绝了你的 兼并 申请.", [GuildName]);
					2 ->
						Content = io_lib:format("氏族【~s】拒绝了你的 归附 申请.", [GuildName])
				end,
				[NameList, Title, Content, 0, 0, 1];
			chose_union_member ->
				[GuildName, PlayerName] = Param,
				NameList = [PlayerName],
				Title = "联盟公告",
				Content = io_lib:format("氏族【~s】提交了加入名单,请尽快处理.", [GuildName]),
				[NameList, Title, Content, 0, 0, 1];
			refuse_chose_member ->
				[GuildName, PlayerName] = Param,
				NameList = [PlayerName],
				Title = "联盟公告",
				Content = io_lib:format("氏族【~s】对您提出的加入名单表示不满,拒绝了您的请求.", [GuildName]),
				[NameList, Title, Content, 0, 0, 1];
			union_succeed_chief ->
				[GuildName,PlayerName] = Param,
				NameList  = [PlayerName],
				Title     = "联盟公告",
				Content   = io_lib:format("可喜可贺，你所在的氏族与氏族【~s】通过缔结盟约正式结盟成功", [GuildName]),
				[NameList, Title, Content, 28023, 8, 0];%%发8张绑定的绑定铜币卡
			union_succeed_chose ->
				[GuildName, NameList] = Param,
				NameList  = NameList,
				Title     = "联盟公告",
				Content   = io_lib:format("您所在的氏族与氏族【~s】合并成功！您的能力得到了新族长的认同，希望您在新的氏族里有更好的发展！", [GuildName]),
				[NameList, Title, Content, 0, 0, 1];
			union_succeed_unchose ->
				[GuildName, NameList] = Param,
				NameList  = NameList,
				Title     = "联盟公告",
				Content   = io_lib:format("您所在的氏族与氏族【~s】合并。很遗憾，您并没有得到新族长的青睐。请不要灰心，游戏里您会找到合适自己的氏族！", [GuildName]),
				[NameList, Title, Content, 0, 0, 1];
			union_timeout ->
				[GuildName, Type, PlayerName] = Param,
				NameList = [PlayerName],
				Title = "联盟公告",
				case Type of
					1 ->
						Content = io_lib:format("您所在的氏族对氏族【~s】发起的 兼并 请求，由于已经超过时限，目前此操作作废，敬请重新申请.", [GuildName]);
					2 ->
						Content = io_lib:format("您所在的氏族对氏族【~s】发起的 归附 请求，由于已经超过时限，目前此操作作废，敬请重新申请.", [GuildName]);
					3 ->
						Content = io_lib:format("您所在的氏族与氏族【~s】进行的 结盟 日程，由于已经超过时限，目前此操作作废，敬请重新申请.", [GuildName])
				end,
				[NameList, Title, Content, 0, 0, 1]
		end,
	mod_mail:send_sys_mail(NameListNew, TitleNew, ContentNew, 0, GoodsTypeId, GoodsNum, 0, 0, GoodsBind).

get_member_name_list(GuildId, PlayerId) ->
    MemberList = get_guild_member_by_guild_id(GuildId),
	case MemberList of
		[] ->
			NewMemberList = [];
		_ ->
			NewMemberList = lists:keydelete(PlayerId, #ets_guild_member.player_id, MemberList)
	end,
    get_member_name_list_helper(NewMemberList, []).
get_member_name_list_helper([], NameList) ->
    NameList;
get_member_name_list_helper(MemberList, NameList) ->
    [Member|MemberLeft] = MemberList,
    get_member_name_list_helper(MemberLeft, NameList++[Member#ets_guild_member.player_name]).

get_official_name_list(GuildId, Position) ->
    % 更新氏族成员表
    GuildMembers = get_guild_official(GuildId, Position),
    get_official_name_list_helper(GuildMembers, []).

get_official_name_list_helper([], NameListNew) ->
    NameListNew;
get_official_name_list_helper(GuildMembers, NameListNew) ->
    [GuildMember|GuildMemberLeft] = GuildMembers,
    get_official_name_list_helper(GuildMemberLeft, NameListNew++[GuildMember#ets_guild_member.player_name]).

%%=========================================================================
%% 定时服务
%%=========================================================================
   
%% -----------------------------------------------------------------
%% 收取日建设
%% -----------------------------------------------------------------
handle_daily_consume() ->
    Guilds = get_guild_all(),
    lists:map(fun handle_daily_consume/1, Guilds).

handle_daily_consume(Guild) ->
	NowTime = util:unixtime(),
	#ets_guild{id = GuildId,
			   level = GuildLevel,
			   funds = Funds,
			   consume_get_nexttime = LastGetTime} = Guild,
	Diff = NowTime - LastGetTime,
	%%是否到时间了 
	case Diff >= 0 of
		false ->
			nothing_todo;
		true ->
			if GuildLevel > 0 andalso GuildLevel =< 10 ->%%判断等级是否有效
				   NextConsumeTime = NowTime + ?ONE_DAY_SECONDS,
				   [_, ConsumeFunds] = data_guild:get_guild_funds_consume(GuildLevel),
				   NewFunds = Funds - ConsumeFunds,
				   Data = [GuildId, NextConsumeTime, ConsumeFunds],
				   db_agent:guild_update_init(Data),
				   GuildNew = Guild#ets_guild{consume_get_nexttime = NextConsumeTime,
											  funds = NewFunds},
				   update_guild(GuildNew);
			   true ->%%等级出错了
				   no_action
			end
	end.
%%做氏族升级处理
handle_guild_upgrade_record() ->
	NowTime = util:unixtime(),
	case get_guild_upgrade_from_ets(NowTime) of
		[] ->
			no_action;
		GuildUpgradeList ->
			lists:foreach(fun upgrade_guild_info/1, GuildUpgradeList)
	end.
upgrade_guild_info(GuildUpgrade) ->
	#ets_guild_upgrade_status{guild_id = GuildId,
							  guild_name = GuildName} = GuildUpgrade,
	case get_guild(GuildId) of
		[] ->
			delete_ets_guild_upgrade(GuildId),
			no_action;
		Guild ->
			#ets_guild{skills = Skills,
					   level = Level} = Guild,
			NewLevel = Level +1,
			NewSkills = Skills + 2,
			ValueList = [{skills, NewSkills}, {upgrade_last_time, 0}, {level, NewLevel}],
			delete_ets_guild_upgrade(GuildId),
			db_agent:update_guild_table(ValueList, GuildId),
			NewGuild = Guild#ets_guild{skills = NewSkills,
									   upgrade_last_time = 0,
									   level = NewLevel},
			update_guild(NewGuild),
			send_guild(0, 0, GuildId, guild_upgrade, [GuildId, GuildName, Level, NewLevel]),
			%%更新联盟申请表的数据
			lib_guild_union:update_guild_info(upgrade, {GuildId,NewLevel})
%% 			%向整个氏族成员发送信件(暂时不用了)
%% 			lib_guild:send_mail_guild_everyone(0, 0, GuildId, guild_upgrade, [GuildName, Level+1])
	end.
	
	
%% -----------------------------------------------------------------
%% 清理过期的氏族日志（三天前）
%% -----------------------------------------------------------------
handle_delete_guild_logs() ->
	delete_extra_log_guild().


%%=========================================================================
%% 辅助函数
%%=========================================================================

%% -----------------------------------------------------------------
%% 发送消息给氏族所有成员(仅用于聊天)
%% -----------------------------------------------------------------
send_guild(Type, PlayerId, GuildId, Data) ->
	case get_guild_member_by_guild_id(GuildId) of
		[] ->
			no_action;
		MemberList ->
			case Type of
				0 ->
					GuildMembers = MemberList;
				1 ->
					GuildMembers = lists:keydelete(PlayerId, #ets_guild_member.player_id, MemberList)
			end,			
			F = fun(Mem) ->
						lib_send:send_to_uid(Mem#ets_guild_member.player_id, Data)
				end,
			[F(Member) || Member <- GuildMembers]
	end.
%% -----------------------------------------------------------------
%% 发送消息给氏族所有成员，此处用于广播帮派事务
%% -----------------------------------------------------------------
send_guild(Type, PlayerId, GuildId, MsgType, Data) ->
	case get_guild_member_by_guild_id(GuildId) of
		[] ->
			no_action;
		MemberList ->
			case Type of
				0 ->
			GuildMembers = MemberList;
				1 ->
					GuildMembers = lists:keydelete(PlayerId, #ets_guild_member.player_id, MemberList)
			end,
			F = fun(Mem) -> 
						send_msg_to_player(Mem#ets_guild_member.player_id, MsgType, Data)
				end,
			[F(Member) || Member <- GuildMembers]
	end.


%% 发送消息给成员
send_msg_to_player(Id, MsgType, Data) ->
	case lib_player:get_player_pid(Id) of
		[] -> [];	
		Pid -> gen_server:cast(Pid, {'GUILD_SET_AND_SEND', MsgType, Data})
	end.

%% -----------------------------------------------------------------
%% 发送邮件给成员
%% -----------------------------------------------------------------
%% %%%%族长让位, 氏族技能升级，群发邮件
send_mail_guild_everyone_inner(Type, PlayerId, GuildId, SubjectType, BaseParam) ->
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
			lists:foreach(fun(Member) ->
								  Param = [Member#ets_guild_member.player_name | BaseParam],
								  send_mail(SubjectType, Param)
%% 								  lib_guild:send_guild_mail(SubjectType, Param)
						  end, NewGuildMembers)
	end.


%% -----------------------------------------------------------------
%% 根据1970年以来的秒数获得日期
%% -----------------------------------------------------------------
seconds_to_localtime(Seconds) ->
    DateTime = calendar:gregorian_seconds_to_datetime(Seconds+?DIFF_SECONDS_0000_1900),
    calendar:universal_time_to_local_time(DateTime).

%% -----------------------------------------------------------------
%% 根据日期获得1970年以来的秒数(测试用)
%% -----------------------------------------------------------------
%localtime_to_seconds({Data, Time}) ->
%    DateTime = calendar:local_time_to_universal_time({Data, Time}),
%    calendar:datetime_to_gregorian_seconds(DateTime)-?DIFF_SECONDS_0000_1900.

%% -----------------------------------------------------------------
%% 判断是否同一天
%% -----------------------------------------------------------------
is_same_date(Seconds1, Seconds2) ->
    {{Year1, Month1, Day1}, _Time1} = seconds_to_localtime(Seconds1),
    {{Year2, Month2, Day2}, _Time2} = seconds_to_localtime(Seconds2),
    if ((Year1 /= Year2) or (Month1 /= Month2) or (Day1 /= Day2)) -> false;
        true -> true
    end.

%% -----------------------------------------------------------------
%% 判断是否同一星期
%% -----------------------------------------------------------------
is_same_week(Seconds1, Seconds2) ->
    {{Year1, Month1, Day1}, Time1} = seconds_to_localtime(Seconds1),
    % 星期几
    Week1  = calendar:day_of_the_week(Year1, Month1, Day1),
    % 从午夜到现在的秒数
    Diff1  = calendar:time_to_seconds(Time1),
    Monday = Seconds1 - Diff1 - (Week1-1)*?ONE_DAY_SECONDS,
    Sunday = Seconds1 + (?ONE_DAY_SECONDS-Diff1) + (7-Week1)*?ONE_DAY_SECONDS,
    if ((Seconds2 >= Monday) and (Seconds2 < Sunday)) -> true;
        true -> false
    end.

%% -----------------------------------------------------------------
%% 获取当天0点和第二天0点
%% -----------------------------------------------------------------
get_midnight_seconds(Seconds) ->
    {{_Year, _Month, _Day}, Time} = seconds_to_localtime(Seconds),
    % 从午夜到现在的秒数
    Diff   = calendar:time_to_seconds(Time),
    % 获取当天0点
    Today  = Seconds - Diff,
    % 获取第二天0点
    NextDay = Seconds + (?ONE_DAY_SECONDS-Diff),
    {Today, NextDay}.

%% -----------------------------------------------------------------
%% 计算相差的天数
%% -----------------------------------------------------------------
get_diff_days(Seconds1, Seconds2) ->
    {{Year1, Month1, Day1}, _} = seconds_to_localtime(Seconds1),
    {{Year2, Month2, Day2}, _} = seconds_to_localtime(Seconds2),
    Days1 = calendar:date_to_gregorian_days(Year1, Month1, Day1),
    Days2 = calendar:date_to_gregorian_days(Year2, Month2, Day2),
    DiffDays=abs(Days2-Days1),
    DiffDays+1.

%% -----------------------------------------------------------------
%% 计算分页（起始位置为0）
%% -----------------------------------------------------------------
calc_page(RecordTotal, PageSize, PageNo) ->
    PageTotal = (RecordTotal+PageSize-1) div PageSize,
    StartPos  = (PageNo - 1) * PageSize,
    if
        % 无效页码
        ((PageNo > PageTotal) or (PageNo < 1)) ->
            {PageTotal, 0, 0};
        true ->
            if
                PageNo*PageSize > RecordTotal ->
                    {PageTotal, StartPos, RecordTotal-(PageNo-1) * PageSize};
                true ->
                    {PageTotal, StartPos, PageSize}
            end
    end.


%%=========================================================================
%% 缓存操作函数
%%=========================================================================

%% -----------------------------------------------------------------
%% 通用函数
%% -----------------------------------------------------------------
lookup_one(Table, Key) ->
	case ets:lookup(Table, Key) of
		[] ->
			[];
		[Record | _] ->
			Record
	end.

lookup_all(Table, Key) ->
    ets:lookup(Table, Key).

match_one(Table, Pattern) ->
	case ets:match_object(Table, Pattern) of
		[] ->
			[];
		[Record | _] ->
			Record
	end.

match_all(Table, Pattern) ->
    ets:match_object(Table, Pattern).

%% -----------------------------------------------------------------
%% 背包里的物品
%% -----------------------------------------------------------------
get_goods(BaseGoodsId, PlayerId) ->
     match_one(?ETS_GOODS_ONLINE, #goods{player_id = PlayerId, goods_id=BaseGoodsId,  _='_'}).

%% -----------------------------------------------------------------
%% 物品类型(获取背包中是否存在建帮令)
%% -----------------------------------------------------------------
get_goods_type(GoodsId) ->
    lookup_one(?ETS_BASE_GOODS,GoodsId).

%% -----------------------------------------------------------------
%% 氏族
%% -----------------------------------------------------------------
get_guild(GuildId) ->
    lookup_one(?ETS_GUILD, GuildId).

get_guild_all() ->
    match_all(?ETS_GUILD, #ets_guild{_='_'}).
get_guilds_by_realm(Realm) ->
	match_all(?ETS_GUILD, #ets_guild{realm =Realm, _ = '_'}).

get_guild_by_name(GuildName) ->
    match_one(?ETS_GUILD, #ets_guild{name=GuildName, _='_'}).

get_guild_lev_by_id(GuildId) ->
    Guild = lookup_one(?ETS_GUILD, GuildId),
    case  Guild =/= [] of
        true  -> Guild#ets_guild.level;
        false -> null
    end.

update_guild(Guild) ->
    ets:insert(?ETS_GUILD, Guild).

delete_guild(GuildId) ->
    ets:delete(?ETS_GUILD, GuildId).
%%更新氏族日志
update_guild_log(GuildLog) ->
	ets:insert(?ETS_LOG_GUILD, GuildLog).

%% -----------------------------------------------------------------
%% 氏族成员
%% -----------------------------------------------------------------
get_guild_member(MemberId) ->
    lookup_one(?ETS_GUILD_MEMBER, MemberId).

get_guild_official(GuildId, Position) ->
	MG = ets:fun2ms(fun(G) when G#ets_guild_member.guild_position == Position 
								andalso G#ets_guild_member.guild_id == GuildId ->
							[G]
					end),
	ets:select(?ETS_GUILD_MEMBER, MG).

get_guild_member_by_player_id(PlayerId) ->
    match_one(?ETS_GUILD_MEMBER, #ets_guild_member{player_id=PlayerId, _='_'}).

get_guild_member_by_guild_id(GuildId) ->
	MS = ets:fun2ms(fun(T) when T#ets_guild_member.guild_id == GuildId ->
							T
					end),
	ets:select(?ETS_GUILD_MEMBER, MS).

get_union_guild_member(GuildId) ->
	MS = ets:fun2ms(fun(T) when T#ets_guild_member.guild_id == GuildId andalso T#ets_guild_member.unions =/= 0 ->
							T
					end),
	ets:select(?ETS_GUILD_MEMBER, MS).
get_guild_member_by_guildandplayer_id(GuildId, PlayerId) ->
	match_one(?ETS_GUILD_MEMBER, #ets_guild_member{player_id = PlayerId, guild_id = GuildId, _='_'}).

get_guild_member_by_guildid_and_departid(GuildId, DepartId) ->
	MG = ets:fun2ms(fun(G) when G#ets_guild_member.guild_depart_id == DepartId 
								andalso G#ets_guild_member.guild_id == GuildId ->
							G
					end),
	ets:select(?ETS_GUILD_MEMBER, MG).

update_guild_member(GuildMember) ->
    ets:insert(?ETS_GUILD_MEMBER, GuildMember).

delete_guild_member(MemberId) ->
    ets:delete(?ETS_GUILD_MEMBER, MemberId).

delete_guild_member_by_guild_id(GuildId) ->
    ets:match_delete(?ETS_GUILD_MEMBER, #ets_guild_member{guild_id=GuildId, _='_'}).

delete_guild_member_by_player_id(PlayerId) ->
    ets:match_delete(?ETS_GUILD_MEMBER, #ets_guild_member{player_id=PlayerId, _='_'}).

%% -----------------------------------------------------------------
%%氏族升级记录的ets相关操作
%% -----------------------------------------------------------------
insert_into_ets_guild_upgrade(UpGradeList) ->
	ets:insert(?ETS_GUILD_UPGRADE_STATUS, UpGradeList).
delete_ets_guild_upgrade(GuildId) ->
	ets:delete(?ETS_GUILD_UPGRADE_STATUS, GuildId).
get_guild_upgrade_from_ets(NowTime) ->
	MG = ets:fun2ms(fun(T) when T#ets_guild_upgrade_status.upgrade_succeed_time =< NowTime ->
							T
					end),
	ets:select(?ETS_GUILD_UPGRADE_STATUS, MG).
get_guild_upgrade_record(GuildId) ->
	ets:lookup(?ETS_GUILD_UPGRADE_STATUS, GuildId).

%% -----------------------------------------------------------------
%%获取氏族技能表信息
%% -----------------------------------------------------------------
get_ets_guild_skills_attribute(GuildId) ->
	MG = ets:fun2ms(fun(G) when G#ets_guild_skills_attribute.guild_id == GuildId 
						 andalso G#ets_guild_skills_attribute.skill_id >= 1 
						 andalso G#ets_guild_skills_attribute.skill_id =< 3 ->
							G
					end),
	ets:select(?ETS_GUILD_SKILLS_ATTRIBUTE, MG).

get_ets_guild_skill_attribute_one(GuildId, SkillId) ->
	MG = ets:fun2ms(fun(G) when G#ets_guild_skills_attribute.guild_id == GuildId
						 andalso G#ets_guild_skills_attribute.skill_id == SkillId
						   ->
							G
					end),
	ets:select(?ETS_GUILD_SKILLS_ATTRIBUTE, MG).

update_guild_skill_attribute(SkillAttribute) ->
	ets:insert(?ETS_GUILD_SKILLS_ATTRIBUTE, SkillAttribute).
ets_delete_guild_skills_attribute(GuildId) ->
	ets:match_delete(?ETS_GUILD_SKILLS_ATTRIBUTE, #ets_guild_skills_attribute{guild_id=GuildId, _='_'}).


%% -----------------------------------------------------------------
%% 氏族申请
%% -----------------------------------------------------------------
get_guild_apply_by_player_id(PlayerId, GuildId) ->
    match_one(?ETS_GUILD_APPLY, #ets_guild_apply{player_id=PlayerId, guild_id=GuildId, _='_'}).

get_guild_apply_by_player_id(PlayerId) ->
    match_all(?ETS_GUILD_APPLY, #ets_guild_apply{player_id=PlayerId, _='_'}).

get_guild_apply_by_guild_id(GuildId) ->
    match_all(?ETS_GUILD_APPLY, #ets_guild_apply{guild_id=GuildId, _='_'}).

update_guild_apply(GuildApply) ->
    ets:insert(?ETS_GUILD_APPLY, GuildApply).

delete_guild_apply_by_player_id(PlayerId) ->
    ets:match_delete(?ETS_GUILD_APPLY, #ets_guild_apply{player_id=PlayerId, _='_'}).

delete_guild_apply_by_player_id(PlayerId, GuildId) ->
    ets:match_delete(?ETS_GUILD_APPLY, #ets_guild_apply{player_id=PlayerId, guild_id=GuildId, _='_'}).

delete_guild_apply_by_guild_id(GuildId) ->
    ets:match_delete(?ETS_GUILD_APPLY, #ets_guild_apply{guild_id=GuildId, _='_'}).

get_guild_apply_num(GuildId) ->
	MatchSpec = ets:fun2ms(fun(Match) when Match#ets_guild_apply.guild_id == GuildId ->
									  true
						   end),
	ets:select_count(?ETS_GUILD_APPLY, MatchSpec).

%% -----------------------------------------------------------------
%% 氏族邀请
%% -----------------------------------------------------------------
get_guild_invite_by_player_id(PlayerId, GuildId) ->
    match_one(?ETS_GUILD_INVITE, #ets_guild_invite{guild_id=GuildId, player_id=PlayerId, _='_'}).

get_guild_invite_by_player_id(PlayerId) ->
    match_all(?ETS_GUILD_INVITE, #ets_guild_invite{player_id=PlayerId, _='_'}).

get_guild_invite_by_guild_id(GuildId) ->
    match_all(?ETS_GUILD_INVITE, #ets_guild_invite{guild_id=GuildId, _='_'}).

update_guild_invite(GuildInvite) ->
    ets:insert(?ETS_GUILD_INVITE, GuildInvite).

delete_guild_invite_by_player_id(PlayerId) ->
    ets:match_delete(?ETS_GUILD_INVITE, #ets_guild_invite{player_id=PlayerId, _='_'}).

delete_guild_invite_by_player_id(PlayerId, GuildId) ->
    ets:match_delete(?ETS_GUILD_INVITE, #ets_guild_invite{player_id=PlayerId, guild_id=GuildId, _='_'}).

delete_guild_invite_by_guild_id(GuildId) ->
    ets:match_delete(?ETS_GUILD_INVITE, #ets_guild_invite{guild_id=GuildId, _='_'}).



%% -----------------------------------------------------------------
%% 处理好友列表
%% -----------------------------------------------------------------
get_ets_rela_record(PlayerId, Type) ->
	MS = ets:fun2ms(fun(T) when T#ets_rela.pid ==PlayerId 
						 andalso T#ets_rela.rela == Type ->
							T
					end),
	ets:select(?ETS_RELA, MS).
	
%%=========================================================================
%% 数据库操作函数
%%=========================================================================
get_player_guild_info(PlayerId) ->
    db_agent:get_player_guild_info(PlayerId).

get_player_guild_info_by_name(PlayerNickname) ->
    db_agent:get_player_guild_info_by_name(PlayerNickname).

%%=========================================================================
%% 对氏族日志ets表进行更新删除
%%=========================================================================
delete_extra_log_guild() ->
	Time = util:unixtime() - 86400,
	MS = ets:fun2ms(fun(T) when T#ets_log_guild.time < Time ->
							T 
									end),
	Lists = ets:select(?ETS_LOG_GUILD, MS),
	case Lists =:= [] of
		true -> 
			nothing_todo;
		false -> 
			lists:foreach(fun(Elem) -> ets:match_delete(?ETS_LOG_GUILD, Elem) end, Lists),
			db_agent:delete_guild_logs(Time)
	end,
	ok.

%% -----------------------------------------------------------------
%% 获取氏族日志
%% -----------------------------------------------------------------
get_log_guild(GuildId) ->
	MS = ets:fun2ms(fun(T) when T#ets_log_guild.guild_id == GuildId ->
							{T#ets_log_guild.time, T#ets_log_guild.content}
						end),
	Data = ets:select(?ETS_LOG_GUILD, MS),
	if  Data =:= [] -> 
			Len = 0,
			[Len,<<>>];
		true ->
			LenInit = length(Data),
			case LenInit =< 30 of
				true ->
					DataSorted = lists:sort(fun sort_logs_by_time/2,
														Data),
					BinData = lists:map(fun(X) -> {Time, Content} = X,
												  {ContentLen, ContentBin} = string_to_binary_and_len(Content),
												  <<Time:32, ContentLen:16, ContentBin/binary>>
										end, DataSorted),
					[LenInit,list_to_binary(BinData)];
				false ->
					DataSorted = lists:sort(fun sort_logs_by_time/2,
														Data),
					DataList = lists:sublist(DataSorted, 1, 30),
					BinData = lists:map(fun(Y) -> {Time, Content} = Y,
												  {ContentLen, ContentBin} = string_to_binary_and_len(Content),
												  <<Time:32, ContentLen:16, ContentBin/binary>>
										end, DataList),
					[30, list_to_binary(BinData)]
			end
	end.

sort_logs_by_time(LogRecord1,LogRecord2) ->
	{Time1, _Content1} = LogRecord1,
	{Time2, _Content2} = LogRecord2,
	Time1 >= Time2.

%% -----------------------------------------------------------------
%%氏族福利，氏族成员战斗结束后，可额外获得原经验的2%*k
%% -----------------------------------------------------------------
get_guild_battle_exp(GuildId, ExpBase) ->
	Guild = lib_guild_inner:get_guild(GuildId),
	if Guild =:= [] ->%%系统错误，忽略
		   ExpBase;
	   true ->%%氏族福利，氏族成员战斗结束后，可额外获得原经验的2%*k
		   GuildSkillAttrData = lib_guild_inner:get_ets_guild_skill_attribute_one(GuildId, 2),
		   case GuildSkillAttrData of
			   [] ->
				   ExpBase;
			   [GuildSkillAttr] ->
				   SkillLevel = GuildSkillAttr#ets_guild_skills_attribute.skill_level,
				   BaseExp = data_guild:get_guild_config(guild_skill_exp_base, []),
				   ExpBase * (1 + BaseExp * SkillLevel)
		   end
	end.

string_to_binary_and_len(Str) ->
	StrBin = tool:to_binary(Str),
	Len = byte_size(StrBin),
	{Len, StrBin}.

%%由氏族id获取氏族名字
lib_get_guild_name(GuildId) ->
	case lib_guild_inner:get_guild(GuildId) of
		[] ->
			"";
		Guild ->
			Guild#ets_guild.name
	end.

get_guild_friend(GuildId, PlayerId) ->
	case GuildId =:= 0 of
		true ->
			[];
		false ->
			% 获取总记录数
			GuildMembers = get_guild_member_by_guild_id(GuildId),
			make_guild_friend_r(GuildMembers,PlayerId)
	end.
make_guild_friend_r(GuildMembers,PlayerId) ->
	lists:foldl(fun(Elem,AccIn) ->
					  #ets_guild_member{player_id = MemId,
										sex = Sex,
										career = Career,
										lv = Level,
										player_name = MemName} = Elem,
					  case MemId =:= PlayerId of
						  true ->
							  AccIn;
						  false ->
							  [{MemId,Sex,Career,Level,MemName}|AccIn]
					  end
				end, [], GuildMembers).
get_member_donate(PlayerId) ->
	case get_guild_member_by_player_id(PlayerId) of
		[] ->
			0;
		Member ->
			Member#ets_guild_member.donate_total
	end.


%%氏族改名
change_guildname(GuildId,GuildName) ->
	GuildInfo = lib_guild_inner:get_guild(GuildId),
	if 
		GuildInfo == [] orelse GuildInfo#ets_guild.name == GuildName ->
			error;
		true ->
			NewGuildInfo = GuildInfo#ets_guild{name = GuildName},			
			load_guild_into_ets(NewGuildInfo),
			db_agent:change_guildname(GuildId,GuildName),
			GuildMembers = lib_guild_inner:get_guild_member_by_guild_id(GuildId),
			case GuildMembers of
				[] ->
					skip;
				_ ->
					F = fun(GuildMember) ->
								NewGuildMember = GuildMember#ets_guild_member{guild_name = GuildName},
								load_guild_member_into_ets(NewGuildMember),
								%%更新fst_god中霸主的帮派信息
								PlayerId = GuildMember#ets_guild_member.player_id,
								db_agent:change_fst_guildname(PlayerId,GuildName),
								%%更新td_single中霸主的帮派信息
								db_agent:change_td_single_guildname(PlayerId,GuildName),
								%%更新玩家帮派信息
								case lib_player:get_player_pid(PlayerId) of
										[] -> [];	
										Pid -> gen_server:cast(Pid, {'SET_GUILD_NAME', GuildName})
									end							
						end,
					[F(GuildMember) || GuildMember <- GuildMembers],
					%%更新帮派成员对就的帮派名
					db_agent:change_guild_membername(GuildId,GuildName),
					%%更新角色信息中对就的帮派名
					db_agent:change_player_guildname(GuildId,GuildName)
			end,
			{ok,1}			
	end.

%%
change_player_name(PlayerId,GuildId,NickName) ->
	GuildInfo = lib_guild_inner:get_guild(GuildId),
	Chief_id = GuildInfo#ets_guild.chief_id,
	Deputy_chief1_id = GuildInfo#ets_guild.deputy_chief1_id,
	Deputy_chief2_id = GuildInfo#ets_guild.deputy_chief2_id,
	%%更新帮派角色名
	if
		PlayerId == Chief_id ->
			NewGuildInfo = GuildInfo#ets_guild{chief_name = NickName},
			db_agent:change_guild_playername(GuildId,NickName,1),
			load_guild_into_ets(NewGuildInfo);
		PlayerId == Deputy_chief1_id ->
			NewGuildInfo = GuildInfo#ets_guild{deputy_chief1_name = NickName},
			db_agent:change_guild_playername(GuildId,NickName,2),
			load_guild_into_ets(NewGuildInfo);
		PlayerId == Deputy_chief2_id ->
			NewGuildInfo = GuildInfo#ets_guild{deputy_chief2_name = NickName},
			db_agent:change_guild_playername(GuildId,NickName,3),
			load_guild_into_ets(NewGuildInfo);
		true ->
			skip
	end,
	%%更新帮派成员角色名
	GuildMembers = lib_guild_inner:get_guild_member_by_guild_id(GuildId),
	case GuildMembers of
		[] ->
			skip;
		_ ->
			F = fun(GuildMember) ->
						MemberPlayerId = GuildMember#ets_guild_member.player_id,
						if
							PlayerId == MemberPlayerId ->
								NewGuildMember = GuildMember#ets_guild_member{player_name = NickName},
								load_guild_member_into_ets(NewGuildMember),
								db_agent:change_guild_member_playername(PlayerId,GuildId,NickName);
							true ->
								skip
						end
				end,
			[F(GuildMember) || GuildMember <- GuildMembers]
	end.

update_guild_ets(GuildId, ChiefId) ->
gen_server:cast(mod_guild:get_mod_guild_pid(), 
							 {apply_cast, lib_guild_inner, update_guild_ets_inner, 
							  [GuildId, ChiefId]}).
update_guild_ets_inner(GuildId, ChiefId) ->
	Pattern = #ets_guild{id = GuildId, chief_id = ChiefId, _='_'},
	ets:match_delete(?ETS_GUILD, Pattern),
	db_mongo:delete(guild, [{id, GuildId}, {chief_id, ChiefId}]).
