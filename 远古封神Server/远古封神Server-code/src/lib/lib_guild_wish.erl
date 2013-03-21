%% Author: xianrongMai
%% Created: 2011-9-23
%% Description: 氏族祝福相关处理
-module(lib_guild_wish).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include("guild_info.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
%%
%% Exported Functions
%%
-export([
		 gwish_task_finish_rightnow/3,
		 task_gwish_giveup/1,		%%玩家取消任务(任务面板上面的那个任务)
		 notice_mem_gwish/1,		%%通知玩家上/下线啦
		 make_gwish_dic/1,			%%弄进程字典数据
		 db_update_gwish/2,
		 make_probability/1,		%%做随机数
		 check_init_guild_wish/5,	%%检查是否已经初始化
		 leave_guild/1,
		 join_guild/5,
		 logout/1,
		 delete_mem_gwish/1,
		 check_player_gwish/2,		%% 仅供mod_player模块调用，如需调用，请调用lib_gwish_interface:check_player_gwish/2
		 invite_other_flush/4,		%% 40075  邀请别人帮忙刷任务运势
		 help_other_flush/4,		%% 40073  帮他人刷新运势
		 add_gwish_logs/8,			%% 添加日志
		 get_guild_gwish/3,			%% 40072  氏族祝福成员运势
		 ets_get_f5gwish/1,			%% #ets_f5_gwish操作
		 get_gwish_dict/0,			%% dict操作
		 put_gwish_dict/1,
		 add_mem_gwish/1,
		 random_task_id/2,			%% 随机玩家的任务Id
		 init_guild_wish/5			%% 初始化玩家的氏族祝福数据
		]).

%%
%% API Functions
%%
%%检查是否已经初始化过了
check_init_guild_wish(PId, PName, PSex, PCareer, PGId) ->
	case get(init_gwish) of
		1 ->
%% 			?DEBUG("has init the gwish", []),
			skip;
		_ ->
			init_guild_wish(PId, PName, PSex, PCareer, PGId)
	end.

%%初始化玩家的氏族祝福数据
init_guild_wish(PId, PName, Sex, Career, PGId) ->
%% 	?DEBUG("Init PId:~p, PGId:~p", [PId, PGId]),
	case PGId of
		0 ->%%没氏族，什么都不用做,仅作删除数据的操作
			skip;
		_ ->%%有氏族喔
			Fieldslist = "luck, t_color, tstate, tid, task, help, bhelp, flush, time, finish",
			WhereList = [{pid, PId}],
			NowTime = util:unixtime(),
			case db_get_gwish(Fieldslist, WhereList) of
				[] ->%%第一次初始化，数据库都没数据呢
%% 					?DEBUG("init has no data", []),
					Luck = make_probability(?PLAYER_WISH_PRODIST),%%获取玩家运势星级
					TColor = 0,
					TId = 0,
					Task = 0,
					Flush = 0,
					Time = NowTime,
					Help = 0,
					BHelp = 0,
					TState = 0,
					Finish = [],
					FinishStr = util:term_to_string(Finish),
					Fields = [pid, luck, t_color, tid, tstate, task, help, bhelp, flush, time, finish],
					Values = [PId, Luck, TColor, TId, TState, Task, Help, BHelp, Flush, Time, FinishStr],
					%%插入数据库
					db_insert_gwish(Fields,Values),
					Dict = [Luck, TColor, TId, TState, Task, Help, BHelp, Flush, Time, Finish],
					DictEts =  make_gwish_dic(Dict),
					%%放进程字典
					put_gwish_dict(DictEts),
					MemNotices = [PId, PGId, PName, Sex, Career, Luck, TId, TColor, TState, Help, BHelp],
					%%通知玩家上线啦
					notice_mem_gwish(MemNotices);
				[Luck, TColor, TState, TId, Task, Help, BHelp, Flush, Time, FinishStr] ->
%% 					?DEBUG("init the data is Luck:~p, TColor:~p, TId:~p, TState:~p, Task:~p, Help:~p, BHelp:~p, Flush:~p, Time:~p", [Luck, TColor, TId, TState, Task, Help, BHelp, Flush, Time]),
					case util:is_same_date(NowTime, Time) of
						true ->%%是同一天，说明已经刷过玩家运势了
							case FinishStr =:= [] orelse FinishStr =:= undefined of
								true ->
									Finish = [];
								false ->
									Finish = util:string_to_term(tool:to_list(FinishStr))
							end,
							Dict = [Luck, TColor, TId, TState, Task, Help, BHelp, Flush, Time, Finish],
							DictEts =  make_gwish_dic(Dict),
							%%放进程字典
							put_gwish_dict(DictEts),
							MemNotices = [PId, PGId, PName, Sex, Career, Luck, TId, TColor, TState, Help, BHelp],
							%%通知玩家上线啦
							notice_mem_gwish(MemNotices),
							%%加载帮助日志
							load_gwish_log(NowTime, PId);
						false ->
							%%重新获取玩家运势星级
							NLuck = make_probability(?PLAYER_WISH_PRODIST),
							NTime = NowTime,
							NHelp = 0,
							NBHelp = 0,
							NFinish = [],
							NFinishStr = util:term_to_string(NFinish),
							ValueList = [{luck, NLuck}, {help, NHelp}, {bhelp, NBHelp},{time, NTime}, {finish, NFinishStr}],
							WhereList = [{pid, PId}],
							%%更新数据库
							db_update_gwish(ValueList, WhereList),
							Dict = [NLuck, TColor, TId, TState, Task, NHelp, NBHelp, Flush, NTime, NFinish],
							DictEts =  make_gwish_dic(Dict),
							%%放进程字典
							put_gwish_dict(DictEts),
							MemNotices = [PId, PGId, PName, Sex, Career, Luck, TId, TColor, TState, NHelp, NBHelp],
							%%通知玩家上线啦
							notice_mem_gwish(MemNotices),
							%%加载帮助日志
							load_gwish_log(NowTime, PId)
					end
			end,
			put(init_gwish,1)
	end.
	
%%玩家不再拥有氏族时的处理
leave_guild(PId) ->
	put(init_gwish, 0),
	logout(PId).%%因为跟玩家下线是一样的，所以处理都一样
	
%%玩家加入氏族大家庭啦
join_guild(PId, PName, PSex, PCareer, PGId) ->
	init_guild_wish(PId, PName, PSex, PCareer, PGId).
%%玩家下线数据处理
logout(PId) ->
	%%删除日志
	ets_delete_f5gwish_id(PId),
	gen_server:cast(mod_guild:get_mod_guild_pid(), 
					{apply_cast, lib_guild_wish, delete_mem_gwish, [PId]}).

delete_mem_gwish(PId) ->
	%%通知删除成员运势记录
%% 	?DEBUG("delete mem gwish,PId:~p", [PId]),
	ets_delete_mgwish(PId).

%%通知更新氏族成员运势表
notice_mem_gwish(MemNotices) ->
	gen_server:cast(mod_guild:get_mod_guild_pid(), 
					{apply_cast, lib_guild_wish, add_mem_gwish, [MemNotices]}).
add_mem_gwish([PId, PGId, PName, Sex, Career, Luck, TId, TColor, TState, Help, BHelp]) ->
	MemWish = #mem_gwish{pid = PId,
						 gid = PGId,
						 pname = PName,
						 sex = Sex,
						 career = Career,
						 luck = Luck,
						 tid = TId,
						 t_color = TColor,
						 tstate = TState,
						 help = Help,
						 bhelp = BHelp},
	ets_insert_mem_gwish(MemWish).
