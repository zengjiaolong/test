%%%-----------------------------------
%%% @Module  : pt_27
%%% @Author  : ygzj
%%% @Created : 2010.11.18
%%% @Description: 师徒信息
%%%-----------------------------------
-module(pt_27).
-export([read/2,write/2]).
-include("common.hrl").

%%
%%客户端 -> 服务端 ----------------------------

%%拜师申请，师傅ID
read(27000,<<MasterId:32>>) ->
    {ok,MasterId};

%%接受拜师申请，申请者ID
read(27001,<<ApplyId:32>>) ->
    {ok,ApplyId};

%%收徒邀请， 邀请对象角色ID
read(27002,<<Id:32>>) ->
    {ok,Id};

%%是否同意拜师， 接受方ID，结果 0不同意     1同意
read(27003,<<Id:32,Status:8>>) ->
    {ok,[Id,Status]};

%%查询师傅的信息
read(27010,Bin) ->
    {ok,Bin};

%%查询同门师兄弟列表
read(27011,Bin) ->
    {ok,Bin};

%%汇报成绩通知
read(27012,Bin) ->
    {ok,Bin};

%% 汇报成绩
read(27013,Bin) ->
    {ok,Bin};

%%退出师门
read(27014,<<State:8>>) ->
    {ok,State};

%%查询当前角色信息
read(27020,Bin) ->
    {ok,Bin};

%%查询同门师兄弟列表
read(27021,Bin) ->
    {ok,Bin};

%%逐出师门,是否使用决裂书
read(27022,<<Apprentenice_Id:32,Status:8>>) ->
    {ok,[Apprentenice_Id,Status]};

%%查询伯乐榜
read(27030,<<PageNumber:16>>) ->
    {ok,PageNumber};

%%登记上榜
read(27031,Bin) ->
    {ok,Bin};

%%取消上榜
read(27032,Bin) ->
    {ok,Bin};

%%查找伯乐
read(27033,Bin) ->
    {ok,Bin};

%%出师
read(27040,Bin) ->
    {ok,Bin}.




%%
%%服务端 -> 客户端 ------------------------------------
%%
%%拜师申请
write(27000, Result) ->
	Data = <<Result:8>>, 
	{ok, pt:pack(27000, Data)};

%%接受拜师申请
write(27001, Result) ->
	Data = <<Result:8>>, 
	{ok, pt:pack(27001, Data)};

%%收徒邀请
write(27002, Result) ->
	[Forward,State,Master_id,Master_name] = Result,
			NickName = tool:to_binary(Master_name),
			Nick_len = byte_size(NickName),
			Data = <<
					 Forward:8,
					 State:8,
					 Master_id:32,
					 Nick_len:16,
					 NickName/binary
           		   >>,
	{ok, pt:pack(27002, Data)};

%%是否同意拜师
write(27003, Result) ->
	[Forward,State,Master_id,Master_name,State1,ApprenticeId,ApprenticeName] = Result,
			NickName = tool:to_binary(Master_name),
			Nick_len = byte_size(NickName),
			ApprenticeName1 = tool:to_binary(ApprenticeName),
		    ApprenticeName1Len = byte_size(ApprenticeName1),
			Data = <<
					 Forward:8,
					 State:8,
					 Master_id:32,
					 Nick_len:16,
					 NickName/binary,
					 State1:8,
					 ApprenticeId:32,
					 ApprenticeName1Len:16,
					 ApprenticeName1/binary					 
           		   >>,
	{ok, pt:pack(27003, Data)};

%%返回师傅信息查询结果
write(27010, Result) ->
	case Result of
		[] ->
    		NickName = <<>>,
			Data = <<0:32, 0:16, NickName/binary, 0:8, 0:8, 0:16, 0:32>>,
			{ok, pt:pack(27010, Data)};
		_ ->
			[Master_id,Master_name,Master_lv,Career,Score_lv,Appre_num] = Result,
			NickName = tool:to_binary(Master_name),
			Nick_len = byte_size(NickName),
			Data = <<
					 Master_id:32,
					 Nick_len:16,
					 NickName/binary,
					 Master_lv:8,
					 Career:8,
            		 Score_lv:16,
           			 Appre_num:32
           		   >>,
			{ok, pt:pack(27010, Data)}
	end;
	
%%返回师兄弟查询结果
write(27011, Result) ->
	case Result of 
		[] ->
			{ok, pt:pack(27011, <<0:16,<<>>/binary>>)};
		_ ->
			ResultLen = length(Result),
			F = fun([Apprentenice_id,Apprentenice_name,Lv,Career,Sex,Realtion,Status,Report_lv,Join_time,Last_report_time,Online_flag]) ->
						NickName = tool:to_binary(Apprentenice_name),
						Nick_len = byte_size(NickName),		
						<<Apprentenice_id:32,Nick_len:16, NickName/binary, Lv:8, Career:8, Sex:8, Realtion:8, Status:8, Report_lv:16, Join_time:32, Last_report_time:32,Online_flag:8>>
				end,
			Data = tool:to_binary([F(D) || D <- Result]),
			{ok, pt:pack(27011, <<ResultLen:16, Data/binary>>)}
	end;

