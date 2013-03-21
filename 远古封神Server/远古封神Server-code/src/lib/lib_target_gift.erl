%% Author: hxming
%% Created: 2010-12-28
%% Description: TODO: Add description to lib_target_gift
-module(lib_target_gift).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
%%
%% Exported Functions
%%
-compile(export_all).

%%
%% API Functions
%%

%%初始化目标奖励(20110531取消从数据库加载)
init_base_target_gift() ->
%%     F = fun(Target) ->
%% 			TargetGift = list_to_tuple([ets_base_target_gift] ++ Target),
%%             ets:insert(?ETS_BASE_TARGET_GIFT, TargetGift)
%%            end,
%% 	L = db_agent:get_base_target_gift(),
%% 	lists:foreach(F, L),
    ok.

%%玩家登陆，加载目标奖励数据
online(PlayerStatus)->
	case PlayerStatus#player.target_gift of
		0->
			PlayerId = PlayerStatus#player.id,
			case db_agent:select_target_gift_info(PlayerId) of 
				[]->
					%插入新玩家数据
					db_agent:create_target_gift_info(PlayerId),
					Data = [0,PlayerId,0,0,0,0,0,0,0,0,0,0
						   ,0,0,0,0,0,0,0,0,0,0
						   ,0,0,0,0,0,0,0,0,0,0
						   ,0,0,0],
 					EtsData = match_ets_playerinfo(Data),
 					ets:insert(?ETS_TARGET_GIFT,EtsData);
				Result ->	
%% 					io:format("Result~p~n",[Result]),
					Data = match_ets_playerinfo(Result),
					ets:insert(?ETS_TARGET_GIFT,Data)
			end;
		_->skip
	end.

