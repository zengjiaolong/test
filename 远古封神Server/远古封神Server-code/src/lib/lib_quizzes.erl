%% Author: xianrongMai
%% Created: 2012-4-20
%% Description: TODO: 活动大竞猜的接口
-module(lib_quizzes).

%%
%% Include files
%%
-include("activities.hrl").
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").

-define(QUIZZES_LASTING, 3600).	%%竞猜持续时间一个小时
-define(FIRST_BROADCAST, 64800).									%%	18:00:00		竞猜开始时间
-define(SECOND_BROADCAST, ?FIRST_BROADCAST + ?QUIZZES_LASTING + 25).		%%	19:00:25	
-define(THIRD_BROADCAST, ?FIRST_BROADCAST + ?QUIZZES_LASTING + 60).		%%	19:01:00

-define(QUIZZES_START_TIME, ?FIRST_BROADCAST).						%%竞猜开始时间 18:00:00
-define(QUIZZES_END_TIME, ?QUIZZES_START_TIME + ?QUIZZES_LASTING).					%% 19:00:00	竞猜结束时间

%%	测试
%% -define(QUIZZES_LASTING, 600).	%%竞猜持续时间
%% -define(FIRST_BROADCAST, 20*3600+40*60).	%%活动开始时间	
%% -define(SECOND_BROADCAST, ?FIRST_BROADCAST + ?QUIZZES_LASTING + 25).		
%% -define(THIRD_BROADCAST, ?FIRST_BROADCAST + ?QUIZZES_LASTING + 60).		
%%%%%%%%%%%%%%%%%%%

%%
%% Exported Functions
%%
-export([
		 check_player_quizzes_receive/3,	%% 判断是否需要通知客户端领取竞猜奖励
		 check_player_quizzes/2,
		 gm_clear_player_quizzes/1,			%% GM命令
		 handle_30031/1,					%% 30031 竞猜面板请求
		 get_myself_quizzes/5,				%% 获取玩家竞猜面板上的数据(for mod_quizzes)
		 handle_30032/1,					%% 30032 开始竞猜
		 make_myself_quizzes/3,				%% 玩家竞猜数据(for mod_quizzes)
		 handle_30034/1,					%% 30034 领取奖励
		 get_quizzes_award/4,				%% 玩家获取竞猜的奖励(for mod_quizzes)
		 boradcast_lucky/1,					%% 循环广播幸运之星
		 check_quizzes/3,					%% 检查整个大竞猜活动流程的处理
		 load_quizzes_data/0				%% 初始化大竞猜的数据
		]).

%%
%% API Functions
%%
%% 初始化大竞猜的数据
load_quizzes_data() ->
	Fields = "pid, num, got, data",
	case db_agent:select_type_mid_award(77, Fields) of%%大竞猜的活动类型定义为77
		[] ->
			skip;
		List ->
			Quizzes = 
				lists:map(fun([Pid, Num, State, PName]) ->
								  ANum = Num rem 1000 div 100,
								  BNum  = Num rem 100 div 10,
								  CNum = Num rem 10,
								  #quizzes{pid = Pid,
										   pname = PName,
										   a = ANum,
										   b = BNum,
										   c = CNum,
										   state = State}
						  end, List),
			ets_update_quizzes(Quizzes)
	end,
	%%初始化本期的奖金奖池
	{PrizeNum, ThreePrize} = 
		case db_agent:get_mid_prize(0,99)of
			[] ->
				db_agent:insert_mid_prize([pid,type,num,got],[0,99,?PRIZE_NUM,0]),
				{?PRIZE_NUM, 0};
			[_PId,_PPid,_PType,PNum,PGot] ->
				{PNum, PGot}
		end,
	%%初始化本期的幸运号码
	LuckyNum = 
		case db_agent:get_mid_prize(0,100)of
			[] ->
				db_agent:insert_mid_prize([pid,type,num,got],[0,100,0,0]),
				0;
			[_LId,_LPid,_LType,LNum,_LGot] ->
				LNum
		end,
	{LuckyNum, PrizeNum, ThreePrize}.
			
