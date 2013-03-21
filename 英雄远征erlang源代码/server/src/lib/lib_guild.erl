%%%--------------------------------------
%%% @Module  : lib_guild
%%% @Author  : shebiao
%%% @Email   : shebiao@jieyou.com
%%% @Created : 2010.06.23
%%% @Description : 帮派业务处理实现
%%%--------------------------------------
-module(lib_guild).
-include("common.hrl").
-include("record.hrl").
-compile(export_all).

%%=========================================================================
%% SQL定义
%%=========================================================================

%% -----------------------------------------------------------------
%% 角色表SQL
%% -----------------------------------------------------------------
-define(SQL_PLAYER_SELECT_GUILD_INFO1,       "select nickname, realm, guild_id, guild_name, guild_position from player where id = ~p").
-define(SQL_PLAYER_SELECT_GUILD_INFO2,       "select id, realm, guild_id, guild_name, guild_position from player where nickname = '~s'").

-define(SQL_PLAYER_UPDATE_GUILD_INFO1,       "update player set guild_id=~p, guild_name='~s', guild_position=~p, coin = coin-~p where id = ~p").
-define(SQL_PLAYER_UPDATE_GUILD_INFO2,       "update player set guild_id=~p, guild_name='~s', guild_position=~p where guild_id = ~p").
-define(SQL_PLAYER_UPDATE_GUILD_INFO3,       "update player set guild_id=~p, guild_name='~s', guild_position=~p where id = ~p").
-define(SQL_PLAYER_UPDATE_GUILD_POSITION,    "update player set guild_position=~p where id=~p").
-define(SQL_PLAYER_UPDATE_DEDUCT_COIN,       "update player set coin=coin-~p where id=~p").
-define(SQL_PLAYER_UPDATE_ADD_COIN,          "update player set coin=coin+~p where id=~p").

%% -----------------------------------------------------------------
%% 帮派表SQL
%% -----------------------------------------------------------------
-define(SQL_GUILD_INSERT,                    "insert into guild(name,tenet,initiator_id,initiator_name,chief_id,chief_name,member_num,member_capacity,realm,level,contribution_daily,contribution_threshold,create_time,contribution_get_nexttime) "
                                             "values('~s','~s',~p,'~s',~p,'~s',~p,~p,~p,~p,~p,~p,~p, ~p)").

-define(SQL_GUILD_SELECT_ALL,                "select id,name,tenet,announce,initiator_id,initiator_name,chief_id,chief_name,deputy_chief1_id,deputy_chief1_name,deputy_chief2_id,deputy_chief2_name,deputy_chief_num,member_num,member_capacity,realm,level,reputation,funds,contribution,contribution_daily,contribution_threshold,contribution_get_nexttime,combat_num,combat_victory_num,qq,create_time,disband_flag,disband_confirm_time,disband_deadline_time from guild").
-define(SQL_GUILD_SELECT_CREATE,             "select id,name,tenet,announce,initiator_id,initiator_name,chief_id,chief_name,deputy_chief1_id,deputy_chief1_name,deputy_chief2_id,deputy_chief2_name,deputy_chief_num,member_num,member_capacity,realm,level,reputation,funds,contribution,contribution_daily,contribution_threshold,contribution_get_nexttime,combat_num,combat_victory_num,qq,create_time,disband_flag,disband_confirm_time,disband_deadline_time from guild where name = '~s'").

-define(SQL_GUILD_UPDATE_DISBAND_INFO,       "update guild set disband_flag=~p, disband_confirm_time=~p where id = ~p").
-define(SQL_GUILD_UPDATE_MEMBER_NUM,         "update guild set member_num=member_num+1 where id=~p").
-define(SQL_GUILD_UPDATE_REMOVE_DEPUTY1,     "update guild set member_num=member_num-1, deputy_chief_num=deputy_chief_num-1, deputy_chief1_id=0, deputy_chief1_name='' where id=~p").
-define(SQL_GUILD_UPDATE_REMOVE_DEPUTY2,     "update guild set member_num=member_num-1, deputy_chief_num=deputy_chief_num-1, deputy_chief2_id=0, deputy_chief2_name='' where id=~p").
-define(SQL_GUILD_UPDATE_MEMBER_NUM_DEDUCT,  "update guild set member_num=member_num-1 where id=~p").
-define(SQL_GUILD_UPDATE_TENET,              "update guild set tenet='~s' where id=~p").
-define(SQL_GUILD_UPDATE_ANNOUNCE,           "update guild set announce='~s' where id=~p").
-define(SQL_GUILD_UPDATE_DEDUCT_DEPUTY1,     "update guild set deputy_chief_num=deputy_chief_num-1, deputy_chief1_id=0, deputy_chief1_name='' where id=~p").
-define(SQL_GUILD_UPDATE_DEDUCT_DEPUTY2,     "update guild set deputy_chief_num=deputy_chief_num-1, deputy_chief2_id=0, deputy_chief2_name='' where id=~p").
-define(SQL_GUILD_UPDATE_ADD_DEPUTY1,        "update guild set deputy_chief_num=deputy_chief_num+1, deputy_chief1_id=~p, deputy_chief1_name='~s' where id=~p").
-define(SQL_GUILD_UPDATE_ADD_DEPUTY2,        "update guild set deputy_chief_num=deputy_chief_num+1, deputy_chief2_id=~p, deputy_chief2_name='~s' where id=~p").
-define(SQL_GUILD_UPDATE_CHANGE_DEPUTY1,     "update guild set chief_id=~p, chief_name='~s',deputy_chief1_id=~p, deputy_chief1_name='~s' where id=~p").
-define(SQL_GUILD_UPDATE_CHANGE_DEPUTY2,     "update guild set chief_id=~p, chief_name='~s',deputy_chief2_id=~p, deputy_chief2_name='~s' where id=~p").
-define(SQL_GUILD_UPDATE_ADD_FUNDS,          "update guild set funds=funds+~p where id=~p").
-define(SQL_GUILD_UPDATE_ADD_CONTRIBUTION,   "update guild set contribution=contribution+~p where id=~p").
-define(SQL_GUILD_UPDATE_GRADE,              "update guild set member_capacity=~p, level=~p, contribution=~p, contribution_daily=~p, contribution_threshold=~p, disband_deadline_time=0 where id=~p").
-define(SQL_GUILD_UPDATE_EXPIRED_DISBAND,    "update guild set disband_flag=0, disband_confirm_time=0 where disband_flag=1 and disband_confirm_time < ~p").
-define(SQL_GUILD_UPDATE_CONTRIBUTION_DAILY, "update guild set contribution=contribution-contribution_daily, contribution_get_nexttime=~p where contribution_get_nexttime < ~p").
-define(SQL_GUILD_UPDATE_DISBAND_DEADLINE,   "update guild set disband_deadline_time=~p where id=~p").
-define(SQL_GUILD_UPDATE_INIT,               "update guild set contribution=~p, contribution_get_nexttime=~p, contribution_daily=~p, contribution_threshold=~p, level=~p, disband_deadline_time=~p, member_capacity=~p where id=~p").

-define(SQL_GUILD_DELETE,                    "delete from guild where id = ~p").

%% -----------------------------------------------------------------
%% 帮派申请表SQL
%% -----------------------------------------------------------------
-define(SQL_GUILD_APPLY_INSERT,              "insert into guild_apply(player_id,guild_id,create_time) values(~p,~p,~p)").

-define(SQL_GUILD_APPLY_SELECT_ALL,          "select a.id, a.guild_id, a.player_id, a.create_time, b.nickname, b.sex, b.jobs, b.lv, b.career from guild_apply a join player b on a.player_id = b.id where a.guild_id = ~p").
-define(SQL_GUILD_APPLY_SELECT_NEW,          "select a.id, a.guild_id, a.player_id, a.create_time, b.nickname, b.sex, b.jobs, b.lv, b.career from guild_apply a join player b on a.player_id = b.id where a.player_id=~p and a.guild_id = ~p").

-define(SQL_GUILD_APPLY_DELETE,              "delete from guild_apply where guild_id = ~p").
-define(SQL_GUILD_APPLY_DELETE_PLAYER,       "delete from guild_apply where player_id = ~p").
-define(SQL_GUILD_APPLY_DELETE_ONE,          "delete from guild_apply where player_id = ~p and guild_id = ~p").
-define(SQL_GUILD_APPLY_DELETE_ALL,          "delete from guild_apply where player_id = ~p").

%% -----------------------------------------------------------------
%% 帮派邀请表SQL
%% -----------------------------------------------------------------
-define(SQL_GUILD_INVITE_INSERT,             "insert into guild_invite(player_id,guild_id,create_time) values(~p,~p,~p)").

-define(SQL_GUILD_INVITE_SELECT_ALL,         "select id, player_id, guild_id, create_time from guild_invite where player_id = ~p").
-define(SQL_GUILD_INVITE_SELECT_NEW,         "select id, player_id, guild_id, create_time from guild_invite where player_id = ~p and guild_id=~p").

-define(SQL_GUILD_INVITE_DELETE,             "delete from guild_invite where guild_id = ~p").
-define(SQL_GUILD_INVITE_DELETE_ONE,         "delete from guild_invite where player_id = ~p and guild_id = ~p").
-define(SQL_GUILD_INVITE_DELETE_ALL,         "delete from guild_invite where player_id = ~p").

%% -----------------------------------------------------------------
%% 帮派成员表SQL
%% -----------------------------------------------------------------
-define(SQL_GUILD_MEMBER_INSERT,             "insert into guild_member(guild_id,guild_name,player_id,player_name,create_time) "
                                             "values(~p,'~s',~p,'~s',~p)").

-define(SQL_GUILD_MEMBER_SELECT_ALL,         "select a.id,a.guild_id,a.guild_name,a.player_id,a.player_name,a.donate_total,a.donate_lasttime,a.donate_total_lastday,a.donate_total_lastweek,a.paid_get_lasttime,a.create_time,a.title,a.remark,a.honor, b.sex, b.jobs, b.lv, b.guild_position, b.last_login_time, b.online_flag, b.career from guild_member a join player b on a.player_id = b.id where a.guild_id = ~p").
-define(SQL_GUILD_MEMBER_SELECT_NEW,         "select a.id,a.guild_id,a.guild_name,a.player_id,a.player_name,a.donate_total,a.donate_lasttime,a.donate_total_lastday,a.donate_total_lastweek,a.paid_get_lasttime,a.create_time,a.title,a.remark,a.honor, b.sex, b.jobs, b.lv, b.guild_position, b.last_login_time, b.online_flag, b.career from guild_member a join player b on a.player_id = b.id where a.player_id=~p").

-define(SQL_GUILD_MEMBER_UPDATE_DONATE_INFO, "update guild_member set donate_total=~p,donate_lasttime=~p,donate_total_lastweek=~p,donate_total_lastday=~p where player_id = ~p").
-define(SQL_GUILD_MEMBER_UPDATE_PAID,        "update guild_member set paid_get_lasttime=~p where player_id=~p").
-define(SQL_PLAYER_MEMBER_UPDATE_TITLE,      "update guild_member set title='~s' where player_id=~p").
-define(SQL_PLAYER_MEMBER_UPDATE_REMARK,     "update guild_member set remark='~s' where player_id=~p").

