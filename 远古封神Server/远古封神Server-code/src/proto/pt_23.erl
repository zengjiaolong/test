%%%------------------------------------
%%% @Module     : pt_23
%%% @Author     : ygfs
%%% @Created    : 2011.02.15 
%%% @Description: 竞技场处理 
%%%------------------------------------
-module(pt_23).
-export(
	[
	 	read/2, 
		write/2
	]
).
-include("common.hrl").
-include("record.hrl").

read(23001, _) ->
    {ok, []};

%% 竞技场报名
read(23002, _) ->
    {ok, []};

%% 进入竞技场
read(23003, _) ->
    {ok, []};

%% 加入战场
%% 战场ID ZoneId
%% 战区ID BattleId
read(23004, <<ZoneId:8, BattleId:16>>) ->
	{ok, [ZoneId, BattleId]};

%% 竞技排名列表
read(23005, _) ->
	{ok, []};

%% 竞技排名列表
read(23010, _) ->
	{ok, []};

%%LvNum    
%%1 初级竞技场(30-39级)	2 中级竞技场(40-49级)	 3 高级竞技场(50级以上)
%%AreaNum 
%%1第一战区	2第二战区	3第三战区
read(23020, <<LvNum:8, AreaNum:8>>) ->
	{ok, [LvNum, AreaNum]};

%%Rank   1 >> 总战绩排行	2 >> 周战绩排行
%%Page 1 >> 1-5页		2 >> 6-10页		3 >> 11-15页
read(23021, <<RankType:8,PageNum:8,CurrPage:16>>) ->
	{ok, [RankType,PageNum,CurrPage]};

%% 使用怒气技能
read(23023, <<DerId:32>>) ->
    {ok, DerId};

%% 打开战场奖励面板
read(23024, _) ->
	{ok, []};

%% 领取奖励
read(23026, _) ->
	{ok, []};

read(_Cmd, _R) ->
	{error, no_match}.

%% 竞技场报名
write(23001, [Time, Sta]) ->
    {ok, pt:pack(23001, <<Time:16, Sta:8>>)};

%% 竞技场报名
write(23002, Result) ->
    {ok, pt:pack(23002, <<Result:8>>)};

%% 通知前端加入战场
%% 战场ID ZoneId
%% 战区ID BattleId
write(23003, [ZoneId, BattleId, Type]) ->
	{ok, pt:pack(23003, <<ZoneId:8, BattleId:16, Type:8>>)};

%% 是否能加入战场
write(23004, Result) ->
    {ok, pt:pack(23004, <<Result:8>>)};

%% 竞技排名列表
%% DragonRealm 天龙
%% TigerRealm 地虎
%% HumanRealm 人王
write(23005, [DragonRealm, TigerRealm, HumanRealm, ArenaList, Zone]) ->
    Len = length(ArenaList),
    F = fun({PlayerId, Name, Career, Kill, Mark}) ->
  		NewName = tool:to_binary(Name),
  		NL = byte_size(NewName),  		
		<<PlayerId:32, NL:16, NewName/binary, Career:8, Kill:8, Mark:8>>
    end,
    LN = tool:to_binary([F(A) || A <- ArenaList]),
    Data = <<DragonRealm:16, TigerRealm:16, HumanRealm:16, Len:16, LN/binary, Zone:8>>,
    {ok, pt:pack(23005, Data)};

%% 更新竞技场信息
%% DragonRealm 天龙
%% TigerRealm 地虎
%% HumanRealm 人王
write(23006, [Killer, KName, BeKiller, BKName, DragonRealm, TigerRealm, HumanRealm]) ->	
	NewKName = tool:to_binary(KName),
  	KL = byte_size(NewKName),
	NewBKName = tool:to_binary(BKName),
  	BKL = byte_size(NewBKName),
    Data = <<Killer:32, KL:16, NewKName/binary, BeKiller:32, BKL:16, NewBKName/binary, DragonRealm:16, TigerRealm:16, HumanRealm:16>>,
    {ok, pt:pack(23006, Data)};

%% 竞技场复活次数
write(23008, Nickname) ->
	NewNickname = tool:to_binary(Nickname),
  	NicknameLen = byte_size(NewNickname),
	{ok, pt:pack(23008, <<NicknameLen:16, NewNickname/binary>>)};

%% 竞技场复活次数
write(23009, Num) ->
	{ok, pt:pack(23009, <<Num:8>>)};

%% 竞技场结束
write(23010, Sign) ->
    {ok, pt:pack(23010, <<Sign:8>>)};

%% 竞技场英雄榜
write(23020, Data) ->
	[LvNum,AreaNum,AreaDataS,WinSide,Finished,RankList] = Data,
	Size = length(RankList),
    F =  fun([Nickname, Realm, Career, Lv, Camp, Type, Score]) ->
 		NickName1 = tool:to_binary(Nickname),
    	Nick_len = byte_size(NickName1),
     	<<Nick_len:16, NickName1/binary, Realm:8, Career:8, Lv:8, Camp:8, Type:16, Score:16>>
		 end,
    Data2 = tool:to_binary([F(ArenaWeek) || ArenaWeek<- RankList]),
    {ok, pt:pack(23020, <<LvNum:8,AreaNum:8,AreaDataS:8,WinSide:8,Finished:8,Size:16,Data2/binary>>)};


%% 竞技场排行榜
write(23021, Data) ->
	[RankType,PageNum,TotalPage,RankFirthName,ResultData] = Data,
	RankFirthName1 = tool:to_binary(RankFirthName),
	Nick_len = byte_size(RankFirthName1),
	ResultData_len = length(ResultData),
    F =  fun(Result) ->
                 [Order,_Player_Id,Nickname, Realm, Career, Lv, Wins] = Result,
                 Nickname1 = tool:to_binary(Nickname),
                 Nick_len1 = byte_size(Nickname1),
                 <<
				   Order:16,
                   Nick_len1:16,
                   Nickname1/binary,
                   Realm:8,
                   Career:8,
                   Lv:8,
                   Wins:16
				 >>
		 end,
    Data2 =  tool:to_binary([F(Result) || Result<- ResultData]),
    {ok, pt:pack(23021, <<RankType:8, PageNum:16,TotalPage:16,Nick_len:16,RankFirthName1/binary,ResultData_len:16,Data2/binary>>)};

%% 更新竞技场怒气
write(23022, Angry) ->
	{ok, pt:pack(23022, <<Angry:16>>)};

%% 使用怒气技能
write(23023, Result) ->
	{ok, pt:pack(23023, <<Result:8>>)};

%% 打开战场奖励面板
write(23024, [RankList, Result]) ->
	RankData = pt_22:pack_arena_rank_list(RankList),
    {ok, pt:pack(23024, <<RankData/binary, Result:8>>)};

%% 领取战场奖励
write(23026, [Result, GoodsTypeId]) ->
    {ok, pt:pack(23026, <<Result:8, GoodsTypeId:32>>)};

write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.
