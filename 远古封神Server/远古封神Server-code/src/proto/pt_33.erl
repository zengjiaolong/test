%%%-----------------------------------
%%% @Module  : pt_33
%%% @Author  : lzz
%%% @Created : 2010.11.29
%%% @Description: 33凝神修炼
%%%-----------------------------------
-module(pt_33).
-export([read/2, write/2]).

-include("common.hrl").
-include("record.hrl").


%%
%%客户端 -> 服务端 ----------------------------
%%

%%打开凝神修炼
read(33000, _) ->
    {ok, open_exc};

%%开始修炼
read(33001, <<Ty:8, Tm:8>>) ->
%% ?DEBUG("33001_get_~p/~p ~n",[Ty, Tm]),
    {ok, [Ty, Tm]};

%%取消修炼
read(33002, _) ->
    {ok, cancel};

%%加速修炼
read(33004, <<Ty:8>>) ->
    {ok, [Ty]};

read(33005, <<Type:8>>) ->
%% ?DEBUG("33005_get_~p/~p ~n",[33005, 33005]),
    {ok, [Type]};

%%查询经验找回信息
read(33006,_)->
	{ok,[]};

%%兑换经验找回
read(33007,<<Id:32,ConvertType:8,Color:16>>)->
	{ok,[Id,ConvertType,Color]};

%%一键兑换经验找回
read(33008,<<Type:8>>)->
	{ok,[Type]};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%


%%打开凝神修炼返回
write(33000, [Sta, Tleft, Ttol, Exp, Spr, Tok, Costc, Costg, Costcn, Costgn, Spd10, Spd60, Gldn, Lvn]) ->
%% ?DEBUG("33000_return_~p/~p/~p/~p/~p/~p/~p/~p/~p/~p/~p/~p/~p/~p ~n",[Sta, Tleft, Ttol, Exp, Spr, Tok, Costc, Costg, Costcn, Costgn, Spd10, Spd60, Gldn, Lvn]),	
    {ok, pt:pack(33000, <<Sta:8, Tleft:32, Ttol:16, Exp:16, Spr:16, Tok:16, Costc:16, Costg:16, Costcn:16, Costgn:16, Spd10:8, Spd60:16, Gldn:32, Lvn:8>>)};


%%开始修炼返回
write(33001, [Sta, Gleft, Cleft, Bcleft, This_time]) ->
%% ?DEBUG("33001_return_~p/~p/~p/~p/~p ~n",[Sta, Gleft, Cleft, Bcleft, This_time]),		
    {ok, pt:pack(33001, <<Sta:8, Gleft:32, Cleft:32, Bcleft:32, This_time:16>>)};
    
    
%%取消修炼返回
write(33002, [Gleft, Cleft]) ->
%% ?DEBUG("33002_return_~p/~p ~n",[Gleft, Cleft]),	
    {ok, pt:pack(33002, <<Gleft:32, Cleft:32>>)};
   
%%修炼完成返回
write(33003, _) ->
		Data = <<>>,
%% ?DEBUG("33003_return_~p ~n",[Data]),		
    {ok, pt:pack(33003, Data)};

%%加速修炼返回
write(33004, [Sta, Gleft, Ty]) ->
%% ?DEBUG("33004_return_~p/~p/~p ~n",[Sta, Gleft, Ty]),	
    {ok, pt:pack(33004, <<Sta:8, Gleft:32, Ty:8>>)};

%%传送至修炼区
write(33005, [Sta, Gleft]) ->
%% ?DEBUG("33005_return_~p/~p ~n",[Sta, Gleft]),	
    {ok, pt:pack(33005, <<Sta:8, Gleft:32>>)};

%%查询经验找回信息
%% array(
%% 		int16 活动类型
%% 		int32找回时间
%% 		int16次数
%% 		int16 等级
%% 		int32 经验
%% 		int32 灵力
%% 	)
write(33006,Data)->
	NowTime = util:unixtime(),
	Mult = lib_find_exp:check_mult(NowTime,1),
	Len = length(Data),
	Bin = tool:to_binary(pack_find_exp(Data,[],Mult)),
	{ok,pt:pack(33006,<<Len:16,Bin/binary>>)};

%%兑换经验找回
write(33007,[Res,Color])->
	{ok,pt:pack(33007,<<Res:16,Color:16>>)};

%%一键找回
write(33008,[Res])->
	{ok,pt:pack(33008,<<Res:16>>)};

%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.

pack_find_exp([],Bin,_Mult)->Bin;
pack_find_exp([Info|Data],Bin,Mult)->
	Id = Info#ets_find_exp.id,
	Name = Info#ets_find_exp.name,
	Name1 = tool:to_binary(Name),
	Len = byte_size(Name1),
	Type = Info#ets_find_exp.type,
	Timestamp = Info#ets_find_exp.timestamp,
	Times= Info#ets_find_exp.times,
	Lv=Info#ets_find_exp.lv,
	Exp = round(Info#ets_find_exp.exp * Mult),
	Spt = round(Info#ets_find_exp.spt * Mult),
	Gold=lib_find_exp:gold(Type),
	pack_find_exp(Data,[<<Id:32,Len:16,Name1/binary,Type:16,Timestamp:32,Times:16,Lv:16,Exp:32,Spt:32,Gold:16>>|Bin],Mult).
	