%% 检查整个大竞猜活动流程的处理
check_quizzes(LuckyNum, PrizeNum, ThreePrize) ->
	%%当期那时间
	NowTime = util:unixtime(),
	%%当前时间(0时开始)
	NowSec = util:get_today_current_second(),
	%%活动时间
	{LStart, LEnd} = lib_activities:late_may_day_time(),
	% 判断是否是在活动指定的时间段里
	case NowTime > LStart andalso NowTime < LEnd of
		true ->
			%%判断需要做的操作
			if
				NowSec > ?FIRST_BROADCAST-10 andalso NowSec =< ?FIRST_BROADCAST ->%%清空数据
					NLuckyNum = fulsh_quizzes(),
					NPrizeNum = PrizeNum,
					NThreePrize = ThreePrize;
				NowSec > ?FIRST_BROADCAST andalso NowSec =< ?FIRST_BROADCAST+10 ->%%开始大竞猜的第一次播报
					Message = "<font color='#8800FF'>大竞猜</font><font color='#FEDB4F'>开始啦！亲，想成为今晚万人瞩目的幸运之星吗？！快来爽一爽，使出浑身解数，抖一抖您的运气吧！猜中会有好大好大的惊喜的噢^_-</font>",
					lib_chat:broadcast_sys_msg(2, Message),
					NLuckyNum = LuckyNum,
					NPrizeNum = PrizeNum,
					NThreePrize = ThreePrize;
				NowSec > ?SECOND_BROADCAST andalso NowSec =< ?SECOND_BROADCAST+10 ->%%系统摇号的开始播报
					Message = "<font color='#FEDB4F'>噔.噔..噔...噔！好消息，开奖啦，开奖咧！今天的幸运之星会花落谁家呢？快来看看啰喂...</font>",
					lib_chat:broadcast_sys_msg(2, Message),
					NLuckyNum = LuckyNum,
					NPrizeNum = PrizeNum,
					NThreePrize = ThreePrize;
				NowSec > ?THIRD_BROADCAST andalso NowSec =< ?THIRD_BROADCAST+10 ->%%播报三次获奖，并且得到获奖名单
					%% 系统摇号，并且得到奖励名单
					{NLuckyNum, LuckyOnes, TwoLucky, OneLucky} = make_lucky(),
					%%全服播报系统摇号数值
					boradcast_sys_luckynum(NLuckyNum),
					Message1 = io_lib:format("<font color='#FEDB4F'>万众瞩目的时刻到啦！擦亮您们的眼睛瞄一瞄，惊喜不断！本期的幸运号码为：</font></font><font color='#8800FF'>~p</font>", [NLuckyNum]),
					lists:foreach(fun(Elem) ->spawn(fun()->timer:apply_after(Elem, lib_chat, broadcast_sys_msg,[2, Message1]) end) end, [2000,4000,6000]),
					case LuckyOnes of
						[] ->
							NThreePrize = 0,
							Message2 = ["<font color='#FEDB4F'>很遗憾，本期大竞猜无人当选幸运之星，奖池奖金增加500000绑定铜，下期再见..T_T</font>"],
							NPrizeNum = PrizeNum+?PRIZE_NUM,
							db_agent:update_mid_prize([{num, NPrizeNum}, {got, NThreePrize}], [{type, 99}]);
						_ ->
							Ones = length(LuckyOnes),
							NThreePrize = trunc(100000+PrizeNum/Ones),
							Message2 = make_lucky_broadcast(NThreePrize, LuckyOnes, []),
							NPrizeNum = ?PRIZE_NUM,
							db_agent:update_mid_prize([{num, NPrizeNum}, {got, NThreePrize}], [{pid, 0}, {type, 99}])
					end,
					spawn(fun()->timer:apply_after(7000, lib_quizzes, boradcast_lucky, [Message2]) end),
					%%发放奖励
					{ThreeQuizzes, ThreePids} = make_quizzes_data(3, LuckyOnes, {[], []}),
					{TwoQuizzes, TwoPids} = make_quizzes_data(2, TwoLucky, {[], []}),
					{OneQuizzes, OnePids} = make_quizzes_data(1, OneLucky, {[], []}),
					%%更新ets和数据库
					ets_update_quizzes(ThreeQuizzes),
					ets_update_quizzes(TwoQuizzes),
					ets_update_quizzes(OneQuizzes),
					db_agent:update_mid_prize([{got, 3}], [{type, 77}, {pid, "in", ThreePids}]),
					db_agent:update_mid_prize([{got, 2}], [{type, 77}, {pid, "in", TwoPids}]),
					db_agent:update_mid_prize([{got, 1}], [{type, 77}, {pid, "in", OnePids}]);	
				true ->
					NLuckyNum = LuckyNum,
					NPrizeNum = PrizeNum,
					NThreePrize = ThreePrize
			end,
			{1, NLuckyNum, NPrizeNum, NThreePrize};
		false ->
			case NowTime =< LStart of
				true ->%%如果是在活动之前，则需要继续轮询
					{1, LuckyNum, PrizeNum, ThreePrize};
				false ->
					{0, LuckyNum, PrizeNum, ThreePrize}
			end
	end.
		