%%玩家离线,释放ETS缓存
offline(PlayerId)->
	ets:match_delete(?ETS_TARGET_GIFT,#ets_target_gift{player_id=PlayerId,_='_'}).

%%获取玩家目标奖励信息
check_target_gift(PlayerStatus)->
	case PlayerStatus#player.target_gift of
		0->
			[TargetGift] = select_target_gift(PlayerStatus#player.id),
			Target = [[TargetGift#ets_target_gift.first,TargetGift#ets_target_gift.first_two,TargetGift#ets_target_gift.first_three,TargetGift#ets_target_gift.first_four,TargetGift#ets_target_gift.first_five],
					  [TargetGift#ets_target_gift.second,TargetGift#ets_target_gift.second_two,TargetGift#ets_target_gift.second_three,TargetGift#ets_target_gift.second_four,TargetGift#ets_target_gift.second_five],
					  [TargetGift#ets_target_gift.third,TargetGift#ets_target_gift.third_two,TargetGift#ets_target_gift.third_three,TargetGift#ets_target_gift.third_four,TargetGift#ets_target_gift.third_five],
					  [TargetGift#ets_target_gift.fourth,TargetGift#ets_target_gift.fourth_two,TargetGift#ets_target_gift.fourth_three,TargetGift#ets_target_gift.fourth_four],
					  [TargetGift#ets_target_gift.fifth,TargetGift#ets_target_gift.fifth_two,TargetGift#ets_target_gift.fifth_three],
					  [TargetGift#ets_target_gift.sixth,TargetGift#ets_target_gift.sixth_two,TargetGift#ets_target_gift.sixth_three],
					  [TargetGift#ets_target_gift.seventh,TargetGift#ets_target_gift.seventh_two,TargetGift#ets_target_gift.seventh_three],
					  [TargetGift#ets_target_gift.eighth,TargetGift#ets_target_gift.eighth_two],
					  [TargetGift#ets_target_gift.ninth,TargetGift#ets_target_gift.ninth_two],
					  [TargetGift#ets_target_gift.tenth]],
			NewPlayerStatus = check_target_finish(PlayerStatus,Target),
			{ok,NewPlayerStatus,count_game_day(PlayerStatus#player.reg_time),Target};
		_->
			{ok,PlayerStatus,count_game_day(PlayerStatus#player.reg_time),[[1,1,1,1,1],[1,1,1,1,1],[1,1,1,1,1],[1,1,1,1],[1,1,1],[1,1,1],[1,1,1],[1,1],[1,1],[1]]}
	end.

check_target_state(PlayerStatus)->
	Date =[[1,1],[1,2],[1,3],[1,4],[1,5],
		   [2,1],[2,2],[2,3],[2,4],[2,5],
		   [3,1],[3,2],[3,3],[3,3],[3,5],
		   [4,1],[4,2],[4,3],[4,4],
		   [5,1],[5,2],[5,3],
		   [6,1],[6,2],[6,3],
		   [7,1],[7,2],[7,3],
		   [8,1],[8,2],
		   [9,1],[9,2],
		   [10,1]],
	case lib_target_gift:check_target_state(PlayerStatus, Date,finish) of	
		{true,Day,Times} ->
			{ok,BinData} = pt_30:write(30074, [Day, Times]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
			ok;
		Other -> Other
	end.

%%检查目标是否可领取
check_target_state(_PlayerStatus,[],State)->
	State;
check_target_state(PlayerStatus,[[Day,Times]|Date],_State)->
	case PlayerStatus#player.target_gift of
		0-> 
			GameDay = count_game_day(PlayerStatus#player.reg_time),
			case Day =< GameDay of
				true->
					Type = id_to_type(Day,Times),
					%%检查是否已经领取
					case tatget_gift_had_get(PlayerStatus#player.id,Type) of
						true ->
							%%检查目标是否达到
							case check_target(Type,PlayerStatus) of
								{ok,_Result} ->
									{true,Day,Times};
								{error,_Result}->
									check_target_state(PlayerStatus,Date,ok)
							end;
						false->
							check_target_state(PlayerStatus,Date,ok)
					end;
				false->
					%%4目标日期未开启
					check_target_state(PlayerStatus,[],ok)
			end;
		_->
			check_target_state(PlayerStatus,[],finish)
	end.

%%领取目标奖励
get_target_gift(PlayerStatus,Day,Times)->
	case PlayerStatus#player.target_gift of
		0-> 
			GameDay = count_game_day(PlayerStatus#player.reg_time),
			case Day =< GameDay of
				true->
					Type = id_to_type(Day,Times), 
					%%检查是否已经领取
					case tatget_gift_had_get(PlayerStatus#player.id,Type) of
						true ->
							%%检查目标是否达到
							case check_target(Type,PlayerStatus) of
								{ok,Result} ->
									case get_gift_info(Day,Times) of
										[]->
											{error,[2,Day,Times]};
										[GoodsInfo,Cash]->
											case gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
										  		{'cell_num'})<length(GoodsInfo) of
												false->
													case add_target_gift(PlayerStatus,GoodsInfo) of
														{ok,_}->
															update_target_gift(PlayerStatus#player.id,Type),
															NewPlayerStatus = add_cash(PlayerStatus,Cash),
															spawn(fun()->catch(db_agent:log_target_gift(PlayerStatus#player.id,Day,Times,Cash,
																										util:term_to_string(GoodsInfo),util:unixtime()))end),
%% 															NewPlayerStatus#player.other#player_other.pid!{'TARGET_STATE'},
															spawn(fun()->check_target_state(PlayerStatus)end),
															{ok,NewPlayerStatus,[Result,Day,Times]};
														{error,_}->
															{error,[2,Day,Times]}
													end;
												true ->
													%%背包位置不足
													{error,[3,Day,Times]}
											end
									end;
								{error,Result}->
									{error,[Result,Day,Times]}
							end;
						false->
							{error,[5,Day,Times]}
					end;
				false->
					%%4目标日期未开启
					{error,[4,Day,Times]}
			end;
		_->
			{error,[5,Day,Times]}
	end.
%%
%% Local Functions
%%
%%添加奖励物品
add_target_gift(PlayerStatus,[])->
	{ok,PlayerStatus};
add_target_gift(PlayerStatus,[Gift|T])->
	[GoodsId,GoodsNum] = Gift,
	case (catch gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'give_goods', PlayerStatus, GoodsId, GoodsNum,2}))of
		ok->add_target_gift(PlayerStatus,T);
		_->{error,PlayerStatus}
	end.

%%增加礼券
add_cash(PlayerStatus,0)->
	PlayerStatus;
add_cash(PlayerStatus,Cash)->
%% 	ValueList = [{cash,Cash,add}],
%% 	WhereList = [{id, PlayerStatus#player.id}],
%%     db_agent:mm_update_player_info(ValueList, WhereList),
	db_agent:add_money(PlayerStatus,Cash,cash,3001),
	NewCash = PlayerStatus#player.cash+Cash,
	PlayerStatus#player{cash=NewCash}.

%%获取玩家身上装备的强化等级
get_equipment_stren_info(PlayerId,Career,Type)->
	case Type of
		suit ->
			get_equipment_max_stren(PlayerId,19);
		weapon ->
			SubType = get_weapon_position(Career),
			get_equipment_max_stren(PlayerId,SubType);
		mount ->
			get_equipment_max_stren(PlayerId,22);
		_-> 0
	end.

%%获取指定装备的最大强化等级
get_equipment_max_stren(PlayerId,SubType)->
	MS = ets:fun2ms(fun(T) when T#goods.player_id =:= PlayerId , T#goods.subtype =:= SubType ,
						  (T#goods.location =:= 1 orelse T#goods.location =:= 4) ->
					T#goods.stren	
					end),
   	case ets:select(?ETS_GOODS_ONLINE, MS) of
		[] ->0;
		StrenList ->lists:max(StrenList)
	end.

%%获取灵兽最大等级
get_pet_max_lv(PlayerId)->
	PetList = lib_pet:get_all_pet(PlayerId),
	Petlv = [Pet#ets_pet.level||Pet<-PetList],
	case Petlv of
		[]->0;
		_->lists:max(Petlv)
	end.

%%获取好友人数
get_friend_num(PlayerId)->
	[NumA, NumB] = db_agent:relationship_get_fri_count(PlayerId),
	Na = 
		case NumA of
			[] -> 0;
			[N] -> N
		end,
	Nb = 
		case NumB of
			[] -> 0;
			[N1] -> N1
		end,
	Na + Nb.

%%获取法宝位置(玄武10、白虎11、青龙9、朱雀13、麒麟12)
get_weapon_position(Career)->
	case Career of
		1 -> 10;
		2 -> 11;
		3 -> 9;
		4 -> 13;
		_ -> 12
	end.

%%计算游戏时间1294021518
count_game_day(RegTime)->
	NowDay = (util:unixtime()+8*3600) div 86400,
	RegDay = (RegTime+8*3600) div 86400,
	abs(NowDay-RegDay+1).


%%检查目标奖励是否领完
check_target_finish(PlayerStatus,Target)->
	NewTarget = lists:append(Target),
	case lists:member(0, NewTarget) of
		true ->
			PlayerStatus;
		false->
			offline(PlayerStatus#player.id),
			db_agent:delete_target_gift_info(PlayerStatus#player.id),
			ValueList = [{target_gift,1}],
			WhereList = [{id, PlayerStatus#player.id}],
    		db_agent:mm_update_player_info(ValueList, WhereList),
			PlayerStatus#player{target_gift=1}
	end.

%%检查目标奖励是否领取
tatget_gift_had_get(PlayerId,Type)->
	case select_target_gift(PlayerId) of
		[]->false;
		[TargetGift] ->
			case Type of
				first ->
					TargetGift#ets_target_gift.first =:= 0;
				first_two ->
					TargetGift#ets_target_gift.first_two =:= 0;
				first_three ->
					TargetGift#ets_target_gift.first_three =:= 0;
				first_four ->
					TargetGift#ets_target_gift.first_four =:= 0;
				first_five ->
					TargetGift#ets_target_gift.first_five =:= 0;
				second ->
					TargetGift#ets_target_gift.second =:= 0;
				second_two ->
					TargetGift#ets_target_gift.second_two =:= 0;
				second_three ->
					TargetGift#ets_target_gift.second_three =:= 0;
				second_four ->
					TargetGift#ets_target_gift.second_four =:= 0;
				second_five ->
					TargetGift#ets_target_gift.second_five =:= 0;
				third ->
					TargetGift#ets_target_gift.third =:= 0;
				third_two ->
					TargetGift#ets_target_gift.third_two =:= 0;
				third_three ->
					TargetGift#ets_target_gift.third_three =:= 0;
				third_four ->
					TargetGift#ets_target_gift.third_four =:= 0;
				third_five ->
					TargetGift#ets_target_gift.third_five =:= 0;
				fourth ->
					TargetGift#ets_target_gift.fourth =:= 0;
				fourth_two ->
					TargetGift#ets_target_gift.fourth_two =:= 0;
				fourth_three ->
					TargetGift#ets_target_gift.fourth_three =:= 0;
				fourth_four ->
					TargetGift#ets_target_gift.fourth_four =:= 0;
				fifth ->
					TargetGift#ets_target_gift.fifth =:= 0;
				fifth_two ->
					TargetGift#ets_target_gift.fifth_two =:= 0;
				fifth_three ->
					TargetGift#ets_target_gift.fifth_three =:= 0;
				sixth ->
					TargetGift#ets_target_gift.sixth =:= 0;
				sixth_two ->
					TargetGift#ets_target_gift.sixth_two =:= 0;
				sixth_three ->
					TargetGift#ets_target_gift.sixth_three =:= 0;
				seventh ->
					TargetGift#ets_target_gift.seventh =:= 0;
				seventh_two ->
					TargetGift#ets_target_gift.seventh_two =:= 0;
				seventh_three ->
					TargetGift#ets_target_gift.seventh_three =:= 0;
				eighth ->
					TargetGift#ets_target_gift.eighth =:= 0;
				eighth_two ->
					TargetGift#ets_target_gift.eighth_two =:= 0;
				ninth ->
					TargetGift#ets_target_gift.ninth =:= 0;
				ninth_two ->
					TargetGift#ets_target_gift.ninth_two =:= 0;
				tenth ->
					TargetGift#ets_target_gift.tenth =:= 0;
				_->
					false
			end
	end.

%%检查目标

%%选择部落(1ok;6未选择部落)
check_target(first,PlayerStatus)->
	case PlayerStatus#player.realm /= 100 of
		true ->
			{ok,1};
		false ->
			{error,6}
	end;
%%成功拜师
check_target(first_two,PlayerStatus)->
	case mod_master_apprentice:get_own_master_id(PlayerStatus#player.id)=:=0 of
		false->
			{ok,1};
		true->
			case mod_master_apprentice:get_my_apprentice_info_page(PlayerStatus#player.id) of
				[]->
					{error,7};
				_->
					{ok,1}
			end
	end;
%%加入氏族
check_target(first_three,PlayerStatus)->
		case PlayerStatus#player.guild_id of
		0->{error,8};
		_->{ok,1}
	end;
%%奇脉1级
check_target(first_four,PlayerStatus)->
	{ok,[Lvl,_LG,_value]} = lib_meridian:check_meridian_lvl_and_linggen(PlayerStatus#player.id,mer_qi),
	case Lvl >= 1 of
		true->{ok,1};
		false->{error,9}
	end;
%%角色30级
check_target(first_five,PlayerStatus)->
	case PlayerStatus#player.lv >= 30 of
		true ->
			{ok,1};
		false ->
			{error,10}
	end;
%%坐骑+3
check_target(second,PlayerStatus)->
	case get_equipment_stren_info(PlayerStatus#player.id,PlayerStatus#player.career,mount)>=3 of
		true ->
			{ok,1};
		false ->
			{error,11}
	end;
%%20个好友
check_target(second_two,PlayerStatus)->
	case get_friend_num(PlayerStatus#player.id) >= 20 of
		true->{ok,1};
		false->{error,12}
	end;

%%氏族2级
check_target(second_three,PlayerStatus)->
	case PlayerStatus#player.guild_id of
		0->
			{error,8};
		GuildId->
			{GuildLvl,_GuildAtt} = lib_guild:get_guild_member_info(GuildId, PlayerStatus#player.id),
			case GuildLvl >= 2 of
				true->
					{ok,1};
				false ->
					{error,13}
			end
	end;
%%角色32级
check_target(second_four,PlayerStatus)->
	case PlayerStatus#player.lv >= 32 of
		true ->
			{ok,1};
		false ->
			{error,14}
	end;
%%参加远古战场
check_target(second_five,PlayerStatus)->
	case db_agent:check_task_by_id(PlayerStatus#player.id,[80002,80003,80004,80005,80006]) of
		[]->{error,15};
		null->{error,15};
		_->{ok,1}
	end;
%%气血到达4000
check_target(third,PlayerStatus)->
	case PlayerStatus#player.hp_lim >= 4000 of
		true->{ok,1};
		false->{error,16}
	end;
%%攻击到达550
check_target(third_two,PlayerStatus)->
	case PlayerStatus#player.max_attack >= 550 of
		true->{ok,1};
		false->{error,17}
	end;
%%氏族3级
check_target(third_three,PlayerStatus)->
	case PlayerStatus#player.guild_id of
		0->
			{error,8};
		GuildId->
			{GuildLvl,_GuildAtt} = lib_guild:get_guild_member_info(GuildId, PlayerStatus#player.id),
			case GuildLvl >= 3 of
				true->
					{ok,1};
				false ->
					{error,18}
			end
	end;
%%灵兽18级
check_target(third_four,PlayerStatus)->
	case get_pet_max_lv(PlayerStatus#player.id) >= 18 of
		true->{ok,1};
		false->{error,19}
	end;
%%角色37级
check_target(third_five,PlayerStatus)->
	case PlayerStatus#player.lv >= 37 of
		true ->
			{ok,1};
		false ->
			{error,20}
	end;
%%气血达到5000
check_target(fourth,PlayerStatus)->
	case PlayerStatus#player.hp_lim >= 5000 of
		true->{ok,1};
		false->{error,21}
	end;
%%攻击达到650
check_target(fourth_two,PlayerStatus)->
	case PlayerStatus#player.max_attack > 650 of
		true->{ok,1};
		false->{error,22}
	end;
%%个人氏族贡献2800
check_target(fourth_three,PlayerStatus)->
	case PlayerStatus#player.guild_id of
		0->
			{error,8};
		GuildId->
			{_GuildLvl,GuildAtt} = lib_guild:get_guild_member_info(GuildId, PlayerStatus#player.id),
			case GuildAtt >= 2800 of
				true->
					{ok,1};
				false ->
					{error,23}
			end
	end;
%%角色38级
check_target(fourth_four,PlayerStatus)->
	case PlayerStatus#player.lv >= 38 of
		true ->
			{ok,1};
		false ->
			{error,24}
	end;
%%灵兽22级
check_target(fifth,PlayerStatus)->
	case get_pet_max_lv(PlayerStatus#player.id) >= 22 of
		true->{ok,1};
		false->{error,25}
	end;
%%个人氏族贡献3500
check_target(fifth_two,PlayerStatus)->
	case PlayerStatus#player.guild_id of
		0->
			{error,8};
		GuildId->
			{_GuildLvl,GuildAtt} = lib_guild:get_guild_member_info(GuildId, PlayerStatus#player.id),
			case GuildAtt >= 3500 of
				true->
					{ok,1};
				false ->
					{error,26}
			end
	end;
%%角色40级
check_target(fifth_three,PlayerStatus)->
	case PlayerStatus#player.lv >= 40 of
		true ->
			{ok,1};
		false ->
			{error,27}
	end;
%%法宝+6
check_target(sixth,PlayerStatus)->
		case get_equipment_stren_info(PlayerStatus#player.id,PlayerStatus#player.career,weapon)>=6 of
		true ->
			{ok,1};
		false ->
			{error,28}
	end;
%%灵兽23级
check_target(sixth_two,PlayerStatus)->
	case get_pet_max_lv(PlayerStatus#player.id) >= 23 of
		true->{ok,1};
		false->{error,29}
	end;
%%角色41级
check_target(sixth_three,PlayerStatus)->
	case PlayerStatus#player.lv >= 41 of
		true ->
			{ok,1};
		false ->
			{error,30}
	end;
%%奇脉4级，灵根4级
check_target(seventh,PlayerStatus)->
	{ok,[Lvl,LG,_value]} = lib_meridian:check_meridian_lvl_and_linggen(PlayerStatus#player.id,mer_qi),
	case Lvl >= 4 of
		true->
			case LG>=40 of
				true ->
					{ok,1};
				false ->
					{error,32}
			end;
		false->
			{error,31}
	end;
%%衣服+6
check_target(seventh_two,PlayerStatus)->
	case get_equipment_stren_info(PlayerStatus#player.id,PlayerStatus#player.career,suit) >= 6 of
		true ->
			{ok,1};
		false ->
			{error,33}
	end;
%%角色到42级
check_target(seventh_three,PlayerStatus)->
	case PlayerStatus#player.lv >= 42 of
		true ->
			{ok,1};
		false ->
			{error,34}
	end;
%%奇脉6级
check_target(eighth,PlayerStatus)->
	{ok,[Lvl,_LG,_value]} = lib_meridian:check_meridian_lvl_and_linggen(PlayerStatus#player.id,mer_qi),
	case Lvl >= 6 of
		true->{ok,1};
		false->{error,35}
	end;
%%角色43级
check_target(eighth_two,PlayerStatus)->
	case PlayerStatus#player.lv >= 43 of
		true ->
			{ok,1};
		false ->
			{error,36}
	end;
%%灵兽25级
check_target(ninth,PlayerStatus)->
	case get_pet_max_lv(PlayerStatus#player.id) >= 25 of
		true->{ok,1};
		false->{error,37}
	end;
%%角色44级
check_target(ninth_two,PlayerStatus)->
	case PlayerStatus#player.lv >= 44 of
		true ->
			{ok,1};
		false ->
			{error,38}
	end;
%%角色45级
check_target(tenth,PlayerStatus)->
	case PlayerStatus#player.lv >= 45 of
		true ->
			{ok,1};
		false ->
			{error,39}
	end;
		
%%异常处理
check_target(_Other,_PlayerStatus) ->
	{error,2}.

%%天数类型转换
id_to_type(Day,Times)->
	case Day of
		1 -> 
			case Times of
				1->first;
				2->first_two;
				3->first_three;
				4->first_four;
				_->first_five
			end;
		2 -> 
			case Times of
				1->second;
				2->second_two;
				3->second_three;
				4->second_four;
				_->second_five
			end;
		3 -> 
			case Times of
				1->third;
				2->third_two;
				3->third_three;
				4->third_four;
				_->third_five
			end;
		4 -> 
			case Times of
				1->fourth;
				2->fourth_two;
				3->fourth_three;
				_->fourth_four
			end;
		5 -> case Times of
				 1->fifth;
				 2->fifth_two;
				 _->fifth_three
			 end;
		6 -> case Times of
				 1->sixth;
				 2->sixth_two;
				 _->sixth_three
			 end;
		7 -> case Times of
				 1->seventh;
				 2->seventh_two;
				 _->seventh_three
			 end;
		8 -> case Times of
				 1->eighth;
				 _->eighth_two
			 end;
		9 -> case Times of
				 1->ninth;
				 _->ninth_two
			 end;
		_ -> tenth
	end.

%%获取玩家目标奖励信息
select_target_gift(PlayerId)->
	Pattern = #ets_target_gift{player_id=PlayerId,_='_'},
	ets:match_object(?ETS_TARGET_GIFT, Pattern).

%%更新目标奖励信息
update_target_gift(PlayerId,Type)->
	db_agent:update_target_gift_info(PlayerId,Type),
	[TargetGift] = select_target_gift(PlayerId),
	case Type of
		first ->
			NewTargetGift = TargetGift#ets_target_gift{first = 1};
		first_two ->
			NewTargetGift = TargetGift#ets_target_gift{first_two = 1};
		first_three ->
			NewTargetGift = TargetGift#ets_target_gift{first_three = 1};
		first_four ->
			NewTargetGift = TargetGift#ets_target_gift{first_four = 1};
		first_five ->
			NewTargetGift = TargetGift#ets_target_gift{first_five = 1};
		second ->
			NewTargetGift = TargetGift#ets_target_gift{second = 1};
		second_two ->
			NewTargetGift = TargetGift#ets_target_gift{second_two = 1};
		second_three ->
			NewTargetGift = TargetGift#ets_target_gift{second_three = 1};
		second_four ->
			NewTargetGift = TargetGift#ets_target_gift{second_four = 1};
		second_five ->
			NewTargetGift = TargetGift#ets_target_gift{second_five = 1};
		third ->
			NewTargetGift = TargetGift#ets_target_gift{third = 1};
		third_two ->
			NewTargetGift = TargetGift#ets_target_gift{third_two = 1};
		third_three ->
			NewTargetGift = TargetGift#ets_target_gift{third_three = 1};
		third_four ->
			NewTargetGift = TargetGift#ets_target_gift{third_four = 1};
		third_five ->
			NewTargetGift = TargetGift#ets_target_gift{third_five = 1};
		fourth ->
			NewTargetGift = TargetGift#ets_target_gift{fourth = 1};
		fourth_two ->
			NewTargetGift = TargetGift#ets_target_gift{fourth_two = 1};
		fourth_three ->
			NewTargetGift = TargetGift#ets_target_gift{fourth_three = 1};
		fourth_four ->
			NewTargetGift = TargetGift#ets_target_gift{fourth_four = 1};
		fifth ->
			NewTargetGift = TargetGift#ets_target_gift{fifth = 1};
		fifth_two ->
			NewTargetGift = TargetGift#ets_target_gift{fifth_two = 1};
		fifth_three ->
			NewTargetGift = TargetGift#ets_target_gift{fifth_three = 1};
		sixth ->
			NewTargetGift = TargetGift#ets_target_gift{sixth = 1};
		sixth_two ->
			NewTargetGift = TargetGift#ets_target_gift{sixth_two = 1};
		sixth_three ->
			NewTargetGift = TargetGift#ets_target_gift{sixth_three = 1};
		seventh ->
			NewTargetGift = TargetGift#ets_target_gift{seventh = 1};
		seventh_two ->
			NewTargetGift = TargetGift#ets_target_gift{seventh_two = 1};
		seventh_three ->
			NewTargetGift = TargetGift#ets_target_gift{seventh_three = 1};
		eighth ->
			NewTargetGift = TargetGift#ets_target_gift{eighth = 1};
		eighth_two ->
			NewTargetGift = TargetGift#ets_target_gift{eighth_two = 1};
		ninth ->
			NewTargetGift = TargetGift#ets_target_gift{ninth = 1};
		ninth_two ->
			NewTargetGift = TargetGift#ets_target_gift{ninth_two = 1};
		tenth ->
			NewTargetGift = TargetGift#ets_target_gift{tenth = 1};
		_->
			NewTargetGift = TargetGift
	end,
	ets:insert(?ETS_TARGET_GIFT,NewTargetGift).

%%获取奖励物品信息
get_gift_info(Day,Times)->
%% 	Pattern = #ets_base_target_gift{day=Day,_='_'},
%% 	ets:match_object(?ETS_BASE_TARGET_GIFT, Pattern).28013
	case Day of
		1->
			case Times of
				1->[[[28201,5]],5];%%筋斗云*5;礼金5
				2->[[[24000,5]],5];%%灵兽口粮*5;礼金5
				3->[[[28201,5],[24000,5]],5];%%筋斗云*5，灵兽口粮*5;礼金5 
				4->[[[28013,5]],5];%%传音符*5，礼金5
				5->[[[22000,3],[28013,5]],0];%% 经脉成长符*3；传音符*5，礼金5
				_->[]
			end;
		2->
			case Times of
				1->[[[21100,3]],5];%%低阶锋芒灵石*3；礼金：5
				2->[[[24000,10]],10];%%灵兽口粮*10；礼金：10
				3->[[[21200,6]],5];%%低阶坚韧灵石*6；礼金：5
				4->[[[23203,3]],10];%%低级经验符*3； 礼金：10
				5->[[[21200,3],[21100,3]],10];%%低阶坚韧灵石*3；低级锋芒石*3； 礼金：10
				_->[]
			end;
		3->
			case Times of
				1->[[[21320,1]],10];%%一级攻击宝石*1；礼金：10
				2->[[[21002,1],[21001,2]],10];%%金色鉴定石*1；蓝色鉴定石*2；礼金：10
				3->[[[23403,2]],10];%%低级防御药*2;礼金：10
				4->[[[24400,2]],20];%%灵兽资质符*2;礼金：20
				5->[[[23403,1],[24000,10]],10];%%低级防御药*1；灵兽口粮*10;礼金：10
				_->[]
			end;
		4->
			case Times of
				1->[[[21330,1]],20];%% 一级防御宝石*1;礼金：20
				2->[[[21360,1]],20];%%一级暴击宝石*1;礼金：20
				3->[[[21400,3]],20];%%初阶打孔石*3; 礼金：20
				4->[[[23400,1],[24000,5]],20];%%低级气血药*1；灵兽口粮*5;礼金：20
				_->[]
			end;
		5->
			case Times of
				1->[[[21101,3]],30];%%中阶锋芒灵石*3;礼金：30
				2->[[[20200,2]],30];%% 初级镶嵌符*2;礼金：30
				3->[[[21201,3],[23400,1]],40];%%中阶坚韧灵石*3；低级气血药*1;礼金：40
				_->[]
			end;
		6->
			case Times of
				1->[[[21300,1],[20300,2]],40];%%一级气血宝石*1；幸运符*2;礼金：40
				2->[[[21330,1],[20300,3]],40];%% 一级防御宝石*1；幸运符*3; 礼金：40
				3->[[[20301,1],[23006,1]],40];%%七彩幸运符*1；气血包*1 ;礼金：40
				_->[]
			end;
		7->
			case Times of
				1->[[[22007,1],[22000,1],[20100,3]],40];%%经脉保护符*1；经脉成长符*1；初级合成符*3;礼金：40
				2->[[[23106,1]],50];%%法力包*1 （中级法力包）;礼金：50
				3->[[[23010,1]],50];%% 大气血包*1; 礼金：50
				_->[]
			end;
		8->
			case Times of
				1->[[[21320,1],[23402,2]],100];%%一级攻击宝石*1；高级气血药*2;礼金：100
				2->[[[20100,3],[20300,3]],60];%%初级合成符*3；幸运符*3;礼金：60
				_->[]
			end;
		9->
			case Times of
				1->[[[24400,1],[24401,1],[24000,8]],100];%%灵兽资质符*1；灵兽保护符*1；灵兽口粮*8;礼金：100
				2->[[[24400,5],[24000,10]],80];%%灵兽资质符*5；灵兽口粮*10;礼金：80
				_->[]
			end;
		10->
			case Times of
				1->[[[20000,3],[20200,3],[23010,1]],500];%%初级摘除符*3；初级镶嵌符*3；大气血包*1;礼金：500
				_->[]
			end;
		_->[]
	end.

%%ets匹配
match_ets_playerinfo(Data)->
	[Id,PlayerId,
	 First,First_2,First_3,First_4,First_5,
	 Second,Second_2,Second_3,Second_4,Second_5,
	 Third,Third_2,Third_3,Third_4,Third_5,
	 Fourth,Fourth_2,Fourth_3,Fourth_4,
	 Fifth,Fifth_2,Fifth_3,
	 Sixth,Sixth_2,Sixth_3,
	 Seventh,Seventh_2,Seventh_3,
	 Eighth,Eighth_2,
	 Ninth,Ninth_2,
	 Tenth]= Data,
	EtsData = #ets_target_gift{
							    id=Id,
      							player_id = PlayerId,          %% 玩家ID	
	  							first = First,
								first_two = First_2,
								first_three = First_3,
								first_four = First_4,
								first_five = First_5,
								second = Second,
								second_two = Second_2,
								second_three = Second_3,
								second_four = Second_4,
								second_five = Second_5,
								third = Third,
								third_two = Third_2,
								third_three = Third_3,
								third_four = Third_4,
								third_five = Third_5,
								fourth = Fourth,
								fourth_two = Fourth_2,
								fourth_three = Fourth_3,
								fourth_four = Fourth_4,
								fifth = Fifth,
								fifth_two = Fifth_2,
								fifth_three = Fifth_3,
								sixth = Sixth,
								sixth_two = Sixth_2,
								sixth_three = Sixth_3,
								seventh = Seventh,
								seventh_two = Seventh_2,
								seventh_three = Seventh_3,
								eighth = Eighth,
								eighth_two = Eighth_2,
								ninth = Ninth,
								ninth_two = Ninth_2,
								tenth = Tenth
							},
	EtsData.

%%删除奖励记录
delete_target_gift_info(PlayerId)->
	offline(PlayerId),
	db_agent:delete_target_gift_info(PlayerId),
	ok.