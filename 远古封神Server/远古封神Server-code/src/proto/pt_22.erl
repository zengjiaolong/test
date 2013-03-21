%%%------------------------------------
%%% @Module     : pt_22
%%% @Author     : ygzj
%%% @Created    : 2010.10.06 
%%% @Description: 排行榜协议处理 
%%%------------------------------------
-module(pt_22).
-export(
	[
	 	read/2, 
		write/2,
		pack_arena_rank_list/1
	]
).
-include("common.hrl").
-include("record.hrl").

%%
%%客户端 -> 服务端 ----------------------------
%%

%% 查询人物排行榜
read(22001, <<Realm:8, Career:8, Sex:8, Type:8>>) ->
    {ok, [Realm, Career, Sex, Type]};

%% %% 查询装备排名
read(22002, <<Type:8>>) ->
    {ok, Type};

%% 查询帮会排名
read(22003, <<Type:8>>) ->
    {ok, Type};

%%宠物排行
read(22004, _) ->
	{ok, []};

%%封神台霸主榜
read(22005, _) ->
	{ok, []};

%%氏族战排行
read(22006, _) ->
	{ok, []};
%%22007 上场个人功勋排行
read(22007, _) ->
	{ok, []};

%%镇妖台排行
read(22008, _) ->
	{ok, []};
read(22009, _) ->
	{ok, []};

%%22010	魅力值排行榜
read(22010, _) ->
	{ok, []};

%%22011	成就点排行榜
read(22011, _) ->
	{ok, []};

%%诛仙台霸主榜
read(22012, _) ->
	{ok, []};

%%战场排行上一场排行
read(22013, _) ->
	{ok, []};

%%总排行战场总排行和周排行RankType
read(22014, <<RankType:8>>) ->
	{ok, RankType};

%%查询某人战斗力的排名(只查询前100名中的名次，返回结果超过0说明没有给其排名)
read(22015, <<PlayerId:32>>) ->
	{ok, PlayerId};

%%神器排行
read(22016, _) ->
	{ok, []};

%%坐骑排行
read(22017, _) ->
	{ok, []};

%%单人镇妖竞技排行
read(22018,_)->
	{ok,[1]};

%%领取单人镇妖竞技排行奖励
read(22019,_)->
	{ok,[]};

read(_, _) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%% 查询人物排名
write(22001, []) ->
    {ok, pt:pack(22001, <<0:16>>)};     %% 无数据
%%write(22001, [RankList]) ->
write(22001, RankList) ->
%% RankList = RoleRank#ets_rank.rank_list,
    F = fun(Info) ->
            [Rank, Id, Nick, Sex, Career, Realm, GuildName, Value, Vip] = Info,
			Nick1 = tool:to_binary(Nick), 
            Len1 = byte_size(Nick1),
			GuildName1 = tool:to_binary(GuildName),
            Len2 = byte_size(GuildName1),
            <<Rank:16, Id:32, Len1:16, Nick1/binary, Vip:8, Sex:8, Realm:8, Career:8, Len2:16, GuildName1/binary, Value:32>>
    end,
    Size = length(RankList),
    BinList = tool:to_binary([F(Info) || Info <- RankList]),
    {ok, pt:pack(22001, <<Size:16, BinList/binary>>)};

%% 查询装备排名
write(22002, []) ->
    {ok, pt:pack(22002, <<0:16>>)};     %% 无数据
write(22002, [EquipRank]) ->
    RankList = EquipRank#ets_rank.rank_list,
    F = fun(Info) ->
            [Rank, GoodsId, GoodsName, PlayerId, PlayerName, Realm, Guild, Score, _Vip] = Info,
			GoodsName1 = tool:to_binary(GoodsName), 
            Len1 = byte_size(GoodsName1),
			PlayerName1 = tool:to_binary(PlayerName),
            Len2 = byte_size(PlayerName1),
			GuildName1 = tool:to_binary(Guild),
            Len3 = byte_size(GuildName1),
            NewScore = trunc(Score),
            <<Rank:16, GoodsId:32, Len1:16, GoodsName1/binary, PlayerId:32, Len2:16, 
					PlayerName1/binary, Realm:8, Len3:16, GuildName1/binary, NewScore:32>>
    end,
    Size = length(RankList),
    BinList = tool:to_binary([F(Info) || Info <- RankList]),
    {ok, pt:pack(22002, <<Size:16, BinList/binary>>)};

