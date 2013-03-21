%%%---------------------------------------------
%%% @Module     : mail_test
%%% @Author     : huangyongxing
%%% @Email      : huangyongxing@yeah.net
%%% @Created    : 2010.06.12
%%% @Description: 邮件功能测试客户端（兼排行榜功能测试）
%%%---------------------------------------------
-module(mail_test).
-export([start/0, login/1]).
-compile(export_all).

%% 排行榜测试
start_rank() ->
    start(3).

%% 信件功能测试
start() ->
    {ok, [N]} = io:fread("player 1 or 2:", "~d\n"),
    start(N).

%% 开启模拟客户端
start(N) ->
    case gen_tcp:connect("localhost", 6666, [binary, {packet, 0}]) of
        {ok, Socket1} ->
            gen_tcp:send(Socket1, <<"<policy-file-request/>\0">>),
            rec(Socket1),
            gen_tcp:close(Socket1);
        {error, _Reason1} ->
            io:format("connect failed!~n")
	end,

    %%case gen_tcp:connect("113.107.160.2", 6666, [binary, {packet, 0}]) of
    case gen_tcp:connect("localhost", 6666, [binary, {packet, 0}]) of
		{ok, Socket} ->
            case N of
                1 ->
                    login(Socket),
                    %create(Socket),
                    player_list(Socket),
                    enter(Socket, 4158),    %% enter(Socket, PlayerId)
                    %load_player(Socket),
                    check_unread(Socket),   %% 进入游戏时，查询是否存在未读邮件
                    %send_mail(Socket),     %% 发送信件
                    %rec(Socket),           %% 发信给自己时接收信件通知，否则去掉
                    %feedback(Socket),      %% 玩家反馈
                    get_maillist(Socket),   %% 获取信件列表
                    get_mail(Socket),       %% 获取信件
                    get_attachment(Socket), %% 取得附件
                    del_mail(Socket),       %% 删除信件
                    ok;
                2 ->
                    login2(Socket),
                    %create2(Socket),
                    player_list(Socket),
                    enter(Socket, 2327),    %% enter(Socket, PlayerId)
                    %load_player(Socket),
                    %check_unread(Socket),  %% 进入游戏时，查询是否存在未读邮件
                    send_mail(Socket),      %% 发送信件
                    %rec(Socket),           %% 发信给自己时接收信件通知，否则去掉
                    get_maillist(Socket),   %% 获取信件列表
                    get_mail(Socket),       %% 获取信件
                    get_attachment(Socket), %% 取得附件
                    del_mail(Socket),       %% 删除信件
                    ok;
                3 ->    %% 排行榜测试                    
                    login(Socket),
                    %create(Socket),
                    player_list(Socket),
                    enter(Socket, 4158),
                    get_rank(Socket),       %% 获取排行榜
                    ok;
                4 ->
                    login(Socket),
                    player_list(Socket),
                    enter(Socket, 4158),
                    feedback(Socket),       %% 玩家反馈
                    ok;
                _ ->
                    num_error
            end;

		{error, _Reason} ->
            io:format("connect failed!~n")
	end.

%%登陆
login(Socket) ->
    L = byte_size(
        <<1:16, 10000:16, 710877:32, 1281088363:32, 6:16, "710877", 32:16, "1e579548d27f6826638ff7a29c6784fe">>),
    gen_tcp:send(Socket,
        <<L:16, 10000:16, 710877:32, 1281088363:32, 6:16, "710877", 32:16, "1e579548d27f6826638ff7a29c6784fe">>),
    rec(Socket).

login2(Socket) ->
    % Ticket = util:md5(integer_to_list(AccId)++AccName++integer_to_list(Timestamp)++"SDFSDESF123DFSDF").
    L = byte_size(
        <<1:16, 10000:16, 123369:32, 1281088363:32, 6:16,"123369", 32:16, "f7ccf58440aabe178e3db295d9effe4e">>),
    gen_tcp:send(Socket,
        <<L:16, 10000:16, 123369:32, 1281088363:32, 6:16,"123369", 32:16, "f7ccf58440aabe178e3db295d9effe4e">>),
    rec(Socket).

