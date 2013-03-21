%% Author: hzj
%% Created: 2010-9-29
%% Description: TODO: Add description to gmcmd
-module(gmcmd).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
%%
%% Exported Functions
%%
-export([cmd/2]).

%%
%% API Functions
%%
%%
%% Local Functions
%%
cmd(Status,Data) ->
%% ?DEBUG("cmd_~p ~n",[Data]),
	case config:get_can_gmcmd(server) of
		1 ->  do_cmd(Status,Data);
		_ ->  no_cmd
	end.

do_cmd(Status,Data) ->
	 %% -------------------- 测试命令 ----------------
    case string:tokens(Data, " ") of
        ["-加物品",Id,Num] ->
            GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, list_to_integer(Id)),
			if is_record(GoodsTypeInfo,ets_base_goods) ->
				   NewInfo = goods_util:get_new_goods(GoodsTypeInfo),
				   GoodsInfo = NewInfo#goods{ player_id=Status#player.id, location=4, cell=3, num=abs(list_to_integer(Num))},
				   (catch lib_goods:add_goods(GoodsInfo));
			   true ->
				   skip
			end,
			is_cmd;
		["-加时效物品",GoodsId,Timestamp]->
			GoodsTypeId = list_to_integer(GoodsId),
			Time=abs(list_to_integer(Timestamp)),
			gen_server:call(Status#player.other#player_other.pid_goods, {'give_goods', Status, GoodsTypeId, 1,2,Time+util:unixtime()}),
			is_cmd;
		["-加物品",Id,Num,"bind"] ->
            GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, list_to_integer(Id)),
            NewInfo = goods_util:get_new_goods(GoodsTypeInfo),
            GoodsInfo = NewInfo#goods{ player_id=Status#player.id, location=4, cell=3, bind=2, num=abs(list_to_integer(Num))},
            (catch lib_goods:add_goods(GoodsInfo)),
			is_cmd;
		["-加非交易物品",Id,Num] ->
			GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, list_to_integer(Id)),
            NewInfo = goods_util:get_new_goods(GoodsTypeInfo),
            GoodsInfo = NewInfo#goods{ player_id=Status#player.id, location=4, cell=3, bind=0, trade = 1, num=abs(list_to_integer(Num))},
            (catch lib_goods:add_goods(GoodsInfo)),
			is_cmd;
		["-加套装",Value] ->
			BaseSuitList = 
			try
				Id = list_to_integer(Value),
				db_agent:get_base_goods_suit_by_id(Id)
			catch
				_:_ ->db_agent:get_base_goods_suit_by_name(Value)
			end,
			if BaseSuitList == [] ->
				   skip;
			   true ->
				   [BaseSuit|_] = BaseSuitList,
				   BaseSuitInfo = list_to_tuple([ets_base_goods_suit] ++ BaseSuit),
				   Suit_goods = BaseSuitInfo#ets_base_goods_suit.suit_goods,
				   GoodsIdList = util:string_to_term(tool:to_list(Suit_goods)),
				   if GoodsIdList == [] ->
						  skip;
					  true ->
						  F = fun(GoodsId) ->
									  GoodsTypeInfo = goods_util:get_ets_info(?ETS_BASE_GOODS, GoodsId),
									  %%加套装
									 NewInfo = goods_util:get_new_goods(GoodsTypeInfo),
									 GoodsInfo = NewInfo#goods{ player_id=Status#player.id, location=4, num=1},
									 (catch lib_goods:add_goods(GoodsInfo))
							  end,				   
						  [F(GoodsId) ||GoodsId <- GoodsIdList],
						   F1 = fun(_Order) ->
								%%加戒指
					 			GoodsTypeInfo1 = goods_util:get_ets_info(?ETS_BASE_GOODS,10052),
								 %%加套装
								NewInfo1 = goods_util:get_new_goods(GoodsTypeInfo1),
								GoodsInfo1 = NewInfo1#goods{ player_id=Status#player.id, location=4, num=1},
								(catch lib_goods:add_goods(GoodsInfo1)),	
												
								%%加饰品
							    GoodsTypeInfo2 = goods_util:get_ets_info(?ETS_BASE_GOODS,10034),
								NewInfo2 = goods_util:get_new_goods(GoodsTypeInfo2),
								GoodsInfo2 = NewInfo2#goods{ player_id=Status#player.id, location=4, num=1},
								(catch lib_goods:add_goods(GoodsInfo2))
						  end,
						lists:foreach(F1, [1,2])
				   end
			end,
			is_cmd;
		["-设等级",Level] ->
			Lv0 = abs(list_to_integer(Level)),
			Lv= if Lv0 < 1 -> 1;
				   Lv0 > 100 -> 100;
				   true -> Lv0
				end,
			
			(catch db_agent:test_update_player_info([{lv,Lv}],[{id,Status#player.id}])),
			Status2=Status#player{lv=Lv},
			gen_server:cast(Status2#player.other#player_other.pid, {'SET_PLAYER', Status2}),
			lib_player:send_player_attribute(Status2, 1),
			is_cmd;
		["-加铜币",Num] ->
			N1=abs(list_to_integer(Num)),
			(catch db_agent:test_update_player_info([{coin,N1,add},{coin_sum,N1,add}],[{id,Status#player.id}])),
			Coin=Status#player.coin + N1,
			Coin_sum = Status#player.coin_sum + N1,
			Status3=Status#player{coin=Coin,coin_sum=Coin_sum},
			gen_server:cast(Status3#player.other#player_other.pid, {'SET_PLAYER', Status3}),
			lib_player:send_player_attribute2(Status3, 3),
			is_cmd;
		["-加金币",Num] ->
			N2=abs(list_to_integer(Num)),
			(catch db_agent:test_update_player_info([{gold,N2,add}],[{id,Status#player.id}])),
			Gold=Status#player.gold + N2,
			Status4=Status#player{gold=Gold},
			gen_server:cast(Status4#player.other#player_other.pid, {'SET_PLAYER', Status4}),
			lib_player:send_player_attribute2(Status4, 3),
			is_cmd;
		["-加绑定铜",Num] ->
			N3=abs(list_to_integer(Num)),
			(catch db_agent:test_update_player_info([{bcoin,N3,add},{coin_sum,N3,add}],[{id,Status#player.id}])),
			Bcoin=Status#player.bcoin + N3,
			Coin_sum = Status#player.coin_sum + N3,
			Status5=Status#player{bcoin=Bcoin,coin_sum=Coin_sum},
			gen_server:cast(Status5#player.other#player_other.pid, {'SET_PLAYER', Status5}),
			lib_player:send_player_attribute2(Status5, 3),
			is_cmd;
		["-加礼券",Num] ->
			N2=abs(list_to_integer(Num)),
			(catch db_agent:test_update_player_info([{cash,N2,add}],[{id,Status#player.id}])),
			Cash=Status#player.cash + N2,
			Status4=Status#player{cash=Cash},
			gen_server:cast(Status4#player.other#player_other.pid, {'SET_PLAYER', Status4}),
			lib_player:send_player_attribute2(Status4, 3),
			is_cmd;
		["-加礼金",Num] ->
			N4=abs(list_to_integer(Num)),
			(catch db_agent:test_update_player_info([{cash,N4,add}],[{id,Status#player.id}])),
			Cash = Status#player.cash + N4,
			Status6=Status#player{cash = Cash},
			gen_server:cast(Status6#player.other#player_other.pid, {'SET_PLAYER', Status6}),
			lib_player:send_player_attribute2(Status6, 3),
			is_cmd;
		["-设财产",Num] ->
			N=abs(list_to_integer(Num)),
			(catch db_agent:test_update_player_info([{cash,N},{gold,N},{coin,N},{bcion,N}],[{id,Status#player.id}])),
			Status1=Status#player{gold=N,coin=N,bcoin=N,cash=N},
			gen_server:cast(Status1#player.other#player_other.pid, {'SET_PLAYER', Status1}),
			lib_player:send_player_attribute2(Status1, 3),
			is_cmd;
		["-加经验",Num] ->
			N5=abs(list_to_integer(Num)),
			try
				Status2 = lib_player:add_exp(Status,N5,0,0), 
				gen_server:cast(Status2#player.other#player_other.pid, {'SET_PLAYER', Status2}),
				lib_player:send_player_attribute(Status2, 3)
			catch
				_:_ ->error
			end,
			is_cmd;
		["task_zp"] ->
			erlang:send_after(1 * 1000, Status#player.other#player_other.pid, 'TASK_ZP'),
			is_cmd;
		["stda"] ->
			cmd(Status, "-加物品 28201 99"),
			cmd(Status, "-加物品 28201 99"),
			GoldNum = 1000000,
			CoinNum = 1000000,
			Att = 20000,
			Speed = 1500,
			(catch db_agent:test_update_player_info([{gold,GoldNum,add},
													 {bcoin,CoinNum,add},
													 {coin,CoinNum,add},
													 {coin_sum,CoinNum + CoinNum,add},
													 {max_attack,Att,add},
													 {min_attack,Att,add},
													 {speed,Speed}],
													 [{id,Status#player.id}])),
			try
%% 				S_lv = 5,
				Statusx=Status#player{gold=Status#player.gold + GoldNum,
									  	bcoin=Status#player.bcoin + CoinNum,
									  	coin=Status#player.coin + CoinNum,
									  	coin_sum=Status#player.coin_sum + CoinNum + CoinNum,
										max_attack = Status#player.max_attack + Att,
										min_attack = Status#player.min_attack + Att,
										speed = Speed
									  	},
%% 				Statusx = lib_player:count_player_attribute(NewStatus),
				gen_server:cast(Statusx#player.other#player_other.pid, {'SET_PLAYER', Statusx}),
				lib_player:send_player_attribute(Statusx, 3),
				pp_goods:handle(15052, Statusx, clean)
			catch
				_:_ ->error
			end,
			is_cmd;
		["stde"] ->
			cmd(Status, "-加物品 11014 1"),
			cmd(Status, "-加物品 12014 1"),
			cmd(Status, "-加物品 13014 1"),
			cmd(Status, "-加物品 14014 1"),
			cmd(Status, "-加物品 15014 1"),
%% 			db_agent:test_update_player_info([{lv,10}]),
			Statusxx=Status#player{lv=10},
			gen_server:cast(Statusxx#player.other#player_other.pid, {'SET_PLAYER', Statusxx}),
			lib_player:send_player_attribute(Statusxx, 3),
%% 				cmd(Statusxx, "-task 10"),
%% 			timer:sleep(300),
%% 				cmd(Statusxx, "-task 10"),
%% 			timer:sleep(300),
%% 				cmd(Statusxx, "-task 10"),
%% 			timer:sleep(300),
%% 			pp_task:handle(30000, Statusxx, []),
%% 			timer:sleep(500),
%% 				cmd(Statusxx, "-task 10"),
%% 			timer:sleep(300),
%% 				cmd(Statusxx, "-task 10"),
%% 			timer:sleep(300),
%% 				cmd(Statusxx, "-task 10"),
%% 			timer:sleep(300),
%% 				cmd(Statusxx, "-task 10"),
%% 			timer:sleep(300),
%% 			pp_task:handle(30000, Statusxx, []),
%% 			timer:sleep(500),
%% 				cmd(Statusxx, "-task 10"),
%% 			timer:sleep(300),
%% 				cmd(Statusxx, "-task 10"),
%% 			timer:sleep(300),
%% 				cmd(Statusxx, "-task 10"),
%% 			timer:sleep(300),
%% 			pp_task:handle(30000, Statusxx, []),
			timer:sleep(500),
				cmd(Statusxx, "-task 10"),
			timer:sleep(300),
				cmd(Statusxx, "-task 10"),
			timer:sleep(300),
				cmd(Statusxx, "-task 10"),
			timer:sleep(500),
			gen_server:cast(Statusxx#player.other#player_other.pid_task,{'init_task',Statusxx}),
			timer:sleep(500),
			cmd(Statusxx, "-task 10"),
			timer:sleep(1000),
			Default_Sc = "300",
			GoldNum = 0,
			CoinNum = 0,
			Lv = 50,
			Att = 3000,
			Def = 2000,
			A_Def = 2000,
			Realm = util:rand(1,3),
			_Speed = 500,
			Spr = 888888888,
			Cul = 100000,
			Physique = 1500,
			Hp = 50000,
			Mp = 50000,
			Hit = 800,
			(catch db_agent:test_update_player_info([{gold,GoldNum,add},
													 {bcoin,CoinNum,add},
													 {coin,CoinNum,add},
													 {coin_sum,CoinNum + CoinNum,add},
													 {lv,Lv},
													 {max_attack,Att,add},
													 {min_attack,Att,add},
													 {def,Def,add},
%% 													 {speed,Speed},
													 {realm,Realm},
													 {culture,Cul,add},
													 {physique,Physique,add},
													 {hp,Hp,add},
													 {mp,Mp,add},
													 {hit,Hit,add},
													 {spirit,Spr,add},
													 {anti_wind,A_Def,add},
													 {anti_fire,A_Def,add},
													 {anti_water,A_Def,add},
													 {anti_thunder,A_Def,add},
													 {task_convoy_npc,0},
													 {anti_soil,A_Def,add}],[{id,Status#player.id}])),
			try
%% 				S_lv = 5,
				Statusx=Status#player{gold=Status#player.gold + GoldNum,
									  	bcoin=Status#player.bcoin + CoinNum,
									  	coin=Status#player.coin + CoinNum,
									  	coin_sum=Status#player.coin_sum + CoinNum + CoinNum,
										lv=Lv,
										max_attack = Status#player.max_attack + Att,
										min_attack = Status#player.min_attack + Att,
										def = Status#player.def + Def,
										anti_wind = Status#player.anti_wind + A_Def,
										anti_fire = Status#player.anti_fire + A_Def,
										anti_water = Status#player.anti_water + A_Def,
										anti_thunder = Status#player.anti_thunder + A_Def,
										anti_soil = Status#player.anti_soil + A_Def,
%% 										speed = Speed,
										realm = Realm,
									  	physique = Status#player.physique + Physique,
									  	hp = Status#player.hp + Hp,
										mp = Status#player.mp + Mp,
									  	hit = Status#player.hit + Hit,
										culture = Status#player.culture + Cul,
									  	spirit=Status#player.spirit + Spr,
									 	task_convoy_npc = 0
									  	},
%% 				Statusx = lib_player:count_player_attribute(NewStatus),
				gen_server:cast(Statusx#player.other#player_other.pid, {'SET_PLAYER', Statusx}),
				lib_player:send_player_attribute(Statusx, 3),
				set_scene(Statusx, Default_Sc, 1),
            	{ok, BinData} = pt_12:write(12009, [Statusx#player.id, Statusx#player.hp, Statusx#player.hp_lim]),
 				mod_scene_agent:send_to_area_scene(Statusx#player.scene, Statusx#player.x, Statusx#player.y, BinData),
				pp_goods:handle(15052, Statusx, clean)
			catch
				_:_ ->error
			end,
			is_cmd;
		["-祝福等级",Level] ->
			Lv0 = abs(list_to_integer(Level)) - 1,
			Lv= if Lv0 < 1 -> 1;
				   Lv0 > 100 -> 100;
				   true -> Lv0
				end,
			
			(catch db_agent:test_update_player_info([{lv,Lv},{exp, 50}],[{id,Status#player.id}])),
			Status1=Status#player{lv=Lv, exp=50},
			Exp_inc = data_exp:get(Lv),
			try
				Status2 = lib_player:add_exp(Status1,Exp_inc,0,0), 
				gen_server:cast(Status2#player.other#player_other.pid, {'SET_PLAYER', Status2}),
				lib_player:send_player_attribute(Status2, 3)
			catch
				_:_ ->error
			end,
			is_cmd;
		["-加灵力",Num] ->
			N6=abs(list_to_integer(Num)),
			(catch db_agent:test_update_player_info([{spirit,N6,add}],[{id,Status#player.id}])),
			Spirit = Status#player.spirit + N6,
			Status7=Status#player{spirit=Spirit},
			gen_server:cast(Status7#player.other#player_other.pid, {'SET_PLAYER', Status7}),
			lib_player:send_player_attribute(Status7, 3),
			is_cmd;
		["-加修为",Num] ->
			N7=abs(list_to_integer(Num)),
			(catch db_agent:test_update_player_info([{culture,N7,add}],[{id,Status#player.id}])),
			Culture = Status#player.culture + N7,
			Status8=Status#player{culture=Culture},
			gen_server:cast(Status8#player.other#player_other.pid, {'SET_PLAYER', Status8}),
			lib_player:send_player_attribute(Status8, 3),
			is_cmd;
		["-跳场景",Scene] ->	
			set_scene(Status, Scene, 1),
			is_cmd;
		["-场景",Scene] ->	
			set_scene(Status, Scene, 2),
			is_cmd;
		["-设跑速",Num] ->
			N8=abs(list_to_integer(Num)),
			(catch db_agent:test_update_player_info([{speed,N8}],[{id,Status#player.id}])),
			Status10=Status#player{speed=N8},
			gen_server:cast(Status10#player.other#player_other.pid, {'SET_PLAYER', Status10}),
			lib_player:send_player_attribute(Status10, 3),
			is_cmd;
		["-设攻速",Num] ->
			N9=abs(list_to_integer(Num)),
			(catch db_agent:test_update_player_info([{att_speed,N9}],[{id,Status#player.id}])),
			Status11=Status#player{att_speed=N9},
			gen_server:cast(Status11#player.other#player_other.pid, {'SET_PLAYER', Status11}),
			lib_player:send_player_attribute(Status11, 3),
			is_cmd;
		["-加攻击",Num] ->
			N10=abs(list_to_integer(Num)),
			(catch db_agent:test_update_player_info([{max_attack,N10,add},{min_attack,N10,add}],[{id,Status#player.id}])),
			Max_attack = Status#player.max_attack + N10,
			Min_attack = Status#player.min_attack + N10,
			Status12=Status#player{max_attack=Max_attack,min_attack=Min_attack},
			gen_server:cast(Status12#player.other#player_other.pid, {'SET_PLAYER', Status12}),
			lib_player:send_player_attribute(Status12, 3),
			is_cmd;
		["-设攻击", Num] ->
			MinAttack = abs(list_to_integer(Num)),
			MaxAttack = MinAttack + 1,
			spawn(fun()-> db_agent:test_update_player_info([{max_attack, MaxAttack}, {min_attack, MinAttack}], [{id, Status#player.id}]) end),
			NewPlayer = Status#player{max_attack = MaxAttack, min_attack = MinAttack},
			gen_server:cast(NewPlayer#player.other#player_other.pid, {'SET_PLAYER', NewPlayer}),
			lib_player:send_player_attribute(NewPlayer, 3),
			is_cmd;
		["-加防御",Num] ->
			N11 = abs(list_to_integer(Num)),
			(catch db_agent:test_update_player_info([{def,N11,add}],[{id,Status#player.id}])),
			Def = Status#player.def + N11,
			Status13 = Status#player{def = Def},
			gen_server:cast(Status13#player.other#player_other.pid, {'SET_PLAYER', Status13}),
			lib_player:send_player_attribute(Status13, 3),
			is_cmd;
		["-一键称王"] ->
			Atk = 1000000, Def = 1000000, Anti = 1000000, RunSpeed = 800, Gold = 10000000, Coin = 10000000, Cash = 10000000,
			Anti_wind = Status#player.anti_wind + Anti,
			Anti_fire = Status#player.anti_fire + Anti,
			Anti_water = Status#player.anti_water + Anti,
			Anti_thunder = Status#player.anti_thunder + Anti,
			Anti_soil = Status#player.anti_soil + Anti,
			spawn(fun()-> db_agent:test_update_player_info([{max_attack, Atk+1}, {min_attack, Atk}, {def, Def}, {speed, RunSpeed}, {coin, Coin}, {gold,Gold}, {vip,3},{cash, Cash},
															{anti_wind, Anti_wind}, {anti_fire, Anti_fire}, {anti_water, Anti_water}, {anti_thunder, Anti_thunder},
															{anti_soil, Anti_soil}], [{id, Status#player.id}]) end),
			NewPlayer = Status#player{max_attack = Atk+1, min_attack = Atk, def = Def, speed = RunSpeed, gold = Gold, coin = Coin, vip = 3, cash = Cash,
									  anti_wind = Anti_wind, anti_fire = Anti_fire, anti_water = Anti_water, anti_thunder = Anti_thunder, anti_soil = Anti_soil},
			gen_server:cast(Status#player.other#player_other.pid, {'SET_PLAYER', NewPlayer}),
			lib_player:send_player_attribute(NewPlayer, 3),
			is_cmd;
			
		["-换职业",CareerName] ->
			N12 =
			case CareerName of
				"玄武" ->1;
				"白虎" ->2;
				"青龙" ->3;
				"朱雀" ->4;
				"麒麟" ->5;
				_->1
			end,
			(catch db_agent:test_update_player_info([{career,N12}],[{id,Status#player.id}])),
			if
				(N12 > 0 andalso N12 =<5) =:= true ->				
					Status14 = Status#player{career=N12},
					gen_server:cast(Status14#player.other#player_other.pid, {'SET_PLAYER', Status14}),
					lib_player:send_player_attribute(Status14, 3);					
				true ->
					ok
			end,
			is_cmd;
		["-换部落",RealmName] ->
			N12 =
			case RealmName of
				"女娲" ->1;
				"伏羲" ->3;
				"神农" ->2;
				_->1
			end,
			(catch db_agent:test_update_player_info([{realm,N12}],[{id,Status#player.id}])),
			if
				(N12 > 0 andalso N12 =<3) =:= true ->				
					Status14 = Status#player{realm=N12},
					gen_server:cast(Status14#player.other#player_other.pid, {'SET_PLAYER', Status14}),
%% 					SceneId = lib_task:get_sceneid_by_realm(Status14#player.realm),
%% 					pp_scene:handle(12005, Status14, SceneId),
					lib_player:send_player_attribute(Status14, 3);					
				true ->
					ok
			end,
			is_cmd;
		["-加血",Num] ->
			N13 = abs(list_to_integer(Num)),
			(catch db_agent:test_update_player_info([{hp,N13,add}],[{id,Status#player.id}])),
			Hp = Status#player.hp + N13,
			Status15 = Status#player{hp = Hp},
			gen_server:cast(Status15#player.other#player_other.pid, {'SET_PLAYER', Status15}),
			lib_player:send_player_attribute2(Status15, 3),
            {ok, BinData} = pt_12:write(12009, [Status15#player.id, Status15#player.hp, Status15#player.hp_lim]),
 			mod_scene_agent:send_to_area_scene(Status15#player.scene, Status15#player.x, Status15#player.y, BinData),
			is_cmd;
		["-加魔",Num] ->
			N14 = abs(list_to_integer(Num)),
			(catch db_agent:test_update_player_info([{mp,N14,add}],[{id,Status#player.id}])),
			Mp = Status#player.mp + N14,
			Status16 = Status#player{mp = Mp},
			gen_server:cast(Status16#player.other#player_other.pid, {'SET_PLAYER', Status16}),
			lib_player:send_player_attribute2(Status16, 3),
			is_cmd;
		["-加风抗",Num] ->
			N15 = abs(list_to_integer(Num)),
			(catch db_agent:test_update_player_info([{anti_wind,N15,add}],[{id,Status#player.id}])),
			Anti_wind = Status#player.anti_wind + N15,
			Status17 = Status#player{anti_wind = Anti_wind},
			gen_server:cast(Status17#player.other#player_other.pid,{'SET_PLAYER',Status17}),
			lib_player:send_player_attribute(Status17,3),
			is_cmd;
		["-加火抗",Num] ->
			N16 = abs(list_to_integer(Num)),
			(catch db_agent:test_update_player_info([{anti_fire,N16,add}],[{id,Status#player.id}])),
			Anti_fire = Status#player.anti_fire + N16,
			Status18 = Status#player{anti_fire = Anti_fire},
			gen_server:cast(Status18#player.other#player_other.pid,{'SET_PLAYER',Status18}),
			lib_player:send_player_attribute(Status18,3),
			is_cmd;
		["-加水抗",Num] ->
			N17 = abs(list_to_integer(Num)),
			(catch db_agent:test_update_player_info([{anti_water,N17,add}],[{id,Status#player.id}])),
			Anti_water = Status#player.anti_water + N17,
			Status19 = Status#player{anti_water = Anti_water},
			gen_server:cast(Status19#player.other#player_other.pid,{'SET_PLAYER',Status19}),
			lib_player:send_player_attribute(Status19,3),
			is_cmd;
		["-加雷抗",Num] ->
			N18 = abs(list_to_integer(Num)),
			(catch db_agent:test_update_player_info([{anti_thunder,N18,add}],[{id,Status#player.id}])),
			Anti_thunder = Status#player.anti_thunder + N18,
			Status20 = Status#player{anti_thunder = Anti_thunder},
			gen_server:cast(Status20#player.other#player_other.pid,{'SET_PLAYER',Status20}),
			lib_player:send_player_attribute(Status20,3),
			is_cmd;
		["-加土抗",Num] ->
			N19 = abs(list_to_integer(Num)),
			(catch db_agent:test_update_player_info([{anti_soil,N19,add}],[{id,Status#player.id}])),
			Anti_soil = Status#player.anti_soil + N19,
			Status21 = Status#player{anti_soil = Anti_soil},
			gen_server:cast(Status21#player.other#player_other.pid,{'SET_PLAYER',Status21}),
			lib_player:send_player_attribute(Status21,3),
			is_cmd;

        %% 学技能
      	["-学技能", Lv] ->
        	%% 技能等级
			Slv = abs(list_to_integer(Lv)),
 			NewLv = 
				case Slv of
					5 ->
						5;
					4 ->
						4;
					3 ->
						3;
					2 ->
						2;
					_ ->
						1
				end,
            catch ?DB_MODULE:delete(skill, [{player_id, Status#player.id}]),
 			AllSkill = data_skill:get_skill_id_list(Status#player.career),
            F = fun(Sid) ->
                catch ?DB_MODULE:insert(skill, [player_id, skill_id, lv], [Status#player.id, Sid, NewLv]),
                {Sid, NewLv}
            end,
            Skill = [F(S) || S <- AllSkill],
			catch db_agent:test_update_player_info([{skill, Skill}],[{id, Status#player.id}]),			
			NewStatus = Status#player{                                           
          		other = Status#player.other#player_other{
           			skill = Skill
          		}
           	},			
			gen_server:cast(NewStatus#player.other#player_other.pid, {'SET_PLAYER', NewStatus}),
			lib_player:send_player_attribute(NewStatus, 3),
			is_cmd;

		["-加全抗",Num] ->
			N20 = abs(list_to_integer(Num)),
			(catch db_agent:test_update_player_info([{anti_wind,N20,add},{anti_fire,N20,add},{anti_water,N20,add},{anti_thunder,N20,add},{anti_soil,N20,add}],[{id,Status#player.id}])),
			Anti_wind = Status#player.anti_wind + N20,
			Anti_fire = Status#player.anti_fire + N20,
			Anti_water = Status#player.anti_water + N20,
			Anti_thunder = Status#player.anti_thunder + N20,
			Anti_soil = Status#player.anti_soil + N20,
			Status22 = Status#player{anti_wind = Anti_wind,anti_fire = Anti_fire,anti_water = Anti_water,anti_thunder = Anti_thunder,anti_soil = Anti_soil},
			gen_server:cast(Status22#player.other#player_other.pid,{'SET_PLAYER',Status22}),
			lib_player:send_player_attribute(Status22,3),
			is_cmd;
        ["del"] ->
            lib_account:delete_role(Status#player.id, Status#player.accid),
			is_cmd;
        ["taskdel", "all"] ->
            db_agent:pc_del_task_bag(Status#player.id),
            db_agent:pc_del_task_log(Status#player.id),
            lib_task:offline(Status#player.id),
            lib_task:flush_role_task(Status),
            lib_task:trigger(10100, Status),
            {ok, BinData1} = pt_30:write(30006, [1,0]),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData1),
			is_cmd;
        ["spr", Num] ->
            Num1 = abs(list_to_integer(Num)),
            Status1 = Status#player{spirit=Num1},
            gen_server:cast(Status1#player.other#player_other.pid, {'SET_PLAYER', Status1}),
            lib_player:refresh_spirit(Status#player.other#player_other.socket, Num1),
			is_cmd;
		["完成任务"]->
			lib_task:finish_all_task(Status),
			is_cmd;
		["-task",Lv] ->
			N20 = abs(list_to_integer(Lv)),
			lib_task:finish_task_under_lv(Status,N20),
			is_cmd;
		["-天降彩石",Min] ->
			OreSup = mod_ore_sup:get_mod_ore_pid(),
			gen_server:cast(OreSup,{'test',Min}),
			is_cmd;
		["-天降彩石结束"]->
			OreSup = mod_ore_sup:get_mod_ore_pid(),
			gen_server:cast(OreSup,{'test_over'}),
			is_cmd;
		%%["-天降彩石即将结束"] ->
			%%OreSup = mod_ore_sup:get_mod_ore_pid(),
			%%gen_server:cast(OreSup,{'test_over_1'});
		["-单人副本"] ->
			{_,NewStatus} = mod_single_dungeon:enter_single_dungeon_scene(Status),
			 gen_server:cast(Status#player.other#player_other.pid, {'SET_PLAYER', NewStatus}),
			is_cmd;
		["-试炼副本"] ->
			case  pp_scene:handle(12005, Status, 901) of
				{_,_,NewStatus} ->
					gen_server:cast(Status#player.other#player_other.pid, {'SET_PLAYER', NewStatus});
				_ ->
					skip
			end,
			is_cmd;
		["-离开试炼副本"] ->
			case pp_scene:handle(12030, Status, leave) of
				{_,_,NewStatus} ->
					gen_server:cast(Status#player.other#player_other.pid, {'SET_PLAYER', NewStatus});
				_ ->
					skip
			end,
			is_cmd;
		["-灵兽经验",Num]->
			case Status#player.other#player_other.out_pet of
				[]->
					skip;
				Pet->
					Exp = abs(list_to_integer(Num)),
					lib_pet:test_update_pet_exp(Status#player.other#player_other.pid_send,Status#player.lv,Pet,Exp)
			end,
			is_cmd;
		%%add by zkj begin======================================
		["-灵兽资质",Num]->
			case Status#player.other#player_other.out_pet of
				[]->
					skip;
				Pet->
					Apt = abs(list_to_integer(Num)),
					lib_pet:test_update_pet_apt(Status#player.other#player_other.pid_send,Status#player.lv,Pet,Apt),
					mod_pet:pet_attribute_effect(Status,Pet)
			end,
			is_cmd;
		["-灵兽等级",Num]->
			case Status#player.other#player_other.out_pet of
				[]->
					skip;
				Pet->
					Level = abs(list_to_integer(Num)),
					lib_pet:test_update_pet_level(Status#player.other#player_other.pid_send,Status#player.lv,Pet,Level),
					mod_pet:pet_attribute_effect(Status,Pet)
			end,
			is_cmd;
		["-灵兽成长",Num]->
			case Status#player.other#player_other.out_pet of
				[]->
					skip;
				Pet->
					Grow = abs(list_to_integer(Num)),
					lib_pet:test_update_pet_grow(Pet,Grow),
					mod_pet:pet_attribute_effect(Status,Pet)
			end,
			is_cmd;
		["-灵兽快乐值",Num]->
			case Status#player.other#player_other.out_pet of
				[]->
					skip;
				Pet->
					Happy = abs(list_to_integer(Num)),
					lib_pet:test_update_pet_happy(Pet,Happy),
					mod_pet:pet_attribute_effect(Status,Pet)
			end,
			is_cmd;
		["-灵兽训练时间",Num]->
			case Status#player.other#player_other.out_pet of
				[]->
					skip;
				Pet->
					Time = abs(list_to_integer(Num)),
					lib_pet:test_update_pet_train(Status,Pet,Time)
			end,
			is_cmd;
		["-经脉灵根",Num]->
			Lv = abs(list_to_integer(Num)),
			NewLv = round(Lv div 10 * 10),
			if NewLv > 0 andalso NewLv =< 100->
				   mod_meridian:gm_linggen(Status,NewLv);
			   true->skip
			end,
			is_cmd;
		["-灵兽战斗技能",Num]->
			SkillId = abs(list_to_integer(Num)),
			lib_goods:give_pet_batt_skill_goods({SkillId, 1}, Status#player.id),
			is_cmd;
		%%add by zkj end======================================
		["-加天数",Num] ->
			N20 = abs(list_to_integer(Num)*86400),
			(catch db_agent:test_update_player_info([{reg_time,N20,sub}],[{id,Status#player.id}])),
			Reg_time = Status#player.reg_time - N20,
			Status13 = Status#player{reg_time = Reg_time},
			gen_server:cast(Status13#player.other#player_other.pid, {'SET_PLAYER', Status13}),
			lib_player:send_player_attribute(Status13, 3),
			is_cmd;
		["-我要VIP",Num] ->
			NowTime = util:unixtime(),
			{Vip,Timestamp} = case tool:to_integer(Num) of
							1-> {1,NowTime + 30 * 24* 3600};
							2-> {2,NowTime + 30*24 *3600 *3};
							3->{3,NowTime + 30*24 *3600 *3};
							_->{4,NowTime + 7*24 *3600 *3}
						end,
			(catch db_agent:test_update_player_info([{vip,Vip},{vip_time,Timestamp}],[{id,Status#player.id}])),
			Status13 = Status#player{vip=Vip,vip_time=Timestamp},
			gen_server:cast(Status13#player.other#player_other.pid, {'SET_PLAYER', Status13}),
			lib_player:send_player_attribute(Status13, 3),
			is_cmd;
		["-取消VIP"]->
			(catch db_agent:test_update_player_info([{vip,0},{vip_time,0}],[{id,Status#player.id}])),
			Status13 = Status#player{vip=0,vip_time=0},
			gen_server:cast(Status13#player.other#player_other.pid, {'SET_PLAYER', Status13}),
			lib_player:send_player_attribute(Status13, 3),
			is_cmd;
		["-减少VIP时间",Num] ->
			case Status#player.vip >  0 of
				true->
					NowTime = util:unixtime()+(abs(list_to_integer(Num))*3600),
					case NowTime >  Status#player.vip_time of
						true->
							(catch db_agent:test_update_player_info([{vip,0},{vip_time,0}],[{id,Status#player.id}])),
							Status13 = Status#player{vip=0,vip_time=0};
						false->
							End = Status#player.vip_time-(abs(list_to_integer(Num))*3600),
							(catch db_agent:test_update_player_info([{vip_time,End}],[{id,Status#player.id}])),
							Status13 = Status#player{vip_time=End}
					end,
					gen_server:cast(Status13#player.other#player_other.pid, {'SET_PLAYER', Status13}),
					lib_player:send_player_attribute(Status13, 3),
					is_cmd;
				false->no_cmd
			end;
		["-抽奖次数",Num]->
			N20 = abs(list_to_integer(Num)),
			lib_lucky_draw:test_times(Status#player.id,N20),
			is_cmd;
		["-氏族技能令", GuildName, Num] ->
			GuildNameBin = tool:to_binary(GuildName),
			NewNum = tool:to_integer(Num),
%% 			case lib_guild_inner:get_guild_by_name(GuildNameBin) of
			case gen_server:call(mod_guild:get_mod_guild_pid(), 
								 {apply_call, lib_guild_inner, 
								  get_guild_by_name, [GuildNameBin]}) of
				[] ->
					no_cmd;
				Guild ->
					NewReputation = Guild#ets_guild.reputation + NewNum,
					NewGuild = Guild#ets_guild{reputation = NewReputation},
					db_agent:guild_add_reputation(Guild#ets_guild.id, NewReputation),
					%%更新氏族缓存
					gen_server:cast(mod_guild:get_mod_guild_pid(), {'update_guild_info', NewGuild}),
					is_cmd
			end;	
		["-离线累积时间",Num]->
			Hours = abs(list_to_integer(Num)),
			lib_offline_award:test_change_offline_time(Status#player.id,Hours),
			is_cmd;
		["-活动在线天数",Num]->
			Day = abs(list_to_integer(Num)),
			lib_online_award:test_change_time(holiday,Status#player.id,Day),
			is_cmd;
		["-重置活动数据"]->
			lib_online_award:test_change_time(holiday_del,Status#player.id,0),
			is_cmd;
		["-连续在线",Num]->
			Day = abs(list_to_integer(Num)),
			lib_online_award:test_change_time(date,Status#player.id,Day),
			is_cmd;
		["-天在线时长",Num]->
			Hours = abs(list_to_integer(Num)),
			lib_online_award:test_change_time(day,Status#player.id,Hours),
			is_cmd;
		["-周在线时长",Num]->
			Hours = abs(list_to_integer(Num)),
			lib_online_award:test_change_time(week,Status#player.id,Hours),
			is_cmd;
		["-月在线时长",Num]->
			Hours = abs(list_to_integer(Num)),
			lib_online_award:test_change_time(mon,Status#player.id,Hours),
			is_cmd;
		["-挂机时间",Num]->
			Seconds = abs(list_to_integer(Num)),
			lib_hook:set_hooking_time_test(Status#player.id,Seconds),
			is_cmd;
		["-加魅力",Num]->
			Charm = abs(list_to_integer(Num)),
			_NewPlayerStatus = lib_love:get_evaluate(Status,Charm),
			is_cmd;
		["-加声望",Num]->
			Value = abs(list_to_integer(Num)),
			mod_war_supervisor:set_war_award(Status#player.id,1,Value),
			is_cmd;
		["-修改登陆时间"]->
			lib_login_award:gmcmd_change_login(Status#player.id),
			is_cmd;
		["-我是RMB"]->
			lib_login_award:gmcmd_bacome_rmb(Status#player.id),
			is_cmd;
		["-我要充值",Num]->
			Gold = abs(list_to_integer(Num)),
			db_agent:test_charge_insert(Status#player.id,Gold),
			(catch db_agent:test_update_player_info([{gold,Gold,add}],[{id,Status#player.id}])),
			Gold1=Status#player.gold + Gold,
			Status4=Status#player{gold=Gold1},
			gen_server:cast(Status4#player.other#player_other.pid, {'SET_PLAYER', Status4}),
			lib_player:send_player_attribute2(Status4, 3),
			is_cmd;
		["-模拟充值",Num]->
			Gold = abs(list_to_integer(Num)),		
%% 			db_agent:insert_pay_log(Now, "gm", Status#player.id, Status#player.nickname, 
%% 									Status#player.lv, Now, 1, round(Gold/10), Gold, Now, Now, 1,1),
			?DEBUG("Gold = ~p",[Gold]),
			db_agent:test_charge_insert(Status#player.id,Gold),
			(catch db_agent:test_update_player_info([{gold,Gold,add}],[{id,Status#player.id}])),
			Gold1=Status#player.gold + Gold,
			Status4=Status#player{gold=Gold1},
			gen_server:cast(Status4#player.other#player_other.pid, {'SET_PLAYER', Status4}),
			lib_player:send_player_attribute2(Status4, 3),
			%% 为了模拟，自己cast
			gen_server:cast(Status4#player.other#player_other.pid, {'CHANGE_MONEY', [1, 1, Gold1, 1]}),
			is_cmd;
		["-我是非RMB"]->
			lib_login_award:gmcmd_bacome_un_rmb(Status#player.id),
			is_cmd;
		["-氏族标配", GuildName] ->
			GuildNameBin = tool:to_binary(GuildName),
%% 			case lib_guild_inner:get_guild_by_name(GuildNameBin) of
			case gen_server:call(mod_guild:get_mod_guild_pid(), 
								 {apply_call, lib_guild_inner, 
								  get_guild_by_name, [GuildNameBin]}) of
				[] ->
					no_cmd;
				Guild ->
							NewGuild = Guild#ets_guild{level = 7,
													   reputation = 20,
													   skills = 10,
													   funds = 10000000},
							ValueList = [{level, 7}, {reputation, 20}, {skills, 10}, {funds, 10000000}],
							FieldList = [{id, Guild#ets_guild.id}],
							db_agent:gm_guild_base(ValueList, FieldList),
							gen_server:cast(mod_guild:get_mod_guild_pid(), {'update_guild_info', NewGuild})
			end,
			is_cmd;
		["-刷新氏族boss", GuildName] ->
			GuildNameBin = tool:to_binary(GuildName),
%% 			case lib_guild_inner:get_guild_by_name(GuildNameBin) of
			case gen_server:call(mod_guild:get_mod_guild_pid(), 
								 {apply_call, lib_guild_inner, 
								  get_guild_by_name, [GuildNameBin]}) of
				[] ->
					no_cmd;
				Guild ->
							NewGuild = Guild#ets_guild{lct_boss = util:term_to_string([0,0,0]),
													   boss_sv = 0,
													   funds = 10000000},
							ValueList = [{boss_sv, 0}, {lct_boss, util:term_to_string([0,0,0])}, {funds, 10000000}],
							FieldList = [{id, Guild#ets_guild.id}],
							db_agent:gm_guild_base(ValueList, FieldList),
							gen_server:cast(mod_guild:get_mod_guild_pid(), {'update_guild_info', NewGuild})
			end,
			is_cmd;
		["-氏族升级", GuildName, Num] ->
			GuildNameBin = tool:to_binary(GuildName),
			NewNum = tool:to_integer(Num),
%% 			case lib_guild_inner:get_guild_by_name(GuildNameBin) of
			case gen_server:call(mod_guild:get_mod_guild_pid(), 
								 {apply_call, lib_guild_inner, 
								  get_guild_by_name, [GuildNameBin]}) of
				[] ->
					no_cmd;
				Guild ->
					case NewNum >= 1 andalso NewNum =< 10 of
						true ->
							NewGuild = Guild#ets_guild{level = NewNum},
							db_agent:gm_update_guild_level(Guild#ets_guild.id, NewNum),
							gen_server:cast(mod_guild:get_mod_guild_pid(), {'update_guild_info', NewGuild});
						false ->
							skip
					end
			end,
			is_cmd;
		["-氏族奖励", GuildName] ->
			GuildNameBin = tool:to_binary(GuildName),
			gen_server:cast(mod_guild:get_mod_guild_pid(),
								{apply_cast, lib_skyrush,
								 gmcmd_update_skyaward, [GuildNameBin]}),
			is_cmd;
		["-申请八神珠"] ->
			WhereList = [{pid, Status#player.id}],
			ValueList = [{ts13, 1},{ts14, 1},{ts15, 1},{ts16, 1},{ts17, 1},{ts18, 1},{ts19, 1},{ts20, 1},
						 {ts21, 1},{ts22, 1},{ts23, 1},{ts24, 1},{ts25, 1},{ts26, 1},{ts27, 1},{ts28, 1},
						 {ts101, 1},{ts102, 1},{ts103, 1},{ts104, 1},{ts105, 1},{ts106, 1},{ts107, 1},{ts108, 1}],
			db_agent:update_player_achieve(ach_treasure, ValueList, WhereList),
			db_agent:update_player_achieve(goods, [{type, 82}], [{player_id, Status#player.id}]),%%清物品
			is_cmd;
		["-每天在线奖励"] ->
			WhereList = [{id, Status#player.id}],
			db_agent:mm_update_player_info([{online_gift,1}], WhereList),
			NewStatus = Status#player{online_gift = 1},
			Result = lib_daily_award:check_today_times(NewStatus),
			{ok, BinData} = pt_30:write(30900,[Result]),
	        lib_send:send_to_sid(NewStatus#player.other#player_other.pid_send, BinData),
			is_cmd;
		["-后退一天"] ->
			case db_agent:find_single_award(Status#player.id) of
				[] ->skip;
				Info -> 
					[ PlayerId, GainTimes, TimeStamp ] = Info,
					Time = TimeStamp - ?ONE_DAY_SECONDS,
					NewInfo = #ets_daily_online_award{pid = PlayerId, gain_times = GainTimes, timestamp = Time},
					ets:insert(?ETS_DAILY_ONLINE_AWARD,NewInfo),
	                db_agent:update_daily_award(PlayerId, GainTimes, Time),
				    Result = lib_daily_award:check_today_times(Status),
			        {ok, BinData} = pt_30:write(30900,[Result]),
	                lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData)
			end,
			is_cmd;
		["-隔天"] ->
			Now = util:unixtime(),
			db_agent:update_bless_bottle([{bless_time,Now - 86400}],[{player_id,Status#player.id}]),
			is_cmd;
		["-我要大礼包"] ->
			db_agent:delete_card_used(Status#player.id),
			%PlatFormName = config:get_platform_name(),
			ServerNum = config:get_server_num(),
			Accname = Status#player.accname,
			CardKey = config:get_card_key(),
			MakeCardString = util:md5(lists:concat([Accname,tool:to_list(ServerNum),CardKey])),
			lib_mail:send_sys_mail([Status#player.nickname], "新手卡卡号", MakeCardString, 0, 0, 0, 0, 0),
			lib_mail:send_sys_mail([Status#player.nickname], "首充大礼包", "2", 0, 28120, 1, 0, 0),
			lib_mail:send_sys_mail([Status#player.nickname], "VIP礼包", "2", 0, 28185, 1, 0, 0),
            %
			io:format("gmcmd send mail gift ~p ~n", [CardKey]),
			is_cmd;
			
		["-加氏族经验", GuildName, Exp] ->
			GuildNameBin = tool:to_binary(GuildName),
			NewExp = tool:to_integer(Exp),
%% 			case lib_guild_inner:get_guild_by_name(GuildNameBin) of
			case gen_server:call(mod_guild:get_mod_guild_pid(), 
								 {apply_call, lib_guild_inner, 
								  get_guild_by_name, [GuildNameBin]}) of
				[] ->
					no_cmd;
				Guild ->
					case Guild#ets_guild.level > 0 andalso Guild#ets_guild.level < 10 of
						true ->
							[_Funds, NeedExp, _NeedTime, _AddSkills] = 
								data_guild:get_guild_upgrade_info(Guild#ets_guild.level+1),
							GuildId = Guild#ets_guild.id,
							if 
								NeedExp =< Guild#ets_guild.exp ->%%经验满了,不再增加
									no_action;
								NeedExp =< (Guild#ets_guild.exp + NewExp)  ->%%做了这任务，经验就满了
									NewGuild = Guild#ets_guild{exp = NeedExp},
									db_agent:increase_guild_exp(GuildId, NeedExp - Guild#ets_guild.exp, 0),
									%%更新氏族缓存
									gen_server:cast(mod_guild:get_mod_guild_pid(), {'update_guild_info', NewGuild});
								true ->
									NewGuild = Guild#ets_guild{exp = Guild#ets_guild.exp + NewExp},
									db_agent:increase_guild_exp(GuildId, NewExp, 0),
									%%更新氏族缓存
									gen_server:cast(mod_guild:get_mod_guild_pid(), {'update_guild_info', NewGuild})
							end;
						false ->
							no_action
					end,
					is_cmd
			end;
		["-成熟",FarmIds] ->
			F = fun(Farm_Id) ->
						Farm_Info_list = lib_manor:get_db_farm_info_list(Status#player.id),
						if
							Farm_Info_list == [] ->
								skip;
							true ->
								Farm_Info = lists:nth(1, Farm_Info_list),
								Farm = lib_manor:get_farm_by_id(Farm_Id, Farm_Info),
								[Fstate, Sgoodsid, _Sstate, Plant, _Grow, _Fruit, _Celerate] = Farm,
								Seed_Info = lib_manor:get_seed_info(Sgoodsid), %%取种子信息
								[ _ , _ , { _ , _Grow_Time, Max_Fruit, _, _ }] = Seed_Info,
								lib_manor:update_farm_by_id(Status#player.id, Farm_Id, [Fstate, Sgoodsid, 3, Plant-15*3600, Plant, Max_Fruit, 1]),
								lib_manor:write_log(insert,11111,	Status#player.id, util:unixtime(), 7, Status#player.id, Status#player.nickname, Farm_Id, Sgoodsid, Max_Fruit, 1),
								lib_manor:send_fram_status_when_change(Status, Farm_Id),
								Data1 = lib_manor:get_farm_info(Status, Farm_Id),
								{ok, BinData1} = pt_42:write(42011, Data1),
								lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData1),
								is_cmd
						end
				end,
			[F(FarmId) || FarmId <- util:string_to_term(FarmIds)];
		["-诛仙台荣誉",Num]->
			Honor = abs(list_to_integer(Num)),
			NewStatus = lib_scene_fst:add_zxt_honor(Status,Honor),
			mod_player:save_online_diff(Status,NewStatus),
			is_cmd;
		["-active"] ->%%活跃度在线时间 GM命令，每次+30分钟
			lib_activity:update_activity_data(online, Status#player.other#player_other.pid, Status#player.id, 30),%%添加玩家活跃度统计;
			is_cmd;
		
		["-加亲密度",Name,Num]->
			Rid = lib_player:get_role_id_by_name(Name),
			IntNum = tool:to_integer(Num),
			case lib_relationship:find_is_exists(Status#player.id,Rid,1) of
				{ok,false} -> skip;
				{Id,true} ->
					{DbId,Id1,1} = Id,
					if Id1 == Status#player.id ->
						   [R|_Relas] = ets:lookup(?ETS_RELA,Id),
						   NewRela = R#ets_rela{close = IntNum},
						   ets:insert(?ETS_RELA,NewRela),
						   ID = {DbId,Rid,1},
						   case lib_player:get_player_pid(Rid) of
							   [] ->skip;
							   Pid ->
								   Pid ! ({'SET_CLOSE',[ID, NewRela#ets_rela.pk_mon, NewRela#ets_rela.timestamp, IntNum]})
						   end,
						   spawn(fun()->db_agent:update_close(DbId,NewRela#ets_rela.close,NewRela#ets_rela.pk_mon,NewRela#ets_rela.timestamp)end);
					   true ->
						   ID = {DbId,Status#player.id,1},
						   [R|_Relas] = ets:lookup(?ETS_RELA,ID),
						   NewRela = R#ets_rela{close = IntNum},
						   ets:insert(?ETS_RELA,NewRela),
						   case lib_player:get_player_pid(Rid) of
							   [] ->skip;
							   Pid ->
								   Pid ! ({'SET_CLOSE',[Id, NewRela#ets_rela.pk_mon, NewRela#ets_rela.timestamp, IntNum]})
						   end,
						   spawn(fun()->db_agent:update_close(DbId,NewRela#ets_rela.close,NewRela#ets_rela.pk_mon,NewRela#ets_rela.timestamp)end)
					end
			end,
			is_cmd;
		["-坐骑等级",Num]->
			case Status#player.mount of
				[]->
					skip;
				MountId->
					Mount = lib_mount:get_mount(MountId),
					Level = abs(list_to_integer(Num)),
					NewMount = Mount#ets_mount{level=Level},
					lib_mount:update_mount(NewMount),
					db_agent:update_mount([{level,NewMount#ets_mount.level}],[{id,NewMount#ets_mount.id}])
			end,
			is_cmd;
		["-坐骑精魂",Name] ->
			 SkillId = data_mount:get_skill_id_name(Name),
			 if SkillId == 0 ->skip;
				true ->
					[Type,Color] = data_mount:get_skill_type_color(SkillId),
					MountSkillSplitId = lib_mount:save_mount_skill_split(Status#player.id,SkillId,0,Color,1,Type),
					MountSkillSplitInfo = #ets_mount_skill_split{
									  id = MountSkillSplitId,
									  player_id = Status#player.id,
									  skill_id = SkillId,
									  exp = 0,
									  color = Color,
									  level = 1,
									  type = Type							  
					},			 
					lib_mount:update_mount_skill_split(MountSkillSplitInfo),
					if Color >= 3 andalso Color =< 4 ->
						   NameColor = data_agent:get_realm_color(Status#player.realm),
						   Msg2 = io_lib:format("恭喜！玩家[<a href='event:1,~p, ~s, ~p,~p'><font color='~s'><u>~s</u></font></a>]猎到了极为珍贵的精魂<a href='event:4,~p'><font color='~s'><u>[~s]</u></font></a>！真是让人羡慕妒忌恨啊！",[Status#player.id,Status#player.nickname,Status#player.career,Status#player.sex,NameColor,Status#player.nickname,MountSkillSplitId,data_mount:get_skill_name_color(Color+1),data_mount:get_skill_name(SkillId)]),
						   lib_chat:broadcast_sys_msg(2,Msg2),
						   lib_act_interf:mount_purple_skill(Status#player.nickname, Color);
					   true ->
						   skip
					end,
					pp_mount:handle(16023, Status, []),
					pp_mount:handle(16024, Status, [])
			 end,
			 is_cmd;
		["-结婚三天"]->
			Ms = 
			case Status#player.sex of
				1 ->
					ets:fun2ms(fun(M) when M#ets_marry.boy_id =:= Status#player.id -> M end);
				2 ->
					ets:fun2ms(fun(M) when M#ets_marry.girl_id =:= Status#player.id -> M end)
			end,
			case ets:select(?ETS_MARRY,Ms) of
				[] -> skip;
				[M|_Rets] ->
					Rid = 
						case Status#player.sex of
							1 -> M#ets_marry.girl_id;
							2 -> M#ets_marry.boy_id
						end,
					NewTime = M#ets_marry.marry_time - 3*86400,
					{DbId,Id} = M#ets_marry.id,
					case Id =/= Status#player.id of
						true ->
							case ets:lookup(?ETS_MARRY, {DbId,Status#player.id}) of
								[] -> skip;
								[Marry1|_R] ->
									?DEBUG("1PLAYERID = ~p~n",[Status#player.id]),
									ets:insert(?ETS_MARRY, Marry1#ets_marry{marry_time = NewTime})
							end;
						false ->
							?DEBUG("2PLAYERID = ~p~n",[Status#player.id]),
							ets:insert(?ETS_MARRY, M#ets_marry{marry_time = NewTime})
					end,
					
					 case lib_player:get_player_pid(Rid) of
							   [] ->skip;
							   Rpid ->
								   Rpid ! {'gm_marry_3_days',NewTime,DbId}
					end,
					db_agent:update_marry_time(DbId,NewTime)
			end,
			is_cmd;
		["-离婚七天"]->
			Ms = 
			case Status#player.sex of
				1 ->
					ets:fun2ms(fun(M) when M#ets_marry.boy_id =:= Status#player.id -> M end);
				2 ->
					ets:fun2ms(fun(M) when M#ets_marry.girl_id =:= Status#player.id -> M end)
			end,
			case ets:select(?ETS_MARRY,Ms) of
				[] -> skip;
				[M|_Rets] ->
					Rid = 
						case Status#player.sex of
							1 -> M#ets_marry.girl_id;
							2 -> M#ets_marry.boy_id
						end,
					NewTime = M#ets_marry.div_time - 7*86400,
					{DbId,Id} = M#ets_marry.id,
					case Id =/= Status#player.id of
						true ->
							case ets:lookup(?ETS_MARRY, {DbId,Status#player.id}) of
								[] -> skip;
								[Marry1|_R] ->
									ets:insert(?ETS_MARRY, Marry1#ets_marry{div_time = NewTime})
							end;
						false ->
							ets:insert(?ETS_MARRY, M#ets_marry{div_time = NewTime})
					end,
					case lib_player:get_player_pid(Rid) of
						[] ->skip;
						Rpid ->
							Rpid ! {'gm_unmarry_7_days',NewTime,DbId}
					end,
					db_agent:update_divorce_time(DbId,NewTime)
			end,
			is_cmd;
		
		["-结婚",Name]->
			Rid = lib_player:get_role_id_by_name(Name),
			IntNum = 50000,
			case lib_relationship:find_is_exists(Status#player.id,Rid,1) of
				{ok,false} -> skip;
				{Id,true} ->
					{DbrId,Id1,1} = Id,
					if Id1 == Status#player.id ->
						   [R|_Relas] = ets:lookup(?ETS_RELA,Id),
						   NewRela = R#ets_rela{close = IntNum},
						   ets:insert(?ETS_RELA,NewRela),
						   ID = {DbrId,Rid,1},
						   case lib_player:get_player_pid(Rid) of
							   [] ->skip;
							   Pid ->
								   Pid ! ({'SET_CLOSE',[ID, NewRela#ets_rela.pk_mon, NewRela#ets_rela.timestamp, IntNum]})
						   end,
						   spawn(fun()->db_agent:update_close(DbrId,NewRela#ets_rela.close,NewRela#ets_rela.pk_mon,NewRela#ets_rela.timestamp)end);
					   true ->
						   ID = {DbrId,Status#player.id,1},
						   [R|_Relas] = ets:lookup(?ETS_RELA,ID),
						   NewRela = R#ets_rela{close = IntNum},
						   ets:insert(?ETS_RELA,NewRela),
						   case lib_player:get_player_pid(Rid) of
							   [] ->skip;
							   Pid ->
								   Pid ! ({'SET_CLOSE',[Id, NewRela#ets_rela.pk_mon, NewRela#ets_rela.timestamp, IntNum]})
						   end,
						   spawn(fun()->db_agent:update_close(DbrId,NewRela#ets_rela.close,NewRela#ets_rela.pk_mon,NewRela#ets_rela.timestamp)end)
					end,
					Now = util:unixtime(),
					case Status#player.sex of
						1 ->
							case db_agent:get_marry_row(Status#player.id,boy_id) of
								[] -> skip;
								Data ->
									[OldId,BoyId,GirlId,_DoWedding,_MarryTime,_RecGold,_RecCoin,_Divorce,_DivTime] = Data,
									catch ets:delete(?ETS_MARRY, {OldId,BoyId}),
									case lib_player:get_player_pid(GirlId) of
										[] ->skip;
										Gpid1 ->
											Gpid1 ! ({'gm_del_marry',OldId})
									end,
									spawn(fun()->db_agent:del_marry_by_boy(Status#player.id) end)
							end;
						2 ->
							case db_agent:get_marry_row(Status#player.id,girl_id) of
								[] -> skip;
								Data ->
									[OldId,BoyId,GirlId,_DoWedding,_MarryTime,_RecGold,_RecCoin,_Divorce,_DivTime] = Data,
									catch ets:delete(?ETS_MARRY, {OldId,GirlId}),
									case lib_player:get_player_pid(BoyId) of
										[] ->skip;
										Bpid ->
											Bpid ! ({'gm_del_marry',OldId})
									end,
									spawn(fun()->db_agent:del_marry_by_girl(Rid) end)
							end
					end,
					DbId = db_agent:do_marry(Now,Status#player.id,Rid),
					Marry = #ets_marry{ id = {DbId,Status#player.id}, boy_id = Status#player.id, girl_id = Rid, marry_time = Now, do_wedding = 1},
					ets:insert(?ETS_MARRY, Marry),
					case lib_player:get_player_pid(Rid) of
						[] -> skip;
						Gpid ->
							Gpid ! {'marry_sucess',Marry#ets_marry{id = {DbId,Rid}}},
							Gpid ! {'end_do_marry',Status#player.nickname,DbId}
					end,
					{ok,GirlBin} = pt_48:write(48002,1),
					{ok,BoyBin} = pt_48:write(48016,1),
					lib_send:send_to_sid(Status#player.other#player_other.pid_send, BoyBin),
					lib_send:send_to_uid(Rid,GirlBin),
					Self = self(),
					Self ! {'end_do_marry',Name,DbId},
					?DB_MODULE:update(marry, [{do_wedding, 1}], [{id,DbId}]),
					db_agent:update_cuple_name(Name,Status#player.id),
					db_agent:update_cuple_name(Status#player.nickname,Rid)
			end,
			is_cmd;
			
		["-猜灯谜刷新"] ->
			%%更新数据库数据
			WhereList = [{pid, Status#player.id}],
			ValueList = [{time,0},{num, 0},{state, 0},{qid,0}],
			db_agent:update_lantern_riddles(ValueList, WhereList),
			%%改进程字典
			put(lantern, {0,0,0,0}),
			is_cmd;
		["-镇妖奖励"]->
			mod_rank:single_td_award_cmd(),
			is_cmd;
		["-镇妖榜"]->
			mod_rank:single_td_rank_cmd(),
			id_cmd;
		["-镇妖奖励排名",Num]->
			Rank = abs(list_to_integer(Num)),
			mod_rank:cmd_single_td_rank(Status#player.id,Rank),
			is_cmd;
		["-经验找回"]->
			NowTime = util:unixtime(),
			lib_find_exp:find_exp_single_cmd(Status,Status#player.lv,Status#player.guild_id,NowTime+86400),
%% 			lib_find_exp:init_find_exp(Status#player.id),
			is_cmd;
		["-分身"]->
%% 			Status,SkillList,SceneId,X,Y
			SkillList = mod_mon_create:shadow_skill(Status),
			gen_server:cast(Status#player.other#player_other.pid_scene,{'SHADOW',[Status,SkillList,Status#player.scene,Status#player.x+1,Status#player.y+1]}),
			is_cmd;
		["-分身1"] ->
			SkillList = mod_mon_create:shadow_skill(Status),
			gen_server:cast(Status#player.other#player_other.pid_scene, {'CREATE_SHADOW', Status#player.id, SkillList}),
			is_cmd;
		["-批量分身",Num]->
			Nums = abs(list_to_integer(Num)),
			SkillList = mod_mon_create:shadow_skill(Status),
			List = lists:seq(1, Nums),
			[gen_server:cast(Status#player.other#player_other.pid_scene,{'SHADOW',[Status,SkillList,Status#player.scene,Status#player.x+1,Status#player.y+1]})||_N<- List],
			is_cmd;
		["-重置任务",Num]->
			TaskId =  abs(list_to_integer(Num)),
			lib_task:cmd_reset_task(Status,TaskId),
			is_cmd;
		["-跨服功勋",Num]->
			Honor =  abs(list_to_integer(Num)),
			lib_war2:add_war_honor(Status,Honor),
			is_cmd;
		["-青桃子"] ->
			db_agent:del_goods_buff(Status#player.id, 23409),
			db_agent:delete_bigwheel_use(Status#player.id, 1),
			is_cmd;
		["-我要重新竞猜"] ->
			Now = util:unixtime(),
			case lib_activities:is_all_may_day_time(Now) of
				true ->
					gen_server:cast(mod_quizzes:get_quizzes_pid(), {'GM_CLEAR_QUIZZES', Status#player.id}),
					is_cmd;
				false ->
					no_cmd
			end;
		["-远古目标"]->
			lib_target:cmd_finish_target(Status),
			is_cmd;
%% 		["-坐骑等级",Num]->
%% 			case Status#player.mount of
%% 				[]->
%% 					skip;
%% 				MountId->
%% 					Mount = lib_mount:get_mount(MountId),
%% 					Level = abs(list_to_integer(Num)),
%% 					NewMount = Mount#ets_mount{level=Level},
%% 					lib_mount:update_mount(NewMount),
%% 					db_agent:update_mount([{level,NewMount#ets_mount.level}],[{id,NewMount#ets_mount.id}])
%% 			end,
%% 			is_cmd;
%% 		["-坐骑喂养",Num]->
%% 			case Status#player.mount of
%% 				[]->
%% 					skip;
%% 				MountId->
%% 					Mount = lib_mount:get_mount(MountId),
%% 					Num1 = abs(list_to_integer(Num)),
%% 					lib_mount:feed_mount(Status,Mount,24000,Num1),
%% 					NewMount = lib_mount:get_mount(MountId),
%% 					lib_mount:update_mount(NewMount),
%% 					db_agent:update_mount([{level,NewMount#ets_mount.level},{exp,NewMount#ets_mount.exp}],[{id,NewMount#ets_mount.id}])
%% 			end,
%% 			is_cmd;
		_ -> no_cmd
	end.
         
set_scene(Status, Scene, Type)->
	[Sid,Name,X,Y]=
	case (catch abs(list_to_integer(Scene))) of
		{'EXIT',_} ->
			 case db_agent:test_get_scene_byname(abs(Scene)) of
				 []->
					 [0,0,0,0];
				 R0 ->
					 R0
			 end;
		Id ->
			case db_agent:test_get_scene_byid(Id) of					
				[]->
					[0,0,0,0];
				R ->
					R
			end
	end,
	if
		Sid > 0 ->
			enter_scene(Status,Sid,Name,X,Y,Type);
		true ->
			skip
	end.

enter_scene(Status,Id,Name,X,Y,Type) ->
    case abs(Id) == Status#player.scene of
        true when Id =/= 0 ->
            {ok, BinData} = pt_12:write(12005, [Id, Status#player.x, Status#player.y, <<>>, Id, 0, 0, 0]),
            lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData);
        false when Id =/= 0 ->
			Is_dungeon_scene =
            	case ets:lookup(?ETS_BASE_SCENE, Id) of
                	[] -> false;
                	[S] -> S#ets_scene.type =:= 2
            	end,		
			case Is_dungeon_scene of
				true -> fail;
					
				_ ->
				 	if	Type =:= 1 ->	%% 非常规变换场景
            			{ok, BinData} = pt_12:write(12005, [Id, X, Y, Name, Id, 0, 0, 0]),
            			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
            			%%告诉原来场景玩家你已经离开
						pp_scene:handle(12004, Status, Status#player.scene),
            			Status2 = Status#player{scene = Id, x = X, y = Y},
						gen_server:cast(Status#player.other#player_other.pid, {'SET_PLAYER', Status2}),
						ok;
					true ->	%% 变换场景前，将进行条件检查
						case pp_scene:handle(12005, Status, Id) of
						{ok, Status2} ->
							gen_server:cast(Status#player.other#player_other.pid, {'SET_PLAYER', Status2});
						_-> other
						end
				end
			end;
		true ->
			skip
    end.
