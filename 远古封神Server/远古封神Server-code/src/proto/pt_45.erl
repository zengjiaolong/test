%% Author: Administrator
%% Created: 2011-8-17
%% Description: TODO: 跨服战场协议
-module(pt_45).

-export([read/2, write/2]).

-include("common.hrl").
-include("record.hrl").

%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------

%%查看历届大会记录
read(45001,<<Times:16>>)->
	{ok,[Times]};

%%报名
read(45002,<<>>)->
	{ok,[]};

%%查看报名信息
read(45003,<<>>)->
	{ok,[]};

%% %%资格邀请
%% read(45004,<<Name/binary>>)->
%% 	{Nickname,_} = pt:read_string(Name),
%% 	{ok,[Nickname]};
%% 
%% %%请求资格转让
%% read(45005,<<Name/binary>>)->
%% 	{Nickname,_} = pt:read_string(Name),
%% 	{ok,[Nickname]};
%% 
%% %%确认资格转让
%% read(45006,<<Res:8,Name/binary>>)->
%% 	{Nickname,_} = pt:read_string(Name),
%% 	{ok,[Res,Nickname]};
	
%%查看参赛队伍
read(45007,<<>>)->
	{ok,[]};

%%进入大会
read(45008,<<>>)->
	{ok,[]};

%%领取奖品
read(45009,<<>>)->
	{ok,[]};

%%查看个参赛队伍信息
read(45010,<<>>)->
	{ok,[]};

%%查看对阵表
read(45011,<<>>)->
	{ok,[]};

%%查看积分榜
read(45012,<<>>)->
	{ok,[]};

%%查看当前比赛状态
read(45013,<<>>)->
	{ok,[]};

%%查看比赛时间
read(45014,<<>>)->
	{ok,[]};

%%查看比赛信息
read(45015,<<>>)->
	{ok,[]};

%%VIP领取药品
read(45017,<<>>)->
	{ok,[]};

%%查看比赛比分
read(45018,<<>>)->
	{ok,[]};

%%查看其他分组比分
read(45019,<<>>)->
	{ok,[]};

%%请求回到休息区
read(45020,<<>>)->
	{ok,[]};

%%退出封神大会
read(45022,<<>>)->
	{ok,[]};

%%取消封神大会报名
read(45023,<<>>)->
	{ok,[]};

%%提交战旗
read(45024,<<>>)->
	{ok,[]};

%%查询积分
read(45025,<<>>)->
	{ok,[]};

%%积分兑换物品
read(45026,<<GoodsId:32,Num:16>>)->
	{ok,[GoodsId,Num]};

%%跨服单人竞技
read(45101,<<>>)->
	{ok,[]};

%%获取跨服单人竞技信息
read(45102,<<Type:16>>)->
	{ok,[Type]};

%%选拔赛配对
read(45103,<<>>)->
	{ok,[]};
%%请求返回分区
read(45105,<<>>)->
	{ok,[]};

%%查询淘汰赛历史记录
read(45107,<<>>)->
	{ok,[]};

%%领取单人奖励物品
read(45108,<<>>)->
	{ok,[]};

%%查询我的下注
read(45109,<<>>)->
	{ok,[]};

read(45110,<<Type:8,Money:8,PlayerId:32>>)->
	{ok,[Type,Money,PlayerId]};

%%请求进入单人竞技场景
read(45111,<<>>)->
	{ok,[]};

%%查询物品奖励信息
read(45114,<<>>)->
	{ok,[]};	
	
%%玩家逃跑
read(45115,<<>>)->
	{ok,[]};

%%获取比赛状态
read(45118,<<>>)->
	{ok,[]};

%%查询战报
read(45119,<<Grade:8,State:16,PidA:32,PidB:32>>)->
	{ok,[Grade,State,PidA,PidB]};

%%选择观战
read(45120,<<FightId:32>>)->
	{ok,[FightId]};

read(_Cmd, _R) ->
    {error, no_match}.


%%打包历届记录
write(45001,Bag)->
	{ok,NowTimes,Times,Nums,RecordBag} = Bag,
	RecordBin = tool:to_binary([pack_record(Record)||Record <- RecordBag]),
	{ok,pt:pack(45001,<<NowTimes:16,Times:16,Nums:16,RecordBin/binary>>)};

