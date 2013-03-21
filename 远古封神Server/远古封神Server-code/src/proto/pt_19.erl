%%------------------------------------
%%% @Module     : pt_19
%%% @Author  	: ygzj
%%% @Created 	: 2010.10.05
%%% @Description: 信件协议处理 
%%%------------------------------------
-module(pt_19).
%% -export([]).
-compile(export_all).
-include("common.hrl").
-include("record.hrl").

%%
%%客户端 -> 服务端 ----------------------------
%%

%% 发送信件
read(19001, Bin) ->
	{RName, Bin2} =	pt:read_string(Bin),
	{Title, ContentBin} =	pt:read_string(Bin2),
	{Content, Rest2} =	pt:read_string(ContentBin),
	case Rest2 of
		<<GoodsId:32, GoodsNum:8, Coin:32>> ->
    		{ok, [RName, Title, Content, GoodsId, GoodsNum, Coin]};
    	_ ->
   		{error, no_match}
   end;


%% 获取信件
read(19002, Bin) ->
    case Bin of
        <<Id:32>> ->
            {ok, Id};
        _ ->
            {error, no_match}
    end;

%% 删除信件
read(19003, Bin) ->                 %% 选中删除
    <<N:16, Bin2/binary>> = Bin,
    case get_list2([], Bin2, N) of
        error ->
            {error, no_match};
        {IdList, _RestBin} ->
            {ok, IdList}
    end;

%% 获取信件列表
read(19004, <<Mail_type:8, Mail_page:8>>) ->
    {ok, [Mail_type, Mail_page]};

%% 查询有无未读邮件
read(19005, _) ->
    {ok, check_unread};

%% 提取附件
read(19006, <<MailId:32>>) ->
    {ok, MailId};

%% ----------------------------------------------------------
%% 19008 删除已读邮件
%% ----------------------------------------------------------
read(19008, _R) ->
	{ok, []};

%% 玩家反馈
read(19010, <<Type:16, Bin/binary>>) ->
    case pt:read_string(Bin) of
        {[], <<>>} ->
            {error, no_match};
        {Title, Bin2} ->
            case pt:read_string(Bin2) of
                {[], <<>>} ->
                    {error, no_match};
                {Content, _} ->
                    {ok, [Type, Title, Content]}
            end
    end;

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%% 回应客户端发信
write(19001, Data) ->
    case Data of
        [SendStatus] ->
            case is_integer(SendStatus) of
                true ->
                    case SendStatus < 0 of
                        true ->
                            {error, no_match};
                        false ->
                            {ok, pt:pack(19001, <<SendStatus:8>>)}
                    end;
                false ->
                    {error, no_match}
            end;
        _ ->
            {error, no_match}
    end;

%% 获取信件
%% write(19002, [Result | RestData]) ->
%%     case Result of
%%         2 ->
%%             MailId = RestData,
%%             {ok, pt:pack(19002, <<2:16, % 结果，成功-1 / 无该信件-2 / 读取信件失败-3
%%                     MailId:32,      % int:32 信件id
%%                     0:16,           % int:32 时间戳（不成功为空）
%%                     0:16, "",       % string 发件人（不成功为空）
%%                     0:16, "",       % string 信件标题（不成功为空）
%%                     0:16, "",       % string 信件内容（不成功为空）
%%                     0:32,           % int:32 物品类型ID（无则为0）
%%                     0:32,           % int:32 铜钱数
%%                     0:32>>)};       % int:32 元宝数
%%         3 ->
%%             MailId = RestData,
%%             {ok, pt:pack(19002, <<3:16, MailId:32, 0:16, 0:16, "", 0:16, "", 0:16, "", 0:32, 0:32, 0:32>>)};
%%         1 ->
%%             case RestData of
%%                 [MailId, _, _, Timestamp, SName, _, Title, Content, GoodsId, GoodsNum, Coin, Gold] ->
%%                     case lib_mail:get_goods_type_id(GoodsId) of
%%                         [] ->
%%                             GoodsTypeId = 0;
%%                         [GoodsTypeId] ->
%%                             ok;
%%                         _ ->
%%                             GoodsTypeId = 0
%%                     end,
%%                     Len1 = byte_size(SName),
%%                     Len2 = byte_size(Title),
%%                     Len3 = byte_size(Content),
%%                     {ok, pt:pack(19002, <<1:16, MailId:32, Timestamp:32, Len1:16, SName/binary, Len2:16, Title/binary, Len3:16, Content/binary, GoodsTypeId:32, GoodsNum:32, Coin:32, Gold:32>>)};
%%                 _ ->
%%                     {error, no_match}
%%             end;
%%         _ ->
%%             {error, no_match}
%%     end;

