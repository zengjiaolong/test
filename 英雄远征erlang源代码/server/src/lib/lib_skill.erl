%%%-----------------------------------
%%% @Module  : lib_skill
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.07.27
%%% @Description: 技能
%%%-----------------------------------
-module(lib_skill).
-include("common.hrl").
-include("record.hrl").
-export(
    [
        get_all_skill/1,
        upgrade_skill/2
    ]
).

%% 获取所有技能
get_all_skill(Id) ->
    Data = db_sql:get_all(io_lib:format(<<"select skill_id, lv  from skill where id = ~p">>, [Id])),
    if
        Data == [] ->
            [];
        true ->
            [list_to_tuple(D) || D <- Data]
    end.

%% 升级技能
upgrade_skill(Status, SkillId) ->
    case lists:member(SkillId, data_skill:get_ids(Status#player_status.career)) of
        true ->
            [Data, Lv0, Type] = case lists:keyfind(SkillId, 1, Status#player_status.skill) of
                false -> %% 还没学习过
                    [data_skill:get(SkillId, 1), 1, 0];
                {_, Lv} -> %% 学习了，升级
                    [data_skill:get(SkillId, Lv+1), Lv+1, 1]
            end,
            case Data#ets_skill.data of
                [] ->
                    {ok, BinData} = pt_21:write(21001, [0, <<"当前已经是最高等级了">>]),
                    lib_send:send_one(Status#player_status.socket, BinData),
                    {ok, Status};
                _ ->
                    [{condition, Condition} | T] = Data#ets_skill.data,
                    case check_upgrade(Status, Condition, 0) of
                        {true, C} ->
                            case Type =:= 0 of
                                true ->
                                    db_sql:execute(io_lib:format(<<"insert into skill set id = ~p, skill_id = ~p, lv = ~p ">>, [Status#player_status.id, SkillId, Lv0]));
                                false ->
                                    db_sql:execute(io_lib:format(<<"update skill set lv = ~p where id = ~p and skill_id = ~p">>, [Lv0, Status#player_status.id, SkillId]))
                            end,

                            %% 被动技能属性加成
                            case Data#ets_skill.type =:= 2 of
                                true ->
                                    case T of
                                        [{att, D1}, {mp, D2}] ->
                                            db_sql:execute(io_lib:format(<<"update `player` set att = att + ~p, mp = mp + ~p where id = ~p ">>, [D1, D2,Status#player_status.id]));
                                        [{crit, D}] ->
                                            db_sql:execute(io_lib:format(<<"update `player` set crit = crit + ~p where id = ~p ">>, [D, Status#player_status.id]));
                                        [{hp, D}] ->
                                            db_sql:execute(io_lib:format(<<"update `player` set hp_lim = hp_lim + ~p where id = ~p ">>, [D, Status#player_status.id]))
                                    end;
                                false ->
                                    skip
                            end,

                            {ok, BinData} = pt_21:write(21001, [1, <<>>]),
                            lib_send:send_one(Status#player_status.socket, BinData),
                            SkillList = lists:keydelete(SkillId, 1, Status#player_status.skill),
                            Status1 = Status#player_status{coin = Status#player_status.coin - C, skill = [{SkillId, Lv0}|SkillList]},
                            {ok, Status1};
                        {false, Msg} ->
                            {ok, BinData} = pt_21:write(21001, [0, Msg]),
                            lib_send:send_one(Status#player_status.socket, BinData),
                            {ok, Status}
                    end
            end;
        false ->
            {ok, BinData} = pt_21:write(21001, [0, <<"当前技能不存在！">>]),
            lib_send:send_one(Status#player_status.socket, BinData),
            {ok, Status}
    end.

%% 逐个检查进入需求
check_upgrade(_, [], C) ->
    {true, C};
check_upgrade(Status, [{K, V} | T], C) ->
    case K of
        lv -> %% 等级需求
            case Status#player_status.lv < V of
                true ->
                    Msg = "等级不足"++integer_to_list(V)++"级",
                    {false, list_to_binary(Msg)};
                false ->
                    check_upgrade(Status, T, C)
            end;
        coin -> %% 铜币需求
            case Status#player_status.coin < V of
                true ->
                    Msg = "铜币不足"++integer_to_list(V),
                    {false, list_to_binary(Msg)};
                false ->
                    check_upgrade(Status, T, V)
            end;
        _ ->
            check_upgrade(Status, T, C)
    end;
check_upgrade(Status, [{_, Id, Lv} | T], C) ->
    %%技能需求
    case Id > 0 andalso Lv > 0 of
        true ->
            case lists:keyfind(Id, 1, Status#player_status.skill) of
                false ->
                    {false, <<"前置条件不足">>};
                {_, Lv0} ->
                    if
                        Lv0 >= Lv ->
                            check_upgrade(Status, T, C);
                        true ->
                            {false, <<"前置条件不足">>}
                    end
            end;
        false ->
            check_upgrade(Status, T, C)
    end.
