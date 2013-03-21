%%%---------------------------------------------
%%% @Module  : guild_test
%%% @Author  : shebiao
%%% @Email   : shebiao@jieyou.com
%%% @Created : 2010.06.25
%%% @Description: 客户端测试程序
%%%---------------------------------------------
-module(guild_test).
-include("common.hrl").
-compile(export_all).

for(Max, Max, _F, X) ->
    X;
for(Min, Max, F, X) ->
    F(X),
    for(Min+1, Max, F, X).

 sleep_send({T, S}) ->
    receive
    after T -> handle(run, a, S)
    end.

loop2(N) ->
%    case gen_tcp:connect(?HOST, ?PORT, [binary, {packet, 0}], 100000) of
    case gen_tcp:connect("localhost", 6666, [binary, {packet, 0}], 100000) of
        {ok, Socket} ->
            io:format("connect ok: ~p~n", [N]),
            sleep(10),
            % 登录消息10000
            handle(login, {N, integer_to_list(123620)}, Socket),
            sleep(10),
            % 创建角色消息10003
%            handle(create_player, {1, 1, integer_to_list(N)}, Socket),
%            sleep(10),
            % 进入场景消息10004
            handle(enter_player, {1}, Socket),
            sleep(10),
            % 心跳消息10006
            handle(heart, 0, Socket),
            sleep(10),
            % 移动消息12001
%            handle(run, a, Socket),
%            sleep(10),
            % 创建帮派消息40001
%            handle(create_guild, {"潮人帮", "帮派宗旨"}, Socket),
%            sleep(10),
            % 解散帮派消息40002
%            handle(disband_guild, {19}, Socket),
%            sleep(10),
            % 确认解散帮派消息40003
%            handle(confirm_disband_guild, {19, 1}, Socket),
%            sleep(10),
            % 加入帮派消息40004
%            handle(apply_guild, {22}, Socket),
%            sleep(10),
            % 审批申请40005
%            handle(hanle_apply, {2, 1}, Socket),
%            sleep(10),
            %% 帮派邀请
%            handle(invite_guild, {"XiaoZ"}, Socket),
%            sleep(10),
            %% 踢出帮派
%            handle(kickout_guild, {2}, Socket),
%            sleep(10),
            %% 帮派列表
%            handle(list_guild, {10, 1}, Socket),
%            sleep(10),
            %% 成员列表
%            handle(list_member, {22, 10, 1}, Socket),
%            sleep(10),
            %% 申请列表
%            handle(list_apply, {22, 10, 1}, Socket),
%            sleep(10),
%            handle(quit_guild, {22}, Socket),
%            sleep(10),
            %% 邀请列表
%            handle(list_invite, {1, 10, 1}, Socket),
%            sleep(10),
            %% 受邀列表
%            handle(list_invited, {1, 10, 1}, Socket),
%            sleep(10),
            %% 获取帮派信息
%            handle(guild_info, {22}, Socket),
%            sleep(10),
            %% 修改帮派宗旨
%            handle(modify_guild_tenet, {22, "新帮派宗旨"}, Socket),
%            sleep(10),
            %% 修改帮派公告
%            handle(modify_guild_announce, {22, "新帮派公告"}, Socket),
%            sleep(10),
            %% 招纳贤士信息
%            handle(recruit_member, {1}, Socket),
%            sleep(10),
            % 设置职位信息
%            handle(set_position, {2, 3}, Socket),
%            sleep(10),
            %% 禅让帮主
%            handle(demise_chief, {2}, Socket),
%            sleep(10),
            %%捐献帮派金
%            handle(donate_money, {22, 100000}, Socket),
%            sleep(10),
            %%捐献建设卡
%            handle(donate_contribution_card, {22, 100}, Socket),
%            sleep(10),
            %%捐献列表
            handle(list_donate, {24, 10, 1}, Socket),
            sleep(10),
            %%辞去官职
%            handle(resign_position, {22}, Socket),
%            sleep(10),
            %%领取日福利
%            handle(get_paid, {22}, Socket),
%            sleep(10),
            %%获取成员信息
%            handle(get_member_info, {22, 1}, Socket),
%            sleep(10),
            %%授予称号
%            handle(give_title, {22, 1, "打虎英雄"}, Socket),
%            sleep(10),
            %%修改个人备注
