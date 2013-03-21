%% Author: xianrongMai
%% Created: 2011-10-8
%% Description: 专门处理人物称号的模块
-module(lib_title).

%%
%% Include files
%%

-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("achieve.hrl").

%%
%% Exported Functions
%%
-export([
		 check_one/2,
		 check_get_ornot/2,
		 check_normal_t_use/1,			%%检查是否有使用普通称
		 pack_titles_data/1,			%%称号数据打包处理(专职打包数据)
		 sex_change_title/2,			%%变性修改称号
		 notices_title_change/2,
		 update_server_titles/2,
		 player_claim_ach_title/4,		%%玩家领取并使用称号
		 compare_title/3,
		 rank_change_titles/0
		]).

%%
%% API Functions
%%
%%称号数据打包处理
pack_titles_data(CharmTitle) ->
	pack_titles(CharmTitle, [], 0).
pack_titles([], NTitles, Num) ->
	{Num, tool:to_binary(NTitles)};
pack_titles([Elem|Rest], Titles, Num) ->
	NTitles = [<<Elem:32>>|Titles],
	pack_titles(Rest, NTitles, Num+1).
								 
%%人物称号数据兼容性处理
compare_title(Ts, Title, PId) ->
%% 	?DEBUG("Ts:~p, Title:~p, PId:~p", [Ts, Title, PId]),
	case Title of
		Val when is_integer(Val) ->
			case lists:keyfind(Val, #p_title_elem.tid, Ts) of
				false ->
					NTitle = [],
					NTitleStr = util:term_to_string(NTitle),
					ValueList = [{ptitle, NTitleStr}],
					WhereList = [{pid, PId}],
					db_agent:update_player_other(player_other, ValueList, WhereList),
					NTitle;
				TElem ->
					NTitle = [TElem#p_title_elem.tid],
					NTitleStr = util:term_to_string(NTitle),
					ValueList = [{ptitle, NTitleStr}],
					WhereList = [{pid, PId}],
					db_agent:update_player_other(player_other, ValueList, WhereList),
					NTitle
			end;
		Val when is_list(Val) ->
			Title;
		_ ->
			NTitle = [],
			NTitleStr = util:term_to_string(NTitle),
			ValueList = [{ptitle, NTitleStr}],
			WhereList = [{pid, PId}],
			db_agent:update_player_other(player_other, ValueList, WhereList),
			NTitle
	end.

%%检查是否有使用普通称号
check_normal_t_use(Titles) ->
	check_use(Titles).
check_use([]) ->
	false;
check_use([Elem|Titles]) ->
	case Elem >= 101 andalso Elem =< 700 of
		true ->
			{true, Elem};
		false ->
			check_use(Titles)
	end.

%%变性修改称号
sex_change_title(NeedIds, Titles) ->
	[{CheckO,ChangeO},{CheckT, ChangeT}] = NeedIds,
	{OutType, OutNTitles} = lists:foldl(fun(Elem, AccIn) ->
												{Type, Ids} = AccIn,
												if
													Elem =:= CheckO ->
														{1, [ChangeO|Ids]};
													Elem =:= CheckT ->
														{1, [ChangeT|Ids]};
													true ->
														{Type, [Elem|Ids]}
												end
										end, {0, []}, Titles),
	%%转置一下
	{OutType, lists:reverse(OutNTitles)}.

%%
%% Local Functions
%%
%%玩家领取并使用称号
player_claim_ach_title(Type, AchNum, ExpireTime, Status) ->
	%%检测是否已经加载过 成就系统的数据
	lib_achieve_inline:check_achieve_init(Status#player.id),
	Now = util:unixtime(),
	#player{id = PlayerId,
			realm = Realm,
			other = Other
			} = Status,
	OTitles = Other#player_other.titles,
%% 	?DEBUG("one Title:~p", [OTitles]),
	case lib_achieve_inline:get_achieve_ets(Status#player.id) of
		[] ->
			{0, Status};
		[Achieve] ->
			Titles = 
				case lib_title:check_normal_t_use(OTitles) of
					{true, _HUseTid} ->
						[];
					false ->
						OTitles
				end,
%% 			?DEBUG("two Title:~p", [Titles]),
			PTitles = Achieve#ets_achieve.ach_titles,
			{RType, FailType, NewPTitles} =  
				case lists:keyfind(AchNum, #p_title_elem.tid, PTitles) of
					false when Type =:= 1 ->
						NewTitle = #p_title_elem{tid = AchNum,
												 expi = Now+ExpireTime},
						{ok, 1, [NewTitle|PTitles]};
					false when Type =:= 0 ->
						if
							AchNum =:= 901 ->%%封神台霸主
								IdList = get_titles_players(fst),
%% 								?DEBUG("THE FST LISTS: ~p", [IdList]),
								case IdList of
									[] ->
										{fail, 3, PTitles};
									_ ->
										case lists:member(PlayerId, IdList) of
%% 										case lists:member(PlayerId, [28]) of%%测试用的
											true ->
												NewTitle = #p_title_elem{tid = AchNum,
																		 expi = 1},
												{ok, 1, [NewTitle|PTitles]};
											false ->
												{fail, 3, PTitles}
										end
								end;
							AchNum =:= 902 ->%%天下无敌
								FirstList = get_titles_players(area_king),
								case lists:member(PlayerId, FirstList) of
%% 								case PlayerId =:= 28 of%%测试用的
									true ->
										NewTitle = #p_title_elem{tid = AchNum,
																 expi = 1},
										{ok, 1, [NewTitle|PTitles]};
									false ->
										{fail, 3, PTitles}
								end;
							AchNum =:= 903 -> %%女娲英雄
								case Realm =:= 1 of
									true ->
										%%查询部落荣誉最高的女娲族人
										FirstList = get_titles_players(nwfirst),
								case lists:member(PlayerId, FirstList) of
%% 										case PlayerId =:= 28 of%%测试用的
											true ->
												NewTitle = #p_title_elem{tid = AchNum,
																		  expi = 1},
												{ok, 1, [NewTitle|PTitles]};
											false ->
												{fail, 3,PTitles}
										end;
									false ->
										{fail, 4,PTitles}
								end;
							AchNum =:= 904 -> %%神农英雄
								case Realm =:= 2 of
									true ->
										%%查询部落荣誉最高的神农族人
										FirstList = get_titles_players(snfirst),
								case lists:member(PlayerId, FirstList) of
