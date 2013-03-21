%%%-----------------------------------
%%% @Module  : pt
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 协议公共函数
%%%-----------------------------------
-module(pt).
-include("common.hrl").
-include("record.hrl").
-export([
            read_string/1,
            pack/2
        ]).

%%读取字符串
read_string(Bin) ->
    case Bin of
        <<Len:16, Bin1/binary>> ->
            case Bin1 of
                <<Str:Len/binary-unit:8, Rest/binary>> ->
                    {binary_to_list(Str), Rest};
                _R1 ->
                    {[],<<>>}
            end;
        _R1 ->
            {[],<<>>}
    end.

%% 打包信息，添加消息头 
pack(Cmd, Data) ->
%% 	case lists:member(Cmd, [12001,12003,12004,20001, 20003]) of
%% 		false ->
%% 			io:format("time:~p ---- Cmd ~p~n", [util:unixtime(),Cmd]);
%% 		true ->
%% 			skip
%% 	end,
%%  暂取消包统计观察是否影响性能 modify hzj
%%	pack_stat(Cmd),
	L = byte_size(Data) + 6,
%% 	if
%% 		L > 400 ->
%% 			?DEBUG("________cmd:~p__________________BYTE_SIZE:~p",[Cmd,L]);
%% 		true ->
%% 			skip
%% 	end,
	%% 选择压缩的协议
	%% 12002 加载场景信息
	%% 15010 玩家物品列表
	%% 15017 所有物品信息
	%% 30000 任务列表
	%% 12011 九宫格附近玩家
	PackCmd = [12002,15010,15017,30000],
	case lists:member(Cmd, PackCmd) of
	   true ->
		   NewData = zlib:compress(Data),
		   NL = byte_size(NewData) + 6,
		   <<NL:32, Cmd:16, NewData/binary>>;
	   false ->
		   <<L:32, Cmd:16, Data/binary>>
	end.

%% 统计输出数据包 
%% pack_stat(Cmd) ->
%% 	if Cmd =/= 10006 andalso Cmd =/= 12008 ->
%% 		?INFO_MSG("~s_write_[~p] ",[misc:time_format(yg_timer:now()), Cmd]);
%%    		true -> no_out
%% 	end,
%% 	[NowBeginTime, NowCount] = 
%% 	case ets:match(?ETS_STAT_SOCKET,{Cmd, socket_out , '$3', '$4'}) of
%% 		[[OldBeginTime, OldCount]] ->
%% 			[OldBeginTime, OldCount+1];
%% 		_ ->
%% 			[yg_timer:now(),1]
%% 	end,	
%% 	ets:insert(?ETS_STAT_SOCKET, {Cmd, socket_out, NowBeginTime, NowCount}).
