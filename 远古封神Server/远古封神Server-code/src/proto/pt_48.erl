%% Author: Administrator
%% Created: 2011-12-1
%% Description: TODO: 结婚及婚宴
-module(pt_48).

%%
%% Include files
%%

%%
%% Exported Functions
%%
-export([
		 read/2,
		 write/2
		]).
-include("record.hrl").
-include("common.hrl").

%%
%% API Functions
%%

%%提亲条件判断
read(48000,<<NameBin/binary>>) ->
	{Name, _} = pt:read_string(NameBin),
	{ok,[Name]};

%%提亲
read(48001,_R) ->
	{ok,[]};

%%女方对提亲的回应
read(48002,<<Response:8,BoyId:32>>) ->
	{ok,[Response,BoyId]};

%%婚宴信息
read(48003,_) ->
	{ok,[]};

%%预订婚宴
read(48004,<<WeddingType:8,WeddingNum:8>>) ->
	{ok,[WeddingType,WeddingNum]};

%%群发喜帖
read(48005,_) ->
	{ok,[]};

%%发送喜帖
read(48006,<<Len:16,Bin/binary>>) ->
	F = fun(_, [Bin1,L]) ->
				<<Id:32,Rest/binary>> = Bin1,
				L1 = [Id|L],
				[Rest, L1]
		end,
	[_, Ids] = lists:foldl(F, [Bin,[]], lists:seq(1, Len)),
	{ok,[Ids]};

%%购买喜帖
read(48007,<<Num:32>>) ->
	{ok,[Num]};

%%婚宴通知
read(48008,_) ->
	{ok,[]};

%%发贺礼
read(48009,<<Coin:32,Gold:32,Bin/binary>>) ->
	{Msg, _} = pt:read_string(Bin),
	{ok,[Coin,Gold,Msg]};

%%吃饭
read(48010,_) ->
	{ok,[]};

%%拜堂
read(48011,_) ->
	{ok,[]};

%%拜堂的接受方确认(稍等)
read(48012,_) ->
	{ok,[]};

%%拜堂的接受方确认(开始)
read(48013,_) ->
	{ok,[]};

%%客户端请求证书与心形动画
read(48015,_) ->
	{ok,[]};

%%离婚
read(48019,_)->
	{ok,[]};

%%取消婚期
read(48020,_) ->
	{ok,[]};

%%查看预订信息
read(48021,_) ->
	{ok,[]};

%%请求配偶援助
read(48023, <<Type:8, OSceneId:32, OX:32, OY:32>>) ->
	{ok, [Type, OSceneId, OX, OY]};

read(_Cmd, _R) ->
	io:format("NO MATCH READ ~p~n", [[_Cmd, _R]]),
    {error, no_match}.


%%=========================================================================
%%=========================================================================

%%提亲判断
write(48000,Result) ->
   {ok, pt:pack(48000, <<Result:16>>)};

%%提亲
write(48001,{BoyId,BoyName}) ->
	BName = tool:to_binary(BoyName),
	Len = byte_size(BName),
	{ok, pt:pack(48001, <<BoyId:32,Len:16,BName/binary>>)};

%%女方对提亲的回应
write(48002,Response) ->
	{ok, pt:pack(48002, <<Response:16>>)};

%%获取预订婚宴的信息
write(48003,{Result,Wlist}) ->
	F = fun(W)->
				{Num,State,TimeStr} = W,
				Bs = tool:to_binary(TimeStr),
				Len = byte_size(Bs),
				<<Num:8,State:8,Len:16,Bs/binary>>
		end,
	{Wbin,Wlen} =
		if Wlist =:= [] ->
			   {<<>>,0};
		   true ->
			   {tool:to_binary([F(W) || W <- Wlist]), length(Wlist)}
	end,
	{ok, pt:pack(48003, <<Result:16,Wlen:16,Wbin/binary>>)};

%%预订婚宴
write(48004,Res) ->
	{ok, pt:pack(48004, <<Res:16>>)};

%%群发喜帖(打开列表)
write(48005,{Res,Inv_num,Max,List}) ->
	if Res =/= 1 ->
		   Max = 0,
		   Len = 0,
		   Data = <<>>;
	   true ->
		   F = fun(L) ->
					   {PlayerId,[Name,Lv,State,Online]} = L,
					   BName = tool:to_binary(Name),
					   Len = byte_size(BName),
					   <<PlayerId:32,Len:16,BName/binary,Lv:32,State:8,Online:8>>
			   end,
		   Data = tool:to_binary([F(L) || L <- List]),
		   Len = length(List)
	end,
	{ok, pt:pack(48005, <<Res:8,Inv_num:32,Max:32,Len:16,Data/binary>>)};

%%发送喜帖
write(48006,Res) ->
	{ok, pt:pack(48006, <<Res:16>>)};

