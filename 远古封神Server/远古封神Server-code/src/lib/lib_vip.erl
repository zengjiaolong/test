%% Author: hxming
%% Created: 2011-3-7
%% Description: TODO: lib_vip模块
-module(lib_vip).

%%
%% Include files
%%

%%
%% Exported Functions
%%
-compile(export_all).

-include("common.hrl").
-include("record.hrl").

%%
%% API Functions
%%
%%查询是否vip
check_vip(PlayerStatus)->
	PlayerStatus#player.vip=/=0.

%%检查vip类型[1月卡，2季卡，3半年卡，4周卡,5一天卡，6体验卡]
check_vip_type(PlayerStatus)->
	case PlayerStatus#player.vip of
		1->{true,blue};
		2->{true,yellow};
		3->{true,purple};
		4->{true,green};
		5->{true,green};
		6->{true,green};
		_->{false,undefind}
	end.

%%获取vip类型和时间28600,28601,28602
get_vip_type(VipType)->
	case VipType of
		28600->{1,30*24*3600};
		28601->{2,3*30*24*3600};
		28602->{3,6*30*24*3600};
		28603->{4,7*24*3600};
		28604->{5,1*24*3600};
		28605->{6,30*60};
		_->{0,0}
	end.

%%设置vip
set_vip_state(PlayerStatus,GoodsId)->
	{Vip,VipTime} = get_vip_type(GoodsId),
	NowTime = util:unixtime(),
	mod_vip:send_mail(PlayerStatus,0,GoodsId),
	sys_broadcast_msg(PlayerStatus,GoodsId,1),
	vip_gift_bag(PlayerStatus,GoodsId),
	db_agent:log_vip(PlayerStatus#player.id,GoodsId,NowTime),
	update_times(PlayerStatus#player.id,Vip),
	case PlayerStatus#player.vip > 0 of
		false->
			Timestamp = NowTime + VipTime,
			db_agent:set_vip_state(PlayerStatus#player.id,Vip,Timestamp),
			gen_server:cast(PlayerStatus#player.other#player_other.pid,{'ACCEPT_VIP_CHECK',[VipTime]}),
			PlayerStatus#player{vip = Vip,vip_time = Timestamp};
		true->
			if Vip =:= 6 ->PlayerStatus;
			   true->
					case PlayerStatus#player.vip =:= Vip of
						true->
							Timestamp = PlayerStatus#player.vip_time + VipTime,
							db_agent:set_vip_state(PlayerStatus#player.id,Vip,Timestamp),
							PlayerStatus#player{vip = Vip,vip_time = Timestamp};
						false->
							Timestamp = NowTime + VipTime,
							db_agent:set_vip_state(PlayerStatus#player.id,Vip,Timestamp),
							PlayerStatus#player{vip = Vip,vip_time = Timestamp}
					end
			end
	end.

%%检查vip状态
check_vip_state(PlayerStatus)->
	case PlayerStatus#player.vip > 0 of
		false -> 
			PlayerStatus;
		true ->
			NowTime = util:unixtime(),
			case PlayerStatus#player.vip_time < NowTime of
				false ->
					case PlayerStatus#player.vip_time - NowTime < 86400 of
						false -> 
							skip;
						true -> 
							if PlayerStatus#player.vip =/=6->
								mod_vip:send_mail(PlayerStatus,1,PlayerStatus#player.vip);
							   true->skip
							end
					end,
					PlayerStatus;
				true ->
					mod_vip:send_mail(PlayerStatus, 2, PlayerStatus#player.vip),
					{ok,Bin13032} = pt_13:write(13032, 1),
					lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, Bin13032),
%% 					通知氏族模块(没vip啦)
					mod_guild:role_vip_update(PlayerStatus#player.id, 0),
					spawn(fun()-> db_agent:set_vip_state(PlayerStatus#player.id, 0, 0) end),
					NewPlayer = PlayerStatus#player{
						vip = 0,
						vip_time = 0
					},
					lib_player:send_player_attribute(NewPlayer, 3),
					mod_player:save_online_diff(PlayerStatus,NewPlayer),
					NewPlayer
			end
	end.

%%vip邮件
vip_mail(PlayerStatus,MailType,VipType)->
	NameList = [tool:to_list(PlayerStatus#player.nickname)],
	case MailType of
		0->Content =io_lib:format( "尊贵的远古封神玩家，欢迎您成为我们尊贵的~s玩家；相应的VIP特权福利从现在起已经对您开放，祝您游戏愉快！",[get_vip_name(VipType)]);
		1->Content = "尊贵的远古封神VIP玩家，您的VIP即将到期，感谢您对游戏的支持，欢迎您继续成为我们尊贵的VIP用户，祝你游戏愉快！";
		_->
			if PlayerStatus#player.vip=:= 6 ->
%% 				   gen_server:cast(PlayerStatus#player.other#player_other.pid, 
%% 							{'SET_PLAYER', [{vip,0},{vip_time ,0}]}),
%% 				   lib_player:send_player_attribute2(PlayerStatus#player{vip=0,vip_time=0}, 2),
				   {ok,BinData} = pt_15:write(15140,[1]),
				   lib_send:send_to_sid(PlayerStatus#player.other#player_other.pid_send, BinData),
				   ok;
			   true->skip
			end,
			Content = "亲爱的玩家，您的VIP功能已过期，感谢您对游戏的支持，欢迎您继续成为我们尊贵的VIP用户，祝你游戏愉快！"
	end,
	mod_mail:send_sys_mail(NameList, "VIP信件", Content, 0,0, 0, 0, 0).

%%系统播报
sys_broadcast_msg(PlayerStatus,VipType,BcType)->
	NameColor = data_agent:get_realm_color(PlayerStatus#player.realm),
	case BcType of
		0->
			if VipType =:= 28600  ->
				   Msg = io_lib:format("玩家[<a href='event:1,~p, ~s, ~p,~p'><font color='~s><u>~s</u></font></a>]元宝一丢，成功购买了商城中的【~s】！",
									  [PlayerStatus#player.id,PlayerStatus#player.nickname,PlayerStatus#player.career,PlayerStatus#player.sex,NameColor,PlayerStatus#player.nickname,vipcard_msg(VipType)]),
					lib_chat:broadcast_sys_msg(2,Msg);
			   VipType =:= 28601  ->
				   Msg = io_lib:format("玩家[<a href='event:1,~p, ~s, ~p,~p'><font color='~s'><u>~s</u></font></a>]挥手甩出了金烂烂的大元宝，在商城中购买了【~s】！",
									  [PlayerStatus#player.id,PlayerStatus#player.nickname,PlayerStatus#player.career,PlayerStatus#player.sex,NameColor,PlayerStatus#player.nickname,vipcard_msg(VipType)]),
					lib_chat:broadcast_sys_msg(2,Msg);
			   VipType =:= 28602  ->
				   Msg = io_lib:format("玩家[<a href='event:1,~p, ~s, ~p,~p'><font color='~s'><u>~s</u></font></a>]真是财大气粗，毫不犹豫的砸了大量元宝在商城中购买了【~s】！",
									  [PlayerStatus#player.id,PlayerStatus#player.nickname,PlayerStatus#player.career,PlayerStatus#player.sex,NameColor,PlayerStatus#player.nickname,vipcard_msg(VipType)]),
					lib_chat:broadcast_sys_msg(2,Msg);
			   true->skip
			   end;
		_->
			if VipType =:= 28600  ->
				   Msg = io_lib:format("玩家[<a href='event:1,~p, ~s, ~p,~p'><font color='~s'><u>~s</u></font></a>]使用了【~s】，成了远古封神黄金VIP会员！！<a href='event:4'><font color='#00FF00'><u>》》我要成为VIP《《</u></font></a>",
									  [PlayerStatus#player.id,PlayerStatus#player.nickname,PlayerStatus#player.career,PlayerStatus#player.sex,NameColor,PlayerStatus#player.nickname,vipcard_msg(VipType)]),
					lib_chat:broadcast_sys_msg(6,Msg);
			   VipType =:= 28601  ->
				   Msg = io_lib:format("玩家[<a href='event:1,~p, ~s, ~p,~p'><font color='~s'><u>~s</u></font></a>]使用了【~s】，成了远古封神尊贵的白金VIP会员！！<a href='event:4'><font color='#00FF00'><u>》》我要成为VIP《《</u></font></a>",
									  [PlayerStatus#player.id,PlayerStatus#player.nickname,PlayerStatus#player.career,PlayerStatus#player.sex,NameColor,PlayerStatus#player.nickname,vipcard_msg(VipType)]),
					lib_chat:broadcast_sys_msg(6,Msg);
			   VipType =:= 28602  ->
				   Msg = io_lib:format("玩家[<a href='event:1,~p, ~s, ~p,~p'><font color='~s'><u>~s</u></font></a>]使用了【~s】，成了远古封神最尊贵的钻石VIP会员！！<a href='event:4'><font color='#00FF00'><u>》》我要成为VIP《《</u></font></a>",
									  [PlayerStatus#player.id,PlayerStatus#player.nickname,PlayerStatus#player.career,PlayerStatus#player.sex,NameColor,PlayerStatus#player.nickname,vipcard_msg(VipType)]),
					lib_chat:broadcast_sys_msg(6,Msg);
			   VipType =:= 28603 orelse VipType =:= 28604 ->
				    Msg = io_lib:format("玩家[<a href='event:1,~p, ~s, ~p,~p'><font color='~s'><u>~s</u></font></a>]使用了【~s】，成了远古封神普通VIP会员！！<a href='event:4'><font color='#00FF00'><u>》》我要成为VIP《《</u></font></a>",
									  [PlayerStatus#player.id,PlayerStatus#player.nickname,PlayerStatus#player.career,PlayerStatus#player.sex,NameColor,PlayerStatus#player.nickname,vipcard_msg(VipType)]),
					lib_chat:broadcast_sys_msg(6,Msg);
			   VipType =:= 28605 andalso PlayerStatus#player.vip==0->
				   Msg = io_lib:format("玩家[<a href='event:1,~p, ~s, ~p,~p'><font color='~s'><u>~s</u></font></a>]使用了【~s】，成了远古封神普通VIP会员！！<a href='event:4'><font color='#00FF00'><u>》》我要成为VIP《《</u></font></a>",
									  [PlayerStatus#player.id,PlayerStatus#player.nickname,PlayerStatus#player.career,PlayerStatus#player.sex,NameColor,PlayerStatus#player.nickname,vipcard_msg(VipType)]),
					lib_chat:broadcast_sys_msg(6,Msg);
			   true->skip
			   end
	end.
			   
vipcard_msg(GoodsId)->
	io_lib:format("<a href='event:2,~p,~p,1'><font color='~s'> <u> ~s </u> </font></a>",
												[GoodsId, 0, get_vip_color(GoodsId), get_vip_name(GoodsId)]).

vip_gift_bag(PlayerStatus,GoodsId)->
%% 	case lists:member(GoodsId,[28600,28601,28602]) of
	case check_opened_time() of
		false->skip;
		true->
			if GoodsId =/=28603 andalso GoodsId =/=28604 andalso GoodsId =/= 28605->
				   case db_agent:check_vip_log(PlayerStatus#player.id,[28600,28601,28602]) of
						[]->
							NameList = [tool:to_list(PlayerStatus#player.nickname)],
							Content = io_lib:format("尊敬的~s，您好，您已成功使用~s，成为了尊贵的VIP玩家，接下来您将享受到各种专属VIP的服务。这是我们为您精心准备的VIP礼包，请在邮件附件处领取。祝您游戏!",[PlayerStatus#player.nickname,get_vip_name(GoodsId)]),
							mod_mail:send_sys_mail(NameList, "VIP礼包", Content, 0,28185, 1, 0, 0);
						_->skip
					end;
			   true->skip
			end
	end.

%%检查开服时间
check_opened_time()->
	 case config:get_opening_time() of
		 0->false;
		 OpenedTime->
			 util:unixtime()-OpenedTime =< 72*3600
%% 			 util:unixtime()-OpenedTime =< 2*3600%%测试时间
	 end.

%%获取vip名字
get_vip_name(VipType)->
	case VipType of
		28605->"VIP体验卡";
		28604->"VIP1天卡";
		28603->"VIP周卡";
		28600->"VIP月卡";
		28601->"VIP季卡";
		_28602->"VIP半年卡"
	end.
%%获取VIP颜色
get_vip_color(VipType)->
	case VipType of
		28605->goods_util:get_color_hex_value(1);
		28604->goods_util:get_color_hex_value(1);
		28603->goods_util:get_color_hex_value(1);
		28600->goods_util:get_color_hex_value(2);
		28601->goods_util:get_color_hex_value(3);
		_28602->goods_util:get_color_hex_value(4)
	end.
%%根据id获取部落名称
get_realm_name_by_id(Id)->
	case Id of
		1->"女娲";
		2->"神农";
		_->"伏羲"
	end.

%%每天登陆获取物品奖励
get_vip_award_load(PlayerStatus)->
	NewPlayerStatus = check_vip_state(PlayerStatus),
	{GoodsId,Num} = check_vip_award(goods,NewPlayerStatus),
	case Num > 0 of
		false->skip;
		true->
				NameList = [tool:to_list(PlayerStatus#player.nickname)],
				Content = "尊贵的VIP玩家，每天登陆奖励：",
				mod_mail:send_sys_mail(NameList, "VIP信件", Content, 0,GoodsId, Num, 0, 0)
	end,
	NewPlayerStatus.
	
%%获取vip奖励
get_vip_award(Type,PlayerStatus)->
	NewPlayerStatus = check_vip_state(PlayerStatus),
	{Award1,Award2} = check_vip_award(Type,NewPlayerStatus),
	{NewPlayerStatus, Award1, Award2}.

%%每天登陆奖励物品(筋斗云)
check_vip_award(goods,PlayerStatus)->
	case PlayerStatus#player.vip of
		1->{28134,1};
		2->{28134,2};
		3->{28134,0};%%vip半年卡修改成无限飞，礼包改成0
		4->{28134,1};
		5->{28134,1};
		6->{28134,1};
		_->{28134,0}
	end;

%%打怪经验灵力附加奖励倍数
check_vip_award(pk_mon,PlayerStatus)->
	case PlayerStatus#player.vip of
		1->{ok,0.2}; 
		2->{ok,0.3};
		3->{ok,0.5};
		4->{ok,0.2};
		5->{ok,0.2};
		6->{ok,0.2};
		_->{ok,0}
	end;
%%灵兽自动喂养,提升资质成功率奖励{灵兽是否自动喂养，资质提升附加成功率}
check_vip_award(pet,PlayerStatus)->
	case PlayerStatus#player.vip of
		1->{true,0};
		2->{true,0.03};
		3->{true,0.05};
		4->{true,0};
		5->{true,0};
		6->{true,0};
		_->{false,0}
	end; 
%%提升灵根附加成功率奖励
check_vip_award(meridian,PlayerStatus)->
	case PlayerStatus#player.vip of
		1->{ok,0.03};
		2->{ok,0.04};
		3->{ok,0.05};
		4->{ok,0.03};
		5->{ok,0.03};
		6->{ok,0.03};
		_->{ok,0}
	end;
%%装备强化附加成功率奖励
check_vip_award(intensify,PlayerStatus)->
	case PlayerStatus#player.vip of
		1->{ok,0};
		2->{ok,0};
		3->{ok,0.03};
		4->{ok,0};
		5->{ok,0};
		6->{ok,0};
		_->{ok,0}
	end;

%%获取副本挂机自动拾取权限,进入副本附加次数奖励
check_vip_award(dungeon,PlayerStatus)->
	case PlayerStatus#player.vip of
		1->{true,1};
		2->{true,2};
		3->{true,3};
		4->{true,1};
		5->{true,1};
		6->{true,1};
		_->{false,0}
	end;

%%进入70副本附加次数奖励
check_vip_award(cave,PlayerStatus)->
	case PlayerStatus#player.vip of
		1->{true,1};
		2->{true,1};
		3->{true,1};
		4->{true,1};
		5->{true,1};
		6->{true,1};
		_->{false,0}
	end;

%%获得封神台挂机，进入次数奖励{[true封神台可挂机；false否],封神台进入附加次数}
check_vip_award(fst,PlayerStatus)->
	case PlayerStatus#player.vip of
		1->{false,0};
		2->{false,1};
		3->{true,2};
		4->{false,0};
		5->{false,0};
		6->{false,0};
		_->{false,0}
	end;

%%获得诛仙台挂机，进入次数奖励{[true诛仙台可挂机；false否],诛仙台进入附加次数}
check_vip_award(zxt,PlayerStatus)->
	case PlayerStatus#player.vip of
		1->{false,0};
		2->{false,0};
		3->{true,0};
		4->{false,0};
		5->{false,0};
		6->{false,0};
		_->{false,0}
	end;

%%开放第四个背包(true开放，false否)
check_vip_award(bag,PlayerStatus)->
	case PlayerStatus#player.vip of
		1->{ok,false};
		2->{ok,true};
		3->{ok,true};
		4->{ok,false};
		5->{ok,false};
		6->{ok,false};
		_->{ok,false}
	end;

%%开放远程药店远程仓库(true开放，false否)
check_vip_award(remote,PlayerStatus)->
	case PlayerStatus#player.vip of
		1->{ok,true};
		2->{ok,true};
		3->{ok,true};
		4->{ok,true};
		5->{ok,true};
		6->{ok,true};
		_->{ok,false}
	end;
%%增加好友上限
check_vip_award(friend,PlayerStatus)->
	case PlayerStatus#player.vip of
		1->{ok,10};
		2->{ok,20};
		3->{ok,30};
		4->{ok,10};
		5->{ok,10};
		6->{ok,10};
		_->{ok,0}
	end;

%%学技能打折
check_vip_award(up_skill,PlayerStatus)->
	case PlayerStatus#player.vip of
		1->{ok,0.08};
		2->{ok,0.11};
		3->{ok,0.15};
		4->{ok,0.05};
		5->{ok,0.05};
		6->{ok,0.05};
		_->{ok,0}
	end;

check_vip_award(_,_)->
	{error,undefined}.


%%初始化vip信息
init_vip_info(PlayerId,Vip)->
	if Vip > 0 ->
			Times = get_send_times(Vip),
			NowTime = util:unixtime(),
			case db_agent:select_vip_info(PlayerId) of
				[]->
					{_,Id} = db_agent:insert_vip_info(PlayerId,Times,NowTime),
					ets:insert(?ETS_VIP, #ets_vip{id=Id,pid=PlayerId,times=Times,timestamp=NowTime});
				[Id,_,Times1,Timestamp]->
					{NewTimes,NewTimestamp} = case util:is_same_date(Timestamp,NowTime) of
												  true->{Times1,Timestamp};
												  false->
													  db_agent:update_vip_info([{times,Times},{timestamp,NowTime}],[{pid,PlayerId}]),
													  {Times,NowTime}
											  end,
					ets:insert(?ETS_VIP, #ets_vip{id=Id,pid=PlayerId,times=NewTimes,timestamp=NewTimestamp})
			end;
	   true->skip
	end.

offline(PlayerId)->
	ets:delete(?ETS_VIP, PlayerId).

get_send_times(PlayerId,Vip)->
	if Vip =:=0 orelse Vip =:=3->0;
	   true->
		   case ets:lookup(?ETS_VIP, PlayerId) of
			   []->0;
			   [Info]->
				   Info#ets_vip.times
		   end
	end.
	
check_send_times(PlayerId,Vip)->
	if Vip =:= 0 orelse Vip =:=3->false;
	   true->
			case ets:lookup(?ETS_VIP, PlayerId) of
				[]->false;
				[Info]->
					NowTime = util:unixtime(),
					case util:is_same_date(Info#ets_vip.timestamp,NowTime) of
						true->
							if Info#ets_vip.times > 0->
						   		Times  = Info#ets_vip.times-1,
						   		db_agent:update_vip_info([{times,Times}],[{pid,PlayerId}]),
				   				ets:insert(?ETS_VIP, Info#ets_vip{times=Times}),
						   		true;
					  		 true->false
							end;
						false->
							Times = get_send_times(Vip)-1,
							db_agent:update_vip_info([{times,Times},{timestamp,NowTime}],[{pid,PlayerId}]),
						   	ets:insert(?ETS_VIP, Info#ets_vip{times=Times,timestamp=NowTime})
					end
			end
	end.

update_times(PlayerId,Vip)->
	Times = get_send_times(Vip),
	case ets:lookup(?ETS_VIP, PlayerId) of
		[]->
			NowTime = util:unixtime(),
			{_,Id} = db_agent:insert_vip_info(PlayerId,Times,NowTime),
			ets:insert(?ETS_VIP, #ets_vip{id=Id,pid=PlayerId,times=Times,timestamp=NowTime});
		[Info]->
			NewTimes = Info#ets_vip.times+Times,
			db_agent:update_vip_info([{times,NewTimes}],[{pid,PlayerId}]),
			ets:insert(?ETS_VIP, Info#ets_vip{times=NewTimes})
	end.

get_send_times(Vip)->
	case Vip of
		1->20;
		2->40;
		4->20;
		5->20;
		6->20;
		_->0
	end.
					   