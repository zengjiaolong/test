%%%------------------------------------
%%% @Module     : lib_mail
%%% @Author     : huangyongxing
%%% @Email      : huangyongxing@yeah.net
%%% @Created    : 2010.05.24
%%% @Description: 信件处理函数
%%%------------------------------------
-module(lib_mail).
%-compile(export_all).
-export(
    [
        check_mail_time/0,      %% 检查信件有效期
        check_unread/1,         %% 查询是否存在未读信件
        del_mail/2,             %% 删除信件
        execute/1,              %% 执行一条Sql语句
        feedback/6,             %% 玩家反馈（GM提交）
        get_attachment/2,       %% 获取附件
      % get_goods_icon/1,       %% 获取图标号
        get_goods_type_id/1,    %% 获取物品类型ID
        get_mail/2,             %% 获取邮件
        get_maillist/1,         %% 获取邮件列表
        new_mail_notify/1,      %% 新邮件到达通知
        rand_insert_mail/3,     %% 随机插入信件（测试用）
        refresh_client/5,       %% 刷新客户端背包
        refresh_client/2,       %% 刷新客戶端
        send_priv_mail/7,       %% 发送私人邮件
        send_sys_mail/7,        %% 发送系统邮件
        make_insert_sql/3       %% 生成插入语句
    ]).
-include("common.hrl").
-include("record.hrl").

-define(OTHER_ERROR,           0).  %% 其它错误
-define(WRONG_TITLE,           2).  %% 标题错误
-define(WRONG_CONTENT,         3).  %% 内容错误
-define(CANNOT_SEND_ATTACH,    4).  %% 不能发送附件
-define(WRONG_NAME,            5).  %% 无合法收件人
-define(NOT_ENOUGH_COIN,       7).  %% 金钱不足
-define(GOODS_NUM_NOT_ENOUGH,  8).  %% 物品数量不足
-define(GOODS_NOT_EXIST,       9).  %% 物品不存在
-define(GOODS_NOT_IN_PACKAGE, 10).  %% 物品不在背包
-define(ATTACH_CANNOT_SEND,   11).  %% 附件不能发送

-define(NOT_ENOUGH_SPACE,      2).  %% 背包已满
-define(ATTACH_NOT_EXIST,      3).  %% 信件中不存在附件
-define(GOODS_NOT_EXIST_2,     4).  %% 信件中物品不存在

-define(POSTAGE, 50).               %% 邮资
-define(MAX_NUM, 50).               %% 每个用户信件数量上限

%% 添加在线物品（背包中的）
add_online_goods(GoodsId) ->
    case get_goods_by_id(GoodsId) of
        {ok, []} ->     %% 物品不存在
            ok;
        {ok, [GoodsInfo]} ->
            Goods = list_to_tuple([goods | GoodsInfo]),
            ets:insert(?ETS_GOODS_ONLINE, Goods);
        error ->
            ?ERR("~n*******Execute ~p:~p/1 error!*******~n", [?MODULE, add_online_goods]),
            ok
    end.

%% 检查内容（限制500汉字）
check_content(Content) ->
    check_length(Content, 1000).

%% 长度合法性检查
check_length(Item, LenLimit) ->
    case asn1rt:utf8_binary_to_list(list_to_binary(Item)) of
        {ok, UnicodeList} ->
            Len = string_width(UnicodeList),   
            Len =< LenLimit andalso Len >= 1;
        {error, _Reason} ->
            error
    end.

%% 检查信件是否合法，如合法，返回有效的角色名列表与无效的角色名列表
%% @spec check_mail(NameList, Title, Content, GoodsId, Coin, Silver) ->
%%          {ok, Name} | {error, Position} | {VList, IList}
check_mail(NameList, Title, Content, GoodsId, Coin, Silver) ->
    case check_title(Title) of  %% 检查标题合法性
        true ->
            case check_content(Content) of  %% 检查内容合法性
                true ->
                    F = fun(Item) ->
                            case is_binary(Item) of
                                true ->     %% 二进制数据转换为字符串
                                    binary_to_list(Item);
                                false ->    %% 无须转换
                                    Item
                            end
                    end,
                    NewNameList = [F(Nick) || Nick <- NameList],
                    case length(NewNameList) of
                        1 ->
                            [Name] = NewNameList,
                            case check_name(Name) of
                                true ->
                                    {ok, Name};
                                false ->
                                    {error, ?WRONG_NAME}
                            end;
                        _ ->
                            case GoodsId == 0 andalso Coin == 0 andalso Silver == 0 of
                                true ->
                                    {VList, IList} = lists:partition(fun check_name/1, NewNameList),
                                    case VList of
                                        [] ->
                                            {error, ?WRONG_NAME};
                                        _ ->
                                            {VList, IList}
                                    end;
                                false ->    %% 发信给多人有附件，不合法
                                    {error, ?CANNOT_SEND_ATTACH}
                            end
                    end;
                false ->
                    {error, ?WRONG_CONTENT};       %% 内容长度非法
                error ->
                    {error, ?WRONG_CONTENT}
            end;
        false ->
            {error, ?WRONG_TITLE};     %% title长度非法
        error ->
            {error, ?WRONG_TITLE}
    end.

%% 获得信件id进行信件时间检查
check_mail_time() ->
    Sql = "select id from mail",    %% 获得所有信件的id
    case execute(Sql) of
        {ok, []} ->
            ok;
        error ->
            ?ERR("~n*******Execute ~p:~p/0 error!*******~n", [?MODULE, check_mail_time]);
        {ok, ItemList} ->
            lists:foreach(fun(Item) -> [Id] = Item, check_mail_time(Id) end, ItemList)
    end.

%% 根据信件Id对该信件进行期限检查
check_mail_time(Id) ->
    SqlGetMail = io_lib:format(<<"select * from mail where id = ~p limit 1">>, [Id]),
    case execute(SqlGetMail) of
        {ok, []} ->
            ok;
        error ->
            ok;
        {ok, [Mail]} ->
            [_, _, _, Timestamp, _, _, _, _, _, _, _, _] = Mail,
            CurrTimestamp = util:unixtime(),            %% 当前时间戳
            TimeSpan = CurrTimestamp - Timestamp,       %% 时间差
            case TimeSpan >= 604800 of                  %% 信件一周(604800秒)到期
                true ->
                    del_one_mail(Mail);
                false ->
                    ok
            end
    end.

%% 检查角色名长度合法性，合法则查询是否存在角色
check_name(Name) ->
    case check_length(Name, 11) of
        true ->
            lib_player:is_exists(Name);     %% 存在true，不存在false
        _Other ->       %% false与error
            false
    end.