%% -----------------------------------------------------------------
%% 40072  氏族祝福成员运势
%% -----------------------------------------------------------------
get_guild_gwish(ReHelp, GuildId, PidSend) ->
	Result = ets_get_mgwish_bygid(GuildId),
%% 	?DEBUG("40072 send the guild wish:~p", [Result]),
	{ok, BinData} = pt_40:write(40072, [{ReHelp, Result}]),
	lib_send:send_to_sid(PidSend, BinData).

%%加载帮助日志
load_gwish_log(Nowtime, PId) ->
	{ToDay, _NextDay} = util:get_midnight_seconds(Nowtime),
	Lists = db_agent:db_get_f5gwish(PId,ToDay),
	lists:foreach(fun(Elem) ->
						  EtsElem = list_to_tuple([ets_f5_gwish] ++ Elem),
						  ets_insert_f5gwish(EtsElem)
				  end,Lists).
		
%% -----------------------------------------------------------------
%% 40073  帮他人刷新运势
%% -----------------------------------------------------------------
help_other_flush(SPId, SPName, SGW, DPId) ->
	#p_gwish{luck = Luck,
			 help = Help} = SGW,
	case Help >= ?GWISH_HELP_LIMIT of
		true ->
			{2, 0, "", SGW};
		false ->
			case ets_get_mgwish_bypgid(DPId) of
				[] ->
					{4, 0, "", SGW};
				[DMGW] ->
					case lib_player:get_player_pid(DPId) of
						[] ->%%不在线
							{4, 0, "", SGW};
						DPPid ->
							#mem_gwish{bhelp = DBHelp,
									   pname = DPName,
									   tid = DTId} = DMGW,
							if
								DTId =:= 0 ->%%没有任务
									{5, 0, "", SGW};
