%% Author: Administrator
%% Created: 2011-8-16
%% Description: TODO:跨服战场
-module(lib_war).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
%%
%% Exported Functions
%%
-compile(export_all).



%%
%% API Functions
%%

is_war_server()->
	config:get_war_server_mark() > 0.

is_war_scene(SceneId) ->
	Scene = SceneId rem 1000,
	lists:member(Scene,[730,740,750,760]).
%% 	Scene =:= 750 orelse Scene =:= 760.
is_wait_scene(SceneId) ->
	Scene = SceneId rem 1000,
	lists:member(Scene,[760]).
%% 	Scene =:= 760.

is_fight_scene(SceneId)->
	Scene = SceneId rem 1000,
	lists:member(Scene,[750]).
%% 	Scene =:= 750.

is_war_week()->
	Week = util:get_date(),
	lists:member(Week,[7]). 

%%重载资源配置
reload(WarServerIp,WarServerPort,State,Port)->
	lists:map(fun(N)->rpc:call(N,application,set_env,[server,war_server_info,[WarServerIp,WarServerPort,State,Port]]) end,nodes()). 

%%加载跨服战场玩家数据
init_war_player()->
	F = fun(PlayerData) ->
			EtsData = list_to_tuple([ets_war_player] ++ PlayerData),
            ets:insert(?ETS_WAR_PLAYER, EtsData)
           end,
	PlayerData = db_agent:select_war_player(),
	lists:foreach(F, PlayerData),
    ok.

%%加载跨服战场玩家积分数据
init_war_award()->
	F = fun(Award) ->
			EtsAward = list_to_tuple([ets_war_award] ++ Award),
            ets:insert(?ETS_WAR_AWARD, EtsAward)
           end,
	Award = db_agent:select_war_award(),
	lists:foreach(F, Award),
    ok.

%%获取跨服资格玩家数据
get_war_player()->
	case is_war_week() of
		true->
			clear_war_player(),
%% 			Times = check_times(),
%% 			PlayerBag = db_agent:loop_query_batt_value(?SLAVE_POOLID,50),
%% %% 			PlayerBag = mod_arena_supervisor:rank_current_arena_week(),
%% 			NewPlayerBag = loop_check_player(0,PlayerBag,[]),
%% %% 			io:format("get_war_player>>~p~n",[NewPlayerBag]),
%% 			Platform = config:get_platform_name(),
%% 			Sn = config:get_server_num(),
%% 			[insert_war_player(PlayerId,NickName,Realm,Career,Sex,Lv,Platform,Sn,Times)||{PlayerId,NickName,Realm,Career,Sex,Lv}<-NewPlayerBag],
			ok;
		false->skip
	end.
			 

loop_check_player(_20,[],NewPlayerBag)->
	NewPlayerBag;
loop_check_player(20,_PlayerBag,NewPlayerBag)->
	NewPlayerBag;
loop_check_player(Nums,[Player|PlayerBag],NewPlayerBag)->
	[PlayerId,_] = Player,
	Data = db_agent:get_player_mult_properties([nickname,realm,career,sex,lv],[PlayerId]),
	case Data of
		[{_,[Nickname, Realm, Career,Sex, Lv]}]->
			if Lv >= 50->
				loop_check_player(Nums+1,PlayerBag,[{PlayerId, Nickname, Realm, Career,Sex, Lv}|NewPlayerBag]);
			   true->loop_check_player(Nums,PlayerBag,NewPlayerBag)
			end;
		_->loop_check_player(Nums,PlayerBag,NewPlayerBag)
	end.
	%%[_Player_Id8, Nickname8, Realm8, Career8, Lv8, Wins8]
%% 	[_,PlayerId, Nickname, Realm, Career, Lv, _Wins8] = Player,
%% 	if Lv>=50->
%% 		   Sn = config:get_server_num(),
%% 		   Data = db_agent:get_player_mult_properties([sex],[PlayerId]),
%% 		   case lists:keyfind(PlayerId,1,Data) of
%% 			   false->loop_check_player(Nums,PlayerBag,NewPlayerBag);
%% 			   {_1,[Sex]}->
%% 				   loop_check_player(Nums+1,PlayerBag,[{PlayerId, Nickname, Realm, Career,Sex, Lv,Sn}|NewPlayerBag]);
%% 			   _->loop_check_player(Nums,PlayerBag,NewPlayerBag)
%% 		   end;
%% 	   true->
%% 		   loop_check_player(Nums,PlayerBag,NewPlayerBag)
%% 	end. 

