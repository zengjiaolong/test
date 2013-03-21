%% Author: xianrongMai
%% Created: 2011-8-2
%% Description: spring模块的处理方法
-module(lib_spring).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("hot_spring.hrl").
%%
%% Exported Functions
%%
-export([
		 player_comeinto_spring/1,			%%进温泉，下坐骑，取消挂机，温泉福利
		 get_spring_on_sale_times/0,		%%温泉的开放时间控制，修改时间时，直接修改此方法的返回值
%% 		 get_hotspring_resure_id/1,
		 check_hotspring_site/2,
		 send_player_spring_site/5,
		 get_hotspring_site/0,
		 mark_hotspring_site/1,			%%做玩家在温泉的位置标注，0：温泉场景外面，1：温泉里但不在泉水里，2：VIPTOP泉水里，3：VIPNORMAL泉水里，4：PUBLIC泉水里
		 sys_broadcast_spring/1,		%%系统广播
		 check_is_hotspring_date/1,		%%判断是否在这一天启动了该类型的温泉
		 get_spring_scene/1,			%%获取温泉场景ID
		 get_spring_type/1,				%%获取温泉的类型
		 broadcast_spring_time/2,		%%广播温泉时间
		 check_spring_onsale/2,			%%检查是否需要通知温泉开放
		 make_faces_num/1,				%%生成 玩家能发表情的次数列表
		 enter_spring/2,				%%进入温泉
		 get_faces/1,					%%获取玩家能够戏水的次数
		 spring_add_expspi/2,			%%温泉+经验
		 is_spring_scene/1,				%%判断是否在温泉场景中
		 start_spring/2					%%判断是否需要启动温泉
		]).

%%
%% API Functions
%%

get_spring_on_sale_times() ->
	[{43200, 45000}, {64800, 66600}].	%%正确返回，不能随便修改，警告：测试时，请用下面的代码

%% 	=======================================
	%%温泉时间 测试用
%% 	[{14*3600+30*60, 15*3600+20*60}, {18*3600+50*60, 20*3600+15*60}].
%% 	=======================================

%% -----------------------------------------------------------------
%% 12054 进入温泉
%% -----------------------------------------------------------------
enter_spring(Status, Type) ->
	#player{lv = Lv} = Status,
	%%判断是否在这一天启动了该类型的温泉
	IsDate = check_is_hotspring_date(Type),
	%%获取进入的温泉的场景Id
	SceneId = get_spring_scene(Type),