%% 								DTState =:= 3 ->%%已经接收了任务了
%% 									{6, 0, "", SGW};
								true ->
									%%刷新任务运势
									TCLuck = lists:nth(Luck, ?TASK_COLOR_LUCK),
									TColor = lib_guild_wish:make_probability(TCLuck),
									NBHelp = DBHelp + 1,
									NDNGW = DMGW#mem_gwish{t_color = TColor,
														   bhelp = NBHelp},
									ets_insert_mem_gwish(NDNGW),
									%%通知对方
									Notices = [SPId, SPName, Luck, TColor],
									gen_server:cast(DPPid, {'HELP_FLUSH_GWISH_TASK', Notices}),
									%%返回自己新的SGW
									NSGW = SGW#p_gwish{help = Help+1},
									{1, TColor, DPName, NSGW}
							end
					end
			end
	end.
%%添加日志
add_gwish_logs(DPId, SPId, SPName, Luck, DOTColor, TColor, TId, NowTime) ->
	 F5GWish = 
		#ets_f5_gwish{pid = DPId,                                %% 玩家Id(被刷的玩家的Id)	
					  hpid = SPId,                               %% 帮忙刷新的玩家的Id	
					  hpname = SPName,                            %% 帮忙刷新的玩家的名字	
					  hluck = Luck,                              %% 帮忙刷新的玩家的运势	
					  ocolor = DOTColor,                            %% 被帮忙的玩家原来的任务运势等级，N：N星	
					  ncolor = TColor,                             %% 被帮忙的玩家新的任务运势等级，N：N星	
					  tid = TId,
					  time = NowTime                                %% 帮忙时间	
					 },
	{_, Id} =db_agent:add_gwish_logs(F5GWish),
	NewF5GWish = F5GWish#ets_f5_gwish{id = Id},
	ets_insert_f5gwish(NewF5GWish).
	 
	
%% -----------------------------------------------------------------
%% 40075  邀请别人帮忙刷任务运势
%% -----------------------------------------------------------------
invite_other_flush(SPId, SPName, SGId, DPId) ->
	case ets_get_mgwish_bypgid(DPId) of
		[] ->
			{fail, 4};
		[DMGW] ->
			case lib_player:get_player_pid(DPId) of
				[] ->%%不在线
					{fail, 4};
				DPPid ->
					#mem_gwish{gid = DGId,
							   help = DHelp} = DMGW,
					if 
						DHelp >= ?GWISH_HELP_LIMIT ->%%对方超过次数啦
							{fail, 3};
						DGId =/= SGId ->%%已经不同氏族了
							{fail, 6};
						true ->%%没超过人数，可以刷
							%%通知被邀请的那个玩家
							Notices = {SPId, SPName},
							gen_server:cast(DPPid, {'INVITE_FLUSH_GWISH_TASK', Notices}),
							ok
					end
			end
	end.
							