%%可否汇报成绩
write(27012,Result) ->
	Data = <<Result:8>>, 
	{ok, pt:pack(27012, Data)};

%% 汇报成绩
write(27013,Result) ->
	[State,Forward, Exp, Spirit] = Result,
	Data = <<State:8,Forward:8,Exp:32,Spirit:32>>, 
	{ok, pt:pack(27013, Data)};

%%退出师门
write(27014, Result) ->
	Data = <<Result:8>>, 
	{ok, pt:pack(27014, Data)};


%%返回当月前角色 查询结果
write(27020, Result) ->
	case Result of
		[] ->
			Data = <<0:16, 0:16, 0:8>>,
			{ok, pt:pack(27020, Data)};
		_ ->
			[Award_count,Score_lv,Appre_num] = Result,
			Data = <<
					 Award_count:16,
            		 Score_lv:16,
           			 Appre_num:8
           		   >>,
			{ok, pt:pack(27020, Data)}
	end;

%%返回我的徒弟查询结果
write(27021, Result) ->
	case Result of 
		[] ->
			{ok, pt:pack(27021, <<0:16,<<>>/binary>>)};
		_ ->
			ResultLen = length(Result),
			F = fun([Apprentenice_id,Apprentenice_name,Lv,Career,Sex,Realtion,Status,Report_lv,Join_time,Last_report_time,Online_flag]) ->
						NickName = tool:to_binary(Apprentenice_name),
						Nick_len = byte_size(NickName),		
						<<Apprentenice_id:32,Nick_len:16, NickName/binary, Lv:8, Career:8,Sex:8, Realtion:8, Status:8, Report_lv:16, Join_time:32, Last_report_time:32,Online_flag:8>>
				end,
			Data = tool:to_binary([F(D) || D <- Result]),
			{ok, pt:pack(27021, <<ResultLen:16, Data/binary>>)}
	end;

%%逐出师门
write(27022, Result) ->
	Data = <<Result:8>>, 
	{ok, pt:pack(27022, Data)};

%%拜师申请通知 
write(27023, Result) ->
	Data = <<Result:8>>, 
	{ok, pt:pack(27023, Data)};


%%查询所有伯乐信息
write(27030, Result) ->
	case Result == [] of
		true ->
			skip;
		_ ->
			[PageNumber, Totalpage, Result1] = Result,
			case Result1 of 
				[] ->
					{ok, pt:pack(27030, <<PageNumber:16,Totalpage:16,0:16,<<>>/binary>>)};
				_ ->
					ResultLen = length(Result1),
					F = fun(D) ->
								[_Id,Master_id,Master_name,Master_lv,_Realm,Career,Award_count,_Score_lv,Appre_num,Regist_time,_Lover_type,Sex,Online_flag] = D,
								NickName = tool:to_binary(Master_name),
								Nick_len = byte_size(NickName),
								Appre_num1 =
									case Master_lv =< 36 of
										false ->
											Appre_num;
										_ ->
											case Appre_num  > 5 of
												true -> 5;
												_ -> Appre_num
											end
									end,
								<<
								 Master_id:32,
								 Nick_len:16,
								 NickName/binary,
								 Master_lv:8,
								 Career:8,
								 Sex:8,
								 Award_count:16,
								 Appre_num1:8,
								 Regist_time:32,
								 Online_flag:8
								 >>
						end,
					Data = tool:to_binary([F(D) || D <- Result1]),
					{ok, pt:pack(27030, <<PageNumber:16,Totalpage:16,ResultLen:16,Data/binary>>)}
			end
	end;
	
%%登记上榜
write(27031, Result) ->
	Data = <<Result:8>>, 
	{ok, pt:pack(27031, Data)};

%%取消上榜
write(27032, Result) ->
	Data = <<Result:8>>, 
	{ok, pt:pack(27032, Data)};

%%查找伯乐
write(27033, Result) ->
	case Result of 
		[] ->
			{ok, pt:pack(27033, <<0:16,<<>>/binary>>)};
		_ ->
			ResultLen = length(Result),
			F = fun(D) ->
						[Master_id,Master_name,Master_lv,Career,Sex,Award_count,Appre_num,Regist_time,Online_flag] = D,
						NickName = tool:to_binary(Master_name),
						Nick_len = byte_size(NickName),
						<<
								 Master_id:32,
								 Nick_len:16,
								 NickName/binary,
								 Master_lv:8,
								 Career:8,
								 Sex:8,
								 Award_count:16,
								 Appre_num:8,
								 Regist_time:32,
								 Online_flag:8
								 >>
				end,
			Data = tool:to_binary([F(D) || D <- Result]),
			{ok, pt:pack(27033, <<ResultLen:16,Data/binary>>)}
	end;

%%出师
write(27040, Result) ->
	[Forward,State] = Result,
			Data = <<
					 Forward:8,
					 State:8
           		   >>,
	{ok, pt:pack(27040, Data)};

%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.


