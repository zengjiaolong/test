%%%-----------------------------------
%%% @Module  : pt_13
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.04.29
%%% @Description: 13角色信息
%%%-----------------------------------
-module(pt_13).
-export([read/2, write/2]).

%%
%%客户端 -> 服务端 ----------------------------
%%

%%查询自己的信息
read(13001, _) ->
    {ok, myself};

%%查询玩家的信息
read(13004, <<Id:32>>) ->
    {ok, Id};

%%获取快捷栏
read(13007, _) ->
    {ok, get};

%%保存快捷栏
read(13008, <<T:8, S:8, Id:32>>) ->
    {ok, [T, S, Id]};

%%删除快捷栏
read(13009, <<T:8>>) ->
    {ok, T};

%%替换快捷栏
read(13010, <<T1:8, T2:8>>) ->
    {ok, [T1, T2]};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%%查询进入场景所需信息
write(13001, [Scene, X, Y, Id, Hp, Hp_lim, Mp, Mp_lim, Sex, Lv, Exp, Exp_lim, Career, Nickname,Att, Def, Forza, Agile, Wit, Hit, Dodge, 
            Crit, Ten, GuildId, GuildName, GuildPosition, Realm, Gold, Silver, Coin, Att_area, Spirit, Speed, AttSpeed, EquipCurrent
            ]) ->
    [E1, E2, E3] = EquipCurrent,
    Nick1 = list_to_binary(Nickname),
    Len = byte_size(Nick1),
    GuildName1 = list_to_binary(GuildName),
    Len1 = byte_size(GuildName1),
    Data = <<
            Scene:32,
            X:16,
            Y:16,
            Id:32,
            Hp:32,
            Hp_lim:32,
            Mp:32,
            Mp_lim:32,
            Sex:16,
            Lv:16,
            Exp:32,
            Exp_lim:32,
            Career:8,
            Len:16,
            Nick1/binary,
            Att:16,
            Def:16,
            Forza:16,
            Agile:16,
            Wit:16,
            Hit:16,
            Dodge:16,
            Crit:16,
            Ten:16,
            GuildId:16,
            Len1:16,
            GuildName1/binary,
            GuildPosition:8,
            Realm:8,
            Gold:32,
            Silver:32,
            Coin:32,
            Att_area:8,
            Spirit:32,
            Speed:16,
            AttSpeed:16,
            E1:32,
            E2:32,
            E3:32
            >>,
    {ok, pt:pack(13001, Data)};

%%加经验
write(13002, Exp) ->
    {ok, pt:pack(13002, <<Exp:32>>)};

%%升级
write(13003, [Hp, Mp, Lv, Exp, Exp_lim]) ->
    {ok, pt:pack(13003, <<Hp:32, Mp:32, Lv:16, Exp:32, Exp_lim:32>>)};

%%查询进入场景所需信息
write(13004, [Id, Hp, Hp_lim, Mp, Mp_lim, Sex, Lv, Career, Nickname,
            Att, Def, Forza, Agile, Wit, Hit, Dodge, Crit, Ten, GuildId, GuildName, GuildPosition,  Realm, Spirit
            ]) ->
    Nick1 = list_to_binary(Nickname),
    Len = byte_size(Nick1),
    GuildName1 = list_to_binary(GuildName),
    Len1 = byte_size(GuildName1),
    Data = <<
            Id:32,
            Hp:32,
            Hp_lim:32,
            Mp:32,
            Mp_lim:32,
            Sex:16,
            Lv:16,
            Career:8,
            Len:16,
            Nick1/binary,
            Att:16,
            Def:16,
            Forza:16,
            Agile:16,
            Wit:16,
            Hit:16,
            Dodge:16,
            Crit:16,
            Ten:16,
            GuildId:16,
            Len1:16,
            GuildName1/binary,
            GuildPosition:8,
            Realm:8,
            Spirit:32
            >>,
    {ok, pt:pack(13004, Data)};

%%通知客户端更新
write(13005, S) ->
    {ok, pt:pack(13005, <<S:8>>)};

%%通知客户端更新灵力
write(13006, Spr) ->
    {ok, pt:pack(13006, <<Spr:32>>)};

%%获取快捷栏
write(13007, []) ->
    {ok, pt:pack(13007, <<0:16, <<>>/binary>>)};
write(13007, Quickbar) ->
    Rlen = length(Quickbar),
    F = fun({L, T, Id}) ->
        <<L:8, T:8, Id:32>>
    end,
    RB = list_to_binary([F(D) || D <- Quickbar]),
    {ok, pt:pack(13007, <<Rlen:16, RB/binary>>)};

%%保存快捷栏
write(13008, State) ->
    {ok, pt:pack(13008, <<State:8>>)};

%%删除快捷栏
write(13009, State) ->
    {ok, pt:pack(13009, <<State:8>>)};

%%替换快捷栏
write(13010, State) ->
    {ok, pt:pack(13010, <<State:8>>)};


%%角色属性改变通知
write(13011, [PlayerId, ChangeReason, Level, Exp, ExpLimit, Forza, Agile, Wit, Hp, HpLimit, Mp, MpLimit, Att, Def, Hit, Dodge, Crit, Ten]) ->
    Data = <<PlayerId:32, ChangeReason:16, Level:16, Exp:32, ExpLimit:32, Forza:16, Agile:16, Wit:16, Hp:32, HpLimit:32, Mp:32, MpLimit:32, Att:16, Def:16, Hit:16, Dodge:16, Crit:16, Ten:16>>,
    {ok, pt:pack(13011, Data)};

write(_Cmd, _R) ->
    {ok, <<>>}.