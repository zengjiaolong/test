%%%-----------------------------------
%%% @Module  : lib_meridian
%%% @Author  : hc
%%% @Email   : hc@jieyou.com
%%% @Created : 2010.08.09
%%% @Description: ����
%%%-----------------------------------
-module(lib_meridian).
-export([
        check_meridian_info/1,
        check_meridian_lvl/2,
        check_meridian_lvl_byId/2,
        set_meridian_value/3,
        check_meridian_ative_all/2,
        get_value_between_two_lvl/1,
        type_to_id/1,
        id_to_type/1
       ]).

%SQL-查看经脉信息
-define(SQL_SELECT_MERIDIAN_INFO,  "select mer_ren,mer_du,mer_chong,mer_dai,mer_yinwei,mer_yangwei,mer_yinqiao,mer_yangqiao from meridian where player_id = ~p").
%SQL-新建经脉记录
-define(SQL_NEW_MERIDIAN,          "insert into meridian(player_id) VALUES (~p)").
%SQL-查看经脉等级
-define(SQL_SELECT_LVL_INFO,       "select ~p from meridian where player_id=~p").
%SQL-设置经脉系数
-define(SQL_ADDLMERIDIAN_VALUE,    "update meridian set ~p=~p where player_id=~p").
%SQL-产看经脉每级升级系数
-define(SQL_MERIDIAN_UPLVL_VALUE,  "select crit,ten,hit,shun,att,def,hp,mp from base_meridian where mer_type=~p").

%查看经脉信息
check_meridian_info(PlayrId) ->
    SQL1  = io_lib:format(?SQL_SELECT_MERIDIAN_INFO, [PlayrId]),
    case db_sql:get_row(SQL1) of
        []     ->
                SQL2 = io_lib:format(?SQL_NEW_MERIDIAN, [PlayrId]),
                db_sql:execute(SQL2),
                {ok, [PlayrId,0,0,0,0,0,0,0,0]};
        Result ->
                 {ok, [PlayrId]++Result}
    end.

%查看经脉等级byType
check_meridian_lvl(PlayrId,Type) ->
    SQL  = io_lib:format(?SQL_SELECT_LVL_INFO, [Type,PlayrId]),
    case catch db_sql:get_row(SQL) of
        {'EXIT',_}  -> {error,norecord};
        []          ->
                       {error,norecord};
        Result      ->
                       [Lvl] = Result,
                       {ok, Lvl}
    end.

 %查看经脉等级byID
check_meridian_lvl_byId(PlayrId,TypeId) ->
    Type = id_to_type(TypeId),
    SQL  = io_lib:format(?SQL_SELECT_LVL_INFO, [Type,PlayrId]),
    case catch db_sql:get_row(SQL) of
        {'EXIT',_}  -> {error,norecord};
        []          ->
                       {error,norecord};
        Result      ->
                       [Lvl] = Result,
                       {ok, Lvl}
    end.


%设置经脉系数
set_meridian_value(PlayrId,Type,Value) ->
    SQL  = io_lib:format(?SQL_ADDLMERIDIAN_VALUE, [Type,Value,PlayrId]),
    case catch db_sql:execute(SQL) of
        {'EXIT',_}  -> {error,norecord};
        _           -> {ok,noreply}
    end.

%查看经脉是否完全激活
check_meridian_ative_all(PlayrId,Type) ->
    SQL  = io_lib:format(?SQL_SELECT_LVL_INFO, [Type,PlayrId]),
    case catch db_sql:get_row(SQL) of
        {'EXIT',_}  ->
                     {error,false};
        []          ->
                       {error,false};
        Result      ->
                       [Lvl] = Result,
                       if
                           Lvl < 100 ->
                               {ok,false};
                           true      ->
                               {ok,true}
                       end
    end.

%获取经脉升级属性
get_value_between_two_lvl(Type) ->
    TypeId =type_to_id(Type),
    SQL  = io_lib:format(?SQL_MERIDIAN_UPLVL_VALUE, [TypeId]),
    case catch db_sql:get_row(SQL) of
        {'EXIT',_}  -> {error,norecord};
        []          ->
                       {error,norecord};
        Result      ->
%                       [Value] = Result,
                       [V1,V2,V3,V4,V5,V6,V7,V8] = Result,
                       [{1,V1},{2,V2},{3,V3},{4,V4},{5,V5},{6,V6},{7,V7},{8,V8}]
    end.


%经脉ID=>经脉类型
id_to_type(MeridianId) ->
    if
        MeridianId =:= 1 ->
            Value = mer_ren;
        MeridianId =:= 2 ->
            Value = mer_du;
        MeridianId =:= 3 ->
            Value = mer_chong;
        MeridianId =:= 4 ->
            Value = mer_dai;
        MeridianId =:= 5 ->
            Value = mer_yinwei;
        MeridianId =:= 6 ->
            Value = mer_yangwei;
        MeridianId =:= 7 ->
            Value = mer_yinqiao;
        MeridianId =:= 8 ->
            Value = mer_yangqiao;
        true              ->
            Value = mer_yangqiao
    end,
    Value.

%经脉类型=>经脉ID
type_to_id(MeridianType) ->
    if
        MeridianType =:= mer_ren ->
            Value = 1;
        MeridianType =:= mer_du ->
            Value = 2;
        MeridianType =:= mer_chong ->
            Value = 3;
        MeridianType =:= mer_dai ->
            Value = 4;
        MeridianType =:= mer_yinwei ->
            Value = 5;
        MeridianType =:= mer_yangwei ->
            Value = 6;
        MeridianType =:= mer_yinqiao ->
            Value = 7;
        MeridianType =:= mer_yangqiao ->
            Value = 8;
        true              ->
            Value = 8
    end,
    Value.