%%创建角色
create(Socket) ->
    L = byte_size(<<1:16, 10003:16, 2:8, 1:8, 1:8, 3:16, "極">>),
    gen_tcp:send(Socket, <<L:16, 10003:16, 2:8, 1:8, 1:8, 3:16, "極">>),
    rec(Socket).

create2(Socket) -> 
    L = byte_size( <<1:16, 10003:16, 3:8, 3:8, 2:8, 5:16, "stone">>),
    gen_tcp:send(Socket, <<L:16, 10003:16, 3:8, 3:8, 2:8, 5:16, "stone">>),
    rec(Socket).

%%玩家列表
player_list(Socket) ->
    gen_tcp:send(Socket, <<6:16,10002:16,1:16>>),
    rec(Socket).

%%选择角色进入
enter(Socket) ->
    gen_tcp:send(Socket, <<8:16, 10004:16, 1:32>>),
    %gen_tcp:send(Socket, <<10004:16, 20:32>>),
    rec(Socket).

%%选择角色进入
enter(Socket, N) ->
    gen_tcp:send(Socket, <<8:16, 10004:16, N:32>>),
    rec(Socket).

%%加载场景
load_scene(Socket) ->
    io:format("send:12002~n"),
    gen_tcp:send(Socket, <<6:16,12002:16,1:16>>),
    rec(Socket).

%%用户信息
load_player(Socket) ->
    gen_tcp:send(Socket, <<4:16,13001:16>>),
    rec(Socket).

%%人攻击怪
attack_mon(Socket) ->
    io:format("send:20001~n"),
    gen_tcp:send(Socket, <<10:16,20002:16,1:32,1:16>>),
    rec(Socket).

%% 查询有无未读邮件
check_unread(Socket) ->
    io:format("send:19005, check unread~n"),
    gen_tcp:send(Socket, <<4:16, 19005:16>>),
    rec(Socket).

%% 玩家反馈
feedback(Socket) ->
    Type = util:rand(1, 4),
    Title = integer_to_list( util:rand(1000, 9999) ),
    {{Year, Month, Day}, {Hour, Minute, Second}} = erlang:localtime(),
    Content = lists:concat([Year, "-", Month, "-", Day, " ", Hour, ":", Minute, ":", Second]),
    BinTitle = list_to_binary(Title),
    BinContent = list_to_binary(Content),
    Len1 = byte_size(BinTitle),
    Len2 = byte_size(BinContent),
    L = byte_size(<<1:16, 19:16, 1:16, Len1:16, BinTitle/binary, Len2:16, BinContent/binary>>),
    io:format("send:19010, feedback!~n"),
    gen_tcp:send(Socket, <<L:16, 19010:16, Type:16, Len1:16, BinTitle/binary, Len2:16, BinContent/binary>>),
    rec(Socket).

%% 发送信件
send_mail(Socket) ->
    {{Year, Month, Day}, {Hour, Minute, Second}} = erlang:localtime(),
    Content2 = lists:concat([Year, "-", Month, "-", Day, " ", Hour, ":", Minute, ":", Second]),
    Content = list_to_binary(Content2),
    Len = byte_size(Content),
    Title = integer_to_list(util:rand(100, 999)),
    BinTitle = list_to_binary(Title),
    LenTitle = byte_size(BinTitle),
    % L = byte_size(<<1:16, 19001:16, 3:16, 5:16, "stone", 3:16, "極", 6:16, "noname", LenTitle:16, BinTitle/binary, Len:16, Content/binary, 0:32, 0:32, 0:32>>),
    L = byte_size(<<1:16, 19001:16, 1:16, 3:16, "極", LenTitle:16, BinTitle/binary, Len:16, Content/binary, 0:32, 0:32, 0:32>>),
    io:format("send:19001~n"),
    gen_tcp:send(Socket, <<L:16, 19001:16, 1:16, 3:16, "極", LenTitle:16, BinTitle/binary, Len:16, Content/binary, 48018:32, 10:32, 0:32>>),
    io:format("send 19001 over!~n"),
    rec(Socket).