%% 查询帮会排名
write(22003, []) ->
    {ok, pt:pack(22003, <<0:16>>)};
write(22003, [GuildRank]) ->
    RankList = GuildRank#ets_rank.rank_list,
    F = fun(Info) ->
            [Rank, Id, Name, Realm, Funds, Chief_name, MemberNum, Level] = Info,
			Name1 = tool:to_binary(Name), 
            Name_len = byte_size(Name1),
			Chief_name1 = tool:to_binary(Chief_name),
			Chief_name_len = byte_size(Chief_name1),
            <<Rank:16, Id:32, Name_len:16, Name1/binary, Funds:32, Chief_name_len:16, 
			  Chief_name1/binary, Realm:8, MemberNum:16, Level:8>>
    end,
    Size = length(RankList),
    BinList = tool:to_binary([F(Info) || Info <- RankList]),
    {ok, pt:pack(22003, <<Size:16, BinList/binary>>)};

%%宠物排行榜
write(22004, []) ->
	Data = <<0:16>>,
	{ok, pt:pack(22004, Data)};
write(22004, [RankPet]) ->
	RankList = RankPet#ets_rank.rank_list,
	F = fun(Info) ->
				[Rank, PetId, PetName, PlayerId, PlayerName, PetLevel, PetAptitude, Grow,Point, Vip] = Info,
				PetNameBin = tool:to_binary(PetName),
				PetNameBinLen = byte_size(PetNameBin),
				PlayerNameBin = tool:to_binary(PlayerName),
				PlayerNameBinLen = byte_size(PlayerNameBin),
				<<Rank:8, PetId:32, PetNameBinLen:16, PetNameBin/binary, PlayerId:32,
				  PlayerNameBinLen:16, PlayerNameBin/binary, Vip:8, PetLevel:8, PetAptitude:8, Grow:8,Point:32>>
		end,
	Size = length(RankList),
	BinData = tool:to_binary([F(Elem) || Elem <- RankList]),
	Data = <<Size:16, BinData/binary>>,
	{ok, pt:pack(22004, Data)};
	
%% 查询封神台霸主
write(22005, FstGods) ->
    F = fun([{Loc, _Uid, Nick, ThruTime}]) ->
		NewNick = tool:to_binary(Nick), 
      	NewLen = byte_size(NewNick),
      	<<ThruTime:32, Loc:8, NewLen:16, NewNick/binary>>
    end,
    Size = length(FstGods),
    BinList = tool:to_binary([F(God) || God <- FstGods]),
    {ok, pt:pack(22005, <<Size:16, BinList/binary>>)};

%%氏族战排行
write(22006, []) ->
    {ok, pt:pack(22006, <<0:16>>)};
write(22006, [GuildRank]) ->
    RankList = GuildRank#ets_rank.rank_list,
    F = fun(Info) ->
            [Order, Name, Level, Combat_all_num, Combat_Num] = Info,
			Name1 = tool:to_binary(Name), 
            Name_len = byte_size(Name1),
            <<Order:8, Name_len:16, Name1/binary, Level:8, Combat_all_num:32, Combat_Num:16>>
    end,
    Size = length(RankList),
    BinList = tool:to_binary([F(Info) || Info <- RankList]),
    {ok, pt:pack(22006, <<Size:16, BinList/binary>>)};

%%22007 上场个人功勋排行
write(22007, RankInfo) -> 
	{RankInfoLen, RankInfoBin} = handle_skymemrank_list(RankInfo), 
	{ok, pt:pack(22007, <<RankInfoLen:16, RankInfoBin/binary>>)};

%% 镇妖台（单）排行
write(22008, TdList) ->
    F = fun([{_Id, _Uid, AttNum, GuildName, Nick, Career, Realm, HorTd, MgcTd, Vip}]) ->
		Nick1 = tool:to_binary(Nick),
      	NLen = byte_size(Nick1),
		GuildName1 = tool:to_binary(GuildName),
		GLen = byte_size(GuildName1),
       	<<NLen:16, Nick1/binary, Vip:8, Career:8, Realm:8, GLen:16, GuildName1/binary, AttNum:8, HorTd:32, MgcTd:32>>
    end,
    Size = length(TdList),
    BinList = tool:to_binary([F(Td) || Td <- TdList]),
    {ok, pt:pack(22008, <<Size:16, BinList/binary>>)};

