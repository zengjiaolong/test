%%%------------------------------------
%%% @Module  : mod_battle
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.05.18
%%% @Description: 战斗
%%%------------------------------------
-module(mod_battle).
-behaviour(gen_server).
-export([
        start_link/0,
        battle_fail/3,
        battle/2,
        assist_skill/2
    ]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-include("common.hrl").
-include("record.hrl").

%%战斗所需的属性
-record(battle_status, {
         id,
         name,
         scene,           %%所属场景
         lv, 
         hp, 
         hp_lim,
         mp, 
         mp_lim, 
         retime,          %% 回血回魔间隔时间
         att,             %% 攻击力
         def,             %% 防御值
         x,               %% 默认出生X
         y,               %% 默认出生y
         att_area,        %% 攻击范围  
         sid = none,      %% 玩家进程
         bid = none,      %% 战斗进程
         battle_status = [],      %% 战斗状态
         sign = 0,        %% 标示是怪还是人 1:怪， 2：人
         hit = 0,
         dodge = 0,
         crit = 0,
         ten = 0,
         hurt_add = 0,    %% 加伤害
         hurt_del = 0,    %% 减伤害
         ftsh = 0,        %% 反弹伤害
         shield = 0,      %% 法盾
         skill
    }).
-record(state, {
        last_attack_time=0,   % 上次出手时间
        last_skill_time = []  % [{技能id,上次时间}]
}).

%%启动战斗进程
start_link() ->
    gen_server:start_link(?MODULE, [], []).

%% 发起战斗
battle(Pid, Data) ->
    case catch gen:call(Pid, '$gen_call', {'BATTLE', Data}, 2000) of
        {'EXIT',_Reason} ->
            none;
        {ok, BackData} ->
            BackData
    end.

%% 发动辅助技能
assist_skill(Pid, Data) ->
    gen_server:call(Pid, {assist_skill, Data}).

init([]) ->
    State = #state{},
    {ok, State}.

handle_cast(_R , State) ->
    {noreply, State}.

%%战斗
handle_call({'BATTLE', [Aer, Der, Sid]} , _FROM, State) ->
    if
        is_record(Aer, player_status) ->
            Time = util:longunixtime()+50,
            [Return, State1] = case Time - State#state.last_attack_time >= Aer#player_status.att_speed of %%限制出手频率
                true ->
                    start([Aer, Der, Sid, State]);
                false ->
                    %battle_fail(2, Aer#player_status.id, Aer#player_status.socket, 2),
                    [none, State]
            end,
            State2 = State1#state{last_attack_time = Time},
            {reply, Return, State2};
        true ->
            [Return, State1] = start([Aer, Der, Sid, State]),
            {reply, Return, State1}
    end;

%% 发动辅助技能
handle_call({assist_skill, [Aer, Der, Sid]} , _FROM, State) ->
    State1 = use_assist_skill([Aer, Der, Sid, State]),
    {reply, ok, State1};

handle_call(_R , _FROM, State) ->
    {reply, ok, State}.

%% 持续掉血
%%Data:次数，间隔时间，数值
handle_info({last_red_hp, Pid1, Pid2, Data}, State) ->
    [C, T, V] = Data,
    Pid1 ! {last_red_hp, V, Pid2},
    C1 = C - 1,
    case C1 > 0 of
        true ->
            Data1 = [C1, T, V],
            erlang:send_after(T*1000, self(), {last_red_hp, Pid1, Pid2, Data1});
        false ->
            ok
    end,
    {noreply, State};

handle_info(_Reason, State) ->
    {noreply, State}.

terminate(normal, _State) ->
    ok.

code_change(_OldVsn, State, _Extra)->
    {ok, State}.

%%---------------私有函数----------------

%%初始化战斗双方属性
init_data(Arr) ->
    if
        is_record(Arr, ets_mon) ->
            #battle_status{
                id = Arr#ets_mon.id,
                name = Arr#ets_mon.name,
                scene = Arr#ets_mon.scene,
                lv = Arr#ets_mon.lv,
                hp = Arr#ets_mon.hp,
                hp_lim = Arr#ets_mon.hp_lim,
                mp = Arr#ets_mon.mp,
                mp_lim = Arr#ets_mon.mp_lim,
                retime = 5000,
                att = Arr#ets_mon.att,
                def = Arr#ets_mon.def,
                x = Arr#ets_mon.x,
                y = Arr#ets_mon.y,
                att_area = Arr#ets_mon.att_area,
                sid = Arr#ets_mon.aid,
                hit = Arr#ets_mon.hit,
                dodge = Arr#ets_mon.dodge,
                crit = Arr#ets_mon.crit,
                ten = Arr#ets_mon.ten,
                skill = Arr#ets_mon.skill,
                battle_status = Arr#ets_mon.battle_status,
                bid = Arr#ets_mon.bid,
                sign = 1
            };
        is_record(Arr, player_status) ->
            #battle_status{
                id = Arr#player_status.id,
                name = Arr#player_status.nickname,
                scene = Arr#player_status.scene,
                lv = Arr#player_status.lv,
                hp = Arr#player_status.hp,
                hp_lim = Arr#player_status.hp_lim,
                mp = Arr#player_status.mp,
                mp_lim = Arr#player_status.mp_lim,
                retime = 5000,
                att = Arr#player_status.att,
                def = Arr#player_status.def,
                x = Arr#player_status.x,
                y = Arr#player_status.y,
                att_area = Arr#player_status.att_area,
                sid = Arr#player_status.pid,
                hit = Arr#player_status.hit,
                dodge = Arr#player_status.dodge,
                crit = Arr#player_status.crit,
                ten = Arr#player_status.ten,
                skill = Arr#player_status.skill,
                battle_status = Arr#player_status.battle_status,
                bid = Arr#player_status.bid,
                sign = 2
            };
        is_list(Arr) ->
            [Id, Att, Def, Hit, Dodge, Crit, Ten, Hp, Mp, Pid, Sign, BS] = Arr,
            #battle_status{
                id = Id,
                hp = Hp,
                mp = Mp,
                att = Att,
                def = Def,
                sid = Pid,
                hit = Hit,
                dodge = Dodge,
                crit = Crit,
                ten = Ten,
                battle_status = BS,
                sign = Sign
            }
    end.

