%% Author: xianrongMai
%% Created: 2011-8-23
%% Description: TODO: Add description to lib_lotus
-module(lib_lotus).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include("hot_spring.hrl").
%%
%% Exported Functions
%%
-export([
		 reset_player_lotus/1,		%%通知复位玩家的状态
		 player_spring_move/1,		%%玩家移动，取消采莲
		 give_lotus/1,				%%采集到莲花，给玩家发奖励
		 check_spring_time/0,		%%检查温泉的时间
		 random_lotus/4				%%随机产生 莲花的类型和坐标
		]).

%%
%% API Functions
%%
%%获取莲花的随机坐标
random_lotus(0, _OldCoords, NewCoords, _LotusCoords) ->
	NewCoords;
random_lotus(Num, OldCoords, NewCoords, LotusCoords) ->
	RandNum = util:rand(1, ?LOTUS_COORDS_MAX),
	{RX, RY}= lists:nth(RandNum, LotusCoords),
	Result = 
		lists:any(fun({X,Y}) ->
						  RX =:= X andalso RY =:= Y
				  end, OldCoords), 
	case Result of
		true ->%%出现雷同的，直接T掉，重新随机
			random_lotus(Num, OldCoords, NewCoords, LotusCoords);
		false ->%%这对组合可用
			random_lotus(Num-1, [{RX,RY}|OldCoords], [{RX,RY}|NewCoords], LotusCoords)
	end.

%%检查温泉的时间
check_spring_time() ->
	NowSec = util:get_today_current_second(),
	[{SO,EO},{ST,ET}] = lib_spring:get_spring_on_sale_times(),%%获取温泉的开放时间
	A = NowSec >= SO andalso NowSec =< (EO-5),
	B = NowSec >= ST andalso NowSec =< (ET-5),
	A orelse B.


%%采集到莲花，给玩家发奖励
give_lotus(PlayerId) ->
	GoodsTypeId = get_lotus_award(),
	 case lib_player:get_player_pid(PlayerId) of
		 [] ->
			 skip;
		 Pid when is_pid(Pid)->%%往玩家发信息
			 gen_server:cast(Pid, {'GIVE_LOTUS_AWARD', GoodsTypeId});
		 _ ->
			 skip
	end.
%%通知复位玩家的状态
reset_player_lotus(Players) ->
	lists:map(fun(Elem) ->
					  {_Time, PlayerId} = Elem,
					  case lib_player:get_player_pid(PlayerId) of
						  [] ->
							  skip;
						  Pid ->
							  gen_server:cast(Pid, {'RESET_LOTUS_MARK'})
					  end
			  end, Players).
	
	
%%玩家移动，取消采莲
player_spring_move(Player) ->
	case Player#player.carry_mark =/= 0 of
		true ->
			%%发给自己说，取消采莲
			{ok,BinData12064} = pt_12:write(12064, []),
			lib_send:send_to_sid(Player#player.other#player_other.pid_send, BinData12064),
			%%广播给场景的人
			{ok,BinData12041} = pt_12:write(12041, [Player#player.id, 0]),
			mod_scene_agent:send_to_area_scene(Player#player.scene,Player#player.x, Player#player.y, BinData12041),
			%%通知场景进程，T掉玩家在莲花采集队列中的轮询资格
			gen_server:cast(Player#player.other#player_other.pid_scene, {'CANCEL_COLLECT_LOTUS', Player#player.id}),%%去掉采集的数据
			NewPlayer = Player#player{carry_mark = 0},
			mod_player:save_online_diff(Player, NewPlayer),	
			mod_player:save_player_table(NewPlayer),
			NewPlayer;
		false ->
			Player
	end.

		
%%
%% Local Functions
%%
%%获取随机奖励的物品ID
get_lotus_award() ->
	RandNum = util:rand(1, 100),
	get_random_goods(RandNum, ?LOTUS_AWARD_GOODS).
			
%%取出对应的物品Id
get_random_goods(RandNum, [Elem|Rest]) ->
	{Min, Max, GoodsId} = Elem,
	case RandNum >= Min andalso RandNum =< Max of
		true ->
			GoodsId;
		false ->
			get_random_goods(RandNum, Rest)
	end.