%% 循环广播幸运之星
boradcast_lucky([]) ->
	skip;
boradcast_lucky([Message|Rest]) ->
	lib_chat:broadcast_sys_msg(2, Message),
	boradcast_lucky(Rest).
	
make_lucky_broadcast(_ThreePrize, [], Messages) ->
	 Messages;
make_lucky_broadcast(ThreePrize, [Lucky|Rest], Messages) ->
	 #quizzes{pname = PName} = Lucky,
	 Message1 = io_lib:format("<font color='#FEDB4F'>夜黑风高，[</font><font color='#8800FF'>~s</font><font color='#FEDB4F'>]趁着财神爷打盹之际，偷走了幸运之星，获得了</font><font color='#8800FF'>~p</font><font color='#FEDB4F'>绑定铜币奖励！恭喜恭喜！！！</font>", 
							  [PName, ThreePrize]),
	 make_lucky_broadcast(ThreePrize, Rest, [Message1|Messages]).

	
%% -----------------------------------------------------------------
%% 30031 竞猜面板请求
%% -----------------------------------------------------------------
handle_30031(Player) ->
	#player{id = Pid,
			lv = Lv,
			other = Other} = Player,
	#player_other{pid_send = PidSend} =Other,
	Now = util:unixtime(),
	%%活动	时间
	{LStart, LEnd} = lib_activities:late_may_day_time(),		
	%% 判断是否是在活动指定的时间段里
	case Now > LStart andalso Now < LEnd of
		true ->
			case Lv >= 30 of
				true ->
					gen_server:cast(mod_quizzes:get_quizzes_pid(), {'GET_SELF_QUIZZES', Pid, PidSend});
				false ->%%等级不足30级
					{ok, BinData30031} = pt_30:write(30031, [3, 0, 0, 0, 0, 0, []]),
					lib_send:send_to_sid(PidSend, BinData30031)
			end;
		false ->%%活动时间以外了
			{ok, BinData30031} = pt_30:write(30031, [2, 0, 0, 0, 0, 0, []]),
			lib_send:send_to_sid(PidSend, BinData30031)
	end.

%% 获取玩家竞猜面板上的数据(for mod_quizzes)
get_myself_quizzes(LuckyNum, PrizeNum, Pid, PidSend, ThreePrize) ->
	case ets_lookup_quizzes(Pid) of
		[] ->
			MyLuckyNum = 0,
			State = 0,
			Prize = 0;
		Quizzes ->
			#quizzes{a = A,
					 b = B,
					 c = C,
					 state = State} = Quizzes,
			MyLuckyNum = A*100+B*10+C,
			Prize = 
				case State of
					1 -> 5000;
					2 -> 50000;
					3 -> ThreePrize;
					4 -> 5000;
					5 -> 50000;
					6 -> ThreePrize;
					_ -> 0
				end
	
	end,
	LuckyOnes = ets_select_quizzes_bysatate(3),
	{ok, BinData30031} = pt_30:write(30031, [1, PrizeNum, LuckyNum, MyLuckyNum, State, Prize, LuckyOnes]),
	lib_send:send_to_sid(PidSend, BinData30031).