%%开启一个战斗服务
start([Aer, Der, Sid, State])->
    Aer1 = init_data(Aer),
    Der1 = init_data(Der),
    attack([Aer1, Der1, Sid], [Aer, State]).

%回写
back_data(ArrInit, Arr) ->
    if
        Arr#battle_status.sign == 1->
            ArrInit#ets_mon{
                hp = Arr#battle_status.hp,
                mp = Arr#battle_status.mp
            };
        Arr#battle_status.sign == 2 ->
            ArrInit#player_status{
                hp = Arr#battle_status.hp,
                mp = Arr#battle_status.mp
            }
    end.
   
%% ===============处理战斗状态================

%%战斗准备就绪检查 - 能否发动有效攻击，否则对本次攻击进行MISS

%%进入战斗中
attack([Aer, Der, Sid], [AerInit, State]) ->
    {Sid1, Slv1} = case lists:keyfind(Sid, 1, Aer#battle_status.skill) of
        false ->
            {0, 0};
        {_, Lv} ->
            {Sid, Lv}
    end,
    case skill(Aer, Der, Sid1, Slv1, State) of
        att_area_out -> %% 攻击距离有误
            BData = [
                    Aer#battle_status.sign, Aer#battle_status.id, Aer#battle_status.hp, Aer#battle_status.x, Aer#battle_status.y,
                    Der#battle_status.sign, Der#battle_status.id, Der#battle_status.hp, Der#battle_status.x, Der#battle_status.y
                ],
            battle_fail(4, BData, AerInit#player_status.socket),
            save(Aer, [AerInit, State]);
        %mp_not_enough -> %% 蓝不足
        %    battle_fail(Aer#battle_status.sign, AerInit#player_status.id, AerInit#player_status.socket, 5),
        %    save(Aer, [AerInit, State]);
        false -> %%技能使用有误
            BData = [
                    Aer#battle_status.sign, Aer#battle_status.id, Aer#battle_status.hp, Aer#battle_status.x, Aer#battle_status.y,
                    Der#battle_status.sign, Der#battle_status.id, Der#battle_status.hp, Der#battle_status.x, Der#battle_status.y
                ],
            battle_fail(6, BData, AerInit#player_status.socket),
            save(Aer, [AerInit, State]);
        [{Aer1, X, Y, State1 , DefList}, Sid2] ->
            send_msg([Aer1#battle_status.id, Aer1#battle_status.hp, Aer1#battle_status.mp, Sid2, X, Y, DefList, Aer1#battle_status.sign, Aer1#battle_status.scene]),
            save(Aer1, [AerInit, State1]);
        [assist, State1] ->
            save(Aer, [AerInit, State1]);
         _ ->
            save(Aer, [AerInit, State])
    end.
    
%%保存数据
save(Aer, [AerInit, State]) ->
    %% 修改初始数据
    AerInit1 = back_data(AerInit, Aer),
    [AerInit1, State].

%%发送消息
send_msg([Id, Hp, Mp, Sid, X, Y, DefList, Sign, Q]) when Sign == 1 -> % 怪攻击
    {ok, BinData} = pt_20:write(20003, [Id, Hp, Mp, Sid, X, Y, DefList]),
    lib_send:send_to_scene(Q, BinData);
send_msg([Id, Hp, Mp, Sid, X, Y, DefList, Sign, Q]) when Sign == 2 -> % 人攻击
    {ok, BinData} = pt_20:write(20001, [Id, Hp, Mp, Sid, X, Y, DefList]),
    lib_send:send_to_scene(Q, BinData).

%%发送辅助技能信息
send_assist_msg(Id, Sid, MP, Q, List)->
    {ok, BinData} = pt_20:write(20006, [Id, Sid, MP, List]),
    lib_send:send_to_scene(Q, BinData).

%%---------------技能--------------
%% 使用主动技能
skill(Aer, Der, Sid, Lv, State) ->
    case data_skill:get(Sid, Lv) of
        [] ->
            [single_active_skill(Aer, Der, [], State), 0];
        SkillData ->
            %% 判断上次放技能时间
            case skill_use_fr(Sid, SkillData#ets_skill.cd, State) of
                [true, State1] ->
                    %% 判断MP是否足够
                    [ _, {mp_out, MpOut} | _ ] = SkillData#ets_skill.data,
                    case MpOut > Aer#battle_status.mp of
                        false ->
                            %% 判断攻击距离
                            AttArea = if
                                SkillData#ets_skill.attarea == 0 ->
                                    Aer#battle_status.att_area;
                                true ->
                                    SkillData#ets_skill.attarea
                            end,
                            case check_attarea([AttArea, Aer#battle_status.x, Aer#battle_status.y], [Der#battle_status.x, Der#battle_status.y]) andalso SkillData#ets_skill.type < 2 of
                                true -> %% 合理攻击范围内
                                    Aer1 = Aer#battle_status{mp = Aer#battle_status.mp - MpOut},
                                    case SkillData#ets_skill.type of
                                        1 -> %% 主动
                                            %% 判断是群攻还是单攻
                                            case SkillData#ets_skill.mod of
                                                2 ->
                                                    [double_active_skill(Aer1, Der, SkillData, State1), Sid];
                                                _ ->
                                                    [single_active_skill(Aer1, Der, SkillData, State1), Sid]
                                            end;
                                        _ -> %% 技能出错
                                            false
                                    end;
                                false -> %% 不在攻击范围内
                                    att_area_out
                            end;
                        true -> %% 蓝不足
                            [single_active_skill(Aer, Der, [], State), 0]
                    end;
                [false, State2] -> %% 还没到时候技能的时候
                    [single_active_skill(Aer, Der, [], State2), 0]
            end
    end.

%% 使用辅助技能
use_assist_skill([Aer, Der, Sid, State]) ->
    {Sid1, Slv1} = case lists:keyfind(Sid, 1, Aer#player_status.skill) of
        false ->
            {0, 0};
        {_, Lv} ->
            {Sid, Lv}
    end,
    
    case data_skill:get(Sid1, Slv1) of  %% 先判断技能是否存在
        [] ->
            skip;
        SkillData ->
            %% 判断上次放技能时间
            case skill_use_fr(Sid, SkillData#ets_skill.cd, State) of
                [true, State1] ->
                    %% 判断MP是否足够
                    [ _, {mp_out, MpOut} | _ ] = SkillData#ets_skill.data,
                    case MpOut > Aer#player_status.mp orelse SkillData#ets_skill.type /= 3  of
                        false ->
                            %% 判断释放目标
                            case SkillData#ets_skill.obj == 1 of
                                true -> %以自己为目标
                                    Aer1 = Aer#player_status{mp = Aer#player_status.mp - MpOut},
                                    case SkillData#ets_skill.mod == 2 andalso Aer1#player_status.pid_team /= none of %% 判断是群攻还是单攻
                                        true ->
                                            double_assist_skill(Aer1, {}, SkillData);
                                        false ->
                                            single_assist_skill(Aer1, {}, SkillData)
                                    end;
                                false -> %以他人为目标
                                    %% 判断攻击距离
                                    AttArea = if
                                        SkillData#ets_skill.attarea == 0 ->
                                            Aer#player_status.att_area;
                                        true ->
                                            SkillData#ets_skill.attarea
                                    end,
                                    %% 有一个给自己加血的技能Der=={}区分 or 用 Der == Aer
                                    case Der=={} orelse check_attarea([AttArea, Aer#player_status.x, Aer#player_status.y], [Der#player_status.x, Der#player_status.y]) of
                                        true -> %% 合理攻击范围内
                                            Aer1 = Aer#player_status{mp = Aer#player_status.mp - MpOut},
                                            case SkillData#ets_skill.mod of %% 判断是群攻还是单攻
                                                2 ->
                                                    double_assist_skill(Aer1, Der, SkillData);
                                                _ ->
                                                    single_assist_skill(Aer1, Der, SkillData)
                                            end;
                                        false -> %% 不在攻击范围内
                                            skip
                                    end
                                end,
                                State1;
                        true ->
                            State1
                    end;
                [false, State2] ->
                    State2
            end
    end.

%群攻
double_active_skill(Aer, Der, SkillData, State) ->
    NowTime = util:longunixtime(),
    %% 计算技能效果
    Aer1 = cale_aer_last_effect(Aer#battle_status.battle_status, Aer, [], NowTime),
    %% 计算主动技能
    [Aer2, _] = case SkillData of
        [] ->
            [Aer1, Der];
        _ ->
            [ _, _ | Data ] = SkillData#ets_skill.data,
            Time = NowTime+SkillData#ets_skill.lastime,
            cale_active_effect(Data , Aer1, Der, Aer1#battle_status.battle_status, Der#battle_status.battle_status, Time)
    end,
    
    F = fun(D) ->
        DerInit = init_data(D),
        %% 计算技能效果
        DerInit1 = cale_der_last_effect(DerInit#battle_status.battle_status, DerInit, [], NowTime),

        [Hpb, Mpb, Hurt, Status] = cale_hurt(
            [Aer2#battle_status.att, Aer2#battle_status.def, Aer2#battle_status.hit, Aer2#battle_status.dodge, Aer2#battle_status.crit, Aer2#battle_status.ten, Aer2#battle_status.hp, Aer2#battle_status.mp],
            [DerInit1#battle_status.att, DerInit1#battle_status.def, DerInit1#battle_status.hit, DerInit1#battle_status.dodge, DerInit1#battle_status.crit, DerInit1#battle_status.ten, DerInit1#battle_status.hp, DerInit1#battle_status.mp]
        ),
        if
            Aer2#battle_status.sign == 1 -> %% 攻击者是怪物
                DerInit1#battle_status.sid ! {'BATTLE', [Hpb, Mpb, 0, 0], 0};
            true ->
                DerInit1#battle_status.sid ! {'BATTLE', [Hpb, Mpb, 0, 0], Aer2#battle_status.sid}
        end,
        [DerInit1#battle_status.sign, DerInit1#battle_status.id, Hpb, Mpb, Hurt, Status]
    end,

    AerId1 = case Aer2#battle_status.sign of
        1 ->
            0;
        2 ->
            Aer2#battle_status.id
    end,
    DerId1 = case Der#battle_status.sign of
        1 ->
            0;
        2 ->
            Der#battle_status.id
    end,
    AllUser = get_user_for_battle(Der#battle_status.scene, Der#battle_status.x, Der#battle_status.y, 2, AerId1, DerId1),
    AerId2 = case Aer2#battle_status.sign of
        2 ->
            0;
        1 ->
            Aer2#battle_status.id
    end,
    DerId2 = case Der#battle_status.sign of
        2 ->
            0;
        1 ->
            Der#battle_status.id
    end,
    AllMon = get_mon_for_battle(Der#battle_status.scene, Der#battle_status.x ,Der#battle_status.y, 2, AerId2, DerId2),

    case Der#battle_status.id == Aer2#battle_status.id of
        true ->
            All = AllUser ++ AllMon;
        false ->
            My = [[Der#battle_status.id, Der#battle_status.att, Der#battle_status.def, Der#battle_status.hit, Der#battle_status.dodge, Der#battle_status.crit, Der#battle_status.ten, Der#battle_status.hp, Der#battle_status.mp, Der#battle_status.sid, Der#battle_status.sign, Der#battle_status.battle_status]],
            All = My ++ AllUser ++ AllMon
    end,
    
    {Aer2, 0, 0, State, [F(D) || D <-All]}.
    
%%单体攻击
single_active_skill(Aer, Der, SkillData, State) ->
    NowTime = util:longunixtime(),
    %% 持续效果
    Aer1 = cale_aer_last_effect(Aer#battle_status.battle_status, Aer, [], NowTime),
    Der1 = cale_der_last_effect(Der#battle_status.battle_status, Der, [], NowTime),
    
    %% 计算技能效果
    [Aer2, Der2] = case SkillData of
        [] ->
            [Aer1, Der1];
        _ ->
            [ _, _ | Data ] = SkillData#ets_skill.data,
            Time = NowTime+SkillData#ets_skill.lastime,
            cale_active_effect(Data , Aer1, Der1, Aer#battle_status.battle_status, Der#battle_status.battle_status, Time)
    end,
    
    %是否打退
    [X, Y] = case random:uniform(100) > 80 andalso Aer2#battle_status.sign == 2 of
        false ->
            [0, 0];
        true ->
            X0 = if
                Der2#battle_status.x - Aer2#battle_status.x > 0 ->
                    Der2#battle_status.x + 3;
                Der2#battle_status.x - Aer2#battle_status.x < 0 ->
                    Der2#battle_status.x - 3;
                true->
                    Der2#battle_status.x
            end,
            Y0 = if
                Der2#battle_status.y - Aer2#battle_status.y > 0 ->
                    Der2#battle_status.y + 3;
                Der2#battle_status.y - Aer2#battle_status.y < 0 ->
                    Der2#battle_status.y - 3;
                true->
                    Der2#battle_status.y
            end,
            %判断是否障碍物
            case lib_scene:is_blocked(Aer2#battle_status.scene, [X0, Y0]) of
                true ->
                    [X0, Y0];
                false ->
                    [0,0]
            end
    end,
    [Hpb, Mpb, Hurt, Status] = cale_hurt(
        [Aer2#battle_status.att, Aer2#battle_status.def, Aer2#battle_status.hit, Aer2#battle_status.dodge, Aer2#battle_status.crit, Aer2#battle_status.ten, Aer2#battle_status.hp, Aer2#battle_status.mp],
        [Der2#battle_status.att, Der2#battle_status.def, Der2#battle_status.hit, Der2#battle_status.dodge, Der2#battle_status.crit, Der2#battle_status.ten, Der2#battle_status.hp, Der2#battle_status.mp]
    ),
    
    if
        Aer2#battle_status.sign == 1 -> %% 攻击者是怪物
            Der2#battle_status.sid ! {'BATTLE', [Hpb, Mpb, X, Y], 0};
        true ->
            Der2#battle_status.sid ! {'BATTLE', [Hpb, Mpb, X, Y], Aer2#battle_status.sid}
    end,
    {Aer2, X, Y, State, [[Der2#battle_status.sign, Der2#battle_status.id, Hpb, Mpb, Hurt, Status]]}.

% 群攻辅助
double_assist_skill(Aer, _Der, SkillData) ->
    [ _, _ | Data ] = SkillData#ets_skill.data,
    L = ets:match(?ETS_ONLINE, #ets_online{pid='$1', id = '$2', hp='$3', battle_status = '$4', pid_team=Aer#player_status.pid_team, _='_'}),
    Time = util:longunixtime()+SkillData#ets_skill.lastime,
    F =fun([Pid, Id, Hp0, BattleStatus ]) ->
        case SkillData#ets_skill.lastime > 0 of
            true -> %%持续性技能
                Effect = cale_assist_last_effect(Data , BattleStatus, Time),
                Pid ! {'BATTLE_STATUS', Effect},
                [Id, Hp0];
            false -> %% 一次性使用技能
                [Hp] = cale_assist_one_effect(Data, [Hp0]),
                Pid ! {'HP', Hp},
                [Id, Hp]
        end
    end,
    List = [F(D) || D <- L],
    send_assist_msg(Aer#player_status.id, SkillData#ets_skill.id, Aer#player_status.mp, Aer#player_status.scene, List).

%%单体辅助
single_assist_skill(Aer, Der, SkillData) ->
    if
        Der == {} ->
            User = Aer;
        true ->
            User = Der
    end,
    [ _, _ | Data ] = SkillData#ets_skill.data,
    case SkillData#ets_skill.lastime > 0 of
        true -> %%持续性技能
            Time = util:longunixtime()+SkillData#ets_skill.lastime,
            Effect = cale_assist_last_effect(Data , User#player_status.battle_status, Time),
            User#player_status.pid ! {'BATTLE_STATUS', Effect},
            %% 发消息
            send_assist_msg(Aer#player_status.id, SkillData#ets_skill.id, Aer#player_status.mp, User#player_status.scene, []);
        false -> %% 一次性使用技能
            [Hp] = cale_assist_one_effect(Data, [User#player_status.hp]),
            case Hp >  User#player_status.hp_lim of
                true ->
                    Hp1 = User#player_status.hp_lim;
                false ->
                    Hp1 = Hp
            end,
            User#player_status.pid ! {'HP', Hp1},
            send_assist_msg(Aer#player_status.id, SkillData#ets_skill.id, Aer#player_status.mp, User#player_status.scene, [[User#player_status.id, Hp1]])
    end.

%%计算伤害
%%Att[攻击], Def[防御], Hit[命中], Der[防御], Crit[暴击], Ten[坚韧]
cale_hurt([Atta, _Defa, Hita, _Dodgea, Crita, _Tena, _Hpa, _Mpa], [_Attb, Defb, _Hitb, Dodgeb, _Critb, Tenb, Hpb, Mpb])->
    Hit = (0.25 + Hita / (Hita + Dodgeb) * 1.3),
    %Status : (0普通攻击,1躲避,3暴击)
    {Hurt, Status} = case random:uniform(1000) > Hit * 1000 of
        false -> % 命中
            Att = (Atta*Atta) div (Atta + Defb),

            % 是否暴击
            Crit = Crita/(Crita + Tenb),
            {Att1, Status1} = case random:uniform(1000) > Crit * 1000 of
                true -> % 没暴击
                    {trunc(Att/3), 0};
                false ->
                    {trunc(Att*(1+Crit)/3), 3}
            end,
           {Att1, Status1};
        true -> % miss
            {0, 1}
    end,
    case Hurt > 0 of
        true ->
            D_hp = Hpb -  Hurt,
            Hpb1 = case D_hp =< 0 of
                true -> %死亡状态
                    0;
                false ->
                    D_hp
            end,
            [Hpb1, Mpb, Hurt, Status];
        false ->
            [Hpb, Mpb, 0, Status]
    end.

%%获取群攻范围内的玩家
get_user_for_battle(Q, X, Y, Area, Id1, Id2) ->
    X1 = X + Area,
    X2 = X - Area,
    Y1 = Y + Area,
    Y2 = Y - Area,
    AllUser = ets:match(?ETS_ONLINE, #ets_online{id = '$1',x = '$2', y='$3', att='$4', def='$5', hit='$6', dodge='$7', crit='$8', ten='$9', hp='$10', mp='$11', pid='$12', battle_status='$13',  scene = Q, _='_'}),
    [[Id, Att, Def, Hit, Dodge, Crit, Ten, Hp, Mp, Pid, 2, BS] || [Id, X0, Y0, Att, Def, Hit, Dodge, Crit, Ten, Hp, Mp, Pid, BS] <-AllUser, X0 >= X2 andalso X0 =< X1, Y0 >= Y2 andalso Y0 =< Y1, Id /= Id1 andalso Id /= Id2, Hp > 0].

%%获取群攻范围内的怪物
get_mon_for_battle(Q, X, Y, Area, Id1, Id2) ->
    X1 = X + Area,
    X2 = X - Area,
    Y1 = Y + Area,
    Y2 = Y - Area,
    AllMon = ets:match(?ETS_MON, #ets_mon{id = '$1',x = '$2', y='$3', att='$4', def='$5', hit='$6', dodge='$7', crit='$8', ten='$9', hp='$10', mp='$11', aid='$12', battle_status='$13',  scene = Q, _='_'}),
    [[Id, Att, Def, Hit, Dodge, Crit, Ten, Hp, Mp, Pid, 1, BS] || [Id, X0, Y0, Att, Def, Hit, Dodge, Crit, Ten, Hp, Mp, Pid, BS] <-AllMon, X0 >= X2 andalso X0 =< X1, Y0 >= Y2 andalso Y0 =< Y1 , Id /= Id1 andalso Id /= Id2, Hp > 0].

%% 战斗失败
battle_fail(State, [Sign1, User1, Hp1, X1, Y1, Sign2, User2, Hp2, X2, Y2], Socket) ->
    {ok, BinData} = pt_20:write(20005, [State, Sign1, User1, Hp1, X1, Y1, Sign2, User2, Hp2, X2, Y2]),
    lib_send:send_one(Socket, BinData).

%% 主动技能效果
%% SA攻击方持续状态
%% SD防守方持续状态
cale_active_effect([] , Aer, Der, SA, SD, _Time) ->
    [Aer#battle_status{battle_status = SA}, Der#battle_status{battle_status = SD}];
cale_active_effect([{K, V} | T] , Aer, Der, SA, SD, Time) ->
    case K of
        att ->      % 加攻击
            Att = value_cate(V, Aer#battle_status.att),
            Aer1 = Aer#battle_status{att = Att},
            cale_active_effect(T , Aer1, Der, SA, SD, Time);
        hp ->       % 加Hp
            Hp = value_cate(V, Aer#battle_status.hp),
            Aer1 = Aer#battle_status{hp = Hp},
            cale_active_effect(T , Aer1, Der, SA, SD, Time);
        mp ->       % 加MP
            Mp = value_cate(V, Aer#battle_status.mp),
            Aer1 = Aer#battle_status{mp = Mp},
            cale_active_effect(T , Aer1, Der, SA, SD, Time);
        hurt_add -> % 加大攻击伤害
            HurtAdd = value_cate(V, Aer#battle_status.hurt_add),
            Aer1 = Aer#battle_status{hurt_add = HurtAdd},
            cale_active_effect(T , Aer1, Der, SA, SD, Time);
        hurt_del -> % 减少被攻击伤害
            cale_active_effect(T , Aer, Der, SA, SD, Time);
        crit ->     % 加暴击
            Crit = value_cate(V, Aer#battle_status.crit),
            Aer1 = Aer#battle_status{crit = Crit},
            cale_active_effect(T , Aer1, Der, SA, SD, Time);
        def_add ->  % 对自己防御
            cale_active_effect(T , Aer, Der, SA, SD, Time);
        def_del ->  % 对对方防御
            Def = value_cate(V, Der#battle_status.def),
            Der1 = Der#battle_status{def = Def},
            cale_active_effect(T , Aer, Der1, SA, SD, Time);
        hit_add ->  % 加命中
            Hit = value_cate(V, Aer#battle_status.hit),
            Aer1 = Aer#battle_status{hit = Hit},
            cale_active_effect(T , Aer1, Der, SA, SD, Time);
        hit_del ->  % 减命中
            cale_active_effect(T , Aer, Der, SA, SD, Time);
        dodge ->    % 加躲避
            cale_active_effect(T , Aer, Der, SA, SD, Time);
        speed ->    % 减速度
            cale_active_effect(T , Aer, Der, SA, SD, Time);
        ftsh ->     % 反弹伤害
            cale_active_effect(T , Aer, Der, SA, SD, Time);
        drug ->     % 加毒
            [_,T1,_] = V,
            if
                Aer#battle_status.sign == 1 -> %% 攻击者是怪物
                    erlang:send_after(T1*1000, Der#battle_status.bid, {last_red_hp, Der#battle_status.sid, 0, V});
                true ->
                    erlang:send_after(T1*1000, Der#battle_status.bid, {last_red_hp, Der#battle_status.sid, Aer#battle_status.sid, V})
            end,
            cale_active_effect(T , Aer, Der, SA, SD, Time);
        shield ->   % 法盾
            cale_active_effect(T , Aer, Der, SA, SD ++ [{K, V, Time}], Time);
        last_def_del ->   % 持续减防
            [P,V1] = V,
            case random:uniform(100) > P of
                true ->
                    cale_active_effect(T , Aer, Der, SA, SD, Time);
                false ->
                    cale_active_effect(T , Aer, Der, SA, SD ++ [{K, V1, Time}], Time)
            end
    end.

%% 一次性辅助技能能效果
cale_assist_one_effect([], Data) ->
    Data;
cale_assist_one_effect([{K, V} | T], Data) ->
    case K of
        hp ->      % 加攻击
            [Hp] =Data,
            Hp1 = value_cate(V, Hp),
            cale_assist_one_effect(T, [Hp1]);
        _ ->
            cale_assist_one_effect(T, Data)
    end.

%% 持续辅助技能能效果
cale_assist_last_effect([], Effect, _) ->
    Effect;
cale_assist_last_effect([{K, V} | T], Effect, Time) ->
    case K of
        att ->      % 加攻击
            Effect1 = case lists:keyfind(att, 1, Effect) of
                false ->
                    Effect;
                _ ->
                    lists:keydelete(att, 1, Effect)
            end,
            cale_assist_last_effect(T, Effect1 ++ [{K, V, Time}], Time);
        hurt_add -> % 加大攻击伤害
            Effect1 = case lists:keyfind(hurt_add, 1, Effect) of
                false ->
                    Effect;
                _ ->
                    lists:keydelete(hurt_add, 1, Effect)
            end,
            cale_assist_last_effect(T, Effect1 ++ [{K, V, Time}], Time);
        hurt_del -> % 减少被攻击伤害
            Effect1 = case lists:keyfind(hurt_del, 1, Effect) of
                false ->
                    Effect;
                _ ->
                    lists:keydelete(hurt_del, 1, Effect)
            end,
            cale_assist_last_effect(T, Effect1 ++ [{K, V, Time}], Time);
        crit ->     % 加暴击
            Effect1 = case lists:keyfind(crit, 1, Effect) of
                false ->
                    Effect;
                _ ->
                    lists:keydelete(crit, 1, Effect)
            end,
            cale_assist_last_effect(T, Effect1 ++ [{K, V, Time}], Time);
        def_add ->  % 对自己防御
            Effect1 = case lists:keyfind(def_add, 1, Effect) of
                false ->
                    Effect;
                _ ->
                    lists:keydelete(def_add, 1, Effect)
            end,
            cale_assist_last_effect(T, Effect1 ++ [{K, V, Time}], Time);
        hit_add ->  % 加命中
            Effect1 = case lists:keyfind(hit_add, 1, Effect) of
                false ->
                    Effect;
                _ ->
                    lists:keydelete(hit_add, 1, Effect)
            end,
            cale_assist_last_effect(T, Effect1 ++ [{K, V, Time}], Time);
        dodge ->    % 加躲避
            Effect1 = case lists:keyfind(dodge, 1, Effect) of
                false ->
                    Effect;
                _ ->
                    lists:keydelete(dodge, 1, Effect)
            end,
            cale_assist_last_effect(T, Effect1 ++ [{K, V, Time}], Time);
        add_speed ->  % 加速
            Effect1 = case lists:keyfind(add_speed, 1, Effect) of
                false ->
                    Effect;
                _ ->
                    lists:keydelete(add_speed, 1, Effect)
            end,
            cale_assist_last_effect(T, Effect1 ++ [{K, V, Time}], Time);
        shield -> %% 法盾
            Effect1 = case lists:keyfind(shield, 1, Effect) of
                false ->
                    Effect;
                _ ->
                    lists:keydelete(shield, 1, Effect)
            end,
            cale_assist_last_effect(T, Effect1 ++ [{K, V, Time}], Time);
        _ ->
            cale_assist_last_effect(T, Effect, Time)
    end.

%% 整数相加，小数相乘
value_cate(V1, V2) when is_float(V1) ->
    round(V2*V1);
value_cate(V1, V2) ->
    V2+V1.

%% 判断攻击距离
check_attarea([AttArea, X1, Y1], [X2, Y2]) ->
    case AttArea >= abs(X1 - X2) of %放宽一格的验证
        true ->
            case AttArea >= abs(Y1 - Y2) of
                true ->
                    true;
                false ->
                    false
            end;
        false ->
           false
    end.

%% 计算攻击方持续效果 - 主要是加成效果
cale_aer_last_effect([] , Aer, NewState, _Time) ->
    Aer#battle_status{battle_status = NewState};
cale_aer_last_effect([{K, V, T} | H] , Aer, NewState, Time) ->
    case K of
        att ->      % 加攻击
            case T > Time of
                true ->
                    Att = value_cate(V, Aer#battle_status.att),
                    Aer1 = Aer#battle_status{att = Att},
                    cale_aer_last_effect(H , Aer1, NewState ++ [{K, V, T}], Time);
                false ->
                    cale_aer_last_effect(H , Aer, NewState, Time)
            end;
        hurt_add -> % 加大攻击伤害
            case T > Time of
                true ->
                    Aer1 = Aer#battle_status{hurt_add = V},
                    cale_aer_last_effect(H , Aer1, NewState ++ [{K, V, T}], Time);
                false ->
                    cale_aer_last_effect(H , Aer, NewState, Time)
            end;
        crit ->     % 加暴击
            case T > Time of
                true ->
                    Crit = value_cate(V, Aer#battle_status.crit),
                    Aer1 = Aer#battle_status{crit = Crit},
                    cale_aer_last_effect(H , Aer1, NewState ++ [{K, V, T}], Time);
                false ->
                    cale_aer_last_effect(H , Aer, NewState, Time)
            end;
        hit_add ->  % 加命中
            case T > Time of
                true ->
                    Hit = value_cate(V, Aer#battle_status.hit),
                    Aer1 = Aer#battle_status{hit = Hit},
                    cale_aer_last_effect(H , Aer1, NewState ++ [{K, V, T}], Time);
                false ->
                    cale_aer_last_effect(H , Aer, NewState, Time)
            end;
        hit_del ->  % 减命中
            case T > Time of
                true ->
                    Hit = value_cate(V, Aer#battle_status.hit),
                    Aer1 = Aer#battle_status{hit = Hit},
                    cale_aer_last_effect(H , Aer1, NewState ++ [{K, V, T}], Time);
                false ->
                    cale_aer_last_effect(H , Aer, NewState, Time)
            end;
        dodge ->    % 加躲避
            case T > Time of
                true ->
                    Dodge = value_cate(V, Aer#battle_status.dodge),
                    Aer1 = Aer#battle_status{dodge = Dodge},
                    cale_aer_last_effect(H , Aer1, NewState ++ [{K, V, T}], Time);
                false ->
                    cale_aer_last_effect(H , Aer, NewState, Time)
            end;
        _ ->
            cale_aer_last_effect(H , Aer, NewState, Time)
    end.

%% 计算防守方持续效果 - 主要是抵御和被附近的效果
cale_der_last_effect([] , Der, NewState, _Time) ->
    Der#battle_status{battle_status = NewState};
cale_der_last_effect([{K, V, T} | H] , Der, NewState, Time) ->
    case K of
        hurt_del -> % 减少被攻击伤害
            case T > Time of
                true ->
                    HurtDel = value_cate(V, Der#battle_status.hurt_del),
                    Der1 = Der#battle_status{hurt_del = HurtDel},
                    cale_der_last_effect(H , Der1, NewState ++ [{K, V, T}], Time);
                false ->
                    cale_der_last_effect(H , Der, NewState, Time)
            end;
        def_add ->  % 对自己防御
            case T > Time of
                true ->
                    Def = value_cate(V, Der#battle_status.def),
                    Der1 = Der#battle_status{def = Def},
                    cale_der_last_effect(H , Der1, NewState ++ [{K, V, T}], Time);
                false ->
                    cale_der_last_effect(H , Der, NewState, Time)
            end;
        def_del ->  % 对对方防御
            case T > Time of
                true ->
                    Def = value_cate(V, Der#battle_status.def),
                    Der1 = Der#battle_status{def = Def},
                    cale_der_last_effect(H , Der1, NewState ++ [{K, V, T}], Time);
                false ->
                    cale_der_last_effect(H , Der, NewState, Time)
            end;
        ftsh ->     % 反弹伤害
            case T > Time of
                true ->
                    Ftsh = value_cate(V, Der#battle_status.ftsh),
                    Der1 = Der#battle_status{ftsh = Ftsh},
                    cale_der_last_effect(H , Der1, NewState ++ [{K, V, T}], Time);
                false ->
                    cale_der_last_effect(H , Der, NewState, Time)
            end;
        shield ->   % 法盾
            case T > Time of
                true ->
                    Shield = value_cate(V, Der#battle_status.shield),
                    Der1 = Der#battle_status{shield = Shield},
                    cale_der_last_effect(H , Der1, NewState ++ [{K, V, T}], Time);
                false ->
                    cale_der_last_effect(H , Der, NewState, Time)
            end;
        last_def_del ->   % 持续减防
            case T > Time of
                true ->
                    Def = value_cate(V, Der#battle_status.def),
                    Der1 = Der#battle_status{def = Def},
                    cale_der_last_effect(H , Der1, NewState ++ [{K, V, T}], Time);
                false ->
                    cale_der_last_effect(H , Der, NewState, Time)
            end;
        _ ->
            cale_der_last_effect(H , Der, NewState, Time)
    end.

%% 技能触发频率
skill_use_fr(Sid, Cd, State) ->
    Time = util:longunixtime(),
    case lists:keyfind(Sid, 1, State#state.last_skill_time) of
        false ->
            State1 = State#state{last_skill_time = [{Sid, Time}] ++ State#state.last_skill_time},
            [true, State1];
        {_, Time0} ->
            case Time0 + Cd < Time  of
                true ->
                    LastSkillTime = lists:keydelete(Sid, 1, State#state.last_skill_time),
                    State1 = State#state{last_skill_time = [{Sid, Time}] ++ LastSkillTime},
                    [true, State1];
                false ->
                    [false, State] 
            end
    end.