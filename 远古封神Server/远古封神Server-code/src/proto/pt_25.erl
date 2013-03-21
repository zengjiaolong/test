%%%------------------------------------
%%% @Module  : pt_25
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 经脉协议
%%%------------------------------------

-module(pt_25).
-export([read/2, write/2]).
-include("common.hrl").

%%
%%客户端 -> 服务端 ----------------------------
%%

%%是否有可修炼检测
read(25010, <<>>) ->
    {ok, []};

%%查看经脉信息
read(25020, <<PlayerId:32>>) ->
    {ok, PlayerId};

%%查看经脉属性
read(25030, <<PlayerId:32,MeridianId:16>>) ->
    {ok, [PlayerId,MeridianId]};

%%经脉升级
read(25040,<<MeridianId:16>>) ->
	{ok,MeridianId};

%%取消经脉升级
read(25050,<<MeridianId:16>>)->
	{ok,MeridianId};

%%经脉修炼加速
read(25060,<<MeridianId:16,GoodsId:16>>)->
	{ok,[MeridianId,GoodsId]};

%%经脉灵根洗练
read(25070,<<MeridianId:16,IsSave:8,AutoPay:8>>)->
	{ok,[MeridianId,IsSave,AutoPay]};

%%加速物品信息
read(25080,<<MeridianId:16>>)->
	{ok,MeridianId};
%%经脉突破
read(25090,<<MerId:16>>)->
	{ok,[MerId]};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%
write(25010,[Result])->
	{ok,pt:pack(25010,<<Result:8>>)};

write(25011,Msg)->
    Msg1 = tool:to_binary(Msg),
    Len1 = byte_size(Msg1),
    Data = <<Len1:16, Msg1/binary>>,
    {ok, pt:pack(25011, Data)};

write(25020,[PlayerId1,Mer_YX,Lvl1,LG1,Top1,E1,EN1,T1,
			PlayerId2,Mer_YQ,Lvl2,LG2,Top2,E2,EN2,T2,
			PlayerId3,Mer_YW1,Lvl3,LG3,Top3,E3,EN3,T3,
			PlayerId4,Mer_RM,Lvl4,LG4,Top4,E4,EN4,T4,
			PlayerId5,Mer_DM1,Lvl5,LG5,Top5,E5,EN5,T5,
			PlayerId6,Mer_CM,Lvl6,LG6,Top6,E6,EN6,T6,
			PlayerId7,Mer_YW2,Lvl7,LG7,Top7,E7,EN7,T7,
			PlayerId8,Mer_DM2,Lvl8,LG8,Top8,E8,EN8,T8
			])->
%% 	io:format("Here is Msg L:~p~n",[Msg]),
%% 	Msg1 = tool:to_binary(Msg),
%%     L = byte_size(Msg1),
%% 	io:format("Here is Msg L:~p~n",[L]),
%% 	{ok,pt:pack(25020,<<L:16,Msg1/binary>>)};
	{ok,pt:pack(25020,<<8:16,PlayerId1:32,Mer_YX:16,Lvl1:16,LG1:16,Top1:16,E1:16,EN1:16,T1:32,
						PlayerId2:32,Mer_YQ:16,Lvl2:16,LG2:16,Top2:16,E2:16,EN2:16,T2:32,
						PlayerId3:32,Mer_YW1:16,Lvl3:16,LG3:16,Top3:16,E3:16,EN3:16,T3:32,
						PlayerId4:32,Mer_RM:16,Lvl4:16,LG4:16,Top4:16,E4:16,EN4:16,T4:32,
						PlayerId5:32,Mer_DM1:16,Lvl5:16,LG5:16,Top5:16,E5:16,EN5:16,T5:32,
						PlayerId6:32,Mer_CM:16,Lvl6:16,LG6:16,Top6:16,E6:16,EN6:16,T6:32,
						PlayerId7:32,Mer_YW2:16,Lvl7:16,LG7:16,Top7:16,E7:16,EN7:16,T7:32,
						PlayerId8:32,Mer_DM2:16,Lvl8:16,LG8:16,Top8:16,E8:16,EN8:16,T8:32
						>>)};

%% write(25030,[PlayerId,Mer,Lvl1,LG,T])	->
%% 	{ok,pt:pack(25030,<<PlayerId:32,Mer:16,Lvl1:16,LG:16,T:32>>)};

write(25030,[PlayerId,Mer,Lvl1,LG,Value,Effect,Effect_Next,T])	->
	{ok,pt:pack(25030,<<PlayerId:32,Mer:16,Lvl1:16,LG:16,Value:16,Effect:16,Effect_Next:16,T:32>>)};

write(25040,[MeridianId,Result,Timestamp]) ->
	{ok,pt:pack(25040,<<MeridianId:16,Result:16,Timestamp:32>>)};

write(25050,[MeridianId,Result])->
	{ok,pt:pack(25050,<<MeridianId:16,Result:16>>)};

write(25060,[MeridianId,Result,Timestamp])->
	{ok,pt:pack(25060,<<MeridianId:16,Result:16,Timestamp:32>>)};

%% write(25070,[MeridianId,Result,Value])->
%% 	{ok,pt:pack(25070,<<MeridianId:16,Result:16,Value:16>>)};
write(25070,[MeridianId,Result,Value,Effect])->
	{ok,pt:pack(25070,<<MeridianId:16,Result:16,Value:16,Effect:16>>)};

write(25080,[Id1,GoodsId1,NUM1,
			 Id1,GoodsId2,NUM2,
			 Id3,GoodsId3,NUM3,
			 Id4,GoodsId4,NUM4,
			 Id5,GoodsId5,NUM5,
			 Id6,GoodsId6,NUM6,
			 Id7,GoodsId7,NUM7]) ->
	{ok,pt:pack(25080,<<7:16,Id1:16,GoodsId1:16,NUM1:16,
							 Id1:16,GoodsId2:16,NUM2:16,
							 Id3:16,GoodsId3:16,NUM3:16,
							 Id4:16,GoodsId4:16,NUM4:16,
							 Id5:16,GoodsId5:16,NUM5:16,
							 Id6:16,GoodsId6:16,NUM6:16,
							 Id7:16,GoodsId7:16,NUM7:16>>)};

%%经脉突破
write(25090,[Res,MerId,Value])->
	{ok,pt:pack(25090,<<Res:16,MerId:16,Value:16>>)};

write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.
