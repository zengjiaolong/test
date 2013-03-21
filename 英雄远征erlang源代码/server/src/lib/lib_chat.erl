%%%-----------------------------------
%%% @Module  : lib_chat
%%% @Author  : xyao
%%% @Email   : jiexiaowen@gmail.com
%%% @Created : 2010.06.11
%%% @Description: 聊天
%%%-----------------------------------
-module(lib_chat).
-export([send_sys_msg/2, send_sys_msg_one/2, chat_in_blacklist/2]).
-include("common.hrl").
-include("record.hrl").

%%发聊天系统信息
send_sys_msg(Socket, Msg) ->
    {ok, BinData} = pt_11:write(11004, Msg),
    lib_send:send_to_scene(Socket, BinData).

%%发送系统信息给某个玩家
send_sys_msg_one(Socket, Msg) ->
    {ok, BinData} = pt_11:write(11004, Msg),
    lib_send:send_one(Socket, BinData).

%%私聊返回被加黑名单通知
chat_in_blacklist(Id, Sid) ->
    {ok, BinData} = pt_11:write(11007, Id),
    lib_send:send_to_sid(Sid, BinData).
