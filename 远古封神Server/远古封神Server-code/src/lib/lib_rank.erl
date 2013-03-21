%%%------------------------------------
%%% @Module     : lib_rank
%%% @Author     : ygzj
%%% @Created    : 2010.10.06
%%% @Description: 排行榜处理函数
%%%------------------------------------
-module(lib_rank).
-include("common.hrl").
-include("record.hrl").
-include("rank.hrl").
-include("guild_info.hrl").
-include("achieve.hrl").

-compile(export_all).


%% @doc  创建排行榜ETS表
init_rank() ->
    %% 创建排行榜ETS表
    ets:new(?ETS_RANK, [named_table, public, set, {keypos, 2},?ETSRC, ?ETSWC]),
	%% 封神台
	ets:new(?ETS_FST_GOD, [named_table, public, set, {keypos, 1},?ETSRC, ?ETSWC]),
	%% 镇妖台（单）
	ets:new(?ETS_TD_S, [named_table, public, ordered_set, {keypos, 1},?ETSRC, ?ETSWC]),
	%% 镇妖台（多）
	ets:new(?ETS_TD_M, [named_table, public, ordered_set, {keypos, 1},?ETSRC, ?ETSWC]),
	%% 诛仙台
	ets:new(?ETS_ZXT_GOD, [named_table, public, set, {keypos, 1},?ETSRC, ?ETSWC]),
	%%镇妖单人竞技榜
	ets:new(?ETS_TD_S_ALL, [named_table, public, set, {keypos, 1},?ETSRC, ?ETSWC]), 
	ok. 

%% @doc  从数据库中读取数据，更新排行榜(Order为0全部加载，1-9分别加载数据 10分钟一次循环)
%%添加新排行请注意分两种情况(Order为0或不为0的情况)
update_rank(Order) ->
	Rem = Order rem 10,
	if Order == 0 -> %%全部加载
		   loop_query_batt_value(?NUM_LIMIT),                         %%获取人物战斗力相关排行
		   loop_query_lv(?NUM_LIMIT),   							    %% 获取人物等级相关排行
		   loop_query_coin_sum(?NUM_LIMIT),   						%% 获取人物财富相关排行
		   loop_query_realm_honor(?NUM_LIMIT),   					    %% 获取人物部落荣誉相关排行
		   guildbat_rank(),   										        %% 帮派战排行
		   
		   EquipRanks = loop_query_equip(?EQUIP_RANK_TYPE_LIST),   %% 获取装备相关排行
		   insert_rank_info(?ETS_RANK, EquipRanks),
		   GuildRanks = mod_guild:rank_guild(),   					     %% 获取帮会相关排行
		   insert_rank_info(?ETS_RANK, GuildRanks),
		   
		   PetRanks = loop_query_pet(),							         %% 获取宠物相关排行
		   insert_rank_info(?ETS_RANK, PetRanks),
		   
		   CharmRanks = loop_query_charm(),						         %% 人物魅力值相关排行
		   insert_rank_info(?ETS_RANK, CharmRanks),
		   AchieveRanks = loop_query_achieve(),					         %% 成就点相关排行
		   insert_rank_info(?ETS_RANK, AchieveRanks),
		   
		   FstGods = loop_fst_gods(),								         %% 封神台霸主榜
		   ets:delete_all_objects(?ETS_FST_GOD),
		   insert_rank_info(?ETS_FST_GOD, FstGods),
		   TDSRanks = loop_tds_rank(),								     %% 镇妖台（单）排行榜
		   insert_rank_info(?ETS_TD_S, TDSRanks),
		   TDSRanksAll = loop_tds_rank_all(),								     %% 镇妖台（单）竞技榜
		   insert_rank_info(?ETS_TD_S_ALL, TDSRanksAll),
		   TDMRanks = loop_tdm_rank(),								     %% 镇妖台（多）排行榜
		   insert_rank_info(?ETS_TD_M, TDMRanks),
		   ZxtGods = loop_zxt_gods(),								    %% 诛仙台 霸主榜
		   ets:delete_all_objects(?ETS_ZXT_GOD),
		   insert_rank_info(?ETS_ZXT_GOD, ZxtGods),
		   
		   lib_title:rank_change_titles(),                                  %%触发更新全服的称号集数据
		   
		   DeputyEquipRanks = loop_deputy_equip(),                      %% 神器战力排行
		   insert_rank_info(?ETS_RANK, DeputyEquipRanks),
		   
		   MountRanks = loop_mount(),                                   %% 坐骑战力排行
		   insert_rank_info(?ETS_RANK, MountRanks),
		   
		   ok;
	   Order > 10 andalso Rem == 1 ->                                 %%从第11分钟开始加加载部分数据
		   loop_query_batt_value(?NUM_LIMIT),                        %%获取人物战斗力相关排行
		   loop_query_lv(?NUM_LIMIT),   							   %% 获取人物等级相关排行
		   loop_query_coin_sum(?NUM_LIMIT),   					    %% 获取人物财富相关排行
		   loop_query_realm_honor(?NUM_LIMIT),   					    %% 获取人物部落荣誉相关排行
		   guildbat_rank(),   										        %% 帮派战排行
		   ok;
	   Order > 10 andalso Rem == 2 ->                                   %%从第12分钟开始加加载部分数据
		   EquipRanks = loop_query_equip(?EQUIP_RANK_TYPE_LIST),   %% 获取装备相关排行
		   insert_rank_info(?ETS_RANK, EquipRanks),
		   GuildRanks = mod_guild:rank_guild(),   					      %% 获取帮会相关排行
		   insert_rank_info(?ETS_RANK, GuildRanks),
		   ok;
	   Order > 10 andalso Rem == 3 ->                                   %%从第13分钟开始加加载部分数据
		   PetRanks = loop_query_pet(),							         %% 获取宠物相关排行
		   insert_rank_info(?ETS_RANK, PetRanks),
		   ok;
	    Order > 10 andalso Rem == 4 ->                                 %%从第14分钟开始加加载部分数据
		   CharmRanks = loop_query_charm(),						        %% 人物魅力值相关排行
		   insert_rank_info(?ETS_RANK, CharmRanks),
		   AchieveRanks = loop_query_achieve(),					        %% 成就点相关排行
		   insert_rank_info(?ETS_RANK, AchieveRanks),
		   ok;
	   Order > 10 andalso Rem == 5 ->                                  %%从第15分钟开始加加载部分数据
		   FstGods = loop_fst_gods(),								        %% 封神台霸主榜
		   ets:delete_all_objects(?ETS_FST_GOD),
		   insert_rank_info(?ETS_FST_GOD, FstGods),
		   TDSRanks = loop_tds_rank(),								    %% 镇妖台（单）排行榜
		   insert_rank_info(?ETS_TD_S, TDSRanks),
		   TDSRanksAll = loop_tds_rank_all(),								    %% 镇妖台（单）排行榜
		   insert_rank_info(?ETS_TD_S_ALL, TDSRanksAll),
		   TDMRanks = loop_tdm_rank(),								    %% 镇妖台（多）排行榜
		   insert_rank_info(?ETS_TD_M, TDMRanks),
		   ZxtGods = loop_zxt_gods(),								    %% 诛仙台 霸主榜
		   ets:delete_all_objects(?ETS_ZXT_GOD),
		   insert_rank_info(?ETS_ZXT_GOD, ZxtGods),
		   ok;
		Order > 10 andalso Rem == 6 ->                                 %%从第16分钟开始加加载部分数据
		   lib_title:rank_change_titles(),                                  %%触发更新全服的称号集数据
		   ok;
	   Order > 10 andalso Rem == 7 ->                                 %%从第17分钟开始加加载部分数据
		   DeputyEquipRanks = loop_deputy_equip(),                      %% 神器战力排行
		   insert_rank_info(?ETS_RANK, DeputyEquipRanks),
		   ok;
		  Order > 10 andalso Rem == 8 ->                                 %%从第18分钟开始加加载部分数据
		   MountRanks = loop_mount(),                                   %% 坐骑战力排行
		   insert_rank_info(?ETS_RANK, MountRanks),
		   ok;
		true -> 
			skip
	end.

%% @doc  将列表的每个元素（列表）加上次序信息
%% @spec add_order([], List, FirstNum) -> NewList
%% @var  List    : 需为每个元素（列表）添加序号的初始列表
%%       NewList : 添加序号后的新列表
add_order(AccList, [], _) ->
    lists:reverse(AccList);
add_order(AccList, [Info | List], N) ->
    NewInfo = [N | Info],
    add_order([NewInfo | AccList], List, N + 1).

%% @doc  根据物品类型ID查询ETS表获得物品名（二进制数据）
%% @spec get_equip_name(GoodsTypeId) -> GoodsName
get_equip_name(GoodsTypeId) ->
    case ets:lookup(?ETS_BASE_GOODS, GoodsTypeId) of
        [] ->
            <<"">>;
        [Info] ->
            Info#ets_base_goods.goods_name
    end.

%% @doc  查询ETS表获取请求的装备排行榜
%% @spec get_equip_rank(Type) -> RankInfo
get_equip_rank_order(PidSend,Type) ->
	RankInfo = get_equip_rank(Type),
	{ok, BinData} = pt_22:write(22002, RankInfo),
   	lib_send:send_to_sid(PidSend, BinData).

get_equip_rank(Type) when is_integer(Type) ->
    case Type >= 1 andalso Type =< 2 of
        true -> ets:lookup(?ETS_RANK, ?EQUIP_RANK_TYPE_ID);
        false -> []
    end;
get_equip_rank(_) -> [].

%% @doc  由数据库中取出的数据转换得到排行榜所需信息
%% @spec get_equip_rank_list(RankList, PlayerInfoList) -> NewRankList
get_equip_rank_list(RankList, PlayerInfoList) ->
    update_goods_info(RankList, PlayerInfoList, 1, []).

%% @doc  由数据库中取出的数据转换得到排行榜所需信息
%% @spec get_equip_rank_list(RankList, PlayerInfoList) -> NewRankList
get_pet_rank_list(RankList, PlayerInfoList) ->
	update_pet_info(RankList, PlayerInfoList, 1, []).

