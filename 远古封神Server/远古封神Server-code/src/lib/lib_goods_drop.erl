%%%--------------------------------------
%%% @Module  : lib_goods_drop
%%% @Author  : ygfs
%%% @Created : 2010.12.15
%%% @Description : 物品掉落信息
%%%--------------------------------------
-module(lib_goods_drop).
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-export(
	[	
		mon_drop/3,
		check_drop_list/4,
		check_drop_choose/6,		
		drop_choose/7,
		extra_mon_drop/2,
		mon_drop_analytics/6,
		drop_choose_broadcast/10,
		is_weapon/2,
		hook_give_goods/9,
		put_mon_drop_in_scene/7,
		put_mon_drop_in_scene/6,
		check_drop_num/1,
		get_drop_rule_list/1,
		extra_rule_list/5,
		extra_mon_drop_goods/3,
		train_mon_drop/3,
		hook_select_goods/5,
		team_drop/6,
		hook_drop/4,
		get_drop_list/6,
		time_filter/3,
		handle_drop_rule/4,
		wild_boss_dps_drop/2,
		give_goods/5
	]
).

%% 怪物掉落
mon_drop(Player, Mon, PlayerList) ->
	case lib_mon:is_boss_mon(Mon#ets_mon.type) of
   		false ->
			case check_drop_num(Mon) of
				false ->
					lib_task:share_mon_kill(Player, PlayerList, Mon#ets_mon.mid, Mon#ets_mon.lv, Mon#ets_mon.scene);
				{true, DropNum, RuleList, TotalRatio} ->
					mon_drop_analytics(Player, Mon, DropNum, RuleList, TotalRatio, PlayerList)
			end;
        true ->
			mod_dungeon_analytics:mon_drop_extra(Player, Mon, PlayerList)
    end.

mon_drop_analytics(Player, Mon, DropNum, RuleList, TotalRatio,PlayerList) ->
	MonType = Mon#ets_mon.type,
    MonId = Mon#ets_mon.mid,
    [_RuleList, _TotalRatio, _MonType, DropGoods0, TaskResult] = 
        lists:foldl(fun mon_drop_loop/2, 
                    [RuleList, TotalRatio, MonType, [], []], lists:seq(1, DropNum)),
    lib_task:share_mon_drop(Player, MonId, MonType, Mon#ets_mon.lv, PlayerList,Mon#ets_mon.scene, TaskResult),
	Now = util:unixtime(),
	DropGoods = time_filter(DropGoods0, Now, []),
	if
  		DropGoods =/= [] ->
			give_goods(Player, Mon, DropGoods, MonId, 0);
     	true ->
            skip
    end.

%% 循环掉落物品
mon_drop_loop(_Num, [RuleList, TotalRatio, MonType, RuleResult, TaskResult]) ->
	RandRatio = util:rand(1, TotalRatio),    
    F = fun(Rule, [Ra, First, Result1]) ->		
     	End1 = First + Rule#ets_base_goods_drop_rule.ratio,		
       	case Ra > First andalso Ra =< End1 of
          	true ->				
				[Ra, End1, Rule];
          	false ->				
				[Ra, End1, Result1]
     	end
   	end,
  	[_RandRatio, _First, NewRule] = lists:foldl(F, [RandRatio, 0, {}], RuleList),
    case NewRule#ets_base_goods_drop_rule.goods_id > 0 andalso NewRule#ets_base_goods_drop_rule.goods_id =/= 28704 andalso NewRule#ets_base_goods_drop_rule.goods_id =/= 31201 of
        %% 有掉落
        true ->
            NewRuleList = lists:delete(NewRule, RuleList),
            NewTotalRatio = TotalRatio - NewRule#ets_base_goods_drop_rule.ratio,
            %% 掉落物品分析
            [NewRuleResult, NewTaskResult] = handle_drop_rule(NewRule, RuleResult, TaskResult, MonType),
            [NewRuleList, NewTotalRatio, MonType, NewRuleResult, NewTaskResult];
        %% 无掉落
        false ->
            [RuleList, TotalRatio, MonType, RuleResult, TaskResult]
    end.

%% 掉落物品分析处理
handle_drop_rule(Rule, RuleResult, TaskResult, MonType) ->
	GoodsTypeId = Rule#ets_base_goods_drop_rule.goods_id,
    GoodsType = Rule#ets_base_goods_drop_rule.type,
    GoodsNum = Rule#ets_base_goods_drop_rule.goods_num,
    case GoodsType of
        %% 任务物品
		35 ->
            NewTaskResult = [{GoodsTypeId, GoodsNum} | TaskResult],
            [RuleResult, NewTaskResult];
        _ ->
			case ets:lookup(?ETS_BASE_GOODS, GoodsTypeId) of
				[] ->
					[RuleResult, TaskResult];
				[GoodsTypeInfo | _] ->
					NewRuleResult = [{GoodsTypeId, GoodsType, GoodsNum, GoodsTypeInfo#ets_base_goods.color, MonType} | RuleResult],           
            		[NewRuleResult, TaskResult]
			end
    end.

%% 掉落数随机
get_drop_num_rule(MonId) ->
    Pattern = #ets_base_goods_drop_num{ mon_id=MonId, _='_' },
    NumRuleList = goods_util:get_ets_list(?ETS_BASE_GOODS_DROP_NUM, Pattern),
    case length(NumRuleList) > 0 of
        true ->
            TotalRatio = lists:foldl(fun(R, Sum) -> R#ets_base_goods_drop_num.ratio + Sum end, 0, NumRuleList),
            Ratio = util:rand(1, TotalRatio),
			get_drop_num_rule_loop(NumRuleList, Ratio, 0);
       	false ->
			[]
	end.    
get_drop_num_rule_loop([], _Ratio, _N) ->
	[];
get_drop_num_rule_loop([Rule | R], Ratio, N) ->
	NN = N + Rule#ets_base_goods_drop_num.ratio,
	case Ratio > N andalso Ratio =< NN of
  		true ->
			Rule;
     	false ->
			get_drop_num_rule_loop(R, Ratio, NN)
   	end.

%% 掉落物品规则列表
get_drop_rule_list(MonId) ->
    Pattern = #ets_base_goods_drop_rule{ mon_id = MonId, _ = '_' },
    RuleList = goods_util:get_ets_list(?ETS_BASE_GOODS_DROP_RULE, Pattern),
    Fun = fun(Rule, [TotalRatio, RetRuleList]) ->
		[TotalRatio + Rule#ets_base_goods_drop_rule.ratio, [Rule | RetRuleList]]
   	end,
	lists:foldl(Fun, [0, []], RuleList).

get_drop_rule_list(MonId, Extra) ->
    Pattern = #ets_base_goods_drop_rule{ mon_id = MonId, extra = Extra, _ = '_' },
  	goods_util:get_ets_list(?ETS_BASE_GOODS_DROP_RULE, Pattern).

%% 额外掉落物品规则列表
get_extra_drop_rule_list(MonId, Extra) ->
    Pattern = #ets_base_goods_drop_rule{ mon_id = MonId, extra = Extra, _ = '_' },
    RuleList = goods_util:get_ets_list(?ETS_BASE_GOODS_DROP_RULE, Pattern),
    Fun = fun(Rule, [TotalRatio, RetRuleList]) ->
		[TotalRatio + Rule#ets_base_goods_drop_rule.ratio, [Rule | RetRuleList]]
   	end,
	lists:foldl(Fun, [0, []], RuleList).

%% 检查掉落物品是否合法
check_drop_list(PlayerId, _TeamPid, SceneId, DropId) ->
	DropInfo = mod_scene:get_mon_drop_in_scene(SceneId, DropId),	
    %NowTime = util:unixtime(),
    if
        %% 掉落包已经消失
        %is_record(DropInfo, ets_goods_drop) =:= false ->
		DropInfo =:= {} ->
            {fail, 2};
%%         %% 掉落包已经消失
%%         DropInfo#ets_goods_drop.expire_time =< NowTime ->
%%             {fail, 2};
        %% 无权拣取
    	DropInfo#ets_goods_drop.player_id /= PlayerId ->
			{fail, 3};
%%         %% 无权拣取
%%         DropInfo#ets_goods_drop.team_pid /= undefined andalso DropInfo#ets_goods_drop.team_pid /= TeamPid ->
%% io:format("d13~n"),
%% 			{fail, 3};
        true ->
            {ok, DropInfo}
    end.

%% 拾取掉落包
get_drop_list(PlayerId, DropId, TeamPid, PidSend, X, Y) ->
	DropInfo = goods_util:get_ets_info(?ETS_GOODS_DROP, DropId),
	[DropGoods, MonId] = 
		if
        	%% 掉落包已经消失
			DropInfo =:= {} ->
            	[[], 0];
        	%% 无权拣取
        	DropInfo#ets_goods_drop.team_pid == undefined andalso DropInfo#ets_goods_drop.player_id /= PlayerId ->
				[[], 0];
        	%% 无权拣取
        	DropInfo#ets_goods_drop.team_pid /= undefined andalso DropInfo#ets_goods_drop.team_pid /= TeamPid ->
				[[], 3];
        	true ->
				[DropInfo#ets_goods_drop.drop_goods, DropInfo#ets_goods_drop.mon_id]
    	end,
	%% 判断是否组队	
    case DropId < ?MON_LIMIT_NUM andalso DropGoods /= [] andalso is_pid(TeamPid) of
        true ->
			ets:delete(?ETS_GOODS_DROP, DropId),
			{ok, BinData} = pt_12:write(12019, DropId),
			gen_server:cast(TeamPid, {'TEAM_CHAT', BinData}),
			team_drop(DropGoods, DropInfo#ets_goods_drop.scene, X, Y, TeamPid, MonId);
        _ ->
            {ok, BinData} = pt_15:write(15002, [1, DropId, DropGoods]),
            lib_send:send_to_sid(PidSend, BinData)			
    end.

%% 拣取地上掉落包的物品
check_drop_choose(PlayerId, TeamPid, SceneId, GoodsStatus, DropId, GoodsTypeId) ->
    case check_drop_list(PlayerId, TeamPid, SceneId, DropId) of
        {fail, Res} ->
            {fail, Res};
        {ok, DropInfo} ->
            case lists:keyfind(GoodsTypeId, 1, DropInfo#ets_goods_drop.drop_goods) of
                %% 物品已经不存在
                false ->
                    {fail, 4};
                GoodsInfo ->
                    {GoodsTypeId, _GoodsType, GoodsNum, _GoodsColor, _MonType} = GoodsInfo,
                    GoodsTypeInfo = goods_util:get_goods_type(GoodsTypeId),
                    case is_record(GoodsTypeInfo, ets_base_goods) of
						true ->
							case lib_goods:is_enough_backpack_cell(GoodsStatus, GoodsTypeInfo, GoodsNum) of
								{enough, _GoodsList, _CellNum} ->
									{ok, DropInfo, GoodsInfo};
								%% 背包格子不足
								no_enough ->
									{fail, 5}	
							end;
						false ->
                       		{fail, 4}                        
                    end
            end
    end.

%% 拣取地上掉落包的物品
drop_choose(PlayerId, TeamPid, SceneId, GoodsStatus, DropInfo, GoodsInfo, [NickName, Realm, Career, Sex]) ->
    {GoodsTypeId, _GoodsType, GoodsNum, GoodsColor, MonType} = GoodsInfo,
    %% 添加物品
    case catch lib_goods:give_goods({GoodsTypeId, GoodsNum}, GoodsStatus) of
        {ok, NewGoodsStatus} ->
            MonId = DropInfo#ets_goods_drop.mon_id,
            spawn(fun()-> drop_choose_broadcast(PlayerId, NickName, Career, Sex, Realm, GoodsTypeId, GoodsColor, MonId, MonType, GoodsNum) end),
            %% 通知前端获取物品
%% 			{ok, GoodsBinData} = pt_15:write(15110, GoodsTypeId),
%% 			lib_send:send_to_sid(NewGoodsStatus#goods_status.pid_send, GoodsBinData),
			notice_give_goods(NickName, GoodsTypeId, TeamPid, NewGoodsStatus#goods_status.pid_send),
			
			%% 更新掉落包
            mod_scene:del_mon_drop_in_scene(SceneId, DropInfo#ets_goods_drop.id),
            {ok, BinData} = pt_12:write(12019, DropInfo#ets_goods_drop.id),
            lib_send:send_to_team(NewGoodsStatus#goods_status.pid_send, TeamPid, BinData),
			%%刷新掉落物
			lib_goods:refresh_new_goods(NewGoodsStatus#goods_status.pid_send,PlayerId,GoodsTypeId),
            {ok, NewGoodsStatus};
        {fail, _Error, GoodsStatus} ->
            GoodsStatus
    end.

%% 掉落播报
drop_choose_broadcast(PlayerId, PlayerName, Career, Sex, PlayerRealm, GoodsTypeId, GoodsColor, MonId, MonType, GoodsNum) ->
	%% 金色、紫色物品广播
    case MonType > 0 andalso (GoodsColor > 2 orelse lists:member(MonType, [3, 8, 31])) of
        true ->
            Minfo = data_agent:mon_get(MonId),
            GoodsTypeInfo = goods_util:get_goods_type(GoodsTypeId),
            GoodsName = GoodsTypeInfo#ets_base_goods.goods_name,
            if
				GoodsColor > 2 ->
                    GoodsType = GoodsTypeInfo#ets_base_goods.type,
                    GoodsSubType = GoodsTypeInfo#ets_base_goods.subtype,
                    IsWeapon = 
                        case is_weapon(GoodsType, GoodsSubType) of
                            true ->
                                1;
                            false ->
                                0
                        end,
                    Data = [
                        MonId, 
                        Minfo#ets_mon.name, 
                        PlayerId,
                        PlayerName,
                        GoodsTypeId,			
                        GoodsName,					 
                        GoodsColor,
                        IsWeapon, 
                        util:unixtime()		
                    ],
                    spawn(fun()-> db_agent:insert_mon_drop_analytics(Data) end);
          		true ->
                    skip
            end,
            GoodsList = goods_util:get_goods(GoodsTypeId, PlayerId),
			GoodsListLen = length(GoodsList),
            GoodsId =
                if							
              		GoodsListLen > 1 ->
                        Gs = lists:max(GoodsList),
                        Gs#goods.id;
                  	GoodsListLen == 1 ->
                        Gs = lists:nth(1, GoodsList),
                        Gs#goods.id;
                    true ->
                        0
                end,
            Realm = lib_player:get_country(PlayerRealm),
			NameColor = data_agent:get_realm_color(PlayerRealm),
            ColorVal = goods_util:get_color_hex_value(GoodsColor), 
            MsgData = [
			    "#FF0000",
                Realm, 
                PlayerId, 
                PlayerName, 
                Career,
                Sex, 
				NameColor,
                PlayerName,
				"#FFCF00",
				Minfo#ets_mon.name, 
                GoodsId,
                PlayerId, 
                ColorVal, 
                GoodsName,
				GoodsNum
            ],
			Msg = io_lib:format("<font color='~s'>[~s]</font>玩家 [<a href='event:1, ~p, ~s, ~p, ~p'><font color='~s'><u>~s</u></font></a>] 与 <font color='~s'>[~s]</font> 经过一番天昏地暗的战斗后，获得 <a href='event:2, ~p, ~p, 1'><font color='~s'>~sx~p</font></a>。", MsgData),
            lib_chat:broadcast_sys_msg(1, Msg);
        false ->
            skip
    end.

%% 额外奖励掉落
extra_mon_drop(Mon, PlayerId) ->
	case lib_mon:get_player(PlayerId, Mon#ets_mon.scene) of 
   		[] ->
      		skip;
		Player ->
			MonId = Mon#ets_mon.mid,
			[TotalRatio, RuleList] = get_extra_drop_rule_list(MonId + 1, 0),
			[_RuleList, _TotalRatio, _MonType, DropGoods, _TaskResult] = 
                        mon_drop_loop(1, [RuleList, TotalRatio, Mon#ets_mon.type, [], []]),
			if
				DropGoods =/= [] ->
					ExtraDropGoods = get_drop_rule_list(MonId + 1, 2),
					LenExtraDropGoods = length(ExtraDropGoods),
					NewDropGoods = 
						if
							LenExtraDropGoods > 0 ->
								get_extra_drop_goods(1, ExtraDropGoods, LenExtraDropGoods, DropGoods);
							true ->
								DropGoods
						end,
					give_goods(Player, Mon, NewDropGoods, MonId, 0);
				true ->
					skip
			end
	end.


%% 野外BOSS额外DPS掉落
wild_boss_dps_drop(Player, Mon) ->
	MonId = Mon#ets_mon.mid,
	%% 额外BOSS掉落
	ExtraDropGoods = get_drop_rule_list(MonId + 1, 2),
	LenExtraDropGoods = length(ExtraDropGoods),
	if
		LenExtraDropGoods > 0 ->
			DropGoods = get_extra_drop_goods(5, ExtraDropGoods, LenExtraDropGoods, []),
			mod_dungeon_analytics:drop_goods(DropGoods, Player, Mon, MonId);
		true ->
			skip
	end.

%% 额外掉落（物品获得不广播）
get_extra_drop_goods(0, _ExtraDropGoods, _LenExtraDropGoods, DropGoods) ->
	DropGoods;
get_extra_drop_goods(Num, ExtraDropGoods, LenExtraDropGoods, DropGoods) ->
	Rand = random:uniform(LenExtraDropGoods),
	ExtraDropInfo = lists:nth(Rand, ExtraDropGoods),
	GoodsTypeId = ExtraDropInfo#ets_base_goods_drop_rule.goods_id,
	case ets:lookup(?ETS_BASE_GOODS, GoodsTypeId) of
		[] ->
			get_extra_drop_goods(Num - 1, ExtraDropGoods, LenExtraDropGoods, DropGoods);
		[GoodsTypeInfo | _] ->
			GoodsType = ExtraDropInfo#ets_base_goods_drop_rule.type,
			GoodsNum = ExtraDropInfo#ets_base_goods_drop_rule.goods_num,
			get_extra_drop_goods(Num - 1, ExtraDropGoods, LenExtraDropGoods, [{GoodsTypeId, GoodsType, GoodsNum, GoodsTypeInfo#ets_base_goods.color, 0} | DropGoods])
	end.
	

%% 是否是武器
is_weapon(GoodsType, GoodsSubType) ->
	GoodsType == 10 andalso GoodsSubType < 14.

%% 挂机拾取物品
hook_give_goods([], _DropId, MonId, MonX, MonY, GoodsStatus, LeftDropGoods, [PlayerId, _NickName, _Career, _Sex, _Realm, SceneId, PidTeam, PidScene, PidSend, _Socket], SceneType) ->
	put_mon_drop_in_scene(LeftDropGoods, [PlayerId, SceneId, PidTeam, PidScene, PidSend], MonId, MonX, MonY, SceneType),
	GoodsStatus;
hook_give_goods([{GoodsTypeId, GoodsType, GoodsNum, GoodsColor, MonType} | D], DropId, MonId, MonX, MonY, GoodsStatus, LeftDropGoods,
			   [PlayerId, NickName, Career, Sex, Realm, SceneId, PidTeam, PidScene, PidSend, Socket], SceneType) ->
	GiveGoodsParam = 
		if
			MonType =/= 42 ->
				{GoodsTypeId, GoodsNum};
			%% 绑定怪掉落
			true ->
				{GoodsTypeId, GoodsNum, 2}
		end,
	[RetGoodsStatus, RetLeftDropGoods] = 
		case catch lib_goods:give_goods(GiveGoodsParam, GoodsStatus) of
        	{ok, NewGoodsStatus} ->
				drop_choose_broadcast(PlayerId, NickName, Career, Sex, Realm, GoodsTypeId, GoodsColor, MonId, MonType, GoodsNum),
				%% 通知前端获取物品
%% 				{ok, GoodsBinData} = pt_15:write(15110, GoodsTypeId),
%% 				lib_send:send_to_sid(PidSend, GoodsBinData),
				notice_give_goods(NickName, GoodsTypeId, PidTeam, PidSend),
				%%刷新掉落物
				lib_goods:refresh_new_goods(PidSend, PlayerId, GoodsTypeId),
				[NewGoodsStatus, LeftDropGoods];            	
        	{fail, _Error, NewGoodsStatus} ->
				[NewGoodsStatus, [{GoodsTypeId, GoodsType, GoodsNum, GoodsColor, MonType} | LeftDropGoods]]
    	end,
	hook_give_goods(D, DropId, MonId, MonX, MonY, RetGoodsStatus, RetLeftDropGoods, [PlayerId, NickName, Career, Sex, Realm, SceneId, PidTeam, PidScene, PidSend, Socket], SceneType).

%% 物品放入场景
put_mon_drop_in_scene(DropGoods, [PlayerId, SceneId, TeamPid, ScenePid, SendPid], DropId, MonId, DropX, DropY, SceneType) ->
	DropNum = length(DropGoods),
	if
		DropNum > 0 ->
            %% 需要放入场景            							
            DropInfo = #ets_goods_drop{
                id = DropId,
                mon_id = MonId, 						
                player_id = PlayerId, 
                team_pid = TeamPid, 
                drop_goods = DropGoods, 
				scene = SceneId
            },
            mod_scene:put_mon_drop_in_scene(ScenePid, DropInfo),
            %% 广播
            {ok, BinData} = pt_12:write(12017, [DropId, ?Goods_Expire_Time, DropX, DropY]),
			%% 是否在试炼副本
			if
				SceneType =/= 4 ->
					case is_pid(TeamPid) of 
						true ->
							gen_server:cast(TeamPid, {'SEND_TO_MEMBER', BinData});
   						false ->
       						lib_send:send_to_sid(SendPid, BinData)
    				end;
				true ->
					lib_send:send_to_sid(SendPid, BinData)
			end;
        true ->
            skip
    end.

%% 物品放入场景
put_mon_drop_in_scene(DropGoods, [PlayerId, SceneId, TeamPid, ScenePid, SendPid], MonId, DropX, DropY, SceneType) ->
	DropNum = length(DropGoods),
	if
		DropNum > 0 ->
			DropId = mod_scene:get_drop_id(SceneId, DropNum),
			DropFun = fun({GoodsTypeId, GoodsType, GoodsNum, GoodsColor, MonType}, [DId, DG])->
				NewDropX = DropX + random_position(),
				NewDropY = DropY + random_position(),
				DropInfo = #ets_goods_drop{
	                unique_key = {SceneId, DId},
					id = DId,
	                mon_id = MonId, 						
	                player_id = PlayerId, 
	                team_pid = TeamPid, 
	                drop_goods = [{GoodsTypeId, GoodsType, GoodsNum, GoodsColor, MonType}], 
					scene = SceneId
	            },
				mod_scene:put_mon_drop_in_scene(ScenePid, DropInfo),
				[DId + 1, [{DId, GoodsTypeId, NewDropX, NewDropY} | DG]]
			end,
			[_RetDropId, NewDropGoods] = lists:foldl(DropFun, [DropId, []], DropGoods),
			{ok, BinData} = pt_12:write(12117, [1, NewDropGoods]),
			%% 是否在试炼副本
			if
				SceneType =/= 4 ->
					case is_pid(TeamPid) of 
						true ->
							gen_server:cast(TeamPid, {'SEND_TO_MEMBER', BinData});
   						false ->
       						lib_send:send_to_sid(SendPid, BinData)
    				end;
				true ->
					lib_send:send_to_sid(SendPid, BinData)
			end;
        true ->
            skip
    end.

%% 特殊掉落
extra_rule_list([], ExtraDrop, Drop, ExtraTotal, OtherTotal) ->
	[[ExtraTotal, ExtraDrop], Drop, OtherTotal];
extra_rule_list([E | R], ExtraDrop, Drop, ExtraTotal, OtherTotal) ->
	case E#ets_base_goods_drop_rule.extra == 1 of
		true ->
			extra_rule_list(R, [E | ExtraDrop], Drop, ExtraTotal + E#ets_base_goods_drop_rule.ratio, OtherTotal);
		false ->
			extra_rule_list(R, ExtraDrop, [E | Drop], ExtraTotal, OtherTotal + E#ets_base_goods_drop_rule.ratio)
	end.

extra_mon_drop_goods([Total, RuleList], MonType, RuleResult) ->
	case RuleList /= [] andalso Total /= 0 of
		true ->
			RandRatio = util:rand(1, Total),
			F = fun(Rule, [Ra, First, Result1]) ->		
     			End1 = First + Rule#ets_base_goods_drop_rule.ratio,		
       			case Ra > First andalso Ra =< End1 of
          			true ->				
						[Ra, End1, Rule];
          			false ->				
						[Ra, End1, Result1]
     			end
   			end,	
  			[_RandRatio, _First, NewRule] = lists:foldl(F, [RandRatio, 0, {}], RuleList),
        	case NewRule#ets_base_goods_drop_rule.goods_id > 0 of
            	%% 有掉落
            	true ->
					GoodsTypeId = NewRule#ets_base_goods_drop_rule.goods_id,
					case ets:lookup(?ETS_BASE_GOODS, GoodsTypeId) of
						[] ->
							RuleResult;
						[GoodsTypeInfo | _] ->
							GoodsType = NewRule#ets_base_goods_drop_rule.type,
    						GoodsNum = NewRule#ets_base_goods_drop_rule.goods_num,
							GoodsColor = GoodsTypeInfo#ets_base_goods.color,
							[{GoodsTypeId, GoodsType, GoodsNum, GoodsColor, MonType} | RuleResult]	
					end;
            	%% 无掉落
            	false ->
					RuleResult
        	end;
		false ->
			RuleResult
	end.
	
%% 检查掉落数量
check_drop_num(Mon) ->
	case get_drop_num_rule(Mon#ets_mon.mid) of
		[] ->
			false;
      	NumRule ->
			case NumRule#ets_base_goods_drop_num.drop_num > 0 of
				true ->
					[TotalRatio, RuleList] = get_drop_rule_list(Mon#ets_mon.mid),
					case length(RuleList) > 0 of
						true ->
							{true, NumRule#ets_base_goods_drop_num.drop_num, RuleList, TotalRatio};
						false ->
							false
					end;
				false ->
					false
			end
    end.

%% 试炼掉落
train_mon_drop(Player, Mon, PlayerList) ->
	case check_drop_num(Mon) of
		false ->
			lib_task:share_mon_kill(Player, PlayerList, Mon#ets_mon.mid, Mon#ets_mon.lv, Mon#ets_mon.scene);
		{true, DropNum, RuleList, TotalRatio} ->
            MonId = Mon#ets_mon.mid,
            MonType = Mon#ets_mon.type,
            [_RuleList, _TotalRatio, _MonType, DropGoods, TaskResult] = 
                	lists:foldl(fun mon_drop_loop/2, [RuleList, TotalRatio, MonType, [], []], lists:seq(1, DropNum)),
            lib_task:share_mon_drop(Player, MonId, MonType, Mon#ets_mon.lv, PlayerList, Mon#ets_mon.scene, TaskResult),
			case DropGoods =/= [] of
                true ->
					give_goods(Player, Mon, DropGoods, MonId, 4);
                false ->
                    skip
            end
	end.


%% 捡取物品
give_goods(Player, Mon, DropGoods, MonId, SceneType) ->
	%% 判断是否开启挂机自动拾取物品
	if
  		Player#player.status =:= 5 andalso Player#player.other#player_other.hook_pick =:= 1 ->
			hook_drop(Player, DropGoods, Mon, MonId);
		true ->
			PlayerData = [
                Player#player.id,
                Player#player.scene,
                Player#player.other#player_other.pid_team,
                Player#player.other#player_other.pid_scene,
                Player#player.other#player_other.pid_send
            ],
          	put_mon_drop_in_scene(DropGoods, PlayerData, MonId, Mon#ets_mon.x, Mon#ets_mon.y, SceneType)
    end.


%% 挂机掉落过滤
hook_select_goods([], _HookEquipList, _HookQualityList, GiveGoods, DropGoods) ->
	[GiveGoods, DropGoods];
hook_select_goods([{GoodsTypeId, GoodsType, GoodsNum, GoodsColor, MonType} | G], HookEquipList, HookQualityList, GiveGoods, DropGoods) ->
	Color = GoodsColor + 1,
	IsGive =
		if
			Color > 4 ->
				1;
			true ->
				%% 是否装备
				case GoodsType =/= 10 of
					true ->
						lists:nth(Color, HookQualityList);
					false ->
						lists:nth(Color, HookEquipList)
				end
		end,
	if
		IsGive =:= 0 ->
			hook_select_goods(G, HookEquipList, HookQualityList, GiveGoods, [{GoodsTypeId, GoodsType, GoodsNum, GoodsColor, MonType} | DropGoods]);
		true ->
			hook_select_goods(G, HookEquipList, HookQualityList, [{GoodsTypeId, GoodsType, GoodsNum, GoodsColor, MonType} | GiveGoods], DropGoods)
	end.


%% 挂机掉落拾取
hook_drop(Player, DropGoods, Mon, MonId) ->
	DropFun = fun({GoodsTypeId, _GoodsType, _GoodsNum, _GoodsColor, _MonType}, RetDropGoods) ->
		X = Player#player.x + random_position(),
		Y = Player#player.y + random_position(),
		[{1, GoodsTypeId, X, Y} | RetDropGoods]
	end,
	NewDropGoods = lists:foldl(DropFun, [], DropGoods),
	{ok, BinData} = pt_12:write(12117, [2, NewDropGoods]),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),	
    PlayerData = [
        Player#player.id,
        Player#player.nickname,
        Player#player.career,
        Player#player.sex,
        Player#player.realm,
        Player#player.scene,
        Player#player.other#player_other.pid_team,
        Player#player.other#player_other.pid_scene,
        Player#player.other#player_other.pid_send,
        Player#player.other#player_other.socket
    ],
    Msg = {'HOOK_GIVE_GOODS', DropGoods, PlayerData, Mon#ets_mon.id, MonId, Mon#ets_mon.x, Mon#ets_mon.y, 0,
        	Player#player.other#player_other.hook_equip_list, Player#player.other#player_other.hook_quality_list},
    gen_server:cast(Player#player.other#player_other.pid_goods, Msg).


%% 组队掉落拾取
team_drop(DropGoods, SceneId, X, Y, PidTeam, MonId) ->
	X1 = X + ?TEAM_X_RANGE,
    X2 = X - ?TEAM_X_RANGE,
    Y1 = Y + ?TEAM_Y_RANGE,
    Y2 = Y - ?TEAM_Y_RANGE,
    MS = ets:fun2ms(fun(P) when P#player.other#player_other.pid_team == PidTeam, P#player.scene == SceneId,
                                P#player.x < X1, P#player.x > X2, 
                                P#player.y < Y1, P#player.y > Y2 ->
  		P
    end),
    PlayerList = ets:select(?ETS_ONLINE_SCENE, MS),
	LenPlayerList = length(PlayerList),
	if
		LenPlayerList == 1 ->
			[Player | _] = PlayerList,
			DropFun = fun({GoodsTypeId, _GoodsType, _GoodsNum, _GoodsColor, _MonType}, RetDropGoods) ->
				DX = Player#player.x + random_position(),
				DY = Player#player.y + random_position(),
				[{1, GoodsTypeId, DX, DY} | RetDropGoods]
			end,
			NewDropGoods = lists:foldl(DropFun, [], DropGoods),
			{ok, BinData} = pt_12:write(12117, [2, NewDropGoods]),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData),
			PlayerData = [
				Player#player.id,
				Player#player.nickname,
				Player#player.career,
				Player#player.sex,
				Player#player.realm,
				Player#player.scene,
				Player#player.other#player_other.pid_team,
				Player#player.other#player_other.pid_scene,
				Player#player.other#player_other.pid_send,
				Player#player.other#player_other.socket
			],
			gen_server:cast(Player#player.other#player_other.pid_goods, 
					{'HOOK_GIVE_GOODS', DropGoods, PlayerData, Player#player.id, MonId, Player#player.x, Player#player.y, 0});
		LenPlayerList > 1 ->
			team_drop_loop(DropGoods, PlayerList, PlayerList, MonId); 
		true ->
			skip
	end.
team_drop_loop([], _NewPlayerList, _PlayerList, _MonId) ->
	skip;
team_drop_loop([DropGoods | D], P, PlayerList, MonId) ->
	PL = length(P),
	Player = lists:nth(random:uniform(PL), P),
	NP = lists:keydelete(Player#player.id, 2, P),
	{GoodsTypeId, _GoodsType, _GoodsNum, _GoodsColor, _MonType} = DropGoods,
	PlayerData = [
		Player#player.id,
		Player#player.nickname,
		Player#player.career,
		Player#player.sex,
		Player#player.realm,
		Player#player.scene,
		Player#player.other#player_other.pid_team,
		Player#player.other#player_other.pid_scene,
		Player#player.other#player_other.pid_send,
		Player#player.other#player_other.socket
	],
	gen_server:cast(Player#player.other#player_other.pid_goods, 
			{'HOOK_GIVE_GOODS', [DropGoods], PlayerData, Player#player.id, MonId, Player#player.x + 1, Player#player.y + 1, 0}),
	
	X = Player#player.x + random_position(),
	Y = Player#player.y + random_position(),
	{ok, DropGoodsBinData} = pt_12:write(12117, [2, [{1, GoodsTypeId, X, Y}]]),
	lib_send:send_to_sid(Player#player.other#player_other.pid_send, DropGoodsBinData),
	
	NewPlayerList = 
		if
			NP =/= [] ->
				NP;
			true ->
				PlayerList
		end,
	team_drop_loop(D, NewPlayerList, PlayerList, MonId).


%% 时间限制
time_filter([], _Now, DropGoods) ->
	DropGoods;
time_filter([{GoodsTypeId, GoodsType, GoodsNum, GoodsColor, MonType} | G], Now, DropGoods) ->
	case lists:member(GoodsTypeId, [28017, 28016, 28015, 28014]) of
		false ->
			time_filter(G, Now, [{GoodsTypeId, GoodsType, GoodsNum, GoodsColor, MonType} | DropGoods]);
		true ->
			{ST, ET} = lib_activities:lantern_festival_time(),
			if
				Now > ST andalso Now < ET ->
					time_filter(G, Now, [{GoodsTypeId, GoodsType, GoodsNum, GoodsColor, MonType} | DropGoods]);
				true ->
					time_filter(G, Now, DropGoods)
			end
	end.


%% 通知前端获取物品
notice_give_goods(Nickname, GoodsTypeId, PidTeam, PidSend) ->
	case is_pid(PidTeam) of
		true ->
			{ok, BinData} = pt_15:write(15110, [GoodsTypeId, Nickname]),
			gen_server:cast(PidTeam, {'SEND_TO_MEMBER', BinData});
		false ->
			{ok, BinData} = pt_15:write(15110, [GoodsTypeId, []]),
			lib_send:send_to_sid(PidSend, BinData)
	end.
	

%% 随机位置
random_position() ->
	Rand = random:uniform(5),
	case Rand of
		1 ->
			0;
		2 ->
			1;
		3 ->
			-1;
		4 ->
			2;
		_ ->
			-2
	end.