%% 获得信件列表
get_maillist(Socket) ->
    % {ok, [Type]} = io:fread('Input the type:',"~d\n"),      %%0全1系统2私人
    % {ok, [State]} = io:fread('Input the state:', "~d\n"),    %%0全1未读2已读
    % {ok, [PageNum]} = io:fread('Input the page number:', "~d\n"),    %%页码
    io:format("send:19004, get maillist~n"),
    % gen_tcp:send(Socket, <<10:16, 19004:16, Type:16, State:16, PageNum:16>>),
    gen_tcp:send(Socket, <<4:16, 19004:16>>),
    rec(Socket).

%% 获得信件
get_mail(Socket) ->
    {ok, [Id]} = io:fread('Input id:', "~d\n"),
    io:format("send:19002, get mail~n"),
    gen_tcp:send(Socket, <<8:16, 19002:16, Id:32>>),
    rec(Socket).

%% 删除信件
del_mail(Socket) ->
    % {ok, [Ch]} = io:fread('all delete(0) or some delete(1)?', "~d\n"),
    % case Ch of
        % 0 ->
            % {ok, [Type]} = io:fread('Input the Type(0~2)?', "~d\n"),
            % {ok, [State]} = io:fread('Input the State(0~2)?', "~d\n"),
            % io:format("send:19003, delete all mail~n"),
            % gen_tcp:send(Socket, <<10:16, 19003:16, 0:16, Type:16, State:16>>),
            % rec(Socket);
        % 1 ->
            {ok, [Id1]} = io:fread('The first id which you want to delete:', "~d\n"),
            {ok, [Id2]} = io:fread('The second id which you want to delete:', "~d\n"),
            io:format("send:19003, delete some mail~n"),
            gen_tcp:send(Socket, <<14:16, 19003:16, 2:16, Id1:32, Id2:32>>),
            rec(Socket).
        % _ ->
            % error
    % end.

%% 提取附件
get_attachment(Socket) ->
    {ok, [Id]} = io:fread('Input the id of mail:', "~d\n"),
    io:format("send:19006, get attachment~n"),
    gen_tcp:send(Socket, <<8:16, 19006:16, Id:32>>),
    rec(Socket).

%% 获取排行榜
get_rank(Socket) ->
    {ok, [Option]} = io:fread('1.RoleRank, 2.EquipRank, 3.Guild, please select:', "~d\n"),
    case Option of
        1 ->
            {ok, [Realm]}  = io:fread('Input the Realm:', "~d\n"),
            {ok, [Career]} = io:fread('Input the Career:', "~d\n"),
            {ok, [Type]}   = io:fread('Input the Type:', "~d\n"),
            io:format("send 22001, get roles rank~n"),
            gen_tcp:send(Socket, <<7:16, 22001:16, Realm:8, Career:8, Type:8>>);
        2 ->
            {ok, [Type]}   = io:fread('Input the Type:', "~d\n"),
            io:format("send 22002, get equip rank~n"),
            gen_tcp:send(Socket, <<5:16, 22002:16, Type:8>>);
        3 ->
            {ok, [Type]}   = io:fread('Input the Type:', "~d\n"),
            io:format("send 22003, get guild rank~n"),
            gen_tcp:send(Socket, <<5:16, 22003:16, Type:8>>);
        _ ->
            io:format("Input error!~n")
    end,
    rec(Socket).

%% 读取列表，列表每项：[Id, State, Timestamp, SName, Title, Kind]
%% 对应：<<Id:32, State:16, Timestamp:32, Len1:16, SName/binary, Len2:16, Title/binary, Kind:16>>
%% AccList 列表累加器，使用时初始为[]
get_list(AccList, Bin, N) when N>0 ->
    case Bin of
        <<Id:32, Type:16, State:16, Timestamp:32, Len1:16, Rest/binary>> ->
            <<SName1:Len1/binary-unit:8, Len2:16, Rest2/binary>> = Rest,
            <<Title1:Len2/binary-unit:8, Kind:16, Rest3/binary>> = Rest2,
            SName2 = binary_to_list(SName1),
            Title2 = binary_to_list(Title1),
            Item = [Id, Type, State, Timestamp, SName2, Title2, Kind],
            %io:format("Item: ~p~n", [Item]),
            NewList = [Item | AccList],
            get_list(NewList, Rest3, N - 1);
        _R1 ->
            error
    end;