%% -----------------------------------------------------------------
%% 30032 开始竞猜
%% -----------------------------------------------------------------
handle_30032(Player) ->
	#player{id = Pid,
			nickname = PName,
			lv = Lv,
			other = Other} = Player,
	#player_other{pid_send = PidSend} =Other,
	Now = util:unixtime(),
	%%活动	时间
	{LStart, LEnd} = lib_activities:late_may_day_time(),		
	%% 判断是否是在活动指定的时间段里
	case Now > LStart andalso Now < LEnd of
		true ->
			case Lv >= 30 of
				true ->
					NowSec = util:get_today_current_second(),
					case NowSec > ?QUIZZES_START_TIME andalso NowSec < ?QUIZZES_END_TIME of
						true ->%%是在活动规定竞猜的时间里
							gen_server:cast(mod_quizzes:get_quizzes_pid(), {'MAKE_SELF_QUIZZES', Pid, PName, PidSend});
						false ->
							{ok, BinData30032} = pt_30:write(30032, [4, 0]),
							lib_send:send_to_sid(PidSend, BinData30032)
					end;
				false ->%%等级不足30级
					{ok, BinData30032} = pt_30:write(30032, [3, 0]),
					lib_send:send_to_sid(PidSend, BinData30032)
			end;
		false ->%%活动时间以外了
			{ok, BinData30032} = pt_30:write(30032, [2, 0]),
			lib_send:send_to_sid(PidSend, BinData30032)
	end.

%% 玩家竞猜数据(for mod_quizzes)
make_myself_quizzes(Pid, PName, PidSend) ->
	{Result, MyLucky} = 
		case ets_lookup_quizzes(Pid) of
			[] ->%%没有，可以开始竞猜
				Num = get_quizzes_num(Pid, PName),
				{1, Num};
			MyQuizzes ->%%已经竞猜过了
				#quizzes{a = A,
						 b = B,
						 c = C} = MyQuizzes,
				Num = A*100+B*10+C,
				{5, Num}
		end,
	{ok, BinData30032} = pt_30:write(30032, [Result, MyLucky]),
	lib_send:send_to_sid(PidSend, BinData30032).

%% -----------------------------------------------------------------
%% 30034 领取奖励
%% -----------------------------------------------------------------
handle_30034(Player) ->
	#player{id = Pid,
			lv = Lv,
			other = Other} = Player,
	#player_other{pid_send = PidSend,
				  pid = PPid} =Other,
	Now = util:unixtime(),
	%%活动	时间
	{LStart, LEnd} = lib_activities:late_may_day_time(),		
	%% 判断是否是在活动指定的时间段里
	case Now > LStart andalso Now < LEnd of
		true ->
			case Lv >= 30 of
				true ->
					NowSec = util:get_today_current_second(),
					case NowSec > ?QUIZZES_START_TIME andalso NowSec < ?QUIZZES_END_TIME of
						false ->
							gen_server:cast(mod_quizzes:get_quizzes_pid(), {'GET_QUIZZES_AWARD', Pid, PPid, PidSend});
						true ->%%在活动竞猜的时候，是没有奖励的喔
							{ok, BinData30034} = pt_30:write(30034, [5]),
							lib_send:send_to_sid(PidSend, BinData30034)
					end;
				false ->%%等级不足30级
					{ok, BinData30034} = pt_30:write(30034, [6]),
					lib_send:send_to_sid(PidSend, BinData30034)
			end;
		false ->%%活动时间以外了
			{ok, BinData30034} = pt_30:write(30034, [7]),
			lib_send:send_to_sid(PidSend, BinData30034)
	end.
	