%% @doc  由数据库中取出的数据转换得到排行榜所需信息(魅力值排行)
get_charm_rank_list(RankList, PlayerInfoList) ->
	update_charm_info(RankList, PlayerInfoList, 1, []).

%% @doc  由数据库中取出的数据转换得到排行榜所需信息(魅力值排行)
get_achieve_rank_list(RankList, PlayerInfoList) ->
	update_achieve_info(RankList, PlayerInfoList, 1, []).

%% 获取氏族排名信息
rank_guild()->
	loop_query_guild(?GUILD_RANK_TYPE_LIST).

%%氏族战排行
query_guildbat_rank_order(PidSend) ->
	RankInfo = query_guildbat_rank(),
	{ok, BinData} = pt_22:write(22006, RankInfo),
	lib_send:send_to_sid(PidSend, BinData).
query_guildbat_rank() ->
	 ets:lookup(?ETS_RANK, ?GUILDBAT_RANK_TYPE_ID).

%% @doc  查询ETS表获取请求的排行榜
%% @spec get_guild_rank(TypeNum | Type) -> RankInfo
get_guild_rank_order(PidSend,Type) ->
	RankInfo = get_guild_rank(Type),
	{ok, BinData} = pt_22:write(22003, RankInfo),
    lib_send:send_to_sid(PidSend, BinData).

get_guild_rank(TypeNum) when is_integer(TypeNum) ->
    ets:lookup(?ETS_RANK, ?GUILD_RANK_TYPE_ID);
get_guild_rank(Type) ->
    case lists:keysearch(Type, 2, ?GUILD_RANK_TYPE_LIST) of
        {value, {TypeNum, _}} ->
            ets:lookup(?ETS_RANK, ?GUILD_RANK_TYPE_ID);
        false ->
            []
    end.
%%宠物排行榜
get_pet_rank_order(PidSend) ->
	RankInfo = get_pet_rank(),
	{ok, BinData} = pt_22:write(22004, RankInfo),
	lib_send:send_to_sid(PidSend, BinData).
get_pet_rank() ->
	ets:lookup(?ETS_RANK, ?PET_RANK_TYPE_ID).

%%22010	魅力值排行榜
get_charm_rank_order(PidSend) ->
	RankInfo = get_charm_rank(),
	{ok, BinData} = pt_22:write(22010, RankInfo),
	lib_send:send_to_sid(PidSend, BinData).
get_charm_rank() ->
	ets:lookup(?ETS_RANK, ?CHARM_RANK_ID).

%%22011 成就点排行榜
get_achieve_rank_order(PidSend) ->
	RankInfo = get_achieve_rank(),
	{ok, BinData} = pt_22:write(22011, RankInfo),
	lib_send:send_to_sid(PidSend, BinData).
get_achieve_rank() ->
	ets:lookup(?ETS_RANK, ?ACHIEVE_RANK_ID).

%% 封神台霸主榜
get_fst_god_order(PidSend) ->
	RankInfo = get_fst_god(),
	{ok, BinData} = pt_22:write(22005, RankInfo),
	lib_send:send_to_sid(PidSend, BinData).
get_fst_god() ->
	ets:match(?ETS_FST_GOD, _ = '$1').

%% 诛仙台霸主榜
get_zxt_god_order(PidSend) ->
	RankInfo = get_zxt_god(),
	{ok, BinData} = pt_22:write(22012, RankInfo),
	lib_send:send_to_sid(PidSend, BinData).
get_zxt_god() ->
	ets:match(?ETS_ZXT_GOD, _ = '$1').

%% 镇妖台（单）
get_tds_rank_order(PidSend) ->
	RankInfo = get_tds_rank(),
	{ok, BinData} = pt_22:write(22008, RankInfo),
	lib_send:send_to_sid(PidSend, BinData).
get_tds_rank() ->
	ets:match(?ETS_TD_S, _ = '$1').