%%打包报名
write(45002,[Res,Total])->
	{ok,pt:pack(45002,<<Res:16,Total:16>>)};

%%打包报名信息
write(45003,Data)->
	[Res,Total,Invited,CanInvite] = Data,
	{ok,pt:pack(45003,<<Res:16,Total:16,Invited:16,CanInvite:16>>)};

%%打包资格邀请
write(45004,[Res])->
	{ok,pt:pack(45004,<<Res:16>>)};

%%打包资格转让请求
write(45005,[Res,Type])->
	{ok,pt:pack(45005,<<Res:16,Type:16>>)};

%%打包资格转让请求
write(45006,[NickName,SignUp])->
	Name = tool:to_binary(NickName),
	Len = byte_size(Name),
	{ok,pt:pack(45006,<<Len:16,Name/binary,SignUp:8>>)};

%%打包查看参赛玩家
write(45007,PlayerBag)->
	Len = length(PlayerBag),
	Bin = tool:to_binary([pack_war_player(Info)||Info<-PlayerBag]),
	{ok,pt:pack(45007,<<Len:16,Bin/binary>>)};

%%进入封神大会
write(45008,[Res,Ip,Port])->
	{Len,IpBin} = to_string(Ip),
	{ok,pt:pack(45008,<<Res:16,Len:16,IpBin/binary,Port:32>>)};

%%查看全部的参赛服务器玩家
write(45010,TeamInfo)->
	Len = length(TeamInfo),
	Bin = tool:to_binary([pack_team_player_all(Info)||Info<-TeamInfo]),
	{ok,pt:pack(45010,<<Len:16,Bin/binary>>)};

%%打包分组对阵
write(45011,Data)->
	{_Lv,VsInfo} = Data,
	Len = length(VsInfo),
	Bin = tool:to_binary([pack_vs_all(Info)||Info<-VsInfo]),
	{ok,pt:pack(45011,<<Len:16,Bin/binary>>)};

%%打包比分
write(45012,Data)->
	Len = length(Data),
	Bin = tool:to_binary([pack_point_all(Info)||Info<-Data]),
	{ok,pt:pack(45012,<<Len:16,Bin/binary>>)};

%%打包比赛状态
write(45013,[Res,Round])->
	{ok,pt:pack(45013,<<Res:8,Round:16>>)};

%%打包比赛时间
write(45014,[Type,Round,Timestamp])->
	{ok,pt:pack(45014,<<Type:16,Round:16,Timestamp:32>>)};

%%打包比赛信息
%%战斗信息
%%string红方平台
%%int8 红方服id
%% 	int	32红方积分
%%string蓝方平台
%%int8 蓝方服id
%% 	int 32蓝方积分
%%	int 8 战旗状态（11红，12 蓝，0中立)
%%string 持旗玩家 
%%  string MVP
%%int 16本场击杀数
%%int16 连击数
%% int32 本场获得积分 
%%int32本届总积分
%% int16 当前攻击战旗数
%% int16  需要攻击战旗数
%% int16当前击倒玩家数
%% int16需要击倒玩家数
write(45015,[RedPlat,RedSn,RedP,BluePlat,BlueSn,BlueP,FlagState,FlagOwner,MvpColor,Mvp,NowKill,DoubleHit,PointS,MaxP,TotalP,AttFlag,AttFlagNeed,Kill,KillNeed,PlayerBag])->
	Len  = length(PlayerBag),
	Bin = tool:to_binary([pack_player_fight(Player)||Player<-PlayerBag]),
	{RedLen,RedPlat1} = to_string(RedPlat),
	{BlueLen,BluePlat1} = to_string(BluePlat),
	{MvpLen,MvpBin} = to_string(Mvp),
	{OwnerLen,OwnerBin} = to_string(FlagOwner),
	{ok,pt:pack(45015,<<RedLen:16,RedPlat1/binary,RedSn:16,RedP:32,
						BlueLen:16,BluePlat1/binary,BlueSn:16,BlueP:32,
						FlagState:8,OwnerLen:16,OwnerBin/binary,MvpColor:8,MvpLen:16,MvpBin/binary,NowKill:16,DoubleHit:16,
						PointS:32,MaxP:32,TotalP:32,AttFlag:16,AttFlagNeed:16,Kill:16,KillNeed:16,Len:16,Bin/binary>>)};
						 
						 
