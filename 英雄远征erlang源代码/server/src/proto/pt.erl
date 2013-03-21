%%%-----------------------------------
%%% @Module  : pt
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.04.29
%%% @Description: 协议公共函数
%%%-----------------------------------
-module(pt).
-export([
            read_string/1,
            pack_role_list/1,
            pack_mon_list/1,
            pack/2
        ]).

%%读取字符串
read_string(Bin) ->
    case Bin of
        <<Len:16, Bin1/binary>> ->
            case Bin1 of
                <<Str:Len/binary-unit:8, Rest/binary>> ->
                    {binary_to_list(Str), Rest};
                _R1 ->
                    {[],<<>>}
            end;
        _R1 ->
            {[],<<>>}
    end.

%% 打包角色列表
pack_role_list([]) ->
    <<0:16, <<>>/binary>>;
pack_role_list(User) ->
    Rlen = length(User),
    F = fun([Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent, Sex, Leader]) ->
        [E1, E2, E3] = EquipCurrent,
        Name1 = list_to_binary(Nick),
        Len = byte_size(Name1),
        <<X:16, Y:16, Id:32, Hp:32, Mp:32, Hp_lim:32, Mp_lim:32, Lv:16, Career:8, Len:16, Name1/binary, Speed:16, E1:32, E2:32, E3:32, Sex:8, Leader:8>>
    end,
    RB = list_to_binary([F(D) || D <- User]),
    <<Rlen:16, RB/binary>>.

%% 打包怪物列表
pack_mon_list([]) ->
    <<0:16, <<>>/binary>>;
pack_mon_list(Mon) ->
    F = fun([Id, Name, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Mid, Speed, Icon]) ->
             Len = byte_size(Name),
            <<X:16, Y:16, Id:32, Mid:32, Hp:32, Mp:32, Hp_lim:32, Mp_lim:32, Lv:16, Len:16, Name/binary, Speed:16, Icon:32>>
        end,
    Mons = [F([Id, Name, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Mid, Speed, Icon]) || [Id, Name, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Mid, Speed, Icon] <- Mon, Hp > 0],
    Rlen = length(Mons),
    RB = list_to_binary(Mons),
    <<Rlen:16, RB/binary>>.

%% 打包信息，添加消息头
pack(Cmd, Data) ->
    L = byte_size(Data) + 4,
    <<L:16, Cmd:16, Data/binary>>.
