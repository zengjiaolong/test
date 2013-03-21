%% Author: xianrongMai
%% Created: 2011-9-26
%% Description: 氏族祝福处理pp_handle调用的接口
-module(lib_gwish_interface).

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
		 sex_change_succeed/1,	%%玩家变性成功
		 check_player_gwish/2,	%% 玩家氏族祝福任务完成情况检查
		 flush_gwish_time/1,	%% 40078  刷新时间
		 get_gwish_award/1,		%% 40077  领取奖励
		 invite_other_flush/2,	%% 40075  邀请别人帮忙刷任务运势
		 help_other_flush/2,	%% 40073  帮他人刷新运势
		 get_guild_gwish/2,		%% 40072  氏族祝福成员运势
		 giveup_gwish_task/1,	%% 40070  放弃当前任务
		 accept_gwish_task/1,	%% 40069  接受当前任务
		 f5_gwish_task/1,		%% 40068  刷新氏族祝福任务
		 get_gwish_task/1,		%% 40067  获取氏族祝福任务
		 get_p_gwish/1			%% 40066  氏族祝福个人信息
		]).

%%
%% API Functions
%%
% 玩家氏族祝福任务完成情况检查
check_player_gwish(PPid, GWParam) ->
	gen_server:cast(PPid, {'CHEKC_PLAYER_GWISH', GWParam}).

%% -----------------------------------------------------------------
%% 40066  氏族祝福个人信息
%% -----------------------------------------------------------------
get_p_gwish(Status) ->
	case Status#player.guild_id of
		0 ->%%没氏族了
			{0, 0, 0, 0, 0, []};
		_ ->
			NowTime = util:unixtime(),
			%%获取氏族祝福任务的详细数据
			GWish = lib_guild_wish:get_gwish_dict(),
			#player{id = PId,
					nickname = PName,
					sex = Sex,
					career = Career,
					guild_id = PGId} = Status,
			#p_gwish{t_color = TColor,
					 tid = TId,
					 tstate = TState,
					 task = Task,
					 flush = Flush} = GWish,
			Luck = 
				case util:is_same_date(NowTime, GWish#p_gwish.time) of
					true ->
						GWish#p_gwish.luck;
					false ->
						%%重新获取玩家运势星级
						NLuck = lib_guild_wish:make_probability(?PLAYER_WISH_PRODIST),
						NTime = NowTime,
						NHelp = 0,
						NBHelp = 0,
						NFinish = [],
						NFinishStr = util:term_to_string(NFinish),
						ValueList = [{luck, NLuck}, {help, NHelp}, {bhelp, NBHelp},{time, NTime}, {finish, NFinishStr}],
						WhereList = [{pid, PId}],
						%%更新数据库
						lib_guild_wish:db_update_gwish(ValueList, WhereList),
						Dict = [NLuck, TColor, TId, TState, Task, NHelp, NBHelp, Flush, NTime, NFinish],
						DictEts =  lib_guild_wish:make_gwish_dic(Dict),
						%%放进程字典
						lib_guild_wish:put_gwish_dict(DictEts),
						MemNotices = [PId, PGId, PName, Sex, Career, NLuck, TId, TColor, TState, NHelp, NBHelp],
						%%通知氏族玩家数据更新啦
						lib_guild_wish:notice_mem_gwish(MemNotices),
						NLuck
				end,
			Diff = NowTime - Flush,
%% 			?DEBUG("NowTime:~p, Flush:~p", [NowTime, Flush]),
			ReTime = 
				case Flush =/= 0 andalso Diff > ?WISH_TASK_FLUSH_TIME of
					true ->
						0;
					false when Flush =:= 0 ->
						0;
					false when Diff < 0 ->
						0;
					false ->
						abs(?WISH_TASK_FLUSH_TIME - Diff)
				end,
			Logs = lib_guild_wish:ets_get_f5gwish(PId),
			{TId, Luck, TColor, TState, ReTime, Logs}
	end.

%% -----------------------------------------------------------------
%% 40067  获取氏族祝福任务
%% -----------------------------------------------------------------
get_gwish_task(Status) ->
	#player{id = PId,
			lv = PLv,
			sex = Sex,
			career = Career,
			guild_id = PGId,
			nickname = PName} = Status,
	%%获取氏族祝福任务的详细数据
	GWish = lib_guild_wish:get_gwish_dict(),
	#p_gwish{luck = Luck,
			 tstate = TState,
			 help = Help,
			 bhelp = BHelp,
			 flush = Flush,
			 finish = Finish} = GWish,
	case TState of
		Value when Value =:= 1 orelse Value =:= 2 ->
			{2, 0};%%已经获取任务了，只能刷新任务
		Value when Value =:= 0 ->
			NowTime = util:unixtime(),
			Diff = NowTime - Flush,
			case Diff < ?WISH_TASK_FLUSH_TIME andalso Flush =/= 0 of
				true ->%%还未到时间呢
					{5, 0};
				false ->
					NTCLuck = lists:nth(Luck, ?TASK_COLOR_LUCK),
					NTColor = lib_guild_wish:make_probability(NTCLuck),
					%%随机玩家的任务Id
					NTId = lib_guild_wish:random_task_id(PLv, Finish),
					NTState = 1,
					NTask = 0,
