%%%--------------------------------------
%%% @Module  : lib_relationship
%%% @Author  : zzm
%%% @Email   : ming_up@163.com
%%% @Created : 2010.05.20
%%% @Description: 玩家关系相关处理
%%%--------------------------------------

-module(lib_relationship).
-export([add/3
        ,delete/1
        ,delete_ets/1
        ,delete_role/1
        ,find/1
%        ,find/2
%        ,find_A/2
%        ,get_auto_res/1
        ,get_id/3
        ,get_intimacy/1
        ,get_friend_group_name/1
        ,move_friend/2
        ,new_friend_group/3
%        ,is_exists/3
%        ,set_auto_res/3
        ,set_ets_rela_set/1
        ,set_ets_rela_info_lv/2
        ,set_friend_group_name/3
        ,set_intimacy/2
        ]).

-include("record.hrl").
-include("common.hrl").

%%建立关系(A加B)
%%IdA:角色A的id
%%IdB:角色B的id
%%Rela:A与B的关系
%%    0 =>没关系
%%    1 =>好友
%%    2 =>黑名单
%%    3 =>仇人
add(IdA, IdB, Rela) ->
    R = execute(db_sql:make_insert_sql(relationship, ["idA", "idB", "rela"], [IdA, IdB, Rela])),
    case get_id(IdA, IdB, Rela) of
        0 ->
            ?ERR("get_id: IdA[~p], IdB[~p], Rela[~p], ~n", [IdA, IdB, Rela]),
            ok;
        Id ->
            insert_ets_rela(Id, IdA, IdB, Rela, 0, 1)
    end,
    R.

%%删除某个记录
delete(Id) ->
    ets:delete(?ETS_RELA, Id),
    execute(<<"delete from relationship where id = ~p">>, [Id]).

%%下线清除ets_rela表中的相关数据
delete_ets(Uid) ->
    ets:match_delete(?ETS_RELA, #ets_rela{idA = Uid, _ = '_'}),
    ets:delete(?ETS_RELA_SET, Uid).

%%当玩家删除角色时，删除有关于这角色的数据
delete_role(Uid) -> 
    case execute(<<"delete from relationship where idA = ~p or idB = ~p">>, [Uid, Uid]) of 
        {ok, 1} -> 
            case execute(<<"delete from relationship_setting where id = ~p">>, [Uid]) of
                {ok, 1} -> true;
                _ -> false
            end;
        _ -> false
    end.

%%查找与角色A有关系的角色信息
find(IdA) ->
    db_sql:get_all(io_lib:format(<<"select * from relationship where idA = ~p">>, [IdA])).

%%查找与角色A有Rela关系的角色
%find(IdA, Rela) ->
%    db_sql:get_all(io_lib:format(<<"select * from relationship where idA = ~p and rela = ~p">>, [IdA, Rela])).

%%知道角色B，查找与之有Rela关系的角色A
%find_A(IdB, Rela) ->
%    db_sql:get_all(io_lib:format(<<"select * from relationship where idB = ~p and rela = ~p">>, [IdB, Rela])).

%%获取自动回复设置
%get_auto_res(Id) ->
%    db_sql:get_row(io_lib:format(<<"select auto_res, msg from relationship_setting where id = ~p">>, [Id])).

%%获取分组名字
get_friend_group_name(Id) ->
    case db_sql:get_row(io_lib:format(<<"select name1, name2, name3 from relationship_setting where id = ~p">>, [Id])) of
        [] -> [];
        R -> R
    end.

%%取某条记录id
get_id(IdA, IdB, Rela) ->
    case db_sql:get_row(io_lib:format(<<"select id from relationship where idA = ~p and idB = ~p and rela = ~p">>, [IdA, IdB, Rela])) of
        [] -> 0;
        [H] -> H
    end.

%%获取的亲密度
get_intimacy(Id) ->
    db_sql:get_row(io_lib:format(<<"select intimacy from relationship where id = ~p">>, [Id])).

%%移动好友到别的分组
move_friend(Id, N) ->
    execute(<<"update relationship set in_group = ~p where id = ~p">>, [N, Id]).

%%新创建分组(当某一默认分组的名字被改变时)
new_friend_group(Id, N, Name) ->
    N1 = "name" ++ integer_to_list(N),
    case db_sql:get_row(io_lib:format(<<"select id, name1, name2, name3 from relationship_setting where id = ~p">>, [Id])) of
        [] ->
            execute(db_sql:make_insert_sql(relationship_setting, ["id", N1], [Id, Name]));
        [Id, Name1, Name2, Name3] -> %%如果有记录写进ets_rela_info表
            ets:insert(?ETS_RELA_INFO, #ets_rela_set{id = Id, name1 = Name1, name2 = Name2, name3 = Name3}),
            {ok, 0}
    end.

%%检查A与B是否存在Rela关系------------ 改为:从ets_rela读取
%is_exists(IdA, IdB, Rela) ->
%    case db_sql:get_row(io_lib:format(<<"select idA from relationship where idA = ~p and idB = ~p and rela = ~p">>, [IdA, IdB, Rela])) of
%        [] -> false;
%        _Other -> true
%    end.

%%设置自动回复设置
%set_auto_res(Id, AutoRes, Msg) ->
%    execute(lists:concat(["update relationship_setting set auto_res = ", integer_to_list(AutoRes), ", msg = '", Msg ,"' where id = ", integer_to_list(Id)])).

%%玩家升级时改变ets_rela_info的数据
set_ets_rela_info_lv(Id, Lv) ->
    case ets:lookup(?ETS_RELA_INFO, Id) of
        [] -> ok;
        [Info] -> 
            NewInfo = Info#ets_rela_info{lv = Lv},
            ets:insert(?ETS_RELA_INFO, NewInfo)
    end.

%%初始化ets_rela_set
set_ets_rela_set(Uid) ->
    case get_friend_group_name(Uid) of
        [] -> ok;
        [Name1, Name2, Name3] -> 
            ets:insert(?ETS_RELA_SET, #ets_rela_set{id = Uid, name1 = Name1, name2 = Name2, name3 = Name3})
    end.

%%改变好友分组的名字
%%IdA:角色id
%%N:第N个分组
%%NewName:新的分组名字
set_friend_group_name(Id, N, NewName) ->
    N1 = "name" ++ integer_to_list(N),
    execute(db_sql:make_update_sql(relationship_setting, [N1], [NewName], "id", Id)).

%%改变亲密度
set_intimacy(Id, Intimacy) ->
    execute(<<"update relationship set intimacy = ~p where id = ~p">>, [Intimacy, Id]).


%%私有函数------------------------------------

%%db_sql:execute/1
execute(Sql) ->
    case db_sql:execute(Sql) of
        1 -> {ok, 1};
        0 -> {ok, 1};
        _Other -> {ok ,0}
    end.

%%使用io_lib:format/2组合sql
execute(Sql, Args) ->
    case db_sql:execute(io_lib:format(Sql, Args)) of
        1 -> {ok, 1};
        0 -> {ok, 1};
        _Other -> {ok ,0}
    end.

%%往ets_rela表插入记录
insert_ets_rela(Id, IdA, IdB, Rela, Intimacy, Group) ->
    ets:insert(?ETS_RELA, #ets_rela{
            id = Id, 
            idA = IdA, 
            idB = IdB, 
            rela = Rela, 
            intimacy = Intimacy, 
            group = Group
        }).