%            handle(modify_remark, {22, "个人备注"}, Socket),
%            sleep(10),
            %%帮派聊天
%            handle(guild_chat, {1, "帮派聊天信息"}, Socket),
%            sleep(10),
            rec(Socket);
        {error, Reason} ->
            io:format("connect failed: ~p~n", [Reason])   
    end.

for(Max, Max, _F) ->
    [];
for(Min, Max, F) ->
    [F(Min) | for(Min+1, Max, F)].

%% 循环测试
ct(N) ->
    F = fun(N1) ->
            spawn(fun() -> loop2(N1+10000) end),
            sleep(500)
        end,
    for(1, N+1, F),
    ok.


%%心跳包
handle(heart, _, Socket) ->
    io:format("client send: heart Cmd=[10006]~n"),
    gen_tcp:send(Socket, <<4:16, 10006:16>>),
    ok;%rec(Socket);
%%登陆
handle(login, {Accid, AccName}, Socket) ->
    io:format("client send: login Cmd=[10000], Accid=[~p], AccName=[~p] ~n", [Accid, AccName]),
    AccStamp = 1273027133,
    Tick = integer_to_list(Accid) ++ AccName ++ integer_to_list(AccStamp) ++ ?TICKET,
    TickMd5 = util:md5(Tick),
    TickMd5Bin = list_to_binary(TickMd5),
    AccNameLen = byte_size(list_to_binary(AccName)),
    AccNameBin = list_to_binary(AccName),
    Data = <<Accid:32, AccStamp:32, AccNameLen:16, AccNameBin/binary, 32:16, TickMd5Bin/binary>>,
    Len = byte_size(Data) + 4,
    gen_tcp:send(Socket, <<Len:16, 10000:16, Data/binary>>),
    ok;%rec(Socket);
%%创建用户
handle(create_player, {Pro, Sex, Name}, Socket) ->
    io:format("client send: create_player Cmd=[10003], Pro=[~p], Sex=[~p], Name[~p] ~n", [Pro, Sex, Name]),
    NameBin = list_to_binary(Name),
    NameLen = byte_size(NameBin),
    Data = <<Pro:16, Sex:16, NameLen:16, NameBin/binary>>,
    Len = byte_size(Data) + 4,
    gen_tcp:send(Socket, <<Len:16, 10003:16, Data/binary>>),
    ok;%%rec(Socket);
%%玩家列表
handle(list_player, _, Socket) ->
    io:format("client send: list_player Cmd=[10002]~n"),
    gen_tcp:send(Socket, <<6:16, 10002:16, 1:16>>),
    rec(Socket);
%%选择角色进入
handle(enter_player, {PlayerId}, Socket) ->
    io:format("client send: enter_player Cmd=[10004], PlayerId=[~p] ~n", [PlayerId]),
    gen_tcp:send(Socket, <<8:16, 10004:16, PlayerId:32>>),
    ok;%rec(Socket);


%% -----------------------------------------------------------------
%% 帮派
%% -----------------------------------------------------------------

%%创建帮派
handle(create_guild, {GuildName, GuildIntro}, Socket) ->
     Name  = list_to_binary(GuildName),
     NameLen = byte_size(Name),
     Intro = list_to_binary(GuildIntro),
     IntroLen = byte_size(Intro),
     io:format("client send: create_guild Cmd=[40001], GuildName=[~s], GuildIntro=[~p]~n", [GuildName, GuildIntro]),
     MsgLen = byte_size( <<1:16,40001:16,NameLen:16,"潮人帮", IntroLen:16, "帮派宗旨">>),
     gen_tcp:send(Socket, <<MsgLen:16,40001:16,NameLen:16,"潮人帮", IntroLen:16, "帮派宗旨">>),
     ok;%rec(Socket);

%%解散帮派
handle(disband_guild, {GuildId}, Socket) ->
    io:format("client send: disband_guild Cmd=[40002], GuildId=[~p] ~n", [GuildId]),
    MsgLen = byte_size(<<1:16,40002:16,GuildId:32>>),
    gen_tcp:send(Socket, <<MsgLen:16,40002:16,GuildId:32>>),
    ok;%rec(Socket);