get_list(AccList, Bin, _) ->
    {lists:reverse(AccList), Bin}.

%% 读取列表，列表每项：[Rank, Id, Name, Sex, Career, Realm, Guild, Value]
get_list2(AccList, Bin, N) when N>0 ->
    case Bin of
        <<Rank:16, Id:32, Len1:16, Rest/binary>> ->
            <<Nick:Len1/binary-unit:8, Sex:8, Career:8, Len2:16, Rest2/binary>> = Rest,
            <<GuildName:Len2/binary-unit:8, Value:32, Rest3/binary>> = Rest2,
            Name = binary_to_list(Nick),
            Guild = binary_to_list(GuildName),
            Item = [Rank, Id, Name, Sex, Career, Guild, Value],
            %io:format("Item: ~p~n", [Item]),
            NewList = [Item | AccList],
            get_list2(NewList, Rest3, N - 1);
        _R1 ->
            io:format("match error!~n"),
            error
    end;
get_list2(AccList, Bin, _) ->
    {lists:reverse(AccList), Bin}.

%% 读取列表，列表每项：[Rank, Id, Name, PlayerId, PlayerName, Guild, Score]
get_list3(AccList, Bin, N) when N>0 ->
    case Bin of
        <<Rank:16, GoodsId:32, Len1:16, Rest/binary>> ->
            <<BinGoodsName:Len1/binary-unit:8, PlayerId:32, Len2:16, Rest2/binary>> = Rest,
            <<BinPlayerName:Len2/binary-unit:8, Len3:16, Rest3/binary>> = Rest2,
            <<BinGuild:Len3/binary-unit:8, Score:32, Rest4/binary>> = Rest3,
            GoodsName = binary_to_list(BinGoodsName),
            PlayerName = binary_to_list(BinPlayerName),
            Guild = binary_to_list(BinGuild),
            Item = [Rank, GoodsId, GoodsName, PlayerId, PlayerName, Guild, Score],
            %io:format("Item: ~p~n", [Item]),
            NewList = [Item | AccList],
            get_list3(NewList, Rest4, N - 1);
        _R1 ->
            error
    end;
get_list3(AccList, Bin, _) ->
    {lists:reverse(AccList), Bin}.

%% 读取列表，列表每项：[Rank, Id, Name, Realm, Level]
get_list4(AccList, Bin, N) when N>0 ->
    case Bin of
        <<Rank:16, Id:32, Len1:16, Rest/binary>> ->
            <<BinName:Len1/binary-unit:8, Realm:8, Level:8, Rest2/binary>> = Rest,
            GuildName = binary_to_list(BinName),
            Item = [Rank, Id, GuildName, Realm, Level],
            %io:format("Item: ~p~n", [Item]),
            NewList = [Item | AccList],
            get_list4(NewList, Rest2, N - 1);
        _R1 ->
            error
    end;
get_list4(AccList, Bin, _) ->
    {lists:reverse(AccList), Bin}.

