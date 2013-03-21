%%%------------------------------------
%%% @Module     : lib_mail
%%% @Author     : ygzj
%%% @Created    : 2010.10.05
%%% @Description: 信件处理函数
%%%------------------------------------
-module(lib_mail).
-export(
    [
        check_mail_time/0,      %% 检查信件有效期
        check_unread/1,         %% 查询是否存在未读信件
        del_mail/2,             %% 删除信件
        feedback/6,             %% 玩家反馈（GM提交）
        get_attachment/2,       %% 获取附件
      % get_goods_icon/1,       %% 获取图标号
        get_goods_type_id/1,    %% 获取物品类型ID
        get_mail/2,             %% 获取邮件
        get_maillist/1,         %% 获取邮件列表
		get_mails/4,			%% 分页获取用户所有信件，邮件类型和已读未读
		check_mail_full/1,		%% 检查邮件是否已满
        new_mail_notify/1,      %% 新邮件到达通知
        rand_insert_mail/3,     %% 随机插入信件（测试用）
        refresh_client/5,       %% 刷新客户端背包(不可外部调用)
%%         refresh_client/2,       %% 刷新客戶端
        send_priv_mail/7,       %% 发送私人邮件(unused)
        send_mail_to_one/12,	%% 发送私人邮件
        send_sys_mail/8,	    %% 发送系统邮件
		send_sys_mail/9,		%% 发送系统邮件(可发绑定的物品)
		insert_mail/11,
		add_online_goods/3,
		filter_list/3,
		get_earliest_mail/1,
		get_goods_info_list/2,
		get_new_goods_info_list/3,
		get_string/2,
		part_list/1,
		update_goods/2,
		total_goods_num/1,
		check_unread_by_name/1,
		delete_read_mail/1		%% 19008 删除已读邮件
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
-define(MAIL_FULL,            12).  %% 对方邮件已满
-define(NOT_ENOUGH_SPACE,      2).  %% 背包已满
-define(ATTACH_NOT_EXIST,      3).  %% 信件中不存在附件
-define(GOODS_NOT_EXIST_2,     4).  %% 信件中物品不存在

-define(POSTAGE, 50).               %% 邮资
-define(MAX_NUM, 50).               %% 每个用户信件数量上限
-define(SYS_MAIL_KEEP, 20).         %% 系统邮件保留时间（天）


%% 添加在线物品（背包中的）
add_online_goods(Goods, Cell, PlayerId) ->
	GoodsInfo = list_to_tuple([goods] ++ Goods),        %% 生成物品记录
	db_agent:attach_mail_goods(PlayerId, Cell, GoodsInfo#goods.id),
	NewGoodsInfo = GoodsInfo#goods{player_id = PlayerId,
								   cell = Cell,
								   location = 4},
	ets:insert(?ETS_GOODS_ONLINE, NewGoodsInfo),
	GoodsAttributeInfo = db_agent:mail_get_goods_attribute_by_id(GoodsInfo#goods.id),
	lists:foreach(fun(Elem) ->
						  AttrInfo = list_to_tuple([goods_attribute] ++ Elem),
						  AttrInfoInsert = AttrInfo#goods_attribute{player_id = PlayerId},
						  ets:insert(?ETS_GOODS_ATTRIBUTE, AttrInfoInsert)
				  end, GoodsAttributeInfo).

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

%% 检查邮件是否已满
check_mail_full(PlayerId) ->
	[MailCount] = db_agent:get_mail_count(PlayerId),
	MailCount >= ?MAX_NUM.

%% 检查信件是否合法，如合法，返回有效的角色名列表与无效的角色名列表
%% @spec check_mail(NameList, Title, Content, GoodsId, Coin, Gold) ->
%%          {ok, Name} | {error, Position} | {VList, IList}
check_mail(NameList, Title, Content, GoodsId, Coin, Gold) ->
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
                            case GoodsId == 0 andalso Coin == 0 andalso Gold == 0 of
                                true ->
                                    {VList, IList} = lists:partition(fun check_name/1, NewNameList),
                                    case VList of
                                        [] ->
                                            {error, ?WRONG_NAME};
                                        _ ->
                                            {VList, IList}
                                    end;
                                false ->    %% 发信给多人有同一附件，不合法
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
    %% 获得所有信件的id
    case db_agent:get_all_mail_ids() of
        [] ->
            ok;
        ItemList ->
            lists:foreach(fun(Item) -> [Id] = Item, check_mail_time(Id) end, ItemList)
    end.

%% 根据信件Id对该信件进行期限检查
check_mail_time(Id) ->
    case db_agent:get_mail_info_by_mail_id(Id) of
        [] ->
            ok;
        [Mail] ->
            [_, Type, _, Timestamp, _, _, _, _, _, _, _, _] = Mail,
            CurrTimestamp = util:unixtime(),            %% 当前时间戳
            TimeSpan = CurrTimestamp - Timestamp,       %% 时间差
            case TimeSpan >= ?SYS_MAIL_KEEP * 86400 andalso (Type =:= 1 orelse Type =:= 0) of                  %% 系统信件20天(604800秒)到期
                true ->
                    del_one_mail(Mail);
                false ->
                    ok
            end
    end.

%% 检查角色名长度合法性，合法则查询是否存在角色
check_name(Name) ->
	%%合服的角色名字长度会增加，特此长度改为21,以前是11
    case check_length(Name, 21) of
        true ->
            lib_player:is_exists_name(Name);     %% 存在true，不存在false
        _Other ->       %% false与error
            false
    end.

%% 检查主题长度（限制25汉字）
check_title(Title) ->
    check_length(Title, 50).

%% 检查邮件中是否存在未读邮件
check_unread(PlayerId) ->
    case db_agent:check_mail_unread(PlayerId) of
  		[] ->
      		skip;
  		Data ->
			Nums = length(Data),
			{ok, BinData} = pt_19:write(19005, {1,Nums}),
			lib_send:send_to_uid(PlayerId, BinData)
    end.

%%根据名字
check_unread_by_name(Name) ->
	case db_agent:get_mail_player_id(Name) of
		[] ->     %% 发件人角色不存在
			skip;       
		[Uid] ->
			check_unread(Uid)
	end.

%% 删除物品
del_goods(GoodsId) ->
    db_agent:del_mail_goods(GoodsId).  

%% 删除信件
%% @spec del_mail(IdList, PlayerId) -> ok | error
del_mail(IdList, PlayerId) when is_list(IdList) ->    %% 根据客户端发送的信件id列表删除信件
    Maillist = get_maillist_by_id_list(IdList, PlayerId),
    lists:foreach(fun(Mail) -> del_one_mail(Mail) end, Maillist);
del_mail(_, _) ->
    error.

%% 从数据库中删除信件
del_mail_from_database(MailId) ->
    db_agent:del_mail(MailId).

%% 删除一封信件，退回附件
del_one_mail(Mail) ->
    [MailId, Type, _, Timestamp, BinSName, UId, _, _, GoodsId, GoodsNum, Coin, Gold] = Mail,
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
            case db_agent:get_mail_player_id(Nick) of
                [] ->     %% 发件人角色不存在
                    F1();       %% 删除信件，如果存在附件则丢弃
                [UId2] ->
                    case db_agent:get_mail_player_name(UId) of
                        [] ->
                            Name = "对方";
                        [Any] ->
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
					Content2 = io_lib:format("~s：\n    您于~p-~p-~p ~p:~p:~p发送的信件包含附件，~s未提取您发送的附件，请于7天内取回附件!",
											 [Nick, Year, Month, Day, Hour, Minute, Second, Name]),
					case GoodsId of
						0 -> 
							GoodsTypeId = 0;
						_ ->
							GoodsTypeId = 
        						case lib_mail:get_goods_type_id(GoodsId) of
            						[] ->
                						0;
            						[_PlayerId, GTId] ->
                						GTId;
            						_ ->
                						0
       							end
					end,
					case insert_mail(Type2, Timestamp2, SName2, UId2, Title2, 
                            Content2, GoodsId, GoodsTypeId, GoodsNum, Coin, Gold) of
                        ok ->
                            check_unread(UId2),
                            del_mail_from_database(MailId);  %% 删除信件
%%                          mail_num_limit(UId2);            %% 检查该用户信件数量
                        _ ->        %% 物品丢失（实际上仍在表goods中，但是物品所有人player_id变成0了）
                            ?ERROR_MSG("~n*******Execute ~p:~p/1 error, id of goods: ~p, owner: ~ts*******~n", [?MODULE, del_one_mail, GoodsId, Nick])
                    end;
                error ->
                    error
            end
    end,
    case GoodsId /= 0 orelse Coin /= 0 andalso Type == 2 of
        true ->                 %% 私人信件有附件，需要退回附件
            case db_agent:mail_get_goods_by_id(GoodsId) of
                [] ->     %% 附件物品实际不存在
                    case Coin == 0 of
                        true ->
                            F1();
                        false ->
                            F2()
                    end;
                _ ->
                    F2()
            end;
        false ->
            F1()      %% 无附件或者系统邮件，附件直接删除
    end.

%% 删去在线物品（背包中）
del_online_goods(GoodsId) ->
    ets:delete(?ETS_GOODS_ONLINE, GoodsId),
	ets:match_delete(?ETS_GOODS_ATTRIBUTE, #goods_attribute{ gid=GoodsId, _='_' }).

%% 插入玩家反馈至数据库的feedback表
%% @spec feedback(Type, Title, Content, Address, PlayerId, PlayerName) -> Result
%%      Result : 0 | 1
feedback(Type, Title, Content, Address, PlayerId, PlayerName) ->
    Server = atom_to_list( node() ),
    Timestamp = util:unixtime(),
    {A, B, C, D} = Address,
    IP = lists:concat([A, ".", B, ".", C, ".", D]),
    case db_agent:mail_feedback(Type, PlayerId, PlayerName, Title, Content, Timestamp, IP, Server) of
        1 -> 1;
        _  -> 0
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
%% @spec get_attachment(PlayerStatus, MailId) -> {ok, Status} | {error, Reason}
get_attachment(PlayerStatus, MailId) ->
    case get_mail(MailId, PlayerStatus#player.id) of
        {ok, Mail} ->
            [_, Type, _, _, _SName, _Uid, _, _, GoodsId, GoodsType, GoodsNum, Coin, Gold] = Mail,
            case GoodsId == 0 andalso GoodsType == 0 andalso Coin == 0 andalso Gold == 0 of
                false ->            %% 有附件
					Nowtime = util:unixtime(),
                    case GoodsId == 0 andalso GoodsType == 0 of
                        false ->        %% 有物品
                            PlayerId = PlayerStatus#player.id,
                            GoodsPid = PlayerStatus#player.other#player_other.pid_goods,
                            case Coin == 0 andalso Gold == 0 of
                                true ->     %% 仅物品附件
                                    case handle_goods_recv(PlayerStatus, GoodsPid, PlayerId, GoodsId, GoodsType, GoodsNum, Type) of
                                        ok ->
                                            update_mail(MailId),
                                            spawn(fun()-> db_agent:update_mail_log(MailId, Nowtime) end),
											ok;
                                        {error, ErrorCode} ->
                                            {error, ErrorCode}
                                    end;
                                false ->    %% 同时有物品和钱币附件
                                    case handle_goods_recv(PlayerStatus, GoodsPid, PlayerId, GoodsId, GoodsType, GoodsNum, Type) of
                                        ok ->
                                            update_mail(MailId),
											Coin_abs = abs(Coin),
											Gold_abs = abs(Gold),
											NewStatus1 = 
												if 
													Coin_abs > 0 -> 
														lib_goods:add_money(PlayerStatus, Coin_abs, coinonly, 1411);%%修改money更新方式
													true ->
														PlayerStatus
												end,
											NewStatus =
												if
													Gold_abs > 0 ->
														lib_goods:add_money(NewStatus1, Gold_abs, gold, 1412);%%修改money更新方式
													true ->
														NewStatus1
												end,
											spawn(fun()-> db_agent:update_mail_log(MailId, Nowtime) end),
											refresh_client(2,NewStatus#player.other#player_other.pid_send),   %% 刷新背包(此处刷新，是为了刷新元宝铜币的数据更新)
                                            {ok,NewStatus};
                                        {error, ErrorCode} ->
                                            {error, ErrorCode}
                                    end
                            end;
                        true ->             %% 只有钱币
                            update_mail(MailId),
							Coin_abs = abs(Coin),
							Gold_abs = abs(Gold),
							NewStatus1 = 
								if 
									Coin_abs > 0 -> 
										lib_goods:add_money(PlayerStatus, Coin_abs, coinonly, 1411);%%修改money更新方式
									true ->
										PlayerStatus
								end,
							NewStatus =
								if
									Gold_abs > 0 ->
										lib_goods:add_money(NewStatus1, Gold_abs, gold, 1412);%%修改money更新方式
									true ->
										NewStatus1
								end,
							spawn(fun()-> db_agent:update_mail_log(MailId, Nowtime) end),
							{ok, NewStatus}
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

%% 获得背包中的物品的id, goods_id、cell及num属性的列表
%% @spec get_goods_info_list(PlayerId, Location) -> [Object]
%% Object = [GoodsId, GoodsTypeId, GoodsCell, GoodsNum]
get_goods_info_list(PlayerId, Location) ->
    Pattern = #goods{id = '$1', goods_id = '$2', cell = '$3', num = '$4', player_id = PlayerId, location = Location, _ = '_'},
    ets:match(?ETS_GOODS_ONLINE, Pattern).

%% 获得物品类型ID（goods.goods_id）
get_goods_type_id(GoodsId) ->
    db_agent:get_mail_goods_type_id(GoodsId).

%% 获取信件
%% @spec get_mail(MailId, PlayerId) -> {ok, Mail} | {error, ErrorCode}
get_mail(MailId, PlayerId) ->
    case db_agent:get_mail(MailId, PlayerId) of
        [] ->
           	{error,2};		
        [Mail] ->
            [_, _, State, _, _, _, _, _, _, _, _, _, _] = Mail,
            case State of
                2 ->
                    %% 更新信件状态为已读
                    db_agent:update_mail_status(MailId),    
                    {ok, Mail};
                _ ->
                    {ok, Mail}
            end
    end.

%% 获取用户信件列表
%% @spec get_maillist(PlayerId) -> Maillist | db_error
get_maillist(UId) ->
    db_agent:get_maillist(UId).


%% 分页获取用户所有信件，邮件类型和已读未读
get_mails(Mails, Mail_count,Mail_type, Mail_page) ->
	Mail_list_show =
		if 
			Mail_count > ?MAX_NUM ->
				lists:sublist(Mails, Mail_count - ?MAX_NUM + 1, ?MAX_NUM);
			true ->
				Mails
		end,
	Mails_tmp = 
		case Mail_type of
			0 ->
				Mail_list_show;
			1 ->
				lists:filter(fun(Mail) ->  [_,Tp|_Tail] = Mail, Tp =:= 1 orelse Tp =:= 0 end, Mail_list_show);
			2 ->
				lists:filter(fun(Mail) ->  [_,Tp|_Tail] = Mail, Tp =:= 2 end, Mail_list_show);
			Mt when Mt =:= 3 orelse Mt =:= 4 ->
				lists:filter(fun(Mail) ->  [_,_,St|_Tail] = Mail, St =:= (Mt-2) end, Mail_list_show)
		end,
	List_len = length(Mails_tmp),
	if
		List_len < (Mail_page - 1) * 5 ->
			{List_len, []};
		true ->
			{List_len, lists:sublist(Mails_tmp, (Mail_page - 1) * 5 + 1, 5)}
	end.

	

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
    case db_agent:get_mail_info_by_id(Id, PlayerId) of
        [] ->     %% 该id信件不存在
            get_maillist_by_id_list(AccMaillist, NewIdList, PlayerId);
        [Mail] -> %% 获得对应信件
            get_maillist_by_id_list([Mail | AccMaillist], NewIdList, PlayerId)
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
%% @spec handle_goods_send(PlayerStatus, GoodsId, GoodsNum, Coin) -> {ok, NewGoodsId} | {error, ErrorCode}
handle_goods_send(PlayerStatus, GoodsId, GoodsNum, Coin) ->
	case check_money(PlayerStatus, ?POSTAGE + Coin) of
		ok ->
			GoodsPid = PlayerStatus#player.other#player_other.pid_goods, 
			PlayerId = PlayerStatus#player.id,
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
                                		    case db_agent:handle_mail_goods(GoodsId) of
                              		          1 ->
												   	db_agent:handle_mail_goods_attribute(GoodsId),
													%% 把GoodsId对应物品从ets_goods_online表中去掉
                     		                       	del_online_goods(GoodsId), 
             		                               	%% 更新背包空格列表 
                                            		gen_server:cast(GoodsPid, {'handle_mail_goods',Goods#goods.cell}),
                                            		{ok, GoodsId};
                 		                       _ ->
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
    		end;
		Error -> Error
	end.

%% 处理物品附件（提取附件时）,其中物品的刷新搬到人物的物品进程中操作
%% @spec handle_goods_recv(GoodsPid, PlayerId, GoodsId, GoodsType, GoodsNum) -> ok | {error, ErrorCode}
handle_goods_recv(PlayerStatus, GoodsPid, PlayerId, GoodsId, GoodsType, GoodsNum, Type) ->
	case GoodsId of
		0 ->
			if
				Type =:= 0 ->
					case gen_server:call(GoodsPid, {'give_goods', PlayerStatus, GoodsType, GoodsNum, 2}) of
						ok ->
							ok;
						{_GoodsTypeId, not_found} ->
							{error, ?GOODS_NOT_EXIST_2};
						cell_num ->
							{error, ?NOT_ENOUGH_SPACE};
						_Error ->
							{error, ?OTHER_ERROR}
					end;
				Type =:= 3 ->%%系统	绑定的 不可交易的物品
					case gen_server:call(GoodsPid, {'give_goods_bt', PlayerStatus, GoodsType, GoodsNum, 2, 1}) of
						ok ->
							ok;
						{_GoodsTypeId, not_found} ->
							{error, ?GOODS_NOT_EXIST_2};
						cell_num ->
							{error, ?NOT_ENOUGH_SPACE};
						_Error ->
							{error, ?OTHER_ERROR}
					end;
				Type =:= 4 ->%%系统	不绑定的 不可交易的物品
					case gen_server:call(GoodsPid, {'give_goods_bt', PlayerStatus, GoodsType, GoodsNum, 0, 1}) of
						ok ->
							ok;
						{_GoodsTypeId, not_found} ->
							{error, ?GOODS_NOT_EXIST_2};
						cell_num ->
							{error, ?NOT_ENOUGH_SPACE};
						_Error ->
							{error, ?OTHER_ERROR}
					end;
				true ->
					GoodsTypeInfo = goods_util:get_goods_type(GoodsType),
					if
						is_record(GoodsTypeInfo, ets_base_goods) =:= false ->

							{error, ?GOODS_NOT_EXIST_2};
						true ->
							case gen_server:call(GoodsPid, {'give_goods', PlayerStatus, GoodsType, GoodsNum, GoodsTypeInfo#ets_base_goods.bind}) of
								ok ->
									ok;
								{_GoodsTypeId, not_found} ->
									{error, ?GOODS_NOT_EXIST_2};
								cell_num ->
									{error, ?NOT_ENOUGH_SPACE};
								_Error ->
									{error, ?OTHER_ERROR}
							end
					end
			end;
		_ ->
			case catch(gen_server:call(GoodsPid, {'give_goods_exsit', GoodsId, PlayerId})) of
				{ok, _Res} ->
					ok;
				{error, Res} ->
					{error, Res};
				_Other ->
					{error, ?OTHER_ERROR}
			end
	end.

%% 检查邮件发送时的金钱是否够
check_money(PlayerStatus, Pay) ->
    case goods_util:is_enough_money(PlayerStatus, Pay, coin) of
        true -> ok;
        false ->
            {error, ?NOT_ENOUGH_COIN}
    end.

%% 处理发信时的金钱支出
%% @spec handle_money(PlayerStatsu, Pay) -> {ok, NewStatus} | {error, ErrorCode}
handle_money(PlayerStatus, Pay) ->
    case goods_util:is_enough_money(PlayerStatus, Pay, coin) of
        true ->
			case goods_util:is_enough_money(PlayerStatus, Pay - ?POSTAGE, coinonly) of
				true ->
					Pay_coin_only = abs(Pay-?POSTAGE),
					NewStatus1 = lib_goods:cost_money(PlayerStatus, ?POSTAGE, coin, 1413),
					NewStatus = lib_goods:cost_money(NewStatus1, Pay_coin_only, coinonly, 1413),
%% 					gen_server:cast(NewStatus#player.other#player_other.pid,
%% 									{'SET_PLAYER', NewStatus}),
					{ok, NewStatus};
				false ->
					{error, ?NOT_ENOUGH_COIN}
			end;
        false ->
            {error, ?NOT_ENOUGH_COIN}
    end.

%% 处理金钱附件（提取附件时）
%% handle_money(PlayerStatus, NewCoin, NewGold) ->
%%     case db_agent:handle_mail_money(PlayerStatus#player.id, NewCoin, NewGold) of
%%         1 ->
%%             gen_server:cast(PlayerStatus#player.other#player_other.pid, 
%% 							{'SET_PLAYER', [{coin, NewCoin}, {gold, NewGold}]});
%%         _ ->
%%             {error, ?OTHER_ERROR}
%%     end.

%% 插入新信件
insert_mail(Type, Timestamp, SName, UId, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Gold) ->
    case db_agent:insert_mail(Type, Timestamp, SName, UId, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Gold) of
        1 ->
            ok;
        _ ->
            {error, ?OTHER_ERROR}
    end.

%% 限制信件数
%% mail_num_limit(PlayerId) ->
%%     case db_agent:mail_num_limit(PlayerId) of
%% 		[] -> ok;
%%         Maillist ->
%%             mail_num_limit(Maillist, ?MAX_NUM)    %% 限制信件数为50
%%     end.

%% %% 信件数量限制为N
%% mail_num_limit(Maillist, N) ->
%%     Len = length(Maillist),
%%     case Len > N of
%%         false ->
%%             ok;
%%         true ->
%%             Mail = get_earliest_mail(Maillist),
%%             [_, Type, _, _, SName, _, _, _, GoodsId, _, Coin, _] = Mail,
%%             del_one_mail(Mail),
%%             case Type == 2 andalso (GoodsId /= 0 orelse Coin /= 0) of
%%                 true ->     %% 私人信件且有附件
%%                     case db_agent:get_mail_player_id(SName) of
%% 						[] -> ok;
%%                         [PlayerId] ->    %% 系统发送了退附件邮件，需检查该用户邮件数
%%                             mail_num_limit(PlayerId)
%%                     end;
%%                 false ->    %% 系统信件/无附件
%%                     ok
%%             end
%%     end.

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
    lists:foreach(fun(Nick) -> check_unread_by_name(Nick) end, NameList).

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
	Content = io_lib:format("内容~p, ~p-~p-~p, ~p:~p:~p", [Start, Year, Month, Day, Hour, Minute, Second]),
	Title = io_lib:format("标题~p", [Start]),
    Type = random:uniform(2),
    Timestamp = util:unixtime(),
    SName = integer_to_list( random:uniform(10000) ),
    GoodsId = 0,
	GoodsTypeId = 0,
    GoodsNum = 0,
    Coin = 0,
    Gold = 0,
    insert_mail(Type, Timestamp, SName, UId, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Gold),
    case N =< 1 of
        true ->
            ok;
        false ->
            timer:sleep(500),
            rand_insert_mail(UId, Start + 1, N - 1)
    end.

%% 刷新客户端
refresh_client(Location, Coin, Cash, Gold, PlayerStatus) ->
    [NewLocation, CellNum, GoodsList] = 
				gen_server:call(PlayerStatus#player.other#player_other.pid_goods, 
				{'list', PlayerStatus, Location}),
    {ok, BinData} = pt_15:write(15010, [NewLocation, CellNum, Coin, Cash, Gold, GoodsList]),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData).

%% 通知客戶端刷新信息
refresh_client(What, Pid_send) ->
    {ok, BinData} = pt_13:write(13005, What),
    lib_send:send_to_sid(Pid_send, BinData).

%% 发送私人信件
%% @spec send_priv_mail/7 -> {ok, RName} | {error, ErrorCode} | {VList, IList}
%% @var     RName : 收件人名，VList : 发送成功名单， IList : 发送失败名单
send_priv_mail(NameList, Title, Content, GoodsId, GoodsNum, Coin, PlayerStatus) ->
    Gold = 0,
    Timestamp = util:unixtime(),	
    case check_mail(NameList, Title, Content, GoodsId, Coin, Gold) of
        {error, Reason} ->
            {error, Reason};
        {ok, RName} ->
            %% 当发送附件时，需消耗道具，未处理（在send_mail_to_one中添加）
			case GoodsId of
				0 -> 
					GoodsTypeId = 0;
				_ ->
					GoodsTypeId = 
        				case lib_mail:get_goods_type_id(GoodsId) of
            				[] ->
                				0;
            				[_PlayerId, GTId] ->
                				GTId;
            				_ ->
                				0
       					end
			end,
            case send_mail_to_one(2, Timestamp, PlayerStatus#player.nickname, RName, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Gold, PlayerStatus) of
                {ok, _NewStatus} ->
                    {ok, RName};
				ok ->
					{ok, RName};
                {error, Reason} ->
                    {error, Reason}
%%             end;
%% 
%%         {ValidNameList, InvalidNameList} ->     %% {正确角色名列表，错误角色名列表}
%%             case send_mail_to_some(2, Timestamp, PlayerStatus#player.nickname, ValidNameList, Title, Content, GoodsId, GoodsNum, Coin, Gold, PlayerStatus) of
%%                 {error, Reason} ->
%%                     {error, Reason};
%%                 {ValidList, OldInvalidList} ->
%%                     NewInvalidList = InvalidNameList ++ OldInvalidList,
%%                     {ValidList, NewInvalidList}
            end
    end.

%% 发送信件给一个收件人
%% @spec send_mail_to_one/11 -> ok | {error, ErrorCode}
send_mail_to_one(Type, Timestamp, SName, RName, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Gold, PlayerStatus) ->
    case db_agent:get_mail_player_id(RName) of
        []->
            {error, ?WRONG_NAME};
        [UId]->
			case Type of
				0 ->
					case insert_mail(Type, Timestamp, SName, UId, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Gold) of
						ok ->
							if
								Coin =/= 0 orelse Gold=/= 0 orelse GoodsId =/=0 orelse GoodsTypeId =/= 0->
									spawn(fun()-> db_agent:insert_mail_log(Timestamp, SName, UId, RName, GoodsId, GoodsTypeId, GoodsNum, Coin, Gold, 0, 1) end);
								true ->
									skip
							end,
							ok;
						Error ->
							Error
					end;
				1 ->
					case insert_mail(Type, Timestamp, SName, UId, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Gold) of
						ok ->
							if
								Coin =/= 0 orelse Gold=/= 0 orelse GoodsId =/=0 orelse GoodsTypeId =/= 0->
									spawn(fun()-> db_agent:insert_mail_log(Timestamp, SName, UId, RName, GoodsId, GoodsTypeId, GoodsNum, Coin, Gold, 0, 1) end);
								true ->
									skip
							end,
							ok;
						Error ->
							Error
					end;
				2 ->
					case check_mail_full(UId) of
						true ->
							{error, ?MAIL_FULL};
						_ ->			
            				case [GoodsId, GoodsTypeId] of
                				[0, 0] ->        %% 只有铜钱 (+ 元宝)
		                            Pay = ?POSTAGE + Coin,  %% 发信时需扣取的铜钱数
                            		case handle_money(PlayerStatus, Pay) of
                                		{ok, Newstatus1} ->
											%% 刷新背包
                                    		refresh_client(2, Newstatus1#player.other#player_other.pid_send),
                                    		ReturnMailId = db_agent:insert_mail_return_id(Type, Timestamp, SName, UId, Title, Content, GoodsId , GoodsTypeId, GoodsNum, Coin, Gold),
											if
												Coin =/= 0 orelse Gold=/= 0 orelse GoodsId =/=0 orelse GoodsTypeId =/= 0->
													spawn(fun()-> db_agent:insert_mail_log(Timestamp, SName, UId, RName, GoodsId, GoodsTypeId, GoodsNum, Coin, Gold, ReturnMailId, 1) end);
												true ->
													skip
											end,
											{ok, Newstatus1};
                                		Error ->
                                    		Error
                            		end;
								[0, Val] when Val =/= 0 ->
									{error, ?GOODS_NOT_EXIST};
				                _ ->        %% 物品 + 铜钱 (+ 元宝)
                            		case handle_goods_send(PlayerStatus, GoodsId, GoodsNum, Coin) of    %% 处理物品
                                		{ok, NewId} ->
                                    		Pay = ?POSTAGE + Coin,  %% 发信时需扣取的铜钱数
                                    		case handle_money(PlayerStatus, Pay) of       %% 扣费
                                        		{ok, Newstatus1} ->
													%% 刷新背包
                                           			refresh_client(2, Newstatus1#player.other#player_other.pid_send),   
													ReturnMailId = db_agent:insert_mail_return_id(Type, Timestamp, SName, UId, Title, Content, NewId, GoodsTypeId, GoodsNum, Coin, Gold),
													spawn(fun()-> db_agent:insert_mail_log(Timestamp, SName, UId, RName, GoodsId, GoodsTypeId, GoodsNum, Coin, Gold, ReturnMailId, 1) end),
                                                    {ok, Newstatus1};
                                        		Error ->
                                            		Error
                                    		end;
                                		Error ->
                                    		Error
                            		end
							  end
                    	end
            end;
        _ ->
            {error, ?OTHER_ERROR}
    end.

%% 发送信件给多个收件人
%% @spec send_mail_to_some/11 -> {error, ErrorCode} | {VList, IList}
%%      VList : 信件已正确发送的收件人列表
%%      IList : 未正确发送的收件人列表
send_mail_to_some(Type, Timestamp, SName, NameList, Title, Content, GoodsId, GoodsNum, Coin, Gold, _PlayerStatus) ->
    F = fun(RName) ->
            case db_agent:get_mail_player_id(RName) of
                [] ->
                    false;
                [UId] ->
                    case Type of
                        1 ->        %% 系统信件可群发金钱附件
                            case insert_mail(Type, Timestamp, SName, UId, Title, Content, 0, 0, 0, Coin, Gold) of
                                ok ->
                                    true;
                                {error, _} ->
                                    false
                            end;
                        2 ->
							case check_mail_full(UId) of
								true ->
									false;
								_ ->
                            		case GoodsId == 0 andalso Coin == 0 of
                                		true ->     %% 私人信件（无物品）
                                    		case insert_mail(Type, Timestamp, SName, UId, Title, Content, GoodsId, 0, GoodsNum, Coin, Gold) of
                                        		ok ->
                                            		true;
                                        		Error ->
                                            		Error
                                    		end;
                                		false ->   %% 有物品，群发不能发送
                                    		false
                            		end
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
        _ ->
			
%%	私人邮件不支持群发
%%             NewCoin = PlayerStatus#player.coin - ?POSTAGE,
%%             case NewCoin >= 0 of
%%                 true ->
%%                     {VList, IList} = lists:partition(F, NameList),
%%                     case VList of
%%                         [] ->   %% 无成功发送
%%                             {error, ?WRONG_NAME};
%%                         _ ->    %% 扣费
%%                             case db_agent:update_player_coin(PlayerStatus, ?POSTAGE, sub) of%%修改money更新方式
%%                                 1 ->
%%                                     NewCoin = PlayerStatus#player.coin - ?POSTAGE,
%%                                     NewCash = PlayerStatus#player.cash,
%%                                     NewGold = PlayerStatus#player.gold,
%%                                     gen_server:cast(PlayerStatus#player.other#player_other.pid, 
%% 													{'SET_PLAYER', [{coin, NewCoin},{cash, NewCash}, {gold, NewGold}]}),
%%                                     %refresh_client(4, NewCoin, NewCash, NewGold, PlayerStatus);%% 刷新背包
%% %%                                     refresh_client(2, PlayerStatus#player.other#player_other.pid_send);   %% 刷新背包
%% %%                                 _ ->
%% %%                                     error
%% %%                             end,
%% %%                             {VList, IList}
%% %%                     end;
%% %%                 false ->
%%                     {error, ?NOT_ENOUGH_COIN}
%%             end;
%%         _ ->
            {error, ?OTHER_ERROR}
    end.

%% 发送系统信件
%% @spec send_sys_mail/8 -> {ok, InvalidList} | {error, Reason}
%%          InvalidList : 未发送的名单
%%          Reason      : 错误码（数字），对应含义见宏定义
send_sys_mail(NameList, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Gold) ->
    Timestamp = util:unixtime(),
    case check_mail(NameList, Title, Content, GoodsId, Coin, Gold) of
        {error, Reason} ->
            {error, Reason};
        {ok, Name} ->
            case send_mail_to_one(1, Timestamp, "系统", NameList, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Gold, []) of
                {ok, _NewStatus} -> %% 发送成功
                    check_unread_by_name(Name),
                    {ok, []};
				ok -> %% 发送成功
                    check_unread_by_name(Name),
                    {ok, []};
                {error, Reason} ->
                    {erorr, Reason}
            end;
        {ValidNameList, InvalidNameList} ->
            case send_mail_to_some(1, Timestamp, "系统", ValidNameList, Title, Content, GoodsId, GoodsNum, Coin, Gold, []) of
                {error, Reason} ->
                    {error, Reason};
                {ValidList, OldInvalidList} ->
                    NewInvalidList = InvalidNameList ++ OldInvalidList,
                    new_mail_notify(ValidList),
                    {ok, NewInvalidList}
            end
    end.
%% 发送系统信件(可选择发绑定的物品)
%% @spec send_sys_mail/9 -> {ok, InvalidList} | {error, Reason}
%%          InvalidList : 未发送的名单
%% 			GoodsBind：	为0时，发绑定的物品，其他值如1时不绑定
%%          Reason      : 错误码（数字），对应含义见宏定义
send_sys_mail(NameList, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Gold, GoodsBind) ->
    Timestamp = util:unixtime(),
    case check_mail(NameList, Title, Content, GoodsId, Coin, Gold) of
        {error, Reason} ->
            {error, Reason};
        {ok, Name} ->
%% 			?DEBUG("GoodsBind:~p", [GoodsBind]),
            case send_mail_to_one(GoodsBind, Timestamp, "系统", NameList, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, Gold, []) of
                {ok, _NewStatus} -> %% 发送成功
                    check_unread_by_name(Name),
                    {ok, []};
				ok -> %% 发送成功
                    check_unread_by_name(Name),
                    {ok, []};
                {error, Reason} ->
                    {erorr, Reason}
            end;
        {ValidNameList, InvalidNameList} ->
            case send_mail_to_some(GoodsBind, Timestamp, "系统", ValidNameList, Title, Content, GoodsId, GoodsNum, Coin, Gold, []) of
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
    [id | FieldList] = record_info(fields, goods),                      %% 得到表中对应的列名
    case db_agent:get_mail_goods_id(PlayerId) of    %% 获取原cell为0的该用户物品Id列表
        error ->
            {error, ?OTHER_ERROR};
        List1 ->
            case db_agent:insert_mail_goods(FieldList, NewInfo) of      %% 插入新物品
                1 ->
                    %% 修改原物品
                    case db_agent:update_mail_goods(NewNum1, GoodsId) of 
                        1 ->
                            update_online_goods(Goods#goods.id, 4, Goods#goods.cell, NewNum1),  %% 更新在线物品表
                            %% 获取新cell为0的该用户物品Id列表
                            case db_agent:get_mail_goods_id(PlayerId) of 
								[]	-> {error, ?OTHER_ERROR};
                                error ->
                                    {error, ?OTHER_ERROR};
                                List2 ->
                                    [[NewGoodsId]] = List2 -- List1,
                                    db_agent:update_mail_goods(NewGoodsId),
                                    {ok, NewGoodsId}
                            end;
                        _ ->
                            {error, ?OTHER_ERROR}
                    end;
                _ ->
                    {error, ?OTHER_ERROR}
            end
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
            db_agent:delete_mail_goods(GId);
        _ ->
            update_online_goods(GId, 4, Cell, Num), %% 更新ets_goods_online表数据
            NewNullCells = NullCells,
            db_agent:update_mail_goods(Cell, Num, GId)
    end,
    update_goods(NewList, NewNullCells).

%% 去掉信件的附件
update_mail(MailId) ->
    db_agent:update_mail_attachment(MailId).

%% 更新在线物品
update_online_goods(GoodsId, NewLocation, NewCell, NewNum) ->
    [Goods] = ets:lookup(?ETS_GOODS_ONLINE, GoodsId),
    NewGoods = Goods#goods{location = NewLocation, cell = NewCell, num = NewNum},
    ets:insert(?ETS_GOODS_ONLINE, NewGoods).

%% ----------------------------------------------------------
%% 19008 删除已读邮件
%% ----------------------------------------------------------
delete_read_mail(PlayerId) ->
	MailList = db_agent:get_read_mail_candelete(PlayerId),
	catch lists:foreach(fun(Mail) -> del_one_mail(Mail) end, MailList),
	1.