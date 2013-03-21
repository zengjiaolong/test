%%%-----------------------------------
%%% @Module  : pt_21
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 21技能信息
%%%-----------------------------------
-module(pt_21).
-export([read/2, write/2]).
-include("common.hrl").
%%
%%客户端 -> 服务端 ----------------------------
%%

%%主动技能升级
read(21001, <<Id:32>>) ->
    {ok, Id};

%%主动技能列表
read(21002, _) ->
    {ok, list};

%%被动技能升级 (以协议号做区分)
read(21004, <<Id:32>>) ->
    {ok, Id};

%%被动技能列表 (以协议号做区分)
read(21005, _) ->
    {ok, list};

%%使用夫妻传送技能
read(21006,_)->
	{ok,[]}; 

%%轻功技能等级信息
%%read(21003, Bin) ->
%%    {ok, Bin};


read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%% 主动技能升级
write(21001, [State, Msg, SkillId]) ->
    L = byte_size(Msg),
    {ok, pt:pack(21001, <<State:8, L:16, Msg/binary, SkillId:32>>)};

%%获取主动技能列表
write(21002, [All, Skill]) ->
	Data = skill_list([All, Skill]),
    {ok, pt:pack(21002, Data)};

%%轻功技能等级信息
write(21003, [Res]) ->
    {ok, pt:pack(21003, <<Res:8>>)};

%% 被动技能升级
write(21004, [State, Msg, SkillId]) ->
    L = byte_size(Msg),
    {ok, pt:pack(21004, <<State:8, L:16, Msg/binary, SkillId:32>>)};

%%获取被动技能列表
write(21005, [All, Skill]) ->
	Data = skill_list([All, Skill]),
    {ok, pt:pack(21005, Data)};

%%使用夫妻传送技能
write(21006,[Err,Cd])->
	{ok,pt:pack(21006, <<Err:16,Cd:32>>)};

write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
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
    RB = tool:to_binary([F(D) || D <- All]),
    <<Rlen:16, RB/binary>>.
