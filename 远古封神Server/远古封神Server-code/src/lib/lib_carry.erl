%% Author: hxming
%% Created: 2010-10-26
%% Description: 运镖管理类
-module(lib_carry).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
%%
%% Exported Functions
%%
%% -export([]).
-compile(export_all).
%%
%% API Functions
%%

%%
%% Local Functions
%%

init_carry(PlayerId)->
	case db_agent:select_carry(PlayerId) of
		[]->
			%插入新玩家数据
			NowTime = util:unixtime(),
			{_,Id}=db_agent:insert_carry(PlayerId,NowTime),
			Data = [Id,PlayerId,0,NowTime,0,NowTime,1,0,0,0],
			EtsData = match_ets_playerinfo(Data),
 			ets:insert(?ETS_CARRY,EtsData);
		Result ->
				Data = match_ets_playerinfo(Result),
				ets:insert(?ETS_CARRY,Data)
	end.

match_ets_playerinfo(Data)->
	[Id,PlayerId,Carry,Ctime,Bandits,Btime,Qc,TH,NW,HY]= Data,
	EtsData = #ets_carry{
							    id=Id,
      							pid = PlayerId,          %% 玩家ID	
	  							carry = Carry,
								carry_time = Ctime,
								bandits = Bandits,
								bandits_time = Btime,
								quality = Qc,
								taihao = TH,
								vnwa=NW,
								huayang=HY
								
															},
	EtsData.

%%获取玩家运镖信息
get_carry(PlayerId)->
	ets:lookup(?ETS_CARRY, PlayerId).

