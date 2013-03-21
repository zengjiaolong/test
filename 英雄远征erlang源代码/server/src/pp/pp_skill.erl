%%%--------------------------------------
%%% @Module  : pp_skill
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.07.27
%%% @Description:  技能管理
%%%--------------------------------------
-module(pp_skill).
-export([handle/3]).
-include("common.hrl").
-include("record.hrl").

%%学习技能
handle(21001, Status, SkillId) ->
    lib_skill:upgrade_skill(Status, SkillId);

%%获取技能列表
handle(21002, Status, _) ->
    All = data_skill:get_ids(Status#player_status.career),
    {ok, BinData} = pt_21:write(21002, [All, Status#player_status.skill]),
    lib_send:send_one(Status#player_status.socket, BinData);

handle(_Cmd, _Status, _Data) ->
    {error, "pp_skill no match"}.