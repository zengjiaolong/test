%%%-----------------------------------
%%% @Module  : pt_44
%%% @Author  : ygzj
%%% @Created : 2011.09.03
%%% @Description: 评价模块
%%%-----------------------------------
-module(pt_44).
-export([read/2, write/2]).

-include("common.hrl").
-include("record.hrl").


%%
%%客户端 -> 服务端 ----------------------------
%%
%%查看玩家评价信息
read(44000, <<Other_Id:32>>) ->
    {ok, Other_Id};

%%玩家评价被崇拜(2),被鄙视(3)
read(44001, <<Other_Id:32, Type:8>>) ->
    {ok, [Other_Id,Type]};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%
write(44000, [Type1Num, Type2Num, Nickname, Remain_Twice,Fans_Id, Level, Career, Sex]) ->
	NickName = tool:to_binary(Nickname),
	Nick_len = byte_size(NickName),
	{ok, pt:pack(44000, <<Type1Num:16, Type2Num:16,  Nick_len:16, NickName/binary, Remain_Twice:8, Fans_Id:32, Level:16, Career:8, Sex:8>>)};
		
	
	
write(44001, [Result]) ->
	{ok, pt:pack(44001, <<Result:8>>)};

%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.

