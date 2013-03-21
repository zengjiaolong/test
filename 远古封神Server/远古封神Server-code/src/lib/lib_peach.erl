%% Author: xiaomai
%% Created: 2011-2-25
%% Description: 蟠桃盛宴
-module(lib_peach).

%%
%% Include files
%%
-include("common.hrl").
-include("record.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-define(AUTO_SIT_EXP_TIME_LIMIT, 60).%%进入自动打坐的时间限制(60秒)
%%
%% Exported Functions
%%
-export([
		 get_peach_type/1,
		 count_add_peach_time/5,
		 player_load_into_scene/2,		%%玩家登陆进入桃子区域
		 player_revive_into_peach/1,
		 check_player_enter_peach/1,
		 check_handle_peach_exp_spir/1,	%%判断是否有可能给帮玩家启动一个 定时器的判断
		 handle_peach_exp_spir/1,		%%吃了蟠桃之后的状态判断
		 check_peach_use/2,				%%吃蟠桃时的判断
		 get_player_dict/1,				%%处理玩家吃蟠桃加经验和灵力的进程字典接口
		 put_player_dict/2,
		 erase_player_dict/1,
		 get_peach_exp_spirit/2,		%%获取不同类型的蟠桃得到的经验和灵力
		 count_auto_sit_exp/1,			%%计算自动打坐时+的经验和灵力
		 use_goods_peach/3,				%%使用蟠桃
		 get_devliver_coord/1,			%%获取蟠桃盛宴的传送坐标:SceneId, X, Y
		 get_peach_type_status/1,		%%蟠桃树下的提示
		 update_peach_revel/3,			%%用于更新玩家吃蟠桃时头上的桃子更新处理
		 cancel_peach_timer/1,			%%蟠桃的取消定时器
		 cancel_auto_sit_timer/4,		%%取消自动打坐+经验的定时器
		 player_sit_auto_add/1,			%%自动打坐+经验(警告：仅供mod_player使用)
		 is_local_peach/2]).			%%判断是否在蟠桃树下指定的地区

%%
%% API Functions
%%
%%使用蟠桃
use_goods_peach(Res, NewPlayerStatus, GoodsTypeId) ->
	case Res of
		1 ->
			case lists:member(GoodsTypeId, [23409, 23410, 23411]) of
				true ->%%蟠桃，要进行额外操作
					lib_activity:update_activity_data(peach, NewPlayerStatus#player.other#player_other.pid, NewPlayerStatus#player.id, 1),%%添加玩家活跃度统计
					%%吃桃子任务
					lib_task:event(use_peack, [1], NewPlayerStatus),
					%%氏族祝福任务判断
					GWParam = {2, 1},
					lib_gwish_interface:check_player_gwish(NewPlayerStatus#player.other#player_other.pid, GWParam),
					eat_peach_and_add_spirit(NewPlayerStatus, GoodsTypeId);
				false ->
					NewPlayerStatus
			end;
		_ ->
			NewPlayerStatus
	end.
%%使用蟠桃
eat_peach_and_add_spirit(NewPlayerStatus, _GoodsTypeId) ->
%% 	?DEBUG("the peach status is: ~p", [NewPlayerStatus#player.other#player_other.goods_buff#goods_cur_buff.peach_mult]),
	case lib_peach:get_player_dict(peach_add_exp_spirit) of
		true ->%%已经在打坐吃经验了
			NewStatus2 = 
				case NewPlayerStatus#player.status =:= 6 orelse NewPlayerStatus#player.status =:= 7 of
					true ->
						lib_peach:cancel_peach_timer(eat_peach_timer),%%蟠桃的取消定时器
						lib_peach:cancel_auto_sit_timer(NewPlayerStatus#player.scene, NewPlayerStatus#player.x, NewPlayerStatus#player.y, NewPlayerStatus#player.mount),%%取消自动打坐+经验的定时器
						%%重新算时间
						TimeRef = erlang:send_after(?PEACH_ADD_EXP_SPIRIT_STAMPTIME, self(), {'PEACH_ADD_EXP_SPIRIT'}),
						put(eat_peach_timer, TimeRef),
						lib_peach:put_player_dict(peach_add_exp_spirit, 1),
						NewPlayerStatus;
					false ->
						lib_peach:cancel_peach_timer(eat_peach_timer),%%蟠桃的取消定时器
						lib_peach:cancel_auto_sit_timer(NewPlayerStatus#player.scene, NewPlayerStatus#player.x, NewPlayerStatus#player.y, NewPlayerStatus#player.mount),%%取消自动打坐+经验的定时器
%% 						NewStatus1 = NewPlayerStatus#player{status = 6},
%% 						{ok, BinData} = pt_13:write(13015, [NewStatus1#player.id, 6]),
%% 						%%采用广播通知，附近玩家都能看到
%% 						mod_scene_agent:send_to_area_scene(NewStatus1#player.scene, NewStatus1#player.x, NewStatus1#player.y, BinData),
						TimeRef = erlang:send_after(?PEACH_ADD_EXP_SPIRIT_STAMPTIME, self(), {'PEACH_ADD_EXP_SPIRIT'}),
						put(eat_peach_timer, TimeRef),
						lib_peach:put_player_dict(peach_add_exp_spirit, 1),
						NewPlayerStatus
				end,
			NewStatus2;
		_ ->
			lib_peach:put_player_dict(peach_add_exp_spirit, 1),
%% 			Type = get_peach_type(GoodsTypeId),
%% 			{Exp, Spirit} = lib_peach:get_peach_exp_spirit(Type, NewPlayerStatus#player.lv),
%% 			NewStatus = lib_player:add_exp(NewPlayerStatus, Exp, Spirit, 6),
			lib_peach:cancel_peach_timer(eat_peach_timer),%%蟠桃的取消定时器
			lib_peach:cancel_auto_sit_timer(NewPlayerStatus#player.scene, NewPlayerStatus#player.x, NewPlayerStatus#player.y, NewPlayerStatus#player.mount),%%取消自动打坐+经验的定时器
			NewStatus2 = NewPlayerStatus,
%% 				case NewStatus#player.status =:= 6 orelse NewStatus#player.status =:= 7 of
%% 					true ->
%% 						NewStatus;
%% 					false ->
%% 						NewStatus1 = NewStatus#player{status = 6},
%% 						{ok, BinData} = pt_13:write(13015, [NewStatus1#player.id, 6]),
%% 						%%采用广播通知，附近玩家都能看到
%% 						mod_scene_agent:send_to_area_scene(NewStatus1#player.scene, NewStatus1#player.x, NewStatus1#player.y, BinData),
%% 						NewStatus1
%% 				end,
			TimeRef = erlang:send_after(?PEACH_ADD_EXP_SPIRIT_STAMPTIME, self(), {'PEACH_ADD_EXP_SPIRIT'}),
			put(eat_peach_timer, TimeRef),
			NewStatus2
	end.
			

%%吃了蟠桃之后的状态判断
handle_peach_exp_spir(Status) ->
	SitStatus = lib_player:player_status(Status),
	case  SitStatus =:= 6 orelse SitStatus =:= 7 of
		true ->%%是否在打坐
			Type = Status#player.other#player_other.goods_buff#goods_cur_buff.peach_mult,
			case Type =/= 1 of
				true ->
					case is_local_peach(Status#player.scene, [Status#player.x, Status#player.y]) of
						ok ->
							lib_peach:put_player_dict(peach_add_exp_spirit, 1),
							lib_peach:cancel_peach_timer(eat_peach_timer),%%蟠桃的取消定时器
							TimeRef = erlang:send_after(?PEACH_ADD_EXP_SPIRIT_STAMPTIME, self(), {'PEACH_ADD_EXP_SPIRIT'}),
							put(eat_peach_timer, TimeRef),
							Status;
						_Fail ->
							auto_sit_check(Status)	%%打坐自动+经验的判断
					end;
				false ->
					auto_sit_check(Status)	%%打坐自动+经验的判断
			end;
		false ->
			Status
	end.

%%吃蟠桃时的判断
check_peach_use(_GoodsId, Status) ->
%% 	Now = util:unixtime(),
	%%获取蟠桃的数据类型
%% 	Data = get_peach_type(GoodsId),
%% 	PeachMult = Status#player.other#player_other.goods_buff#goods_cur_buff.peach_mult,
%% 	case Data =< PeachMult of
%% 		true ->
%% 			case Status#player.lv >= 30 of
%% 				true ->
%% 					case is_local_peach(Status#player.scene, [Status#player.x, Status#player.y]) of
%% 						ok ->
%% 							status_isok(Status);
%% 						{fail, _Res} ->
%% 							{fail, 22}
%% 					end;
%% 				false ->%%等级限制
%% 					{fail, 8}
%% 			end;
%% 		false when PeachMult =:= 1 ->
			case Status#player.lv >= 30 of
				true ->
					case is_local_peach(Status#player.scene, [Status#player.x, Status#player.y]) of
						ok ->
							status_isok(Status);
						{fail, _Res} ->
							{fail, 22}
					end;
				false ->%%等级限制
					{fail, 8}
			end.
%% 		false when PeachMult > 1 ->
%% 			{fail, 77};
%% 		_ ->%%出问题
%% 			{fail, 34}
%% 	end.
			
%% %%一般情况的进去打坐
%% check_peach_using() ->

%%处理玩家吃蟠桃加经验和灵力的进程字典接口
get_player_dict(Type) ->
	case get(Type) of
		1 ->
			true;
		0 ->
			false;
		undefined  ->
			undefined
	end.
put_player_dict(Type, Param) ->
	put(Type, Param).
erase_player_dict(Type) ->
	erase(Type).

%%取消定时器的操作
cancel_peach_timer(Timer) ->
	case get(Timer) of
		undefined -> skip;
		Timer1 ->	
			erlang:cancel_timer(Timer1),
			put(Timer, undefined)
	end.

%%取消自动打坐+经验的定时器
cancel_auto_sit_timer(SceneId, X, Y, Mount) ->
	put(sit_auto_exp, {SceneId, X, Y, Mount, zero}).

%%获取不同类型的蟠桃得到的经验和灵力
get_peach_exp_spirit(Type, Level) ->
	Exp0 = data_peach:gen_peach_gain(Level),
	Spir0 = Exp0/2,
	{RetExp,RetSpirit} = case Type of
		2 ->%%初级primary
			PrimaryExp = Exp0 / 1.5,
			PrimarySpir = PrimaryExp / 2,
			{PrimaryExp, PrimarySpir};
		3 ->%%中级mid
			MidExp = Exp0 / 1.3,
			MidSpir = MidExp / 2,
			{MidExp, MidSpir};
		4 ->%%高级high
			HighExp = Exp0,
			HighSpir = Spir0,
			{HighExp, HighSpir}
	end,
	{util:floor(RetExp), util:floor(RetSpirit)}.

%%计算自动打坐时+的经验和灵力
count_auto_sit_exp(Lv) ->
	A = Lv/8,
	B = math:pow(A, 2.5),
	C = Lv*0.5+5,
	Exp = util:floor(B + C),
	Spirit = round(Exp/2),%%增加灵力为0
	{Exp, Spirit}.


get_peach_type_status(Player) ->
	if%%蟠桃树下的提示 --- by xiaomai
		Player#player.status =:= 6 andalso Player#player.other#player_other.goods_buff#goods_cur_buff.peach_mult =/= 1->
			IsPeach = is_local_peach(Player#player.scene, [Player#player.x, Player#player.y]), 
			case IsPeach of
				ok ->
					Type = 1;%%需要提示
				_ ->%%不需要提示
					Type = 0
			end;
		true ->%%不需要提示
			Type = 0
	end,
	Type.
	
%% 用于更新玩家吃蟠桃时头上的桃子更新处理
update_peach_revel(Type, Status, IsTO) ->
	PeachRevel = Status#player.other#player_other.peach_revel,
	case Type =:= PeachRevel of
		true when Type =:= 1 ->
			%%?DEBUG("peach Type:~p", [Type]),
			%% 仅更新玩家的桃子状态
			{ok, Bin12042} = pt_12:write(12042, [Status#player.id, [{1, Type}]]),
			%% 采用广播通知，附近玩家都能看到
			mod_scene_agent:send_to_area_scene(Status#player.scene, Status#player.x, Status#player.y, Bin12042),
			{0, Status};
		true ->
			{0, Status};
		false ->
			%% 玩家吃了蟠桃做下的状态更新 
			{ok, Bin12042} = pt_12:write(12042, [Status#player.id, [{1, Type}]]),
			%% 采用广播通知，附近玩家都能看到
			mod_scene_agent:send_to_area_scene(Status#player.scene, Status#player.x, Status#player.y, Bin12042),
			NewStatus = Status#player{other = Status#player.other#player_other{peach_revel = Type}},
			case Type =:= 1 andalso  PeachRevel =/= 1 of
				true ->
					case IsTO of
						true ->
							skip;
						false ->
							{ok, Bin11080} = pt_11:write(11080, 13, "离开修炼区域，无法获得仙桃经验"),
							lib_send:send_to_sid(Status#player.other#player_other.pid_send,Bin11080)
					end;
				false ->
					skip
			end,				
			{1, NewStatus}
	end.

%%自动打坐+经验(警告：仅供mod_player使用)
player_sit_auto_add(Status) ->
	#player{status = SitStatus, 
			hp = HP,
			scene = SceneId,
			x = NX,
			y = NY,
			mount = Mount} = Status,
	PeachAdd = lib_peach:get_player_dict(peach_add_exp_spirit),
	if
		SitStatus =:= 10 orelse SceneId =:= ?WEDDING_SCENE_ID orelse SceneId =:= ?WEDDING_LOVE_SCENE_ID ->%%双修状态不加经验,婚宴场景不做自动打坐的判断
			put(sit_auto_exp, {SceneId, NX, NY, Mount, zero}),
			SaveType = 0,	%%因为状态没变，所以不保存数据
			NewStatus = Status;
		true ->
			case Status#player.other#player_other.peach_revel =:= 1 of
				false ->
					put(sit_auto_exp, {SceneId, NX, NY, Mount, zero}),
					SaveType = 0,	%%因为状态没变，所以不保存数据
					NewStatus = Status;
				true ->
	case get(sit_auto_exp) of
		{OSceneId, OX, OY, OldMount,zero} ->%%第一次轮询
			case (SitStatus =:= 0 orelse SitStatus =:= 7) andalso Mount =:= OldMount andalso HP > 0 
				andalso SceneId =:= OSceneId andalso (SceneId =< 500 orelse SceneId =:= 705)
				andalso OX =:= NX andalso OY =:= NY of%%是否已经超过一分钟正常站着的
				true ->
					put(sit_auto_exp, {SceneId, NX, NY, Mount, first}),
					SaveType = 0,	%%因为状态没变，所以不保存数据
					NewStatus = Status;
				false ->%%重新轮询
					put(sit_auto_exp, {SceneId, NX, NY, Mount, zero}),
					SaveType = 0,	%%因为状态没变，所以不保存数据
					NewStatus = Status
			end;
		{OSceneId, OX, OY, OldMount, first} ->%%过了第一个20秒
			case (SitStatus =:= 0 orelse SitStatus =:= 7) andalso Mount =:= OldMount andalso HP > 0 
				andalso SceneId =:= OSceneId andalso (SceneId =< 500 orelse SceneId =:= 705)
				andalso OX =:= NX andalso OY =:= NY of%%是否已经超过一分钟正常站着的
				true ->
					put(sit_auto_exp, {SceneId, NX, NY, Mount, second}),
					SaveType = 0,	%%因为状态没变，所以不保存数据
					NewStatus = Status;
				false ->%%重新轮询
					put(sit_auto_exp, {SceneId, NX, NY, Mount, zero}),
					SaveType = 0,	%%因为状态没变，所以不保存数据
					NewStatus = Status
			end;
		{OSceneId, OX, OY, OldMount, second} ->%%过了第二个20秒
			case (SitStatus =:= 0 orelse SitStatus =:= 7) andalso Mount =:= OldMount andalso HP > 0 
				andalso SceneId =:= OSceneId andalso (SceneId =< 500 orelse SceneId =:= 705)
				andalso OX =:= NX andalso OY =:= NY of%%是否已经超过一分钟正常站着的
				true ->
					put(sit_auto_exp, {SceneId, NX, NY, Mount, third}),
					SaveType = 0,	%%因为状态没变，所以不保存数据
					NewStatus = Status;
				false ->%%重新轮询
					put(sit_auto_exp, {SceneId, NX, NY, Mount, zero}),
					SaveType = 0,	%%因为状态没变，所以不保存数据
					NewStatus = Status
			end;
		{OSceneId, OX, OY, OldMount, third} ->%%过了第三个20秒
			case (SitStatus =:= 0 orelse SitStatus =:= 7) 
				andalso Mount =:= OldMount andalso HP > 0 
				andalso SceneId =:= OSceneId andalso (SceneId =< 500 orelse SceneId =:= 705)
				andalso OX =:= NX andalso OY =:= NY of%%是否已经超过一分钟正常站着的或者坐坐骑的
				true when SitStatus =:= 0 andalso Mount =< 0->%%超过一分钟啦，开始计算+经验（站着的）
					put(sit_auto_exp, {SceneId, NX, NY, Mount, forth}),
					SaveType = 1,%%设置为需要保存数据
					{ok, NewStatus} = lib_player:startSitStatus(Status, no_param);
				true ->
					SaveType = 0,%%设置为需要保存数据
					NewStatus = auto_sit_check(Status);%%因为还是坐在坐骑上或者在凝神修炼，因此player没有改变
				false when SceneId =:= OSceneId andalso (SceneId =< 500 orelse SceneId =:= 705) andalso OX =:= NX andalso OY =:= NY ->%%站在同一个地方
					put(sit_auto_exp, {SceneId, NX, NY, Mount, forth}),
					SaveType = 0,	%%因为状态没变，所以不保存数据
					NewStatus = Status;
				false ->%%位置改变了
					put(sit_auto_exp, {SceneId, NX, NY, Mount, zero}),
					SaveType = 0,	%%因为状态没变，所以不保存数据
					NewStatus = Status
			end;
		{OSceneId, OX, OY, OldMount, forth} ->%%过了第三个20秒
			case ((SitStatus =:= 6 andalso Mount =< 0) 
				 orelse (SitStatus =:= 7 andalso Mount =< 0)
				 orelse (SitStatus =:= 0 andalso OldMount =:= Mount andalso Mount >0)) 
				andalso HP > 0 
				andalso SceneId =:= OSceneId andalso (SceneId =< 500 orelse SceneId =:= 705)
				andalso OX =:= NX andalso OY =:= NY of%%重新判断一次条件
				true when PeachAdd =:= true ->%%因为在吃桃子经验，所以不用+打坐的经验了
					put(sit_auto_exp, {SceneId, NX, NY, Mount, forth}),
					SaveType = 0,%%设置为需要保存数据
					NewStatus = Status;
				true ->
					%%修为倍数
					MultCulture = Status#player.other#player_other.goods_buff#goods_cur_buff.culture,
					%%封神争霸属性加成
					[_,WarMult|_] = Status#player.other#player_other.war_honor_value,
					{Exp, Spirit} = lib_peach:count_auto_sit_exp(Status#player.lv),
					Culture = round(Exp/10*(MultCulture+WarMult)), 
					NewStatus1 = lib_player:add_culture(Status,Culture),
					NewStatus2 = lib_player:add_exp(NewStatus1, Exp, Spirit, 13),
					lib_player:send_player_attribute(NewStatus2,2),
					NewStatus = NewStatus2,
					SaveType = 0,%%设置为需要保存数据
					put(sit_auto_exp, {SceneId, NX, NY, Mount, forth});
				false ->
					put(sit_auto_exp, {SceneId, NX, NY, Mount, zero}),
					SaveType = 0,	%%因为状态没变，所以不保存数据
					NewStatus = Status
			end;
		_ ->
			put(sit_auto_exp, {SceneId, NX, NY, Mount, zero}),
			SaveType = 0,	%%因为状态没变，所以不保存数据
			NewStatus = Status
			end
	end
	end,
	case SaveType =:= 1 of
		true ->
			mod_player:save_online_diff(Status,NewStatus);
		false ->
			skip
	end,
	NewStatus.
%%
%% Local Functions
%%
%%蟠桃类型
get_peach_type(GoodsTypeId) ->
	case GoodsTypeId of
		23409 ->
			2;
		23410 ->
			3;
		23411 ->
			4
	end.

%%判断是否在蟠桃树下指定的地区
is_local_peach(PlayerSceId, [PX, PY]) ->
	%%地图原坐标[(40,88),(22,70),(40,52),(58,70)],中心点(40,70)%%旧的
	%%地图原坐标[(61,126),(48,114),(61,102),(84,114)],中心点(66,118)%%新的
	%%以原点为中心点则
	%% 	x2 = x1 * cos(alpha) + y1 * sin(alpha);
	%% 	y2 = -x1 * sin(alpha) + y1 * cos(alpha);
	%%移至原点后 逆时针转换45度之后得出左下角，右上角坐标[(-11, -11),(13, 13)]
	{SceneId,[Xu,Yu], [Xd, Yd]} = {300, [-13, -13],[13, 13]},%%九霄的(重新配置，移至原点后再旋转,得出坐标，向上取整)
	%%移至原点
	%%旧的
%% 	X0 = PX - 40,
%% 	Y0 = PY - 70,
	%%新的
	X0 = PX - 62,
	Y0 = PY - 114,
	%%旋转，向上取整
	%% 对 math:sqrt(2)/2 = 0.7071067811865476 取整
	X = tool:ceil(X0*0.707 - Y0*0.707),
	Y = tool:ceil(X0*0.707 + Y0*0.707),
	case PlayerSceId =:= SceneId of
		true ->
			if
				X > Xu andalso X < Xd andalso Y > Yu andalso Y < Yd ->
					ok;
				true ->
					{fail, 1}%%不在指定的地区
			end;
		false ->
			{fail,1}%%不在指定的场景
	end.

%%获取蟠桃盛宴的传送坐标:SceneId, X, Y
get_devliver_coord(Type) ->
	case Type of
		3 -> %%灵兽圣园Npc附近
			SceneId = 705,
			[SceneId, 39, 74];
		_ ->
			SceneId = 300,
			Coords = [{61, 118}, {67, 123}, {71, 117}, {66, 111}, {67, 117}],
			%%产生种子
			{MegaSecs, Secs, MicroSecs} = now(),
			random:seed({MegaSecs, Secs, MicroSecs}),
			Num = random:uniform(5),
			{PX, PY} = lists:nth(Num, Coords),
			%%3秒之后做buff状态的判断
			erlang:send_after(3000, self(), {'PLAYER_INTO_PEACH'}),
			[SceneId, PX, PY]
	end.

%%角色状态是否能够吃蟠桃
status_isok(Status) ->
%% 	case Status#player.mount > 0 of 
%% 		true ->%%有坐骑
%% 			{fail,21};
%% 		false ->
			case lists:member(Status#player.status, [0,2,4,5,6,7,8,9,10]) of
				true ->
					ok;
				false ->%%其他状态不能吃
					{fail, 23}
			end.
%% 	end.

%%打坐自动+经验的判断
auto_sit_check(Status) ->
	#player{scene = SceneId,
			x = X,
			y = Y,
			mount = Mount} = Status,
	case (Status#player.scene < 500 orelse Status#player.scene =:= 705) of
		true ->
			case get(sit_auto_exp) of
				{OSceneId, OX, OY, OMount, _OType} ->
					case OX =:= X andalso OY =:= Y andalso OSceneId =:= SceneId
						andalso OMount =:= Mount of
						true ->%%原来的位置站起来坐下去
							put(sit_auto_exp, {SceneId, X, Y, Mount, forth}),
							Status;
						false ->%% 走动了
							put(sit_auto_exp, {SceneId, X, Y, Mount, third}),
							Status
					end;
				_ ->%%其他情况
					put(sit_auto_exp, {SceneId, X, Y, Mount, zero}),
					Status
			end;
		false ->
			put(sit_auto_exp, {SceneId, X, Y, Mount, zero}),
			Status
	end.
		
%%判断是否有可能给帮玩家启动一个 定时器的判断
check_handle_peach_exp_spir(Player) ->
	case Player#player.status of
		7 ->%%只有在凝神修炼的时候，才会有可能给帮玩家启动一个 定时器的判断
			lib_peach:handle_peach_exp_spir(Player);
		_ ->
			Player
	end.
			
check_player_enter_peach(Status) ->
	PeachMult = Status#player.other#player_other.goods_buff#goods_cur_buff.peach_mult,
	case PeachMult of
		Type when Type =:= 2 orelse Type =:= 3 orelse Type =:= 4 ->%%buff存在呢
			case lib_peach:is_local_peach(Status#player.scene, [Status#player.x, Status#player.y])of
				ok -> %%是否在桃树区域
					case get(peach_coord) of
						1 ->%%原来已经在里面了
							%%做位置的标注
							put(peach_coord, 1),
							Status;
						_O ->%%原来不在
							case lib_peach:get_player_dict(peach_add_exp_spirit) of
								true ->
%% 									{_Exp, _Spirit} = lib_peach:get_peach_exp_spirit(Type, Status#player.lv),
									lib_peach:put_player_dict(peach_add_exp_spirit, 1),
									lib_peach:cancel_peach_timer(eat_peach_timer),%%蟠桃的取消定时器
									lib_peach:cancel_auto_sit_timer(Status#player.scene, Status#player.x, Status#player.y, Status#player.mount),%%取消自动打坐+经验的定时器
									TimeRef = erlang:send_after(?PEACH_ADD_EXP_SPIRIT_STAMPTIME, self(), {'PEACH_ADD_EXP_SPIRIT'}),
									put(eat_peach_timer, TimeRef),
%% 									NewStatus1 = lib_player:add_exp(Status, Exp, Spirit, 7),
%% 									?DEBUG("true PeachMult:~p, peach_revel:~p", [PeachMult, Status#player.other#player_other.peach_revel]),
									{_SaveType, NewStatus} = lib_peach:update_peach_revel(PeachMult, Status, false),
									%%做位置的标注
									put(peach_coord, 1),
									NewStatus;
								false ->%%刚刚进来的
%% 									{_Exp, _Spirit} = lib_peach:get_peach_exp_spirit(Type, Status#player.lv),
									lib_peach:put_player_dict(peach_add_exp_spirit, 1),
									lib_peach:cancel_peach_timer(eat_peach_timer),%%蟠桃的取消定时器
									lib_peach:cancel_auto_sit_timer(Status#player.scene, Status#player.x, Status#player.y, Status#player.mount),%%取消自动打坐+经验的定时器
									TimeRef = erlang:send_after(?PEACH_ADD_EXP_SPIRIT_STAMPTIME, self(), {'PEACH_ADD_EXP_SPIRIT'}),
									put(eat_peach_timer, TimeRef),
%% 									NewStatus1 = lib_player:add_exp(Status, Exp, Spirit, 7),
%% 									?DEBUG("false PeachMult:~p, peach_revel:~p", [PeachMult, Status#player.other#player_other.peach_revel]),
									{_SaveType, NewStatus} = lib_peach:update_peach_revel(PeachMult, Status, false),
									%%做位置的标注
									put(peach_coord, 1),
									NewStatus;
								undefined ->
%% 									?DEBUG("undefined PeachMult:~p, peach_revel:~p", [PeachMult, Status#player.other#player_other.peach_revel]),
									{_SaveType, NewStatus} = lib_peach:update_peach_revel(PeachMult, Status, false),
									lib_peach:erase_player_dict(peach_add_exp_spirit),
									%%做位置的标注
									put(peach_coord, 1),
									NewStatus
							end
					end;
				_OutSide ->
					case get(peach_coord) of
						1 ->%%原来已经在里面了
							%%做位置的标注
							{_SaveType, NewStatus} = lib_peach:update_peach_revel(1, Status, false),
							put(peach_coord,0),
							NewStatus;
						_ ->
							%%做位置的标注
							put(peach_coord, 0),
							Status
					end
			end;
		_O ->%%没有buff
			%%做位置的标注
			put(peach_coord, 0),
			Status
	end.

player_revive_into_peach(Status) ->
	PeachMult = Status#player.other#player_other.goods_buff#goods_cur_buff.peach_mult,
	case PeachMult of
		1 ->%%没有buff
			%%做位置的标注
			put(peach_coord, 0),
			{0, Status};
		Type when Type =:= 2 orelse Type =:= 3 orelse Type =:= 4 ->%%buff存在呢
			case lib_peach:is_local_peach(Status#player.scene, [Status#player.x, Status#player.y])of
				ok -> %%是否在桃树区域
%% 					{Exp, Spirit} = lib_peach:get_peach_exp_spirit(Type, Status#player.lv),
					lib_peach:put_player_dict(peach_add_exp_spirit, 1),
					lib_peach:cancel_peach_timer(eat_peach_timer),%%蟠桃的取消定时器
					lib_peach:cancel_auto_sit_timer(Status#player.scene, Status#player.x, Status#player.y, Status#player.mount),%%取消自动打坐+经验的定时器
					TimeRef = erlang:send_after(?PEACH_ADD_EXP_SPIRIT_STAMPTIME, self(), {'PEACH_ADD_EXP_SPIRIT'}),
					put(eat_peach_timer, TimeRef),
%% 					NewStatus1 = lib_player:add_exp(Status, Exp, Spirit, 7),
%% 					?DEBUG("true PeachMult:~p, peach_revel:~p", [PeachMult, Status#player.other#player_other.peach_revel]),
					{SaveType, NewStatus} = lib_peach:update_peach_revel(PeachMult, Status, false),
					%%做位置的标注
					put(peach_coord, 1),
					{SaveType, NewStatus};
				_OutSide ->
					%%做位置的标注
					put(peach_coord, 0),
					{0, Status}
			end;
		_Other ->
			%%做位置的标注
			put(peach_coord, 0),
			{0, Status}
	end.
		
		
%%玩家登陆进入桃子区域
player_load_into_scene(Status, PlayerBuff) ->
	lists:foldl(fun(Elem, AccIn) ->
						{EBuffId,_EValue,_ELT} = Elem,
						case AccIn of
							false ->
								case lists:member(EBuffId, [23409, 23410, 23411]) of
									true ->
%% 										?DEBUG("EBuffId:~p", [EBuffId]),
										lib_peach:put_player_dict(peach_add_exp_spirit, 1),
										lib_peach:cancel_peach_timer(eat_peach_timer),%%蟠桃的取消定时器
										lib_peach:cancel_auto_sit_timer(Status#player.scene, Status#player.x, Status#player.y, Status#player.mount),%%取消自动打坐+经验的定时器
										TimeRef = erlang:send_after(?PEACH_ADD_EXP_SPIRIT_STAMPTIME, self(), {'PEACH_ADD_EXP_SPIRIT'}),
										put(eat_peach_timer, TimeRef),
										true;
									false ->
										AccIn
								end;
							true ->
								AccIn
						end
				end, false, PlayerBuff).

-define(ABCDE, 60).
count_add_peach_time(Data, Value, OldTime, OldType, Now) ->
	case {OldType, Value} of
		{4, 3} -> %%高级 吃 中级 -> 高级
			{trunc(Data * ?ABCDE / 1.3 + OldTime), 4};
		{3, 2} -> %%中级 吃 低级 -> 中级
			{trunc(Data * ?ABCDE * 1.3 / 1.5 + OldTime), 3};
		{4, 2} -> %%高级 吃 低级 -> 高级
			{trunc(Data * ?ABCDE / 1.5 + OldTime), 4};
		{4, 4} -> %%高级 吃 高级 -> 高级
			{trunc(Data * ?ABCDE + OldTime), 4};
		{3, 3} -> %%中级 吃 中级 -> 中级
			{trunc(Data * ?ABCDE + OldTime), 3};
		{2, 2} -> %%低级 吃 低级 -> 低级
			{trunc(Data * ?ABCDE + OldTime), 2};
		{3, 4} -> %%中级 吃 高级 -> 高级
			RetTime = OldTime - Now,
			case RetTime > 0 of
				true ->
					{trunc(RetTime / 1.3 + Data * ?ABCDE + Now), 4};
				false ->
					{trunc(Data * ?ABCDE + Now), 4}
			end;
		{2, 3} -> %%低级 吃 中级 -> 中级
			RetTime = OldTime - Now,
			case RetTime > 0 of
				true ->
					{trunc(RetTime * 1.3 / 1.5 + Data * ?ABCDE + Now), 3};
				false ->
					{trunc(Data * ?ABCDE + Now), 3}
			end;
		{2, 4} -> %%低级 吃 高级 -> 高级
			RetTime = OldTime - Now,
			case RetTime > 0 of
				true ->
					{trunc(RetTime / 1.5 + Data * ?ABCDE + Now), 4};
				false ->
					{trunc(Data * ?ABCDE + Now), 4}
			end;
		_ -> %%
			{0, 1}
	end.