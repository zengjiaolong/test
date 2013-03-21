%%%-----------------------------------
%%% @Module  : lib_meridian
%%% @Author  : hc
%%% @Email   : hc@jieyou.com
%%% @Created : 2010.08.09
%%% @Description: ����
%%%-----------------------------------
-module(mod_meridian).
-export([meridian_active/2,init_meridian/0]).
-include("common.hrl").
-include("record.hrl").

%-----------------------------------------------------------
%经脉开脉:0 开脉成功，1前置经脉未完全激活 2 经脉已经完全激活
%-----------------------------------------------------------
meridian_active(PlayerStatue,MeridianType) ->
    %检测开脉条件
    case catch check_condition1(PlayerStatue,MeridianType) of
        true ->
            GoodsType = get_meridian_goodstype(MeridianType),
           {_,OldLvl} = lib_meridian:check_meridian_lvl(PlayerStatue#player_status.id,MeridianType),
%           io:format("id=~p~n",[PlayerStatue#player_status.id]),
           if
                OldLvl >= 100 ->
                    {error, PlayerStatue,0,2};
                true          ->
                    RRRe = gen_server:call(PlayerStatue#player_status.goods_pid, {'delete_more', GoodsType, 1}),
%                    io:format("RRRe=~p~n",[RRRe]),
                    if
                        RRRe =:= 1 ->
                            %经脉属性值
                            Data = lib_meridian:get_value_between_two_lvl(MeridianType),
                            %设置经脉系数
                            lib_meridian:set_meridian_value(PlayerStatue#player_status.id,MeridianType,OldLvl+10),
                            %经脉属性添加
                            NewPlayerStatue = add_attribute_to_role(Data,PlayerStatue),
                            %设置玩家状态
                            gen_server:cast(NewPlayerStatue#player_status.pid, {'SET_PLAYER', NewPlayerStatue}),
                            %刷新玩家信息
                            lib_player:send_attribute_change_notify(NewPlayerStatue,0),
                            {error, NewPlayerStatue,OldLvl+10,0};
                         true      -> {error, PlayerStatue,0,3}
                    end
            end;
        _   ->
            {error, PlayerStatue,0,1}
    end.

%-----------------------------------------------
%经脉规则初始化
%-----------------------------------------------
init_meridian() ->
    %任脉
    case db_sql:get_row("select * from base_meridian where mer_type = 1") of
        []     ->
                db_sql:execute("insert into base_meridian(mer_type) value (1)");
        _      ->
                 ok
    end,
    %督脉
    case db_sql:get_row("select * from base_meridian where mer_type = 2") of
        []     ->
                db_sql:execute("insert into base_meridian(mer_type) value (2)");
        _       ->
                 ok
    end,
    %冲脉
    case db_sql:get_row("select * from base_meridian where mer_type = 3") of
        []     ->
                db_sql:execute("insert into base_meridian(mer_type) value (3)");
        _       ->
                 ok
    end,
    %带脉
    case db_sql:get_row("select * from base_meridian where mer_type = 4") of
        []     ->
                db_sql:execute("insert into base_meridian(mer_type) value (4)");
        _       ->
                 ok
    end,
    %阴维
    case db_sql:get_row("select * from base_meridian where mer_type = 5") of
        []     ->
                db_sql:execute("insert into base_meridian(mer_type) value (5)");
        _       ->
                 ok
    end,
    %阳维
    case db_sql:get_row("select * from base_meridian where mer_type = 6") of
        []     ->
                db_sql:execute("insert into base_meridian(mer_type) value (6)");
        _       ->
                 ok
    end,
    %阴跷
    case db_sql:get_row("select * from base_meridian where mer_type = 7") of
        []     ->
                db_sql:execute("insert into base_meridian(mer_type) value (7)");
        _       ->
                 ok
    end,
    %阳跷
    case db_sql:get_row("select * from base_meridian where mer_type = 8") of
        []     ->
                db_sql:execute("insert into base_meridian(mer_type) value (8)");
        _       ->
                 ok
    end,
    ok.

%-----------------------------------------------
%内部方法
%-----------------------------------------------

%检测开脉条件-前置脉搏
check_condition1(PlayerStatue,MeridianType) ->
    if
        MeridianType =:= mer_ren      ->
            true;
        MeridianType =:= mer_du       ->
            case lib_meridian:check_meridian_ative_all(PlayerStatue#player_status.id,mer_ren) of
                {ok, Value} ->
%                    io:format("Value=~p~n",[Value]),
                    Value;
                {error,  _}  ->
%                    io:format("Value"),
                    false
            end;
        MeridianType =:= mer_chong    ->
            case lib_meridian:check_meridian_ative_all(PlayerStatue#player_status.id,mer_du) of
                {ok, Value} ->
                    Value;
                {error,  _}  ->
                    false
            end;
        MeridianType =:= mer_dai      ->
            case lib_meridian:check_meridian_ative_all(PlayerStatue#player_status.id,mer_chong) of
                {ok, Value} ->
                    Value;
                {error,  _}  ->
                    false
            end;
        MeridianType =:= mer_yinwei   ->
            case lib_meridian:check_meridian_ative_all(PlayerStatue#player_status.id,mer_dai) of
                {ok, Value} ->
                    Value;
                {error,  _}  ->
                    false
            end;
        MeridianType =:= mer_yangwei  ->
            case lib_meridian:check_meridian_ative_all(PlayerStatue#player_status.id,mer_yinwei) of
                {ok, Value} ->
                    Value;
                {error,  _}  ->
                    false
            end;
        MeridianType =:= mer_yinqiao  ->
            case lib_meridian:check_meridian_ative_all(PlayerStatue#player_status.id,mer_yangwei) of
                {ok, Value} ->
                    Value;
                {error,  _}  ->
                    false
            end;
        MeridianType =:= mer_yangqiao ->
            case lib_meridian:check_meridian_ative_all(PlayerStatue#player_status.id,mer_yinqiao) of
                {ok, Value} ->
                    Value;
                {error,  _}  ->
                    false
            end;
        true                              ->
            false
    end.

%检测开脉条件-物品条件:
%return: 物品存在->{true goodsid}|{error,noreply}

get_meridian_goodstype(MeridianType) ->
    if
        MeridianType =:= mer_ren      ->
            TypeId= 111461;
        MeridianType =:= mer_du       ->
            TypeId= 111462;
        MeridianType =:= mer_chong    ->
            TypeId= 111463;
        MeridianType =:= mer_dai      ->
            TypeId= 111464;
        MeridianType =:= mer_yinwei   ->
            TypeId= 111465;
        MeridianType =:= mer_yangwei  ->
            TypeId= 111466;
        MeridianType =:= mer_yinqiao  ->
            TypeId= 111467;
        MeridianType =:= mer_yangqiao ->
            TypeId= 111468;
        true                              ->
            TypeId=0
    end,
    TypeId.


%添加经脉属性
add_attribute_to_role(List,PlayerStatue) ->
    %设置ets表
    if
        List =:= [] ->
            PlayerStatue;
       true         ->
            [{_,Crit},{_,Ten},{_,Hit},{_,Dodge},{_,Att},{_,Def},{_,Hp_lim},{_,Mp_lim}] = List,
            [Old_Hp_lim, Old_Mp_lim, Old_Att, Old_Def, Old_Hit, Old_Dodge, Old_Crit, Old_Ten] = PlayerStatue#player_status.base_attribute,
            NewPlayerStatue1 = PlayerStatue#player_status{
                                                            base_attribute=[Old_Hp_lim+Hp_lim,Old_Mp_lim+Mp_lim,Old_Att+Att,Old_Def+Def,Old_Hit+Hit,Old_Dodge+Dodge,Old_Crit+Hit,Old_Ten+Ten]
                                                           },
            %重新统计玩家信息
            NewPlayerStatue2 = lib_player:count_player_attribute(NewPlayerStatue1),
            %设置数据库
            db_sql:execute(io_lib:format(<<"update `player` set crit=crit+~p,ten=ten+~p,hit=hit+~p,dodge=dodge+~p,att=att+~p,def=def+~p,hp_lim=hp_lim+~p,mp_lim=mp_lim+~p where `id` = ~p">>,
                [Crit,Ten,Hit,Dodge,Att,Def,Hp_lim,Mp_lim,NewPlayerStatue2#player_status.id])),
            NewPlayerStatue2
    end.