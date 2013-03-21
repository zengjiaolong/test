%%%--------------------------------------
%%% @Module  : pt_47
%%% @Author  : ygfs
%%% @Created : 2011.11.16
%%% @Description : 九霄攻城战
%%%--------------------------------------
-module(pt_47).

-export(
	[
		read/2, 
		write/2
	]
).

-include("common.hrl").
-include("record.hrl").

%% 攻城战报名
read(47002, _) ->
	{ok, []};

%% 获取攻城战报名氏族列表
read(47003, _) ->
	{ok, []};

%% 进入九霄攻城战
read(47004, _) ->
	{ok, []};

%% 战功排行个人战功
read(47005, _) ->
	{ok, []};

%% 战功排行个人战功
read(47006, _) ->
	{ok, []};

%% 攻城战数据
%% Type 1氏族战功、2伤害积分、3个人战功ZoneId
read(47007, <<Type:8>>) ->
	{ok, Type};

%% 领取税收
read(47009, _) ->
	{ok, []};

%% 离开攻城战
read(47010, _) ->
	{ok, []};

%% 使用鼓舞技能
read(47012, _) ->
	{ok, []};

%% 城主更新
read(47015, _) ->
	{ok, []};

%% 攻城战奖励 - 获取物品
read(47016, _) ->
	{ok, []};

%% 攻城战奖励 - 物品分配物品
read(47017, <<PlayerId:32, GoodsTypeId:32, Num:32>>) ->
	{ok, [PlayerId, GoodsTypeId, Num]};

%% 攻城战奖励 - 物品自动分配
read(47018, _) ->
	{ok, []};

read(_Cmd, _R) ->
	io:format("NO MATCH READ ~p~n", [[_Cmd, _R]]),
    {error, no_match}.



%% 攻城战报名开始
write(47001, [Time, Sta]) ->
	{ok, pt:pack(47001, <<Time:16, Sta:8>>)};

%% 攻城战报名
write(47002, Sta) ->
	{ok, pt:pack(47002, <<Sta:8>>)};

%% 攻城战报名氏族列表
write(47003, CastleRushList) ->
	Len = length(CastleRushList),
    F = fun(R) ->
		GuildId = R#ets_castle_rush_join.guild_id,
		GuildLv = R#ets_castle_rush_join.guild_lv,
		GuildNum = R#ets_castle_rush_join.guild_num,
		GuildName = R#ets_castle_rush_join.guild_name,
		GuildChief = R#ets_castle_rush_join.guild_chief,
  		NewGuildName = tool:to_binary(GuildName),
  		GuildNameLen = byte_size(NewGuildName),
		NewGuildChief = tool:to_binary(GuildChief),
  		GuildChiefLen = byte_size(NewGuildChief), 
		<<GuildId:32, GuildLv:8, GuildNum:16, GuildNameLen:16, NewGuildName/binary, GuildChiefLen:16, NewGuildChief/binary>>
    end,
    LN = tool:to_binary([F(L) || L <- CastleRushList]),
    {ok, pt:pack(47003, <<Len:16, LN/binary>>)};

%% 进入九霄攻城战
write(47004, Sta) ->
	{ok, pt:pack(47004, <<Sta:8>>)};

%% 战功排行氏族战功 
write(47005, CastleRushList) ->
	Len = length(CastleRushList),
    F = fun([_GuildId, GuildName, GuildLv, GuildNum, Score]) ->
  		NewGuildName = tool:to_binary(GuildName),
  		GuildNameLen = byte_size(NewGuildName),
		<<GuildNameLen:16, NewGuildName/binary, GuildLv:8, GuildNum:8, Score:32>>
    end,
    LN = tool:to_binary([F(L) || L <- CastleRushList]),
    {ok, pt:pack(47005, <<Len:16, LN/binary>>)};

%% 战功排行个人战功
write(47006, CastleRushList) ->
	Len = length(CastleRushList),
    F = fun([_PlayerId, NickName, _GuildId, Career, Lv, KillNum, DieNum, GuildScore, PlayerScore, Score]) ->
  		NewNickName = tool:to_binary(NickName),
  		NickNameLen = byte_size(NewNickName),
		<<NickNameLen:16, NewNickName/binary, Career:8, Lv:16, KillNum:16, DieNum:16, GuildScore:32, PlayerScore:32, Score:32>>
    end,
    LN = tool:to_binary([F(L) || L <- CastleRushList]),
    {ok, pt:pack(47006, <<Len:16, LN/binary>>)};

