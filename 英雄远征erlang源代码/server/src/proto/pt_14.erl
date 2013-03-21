%%%--------------------------------------
%%% @Module  : pt_14
%%% @Author  : zzm
%%% @Email   : ming_up@163.com
%%% @Created : 2010.06.07
%%% @Description:  14玩家间关系信息
%%%--------------------------------------
-module(pt_14).
-export([read/2, write/2]).

%%
%%客户端 -> 服务端 ----------------------------
%%

%%请求好友列表
read(14000, _R) ->
    {ok, []};

%%添加好友请求
read(14001,<<Type:16, Id:32, Bin/binary>>) ->
    {Nick, _} = pt:read_string(Bin),
    {ok, [Type, Id, Nick]};

%%回应添加好友请求
read(14002,<<Type:16, Res:16, Id:32>>) ->
    {ok,[Type, Res, Id]};

%%删除好友
read(14003, <<Id:32>>) ->
    {ok, Id};

%%添加黑名单
read(14004, <<Id:32>>) ->
    {ok, Id};

%%添加仇人
read(14005, <<Id:32>>) ->
    {ok, Id};

%%改变好友分组名字
read(14006, <<N:16, Bin/binary>>) ->
    {Gname, _} = pt:read_string(Bin),
    {ok, [N, Gname]};

%%请求黑名单列表
read(14007, _R) ->
    {ok, []};

%%请求仇人列表
read(14008, _R) ->
    {ok, []};

%%移动好友到别的分组
read(14009, <<Uid:32, N:16>>) ->
    {ok, [Uid, N]};

%%查找角色
read(14010, <<Bin/binary>>) ->
    {Nick, _} = pt:read_string(Bin),
    {ok, Nick};

%%设置自动回复
%read(14012, <<AutoRes:16, Bin/binary>>) ->
%    {Msg, _} = pt:read_string(Bin),
%    {ok, [AutoRes, Msg]};

%%查询陌生人资料
read(14013, <<Id:32>>) ->
    {ok, Id};

%%删除黑名单
read(14020, <<Id:32>>) ->
    {ok, Id};

%%删除仇人
read(14021, <<Id:32>>) ->
    {ok, Id};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%%打包好友信息
write(14000, [[],[]]) ->
    GLen = 0,
    N = 0,
    LA = <<>>,
    LB = <<>>,
      Data = <<GLen:16, LA/binary ,N:16, LB/binary>>,
    {ok, pt:pack(14000, Data)};
write(14000, [GL,[]]) ->
    GLen = length(GL),
    F1 = fun(GroupName) ->
            GNL = byte_size(GroupName),
            <<GNL:16, GroupName/binary>>
    end,
    LA = list_to_binary([F1(X) || X <- GL]),
    N = 0,
    LB = <<>>,
      Data = <<GLen:16, LA/binary ,N:16, LB/binary>>,
    {ok, pt:pack(14000, Data)};
write(14000,[GL, L]) ->
    GLen = length(GL),
    N = length(L),
    F = fun([Online, IdB, Intimacy, Group, Lv, Sex, Career, Nick, Id]) ->
            NL = byte_size(Nick),
            <<Online:16, IdB:32, Intimacy:32, Group:16, Lv:16, Sex:16, Career:16, NL:16, Nick/binary, Id:32>>
    end,
    F1 = fun(GroupName) ->
            GNL = byte_size(GroupName),
            <<GNL:16, GroupName/binary>>
    end,
    LA = list_to_binary([F1(X) || X <- GL]),
    LB = list_to_binary([F(X) || X <- L, X /= []]),
    Data = <<GLen:16, LA/binary, N:16, LB/binary>>,
    {ok, pt:pack(14000, Data)};

%%添加好友请求
write(14001, [Type, Id, Lv, _Sex, Career, Nick]) ->
    Nick1 = list_to_binary(Nick),
    Len = byte_size(Nick1),
    Data = <<Type:16, Id:32, Lv:16, Career:16, Len:16, Nick1/binary>>,
    {ok, pt:pack(14001, Data)};

%%回应者不在线/不存在此用户名/发送者被加黑名单
write(14002, [Res]) ->
    Nick1 = <<>>,
    Data = <<Res:16, 0:32, 0:16, 0:16, 0:16, Nick1/binary>>,
    {ok, pt:pack(14002, Data)};
