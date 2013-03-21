%%%--------------------------------------
%%% @Module  : lib_double_rest
%%% @Created : 2011.10.26
%%% @Description:双修相关处理
%%%--------------------------------------
-module(lib_double_rest).
-export([
		 get_double_rest_list/1,
		 get_double_rest_user/1,
		 send_double_rest/2,
		 accept_double_rest/3,
		 double_rest_oper/5,
		 get_add_exp_sprit_culture_time/0,
		 get_double_love_value_time/0,
		 get_double_love_value/0,
		 cancel_double_rest/1
		]).
-include("common.hrl").
-include("record.hrl"). 
-include("guild_info.hrl").
-define(ADD_EXP_SPRIRT_CULTURE_TIME, 18000).	
-define(ADD_DOUBLE_REST_LOVE_TIME, 1*60*1000).	
-define(ADD_DOUBLE_REST_LOVE_ALUE, 1).	

get_add_exp_sprit_culture_time() ->
	?ADD_EXP_SPRIRT_CULTURE_TIME.

%%每5分钟增加双方的亲密度值1点
get_double_love_value_time() ->
	?ADD_DOUBLE_REST_LOVE_TIME.

%%每5分钟增加双方的亲密度值1点
get_double_love_value() ->
	?ADD_DOUBLE_REST_LOVE_ALUE.
	
%%返回场景内（一屏内）的在线玩家
get_double_rest_list(Player) ->
	mod_scene:get_all_scene_user(Player).

