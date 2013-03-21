%% Author: Administrator
%% Created: 2011-7-6
%% Description: TODO: 新登录奖励
-module(lib_login_award).

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

%%获取登陆奖励信息
check_award_info(PlayerId)->
	case select_award(PlayerId) of
		[]->
			{0,0,get_uc_info(null),get_c_info(null)};
		[Award]->
			{is_charge_player(PlayerId),Award#ets_login_award.days,get_uc_info(Award),get_c_info(Award)}
	end.

%%清除登陆日期1成功，2系统繁忙，请稍候清除
clear_login_days(PlayerId)->
	case select_award(PlayerId) of
		[]->{error,2};
		[Award]->
			NewAward=Award#ets_login_award{days=0},
			update_award(NewAward),
			db_agent:update_login_award([{days,0}],[{pid,PlayerId}]),
			spawn(fun()->db_agent:log_login_award(PlayerId,3,0,0,0,util:unixtime())end),
			{ok,1}
	end.

%%领取奖励1成功，2系统繁忙，请稍后领取3背包不足,4没有物品可领取,5您不是充值玩家，不能领取,6数据异常
get_award(PlayerStatus,TypeId,Day)->
	case lists:member(TypeId,[1,2]) of
		false->{error,6};
		true->
			case lists:member(Day, [1,2,3,5,7,10,15,20,25,30,35,40,45,50,55,60]) of
				false->{error,6};
				true->
					case select_award(PlayerStatus#player.id) of
						[]->{error,2};
						[Award]->
							Index = day_to_index(Day),
							case get_goods(Award,TypeId,Index) of
								false-> {error,6};
								GoodsList->
									case gen_server:call(PlayerStatus#player.other#player_other.pid_goods,{'cell_num'})< length(GoodsList) of
										false->
											case TypeId of
												1->give_goods(PlayerStatus,Award,TypeId,Day,Index,GoodsList);
												_2->
													case is_charge_player(PlayerStatus#player.id) of
														0->{error,5};
														_->
															give_goods(PlayerStatus,Award,TypeId,Day,Index,GoodsList)
													end
											end;
										true->{error,3}
									end
							end
					end
			end
	end.

%%获取物品列表
get_goods(Award,Type,Index)->
	case Type of
		1->
			case length(Award#ets_login_award.un_charge)<Index of
				true->false;
				false->
					lists:nth(Index,Award#ets_login_award.un_charge)
			end;
		_->
			case length(Award#ets_login_award.charge)<Index of
				true->false;
				false->
					lists:nth(Index,Award#ets_login_award.charge)
			end
	end.

%%获取物品
give_goods(PlayerStatus,Award,Type,Day,Index,[])->
	update_goods_info(PlayerStatus#player.id,Award,Type,Day,Index),
	{ok,1};
give_goods(PlayerStatus,Award,Type,Day,Index,[GoodsInfo|GoodsList])->
	[_,GoodsId,GoodsNum] = GoodsInfo,
	case GoodsNum < 1 of
		true->{error,4};
		false->
			case (catch gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'give_goods', PlayerStatus, GoodsId, GoodsNum,2}))of
				ok->
					db_agent:log_login_award(PlayerStatus#player.id,Type,Day,GoodsId,GoodsNum,util:unixtime()),
					give_goods(PlayerStatus,Award,Type,Day,Index,GoodsList);
				_->{error,2}
			end
	end.
	
%%更新物品列表
update_goods_info(PlayerId,Award,Type,Day,Index)->
	if Day =:= 60->
		   spawn(fun()->db_agent:log_login_award(PlayerId,3,0,0,0,util:unixtime())end),
		   NewDays = 0;
	   true->
		   NewDays = Award#ets_login_award.days
	end,
	case Type of
		1->
			{Goods_Id,_} = goods(Type,Day),
			GoodsBag = tool:replace(Award#ets_login_award.un_charge, Index, [[Day,Goods_Id,0]]),
			NewAward = Award#ets_login_award{un_charge=GoodsBag,days = NewDays},
			update_award(NewAward),
			db_agent:update_login_award([{un_charge,util:term_to_string(GoodsBag)},{days,NewDays}],[{pid,PlayerId}]);
		_->
			{Goods_Id,_} = goods(Type,Day),
			GoodsBag = tool:replace(Award#ets_login_award.charge, Index, [[Day,Goods_Id,0]]),
			NewAward = Award#ets_login_award{charge=GoodsBag,days=NewDays},
			update_award(NewAward),
			db_agent:update_login_award([{charge,util:term_to_string(GoodsBag)},{days,NewDays}],[{pid,PlayerId}])
	end.


%%初始化登录奖励数据
init_login_award(PlayerId)->
	NowTime = util:unixtime(),
	case db_agent:select_login_award(PlayerId) of
		[]->
			case is_charge_player(PlayerId) of
				0->
					UnCharge = util:term_to_string(get_uc_info(init)),
					Charge = util:term_to_string(get_c_info(null)),
					Mark = 0;
				_->
					UnCharge = util:term_to_string(get_uc_info(null)),
					Charge = util:term_to_string(get_c_info(init)),
					Mark = 1
				end,
			{_,Id} = db_agent:insert_login_award(PlayerId,1,NowTime,UnCharge,Charge,Mark),
			EstData = [Id,PlayerId,1,NowTime,UnCharge,Charge,Mark],
			LoginAward = pack_ets(EstData),
			update_award(LoginAward),
			ok;
		Data->
			NewData = update_login_days(NowTime,Data),
			LoginAward = pack_ets(NewData),
%% 			NewLoginAward = update_change_goods(PlayerId,LoginAward),
			update_award(LoginAward),
			ok
	end.

offline(PlayerId)->
	case select_award(PlayerId) of
		[]->skip;
		[Award]->
			update_login_days_offline(PlayerId,Award)
	end,
	delete_award(PlayerId).

%%
%% Local Functions
%%
pack_ets(Data)->
	[Id,Pid,Days,Timestamp,UnCharge,Charge,Mark] = Data,
	#ets_login_award{
					 id = Id,
					 pid = Pid,
					 days = Days,
					 time = Timestamp,
					 un_charge = util:string_to_term(tool:to_list(UnCharge)),
					 charge = util:string_to_term(tool:to_list(Charge)),
					 charge_mark = Mark
					 }.

%% %%获取未充值奖励信息[1,2,3,5,7,10,15,20,25,30,35,40,45,50,55,60]
get_uc_info(Award)->
	case is_record(Award,ets_login_award) of
		true-> 
			Award#ets_login_award.un_charge;
		false->
			case Award of
				init->
					[[[1,23007,1]],
 					[[2,23203,0]],
 					[[3,21200,0]],
 					[[5,21100,0]],
 					[[7,24400,0]],
 					[[10,22000,0]],
 					[[15,20300,0]],
 					[[20,24105,0]],
					[[25,20301,0]],
 					[[30,21801,0]],
 					[[35,20302,0]],
 					[[40,28801,0]],
 					[[45,24401,0]],
 					[[50,28802,0]],
 					[[55,22007,0]],
					[[60,21600,0]]];
				_->
					[[[1,23007,0]],
 					[[2,23203,0]],
 					[[3,21200,0]],
 					[[5,21100,0]],
 					[[7,24400,0]],
 					[[10,22000,0]],
		 			[[15,20300,0]],
 					[[20,24105,0]],
					[[25,20301,0]],
 					[[30,21801,0]],
 					[[35,20302,0]],
 					[[40,28801,0]],
 					[[45,24401,0]],
 					[[50,28802,0]],
 					[[55,22007,0]],
					[[60,21600,0]]]
			end
	end.

%%获取充值奖励信息[1,2,3,5,7,10,15,20,25,30,35,40,45,50,55,60]
get_c_info(Award)->
	case is_record(Award,ets_login_award) of
		true->
			Award#ets_login_award.charge;
		false->
			case Award of
				init->
					[[[1,23006,1]],
 					[[2,23204,0]],
 					[[3,21201,0]],
 					[[5,21101,0]],
 					[[7,24400,0]],
 					[[10,22000,0]],
 					[[15,20300,0]],
 					[[20,24105,0]],
 					[[25,20301,0]],
 					[[30,21801,0]],
 					[[35,20302,0]],
 					[[40,28801,0]],
 					[[45,24401,0]],
 					[[50,28802,0]],
 					[[55,22007,0]],
					[[60,21600,0]]];
				_->
					[[[1,23006,0]],
 					[[2,23204,0]],
 					[[3,21201,0]],
 					[[5,21101,0]],
 					[[7,24400,0]],
 					[[10,22000,0]],
 					[[15,20300,0]],
 					[[20,24105,0]],
 					[[25,20301,0]],
 					[[30,21801,0]],
 					[[35,20302,0]],
 					[[40,28801,0]],
 					[[45,24401,0]],
 					[[50,28802,0]],
 					[[55,22007,0]],
					[[60,21600,0]]]
			end
	end.
%% 
%% %%获取未充值奖励信息[1,2,3,5,7,10,15,20,25,30,35,40,45,50,55,60]
%% get_uc_info(Award)->
%% 	DayList = [1,2,3,5,7,10,15,20,25,30,35,40,45,50,55,60],
%% 	case is_record(Award,ets_login_award) of
%% 		true-> 
%% 			merge_list(Award#ets_login_award.un_charge,DayList,[]);
%% 		false->
%% 			Data = [[[23007,1]],[[23203,0]],[[21200,0]],[[21100,0]],
%% 			 [[24400,0]],[[22000,0]],[[20300,0]],[[24105,0]],
%% 			 [[20301,0]],[[21801,0]],[[20302,0]],[[28801,0]],
%% 			 [[24401,0]],[[28802,0]],[[22007,0]],[[21600,0]]],
%% 			merge_list(Data,DayList,[])
%% 	end.
%% 
%% %%获取充值奖励信息[1,2,3,5,7,10,15,20,25,30,35,40,45,50,55,60]
%% get_c_info(Award)->
%% 	DayList = [1,2,3,5,7,10,15,20,25,30,35,40,45,50,55,60],
%% 	case is_record(Award,ets_login_award) of
%% 		true->
%% 			merge_list(Award#ets_login_award.charge,DayList,[]);
%% 		false->
%% 			Data = [[[23006,1]],[[23204,0]],[[21201,0]],[[21101,0]],
%% 			 [[24400,0]],[[22000,0]],[[20300,0]],[[24105,0]],
%% 			 [[20301,0]],[[21801,0]],[[20302,0]],[[28801,0]],
%% 			 [[24401,0]],[[28802,0]],[[22007,0]],[[21600,0]]],
%% 			merge_list(Data,DayList,[])
%% 	end.


%% get_base_award(Type)->
%% 	case Type of
%% 		1->
%% 			[[[23007,1]],[[23203,0]],[[21200,0]],[[21100,0]],
%% 			 [[24400,0]],[[22000,0]],[[20300,0]],[[24105,0]],
%% 			 [[20301,0]],[[21801,0]],[[20302,0]],[[28801,0]],
%% 			 [[24401,0]],[[28802,0]],[[22007,0]],[[21600,0]]];
%% 		_->
%% 			[[23006,1],[23204,0],[21201,0],[21101,0],
%% 			 [24400,0],[22000,0],[20300,0],[24105,0],
%% 			 [20301,0],[21801,0],[20302,0],[28801,0],
%% 			 [24401,0],[28802,0],[22007,0],[21600,0]]
%% 	end.
			
merge_list([],_,GoodsBag)->
	lists:reverse(GoodsBag);
merge_list(_,[],GoodsBag)->
	lists:reverse(GoodsBag);
merge_list([GoodsInfo|GoodsList],[Day|DayList],GoodsBag)->
	NewGoods = merge(GoodsInfo,Day,[]),
	merge_list(GoodsList,DayList,[NewGoods|GoodsBag]).

merge([],_Day,GoodsBag)->
	lists:reverse(GoodsBag);
merge([Goods|GoodsList],Day,GoodsBag)->
	NewGoods = [Day|Goods],
	merge(GoodsList,Day,[NewGoods|GoodsBag]).

%%更新登陆奖励信息
update_login_days(NowTime,Data)->
	[Id,Pid,Days,Timestamp,UnCharge,Charge,Mark] = Data,
	case check_online_day(Timestamp,NowTime) of
		0->Data;
		1->
			case get_charge_date(Pid) of
				0->
					NewUnCharge = update_goodsinfo(UnCharge,1,Days+1),
					db_agent:update_login_award([{days,Days+1},{time,NowTime},{un_charge,NewUnCharge}],[{pid,Pid}]),
					[Id,Pid,Days+1,NowTime,NewUnCharge,Charge,Mark] ;
				_ChargeDate ->
					NewCharge = update_goodsinfo(Charge,2,Days+1),
					db_agent:update_login_award([{days,Days+1},{time,NowTime},{charge,NewCharge}],[{pid,Pid}]),
					[Id,Pid,Days+1,NowTime,UnCharge,NewCharge,Mark] 
			end;
		_->
			spawn(fun()->db_agent:log_login_award(Pid,4,0,0,0,NowTime)end),
			case get_charge_date(Pid) of
				0->
					NewUnCharge = update_goodsinfo(UnCharge,1,1),
					db_agent:update_login_award([{days,1},{time,NowTime},{un_charge,NewUnCharge}],[{pid,Pid}]),
					[Id,Pid,1,NowTime,NewUnCharge,Charge,Mark] ;
				_ChargeDate ->
					NewCharge = update_goodsinfo(Charge,2,1),
					db_agent:update_login_award([{days,1},{time,NowTime},{charge,NewCharge}],[{pid,Pid}]),
					[Id,Pid,1,NowTime,UnCharge,NewCharge,Mark] 
			end
	end.
		
%%玩家下线，更新天数
update_login_days_offline(PlayerId,Award)->
	NowTime = util:unixtime(),
	Days = Award#ets_login_award.days,
	case check_online_day(Award#ets_login_award.time,NowTime) of
		0->skip;
		_->
			case get_charge_date(PlayerId) of
				0->
					NewUnCharge = update_goodsinfo(util:term_to_string(Award#ets_login_award.un_charge),1,Days+1),
					db_agent:update_login_award([{days,Days+1},{time,NowTime},{un_charge,NewUnCharge}],[{pid,PlayerId}]),
					ok;
				_ChargeDate ->
					NewCharge = update_goodsinfo(util:term_to_string(Award#ets_login_award.charge),2,Days+1),
					db_agent:update_login_award([{days,Days+1},{time,NowTime},{charge,NewCharge}],[{pid,PlayerId}]),
					ok
			end
	end.

%%获取充值日期
get_charge_date(PlayerId)->
	case db_agent:get_first_pay_time(PlayerId) of
		null->
			case db_agent:get_first_pay_time_phone(PlayerId) of
				null ->0;
				T->T
			end;
		Timestamp->Timestamp
	end.

%%是否充值玩家
is_charge_player(PlayerId)->
	case db_agent:get_first_pay_time(PlayerId) of
		null->
			case db_agent:get_first_pay_time_phone(PlayerId) of
				null->0;
				_->1
			end;
		_Timestamp->1
	end.

%%更新奖励包信息
update_goodsinfo(GoodsBag,Type,Days)->
	case lists:member(Days,[1,2,3,5,7,10,15,20,25,30,35,40,45,50,55,60]) of
		true->
			NewGoodsBag = util:string_to_term(tool:to_list(GoodsBag)),
			Index = day_to_index(Days),
			{GoodsId,Num } = goods(Type,Days),
			GoodsList = lists:nth(Index,NewGoodsBag),
			NewGoodsList = replace_goods(GoodsList,GoodsId,Num,[]),
			GoodsInfo = tool:replace(NewGoodsBag, Index, NewGoodsList),
			util:term_to_string(GoodsInfo);
		false->
			GoodsBag
	end.

%%物品id变换
update_change_goods(PlayerId,Award)->
	{_,UnCharge} = change_goods(Award#ets_login_award.un_charge,45,24401,1),
	{_,Charge} = change_goods(Award#ets_login_award.charge,45,24401,1),
	NewAward = Award#ets_login_award{un_charge=UnCharge,charge=Charge},
	if Award=/= NewAward->
		   db_agent:update_login_award([{un_charge,util:term_to_string(UnCharge)},{charge,util:term_to_string(Charge)}],[{pid,PlayerId}]);
	   true->skip
	end,
	NewAward.

%%替换物品id
change_goods(GoodsBag,Days,GoodsId,Num)->
	Index = day_to_index(Days),
	GoodsInfo = lists:nth(Index,GoodsBag),
	NewGoodsInfo = change_goods_id(GoodsInfo,GoodsId,Num,[]),
	if GoodsBag =/= NewGoodsInfo ->
		   NewGoodsBag = tool:replace(GoodsBag, Index, NewGoodsInfo),
		   {true,NewGoodsBag};
	   true->
		   {false,GoodsBag}
	end.
%%替换物品id
change_goods_id([],_GoodsId,_GoodsNum,GoodsBag)->
	GoodsBag;
change_goods_id([GoodsInfo|GoodsList],GoodsId,GoodsNum,GoodsBag)->
	[Day,Id,Num] = GoodsInfo,
	if Id =:= GoodsId ->
		   replace_goods(GoodsList,GoodsId,GoodsNum,[[Day,Id,Num]|GoodsBag]);
	   true->
		   replace_goods(GoodsList,GoodsId,GoodsNum,[[Day,GoodsId,Num]|GoodsBag])
	end.

%%替换物品数量
replace_goods([],_GoodsId,_GoodsNum,GoodsBag)->
	GoodsBag;
replace_goods([GoodsInfo|GoodsList],GoodsId,GoodsNum,GoodsBag)->
	[Day,Id,Num] = GoodsInfo,
	if Id =:= GoodsId ->
		   replace_goods(GoodsList,GoodsId,GoodsNum,[[Day,Id,Num+GoodsNum]|GoodsBag]);
	   true->
		   replace_goods(GoodsList,GoodsId,GoodsNum,[[Day,Id,Num]|GoodsBag])
	end.

%%充值玩家物品处理
charge_goods(GoodsBag,ChargeDate,NowTime,Days,Mark)->
	case check_online_day(ChargeDate,NowTime) of
		0->
			case lists:member(Days,[1,2,3,5,7,10,15,20,25,30,35,40,45,50,55,60]) of
				true-> 
					NewGoodsBag = util:string_to_term(tool:to_list(GoodsBag)),
					Index = day_to_index(Days),
					{GoodsId,Num } = goods(2,Days),
					GoodsList = lists:nth(Index,NewGoodsBag),
					{NewMark,NewGoodsList}= check_goods(GoodsList,GoodsId,Num,Mark,[]),
					GoodsInfo = tool:replace(NewGoodsBag, Index, NewGoodsList),
					{util:term_to_string(GoodsInfo),NewMark};
				false->{GoodsBag,Mark}
			end;
		_->{GoodsBag,Mark}
	end.

%%检查今天的物品是否已经加过
check_goods([],_GoodsId,_GoodsNum,Mark,GoodsBag)->
	{Mark,GoodsBag};
check_goods([GoodsInfo|GoodsList],GoodsId,GoodsNum,Mark,GoodsBag)->
	[Day,Id,Num] = GoodsInfo,
	if Mark =:= 0  andalso Id =:= GoodsId ->
		   check_goods(GoodsList,GoodsId,GoodsNum,1,[[Day,Id,Num+GoodsNum]|GoodsBag]);
	   true->
		   check_goods(GoodsList,GoodsId,GoodsNum,Mark,[[Day,Id,Num]|GoodsBag])
	end.

%%database
update_login_award(ValueList,WhereList)->
	db_agent:update_login_award(ValueList,WhereList).

%%ets
select_award(PlayerId)->
	ets:lookup(?ETS_LOGIN_AWARD, PlayerId).
update_award(Award)->
	ets:insert(?ETS_LOGIN_AWARD, Award).
delete_award(PlayerId)->
	ets:delete(?ETS_LOGIN_AWARD, PlayerId).

%%类型转换
id_to_type(Id)->
	case Id of
		1->uc;
		_->c
	end.

check_day_limit(Days)->
	if Days< 1->0;
	   Days< 2->1;
	   Days< 3->2;
	   Days< 5->3;
	   Days< 7->5;
	   Days< 10->7;
	   Days< 15->10;
	   Days< 20->15;
	   Days< 25 ->20;
	   Days< 30 -> 25;
	   Days< 35 -> 30;
	   Days< 40 -> 35;
	   Days< 45 -> 40;
	   Days< 50 -> 45;
	   Days< 55 ->50;
	   Days< 60 -> 55;
	   true-> 60
	end.

day_to_index(Day)->
	case Day of
		1->1;
		2->2;
		3->3;
		5->4;
		7->5;
		10->6;
		15->7;
		20->8;
		25->9;
		30->10;
		35->11;
		40->12;
		45->13;
		50->14;
		55->15;
		_->16
	end.

%%检查天数差
check_online_day(Timestamp,NowTime)->
	NDay = (NowTime+8*3600) div 86400,
	TDay = (Timestamp+8*3600) div 86400,
	NDay-TDay.

%%获取物品{物品id，物品数量}
goods(Type,Days)->
	case Type of
		1->
			case Days of
				1->{23007,1};
				2->{23203,1};
				3->{21200,1};
				5->{21100,1};
				7->{24400,1};
				10->{22000,1};
				15->{20300,1};
				20->{24105,1};
				25->{20301,1};
				30->{21801,1};
				35->{20302,1};
				40->{28801,1};
				45->{24401,1};
				50->{28802,1};
				55->{22007,1};
				60->{21600,1};
				_->{0,0}
			end;
		2->
			case Days of
				1->{23006,1};
				2->{23204,1};
				3->{21201,1};
				5->{21101,1};
				7->{24400,2};
				10->{22000,2};
				15->{20300,2};
				20->{24105,2};
				25->{20301,2};
				30->{21801,2};
				35->{20302,1};
				40->{28801,1};
				45->{24401,1};
				50->{28802,1};
				55->{22007,1};
				60->{21600,1};
				_->{0,0}
			end
	end.

%%测试
gmcmd_add_days(PlayerId,Days)->
	case select_award(PlayerId) of
		[]->skip;
		[Award]->
			NewAward= Award#ets_login_award{days=Days},
			update_award(NewAward),
			db_agent:update_login_award([{days,Days}],[{pid,PlayerId}])
	end.
%%修改登陆时间
gmcmd_change_login(PlayerId)->
	case select_award(PlayerId) of
		[]->skip;
		[Award]->
			NewAward= Award#ets_login_award{time=0},
			update_award(NewAward),
			db_agent:update_login_award([{time,86400,sub}],[{pid,PlayerId}])
	end.

%%成为充值玩家
gmcmd_bacome_rmb(PlayerId)->
	db_agent:test_charge_insert(PlayerId).

%%变成非R
gmcmd_bacome_un_rmb(PlayerId)->
	db_agent:test_delete_charge(PlayerId).