-define(SQL_GUILD_MEMBER_DELETE,             "delete from guild_member where guild_id = ~p").
-define(SQL_GUILD_MEMBER_DELETE_ONE,         "delete from guild_member where player_id=~p and guild_id = ~p").

%%=========================================================================
%% 初始化回调函数
%%=========================================================================

%% -----------------------------------------------------------------
%% 角色登录
%% -----------------------------------------------------------------
role_login(PlayerId, LastLoginTime) ->
    GuildMember = get_guild_member_by_player_id(PlayerId),
    case  GuildMember of
        % 未参加帮派
        [] -> void;
        % 参加了帮派
        _  ->
            GuildMemberNew = GuildMember#ets_guild_member{online_flag = 1, last_login_time=LastLoginTime},
            update_guild_member(GuildMemberNew)
    end,
    load_all_guild_invite(PlayerId).
    

%% -----------------------------------------------------------------
%% 角色退出
%% -----------------------------------------------------------------
role_logout(PlayerId) ->
    GuildMember = get_guild_member_by_player_id(PlayerId),
    case  GuildMember of
        % 未参加帮派
        [] -> void;
        % 参加了帮派
        _  ->
            GuildMemberNew = GuildMember#ets_guild_member{online_flag = 0},
            update_guild_member(GuildMemberNew)
    end,
    delete_guild_invite_by_player_id(PlayerId).

%% -----------------------------------------------------------------
%% 角色升级
%% -----------------------------------------------------------------
role_upgrade(PlayerId, Level) ->
    % 如果是帮派成员则更新缓存
    GuildMember = get_guild_member_by_player_id(PlayerId),
    case  GuildMember of
        [] -> void;
        _  ->
            GuildMemberNew = GuildMember#ets_guild_member{level = Level},
            update_guild_member(GuildMemberNew)
    end,
    % 如果是申请了帮派则更新缓存
    GuildApply = get_guild_apply_by_player_id(PlayerId),
    case  GuildApply of
        [] -> void;
        _  ->
            GuildApplyNew = GuildApply#ets_guild_apply{player_level = Level},
            update_guild_apply(GuildApplyNew)
    end.

%% -----------------------------------------------------------------
%% 删除角色
%% -----------------------------------------------------------------
delete_role(PlayerId) ->
    ?DEBUG("delete_role: PlayerId=[~p]", [PlayerId]),
    GuildMember = get_guild_member_by_player_id(PlayerId),
    case  GuildMember of
        % 未参加帮派
        [] ->
            % 删除帮派申请
            remove_guild_invite_all(PlayerId),
            % 删除帮派邀请
            remove_guild_apply_all(PlayerId);
        % 参加了帮派
        _  ->
            case GuildMember#ets_guild_member.position of
                % 帮主
                1 ->
                    % 解散帮派
                    confirm_disband_guild(GuildMember#ets_guild_member.guild_id, GuildMember#ets_guild_member.guild_name, 1);
                % 副帮主
                _ ->
                    % 删除帮派成员
                    GuildId = GuildMember#ets_guild_member.guild_id,
                    Guild = get_guild(GuildId),
                    case Guild of
                        [] ->
                            ?ERR("delete_role: Not find guild, id=[~p]", [GuildId]);
                        _  ->
                            case remove_guild_member(PlayerId, GuildId, GuildMember#ets_guild_member.position, Guild#ets_guild.deputy_chief1_id, Guild#ets_guild.deputy_chief2_id) of
                                [ok, MemberType] ->
                                % 更新缓存
                                        case MemberType of
                                            0 ->
                                                GuildNew = Guild#ets_guild{member_num = Guild#ets_guild.member_num-1},
                                                lib_guild:update_guild(GuildNew);
                                            1 ->
                                                GuildNew = Guild#ets_guild{member_num         = Guild#ets_guild.member_num-1,
                                                                          deputy_chief_num   = Guild#ets_guild.deputy_chief_num -1,
                                                                          deputy_chief1_id   = 0,
                                                                          deputy_chief1_name = <<>>},
                                                lib_guild:update_guild(GuildNew);
                                            2 ->
                                                GuildNew = Guild#ets_guild{member_num         = Guild#ets_guild.member_num-1,
                                                                           deputy_chief_num   = Guild#ets_guild.deputy_chief_num -1,
                                                                           deputy_chief2_id   = 0,
                                                                           deputy_chief2_name = <<>>},
                                              lib_guild:update_guild(GuildNew)
                                        end;
                                _  ->
                                        void
                            end,
                            % 删除帮派申请
                           remove_guild_invite_all(PlayerId),
                            % 删除帮派邀请
                          remove_guild_apply_all(PlayerId)
                    end
            end
    end,
    ok.

%% -----------------------------------------------------------------
%% 加载所有帮派
%% -----------------------------------------------------------------
load_all_guild() ->
    SQL  = io_lib:format(?SQL_GUILD_SELECT_ALL, []),
    %?DEBUG("load_all_guild: SQL=[~s]", [SQL]),
    GuildList = db_sql:get_all(SQL),
    lists:map(fun load_guild_into_ets/1, GuildList),
    ?DEBUG("load_all_guild: [~p] guild loaded", [length(GuildList)]).

load_guild_into_ets([Id,Name,Tenet,Announce,InitiatorId,InitiatorName,ChiefId,ChiefName,DeputyChief1Id,DeputyChief1Name,DeputyChief2Id,DeputyChief2Name,DeputyChiefNum,MemberNum,MemberCapacity,Realm,Level,Reputation,Funds,Contribution,ContributionDaily,ContributionThreshold,ContributionGetNextTime,CombatNum,CombatVictoryNum,QQ,CreateTime,DisbandFlag,DisbandConfirmTime,DisbandDeadlineTime]) ->
    % 1- 收取日建设
    NowTime = util:unixtime(),
    [State, ContributionNew, ContributionGetNextTimeNew, ContributionDailyNew, ContributionThresholdNew, LevelNew, DisbandDeadlineTimeNew, MemberCapacityNew] =
        calc_contribution_daily(NowTime, ContributionGetNextTime, Contribution, ContributionDaily, ContributionThreshold, Level, DisbandDeadlineTime, MemberCapacity),
    if  % 如果收取了日建设则更新数据库
        (State > 0) ->
            SQLData = [ContributionNew, ContributionGetNextTimeNew, ContributionDailyNew, ContributionThresholdNew, LevelNew, DisbandDeadlineTimeNew, MemberCapacityNew, Id],
            SQL = io_lib:format(?SQL_GUILD_UPDATE_INIT, SQLData),
            ?DEBUG("load_guild_into_ets: SQL=[~s]", [SQL]),
            db_sql:execute(SQL),
            if  % 帮派掉级面临解散
                State == 3 ->
                    % 邮件通知给帮派成员
                    DelayDay = data_guild:get_guild_config(disband_lv0_delay_day, []),
                    mod_guild:send_guild_mail(guild_auto_disband, [Id, Name, DelayDay]);
                true ->
                    void
            end;
        true ->
            void
    end,
    % 2- 插入缓存
    Guild = #ets_guild{
        id = Id,
        name = Name,
        tenet = Tenet,
        announce = Announce,
        initiator_id = InitiatorId,
        initiator_name = InitiatorName,
        chief_id = ChiefId,
        chief_name = ChiefName,
        deputy_chief1_id = DeputyChief1Id,
        deputy_chief1_name = DeputyChief1Name,
        deputy_chief2_id = DeputyChief2Id,
        deputy_chief2_name = DeputyChief2Name,
        deputy_chief_num = DeputyChiefNum,
        member_num = MemberNum,
        member_capacity = MemberCapacityNew,
        realm = Realm,
        level = LevelNew,
        reputation = Reputation,
        funds = Funds,
        contribution = ContributionNew,
        contribution_daily = ContributionDailyNew,
        contribution_threshold = ContributionThresholdNew,
        contribution_get_nexttime = ContributionGetNextTimeNew,
        combat_num = CombatNum,
        combat_victory_num = CombatVictoryNum,
        qq = QQ,
        create_time = CreateTime,
        disband_flag = DisbandFlag,
        disband_confirm_time = DisbandConfirmTime,
        disband_deadline_time = DisbandDeadlineTimeNew
        },
    update_guild(Guild),
    % 加载该帮派成员
    load_all_guild_member(Guild#ets_guild.id),
    % 加载该帮派申请
    load_all_guild_apply(Guild#ets_guild.id).

%% -----------------------------------------------------------------
%% 加载所有帮派成员
%% -----------------------------------------------------------------
load_all_guild_member(GuildId) ->
    SQL  = io_lib:format(?SQL_GUILD_MEMBER_SELECT_ALL, [GuildId]),
    %?DEBUG("load_all_guild_member: SQL=[~s]", [SQL]),
    GuildMemberList = db_sql:get_all(SQL),
    lists:map(fun load_guild_member_into_ets/1, GuildMemberList),
    ?DEBUG("load_all_guild_member: guild=[~p], [~p] member loaded", [GuildId, length(GuildMemberList)]).
    
load_guild_member_into_ets([Id,GuildId,GuildName,PlayerId,PlayerName,DonateTotal,DonateLastTime,DonateTotalLastDay,DonateTotalLastWeek,PaidGetLastTime,CreateTime,Title,Remark,Honor,Sex,Jobs, Level, Position, LastLoginTime, OnlineFlag, Career]) ->
    % 插入缓存
    GuildMember = #ets_guild_member{
        id = Id,
        guild_id = GuildId,
        guild_name = GuildName,
        player_id = PlayerId,
        player_name = PlayerName,
        donate_total = DonateTotal,
        donate_lasttime = DonateLastTime,
        donate_total_lastday = DonateTotalLastDay,
        donate_total_lastweek = DonateTotalLastWeek,
        paid_get_lasttime = PaidGetLastTime,
        create_time = CreateTime,
        title = Title,
        remark = Remark,
        honor = Honor,
        sex   = Sex,
        jobs  = Jobs,
        level = Level,
        position = Position,                 
        last_login_time = LastLoginTime,
        online_flag = OnlineFlag,
        career = Career
        },
    update_guild_member(GuildMember).

%% -----------------------------------------------------------------
%% 加载所有帮派申请
%% -----------------------------------------------------------------
load_all_guild_apply(GuildId) ->
    SQL  = io_lib:format(?SQL_GUILD_APPLY_SELECT_ALL, [GuildId]),
    ?DEBUG("load_all_guild_member: SQL=[~s]", [SQL]),
    GuildApplyList = db_sql:get_all(SQL),
    lists:map(fun load_guild_apply_into_ets/1, GuildApplyList),
    ?DEBUG("load_all_guild_apply: guild=[~p], [~p] apply loaded", [GuildId, length(GuildApplyList)]).

load_guild_apply_into_ets([Id, GuildId, PlayerId, CreateTime, PlayerName, PlayerSex, PlayerJobs, PlayerLevel, PlayerCareer]) ->
    % 插入缓存
    GuildApply = #ets_guild_apply{
        id          = Id,
        guild_id    = GuildId,
        player_id   = PlayerId,
        player_name = PlayerName,        
        player_sex  = PlayerSex,
        player_jobs = PlayerJobs,
        player_level= PlayerLevel,
        create_time = CreateTime,
        player_career = PlayerCareer
        },
    update_guild_apply(GuildApply).