%%
%% Local Functions
%%
db_get_gwish(FieldsList, WhereList) ->
	db_agent:db_get_gwish(guild_wish, FieldsList, WhereList).
db_update_gwish(ValueList, WhereList) ->
	db_agent:db_update_gwish(guild_wish, ValueList, WhereList).
%% db_delete_gwish(WhereList) ->
%% 	db_agent:db_delete_gwish(guild_wish, WhereList).
db_insert_gwish(Fields,Values) ->
	db_agent:db_insert_gwish(guild_wish, Fields, Values).

ets_insert_mem_gwish(MemWish) ->
	ets:insert(?MEMBER_GWISH, MemWish).
ets_get_mgwish_bygid(GId) ->
	Pattern = #mem_gwish{gid = GId, _ = '_'},
	ets:match_object(?MEMBER_GWISH, Pattern).
ets_get_mgwish_bypgid(PId) ->
	ets:lookup(?MEMBER_GWISH, PId).
ets_delete_mgwish(PId) ->
	ets:delete(?MEMBER_GWISH, PId).
		

ets_insert_f5gwish(F5GWish) ->
	ets:insert(?LOG_F5_GWISH, F5GWish).
ets_delete_f5gwish(Key) ->
	ets:delete(?LOG_F5_GWISH, Key).