handle(confirm_disband_guild, {GuildId, ConfirmResult}, Socket) ->
    io:format("client send: confirm_disband_guild Cmd=[40003], GuildId=[~p], ConfirmResult=[~p] ~n", [GuildId,ConfirmResult]),
    MsgLen = byte_size(<<1:16,40003:16,GuildId:32,ConfirmResult:16>>),
    gen_tcp:send(Socket, <<MsgLen:16,40003:16,GuildId:32,ConfirmResult:16>>),
    ok;%rec(Socket);

%%申请帮派
handle(apply_guild, {GuildId}, Socket) ->
    io:format("client send: apply_guild Cmd=[40004], GuildId=[~p] ~n", [GuildId]),
    MsgLen = byte_size(<<1:16,40004:16,GuildId:32>>),
    gen_tcp:send(Socket, <<MsgLen:16,40004:16,GuildId:32>>),
    ok;%rec(Socket);

%%审批申请
handle(hanle_apply, {PlayerId, HanleResult}, Socket) ->
    io:format("client send: hanle_apply Cmd=[40005], PlayerId=[~p], HandleResult=[~p] ~n", [PlayerId,HanleResult]),
    MsgLen = byte_size(<<1:16,40005:16,PlayerId:32,HanleResult:16>>),
    gen_tcp:send(Socket, <<MsgLen:16,40005:16,PlayerId:32,HanleResult:16>>),
    ok;%rec(Socket);

%%帮派邀请
handle(invite_guild, {PlayerName}, Socket) ->
    io:format("client send: invite_guild Cmd=[40006], PlayerName=[~s] ~n", [PlayerName]),
    PlayerNameBin = list_to_binary("XiaoZ"),
    PlayerNameLen = byte_size(PlayerNameBin),
    MsgLen = byte_size(<<1:16,40006:16,PlayerNameLen:16,"XiaoZ">>),
    gen_tcp:send(Socket, <<MsgLen:16,40006:16,PlayerNameLen:16,"XiaoZ">>),
    ok;%rec(Socket);

%%回应邀请
handle(response_invite, {GuildId, Response}, Socket) ->
    io:format("client send: response_invite Cmd=[40007], GuildId=[~p], Response=[~p] ~n", [GuildId, Response]),
    MsgLen = byte_size(<<1:16,40007:16,GuildId:32, Response:16>>),
    gen_tcp:send(Socket, <<MsgLen:16,40007:16,GuildId:32, Response:16>>),
    ok;%rec(Socket);

%%踢出帮派
handle(kickout_guild, {PlayerId}, Socket) ->
    io:format("client send: kickout_guild Cmd=[40008], PlayerId=[~p] ~n", [PlayerId]),
    MsgLen = byte_size(<<1:16,40008:16,PlayerId:32>>),
    gen_tcp:send(Socket, <<MsgLen:16,40008:16,PlayerId:32>>),
    ok;%rec(Socket);

%%退出帮派
handle(quit_guild, {GuildId}, Socket) ->
    io:format("client send: quit_guild Cmd=[40009], GuildId=[~p] ~n", [GuildId]),
    MsgLen = byte_size(<<1:16,40009:16,GuildId:32>>),
    gen_tcp:send(Socket, <<MsgLen:16,40009:16,GuildId:32>>),
    ok;%rec(Socket);

%%帮派列表
handle(list_guild, {PageSize, PageNo}, Socket) ->
    io:format("client send: list_guild Cmd=[40010], PageSize=[~p], PageNo=[~p] ~n", [PageSize, PageNo]),
    MsgLen = byte_size(<<1:16,40010:16,PageSize:16, PageNo:16>>),
    gen_tcp:send(Socket, <<MsgLen:16,40010:16,PageSize:16, PageNo:16>>),
    ok;%rec(Socket);

%%成员列表
handle(list_member, {GuildId, PageSize, PageNo}, Socket) ->
    io:format("client send: list_member Cmd=[40011], GuildId=[~p], PageSize=[~p], PageNo=[~p] ~n", [GuildId, PageSize, PageNo]),
    MsgLen = byte_size(<<1:16,40011:16,GuildId:32, PageSize:16, PageNo:16>>),
    gen_tcp:send(Socket, <<MsgLen:16, 40011:16, GuildId:32, PageSize:16, PageNo:16>>),
    ok;%rec(Socket);