%% 					?DEBUG("flush the task: ~p", [NowTime]),
					NGWish = GWish#p_gwish{t_color = NTColor,
										   tid = NTId,
										   tstate = NTState,
										   task = NTask,
										   flush = NowTime},
					ValueList = [{t_color, NTColor}, {tid, NTId}, {tstate, NTState}, {task, NTask}, {flush, NowTime}],
					WhereList = [{pid, PId}],
					%%更新dict
					lib_guild_wish:put_gwish_dict(NGWish),
					%%更新数据库
					lib_guild_wish:db_update_gwish(ValueList, WhereList),
					MemNotices = [PId, PGId, PName, Sex, Career, Luck, NTId, NTColor, NTState, Help, BHelp],
					%%通知氏族玩家数据更新啦
					lib_guild_wish:notice_mem_gwish(MemNotices),
					{1, NTId}
			end;
		_ ->%%OMG，居然出问题了
			{0, 0}
	end.
	
%% -----------------------------------------------------------------
%% 40068  刷新氏族祝福任务
%% -----------------------------------------------------------------
f5_gwish_task(Status) ->
	#player{id = PId,
			sex = Sex,
			career = Career,
			lv = PLv,
			guild_id = PGId,
			nickname = PName} = Status,
	%%获取氏族祝福任务的详细数据
	GWish = lib_guild_wish:get_gwish_dict(),
	#p_gwish{luck = Luck,
			 t_color = TColor,
			 tstate = TState,
			 help = Help,
			 bhelp = BHelp,
			 flush = Flush,
			 finish = Finish} = GWish,
	case TState of
		0 ->%%任务都还未获取呢，怎么刷新
			{3, 0, 0};
		2 ->%%任务已经接受了，不能再刷新了
			{4, 0, 0};
		1 ->%%获取了任务没接受呢，噫，正确啰喔^_^
			NowTime = util:unixtime(),
			Diff = NowTime - Flush,
			case Diff < ?WISH_TASK_FLUSH_TIME andalso Flush =/= 0 of
				true ->%%还未到时间呢
					{2, 0, 0};
				false ->%%可以刷了
					%%随机玩家的任务Id
					NTId = lib_guild_wish:random_task_id(PLv, Finish),
					NTask = 0,
					NGWish = GWish#p_gwish{tid = NTId,
										   task = NTask,
										   flush = NowTime},
					ValueList = [{tid, NTId},{task, NTask},{flush, NowTime}],
					WhereList = [{pid, PId}],
					%%更新dict
					lib_guild_wish:put_gwish_dict(NGWish),
					%%更新数据库
					lib_guild_wish:db_update_gwish(ValueList, WhereList),
					MemNotices = [PId, PGId, PName, Sex, Career, Luck, NTId, TColor, TState, Help, BHelp],
					%%通知氏族玩家数据更新啦
					lib_guild_wish:notice_mem_gwish(MemNotices),
					{1, NTId, TColor}
			end;
		_ ->%%哇塞，什么错啊？
			{0, 0, 0}
	end.
	
