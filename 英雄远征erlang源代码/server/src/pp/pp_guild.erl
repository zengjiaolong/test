%%%--------------------------------------
%%% @Module  : pp_guild
%%% @Author  : shebiao
%%% @Email   : shebiao@jieyou.com
%%% @Created : 2010.06.12
%%% @Description: 帮派处理接口
%%%--------------------------------------
-module(pp_guild).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").
-include("qlc.hrl").
-import(data_guild, [get_guild_config/2]).

%%=========================================================================
%% 接口函数
%%=========================================================================

%% -----------------------------------------------------------------
%% 创建帮派
%% -----------------------------------------------------------------
handle(40001, Status, [GuildName, GuildTenet]) ->
    [Result, GuildId, MoneyLeft] = mod_guild:create_guild(Status, [GuildName, GuildTenet]),
    if  % 创建成功
        Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_40:write(40001, [Result, GuildId,  lib_guild:make_sure_binary(GuildName), 1, MoneyLeft]),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 返回新状态
            Status1 = Status#player_status{guild_id       = GuildId,
                                            guild_name     = lib_guild:make_sure_binary(GuildName),
                                            guild_position = 1,
                                            coin           = MoneyLeft},
            {ok, Status1};            
        % 创建失败
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40001, [Result, 0,lib_guild:make_sure_binary(GuildName), 0, MoneyLeft]),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;
    