rec(Socket) ->
    receive
        {tcp, Socket, <<"<cross-domain-policy><allow-access-from domain='*' to-ports='*' /></cross-domain-policy>">>} -> 
            io:format("revc : ~p~n", ["flash_file"]);

        %% 发信后接收服务端返回
        {tcp, Socket, <<_L:16, 19001:16, Bin/binary>>} ->
            <<Result:16, Rest/binary>> = Bin,
            case Result of
                6 ->
                    <<Num:16, Rest2/binary>> = Rest,
                    {NameList, _} = pt_19:get_list([], Rest2, Num),
                    io:format("recv: [19001, ~w], failed namelist: ~p~n", [Result, NameList]);
                _ ->
                    io:format("recv: [19001, ~w]~n", [Result])
            end;

        %% 收信
        {tcp, Socket, <<_L:16, 19002:16, Result:16, Bin/binary>>} ->
            case Result of
                2 ->
                    io:fwrite("Failed, the mail is not existed~n");
                3 ->
                    io:fwrite("failed, read mail error");
                1 ->
                    <<_Id:32, _Timestamp:32, L1:16, BinSName:L1/binary-unit:8, L2:16, BinTitle:L2/binary-unit:8, Len:16, BinContent:Len/binary-unit:8, GoodsTypeId:32, GoodsNum:32, Coin:32, Silver:32>> = Bin,
                    SName = binary_to_list(BinSName),
                    Title = binary_to_list(BinTitle),
                    Content = binary_to_list(BinContent),
                    io:fwrite("sname: ~p, title: ~p, content: ~p, goods_type_id:~p, goods_num:~p, coin:~p, silver:~p~n", [SName, Title, Content, GoodsTypeId, GoodsNum, Coin, Silver]);
                _ ->
                    io:fwrite("Unknown error!~n")
            end;

        %% 删除信件
        {tcp, Socket, <<_L:16, 19003:16, Bin/binary>>} ->
            io:format("delete mail~n"),
            case Bin of
                <<Result:16>> ->
                    case Result of
                        0 ->
                            io:format("Failed to delete the mail!~n");
                        1 ->
                            io:format("Finished successfully!~n")
                    end;
                _ ->
                    io:format("Unknown error!~n")
            end;

        %% 信件列表请求
        {tcp, Socket, <<_L:16, 19004:16, Result:16, Timestamp:32, Num:16, Bin/binary>>} ->
            case Result of
                0 ->
                    io:format("failed to get maillist!~n");
                1 ->
                    case Num of
                        0 ->
                            io:format("The maillist is empty!~n");
                        _ ->
                            io:format("current timestamp: ~w~n", [Timestamp]),
                            case Num > 10 of
                                true ->
                                    {Maillist, _} = get_list([], Bin, 10);
                                false ->
                                    {Maillist, _} = get_list([], Bin, Num)
                            end,
                            io:format("the top 10 mail in maillist: ~p~n", [Maillist])
                    end;
                _ ->
                    io:format("recv: [19004, ~w], error~n", [Result])
            end;

        %% 收到新信件的通知
        {tcp, Socket, <<4:16, 19005:16, Result:16>>} ->
            case Result of
                0 ->
                    io:format("recv: [19005, 0], no unread mail~n");
                1 ->
                    io:format("recv: [19005, 1], any unread mail in your mailbox~n")
            end;

        %% 提取附件
        {tcp, Socket, <<_L:16, 19006:16, Result:16, _MailId:32>>} ->
            io:format("recv: [19006, ~w], get attachment!~n", [Result]);

        %% 玩家反馈
        {tcp, Socket, <<_L:16, 19010:16, Result:16>>} ->
            io:format("feedback! [19010, ~p]~n", [Result]);

        %% 获取角色属性排行榜
        {tcp, Socket, <<_L:16, 22001:16, Num:16, BinList/binary>>} ->
            io:format("recv:22001, Num:~p~n", [Num]),
            %io:format("BinList:~p~n", [BinList]),
            case Num > 10 of
                true ->
                    {RankList, _} = get_list2([], BinList, 10);     %% if Num >= 10
                false ->
                    {RankList, _} = get_list2([], BinList, Num)
            end,
            io:format("the top 10 of the rank:~p~n", [RankList]);

        %% 获取装备排行榜
        {tcp, Socket, <<_:16, 22002:16, Num:16, BinList/binary>>} ->
            io:format("recv 22002, Num:~p~n", [Num]),
            case Num > 10 of
                true ->
                    {RankList, _} = get_list3([], BinList, 10);     %% if Num >= 10
                false ->
                    {RankList, _} = get_list3([], BinList, Num)
            end,
            io:format("the top 10 of the rank:~p~n", [RankList]);

        %% 获取帮会排行榜
        {tcp, Socket, <<_:16, 22003:16, Num:16, BinList/binary>>} ->
            io:format("recv 22003, Num:~p~n", [Num]),
            case Num > 10 of
                true ->
                    {RankList, _} = get_list4([], BinList, 10);     %% if Num >= 10
                false ->
                    {RankList, _} = get_list4([], BinList, Num)
            end,
            io:format("the top 10 of the rank:~p~n", [RankList]);

        %% 刷新背包
        {tcp, Socket, <<_L:16, 15001:16, _Rest/binary>>} ->
            io:format("recv:15001, refresh client!~n"),
            rec(Socket);

        %% 怪物移动
        {tcp, Socket, <<_L:16, 12008:16, _Bin/binary>>} ->
            io:format("recv 12008~n"),
            rec(Socket);

        %%用户信息
        {tcp, Socket, <<_L:16,13001:16, Scene:32, X:16, Y:16, Id:32, Hp:32, Hp_lim:32, Mp:32, Mp_lim:32,Sex:16, Lv:16, Bin/binary>>} -> 
            {Nick, _} = read_string(Bin),
            io:format("revc player info:~p~n",[[Scene,X,Y,Id,Hp,Hp_lim,Mp,Mp_lim,Sex,Lv,Nick]]);

        %%场景
        {tcp, Socket, <<_L:16,12002:16, Bin/binary>>} -> 
            <<L:16, Bin22/binary>> = Bin,
            F = fun(Bin3) ->
                <<X1:16, Y1:16, Uid1:32, Bin4/binary>> = Bin3,
                {Nick1, Bin5} = read_string(Bin4),
                io:format("revc scene user online :~p~n",[[X1,Y1,Uid1,Nick1]]),
                Bin5
            end,
            Bin2 = for(0, L, F, Bin22),

            <<L2:16, Bin222/binary>> = Bin2,
            F2 = fun(Bin32) ->
                <<X1:16, Y1:16, Uid1:32,_,_,_,_,_, Bin4/binary>> = Bin32,
                {Nick1, Bin5} = read_string(Bin4),
                io:format("revc scene mon online :~p~n",[[X1,Y1,Uid1,Nick1]]),
                Bin5
            end,
            for(0, L2, F2, Bin222);

        {tcp, Socket, <<_L:16,Cmd:16, Bin:16>>} -> 
            io:format("revc : ~p~n", [[Cmd, Bin]]);

        %复活
        {tcp, Socket, <<_L:16, Cmd:16, _X:16, _Y:16, Id:32, Hp:32, Mp:32, _Hp_lim:32, _Mp_lim:32, Lv:16, _Len:16, _Name1/binary>>} ->
            io:format("revc revive: ~p:~p~n", [Cmd, [Id, Hp, Mp, Lv]]);

        %战斗结果
        {tcp, Socket, <<_L:16, _Cmd:16, Id:32, Id2:32, Hp:32, S:16>>} ->
            io:format("revc battle: ~p,~p,~p,~p~n", [Id, Id2, Hp, S]),
            rec(Socket);

        %%角色列表啊
        {tcp, Socket, <<_L:16,10002:16, Len:16, Bin/binary>>} -> 
            F = fun(Bin2) ->
                <<Id:32, S:16, C:16, Sex:16, Lv:16, L:16, Bin1/binary>> = Bin2,
                io:format("revc player list: ~p", [[10002, Id, S,C,Sex,Lv,L]]),
                <<Str:L/binary-unit:8, Rest/binary>> = Bin1,
                io:format("~p~n", [Str]),
                Rest
            end,
            for(0, Len, F, Bin);

        {tcp, Socket, <<_L:16, Cmd:16, _Bin/binary>>} ->
            io:format("recv: ~p~n", [Cmd]);

        {tcp_closed, Socket} ->
            gen_tcp:close(Socket)
    end.

for(Max, Max, _F, X) ->
    X;
for(Min, Max, F, X) ->
    X1 = F(X),
    for(Min+1, Max, F, X1).

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