%% 检查主题长度（限制25汉字）
check_title(Title) ->
    check_length(Title, 50).

%% 检查邮件中是否存在未读邮件
%% @spec check_unread(UId) -> false | true
check_unread(UId) ->
    Sql = io_lib:format(<<"select * from mail where uid = ~p and state = 2">>, [UId]),
    case execute(Sql) of
        {ok, []} ->
            false;
        {ok, _} ->
            true;
        _ ->
            false
    end.

%% 删除物品
del_goods(GoodsId) ->
    Sql = io_lib:format(<<"delete from goods where id = ~p">>, [GoodsId]),
    execute(Sql).

%% 删除信件
%% @spec del_mail(IdList, PlayerId) -> ok | error
del_mail(IdList, PlayerId) when is_list(IdList) ->    %% 根据客户端发送的信件id列表删除信件
    Maillist = get_maillist_by_id_list(IdList, PlayerId),
    lists:foreach(fun(Mail) -> del_one_mail(Mail) end, Maillist);
del_mail(_, _) ->
    error.

%% 从数据库中删除信件
del_mail_from_database(MailId) ->
    Sql = io_lib:format(<<"delete from mail where id = ~p">>, [MailId]),
    execute(Sql).

%% 删除一封信件，退回附件
del_one_mail(Mail) ->
    [MailId, Type, _, Timestamp, BinSName, UId, _, _, GoodsId, GoodsNum, Coin, Silver] = Mail,
    F1 = fun() ->               %% 不退回附件删除信件
            del_mail_from_database(MailId),
            case GoodsId of
                0 ->
                    ok;
                _ ->
                    del_goods(GoodsId)
            end
    end,
    F2 = fun() ->               %% 退回附件删除信件
            Nick = binary_to_list(BinSName),
            case get_player_id(Nick) of
                {ok, []} ->     %% 发件人角色不存在
                    F1();       %% 删除信件，如果存在附件则丢弃
                {ok, [[UId2]]} ->
                    case get_player_name(UId) of
                        {ok, []} ->
                            Name = "对方";
                        {ok, [[Any]]} ->
                            Name = binary_to_list(Any);
                        error ->
                            Name = "对方"
                    end,
                    Type2 = 1,
                    Timestamp2 = util:unixtime(),
                    SName2 = "系统",
                    Title2 = "退回附件",
                    OldTime = calendar:now_to_local_time({Timestamp div 1000000, Timestamp rem 1000000, 0}),
                    {{Year, Month, Day}, {Hour, Minute, Second}} = OldTime,
                    Content2 = lists:concat([Nick, "：\n    ", "您于", Year, "-", Month, "-", Day, " ", Hour, ":", Minute, ":", Second, "发送的信件包含附件，", Name, "未提取您发送的附件，请于7天内取回附件!"]),
                    case insert_mail(Type2, Timestamp2, SName2, UId2, Title2, 
                            Content2, GoodsId, GoodsNum, Coin, Silver) of
                        ok ->
                            {ok, Bin} = pt_19:write(19005, 1),
                            lib_send:send_to_uid(UId2, Bin), %% 给通知原信件发件人收到新信件
                            del_mail_from_database(MailId),  %% 删除信件
                            mail_num_limit(UId2);            %% 检查该用户信件数量
                        _ ->        %% 物品丢失（实际上仍在表goods中，但是物品所有人player_id变成0了）
                            ?ERR("~n*******Execute ~p:~p/1 error, id of goods: ~p, owner: ~ts*******~n", [?MODULE, del_one_mail, GoodsId, Nick])
                    end;
                error ->
                    error
            end
    end,
    case GoodsId /= 0 orelse Coin /= 0 andalso Type == 2 of
        true ->                 %% 私人信件有附件，需要退回附件
            case get_goods_by_id(GoodsId) of
                {ok, []} ->     %% 附件物品实际不存在
                    case Coin == 0 of
                        true ->
                            F1();
                        false ->
                            F2()
                    end;
                {ok, _} ->
                    F2();
                error ->
                    error
            end;
        false ->
            F1()      %% 无附件或者系统邮件，附件直接删除
    end.

%% 删去在线物品（背包中）
del_online_goods(GoodsId) ->
    ets:delete(?ETS_GOODS_ONLINE, GoodsId).

%% 执行一条sql语句
%% @spec execute(Sql) -> {ok, Result} | error
execute(Sql) ->
    case mysql:fetch(?DB, Sql) of
        {data, {_, _, ResultList, _, _}} ->
            {ok, ResultList};
        {updated, _} ->
            {ok, updated};
        {error, {_, _, _, _, Reason}} ->
            ?ERR("~n[Database Error]: ~nQuery:   ~ts~nError:   ~ts", [Sql, Reason]),
            error
    end.

%% 插入玩家反馈至数据库的feedback表
%% @spec feedback(Type, Title, Content, Address, PlayerId, PlayerName) -> Result
%%      Result : 0 | 1
feedback(Type, Title, Content, Address, PlayerId, PlayerName) ->
    Server = atom_to_list( node() ),
    Timestamp = util:unixtime(),
    {A, B, C, D} = Address,
    IP = lists:concat([A, ".", B, ".", C, ".", D]),
    Sql = io_lib:format(<<"insert into feedback (type, player_id, player_name, title, content, timestamp, ip, server) values (~p, ~p, '~s', '~s', '~s', ~p, '~s', '~s')">>, [Type, PlayerId, PlayerName, Title, Content, Timestamp, IP, Server]),
    case execute(Sql) of
        {ok, _} -> 1;
        error   -> 0
    end.

%% 用于过滤get_goods_info_list/2中得到的列表，以得到物品类型对应的物品属性
%% @spec filter_list(B, AccList, List) -> List2
%% List2: [[A1,B,C1,D1], [A2,B,C2,D2],…], 根据列表每项（列表）的第二个元素过滤
filter_list(B, AccList, List) ->
    case List of
        [] ->
            AccList;
        _ ->
            [H | NewList] = List,
            case H of
                [_A, B, _C, _D] ->
                    filter_list(B, [H | AccList], NewList);
                _ ->
                    filter_list(B, AccList, NewList)
            end
    end.

