%%%-----------------------------------
%%% @Module  : pt_32
%%% @Author  : ygzj
%%% @Created : 2010.10.05
%%% @Description: 32 NPC模块
%%%-----------------------------------
-module(pt_32).
-export([read/2, write/2]).
-include("common.hrl").

%%
%%客户端 -> 服务端 ----------------------------
%%

%% 获取npc对话或关联任务
read(32000, <<NpcId:32>>) ->
    {ok, [NpcId]};

%% 获得npc任务对话
read(32001, <<NpcId:32, TaskId:32>>) ->
    {ok, [NpcId, TaskId]};

read(_Cmd, _R) ->
    {error, no_match}.

%%
%%服务端 -> 客户端 ------------------------------------
%%

%% --- NPC对话开始 ----------------------------------

%% NPC对话
%% 数据格式[[{npc,<<"测试">>,[]},{yes,<<"后会有期">>,[]}]]
%% 数据格式:[任务id,状态(1:可接，2：关联，3：未完成，4：已完成),名称]
write(32000, [Id, TaskList, TalkList]) ->
    BinA = pack_talk_task_list(TaskList),
    BinB = pack_talk(TalkList),
    Data = <<Id:32, BinA/binary, BinB/binary>>,
    {ok, pt:pack(32000, Data)};

%% NPC任务对话
write(32001, [Id, TaskId, TalkList]) ->
    Bin = pack_talk(TalkList),
    Data = <<Id:32, TaskId:32, Bin/binary>>,
    {ok, pt:pack(32001, Data)};

%%通知客户端显示NPC
write(32002, _R) ->
	{ok,pt:pack(32002,<<>>)};

%% -----------------------------------------------------------------
%% 错误处理
%% -----------------------------------------------------------------
write(Cmd, _R) ->
?INFO_MSG("~s_errorcmd_[~p] ",[misc:time_format(yg_timer:now()), Cmd]),
    {ok, pt:pack(0, <<>>)}.

%% ----- 私有函数 -------

%% 打包对话数据
%% 数据格式[[{npc,<<"测试">>,[]},{yes,<<"后会有期">>,[]}]]
pack_talk([]) ->
    <<0:16, <<>>/binary>>;
pack_talk(TalkList) ->
    Bin = [pack_talk_item(X) || X<- TalkList],
    Len = length(TalkList),
    tool:to_binary([<<Len:16>>, Bin]).
pack_talk_item(Item) ->
    Bin = pack_talk_answer_item(Item,[]),
    Len = length(Bin),
    tool:to_binary([<<Len:16>>, Bin]).

pack_talk_answer_item([],Data)->lists:reverse(Data);
pack_talk_answer_item([{Type, Text, Ex}|Item],Data) ->
	case show_delay(Type) of 
		true->
			pack_talk_answer_item(Item,Data);
		false->
    		TypeInt = data_talk:type_to_int(Type),
    		TLen = byte_size(Text),
   		 	ExBin = tool:to_binary(util:implode("#&", Ex)),
    		ExL = byte_size(ExBin),
    		Bin = tool:to_binary([<<TypeInt:16, TLen:16>>, Text, <<ExL:16, ExBin/binary>> ]),
			pack_talk_answer_item(Item,[Bin|Data])
	end.

%%111 propose 提亲
%%112 book_wedding 预订婚宴
%%113 mass 群发喜帖

%%114 begin_weddings 开始拜堂
%%115 wedding_gift 赠送贺礼
%%116 leave_wedding 离开婚宴
show_delay(Type)->
	case lists:member(Type,[divorce]) of
		false->false;
		true->
			NowTime = util:unixtime(),
%% 			{ST, _ET} = lib_activities:newyear_time(),
			if NowTime >1328544000->
				false;
	   		true->
				true
		  		 %%结婚功能标签到1月1号才显示(43991服除外)
%% 		   		Platform = config:get_platform_name(), 
%% 		   		Sn = config:get_server_num(),
%% 		   		if Platform == "4399" andalso Sn==1->
%% 					   false;
%% 			 		 true->
%% 						 true
%% 				end
			end
	end.

%% 打包对话里的任务列表
%% 数据格式:[任务id,状态(1:可接，2：关联，3：未完成，4：已完成),名称]
pack_talk_task_list([]) ->
    <<0:16, <<>>/binary>>;
pack_talk_task_list(TaskList) ->
    L = [pack_talk_task_list(TaskId, State, Name,Type)|| [TaskId, State, Name,Type] <- TaskList],
%%     L = [pack_talk_task_list(TaskId, State, Name)|| [TaskId, State, Name] <- TaskList],
	Len = length(TaskList),
    tool:to_binary([<<Len:16>>, L]).
pack_talk_task_list(TaskId, State, Name,Type) ->
    NL = byte_size(Name),
    <<TaskId:32, State:8, NL:16, Name/binary,Type:32>>.