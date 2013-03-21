%% Author: Administrator
%% Created: 2012-1-4
%% Description: TODO: 经验找回
-module(lib_find_exp).

%%
%% Include files
%%

-include("common.hrl").
-include("record.hrl").
%%
%% Exported Functions
%%
-compile(export_all).

%%
%% API Functions
%%

-define(MAX_EXP_TIMES,3).%%副本高经验次数

%%加载经验找回信息
init_find_exp(PlayerId,Lv,GuildId,RegTime)->
	if Lv > 24->
		find_exp_single(PlayerId,Lv,GuildId,RegTime),
		Data = db_agent:select_find_exp(PlayerId),
		lists:map(fun init/1, Data),
		ok;
	   true->skip
	end,
	ok.

init(Info)->
	FindExp =list_to_tuple([ets_find_exp|Info]),
    update_find_exp(FindExp).

%%查询经验找回信息
check_find_exp(PlayerId)->
	select_by_pid(PlayerId).

%%兑换经验找回信息
%%   1 => 领取成功
%%   2 => 元宝不足
%%   3 => 已经领取过了
%%   4=> 数据异常
%%   5=> 该经验不属于你
%%   6=>没有商牌
convert_find_exp(Status,ConvertType,Id,Color)->
	case select_by_id(Id) of
		[]->
			{Status,3,Color};
		[Info|_]->
			if Info#ets_find_exp.pid =/= Status#player.id->{Status,5,Color};
			   true->
					case ConvertType of
						1->
							Gold = gold(Info#ets_find_exp.type),
							case goods_util:is_enough_money(Status, Gold, gold) of
								false->{Status,2,Color};
								true->
									case check_business_card(Status,Info,Color) of
										true->
											Status1 = lib_goods:cost_money(Status, Gold, gold, 3315),
											NowTime= util:unixtime(),
											Mult = check_mult(NowTime,1),
											convert_exp(Status1,Info,Mult,Color,Gold,NowTime);
										false->{Status,6,Color}
									end
							end;
						_->
							case check_business_card(Status,Info,Color) of
								true->
									NowTime= util:unixtime(),
									Mult = check_mult(NowTime,0.5),
									convert_exp(Status,Info,Mult,Color,0,NowTime);
								false->{Status,6,Color}
							end
					end
			end
	end.

check_business_card(Status,FindExp,Color)->
	if FindExp#ets_find_exp.type=:=5->
		   GoodsId = color_to_goods_id(Color),
		   case gen_server:call(Status#player.other#player_other.pid_goods, {'delete_more', GoodsId, 1}) of
			   1->true;
			   _->false
		   end;
	   true->true
	end.

%%商牌颜色-物品id
color_to_goods_id(Color)->
	case Color of
		4->28406;
		5->28407;
		6->28408;
		_7->28409
	end.

%%获取经验找回倍数
check_mult(NowTime,Mult)->
	%%二月活动
	%%活动七：经验翻倍找回，回归大回馈			
	case lib_activities:is_february_event_time(NowTime) of
		true->1.5*Mult;
		false->Mult
	end. 

%%加经验
convert_exp(Status,Info,Mult,Color,Money,NowTime)->
	{Exp,Spt,TaskType} = 
		%%跑商可选商牌颜色
		case Info#ets_find_exp.type of
			5->
				case Color of
					4->{round(Mult*Info#ets_find_exp.exp),round(Mult*Info#ets_find_exp.spt),business};
					_->
						{Exp1,Spt1} = lib_business:base_award(Color,Info#ets_find_exp.lv),
						{round(Mult*Exp1),round(Mult*Spt1),business}
				end;
			_->
				{round(Mult*Info#ets_find_exp.exp),round(Mult*Info#ets_find_exp.spt),other}
		end,
	NewStatus = lib_player:add_exp(Status, Exp, Spt, 23),
	case TaskType of
		business->
			if Info#ets_find_exp.times =:= 1 ->
				   delete_by_id(Info#ets_find_exp.id),
				   db_agent:delete_find_exp(Info#ets_find_exp.id);
			   true->
				   NewTimes = Info#ets_find_exp.times-1,
				   {NewExp,NewSpt} = lib_business:base_award(4,Info#ets_find_exp.lv),
				   NewInfo = Info#ets_find_exp{times=NewTimes,exp=NewExp*NewTimes,spt=NewSpt*NewTimes},
				   update_find_exp(NewInfo),
				   db_agent:update_find_exp([{times,NewTimes},{exp,NewExp*NewTimes},{spt,NewSpt*NewTimes}],[{id,Info#ets_find_exp.id}])
			end;
		_->
			delete_by_id(Info#ets_find_exp.id),
			db_agent:delete_find_exp(Info#ets_find_exp.id)
	end,
	spawn(fun()->db_agent:log_find_exp(Status#player.id,Info#ets_find_exp.task_id,Info#ets_find_exp.name,Info#ets_find_exp.type,Info#ets_find_exp.timestamp,Info#ets_find_exp.times,Info#ets_find_exp.lv,Info#ets_find_exp.exp,Info#ets_find_exp.spt,NowTime,Money,Color)end),
	{NewStatus,1,Color}.


%%一键找回
convert_exp_all(Status,Type)->
	ExpBag = select_by_pid(Status#player.id),
	NowTime = util:unixtime(),
	Mult = if Type == 1 -> check_mult(NowTime,1); 
			  true-> check_mult(NowTime,0.5)
		   end,
	{Gold,Exp,Spt,Newbag} =   calc_gold_by_one_key(ExpBag,Mult,0,0,0,[]),
	case Newbag of
		[]->{Status,3};
		_->
			case Type of
				1->
					case goods_util:is_enough_money(Status, Gold, gold) of
						false->{Status,2};
						true->
							NewStatus = lib_player:add_exp(Status, Exp, Spt, 23),
							Status1 = lib_goods:cost_money(NewStatus, Gold, gold, 3315), 
							del_find_exp_loop(Newbag,Status1#player.id,Type,NowTime),
							{Status1,1}
					end;
				2->
					NewStatus = lib_player:add_exp(Status, Exp, Spt, 23),
					del_find_exp_loop(Newbag,Status#player.id,Type,NowTime),
					{NewStatus,1}
			end
	end.

del_find_exp_loop([],_PlayerId,_Type,_NowTime)->
	ok;
del_find_exp_loop([Info|ExpBag],PlayerId,Type,NowTime)->
	delete_by_id(Info#ets_find_exp.id),
	db_agent:delete_find_exp(Info#ets_find_exp.id),
	spawn(fun()->db_agent:log_find_exp(PlayerId,Info#ets_find_exp.task_id,Info#ets_find_exp.name,Info#ets_find_exp.type,Info#ets_find_exp.timestamp,Info#ets_find_exp.times,Info#ets_find_exp.lv,Info#ets_find_exp.exp,Info#ets_find_exp.spt,NowTime,Type,0)end),
	del_find_exp_loop(ExpBag,PlayerId,Type,NowTime).

%%计算一键找回所需总元宝,获得的经验，灵力值
calc_gold_by_one_key([],_Mult,Gold,Exp,Spt,Newbag)->{Gold,Exp,Spt,Newbag};
calc_gold_by_one_key([E|ExpBag],Mult,Gold,Exp,Spt,Newbag)->
	if E#ets_find_exp.type /= 5->
		   NewGold = gold(E#ets_find_exp.type)+Gold,
		   NewExp = round(Mult*E#ets_find_exp.exp)+Exp,
		   NewSpt = round(Mult*E#ets_find_exp.spt)+Spt,
		   calc_gold_by_one_key(ExpBag,Mult,NewGold,NewExp,NewSpt,[E|Newbag]);
	   
	   true->
		   calc_gold_by_one_key(ExpBag,Mult,Gold,Exp,Spt,Newbag)
	end.

%%(1副本，2氏族任务，3日常任务，4试炼，5跑商，6循环任务，7随机循环)
gold(Type)->
	case Type of
		1->100;
		2->50;
		3->50;
		4->80;
		5->50;
		6->80;
		7->80;
		_->100
	end.

fun_type(Fun)->
	case Fun of
		dungeon->1;
		guild->2;
		pk_mon->3;
		train->4;
		business->5;
		cycle->6;
		random->7
	end.

%% %%更新经验找回信息
%% find_exp_all_1()->
%% 	NowTime = util:unixtime(),
%% 	{ZeroToday,_} = util:get_midnight_seconds(NowTime),
%% 	ZeroYesterday =ZeroToday-86400, 
%% 	%%最近6天有上线的玩家才更新
%% 	PlayerBag = db_agent:check_find_exp_player(ZeroToday-6*86400),
%% 	[spawn(fun()-> find_exp_1(PlayerId,Lv,GuildId,ZeroToday,ZeroYesterday)end)||[PlayerId,Lv,GuildId|_]<-PlayerBag],
%% 	ok.
%% 
%% find_exp_all_2()->
%% 	NowTime = util:unixtime(),
%% 	{ZeroToday,_} = util:get_midnight_seconds(NowTime),
%% 	ZeroYesterday =ZeroToday-86400, 
%% 	%%最近6天有上线的玩家才更新
%% 	PlayerBag = db_agent:check_find_exp_player(ZeroToday-6*86400),
%% 	[spawn(fun()-> find_exp_2(PlayerId,Lv,GuildId,ZeroToday,ZeroYesterday)end)||[PlayerId,Lv,GuildId|_]<-PlayerBag],
%% 	ok.

find_exp_all_cmd()->
	NowTime = util:unixtime(),
	{ZeroToday,_} = util:get_midnight_seconds(NowTime),
	ZeroYesterday =ZeroToday-86400, 
	%%最近6天有上线的玩家才更新
	PlayerBag = db_agent:check_find_exp_player(ZeroToday-6*86400),
	[find_exp(PlayerId,Lv,GuildId,ZeroToday,ZeroYesterday)||[PlayerId,Lv,GuildId|_]<-PlayerBag],
	ok.


get_update_time()->
	round((86400 - util:get_today_current_second()+10)*1000).

get_update_time_1()->
	NowSec = util:get_today_current_second(),
	case NowSec >= 4*3600 of
		false-> round(4*3600-NowSec)*1000;
		true->
			round(86400-NowSec + 4*3600)*1000
	end.
%% 	round((86400 - util:get_today_current_second()+10)*1000).

%%
%% Local Functions
%%
%%
%%更新个人经验找回信息
find_exp_single(PlayerId,Lv,GuildId,RegTime)->
	NowTime = util:unixtime(),
	{ZeroToday,_} = util:get_midnight_seconds(NowTime),
	%%2月16号之前，每天找回前一天的，找回的找回前三天的
	if NowTime > 1329321600->
		ZeroFirst = ZeroToday-1*86400,
		ZeroSecond = ZeroToday-2*86400,
		ZeroThird = ZeroToday-3*86400,
		ZeroBag = [ZeroThird,ZeroSecond,ZeroFirst],
		ok;
	   true->
		   ZeroFirst = ZeroToday-1*86400,
%% 		   ZeroSecond = ZeroToday-2*86400,
		   ZeroThird = ZeroToday-3*86400,
		   ZeroBag = [ZeroFirst]
	end,
	LogDate = db_agent:select_find_exp_date(PlayerId,ZeroThird),
	find_exp_single_loop(ZeroBag,PlayerId,Lv,GuildId,LogDate,ZeroToday,false,RegTime),
	ok.
find_exp_single_cmd(Status,Lv,GuildId,NowTime)->
	spawn(fun()->db_agent:delete_find_exp_date(Status#player.id,NowTime)end),
	{ZeroToday,_} = util:get_midnight_seconds(NowTime),
	ZeroFirst = ZeroToday-1*86400,
	ZeroSecond = ZeroToday-2*86400,
	ZeroThird = ZeroToday-3*86400,
	LogDate = db_agent:select_find_exp_date(Status#player.id,ZeroThird),
	find_exp_single_loop([ZeroThird,ZeroSecond,ZeroFirst],Status#player.id,Lv,GuildId,LogDate,ZeroToday,false,Status#player.reg_time),
 	lib_find_exp:delete_by_pid(Status#player.id),
	Data = db_agent:select_find_exp(Status#player.id),
	lists:map(fun init/1, Data),
	pp_exc:handle(33006,Status,[]),
	ok.

find_exp_single_loop([],PlayerId,_Lv,_GuildId,_LogDate,ZeroToday,Find,_RegTime)->
	case Find of
		true->
			spawn(fun()->db_agent:delete_dungeon_log(PlayerId,ZeroToday-86400*4)end),
			spawn(fun()->db_agent:delete_find_exp_date(PlayerId,ZeroToday-86400*4)end),
			ok;
		false->skip
	end;
find_exp_single_loop([ZeroYesterday|ZeroBag],PlayerId,Lv,GuildId,LogDate,ZeroToday,Find,RegTime)->
	if ZeroYesterday >= RegTime ->
		   case lists:member([ZeroYesterday],LogDate) of
			   true->NewFind=Find;
			   false->
				   ZeroToday1 = ZeroYesterday+86400,
				   task_normal(PlayerId,Lv,ZeroToday1,ZeroYesterday),
				   if GuildId>0->
						  task_guild(PlayerId,Lv,ZeroToday1,ZeroYesterday);
					  true->skip
				   end,
				   task_business(PlayerId,Lv,ZeroToday1,ZeroYesterday),
				   task_random(PlayerId,Lv,ZeroToday1,ZeroYesterday),
				   task_dungeon(PlayerId,Lv,ZeroToday1,ZeroYesterday),
				   task_train(PlayerId,Lv,ZeroToday1,ZeroYesterday),
				   task_cycle(PlayerId,Lv,ZeroToday1,ZeroYesterday),
				   spawn(fun()->db_agent:log_find_exp_date(PlayerId,ZeroYesterday)end),
				   NewFind=true,
				   ok
		   end;
	   true->NewFind=Find
	end,
	find_exp_single_loop(ZeroBag,PlayerId,Lv,GuildId,LogDate,ZeroToday,NewFind,RegTime).


find_exp(PlayerId,Lv,GuildId,ZeroToday,ZeroYesterday)->	
	case lib_player:get_player_pid(PlayerId) of
		[]->
			task_normal(PlayerId,Lv,ZeroToday,ZeroYesterday),
			if GuildId>0->
				   task_guild(PlayerId,Lv,ZeroToday,ZeroYesterday);
			   true->skip
			end,
			task_business(PlayerId,Lv,ZeroToday,ZeroYesterday),
			task_random(PlayerId,Lv,ZeroToday,ZeroYesterday),
			task_dungeon(PlayerId,Lv,ZeroToday,ZeroYesterday),
			task_train(PlayerId,Lv,ZeroToday,ZeroYesterday),
			task_cycle(PlayerId,Lv,ZeroToday,ZeroYesterday),
			ok;
		Pid->
			gen_server:cast(Pid, {'UPDATE_FIND_EXP',[PlayerId,Lv,GuildId,ZeroToday,ZeroYesterday]})
	end,
	ok.
%% find_exp_1(PlayerId,Lv,GuildId,ZeroToday,ZeroYesterday)->	
%% 	case lib_player:get_player_pid(PlayerId) of
%% 		[]->
%% 			task_dungeon(PlayerId,Lv,ZeroToday,ZeroYesterday),
%% 			task_train(PlayerId,Lv,ZeroToday,ZeroYesterday),
%% 			ok;
%% 		Pid->
%% 			gen_server:cast(Pid, {'UPDATE_FIND_EXP_1',[PlayerId,Lv,GuildId,ZeroToday,ZeroYesterday]})
%% 	end,
%% 	ok.
%% 
%% %%更新个人经验找回信息
%% find_exp_2(PlayerId,Lv,GuildId,ZeroToday,ZeroYesterday)->	
%% 	case lib_player:get_player_pid(PlayerId) of
%% 		[]->
%% 			task_normal(PlayerId,Lv,ZeroToday,ZeroYesterday),
%% 			if GuildId>0->
%% 				   task_guild(PlayerId,Lv,ZeroToday,ZeroYesterday);
%% 			   true->skip
%% 			end,
%% 			task_business(PlayerId,Lv,ZeroToday,ZeroYesterday),
%% 			task_random(PlayerId,Lv,ZeroToday,ZeroYesterday),
%% 			task_cycle(PlayerId,Lv,ZeroToday,ZeroYesterday),
%% 			ok;
%% 		Pid->
%% 			gen_server:cast(Pid, {'UPDATE_FIND_EXP_2',[PlayerId,Lv,GuildId,ZeroToday,ZeroYesterday]})
%% 	end,
%% 	ok.
%% 
%% exp_find_1(PlayerId,Lv,_GuildId,ZeroToday,ZeroYesterday)->
%% 	task_dungeon(PlayerId,Lv,ZeroToday,ZeroYesterday),
%% 	task_train(PlayerId,Lv,ZeroToday,ZeroYesterday),
%% 	ok.
%% 
%% exp_find_2(PlayerId,Lv,GuildId,ZeroToday,ZeroYesterday)->
%% 	task_normal(PlayerId,Lv,ZeroToday,ZeroYesterday),
%% 	if GuildId>0->
%% 		   task_guild(PlayerId,Lv,ZeroToday,ZeroYesterday);
%% 	   true->skip
%% 	end,
%% 	task_business(PlayerId,Lv,ZeroToday,ZeroYesterday),
%% 	task_random(PlayerId,Lv,ZeroToday,ZeroYesterday),
%% 	task_cycle(PlayerId,Lv,ZeroToday,ZeroYesterday),
%% 	ok.

%%试炼副本
task_train(PlayerId,Lv,ZeroToday,ZeroYesterday)->
	if Lv < 33->skip;
	   true->
		   case db_agent:select_dungeon_log(PlayerId,901,ZeroYesterday,ZeroToday) of
			   []->train_find_exp(PlayerId,Lv,ZeroYesterday);
			   _->skip
		   end
%% 			case db_agent:get_log_dungeon(PlayerId, 901) of
%% 				[]->train_find_exp(PlayerId,Lv,ZeroYesterday);
%% 				[_,_,Timestamp,_Times]->
%% 					if ZeroYesterday<Timestamp andalso Timestamp < ZeroToday ->skip;
%% 					   Timestamp > ZeroToday->skip;
%% 			  		 true->
%% 				  		 train_find_exp(PlayerId,Lv,ZeroYesterday)
%% 					end
%% 			end
	end,
	ok.

train_find_exp(PlayerId,Lv,ZeroYesterday)->
	FunType = fun_type(train),
	clear_find_exp(PlayerId,FunType,901),
	{Exp,Spt} = train_exp(Lv),
	db_agent:insert_find_exp(PlayerId,901,"试炼副本",FunType,ZeroYesterday,1,Lv,Exp,Spt),
	ok.

%%试炼经验
train_exp(Lv)->
	if Lv < 40 -> {675000,421875};
	   Lv < 50 -> {1406250,879187};
	   Lv < 60 -> {3375000,2109375};
	   Lv < 70 -> {4781250,2988562};
	   Lv < 80 -> {6750000,4218750};
	   true-> {7031250,4394812}
	end.

%%普通日常3
task_normal(PlayerId,Lv,ZeroToday,ZeroYesterday)->
	TaskBag = data_task:task_get_pk_mon_id_list(),
	FunType = fun_type(pk_mon),
	lists:map( fun(TaskId)->
					   %%获取任务数据
					   case lib_task:get_data(TaskId) of
						   []->
							   skip;
						   TD->
							   %%检查可接等级
							   case lib_task:check_lvl(TD,Lv) of
								   false->skip;
								   true->
									   %%获取已完成次数
									   LogTimes =  length(db_agent:check_task_log_by_date(PlayerId,TaskId,ZeroYesterday,ZeroToday)),
									   %%任务可完成次数
									   Times = lib_task:check_daily_times(TD#task.condition),
									   if LogTimes >= Times-> skip;
										  true->
											  ResTimes = Times-LogTimes,
											  %%查找记录
											  clear_find_exp(PlayerId,FunType,TaskId),
											  %%添加新的经验找回
											  db_agent:insert_find_exp(PlayerId,TaskId,TD#task.name,FunType,ZeroYesterday,ResTimes,Lv,TD#task.exp*ResTimes,TD#task.spt*ResTimes),
											  ok
									   end
							   end
					   end
			   end, TaskBag),
	ok.

%%副本任务1
task_dungeon(PlayerId,Lv,ZeroToday,ZeroYesterday)->
	TaskBag = data_task:task_get_dungeon_id_list(),
	FunType=fun_type(dungeon),
	lists:map( fun(TaskId)->
					   case lib_task:get_data(TaskId) of
						   []->
							   skip;
						   TaskData->
							   case lib_task:check_lvl(TaskData,Lv) of
								   false->skip;
								   true->
									   DungeonId = get_dungeon(TaskData#task.id),
									   case db_agent:select_dungeon_log(PlayerId,DungeonId,ZeroYesterday,ZeroToday) of
										   []->dungeon_find_exp(PlayerId,Lv,FunType,DungeonId,0,TaskData,ZeroYesterday,ZeroToday);
										   DungeonLog->
											   DungeonTimes = length(DungeonLog),
											   {Res,NewDungeonTimes} = 
												   if DungeonTimes>=3->{false,0};
													  true->{true,DungeonTimes}
												   end,
											   case Res of
												   true->
													   dungeon_find_exp(PlayerId,Lv,FunType,DungeonId,NewDungeonTimes,TaskData,ZeroYesterday,ZeroToday);
												   false->skip
											   end
%% 									   case db_agent:get_log_dungeon(PlayerId, DungeonId) of
%% 										   []->
%% 											   dungeon_find_exp(PlayerId,Lv,FunType,DungeonId,0,TaskData,ZeroYesterday,ZeroToday);
%% 										   [_,_,DungeonTimestamp,DungeonTimes]->
%% 											   {Res,NewDungeonTimes} = 
%% 												   if ZeroYesterday<DungeonTimestamp andalso DungeonTimestamp < ZeroToday ->
%% 														  if DungeonTimes>=3->{false,0};
%% 															 true->{true,DungeonTimes}
%% 														  end;
%% 													  DungeonTimestamp > ZeroToday->
%% 														  {false,0};
%% 													  true->{true,0}
%% 												   end,
%% 											   case Res of
%% 												   true->
%% 													   dungeon_find_exp(PlayerId,Lv,FunType,DungeonId,NewDungeonTimes,TaskData,ZeroYesterday,ZeroToday);
%% 												   false->skip
%% 											   end
									   end
							   end
					   end
			   end, TaskBag),
	ok.

dungeon_find_exp(PlayerId,Lv,FunType,DungeonId,DungeonTimes,TaskData,ZeroYesterday,ZeroToday)->
	LogTimes =  length(db_agent:check_task_log_by_date(PlayerId,TaskData#task.id,ZeroYesterday,ZeroToday)),
	Times = lib_task:check_daily_times(TaskData#task.condition),
	if LogTimes >= Times->
		   %%由于70副本只有1次任务，所以即使任务完成了，如果进入副本次数未满3次的，还是可以获得高经验
		   if DungeonId =:= 961->
				  special_dungeon_70(PlayerId,Lv,FunType,DungeonId,DungeonTimes,ZeroYesterday,TaskData);
			  true->skip
		   end;
	   true->
		   normal_dungeon(PlayerId,Lv,FunType,DungeonId,DungeonTimes,Times-LogTimes,TaskData,ZeroYesterday)
	end,
	ok.

%%70副本特殊处理
special_dungeon_70(PlayerId,Lv,FunType,DungeonId,DungeonTimes,ZeroYesterday,TaskData)->
	 clear_find_exp(PlayerId,FunType,TaskData#task.id),
	 {Exp,Spt} = dungeon_exp(DungeonId),
	 NewExp = round(Exp*(?MAX_EXP_TIMES-DungeonTimes)),
	 NewSpt = round(Spt*(?MAX_EXP_TIMES-DungeonTimes)),
	 db_agent:insert_find_exp(PlayerId,TaskData#task.id,TaskData#task.name,FunType,ZeroYesterday,1,Lv,NewExp,NewSpt),
	 ok.

%%普通副本(70副本任务没完成的话也走这个接口)
normal_dungeon(PlayerId,Lv,FunType,DungeonId,NewDungeonTimes,ResTimes,TaskData,ZeroYesterday)->
%% 	ResTimes = Times-LogTimes,
	clear_find_exp(PlayerId,FunType,TaskData#task.id),
	{Exp,Spt} = dungeon_exp(DungeonId),
	NewExp = round(TaskData#task.exp*ResTimes+Exp*(?MAX_EXP_TIMES-NewDungeonTimes)),
	NewSpt = round(TaskData#task.spt*ResTimes+Spt*(?MAX_EXP_TIMES-NewDungeonTimes)),
	db_agent:insert_find_exp(PlayerId,TaskData#task.id,TaskData#task.name,FunType,ZeroYesterday,ResTimes,Lv,NewExp,NewSpt),
	ok.

%%副本经验1次
dungeon_exp(Id)->
	case Id of
		911->{21240,13140};
		920->{115065,66960};
		930->{458910,263565};
		940->{854595,489465};
		950->{1009935,577890};
		961->{1212365,606182};
		_->{0,0}
	end.

%%任务id-副本id
get_dungeon(TaskId)->
	case TaskId of
		61002->911;
		61010->920;
		61015->930;
		61016->940;
		61036->950;
		_->961
	end.

%%氏族任务2
task_guild(PlayerId,Lv,ZeroToday,ZeroYesterday)->
	TaskBag1 = data_task:task_get_guild_id_list(),
	%%氏族祝福任务不算在内
	TaskBag = lists:delete(83150, TaskBag1),
	FunType=fun_type(guild),
	lists:map( fun(TaskId)->
					   case lib_task:get_data(TaskId) of
						   []->
							   skip;
						   TD->
							   case lib_task:check_lvl(TD,Lv) of
								   false->skip;
								   true->
									   LogTimes =  length(db_agent:check_task_log_by_date(PlayerId,TaskId,ZeroYesterday,ZeroToday)),
									   Times = lib_task:check_daily_times(TD#task.condition),
									   if LogTimes >= Times-> skip;
										  true->
											  ResTimes = Times-LogTimes,
											  clear_find_exp(PlayerId,FunType,TaskId),
											  db_agent:insert_find_exp(PlayerId,TaskId,TD#task.name,FunType,ZeroYesterday,ResTimes,Lv,TD#task.exp*ResTimes,TD#task.spt*ResTimes),
											  ok
									   end
							   end
					   end
			   end, TaskBag),
	ok.

%%循环任务6
task_cycle(PlayerId,Lv,ZeroToday,ZeroYesterday)->
	TaskBag = [70100,70103,70106],
	case lib_task:get_data(70100) of
		[]->
			skip;
		TD->
			case lib_task:check_lvl(TD,Lv) of
				false->skip;
				true->
					LogTimesInfo = times_log(TaskBag,PlayerId,ZeroYesterday,ZeroToday,[]),
					TimesBag = times_info(LogTimesInfo,[]),
					case  check_cycle_times(TimesBag,ZeroToday,ZeroYesterday) of
						true->skip;
						false->
							FunType=fun_type(cycle),
							clear_find_exp(PlayerId,FunType,70100),
							{Exp,Spt} = get_cycle_award(LogTimesInfo,Lv,[0,0]),
							CanTimes = can_times(TimesBag,0),
							db_agent:insert_find_exp(PlayerId,70100,TD#task.name,FunType,ZeroYesterday,CanTimes,Lv,Exp,Spt),
							ok
					end
			end
	end.

%%循环任务已完成次数
times_log([],_PlayerId,_ZeroYesterday,_ZeroToday,LogTimesBag)->LogTimesBag;
times_log([TaskId|TaskBag],PlayerId,ZeroYesterday,ZeroToday,LogTimesBag)->
	LogTimes =  length(db_agent:check_task_log_by_date(PlayerId,TaskId,ZeroYesterday,ZeroToday)),
	times_log(TaskBag,PlayerId,ZeroYesterday,ZeroToday,[{TaskId,LogTimes}|LogTimesBag]).	

%%循环任务完成信息{任务id，完成次数，可完成次数}
times_info([],TimesBag)->TimesBag;
times_info([{TaskId,LogTimes}|TaskBag],TimesBag)->
	case lib_task:get_data(TaskId) of 
		[]->
			times_info(TaskBag,[{TaskId,LogTimes,5}|TimesBag]);
		TD->
			Times = lib_task:check_daily_times(TD#task.condition),
			times_info(TaskBag,[{TaskId,LogTimes,Times}|TimesBag])
	end.

%%剩余可完成次数
can_times([],Times)->Times;
can_times([{_,LogTimes,MaxTimes}|TaskBag],Times)->
	can_times(TaskBag,Times+MaxTimes-LogTimes).

%%查询经验是否可找
check_cycle_times([],_ZeroToday,_ZeroYesterday)->true;
check_cycle_times([{_TaskId,LogTimes,MaxTimes}|TaskBag],ZeroToday,ZeroYesterday)->
	if LogTimes < MaxTimes -> false;
	   true->
		   check_cycle_times(TaskBag,ZeroToday,ZeroYesterday)
	end.

%%获取循环任务奖励
get_cycle_award([],_Lv,[Exp,Spt])->{Exp,Spt};
get_cycle_award([{TaskId,LogTimes}|TaskBag],Lv,[Exp,Spt])->
	{NewExp,NewSpt} = lib_task:calc_cycle_exp(Lv,TaskId,LogTimes+1,{0,0}),
	get_cycle_award(TaskBag,Lv,[Exp+NewExp,Spt+NewSpt]).
	
%%随机循环任务 7
task_random(PlayerId,Lv,ZeroToday,ZeroYesterday)->
	%%83124,83125,83126,83127,83128
	TaskBag= [83124,83125,83126,83127,83128],
	FunType=fun_type(random),
	lists:map( fun(TaskId)->
					   case lib_task:get_data(TaskId) of
						   []->
							   skip;
						   TD->
							   case lib_task:check_lvl(TD,Lv) of
								   false->skip;
								   true->
									   LogTimes =  length(db_agent:check_task_log_by_date(PlayerId,TaskId,ZeroYesterday,ZeroToday)),
									   Times = lib_task:check_daily_times(TD#task.condition),
									   if LogTimes >= Times-> skip;
										  true->
											  ResTimes = Times-LogTimes,
											  clear_find_exp(PlayerId,FunType,TaskId),
											  db_agent:insert_find_exp(PlayerId,TaskId,TD#task.name,FunType,ZeroYesterday,ResTimes,Lv,TD#task.exp*ResTimes,TD#task.spt*ResTimes),
											  ok
									   end
							   end
					   end
			   end, TaskBag),
	ok.

%%跑商任务5
task_business(PlayerId,Lv,ZeroToday,ZeroYesterday)->
	TaskBag = data_task:task_get_business_id_list(),
	FunType=fun_type(business),
	lists:map( fun(TaskId)->
					   case lib_task:get_data(TaskId) of
						   []->
							   skip;
						   TD->
							   case lib_task:check_lvl(TD,Lv) of
								   false->skip;
								   true->
									   LogTimes =  length(db_agent:check_task_log_by_date(PlayerId,TaskId,ZeroYesterday,ZeroToday)),
									   Times = lib_task:check_daily_times(TD#task.condition),
									   if LogTimes >= Times-> skip;
										  true->
											  ResTimes = Times-LogTimes,
											  clear_find_exp(PlayerId,FunType,TaskId),
											  {Exp,Spt} = lib_business:base_award(4,Lv),
											  db_agent:insert_find_exp(PlayerId,TaskId,TD#task.name,FunType,ZeroYesterday,ResTimes,Lv,ResTimes*Exp,ResTimes*Spt),
%% 											  business_find(ResTimes,PlayerId,Lv,TD,FunType,ZeroYesterday),
											  ok
									   end
							   end
					   end
			   end, TaskBag),
	ok.

%%添加任务奖励
business_find(0,_PlayerId,_Lv,_TaskData,_FunType,_ZeroYesterday)->ok;
business_find(Times,PlayerId,Lv,TaskData,FunType,ZeroYesterday)->
	{Exp,Spt} = lib_business:base_award(4,Lv),
	db_agent:insert_find_exp(PlayerId,TaskData#task.id,TaskData#task.name,FunType,ZeroYesterday,1,Lv,Exp,Spt),
	business_find(Times-1,PlayerId,Lv,TaskData,FunType,ZeroYesterday).

clear_find_exp(PlayerId,FunType,TaskId)->
	IdBag = db_agent:check_find_exp_by_type(FunType,TaskId,PlayerId),
	IdList = [Id||[Id]<-IdBag],
	case length(IdList) >=3 of
		true->
			IdList1= lists:reverse(lists:sort(IdList)),
			OldList = lists:nthtail(2,IdList1),
			lists:map( fun(Id)->
							   db_agent:delete_find_exp(Id)
					   end,OldList);
		false->
			skip
	end.

update_find_exp(FindExp)->
	ets:insert(?ETS_FIND_EXP, FindExp).

select_by_pid(PlayerId)->
	ets:match_object(?ETS_FIND_EXP, #ets_find_exp{pid=PlayerId,_='_'}).

select_by_type(PlayerId,Type,Timestamp)->
	ets:match_object(?ETS_FIND_EXP, #ets_find_exp{pid=PlayerId,type=Type,timestamp=Timestamp,_='_'}).

select_by_id(Id)->
	ets:lookup(?ETS_FIND_EXP, Id).

delete_by_id(Id)->
	ets:delete(?ETS_FIND_EXP, Id).

delete_by_pid(PlayerId)->
	ets:match_delete(?ETS_FIND_EXP, #ets_find_exp{pid=PlayerId,_='_'}).
	