%% -----------------------------------------------------------------
%% 40069  接受当前任务
%% -----------------------------------------------------------------
accept_gwish_task(Status) ->
	#player{id = PId,
			sex = Sex,
			career = Career,
			guild_id = PGId,
			nickname = PName,
			other = Other} = Status,
	#player_other{pid = PPid} = Other,
	%%获取氏族祝福任务的详细数据
	GWish = lib_guild_wish:get_gwish_dict(),
	#p_gwish{luck = Luck,
			 tid = TId,
			 t_color = TColor,
			 tstate = TState,
			 help = Help,
			 bhelp = BHelp} = GWish,
	case TState of
		0 ->%%还未获取任务呢
			3;
		2 ->%%已经有任务了
			2;
		1 ->%%ok！
			NTState = 2,
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
			lib_guild_wish:notice_mem_gwish(MemNotices),
			%%做一些特殊的判断，比如一些任务已经完成的，则立即给予完成(跟活跃度的完成情况挂钩)
			case lists:member(TId, ?GWISH_TASK_FINISH_RIGHTNOW) of
				true ->
					erlang:send_after(5000, PPid, {'GWISH_TASK_FINISH_RIGHTNOW', TId});
				false ->
					skip
			end,
			1;
		_ ->%%OMG,fuck
			0
	end.
		
%% -----------------------------------------------------------------
%% 40070  放弃当前任务
%% -----------------------------------------------------------------
giveup_gwish_task(Status) ->
	#player{id = PId,
			sex = Sex,
			career = Career,
			guild_id = PGId,
			nickname = PName} = Status,
	%%获取氏族祝福任务的详细数据
	GWish = lib_guild_wish:get_gwish_dict(),
	#p_gwish{luck = Luck,
			 tstate = TState,
			 help = Help,
			 bhelp = BHelp} = GWish,
	case TState of
		0 ->%%压根任务都没获取，何来取消
			2;
		1 ->%任务获取了，但是没有接，所以不能放弃
			3;
		2 ->%%放弃吧
			NTId = 0,
			NTState = 0,
			NTColor = 0,
			NTask = 0,
			NGWish = GWish#p_gwish{tid = NTId,
								   tstate = NTState,
								   t_color = NTColor,
								   task = NTask},
			ValueList = [{tid, NTId}, {tstate, NTState}, {t_color, NTColor}, {task, NTask}],
			WhereList = [{pid, PId}],
			%%更新dict
			lib_guild_wish:put_gwish_dict(NGWish),
			%%更新数据库
			lib_guild_wish:db_update_gwish(ValueList, WhereList),
			MemNotices = [PId, PGId, PName, Sex, Career, Luck, NTId, NTColor, NTState, Help, BHelp],
			%%通知氏族玩家数据更新啦
			lib_guild_wish:notice_mem_gwish(MemNotices),
			1;
		3 ->%%已经完成啦
			5;
		_ ->
			0
	end.
	
