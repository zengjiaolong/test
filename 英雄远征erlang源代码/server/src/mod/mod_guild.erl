%%%------------------------------------
%%% @Module  : mod_guild
%%% @Author  : shebiao
%%% @Email   : shebiao@jieyou.com
%%% @Created : 2010.06.24
%%% @Description: 帮派处理
%%%------------------------------------
-module(mod_guild).
-behaviour(gen_server).
-include("common.hrl").
-include("record.hrl").
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-compile(export_all).

%%=========================================================================
%% 一些定义
%%=========================================================================
-record(state, {interval = 0}).

%%=========================================================================
%% 接口函数
%%=========================================================================
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

stop() ->
    gen_server:call(?MODULE, stop).

handle_expired_disband() ->
    gen_server:cast(?MODULE, 'handle_expired_disband').

handle_auto_disband() ->
    gen_server:cast(?MODULE, 'handle_auto_disband').

handle_daily_construction() ->
    gen_server:cast(?MODULE, 'handle_daily_construction').

send_guild_mail(SubjectType, Param) ->
    gen_server:cast(?MODULE, {'send_mail', SubjectType, Param}).

%%=========================================================================
%% 回调函数
%%=========================================================================
init([]) ->
    process_flag(trap_exit, true),
    Timeout = 60000,
    State = #state{interval = Timeout},
    ?DEBUG("init: loading guild....", []),
    lib_guild:load_all_guild(),
    {ok, State}.

handle_call(_Request, _From, State) ->
    {reply, State, State}.

%% -----------------------------------------------------------------
%% 处理过期的解散申请
%% -----------------------------------------------------------------
handle_cast('handle_expired_disband', State) ->
    ?DEBUG("handle_case: msg_type=[~p]", ['handle_expired_disband']),
    lib_guild:handle_expired_disband(),
    {noreply, State};

%% -----------------------------------------------------------------
%% 处理掉级导致的自动解散
%% -----------------------------------------------------------------
handle_cast('handle_auto_disband', State) ->
    ?DEBUG("handle_case: msg_type=[~p]", ['handle_auto_disband']),
    lib_guild:handle_auto_disband(),
    {noreply, State};

%% -----------------------------------------------------------------
%% 收取日建设
%% -----------------------------------------------------------------
handle_cast('handle_daily_construction', State) ->
    ?DEBUG("handle_case: msg_type=[~p]", ['handle_daily_construction']),
    lib_guild:handle_daily_construction(),
    {noreply, State};

