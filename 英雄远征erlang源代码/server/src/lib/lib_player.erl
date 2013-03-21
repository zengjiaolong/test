%%%--------------------------------------
%%% @Module  : lib_player
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.05.10
%%% @Description:角色相关处理
%%%--------------------------------------
-module(lib_player).
-export([
        is_online/1,
        get_info_from_mysql/1,
        get_role_id_by_name/1,
        is_exists/1,
        add_exp/2,
        add_coin/2,
        refresh_client/1,
        refresh_client/2,
        next_lv_exp/1,
        get_online_info/1,
        get_user_info_by_id/1,
        is_accname_exists/1,
        one_to_two/4,
        count_player_attribute/1,
        refresh_spirit/2,
        send_attribute_change_notify/2,
        player_die/2
    ]).
-include("common.hrl").
-include("record.hrl").

%% 检测某个角色是否在线
is_online(Pid) ->
    case ets:lookup(?ETS_ONLINE, Pid) of
        [] -> false;
        _Other -> true
    end.

%% 从mysql数据库读取角色信息
get_info_from_mysql(Pid) ->
    db_sql:get_row(io_lib:format(<<"select id, accid, accname, nickname, sex, lv, career from player where id=~p limit 1">>, [Pid])).

%% 根据角色名称查找ID
get_role_id_by_name(Name) ->
    Sql = io_lib:format(<<"select id from player where nickname = '~s' limit 1">>, [Name]),
    db_sql:get_one(Sql).

%% 检测指定名称的角色是否已存在
is_accname_exists(AccName) ->
    Sql = io_lib:format(<<"select id from player where accname = '~s' limit 1">>, [AccName]),
    case db_sql:get_one(Sql) of
        null -> false;
        _Other -> true
    end.

%% 读取角色基础属性
%get_info_for_att(Pid) ->
%    db_sql:get_row(io_lib:format(<<"select hp_lim, mp_lim, att, def, hit, dodge, crit, ten, forza, agile, wit from player where id=~p limit 1">>, [Pid])).

%% 检测指定名称的角色是否已存在
is_exists(Name) ->
    case get_role_id_by_name(Name) of
        null -> false;
        _Other -> true
    end.