%%回应添加好友请求
write(14002, [Res, Id, Lv, _Sex, Career, Nick]) ->
    Data = case is_binary(Nick) of
            true ->
                Len = byte_size(Nick),
                <<Res:16, Id:32, Lv:16, Career:16, Len:16, Nick/binary>>;
            false ->
                Nick1 = list_to_binary(Nick),
                Len = byte_size(Nick1),
                <<Res:16, Id:32, Lv:16, Career:16, Len:16, Nick1/binary>>
    end,
    {ok, pt:pack(14002, Data)};

%删除好友
write(14003, N) ->
    Data = <<N:16>>,
    {ok, pt:pack(14003, Data)};

%%添加黑名单
write(14004, [Res, Id]) ->
    Data = <<Res:16, Id:32>>,
    {ok, pt:pack(14004,Data)};

%%添加仇人
write(14005, [Res, Id]) ->
    Data = <<Res:16, Id:32>>,
    {ok, pt:pack(14005, Data)};

%%改变好友分组名字
write(14006, Res) ->
    Data = <<Res:16>>,
    {ok, pt:pack(14006, Data)};

%%请求黑名单列表
write(14007, L) ->
    N = length(L),
    F = fun([IdB, Lv, Sex, Career, Nick, Rid]) ->
            NL = byte_size(Nick),
            <<IdB:32, Lv:16, Sex:16, Career:16, NL:16, Nick/binary, Rid:32>>
    end,
    LB = list_to_binary([F(X) || X <- L, X /= []]),
    Data = <<N:16, LB/binary>>,
    {ok, pt:pack(14007, Data)};

%%请求仇人列表
write(14008, L) ->
    N = length(L),
    F = fun([Online, IdB, Lv, Sex, Career, Nick, Rid]) ->
            NL = byte_size(Nick),
            <<Online:16, IdB:32, Lv:16, Sex:16, Career:16, NL:16, Nick/binary, Rid:32>>
    end,
    LB = list_to_binary([F(X) || X <- L, X /= []]),
    Data = <<N:16, LB/binary>>,
    {ok, pt:pack(14008, Data)};

%%移动好友到别的分组
write(14009, N) ->
    Data = <<N:16>>,
    {ok, pt:pack(14009, Data)};

%%查找角色
write(14010, []) ->
    GuildName = <<>>,
    Nick = <<>>,
    Data = <<0:16, 0:32, 0:16, 0:16, 0:16, 0:16, GuildName/binary, 0:16, Nick/binary>>,
    {ok, pt:pack(14010, Data)};
write(14010, [1, Id, Lv, Sex, Career, GuildName, Nick]) ->
    GuildName1 = list_to_binary(GuildName),
    Nick1 = list_to_binary(Nick),
    L1 = byte_size(GuildName1),
    L2 = byte_size(Nick1),
    Data = <<1:16, Id:32, Lv:16, Sex:16, Career:16, L1:16, GuildName1/binary, L2:16, Nick1/binary>>,
    {ok, pt:pack(14010, Data)};

%%发送自动回复设置
%write(14011, [AutoRes, Msg]) ->
%    L = byte_size(Msg),
%    Data = <<AutoRes:16, L:16, Msg/binary>>,
%    {ok, pt:pack(14011, Data)};

%%设置自动回复设置
%write(14012, Res) ->
%    Data = <<Res:16>>,
%    {ok, pt:pack(14011, Data)};

%%查询陌生人资料
write(14013, [Id, Lv, Sex, Career, Nick]) ->
    Nick1 = list_to_binary(Nick),
    L = byte_size(Nick1),
    Data = <<Id:32, Lv:16, Sex:16, Career:16, L:16, Nick1/binary>>,
    {ok, pt:pack(14013, Data)};

%%删除黑名单
write(14020, N) ->
    Data = <<N:16>>,
    {ok, pt:pack(14020, Data)};

%%删除仇人
write(14021, N) ->
    Data = <<N:16>>,
    {ok, pt:pack(14021, Data)};

%%好友上下线通知
write(14030, [Uid, Line, Nick]) ->
    Nick1 = list_to_binary(Nick),
    L = byte_size(Nick1),
    Data = <<Uid:32, Line:16, L:16, Nick1/binary>>,
    {ok, pt:pack(14030, Data)};

%%仇人上下线通知
write(14031, [Uid, Line, Nick]) ->
    Nick1 = list_to_binary(Nick),
    L = byte_size(Nick1),
    Data = <<Uid:32, Line:16, L:16, Nick1/binary>>,
    {ok, pt:pack(14031, Data)};

write(_Cmd, _R) ->
    {ok, pt:pack(0, <<>>)}.
