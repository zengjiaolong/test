%%%------------------------------------
%%% @Module     : pp_mail
%%% @Author     : huangyongxing
%%% @Email      : huangyongxing@yeah.net
%%% @Created    : 2010.05.24
%%% @Description: 信件操作
%%%------------------------------------
-module(pp_mail).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%% 客户端发信
handle(19001, PlayerStatus, Data) ->
    [NameList, Title, Content, GoodsId, GoodsNum, Coin] = Data,
    case lib_mail:send_priv_mail(NameList, Title, Content, GoodsId, GoodsNum, Coin, PlayerStatus) of
        {ok, RName} ->
            {ok, BinData} = pt_19:write(19001, [1, []]),            %% 发送成功
            {ok, Bin} = pt_19:write(19005, 1),                      %% 通知收件人有未读邮件
            lib_send:send_to_nick(RName, Bin);
        {error, Reason} ->
            {ok, BinData} = pt_19:write(19001, [Reason, []]);

        {VList, IList} ->                                           %% {发送成功名单，发送失败名单}
            case IList of
                [] ->
                    {ok, BinData} = pt_19:write(19001, [1, []]);    %% 发送成功
                _ ->
                    {ok, BinData} = pt_19:write(19001, [6, IList])  %% 部分发送失败
            end,
            {ok, Bin} = pt_19:write(19005, 1),                      %% 通知收件人有未读邮件
            lists:foreach(fun(Nick) -> lib_send:send_to_nick(Nick, Bin) end, VList)
    end,
    %timer:sleep(5),    %% Erlang模拟客户端测试需要，分隔两个数据包
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%% 获取信件
handle(19002, PlayerStatus, MailId) ->
    case lib_mail:get_mail(MailId, PlayerStatus#player_status.id) of
        {ok, Mail} ->
            {ok, BinData} = pt_19:write(19002, [1 | Mail]);
        {error, ErrorCode} ->
            {ok, BinData} = pt_19:write(19002, [ErrorCode | MailId])
    end,
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%% 删除信件
handle(19003, PlayerStatus, Data) ->
    IdList = Data,
    case lib_mail:del_mail(IdList, PlayerStatus#player_status.id) of
        ok ->
            {ok, BinData} = pt_19:write(19003, 1);
        _ ->
            {ok, BinData} = pt_19:write(19003, 0)
    end,
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%% 获取信件列表
handle(19004, PlayerStatus, get_maillist) ->
    case lib_mail:get_maillist(PlayerStatus#player_status.id) of        %% 获取用户信件列表
        {ok, Maillist} ->
            CurrTimestamp = util:unixtime(),
            {ok, BinData} = pt_19:write(19004, [1, CurrTimestamp, Maillist]);
        error ->
            {ok, BinData} = pt_19:write(19004, [0, [], []])            
    end,
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%% 查询有无未读邮件
handle(19005, PlayerStatus, check_unread) ->
    case lib_mail:check_unread(PlayerStatus#player_status.id) of
        true ->
            {ok, BinData} = pt_19:write(19005, 1);  %% 有未读邮件
        false ->
            {ok, BinData} = pt_19:write(19005, 0)   %% 无未读邮件
    end,
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%% 提取附件
handle(19006, PlayerStatus, Data) ->
    MailId = Data,
    case lib_mail:get_attachment(PlayerStatus, MailId) of
        ok ->
            %timer:sleep(5),    %% Erlang模拟客户端测试需要
            {ok, BinData} = pt_19:write(19006, [1, MailId]);        %% 提取附件成功
        {error, ErrorCode} ->
            {ok, BinData} = pt_19:write(19006, [ErrorCode, MailId])
    end,
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%% 处理玩家反馈信息
handle(19010, PlayerStatus, Data) ->
    [Type, Title, Content] = Data,
    PlayerId = PlayerStatus#player_status.id,
    PlayerName = PlayerStatus#player_status.nickname,
    {ok, {Address, _Port}} = inet:peername(PlayerStatus#player_status.socket),   %% 获得对方IP地址
    Result = lib_mail:feedback(Type, Title, Content, Address, PlayerId, PlayerName),
    {ok, BinData} = pt_19:write(19010, Result),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

handle(_, _, _) ->
    ?DEBUG("pp_mail no match", []),
    {error, "pp_mail no match"}.
