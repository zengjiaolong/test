%%%--------------------------------------
%%% @Module  : pp_mount
%%% @Author  : xhg
%%% @Email   : xuhuguang@jieyou.com
%%% @Created : 2010.06.02
%%% @Description:  坐骑操作
%%%--------------------------------------

-module(pp_mount).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").


%% 查询坐骑详细信息
handle(16001, PlayerStatus, MountId) ->
    [Res, MountTypeId, BindState, UseState] = gen_server:call(PlayerStatus#player_status.mount_pid, {'info', PlayerStatus, MountId}),
    {ok, BinData} = pt_16:write(16001, [Res, MountId, MountTypeId, BindState, UseState]),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

%% 乘上坐骑
handle(16002, PlayerStatus, MountId) ->
    [NewPlayerStatus, Res, OldMountId, OldMountTypeId, OldMountCell, MountTypeId] = gen_server:call(PlayerStatus#player_status.mount_pid, {'get_on', PlayerStatus, MountId}),
    {ok, BinData} = pt_16:write(16002, [Res, MountId, OldMountId, OldMountTypeId, OldMountCell, NewPlayerStatus#player_status.speed]),
    lib_send:send_one(NewPlayerStatus#player_status.socket, BinData),
    %% 广播
    {ok, BinData1} = pt_12:write(12010, [NewPlayerStatus#player_status.id, NewPlayerStatus#player_status.speed, MountTypeId]),
    lib_send:send_to_area_scene(NewPlayerStatus#player_status.scene, NewPlayerStatus#player_status.x, NewPlayerStatus#player_status.y, BinData1),
    {ok, NewPlayerStatus};

%% 离开坐骑
handle(16003, PlayerStatus, MountId) ->
    [NewPlayerStatus, Res, MountTypeId, MountCell] = gen_server:call(PlayerStatus#player_status.mount_pid, {'get_off', PlayerStatus, MountId}),
    {ok, BinData} = pt_16:write(16003, [Res, MountId, MountTypeId, MountCell, NewPlayerStatus#player_status.speed]),
    lib_send:send_one(NewPlayerStatus#player_status.socket, BinData),
    %% 广播
    {ok, BinData1} = pt_12:write(12010, [NewPlayerStatus#player_status.id, NewPlayerStatus#player_status.speed, 0]),
    lib_send:send_to_area_scene(NewPlayerStatus#player_status.scene, NewPlayerStatus#player_status.x, NewPlayerStatus#player_status.y, BinData1),
    {ok, NewPlayerStatus};

%% 丢弃坐骑
handle(16004, PlayerStatus, MountId) ->
    Res = gen_server:call(PlayerStatus#player_status.mount_pid, {'throw_away', PlayerStatus, MountId}),
    {ok, BinData} = pt_16:write(16004, [Res, MountId]),
    lib_send:send_one(PlayerStatus#player_status.socket, BinData);

handle(_Cmd, _Status, _Data) ->
    ?DEBUG("pp_goods no match", []),
    {error, "pp_goods no match"}.