ets_delete_f5gwish_id(PId) ->
	ets:match_delete(?LOG_F5_GWISH, #ets_f5_gwish{pid=PId, _='_' }).
ets_get_f5gwish(PId) ->
	Pattern = #ets_f5_gwish{pid = PId, _ = '_'},
	Result = ets:match_object(?LOG_F5_GWISH, Pattern),
	Len = length(Result),
	case Len > ?F5_GWISH_LIMIT of
		true ->
			Sort = lists:keysort(#ets_f5_gwish.time, Result),
			Sub = lists:sublist(Sort, Len - ?F5_GWISH_LIMIT+1, ?F5_GWISH_LIMIT),
			DSub = lists:sublist(Sort, ?F5_GWISH_LIMIT),
			lists:foreach(fun(Elem) ->
								ets_delete_f5gwish(Elem#ets_f5_gwish.id)
						  end, DSub),
			Sub;
		false ->
			lists:keysort(#ets_f5_gwish.time, Result)
	end.

%%dict操作
put_gwish_dict(Dict) ->
	put(gwish, Dict).
get_gwish_dict() ->
	case get(gwish) of
		undefined ->
%% 			?DEBUG("undefined", []),
			#p_gwish{};
		GuildWish when is_record(GuildWish, p_gwish) ->
%% 			?DEBUG("ok:~p", [GuildWish]),
			GuildWish;
		_Other ->
%% 			?DEBUG("other:~p", [_Other]),
			#p_gwish{}
	end.

make_probability(ProDist) ->
	{One, Two, Three, Four, Five} = ProDist,
	RandNum = util:rand(1, 100),
	if
		RandNum =< One ->
			1;%%一星
		RandNum =< Two ->
			2;%%二星
		RandNum =< Three ->
			3;%%三星
		RandNum =< Four ->
			4;%%四星
		RandNum =< Five ->
			5;%%五星
		true ->
			1%%随机数出问题了，居然跑这里来，拉倒直接给个 一星 
	end.
make_gwish_dic(Dic) ->
	[Luck, TColor, TId, TState, Task, Help, BHelp, Flush, Time, Finish] = Dic,
	#p_gwish{luck = Luck, 		%%玩家当天运势，N：N颗星
			 t_color = TColor,	%%任务运势等级，N：N星
			 tid = TId,			%%刷出来的任务Id
			 tstate = TState,	%%任务状态
			 task = Task,		%%任务完成情况，此值会根据不同的任务情况，做不同的数值保存
			 help = Help,		%%助人次数
			 bhelp = BHelp,		%%被帮助次数
			 flush = Flush,		%%任务刷新时间
			 time = Time,		%%玩家运势刷新时间
			 finish = Finish	%%玩家当天已经完成的任务Ids
			}.

%%随机玩家的任务Id
random_task_id(PLv, Finish) ->
	TLen = length(?GWISH_TASK_LIST),
	RandNum = util:rand(1, TLen),
	{TId, TLv} = lists:nth(RandNum, ?GWISH_TASK_LIST),
	case lists:member(TId, Finish) of
		true ->
			get_next_task(PLv, TLen, RandNum+1, Finish);
		false ->
			case TLv > PLv of
				true ->
					get_next_task(PLv, TLen, RandNum+1, Finish);
				false ->
					TId
			end
	end.
get_next_task(PLv, TLen, RandNum, Finish) ->
	case TLen < RandNum of
		true ->
			NRandNum = 1,
			{TId, TLv} = lists:nth(NRandNum, ?GWISH_TASK_LIST),
			case lists:member(TId, Finish) of
				true ->
					get_next_task(PLv, TLen, NRandNum+1, Finish);
				false ->
					case TLv > PLv of
						true ->
							get_next_task(PLv, TLen, NRandNum+1, Finish);
						false ->
							TId
					end
			end;
		false ->
			{TId, TLv} = lists:nth(RandNum, ?GWISH_TASK_LIST),
			case lists:member(TId, Finish) of
				true ->
					get_next_task(PLv, TLen, RandNum+1, Finish);
				false ->
					case TLv > PLv of
						true ->
							get_next_task(PLv, TLen, RandNum+1, Finish);
						false ->
							TId
					end
			end
	end.
%%玩家取消任务(任务面板上面的那个任务)
task_gwish_giveup(Status) ->
	#player{id = PId,
			sex = Sex,
			career = Career,
			guild_id = PGId,
			nickname = PName} = Status,
	%%检查是否已经初始化过了
	lib_guild_wish:check_init_guild_wish(Status#player.id, Status#player.nickname, Status#player.sex, Status#player.career, Status#player.guild_id),
	%%获取氏族祝福任务的详细数据
	GWish = lib_guild_wish:get_gwish_dict(),
	#p_gwish{luck = Luck,
			 tid = TId,
			 t_color = TColor,
			 help = Help,
			 bhelp = BHelp} = GWish,
	NTState = 1,
	NTask = 0,
	NGWish = GWish#p_gwish{tstate = NTState,
						   task = NTask},
	ValueList = [{tstate, NTState}, {task, NTask}],
	WhereList = [{pid, PId}],
	%%更新dict
	lib_guild_wish:put_gwish_dict(NGWish),
	%%更新数据库
	lib_guild_wish:db_update_gwish(ValueList, WhereList),
	MemNotices = [PId, PGId, PName, Sex, Career, Luck, TId, TColor, NTState, Help, BHelp],
	%%通知氏族玩家数据更新啦
	lib_guild_wish:notice_mem_gwish(MemNotices).

gwish_task_finish(Player, GWish, NTask) ->
	#player{id = PId,
			sex = Sex,
			career = Career,
			guild_id = PGId,
			nickname = PName,
			other = Other} = Player,
	#player_other{pid_send = PidSend} = Other,
	#p_gwish{luck = Luck,
			 tid = TId,
			 t_color = TColor,
			 help = Help,
			 bhelp = BHelp} = GWish,
	NTState = 3,
	NGWish = GWish#p_gwish{tstate = NTState,
						   task = NTask},
	ValueList = [{tstate, NTState}, {task, NTask}],
	WhereList = [{pid, PId}],
	%%更新dict
	lib_guild_wish:put_gwish_dict(NGWish),
	%%更新数据库
	lib_guild_wish:db_update_gwish(ValueList, WhereList),
	MemNotices = [PId, PGId, PName, Sex, Career, Luck, TId, TColor, NTState, Help, BHelp],
	%%通知氏族玩家数据更新啦
	lib_guild_wish:notice_mem_gwish(MemNotices),
	%%通知任务可提交
%% 	lib_task:event(guild_bless, null, Player),
%% 	lib_task:auto_finish_task(Player,?GUILD_WISH_TASK_ID),
	%%通知玩家