%%申请列表
handle(list_apply, {GuildId, PageSize, PageNo}, Socket) ->
    io:format("client send: list_apply Cmd=[40012], GuildId=[~p], PageSize=[~p], PageNo=[~p] ~n", [GuildId, PageSize, PageNo]),
    MsgLen = byte_size(<<1:16,40012:16,GuildId:32, PageSize:16, PageNo:16>>),
    gen_tcp:send(Socket, <<MsgLen:16, 40012:16, GuildId:32, PageSize:16, PageNo:16>>),
    ok;%rec(Socket);

%%邀请列表
handle(list_invited, {PlayerId, PageSize, PageNo}, Socket) ->
    io:format("client send: list_invited Cmd=[40013], PlayerId=[~p], PageSize=[~p], PageNo=[~p] ~n", [PlayerId, PageSize, PageNo]),
    MsgLen = byte_size(<<1:16,40013:16,PlayerId:32, PageSize:16, PageNo:16>>),
    gen_tcp:send(Socket, <<MsgLen:16, 40013:16, PlayerId:32, PageSize:16, PageNo:16>>),
    ok;%rec(Socket);

%%帮派信息
handle(guild_info, {GuildId}, Socket) ->
    io:format("client send: guild_info Cmd=[40014], GuildId=[~p] ~n", [GuildId]),
    MsgLen = byte_size(<<1:16,40014:16,GuildId:32>>),
    gen_tcp:send(Socket, <<MsgLen:16, 40014:16, GuildId:32>>),
    ok;%rec(Socket);

%%修改帮派宗旨
handle(modify_guild_tenet, {GuildId, Tenet}, Socket) ->
    Name    = list_to_binary(Tenet),
    NameLen = byte_size(Name),
    io:format("client send: modify_guild Cmd=[40015], GuildId=[~p], Tenet=[~s] ~n", [GuildId, Tenet]),
    MsgLen = byte_size(<<1:16,40015:16,GuildId:32, NameLen:16,"新帮派宗旨">>),
    gen_tcp:send(Socket, <<MsgLen:16, 40015:16, GuildId:32, NameLen:16, "新帮派宗旨">>),
    ok;%rec(Socket);

%%修改帮派公告
handle(modify_guild_announce, {GuildId, Announce}, Socket) ->
    Name    = list_to_binary(Announce),
    NameLen = byte_size(Name),
    io:format("client send: modify_guild Cmd=[40016], GuildId=[~p], Announce=[~s] ~n", [GuildId, Announce]),
    MsgLen = byte_size(<<1:16,40016:16,GuildId:32, NameLen:16,"新帮派公告">>),
    gen_tcp:send(Socket, <<MsgLen:16, 40016:16, GuildId:32, NameLen:16, "新帮派公告">>),
    ok;%rec(Socket);

%%招募贤士信息
handle(recruit_member, {GuildId}, Socket) ->
    io:format("client send: recruit_member Cmd=[40014], GuildId=[~p] ~n", [GuildId]),
    MsgLen = byte_size(<<1:16,40016:16,GuildId:32>>),
    gen_tcp:send(Socket, <<MsgLen:16, 40016:16, GuildId:32>>),
    ok;%rec(Socket);

%%职位设置
handle(set_position, {PlayerId, GuildPosition}, Socket) ->
    io:format("client send: set_position Cmd=[40017], PlayerId=[~p], GuildPosition=[~p] ~n", [PlayerId, GuildPosition]),
    MsgLen = byte_size(<<1:16,40017:16,PlayerId:32, GuildPosition:16>>),
    gen_tcp:send(Socket, <<MsgLen:16, 40017:16, PlayerId:32, GuildPosition:16>>),
    ok;%rec(Socket);

%%禅让帮主
handle(demise_chief, {PlayerId}, Socket) ->
    io:format("client send: demise_chief Cmd=[40018], PlayerId=[~p] ~n", [PlayerId]),
    MsgLen = byte_size(<<1:16,40018:16,PlayerId:32>>),
    gen_tcp:send(Socket, <<MsgLen:16, 40018:16, PlayerId:32>>),
    ok;%rec(Socket);

%%捐献帮派金
handle(donate_money, {GuildId, Num}, Socket) ->
    io:format("client send: donate_money Cmd=[40019], GuildId=[~p], Gold=[~p] ~n", [GuildId, Num]),
    MsgLen = byte_size(<<1:16,40019:16,GuildId:32, Num:32>>),
    gen_tcp:send(Socket, <<MsgLen:16, 40019:16, GuildId:32, Num:32>>),
    ok;%rec(Socket);

