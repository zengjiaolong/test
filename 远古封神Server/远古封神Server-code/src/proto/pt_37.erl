%% Author: ygzj
%% Created: 2011-4-8
%% Description: 答题模块
-module(pt_37).

-export([read/2,write/2]).
-include("common.hrl").


%%
%%客户端 -> 服务端 ----------------------------
%%答题报名
read(37001,Bin) ->
    {ok,Bin};

%%提交答题
read(37004,<<Order:8,BaseAnswerId:32,Tool:8,Reference_id:32,Bin/binary>>) ->
	{Opt, _} = pt:read_string(Bin),
%% io:format("Order,BaseAnswerId,Opt,Tool,Reference_id is ~p,~p,~p,~p,~p,~n",[Order,BaseAnswerId,Opt,Tool,Reference_id]),
    {ok,[Order,BaseAnswerId,Opt,Tool,Reference_id]};

%%退出答题活动
read(37006,Bin) ->
    {ok,Bin};

%%重新登陆检查是否在答题时间内
read(37008,Bin) ->
    {ok,Bin}.



%%
%%服务端 -> 客户端 ------------------------------------
%%
%%答题报名
write(37001, Result) ->
	Data = 
		case Result == [] of
			true -> <<9:8>>;
			false -> <<Result:8>>
		end,
	{ok, pt:pack(37001, Data)};

%%答题倒计时
write(37002, Result) ->
	[Pos,TimeValue] = Result,
	Data = <<Pos:8,TimeValue:32>>, 
	{ok, pt:pack(37002, Data)};

%%向客户端推送题库
write(37003, Result) ->
	[Order,Id,Quest,Opt1,Opt2,Opt3,Opt4] = Result,
	Quest1 = tool:to_binary(Quest),
	Quest1_len = byte_size(Quest1),
	Opt1_Content = tool:to_binary(Opt1),
	Opt1_Content_len = byte_size(Opt1_Content),
	Opt2_Content = tool:to_binary(Opt2),
	Opt2_Content_len = byte_size(Opt2_Content),
	Opt3_Content = tool:to_binary(Opt3),
	Opt3_Content_len = byte_size(Opt3_Content),
	Opt4_Content = tool:to_binary(Opt4),
	Opt4_Content_len = byte_size(Opt4_Content),
	
	Data = <<Order:8,
			  Id:32,
			  Quest1_len:16,
			  Quest1/binary,
			  Opt1_Content_len:16,
			  Opt1_Content/binary,
			  Opt2_Content_len:16,
			  Opt2_Content/binary,
			  Opt3_Content_len:16,
			  Opt3_Content/binary,
			  Opt4_Content_len:16,
			  Opt4_Content/binary
			 >>, 
	{ok, pt:pack(37003, Data)};

%%答题倒计时
write(37004, Result) ->
	Data = <<Result:8>>, 
	{ok, pt:pack(37004, Data)};

%%活动结束，通知客户端关闭答题窗口
write(37005, Result) ->
	 [Type, Tool1, Tool2, Tool3] = Result,
	Data = <<Type:8,Tool1:8,Tool2:8,Tool3:8>>, 
	{ok, pt:pack(37005, Data)};

%%退出答题活动
write(37006, Result) ->
	Data = <<Result:8>>, 
	{ok, pt:pack(37006, Data)};

%%将统计选项统计数和正确答案推送到客户端
write(37007, Result) ->
	[Order,SelectOpt1Num,SelectOpt2Num,SelectOpt3Num,SelectOpt4Num,Reply,ResultList,Score,ChatOrder,IsCorrect] = Result,
	ResultLen = length(ResultList),
	F = fun(R) ->
				[_ChatOrder1,Player_id1, Nickname1, Realm1, Score1,_IsCorrect] = R,
				NickName2 = tool:to_binary(Nickname1),
				Nick_len = byte_size(NickName2),	
				<<Player_id1:32,Nick_len:16, NickName2/binary,Realm1:8, Score1:16>>
				end,
	Data1 = tool:to_binary([F(R) || R <- ResultList]),
	Reply1 = tool:to_binary(Reply),
	Reply1_len = byte_size(Reply1),	
	Data = <<Order:8,
			  SelectOpt1Num:16,
			  SelectOpt2Num:16,
			  SelectOpt3Num:16,
			  SelectOpt4Num:16,
			  Reply1_len:16,
			  Reply1/binary,
			  ResultLen:16, 
			  Data1/binary,
			  Score:16,
			  ChatOrder:16,
			  IsCorrect:8 
			 >>, 
	{ok, pt:pack(37007, Data)};

%%活动结束，显示答对题数，分数，经验，灵力
write(37009, Result) ->
	[CorrectNum,Score,Exp,Spirit] = Result,
	Data = <<CorrectNum:8,Score:16,Exp:32,Spirit:32>>, 
	{ok, pt:pack(37009, Data)}.
	
	
	
	