%%VIP领取药品
write(45017,[Res])->
	{ok,pt:pack(45017,<<Res:16>>)};

%%分组战斗结果
write(45018,[Mark,RedP,RedK,RedMem,BlueP,BlueK,BlueMem])->
	RedLen = length(RedMem),
	RedBin = tool:to_binary(pack_result_member(RedMem,[])),
	BlueLen = length(BlueMem),
	BlueBin = tool:to_binary(pack_result_member(BlueMem,[])),
	{ok,pt:pack(45018,<<Mark:16,RedP:32,RedK:32,RedLen:16,RedBin/binary,BlueP:32,BlueK:32,BlueLen:16,BlueBin/binary>>)};

%%其他分组战斗结果
write(45019,[ResultBag])->
	Len = length(ResultBag),
	Bin = tool:to_binary([pack_war_result(Result)||Result<-ResultBag]),
	{ok, pt:pack(45019, <<Len:16,Bin/binary>>)};
	
%%查询封神大会入口状态
write(45021,[Res])->
	{ok,pt:pack(45021,<<Res:8>>)};

%%退出封神大会
write(45022,[IP,Port])->
	{Len,IpBin} = to_string(IP),
	{ok,pt:pack(45022,<<Len:16,IpBin/binary,Port:32>>)};

%%取消封神大会报名
write(45023,[Res])->
	{ok,pt:pack(45023,<<Res:16>>)};

%%提交战旗
write(45024,[Res])->
	{ok,pt:pack(45024,<<Res:16>>)};

%%查询积分
write(45025,[P])->
	{ok,pt:pack(45025,<<P:16>>)};
%%积分兑换物品
write(45026,[Res,P])->
	{ok,pt:pack(45026,<<Res:16,P:16>>)};


%%跨服单人竞技报名
write(45101,[Res])->
	{ok,pt:pack(45101, <<Res:16>>)};

%%获取跨服单人竞技信息
write(45102,[Times,Week,Champion,ChampionNow,Award,MyBet,IsApply,VsInfo])->
	[C_Name_Old,C_Platform_Old,C_Sn_Old] = Champion,
	{C_NameLen_Old,C_Name1_Old} = to_string(C_Name_Old),
	{C_PlatformLen_Old,C_Platform1_Old} = to_string(C_Platform_Old),
	
	[C_Name,C_Career,C_Sex,C_Platform,C_Sn] = ChampionNow,
	{C_NameLen,C_Name1} = to_string(C_Name),
	{C_PlatformLen,C_Platform1} = to_string(C_Platform),
	{CanBet,BetId,Grade,BetType,BetTotal} = MyBet,
	VsLen = length(VsInfo),
	VsBin  = tool:to_binary(pack_elimination_bag(VsInfo,[])),
	{ok,pt:pack(45102,<<Times:32,Week:16,
						C_NameLen_Old:16,C_Name1_Old/binary,C_PlatformLen_Old:16,C_Platform1_Old/binary,C_Sn_Old:32,
						C_NameLen:16,C_Name1/binary,C_Career:16,C_Sex:16,C_PlatformLen:16,C_Platform1/binary,C_Sn:32,
						Award:8,CanBet:8,
						BetId:32,Grade:16,BetType:16,BetTotal:32,
						IsApply:8,
						VsLen:16,VsBin/binary>>)};

%%配对结果
write(45103,[Res])->
	{ok,pt:pack(45103,<<Res:16>>)};

%%竞技战斗结果
write(45104,[Status,Enemy,Wins])->
	{Len,Name} = to_string(Enemy),
	{ok,pt:pack(45104, <<Status:8,Len:16,Name/binary,Wins:32>>)};

%%淘汰赛结果
write(45106,[Status,NameA,WinsA,NameB,WinsB])->
	{ALen,AName} = to_string(NameA),
	{BLen,BName} = to_string(NameB),
	{ok,pt:pack(45106, <<Status:8,ALen:16,AName/binary,WinsA:16,BLen:16,BName/binary,WinsB:16>>)};