%% 玩家获取竞猜的奖励(for mod_quizzes)
get_quizzes_award(Pid, PPid, PidSend, ThreePirze) ->
	case ets_lookup_quizzes(Pid) of
		[] ->
			{ok, BinData30034} = pt_30:write(30034, [2]),
			lib_send:send_to_sid(PidSend, BinData30034);
		Quizzes ->
			#quizzes{state = State} = Quizzes,
			case State of
				1 ->%%中奖一个的
					Prize = 5000,%%自猜中一个数奖励5000绑定铜
					%%发送奖励
					send_player_award(Quizzes, State, Pid, PPid, Prize),
					ok;
				2 ->%%中奖而个的
					Prize = 50000,%%自猜中一个数奖励50000绑定铜
					%%发送奖励
					send_player_award(Quizzes, State, Pid, PPid, Prize),
					ok;
				3 ->%%中奖三个的
					Prize = ThreePirze,%%自猜中一个数奖励ThreePirze绑定铜
					%%发送奖励
					send_player_award(Quizzes, State, Pid, PPid, Prize),
					ok;
				0 ->%%一个也没猜中
					{ok, BinData30034} = pt_30:write(30034, [8]),
					lib_send:send_to_sid(PidSend, BinData30034);
				_ ->
					{ok, BinData30034} = pt_30:write(30034, [4]),
					lib_send:send_to_sid(PidSend, BinData30034)
			end
	end.
send_player_award(Quizzes, State, Pid, PPid, Prize) ->
	%%更新ets和数据库
	NState = State+3,
	NQuizzes = Quizzes#quizzes{state = NState},
	ets_update_quizzes(NQuizzes),
	WhereList = [{pid, Pid}, {type, 77}],
	ValueList = [{got, NState}],
	db_agent:update_mid_prize(ValueList, WhereList),
	%%发奖励
	gen_server:cast(PPid, {'SEND_QUIZZES_AWARD', Prize}).

%% GM命令
gm_clear_player_quizzes(PlayerId) ->
	ets_delete_quizzes_bypid(PlayerId),
	WhereList = [{pid, PlayerId}, {type, 77}],
	db_agent:delete_mid_prize(WhereList).

%% 判断是否需要通知客户端领取竞猜奖励
check_player_quizzes_receive(PlayerId, PidSend, Now) ->
	case lib_activities:is_late_may_day_time(Now) of
		true ->
			gen_server:cast(mod_quizzes:get_quizzes_pid(), {'CHECK_PLZYER_QUIZZES_RECEIVE', PlayerId, PidSend});
		false ->
			skip
	end.
%% 判断是否需要通知客户端领取竞猜奖励(for mod_quizzes)
check_player_quizzes(PlayerId, PidSend) ->
	case ets_lookup_quizzes(PlayerId) of
		[] ->
			skip;
		Quizzes ->
			#quizzes{state = State} = Quizzes,
			if 
				State =:= 1 orelse State =:= 2 orelse State =:= 3 ->
					{ok, BinData30035} = pt_30:write(30035, []),
					lib_send:send_to_sid(PidSend, BinData30035);
				true ->
					skip
			end
	end.

%%
%% Local Functions
%%
%% quizzes ets operate interfaces
%% insert
ets_update_quizzes(Quizzes) ->
	ets:insert(?ETS_QUIZZES, Quizzes).
ets_delete_quizzes_bypid(Pid) ->
	ets:delete(?ETS_QUIZZES, Pid).
ets_delete_quizzes_all() ->
	ets:delete_all_objects(?ETS_QUIZZES).
ets_select_quizzes_bysatate(State) ->
	Pattern = #quizzes{state = State, _ = '_'},
	ets:match_object(?ETS_QUIZZES, Pattern).
ets_lookup_quizzes(Pid) ->
	case ets:lookup(?ETS_QUIZZES, Pid) of
		[] ->
			[];
		[Quizzes|_] ->
			Quizzes
	end.
ets_select_quizzes_byms(MS) ->
	ets:select(?ETS_QUIZZES, MS).

