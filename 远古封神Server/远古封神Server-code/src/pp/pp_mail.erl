%%%------------------------------------
%%% @Module     : pp_mail
%%% @Author     : ygzj
%%% @Created    : 2010.10.05
%%% @Description: 信件操作
%%%------------------------------------
-module(pp_mail).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl"). 

%% 客户端发信
handle(19001, PlayerStatus, Data) ->
	Timestamp = util:unixtime(),
	Last_send = get(send_mail_time),
	Could_send =
		case Last_send  of
			undefined ->
				ok;
			Val when Timestamp - Val > 4 ->
				ok;
			_ ->
				error
		end,
	case Could_send of
		ok ->
			put(send_mail_time, Timestamp),
			[RName, Title, Content, GoodsId, GoodsNum, Coin] = Data,
			%%获取物品ID
			case GoodsId of
				0 -> 
					GoodsTypeId = 0;
				_ ->
%% ?DEBUG("19001_1111111111111_~p ~n",[lib_mail:get_goods_type_id(GoodsId)]),
					GoodsTypeId = 
        				case lib_mail:get_goods_type_id(GoodsId) of
            				[] ->
                				0;
            				[PlayerId, GTId] ->
								if
									PlayerId =:= PlayerStatus#player.id ->
										GTId;
									true ->
										0
								end;
            				_ ->
                				0
       					end
			end,
			%%对标题和邮件内容进行敏感词处理
			Title_ver = lib_words_ver:words_ver(Title),
			Content_ver = lib_words_ver:words_ver(Content),
			IsWarServer = lib_war:is_war_server(),
			if
				Title_ver =:= false ->
    				{ok, BinData} = pt_19:write(19001, [2]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
					ok;
				Content_ver =:= false ->
    				{ok, BinData} = pt_19:write(19001, [3]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
					ok;
				GoodsId =/= 0 andalso GoodsTypeId =:= 0 ->
					{ok, BinData} = pt_19:write(19001, [9]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
					ok;
				%%跨服不能发送邮件
				IsWarServer ->
					{ok, BinData} = pt_19:write(19001, [13]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
					ok;
				true ->
					case lib_mail:send_mail_to_one(2, Timestamp, PlayerStatus#player.nickname, RName, Title, Content, GoodsId, GoodsTypeId, GoodsNum, Coin, 0, PlayerStatus) of
    					{ok, NewStatus} ->
            				lib_mail:check_unread_by_name(RName),             %% 通知收件人有未读邮件
							{ok, BinData} = pt_19:write(19001, [1]),          %% 发送成功
							lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
							mod_player:save_online(NewStatus),
							{ok, NewStatus};
    					{error, Reason} ->
							put(send_mail_time, Last_send),
    						{ok, BinData} = pt_19:write(19001, [Reason]),
							lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
							ok;
						_ ->
							ok
    				end
			end;
		_ ->
    		{ok, BinData} = pt_19:write(19001, [13]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
			ok
	end;

%% 获取信件
handle(19002, PlayerStatus, MailId) ->
    {_Sta, _Mail} = lib_mail:get_mail(MailId, PlayerStatus#player.id),
	ok;

%% 删除信件
handle(19003, PlayerStatus, Data) ->
    IdList = Data,
    case lib_mail:del_mail(IdList, PlayerStatus#player.id) of
        ok ->
            {ok, BinData} = pt_19:write(19003, 1);
        _ ->
            {ok, BinData} = pt_19:write(19003, 0)
    end,
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%% 获取信件列表及内容
handle(19004, PlayerStatus, [Mail_type, Mail_page_p]) ->
	Mail_page =
		if 
			Mail_page_p > 10 ->
				10;
			Mail_page_p < 1 ->
				1;
			true ->
				Mail_page_p
		end,
	Mail_list = db_agent:get_maillist_all(PlayerStatus#player.id),
	Mail_count = length(Mail_list),
	case Mail_count of
		0 ->
			{ok, BinData} = pt_19:write(19004, [0, 0, Mail_page, []]);
		_ ->
			{Mail_current, Mails} = lib_mail:get_mails(Mail_list, Mail_count, Mail_type, Mail_page),			
			{ok, BinData} = pt_19:write(19004, [1, Mail_current, Mail_page, Mails])
	end,
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

%% 查询有无未读邮件
handle(19005, Player, check_unread) ->
	lib_mail:check_unread(Player#player.id);

%% 提取附件
handle(19006, PlayerStatus, Data) ->
    MailId = Data,
	Timestamp = util:unixtime(),
	Last_get = get(get_mail_time),
	Could_get =
		case Last_get of
			undefined ->
				ok;
			{Last_MailId, Last_time} when Last_MailId =:= MailId andalso Timestamp - Last_time < 6 ->
				error;
			_ ->
				ok
		end,
	case Could_get of
		ok ->
    		case lib_mail:get_attachment(PlayerStatus, MailId) of
        		{ok, Status} ->
            		%timer:sleep(5),    %% Erlang模拟客户端测试需要
					put(get_mail_time, {MailId, Timestamp}),
            		{ok, BinData} = pt_19:write(19006, [1, MailId]),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					{ok, Status};        %% 提取附件成功，附件中有铜币或者元宝
				ok ->
					put(get_mail_time, {MailId, Timestamp}),
            		{ok, BinData} = pt_19:write(19006, [1, MailId]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
					ok;			%% 提取附件成功		
        		{error, ErrorCode} ->
					put(get_mail_time, Last_get),
            		{ok, BinData} = pt_19:write(19006, [ErrorCode, MailId]),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
					ok
    		end;
		_ ->
			ok
	end;
%% -----------------------------------------------------------------
%% 19008 删除已读邮件
%% -----------------------------------------------------------------
handle(19008, Status, []) ->
	Result = mod_mail:delete_read_mail(Status),
	{ok, BinData19008} = pt_19:write(19008, [Result]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData19008),
	ok;
	
	
%% 处理玩家反馈信息
handle(19010, PlayerStatus, Data) ->
    [Type, Title, Content] = Data,
    PlayerId = PlayerStatus#player.id,
    PlayerName = PlayerStatus#player.nickname,
    {ok, {Address, _Port}} = inet:peername(PlayerStatus#player.other#player_other.socket),   %% 获得对方IP地址
    Result = lib_mail:feedback(Type, Title, Content, Address, PlayerId, PlayerName),
    {ok, BinData} = pt_19:write(19010, Result),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData);

handle(_, _, _) ->
%%     ?DEBUG("pp_mail no match", []),
    {error, "pp_mail no match"}.
