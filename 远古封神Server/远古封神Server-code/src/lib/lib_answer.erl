%% Author: ygzj
%% Created: 2011-4-8
%% Description: 答题模块
-module(lib_answer).

%%
%% Exported Functions
%%
-export([
	init_answer/0,
	load_base_answer/1,
	answer_join/5,
	answer_commit/6,
	statics_answer/1,
	answer_exit/2,
	send_answer_info/2,
	handleTool3/6,
	check_answer_time/1,
	send_answer_result/0,
	get_ets_base_answer/0,
	get_ets_answer/1,
	get_ets_answer/0,
	put_answer_hour_time/1,
	get_mod_answer_data_by_type/1,
	get_answer_hour_time_by_dict/0,
	test/0
]).
-include("common.hrl").
-include("record.hrl").

%% @doc 创建答题ets
init_answer() ->
	ets:delete(?ETS_BASE_ANSWER),
	ets:delete(?ETS_ANSWER),
    ets:new(?ETS_BASE_ANSWER, [named_table, public, set, {keypos,#ets_base_answer.id}]),
	ets:new(?ETS_ANSWER, [named_table, public, set, {keypos,#ets_answer.player_id}]), 
    ok.
	
%%加载答题基础数据
load_base_answer(Sum) ->
	db_agent:load_base_answer(Sum).

%%查询ets_base_answer
get_ets_base_answer() ->
	%%AnswerList = ets:match(?ETS_ANSWER,_='$1'),
	BaseAnswerList = ets:match(?ETS_BASE_ANSWER,_='$1'),
	BaseAnswerList.

%%查询角色的答题信息
get_ets_answer(Player_Id) ->
	 [EtsAnswer] =  ets:lookup(ets_answer, Player_Id),
	 EtsAnswer.

%%查询角色的答题信息
get_ets_answer() ->
	 AnswerList = ets:match(?ETS_ANSWER,_='$1'),
	 AnswerList.

%%报名
answer_join(PlayerId, NickName, Lv, Realm, PidSend) ->
	Time1 = mod_answer:get_answer_data_by_type(answer_join_start),
	Time2 = mod_answer:get_answer_data_by_type(answer_start),
	Time3 = mod_answer:get_answer_data_by_type(answer_end),
	LimitLv = mod_answer:get_answer_data_by_type(answer_lv),
	Timerdelay = get(timerdelay),
	Timerdelay1 = 
	if Timerdelay == undefined ->
		   0;
	   true ->
		   Timerdelay
	end,		
	NowSec = util:get_today_current_second(),
	Res = 
	case NowSec < (Time1+Timerdelay1) of
		true -> 3; %%没到报名时间
		false ->
			case NowSec >= (Time3+Timerdelay1) of
						true  -> 5; %%答题活动已经结束 
						false ->
							case Lv < LimitLv of
								true -> 2; %%等级不到30级 
								false ->
									EtsAnswerObj = ets:lookup(?ETS_ANSWER, PlayerId),
									%%区分是报名时间和正式开始答题时间
									case NowSec >= (Time1+Timerdelay1) andalso NowSec < (Time2+Timerdelay1) of
										true ->%%报名时间内
											case EtsAnswerObj =/= [] of
												true ->
													8;
												false ->
													EtsAnswer = #ets_answer{	
													player_id = PlayerId,
													nickname = NickName,
													realm = Realm
													},
													ets:insert(?ETS_ANSWER,EtsAnswer),
													%%报名成功后计算活动答题倒计时
													{ok, BinData} = pt_37:write(37002, [3,60-(NowSec-Time1)+Timerdelay1]),
													lib_send:send_to_sid(PidSend, BinData),
													1
											end;
										false ->%%正式开始答题时间以后
											case EtsAnswerObj =/= [] of
												true -> 
													[EtsAnswer] = EtsAnswerObj,
													Tool1 = EtsAnswer#ets_answer.tool1,
													Tool2 = EtsAnswer#ets_answer.tool2,
													Tool3 = EtsAnswer#ets_answer.tool3,
													{ok, BinData3} = pt_37:write(37002, [8,15*60-(NowSec-Time2)+Timerdelay1]),
													lib_send:send_to_sid(PidSend, BinData3),
													{ok, BinData} = pt_37:write(37005, [1, Tool1, Tool2, Tool3]),
													lib_send:send_to_sid(PidSend, BinData),
													TimeValue = (NowSec - Time3) rem 30,%%计算现在应该显示的倒计时
													if TimeValue >= 0 andalso  TimeValue =< 10 ->
														   {ok, BinData2} = pt_37:write(37002, [5,(10-TimeValue)]),
														   lib_send:send_to_sid(PidSend, BinData2);
													   TimeValue > 10 andalso  TimeValue =< 25 ->
														   {ok, BinData2} = pt_37:write(37002, [6,(25-TimeValue)]),
														   lib_send:send_to_sid(PidSend, BinData2);
													   TimeValue > 25 andalso  TimeValue =< 30 ->
														   {ok, BinData2} = pt_37:write(37002, [7,(30-TimeValue)]),
														   lib_send:send_to_sid(PidSend, BinData2);
													   true ->
														   skip
													end;
												false ->
													EtsAnswer = #ets_answer{
													player_id = PlayerId,
													nickname = NickName,
													realm = Realm
													},
													ets:insert(?ETS_ANSWER,EtsAnswer),
													{ok, BinData3} = pt_37:write(37002, [8,15*60-(NowSec-Time2)+Timerdelay1]),
													lib_send:send_to_sid(PidSend, BinData3)
											end,
											11
									end
							end
					end
	end,
	if Res == 1 ->
		   {ok, BinData1} = pt_37:write(37001, Res),
		   lib_send:send_to_sid(PidSend, BinData1);
	   true ->
		   skip
	end.

	
	
%%删除基础ets_base_answer,ets_answer
send_answer_result() ->
	AnswerList = ets:match(?ETS_ANSWER,_='$1'),
	BaseAnswerList = ets:match(?ETS_BASE_ANSWER,_='$1'),
	CreateTime = util:unixtime(),
	case AnswerList of
		[] -> skip;
		_ ->
			F = fun(Ets_Answer) ->
						PlayerStatus  = lib_player:get_online_info(Ets_Answer#ets_answer.player_id),
						Score = Ets_Answer#ets_answer.score,
						case PlayerStatus of
							[] -> %%玩家不在线 
								Lv = db_agent:get_player_properties(lv,Ets_Answer#ets_answer.player_id),
								Exp = round(Score*math:pow(Lv/10,5)),
								Spirit = round(Exp/3),
								%%统计答题参与人数
								spawn(fun()-> db_agent:update_join_data(Ets_Answer#ets_answer.player_id, answer) end),
								spawn(fun()-> db_agent:update_player_exp_data([{exp, Exp, add},{spirit, Spirit, add}], [{id,Ets_Answer#ets_answer.player_id}]) end),								 
								%%记录答题日志
								spawn(fun()-> db_agent:create_log_answer(Ets_Answer#ets_answer.player_id,Score,Exp,Spirit,CreateTime) end);
							_ ->
								Lv = PlayerStatus#player.lv,
								Exp = round(Score*math:pow(Lv/10,5)),
								Spirit = round(Exp/3),
								gen_server:cast(PlayerStatus#player.other#player_other.pid,{'EXP', Exp, Spirit, 9}),
								%%将答题结果推送客户端
								CorrectNum = statics_answer_result(BaseAnswerList,Ets_Answer),
								{ok, BinData} = pt_37:write(37009, [CorrectNum,Score,Exp,Spirit]),
								lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
								%%统计答题参与人数
								spawn(fun()-> db_agent:update_join_data(PlayerStatus#player.id, answer) end),
								%%记录答题日志
								spawn(fun()-> db_agent:create_log_answer(PlayerStatus#player.id,Score,Exp,Spirit,CreateTime) end)
						end
				end,
			[F(Ets_Answer) || [Ets_Answer] <- AnswerList],
		    F1 = fun(Ets_Answer1) ->
					  [Ets_Answer1#ets_answer.nickname,Ets_Answer1#ets_answer.score]
			  end,		   
		    TotalResult = [F1(Ets_Answer1) || [Ets_Answer1] <- AnswerList],
			%%释放字典中的答题开始时间值
			erlang:erase(answer_hour_time),
			ets:delete_all_objects(?ETS_ANSWER),
			case TotalResult == [] of
				true -> skip;
				false ->
					ResultList1 = lists:sort(fun([_Nickname1, Score1],[_Nickname2, Score2]) -> Score1 > Score2 end, TotalResult),
					[FirthName,_] = lists:nth(1,ResultList1),
					%%timer:sleep(1000*10),
					Msg = io_lib:format("<a href='event:1'><font color='#FEDB4F'>恭喜玩家【~s】在答题活动中获得第一名！</font></a>", [FirthName]),
					lib_chat:broadcast_sys_msg(6,Msg)
			end			
	end.	    


%%答题活动退出
answer_exit(PlayerId, Sta) ->
	NowSec = util:get_today_current_second(),
	Time1 = mod_answer:get_answer_data_by_type(answer_end),
	if NowSec >= Time1 ->
		   if Sta == 9 ->
				  1;
			  true ->
				  1
		   end;
	   true ->
		   EtsAnswer = ets:lookup(?ETS_ANSWER, PlayerId),
		   if EtsAnswer == [] ->
				  1;
			  true ->
				  %%退出时间大于结束时间，则不清空角色的答题信息
				   %%ets:delete(?ETS_ANSWER, PlayerId),
				   1
		   end
	end.

%%答题提交2,1735,"D",0,0,
%%PlayerStatus,AnswerOrder,BaseAnswerId,Opt,Reply is 1,1,1706,"B","B",
answer_commit(PlayerId, AnswerOrder, BaseAnswerId, Opt, Tool, Reference_id) ->
	NowSec = util:get_today_current_second(),
	StartAnswerTime = mod_answer:get_answer_data_by_type(answer_start),
	[EtsBaseAnswer] = ets:lookup(?ETS_BASE_ANSWER, BaseAnswerId),
	Reply = tool:to_list(EtsBaseAnswer#ets_base_answer.reply),
	[EtsAnswer] = ets:lookup(?ETS_ANSWER, PlayerId),
	%%先判断道具使用正确性
	case Tool of
		%%没有使用道具
		0  -> 
		   	if Reply == Opt -> %%答对
				  EtsAnswer1 = get_new_answer(EtsAnswer,AnswerOrder,Opt,Tool,Reference_id),
				  ReplyTime = get_answer_time(NowSec,StartAnswerTime,AnswerOrder),
				  Score = get_scroe(ReplyTime,Tool),
				  EtsAnswer2 = EtsAnswer1#ets_answer{score = (EtsAnswer#ets_answer.score+Score)},
				  ets:insert(?ETS_ANSWER,EtsAnswer2),
				  1;
			  true -> %% 答错
				  EtsAnswer1 = get_new_answer(EtsAnswer,AnswerOrder,Opt,Tool,Reference_id),
				  ets:insert(?ETS_ANSWER,EtsAnswer1),
				  1
		   	end;
	  	%%使用幸运星道具
		1 ->
			Tools1 = EtsAnswer#ets_answer.tool1,
		   	if Tools1 >= 3 -> 7; %%幸运星只能使用三次
			  true ->
				  if Reply == Opt -> %%答对
						  EtsAnswer1 = get_new_answer(EtsAnswer,AnswerOrder,Opt,Tool,Reference_id),
						  Score = get_scroe(get_answer_time(NowSec,StartAnswerTime,AnswerOrder),Tool),
						  EtsAnswer2 = EtsAnswer1#ets_answer{score = (EtsAnswer#ets_answer.score+Score)},
						  ets:insert(?ETS_ANSWER,EtsAnswer2),
						  1;
					 true -> %%  答错
						 EtsAnswer1 = get_new_answer(EtsAnswer,AnswerOrder,Opt,Tool,Reference_id),
						 ets:insert(?ETS_ANSWER,EtsAnswer1),
						 1
				  end
		   	end;  
	  	%%使用读心书道具
		2 ->
			Tools2 = EtsAnswer#ets_answer.tool2,
		    if Tools2 >= 3 -> 7; %%读心书只能使用三次
			   true ->
				   if AnswerOrder == 1 -> 6;
					  true ->
						  if Opt =/= "" orelse Opt =/= []  -> 
								 10;%%已使用读心术功能，答题时间结束后，系统会为你答题
							 true -> 
								 EtsAnswer1 = get_new_answer(EtsAnswer,AnswerOrder,Opt,Tool,Reference_id),
								 ets:insert(?ETS_ANSWER,EtsAnswer1),
								 1
						  end						 
				   end
			end;
	  	%%使用放大镜道具
		3 ->
			Tools3 = EtsAnswer#ets_answer.tool3,
		    if Tools3 >= 3 -> 7; %%放大镜只能使用三次
			   true ->
				   if Opt =/= "" orelse Opt =/= []  -> 
						  11;
					  true ->
						  EtsAnswer1 = get_new_answer(EtsAnswer,AnswerOrder,Opt,Tool,Reference_id),
						  ets:insert(?ETS_ANSWER,EtsAnswer1),
						  1
				   end
			end;
	  	_ ->
		   12
	end.

%%协议号 37003 向客户端推送题目信息
send_answer_info(Order,Ets_Base_Answer) ->
	if Order >= 1 andalso Order =< 30 ->
		   Id = Ets_Base_Answer#ets_base_answer.id,
	  	   Quest = Ets_Base_Answer#ets_base_answer.quest,
		   Opt1 = Ets_Base_Answer#ets_base_answer.opt1,
		   Opt2 = Ets_Base_Answer#ets_base_answer.opt2,
		   Opt3 = Ets_Base_Answer#ets_base_answer.opt3,
		   Opt4 = Ets_Base_Answer#ets_base_answer.opt4,  
		   AnswerList = ets:match(?ETS_ANSWER,_='$1'),
		   F = fun(Ets_Answer) ->
					   Player_id = Ets_Answer#ets_answer.player_id, 
					   {ok, BinData} = pt_37:write(37003, [Order,Id,Quest,Opt1,Opt2,Opt3,Opt4]),
					   lib_send:send_to_uid(Player_id, BinData)
				end,		   
		   [F(Ets_Answer) || [Ets_Answer] <- AnswerList];
	   true -> skip
	end.


%%统计答对的题数
statics_answer_result(BaseAnswerList,Ets_Answer) ->
	Size = length(BaseAnswerList),
	F = fun(Order) ->
				[Ets_Base_Answer] =  lists:nth(Order,BaseAnswerList),
				Reply = tool:to_list(Ets_Base_Answer#ets_base_answer.reply),
				Answer_properties = get_answer_properties(Order,Ets_Answer),
				Opt = tool:to_list(Answer_properties#answer_properties.opt),
				if Opt == Reply -> 
					   1;
				   true ->
					   0
				end
		end,
	L = [F(Order) || Order <- lists:seq(1, Size)],
	lists:sum(L).

%%%%协议号 37007 更新使用读心术和放大镜道具的结果,并将选项统计数和正确答案推送到客户端
statics_answer(Order) ->
	if Order >= 1 andalso Order =< 30 ->
		   BaseAnswerList = ets:match(?ETS_BASE_ANSWER,_='$1'),
		   [Ets_Base_Answer] =  lists:nth(Order,BaseAnswerList),
		   Reply = tool:to_list(Ets_Base_Answer#ets_base_answer.reply),
		   AnswerList = ets:match(?ETS_ANSWER,_='$1'),
		   case AnswerList of
			   [] ->
				   skip;
			   _ ->
				   F = fun(Ets_Answer) ->
							   handleTool2Result(Order,Ets_Answer,Reply)		%%处理使用道具2的情况
					   end,
				   [F(Ets_Answer) || [Ets_Answer] <- AnswerList],
				   F1 = fun(Ets_Answer) ->
								handleTool3Result(Order,AnswerList,Ets_Answer,Reply)	%%处理使用道具3的情况
						end,
				   [F1(Ets_Answer) || [Ets_Answer] <- AnswerList],
				   %%将选择累计数,正确答案推送客户端
				   AnswerList1 = ets:match(?ETS_ANSWER,_='$1'),%%重新获取角色答题数据
				   {{_A,SelectOpt1Num},{_B,SelectOpt2Num},{_C,SelectOpt3Num},{_D,SelectOpt4Num}} = handleTool3(Order,AnswerList,{"A",0},{"B",0},{"C",0},{"D",0}),
				   push_to_client(Order,SelectOpt1Num,SelectOpt2Num,SelectOpt3Num,SelectOpt4Num,Reply,AnswerList1)
		   end;
	   true -> skip
	end.

push_to_client(Order,SelectOpt1Num,SelectOpt2Num,SelectOpt3Num,SelectOpt4Num,Reply,AnswerList) ->
	F =  fun(Ets_Aanswer) ->
				 Answer_properties = get_answer_properties(Order,Ets_Aanswer),
				 Opt = tool:to_list(Answer_properties#answer_properties.opt),
				 IsCorrect = 
					 if Reply == Opt ->
							1;
						true ->
							0
					 end,
				 [Ets_Aanswer#ets_answer.player_id,Ets_Aanswer#ets_answer.nickname,Ets_Aanswer#ets_answer.realm,Ets_Aanswer#ets_answer.score,IsCorrect]
		  end,		 
	AnswerList1 = [F(Ets_Aanswer) || [Ets_Aanswer] <- AnswerList],
	ResultList1 = lists:sort(fun([_Player_id1, _Nickname1,_Realm1, Score1,_IsCorrect1],[_Player_id2, _Nickname2, _Realm2, Score2, _IsCorrect2]) -> Score1 > Score2 end, AnswerList1),
	ResultList2 = add_order([],ResultList1,1),
	ResultList3 = lists:sublist(ResultList2, 15),
	F1 = fun(ChatOrder,Player_id, Score, IsCorrect) ->
				{ok, BinData} = pt_37:write(37007, [Order,SelectOpt1Num,SelectOpt2Num,SelectOpt3Num,SelectOpt4Num,Reply,ResultList3,Score,ChatOrder,IsCorrect]),
				lib_send:send_to_uid(Player_id, BinData)
		end,
	[F1(ChatOrder,Player_id,Score,IsCorrect) || [ChatOrder,Player_id, _Nickname, _Realm, Score, IsCorrect] <- ResultList2].

%%添加顺序号
add_order(AccList, [], _) ->
    lists:reverse(AccList);
add_order(AccList, [Info | List], N) ->
    NewInfo = [N | Info],
    add_order([NewInfo | AccList], List, N + 1).

get_answer_properties(Order,Ets_Answer) ->
	if Order == 1 ->
			   Ets_Answer#ets_answer.answer1;
		   Order == 2 ->
			   Ets_Answer#ets_answer.answer2;
		   Order == 3 ->
			   Ets_Answer#ets_answer.answer3;
		   Order == 4 ->
			   Ets_Answer#ets_answer.answer4;
		   Order == 5 ->
			   Ets_Answer#ets_answer.answer5;
		   Order == 6 ->
			   Ets_Answer#ets_answer.answer6;
		   Order == 7 ->
			   Ets_Answer#ets_answer.answer7;
		   Order == 8 ->
			   Ets_Answer#ets_answer.answer8;
		   Order == 9 ->
			   Ets_Answer#ets_answer.answer9;
		   Order == 10 ->
			   Ets_Answer#ets_answer.answer10;
		   Order == 11 ->
			   Ets_Answer#ets_answer.answer11;
		   Order == 12 ->
			   Ets_Answer#ets_answer.answer12;
		   Order == 13 ->
			   Ets_Answer#ets_answer.answer13;
		   Order == 14 ->
			   Ets_Answer#ets_answer.answer14;
		   Order == 15 ->
			   Ets_Answer#ets_answer.answer15;
		   Order == 16 ->
			   Ets_Answer#ets_answer.answer16;
		   Order == 17 ->
			   Ets_Answer#ets_answer.answer17;
		   Order == 18 ->
			   Ets_Answer#ets_answer.answer18;
		   Order == 19 ->
			   Ets_Answer#ets_answer.answer19;
		   Order == 20 ->
			   Ets_Answer#ets_answer.answer20;
		   Order == 21 ->
			   Ets_Answer#ets_answer.answer21;
		   Order == 22 ->
			   Ets_Answer#ets_answer.answer22;
		   Order == 23 ->
			   Ets_Answer#ets_answer.answer23;
		   Order == 24 ->
			   Ets_Answer#ets_answer.answer24;
		   Order == 25 ->
			   Ets_Answer#ets_answer.answer25;
		   Order == 26 ->
			   Ets_Answer#ets_answer.answer26;
		   Order == 27 ->
			   Ets_Answer#ets_answer.answer27;
		   Order == 28 ->
			   Ets_Answer#ets_answer.answer28;
		   Order == 29 ->
			   Ets_Answer#ets_answer.answer29;
		   Order == 30 ->
			   Ets_Answer#ets_answer.answer30
	end.

handleTool3(_Order,[],SelectOpt1,SelectOpt2,SelectOpt3,SelectOpt4) ->
	{SelectOpt1,SelectOpt2,SelectOpt3,SelectOpt4};
handleTool3(Order,[H|RestAnswerList],SelectOpt1,SelectOpt2,SelectOpt3,SelectOpt4) ->
	[Ets_Answer] = H,
	Answer_properties = get_answer_properties(Order,Ets_Answer),
	{NewSelectOpt1,NewSelectOpt2,NewSelectOpt3,NewSelectOpt4} = 
	if Answer_properties == ok -> %%不匹配
		    {SelectOpt1,SelectOpt2,SelectOpt3,SelectOpt4};
	   true ->
		   Opt = tool:to_list(Answer_properties#answer_properties.opt),
		   if Opt == "A" ->
				  {"A",SelectOpt1Num} = SelectOpt1,
				  {{"A",SelectOpt1Num+1},SelectOpt2,SelectOpt3,SelectOpt4};
			  Opt == "B" ->
				  {"B",SelectOpt2Num} = SelectOpt2,
				  {SelectOpt1,{"B",SelectOpt2Num+1},SelectOpt3,SelectOpt4};
			  Opt == "C" ->
				  {"C",SelectOpt3Num} = SelectOpt3,
				  {SelectOpt1,SelectOpt2,{"C",SelectOpt3Num+1},SelectOpt4};
			  Opt == "D" ->
				  {"D",SelectOpt4Num} = SelectOpt4,
				  {SelectOpt1,SelectOpt2,SelectOpt3,{"D",SelectOpt4Num+1}};				  
			  true ->
				  {SelectOpt1,SelectOpt2,SelectOpt3,SelectOpt4}
		   end
	end,
	handleTool3(Order,RestAnswerList,NewSelectOpt1,NewSelectOpt2,NewSelectOpt3,NewSelectOpt4).
	
get_selectOpt_num(SelectOptList) ->
	{A ,SelectOpt1Num} = lists:nth(1, SelectOptList),
	{B ,SelectOpt2Num} = lists:nth(2, SelectOptList),
	{C ,SelectOpt3Num} = lists:nth(3, SelectOptList),
	{D ,SelectOpt4Num} = lists:nth(4, SelectOptList),
	MaxValue = lists:max([SelectOpt1Num,SelectOpt2Num,SelectOpt3Num,SelectOpt4Num]),
	if MaxValue == SelectOpt1Num -> {A ,SelectOpt1Num};
	   MaxValue == SelectOpt2Num -> {B ,SelectOpt2Num};
	   MaxValue == SelectOpt3Num -> {C ,SelectOpt3Num};
	true ->
		{D ,SelectOpt4Num}
	end.

get_new_ets_answer(Order,Ets_Answer,Opt) ->
	case Order of
		1 ->
			Ets_Answer#ets_answer{answer1 = Ets_Answer#ets_answer.answer1#answer_properties{opt = Opt}};
		2 ->
			Ets_Answer#ets_answer{answer2 = Ets_Answer#ets_answer.answer2#answer_properties{opt = Opt}};
		3 ->
			Ets_Answer#ets_answer{answer3 = Ets_Answer#ets_answer.answer3#answer_properties{opt = Opt}};
		4 ->
			Ets_Answer#ets_answer{answer4 = Ets_Answer#ets_answer.answer4#answer_properties{opt = Opt}};
		5 ->
			Ets_Answer#ets_answer{answer5 = Ets_Answer#ets_answer.answer5#answer_properties{opt = Opt}};
		6 ->
			Ets_Answer#ets_answer{answer6 = Ets_Answer#ets_answer.answer6#answer_properties{opt = Opt}};
		7 ->
			Ets_Answer#ets_answer{answer7 = Ets_Answer#ets_answer.answer7#answer_properties{opt = Opt}};
		8 ->
			Ets_Answer#ets_answer{answer8 = Ets_Answer#ets_answer.answer8#answer_properties{opt = Opt}};
		9 ->
			Ets_Answer#ets_answer{answer9 = Ets_Answer#ets_answer.answer9#answer_properties{opt = Opt}};
		10 ->
			Ets_Answer#ets_answer{answer10 = Ets_Answer#ets_answer.answer10#answer_properties{opt = Opt}};
		11 ->
			Ets_Answer#ets_answer{answer11 = Ets_Answer#ets_answer.answer11#answer_properties{opt = Opt}};
		12 ->
			Ets_Answer#ets_answer{answer12 = Ets_Answer#ets_answer.answer12#answer_properties{opt = Opt}};
		13 ->
			Ets_Answer#ets_answer{answer13 = Ets_Answer#ets_answer.answer13#answer_properties{opt = Opt}};
		14 ->
			Ets_Answer#ets_answer{answer14 = Ets_Answer#ets_answer.answer14#answer_properties{opt = Opt}};
		15 ->
			Ets_Answer#ets_answer{answer15 = Ets_Answer#ets_answer.answer15#answer_properties{opt = Opt}};
		16 ->
			Ets_Answer#ets_answer{answer16 = Ets_Answer#ets_answer.answer16#answer_properties{opt = Opt}};
		17 ->
			Ets_Answer#ets_answer{answer17 = Ets_Answer#ets_answer.answer17#answer_properties{opt = Opt}};
		18 ->
			Ets_Answer#ets_answer{answer18 = Ets_Answer#ets_answer.answer18#answer_properties{opt = Opt}};
		19 ->
			Ets_Answer#ets_answer{answer19 = Ets_Answer#ets_answer.answer19#answer_properties{opt = Opt}};
		20 ->
			Ets_Answer#ets_answer{answer20 = Ets_Answer#ets_answer.answer20#answer_properties{opt = Opt}};
		21 ->
			Ets_Answer#ets_answer{answer21 = Ets_Answer#ets_answer.answer21#answer_properties{opt = Opt}};
		22 ->
			Ets_Answer#ets_answer{answer22 = Ets_Answer#ets_answer.answer22#answer_properties{opt = Opt}};
		23 ->
			Ets_Answer#ets_answer{answer23 = Ets_Answer#ets_answer.answer23#answer_properties{opt = Opt}};
		24 ->
			Ets_Answer#ets_answer{answer24 = Ets_Answer#ets_answer.answer24#answer_properties{opt = Opt}};
		25 ->
			Ets_Answer#ets_answer{answer25 = Ets_Answer#ets_answer.answer25#answer_properties{opt = Opt}};
		26 ->
			Ets_Answer#ets_answer{answer26 = Ets_Answer#ets_answer.answer26#answer_properties{opt = Opt}};
		27 ->
			Ets_Answer#ets_answer{answer27 = Ets_Answer#ets_answer.answer27#answer_properties{opt = Opt}};
		28 ->
			Ets_Answer#ets_answer{answer28 = Ets_Answer#ets_answer.answer28#answer_properties{opt = Opt}};
		29 ->
			Ets_Answer#ets_answer{answer29 = Ets_Answer#ets_answer.answer29#answer_properties{opt = Opt}};
		30 ->
			Ets_Answer#ets_answer{answer30 = Ets_Answer#ets_answer.answer30#answer_properties{opt = Opt}}
	end.

%%道具2统计
 handleTool2Result(Order,Ets_Answer,Reply) ->
	 if Order >= 2 andalso Order =< 30 -> %%第1题不能引用他人的答题
			Answer_properties = get_answer_properties(Order,Ets_Answer),
			Reference_id = Answer_properties#answer_properties.reference_id,
			Tool = Answer_properties#answer_properties.tool,
			if Tool =/= 2 -> skip;
			   true ->
				   OtherEtsAnswer = ets:lookup(?ETS_ANSWER, Reference_id),
				    if OtherEtsAnswer == [] ->skip;
					   true ->
						  NewOtherEtsAnswer = lists:nth(1, OtherEtsAnswer),
						  Other_Answer_properties = get_answer_properties(Order,NewOtherEtsAnswer),
						  Other_Opt =  Other_Answer_properties#answer_properties.opt,
						  EtsAnswer1 = get_new_ets_answer(Order,Ets_Answer,Other_Opt),
						  if Other_Opt =/= Reply -> 
								 ets:insert(?ETS_ANSWER,EtsAnswer1);
							 true ->
								 EtsAnswer2 = EtsAnswer1#ets_answer{score = (EtsAnswer1#ets_answer.score+5)},
								 ets:insert(?ETS_ANSWER,EtsAnswer2)
						  end
				   end
			end;
		true ->
			skip
	 end.

%%道具3统计
handleTool3Result(Order,AnswerList,Ets_Answer,Reply)->
	{Opt,_MaxSelectOptNum} = get_selectOpt_num(tuple_to_list(handleTool3(Order,AnswerList,{"A",0},{"B",0},{"C",0},{"D",0}))),
	Answer_properties = get_answer_properties(Order,Ets_Answer),
	Tool = Answer_properties#answer_properties.tool,
	if Tool =/= 3 -> skip;
	   true ->	
		  EtsAnswer1 = get_new_ets_answer(Order,Ets_Answer,Opt)	,
		  if Opt =/= Reply ->
				 ets:insert(?ETS_ANSWER,EtsAnswer1);
			 true ->
				 EtsAnswer2 = EtsAnswer1#ets_answer{score = (EtsAnswer1#ets_answer.score+5)},
				 ets:insert(?ETS_ANSWER,EtsAnswer2)
		  end
	end.

%%组装新ets_answer
get_new_answer(EtsAnswer,AnswerOrder,Opt,Tool,Reference_id) ->
	case AnswerOrder of
		1 ->  
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer1 = EtsAnswer#ets_answer.answer1#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> %%道具1数量加1
					 EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					 EtsAnswer1#ets_answer{answer1 = EtsAnswer1#ets_answer.answer1#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> %%道具2数量加1
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer1 = EtsAnswer1#ets_answer.answer1#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> %%道具3数量加1
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer1 = EtsAnswer1#ets_answer.answer1#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ ->
					EtsAnswer
			end;
		2 ->  
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer2 = EtsAnswer#ets_answer.answer2#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer2 = EtsAnswer1#ets_answer.answer2#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer2 = EtsAnswer1#ets_answer.answer2#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer2 = EtsAnswer1#ets_answer.answer2#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		3 ->  
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer3 = EtsAnswer#ets_answer.answer3#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer3 = EtsAnswer1#ets_answer.answer3#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer3 = EtsAnswer1#ets_answer.answer3#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer3 = EtsAnswer1#ets_answer.answer3#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		4 ->  
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer4 = EtsAnswer#ets_answer.answer4#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer4 = EtsAnswer1#ets_answer.answer4#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer4 = EtsAnswer1#ets_answer.answer4#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer4 = EtsAnswer1#ets_answer.answer4#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		5 ->  
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer5 = EtsAnswer#ets_answer.answer5#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer5 = EtsAnswer1#ets_answer.answer5#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer5 = EtsAnswer1#ets_answer.answer5#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer5 = EtsAnswer1#ets_answer.answer5#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		6 ->  
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer6 = EtsAnswer#ets_answer.answer6#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer6 = EtsAnswer1#ets_answer.answer6#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer6 = EtsAnswer1#ets_answer.answer6#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer6 = EtsAnswer1#ets_answer.answer6#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		7 ->  
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer7 = EtsAnswer#ets_answer.answer7#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer7 = EtsAnswer1#ets_answer.answer7#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer7 = EtsAnswer1#ets_answer.answer7#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer7 = EtsAnswer1#ets_answer.answer7#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		8 ->  
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer8 = EtsAnswer#ets_answer.answer8#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer8 = EtsAnswer1#ets_answer.answer8#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer8 = EtsAnswer1#ets_answer.answer8#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer8 = EtsAnswer1#ets_answer.answer8#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		9 ->  
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer9 = EtsAnswer#ets_answer.answer9#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer9 = EtsAnswer1#ets_answer.answer9#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer9 = EtsAnswer1#ets_answer.answer9#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer9 = EtsAnswer1#ets_answer.answer9#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		10 -> 
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer10 = EtsAnswer#ets_answer.answer10#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer10 = EtsAnswer1#ets_answer.answer10#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer10 = EtsAnswer1#ets_answer.answer10#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer10 = EtsAnswer1#ets_answer.answer10#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		11 -> 
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer11 = EtsAnswer#ets_answer.answer11#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer11 = EtsAnswer1#ets_answer.answer11#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer11 = EtsAnswer1#ets_answer.answer11#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer11 = EtsAnswer1#ets_answer.answer11#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		12 -> 
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer12 = EtsAnswer#ets_answer.answer12#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer12 = EtsAnswer1#ets_answer.answer12#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer12 = EtsAnswer1#ets_answer.answer12#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer12 = EtsAnswer1#ets_answer.answer12#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		13 -> 
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer13 = EtsAnswer#ets_answer.answer13#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer13 = EtsAnswer1#ets_answer.answer13#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer13 = EtsAnswer1#ets_answer.answer13#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer13 = EtsAnswer1#ets_answer.answer13#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		14 -> 
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer14 = EtsAnswer#ets_answer.answer14#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer14 = EtsAnswer1#ets_answer.answer14#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer14 = EtsAnswer1#ets_answer.answer14#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer14 = EtsAnswer1#ets_answer.answer14#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		15 -> 
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer15 = EtsAnswer#ets_answer.answer15#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer15 = EtsAnswer1#ets_answer.answer15#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer15 = EtsAnswer1#ets_answer.answer15#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer15 = EtsAnswer1#ets_answer.answer15#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		16 -> 
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer16 = EtsAnswer#ets_answer.answer16#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer16 = EtsAnswer1#ets_answer.answer16#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer16 = EtsAnswer1#ets_answer.answer16#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer16 = EtsAnswer1#ets_answer.answer16#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		17 -> 
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer17 = EtsAnswer#ets_answer.answer17#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer17 = EtsAnswer1#ets_answer.answer17#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer17 = EtsAnswer1#ets_answer.answer17#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer17 = EtsAnswer1#ets_answer.answer17#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		18 -> 
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer18 = EtsAnswer#ets_answer.answer18#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer18 = EtsAnswer1#ets_answer.answer18#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer18 = EtsAnswer1#ets_answer.answer18#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer18 = EtsAnswer1#ets_answer.answer18#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		19 -> 
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer19 = EtsAnswer#ets_answer.answer19#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer19 = EtsAnswer1#ets_answer.answer19#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer19 = EtsAnswer1#ets_answer.answer19#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer19 = EtsAnswer1#ets_answer.answer19#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		20 -> 
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer20 = EtsAnswer#ets_answer.answer20#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer20 = EtsAnswer1#ets_answer.answer20#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer20 = EtsAnswer1#ets_answer.answer20#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer20 = EtsAnswer1#ets_answer.answer20#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		21 -> 
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer21 = EtsAnswer#ets_answer.answer21#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer21 = EtsAnswer1#ets_answer.answer21#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer21 = EtsAnswer1#ets_answer.answer21#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer21 = EtsAnswer1#ets_answer.answer21#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		22 -> 
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer22 = EtsAnswer#ets_answer.answer22#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer22 = EtsAnswer1#ets_answer.answer22#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer22 = EtsAnswer1#ets_answer.answer22#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer22 = EtsAnswer1#ets_answer.answer22#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		23 -> 
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer23 = EtsAnswer#ets_answer.answer23#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer23 = EtsAnswer1#ets_answer.answer23#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer23 = EtsAnswer1#ets_answer.answer23#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer23 = EtsAnswer1#ets_answer.answer23#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		24 -> 
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer24 = EtsAnswer#ets_answer.answer24#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer24 = EtsAnswer1#ets_answer.answer24#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer24 = EtsAnswer1#ets_answer.answer24#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer24 = EtsAnswer1#ets_answer.answer24#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		25 -> 
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer25 = EtsAnswer#ets_answer.answer25#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer25 = EtsAnswer1#ets_answer.answer25#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer25 = EtsAnswer1#ets_answer.answer25#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer25 = EtsAnswer1#ets_answer.answer25#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		26 -> 
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer26 = EtsAnswer#ets_answer.answer26#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer26 = EtsAnswer1#ets_answer.answer26#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer26 = EtsAnswer1#ets_answer.answer26#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer26 = EtsAnswer1#ets_answer.answer26#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		27 -> 
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer27 = EtsAnswer#ets_answer.answer27#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer27 = EtsAnswer1#ets_answer.answer27#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer27 = EtsAnswer1#ets_answer.answer27#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer27 = EtsAnswer1#ets_answer.answer27#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		28 -> 
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer28 = EtsAnswer#ets_answer.answer28#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer28 = EtsAnswer1#ets_answer.answer28#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer28 = EtsAnswer1#ets_answer.answer28#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer28 = EtsAnswer1#ets_answer.answer28#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		29 ->
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer29 = EtsAnswer#ets_answer.answer29#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer29 = EtsAnswer1#ets_answer.answer29#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer29 = EtsAnswer1#ets_answer.answer29#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer29 = EtsAnswer1#ets_answer.answer29#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		30 -> 
			case Tool of
				0 -> %%不使用道具
					EtsAnswer#ets_answer{answer30 = EtsAnswer#ets_answer.answer30#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				1 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool1 =  (EtsAnswer#ets_answer.tool1+1)},
					EtsAnswer1#ets_answer{answer30 = EtsAnswer1#ets_answer.answer30#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				2 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool2 =  (EtsAnswer#ets_answer.tool2+1)},
					EtsAnswer1#ets_answer{answer30 = EtsAnswer1#ets_answer.answer30#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				3 -> 
					EtsAnswer1 = EtsAnswer#ets_answer{tool3 =  (EtsAnswer#ets_answer.tool3+1)},
					EtsAnswer1#ets_answer{answer30 = EtsAnswer1#ets_answer.answer30#answer_properties{opt = Opt,tool = Tool, reference_id = Reference_id}};
				_ -> 
					EtsAnswer
			end;
		_ -> EtsAnswer
	end.

%%答题时间判断
%%当前时间NowSec
%%当前时间NowSec
%%题目顺序号 AnswerOrder
%%要减去10秒阅题时间
%%进程字典，存储时间误差
get_answer_time(NowSec,StartAnswerTime,AnswerOrder) ->
	Timerdelay = get(timerdelay),
	Timerdelay1 = 
	if Timerdelay == undefined ->
		   0;
	   true ->
		   Timerdelay
	end,		  
	NowSec - StartAnswerTime - (AnswerOrder-1)*30 - 10 - Timerdelay1.

%%计算答题获得分数
get_scroe(Time,Tool) ->
	case Tool of
		0 -> %%没有使用道具
			if Time =< 1 ->
				   10;
			   Time > 1 andalso Time =< 2 ->
				   9;
			   Time > 2 andalso Time =< 3 ->
				   8;
			   Time > 3 andalso Time =< 4 ->
				   7;
			   Time > 4 andalso Time =< 5 ->
				   6;
			   Time > 5 andalso Time =< 6 ->
				   5;
			   Time > 6 andalso Time =< 7 ->
				   4;
			   Time > 7 andalso Time =< 8 ->
				   3;
			   Time > 8 andalso Time =< 9 ->
				   2;
			   Time > 9 andalso Time =< 15 ->
				   1;
			   true ->
				   0
			end;  
		1 -> %%使用第一种道具
			if Time =< 1 ->
				   10*2;
			   Time > 1 andalso Time =< 2 ->
				   9*2;
			   Time > 2 andalso Time =< 3 ->
				   8*2;
			   Time > 3 andalso Time =< 4 ->
				   7*2;
			   Time > 4 andalso Time =< 5 ->
				   6*2;
			   Time > 5 andalso Time =< 6 ->
				   5*2;
			   Time > 6 andalso Time =< 7 ->
				   4*2;
			   Time > 7 andalso Time =< 8 ->
				   3*2;
			   Time > 8 andalso Time =< 9 ->
				   2*2;
			   Time > 9 andalso Time =< 15 ->
				   1*2;
			   true ->
				   0
			end;  
		_ -> %%使用第 二，三种道具答对得5分
			5
	end.

%%重新登陆检查是否在答题时间内
check_answer_time(Player) ->
	PlayerId = Player#player.id, 
	PidSend = Player#player.other#player_other.pid_send,
	WeekDay = util:get_date(),
	LimitLv = mod_answer:get_answer_data_by_type(answer_lv),
	Bool = lists:member(WeekDay, mod_answer:get_answer_data_by_type(answer_data)),
	if 
		Bool ->  
		   Time1 = mod_answer:get_answer_data_by_type(answer_notify_start),
		   Time2 = mod_answer:get_answer_data_by_type(answer_join_start),
		   Time3 = mod_answer:get_answer_data_by_type(answer_start),
		   Time4 = mod_answer:get_answer_data_by_type(answer_end),
		   Timerdelay = get(timerdelay),
		   Timerdelay1 =
			   if Timerdelay == undefined ->
					  0;
				  true ->
					  Timerdelay
			   end,
		   NowSec = util:get_today_current_second(),
		   if  (NowSec - Time1) > Timerdelay1 andalso (NowSec < Time2) ->
				   {ok, BinData} = pt_37:write(37002, [1,120-(NowSec-Time1)+Timerdelay1]),
				   lib_send:send_to_sid(PidSend, BinData);
			   (NowSec - Time2) > Timerdelay1 andalso (NowSec < Time3) ->
				   EtsAnswerList = ets:match(?ETS_ANSWER,_='$1'),
				   AnswerList = [Ets_Answer#ets_answer.player_id || [Ets_Answer] <- EtsAnswerList],
				   case lists:member(PlayerId, AnswerList) of 
					   true ->
						   {ok, BinData3} = pt_37:write(37005, [1, 0, 0, 0]),
						   lib_send:send_to_sid(PidSend, BinData3),
						   {ok, BinData4} = pt_37:write(37002, [3,60-(NowSec-Time2)+Timerdelay1]),
						   lib_send:send_to_sid(PidSend, BinData4);	
					   false ->
						   {ok, BinData4} = pt_37:write(37002, [3,60-(NowSec-Time2)+Timerdelay1]),
						   lib_send:send_to_sid(PidSend, BinData4)
				   end,
				   {ok, BinData} = pt_37:write(37002, [2,60-(NowSec-Time2)+Timerdelay1]),
				   lib_send:send_to_sid(PidSend, BinData); 
			   (NowSec - Time3) > Timerdelay1 andalso (NowSec < Time4) ->
				   EtsAnswerObj = ets:lookup(?ETS_ANSWER, PlayerId),
				   %%是否报名参加答题活动
				   case EtsAnswerObj =/= [] of 
					   true ->
						   %%打开答题窗口
						   [EtsAnswer] = EtsAnswerObj,
						   Tool1 = EtsAnswer#ets_answer.tool1,
						   Tool2 = EtsAnswer#ets_answer.tool2,
						   Tool3 = EtsAnswer#ets_answer.tool3,
						   {ok, BinData1} = pt_37:write(37005, [1, Tool1, Tool2, Tool3]),
						   lib_send:send_to_sid(PidSend, BinData1),
						   {ok, BinData3} = pt_37:write(37002, [8,15*60-(NowSec-Time3)+Timerdelay1]),
						   lib_send:send_to_sid(PidSend, BinData3),
						   %%计算现在出题序号
						   TimeValue = (NowSec - Time3) rem 30,%%计算现在应该显示的倒计时
						   if TimeValue >= 0 andalso  TimeValue =< 10 ->
								  {ok, BinData2} = pt_37:write(37002, [5,(10-TimeValue)]),
								  lib_send:send_to_sid(PidSend, BinData2);
							  TimeValue > 10 andalso  TimeValue =< 25 ->
								  {ok, BinData2} = pt_37:write(37002, [6,(25-TimeValue)]),
								  lib_send:send_to_sid(PidSend, BinData2);
							  TimeValue > 25 andalso  TimeValue =< 30 ->
								  {ok, BinData2} = pt_37:write(37002, [7,(30-TimeValue)]),
								  lib_send:send_to_sid(PidSend, BinData2);
							  true ->
								  skip
						   end;
					   false ->
						   if Player#player.lv >= LimitLv ->
								  EtsAnswer = #ets_answer{
										player_id = PlayerId,
										nickname = Player#player.nickname,
										realm = Player#player.realm
										},
								  ets:insert(?ETS_ANSWER,EtsAnswer),
								  {ok, BinData3} = pt_37:write(37002, [8,15*60-(NowSec-Time3)+Timerdelay1]),
								  lib_send:send_to_sid(PidSend, BinData3);
							  true ->
								  skip
						   end
				   end;
			   true ->
				   skip
		   end;
	   	true ->
		   skip
	end.

%%重启答题
put_answer_hour_time(Time) ->
	lib_answer:init_answer(),
	put(answer_hour_time,Time),
	ok.

get_answer_hour_time_by_dict() ->
	get(answer_hour_time).

get_mod_answer_data_by_type(Type) ->
	if
		%%活动开始时间从字典中取值，如果没有则从宏定义中取值
		Type == answer_hour_time -> mod_answer:get_answer_data_by_type(answer_hour_time); %%设定答题时间值
		Type == answer_notify_start -> mod_answer:get_answer_data_by_type(answer_hour_time) + 2*60; %%答题前二分钟广播（9:12）15*3600+10*60
		Type == answer_join_start -> mod_answer:get_answer_data_by_type(answer_hour_time) + 4*60;   %%答题报名开始时间广播（9:14）21*3600+14*60
		Type == answer_start -> mod_answer:get_answer_data_by_type(answer_hour_time) + 5*60;        %%答题开始时间广播（9:15）21*3600+14*60
		Type == answer_end -> mod_answer:get_answer_data_by_type(answer_hour_time) + 20*60;        %%答题结束时间广播（9:30）21*3600+30*60
		Type == answer_end_finish -> mod_answer:get_answer_data_by_type(answer_hour_time) + 20*60 + 10; %%答题结束检查时间20*3600+30*60
		true ->
			0
	end.	

test() ->
	A = [{4,1},{1,2},{3,1},{1,3},{2,3},{3,2},{3,3},{3,4},{2,5}],
	D = lists:sort(fun({X1,Y1},{X2,Y2}) -> 
						   if X1 =/= X2 -> 
								  X1 > X2; 
							  true -> 
								  Y1 >= Y2 
						   end 
				   end ,
				   A),
	io:format("D is ~p~n",[D]),
	ok.