%% 攻城战数据
%% Type 1氏族战功、2伤害积分、3个人战功
write(47007, Type) ->
    LN = 
		case Type of
			%% 氏族战功
			1 ->
				CastleRushData = ets:tab2list(?ETS_CASTLE_RUSH_GUILD_SCORE),
				Len = length(CastleRushData),
				F = fun(C) ->
					GuildName = C#ets_castle_rush_guild_score.guild_name,
					Score = C#ets_castle_rush_guild_score.score,
  					NewGuildName = tool:to_binary(GuildName),
  					GuildNameLen = byte_size(NewGuildName),
					<<GuildNameLen:16, NewGuildName/binary, Score:32>>
    			end,
				tool:to_binary([F(L) || L <- CastleRushData]);
			%% 伤害积分
			2 ->
				CastleRushData = ets:tab2list(?ETS_CASTLE_RUSH_HARM_SCORE),
				Len = length(CastleRushData),
				F = fun(C) ->
					GuildName = C#ets_castle_rush_harm_score.guild_name,
					Score = C#ets_castle_rush_harm_score.score,
  					NewGuildName = tool:to_binary(GuildName),
  					GuildNameLen = byte_size(NewGuildName),
					<<GuildNameLen:16, NewGuildName/binary, Score:32>>
    			end,
				tool:to_binary([F(L) || L <- CastleRushData]);
			%% 个人战功
			_ ->
				CastleRushData = ets:tab2list(?ETS_CASTLE_RUSH_PLAYER_SCORE),
				Len = length(CastleRushData),
				F = fun(C) ->
					GuildName = C#ets_castle_rush_player_score.nickname,
					Score = C#ets_castle_rush_player_score.score,
  					NewGuildName = tool:to_binary(GuildName),
  					GuildNameLen = byte_size(NewGuildName),
					<<GuildNameLen:16, NewGuildName/binary, Score:32>>
    			end,
				tool:to_binary([F(L) || L <- CastleRushData])
		end,
    {ok, pt:pack(47007, <<Type:8, Len:16, LN/binary>>)};

%% 龙塔占领方
write(47008, GuildName) ->
	NewGuildName = tool:to_binary(GuildName),
  	GuildNameLen = byte_size(NewGuildName),
	{ok, pt:pack(47008, <<GuildNameLen:16, NewGuildName/binary>>)};

%% 领取税收
write(47009, [Sta, Num]) ->
	{ok, pt:pack(47009, <<Sta:8, Num:32>>)};

%% 鼓舞更新
write(47011, CastleRushAngry) ->
	{ok, pt:pack(47011, <<CastleRushAngry:16>>)};

%% 使用鼓舞技能
write(47012, Sta) ->
	{ok, pt:pack(47012, <<Sta:8>>)};

%% 九霄城主信息 
write(47013, [Lv, Realm, Career, Sex, Light, NickName, GuildName]) ->
	NewNickName = tool:to_binary(NickName),
  	NickNameLen = byte_size(NewNickName),
	NewGuildName = tool:to_binary(GuildName),
  	GuildNameLen = byte_size(NewGuildName),
	{ok, pt:pack(47013, <<Lv:16, Realm:8, Career:32, Sex:8, Light:8, NickNameLen:16, NewNickName/binary, GuildNameLen:16, NewGuildName/binary>>)};

%% 攻城战防守方更换
write(47014, [PlayerId, Sta]) ->
	{ok, pt:pack(47014, <<PlayerId:32, Sta:8>>)};

%% 城主更新
write(47015, Sta) ->
	{ok, pt:pack(47015, <<Sta:8>>)};

%% 攻城战奖励 - 获取物品
write(47016, [AwardGoods, FeatMember]) ->
	ALen = length(AwardGoods),
	ACoded = lists:map(fun({GoodsId, Num}) ->
		<<GoodsId:32, Num:32>>
	end, AwardGoods),
	ABin = tool:to_binary(ACoded),
	FLen = length(FeatMember),
	FCoded = lists:map(fun([PlayerId, PlayerName, Feats]) ->
		{PLen, PBin} = lib_guild_inner:string_to_binary_and_len(PlayerName),
		<<PlayerId:32, PLen:16, PBin/binary, Feats:32>>
	end, FeatMember),
	FBin = tool:to_binary(FCoded),
	{ok, pt:pack(47016, <<FLen:16, FBin/binary, ALen:16, ABin/binary>>)};

%% 攻城战奖励 - 物品分配物品
write(47017, [Result, GoodsTypeId, NewNum]) ->
	{ok, pt:pack(47017, <<Result:16, GoodsTypeId:32, NewNum:32>>)};

%% 攻城战奖励 - 物品自动分配
write(47018, [Result]) ->
	{ok, pt:pack(47018, <<Result:16>>)};

write(_Cmd, _R) ->
	io:format("NO MATCH WRITE ~p~n", [[_Cmd, _R]]),
    {ok, pt:pack(0, <<>>)}.