%% 获取附件
%% @spec get_attachment(PlayerStatus, MailId) -> {ok, NewCoin, NewSilver} | {error, Reason}
get_attachment(PlayerStatus, MailId) ->
    case get_mail(MailId, PlayerStatus#player_status.id) of
        {ok, Mail} ->
            [_, _, _, _, _, _, _, _, GoodsId, GoodsNum, Coin, Silver] = Mail,
            case GoodsId == 0 andalso Coin == 0 andalso Silver == 0 of
                false ->            %% 有附件
                    case GoodsId == 0 of
                        false ->        %% 有物品
                            PlayerId = PlayerStatus#player_status.id,
                            GoodsPid = PlayerStatus#player_status.goods_pid,
                            case Coin == 0 andalso Silver == 0 of
                                true ->     %% 仅物品附件
                                    case handle_goods_recv(GoodsPid, PlayerId, GoodsId, GoodsNum) of
                                        ok ->
                                            update_mail(MailId),
                                            %NewCoin = PlayerStatus#player_status.coin,
                                            %NewSilver = PlayerStatus#player_status.silver,
                                            %NewGold = PlayerStatus#player_status.gold,
                                            %refresh_client(4, NewCoin, NewSilver, NewGold, PlayerStatus),%% 刷新背包
                                            refresh_client(2, PlayerStatus#player_status.socket),   %% 刷新背包
                                            ok;
                                        {error, ErrorCode} ->
                                            {error, ErrorCode}
                                    end;
                                false ->    %% 同时有物品和钱币附件
                                    case handle_goods_recv(GoodsPid, PlayerId, GoodsId, GoodsNum) of
                                        ok ->
                                            update_mail(MailId),
                                            %NewCoin = PlayerStatus#player_status.coin + Coin,
                                            %NewSilver = PlayerStatus#player_status.silver + Silver,
                                            %NewGold = PlayerStatus#player_status.gold,
                                            %handle_money(PlayerStatus, NewCoin, NewSilver),
                                            %refresh_client(4, NewCoin, NewSilver, NewGold, PlayerStatus),
                                            refresh_client(2, PlayerStatus#player_status.socket),   %% 刷新背包
                                            ok;
                                        {error, ErrorCode} ->
                                            {error, ErrorCode}
                                    end
                            end;
                        true ->             %% 只有钱币
                            update_mail(MailId),
                            NewCoin = PlayerStatus#player_status.coin + Coin,
                            NewSilver = PlayerStatus#player_status.silver + Silver,
                            %NewGold = PlayerStatus#player_status.gold,
                            %case handle_money(PlayerStatus, NewCoin, NewSilver) of
                            %    ok ->
                            %        refresh_client(4, NewCoin, NewSilver, NewGold, PlayerStatus),
                            %        ok;
                            %    {error, ErrorCode} ->
                            %        {error, ErrorCode}
                            %end
                            handle_money(PlayerStatus, NewCoin, NewSilver),
                            refresh_client(2, PlayerStatus#player_status.socket)   %% 刷新背包
                    end;
                true ->             %% 无附件
                    {error, ?ATTACH_NOT_EXIST}
            end;
        {error, _} ->
            {error, ?OTHER_ERROR}
    end.

%% 找出信件列表中最早发送的一封
%% （先取列表中的第一封作为初始最早期信件进行比较）
%% @spec get_earliest_mail(Maillist) -> error | Mail
get_earliest_mail(Maillist) ->
    case Maillist of
        [] ->
            error;
        _ ->
            [Mail | NewMaillist] = Maillist,
            get_earliest_mail(Mail, NewMaillist)
    end.

%% 找出信件列表中最早发送的一封
%% @spec get_earliest_mail(Mail, Maillist) -> EarliestMail
get_earliest_mail(Mail, []) ->
    Mail;
get_earliest_mail(EarliestMail, Maillist) ->
    [Mail | NewMaillist] = Maillist,
    Timestamp  = lists:nth(4, EarliestMail),
    Timestamp2 = lists:nth(4, Mail),
    case Timestamp2 < Timestamp of
        true ->
            get_earliest_mail(Mail, NewMaillist);
        false ->
            get_earliest_mail(EarliestMail, NewMaillist)
    end.

%%% 获得物品图标号
%%% @spec get_goods_icon(GoodsId) -> Icon
%%% Icon : binary()
%get_goods_icon(GoodsId) ->
%    Sql = io_lib:format(<<"select base_goods.icon from goods inner join base_goods on goods.goods_id = base_goods.goods_id and goods.id = ~p limit 1">>, [GoodsId]),
%    case execute(Sql) of
%        {ok, []} ->     %% 物品不存在
%            <<"">>;
%        {ok, [[Icon]]} ->
%            Icon;
%        error ->
%            <<"">>
%    end.

%% 查询物品信息
%% @spec get_goods_by_id(GoodsId) -> GoodsInfo
get_goods_by_id(GoodsId) ->
    Sql = io_lib:format(<<"select * from goods where id = ~p limit 1">>, [GoodsId]),
    execute(Sql).

%% 获得背包中的物品的id, goods_id、cell及num属性的列表
%% @spec get_goods_info_list(PlayerId, Location) -> [Object]
%% Object = [GoodsId, GoodsTypeId, GoodsCell, GoodsNum]
get_goods_info_list(PlayerId, Location) ->
    Pattern = #goods{id = '$1', goods_id = '$2', cell = '$3', num = '$4', player_id = PlayerId, location = Location, _ = '_'},
    ets:match(?ETS_GOODS_ONLINE, Pattern).

%% 获得物品类型ID（goods.goods_id）
get_goods_type_id(GoodsId) ->
    Sql = io_lib:format(<<"select goods_id from goods where id = ~p limit 1">>, [GoodsId]),
    execute(Sql).

%% 获取信件
%% @spec get_mail(MailId, PlayerId) -> {ok, Mail} | {error, ErrorCode}
get_mail(MailId, PlayerId) ->
    Sql = io_lib:format(<<"select * from mail where id = ~p and uid = ~p limit 1">>, [MailId, PlayerId]),
    case execute(Sql) of
        {ok, [Mail]} ->
            [_, _, State, _, _, _, _, _, _, _, _, _] = Mail,
            case State of
                2 ->
                    Sql2 = io_lib:format(<<"update mail set state = 1 where id = ~p">>, [MailId]),
                    execute(Sql2),      %% 更新信件状态为已读
                    {ok, Mail};
                _ ->
                    {ok, Mail}
            end;
        {ok, []} ->
            {error, 2};
        error ->
            {error, 3}
    end.

%% 获取用户信件列表
%% @spec get_maillist(PlayerId) -> Maillist | db_error
get_maillist(UId) ->
    Sql = io_lib:format(<<"select * from mail where uid = ~p">>, [UId]),
    execute(Sql).

%% 根据信件Id列表及角色Id获取对应信件列表
%% @spec get_maillist_by_id_list(IdList, PlayerId) -> Maillist
get_maillist_by_id_list(IdList, PlayerId) ->
    NewIdList = lists:usort(IdList),            %% 去除重复元素
    get_maillist_by_id_list([], NewIdList, PlayerId).

%% 根据信件Id列表及角色Id获取对应信件列表
get_maillist_by_id_list(AccMaillist, [], _) ->
    AccMaillist;
get_maillist_by_id_list(AccMaillist, IdList, PlayerId) ->
    [Id | NewIdList] = IdList,
    Sql = io_lib:format(<<"select * from mail where id = ~p and uid = ~p limit 1">>, [Id, PlayerId]),
    case execute(Sql) of
        {ok, []} ->     %% 该id信件不存在
            get_maillist_by_id_list(AccMaillist, NewIdList, PlayerId);
        {ok, [Mail]} -> %% 获得对应信件
            get_maillist_by_id_list([Mail | AccMaillist], NewIdList, PlayerId);
        error ->        %% 读取数据库出错
            get_maillist_by_id_list(AccMaillist, NewIdList, PlayerId)
    end.

%% 将GoodsInfoList前N个项的Num值设置为Max值，剩余项的Num值设置为0，并去掉TypeId
%% 用于整理占用多个背包空间的同类物品
%% @spec get_new_goods_info_list(OldInfoList, N, Max) -> {List1, List2}
get_new_goods_info_list(OldInfoList, N, Max) ->
    case N > length(OldInfoList) of
        true ->
            NewList =  [ [GId, Cell, Max] || [GId, _, Cell, _] <- OldInfoList ],
            {NewList, []};
        false ->
            {List1, List2} = lists:split(N, OldInfoList),
            NewList1 = [ [GId, Cell, Max] || [GId, _, Cell, _] <- List1 ],
            NewList2 = [ [GId, Cell, 0  ] || [GId, _, Cell, _] <- List2 ],
            {NewList1, NewList2}
    end.

%% 根据角色名查找角色Id
%% @spec get_player_id(Name) -> {ok, [[Id]]} | {ok, []} | error
get_player_id(Name) ->
    Sql = io_lib:format(<<"select id from player where nickname = '~s' limit 1">>, [Name]),
    execute(Sql).

%% 由角色ID获得角色名
%% @spec get_player_name(Id) -> {ok, [[BinName]] | {ok, []} | error
get_player_name(Id) ->
    Sql = io_lib:format(<<"select nickname from player where id = ~p limit 1">>, [Id]),
    execute(Sql).

%% 将列表项格式化成字符串的形式（供生成插入语句时使用）
%% @spec get_string([], List) -> string()
get_string(String, []) ->
    String;
get_string(String, List) ->
    [Item | NewList] = List,
    if
        String =/= [] ->
            case is_list(Item) of
                true ->
                    NewStr = lists:concat([String, ",", "'", Item, "'"]);
                false ->
                    NewStr = lists:concat([String, ",", Item])
            end;
        true ->
            case is_list(Item) of
                true ->
                    NewStr = lists:concat(["'", Item, "'"]);
                false ->
                    NewStr = lists:concat([Item])
            end
    end,
    get_string(NewStr, NewList).

%% 处理发信时的物品附件
%% @spec handle_goods_send(GoodsPid, PlayerId, GoodsId, GoodsNum) -> {ok, NewGoodsId} | {error, ErrorCode}
handle_goods_send(GoodsPid, PlayerId, GoodsId, GoodsNum) ->
    case ets:lookup(?ETS_GOODS_ONLINE, GoodsId) of
        [Goods] ->
            case Goods#goods.bind == 2 orelse Goods#goods.trade == 1 of     %% 已绑定或者不可交易
                false ->
                    case Goods#goods.location /= 4 orelse Goods#goods.player_id /= PlayerId of     %% 不在该玩家背包
                        false ->
                            NewNum = Goods#goods.num - GoodsNum,
                            if
                                NewNum > 0 ->
                                    %% 物品分堆, 并返回新Id或者返回错误码
                                    split_goods(Goods, NewNum, GoodsNum);   %% {ok, NewId} | {error, ?OTHER_ERROR}
                                NewNum == 0 ->
                                    SqlUpdateGoods = io_lib:format(<<"update goods set player_id = 0 where id = ~p">>, [GoodsId]),
                                    case execute(SqlUpdateGoods) of
                                        {ok, _} ->
                                            del_online_goods(GoodsId), %% 把GoodsId对应物品从ets_goods_online表中去掉
                                            %% 更新背包空格列表
                                            GoodsStatus = gen_server:call(GoodsPid, {'STATUS'}),
                                            NewNullCells = lists:sort([ Goods#goods.cell | GoodsStatus#goods_status.null_cells]),
                                            NewGoodsStatus = GoodsStatus#goods_status{null_cells = NewNullCells},
                                            gen_server:cast(GoodsPid, {'SET_STATUS', NewGoodsStatus}),
                                            {ok, GoodsId};
                                        error ->
                                            {error, ?OTHER_ERROR}
                                    end;
                                NewNum < 0 ->   %% 物品数量不足
                                    {error, ?GOODS_NUM_NOT_ENOUGH}
                            end;
                        true ->
                            {error, ?GOODS_NOT_IN_PACKAGE}
                    end;
                true ->
                    {error, ?ATTACH_CANNOT_SEND}
            end;
        [] ->
            {error, ?GOODS_NOT_EXIST}
    end.

%% 处理物品附件（提取附件时）
%% @spec handle_goods_recv(GoodsPid, PlayerId, GoodsId, GoodsNum) -> ok | {error, ErrorCode}
handle_goods_recv(GoodsPid, PlayerId, GoodsId, GoodsNum) ->
    GoodsInfoList = get_goods_info_list(PlayerId, 4),   %% 获得用户背包中物品部分属性[id, goods_id, cell, num]的列表
    %% 分解为id, goods_id, cell, num四个列表
    {_, TypeIdList, _, _} = part_list(GoodsInfoList),
    case get_goods_by_id(GoodsId) of
        {ok, []} ->
            {error, ?GOODS_NOT_EXIST_2};
        {ok, [GoodsInfo]} ->
            Goods = list_to_tuple([goods | GoodsInfo]),         %% 生成物品记录
            case ets:lookup(?ETS_GOODS_TYPE, Goods#goods.goods_id) of   %% 检查物品类型是否存在
                [] ->
                    {error, ?OTHER_ERROR};
                [GoodsTypeInfo] ->
                    GoodsStatus = gen_server:call(GoodsPid, {'STATUS'}),
                    Max = GoodsTypeInfo#ets_goods_type.max_overlap,
                    case Max == 0 of
                        true ->         %% 不可叠加
                            case length(GoodsStatus#goods_status.null_cells) > 0 of
                                true ->
                                    [MinCellNum | NullCells] = GoodsStatus#goods_status.null_cells,
                                    Sql = io_lib:format(<<"update goods set player_id = ~p, cell = ~p where id = ~p">>, [PlayerId, MinCellNum, GoodsId]),
                                    case execute(Sql) of
                                        {ok, _} ->
                                            add_online_goods(GoodsId),  %% 将物品添加到ets_goods_online表
                                            %% 更新背包空格列表
                                            NewGoodsStatus = GoodsStatus#goods_status{null_cells = NullCells},
                                            gen_server:cast(GoodsPid, {'SET_STATUS', NewGoodsStatus}),
                                            ok;
                                        error ->
                                            {error, ?OTHER_ERROR}
                                    end;
                                false ->
                                    {error, ?NOT_ENOUGH_SPACE}
                            end;
                        false ->        %% 可叠加
                            case lists:member(Goods#goods.goods_id, TypeIdList) of
                                true ->     %% 存在同类物品
                                    %% 查找背包中该物品对应物品的id和数量, 得到对应信息列表
                                    InfoList = filter_list(Goods#goods.goods_id, [], GoodsInfoList),
                                    Total = total_goods_num(InfoList) + GoodsNum, %% 合计该物品数量
                                    OldLen = length(InfoList),       %% 原占用格子数
                                    NewLen = util:ceil(Total / Max),    %% 整理后应占用格子数
                                    case NewLen > OldLen of             %% NewLen == OldLen + 1
                                        true ->     %% 需要背包空间
                                            case length(GoodsStatus#goods_status.null_cells) > 0 of
                                                true ->
                                                    [MinCellNum | NullCells] = GoodsStatus#goods_status.null_cells,
                                                    NewNum = Total - (NewLen - 1) * Max,
                                                    NewInfoList = [[GId, Cell, Max] || [GId, _, Cell, _] <- InfoList],    %% 更新需要用到的：id, cell, num
                                                    {ok, NewNullCells} = update_goods(NewInfoList, NullCells),
                                                    Sql = io_lib:format(<<"update goods set player_id = ~p, cell = ~p, num = ~p where id = ~p">>, [PlayerId, MinCellNum, NewNum, GoodsId]),
                                                    case execute(Sql) of
                                                        {ok, _} ->
                                                            add_online_goods(GoodsId),  %% 添加至在线物品表
                                                            %% 更新背包空格列表
                                                            NewGoodsStatus = GoodsStatus#goods_status{null_cells = NewNullCells},
                                                            gen_server:cast(GoodsPid, {'SET_STATUS', NewGoodsStatus}),
                                                            ok;
                                                        error ->
                                                            {error, ?OTHER_ERROR}
                                                    end;
                                                false ->
                                                    {error, ?NOT_ENOUGH_SPACE}
                                            end;
                                        false ->    %% 不需要额外的背包空间
                                            NewNum = Total - (NewLen - 1) * Max,
                                            {List1, List2} = get_new_goods_info_list(InfoList, NewLen - 1, Max),
                                            [[GId2, Cell2, _] | T] = List2,
                                            NewList2 = [[GId2, Cell2, NewNum] | T],
                                            Sql = io_lib:format(<<"delete from goods where id = ~p">>, [GoodsId]),
                                            case execute(Sql) of
                                                {ok, _} ->
                                                    {ok, NullCells1} = update_goods(List1, GoodsStatus#goods_status.null_cells),
                                                    {ok, NullCells2} = update_goods(NewList2, NullCells1),
                                                    NewGoodsStatus = GoodsStatus#goods_status{null_cells = NullCells2},
                                                    gen_server:cast(GoodsPid, {'SET_STATUS', NewGoodsStatus}),
                                                    ok;
                                                error ->
                                                    {error, ?OTHER_ERROR}
                                            end
                                    end;
                                false ->    %% 不存在同类物品
                                    case length(GoodsStatus#goods_status.null_cells) > 0 of
                                        true ->
                                            [MinCellNum | NullCells] = GoodsStatus#goods_status.null_cells,
                                            Sql = io_lib:format(<<"update goods set player_id = ~p, cell = ~p where id = ~p">>, [PlayerId, MinCellNum, GoodsId]),
                                            case execute(Sql) of
                                                {ok, _} ->
                                                    add_online_goods(GoodsId),  %% 添加到在线物品ETS表中
                                                    %% 更新背包空格列表
                                                    NewGoodsStatus = GoodsStatus#goods_status{null_cells = NullCells},
                                                    gen_server:cast(GoodsPid, {'SET_STATUS', NewGoodsStatus}),
                                                    ok;
                                                error ->
                                                    {error, ?OTHER_ERROR}
                                            end;
                                        false ->
                                            {error, ?NOT_ENOUGH_SPACE}
                                    end
                            end
                    end
            end
    end.

%% 处理发信时的金钱支出
%% @spec handle_money(PlayerStatsu, Pay) -> ok | {error, ErrorCode}
handle_money(PlayerStatus, Pay) ->
    NewCoin = PlayerStatus#player_status.coin - Pay,
    case NewCoin >= 0 of
        true ->
            Sql = io_lib:format(<<"update player set coin = ~p where id = ~p limit 1">>, [NewCoin, PlayerStatus#player_status.id]),
            case execute(Sql) of
                {ok, _} ->
                    NewStatus = PlayerStatus#player_status{coin = NewCoin},
                    gen_server:cast(PlayerStatus#player_status.pid, {'SET_PLAYER', NewStatus});
                _ ->
                    {error, ?OTHER_ERROR}
            end;
        false ->
            {error, ?NOT_ENOUGH_COIN}
    end.

%% 处理金钱附件（提取附件时）
handle_money(PlayerStatus, NewCoin, NewSilver) ->
    Sql = io_lib:format(<<"update player set coin = ~p, silver = ~p where id = ~p limit 1">>, [NewCoin, NewSilver, PlayerStatus#player_status.id]),
    case execute(Sql) of
        {ok, _} ->
            NewStatus = PlayerStatus#player_status{coin = NewCoin, silver = NewSilver},
            gen_server:cast(PlayerStatus#player_status.pid, {'SET_PLAYER', NewStatus});
        error ->
            {error, ?OTHER_ERROR}
    end.

%% 插入新信件
insert_mail(Type, Timestamp, SName, UId, Title, Content, GoodsId, GoodsNum, Coin, Silver) ->
    Sql = db_sql:make_insert_sql(mail, ["type", "state", "timestamp", "sname", "uid", "title", "content", "goods_id", "goods_num", "coin", "silver"], [Type, 2, Timestamp, SName, UId, Title, Content, GoodsId, GoodsNum, Coin, Silver]),
    case execute(Sql) of
        {ok, _} ->
            ok;
        error ->
            {error, ?OTHER_ERROR}
    end.

%% 限制信件数
mail_num_limit(PlayerId) ->
    Sql = io_lib:format(<<"select * from mail where uid = ~p">>, [PlayerId]),
    case execute(Sql) of
        {ok, Maillist} ->
            mail_num_limit(Maillist, 50);     %% 限制信件数为50
        error ->
            ok
    end.

%% 信件数量限制为N
mail_num_limit(Maillist, N) ->
    Len = length(Maillist),
    case Len > N of
        false ->
            ok;
        true ->
            Mail = get_earliest_mail(Maillist),
            [_, Type, _, _, SName, _, _, _, GoodsId, _, Coin, _] = Mail,
            del_one_mail(Mail),
            case Type == 2 andalso (GoodsId /= 0 orelse Coin /= 0) of
                true ->     %% 私人信件且有附件
                    case get_player_id(SName) of
                        {ok, [[PlayerId]]} ->    %% 系统发送了退附件邮件，需检查该用户邮件数
                            mail_num_limit(PlayerId);
                        _Other ->
                            ok
                    end;
                false ->    %% 系统信件/无附件
                    ok
            end
    end.

%% 生成插入数据库的语句
%% @spec make_insert_sql(Tab, FieldList, ValueList) -> string()
make_insert_sql(Tab, FieldList, ValueList) ->
    FieldListStr = get_string([], FieldList),
    ValueListStr = get_string([], ValueList),
    lists:concat(["insert into ", Tab, " (", FieldListStr, ") values (", ValueListStr, ")"]).

%%% 找出未使用的最小背包单元
%min_empty_cell(CellList, MaxCellNum) ->
%    case length(CellList) >= MaxCellNum of
%        false ->
%            NewCellList = lists:sort(CellList),
%            min_empty_cell(1, NewCellList, MaxCellNum);
%        true ->
%            not_enough_space
%    end.

%%% 找出未使用的最小背包单元号
%min_empty_cell(Min, [], _MaxCellNum) ->
%    Min;
%min_empty_cell(Min, CellList, MaxCellNum) ->
%    [Cell | CellList2] = CellList,
%    case Cell == Min of
%        true ->
%            min_empty_cell(Min + 1, CellList2, MaxCellNum);
%        false ->
%            Min
%    end.

%% 未读信件通知
new_mail_notify(NameList) ->
    {ok, Bin} = pt_19:write(19005, 1),
    lists:foreach(fun(Nick) -> lib_send:send_to_nick(Nick, Bin) end, NameList).

%% 将每项为列表（四个元素）的列表分解为四个列表，用于分解get_goods_info_list/2中得到的列表
%% @spec part_list(List) -> {List1, List2, List3, List4}
%% part_list([[A1, B1, C1, D1], …, [An, Bn, Cn, Dn]] -> {[A1,…,An], [B1,…,Bn], [C1,…,Cn], [D1,…,Dn]}
part_list(List) ->
    part_list([], [], [], [], List).

%% 分解列表
part_list(List1, List2, List3, List4, List) ->
    case List of
        [] ->
            {List1, List2, List3, List4};
        _ ->
            [[A, B, C, D] | NewList] = List,
            NewList1 = [A | List1],
            NewList2 = [B | List2],
            NewList3 = [C | List3],
            NewList4 = [D | List4],
            part_list(NewList1, NewList2, NewList3, NewList4, NewList)
    end.

%% 随机插入信件到数据库（测试用）
%% Start: 起始编号，N 结束编号
rand_insert_mail(UId, Start, N) ->
    {{Year, Month, Day}, {Hour, Minute, Second}} = erlang:localtime(),
    Content = "内容" ++ integer_to_list(Start) ++ ", " ++ integer_to_list(Year) ++ "-" ++ integer_to_list(Month) ++
        "-" ++ integer_to_list(Day) ++ ", " ++ integer_to_list(Hour) ++ ":" ++ integer_to_list(Minute)
        ++ ":" ++ integer_to_list(Second),
    Title = "标题" ++ integer_to_list(Start),
    Type = random:uniform(2),
    Timestamp = util:unixtime(),
    SName = integer_to_list( random:uniform(10000) ),
    GoodsId = 0,
    GoodsNum = 0,
    Coin = 0,
    Silver = 0,
    insert_mail(Type, Timestamp, SName, UId, Title, Content, GoodsId, GoodsNum, Coin, Silver),
    case N =< 1 of
        true ->
            ok;
        false ->
            timer:sleep(500),
            rand_insert_mail(UId, Start + 1, N - 1)
    end.

%% 刷新客户端
refresh_client(Location, Coin, Silver, Gold, PlayerStatus) ->
    [NewLocation, CellNum, GoodsList] = gen_server:call(PlayerStatus#player_status.goods_pid, {'list', PlayerStatus, Location}),
    %io:format("New coin, silver, gold: ~p, ~p, ~p~n", [Coin, Silver, Gold]),
    %io:format("goods list: ~p~n", [GoodsList]),
    {ok, BinData} = pt_15:write(15010, [NewLocation, CellNum, Coin, Silver, Gold, GoodsList]),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData).

%% 通知客戶端刷新信息
refresh_client(What, Socket) ->
    {ok, BinData} = pt_13:write(13005, What),
    lib_send:send_one(Socket, BinData).

%% 发送私人信件
%% @spec send_priv_mail/7 -> {ok, RName} | {error, ErrorCode} | {VList, IList}
%% @var     RName : 收件人名，VList : 发送成功名单， IList : 发送失败名单
send_priv_mail(NameList, Title, Content, GoodsId, GoodsNum, Coin, PlayerStatus) ->
    Silver = 0,
    Timestamp = util:unixtime(),
    case check_mail(NameList, Title, Content, GoodsId, Coin, Silver) of
        {error, Reason} ->
            {error, Reason};

        {ok, RName} ->
            %% TODO 当发送附件时，需消耗道具，未处理（在send_mail_to_one中添加）
            case send_mail_to_one(2, Timestamp, PlayerStatus#player_status.nickname, RName, Title, Content, GoodsId, GoodsNum, Coin, Silver, PlayerStatus) of
                ok ->
                    {ok, RName};
                {error, Reason} ->
                    {error, Reason}
            end;

        {ValidNameList, InvalidNameList} ->     %% {正确角色名列表，错误角色名列表}
            case send_mail_to_some(2, Timestamp, PlayerStatus#player_status.nickname, ValidNameList, Title, Content, GoodsId, GoodsNum, Coin, Silver, PlayerStatus) of
                {error, Reason} ->
                    {error, Reason};
                {ValidList, OldInvalidList} ->
                    NewInvalidList = InvalidNameList ++ OldInvalidList,
                    {ValidList, NewInvalidList}
            end
    end.

%% 发送信件给一个收件人
%% @spec send_mail_to_one/11 -> ok | {error, ErrorCode}
send_mail_to_one(Type, Timestamp, SName, RName, Title, Content, GoodsId, GoodsNum, Coin, Silver, PlayerStatus) ->
    Sql = io_lib:format(<<"select id from player where nickname = '~s' limit 1">>, [RName]),
    case execute(Sql) of
        {ok, []} ->
            {error, ?WRONG_NAME};
        {ok, [[UId]]} ->
            case GoodsId of
                0 ->        %% 只有铜钱 (+ 银币)
                    case Type of
                        1 ->        %% 系统信件
                            insert_mail(Type, Timestamp, SName, UId, Title, Content, GoodsId, GoodsNum, Coin, Silver);
                        2 ->        %% 私人信件
                            Pay = ?POSTAGE + Coin,  %% 发信时需扣取的铜钱数
                            case handle_money(PlayerStatus, Pay) of
                                ok ->
                                    %NewCoin = PlayerStatus#player_status.coin - Pay,
                                    %NewSilver = PlayerStatus#player_status.silver,
                                    %NewGold = PlayerStatus#player_status.gold,
                                    %refresh_client(4, NewCoin, NewSilver, NewGold, PlayerStatus),   %% 刷新背包
                                    refresh_client(2, PlayerStatus#player_status.socket),   %% 刷新背包
                                    case insert_mail(Type, Timestamp, SName, UId, Title, Content, GoodsId , GoodsNum, Coin, Silver) of
                                        ok ->
                                            mail_num_limit(UId),    %% 检查信件数量
                                            ok;
                                        Error ->
                                            Error
                                    end;
                                Error ->
                                    Error
                            end;
                        _ ->
                            {error, ?OTHER_ERROR}
                    end;
                _ ->        %% 物品 + 铜钱 (+ 银币)
                    case Type of
                        1 ->
                            insert_mail(Type, Timestamp, SName, UId, Title, Content, GoodsId, GoodsNum, Coin, Silver);
                        2 ->
                            case handle_goods_send(PlayerStatus#player_status.goods_pid, PlayerStatus#player_status.id, GoodsId, GoodsNum) of    %% 处理物品
                                {ok, NewId} ->
                                    Pay = ?POSTAGE + Coin,  %% 发信时需扣取的铜钱数
                                    case handle_money(PlayerStatus, Pay) of       %% 扣费
                                        ok ->
                                            %NewCoin = PlayerStatus#player_status.coin - Pay,
                                            %NewSilver = PlayerStatus#player_status.silver,
                                            %NewGold = PlayerStatus#player_status.gold,
                                            %refresh_client(4, NewCoin, NewSilver, NewGold, PlayerStatus),%% 刷新背包
                                            refresh_client(2, PlayerStatus#player_status.socket),   %% 刷新背包
                                            case insert_mail(Type, Timestamp, SName, UId, Title, Content, NewId, GoodsNum, Coin, Silver) of
                                                ok ->
                                                    mail_num_limit(UId),    %% 检查信件数量
                                                    ok;
                                                Error ->
                                                    Error
                                            end;
                                        Error ->
                                            Error
                                    end;
                                Error ->
                                    Error
                            end;
                        _ ->
                            {error, ?OTHER_ERROR}
                    end
            end;
        _ ->
            {error, ?OTHER_ERROR}
    end.

%% 发送信件给多个收件人
%% @spec send_mail_to_some/11 -> {error, ErrorCode} | {VList, IList}
%%      VList : 信件已正确发送的收件人列表
%%      IList : 未正确发送的收件人列表
send_mail_to_some(Type, Timestamp, SName, NameList, Title, Content, GoodsId, GoodsNum, Coin, Silver, PlayerStatus) ->
    F = fun(RName) ->
            Sql = io_lib:format(<<"select id from player where nickname = '~s'">>, [RName]),
            case execute(Sql) of
                {ok, []} ->
                    false;
                {ok, [[UId]]} ->
                    case Type of
                        1 ->        %% 系统信件可群发金钱附件
                            case insert_mail(Type, Timestamp, SName, UId, Title, Content, 0, 0, Coin, Silver) of
                                ok ->
                                    mail_num_limit(UId),    %% 检查信件数量是否超出限制
                                    true;
                                {error, _} ->
                                    false
                            end;
                        2 ->
                            case GoodsId == 0 andalso Coin == 0 of
                                true ->     %% 私人信件（无物品）
                                    case insert_mail(Type, Timestamp, SName, UId, Title, Content, GoodsId, GoodsNum, Coin, Silver) of
                                        ok ->
                                            mail_num_limit(UId),
                                            true;
                                        Error ->
                                            Error
                                    end;
                                false ->   %% 有物品，群发不能发送
                                    false
                            end;
                        _ ->
                            false
                    end;
                error ->
                    false
            end
    end,
    case Type of
        1 ->
            lists:partition(F, NameList);
        2 ->
            NewCoin = PlayerStatus#player_status.coin - ?POSTAGE,
            case NewCoin >= 0 of
                true ->
                    {VList, IList} = lists:partition(F, NameList),
                    case VList of
                        [] ->   %% 无成功发送
                            {error, ?WRONG_NAME};
                        _ ->    %% 扣费
                            Sql = io_lib:format(<<"update player set coin = ~p where id = ~p limit 1">>, [NewCoin, PlayerStatus#player_status.id]),
                            case execute(Sql) of
                                {ok, _} ->
                                    NewCoin = PlayerStatus#player_status.coin - ?POSTAGE,
                                    NewSilver = PlayerStatus#player_status.silver,
                                    NewGold = PlayerStatus#player_status.gold,
                                    NewStatus = PlayerStatus#player_status{coin = NewCoin, silver = NewSilver, gold = NewGold},
                                    gen_server:cast(PlayerStatus#player_status.pid, {'SET_PLAYER', NewStatus}),
                                    %refresh_client(4, NewCoin, NewSilver, NewGold, PlayerStatus);%% 刷新背包
                                    refresh_client(2, PlayerStatus#player_status.socket);   %% 刷新背包
                                _ ->
                                    error
                            end,
                            {VList, IList}
                    end;
                false ->
                    {error, ?NOT_ENOUGH_COIN}
            end;
        _ ->
            {error, ?OTHER_ERROR}
    end.

%% 发送系统信件
%% @spec send_sys_mail/7 -> {ok, InvalidList} | {error, Reason}
%%          InvalidList : 未发送的名单
%%          Reason      : 错误码（数字），对应含义见宏定义
send_sys_mail(NameList, Title, Content, GoodsId, GoodsNum, Coin, Silver) ->
    Timestamp = util:unixtime(),
    case check_mail(NameList, Title, Content, GoodsId, Coin, Silver) of
        {error, Reason} ->
            {error, Reason};
        {ok, Name} ->
            case send_mail_to_one(1, Timestamp, "系统", NameList, Title, Content, GoodsId, GoodsNum, Coin, Silver, []) of
                ok -> %% 发送成功
                    {ok, Bin} = pt_19:write(19005, 1),
                    lib_send:send_to_nick(Name, Bin),
                    {ok, []};
                {error, Reason} ->    %% 金钱不足
                    {erorr, Reason}
            end;
        {ValidNameList, InvalidNameList} ->
            case send_mail_to_some(1, Timestamp, "系统", ValidNameList, Title, Content, GoodsId, GoodsNum, Coin, Silver, []) of
                {error, Reason} ->
                    {error, Reason};
                {ValidList, OldInvalidList} ->
                    NewInvalidList = InvalidNameList ++ OldInvalidList,
                    new_mail_notify(ValidList),
                    {ok, NewInvalidList}
            end
    end.

%% 将物品分堆，并返回新物品Id
%% @spec split_goods(Goods, NewNum1, NewNum2) -> {ok, NewGoodsId} | {error, ErrorCode}
split_goods(Goods, NewNum1, NewNum2) ->
    GoodsId  = Goods#goods.id,
    PlayerId = Goods#goods.player_id,
    NewGoods = Goods#goods{num = NewNum2, location = 4, cell = 0},
    NewInfo  = lists:nthtail(2, tuple_to_list(NewGoods)),
    %SqlInsertGoods = io_lib:format(<<"insert into goods (player_id, goods_id, type, subtype, equip_type, price_type, price, sell_price, bind, trade, sell, isdrop, level, vitality, spirit, hp, mp, forza, agile, wit, att, def, hit, dodge, crit, ten, speed, attrition, use_num, suit_id, quality, quality_his, quality_fail, stren, stren_his, stren_fail, hole, hole1_goods, hole2_goods, hole3_goods, location, cell, num, color, expire_time) values (~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p, ~p)">>, NewInfo),
    [id | FieldList] = record_info(fields, goods),                      %% 得到表中对应的列名
    SqlInsertGoods = make_insert_sql(goods, FieldList, NewInfo),        %% 生成对应的插入查询
    Sql = io_lib:format(<<"select id from goods where player_id = ~p and location = 4 and cell = 0">>, [PlayerId]),
    %io:format("sql: ~p~n", [SqlInsertGoods]),
    SqlUpdateGoods = io_lib:format(<<"update goods set num = ~p where id = ~p">>, [NewNum1, GoodsId]),
    case execute(Sql) of                                %% 获取原cell为0的该用户物品Id列表
        {ok, List1} ->
            case execute(SqlInsertGoods) of             %% 插入新物品
                {ok, _} ->
                    case execute(SqlUpdateGoods) of     %% 修改原物品
                        {ok, _} ->
                            update_online_goods(Goods#goods.id, 4, Goods#goods.cell, NewNum1),  %% 更新在线物品表
                            case execute(Sql) of        %% 获取新cell为0的该用户物品Id列表
                                {ok, List2} ->
                                    [[NewGoodsId]] = List2 -- List1,
                                    Sql2 = io_lib:format(<<"update goods set player_id = 0, cell = 1 where id = ~p">>, [NewGoodsId]),        %% 将新物品的用户Id设置为0（如不更改，用户删角色，该物品是否有删除的可能？）
                                    execute(Sql2),
                                    {ok, NewGoodsId};
                                error ->
                                    {error, ?OTHER_ERROR}
                            end;
                        error ->
                            {error, ?OTHER_ERROR}
                    end;
                error ->
                    {error, ?OTHER_ERROR}
            end;
        error ->
            {error, ?OTHER_ERROR}
    end.

%% 字符宽度，1汉字=2单位长度，1数字字母=1单位长度
string_width(String) ->
    string_width(String, 0).
string_width([], Len) ->
    Len;
string_width([H | T], Len) ->
    case H > 255 of
        true ->
            string_width(T, Len + 2);
        false ->
            string_width(T, Len + 1)
    end.

%% 合计物品数量
%% @spec total_goods_num(GoodsInfoList) -> integer()
total_goods_num(GoodsInfoList) ->
    total_goods_num(GoodsInfoList, 0).

%% 合计物品数量
total_goods_num([], Total) ->
    Total;
total_goods_num(GoodsInfoList, Total) ->
    [[_, _, _, Num] | NewList] = GoodsInfoList,
    NewTotal = Num + Total,
    total_goods_num(NewList, NewTotal).

%% 根据InfoList更新对应物品
%% @spec update_goods(InfoList, OldNullCells) -> {ok, NewNullCells}
update_goods([], NullCells) ->
    NewNullCells = lists:sort(NullCells),
    {ok, NewNullCells};
update_goods(InfoList, NullCells) ->
    [[GId, Cell, Num] | NewList] = InfoList,
    case Num of
        0 ->
            del_online_goods(GId),                  %% 从ets_goods_online表中删掉
            NewNullCells = [Cell | NullCells],      %% 更新空格列表
            Sql = io_lib:format(<<"delete from goods where id = ~p">>, [GId]);
        _ ->
            update_online_goods(GId, 4, Cell, Num), %% 更新ets_goods_online表数据
            NewNullCells = NullCells,
            Sql = io_lib:format(<<"update goods set cell = ~p, num = ~p where id = ~p">>, [Cell, Num, GId])
    end,
    execute(Sql),
    update_goods(NewList, NewNullCells).

%% 去掉信件的附件
update_mail(MailId) ->
    Sql = io_lib:format(<<"update mail set goods_id = 0, goods_num = 0, coin = 0, silver = 0 where id = ~p">>, [MailId]),
    execute(Sql).

%% 更新在线物品
update_online_goods(GoodsId, NewLocation, NewCell, NewNum) ->
    [Goods] = ets:lookup(?ETS_GOODS_ONLINE, GoodsId),
    NewGoods = Goods#goods{location = NewLocation, cell = NewCell, num = NewNum},
    ets:insert(?ETS_GOODS_ONLINE, NewGoods).
