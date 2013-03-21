%%%-----------------------------------
%%% @Module  : pt_29
%%% @Author  : ygzj
%%% @Created : 2010.11.23
%%% @Description: 29防沉迷
%%%-----------------------------------
-module(pt_29).
-export([read/2, write/2]).
-include("common.hrl").

%%
%%客户端 -> 服务端 ----------------------------
%%

%%填写防沉迷信息
read(29000, <<Idcard_status:8, Bin/binary>>) ->
    {Idcardnum, _} = pt:read_string(Bin),
    {ok, [Idcard_status, Idcardnum]};

%%累计游戏时间查询
read(29002, _) ->
    {ok, eqtime};

%%我未成年（暂时不填身份证 信息）
read(29003, _) ->
    {ok, infant}.

%%服务端  -> 客户端 ----------------------------

%%填写防沉迷信息返回
write(29000, Code) ->
%% ?DEBUG("Put_29000_~p",[Code]),
    Data = <<Code:8>>,
    {ok, pt:pack(29000, Data)};


%%防沉迷5分钟离线通知
write(29001, _) ->
    Data = <<>>,
    {ok, pt:pack(29001, Data)};
    
    
%%累计游戏时间查询返回
write(29002, [Idcard_status, Gametime]) ->
    Data = <<Idcard_status:8,
			 Gametime:32>>,
    {ok, pt:pack(29002, Data)};

%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.