%%历史记录
write(45107,[State,History])->
	Len = length(History),
	HistoryBin = tool:to_binary(pack_history(History,[])),
	{ok,pt:pack(45107, <<State:16,Len:16,HistoryBin/binary>>)};

%%单人奖励
write(45108,[Res])->
	{ok,pt:pack(45108, <<Res:16>>)};

%%进入单人竞技
write(45111,[Res,Ip,Port])->
	{Len,IpBin} = to_string(Ip),
	{ok,pt:pack(45111,<<Res:16,Len:16,IpBin/binary,Port:32>>)};

%%下注
write(45110, [Res,Grade])->
	{ok,pt:pack(45110, <<Res:16,Grade:16>>)};

%%推送比赛个人信息
write(45112,[Grade,Subarea,Timestamp,Wins,WinNeed,Tryout,MatchStart,Offtrack])->
	{ok,pt:pack(45112, <<Grade:8,Subarea:16,Timestamp:32,Wins:16,WinNeed:16,Tryout:16,MatchStart:8,Offtrack:8>>)};

%%淘汰赛个人比赛信息
write(45113,[State,Timestamp,MyWins,EnemyWins,Remain,Finish])->
	{ok,pt:pack(45113, <<State:16,Timestamp:32,MyWins:16,EnemyWins:16,Remain:16,Finish:8>>)};

%%查询奖励信息
write(45114,[Grade,Rank,P,Goods])->
	Len = length(Goods),
	GoodsBin = tool:to_binary(pack_goods_award(Goods,[])),
	{ok,pt:pack(45114,<<Grade:8,Rank:16,P:32,Len:16,GoodsBin/binary>>)};

%%玩家逃跑
write(45115,[Res])->
	{ok,pt:pack(45115, <<Res:16>>)};

%%通知进入封神争霸
write(45116,[Res])->
	{ok,pt:pack(45116, <<Res:16>>)};

%%通知退出封神争霸
write(45117,[Res])->
	{ok,pt:pack(45117, <<Res:8>>)};

%%获取比赛状态
write(45118,[S])->
	{ok,pt:pack(45118, <<S:16>>)};

%%查询战报{<<>>,<<>>,0,0,0};
write(45119,[AInfo,BInfo,Pape])->
	{NameA,PA,SA,CA,SexA} = AInfo,
	{LenA,NameABin} = to_string(NameA),
	{LenPA,PABin} = to_string(PA),
	{NameB,PB,SB,CB,SexB}  = BInfo,
	{LenB,NameBBin} = to_string(NameB),
	{LenPB,PBBin} = to_string(PB),
	LenPage = length(Pape),
	PageBin = tool:to_binary(pack_war2_pape(Pape,[])),
	{ok,pt:pack(45119, <<LenA:16,NameABin/binary,LenPA:16,PABin/binary,SA:16,CA:16,SexA:8,
						 LenB:16,NameBBin/binary,LenPB:16,PBBin/binary,SB:16,CB:16,SexB:8,
						 LenPage:16,PageBin/binary>>)};

%%选择观战
write(45120,[Res])->
	{ok,pt:pack(45120, <<Res:16>>)};

%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.

%%打包历史记录
pack_record(Bag)->
	Len = length(Bag),
	{Lv,BagList} = pack_record_loop(Bag,0,[]),
	AIBin = tool:to_binary(BagList),
	<<Lv:16,Len:16,AIBin/binary>>.

pack_record_loop([],Lv,NewRecord)->{Lv,NewRecord};
pack_record_loop([R|Record],Lv,NewRecord)->
	{NewLv,P,Platform,Sn} = R,
	if Lv =/= NewLv ->
		   NewLv1 = NewLv;
	   true->
		   NewLv1 = Lv
	end,
	PlatformBin = tool:to_binary(Platform),
	PlatformLen = byte_size(PlatformBin),
%% 	NameBin = tool:to_binary(Name),
%% 	Len = byte_size(NameBin),
	pack_record_loop(Record,NewLv1,[<<P:16,PlatformLen:16,PlatformBin/binary,Sn:16>>|NewRecord]).