%% 镇妖台（多）排行
write(22009, TdList) ->
    F = fun([{_Id, HorTd, AttNum, MgcTd, Nicks}]) ->
		Nick1 = tool:to_binary(Nicks), 
      	NLen = byte_size(Nick1),
      	<<NLen:16, Nick1/binary, AttNum:8, HorTd:32, MgcTd:32>>
    end,
    Size = length(TdList),
    BinList = tool:to_binary([F(Td) || Td <- TdList]),
    {ok, pt:pack(22009, <<Size:16, BinList/binary>>)};

%%22010	魅力值排行榜
write(22010, []) ->
    {ok, pt:pack(22010, <<0:16>>)};     %% 无数据
write(22010, [CharmRank]) ->
	List = CharmRank#ets_rank.rank_list,
	F = fun(Info) ->
				[Order, PId, PlayerName, Career, Realm, GuildName, Title, Charm, Vip] = Info,
				PNameBin = tool:to_binary(PlayerName),
				PNameLen = byte_size(PNameBin),
				GNameBin = tool:to_binary(GuildName),
				GNameLen = byte_size(GNameBin),
				<<Order:8, PId:32, PNameLen:16, PNameBin/binary, Vip:8, Career:8, Realm:8, GNameLen:16, GNameBin/binary, Title:32, Charm:32>>
		end, 
	Size = length(List),
    BinList = tool:to_binary([F(CharmInfo) || CharmInfo <- List]),
    {ok, pt:pack(22010, <<Size:16, BinList/binary>>)};


%%22010	成就点排行榜
write(22011, []) ->
    {ok, pt:pack(22011, <<0:16>>)};     %% 无数据
write(22011, [AchieveRank]) ->
	List = AchieveRank#ets_rank.rank_list,
	F = fun(Info) ->
				[Order, PId, PlayerName, Career, Realm, GuildName, Achieve, Vip] = Info,
				PNameBin = tool:to_binary(PlayerName),
				PNameLen = byte_size(PNameBin),
				GNameBin = tool:to_binary(GuildName),
				GNameLen = byte_size(GNameBin),
				<<Order:8, PId:32, PNameLen:16, PNameBin/binary, Vip:8, Career:8, Realm:8, GNameLen:16, GNameBin/binary, Achieve:32>>
		end, 
	Size = length(List),
    BinList = tool:to_binary([F(AchieveInfo) || AchieveInfo <- List]),
    {ok, pt:pack(22011, <<Size:16, BinList/binary>>)};

%% 查询诛仙台霸主
write(22012, ZxtGods) ->
    F = fun([{Loc, _Uid, Nick, ThruTime}]) ->
		NewNick = tool:to_binary(Nick), 
      	NewLen = byte_size(NewNick),
      	<<ThruTime:32, Loc:8, NewLen:16, NewNick/binary>>
    end,
    Size = length(ZxtGods),
    BinList = tool:to_binary([F(God) || God <- ZxtGods]),
    {ok, pt:pack(22012, <<Size:16, BinList/binary>>)};

%% 竞技场英雄榜上一场所有排名
write(22013, RankList) ->
	RankData = pack_arena_rank_list(RankList),
    {ok, pt:pack(22013, <<RankData/binary>>)};
	
%%总排行的竞技场排行榜(RankType 1周战绩排行	2总战绩排行)
write(22014, Data) ->
   [_RankType,ResultData] = Data,
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
    {ok, pt:pack(22014, <<ResultData_len:16,Data2/binary>>)};

%%查询某人战斗力的排名
write(22015, Data) ->
    {ok, pt:pack(22015, <<Data:32>>)};

%%神器排行
write(22016, []) ->
    {ok, pt:pack(22016, <<0:16>>)};     %% 无数据