%% -----------------------------------------------------------------
%% 加载所有帮派邀请
%% -----------------------------------------------------------------
load_all_guild_invite(PlayerId) ->
    SQL  = io_lib:format(?SQL_GUILD_INVITE_SELECT_ALL, [PlayerId]),
    ?DEBUG("load_all_guild_invite: SQL=[~s]", [SQL]),
    GuildInviteList = db_sql:get_all(SQL),
    lists:map(fun load_guild_invite_into_ets/1, GuildInviteList),
    ?DEBUG("load_all_guild_invite: PlayerId=[~p], [~p] invite loaded", [PlayerId, length(GuildInviteList)]).

load_guild_invite_into_ets([Id, PlayerId, GuildId, CreateTime]) ->
    % 插入缓存
    GuildInvite = #ets_guild_invite{
        id          = Id,
        guild_id    = GuildId,
        player_id   = PlayerId,
        create_time = CreateTime
        },
    update_guild_invite(GuildInvite).

%%=========================================================================
%% 业务操作函数
%%=========================================================================

%% -----------------------------------------------------------------
%% 创建帮派
%% -----------------------------------------------------------------
create_guild(PlayerId, PlayerName, PlayerRealm, GuildName, GuildTenet, CreateCoin) ->
    ?DEBUG("create_guild: PlayerId=[~p], PlayerName=[~s], PlayerRealm=[~p], GuildName=[~s], GuildTenet=[~s], CreateCoin=[~p]", [PlayerId, PlayerName, PlayerRealm, GuildName, GuildTenet, CreateCoin]),
    [_MemberCapacityBase, MemberCapcity, _ContributionCardNum, ContributionThreshold, ContributionDaily] = data_guild:get_level_info(1),
    CreateTime              = util:unixtime(),
    FreeDay                 = data_guild:get_guild_config(contribution_free_day, []),
    ContributionGetNextTime = CreateTime + FreeDay*(?ONE_DAY_SECONDS),
    % 插入帮派
    Data       = [GuildName, GuildTenet, PlayerId, PlayerName, PlayerId, PlayerName, 1, MemberCapcity, PlayerRealm, 1, ContributionDaily, ContributionThreshold, CreateTime, ContributionGetNextTime],
    SQL        = io_lib:format(?SQL_GUILD_INSERT, Data),
    ?DEBUG("create_guild: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    % 获取刚插入的帮派
    Data1   = [GuildName],
    SQL1    = io_lib:format(?SQL_GUILD_SELECT_CREATE, Data1),
    ?DEBUG("create_guild: SQL=[~s]", [SQL1]),
    Guild = db_sql:get_row(SQL1),
    if Guild =:= [] ->
            ?ERR("create_guild: guild id is null, name=[~s]", [GuildName]),
            error;
        true ->
            % 插入帮派成员
            [GuildId|_]   = Guild,
            Data2         = [GuildId, GuildName, PlayerId, PlayerName,CreateTime],
            SQL2          = io_lib:format(?SQL_GUILD_MEMBER_INSERT, Data2),
            ?DEBUG("create_guild: SQL=[~s]", [SQL2]),
            db_sql:execute(SQL2),
            % 更新角色表
            Data3 = [GuildId, GuildName, 1, CreateCoin, PlayerId],
            SQL3  = io_lib:format(?SQL_PLAYER_UPDATE_GUILD_INFO1, Data3),
            ?DEBUG("create_guild: SQL=[~s]", [SQL3]),
            db_sql:execute(SQL3),
            % 更新缓存
            load_guild_into_ets(Guild),
            GuildCahe       = get_guild(GuildId),
            GuildMemberCahe = get_guild_member_by_player_id(PlayerId),
            ?DEBUG("Cache was update, guild id=[~p], member id=[~p]", [GuildCahe#ets_guild.id, GuildMemberCahe#ets_guild_member.id]),
            {ok, GuildId}
end.
    

%% -----------------------------------------------------------------
%% 申请解散帮派
%% -----------------------------------------------------------------
apply_disband_guild(GuildId) ->
    ?DEBUG("apply_disband_guild: GuildId=[~p]", [GuildId]),
    % 更新帮派
    ConfirmDay  = data_guild:get_guild_config(disband_confirm_day, []),
    ConfirmTime = util:unixtime() + ConfirmDay*(?ONE_DAY_SECONDS),
    Data        = [1, ConfirmTime, GuildId],
    SQL         = io_lib:format(?SQL_GUILD_UPDATE_DISBAND_INFO, Data),
    ?DEBUG("apply_disband_guild: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    [ok, ConfirmTime].

%% -----------------------------------------------------------------
%% 确认解散帮派
%% -----------------------------------------------------------------
confirm_disband_guild(GuildId, GuildName, ConfirmResult) ->
    ?DEBUG("confirm_disband_guild: GuildId=[~p], GuildName=[~s], ConfirmResult=[~p]", [GuildId, GuildName, ConfirmResult]),
    if ConfirmResult == 0 ->
            % 更新帮派表
            Data = [0, 0, GuildId],
            SQL  = io_lib:format(?SQL_GUILD_UPDATE_DISBAND_INFO, Data),
            ?DEBUG("confirm_disband_guild: SQL=[~s]", [SQL]),
            db_sql:execute(SQL);
       true ->
            % 更新角色表
            Data      = [0, "", 0, GuildId],
            SQL       = io_lib:format(?SQL_PLAYER_UPDATE_GUILD_INFO2, Data),
            ?DEBUG("confirm_disband_guild: SQL=[~s]", [SQL]),
            db_sql:execute(SQL),
            % 删除帮派表
            Data1 = [GuildId],
            SQL1  = io_lib:format(?SQL_GUILD_DELETE, Data1),
            ?DEBUG("confirm_disband_guild: SQL=[~s]", [SQL1]),
            db_sql:execute(SQL1),
            % 删除帮派成员表
            Data2 = [GuildId],            
            SQL2  = io_lib:format(?SQL_GUILD_MEMBER_DELETE, Data2),
            ?DEBUG("confirm_disband_guild: SQL=[~s]", [SQL2]),
            db_sql:execute(SQL2),
            % 删除帮派申请表
            Data3 = [GuildId],
            SQL3  = io_lib:format(?SQL_GUILD_APPLY_DELETE, Data3),
            ?DEBUG("confirm_disband_guild: SQL=[~s]", [SQL3]),
            db_sql:execute(SQL3),
            % 删除帮派邀请表
            Data4 = [GuildId],            
            SQL4  = io_lib:format(?SQL_GUILD_INVITE_DELETE, Data4),
            ?DEBUG("confirm_disband_guild: SQL=[~s]", [SQL4]),
            db_sql:execute(SQL4),
            % 邮件通知给帮派成员
            NameList  = get_member_name_list(GuildId),
            mod_guild:send_guild_mail(guild_disband, [GuildId, GuildName, NameList]),
            % 更新缓存
            delete_guild(GuildId),
            delete_guild_member_by_guild_id(GuildId),
            delete_guild_invite_by_guild_id(GuildId),
            delete_guild_apply_by_guild_id(GuildId)
    end,
    ok.

%% -----------------------------------------------------------------
%% 添加帮派加入申请
%% -----------------------------------------------------------------
add_guild_apply(PlayerId, GuildId) ->
    ?DEBUG("add_guild_apply: PlayerId=[~p], GuildId=[~p]", [PlayerId, GuildId]),
    % 删除其他申请
    Data       = [PlayerId],
    SQL        = io_lib:format(?SQL_GUILD_APPLY_DELETE_PLAYER, Data),
    ?DEBUG("add_guild_apply: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    % 插入帮派申请
    CreateTime  = util:unixtime(),
    Data1       = [PlayerId, GuildId, CreateTime],
    SQL1        = io_lib:format(?SQL_GUILD_APPLY_INSERT, Data1),
    ?DEBUG("add_guild_apply: SQL=[~s]", [SQL1]),
    db_sql:execute(SQL1),
    % 更新缓存
    delete_guild_apply_by_player_id(PlayerId),
    Data2 = [PlayerId, GuildId],
    SQL2  = io_lib:format(?SQL_GUILD_APPLY_SELECT_NEW, Data2),
    ?DEBUG("add_guild_apply: SQL=[~s]", [SQL2]),
    GuildApply = db_sql:get_row(SQL2),
    load_guild_apply_into_ets(GuildApply),
    ok.
    
%% -----------------------------------------------------------------
%% 添加帮派邀请
%% -----------------------------------------------------------------
add_guild_invite(PlayerId, GuildId) ->
    ?DEBUG("add_guild_invite: PlayerId=[~p], GuildId=[~p]", [PlayerId, GuildId]),
    % 插入帮派邀请
    CreateTime = util:unixtime(),
    Data       = [PlayerId, GuildId, CreateTime],
    SQL        = io_lib:format(?SQL_GUILD_INVITE_INSERT, Data),
    ?DEBUG("add_guild_invite: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    % 更新缓存
    Data1 = [PlayerId, GuildId],
    SQL1  = io_lib:format(?SQL_GUILD_INVITE_SELECT_NEW, Data1),
    ?DEBUG("add_guild_invite: SQL=[~s]", [SQL1]),
    GuildInvite = db_sql:get_row(SQL1),
    load_guild_invite_into_ets(GuildInvite),
    ok.

%% -----------------------------------------------------------------
%% 删除帮派申请
%% -----------------------------------------------------------------
remove_guild_apply(PlayerId, GuildId) ->
    ?DEBUG("remove_guild_apply: PlayerId=[~p], GuildId=[~p]", [PlayerId, GuildId]),
    % 删除帮派申请
    Data = [PlayerId, GuildId],    
    SQL  = io_lib:format(?SQL_GUILD_APPLY_DELETE_ONE, Data),
    ?DEBUG("remove_guild_apply: sql=~s", [SQL]),
    db_sql:execute(SQL),
    % 更新缓存
    delete_guild_apply_by_player_id(PlayerId, GuildId),
    ok.

%% -----------------------------------------------------------------
%% 删除帮派邀请
%% -----------------------------------------------------------------
remove_guild_invite(PlayerId, GuildId) ->
    ?DEBUG("remove_guild_invite: PlayerId=[~p], GuildId=[~p]", [PlayerId, GuildId]),
    % 删除帮派邀请
    Data = [PlayerId, GuildId],
    SQL  = io_lib:format(?SQL_GUILD_INVITE_DELETE_ONE, Data),
    ?DEBUG("remove_guild_invite: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    % 更新缓存
    delete_guild_invite_by_player_id(PlayerId, GuildId),
    ok.

%% -----------------------------------------------------------------
%% 删除角色所有的帮派申请
%% -----------------------------------------------------------------
remove_guild_apply_all(PlayerId) ->
    ?DEBUG("remove_guild_apply_all: PlayerId=[~p]", [PlayerId]),
    % 删除帮派申请
    Data = [PlayerId],
    SQL  = io_lib:format(?SQL_GUILD_APPLY_DELETE_ALL, Data),
    ?DEBUG("remove_guild_apply_all: sql=~s", [SQL]),
    db_sql:execute(SQL),
    % 更新缓存
    delete_guild_apply_by_player_id(PlayerId),
    ok.

%% -----------------------------------------------------------------
%% 删除帮派邀请
%% -----------------------------------------------------------------
remove_guild_invite_all(PlayerId) ->
    ?DEBUG("remove_guild_invite_all: PlayerId=[~p]", [PlayerId]),
    % 删除帮派邀请
    Data = [PlayerId],
    SQL  = io_lib:format(?SQL_GUILD_INVITE_DELETE_ALL, Data),
    ?DEBUG("remove_guild_invite_all: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    % 更新缓存
    delete_guild_invite_by_player_id(PlayerId),
    ok.

%% -----------------------------------------------------------------
%% 添加新成员
%% -----------------------------------------------------------------
add_guild_member(PlayerId, PlayerName, GuildId, GuildName, GuildPosition) ->
    ?DEBUG("add_guild_member: PlayerId=[~p], PlayerName=[~s],GuildId=[~p],GuildName=[~s], GuildPosition=[~p]", [PlayerId, PlayerName, GuildId, GuildName, GuildPosition]),
    % 插入帮派成员
    CreateTime    = util:unixtime(),
    Data          = [GuildId, GuildName, PlayerId, PlayerName,CreateTime],
    SQL           = io_lib:format(?SQL_GUILD_MEMBER_INSERT, Data),
    ?DEBUG("add_guild_member: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    % 更新角色表
    Data1 = [GuildId, GuildName, GuildPosition, PlayerId],
    SQL1  = io_lib:format(?SQL_PLAYER_UPDATE_GUILD_INFO3, Data1),
    ?DEBUG("add_guild_member: SQL=[~s]", [SQL1]),
    db_sql:execute(SQL1),
    % 更新帮派表
    Data2 = [GuildId],
    SQL2  = io_lib:format(?SQL_GUILD_UPDATE_MEMBER_NUM, Data2),
    ?DEBUG("add_guild_member: SQL=[~s]", [SQL2]),
    db_sql:execute(SQL2),
    % 删除帮派申请
    remove_guild_apply_all(PlayerId),
    % 删除帮派邀请
    remove_guild_invite_all(PlayerId),
    % 更新缓存
    Data3 = [PlayerId],
    SQL3  = io_lib:format(?SQL_GUILD_MEMBER_SELECT_NEW, Data3),
    ?DEBUG("add_guild_member: SQL=[~s]", [SQL3]),
    GuildMember = db_sql:get_row(SQL3),
    load_guild_member_into_ets(GuildMember),
    ok.

%% -----------------------------------------------------------------
%% 删除成员
%% -----------------------------------------------------------------
remove_guild_member(PlayerId, GuildId, GuildPosition, DeputyChielfId1, DeputyChielfId2) ->
    ?DEBUG("remove_guild_member: PlayerId=[~p], GuildId=[~p], GuildPosition=[~p], DeputyChielfId1=[~p], DeputyChielfId2=[~p]", [PlayerId, GuildId, GuildPosition, DeputyChielfId1, DeputyChielfId2]),
    % 更新角色表
    Data = [0, "", 0, PlayerId],
    SQL  = io_lib:format(?SQL_PLAYER_UPDATE_GUILD_INFO3, Data),
    ?DEBUG("remove_guild_member: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    % 更新帮派表
    MemberType = case PlayerId == DeputyChielfId1 of
        true ->
            Data1 = [GuildId],
            SQL1  = io_lib:format(?SQL_GUILD_UPDATE_REMOVE_DEPUTY1, Data1),
            ?DEBUG("remove_guild_member: SQL=[~s]", [SQL1]),
            db_sql:execute(SQL1),
            1;
        false when PlayerId == DeputyChielfId2 ->
            Data1 = [GuildId],
            SQL1  = io_lib:format(?SQL_GUILD_UPDATE_REMOVE_DEPUTY2, Data1),
            ?DEBUG("remove_guild_member: SQL=[~s]", [SQL1]),
            db_sql:execute(SQL1),
            2;
        false ->
            Data1 = [GuildId],
            SQL1  = io_lib:format(?SQL_GUILD_UPDATE_MEMBER_NUM_DEDUCT, Data1),
            ?DEBUG("remove_guild_member: SQL=[~s]", [SQL1]),
            db_sql:execute(SQL1),
            0
    end,
    % 删除帮派成员表
    Data2 = [PlayerId, GuildId],
    SQL2  = io_lib:format(?SQL_GUILD_MEMBER_DELETE_ONE, Data2),
    ?DEBUG("remove_guild_member: SQL=[~s]", [SQL2]),
    db_sql:execute(SQL2),
    % 更新缓存
    delete_guild_member_by_player_id(PlayerId),
    [ok, MemberType].

%% -----------------------------------------------------------------
%% 获取帮派列表
%% -----------------------------------------------------------------
get_guild_page(PageSize, PageNo) ->
    ?DEBUG("get_guild_page: PageSize=[~p], PageNo=[~p]", [PageSize, PageNo]),
    % 获取总记录数
    Guilds       = get_guild_all(),
    SortedGuilds = lists:sort(fun sort_guild_by_level/2, Guilds),
    RecordTotal  = length(SortedGuilds),
    % 计算分页
    {PageTotal, StartPos, RecordNum} = calc_page_cache(RecordTotal, PageSize, PageNo),
    ?DEBUG("get_guild_page: PageTotal=[~p], StartPos=[~p], RecordNum=[~p]", [PageTotal, StartPos, RecordNum]),
    % 获取分页
    RowsPage = RowsPage = lists:sublist(SortedGuilds, StartPos, PageSize),
    % 处理分页
    Records = lists:map(fun handle_guild_page/1, RowsPage),
    % 发送回应
    [1, PageTotal, PageNo, RecordNum, list_to_binary(Records)].

sort_guild_by_level(Guild1, Guild2) ->
    case Guild1#ets_guild.level =< Guild2#ets_guild.level of
        true  -> false;
        false -> true
    end.

handle_guild_page(Guild) ->
    [GuildId, GuildName, ChiefId, ChiefName, MemberNum, MemberCapacity, Level, Realm, Tenet] =
        [Guild#ets_guild.id, Guild#ets_guild.name, Guild#ets_guild.chief_id, Guild#ets_guild.chief_name, Guild#ets_guild.member_num, Guild#ets_guild.member_capacity, Guild#ets_guild.level, Guild#ets_guild.realm, Guild#ets_guild.tenet],
    GuildNameLen = byte_size(GuildName),
    ChiefNameLen = byte_size(ChiefName),
    TenetLen     = byte_size(Tenet),
    <<GuildId:32, GuildNameLen:16, GuildName/binary, ChiefId:32, ChiefNameLen:16, ChiefName/binary, MemberNum:16, MemberCapacity:16, Level:16, Realm:16, TenetLen:16, Tenet/binary>>.

%% -----------------------------------------------------------------
%% 获取成员列表
%% -----------------------------------------------------------------
get_guild_member_page(GuildId, PageSize, PageNo) ->
    ?DEBUG("get_guild_member_page: GuildId=[~p], PageSize=[~p], PageNo=[~p]", [GuildId, PageSize, PageNo]),
    % 获取总记录数
    GuildMembers = get_guild_member_by_guild_id(GuildId),
    RecordTotal  = length(GuildMembers),
    % 计算分页
    {PageTotal, StartPos, RecordNum} = calc_page_cache(RecordTotal, PageSize, PageNo),
    ?DEBUG("get_guild_member_page: PageTotal=[~p], StartPos=[~p], RecordNum=[~p]", [PageTotal, StartPos, RecordNum]),
    % 获取分页
    RowsPage = lists:sublist(GuildMembers, StartPos, PageSize),
    % 处理分页
    Records = lists:map(fun handle_member_page/1, RowsPage),
    % 发送回应
    [1, PageTotal, PageNo, RecordNum, list_to_binary(Records)].

handle_member_page(GuildMember) ->
    [PlayerId, PlayerName, PlayerSex, _PlayerJobs, PlayerLevel, LastLoginTime, GuildPosition, DonateTotal, OnlineFlag, PlayerCareer] =
        [GuildMember#ets_guild_member.player_id, GuildMember#ets_guild_member.player_name, GuildMember#ets_guild_member.sex, GuildMember#ets_guild_member.jobs, GuildMember#ets_guild_member.level, GuildMember#ets_guild_member.last_login_time, GuildMember#ets_guild_member.position, GuildMember#ets_guild_member.donate_total, GuildMember#ets_guild_member.online_flag, GuildMember#ets_guild_member.career],
    PlayerNameLen = byte_size(PlayerName),
    <<PlayerId:32, PlayerNameLen:16, PlayerName/binary, PlayerSex:16, PlayerCareer:16, PlayerLevel:16, LastLoginTime:32, GuildPosition:16, DonateTotal:32, OnlineFlag:16>>.


%% -----------------------------------------------------------------
%% 获取申请列表
%% -----------------------------------------------------------------
get_guild_apply_page(GuildId, PageSize, PageNo) ->
    ?DEBUG("get_guild_apply_page: GuildId=[~p], PageSize=[~p], PageNo=[~p]", [GuildId, PageSize, PageNo]),
    % 获取总记录数
    GuildApplys = get_guild_apply_by_guild_id(GuildId),
    RecordTotal  = length(GuildApplys),
    % 计算分页
    {PageTotal, StartPos, RecordNum} = calc_page_cache(RecordTotal, PageSize, PageNo),
    ?DEBUG("get_guild_apply_page: PageTotal=[~p], StartPos=[~p], RecordNum=[~p]", [PageTotal, StartPos, RecordNum]),
    % 获取分页
    RowsPage = lists:sublist(GuildApplys, StartPos, PageSize),
    % 处理分页
    Records = lists:map(fun handle_apply_page/1, RowsPage),
    % 发送回应
    [1, PageTotal, PageNo, RecordNum, list_to_binary(Records)].

handle_apply_page(GuildApply) ->
    [PlayerId, PlayerName, PlayerSex, _PlayerJobs, PlayerLevel, ApplyTime, PlayerCareer] =
        [GuildApply#ets_guild_apply.player_id, GuildApply#ets_guild_apply.player_name, GuildApply#ets_guild_apply.player_sex, GuildApply#ets_guild_apply.player_jobs, GuildApply#ets_guild_apply.player_level, GuildApply#ets_guild_apply.create_time, GuildApply#ets_guild_apply.player_career],
    PlayerNameLen = byte_size(PlayerName),
    <<PlayerId:32, PlayerNameLen:16, PlayerName/binary, PlayerSex:16, PlayerCareer:16, PlayerLevel:16, ApplyTime:32 >>.

%% -----------------------------------------------------------------
%% 获取邀请列表
%% -----------------------------------------------------------------
get_guild_invite_page(PlayerId, PageSize, PageNo) ->
    ?DEBUG("get_guild_invite_page: PlayerId=[~p], PageSize=[~p], PageNo=[~p]", [PlayerId, PageSize, PageNo]),
    % 获取总记录数
    GuildInvites = get_guild_invite_by_player_id(PlayerId),
    RecordTotal = length(GuildInvites),
    % 计算分页
    {PageTotal, StartPos, RecordNum} = calc_page_cache(RecordTotal, PageSize, PageNo),
    ?DEBUG("get_guild_invite_page: PageTotal=[~p], StartPos=[~p], RecordNum=[~p]", [PageTotal, StartPos, RecordNum]),
    % 获取分页
    RowsPage = lists:sublist(GuildInvites, StartPos, PageSize),
    % 处理分页
    Records = lists:map(fun handle_invite_page/1, RowsPage),
    % 发送回应
    [1, PageTotal, PageNo, RecordNum, list_to_binary(Records)].

handle_invite_page(GuildInvite) ->
    [GuildId, InviteTime] =
        [GuildInvite#ets_guild_invite.guild_id, GuildInvite#ets_guild_invite.create_time],
    Guild = get_guild(GuildId),
    case Guild of
        [] ->
            <<>>;
        _ ->
            [GuildName, ChiefId, ChiefName, MemberNum, MemberCapacity, Level, Realm, Tenet]
                = [Guild#ets_guild.name, Guild#ets_guild.chief_id, Guild#ets_guild.chief_name, Guild#ets_guild.member_num, Guild#ets_guild.member_capacity, Guild#ets_guild.level, Guild#ets_guild.realm, Guild#ets_guild.tenet],
            GuildNameLen = byte_size(GuildName),
            ChiefNameLen = byte_size(ChiefName),
            TenetLen     = byte_size(Tenet),
            <<GuildId:32, GuildNameLen:16, GuildName/binary, ChiefId:32, ChiefNameLen:16, ChiefName/binary, MemberNum:16, MemberCapacity:16, Level:16, Realm:16, TenetLen:16, Tenet/binary, InviteTime:32>>
    end.
    
%% -----------------------------------------------------------------
%% 获取帮派信息
%% -----------------------------------------------------------------
get_guild_info(GuildId) ->
    ?DEBUG("get_guild_info: GuildId=~p", [GuildId]),
    Guild = get_guild(GuildId),
    if  % 帮派不存在
        Guild =:= [] ->
            [2, <<>>];
        true ->
            [Id,Name,Tenet,Announce,InitiatorId,InitiatorName,ChiefId,ChiefName,DeputyChief1Id,DeputyChief1Name,DeputyChief2Id,DeputyChief2Name,DeputyChiefNum,MemberNum,MemberCapacity,Realm,Level,Reputation,Funds,Contribution,ContributionDaily,CombatNum,CombatVictoryNum,QQ,CreateTime, ContributionThreshold] =
                [Guild#ets_guild.id, Guild#ets_guild.name, Guild#ets_guild.tenet, Guild#ets_guild.announce, Guild#ets_guild.initiator_id, Guild#ets_guild.initiator_name, Guild#ets_guild.chief_id, Guild#ets_guild.chief_name, Guild#ets_guild.deputy_chief1_id,Guild#ets_guild.deputy_chief1_name, Guild#ets_guild.deputy_chief2_id, Guild#ets_guild.deputy_chief2_name, Guild#ets_guild.deputy_chief_num, Guild#ets_guild.member_num,Guild#ets_guild.member_capacity, Guild#ets_guild.realm, Guild#ets_guild.level, Guild#ets_guild.reputation, Guild#ets_guild.funds, Guild#ets_guild.contribution, Guild#ets_guild.contribution_daily,Guild#ets_guild.combat_num, Guild#ets_guild.combat_victory_num, Guild#ets_guild.qq, Guild#ets_guild.create_time, Guild#ets_guild.contribution_threshold],
            NameLen             = byte_size(Name),
            TenetLen            = byte_size(Tenet),
            AnnounceLen         = byte_size(Announce),
            InitiatorNameLen    = byte_size(InitiatorName),
            ChiefNameLen        = byte_size(ChiefName),
            DeputyChief1NameLen = byte_size(DeputyChief1Name),
            DeputyChief2NameLen = byte_size(DeputyChief2Name),
            if ((DeputyChiefNum == 1) and (DeputyChief1Id == 0)) ->
                        [1, <<Id:32,NameLen:16,Name/binary,TenetLen:16,Tenet/binary,AnnounceLen:16,Announce/binary,InitiatorId:32,InitiatorNameLen:16,InitiatorName/binary,ChiefId:32,ChiefNameLen:16,ChiefName/binary,DeputyChief2Id:32,DeputyChief2NameLen:16,DeputyChief2Name/binary,DeputyChief1Id:32,DeputyChief1NameLen:16,DeputyChief1Name/binary,DeputyChiefNum:16,MemberNum:16,MemberCapacity:16,Realm:16,Level:16,Reputation:16,Funds:32,Contribution:32,ContributionDaily:16,CombatNum:16,CombatVictoryNum:16,QQ:32,CreateTime:32, ContributionThreshold:32>>];
                    true ->
                        [1, <<Id:32,NameLen:16,Name/binary,TenetLen:16,Tenet/binary,AnnounceLen:16,Announce/binary,InitiatorId:32,InitiatorNameLen:16,InitiatorName/binary,ChiefId:32,ChiefNameLen:16,ChiefName/binary,DeputyChief1Id:32,DeputyChief1NameLen:16,DeputyChief1Name/binary,DeputyChief2Id:32,DeputyChief2NameLen:16,DeputyChief2Name/binary,DeputyChiefNum:16,MemberNum:16,MemberCapacity:16,Realm:16,Level:16,Reputation:16,Funds:32,Contribution:32,ContributionDaily:16,CombatNum:16,CombatVictoryNum:16,QQ:32,CreateTime:32, ContributionThreshold:32>>]
            end
    end.

%% -----------------------------------------------------------------
%% 修改帮派宗旨
%% -----------------------------------------------------------------
modify_guild_tenet(GuildId, Tenet) ->
    ?DEBUG("modify_guild_tenet: GuildId=[~p], Tenet=[~s]", [GuildId, Tenet]),
    Data = [Tenet, GuildId],
    SQL = io_lib:format(?SQL_GUILD_UPDATE_TENET, Data),
    ?DEBUG("modify_guild_tenet: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    ok.

%% -----------------------------------------------------------------
%% 修改帮派公告
%% -----------------------------------------------------------------
modify_guild_announce(GuildId, Announce) ->
    ?DEBUG("modify_guild_announce: GuildId=[~p], Announce=[~s]", [GuildId, Announce]),
    Data = [Announce, GuildId],
    SQL = io_lib:format(?SQL_GUILD_UPDATE_ANNOUNCE, Data),
    ?DEBUG("modify_guild_announce: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    ok.

%% -----------------------------------------------------------------
%% 职位设置
%% -----------------------------------------------------------------
set_position(PlayerId, PlayerName, GuildId, NewGuildPosition, DeputyChielfId1, DeputyChielfId2) ->
    ?DEBUG("set_position: PlayerId=[~p], PlayerName=[~s], GuildId=[~p], NewGuildPosition=[~p], DeputyChielfId1=[~p], DeputyChielfId2=[~p]", [PlayerId, PlayerName, GuildId, NewGuildPosition, DeputyChielfId1, DeputyChielfId2]),
    % 更新角色表
    Data = [NewGuildPosition, PlayerId],
    SQL  = io_lib:format(?SQL_PLAYER_UPDATE_GUILD_POSITION, Data),
    ?DEBUG("set_position: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    % 更新帮派表
    MemberType = case  ((PlayerId == DeputyChielfId1) and (NewGuildPosition /= 2)) of
        true ->
            Data1 = [GuildId],
            SQL1  = io_lib:format(?SQL_GUILD_UPDATE_DEDUCT_DEPUTY1, Data1),
            ?DEBUG("set_position: SQL=[~s]", [SQL1]),
            db_sql:execute(SQL1),
            1;
        false when ((PlayerId == DeputyChielfId2) and (NewGuildPosition /= 2)) ->
            Data1 = [GuildId],
            SQL1  = io_lib:format(?SQL_GUILD_UPDATE_DEDUCT_DEPUTY2, Data1),
            ?DEBUG("set_position: SQL=[~s]", [SQL1]),
            db_sql:execute(SQL1),
            2;
         % 副帮主数增加
        false when ((DeputyChielfId1 == 0) and (NewGuildPosition == 2)) ->
            Data1 = [PlayerId, PlayerName, GuildId],
            SQL1  = io_lib:format(?SQL_GUILD_UPDATE_ADD_DEPUTY1, Data1),
            ?DEBUG("set_position: SQL=[~s]", [SQL1]),
            db_sql:execute(SQL1),
            3;
        false when ((DeputyChielfId2 == 0) and (NewGuildPosition == 2)) ->
            Data1 = [PlayerId, PlayerName, GuildId],
            SQL1  = io_lib:format(?SQL_GUILD_UPDATE_ADD_DEPUTY2, Data1),
            ?DEBUG("set_position: SQL=[~s]", [SQL1]),
            db_sql:execute(SQL1),
            4;
        false ->
            0
    end,
    % 更新缓存
    GuildMember = get_guild_member_by_player_id(PlayerId),
    GuildMemberNew = GuildMember#ets_guild_member{position = NewGuildPosition},
    update_guild_member(GuildMemberNew),
    [ok, MemberType].

%% -----------------------------------------------------------------
%% 禅让帮主
%% -----------------------------------------------------------------
demise_chief(PlayerId1, PlayerName1,PlayerId2, PlayerName2, GuildId, DeputyChielfId1, DeputyChielfId2) ->
    ?DEBUG("demise_chief: PlayerId1=[~p], PlayerName1=[~s],PlayerId2=[~p], PlayerName2=[~s], GuildId=[~p], DeputyChielfId1=[~p], DeputyChielfId2=[~p]", [PlayerId1, PlayerName1,PlayerId2, PlayerName2, GuildId, DeputyChielfId1, DeputyChielfId2]),
    % 更新角色表
    Data = [2, PlayerId1],
    SQL  = io_lib:format(?SQL_PLAYER_UPDATE_GUILD_POSITION, Data),
    ?DEBUG("demise_chief: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    Data1 = [1, PlayerId2],
    SQL1  = io_lib:format(?SQL_PLAYER_UPDATE_GUILD_POSITION, Data1),
    ?DEBUG("demise_chief: SQL=[~s]", [SQL1]),
    db_sql:execute(SQL1),
    % 更新帮派表
    MemberType = case PlayerId2 == DeputyChielfId1 of
        true ->
            Data2 = [PlayerId2, PlayerName2, PlayerId1, PlayerName1, GuildId],
            SQL2  = io_lib:format(?SQL_GUILD_UPDATE_CHANGE_DEPUTY1, Data2),
            ?DEBUG("demise_chief: SQL=[~s]", [SQL2]),
            db_sql:execute(SQL2),
            1;
        false when PlayerId2 == DeputyChielfId2 ->
            Data2 = [PlayerId2, PlayerName2, PlayerId1, PlayerName1, GuildId],
            SQL2  = io_lib:format(?SQL_GUILD_UPDATE_CHANGE_DEPUTY2, Data2),
            ?DEBUG("demise_chief: SQL=[~s]", [SQL2]),
            db_sql:execute(SQL2),
            2;
        false ->
            0
    end,
    % 更新缓存
    GuildMember1 = get_guild_member_by_player_id(PlayerId1),
    GuildMemberNew1 = GuildMember1#ets_guild_member{position = 2},
    update_guild_member(GuildMemberNew1),
    GuildMember2 = get_guild_member_by_player_id(PlayerId2),
    GuildMemberNew2 = GuildMember2#ets_guild_member{position = 1},
    update_guild_member(GuildMemberNew2),
    [ok, MemberType].

% -----------------------------------------------------------------
%% 捐献钱币
%% -----------------------------------------------------------------
donate_money(PlayerId, GuildId, Num) ->
    ?DEBUG("donate_money: PlayerId=[~p], GuildId=[~p], Num=[~p]", [PlayerId, GuildId, Num]),
    % 更新角色表
    Data = [Num, PlayerId],
    SQL  = io_lib:format(?SQL_PLAYER_UPDATE_DEDUCT_COIN, Data),
    ?DEBUG("donate_money: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    % 更新帮派表
    Data1 = [Num, GuildId],
    SQL1  = io_lib:format(?SQL_GUILD_UPDATE_ADD_FUNDS, Data1),
    ?DEBUG("donate_money: SQL=[~s]", [SQL1]),
    db_sql:execute(SQL1),
    % 更新帮派成员表
    DonateMoneyRatio = data_guild:get_guild_config(donate_money_ratio, []),
    DonateAdd        = Num div DonateMoneyRatio,
    add_donation(PlayerId, DonateAdd).
    
% -----------------------------------------------------------------
%% 捐献帮派建设卡
%% @return 未升级：[0, 新帮派建设值]
%%          升级  ：[1, 新成员上限, 新级别, 新帮派建设值(0), 新每日建设值, 新帮派建设上限, 新自动解散标志位(0)]
%%          出错  ：error
%% -----------------------------------------------------------------
donate_contribution_card(PlayerId, GuildId, Num, Level, Contribution, ContributionThreshold) ->
    ?DEBUG("donate_contribution_card: PlayerId=[~p], GuildId=[~p], Num=[~p], Level=[~p], Contribution=[~p], ContributionThreshold=[~p]", [PlayerId, GuildId, Num, Level, Contribution, ContributionThreshold]),
    % 更新帮派成员表
    DonateRatio = data_guild:get_guild_config(donate_contribution_card_ratio, []),
    DonateAdd   = Num * DonateRatio,
    case add_donation(PlayerId, DonateAdd) of
        ok ->
            % 更新帮派表
            ContributionRatio  = data_guild:get_guild_config(contribution_card_ratio, []),
            ContributionAdd    = Num * ContributionRatio,
            ContributionTotal  = Contribution + ContributionAdd,
            if  % 升级
            ContributionTotal >= ContributionThreshold ->
                    NewLevel = Level + 1,
                    [_NewMemberCapacityBase, NewMemberCapcity, _NewContributionCardNum, NewContributionThreshold, NewContributionDaily] = data_guild:get_level_info(NewLevel),
                    Data1 = [NewMemberCapcity, NewLevel, 0, NewContributionDaily, NewContributionThreshold, GuildId],
                    SQL1  = io_lib:format(?SQL_GUILD_UPDATE_GRADE, Data1),
                    ?DEBUG("donate_contribution_card: SQL=[~s]", [SQL1]),
                    db_sql:execute(SQL1),
                    [1, NewMemberCapcity, NewLevel, 0, NewContributionDaily, NewContributionThreshold, 0];
            true ->
                    Data1 = [ContributionAdd, GuildId],
                    SQL1  = io_lib:format(?SQL_GUILD_UPDATE_ADD_CONTRIBUTION, Data1),
                    ?DEBUG("donate_contribution_card: SQL=[~s]", [SQL1]),
                    db_sql:execute(SQL1),
                    [0, ContributionAdd]
            end;
       _ ->
           error
    end.

% -----------------------------------------------------------------
%% 增加帮贡
%% -----------------------------------------------------------------
add_donation(PlayerId, DonateAdd) ->
    % 查询贡献信息
    GuildMember = get_guild_member_by_player_id(PlayerId),
    if  % 帮派成员不存在
        GuildMember =:= [] ->
            ?ERR("add_donation: guild member not find ,id=[~p]", [PlayerId]),
            error;
        true ->
            [DonateTotal, DonateLastTime, DonateTotalLastWeek, DonateTotalLastdDay] =
                [GuildMember#ets_guild_member.donate_total, GuildMember#ets_guild_member.donate_lasttime, GuildMember#ets_guild_member.donate_total_lastweek, GuildMember#ets_guild_member.donate_total_lastday],
            DonateTime = util:unixtime(),
            SameDay    = is_same_date(DonateTime, DonateLastTime),
            SameWeek   = is_same_week(DonateTime, DonateLastTime),
            if  % 同一个星期且同一天
               (SameDay == true) ->
                    Data3 = [DonateTotal+DonateAdd, DonateTime, DonateTotalLastWeek+DonateAdd, DonateTotalLastdDay+DonateAdd, PlayerId],
                    SQL3  = io_lib:format(?SQL_GUILD_MEMBER_UPDATE_DONATE_INFO, Data3),
                    ?DEBUG("add_donation: SQL=[~s]", [SQL3]),
                    db_sql:execute(SQL3),
                    % 更新缓存
                    GuildMemberNew = GuildMember#ets_guild_member{donate_total          = DonateTotal+DonateAdd,
                                                                  donate_lasttime       = DonateTime,
                                                                  donate_total_lastweek = DonateTotalLastWeek+DonateAdd,
                                                                  donate_total_lastday  = DonateTotalLastdDay+DonateAdd},
                    update_guild_member(GuildMemberNew);
              % 同一个星期且不同天
              ((SameWeek == true) and (SameDay == false)) ->
                    Data3 = [DonateTotal+DonateAdd, DonateTime, DonateTotalLastWeek+DonateAdd, DonateAdd, PlayerId],
                    SQL3  = io_lib:format(?SQL_GUILD_MEMBER_UPDATE_DONATE_INFO, Data3),
                    ?DEBUG("add_donation: SQL=[~s]", [SQL3]),
                    db_sql:execute(SQL3),
                    % 更新缓存
                    GuildMemberNew = GuildMember#ets_guild_member{donate_total          = DonateTotal+DonateAdd,
                                                                  donate_lasttime       = DonateTime,
                                                                  donate_total_lastweek = DonateTotalLastWeek+DonateAdd,
                                                                  donate_total_lastday  = DonateAdd},
                    update_guild_member(GuildMemberNew);
              % 不同一个星期且不同天
              (SameWeek == false) ->
                    Data3 = [DonateTotal+DonateAdd, DonateTime, DonateAdd, DonateAdd, PlayerId],
                    SQL3  = io_lib:format(?SQL_GUILD_MEMBER_UPDATE_DONATE_INFO, Data3),
                    ?DEBUG("add_donation: SQL=[~s]", [SQL3]),
                    db_sql:execute(SQL3),
                    % 更新缓存
                    GuildMemberNew = GuildMember#ets_guild_member{donate_total          = DonateTotal+DonateAdd,
                                                                  donate_lasttime       = DonateTime,
                                                                  donate_total_lastweek = DonateAdd,
                                                                  donate_total_lastday  = DonateAdd},
                    update_guild_member(GuildMemberNew);
               true ->
                    void
           end
    end,
    ok.
    
%% -----------------------------------------------------------------
%% 获取捐献列表
%% -----------------------------------------------------------------
get_donate_page(GuildId, PageSize, PageNo) ->
    ?DEBUG("get_donate_page: GuildId=[~p], PageSize=[~p], PageNo=[~p]", [GuildId, PageSize, PageNo]),
    % 获取总记录数
    GuildMembers = get_guild_member_by_guild_id(GuildId),
    RecordTotal  = length(GuildMembers),
    % 计算分页
    {PageTotal, StartPos, RecordNum} = calc_page_cache(RecordTotal, PageSize, PageNo),
    ?DEBUG("get_donate_page: PageTotal=[~p], StartPos=[~p], RecordNum=[~p]", [PageTotal, StartPos, RecordNum]),
    % 获取分页
    RowsPage = RowsPage = lists:sublist(GuildMembers, StartPos, PageSize),
    % 处理分页
    Records = lists:map(fun handle_donate_page/1, RowsPage),
    % 发送回应
    [1, PageTotal, PageNo, RecordNum, list_to_binary(Records)].

handle_donate_page(GuildMember) ->
    [PlayerId, PalyerName, PlayerLevel, GuildPosition, DonateLastTime, DonateTotal, DonateTotalLastWeek, DonateTotalLastDay] =
        [GuildMember#ets_guild_member.player_id, GuildMember#ets_guild_member.player_name, GuildMember#ets_guild_member.level, GuildMember#ets_guild_member.position, GuildMember#ets_guild_member.donate_lasttime, GuildMember#ets_guild_member.donate_total, GuildMember#ets_guild_member.donate_total_lastweek, GuildMember#ets_guild_member.donate_total_lastday],
    PlayerNameLen = byte_size(PalyerName),
    NowTime       = util:unixtime(),
    SameDay       = is_same_date(NowTime, DonateLastTime),
    SameWeek      = is_same_week(NowTime, DonateLastTime),
    if  % 同一个星期且同一天
        (SameDay == true) ->
            <<PlayerId:32, PlayerNameLen:16, PalyerName/binary, PlayerLevel:16, GuildPosition:16, DonateTotal:32, DonateTotalLastWeek:32, DonateTotalLastDay:32>>;
        % 同一个星期且不同天
        ((SameWeek == true) and (SameDay == false)) ->
            <<PlayerId:32, PlayerNameLen:16, PalyerName/binary, PlayerLevel:16, GuildPosition:16, DonateTotal:32, DonateTotalLastWeek:32, 0:32>>;
        % 不同一个星期且不同天
        (SameWeek == false) ->
             <<PlayerId:32, PlayerNameLen:16, PalyerName/binary, PlayerLevel:16, GuildPosition:16, DonateTotal:32, 0:32, 0:32>>;
        true ->
             <<PlayerId:32, PlayerNameLen:16, PalyerName/binary, PlayerLevel:16, GuildPosition:16, DonateTotal:32, 0:32, 0:32>>
    end.

%% -----------------------------------------------------------------
%% 获取日福利
%% -----------------------------------------------------------------
get_paid(PlayerId, PaidDaily, NowTime) ->
    ?DEBUG("get_paid: PlayerId=[~p], PaidDaily=[~p], NowTime=[~p]", [PlayerId, PaidDaily, NowTime]),
    % 更新角色表
    Data = [PaidDaily, PlayerId],
    SQL  = io_lib:format(?SQL_PLAYER_UPDATE_ADD_COIN, Data),
    ?DEBUG("get_paid: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    % 更新帮派成员表
    Data1 = [NowTime, PlayerId],
    SQL1  = io_lib:format(?SQL_GUILD_MEMBER_UPDATE_PAID, Data1),
    ?DEBUG("get_paid: SQL=[~s]", [SQL1]),
    db_sql:execute(SQL1),
    ok.

%% -----------------------------------------------------------------
%% 获取成员信息
%% -----------------------------------------------------------------
get_member_info(GuildId, PlayerId) ->
    ?DEBUG("get_member_info: GuildId=[~p], PlayerId=[~p]", [GuildId, PlayerId]),
    % 获取帮派等级
    Guild = get_guild(GuildId),
    if  % 帮派不存在
        Guild =:= [] ->
            [2, <<>>];
        true ->
            GuildLevel = Guild#ets_guild.level,
            % 获取成员信息
            GuildMember = get_guild_member_by_player_id(PlayerId),
            if  % 帮派不存在该成员
                GuildMember =:= [] -> [3, <<>>];
                true ->           
                    [Id, Nickname, _Jobs, Lv, GuildPosition, DonateTotal, DonateTotalLastWeek, DonateTotalLastDay, Title, Remark, Honor, Career] =
                        [GuildMember#ets_guild_member.player_id, GuildMember#ets_guild_member.player_name, GuildMember#ets_guild_member.jobs, GuildMember#ets_guild_member.level, GuildMember#ets_guild_member.position, GuildMember#ets_guild_member.donate_total, GuildMember#ets_guild_member.donate_total_lastweek, GuildMember#ets_guild_member.donate_total_lastday, GuildMember#ets_guild_member.title, GuildMember#ets_guild_member.remark, GuildMember#ets_guild_member.honor, GuildMember#ets_guild_member.career],
                    NicknameLen     = byte_size(Nickname),
                    TitleLen        = byte_size(Title),
                    RemarkLen       = byte_size(Remark),
                    PaidDaily       = data_guild:get_paid_daily(GuildLevel, GuildPosition),
                    [1, <<Id:32, NicknameLen:16, Nickname/binary, Career:16, Lv:16, GuildPosition:16, DonateTotal:32, DonateTotalLastWeek:32, DonateTotalLastDay:32, PaidDaily:32, TitleLen:16, Title/binary, RemarkLen:16, Remark/binary, Honor:32>>]
            end
    end.

%% -----------------------------------------------------------------
%% 授予头衔
%% -----------------------------------------------------------------
give_title(PlayerId, Title) ->
    ?DEBUG("give_tile: PlayerId=[~p], Title=[~s]", [PlayerId, Title]),
    % 更新帮派成员表
    Data = [Title, PlayerId],
    SQL  = io_lib:format(?SQL_PLAYER_MEMBER_UPDATE_TITLE, Data),
    ?DEBUG("give_tile: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    ok.

%% -----------------------------------------------------------------
%% 修改个人备注
%% -----------------------------------------------------------------
modify_remark(PlayerId, Remark) ->
    ?DEBUG("modify_remark: PlayerId=[~p], Remark=[~s]", [PlayerId, Remark]),
    % 更新帮派成员表
    Data = [Remark, PlayerId],
    SQL  = io_lib:format(?SQL_PLAYER_MEMBER_UPDATE_REMARK, Data),
    ?DEBUG("modify_remark: SQL=[~s]", [SQL]),
    db_sql:execute(SQL),
    ok.

%% -----------------------------------------------------------------
%% 计算收取的每日建设
%% -----------------------------------------------------------------
calc_contribution_daily(NowTime, ContributionGetNextTime, Contribution, ContributionDaily, ContributionThreshold, Level, DisbandDeadlineTime, MemberCapcaity) ->
    {_Today, NextDay} = get_midnight_seconds(NowTime),
    ?DEBUG("calc_contribution_daily: NowTime=[~p], NextDay=[~p], ContributionGetNextTime=[~p], Contribution=[~p], ContributionDaily=[~p]", [NowTime, NextDay, ContributionGetNextTime, Contribution, ContributionDaily]),
    if  % 小于第二天凌晨的应该收取
        ContributionGetNextTime =< NextDay ->
            DiffDays = get_diff_days(ContributionGetNextTime, NowTime),
            ContributionTotal = ContributionDaily*DiffDays,
            case Contribution >= ContributionDaily of
                % 正常收取每日建设
                % (1) 扣取每日建设
                % (2) 更新每日建设下次收取时间
                true  ->
                    [1, Contribution - ContributionTotal, NowTime+(?ONE_DAY_SECONDS), ContributionDaily, ContributionThreshold, Level, DisbandDeadlineTime, MemberCapcaity];
                % 每日建设不够收取导致正常降级
                % (1) 建设值变为上一级上限，然后按上一级标准扣取每日建设
                % (2) 更新每日建设下次收取时间
                % (3) 级别、每日建设、建设上限、最大成员数变为上一级标准
                % (4) 自动解散时间置为0
                false when Level >= 2 ->
                    [_MemberCapacityBaseConfig, MemberCapacityConfig, _ContributionCardNumConfig, ContributionThresholdConfig, ContributionDailyConfig] = data_guild:get_level_info(Level-1),
                    [2, ContributionThresholdConfig-ContributionDailyConfig, NowTime+(?ONE_DAY_SECONDS), ContributionDailyConfig, ContributionThresholdConfig, Level-1, 0, MemberCapacityConfig];
                % 每日建设不够收取导致解散且之前没有处理过
                % (1) 扣取每日建设
                % (2) 更新每日建设下次收取时间
                % (3) 自动解散时间置为3天后
                false when Level == 1 andalso DisbandDeadlineTime == 0 ->
                    DelayDay = data_guild:get_guild_config(disband_lv0_delay_day, []),
                    [3, Contribution - ContributionTotal, NowTime+(?ONE_DAY_SECONDS), ContributionDaily, ContributionThreshold, Level, NowTime+DelayDay*(?ONE_DAY_SECONDS), MemberCapcaity];
                % 每日建设不够收取导致解散且之前已处理过
                % (1) 扣取每日建设
                % (2) 更新每日建设下次收取时间
                false when Level == 1 andalso DisbandDeadlineTime /= 0 ->
                    [4, Contribution - ContributionTotal, NowTime+(?ONE_DAY_SECONDS), ContributionDaily, ContributionThreshold, Level, DisbandDeadlineTime, MemberCapcaity]
            end;
        % 不应该收取
        true ->
            [0, Contribution, ContributionGetNextTime, ContributionDaily, ContributionThreshold, Level, DisbandDeadlineTime, MemberCapcaity]
    end.

%%=========================================================================
%% 邮件服务
%%=========================================================================
send_mail(SubjectType, Param) ->
    [NameListNew, TitleNew, ContentNew] = case SubjectType of
                  guild_apply_disband ->
                      [_PlayerId, _PlayerName, GuildId, GuildName] = Param,
                      NameList  = get_member_name_list(GuildId),
                      Title     = "帮派被申请解散",
                      Content   = io_lib:format("你的帮派【~s】被帮主申请解散。", [GuildName]),
                      [NameList, Title, Content];
                  guild_cancel_disband ->
                      [_PlayerId, _PlayerName, GuildId, GuildName] = Param,
                      NameList  = get_member_name_list(GuildId),
                      Title     = "帮派解散被取消",
                      Content   = io_lib:format("你的帮派【~s】被帮主取消解散。", [GuildName]),
                      [NameList, Title, Content];
                  guild_disband ->
                      [_GuildId, GuildName, MemberNameList] = Param,
                      %NameList  = get_member_name_list(GuildId),
                      NameList  = MemberNameList,
                      Title     = "帮派已解散",
                      Content   = io_lib:format("你的帮派【~s】已正式解散。", [GuildName]),
                      [NameList, Title, Content];
                  guild_auto_disband ->
                      [GuildId, GuildName, ExpiredDay] = Param,
                      NameList  = get_member_name_list(GuildId),
                      Title     = "帮派面临解散",
                      Content   = io_lib:format("你的帮派【~s】不够收取每日建设，【~p】天内再不升级，会被自动解散。", [GuildName, ExpiredDay]),
                      [NameList, Title, Content];
%                  guild_apply_join ->
%                      [_PlayerId, PlayerName, GuildId, GuildName] = Param,
%                      NameList = get_official_name_list(GuildId, 3),
%                      Title    = "帮派加入申请",
%                      Content  = io_lib:format("玩家【~s】申请加入本帮派【~s】。", [PlayerName, GuildName]),
%                      [NameList, Title, Content];
                  guild_reject_apply ->
                      [_PlayerId, PlayerName, _GuildId, GuildName] = Param,
                      NameList = [PlayerName],
                      Title    = "帮派申请被拒绝",
                      Content  = io_lib:format("帮派【~s】拒绝了你的加入申请。", [GuildName]),
                      [NameList, Title, Content];
                  guild_new_member ->
                      [_PlayerId, PlayerName, _GuildId, GuildName] = Param,
                      NameList = [PlayerName] ,
                      Title    = "成功加入帮派",
                      Content  = io_lib:format("恭喜你成功加入了帮派【~s】。", [GuildName]),
                      [NameList, Title, Content];
%                  guild_invite_join ->
%                      [_PlayerId, PlayerName, _GuildId, GuildName] = Param,
%                      NameList = [PlayerName],
%                      Title   = "帮派邀请",
%                      Content = io_lib:format("你被邀请加入帮派【~s】。", [GuildName]),
%                      [NameList, Title, Content];
                  guild_kickout ->
                      [_PlayerId, PlayerName, _GuildId, GuildName] = Param,
                      NameList = [PlayerName],
                      Title   = "你被踢出帮派",
                      Content = io_lib:format("你被踢出了帮派【~s】。", [GuildName]),
                      [NameList, Title, Content]
              end,
    ?DEBUG("send_mail: send_sys_mail, NameListNew=~w, TitleNew=~s, ContentNew=~s", [NameListNew, TitleNew, ContentNew]),
    lib_mail:send_sys_mail(NameListNew, TitleNew, ContentNew, 0, 0, 0, 0).

get_member_name_list(GuildId) ->
    MemberList = get_guild_member_by_guild_id(GuildId),
    get_member_name_list_helper(MemberList, []).
get_member_name_list_helper([], NameList) ->
    NameList;
get_member_name_list_helper(MemberList, NameList) ->
    [Member|MemberLeft] = MemberList,
    get_member_name_list_helper(MemberLeft, NameList++[Member#ets_guild_member.player_name]).

get_official_name_list(GuildId, Position) ->
    ?DEBUG("get_official_name_list: GuildId=[~p], Position=[~s]", [GuildId, Position]),
    % 更新帮派成员表
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
%% 处理过期的解散申请
%% -----------------------------------------------------------------
handle_expired_disband() ->
    Guilds = get_guild_disband(),
    lists:map(fun handle_expired_disband/1, Guilds).

handle_expired_disband(Guild) ->
    ?DEBUG("handle_expired_disband: GuildId=[~p]", [Guild#ets_guild.id]),
    % 三天不确认则取消
    NowTime    = util:unixtime(),
    ExpiredDay = data_guild:get_guild_config(disband_expired_day, []),
    [GuildId, GuildName, DisbandFlag, DisbandConfirmTime] = [Guild#ets_guild.id, Guild#ets_guild.name, Guild#ets_guild.disband_flag, Guild#ets_guild.disband_confirm_time],
    case  DisbandFlag == 1 andalso NowTime > DisbandConfirmTime andalso get_diff_days(NowTime, DisbandConfirmTime) >= ExpiredDay  of
        true ->
            % 解散帮派
            confirm_disband_guild(GuildId, GuildName, 1),
            % 广播帮派成员
            send_guild(GuildId, 'guild_disband', [GuildId, GuildName]);
        false ->
            void
    end,
    ok.

%% -----------------------------------------------------------------
%% 清理掉级后需自动解散的帮派
%% -----------------------------------------------------------------
handle_auto_disband() ->
    Guilds = get_guild_lv0(),
    lists:map(fun handle_auto_disband/1, Guilds).

handle_auto_disband(Guild) ->
    ?DEBUG("handle_auto_disband: GuildId=[~p]", [Guild#ets_guild.id]),
    NowTime = util:unixtime(),
    [GuildId, GuildName, Level, DisbandDeadlineTime] = [Guild#ets_guild.id, Guild#ets_guild.name, Guild#ets_guild.level, Guild#ets_guild.disband_deadline_time],
    case  Level == 1 andalso  DisbandDeadlineTime > 0 andalso NowTime > DisbandDeadlineTime of
        true ->
            % 解散帮派
            confirm_disband_guild(GuildId, GuildName, 1),
            % 广播帮派成员
            send_guild(GuildId, 'guild_disband', [GuildId, GuildName]);
        false ->
            void
    end,
    ok.
    
%% -----------------------------------------------------------------
%% 收取日建设
%% -----------------------------------------------------------------
handle_daily_construction() ->
    Guilds = get_guild_all(),
    lists:map(fun handle_daily_construction/1, Guilds).

handle_daily_construction(Guild) ->
    ?DEBUG("handle_daily_construction: GuildId=[~p]", [Guild#ets_guild.id]),
    NowTime = util:unixtime(),
    [Id, Name, ContributionGetNextTime, Contribution, ContributionDaily, ContributionThreshold, Level, DisbandDeadlineTime, MemberCapacity] =
        [Guild#ets_guild.id, Guild#ets_guild.name, Guild#ets_guild.contribution_get_nexttime, Guild#ets_guild.contribution, Guild#ets_guild.contribution_daily, Guild#ets_guild.contribution_threshold, Guild#ets_guild.level, Guild#ets_guild.disband_deadline_time, Guild#ets_guild.member_capacity],
    [State, ContributionNew, ContributionGetNextTimeNew, ContributionDailyNew, ContributionThresholdNew, LevelNew, DisbandDeadlineTimeNew, MemberCapacityNew] =
        calc_contribution_daily(NowTime, ContributionGetNextTime, Contribution, ContributionDaily, ContributionThreshold, Level, DisbandDeadlineTime, MemberCapacity),
    if  % 如果收取了日建设
        (State > 0) ->
            % 更新数据库
            SQLData = [ContributionNew, ContributionGetNextTimeNew, ContributionDailyNew, ContributionThresholdNew, LevelNew, DisbandDeadlineTimeNew, MemberCapacityNew, Id],
            SQL = io_lib:format(?SQL_GUILD_UPDATE_INIT, SQLData),
            ?DEBUG("handle_daily_construction: SQL=[~s]", [SQL]),
            db_sql:execute(SQL),
            % 更新缓存
            GuildNew = Guild#ets_guild{contribution              = ContributionNew,
                                        contribution_get_nexttime = ContributionGetNextTimeNew,
                                        contribution_daily        = ContributionDailyNew,
                                        contribution_threshold    = ContributionThresholdNew,
                                        level                     = LevelNew,
                                        disband_deadline_time     = DisbandDeadlineTimeNew,
                                        member_capacity           = MemberCapacityNew},
            lib_guild:update_guild(GuildNew),
            if  % 帮派正常降级
                State == 2 ->
                    lib_guild:send_guild(Id, 'guild_degrade', [Id, Name, Level, LevelNew]);
                % 帮派掉级面临解散
                State == 3 ->
                    lib_guild:send_guild(Id, 'guild_auto_disband', [Id, Name]),
                    % 邮件通知给帮派成员
                    DelayDay = data_guild:get_guild_config(disband_lv0_delay_day, []),
                    mod_guild:send_guild_mail(guild_auto_disband, [Id, Name, DelayDay]);
                true ->
                    void
            end;
        true ->
            void
    end.

%%=========================================================================
%% 辅助函数
%%=========================================================================

%% -----------------------------------------------------------------
%% 确保字符串类型为二进制
%% -----------------------------------------------------------------
make_sure_binary(String) ->
    case is_binary(String) of
        true  -> String;
        false when is_list(String) -> list_to_binary(String);
        false -> 
            ?ERR("make_sure_binary: Error string=[~w]", [String]),
            String
    end.

%% -----------------------------------------------------------------
%% 发送消息给帮派所有成员
%% -----------------------------------------------------------------
send_guild(GuildId, MsgType, Bin) ->
    Pids = ets:match(?ETS_ONLINE, #ets_online{pid='$1', guild_id=GuildId, _='_'}),
    F = fun([P]) ->
        gen_server:cast(P, {MsgType, Bin})
    end,
    [F(Pid) || Pid <- Pids].

%% -----------------------------------------------------------------
%% 发送消息给帮派官员
%% -----------------------------------------------------------------
send_guild_official(0, _GuildId, _MsgType, _Bin) ->
    void;
send_guild_official(GuildPosition, GuildId, MsgType, Bin) ->
    Pids = ets:match(?ETS_ONLINE, #ets_online{pid='$1', guild_id=GuildId, guild_position=GuildPosition, _='_'}),
    F = fun([P]) ->
        gen_server:cast(P, {MsgType, Bin})
    end,
    [F(Pid) || Pid <- Pids],
    send_guild_official(GuildPosition-1, GuildId, MsgType, Bin).

%% -----------------------------------------------------------------
%% 发送消息给单个成员
%% -----------------------------------------------------------------
send_one(PlayerId, MsgType, Bin) ->
    Pids = ets:match(?ETS_ONLINE, #ets_online{pid='$1', id=PlayerId, _='_'}),
    F = fun([P]) ->
        gen_server:cast(P, {MsgType, Bin})
    end,
    [F(Pid) || Pid <- Pids].

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

%% -----------------------------------------------------------------
%% 计算分页（起始位置为1）
%% -----------------------------------------------------------------
calc_page_cache(RecordTotal, PageSize, PageNo) ->
    PageTotal = (RecordTotal+PageSize-1) div PageSize,
    StartPos = (PageNo - 1) * PageSize + 1,
    if
        ((PageNo > PageTotal) or (PageNo < 1)) ->
            {PageTotal, 1, 0};
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
    Record = ets:lookup(Table, Key),
    if  Record =:= [] ->
            [];
        true ->
            [R] = Record,
            R
    end.

lookup_all(Table, Key) ->
    ets:lookup(Table, Key).

match_one(Table, Pattern) ->
    Record = ets:match_object(Table, Pattern),
    if  Record =:= [] ->
            [];
        true ->
            [R] = Record,
            R
    end.

match_all(Table, Pattern) ->
    ets:match_object(Table, Pattern).

%% -----------------------------------------------------------------
%% 背包里的物品
%% -----------------------------------------------------------------
get_goods(GoodsId) ->
    match_one(?ETS_GOODS_ONLINE, #goods{id=GoodsId, location=4, _='_'}).

get_goods_type_by_type_info(GoodsType, GoodsSubType) ->
    match_one(?ETS_GOODS_TYPE, #ets_goods_type{type=GoodsType, subtype=GoodsSubType, _='_'}).

%% -----------------------------------------------------------------
%% 物品类型
%% -----------------------------------------------------------------
get_goods_type(GoodsId) ->
    lookup_one(?ETS_GOODS_TYPE,GoodsId).

%% -----------------------------------------------------------------
%% 帮派
%% -----------------------------------------------------------------
get_guild(GuildId) ->
    lookup_one(?ETS_GUILD, GuildId).

get_guild_all() ->
    match_all(?ETS_GUILD, #ets_guild{_='_'}).

get_guild_lv0() ->
    match_all(?ETS_GUILD, #ets_guild{level=1, _='_'}).

get_guild_disband() ->
    match_all(?ETS_GUILD, #ets_guild{disband_flag=1, _='_'}).

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

%% -----------------------------------------------------------------
%% 帮派成员
%% -----------------------------------------------------------------
get_guild_member(MemberId) ->
    lookup_one(?ETS_GUILD_MEMBER, MemberId).

get_guild_official(GuildId, Position) ->
    match_one(?ETS_GUILD_MEMBER, #ets_guild_member{guild_id=GuildId, position=Position, _='_'}).

get_guild_member_by_player_id(PlayerId) ->
    match_one(?ETS_GUILD_MEMBER, #ets_guild_member{player_id=PlayerId, _='_'}).

get_guild_member_by_guild_id(GuildId) ->
    match_all(?ETS_GUILD_MEMBER, #ets_guild_member{guild_id=GuildId, _='_'}).

update_guild_member(GuildMember) ->
    ets:insert(?ETS_GUILD_MEMBER, GuildMember).

delete_guild_member(MemberId) ->
    ets:delete(?ETS_GUILD_MEMBER, MemberId).

delete_guild_member_by_guild_id(GuildId) ->
    ets:match_delete(?ETS_GUILD_MEMBER, #ets_guild_member{guild_id=GuildId, _='_'}).

delete_guild_member_by_player_id(PlayerId) ->
    ets:match_delete(?ETS_GUILD_MEMBER, #ets_guild_member{player_id=PlayerId, _='_'}).

%% -----------------------------------------------------------------
%% 帮派申请
%% -----------------------------------------------------------------
get_guild_apply_by_player_id(PlayerId, GuildId) ->
    match_all(?ETS_GUILD_APPLY, #ets_guild_apply{player_id=PlayerId, guild_id=GuildId, _='_'}).

get_guild_apply_by_player_id(PlayerId) ->
    match_one(?ETS_GUILD_APPLY, #ets_guild_apply{player_id=PlayerId, _='_'}).

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

%% -----------------------------------------------------------------
%% 帮派邀请
%% -----------------------------------------------------------------
get_guild_invite_by_player_id(PlayerId, GuildId) ->
    match_all(?ETS_GUILD_INVITE, #ets_guild_invite{player_id=PlayerId, guild_id=GuildId, _='_'}).

get_guild_invite_by_player_id(PlayerId) ->
    match_one(?ETS_GUILD_INVITE, #ets_guild_invite{player_id=PlayerId, _='_'}).

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

%%=========================================================================
%% 数据库操作函数
%%=========================================================================

get_player_guild_info(PlayerId) ->
    Data = [PlayerId],
    SQL  = io_lib:format(?SQL_PLAYER_SELECT_GUILD_INFO1, Data),
    ?DEBUG("get_player_guild_info: SQL=[~s]", [SQL]),
    db_sql:get_row(SQL).

get_player_guild_info_by_name(PlayerNickname) ->
    Data = [PlayerNickname],
    SQL  = io_lib:format(?SQL_PLAYER_SELECT_GUILD_INFO2, Data),
    ?DEBUG("get_player_guild_info_by_name: SQL=[~s]", [SQL]),
    db_sql:get_row(SQL).