%% 	?DEBUG("gwish_task_finish:~p", [TId]),
	%%通知任务变成可提交
	lib_task:event(guild_bless, null, Player),
	{ok, BinData} = pt_40:write(40071, [TId]),
	lib_send:send_to_sid(PidSend, BinData).

gwish_task_update(Player, GWish, NTask) ->
	PId = Player#player.id,
	NGWish = GWish#p_gwish{task = NTask},
	ValueList = [{task, NTask}],
	WhereList = [{pid, PId}],
	%%更新dict
	lib_guild_wish:put_gwish_dict(NGWish),
	%%更新数据库
	lib_guild_wish:db_update_gwish(ValueList, WhereList).

% 玩家氏族祝福任务完成情况检查
check_player_gwish(Player, GWParam) ->
	{Type, Num} = GWParam,
	%%获取氏族祝福任务的详细数据
	GWish = lib_guild_wish:get_gwish_dict(),
	#p_gwish{tid = TId,
			 tstate = TState,
			 task = Task} = GWish,
%% 	?DEBUG("Type:~p,TId:~p, TState:~p", [Type, TId, TState]),
	TIds = 
		if
			TId > 0 andalso TId =< ?GWISH_TASK_LIMIT_NUM ->
				lists:nth(TId, ?GWISH_TASK_TIDS_LIST);
			true ->
				[]
		end,
	case lists:member(Type, TIds) andalso TState =:= 2 of
		false ->
			skip;
		true ->
			case Type of
				1 ->%%  赠送玫瑰	增送1次玫瑰花
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				2 ->%%  吃仙桃	吃1个仙桃
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				3 ->%%  物美价廉	在商城中购买一件道具							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				4 ->%%  发起诛邪	诛邪1次							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				5 ->%%  封神帖	完成1次封神帖任务，							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				6 ->%%  封神台	通关一次封神台9层							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				7 ->%%  单人镇妖	单人镇妖台击退20波怪物							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				8 ->%%  多人镇妖	多人镇妖击退20波怪物							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				9 ->%%  仙侣奇缘	完成一次仙侣奇缘							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				10 ->%%  诛仙台	通关诛仙台第九层							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				11 ->%%  珍贵宝石	合成2级宝石一次							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				12 ->%%  活跃分子	活跃度达到100							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				13 ->%%  远古运镖	运镖1次							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				14 ->%%  温柔两刀	战场击败2名玩家							
					NTask = Task + Num,
					case NTask >= ?TASK_14 of
						true ->
							gwish_task_finish(Player, GWish, NTask);
						false ->
							gwish_task_update(Player, GWish, NTask)
					end;
				15 ->%%  在线有礼	领取完毕今天的在线奖励（右上角的在线宝箱）							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				16 ->%%  氏族运旗	氏族运送旗子1次							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				17 ->%%  高效挂机	完成30分钟挂机园挂机							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				18 ->%%  远古试炼	完成1次远古试炼							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				19 ->%%  出售果实	出售10个庄园果实							
					NTask = Task + Num,
					case NTask >= ?TASK_19 of
						true ->
							gwish_task_finish(Player, GWish, NTask);
						false ->
							gwish_task_update(Player, GWish, NTask)
					end;
				20 ->%%  快乐跑商	完成1次跑商任务							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				21 ->%%  为了部落	完成1次荣誉任务							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				22 ->%%  修为高深	完成一次修为任务							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				23 ->%%  智力答题	完成一次智力答题							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				24 ->%%  狂扫副本	完成一次最高等级副本任务							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				25 ->%%  泡泡温泉	泡温泉1次							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				26 ->%%  日常守护	完成1次日常守护任务							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				27 ->%%  氏族BOSS	今天打败一次氏族BOSS							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				28 ->%%  世界BOSS	打败任意一个火凤、千年老龟、烈焰麒麟兽和穷奇，蛮荒巨龙1次							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				29 ->%%  精英BOSS	打败任意一个灵狐、裂地斧魔、千年猴妖和赤尾狐，千年毒尸1次							
					NTask = Task + Num,
					gwish_task_finish(Player, GWish, NTask);
				_ ->
					ok
			end
	end.

