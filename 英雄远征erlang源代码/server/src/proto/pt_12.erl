%%%-----------------------------------
%%% @Module  : pt_12
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.04.29
%%% @Description: 12场景信息
%%%-----------------------------------
-module(pt_12).
-export([read/2, write/2, trans_to_12003/1]).
-include("record.hrl").

%%
%%客户端 -> 服务端 ----------------------------
%%

%%走路
read(12001, <<X:16, Y:16>>) ->
    {ok, [X, Y]};

%%加载场景
read(12002, _) ->
    {ok, load_scene};

%%离开场景
read(12004, <<Q:32>>) ->
    {ok, Q};

%%切换场景
read(12005, <<Q:32>>) ->
    {ok, Q};

%%离开副本
read(12030, <<Nid:32>>) ->
    {ok, Nid};

%%获取场景关系
read(12080, _) ->
    {ok, []};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%%走路
write(12001, [X, Y, Id]) ->
    Data = <<X:16, Y:16, Id:32>>,
    {ok, pt:pack(12001, Data)};

%%加场景信息
write(12002, {User, Mon, Elem, Npc}) ->
    Data1 = pack_elem_list(Elem),
    Data2 = pt:pack_role_list(User),
    Data3 = pt:pack_mon_list(Mon),
    Data4 = pack_npc_list(Npc),
    Data = << Data1/binary, Data2/binary, Data3/binary, Data4/binary>>,
    {ok, pt:pack(12002, Data)};

%%进入新场景广播给本场景的人
write(12003, [Id, Nick, X, Y, Hp, Hp_lim, Mp, Mp_lim, Lv, Career, Speed, EquipCurrent, Sex, Leader]) ->
    [E1, E2, E3] = EquipCurrent,
    Nick1 = list_to_binary(Nick),
    Len = byte_size(Nick1),
    Data = <<X:16, Y:16, Id:32, Hp:32, Mp:32, Hp_lim:32, Mp_lim:32, Lv:16, Career:8, Len:16, Nick1/binary, Speed:16, E1:32, E2:32, E3:32, Sex:8, Leader:8>>,
    {ok, pt:pack(12003, Data)};

%%退出场景
write(12004, Id) ->
    Data = <<Id:32>>,
    {ok, pt:pack(12004, Data)};

%%切换场景
write(12005, [Id, X, Y, Name, Sid]) ->
    Len = byte_size(Name),
    Data = <<Id:32, X:16, Y:16, Len:16, Name/binary, Sid:32>>,
    {ok, pt:pack(12005, Data)};

%%通知情景玩家怪物重生了
write(12007, Info) ->
    Name1 = Info#ets_mon.name,
    Len = byte_size(Name1),
    X = Info#ets_mon.x,
    Y = Info#ets_mon.y,
    Id = Info#ets_mon.id,
    Mid = Info#ets_mon.mid,
    Hp = Info#ets_mon.hp,
    Mp = Info#ets_mon.mp,
    Hp_lim = Info#ets_mon.hp_lim,
    Mp_lim = Info#ets_mon.mp_lim,
    Lv = Info#ets_mon.lv,
    Speed = Info#ets_mon.speed,
    Icon = Info#ets_mon.icon,
    Data = <<X:16, Y:16, Id:32, Mid:32, Hp:32, Mp:32, Hp_lim:32, Mp_lim:32, Lv:16, Len:16, Name1/binary, Speed:16, Icon:32>>,
    {ok, pt:pack(12007, Data)};

%%怪物移动
write(12008, [X, Y, Id]) ->
    Data = <<X:16, Y:16, Id:32>>,
    {ok, pt:pack(12008, Data)};

%%使用物品或者装备物品
write(12009, [PlayerId, HP, HP_lim]) ->
    {ok, pt:pack(12009, <<PlayerId:32, HP:32, HP_lim:32>>)};

%%乘上坐骑或者离开坐骑
write(12010, [PlayerId, PlayerSpeed, MountTypeId]) ->
    {ok, pt:pack(12010, <<PlayerId:32, PlayerSpeed:16, MountTypeId:32>>)};

%%加场景信息
write(12011, [User1, User2]) ->
    Data1 = pt:pack_role_list(User1),
    Data2 = pack_leave_list(User2),
    Data = << Data1/binary, Data2/binary>>,
    {ok, pt:pack(12011, Data)};

%%装备物品
write(12012, [PlayerId, GoodsTypeId, Subtype, HP, HP_lim]) ->
    {ok, pt:pack(12012, <<PlayerId:32, GoodsTypeId:32, Subtype:16, HP:32, HP_lim:32>>)};

%%卸下装备
write(12013, [PlayerId, GoodsTypeId, Subtype, HP, HP_lim]) ->
    {ok, pt:pack(12013, <<PlayerId:32, GoodsTypeId:32, Subtype:16, HP:32, HP_lim:32>>)};

