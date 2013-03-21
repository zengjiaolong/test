%%%--------------------------------------
%%% @Module  : pp_player
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.05.12
%%% @Description:  角色功能管理
%%%--------------------------------------
-module(pp_player).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%%查询当前玩家信息
handle(13001, Status, _) ->
    Exp = lib_player:next_lv_exp(Status#player_status.lv),
    {ok, BinData} = pt_13:write(13001, [
            Status#player_status.scene,
            Status#player_status.x,
            Status#player_status.y,
            Status#player_status.id,
            Status#player_status.hp,
            Status#player_status.hp_lim,
            Status#player_status.mp,
            Status#player_status.mp_lim,
            Status#player_status.sex,
            Status#player_status.lv,
            Status#player_status.exp,
            Exp,
            Status#player_status.career,
            Status#player_status.nickname,
            Status#player_status.att,
            Status#player_status.def,
            Status#player_status.forza,
            Status#player_status.agile,
            Status#player_status.wit,
            Status#player_status.hit,
            Status#player_status.dodge,
            Status#player_status.crit,
            Status#player_status.ten,
            Status#player_status.guild_id,
            Status#player_status.guild_name,
            Status#player_status.guild_position,
            Status#player_status.realm,
            Status#player_status.gold,
            Status#player_status.silver,
            Status#player_status.coin,
            Status#player_status.att_area,
            Status#player_status.spirit,
            Status#player_status.speed,
            Status#player_status.att_speed,
            Status#player_status.equip_current
        ]),
    lib_send:send_one(Status#player_status.socket, BinData),
    ok;

%%查询其他玩家信息
handle(13004, Status, Id) ->
    case Id =/= Status#player_status.id of
        true ->
            case lib_player:get_user_info_by_id(Id) of
                 [] -> ok;
                 UserStatus ->
                    {ok, BinData} = pt_13:write(13004, [
                            UserStatus#player_status.id,
                            UserStatus#player_status.hp,
                            UserStatus#player_status.hp_lim,
                            UserStatus#player_status.mp,
                            UserStatus#player_status.mp_lim,
                            UserStatus#player_status.sex,
                            UserStatus#player_status.lv,
                            UserStatus#player_status.career,
                            UserStatus#player_status.nickname,
                            UserStatus#player_status.att,
                            UserStatus#player_status.def,
                            UserStatus#player_status.forza,
                            UserStatus#player_status.agile,
                            UserStatus#player_status.wit,
                            UserStatus#player_status.hit,
                            UserStatus#player_status.dodge,
                            UserStatus#player_status.crit,
                            UserStatus#player_status.ten,
                            UserStatus#player_status.guild_id,
                            UserStatus#player_status.guild_name,
                            UserStatus#player_status.guild_position,
                            UserStatus#player_status.realm,
                            UserStatus#player_status.spirit
                        ]),
                    lib_send:send_one(Status#player_status.socket, BinData)
            end;
        false ->
            skip
    end;

%%请求快捷栏
handle(13007, Status, _) ->
    {ok, BinData} = pt_13:write(13007, Status#player_status.quickbar),
    lib_send:send_one(Status#player_status.socket, BinData);

%%保存快捷栏
handle(13008, Status, [T, S, Id]) ->
    {ok, BinData} = pt_13:write(13008, 1),
    lib_send:send_one(Status#player_status.socket, BinData),
    Quickbar = save_quickbar([T, S, Id], Status#player_status.quickbar),
    Status1 = Status#player_status{quickbar= Quickbar},
    {ok, Status1};

%%删除快捷栏
handle(13009, Status, T) ->
    {ok, BinData} = pt_13:write(13009, 1),
    lib_send:send_one(Status#player_status.socket, BinData),
    Quickbar = delete_quickbar(T, Status#player_status.quickbar),
    Status1 = Status#player_status{quickbar= Quickbar},
    {ok, Status1};

%%替换快捷栏
handle(13010, Status, [T1, T2]) ->
    {ok, BinData} = pt_13:write(13010, 1),
    lib_send:send_one(Status#player_status.socket, BinData),
    Quickbar = replace_quickbar(T1, T2,  Status#player_status.quickbar),
    Status1 = Status#player_status{quickbar= Quickbar},
    {ok, Status1};

handle(_Cmd, _Status, _Data) ->
    ?DEBUG("pp_player no match", []),
    {error, "pp_player no match"}.

%% ---------------快捷栏-----------------

%%删除指定位置的快捷栏
save_quickbar([T, S, Id], Q) ->
    case lists:keyfind(T, 1, Q) of
        false ->
            [{T, S, Id} | Q];
        _ -> 
            Q1 = lists:keydelete(T, 1, Q),
            [{T, S, Id} | Q1]
    end.

%%删除指定位置的快捷栏
delete_quickbar(T, Q) ->
    case lists:keyfind(T, 1, Q) of
        false ->
            Q;
        _ ->
            lists:keydelete(T, 1, Q)
    end.

%%删除指定位置的快捷栏
replace_quickbar(T1, T2,  Q) ->
    case lists:keyfind(T1, 1, Q) of
        false -> %T1没有物品
            Q;
        {_ , S1, Id1} ->
            Q1 = lists:keydelete(T2, 1, Q),
            Q2 = lists:keydelete(T1, 1, Q1),
            case lists:keyfind(T2, 1, Q) of
                false -> %T2没有物品
                    [{T2, S1, Id1} | Q2];
                {_, S2, Id2} ->
                    [{T2, S1, Id1}, {T1, S2, Id2} | Q2]
            end
    end.
%% -------------------快捷栏结束------------------