%% 										case PlayerId =:= 28 of%%测试用的
											true ->
												NewTitle = #p_title_elem{tid = AchNum,
																		  expi = 1},
												{ok, 1, [NewTitle|PTitles]};
											false ->
												{fail, 3,PTitles}
										end;
									false ->
										{fail, 4,PTitles}
								end;
							AchNum =:= 905 -> %%伏羲英雄
								case Realm =:= 3 of
									true ->
										%%查询部落荣誉最高的伏羲族人
										FirstList = get_titles_players(fxfirst),
								case lists:member(PlayerId, FirstList) of
%% 										case PlayerId =:= 28 of%%测试用的
											true ->
												NewTitle = #p_title_elem{tid = AchNum,
																		  expi = 1},
												{ok, 1, [NewTitle|PTitles]};
											false ->
												{fail, 3,PTitles}
										end;
									false ->
										{fail, 4,PTitles}
								end;
							AchNum =:= 906 -> %%不差钱
								%%财富榜第一名的玩家
								FirstList = get_titles_players(rich),
								case lists:member(PlayerId, FirstList) of
%% 								case PlayerId =:= 28 of%%测试用的
									true ->
										NewTitle = #p_title_elem{tid = AchNum,
																 expi = 1},
										{ok, 1, [NewTitle|PTitles]};
									false ->
										{fail, 3,PTitles}
								end;
							AchNum =:= 907 -> %%八神之主
								FirstList = get_titles_players(ach),
								case lists:member(PlayerId, FirstList) of
