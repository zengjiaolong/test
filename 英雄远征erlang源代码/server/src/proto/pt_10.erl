%%%-----------------------------------
%%% @Module  : pt_10
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.04.29
%%% @Description: 10帐户信息
%%%-----------------------------------
-module(pt_10).
-export([read/2, write/2]).

%%
%%客户端 -> 服务端 ----------------------------
%%

%%登陆
read(10000, <<Accid:32, Tstamp:32, Bin/binary>>) ->
    {Accname, Bin1} = pt:read_string(Bin),
    {Ticket, _} = pt:read_string(Bin1),
    {ok, login, [Accid, Accname, Tstamp, Ticket]};

%%退出
read(10001, _) ->
    {ok, logout};

%%读取列表
read(10002, _R) ->
    {ok, lists, []};

%%创建角色
read(10003, <<Realm:8, Career:8, Sex:8, Bin/binary>>) ->
    {Name1, _} = pt:read_string(Bin),
    {ok, create, [Realm, Career, Sex, Name1]};

%%选择角色进入游戏
read(10004, <<Id:32>>) ->
    {ok, enter, Id};

%%删除角色
read(10005, <<Id:32>>) ->
    {ok, delete, Id};

%%心跳包
read(10006, _) ->
    {ok, heartbeat};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%%网关登陆
write(9999, [Host, Port]) ->
    HL = byte_size(Host),
    Data = <<HL:16, Host/binary, Port:16>>,
    {ok, pt:pack(9999, Data)};

%%登陆返回
write(10000, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(10000, Data)};

%%登陆退出
write(10001, _) ->
    Data = <<>>,
    {ok, pt:pack(10001, Data)};

%% 打包角色列表
write(10002, []) ->
    N = 0,
    LB = <<>>,
    {ok, pt:pack(10002, <<N:16, LB/binary>>)};
write(10002, L) ->
    N = length(L),
    F = fun([Pid, Status, Name, Sex, Lv, Career]) ->
            NL = byte_size(Name),
            <<Pid:32, Status:16, Career:16, Sex:16, Lv:16, NL:16, Name/binary>>
    end,
    LB = list_to_binary([F(X) || X <- L]),
    {ok, pt:pack(10002, <<N:16, LB/binary>>)};

%%创建角色
write(10003, Code) ->
    Data = <<Code:16>>,
    {ok,  pt:pack(10003, Data)};

%%选择角色进入游戏
write(10004, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(10004, Data)};

%%删除角色
write(10005, Code) ->
    Data = <<Code:16>>,
    {ok, pt:pack(10005, Data)};

%%心跳包
write(10006, _) ->
    Data = <<>>,
    {ok, pt:pack(10006, Data)};

%%账号在别处登陆
write(10007, _) ->
    Data = <<>>,
    {ok, pt:pack(10007, Data)};

write(_Cmd, _R) ->
    {ok, pt:pack(0, <<>>)}.