%% Author: hxming
%% Created: 2011-5-11
%% Description: TODO: 远古情缘
-module(lib_love).

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

%%获取刷新时间CD
check_refresh(PlayerId)->
	case select_love(PlayerId) of
		[]->{ok,180,[]};
		[Love]->
			NowTime = util:unixtime(),
			Invite = case Love#ets_love.be_invite of
								[]->[];
								undefined->[];
								_->Love#ets_love.be_invite
							end,
			if Love#ets_love.refresh > NowTime->
				   
				   {ok,Love#ets_love.refresh-NowTime,Invite};
			   true->{ok,0,Invite}
			end
	end.

%%刷新有缘人
refresh(PlayerStatus,Type)->
	case check_gold_refresh(PlayerStatus,Type) of
		false->{error,2};
		true->
			case select_love(PlayerStatus#player.id) of
				[]->{error,3};
				[Love]-> 
					NowTime = util:unixtime(),
					if Love#ets_love.refresh > NowTime andalso Type=/=1 ->
						   {error,4};
					   true->
						   Invitee = get_invitee(PlayerStatus#player.sex),
						   if Type =:= 1->
								  NewPlayer = lib_goods:cost_money(PlayerStatus,1,gold,3008),
								  NewLove = Love#ets_love{be_invite = Invitee},
								  db_agent:update_refresh_time(PlayerStatus#player.id,NewLove#ets_love.refresh,util:term_to_string(Invitee)),
								  update_love(NewLove);
							  true->
								  Timestamp = NowTime +180,
								  db_agent:update_refresh_time(PlayerStatus#player.id,Timestamp,util:term_to_string(Invitee)),
						  	 	  NewLove = Love#ets_love{refresh=Timestamp,be_invite = Invitee},
								  update_love(NewLove),
								  NewPlayer = PlayerStatus
						   end,
						   {ok,NewPlayer,Invitee,NewLove#ets_love.refresh-NowTime}
					end
			end
	end.

get_invitee(Sex)->
	%%根据不同的条件挑选玩家
	{Type,_}=tool:list_random([id,lv,exp,spirit,coin,cash,hp,mp,honor,culture]),
	PlayerList = db_agent:get_player_macth_status(Sex,Type),
%% 	io:format("PlayerList~p~n",[PlayerList]),
	case PlayerList of
		[]->[];
		_->random(PlayerList,[],0)
	end.

random(_PlayerList,RandomList,2)->
	RandomList;
random(PlayerList,RandomList,Times)->
	case PlayerList of
		[]->RandomList;
		_->
			{[Nickname,PlayerId,Career,Sex],NewPlayerList} = tool:list_random(PlayerList),
			case db_agent:check_invite_state(PlayerId) of
				[]->random(NewPlayerList,RandomList,Times);
				_->
					NewInfo = {Nickname,PlayerId,Career,Sex},
					random(NewPlayerList,[NewInfo|RandomList],Times+1)
			end
	end.

								   
check_invite(PlayerId)->
	case lib_player:get_online_info(PlayerId) of
		[]->{error,2};
		PlayerStatus->
			case catch gen_server:call(PlayerStatus#player.other#player_other.pid_love,{'check_invite',PlayerId}) of
				{ok,_}->{ok,1};
				{error,Error}->{error,Error};
				_->{error,2}
			end
	end. 


%%邀请有缘人
%%1成功，2元宝不足，3玩家不存在，4玩家不在线，5玩家等级不足30级，6今天约会次数已满2次，
%%7玩家正在约会中,8玩家性别不匹配，9不能邀请自己，10数据异常,11，不是好友，不能邀请12亲密度不足10 ，不能邀请
invite(PlayerStatus,InviteName,InviteType)->
%% 	io:format("invite/~s/~p/~n",[InviteName,InviteType]),
	case check_gold(PlayerStatus,InviteType) of
		false->
			{error,2};
		true->
			case check_my_status(PlayerStatus#player.id) of
				{error,ErrorCode}->
					{error,ErrorCode};
				{ok,_}->
					case lib_player:get_role_id_by_name(InviteName) of
						null->{error,3};
						[]->{error,3};
						InviteId->
							case check_close(PlayerStatus#player.id,InviteId,InviteType) of
								{error,Err}->{error,Err};
								_->
									case lib_player:get_online_info(InviteId) of
										[]->{error,4};
										Invite->
											if Invite#player.lv >= 30->
												   case PlayerStatus#player.sex =/= Invite#player.sex of
													   true->
										   				if PlayerStatus#player.id =/= Invite#player.id ->
														  		case  gen_server:call(Invite#player.other#player_other.pid_love,{'invite',Invite#player.id}) of
													   				{ok,_}->
																		pp_task:handle(30804,Invite,[PlayerStatus#player.id,
																									 PlayerStatus#player.nickname,
																									 PlayerStatus#player.career,
																									 PlayerStatus#player.sex,InviteType]),
																		{ok,1};
											  						 {error,Error}->
																		 {error,Error};
															   		_->
																		{error,10}
														  		 end;
															  true->{error,9}
														   end;
													   false->{error,8}
												   end;
											   true->{error,5}
											end
									end
							end
					end
			end
	end.

%%检查邀请人当前状态
check_my_status(PlayerId)->
	case select_love(PlayerId) of
		[]->{error,10};
		[Love]->
			if Love#ets_love.status =:= 0 ->
				   {ok,1};
			   true->
				   case util:unixtime() > Love#ets_love.duration  of
					   true->
						  {ok,1};
					   false->
						   {error,7}
				   end
			end
	end.

%%检查被邀请人数据
check_invitee(PlayerId)->
	case select_love(PlayerId) of
		[]->{error,10};
		[Love] ->
			NowTime = util:unixtime(),
			case check_invitee_status(Love,NowTime) of
				{error,ErrorCode}->{error,ErrorCode};
				{ok,NewLove}->
					case check_invitee_times(NewLove,NowTime) of
						{error,ErrorCode1}->
							if Love=/=NewLove->
								   update_love(NewLove);
							   true->skip
							end,
							{error,ErrorCode1};
						{ok,NewLove1}->
							if NewLove1=/=Love->
								   update_love(NewLove1);
							   true->skip
							end,
							{ok,1}
					end
			end
	end.

%%检查被邀请人状态
check_invitee_status(Love,NowTime)->
	if Love#ets_love.status =:= 0 ->
		   {ok,Love};
	   true->
		   if NowTime > Love#ets_love.duration ->
				  db_agent:reset_invite_state(Love#ets_love.pid),
				  {ok,Love#ets_love{status=0,duration=0,mult=1}};
			  true->
				  {error,7}
		   end
	end.

%%检查被邀请人邀请次数 
check_invitee_times(Love,NowTime)->
	case check_new_day(Love#ets_love.timestamp,NowTime) of
		true->
			if Love#ets_love.times >=2 ->
				   {error,6};
			   true->{ok,Love}
			end;
		false->
			db_agent:update_invite_times(Love#ets_love.pid,NowTime,util:term_to_string(Love#ets_love.be_invite)),
			{ok,Love#ets_love{times=0,timestamp=NowTime}}
	end.

%%检查元宝值
check_gold(PlayerStatus,InviteType)->
	case InviteType of
		1->  goods_util:is_enough_money(PlayerStatus,30,gold);
		_->true
	end.
check_gold_refresh(PlayerStatus,Type)->
	case Type of
		1->  goods_util:is_enough_money(PlayerStatus,1,gold);
		_->true
	end.

%%检查亲密度
check_close(IdA,IdB,Type)->
	case Type of
		3->
			lib_relationship:check_close(IdA,IdB,16000);
		_->ok
	end.

%%扣除元宝
del_invite_gold(PlayerStatus,Gold)->
	NewPlayer = lib_goods:cost_money(PlayerStatus,Gold,gold,3009),
	{ok,NewPlayer}.

%%接受/拒绝邀请(1接受，2拒绝)
accept_invite(PlayerStatus,InviteId,Result,Type)->
	case lib_player:get_online_info(InviteId) of
		[]->{error,2};
		Invite->
			case gen_server:call(Invite#player.other#player_other.pid_task,{'get_one_trigger',Invite#player.id,83000}) of
				false->
					error;
				true->
					case check_status(Invite,PlayerStatus,Type,Result) of
						ok->
							case Result of
								1->invite_ok_msg(Invite,PlayerStatus);
								_->refuse_invite_msg(Invite,PlayerStatus#player.nickname)
							end,
							{ok,Invite};
						_->error
					end;
				_->error
			end
	end.

check_status(Invite,PlayerStatus,Type,Result)->
	case Result of
		2->ok;
		_->
			case Type of
				1->
					case goods_util:is_enough_money(Invite,30,gold)of
						true->
							gen_server:cast(Invite#player.other#player_other.pid,{'del_gold_close',PlayerStatus#player.id,Type}),
							ok;%%扣除元宝
						false->error
					end;
				2->ok;%%普通邀请
				3->%%扣除亲密度
					case lib_relationship:del_close(PlayerStatus#player.id,Invite#player.id,10,30805) of
						ok->
							gen_server:cast(Invite#player.other#player_other.pid,{'del_gold_close',PlayerStatus#player.id,Type}),
							close_msg(PlayerStatus,Invite),
							ok;
						_->error
					end;
				_->error
			end
	end.

%%取消邀请
cancel_invite(PlayerId,Name)->
	case lib_player:get_online_info(PlayerId) of
		[]->{error,2};
		Player->
			cancel_invite_msg(Player,Name),
			{ok,Player}
	end.

%%赠送礼物(1成功，2数据异常，3铜币不足，4元宝不足，5玩家不在线6没有接任务7玩家等级不足，
%%8玩家性别不匹配9玩家正在约会中，10玩家今天约会次数已满,11不能赠送给自己，12场景不符合)
%% Todo 场景id欠缺
present_gift(PlayerStatus,InviteId,Mult)->
	case lists:member(Mult,[1,2]) of
		false->{error,2};
		true->
			case PlayerStatus#player.id =:= InviteId of
				true->{error,11};
				false->
					case check_task(PlayerStatus#player.id) of
						{error,Error2}->{error,Error2};
						_->
							case check_money(PlayerStatus,Mult) of
								{error,Error1}->{error,Error1};
								_->
									case check_my_status(PlayerStatus#player.id) of
										{error,ErrorCode}->
											case ErrorCode of
												10->{error,2};
												_->{error,9}
											end;
										{ok,_}->
											case lib_player:get_online_info(InviteId) of
												[]->{error,5};
												Invitee->
													if Invitee#player.lv >= 30->
														   if Invitee#player.sex =/= PlayerStatus#player.sex->
																  if Invitee#player.scene =/= ?LOVE_SCENE orelse PlayerStatus#player.scene =/= ?LOVE_SCENE->
																		 give_gift_fail(PlayerStatus),
																		 {error,12};
																	 true->
																		case  gen_server:call(Invitee#player.other#player_other.pid_love,{'invite',Invitee#player.id}) of
													   						{ok,_}->
																				%% 扣除礼物所需元宝或者铜板
																				NewPlayerStatus = del_goods_money(PlayerStatus,Mult),
																				%%开启经验共享定时器
																				start_share_timer(NewPlayerStatus,Invitee,Mult),
																				%%初始化默契度测试
																				NewPlayerStatus1=init_answer(NewPlayerStatus,Invitee),
																				%%共享鲜花
																				share_flower(NewPlayerStatus1),
																				%%完成仙侣情缘提示
																				finish_msg(NewPlayerStatus1,Invitee),
																				%%赠送礼物提示
																				gift_gift_ok(NewPlayerStatus1,Invitee,Mult),
																				spawn(fun()->db_agent:log_invite(NewPlayerStatus1#player.id,InviteId,Mult,util:unixtime())end),
																				%%完成仙侣情缘任务
																				lib_task:event(love,null,NewPlayerStatus1),
																				%%与爱侣完成仙侣情愿任务
																				case tool:to_list(NewPlayerStatus1#player.couple_name) ==Invitee#player.nickname of
																					true->
																						lib_task:event(lover_task,Invitee#player.nickname,NewPlayerStatus1),
																						lib_task:event(lover_task,NewPlayerStatus1#player.nickname,Invitee);
																				   false->skip
																				end,
																				%%七夕活动礼包接口 
%% 																				holiday_bag(NewPlayerStatus1),
																				%%成就系统统计接口
																				erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(Invitee#player.other#player_other.pid, 617, [1]))end),
																				erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(NewPlayerStatus1#player.other#player_other.pid, 615, [1]))end),
																				{ok,NewPlayerStatus1};
											  				 				{error,Error3}->
																					case Error3 of
																						6->{error,10};
																						7->{error,9};
																						_->{error,2}
																					end;
													   						_->{error,2}
																		end
												  		 			end;
															 true->{error,8}
														 end;
											 		 true->{error,7}
													end
											end
									end
							end
					end
			end
	end.

%%Todo 任务
check_task(PlayerId)->
	case lib_task:get_one_trigger(83000, PlayerId) of
		false->{error,6};
		_->{ok,1}
	end.

check_money(PlayerStatus,Type)->
	case Type of 
		1->
			case goods_util:is_enough_money(PlayerStatus,20000,coin) of
				false->{error,3};
				true->{ok,1}
			end;
		_->
			case goods_util:is_enough_money(PlayerStatus,15,gold) of
				false->{error,4};
				true->{ok,1}
			end
	end.

%%赠送礼物所需金钱
del_goods_money(PlayerStatus,Type)->
	case Type of
		1->
			give_gift_msg(PlayerStatus,Type,20000),
			lib_goods:cost_money(PlayerStatus,20000,coin,3010);
		_->
			give_gift_msg(PlayerStatus,Type,15),
			lib_goods:cost_money(PlayerStatus,15,gold,3010)
	end.

%%初始化共享经验
init_share_exp(Pid_Send,Love)->
	NowTime = util:unixtime(),
	if Love#ets_love.status > 0 andalso Love#ets_love.duration > NowTime ->
		   RemainTime = Love#ets_love.duration - NowTime,
		   share_exp_time(Pid_Send,RemainTime),
		   {ok,RemainTime};
	   true->skip
	end.

%%开启共享经验定时器，
start_share_timer(PlayerStatus,Invitee,Mult)->
	InviteData = [Invitee#player.id,Invitee#player.nickname,Invitee#player.career,Invitee#player.sex],
	PlayerData = [PlayerStatus#player.id,PlayerStatus#player.nickname,PlayerStatus#player.career,PlayerStatus#player.sex],
	gen_server:cast(PlayerStatus#player.other#player_other.pid_love,{start_share_exp,PlayerStatus,Mult,InviteData,1}),
	gen_server:cast(Invitee#player.other#player_other.pid_love,{start_share_exp,Invitee,Mult,PlayerData,2}),
	ok.

%%开始共享经验
start_share_exp(PlayerStatus,Mult,Type,InviteData)->
	case select_love(PlayerStatus#player.id) of
		[]->skip;
		[Love]->
			NowTime = util:unixtime()+base_time(),
			case Type of
				1->
					NewLove = Love#ets_love{status=1,duration=NowTime,mult=Mult,invitee=InviteData};
				_->
					Times = Love#ets_love.times+1,
					NewLove = Love#ets_love{status=1,duration=NowTime,mult=Mult,times = Times,invitee=InviteData}
			end,
			update_love(NewLove),
			db_agent:update_invite_state_and_times(PlayerStatus#player.id,1,NowTime,Mult,NewLove#ets_love.times,util:term_to_string(InviteData)),
			share_exp_time(PlayerStatus#player.other#player_other.pid_send,base_time())
	end.

%%共享经验
share_exp(PlayerStatus)->
	case select_love(PlayerStatus#player.id) of
		[]->skip;
		[Love]->
			if Love#ets_love.status > 0->
				   NowTime = util:unixtime(),
				   if Love#ets_love.duration > NowTime ->
						  if PlayerStatus#player.scene =:= ?LOVE_SCENE ->
								get_share_award(PlayerStatus,Love#ets_love.mult);
							 true->skip
						  end,
						  ok;
					  true->
						  NewLove = Love#ets_love{status=0,duration=0},
						  update_love(NewLove),
						  db_agent:reset_invite_state1(PlayerStatus#player.id),
						  share_exp_time(PlayerStatus#player.other#player_other.pid_send,0),
						  evaluate_tips(PlayerStatus,Love#ets_love.invitee),
						  get_share_award(PlayerStatus,Love#ets_love.mult),
						  skip
				   end;
			   true->skip
			end
	end.

get_share_award(PlayerStatus,Mult)->
	{Exp,Spt} = base_exp_spt(PlayerStatus#player.lv,Mult),
	gen_server:cast(PlayerStatus#player.other#player_other.pid,{'love_share_exp',Exp,Spt}).
%% 	NewPlayer = lib_player:add_exp(PlayerStatus,Exp, 0, 0),
%% 	NewPlayer_1 = lib_player:add_spirit(NewPlayer,Spt),
%% 	ValueList = [{spirit,Spt,add}],
%% 	WhereList = [{id, NewPlayer_1#player.id}],
%% 	db_agent:mm_update_player_info(ValueList, WhereList),
%% 	mod_player:save_online(NewPlayer_1),
%% 	gen_server:cast(NewPlayer_1#player.other#player_other.pid, {'SET_PLAYER', [{spirit,NewPlayer_1#player.spirit},
%% 																			   {lv,NewPlayer_1#player.lv},
%% 																			   {exp,NewPlayer_1#player.exp}
%% 																			   ]}),
	

share_exp_time(Pid_Send,Timestamp)->
	{ok, BinData} = pt_30:write(30807, [Timestamp]),
	lib_send:send_to_sid(Pid_Send,BinData).

share_flower(PlayerStatus)->
	{ok,BinData2} = pt_30:write(30809,[120]),
	mod_scene_agent:send_to_area_scene(PlayerStatus#player.scene,PlayerStatus#player.x,PlayerStatus#player.y, BinData2).

base_exp_spt(Lv,Mult)->
	%%每15S获得经验=[(lv/4)^4.9]/60;
	%%灵力=经验*1.5
	Exp = round(math:pow(Lv/4,4.9)/24*Mult),
	Spt = round(Exp*1.5),
	{Exp,Spt}.

base_time()->
	120.

base_task_award(Lv)->
	if Lv < 39 -> {50000,75000};
	   Lv < 49 -> {75000,112500};
	   Lv < 59 -> {100000,150000};
	   Lv < 69 -> {200000,300000};
	   Lv < 79 -> {400000,600000};
	   Lv < 89 -> {700000,1050000};
	   true -> {1000000,1500000}
	end.
%%Msg
invite_msg_gold(PlayerStatus,Gold)->
	%%你使用情有独钟功能，花费30元宝
	Msg = io_lib:format("你使用情有独钟功能，花费 ~p元宝", [Gold]),
	{ok,MyBin} = pt_15:write(15055,[Msg]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin).

accept_invite_msg(PlayerStatus)->
 	%%您收到了神秘的约会邀请！
	Msg= "您收到了神秘的约会邀请！",
%% 	NewStatus = PlayerStatus#player{other = PlayerStatus#player.other#player_other{love_invited = 1}},
	put(sex_change_invited,1),
	{ok,MyBin} = pt_15:write(15055,[Msg]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin).

refuse_invite_msg(PlayerStatus,Name)->
	%%今天天气不好，静菱不愿与您一起前去约会！
	Msg = io_lib:format("今天天气不好，~s不愿与您一起前去约会！",[Name]),
	case lib_player:get_player_pid(PlayerStatus#player.id) of
		[] ->skip;
		Pid ->gen_server:cast(Pid,{'sex_change_reset_invited'})
	end,
	{ok,MyBin} = pt_15:write(15055,[Msg]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin).

cancel_invite_msg(PlayerStatus,Name)->
	%%眩目取消了与您的的约会行程！
	Msg = io_lib:format("~s取消了与您的约会行程！",[Name]),
	case lib_player:get_player_pid(PlayerStatus#player.id) of
		[] ->skip;
		Pid ->gen_server:cast(Pid,{'sex_change_reset_invited'})
	end,
	{ok,MyBin} = pt_15:write(15055,[Msg]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin).

invite_ok_msg(PlayerStatus,Invitee)->
	%%您同意與【XXX】一起完成仙侶情緣緣任務，請前往天涯海角處尋找TA。
	%%【XXX】同意了您的邀請，請您在天涯海角等待TA的到來。
%% 	NewStatus = Invitee#player{other = Invitee#player.other#player_other{love_invited = 0}},
	Msg = io_lib:format("您同意与【~s】一起完成仙侣情缘任务，请前往天涯海角处寻找TA",[PlayerStatus#player.nickname]),
	{ok,MyBin} = pt_15:write(15055,[Msg]),
	lib_send:send_to_sid(Invitee#player.other#player_other.pid_send,MyBin),
	case lib_player:get_player_pid(Invitee#player.id) of
		[] ->skip;
		Pid ->gen_server:cast(Pid,{'sex_change_reset_invited'})
	end,
	Msg1 = io_lib:format("【~s】同意了您的邀请，请您在天涯海角等待TA的到來。",[Invitee#player.nickname]),
	{ok,MyBin1} = pt_15:write(15055,[Msg1]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin1).

give_gift_msg(PlayerStatus,Mult,Num)->
	%%赠送成功，花费了XX元宝/铜币。
	case Mult of
		1->
			Msg = io_lib:format("赠送成功，花费了~p铜币",[Num]);
		_->
		   Msg = io_lib:format("赠送成功，花费了 ~p元宝",[Num])
	end,
	{ok,MyBin} = pt_15:write(15055,[Msg]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin).

give_gift_fail(PlayerStatus)->
	%%赠送失败，请您耐心等待您的有缘人过来！
	Msg= "赠送失败，请您耐心等待您的有缘人过来！",
	{ok,MyBin} = pt_15:write(15055,[Msg]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin).

gift_gift_ok(PlayerStatus,Invitee,Type)->
	%%您获得了xxx送的【XXX】，春宵一刻值千金，请尽情的享受两分钟的二人世界吧！	
	%%您成功赠送了【XXX】给XXX，春宵一刻值千金，请尽情的享受两分钟的二人世界吧！
	Msg_a = io_lib:format("您获得了~s送的【~s】，春宵一刻值千金，请尽情的享受两分钟的二人世界吧！",[PlayerStatus#player.nickname,get_name_by_type(Type)]),
	{ok,MyBin} = pt_15:write(15055,[Msg_a]),
	lib_send:send_to_sid(Invitee#player.other#player_other.pid_send,MyBin),
	Msg_b = io_lib:format("您成功赠送了【~s】给~s，春宵一刻值千金，请尽情的享受两分钟的二人世界吧！",[get_name_by_type(Type),Invitee#player.nickname]),
	{ok,MyBin1} = pt_15:write(15055,[Msg_b]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin1),
	ok.
	
close_msg(PlayerStatus,Invite)->
	%%B同意了您的邀请，各消耗10亲密度
	Msg = io_lib:format("您接受 了【~s】的邀请，消耗10亲密度",[Invite#player.nickname]),
	{ok,MyBin} = pt_15:write(15055,[Msg]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin),
	
	Msg1 = io_lib:format("~s接受 了您的邀请，消耗10亲密度",[PlayerStatus#player.nickname]),
	{ok,MyBin1} = pt_15:write(15055,[Msg1]),
	lib_send:send_to_sid(Invite#player.other#player_other.pid_send,MyBin1),
	ok.

get_name_by_type(Type)->
	case Type of
		1->"鸳鸯镯";
		_->"天使之泪"
	end.

finish_msg(PlayerStatus,Invitee)->
	%%【传闻】 眩目与静菱在天涯海角红娘的见证下，完成♥远古奇缘♥任务，共渡了一段美好♥浪漫时光♥
	Msg = io_lib:format("[<a href='event:1,~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>]与[<a href='event:1,~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>]在天涯海角红娘的见证下，完成仙侣情缘任务，共渡了一段美好♥浪漫时光♥",[PlayerStatus#player.id,PlayerStatus#player.nickname,PlayerStatus#player.career,PlayerStatus#player.sex,PlayerStatus#player.nickname,Invitee#player.id,Invitee#player.nickname,Invitee#player.career,Invitee#player.sex,Invitee#player.nickname]),
	lib_chat:broadcast_sys_msg(6,Msg).

%%魅力值相关

%%发起评价
evaluate_tips(PlayerStatus,InviteData)->
%% 	io:format("evaluate_tips_~p/~p~n",[PlayerStatus#player.id,InviteData]),
	finish_share_flow(PlayerStatus,InviteData),
	{ok,MyBin} = pt_30:write(30812,InviteData),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin).

%%共享经验结束提示
finish_share_flow(PlayerStatus,InviteData)->
	%%春宵苦短，您与【XXXX】的浪漫时光已经结束了
	case InviteData of
		[]->skip;
		[_,Name,_,_]->
			Msg_b = io_lib:format("春宵苦短，您与【~s】的浪漫时光已经结束了",[Name]),
			{ok,MyBin1} = pt_15:write(15055,[Msg_b]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin1)
	end.
	
%%评价以及赠送鲜花(1成功，2玩家不在线，3没有鲜花，4该玩家不是和您在约会，5数据异常)
evaluate(PlayerStatus,InviteId,App,Flower)->
%% 	?DEBUG("lib_love_______________evaluate flower_____________",[]),
	case lib_player:get_online_info(InviteId) of
		[]->{error,2};
		Invitee->
			{Charm,FlowerId}=get_folwer(Flower),
			%%检查鲜花数量
			case FlowerId > 0  of
				true->
					case  goods_util:get_goods_num(PlayerStatus#player.id, FlowerId,4) >= 1 of
						true->
							GoodsInfo = goods_util:get_type_goods_info(PlayerStatus#player.id,FlowerId,4),
							 case send_evaluate(Invitee,PlayerStatus,App,Flower,Charm) of
								 {ok,1}->
									gen_server:cast(PlayerStatus#player.other#player_other.pid_goods,
										{'usefestivaltool_15054',PlayerStatus,GoodsInfo#goods.id,1,Invitee#player.nickname}),
									{ok,1};
								 Other->
									 Other
							end;
						false->{error,3}
					end;
				false->
					send_evaluate(Invitee,PlayerStatus,App,Flower,Charm)
			end
	end.

send_evaluate(Invitee,PlayerStatus,App,Flower,Charm)->
	case gen_server:call(Invitee#player.other#player_other.pid_love,{'evaluate',
																	 Invitee,
																	 PlayerStatus#player.id,
																	 PlayerStatus#player.nickname,
																	 PlayerStatus#player.career,
																	 PlayerStatus#player.sex,
																	 App,Flower,Charm}) of
		{ok,1}->{ok,1};
		{error,Error}->{error,Error};
		_->{error,5}
	end.

%%检查评价
check_evaluate(Invitee,PlayerId,Nickname,Career,Sex,App,Flower,Charm)->
	case select_love(Invitee#player.id) of
		[]->{error,5};
		[Love]->
			case Love#ets_love.invitee of
				undefined->{error,4};
				[]->{error,4};
				_->
					[InviteId|_]=Love#ets_love.invitee,
					if InviteId =/= PlayerId->
				   		{error,4};
			   		true->
				   		pp_task:handle(30811,Invitee,[PlayerId,Nickname,Career,Sex,App,Flower,Charm]),
				   		{ok,1}
					end
			end
	end.

%%得到评价,增加魅力值
get_evaluate(PlayerStatus,Charm)->
	case Charm of
		0->PlayerStatus;
		_->
			add_charm(PlayerStatus,Charm)
	end.

get_folwer(Type)->
	case Type of
		1->{9,28018};
		2->{99,28019};
		3->{999,28020};
		_->{0,0}
	end. 

%%获取魅力值
get_charm(PlayerId)->
	case select_love(PlayerId) of
		[]->0;
		[Love]->Love#ets_love.charm
	end.

%%检查魅力值是否足够
check_charm_is_enough(PlayerId,Charm)->
	case get_charm(PlayerId) of
		0->false;
		C->
			C>=Charm
	end.

%%增加魅力值
add_charm(PlayerStatus,Charm)->
	case select_love(PlayerStatus#player.id) of
		[]->PlayerStatus;
		[Love]->
			NewCharm = Charm+Love#ets_love.charm,
			NewLove = Love#ets_love{charm=NewCharm},
			update_love(NewLove),
			db_agent:update_charm(PlayerStatus#player.id,NewCharm),
			NewPlayerStatus = PlayerStatus#player{
						  other = PlayerStatus#player.other#player_other{
                           		charm = NewCharm
								}
                    		},
			mod_player:save_online_diff(PlayerStatus,NewPlayerStatus),
			lib_player:send_player_attribute(NewPlayerStatus, 1),
			%%成就系统统计接口
			if NewCharm >=20 andalso NewCharm < 1314->
				   erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerStatus#player.other#player_other.pid, 612, [20]))end);
			   NewCharm >=1314 andalso NewCharm < 3344->
				   erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerStatus#player.other#player_other.pid, 613, [1314]))end);
			   NewCharm >=3344->
				   erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PlayerStatus#player.other#player_other.pid, 614, [3344]))end);
			   true->skip
			end,
			NewPlayerStatus
	end.

%%扣除魅力值
del_charm(PlayerStatus,Charm)->
	case select_love(PlayerStatus#player.id) of
		[]->PlayerStatus;
		[Love]->
			case Love#ets_love.charm >= Charm  of
				false->PlayerStatus;
				true->
					NewCharm = Love#ets_love.charm-Charm,
					NewLove = Love#ets_love{charm=NewCharm},
					update_love(NewLove),
					db_agent:update_charm(PlayerStatus#player.id,NewCharm),
					PlayerStatus#player{other = PlayerStatus#player.other#player_other{
                           		charm = NewCharm }}
			end
	end. 

%%魅力值兑换，获得头衔(2需要兑换的称号信息有误，3这个称号不适用您的性别，换一个吧，4魅力值不足)
convert_charm(PlayerStatus,Title)->
	case base_title_info(Title) of
		error->{error,2};
		{Sex,Charm,Timestamp,Day,TitleName}->
			if PlayerStatus#player.sex =/= Sex ->
				   {error,3};
			   true->
				   case check_charm_is_enough(PlayerStatus#player.id,Charm) of
					   false->{error,4};
					   true->
						   Player = del_charm(PlayerStatus,Charm),
%% 						   NewPlayerStatus = set_title(Player,Title,Timestamp),
						   NewPlayerStatus = lib_achieve_outline:claim_love_title(Title, Player, Timestamp),
%% 						   bc_title_in_scene(PlayerStatus,Title),
						   sys_msg_title(PlayerStatus,TitleName),
						   mail(PlayerStatus,Day,TitleName),
						   spawn(fun()->db_agent:log_convert_charm(PlayerStatus#player.id,Title,Charm,util:unixtime())end),
						   {ok,NewPlayerStatus}
				   end
			end
	end.

%%魅力兑换物品(1兑换成功，2数据异常，3魅力值不足，4系统繁忙，稍后重试，5背包空间不足,6活动已结束)
convert_goods(PlayerStatus,Type)->
	NowTime = util:unixtime(),
	if ?HOLIDAY_START =< NowTime andalso NowTime =< ?HOLIDAY_END->
		   case type_to_goods(Type) of
			   {}->{PlayerStatus,2};
			   {Charm,Award}->
				   case check_charm_is_enough(PlayerStatus#player.id,Charm) of
					   false->{PlayerStatus,3};
						true->
							case get_goods(Type,PlayerStatus,Award) of
								{NewPlayer,1}->
									Player = del_charm(NewPlayer,Charm),
									spawn(fun()->db_agent:log_convert_charm(PlayerStatus#player.id,Type,Charm,util:unixtime())end),
									{Player,1};
								{NewPlayer1,Error}->{NewPlayer1,Error}
							end
				   end
			end;
	   true->
		   {PlayerStatus,6}
	end.

get_goods(1,PlayerStatus,Award)->
	{GoodsId,Num} = Award,
	case gen_server:call(PlayerStatus#player.other#player_other.pid_goods,{'cell_num'})< 1 of
		false->
			case ( catch gen_server:call(PlayerStatus#player.other#player_other.pid_goods,
										 {'give_goods', PlayerStatus,GoodsId, Num,2})) of
				ok -> 
					{PlayerStatus,1};
				_->{PlayerStatus,4}
			end;
		true->{PlayerStatus,5}
	end;
get_goods(2,PlayerStatus,Award)->
	{Cul} = Award,
	NewPlayer = lib_player:add_culture(PlayerStatus,Cul),
		ValueList = [{culture,Cul,add}],
	WhereList = [{id, PlayerStatus#player.id}],
	spawn(fun()->catch(db_agent:mm_update_player_info(ValueList, WhereList))end),
	{NewPlayer,1};
get_goods(3,PlayerStatus,Award)->
	{Exp,Spt}=Award,
	NewPlayer = lib_player:add_exp(PlayerStatus,Exp,Spt,20),
	{NewPlayer,1}.


type_to_goods(Type)->
	case Type of
		1->{500,{21500,4}};
		2->{100,{3000}};
		3->{20,{20000,10000}};
		_->{}
	end.
%% %%设置头衔
%% set_title(PlayerStatus,Title,Timestamp)->
%% 	NowTime = util:unixtime(),
%% 	EndTime = round(NowTime+Timestamp),
%% 	case PlayerStatus#player.other#player_other.charm_title of
%% 		0->
%% 			update_title(PlayerStatus,Title,EndTime);
%% 		OldTitle->
%% 			case OldTitle =:= Title of
%% 				true->
%% 					OldTime = PlayerStatus#player.other#player_other.charm_title_time,
%% 					update_title(PlayerStatus,Title,OldTime+Timestamp);
%% 				false->
%% 					update_title(PlayerStatus,Title,EndTime)
%% 			end
%% 	end.

%% update_title(PlayerStatus,Title,Timestamp)->
%% 	db_agent:update_title(PlayerStatus#player.id,Title,Timestamp),
%% 	PlayerStatus#player{other = PlayerStatus#player.other#player_other{
%%                            		charm_title = Title,charm_title_time=Timestamp
%% 								}
%%                     		}.
%% %%检查头衔
%% check_title_state(PlayerStatus)->
%% 	case PlayerStatus#player.other#player_other.charm_title of
%% 		0->PlayerStatus;
%% 		_Title->
%% 			NowTime = util:unixtime(),
%% 			case NowTime>PlayerStatus#player.other#player_other.charm_title_time of
%% 				true->
%% 					mod_vip:send_title_mail(PlayerStatus,PlayerStatus#player.other#player_other.charm_title,2),
%% 					db_agent:update_title(PlayerStatus#player.id,0,0),
%% 					bc_title_in_scene(PlayerStatus,0),
%% 					PlayerStatus#player{
%% 						  other = PlayerStatus#player.other#player_other{
%%                            		charm_title = 0,charm_title_time=0
%% 								}
%%                     		};
%% 				false->
%% 					if PlayerStatus#player.other#player_other.charm_title_time - NowTime < 86400->
%% 						   mod_vip:send_title_mail(PlayerStatus,PlayerStatus#player.other#player_other.charm_title,1);
%% 						true->skip
%% 					end,
%% 					PlayerStatus
%% 			end
%% 	end.

%%加载头衔
load_title(PlayerStatus)->
%% 	{Charm,Title,Timestamp,PrivityInfo} = case select_love(PlayerStatus#player.id) of
%% 								  []->{0,0,0,[]};
%% 								  [Love]->
%% 									  case Love#ets_love.title of
%% 										  0->{Love#ets_love.charm,0,0,Love#ets_love.privity_info};
%% 										  _T->
%% 											  NowTime = util:unixtime(),
%% 											  case NowTime >Love#ets_love.title_time of
%% 												  false->
%% 													  if Love#ets_love.title_time - NowTime < 86400->
%% 															 spawn_link(fun()->mod_vip:send_title_mail(PlayerStatus,Love#ets_love.title,1)end);
%% 														 true->skip
%% 													  end,
%% 													  {Love#ets_love.charm,Love#ets_love.title,Love#ets_love.title_time,Love#ets_love.privity_info};
%% 												  true->
%% 													  spawn_link(fun()->
%% 													  		mod_vip:send_title_mail(PlayerStatus,Love#ets_love.title,2),
%% 													  		db_agent:update_title(PlayerStatus#player.id,0,0)
%% 												  	  end),
%% 													  {Love#ets_love.charm,0,0,Love#ets_love.privity_info}
%% 											  end
%% 									  end
%% 							  end,
	Charm = case select_love(PlayerStatus#player.id) of
				[]->0;
				[Love]->Love#ets_love.charm
			end,
	PlayerStatus#player{
						other = PlayerStatus#player.other#player_other{
                           		charm=Charm
								}
                    		}.
%%称号到期邮件
title_mail(PlayerStatus,Type)->
	NameList = [tool:to_list(PlayerStatus#player.nickname)],
	case Type of
		1->
			Content = "亲爱的玩家，您的魅力值称号使用期限将到！在以后的时间里，希望您能得到更多玩家的亲睐，成为远古封神的人气王！";
		2->
			Content = "亲爱的玩家，您的魅力值称号已经过期！在以后的时间里，希望您能得到更多玩家的亲睐，成为远古封神的人气王！"
	end,
	mod_mail:send_sys_mail(NameList, "魅力称号", Content, 0,0, 0, 0, 0).

mail(PlayerStatus,Day,TitleName)->
	NameList = [tool:to_list(PlayerStatus#player.nickname)],
	Content =io_lib:format( "尊贵的远古封神玩家，恭喜您获得~s称号，有效期为~p天，祝您游戏愉快！",[TitleName,Day]),
	mod_mail:send_sys_mail(NameList, "魅力称号", Content, 0,0, 0, 0, 0).

%%兑换魅力称号系统通告
sys_msg_title(PlayerStatus,TitleName)->
	Msg = io_lib:format("玩家[<a href='event:1,~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>]魅力四射，获得<font color='#F8EF38'>【~s】</font>称号,成为远古封神的人气王！！！",[PlayerStatus#player.id,PlayerStatus#player.nickname,PlayerStatus#player.career,PlayerStatus#player.sex,PlayerStatus#player.nickname,TitleName]),
	lib_chat:broadcast_sys_msg(6,Msg).

%%场景广播称号
bc_title_in_scene(PlayerStatus,Titles)->
	{ok,BinData2} = pt_12:write(12043,[PlayerStatus#player.id,Titles]),
	mod_scene_agent:send_to_area_scene(PlayerStatus#player.scene,PlayerStatus#player.x,PlayerStatus#player.y, BinData2).

%%称号基础数据{性别，兑换所需魅力值，时间（秒），时间（天），称号}
base_title_info(Title)->
	case Title of
		28035->{1,520,round(5*24*3600),5,"人气王子"};
		28036->{2,520,round(5*24*3600),5,"人气宝贝"};
		28037->{1,1000,round(7*24*3600),7,"多情公子"};
		28038->{2,1000,round(7*24*3600),7,"魅力宝贝"};
		_->error
	end.

%默契度基础值
base_privity_value(Question)->
	case Question of
		11->5;
		10->5;
		9->5;
		_->10
	end.

%%初始化默契度测试
init_answer(PlayerStatus,Invitee)->
	QuestionList = random_question(10),
	NowTime = util:unixtime()+60,
	PtivityInfo1 = [PlayerStatus#player.id,NowTime,0,[],QuestionList],
	gen_server:cast(Invitee#player.other#player_other.pid,{'update_privity_info',PtivityInfo1,true,61}),
	gen_server:cast(PlayerStatus#player.other#player_other.pid,{'start_privity_test_timer',61}),
	PtivityInfo = [Invitee#player.id,NowTime,0,[],QuestionList],
	next_question(PlayerStatus,Invitee,1,1,60,0),
	update_privity(PlayerStatus,PtivityInfo).


%%答题(相互call玩家的数据，如果都选择了答案则进入下一题，否则就等待)
answer(PlayerStatus,Answer)->
%% 	io:format("answer_____~p~n",[Answer]),
	case PlayerStatus#player.other#player_other.privity_info of
		[]->PlayerStatus;
		PrivityInfo->
			%%[对手，时间，默契度，当前答案，[题库]]
%% 			io:format("answer_____1_~p~n",[PrivityInfo]),
			[InviteId,Timestamp,Privity,_Answer,Question] = PrivityInfo,
			NowTime = util:unixtime(),
			Qlen = length(Question), 
			case lib_player:get_online_info(InviteId) of
				[]->
					case NowTime-Timestamp>60 of
						false->
							if Qlen =:=10 andalso Answer =:="否"->
								   NewPlayerStatus = update_privity(PlayerStatus,[]),
								   {ok,BinData} = pt_30:write(30813,[2,0,0,0,0,<<>>,<<>>,<<>>,<<>>]),
									lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
								   give_up_msg(PlayerStatus),
									NewPlayerStatus; 
							   true->
									update_privity(PlayerStatus,[InviteId,Timestamp,Privity,Answer,Question])
							end;
						true->
							update_privity(PlayerStatus,[])
					end;
				Invitee->
					case Invitee#player.other#player_other.privity_info of
						[]->
							NewPlayerStatus = privity_award(PlayerStatus,Privity),
							update_privity(NewPlayerStatus,[]);
						[PlayerId,Timestamp,_Privity,Answer_Invite,_Question]->
							case Answer_Invite of
								[]->
									if Qlen =:=10 andalso Answer =:="否"->
										   NewPlayerStatus = update_privity(PlayerStatus,[]),
										   privity_end(PlayerStatus,Invitee),
										   gen_server:cast(Invitee#player.other#player_other.pid,{'update_privity_info',[],false,0}),
										   give_up_msg(PlayerStatus,Invitee),
										   NewPlayerStatus; 
							   		true->
										update_privity(PlayerStatus,[InviteId,Timestamp,Privity,Answer,Question])
									end;
								undefined->
									update_privity(PlayerStatus,[InviteId,Timestamp,Privity,Answer,Question]);
								_->
									
									BasePrivity = base_privity_value(Qlen),
%% 									io:format("answer_____4_~p_~p~n",[Qlen,BasePrivity]),
									 if Qlen=:= 10 andalso (Answer =:="否" orelse Answer_Invite =:= "否")->
%% 											io:format("answer_____5_~p~n",[1]),
											NewPlayerStatus = update_privity(PlayerStatus,[]),
											privity_end(PlayerStatus,Invitee),
								  		 	gen_server:cast(Invitee#player.other#player_other.pid,{'update_privity_info',[],false,0}),
											give_up_msg(PlayerStatus,Invitee),
										 	NewPlayerStatus; 
										Qlen >0->
%% 											io:format("answer_____6_~p~n",[1]),
											if Answer =:= Answer_Invite->
												   NewPrivity = Privity+BasePrivity;
											   true-> NewPrivity = Privity
											end,
%% 											io:format("answer_____6_~p~n",[3]),
											[QuestionId|QuestionRemain]=Question,
											NewPlayerStatus = update_privity(PlayerStatus,[InviteId,Timestamp,NewPrivity,[],QuestionRemain]),
								  		 	gen_server:cast(Invitee#player.other#player_other.pid,{'update_privity_info',[PlayerId,Timestamp,NewPrivity,[],QuestionRemain],false,0}),
										 	next_question(NewPlayerStatus,Invitee,Qlen+1,QuestionId,Timestamp-NowTime,Privity),
										 	NewPlayerStatus;
							 		  true->
%% 										  io:format("****************finish_answer_____7_~p~n",[1]),
										if Answer =:= Answer_Invite->
												   NewPrivity = Privity+BasePrivity;
											   true-> NewPrivity = Privity
											end,
										NewPlayerStatus = update_privity(PlayerStatus,[]),
										privity_finish(NewPlayerStatus,NewPrivity),
										privity_finish(Invitee,NewPrivity),
										privity_msg(PlayerStatus,Invitee,NewPrivity),
										gen_server:cast(Invitee#player.other#player_other.pid,{'privity_award',NewPrivity}),
								   		privity_award(NewPlayerStatus,NewPrivity)
									end
							end
					end
			end
	end.

%%出题
next_question(PlayerStatus,Invitee,Num,QuestionId,Timestamp,Privity)->
	case select_base_privity(QuestionId) of
		[]->
			skip;
		[Question]->
			{ok,BinData} = pt_30:write(30813,[0,Num,Timestamp,Privity,spirit(PlayerStatus#player.lv,Privity),Question#ets_base_privity.question,Question#ets_base_privity.a,Question#ets_base_privity.b,Question#ets_base_privity.c]),
			lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
			{ok,BinData1} = pt_30:write(30813,[0,Num,Timestamp,Privity,spirit(Invitee#player.lv,Privity),Question#ets_base_privity.question,Question#ets_base_privity.a,Question#ets_base_privity.b,Question#ets_base_privity.c]),
			lib_send:send_to_sid(Invitee#player.other#player_other.pid_send, BinData1)
	end.

%%测完完成
privity_finish(PlayerStatus,Privity)->
	{ok,BinData} = pt_30:write(30813,[1,0,0,Privity,spirit(PlayerStatus#player.lv,Privity),<<>>,<<>>,<<>>,<<>>]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData).

%%测试终止
privity_end(PlayerStatus,Invitee)->
	{ok,BinData} = pt_30:write(30813,[2,0,0,0,0,<<>>,<<>>,<<>>,<<>>]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
	{ok,BinData1} = pt_30:write(30813,[2,0,0,0,0,<<>>,<<>>,<<>>,<<>>]),
	lib_send:send_to_sid(Invitee#player.other#player_other.pid_send, BinData1).


%%更新测试信息
update_privity(PlayerStatus, PrivityInfo)->
	spawn(fun()-> db_agent:update_privity(PlayerStatus#player.id,util:term_to_string(PrivityInfo)) end),
	PlayerStatus#player{
		other = PlayerStatus#player.other#player_other{
			privity_info = PrivityInfo
		}
	}. 

%%测试奖励
privity_award(PlayerStatus, Privity)->
	Spirit = spirit(PlayerStatus#player.lv, Privity),
	spt_msg(PlayerStatus, Privity, Spirit),
%%     ?DEBUG("lib_love_______________love task Close = ~p_____________",[30*(Privity/100)]),
    spawn(fun()-> db_agent:mm_update_player_info([{spirit, Spirit, add}], [{id, PlayerStatus#player.id}]) end),
	lib_player:add_spirit(PlayerStatus, Spirit).

%%测试结果
spt_msg(PlayerStatus,Pri,Spt)->
	%%心有灵犀测试结束，您与TA的默契度是XX，您获得XXX灵力
	Msg = io_lib:format("心有灵犀测试结束，您与TA的默契度是~p，您获得~p灵力",[Pri,Spt]),
	{ok,MyBin} = pt_15:write(15055,[Msg]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin).

%%
privity_msg(PlayerStatus,Invitee,Privity)->
	if Privity>= 100->
		Msg = io_lib:format("身无彩凤双飞翼，心有灵犀一点通;[<a href='event:1,~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>]与[<a href='event:1,~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>]心心相印，他们的默契度为~p!!!",[PlayerStatus#player.id,PlayerStatus#player.nickname,PlayerStatus#player.career,PlayerStatus#player.sex,PlayerStatus#player.nickname,Invitee#player.id,Invitee#player.nickname,Invitee#player.career,Invitee#player.sex,Invitee#player.nickname,Privity]),
		%%情人节活动
		case lib_activities:is_lovedays_time(util:unixtime()) of
			true ->
				lib_activities:send_to_task_2(PlayerStatus#player.nickname),
				lib_activities:send_to_task_2(Invitee#player.nickname);
			false ->
				skip
		end,
		lib_chat:broadcast_sys_msg(6,Msg);
	   true->skip
	end,
	%%增加亲密度
	spawn(fun()->lib_relationship:close(love,PlayerStatus#player.id,Invitee#player.id,[round(30*(Privity/100)),PlayerStatus#player.other#player_other.pid_team,Invitee#player.other#player_other.pid_team])end).

%%放弃信息
give_up_msg(PlayerStatus,Invitee)->
	Content = "您放弃了心有灵犀测试",
	{ok,MyBin} = pt_15:write(15055,[Content]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin),

	Msg = io_lib:format("~s放弃了心有灵犀测试", [PlayerStatus#player.nickname]),
	{ok,MyBin1} = pt_15:write(15055,[Msg]),
	lib_send:send_to_sid(Invitee#player.other#player_other.pid_send,MyBin1).

give_up_msg(PlayerStatus)->
	Content = "您放弃了心有灵犀测试",
	{ok,MyBin} = pt_15:write(15055,[Content]),
	lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send,MyBin).


%%灵力奖励值
spirit(Lv,Privity)->
	round(math:pow(Lv,1.5)*Privity*3).
%%
%% Local Functions
%%

%%加载数据
init_love(PlayerId,Sex)->
	NowTime = util:unixtime(), 
	case db_agent:select_love(PlayerId) of
		[]->
			%插入新玩家数据
			BeInvite = get_invitee(Sex),
			{_,Id}=db_agent:new_love(PlayerId,NowTime,BeInvite),
			Data = [Id,PlayerId,0,0,0,0,1,0,NowTime,[],0,0,[],util:term_to_string(BeInvite),0,util:term_to_string([])],
			Love = match_ets(Data),
			update_love(Love),
			{ok,Love};
		Result ->
				NewData = check_invite_times(Result,NowTime,Sex),
				NewData1 = check_invite_state(NewData,NowTime),
				Love = match_ets(NewData1),
				update_love(Love),
				{ok,Love} 
	end.

match_ets(Data)->
	[Id,PlayerId,Charm,Refresh,Status,Duration,Mult,Times,Timestamp,InviteData,Title,TitleTime,PrivityInfo,BeInvitee,TaskTimes,TaskContent]= Data,
	EtsData = #ets_love{
							    id=Id,
      							pid = PlayerId,
								charm = Charm,
								refresh =Refresh,
								status=Status,
								duration = Duration,
								mult=Mult,
	  							times = Times,
								timestamp=Timestamp,
								invitee =  util:string_to_term(tool:to_list(InviteData)),
								title = Title,
								title_time = TitleTime,
								privity_info = util:string_to_term(tool:to_list(PrivityInfo)),
					   			be_invite = util:string_to_term(tool:to_list(BeInvitee)),
								task_times=TaskTimes,
								task_content = util:string_to_term(tool:to_list(TaskContent))
							},
	EtsData.


%%检查被邀请次数
check_invite_times(Data,NowTime,Sex)->
	[Id,PlayerId,Charm,Refresh,Status,Duration,Mult,_Times,Timestamp,InviteData,Title,TitleTime,PrivityInfo,_BeInvite,_TaskTimes,_TaskContent]= Data,
	case check_new_day(Timestamp,NowTime) of
		true->Data;
		false->
			NewBeInvite = util:term_to_string(get_invitee(Sex)),
			db_agent:update_invite_times(PlayerId,NowTime,NewBeInvite),
			[Id,PlayerId,Charm,Refresh,Status,Duration,Mult,0,NowTime,InviteData,Title,TitleTime,PrivityInfo,NewBeInvite,0,util:term_to_string([])]
	end.

%%检查被邀请状态
check_invite_state(Data,NowTime)->
	[Id,PlayerId,Charm,Refresh,Status,Duration,Mult,_Times,Timestamp,InviteData,Title,TitleTime,PrivityInfo,BeInvite,TaskTimes,TaskContent]= Data,
	if Status =:=0 ->
		   Data;
	   true->
		   case NowTime > Duration of
			   true->
				   db_agent:reset_invite_state(PlayerId),
				   [Id,PlayerId,Charm,Refresh,0,0,Mult,_Times,Timestamp,InviteData,Title,TitleTime,PrivityInfo,BeInvite,TaskTimes,TaskContent];
			   false->Data
		   end
	end.
%%检查第二天
check_new_day(Timestamp,NowTime)->
	NDay = (NowTime+8*3600) div 86400,
	ODay = (Timestamp+8*3600) div 86400,
	NDay=:=ODay.

update_love(Love)->
	ets:insert(?ETS_LOVE,Love).

select_love(PlayerId)->
	ets:lookup(?ETS_LOVE, PlayerId).

delete_love(PlayerId)->
	ets:delete(?ETS_LOVE, PlayerId).

offline(PlayerId)->
	delete_love(PlayerId).

%%初始化题库
init_base_privity()->
	  F = fun(Question) ->
			QuestionEts = list_to_tuple([ets_base_privity|Question]),
            ets:insert(?ETS_BASE_PRIVITY, QuestionEts)
           end,
	L = db_agent:get_base_privity(),
	lists:foreach(F, L),
    ok.

select_base_privity(Id)->
	ets:lookup(?ETS_BASE_PRIVITY,Id).

select_all()->
	ok.

random_question(Total)->
	[Count] = db_agent:count_base_privity(),
%% 	Count=2000,
	F = fun(List) ->
				RandomList1 =  util:filter_list(List,1,0),
				_RandomList2 = lists:sublist(RandomList1,Total)
		end,
	OrderSumList = F([util:rand(2,Count) || _SeqNum <- lists:seq(2, 200)]),
	OrderSumList.

%%仙侣情缘任务获得奖励
add_love_award(PlayerStatus)->
	{Exp,_Spt} = lib_love:base_task_award(PlayerStatus#player.lv),
	%%spawn(fun()->lib_relationship:team_close(Team#team.member,MonType,MonScene)end)
	lib_player:add_exp(PlayerStatus, Exp, 0,0).

%%七夕活动礼包,0806~0807
%%0806零点时间戳1312560000
%%0808零点时间戳1312732800
holiday_bag(PlayerStatus)->
	NowTime= util:unixtime(),
	case NowTime >=1312560000 andalso NowTime =< 1312732800 of
		true->
			NameList = [tool:to_list(PlayerStatus#player.nickname)],
			Title = "七夕情人节礼包",
			Content ="8月6日00:00-8月8日00:00期间，完成仙侣情缘任务获得精美的七夕礼包,助你打造梦幻紫戒。《远古封神》祝您有一个甜蜜的情人节！",
			mod_mail:send_sys_mail(NameList, Title, Content, 0, 28192, 1, 0,0);
		false->skip
	end.

%%检查仙侣任务次数
check_lover_task_times(PlayerId,MaxTimes)->
	case select_love(PlayerId) of
		[]->false;
		[Love]->
			NowTime = util:unixtime(),
			case check_new_day(Love#ets_love.timestamp,NowTime) of
				true->
					Love#ets_love.task_times < MaxTimes;
				false->
					NewLove = Love#ets_love{task_times=0,task_content = []},
					db_agent:update_love([{task_times,0},{task_content,[]}],[{pid,PlayerId}]),
					update_love(NewLove),
					true
			end
	end.

%%更新爱侣任务
update_lover_task(PlayerId,Content)->
	case select_love(PlayerId) of
		[]->
			util:get_random_list(Content,1);
		[Love]->
			{NewContent,TaskContent} = get_content(Content,Love#ets_love.task_content),
			NewLove = Love#ets_love{task_times=Love#ets_love.task_times+1,task_content = TaskContent},
			db_agent:update_love([{task_times,1,add},{task_content,util:term_to_string(TaskContent)}],[{pid,PlayerId}]),
			update_love(NewLove),
			NewContent
	end.

%%Content[0,0,kill,40104,16,0]
get_content(Content,TaskContent)->
	NewContent= util:get_random_list(Content,1),
	[[_,_,Type|_]] = NewContent,
	if TaskContent == undefined->
		   {NewContent,[Type]};
	   true->
			case length(TaskContent)>=4 of
				true->{NewContent,TaskContent};
				false->
					case lists:member(Type,TaskContent) of
						false->
							{NewContent,[Type|TaskContent]};
						true->
							case length(Content) == 1 of
								true->{NewContent,[Type|TaskContent]};
								false->
									get_content(Content,TaskContent)
							end
					end
			end
	end.
	
	
%%测试
%% add_charm(PlayerStatus,Charm)->ok.