%% 								case PlayerId =:= 28 of
									true ->
										NewTitle = #p_title_elem{tid = AchNum,
																 expi = 1},
										{ok, 1, [NewTitle|PTitles]};
									false ->
										{fail, 3,PTitles}
								end;
							AchNum =:= 908 -> %%绝世神兵
								FirstList = get_titles_players(equip),
								case lists:member(PlayerId, FirstList) of
%% 								case PlayerId =:= 28 of%%测试用的
									true ->
										NewTitle = #p_title_elem{tid = AchNum,
																 expi = 1},
										{ok, 1, [NewTitle|PTitles]};
									false ->
										{fail, 3,PTitles}
								end;
							AchNum =:= 909 -> %%诛仙霸主
								FirstList = get_titles_players(zxt),
								case lists:member(PlayerId, FirstList) of
%% 										case lists:member(PlayerId, [28]) of%%测试用的
											true ->
												NewTitle = #p_title_elem{tid = AchNum,
																		 expi = 1},
												{ok, 1, [NewTitle|PTitles]};
											false ->
												{fail, 3, PTitles}
										end;
							AchNum =:= 910 -> %%全民偶像
								FirstList = get_titles_players(adore),
								case lists:member(PlayerId, FirstList) of
%% 										case lists:member(PlayerId, [28]) of%%测试用的
											true ->
												NewTitle = #p_title_elem{tid = AchNum,
																		 expi = 1},
												{ok, 1, [NewTitle|PTitles]};
											false ->
												{fail, 3,PTitles}
										end;
							AchNum =:= 911 -> %%全民公敌
								FirstList = get_titles_players(disdain),
								case lists:member(PlayerId, FirstList) of
%% 										case lists:member(PlayerId, [28]) of%%测试用的
											true ->
												NewTitle = #p_title_elem{tid = AchNum,
																		 expi = 1},
												{ok, 1, [NewTitle|PTitles]};
											false ->
										{fail, 3,PTitles}
								end;
							AchNum =:= 912 -> %%远古战神
								%%战斗力榜第一名的玩家
								FirstList = get_titles_players(ygzs),
								case lists:member(PlayerId, FirstList) of
