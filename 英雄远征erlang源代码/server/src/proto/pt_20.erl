%%%-----------------------------------
%%% @Module  : pt_20
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.04.29
%%% @Description: 20战斗信息
%%%-----------------------------------
-module(pt_20).
-export([read/2, write/2]).

%%
%%客户端 -> 服务端 ----------------------------
%%

%%人打怪
read(20001, <<Id:32, Sid:32>>) ->
    {ok, [Id, Sid]};

%%人打人
read(20002, <<Id:32, Sid:32>>) ->
    {ok, [Id, Sid]};

%%复活
read(20004, _) ->
    {ok, <<>>};

%%使用辅助技能
read(20006, <<Id:32, Sid:32>>) ->
    {ok, [Id, Sid]};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%%广播战斗结果 - 玩家PK怪
write(20001, [Id, Hp, Mp, Sid, X, Y, DefList]) ->
    Data1 = <<Id:32, Hp:32, Mp:32, Sid:32, X:16, Y:16>>,
    Data2 = def_list(DefList),
    Data = << Data1/binary, Data2/binary>>,
    {ok, pt:pack(20001, Data)};

%%广播战斗结果 - 玩家PK玩家
%write(20002, [Pid1, Pid2, Hurt, Sid, Hp1, Mp1, Hp2, Mp2, S]) ->
%    Data = <<Pid1:32, Hp1:32, Mp1:32, Pid2:32, Hp2:32, Mp2:32, Hurt:32, Sid:16, S:8>>,
%    {ok, pt:pack(20002, Data)};

%%广播战斗结果 - 怪PK玩家
write(20003, [Id, Hp, Mp, Sid, X, Y, DefList]) ->
    Data1 = <<Id:32, Hp:32, Mp:32, Sid:32, X:16, Y:16>>,
    Data2 = def_list(DefList),
    Data = << Data1/binary, Data2/binary>>,
    {ok, pt:pack(20003, Data)};

%%广播战斗结果 - 怪PK玩家
write(20005, [State, Sign1, User1, Hp1, X1, Y1, Sign2, User2, Hp2, X2, Y2]) ->
    {ok, pt:pack(20005, <<State:8, Sign1:8, User1:32, Hp1:32, X1:16, Y1:16, Sign2:8, User2:32, Hp2:32, X2:16, Y2:16>>)};

%%广播战斗结果 - 辅助技能
write(20006, [Id, Sid, MP, List]) ->
    Data1 = <<Id:32, Sid:32, MP:32>>,
    Data2 = assist_list(List),
    Data = << Data1/binary, Data2/binary>>,
    {ok, pt:pack(20006, Data)};

write(_Cmd, _R) ->
    {ok, pt:pack(0, <<>>)}.

def_list([]) ->
    <<0:16, <<>>/binary>>;
def_list(DefList) ->
    Rlen = length(DefList),
    F = fun([Sign, Id, Hp, Mp, Hurt, S]) ->
        <<Sign:8, Id:32, Hp:32, Mp:32, Hurt:32, S:8>>
    end,
    RB = list_to_binary([F(D) || D <- DefList]),
    <<Rlen:16, RB/binary>>.

assist_list([]) ->
    <<0:16, <<>>/binary>>;
assist_list(List) ->
    Rlen = length(List),
    F = fun([Id, Hp]) ->
        <<Id:32, Hp:32>>
    end,
    RB = list_to_binary([F(D) || D <- List]),
    <<Rlen:16, RB/binary>>.