%%从所有在线玩家中查找角色名
get_double_rest_user(Nickname) ->
	PlayerId = lib_player:get_role_id_by_name(Nickname),
	Player = lib_player:get_online_info(PlayerId),
	case Player of
		[] -> [];
		_ ->
			[Player#player.id,Player#player.nickname,Player#player.lv,Player#player.career]
	end.

%%发出双修邀请
send_double_rest(Player,OtherPlayerId) ->
	OtherPlayer = lib_player:get_online_info(OtherPlayerId),
	if Player#player.mount > 0 ->
		   [6,OtherPlayer,0,0,0,0,0,0,0,0,0,0];%%有坐骑不能双修		
		OtherPlayer == [] -> 
			[7,OtherPlayer,0,0,0,0,0,0,0,0,0,0];%%对方不在线
		true ->
			X = OtherPlayer#player.x,
			Y = OtherPlayer#player.y,
			if
				X rem 2 =/= 0 ->
					X1 = X-1;
				true ->
					X1 = X+1
			end,
			if OtherPlayer#player.status == 10 ->
					[8,OtherPlayer,0,0,0,0,0,0,0,0,0,0]; %%对方已经在双修状态
			   Player#player.status == 10 ->
					[9,OtherPlayer,0,0,0,0,0,0,0,0,0,0]; %%您已经在双修状态
				true ->
					Is_Td = lib_scene:is_td_scene(Player#player.scene),
					Is_Zxt = lib_scene:is_zxt_scene(Player#player.scene),
					Id_fst = lib_scene:is_fst_scene(Player#player.scene),
					Other_Is_Td = lib_scene:is_td_scene(OtherPlayer#player.scene),
					Other_Is_Zxt = lib_scene:is_zxt_scene(OtherPlayer#player.scene),
					Other_Id_fst = lib_scene:is_fst_scene(OtherPlayer#player.scene),
					Accept = OtherPlayer#player.other#player_other.accept,
					OtherStatus = OtherPlayer#player.status, 
					IsSpring1 = lib_spring:is_spring_scene(Player#player.scene),
					IsSpring2 = lib_spring:is_spring_scene(OtherPlayer#player.scene),
					IsWarServer = lib_war:is_war_server(),				
					if  
						IsSpring1 == true orelse IsSpring2 == true -> 
							[5,OtherPlayer,0,0,0,0,0,0,0,0,0,0]; %%温泉内无法双修 
						(Player#player.scene >= 600 andalso Player#player.scene =< 700) orelse (OtherPlayer#player.scene >= 600 andalso OtherPlayer#player.scene =< 700) ->
							[10,OtherPlayer,0,0,0,0,0,0,0,0,0,0]; %%战场内无法双修
						Player#player.scene =:= ?SKY_RUSH_SCENE_ID orelse OtherPlayer#player.scene =:= ?SKY_RUSH_SCENE_ID orelse Is_Td == true orelse Is_Zxt == true 
						  orelse Other_Is_Td == true orelse  Other_Is_Zxt == true orelse Id_fst == true orelse Other_Id_fst == true orelse Player#player.scene =:= 800 orelse Player#player.scene =:= 215 orelse Player#player.scene =:= 216->
							[11,OtherPlayer,0,0,0,0,0,0,0,0,0,0];%%空岛,封神台，诛仙台中不能双修
						IsWarServer == true ->
							[12,OtherPlayer,0,0,0,0,0,0,0,0,0,0];%%跨服战场不能双修
						OtherPlayer#player.mount > 0 ->
							[13,OtherPlayer,0,0,0,0,0,0,0,0,0,0];%%对方有坐骑不能接受双修邀请
						Player#player.status == 4 orelse OtherPlayer#player.status == 4->
							[15,OtherPlayer,0,0,0,0,0,0,0,0,0,0];%%蓝名状态不能双修
						OtherStatus == 6 andalso Accept == 1 ->
							[1,OtherPlayer,OtherPlayer#player.id,OtherPlayer#player.scene,X1,Y,X,Y,Player#player.id,Player#player.scene,X1,Y];%%对方设置了自动接受并自动同意
					   OtherStatus == 6 andalso Accept == 3 ->
							[1,OtherPlayer,OtherPlayer#player.id,OtherPlayer#player.scene,X1,Y,X,Y,Player#player.id,Player#player.scene,X1,Y];%%对方设置了自动接受并自动同意
					   OtherStatus == 6 andalso Accept == 2 ->
							[2,OtherPlayer,OtherPlayer#player.id,OtherPlayer#player.scene,X1,Y,X,Y,Player#player.id,Player#player.scene,X1,Y];%%对方设置了需要玩家手动点同意
					   OtherStatus =/= 6 andalso Accept == 1 ->
						    [2,OtherPlayer,OtherPlayer#player.id,OtherPlayer#player.scene,X1,Y,X,Y,Player#player.id,Player#player.scene,X1,Y];%%对方设置了需要玩家手动点同意
					   OtherStatus =/= 6 andalso Accept == 2 ->
						    [2,OtherPlayer,OtherPlayer#player.id,OtherPlayer#player.scene,X1,Y,X,Y,Player#player.id,Player#player.scene,X1,Y];%%对方设置了需要玩家手动点同意
					   %%其它情况为拒绝邀请
						true ->
							[4,OtherPlayer,0,0,0,0,0,0,0,0,0,0]%%对方设置了拒绝双修邀请
%% 							%%通知对方弹出邀请窗口
%% 							{ok, BinData} = pt_13:write(13044, [Player#player.id,Player#player.nickname]),
%% 							lib_send:send_to_sid(OtherPlayer#player.other#player_other.pid_send, BinData),
%% 							1
					end
			end
	end.

%%同意或拒绝双修邀请code 同意1，拒绝2
accept_double_rest(Player,OtherPlayerId,Code) ->
	OtherPlayer = lib_player:get_online_info(OtherPlayerId),
	case OtherPlayer of
		[] -> 
			[3,0,0,0,0,0,0,0,0,0,0];%%对方不在线
		_ ->
			Status = OtherPlayer#player.status,
			case Status == 10 of
				true ->
					[4,0,0,0,0,0,0,0,0,0,0]; %%对方已经在双修状态
				false ->
					Accept = OtherPlayer#player.other#player_other.accept,
					Is_Td = lib_scene:is_td_scene(Player#player.scene),
					Is_Zxt = lib_scene:is_zxt_scene(Player#player.scene),
					IsSpring1 = lib_spring:is_spring_scene(Player#player.scene),
					IsSpring2 = lib_spring:is_spring_scene(OtherPlayer#player.scene),
					Id_fst = lib_scene:is_fst_scene(Player#player.scene),
					Other_Is_Td = lib_scene:is_td_scene(OtherPlayer#player.scene),
					Other_Is_Zxt = lib_scene:is_zxt_scene(OtherPlayer#player.scene),
					Other_Id_fst = lib_scene:is_fst_scene(OtherPlayer#player.scene),
					
					case Accept of
						4 ->
							[2,0,0,0,0,0,0,0,0,0,0];%%对方设置了拒绝双修邀请
						_ ->
							if
								Player#player.mount > 0 ->
									[6,0,0,0,0,0,0,0,0,0,0];%%有坐骑不能双修
								Player#player.status == 3 ->
									[7,0,0,0,0,0,0,0,0,0,0];%%已经死亡不能双修
								Player#player.status == 4 ->
									[8,0,0,0,0,0,0,0,0,0,0];%%蓝名不能双修
								Player#player.status == 7 ->
									[9,0,0,0,0,0,0,0,0,0,0];%%凝神修炼
								Player#player.status == 8 ->
									[10,0,0,0,0,0,0,0,0,0,0];%%采矿不能双修  
								Player#player.scene == 520 orelse  (Player#player.scene >= 600 andalso Player#player.scene =<700)  orelse Player#player.scene == 750 orelse Player#player.scene == 760  ->
									[12,0,0,0,0,0,0,0,0,0,0];%%采矿不能双修
								Player#player.scene =:= 800 orelse Player#player.scene =:= ?SKY_RUSH_SCENE_ID orelse Is_Td == true orelse Is_Zxt == true orelse Other_Is_Td == true orelse Other_Is_Zxt == true orelse Id_fst == true orelse Other_Id_fst == true orelse Player#player.scene =:= 215 orelse Player#player.scene =:= 216->
									[13,0,0,0,0,0,0,0,0,0,0];%%空岛,封神台,诛仙台
								IsSpring1 == true orelse IsSpring2 == true -> 
									[14,0,0,0,0,0,0,0,0,0,0];%%在温泉里不能双修
								Player#player.mount > 0 ->
									[15,0,0,0,0,0,0,0,0,0,0];%%有坐骑不能双修
								(Player#player.carry_mark >= 1  andalso Player#player.carry_mark =< 3)  orelse (Player#player.carry_mark >= 20  andalso Player#player.carry_mark =< 25)->
									[16,0,0,0,0,0,0,0,0,0,0];%%运镖状态，不能双修
								Player#player.carry_mark >= 4  andalso Player#player.carry_mark =< 7 ->
									[17,0,0,0,0,0,0,0,0,0,0];%%跑商状态，不能双修
								Player#player.status == 4 orelse OtherPlayer#player.status == 4->
									[18,0,0,0,0,0,0,0,0,0,0];%%蓝名状态不能双修
								true ->
									case Code of
										1 ->
											%%X为单位为向左，双数为向右(且两人X坐标必须为一个单数一个双数),Y坐标一致，保持在平行线
											X = Player#player.x,
											Y = Player#player.y,
											if
												X rem 2 =/= 0 ->
													X1 = X-1;
												true ->
													X1 = X+1
											end,
											[1,Player#player.id,Player#player.scene,X1,Y,X,Y,OtherPlayer#player.id,OtherPlayer#player.scene,X1,Y];
										2 ->
											[5,0,0,0,0,0,0,0,0,0,0]
									end
							end
					end
			end
	end.


%%开始或取消双修动作(Code开始双修1，结束双修2)
double_rest_oper(Player,OtherPlayerId,Code,InitX,InitY) ->
	case Code of
		2 ->
			{ok, NewPlayer} = cancel_double_rest(Player),
			[7,NewPlayer];
		1 ->
			OtherPlayer = lib_player:get_online_info(OtherPlayerId),
			case OtherPlayer of
				[] -> 
					[3,Player];%%对方不在线
				_ ->
					Status = OtherPlayer#player.status,
					if Code == 1 andalso Status == 10  ->
						   [4,Player]; %%对方已经在双修状态
					   true ->
						   Accept = OtherPlayer#player.other#player_other.accept,
						   case Accept of
							   4 ->
								   [5,Player];%%对方设置了拒绝双修邀请
							   _ ->
								   X = OtherPlayer#player.x,
								   Y = OtherPlayer#player.y,
								   if
									   X =/= InitX orelse Y =/= InitY ->
										   [6,Player];
									   true ->
%% 										   %%添加吃桃定时器
%% 										   Type = Player#player.other#player_other.goods_buff#goods_cur_buff.peach_mult,
%% 										   IsPeach = lib_peach:is_local_peach(Player#player.scene, [Player#player.x, Player#player.y]), 
%% 										   Type1 = OtherPlayer#player.other#player_other.goods_buff#goods_cur_buff.peach_mult,
%% 										   IsPeach1 = lib_peach:is_local_peach(OtherPlayer#player.scene, [OtherPlayer#player.x, OtherPlayer#player.y]), 
%% 										   %%添加吃桃定时器
%% 										   if Type =/= 1 andalso IsPeach == ok ->
%% 												  Player#player.other#player_other.pid!{'DOUBLE_TEST_PEACH'};
%% 											  Type1 =/= 1 andalso IsPeach1 == ok ->
%% 												  OtherPlayer#player.other#player_other.pid!{'DOUBLE_TEST_PEACH'};
%% 											  true ->
%% 												  skip
%% 										   end,
										%%开始双修
										%%将对方的状态设为双修
											{ok, BinData} = pt_13:write(13047,[OtherPlayer#player.id,10,OtherPlayer#player.x,OtherPlayer#player.y]),
											mod_scene_agent:send_to_area_scene(OtherPlayer#player.scene, OtherPlayer#player.x, OtherPlayer#player.y, BinData),
											OtherPlayer#player.other#player_other.pid!{'DOUBLE_REST_ADD_EXP',[Player#player.id,Player#player.other#player_other.pid,0]},
											%%将自己的状态设为双修
											{ok, BinData1} = pt_13:write(13047,[Player#player.id,10,Player#player.x,Player#player.y]),
											mod_scene_agent:send_to_area_scene(Player#player.scene, Player#player.x, Player#player.y, BinData1),
											{ok, NewPlayer} = lib_player:start_double_rest(Player,[OtherPlayerId,OtherPlayer#player.other#player_other.pid,0]),
											%%开始增加双方亲密度
											Double_rest_close_timer = erlang:send_after(lib_double_rest:get_double_love_value_time(), self(), {'DOUBLE_TEST_LOVE',OtherPlayer}),
											put(double_rest_close_timer,Double_rest_close_timer),
											[1,NewPlayer]
								   end
						   end
					end
			end
	end.
	
%%取消双修(供外表调用)
cancel_double_rest(Player) ->
	OtherPlayerId = Player#player.other#player_other.double_rest_id,
	OtherPlayer = lib_player:get_online_info(OtherPlayerId),
	case OtherPlayer of
		[] -> skip;
		_ ->
			if
				%%取消对方的双修状态
				OtherPlayer#player.status == 10 ->
					OtherPlayer#player.other#player_other.pid!{'CANEL_DOUBLE_REST_EXP'};
				true ->
					skip
			end
	end,
	%%取消自己的双修状态
	lib_player:cancel_double_rest(Player,0).




	