%%产生大竞猜数据
get_quizzes_num(PId, PName) ->
	A = make_random_num(),
	B = make_random_num(),
	C = make_random_num(),
	State = 0,
	Quizzes = #quizzes{pid = PId,
					   pname = PName,
					   a = A,
					   b = B,
					   c = C,
					   state = State},
	Num = A*100 + B*10 + C,
	ets_update_quizzes(Quizzes),
	db_agent:insert_mid_prize([pid,type,num,got,data],[PId,77,Num,State,PName]),
	Num.
	
	
%%做出竞猜的随机数
make_random_num() ->
	Rand = util:rand(0, 99),
	if
		Rand >= 0 andalso Rand =< 9 ->
			1;
		Rand >= 10 andalso Rand =< 29 ->
			2;
		Rand >= 20 andalso Rand =< 29 ->
			3;
		Rand >= 30 andalso Rand =< 39 ->
			4;
		Rand >= 40 andalso Rand =< 49 ->
			5;
		Rand >= 50 andalso Rand =< 59 ->
			6;
		Rand >= 60 andalso Rand =< 69 ->
			7;
		Rand >= 80 andalso Rand =< 89 ->
			9;
		true ->
			9
	end.

%% 系统摇号，并且得到奖励名单
make_lucky() ->
	%%系统摇号
	A = make_random_num(),
	B = make_random_num(),
	C = make_random_num(),
	LuckyNum = A*100 + B*10 + C,
	%%更新数据库的数值
	db_agent:update_mid_prize([{num, LuckyNum}], [{pid, 0}, {type, 100}]),
	%%幸运之星
	LuckyMS = ets:fun2ms(fun(Three) when Three#quizzes.a =:= A andalso Three#quizzes.b =:= B andalso Three#quizzes.c =:= C ->
								 Three
						 end),
	LuckyOnes = ets_select_quizzes_byms(LuckyMS),
	%%两个号中的
	TwoMS = ets:fun2ms(fun(Two) when (Two#quizzes.a =:= A andalso Two#quizzes.b =:= B andalso Two#quizzes.c =/= C) 
							  orelse (Two#quizzes.a =:= A andalso Two#quizzes.b =/= B andalso Two#quizzes.c =:= C) 
							  orelse Two#quizzes.a =/= A andalso Two#quizzes.b =:= B andalso Two#quizzes.c =:= C->
								 Two
						 end),
	TwoLucky = ets_select_quizzes_byms(TwoMS),
	%%仅中一个的
	OneMS = ets:fun2ms(fun(One) when (One#quizzes.a =:= A andalso One#quizzes.b =/= B andalso One#quizzes.c =/= C) 
							  orelse (One#quizzes.a =/= A andalso One#quizzes.b =:= B andalso One#quizzes.c =/= C) 
							  orelse One#quizzes.a =/= A andalso One#quizzes.b =/= B andalso One#quizzes.c =:= C->
								 One
						 end),
	OneLucky = ets_select_quizzes_byms(OneMS),
	{LuckyNum, LuckyOnes, TwoLucky, OneLucky}.


make_quizzes_data(_Type, [], Result) ->
	Result;
make_quizzes_data(Type, [Quizzes|Rest], {NQuizzes, Pids}) ->
	#quizzes{pid = Pid} = Quizzes,
	make_quizzes_data(Type, Rest, {[Quizzes#quizzes{state = Type}|NQuizzes], [Pid|Pids]}).
	
%% 清空老数据
fulsh_quizzes() ->
	%%清空ets数据
	ets_delete_quizzes_all(),
	WhereList = [{type, 77}],
	db_agent:delete_mid_prize(WhereList),
	%%更新数据库的数值
	LuckyNum = 0,
	db_agent:update_mid_prize([{num, LuckyNum}], [{pid, 0}, {type, 100}]),
%% 	?DEBUG("fulsh_quizzes, LuckyNum:~p", [LuckyNum]),
	LuckyNum.

%% 全服播报系统摇号结果
boradcast_sys_luckynum(SysLuckyNum) ->
	{ok, BinData30033} = pt_30:write(30033, [SysLuckyNum]),
	lib_send:send_to_all(BinData30033).
