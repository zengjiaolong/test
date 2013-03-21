%%%--------------------------------------
%%% @Module  : pt_49
%%% @Author  : ygfs
%%% @Created : 2012.02.27
%%% @Description : 竞技场
%%%--------------------------------------
-module(pt_49).

-export(
 	[
		read/2,
		write/2
	]
).
-include("record.hrl").
-include("common.hrl").


%% 打开竞技场面板
read(49001, _) ->
    {ok, []};

%% 修改是否自动使用替身设置 
%% IsAvatar 1是，0否
read(49002, <<IsAvatar:8>>) ->
	{ok, IsAvatar};

%% 请求竞技场排行榜信息
read(49003, _) ->
    {ok, []};

%% 清零冷却时间或增加每日挑战次数
%% Type 请求类型，1清零冷却时间，2增加每日挑战次数
read(49004, <<Type:8>>) ->
	{ok, Type};

%% 竞技场战报展示
%% ResultId 战报id
read(49006, <<ResultId:32>>) ->
	{ok, ResultId};

%% 竞技场挑战
%% ChallengerId 挑战者ID
read(49007, <<ChallengerId:32>>) ->
	{ok, ChallengerId};

%% 被挑战者回应
%% Result 1亲自上阵，2使用替身
read(49008, <<Result:8, PlayerId:32>>) ->
	{ok, [Result, PlayerId]};

%% 离开竞技场
read(49012, _) ->
	{ok, []};

%% 领取竞技场奖励
read(49014, _) ->
	{ok, []};

read(_Cmd, _R) ->
	{error, no_match}.



%% PlayerId 玩家ID
%% Ranking 排名
%% Win 连胜次数
%% CoolTime 冷却时间
%% SurplusTimes 剩余挑战次数
%% ExtraChallengeTime 额外添加的挑战次数
%% RewardTime 奖励领取时间
%% Avatar 是否使用替身，1是0否
%% ChallengerList 挑战者列表
write(49001, [{PlayerId, CoolTime, SurplusTimes, ExtraChallengeTime, Avatar}, Ranking, Win, RewardTime, ChallengerList]) ->
    Len = length(ChallengerList),
    F = fun(C) ->
		#ets_coliseum_rank{
			player_id = Id,
			nickname = Nickname,
			lv = Lv,
			realm = Realm,
			sex = Sex,
			rank = Rank,
			career = Career,
			battle = Battle		   
		} = C,
  		NewName = tool:to_binary(Nickname),
  		NL = byte_size(NewName),  		
		<<Id:32, NL:16, NewName/binary, Lv:8, Realm:8, Sex:8, Battle:32, Rank:16, Career:8>>
    end,
    LN = tool:to_binary([F(A) || A <- ChallengerList]),
    Data = <<PlayerId:32, Ranking:16, Win:8, CoolTime:16, SurplusTimes:8, ExtraChallengeTime:8, RewardTime:32, Avatar:8, Len:16, LN/binary>>,
    {ok, pt:pack(49001, Data)};

%% 请求竞技场排行榜信息
write(49003, ColiseumList) ->
	Len = length(ColiseumList),
	F = fun(C) ->
		#ets_coliseum_rank{
			player_id = PlayerId,
			nickname = Nickname,
			lv = Lv,
			battle = Battle,
			trend = Trend		   
		} = C,
		NewName = tool:to_binary(Nickname),
  		NL = byte_size(NewName),  
		<<PlayerId:32, NL:16, NewName/binary, Lv:8, Battle:32, Trend:8>>
    end,
    LN = tool:to_binary([F(C) || C <- ColiseumList]),
	{ok, pt:pack(49003, <<Len:16, LN/binary>>)};

%% 清零冷却时间或增加每日挑战次数
%% Type 请求类型，1清零冷却时间，2增加每日挑战次数
%% Time 返回冷却时间或者剩余挑战次数
%% Extra 返回额外挑战次数
write(49004, [Type, Result, Time, Extra]) ->
	{ok, pt:pack(49004, <<Type:8, Result:8, Time:8, Extra:8>>)};

%% 竞技场战报返回
write(49005, ColiseumReport) ->
	NewColiseumReport = 
		case is_list(ColiseumReport) of
			true ->
				ColiseumReport;
			false ->
				[]
		end,
	Len = length(NewColiseumReport),
	F = fun({ResultId, ChallengerId, ResultTime, Nickname, Relation, Result, Rank}) ->
  		NewName = tool:to_binary(Nickname),
  		NL = byte_size(NewName),  		
		<<ResultId:32, ResultTime:32, NL:16, NewName/binary, Relation:8, Result:8, Rank:16, ChallengerId:32>>
    end,
    LN = tool:to_binary([F(C) || C <- NewColiseumReport]),
	{ok, pt:pack(49005, <<Len:16, LN/binary>>)};

%% 竞技场战报展示
write(49006, Result) ->
	{ok, pt:pack(49006, <<Result:8>>)};

%% 竞技场挑战结果返回
%% ChallengerId 挑战者ID
write(49007, [Result, PlayerId, Nickname]) ->
	NewName = tool:to_binary(Nickname),
  	NameLen = byte_size(NewName),  
	{ok, pt:pack(49007, <<Result:8, PlayerId:32, NameLen:16, NewName/binary>>)};

%% 被挑战者回应结果
%% Result 2已经结束，3已经开打
write(49008, Result) ->
	{ok, pt:pack(49008, <<Result:8>>)};

%% 进入竞技场
write(49009, [PlayerId, Nickname, Lv, Sex, Career, HpLim, MpLim]) ->
	NewName = tool:to_binary(Nickname),
  	NameLen = byte_size(NewName),
	{ok, pt:pack(49009, <<PlayerId:32, NameLen:16, NewName/binary, Lv:8, Sex:8, Career:8, HpLim:32, MpLim:32>>)};

%% 发送竞技场战斗时间
%% Type 1准备、2正式开始
write(49010, [Type, ColiseumFightTime]) ->
	{ok, pt:pack(49010, <<Type:8, ColiseumFightTime:16>>)};

%% 竞技场结果
write(49011, [Player1, Nickname1, Lv1, Sex1, Career1, Player2, Nickname2, Lv2, Sex2, Career2, Result, Coin, Cul, Rank]) ->
	NewName1 = tool:to_binary(Nickname1),
  	NameLen1 = byte_size(NewName1),  
	NewName2 = tool:to_binary(Nickname2),
  	NameLen2 = byte_size(NewName2),  
	Data = <<Player1:32, NameLen1:16, NewName1/binary, Lv1:8, Sex1:8, Career1:8, 
			 Player2:32, NameLen2:16, NewName2/binary, Lv2:8, Sex2:8, Career2:8, Result:8, Coin:32, Cul:32, Rank:16>>,
	{ok, pt:pack(49011, Data)};

%% 竞技场奖励状态
write(49013, Rank) ->
	{ok, pt:pack(49013, <<Rank:32>>)};

%% 领取竞技场奖励
write(49014, [Result, Culture, Coin, Spirit, Time, GoodsTypeId]) ->
	{ok, pt:pack(49014, <<Result:8, Culture:32, Coin:32, Spirit:32, Time:32, GoodsTypeId:32>>)};

write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.

