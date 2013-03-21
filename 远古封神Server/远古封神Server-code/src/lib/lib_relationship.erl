%%%--------------------------------------
%%% @Module  : lib_relationship
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 玩家关系相关处理
%%%--------------------------------------

-module(lib_relationship).
-compile(export_all).
-include("record.hrl").
-include("common.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-define(MID_FESTIVAL_CLOSE, 2000).%%中秋节活动，好友亲密度上限2000


%%建立关系(A加B)
%%IdA:角色A的id
%%IdB:角色B的id
%%Rela:A与B的关系
%%    0 =>没关系
%%    1 =>好友
%%    2 =>黑名单
%%    3 =>仇人
%%    4 => 最近一次解除关系的亲密度超过了3级 
add(IdA, IdB, Rela, Close) ->
	case check_rela(IdA, IdB, Rela) of
		no ->
			Nowtime = util:unixtime(),
    		case db_agent:relationship_add(IdA, IdB, Rela,Nowtime,Close,0,Nowtime) of
				{mongo, Id} ->
					insert_ets_rela(Id, IdA, IdB, Rela, Nowtime, Close,0,Nowtime);
				_ ->
    				case get_id(IdA, IdB, Rela) of
        				0 -> 0;
        				Id ->
            				insert_ets_rela(Id, IdA, IdB, Rela, Nowtime, Close,0,Nowtime)
					end
			end;
		Id -> 
			add_ets(Id, IdA, IdB, Rela,Close)
	end.

%%增添关系为4
add_rela_special(IdA,IdB,Rela,Close) ->
	Nowtime = util:unixtime(),
	case db_agent:relationship_add(IdA, IdB, Rela,Nowtime,Close,0,Nowtime) of
		{mongo, Id} ->
			insert_ets_rela(Id, IdA, IdB, Rela, Nowtime, Close, 0, Nowtime);
		_ ->
			case get_id(IdA, IdB, Rela) of
				0 -> 0;
				Id ->
					insert_ets_rela(Id, IdA, IdB, Rela, Nowtime, Close,0,Nowtime)
			end
	end.
	
add_ets(IdA, IdB, Rela,Close) ->
	Id = db_agent:relationship_get_id(IdA, IdB, Rela),
	Nowtime = util:unixtime(),
	insert_ets_rela(Id, IdA, IdB, Rela,Nowtime,Close,0,0).

add_ets(Id, IdA, IdB, Rela,Close) ->
	Nowtime = util:unixtime(),
	insert_ets_rela(Id, IdA, IdB, Rela, Nowtime,Close,0,0).

%%删除某个记录
delete(PlayerId) ->
    ets:match_delete(?ETS_RELA, #ets_rela{id = PlayerId, _ = '_'}),
	spawn(fun()-> db_agent:relationship_delete(PlayerId) end).
delete(Id,PId,Rela) ->
    ets:match_delete(?ETS_RELA, #ets_rela{id = {Id,PId,Rela}, _ = '_'}),
	spawn(fun()-> db_agent:relationship_delete(Id) end),
	%%删除好友亲密度日志记录
	case Rela of
		1 ->
			spawn(fun()-> db_agent:delete_log_close(Id)end);
		_->
			skip
	end.

%%删除某个记录（只清除ets）
delete_one_ets(Id,Pid,Rela) ->
    ets:match_delete(?ETS_RELA, #ets_rela{id = {Id,Pid,Rela}, _ = '_'}).

%%下线清除ets_rela表中的相关数据
delete_ets(Uid) ->
	%%下线保存亲密度
	insert_to_db(Uid),
    ets:match_delete(?ETS_RELA, #ets_rela{pid = Uid, _ = '_'}),
	ok.

%%当玩家删除角色时，删除有关于这角色的数据
delete_role(Uid) -> 
    db_agent:relationship_delete_role1(Uid),
	true.

%%查找与角色A有关系的角色信息
find(IdA) ->
    La = db_agent:relationship_find(IdA),
	Lb = db_agent:relationship_find(IdA, 1),
	%%最近一次删除亲密度超过3级的好友(包括删除好友、添加仇人、添加黑名单、击杀好友4种操作)
	Lc = db_agent:relationship_find(IdA, 4),
	Ld = lists:append(La, Lb),
	lists:append(Ld, Lc).

%%取某条记录id
get_id(IdA, IdB, Rela) ->
    case db_agent:relationship_get_id(IdA, IdB, Rela) of
        [] -> 0;
        [H] -> H
    end.


%%往ets_rela表插入记录
insert_ets_rela(Id, IdA, IdB, Rela, Time_form, Close, PkMon, MonTime) ->
	case db_agent:relationship_get_player_info(IdB) of
		[_Pid, Nick, Sex, Lv, Career]  ->
			New_rela = #ets_rela{
		            id = {Id,IdA,Rela}, 
		            pid = IdA, 
		            rid = IdB, 
		            rela = Rela, 
		            time_form = Time_form,
					nickname = Nick,      					%% 对方角色名字
		    		sex = Sex,            					%% 对方角色性别
		    		lv = Lv,             					%% 对方角色等级
		    		career = Career,          				%% 对方角色职业
					close=Close,%%总亲密度
					pk_mon=PkMon,%%每日打怪亲密度上限
					timestamp = MonTime 
		        }, 
		    ets:insert(?ETS_RELA, New_rela),
			%%io:format("lib_relationship 104 line Close=~p~n",[Close]),
			New_rela;
		_ ->skip
	end.

%设置某玩家在ets_rela中的所有记录
set_ets_rela_record(Uid) ->
    case ets:match_object(?ETS_RELA, #ets_rela{pid = Uid, _ = '_'}) of
        [] -> 
            %%如果为空，则从数据库中读取全部关系
            List_r = lib_relationship:find(Uid),                %% 从数据库中读取
			L0 = lists:map(fun(Rela_item)-> [Id, IdB, Rela, Time_form,Close,PkMon,Timestamp] = Rela_item, 
										  case db_agent:relationship_get_player_info(IdB) of 
											  [_Pid, Nick, Sex, Lv, Career] ->
										  			[Id, Uid, IdB, Rela, Time_form, Nick, Sex, Lv, Career,Close,PkMon,Timestamp];
											  
											  _ ->[]
										  end
						  end, List_r),
			
			L = lists:filter(fun(_e) -> _e /= [] end, L0),
			lists:foldl(fun(R, Acc) ->
							Rela = list_to_tuple([ets_rela] ++ R),
						    T = [Rela#ets_rela.pid, Rela#ets_rela.rid, Rela#ets_rela.rela],
							%%初始化每天打怪亲密度上限
							NowTime = util:unixtime(),
							NewRela = case util:is_same_date(NowTime,Rela#ets_rela.timestamp) of
										  true->
											  Rela#ets_rela{id={Rela#ets_rela.id,Rela#ets_rela.pid,Rela#ets_rela.rela}};
										  false->
											  db_agent:update_pk_mon_close_limit(Rela#ets_rela.pid, Rela#ets_rela.rid,NowTime),
											  Rela#ets_rela{id={Rela#ets_rela.id,Rela#ets_rela.pid,Rela#ets_rela.rela},pk_mon=0,timestamp=NowTime}
									  end,
							case lists:any(fun(M)-> M==T end, Acc) of
								true ->
									Acc;
								_ ->
									ets:insert(?ETS_RELA, NewRela),
									Acc ++ [T]				
							end	
						end,
						[], L),
            ok;
        _L -> ok
    end.

%%读取ets_rela中是否有某玩家的好友/黑名单/仇人记录(包含VIP信息)
get_ets_rela_record(Uid, Rela) ->
    case ets:match_object(?ETS_RELA, #ets_rela{pid = Uid, rela = Rela, _ = '_'}) of
        [] -> [{[],[]}];
        L -> RidList = [R#ets_rela.rid || R <- L],
			 F = fun(Rid) -> db_agent:get_player_mult_properties([vip],[Rid]) end,
			 VipList = [F(Rid) || Rid <- RidList],
			 VipList2 = [Data || [Data] <- VipList], 
			 [{L,VipList2}]
    end.

%%读取ets_rela中是否有某玩家的好友/黑名单/仇人记录(无VIP信息)
find_ets_rela_record(Uid,Rela) ->
	 case ets:match_object(?ETS_RELA, #ets_rela{pid = Uid, rela = Rela, _ = '_'}) of
		 [] ->[];
		 L -> L
	 end.

%%取ets_rela{pid = Uid, rela = Rela}的记录，返回idA的列表
get_idA_list(Uid, Rela) ->
    case ets:match(?ETS_RELA, #ets_rela{pid = Uid, rid = '$1', rela = Rela, _ = '_'}) of
        [] -> [];
        L -> lists:usort(L) 
    end.

%%取ets_rela{rid = Uid, rela = Rela}的记录，返回idA的列表
get_idB_list(Uid, Rela) ->
    case ets:match(?ETS_RELA, #ets_rela{rid = Uid, pid = '$1', rela = Rela, _ = '_'}) of
        [] -> [];
        L -> lists:usort(L) 
    end.

%%取ets_rela{id = Id, pid = Pid, rela = Rela}的记录，返回idA的列表
get_idB(Id, Pid, Rela) ->
    case ets:match(?ETS_RELA, #ets_rela{id = {Id,Pid,Rela}, pid = Pid, rid = '$1', rela = Rela, _ = '_'}) of
        [] -> [];
        L -> 
			%%io:format("L~p~n",[L]),
			lists:usort(L) 
    end.

%%检查A与B是否存在Rela关系
is_exists(IdA, IdB, Rela) ->
    case ets:match(?ETS_RELA, #ets_rela{id = '$1', pid = IdA, rid = IdB, rela = Rela, _ = '_'}) of
        [] ->
			case Rela of
				1 -> 
					case is_exists_remote(IdB, IdA, Rela) of
						{_, false} -> {ok, false};
						Id -> {Id, true}
					end;
				_ -> {ok, false}
			 end;
        [[{Id,_,_}]|_T] -> {Id, true}
    end.

%%检查A是否有Rid的关系记录
is_exists_Rid(RecId, IdA, Rela) ->
    case ets:match_object(?ETS_RELA, #ets_rela{id = {RecId,IdA,Rela}, _ = '_'}) of
        [] -> {ok, false};
        [_T] -> {RecId, true};
		_ -> {ok, false}
    end.

%%IdA是否加了IdB为Rela关系(用于外部模块)
%%Rela: 1:好友;2:黑名单;3:仇人
export_is_exists(IdA, IdB, Rela) ->
   %%保证有数据 
%%     set_ets_rela_record(IdA),
    case ets:match(?ETS_RELA, #ets_rela{id = '$1', pid = IdA, rid = IdB, rela = Rela, _ = '_'}) of
        [] ->{ok, false};
        [[{Id,_,_}]|_T] -> {Id, true}
    end.

find_is_exists(IdA, IdB, Rela) ->
	Ms = ets:fun2ms(fun(R) when R#ets_rela.pid == IdA andalso R#ets_rela.rid == IdB andalso R#ets_rela.rela == Rela -> R#ets_rela.id end),
	Ms1 = ets:fun2ms(fun(R) when R#ets_rela.pid == IdB andalso R#ets_rela.rid == IdA andalso R#ets_rela.rela == Rela -> R#ets_rela.id end),
    case ets:select(?ETS_RELA,Ms) of
        [] ->
			case ets:select(?ETS_RELA,Ms1) of
				[] -> {ok, false};
				[Id|_] -> {Id,true}
			end;
        [Id|_] ->
			{Id, true}
    end.

find_friend_record(IdA, IdB, Rela) ->
	Ms = ets:fun2ms(fun(R) when R#ets_rela.pid == IdA andalso R#ets_rela.rid == IdB andalso R#ets_rela.rela == Rela -> R end),
	Ms1 = ets:fun2ms(fun(R) when R#ets_rela.pid == IdB andalso R#ets_rela.rid == IdA andalso R#ets_rela.rela == Rela -> R end),
    case ets:select(?ETS_RELA,Ms) orelse ets:select(?ETS_RELA,Ms1) of
        [] ->
			{ok, false};
        [R|_] ->
			R
    end.

%%到对方进程，检查A与B是否存在Rela关系
is_exists_remote(IdA, IdB, Rela) ->
	case lib_player:get_player_pid(IdA) of
		[] -> {offline, false};
		Pid ->
             case catch gen:call(Pid, '$gen_call', {is_exists, IdA, IdB, Rela}, 2000) of
              		{ok, Ret} ->
						Ret;
                	_ ->
                   		{offline, false}					
             end
	end.

%%到对方进程，检查对方好友个数
friend_num_remote(Remote_id) ->
	case lib_player:get_player_pid(Remote_id) of
		[] -> 
			[NumA, NumB] = db_agent:relationship_get_fri_count(Remote_id),
			Na = 
				case NumA of
					[] -> 0;
					[N] -> N
				end,
			Nb = 
				case NumB of
					[] -> 0;
					[N1] -> N1
				end,
			Na + Nb >= 50;
		Pid ->
             case catch gen:call(Pid, '$gen_call', {count_fri}, 2000) of
              		{ok, Ret} ->
						Ret;
                	_ ->
                   		true					
             end
	end.

%% 到数据库查询相应关系并返回相应Id
check_rela(IdA, IdB, Rela) ->
	case db_agent:relationship_get_id(IdA, IdB, Rela) of
		[] ->
			case Rela of
				1 -> 
					case db_agent:relationship_get_id(IdB, IdA, Rela) of
						[] -> no;
						 _ -> ok
					end;
				_ -> no
			end;
		Id -> Id
	end.

%% 获取好友祝福相关信息
get_bless_info(PlayerId) ->
	Now = util:unixtime(),
	case db_agent:get_bless_info(PlayerId) of
		[] ->
			spawn(fun()-> db_agent:insert_bless_info(PlayerId, Now) end),
			[0, 0, 0, Now];
		[BlessTimes, B_exp, B_spr, LastBlessTime] ->
			case util:is_same_date(Now,LastBlessTime) of
				 false ->
					 %%额外增加的10次发起次数清零
					 spawn(fun()-> db_agent:set_bless_info(PlayerId, 0, Now) end),
					 [BlessTimes, B_exp, B_spr, 0];
				 true ->
					[BlessTimes, B_exp, B_spr, LastBlessTime]
			end
	end.

%% 发送好友祝福通知
send_bless_notes(Player) ->
	%% 设置好友祝福过期时间
	Time_limit = util:unixtime() + 120,  
	NewPlayer = Player#player{
		other = Player#player.other#player_other{
			be_bless_time = 20, 
			bless_limit_time = Time_limit, 
			bless_list = []
		}
	},
	L = get_idA_25_online_list(NewPlayer#player.id, 1), %% add by zkj
	if
		%% 在线好友大于5人 
		length(L) >= 5 ->
			skip;
		%% 在线好友少于5人，向同屏的好友发送请求
		true -> 
			%% 获得同屏好友的列表，并向对方发送祝福
			mod_scene_agent:get_player_in_screen_bless(NewPlayer, L)
	end,
	%% 发送给好友
	send_bless_notes_nod(NewPlayer#player.id, NewPlayer#player.nickname, NewPlayer#player.lv, L, []),
	NewPlayer.

%%发送祝福
%%L为要发送的列表，L_friends为好友列表
%% add by zkj
send_bless_notes_nod(FriendId, FriendName, FriendLv, L, L_friends) ->
	F = fun(Litem)->
		case Litem of
			[] -> 
				ok;
			Id ->
				case lib_player:get_player_pid(Id) of
					[] ->
						ok;
					Pid ->
						gen_server:cast(Pid, {'GET_BLESS_TIMES', FriendId, FriendName, FriendLv})
				end
		end
  	end,
	if
		L_friends =:= [] ->
			%%仅发送好友
			L1 = L; 
		true ->
			%%发送给同屏玩家
			 L1 = lists:foldl(fun(N,Left)-> lists:delete(N,Left) end,L,L_friends) %%删除同屏玩家的好友		
	end,
    [F(L_item) || L_item <- L1].
	
	
%%取ets_rela{pid = Uid, rela = Rela, lv >24}的记录，返回idA的列表
%%add by zkj
get_idA_25_online_list(Uid, Rela) ->
	MS = ets:fun2ms(fun(T) when T#ets_rela.pid == Uid andalso T#ets_rela.rela==Rela andalso T#ets_rela.lv > 24 ->
						T
						end),
	Friends_list = ets:select(?ETS_RELA, MS),
	
	if
		length(Friends_list) =:=0 ->
			[];
		true ->
			get_idA_25_online_list_loop(Friends_list,[])
	end.

%% add by zkj
get_idA_25_online_list_loop(L, Old_L) ->
	if 
		length(L) > 0 ->
			L_I=lists:nth(1, L),
			case (lib_player:is_online(L_I#ets_rela.rid)) of
				true ->
					New_L=Old_L++tuple_to_list({L_I#ets_rela.rid}),
					get_idA_25_online_list_loop(lists:sublist(L,2,length(L)-1), New_L);
				_ ->
					get_idA_25_online_list_loop(lists:sublist(L,2,length(L)-1), Old_L)
			end;
		true ->
			%%lists:delete({}, Old_L)
			Old_L
	end.

%% 获取角色好友祝福次数信息
get_bless_time(PlayerState, Player) ->
	Now = util:unixtime(),
	if 
		(Now + 8 * 3600) div 86400 > (PlayerState#player_state.last_bless_time + 8 * 3600) div 86400 ->
			spawn(fun()-> db_agent:set_bless_info(Player#player.id, 0, Now) end),
			NewPlayerState = PlayerState#player_state{
				bless_times = 0, 
				last_bless_time = Now			   
			},
			[0, NewPlayerState];
		true ->
			[PlayerState#player_state.bless_times, PlayerState]
	end.

%% 请求好友列表
get_friend_list(Player) ->
	[{L,VipList}] = get_ets_rela_record(Player#player.id, 1),
    L1 = [pp_relationship:pack_friend_list(X,VipList) || X <- L],
	L2 = lists:filter(fun(_e) -> _e /= [] end, L1),
    {ok, BinData} = pt_14:write(14000, [L2]),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData).

%% 请求好友列表
pp_get_friend_list(Player) ->
	[{L,VipList}] = get_ets_rela_record(Player#player.id, 1),
    L1 = [pp_relationship:pack_friend_list(X,VipList) || X <- L],
	L2 = lists:filter(fun(_e) -> _e /= [] end, L1),
	case length(L2) > 0 of
		true ->
			lib_achieve:check_achieve_finish(Player#player.other#player_other.pid_send,
											 Player#player.id, 625, [1]);%%拥有一个好友
		false ->
			skip
	end,
    {ok, BinData} = pt_14:write(14000, [L2]),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData).

%% 请求黑名单列表
get_back_list(Player) ->
	[{L,VipList}] = get_ets_rela_record(Player#player.id, 2),
    L2 = [pp_relationship:pack_blacklist_list(X,VipList)|| X <- L],
    {ok, BinData} = pt_14:write(14007,L2),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData).

%% 请求仇人列表
get_enemy_list(Player) ->
	[{L,VipList}]  = get_ets_rela_record(Player#player.id, 3),
    L2 = [pp_relationship:pack_enemy_list(X,VipList)||X <- L],
    {ok, BinData} = pt_14:write(14008, L2),
    lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData).


%% 好友上下线通知
%% Uid 上下线角色id
%% Line 上线:1;下线:0
notice_friend_online(Uid, Line, Nick) ->
	L = get_idA_list(Uid, 1),
    {ok, BinData} = pt_14:write(14030, [Uid, Line, Nick]),
    F = fun(Id)->  
   		lib_send:send_to_uid(Id, BinData)
    end,
    [F(IdA) || [IdA] <- L].

%% 仇人上下线通知
notice_enemy_online(Uid, Line, Nick) ->
	L = get_idB_list(Uid, 3),
    {ok, BinData} = pt_14:write(14031, [Uid, Line, Nick]),
    F = fun(Id)->
  		lib_send:send_to_uid(Id, BinData)
    end,
    [F(IdA) || [IdA] <- L].

%%%%%%%%%%%%%%%增加亲密度%%%%%%%%%%%%%%%%%%%%%
%%member = [#mb{id = Uid, pid = Pid, nickname = Nick}],
team_close(TeamMmember,MonType,MonScene)->
	member_loop(TeamMmember,MonType,MonScene).

%% 添加仇人
add_enemy(Player, EnemyId, Close) ->
	case is_exists(Player#player.id, EnemyId, 2) of
		{_, true} -> ok;
		{ok, false} ->
    		case is_exists(Player#player.id, EnemyId, 3) of
        		{_, true} -> ok;
        		{ok, false} ->
           			case add(Player#player.id, EnemyId, 3, 0) of
						0 ->
                   			{ok, BinData} = pt_14:write(14005, [0,0]),
                    		lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
							ok;
						_ ->
                    		% 删除好友关系
							case is_exists(Player#player.id, EnemyId, 1) of
    							{RecordId1, true} ->				
									%%要求对方删除好友
									pp_relationship:response_friend_delete(EnemyId, RecordId1,1),
        							delete(RecordId1,Player#player.id,1),
									%%删除中秋活动的日志记录
									lib_relationship:delete_midaward_data(Player#player.id,EnemyId),
									get_friend_list(Player);
    							{ok, false} -> ok
							end,
							%%保存为关系4
							CloseLevel = lib_relationship:get_close_level(Close),
							if CloseLevel >=3 ->
								  case lib_relationship:add_rela_special(Player#player.id,EnemyId,4,Close) of
									  0 -> skip;
									  NewRela ->%%对方内存ets也要改变
										  case lib_player:get_player_pid(EnemyId) of
											  [] -> skip;
											  Pid -> gen_server:cast(Pid, {add_special, NewRela})
										  end
								  end;	
							   true ->
								   skip
							end,
							
                    		{ok, BinData} = pt_14:write(14005, [1, EnemyId]),
                    		lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
							get_enemy_list(Player)
            		end
    		end
	end.
member_loop([],_MonType,_MonScene)->ok;
member_loop(TeamMmember,MonType,MonScene)->
	Mb = lists:nth(1, TeamMmember),
	Member = lists:delete(Mb, TeamMmember),
	get_member(Member,Mb,MonType,MonScene),
	member_loop(Member,MonType,MonScene).

get_member([],_Mb,_MonType,_MonScene)->
	ok;
get_member([M|Member],Mb,MonType,MonScene)->
	case misc:is_process_alive(M#mb.pid) andalso misc:is_process_alive(Mb#mb.pid) of
		true->
			gen_server:cast(Mb#mb.pid,{'close',pk_mon,Mb#mb.id,M#mb.id,[MonType,MonScene]}),
			gen_server:cast(M#mb.pid,{'close_etsonly',pk_mon,Mb#mb.id,M#mb.id,[MonType,MonScene]});
		false->skip
	end,
	get_member(Member,Mb,MonType,MonScene).
	
%% 发送好友请求
%% Type 加好友的类型(1:常规加好友,2:黑名单里加好友,3:仇人里加好友)
%% Uid 用户ID
%% Nick 角色名
send_friend_request(Status, Type, Uid, Nick) ->	
	%% 检查回应方是否在线和是否已经是好友关系
    Val = 
		case Uid of 
            0 -> 
              	case Nick =:= Status#player.nickname of
    	            true -> 	%% 不能加自己为好友
						 error;					
                	false ->
					 	case lib_player:get_role_id_by_name(Nick) of
							null -> error;
						 	IdB -> 
							 	case lib_player:is_online(IdB) of
									 false -> {offline, 0};
									 true -> %%检查是否已经存在好友关系
        	                    		case is_exists(Status#player.id, IdB, 1) of
            	                    		{_, true} -> error;
                	                		{ok, false} -> {online, IdB}
                    	        		end							
								 end
						 end
              	end;
            IdB -> 
                case IdB =:= Status#player.id of
    	            true -> 	%% 不能加自己为好友
						 error;					
                    false ->
                        %%检查是否在线
                        case lib_player:is_online(IdB) of
                            false -> {offline, 0};
                            true -> %%检查是否已经存在好友关系
                                 case is_exists(Status#player.id, IdB, 1) of
                                     {_, true} -> 
										 %%io:format("lib_relationship 504 line have exits~n"),
										 error;
                                     {ok, false} -> 
										 lib_task:event(friend,null,Status),
										 {online, IdB}
                                 end
                         end
                end
        end,
    case Val of
        %%回应方在线
        {online, Id} ->
            %%保证有数据
            case is_exists_remote(Id, Status#player.id, 2) of	%%自己是否在对方的黑名单中
				{offline, _} ->
            				{ok, BinData} = pt_14:write(14002, [2,2]),
            				lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);					
                {ok, false} ->
                    case is_exists_remote(Id, Status#player.id, 1) of
						{offline, _} ->
            				{ok, BinData} = pt_14:write(14002, [2,2]),
            				lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);							
                        {ok, false} ->
                            %%回应方没有加发送方为好友
                            Data1 = [Type, Status#player.id, Status#player.lv, Status#player.sex, 
									 Status#player.career, Status#player.nickname],
                            {ok, BinData} = pt_14:write(14001, Data1),
                            lib_send:send_to_uid(Id, BinData),
                            lib_chat:send_sys_msg_one(Status#player.other#player_other.socket, "加好友请求已发出，等待对方回应");
                        {_Rid, true} ->
                            %%回应方已经加了发送方为好友 
							Rela_ets = lib_relationship:add(Status#player.id, Id, 1),
							Data1 = [2, 1, Rela_ets#ets_rela.rid, Rela_ets#ets_rela.lv, Rela_ets#ets_rela.sex, 
										Rela_ets#ets_rela.career, Rela_ets#ets_rela.nickname],
                            {ok, BinData} = pt_14:write(14002, Data1),
                            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
                    end;
                {_, true} ->
                    {ok, BinData} = pt_14:write(14002, [2, 3]),
                    lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
            end;
        %%回应方不在线
        {offline, _} ->
            {ok, BinData} = pt_14:write(14002, [2, 2]),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
        %%加自己为好友
        error -> ok
    end.

%% 亲密度写数据库
insert_to_db(PlayerId) ->
   [{L,_VipList}] = get_ets_rela_record(PlayerId, 1),
   F = fun(R) -> 
			   {DbId,_pid,1} = R#ets_rela.id,
			   spawn(fun()->db_agent:update_close(DbId,R#ets_rela.close,R#ets_rela.pk_mon,R#ets_rela.timestamp) end),
			   if R#ets_rela.close > 1000 ->
					  spawn(fun()->db_agent:log_close_add(DbId,R#ets_rela.pid,R#ets_rela.rid,R#ets_rela.close,util:unixtime())end);
				  true ->
					  skip
			   end
	   end,
   [F(R) || R <- L].

%%亲密度增加
close(Type,IdA,IdB,Value)->
	case find_is_exists(IdA,IdB,1) of
		{ok,false}->
			skip;
		{Id,true}->
			case ets:lookup(?ETS_RELA,Id) of
				[] ->
					skip;
				[R] ->
					add_close(Type,IdA,IdB,R,Value)
			end
	end.

%%独立的函数，返回最新的close_rela元素
%%1、与好友一起组队，在副本、镇妖台、封神台、诛仙台、试炼副本、挂机园战斗胜利后可增加双方亲密度，小怪增加 1 点，BOSS则增加 2 点。（每日上限400点）
add_mon_close(pk_mon,IdA,IdB,Rela,[MonType, Pid_team]) ->
    NowTime = util:unixtime(),
	{Param,DayMax} = get_active_param_mon(NowTime),
    [PkMon,Timestamp,Close] = case util:is_same_date(NowTime,Rela#ets_rela.timestamp) of
                                  true->
                                      if Rela#ets_rela.pk_mon >= DayMax->
                                             [Rela#ets_rela.pk_mon,Rela#ets_rela.timestamp,0];
                                         true->
                                             MonClose1=get_close_add(mon,MonType),
											 MonClose = MonClose1 * Param, 
                                             [Rela#ets_rela.pk_mon+MonClose,Rela#ets_rela.timestamp,MonClose]
                                      end;
                                  false->
                                      MonClose1=get_close_add(mon,MonType),
									  MonClose = MonClose1 * Param, 
                                      [MonClose,NowTime,MonClose]
                              end,
    case Close > 0 of
        true->
            NewRela = Rela#ets_rela{pk_mon = PkMon, timestamp = Timestamp, close = Rela#ets_rela.close+Close},
            {DbId,_Id1,1} = Rela#ets_rela.id,
            case lib_player:get_player_pid(IdA) of
                [] -> {{IdA,IdB},Rela};
                Apid -> case lib_player:get_player_pid(IdB) of
                            [] -> {{IdA,IdB},Rela};
                            Bpid-> 
                                Apid ! ({'SET_CLOSE', [{DbId,IdA,1}, NewRela#ets_rela.pk_mon, NewRela#ets_rela.timestamp, NewRela#ets_rela.close]}),
                                Bpid ! ({'SET_CLOSE', [{DbId,IdB,1}, NewRela#ets_rela.pk_mon, NewRela#ets_rela.timestamp, NewRela#ets_rela.close]}),
                                gen_server:cast(Pid_team, {'ADD_TEAM_CLOSE',IdA,IdB,NewRela}),
                                {{IdA,IdB},NewRela}
                        end
            end;
        false->{{IdA,IdB},Rela}
    end.

%%2、赠送好友鲜花，每只鲜花可增加双方亲密度 1 点。（无每日上限）
add_close(flower,IdA,IdB,Rela,[Flowers,Pid_team,Rid_team])->
	Close1 = get_close_add(flower,Flowers),
	Close = Close1*get_active_param(),
	NewRela = Rela#ets_rela{close=Rela#ets_rela.close+Close},
	{DbId, _Id1, 1} = NewRela#ets_rela.id,
	case lib_player:get_player_pid(IdA) of
		[] -> skip;
		Apid -> case lib_player:get_player_pid(IdB) of
					[] -> skip;
					Bpid-> 
						Apid ! ({'SET_CLOSE', [{DbId,IdA,1}, NewRela#ets_rela.pk_mon, NewRela#ets_rela.timestamp, NewRela#ets_rela.close]}),
						Bpid ! ({'SET_CLOSE', [{DbId,IdB,1}, NewRela#ets_rela.pk_mon, NewRela#ets_rela.timestamp, NewRela#ets_rela.close]}),
 						if Pid_team =:= undefined orelse Rid_team =:= undefined orelse Pid_team =/= Rid_team ->
 							   skip;
 						   true ->
 						    gen_server:cast(Pid_team, {'ADD_TEAM_CLOSE',IdA,IdB,NewRela})
 						end,
						%%送花，即时写亲密度日志
						spawn(fun()->db_agent:log_close_add(DbId,IdA,IdB,NewRela#ets_rela.close,util:unixtime())end)
				end
	end;
				
%%3、仙侣情缘任务，每次可增加双方亲密度 30*默契度/100 点。（无每日上限）
add_close(love,IdA,IdB,Rela,[Close1,Pid_team,Rid_team])->
	Close = Close1*get_active_param(),
	NewRela = Rela#ets_rela{close=Rela#ets_rela.close+Close},
	{DbId, _Id1, 1} = NewRela#ets_rela.id,
	case lib_player:get_player_pid(IdA) of
		[] ->
			skip;
		Apid -> case lib_player:get_player_pid(IdB) of
					[] ->
						skip;
					Bpid->
						Apid ! ({'SET_CLOSE', [{DbId,IdA,1}, NewRela#ets_rela.pk_mon, NewRela#ets_rela.timestamp, NewRela#ets_rela.close]}),
						Bpid ! ({'SET_CLOSE', [{DbId,IdB,1}, NewRela#ets_rela.pk_mon, NewRela#ets_rela.timestamp, NewRela#ets_rela.close]}),
 						if Pid_team =:= undefined orelse Rid_team =:= undefined orelse Pid_team =/= Rid_team ->
 							   skip;
 						   true ->
 						    gen_server:cast(Pid_team, {'ADD_TEAM_CLOSE',IdA,IdB,NewRela})
 						end
%% 						spawn(fun()->db_agent:update_close(DbId,NewRela#ets_rela.close,NewRela#ets_rela.pk_mon,NewRela#ets_rela.timestamp)end)
				end
	end;

%%4、好友祝福，每次可增加双方亲密度 5 点。（无每日上限）
add_close(bless,IdA,IdB,Rela,[_Close,Pid_team,Rid_team])->
	Close1 = get_close_add(bless,5),
	Close = Close1*get_active_param(),
	NewRela = Rela#ets_rela{close=Rela#ets_rela.close+Close},
	{DbId, _Id1, 1} = NewRela#ets_rela.id,
	case lib_player:get_player_pid(IdA) of
		[] -> skip;
		Apid -> case lib_player:get_player_pid(IdB) of
					[] -> skip;
					Bpid->
						Apid ! ({'SET_CLOSE', [{DbId,IdA,1}, NewRela#ets_rela.pk_mon, NewRela#ets_rela.timestamp, NewRela#ets_rela.close]}),
						Bpid ! ({'SET_CLOSE', [{DbId,IdB,1}, NewRela#ets_rela.pk_mon, NewRela#ets_rela.timestamp, NewRela#ets_rela.close]}),
 						if Pid_team =:= undefined orelse Rid_team =:= undefined orelse Pid_team =/= Rid_team ->
 							   skip;
 						   true ->
 						    gen_server:cast(Pid_team, {'ADD_TEAM_CLOSE',IdA,IdB,NewRela})
 						end
%% 						spawn(fun()->db_agent:update_close(DbId,NewRela#ets_rela.close,NewRela#ets_rela.pk_mon,NewRela#ets_rela.timestamp)end)
				end
	end;


%%4、双修
add_close(double_rest,IdA,IdB,Rela,[_,Pid_team,Rid_team])->
	Close1 = lib_double_rest:get_double_love_value(),
	Close = Close1*get_active_param(),
	NewRela = Rela#ets_rela{close=Rela#ets_rela.close+Close},
	{DbId, _Id1, 1} = NewRela#ets_rela.id,
	case lib_player:get_player_pid(IdA) of
		[] -> skip;
		Apid -> case lib_player:get_player_pid(IdB) of
					[] -> skip;
					Bpid->
						Apid ! ({'SET_CLOSE', [{DbId,IdA,1}, NewRela#ets_rela.pk_mon, NewRela#ets_rela.timestamp, NewRela#ets_rela.close]}),
						Bpid ! ({'SET_CLOSE', [{DbId,IdB,1}, NewRela#ets_rela.pk_mon, NewRela#ets_rela.timestamp, NewRela#ets_rela.close]}),
 						if Pid_team =:= undefined orelse Rid_team =:= undefined orelse Pid_team =/= Rid_team ->
 							   skip;
 						   true ->
 						    gen_server:cast(Pid_team, {'ADD_TEAM_CLOSE',IdA,IdB,NewRela})
 						end
				end
	end;

%%5、偷取好友的庄园果实，每个果实可增加双方亲密度 1 。（无每日上限）
add_close(manor,IdA,IdB,Rela,[Fruits,Pid_team,Rid_team])->
	Close1 = get_close_add(manor,Fruits),
	Close = Close1*get_active_param(),
	NewRela = Rela#ets_rela{close=Rela#ets_rela.close+Close},
	{DbId, _Id1, 1} = NewRela#ets_rela.id,
	case lib_player:get_player_pid(IdA) of
		[] -> skip;
		Apid -> case lib_player:get_player_pid(IdB) of
					[] ->
						%%对方不在线也增加亲密度
						Apid ! ({'SET_CLOSE', [{DbId,IdA,1}, NewRela#ets_rela.pk_mon, NewRela#ets_rela.timestamp, NewRela#ets_rela.close]});
					Bpid-> 
						Apid ! ({'SET_CLOSE', [{DbId,IdA,1}, NewRela#ets_rela.pk_mon, NewRela#ets_rela.timestamp, NewRela#ets_rela.close]}),
						Bpid ! ({'SET_CLOSE', [{DbId,IdB,1}, NewRela#ets_rela.pk_mon, NewRela#ets_rela.timestamp, NewRela#ets_rela.close]}),
 						if Pid_team =:= undefined orelse Rid_team =:= undefined orelse Pid_team =/= Rid_team ->
 							   skip;
 						   true ->
 						    gen_server:cast(Pid_team, {'ADD_TEAM_CLOSE',IdA,IdB,NewRela})
 						end
%% 						spawn(fun()->db_agent:update_close(DbId,NewRela#ets_rela.close,NewRela#ets_rela.pk_mon,NewRela#ets_rela.timestamp)end)
				end
	end;

add_close(_,_,_,_,_)->
	skip.

%%亲密度等级公式
get_close_level(ClosePoint) ->
	if  
		ClosePoint =< 0 ->
			0;
		ClosePoint =< 999 -> 
			1;
		ClosePoint =< 3999 ->
			2;
		ClosePoint =< 8999 ->
			3;
		ClosePoint =< 15999 ->
			4;
		ClosePoint =< 24999 ->
			5;
		ClosePoint =< 39999 ->
			6;
		ClosePoint =< 64999 ->
			7;
		ClosePoint =< 99999 ->
			8;
		ClosePoint >= 100000 ->
			9;
		true ->
			0
	end.

%%亲密度加成系数
get_close_res(CloseLevel) ->
	if
		CloseLevel =:= 1 ->
			{1,0,0,0,0};     %%经验加成，法力上限，气血上限，全抗+，攻击上限
		CloseLevel =:= 2 ->
			{1.05,0,0,0,0};
		CloseLevel =:= 3 ->
			{1.05,200,0,0,0};
		CloseLevel =:= 4 ->
			{1.1,200,0,0,0};
		CloseLevel =:= 5 ->
			{1.1,200,300,0,0};
		CloseLevel =:= 6 ->
			{1.15,200,300,0,0};
		CloseLevel =:= 7 ->
			{1.15,200,300,150,0};
		CloseLevel =:= 8 ->
			{1.2,200,300,150,0};
		CloseLevel =:= 9 ->
			{1.2,200,300,150,100};
		true ->
			{1,0,0,0,0}
	end.

%%1普通怪、2精英怪、3野外BOSS、4副本怪、5副本BOSS、6采集怪、7捕捉怪、9诛邪怪,10塔怪(物攻)、11~15塔怪(属攻)，20塔怪boss(物攻)、21~25塔怪boss(属攻),30,31神岛怪,98TD小怪,99TD(boss),100TD守卫,101TD镇妖剑
get_close_add(mon,MonType)->
	case MonType of
		1->1;
		4->1;
		5->2;
		10->1;
		11->1;
		12->1;
		13->1;
		14->1;
		15->1;
		20->2;
		21->1;
		22->1;
		23->1;
		24->1;
		25->1;
		98->1;
		99->2;
		_->0
	end;
get_close_add(flower,Flower)->Flower;
get_close_add(love,_)->20;
get_close_add(bless,_)->5;
get_close_add(manor,Fruits)->Fruits;
get_close_add(_,_)->
	0.

%%仙侣情缘，检查亲密度
check_close(IdA,IdB,Close)->
	case find_is_exists(IdA,IdB,1) of
		{ok,false}->
			{error,11};
		{Id,true}->
			case ets:lookup(?ETS_RELA,Id) of
				[] -> 
					{error,11};
				[R] ->
					case R#ets_rela.close>=Close of
						false->{error,12};
						true->ok
					end
			end
	end.

%%扣除亲密度
del_close(IdA,IdB,Close,Type)->
	case ets:match_object(?ETS_RELA, #ets_rela{ pid = IdA, rid = IdB, rela = 1, _ = '_'}) of
		[]->error;
		[Rela]->
			NewClose = Rela#ets_rela.close-Close,
			NewRela = Rela#ets_rela{close = NewClose},
			ets:insert(?ETS_RELA, NewRela),
			{Id,_,_} = NewRela#ets_rela.id,
			spawn(fun()->db_agent:update_close(Id,NewRela#ets_rela.close,NewRela#ets_rela.pk_mon,NewRela#ets_rela.timestamp)end),
			spawn(fun()->db_agent:log_close_consume(IdA,IdB,Type,Close,util:unixtime())end),
			ok
	end.

%%扣除亲密度
del_close_etsonly(IdA,IdB,Close)->
	case ets:match_object(?ETS_RELA, #ets_rela{ pid = IdA, rid = IdB, rela = 1, _ = '_'}) of
		[]->error;
		[Rela]->
			NewClose = Rela#ets_rela.close-Close,
			NewRela = Rela#ets_rela{close = NewClose},
			ets:insert(?ETS_RELA, NewRela)
	end.
			
%%中秋活动，亲密度判断发礼包
mid_festival_award(NickNameA, NickNameB, AId, BId, NewClose, OldClose) ->
	case check_mid_time() of
		true ->
			case NewClose >= ?MID_FESTIVAL_CLOSE andalso OldClose < ?MID_FESTIVAL_CLOSE of
				true ->
					case got_midaward_data(AId,BId)of
						true ->%%领取过了
							skip;
						false ->%%可以发
							%%发邮件
							close_midaward_mail(NickNameA, NickNameB, 1),
							close_midaward_mail(NickNameB, NickNameA, 1),
							%%做日志记录
							Fields = [rela, time],
							Now = util:unixtime(),
							RelaName = [AId,BId],
							RelaNameStr = util:term_to_string(RelaName),
							Values = [RelaNameStr, Now],
							db_agent:insert_midaward_data(mid_close_award, Fields, Values)
					end;
				false ->%%不够亲密度
					skip
			end;
		false ->
			skip
	end.


%%判断是否活动时间
check_mid_time() ->
	NowTime = util:unixtime(),
%% 	活动时间：9月10日00点　至　9月12日24点				
	NowTime > 1315584000 andalso NowTime < 1315843200.

	
%% 	===============================
	%%暂时测试用，恒返回 true
%% 	true.
%% 	===============================


got_midaward_data(AId,BId) ->
	RelaName1 = [AId,BId],
	RelaName2 = [BId,AId],
	RelaNameStr1 = util:term_to_string(RelaName1),
	RelaNameStr2 = util:term_to_string(RelaName2),
	case db_agent:get_midaward_date(mid_close_award,RelaNameStr1,RelaNameStr2) of
		[] ->
			false;
		RelaRes when is_list(RelaRes)->
			true;
		_ ->%%出错
			true
	end.
	
%%删除数据
delete_midaward_data(AId,BId) ->
	RelaName1 = [AId,BId],
	RelaName2 = [BId,AId],
	RelaNameStr1 = util:term_to_string(RelaName1),
	RelaNameStr2 = util:term_to_string(RelaName2),
	db_agent:delete_midaward_date(mid_close_award,RelaNameStr1,RelaNameStr2).
%%发邮件
close_midaward_mail(PlayerNameA, PlayerNameB, Num) ->
	FriedName = tool:to_list(PlayerNameB),
	Content = io_lib:format("哇塞，中秋节送礼包啦，恭喜您与您的好友[ ~s ]之间的亲密度持续上涨，达到亲密好友要求，特发此礼包给予奖励，加油！",[FriedName]),
	Title = "中秋亲密礼包",
	GoodsTypeId = 31015,	%%中秋亲密礼包ID 
	%%物品不可以群发
	mod_mail:send_sys_mail([tool:to_list(PlayerNameA)], Title, Content, 0, GoodsTypeId, Num, 0, 0).

%% %%更新玩家亲密度时，顺便给玩家发邮件奖励
%% give_mid_festival_award(MidAward,Player,Close) ->
%% 	{OldClose,Type,BId,NickNameA} = MidAward,
%% 	#player{id = PlayerId,
%% 			nickname = NickNameB} = Player,
%% 	case Type =:= 1 of
%% 		true ->
%% 			lib_relationship:mid_festival_award(NickNameA, NickNameB, PlayerId, BId, Close, OldClose);
%% 		false ->
%% 			skip
%% 	end.


%%系统判断已有的亲密度，仅执行一次的方法
check_give_mid_close(NowTime) ->
%% 	case NowTime > 1315302600 andalso NowTime < (1315302600 + 11) of %%测试用
	case NowTime > 1315584000 andalso NowTime < (1315584000 + 11) of
		true ->%%只做一次的判断和处理
			sys_give_mid_close();
		false ->
			skip
	end.
sys_give_mid_close() ->
	case db_agent:get_close_ok(?MID_FESTIVAL_CLOSE) of
		[] ->%%囧，居然不用做
%% 			?DEBUG("omg", []),
			skip;
		List ->
%% 			?DEBUG("the lists is:~p", [List]),
			Now = util:unixtime(),
			lists:foreach(fun(Elem) ->
								  [AId, BId] = Elem,
								  case db_agent:get_player_name(AId) of
										[] ->
											skip;
										[AName] ->
											case db_agent:get_player_name(BId) of
												[] ->
													skip;
												[BName] ->
													case got_midaward_data(AId,BId) of
														true ->%%判断是否需要发送
															skip;
														false ->
															close_midaward_mail(AName, BName, 1),
															close_midaward_mail(BName, AName, 1),
															%%做日志记录
															Fields = [rela, time],
															RelaNameStr = util:term_to_string(Elem),
															Values = [RelaNameStr, Now],
															db_agent:insert_midaward_data(mid_close_award, Fields, Values)
													end
											end
									end
							end, List)
	end.

%%判断是否好友并且亲密度超过16000
rela_for_marry(IdA,IdB,Rela) ->
	case find_is_exists(IdA,IdB,Rela) of
		{ok,false} -> {fail,9};
		{Id,true} ->
			case ets:lookup(?ETS_RELA, Id) of
				[] ->{fail,9};
				[R|_Rets] ->
					if R#ets_rela.close >= 9000 ->
						   {ok,suc};
					   true ->
						   {fail,10}
					end
			end
	end.

%% ==============================
%% 活动七：白色情人节，亲密度双倍涨		
%% ==============================
%%判断是否活动双倍亲密度时间
get_active_param()->
    {S,E} = lib_activities:whiteday_time(),
	Now = util:unixtime(),
	case Now > S andalso Now < E of
		true ->
			2;
		false ->
			1
	end.

%%打怪接口专用
get_active_param_mon(Now)->
	{S,E} = lib_activities:whiteday_time(),
	case Now > S andalso Now < E of
		true ->
			{2,800};
		false ->
			{1,400}
	end.

	