%% 删除信件
write(19003, Result) ->
    case is_integer(Result) of
        true ->
            case Result > 1 orelse Result < 0 of
                true ->
                    {error, no_match};
                false ->
                    {ok, pt:pack(19003, <<Result:16>>)}
            end;
        false ->
            {error, no_match}
    end;

%% 信件列表
write(19004, [Result, Mail_num, Mail_page, Maillist]) ->
%% ?DEBUG("19004_write_~p/~p ~n",[Mail_num, Mail_page]),
    case Result of
        0 ->
            {ok, pt:pack(19004, <<0:8, 0:8, Mail_page:8, 0:16>>)};
        1 ->
            F = fun(Mail) ->
                    [Id, Type, State, Timestamp, SName, _RName,
                        Title, Content, GoodsId, GoodsNum, Coin, Gold, GoodsTypeId] = Mail,

                    Len1 = byte_size(tool:to_binary(SName)),
                    Len2 = byte_size(tool:to_binary(Title)),
					Len3 = byte_size(tool:to_binary(Content)),
                    <<Id:32, Type:8, State:8, Timestamp:32, Len1:16, SName/binary, Len2:16, Title/binary, Len3:16, Content/binary, GoodsId:32, GoodsTypeId:32, GoodsNum:16, Gold:32, Coin:32>>
            end,
            MailNum = length(Maillist),
            BinList = tool:to_binary([F(Mail) || Mail <- Maillist]),
			{ok, pt:pack(19004, <<1:8, Mail_num:8, Mail_page:8, MailNum:16, BinList/binary>>)};
        _ ->
            {error, no_match}
    end;

%% 新信件通知
%% Result 0-无未读邮件, 1-有未读邮件, 2-查询失败
write(19005, {Result,Nums}) ->
    {ok, pt:pack(19005, <<Result:16,Nums:16>>)};

%% 提取附件
write(19006, [Result, MailId]) ->
    case is_integer(Result) of
        true ->
            case Result > 4 orelse Result < 0 of
                true ->
                    {error, no_match};
                false ->
                    {ok, pt:pack(19006, <<Result:16, MailId:32>>)}
            end;
        false ->
            {error, no_match}
    end;

%% 玩家反馈
write(19010, Result) ->
    case is_integer(Result) of
        true ->
            case Result > 1 orelse Result < 0 of
                true ->
                    {error, no_match};
                false ->
                    {ok, pt:pack(19010, <<Result:16>>)}
            end;
        false ->
            {error, no_match}
    end;

write(19007, _) ->
    {ok, pt:pack(19007, <<>>)};

%% ----------------------------------------------------------
%% 19008 删除已读邮件
%% ----------------------------------------------------------
write(19008, [Result]) ->
	 {ok, pt:pack(19008, <<Result:16>>)};

write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.

%% 获取列表（读取角色名称列表）
%% 列表每项为String，对应<<Length:16, String/binary>>
%% AccList列表累加器，使用时初始为[]
get_list(AccList, Bin, N) when N > 0 ->
    case Bin of
        <<Len:16, Bin2/binary>> ->
            <<Item:Len/binary-unit:8, Rest/binary>> = Bin2,
            Item2 = binary_to_list(Item),
            NewList = [Item2 | AccList],
            get_list(NewList, Rest, N - 1);
        _R1 ->
            error
    end;
get_list(AccList, Bin, _) ->
    {AccList, Bin}.

%% 获取列表（读取信件id列表）
%% 列表每项为int32
get_list2(AccList, Bin, N) when N > 0 ->
    case Bin of
        <<Item:32, Bin2/binary>> ->
            NewList = [Item | AccList],
            get_list2(NewList, Bin2, N - 1);
        _ ->
            error
    end;
get_list2(AccList, Bin, _N) ->
    {AccList, Bin}.
