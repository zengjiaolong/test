%%%--------------------------------------
%%% @Module  : pp_battle
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.05.19
%%% @Description: 战斗
%%%--------------------------------------
-module(pp_battle).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%%发动攻击 - 玩家VS怪
handle(20001, Status, [Id, Sid]) ->
    case ets:lookup(?ETS_MON, Id) of
        [] ->
            skip;
        [Mon] ->
            case Status#player_status.hp > 0 andalso Mon#ets_mon.hp > 0 of
                true ->
                    case mod_battle:battle(Status#player_status.bid, [Status, Mon, Sid]) of
                        none ->
                            ok;
                        Aer ->
                            {ok, Aer}
                    end;
                false ->
                    BData = [
                            2, Status#player_status.id, Status#player_status.hp, Status#player_status.x, Status#player_status.y,
                            1, Mon#ets_mon.id, Mon#ets_mon.hp, Mon#ets_mon.x, Mon#ets_mon.y
                        ],
                    mod_battle:battle_fail(1, BData, Status#player_status.socket)
            end
    end;

%%发动攻击 - 玩家VS玩家
%%Id:玩家ID
%%Sid:玩家技能id
handle(20002, Status, [Id, Sid]) ->
    case Status#player_status.id == Id of
        true ->
            case Status#player_status.hp > 0 of
                true ->
                    case  mod_battle:battle(Status#player_status.bid, [Status, Status, Sid]) of
                        none ->
                            ok;
                        Aer ->
                            {ok, Aer}
                    end;
                false ->
                    BData = [
                            2, Status#player_status.id, Status#player_status.hp, Status#player_status.x, Status#player_status.y,
                            2, Status#player_status.id, Status#player_status.hp, Status#player_status.x, Status#player_status.y
                        ],
                    mod_battle:battle_fail(1, BData, Status#player_status.socket)
            end;
        false->
            case ets:lookup(?ETS_ONLINE, Id) of
                [] ->
                    skip;
                [Data] ->
                    case lib_scene:is_safe(Data#ets_online.scene, [Data#ets_online.x, Data#ets_online.y]) of
                        false ->
                            case catch gen:call(Data#ets_online.pid, '$gen_call', 'PLAYER', 2000) of
                                {'EXIT',_Reason} ->
                                    {ok, BinData} = pt_12:write(12004, Id),
                                    lib_send:send_to_scene(Status#player_status.scene, BinData),
                                    %%删除ETS记录
                                    ets:delete(?ETS_ONLINE, Id),
                                    ok;
                                {ok, Player} ->
                                    case Status#player_status.hp > 0 andalso Player#player_status.hp > 0 of
                                        true ->
                                            case  mod_battle:battle(Status#player_status.bid, [Status, Player, Sid]) of
                                                none ->
                                                    ok;
                                                Aer ->
                                                    {ok, Aer}
                                            end;
                                        false ->
                                            BData = [
                                                    2, Status#player_status.id, Status#player_status.hp, Status#player_status.x, Status#player_status.y,
                                                    2, Player#player_status.id, Player#player_status.hp, Player#player_status.x, Player#player_status.y
                                                ],
                                            mod_battle:battle_fail(1, BData, Status#player_status.socket)
                                    end
                            end;
                        true ->
                            none
                            %mod_battle:battle_fail(2, Data#ets_online.id, Status#player_status.socket, 1)
                    end
            end
    end;

%%复活
handle(20004, Status, _D) ->
    case ets:lookup(?ETS_SCENE, Status#player_status.scene) of
        [] ->
            Status1 = Status#player_status{
                hp = Status#player_status.hp_lim,
                mp = Status#player_status.mp_lim
            };
        [Scene] ->
            Status1 = Status#player_status{
                hp = Status#player_status.hp_lim,
                mp = Status#player_status.mp_lim,
                x = Scene#ets_scene.x,
                y = Scene#ets_scene.y
            }
    end,
    %通知离开原来场景
    lib_scene:revive_to_scene(Status, Status1),
    {ok, Status1};


%%发动辅助技能
%%Id:玩家ID
%%Sid:玩家技能id
handle(20006, Status, [Id, Sid]) ->
    case Status#player_status.id == Id of
        true ->
            mod_battle:assist_skill(Status#player_status.bid, [Status, {}, Sid]);
        false ->
            case ets:lookup(?ETS_ONLINE, Id) of
                [] ->
                    skip;
                [Data] ->
                    case catch gen:call(Data#ets_online.pid, '$gen_call', 'PLAYER', 2000) of
                        {'EXIT',_Reason} ->
                            {ok, BinData} = pt_12:write(12004, Id),
                            lib_send:send_to_scene(Status#player_status.scene, BinData),
                            %%删除ETS记录
                            ets:delete(?ETS_ONLINE, Id),
                            ok;
                        {ok, Player} ->
                            case Status#player_status.hp > 0 andalso Player#player_status.hp > 0 of
                                true ->
                                    mod_battle:assist_skill(Status#player_status.bid, [Status, Player, Sid]);
                                false ->
                                    skip
                                    %mod_battle:battle_fail(2, Player#player_status.id, Status#player_status.socket, 1)
                            end
                    end
            end
    end;

handle(_Cmd, _Status, _Data) ->
    {error, "pp_battle no match"}.