%%购买喜帖
write(48007,{Res,Total}) ->
	{ok, pt:pack(48007, <<Res:16,Total:32>>)};

%%全服通知婚宴
write(48008,{Str,Bc,Gc}) ->
	BinStr = tool:to_binary(Str),
	StrLen = byte_size(BinStr),
	{ok, pt:pack(48008, <<StrLen:16,BinStr/binary,Bc:8,Gc:8>>)};

%%显示贺礼信息
write(48009,{Result,PlayerId,Name,Coin,Gold,Msg}) ->
	if Result =/= 1 ->
		   NameBin = <<>>,
		   NameLen = 0,
		   MsgBin = <<>>,
		   MsgLen = 0;
	   true ->
		   NameBin = tool:to_binary(Name),
		   NameLen = byte_size(NameBin),
		   MsgBin = tool:to_binary(Msg),
		   MsgLen = byte_size(MsgBin)
	end,
	{ok, pt:pack(48009,<<Result:8,PlayerId:32,NameLen:16,NameBin/binary,Coin:32,Gold:32,MsgLen:16,MsgBin/binary>>)};

%%吃饭
write(48010,{PlayerId,Pstate}) ->
	{ok, pt:pack(48010,<<PlayerId:32,Pstate:16>>)};

%%拜堂
write(48011,Result)->
	{ok, pt:pack(48011, <<Result:16>>)};

%%拜堂的接受方选择:稍等
write(48012,Result)->
	{ok, pt:pack(48012, <<Result:16>>)};

%%拜堂的接受方选择:开始
write(48013,{Res,BoyId,Bname,GirlId,Gname}) ->
	BinB = tool:to_binary(Bname),
    BLen = byte_size(BinB),
	BinG = tool:to_binary(Gname),
    GLen = byte_size(BinG),
	{ok, pt:pack(48013, <<Res:16,BoyId:32,BLen:16,BinB/binary,GirlId:32,GLen:16,BinG/binary>>)};

%%图标通知
write(48014,{Result,Ret,Msg,Bc,Gc})->
	if Msg =:= [] ->
		   BinStr = <<>>,
		   StrLen = 0;
	   true ->
		   BinStr = tool:to_binary(Msg),
		   StrLen = byte_size(BinStr)
	end,	
	{ok, pt:pack(48014, <<Result:8,Ret:32,StrLen:16,BinStr/binary,Bc:8,Gc:8>>)};

%%提亲成功提示
write(48015,{BName,GName,Time,Number}) ->
	BNameStr = tool:to_binary(BName),
	BStrLen = byte_size(BNameStr),
	GNameStr = tool:to_binary(GName),
	GStrLen = byte_size(GNameStr),
	TimeStr = tool:to_binary(Time),
	TStrLen = byte_size(TimeStr),
	{ok, pt:pack(48015, <<BStrLen:16,BNameStr/binary,GStrLen:16,GNameStr/binary,TStrLen:16,TimeStr/binary,Number:16>>)};

%%男方专用（女方回应提亲请求后给男方发的协议）
write(48016,Result)->
	{ok, pt:pack(48016, <<Result:16>>)};

%%通知客户端播放鲜花
write(48017,_) ->
	{ok, pt:pack(48017, <<>>)};

%%放烟花
write(48018,Type) ->
	{ok, pt:pack(48018, <<Type:8>>)};

%%离婚
write(48019,Result) ->
	{ok, pt:pack(48019, <<Result:16>>)};

%%取消婚期
write(48020,Res) ->
	{ok, pt:pack(48020, <<Res:16>>)};

%%预订信息
write(48021,{Y,M,D,List}) ->
	F = fun(L) ->
				{TimeStr,Bname,Gname,Wtype} = L,
				T = tool:to_binary(TimeStr),
				TL = byte_size(T),
				B = tool:to_binary(Bname),
				BL = byte_size(B),
				G = tool:to_binary(Gname),
				GL = byte_size(G),
				<<TL:16,T/binary,BL:16,B/binary,GL:16,G/binary,Wtype:8>>
		end,
	{Data,Len} =
		if List =:= [] ->
			  {<<>>,0};
		   true ->
			  {tool:to_binary([F(L) || L <- List]),length(List)}
	end,
	{ok, pt:pack(48021, <<Y:32,M:8,D:8,Len:16,Data/binary>>)};

%%夫妻pK通知信息
write(48022,{Aname,Field,Sid,X,Y}) ->
	T = tool:to_binary(Aname),
	TL = byte_size(T),
	Sex = 
		case Field of
			boy ->
				1;
			girl ->
				2
		end,
	{ok, pt:pack(48022,<<TL:16,T/binary,Sex:8,Sid:32,X:32,Y:32>>)};

write(Cmd, _R) ->
    io:format("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.
%%
%% Local Functions
%%