%%氏族祝福任务触发立即完成(跟活跃度的完成情况挂钩)
gwish_task_finish_rightnow(Actions, TId, Player) ->
%% 	?DEBUG("Actions:~p, TId:~p", [Actions, TId]),
	case TId of
		Value when Value =:= 2 orelse Value =:= 30 ->%%吃1个仙桃
			Num = lists:nth(20, Actions),
			case Num >= 1 of
				true ->
					GWParam = {2, 1},
					check_player_gwish(Player, GWParam);
				false ->
					skip
			end;
		Value when Value =:= 3 orelse Value =:= 31 ->%%在商城中购买一件道具
			Num = lists:nth(4, Actions),
			case Num >= 1 of
				true ->
					GWParam = {3, 1},
					check_player_gwish(Player, GWParam);
				false ->
					skip
			end;
		Value when Value =:= 4 ->%%诛邪1次
			Num = lists:nth(3, Actions),
			case Num >= 1 of
				true ->
					GWParam = {4, 1},
					check_player_gwish(Player, GWParam);
				false ->
					skip
			end;
		Value when Value =:= 5 orelse Value =:= 32 orelse Value =:= 33 ->%%完成1次封神帖任务
			Num = lists:nth(13, Actions),
			case Num >= 1 of
				true ->
					GWParam = {5, 1},
					check_player_gwish(Player, GWParam);
				false ->
					skip
			end;
		Value when Value =:= 9 ->%%完成一次仙侣奇缘
			Num = lists:nth(9, Actions),
			case Num >= 1 of
				true ->
					GWParam = {9, 1},
					check_player_gwish(Player, GWParam);
				false ->
					skip
			end;
		Value when Value =:= 13 orelse Value =:= 34 orelse Value =:= 35 ->%%运镖1次
			Num = lists:nth(8, Actions),
			case Num >= 1 of
				true ->
					GWParam = {13, 1},
					check_player_gwish(Player, GWParam);
				false ->
					skip
			end;
		Value when Value =:= 17 ->%%完成30分钟挂机园挂机
			Num = lists:nth(5, Actions),
			case Num >= 1 of
				true ->
					GWParam = {17, 1},
					check_player_gwish(Player, GWParam);
				false ->
					skip
			end;
		Value when Value =:= 18 ->%%完成1次远古试炼
			Num = lists:nth(6, Actions),
			case Num >= 1 of
				true ->
					GWParam = {18, 1},
					check_player_gwish(Player, GWParam);
				false ->
					skip
			end;
		Value when Value =:= 19 ->%%出售10个庄园果实
			Num = lists:nth(7, Actions),
			GWParam = {19, Num},
			check_player_gwish(Player, GWParam);
		Value when Value =:= 20 orelse Value =:= 36 orelse Value =:= 37 ->%%完成1次跑商任务
			Num = lists:nth(10, Actions),
			case Num >= 1 of
				true ->
					GWParam = {20, 1},
					check_player_gwish(Player, GWParam);
				false ->
					skip
			end;
		Value when Value =:= 21 ->%%完成1次荣誉任务
			Num = lists:nth(14, Actions),
			case Num >= 1 of
				true ->
					GWParam = {21, 1},
					check_player_gwish(Player, GWParam);
				false ->
					skip
			end;
		Value when Value=:= 22 ->%%完成一次修为任务
			Num = lists:nth(16, Actions),
			case Num >= 1 of
				true ->
					GWParam = {22, 1},
					check_player_gwish(Player, GWParam);
				false ->
					skip
			end;
		Value when Value =:= 24 orelse Value =:= 38 orelse Value =:= 39 ->%%完成一次最高等级副本任务
			Num = lists:nth(1, Actions),
			case Num >= 1 of
				true ->
					GWParam = {24, 1},
					check_player_gwish(Player, GWParam);
				false ->
					skip
			end;
		Value when Value =:= 26 ->%%完成1次日常守护任务
			Num = lists:nth(17, Actions),
			case Num >= 1 of
				true ->
					GWParam = {26, 1},
					check_player_gwish(Player, GWParam);
				false ->
					skip
			end;
		_ ->
			skip
	end.
		