%%单人竞技榜
get_tds_rank_order_all(PidSend,PlayerId,Lv,Type)->
	{OldOrder,Spt1,BCoin1} = 
		case select_single_td_award(PlayerId) of
			[]->{0,0,0};
			[Award]->
				{Spt,BCoin} = single_td_award(Lv,Award#ets_single_td_award.order),
				{Award#ets_single_td_award.order,Spt,BCoin}
		end,
	if Type =:=0 andalso OldOrder =:= 0->skip;
	   true->
		   {MyOrder,RankInfo} = get_tds_rank_all(PlayerId),
			NextSec = single_td_rank_timer(),
			{ok, BinData} = pt_22:write(22018, [MyOrder,NextSec,OldOrder,Spt1,BCoin1,RankInfo]),
			lib_send:send_to_sid(PidSend, BinData)
	end.

single_td_rank_timer()->
	NowSec = util:get_today_current_second(),
	Timer = 22*3600+0*60,
	case NowSec < Timer of
		true->
			NextSec = Timer - NowSec;
		false->
			NextSec = Timer + 86400-NowSec
	end,
	NextSec.

get_tds_rank_all(PlayerId)->
	Rank = get_single_td_rank_info(),
	MaxOrder = length(Rank),
	case lists:keyfind(PlayerId, 2, Rank) of
		false->
			if MaxOrder > 200-> 
				OrderList = check_tds_rank_order(0,10,MaxOrder+10,10,[]),
				{0,get_tds_rank_all_loop(OrderList,Rank,[])};
			   MaxOrder > 100 ->
				   OrderList = check_tds_rank_order(0,10,MaxOrder+5,5,[]),
				   {0,get_tds_rank_all_loop(OrderList,Rank,[])};
			   MaxOrder > 50 ->
				   OrderList = check_tds_rank_order(0,10,MaxOrder+2,2,[]),
				   {0,get_tds_rank_all_loop(OrderList,Rank,[])};
			   10 >= MaxOrder ->
				   {0,Rank};
			   true->
				   OrderList = check_tds_rank_order(0,10,MaxOrder+1,1,[]),
				   {0,get_tds_rank_all_loop(OrderList,Rank,[])}
			end;
		Info->
			{Order,_PlayerId, _AttNum, _GuildName, _Nick, _Career, _Realm, _HorTd, _MgcTd, _Vip,_Lv} = Info,
			if  200 < Order-> 
					OrderList = check_tds_rank_order(0,9,Order,10,[]),
					{Order,get_tds_rank_all_loop(OrderList,Rank,[Info])};
				100 < Order->
					OrderList = check_tds_rank_order(0,9,Order,5,[]),
					{Order,get_tds_rank_all_loop(OrderList,Rank,[Info])};
				50 < Order->
					OrderList = check_tds_rank_order(0,9,Order,2,[]),
					{Order,get_tds_rank_all_loop(OrderList,Rank,[Info])};
				10 >= Order ->
					if MaxOrder<10->
						  {Order,Rank};
					   true->
							OrderList = check_tds_rank_order(0,10,11,1,[]),
							{Order,get_tds_rank_all_loop(OrderList,Rank,[])}
					end;
				true ->
					OrderList = check_tds_rank_order(0,9,Order,1,[]),
					{Order,get_tds_rank_all_loop(OrderList,Rank,[Info])}
			end
	end.

check_tds_rank_order(NowNum,MaxNum,Order,Num,OrderList)->
	if NowNum =:=MaxNum->lists:reverse(OrderList);
	   true->
			NewOrder = Order-Num,
			check_tds_rank_order(NowNum+1,MaxNum,NewOrder,Num,[NewOrder|OrderList])
	end.

get_tds_rank_all_loop(_,[],Info)->Info;
get_tds_rank_all_loop([],_Rank,Info)->Info;
get_tds_rank_all_loop([Order|OrderList],Rank,Info)->
	case lists:keyfind(Order, 1, Rank) of
		false-> get_tds_rank_all_loop(OrderList,Rank,Info);
		NewInfo ->
			get_tds_rank_all_loop(OrderList,Rank,[NewInfo|Info])
	end.


%% 镇妖台（多）
get_tdm_rank_order(PidSend) ->
	RankInfo = get_tdm_rank(),
	{ok, BinData} = pt_22:write(22009, RankInfo),
	lib_send:send_to_sid(PidSend, BinData).
get_tdm_rank() ->
	ets:match(?ETS_TD_M, _ = '$1').

%% @doc  对装备计算出评分，并返回相应信息
%% @spec get_new_goods_info_list([], GoodsInfoList) -> NewGoodsInfoList
get_new_goods_info_list(AccList, []) ->
    AccList;    
get_new_goods_info_list(AccList, GoodsInfoList) ->
    [[Id, GoodsTypeId, PlayerId, Level, Color, Stren] | Rest] = GoodsInfoList,
    NewAccList = [{Id, GoodsTypeId, PlayerId, Level * (0.5 * Color + 2) * 5  + Stren * 100} | AccList],
    get_new_goods_info_list(NewAccList, Rest).

%% @doc  获得用户信息
%% @spec get_player_info_list([], PlayerIdList) -> PlayerInfoList
get_player_info_list(AccList, []) ->
    AccList;    
get_player_info_list(AccList, PlayerIdList) ->
    [PlayerId | Rest] = PlayerIdList,
    case ets:lookup(?ETS_ONLINE, PlayerId) of
        [] ->
			case mod_cache:get({lib_rank,get_player_info_list,PlayerId}) of
				[] ->
					%% 不在线要从数据库中取数据
            		case db_agent:rank_get_player_info_list(?SLAVE_POOLID, PlayerId) of
                		[PlayerInfo] ->
							%%玩家不在线，个人信息缓存3小时
							mod_cache:set({lib_rank,get_player_info_list,PlayerId},PlayerInfo,10800),
                    		PlayerInfo;
                		[] ->
                    		PlayerInfo = [0, <<"">>, 0, <<"">>, 0]
            		end;
				CacheData ->
					PlayerInfo = CacheData
			end;
        [OnlinePlayer] ->       %% 人物在线则从ETS表中取数据
            PlayerName =  tool:to_binary(OnlinePlayer#player.nickname),
			GuildName =  tool:to_binary(OnlinePlayer#player.guild_name),
            PlayerInfo = [PlayerId, PlayerName, OnlinePlayer#player.realm, GuildName, OnlinePlayer#player.career, OnlinePlayer#player.vip]
    end,
    get_player_info_list([PlayerInfo | AccList], Rest).

%% @doc  查询ETS表获取请求的排行榜
%% @spec get_role_rank(Realm, Career, Sex, TypeNum) -> RankInfo
%% @var     TypeNum = integer()
get_role_rank(Realm, Career, Sex, TypeNum) when is_integer(TypeNum) ->
    RankTypeId = get_role_rank_type(Realm, Career, Sex, TypeNum),
    ets:lookup(?ETS_RANK, RankTypeId);
get_role_rank(_, _, _, _) -> [].

%% @doc  获得人物对应排行榜类型ID
%% @spec get_role_rank_type(Realm, Career, Sex, Type | TypeNum) -> RankTypeId | error
get_role_rank_type(Realm, Career, Sex, TypeNum) when is_integer(TypeNum) ->
    ?ROLE_RANK_TYPE_ID;
get_role_rank_type(Realm, Career, Sex, Type) ->
    case is_atom(Type) of
        true ->
            case lists:keysearch(Type, 2, ?ROLE_RANK_TYPE_LIST) of
                {value, {TypeNum, _}} ->
                    ?ROLE_RANK_TYPE_ID;
                false ->        %% 无此类型
                    error
            end;
        false ->
            error
    end.

%% @doc  插入记录至ETS表
insert_rank_info(Tab, List) ->
    lists:foreach(fun(Record) -> ets:insert(Tab, Record) end, List),
    ok.

%% @doc  在列表列表（元素为列表的列表）中搜索特定元素（第N列搜索值为Key的元素）
%% @spec keysearch(Key, N, ListList) -> {ok, Value} | false
keysearch(_, _, []) ->
    false;
keysearch(Key, N, List) ->
    [List1 | NewList] = List,
    case lists:nth(N, List1) of
        Key ->
            {ok, List1};
        _ ->
            keysearch(Key, N, NewList)
    end.

%% @doc  根据装备类型列表查询相应排行信息
%% @spec loop_query_equip(EquipTypeList) -> AllEquipRanks
loop_query_equip(EquipTypeList) ->
    F = fun(Type) ->
            InfoList = query_equip(Type),                            %% 所有玩家物品信息列表
			RankList = lists:map(fun(Info) -> erlang:list_to_tuple(Info) end,InfoList),
            PlayerIdList = lists:usort([PlayerId || {_, _, PlayerId, _} <- RankList]),         %% 去除重复Id
            PlayerInfoList = get_player_info_list([], PlayerIdList),    %% 获得玩家信息
            NewRankList = get_equip_rank_list(RankList, PlayerInfoList),
            make_rank_info(?EQUIP_RANK_TYPE_ID, NewRankList)
    end,
	lists:map(F, EquipTypeList).

loop_deputy_equip() ->   %% 神器战力排行
	BattRanks = query_deputy_equip(),
	PlayerValueList = [{PlayerId,[Id,Prof_lv,Color,Batt_Val]} || [Id,PlayerId,Prof_lv,Color,Batt_Val] <- BattRanks],
	PlayerIdList = [Player_Id || [_Id,Player_Id,_Prof_lv,_Color,_Batt_Val] <- BattRanks],
	PlayerInfoList = db_agent:get_player_mult_properties([id, nickname, sex, career, realm, guild_name, vip],lists:flatten(PlayerIdList)), 
	F = fun([Id, Nickname, _Sex, _Career, _Realm, _Guild_name, Vip]) ->
				{_Id, Value}  = lists:keyfind(Id, 1, PlayerValueList),
				[Id1,Prof_lv1,Color1,Batt_Val1] = Value,
				DeputyName = lib_deputy:get_deputy_equip_name(Prof_lv1), 
				[Id, Nickname, Id1,DeputyName,Color1,Batt_Val1,Vip]
		end,
	BattRanks2 = [F([Id, Nickname, Sex, Career, Realm, Guild_name, Vip]) || {_Key,[Id, Nickname, Sex, Career, Realm, Guild_name,Vip]} <- PlayerInfoList],
	BattRanks3 = lists:sort(fun([_PlayerId2, _Nickname2, _Id2,_DeputyName2,_Color2,Batt_Val2,_Vip2],[_PlayerId3, _Nickname3, _Id3,_DeputyName3,_Color3,Batt_Val3,_Vip3]) ->
									 Batt_Val2 >= Batt_Val3 end,BattRanks2),
    [make_rank_info(?DEPUTY_EQUIP_RANK_TYPE_ID, BattRanks3)].

%% 坐骑战力排行
loop_mount() ->
	BattRanks1 = query_mount(),
	PlayerValueList = [{PlayerId,MountId,Name,Level,Color,Step,Mount_val} || [PlayerId,MountId,Name,Level,Color,Step,Mount_val] <- BattRanks1],
	PlayerIdList = [_Player_Id || [_Player_Id,_MountId,_Name,_Level,_Color,_Step,_Mount_val] <- BattRanks1],
	PlayerInfoList = db_agent:get_player_mult_properties([id, nickname, vip],lists:flatten(PlayerIdList)), 
	F = fun([Id, Nickname, Vip]) ->
				{_Id, MountId, Name, Level, Color, Step, Mount_val}  = lists:keyfind(Id, 1, PlayerValueList),
				[Id, Nickname, MountId, Name, Level, Color, Step, Mount_val, Vip]
		end,
	BattRanks2 = [F([Id, Nickname, Vip]) || {_Key,[Id, Nickname, Vip]} <- PlayerInfoList],
	BattRanks3 = lists:sort(fun([_Id1, _Nickname1, _MountId1,_Name1, _MountLevel1, _Color1, _Step1, Mount_val1, _Vip1],[_Id2, _Nickname2, _MountId2, _Name2,_MountLevel2, _Color2, _Step2, Mount_val2, _Vip2]) ->
									 Mount_val1 >= Mount_val2 end,BattRanks2),
	[make_rank_info(?MOUNT_RANK_TYPE_ID, BattRanks3)].


loop_query_pet() ->
	InfoList = query_pet(),%%获取所有的排在前面的宠物列表（100个）
	PetList = calc_pet_score(InfoList,[]),
%% 	RankList = lists:map(fun(Info) -> erlang:list_to_tuple(Info) end, PetList),
	PlayerIdList = lists:usort([PlayerId || {_PetId, _PetName, PlayerId, _PetLevel, _PetAptitude, _grow,_Point} <- PetList]),%% 去除重复Id
	PlayerInfoList = get_player_info_list([], PlayerIdList),    %% 获得玩家信息
	NewRankList = get_pet_rank_list(PetList, PlayerInfoList),
	[make_rank_info(?PET_RANK_TYPE_ID, NewRankList)].
			
%%计算灵兽评分
calc_pet_score([],PetList)->
	SortFun = fun({_,_,_,_,_,_,P1}, {_,_,_,_,_,_,P2}) ->
		P1 > P2 
	end,	
	lists:sort(SortFun, PetList);
calc_pet_score([Pet|PetBag],PetList)->
	[PetId, PetName, PlayerId, PetLevel, PetAptitude, Grow,Skill1,Skill2,Skill3,Skill4,Skill5] = Pet,
	P = round((PetLevel*Grow*PetAptitude/144+calc_skill_score([Skill1,Skill2,Skill3,Skill4,Skill5],0))),
	NewPet = {PetId, PetName, PlayerId, PetLevel, PetAptitude, Grow,P},
	calc_pet_score(PetBag,[NewPet|PetList]).

%%计算技能分数
calc_skill_score([],P)->P;
calc_skill_score([Skill|SkillBag],P)->
	NewSkill = util:string_to_term(tool:to_list(Skill)),
	[_SkillId,Lv,Step|_] = NewSkill,
	NewP = step(Step)*Lv*10/6,
	calc_skill_score(SkillBag,P+NewP).

%%技能介数换算系数
step(Step)->
	case Step of
		1->0.8;
		2->1.6;
		3->2.5;
		4->4;
		5->5.5;
		_->0
	end.


loop_query_charm() ->
	InfoList = query_charm(),%%获取所有排在前面的魅力值超过10的童鞋(最多100个)
	RankList = lists:map(fun(Info) -> erlang:list_to_tuple(Info) end, InfoList),
	PlayerIdList = lists:usort([PId || {PId, _Charm, _Title} <- RankList]),%% 刷选玩家id，去除重复Id
	
	PlayerInfoList = get_player_info_list([], PlayerIdList),		%%获取玩家的信息
	
	NewRankList = get_charm_rank_list(RankList, PlayerInfoList),
	[make_rank_info(?CHARM_RANK_ID, NewRankList)].

%% 封神台霸主榜
loop_fst_gods() ->
	FstGods = db_agent:get_fst_god(),
	fst_gods_loop(FstGods, []).
fst_gods_loop([], Ret) ->
	Ret;
fst_gods_loop([[Loc, Uid, Nick, Time] | G], Ret) ->
	NewRet = 
		case lists:keyfind(Loc, 1, Ret) of
			false ->
				[{Loc, [Uid], io_lib:format("~s ", [Nick]), Time} | Ret];
			{_Loc, OUid, Name, _Time} ->
				NewName = Name ++ io_lib:format("~s ", [Nick]),
				lists:keyreplace(Loc, 1, Ret, {Loc, [Uid|OUid], NewName, Time})
		end,
	fst_gods_loop(G, NewRet).

%% 诛仙台霸主榜
loop_zxt_gods() ->
	ZxtGods = db_agent:get_zxt_god(),
	zxt_gods_loop(ZxtGods, []).
zxt_gods_loop([], Ret) ->
	Ret;
zxt_gods_loop([[Loc, Uid, Nick, Time] | G], Ret) ->
	NewRet = 
		case lists:keyfind(Loc, 1, Ret) of
			false ->
				[{Loc, [Uid], io_lib:format("~s ", [Nick]), Time} | Ret];
			{_Loc, OUid, Name, _Time} ->
				NewName = Name ++ io_lib:format("~s ", [Nick]),
				lists:keyreplace(Loc, 1, Ret, {Loc, [Uid|OUid], NewName, Time})
		end,
	zxt_gods_loop(G, NewRet).

%% 镇妖台（单）
loop_tds_rank() ->
	List = db_agent:get_td_single_rank(10),
	List1 = [Uid || [Uid, _AttNum, _GuildName, _Nick, _Career, _Realm, _HorTd, _MgcTd] <- List],
	List2 = db_agent:find_vip(List1),
	F = fun(Num) ->
		lists:nth(Num, List) ++ lists:nth(Num, List2)
	end,
	Data = [F(Num) || Num <- lists:seq(1, length(List))],
	tds_rank_loop(Data, 1, []).


tds_rank_loop([], _N, Ret) ->
	Ret;
tds_rank_loop([D | Data], N, Ret) ->
	tdm_rank_loop(Data, N + 1, [erlang:list_to_tuple([N | D]) | Ret]).

%%单人镇妖竞技榜
loop_tds_rank_all() ->
	List = db_agent:get_td_single_rank(500),
	List1 = [Uid || [Uid, _AttNum, _GuildName, _Nick, _Career, _Realm, _HorTd, _MgcTd] <- List],
	List2 = db_agent:find_vip_lv(List1),
	F = fun(Num) ->
		lists:nth(Num, List) ++ lists:nth(Num, List2)
	end,
	Data = [F(Num) || Num <- lists:seq(1, length(List))],
	tds_rank_loop(Data, 1, []).


%% 镇妖台（多）
loop_tdm_rank() ->
	Data = db_agent:get_td_multi_rank(),
	tdm_rank_loop(Data, 1, []).
tdm_rank_loop([], _N, Ret) ->
	Ret;
tdm_rank_loop([D | Data], N, Ret) ->
	tdm_rank_loop(Data, N + 1, [erlang:list_to_tuple([N | D]) | Ret]).

loop_query_achieve() ->
	InfoList = query_achieve(),%%获取所有排在前面的成就点超过10的童鞋(最多100个)
	RankList = lists:map(fun(Info) -> erlang:list_to_tuple(Info) end, InfoList),
	PlayerIdList = lists:usort([PId || {PId, _Achieve} <- RankList]),%% 刷选玩家id，去除重复Id
	%%%%%%%%%%%%%此方法不完善，需要根据后期提供的数据表在进行修改(暂时保留原样)
	PlayerInfoList = get_player_info_list([], PlayerIdList),		%%获取玩家的信息
	%%%%%%%%%%%%%此方法不完善，需要根据后期提供的数据表在进行修改
	
	NewRankList = get_achieve_rank_list(RankList, PlayerInfoList),
	[make_rank_info(?ACHIEVE_RANK_ID, NewRankList)].
	
guildbat_rank() ->
	{StartTime,EndTime} = util:get_this_week_duringtime(),
	GuildList = db_agent:guildbat_rank_guild(),
	F =  fun(Guild) ->
				 [_Id, Name, Level, Combat_all_num, Combat_week_num] = Guild,
				 [Time,Combat_Num] = util:string_to_term(tool:to_list(Combat_week_num)),
				 if Time >= StartTime andalso  Time < EndTime ->
						[Name, Level, Combat_all_num, Combat_Num];
					true ->
						[Name, Level, Combat_all_num, 0]
				 end
		 end,
	GuildList1 = [F(Guild) || Guild <- GuildList],
	GuildList2  = lists:sort(fun([_Name, Level, Combat_all_num, Combat_Num],[_Name1, Level1, Combat_all_num1, Combat_Num1]) -> 
									 if
										 Combat_all_num =/= Combat_all_num1 -> Combat_all_num > Combat_all_num1;
										 true ->
											 if
												 Combat_Num =/= Combat_Num1 -> Combat_Num > Combat_Num1;
												 true ->  Level >= Level1 
											 end
									 end
					   end ,
					   GuildList1),
	GuildList3 = add_order([],GuildList2,1),
	GuildList4 = make_rank_info(?GUILDBAT_RANK_TYPE_ID, GuildList3),
	ets:insert(?ETS_RANK, GuildList4).

%% @doc  根据氏族排行类别查询相应排行信息
%% @spec loop_query_guild(GuildTypeList) -> AllGuildRanks
loop_query_guild(GuildTypeList) ->
    F = fun({TypeNum, Type}) ->
            OldRankList = query_guild(Type),
            NewRankList = add_order([], OldRankList, 1),
            make_rank_info(?GUILD_RANK_TYPE_ID, NewRankList)
    end,
    lists:map(fun(TypeInfo) -> F(TypeInfo) end, GuildTypeList).

%% @doc  根据RealmList、CareerList、SexList和TypeList循环查询，获得人物属性排行榜
%% @spec loop_query_roles(RealmList, CareerList, SexList, TypeList) -> AllRoleRanks
%% loop_query_roles(RealmList, CareerList, SexList, TypeList) ->
%%     loop_query_roles_1(RealmList, CareerList, SexList, TypeList, []).
%% 
%% %% @doc  根据RealmList、CareerList、SexList和TypeList循环执行查询，获得排名信息
%% loop_query_roles_1([], _, _, _, AccList) ->
%%     AccList;
%% loop_query_roles_1(RealmList, CareerList, SexList, TypeList, AccList) ->
%%     [Realm | NewList] = RealmList,
%%     case loop_query_roles_2(Realm, CareerList, SexList, TypeList, AccList) of
%%         error ->
%%             error;
%%         NewAccList ->
%%             loop_query_roles_1(NewList, CareerList, SexList, TypeList, NewAccList)
%%     end.
%% 
%% %% @doc  在Realm给定时，根据CareerList、SexList和TypeList中的元素循环查询
%% loop_query_roles_2(_, [], _, _, AccList) ->
%%     AccList;
%% loop_query_roles_2(Realm, CareerList, SexList, TypeList, AccList) ->
%%     [Career | NewList] = CareerList,
%%     case loop_query_roles_3(Realm, Career, SexList, TypeList, AccList) of
%%         error ->
%%             error;
%%         NewAccList ->
%%             loop_query_roles_2(Realm, NewList, SexList, TypeList, NewAccList)
%%     end.
%% 
%% %% @doc  在Realm、Career给定时,根据SexList和TypeList中的元素循环查询
%% loop_query_roles_3(_, _, [], _, AccList) ->
%%     AccList;
%% loop_query_roles_3(Realm, Career, SexList, TypeList, AccList) ->
%%     [Sex | NewList] = SexList,
%%     case loop_query_roles_4(Realm, Career, Sex, TypeList, AccList) of
%%         error ->
%%             error;
%%         NewAccList ->
%%             loop_query_roles_3(Realm, Career, NewList, TypeList, NewAccList)
%%     end.
%% 
%% %% @doc  在Realm、Career、Sex给定时,根据TypeList中的元素循环查询
%% loop_query_roles_4(_, _, _, [], AccList) -> AccList;
%% loop_query_roles_4(Realm, Career, Sex, TypeList, AccList) ->
%%     [{TypeNum, Type} | NewList] = TypeList,
%% 	do_query_roles(Realm, Career, Sex, Type, TypeNum),
%%     NewAccList = AccList,
%% 	timer:sleep(100),
%%     loop_query_roles_4(Realm, Career, Sex, NewList, NewAccList).
%% 
%% do_query_roles(Realm, Career, Sex, Type, TypeNum) ->
%%     RankList = query_roles(Realm, Career, Sex, Type),
%%     NewRankList = add_order([], RankList, 1),
%%     RankTypeId = get_role_rank_type(Realm, Career, Sex, TypeNum),
%%     RankRecord = make_rank_info(RankTypeId, NewRankList),
%% 	ets:insert(?ETS_RANK, RankRecord),
%% 	ok.
%% 	
	
%% @doc  生成某排行榜信息
%% @spec make_rank_info(TypeId, List) -> error | Record
make_rank_info(TypeId, List) ->
    #ets_rank{type_id = TypeId, rank_list = List}.

%% @doc  查询装备相关属性
%% @spec query_equip(Type) -> GoodsInfoList
query_equip(Type) when is_integer(Type) ->
    db_agent:rank_query_equip(?SLAVE_POOLID, Type).

%% @doc  查询神器战力属性
%% @spec query_equip(Type) -> GoodsInfoList
query_deputy_equip() ->
    db_agent:rank_query_deputy_equip(?SLAVE_POOLID).

%% @doc  查询坐骑战力属性
query_mount() ->
    db_agent:rank_mount_rank(?SLAVE_POOLID,100).

%% @doc  查询宠物相关属性
%% @spec query_pet() -> PetInfoList
query_pet() ->
	db_agent:rank_query_pet().

%% 获取人物的相关属性
%% lsit[pid,charm]
query_charm() ->
	db_agent:rank_query_charm().

%% 查询所有玩家成就点(成就点大于10的)
%% lsit[pid,achieve]
query_achieve() ->
	db_agent:rank_query_achieve().

%% @doc  查询氏族相关属性，获取氏族属性的排行
%% @spec query_guild(Type) -> RankList
query_guild(Type) ->
    case get_position(Type) of  %% 查询ETS表方式
        {ok, Pos} ->
            GuildList = [ Guild || [Guild] <- ets:match(?ETS_GUILD, _ = '$1') ],
			NewGuildList = lists:sublist(lists:sort(fun query_guild_level_member/2, GuildList), ?NUM_LIMIT),
            [ [Guild#ets_guild.id, 
			   Guild#ets_guild.name, 
			   Guild#ets_guild.realm,
			   Guild#ets_guild.funds,
			   Guild#ets_guild.chief_name, 
			   Guild#ets_guild.member_num,
			   lists:nth(Pos, tuple_to_list(Guild))] || Guild <- NewGuildList];
        false ->
            []
    end.
%%氏族属性排行
query_guild_level_member(GuildA, GuildB) ->
%% 	case GuildA#ets_guild.level >GuildB#ets_guild.level of
%% 		true ->
%% 			true;
%% 		false ->
%% 			case GuildA#ets_guild.level =:= GuildB#ets_guild.level of
%% 				true ->
%% 					GuildA#ets_guild.member_num >= GuildB#ets_guild.member_num;
%% 				false ->
%% 					false
%% 			end
%% 	end.
	if
		GuildA#ets_guild.level =/= GuildB#ets_guild.level ->
			GuildA#ets_guild.level > GuildB#ets_guild.level;
		true ->
			if GuildA#ets_guild.member_num =/= GuildB#ets_guild.member_num ->
				   GuildA#ets_guild.member_num > GuildB#ets_guild.member_num;
			   true ->
				   GuildA#ets_guild.id > GuildB#ets_guild.id
			end
	end.
	
%% @doc  查询某个字段在ets_guild记录中的位置
%% @spec get_position(Field) -> {ok, Position} | false
get_position(Field) when is_atom(Field) ->
    FieldList = record_info(fields, ets_guild),
    case get_first_pos(Field, FieldList) of
        {ok, Pos} ->
            {ok, Pos + 1};
        false ->
            false
    end;
get_position(_) ->
    false.

%% @doc  查询某元素在列表中首次出现的位置
%% @spec get_pos(Elem, List) -> {ok, Position} | false
get_first_pos(Elem, List) when is_list(List) ->
    F = fun
        (_X, [], _N, _G) ->
            false;
        (X, L, N, G) ->
            [H | NewList] = L,
            case X == H of
                true ->
                    {ok, N};
                false ->
                    G(X, NewList, N + 1, G)
            end
    end,
    F(Elem, List, 1, F).

%% @doc  查询人物相关属性排行(honor), 从氏族里
%% @spec query_roles(Realm, Career, Sex, Type) -> RankList
query_roles_honor(Realm, Career, Sex, honor) ->
    F1 = fun(GuildMember) ->        %% 全部落
            [Guild] = ets:lookup(?ETS_GUILD, GuildMember#ets_guild_member.guild_id),
            RoleRealm = Guild#ets_guild.realm,
            PlayerId = GuildMember#ets_guild_member.player_id,
            PlayerName = GuildMember#ets_guild_member.player_name,
            RoleSex = GuildMember#ets_guild_member.sex,
            RoleCareer = GuildMember#ets_guild_member.career,
            GuildName = GuildMember#ets_guild_member.guild_name,
            Honor = GuildMember#ets_guild_member.honor,
            [PlayerId, PlayerName, RoleSex, RoleCareer, RoleRealm, GuildName, Honor]
    end,
    F2 = fun(GuildMembers) ->        %% 单部落
            F = fun
                ([], AccList, _G) ->
                    AccList;
                (Members, AccList, G) ->
                    [GuildMember | Rest] = Members,
                    GuildId = GuildMember#ets_guild_member.guild_id,
                    case ets:match(?ETS_GUILD, #ets_guild{id = GuildId, realm = Realm, _ = '_'}) of
                        [_Guild] ->
                            PlayerId = GuildMember#ets_guild_member.player_id,
                            PlayerName = GuildMember#ets_guild_member.player_name,
                            RoleSex = GuildMember#ets_guild_member.sex,
                            RoleCareer = GuildMember#ets_guild_member.career,
                            GuildName = GuildMember#ets_guild_member.guild_name,
                            Honor = GuildMember#ets_guild_member.honor,
                            NewAccList = [[PlayerId, PlayerName, RoleSex, RoleCareer, Realm, GuildName, Honor] | AccList],
                            G(Rest, NewAccList, G);
                        [] ->
                            G(Rest, AccList, G)
                    end
            end,
            F(GuildMembers, [], F)
    end,

   	case Realm of
       	0 ->		%% 全部落
           	case Career of
               	0 ->        %% 全职业
                   	case Sex of
                       	0 ->
                       		[F1(GuildMember) || [GuildMember] <- ets:match(?ETS_GUILD_MEMBER, _ = '$1')];
                       	_ ->
                          	[F1(GuildMember) || [GuildMember] <- ets:match(?ETS_GUILD_MEMBER, #ets_guild_member{sex = Sex})]
                   	end;
               	_ ->        %% 单职业
                   	case Sex of
                       	0 ->
                           	[F1(GuildMember) || GuildMember <- ets:match(?ETS_GUILD_MEMBER, #ets_guild_member{career = Career})];
                       	_ ->
                           	[F1(GuildMember) || GuildMember <- ets:match(?ETS_GUILD_MEMBER, #ets_guild_member{career = Career, sex = Sex})]
                   	end
           	end;
       	_ ->		%% 单部落
           	case Career of
               	0 ->        %% 全职业
                   	case Sex of
                       	0 ->
                           	F2([GuildMember || [GuildMember] <- ets:match(?ETS_GUILD_MEMBER, _ = '$1') ] );
                   	 	_ ->
                           	F2([GuildMember || [GuildMember] <- ets:match(?ETS_GUILD_MEMBER, #ets_guild_member{sex = Sex}) ] )
                   	end;
               	_ ->        %% 单职业
                   	case Sex of
                       	0 ->
                           	F2(ets:match(?ETS_GUILD_MEMBER, #ets_guild_member{career = Career}));
                       	_ ->
                           	F2(ets:match(?ETS_GUILD_MEMBER, #ets_guild_member{career = Career, sex = Sex}))
                   	end
       		end
	end.

%% @doc  查询人物相关属性排行 
%% @spec query_roles(Realm, Career, Sex, Type) -> RankList
query_roles(Realm, Career, Sex, Type) ->
	db_agent:rank_get_player_info(?SLAVE_POOLID, Realm, Career, Sex, Type, ?NUM_LIMIT).
%% 	case Type /= honor of
%% 		true ->
%% 			db_agent:rank_get_player_info(?SLAVE_POOLID, Realm, Career, Sex, Type, ?NUM_LIMIT);
%% 		false ->
%% 			mod_guild:query_roles_honor(Realm, Career, Sex, honor)
%% 	end.	

%% @doc  添加排行信息、物品名及玩家信息至物品信息，去掉goods_id（类型ID）
%% @spec update_goods_info(OldInfoList, PlayerInfoList, StartOrder, []) ->NewInfoList
update_goods_info([], _, _, AccList) ->
    lists:reverse(AccList);
update_goods_info(OldGoodsInfoList, PlayerInfoList, Order, AccList) ->
    [GoodsInfo | NewList] = OldGoodsInfoList,
    {Id, GoodsTypeId, PlayerId, Score} = GoodsInfo,
    GoodsName = get_equip_name(GoodsTypeId),
    case keysearch(PlayerId, 1, PlayerInfoList) of
        {ok, PlayerInfo} ->
            [NewPlayerId, PlayerName, Realm, Guild, _Career, Vip] = PlayerInfo;
        false ->
            NewPlayerId = 0,
            PlayerName = <<"">>,
			Realm = 0,
            Guild = <<"">>,
			Vip = 0
    end,
    NewAccList = [[Order, Id, GoodsName, NewPlayerId, PlayerName, Realm, Guild, Score, Vip] | AccList],
    update_goods_info(NewList, PlayerInfoList, Order + 1, NewAccList).

update_pet_info([], _PlayerInfoList, _Order, AccList) ->
	lists:reverse(AccList);
update_pet_info(PetInfoList, PlayerInfoList, Order, AccList) ->
	[PetInfo| NewPetInfoList] = PetInfoList,
	{PetId, PetName, PlayerId, PetLevel, PetAptitude, Grow,Point} = PetInfo,
	case keysearch(PlayerId, 1, PlayerInfoList) of
		{ok, PlayerInfo} ->
			[NewPlayerId, PlayerName, _Realm, _Guild, _Career, Vip] = PlayerInfo;
		false ->
			NewPlayerId = 0,
			PlayerName = <<"">>,
			Vip = 0
	end,
	NewAccList = [[Order, PetId, PetName, NewPlayerId, PlayerName, PetLevel, PetAptitude, Grow,Point, Vip] | AccList],
	update_pet_info(NewPetInfoList, PlayerInfoList, Order+1, NewAccList).


update_charm_info([], _PlayerInfoList, _Order, AccList) ->
	lists:reverse(AccList);
update_charm_info(CharmInfoList, PlayerInfoList, Order, AccList) ->
	[CharmInfo| NewCharmInfoList] = CharmInfoList,
	{PId, Charm, Title} = CharmInfo,
	case keysearch(PId, 1, PlayerInfoList) of
		{ok, PlayerInfo} ->
			[_NewPlayerId, PlayerName, Realm, GuildName, Career, Vip] = PlayerInfo;
		false ->
			_NewPlayerId = 0,
			PlayerName = <<"">>,
			Career = 0,
			Realm = 0,
			GuildName = <<"">>,
			Vip = 0
	end,
	NewAccList = [[Order, PId, PlayerName, Career, Realm, GuildName, Title, Charm, Vip] | AccList],
	update_charm_info(NewCharmInfoList, PlayerInfoList, Order+1, NewAccList).

%% 成就点与玩家信息组合
update_achieve_info([], _PlayerInfoList, _Order, AccList) ->
	lists:reverse(AccList);
update_achieve_info(AchieveInfoList, PlayerInfoList, Order, AccList) ->
	[AchieveInfo| NewAchieveInfoList] = AchieveInfoList,
	{PId, Achieve} = AchieveInfo,
	case keysearch(PId, 1, PlayerInfoList) of
		{ok, PlayerInfo} ->
			[_NewPlayerId, PlayerName, Realm, GuildName, Career, Vip] = PlayerInfo;
		false ->
			_NewPlayerId = 0,
			PlayerName = <<"">>,
			Career = 0,
			Realm = 0,
			GuildName = <<"">>,
			Vip = 0
	end,
	NewAccList = [[Order, PId, PlayerName, Career, Realm, GuildName, Achieve, Vip] | AccList],
	update_achieve_info(NewAchieveInfoList, PlayerInfoList, Order+1, NewAccList).

loop_query_batt_value(Limit) ->
	BattRanks = db_agent:loop_query_batt_value(?SLAVE_POOLID,Limit),
	BattRanks1 = lists:sublist(BattRanks, Limit),	
	PlayerValueList = [{PlayerId,BattValue} || [PlayerId,BattValue] <- BattRanks1],
	PlayerIdList = [_Player_Id || [_Player_Id,_BattValue] <- BattRanks1],
	PlayerInfoList = db_agent:get_player_mult_properties([id, nickname, sex, career, realm, guild_name, vip],lists:flatten(PlayerIdList)), 
	F = fun([Id, Nickname, Sex, Career, Realm, Guild_name, Vip]) ->
				{_Id, Value}  = lists:keyfind(Id, 1, PlayerValueList),
				[Id, Nickname, Sex, Career, Realm, Guild_name, Value, Vip]
		end,
	BattRanks2 = [F([Id, Nickname, Sex, Career, Realm, Guild_name, Vip]) || {_Key,[Id, Nickname, Sex, Career, Realm, Guild_name,Vip]} <- PlayerInfoList],
	BattRanks3 = lists:sort(fun([_Id1, _Nickname1, _Sex1, _Career1, _Realm1, _Guild_name1, Value1, _Vip1],[_Id2, _Nickname2, _Sex2, _Career2, _Realm2, _Guild_name2, Value2, _Vip2]) ->
									 Value1 >= Value2 end,BattRanks2),
    RankRecord = make_rank_info(?BATT_RANK_TYPE_ID, BattRanks3),
	ets:insert(?ETS_RANK, RankRecord).

%% 获取人物等级相关排行
loop_query_lv(Limit) ->
	LvRanks = db_agent:loop_query_lv(?SLAVE_POOLID,Limit),
	LvRanks1 = lists:sublist(LvRanks, Limit),	
    RankRecord = make_rank_info(?LV_RANK_TYPE_ID, LvRanks1),
	ets:insert(?ETS_RANK, RankRecord).

%% 获取人物财富相关排行	
loop_query_coin_sum(Limit) ->   
	CoinSumRanks = db_agent:loop_query_coin_sum(?SLAVE_POOLID,Limit),
	CoinSumRanks1 = lists:sublist(CoinSumRanks, Limit),	
	RankRecord = make_rank_info(?COIN_SUM_RANK_TYPE_ID, CoinSumRanks1),
	ets:insert(?ETS_RANK, RankRecord).

%% 获取人物荣誉相关排行
loop_query_realm_honor(Limit)->   
	HonorRanks =  db_agent:loop_query_honor(?SLAVE_POOLID,Limit),
	HonorRanks1 = lists:sublist(HonorRanks, Limit),	
	RankRecord = make_rank_info(?HONOR_RANK_TYPE_ID, HonorRanks1),
	ets:insert(?ETS_RANK, RankRecord).

%% 获取人物修为相关排行
loop_query_culture(Limit)->  
	CultureRanks = db_agent:loop_query_culture(?SLAVE_POOLID,Limit),
	CultureRanks1 = lists:sublist(CultureRanks, Limit),	
	RankRecord = make_rank_info(?CULTURE_RANK_TYPE_ID, CultureRanks1),
	ets:insert(?ETS_RANK, RankRecord).

%%【外部接口】
%%等级，财富，荣誉，修为根据部落，职业，性别查询 
get_role_rank_order(PidSend,Realm, Career, Sex, TypeNum) ->
	RankInfo = get_role_rank1(Realm, Career, Sex, TypeNum),
	{ok, BinData} = pt_22:write(22001, RankInfo),
	lib_send:send_to_sid(PidSend, BinData).

%%等级，财富，荣誉，修为根据部落，职业，性别查询
get_role_rank1(Realm, Career, Sex, TypeNum) ->
	RankTypeId = 
	 case TypeNum of
		 1 -> 50000;
		 2 -> 60000;
		 3 -> 70000;
		 4 -> 80000;
		 5 -> 11000;
		 6 -> 14000;
		 _ -> 50000
	 end,	 
	[{ets_rank,RankTypeId,Data}] = 
		case ets:lookup(?ETS_RANK, RankTypeId) of
			[]->
				[{ets_rank,RankTypeId,[]}];
			Value->Value
		end,
	case Data of 
		[] -> [];
		_ -> 
			Data1 = 
				if Realm > 0 ->
					   lists:filter(fun([_Id1, _Nickname1, _Sex1, _Career1, Realm1, _Guild_name1,_TypeValue1,_Vip]) -> Realm1 == Realm end,Data);
				   true ->
					   Data 
				end,
			Data2 =
				if Career > 0 ->
					   lists:filter(fun([_Id2, _Nickname2, _Sex2, Career2, _Realm2, _Guild_name2,_TypeValue2,_Vip]) -> Career2 == Career end,Data1);
				   true -> 
					   Data1
				end,
			Data3 =
				if Sex > 0 ->
					    lists:filter(fun([_Id3, _Nickname3, Sex3, _Career3, _Realm3, _Guild_name3,_TypeValue3,_Vip]) -> Sex3 == Sex end,Data2);
				   true ->
					   Data2
				end,			
			Data4 = add_order([],Data3,1),
			Data4
	end.


%%从排行榜中查询某人战斗力的排名(只查询前100名中的名次，返回结果0说明没有给其排名)
get_batt_value_place(PlayerId) ->
	RankList = get_role_rank1(0, 0, 0, 5),
	loop_get_batt_value_place(PlayerId,RankList,0).

loop_get_batt_value_place(_PlayerId,[],Place) ->
	Place;
loop_get_batt_value_place(PlayerId,[Info | Rest],Place) ->
	[Rank, Id | _] = Info,
	if PlayerId == Id ->
		   loop_get_batt_value_place(PlayerId,[],Rank);
	   true ->
		   loop_get_batt_value_place(PlayerId,Rest,Place)
	end.

%%从数据库中查询某人战斗力的排名
get_batt_value_place_db_order(PidSend,PlayerId) ->
	RankInfo = get_batt_value_place_db(PlayerId),
	{ok, BinData} = pt_22:write(22015, RankInfo),
	lib_send:send_to_sid(PidSend, BinData).
get_batt_value_place_db(PlayerId) ->
	case mod_cache:get({lib_rank,get_all_batt_value}) of
		[] ->
			ResultList = db_agent:get_all_batt_value(),
			mod_cache:set({lib_rank,get_all_batt_value},ResultList,3600);
		CacheData ->
			ResultList = CacheData
	end,
	F = fun(Num) ->
				[Player_Id,_Value] = lists:nth(Num, ResultList),
				[Num,Player_Id]
		end,
	RankList = [F(Num) || Num <- lists:seq(1, length(ResultList))],
	loop_get_batt_value_place(PlayerId,RankList,0).
	
%%
%%======================================================================================
%%	手动即时刷新排行榜
%%	警告：此方法比较耗数据库性能，不要随意使用，只在需要即时人工手动刷新系统排行榜时使用
%%======================================================================================
%%
update_rank_rightnow() ->
	Pid = mod_rank:get_mod_rank_pid(),
	gen_server:cast(Pid, {'UPDATE_RANK_RIGHTNOW'}).

%% ===================================================
%%   成就系统 专用的获取人物Id，其他的模块慎用
%% ===================================================
%%战斗力第一
get_batt_value_first_id() ->
	try 
		case gen_server:call(mod_rank:get_mod_rank_pid(), 
							 {apply_call, lib_rank, get_batt_value_first_id_inline, []}) of
			error ->
				0;
			Data ->
				Data
		end
	catch
		_:_ -> 
			0
	end.
get_batt_value_first_id_inline() ->
	case get_role_rank1(0, 0, 0, 5) of
		[] ->
			0;
		[[_Order, PlayerId, _Nickname, _Sex, _Career, _Realm, _Guild_name, Type, _Vip]|_] ->
			case Type >= ?BATT_VALUE_LIMIT of
				true ->
					PlayerId;
				false ->
					0
			end
	end.

%%部落荣誉第一
get_realm_honor_first_id(Realm) ->
	try 
		case gen_server:call(mod_rank:get_mod_rank_pid(), 
							 {apply_call, lib_rank, get_realm_honor_first_id_inline, [Realm]}) of
			error ->
				0;
			Data ->
				Data
		end
	catch
		_:_ -> 
			0
	end.		
get_realm_honor_first_id_inline(Realm) ->
	case get_role_rank1(Realm, 0, 0, 3) of
		[] ->
			0;
		[[_Order, PlayerId, _Nickname, _Sex, _Career, _Realm, _Guild_name, Type, _Vip]|_] ->
			case Type >= ?REALM_HONOR_LIMIT of
				true ->
					PlayerId;
				false ->
					0
			end
	end.
%%财富第一
get_fortune_first_id() ->
	try 
		case gen_server:call(mod_rank:get_mod_rank_pid(), 
							 {apply_call, lib_rank, get_fortune_first_id_inline, []}) of
			error ->
				0;
			Data ->
				Data
		end
	catch
		_:_ -> 
			0
	end.
get_fortune_first_id_inline() ->
	case get_role_rank1(0, 0, 0, 2) of
		[] ->
			0;
		[[_Order, PlayerId, _Nickname, _Sex, _Career, _Realm, _Guild_name,_Type,_Vip]|_] ->
			case _Type >= 1000000 of
				true ->
					PlayerId;
				false ->
					0
			end
	end.
%%魅力前五
get_charm_five_id() ->
	try 
		case gen_server:call(mod_rank:get_mod_rank_pid(), 
							 {apply_call, lib_rank, get_charm_five_id_2, []}) of
			error ->
				[];
			Data ->
				Data
		end
	catch
		_:_ -> 
			0
	end.
get_charm_five_id_2() ->
	case get_charm_rank() of
		[] ->
			[];
		[RankList] ->
			F = fun(Item) ->
						case Item of
							[] -> 
								0;
							%%[Order, PId, PlayerName, Career, Realm, GuildName, Title, Charm, Vip]
							[_Order, Pid, _PlayerName, _Career, _Realm, _GuildName, _Title, _Charm, _Vip] ->
								Pid
						end
				end,
			case RankList#ets_rank.rank_list of
				[] -> 
					[];
				Data ->
					if length(Data)=< 5 ->
						   lists:map(F,Data);
					   true ->
						   {Fives,_} = lists:split(5, Data),
						   lists:map(F,Fives)
					end
			end		
	end.

%%成就第一
get_ach_first_id() ->
	try 
		case gen_server:call(mod_rank:get_mod_rank_pid(), 
							 {apply_call, lib_rank, get_ach_first_id_inline, []}) of
			error ->
				0;
			Data ->
				Data
		end
	catch
		_:_ -> 
			0
	end.
get_ach_first_id_inline() ->
	case get_achieve_rank() of
		[] ->
			0;
		[RankList] ->
			case RankList#ets_rank.rank_list of
				[] ->
					0;
				[[_Order, PlayerId, _PlayerName, _Career, _Realm, _GuildName, Achieve, _Vip]|_] ->
					case Achieve >= 500 of%%成就点需要大于500的限制
						true ->
							PlayerId;
						false ->
							0
					end
			end
	end.
%%法宝第一
get_equip_first_id() ->
	try 
		case gen_server:call(mod_rank:get_mod_rank_pid(), 
							 {apply_call, lib_rank, get_equip_first_id_inline, []}) of
			error ->
				0;
			Data ->
				Data
		end
	catch
		_:_ -> 
			0
	end.

get_equip_first_id_inline() ->
	case get_equip_rank(1) of
		[] ->
			0;
		[RankList] ->
			case RankList#ets_rank.rank_list of
				[] ->
					0;
				[[_Rank, _GoodsId, _GoodsName, PlayerId, _PlayerName, _Realm, _Guild, _Score, _Vip]|_] ->
					case _Score >= 1600 of
						true ->
							PlayerId;
						false ->
							0
					end
			end
	end.


%%获取有关排行榜上的一些第一
%%1：封神台第一
%%2：诛仙台第一
get_title_first_ids(Type) ->
	try 
		case gen_server:call(mod_rank:get_mod_rank_pid(), 
							 {apply_call, lib_rank, get_title_first_ids_inline, [Type]}) of
			error ->
				[];
			Data ->
				Data
		end
	catch
		_:_ -> 
			[]
	end.



get_title_first_ids_inline(Type) ->
	case Type of
		1 ->%%封神台第一
			case get_fst_god() of
				[] ->
					[];
				FSTRank ->
					[{MLoc, MUid, _MNick, _MThruTime}] = lists:max(FSTRank),%%取出最大的那个loc
					case MLoc of
						30 ->
							MUid;
						_ ->%%是排第一，但是不是30层的，所以还是拿不到称号
							[]
					end
			end;
		2 ->%%诛仙台第一
			case get_zxt_god() of
				[] ->
					[];
				ZXTRank ->
					[{MLoc, MUid, _MNick, _MThruTime}] = lists:max(ZXTRank),%%取出最大的那个loc
					case MLoc of
						20 ->
							MUid;
						_ ->%%排第一，但是不是20层的，所以还是拿不到称号
							[]
					end
			end
	end.

%%{封神霸主, 天下无敌, 女娲英雄, 神农英雄, 伏羲英雄, 不差钱, 八神之主, 绝世神兵, 诛仙霸主, 全民偶像, 全民公敌, 远古战神}
get_ach_rank_first() ->
	Areaking = lib_arena:get_arena_king(),		%%天下无敌
	{Adore, Disdain}= mod_appraise:get_all_max_appraise(),			%%{全民偶像,全民公敌}
	Castle = lib_castle_rush:get_castle_rush_king_id(),
	{Fst, NWFirst, SNFirst, FXFirst, Rich, Ach, Equip, Zxt, YGZS} =
		try 
			case gen_server:call(mod_rank:get_mod_rank_pid(), 
								 {apply_call, lib_rank, get_ach_rank_first_inline, []}) of
				error ->
					{[], 0, 0, 0, 0, 0, 0, [], 0};
				Data ->
					Data
			end
		catch
			_:_ -> 
				{[], 0, 0, 0, 0, 0, 0, [], 0}
		end,
	{Fst, Areaking, NWFirst, SNFirst, FXFirst, Rich, Ach, Equip, Zxt, Adore, Disdain, YGZS, Castle}.

get_ach_rank_first_inline() ->
	Fst = get_title_first_ids_inline(1),				%%封神霸主
	NWFirst = get_realm_honor_first_id_inline(1),		%%女娲英雄
	SNFirst = get_realm_honor_first_id_inline(2),		%%神农英雄 
	FXFirst = get_realm_honor_first_id_inline(3),		%%伏羲英雄
	Rich = get_fortune_first_id_inline(),				%%不差钱
	Ach = get_ach_first_id_inline(),					%%八神之主
	Equip = get_equip_first_id_inline(),				%%绝世神兵
	Zxt = get_title_first_ids_inline(2),				%%诛仙霸主
	YGZS = get_batt_value_first_id_inline(),			%%远古战神
	{Fst, NWFirst, SNFirst, FXFirst, Rich, Ach, Equip, Zxt, YGZS}.


%%神器战力排行
rank_deputy_equip_rank_order(PidSend) ->
	RankInfo = rank_deputy_equip_rank(),
	{ok, BinData} = pt_22:write(22016, RankInfo),
	lib_send:send_to_sid(PidSend, BinData).
rank_deputy_equip_rank() ->
	[{ets_rank,_RankTypeId,Data}] = ets:lookup(?ETS_RANK, ?DEPUTY_EQUIP_RANK_TYPE_ID),
	Data1 = add_order([],Data,1),
	Data1.
	
%%坐骑战力排行
rank_mount_rank(PidSend) ->
	[{ets_rank,_RankTypeId,Data}] = ets:lookup(?ETS_RANK, ?MOUNT_RANK_TYPE_ID),
	RankInfo = add_order([],Data,1),
	{ok, BinData} = pt_22:write(22017, RankInfo),
	lib_send:send_to_sid(PidSend, BinData).	
	
	
	
%%加载单人镇妖竞技奖励
init_single_td_award()->
	Data = db_agent:get_single_td_award(),
	lists:map(
	  fun(A)->
			Award = list_to_tuple([ets_single_td_award|A]),
			update_single_td_awrd(Award)
	  end, Data).

update_single_td_awrd(Award)->
	ets:insert(?ETS_SINGLE_TD_AWARD, Award).
select_single_td_award(PlayerId)->
	ets:lookup(?ETS_SINGLE_TD_AWARD, PlayerId).
select_single_td_award_all()->	
	ets:tab2list(?ETS_SINGLE_TD_AWARD).
del_single_td_award(PlayerId)->
	ets:delete(?ETS_SINGLE_TD_AWARD, PlayerId).
del_single_td_award_all()->
	ets:delete_all_objects(?ETS_SINGLE_TD_AWARD).	
	

single_td_award(Lv,Order)->
	if Order == 1->
		   {Lv*10000,150000};
	   Order > 200 ->
		   {round(Lv*666-(Order-201)*Lv*2),round(10000-(Order-201)*30)};
	   Order > 100 ->
		   {round(Lv*1333-(Order-101)*Lv*6),round(20000-(Order-101)*95)};
	   Order > 50 ->
		   {round(Lv*2000-(Order-51)*Lv*13),round(30000-(Order-51)*195)};
	   Order > 20 ->
		   {round(Lv*4000-(Order-21)*Lv*64),round(60000-(Order-21)*960)};
	   Order >= 6 ->
		   {round(Lv*5333-(Order-6)*Lv*83),round(80000-(Order-6)*1250)};
	   true->
		   {round(Lv*6666-(Order-2)*Lv*266),round(100000-(Order-2)*4000)}
	end.

%%单人镇妖竞技奖励
single_td_award()->
	TDSRanksAll = loop_tds_rank_all(),								     %% 镇妖台（单）竞技榜
	insert_rank_info(?ETS_TD_S_ALL, TDSRanksAll),
	%%系统自动给未领取奖励的玩家发放奖励
	AwardBag = select_single_td_award_all(),
	spawn(fun()->single_td_award_auto(AwardBag)end),
	del_single_td_award_all(),
	db_agent:del_single_td_award_all(),
	NowTime = util:unixtime(),
	Rank = get_single_td_rank_info(),
	lists:map(
	  fun(Info)->
			  {Order,PlayerId, _AttNum, _GuildName, _Nick, _Career, _Realm, _HorTd, _MgcTd, _Vip,Lv} = Info,
			  Id = db_agent:new_single_td_award(PlayerId,Lv,Order,NowTime),
			  NewAward = #ets_single_td_award{ id=Id,pid=PlayerId,lv=Lv,order=Order,timestamp=NowTime},
			  update_single_td_awrd(NewAward),
			  spawn(fun()->notice_single_td_award(PlayerId)end)
	  end, Rank),
	ok.	

notice_single_td_award(PlayerId)->
	case lib_player:get_online_info(PlayerId) of
		[]->skip;
		PlayerStatus->
			PidSend = PlayerStatus#player.other#player_other.pid_send,
			get_tds_rank_order_all(PidSend,PlayerStatus#player.id,PlayerStatus#player.lv,1)
	end.

get_single_td_rank_info()->
	ets:tab2list(?ETS_TD_S_ALL).

award_single_td_get(PlayerStatus)->
	Res = case select_single_td_award(PlayerStatus#player.id) of
			  []->2;
			  [Award]->
				  {Spt,BCoin} = single_td_award(Award#ets_single_td_award.lv,Award#ets_single_td_award.order),
				  gen_server:cast(PlayerStatus#player.other#player_other.pid,{'single_td_award',[Spt,BCoin]}),
				  del_single_td_award(PlayerStatus#player.id),
				  db_agent:del_single_td_award(PlayerStatus#player.id),
				  spawn(fun()->db_agent:log_single_td_award(PlayerStatus#player.id,Award#ets_single_td_award.order,Award#ets_single_td_award.lv,Spt,BCoin,util:unixtime())end),
				  1
		  end,
	{ok,BinData} = pt_22:write(22019,[Res]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData).	

sigle_td_rank_cmd()->
	%% 镇妖台（单）排行榜
	TDSRanksAll = loop_tds_rank_all(),	
	insert_rank_info(?ETS_TD_S_ALL, TDSRanksAll).

%%给玩家自动发送镇妖台奖励
single_td_award_auto(AwardBag)->
%% 	AwardBag = select_single_td_award_all(),
	single_td_award_auto_loop(AwardBag),
	ok.

single_td_award_auto_loop([])->ok;
single_td_award_auto_loop([Award|AwardBag])->
	{Spt,BCoin} = single_td_award(Award#ets_single_td_award.lv,Award#ets_single_td_award.order),
	NowTime = util:unixtime(),
	spawn(fun()->auto_award(Award#ets_single_td_award.pid,Award#ets_single_td_award.order,Spt,BCoin,NowTime)end),
	single_td_award_auto_loop(AwardBag).

auto_award(PlayerId,Rank,Spt,Bcoin,NowTime)->
	GoodsSpt = round(Spt div 10000),
	GoodsBcoin = round(Bcoin div 5000),
	if GoodsSpt =<0 andalso GoodsBcoin =< 0 ->skip;
	   true->
%% 		   case lib_player:get_role_name_by_id(PlayerId) of
%% 			   null->skip;
		   %% Nickname->
		   PlayerData = db_agent:get_player_mult_properties([nickname,last_login_time],[PlayerId]),
		   case lists:keyfind(PlayerId,1,PlayerData) of
			   false->skip;
			   {_1,[NickName,LoginTime]}->
				   if NowTime - LoginTime > 5*3600->skip;
					  true->
						  NameList = [tool:to_list(NickName)],
						  Title = "镇妖台（单人）排行奖励",
						  if GoodsSpt > 0->
								 Msg = io_lib:format("恭喜您在镇妖台（单人）排行上获得~p名，获得了~p个中灵力丹奖励。",[Rank,GoodsSpt]),
								 mod_mail:send_sys_mail(NameList, Title, Msg, 0, 23301, GoodsSpt, 0,0),
								 ok;
							 true->skip
						  end,
						  if GoodsBcoin > 0->
								 Msg1 = io_lib:format("恭喜您在镇妖台（单人）排行上获得~p名，获得了~p个中级绑定铜币卡。",[Rank,GoodsBcoin]),
								 mod_mail:send_sys_mail(NameList, Title, Msg1, 0, 28039, GoodsBcoin, 0,0),
								 ok;
							 true->skip
						  end
				   end;
			   _->skip
		   end			   
	end,
	ok.

%%GM命令，修改镇妖排名
cmd_single_td_rank(PlayerId,Rank)->
	case select_single_td_award(PlayerId) of 
		[]->skip;
		[Award]->
			if Rank>0 andalso Rank < 501->
				   NewAward = Award#ets_single_td_award{order=Rank},
				   update_single_td_awrd(NewAward),
				   db_agent:update_single_td_awrd([{order,Rank}],[{pid,PlayerId}]),
				   ok;
			   true->skip
			end
	end.

%%三月活动,坐骑排行榜奖励
march_mount_award() ->
	[{ets_rank,_RankTypeId,Data}] = ets:lookup(?ETS_RANK, ?MOUNT_RANK_TYPE_ID),
	RankInfo = add_order([],Data,1),
	TenFirst = lists:sublist(RankInfo, 10),
	lists:foreach(fun(Elem) ->
						  [Order, _PlayerId, Nickname, _MountId, _Name, _Level, _Color, _Step, _Mount_val, _Vip] = Elem,
						  lib_act_interf:mount_rank_award(Nickname, Order)
				  end, TenFirst).


%%获取跨服排行榜数据信息
get_war_rank_to_remote()->
	{BattRankBag,RankRecord} = get_rank_20(),
	{EquipList,AttList} = get_goods_info(BattRankBag,[],[]),
	PlayerBase = get_player_base_info(BattRankBag,[]),
%% 	gen_server:cast(mod_rank:get_mod_rank_pid(),{'war_battvalue_rank',[RankRecord,EquipList,AttList,PlayerBase]}),
	mod_leap_server:sync_war_rank([RankRecord,EquipList,AttList,PlayerBase]),
	ok.

answer_war_rank([Platform,Sn])->
	{BattRankBag,RankRecord} = get_rank_20(),
	{EquipList,AttList} = get_goods_info(BattRankBag,[],[]),
	PlayerBase = get_player_base_info(BattRankBag,[]),
	mod_leap_server:answer_war_rank([Platform,Sn,[RankRecord,EquipList,AttList,PlayerBase]]),
	ok.

%%获取前20
get_rank_20()->
	BattRanks = db_agent:loop_query_batt_value(?SLAVE_POOLID,20),
	BattRanks1 = lists:sublist(BattRanks, 20),	
	PlayerValueList = [{PlayerId,BattValue} || [PlayerId,BattValue] <- BattRanks1],
	PlayerIdList = [_Player_Id || [_Player_Id,_BattValue] <- BattRanks1],
	PlayerInfoList = db_agent:get_player_mult_properties([id, nickname, sex, career, realm, guild_name, vip],lists:flatten(PlayerIdList)), 
	F = fun([Id, Nickname, Sex, Career, Realm, Guild_name, Vip]) ->
				{_Id, Value}  = lists:keyfind(Id, 1, PlayerValueList),
				[new_player_id(Id), nickname(Nickname), Sex, Career, Realm, Guild_name, Value, Vip]
		end,
	BattRanks2 = [F([Id, Nickname, Sex, Career, Realm, Guild_name, Vip]) || {_Key,[Id, Nickname, Sex, Career, Realm, Guild_name,Vip]} <- PlayerInfoList],
	BattRanks3 = lists:sort(fun([_Id1, _Nickname1, _Sex1, _Career1, _Realm1, _Guild_name1, Value1, _Vip1],[_Id2, _Nickname2, _Sex2, _Career2, _Realm2, _Guild_name2, Value2, _Vip2]) ->
									 Value1 >= Value2 end,BattRanks2),
    RankRecord = make_rank_info(?WAR_BATT_RANK_TYPE_ID, BattRanks3),
	{PlayerValueList,RankRecord}.

nickname(Nickname)->Nickname.
%% 	lists:concat(["跨服-",tool:to_list(Nickname)]).


%%获取装备信息
get_goods_info([],GoodsBag,Att)->{GoodsBag,Att};
get_goods_info([{Pid,_}|BattBag],GoodsBag,Att)->
	EquipList = goods_util:get_offline_goods(Pid, 1),
	NewPid = new_player_id(Pid),
	{NewE,EAtt} = replace_pid(EquipList,NewPid,[],[]),
	get_goods_info(BattBag,[{NewPid,NewE}|GoodsBag],EAtt++Att).

%%获取装备属性
get_goods_att(Pid,Gid)->
	[GoodsInfo, SuitNum, AttributeList] = lib_goods:get_goods_info_from_db(Pid,Gid),
	NewPid = new_player_id(Pid),
	NewAttributeList = replace_att_pid(AttributeList,NewPid,[]),
	[NewPid,Gid,GoodsInfo, SuitNum, NewAttributeList].


%%替换装备玩家id
replace_pid([],_Pid,NewGoods,GoodsAtt)->{NewGoods,GoodsAtt};
replace_pid([Goods|GoodsBag],Pid,NewGoods,GoodsAtt)->
	AttList = get_goods_att(Goods#goods.player_id,Goods#goods.id),
	replace_pid(GoodsBag,Pid,[Goods#goods{player_id=Pid}|NewGoods],[AttList|GoodsAtt]).
%%替换装备属性玩家id
replace_att_pid([],_Pid,NewGoods)->NewGoods;
replace_att_pid([Goods|GoodsBag],Pid,NewGoods)->
	replace_att_pid(GoodsBag,Pid,[Goods#goods_attribute{player_id=Pid}|NewGoods]).

%%获取玩家基本信息13029
get_player_base_info([],Info)->Info;
get_player_base_info([{Pid,_}|Bag],Info)->
	case lib_player:get_palyer_properties(Pid,[id, nickname, realm, sex, lv, career, vip, mount]) of
		[]->get_player_base_info(Bag,Info);
		[_Id, Nickname, Realm, Sex, Lv, Career, Vip, Mount]->
			case Mount of 
				0 -> 
					MountTypeId = 0;
				_ -> 
					MountTypeId1 = goods_util:get_goods_type_db(Mount),
					case MountTypeId1 == null of
						true -> MountTypeId = 0;
						false -> MountTypeId = MountTypeId1
					end
			end,
			NewPid = new_player_id(Pid),
			Result = [NewPid, Nickname, Realm, Sex, Lv, Career, Vip, Mount,MountTypeId],
			get_player_base_info(Bag,[{NewPid,Result}|Info])
	end.

new_player_id(PlayerId)->
	100000000+PlayerId.


%%同步跨服排行数据到本地
get_war_rank_to_local([RankRecord,EquipList,AttList,PlayerBase])->
	ets:insert(?ETS_RANK, RankRecord),
	equip_info_to_cache(EquipList),
	equip_att_info_to_cache(AttList),
	player_base_info_tp_cache(PlayerBase),
	ok.

equip_info_to_cache([])->skip;
equip_info_to_cache([{Pid,E}|EBag])->
	mod_cache:g_set({mod_goods,get_offline_goods,Pid},E,10800),
	equip_info_to_cache(EBag).

equip_att_info_to_cache([])->skip;
equip_att_info_to_cache([E|EBag])->
	[Pid,Gid,GoodsInfo, SuitNum, NewAttributeList] = E,
	mod_cache:g_set({mod_goods,info_15003,Pid,Gid},[GoodsInfo, SuitNum, NewAttributeList],10800),
	equip_att_info_to_cache(EBag).

player_base_info_tp_cache([])->skip;
player_base_info_tp_cache([{Pid,Info}|Bag])->
	mod_cache:g_set({pp_player,13029,Pid},Info,10800),
	player_base_info_tp_cache(Bag).