%%添加跨服战场玩家数据
insert_war_player(PlayerId,NickName,Realm,Career,Sex,Lv,Platform,Sn,Times)->
	{_,Id} = db_agent:insert_war_player(PlayerId,NickName,Realm,Career,Lv,Platform,Sn,Times,0,Sex),
	ets:insert(?ETS_WAR_PLAYER, #ets_war_player{id=Id,pid=PlayerId,nickname=NickName,realm=Realm,career=Career,sex=Sex,level=Lv,platform = Platform,sn=Sn,times=Times}),
	mail_notice_sign_up(NickName),
	ok.

%%清除跨服战场玩家数据
clear_war_player()-> 
	delete_war_player(),
	db_agent:clear_war_player(),
	ok.

%%查询历届大会记录
get_war_record(Times1,TimesRecord)->
	NowTimes = case TimesRecord =:= 0 of
				   true->
					   case is_war_server() of
						   true->
							   check_times();
						   false->
							    check_times()-1
					   end;
				   false->TimesRecord
			   end,
	Times=case Times1 of
		0->NowTimes;
		_->Times1
	end,
	Record = select_war_team(Times),
	LvList = util:filter_list([Team#ets_war_team.lv||Team<-Record],1,1),
	Nums = length(LvList),
	RecordBag = [pack_record_loop(Times,Lv)||Lv<-LvList],
	{ok,NowTimes,Times,Nums,RecordBag}.

pack_record_loop(Times,Lv)->
	Record = select_war_team(Times,Lv),
	Data = [{R#ets_war_team.lv,R#ets_war_team.point,R#ets_war_team.platform,R#ets_war_team.sn}||R<-Record],
	%% 分数由高到底
	SortFun = fun({_,P1,_,_}, {_,P2,_,_}) ->
		P1 > P2 
	end,
	NewRecordBag = lists:sort(SortFun, Data),
	add_sort_num(NewRecordBag,1,[]).

add_sort_num([],_,Info)->Info;
add_sort_num([R|Record],Num,Info)->
	{Lv,_,Plat,Name} = R,
	add_sort_num(Record,Num+1,[{Lv,Num,Plat,Name}|Info]).

%%获取封神大会记录到远程
get_record_to_remote(Times,MaxLv,MaxRound)->
	TeamData = db_agent:select_war_team(Times),
	VsData = db_agent:select_war_vs(),
	{Times,MaxLv,MaxRound,TeamData,VsData}.

%%添加封神大会记录到本地
add_war_record(Times,[])->
	init_war_team(Times);
add_war_record(Times,[Record|RecordBag])->
	War = list_to_tuple([ets_war_team | Record]),
	ValueList = lists:nthtail(2, tuple_to_list(War)),
    [id | FieldList] = record_info(fields, ets_war_team),
	?DB_MODULE:insert(war_team, FieldList, ValueList),
	add_war_record(Times,RecordBag).

add_war_record_vs(MaxLv,MaxRound,[])->
	init_war_vs(),
	VsInfo = [continue_vs(Lv,MaxRound)||Lv<-lists:seq(1,MaxLv)],
	VsInfo;
add_war_record_vs(MaxLv,MaxRound,[Record|RecordBag])->
	War = list_to_tuple([ets_war_vs | Record]),
	ValueList = lists:nthtail(2, tuple_to_list(War)),
    [id | FieldList] = record_info(fields, ets_war_vs),
	?DB_MODULE:insert(war_vs, FieldList, ValueList),
	add_war_record_vs(MaxLv,MaxRound,RecordBag).

%%删除记录
del_war_record(Times)->
	db_agent:delete_war_vs(),
	delete_war_vs(),
	db_agent:delete_war_team(Times),
	delete_war_team(Times).

%%跨服战场报名（新版）
%%1、报名成功，2、现在不是封神大会报名时间3、玩家等级低于50级4、您的战斗力没进入战斗力排行榜前20名
%%5、您已经报名，6、你取消了报名，不能从新报名、7、当前报名玩家已满15名，您的战斗力在已报名玩家之下,8成功更新战斗力
war_sign_up_new(PlayerStatus)->
	case check_sign_up_time() of
		signup_no->{error,2};
		_->
			if PlayerStatus#player.lv<50->{error,3};
			   true->
				   case check_att_rank(PlayerStatus#player.id) of
					   {false,_}->{error,4};
					   {true,_Att}->
						   Platform = config:get_platform_name(),
						   Sn = config:get_server_num(),
						   Att = lib_player:count_value(PlayerStatus#player.other#player_other.batt_value),							   
						   case had_sign_up(PlayerStatus#player.id,PlayerStatus#player.nickname,Platform,Sn,Att) of
							   {error,Err1}->{error,Err1};
							   {ok,1}->
								    case get_sign_up_nums()>=20 of
										false->
											sign_up_new(PlayerStatus,Platform,Sn,Att),
											{ok,1};
										true->
											case check_sign_up_att(Att) of
												{error,Err2}->{error,Err2};
												{ok,1}->
													sign_up_new(PlayerStatus,Platform,Sn,Att),
													{ok,1}
											end
									end
						   end
				   end
			end
	end.

%%查询是否已经报名
had_sign_up(PLayerId,Nickname,Platform,Sn,Att)->
	case select_war_player(PLayerId) of
		[]->{ok,1};
		[P]->
%% 			if P#ets_war_player.sign_up=:=1->
				   if P#ets_war_player.att < Att->
						  NewP = P#ets_war_player{att=Att},
						  update_war_player(NewP),
						  db_agent:update_war_player([{att,Att}],[{id,P#ets_war_player.id}]),
						  mod_leap_client:update_player_att(Platform,Sn,Nickname,Att),
						  {error,8};
					  true->
						  {error,8}
				   end
%% 			   true->{error,6}
%% 			end
	end.
%%报名
sign_up_new(PlayerStatus,Platform,Sn,Att)->
	Times = check_times(),
	
	{_,Id} = db_agent:insert_war_player(PlayerStatus#player.id,
										PlayerStatus#player.nickname,
										PlayerStatus#player.realm,
										PlayerStatus#player.career,
										PlayerStatus#player.lv,
										Platform,
										Sn,
										Times,
										0,
										PlayerStatus#player.sex,
										Att),
	ets:insert(?ETS_WAR_PLAYER, #ets_war_player{id=Id,
												pid=PlayerStatus#player.id,
												nickname=PlayerStatus#player.nickname,
												realm=PlayerStatus#player.realm,
												career=PlayerStatus#player.career,
												sex=PlayerStatus#player.sex,
												level=PlayerStatus#player.lv,
												platform = Platform,
												sn=Sn,
												att=Att,
												sign_up=1,
												times=Times}),
	%%测试
	
%% 	update_to_team_test(PlayerStatus#player.id,PlayerStatus#player.nickname,
%% 				   PlayerStatus#player.career,PlayerStatus#player.realm,
%% 				   PlayerStatus#player.lv,PlayerStatus#player.sex,PlayerStatus#player.vip,
%% 						Att,Platform,PlayerStatus#player.sn,Times),
	ok.

%%检查已报名玩家战斗力列表
check_sign_up_att(Att)->
	Members = ets:match_object(?ETS_WAR_PLAYER, #ets_war_player{sign_up=1,_='_'}),
	AttList =lists:reverse(lists:sort([P#ets_war_player.att||P<-Members] )),
	case AttList of
		[]->{ok,1};
		_-> 
			case length(AttList) >=20 of
				false->{ok,1};
				true->
					MinAtt = lists:nth(20, AttList),
					if Att > MinAtt ->
				   		{ok,1};
			  		 true->{error,7}
					end
			end
	end.

%%检查玩家是否在战斗力前20名内，并返回战斗力
check_att_rank(PlayerId)->
	PlayerBag = db_agent:loop_query_batt_value(?SLAVE_POOLID,20),
	{Res,Att} = check_att_rank_loop(PlayerBag,PlayerId),
	{Res,Att}.

check_att_rank_loop([],_PlayerId)->
  	{false,0};
%%	{true,0};
check_att_rank_loop([PlayerInf|PlayerBag],PlayerId)->
	[Pid,Att] = PlayerInf,
	if PlayerId =:= Pid ->
		   {true,Att};
	   true->
		   check_att_rank_loop(PlayerBag,PlayerId)
	end.

%%取消报名
cancel_war_sign_up(PlayerStatus)->
	case select_war_player(PlayerStatus#player.id) of
		[]->{error,2};
		[P]->
			delete_war_player_one(P#ets_war_player.id),
			db_agent:delete_war_player(P#ets_war_player.id),
			Platform = config:get_platform_name(),
			Sn = config:get_server_num(),
			mod_leap_client:del_player_data(Platform,Sn,PlayerStatus#player.nickname,PlayerStatus#player.id),
			{ok,1}
	end.

%%选取战斗力前10名玩家进入封神大会
select_top_ten()->
	PlayerBag = select_war_player_all(),
	Data = [{P#ets_war_player.id,P#ets_war_player.platform,P#ets_war_player.sn,P#ets_war_player.nickname,P#ets_war_player.pid,P#ets_war_player.sign_up,P#ets_war_player.att}||P<-PlayerBag],
	%% 战斗力由高到底
	SortFun = fun({_,_,_,_,_,_,P1}, {_,_,_,_,_,_,P2}) ->
		P1 > P2 
	end,
	Members = lists:sort(SortFun,Data), 
	top_ten_loop(Members,0,[]),
	ok.

top_ten_loop([],_Num,Unlucky)->
	del_unlucky_player(Unlucky),
	ok;
top_ten_loop(Members,10,Unlucky)->
	del_unlucky_player(Members++Unlucky),
	ok;
top_ten_loop([M|Members],Num,Unlucky)->
	{_Id,_Platform,_Sn,NickName,_PlayerId,SignUp,_Att} = M,
	if SignUp=:= 1->
		   NameList = [tool:to_list(NickName)],
		   Content = "亲爱的玩家，你获得了封神大会的参赛资格，请在15:30后进入封神大会专线准备比赛。",
		   mod_mail:send_sys_mail(NameList, "封神大会", Content, 0,0, 0, 0, 0),
		   top_ten_loop(Members,Num+1,Unlucky);
	   true->
		   top_ten_loop(Members,Num,[M|Unlucky])
	end.

del_unlucky_player([])->ok;
del_unlucky_player([M|Member])->
	{Id,Platform,Sn,NickName,PlayerId,_SignUp,_Att} = M,
	ets:delete(?ETS_WAR_PLAYER, Id)	,
	db_agent:delete_war_player(Id),
	mod_leap_client:del_player_data(Platform,Sn,NickName,PlayerId),
	del_unlucky_player(Member),
	ok.

%%报名测试
war_sign_up_test(PlayerStatus)->
	if PlayerStatus#player.lv<50->{error,6};
	   true->
		   case get_sign_up_nums()>=10 of
			   true->{error,3};
			   false->
				   Type = check_sign_up_time(),
				   case lists:member(Type,[signup_fir,signup_sec]) of
					   true->
				  		 case select_war_player(PlayerStatus#player.id) of
					  		 []->
									Times = check_times()-1,
									Platform = config:get_platform_name(),
									insert_war_player(PlayerStatus#player.id,PlayerStatus#player.nickname,PlayerStatus#player.realm,PlayerStatus#player.career,PlayerStatus#player.sex,PlayerStatus#player.lv,tool:to_binary(Platform),PlayerStatus#player.sn,Times),
									[PlayerData] = select_war_player(PlayerStatus#player.id),
									into_team_test(PlayerStatus,Times,Platform),
									sign_up(PlayerStatus,PlayerData);
					  		 [Info]->
								 if Info#ets_war_player.sign_up=:=1->{error,5};
									true->
										into_team_test(PlayerStatus,Info#ets_war_player.times,Info#ets_war_player.platform),
										sign_up(PlayerStatus,Info)
								 end
				  		 end;
					   false->{error,4}
				   end
			   end
	end.

into_team_test(PlayerStatus,Times,Platform)->
	case select_war_team_by_sn(tool:to_binary(Platform),PlayerStatus#player.sn,Times) of
		[]->skip3;
		[TeamBag]->
			Att = lib_player:count_value(PlayerStatus#player.other#player_other.batt_value),
			Team = {PlayerStatus#player.id,PlayerStatus#player.nickname,PlayerStatus#player.career,PlayerStatus#player.realm,PlayerStatus#player.lv,PlayerStatus#player.sex,PlayerStatus#player.vip,Att},
			NewTeam = [Team|TeamBag#ets_war_team.team],
			NewTeamBag = TeamBag#ets_war_team{team=NewTeam},
			update_war_team(NewTeamBag), 
			db_agent:update_war_team([{team,util:term_to_string(NewTeam)}],[{id,TeamBag#ets_war_team.id}]),
			ok
	end.

%%%%%%%跨服才有新的报名机制，以下的报名方式取消，包括邀请，转让
%%跨服战场报名(1报名成功，2你没有报名资格，3当前报名人数已经超过10人，4现在不是报名时间,0报名失败，请重试)
war_sign_up(PlayerStatus)->
	case select_war_player(PlayerStatus#player.id) of
		[]->{error,2};
		[PlayerData]->
			case get_sign_up_nums()>=10 of
				true->{error,3};
				false->
					if PlayerData#ets_war_player.sign_up=:=1->{error,5};
					   true->
						   case check_sign_up_time() of
							   signup_no->{error,4};
							   _->sign_up(PlayerStatus,PlayerData)
						   end
%% 							   signup_fir->
%% 								   sign_up(PlayerStatus,PlayerData);
%% 							   signup_sec->
%% 								   if PlayerData#ets_war_player.is_invite =:= 1 ->
%% 										  sign_up(PlayerStatus,PlayerData);
%% 									  true->{error,4}
%% 								   end;
%% 							   _->{error,4}
%% 						   end
					end
			end
	end.

%%报名
sign_up(PlayerStatus,PlayerData)->
	NowTime = util:unixtime(),
	NewPlayerData = PlayerData#ets_war_player{sign_up=1,timestamp=NowTime},
	update_war_player(NewPlayerData),
	db_agent:update_war_player([{sign_up,1},{timestamp,NowTime}],[{pid,PlayerStatus#player.id}]),
	mail_sign_up_ok(PlayerStatus#player.nickname),
%% 	spawn(fun()->db_agent:log_war_player(PlayerStatus#player.id,PlayerData#ets_war_player.times,NowTime)end),
	{ok,1}.


	
%%查询邀请信息
check_invite_info(PlayerStatus)->
	case select_war_player(PlayerStatus#player.id) of
		[]->[2,0,0,0];
		[PlayerData]->
			[PlayerData#ets_war_player.sign_up,length(select_war_player_sign_up()),PlayerData#ets_war_player.invite,2-PlayerData#ets_war_player.invite]
	end.

%%查看参赛队伍信息
check_war_player(PlayerId)->
	Data = case is_war_server()of
		false->
			Bag = select_war_player_all(),
			[{P#ets_war_player.nickname,P#ets_war_player.realm,P#ets_war_player.career,P#ets_war_player.level,P#ets_war_player.att}||P<-Bag,P#ets_war_player.sign_up=:=1];
		true->
			case select_war_player(PlayerId) of
				[]->[];
				[Info]->
					Bag = select_war_player_by_sn(Info#ets_war_player.platform,Info#ets_war_player.sn),
					[{P#ets_war_player.nickname,P#ets_war_player.realm,P#ets_war_player.career,P#ets_war_player.level,P#ets_war_player.att}||P<-Bag]
			end
	end,
	SortFun = fun({_,_,_,_,P1}, {_,_,_,_,P2}) ->
					  P1 > P2 
			  end,
	Members = lists:sort(SortFun,Data),
	Members.
			
%%查看全体参赛队伍
war_team(Times,MaxLv)->
	LvList = lists:seq(1,MaxLv),
	Data= [get_war_team(Times,Lv)||Lv<-LvList],
	Data.
	
get_war_team(Times,Lv)->
	TeamBag = select_war_team(Times,Lv),
	{Lv,[{Team#ets_war_team.platform,Team#ets_war_team.sn,Team#ets_war_team.team}||Team<-TeamBag]}.
						  
	
%%查看队伍对阵信息
war_vs(VsInfo)->
	Len = length(VsInfo),
	{Len,[get_vs_info(Vs)||Vs<-VsInfo]}.

get_vs_info(Vs)->
	{Lv,IdList} = Vs,
	{Lv,[pack_vs_info_loop(Idbag,[])||Idbag<-IdList]}.

pack_vs_info_loop([],Bag)->
	Bag;
pack_vs_info_loop([Id|IdBag],Bag)->
	case select_war_vs(Id) of
		[]->
			pack_vs_info_loop(IdBag,Bag);
		[Vs]->
			pack_vs_info_loop(IdBag,[{Vs#ets_war_vs.platform_a,Vs#ets_war_vs.sn_a,Vs#ets_war_vs.res_a,Vs#ets_war_vs.platform_b,Vs#ets_war_vs.sn_b,Vs#ets_war_vs.res_b}|Bag])
	end.

%%查看比赛积分
war_point(Times,MaxLv)->
	LvList = lists:seq(1, MaxLv),
	Data= [get_war_team_point(Times,Lv)||Lv<-LvList],
	Data.

get_war_team_point(Times,Lv)->
	TeamBag = select_war_team(Times,Lv),
	Data = [{Team#ets_war_team.platform,Team#ets_war_team.sn,Team#ets_war_team.point}||Team<-TeamBag],
	%% 分数由高到底
	SortFun = fun({_,_,P1}, {_,_,P2}) ->
		P1 > P2 
	end,	
	NewMemberList = lists:sort(SortFun, Data),
	{Lv,NewMemberList}.
	

%%跨服战场名额邀请(1邀请成功，2报名还没截止，不能邀请，3当前报名人数已达10人，不能邀请，4玩家不存在，5玩家不在线，
%%6玩家等级低于55级,7你没有邀请的资格,8你的邀请次数已达3次,9你还没有报名，不能邀请,10不能邀请自己,11受邀请的玩家已经获得资格，不能邀请,12补充邀请名额已满,13报名已截止)
war_invite(PlayerStatus,NickName)->
	case select_war_player(PlayerStatus#player.id) of
		[]->{error,7}; 
		[PlayerData]->
			if PlayerData#ets_war_player.invite >=2 ->
				   {error,8};
			   true->
				   case PlayerData#ets_war_player.sign_up > 0 of
					   false->{error,9};
					   true->
							case check_sign_up_time() of
								signup_sec->
									SignNum = get_sign_up_nums(),
									case SignNum >=10 of
										true->{error,3};
										false->
											case SignNum + get_invite_nums() >=20 of
												true->{error,12};
												false->
													case lib_player:get_role_id_by_name(NickName) of
														null->{error,4};
														[]->{error,4};
														InviteId->
															case lib_player:get_online_info(InviteId) of
																[]->{error,5};
																Invitee->
																	if Invitee#player.id =:= PlayerStatus#player.id->{error,10};
																	   true->
																			case Invitee#player.lv >= 50 of
																				true->
																					case select_war_player(Invitee#player.id) of
																						[]->
																							NewPlayerData = PlayerData#ets_war_player{invite=PlayerData#ets_war_player.invite+1},
																							update_war_player(NewPlayerData),
																							Times = check_times(),
																							Sn = config:get_server_num(),
																							Platform = config:get_platform_name(),
																							db_agent:update_war_player([{invite,1,add}],[{pid,PlayerStatus#player.id}]),
																							{_,Id} = db_agent:insert_war_player(InviteId,NickName,Invitee#player.realm,Invitee#player.career,Invitee#player.lv,Platform,Sn,Times,1,Invitee#player.sex),
																							ets:insert(?ETS_WAR_PLAYER, #ets_war_player{id=Id,pid=InviteId,nickname=NickName,career = Invitee#player.career,level = Invitee#player.lv,realm=Invitee#player.realm,sn=Invitee#player.sn,sex = Invitee#player.sex,is_invite=1}),
																							mail_notice_invite(NickName,PlayerStatus#player.nickname),
																							{ok,1};
																						_->{error,11}
																					end;
																				false->{error,6}
																			end
																	end
															end
													end
											end
									end;
								_->{error,2}
							end
				   end
			end
	end.

%%跨服战场请求名额转让(1转让请求成功，（2你没有参赛资格，不能转让，3你的名额不能转让，4你的资格是邀请的，不能转让，
%%5当前时间不允许转让，6玩家不存在，7玩家不在线,9受转让的玩家已经获得资格，不能转让,10接受转让的玩家等级低于55,11当前报名人数已满10人，不能转让
war_request_transfer(PlayerStatus,NickName)->
	case war_check_transfer(PlayerStatus) of
		{error,Error}->
			{error,Error};
		{ok,PlayerData}->
			case lib_player:get_role_id_by_name(NickName) of
				null->{error,6};
				[]->{error,6};
				InviteId->
					if InviteId =:= PlayerStatus#player.id->{error,8};
					   true->
							case lib_player:get_online_info(InviteId) of
								[]->{error,7};
								Invitee->
									case select_war_player(Invitee#player.id) of
										[]->
											if Invitee#player.lv < 50->{error,10};
											   true->
													{ok,Invitee,PlayerData#ets_war_player.sign_up}
											end;
										_->{error,9}
									end
							end	
					end
			end
	end.

%%跨服战场回应名额转让
war_answer_transfer(PlayerStatus,NickName,Res)->
	case lib_player:get_role_id_by_name(NickName) of
		null->{error,6};
		[]->{error,6};
		InviteId->
			case lib_player:get_online_info(InviteId) of
				[]->{error,7};
				Invitee->
					case Res of
						2->{ok,Invitee,0};
						1->
							case war_check_transfer(Invitee) of 
								{error,Error}->{error,Error};
								{ok,PlayerData}->
									NewPlayerData = PlayerData#ets_war_player{pid=PlayerStatus#player.id,nickname=PlayerStatus#player.nickname,career =PlayerStatus#player.career,level = PlayerStatus#player.lv,sex=PlayerStatus#player.sex, realm=PlayerStatus#player.realm,transfer=1},
									update_war_player(NewPlayerData),
									db_agent:update_war_player([{pid,PlayerStatus#player.id},{nickname,PlayerStatus#player.nickname},{career,PlayerStatus#player.career},{level,PlayerStatus#player.lv},{sex,PlayerStatus#player.sex},{realm,PlayerStatus#player.realm},{transfer,1}],[{id,PlayerData#ets_war_player.id}]),
									mail_notice_transfer(PlayerStatus#player.nickname,NickName),
									{ok,Invitee,1}
							end;
						_->{error,Res}
					end
			end
	end.

%%跨服战场检查名额转让（2你没有参赛资格，不能转让，3你的名额不能转让，4你的资格是邀请的，不能转让，4当前时间不允许转让
war_check_transfer(PlayerStatus)->
	case select_war_player(PlayerStatus#player.id) of
		[]->{error,2}; 
		[PlayerData]->
			if PlayerData#ets_war_player.transfer >0 ->
				   {error,3};
			   true->
				   case get_sign_up_nums()>= 10 of
					   true->
						   if PlayerData#ets_war_player.sign_up =:= 1 ->
								  case check_sign_up_time() of
									  signup_no->
										  {error,5};
									  _->
										  if PlayerData#ets_war_player.is_invite > 0->{error,4};
											 true->
												 {ok,PlayerData}
										  end
								  end;
							  true->
								  {error,11}
						   end;
					   false->
						   case check_sign_up_time() of
							   signup_no->
								   {error,5};
							   _->
						   		if PlayerData#ets_war_player.is_invite > 0->{error,4};
							 		 true->
								 		 {ok,PlayerData}
						   		end
						   end
				   end
			end
	end.

%%加载大会历史记录
init_war_team_all()->
	F = fun(Team) ->
			T = list_to_tuple([ets_war_team] ++ Team),
			TeamInfo = T#ets_war_team{team=util:string_to_term(tool:to_list(T#ets_war_team.team))},			
            ets:insert(?ETS_WAR_TEAM, TeamInfo)
           end,
	L = db_agent:select_war_team_all(),
	lists:foreach(F, L),
    ok.

%%加载大会历史记录
init_war_team(Times)->
	F = fun(Team) ->
			T = list_to_tuple([ets_war_team] ++ Team),
			TeamInfo = T#ets_war_team{team=util:string_to_term(tool:to_list(T#ets_war_team.team))},			
            ets:insert(?ETS_WAR_TEAM, TeamInfo)
           end,
	L = db_agent:select_war_team(Times),
%% 	io:format("INit>>>>>>>>>>>>>>>~p~n",[L]),
	lists:foreach(F, L),
    ok.

%%添加大会历史记录
add_war_team(Data)->
	[_,Platform,Sn,Name,Team,Lv,Times,Point] = Data,
	{_,Id} = db_agent:insert_war_team(Platform,Sn,Name,Team,Lv,Times,Point),
	ets:insert(?ETS_WAR_TEAM, #ets_war_team{id=Id,platform=Platform,sn=Sn,name=Name,team=util:string_to_term(tool:to_list(Team)),lv=Lv,times=Times,point=Point}),
	{ok,Id}.

%%添加对战分组
add_war_team_vs(PlatformA,SnA,NameA,PlatformB,SnB,NameB,Times,Lv,Round,ResA,ResB,Timestamp)->
	{_,Id} = db_agent:insert_war_vs(PlatformA,SnA,NameA,PlatformB,SnB,NameB,Times,Lv,Round,ResA,ResB,Timestamp),
	ets:insert(?ETS_WAR_VS,#ets_war_vs{id=Id,platform_a=PlatformA,sn_a=SnA,name_a=NameA, platform_b=PlatformB,sn_b=SnB,name_b=NameB,times=Times,lv=Lv,round=Round,res_a=ResA,res_b=ResB,timestamp=Timestamp}),
	{ok,Id}.

%%加载大会对战分组
init_war_vs()->
	F = fun(Vs) ->
			T = list_to_tuple([ets_war_vs] ++ Vs),
            ets:insert(?ETS_WAR_VS, T)
           end,
	L = db_agent:select_war_vs(),
	lists:foreach(F, L),
    ok.

%%进入封神大会
enter_match(Status)->
	if Status#player.carry_mark > 0->
		   {error,5};
	   true->
		   if Status#player.scene > 500->
				  {error,6};
			  true->
					case select_war_player(Status#player.id) of
						[]->{error,2};
						[Info]->
							case Info#ets_war_player.sign_up > 0 of
								false->{error,3};
								true->
									case check_enter_time() of
										{ok,_}->
%% 										_->
											{ok,1};
										{_,Error}->{error,Error}
									end
							end
					end
			end
	end.
%%广播比赛时间
timestamp_bc(PlayerStatus,Type,Round,Timestamp)->
	{ok,BinData} = pt_45:write(45014,[Type,Round,Timestamp]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData).

%%===================================================初始化队伍信息========================================================
%%初始化队伍分组
init_server_team()->
	case db_agent:select_war_team_all() of
		[]->
			%%获取参赛服务器列表
%% 			ServerList = db_agent:select_server_all(),
			ServerList = config:get_war_client_info(),
			Len = length(ServerList),
			MaxLv =  case Len rem 4  of
						   0 -> tool:ceil(Len/4);
						   Other ->
							   case Other >= 2 of
								   true -> tool:ceil(Len/4);
								   false-> tool:ceil(Len/4)-1
							   end
					   end,
			init_team_loop_fir(ServerList,1,1,MaxLv),
			init_war_team(1),
			{ok,1};
		_->
			Times = check_times(),
			LvMax = get_lv_max(Times-1),
			LvList = lists:seq(1, LvMax),
			ServerList = config:get_war_client_info(),
			[init_team_loop(Lv,Times,ServerList)||Lv<-LvList],
%% 			ServerList = db_agent:select_server_all(),
			NewServer = check_new_server(ServerList,Times-1,[]),
			[new_team_info(Platform,Sn,Name,LvMax,Times)||{Platform,Sn,Name,State}<-NewServer,State=:=1],
			TeamAll = db_agent:select_war_team_by_times(Times),
			NewLen = length(TeamAll),
			NewMaxLv = case NewLen rem 4  of
						   0 -> tool:ceil(NewLen/4);
						   Other ->
							   case Other >= 2 of
								   true -> tool:ceil(NewLen/4);
								   false-> tool:ceil(NewLen/4)-1
							   end
					   end,
			update_lv(1,1,TeamAll,NewMaxLv), 
			init_war_team(Times),
			{ok,Times}
	end.

%%第一次添加队伍记录
init_team_loop_fir([],_,_,_MaxLv)->
	ok;
init_team_loop_fir([Server|ServerList],NowLv,Num,MaxLv)->
%% 	io:format("NowLv,Num,MaxLv ")
%% 	[Platform,Sn,Name,State] = Server,
	{Platform,Sn,_Ip,_Port,State} = Server,
	if State > 0->
		   if NowLv =:= MaxLv ->
				  db_agent:insert_war_team(Platform,Sn,undefined,[],NowLv,1,0),
				  init_team_loop_fir(ServerList,NowLv,Num+1,MaxLv);
			  true->
				  if Num =:= 4 ->
						 db_agent:insert_war_team(Platform,Sn,undefined,[],NowLv,1,0),
						 init_team_loop_fir(ServerList,NowLv+1,1,MaxLv);
					 true->
						 db_agent:insert_war_team(Platform,Sn,undefined,[],NowLv,1,0),
						 init_team_loop_fir(ServerList,NowLv,Num+1,MaxLv)
				  end
		   end;
	   true->
		   init_team_loop_fir(ServerList,NowLv,Num,MaxLv)
	end.
%%添加新的队伍记录
init_team_loop(Lv,Times,ServerList)->
	TeamInfo = db_agent:select_war_team_by_lv(Times-1,Lv),
	new_team_info_loop(TeamInfo,Lv,Times,ServerList).
%% 	[new_team_info(Platform,Sn,Name,Lv,Times)||[_,Platform,Sn,Name]<-TeamInfo,check_server_state(ServerList,tool:to_list(Platform),Sn) =:=true].


new_team_info_loop([],_Lv,_Times,_ServerList)->ok;
new_team_info_loop([Team|TeamInfo],Lv,Times,ServerList)->
	[_,Platform,Sn,Name] = Team,
	case check_server_state(ServerList,tool:to_list(Platform),Sn) of
		true->
			new_team_info(Platform,Sn,Name,Lv,Times);
		_->skip
	end,
	new_team_info_loop(TeamInfo,Lv,Times,ServerList).
			
												  
new_team_info(Platform,Sn,Name,Lv,Times)->
%% 	Platform = config:get_platform_name(),
	db_agent:insert_war_team(Platform,Sn,Name,[],Lv,Times,0). 
%% 	case db_agent:select_server_state(Platform,Sn) of
%% 		[1]->
%% 			db_agent:insert_war_team(Platform,Sn,Name,[],Lv,Times,0);
%% 		_->skip
%% 	end.

check_server_state([],_Platform,_Sn)->
	false;
check_server_state([Server|ServerList],Platform,Sn)->
	{NewPlatform,NewSn,_Ip,_Port,State} = Server,
	
	if NewPlatform =:= Platform andalso NewSn =:=Sn->
		   if State =:= 1->
				  true;
			  true->check_server_state(ServerList,Platform,Sn)
		   end;
	   true->check_server_state(ServerList,Platform,Sn)
	end.
	
	
%%查找新添加的服务器
check_new_server([],_Times,NewServer)->lists:reverse(NewServer);
check_new_server([Server|ServerList],Times,NewServer)->
%% 	[Platform,Sn,_Name,_State] = Server,
	{Platform,Sn,_Ip,_Port,State} = Server,
	case db_agent:select_war_team_info(Platform,Sn,Times) of
		[]->
			NewServer1 = [{Platform,Sn,undefined,State}]++NewServer,
			check_new_server(ServerList,Times,NewServer1);
		_->check_new_server(ServerList,Times,NewServer)
	end.

 %%获取最高分组
get_lv_max(Times)->
	TeamBag = select_war_team(Times),
	LvList  =util:filter_list( [Team#ets_war_team.lv||Team<-TeamBag],1,1),
	case LvList of
		[]->1;
		_->lists:max(LvList)
	end.

%%更新分组
update_lv(_NowLv,_Num,[],_MaxLv)->
	ok;
update_lv(NowLv,Num,[[Id]|IdList],MaxLv)->
	if NowLv =:= MaxLv ->
		   db_agent:update_war_team([{lv,NowLv}],[{id,Id}]),
		   update_lv(NowLv,Num+1,IdList,MaxLv);
	   true->
		   if Num =:= 4->
				db_agent:update_war_team([{lv,NowLv}],[{id,Id}]),
		   		update_lv(NowLv+1,1,IdList,MaxLv);
			  true->
				  db_agent:update_war_team([{lv,NowLv}],[{id,Id}]),
		   		  update_lv(NowLv,Num+1,IdList,MaxLv)
		   end
	end.

%%==================================================初始化队伍玩家信息===================================================
continue_match_team_info(Times,MaxLv,MaxRound)->
	TeamBag = select_war_team(Times),
	Info = [{Team#ets_war_team.id,Team#ets_war_team.lv}||Team<-TeamBag],
	init_war_vs(),
	VsInfo = [continue_vs(Lv,MaxRound)||Lv<-lists:seq(1,MaxLv)],
	{Info,VsInfo}.
	
init_match_team_info(Times)->
	TeamBag = select_war_team(Times),
	%%初始化队伍信息
	Info = [init_team(Team)||Team<-TeamBag],
	MaxLv = get_lv_max(Times),
	%%初始化对战分组
	VsInfo = team_vs(Times,MaxLv),
	{MaxLv,Info,VsInfo}.
	
%%初始化队伍信息
init_team(Team)->
%% 	PlayerBag = select_war_player_by_times(Team#ets_war_team.platform,Team#ets_war_team.sn,Team#ets_war_team.times),
	PlayerBag = select_war_player_by_sn(Team#ets_war_team.platform,Team#ets_war_team.sn),
%% 	io:format("PlayerBag>>>>>~p~n",[PlayerBag]),
	Info = pack_member_info(PlayerBag,[]),			  
%% 	Info = [{P#ets_war_player.pid,P#ets_war_player.nickname,P#ets_war_player.career,P#ets_war_player.realm,P#ets_war_player.level,P#ets_war_player.sex,P#ets_war_player.sign_up,P#ets_war_player.att}||P<-PlayerBag],
	%% 战斗力由高到底
	SortFun = fun({_,_,_,_,_,_,_,_,P1}, {_,_,_,_,_,_,_,_,P2}) ->
		P1 > P2 
	end,
	Member = lists:sort(SortFun, Info),
	Info1 = get_top_ten(Member,0,[]),
	NewTeam = Team#ets_war_team{team = Info1},
	update_war_team(NewTeam),
	db_agent:update_war_team([{team,util:term_to_string(Info1)}],[{id,Team#ets_war_team.id}]),
	update_player_lv(PlayerBag,Team#ets_war_team.lv),
	{Team#ets_war_team.id,Team#ets_war_team.lv}.

pack_member_info([],Info)->Info;
pack_member_info([P|Member],Info)->
	Vip = get_vip(P#ets_war_player.pid),
	PInfo = {P#ets_war_player.pid,P#ets_war_player.nickname,P#ets_war_player.career,P#ets_war_player.realm,P#ets_war_player.level,P#ets_war_player.sex,P#ets_war_player.sign_up,Vip,P#ets_war_player.att},
	pack_member_info(Member,[PInfo|Info]).

get_vip(PlayerId) ->
	case db_agent:get_player_mult_properties([vip],[PlayerId]) of
		[{_,[Vip]}]->Vip;
		_->0
	end.

get_top_ten([],_Num,Member)->
	Member;
get_top_ten(_,10,Member)->Member;
get_top_ten([M|Mem],Num,Member)->
	{Pid,NickName,Career,Realm,Lv,Sex,SignUp,Vip,Att} = M,
	if SignUp =:=1->
		   get_top_ten(Mem,Num+1,[{Pid,NickName,Career,Realm,Lv,Sex,Vip,Att}|Member]);
	   true->
		   get_top_ten(Mem,Num,Member)
	end.

%%更新玩家分组等级
update_player_lv([],_Lv)->ok;
update_player_lv([P|PlayerBag],Lv)->
	NP = P#ets_war_player{lv=Lv},
	update_war_player(NP),
	db_agent:update_war_player([{lv,Lv}],[{id,P#ets_war_player.id}]),
	update_player_lv(PlayerBag,Lv).

%%分组VS
team_vs(Times,MaxLv)->
	delete_war_vs(),
	db_agent:delete_war_vs(),
	LvList = lists:seq(1,MaxLv),
	VsBag = [vs(Times,Lv)||Lv<-LvList],
	MaxRound = get_max_round(VsBag,0),
	{MaxRound,VsBag}.

vs(Times,Lv)->
	TeamBag = select_war_team(Times,Lv),
	%%分组的队伍数量要满足双数
	NewTeamBag = case length(TeamBag) rem 2 =:= 0 of
					 true->TeamBag;
					 false->lists:append([TeamBag,[undefined]])
				 end,
	VsData = data_war:vs(length(NewTeamBag)),
	case VsData of
		error->{Lv,[]};
		_->
			NowTime = util:unixtime(),
			VsIdBag = round_loop(VsData,[],1,NewTeamBag,Times,Lv,NowTime),
			{Lv,VsIdBag}
	end.

round_loop([],VsIdBag,_Round,_TeamBag,_Times,_Lv,_NowTime)->
	lists:reverse(VsIdBag);
round_loop([VsBag|VsData],VsIdBag,Round,TeamBag,Times,Lv,NowTime)->
	VsId = vs_loop(VsBag,[],TeamBag,Times,Lv,Round,NowTime),
	round_loop(VsData,[VsId|VsIdBag],Round+1,TeamBag,Times,Lv,NowTime).

vs_loop([],VsIdBag,_TeamBag,_Times,_lv,_Round,_NowTime)->
	VsIdBag;
vs_loop([Vs|VsBag],VsIdBag,TeamBag,Times,Lv,Round,NowTime)->
	{Sn1,Sn2} = Vs,
	%%undefined的队伍将轮空
	{PlatformA,SnA,NameA} = case lists:nth(Sn1,TeamBag) of
				undefined->{<<>>,0,<<>>};
				T1->{T1#ets_war_team.platform,T1#ets_war_team.sn,T1#ets_war_team.name}
			end,
	{PlatformB,SnB,NameB} = case lists:nth(Sn2,TeamBag) of
				undefined -> {<<>>,0,<<>>};
				T2->{T2#ets_war_team.platform,T2#ets_war_team.sn,T2#ets_war_team.name}
			end,
	{_,VsId} = add_war_team_vs(PlatformA,SnA,NameA,PlatformB,SnB,NameB,Times,Lv,Round,0,0,NowTime),
	vs_loop(VsBag,[VsId|VsIdBag],TeamBag,Times,Lv,Round,NowTime).

get_max_round([],Round)->
	Round;
get_max_round([{_,Vs}|VsBag],Round)->
	NewRound = length(Vs),
	if NewRound > Round->
		   get_max_round(VsBag,NewRound);
	   true->
		   get_max_round(VsBag,Round)
	end.

%%{Lv,[[Round1],[Round2]...]}
continue_vs(Lv,MaxRound)->
	RoundList = lists:seq(1,MaxRound),
	Vs = continue_vs_pack(RoundList,Lv,[]),
	{Lv,Vs}.

continue_vs_pack([],_Lv,VsInfo)->lists:reverse(VsInfo);
continue_vs_pack([Round|RoundList],Lv,VsInfo)->
	VsBag = select_war_vs_by_lv(Lv,Round),
	Id = [Vs#ets_war_vs.id||Vs<-VsBag],
	continue_vs_pack(RoundList,Lv,[Id|VsInfo]).

%%====================================================升降级==================================================================
change_lv(Times,MaxLv)->
%% 	Times = check_times()-1,
%% 	MaxLv = get_lv_max(Times),
	LvList = lists:seq(1, MaxLv),
	{Change,Unchange} = change_lv_loop(LvList,[],[],Times,MaxLv),
	up_or_down(Change,Times,MaxLv),
	[un_change(Info,Times,MaxLv,Lv,[])||{Info,Lv}<-Unchange],
	%%同步玩家积分 
%% 	syn_war_award_remote(MaxLv),
%% 	award(Times,MaxLv),
	ok.

%%查找需要升降级的服务器
change_lv_loop([],Change,Unchange,_Times,_MaxLv)->{Change,Unchange};
change_lv_loop([Lv|LvList],Change,Unchange,Times,MaxLv)->
	{NewChange,NewUnchange} =
		if MaxLv=:= 1->
			   TeamInfo = db_agent:select_war_team_by_lv(Times,Lv,asc),
			   {[],[{TeamInfo,Lv}]};
		Lv =:= 1->%%{降级,保级}
			TeamInfo = db_agent:select_war_team_by_lv(Times,Lv,asc),
			Down1 = lists:nth(1,TeamInfo),
			Down2 = lists:nth(2,TeamInfo),
			spawn(fun()->msg(down,Times,MaxLv,Lv+1,[Down1,Down2])end),
			{[{Down1,Lv+1,down},{Down2,Lv+1,down}],
			 [{lists:nthtail(2, TeamInfo),Lv}]};
	   Lv =:= MaxLv->%%{升级,保级}
		   case db_agent:select_war_team_by_lv(Times,Lv,desc) of
			   []->{[],[]};
			   TeamInfo->
				   Up1 = lists:nth(1,TeamInfo),
				   Up2 = lists:nth(2,TeamInfo),
				   spawn(fun()->msg(up,Times,MaxLv,Lv-1,[Up1,Up2])end),
				   { [{Up1,Lv-1,up},{Up2,Lv-1,up}],
					 [{lists:nthtail(2, TeamInfo),Lv}]}
		   end;
	   true->%%{降级，升级，保级}
		   TeamInfo = db_agent:select_war_team_by_lv(Times,Lv,asc),
		   Len = length(TeamInfo),
		   TeamInfo1 = lists:nthtail(2, TeamInfo),
		   Down1 = lists:nth(1,TeamInfo),
		   Down2 =lists:nth(2,TeamInfo),
		   spawn(fun()->msg(down,Times,MaxLv,Lv+1,[Down1,Down2])end),
		   Up1 = lists:nth(Len,TeamInfo),
		   Up2 = lists:nth(Len-1,TeamInfo),
		   spawn(fun()->msg(up,Times,MaxLv,Lv-1,[Up1,Up2])end),
		  { [{Down1,Lv+1,down},{Down2,Lv+1,down},
			 {Up1,Lv-1,up},{Up2,Lv-1,up}],
			[{lists:nthtail(2, lists:reverse(TeamInfo1)),Lv}]}
	end,
	change_lv_loop(LvList,NewChange++Change,NewUnchange++Unchange,Times,MaxLv).

up_or_down([],_Times,_MaxLv)->
	ok;
up_or_down([Info|LvBag],Times,MaxLv)->
	%%{[85,<<"4399">>,13,<<"1313">>],2,up}
	{[Id,Platform,Sn,_Name],Lv,Type} = Info,
	db_agent:update_war_team([{lv,Lv}],[{id,Id}]),
	[Team] = select_war_team_by_id(Id),
	NewTeam = Team#ets_war_team{lv=Lv},
	update_war_team(NewTeam),
	spawn(fun()->msg_remote(Type,Times,MaxLv,Lv,Platform,Sn)end),
%% 	spawn(fun()->msg(Type,Times,Lv,Platform,Sn,Name)end),
	up_or_down(LvBag,Times,MaxLv).


un_change([],Times,MaxLv,Lv,BcInfo)->
	if BcInfo =/= []->
		spawn(fun()->msg(keep,Times,MaxLv,Lv,BcInfo)end);
	   true->skip
	end;
un_change([[Id,Platform,Sn,Name]|Info],Times,MaxLv,Lv,BcInfo)->
	spawn(fun()->msg_remote(keep,Times,MaxLv,Lv,Platform,Sn)end),
%% 	spawn(fun()->msg(keep,Times,Lv,Platform,Sn,Name)end),
	un_change(Info,Times,MaxLv,Lv,[[Id,Platform,Sn,Name]|BcInfo]).

msg(Type,Times,MaxLv,Lv,Info)->
	case Type of
		up->
			%%第XX届封神大会在经过多轮激烈的比赛后完满落幕，[XXX服][XXX服]成功升级！
			Content = io_lib:format("第<font color='#FEDB4F;'>~p</font>届封神大会在经过多轮激烈的比赛后完满落幕，~s成功升至~s",[Times,pack_info(Info),id_to_name(Lv,MaxLv)]);
		down->
			%%第XX届封神大会在经过多轮激烈的比赛后完满落幕，[XXX服][XXX服]遗憾降级！
			Content = io_lib:format("第<font color='#FEDB4F;'>~p</font>届封神大会在经过多轮激烈的比赛后完满落幕，~s遗憾降到~s！",[Times,pack_info(Info),id_to_name(Lv,MaxLv)]);
		_->
			%%第XX届封神大会在经过多轮激烈的比赛中完满落幕，[XXX服][XXX服]...保住X级的位置！
			Content = io_lib:format("第<font color='#FEDB4F;'>~p</font>届封神大会在经过多轮激烈的比赛后完满落幕，~s保住~s的位置",[Times,pack_info(Info),id_to_name(Lv,MaxLv)])
	end,
	lib_chat:broadcast_sys_msg(2,Content),
%% 	spawn(fun()->msg_remote(Type,Times,Lv,Platform,Sn)end),
	ok.

pack_info(Info)->
	lists:foldl(fun(R, Sum) ->
						[_,Platform,Sn,_] = R,
						Bin  = io_lib:format("[<font color='#FEDB4F;'>~s平台~p服</font>]",[platform(Platform),Sn]),
						Sum++Bin
				end,[], Info).

msg_remote(Type,Times,MaxLv,Lv,Platform,Sn)->
	case Type of
		up->
			%%第XX届封神大会在经过多轮激烈的比赛后完满落幕，本服代表队升到X级！
			Content = io_lib:format("第<font color='#FEDB4F;'>~p</font>届封神大会在经过多轮激烈的比赛后完满落幕，本服代表队升到<font color='#FEDB4F;'>~s</font>！",[Times,id_to_name(Lv,MaxLv)]);
		down->
			%%第XX届封神大会在经过多轮激烈的比赛后完满落幕，本服代表队降到X级！
			Content = io_lib:format("第<font color='#FEDB4F;'>~p</font>届封神大会在经过多轮激烈的比赛后完满落幕，本服代表队不幸降到<font color='#FEDB4F;'>~s</font>！",[Times,id_to_name(Lv,MaxLv)]);
		_->
			%%第XX届封神大会在经过多轮激烈的比赛中完满落幕，本服代表队保住X级的位置！
			Content = io_lib:format("第<font color='#FEDB4F;'>~p</font>届封神大会在经过多轮激烈的比赛中完满落幕，本服代表队保住<font color='#FEDB4F;'>~s</font>的位置！",[Times,id_to_name(Lv,MaxLv)])
	end,
	mod_leap_server:remote_server_msg_by_sn(Platform,Sn,Content).


%%######################以下的封神大会奖励取消，改成积分制
%%封神大会奖励
award(Times,MaxLv)->
	AwardInfo = award_lv_info(MaxLv),
	[award_by_lv(LvList,Times,GoodsNum)||{GoodsNum,LvList}<-AwardInfo],
	ok.

award_by_lv([],_Times,_GoodsNum)->ok;
award_by_lv([Lv|LvList],Times,GoodsNum)->
	TeamInfo = select_war_team(Times,Lv),
	NewTeamInfo = order_team(TeamInfo),
	award_by_sn(NewTeamInfo,Lv,GoodsNum,1),
	award_by_lv(LvList,Times,GoodsNum).

order_team(TeamInfo)->
	Team = [{Team#ets_war_team.platform,Team#ets_war_team.sn,Team#ets_war_team.point}||Team<-TeamInfo],
	SortFun = fun({_,_,P1}, {_,_,P2}) ->
		P1 > P2 
	end,	
	lists:sort(SortFun, Team).
award_by_sn([],_Lv,_GoodsNum,_)->ok;
award_by_sn([Info|InfoBag],Lv,GoodsNum,Mark)->
	{Platform,Sn,_} = Info,
	if Lv=:= 1->
		   case lists:member(Mark,[1,2]) of
			   true->Other=1;
			   false->Other = 0
		   end;
	   true->Other=0
	end,
	mod_leap_server:war_award(Platform,Sn,GoodsNum+Other,Other),
	award_by_sn(InfoBag,Lv,GoodsNum,Mark+1).

%%设所有级别数为N，则前N/3个级别队伍获得5个礼包，
%%中间N/3个级别队伍获得3个礼包，其余队伍获得1个礼包。（向下取整，如只有两个级别，则甲级获3个，乙级获1个）
award_lv_info(MaxLv)->
	if MaxLv =:=1->[{1,[1]}];
	   MaxLv =:=2->[{3,[1]},{1,[2]}];
	   true->
		   MaxList = lists:seq(1, MaxLv),
		   Num = MaxLv div 3,
		   Award5 = lists:seq(1, Num),
		   Award3 = lists:flatmap(fun(X)->[X+Num] end, Award5),
		   Award1 = lists:nthtail(Num*2, MaxList),
		   [{5,Award5},{3,Award3},{1,Award1}]
	end.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%进入休息区%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%比赛区出生点：红（16,85）蓝（54,29）
enter_war_scene(PlayerStatus,SceneId)->
	case is_war_scene(SceneId)of
		false->
			init_wait_scene(PlayerStatus,1);
		true->
			case is_wait_scene(SceneId) of
				true->
				   init_wait_scene(PlayerStatus,2);
			   false->
				   init_fight_scene(PlayerStatus,SceneId)
			end
	end.

init_wait_scene(PlayerStatus,Type)->
	case mod_war_supervisor:get_wait_server_pid(PlayerStatus#player.id) of
		{ok,[undefined,undefined]}->
			case Type of
				1->PlayerStatus;
				_->PlayerStatus#player{scene = 300,x = 68,y = 211}
			end;
		{ok,[Pid,SceneId]}->
			PlayerStatus#player{scene = SceneId,
								x = 22,
								y = 53,
								mount = 0,
								carry_mark = 0,
								hp = PlayerStatus#player.hp_lim,
								mp = PlayerStatus#player.mp_lim,
								other = PlayerStatus#player.other#player_other{pid_dungeon = Pid}}
	end.

init_fight_scene(PlayerStatus,SceneId)->
	case mod_war_supervisor:get_scene_server_pid(SceneId) of
		{ok,[undefined]}->init_wait_scene(PlayerStatus,2);
		{ok,[Pid]}->
			%%检查战斗场景进程是否是活的,死的就把玩家传送到休息区
			case misc:is_process_alive(Pid) of
				true->
					catch case gen_server:call(Pid,{'get_color',PlayerStatus#player.id}) of
						{ok,[Mark,_State]} ->
							[X, Y] =
								case Mark of
									%% 红
									11 ->
										[16,85];
									%% 蓝
									12 ->
										[54,29];
									_ ->
										[39, 49]
								end,
						gen_server:cast(Pid,{'WAR_ENTER_LEAVE',PlayerStatus#player.id,in,PlayerStatus#player.other#player_other.pid_send,PlayerStatus#player.other#player_other.pid,PlayerStatus#player.other#player_other.leader,PlayerStatus#player.carry_mark}),
						PlayerStatus#player{x = X,
											y =Y,
											carry_mark = 0,
											mount = 0,
											other = PlayerStatus#player.other#player_other{leader = Mark,
																						   pid_dungeon = Pid}};
						 _->init_wait_scene(PlayerStatus,1)
					end;
				false->
					init_wait_scene(PlayerStatus,1)
			end
	end.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%第**轮封神大会开始%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%比赛区出生点比赛区出生点：红（16,85）蓝（54,29）
war_start(Player,Times,_Level, Round,SceneId,X,Y,Color,WarPid)->
	%%告诉原场景的玩家你已经离开
	pp_scene:handle(12004, Player, Player#player.scene),
	%%更新大会信息，缺坐标
	NewPlayer = Player#player{
							  scene = SceneId,
							  x=X,
							  y=Y,
							  hp = Player#player.hp_lim,
							  mp = Player#player.mp_lim,
							  carry_mark = 0,
							  other = Player#player.other#player_other{
																	   leader = Color,
																	   pid_dungeon = WarPid,
																	   battle_limit = 0		
																	  
																	  }							  
							 },
	%% 坐标记录
	put(change_scene_xy, [X, Y]),
	{ok, BinData} = pt_12:write(12005, [SceneId, X, Y, <<>>, 750, 0, 0, Color]),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
	mod_player:save_online_info_fields(NewPlayer, [{carry_mark,0},{scene,SceneId},{x,X},{y,Y},{leader, Color}, 
												   {hp,Player#player.hp_lim},{mp,Player#player.mp_lim},{pid_dungeon, WarPid}]),
	lib_war:timestamp_bc(Player,3,Round,600),
	Msg = io_lib:format("第~p届封神大会第~p轮战斗开始，为本服的荣誉努力吧，勇士们！", [Times,Round]),
	{ok, MsgBinData} = pt_11:write(11080, 2, Msg),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, MsgBinData),
	lib_player:send_player_attribute(NewPlayer, 2),
	NewPlayer.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%*轮分组赛结束，返回休息区%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
war_finish(PlayerStatus,Pid,SceneId)->
	if PlayerStatus#player.carry_mark ==26->
		   %%通知所有玩家
		   {ok,BinData2} = pt_12:write(12041,[PlayerStatus#player.id,0]),
		   mod_scene_agent:send_to_area_scene(PlayerStatus#player.scene,PlayerStatus#player.x,PlayerStatus#player.y, BinData2);
	   true->skip
	end,
	[X,Y] = [22,53],
	NewPlayer = PlayerStatus#player{scene = SceneId,
						x = X,
						y = Y,
						hp = PlayerStatus#player.hp_lim,
						mp = PlayerStatus#player.mp_lim,
						carry_mark = 0,
						other = PlayerStatus#player.other#player_other{ 
																	   battle_limit = 0,
																	   leader = 0,
																	   titles=[],
																	   pid_dungeon = Pid}},
	mod_player:save_online_info_fields(NewPlayer, [{scene,SceneId},{x, X}, {y, Y},{carry_mark,0},
												   {hp,PlayerStatus#player.hp_lim},{mp,PlayerStatus#player.mp_lim},
												    {title,[]},{leader,0},{battle_limit, 0}]),
	put(change_scene_xy, [X, Y]),
	{ok, BinData} = pt_12:write(12005, [SceneId, X, Y, <<>>, 760, 0, 0, 0]),
   	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	timestamp_bc(PlayerStatus,1,0,300),
	NewPlayer1 = lib_player:count_player_speed(NewPlayer),
	lib_player:send_player_attribute(NewPlayer1, 2),
	NewPlayer1.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%战场称号%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
war_title(PlayerStatus,Type,TitleId) ->
	case Type of
		get->
			Title = to_title_id(TitleId),
			NewPlayerStatus =PlayerStatus#player{
						other = PlayerStatus#player.other#player_other{
                           		titles = [Title]
								}
                    		},
			mod_player:save_online_info_fields(NewPlayerStatus, [{titles,[Title]}]),
			NewPlayerStatus;
		lose->
			NewPlayerStatus =PlayerStatus#player{
						other = PlayerStatus#player.other#player_other{
                           		titles=[]
								}
                    		},
			mod_player:save_online_info_fields(NewPlayerStatus, [{titles,[]}]),
			NewPlayerStatus;
		_->PlayerStatus
	end.

to_title_id(TypeId)->
	case TypeId of
		3->1;
		4->2;
		5->3;
		6->4;
		7->5;
		8->6;
		9->7;
		_->8
	end.
%%
%% Local Functions
%%
%%查找所有玩家信息
select_war_player_all()->
	ets:tab2list(?ETS_WAR_PLAYER).
%%根据玩家id查找玩家信息
select_war_player(PlayerId)->
	ets:match_object(?ETS_WAR_PLAYER, #ets_war_player{pid=PlayerId,_='_'}).
%%更新服务器号查找玩家信息
select_war_player_by_sn(Platform,Sn)->
	ets:match_object(?ETS_WAR_PLAYER, #ets_war_player{platform=Platform,sn=Sn,_='_'}).
%%更新服务器和届查询玩家信息
select_war_player_by_times(Platform,Sn,Times)->
	ets:match_object(?ETS_WAR_PLAYER, #ets_war_player{platform=Platform,sn=Sn,times=Times,_='_'}).
%%查找已报名玩家
select_war_player_sign_up()->
	ets:match_object(?ETS_WAR_PLAYER, #ets_war_player{sign_up=1,_='_'}).
%%更新玩家信息
update_war_player(WarPlayer)->
	ets:insert(?ETS_WAR_PLAYER, WarPlayer).
%%清除玩家信息
delete_war_player()->
	ets:delete_all_objects(?ETS_WAR_PLAYER).

delete_war_player_one(Id)->
	ets:delete(?ETS_WAR_PLAYER, Id).

%%查找队伍信息
select_war_team_by_id(Id)->
	ets:lookup(?ETS_WAR_TEAM, Id).
%%根据届查找队伍信息
select_war_team(Times)->
	ets:match_object(?ETS_WAR_TEAM,#ets_war_team{times=Times,_='_'}).
%%加载所有队伍信息
select_war_team_all()->
	ets:tab2list(?ETS_WAR_TEAM).
%%根据届和级别查找队伍信息
select_war_team(Times,Lv)->
	ets:match_object(?ETS_WAR_TEAM,#ets_war_team{times=Times,lv=Lv,_='_'}).
%%更新届查找队伍信息
select_war_team_by_times(Times)->
	ets:match_object(?ETS_WAR_TEAM,#ets_war_team{times=Times,_='_'}).
%%更加服务器id和届查找队伍信息
select_war_team_by_sn(Platform,Sn,Times)->
	ets:match_object(?ETS_WAR_TEAM,#ets_war_team{platform=Platform,times=Times,sn=Sn,_='_'}).
%%更新队伍信息
update_war_team(Team)->
	ets:insert(?ETS_WAR_TEAM, Team).
%%清除队伍信息
delete_war_team()->
	ets:delete_all_objects(?ETS_WAR_TEAM).
delete_war_team(Times)->
	ets:match_delete(?ETS_WAR_TEAM, #ets_war_team{times=Times,_='_'}).

%%查找队伍对战信息
select_war_vs_all()->
	ets:tab2list(?ETS_WAR_VS).

select_war_vs_by_round(Round)->
	ets:match_object(?ETS_WAR_VS, #ets_war_vs{round=Round,_='_'}).

select_war_vs_by_lv(Lv,Round)->
	ets:match_object(?ETS_WAR_VS, #ets_war_vs{round=Round,lv=Lv,_='_'}).

select_war_vs(Id)->
	ets:lookup(?ETS_WAR_VS, Id).

update_war_vs(VsInfo)->
	ets:insert(?ETS_WAR_VS, VsInfo).

delete_war_vs()->
	ets:delete_all_objects(?ETS_WAR_VS).


%%查找玩家积分
check_war_award(PlayerId)->
	ets:lookup(?ETS_WAR_AWARD, PlayerId).

%%更新积分
update_war_award(Award)->
	ets:insert(?ETS_WAR_AWARD, Award).

%%查询大会状态
select_war_state()->
	case db_agent:select_war_state()of
		[]->
			db_agent:insert_war_state(),
			{0,1,0,1,1,1};
		[Type,Times,State,Lv,Round,MaxRound]->
			{Type,Times,State,Lv,Round,MaxRound}
	end. 

%%更新大会状态
update_war_state(KeyList,ValueList)->
	db_agent:update_war_state(KeyList,ValueList),
	ok.

%%计算已报名人数
get_sign_up_nums()->
	Members = ets:match_object(?ETS_WAR_PLAYER, #ets_war_player{sign_up=1,_='_'}),
	length(Members).

%%计算邀请人数
get_invite_nums()->
	Members = ets:match_object(?ETS_WAR_PLAYER, #ets_war_player{is_invite=1,sign_up = 0,_='_'}),
	length(Members). 

%%查询第几届
check_times()->
	Record = select_war_team_all(),
	TimesList = [Team#ets_war_team.times||Team<-Record],
	case TimesList of
		[]->
			case db_agent:select_war_team_all() of
				[]->1;
				Team1->
					TimesList1 = [Times||[_,_,_,_,_,_,Times|_]<-Team1],
					lists:max(TimesList1)+1
			end;
		_->
			lists:max(TimesList)+1
	end.



%%检查报名时间
check_sign_up_time()->
	TodaySec = util:get_today_current_second(),
	SIGNUP_FIRST =?WAR_SIGN_UP_OPEN,
	SIGNUP_END = ?WAR_SIGN_UP_CLOSE,  
%%	IsSignUp_Test = true,
%%	if IsSignUp_Test->signup_fir;
%%	   true->
			case is_war_week() of
				true->
					if TodaySec >= SIGNUP_FIRST andalso SIGNUP_END>=TodaySec->
				   		signup_fir;
	  				 true->	signup_no 
					end;
				false->signup_no
%%			end
	end.
		  


%%甲、乙、丙、丁、戊、己、庚、辛、壬、癸
id_to_name(Lv) ->
	case Lv of
		1->"甲";
		2->"乙";
		3->"丙";
		4->"丁";
		5->"戊";
		6->"己";
		7->"庚";
		8->"辛";
		9->"壬";
		10->"癸";
		_->"子"
	end.

%% yuengufs => "香港"
%% cmwebgame => "台湾"
%% duowan => "多玩"
%% kuwo => "酷我"
platform(Name)->
	case Name of
		<<"yuengufs">>->"香港";
		<<"cmwebgame">>->"臺灣";
		<<"duowan">>->"多玩";
		<<"kuwo">>->"酷我";
		_->Name
	end.

id_to_name(Lv,MaxLv)->
	{MidList,PriStart,_PriList} = lv_to_team(MaxLv),
	case Lv of
		1->"冠军组";
		_->
			case lists:member(Lv,MidList) of
				true->
					io_lib:format("中级~p组",[Lv-1]);
				false->
					io_lib:format("初级~p组",[Lv-PriStart+1])
			end
	end.

lv_to_team(MaxLv)->
	Mid = round((MaxLv-1)*0.6),
	MidList = lists:seq(2,Mid+1),
	PriList = lists:seq(Mid+2,MaxLv),
	{MidList,Mid+2,PriList}.

%%获取服务器开放时间
check_enter_time()->
	InitTime = round(?WAR_ENTER_OPEN+1),
	EndTime = round(?WAR_ENTER_OPEN+2*3600+30*60),
	TodaySec = util:get_today_current_second(),
	case is_war_week() of
		true->
			case TodaySec > InitTime andalso TodaySec < EndTime of
				true-> 
					{ok,round(EndTime-TodaySec)};
				false->
					{error,4}
			end;
		false->
			{error,4}
	end.

notice_war_state(PlayerStatus)->
	case PlayerStatus#player.lv >= 20 of
		false->skip;
		true->
			TodaySec = util:get_today_current_second(),
			SIGNUP_FIRST =?WAR_SIGN_UP_OPEN,
			SIGNUP_END =  round(?WAR_ENTER_OPEN+2*3600),
			case is_war_week() of
				true->
					if TodaySec>SIGNUP_END orelse  TodaySec < SIGNUP_FIRST ->skip;
			   		true->
						case config:get_war_server_info() of
							[_,_,1,_,_]->
%% 								mod_war_supervisor:notice_enter_war(PlayerStatus),
				   				timestamp_bc(PlayerStatus,0,0,0);
							_->skip
						end
					end;
				false->skip
			end
	end.

notice_war_state_all(Type)->
	case is_war_week() of
		true->
			{ok,BinData} = pt_45:write(45014,[Type,1,100]),
			mod_disperse:broadcast_to_world(ets:tab2list(?ETS_SERVER), BinData);
		false->skip
	end.

notice_enter_war(Status)->
	case lib_war:select_war_player(Status#player.id) of
		[]->skip;
		[Info]->
			if Info#ets_war_player.sign_up >= 1->
				   notice_msg(Status),
				   ok;
			   true->skip
			end
	end.

notice_msg(Status)->
	{ok,BinData} = pt_45:write(45021,[1]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData).

notice_enter_war_all()->
	PlayerBag = select_war_player_all(),
	notice_enter_war_all_loop(PlayerBag),
	ok.

notice_enter_war_all_loop([])->ok;
notice_enter_war_all_loop([P|PlayerBag])->
	if P#ets_war_player.sign_up >0->
		   case lib_player:get_online_info(P#ets_war_player.pid) of
			[]->skip;
			Player->
				notice_msg(Player),
		   ok
			   end;
	   true->skip
	end,
	notice_enter_war_all_loop(PlayerBag).

%%系统邮件
mail_notice_sign_up(NickName)->
	%%恭喜！你获得封神大会的报名资格！请在本周日14:00前到封神大会负责人处报名确认。
	NameList = [tool:to_list(NickName)],
	Content = "恭喜！你获得封神大会的报名资格！报名时间是周日的14:00~15:20,请前往九霄封神大会负责人处报名确认。",
	mod_mail:send_sys_mail(NameList, "封神大会", Content, 0,0, 0, 0, 0).
%%
mail_sign_up_ok(NickName)->
	%%恭喜！你获得封神大会的参赛资格！请在本周日15:30前到九霄封神大会负责人处进入封神大会专服参加比赛。
	NameList = [tool:to_list(NickName)],
	Content = "恭喜！你获得封神大会的参赛资格！请在周日15:30后前往九霄封神大会负责人处进入封神大会专服参加比赛。",
	mod_mail:send_sys_mail(NameList, "封神大会", Content, 0,0, 0, 0, 0).

mail_notice_invite(NickName,InviteName)->
	%%    恭喜！你受到XXXX的邀请获得封神大会的报名资格！请在15:30前到封神大会负责人处报名确认。
	NameList = [tool:to_list(NickName)],
	Content =io_lib:format( "恭喜！你受到【~s】的邀请获得封神大会的报名资格！请在周日15:20前前往封神大会负责人处报名确认。",[InviteName]),
	mod_mail:send_sys_mail(NameList, "封神大会", Content, 0,0, 0, 0, 0).

mail_notice_transfer(NickName,InviteName)->
	%%玩家【XX】把封神大会的参赛资格转让于你，请在本周日14:00前到封神大会负责人处确认是否报名。
	NameList = [tool:to_list(NickName)],
	Content =io_lib:format( "玩家【~s】把封神大会的参赛资格转让于你，请在周日15:20前到封神大会负责人处确认。",[InviteName]),
	mod_mail:send_sys_mail(NameList, "封神大会", Content, 0,0, 0, 0, 0).

%% 播放连续击杀信息
bc_double_hit_msg(Platform,ServerId,PlayerId, NickName, Career, Sex, Kill) ->
	if
		Kill > 2 ->
			Msg = 
				case Kill of
					3 ->
						"正在大杀特杀";
                    4 ->
						"已经主宰比赛了";
					5 ->
						"正在疯狂杀戮！";
					6 ->
						"已经无人能挡了";
					7 ->
						"正在变态杀戮！";
					8 ->
						"已经像妖怪一样了！";
					9 ->
						"已经如神一般了！";
					10 ->
						"已经超神！！！拜托谁杀了他吧";
					_ ->
						case Kill > 10 andalso Kill rem 2 == 0 of 
							true ->
								"已经超神了！！！拜托谁杀了他吧";
							false ->
								[]
						end
				end,
			case Msg of
				[] ->
					skip;
				_ ->
					NewMsg = io_lib:format("<font color='#FEDB4F;'>~s</font>平台<font color='#FEDB4F;'>~p</font>服的勇士<a href='event:1, ~p, ~s, ~p, ~p'><font color='#FEDB4F'>~s</font></a> 连续击杀了 <font color='#FEDB4F;'>~p</font> 人， ~s！", [platform(Platform),ServerId,PlayerId, NickName, Career, Sex, NickName, Kill, Msg]),
					lib_chat:broadcast_sys_msg(6, NewMsg),
					spawn(fun()->mod_leap_server:remote_server_msg_by_sn(Platform,ServerId,NewMsg)end)
			end;
		true ->
			skip
	end.


war_award(_PlayerId,NickName,GoodsNum,_Other)->
%% 	case db_agent:check_war_player(PlayerId) of
%% 		[]->skip;
			GoodsId= 28812,
			NameList = [tool:to_list(NickName)],
			Title = "封神大会",
			Content ="尊敬的玩家，您的服务器参加了本届封神大会并获得了冠军组第一名，感谢您对封神大会的支持！",
			mod_mail:send_sys_mail(NameList, Title, Content, 0, GoodsId, GoodsNum, 0,0).
%% %% 		_->
%% 			GoodsId = 28811,
%% 			NameList = [tool:to_list(NickName)],
%% 			Title = "封神大会",
%% 			Content ="尊敬的玩家，请收取您的封神大会比赛奖励，感谢参加本届封神大会!",
%% 			mod_mail:send_sys_mail(NameList, Title, Content, 0, GoodsId, GoodsNum, 0,0).
%% %% 	end.

%%VIP领取药品标记重置
reset_vip_drug_loop()->
	PlayerBag = select_war_player_all(),
	[reset_vip_drug(PlayerInfo)||PlayerInfo<-PlayerBag].

reset_vip_drug(PlayerInfo)->
	NewInfo = PlayerInfo#ets_war_player{drug=0},
	update_war_player(NewInfo),
	db_agent:update_war_player([{drug,0}],[{pid,PlayerInfo#ets_war_player.pid}]).

%%1成功，2只有前两轮才能领取药品 3你没有资格领取药品，4领取药品次数到到上限，5你不是VIP不能领取，6背包已满，不能领取,7该轮已经领取过
get_vip_drug(PlayerStatus,Round,MaxRound)->
	case check_drug(PlayerStatus#player.id,Round,MaxRound) of
		{1,Info}->
			case give_drup(PlayerStatus)of
				1->
					NewInfo = Info#ets_war_player{drug=1},
					update_war_player(NewInfo),
					db_agent:update_war_player([{drug,1}],[{pid,PlayerStatus#player.id}]),
					1;
				R->R
			end;
		{Other,_}->Other
	end.

check_drug(PlayerId,Round,MaxRound)->
	if Round > MaxRound ->{2,null};
	   true->
			case select_war_player(PlayerId) of
				[]->{3,null};
				[Info]->
					if Info#ets_war_player.drug > 0 -> {4,null};
					   			true->{1,Info}
							end
			end
	end.

give_drup(PlayerStatus)->
	case PlayerStatus#player.vip =:= 0 of
		true->5;
		false->
			case gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
										  		{'cell_num'})<1 of
				false->
					{GoodsId,GoodsNum} = goods_info(PlayerStatus#player.vip),
					case (catch gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'give_goods', PlayerStatus, GoodsId, GoodsNum,2}))of
						ok->1;
						_->7
					end;
				true->6
			end
	end.
goods_info(Vip)->
	case Vip of
		1->{31048,1};%%月卡，初级
		2->{31048,1};%%季卡，中级
		3->{31021,1};%%半年卡，高级
		_->{31048,1}%%周卡，初级
	end.
exit_war(PlayerId)->
	case select_war_player(PlayerId) of
		[]->
			case lib_war2:ets_select_war2_record(PlayerId) of
				[]->error;
				[R]->			
					Platform = tool:to_list(R#ets_war2_record.platform),
					ServerList = config:get_war_client_info(),
					case get_client_ip(ServerList,Platform,R#ets_war2_record.sn) of
						[]->error;
						[Ip,Port]->
							{ok,Ip,Port}
					end
			end;
		
		[Info]->
			Platform = tool:to_list(Info#ets_war_player.platform),
%% 			if Info#ets_war_player.sn =:= 1->
%% 				   {ok,"121.9.242.238",7777};
%% 			   true->{ok,"121.9.242.238",7778}
%% 			end
			ServerList = config:get_war_client_info(),
%% 			case db_agent:select_server_ip(Platform,Info#ets_war_player.sn) of
			case get_client_ip(ServerList,Platform,Info#ets_war_player.sn) of
				[]->error;
				[Ip,Port]->
					{ok,Ip,Port}
			end
	end.
get_client_ip([],_,_)->[];
get_client_ip([Server|ServerList],Platform,Sn)->
	{NewPlatform,NewSn,Ip,Port,_State} = Server,
	if NewPlatform =:= Platform andalso NewSn =:= Sn ->
		   [Ip,Port];
	  true->
		  get_client_ip(ServerList,Platform,Sn)
	end.

%%%检查玩家装备属性
check_player_equip()->
	PlayerBag = select_war_player_all(),
	check_equip(PlayerBag).

check_equip([])->ok;
check_equip([P|PlayerBag])->
	case db_agent:check_equip_att(P#ets_war_player.pid) of
		[]->
%% 			io:format("Info>>~p/~p/~p~n",[P#ets_war_player.platform,P#ets_war_player.sn,P#ets_war_player.nickname]),
			mod_leap_server:syn_equip(P#ets_war_player.platform,P#ets_war_player.sn,P#ets_war_player.nickname),
			ok; 
		_->skip
	end,
	check_equip(PlayerBag).

update_to_team(Id,PlayerId,NickName,Career,Realm,Lv,Sex,Vip,Att,Platform1,Sn,Times)->
	Platform = tool:to_binary(Platform1),
	case select_war_team_by_sn(Platform,Sn,Times) of
		[]->skip3;
		[TeamBag]->
			Team = {PlayerId,NickName,Career,Realm,Lv,Sex,Vip,Att},
			NewTeam = [Team|TeamBag#ets_war_team.team],
			NewTeamBag = TeamBag#ets_war_team{team=NewTeam},
			update_war_team(NewTeamBag),
			db_agent:update_war_team([{team,util:term_to_string(NewTeam)}],[{id,TeamBag#ets_war_team.id}]),
			ets:insert(?ETS_WAR_PLAYER, #ets_war_player{id=Id,pid=PlayerId,nickname=NickName,realm=Realm,career=Career,sex=Sex,level=Lv,platform = Platform,sn=Sn,times=Times}),
			ok
	end,
	ok.

%%修改积分
set_war_award(PlayerId,Type,Value)->
	case check_war_award(PlayerId) of
		[]->
			NowTime = util:unixtime(),
			{_,Id} = db_agent:new_war_award(PlayerId,Value,NowTime),
			ets:insert(?ETS_WAR_AWARD, #ets_war_award{id=Id,pid=PlayerId,point=Value,timestamp=NowTime}),
			ok;
		[Award]->
			P = case Type of
					2->
						if Award#ets_war_award.point-Value < 0->
							   0;
						   true->Award#ets_war_award.point-Value
						end;
					_->
						Award#ets_war_award.point+Value
				end,
			NewAward = Award#ets_war_award{point = P},
			update_war_award(NewAward),
			db_agent:update_war_award([{point,P}],[{pid,PlayerId}]),
			ok
	end.

%%查询积分
get_war_award_point(PlayerId)->
	case is_war_server()of
		false->
			case check_war_award(PlayerId) of
				[]->0;
				[Award]->
					Award#ets_war_award.point
			end;
		true->
			case select_war_player(PlayerId) of
				[]->0;
				[P]->P#ets_war_player.point
			end
	end.
			
%%积分兑换物品(1兑换成功，2不能兑换该物品，3积分不足，4背包空间不足，5系统繁忙，稍后重试)
change_goods(Status,GoodsId,Num)->
	case lists:member(GoodsId,[28811,32026,32027,32021,23501,23300,23301,28054]) andalso  Num =/=0 of
		false->{2,get_war_award_point(Status#player.id)};
		true->
			case check_war_award(Status#player.id) of
				[]->{3,0};
				[Award]->
					TotalP =goods_to_point(GoodsId,Num),
					case Award#ets_war_award.point >= TotalP of
						false->{3,Award#ets_war_award.point};
						true->
							case gen_server:call(Status#player.other#player_other.pid_goods,{'cell_num'})< 1 of
								false->
									case ( catch gen_server:call(Status#player.other#player_other.pid_goods,
																 {'give_goods', Status,GoodsId,Num,2})) of
										ok ->
											P = Award#ets_war_award.point-TotalP,
											NewAward = Award#ets_war_award{point = P},
											update_war_award(NewAward),
											db_agent:update_war_award([{point,P}],[{pid,Status#player.id}]),
											spawn(fun()->db_agent:log_war_award(Status#player.id,GoodsId,Num,2,TotalP,util:unixtime())end),
											{1,P};
										_->{5,Award#ets_war_award.point}
									end;
								_true->{4,Award#ets_war_award.point}
							end
					end
			end
			
	end.
goods_to_point(GoodsId,Num)->
	case GoodsId of
		28811 -> 70*Num;%%跨服礼包
		32026 -> 20*Num;%%熟练丹
		32027 -> 50*Num;%%太虚石
		32021 -> 150*Num;%%品质石
		23501 ->70*Num;%%小修为丹
		23300 -> 35* Num;%%小灵力丹
		23301 -> 70*Num;%%	中灵力丹
		28054 -> 550*Num;%%霸者勋章
		_->0
	end.

get_mvp(PlayerBag)->
%% 	PlayerBag = lib_war:select_war_player_all(),
	case mvp_loop(PlayerBag,[]) of
		[]->[];
		Member->
%% 			NewPoint = round(Member#ets_war_player.point*(1+0.3)),
%% 			NewMember = Member#ets_war_player{point=NewPoint},
%% 			lib_war:update_war_player(NewMember),
%% 			db_agent:update_war_player([{point,NewPoint}],[{pid,NewMember#ets_war_player.pid}]),
			%%“恭喜玩家[XXXX]凭借着其在封神大会比赛中的出色表现，成为本届封神大会MVP！”
			Msg = io_lib:format("<font color='#FEDB4F;'>恭喜~s平台~p服玩家[~s]凭借着其在封神大会比赛中的出色表现，成为本届封神大会MVP！</font>",[platform(Member#ets_war_player.platform),Member#ets_war_player.sn,Member#ets_war_player.nickname]),
			lib_chat:broadcast_sys_msg(2,Msg),
			mod_leap_server:remote_server_msg(Msg),
			Member
	end.

mvp_loop([],Member)->Member;
mvp_loop([M|PBag],Member)->
	case Member of
		[]->mvp_loop(PBag,M);
		_->
			if M#ets_war_player.kill > Member#ets_war_player.kill ->
				   mvp_loop(PBag,M);
			   true-> mvp_loop(PBag,Member)
			end
	end.

%%发放总积分
syn_war_award_remote(Times,MaxLv)->
	PlayerBag = select_war_player_all(),
	%%级别加成
	NewMember = team_lv_add_loop(PlayerBag,MaxLv,[]),
	%%mvp积分
	Mvp=get_mvp(NewMember),
	%%总冠军
	{First,Second} = get_the_champion(Times),
	syn_war_award_remote_loop(NewMember,MaxLv,First,Second,Mvp),
	ok.


syn_war_award_remote_loop([],_,_,_,_)->ok;
syn_war_award_remote_loop([P|PlayerBag],MaxLv,First,Second,Mvp)->
	war_award_remote(MaxLv,P,Mvp,First,Second),
	syn_war_award_remote_loop(PlayerBag,MaxLv,First,Second,Mvp).


war_award_remote(MaxLv,Member,Mvp,{FirstPlatform,FirstSn,_},{SecondPlatform,SecondSn,_})->
	if Member#ets_war_player.platform =:= FirstPlatform andalso Member#ets_war_player.sn =:= FirstSn ->
		   if Member =:= Mvp ->
				  ActP = activity(MaxLv,Member),
				  MvpPoint = round(Member#ets_war_player.point*0.15),
				  ChamP = 30*MaxLv,
				  Total = ActP+MvpPoint+ChamP+Member#ets_war_player.point,
				  Content = io_lib:format("亲爱的玩家，您在本届比赛中一共获得封神大会声望~p分,其中比赛获得奖励声望~p分，活跃度奖励声望~p分,总MVP奖励声望~p分，冠军组第一名奖励声望~p分。下一届封神大会期待您的继续参与！",[Total,Member#ets_war_player.point,ActP,MvpPoint,ChamP]);
			  true->
				  ActP = activity(MaxLv,Member),
				  ChamP =  30*MaxLv,
				  Total = ActP+ChamP+Member#ets_war_player.point,
				  Content = io_lib:format("亲爱的玩家，您在本届比赛中一共获得封神大会声望~p分,其中比赛获得奖励声望~p分，活跃度奖励声望~p分,冠军组第一名奖励声望~p分。下一届封神大会期待您的继续参与！",[Total,Member#ets_war_player.point,ActP,ChamP])
		   end;
	   Member#ets_war_player.platform =:= SecondPlatform andalso Member#ets_war_player.sn =:= SecondSn ->
		   if Member =:= Mvp ->
				  ActP = activity(MaxLv,Member),
				  MvpPoint = round(Member#ets_war_player.point*0.15),
				  ChamP = 10*MaxLv,
				  Total = ActP+MvpPoint+ChamP+Member#ets_war_player.point,
				  Content = io_lib:format("亲爱的玩家，您在本届比赛中一共获得封神大会声望~p分,其中比赛获得奖励声望~p分，活跃度奖励声望~p分,总MVP奖励声望~p分，冠军组第二名奖励声望~p分。下一届封神大会期待您的继续参与！",[Total,Member#ets_war_player.point,ActP,MvpPoint,ChamP]);
			  true->
				  ActP = activity(MaxLv,Member),
				  ChamP = 10*MaxLv,
				  Total = ActP+ChamP+Member#ets_war_player.point,
				  Content = io_lib:format("亲爱的玩家，您在本届比赛中一共获得封神大会声望~p分,其中比赛获得奖励声望~p分，活跃度奖励声望~p分,冠军组第二名奖励声望~p分。下一届封神大会期待您的继续参与！",[Total,Member#ets_war_player.point,ActP,ChamP])
		   end;
	   true->
		   if Member =:= Mvp ->
				  ActP = activity(MaxLv,Member),
				  MvpPoint = round(Member#ets_war_player.point*0.15),
				  Total = ActP+MvpPoint+Member#ets_war_player.point,
				  Content = io_lib:format("亲爱的玩家，您在本届比赛中一共获得封神大会声望~p分,其中比赛获得奖励声望~p分，活跃度奖励声望~p分,总MVP奖励声望~p分。下一届封神大会期待您的继续参与！",[Total,Member#ets_war_player.point,ActP,MvpPoint]);
			  true->
				  ActP = activity(MaxLv,Member),
				  Total = ActP+Member#ets_war_player.point,
				  Content = io_lib:format("亲爱的玩家，您在本届比赛中一共获得封神大会声望~p分,其中比赛获得奖励声望~p分，活跃度奖励声望~p分。下一届封神大会期待您的继续参与！",[Total,Member#ets_war_player.point,ActP])
		   end
	end,
	mod_leap_server:syn_award_to_remore(Member#ets_war_player.platform,Member#ets_war_player.sn,Member#ets_war_player.nickname,Total,Content).


team_lv_add_loop([],_MaxLv,NewMember)->NewMember;
team_lv_add_loop([M|Member],MaxLv,NewMember)->
	N = MaxLv-M#ets_war_player.lv+1,
	TeamPoint = 20+5 * N,
	NewPoint = round(M#ets_war_player.point+TeamPoint),
	NewM = M#ets_war_player{point=NewPoint},
	lib_war:update_war_player(NewM),
	db_agent:update_war_player([{point,NewPoint}],[{pid,NewM#ets_war_player.pid}]),
	team_lv_add_loop(Member,MaxLv,[NewM|NewMember]).

%%冠军组额外加分
get_the_champion(Times)->
	TeamBag = select_war_team(Times,1),
	TeamInfo = [{Team#ets_war_team.platform,Team#ets_war_team.sn,Team#ets_war_team.point}||Team<-TeamBag],
	SortFun = fun({_,_,P1}, {_,_,P2}) ->
		P1 > P2 
	end,	
	NewTeamInfo = lists:sort(SortFun, TeamInfo),
	{Platform,Sn,P} = lists:nth(1, NewTeamInfo),
	mod_leap_server:war_award(Platform,Sn,1,0),
	Second = lists:nth(2, NewTeamInfo),
	{{Platform,Sn,P},Second}.



%%活跃度目标：攻击战旗（非夺得）10次，击倒玩家3人
%%活跃度完成率：攻击战旗1次+7%，击倒一个玩家+10%
%5活跃度声望奖励上限 = 100*N/3（N同上），最低值为100
%%玩家实际获得活跃度声望=上限*完成率
activity(MaxLv,Member)->
	N = MaxLv-Member#ets_war_player.lv+1,
	AttFlag = case Member#ets_war_player.att_flag >= 10 of
			   true-> 10*0.07;
			   false->Member#ets_war_player.att_flag*0.07
		   end,
	Kill = case Member#ets_war_player.kill >=3 of
			   true-> 3*0.1;
			   false->Member#ets_war_player.kill*0.1
		   end,
	round((150 + 15 * (N-1))  * ( AttFlag + Kill )).

%%同步积分 
syn_war_award(NickName,Point,Content)->
	case ?DB_MODULE:select_one(war_player, "pid", [{nickname, NickName}]) of
		null->ok;
		PlayerId->
			NowTime = util:unixtime(),
			case check_war_award(PlayerId) of
				[]->
					{_,Id} = db_agent:new_war_award(PlayerId,Point,NowTime),
					ets:insert(?ETS_WAR_AWARD, #ets_war_award{id=Id,pid=PlayerId,point=Point,timestamp=NowTime}),
					ok;
				[Award]->
					P = Award#ets_war_award.point+Point,
					NewAward = Award#ets_war_award{point = P},
					update_war_award(NewAward),
					db_agent:update_war_award([{point,P}],[{pid,PlayerId}]),
					ok
			end,
			spawn(fun()->db_agent:log_war_award(PlayerId,0,0,1,Point,NowTime)end),
			mail_point(NickName,Content)
	end.

mail_point(NickName,Content)->
	NameList = [tool:to_list(NickName)],
	Title = "封神大会",
	mod_mail:send_sys_mail(NameList, Title, Content, 0, 0, 0, 0,0),
	ok.

%%%%%%%%%%%%%%
update_to_team_test(PlayerId,NickName,Career,Realm,Lv,Sex,Vip,Att,Platform1,Sn,Times)-> 
	Platform = tool:to_binary(Platform1),
	case select_war_team_by_sn(Platform,Sn,Times-1) of
		[]->
%% 			io:format("can not find team>>>>~p/~p/~p ~n",[Platform,Sn,Times]),
			skip3;
		[TeamBag]->
			Team = {PlayerId,NickName,Career,Realm,Lv,Sex,Vip,Att},
			NewTeam = [Team|TeamBag#ets_war_team.team],
			NewTeamBag = TeamBag#ets_war_team{team=NewTeam},
			update_war_team(NewTeamBag),
			db_agent:update_war_team([{team,util:term_to_string(NewTeam)}],[{id,TeamBag#ets_war_team.id}]),
			ok
	end,
	ok.