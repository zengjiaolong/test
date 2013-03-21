%%%------------------------------------
%%% @Module  : mod_dungeon_analytics
%%% @Author  : ygzj
%%% @Created : 2011.01.05
%%% @Description: 副本掉落数据统计
%%%------------------------------------

-module(mod_dungeon_analytics).

-export(
    [
		mon_drop_extra/3,
		drop_goods/4     
    ]
).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

mon_drop_extra(Player, Mon, PlayerList) ->
	case lib_goods_drop:check_drop_num(Mon) of
		false ->
			case Mon#ets_mon.mid >= 41057 andalso Mon#ets_mon.mid =< 41098 of
				true->lib_task:task_event(train_kill, Mon#ets_mon.mid, Player);
				false->
					skip	
			end,
			lib_task:event(kill, Mon#ets_mon.mid, Player),
			if Player#player.lv >= 30->
				   lib_task:event(hero_kill, {Mon#ets_mon.lv}, Player);
			   true->skip
			end;
		{true, DropNum, RuleList, TotalRatio} ->
			mon_drop_analytics(Player, Mon, DropNum, RuleList, TotalRatio, PlayerList)
	end.


%% %% 一个掉落包金色以上物品只掉一个
%% filter_goods_by_color([], _MonType, _Color, _IsFilter, Ret) ->
%% 	Ret;
%% filter_goods_by_color([{GoodsTypeId, GoodsType, GoodsNum, GoodsColor, MonTeyp} | D], MonType, Color, IsFilter, Ret) ->
%%     if
%% 		GoodsColor >= Color andalso MonType /= 3 ->
%% 			if
%%           		IsFilter == 0 ->
%%                     NewRet = [{GoodsTypeId, GoodsType, GoodsNum, GoodsColor, MonTeyp} | Ret],					
%%                     filter_goods_by_color(D, MonType, Color, 1, NewRet);
%%          		true ->
%%                     filter_goods_by_color(D, MonType, Color, IsFilter, Ret)
%%             end;
%%   		true ->
%%             NewRet = [{GoodsTypeId, GoodsType, GoodsNum, GoodsColor, MonTeyp} | Ret],
%%             filter_goods_by_color(D, MonType, Color, IsFilter, NewRet)
%%     end.

mon_drop_analytics(Player, Mon, DropNum, RuleList, TotalRatio, PlayerList) ->
	MonId = Mon#ets_mon.mid,
    MonType = Mon#ets_mon.type,	
    case MonId =:= 40976 of%%小魔头
		false ->
	case MonType of
        %% 野外BOSS
        3 ->
            [Extra, OtherRuleList, OtherTotalRatio] = lib_goods_drop:extra_rule_list(RuleList, [], [], 0, 0),
            [_RuleList, _TotalRatio, _MonType, RetDropGoods, TaskResult] = 
                lists:foldl(fun mon_drop_loop/2, 
                    [OtherRuleList, OtherTotalRatio, MonType, [], []], lists:seq(1, DropNum - 1)), 
            DropGoods = lib_goods_drop:extra_mon_drop_goods(Extra, MonType, RetDropGoods),
            drop_goods(DropGoods, Player, Mon, MonId);
        %% 氏族BOSS
        8 ->
            [_RuleList, _TotalRatio, _MonType, RetDropGoods, TaskResult] = 
                lists:foldl(fun mon_drop_loop/2, 
                    [RuleList, TotalRatio, MonType, [], []], lists:seq(1, DropNum)),
            [GuildDropGoods, TokenNum] = filter_guild_drop_goods(RetDropGoods, 0, []),
            lib_guild_weal:mod_drop_add_reputation(Player#player.guild_name, Player#player.guild_id, Mon#ets_mon.name, TokenNum),
            allot_guild_boss_goods(Mon, GuildDropGoods);
        _ ->
            DropGoods =
                %% 25副本BOSS
                case lists:member(MonId, [41010, 41008, 41006]) 
                        andalso Player#player.other#player_other.pid_team == undefined of
                    true ->
                        TaskResult = [],
                        case data_25_boss_drop:get(MonId) of
                            [] ->
                                [];
                            DropGoodsList ->
                                case lists:keyfind(Player#player.career, 1, DropGoodsList) of
                                    false ->
                                        [];
                                    DropGoodsList25 ->
                                        {_Career, NewDropGoodsList25} = DropGoodsList25,
                                        TR = fb25_rate(NewDropGoodsList25, 0),
                                        fb25_rate_drop(DropNum, TR, MonType, NewDropGoodsList25, [])
                                end
                        end;
                    false ->
                        [_RuleList, _TotalRatio, _MonType, RetDropGoods, TaskResult] = 
                        lists:foldl(fun mon_drop_loop/2, 
                            [RuleList, TotalRatio, MonType, [], []], lists:seq(1, DropNum)), 
						RetDropGoods
%%                         filter_goods_by_color(RetDropGoods, MonType, 3, 0, [])
                end,
            drop_goods(DropGoods, Player, Mon, MonId)
    end,
    lib_task:share_mon_drop(Player, MonId, MonType, Mon#ets_mon.lv, PlayerList, Mon#ets_mon.scene, TaskResult);
		true ->
			%% 小魔头掉落
			[_RuleList, _TotalRatio, _MonType, RetDropGoods, _TaskResult] = 
        		lists:foldl(fun mon_drop_loop/2, [RuleList, TotalRatio, MonType, [], []], lists:seq(1, DropNum)),
			OneYearDropGoodsFun = fun(PlayerId)->
				case lib_player:get_player_pid(PlayerId) of
					[] ->
						skip;
					Pid ->
						gen_server:cast(Pid, {'ONE_YEAR_DROP_GOODS', Mon#ets_mon.scene, Mon#ets_mon.mid, RetDropGoods})
				end					  
			end,
			[OneYearDropGoodsFun(P) || P <- PlayerList]
	end.

%% 捡取物品
drop_goods(DropGoods0, Player, Mon, MonId) ->
	Now = util:unixtime(),
	DropGoods = lib_goods_drop:time_filter(DropGoods0, Now, []),
	if
		DropGoods =/= [] ->
			PidTeam = Player#player.other#player_other.pid_team,
            case is_pid(PidTeam) of
                true ->
					lib_goods_drop:team_drop(DropGoods, Player#player.scene, Player#player.x, Player#player.y, PidTeam, MonId);
                false ->
					lib_goods_drop:give_goods(Player, Mon, DropGoods, MonId, 0)
			end;
		true ->
			skip
	end.


%% 循环掉落物品
mon_drop_loop(_Num, [RuleList, TotalRatio, MonType, RuleResult, TaskResult]) ->
	RandRatio = util:rand(1, TotalRatio),    
    RandRatioFun = fun(Rule, [Ratio, First, Result]) ->	
     	End = First + Rule#ets_base_goods_drop_rule.ratio,
		if
       		Ratio > First andalso Ratio =< End ->
				[Ratio, End, Rule];
      		true ->				
				[Ratio, End, Result]
     	end
   	end,
  	[_RandRatio, _First, NewRule] = lists:foldl(RandRatioFun, [RandRatio, 0, {}], RuleList),
	if
   		NewRule /= {} andalso NewRule#ets_base_goods_drop_rule.goods_id > 0 ->
            NewRuleList = lists:delete(NewRule, RuleList),
            NewTotalRatio = TotalRatio - NewRule#ets_base_goods_drop_rule.ratio,
            %% 掉落物品分析
            [NewRuleResult, NewTaskResult] = lib_goods_drop:handle_drop_rule(NewRule, RuleResult, TaskResult, MonType),
			[NewRuleList, NewTotalRatio, MonType, NewRuleResult, NewTaskResult];
      	true ->
            [RuleList, TotalRatio, MonType, RuleResult, TaskResult]
    end.

fb25_rate([], Ret) ->
	trunc(Ret);
fb25_rate([{_GoodsId, _Type, _Num, Rate} | G], Ret) ->
	fb25_rate(G, Ret + Rate * 100000).

fb25_rate_drop(0, _TotalRatio, _MonType, _FB25Drop, Ret) ->
	Ret;
fb25_rate_drop(DropNum, TotalRatio, MonType, FB25Drop, Ret) ->
	RandRatio = util:rand(1, TotalRatio),    
    F = fun({GoodsTypeId, GoodsType, GoodsNum, R}, [Ra, First, GI, Reture]) ->	
     	End = First + R * 100000,		
       	case Ra > First andalso Ra =< End of
          	true ->
				GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, GoodsTypeId),
				GoodsColor = GoodsTypeInfo#ets_base_goods.color,
				[Ra, End, GoodsTypeId, {GoodsTypeId, GoodsType, GoodsNum, GoodsColor, MonType}];
          	false ->				
				[Ra, End, GI, Reture]
     	end
   	end,
  	[_RandRatio, _First, GI, DropList] = lists:foldl(F, [RandRatio, 0, 0, {}], FB25Drop),
	NewFB25Drop = lists:keydelete(GI, 1, FB25Drop),
	NewRet = 
		case DropList /= {} of
			true ->
				[DropList | Ret];
			false ->
				Ret
		end,
	fb25_rate_drop(DropNum - 1, TotalRatio, MonType, NewFB25Drop, NewRet).

%% 过滤氏族BOSS掉落品（氏族令）
filter_guild_drop_goods([], TokenNum, DropGoods) ->
	[DropGoods, TokenNum];
filter_guild_drop_goods([{GoodsTypeId, GoodsType, GoodsNum, GoodsColor, MonType} | D], TokenNum, DropGoods) ->
	if
		GoodsTypeId =/= 28303 ->
			filter_guild_drop_goods(D, TokenNum, [{GoodsTypeId, GoodsType, GoodsNum, GoodsColor, MonType} | DropGoods]);
		true ->
			filter_guild_drop_goods(D, TokenNum + GoodsNum, DropGoods)
	end.

%% 氏族BOSS分配
allot_guild_boss_goods(Minfo, DropGoods) ->
	Pattern = ets:fun2ms(fun(P) when P#player.scene == Minfo#ets_mon.scene -> P end),
   	case ets:select(?ETS_ONLINE_SCENE, Pattern) of
   		[] -> 
			[];
  		AllUser ->
			allot_guild_boss_goods_loop(DropGoods, Minfo, AllUser, AllUser, 1)
    end.
allot_guild_boss_goods_loop([], _Minfo, _DropUser, _AllUser, _Num) ->
	ok;
allot_guild_boss_goods_loop([G | D], Minfo, DropUser, AllUser, Num) ->
	case Num > 6 of
		false ->
			Len = length(DropUser),
			Rand = random:uniform(Len),
			RandPlayer = lists:nth(Rand, DropUser),
			DropId = Num * ?MON_LIMIT_NUM,
			
			PlayerData = [
				RandPlayer#player.id,
				RandPlayer#player.nickname,
				RandPlayer#player.career,
				RandPlayer#player.sex,
				RandPlayer#player.realm,
				RandPlayer#player.scene,
				RandPlayer#player.other#player_other.pid_team,
				RandPlayer#player.other#player_other.pid_scene,
				RandPlayer#player.other#player_other.pid_send,
				RandPlayer#player.other#player_other.socket
			],
			gen_server:cast(RandPlayer#player.other#player_other.pid_goods, 
					{'HOOK_GIVE_GOODS', [G], PlayerData, DropId, Minfo#ets_mon.mid, Minfo#ets_mon.x, Minfo#ets_mon.y, 0}),

%% 			PlayerData = [
%%                 RandPlayer#player.id,
%%                 RandPlayer#player.scene,
%%                 RandPlayer#player.other#player_other.pid_team,
%%                 RandPlayer#player.other#player_other.pid_scene,
%%                 RandPlayer#player.other#player_other.pid_send
%%             ],
%%             lib_goods_drop:put_mon_drop_in_scene([G], PlayerData, Minfo#ets_mon.mid, RandPlayer#player.x, RandPlayer#player.y, 0),
			
			LeftUser = lists:keydelete(RandPlayer#player.id, 2, DropUser),
			NewLeftUser = 
				case length(LeftUser) > 0 of
					true ->
						LeftUser;
					false ->
						AllUser
				end,
			allot_guild_boss_goods_loop(D, Minfo, NewLeftUser, AllUser, Num + 1);
		true ->
			skip
	end.