%% 取得在线角色的角色状态
get_online_info(Id) ->
    case ets:lookup(?ETS_ONLINE, Id) of
        [] -> [];
        [R] ->
            case is_process_alive(R#ets_online.pid) of
                true -> R;
                false ->
                    ets:delete(?ETS_ONLINE, Id),
                    []
            end
    end.

%% 增加人物经验
add_exp(Status, Exp) ->
    Exp1 = Status#player_status.exp + Exp,
    NextLvExp = next_lv_exp(Status#player_status.lv),
    if
        NextLvExp > Exp1 ->  %% 未升级
            {ok, BinData} = pt_13:write(13002, Exp1),
            lib_send:send_one(Status#player_status.socket, BinData),
            Sql = io_lib:format(<<"update player set exp=~p,hp=~p,mp=~p where id=~p">>, [Exp1, Status#player_status.hp, Status#player_status.mp, Status#player_status.id]),
            db_sql:execute(Sql),
            Status#player_status{
                exp = Exp1
            };
        true -> %% 已升级
            Exp2 = Exp1 - NextLvExp,
            Lv = Status#player_status.lv + 1,
            %% 职业收益
            [Forza0, Agile0, Wit0] = case Status#player_status.lv > 10 of
                true ->
                    case Status#player_status.career of
                        1 -> [1.4, 0.9, 0.7]; %% 战士
                        2 -> [0.7, 0.9, 1.4]; %% 法师
                        _ -> [1.1, 1.5, 0.4]  %% 刺客
                    end;
                false ->
                    [1,1,1]
            end,
            Forza1 = Forza0 + Status#player_status.forza,
            Agile1 = Agile0 + Status#player_status.agile,
            Wit1 = Wit0 + Status#player_status.wit,
            Status1 = Status#player_status{
                exp = Exp2,
                lv = Lv,
                forza = round(Forza1),
                agile = round(Agile1),
                wit = round(Wit1)
            },
            %% 人物属性计算
            NewStatus = count_player_attribute(Status1),

            Sql = io_lib:format(<<"update player set forza=~p,agile=~p,wit=~p,exp=~p,lv=~p,hp=~p,mp=~p where id=~p">>, 
                            [Forza1, Agile1, Wit1, Exp2, Lv, NewStatus#player_status.hp, NewStatus#player_status.mp, NewStatus#player_status.id]),
            db_sql:execute(Sql),

            NextLvExp1  = next_lv_exp(NewStatus#player_status.lv),
            {ok, BinData} = pt_13:write(13003, [NewStatus#player_status.hp_lim, NewStatus#player_status.mp_lim, NewStatus#player_status.lv, NewStatus#player_status.exp, NextLvExp1]),
            lib_send:send_one(NewStatus#player_status.socket, BinData),
            %% 更新帮派成员缓存
            lib_guild:role_upgrade(NewStatus#player_status.id, Lv),
            %% 更新好友缓存
            lib_relationship:set_ets_rela_info_lv(NewStatus#player_status.id, Lv),
            NewStatus
    end.

%% 增加铜币
add_coin(R, 0) -> R;
add_coin(R, Num) ->
    C = R#player_status.coin + Num,
    R#player_status{coin=C}.

%% 刷新客户端
refresh_client(Id, S) when is_integer(Id)  ->
    {ok, BinData} = pt_13:write(13005, S),
    lib_send:send_to_uid(Id, BinData).
%%或新人物信息
refresh_client(Ps) ->
    refresh_client(Ps#player_status.id, 1).

%% 更新客户端
refresh_spirit(Socket, Spr) ->
    {ok, BinData} = pt_13:write(13006, Spr),
    lib_send:send_one(Socket, BinData).

%% 经验
next_lv_exp(Lv) ->
    data_exp:get(Lv).

%% 获取地址玩家信息
get_user_info_by_id(Id) ->
    case get_online_info(Id) of
        [] -> [];
        Data ->
             case catch gen:call(Data#ets_online.pid, '$gen_call', 'PLAYER', 2000) of
                 {'EXIT',_Reason} ->
                     ets:delete(?ETS_ONLINE, Id),
                     [];
                 {ok, Player} ->
                     Player
             end
    end.

%% 一级属性转化为二级属性
one_to_two(Forza, Agile, Wit, Career) ->
    %% 职业收益
    [HpY, MpY, AttY, DefY, HitY, DodgeY, CritY, TenY] = case Career of
        1 -> [8.5, 3, 1.25, 1.05, 0.14, 0.165, 0.03, 0.08]; %% 战士
        2 -> [7, 3.1, 1.7, 0.75, 0.62, 0.14, 0.08, 0.08]; %% 法师
        _ -> [6.4, 2, 1.6, 0.75, 0.24, 0.38, 0.12, 0.08]  %% 刺客
    end,
    Hp = round(Forza * 8 * HpY),
    Mp = round(Wit * 6 * MpY),
    Att = round((Forza * 10 + Wit*10) * AttY),
    Def = round((Forza * 6 + Agile*12 + Wit*6) * DefY),
    Hit = round(Agile * 8 * HitY),
    Dodge = round((Forza * 2 + Agile*4 + Wit*2) * DodgeY),
    Crit = round(Agile * 1 * CritY + 10),
    Ten = round(Wit * 1 * TenY + 20),
    [Hp, Mp, Att, Def, Hit, Dodge, Crit, Ten].

%% 人物属性计算
count_player_attribute(PlayerStatus) ->
    %% 人物一级属性
    [Forza, Wit, Agile] = [PlayerStatus#player_status.forza, PlayerStatus#player_status.wit, PlayerStatus#player_status.agile],
    %% 宠物一级属性
    [PetForza, PetWit, PetAgile] = PlayerStatus#player_status.pet_attribute,
    %% 原始二级属性
    [Hp, Mp, Att, Def, Hit, Dodge, Crit, Ten] = PlayerStatus#player_status.base_attribute,
    %% 一级属性转化为二级属性
    [Hp1, Mp1, Att1, Def1, Hit1, Dodge1, Crit1, Ten1] = lib_player:one_to_two(Forza+PetForza, Agile+PetAgile, Wit+PetWit, PlayerStatus#player_status.career),
    %% 装备属性加成
    [Hp2, Mp2, Att2, Def2, Hit2, Dodge2, Crit2, Ten2] = PlayerStatus#player_status.equip_attribute,
    %% 属性计算
    NewHp = case PlayerStatus#player_status.hp > Hp+Hp1+Hp2 of
                true -> Hp+Hp1+Hp2;
                false -> PlayerStatus#player_status.hp
           end,
    NewMp = case PlayerStatus#player_status.mp > Mp+Mp1+Mp2 of
                true -> Mp+Mp1+Mp2;
                false -> PlayerStatus#player_status.mp
           end,
    NewPlayerStatus = PlayerStatus#player_status {
                                hp = NewHp,
                                mp = NewMp,
                                hp_lim = Hp + Hp1 + Hp2,
                                mp_lim = Mp + Mp1 + Mp2,
                                att = Att + Att1 + Att2,
                                def = Def + Def1 + Def2,
                                hit = Hit + Hit1 + Hit2,
                                dodge = Dodge + Dodge1 + Dodge2,
                                crit = Crit + Crit1 + Crit2,
                                ten = Ten + Ten1 + Ten2,
                                two_attribute = [Hp1, Mp1, Att1, Def1, Hit1, Dodge1, Crit1, Ten1]
                    },
    NewPlayerStatus.
    
send_attribute_change_notify(Status, ChangeReason) ->
    ExpLimit = next_lv_exp(Status#player_status.lv),
    {ok, BinData} = pt_13:write(13011, [Status#player_status.id, ChangeReason, Status#player_status.lv, Status#player_status.exp, ExpLimit, Status#player_status.forza, Status#player_status.agile, Status#player_status.wit, Status#player_status.hp, Status#player_status.hp_lim, Status#player_status.mp, Status#player_status.mp_lim, Status#player_status.att, Status#player_status.def, Status#player_status.hit, Status#player_status.dodge, Status#player_status.crit, Status#player_status.ten]),
    lib_send:send_one(Status#player_status.socket, BinData).

%% 玩家死亡处理
%% 当前自己的状态
%% 杀死你的玩家进程
player_die(NewStatus, Pid) ->
    %%宠物
    lib_pet:handle_role_dead(NewStatus),
    case is_pid(Pid) of
        true ->
            %% 如果玩家杀加入仇人
            case catch gen:call(Pid, '$gen_call', 'PLAYER') of
                {'EXIT', _} ->
                    none;
                {ok, Player} ->
                    pp_relationship:handle(14005, NewStatus, Player#player_status.id)
            end;
        false ->
            ok
    end.
