%%%-----------------------------------
%%% @Module  : pt_43
%%% @Author  : lzz
%%% @Created : 2011.05.05
%%% @Description: 封神台
%%%-----------------------------------
-module(pt_43).
-export([read/2, write/2]).

-include("common.hrl").
-include("record.hrl").


%%
%%客户端 -> 服务端 ----------------------------
%%
%%TD info
read(43001, _) ->
    {ok, td_info};

%%退出TD
read(43002, _) ->
    {ok, quit};

%%护卫信息
read(43004, _) ->
%% %% ?DEBUG("35003_get_~p ~n",[Loc]),
    {ok, def_info};

%%护卫信息
read(43005, <<Def:8>>) ->
%% ?DEBUG("43005_get_~p ~n",[Def]),
    {ok, Def};

%%升级/修复护卫信息
read(43006, <<Def:8>>) ->
%% ?DEBUG("43006_get_~p ~n",[Def]),
    {ok, Def};

%% query hor sum
read(43007, _) ->
%% ?DEBUG("43007_get_~p ~n",[hor_sum]),
    {ok, hor_sum};

%% 加速刷怪
read(43008, _) ->
%% ?DEBUG("43007_get_~p ~n",[hor_sum]),
    {ok, get_mon};

%% 单人镇妖台进入
read(43009,<<Attnum:8>>) ->
	{ok,[Attnum]};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%


%%TD info
write(43000, [Info_type, Info]) ->
%% %% ?DEBUG("35000_return_~p/~p/~p/~p ~n",[Loc, Hor, Exp, Spr]),	
    {ok, pt:pack(43000, <<Info_type:8, Info:32>>)};

%%TD info
write(43001, [Att_num, Next_att_time, Mgc_td, Hor_td, Som_num]) ->
%% ?DEBUG("43001_return_~p/~p/~p/~p ~n",[Att_num, Next_att_time, Mgc_td, Hor_td]),	
    {ok, pt:pack(43001, <<Att_num:8, Next_att_time:8, Mgc_td:32, Hor_td:32, Som_num:8>>)};
    
%%leave TD
write(43002, _) ->
    {ok, pt:pack(43002, <<>>)};
   
%% 镇妖台结果面板信息
%% AttNum 波数
%% Exp 经验
%% Spirit 灵力
%% Horon 荣誉
write(43003, [AttNum, Exp, Spirit, Horon]) ->
  	{ok, pt:pack(43003, <<AttNum:8, Exp:32, Spirit:32, Horon:32>>)};

%%TD def info
write(43004, [Def_0, Def_1, Def_2, Def_3, Som_num]) ->
%% ?DEBUG("43004_return_~p ~n",[[Def_0, Def_1, Def_2, Def_3, Som_num]]),
    {ok, pt:pack(43004, <<Def_0:8, Def_1:8, Def_2:8, Def_3:8, Som_num:8>>)};

%%TD Skill
write(43005, [Res, Def]) ->
%% ?DEBUG("43005_return_~p ~n",[Res]),		
    {ok, pt:pack(43005, <<Res:8, Def:8>>)};

%%TD up
write(43006, [Res, Skill, Skill_lv]) ->
%% %% ?DEBUG("43005_return_~p ~n",[Res]),		
    {ok, pt:pack(43006, <<Res:8, Skill:8, Skill_lv:8>>)};

%%TD sum
write(43007, Hor) ->
%% %% ?DEBUG("43007_return_~p ~n",[Res]),		
    {ok, pt:pack(43007, <<Hor:32>>)};

%% 加速刷怪
write(43008, Res) ->
%% %% ?DEBUG("43007_return_~p ~n",[Res]),		
    {ok, pt:pack(43008, <<Res:8>>)};

%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.