%%捐献建设卡
 handle(donate_contribution_card, {GuildId, Num}, Socket) ->
    io:format("client send: donate_contribution_card Cmd=[40020], GuildId=[~p], Num=[~p] ~n", [GuildId, Num]),
    MsgLen = byte_size(<<1:16,40020:16,GuildId:32, Num:32>>),
    gen_tcp:send(Socket, <<MsgLen:16, 40020:16, GuildId:32, Num:32>>),
    ok;%rec(Socket);

%%捐献列表
handle(list_donate, {GuildId, PageSize, PageNo}, Socket) ->
    io:format("client send: list_donate Cmd=[40021], GuildId=[~p], PageSize=[~p], PageNo=[~p] ~n", [GuildId, PageSize, PageNo]),
    MsgLen = byte_size(<<1:16,40021:16,GuildId:32, PageSize:16, PageNo:16>>),
    gen_tcp:send(Socket, <<MsgLen:16, 40021:16, GuildId:32, PageSize:16, PageNo:16>>),
    ok;%rec(Socket);

%%辞去官职
handle(resign_position, {GuildId}, Socket) ->
    io:format("client send: resign_position Cmd=[40022], GuildId=[~p] ~n", [GuildId]),
    MsgLen = byte_size(<<1:16,40022:16,GuildId:32>>),
    gen_tcp:send(Socket, <<MsgLen:16, 40022:16, GuildId:32>>),
    ok;%rec(Socket);

%%领取日福利
handle(get_paid, {GuildId}, Socket) ->
    io:format("client send: get_paid Cmd=[40023], GuildId=[~p] ~n", [GuildId]),
    MsgLen = byte_size(<<1:16,40023:16,GuildId:32>>),
    gen_tcp:send(Socket, <<MsgLen:16, 40023:16, GuildId:32>>),
    ok;%rec(Socket);

%%获取成员信息
handle(get_member_info, {GuildId, PlayerId}, Socket) ->
    io:format("client send: get_member_info Cmd=[40024], GuildId=[~p], PlayerId=[~p] ~n", [GuildId, PlayerId]),
    MsgLen = byte_size(<<1:16,40024:16,GuildId:32, PlayerId:32>>),
    gen_tcp:send(Socket, <<MsgLen:16, 40024:16, GuildId:32, PlayerId:32>>),
    ok;%rec(Socket);

%%授予帮派称号
handle(give_title, {GuildId, PlayerId, Title}, Socket) ->
    TitleBin = list_to_binary(Title),
    TitelLen = byte_size(TitleBin),
    io:format("client send: get_member_info Cmd=[40025], GuildId=[~p], PlayerId=[~p] ~n", [GuildId, PlayerId]),
    MsgLen = byte_size(<<1:16,40025:16,GuildId:32, PlayerId:32, TitelLen:16, "打虎英雄">>),
    gen_tcp:send(Socket, <<MsgLen:16, 40025:16, GuildId:32, PlayerId:32, TitelLen:16, "打虎英雄">>),
    ok;%rec(Socket);

%%修改个人备注
handle(modify_remark, {GuildId, Title}, Socket) ->
    TitleBin = list_to_binary(Title),
    TitelLen = byte_size(TitleBin),
    io:format("client send: get_member_info Cmd=[40026], GuildId=[~p], Title=[~s] ~n", [GuildId, Title]),
    MsgLen = byte_size(<<1:16,40026:16,GuildId:32, TitelLen:16, "个人备注">>),
    gen_tcp:send(Socket, <<MsgLen:16, 40026:16, GuildId:32, TitelLen:16, "个人备注">>),
    ok;%rec(Socket);

%%帮派聊天
handle(guild_chat, {Color, Content}, Socket) ->
    ContentBin = list_to_binary(Content),
    ContentLen = byte_size(ContentBin),
    io:format("client send: guild_chat Cmd=[11005], Color=[~p], Title=[~s] ~n", [Color, "帮派聊天信息"]),
    MsgLen = byte_size(<<1:16,11005:16,Color:8, ContentLen:16, "帮派聊天信息">>),
    gen_tcp:send(Socket, <<MsgLen:16, 11005:16, Color:8, ContentLen:16, "帮派聊天信息">>),
    ok;%rec(Socket);

