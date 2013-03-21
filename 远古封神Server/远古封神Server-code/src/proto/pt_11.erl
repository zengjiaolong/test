%%%-----------------------------------
%%% @Module  : pt_11
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 11聊天信息
%%%-----------------------------------
-module(pt_11).
-export([read/2, write/2, write/3]).
-include("common.hrl").

%%
%%客户端 -> 服务端 ----------------------------
%%

%%世界聊天
read(11010, <<Bin/binary>>) ->
    {Msg, _} = pt:read_string(Bin),
    {ok, [Msg]};

%%部落聊天
read(11020, <<Bin/binary>>) ->
    {Msg, _} = pt:read_string(Bin),
    {ok, [Msg]};

%%氏族聊天
read(11030, <<Bin/binary>>) ->
    {Msg, _} = pt:read_string(Bin),
    {ok, [Msg]};

%%队伍聊天
read(11040, <<Bin/binary>>) ->
    {Msg, _} = pt:read_string(Bin),
    {ok, [Msg]};

%%场景聊天
read(11050, <<Bin/binary>>) ->
    {Msg, _} = pt:read_string(Bin),
    {ok, [Msg]};

%%传音
read(11060, <<Color:8, Bin/binary>>) ->
    {Msg, _} = pt:read_string(Bin),
    {ok, [Color, Msg]};

%%私聊
read(11070, <<Id:32, Bin/binary>>) ->
	{Msg, _} = pt:read_string(Bin),
    {ok, [Id, Msg]};

read(11073, <<Id:32>>) ->
    {ok, [Id]};

%%拜堂对白
read(11080, <<Type:8, Bin/binary>>) ->
	{Msg, _} = pt:read_string(Bin),
    {ok, [Type, Msg]};

%%同服聊天
read(11090, <<Bin/binary>>) ->
    {Msg, _} = pt:read_string(Bin),
    {ok, [Msg]};

%%场景大表情
read(11100,<<Id:32>>)->
	{ok,[Id]};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%%世界
write(11010, [Id, Nick, Career, Realm, Sex, Vip,State,Bin]) ->
	pack_chat(11010, [Id, Nick, Career, Realm, Sex, Vip,State, Bin]);

%%世界错误
write(11011, [Errno, Value]) ->
	pack_error(11011, [Errno, Value]);

%%部落
write(11020, [Id, Nick, Career, Realm, Sex,Vip,State, Bin]) ->
	pack_chat(11020, [Id, Nick, Career, Realm, Sex,Vip,State, Bin]);

%%部落错误
write(11021, [Errno, Value]) ->
	pack_error(11021, [Errno, Value]);

%%氏族
write(11030, [Id, Nick, Career, Realm, Sex,Vip,State, Bin]) ->
	pack_chat(11030, [Id, Nick, Career, Realm, Sex,Vip,State, Bin]);

%%氏族错误
write(11031, [Errno, Value]) ->
	pack_error(11031, [Errno, Value]);

%%队伍
write(11040, [Id, Nick, Lv, Realm, Sex,Vip,State, Bin]) ->
	pack_chat(11040, [Id, Nick, Lv, Realm, Sex,Vip,State,Bin]);

%%队伍错误
write(11041, [Errno, Value]) ->
	pack_error(11041, [Errno, Value]);

%%场景
write(11050, [Id, Nick, Career, Realm, Sex,Vip,State, Bin]) ->
	pack_chat(11050, [Id, Nick, Career, Realm, Sex,Vip,State, Bin]);

%%场景错误
write(11051, [Errno, Value]) ->
	pack_error(11051, [Errno, Value]);

%%传音
write(11060, [Id, Nick, Lv, Realm, Sex, Career, Color,Vip,State, Bin]) ->
    Nick1 = tool:to_binary(Nick),
    NickLen = byte_size(Nick1),
    Bin1 = tool:to_binary(Bin),
    BinLen = byte_size(Bin1),
    Data = <<Id:32, NickLen:16, Nick1/binary, Lv:8, Realm:8, Sex:8, Career:8, Color:8, Vip:8,State:8, BinLen:16, Bin1/binary>>,
    {ok, pt:pack(11060, Data)};

%%传音错误
write(11061, [Errno, Value]) ->
	pack_error(11061, [Errno, Value]);

%%私聊
write(11070, [Id, Career, Sex, Nick, Bin]) ->
    Nick1 = tool:to_binary(Nick),
    Len = byte_size(Nick1),
    Bin1 = tool:to_binary(Bin),
    Len1 = byte_size(Bin1),
    Data = <<Id:32, Career:8, Sex:8, Len:16, Nick1/binary, Len1:16, Bin1/binary>>,
    {ok, pt:pack(11070, Data)};

%%私聊返回黑名单通知
write(11071, Id) ->
    {ok, pt:pack(11071, <<Id:32>>)};

%%私聊返回，假如对方不在线 
write(11072, Id) ->
    {ok, pt:pack(11072, <<Id:32>>)};

write(11073, [Id, Realm, Level, RealmName, GuildId]) ->
	Rname = tool:to_binary(RealmName),
	Len = byte_size(Rname),
	%%io:format("pt_11 132line Rname = ~p~n", Rname),
	{ok, pt:pack(11073, <<Id:32, Realm:8, Level:8, Len:16, Rname/binary, GuildId:32>>)};

%%系统信息
write(11080, Msg) ->
	write(11080, 1, Msg);

%%中央提示
write(11081, Msg) ->
    Msg1 = tool:to_binary(Msg),
    Len1 = byte_size(Msg1),
    Data = <<Len1:16, Msg1/binary>>,
    {ok, pt:pack(11081, Data)};

%%悬浮提示
write(11082, Msg) ->
    Msg1 = tool:to_binary(Msg),
    Len1 = byte_size(Msg1),
    Data = <<Len1:16, Msg1/binary>>,
    {ok, pt:pack(11082, Data)};

%%本服聊天频道
write(11090, [Id, Nick, Career, Realm, Sex,Vip,State, Bin]) ->
	pack_chat(11090, [Id, Nick, Career, Realm, Sex,Vip,State, Bin]);

%%本服本服错误
write(11091, [Errno, Value]) ->
	pack_error(11091, [Errno, Value]);

%%场景大表情
write(11100,[PlayerId,Id])->
	{ok,pt:pack(11100, <<PlayerId:32,Id:32>>)};

write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.

%%系统信息
write(11080, Type, Msg) ->
    Msg1 = tool:to_binary(Msg),
    Len1 = byte_size(Msg1),
    Data = <<Type:8, Len1:16, Msg1/binary>>,
    {ok, pt:pack(11080, Data)}.




%%聊天内容打包
pack_chat(Cmd, [Id, Nick, Lv, Realm, Sex,Vip,State, Bin]) ->
    Nick1 = tool:to_binary(Nick),
    Len = byte_size(Nick1),
    Bin1 = tool:to_binary(Bin),
    Len1 = byte_size(Bin1),
    Data = <<Id:32, Len:16, Nick1/binary, Lv:8, Realm:8, Sex:8,Vip:8,State:8, Len1:16, Bin1/binary>>,
    {ok, pt:pack(Cmd, Data)}.

%%错误打包
pack_error(Cmd, [Errno, Value]) ->
    Data = <<Errno:8, Value:32>>,
    {ok, pt:pack(Cmd, Data)}.
