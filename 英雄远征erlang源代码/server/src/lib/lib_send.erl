%%%-----------------------------------
%%% @Module  : lib_send
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.05.05
%%% @Description: 发送消息
%%%-----------------------------------
-module(lib_send).
-include("record.hrl").
-include("common.hrl").

-export([
        send_one/2,
        send_to_sid/2,
        send_to_all/1,
        send_to_local_all/1,
        send_to_nick/2,
        send_to_uid/2,
        send_to_scene/2,
        send_to_area_scene/4,
        send_to_guild/2,
        send_to_team/3,
        rand_to_process/1
       ]).

%%发送信息给指定socket玩家.
%%Pid:游戏逻辑ID
%%Bin:二进制数据.
send_one(S, Bin) ->
    gen_tcp:send(S, Bin).

%%发送信息给指定sid玩家.
%%Sid:游戏逻辑ID
%%Bin:二进制数据.
send_to_sid(S, Bin) ->
    rand_to_process(S) ! {send, Bin}.

%%发送信息给指定玩家名.
%%Nick:名称
%%Bin:二进制数据.
send_to_nick(Nick, Bin) ->
   L = ets:match(?ETS_ONLINE, #ets_online{sid='$1', nickname = Nick, _='_'}),
   do_broadcast(L, Bin).

%%发送信息给指定玩家ID.
%%Uid:玩家ID
%%Bin:二进制数据.
send_to_uid(Uid, Bin) ->
    case ets:lookup(?ETS_ONLINE, Uid) of
        [] -> skip;
        [Player] -> send_to_sid(Player#ets_online.sid, Bin)
    end.

%%发送信息到情景
%%Q:场景ID
%%Bin:数据
send_to_scene(Q, Bin) ->
    L = ets:match(?ETS_ONLINE, #ets_online{sid='$1', scene = Q, _='_'}),
    do_broadcast(L, Bin).

%%发送信息到帮派
%%Q:帮派ID
%%Bin:数据
send_to_guild(Q, Bin) ->
    if (Q > 0) ->
            L = ets:match(?ETS_ONLINE, #ets_online{sid='$1',  guild_id= Q, _='_'}),
            do_broadcast(L, Bin);
        true -> 
            void
    end.

%%发送信息到组队
%%Sid:游戏逻辑ID
%%TeamId:组队ID
%%Bin:数据
send_to_team(Sid, TeamId, Bin) ->
    if (TeamId > 0) ->
            L = ets:match(?ETS_ONLINE, #ets_online{sid='$1',  pid_team=TeamId, _='_'}),
            do_broadcast(L, Bin);
        true ->
            send_to_sid(Sid, Bin)
    end.

%%发送信息到情景(9宫格区域，不是整个场景)
%%Q:场景ID
%%X,Y坐标
%%Bin:数据
send_to_area_scene(Q, X2, Y2, Bin) ->
    AllUser = ets:match(?ETS_ONLINE, #ets_online{sid = '$1',x = '$2', y='$3', scene = Q, _='_'}),
    XY2 = lib_scene:get_xy(X2, Y2),
    F = fun([Sid, X, Y]) ->
        XY = lib_scene:get_xy(X, Y),
        if
            XY == XY2 orelse XY == XY2 + 1 orelse XY == XY2 -1 orelse XY == XY2 -8 orelse XY == XY2 +8 orelse XY == XY2 -9 orelse XY == XY2 +9 orelse XY == XY2 -7  orelse XY == XY2+7 ->
                send_to_sid(Sid, Bin);
            true->
                ok
        end
    end,
    [F([Sid, X, Y]) || [Sid, X, Y] <- AllUser].
    
%% 发送信息到世界
send_to_all(Bin) ->
    send_to_local_all(Bin),
    mod_disperse:broadcast_to_world(ets:tab2list(?ETS_SERVER), Bin).

send_to_local_all(Bin) ->
    L = ets:match(?ETS_ONLINE, #ets_online{sid='$1', _='_'}),
    do_broadcast(L, Bin).

%% 对列表中的所有socket进行广播
do_broadcast(L, Bin) ->
    F = fun([S]) ->
        send_to_sid(S, Bin)
    end,
    [F(D) || D <- L].

rand_to_process(S) ->
    {_,_,R} = erlang:now(),
    Rand = R div 1000 rem ?SEND_MSG + 1,
    lists:nth(Rand, S).