%% -----------------------------------------------------------------
%% 发送帮派邮件
%% -----------------------------------------------------------------
handle_cast({'send_mail', SubjectType, Param}, State) ->
    ?DEBUG("handle_case: msg_type=[~p], SubjectType=[~p], Param=[~p]", ['send_mail', SubjectType, Param]),
    lib_guild:send_mail(SubjectType, Param),
    {noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%=========================================================================
%% 业务处理函数
%%=========================================================================

%% -----------------------------------------------------------------
%% 创建帮派
%% -----------------------------------------------------------------
create_guild(Status, [GuildName, GuildTenet]) ->
    ?DEBUG("create_guild: GuildName=[~s], GuildTenet=[~s]", [GuildName, GuildTenet]),
    if  % 你已经拥有帮派
        Status#player_status.guild_id /= 0 -> [2, 0, 0];
        true ->
            CreateLevel  = data_guild:get_guild_config(create_level, []),
            if  % 你级别不够
                Status#player_status.lv < CreateLevel -> [3, 0, 0];
                true ->
                    CreateCoin = data_guild:get_guild_config(create_coin, []),
                    if  % 你铜币不够
                        Status#player_status.coin < CreateCoin -> [4, 0, 0];
                        true ->
                            [Type, SubType, CreateCardNum] = data_guild:get_guild_config(create_contribution_card, []),
                            GoodsType = lib_guild:get_goods_type_by_type_info(Type, SubType),
                            if  % 帮派建设卡类型信息不存在
                                GoodsType =:= [] ->
                                    ?DEBUG("create_guild: Faild to find goods type, type=[~p], subtype=[~p]", [Type, SubType]),
                                    [0, 0, 0];
                                true ->
                                    NewGuildName = lib_guild:make_sure_binary(GuildName),
                                    Guild = lib_guild:get_guild_by_name(NewGuildName),
                                    if  % 帮派名已存在
                                        Guild =/= [] -> [6, 0, 0];
                                        true ->
                                            case gen_server:call(Status#player_status.goods_pid, {'delete_more', GoodsType#ets_goods_type.goods_id, CreateCardNum}) of
                                                % 扣取物品成功
                                                1 ->
                                                    case lib_guild:create_guild(Status#player_status.id, Status#player_status.nickname, Status#player_status.realm, NewGuildName, GuildTenet, CreateCoin) of
                                                        {ok, GuildId} -> [1, GuildId, Status#player_status.coin-CreateCoin];
                                                        _ -> [0, 0, 0]
                                                    end;
                                                % 扣取物品失败
                                                0 ->
                                                    ?DEBUG("create_guild: Call goods module faild", []),
                                                    [0, 0, 0];
                                                % 物品数量不够
                                                _ ->
                                                    [5, 0, 0]
                                            end
                                    end
                            end
                    end
            end
    end.


%% -----------------------------------------------------------------
%% 申请解散帮派
%% -----------------------------------------------------------------
apply_disband_guild(Status, [GuildId]) ->
    ?DEBUG("apply_disband_guild: GuildId=[~p]", [GuildId]),
    Guild = lib_guild:get_guild(GuildId),
    if % 帮派不存在
       Guild =:= [] -> 2;
       true ->
           DisbandFlag = Guild#ets_guild.disband_flag,
           if  % 你尚未加入任何帮派
               Status#player_status.guild_id == 0 -> 3;
               % 你不是该帮派成员
               Status#player_status.guild_id /= GuildId -> 4;
               % 你无权解散该帮派
               Status#player_status.guild_position > 1 -> 5;
               % 你已经申请解散
               DisbandFlag == 1 -> 6;
               % 可以解散帮派
               true ->
                   case lib_guild:apply_disband_guild(GuildId) of
                        [ok, ConfirmTime]  ->
                            % 更新缓存
                            GuildNew = Guild#ets_guild{disband_flag         = 1,
                                                       disband_confirm_time = ConfirmTime},
                            lib_guild:update_guild(GuildNew),
                            1;
                        _   -> 0
                   end
            end
    end.

%% -----------------------------------------------------------------
%% 确认解散帮派
%% -----------------------------------------------------------------
confirm_disband_guild(Status, [GuildId, ConfirmResult]) ->
    ?DEBUG("confirm_disband_guild: GuildId=[~p], ConfirmResult=[~p]", [GuildId, ConfirmResult]),
    Guild = lib_guild:get_guild(GuildId),
    NowTime = util:unixtime(),
    if % 帮派不存在
       Guild =:= [] -> 2;
       true ->
           [DisbandFlag, DisbandConfirmTime] = [Guild#ets_guild.disband_flag, Guild#ets_guild.disband_confirm_time],
           if  % 你尚未加入任何帮派
               Status#player_status.guild_id == 0 -> 3;
               % 你不是该帮派成员
               Status#player_status.guild_id /= GuildId -> 4;
               % 你无权确认解散该帮派
               Status#player_status.guild_position > 1 -> 5;
               % 你未申请解散
               DisbandFlag == 0 -> 6;
               % 申请后3天才能确认
               NowTime < DisbandConfirmTime -> 7;
               % 可以解散帮派
               true ->
                   case lib_guild:confirm_disband_guild(Status#player_status.guild_id, Status#player_status.guild_name, ConfirmResult) of
                        ok  ->
                            if  % 取消解散
                                ConfirmResult == 0 ->
                                    % 更新缓存
                                    GuildNew = Guild#ets_guild{disband_flag         = 0,
                                                               disband_confirm_time = 0},
                                    lib_guild:update_guild(GuildNew);
                                true ->
                                    void
                            end,
                            1;
                        _   -> 0
                   end
            end
    end.

%% -----------------------------------------------------------------
%% 申请加入帮派
%% -----------------------------------------------------------------
apply_join_guild(Status, [GuildId]) ->
    ?DEBUG("apply_join_guild: GuildId=[~p]", [GuildId]),
    Guild = lib_guild:get_guild(GuildId),
    if  % 帮派不存在
        Guild =:= [] -> [2, <<>>];
        true ->
            [GuildRealm, GuildName, GuildMemberNum, GuildMemberCapacity] = [Guild#ets_guild.realm, Guild#ets_guild.name, Guild#ets_guild.member_num, Guild#ets_guild.member_capacity],
            if  % 你已经加入帮派
                Status#player_status.guild_id /= 0 -> [3, <<>>];
                % 阵营不同
                Status#player_status.realm /= GuildRealm -> [4, <<>>];
                % 帮众数已满
                GuildMemberNum >=  GuildMemberCapacity -> [5, <<>>];
                true ->
                    GuildApply = lib_guild:get_guild_apply_by_player_id(Status#player_status.id, GuildId),
                    if  % 你已经申请加入该帮派
                        GuildApply =/= [] -> [6, <<>>];
                        true ->
                            case lib_guild:add_guild_apply(Status#player_status.id, GuildId) of
                                ok  -> [1, GuildName];
                                _   -> [0, <<>>]
                            end
                    end
            end
    end.

% -----------------------------------------------------------------
% 审批申请加入帮派
% -----------------------------------------------------------------
handle_apply_guild(Status, [PlayerId, HandleResult]) ->
    ?DEBUG("handle_apply_guild: PlayerId=[~p], HandleResult=[~p]", [PlayerId, HandleResult]),
    if   % 你没有加入任何帮派
         Status#player_status.guild_id == 0 -> [2, <<>>, 0];
         % 你无权批准(帮主,副帮和长老可以)
         Status#player_status.guild_position > 3 -> [3, <<>>, 0];
         true ->
             PlayerInfo = lib_guild:get_player_guild_info(PlayerId),
             Guild = lib_guild:get_guild(Status#player_status.guild_id),
             if  % 对方玩家不存在
                 PlayerInfo =:= [] -> [4, <<>>, 0];
                 % 帮派数据缺失
                 Guild =:= []  ->
                     ?ERR("handle_apply_guild: guild not found, id=[~p]", [Status#player_status.guild_id]),
                     [0, <<>>, 0];
                 true ->
                     [PlayerNickname, _PlayerRealm, PlayerGuildId, _PlayerGuildName, _PlayerGuildPosition] = PlayerInfo,
                     [GuildMemberNum, GuildMemberCapacity] = [Guild#ets_guild.member_num, Guild#ets_guild.member_capacity],
                     GuildApply = lib_guild:get_guild_apply_by_player_id(PlayerId, Status#player_status.guild_id),
                     if  % 不在申请列表
                         GuildApply =:= [] -> [5, <<>>, 0];
                         true ->
                             if  % 允许加入但已拥有帮派
                                 ((PlayerGuildId /= 0) and (HandleResult == 1)) ->
                                     [6, <<>>, 0];
                                 % 允许加入但帮众数已满
                                 ((GuildMemberNum >=  GuildMemberCapacity) and (HandleResult == 1)) ->
                                     [7, <<>>, 0];
                                 % 拒绝加入
                                 HandleResult == 0 ->
                                     % 从申请列表中删除
                                     case lib_guild:remove_guild_apply(PlayerId, Status#player_status.guild_id) of
                                         ok -> [1, PlayerNickname, 0];
                                         _  -> [0, <<>>, 0]
                                     end;
                                 % 允许加入
                                 true ->
                                     % 添加新成员并成列表中删除
                                     DefaultPostion = data_guild:get_guild_config(default_position, []),
                                     case lib_guild:add_guild_member(PlayerId, PlayerNickname, Status#player_status.guild_id, Status#player_status.guild_name, DefaultPostion) of
                                         ok ->
                                             % 更新缓存
                                             GuildNew = Guild#ets_guild{member_num = GuildMemberNum+1},
                                             lib_guild:update_guild(GuildNew),
                                             % 发送通知
                                             lib_guild:send_one(PlayerId, 'guild_new_member', [PlayerId, PlayerNickname, Status#player_status.guild_id, Status#player_status.guild_name, DefaultPostion]),
                                             [1, PlayerNickname, DefaultPostion];
                                         _  ->
                                             [0, <<>>, 0]
                                     end                                     
                             end
                     end
             end
    end.

%% -----------------------------------------------------------------
%% 邀请加入帮派
%% -----------------------------------------------------------------
invite_join_guild(Status, [PlayerName]) ->
    ?DEBUG("invite_join_guild: PlayerNickname=[~p]", [PlayerName]),
    if   % 你没有加入任何帮派
         Status#player_status.guild_id == 0 -> [2, 0];
         % 你无权邀请(帮主和副帮主可以)
         Status#player_status.guild_position > 2 -> [3, 0];
         true ->
             PlayerInfo = lib_guild:get_player_guild_info_by_name(PlayerName),
             Guild = lib_guild:get_guild(Status#player_status.guild_id),
             if  % 对方玩家不存在
                 PlayerInfo =:= [] -> [4, 0];
                 % 帮派数据缺失
                 Guild =:= []  ->
                     ?ERR("invite_join_guild: guild not found, id=[~p]", [Status#player_status.guild_id]),
                     [0, 0];
                 true ->
                     [PlayerId, PlayerRealm, PlayerGuildId, _PlayerGuildName, _PlayerGuildPosition] = PlayerInfo,
                     [GuildMemberNum, GuildMemberCapacity] = [Guild#ets_guild.member_num, Guild#ets_guild.member_capacity],
                     if  % 对方已经拥有帮派
                         PlayerGuildId /= 0 -> [5, 0];
                         % 阵营不同
                         PlayerRealm /= Status#player_status.realm -> [6, 0];
                         % 帮众数已满
                         GuildMemberNum >=  GuildMemberCapacity -> [7, 0];
                         true ->
                             GuildInvite = lib_guild:get_guild_invite_by_player_id(PlayerId, Status#player_status.guild_id),
                             if  % 已邀请过
                                 GuildInvite =/= [] -> [8, 0];
                                 % 可以邀请
                                 true ->
                                     case lib_guild:add_guild_invite(PlayerId, Status#player_status.guild_id) of
                                         ok  -> [1, PlayerId];
                                         _   -> [0, 0]
                                     end
                             end
                     end
             end
    end.

%% -----------------------------------------------------------------
%% 回应帮派邀请
%% -----------------------------------------------------------------
response_invite_guild(Status, [GuildId, ResponseResult]) ->
    ?DEBUG("response_invite_guild: GuildId=[~p], ResponseResult=[~p]", [GuildId, ResponseResult]),
    Guild = lib_guild:get_guild(GuildId),
    if  % 帮派不存在
        Guild =:= [] -> [2, <<>>, 0];
        true ->
            [GuildName, GuildMemberNum, GuildMemberCapacity] = [Guild#ets_guild.name, Guild#ets_guild.member_num, Guild#ets_guild.member_capacity],
            GuildInvite = lib_guild:get_guild_invite_by_player_id(Status#player_status.id, GuildId),
            if  % 你不在邀请列表
                GuildInvite =:= [] -> [3, <<>>, 0];
                % 同意加入但已经拥有帮派
                ((Status#player_status.guild_id /= 0) and (ResponseResult == 1)) -> [4, <<>>, 0];
                % 同意加入但帮众数已满
                ((GuildMemberNum >= GuildMemberCapacity) and (ResponseResult == 1)) -> [5, <<>>, 0];
                % 拒绝加入
                ResponseResult == 0 ->
                    % 从邀请列表中删除
                    case lib_guild:remove_guild_invite(Status#player_status.id, GuildId) of
                         ok -> [1, <<>>, 0];
                         _  -> [0, <<>>, 0]
                    end;
                % 允许加入
                true ->
                    DefaultPostion = data_guild:get_guild_config(default_position, []),
                    case lib_guild:add_guild_member(Status#player_status.id, Status#player_status.nickname, GuildId, GuildName, DefaultPostion) of
                        ok ->
                            % 更新缓存
                            GuildNew = Guild#ets_guild{member_num = GuildMemberNum+1},
                            lib_guild:update_guild(GuildNew),
                            % 发送通知
                            lib_guild:send_one(Status#player_status.id, 'guild_new_member', [Status#player_status.id, Status#player_status.nickname, GuildId, GuildName, DefaultPostion]),
                            [1, GuildName, DefaultPostion];
                        _  -> [0, <<>>, 0]
                    end
            end
    end.

%% -----------------------------------------------------------------
%% 踢出帮派
%% -----------------------------------------------------------------
kickout_guild(Status, [PlayerId]) ->
    ?DEBUG("kickout_guild: PlayerId=[~p]", [PlayerId]),
    if   % 你没有加入任何帮派
         Status#player_status.guild_id == 0 -> [2, <<>>];
         % 你没有踢出权限(帮主,副帮主和长老可以踢出)
         Status#player_status.guild_position > 3 -> [3, <<>>];
         % 不能踢出自己
         PlayerId == Status#player_status.id -> [4, <<>>];
         true ->
             PlayerInfo = lib_guild:get_player_guild_info(PlayerId),
             Guild      = lib_guild:get_guild(Status#player_status.guild_id),
             if  % 对方玩家不存在
                 PlayerInfo =:= [] -> [5, <<>>];
                 % 帮派数据缺失
                 Guild =:= []  ->
                     ?ERR("kickout_guild: guild not found, id=[~p]", [Status#player_status.guild_id]),
                     [0, <<>>];
                 true ->
                     [PlayerNickname, _PlayerRealm, PlayerGuildId, _PlayerGuildName, PlayerGuildPosition] = PlayerInfo,
                     [DeputyChiefId1, DeputyChiefId2, MemberNum, DeputyChiefNum] = [Guild#ets_guild.deputy_chief1_id, Guild#ets_guild.deputy_chief2_id, Guild#ets_guild.member_num, Guild#ets_guild.deputy_chief_num],
                     if  % 对方没有帮派
                         PlayerGuildId == 0 -> [6, <<>>];
                         % 对方不是本帮成员
                         PlayerGuildId /= Status#player_status.guild_id -> [7, <<>>];
                         % 对方职位不在你之下
                         PlayerGuildPosition =< Status#player_status.guild_position -> [8, <<>>];
                         % 可以踢出
                         true ->
                             case lib_guild:remove_guild_member(PlayerId, Status#player_status.guild_id, PlayerGuildPosition, DeputyChiefId1, DeputyChiefId2) of
                                 [ok, MemberType] ->
                                         % 更新缓存
                                         case MemberType of 
                                             0 ->
                                                 GuildNew = Guild#ets_guild{member_num = MemberNum-1},
                                                 lib_guild:update_guild(GuildNew);
                                             1 ->
                                                 GuildNew = Guild#ets_guild{member_num         = MemberNum-1,
                                                                            deputy_chief_num   = DeputyChiefNum -1,
                                                                            deputy_chief1_id   = 0,
                                                                            deputy_chief1_name = <<>>},
                                                 lib_guild:update_guild(GuildNew);
                                             2 ->
                                                 GuildNew = Guild#ets_guild{member_num         = MemberNum-1,
                                                                            deputy_chief_num   = DeputyChiefNum -1,
                                                                            deputy_chief2_id   = 0,
                                                                            deputy_chief2_name = <<>>},
                                                 lib_guild:update_guild(GuildNew)
                                         end,
                                         [1, PlayerNickname];
                                 _  ->
                                        [0, <<>>]
                             end
                     end
             end
    end.

%% -----------------------------------------------------------------
%% 退出帮派
%% -----------------------------------------------------------------
quit_guild(Status, [GuildId]) ->
    ?DEBUG("quit_guild: GuildId=[~p]", [GuildId]),
    Guild  = lib_guild:get_guild(GuildId),
    if  % 帮派不存在
        Guild =:= [] -> 2;
        true ->
            [DeputyChiefId1, DeputyChiefId2, MemberNum, DeputyChiefNum] = [Guild#ets_guild.deputy_chief1_id, Guild#ets_guild.deputy_chief2_id, Guild#ets_guild.member_num, Guild#ets_guild.deputy_chief_num],
            if  % 你尚未加入任何帮派
                Status#player_status.guild_id == 0 -> 3;
                % 你不是该帮派成员
                Status#player_status.guild_id /= GuildId -> 4;
                % 你拥有职位不能直接退出
                Status#player_status.guild_position < 5 -> 5;
                % 可以退出帮派
                true ->
                    case lib_guild:remove_guild_member(Status#player_status.id, Status#player_status.guild_id, Status#player_status.guild_position, DeputyChiefId1, DeputyChiefId2) of
                        [ok, MemberType] ->
                            % 更新缓存
                            case MemberType of 
                                0 ->
                                    GuildNew = Guild#ets_guild{member_num = MemberNum-1},
                                    lib_guild:update_guild(GuildNew);
                                1 ->
                                    GuildNew = Guild#ets_guild{member_num         = MemberNum-1,
                                                               deputy_chief_num   = DeputyChiefNum -1,
                                                               deputy_chief1_id   = 0,
                                                               deputy_chief1_name = <<>>},
                                    lib_guild:update_guild(GuildNew);
                                2 ->
                                    GuildNew = Guild#ets_guild{member_num         = MemberNum-1,
                                                               deputy_chief_num   = DeputyChiefNum -1,
                                                               deputy_chief2_id   = 0,
                                                               deputy_chief2_name = <<>>},
                                    lib_guild:update_guild(GuildNew)
                            end,
                            1;
                         _ -> 0
                    end
            end
    end.

%% -----------------------------------------------------------------
%% 获取帮派列表
%% -----------------------------------------------------------------
list_guild(_Status, [PageSize, PageNo]) ->
    ?DEBUG("list_guild: PageSize=[~p], PageNo=[~p]", [PageSize, PageNo]),
    lib_guild:get_guild_page(PageSize, PageNo).

%% -----------------------------------------------------------------
%% 获取成员列表
%% -----------------------------------------------------------------
list_guild_member(_Status, [GuildId, PageSize, PageNo]) ->
    ?DEBUG("list_guild_member: GuildId=[~p], PageSize=[~p], PageNo=[~p]", [GuildId, PageSize, PageNo]),
    lib_guild:get_guild_member_page(GuildId, PageSize, PageNo).

%% -----------------------------------------------------------------
%% 获取申请列表
%% -----------------------------------------------------------------
list_guild_apply(_Status, [GuildId, PageSize, PageNo]) ->
    ?DEBUG("list_guild_apply: GuildId=[~p], PageSize=[~p], PageNo=[~p]", [GuildId, PageSize, PageNo]),
    lib_guild:get_guild_apply_page(GuildId, PageSize, PageNo).

%% -----------------------------------------------------------------
%% 获取邀请列表
%% -----------------------------------------------------------------
list_guild_invite(_Status, [PlayerId, PageSize, PageNo]) ->
    ?DEBUG("list_guild_invite: PlayerId=[~p], PageSize=[~p], PageNo=[~p]", [PlayerId, PageSize, PageNo]),
    lib_guild:get_guild_invite_page(PlayerId, PageSize, PageNo).

%% -----------------------------------------------------------------
%% 获取本帮信息
%% -----------------------------------------------------------------
get_guild_info(_Status, [GuildId]) ->
    ?DEBUG("get_guild_info: GuildId=[~p]", [GuildId]),
    lib_guild:get_guild_info(GuildId).

%% -----------------------------------------------------------------
%% 修改帮派宗旨
%% -----------------------------------------------------------------
modify_guild_tenet(Status, [GuildId, Tenet]) ->
    ?DEBUG("modify_guild_tenet: GuildId=[~p], Tenet=[~s]", [GuildId, Tenet]),
    Guild = lib_guild:get_guild(GuildId),
    if  % 帮派不存在
        Guild =:= [] -> 2;
        true ->
            if  % 你没有加入任何帮派
                Status#player_status.guild_id == 0 -> 3;
                % 你不是该帮派成员
                Status#player_status.guild_id /= GuildId -> 4;
                % 你无权修改(帮主和副帮主可以)
                Status#player_status.guild_position > 2 -> 5;
                % 可以修改
                true ->
                    case lib_guild:modify_guild_tenet(GuildId, Tenet) of
                        ok  ->
                            % 更新缓存
                            TenetBin = lib_guild:make_sure_binary(Tenet),
                            GuildNew = Guild#ets_guild{tenet = TenetBin},
                            lib_guild:update_guild(GuildNew),
                            1;
                        _   -> 0
                    end
            end
    end.

%% -----------------------------------------------------------------
%% 修改帮派公告
%% -----------------------------------------------------------------
modify_guild_announce(Status, [GuildId, Announce]) ->
    ?DEBUG("modify_guild_tenet: GuildId=[~p], Announce=[~s]", [GuildId, Announce]),
    Guild = lib_guild:get_guild(GuildId),
    if  % 帮派不存在
        Guild =:= [] -> 2;
        true ->
            if  % 你没有加入任何帮派
                Status#player_status.guild_id == 0 -> 3;
                % 你不是该帮派成员
                Status#player_status.guild_id /= GuildId -> 4;
                % 你无权修改(帮主和副帮主可以)
                Status#player_status.guild_position > 2 -> 5;
                % 可以修改
                true ->
                    case lib_guild:modify_guild_announce(GuildId, Announce) of
                        ok  ->
                            % 更新缓存
                            AnnounceBin = lib_guild:make_sure_binary(Announce),
                            GuildNew = Guild#ets_guild{announce = AnnounceBin},
                            lib_guild:update_guild(GuildNew),
                            1;
                        _   -> 0
                    end
            end
    end.

%% -----------------------------------------------------------------
%% 职位设置
%% -----------------------------------------------------------------
set_position(Status, [PlayerId, GuildPosition]) ->
    ?DEBUG("set_position: PlayerId=[~p], GuildPosition=[~p]", [PlayerId, GuildPosition]),
    if   % 你没有加入任何帮派
         Status#player_status.guild_id == 0 -> [2, <<>>, 0];
         % 你无权设置(帮主和副帮主可以)
         Status#player_status.guild_position > 2 -> [3, <<>>, 0];
         % 不能自封职位
         PlayerId == Status#player_status.id  -> [4, <<>>, 0];
         % 你要设置的职位不比你的低
         GuildPosition =< Status#player_status.guild_position -> [5, <<>>, 0];
         true ->
             PlayerInfo = lib_guild:get_player_guild_info(PlayerId),
             Guild = lib_guild:get_guild(Status#player_status.guild_id),
             if  % 对方玩家不存在
                 PlayerInfo =:= [] -> [6, <<>>, 0];
                 % 帮派数据缺失
                 Guild =:= []  ->
                     ?ERR("set_position: guild not found, id=[~p]", [Status#player_status.guild_id]),
                     [0, <<>>, 0];
                 true ->
                     [PlayerNickname, _PlayerRealm, PlayerGuildId, _PlayerGuildName, PlayerGuildPosition] = PlayerInfo,
                     [DeputyChiefId1, DeputyChiefId2, DeputyChiefNum] = [Guild#ets_guild.deputy_chief1_id, Guild#ets_guild.deputy_chief2_id, Guild#ets_guild.deputy_chief_num],
                     if  % 对方没有帮派
                         PlayerGuildId == 0 -> [7, <<>>, 0];
                         % 对方不是本帮成员
                         PlayerGuildId /= Status#player_status.guild_id -> [8, <<>>, 0];
                         % 对方职位不比你低
                         PlayerGuildPosition =< Status#player_status.guild_position -> [9, <<>>, 0];
                         % 副帮主个数已满
                         ((PlayerGuildPosition > GuildPosition) and (GuildPosition == 2) and (DeputyChiefNum == 2)) -> [10, <<>>, 0];
                         % 职位没有改变
                         PlayerGuildPosition == GuildPosition -> [1, PlayerNickname, PlayerGuildPosition];
                         % 可以设置
                         true ->
                             case lib_guild:set_position(PlayerId, PlayerNickname, Status#player_status.guild_id, GuildPosition, DeputyChiefId1, DeputyChiefId2) of
                                 [ok, MemberType]  ->
                                     % 更新缓存
                                     case MemberType of 
                                         0 ->
                                            void;
                                         1 ->
                                             GuildNew = Guild#ets_guild{deputy_chief_num   = DeputyChiefNum-1,
                                                                        deputy_chief1_id   = 0,
                                                                        deputy_chief1_name = <<>>},
                                             lib_guild:update_guild(GuildNew);
                                         2 ->
                                             GuildNew = Guild#ets_guild{deputy_chief_num   = DeputyChiefNum-1,
                                                                        deputy_chief2_id   = 0,
                                                                        deputy_chief2_name = <<>>},
                                             lib_guild:update_guild(GuildNew);
                                         3 ->
                                             GuildNew = Guild#ets_guild{deputy_chief_num   = DeputyChiefNum+1,
                                                                        deputy_chief1_id   = PlayerId,
                                                                        deputy_chief1_name = PlayerNickname},
                                             lib_guild:update_guild(GuildNew);
                                         4 ->
                                             GuildNew = Guild#ets_guild{deputy_chief_num   = DeputyChiefNum+1,
                                                                        deputy_chief2_id   = PlayerId,
                                                                        deputy_chief2_name = PlayerNickname},
                                             lib_guild:update_guild(GuildNew)
                                     end,
                                     [1, PlayerNickname, PlayerGuildPosition];
                                 _  -> [0, <<>>, 0]
                             end
                     end
             end
    end.

%% -----------------------------------------------------------------
%% 禅让帮主
%% -----------------------------------------------------------------
demise_chief(Status, [PlayerId]) ->
    ?DEBUG("demise_chief: PlayerId=[~p]", [PlayerId]),
    if   % 你没有加入任何帮派
         Status#player_status.guild_id == 0 -> [2, <<>>];
         % 你不是帮主
         Status#player_status.guild_position /= 1 -> [3, <<>>];
         % 不能禅让给自己
         PlayerId == Status#player_status.id  -> [4, <<>>];
         true ->
             PlayerInfo = lib_guild:get_player_guild_info(PlayerId),
             Guild      = lib_guild:get_guild(Status#player_status.guild_id),
             if  % 对方玩家不存在
                 PlayerInfo =:= [] -> [5, <<>>];
                 % 帮派数据缺失
                 Guild =:= []  ->
                     ?ERR("set_position: guild not found, id=[~p]", [Status#player_status.guild_id]),
                     [0, <<>>];
                 true ->
                     [PlayerNickname, _PlayerRealm, PlayerGuildId, _PlayerGuildName, PlayerGuildPosition] = PlayerInfo,
                     [DeputyChiefId1, DeputyChiefId2] = [Guild#ets_guild.deputy_chief1_id, Guild#ets_guild.deputy_chief2_id],
                     if  % 对方没有帮派
                         PlayerGuildId == 0 -> [6, <<>>];
                         % 对方不是本帮成员
                         PlayerGuildId /= Status#player_status.guild_id -> [7, <<>>];
                         % 对方不是副帮主
                         PlayerGuildPosition /= 2 -> [8, <<>>];
                         % 可以禅让
                         true ->
                             case lib_guild:demise_chief(Status#player_status.id, Status#player_status.nickname, PlayerId, PlayerNickname, Status#player_status.guild_id, DeputyChiefId1, DeputyChiefId2) of
                                 [ok, MemberType] ->
                                     case MemberType of 
                                         0 ->
                                             void;
                                         1 ->
                                             GuildNew = Guild#ets_guild{chief_id           = PlayerId,
                                                                        chief_name         = PlayerNickname,
                                                                        deputy_chief1_id   = Status#player_status.id,
                                                                        deputy_chief1_name = lib_guild:make_sure_binary(Status#player_status.nickname)},
                                             lib_guild:update_guild(GuildNew);
                                         2 ->
                                             GuildNew = Guild#ets_guild{chief_id           = PlayerId,
                                                                        chief_name         = PlayerNickname,
                                                                        deputy_chief2_id   = Status#player_status.id,
                                                                        deputy_chief2_name = lib_guild:make_sure_binary(Status#player_status.nickname)},
                                             lib_guild:update_guild(GuildNew)
                                     end,
                                     [1, PlayerNickname];
                                  _ -> [0, <<>>]
                             end
                     end
             end
    end.

%% -----------------------------------------------------------------
%% 捐献钱币
%% -----------------------------------------------------------------
donate_money(Status, [GuildId, Num]) ->
    ?DEBUG("donate_money: GuildId=[~p], Num=[~p]", [GuildId, Num]),
    if   % 你没有加入任何帮派
         Status#player_status.guild_id == 0 -> [3, 0];
         % 你不是该帮派成员
         Status#player_status.guild_id /= GuildId -> [4, 0];
         % 你没有这么多钱
         Status#player_status.coin < Num -> [5, 0];
         true ->
             Guild = lib_guild:get_guild(GuildId),
             if  % 帮派不存在
                 Guild =:= [] -> [2, 0];
                 true ->
                     case lib_guild:donate_money(Status#player_status.id, GuildId, Num) of
                         ok  ->
                             % 更新缓存
                             GuildNew = Guild#ets_guild{funds = Guild#ets_guild.funds+Num},
                             lib_guild:update_guild(GuildNew),
                             [1, Status#player_status.coin-Num];
                         _   -> [0, 0]
                     end
             end             
   end.

%% -----------------------------------------------------------------
%% 捐献帮派建设卡
%% -----------------------------------------------------------------
donate_contribution_card(Status, [GuildId, Num]) ->
    ?DEBUG("donate_contribution_card: GuildId=[~p], Num=[~p]", [GuildId, Num]),
    if   % 你没有加入任何帮派
         Status#player_status.guild_id == 0 -> [2, 0, 0];
         % 你不是该帮派成员
         Status#player_status.guild_id /= GuildId -> [3, 0, 0];
         true ->
             [Type, SubType, _CreateCardNum] = data_guild:get_guild_config(create_contribution_card, []),
             GoodsType = lib_guild:get_goods_type_by_type_info(Type, SubType),
             if  % 没有帮派建设卡
                 GoodsType =:= [] ->
                     ?DEBUG("donate_contribution_card: Faild to find goods type, type=[~p], subtype=[~p]", [Type, SubType]),
                     [0, 0, 0];
                 true ->
                     Guild = lib_guild:get_guild(GuildId),
                     if  % 帮派不存在
                         Guild =:= []  -> [5, 0, 0];
                         true ->
                             case gen_server:call(Status#player_status.goods_pid, {'delete_more', GoodsType#ets_goods_type.goods_id, Num}) of
                                 % 扣取物品成功
                                 1 ->
                                    [Level,Contribution,ContributionThreshold] = [Guild#ets_guild.level, Guild#ets_guild.contribution, Guild#ets_guild.contribution_threshold],
                                    case lib_guild:donate_contribution_card(Status#player_status.id, GuildId, Num, Level, Contribution, ContributionThreshold) of
                                        % 帮派未升级
                                        [0, ContributionNew]  ->
                                            % 更新缓存
                                            GuildNew = Guild#ets_guild{contribution = ContributionNew},
                                            lib_guild:update_guild(GuildNew),
                                            [1, Level, Level];
                                        % 帮派升级
                                        [1, MemberCapacityNew, LevelNew, ContributionNew, ContributionDailyNew, ContributionThresholdNew, DisbandDeadlineTime]  ->
                                            % 更新缓存
                                            GuildNew = Guild#ets_guild{member_capacity        = MemberCapacityNew,
                                                                       level                  = LevelNew,
                                                                       contribution           = ContributionNew,
                                                                       contribution_daily     = ContributionDailyNew,
                                                                       contribution_threshold = ContributionThresholdNew,
                                                                       disband_deadline_time  = DisbandDeadlineTime},
                                            lib_guild:update_guild(GuildNew),
                                            [1, Level, LevelNew];
                                        % 出错
                                        _   ->
                                            [0, 0, 0]
                                    end;
                                  % 扣取物品失败
                                  0 ->
                                       ?DEBUG("donate_contribution_card: Call goods module faild", []),
                                       [0, 0, 0];
                                  % 物品数量不够
                                  _ ->
                                       [4, 0, 0]
                             end
                     end
             end
   end.

%% -----------------------------------------------------------------
%% 获取捐献列表
%% -----------------------------------------------------------------
list_donate(_Status, [GuildId, PageSize, PageNo]) ->
    ?DEBUG("list_donate: GuildId=[~p], PageSize=[~p], PageNo=[~p]", [GuildId, PageSize, PageNo]),
    lib_guild:get_donate_page(GuildId, PageSize, PageNo).
   
%% -----------------------------------------------------------------
%% 辞去官职
%% -----------------------------------------------------------------
resign_position(Status, [GuildId]) ->
    ?DEBUG("resign_position: GuildId=[~p]", [GuildId]),
    DefautPosition = data_guild:get_guild_config(default_position, []),
    if   % 你没有加入任何帮派
         Status#player_status.guild_id == 0 -> [2, Status#player_status.guild_position];
         % 你不是该帮派成员
         Status#player_status.guild_id /= GuildId -> [3, Status#player_status.guild_position];
         % 你没有官职
         Status#player_status.guild_position == DefautPosition -> [4, Status#player_status.guild_position];
         % 帮主不能辞去官职
         Status#player_status.guild_position == 1 -> [5, Status#player_status.guild_position];
         true ->
             Guild   = lib_guild:get_guild(GuildId),
             if  % 帮派不存在
                 Guild =:= []  ->
                     ?ERR("resign_position: guild not found, id=[~p]", [Status#player_status.guild_id]),
                     [6, Status#player_status.guild_position];
                 true ->
                     [DeputyChielfId1, DeputyChielfId2, DeputyChiefNum] = [Guild#ets_guild.deputy_chief1_id, Guild#ets_guild.deputy_chief2_id, Guild#ets_guild.deputy_chief_num],
                     case lib_guild:set_position(Status#player_status.id, Status#player_status.nickname, Status#player_status.guild_id, DefautPosition, DeputyChielfId1, DeputyChielfId2) of
                        [ok, MemberType] ->
                            % 更新缓存
                            case MemberType of 
                                0 ->
                                    void;
                                1 ->
                                    GuildNew = Guild#ets_guild{deputy_chief_num   = DeputyChiefNum-1,
                                                               deputy_chief1_id   = 0,
                                                               deputy_chief1_name = <<>>},
                                    lib_guild:update_guild(GuildNew);
                                2 ->
                                    GuildNew = Guild#ets_guild{deputy_chief_num   = DeputyChiefNum-1,
                                                               deputy_chief2_id   = 0,
                                                               deputy_chief2_name = <<>>},
                                    lib_guild:update_guild(GuildNew);
                                3 ->
                                    GuildNew = Guild#ets_guild{deputy_chief_num   = DeputyChiefNum+1,
                                                               deputy_chief1_id   = Status#player_status.id,
                                                               deputy_chief1_name = lib_guild:make_sure_binary(Status#player_status.nickname)},
                                    lib_guild:update_guild(GuildNew);
                                4 ->
                                    GuildNew = Guild#ets_guild{deputy_chief_num   = DeputyChiefNum+1,
                                                               deputy_chief2_id   = Status#player_status.id,
                                                               deputy_chief2_name = lib_guild:make_sure_binary(Status#player_status.nickname)},
                                    lib_guild:update_guild(GuildNew)
                            end,
                            [1, DefautPosition];
                        _  ->  [0, Status#player_status.guild_position]
                    end
             end
    end.


%% -----------------------------------------------------------------
%% 领取日福利
%% -----------------------------------------------------------------
get_paid(Status, [GuildId]) ->
    ?DEBUG("get_paid: GuildId=[~p]", [GuildId]),
    if   % 你没有加入任何帮派
         Status#player_status.guild_id == 0 -> [2, 0, 0];
         % 你不是该帮派成员
         Status#player_status.guild_id /= GuildId -> [3, 0, 0];
         true ->
             GuildMember = lib_guild:get_guild_member_by_player_id(Status#player_status.id),
             if  % 成员不存在
                 GuildMember =:= [] ->
                     [0, 0, 0];
                 true ->                     
                     PaidLastTime   = GuildMember#ets_guild_member.paid_get_lasttime,
                     NowTime        = util:unixtime(),
                     SameDay        = lib_guild:is_same_date(PaidLastTime, NowTime),
                     if  % 已经领取过
                         SameDay == true -> [4, 0, 0];
                         true ->
                             Guild   = lib_guild:get_guild(Status#player_status.guild_id),
                             if  % 帮派不存在
                                 Guild =:= []  ->
                                     ?ERR("get_paid: guild not found, id=[~p]", [Status#player_status.guild_id]),
                                     [5, 0, 0];
                                 true ->
                                     GuildLevel    = Guild#ets_guild.level,
                                     PaidDaily = data_guild:get_paid_daily(GuildLevel, Status#player_status.guild_position),
                                     case lib_guild:get_paid(Status#player_status.id, PaidDaily, NowTime) of
                                        ok ->
                                            % 更新缓存
                                            GuildMemberNew = GuildMember#ets_guild_member{paid_get_lasttime = NowTime},
                                            lib_guild:update_guild_member(GuildMemberNew),
                                            [1, PaidDaily, Status#player_status.coin+PaidDaily];
                                        _  ->
                                            [0, 0, 0]
                                     end
                             end
                     end
             end
    end.


%% -----------------------------------------------------------------
%% 获取成员信息
%% -----------------------------------------------------------------
get_member_info(_Status, [GuildId, PlayerId]) ->
    ?DEBUG("get_member_info: GuildId=[~p], PlayerId=[~p]", [GuildId, PlayerId]),
    lib_guild:get_member_info(GuildId, PlayerId).


%% -----------------------------------------------------------------
%% 授予头衔
%% -----------------------------------------------------------------
give_tile(Status, [GuildId, PlayerId, Title]) ->
    ?DEBUG("give_tile: GuildId=[~p], PlayerId=[~p], Title=[~s]", [GuildId, PlayerId, Title]),
    if   % 你没有加入任何帮派
         Status#player_status.guild_id == 0 -> [2, <<>>];
         % 你不是该帮派成员
         Status#player_status.guild_id /= GuildId  -> [3, <<>>];
         % 你无权设置(帮主可以)
         Status#player_status.guild_position > 1 -> [4, <<>>];
         true ->
             PlayerInfo = lib_guild:get_player_guild_info(PlayerId),
             if  % 对方玩家不存在
                 PlayerInfo =:= [] -> [5, <<>>];
                 true ->
                     [PlayerNickname, _PlayerRealm, PlayerGuildId, _PlayerGuildName, _PlayerGuildPosition] = PlayerInfo,
                     if  % 对方没有帮派
                         PlayerGuildId == 0 -> [6, <<>>];
                         % 对方不是本帮成员
                         PlayerGuildId /= Status#player_status.guild_id -> [7, <<>>];
                         % 可以授予
                         true ->
                             case lib_guild:give_title(PlayerId, Title) of
                                 ok ->
                                     % 更新缓存
                                     GuildMember    = lib_guild:get_guild_member_by_player_id(PlayerId),
                                     TitleBin       = lib_guild:make_sure_binary(Title),
                                     GuildMemberNew = GuildMember#ets_guild_member{title = TitleBin},
                                     lib_guild:update_guild_member(GuildMemberNew),
                                     [1, PlayerNickname];
                                 _ ->
                                     [0, <<>>]
                             end
                     end
             end
    end.

%% -----------------------------------------------------------------
%% 修改个人备注
%% -----------------------------------------------------------------
modify_remark(Status, [GuildId, Remark]) ->
    ?DEBUG("modify_remark: GuildId=[~p], Remark=[~s]", [GuildId, Remark]),
    if   % 你没有加入任何帮派
         Status#player_status.guild_id == 0 -> 2;
         % 你不是该帮派成员
         Status#player_status.guild_id /= GuildId  -> 3;
         true ->
             case lib_guild:modify_remark(Status#player_status.id, Remark) of
                 ok ->
                    % 更新缓存
                    GuildMember    = lib_guild:get_guild_member_by_player_id(Status#player_status.id),
                    RemarkBin      = lib_guild:make_sure_binary(Remark),
                    GuildMemberNew = GuildMember#ets_guild_member{remark = RemarkBin},
                    lib_guild:update_guild_member(GuildMemberNew),
                     1;
                 _ ->  0
             end
    end.