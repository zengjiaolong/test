%%%--------------------------------------
%%% @Module  : pp_deliver
%%% @Author  : lzz
%%% @Created : 2010.12.15
%%% @Description:  传送功能
%%%--------------------------------------
-module(pp_deliver).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%% 传送信息
handle(31000, Status, [Scid]) ->
	%% 竞技场不可以使用传送
	case lib_arena:is_arena_scene(Status#player.scene) of
		false ->
			[Res, Status_updated] = lib_deliver:deliver(Status, Scid),
			{ok, BinData} = pt_31:write(31000, Res),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			{ok, Status_updated};
		true ->
			skip
	end;	


%% 绑定回城石信息
handle(31001, Status, [Scid]) ->
	Res = lib_deliver:fix_home(Status, Scid),
	{ok, BinData} = pt_31:write(31001, [Res]),
	lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),	
	ok;


%% 使用回城石信息
handle(31002, Status, [GoodsId]) ->
	%% 竞技场不可以使用传送
	case lib_arena:is_arena_scene(Status#player.scene) of
		false ->
			Goodsinfo = goods_util:get_goods(GoodsId),
			[Res, Return_21002] = lib_deliver:back_home(Status, Goodsinfo),
			{ok, BinData} = pt_31:write(31002, [Res]),
			lib_send:send_to_sid(Status#player.other#player_other.pid_send, BinData),
			Return_21002;
		true ->
			skip
	end;

%% 幻魔穴区域信息
handle(31010, Player, _) ->
	case is_pid(Player#player.other#player_other.pid_dungeon) of
		true ->
			gen_server:cast(Player#player.other#player_other.pid_dungeon, 
					{'GET_ZONE_INFO', Player#player.id, Player#player.other#player_other.pid_send});			
		false ->
			skip
	end;

handle(_Cmd, _Player, _Data) ->
%%     ?DEBUG("pp_deliver no match", []),
    {error, "pp_deliver no match"}.