%% pack_record_loop(Record,NewLv1,[<<P:16>>|NewRecord]).
%%打包参赛玩家
pack_war_player(Info)->
	{NickName,Realm,Career,Lv,Att}=Info,
	Name = tool:to_binary(NickName),
	Len = byte_size(Name),
	<<Len:16,Name/binary,Realm:16,Career:16,Lv:16,Att:32>>.

%%打包所有参赛队伍
%%{Lv,[{Team#ets_war_team.platform,Team#ets_war_team.name,Team#ets_war_team.team}||Team<-TeamBag]}.
pack_team_player_all(Info)->
	{Lv,TeamBag} = Info,
	Len = length(TeamBag),
	Team = tool:to_binary(pack_team_loop(TeamBag,[])),
	<<Lv:16,Len:16,Team/binary>>.

pack_team_loop([],Info)->
	Info;
pack_team_loop([Team|Bag],Info)->
	{Platform1,Sn,TeamBag}=Team,
	Platform = tool:to_binary(Platform1),
	PlatLen = byte_size(Platform),
	
%% 	ServerName = tool:to_binary(ServerName1),
%% 	Len = byte_size(ServerName),
	TeamBag1 = case TeamBag of
				   undefined->[];
				   ""->[];
				   _->TeamBag
			   end,
	TeamLen = length(TeamBag1),
	TeamBin = tool:to_binary(pack_team_member(TeamBag1,[])),
	Data = <<PlatLen:16,Platform/binary,Sn:16,TeamLen:16,TeamBin/binary>>,
	pack_team_loop(Bag,[Data|Info]).

pack_team_member([],Info)->Info;
pack_team_member([Team|Bag],Info)->
	{_Id,NickName1,Career,Realm,Lv,Sex,Vip,Att}=Team,
	NickName = tool:to_binary(NickName1),
	Len = byte_size(NickName),
	pack_team_member(Bag,[<<Len:16,NickName/binary,Lv:16,Sex:8,Realm:8,Career:8,Vip:8,Att:32>>|Info]).

%%打包对阵{Lv,[pack_vs_info_loop(Idbag,[])||Idbag<-IdList]}.
pack_vs_all(Info)->
	{Lv,VsBag}=Info,
	Round = length(VsBag),
	Bin = tool:to_binary(pack_vs_loop(VsBag,1,[])),
	<<Lv:16,Round:16,Bin/binary>>.

pack_vs_loop([],_Round,Info)->lists:reverse(Info);
pack_vs_loop([Vs|VsBag],Round,Info)->
	Len = length(Vs),
	Bin = tool:to_binary(pack_vs(Vs,[])),
	pack_vs_loop(VsBag,Round+1,[<<Round:16,Len:16,Bin/binary>>|Info]).

pack_vs([],Info)->Info;
pack_vs([Vs|Bag],Info)->
	%%[{Vs#ets_war_vs.name_a,Vs#ets_war_vs.res_a,Vs#ets_war_vs.name_b,Vs#ets_war_vs.res_b}|Bag]
	{PlatA1,SnA,ResA,PlatB1,SnB,ResB} = Vs,
	{PlatALen,PlatA} = to_string(PlatA1),
%% 	{LenA,NameA} = to_string(NameA1),
	{PlatBLen,PlatB} = to_string(PlatB1),
%% 	{LenB,NameB} = to_string(NameB1),
	pack_vs(Bag,[<<PlatALen:16,PlatA/binary,SnA:16,ResA:16,PlatBLen:16,PlatB/binary,SnB:16,ResB:16>>|Info]).

%%打包比分
pack_point_all(Info)->
	{Lv,Bag} = Info,
	Len = length(Bag), 
	Bin = tool:to_binary(pack_point(Bag,1,[])),
	<<Lv:16,Len:16,Bin/binary>>.

pack_point([],_R,Info)->lists:reverse(Info);
pack_point([{Platform1,Sn,Point}|Bag],Round,Info)->
	{PlatLen,Platform} = to_string(Platform1),
%% 	{Len,Name1} = to_string(Name),
	pack_point(Bag,Round+1,[<<Round:16,PlatLen:16,Platform/binary,Sn:16,Point:16>>|Info]).

pack_war_result(Result)->
	{PlatA1,SnA,PA,PlatB1,SnB,PB} = Result,
	{PlatALen,PlatA} = to_string(PlatA1),
%% 	{LenA,NameA} = to_string(NameA1),
	{PlatBLen,PlatB} = to_string(PlatB1),
%% 	{LenB,NameB} = to_string(NameB1),
	<<PlatALen:16,PlatA/binary,SnA:16,PA:16,PlatBLen:16,PlatB/binary,SnB:16,PB:16>>.


pack_player_fight(Player)->
	{Name,Career,Mark,P} = Player,
	{Len,Name1} = to_string(Name),
	<<Len:16,Name1/binary,Career:16,Mark:16,P:16>>.

%%打包比赛结果
%% pack_war_res(RedP,RedK,RedMem,BlueP,BlueK,BlueMem)->
%% 	RedLen = length(RedMem),
%% 	RedBin = tool:to_binary(pack_result_member(RedMem,[])),
%% 	BlueLen = length(BlueMem),
%% 	BlueBin = tool:to_binary(pack_result_member(BlueMem,[])),
%% 	<<RedP:32,RedK:32,RedLen:16,RedBin/binary,BlueP:32,BlueK:32,BlueLen:16,BlueBin/binary>>.

pack_result_member([],MemBag)->MemBag;
pack_result_member([M|Member],MemBag)->
	{NickName,Kill,Die,MaxHit} = M,
	Name = tool:to_binary(NickName),
	Len = byte_size(Name),
	pack_result_member(Member,[<<Len:16,Name/binary,Kill:16,Die:16,MaxHit:16>>|MemBag]).

%%打包个人竞技淘汰赛对阵信息
pack_elimination_bag([],EliInfo)->EliInfo;
pack_elimination_bag([M|Eli],EliInfo)->
	PlayerId =  M#ets_war2_elimination.pid,
	Nickname = M#ets_war2_elimination.nickname,
	{NameLen,NickName1} = to_string(Nickname),
	Lv = M#ets_war2_elimination.lv,
	Career = M#ets_war2_elimination.career,
	Sex = M#ets_war2_elimination.sex,
	BattValue = M#ets_war2_elimination.batt_value,
	Popular = M#ets_war2_elimination.popular,
	Platform = M#ets_war2_elimination.platform,
	{PlatformLen,Platform1} = to_string(Platform),
	Sn = M#ets_war2_elimination.sn,
	Subarea = M#ets_war2_elimination.subarea,
	Num = M#ets_war2_elimination.num,
	State = M#ets_war2_elimination.state, 
	IfEli = M#ets_war2_elimination.elimination,
	pack_elimination_bag(Eli,[<<PlayerId:32,NameLen:16,NickName1/binary,Lv:16,Career:16,Sex:16,BattValue:32,Popular:32,PlatformLen:16,Platform1/binary,Sn:32,Subarea:16,Num:16,State:16,IfEli:8>>|EliInfo]).

%%打包个人淘汰赛历史记录
pack_history([],Bin)->lists:reverse(Bin);
pack_history([H|History],Bin)->
	State = H#ets_war2_history.state,
	Timestamp = H#ets_war2_history.timestamp,
	Enemy = H#ets_war2_history.enemy,
	{LenE,E} = to_string(Enemy),
	Res = H#ets_war2_history.result,
	Res1 = tool:to_list(Res),
	P1 = tool:to_integer(string:substr(Res1, 2,1)),
	P2 = tool:to_integer(string:substr(Res1, 4,1)),
	pack_history(History,[<<State:16,Timestamp:32,LenE:16,E/binary,P1:16,P2:16>>|Bin]).

%%打包争霸奖励物品信息
pack_goods_award([],Bin)->Bin;
pack_goods_award([{GoodsId,Num}|Goods],Bin)->
	pack_goods_award(Goods,[<<GoodsId:32,Num:16>>|Bin]).

%%pack_war2_page打包战报
pack_war2_pape([],Bin)->Bin;
pack_war2_pape([{Round,Name}|Pape],Bin)->
	{Len,Name1} = to_string(Name),
	pack_war2_pape(Pape,[<<Round:16,Len:16,Name1/binary>>|Bin]).

to_string(String)->
	String1 = tool:to_binary(String),
	Len = byte_size(String1),
	{Len,String1}.