%% 	?DEBUG("enter spring Type:~p, SceneId:~p", [Type, SceneId]),
	NowSec = util:get_today_current_second(),
	[{SO,EO},{ST,ET}] = lib_spring:get_spring_on_sale_times(),%%获取温泉的开放时间
	IsOnSale = ((SO + 2 =< NowSec andalso NowSec =< EO) orelse 
				   (ST + 2 =< NowSec andalso NowSec =< ET)) andalso IsDate,
	IsOn = lib_deliver:could_deliver(Status),
	if
		Lv < 30 ->%%等级够吗
			{3, Status};
		IsOnSale =:= false ->%%开放时间吗？
			if 
				((SO + 2 =< NowSec andalso NowSec =< EO) orelse 
					(ST + 2 =< NowSec andalso NowSec =< ET)) andalso Type =:= 2->
					{11, Status};%%大众温泉不是每天开放的
				true ->
					{2, Status}
			end;
		(Status#player.scene > 500 andalso Status#player.scene =/= 705) 
		  orelse Status#player.scene =:= ?WEDDING_SCENE_ID 
		  orelse Status#player.scene =:= ?WEDDING_LOVE_SCENE_ID 
		  orelse 
		IsOn =:= 31 orelse IsOn =:= 32 orelse IsOn =:= 33 
		  orelse IsOn =:= 34 orelse IsOn =:= 35 
		  orelse IsOn =:= 36 orelse IsOn =:= 37
		  orelse IsOn =:= 38 orelse IsOn =:= 41 
		  orelse IsOn =:= 42 orelse IsOn =:= 43 ->	%%副本中
			{4, Status};
		IsOn =:= 22 -> %%运镖,跑商
			{5, Status};
		IsOn =:= 21 ->%%红名
			{7, Status};
		IsOn =:= 10 orelse Status#player.status =:= 2 ->%%战斗中
			{8, Status};
		IsOn =:= 12 orelse Status#player.status =:= 4 ->%%蓝名
			{13, Status};
%% 		IsOn =:= 14 orelse Status#player.status =:= 6 ->%%打坐
%% 			{9, Status};
		IsOn =:= 15 ->%%凝神
			{10, Status};
%% 		Status#player.mount > 0 ->%%有坐骑
%% 			{12, Status};
		IsOn =:= 11 orelse IsOn =:= 16  ->
			{0, Status};
		IsOn =:= 18 ->%%双修不能进入温泉
			{14, Status};
%% 		Vip =:= 0 andalso SceneId =:= ?SPRING_SCENE_VIP_ID ->%%不再判断VIP了
%% 			{6, Status};
		true ->
			Result =
				case data_scene:get(SceneId) of
					[] ->
%% 						?DEBUG("false -- scene111111111111", []),
						{false, 0, 0, 0, <<"场景不存在!">>, 0, []};
					Scene ->
						case lib_scene:check_requirement(Status, Scene#ets_scene.requirement) of
							{false, Reason} -> 		
%% 								?DEBUG("false -- scene333333333333333", []),
								{false, 0, 0, 0, Reason, 0, []};
							{true} when Scene#ets_scene.type =:= ?SPRING_SCENE_TYPE ->%%温泉场景类型暂定为22
								get_spring_scene_info(Status, Scene#ets_scene.name,Scene#ets_scene.x, Scene#ets_scene.y, SceneId);
							_Other ->
%% 								?DEBUG("false -- scene444444444444", []),
								{false, 0, 0, 0, <<"场景不存在!">>, 0, []}
						end
				end,
			case Result of
				{false, _, _, _, _Msg, _, _} ->%%没有这个场景
%% 					?DEBUG("false -- scene", []),
					{0, Status};
				{true, NewSceneId, X, Y, Name, SceneResId, Dungeon_times, Dungeon_maxtimes, Status1} ->
					%%进入温泉前取消变身效果
					%%NewPs = Status1#player{other = Status1#player.other#player_other{turned = 0}},
					%%告诉原场景的玩家你已经离开
					pp_scene:handle(12004, Status, Status#player.scene),
%% 					?DEBUG("result and 12005:scene ~p, resoure ~p", [NewSceneId, SceneResId]),
					{ok, BinData} = pt_12:write(12005, 
												[NewSceneId, X, Y, Name, SceneResId, Dungeon_times, Dungeon_maxtimes, 0]),
					lib_send:send_to_sid(Status1#player.other#player_other.pid_send, BinData),
					put(change_scene_xy , [X, Y]),%%做坐标记录
					Status2 = Status1#player{scene = NewSceneId, x = X, y = Y,
											 other = Status1#player.other#player_other{is_spring = 1}},%%进入温泉前取消变身效果
					%%更新玩家新坐标
					ValueList = [{scene,NewSceneId},{x,X},{y,Y}],
					WhereList = [{id, Status2#player.id}],
					db_agent:mm_update_player_info(ValueList, WhereList),
					{1, Status2}
			end
	end.

%%获取玩家能够戏水的次数
get_faces(Vip) ->
	case Vip of
		0 ->%%不是会员
			3;
		1 ->%%月卡
			3;
		2 ->%%季卡
			4;
		3 ->%%半年卡
			5;
		_ ->
			3
	end.
%% 	100.%%暂时设成100
		
%%温泉+经验
spring_add_expspi(Player, Type) ->
	#player{lv = Lv,
			vip = Vip,
			x = X,
			y = Y,
			scene = Scene} = Player,
	%%判断是否在这一天启动了该类型的温泉
	SpriType = get_spring_type(Scene),
	IsDate = check_is_hotspring_date(SpriType),
%% 			?DEBUG("spring Type:~p, SceneId:~p", [Type, Scene]),
	NowSec = util:get_today_current_second(),
	[{SO,EO},{ST,ET}] = lib_spring:get_spring_on_sale_times(),%%获取温泉的开放时间
	IsOnSale = ((SO =< NowSec andalso NowSec =< EO) orelse 
					(ST =< NowSec andalso NowSec =< ET)) andalso IsDate,
	%%先查出玩家的位置
	Site = check_hotspring_site(X, Y),
	if 
		Site =:= 0 orelse Site =:= 1 ->%%泉水外的不+
			NewStatus = Player;
		Site =:= 2 andalso Vip =/= 3 ->%%VIPTOP里面的，但不是钻石VIP的不+
			NewStatus = Player;
		Site =:= 3 andalso Vip =:= 0 ->%%VIPNORMAL里面的，单不是VIP的不+
			NewStatus = Player;
		true ->
			case IsOnSale of
				true ->
					{Exp, Spi} = data_spring:get_spring_expspi(Lv, Vip, Site, Type),
%% 					?DEBUG("add hotspring exp:~p, spi:~p, Vip:~p, Site:~p, Type:~p", [Exp, Spi, Vip, Site, Type]),
					case Exp =:= 0 orelse Spi =:= 0 of
						true ->
%% 							?WARNING_MSG("add hotspring PlayerId:~p, exp:~p, spi:~p, Lv:~p, Vip:~p, Site:~p, Type:~p", 
%% 										 [Player#player.id, Exp, Spi, Lv, Vip, Site, Type]),
							NewStatus = Player;
						false ->
							NewStatus = lib_player:add_exp(Player, Exp, Spi, 15)
					end;
				false ->
%% 					?WARNING_MSG("IsOnSale false add hotspring PlayerId:~p, Lv:~p, Vip:~p, Site:~p, Type:~p", 
%% 								 [Player#player.id, Lv, Vip, Site, Type]),
					NewStatus = Player
			end
	end,
	case Type of
		0 ->%%发动作表情的
			skip;
		1 ->%%定时器的
			%%先去掉定时器.
			misc:cancel_timer(spring_timer),
			case IsOnSale of
				true ->
					SpringTimeer = erlang:send_after(?SPRING_TIMER, self(), {'SPRING_ADD_EXP_SPRI'}), %%开启温泉经验定时器
					put(spring_timer, SpringTimeer);%%进程字典
				false ->
					skip
			end
	end,
	NewStatus.

%%判断是否在温泉场景中
is_spring_scene(SceneId) ->
	SceneId =:= ?SPRING_SCENE_VIPTOP_ID.

%%判断是否需要启动温泉
start_spring(HSType, NowSec) ->
	[{SO,EO},{ST,ET}] = lib_spring:get_spring_on_sale_times(),%%获取温泉的开放时间
%% 	?DEBUG("NowSec:~p,{SO:~p,EO:~p},{ST:~p,ET:~p}", [NowSec,SO,EO,ST,ET]),
	case HSType of
		0 ->
			if 
				NowSec >= SO andalso NowSec =< EO ->
%% 					?DEBUG("11111 start spring:~p, ~p", [NowSec, HSType]),
					EndTime = EO - NowSec,
					open_spring(NowSec, 1, EndTime),%vip温泉启动
%% 					open_spring(NowSec, 2, EndTime),%大众温泉启动
					sys_broadcast_spring(1),%%全服通告
					CountEndTime = EndTime - 5,
					broadcast_spring_time(CountEndTime, 1),%% 广播温泉时间
					%%前十秒的倒计时同步
					SysEndTime = EndTime - 12,
					spawn(fun() -> timer:apply_after(SysEndTime*1000, lib_spring, broadcast_spring_time, [10, 0]) end),
					NewSType = 1;
				NowSec >= ST andalso NowSec =< ET ->
%% 					?DEBUG("22222 start spring:~p, ~p", [NowSec, HSType]),
					EndTime = ET - NowSec,
					open_spring(NowSec, 1, EndTime),%vip温泉启动
%% 					open_spring(NowSec, 2, EndTime),%大众温泉启动
					sys_broadcast_spring(1),%%全服通告
					CountEndTime = EndTime - 5,
					broadcast_spring_time(CountEndTime, 1),%% 广播温泉时间
					%%前十秒的倒计时同步
					SysEndTime = EndTime - 12,
					spawn(fun() -> timer:apply_after(SysEndTime*1000, lib_spring, broadcast_spring_time, [10, 0]) end),
					NewSType = 1;
				true ->
%% 					?DEBUG("44444  start spring:~p, ~p", [NowSec, HSType]),
					NewSType = HSType
			end;
		1 ->
			if 
				(NowSec >= SO andalso NowSec =< EO + 400+30) =:= false andalso
					(NowSec >= ST andalso NowSec =< ET + 400+30) =:= false ->
%%					?DEBUG("33333 delete spring:~p, ~p", [NowSec, HSType]),
					%%删除场景的ets表
%% 					ets:delete(?SPRING_TABLE),
					NewSType = 0;
				true ->
%% 					?DEBUG("55555 start spring:~p, ~p", [NowSec, HSType]),
					NewSType = HSType
			end
	end,
	NewSType.

%%生成 玩家能发表情的次数列表
make_faces_num(Num) ->
	make_face([],Num, ?SPRING_FACES_NUM).
make_face(Rest, _Num, 0) ->
	Rest;
make_face(Rest, Num, Count) ->
	make_face([Num|Rest], Num, Count-1).

%%检查是否需要通知温泉开放
check_spring_onsale(Lv, PidSend) ->
	NowSec = util:get_today_current_second(),
	[{SO,EO},{ST,ET}] = lib_spring:get_spring_on_sale_times(),%%获取温泉的开放时间
	[VipDates, NormalDates] = ?SPRING_ONSALE_DATE,
	Date = util:get_date(),
	IsVipD = lists:member(Date, VipDates),
	IsNormalD = lists:member(Date, NormalDates),
	IsOnDate = IsVipD orelse IsNormalD,
	if
		(NowSec >= SO andalso NowSec =< (EO-3))
		  andalso Lv >= 30 andalso IsOnDate =:= true ->
%% 			?DEBUG("send the notices,  nowsec ~p, lv ~p", [NowSec, Lv]),
			EndTime = EO - NowSec - 3,
			{ok, BinData12053} = pt_12:write(12053, [EndTime, 1]),
			lib_send:send_to_sid(PidSend, BinData12053);
		(NowSec >= ST andalso NowSec =< (ET-3))
		  andalso Lv >= 30 andalso IsOnDate =:= true ->
			EndTime = ET - NowSec - 3,
			{ok, BinData12053} = pt_12:write(12053, [EndTime, 1]),
			lib_send:send_to_sid(PidSend, BinData12053);
		true ->
%% 			?DEBUG("do not send the notices, nowsec ~p, lv ~p", [NowSec, Lv]),
			skip
	end.


%%
%% Local Functions
%%
%% 广播温泉时间
broadcast_spring_time(EndTime, Type) ->
	{ok, BinData12053} = pt_12:write(12053, [EndTime, Type]),
	mod_disperse:broadcast_to_world(ets:tab2list(?ETS_SERVER), BinData12053),
	catch lib_send:send_to_local_all(BinData12053).

%%系统广播
sys_broadcast_spring(Type) ->
	case Type of
		1 ->%%开启
%% 			?DEBUG("11111111111", []),
			NewMsg = "亲爱的玩家,现在是<font color='#FEDB4F'>温泉</font>开放时间,泡温泉可以获得大量的经验和灵力哦^_^",
			lib_chat:broadcast_sys_msg(1, NewMsg);
		0 ->%%关闭
%% 			?DEBUG("222222222222222222222", []),
			NewMsg = "亲爱的玩家,请注意，<font color='#FEDB4F'>温泉</font>将在<font color='#FEDB4F'>10</font>秒后关闭",
			lib_chat:broadcast_sys_msg(1, NewMsg)
	end.

%%获取温泉场景ID
%% get_spring_scene(Type) ->
%% 	case Type of
%% 		1 ->
%% 			?SPRING_SCENE_VIP_ID;
%% 		2 ->
%% 			?SPRING_SCENE_NORMAL_ID
%% 	end.
get_spring_scene(Type) ->
	case Type of
		1 ->
			?SPRING_SCENE_VIPTOP_ID;
		2 ->
			?SPRING_SCENE_VIPTOP_ID;
		3 ->
			?SPRING_SCENE_VIPTOP_ID
	end.
%% get_spring_type(SceneId) ->
%% 	case SceneId of
%% 		?SPRING_SCENE_VIP_ID ->
%% 			1;
%% 		?SPRING_SCENE_NORMAL_ID ->
%% 			2
%% 	end.
get_spring_type(SceneId) ->
	case SceneId of
		?SPRING_SCENE_VIPTOP_ID ->
			1;
		_ ->
			1
	end.

get_spring_scene_info(Status, Name, X, Y, SceneId) ->
%% 	?DEBUG("the scene id is:x:~p, y:~p, SceneId:~p", [X, Y, SceneId]),
	case mod_spring:get_spring_pid(SceneId) of
		{ok, Pid} ->
%% 			?DEBUG("is ok", []),
			Status1 = Status#player{other = Status#player.other#player_other{pid_scene = Pid}},
			%%获取发送给客户端的有关玩家温泉的资源Id
%% 			ResureSId = get_hotspring_resure_id(Status#player.vip),
			ResureSId = SceneId, 
			{true, SceneId, X, Y, Name, ResureSId, 0, 0, Status1};
		_ ->
%% 			?DEBUG("FAIL", []),
			{false, 0, 0, 0, <<"场景不存在!">>, 0, []}
	end.

check_is_hotspring_date(SpringType) ->
	Date = util:get_date(),
	Dates = lists:nth(SpringType, ?SPRING_ONSALE_DATE),
	IsDate = lists:member(Date, Dates),
	IsDate.

open_spring(_NowSec, SpringType, EndTime) ->
	SceneId = get_spring_scene(SpringType),%%获取进入的温泉的场景Id
	case check_is_hotspring_date(SpringType) of
		true ->
			mod_spring:init_spring([SceneId, EndTime]);
		false ->
			skip
	end.
			
%% %%获取发送给客户端的有关玩家温泉的资源Id
%% get_hotspring_resure_id(Vip) ->
%% 	case Vip of
%% 		3 ->
%% 			?SPRING_SCENE_VIPTOP_ID;
%% 		Val when Val =:= 1 orelse Val =:= 2 orelse Val =:= 4 ->
%% 			?SPRING_SCENE_VIPDOWN_ID;
%% 		_ ->
%% 			?SPRING_SCENE_PUBLIC_ID
%% 	end.
	
%%做玩家在温泉的位置标注，0：温泉场景外面，1：温泉里但不在泉水里，2：VIPTOP泉水里，3：VIPNORMAL泉水里，4：PUBLIC泉水里
mark_hotspring_site(Type) ->
	put(hs_site, Type).
get_hotspring_site() ->
	case get(hs_site) of
		undefined ->
			0;
		Num when is_integer(Num) ->
			Num;
		_ ->
			0
	end.

check_hotspring_site(X, Y) ->
%% 	VipTop = [{38, 20}, {39, 20}, {40, 20}, 
%% 			  {40, 21},
%% 			  {40, 22}],
	VipNormal = [{19, 22}, {20, 22}, {21, 22}, {22, 22},
				 {19, 23}, {20, 23}, {21, 23},
				 {19, 24}, {20, 24},
				 {19, 25}],
	Normal = [{23, 52} ,{24, 52}, {25, 52}, {26, 52}, {27, 52}, {28, 52}],
%% 	IsVipTop = lists:member({X,Y}, VipTop),
	IsVipNormal = lists:member({X,Y}, VipNormal),
	IsNormal = lists:member({X,Y}, Normal),
	if
		%% VIPTOP
%% 		(X >= 34 andalso X =<54 andalso Y >= 0 andalso Y =< 19)
%% 		  orelse (X >= 41 andalso X =< 54 andalso Y >= 19 andalso Y =< 26)
%% 		  orelse IsVipTop =:= true ->
%% 			?HOTSPRING_WATER_VIPTOP;
		%% VIPNORMAL
		(X >= 0 andalso X =< 28 andalso Y >= 0 andalso Y =< 21)
		  orelse (X >= 0 andalso X =<18 andalso Y >= 21 andalso Y =< 31)
		  orelse IsVipNormal =:= true ->
			?HOTSPRING_WATER_VIPNORMAL;
		%% PUBLIC
		(X >= 0 andalso X =<12 andalso Y >= 40 andalso Y =< 100)
		  orelse (X >= 12 andalso X =<60 andalso Y >= 53 andalso Y =< 100)
		  orelse IsNormal =:= true->
			?HOTSPRING_WATER_PUBLIC;
		%% OUTSIDE
		true ->
			?HOTSPRING_WATER_OUTSIDE
	end.

send_player_spring_site(PidScene, Pid, X, Y, IsSpring) ->
	NSite = check_hotspring_site(X, Y),
	OSite = get_hotspring_site(),
	case NSite =:= OSite of
		true ->
			IsSpring;
		false ->
			%%做玩家在温泉的位置标注，0：温泉场景外面，1：温泉里但不在泉水里，2：VIPTOP泉水里，3：VIPNORMAL泉水里，4：PUBLIC泉水里
			lib_spring:mark_hotspring_site(NSite),
			%%想场景进程发送位置改变通知
			gen_server:cast(PidScene, {'HOTSPRING_SITE_CHANGE', Pid, NSite}),
			InWater = {OSite, NSite},
			case lists:member(InWater, ?IN_OR_OUT_WATER) of
				true ->%%进水
					%%进水广播
%% 					?DEBUG("walk into water,Pid:~p, {~p,~p}, NSite:~p", [Pid, X, Y, NSite]),
					{ok, BinData12065} = pt_12:write(12065, [Pid, NSite]),
					spawn(fun() -> mod_scene_agent:send_to_area_scene(?SPRING_SCENE_VIPTOP_ID, X, Y, BinData12065) end),
					NSite;
				false ->
					OutWater = {NSite, OSite},
					case lists:member(OutWater, ?IN_OR_OUT_WATER) of
						true -> %%出水
							%%出水广播
%% 							?DEBUG("walk out of water,Pid:~p, {~p,~p}, NSite:~p", [Pid, X, Y, NSite]),
							{ok, BinData12065} = pt_12:write(12065, [Pid, NSite]),
							spawn(fun() -> mod_scene_agent:send_to_area_scene(?SPRING_SCENE_VIPTOP_ID, X, Y, BinData12065) end),
							NSite;
						false ->
							IsSpring
					end
			end
	end.
					
%%进温泉，下坐骑，取消挂机，温泉福利
player_comeinto_spring(Status) ->
	{ok, SitPlayer} =
		case Status#player.status of
			%% 从打坐状态恢复正常状态
			6 ->
				lib_player:cancelSitStatus(Status);
			_ ->
				%% 判断是否在挂机
				HookPlayer = lib_hook:cancel_hoook_status(Status),
				{ok, HookPlayer}
		end,
	%% 玩家卸下坐骑
	{ok, MountPlayerStatus}=lib_goods:force_off_mount(SitPlayer),
	%%玩家气血，法力瞬间爆满(温泉福利)
	SpriNewStatus = MountPlayerStatus#player{hp= MountPlayerStatus#player.hp_lim,
											 mp = MountPlayerStatus#player.mp_lim},
	%%发送人物改变信息
	spawn(fun()->
				  {ok, HpBinData} = pt_13:write(13016, [SpriNewStatus#player.id, 
														SpriNewStatus#player.hp, SpriNewStatus#player.mp]),
				  lib_send:send_to_sid(SpriNewStatus#player.other#player_other.pid_send, HpBinData),
				  %% 更新队伍成员气血
				  lib_team:update_team_player_info(SpriNewStatus)	
		  end),
	SpriNewStatus.

			