handle(run, a, Socket) ->
    io:format("client send: run Cmd=[12001],X=[100], y=[200] ~n"),
    gen_tcp:send(Socket, <<8:16, 12001:16, 100:16, 200:16>>),
    ok;%rec(Socket);

handle(Handle, Data, Socket) ->
    io:format("hadle error: ~p ~p~n", [Handle, Data]),
    {reply, handle_no_match, Socket}.



%%玩家列表
read(<<L:16, 10002:16, Num:16, Bin/binary>>) ->
    io:format("client read: ~p ~p ~p~n", [L, 10002, Num]),
    F = fun(Bin1) ->
        <<Id:32, S:16, C:16, Sex:16, Lv:16, Bin2/binary>> = Bin1,
        {Name, Rest} = read_string(Bin2),
        io:format("player list: Id=~p Status=~p Pro=~p Sex=~p Lv=~p Name=~p~n", [Id, S, C, Sex, Lv, Name]),
        Rest
    end,
    for(0, Num, F, Bin),
    io:format("player list end.~n");

read(<<L:16, Cmd:16>>) ->
    io:format("client read: ~p ~p~n", [L, Cmd]);
read(<<L:16, Cmd:16, Status:16>>) ->
    io:format("client read: ~p ~p ~p~n", [L, Cmd, Status]);
read(<<L:16, Cmd:16, Bin/binary>>) ->
    io:format("client read: ~p ~p ~p~n", [L, Cmd, Bin]);
%    case Cmd of
%        40002 ->
%            <<Status:16, Left/binary>> = Bin,
%            io:format("client read: ~p ~p ~p~n", [L, Cmd, Status]),
%            read(Left);
%        true -> io:format("client read: ~p ~p ~p~n", [L, Cmd, Bin])
%    end;
read(<<L:16, Cmd:16, Status:16, Bin/binary>>) ->
    io:format("client read: ~p ~p ~p ~p~n", [L, Cmd, Status, Bin]);
read(Bin) ->
    io:format("client rec: ~p~n", [Bin]).


rec(Socket) ->
    %%io:format("rec start...~n"),
    receive
        %%flash安全沙箱
        {tcp, Socket, <<"<cross-domain-policy><allow-access-from domain='*' to-ports='*' /></cross-domain-policy>">>} ->
             io:format("rec: ~p~n", ["flash_file"]);
        {tcp, Socket, Bin} ->
            io:format("rec: ~p~n", [Bin]),
            read(Bin);
        {tcp_closed, Socket} ->
            io:format("client recv error!~n");
        {handle, Cmd, Data} ->
            handle(Cmd, Data, Socket);
        {handle, Cmd} ->
            handle(Cmd, 0, Socket);
        close ->
            gen_tcp:close(Socket);
        Any ->
            io:format("client recv error=======================>: ~p~n",[Any])
%        after 15000 ->
%            io:format("circle send: heart 10006~n"),
%            gen_tcp:send(Socket, <<4:16, 10006:16>>),
%            rec(Socket)
    end,
    rec(Socket).

%rec(Socket) ->
%    % 收取头
%     case gen_tcp:recv(Socket, 4) of
%         {ok, <<Len:16, Cmd:16>>} ->
%             BodyLen = Len - 4,
%             io:format("\nrecv header, cmd=[~p], body len=[~p]\n", [Cmd, BodyLen]),
%             % 收取体
%             case gen_tcp:recv(Socket, BodyLen) of
%                 {ok, BodyData} ->
%                     io:format("recv body, data =[~p]\n", BodyData),
%                     rec(Socket);
%                 {error, Reason} -> io:format("recv body error, reason=[~p]\n", [Reason])
%             end;
%          {error, Reason}-> io:format("recv header error, reason=[~p]\n", [Reason])
%     end.

%%读取字符串
read_string(Bin) ->
    case Bin of
        <<Len:16, Bin1/binary>> ->
            case Bin1 of
                <<Str:Len/binary-unit:8, Rest/binary>> ->
                    {binary_to_list(Str), Rest};
                _R1 ->
                    {[],<<>>}
            end;
        _R1 ->
            {[],<<>>}
    end.

 sleep(T) ->
    receive
    after T -> ok
    end.
