%%%-----------------------------------
%%% @Module  : pt_21
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.07.27
%%% @Description: 21技能信息
%%%-----------------------------------
-module(pt_21).
-export([read/2, write/2]).

%%
%%客户端 -> 服务端 ----------------------------
%%

%%技能升级
read(21001, <<Id:32>>) ->
    {ok, Id};

%%技能列表
read(21002, _) ->
    {ok, list};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%%技能升级
write(21001, [State, Msg]) ->
    L = byte_size(Msg),
    {ok, pt:pack(21001, <<State:8, L:16, Msg/binary>>)};

%%获取技能列表
write(21002, [All, Skill]) ->
    {ok, pt:pack(21002, skill_list([All, Skill]))};

write(_Cmd, _R) ->
    {ok, pt:pack(0, <<>>)}.

skill_list([]) ->
    <<0:16, <<>>/binary>>;
skill_list([All, Skill]) ->
    Rlen = length(All),
    F = fun(SkillId) ->
        case lists:keyfind(SkillId, 1, Skill) of
            false ->
                <<SkillId:32, 0:8>>;
            {_, Lv} ->
                <<SkillId:32, Lv:8>>
        end
    end,
    RB = list_to_binary([F(D) || D <- All]),
    <<Rlen:16, RB/binary>>.