%% 								case PlayerId =:= 28 of%%测试用的
									true ->
										NewTitle = #p_title_elem{tid = AchNum,
																 expi = 1},
										{ok, 1, [NewTitle|PTitles]};
									false ->
										{fail, 3,PTitles}
								end;
							AchNum =:= 913 -> %%九霄城主
								%%
								FirstList = get_titles_players(castle),
								case lists:member(PlayerId, FirstList) of
									%% 								case PlayerId =:= 4 of%%测试用的
									true ->
										NewTitle = #p_title_elem{tid = AchNum,
																 expi = 1},
										{ok, 1, [NewTitle|PTitles]};
									false ->
										{fail, 3,PTitles}
								end;
							AchNum =:= 914 -> %%天下第一
								FirstList = get_titles_players(world_first),
								case lists:member(PlayerId, FirstList) of
									true ->
										NewTitle = #p_title_elem{tid = AchNum,
																 expi = 1},
										{ok, 1, [NewTitle|PTitles]};
									false ->
										{fail, 3,PTitles}
								end;
							AchNum =:= 915 -> %%远古无双
								FirstList = get_titles_players(yg_unique),
								case lists:member(PlayerId, FirstList) of
									true ->
										NewTitle = #p_title_elem{tid = AchNum,
																 expi = 1},
										{ok, 1, [NewTitle|PTitles]};
									false ->
										{fail, 3,PTitles}
								end;
							AchNum =:= 916 -> %%一骑绝尘
								FirstList = get_titles_players(mount_king),
								case lists:member(PlayerId, FirstList) of
									true ->
										NewTitle = #p_title_elem{tid = AchNum,
																 expi = 1},
										{ok, 1, [NewTitle|PTitles]};
									false ->
										{fail, 3,PTitles}
								end;
							true ->
								NewTitle = #p_title_elem{tid = AchNum,
														 expi = 1},
								{ok, 1, [NewTitle|PTitles]}
						end;
					_GotTitle when Type =:= 1 ->%%兑换魅力值的
						NewTitle = #p_title_elem{tid = AchNum,
												 expi = Now+ExpireTime},
						{ok, 1, lists:keyreplace(AchNum, #p_title_elem.tid, PTitles, NewTitle)};
					_GotTitle when Type =:= 0 ->%%已经领取过了
						{fail, 5, PTitles}
				end,
			case RType of
				ok ->
					NewTitles = 
						case lists:member(AchNum, Titles) of
							true ->
								Titles;
							false ->
								[AchNum|Titles]
						end,
%% 					更新数据库
					NewTitlesStr = util:term_to_string(NewTitles),
					NewPTitlesStr = util:term_to_string(NewPTitles),
					ValueList = [{ptitle, NewTitlesStr}, {ptitles, NewPTitlesStr}],
					WhereList = [{pid, PlayerId}],
					db_agent:update_player_other(player_other, ValueList, WhereList),
					%%改ets
					NewAchieve = Achieve#ets_achieve{ach_titles = NewPTitles},
					lib_achieve_inline:update_achieve_ets(NewAchieve),
					NewStatus = Status#player{other = Status#player.other#player_other{titles = NewTitles}},
					%%往客户端推消息更新
					lib_love:bc_title_in_scene(NewStatus,NewTitles),
%% 					?DEBUG("the new Title:~p", [NewTitles]),
					{ok, NewStatus};
				fail ->
					{FailType, Status}
			end
	end.


rank_change_titles() ->
	{Fst, NWFirst, SNFirst, FXFirst, Rich, Ach, Equip, Zxt, YGZS} =
		lib_rank:get_ach_rank_first_inline(),
	change_sever_titles({Fst, NWFirst, SNFirst, FXFirst, Rich, Ach, Equip, Zxt, YGZS}).

%%通知称号处理进程处理称号修改
change_sever_titles(Param) ->
%% 	?DEBUG("Param:~p", [Param]),
	gen_server:cast(mod_title:get_mod_title_pid(), {'UPDATE_SERVER_TITLES', Param}).

update_server_titles(Param, State) ->
	{Fst, AreaKing, NWFirst, SNFirst, FXFirst, Rich, Ach, Equip, Zxt, Adore, Disdain, YGZS, Castle, WorldFirst, YGUnique, MountKing} = Param,
	List = [{fst, Fst},{area_king, [AreaKing]}, {nwfirst, [NWFirst]}, {snfirst, [SNFirst]},
			{fxfirst, [FXFirst]}, {rich, [Rich]}, {ach, [Ach]}, {equip, [Equip]}, {zxt, Zxt},
			{adore, Adore}, {disdain, Disdain}, {ygzs, [YGZS]}, {castle, [Castle]}, {world_first, WorldFirst}, {yg_unique, YGUnique}, {mount_king, MountKing}],
	lists:foldl(fun(Elem, AccIn) ->
						{TType, NIds} = Elem,
						NIdsZero = delete_zero(NIds, []),%%去掉0的操作
						update_server_titles(TType, NIdsZero, AccIn)
				end, State, List).
%%去掉0的操作
delete_zero([], Result) ->
	Result;
delete_zero([Elem|NIds], Result) ->
	case Elem =:= 0 of
		true ->
			delete_zero(NIds, Result);
		false ->
			delete_zero(NIds, [Elem|Result])
	end.

update_server_titles(TType, NIds, State) ->
	{TNum, TIds, NState} = 
		case TType of
			fst ->
				{901, State#server_titles.fst,
				 State#server_titles{fst = NIds}};
			area_king ->
				{902, State#server_titles.area_king,
				 State#server_titles{area_king = NIds}};
			nwfirst ->
				{903, State#server_titles.nwfirst,
				 State#server_titles{nwfirst = NIds}};
			snfirst ->
				{904, State#server_titles.snfirst,
				 State#server_titles{snfirst = NIds}};
			fxfirst ->
				{905, State#server_titles.fxfirst,
				 State#server_titles{fxfirst = NIds}};
			rich ->
				{906, State#server_titles.rich,
				 State#server_titles{rich = NIds}};
			ach ->
				{907, State#server_titles.ach,
				 State#server_titles{ach = NIds}};
			equip ->
				{908, State#server_titles.equip,
				 State#server_titles{equip = NIds}};
			zxt ->
				{909, State#server_titles.zxt,
				 State#server_titles{zxt = NIds}};
			adore ->
				{910, State#server_titles.adore,
				 State#server_titles{adore = NIds}};
			disdain ->
				{911, State#server_titles.disdain,
				 State#server_titles{disdain = NIds}};
			ygzs ->
				{912, State#server_titles.ygzs,
				 State#server_titles{ygzs = NIds}};
			castle ->
				{913, State#server_titles.castle,
				 State#server_titles{castle = NIds}};
			world_first ->
				{914, State#server_titles.world_first,
				 State#server_titles{world_first = NIds}};
			yg_unique ->
				{915, State#server_titles.yg_unique,
				 State#server_titles{yg_unique = NIds}};
			mount_king ->
				{916, State#server_titles.mount_king,
				 State#server_titles{mount_king = NIds}};
			_ ->
				{0, [],
				 State}
		end,
	case TNum of
		0 ->
			skip;
		_ ->
			%%过滤掉新的相同的名单
			FilterIds = lists:filter(fun(FElem) ->
											case lists:member(FElem, NIds) of
												true ->
													false;
												false ->
													true
											end
									 end, TIds),
			%%对需要删除的名单进行通知处理
			lists:foreach(fun(Elem) -> 
								  case lib_player:get_player_pid(Elem) of
									  [] ->%%不在线
										  FieldList = "ptitle, ptitles",
										  WhereList = [{pid, Elem}],
										  case db_select_server_titles(player_other, FieldList, WhereList) of
											  [] ->%%没这个人，没劲
												  skip;
											   [UTStr, GTStr] ->
												   OGTitles = util:string_to_term(tool:to_list(GTStr)),
												   if 
													   is_list(OGTitles) ->
														   GT = OGTitles;
													   true ->
														   GT = []
												   end,
												   UT = 
													   if
														   is_integer(UTStr) ->
															   case UTStr =:= 0 of
																   true ->
																	   [];
																   false ->
																	   [UTStr]
															   end;
														   true ->
															   OUTitle = util:string_to_term(tool:to_list(UTStr)),
															   if
																   is_list(OUTitle) ->
																	   OUTitle;
																   true ->
																	   []
															   end
													   end,
												   NGT = lists:keydelete(TNum, #p_title_elem.tid, GT),
												   NUT = lists:delete(TNum, UT),
%% 												   ?DEBUG("NGT:~p; GT:~p; NUT:~p; UT:~p", [NGT,GT,NUT,UT]),
												   case NGT =:= GT andalso NUT =:= UT of
													   true ->%%没变过，不用改数据库了
														   skip;
													   false ->
														   NUTStr = util:term_to_string(NUT),
														   NGTStr = util:term_to_string(NGT),
														   ValueList = [{ptitle, NUTStr}, {ptitles, NGTStr}],
														   db_update_server_titles(player_other, ValueList, WhereList)
												   end
										  end;
									  PPid ->
										  gen_server:cast(PPid, {'NOTICES_TITLE_CHANGE', TNum})
								  end	
						  end, FilterIds),
			%%改数据库数据
			change_db_server_titles(TNum, NIds)
%% 			NIdsStr = util:term_to_string(NIds),
%% 			ValueList = [{ids, NIdsStr}],
%% 			WhereList = [{type, TNum}],
%% 			db_update_server_titles(server_titles, ValueList, WhereList)
	end,
	NState.

%%在线更新玩家称号集
notices_title_change(TNum, Player) ->
	UTs = Player#player.other#player_other.titles,
	%%检测是否已经加载过 成就系统的数据
	lib_achieve_inline:check_achieve_init(Player#player.id),
	case lib_achieve_inline:get_achieve_ets(Player#player.id) of
		[] ->
			Player;
		[Achieve] ->
			GTs = Achieve#ets_achieve.ach_titles,
			NGTs = lists:keydelete(TNum, #p_title_elem.tid, GTs),
			NUTs = lists:delete(TNum, UTs),
			NUTsStr = util:term_to_string(NUTs),
			NGTsStr = util:term_to_string(NGTs),
			ValueList = [{ptitle, NUTsStr}, {ptitles, NGTsStr}],
			WhereList = [{pid, Player#player.id}],
			db_update_server_titles(player_other, ValueList, WhereList),
			%%改ets
			NewAchieve = Achieve#ets_achieve{ach_titles = NGTs},
			lib_achieve_inline:update_achieve_ets(NewAchieve),
			NPlayer = Player#player{other = Player#player.other#player_other{titles = NUTs}},
			%%通知称号被取消
			{ok, BinData38015} = pt_38:write(38015, [TNum]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData38015),
			%%广播称号消失
			lib_love:bc_title_in_scene(Player, NUTs),
			%%同步数据
			mod_player:save_online_diff(Player,NPlayer),
			NPlayer
	end.


check_one(Elem, InSide) ->
	case Elem =:= InSide of
		true ->
			1;
		false ->
			0
	end.
check_list(Elem, InSide) ->
	case lists:member(Elem, InSide) of
		true ->
			1;
		false ->
			0
	end.


%% %%检查是否需要删掉错误获得的特殊称号
%% whether_change_ornot(C, Num, First, Ach, Titles) ->
%% 	case C of
%% 		2 ->
%% 			case lists:member(Num, First) of
%% 				true ->%%第二次判断，保证称号是正确的，还好， 目前也是
%% 					{Ach, Titles, 2};
%% 				false ->%%已经不是该玩家了，直接主动清除掉
%% 					NTitles = lists:keydelete(Num, #p_title_elem.tid, Titles),
%% 					NAch = lists:delete(Num, Ach),
%% 					{NAch, NTitles, 0}
%% 			end;
%% 		_ ->
%% 			check_list(Num, First)
%% 	end.
%% 			
%% update_whether_change(IsChange, DelNums, TNums, Titles, Achieve, Player) ->
%% %% 	OTNums = Player#player.other#player_other.titles,
%% %% 	OTitles = Achieve#ets_achieve.ach_titles,
%% 	 case IsChange of
%% 		 true ->%%没变过，不用改数据库了
%% 			 skip;
%% 		 false ->
%% 			 NTNums = util:term_to_string(TNums),
%% 			 NTitles = util:term_to_string(Titles),
%% 			 ValueList = [{ptitle, NTNums}, {ptitles, NTitles}],
%% 			 WhereList = [{pid, Player#player.id}],
%% 			 db_update_server_titles(player_other, ValueList, WhereList),
%% 			 %%改ets
%% 			 NewAchieve = Achieve#ets_achieve{ach_titles = Titles},
%% 			 lib_achieve_inline:update_achieve_ets(NewAchieve),
%% 			 NPlayer = Player#player{other = Player#player.other#player_other{titles = TNums}},
%% 			 %%通知称号被取消
%% 			 lists:foreach(fun(Elem) ->
%% 								   {ok, BinData38015} = pt_38:write(38015, [Elem]),
%% 								   lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData38015)
%% 						   end, DelNums),
%% 			 %%广播称号消失
%% 			 lib_love:bc_title_in_scene(Player, TNums),
%% 			 %%同步数据
%% 			 mod_player:save_online_diff(Player,NPlayer),
%% 			 NPlayer
%% 	end.

check_get_ornot(PId, SpecTs) ->
	%%获取特殊称号的所有能够获取的人物名单
%% 	{Fst, Areaking, NWFirst, SNFirst, FXFirst, Rich, Ach, Equip, Zxt, Adore, Disdain, YGZS, Castle} =
%% 		lib_rank:get_ach_rank_first(),
	TitleState = get_all_titles(),
%% 	?DEBUG("Pid:~p,TitleState:~p", [PId, TitleState]),
%% 	?DEBUG("first is :~p", [{Fst, Areaking, NWFirst, SNFirst, FXFirst, Rich, Ach, Equip, Zxt, Adore, Disdain, YGZS}]),
	lists:map(fun(Elem) ->
					  {A, B, C, D} = Elem,
					  case C of
						  2 ->
							  Elem;
						  _ ->
							  NC = 
								  case A of
									  901 ->
										  check_list(PId, TitleState#server_titles.fst);
									  902 ->
										  check_list(PId, TitleState#server_titles.area_king);
									  903 ->
										  check_list(PId, TitleState#server_titles.nwfirst);
									  904 ->
										  check_list(PId, TitleState#server_titles.snfirst);
									  905 ->
										  check_list(PId, TitleState#server_titles.fxfirst);
									  906 ->
										  check_list(PId, TitleState#server_titles.rich);
									  907 ->
										  check_list(PId, TitleState#server_titles.ach);
									  908 ->
										  check_list(PId, TitleState#server_titles.equip);
									  909 ->
										  check_list(PId, TitleState#server_titles.zxt);
									  910 ->
										  check_list(PId, TitleState#server_titles.adore);
									  911 ->
										  check_list(PId, TitleState#server_titles.disdain);
									  912 ->
										  check_list(PId, TitleState#server_titles.ygzs);
									  913 ->
										  check_list(PId, TitleState#server_titles.castle);
									  914 ->
										  check_list(PId, TitleState#server_titles.world_first);
									  915 ->
										  check_list(PId, TitleState#server_titles.yg_unique);
									  916 ->
										  check_list(PId, TitleState#server_titles.mount_king);
									  _ ->
										  C
								  end,
							   {A,B,NC,D}
					  end
			  end, SpecTs).
									  
							
db_select_server_titles(Table, FieldList, WhereList) ->
	db_agent:select_server_titles(Table, FieldList, WhereList).
db_update_server_titles(Table, ValueList, WhereList) ->
	db_agent:update_server_titles(Table, ValueList, WhereList).
db_delete_server_titles(Table, WhereList) ->
	db_agent:delete_server_titles(Table, WhereList).
db_insert_server_titles(Table, Fields, Values) ->
	db_agent:db_insert_server_titles(Table, Fields, Values).

change_db_server_titles(TNum, NIds) ->
	%%删除旧数据
	WhereList = [{type, TNum}],
	db_delete_server_titles(server_titles, WhereList),
	spawn(fun()-> 
				  lists:foreach(fun(Elem) ->
								  Values = [TNum, Elem],
								  Fields = [type, pid],
								  db_insert_server_titles(server_titles, Fields, Values)
						  end, NIds)
		  end).

%%获取能够拥有称号的成员
get_titles_players(Type) ->
	case catch (gen_server:call(mod_title:get_mod_title_pid(), {'GET_TITLES_PLAYERS', Type})) of
		{ok, Reply} ->
			Reply;
		_ ->
			[]
	end.

get_all_titles() ->
	case catch (gen_server:call(mod_title:get_mod_title_pid(), {'GET_ALL_TITLES'})) of
		{ok, Reply} ->
			Reply;
		_ ->
			#server_titles{}
	end.