%%使用物品
write(12014, [PlayerId, GoodsTypeId, HP, HP_lim]) ->
    {ok, pt:pack(12014, <<PlayerId:32, GoodsTypeId:32, HP:32, HP_lim:32>>)};

%%装备磨损
write(12015, [PlayerId, HP, HP_lim, GoodsList]) ->
    ListNum = length(GoodsList),
    F = fun(GoodsInfo) ->
            GoodsId = GoodsInfo#goods.goods_id,
            Subtype = GoodsInfo#goods.subtype,
            <<GoodsId:32, Subtype:16>>
        end,
    ListBin = list_to_binary(lists:map(F, GoodsList)),
    {ok, pt:pack(12015, <<PlayerId:32, HP:32, HP_lim:32, ListNum:16, ListBin/binary>>)};

%%切换装备
write(12016, [PlayerId, HP, HP_lim, GoodsList]) ->
    ListNum = length(GoodsList),
    F = fun(GoodsInfo) ->
            GoodsId = GoodsInfo#goods.goods_id,
            Subtype = GoodsInfo#goods.subtype,
            <<GoodsId:32, Subtype:16>>
        end,
    ListBin = list_to_binary(lists:map(F, GoodsList)),
    {ok, pt:pack(12016, <<PlayerId:32, HP:32, HP_lim:32, ListNum:16, ListBin/binary>>)};

%%掉落包生成
write(12017, [RealMonId, Time, X, Y]) ->
     {ok, pt:pack(12017, <<RealMonId:32, Time:16, X:16, Y:16>>)};

%%某玩家成为队长(卸任队长)时通知场景
write(12018, [Id, Type]) ->
    {ok, pt:pack(12018, <<Id:32, Type:8>>)};

%%掉落包消失
write(12019, DropId) ->
     {ok, pt:pack(12019, <<DropId:32>>)};

%% 改变NPC状态图标
write(12020, []) ->
    {ok, pt:pack(12020, <<>>)};
write(12020, [NpcList]) ->
    NL = length(NpcList),
    Bin = list_to_binary([<<Id:32, Ico:8>> || [Id, Ico] <- NpcList]),
    Data = <<NL:16, Bin/binary>>,
    {ok, pt:pack(12020, Data)};

%%退出副本
write(12030, State) ->
    {ok, pt:pack(12030, <<State:8>>)};

%% 打包场景相邻关系数据
write(12080, [L]) ->
    Len = length(L),
    Bin = pack_scene_border(L, []),
    {ok, pt:pack(12080, <<Len:16, Bin/binary>>)};

%%更新怪物血量
write(12081, [Id, Hp]) ->
     {ok, pt:pack(12081, <<Id:32, Hp:32>>)};

write(_Cmd, _R) ->
    {ok, pt:pack(0, <<>>)}.


%% 打包元素列表
pack_elem_list([]) ->
    <<0:16, <<>>/binary>>;
pack_elem_list(Elem) ->
    Rlen = length(Elem),
    F = fun([Sid, Name, X, Y]) ->
        Len = byte_size(Name),
        <<Sid:32, Len:16, Name/binary, X:16, Y:16>>
    end,
    RB = list_to_binary([F(D) || D <- Elem]),
    <<Rlen:16, RB/binary>>.

%% 打包NPC列表
pack_npc_list([]) ->
    <<0:16, <<>>/binary>>;
pack_npc_list(Npc) ->
    Rlen = length(Npc),
    F = fun([Id, Nid, Name, X, Y, Icon]) ->
        Len = byte_size(Name),
        <<Id:32, Nid:32, Len:16, Name/binary, X:16, Y:16, Icon:32>>
    end,
    RB = list_to_binary([F(D) || D <- Npc]),
    <<Rlen:16, RB/binary>>.

%% 打包场景相邻关系数据
pack_scene_border([], Result) ->
    list_to_binary(Result);
pack_scene_border([{Id, Border} | T], Result) ->
    L = length(Border),
    B = list_to_binary([<<X:32>> || X <- Border]),
    Bin = <<Id:32, L:16, B/binary>>,
    pack_scene_border(T, [Bin | Result]).

%% 打包元素列表
pack_leave_list([]) ->
    <<0:16, <<>>/binary>>;
pack_leave_list(User) ->
    Rlen = length(User),
    RB = list_to_binary([<<Id:32>> || Id <- User]),
    <<Rlen:16, RB/binary>>.

trans_to_12003(Status) ->
    [Status#player_status.id, Status#player_status.nickname, Status#player_status.x, Status#player_status.y, Status#player_status.hp, Status#player_status.hp_lim, Status#player_status.mp, Status#player_status.mp_lim, Status#player_status.lv, Status#player_status.career, Status#player_status.speed, Status#player_status.equip_current, Status#player_status.sex, Status#player_status.leader].