%% -----------------------------------------------------------------
%% 申请解散帮派
%% -----------------------------------------------------------------
handle(40002, Status, [GuildId]) ->
    Result = mod_guild:apply_disband_guild(Status, [GuildId]),
    if  % 申请成功
        Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_40:write(40002, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 广播帮派成员
            lib_guild:send_guild(GuildId, 'guild_apply_disband', [Status#player_status.id, Status#player_status.nickname, Status#player_status.guild_id, Status#player_status.guild_name]),
            % 邮件通知给帮派成员
            mod_guild:send_guild_mail(guild_apply_disband, [Status#player_status.id, Status#player_status.nickname, Status#player_status.guild_id, Status#player_status.guild_name]),
            ok;
        % 申请失败
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40002, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;
    
%% -----------------------------------------------------------------
%% 确认解散帮派
%% -----------------------------------------------------------------
handle(40003, Status, [GuildId, ConfirmResult]) ->
    Result = mod_guild:confirm_disband_guild(Status, [GuildId, ConfirmResult]),
    if  % 确定解散且成功
        ((Result == 1) and (ConfirmResult == 1)) ->
            % 发送回应
            {ok, BinData} = pt_40:write(40003, [Result, GuildId, lib_guild:make_sure_binary(Status#player_status.guild_name), ConfirmResult]),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 广播帮派成员
            lib_guild:send_guild(GuildId, 'guild_disband', [Status#player_status.guild_id, Status#player_status.guild_name]),
            % 返回新状态
            Status1 = Status#player_status{guild_id       = 0,
                                            guild_name     = <<>>,
                                            guild_position = 0},
            {ok, Status1};
        % 取消解散且成功
        ((Result == 1) and (ConfirmResult == 0)) ->
            % 广播帮派成员
            lib_guild:send_guild(GuildId, 'guild_cancel_disband', [Status#player_status.id, Status#player_status.nickname, Status#player_status.guild_id, Status#player_status.guild_name]),
            % 邮件通知给帮派成员
            mod_guild:send_guild_mail(guild_cancel_disband, [Status#player_status.id, Status#player_status.nickname, Status#player_status.guild_id, Status#player_status.guild_name]),
            % 发送回应
            {ok, BinData} = pt_40:write(40003, [Result, GuildId, lib_guild:make_sure_binary(Status#player_status.guild_name), ConfirmResult]),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok;
        % 其他情况
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40003, [Result, GuildId, lib_guild:make_sure_binary(Status#player_status.guild_name), ConfirmResult]),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 申请加入
%% -----------------------------------------------------------------
handle(40004, Status, [GuildId]) ->
    [Result, _GuildName] = mod_guild:apply_join_guild(Status, [GuildId]),
    if  % 申请成功
        Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_40:write(40004, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 广播帮派官员（长老以上）
            lib_guild:send_guild_official(3, GuildId, 'guild_apply_join', [Status#player_status.id, Status#player_status.nickname]),
            % 邮件通知给帮派官员（长老以上）
            %mod_guild:send_guild_mail(guild_apply_join, [Status#player_status.id, Status#player_status.nickname, GuildId, GuildName]),
            ok;
        % 申请失败
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40004, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;
    

%% -----------------------------------------------------------------
%% 审批加入
%% -----------------------------------------------------------------
handle(40005, Status, [PlayerId, HandleResult]) ->
    [Result, PlayerName, GuildPosition] = mod_guild:handle_apply_guild(Status, [PlayerId, HandleResult]),
    if  % 审批加入成功且允许
        ((Result == 1) and (HandleResult == 1)) ->
            % 发送回应
            {ok, BinData} = pt_40:write(40005, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 广播帮派成员
            lib_guild:send_guild(Status#player_status.guild_id, 'guild_new_member', [PlayerId, PlayerName, Status#player_status.guild_id, Status#player_status.guild_name, GuildPosition]),
            % 邮件通知给被审批人
            mod_guild:send_guild_mail(guild_new_member, [PlayerId, PlayerName, Status#player_status.guild_id, Status#player_status.guild_name]),
            ok;
        % 审批加入成功且拒绝
        ((Result == 1) and (HandleResult == 0)) ->
            % 发送回应
            {ok, BinData} = pt_40:write(40005, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 广播帮派成员
            lib_guild:send_one(PlayerId, 'guild_reject_apply', [Status#player_status.guild_id, Status#player_status.guild_name]),
            % 邮件通知给被审批人
            mod_guild:send_guild_mail(guild_reject_apply, [PlayerId, PlayerName, Status#player_status.guild_id, Status#player_status.guild_name]),
            ok;
        % 其他情况
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40005, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 邀请加入
%% -----------------------------------------------------------------
handle(40006, Status, [PlayerName]) ->
    [Result, PlayerId] = mod_guild:invite_join_guild(Status, [PlayerName]),
    if  % 邀请成功
        Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_40:write(40006, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 通知被邀请人
            lib_guild:send_one(PlayerId, 'guild_invite_join', [PlayerId, PlayerName, Status#player_status.guild_id, Status#player_status.guild_name]),
            % 邮件通知给被邀请人
            %mod_guild:send_guild_mail(guild_invite_join, [PlayerId, PlayerName, Status#player_status.guild_id, Status#player_status.guild_name]),
            ok;
        % 邀请失败
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40006, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 邀请回应
%% -----------------------------------------------------------------
handle(40007, Status, [GuildId, ResponseResult]) ->
    [Result, GuildName, GuildPosition] = mod_guild:response_invite_guild(Status, [GuildId, ResponseResult]),
    if  % 回应成功且加入帮派
        ((Result == 1) and (ResponseResult == 1)) ->
            % 发送回应
            {ok, BinData} = pt_40:write(40007, [Result, ResponseResult, GuildId, GuildName, GuildPosition]),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 广播帮派成员
            lib_guild:send_guild(GuildId, 'guild_new_member', [Status#player_status.id, Status#player_status.nickname, GuildId, GuildName, GuildPosition]),
            % 邮件通知给新成员
            mod_guild:send_guild_mail(guild_new_member, [Status#player_status.id, Status#player_status.nickname, GuildId, GuildName]),
            % 返回新状态
            Status1 = Status#player_status{guild_id       = GuildId,
                                            guild_name     = lib_guild:make_sure_binary(GuildName),
                                            guild_position = GuildPosition},
            {ok, Status1};
        % 回应成功且拒绝入帮
        ((Result == 1) and (ResponseResult == 0)) ->
            % 发送回应
            {ok, BinData} = pt_40:write(40007, [Result, ResponseResult, GuildId, GuildName, GuildPosition]),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 广播帮派成员(仅发送帮主副帮主)
            lib_guild:send_guild_official(2, GuildId, 'guild_reject_invite', [Status#player_status.id, Status#player_status.nickname]),
            ok;
        % 创建失败
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40007, [Result, ResponseResult, GuildId, GuildName, GuildPosition]),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 踢出帮派
%% -----------------------------------------------------------------
handle(40008, Status, [PlayerId]) ->
    [Result, PlayerName] = mod_guild:kickout_guild(Status, [PlayerId]),
    if  % 踢出成功
        Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_40:write(40008, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 通知帮派成员
            lib_guild:send_guild(Status#player_status.guild_id, 'guild_kickout', [PlayerId, PlayerName, Status#player_status.guild_id, Status#player_status.guild_name]),
            % 邮件通知给被踢出人
            mod_guild:send_guild_mail(guild_kickout, [PlayerId, PlayerName, Status#player_status.guild_id, Status#player_status.guild_name]),
            ok;
        % 踢出失败
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40008, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 退出帮派
%% -----------------------------------------------------------------
handle(40009, Status, [GuildId]) ->
    Result = mod_guild:quit_guild(Status, [GuildId]),
    if  % 退出成功
        Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_40:write(40009, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 通知帮派成员
            lib_guild:send_guild(Status#player_status.guild_id, 'guild_quit', [Status#player_status.id, Status#player_status.nickname, Status#player_status.guild_id, Status#player_status.guild_name]),
            % 返回新状态
            Status1 = Status#player_status{guild_id       = 0,
                                            guild_name     = <<>>,
                                            guild_position = 0},
            {ok, Status1};
        % 退出失败
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40009, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 获取帮派列表
%% -----------------------------------------------------------------
handle(40010, Status, [PageSize, PageNo]) ->
    [Result, PageTotal, PageNo, RecordNum, Data] = mod_guild:list_guild(Status, [PageSize, PageNo]),
    {ok, BinData} = pt_40:write(40010, [Result, PageTotal, PageNo, RecordNum, Data]),
    lib_send:send_one(Status#player_status.socket, BinData),
    ok;

%% -----------------------------------------------------------------
%% 获取帮派成员列表
%% -----------------------------------------------------------------
handle(40011, Status, [GuildId, PageSize, PageNo]) ->
    [Result, PageTotal, PageNo, RecordNum, Data] = mod_guild:list_guild_member(Status, [GuildId, PageSize, PageNo]),
    {ok, BinData} = pt_40:write(40011, [Result, PageTotal, PageNo, RecordNum, Data]),
    lib_send:send_one(Status#player_status.socket, BinData),
    ok;

%% -----------------------------------------------------------------
%% 获取帮派申请列表
%% -----------------------------------------------------------------
handle(40012, Status, [GuildId, PageSize, PageNo]) ->
    [Result, PageTotal, PageNo, RecordNum, Data] = mod_guild:list_guild_apply(Status, [GuildId, PageSize, PageNo]),
    {ok, BinData} = pt_40:write(40012, [Result, PageTotal, PageNo, RecordNum, Data]),
    lib_send:send_one(Status#player_status.socket, BinData),
    ok;

%% -----------------------------------------------------------------
%% 获取帮派邀请列表
%% -----------------------------------------------------------------
handle(40013, Status, [PlayerId, PageSize, PageNo]) ->
    [Result, PageTotal, PageNo, RecordNum, Data] = mod_guild:list_guild_invite(Status, [PlayerId, PageSize, PageNo]),
    {ok, BinData} = pt_40:write(40013, [Result, PageTotal, PageNo, RecordNum, Data]),
    lib_send:send_one(Status#player_status.socket, BinData),
    ok;

%% -----------------------------------------------------------------
%% 查看本帮信息
%% -----------------------------------------------------------------
handle(40014, Status, [GuildId]) ->
    [Result, Data] = mod_guild:get_guild_info(Status, [GuildId]),
    {ok, BinData} = pt_40:write(40014, [Result,Data]),
    lib_send:send_one(Status#player_status.socket, BinData),
    ok;

%% -----------------------------------------------------------------
%% 修改帮派宗旨
%% -----------------------------------------------------------------
handle(40015, Status, [GuildId, Tenet]) ->
    Result = mod_guild:modify_guild_tenet(Status, [GuildId, Tenet]),
    {ok, BinData} = pt_40:write(40015, Result),
    lib_send:send_one(Status#player_status.socket, BinData),
    ok;

%% -----------------------------------------------------------------
%% 修改帮派公告
%% -----------------------------------------------------------------
handle(40016, Status, [GuildId, Announce]) ->
    Result = mod_guild:modify_guild_announce(Status, [GuildId, Announce]),
    {ok, BinData} = pt_40:write(40016, Result),
    lib_send:send_one(Status#player_status.socket, BinData),
    ok;

%% -----------------------------------------------------------------
%% 职位设置
%% -----------------------------------------------------------------
handle(40017, Status, [PlayerId, GuildPosition]) ->
    [Result, PlayerName, OldGuildPostion] = mod_guild:set_position(Status, [PlayerId, GuildPosition]),
    if  % 踢出成功
        Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_40:write(40017, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            case OldGuildPostion < GuildPosition of
                % 降职（仅被降职成员收到）
                true ->
                    lib_guild:send_one(PlayerId, 'guild_set_position', [PlayerId, PlayerName, OldGuildPostion, GuildPosition]);
                % 升职（通知帮派成员）
                false ->
                    lib_guild:send_guild(Status#player_status.guild_id, 'guild_set_position', [PlayerId, PlayerName, OldGuildPostion, GuildPosition])
            end,
            ok;
        % 踢出失败
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40017, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 禅让帮主
%% -----------------------------------------------------------------
handle(40018, Status, [PlayerId]) ->
    [Result, PlayerName] = mod_guild:demise_chief(Status, [PlayerId]),
    if % 禅让成功
        Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_40:write(40018, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 通知帮派成员
            lib_guild:send_guild(Status#player_status.guild_id, 'guild_demise_chief', [Status#player_status.id, Status#player_status.nickname, PlayerId, PlayerName]),
            % 返回新状态
            Status1 = Status#player_status{guild_position = 2},
            {ok, Status1};
        % 创建失败
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40018, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 捐献钱币
%% -----------------------------------------------------------------
handle(40019, Status, [GuildId, Num]) ->
    ?DEBUG("Handling 40019, GuildId=[~p], Num=[~p]", [GuildId, Num]),
    [Result, MoneyLeft] = mod_guild:donate_money(Status, [GuildId, Num]),
    if  % 捐献成功
        Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_40:write(40019, [Result, MoneyLeft]),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 通知帮派成员
            lib_guild:send_guild(Status#player_status.guild_id, 'guild_donate_money', [Status#player_status.id, Status#player_status.nickname, Num]),
            % 返回新状态
            Status1 = Status#player_status{coin = MoneyLeft},
            {ok, Status1};
        % 捐献失败
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40019, [Result, MoneyLeft]),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 捐献帮派建设卡
%% -----------------------------------------------------------------
handle(40020, Status, [GuildId, Num]) ->
    ?DEBUG("Handling 40020, GuildId=[~p], Num=[~p]", [GuildId, Num]),
    [Result, OldLevel, NewLevel] = mod_guild:donate_contribution_card(Status, [GuildId, Num]),
    if   Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_40:write(40020, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 通知帮派成员
            lib_guild:send_guild(Status#player_status.guild_id, 'guild_donate_contribution_card', [Status#player_status.id, Status#player_status.nickname, Num]),
            % 如果帮派升级则也通知帮派成员
            if  (OldLevel < NewLevel) ->
                    lib_guild:send_guild(Status#player_status.guild_id, 'guild_upgrade', [Status#player_status.guild_id, Status#player_status.guild_name, OldLevel, NewLevel]);
                true ->
                    void
            end,
            ok;
        % 捐献失败
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40020, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 获取捐献列表
%% -----------------------------------------------------------------
handle(40021, Status, [GuildId, PageSize, PageNo]) ->
    [Result, PageTotal, PageNo, RecordNum, Data] = mod_guild:list_donate(Status, [GuildId, PageSize, PageNo]),
    {ok, BinData} = pt_40:write(40021, [Result, PageTotal, PageNo, RecordNum, Data]),
    lib_send:send_one(Status#player_status.socket, BinData),
    ok;

%% -----------------------------------------------------------------
%% 辞去官职
%% -----------------------------------------------------------------
handle(40022, Status, [GuildId]) ->
    [Result, NewPosition] = mod_guild:resign_position(Status, [GuildId]),
    if
        % 辞去成功
        Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_40:write(40022, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 通知帮派官员（帮主和副帮主）
            lib_guild:send_guild_official(2, Status#player_status.guild_id, 'guild_resign_position', [Status#player_status.id, Status#player_status.nickname, Status#player_status.guild_position, NewPosition]),
            % 返回新状态
            Status1 = Status#player_status{guild_position = NewPosition},
            {ok, Status1};
        % 创建失败
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40022, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 领取日福利
%% -----------------------------------------------------------------
handle(40023, Status, [GuildId]) ->
    ?DEBUG("Handling 40023, GuildId=[~p]", [GuildId]),
    [Result, Num, MoneyLeft] = mod_guild:get_paid(Status, [GuildId]),
    if
        % 领取成功
        Result == 1 ->
            % 发送回应
            {ok, BinData} = pt_40:write(40023, [Result, Num, MoneyLeft]),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 返回新状态
            Status1 = Status#player_status{coin = MoneyLeft},
            {ok, Status1};
        % 领取失败
        true ->
            % 发送回应
            {ok, BinData} = pt_40:write(40023, [Result, Num, MoneyLeft]),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;

%% -----------------------------------------------------------------
%% 查看成员信息
%% -----------------------------------------------------------------
handle(40024, Status, [GuildId, PlayerId]) ->
    [Result, Data] = mod_guild:get_member_info(Status, [GuildId, PlayerId]),
    {ok, BinData} = pt_40:write(40024, [Result,Data]),
    lib_send:send_one(Status#player_status.socket, BinData),
    ok;

%% -----------------------------------------------------------------
%% 授予头衔
%% -----------------------------------------------------------------
handle(40025, Status, [GuildId, PlayerId, Title]) ->
    ?DEBUG("Handling 40025, GuildId=[~p], PlayerId=[~p], Title=[~s]", [GuildId, PlayerId, Title]),
    [Result, PlayerName] = mod_guild:give_tile(Status, [GuildId, PlayerId, Title]),
    if  Result == 1 ->
            {ok, BinData} = pt_40:write(40025, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            % 通知帮派成员
            lib_guild:send_guild(Status#player_status.guild_id, 'guild_give_title', [PlayerId, PlayerName, Title]),
            ok;
        true ->
            {ok, BinData} = pt_40:write(40025, Result),
            lib_send:send_one(Status#player_status.socket, BinData),
            ok
    end;
    

%% -----------------------------------------------------------------
%% 修改个人备注
%% -----------------------------------------------------------------
handle(40026, Status, [GuildId, Remark]) ->
    ?DEBUG("Handling 40026, GuildId=[~p], Remark=[~s]", [GuildId, Remark]),
    Result = mod_guild:modify_remark(Status, [GuildId, Remark]),
    {ok, BinData} = pt_40:write(40026, Result),
    lib_send:send_one(Status#player_status.socket, BinData),
    ok;

%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
handle(_Cmd, _Status, _Data) ->
    ?DEBUG("pp_guild no match", []),
    {error, "pp_guild no match"}.



