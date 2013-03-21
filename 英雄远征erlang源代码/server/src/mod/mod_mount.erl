%%%------------------------------------
%%% @Module  : mod_mount
%%% @Author  : xhg
%%% @Email   : xuhuguang@jieyou.com
%%% @Created : 2010.06.02
%%% @Description: 坐骑模块
%%%------------------------------------
-module(mod_mount).
-behaviour(gen_server).
-export([start/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-include("common.hrl").
-include("record.hrl").
-define(MAX_MOUNT_NUM, 5).

start(PlayerId) ->
    gen_server:start_link(?MODULE, [PlayerId], []).

init([PlayerId]) ->
    {ok, PlayerId}.

handle_cast(_Reason , PlayerId) ->
    {noreply, PlayerId}.

%% 获取状态
handle_call({'status'}, _From, PlayerId) ->
    {reply, PlayerId, PlayerId};

%% 获取坐骑详细信息
handle_call({'info', PlayerStatus, MountId}, _From, PlayerId) ->
    MountInfo = lib_mount:get_info(MountId),
    case is_record(MountInfo, goods) of
        %% 坐骑不存在
        false ->
            {reply, [2, 0, 0, 0], PlayerId};
        %% 坐骑类型不正确
        true when MountInfo#goods.type =/= 31 ->
            {reply, [3, 0, 0, 0], PlayerId};
        true ->
            UseState = case PlayerStatus#player_status.mount =:= MountId of
                            true -> 1;
                            false -> 0
                    end,
            {reply, [1, MountInfo#goods.goods_id, MountInfo#goods.bind, UseState], PlayerId}
    end;

%% 乘上坐骑
handle_call({'get_on', PlayerStatus, MountId}, _From, PlayerId) ->
    MountInfo = lib_mount:get_info(MountId),
    case is_record(MountInfo, goods) of
        %% 坐骑不存在
        false ->
            {reply, [PlayerStatus, 2, 0, 0, 0, 0], PlayerId};
        %% 坐骑类型不正确
        true when MountInfo#goods.type =/= 31 ->
            {reply, [PlayerStatus, 3, 0, 0, 0, 0], PlayerId};
        %% 已经乘上
        true when PlayerStatus#player_status.mount =:= MountId ->
            {reply, [PlayerStatus, 4, 0, 0, 0, 0], PlayerId};
        %% 灵力不足
        true when PlayerStatus#player_status.spirit =< 0 ->
            {reply, [PlayerStatus, 5, 0, 0, 0, 0], PlayerId};
        true ->
            GoodsStatus = gen_server:call(PlayerStatus#player_status.goods_pid, {'STATUS'}),
            case (catch lib_mount:get_on(PlayerStatus, GoodsStatus, MountInfo)) of
                {ok, NewPlayerStatus, NewGoodsStatus, [OldMountId, OldMountTypeId, OldMountCell, MountTypeId]} ->
                    ok = gen_server:call(PlayerStatus#player_status.goods_pid, {'SET_STATUS', NewGoodsStatus}),
                    {reply, [NewPlayerStatus, 1, OldMountId, OldMountTypeId, OldMountCell, MountTypeId], PlayerId};
                Error ->
                    ?DEBUG("mod_mount get_on:~p", [Error]),
                    {reply, [PlayerStatus, 0, 0, 0, 0, 0], PlayerId}
            end
    end;

%% 离开坐骑
handle_call({'get_off', PlayerStatus, MountId}, _From, PlayerId) ->
    MountInfo = lib_mount:get_info(MountId),
    case is_record(MountInfo, goods) of
        %% 坐骑不存在
        false ->
            {reply, [PlayerStatus, 2, 0, 0], PlayerId};
        %% 没有乘上
        true when PlayerStatus#player_status.mount =/= MountId ->
            {reply, [PlayerStatus, 3, 0, 0], PlayerId};
        true ->
            GoodsStatus = gen_server:call(PlayerStatus#player_status.goods_pid, {'STATUS'}),
            case length(GoodsStatus#goods_status.null_cells) =:= 0 of
                %% 背包已满
                true ->
                    {reply, [PlayerStatus, 4, 0, 0], PlayerId};
                false ->
                    case (catch lib_mount:get_off(PlayerStatus, GoodsStatus, MountInfo)) of
                        {ok, NewPlayerStatus, NewGoodsStatus, Cell} ->
                            ok = gen_server:call(PlayerStatus#player_status.goods_pid, {'SET_STATUS', NewGoodsStatus}),
                            {reply, [NewPlayerStatus, 1, MountInfo#goods.goods_id, Cell], PlayerId};
                        Error ->
                            ?DEBUG("mod_mount get_off:~p", [Error]),
                            {reply, [PlayerStatus, 0, 0, 0], PlayerId}
                    end
            end
    end;

%% 丢弃坐骑
handle_call({'throw_away', PlayerStatus, MountId}, _From, PlayerId) ->
    MountInfo = lib_mount:get_info(MountId),
    case is_record(MountInfo, goods) of
        %% 坐骑不存在
        false ->
            {reply, 2, PlayerId};
        %% 坐骑类型不正确
        true when MountInfo#goods.type =/= 31 ->
            {reply, 3, PlayerId};
        %% 正在乘着，不能丢弃
        true when PlayerStatus#player_status.mount =:= MountId ->
            {reply, 4, PlayerId};
        true ->
            GoodsStatus = gen_server:call(PlayerStatus#player_status.goods_pid, {'STATUS'}),
            case (catch lib_mount:throw_away(GoodsStatus, MountInfo)) of
                {ok, NewGoodsStatus} ->
                    ok = gen_server:cast(PlayerStatus#player_status.goods_pid, {'SET_STATUS', NewGoodsStatus}),
                    {reply, 1, PlayerId};
                Error ->
                    ?DEBUG("mod_mount throw_away:~p", [Error]),
                    {reply, 0, PlayerId}
            end
    end;

handle_call(_Reason , _From, PlayerId) ->
    {reply, ok, PlayerId}.

handle_info(_Reason, PlayerId) ->
    {noreply, PlayerId}.

terminate(_Reason, _PlayerId) ->
    ok.

code_change(_OldVsn, PlayerId, _Extra)->
    {ok, PlayerId}.
