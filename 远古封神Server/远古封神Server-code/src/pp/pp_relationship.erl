%%%--------------------------------------
%%% @Module  : pp_relationship
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description:  管理玩家间的关系 
%%%--------------------------------------
-module(pp_relationship).
-include("record.hrl").
-include("common.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-compile(export_all).

%% 好友上限
-define(MAX_FRIENDS, 50).
-define(MAX_BOTTLE_EXP, 500000).
-define(MAX_BOTTLE_SPR, 250000).


%% %%好友资料
%% -record(ets_rela_info, {
%%     id = 0,             %%角色id
%%     nickname = [],      %%角色名字
%%     sex = 0,            %%角色性别
%%     lv = 0,             %%角色等级
%%     career = 0          %%角色职业
%%     }).

%% 请求好友列表
handle(14000, Player, [], _PlayerState) ->
	lib_relationship:pp_get_friend_list(Player);

%% 发送好友请求
%% Type 加好友的类型(1:常规加好友,2:黑名单里加好友,3:仇人里加好友)
%% Uid 用户ID
%% Nick 角色名
handle(14001, Status, [Type, Uid, Nick], _PlayerState) ->
	%%跨服不能加好友
	case lib_war:is_war_server() of
		false->
			lib_relationship:send_friend_request(Status, Type, Uid, Nick);
		true->skip
	end;

%%回应好友请求
%%Type:加好友的类型(1:常规加好友,2:黑名单里加好友,3:仇人里加好友)
%%Res:拒绝或接受请求(0表示拒绝/1表示接受)
%%Uid:用户ID
handle(14002, Status, [_Type, Res, Uid], _PlayerState) ->
    case Res of
        0 ->
            Data1 = [2, Res, Status#player.id,Status#player.lv, Status#player.sex, 
					 Status#player.career, Status#player.nickname],
            {ok, BinData} = pt_14:write(14002, Data1),
            lib_send:send_to_uid(Uid, BinData);
        1 ->
            %%保证有数据
%%             lib_relationship:set_ets_rela_record(Status#player.id),
            %%查看是否已经加过好友了
            {_, F1} = lib_relationship:is_exists_remote(Uid, Status#player.id, 1),
            {_, F2} = lib_relationship:is_exists(Status#player.id, Uid, 1),
            case F1 orelse F2 of
                false ->
					His_Friend_Full = lib_relationship:friend_num_remote(Uid),
					%%此处会返回对方好友是否已满，true满,false不满
					L_len_rsp = lib_relationship:get_idA_list(Status#player.id, 1),
					%%VIP额外添加好友上限
					{_NewStatus,_,Award} = lib_vip:get_vip_award(friend,Status),
					NewMaxFriends = Award + ?MAX_FRIENDS,
					MyFriendNum = erlang:length(L_len_rsp),
					if 
						His_Friend_Full ->
							{ok, BinDataReq} = pt_14:write(14002, [2, 5]),
            				lib_send:send_to_uid(Uid, BinDataReq),
							{ok, BinDataRsp} = pt_14:write(14002, [1, 5]),
							lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinDataRsp),
							ok;
						MyFriendNum >= NewMaxFriends ->
							{ok, BinDataReq} = pt_14:write(14002, [2, 4]),
            				lib_send:send_to_uid(Uid, BinDataReq),
							{ok, BinDataRsp} = pt_14:write(14002, [1, 4]),
							lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinDataRsp),
							ok;
						true ->
							lib_achieve:check_achieve_finish(Status#player.other#player_other.pid_send,Status#player.id, 625, [1]),%%拥有一个好友
							case MyFriendNum of
								4 ->
									lib_achieve:check_achieve_finish(Status#player.other#player_other.pid_send,Status#player.id, 606, [1]);
								19 ->
									lib_achieve:check_achieve_finish(Status#player.other#player_other.pid_send,Status#player.id, 607, [1]);
								29 ->
									lib_achieve:check_achieve_finish(Status#player.other#player_other.pid_send,Status#player.id, 608, [1]);
								_ ->
									ok
							end,
							Pattern = #ets_rela{pid=Status#player.id,rid=Uid,rela=4,_='_'},
							Info = 
							case ets:match_object(?ETS_RELA, Pattern) of
								[] -> skip;
								[Rela] -> Rela
							end,
							Close = 
								case is_record(Info,ets_rela) of
									true ->
										{DbId,_P,_R} = Info#ets_rela.id,
										ets:delete(?ETS_RELA,{DbId,Status#player.id,4}),
										%%删除数据库记录
										spawn(fun()-> db_agent:relationship_delete(DbId) end),
										%%删除对方的关系4
										response_friend_delete(Uid, DbId, 4),
										Info#ets_rela.close;
									false -> 
										%%("____________ISRECORD FALSE, Info = ~p_________",[Info]),
										1
								end,
                    		lib_relationship:add(Status#player.id, Uid, 1, Close),
                   		 	case lib_relationship:is_exists(Status#player.id, Uid, 3) of
                        		{RecordId3, true} ->
                            		lib_relationship:delete(RecordId3,Status#player.id,3),
									lib_relationship:get_enemy_list(Status);
                        		{ok, false} -> ok
                    		end,
							lib_relationship:get_friend_list(Status),
				
                    		Data = [Res, Status#player.id,Status#player.lv, Status#player.sex, 
							 		Status#player.career, Status#player.nickname],
							Data1 = [1|Data],
                    		{ok, BinData1} = pt_14:write(14002, Data1),
							lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData1),
							
							Data2 = [2|Data],
                    		{ok, BinData2} = pt_14:write(14002, Data2),
							Id = lib_relationship:get_id(Status#player.id, Uid, 1),
							response_friend_request(BinData2, Uid, Status#player.id, Id, Close), %%回应好友请求后， 要求请求方做相关处理
							ok
					end;
                true -> ok
            end
    end;
    

%%删除好友
%%Rec_id 要删除的记录号
handle(14003, Status, Rec_id, _PlayerState) ->
    case lib_relationship:is_exists_Rid(Rec_id, Status#player.id, 1) of
        {ok, false} -> 
			ok;
        {Id, true} ->
%% 		IdB = lib_relationship:get_idB(Id, Status#player.id, 1),
			Uid =
				case lib_relationship:get_idB(Id, Status#player.id, 1) of
					[[L]]
					  ->
						L;
					_ ->
						error
				end,
			Close = 
				case ets:lookup(?ETS_RELA,{Id,Status#player.id,1}) of
					[] -> 0;
					[Info] -> Info#ets_rela.close
				end,
			CloseLevel = lib_relationship:get_close_level(Close),
			if CloseLevel >=3 ->
				   case lib_relationship:add_rela_special(Status#player.id,Uid,4,Close) of
					   0 -> skip;
					   NewRela ->%%对方内存ets也要改变
						   case lib_player:get_player_pid(Uid) of
							   [] -> skip;
							   Pid -> gen_server:cast(Pid, {add_special, NewRela})
						   end
				   end;	  			   
			   true ->

				   skip
			end,
			lib_relationship:delete(Id,Status#player.id,1),
            {ok, BinData} = pt_14:write(14003, 1),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			case Uid of
				error ->
					error;
				_ ->
					response_friend_delete(Uid, Id, 1),
					%%删除中秋活动的日志记录
					lib_relationship:delete_midaward_data(Status#player.id,Uid)
			end
    end,
	lib_relationship:get_friend_list(Status);

%%添加黑名单
%%_Uid 玩家友Id
%%_Nick 玩家名字
handle(14004, Status, Uid, _PlayerState) ->
    %% 保证有数据
    case lib_relationship:is_exists(Status#player.id, Uid, 2) of
        {_, true} -> 
			ok;
        {ok, false} ->
			case lib_relationship:add(Status#player.id, Uid, 2, 0) of
				0 ->
                   	{ok, BinData} = pt_14:write(14004, [0,0]),
                    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
				_ ->
					%%删除好友关系
                    case lib_relationship:is_exists(Status#player.id, Uid, 1) of
                        {RecordId1, true} ->
							%%要求对方删除好友
							Close = 
								case ets:lookup(?ETS_RELA,{RecordId1,Status#player.id,1}) of
									[] -> 0;
									[Info] -> Info#ets_rela.close
								end,
							CloseLevel = lib_relationship:get_close_level(Close),
							if CloseLevel >=3 ->
								   case lib_relationship:add_rela_special(Status#player.id,Uid,4,Close) of
											   0 -> skip;
											   NewRela ->%%对方内存ets也要改变
												   case lib_player:get_player_pid(Uid) of
													   [] -> skip;
													   Pid -> gen_server:cast(Pid, {add_special, NewRela})
												   end
								   end;	  
							   true -> skip						   
							end,
							response_friend_delete(Uid, RecordId1, 1),
                            lib_relationship:delete(RecordId1,Status#player.id,1),
							%%删除中秋活动的日志记录
							lib_relationship:delete_midaward_data(Status#player.id,Uid),
							lib_relationship:get_friend_list(Status);
                        {ok, false} ->
                            ok
                    end,
                	%%删除仇人关系
                    case lib_relationship:is_exists(Status#player.id, Uid, 3) of
                        {RecordId3, true} ->
                            lib_relationship:delete(RecordId3,Status#player.id,3),
							lib_relationship:get_enemy_list(Status);
                        {ok, false} ->
                            ok
                    end,
                    {ok, BinData} = pt_14:write(14004,[1,Uid]),
                    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
					lib_relationship:get_back_list(Status),
%% 					request_to_blacklist(Status#player.id, Uid),  %%告之被加黑名单的用户,更新好友列表
					ok
			end
    end;

%% 添加仇人
%% Uid 仇人ID
handle(14005, Status, Uid, _PlayerState) ->
    %% 保证有数据
	case lib_relationship:is_exists(Status#player.id, Uid, 2) of
		{_, true} -> ok;
		{ok, false} ->
    		case lib_relationship:is_exists(Status#player.id, Uid, 3) of
        		{_, true} -> ok;
        		{ok, false} ->
           			case lib_relationship:add(Status#player.id, Uid, 3, 0) of
						0 ->
                   			{ok, BinData} = pt_14:write(14005, [0,0]),
                    		lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
							ok;
						_ ->
                    		% 删除好友关系
							case lib_relationship:is_exists(Status#player.id, Uid, 1) of
    							{RecordId1, true} ->
									Close = 
										case ets:lookup(?ETS_RELA,{RecordId1,Status#player.id,1}) of
											[] -> 0;
											[Info] -> Info#ets_rela.close
										end,
									CloseLevel = lib_relationship:get_close_level(Close),
									if CloseLevel >=3 ->
										   case lib_relationship:add_rela_special(Status#player.id,Uid,4,Close) of
											   0 -> skip;
											   NewRela ->%%对方内存ets也要改变
												   case lib_player:get_player_pid(Uid) of
													   [] -> skip;
													   Pid -> gen_server:cast(Pid, {add_special, NewRela})
												   end
										   end;		   
									   true ->
										   %%("__________14005 CLOSELEVEL < 3 CLOSE = ~p____________",[Close]),
										   skip
									end,
									%%要求对方删除好友
									response_friend_delete(Uid, RecordId1, 1),
        							lib_relationship:delete(RecordId1,Status#player.id,1),
									%%删除中秋活动的日志记录
									lib_relationship:delete_midaward_data(Status#player.id,Uid),
                            		handle(14000, Status, [], _PlayerState);
    							{ok, false} -> ok
							end,
                    		{ok, BinData} = pt_14:write(14005, [1, Uid]),
                    		lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
							handle(14008, Status, [], _PlayerState),
							ok
            		end
    		end
	end;

%% 请求黑名单列表
handle(14007, Player, [], _PlayerState) ->
	lib_relationship:get_back_list(Player);

%% 请求仇人列表
handle(14008, Player, [], _PlayerState) ->
	lib_relationship:get_enemy_list(Player);

%% 查找角色
handle(14010, Status, Nick, _PlayerState) ->
    if 
        Nick =/= Status#player.nickname ->
			case lib_player:get_role_id_by_name(Nick) of
				null ->
					{ok, BinData} = pt_14:write(14010, []),
                    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
				PlayerId ->
					case lib_player:get_online_info_fields(PlayerId, [lv, sex, career, guild_name, nickname, realm]) of
                        [] -> 
                            {ok, BinData} = pt_14:write(14010, []),
                            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
                        [Lv, Sex, Career, Guild_name, Nickname, Realm] ->
                            Data = [1, PlayerId, Lv, Sex, Career, Guild_name, Nickname, Realm],
                            {ok, BinData} = pt_14:write(14010, Data),
                            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
                 	end
			end;
        true ->
            Data = [1, Status#player.id, Status#player.lv, 
					Status#player.sex, Status#player.career, 
					Status#player.guild_name, Status#player.nickname,
					Status#player.realm],
            {ok, BinData} = pt_14:write(14010, Data),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
 end;

%%查询陌生人资料
handle(14013, Status, Uid, _PlayerState) ->
    case Uid =/= Status#player.id of
        true -> case lib_player:get_online_info_fields(Uid, [lv,sex,career,guild_name,nickname,vip]) of
                [] -> ok;
                [Lv, Sex, Career, _Guild_name, Nickname,Vip] ->
                    Data = [Uid, Lv, Sex, Career, Nickname,Vip],
                    {ok, BinData} = pt_14:write(14013, Data),
                    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
            	end;
	   _-> ok
    end;

%%删除黑名单
handle(14020, Status, Id, _PlayerState) ->
    case ets:lookup(?ETS_RELA, {Id,Status#player.id,2}) of
        [] -> ok;
        [R]-> 
            case R#ets_rela.pid =:= Status#player.id of
                true ->
                    lib_relationship:delete(Id,Status#player.id,2),
                    {ok, BinData} = pt_14:write(14020, 1),
                    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
                false -> ok
            end
    end,
	lib_relationship:get_back_list(Status);

%%删除仇人
handle(14021, Status, Id, _PlayerState) ->
    case ets:lookup(?ETS_RELA, {Id,Status#player.id,3}) of
        [] -> ok;
        [R] ->
            case R#ets_rela.pid =:= Status#player.id of
                true ->
                    lib_relationship:delete(Id,Status#player.id,3),
                    {ok, BinData} = pt_14:write(14021, 1),
                    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
                false -> ok
            end
    end,
	lib_relationship:get_enemy_list(Status);

%% 好友上下线通知
%% Uid 上下线角色id
%% Line 上线:1;下线:0
handle(14030, _Status, [Uid, Line, Nick], _PlayerState) ->
	lib_relationship:notice_friend_online(Uid, Line, Nick);

%% 仇人上下线通知
handle(14031, _Status, [Uid, Line, Nick], _PlayerState) ->
	lib_relationship:notice_enemy_online(Uid, Line, Nick);

%% 发送好友祝福
handle(14051, Player, [Uid, Ulv, Type], PlayerState) ->
	[BlessTimes, NewPlayerState] = lib_relationship:get_bless_time(PlayerState, Player),
	if
		BlessTimes > 29 ->
			{ok, BinData} = pt_14:write(14051, [1, BlessTimes, Uid, Ulv]),
    		lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
		true ->
			%% 处理好友祝福， 要求发送方做相关处理
			case response_bless_request(Uid, Player#player.id, Player#player.nickname, Player#player.lv, Type) of
				offline ->
					{ok, BinData} = pt_14:write(14051, [2, BlessTimes, Uid, Ulv]),
    				lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData);
				_ ->
					ok
			end
	end,
	{ok, change_player_state, NewPlayerState};

%%祝福瓶经验(登陆时推送祝福瓶经验)
handle(14054, Player, [], PlayerState) ->
	B_exp = PlayerState#player_state.bottle_exp,
	if B_exp =:= 0 ->
		   skip;
	   true ->
		   {ok, BinData14054} = pt_14:write(14054, B_exp),
		   lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData14054)
	end;

%%领取祝福瓶经验
handle(14055, Player, [], PlayerState) ->
	NewPlayerState = 
		case Player#player.lv < 38 of
			true ->
				{ok, BinData14055} = pt_14:write(14055, 0),
				lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData14055),
				PlayerState;
			false ->
				B_exp = PlayerState#player_state.bottle_exp,
				B_spr = PlayerState#player_state.bottle_spr,
				NewPlayer = lib_player:add_exp(Player, B_exp, B_spr, 5),
				{ok, BinData14055} = pt_14:write(14055, 1),
				lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData14055),
				mod_player:save_online_diff(Player, NewPlayer),
				spawn(fun()-> db_agent:set_bless_bottle(NewPlayer#player.id, [0, 0]) end),
				TimeStamp = util:unixtime(),
				spawn(fun()-> db_agent:insert_log_bottle_exp(NewPlayer#player.id,B_exp,B_spr,TimeStamp,NewPlayer#player.lv) end),
				PlayerState#player_state{bottle_exp = 0, bottle_spr = 0, player = NewPlayer}
		end,	
   {ok, change_player_state, NewPlayerState};			
	
handle(_Cmd, _Status, _Data, _PlayerState) ->
    {error, "pp_relationship no match"}.

%% 私有函数---------------------------------------------------

%%组装好友列表
pack_friend_list(R,VipList) when is_record(R, ets_rela)->
	On_off_line =  case lib_player:is_online(R#ets_rela.rid) of
						true -> 1;
						_ -> 0
					end,
%% 	[VipList] = List, 
	Vip =
	if VipList =/= [] ->
		   case lists:keyfind(R#ets_rela.rid,1,VipList) of
			   false -> 0;
			   {_Key,[VipLevel]} -> 
				   VipLevel
		   end;
	   true ->
		   0
	end,		   
	{Id,_,_}=R#ets_rela.id,
    [On_off_line, R#ets_rela.rid, 
	R#ets_rela.lv, R#ets_rela.sex,R#ets_rela.career, 
	R#ets_rela.nickname,Id, R#ets_rela.close,Vip].

%%组装仇人列表
pack_enemy_list(R,VipList) when is_record(R, ets_rela) ->
%% 	[VipList] = List, 
	On_off_line =  case lib_player:is_online(R#ets_rela.rid) of
						true -> 1;
						_ -> 0
					end,
%% 	[VipList] = List, 
	Vip =
	if VipList =/= [] ->
		   case lists:keyfind(R#ets_rela.rid,1,VipList) of
			   false -> 0;
			   {_Key,[VipLevel]} -> VipLevel
		   end;
	   true ->
		   0
	end,		
	{Id,_,_}=R#ets_rela.id,
    [On_off_line, R#ets_rela.rid, R#ets_rela.lv, R#ets_rela.sex, 
	  R#ets_rela.career, R#ets_rela.nickname, Id,Vip].

%%组装黑名单列表
pack_blacklist_list(R,VipList) when is_record(R, ets_rela) ->
%% 	[VipList] = List, 
	Vip =
	if VipList =/= [] ->
		   case lists:keyfind(R#ets_rela.rid,1,VipList) of
			   false -> 0;
			   {_Key,[VipLevel]} -> VipLevel
		   end;
	   true ->
		   0
	end,	
	{Id,_,_}=R#ets_rela.id,
    [R#ets_rela.rid, R#ets_rela.lv, R#ets_rela.sex, 
	R#ets_rela.career, R#ets_rela.nickname, Id,Vip].
		
%%回应好友请求后， 要求请求方做相关处理
response_friend_request(BinData, RequestId, ResponseId, Id, Close) ->
	case lib_player:get_player_pid(RequestId) of
		[] -> offline;
		Pid -> 
			gen_server:cast(Pid, {request_friend_ok, BinData, RequestId, ResponseId, Id, Close})
	end.
  
%%回应好友请求后， 请求方需要做的处理
response_friend_request(BinData, RequestId, ResponseId, Id, PlayerStatus, Close) ->
	L_len_rsp = lib_relationship:get_idA_list(PlayerStatus#player.id, 1),
	MyFriend_num = erlang:length(L_len_rsp),
	case MyFriend_num =/= 0 of
		true ->
			lib_achieve:check_achieve_finish(PlayerStatus#player.other#player_other.pid_send,PlayerStatus#player.id, 625, [1]);%%拥有一个好友
		false ->
			skip
	end,
	if
		MyFriend_num =:= 4 ->
			lib_achieve:check_achieve_finish(PlayerStatus#player.other#player_other.pid_send,PlayerStatus#player.id, 606, [1]);
		MyFriend_num =:= 19 ->
			lib_achieve:check_achieve_finish(PlayerStatus#player.other#player_other.pid_send,PlayerStatus#player.id, 607, [1]);
		MyFriend_num =:= 29 ->
			lib_achieve:check_achieve_finish(PlayerStatus#player.other#player_other.pid_send,PlayerStatus#player.id, 608, [1]);
		true ->
			ok
	end,	
	lib_relationship:add_ets(Id, RequestId, ResponseId, 1, Close),
    lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	%%如果被请求方与请求方有黑名单/仇人关系，则需刷新请求方的黑名单/仇人列表
	case lib_relationship:is_exists(RequestId, ResponseId, 2) of
		{RecordId1, true} ->
			lib_relationship:delete(RecordId1,RequestId,2),
			lib_relationship:get_back_list(PlayerStatus);
		{ok, false} -> ok
	end,
 	case lib_relationship:is_exists(RequestId, ResponseId, 3) of
		{RecordId2, true} ->
			lib_relationship:delete(RecordId2,RequestId,3),
			lib_relationship:get_enemy_list(PlayerStatus);
		{ok, false} -> ok
	end,
	lib_relationship:get_friend_list(PlayerStatus).

%%要求对方删除好友
response_friend_delete(Rid, Id, Rela) ->
	case lib_player:get_player_pid(Rid) of
		[] -> offline;
		Pid -> 
			gen_server:cast(Pid, {request_friend_del, Rid, Id, Rela})
	end.

%% 响应好友删除请求
response_friend_delete(_Rid, Id, PlayerStatus, Rela) ->
	lib_relationship:delete_one_ets(Id,PlayerStatus#player.id,Rela),
	lib_relationship:get_friend_list(PlayerStatus).

%% 要求对方处理好友祝福
response_bless_request(Uid, Bless_id, Nick, Lv, Type) ->
	case lib_player:get_player_pid(Uid) of
		[] -> offline;
		Pid ->
			gen_server:cast(Pid, {request_bless_process, Bless_id, Nick, Lv, Type}),
			sent
	end.

%% 处理好友祝福
response_bless_process(Bless_id, Nick, Lv, Type, PlayerState) ->
	Status = PlayerState#player_state.player,
	case lib_player:get_player_pid(Bless_id) of
		[] -> PlayerState;
		Pid ->
			Nowtime = util:unixtime(),
			Plv = Status#player.lv - (Status#player.lv - 25) rem 3,
			[Res, NewPlayerState] =
				if
					Nowtime > Status#player.other#player_other.bless_limit_time ->
						[4, PlayerState];
					Status#player.other#player_other.be_bless_time < 1 ->
						[3, PlayerState];
					true ->
						case lists:member(Bless_id, Status#player.other#player_other.bless_list) of
							true ->
								[5, PlayerState];
							false ->
								Be_bless_time = Status#player.other#player_other.be_bless_time - 1,
								Bless_list = lists:append(Status#player.other#player_other.bless_list, [Bless_id]),
								Status1 = Status#player{other = Status#player.other#player_other{be_bless_time = Be_bless_time, bless_list = Bless_list}},
								Exp_inc = data_bless_exp:get_be_bless(Plv),
								Spr_inc = Exp_inc div 3,
								Old_exp = PlayerState#player_state.bottle_exp,
								Old_spr = PlayerState#player_state.bottle_spr,			
								NewState = 
								if Status1#player.lv < 38 ->
									   NewExp = 
										   case Old_exp+Exp_inc > ?MAX_BOTTLE_EXP of
											   true -> ?MAX_BOTTLE_EXP;
											   false -> Old_exp+Exp_inc
										   end,
									   NewSpr = 
										   case Old_spr+Spr_inc > ?MAX_BOTTLE_SPR of
											   true -> ?MAX_BOTTLE_SPR;
											   false -> Old_spr+Spr_inc
										   end,
									   %%(基础数据全额)
									   spawn(fun()-> db_agent:set_bless_bottle(Status1#player.id, [NewExp, NewSpr]) end),
									   {ok, BinData14054} = pt_14:write(14054, NewExp),									  
									   lib_send:send_to_sid(Status1#player.other#player_other.pid_send, BinData14054),
									   %%(基础数据全额的一半)
									   Status2 = lib_player:add_exp(Status1, round(Exp_inc/2), round(Spr_inc/2), 5),
									   {ok, BinData} = pt_14:write(14052, [Bless_id, Nick, Lv, Plv, Type, round(Exp_inc/2)]),
									   %%基础数据全额
									   PlayerState#player_state{bottle_exp = NewExp, bottle_spr = NewSpr, player = Status2};
								   true -> 
									   Status3 = lib_player:add_exp(Status1, round(Exp_inc), round(Spr_inc), 5),
									   {ok, BinData} = pt_14:write(14052, [Bless_id, Nick, Lv, Plv, Type, round(Exp_inc)]),
									   PlayerState#player_state{player = Status3}
								end,
								lib_send:send_to_sid(Status1#player.other#player_other.pid_send, BinData),
								[0, NewState]
						end
				end,
			%% 响应好友祝福处理
			gen_server:cast(Pid, {request_bless_result, Status#player.id, Plv, Res}),
			NewPlayerState
	end.

%% 响应好友祝福处理
response_bless_result(PlayerId, PLv, Res, PlayerState) ->
	Player = PlayerState#player_state.player,
	[BlessTimes, NewPlayerState] = lib_relationship:get_bless_time(PlayerState, Player),
	Old_exp = PlayerState#player_state.bottle_exp,
	Old_spr = PlayerState#player_state.bottle_spr,
	case Res of %% 处理好友祝福， 要求发送方做相关处理
		offline ->
			{ok, BinData} = pt_14:write(14051, [2, BlessTimes, PlayerId, PLv]),
    		lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
			NewPlayerState;
		0 ->
			NewBlessTimes = BlessTimes + 1,
			Exp = data_bless_exp:get_bless(Player#player.lv),
			Spirit = Exp div 3,
			if  BlessTimes > 29 ->
					{ok, BinData} = pt_14:write(14051, [1, BlessTimes, PlayerId, PLv]),
    				lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
					NewPlayerState;
				true ->
					{ok, BinData} = pt_14:write(14051, [0, NewBlessTimes, PlayerId, PLv]),
    				lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
					case Player#player.lv < 38 of
						%%等级符合，祝福瓶功能开启
						true ->
							NewExp = 
							case Old_exp+Exp > ?MAX_BOTTLE_EXP of
								true -> ?MAX_BOTTLE_EXP;
								false -> Old_exp+Exp
							end,
							NewSpr = 
							case Old_spr+Spirit > ?MAX_BOTTLE_SPR of
								true -> ?MAX_BOTTLE_SPR;
								false -> Old_spr+Spirit
							end,
							%%直接所得部分(基础数据的一半)
							NewPlayer = lib_player:add_exp(Player, round(Exp/2), round(Spirit/2), 5),
							%%祝福瓶部分(基础数据全额)
							spawn(fun()-> db_agent:set_bless_bottle(Player#player.id, [NewExp, NewSpr, NewBlessTimes]) end),
							{ok, BinData14053} = pt_14:write(14053, Exp),
							lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData14053),
							{ok, BinData14054} = pt_14:write(14054, NewExp),
							lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData14054),
							NewPlayerState#player_state{player = NewPlayer, bottle_exp = NewExp, bottle_spr = NewSpr, bless_times = NewBlessTimes };
						%%38级以上的，没有祝福瓶
						false ->
							%%(基础数据全额)
							NewPlayer = lib_player:add_exp(Player, Exp, Spirit, 5),
						    spawn(fun()-> db_agent:set_bless_times(Player#player.id, NewBlessTimes) end),
							NewPlayerState#player_state{player = NewPlayer}
					end
			end;
		_ ->
			{ok, BinData} = pt_14:write(14051, [Res, BlessTimes, PlayerId, PLv]),
    		lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
			NewPlayerState
	end.

%%把别人加入黑名单后， 需要对方做相关处理
request_to_blacklist(MyId, OtherId) ->
	case lib_player:get_player_pid(OtherId) of
		[] -> offline;
		Pid -> gen_server:cast(Pid, {to_blacklist, OtherId, MyId})
	end.

%% -----------------------------------------------------------------
%% 处理好友列表
%% -----------------------------------------------------------------
pack_friend_list_guild(MemberRela) when is_record(MemberRela, ets_rela) ->
	On_off_line =  case lib_player:is_online(MemberRela#ets_rela.rid) of
						true -> 1;
						_ -> 0
					end,
	[MemberRela#ets_rela.nickname, MemberRela#ets_rela.lv, On_off_line].