write(22016, Data) ->
	F = fun([Order, PlayerId, Nickname, DeputyId, DeputyName, Color, Batt_Val, Vip]) ->
				PNameBin = tool:to_binary(Nickname),
				PNameLen = byte_size(PNameBin),
				DNameBin = tool:to_binary(DeputyName),
				DNameLen = byte_size(DNameBin),
				<<Order:8, PlayerId:32, PNameLen:16, PNameBin/binary, DeputyId:32, DNameLen:16, DNameBin/binary, Color:8, Batt_Val:32, Vip:8>>
		end, 
	Size = length(Data),
    BinData = tool:to_binary([F([Order, PlayerId, Nickname, DeputyId, DeputyName, Color, Batt_Val, Vip]) || [Order, PlayerId, Nickname, DeputyId, DeputyName, Color, Batt_Val, Vip] <- Data]),
    {ok, pt:pack(22016, <<Size:16, BinData/binary>>)};

%%坐骑排行
write(22017, []) ->
    {ok, pt:pack(22017, <<0:16>>)};     %% 无数据
write(22017, Data) ->
	F = fun([Order, PlayerId, Nickname, MountId, Name, Level, Color, Step, Mount_val, Vip]) ->
				PNameBin = tool:to_binary(Nickname),
				PNameLen = byte_size(PNameBin),
				DNameBin = tool:to_binary(Name),
				DNameLen = byte_size(DNameBin),
				<<Order:8, PlayerId:32, PNameLen:16, PNameBin/binary, MountId:32, DNameLen:16, DNameBin/binary, Level:16, Color:8, Step:8, Mount_val:32, Vip:8>>
		end, 
	Size = length(Data),
    BinData = tool:to_binary([F([Order, PlayerId, Nickname, MountId, Name, Level, Color, Step, Mount_val, Vip]) || [Order, PlayerId, Nickname, MountId, Name, Level, Color, Step, Mount_val, Vip] <- Data]),
    {ok, pt:pack(22017, <<Size:16, BinData/binary>>)};

%% 镇妖台（单）排行
write(22018, [MyOrder,NextSec,OldOrder,Spt,BCoin,TdList]) ->
    F = fun({Id, _Uid, AttNum, GuildName, Nick, Career, Realm, HorTd, MgcTd, Vip,_}) ->
		Nick1 = tool:to_binary(Nick),
      	NLen = byte_size(Nick1),
		GuildName1 = tool:to_binary(GuildName),
		GLen = byte_size(GuildName1),
       	<<Id:32,NLen:16, Nick1/binary, Vip:8, Career:8, Realm:8, GLen:16, GuildName1/binary, AttNum:8, HorTd:32, MgcTd:32>>
    end,
    Size = length(TdList),
    BinList = tool:to_binary([F(Td) || Td <- TdList]),
    {ok, pt:pack(22018, <<MyOrder:32,NextSec:32,OldOrder:32,Spt:32,BCoin:32,Size:16, BinList/binary>>)};

write(22019,[Res])->
	{ok,pt:pack(22019,<<Res:16>>)};

write(_Cmd, _R) ->
    {ok, pt:pack(0, <<>>)}.

%%22007 上场个人功勋排行 内部方法
handle_skymemrank_list(ThreeList) ->
	Len = length(ThreeList),
	List = lists:map(fun(Elem) ->
							 {PlayerName, Career, PLv, KillFoe, DieC, GFlags, MNuts, Feat} = Elem,
							 {PLen, PBin} = lib_guild_inner:string_to_binary_and_len(PlayerName),
							 <<PLen:16, PBin/binary, Career:8, PLv:8, KillFoe:16, DieC:16, GFlags:16, MNuts:16, Feat:32>>
					 end, ThreeList),
	BinData = tool:to_binary(List),
	{Len, BinData}.

%% 打包战场排名列表
pack_arena_rank_list(RankList) ->
	DataLen = length(RankList),
 	F = fun({_PlayerId, Nickname, Realm, Career, Lv, Camp, Type, Score}) ->
   		NickName1 = tool:to_binary(Nickname),
      	Nick_len = byte_size(NickName1),
     	<<Nick_len:16, NickName1/binary, Realm:8, Career:8, Lv:8, Camp:8, Type:16, Score:16>>
	end,
    Data = tool:to_binary([F(ArenaWeek) || ArenaWeek<- RankList]),
    <<DataLen:16, Data/binary>>.