%%玩家下线
offline(PlayerId)->
	ets:match_delete(?ETS_CARRY, #ets_carry{pid=PlayerId, _='_'}).

%%玩家接镖(1接镖2等级不足，3)
check_carry(PS)->
	case get_carry(PS#player.id) of
		[]->{false,115};
		[Carry]->
			case check_new_day(Carry#ets_carry.carry_time)of
				true ->
					%检查当前有没有镖
					if PS#player.carry_mark  >0->
						   {false,114};
					   true ->
						   %检查接镖次数
						   if Carry#ets_carry.carry >= 3 ->
								  {false,115};
							  true ->
								  {true,[]}
						   end
					end;
				false  ->
					reset_carry_info(PS#player.id,Carry),
					if PS#player.carry_mark >0 ->
						   {false,114};
					   true ->
						   {true,[]}
					end
			end
	end.

%%检查是否有接镖
check_has_carry(PS)->
	if PS#player.carry_mark > 0->
		   true;
	   true ->
		   false
	end.


%%查询镖车刷新信息
check_flush_info(PlayerId)->
	case get_carry(PlayerId) of
		[]->[1,1,1];
		[Carry]->
			[Carry#ets_carry.taihao,Carry#ets_carry.vnwa,Carry#ets_carry.huayang]
	end.

%%刷新镖车品质(1刷镖成功，2刷镖失败，3刷镖NpcId不正确4当前场景不能刷镖5该刷镖点已经刷过，不能刷镖；6当前镖车已经是最好品质，不能刷镖，7没有刷镖令，不能刷镖，8玩家身上没有运镖任务，不能刷镖，9系统繁忙，稍后重试)
flush_qc(PlayerStatus,Npc)->
	case check_npc(Npc) of
		false->{error,PlayerStatus,3};
		true->
			case check_scene(PlayerStatus#player.scene,Npc) of
				false->{error,PlayerStatus,4};
				true->
					case get_carry(PlayerStatus#player.id) of
						[]->{error,PlayerStatus,9};
						[Carry]->
							case check_flush(Npc,Carry) of
								false->{error,PlayerStatus,5};
								true->
									case Carry#ets_carry.quality >= 4 of
										true->{error,PlayerStatus,6};
										false->
											case lists:member(PlayerStatus#player.carry_mark,[1,2,20,21,22,23,24,25]) of
												false->{error,PlayerStatus,8};
												true->
													case gen_server:call(PlayerStatus#player.other#player_other.pid_goods, {'delete_more', 28517,1}) of
														1->
															%%40%的提升概率
															case util:rand(1,10000) =< 4000 of
																true->
																	Qc  = Carry#ets_carry.quality+1,
																	NewCarry = Carry#ets_carry{quality=Qc},
																	flush(Npc,NewCarry),
																	NewPlayerStatus = change_carry_flag(PlayerStatus,Qc),
																	{ok,NewPlayerStatus,1};
																false->
																	flush(Npc,Carry),
																	{ok,PlayerStatus,2}
															end;
														_->{error,PlayerStatus,7}
													end
											end
									end
							end
					end
			end
	end.

flush(Npc,Carry)->
	NewCarry = case Npc of
		20920->
			spawn(fun()->db_agent:reset_carry([{quality,Carry#ets_carry.quality},{taihao,1}],[{pid,Carry#ets_carry.pid}])end),
			Carry#ets_carry{taihao=1};
		20922->
			spawn(fun()->db_agent:reset_carry([{quality,Carry#ets_carry.quality},{vnwa,1}],[{pid,Carry#ets_carry.pid}])end),
			Carry#ets_carry{vnwa=1};
		_->
			spawn(fun()->db_agent:reset_carry([{quality,Carry#ets_carry.quality},{huayang,1}],[{pid,Carry#ets_carry.pid}])end),
			Carry#ets_carry{huayang=1}
	end,
	ets:insert(?ETS_CARRY, NewCarry).


%%npc（1太昊，2女娲，3华阳
check_npc(Npc)->
	lists:member(Npc,[20920,20922,20924]).

%%检查能否刷新
check_flush(Npc,Carry)->
	case Npc of
		20920->Carry#ets_carry.taihao=:=0;
		20922->Carry#ets_carry.vnwa =:=0;
		_->Carry#ets_carry.huayang =:= 0
	end.

%%检查玩家地图
check_scene(Scene,Npc)->
	case Npc of
		20920->Scene =:= 251;
		20922->Scene =:= 201;
		_->Scene =:= 281
	end.

%%接镖信息重置
reset_carry_info(PlayerId,Carry) ->
	NowTime = util:unixtime(),
	NewCarry = Carry#ets_carry{carry=0,carry_time=NowTime},
	ets:insert(?ETS_CARRY,NewCarry),
	db_agent:reset_carry_times(PlayerId,NowTime).
%% 	(catch db_agent:mm_update_player_info([{carry_times,0},{carry_timestamp,0}],[{id,PlayerStatus#player.id}])),
%% %% 	PlayerStatus1=PlayerStatus#player{carry_times=0,carry_timestamp =0},
%% 	gen_server:cast(PlayerStatus#player.other#player_other.pid, {'SET_PLAYER', [{carry_times,0}, {carry_timestamp,0}]}).

%%接镖信息更新
update_carry_info(PlayerStatus,CarryType) ->
	%% 玩家卸下坐骑
	{ok,MountPlayerStatus}=lib_goods:force_off_mount(PlayerStatus),
	Carry_Mark = case CarryType of
					 3-> Pk_mode=3,
						 3;
					 _->Pk_mode=2,
						 case check_double_time() of
							 {false,_}->1;
							 {true,_}->2
				 		end
					 end,
	NewPlayerStatus = MountPlayerStatus#player{pk_mode=Pk_mode},
	{ok, PkModeBinData} = pt_13:write(13012, [1, Pk_mode]),
    lib_send:send_to_sid(NewPlayerStatus#player.other#player_other.pid_send, PkModeBinData),
	(catch db_agent:mm_update_player_info([ {carry_mark, Carry_Mark}],
											[{id,NewPlayerStatus#player.id}])),
	NewPlayerStatus1=NewPlayerStatus#player{carry_mark = Carry_Mark},
	case Carry_Mark of
		3->mod_guild:update_guild_carry_info(PlayerStatus,sub);
		_->
			[Carry]= get_carry(PlayerStatus#player.id),
			NewCarry = Carry#ets_carry{carry=Carry#ets_carry.carry+1},
			ets:insert(?ETS_CARRY,NewCarry),
			db_agent:update_carry_times(PlayerStatus#player.id)
	end,
	guild_carry_msg(NewPlayerStatus1,Carry_Mark),
	%%通知所有玩家
    {ok,BinData2} = pt_12:write(12041,[NewPlayerStatus1#player.id,NewPlayerStatus1#player.carry_mark]),
	mod_scene_agent:send_to_area_scene(NewPlayerStatus1#player.scene,NewPlayerStatus1#player.x,NewPlayerStatus1#player.y, BinData2),
	%%运镖统计
	case Carry_Mark of
		3->
			db_agent:update_join_data(NewPlayerStatus1#player.id, guild_carry);
		_->db_agent:update_join_data(NewPlayerStatus1#player.id, carry)
	end,
	{ok,NewPlayerStatus1}.

%%变换镖车颜色
change_carry_flag(PlayerStatus,Qc)->
	CarryMark = case check_double_time() of
					{false,_}->
						case Qc of
							1->1;
							2->20;
							3->21;
							_->22
						end;
					{true,_}->
						case Qc of
							1->2;
							2->23;
							3->24;
							_->25
						end
				end ,
	%%通知所有玩家
    {ok,BinData2} = pt_12:write(12041,[PlayerStatus#player.id,CarryMark]),
	mod_scene_agent:send_to_area_scene(PlayerStatus#player.scene,PlayerStatus#player.x,PlayerStatus#player.y, BinData2),
	
	(catch db_agent:mm_update_player_info([ {carry_mark, CarryMark}],
											[{id,PlayerStatus#player.id}])),
	gen_server:cast(PlayerStatus#player.other#player_other.pid_task,{'trigger_task',PlayerStatus}),
	NewPlayerStatus=PlayerStatus#player{carry_mark = CarryMark},
	%%蓝。紫镖广播
	change_msg(NewPlayerStatus),
	NewPlayerStatus.

%%交镖
finish_carry(PlayerStatus)->
	(catch db_agent:mm_update_player_info([{carry_mark,0}],[{id,PlayerStatus#player.id}])),
	PlayerStatus1 = PlayerStatus#player{carry_mark = 0},
	[Carry]= get_carry(PlayerStatus#player.id),
	NewCarry = Carry#ets_carry{quality=1,taihao=0,vnwa=0,huayang=0},
	ets:insert(?ETS_CARRY,NewCarry),
	spawn(fun()-> db_agent:reset_carry([{quality,1},{taihao,0},{vnwa,0},{huayang,0}],[{pid,PlayerStatus#player.id}])end),
	%%通知所有玩家
    {ok,BinData2} = pt_12:write(12041,[PlayerStatus1#player.id,PlayerStatus1#player.carry_mark]),
	mod_scene_agent:send_to_area_scene(PlayerStatus1#player.scene,PlayerStatus1#player.x, PlayerStatus1#player.y, BinData2),
	{ok,PlayerStatus1}.

%%镖被劫
carry_failed(Ps,Pid,CarryType)->
	case is_pid(Pid) of
		true->
			case catch gen:call(Pid, '$gen_call', 'PLAYER', 2000) of
             	{'EXIT',_Reason} ->
              			ok;
             	{ok, Player} ->
					case check_bandits_times(Player) of
						false->
							ud_bandits_times(Player),
							case Player#player.realm /= Ps#player.realm of
								true->
									sys_broadcast_msg(Ps,Player,CarryType),
									case CarryType of
										3->
											case  Player#player.guild_id > 0 of 
												true->
													case mod_guild:get_guild_carry_info(Player#player.guild_id) of
														[0,{}]->
															GuildLv=get_guild_level(Ps);
														[_,{_Level,_Coin,_CarryTime,BanditsTime,_ChiefId,_DeputyId1,_DeputyId2}]-> 
															case util:check_same_day(BanditsTime) of
																false->
																	case get_guild_level(Ps) of
																		0->GuildLv=0;
																		Level->
																			mod_guild:update_guild_bandits_info( Player#player.id,Level,Player#player.guild_id),
																			GuildLv=Level
																	end;
																true->
																	GuildLv=get_guild_level(Ps)
															end
													end;
												false->
													GuildLv = get_guild_level(Ps)
											end;
										_->GuildLv=0
									end,
									case get_goods_id(Ps#player.realm,Ps#player.lv,CarryType,GuildLv) of
										{ok,GoodsId,Num} ->
											gen_server:call(Player#player.other#player_other.pid_goods, {'give_goods', Player,GoodsId, Num,0}),
											ok;
										_ ->ok
									end;
								false->ok
							end;
						true->ok
					end
             end;
			
		false ->
			ok
	end.

get_guild_level(Ps)->
	case mod_guild:get_guild_carry_info(Ps#player.guild_id) of
		[0,{}]->0;
		[_,{Level,_Coin,_CarryTime,_BanditsTime,_ChiefId,_DeputyId1,_DeputyId2}]->Level
	end.

%%检查运镖次数
check_bandits_times(PlayerStatus)->
	Times = case catch(gen_server:call(PlayerStatus#player.other#player_other.pid_task,{'bandits',PlayerStatus#player.id})) of
				{ok,Num}->Num;
				{'EXIT', _} -> 0
			end,
	Times >=5 .

%%更新劫镖次数
ud_bandits_times(PlayerStatus)->
	gen_server:cast(PlayerStatus#player.other#player_other.pid_task,{'ud_bandits',PlayerStatus#player.id}).

%%获取劫镖次数
get_bandits_times(PlayerId)->
	[Carry]= get_carry(PlayerId),
	case check_new_day(Carry#ets_carry.bandits_time) of
		true->Carry#ets_carry.bandits;
		false->
			NowTime = util:unixtime(),
			NewCarry = Carry#ets_carry{bandits=0,bandits_time=NowTime},
			ets:insert(?ETS_CARRY,NewCarry),
			db_agent:reset_bandits_times(PlayerId,NowTime),
			0
	end.

%%更新劫镖次数
update_bandits_times(PlayerId)->
	[Carry]= get_carry(PlayerId),
	NewCarry = Carry#ets_carry{bandits=Carry#ets_carry.bandits+1},
	ets:insert(?ETS_CARRY,NewCarry),
	db_agent:update_bandits_times(PlayerId).

sys_broadcast_msg(PsDie,PsLive,CarryType)->
	case CarryType of
		3->
			case PsLive#player.guild_id>0 of
				true->
					%%【国家】的XXX氏族的氏族镖银居然被【国家】的XXX氏族的XXX轻松劫获了！
					Msg = io_lib:format("【~s】的<font color='#F8EF38'>【~s】</font>氏族的氏族镖银居然被【~s】的<font color='#F8EF38'>【~s】</font>氏族的[<a href='event:1,~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>]轻松劫获了！",[get_realm_name_by_id(PsDie#player.realm),get_guild_name_by_pid(PsDie#player.guild_id),get_realm_name_by_id(PsLive#player.realm),get_guild_name_by_pid(PsLive#player.guild_id),PsLive#player.id,PsLive#player.nickname,PsLive#player.career,PsLive#player.sex,PsLive#player.nickname]),
					lib_chat:broadcast_sys_msg(6,Msg);
				false->
					%%【国家】的XXX氏族的氏族镖银居然被【国家】的XXX轻松劫获了！
					Msg = io_lib:format("【~s】的<font color='#F8EF38'>【~s】</font>氏族的氏族镖银居然被【~s】的[<a href='event:1,~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>]轻松劫获了！",[get_realm_name_by_id(PsDie#player.realm),get_guild_name_by_pid(PsDie#player.guild_id),get_realm_name_by_id(PsLive#player.realm),PsLive#player.id,PsLive#player.nickname,PsLive#player.career,PsLive#player.sex,PsLive#player.nickname]),
					lib_chat:broadcast_sys_msg(6,Msg)
			end;
		_->
			Msg = msg(util:rand(1,3),PsDie,PsLive,CarryType),
			lib_chat:broadcast_sys_msg(6,Msg),
			erlang:spawn(fun()->catch(lib_achieve:check_achieve_finish_cast(PsLive#player.other#player_other.pid, 309, [1]))end)
	end.
guild_carry_msg(PlayerStatus,CarryType)->
	if CarryType =:= 3->
		   Msg = io_lib:format("【~s】的<font color='#F8EF38'>【~s】</font>氏族的[<a href='event:1,~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>]拉着满车金灿灿的财宝往九霄氏族领地方向飞奔而去！！！",[get_realm_name_by_id(PlayerStatus#player.realm),get_guild_name_by_pid(PlayerStatus#player.guild_id),PlayerStatus#player.id,PlayerStatus#player.nickname,PlayerStatus#player.career,PlayerStatus#player.sex,PlayerStatus#player.nickname]),
		   lib_chat:broadcast_sys_msg(6,Msg);
	   true->skip
	end.
%%
msg(1,PsDie,PsLive,Mark)->
	%%广播1:“XXX(劫镖者)大吼一声,XXX(被劫者)被吓破了胆,扔下XX镖车（XX为镖车颜色）跑掉了。”
	M1 = io_lib:format("~s的<a href='event:1,~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>大吼一声,~s的<a href='event:1,~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>被吓破了胆,扔下~s跑掉了。",[get_realm_name_by_id(PsLive#player.realm),PsLive#player.id,PsLive#player.nickname,PsLive#player.career,PsLive#player.sex,PsLive#player.nickname,get_realm_name_by_id(PsDie#player.realm),PsDie#player.id,PsDie#player.nickname,PsDie#player.career,PsDie#player.sex,PsDie#player.nickname,get_car_color(Mark)]),
 	M1;
msg(2,PsDie,PsLive,Mark)->
	%%“XXX（劫镖者）使出了华丽丽的必杀技，XXX（被劫者）被打得脸青鼻肿，乖乖地交出了XX镖车（XX为镖车颜色）。”
	M1 = io_lib:format("~s的<a href='event:1,~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>使出了华丽丽的必杀技，~s的<a href='event:1,~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>被打得脸青鼻肿，乖乖地交出了~s。",[get_realm_name_by_id(PsLive#player.realm),PsLive#player.id,PsLive#player.nickname,PsLive#player.career,PsLive#player.sex,PsLive#player.nickname,get_realm_name_by_id(PsDie#player.realm),PsDie#player.id,PsDie#player.nickname,PsDie#player.career,PsDie#player.sex,PsDie#player.nickname,get_car_color(Mark)]),
	M1;
msg(3,PsDie,PsLive,Mark)->
	%%“远远看到围绕在XXX（劫镖者）身边的霸气力场，XXX（被劫者）自觉地留下XX镖车（XX为镖车颜色）溜回老家去了。”
	M1 = io_lib:format("远远看到围绕在~s的<a href='event:1,~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>身边的霸气力场，~s的<a href='event:1,~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>自觉地留下~s溜回老家去了。",[get_realm_name_by_id(PsLive#player.realm),PsLive#player.id,PsLive#player.nickname,PsLive#player.career,PsLive#player.sex,PsLive#player.nickname,get_realm_name_by_id(PsDie#player.realm),PsDie#player.id,PsDie#player.nickname,PsDie#player.career,PsDie#player.sex,PsDie#player.nickname,get_car_color(Mark)]),
	M1.

change_msg(PlayerStatus)->
	%%XXX（玩家名）在XXXX（刷镖NPC名）处接到了X（镖车颜色：蓝/紫）色镖车.
	case lists:member(PlayerStatus#player.carry_mark,[21,22,24,25])of
		true->
			M1 = io_lib:format("哇塞，[<a href='event:1,~p, ~s, ~p,~p'><font color='#FEDB4F'><u>~s</u></font></a>]在~s处接到了~s。",[PlayerStatus#player.id,PlayerStatus#player.nickname,PlayerStatus#player.career,PlayerStatus#player.sex,PlayerStatus#player.nickname,get_npc_name(PlayerStatus#player.scene),get_car_color(PlayerStatus#player.carry_mark)]),
			lib_chat:broadcast_sys_msg(6,M1);
		false->
			skip
	end.
%%根据玩家id获取氏族名称
get_guild_name_by_pid(GuildId)->
	lib_guild:get_guild_name(GuildId).

%%获取镖车颜色
get_car_color(Mark)->
	io_lib:format("<font color='~s'>~s</font>",[get_color_by_id(Mark),get_name_by_color(Mark)]).

get_color_by_id(Id)->
	case Id of 
		1->goods_util:get_color_hex_value(0);
		20->goods_util:get_color_hex_value(1);
		21->goods_util:get_color_hex_value(2);
		22->goods_util:get_color_hex_value(4);
		2->goods_util:get_color_hex_value(0);
		23->goods_util:get_color_hex_value(1);
		24->goods_util:get_color_hex_value(2);
		25->goods_util:get_color_hex_value(4)
	end.

get_name_by_color(Id)->
	case Id of
		1->"白色镖车";
		20->"绿色镖车";
		21->"蓝色镖车";
		22->"紫色镖车";
		2->"白色镖车";
		23->"绿色镖车";
		24->"蓝色镖车";
		25->"紫色镖车"
	end.

%%获取NPC名字
get_npc_name(Scene)->
	case Scene of
		201->"娲皇镖师";
		251->"太昊镖师";
		_->"华阳镖师"
	end.
	
%%根据id获取部落名称
get_realm_name_by_id(Id)->
	case Id of
		1->"女娲";
		2->"神农";
		_->"伏羲"
	end.

get_goods_id(_Realm , Lv,CarryType,GuildLv) ->
	case CarryType of
		3->
			case GuildLv of
				1->{ok,28507,1};
				2->{ok,28508,1};
				3->{ok,28509,1};
				4->{ok,28510,1};
				5->{ok,28511,1};
				6->{ok,28512,1};
				7->{ok,28513,1};
				8->{ok,28514,1};
				9->{ok,28515,1};
				10->{ok,28516,1};
				_->{error,0,0}
			end;
		_->
			case lib_carry:check_double_time() of
				{false,_}->
					if Lv< 40->{ok,28518,get_goods_num(CarryType)};
					   Lv<50->{ok,28519,get_goods_num(CarryType)};
					   Lv<60->{ok,28520,get_goods_num(CarryType)};
					   Lv<70->{ok,28521,get_goods_num(CarryType)};
					   Lv<80->{ok,28522,get_goods_num(CarryType)};
					   Lv<90->{ok,28523,get_goods_num(CarryType)};
					   true->{ok,28524,get_goods_num(CarryType)}
					end;
				{true,_}->
					if Lv< 40->{ok,28518,get_goods_num(CarryType)*3};
					   Lv<50->{ok,28519,get_goods_num(CarryType)*3};
					   Lv<60->{ok,28520,get_goods_num(CarryType)*3};
					   Lv<70->{ok,28521,get_goods_num(CarryType)*3};
					   Lv<80->{ok,28522,get_goods_num(CarryType)*3};
					   Lv<90->{ok,28523,get_goods_num(CarryType)*3};
					   true->{ok,28524,get_goods_num(CarryType)*3}
					end
			end
	end.
%%获取奖励物品个数（白4，绿5，蓝6 紫7）
get_goods_num(Mark)->
	case Mark of
		1->4;
		2->4;
		20->5;
		21->6;
		22->7;
		23->5;
		24->6;
		25->7;
		_->4
	end.
%%检查第二天
check_new_day(Timestamp)->
	if Timestamp =/= 0 ->
		NDay = (util:unixtime()+8*3600) div 86400,
		TDay = (Timestamp+8*3600) div 86400,
		NDay=:=TDay;
	   true->
		   true
	end.

%%检查是否国运时间
check_double_time()->
%% 	false.
	NowSec = util:get_today_current_second(),
	if NowSec>=?CARRY_BC_START andalso NowSec =< ?CARRY_BC_END ->
		   {true,?CARRY_BC_END-NowSec};
	   true-> {false,0}
	end.

get_qc_award(PlayerId)->
	case get_carry(PlayerId) of
		[]->1;
		[Carry]->
			case Carry#ets_carry.quality of
				1->1;
				2->1.25;
				3->1.5;
				4->1.75;
				_->1
			end
	end.

%%运镖奖励
base_carry_award(PlayerId,Task)->
	case lib_carry:check_double_time() of
		{true,_}->{Task#task.exp*3,round(get_qc_award(PlayerId)*Task#task.coin*3)};
		_->{Task#task.exp,round(get_qc_award(PlayerId)*Task#task.coin)}
	end.
	
%%获取运镖奖励
add_carry_award(PlayerStatus,Task)->
	case PlayerStatus#player.carry_mark >0  of
		true ->
			%%镖车颜色加成
			Mult = get_qc_award(PlayerStatus#player.id),
			{ok,PlayerStatus1} = lib_carry:finish_carry(PlayerStatus),
			PlayerStatus_1=lib_player:count_player_speed(PlayerStatus1),
			%%查询是否国运
			case lib_carry:check_double_time() of
				{true,_}->
					case lists:member(PlayerStatus#player.carry_mark,[2,23,24,25]) of
						true->
							Coin = round(Mult*Task#task.coin*3),
							PlayerStatus_2 = lib_player:add_coin(PlayerStatus_1, Coin),
							lib_task:carry_coin_tip(PlayerStatus_2,Coin),
							lib_player:add_exp(PlayerStatus_2, Task#task.exp*3, 0,0);
						false->
							Coin = round(Mult*Task#task.coin),
							PlayerStatus_2 = lib_player:add_coin(PlayerStatus_1, Coin),
							lib_task:carry_coin_tip(PlayerStatus_2,Coin),
							lib_player:add_exp(PlayerStatus_2, Task#task.exp, 0,0)
					end;
				{false,_}->
					Coin = round(Mult*Task#task.coin),
					PlayerStatus_2 = lib_player:add_coin(PlayerStatus_1, Coin),
					lib_task:carry_coin_tip(PlayerStatus_2,Coin),
					lib_player:add_exp(PlayerStatus_2, Task#task.exp, 0,0)
			end;
		false ->
			PlayerStatus_1=lib_player:count_player_speed(PlayerStatus),
			case lib_carry:check_double_time() of
				{true,_}->
					lib_task:carry_mail(PlayerStatus_1,Task#task.exp*3),
					%%运镖失败没有铜币奖励
%% 					PlayerStatus_1 = lib_player:add_coin(PlayerStatus, 0),
					lib_player:add_exp(PlayerStatus_1, Task#task.exp*3, 0,0);
				{false,_}->
					lib_task:carry_mail(PlayerStatus_1,Task#task.exp),
%% 					PlayerStatus_1 = lib_player:add_coin(PlayerStatus, 0),
					lib_player:add_exp(PlayerStatus_1, Task#task.exp, 0,0)
			end
	end.

%%获取氏族运镖奖励
add_guild_carry_award(PlayerStatus,Task)->
	case PlayerStatus#player.carry_mark > 0 of
		true->
			{ok,PlayerStatus_1} = lib_carry:finish_carry(PlayerStatus),
			PlayerStatus_2=lib_player:count_player_speed(PlayerStatus_1),
			case mod_guild:get_guild_carry_info(PlayerStatus_2#player.guild_id) of
				[0,{}]->lib_player:add_exp(PlayerStatus_2, Task#task.exp, 0,0);
				[_,{Level,_Coin,_CarryTime,_BanditsTime,_ChiefId,_DeputyId1,_DeputyId2}]->
					CarryCoin = lib_task:guild_carry_coin_award(player,Level),
					PlayerStatus_3 = lib_player:add_coin(PlayerStatus_2, CarryCoin),
					lib_task:carry_coin_tip(PlayerStatus_3,CarryCoin),
					lib_player:add_exp(PlayerStatus_3, Task#task.exp, 0,0)
			end;
		false->
			PlayerStatus_2=lib_player:count_player_speed(PlayerStatus),
			%%氏族镖被劫只能获得经验奖励
			lib_task:guild_carry_mail(PlayerStatus_2),
			lib_player:add_exp(PlayerStatus_2, Task#task.exp, 0,0)
	end.


%% 	case get_realm_carry_time({realm,Realm}) of
%% 		[]->false;
%% 		[{_,_,_,StartTime,EndTime,_}] ->
%% 			NowSec = util:get_today_current_second(),
%% 			if NowSec>=StartTime andalso NowSec =< EndTime ->
%% 		  		 true;
%% 	   		true-> false
%% 			end
%% 	end.

%%根据等级获取押金
get_kaution_by_lvl(Lvl,_Realm)->
	case lib_carry:check_double_time() of
		{true,_} ->
			if	Lvl < 40 -> 1000*3;
				Lvl >= 40 andalso Lvl < 50 -> 1200*3;
				Lvl >= 50 andalso Lvl < 60 -> 1500*3;
				true -> 2800*3
			end;
		{false,_} ->
			if	Lvl < 40 -> 1000;
				Lvl >= 40 andalso Lvl < 50 -> 1200;
				Lvl >= 50 andalso Lvl < 60 -> 1500;
				true -> 2800
			end
	end.


%%%%%%%%%%时间处理%%%%%%%%%%%%%%%

	
%%根据阵营获取国运时间
get_realm_carry_time({realm,Realm})->
	Pattern = #ets_carry_time{realm=Realm,_='_'},
	case match_all(?ETS_CARRY_TIME, Pattern) of 
		[] ->
			case db_agent:get_carry_time({realm,Realm}) of 
				[]->
					[];
				Result ->
					Data = match_ets_carryinfo(Result),
					ets:insert(?ETS_CARRY_TIME,Data),
					match_all(?ETS_CARRY_TIME, Pattern)
			end;
		Info ->
		 	Info
	end;

%%根据顺序获取国运时间
get_realm_carry_time({seq,Sep})->
	Pattern = #ets_carry_time{seq=Sep,_='_'},
	case match_all(?ETS_CARRY_TIME, Pattern) of 
		[] ->
			case db_agent:get_carry_time({seq,Sep}) of 
				[]->
					[];
				Result ->
					Data = match_ets_carryinfo(Result),
					ets:insert(?ETS_CARRY_TIME,Data),
					match_all(?ETS_CARRY_TIME, Pattern)
			end;
		Info ->
		 	Info
	end.
match_ets_carryinfo(Data)->
	[Realm,Seq,S,E,T]= Data,
	EtsData = #ets_carry_time{
							  realm = Realm,  %%阵营
							  seq = Seq,	%%序号
							  start_time = S,	%%开始时间
							  end_time = E,		%%结束时间
							  timestamp = T		%%分配时间
							  },
	EtsData.

match_all(Table, Pattern) ->
    ets:match_object(Table, Pattern).

time_test()->
	NowTime = util:unixtime(),
	io:format("Here is NowTime:~p~n",[NowTime]),
	ok.

set_carry_time(State)->
	NowTime = util:unixtime(),
	{ok,[First,Second,Third]} = set_seq(),
	set_time(State,1,NowTime,First),
	set_time(State,2,NowTime,Second),
	set_time(State,3,NowTime,Third),
	ok.

set_seq()->
	A = util:rand(1,3),
	[B,C] = lists:delete(A,[1,2,3]),
	{ok,[A,B,C]}.
	
set_time(State,Realm,NowTime,Num)->
	[S,E] = get_time(State,Num),
	db_agent:update_carry_time(Realm,Num,S,E,NowTime),
	[CarryInfo] = get_realm_carry_time({realm,Realm}),
	NewCarryInfo = CarryInfo#ets_carry_time{seq = Num,start_time=S,end_time = E,timestamp=NowTime},
	ets:insert(?ETS_CARRY_TIME,NewCarryInfo),
	ok.

get_time(State,Num)->
	if State =:= noon ->
		   if Num =:= 1 ->[54000,55200];
			  Num =:= 2 ->[55200,56400];
			  true -> [56400,57600]
		   end;
	   true ->
		   if Num =:= 1 ->[68400,69600];
			  Num =:= 2 ->[69600,70800];
			  true -> [70800,72000]
		   end
	end.