%% -----------------------------------------------------------------
%% 40072  氏族祝福成员运势
%% -----------------------------------------------------------------
get_guild_gwish(ReHelp, Status) ->
	case Status#player.guild_id of
		0 ->
			[];
		_ ->
			gen_server:cast(mod_guild:get_mod_guild_pid(), 
									   {apply_cast, lib_guild_wish, get_guild_gwish, 
										[ReHelp, Status#player.guild_id, Status#player.other#player_other.pid_send]})
	end.
	
%% -----------------------------------------------------------------
%% 40073  帮他人刷新运势
%% -----------------------------------------------------------------
help_other_flush(Status, DPId) ->
	if Status#player.guild_id =:= 0 ->%%居然没氏族了，真奇怪
		   {3, 0, ""};
	   Status#player.id =:= DPId ->
		    {8, 0, ""};
	   true ->
		   %%获取氏族祝福任务的详细数据
			GWish = lib_guild_wish:get_gwish_dict(),
			case catch(gen_server:call(mod_guild:get_mod_guild_pid(), 
									   {apply_call, lib_guild_wish, help_other_flush, 
										[Status#player.id,
										 Status#player.nickname,
										 GWish, 
										 DPId]}))of
				{1, NTLuck, DPName, NGWish} ->
					%%改自己的数据
					#p_gwish{luck = Luck,
							 tid = TId,
							 t_color = TColor,
							 tstate = TState,
							 help = Help,
							 bhelp = BHelp} = NGWish,
					#player{id = PId,
							nickname = PName,
							sex = Sex,
							career = Career,
							guild_id = PGId} = Status,
					ValueList = [{help, Help}],
					WhereList = [{pid, PId}],
					%%更新dict
					lib_guild_wish:put_gwish_dict(NGWish),
					%%更新数据库
					lib_guild_wish:db_update_gwish(ValueList, WhereList),
					MemNotices = [PId, PGId, PName, Sex, Career, Luck, TId, TColor, TState, Help, BHelp],
					%%通知氏族玩家数据更新啦
					lib_guild_wish:notice_mem_gwish(MemNotices),
					{1, NTLuck, DPName};
				{Other, ONTLuck, ODPName, _NewGWish} ->
					{Other, ONTLuck, ODPName};
				_Other ->
					{0, 0, ""}
			end
	end.

%% -----------------------------------------------------------------
%% 40075  邀请别人帮忙刷任务运势
%% -----------------------------------------------------------------
invite_other_flush(Status, DPId) ->
	if
		Status#player.guild_id =:= 0 ->%%没氏族，刷什么呢
			2;
		Status#player.id =:= DPId ->%%居然是自己
			8;
		true ->%%获取氏族祝福任务的详细数据
			GWish = lib_guild_wish:get_gwish_dict(),
			case GWish#p_gwish.tstate =/= 0 of
				true ->
					case catch(gen_server:call(mod_guild:get_mod_guild_pid(), 
											   {apply_call, lib_guild_wish, invite_other_flush, 
												[Status#player.id,
												 Status#player.nickname,
												 Status#player.guild_id, 
												 DPId]}))of
						ok ->
							1;
						{fail, Type} ->
							Type;
						_Other ->
							0
					end;
				false ->
					9
			end
	end.
	
%% -----------------------------------------------------------------
%% 40077  领取奖励
%% -----------------------------------------------------------------
get_gwish_award(Status) ->
	#player{id = PId,
			lv = PLv,
			sex = Sex,
			career = Career,
			guild_id = PGId,
			nickname = PName} = Status,
	%%获取氏族祝福任务的详细数据
	GWish = lib_guild_wish:get_gwish_dict(),
	#p_gwish{luck = Luck,
			 tid = TId,
			 tstate = TState,
			 t_color = TColor,
			 help = Help,
			 bhelp = BHelp,
			 finish = Finish} = GWish,
	if
		TState =:= 0 ->%%没获取任务
			{3, 0, Status};
		TState =:= 1 ->%%刚刚获取任务
			{4, 0, Status};
		TState =:= 2 ->%%刚刚接受任务
			{2, 0, Status};
		PGId =:= 0 ->%%没氏族了
			{5, 0, Status};
		TId =:= 0 ->%%没任务了
			{6, 0, Status};
		true ->
			%%获取经验，灵力，铜币，绑定铜，氏族贡献 氏族经验 奖励
			{Exp, Spri, _Coin, _BCoin, Contribute, GuildExp, FBTNum} = data_guild:get_gwish_award(PLv, TColor),
			%%获取奖励的物品Id
			Goods = get_award_goods(TColor),
			GoodsResult = 
				case Goods of
					0 ->%%因为没有刷出奖励，直接返回正确值10
						InResult = 
							%%只给副本令
							case FBTNum of
								0 ->%%等级太小了
									1;
								_ ->
									case catch(gen_server:call(Status#player.other#player_other.pid_goods, {'give_goods', Status,28620, FBTNum, 0})) of
										ok ->%%给了物品，没错
											1;
										cell_num ->
											2;
										_ ->
											0
									end
							end,
						case InResult of
							1 ->
								%%跟经验和灵力
								ExpSpriPlayer = lib_player:add_exp(Status, Exp, Spri, 16),
								%%不再给铜币奖励了
%% 								CoinPlayer = lib_goods:add_money(ExpSpriPlayer, Coin, coin, 4077),
%% 								BCoinPlayer = lib_goods:add_money(CoinPlayer, BCoin, bcoin, 4077),
								BCoinPlayer = ExpSpriPlayer,
								%%奖励氏族贡献值
								mod_guild:increase_guild_exp(PId, PGId, GuildExp, Contribute, 0, 0),
								10;
							_ ->
								BCoinPlayer = Status,
								InResult
						end;
					_Other ->
						{GiveList, NCell} =
							case FBTNum of
								0 ->%%等级太小了
									{[{Goods, 1, 2}],1};
								_ ->
									{[{Goods, 1, 2},{28620, FBTNum, 0}], 2}	%%给运势礼包的同时，给副副本令
%% 									{[{Goods, 1, 2}],1}%%先屏蔽氏族祝福副本令奖励
							end,
						case length(gen_server:call(Status#player.other#player_other.pid_goods,{'null_cell'})) >= NCell of
							true ->
								case give_list_goods(Status, GiveList, ok)of
									ok ->
										%%领取成功更新记录
										%%跟经验和灵力
										ExpSpriPlayer = lib_player:add_exp(Status, Exp, Spri, 16),
										%%不再给铜币奖励了
%% 										CoinPlayer = lib_goods:add_money(ExpSpriPlayer, Coin, coin, 4077),
%% 										BCoinPlayer = lib_goods:add_money(CoinPlayer, BCoin, bcoin, 4077),
										BCoinPlayer = ExpSpriPlayer,
										%%奖励氏族贡献值
										mod_guild:increase_guild_exp(PId, PGId, GuildExp, Contribute, 0, 0),
										1;
									_ ->
										BCoinPlayer = Status,
										0
								end;
							false ->
								BCoinPlayer = Status,
								2
						end
				end,
			case GoodsResult of
				Val when Val =:= 1 orelse Val =:= 10 ->
					%%更新氏族祝福数据
					NTId = 0,
					NTState = 0,
					NTColor = 0,
					NTask = 0,
					NFlush = 0,
					NFinish = [TId|Finish],
					NGWish = GWish#p_gwish{tid = NTId,
										   tstate = NTState,
										   t_color = NTColor,
										   task = NTask,
										   flush = NFlush,
										   finish = NFinish},
					NFinishStr = util:term_to_string(NFinish),
					ValueList = [{tid, NTId}, {tstate, NTState}, {t_color, NTColor}, {task, NTask}, {flush, NFlush}, {finish, NFinishStr}],
					WhereList = [{pid, PId}],
					%%更新dict
					lib_guild_wish:put_gwish_dict(NGWish),
					%%更新数据库
					lib_guild_wish:db_update_gwish(ValueList, WhereList),
					MemNotices = [PId, PGId, PName, Sex, Career, Luck, NTId, NTColor, NTState, Help, BHelp],
					%%通知氏族玩家数据更新啦
					lib_guild_wish:notice_mem_gwish(MemNotices),
					%%通知任务自动完成
%% 					lib_task:event(guild_bless, null, BCoinPlayer),
					lib_task:auto_finish_task(BCoinPlayer,?GUILD_WISH_TASK_ID),
					{Val, Goods, BCoinPlayer};
				2 ->
					{8, 0, BCoinPlayer};
				_ ->
					{0, 0, BCoinPlayer}
			end
	end.
give_list_goods(_Player, [], Type) ->
	Type;
give_list_goods(Player, [{GiveGoodsId, GoodsNum, Bind}|Rest], Type) ->
	case Type of
		ok ->
			case catch (gen_server:call(Player#player.other#player_other.pid_goods, {'give_goods', Player, GiveGoodsId, GoodsNum, Bind})) of
				ok ->
					give_list_goods(Player, Rest, ok);
				_ ->
					give_list_goods(Player, [], fail)
			end;
		_ ->
			give_list_goods(Player, [], fail)
	end.

%% -----------------------------------------------------------------
%% 40078  刷新时间
%% -----------------------------------------------------------------
flush_gwish_time(Status) ->
	%%获取氏族祝福任务的详细数据
	GWish = lib_guild_wish:get_gwish_dict(),
	#p_gwish{flush = Flush} = GWish,
	NowTime = util:unixtime(),
	Diff = NowTime - Flush,
	ReTime = 
		case Flush =/= 0 andalso Diff > ?WISH_TASK_FLUSH_TIME of
			true ->
				0;
			false when Flush =:= 0 ->
				0;
			false when Diff =< 0 ->
				0;
			false ->
				?WISH_TASK_FLUSH_TIME - Diff
		end,
	case ReTime =< 0 of
		true ->
			{Status, 4, 0};
		false ->%%此时算出的GoldNeed一定是大于0
			Count = tool:ceil(ReTime/60),
			CoinNeed = tool:ceil(Count * ?GWISN_COIN_NEED),
			%%即时获取玩家的铜币数
			case goods_util:is_enough_money(Status, CoinNeed, coin) of
				true ->
					NewStatus = lib_goods:cost_money(Status, CoinNeed, coin, 4078),
%% 					?DEBUG("CoinNeed:~p, coin:old:~p, new:~p, coin:old:~p, new:~p", [CoinNeed, Status#player.coin, NewStatus#player.coin, Status#player.bcoin, NewStatus#player.bcoin]),
					case NewStatus#player.coin =:= Status#player.coin andalso NewStatus#player.bcoin =:= Status#player.bcoin of
						true ->%%原来是一样的哦
							{NewStatus, 4, 0};
						false ->
							NFlush = 0,
							NGWish = GWish#p_gwish{flush = NFlush},
							ValueList = [{flush, NFlush}],
							WhereList = [{pid, Status#player.id}],
							%%更新dict
							lib_guild_wish:put_gwish_dict(NGWish),
							%%更新数据库
							lib_guild_wish:db_update_gwish(ValueList, WhereList),
							{NewStatus, 1, CoinNeed}
					end;
				false ->%%铜币不足
					{Status, 2, 0}
			end
	end.
%%玩家变性成功
sex_change_succeed(Status) ->
	case Status#player.lv >= 35 andalso Status#player.guild_id =/= 0 of
		true ->
			%%检查是否已经初始化过了
			lib_guild_wish:check_init_guild_wish(Status#player.id, Status#player.nickname, Status#player.sex, Status#player.career, Status#player.guild_id),
			%%获取氏族祝福任务的详细数据
			GWish = lib_guild_wish:get_gwish_dict(),
			#player{id = PId,
					sex = NSex,
					career = Career,
					guild_id = PGId,
					nickname = PName} = Status,
			#p_gwish{luck = Luck,
					 tid = TId,
					 tstate = TState,
					 t_color = TColor,
					 help = Help,
					 bhelp = BHelp} = GWish,
			MemNotices = [PId, PGId, PName, NSex, Career, Luck, TId, TColor, TState, Help, BHelp],
			%%通知氏族玩家数据更新啦
			lib_guild_wish:notice_mem_gwish(MemNotices);
		false ->
			skip
	end.

%%
%% Local Functions
%%
%%获取奖励的物品Id
%% 任务运势等级		运势礼包获得概率	
%% 白色1星			较低（20%）	
%% 绿色2星			低（30%）	
%% 蓝色3星			中（50%）	
%% 金色4星			高（70%）	
%% 紫色5星			很高（80%）	
get_award_goods(TColor) ->
	Num = 
		case TColor of
			1 ->
				20;
			2 ->
				30;
			3 ->
				50;
			4 ->
				70;
			5 ->
				80;
			_ ->
				20
		end,
	RandNum = util:rand(1, 100),
	if
		RandNum =< Num ->
			?GWISH_GOODS_ID;
		true ->
			0
	end.
		